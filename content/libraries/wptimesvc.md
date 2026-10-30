## WPTimeSvc.dll

The automatic time service of Windows Phone 8.1: it sets the clock and the time zone from the cellular network (NITZ) and from NTP.  
`WPTimeSvc.dll` is a svchost service DLL (65 536 bytes, 181 functions, a third of them CRT, STL and RPC/ALPC stubs). It has no RPC server and no exported API except the service entry points. It subscribes to six WNF states. The NITZ time and time zone of the two modems (`WNF_CELL_NETWORK_TIME_CAN0/1`) are applied directly (`SetSystemTime`, `SetTimeZoneInformationByID`). For NTP, it configures and starts the standard `W32Time` service, asks it to resync over its RPC interface (`W32TIME_ALT`), and schedules the next sync as a task of the Task Scheduler service (`ITaskSchedulerSvcRpc`, the interface of [ShellChromeAPI.dll](./shellchromeapi.md#task-scheduler-rpc-reminders)). Each sync is remembered in a WNF state (`LastSyncInfo`), and `WNF_SHL_SYSTEM_CLOCK_CHANGED` is published after every clock change.  
The settings are the `HKLM\System\State\DateTime` values written by the "date+time" settings page ([DateTimeCPLdll.dll](./datetimecpldll.md)), whose automatic time switch reaches the service through the WNF state `WNF_SHL_AUTOTIMEUPDATE_STATE_CHANGED`. The publishers of the cellular states are the modem / RIL stack (not analysed). Most traces go through `ZTrace.dll` (`ZTraceHelper`, `ZTraceReportOrigination`…), with the C++ class and method names of the source.

Location on the phone: `C:\Windows\System32\WPTimeSvc.dll` ? (svchost service; the service name is taken from `ServiceMain`'s `argv[0]`, it isn't in the binary).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `NtQueryWnfStateData`, `RtlPublishWnfStateData`, `ZwAlpcConnectPort`, `ZwAlpcSendWaitReceivePort`, `ZwAlpcCancelMessage`, `ZwAlpcDisconnectPort`, `ZwAlpcQueryInformation`, `AlpcInitializeMessageAttribute`, `AlpcGetMessageAttribute`, `TpAllocAlpcCompletion`, `TpWaitForAlpcCompletion`, `TpReleaseAlpcCompletion`, `RtlWaitOnAddress`, `RtlWakeAddressAll`, `RtlInitUnicodeString`, `ZwClose`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlNtStatusToDosError`, `vDbgPrintEx` |
| RPCRT4.dll | `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW`, `RpcStringFreeW`, `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingFree`, `NdrClientCall2`, `RpcExceptionFilter`, `I_RpcExceptionFilter` |
| SecRuntime.dll | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor` |
| ZTrace.dll | `ZTraceHelper`, `ZTraceHelperNoThis`, `ZTraceReportOrigination`, `ZTraceReportOriginationNoThis`, `ZTraceReportPropagation`, `ZTraceReportPropagationNoThis` |
| WPGLOBUTIL.dll | `GetTimeZoneList`, `SetTimeZoneInformationByID` |
| WPCOREUTIL.dll | `SHGetKnownFolderPath` |
| api-ms-win-service-core-l1-1-1.dll | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-service-management-l1-1-0.dll | `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `CloseServiceHandle` |
| api-ms-win-service-winsvc-l1-2-0.dll | `QueryServiceStatus`, `ControlService` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetSystemTime`, `SetSystemTime`, `GetSystemTimeAsFileTime`, `GetTickCount64` |
| api-ms-win-core-timezone-l1-1-0.dll | `GetTimeZoneInformation`, `SetTimeZoneInformation`, `SystemTimeToFileTime`, `FileTimeToSystemTime` |
| api-ms-win-core-registry-l1-1-0.dll | `RegGetValueW` |
| api-ms-win-core-registry-l2-1-0.dll | `RegSetKeyValueW`, `RegDeleteKeyValueW` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `OpenProcessToken`, `GetCurrentThreadId`, `TerminateProcess` |
| api-ms-win-security-lsalookup-l2-1-1.dll | `LookupPrivilegeValueW` |
| api-ms-win-security-base-l1-2-0.dll | `AdjustTokenPrivileges`, `GetSecurityDescriptorDacl` |
| api-ms-win-security-sddl-l1-1-0.dll | `ConvertStringSecurityDescriptorToSecurityDescriptorW` |
| api-ms-win-security-provider-l1-1-0.dll | `SetNamedSecurityInfoW` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW` |
| api-ms-win-core-threadpool-l1-2-0.dll | `TrySubmitThreadpoolCallback`, `CreateThreadpoolCleanupGroup`, `CloseThreadpoolCleanupGroup`, `CloseThreadpoolCleanupGroupMembers` |
| api-ms-win-core-threadpool-legacy-l1-1-0.dll | `UnregisterWaitEx` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `WaitForSingleObjectEx`, `Sleep`, `InitializeCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`, `InitializeSRWLock`, `AcquireSRWLockShared`, `ReleaseSRWLockShared`, `AcquireSRWLockExclusive`, `ReleaseSRWLockExclusive` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetProcAddress`, `FreeLibrary` |
| api-ms-win-core-com-l1-1-1.dll | `CoTaskMemFree` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalFree` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memmove`, `memset`, `memcmp`, `wcslen`, `_wcsdup`, `_itow_s`, `_vsnwprintf`, `rand`, … (CRT, `_initterm`, C++ exceptions) |

The msvcrt, rtlsupport, errorhandling (except `GetLastError`) and `TerminateProcess` imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code. `GetProcAddress` / `FreeLibrary` are only used by the [stop callback](#service) on a module handle that is never set (dead code from a service template).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `W32Time` service ([w32time.dll](./w32time.md)) | `OpenServiceW` + `StartServiceW` / `ControlService(SERVICE_CONTROL_STOP)`, RPC `ncalrpc:[W32TIME_ALT]` ([W32Time RPC](#w32time-rpc)) | NTP client that actually talks to the time servers |
| `HKLM\System\ControlSet001\Services\W32Time\Parameters` and `\Config` | `RegSetKeyValueW` / `RegDeleteKeyValueW` | Configuration written for W32Time before each sync (server list, log file), see [Registry](#registry) |
| `<known folder {8C19F0BC-CFD5-48E0-807B-0682F051E368}>\NonEtwLogs\w32time.log` | `SHGetKnownFolderPath(…, 0x4000)`, `CreateFileW(OPEN_ALWAYS)`, `SetNamedSecurityInfoW` | Log file of W32Time, only when `NTP Service Logging Enabled` is set; written by W32Time, not by this DLL |
| RPC server of the Task Scheduler service (`ITaskSchedulerSvcRpc`, dynamic LRPC endpoint) | `RpcBindingCreateW` / `RpcBindingBind` ([Task Scheduler RPC](#task-scheduler-rpc)) | Task `NTP Time Sync Schedule`; the hosting service binary isn't known |
| `\PdcPort` | `ZwAlpcConnectPort` ([PDC activation](#pdc-activation)) | Power dependency coordinator (kernel): keeps the system active during the W32Time resync |

No DLL is loaded with `LoadLibrary`, no process is started and no COM object is created.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `ServiceMain` | 0x10004D38 | `DWORD argc, LPWSTR *argv` |
| 2 | `SvchostPushServiceGlobals` | 0x10004BB8 | `SVCHOST_GLOBAL_DATA *`: stored in `dword_1000B3C8` |

### Startup

`DllEntryPoint` (0x10008A64) → `dllmain_dispatch` (0x10008770): only the CRT initialisation (`sub_10008560`, `_initterm`); there is no ETW provider and no other DLL code at load time.

### Service

**ServiceMain** (0x10004D38):
1. `_wcsdup(argv[0])` (the service name; `E_OUTOFMEMORY` if it fails), `SERVICE_STATUS.dwServiceType = 0x20` (`SERVICE_WIN32_SHARE_PROCESS`), `RegisterServiceCtrlHandlerExW(argv[0], ServiceHandler)` (`sub_10004C9C`).
2. `SERVICE_START_PENDING` (`SetServiceStatus` helper `sub_10004B54`), stop event `CreateEventW(auto-reset)`.
3. `RegisterForWNFs` (`sub_100041BC`, see [WNF dispatch](#wnf-dispatch)).
4. `SERVICE_RUNNING`, controls accepted 0x401 (`SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_TRIGGEREVENT`), then `RegisterStopCallback` of the svchost globals (+0x60) with the stop event and `StopCallback` (`sub_10004BCC`); `ServiceMain` returns while the service keeps running.
5. On any failure: unregisters the WNF states, closes the event, `SERVICE_STOPPED` with the error in `dwWin32ExitCode`.

**ServiceHandler** (`sub_10004C9C`): `SERVICE_CONTROL_STOP` → `SERVICE_STOP_PENDING` and sets the stop event; `SERVICE_CONTROL_INTERROGATE` → 0. The other cases (shutdown, power events 0x8013 / 10, pre-shutdown, time change) call function pointers that are never set, and return `ERROR_CALL_NOT_IMPLEMENTED` (120).

**StopCallback** (`sub_10004BCC`, called when the stop event is set): unregisters the WNF states and destroys the dispatch queue (`sub_100043B0`), closes the stop event, `UnregisterWaitEx`, frees the name, `SERVICE_STOPPED`.

### WNF dispatch

`RegisterForWNFs` (`sub_100041BC`) creates the dispatch queue (0x70 bytes in `dword_1000B38C`: a `std::list` of notifications, a critical section, a thread-pool environment with a cleanup group; the handler is `_ProcessMessage`, `sub_100040F0`, stored in a `std::function`), then subscribes to five states with the callback `s_WnfNotificationCallback` (`sub_10003D78`): `WNF_CELL_NETWORK_TIME_CAN0`, `WNF_CELL_NETWORK_TIME_CAN1`, `WNF_DEVM_MULTIVARIANT_UI_STATUS`, `WNF_SHL_NETWORK_TIME_SYNC_TRIGGER` and `WNF_SHL_AUTOTIMEUPDATE_STATE_CHANGED` (see [WNF states](#wnf-states)). A failed subscription is only traced; the result of the last one is returned.

`s_WnfNotificationCallback` (disassembly only):
1. Identifies the state by `memcmp` of the 8-byte name. The two `CAN` states need a 0x30-byte buffer, the three others 4 bytes; anything else returns `STATUS_INVALID_PARAMETER`.
2. Copies the data (`operator new[]`) into a `shared_ptr<WNFNotification>` (`sub_10004590`: +0x04 state name, +0x0C change stamp, +0x10 data, +0x14 size) and appends it to the queue (`sub_10004858`). The first element starts a thread-pool work item (`TrySubmitThreadpoolCallback`, `sub_100048EC`) that calls `_ProcessMessage` for each queued notification, so the notifications are handled one at a time, in order.

`_ProcessMessage` (`sub_100040F0`):

| State | Handler |
|-------|---------|
| `WNF_CELL_NETWORK_TIME_CAN0` / `CAN1` | `DoNITZ(0 / 1)` (`sub_10003ED8`): [AutoTimeUpdate::Run](#nitz-autotimeupdate)(CAN id), then, if it succeeded, `LastSyncInfo::Publish(1, CAN id)` |
| `WNF_DEVM_MULTIVARIANT_UI_STATUS`, `WNF_SHL_NETWORK_TIME_SYNC_TRIGGER` | `DoMultivariant` (`sub_100040AC`): `LastSyncInfo::Run`; if there is no last sync (0x80070490), `DoNTP` |
| `WNF_SHL_AUTOTIMEUPDATE_STATE_CHANGED` | `DoCPLStateChanged`: DWORD ≠ 0 (automatic time switched on) → `LastSyncInfo::Run`, `DoNTP` if there is no last sync; 0 → stops the W32Time service (`StopW32Time`, `sub_100077B4`) |

**DoNTP** (`sub_10003FB0`): reads `WNF_CNET_DPU_GLOBAL_STATE_OVER_LIMIT` (4 bytes). If it's 1: [NTPSync::Run](#ntp-ntpsync)(NULL) then, on success, `LastSyncInfo::Publish(2, 0)`. If the state can't be read, there is only a trace. For another value it subscribes to that state once (`s_DPUCallback`, `sub_10003F24`), which waits for the value 1, unsubscribes and does `LastSyncInfo::Run`, then `NTPSync::Run` + `Publish(2, 0)` if there is no last sync. The meaning of the value (data usage under the limit ? network available ?) isn't known.

### LastSyncInfo

The last successful sync, kept in the WNF state 0x418A063EA3BD5875 (`SHL` 43), 0x20 bytes:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Provider: 1 = NITZ, 2 = NTP |
| 0x04 | 4 | Instance: CAN id (0 / 1) for NITZ, 0 for NTP |
| 0x08 | 16 | `SYSTEMTIME` (UTC) just after the sync (`GetSystemTime`) |
| 0x18 | 8 | `GetTickCount64` at the same moment |

- `LastSyncInfo::Publish(provider, instance)` (`sub_10004E94`): fills the structure and `RtlPublishWnfStateData` (0x20 bytes).
- `LastSyncInfo::Query` (`sub_10004F14`): `NtQueryWnfStateData`; a size other than 0x20 (state never published since boot) → 0x80070490 (`ERROR_NOT_FOUND`).
- `LastSyncInfo::Run` (`sub_10004F84`): replays the last provider. NITZ → `AutoTimeUpdate::Run(instance)` (the modem state is read again). NTP → `NTPSync::Run(&info)`, which doesn't contact the server: the time becomes `info.SYSTEMTIME` + (now − `info` tick count) (`sub_100058A0`), and it's set only if it differs from the clock by at least `NetworkTime UpdateThreshold` seconds (then `WNF_SHL_SYSTEM_CLOCK_CHANGED` is published). Any other provider → 0x8007139F (`ERROR_INVALID_STATE`).

### NITZ (AutoTimeUpdate)

`AutoTimeUpdate::Run(canId)` (`sub_10006638`, disassembly only) uses a settings structure on the stack:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `NetworkTime Enabled` |
| 0x04 | 4 | `NetworkTime Sync` (read only if the previous one is set) |
| 0x08 | 4 | `NetworkTime TimeZone Sync` (default 1, read only if `NetworkTime Sync` is set) |
| 0x0C | 4 | `NetworkTime Preferred Slot Number` (default 0xFF) |
| 0x10 | 4 | `NetworkTime UpdateThreshold` in seconds (default 60, accepted 1…59) |
| 0x14 | 8 | `FILETIME`: network time now |
| 0x1C | 0x28 | Copy of the first 0x28 bytes of the NITZ data (time zone at +0x28, DST at +0x2C) |
| 0x44 | 4 | CAN id |

1. Loads the settings (`sub_10006510`). `NetworkTime Enabled` = 0 → S_FALSE; `NetworkTime Sync` = 0 → "disabled.", S_OK.
2. Slot check, if a preferred slot is set (≠ 0xFF): reads `WNF_CELL_…` 0x0D8A0B2EA3BDF475 (CAN 0) or 0x0D8A0B2EA3BDFC75 (CAN 1), 0x74 bytes. If its first DWORD isn't the preferred slot and the NITZ state of the *other* CAN holds a valid time (year ≥ 2010), the update is ignored ("Not Preferred Slot.").
3. `LoadTimeValue` (`sub_1000682C`): `NtQueryWnfStateData` of `WNF_CELL_NETWORK_TIME_CAN<id>` (0x30 bytes, see [NITZ data](#nitz-data)). A year < 2010 → `E_UNEXPECTED`. The network time now = `SystemTimeToFileTime(NITZ time)` + (`GetTickCount64` − tick count of the data) × 10 000.
4. If `NetworkTime TimeZone Sync`: `UpdateTimeZone` (`sub_100069A4`):
   - bias = −(time zone offset), and the DST offset is added back unless `DSTOverride` (`HKLM\System\State\DateTime`) is non-zero;
   - `GetTimeZoneIdFromOffset` (`sub_10006D10`): `GetTimeZoneList` (entries of 0x1BC bytes: DWORD id, then the `TIME_ZONE_INFORMATION` at +4). It first tries the ids listed in `HKLM\System\State\DateTime\NetworkTimePriorities` (DWORD values named `1`, `2`, `3`… read until one is missing), then the whole list in order. `DoesTZMatch` (`sub_10006B3C`) compares the bias and computes whether DST is in effect at the network time from the zone's `StandardDate` / `DaylightDate` (`CalcIfDST`, `sub_1000710C`);
   - found → `SeTimeZonePrivilege` (`sub_10007260`), `SetTimeZoneInformationByID(id)`;
   - not found → if `GetTimeZoneInformation` already has this bias, S_FALSE; else `SetTimeZoneInformation` with only `Bias` set (no names, no DST rule).
5. `UpdateTime` (`sub_10006F4C`): if |network time − `GetSystemTime`| < threshold, nothing; else `SetSystemTime` and `WNF_SHL_SYSTEM_CLOCK_CHANGED` (DWORD 0).
6. Writes `NetworkTime Set` = 1 (REG_DWORD).

#### NITZ data

`WNF_CELL_NETWORK_TIME_CAN0/1`, 0x30 bytes (only the fields used here):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 0x0C | ? |
| 0x0C | 4 | Time zone offset from UTC, in minutes (the bias is its opposite) |
| 0x10 | 4 | DST adjustment, in minutes ? |
| 0x14 | 16 | `SYSTEMTIME`: network time (UTC); a year < 2010 means "no time" |
| 0x24 | 4 | ? |
| 0x28 | 8 | `GetTickCount64` when the time was received |

### NTP (NTPSync)

`NTPSync::Run(lastSync)` (`sub_10005564`) builds an `NTPSync` object on the stack:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | NTP sync enabled: `NTP Enabled` and `NetworkTime Sync` |
| 0x04 | 4 | `NTP Service Logging Enabled` |
| 0x08 | 4 | `NTP Force Large Delta Sync Disabled` |
| 0x0C | 4 | `NTP Last Sync Check Disabled` |
| 0x10 | 4 | `NTP Retry Interval` (default 24) |
| 0x14 | 4 | `NTP Regular Sync Interval` (default 24) |
| 0x18 | 4 | `NetworkTime UpdateThreshold` in seconds (default 60) |
| 0x1C | 0x10 | `std::wstring`: W32Time server list |
| 0x2C | 4 | Unit of the intervals in minutes: 60 (hours), or 1 if `NTP Interval In Minutes` is set |
| 0x30 | 4 | Timeout of the resync: 120 seconds |

With `lastSync` it only replays the last sync ([LastSyncInfo](#lastsyncinfo)). Without, `NTPSync::SyncTime` (`sub_10005600`, disassembly only):
1. `InitializeSettings` (`sub_10004FF4`): the registry values of the table and `InitializeTimeServers` (`sub_100052D4`): the REG_MULTI_SZ `NTP Servers` (default `time.windows.com`) is turned into the W32Time syntax, one `<server>,0x1` per entry separated by spaces.
2. NTP not enabled → S_FALSE (the next sync is still scheduled).
3. `IsTimeSyncRequired`: required if there is no [LastSyncInfo](#lastsyncinfo), or if (now − last sync + 5 min) ≥ regular interval, or if `NTP Last Sync Check Disabled`; otherwise S_FALSE.
4. `SyncTimeOverNetwork` (`sub_10005AA4`): runs `SyncTimeOverNetworkAsync` on the thread pool (`AsyncAction<NTPSync>`) and waits 120 s. On timeout (0x800705B4) it stops W32Time.
5. Success: traces the new time, publishes `WNF_SHL_SYSTEM_CLOCK_CHANGED` (DWORD 0).
6. `ScheduleNextTimeSync` (`sub_10005F44`) after the retry interval if the sync failed, after the regular interval otherwise.

**SyncTimeOverNetworkAsync** (`sub_10005C8C`):
1. Logging enabled → `EnableW32TimeLogging` (`sub_100078A0`): `FileLogName` = `<known folder {8C19F0BC-…}>\NonEtwLogs\w32time.log`, `FileLogSize` = 1 048 576, `FileLogEntries` = `0-300` in `W32Time\Config`, then the file is created and given the DACL `D:(A;;GRGW;;;LS)` (read/write for LocalService, `sub_100073B4`). Disabled → the three values are deleted.
2. `NTPServer` (REG_SZ) of `W32Time\Parameters` = the server list.
3. `StartW32Time` (`sub_10007690`): `OpenServiceW("W32Time", SERVICE_QUERY_STATUS | SERVICE_START)`, `StartServiceW` (`ERROR_SERVICE_ALREADY_RUNNING` accepted), then `QueryServiceStatus` every 500 ms, at most 7 times, until `SERVICE_RUNNING` (else 0x800705B4). The object's destructor stops the service again (`StopW32Time`: `SERVICE_CONTROL_STOP`, same polling).
4. Up to 5 attempts: `Sleep(1000…5000 ms, rand)`, then `WpW32TimeSyncNow(force)` ([W32Time RPC](#w32time-rpc)). Results 0x83130001 / 0x83130002 (no data / stale data) → retry; 0x83130004 (change too big) → retry with force, unless `NTP Force Large Delta Sync Disabled`; anything else ends the loop.

**ScheduleNextTimeSync(minutes)** (`sub_10005F44`, disassembly only), through the [Task Scheduler RPC](#task-scheduler-rpc):
1. Opnum 5 with the fixed task GUID `{A92AC509-6753-47B3-9C05-CE0B08894392}`; if the task exists, opnum 1 deletes it ("Deleting existing schedule ['NTP Time Sync Schedule']").
2. Opnum 0 creates it again with the task item below (same layout as the reminder tasks of [ShellChromeAPI.dll](./shellchromeapi.md#reminders)).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Pointer to the task GUID `{A92AC509-…}` |
| 0x04 | 4 | Flags 0xC |
| 0x08 | 4 | `L"NTP Time Sync Schedule"` |
| 0x0C, 0x1C | 16 each | Two `SYSTEMTIME`, zero |
| 0x2C | 4 | 1 |
| 0x30 | 4 | Pointer to the trigger `{ 0, → { 0, interval × unit (minutes), 0, 0 } }`: relative delay ? |
| 0x34 | 4 | Pointer to the action `{ 3, → { WNF state name 0x418A063EA3BD6075, 4, → DWORD 0 } }`: publish 4 bytes in `WNF_SHL_NETWORK_TIME_SYNC_TRIGGER` |

When the task fires, the Task Scheduler service publishes `WNF_SHL_NETWORK_TIME_SYNC_TRIGGER`, which comes back to `DoMultivariant`. Action type 4 is the reminder data of [ShellChromeAPI.dll](./shellchromeapi.md#reminders); type 3 = WNF publication is inferred from this task.

### W32Time RPC

`WpW32TimeSyncNow(force)` (`sub_100074D4`):
1. `RpcStringBindingComposeW(NULL, "ncalrpc", NULL, "W32TIME_ALT")`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW(h, NULL, 6 = RPC_C_AUTHN_LEVEL_PKT_PRIVACY, 10 = RPC_C_AUTHN_WINNT, …, QoS { version 5, capabilities 0, identity tracking static, impersonation 2 = identify })`. RPC errors are returned as 0x8001xxxx.
2. Takes a [PDC activation](#pdc-activation) (create + activate), the error with bit 28 set if it fails.
3. Opnum 0 (`W32TimeSync`) with `wait = 1` and `flags = 0x12` if forced, else 3 (`TimeSyncFlag_HardResync | TimeSyncFlag_ReturnResult`; 0x10 is `ForceResync` in [w32time.dll](./w32time.md#w32timesync-opnum-0): the correction is applied even beyond the max phase correction).
4. Result: 0 → S_OK; 1…4 → 0x83130001…0x83130004 (`ResyncResult_NoData`, `StaleData`, `Shutdown`, `ChangeTooBig`, see [w32time.dll](./w32time.md#w32timesync-opnum-0)); other Win32 errors → `HRESULT_FROM_WIN32`.
5. Releases the activation and the binding.

Interface `{8FB6D884-2388-11D0-8C35-00C04FDA2795}` version 4.1 (W32Time, stub descriptor at 0x10002AE0; server side in [w32time.dll](./w32time.md#rpc-server)).

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `sub_100079FC` | `WpW32TimeSyncNow` | `[in] long wait`, `[in] long flags`, returns `long` | Resync now and return the result |

### Task Scheduler RPC

`TaskScheduler::CreateInstance` (`sub_10007A40`) is the same connection code as [ReminderEvents.dll](./reminderevents.md#rpc) and [ShellChromeAPI.dll](./shellchromeapi.md#task-scheduler-rpc-reminders): `QueryTransientObjectSecurityDescriptor(9, L"ITaskSchedulerSvcRpc\\Server")`, `RpcBindingCreateW` (LRPC, no endpoint, `RPC_C_AUTHN_LEVEL_PKT_PRIVACY`, `RPC_C_AUTHN_WINNT`, QoS version 5, `ServerSecurityDescriptor`), `RpcBindingBind` up to 3 times 500 ms apart while it fails with 1722, 1708, 1717 or 1753. The binding is freed after each schedule (`sub_1000645C`).

Interface `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` version 2.0 (stub descriptor at 0x100032C0).

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `sub_10007B64` | `ScheduleNextTimeSync` | `[in]` task item, `[in] long` (0) | Create the task |
| 1 | `sub_10007BC8` | `ScheduleNextTimeSync` | `[in] GUID *` | Delete the task |
| 5 | `sub_10007C28` | `ScheduleNextTimeSync` | `[in] GUID *`, `[in,out]`, `[in,out]` item | Get the task (does it exist ?) |

### PDC activation

A user-mode client of the power dependency coordinator, used only around the `W32TimeSync` call:
- `sub_1000A000` allocates the client object (signature 0x41634450 `PDcA`, component id 0x44 at +0x0C) and connects (`sub_10007EC8`): `ZwAlpcConnectPort("\PdcPort")`, connection data `{ 0, 0x44, 2, … }` (component 0x44, client type 2 ?), then an ALPC completion on the thread pool (`TpAllocAlpcCompletion`, `sub_10008164` → `sub_100081E0` / `sub_10008350`: handles the messages sent by the PDC, disconnection on type 5).
- `sub_1000A064(client, activate)` keeps a reference count; on the first activation / last release it sends a 0x30-byte ALPC request (`sub_100082DC`): message type 4, byte at +0x20 = 1 (activate) or 0 (release); the status comes back at +0x20.
- `sub_1000A0F8` disconnects (`ZwAlpcDisconnectPort`, waits for the pending completions) and frees the object.

Errors of this code are printed with `vDbgPrintEx(146, …)` (`PdcpAlpcProcessMessage`, `PdcpProcessMessageInternal`). The kernel side of the PDC clients is described in [wppower.sys](../drivers/wppower.md#pdc-clients); the meaning of component 0x44 isn't known.

### WNF states

Decoded with `wnf.py`: version 1, well-known, system scope. The symbolic names come from the trace strings of the DLL.

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x0D8A0B2EA3BC4875 (`.text:0x100016A0`) | `CELL`, 9 (`WNF_CELL_NETWORK_TIME_CAN0`) | 0x30 bytes, [NITZ data](#nitz-data) | Subscribed → `DoNITZ(0)`; read by `LoadTimeValue` and by the slot check of CAN 1 |
| 0x0D8A0B2EA3BD5075 (`.text:0x10001650`) | `CELL`, 42 (`WNF_CELL_NETWORK_TIME_CAN1`) | 0x30 bytes, [NITZ data](#nitz-data) | Subscribed → `DoNITZ(1)`; read by `LoadTimeValue` and by the slot check of CAN 0 |
| 0x0D8A0B2EA3BDF475 (`.text:0x100016E8`) | `CELL`, 62 (permanent) | 0x74 bytes, DWORD +0: slot number ? | Read by `AutoTimeUpdate::Run` for CAN 0 |
| 0x0D8A0B2EA3BDFC75 (`.text:0x10001660`) | `CELL`, 63 (permanent) | 0x74 bytes, DWORD +0: slot number ? | Read by `AutoTimeUpdate::Run` for CAN 1 |
| 0x0C900B29A3BC3875 (`.text:0x10001668`) | `DEVM`, 7 (`WNF_DEVM_MULTIVARIANT_UI_STATUS`) | 4 bytes (not read) | Subscribed → `DoMultivariant` |
| 0x418A063EA3BD6075 (`.text:0x10001658`) | `SHL`, 44 (`WNF_SHL_NETWORK_TIME_SYNC_TRIGGER`) | 4 bytes (not read) | Subscribed → `DoMultivariant`; published by the Task Scheduler service when the `NTP Time Sync Schedule` task fires |
| 0x418A063EA3BDA875 (`.text:0x10001698`) | `SHL`, 53 (`WNF_SHL_AUTOTIMEUPDATE_STATE_CHANGED`) | 4 bytes: automatic time on | Subscribed → `DoCPLStateChanged`; published by [DateTimeCPLdll.dll](./datetimecpldll.md#wnf-states) |
| 0x1583002EA3BC1075 (`.text:0x10001680`) | `CNET`, 2 (`WNF_CNET_DPU_GLOBAL_STATE_OVER_LIMIT`) | 4 bytes; 1 = NTP allowed ? | Read by `DoNTP`, subscribed (`s_DPUCallback`) while it isn't 1 |
| 0x418A063EA3BD5875 (`.text:0x100016D8`) | `SHL`, 43 (`LastSyncInfo`) | 0x20 bytes, [LastSyncInfo](#lastsyncinfo) | Published after each NITZ / NTP sync, read by `LastSyncInfo::Run` and `IsTimeSyncRequired` |
| 0x418A063EA3BC5875 (`.text:0x100016E0`) | `SHL`, 11 (`WNF_SHL_SYSTEM_CLOCK_CHANGED`) | 4 bytes: 0 | Published after every `SetSystemTime`; also published by [DateTimeCPLdll.dll](./datetimecpldll.md#wnf-states) |

### Registry

All under `HKLM`, read with `RegGetValueW` (REG_DWORD unless stated otherwise).

| Key | Value | Access | Use |
|-----|-------|--------|-----|
| `System\State\DateTime` | `NetworkTime Enabled` | Read | NITZ supported; 0 → NITZ ignored |
| `System\State\DateTime` | `NTP Enabled` | Read | NTP supported |
| `System\State\DateTime` | `NetworkTime Sync` | Read | Automatic time on (switch of the settings page) |
| `System\State\DateTime` | `NetworkTime TimeZone Sync` | Read | Automatic time zone on (default 1) |
| `System\State\DateTime` | `NetworkTime Preferred Slot Number` | Read | SIM slot whose NITZ is preferred (default 0xFF = none) |
| `System\State\DateTime` | `NetworkTime UpdateThreshold` | Read | Minimum difference in seconds to change the clock (default 60, 1…59 accepted) |
| `System\State\DateTime` | `NetworkTime Set` | Write (1) | The clock / time zone has been set from NITZ |
| `System\State\DateTime` | `DSTOverride` | Read | Non-zero: the NITZ DST offset isn't removed from the bias |
| `System\State\DateTime\NetworkTimePriorities` | `1`, `2`, … | Read | Time zone ids tried first when looking for a zone matching the NITZ offset |
| `System\State\DateTime` | `NTP Servers` | Read (REG_MULTI_SZ) | NTP servers (default `time.windows.com`) |
| `System\State\DateTime` | `NTP Interval In Minutes` | Read | Intervals in minutes instead of hours |
| `System\State\DateTime` | `NTP Regular Sync Interval` | Read | Interval after a successful sync (default 24) |
| `System\State\DateTime` | `NTP Retry Interval` | Read | Interval after a failed sync (default 24) |
| `System\State\DateTime` | `NTP Service Logging Enabled` | Read | Enables the W32Time file log |
| `System\State\DateTime` | `NTP Force Large Delta Sync Disabled` | Read | Don't force the resync when W32Time reports a change too big |
| `System\State\DateTime` | `NTP Last Sync Check Disabled` | Read | Sync even if the last sync is recent |
| `System\ControlSet001\Services\W32Time\Parameters` | `NTPServer` (REG_SZ) | Write | Server list `<server>,0x1 …` |
| `System\ControlSet001\Services\W32Time\Config` | `FileLogName` (REG_SZ), `FileLogSize` (1 048 576), `FileLogEntries` (REG_SZ `0-300`) | Write / delete | W32Time log file |

### Named objects

| Name | Type | Use |
|------|------|-----|
| `W32TIME_ALT` | LRPC endpoint | W32Time RPC server ([w32time.dll](./w32time.md#rpc-server)) |
| `ITaskSchedulerSvcRpc\Server` | Transient object security descriptor | Expected security of the Task Scheduler RPC server |
| `\PdcPort` | ALPC port | Power dependency coordinator |
| `NTP Time Sync Schedule`, `{A92AC509-6753-47B3-9C05-CE0B08894392}` | Task (Task Scheduler service) | Next NTP sync |
