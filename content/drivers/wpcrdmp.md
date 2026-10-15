## Wpcrdmp.sys

Windows Phone Crash Dump Driver (CDD).  
Registers bugcheck callbacks to complete the Windows crash dump (online dump) and prepares the _preboot_ / _offline_ dump: a full physical memory dump taken after the reset, either by the UEFI boot application wpdmp.efi or by the SBL.  
The Qualcomm subsystems (AMSS, ADSP, WCN…) describe their memory to the CDD through a query-interface: [qccdi8930.sys](./qccdi8930.md) is the client on the Lumia 520.  
KMDF driver, root enumerated (`IoReportRootDevice`): `\??\Root#wpcrdmp#0000#{933b95c6-f9cf-4424-a9f8-f497f760aee5}`. It has no device name and no IOCTL queue.  
Debug messages are prefixed by `WPCRDMP: ` (`DbgPrintEx` component 0x65). Pool tags: `Dmp_` (driver), `Dmp1`, `Dmp2`, `TDat`.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\WpCrDmp`  

Registry key `\Registry\Machine\System\CurrentControlSet\Control\CrashControl`:  
| Registry value | value | comment |
|----------------|-------|---------|
| CrashDumpEnabled | 0 | ULong. Type of the online dump taken by Windows (see below). Mandatory: if it can't be read, the device creation fails. The online dump callbacks are registered only for 1, 2 and 3 |
| WpDisablePrebootCrashDump | 0 | ULong (Boolean). Disables the preboot crash dump |
| EnableOfflineDumps | 0 | ULong. 0 = no preboot dump. 2 = also process the reset data of the SBL (see [Abnormal reset report](#abnormal-reset-report)) |
| WpDisableDebuggerCheck | 0 | ULong (Boolean). By default the preboot dump is not enabled when a kernel debugger is attached (`KdDebuggerNotPresent`) |
| WpDisableSubSystemCallBacks | 0 | ULong (Boolean). Don't call the halt / memory protection / failure record callbacks of the subsystems during a bugcheck |
| DedicatedDumpFile | D:\DedicatedDump.sys | String. Path of the offline dump file. SBL dump: copied in the UEFI variable `DedicatedDumpFile` `{853CE3A3-…}`. UEFI dump: copied in the settings file; its parent directory is the CrashDump partition |
| OfflineDumpBugCheckCodes | ? | MultiString of base 10 integers, 5 values max. SBL dump only: bugcheck codes for which the phone is reset immediately (no online dump) |
| WpSettingsFilePath | ? | String. UEFI dump only: path of the settings file read by wpdmp.efi |
| WpAbortKeyName | ? | String. UEFI dump only: copied in the settings file for wpdmp.efi |
| WpAbortTimeout | ? | ULong. UEFI dump only: copied in the settings file for wpdmp.efi |
| WpAbortKeyScanCode | ? | ULong. UEFI dump only: copied in the settings file for wpdmp.efi |
| WpErrorTimeout | ? | ULong, optional. UEFI dump only: copied in the settings file for wpdmp.efi |

The registry parameter `CrashDumpEnabled` accepts the following values:  
| Value | comment |
|-------|---------|
| 0 | Disabled. |
| 1 | Full physical memory dump. |
| 2 | Kernel memory dump. (Dumps only pages mapped into the kernel process address space; does not include user processes.) |
| 3 | Minidump (stack and registers). |

Other registry keys:  
| Registry key | Registry value | comment |
|--------------|----------------|---------|
| `\Registry\Machine\System\Versions` | ParentBranchBuild, TimeStamp, Label | Read for the phone build info stored in the dump header (UEFI dump only). TimeStamp is `YYYYMMDD-HHMM` (28 bytes), Label is 64 characters max |
| `\Registry\Machine\SYSTEM\CurrentControlSet\Control\LKMDTel` | MaxReportSizeInMB | ULong (max 100). Size of the live kernel report |
| `\Registry\Machine\System\CurrentControlSet\Services\telrepsvc\Parameters\SqmData` | RebootReason | ULong **written** by the driver after an abnormal reset |

The preboot crash dump is enabled only if `WpDisablePrebootCrashDump` = 0, `EnableOfflineDumps` ≠ 0, `CrashDumpEnabled` = 1 or 2, and no debugger is attached (or `WpDisableDebuggerCheck` ≠ 0).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `{A942B3D9-EC95-4754-AE45-49C48735B893}` interface | [qcscm8930.sys](./qcscm8930.md) | UEFI variable service `GUID_SYSENV_INTERFACE` (`\Device\SysEnv`). Only awaited: the preboot dump initialization is deferred until its arrival (`IoRegisterPlugPlayNotification`). Also used by [qcpmicapps8930.sys](./qcpmicapps8930.md) and awaited by [qcbms8930.sys](./qcbms8930.md) |
| CrashDump partition | NTFS | Directory of `DedicatedDumpFile`, and the settings file `WpSettingsFilePath` |

### Initialization

`EvtDriverDeviceAdd` (0x10009F84):
1. Creates the device interface `{933B95C6-…}` and the query-interface `{8BCB35C2-…}` (see [CDD interface](#cdd-interface)).
2. `WpCrDmpProcessCrashControl` (0x10008000) reads the `CrashControl` registry values.
3. `WpCrDmpInitializeOnlineDump` (0x100082B4) allocates the dump data and registers 3 bugcheck callbacks (component name `WpCrDmp`):

| Reason | Callback | Comment |
|--------|----------|---------|
| 1 (KbCallbackReserved1) | `WpCrDmpBugCheckCallback_Initial` (0x100052C8) | Copies the bugcheck code and its 4 parameters in the dump data. SBL dump: if the code is in `OfflineDumpBugCheckCodes`, calls `HalPrivateDispatchTable` +0x1A4 (reset ?) and loops forever. Then asks every subsystem to halt, and to disable its memory protection (xPU) |
| 5 (KbCallbackSecondaryMultiPartDumpData) | `WpCrDmpBugCheckCallback_SecondaryDumpData` (0x10005430) | GUID `{933B95C6-…}`. Asks every subsystem for its failure record (256 bytes), then writes the pages of the subsystem list and of the memory layout list in the dump |
| 3 (KbCallbackDumpIo) | `WpCrDmpBugCheckCallback_DumpIoStatus` (0x100055C0) | When the online dump is complete (`KbDumpIoComplete`), disables the memory capture mode: the preboot dump is not needed anymore |

4. `WpCrDmpInitializePrebootDump` (0x10008758) waits for the `{A942B3D9-…}` interface. On its arrival, `WpCrDmpInitializePrebootDumpDeferred` (0x10008830) runs once and chooses the offline dump version:
   * **SBL dump** (version 11) if `ZwQuerySystemInformation(153)` returns a config table of version 1 or 2 with the capability bit 0 (`OfflineMemoryDumpCapable`, "offline dump via dedicated partition").
   * **UEFI dump** (version 10) otherwise, if the UEFI variables `legacy_flag_address` and `memory_capture_mode_address` exist.

`EvtDeviceD0Exit` (0x10009974): on a normal shutdown or reboot (`WdfPowerDeviceD3Final`) the memory capture mode is disabled.

### Dump data

The dump data (`off_1000C788`) is allocated in contiguous memory, with a copy (`off_1000C778`) used by wpdmp.efi if the original is corrupted. Its physical addresses are given to the preboot dump (UEFI variable `InMemoryDataInfo` or settings file).  
| Offset | Value | Comment |
|--------|-------|---------|
| 0x00 | `\/\/PCl2D\|\/\|PGo` | Signature (16 bytes) |
| 0x10 | | Size of the dump header + 12 |
| 0x14 | 1 | |
| 0x18 | | Size of the dump header |
| 0x1C | | Dump header created by `KeInitializeCrashDumpHeader(DUMP_TYPE_FULL)`. The bugcheck code and parameters are at 0x44-0x57 |
| 0x1C + size | `\/\/PCl2D\|\/\|PeN` | End signature, at the offset 28 of a 12 bytes block |
| 0x38 + size | `\/\/P8Cl2Dl\/lP` | Subsystem data: mutex, list of the subsystems (pages of 7 entries of 520 bytes), list of the memory runs (pages of 169 entries of 24 bytes) and their physical addresses |
| 0x83C | | 128 bytes. UEFI dump: phone build info (`WPB#`, ParentBranchBuild, TimeStamp, Label). SBL dump: address of a dummy function used by wpdmp.efi as PC "when it marks context as invalid" |

