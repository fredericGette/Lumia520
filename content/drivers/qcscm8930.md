## Qcscm8930.sys

Qualcomm Secure Channel Manager (SCM): the gateway between Windows and the TrustZone (TZ) secure world.  
It sends TZ "syscalls" (`SMC #0` instruction) for the other drivers ([qcpil8930.sys](./qcpil8930.md) PAS commands, [qccdi8930.sys](./qccdi8930.md) watchdog configuration, …), and it implements on top of the QSEE trustlet `qcom.tz.winsecapp`:
* the **UEFI variable service** of Windows (`\Device\SysEnv`, `IOCTL_SYSENV_*`), used by `ExGetFirmwareEnvironmentVariable`/`ExSetFirmwareEnvironmentVariable` and by [qcpmicapps8930.sys](./qcpmicapps8930.md), [qcbms8930.sys](./qcbms8930.md), [wpcrdmp.sys](./wpcrdmp.md),
* the **firmware TPM** (TPM "3PI" vendor interface for the Windows TPM driver).

The variables and the TPM state are persisted by the trustlet in the eMMC **RPMB** partition: the driver only relays the RPMB frames between the TZ and the SD storage driver. At D0 exit it writes the `MemoryOverwriteRequestControl` and `PPI` UEFI variables.  
The PDB path is `P:\SCM\rel\8.2.1.1\arm\Release\qcscm8930.pdb`. The trace messages start with `SCM: `.

Device name : `\Device\SysEnv`  
There's no symbolic link: the clients open the device through its device interfaces (e.g. `\??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68}`).  
The device can't be stopped or removed (`WdfDeviceSetStaticStopRemove(FALSE)`), and a surprise removal calls `KeBugCheckEx(0x14E, 0x51736330, 0, 0, 0)` (`sub_40E2C4`).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0E90\0`  

