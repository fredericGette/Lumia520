## Werkernel.sys

Windows Error Reporting for the kernel: policy, throttling and dump files of the **live kernel reports** (live dumps).  
It's a kernel **export driver** (internal name `werkernel.dll`, PDB `werkernel.pdb`, 59 functions): `DriverEntry` (`FxDriverEntry` → `FxDriverEntryWorker`, 0x100034C8) just returns `STATUS_UNSUCCESSFUL` (0xC0000001). It implements the API set `ext-ms-win-ntos-werkernel-l1-1-0` imported by [NTOSKRNL.EXE](../libraries/ntoskrnl.md): the kernel calls [WerLiveKernelInitSystem](#werlivekernelinitsystem-0x100037cc) during `Phase1InitializationIoReady`, and a kernel component that wants a live dump (e.g. [wpcrdmp.sys](./wpcrdmp.md) with the report `AbnormalReset`) goes through [WerLiveKernelCreateReport](#werlivekernelcreatereport-0x100035a0).  
werkernel.sys doesn't write the dump itself: it decides if a dump is allowed (and which type) from `CrashDumpEnabled`, the configuration of the telemetry service (`telrepsvc`) and per-component throttling, creates the `.dmp` file in the `LiveDumps` directory next to the `DedicatedDumpFile`, and returns its handle to the caller (the dump writer of the kernel ?). When the report is submitted, it records the time of the report in the registry and signals a WNF state so that the user-mode telemetry service picks up the dump.  
It also contains a copy of the SQM helpers of the subsystem restart code (`SsrOpenRegistry`, `SsrSqmAddToStreamEx`): every call to `WerLiveKernelCreateReport` increments `SubSystemRebootCount`.

It imports only `ntoskrnl.exe` (registry, files, `ZwUpdateWnfStateData`, ETW, `ERESOURCE`).  
There's no device object, no symbolic link and no IOCTL.  
Debug messages are prefixed by `WERKERNEL: ` (`DbgPrintEx` component 0x96, level 1 = error, 3 = info); the SQM part uses component 0x4D without prefix.  
Pool tags: `werk` (0x6B726577, everything), `MQSs` (0x7353514D, SQM event buffer).

### Exports