The copy also contains the 864 bytes of the `KdDebuggerDataBlock`.

### SBL dump

`WpCrDmpInitializeSBLOfflineDump` (0x10008B44):
1. Copies `DedicatedDumpFile` in the UEFI variable `DedicatedDumpFile` `{853CE3A3-…}` if it's different.
2. Writes the UEFI variable `InMemoryDataInfo` `{853CE3A3-…}` (24 bytes, attributes 7 = NV+BS+RT):

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Virtual address of the dump data |
| 04-07 | 00 00 00 00 | |
| 08-0F | | Physical address of the dump data |
| 10-13 | | Size of the dump data |
| 14-17 | 00 00 00 00 | |

3. Only logs whether the secure boot policy publisher (`ZwQuerySystemInformation(SystemSecureBootPolicyInformation)`) is `SECUREBOOT_DEBUG_GUID`.
4. If a debugger is attached, logs the content of the CrashDump partition.
5. Reads `OfflineDumpBugCheckCodes`.
6. Writes the UEFI variable `OfflineDumpState` `{853CE3A3-…}` (4 bytes) = 2 (enabled), only if it's different.

### UEFI dump

`WpCrDmpInitializeUEFIOfflineDump` (0x10008A20) uses the following UEFI variables of `{83E7A47A-4023-40D2-9852-05EC34CAAF87}`:  
| UEFI variable | comment |
|---------------|---------|
| legacy_flag_address | Physical address of the SV legacy flag, mapped with `MmMapIoSpace` |
| legacy_flag_size | Size of the SV legacy flag. Bugcheck 0x139 (KERNEL_SECURITY_CHECK_FAILURE) if larger than 8 |
| legacy_flag_set_pattern | Value written to the legacy flag when the preboot dump is enabled |
| legacy_flag_reset_pattern | Value written to the legacy flag when the preboot dump is disabled |
| memory_capture_mode_address | Physical address of a ULONG, mapped with `MmMapIoSpace`. 1 = preboot dump enabled, 0 = disabled |

