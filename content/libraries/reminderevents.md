## ReminderEvents.dll

The bridge between the reminders stored by the Task Scheduler service and the shell of Windows Phone 8.1: it watches the reminders and hands each one to the shell when it must be shown.  
`ReminderEvents.dll` is a small DLL (40 960 bytes, 131 functions, most of them CRT, RPC stubs and a hash map). It's an RPC client of the Task Scheduler service (interface `ITaskSchedulerSvcRpc`). At initialisation it lists the reminders of the service, and subscribes to the WNF state of each one. When the service publishes a reminder in its WNF state, the DLL forwards it to [ShellChrome.dll](./shellchrome.md#reminders)`!ProcessReminder`. It also handles dismiss/snooze requests from accessories (`ShellChrome!ProcessAccessoryReminderRequest`), and exports dismiss and snooze functions that call the service.  
The reminders of the alarms are created by [Alarms_NoUI.exe](../applications/alarms_noui.md) with [ShellChromeAPI.dll](./shellchromeapi.md#reminders)`!Shell_CreateReminder`, which creates the `_Reminder_` task (opnum 0) and packs the reminder data. `ReminderEvents.dll` is imported by [ShellChrome.dll](./shellchrome.md), the shell chrome library it calls back, which uses `AddReminderPublishStateName`, `RemoveReminderPublishStateName`, `ShellSnoozeReminder` and `ShellDismissReminder`. `InitializeReminderEvents` / `UninitializeReminderEvents` aren't imported by ShellChrome.dll: their caller is unknown.

Location on the phone: `C:\Programs\Alarms\ReminderEvents.dll` ? (it was extracted next to `Alarms.exe`, `Alarms_NoUI.exe` and [AlarmsSettingHandler.dll](./alarmssettinghandler.md)).  

### Imports

| DLL | Functions |
|-----|-----------|
| [ShellChrome.dll](./shellchrome.md) | `ProcessReminder`, `ProcessAccessoryReminderRequest` |
| RPCRT4.dll | `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingFree`, `NdrClientCall2`, `I_RpcExceptionFilter` |
| SecRuntime.dll | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor` |
| ntdll.dll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlQueryWnfStateData`, `RtlNtStatusToDosError` |
| WPCOREUTIL.dll | `SHGetKnownFolderPath` |
| api-ms-win-core-file-l1-2-1.dll | `DeleteFileW` |
| api-ms-win-core-com-l1-1-1.dll | `StringFromGUID2`, `CoTaskMemFree` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapFree` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSectionEx`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `InitOnceBeginInitialize`, `InitOnceComplete`, `Sleep` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleExW`, `GetModuleFileNameA` |
| api-ms-win-core-debug-l1-1-1.dll | `DebugBreak` |
| ntdll.dll (CRT) | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memcpy_s`, `memset`, `_vsnwprintf`, `_wcsnicmp`, `wcsnlen`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, processthreads (except `CreateThread`), errorhandling and debug imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `<known folder {2856B913-7185-4C9D-9ACC-981269A83C14}>\Reminders\Images\{GUID}.png` | `DeleteFileW` ([ShellDismissReminder](#shelldismissreminder-sub_100025ac)) | Image of a dismissed reminder (copied there by [ShellChromeAPI.dll](./shellchromeapi.md#packed-reminder)) |
| RPC server of the Task Scheduler service (`ITaskSchedulerSvcRpc`, dynamic LRPC endpoint) | `RpcBindingCreateW` / `RpcBindingBind` ([RPC](#rpc)) | Reminder data, dismiss and snooze; the hosting service binary isn't known |

No DLL is loaded at run time and no process or COM server is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 2 | `InitializeReminderEvents` | 0x10001C20 | none |
| 6 | `UninitializeReminderEvents` | 0x10001CC8 | none |
| 1 | `AddReminderPublishStateName` | 0x10001CDC | `const WNF_STATE_NAME *` |
| 3 | `RemoveReminderPublishStateName` | 0x10001CF4 | `const WNF_STATE_NAME *` |
| 4 | `ShellDismissReminder` | 0x10001D40 | `const GUID *reminderId, const WNF_STATE_NAME *` |
| 5 | `ShellSnoozeReminder` | 0x10001D0C | `const GUID *reminderId, DWORD` |

They all return an HRESULT and work on one global object (`sub_10001BB4`, at 0x100053D0, built on first use and destroyed by an `atexit` handler):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable (`off_100017C0`, destructor only) |
| 0x04 | 0x14 | Hash map WNF state name → WNF subscription handle (one entry per reminder, see `AddReminderPublishStateName`) |
| 0x18 | 0x18 | Critical section protecting the map |
| 0x30 | 4 | RPC binding handle to the Task Scheduler service |
| 0x34 | 4 | Handle of the enumeration thread |
| 0x38 | 1 | Initialised |
| 0x3C | 4 | Subscription to the WNF state 0x418A063EA3BD9075 (accessory snooze) |
| 0x40 | 4 | Subscription to the WNF state 0x418A063EA3BD9875 (accessory dismiss) |

### Startup

`start` (`_DllMainCRTStartup`, 0x1000445C): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then the usual `dllmain_dispatch` (`sub_10004168`: CRT init with `_initterm`, then `DllMain`).  
`DllMain` (`sub_10001A4C`) only registers the ETW provider on `DLL_PROCESS_ATTACH` (`McGenEventRegister`) and unregisters it on `DLL_PROCESS_DETACH`. Everything else is done by `InitializeReminderEvents`.

### InitializeReminderEvents (0x10001C20)

1. Gets the global object (`GetReminderEvents`, `sub_10001BB4`) and clears the snooze and dismiss subscription handles.
2. Connects to the task scheduler service (`ConnectTaskScheduler`, `sub_10003848`, see [RPC](#rpc)); returns its error if it fails.
3. Starts the enumeration thread `EnumerateReminders` (`sub_10002404`) with the object as parameter; returns `HRESULT_FROM_WIN32(GetLastError())` if `CreateThread` fails.
4. Subscribes to the accessory states (`SubscribeAccessoryStates`, `sub_100020BC`), marks the object as initialised and returns `S_OK`.

`SubscribeAccessoryStates` subscribes to the two WNF states 0x418A063EA3BD9075 and 0x418A063EA3BD9875 with the callback `AccessoryCallback` (`sub_10001D5C`), see [WNF states](#wnf-states).

**Enumeration thread** (`sub_10002404` → `sub_1000244C`), reads the reminders that already exist:
1. ETW event 100 (start).
2. RPC opnum 2 opens an enumeration (context handle) and returns the first item; opnum 3 returns the next item, until it fails.
3. For each item whose name (item +0x08) is `L"_Reminder_"` (`_wcsnicmp`, 11 characters: case-insensitive and exact): RPC opnum 11 with the GUID of the item (item +0x00) returns the 8-byte WNF state name of the reminder. Then `RtlQueryWnfStateData(…, ReminderCallback, …)` processes the current data of the state, and `AddReminderPublishStateName` subscribes to it.
4. The item is freed (`sub_10002744`); at the end, RPC opnum 4 closes the context handle. ETW event 101 (stop).

**UninitializeReminderEvents** (`sub_10001FAC`): unsubscribes from the two accessory states, then from every reminder state (`RtlUnsubscribeWnfNotificationWaitForCompletion`), empties the map, `RpcBindingFree`, initialised = 0.

### AddReminderPublishStateName / RemoveReminderPublishStateName

`AddReminderPublishStateName(name)` (`sub_10002214`): `RtlSubscribeWnfStateChangeNotification(&h, *name, 0, ReminderCallback, NULL)` then adds name → h to the map. Returns the NTSTATUS with bit 28 set if the subscription fails, `E_UNEXPECTED` (0x8000FFFF) if the handle is NULL, `E_OUTOFMEMORY` (0x8007000E) if the map insertion fails.  
`RemoveReminderPublishStateName(name)` (`sub_100022B0`): finds the name in the map, `RtlUnsubscribeWnfStateChangeNotification`, removes the entry.

The state name of a reminder comes from RPC opnum 11. `Shell_CreateReminder` / `Shell_DeleteReminder` of [ShellChromeAPI.dll](./shellchromeapi.md#reminders) send this state name to the shell (shell RPC opnums 57 / 58), whose server routines in [ShellChrome.dll](./shellchrome.md#rpc-server) (`sub_10070D0C` / `sub_10070CC8`, capability `ID_CAP_SHELL_NOTIFICATION_CLIENT`) call these two exports.

### ReminderCallback (sub_10001E44)

The WNF callback of every reminder state (`StateName`, `ChangeStamp`, `TypeId`, `Context`, `Buffer`, `Length`):

1. Empty buffer: ETW event 10000, returns 0.
2. Unpacks the buffer into a reminder (`UnpackReminder`, `sub_10003704`); on failure ETW event 10002 and goes to the end.
3. Computes the flags as `reminder+0x10 | reminder+0x14`.
4. Calls RPC opnum 5 with the reminder; on failure goes to the end. If the returned item has bit 0x10 set in its field +4, adds flag 0x800.
5. Calls `ProcessReminder(reminder, flags, &stateName)` in ShellChrome.dll.
6. Frees the reminder (`HeapFree`) and the RPC item (`FreeRpcItem`, `sub_10002744`); always returns 0.

The meaning of opnum 5 (called with the reminder, whose first 16 bytes are its GUID) and of bit 0x10 is unknown. On the shell side, flag 0x800 shows the reminder without the time check and without timeout (see [ShellChrome.dll](./shellchrome.md#reminders), which also explains flags 0x1, 0x2 and 0x1000).

### Reminder data

The data of a reminder WNF state is a DWORD giving the size of the header, the header, then the strings and the custom data. `UnpackReminder` (`sub_10003704`) copies it in a `HeapAlloc` buffer as a version 5 structure of 0xD0 bytes followed by the variable data, and turns the offsets into pointers:

| Size of the header | Version (header +0x50) | Conversion |
|--------------------|------------------------|------------|
| 0xD0 (208) | 5 | Copied as is (`sub_1000360C`) |
| 0xD0 (208) | 4 | `sub_100034D0`: same layout, without the fields 0xA4, 0xB0, 0xB4, 0xB8 |
| 0x5C (92) | (any) | `sub_10003434`: older format, offsets 0x00…0x4C kept, 0x50 → 0xA8, 0x54 → 0xAC, 0x58 → 0xBC |

Anything else returns `HRESULT_FROM_WIN32(ERROR_INVALID_DATA)` (0x8007000D) or `E_INVALIDARG`. The output version (+0x50) is always set to 5. A 208-byte header with +0x54 = 0 is rejected.

Version 5 structure (the same layout as the structure passed to `Shell_CreateReminder` by [Alarms_NoUI.exe](../applications/alarms_noui.md#shell_createreminder-parameters)):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 16 | GUID of the reminder |
| 0x10 | 4 | Flags (0x200 = disabled alarm, from Alarms_NoUI.exe) ? |
| 0x14 | 4 | Flags ? (ORed with 0x10 before `ProcessReminder`) |
| 0x18 | 0x20 | Two `SYSTEMTIME` |
| 0x38, 0x3C, 0x40, 0x44 | 4 each | Pointers (offsets in the WNF data): category, name, text, sound file |
| 0x48 | 4 | Pointer to the custom data |
| 0x4C | 4 | Size of the custom data |
| 0x50 | 4 | Structure version, 5 |
| 0x54 | 4 | Pointer: image file (`…\Reminders\Images\{GUID}.png`, copied there by [ShellChromeAPI.dll](./shellchromeapi.md#packed-reminder)) |
| 0x58…0x6C | 4 each | 6 pointers ? |
| 0x7C, 0x80 | 4 each | Pointers ? |
| 0x90, 0x94 | 4 each | Pointers ? |
| 0xA4 | 4 | Pointer ? (version 5 only) |
| 0xA8, 0xAC | 4 each | Pointers: program and command line started when the reminder is dismissed (launch structure of `Shell_CreateReminder`) |
| 0xB0, 0xB4, 0xB8 | 4 each | Pointers ? (version 5 only; fields 2…4 of the launch structure) |
| 0xBC | 4 | Enabled (`Shell_GetReminderData` in Alarms_NoUI.exe; set by [ShellChromeAPI.dll](./shellchromeapi.md#reminders) from bit 2 of the task flags, not part of the WNF data) |
| 0xC0 | 16 | `SYSTEMTIME` (next ring time ?), copied by `Shell_GetReminderData` from the task item +0x0C |

Fields not listed are copied without conversion.

### ShellDismissReminder (sub_100025AC)

1. Builds the image path `<known folder {2856B913-7185-4C9D-9ACC-981269A83C14}>\Reminders\Images\{GUID}.png` (`StringFromGUID2`, `SHGetKnownFolderPath(…, 0x4000, (HANDLE)-1)`, `StringCchPrintf`).
2. Deletes the image with `DeleteFileW`; returns `HRESULT_FROM_WIN32` of the error unless it's `ERROR_FILE_NOT_FOUND`.
3. Removes the WNF state name of the reminder (`RemoveReminderPublishStateName`).
4. Dismisses the reminder in the service with RPC opnum 1 (GUID) and returns its HRESULT.

The image of a reminder is `<known folder>\Reminders\Images\{GUID}.png`. The known folder `{2856B913-7185-4C9D-9ACC-981269A83C14}` isn't a desktop Windows one (Windows Phone folder, unknown name); flag 0x4000 is `KF_FLAG_DONT_VERIFY` ?

### ShellSnoozeReminder (0x10001D0C)

`ShellSnoozeReminder(id, value)` only calls RPC opnum 10 (`sub_10002868`) with the GUID and the DWORD (snooze time ?). [ShellChrome.dll](./shellchrome.md#reminders)`!CreateNewReminder` calls it with 1 when the shell can't show the reminder.  
`ShellDismissReminder` is called by `DismissReminder` (`sub_10065884`) of ShellChrome.dll.

### RPC

`sub_10003848` connects to the Task Scheduler service:
1. `QueryTransientObjectSecurityDescriptor(9, L"ITaskSchedulerSvcRpc\\Server", &sd)` (SecRuntime): security descriptor expected for the server. NTSTATUS 0xC0000109 is returned as 0x8007013D, other errors as the Win32 error of `RtlNtStatusToDosError` (or the NTSTATUS with bit 28 set).
2. `RpcBindingCreateW(&template, &security, NULL, &hBinding)`:
   - template: version 1, flags 0, protocol sequence 3 (`RPC_PROTSEQ_LRPC`), no address, no endpoint (resolved by the endpoint mapper);
   - security: version 1, no principal name, authentication level 6 (`RPC_C_AUTHN_LEVEL_PKT_PRIVACY`), service 10 (`RPC_C_AUTHN_WINNT`), QoS version 5 with `RPC_C_QOS_IDENTITY_DYNAMIC`, `RPC_C_IMP_LEVEL_IDENTIFY` and `ServerSecurityDescriptor = sd` (the server must have this security descriptor).
3. `RpcBindingBind(NULL, hBinding, interface)`, tried up to 3 times, 500 ms apart, while it fails with 1722 (`RPC_S_SERVER_UNAVAILABLE`), 1708, 1717 (`RPC_S_UNKNOWN_IF`) or 1753 (`EPT_S_NOT_REGISTERED`): the service may not be started yet.

Interface `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` version 2.0 (client interface at 0x10001140, MIDL stub descriptor at 0x10001748). The procedures used (all with the binding as explicit primitive handle; parameters read from the format strings):

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 1 | `sub_1000396C` | `ShellDismissReminder` | `[in] GUID *` | Dismiss the reminder |
| 2 | `sub_100039CC` | Enumeration thread | `[out] context handle`, `[in,out]`, `[in,out]`, `[in,out]` item | Start the enumeration, first item |
| 3 | `sub_10003A3C` | Enumeration thread | `[in] context handle`, same as opnum 2 | Next item |
| 4 | `sub_10003AAC` | Enumeration thread | `[in,out] context handle` | End of the enumeration |
| 5 | `sub_10003B0C` | `ReminderCallback` | `[in] GUID *`, `[in,out]`, `[in,out]` | ? (result +4 bit 0x10 → flag 0x800) |
| 10 | `sub_10003B74` | `ShellSnoozeReminder` | `[in] GUID *`, `[in] long` | Snooze the reminder |
| 11 | `sub_10003BD8` | Enumeration thread | `[in] GUID *`, `[in,out]` 8 bytes | WNF state name of the reminder |

Every procedure returns a `long` (HRESULT). The other opnums (0, 6…9) aren't used. The server side (service DLL) isn't analysed. An enumerated item has a GUID pointer at +0x00 and a name at +0x08; it's freed by `sub_10003D40` (fields +0x00, +0x08, +0x30, +0x34).

### WNF states

Decoded by XOR with 0x41C64E6DA3BC0074 (as in [wppower.sys](../drivers/wppower.md#wnf-states)): version 1, well-known, system scope, not permanent, owner tag `SHL`, like the states published by [Alarms_NoUI.exe](../applications/alarms_noui.md#wnf-states).

| Name | Owner, sequence | Data | Action (`AccessoryCallback`, `sub_10001D5C`) |
|------|-----------------|------|-----------------------------------------------|
| 0x418A063EA3BD9075 (`.text:0x100017E8`) | `SHL`, 50 | 20 bytes: GUID + DWORD | `ProcessAccessoryReminderRequest(&data, 1, data.dword)`: snooze, the DWORD is the snooze time ([ShellChrome.dll](./shellchrome.md#reminders) stores it in the shown reminder) |
| 0x418A063EA3BD9875 (`.text:0x10001848`) | `SHL`, 51 | 16 bytes: GUID | `ProcessAccessoryReminderRequest(&data, 0, 0)`: dismiss |
| Name returned by RPC opnum 11 | ? | [Reminder data](#reminder-data) | `ReminderCallback`: `ProcessReminder` |

Data of another size, or another state name, is ignored (ETW event 10000). The symbolic names (`WNF_SHL_...`) and the publishers of the two `SHL` states are unknown (accessory = a connected watch / band ?).

### ETW

Provider `{37DF0687-A79C-4844-BB60-D8F71067B654}`, registered in `DllMain` (context `unk_10005010`, enable callback `ETW_EnableCallback` 0x10001A98, enable bits in `dword_10005280`).

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 100 | 4 (info) | 1 (start), 1 | 0x2 | 0x10 | Enumeration thread starts |
| 101 | 4 (info) | 2 (stop), 1 | 0x2 | 0x10 | Enumeration thread ends |
| 10000 | 4 (info) | 0, 10000 | 0x200000 | 0x01 | WNF callback with unexpected name or data |
| 10001 | 2 (error) | 0, 10000 | 0x400000 | 0x02 | Failed HRESULT, with the source line number (`sub_10002C4C`) |
| 10002 | 3 (warning) | 0, 10000 | 0x100000 | 0x04 | Invalid reminder data (`sub_10002C9C`) |
