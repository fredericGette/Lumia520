## Wpprecorder.sys

WPP Trace Recorder, also known as the Inflight Trace Recorder (IFR). Version `6.3.9651.0 (winbluephone_gdr1.150113-1731)`, PDB `wpprecorder.pdb`.  
It is a kernel **export driver**: it keeps WPP trace messages in small circular buffers in non-paged memory, whether or not an ETW session is running, and adds these buffers to the crash dump when the bugcheck points to the client driver.  
It creates no device and registers no ETW provider, so it has no IOCTL. A client driver links against its exports: `WppAutoLogStart` at start, `WppAutoLogTrace` from the WPP macros, and `WppAutoLogStop` at unload.  
`GsDriverEntry` → `DriverEntry` (0x1210C) only calls `DllInitialize` (0x1211C), which always returns `STATUS_SUCCESS`. `DllUnload` (0x121B4) does nothing.

There's no device name and no symbolic link.  

There's no GUID of its own. Records and dumps are labelled with the WPP control GUID of the client driver.

It doesn't communicate with any other device. It only imports `ntoskrnl.exe`.

Drivers using it:  
| Driver | Exports imported | Comment |
|--------|------------------|---------|
| [acpiex.sys](./acpiex.md) | `WppAutoLogStart`, `WppAutoLogStop`, `WppAutoLogTrace` | The only importer found in the available phone binaries. `Wdf01000.sys` wasn't among them. See [Use by acpiex.sys](#use-by-acpiexsys) |

### Registry

