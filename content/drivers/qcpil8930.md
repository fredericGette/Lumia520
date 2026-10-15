## Qcpil8930.sys

Peripheral Image Loader (PIL).  
On request of the subsystem drivers (the "RPE clients", e.g. [qcwcn8930.sys](./qcwcn8930.md)), it parses the `.mbn` firmware files (ELF), copies their segments to physical memory and asks the TrustZone, through qcscm8930.sys (Secure Channel Manager), to authenticate the image and bring the subsystem out of reset.  
It follows the Qualcomm "PAS" (Peripheral Authentication Service, SCM service 2) sequence: init image (metadata) → load segments → auth & reset, and shutdown before a reload.  
Every loaded image is remembered (keyed by the GUID of the RPE client) so that it can be reloaded after a subsystem restart, and its memory can be given to [qccdi8930.sys](./qccdi8930.md) for the crash dump through a query-interface.  
Build path found in the binary: `P:\PIL\rel\8.2.1.1\arm\Release\qcpil8930.pdb` (Mar 24 2014).  

Device name : `\Device\PIL`  
Symbolic link : `\DosDevices\PIL`  
SDDL : `D:P(A;;GA;;;SY)(A;;GA;;;BA)` (System and Administrators only)  
The device is not exclusive (`WdfDeviceInitSetExclusive(FALSE)`, several clients open it at the same time) and uses buffered I/O. Each handle has its own context (`PIL_FILE_CONTEXT`, see [Image loading](#image-loading)).  

The IOCTLs are received by the `EvtIoDeviceControl` callback (`sub_40E2D0`) of the default queue (sequential, not power managed): they are regular IOCTLs (`IRP_MJ_DEVICE_CONTROL`), not internal IOCTLs. An unknown code returns 0xC0000010 (STATUS_INVALID_DEVICE_REQUEST).  
A second, manual, queue holds the load requests waiting for the end of another load.  

> [!NOTE]
> Unloading the driver is not supported: the cleanup callback of the driver object (`sub_40E9F8`) calls `KeBugCheckEx(0x14E, 0x306C7071 'qpl0', 0, 0, 0)`.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcPILC`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0E00\2&daba3ff&0`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0053`

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcPILC\Parameters`:  
| Registry value | value | comment |
|----------------|-------|---------|
| TestState | 0 | REG_DWORD. State of the test mode, see [IOCTL 0x9C412414](#ioctl-0x9c412414). Read and written by `sub_40F5EC` |
| TestDataBasePath | `C:\PIL` | REG_SZ (max 520 bytes). Folder where the _pilraw_ files are created. Default `C:\PIL` |

At start (`EvtDriverDeviceAdd`), `TestState` is updated and written back:  
| `TestState` read | `TestState` written | Comment |
|------------------|---------------------|---------|
| 1 | 2 | Test mode requested before the reboot → test mode enabled for this boot |
| 2, 3, 4 | 5 | End of the test mode |
| other | unchanged | |

When `TestState` is 2 after this update (test mode), the driver neither publishes its device interfaces nor connects to the SCM device: only the "test" IOCTLs (which do not use the SCM) can work.

GUID of the ETW provider (manifest, `McGenEventRegister`):  
`{7B4111DD-3687-45E7-AD56-497FACDE0F85}`

GUID of the WPP control provider:  
`{4B2AE6CB-2AFC-4251-8DF6-55939744250F}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68} | qcscm8930.sys | Qualcomm Secure Channel Manager Device. Found with `IoRegisterPlugPlayNotification` on the interface class `{41C66D2A-A9F1-40CA-A329-AE096C03EE68}`, opened with `WdfIoTargetOpen` |

When the SCM interface arrives (work item `sub_40EDF0`), the driver:
1. opens an I/O target on the SCM device (`sub_40F05C`),
2. enables its second device interface `{E2EB84C1-4068-4994-A48F-F3AC0D38DC29}` (`sub_40EC74`),
3. queries the SCM query-interface `{999642D1-34E8-4759-AABB-29C62AB58627}` (size 20, version 1) and keeps its function at offset 0x10 (`sub_403668`). This function sends an SCM command synchronously without IRP; it is used by the PIL query-interface (see below) to send the "shutdown" command.

When the SCM interface is removed, the interface `{E2EB84C1-…}` is disabled.

### Image loading

The image of a client is stored in a `PIL_FILE_CONTEXT` (176 bytes) attached to the file object (handle) of the client:  
| Offset | Content |
|--------|---------|
| 0x0C-0x1B | GUID of the RPE client |
| 0x1C | Secured channel ID (PAS peripheral ID), 0xFFFFFFFF when the image is loaded without SCM |
| 0x20 | Path of the .mbn file (UNICODE_STRING, upper case) |
| 0x28 | Path of the .mbn file (ANSI_STRING) |
| 0x38-0x6B | ELF header (52 bytes) |
| 0x6C | Program headers |
| 0x7C-0x8B | Metadata buffer: MDL, virtual address, size, physical address |
| 0x90-0xA3 | Image buffer of a relocatable image: MDL, virtual address, physical address, size |
| 0xA4 | Virtual address of the entry point (`e_entry`) |
| 0xA8 | 1 = relocatable image (ET_REL) |
| 0xAC | 1 = image authenticated |

Steps of a load (`sub_401D00` parses the request, `sub_402C44` loads):
1. The ELF header is checked (`\x7FELF`, 32-bit, `sub_404CE0`) and the program headers are read.
2. The hash segment (program header whose `p_flags` has the Qualcomm segment type 2 = `0x02000000`) is located.
3. A physically contiguous buffer (`MmAllocatePagesForMdlEx`, flags 0x25) receives the **metadata**: ELF header + program headers + content of the hash segment. Its physical address is the parameter of the SCM command 0x801.
4. For an executable image (`e_type` = 2, the case of all the Lumia .mbn files), each `PT_LOAD` segment that is not the hash segment is mapped with `MmMapIoSpace(p_paddr, p_memsz, MmNonCached)` and read from the file at its physical address (the end of the segment, `p_memsz - p_filesz`, is zeroed).  
   For a relocatable image (`e_type` = 1), a contiguous buffer is allocated for the whole image and the entry point is relocated.
5. The physical address of the entry point is returned in the output buffer of the IOCTL (4 bytes, optional).

While a client has a loaded but not yet authenticated image (the GUID is copied in the device context at offset 0x0C), the other load requests are forwarded to a manual queue and processed only when this image is authenticated (IOCTL 0x9C412404 or 0x9C412410), when its load fails, or when the client closes its handle.  
After a successful authentication, the metadata buffer is freed and the context is copied in a global list (`dword_40BF0C`, protected by a wait lock) keyed by the GUID of the client. This saved context is used by the reload / unload IOCTLs and by the query-interface.

NTSTATUS values specific to the driver:  
| Value | Comment |
|-------|---------|
| 0xE0008000 | No image for this client (GUID unknown, or the pending image belongs to another handle) |
| 0xE0008001 | No hash segment / no metadata |
| 0xE0008002 | Cannot allocate the metadata buffer |
| 0xE0008003 | Cannot open the .mbn file |
| 0xE0008004 | Invalid ELF file, read error or cannot map a segment |
| 0xE0008005 | An image is already loaded for this client |
| 0xE0008007 | Query-interface `GetMemoryRuns`: cannot compute the memory range of the image |
| 0xE0008008 | Query-interface: the image has no secured channel ID |
| 0xE0008009 | The SCM device is not connected |
| 0xC0000190 | STATUS_TRUST_FAILURE: the TrustZone refused the command (result ≠ 1) |

In case of failure of the SCM commands, the driver also prints (`DbgPrintEx`) `pil: The ELF image failed initialization: <path>` or `pil: The ELF image failed authentication: <path>`.

---

### IOCTL 0x9C412400

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x900 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| test load image | 536 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | GUID of the RPE client (e.g. `{93367D0F-35CE-4EC4-8E38-BB33030C58B2}`) |
| 10-217 | | Null terminated WCHAR path of the .mbn file (e.g. `\SystemRoot\system32\qcwcnss8930.mbn`) |

Outputbuffer (optional):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 28 12 00 8f | Physical address of the entry point of the image (e.g. 0x8F001228 for the WCNSS) |

This command parses and loads the .mbn file in memory but doesn't communicate with the SCM device (the secured channel ID is set to 0xFFFFFFFF, so the image can't be authenticated with 0x9C412410).  
When `TestState` is 3, the _pilraw_ files are written after the load (see [IOCTL 0x9C41241C](#ioctl-0x9c41241c--ioctl_pil_tz_load_image)).  
Returns 0xE0008005 if an image is already saved for this client.

---

### IOCTL 0x9C412404

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x901 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| force authenticate | 0 | 0 |

The input buffer is ignored: the command applies to the image loaded through the same handle.  
It sets to 1 the flag "authenticated" (offset 0xAC of the file context, `sub_403A48`) **without** asking the TrustZone, frees the metadata buffer and saves the image in the global list, exactly like a successful 0x9C412410.  
Returns 0xE0008000 if this handle has no pending image.  

---

### IOCTL 0x9C412408

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x902 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| unload image | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | GUID of the RPE client |

This command retrieves the image saved for this client. If the image has a secured channel ID, it sends the SCM command [0x806 "Shutdown"](#command-0x806-shutdown) (`sub_403EC0`) for this channel. Then the memory of the image is released and the image is removed from the global list (`sub_402568`).  

NTSTATUS returned:  
| Value | Comment |
|-------|---------|
| 0xC000000D | Input buffer empty |
| 0xC000009A | Input buffer smaller than 16 bytes |
| 0xE0008000 | No image saved for this client |

---

### IOCTL 0x9C41240C

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x903 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| test reload image | 16 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | GUID of the RPE client |

Outputbuffer (optional):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ?? ?? ?? ?? | Physical address of the entry point of the image |

This command releases the image saved for this client and loads again the same .mbn file (path saved with the image), but doesn't communicate with the SCM device.  
Returns 0xE0008000 if no image is saved for this client.

---

### IOCTL 0x9C412410 — IOCTL_PIL_TZ_AUTH_IMAGE_AND_RESET

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PIL_TZ_AUTH_IMAGE_AND_RESET | 0 | 0 |

The input buffer is ignored ([qcwcn8930.sys](./qcwcn8930.md) sends an empty buffer): the command applies to the image loaded (0x9C41241C or 0x9C412420) through the same handle.  
It sends the SCM command [0x805 "Auth and reset"](#command-0x805-auth-and-reset) (`sub_403AB4`) with the secured channel ID of the image: the TrustZone checks the segments against the hash segment and starts the subsystem.  
On success, the metadata buffer is freed and the image is saved in the global list (it can then be reloaded or unloaded). On failure, the image is released.

NTSTATUS returned:  
| Value | Comment |
|-------|---------|
| 0xE0008000 | This handle has no pending image ("no image to authenticate") |
| 0xC000000D | The image has no secured channel ID (loaded with 0x9C412400 / 0x9C41240C) |
| 0xE0008001 | No metadata |
| 0xE0008009 | SCM device not connected |
| 0xC0000190 | Authentication refused by the TrustZone |

---

### IOCTL 0x9C412414

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x905 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| set TestState | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Request, between 1 and 4 |

Depending on the current value of `TestState`, it sets `TestState` to a new value and writes it in the registry (`sub_40F5EC`):  
| InputBuffer value | Current `TestState` | New `TestState` |
|-------------------|---------------------|-----------------|
| 1 | 0 or 5 | 1 |
| 2 | 2 | 3 |
| 3 | 2 | 4 |
| 4 | any | 0 |

Any other combination returns 0xC000000D (STATUS_INVALID_PARAMETER).

| `TestState` | Comment |
|-------------|---------|
| 0 | Test mode disabled (default) |
| 1 | Test mode requested. At the next start of the driver, `TestState` is set to 2 by `EvtDriverDeviceAdd` |
| 2 | Test mode enabled: no device interface, no connection to the SCM |
| 3 | When loading a .mbn file (with 0x9C412400 or 0x9C41241C), it writes the _pilraw_ files in the folder indicated by `TestDataBasePath` |
| 4 | ? (not used elsewhere in the driver) |
| 5 | Test mode finished (set at start when `TestState` was 2, 3 or 4) |

---

### IOCTL 0x9C412418

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x906 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| get TestState | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Current value of `TestState` |

---

### IOCTL 0x9C41241C — IOCTL_PIL_TZ_LOAD_IMAGE

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x907 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PIL_TZ_LOAD_IMAGE | 540 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | GUID of the RPE client |
| 10-13 | 06 00 00 00 | Secured channel ID (PAS peripheral ID) of the subsystem |
| 14-21B | | Null terminated WCHAR path of the .mbn file |

Outputbuffer (optional):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 28 12 00 8f | Physical address of the entry point of the image (e.g. 0x8F001228 for the WCNSS) |

This command parses and loads the .mbn file in memory (see [Image loading](#image-loading)), then sends the SCM command [0x801 "Init image"](#command-0x801-init-image) (`sub_4037C8`) with the physical address of the metadata. The client must then send 0x9C412410 to authenticate the image and reset the subsystem.  

NTSTATUS returned:  
| Value | Comment |
|-------|---------|
| 0xC000000D | Input buffer empty |
| 0xE0008005 | An image is already saved for this client ("image already loaded") |
| 0xE0008001 to 0xE0008004 | Load error, see the table above |
| 0xE0008009 | SCM device not connected |
| 0xC0000190 | Init refused by the TrustZone |

Images loaded on a Lumia 520:  
| GUID RPE client | Secured channel ID | .mbn file path | file size (in bytes) | IoCtl sent by |
|-----------------|--------------------|----------------|----------------------|---------------|
| {d58464d3-5b28-4ea6-a2e2-e8e57c5c69b8} | 0x00000001 | `\SystemRoot\system32\qcadsp8930.mbn` | 6091904 | qcadsp8930.sys |
| {936dc601-5530-4b82-9d2a-72a488bec7c1} | 0x00000004 | `\SystemRoot\system32\qcdsp28930.mbn` | 29776208 | qcamss8930.sys |
| {ba58766d-abf2-4402-88d7-90ab243f6c77} | 0x00000005 | `\SystemRoot\system32\qcdsp1v18930.mbn` | 2839752 | qcamss8930.sys |
| {93367d0f-35ce-4ec4-8e38-bb33030c58b2} | 0x00000006 | `\SystemRoot\system32\qcwcnss8930.mbn` | 2007056 | qcwcn8930.sys |

The channel IDs are the PAS peripheral IDs of the Qualcomm TrustZone (1 = Q6/ADSP, 4 = modem SW, 5 = modem FW, 6 = WCNSS).

#### _pilraw_ files generated with `TestState` 3

Written by `sub_40D318` in the folder `TestDataBasePath`. File name formats (from the binary):  
`\??\%ls%lspilrawHash%.2d-0x%.8X.bin`  
`\??\%ls%lspilraw%.2d-0x%.8X.bin`  

For an executable image, one file is written per `PT_LOAD` segment (`sub_40D5EC`):
- _NN_ is the index of the program header,
- _AAAAAAAA_ is the physical address of the segment (`p_paddr`),
- the _Hash_ file corresponds to the hash segment and contains the metadata (ELF header + program headers + hash segment, with the security certificates).

For a relocatable image, a single file (index 00) contains the whole image (`sub_40D3F4`).

Files generated when loading the 4 images above (the indexes restart at 01 for each image):  
| File name | size (in bytes) |
|-----------|-----------------|
| pilrawHash01-0x9F015114.bin | 12288   |
| pilrawHash01-0x9F4970F4.bin | 8608    |
| pilrawHash01-0x9FE8B194.bin | 8708    |
| pilrawHash01-0x9FF2E414.bin | 9108    |
| pilraw02-0x28400000.bin     | 65536   |
| pilraw02-0x89000000.bin     | 1048660 |
| pilraw02-0x8D400000.bin     | 2676    |
| pilraw02-0x8F000000.bin     | 9812    |
| pilraw03-0x89100060.bin     | 5729776 |
| pilraw03-0x8D4F8000.bin     | 1038704 |
| pilraw03-0x8DA00000.bin     | 4516016 |
| pilraw03-0x8F010000.bin     | 28672   |
| pilraw04-0x89676E50.bin     | 7468904 |
| pilraw04-0x8D5F6000.bin     | 638524  |
| pilraw04-0x8DE4F000.bin     | 1291574 |
| pilraw04-0x8F017000.bin     | 4096    |
| pilraw05-0x89DC0000.bin     | 16384   |
| pilraw05-0x8D693000.bin     | 2066880 |
| pilraw05-0x8DF8C000.bin     | 245776  |
| pilraw05-0x8F018000.bin     | 4361200 |
| pilraw06-0x89E00000.bin     | 8919408 |
| pilraw06-0x8D900000.bin     | 94208   |
| pilraw06-0x8E000000.bin     | 1688448 |
| pilraw07-0x8A700000.bin     | 5347546 |
| pilraw07-0x8D940000.bin     | 87296   |
| pilraw08-0x8AC1B000.bin     | 29591616|
| pilraw08-0x8D401000.bin     | 11436   |
| pilraw09-0x8C854000.bin     | 79600   |
| pilraw09-0x8D403CC0.bin     | 9692    |
| pilraw10-0x8C868000.bin     | 162128  |
| pilraw10-0x8D4064C0.bin     | 68423   |
| pilraw11-0x8D418000.bin     | 4088    |
| pilraw13-0x8D424000.bin     | 117708  |
| pilraw14-0x8D440BE0.bin     | 153188  |
| pilraw21-0x8D41A000.bin     | 3572    |
| pilraw22-0x8D494000.bin     | 28348   |
| pilraw23-0x8D49AEC0.bin     | 20208   |
| pilraw25-0x8D4B0000.bin     | 74640   |
| pilraw26-0x8D4C23A0.bin     | 50396   |
| pilraw27-0x8D4CE880.bin     | 10560   |
| pilraw29-0x8D4E0000.bin     | 91336   |

---

### IOCTL 0x9C412420 — IOCTL_PIL_TZ_RELOAD_IMAGE

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x908 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PIL_TZ_RELOAD_IMAGE | 20 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | GUID of the RPE client |
| 10-13 | 06 00 00 00 | Secured channel ID of the subsystem |

Outputbuffer (optional):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 28 12 00 8f | Physical address of the entry point of the image |

Used to restart a subsystem (e.g. after a crash of the WCNSS). The command retrieves the image saved for this client, sends the SCM command [0x806 "Shutdown"](#command-0x806-shutdown) for the saved channel, releases the image, loads again the same .mbn file (path saved with the image) and sends the SCM command [0x801 "Init image"](#command-0x801-init-image) with the new channel ID. The client must then send 0x9C412410.

NTSTATUS returned:  
| Value | Comment |
|-------|---------|
| 0xE0008000 | No image saved for this client ("no image to reload") |
| other | Same as 0x9C41241C |

---

### IOCTL 0x9C412424

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x909 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| set TestDataBasePath | 520 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-207 | | Null terminated WCHAR path |

The input buffer is the new value of `TestDataBasePath`. It is written in the registry (`sub_40F5EC`).

---

### IOCTL 0xC3514004

This IOCTL is sent by Qcpil8930.sys to qcscm8930.sys (as an internal IOCTL, `WdfIoTargetSendInternalIoctlSynchronously`)

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x1 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Send SCM command | \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68} | 24 or 20 | same as InputBuffer (same buffer) |

The buffer looks like the legacy Qualcomm `scm_command` structure (length, offset of the arguments, response, command ID, arguments). The command ID is `(service << 10) | command` with service 2 = PIL/PAS. The command succeeds only if the request succeeds **and** the result returned at offset 0x08 is 1; otherwise 0xC0000190 is returned.

#### Command 0x801 "Init image"

PAS_INIT_IMAGE: gives the metadata (ELF header + program headers + hash segment) of the image to the TrustZone. Built by `sub_403698`, sent by `sub_4037C8`.

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 18 00 00 00 | Length of the buffer (24) |
| 04-07 | 10 00 00 00 | Offset of the arguments ? |
| 08-0B | 00 00 00 00 | Result |
| 0C-0F | 01 08 00 00 | Command |
| 10-13 | 06 00 00 00 | Secured channel ID |
| 14-17 | ?? ?? ?? ?? | Physical address of the metadata buffer |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | | unchanged |
| 08-0B | 01 00 00 00 | Result: 1 = success |
| 0C-17 | | unchanged |

#### Command 0x805 "Auth and reset"

PAS_AUTH_AND_RESET: authenticates the loaded segments and takes the subsystem out of reset. Sent by `sub_403AB4`.

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 14 00 00 00 | Length of the buffer (20) |
| 04-07 | 10 00 00 00 | Offset of the arguments ? |
| 08-0B | 00 00 00 00 | Result |
| 0C-0F | 05 08 00 00 | Command |
| 10-13 | 06 00 00 00 | Secured channel ID |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 08-0B | 01 00 00 00 | Result: 1 = authentication successful |

#### Command 0x806 "Shutdown"

PAS_SHUTDOWN: stops the subsystem and unlocks its (xPU protected) memory. Sent by `sub_403EC0` before a reload or an unload, or directly through the function of the SCM query-interface by `sub_403D9C` (query-interface of the PIL).

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 14 00 00 00 | Length of the buffer (20) |
| 04-07 | 10 00 00 00 | Offset of the arguments ? |
| 08-0B | 00 00 00 00 | Result |
| 0C-0F | 06 08 00 00 | Command |
| 10-13 | 06 00 00 00 | Secured channel ID |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 08-0B | 01 00 00 00 | Result: 1 = success |

---

### Interface GUID

PIL interface class (published at start, unless `TestState` is 2; used by [qccdi8930.sys](./qccdi8930.md))  
`{20E0709D-AF59-4CE8-9D91-39E11B4C0231}`

Second PIL interface class (enabled only while the SCM device is available)  
`{E2EB84C1-4068-4994-A48F-F3AC0D38DC29}`

### Query-interface

`{2872B2FA-2469-4862-BAB8-FB47D7A12EF9}`, size 24, version 1 (`WdfDeviceAddQueryInterface` in `EvtDriverDeviceAdd`). Used by [qccdi8930.sys](./qccdi8930.md#pil-interface). InterfaceReference / InterfaceDereference are no-op (`nullsub_1`).  
| Offset | Function | Comment |
|--------|----------|---------|
| 0x10 | `sub_404448(GUID *Client, ULONG Protection)` | Protection = 1 returns 0xC000000D. Otherwise, sends the SCM command 0x806 "Shutdown" for the image saved for this client, which unlocks the xPU protected memory. Returns 0xE0008000 (unknown client) or 0xE0008008 (no channel ID). Doesn't take the wait lock above DISPATCH_LEVEL, so it can be called during a crash |
| 0x14 | `sub_4045DC(GUID *Client, RUNS *Runs)` | Returns a single memory run covering the segments of the image. When `Runs->Buffer` (offset 0x10) is NULL, only the number of runs (1) is returned. Otherwise the run (24 bytes) receives the physical address, the virtual address (`MmMapIoSpace`) and the number of pages |

`RUNS` structure:  
| Bytes | Comment |
|-------|---------|
| 00-07 | Number of runs (1) |
| 08-0F | Total number of pages |
| 10-13 | Pointer to the array of runs (24 bytes per run: physical address (8 bytes), virtual address (4 bytes), ?, number of pages (8 bytes)) |