1. Reads the legacy flag configuration.
2. `WpCrDmpUpdateSettings` (0x1000A7AC) writes the settings file for wpdmp.efi.
3. Writes the set pattern in the legacy flag and 1 in the memory capture mode.
4. If a debugger is attached, logs the content of the CrashDump partition.

> [!NOTE]
> If the settings file can't be written (missing `WpSettingsFilePath`, volume not NTFS, write error…), the driver calls `KeBugCheckEx(0x5A, 2, NTSTATUS, FileHandle, RegistryKey)`.

The settings file `WpSettingsFilePath` must be on an NTFS volume. It's marked with `FSCTL_SET_BOOTLOADER_ACCESSED` (0x9004F) so it's not moved on the disk. Content:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 57 50 43 44 | Signature `WPCD` |
| 04-07 | | Size of the entries |
| 08-0B | | Number of entries |
| 0C-0F | | Checksum: sum of the bytes of the entries |
| 10-... | | Entries |

Entry:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | | Size of the entry |
| 02-03 | 00 00 | |
| 04-05 | 02 00 | |
| 06-07 | | Size of the name (n) |
| 08-(8+n-1) | | Name (UTF-16, no terminating 0) |
| 8+n | | Type: 2 = string, 5 = ULONG, 6 = ULONGLONG |
| 9+n | 00 | |
| (10+n)-(11+n) | | Size of the data (d) |
| 12+n-... | | Data |