Global key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\WppRecorder`, read once by `DllInitialize` (`RTL_REGISTRY_CONTROL`):  
| Registry value | value | comment |
|----------------|-------|---------|
| ForceDisabledCrashLogs | 0 | REG_DWORD. Not 0 → `g_IsDllDisabled` (`.data:0x14010`) = 1, and `WppAutoLogStart` does nothing for every client |

Key of each client `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters`, read by `GetWppAutoLogRegistrySettings` (0x114CC) during `WppAutoLogStart`:  
| Registry value | value | comment |
|----------------|-------|---------|
| VerboseOn | 0 | REG_DWORD, stored as a WORD at offset 0x34 of the WPP control block. It isn't read by wpprecorder.sys, nor by [acpiex.sys](./acpiex.md) |
| LogPages | 1 | REG_DWORD. Size of the default log in 4 KB pages, limited to 1..16 |
| ForceLogsInMiniDump | 0 | REG_DWORD, stored as a WORD at offset 0x36 of the WPP control block. Its low byte goes to `ForceDump` in the [driver context](#driver-context): the logs are always added to the dump |
| WppRecorder_PerBufferMinBytes | 256 | REG_DWORD. Minimum total size of a log made with `WppRecorderLogCreate`. 0 = default |
| WppRecorder_PerBufferMaxBytes | 8192 | REG_DWORD. Maximum total size of a log made with `WppRecorderLogCreate`. 0 = default |

If the minimum is larger than the maximum, an explicit minimum wins (maximum = minimum). If only the maximum is set, minimum = maximum. Then both are limited to 65536.  
All the values are optional. If the service key or `Parameters` can't be opened, the defaults above are used.

### Exports

The `control` parameter is the WPP control block of the client driver.  
| Ordinal | Address | Function signature | Comment |
|---------|---------|--------------------|---------|
| 1 | 0x1211C | `NTSTATUS DllInitialize(PUNICODE_STRING RegistryPath)` | Reads `ForceDisabledCrashLogs` |
| 2 | 0x121B4 | `NTSTATUS DllUnload()` | No-op stub |
| 3 | 0x11864 | `void WppAutoLogStart(control, PDRIVER_OBJECT DriverObject, PUNICODE_STRING RegistryPath)` | See [Start](#start) |
| 4 | 0x11A28 | `void WppAutoLogStop(control)` | See [Stop](#stop) |
| 5 | 0x11A78 | `NTSTATUS WppAutoLogTrace(log, ULONG level ?, ULONG flagNumber, GUID *traceGuid, USHORT messageNumber, ...)` | See [Writing a record](#writing-a-record) |
| 6 | 0x11C2C | `void imp_WppRecorderConfigure(control, params)` | See [imp_WppRecorderConfigure](#imp_wpprecorderconfigure) |
| 7 | 0x11E50 | `NTSTATUS imp_WppRecorderDumpLiveDriverData(control, void **buffer, ULONG *size, GUID *guid)` | Returns the 36-byte [driver block](#driver-block) and the control GUID. `STATUS_UNSUCCESSFUL` if there's no context |
| 8 | 0x11DC0 | `void *imp_WppRecorderGetCounterHandle(control)` | Returns the [driver context](#driver-context), whose first DWORD is the sequence counter, or NULL |
| 9 | 0x11E28 | `NTSTATUS imp_WppRecorderGetTriageInfo(control, ULONG *info)` | See [imp_WppRecorderGetTriageInfo](#imp_wpprecordergettriageinfo) |
| 10 | 0x11CB4 | `BOOLEAN imp_WppRecorderIsDefaultLogAvailable(control)` | TRUE if the default log exists and its general partition isn't empty |
| 11 | 0x11DD4 | `NTSTATUS imp_WppRecorderLinkCounters(control, ULONG *counter)` | See [imp_WppRecorderLinkCounters](#imp_wpprecorderlinkcounters) |
| 12 | 0x11CD4 | `NTSTATUS imp_WppRecorderLogCreate(control, params, void **log)` | See [imp_WppRecorderLogCreate](#imp_wpprecorderlogcreate) |
| 13 | 0x11DA0 | `void imp_WppRecorderLogDelete(control, log)` | Does nothing for NULL or for the default log |
| 14 | 0x11E94 | `NTSTATUS imp_WppRecorderLogDumpLiveData(control, log, void **buffer, ULONG *size, GUID *guid)` | Returns the log object and its size without copying it, see [Crash dump](#crash-dump) |
| 15 | 0x11C9C | `void *imp_WppRecorderLogGetDefault(control)` | Returns the default log, or NULL |
| 16 | 0x11D68 | `void imp_WppRecorderLogSetIdentifier(control, log, char *name)` | Copies at most 15 characters + NUL. Does nothing for NULL or for the default log |
| | 0x121C0 | `GsDriverEntry` | PE entry point |

The WPP control block is built by the WPP code generated in the client driver. wpprecorder.sys uses these fields:  
| Offset | Size | Comment |
|--------|------|---------|
| 0x04 | 4 | Pointer to the control GUID |
| 0x30 | 4 | Pointer to the default log. Not 0 = already started |
| 0x34 | 2 | `VerboseOn` |
| 0x36 | 2 | `ForceLogsInMiniDump` |

### Start

`WppAutoLogStart`:
1. If `control+0x30` isn't 0: `DbgPrint("Error: WPP auto recorder is already started\n")` and return. If `g_IsDllDisabled` is set, it returns silently.
2. `RtlGetVersion`: sets `IsWin8OrLater ?` (OS version ≥ 6.2) in the context. This field is never read.
3. Allocates and zeroes the 132-byte [driver context](#driver-context).
4. Reads the registry (see [Registry](#registry)).
5. Copies the 16-byte control GUID.
6. Copies the end of `RegistryPath`, after the last `\`, as the driver name: the service name, at most 31 characters, keeping only the low byte of each UTF-16 character.
7. Creates the default log with a total size of `LogPages × 4096 − 100`, no error partition and the tag `WPLg`, so that the allocation is exactly `LogPages` pages. Its identifier is `DriverLog`.
8. `WppAutoLogpGetImageBase` (0x11EB0) finds the module containing `DriverObject->DriverStart`, with `RtlQueryModuleInformation` or else `ZwQuerySystemInformation(SystemModuleInformation)`. On success it fills the image base and size, then registers the driver callback (`KbCallbackSecondaryDumpData`).
9. Stores the default log in the context and in `control+0x30`.

A failed allocation only produces a `DbgPrint`: tracing is silently absent and the client driver still starts. If the module lookup fails, the driver callback isn't registered, the image range stays 0, and the logs only go in the dump when `ForceLogsInMiniDump` is set.

### Stop

`WppAutoLogStop` deletes the default log, removes the driver callback and frees the context.

> [!NOTE]
> The last instruction doesn't clear `control+0x30` as it should. It writes 0 through `WPP_GLOBAL_Control`, the recorder's own global (`.data:0x14008`), which points to itself, so the write lands in `.data:0x14038`. The client's control block keeps a dangling pointer to the freed log: a second `WppAutoLogStop`, or any later export using that control block, reads freed memory.  
> [acpiex.sys](./acpiex.md) hides this problem: after `WppAutoLogStop`, its `WppCleanupKm` sets its own `WPP_GLOBAL_Control` back to the initial value, so it stops using that control block.  
> Other logs made with `WppRecorderLogCreate` aren't deleted. If the client hasn't deleted them, their bugcheck callbacks stay registered with a pointer to the freed context.

### imp_WppRecorderConfigure

Parameter structure:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not read |
| 04 | 00 | Keep a usable default log (`CreateDefaultLog` ?). 0 = no |

Sets the `Configured ?` flag of the context, which is never read. If byte 04 is 0, the default log is deleted and replaced by a log of size 0: `WppAutoLogTrace` then fails on it, and `imp_WppRecorderIsDefaultLogAvailable` returns FALSE.  
If this allocation fails, the context is freed and `control+0x30` is set to 0.

### imp_WppRecorderLogCreate

Parameter structure:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not read (`Size` ?) |
| 04-07 | ? | Pool tag. 0 = `WPLg` |
| 08-0B | ? | Total buffer size, limited to the minimum and maximum of the [registry](#registry) |
| 0C-0F | ? | Size of the error partition, limited to half of the total |
| 10-13 | ? | Copied to offset 0x1C of the log. Never read |
| 14 | ? | Copied to offset 0x18 of the log. Never read |
| 18-1B | ? | Maximum number of characters of the identifier |
| 1C-2B | ? | Identifier (ASCII). At most 15 characters + NUL are kept. If the value at 18-1B is above 0x7FFFFFFE, the identifier stays empty |

*log is set to NULL at entry.  
Returns `STATUS_INSUFFICIENT_RESOURCES` when the allocation fails or when the recorder isn't started.  
Exception: if `g_IsDllDisabled` is set and there's no context, it returns `STATUS_SUCCESS` with a NULL log.

### imp_WppRecorderLinkCounters

Makes the logs of two drivers share a sequence counter, probably so that their records can be ordered ?. The sequence number is the only ordering information: a record has no timestamp.  
1. Increments the link count of the context (`LinkCount`). If it isn't 1 now, it returns `STATUS_UNSUCCESSFUL`. The count isn't restored, so a failed call also blocks the following ones.
2. `*counter = max(own counter, *counter) + 10`.
3. `SequencePointer` now points to `counter`.

NULL `counter` or missing context → `STATUS_UNSUCCESSFUL`.

### imp_WppRecorderGetTriageInfo

Fills 5 DWORDs. Returns `STATUS_UNSUCCESSFUL` for a NULL pointer. The values describe the structures below:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 64 00 00 00 | 100: size of the log header |
| 04-07 | 44 00 00 00 | 68: offset of `Context` in the log |
| 08-0B | 60 00 00 00 | 96: offset of `TotalSize` in the log |
| 0C-0F | 04 00 00 00 | 4: size of `TotalSize` ? |
| 10-13 | 84 00 00 00 | 132: size of the driver context |

### Driver context

Allocated from `NonPagedPoolNx` with the tag `WPLg`, size 132 bytes. Field names are descriptive: they don't come from symbols.  
| Offset | Size | Field | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | Sequence | Local sequence counter |
| 0x04 | 4 | ImageBase | Base of the client driver |
| 0x08 | 4 | ImageSize | Size of the client driver |
| 0x0C | 1 | ForceDump | From `ForceLogsInMiniDump`, or set to 1 when a bugcheck matches the driver |
| 0x10 | 4 | MinBytes | Minimum size of a log |
| 0x14 | 4 | MaxBytes | Maximum size of a log |
| 0x18 | 1 | Configured ? | Set by `imp_WppRecorderConfigure`. Never read |
| 0x19 | 1 | IsWin8OrLater ? | Never read |
| 0x1C | 28 | | `KBUGCHECK_REASON_CALLBACK_RECORD` of the driver |
| 0x38 | 36 | | [Driver block](#driver-block) |
| 0x5C | 16 | Guid | Control GUID |
| 0x6C | 8 | | `LIST_ENTRY` of the logs |
| 0x74 | 4 | | `KSPIN_LOCK` of the list |
| 0x78 | 4 | DefaultLog | |
| 0x7C | 4 | SequencePointer | Points to `Sequence`, or to a linked counter |
| 0x80 | 4 | LinkCount | |

### Driver block

This 36-byte part of the context is what the driver callback and `imp_WppRecorderDumpLiveDriverData` return.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-1F | 'acpiex' | Driver name (ASCII, NUL-terminated), e.g. the service name of [acpiex.sys](./acpiex.md). It is also the `Component` of the bugcheck callback records |
| 20-21 | ? | Last log number given |
| 22-23 | ? | Number of live logs |

When the live count falls below half of the last number given, `WppAutoLogDeleteLog` (0x117C4) renumbers the logs from 1 in list order. The number changes the GUID of a log in the dump, see [Crash dump](#crash-dump).

### Log

Allocated by `WppAutoLogCreateLog` (0x116E0) from `NonPagedPoolNx`, size 100 + total size. The log is added to the list of the context, gets a number, and registers its own bugcheck callback.  
| Offset | Size | Field | Comment |
|--------|------|-------|---------|
| 0x00 | 8 | | `LIST_ENTRY` |
| 0x08 | 16 | Identifier | ASCII, e.g. `DriverLog` |
| 0x18 | 1 | | From the parameters of `imp_WppRecorderLogCreate`. Never read |
| 0x1C | 4 | | From the parameters of `imp_WppRecorderLogCreate`. Never read |
| 0x20 | 28 | | `KBUGCHECK_REASON_CALLBACK_RECORD` of the log |
| 0x3C | 4 | PoolTag | |
| 0x40 | 2 | Number | See [Driver block](#driver-block) |
| 0x44 | 4 | Context | [Driver context](#driver-context) |
| 0x48 | 4 | ErrorBase | Start of the error partition |
| 0x4C | 4 | ErrorSize | |
| 0x50 | 2 | ErrorWrite | Next write offset |
| 0x52 | 2 | ErrorLast | Offset of the newest record |
| 0x54 | 4 | GeneralBase | Start of the general partition |
| 0x58 | 4 | GeneralSize | Total size − error size |
| 0x5C | 2 | GeneralWrite | Next write offset |
| 0x5E | 2 | GeneralLast | Offset of the newest record |
| 0x60 | 4 | TotalSize | |
| 0x64 | | | Buffer: general partition, then error partition |

### Writing a record

`WppAutoLogTrace`:
1. A NULL log → `STATUS_UNSUCCESSFUL`.
2. Chooses the partition: the error partition if the second parameter is 2 (`TRACE_LEVEL_ERROR` ?) and it has a size, else the general partition. So the errors of a log aren't overwritten by more frequent messages.
3. The variable arguments are (pointer, length) pairs, ended by a NULL pointer. Length 0 is skipped. A single length above 256, a total above 256 after rounding up to 4 bytes, or a record larger than the partition drops the message: the sequence counter is incremented, leaving a visible gap, and the call returns `STATUS_UNSUCCESSFUL`.
4. Reserves the space with an atomic compare-and-swap (`LDREX` / `STREX`) on the two 16-bit fields `Write` and `Last`. There's no lock. If the record doesn't fit before the end of the partition, `Write` goes back to 0: the older records are overwritten with no erase.
5. Fills the record and increments the sequence counter atomically.

Format of a record, in a partition (4-byte padded):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 4C 52 | Signature 0x524C, "LR" in memory |
| 02-03 | ? | Total record size, header included |
| 04-07 | ? | Sequence number |
| 08-09 | ? | Offset of the previous record. Reading backwards from `Last` follows this chain, including across the wrap |
| 0A-0B | ? | Message number: the same value as in the ETW call of the WPP macro |
| 0C-1B | ? | Trace GUID (fourth parameter, `WPP_<hash>_Traceguids` in the client): the same value as in the ETW call of the WPP macro |
| 1C-.. | ? | Arguments, copied end to end (at most 256 bytes) |

There's no timestamp, level or flag in a record. The third parameter of `WppAutoLogTrace`, the WPP flag number, isn't used.

### Use by acpiex.sys

`WppInitKm` (0x1C6B0 in `ACPIEX.SYS`) calls `WppAutoLogStart(WPP_GLOBAL_Control, DriverObject, RegistryPath)` with the parameters of `DriverEntry`. `WppCleanupKm` (0x1E644) calls `WppAutoLogStop`.  
The 46 generated functions `WPP_RECORDER_SF_*` each make one call to `WppAutoLogTrace`:
- The log is `control+0x30`, read by the callers of these functions, so all the traces of acpiex.sys go to the default log.
- The second parameter is always 0, so the error partition is never chosen. The default log doesn't have one anyway.
- The third parameter is the WPP flag number, 2 or 7 to 9 when it is a constant: flag N is the bit `1 << (N-1)` tested at `control+0x20` before the ETW call (e.g. 9 → 0x100).
- The call comes after this test and doesn't depend on it, so a message is recorded even when no ETW session has enabled its flag.

### Crash dump

Each driver and each log register a `KbCallbackSecondaryDumpData` callback (`KeRegisterBugCheckReasonCallback`, reason 2). Both first call `WppAutoLogpBugCheckCallbackFilter` (0x11F74): the data is added only if `ForceDump` is set, or if an address given by the bugcheck is inside the image of the client driver.  
| Bugcheck | Name | Parameter tested |
|----------|------|------------------|
| 0x0A | IRQL_NOT_LESS_OR_EQUAL | 4 |
| 0xD1 | DRIVER_IRQL_NOT_LESS_OR_EQUAL | 4 |
| 0x1E | KMODE_EXCEPTION_NOT_HANDLED | 2 |
| 0x7E | SYSTEM_THREAD_EXCEPTION_NOT_HANDLED | 2 |
| 0x8E | KERNEL_MODE_EXCEPTION_NOT_HANDLED | 2 |
| 0x20 | KERNEL_APC_PENDING_DURING_EXIT | 1 |
| 0x50 | PAGE_FAULT_IN_NONPAGED_AREA | 3 |

Any other bugcheck doesn't match. Once matched, `ForceDump` stays at 1, so the remaining callbacks of this driver add their data without testing again.

The filter also tests the WORD at `WPP_GLOBAL_Control + 0x36`. Like in [Stop](#stop), this is the recorder's own global and not the client's control block: `.data:0x1403E` is never written, so this test has no effect.

Secondary dump data:  
| Callback | Address | Data | Size | GUID |
|----------|---------|------|------|------|
| Driver | `WppAutoLogpBugCheckCallbackForDriver` 0x12090 | [Driver block](#driver-block) | 36 | Control GUID |
| Log | `WppAutoLogpBugCheckCallbackForLog` 0x120D8 | Whole log: header + buffer | 100 + total size | Control GUID, with `Data2` XOR the log number |

The data isn't copied: the callback gives a pointer to the live memory. A log is skipped when it is larger than `MaximumAllowed` (`WppAutoLogGetBugCheckDataForLog`, 0x12014, returns `STATUS_BUFFER_TOO_SMALL`).

### Pool tags

| Tag | Value | Pool | Comment |
|-----|-------|------|---------|
| WPLg | 0x674C5057 | NonPagedPoolNx | Driver context, and logs with no tag of their own |
| WL03 | 0x33304C57 | PagedPool | Temporary list of modules (`WppAutoLogpGetImageBase`) |
| AuxK | 0x4B787541 | Paged, with quota | Temporary buffer of `AuxKlibQueryModuleInformation`, when `RtlQueryModuleInformation` is missing |
