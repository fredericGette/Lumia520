## Acpi.sys

Microsoft ACPI bus driver (Windows Phone 8.x ARM build, PDB symbols available).  
It loads the firmware ACPI tables (DSDT/SSDT…), runs the AML interpreter (AMLI), and enumerates every ACPI device node as a PDO (`ACPI\<_HID>`). On the Lumia 520 nearly all the Qualcomm drivers (`ACPI\QCOMxxxx`) sit on top of an acpi.sys PDO, and use it to evaluate their own ACPI methods: `PMCF` for [qcpmic8930.sys](./qcpmic8930.md#acpi-pmcf) and [qcbms8930.sys](./qcbms8930.md), `_GRT`/`_SRT`/`_GCP`… for [acpitime.sys](./acpitime.md).  
It also attaches as a filter on the ACPI-described devices, handles power (`_PSx`, `_PRx`, `_SxW`), thermal zones, fans, buttons and processors, and forwards GPIO/SPB connection resources to the Resource Hub (`acpiex.sys`).

Symbolic link : `\DosDevices\ACPI_ROOT_OBJECT` (created by `ACPICreateRootSymbolicLink` on the ACPI root device, target = its PDO name)  
The PDOs and filter devices themselves are unnamed (`IoCreateDevice` in `ACPIBuildPdo`, `ACPIBuildFilter`, `ACPIDispatchAddDevice`).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\ACPI`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\<_HID>\<instance>` (one per ACPI device node)  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI_HAL\PNP0C08\0` (ACPI root device: parent of the `ACPI\…` devices, e.g. `\_SB.AGR0` of [acpipagr.sys](./acpipagr.md#lumia-520-device-node))

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\ACPI\Parameters` (read with `OSReadRegValue`, which uses this key when no handle is given):  
| Registry value | value | comment |
|----------------|-------|---------|
| Attributes | 0 | REG_DWORD, OR'ed into `AcpiOverrideAttributes` (`ACPIInitReadRegistryKeys`). Bit 0x10000 is masked out: it can't be set from here |
| AMLIInitFlags | 0 | REG_DWORD, `gAMLIInitFlags` passed to `AMLIInitialize` |
| AMLIMaxCTObjs | 0 | REG_DWORD, maximum number of AML context objects |
| PCIDeviceExclusionMask | ? | `IrqPolicyConfigure` |
| IRQDistribution | ? | `IrqPolicyGetDistributionDisposition` |
| ForcePCIBootConfig | ? | `IrqPolicyGetDistributionDisposition` |
| WHEAOSCImplemented, APEIOSCGranted | — | **Written** by `ACPIWriteOscSupportToRegistry` (PCI root `_OSC`, not used on the phone) |
| `<SIG>\<OEMID>\<OEMTableID>\<rev>` | — | ACPI table override, see [Table override](#acpi-table-override-from-the-registry) |
| NamespaceOverride\\… | — | AML namespace override (`OSOpenAMLINamespaceOverrideHandle`, subkeys `DSDT`, `\%lu`). Only used when `gOverrideFlags` bit 0x20 is set by an Errata Manager rule (`GUID_EM_RULE_AMLI_USE_NAMESPACE_OVERRIDE` ?) |
| Simulator\\Tables | — | Tables of the ACPI simulator (`ACPIRegGetTableFromSimulatorRegistryEntry`), only when `AcpiOverrideAttributes` bit 0x10000 (test signing) is set |

Other registry values:  
| Key | Registry value | comment |
|-----|----------------|---------|
| `HKLM\SYSTEM\CurrentControlSet\Control\ACPI` | AMLIGlobalHeapSize | REG_DWORD, AML global heap size. Default 0x10000, clamped to 0x8000–0x800000 (`ACPIInitGlobalHeapSize`) |
| `HKLM\SYSTEM\CurrentControlSet\Control` | SystemStartOptions | Boot options string. `PCIEXPRESSPOLICY=FORCEDISABLE` → attribute 0x2000, `SBOSCEVALPOLICY=FORCEDISABLE` → 0x4000, `TESTSIGNING` → **0x10000** (enables the registry table override and the simulator) |
| `HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0` | Identifier, VendorIdentifier | Read at start, formatted as `"%s - %s"` (processor name used for `_OSI` / processor objects ?) |
| `HKLM\HARDWARE\DESCRIPTION\System\MultiFunctionAdapter\*` | Identifier = `ACPI BIOS`, Configuration Data | Location of the RSDP given by the boot loader (`OSReadAcpiConfigurationData`) |
| `HKLM\SYSTEM\CurrentControlSet\Control\Arbiters` | AllocationOrder, ReservedResources, InaccessibleRange | Resource arbiters |
| `HKLM\SYSTEM\CurrentControlSet\Services\ACPI\DSMFailures` | — | ? |

GUID of the ETW provider:  
`{C514638F-7723-485B-BCFC-96565D735D4A}` (Microsoft-Windows-Kernel-ACPI, `ACPI_ETW_PROVIDER`)  
`{E8A7C168-81EE-465C-8E8E-D39A2AC1CA41}` (thermal-zone polling, `THERMAL_POLLING_ETW_PROVIDER`)  
Both registered by `AcpiDiagInitialize`.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\RESOURCE_HUB` | acpiex.sys | Resource Hub. Opened by `QueryExternalTranslatorInterface`; if missing after boot, the driver loads `\Registry\Machine\System\CurrentControlSet\Services\acpiex` with `ZwLoadDriver`. Receives IOCTL 0x2AC028 (see below) |
| Thermal sensor device | ? | `ACPIThermalGetSensorDevice` (`IoRegisterPlugPlayNotification` + `ZwCreateFile`) for thermal zones with an external temperature sensor |
| Child PDOs `ACPI\*` | qcpmic8930.sys, qcbms8930.sys, acpitime.sys, … | Callers of the `IOCTL_ACPI_*` controls below |

### ACPI table override from the registry

`ACPIRegReadAMLRegistryEntry` (called by `ACPILoadProcessRSDT`, `ACPILoadProcessDSDT`, `ACPIMapNamedTable`) can replace a firmware table with a copy stored in the registry, **only when the phone is booted with `TESTSIGNING`** (`AcpiOverrideAttributes` bit 0x10000):

1. Key `HKLM\SYSTEM\CurrentControlSet\Services\ACPI\Parameters\<Signature>\<OEMID>\<OEMTableID>` (e.g. `DSDT\QCOMM \MSM8930 ` for the Lumia 520 DSDT, or `SSDT\NOKIA \MSM8930 ` for its Nokia SSDT, the fields are copied with their padding: 4, 6 and 8 characters).
2. `OSOpenLargestSubkey` opens the subkey with the largest number not above the table's OEM revision (subkey name = revision, hex ?).
3. The value `Action` (REG_DWORD) must be 0.
4. `ACPIRegReadEntireAcpiTable` reads the table from the values `00000000`, `00000001`, … (`%08lx`) and concatenates them.

This looks like the format used by `asl.exe /loadtable` on desktop Windows (not verified on the phone).

> [!NOTE]
> The IOCTLs below are meant to be sent by the function driver of an ACPI device to its own PDO (`IoCallDriver` down the stack, `IRP_MJ_DEVICE_CONTROL` or `IRP_MJ_INTERNAL_DEVICE_CONTROL`, both go to `ACPIIrpDispatchDeviceControl`).  
> A request coming from **user mode** is only executed when it is issued by a UMDF driver (`Irp->Flags & IRP_UM_DRIVER_INITIATED_IO` 0x400000) and is one of 0x32C000, 0x32C004, 0x32C018, 0x32C01C, 0x32C020, 0x32C024, 0x32C028 — or when it is 0x32C000 sent to the ACPI root device by a caller holding `SeTcbPrivilege`. Any other user-mode request is passed down / completed without being processed.  
> Method names are resolved relative to the ACPI node of the device the IRP is sent to; the Ex variants check that the full path is inside that scope (`AMLIIsObjectInGivenScope`).

Common NTSTATUS:  
| Value | Comment |
|-------|---------|
| 0xC0000004 STATUS_INFO_LENGTH_MISMATCH | InputBuffer too small |
| 0xC0000023 STATUS_BUFFER_TOO_SMALL | OutputBuffer too small (input checks) |
| 0x80000005 STATUS_BUFFER_OVERFLOW | Output too small for the result: the header (signature, required length, count) is written, `Information` = 20 |
| 0xC00000EF STATUS_INVALID_PARAMETER_1 | Unknown input signature |
| 0xC000000E STATUS_NO_SUCH_DEVICE | Device has no ACPI namespace object |
| 0xC014000F STATUS_ACPI_INVALID_DATA ? | Invalid flags / signature (enum children, op-region, firmware lock) |

---

### IOCTL 0x32C000 — IOCTL_ACPI_ASYNC_EVAL_METHOD
### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

These IOCTLs are processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 (FILE_DEVICE_ACPI) |
| Function | 0x0 / 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_ASYNC_EVAL_METHOD / IOCTL_ACPI_EVAL_METHOD | ≥ 8 | 0 or ≥ 20 |

Handlers: `ACPIIoctlAsyncEvalControlMethod` / `ACPIIoctlEvalControlMethod`, both use `ACPIIoctlEvalPreProcessing` (0x12EEC) then `AMLIAsyncEvalObject` / `AMLIEvalNameSpaceObject`. The async variant returns `STATUS_PENDING` and completes in `ACPIIoctlAsyncEvalControlMethodCompletion`. This is the IOCTL used by qcpmic8930.sys and qcbms8930.sys to evaluate `PMCF`.

Inputbuffer, one of 4 formats selected by the signature:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 69 42` 'AeiB' | ACPI_EVAL_INPUT_BUFFER: no argument |
| 00-03 | `41 65 69 49` 'AeiI' | ACPI_EVAL_INPUT_BUFFER_SIMPLE_INTEGER: one integer argument |
| 00-03 | `41 65 69 53` 'AeiS' | ACPI_EVAL_INPUT_BUFFER_SIMPLE_STRING: one string argument |
| 00-03 | `41 65 69 43` 'AeiC' | ACPI_EVAL_INPUT_BUFFER_COMPLEX: list of arguments |
| 04-07 | e.g. `50 4D 43 46` "PMCF" | Method name (4 characters, relative to the device node) |
| 08-0B | | 'AeiI': integer argument. 'AeiS': string length. 'AeiC': total size |
| 0C-… | | 'AeiS': string. 'AeiC': argument count (4 bytes), then the arguments (ACPI_METHOD_ARGUMENT, see below) from offset 0x10 |

ACPI_METHOD_ARGUMENT (input and output):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | | Type: 0 = integer, 1 = string, 2 = buffer, 3 = package (Ex only, also accepted as 4 in input) |
| 02-03 | | DataLength |
| 04-… | | Data (integer = 4 bytes; strings/buffers are padded to at least 4 bytes). Next argument at `4 + max(DataLength, 4)` |

Outputbuffer (`ACPIIoctlEvalPostProcessing`, ACPI_EVAL_OUTPUT_BUFFER):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 6F 42` 'AeoB' | Signature |
| 04-07 | | Length: total size needed (at least 20) |
| 08-0B | | Count: number of arguments (package elements are flattened as arguments) |
| 0C-… | | ACPI_METHOD_ARGUMENT list |

With an OutputBuffer of size 0 the result is discarded and `STATUS_SUCCESS` is returned.

---

### IOCTL 0x32C008 — IOCTL_ACPI_REGISTER_OPREGION_HANDLER

This IOCTL is processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x2 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_REGISTER_OPREGION_HANDLER | ≥ 20 | ≥ 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 6F 48` 'AeoH' | Signature (0x486F6541) |
| 04-07 | 01 00 00 00 | AccessType (acpiex.sys uses 1) |
| 08-0B | | RegionSpace (acpiex.sys registers 8 = GeneralPurposeIO and 9 = GenericSerialBus) |
| 0C-0F | | Handler function pointer |
| 10-13 | | Context ? |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 72 6F 48` 'AroH' | Signature |
| 04-07 | | Handle of the registered handler (to pass to the unregister IOCTL) |

Backend: `RegisterOperationRegionHandler`. Kernel pointers in the buffer: kernel-mode only. On the Lumia this is used by [acpiex.sys](./acpiex.md#operation-regions).

---

### IOCTL 0x32C00C — IOCTL_ACPI_UNREGISTER_OPREGION_HANDLER

This IOCTL is processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x3 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_UNREGISTER_OPREGION_HANDLER | ≥ 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 75 6F 48` 'AuoH' | Signature (not checked) |
| 04-07 | | Handle returned by IOCTL 0x32C008 |

---

### IOCTL 0x32C010 — IOCTL_ACPI_ACQUIRE_GLOBAL_LOCK
### IOCTL 0x32C014 — IOCTL_ACPI_RELEASE_GLOBAL_LOCK

These IOCTLs are processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x4 / 0x5 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_ACQUIRE_GLOBAL_LOCK | not checked | ≥ 8 |
| IOCTL_ACPI_RELEASE_GLOBAL_LOCK | ≥ 8 | 0 |

Buffer (ACPI_MANIPULATE_GLOBAL_LOCK_BUFFER):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 61 67 4C` 'AagL' / `41 72 67 4C` 'ArgL' | Signature: acquire / release |
| 04-07 | | LockObject: returned by acquire (16-byte pool block, tag `AcgL`), passed back to release |

Acquire may return `STATUS_PENDING` (`ACPIAsyncAcquireGlobalLock`). The ACPI global lock (FACS) is probably meaningless on the phone (hardware-reduced ACPI ?).

---

### IOCTL 0x32C018 — IOCTL_ACPI_EVAL_METHOD_EX
### IOCTL 0x32C01C — IOCTL_ACPI_ASYNC_EVAL_METHOD_EX

These IOCTLs are processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x6 / 0x7 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD_EX / IOCTL_ACPI_ASYNC_EVAL_METHOD_EX | ≥ 260 | 0 or ≥ 20 |

Same as 0x32C004 / 0x32C000 but the method is given by a path of up to 256 characters (upper-cased by the driver), so a child's method can be evaluated. Handlers: `ACPIIoctlEvalControlMethodEx`, `ACPIIoctlAsyncEvalControlMethodEx`, `ACPIIoctlEvalPreProcessingEx`, `ACPIIoctlEvalPostProcessingEx`.

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 69 41` 'AeiA' | ACPI_EVAL_INPUT_BUFFER_V1_EX: no argument |
| 00-03 | `41 65 69 44` 'AeiD' | ACPI_EVAL_INPUT_BUFFER_SIMPLE_INTEGER_V1_EX |
| 00-03 | `41 65 69 45` 'AeiE' | ACPI_EVAL_INPUT_BUFFER_SIMPLE_STRING_V1_EX |
| 00-03 | `41 65 69 46` 'AeiF' | ACPI_EVAL_INPUT_BUFFER_COMPLEX_V1_EX |
| 04-103 | e.g. `\_SB.PMIC.PMCF` | Method path, NUL-terminated ASCII (256 bytes) |
| 104-107 | | 'AeiE': string length. 'AeiF': total size |
| 108-… | | 'AeiD': 64-bit integer (108-10F). 'AeiE': string. 'AeiF': argument count, then the arguments from 0x10C |

Outputbuffer: same as 0x32C004 (signature 'AeoB'), integers are 64-bit (`ACPIIoctlCalculateOutputBufferSizeEx`).

---

### IOCTL 0x32C020 — IOCTL_ACPI_ENUM_CHILDREN

This IOCTL is processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x8 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_ENUM_CHILDREN | ≥ 16 | ≥ 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 69 48` 'AeiH' | Signature |
| 04-07 | | Flags: 1 = immediate children only, 2 = multilevel, 4 = name is a filter. 1 and 2 are exclusive; 4 requires a name |
| 08-0B | | NameLength |
| 0C-… | | Name (ASCII, upper-cased by the driver) |

Outputbuffer (`ACPIIoctlEnumChildrenPopulateOutputBuffer`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 69 47` 'AeiG' | Signature |
| 04-07 | | NumberOfChildren, or the required size when `STATUS_BUFFER_OVERFLOW` |
| 08-… | | Per child: Flags (4 bytes, 1 = has children), NameLength (4 bytes, including the NUL), Name |

Useful to dump the ACPI namespace below a Lumia device node.

---

### IOCTL 0x32C024 — IOCTL_ACPI_QUERY_DEVICE_BIOS_NAME (?)

This IOCTL is processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x9 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | name length + 2 |

Backend: `ACPIIoctlQueryDeviceBiosName` → `ACPIQueryDeviceBiosName`. Returns the full ACPI path of the device (e.g. `\_SB.xxxx`), as a NUL-terminated UTF-16 string (acpiex.sys reads it as one). `STATUS_BUFFER_TOO_SMALL` when the output is too small (nothing returned).

---

### IOCTL 0x32C028 — IOCTL_ACPI_GET_DEVICE_INFORMATION

This IOCTL is processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0xA |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_GET_DEVICE_INFORMATION | 0 | ≥ 32 + strings |

Outputbuffer (`ACPIIoctlGetDeviceInformation`, strings appended after the 32-byte header):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 69 4A` 'AeiJ' | Signature |
| 04-05 | | Size (total). When the buffer is too small (but ≥ 6) only this field is written, with `STATUS_BUFFER_OVERFLOW` |
| 06 | 00 | Revision |
| 08-09 | 20 00 | Offset of the vendor id string (`_HID` without the `ACPI\` prefix, e.g. `QCOM...`) |
| 0A-0B | | Length of the `_HID` string |
| 0C-0D | | Offset of the device id part (vendor + 4 for a 4-letter ACPI id, + 3 for a PNP id) |
| 0E-0F, 10-11, 12-13 | | `_SUB` string: offset, length, offset + 4 ? (only if present) |
| 14-15, 16-17 | | Length and offset of a third string (`_UID` ?) |
| 18-19, 1C, 1E-1F | | `_CLS` class / subclass / prog-if ? |
| 1A-1B | | `_HRV` hardware revision ? |

---

### IOCTL 0x32C02C — IOCTL_ACPI_TRANSLATE_BIOS_RESOURCES (?)

This IOCTL is processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0xB |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | > 0 | ≥ 8 |

Input: an ACPI resource template (`_CRS`-like byte stream). Converted by `PnpBiosResourcesToNtResources`; output is a CM_PARTIAL_RESOURCE_LIST (Version, Revision, Count, then 32 bytes ... per descriptor — `8 + 32 × Count` on ARM ?). Too small → only the 8-byte header + `STATUS_BUFFER_OVERFLOW`.

---

### IOCTL 0x32C030 — register device firmware lock (?)
### IOCTL 0x32C034 — unregister device firmware lock (?)

These IOCTLs are processed by Acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0xC / 0xD |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| register | ≥ 24 | 0 |
| unregister | ≥ 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 44 66 52` 'ADfR' / `41 44 66 55` 'ADfU' | Signature: register / unregister |
| 04-05 | 01 00 | Version (must be non-zero) |
| 08-0B | 84 00 00 00 | Register: resource type handled (0x84 = `CmResourceTypeConnection`, value used by acpiex.sys). Unregister: parameter 1 |
| 0C-0F | | Unregister: parameter 2 |
| 10-13 | | Register: handler (`RhpDeviceFirmwareLockHandler` for acpiex.sys) |
| 14-17 | | Register: context |

Only known user: [acpiex.sys](./acpiex.md#device-firmware-lock).

---

### IOCTL 0x2AC028 — query Resource Hub translator interface

This IOCTL is sent by Acpi.sys to acpiex.sys

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0xA |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ? | `\Device\RESOURCE_HUB` | 56 | 56 |

Sent by `QueryExternalTranslatorInterface` to the top of the `\Device\RESOURCE_HUB` stack. The same 56-byte buffer is used in both directions (details of the returned interface in [acpiex.sys](./acpiex.md#ioctl-0x2ac028--query-translator-interface)):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 38 00 | Size (56) |
| 02-03 | 01 00 | Version |
| 10-11 | 28 00 | Offset of the ACPI block (28-37) |
| 1C-1F | | Returned: `RhTranslateBiosToNtResources`, must be non-zero |
| 28-2B | | ACPI root PDO (acpiex.sys opens an I/O target on it) |
| 2C-2F | | `AcpiExternalInterfaceUnload` |
| 30-33 | | `AcpiGetFullyQualifiedBiosName` |
| 34-37 | | `AcpiAllocateGsivForSecondaryInterrupt` (GPIO interrupts are given secondary GSIVs) |

On success the returned interface is kept by `RegisterExternalTranslatorInterface`: this is how GPIO-based interrupts (`GpioInt` in `_CRS`) of the Lumia devices are translated.

---

### Interface GUID

Interfaces returned through `IRP_MN_QUERY_INTERFACE` (`ACPIBusIrpQueryInterface`, `ACPIFilterIrpQueryInterface`, `ACPIRootIrpQueryInterface`):  
| Name | GUID |
|------|------|
| GUID_ACPI_INTERFACE_STANDARD | `{B091A08A-BA97-11D0-BD14-00AA00B7B32A}` |
| GUID_ACPI_INTERFACE_STANDARD2 | `{E8695F63-1831-4870-A8CF-9C2F03F9DCB5}` |
| GUID_ACPI_CMOS_INTERFACE_STANDARD | `{3A8D0384-6505-40CA-BC39-56C15F8C5FED}` |
| GUID_ACPI_PORT_RANGES_INTERFACE_STANDARD | `{F14F609B-CBBD-4957-A674-BC00213F1C97}` |
| GUID_PNP_LOCATION_INTERFACE | `{70211B0E-0AFB-47DB-AFC1-410BF842497A}` |
| GUID_D3COLD_SUPPORT_INTERFACE | `{B38290E5-3CD0-4F9D-9937-F5FE2B44D47A}` |
| GUID_THERMAL_COOLING_INTERFACE | `{ECBE47A8-C498-4BB9-BD70-E867E0940D22}` |
| GUID_PCC_INTERFACE_STANDARD | `{3EE8BA63-0F59-4A24-8A45-35808BDD1249}` |
| GUID_PCC_INTERFACE_INTERNAL | `{7CCE62CE-C189-4814-A6A7-12112089E938}` |
| GUID_PARTITION_UNIT_INTERFACE_STANDARD | `{52363F5B-D891-429B-8195-AEC5FEF6853C}` |
| GUID_ARBITER_INTERFACE_STANDARD | `{E644F185-8C0E-11D0-BECF-08002BE2092F}` |
| GUID_TRANSLATOR_INTERFACE_STANDARD | `{6C154A92-AACF-11D0-8D2A-00A0C906B244}` |
| GUID_BUS_INTERFACE_STANDARD | `{496B8280-6F25-11D0-BEAF-08002BE2092F}` |
| GUID_DOCK_INTERFACE | `{A9956FF5-13DA-11D3-97DB-00A0C940522E}` |
| GUID_INT_ROUTE_INTERFACE_STANDARD | `{70941BF4-0073-11D1-A09E-00C04FC340B1}` |

Device interfaces registered on child devices (`ACPIInternalSetDeviceInterface`, from the button, fan, processor and thermal start routines):  
| Name | GUID |
|------|------|
| GUID_DEVICE_SYS_BUTTON | `{4AFA3D53-74A7-11D0-BE5E-00A0C9062857}` |
| GUID_DEVICE_THERMAL_ZONE | `{4AFA3D51-74A7-11D0-BE5E-00A0C9062857}` |
| GUID_DEVICE_PROCESSOR | `{97FADB10-4E33-40AE-359C-8BEF029DBDD0}` |
| GUID_DEVICE_FAN | `{05ECD13D-81DA-4A2A-8A4C-524F23DD4DC9}` |
| GUID_DEVICE_APPLICATIONLAUNCH_BUTTON | `{629758EE-986E-4D9E-8E47-DE27F8AB054D}` |

### Other GUID

Bus type of the ACPI PDOs  
`{D7B46895-001A-4942-891F-A7D46610A843}` (GUID_BUS_TYPE_ACPI)

Thermal zone WMI data block  
`{A1BC18C0-A7C8-11D1-BF3C-00A0C9062910}` (THERMAL_ZONE_GUID)

`_DSM` UUIDs evaluated by the driver  
`{BAAEC45E-9D1E-40D1-9C56-CA1126D75B17}` (INTERRUPT_DSM_GUID)  
`{6831B330-1AA3-402C-BCF3-064877A5A43A}` (HOT_REPLACE_DSM_GUID)

Errata Manager rules (`ACPIInitGetEmOverride`, each one sets a bit of the AMLI override flags): `GUID_EM_RULE_AMLI_USE_NAMESPACE_OVERRIDE` `{FB1B8E3C-DF94-4722-AD5E-9E655C33B984}`, `GUID_EM_RULE_AMLI_MULTITHREADED_EXECUTION` `{AA88AE27-E5EB-4298-A844-017B7EB1DE96}`, `GUID_EM_RULE_AMLI_IGNORE_PACKAGE_LENGTH_CHECK` `{18FEB373-B259-432F-BCF5-3AB0296F8FC9}`, `GUID_EM_RULE_AMLI_RETURN_REV1` `{2A331496-B384-40CF-BB33-4307641D00A6}`, `GUID_EM_RULE_AMLI_RETURN_REV3` `{7E46DB74-3590-4E97-8113-5D866DDA23C7}`, and the `GUID_EM_RULE_ACPI_*` rules (disable S1/S2/S3, IRQ routing, ignore `_STA` disable…).
