## NrsDriver.sys

Nokia "NRS" helper driver (KMDF, ACPI device `\_SB.NRSD`, `NRSD0001`).  
It has two jobs:
- at the **first boot** (before the OOBE is done), it reads the cover colour of the phone from the DPP file `C:\DPP\Nokia\CoverColor.txt` and copies the matching theme (accent colour, light/dark theme, wallpaper, MTP icon and avatar) from `HKLM\Software\OEM\Nokia\Multivariant\Color\<colour>` into the shell registry keys. See [Cover colour](#cover-colour-multivariant).
- it gives user mode a few kernel services through IOCTLs: file copy, SMS encoding presets and read/write of a fixed list of registry values. See the [IOCTLs](#ioctl-0x2260d0--ioctl_nrs_file_copy).

PDB: `C:\CI\workspace\nrs_driver_bld\bldl2nrsdriver\NrsDriver\Solution\ARM\Win8betaRelease\NrsDriver.pdb`. Imports only `ntoskrnl.exe`, `HAL.dll` (`KeGetCurrentIrql`) and `WDFLDR.SYS`. Pool tag `nrs` (0x0073726E). No hardware access.  
All its log goes through `DbgPrintEx` (component 0x4D, prefix `NRSDRIVER::<function> (DBG|WRN|ERR):`); the function names in this page come from those strings.

Device name : `\Device\NrsDriver`  
Symbolic link : `\DosDevices\NrsDriver`  
Device type : 0x22 (FILE_DEVICE_UNKNOWN), buffered I/O, not exclusive.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\NRSD0001\1`  

There's no parameters in the registry (the driver reads no value under its own service key).

GUID of the ETW provider (WPP control GUID, registered by `WppInitKm`, no trace message used except in `DriverEntry`):  
`{720FE94A-B5BD-4D7C-A408-000A325EB26C}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\_SB.PRXY` | [qcpepproxy8930.sys](./qcpepproxy8930.md) | Not used by the driver: the `_PS0`…`_PS3` methods of `\_SB.NRSD` report its D-state changes to the power proxy (see [qcabd8930.sys](./qcabd8930.md#lumia-520-acpi-node)) |

### Driver entry and device

`DriverEntry` (0x412008): WPP init, `WdfDriverCreate` with `EvtDriverDeviceAdd` (0x40EFB4) and a driver cleanup callback (`NrsDriverEvtDriverContextCleanup`, 0x40F014, WPP cleanup).  
`NrsDriverCreateDevice` (sub_40E8FC):
1. `WdfDeviceInitAssignName(\Device\NrsDriver)`.
2. PnP/power callbacks: `EvtDeviceD0Entry` (sub_402588) → `NrsColorVariationWorkerStart`, `EvtDeviceD0Exit` (sub_4025C4) → stops and deletes the timer and the work item.
3. `WdfDeviceCreate` with a `DEVICE_CONTEXT` (timer handle at 0x0C, work item at 0x10, retry counter at 0x14) and a cleanup callback (sub_402628).
4. `WdfDeviceCreateDeviceInterface` with the [interface GUID](#interface-guid), `WdfDeviceCreateSymbolicLink(\DosDevices\NrsDriver)`.
5. `NrsDriverQueueInitialize` (sub_40F1B4): default parallel queue, only `EvtIoDeviceControl` (0x40F2F8).
6. `NrsColorVariationWorkerInitialize` (sub_40E698): a WDF timer (`NrsColorcolorVariationTimerTick`, sub_402390) that queues a work item (`NrsColorcolorVariationWorkItem`, sub_40222C).

### Cover colour (Multivariant)

`NrsColorVariationWorkerStart` (sub_40E844) starts the timer **5 s** after D0 entry (due time -50000000). The work item calls `NRSSetDeviceColor` (sub_40E008):
1. Must run at PASSIVE_LEVEL (otherwise 0xC0000184). `\Registry\Machine\Software\Microsoft\Shell` must exist, otherwise the attempt fails ("Registry not ready").
2. Logs the current state (`NRSDebugPrintState`, sub_401E38): `Shell\OOBE` `Done`, `Multivariant\Color` `CurrentColor`, `Shell\OEM\Wallpaper` `CurrentWallpaper`, `Control Panel\Theme` `CurrentAccent` / `CurrentTheme`.
3. Test mode: REG_DWORD `Test` in `HKLM\Software\OEM\Nokia\Multivariant\Color`. Missing → off ("implicit"), 0 → off, other → on.
4. Reads REG_DWORD `Done` in `HKLM\Software\Microsoft\Shell\OOBE`. Read failure → error. Value 1 or 2 → "Not the 1st boot", returns STATUS_SUCCESS without doing anything. Any other value → first boot, continue.
5. Colour file: `\DosDevices\C:\DPP\Nokia\CoverColor.txt`, or `\DosDevices\C:\Data\Users\PUBLIC\CoverColor.txt` in test mode. `NRSBufferRead` (sub_401BDC) reads it one byte at a time into a wide string (max 50 characters, each byte widened to a WCHAR), and stops at the first CR or LF.
6. Mapping key = `\Registry\Machine\Software\OEM\Nokia\Multivariant\Color\` + file content (e.g. `...\Color\Cyan` ?).
   - Key found: `RtlQueryRegistryValues(Ex)` on that key with the [value table](#theme-values) below (flags 0x14 = REQUIRED | NOEXPAND, so every value must exist), then `NRSStoreCurrentColor` (sub_4019B0) writes the file content as REG_SZ `CurrentColor` in `HKLM\Software\OEM\Nokia\Multivariant\Color` (keys created if missing).
   - Key not found: `NRSSetDefaultVariants` (sub_401008) uses `HKLM\Software\OEM\Nokia\Multivariant\Color\Default` instead, with the same table plus `Color` → `CurrentColor`.
7. Logs the state again.

Theme values (read as REG_SZ from the mapping key):  
| Value | Callback | Written to |
|-------|----------|------------|
| `Accent` | `NRSUpdateAccent` (sub_40159C) | `HKLM\Software\Microsoft\Windows\CurrentVersion\Control Panel\Theme` `CurrentAccent` (REG_DWORD, the string converted as a decimal number) |
| `Theme` | `NRSUpdateTheme` (sub_4016D8) | same key, `CurrentTheme` (REG_DWORD, decimal) |
| `Wallpaper` | `NRSUpdateWallpaper` (sub_401814) | `HKLM\Software\Microsoft\Shell\OEM\Wallpaper` `CurrentWallpaper` (REG_SZ, keys created if missing) |
| `Icon` | `NRSUpdateIcon` (sub_40133C) | `HKLM\Software\Microsoft\MTP` `OEMICON` (REG_SZ, key must exist) |
| `Avatar` | `NRSUpdateAvatar` (sub_40146C) | `HKLM\Software\Microsoft\MTP` `OEMAVATAR` (REG_SZ, key must exist) |
| `Color` (Default key only) | `NRSUpdateColor` (sub_4011D0) | `HKLM\Software\OEM\Nokia\Multivariant\Color` `CurrentColor` (REG_SZ) |

Retries (in the work item): success or STATUS_NOT_FOUND (0xC0000225, returned when the colour file is missing, i.e. 0xC0000034 from `ZwOpenFile`, or when the `Default` key is missing) → the timer and the work item are deleted. Any other error → the timer is started again for **3 s**, at most **8** retries ("Max retry limit 8 reached").

The colour file is DPP item 3 of [npetsec.dll](../libraries/npetsec.md#dpp-items).

---

### IOCTL 0x2260D0 — IOCTL_NRS_FILE_COPY

This IOCTL is processed by NrsDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x834 (2100) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_FILE_COPY | 1024 (exact) | 0 |

Inputbuffer (`NFileCopyInfo`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-1FF | | Source path, NT form, null-terminated WCHAR (256 characters) |
| 200-3FF | | Destination path, NT form, null-terminated WCHAR (256 characters) |

`NrsFileCopy` (sub_40F088), at PASSIVE_LEVEL only (otherwise 0xC0000184):
1. `FileRead` (sub_402818): `ZwOpenFile` (GENERIC_READ | SYNCHRONIZE, share read, `FILE_SYNCHRONOUS_IO_NONALERT | FILE_NON_DIRECTORY_FILE`, `OBJ_KERNEL_HANDLE | OBJ_CASE_INSENSITIVE`), size from `ZwQueryInformationFile` (sub_402724), whole file read into one NonPagedPoolNx buffer.
2. `FileWrite` (sub_40299C): `ZwCreateFile` (GENERIC_WRITE | SYNCHRONIZE, `FILE_ATTRIBUTE_NORMAL`, no sharing, disposition `FILE_SUPERSEDE` (0), options `FILE_WRITE_THROUGH | FILE_SYNCHRONOUS_IO_NONALERT | FILE_NON_DIRECTORY_FILE` (0x64)), one `ZwWriteFile` of the whole buffer.

The request is completed with the NTSTATUS of the copy and Information 0.

> [!NOTE]
> The file is opened by the driver with kernel handles, so the access check is done for the kernel, not for the caller. The paths aren't checked. On the error paths of `FileRead`/`FileWrite`, the handle and the buffer are not freed.

---

### IOCTL 0x2260E8 — IOCTL_NRS_FILE_COPY2

This IOCTL is processed by NrsDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x83A (2106) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_FILE_COPY2 | 2048 (exact) | 0 |

Inputbuffer (`NFileCopyInfo2`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-3FF | | Source path, NT form, null-terminated WCHAR (512 characters) |
| 400-7FF | | Destination path, NT form, null-terminated WCHAR (512 characters) |

Same as [IOCTL_NRS_FILE_COPY](#ioctl-0x2260d0--ioctl_nrs_file_copy) with longer paths.

---

### IOCTL 0x2260D4 — IOCTL_NRS_INTERFACE_VERSION

This IOCTL is processed by NrsDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x835 (2101) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_INTERFACE_VERSION | 0 | 8 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Major version 1 ? |
| 04-07 | 03 00 00 00 | Minor version 3 ? |

A different output size is only logged; `WdfRequestRetrieveOutputBuffer` asks for 8 bytes and the result isn't checked before writing.

---

### IOCTL 0x2260D8 — IOCTL_NRS_SMSENCODING_SET

This IOCTL is processed by NrsDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x836 (2102) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_SMSENCODING_SET | 4 (exact) | 1 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Encoding mode 0…4 (only the low 16 bits are tested) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | 1 = written, 0 = error (mode ≥ 5, not PASSIVE_LEVEL, key missing, write failure) |

`SetSmsEncodingRegKey` (sub_40F888) writes the REG_DWORD values of the selected preset (table at `.data:0x00408100`, 5 rows of 99 name/value pairs) into `HKLM\Software\Microsoft\Cellular\SMS\OEM\Encoding`, which must already exist. The request is completed with STATUS_SUCCESS and Information 1.

| Mode | GSM7BitEncodingPage | UseKeyboardLanguage | SendUDHNLSS |
|------|---------------------|---------------------|-------------|
| 0 | 55000 | 0 | 0 |
| 1 | 55004 | 0 | 0 |
| 2 | 55002 | 1 | 1 |
| 3 | 55001 | 1 | 1 |
| 4 | 55003 | 1 | 1 |

The 5500x code pages are the GSM 7-bit national language tables (default alphabet, then the national language single shift / locking shift tables) ?

---

### IOCTL 0x2260DC — IOCTL_NRS_SMSENCODING_QUERY

This IOCTL is processed by NrsDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x837 (2103) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_SMSENCODING_QUERY | 1024 (exact) | 4 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-1FF | | Registry key, absolute path, null-terminated WCHAR (e.g. `\Registry\Machine\Software\Microsoft\Cellular\SMS\OEM\Encoding`) |
| 200-3FF | | Value name, null-terminated WCHAR (e.g. `GSM7BitEncodingPage`) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | REG_DWORD value |

`GetSmsEncodingRegKey` (sub_40F9DC): `RtlCheckRegistryKey`, then `RtlQueryRegistryValuesEx` (or `RtlQueryRegistryValues` when not exported) with `RTL_QUERY_REGISTRY_DIRECT | RTL_QUERY_REGISTRY_TYPECHECK` (0x120), type REG_DWORD. Completed with the NTSTATUS of the query and Information 4.  
Unlike the [allowed-registry IOCTLs](#allowed-registry-values), the key and value name are not compared with the allow-list.

---

### Allowed registry values

The four registry IOCTLs below only accept the keys and value names of two tables:
`NRSAllowedKeys` (`.data:0x0040B738`, rows of 10 pointers: the key, then the parent keys to create) and `NRSAllowedValueNames` (`.data:0x0040B994`, rows of 15 pointers).
The key is compared with `RtlEqualUnicodeString(…, CaseInSensitive = FALSE)`: it must match exactly, including case.

| # | Key | Parent keys created on write | Allowed values |
|---|-----|------------------------------|----------------|
| 0 | `\Registry\Machine\Software\Microsoft\Cellular\SMS\OEM\Encoding` | `…\Cellular\SMS`, `…\Cellular\SMS\OEM` | `GSM8BitEncodingPage`, `OctetEncodingPage`, `GSM7BitEncodingPage`, `UseKeyboardLanguage`, `SendUDHNLSS`, `UseASCII` |
| 1 | `\Registry\Machine\Software\Microsoft\Connectivity\CellUXOEMConfigurable` | `…\Software\Microsoft`, `…\Microsoft\Connectivity` | `HideHighestSpeed4G` |
| 2 | `\Registry\Machine\System\Maps\Storage` | `\Registry\Machine\System\Maps` | `UseExternalStorage` |
| 3 | `\Registry\Machine\System\CurrentControlSet\Services\WiFiConnSvc\Parameters\Config` | `System`, `CurrentControlSet`, `Services`, `WiFiConnSvc`, `Parameters` | `EnableStaticIP` |
| 4 | `\Registry\Machine\System\TOUCH\BUTTONS` | `\Registry\Machine\System\TOUCH` | `Vibrate`, `Duration`, `Intensity` |
| 5 | `\Registry\Machine\Software\OEM\PhoneSmsFilter` | `\Registry\Machine\Software\OEM` | `AppId` |
| 6 | `Registry\Machine\System\DeviceTargetingInfo` | `Registry\Machine\System` | `PhoneFriendlyName` |

Entry 6 has no leading backslash, so it isn't an absolute path for the `RTL_REGISTRY_ABSOLUTE` (0) calls that use it: reads and writes on it should fail ?

Result codes returned in the output buffer (`NReadNumValueFromRegKey` sub_40FFA0, `NWriteNumValueToRegKey` sub_40FE8C, `NReadStringValueFromRegKey` sub_40FB48, `NWriteStringValueToRegKey` sub_40FD3C):  
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Key doesn't exist (read) |
| 2 | Registry read failed |
| 3 | Key not allowed, or not at PASSIVE_LEVEL |
| 4 | Value name not allowed for that key |
| 5 | Registry write failed |
| 6 | Key creation failed (write: when the key is missing, `CreateRegKey` sub_4033E4 creates the parents of the table then the key) |

Status of the request: 0xC0000206 (STATUS_INVALID_BUFFER_SIZE) when a size is wrong, 0xC022001C when the input buffer pointer is NULL.

---

### IOCTL 0x2260E0 — IOCTL_NRS_WRITE_TO_ALLOWED_REGISTRY

This IOCTL is processed by NrsDriver.sys. 0x2260EC (function 0x83B) is handled by the same code.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x838 (2104) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_WRITE_TO_ALLOWED_REGISTRY | 1028 (exact) | 4 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-1FF | | Registry key, null-terminated WCHAR, from the [allowed keys](#allowed-registry-values) |
| 200-3FF | | Value name, null-terminated WCHAR |
| 400-403 | | REG_DWORD data |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | [Result code](#allowed-registry-values) |

`SetRegistryDWORD` (sub_402AEC). Completed with STATUS_SUCCESS and Information 4.

---

### IOCTL 0x2260E4 — IOCTL_NRS_READ_FROM_ALLOWED_REGISTRY

This IOCTL is processed by NrsDriver.sys. 0x2260F0 (function 0x83C) is handled by the same code.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x839 (2105) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_READ_FROM_ALLOWED_REGISTRY | 1024 (exact) | 8 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-1FF | | Registry key, null-terminated WCHAR, from the [allowed keys](#allowed-registry-values) |
| 200-3FF | | Value name, null-terminated WCHAR |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | REG_DWORD data (direct query, type check REG_DWORD) |
| 04-07 | 00 00 00 00 | [Result code](#allowed-registry-values) |

`QueryRegistryDWORD` (sub_402CA0). Completed with STATUS_SUCCESS and Information 8.

---

### IOCTL 0x2260F4 — IOCTL_NRS_WRITE_STRING_TO_ALLOWED_REGISTRY

This IOCTL is processed by NrsDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x83D (2109) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_WRITE_STRING_TO_ALLOWED_REGISTRY | 2048 (exact) | 4 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-1FF | | Registry key, null-terminated WCHAR, from the [allowed keys](#allowed-registry-values) |
| 200-3FF | | Value name, null-terminated WCHAR |
| 400-7FF | | String data, WCHAR |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | [Result code](#allowed-registry-values) |

`SetRegistrySZ` (sub_402E8C) → `NWriteStringValueToRegKey`.

> [!NOTE]
> `RtlWriteRegistryValue` is called with type REG_SZ and a **fixed length of 4 bytes**: only the first 2 characters of the string are written (without terminating null). So this IOCTL can't really write a string value as is.

---

### IOCTL 0x2260F8 — IOCTL_NRS_READ_STRING_FROM_ALLOWED_REGISTRY

This IOCTL is processed by NrsDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x83E (2110) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NRS_READ_STRING_FROM_ALLOWED_REGISTRY | 1024 (exact) | 1028 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-1FF | | Registry key, null-terminated WCHAR, from the [allowed keys](#allowed-registry-values) |
| 200-3FF | | Value name, null-terminated WCHAR |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-3FF | | String, null-terminated WCHAR (max 512 characters, `wcscpy_s`) |
| 400-403 | 00 00 00 00 | [Result code](#allowed-registry-values) |

`QueryRegistrySZ` (sub_40303C) → `NReadStringValueFromRegKey` (query with a callback, `RTL_QUERY_REGISTRY_REQUIRED`, into a 1024-byte pool buffer).

---

### Request completion

Several paths of `NrsDriverEvtIoDeviceControl` never complete the WDF request: an unknown IOCTL code, any size / buffer error, and every error returned by the four registry handlers (their return value is ignored). Such a request stays pending until the handle is closed.  
After a successful file copy or version query, the driver logs "NrsEvtIoDeviceControl: IO error" (the test is inverted: `if (status >= 0)`).

### Interface GUID

NrsDriver Interface Class GUID  
`{EC60E01A-79C0-4641-BA66-1B9E703A3CA3}`
