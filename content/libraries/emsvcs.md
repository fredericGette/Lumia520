## EMSVCS.dll

Client library of the Windows Phone 8.1 execution manager: the factories that the shell and the system services use to talk to the execution manager service (foreground and background tasks, debugging, VoIP, application instance manager, resource manager).  
`EMSVCS.dll` is a small C++ DLL (75 360 bytes, 352 functions, no symbols). Each export creates a reference-counted proxy object. Its methods are thin wrappers around `NdrClientCall2` on one of 11 LRPC interfaces. Nine of those interfaces are served by the endpoint whose security descriptor name is `ExecManService\Server`, and two by `AppXExecutionSvc\Server`. A few methods also call the PacMan COM server ([pacmanserver.dll](./pacmanserver.md#com-server)) to turn a process or an application ID into an application, and the location tracking service of the immersive shell. The DLL has no global state, no thread of its own except the debug event thread, and no live ETW (see [ETW](#etw)).  
It is imported by [MobileUI.exe](../applications/mobileui.md) and [ScreenRecorderImpl.dll](./screenrecorderimpl.md) (`CreateExecutionManager`), [BtServ.dll](./btserv.md) (`CreateExecutionManager`, `CreateAIMProxy`), [pacmanserver.dll](./pacmanserver.md) (`CreateExecutionManager`, `CreateDebugManager`, `CreateBackgroundWorkerManager`), [ShellChrome.dll](./shellchrome.md) (`CreateExecutionManager`, `CreateBackgroundWorkerManager`) and [TaskSchedulerSvc.dll](./taskschedulersvc.md#actions) (`CreateBackgroundWorkerManager`). The RPC servers aren't analysed here: they're probably in `execmanserver.dll`, which runs in the same `svchost.exe -k WPTCBCritical` as `EMSVCS.dll` ([observed](./taskschedulersvc.md)).

Location on the phone: `C:\Windows\System32\EMSVCS.dll` ? (loaded in `svchost.exe -k WPTCBCritical`; the binary was extracted alone)  

### Imports

| DLL | Functions |
|-----|-----------|
| [SecRuntime.dll](./secruntime.md) | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor`, `GetChamberSidFromId`, `CreateTokenFromChamberSid`, `BuildSecurityDescriptorForSharingAccess` |
| RPCRT4.dll | `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingFree`, `NdrClientCall2`, `I_RpcExceptionFilter` |
| OLEAUT32.dll | `SysAllocString`, `SysFreeString`, `SysStringLen` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoUninitialize`, `CoCreateInstance`, `CoCreateGuid`, `StringFromGUID2` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegGetValueW`, `RegCloseKey` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `InitializeCriticalSectionEx`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`, `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `Sleep` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `WaitForMultipleObjects` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `GetCurrentProcessId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalFree` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventWrite` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcmp`, `wcslen`, `wcsstr`, `wcscpy_s`, `_initterm`, `_amsg_exit`, `_XcptFilter`, `__C_specific_handler`, `__CxxFrameHandler3` |

The rtlsupport and errorhandling imports, `GetCurrentProcess`/`TerminateProcess` and most of msvcrt are the Visual C++ DLL CRT startup and `/GS` security cookie code. `RaiseException(0xC0000017)` is the `SysAllocString` failure path (`sub_10004478`).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| RPC server `ExecManService\Server` (execution manager service, probably `execmanserver.dll`, not analysed) | `RpcBindingCreateW` / `RpcBindingBind`, dynamic LRPC endpoint ([RPC](#rpc)) | 9 interfaces: execution manager, background workers, background execution, AIM, debug, VoIP, resource manager |
| RPC server `AppXExecutionSvc\Server` (?) | same | Foreground task manager, AppX execution manager, AppX resource manager |
| RPC server whose security descriptor name is `ResourceManagerRPC` (?) | same | Bound by the resource manager object, never called |
| PacMan server [pacmanserver.dll](./pacmanserver.md#com-server), CLSID `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` (`CLSID_PMSvc`) | `CoCreateInstance(CLSCTX_ALL (0x17), IPMEnumerationManager {698D57C2-292D-4CF3-B73C-D95A6922ED9A})`, then QueryInterface `IPMEnumerationManager2 {D83400E1-A7A6-4990-9B84-10490AFF2063}` | Application info for the [foreground task manager](#createforegroundtaskmanager-0x100044a8) and the [background execution manager](#createbackgroundexecutionmanager-0x1000731c) |
| Immersive shell `{C2F03A33-21F5-47FA-B4BB-156362A2F239}` (`IServiceProvider` `{6D5140C1-7436-11CE-8034-00AA006009FA}`; also used by [AppXDeploymentServer.dll](./appxdeploymentserver.md#dependencies)) | `CoCreateInstance(CLSCTX_LOCAL_SERVER \| CLSCTX_NO_CODE_DOWNLOAD (0x404))`, `QueryService({68CA3595-D70A-4FA6-B9AF-24CF4918E4C6}, {402D0F67-CD0A-4A7A-849B-068515B93866})` | Location tracking service ? used by the [background execution manager](#createbackgroundexecutionmanager-0x1000731c) for the AppX applications |

No DLL is loaded at run time and no process is started. `HKLM\System\AIM` is read by [CreateAIMProxy](#createaimproxy-0x1000594c).

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `CreateBackgroundExecutionManager` | 0x1000731C | `void **object` |
| 2 | `CreateBackgroundWorkerManager` | 0x100040B8 | `void **object` |
| 3 | `CreateForegroundTaskManager` | 0x100044A8 | `IUnknown *channelFactory` (?), `void **object` |
| 4 | `TestHook_CancelShutdown` | 0x100058AC | none |
| 5 | `CreateAIMProxy` | 0x1000594C | `DWORD type` (1…11), `DWORD *id`, `void **object` |
| 6 | `CreateDebugManager` | 0x1000604C | `void **object` |
| 7 | `CreateDebuggerListener` | 0x1000686C | `void **object` |
| 8 | `CreateDebuggerMux` | 0x10006A1C | `void **object` |
| 9 | `CreateExecutionManager` | 0x10008000 | `void **object` |
| 10 | `CreateVoIPTaskManager` | 0x10006BE0 | `void **object` |
| 11 | `GetChamberSID` | 0x100083B4 | `GUID productId` (by value), `DWORD *size`, `BYTE *sid` |

They all return an HRESULT: `E_INVALIDARG` (0x80070057) for a NULL output pointer or a bad argument, `E_OUTOFMEMORY` (0x8007000E), or the error of the binding. A factory builds its object with `operator new` and sets the reference count to 1. It then binds to the server and returns the object, or releases it (vtable slot 2) on failure. The objects are WRL-style classes: slot 0 is `QueryInterface`, slot 1 `AddRef`, slot 2 `Release`, and the last slot is the deleting destructor. In most classes `QueryInterface` is `sub_10004498`, which always returns `E_NOTIMPL` (0x80004001): those objects are used as plain C++ interfaces. Only the background worker manager, the foreground task manager and the AIM proxy answer `QueryInterface` (IIDs given below). The interface names aren't in the binary. The names used here come from the exports.

Summary of the objects (slots counted from 0, IUnknown included):

| Export | Size | Bindings (offset: interface) | Other members |
|--------|------|------------------------------|---------------|
| `CreateExecutionManager` | 0x10 | +0x08: execution manager; +0x0C: AppX execution manager (bound on first use, `sub_1000838C`) | +0x04 references |
| `CreateBackgroundWorkerManager` | 0x14 | +0x0C: background worker manager | +0x08 references, +0x10 [resource manager object](#resource-manager-object) |
| `CreateForegroundTaskManager` | 0x100 | +0x14: foreground task manager | see [below](#createforegroundtaskmanager-0x100044a8) |
| `CreateAIMProxy` | 0x1C | +0x10: AIM | +0x08 references, +0x0C type, +0x14 default latency, +0x18 resource manager object |
| `CreateDebugManager` | 0x38 | +0x20: debug | see [below](#createdebugmanager-0x1000604c) |
| `CreateDebuggerListener` | 0x0C | +0x08: execution manager | +0x04 references |
| `CreateDebuggerMux` | 0x0C | +0x04: debug | +0x08 references |
| `CreateVoIPTaskManager` | 0x28 | +0x20: VoIP (bound on first use) | +0x04 references, +0x08 critical section, +0x24 context handle |
| `CreateBackgroundExecutionManager` | 0x60 | +0x20: execution manager; +0x24: background execution | see [below](#createbackgroundexecutionmanager-0x1000731c) |

### Startup

`DllEntryPoint` (0x1000997C): `__security_init_cookie`, then the CRT `dllmain_dispatch` (`sub_10009478`: `_initterm`, `atexit` table, then the optional user `DllMain` through `off_1000C2C8`). There is no `DllMain` of its own: no ETW registration and no global initialisation. Everything starts with the factories.

### Binding (sub_10009254)

`BindToRPCServer(clientInterface, securityName, &binding)` (`sub_10009254`, the name `DevPlat::Shared::BindToRPCServer` is in its error trace):

1. `QueryTransientObjectSecurityDescriptor(9, securityName, &sd)` ([SecRuntime](./secruntime.md#querytransientobjectsecuritydescriptor-0x10003c20)): the security descriptor the server must have. `STATUS_OBJECT_NAME_NOT_FOUND` (0xC0000034) means no check (sd = NULL). Other errors are returned with bit 28 set.
2. `RpcBindingCreateW(&template, &security, NULL, &binding)`:
   - template: version 1, flags 0, protocol sequence 3 (`RPC_PROTSEQ_LRPC`), no address and no endpoint (resolved by the endpoint mapper);
   - security: version 1, authentication level 6 (`RPC_C_AUTHN_LEVEL_PKT_PRIVACY`), service 10 (`RPC_C_AUTHN_WINNT`), QoS version 5 with `RPC_C_QOS_IDENTITY_DYNAMIC`, `RPC_C_IMP_LEVEL_IDENTIFY` and `ServerSecurityDescriptor = sd`.
3. `RpcBindingBind(NULL, binding, interface)`, once (no retry, unlike [ReminderEvents.dll](./reminderevents.md#rpc)). A positive RPC status is returned as `HRESULT_FROM_WIN32`.

The names are `ExecManService\Server`, `AppXExecutionSvc\Server` and `ResourceManagerRPC`.

Every stub returns its `long` (HRESULT), or `HRESULT_FROM_WIN32` of the RPC exception code (`I_RpcExceptionFilter`).

### CreateExecutionManager (0x10008000)

Binds the execution manager interface `{EBB6E887-…}` at +0x08. The vtable at 0x10003E44 has these methods:

| Slot | Function | Call | Use |
|------|----------|------|-----|
| 3 | `sub_100080E0` | AppX execution opnum 1 (`long pid`, `[out] GUID`) | Product ID of a process ([ScreenRecorderImpl.dll](./screenrecorderimpl.md#application-identity-sub_1000264c) on its own process; the background execution manager on a client process) |
| 4 | `sub_1000814C` | AppX execution opnum 0 (`0`, `[out] GUID`) | Product ID (of the foreground application ?) |
| 5 | `sub_100081B8` | AppX execution opnum 4 (`long`) | ? |
| 6 | `sub_1000820C` | execution manager opnum 8 (`enum`, `[out] long`) | ? |
| 7 | `sub_10008260` | execution manager opnum 9 () | ? |
| 8 | `sub_100082A8` | AppX execution opnum 2 (`long`, `long`, `wchar_t *`, `wchar_t *`), both strings required | ? |
| 9 | `sub_10008328` | AppX execution opnum 5 (`[out] long`) | ? |

Every AppX method first binds `{0FC77B1A-…}` to `AppXExecutionSvc\Server` if that's not done yet.

### CreateBackgroundWorkerManager (0x100040B8)

Binds `{4172BF6F-…}` at +0x0C, then creates a [resource manager object](#resource-manager-object) at +0x10. `E_ACCESSDENIED` (0x80070005) from the resource manager is ignored: the object is still returned, but without a resource manager. `QueryInterface` (`sub_1000437C`) returns the object for `IUnknown` and `{BB077FB8-484B-4F49-852E-AA39C12F3B29}`, and the object +4 for `{4453A201-849D-4CB1-BDF2-611739817668}`.

| Interface (vtable) | Slot | Call |
|--------------------|------|------|
| `{BB077FB8-…}` (0x10001164) | 3 `sub_100041BC` | background worker opnum 0 (`wchar_t *`, `byte[]` with its size, `long`, `long *`, `long *`, `[out] long`): starts a worker; [pacmanserver.dll](./pacmanserver.md#dependencies) uses it to start `InstallerWorker.exe` with its command line, and [TaskSchedulerSvc.dll](./taskschedulersvc.md#actions) for the background tasks |
| | 4 `sub_10004224` | background worker opnum 1 (`long`) |
| | 5 `sub_10004274` | background worker opnum 2 (`wchar_t *`, `byte[]`, `byte[]`, `enum`, `[in,out] long *`) |
| `{4453A201-…}` (0x10003AC4) | 3…6 | resource manager opnums 16, 17, 18, 19 (`E_ACCESSDENIED` without a resource manager) |

### CreateForegroundTaskManager (0x100044A8)

The first parameter is required. It's a COM object, not identified, that creates message channels (a CoreMessaging-like factory ?). The object (0x100 bytes) has four interfaces. The one at +0 is returned. `QueryInterface` (`sub_100057B8`) returns +4 for `IUnknown` and `{23B500C2-5623-4428-9DB4-A4803B62E684}`, +8 for `{D1085C9C-64D3-49B2-BC55-77A9C101B302}`, and +0x0C for `{83280408-0CFA-4006-88FE-039BEE064E43}`.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00…0x0C | 4 each | vtables 0x10003C10, 0x10003BC4, 0x10003B68, 0x10003B80 |
| 0x10 | 4 | References |
| 0x14 | 4 | Binding of the foreground task manager `{8EC21E98-…}` (`AppXExecutionSvc\Server`) |
| 0x18 | 4 | Notification sink set by slot 3 (AddRef'ed) |
| 0x1C | 4 | Channel factory (first parameter of the export) |
| 0x20, 0x24 | 4 each | The two channels created by the factory |
| 0x28 | 0x50 | Name of the first channel: a new GUID string (`CoCreateGuid`, `StringFromGUID2`) |
| 0x78 | 0x50 | Name of the second channel: another GUID string |
| 0xC8, 0xCC | 4 each | Registration cookies of the two channels |
| 0xD0 | 4 | PacMan `IPMEnumerationManager` |
| 0xD4 | 4 | PacMan `IPMEnumerationManager2` |
| 0xD8 | 4 | `CoInitializeEx` done |
| 0xDC | 4 | [Resource manager object](#resource-manager-object) (`sub_10008480`) |
| 0xE0 | 4 | AppX resource manager object (`sub_10008C4C`: 0x10 bytes, binding of `{B1EF227E-…}` at +0x0C, `AppXExecutionSvc\Server`) |
| 0xE4 | 0x18 | Critical section |
| 0xFC | 4 | Counter of the type 5 messages (reset by slot 17) |

Initialisation (`sub_100046F8`):
1. `sub_1000481C`: creates two GUID names (+0x28, +0x78). It builds a security descriptor for the chamber `execmanservice` and one for the chamber `AppXExecutionSvc` (`sub_10009364`: `GetChamberSidFromId`, `CreateTokenFromChamberSid(sid, 1, &token)`, `BuildSecurityDescriptorForSharingAccess(token, NULL, GENERIC_ALL, &sd)`). The factory then creates one channel per descriptor (method +0x24) and registers the callback `sub_100049D0` on each (method +0x30, cookies at +0xC8 / +0xCC). Finally it gets an object (method +0x14) and publishes each channel under its GUID name (that object's method +0x14). The method signatures come from how they're called (unidentified interface).
2. Binds `{8EC21E98-…}` to `AppXExecutionSvc\Server`, and creates the resource manager and AppX resource manager objects (`E_ACCESSDENIED` ignored).
3. `CoInitializeEx(NULL, COINIT_MULTITHREADED)`, PacMan `CoCreateInstance` + QueryInterface `IPMEnumerationManager2` (`E_FAIL` if missing).
4. Foreground task manager opnum 0 with the two channel names: the server opens the channels to send notifications.

**Notifications** (`sub_100049D0(object, message, size)`): `E_FAIL` if the message is shorter than 16 bytes. The DWORD at +0 is the type, and the message is forwarded to the sink (+0x18):

| Type | Sink method | Arguments |
|------|-------------|-----------|
| 1 | +0x0C | message +4, +8, pointer to +0x10 |
| 2 | +0x10 | +4 |
| 3 | +0x14 | +4 |
| 4 | +0x18 | +4, +8 |
| 5 | +0x1C | only on the second type 5 message (counter +0xFC, under the critical section) |
| 6 | +0x20 | +4, +8 |

The destructor unregisters the channels (factory method +0x50), releases everything, `RpcBindingFree` and `CoUninitialize`.

Methods (RPC on the binding +0x14 unless stated):

| Interface | Slot | Call |
|-----------|------|------|
| +0 (0x10003C10) | 3 `sub_10004A90` | Sets the notification sink |
| | 4…12 | foreground opnums 1, 2, 3, 4, 5, 6, 8, 7, 9 |
| | 13 `sub_10005010` | `IPMEnumerationManager2` method 3 (application ID as `BSTR`), QueryInterface `IPMApplicationInfo` `{50AFB58A-…}`, method 7 → string copied into the caller's buffer (`wcscpy_s`, `0x8007007A` if too small; required size returned) |
| | 14 `sub_10004FB0` | Same string, from a product ID: `IPMEnumerationManager` method 9 (`get_ApplicationInfo`) |
| | 15 `sub_10005150`, 16 `sub_100050DC` | Same lookups (by application ID / product ID), then `IPMApplicationInfo` method 20 → BOOL: TRUE when it returns 0 |
| | 17 `sub_100053B0` | Resets +0xFC, foreground opnum 10 |
| | 18 `sub_10005454` | `id` with high byte 0x0A: AppX resource manager opnum 0; else resource manager opnum 15 |
| | 19…21 | foreground opnums 11, 14, 15 |
| | 22 `sub_100055E4` | `IPMEnumerationManager` method 12, then method 6 of the returned object |
| +4 `{23B500C2-…}` (0x10003BC4) | 3…14 | resource manager opnums 3, 4, 7, 6, 5, 8 (followed by AppX resource manager opnum 10), 12, 13, 9, 10, 11, 14 |
| +8 `{D1085C9C-…}` (0x10003B68) | 3…5 | foreground opnums 12, 13, 16 |
| +0x0C `{83280408-…}` (0x10003B80) | 3 | `E_NOTIMPL` |
| | 4…12 | AppX resource manager opnums 1…9 |

The resource manager methods return `E_ACCESSDENIED` when that object doesn't exist.

### Resource manager object

`sub_10008480` (0x14 bytes, vtables 0x10003EA0 / 0x10003E9C): binds `{6F64B095-…}` to `ExecManService\Server` (+0x0C) and `{2C7FD9CE-E706-4B40-B412-953107EF9BB0}` to `ResourceManagerRPC` (+0x10). It has no methods of its own: its owners call the stubs directly with its +0x0C binding. No stub uses the +0x10 binding. The background worker manager, the foreground task manager and the AIM proxy create one each. [TestHook_CancelShutdown](#exports) creates a temporary one, calls resource manager opnum 11 (no parameter) and releases it.

### CreateAIMProxy (0x1000594C)

Application instance manager proxy ([BtServ.dll](./btserv.md) keeps it at +0x104 of its service object). `type` must be 1…11, and `id` and `object` non-NULL. `sub_10005A54`:

1. Binds `{29269506-…}` to `ExecManService\Server` (+0x10), creates a resource manager object (+0x18, `E_ACCESSDENIED` ignored).
2. AIM opnum 0 (`[out] long`) → `*id`.
3. Default latency (+0x14) = 180 000 (0x2BF20, 3 minutes in ms ?), replaced by `HKLM\System\AIM` `DefaultLatencyRequirement` (`RegGetValueW`, `RRF_RT_REG_DWORD`) when the value exists.
4. Stores `type` at +0x0C: it's the first argument of every other AIM call.

`QueryInterface` (`sub_10005F98`): +4 for `IUnknown` and `{CA2106AC-03BA-44F2-A992-A0DB071CD570}`.

| Interface | Slot | Call |
|-----------|------|------|
| +0 (0x10003CD4) | 3, 4 | AIM opnums 1, 2 (type) |
| | 5 `sub_10005C00` | AIM opnum 3 (type, `GUID`, `GUID`, `enum`, `[out] long`) |
| | 6 `sub_10005C9C` | AIM opnum 4 (type, `GUID`) |
| | 7 `sub_10005D14` | AIM opnum 5 (type, `long`, `[out]` 0x28-byte structure) |
| | 8 `sub_10005D7C` | Slot 9 with the default latency (+0x14) inserted as its 7th argument (the 8th RPC parameter, a `long`) |
| | 9 `sub_10005DAC` | AIM opnum 6 (type, `GUID`, `wchar_t *`, `byte[]`, `long` (size), `enum`, `long`, `long`, `[out] long`, `[in,out,unique] enum *`) |
| | 10, 11 | AIM opnums 7, 8 (type, `long`) |
| +4 `{CA2106AC-…}` (0x10003CBC) | 3 `sub_10005EC0` | resource manager opnum 0 (`wchar_t *`, `byte[]`, `long`, `[out] long`, `[out] long`); `E_ACCESSDENIED` without a resource manager |

The GUIDs are passed by value (16 bytes) and are probably product IDs: [BtServ.dll](./btserv.md#creating-a-request) tells the AIM about the background requests of an application identified by its product ID.

### CreateDebugManager (0x1000604C)

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable 0x10003D08 |
| 0x04 | 4 | References |
| 0x08 | 0x18 | Critical section (`InitializeCriticalSectionEx`) |
| 0x20 | 4 | Binding of the debug interface `{8A04D20B-…}` (`ExecManService\Server`) |
| 0x24 | 4 | Stop event (`CreateEventW`, auto-reset) |
| 0x28 | 4 | Event thread (`sub_1000619C`) |
| 0x2C | 4 | Event handle returned by the server (new events) |
| 0x30 | 4 | Event handle returned by the server (acknowledge) |
| 0x34 | 4 | Debug event sink |

Methods (each under the critical section):
- slot 3 `sub_1000626C(GUID *productId, long, sink)`: debug opnum 0 (`GUID`, `long`, `[out] long`, `[out] long`) returns the two event handles (+0x2C, +0x30). Creates the stop event and the thread the first time, then stores the sink.
- slot 4 `sub_100063B0`: stops the thread (`SetEvent` stop, waits up to 5 s), opnum 1;
- slots 5…9: opnums 3 (`GUID`), 4 (`long`, `long`), 5 (`long`), 6 (`long`), 7 (`long`, `[out]` structure).

The event thread waits on {stop, +0x2C}. On each server event it calls opnum 2 (`[out]` {size, pointer}). It accepts only a 24-byte event and dispatches on its DWORD +0: 1 → sink +0x0C(+4, +8, +0xC); 2 → sink +0x10(+4, +0x10); 3 → sink +0x14(+4); 4 → sink +0x18(+4). If the byte at +0x14 is set, it then does `SetEvent(+0x30)` (the server waits for the debugger to acknowledge). The buffer is freed with `free`. [pacmanserver.dll](./pacmanserver.md) uses this manager (for the debug API ?).

**CreateDebuggerMux** (0x10006A1C) is another client of the same interface: slots 3…5 = debug opnums 8 (`long`, `long`, `wchar_t *`), 9 (`wchar_t *`), 10 (`wchar_t *`).  
**CreateDebuggerListener** (0x1000686C) uses the execution manager interface: slots 3, 4 = opnums 2 and 3 (`[out] long`, `E_INVALIDARG` if the pointer is NULL).

### CreateVoIPTaskManager (0x10006BE0)

The factory doesn't connect. Every method first calls `sub_10006CC8`: under the critical section it binds `{34144019-…}` to `ExecManService\Server` on the first call, then VoIP opnum 0 (`[out]` context handle, kept at +0x24). The destructor closes the context handle with opnum 1 and frees the binding.

| Slot | Call |
|------|------|
| 3…10 | VoIP opnums 2…9 (context, `GUID`) |
| 11 `sub_100070AC` | Opnum 10 (context, `[out] long`): an event handle. Waits for it up to 30 s, then opnum 11 (context, `[out] long`) → result. If opnum 11 returns 0x80040201, it closes the handle and repeats opnum 10, the wait and opnum 11 once. A timeout is returned as `HRESULT_FROM_WIN32(WAIT_TIMEOUT)` |
| 12 | Opnum 12 (context, `[in]` interface pointer `{03A327AA-6A4A-4D6C-A02C-4B69E0B5AE88}`, `[out] long`) |
| 13 | Opnum 13 (context, `long`) |

### CreateBackgroundExecutionManager (0x1000731C)

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable 0x10003E08 |
| 0x04 | 4 | References |
| 0x08 | 0x18 | Critical section |
| 0x20 | 4 | Binding of the execution manager `{EBB6E887-…}` |
| 0x24 | 4 | Binding of the background execution interface `{A07F6818-…}` |
| 0x28 | 4 | Location tracking service ? from the immersive shell (NULL if not available) |
| 0x2C | 4 | Execution manager object (`CreateExecutionManager`, on first use) |
| 0x30 | 4 | PacMan `IPMEnumerationManager` (on first use) |
| 0x34 | 0x14 | Hash map process ID → count (type 2) |
| 0x48 | 0x14 | Hash map ID → count (type 1) |
| 0x5C | 4 | Last process registered with type 2 |

`sub_100074A8` binds both interfaces to `ExecManService\Server`. It then asks the immersive shell for `IServiceProvider` and calls `QueryService` (see [Dependencies](#dependencies)) to fill +0x28. A failure here is ignored.

Methods:
- slot 3 `sub_1000756C(type, pid)`: type must be 2, and pid must be non-zero and not the current process. A pid already registered only gets its count incremented. Otherwise the pid is added, then `Register` (`sub_10007634`):
  - for a classic application, execution manager opnum 5 (`type`, `pid`);
  - for an AppX application whose background tasks include `LocationTracking`, method +0x10 of the location service (`pid`, 0x10000000);
  - for any other AppX application, `E_ACCESSDENIED`.

  On success the previous pid (+0x5C) is removed and unregistered with reason 9, and the new pid is stored at +0x5C.
- slot 4 `sub_100076B4(type, reason, pid)`: decrements the count. At the last reference it removes the pid and unregisters it (`sub_10007760`): location service method +0x14 (`pid`, 0x10000000, `reason`) for an AppX application, else execution manager opnum 6 (`type`, `reason`, `pid`).
- slots 5 / 6 (`sub_100077D4` / `sub_100078A4`, type 1): the same counting on the second map, with background execution opnum 9 (`1`, `id`) and opnum 10 (`1`, `reason`, `id`).
- slot 7 `sub_10007988`: copies a 12-byte structure (size must be 12).
- slots 8, 9: background execution opnums 11 and 12 (`long`, non-zero).

"AppX application" (`sub_10007A5C`): the product ID of the process (execution manager slot 3), then `IPMEnumerationManager` method 9 (`get_ApplicationInfo`), then QueryInterface `IPMApplicationInfo2` `{2925390A-…}` succeeds. The same test is used by [WPToolsSvc.exe](../applications/wptoolssvc.md). For the location check (`sub_10007ABC`), method 11 of `IPMEnumerationManager` is called with the product ID, then method 22 of the returned object gives a string. The application qualifies if the string contains `LocationTracking` (`wcsstr`).

### GetChamberSID (0x100083B4)

`GetChamberSID(productId, &size, buffer)`: `size` and `buffer` are required. It creates a temporary binding to the execution manager, calls opnum 4 (`GUID`, `[in,out] long *size`, `[in,out]` buffer of `size` bytes) and frees the binding. It returns the SID of the application's chamber, as stored by the server (format ?).

### RPC

11 client interfaces, all version 0.0 and the NDR syntax, with the binding as an explicit primitive handle (except VoIP opnums 2…13, which use the context handle). "Opnums used" lists every stub present in the binary.

| Interface | Client interface | Security name | Object | Opnums used |
|-----------|------------------|---------------|--------|-------------|
| `{EBB6E887-1016-4962-B1FF-F547226D14A1}` execution manager | 0x100019C0 | `ExecManService\Server` | execution manager, debugger listener, background execution manager, `GetChamberSID` | 2, 3, 4, 5, 6, 8, 9 |
| `{0FC77B1A-95D8-4A2E-A0C0-CFF54237462B}` AppX execution | 0x10003208 | `AppXExecutionSvc\Server` | execution manager | 0, 1, 2, 4, 5 |
| `{4172BF6F-4E52-4B28-ADA9-4A03525074FD}` background worker | 0x100012C0 | `ExecManService\Server` | background worker manager | 0, 1, 2 |
| `{8EC21E98-B5CE-4916-A3D6-449FA428A007}` foreground task | 0x10003170 | `AppXExecutionSvc\Server` | foreground task manager | 0…16 |
| `{29269506-0DC0-44C8-AA1D-A479DCB0E885}` AIM | 0x100015E8 | `ExecManService\Server` | AIM proxy | 0…8 |
| `{8A04D20B-0FFB-445C-9B0B-D2DB9DFF9351}` debug | 0x100018B0 | `ExecManService\Server` | debug manager (0…7), debugger mux (8…10) | 0…10 |
| `{34144019-10CB-41F4-9C87-256036195174}` VoIP | 0x10001C98 | `ExecManService\Server` | VoIP task manager | 0…13 |
| `{A07F6818-376D-4C48-8DB3-FBFE8EEAE2F2}` background execution | 0x10003710 | `ExecManService\Server` | background execution manager | 9…12 |
| `{6F64B095-4A1C-4BD8-865A-2CA9556C8FAB}` resource manager | 0x10002078 | `ExecManService\Server` | resource manager object | 0…19 |
| `{2C7FD9CE-E706-4B40-B412-953107EF9BB0}` | 0x100026D0 | `ResourceManagerRPC` | resource manager object | none |
| `{B1EF227E-DFA5-421E-82BB-67A6A129C496}` AppX resource manager | 0x100033D8 | `AppXExecutionSvc\Server` | AppX resource manager object | 0…10 |

Parameters of the procedures not given in the sections above (from the format strings; `GUID` = 16-byte structure by value, `wchar_t *` = `[in,string]`, `byte[]` = `[unique,size_is]` conformant byte array):

| Interface | Opnum | Parameters |
|-----------|-------|------------|
| Foreground task | 0 | `wchar_t *`, `wchar_t *` (the two channel names) |
| | 1 | `wchar_t *`, `long`, `byte[]`, `long`, `[out] long` |
| | 2 | `long`, `enum`, `long` |
| | 3, 4 | `long` |
| | 5 | `long`, `[unique] wchar_t *` |
| | 6 | `long`, `[out] long` |
| | 7 | `long`, `enum` |
| | 8 | `wchar_t *`, `[in,out] byte[]`, `long`, `[in,out] long *` (size; the wrapper `sub_10004DEC` updates it) |
| | 9 | `GUID`, `wchar_t *`, `[out] long` |
| | 10 | none |
| | 11 | `long`, `enum` |
| | 12 | `[out] long` |
| | 13 | `long`, `enum`, `wchar_t *`, `wchar_t *`, `long`, `[out] long` |
| | 14 | `long`, `[out] long` |
| | 15 | `long`, `long`, `[out] long` |
| | 16 | `long`, `enum`, `[out] long` |
| Resource manager | 1 | `long` |
| | 2 | `[out]` conformant structure, `[out]` structure |
| | 3 | `long`, `[out] long` |
| | 4 | `long`, `[out] long`, `[out]` 8-byte structure |
| | 5 | `long`, `long`, `[in,out] byte[]`, `[in,out] long *` |
| | 6 | `long` |
| | 7, 14 | `[out] long` |
| | 8, 11, 18 | none |
| | 9, 10 | `long`, `enum`, `byte[]`, `long` |
| | 12 | `long`, `[in,out,unique] enum *` |
| | 13 | `long`, `enum` |
| | 15 | `long`, `[out] long` |
| | 16 | `[out]` 0x18-byte structure (6 `long`) |
| | 17 | `[out]` array, `[in,out] long *` (count) |
| | 19 | `wchar_t *` |
| AppX resource manager | 0, 1 | `long`, `[out] long` |
| | 2, 9 | `[out] long` |
| | 3 | `long`, `[in,out] long *`, `long`, `[in,out] byte[]` |
| | 4, 5, 6 | `wchar_t *`, `[in,out] long *`, `long`, `[in,out] byte[]` |
| | 7 | `wchar_t *` |
| | 8 | `long` |
| | 10 | none |

`enum` is `FC_ENUM16` (0x0D) in the format strings. The procedures with the same parameters as another (for example foreground 3 and 4) can't be told apart without the server.

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\System\AIM` (`KEY_READ`) | `DefaultLatencyRequirement` (`REG_DWORD`) | Default latency of the AIM proxy (180 000 if absent), passed by its slot 8 |

### ETW

No provider is registered: `EventWrite` is called with a NULL `REGHANDLE`, and the enable flag (bit 1 of `dword_1000C280`) is never set, so these events are never written. The code is still there: `sub_100091E4` writes the descriptor at 0x10003AE0 (event 10001, version 0, level 4, keyword 0x200000) with two fields, the function name (`DevPlat::Shared::BindToRPCServer` or `DevPlat::Shared::BuildSecurityDescriptorFromId`) and the failed HRESULT.