Registry value read from the driver's **service key** (`WdfDriverGetRegistryPath`, not the `Parameters` subkey) by `SCMEvtDevicePrepareHardware`:  
| Registry value | value | comment |
|----------------|-------|---------|
| UpdateOS | ? | REG_DWORD. When 1, the buffer used by the SSD encrypt/decrypt IOCTLs is 2 MB (0x200000) instead of 8 KB (0x2000). Set during an OS update ? |

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters` (`WdfDriverOpenParametersRegistryKey` + `WdfRegistryQueryULong`, `sub_4039B0`):  
| Registry value | value | comment |
|----------------|-------|---------|
| CommandTimeout | ? | REG_DWORD. Sent to the TPM trustlet in the `CNFG` request (device context +0x18) |
| GenerateKeyCommandTimeout | ? | REG_DWORD. Sent to the TPM trustlet in the `CNFG` request (device context +0x1C) |
| IgnoreRpmbErrors | ? | REG_DWORD. When ≠ 0, a failure to read the RPMB write counter is ignored by `NotifyTpm` (the TPM flush request is sent without the RPMB frame) |

GUID of the ETW (WPP) provider:  
`{BC491612-4CA5-4489-A3EA-8DDE1F3B268E}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device (default I/O target) | ACPI | Evaluates the ACPI method `GCFG` with [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method). The result is checked but not used |
| `{27447C21-BCC3-4D07-A05B-A3395BB4EEE7}` interface | SD storage driver ? (sdstor) | Found with `IoRegisterPlugPlayNotification`, opened with `WdfIoTargetOpen`. RPMB access with [IOCTL 0x71E8C](#ioctl-0x71e8c) |
| TrustZone | | `SMC #0`, see [TrustZone syscalls](#trustzone-syscalls) |

### Start-up

`SCMCreate` (`sub_40D2A4`, called by `SCMEvtDeviceAdd`):
1. Assigns the name `\Device\SysEnv`, registers the PnP/power callbacks (`EvtDevicePrepareHardware` = `sub_40D9F0`, `EvtDeviceReleaseHardware` = `sub_40E188` (does nothing), `EvtDeviceD0Exit` = `sub_40E194`, `EvtDeviceSurpriseRemoval` = `sub_40E2C4`) and a WDM preprocess callback for `IRP_MJ_PNP`/`IRP_MN_QUERY_DEVICE_RELATIONS` (`EvtIrpPreprocessQueryDevRelations`, `sub_40D008`).
2. Creates the device, the wait-lock that serializes all the TZ requests (`ScmLockAcquire`/`ScmLockRelease`), and the default parallel queue (`EvtIoDeviceControl` = `sub_40F238`, `EvtIoInternalDeviceControl` = `sub_40E3BC`).
3. Registers a notification for the arrival of the SD storage interface `{27447C21-BCC3-4D07-A05B-A3395BB4EEE7}` (`EvtNotifySdStorInterfaceChange`, `sub_40D0F4`).

`SCMEvtDevicePrepareHardware` (`sub_40D9F0`):
1. Reads `UpdateOS` and allocates the contiguous SSD buffer (8 KB or 2 MB).
2. Maps the 3 ACPI memory resources (see below).
3. Evaluates the ACPI method `GCFG` (`sub_403AF0`), then reads the `Parameters` registry values.
4. If the SD storage interface has already arrived, exports the TPM interface (`ExportTpmInterface`).

When the SD storage interface arrives (`EvtNotifySdStorInterfaceChange`), the driver opens it, calls `IoInvalidateDeviceRelations(PowerRelations)`, and exports the TPM interface if `EvtDevicePrepareHardware` has already run. Its preprocess callback then adds the PDO of the SD storage device to the **power relations** of the SCM device (`EvtQueryDevicePowerRelations`, `sub_402184`), so the storage is powered down after the SCM device and the D0 exit writes can still reach the RPMB.

`TPM_VendorDevicePrepare`, called by the TPM driver, runs in a work item: `InitializeTrustlet` (look up the application ID of `qcom.tz.winsecapp`, `INFO` and `CNFG` requests, RPMB reliable write size), then `sub_402C40` creates and enables the device interfaces `{41C66D2A-…}` (GUID_SCM_DEVINTERFACE) and `{A942B3D9-…}` (GUID_SYSENV_INTERFACE), and exports the SCM Direct Interface `{999642D1-…}`.

> [!NOTE]
> So the SCM and SysEnv interfaces (and the UEFI variables) are only available once the TPM driver has called `TPM_VendorDevicePrepare`.

`SCMEvtDeviceD0Exit` (`sub_40E194`) writes two UEFI variables (attributes 7 = NON_VOLATILE | BOOTSERVICE_ACCESS | RUNTIME_ACCESS) and flushes them to the RPMB:
| Name | Vendor GUID | Size | Value |
|------|-------------|------|-------|
| PPI | `{882F8C2B-9646-435F-8DE5-F208FF80C1BD}` | 4 | The 4 bytes of the MOR/PPI shared memory (`sub_403510`) |
| MemoryOverwriteRequestControl | `{E20939BE-32D4-41BE-A150-897F85D49829}` | 1 | 00 (`sub_403320`) |

The vendor GUID of `PPI` is the same as the one of `BmsDataVariables` ([qcbms8930.sys](./qcbms8930.md)) and `RTCInfo` ([qcpmicapps8930.sys](./qcpmicapps8930.md)).

### ACPI memory resources

Mapped with `MmMapIoSpace` (non cached) by `SCMEvtDevicePrepareHardware`. Only the resources of type `CmResourceTypeMemory` are used; their order matters. If the first one is missing: "Incorrect ACPI configuration", 0xC014000F (ignored).
| Index | Name | Device context | Use |
|-------|------|----------------|-----|
| 0 | MOR/PPI | +0x04 (VA) | Byte 0 = MOR, byte 1 = PCMD, byte 2 = CCMD, byte 3 = RCMD (logged at start). Written to the `PPI` variable at D0 exit |
| 1 | TrustZone variables buffer | +0x08 (PA), +0x0C (VA), +0x10 (size) | Parameter buffer of the TZ requests (`AllocateParameterMemory`), and buffer of the UEFI variable requests. If its size is 0, a 256 KB (0x40000) contiguous buffer is allocated instead |
| 2 | TrustZone TPM control area | +0x14 (VA) | TPM control area ? (only mapped) |

Both buffers must have a page-aligned physical address and a size multiple of the cache line size (`sub_405CB8`, cache line size read from `CCSIDR`).

### TrustZone syscalls

`ScmSmcSyscall` (`sub_401000`) executes `SMC #0` with R0 = 1, R1 = 0xF, R2 = physical address of the request, and repeats it while R0 > 0 (interrupted call). R0 = 0 means success, otherwise `ScmSyscall` (`sub_405DD0`) returns 0xC0000190 (`STATUS_TRUST_FAILURE`).  
`ScmSmcAtomic` (`sub_401010`, R0 = `id | 0x200`, register arguments) exists but isn't called.

The request is the legacy Qualcomm `tzbsp_syscall_req_t` (names from the log strings), in physically contiguous memory:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | `len`: size of the request |
| 04-07 | 10 00 00 00 | `command_start_off`: offset of the arguments |
| 08-0B | | `response_write_off`: offset of the response |
| 0C-0F | | `command_id`: `(service << 10) \| command` |
| 10-.. | | Arguments |

Response (`tzbsp_syscall_rsp_t`, at `response_write_off`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | `len` |
| 04-07 | | `response_start_off`: offset of the result (from the response) |
| 08-0B | 01 00 00 00 | `status`: 1 = success |

Commands built by the driver itself:  
| command_id | Service / command | Use |
|------------|-------------------|-----|
| 0x1C01 | 7 / 1 | SSD decrypt ([IOCTL 0xC351400C](#ioctl-0xc351400c--ioctl_scm_ssd_class_syscall-decrypt)) |
| 0x1C02 | 7 / 2 | SSD encrypt ([IOCTL 0xC3514008](#ioctl-0xc3514008--ioctl_scm_ssd_class_syscall-encrypt)) |
| 0x3F001 | 0xFC / 1 | QSEE application lookup (`QueryApplicationId`): sub-command 0xFF03 with the name `qcom.tz.winsecapp`. The returned application ID is saved at device context +0x2C |
| 0x3F401 | 0xFD / 1 | Send a request to the `qcom.tz.winsecapp` trustlet (application ID at +0x10, request code at +0x14) |

Request codes sent to `qcom.tz.winsecapp`:  
| Code | Function | Comment |
|------|----------|---------|
| 0x4008 | `NotifyTpm` | Signature `FLSH`. Gives the RPMB write counter frame to the TPM; called after each TPM command |
| 0x400F | `QueryTpmNvStoreSize` | Signature `INFO` |
| 0x4010 | `sub_407A94` | Signature `CNFG`, with `CommandTimeout` and `GenerateKeyCommandTimeout` |
| 0x8000 | `sub_4046D0` | GetVariable |
| 0x8001 | `sub_404804` | SetVariable |
| 0x8002 | `sub_404930` | GetNextVariableName |
| 0x8003 | `sub_404A50` | QueryVariableInfo |
| 0x8004 | `sub_404B24` | Get the RPMB frames to write (`FlushStore`) ? |
| 0x8005 | `FlushStore` | Give the RPMB write result back to the trustlet ? |

The TPM requests (`CreateTpmRequest`, 4096 + n bytes) have `len` = 0x82C, `response_write_off` = 0x420 and a second block at +0x41C (`PRVT` signature, physical and virtual address of the data at +0x1000).

`FlushStore` (`sub_4062F8`) is called after each SetVariable: it reads the RPMB write counter (`SdStorQueryWriteCounter`), asks the trustlet for the authenticated frames (0x8004), writes them to the RPMB in blocks of the reliable write size (`SdStorIssueIRP`), checks the result of each RPMB response frame (`sub_404D8C`) and returns the last response frame to the trustlet (0x8005). `FlushTpmStore` does the same for the TPM store.

The EFI status returned by the trustlet is converted to an NTSTATUS by `sub_407E30` (table at `.data:0x0040B1A0`, 32 entries; an unknown value gives 0xC00000E5 `STATUS_INTERNAL_ERROR`):  
| EFI status | NTSTATUS |
|------------|----------|
| 0x00000000 EFI_SUCCESS | 0x00000000 |
| 0x80000002 EFI_INVALID_PARAMETER | 0xC000000D |
| 0x80000003 EFI_UNSUPPORTED | 0xC00000BB |
| 0x80000005 EFI_BUFFER_TOO_SMALL | 0xC0000023 |
| 0x80000007 EFI_DEVICE_ERROR | 0xC0000185 |
| 0x80000008 EFI_WRITE_PROTECTED | 0xC00000A2 |
| 0x80000009 EFI_OUT_OF_RESOURCES | 0xC0000454 |
| 0x8000000E EFI_NOT_FOUND | 0xC0000100 (`STATUS_VARIABLE_NOT_FOUND`) |
| 0x8000000F EFI_ACCESS_DENIED | 0xC0000022 |
| 0x8000001A EFI_SECURITY_VIOLATION | 0xC0000022 |
| others | see the table in the binary |

### SCM Direct Interface

Query-interface `{999642D1-34E8-4759-AABB-29C62AB58627}` (size 20, version 1), exported by `sub_405940`. It is used by [qcpil8930.sys](./qcpil8930.md).
| Offset | Function | Comment |
|--------|----------|---------|
| 0x04 | | Context (WDFDEVICE) |
| 0x08 | `nullsub_1` | InterfaceReference |
| 0x0C | `nullsub_1` | InterfaceDereference |
| 0x10 | `PerformControlClassSysCall(PVOID Request, ULONG Length)` | Copies the request (max 32 bytes, else 0xC000000D) into a 32-byte contiguous buffer allocated at start, executes the SMC directly (no IRP, no lock wait) and copies the buffer back. Returns 0xC0000184 (`STATUS_INVALID_DEVICE_STATE`) if the SCM lock is held, 0xC0000190 if the SMC fails |

### TPM interface

Query-interface `{35816B44-6FBD-45B5-A07F-CCA201643456}` (size 24, version 1), exported by `ExportTpmInterface` (`sub_402E14`) with the device interface `{934CEDB5-E401-478C-B5E8-70219E335BEF}`:
| Offset | Function | Comment |
|--------|----------|---------|
| 0x04 | | Context (WDFDEVICE) |
| 0x08 | `nullsub_1` | InterfaceReference |
| 0x0C | `nullsub_1` | InterfaceDereference |
| 0x10 | `TPM_VendorDevicePrepare` | Initializes the trustlet (work item `VendorDevicePrepareCallback`) and enables the SCM/SysEnv interfaces |
| 0x14 | `TPM_VendorSubmitTpmCommand` | Runs `NotifyTpm` in a work item. The TPM command and response (big-endian command/response code at +0x36) are in a buffer referenced by the device context +0x14 |

---

### IOCTL 0xC3514000 — IOCTL_SCM_CONTROL_CLASS_SYSCALL

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x0 (0) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SCM_CONTROL_CLASS_SYSCALL | ≥ 16 | same as InputBuffer (same buffer) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | | `tzbsp_syscall_req_t` header, see [TrustZone syscalls](#trustzone-syscalls). `len` must be equal to the InputBuffer size, else 0xC000000D |
| 10-.. | | Arguments and response |

`ControlClassSysCall` (`sub_406DC8`) copies the buffer into the parameter memory, sends it as is with `SMC #0`, and copies the whole buffer back (Information = InputBuffer size). The `command_id` is **not** checked.

> [!NOTE]
> This is a "normal" IOCTL (not internal): any caller that can open the `{41C66D2A-…}` interface with read access can send any TZ syscall.

---

### internal IOCTL 0xC3514004 — IOCTL_INTERNAL_SCM_CONTROL_CLASS_SYSCALL

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x1 (1) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_SCM_CONTROL_CLASS_SYSCALL | ≥ 16 | same as InputBuffer (same buffer) |

Same buffer and processing as [IOCTL 0xC3514000](#ioctl-0xc3514000--ioctl_scm_control_class_syscall). Sent by [qcpil8930.sys](./qcpil8930.md#ioctl-0xc3514004) for the PAS commands 0x801, 0x805 and 0x806.

---

### IOCTL 0xC3514008 — IOCTL_SCM_SSD_CLASS_SYSCALL (encrypt)

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x2 (2) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SSD encrypt ? | 1 to 8192 (2 MB with `UpdateOS`=1) | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | | Data to encrypt |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | | Encrypted data. Information = size returned by the TZ |

`sub_406F6C` copies the data into the SSD buffer and sends the TZ command 0x1C02 (24-byte request, `len` = 0x40, arguments: physical address of a cell containing the physical address of the data, physical address of a cell containing the size). The TZ can return another address and size: the output is copied from there.  
A request bigger than the SSD buffer returns 0xC0000023 ("SCM: Encrypt user buffer size bigger than expected size").

> [!NOTE]
> The size returned by the TZ isn't checked against the OutputBuffer size, and a failure of `WdfRequestRetrieveOutputBuffer` is only logged. The global pointer to the SSD buffer is moved by the difference of address returned by the TZ (it's never restored).

---

### IOCTL 0xC351400C — IOCTL_SCM_SSD_CLASS_SYSCALL (decrypt)

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x3 (3) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SSD decrypt ? | 1 to 8192 (2 MB with `UpdateOS`=1) | ≥ 4 |

Same as [IOCTL 0xC3514008](#ioctl-0xc3514008--ioctl_scm_ssd_class_syscall-encrypt) with the TZ command 0x1C01 (`sub_407178`, "SCM: Decrypt user buffer size bigger than expected size"). The trace message of the handler is also `IOCTL_SCM_SSD_CLASS_SYSCALL`.

---

### IOCTL 0xC3514010 / 0xC3514014 — IOCTL_SCM_SSD_ENCRYPT_KEY_STORE_CLASS_SYSCALL_EX

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x4 (4) / 0x5 (5) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SCM_SSD_ENCRYPT_KEY_STORE_CLASS_SYSCALL_EX | ≥ 16 | same as InputBuffer (same buffer) |

A raw TZ syscall like [IOCTL 0xC3514000](#ioctl-0xc3514000--ioctl_scm_control_class_syscall), but `sub_403F08` first checks the `command_id` (offset 0x0C) with the table at `.data:0x0040B188`:
| IOCTL | Allowed command_id |
|-------|--------------------|
| 0xC3514010 | 0x1C02 (SSD encrypt) |
| 0xC3514014 | 0x1C01 (SSD decrypt) |

Any other `command_id` returns 0xC0000022 (`STATUS_ACCESS_DENIED`).

---

### internal IOCTL 0xC3514018 — IOCTL_INTERNAL_SCM_CONTROL_CLASS_SYSCALL_CPU0

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x6 (6) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_SCM_CONTROL_CLASS_SYSCALL_CPU0 | ≥ 16 | same as InputBuffer (same buffer) |

Same as [IOCTL 0xC3514000](#ioctl-0xc3514000--ioctl_scm_control_class_syscall), but the syscall is executed on **CPU 0**: the handler queues a work item (`ControlClassSysCall_cpu0`, `sub_406C2C`) that calls `KeSetSystemAffinityThreadEx(1)` and waits for it. Sent by [qccdi8930.sys](./qccdi8930.md#internal-ioctl-0xc3514018) for the command 0xC02 (watchdog bark FIQ).

---

### internal IOCTL 0x520004 — IOCTL_SYSENV_GET_VARIABLE

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x52 |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SYSENV_GET_VARIABLE | ≥ 24 | ≥ 8 + data size |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | | Vendor GUID |
| 10-13 | | Size of the name in bytes |
| 14-.. | | Null terminated UTF-16 name |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Attributes |
| 04-07 | | Data size |
| 08-.. | | Data |

`sub_4046D0` (TZ request 0x8000) is called a first time to get the size. If the OutputBuffer is too small, the request completes with 0xC0000023 and Information = 8 + data size. Otherwise the variable is read into a pool buffer (tag `QSCC`) and copied (Information = 8 + data size). A missing variable returns 0xC0000100.

---

### internal IOCTL 0x520008 — IOCTL_SYSENV_SET_VARIABLE

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x52 |
| Function | 0x2 (2) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SYSENV_SET_VARIABLE | ≥ 36 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | ? |
| 04-07 | | Offset of the data |
| 08-0B | | Data size (0 deletes the variable ?) |
| 0C-0F | | Attributes. The driver always adds BOOTSERVICE_ACCESS \| RUNTIME_ACCESS (`\|= 6`) |
| 10-1F | | Vendor GUID |
| 20-.. | | Null terminated UTF-16 name |
| .. | | Data |

`sub_404804` sends the TZ request 0x8001, then `FlushStore` writes the store to the RPMB.

---

### internal IOCTL 0x52000C — IOCTL_SYSENV_ENUM_VARIABLES

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x52 |
| Function | 0x3 (3) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SYSENV_ENUM_VARIABLES | ≥ 1 | variable |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | | 0 = names only, ≠ 0 = names and values |

Outputbuffer: list of entries (same layout as `VARIABLE_NAME` / `VARIABLE_NAME_AND_VALUE` of `NtEnumerateSystemEnvironmentValuesEx`).  
Names only (`sub_4043C8` computes the size, `sub_404570` fills):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Offset of the next entry (0 for the last one) |
| 04-13 | | Vendor GUID |
| 14-.. | | Null terminated UTF-16 name |

Names and values (`sub_403FA0` computes the size, `sub_4041BC` fills):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Offset of the next entry (0 for the last one) |
| 04-07 | | Offset of the value ? |
| 08-0B | | Size of the value ? |
| 0C-0F | | Attributes ? |
| 10-1F | | Vendor GUID |
| 20-.. | | Null terminated UTF-16 name, then the value |

The variables are enumerated with the TZ request 0x8002 (GetNextVariableName) until 0xC0000100. If the OutputBuffer is too small: 0xC0000023 with Information = required size.

---

### internal IOCTL 0x520010 — IOCTL_SYSENV_QUERY_VARIABLE_INFO

This IOCTL is processed by Qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x52 |
| Function | 0x4 (4) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SYSENV_QUERY_VARIABLE_INFO | ≥ 4 | ≥ 24 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Attributes |

Outputbuffer (`SYSENV_VARIABLE_INFO`, names from the log strings):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | | MaximumVariableStorageSize |
| 08-0F | | RemainingVariableStorageSize |
| 10-17 | | MaximumVariableSize |

`sub_404A50` sends the TZ request 0x8003.

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcscm8930.sys to the ACPI driver (lower device), once in `EvtDevicePrepareHardware` (`sub_403AF0`)

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | default I/O target | 8 | 1024 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `AeiB` (ACPI_EVAL_INPUT_BUFFER_SIGNATURE) |
| 04-07 | 47 43 46 47 | Method name `GCFG` |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature `AeoB` |
| 08-0B | | Count of arguments, must be ≠ 0 |

If the signature or the count is wrong: 0xC014000F (logged as info). The result isn't used and the status is ignored by the caller.

---

### IOCTL 0x71E8C

This IOCTL is sent by Qcscm8930.sys to the SD storage interface `{27447C21-…}` (`SdStorIssueIRP`, `sub_404F94`), synchronously (`WdfRequestSend` with `WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`)

| Property | Value |
|----------|-------|
| Device | 0x7 (FILE_DEVICE_DISK) |
| Function | 0x7A3 (1955) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| RPMB access ? | `{27447C21-BCC3-4D07-A05B-A3395BB4EEE7}` interface | 1056 + data | same |

Inputbuffer / Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 20 04 00 00 | Size of the header (1056) |
| 04-07 | | Operation: 0 = get the reliable write size (`SdStorQueryReliableWriteSize`), 2 = read the write counter (`SdStorQueryWriteCounter`), 3 = write frames (`FlushStore`, `FlushTpmStore`) |
| 10-13 | | Number of 512-byte blocks |
| 14-17 | | Reliable write size, returned by the operation 0 |
| 20-21F | | RPMB response frame (big-endian; result at offset 508 of the frame, must be 0 else 0xC000009C) |
| 220-41F | | RPMB request frame (for the operation 2: random nonce at offset 484, request type 0x0002 at offset 510) |
| 420-.. | | Other frames (operation 3) |

---

### Interface GUID

GUID_SCM_DEVINTERFACE (raw TZ syscalls, IOCTL 0xC35140xx), opened by [qcpil8930.sys](./qcpil8930.md) and [qccdi8930.sys](./qccdi8930.md)  
`{41C66D2A-A9F1-40CA-A329-AE096C03EE68}`

GUID_SYSENV_INTERFACE (UEFI variable service, internal IOCTL 0x5200xx), used by [qcpmicapps8930.sys](./qcpmicapps8930.md) and awaited by [qcbms8930.sys](./qcbms8930.md) and [wpcrdmp.sys](./wpcrdmp.md)  
`{A942B3D9-EC95-4754-AE45-49C48735B893}`

TPM device interface ?  
`{934CEDB5-E401-478C-B5E8-70219E335BEF}`

SD storage interface (arrival notification)  
`{27447C21-BCC3-4D07-A05B-A3395BB4EEE7}`

### Other GUID

SCM Direct Interface (query-interface)  
`{999642D1-34E8-4759-AABB-29C62AB58627}`

TPM vendor (3PI) interface (query-interface)  
`{35816B44-6FBD-45B5-A07F-CCA201643456}`

UEFI vendor GUID of `MemoryOverwriteRequestControl` (MEMORY_ONLY_RESET_CONTROL_GUID)  
`{E20939BE-32D4-41BE-A150-897F85D49829}`

UEFI vendor GUID of `PPI`  
`{882F8C2B-9646-435F-8DE5-F208FF80C1BD}`