The entries are: `WpAbortKeyName`, `DedicatedDumpFile`, `WpAbortTimeout`, `WpAbortKeyScanCode`, `WpErrorTimeout` (copied from the registry), `WpDumpDataAddr` and `WpDumpDataAddrCopy` (physical addresses of the dump data and of its copy), `WpDumpDataBugChkParam1Offset` (= 44), `WpDumpKdDebuggerDataBlockAddr` and `WpDumpKdDebuggerDataBlockCopyAddr`.

### Abnormal reset report

Only when `EnableOfflineDumps` = 2 and the config table is version 2 (`sub_10005AD8`): the config table gives the address and size of the reset data written by the SBL (`ResetDataAddress`, `ResetDataSize` = 8280 bytes, signature `{8CC74056-…}`). Its strings `GCC_RESET_STATUS=`, `PON_WARM_RESET_REASON1=` and `POFF_REASON1=` are parsed to compute an abnormal reset reason (only for MSM8916 and MSM8909 ?).  
If an abnormal reset occurred, the driver creates a live kernel report `AbnormalReset` (`WerLiveKernelCreateReport`, secondary data `{6C123512-B8F4-440F-8BB1-813CC38D0CC9}` = the reset data), and writes the reason in `RebootReason`. If the shell is not ready yet, the report is delayed until the WNF state `WNF_SHL_START_READY` (0x418A063EA3BC3875).  
This is probably not used on the Lumia 520 (MSM8930).

### CDD interface

Query-interface `{8BCB35C2-CB20-44E4-9A1E-33A016856CBF}`, size 24, version 1 (`sub_10009210`).  
| Offset | Function | Comment |
|--------|----------|---------|
| 0x08 | InterfaceReference | No-op |
| 0x0C | InterfaceDereference | No-op |
| 0x10 | `RegisterSubsystem(Descriptor, Callbacks, *NotificationFunction, *Context)` (0x100093C4) | Descriptor version must be 1. Adds the subsystem to the list (entry of 520 bytes: context, descriptor, callbacks `GetFailureRecord`, `Halt`, `SetMemoryProtection`, their results, failure record buffer of 256 bytes). Returns the function used to send the memory layout (0x100092B0). If the online dump is not enabled, nothing is registered but the function is still returned |
| 0x14 | `DeregisterSubsystem(Context)` (0x10009490) | |

The memory layout function receives the number of runs (8 bytes) then 16 bytes per run (physical address, number of pages). The previous runs of the subsystem are replaced.

### GUID

CDD interface class (device interface of wpcrdmp.sys) and GUID of the secondary dump data  
`{933B95C6-F9CF-4424-A9F8-F497F760AEE5}`

CDD query-interface  
`{8BCB35C2-CB20-44E4-9A1E-33A016856CBF}`

Signature of the SBL reset data (RESET_DATA_HEADER)  
`{8CC74056-428F-4A4A-A7EB-034E68FC2C2A}`

UEFI variables `DedicatedDumpFile`, `InMemoryDataInfo`, `OfflineDumpState` (SBL dump)  
`{853CE3A3-F693-4D9A-B95F-84E2105D13F2}`

UEFI variables `legacy_flag_*`, `memory_capture_mode_address` (UEFI dump)  
`{83E7A47A-4023-40D2-9852-05EC34CAAF87}`

SECUREBOOT_DEBUG_GUID  
`{0CDAD82E-D839-4754-89A1-844AB282312B}`

Secondary data of the `AbnormalReset` live kernel report  
`{6C123512-B8F4-440F-8BB1-813CC38D0CC9}`

UEFI variable service interface class (awaited)  
`{A942B3D9-EC95-4754-AE45-49C48735B893}`  
`GUID_SYSENV_INTERFACE` of [qcscm8930.sys](./qcscm8930.md) (qcpmicapps8930.sys and qcbms8930.sys are only clients).