| Ordinal | Function | Address |
|---------|----------|---------|
| 1 | [WerLiveKernelCancelReport](#werlivekernelcancelreport-0x100034d8) | 0x100034D8 |
| 2 | [WerLiveKernelCloseHandle](#werlivekernelclosehandle-0x10003534) | 0x10003534 |
| 3 | [WerLiveKernelCreateReport](#werlivekernelcreatereport-0x100035a0) | 0x100035A0 |
| 4 | [WerLiveKernelInitSystem](#werlivekernelinitsystem-0x100037cc) | 0x100037CC |
| 5 | [WerLiveKernelOpenDumpFile](#werlivekernelopendumpfile-0x100038ac) | 0x100038AC |
| 6 | [WerLiveKernelSubmitReport](#werlivekernelsubmitreport-0x10003950) | 0x10003950 |

Usual sequence: `CreateReport` → `OpenDumpFile` → (the caller writes the dump in the file and closes it) → `SubmitReport` or `CancelReport` → `CloseHandle`.

### Registry

Registry key `\Registry\Machine\SYSTEM\CurrentControlSet\Control\CrashControl` (see also [wpcrdmp.sys](./wpcrdmp.md)):  
| Registry value | value | comment |
|----------------|-------|---------|
| CrashDumpEnabled | e.g. 0 | ULong, read at each `WerLiveKernelInitSystem` (`sub_10004A40`). Gives the highest dump type allowed: 0 → none, 1, 2 → full, 3, 4 → mini, 5 to 7 → full, 0xFFFFFFFF → none, other values → none ("Unknown CrashDumpEnabled value") |
| DedicatedDumpFile | e.g. D:\DedicatedDump.sys | String, read once (`TelpInitRootPath`, `sub_10004700`, `RtlQueryRegistryValuesEx` direct, 510 bytes max). The file name is replaced by `LiveDumps`: the live dumps go in `D:\LiveDumps` |

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\telrepsvc\Parameters\Config` (configuration of the telemetry service, "TELCFG", `sub_100056C4` / `sub_10005588`):  
The driver contains the whole table of the telemetry configuration (50 values, defaults at `.data:0x10008028`, `.data:0x10008008` and `.rdata:0x100022D0`), but it only reads the following ones. A value is read lazily on first use, must be a REG_DWORD, and the default is used when it's missing or of another type.  
| Registry value | value | comment |
|----------------|-------|---------|
| LiveDumpsDisabled | 0 | ≠ 0 → `WerLiveKernelInitSystem` fails with `STATUS_NOT_IMPLEMENTED` (0xC0000002) "Live dumps are disabled", so every later report fails |
| LiveMaxQueuedReports | 10 | Maximum number of `*.dmp` files waiting in the `LiveDumps` directory. Also the maximum number of name collisions accepted when creating a dump file |
| SystemLiveMiniThrottleThreshold | 0 | Hours. Minimum time between 2 mini live dumps, all components together |
| ComponentLiveMiniThrottleThreshold | 24 | Hours. Minimum time between 2 mini live dumps of the same component. Raised to SystemLiveMiniThrottleThreshold if lower |
| SystemLiveFullThrottleThreshold | 120 | Hours. Minimum time between 2 full live dumps, all components together |
| ComponentLiveFullThrottleThreshold | 168 | Hours. Minimum time between 2 full live dumps of the same component. Raised to SystemLiveFullThrottleThreshold if lower |
| LiveFullThrottleAction | 0 | Dump type granted instead when a full dump is requested but `CrashDumpEnabled` only allows a mini dump (and LiveFullThrottleAction ≤ the allowed type) ? |

Other values of the table (defaults), not used by werkernel.sys: PackageInternal (0), PackageTest (0), PackageSelfhost (0), WpOsSkuOverride (104), MinStorageQuotaKb (51200), MaxStorageQuotaKb (512000), StorageQuotaFreeSpaceScaleFactor (50), UploadQuotaPeriod (7), MaximumUploadFailures (9), UploadUseServerPrefix (1), UploadUseSecure (1), UploadBypassProxy (0), UseSdMount (0), SdCardBootWaitMs (120000), WatsonDumpType (0x1001A4), WatsonQuickDumpType (0x1001A4), MaxDebugAppDumps (1), MaxConcurrentDumpWorkers (4), MaxConcurrentEtwThreads (8), DebugAppDumpPolicy (1), DebugAppDumpMinRequiredDiskSpace (209715200), AllowOnlineSecondaryData (1), AllowOnlineSecondaryDataTimeout (3000), AllowOnlineSecondaryDataMasterProcessTimeout (10000), SvcMaxIdleMs (5000), CrashDumpEnabledValue (3), SqmReportTimeScaling (100), MaximumSimultaneousReportsUpload (10), MaximumXProcDumps (10), UploadQuota (QWORD 0x40000000), UploadServer (`telemetry.microsoft.com`), UploadUrl (`Telemetry.Request`), UploadSource (`retail`), UploadSourceExternal, SelfhostUser, CabArchiveDirectory, UploadQuotaRoot (`SYSTEM\CurrentControlSet\Services\telrepsvc\Parameters\UploadQuota`), TelDirectory (`C:\Data\SystemData\Telemetry`), TempDirectory (`C:\Data\SystemData\Telemetry\Temp`), EtwDirectory (`C:\Data\SystemData\ETW\Telemetry`), SdCardMount (`D:\Telemetry\`), WatsonEventOverride, WatsonEventOverrideP0.

Registry key `\Registry\Machine\SYSTEM\CurrentControlSet\Services\telrepsvc\Parameters\LiveReports` (created if missing, non-volatile):  
| Registry value | value | comment |
|----------------|-------|---------|
| Components\LastFullLiveReport | ? | REG_QWORD, system time (UTC, 100 ns) of the last submitted live report, any type |
| Components\\<ComponentName>\LastFullLiveReport | ? | REG_QWORD, system time of the last submitted live report of this component, any type. One subkey per component that has already submitted a report |

> [!NOTE]
> The driver uses the name `LastFullLiveReport` for **both** dump types (the 2 `UNICODE_STRING` built in `TelpInitThrottlePolicy` and `TelpSetLastReportTime` point to the same string): a mini report is recorded as `LastFullLiveReport`, and when the policy is reloaded from the registry the "last mini" time also takes the value of `LastFullLiveReport`. In memory the 2 times are kept separately until the next reload, which happens at each `CheckPolicy` of a mini / full report (see [Throttling](#throttling)). So after a full report, the same component gets no mini report for ComponentLiveMiniThrottleThreshold hours, and after a mini report, no full report for ComponentLiveFullThrottleThreshold hours (bug ?).

Registry key `\Registry\machine\SYSTEM\CurrentControlSet\Services\telrepsvc\Parameters\SqmData`:  
| Registry value | value | comment |
|----------------|-------|---------|
| SubSystemRebootCount | ? | ULong, **incremented** (created with 1) at each call to `WerLiveKernelCreateReport`, even when the call fails (`sub_1000738C`). The new value is sent as SQM data point 0x965 |

### GUID and WNF

GUID of the ETW provider (event 612 at the end of `WerLiveKernelCreateReport`, `sub_100053D8`)  
`{3a560832-fabf-41fd-9c00-598939c72f27}`

`Microsoft_Windows_SQM_Provider` (SQM data points 0x965 and 0x966, same provider as [dxgkrnl.sys](./dxgkrnl.md) and [netact.sys](./netact.md))  
`{a97524f6-064c-4c4e-b74b-1acc87c3700d}`

SQM session / stream GUID ? (first field of the 2 SQM events)  
`{fa656545-623d-46b9-83d6-984fd984cef2}`

WNF state updated by `WerLiveKernelSubmitReport` (`TelpSignalWnfLiveDumpReady`, `sub_100049A4`):  
| State name | Decoded | Data |
|------------|---------|------|
| 0x418A0B39A3BC2875 (`.rdata:0x10002340`) | `TEL`, 5, well-known, system scope ("live dump ready") | 4 bytes: tick count in ms since boot (from `KUSER_SHARED_DATA`), never 0 |

ETW events:  
| Provider | Event | Payload | Written by |
|----------|-------|---------|------------|
| {3a560832-…} | Id 612, version 0, level 4, keyword 0x202000 | ComponentName (UTF-16 string, `NULL` if none), granted dump type (ULONG), NTSTATUS (ULONG) | `WerLiveKernelCreateReport`, always. The provider is registered and unregistered around each event |
| SQM {a97524f6-…} | Id 5, version 1, level 4, keyword 0x0008000000000000 | GUID {fa656545-…}, data point 0x965, value = new SubSystemRebootCount | `sub_10007000` |
| SQM {a97524f6-…} | Id 17, version 0, level 4, keyword 0x0008000000000000 | GUID {fa656545-…}, stream 0x966, count of entries (1), size, entries (type 1 = ULONG, 2 = string ≤ 128 chars, 3 = 8 bytes): here 1 string = ComponentName | `sub_100070D4` (`SsrSqmAddToStreamEx`) |

### Dump types

The "Policy" exchanged with the caller is a dump type:  
| Value | Meaning |
|-------|---------|
| 0 | No dump (refused / throttled) |
| 1 | Mini live dump |
| 2 | Full live dump |

The highest type allowed (`dword_100081C0`) comes from `CrashDumpEnabled` (see [Registry](#registry)).

### Report context

`WerLiveKernelCreateReport` returns a pointer to a context of 644 bytes (0x284, PagedPool, tag `werk`). Every export checks its signature.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 54 6C 6B 63 | Signature 0x636B6C54 ("Tlkc") |
| 04-07 | 01 00 00 00 | Granted dump type (1 or 2) |
| 08-0B | | ? (0) |
| 0C-2B | | ComponentName, UTF-16, 15 characters max + 0 |
| 2C-7B | | Report ID = file name of the dump: `<ComponentName>-YYYYMMDD-HHMM.dmp` (local time), or `<ComponentName>-YYYYMMDD-HHMM-NN.dmp` after a name collision, 40 characters max |
| 7C-283 | | Path of the dump: `<root>\<report ID>`, 260 characters max. Empty when no file is open |

The root is the directory of `DedicatedDumpFile` + `LiveDumps` (`word_100081C8`, e.g. `D:\LiveDumps`); `\??\` is prepended when opening files.

### Throttling

`TelpCheckPolicy` (`sub_10003E9C`) computes the dump type granted to a request:
1. Component `AbnormalReset` (reset reports of [wpcrdmp.sys](./wpcrdmp.md)): granted = min(requested, allowed), without time threshold. Only the queue limit is checked: queue full → 0.
2. Other components: granted = requested if ≤ allowed. Otherwise allowed (with the special case of `LiveFullThrottleAction` above). If the result is 1 or 2, `TelpDumpTypeIsThrottled` (`sub_1000463C`) can turn it into 0:
   - re-reads the TELCFG and the throttle policy from the registry (`TelpInitThrottlePolicy`, `sub_10004B28`). The previous list of components is dropped without being freed (leak);
   - system threshold (`TelpExceedsSystemThreshold`, `sub_10004588`): last report of this type (all components) + System…ThrottleThreshold must be ≤ now;
   - component threshold (`TelpExceedsPerComponentThreshold`, `sub_10004420`): last report of this type by the component + Component…ThrottleThreshold must be ≤ now (no previous report → OK);
   - queue (`sub_10003D5C`): opens the root directory (created if missing, `FILE_CREATE`), counts the `*.dmp` files that are not directories / devices / reparse points (`ZwQueryDirectoryFile`, `FileDirectoryInformation`); reaching `LiveMaxQueuedReports` → 0xC000042B and the request is throttled. The message "Max queued live dumps limit reached" is printed on the wrong condition: for any other error, and not for 0xC000042B.

The thresholds are in hours, converted to 100 ns units (× 36000000000). The last report times are kept in memory (`qword_10008180` mini, `qword_10008188` full, plus a linked list of 56-byte nodes per component at `dword_100081B8`: name WCHAR[16], last full time at +0x20, last mini time at +0x28, next at +0x30).

---

### WerLiveKernelInitSystem (0x100037CC)

`NTSTATUS WerLiveKernelInitSystem(…)` (the parameters are not used)  
Called by NTOSKRNL during `Phase1InitializationIoReady`.
1. Creates the TELCFG object (opens the `telrepsvc\Parameters\Config` key; a missing key is accepted). Failure → its HRESULT converted to NTSTATUS (`sub_10003C8C`).
2. `LiveDumpsDisabled` ≠ 0 → `STATUS_NOT_IMPLEMENTED` (0xC0000002).
3. Highest allowed dump type from `CrashDumpEnabled`.
4. `TelpInitRootPath` (only the first time): root directory from `DedicatedDumpFile`.
5. `TelpInitThrottlePolicy`: thresholds, `LiveMaxQueuedReports`, `LiveFullThrottleAction`, opens / creates `telrepsvc\Parameters\LiveReports\Components`, reads `LastFullLiveReport` of the key and of each subkey.
6. Marks the reports as initialized (`byte_10008160`).

### WerLiveKernelCreateReport (0x100035A0)

`NTSTATUS WerLiveKernelCreateReport(PCWSTR ComponentName, PULONG Policy, PVOID *ReportHandle)`  
| Parameter | Comment |
|-----------|---------|
| ComponentName | Name of the report type / component, max 15 characters, e.g. `AbnormalReset` |
| Policy | In: requested dump type. Out: granted dump type (0 on failure) |
| ReportHandle | Out: the [report context](#report-context), NULL on failure |

1. Sends the SQM stream 0x966 with ComponentName and increments `SubSystemRebootCount` (data point 0x965), before any check.
2. Reports not initialized → `STATUS_NOT_IMPLEMENTED` (0xC0000002).
3. ComponentName ≥ 16 characters → `STATUS_INVALID_PARAMETER` (0xC000000D) "Key key length exceeded".
4. Allocates the context, [TelpCheckPolicy](#throttling). Granted type 0 → `STATUS_ACCESS_DENIED` (0xC0000022) "CheckPolicy throttled dump creation".
5. Copies ComponentName into the context and returns it.

Any NULL parameter → `STATUS_INVALID_PARAMETER`. Allocation failure → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A). The ETW event 612 (ComponentName, granted type, status) is written in every case except the invalid parameters.

### WerLiveKernelOpenDumpFile (0x100038AC)

`NTSTATUS WerLiveKernelOpenDumpFile(PVOID ReportHandle, PHANDLE FileHandle)`  
`TelpCreateDumpFile` (`sub_10003FA0`):
1. A file was already created for this report → 0xC0000107 "A dump file has already been opened".
2. `TelpSetDumpFileName` (`sub_10004F44`): report ID from the local time, path = `%wZ\%ws` (root, report ID).
3. `ZwCreateFile(FILE_GENERIC_WRITE (0x120116), FILE_ATTRIBUTE_NORMAL, ShareAccess = 0, FILE_CREATE, FILE_WRITE_THROUGH | FILE_SYNCHRONOUS_IO_NONALERT, OBJ_CASE_INSENSITIVE | OBJ_KERNEL_HANDLE)`.
4. On failure (e.g. the name exists), retries with the suffix `-01`, `-02`… up to `LiveMaxQueuedReports`.

Returns the kernel handle of the file. werkernel.sys never closes it: the caller writes the dump and closes the handle.

### WerLiveKernelSubmitReport (0x10003950)

`NTSTATUS WerLiveKernelSubmitReport(PVOID ReportHandle)`  
1. `TelpSubmitReport` / `TelpSetLastReportTime` (`sub_10005030`): stores the current system time as last report time of the dump type, in memory (system and component), then writes it as REG_QWORD `LastFullLiveReport` in `LiveReports\Components` and in `LiveReports\Components\<ComponentName>` (subkey created if needed).
2. `TelpSignalWnfLiveDumpReady`: updates the WNF state 0x418A0B39A3BC2875 with the tick count. A WNF failure is traced but the function still returns success.

Invalid handle → `STATUS_INVALID_PARAMETER`. Dump type of the context not 1 or 2 → `STATUS_INVALID_PARAMETER`.

### WerLiveKernelCancelReport (0x100034D8)

`NTSTATUS WerLiveKernelCancelReport(PVOID ReportHandle)`  
`TelpDeleteDumpFile` (`sub_10004330`): if a dump file was created for the report, opens it with `DELETE | SYNCHRONIZE`, `FILE_OPEN`, `FILE_DELETE_ON_CLOSE` and closes it (the file is deleted). Returns 0, or `STATUS_INVALID_PARAMETER` for an invalid handle. The last report times are not updated.

### WerLiveKernelCloseHandle (0x10003534)

`NTSTATUS WerLiveKernelCloseHandle(PVOID ReportHandle)`  
Checks the signature and frees the context (`ExFreePoolWithTag(…, 'werk')`). It neither closes the dump file handle nor deletes the file.
