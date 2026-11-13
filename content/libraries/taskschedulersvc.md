## TaskSchedulerSvc.dll

The Task Scheduler service of Windows Phone 8.1 (`TaskSchedulerSvc`): it keeps the system's scheduled tasks and runs their action when their trigger fires (a time, a WNF state, a system event…).  
`TaskSchedulerSvc.dll` is a C++ svchost service DLL (106 496 bytes, 432 functions, no symbols). It is the RPC server of the interface `ITaskSchedulerSvcRpc` `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` v2.0 (13 opnums). Each task has one trigger and one action. Triggers are built on the time broker (`TimeBrokerClient`), the system events broker (`CSystemEventsBrokerClient`), event aggregation (`EventAggregation`) and WNF subscriptions. Actions start a process in the creator's chamber (`SecRuntime!CreateProcessInChamber`), start a background worker (`EMSVCS`), set a named event or publish a WNF state. The tasks are stored in the registry under `HKLM\SOFTWARE\Microsoft\WPTaskScheduler`, serialised with RPC pickling (`NdrMesTypeEncode2`).  
The clients documented here are [ShellChromeAPI.dll](./shellchromeapi.md#task-scheduler-rpc-reminders) and [ReminderEvents.dll](./reminderevents.md#rpc) (reminders), [ShellChrome.dll](./shellchrome.md#alarmlockicontask) (`AlarmLockIconTask`), [WPTimeSvc.dll](./wptimesvc.md#task-scheduler-rpc) (time synchronisation), [pacmanserver.dll](./pacmanserver.md#rpc) (live tile tasks), [BtServ.dll](./btserv.md) (retry timers) and [UpdateUEFIDb.exe](../applications/updateuefidb.md#task-scheduler-rpc).

Location on the phone: `C:\Windows\System32\taskschedulersvc.dll`, loaded by `svchost.exe -k WPTCBCritical` (observed with `tlist`). That host also runs `EMSVCS.dll`, `execmanserver.dll`, `pacmanserver.dll` and others; the processes started by the tasks appear as its children (for example [WpPerfMonServer.exe](../applications/wpperfmonserver.md), `MobileUI.exe`, `HeadlessHost.exe`).  
Service name: `TaskSchedulerSvc` (parameters under `HKLM\SYSTEM\ControlSet001\Services\TaskSchedulerSvc\Parameters`).

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4.dll | `RpcServerUseProtseqW`, `RpcServerInqBindings`, `RpcServerRegisterIf3`, `RpcServerUnregisterIfEx`, `RpcEpRegisterW`, `RpcEpUnregister`, `RpcBindingVectorFree`, `RpcImpersonateClient`, `RpcRevertToSelfEx`, `NdrServerCall2`, `MesEncodeDynBufferHandleCreate`, `MesDecodeBufferHandleCreate`, `MesBufferHandleReset`, `MesHandleFree`, `NdrMesTypeEncode2`, `NdrMesTypeDecode2` |
| [SecRuntime.dll](./secruntime.md) | `GetRpcClientSid`, `CapabilityCheck`, `CreateTokenFromChamberSidEx`, `CreateProcessInChamber`, `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor` |
| TimeBrokerClient.dll | `TbCreateCEvent`, `TbUpdateCEvent`, `TbDeleteCEvent`, `TbQueryCEventTriggerTime` |
| CSystemEventsBrokerClient.dll | `CSebCreateWellKnownEvent`, `CSebCreatePrivateEvent`, `CSebDeleteEvent` |
| EventAggregation.dll | `EACreateAggregateEvent`, `EADeleteAggregateEvent` |
| EMSVCS.dll | `CreateBackgroundWorkerManager` |
| ntdll.dll | `NtCreateWnfStateName`, `NtDeleteWnfStateName`, `NtQueryWnfStateData`, `RtlQueryWnfStateData`, `RtlPublishWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `ZwAlpcConnectPort`, `ZwAlpcSendWaitReceivePort`, `ZwAlpcCancelMessage`, `ZwAlpcDisconnectPort`, `ZwAlpcQueryInformation`, `AlpcInitializeMessageAttribute`, `AlpcGetMessageAttribute`, `TpAllocAlpcCompletion`, `TpWaitForAlpcCompletion`, `TpReleaseAlpcCompletion`, `ZwClose`, `RtlInitUnicodeString`, `RtlWaitOnAddress`, `RtlWakeAddressAll`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlNtStatusToDosError`, `vDbgPrintEx` |
| api-ms-win-core-registry-l1-1-0 / l2-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegEnumKeyExW`, `RegQueryInfoKeyW`, `RegQueryValueExW`, `RegSetValueExW`, `RegCloseKey`, `RegDeleteKeyW`, `RegSetKeyValueW` |
| api-ms-win-core-threadpool-l1-2-0 / legacy | `CreateThreadpool`, `SetThreadpoolThreadMinimum` / `Maximum`, `CreateThreadpoolCleanupGroup`, `CloseThreadpoolCleanupGroup(Members)`, `CloseThreadpool`, `CreateThreadpoolWork`, `SubmitThreadpoolWork`, `CloseThreadpoolWork`, `CreateThreadpoolTimer`, `SetThreadpoolTimer`, `IsThreadpoolTimerSet`, `WaitForThreadpoolTimerCallbacks`, `CloseThreadpoolTimer`, `CreateThreadpoolWait`, `SetThreadpoolWait`, `UnregisterWaitEx` |
| api-ms-win-core-timezone-l1-1-0, sysinfo, file | `GetTimeZoneInformation`, `SystemTimeToFileTime`, `FileTimeToSystemTime`, `SystemTimeToTzSpecificLocalTime(Ex)`, `TzSpecificLocalTimeToSystemTime(Ex)`, `GetSystemTime`, `GetLocalTime`, `CompareFileTime` |
| api-ms-win-service-core-l1-1-1 | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `OpenEventW`, `SetEvent`, critical sections, SRW locks, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2, security-base | `OpenThreadToken`, `SetThreadToken`, `GetCurrentThread`, `GetCurrentThreadId`, `RevertToSelf`, `InitializeSecurityDescriptor` |
| api-ms-win-core-processenvironment-l1-2-0 | `ExpandEnvironmentStringsW` |
| api-ms-win-core-libraryloader-l1-2-0 | `GetProcAddress`, `FreeLibrary` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| msvcrt.dll | `malloc`, `free`, `_wcsdup`, `wcslen`, `memcpy`, `memset`, `memcmp`, `operator new` / `delete`, C++ exceptions, CRT DLL startup (`_initterm`, `__dllonexit`, …) |

`GetCurrentProcess`, `TerminateProcess`, the exception filter functions, `rtlsupport` and the msvcrt startup functions are the Visual C++ DLL CRT and `/GS` cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| Programs named by the tasks, e.g. `c:\Programs\Alarms\Alarms_NoUI.exe` ([ShellChrome.dll](./shellchrome.md#alarmlockicontask)), `%systemdrive%\windows\system32\WpPerfMonServer.exe` and `WpToolsWrapper.exe` ([tasks of a phone](#tasks-of-a-phone)) | `CreateProcessInChamber` ([action 0](#actions)) | The process actions; path expanded with `ExpandEnvironmentStringsW` |
| Background workers (host `HeadlessHost.exe` ?) | `EMSVCS!CreateBackgroundWorkerManager` ([action 1](#actions)) | Background tasks of the applications |
| `\PdcPort` | `ZwAlpcConnectPort` (`sub_10013B58`) | Power dependency coordinator client, the same code as in [WPTimeSvc.dll](./wptimesvc.md#pdc-activation) |
| Library with `PowerSettingUnregisterNotification` (handle in `dword_100174C0`) | `GetProcAddress` / `FreeLibrary` (`sub_10013608`, service stop) | Unregisters 7 power setting notifications; the library and the registration aren't in this binary's imports (loaded by code not analysed ?) |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `ServiceMain` | 0x10013774 | `DWORD argc, LPWSTR *argv` |
| 2 | `SvchostPushServiceGlobals` | 0x100135F4 | `SVCHOST_GLOBAL_DATA *` (saved in `dword_100174F0`) |

### Startup

`DllEntryPoint` (0x1001487C) is the CRT DLL startup; `DllMain` does nothing specific.

**ServiceMain** (0x10013774):
1. Saves the service name, `RegisterServiceCtrlHandlerExW(name, sub_100136D8)`, reports `SERVICE_START_PENDING` (wait hint 50), creates the stop event.
2. `InitializeScheduler` (`sub_10005038`), see below; on failure, `ShutdownScheduler` (`sub_10005350`).
3. `RegisterRpcServer` (`sub_10004F28`), see [RPC](#rpc).
4. Reports `SERVICE_RUNNING` (controls accepted 0x401 = stop + time change ?), then asks svchost (method at +0x60 of the global data) to wait on the stop event with `sub_10013608` as callback: it unregisters the power setting notifications, shuts the scheduler down and reports `SERVICE_STOPPED`.

**InitializeScheduler** (`sub_10005038`):
1. Registers the [ETW provider](#etw), creates the global critical sections and the thread pool (`sub_10012A18`, `sub_10012B0C`).
2. Reads `TimeScale` (REG_DWORD, default 1) in `HKLM\SYSTEM\ControlSet001\Services\TaskSchedulerSvc\Parameters`: 1 → normal clock object (`off_10002418`), another value → a clock that runs `TimeScale` times faster (test hook ?). Reads and updates `TimeZoneInfo` in the same key (`RegSetKeyValueW`), to detect time zone changes while the service was stopped.
3. `sub_10007884`: empties the task list and subscribes to the WNF state 0x41C60C39A3BC0875 (`TB`, 1: time broker ready ?) with `sub_10009B20`, then queues `sub_1000786C`. Both end in `LoadTasks` (`sub_100079E4`).

**LoadTasks** (`sub_100079E4`):
1. Increments the counter kept in the WNF state 0x41C61D22A3BC9075 (`OS`, 18; read with `RtlQueryWnfStateData`, published back with `RtlPublishWnfStateData`): number of (re)loads of the task store ?
2. If scheduling is enabled (`dword_10017010`, see opnum 12): deletes the task keys that have no `Schedule` value (`sub_10011228`), then reads every task key (`sub_100110B4` → `sub_10010E18`): `Schedule`, `RuntimeData`, `Statistics`, `Enabled`, `AdhocState` ([Registry](#registry)), and rebuilds each task with `CreateTask` (`sub_10005A5C`).
3. Arms every task (`sub_100061A8`).

### Tasks

`CreateTask` (`sub_10005A5C`, used by opnum 0 and by the loader) checks and converts the task item sent by the clients (0x3C bytes, the layout seen from the client side in [ShellChromeAPI.dll](./shellchromeapi.md#reminders)):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `GUID *`: task id (required) |
| 0x04 | 4 | Flags: only bits 0x2F are accepted from a client (0x3F when the task is loaded from the registry); bit 0x01 = stored in the registry (persistent); bit 0x02 = disabled ? (set by [ShellChromeAPI.dll](./shellchromeapi.md#reminders) for a disabled reminder, and by the service when it reloads a stored task whose action is a named event); bit 0x20 = process action variant ([action 0](#actions)) |
| 0x08 | 4 | `WCHAR *` name, at most 256 characters (`_Reminder_`, `AlarmLockIconTask`, `NTP Time Sync Schedule`…) |
| 0x0C | 16 | `SYSTEMTIME` start; used only if `wYear` ≥ 1601 |
| 0x1C | 16 | `SYSTEMTIME` end; used only if `wYear` ≥ 1601. Start later than end → 0x82CF0115 |
| 0x2C | 4 | Must not be 0 (saved at task +0x8C). 0xFFFFFFFF in 169 of the 177 tasks of a phone, 1 in the reminders and 7 other tasks: maximum number of runs, −1 = unlimited ? |
| 0x30 | 4 | `{ DWORD type; void *data }` *: the [trigger](#triggers). NULL → a one-shot time trigger (type 5) built from the start time (the reminders). Type 5 from a client is refused (0x82CF0107) |
| 0x34 | 4 | `{ DWORD type; void *data }` *: the [action](#actions) (required) |

When the task is created through RPC, the SID of the caller (`GetRpcClientSid`, `sub_1001286C`) is saved as a string at task +0xE8: the actions are run with a token of that chamber (`CreateTokenFromChamberSidEx(sid, 2, 1, &token)`). When the task is loaded, the SID comes from the stored data.

States of a task (`sub_10006D8C`): 1 created, 2 armed, 3 waiting for its start time, 5 expired, 7 failed (values from the code paths of `CreateTask`; the other values aren't decoded).

#### Triggers

Built by `CreateTrigger` (`sub_1000C75C`) from the `type`; method 2 of each class (vtable +8) initialises it with the `data`.

| Type | Class (vtable) | Object size | Implementation |
|------|----------------|-------------|----------------|
| 0 | `off_10003230` | 0x200 | Time trigger: time broker event (`TbCreateCEvent` / `TbUpdateCEvent`, `sub_1000D284`, `sub_1000DA08`, `sub_1000DD2C`), event aggregation (`sub_1000E2C0`) |
| 1 | `off_10003418` | 0xE8 | [WNF state trigger](#wnf-trigger) (`sub_1000E988`) |
| 2 | `off_100032BC` | 0xB0 | List of sub-triggers (its init `sub_1000F500` calls `CreateTrigger` again). In the stored tasks: `{ DWORD mode (0); DWORD count; { type, data } *triggers }` with WNF sub-triggers, e.g. `_Groveler_SdCardMounted_` = state `OS` 1 ≠ 0 and state `OS` 12 ≠ 0 (any of them or all of them ?) |
| 3 | `off_10003278` | 0xD8 | System event trigger: `CSebCreateWellKnownEvent` / `CSebCreatePrivateEvent` and `EACreateAggregateEvent` (`sub_1000FBE0`) |
| 4 | `off_1000345C` | 0xB8 | Two sub-triggers (`sub_1000FF40` calls `CreateTrigger` twice) and `EACreateAggregateEvent`: aggregate ? |
| 5 | `off_10003300` (`sub_100103CC`) | 0x118 | One-shot time trigger, internal only: `TbCreateCEvent` and a WNF subscription (`sub_10010724`) |
| 6 | `off_1000338C` | 0x200 | Time trigger, same base as type 0 (variant ?) |

##### WNF trigger

The data of a type 1 trigger is 0x1C bytes (copied to the trigger object +0xA0):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | WNF state name |
| 0x08 | 4 | Condition (0…6, see below; ≥ 7 → 0x82CF0116) |
| 0x0C | 4 | Size of the comparison value: must be 1, 2 or 4 for conditions 3…6 |
| 0x10 | 4 | `BYTE *` comparison value |
| 0x14 | 4 | ? (non-zero: a thread-pool timer `sub_1000EE14` re-reads the state, `sub_1000EE50`) |
| 0x18 | 4 | Flags, only bits 0x3 allowed (else 0x82CF0116) |

The state is subscribed through a shared subscription table (`sub_10008B7C`, `RtlSubscribeWnfStateChangeNotification`); the change callback (`sub_10009C64` → work item `sub_10009B84` → `sub_10009700`) finds the tasks that watch the state and evaluates their condition (`sub_1000EF18`) on the published data (`published` below, unsigned, read as 1, 2 or 4 bytes):

| Condition | Fires when |
|-----------|------------|
| 0 | Any publication |
| 1 | The data has the same size and bytes as the value |
| 2 | The data differs from the value |
| 3 | `published` > value |
| 4 | `published` ≥ value |
| 5 | `published` < value |
| 6 | `published` ≤ value |

For each WNF trigger the service also creates a private system event (`CSebCreatePrivateEvent`) and its own WNF state name (`NtCreateWnfStateName`, security `TaskSchedulerWNFEventAccess`), deleted when the trigger is rebuilt.

#### Actions

Built by `CreateAction` (`sub_1000AF18`); method 0 of each class runs it.

| Type | Class (vtable) | Data | Run (method 0) |
|------|----------------|------|----------------|
| 0 | `off_10003158`, or `off_1000320C` when task flag 0x20 is set | `{ WCHAR *application; WCHAR *commandLine }` (application required) | `sub_1000B664` / `sub_1000B848`: `ExpandEnvironmentStringsW(application)` (≤ 260 characters); `CreateTokenFromChamberSidEx(creatorSid, 2, 1, &token)`; if that token has `ID_CAP_CREATE_PROCESS_IN_CHAMBER` (`CapabilityCheck`) the chamber SID is dropped (NULL); then `CreateProcessInChamber(sid, NULL, application, commandLine, …)`. The process isn't waited for: its handles are closed at once. The `off_1000320C` variant first checks a list kept by the service (`sub_10012FB8`) and returns `E_ABORT` if the task is in it (blocked ?) |
| 1 | `off_100031E8` | `{ WCHAR *, DWORD size, BYTE *data }` | `sub_1000BB5C`: impersonates the creator's chamber token (`SetThreadToken`) and starts a background worker with `EMSVCS!CreateBackgroundWorkerManager` |
| 2 | `off_100031C4` | `{ ?, WCHAR *eventName }` | `sub_1000BD98`: with the creator's token, `OpenEventW(name)` and `SetEvent` |
| 3 | `off_100031A0` | `{ WNF state name (8), DWORD size, BYTE *data }` | `sub_1000BFB0`: `RtlPublishWnfStateData(state, data)` with the creator's token ([WPTimeSvc.dll](./wptimesvc.md#task-scheduler-rpc)) |
| 4 | `off_10003134` | `{ DWORD size, BYTE *data }` | The service creates a WNF state for the task (`sub_1000C170`: `NtCreateWnfStateName`, security `TaskSchedulerWNFEventAccess`) and publishes the data in it when the task fires (`sub_1000BFB0`); deleted with the task (`sub_1000C35C`). Used by the reminders: the clients get the state name with opnum 11 and watch it ([ReminderEvents.dll](./reminderevents.md#addreminderpublishstatename--removereminderpublishstatename)) |

### RPC

`RegisterRpcServer` (`sub_10004F28`):
1. `RpcServerUseProtseqW(L"ncalrpc", RPC_C_PROTSEQ_MAX_REQS_DEFAULT, sd)`, `sd` = `QueryTransientObjectSecurityDescriptor(8, L"DefaultRpcAccess")`.
2. `RpcServerInqBindings`.
3. `RpcServerRegisterIf3(interface, NULL, NULL, 0x29, 1234, 0, NULL, sd)`: flags `RPC_IF_AUTOLISTEN | RPC_IF_ALLOW_SECURE_ONLY | RPC_IF_ALLOW_LOCAL_ONLY`, at most 1234 concurrent calls, `sd` = `QueryTransientObjectSecurityDescriptor(9, L"ITaskSchedulerSvcRpc\\Interface")`.
4. `RpcEpRegisterW`: dynamic endpoint, found by the clients through the endpoint mapper (they check the server's security descriptor `ITaskSchedulerSvcRpc\Server`, see [ReminderEvents.dll](./reminderevents.md#rpc)).

Interface `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` version 2.0 (server interface at 0x100017B8, dispatch table 0x10001418, MIDL server info 0x10001798). Every routine first checks that the scheduler is running (`sub_10004A04`, else `E_ABORT`). "Owner check" (`sub_1000496C`) = the task must exist (else 0x82CF010E) and belong to the caller's SID (`sub_100089E0`); otherwise the caller needs `ID_CAP_BUILTIN_TCB` or `ID_CAP_TS_SCHEDULES_ALL` (not accepted for opnum 7).

| Opnum | Routine | Check | Implementation | Use |
|-------|---------|-------|----------------|-----|
| 0 | `sub_10004A58` | flags ≥ 0 | `sub_10007BE8` → [CreateTask](#tasks); writes the task to the registry when it's persistent | Create a task (the `[in] long` is the creation flags) |
| 1 | `sub_10004AB0` | owner | `sub_1000827C`: removes the task, deletes its registry key if persistent (`sub_1001175C`) | Delete a task |
| 2 | `sub_10004AFC` | — | `sub_10007DF4`: snapshot of the task ids visible to the caller (all with `ID_CAP_BUILTIN_TCB` / `ID_CAP_TS_SCHEDULES_ALL`, else only its own), context handle | Start an enumeration, first task |
| 3 | `sub_10004B48` | — | `sub_100080B8`: next visible task (0x82CF010E at the end) | Next task |
| 4 | `sub_10004B94` | — | Frees the context (`E_HANDLE` 0x80070006 if NULL) | End of the enumeration |
| 5 | `sub_10004BF4` | owner | `sub_10008214`: copy of the task item and runtime data | Get one task |
| 6 | `sub_10004C54` | owner | `sub_10008368`: enables or disables the task and writes `Enabled` | Enable / disable |
| 7 | `sub_10004CA4` | owner, no capability bypass | `sub_10008474`: recomputes the schedule (`sub_10005754`), resets the action and writes the task back (`sub_10011504`, `sub_1001157C`) | ? (re-arm) |
| 8 | `sub_10004CF4` | owner | `sub_10008584`: task state change (`sub_1000680C`), writes `AdhocState` / `RuntimeData` ? | ? |
| 9 | `sub_10004D44` | owner | `sub_10008584` (same routine as 8, other ETW event) | ? |
| 10 | `sub_10004D98` | owner | `sub_10008630`: new next time (`sub_100068E8`), rewrites `Schedule` | Snooze |
| 11 | `sub_10004DE8` | owner | `sub_10008768`: the WNF state name of an action of type 3 or 4 (0x82CF0108 no action, 0x82CF0113 other action type, 0x82CF0112 no state) | WNF state name of the task |
| 12 | `sub_10004E38` | `ID_CAP_BUILTIN_TCB` or `ID_CAP_TS_SCHEDULES_ALL` | 0: shut the scheduler down (`sub_10005350`); 1 / 2: enable / disable scheduling (`dword_10017010`) and reinitialise (`sub_10005038`); 3: `sub_10009214` ? | Service control |

Error codes of the service (facility 0xCF): 0x82CF0103 (initialisation), 0x82CF0106 (action allocation), 0x82CF0107 (invalid trigger), 0x82CF0108 (no action), 0x82CF0109 (invalid action), 0x82CF010E (task not found / end of enumeration), 0x82CF0112, 0x82CF0113 (opnum 11), 0x82CF0115 (invalid start / end time), 0x82CF0116 (invalid WNF trigger).

### Registry

| Key | Value | Type | Use |
|-----|-------|------|-----|
| `HKLM\SOFTWARE\Microsoft\WPTaskScheduler\{GUID}` | `Schedule` | REG_BINARY | The task item, pickled with `NdrMesTypeEncode2` (type format at 0x10001CBC + 36, `sub_100119E4`); a key without this value is deleted at start-up |
| same | `RuntimeData` | REG_BINARY | Pickled runtime data (20 bytes once decoded, `sub_10011C54` / `sub_10011B74`) |
| same | `Statistics` | REG_BINARY | Pickled statistics (`sub_10011AAC` / `sub_10011F5C`) |
| same | `Enabled` | REG_DWORD | Written by opnum 6 |
| same | `AdhocState` | ? | Read at load time (`sub_10010E18`) |
| `HKLM\SYSTEM\ControlSet001\Services\TaskSchedulerSvc\Parameters` | `TimeScale` | REG_DWORD | Clock speed factor, 1 (or absent) = real time |
| same | `TimeZoneInfo` | REG_BINARY | Time zone saved by the service, compared at start-up |

The key name is the task GUID formatted as `{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}` (`sub_10010C10`). Only persistent tasks (flag 0x01) are stored.

#### Stored values

The binary values are NDR type-serialisation buffers (`MesEncodeDynBufferHandleCreate`): an 8-byte common header `01 10 08 00 CC CC CC CC`, an 8-byte private header (length of the data, 0), then the data in NDR form (pointers become referent ids `0x0002xxxx` and the pointed data follows the structure; strings are `{max count, offset, actual count}` + UTF-16; enums are 2 bytes). Decoded from an export of a phone (`reg export HKLM\SOFTWARE\Microsoft\WPTaskScheduler`):

`Schedule` (task item of [Tasks](#tasks), +0x10 of the buffer = item +0x00):

| Buffer offset | Size | Content |
|---------------|------|---------|
| 0x10 | 4 | Referent of the task GUID |
| 0x14 | 4 | Flags (seen: 0x01 ×137, 0x03 ×25, 0x21 ×13, 0x05, 0x0B) |
| 0x18 | 4 | Referent of the name |
| 0x1C | 16 | Start `SYSTEMTIME`; `1582-02-24` (year < 1601) = none |
| 0x2C | 16 | End `SYSTEMTIME`; `9999-12-31` = none |
| 0x3C | 4 | Item +0x2C (−1 or 1) |
| 0x40 | 4 | Referent of the trigger (0 = none) |
| 0x44 | 4 | Referent of the action |
| 0x48 | 4 | Item +0x38 (0) |
| 0x4C | 16 | Task GUID |
| 0x5C | 12 | Name: max count 0x101 (257), offset 0, actual count, then the UTF-16 name, padded to 4 |
| … | 4 | Trigger: type (2 bytes) and union discriminant (2 bytes, same value), then the referent of the trigger data and the data (e.g. the 0x1C-byte [WNF trigger](#wnf-trigger) followed by the comparison value as `{count, bytes}`) |
| … | 4 | Action: type and discriminant (2 + 2 bytes), referent of the action data, then the data (for type 0: referents of the application and of the command line, then the two strings) |

`RuntimeData`: 0x40 bytes of data, containing the creator's SID as a string (`S-1-5-18` for the system tasks, the chamber SID `S-1-15-2-…` of the Alarms application for a `_Reminder_`).  
`Statistics`: two DWORDs (the first one grows with the runs: number of runs ?) and two `SYSTEMTIME` (last run and last load ?).

#### Tasks of a phone

An export of a Lumia 520 contains 177 tasks: 84 with a WNF trigger (type 1), 84 with a list trigger (type 2), 8 with a time trigger (type 0), 1 without trigger (a `_Reminder_`). Almost all are created by `S-1-5-18`. Examples:

| GUID | Name | Trigger | Action |
|------|------|---------|--------|
| `{C4CAAC6C-D10E-48EF-8167-6EF820F3685D}` | `WpPerfMonServerImmediate` | 1: WNF 0x0D92063DA3BC0875 (`PHTL` 1), condition 1, value 1 (DWORD) | 0: `%systemdrive%\windows\system32\WpPerfMonServer.exe`, no command line ([WpPerfMonServer.exe](../applications/wpperfmonserver.md)) |
| `{F6E92EC0-E5F9-41DF-B1BF-A0BBB4AD1071}` | `AppVerifWrapperImmediate` | 1: WNF 0x0D92063DA3BC1875 (`PHTL` 3), condition 1, value 1 | 0: `%systemdrive%\windows\system32\WpToolsWrapper.exe`, `WpToolsWrapper.exe -appverif` ([WpToolsWrapper.exe](../applications/wptoolswrapper.md)) |
| `{F6C28102-D5A4-4EC4-B31F-81FEA2735D6E}` | `BatteryLoggerStartImmediate` | 1: WNF 0x0D92063DA3BC1075 (`PHTL` 2), condition 1, value 1 | 0: `WpToolsWrapper.exe -poweron` |
| `{B9801F66-B23F-4BD8-915D-1FD8651B88A0}` | `TracingFlagsSetterStartImmediate` | 1: WNF 0x0D92063DA3BC2875 (`PHTL` 5), condition 1, value 1 | 0: `WpToolsWrapper.exe -tracingFlags` |
| `{3081686A-4C38-468B-83B9-AA6AEA939D4C}` | `UpdateUEFIDb` | 1: WNF 0x418A063EA3BC3875 (`SHL` 7, shell ready) | 0: `%systemdrive%\windows\system32\UpdateUEFIDb.exe` ([UpdateUEFIDb.exe](../applications/updateuefidb.md), which disables this task with opnum 6) |
| `{2B00BA79-D967-404E-B4E2-FB3C963EFA2B}` | `LiveTokenHourly` | 2: WNF states `CNET` 1, `SHL` 1, `CNET` 3, `OS` 8 | 0: `%systemdrive%\windows\system32\LiveToken.exe` ([pacmanserver.dll](./pacmanserver.md#rpc) enables / disables it) |
| `{0189E6C8-2AE6-4F78-9C2B-436494F7FA13}` | `_Groveler_SdCardMounted_` | 2: `OS` 1 ≠ 0, `OS` 12 ≠ 0 | 0: `c:\Programs\Groveler\Groveler.exe -SdCardMounted` |
| `{00DBF760-B3D5-42C0-A750-78CE3250E6AF}` | `DUNotificationInstall` | 1: WNF `DU` 1 | 0: `C:\PROGRAMS\DUACLIENT\DuaNotification.exe ReadyToInstall` |
| `{0802F61C-D9FD-4337-BA76-1F7F505FA346}` | `Lima Update Worker - Shell Ready` | 1: WNF `SHL` 7, condition 0 (any publication) | 1: background worker `app://058D0306-C05B-4BE0-A972-51CA37A82090/BW/ShellReady` |
| `{CD835B75-A43B-413D-A667-574C6EAC716A}` | `DuaDetectionSchedule` | 0: time (with the WNF state `WIFI` 1) | 0: `C:\PROGRAMS\DUACALLBACK\DuaCallback.exe StartScan` |
| `{F6BAF232-298F-4DF7-96AA-189E4F53EA56}` | `_Reminder_` | none (start = end = the ring time) | 4: the WNF state created for the task (`0x41C64E6DA3B18845` on this phone), then the packed reminder ([ShellChromeAPI.dll](./shellchromeapi.md#packed-reminder)) with its sound and the command line `c:\Programs\Alarms\Alarms_NoUI.exe ReminderDismissed 0` |

The `AlarmLockIconTask` of [ShellChrome.dll](./shellchrome.md#alarmlockicontask) isn't in the store: it's created without flag 0x01 at every shell start.

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x41C60C39A3BC0875 | `TB`, 1 | — | Subscribed at start-up (`sub_10007884`): the tasks are (re)loaded when it changes (time broker ready ?) |
| 0x41C61D22A3BC9075 | `OS`, 18 | 4 bytes: counter | Read, incremented and published by `LoadTasks` |
| WNF states of the [WNF triggers](#wnf-trigger) | — | — | Subscribed |
| States of the type 3 actions | — | data of the action | Published |
| One state per type 4 action | Created by the service | data of the action | Created, published, deleted |

### Capabilities

| Capability | Checked by |
|------------|------------|
| `ID_CAP_BUILTIN_TCB` | RPC owner check bypass, enumeration of all tasks, opnum 12 |
| `ID_CAP_TS_SCHEDULES_ALL` | Same as `ID_CAP_BUILTIN_TCB` |
| `ID_CAP_CREATE_PROCESS_IN_CHAMBER` | Process action: if the creator's chamber has it, the process isn't put in that chamber (chamber SID NULL) |

### ETW

Provider `{E8F90FE5-8C92-4146-A764-305AAF12B066}`, registered by `McGenEventRegister` in `InitializeScheduler`. Most functions write events (task creation, trigger, action result, errors); the event descriptors aren't decoded here.
