## BtsCli.dll

The client library of the Background Transfer Service (BTS) of Windows Phone 8.1: the HTTP downloads and uploads that applications (`BackgroundTransferRequest`) and their background agents hand over to the system. "Bts" stands for Background Transfer Service, not Bluetooth.  
`BtsCli.dll` is a C++ DLL (226 functions, the database has its full symbols, source `src\comms\product\services\backgroundtransfer\client\dll\btscli.cpp`, PDB `btscli.pdb`). It's a local RPC client of the `BTSERV` service: it creates, enqueues, queries, cancels, enumerates and closes transfer requests (interface `{EDA02478-D508-46E2-B742-1ACB85AFB609}`), and turns the asynchronous RPC call of the service into status callbacks. Before a request is sent, it shares the files of the transfer with the service through shared file tokens (`dsclient`) and checks the size of an upload against the limits in the registry. When it runs inside a background task host, it holds the notifications while the host is paused (`EMCLIENT` pause/resume callbacks). It also contains the COM class `BtsProxy` (`IBackgroundServiceProxy`), which the execution model uses to control the service: it starts `BTSERV`, forwards cancel / disable / enable of an application's requests, and reports the foreground application (taken from the navigation server's broker session manager and the PacMan server) to the service (second interface `{60916721-C841-46FA-9834-6B6E1E2DCB57}`).  
The callers of the `Bts*` exports and the host of `BtsProxy` aren't documented here. The service is [BtServ.dll](./btserv.md), registered as `BtServ`.

Location on the phone: `C:\Windows\System32\BtsCli.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4 | `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcStringFreeW`, `RpcBindingSetAuthInfoExW`, `RpcBindingFree`, `NdrClientCall2`, `NdrAsyncClientCall`, `RpcAsyncInitializeHandle`, `RpcAsyncCompleteCall`, `RpcAsyncCancelCall`, `RpcSsDestroyClientContext`, `RpcExceptionFilter`, `I_RpcExceptionFilter` |
| CommsPlatformHelperUtil | `StartAndWaitForService`, `Comms::IsActiveDebugger` |
| EMCLIENT | `GetTaskInstanceIDs`, `RegisterPausingHostCallback`, `DeregisterPausingHostCallback`, `RegisterResumedHostCallback`, `DeregisterResumedHostCallback` |
| dsclient | `DSCreateSharedFileToken`, `DSRemoveSharingToken`, `DSFreeString` |
| CoreMessaging, CoreUIComponents | `CoreUICreate`, `CoreUIFactoryCreate`, `MsgRelease` |
| api-ms-win-core-com-l1-1-1, OLEAUT32 | `CoInitializeEx`, `CoUninitialize`, `CoCreateInstance`, `CoCreateFreeThreadedMarshaler`, `SysAllocStringLen`, `SysFreeString`, `SysStringLen` |
| ntdll, api-ms-win-security-sddl-l1-1-0 | `RtlInitUnicodeString`, `RtlCreateServiceSid`, `ConvertSidToStringSidW`, `ConvertStringSecurityDescriptorToSecurityDescriptorW` |
| api-ms-win-core-registry-l1-1-0 | `RegGetValueW` |
| api-ms-win-core-file-l1-2-1, api-ms-win-core-handle-l1-1-0 | `GetFileAttributesW`, `GetFileAttributesExW`, `CreateFileW`, `WriteFile`, `CloseHandle` |
| api-ms-win-core-synch-l1-2-0, api-ms-win-core-kernel32-legacy-l1-1-1 | `InitializeSRWLock`, `AcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`, `InitializeCriticalSection(Ex)`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`, `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `WaitForMultipleObjects`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateThread`, `GetCurrentThreadId`, `GetThreadId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-heap-obsolete-l1-1-0 | `LocalAlloc`, `LocalFree` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-libraryloader-l1-2-0 | `DisableThreadLibraryCalls` |
| msvcrt, rtlsupport, errorhandling, debug | C runtime (`malloc`, `free`, `memcpy`, `memset`, `_vsnwprintf`, `_initterm`, `__CxxFrameHandler3`, …), `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `DebugBreak` |

The msvcrt, rtlsupport, `TerminateProcess` / `GetCurrentProcess`, exception filter and debug imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` code; `RaiseException` is `AtlThrow`. `CoreUICreate`, the critical sections, `GetThreadId` and part of the events belong to the `Execution::ExecutionServices` worker thread (`src\appplat\src\execution\executionservices\executionservices.cpp`) linked in for the foreground listener. `Comms::IsActiveDebugger` and the exception filters are used by the `Comms::LaunchRpcCall<…>` wrappers, which call each RPC stub inside an RPC exception handler.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `BTSERV` service ([BtServ.dll](./btserv.md)) | `StartAndWaitForService(L"BTSERV", …)`, then RPC `ncalrpc` with a dynamic endpoint ([RPC](#rpc)) | The Background Transfer Service itself |
| Destination file of a download, source (and response) file of an upload | `GetFileAttributesW`, `CreateFileW(CREATE_NEW)` + `WriteFile` of 0 bytes, `GetFileAttributesExW`, then `DSCreateSharedFileToken` ([Transfer parameters](#transfer-parameters)) | Shared with the `BTSERV` service as a token instead of a path |
| PacMan server [pacmanserver.dll](./pacmanserver.md), CLSID `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` (`CLSID_PMSvc`) | `CoCreateInstance(…, CLSCTX_ALL (0x17), {D83400E1-A7A6-4990-9B84-10490AFF2063})` (`IPMEnumerationManager2`) | Product ID of the foreground application ([Foreground listener](#foreground-listener)) |
| Message proxy `System\NavigationServer_BrokerSessionManager` | `CoreUIFactoryCreate` + factory method 5 (CoreMessaging) | Foreground application changes ([Foreground listener](#foreground-listener)); the server isn't documented here |

No DLL is loaded at run time and no process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `BtsCreateBackgroundTransferRequest` | 0x100032E4 | `LPCWSTR name, _BtsRequestCreationDisposition disposition, const BtsTransferParams *params` (optional), `BtsClientRequest **request` |
| 6 | `BtsEnqueueBackgroundTransferRequest` | 0x1000374C | `BtsClientRequest *request, const BtsTransferParams *params` |
| 3 | `BtsQueryBackgroundTransferRequestStatus` | 0x10003548 | `BtsClientRequest *request, BtsRequestStatus *status` (filled by the call) |
| 9 | `BtsQueryBackgroundTransferRequestParameters` | 0x10003A0C | `BtsClientRequest *request, BtsTransferParams **params` (freed with `BtsApiFree`) |
| 7 | `BtsNotifyBackgroundTransferRequestStatus` | 0x1000383C | `BtsClientRequest *request, IBtsRequestStatusNotificationCallback *callback` |
| 4 | `BtsCancelBackgroundTransferRequest` | 0x100035A8 | `BtsClientRequest *request` |
| 2 | `BtsCloseBackgroundTransferRequest` | 0x1000345C | `BtsClientRequest *request` |
| 5 | `BtsEnumBackgroundTransferRequests` | 0x10003608 | `BtsRequestEnum **requests` (freed with `BtsApiFree`) |
| 8 | `BtsApiFree` | 0x10004D7C | `void *` (`LocalFree`; the RPC buffers are allocated by `MIDL_user_allocate` = `LocalAlloc(LMEM_ZEROINIT)`) |
| 10 | `DllCanUnloadNow` | 0x10004D90 | ATL |
| 11 | `DllGetClassObject` | 0x10004DB0 | ATL class factory of `BtsProxy` only ([BtsProxy](#btsproxy)) |

The `Bts*` functions return an HRESULT; a NULL argument gives `E_INVALIDARG`. Every error is logged with the ETW events 1 / 2 ([ETW](#etw)).

`BtsClientRequest`, the handle returned to the caller (8 bytes, `operator new`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | RPC context handle of the request (opnum 0), closed by opnum 1 in the destructor (`RpcSsDestroyClientContext` if the call fails) |
| 0x04 | 4 | `BtsNotificationInfo *` (COM reference), set by `BtsNotifyBackgroundTransferRequestStatus` ([Notifications](#notifications)) |

The RPC binding is global (`_AtlModule`, the `BackgroundTransferServiceClient` ATL module):

| Address | Comment |
|---------|---------|
| 0x1000A308 | SRW lock (`BtsSrwLock`: the lock and the owner thread) protecting the three fields below |
| 0x1000A318 | RPC binding handle to `BTSERV` |
| 0x1000A31C | Reference count of the binding (`Initialize` / `Terminate`) |
| 0x1000A320 | `BtsAutoRegisterPauseResume *`, only inside a task host ([Task host](#task-host)) |

### Startup

`_DllMainCRTStartup` (0x10008D74): CRT, with the ATL module constructors (`_AtlModule`, `_AtlComModule`, object map with `BtsProxy`). `DllMain` (0x100032AC): on `DLL_PROCESS_ATTACH` registers the ETW provider (`McGenEventRegister`), calls `DisableThreadLibraryCalls`, and fails the load if the ATL initialisation failed; on `DLL_PROCESS_DETACH` unregisters the provider.

There is no initialisation export: the binding is opened by the exports that need it and released when the last user is gone.

### BackgroundTransferServiceClient::Initialize (0x10003B24)

`Initialize(HANDLE *binding, BOOL proxy, BOOL startService)`, under the global lock:

1. If the binding already exists, increments its reference count and returns it.
2. If `startService`: `StartAndWaitForService(L"BTSERV", 0, 30000 ms, argc, argv, 0)`, with one argument `L"BTS_AIM_PROXY_START"` when called by [BtsProxy](#btsproxy), none otherwise.
3. `GetTaskInstanceIDs(NULL, &count)` (EMCLIENT): if the process is a task host (count ≠ 0), creates a `BtsAutoRegisterPauseResume` object ([Task host](#task-host)).
4. `RpcStringBindingComposeW(NULL, L"ncalrpc", NULL, NULL, NULL)` (no endpoint: resolved from the interface), `RpcBindingFromStringBindingW`.
5. Builds the security descriptor `D:(A;;GR;;;<SID>)` from the service SID of `BTSERV` (`RtlCreateServiceSid`, `ConvertSidToStringSidW`, `ConvertStringSecurityDescriptorToSecurityDescriptorW`), then `RpcBindingSetAuthInfoExW(binding, NULL, RPC_C_AUTHN_LEVEL_PKT_PRIVACY (6), RPC_C_AUTHN_WINNT (10), NULL, 0, &qos)` with an `RPC_SECURITY_QOS_V5` (version 5, no capabilities, static identity tracking, `RPC_C_IMP_LEVEL_IDENTIFY` (2), `ServerSecurityDescriptor` = this descriptor): the server must run as the `BTSERV` service.
6. Stores the binding and the pause/resume object, reference count = 1.

`Terminate` (0x10003ED8) decrements the count; at 0 it frees the binding (`RpcBindingFree`) and the pause/resume object.

### Creating and using a request

`BtsCreateBackgroundTransferRequest(name, disposition, params, &request)`:
1. Allocates the `BtsClientRequest`, converts `params` ([Transfer parameters](#transfer-parameters)), `Initialize(&binding, FALSE, TRUE)` (starts the service).
2. `BtsClientRequest::CreateBackgroundTransferRequest` (0x100041A8): `CheckTaskHost` (0x10003F50) reads the task instance IDs; inside a task host the last ID is passed to the service, NULL otherwise. RPC opnum 0 `(binding, name, disposition, params, taskInstanceId, &contextHandle)`.
3. If the call fails with `EPT_S_NOT_REGISTERED` (0x800706D9), `RPC_S_SERVER_UNAVAILABLE` (0x800706BA), `RPC_S_CALL_FAILED` (0x800706BE), `RPC_S_CALL_FAILED_DNE` (0x800706BF), `RPC_S_UNKNOWN_IF` (0x800706B5) or 0x801882D6, it starts `BTSERV` again (`StartAndWaitForService`, 30 s) and retries, two attempts in all.
4. On success: ETW event 20, the request is returned and the binding kept (released by `BtsCloseBackgroundTransferRequest`). On failure the binding is released and the file tokens removed (`DSRemoveSharingToken`).

The other exports use the context handle of the request:

| Export | RPC | Notes |
|--------|-----|-------|
| `BtsEnqueueBackgroundTransferRequest` | opnum 5 | Converts `params` like the creation (new file tokens) |
| `BtsQueryBackgroundTransferRequestStatus` | opnum 2 | `BtsRequestStatus` filled in place |
| `BtsQueryBackgroundTransferRequestParameters` | opnum 9 | Buffer allocated by the stub, freed on error |
| `BtsCancelBackgroundTransferRequest` | opnum 3 | Returns the HRESULT given by the service (`[out] long`) |
| `BtsCloseBackgroundTransferRequest` | opnum 7, opnum 1 | `BtsNotificationInfo::Cleanup`, ETW event 21, destructor of the request (event 29, opnum 1 and the release of the notification object, whose destructor calls opnum 7), `Terminate` |
| `BtsEnumBackgroundTransferRequests` | opnum 4 | Own binding reference (`Initialize(FALSE, TRUE)`), same retry as the creation |

### Transfer parameters

`BtsTransferParams` is 64 bytes; `BtsClientRequest::GetTransferParams` (0x10004338) copies it and replaces the paths by shared file tokens before it's sent to the service. Only the fields it reads are known:

| Offset | Size | Comment |
|--------|------|---------|
| 0x04 | 4 | Transfer type: 1 = download, 2 = upload (other values copied without file handling); column `Verb` in [BtServ.dll](./btserv.md#btstransferparams) |
| 0x0C | 4 | Number of strings at 0x10, at most 15 |
| 0x10 | 4 | Array of string pointers (HTTP headers ?), each shorter than 0x2000 characters |
| 0x14 | 4 | Download: destination file (required). Upload: response file (optional) |
| 0x18 | 4 | Upload: file to send |
| 0x1C | 4 | Flags; bits 0 and 1 are set when the upload is above `MaxUploadFileSizeBytes`. In [BtServ.dll](./btserv.md#btstransferparams), bit 1 = external power required, bit 0 = Wi-Fi only ? |
| 0x20 | 4 | Token of the file at 0x14; must be NULL from the caller |
| 0x24 | 4 | Token of the file at 0x18; must be NULL from the caller |

`_CreateFileToken(path, &size, &token)` (0x10004004): ETW event 22 with the path; if the file doesn't exist, creates it empty (`CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL)`, `WriteFile` of 0 bytes); otherwise, when the size is asked, reads `nFileSizeLow` with `GetFileAttributesExW`. Then `DSCreateSharedFileToken(path, &params, 1, 0, &token)` with `params = { 2, 0, 1, 1, L"BTSERV", … }` (compare with the `L"MobileUI"` token of [ShellChromeAPI.dll](./shellchromeapi.md#wallpaper)).

Upload size check: `MaxUploadFileSizeBytes` (default 0x500000, 5 MB) and `MaxUploadFileSizeAcWifiBytes` (default 0x6400000, 100 MB) are read from the registry ([Registry](#registry)). A file bigger than `MaxUploadFileSizeAcWifiBytes` is rejected with 0x801882D0; a file bigger than the smaller of the two limits gets flags 0x3.

### Notifications

`BtsNotifyBackgroundTransferRequestStatus(request, callback)` fails if the request already has a callback. It creates a `CComObject<BtsNotificationInfo>` (0x80 bytes), `CreateCanceledEvent` (inside a task host only), then `_NotifyTransferStatusWorker(request, callback, NULL)` (0x10004B90):

1. `RpcAsyncInitializeHandle`, notification type `RpcNotificationTypeCallback` (5), routine `BtsNotificationCallbackWrapper` (0x10003A88), user info = the object.
2. With a request: RPC opnum 6 opens a notification context handle from the request context handle (ETW event 26), and the callback is kept.
3. Asynchronous RPC opnum 8 (`NdrAsyncClientCall`, `_NotifyBackgroundTransferRequestStatus`, 0x100031D8): `[in]` the notification handle and the last status known by the client (NULL the first time), `[out]` a `BtsRequestNotificationParams *` written at +0x10. State = 1 (pending).

`BtsNotificationCallbackWrapper` (completion of opnum 8): inside a task host it first waits for the "resumed" event or the canceled event of the object ([Task host](#task-host)). Then `BtsNotificationInfo::NotifyCallback` (0x100045F4), under the object lock, ETW event 23:
- state 2 (being canceled): only sets the event that `Cleanup` waits for;
- otherwise state = 3, `RpcAsyncCompleteCall`; if the status in the returned parameters (+4) isn't 5 (final state ?), opnum 8 is called again with this status; then `ClientNotifyCallback` gives `(HRESULT, BtsRequestNotificationParams *)` to method 3 of the callback (vtable +0x0C). Outside a task host the callback runs in the RPC thread; inside one, a new thread (`_ClientNotifyThreadCallback`) runs it and is waited for. The parameters are freed with `LocalFree` after the callback.

`BtsNotificationInfo::Cleanup` (0x100047F4, from `BtsCloseBackgroundTransferRequest`; calling it from the callback thread is flagged): returns `E_INVALIDARG` if already canceling and nothing if no call is pending (state 3); otherwise ETW event 24, state = 2, sets the canceled event, `RpcAsyncCancelCall(FALSE)`, waits for the completion, `RpcAsyncCompleteCall` (ETW event 25; `RPC_S_CALL_CANCELLED` is a success).

`BtsNotificationInfo`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable (`CComObject<BtsNotificationInfo>`) |
| 0x04 | 4 | Reference count |
| 0x0C | 4 | Notification context handle (opnum 6), closed by opnum 7 in the destructor (ETW event 30) |
| 0x10 | 4 | `BtsRequestNotificationParams *` returned by opnum 8 |
| 0x14 | 4 | `IBtsRequestStatusNotificationCallback *` |
| 0x18 | 0x44 | `RPC_ASYNC_STATE` of opnum 8 |
| 0x60 | 0x10 | `BtsSrwLock` (lock, owner thread) |
| 0x70 | 4 | State: 1 call pending, 2 being canceled, 3 completed |
| 0x74 | 4 | Thread ID of the client callback in progress |
| 0x78 | 4 | Event set when the canceled call has completed |
| 0x7C | 4 | Canceled event (auto-reset, task host only) |

### Task host

When `GetTaskInstanceIDs` reports task instances (the DLL runs in a background agent host), `BtsAutoRegisterPauseResume::RegisterPauseResume` (0x10004F2C) creates a manual-reset event, signalled, and registers `RegisterPausingHostCallback(HostPauseNotification)` and `RegisterResumedHostCallback(HostResumeNotification, event)`. `HostPauseNotification` (0x10004ED4) resets the event (ETW event 27), `HostResumeNotification` (0x10004E7C) sets it (event 28). The status notifications are held until the host is resumed or the request is closed.

### BtsProxy

ATL COM class `BtsProxy`, CLSID `{3114E1FE-245D-4B36-9BC1-9F64A8DB45A9}`, only interface `IBackgroundServiceProxy` `{3EB353EC-F2FE-486D-8A30-8B410D537303}`. It's the proxy that the execution model uses to manage the background transfer service (the client of this class isn't known; `GetBackgroundServiceId` returns `ID_SCOPE` 9).

`FinalConstruct` (0x10006168): reads `Start` in `HKLM\System\CurrentControlSet\Services\BtServ\Parameters\Settings\Restart`; then `Initialize(&binding, TRUE, Start == 1)`: the service is started with the argument `BTS_AIM_PROXY_START` only when `Start` is 1 (missing value = don't start).

| Method | Address | Action |
|--------|---------|--------|
| `GetBackgroundServiceId(ID_SCOPE *)` | 0x10006244 | Returns 9 |
| `GetBackgroundServicePid(DWORD *)` | 0x10006274 | Proxy opnum 1: process ID of the service |
| `NotifyServiceStarted()` | 0x100062BC | Creates the [foreground listener](#foreground-listener) and connects it to the broker session manager |
| `NotifyServiceStopped()` | 0x10006448 | Unregisters and releases the foreground listener |
| `NotifyServiceTermination()` | 0x100064B0 | Proxy opnum 0 |
| `CancelApplicationRequests(const GUID *)` | 0x100064E0 | Proxy opnum 2 |
| `DisableApplicationRequests(const GUID *)` | 0x10006530 | Proxy opnum 3 |
| `EnableApplicationRequests(const GUID *)` | 0x10006580 | Proxy opnum 4 |
| `NotifyAgentRequestLaunched(const GUID *, DWORD)` | 0x100065D0 | `E_NOTIMPL` |
| `NotifyForegroundAppChange(const GUID *, FOREGROUNDAPP_STATE)` | 0x100065E0 | Proxy opnum 5 |

The GUIDs are product IDs of applications. Object fields: +0x10 binding, +0x14 foreground listener, +0x18 SRW lock.

### Foreground listener

`ModernForegroundChangeListener` (WRL, `FtmBase` + `IMessageProxyListener` `{01863EA3-981D-4590-9F5D-4D4A6A42E6B5}` ?, 0x44 bytes) tells the service which application is in the foreground:

1. `RuntimeClassInitialize(binding)` (0x100066D8): `CoCreateInstance(CLSID_PMSvc {B9E511FC-E364-497A-A121-B7B3612CEDCE}, CLSCTX_ALL, {D83400E1-A7A6-4990-9B84-10490AFF2063})` (PacMan), and starts an `ExecutionServices` worker thread (`SetupExecutionServices`, 0x100069D8).
2. `EnsureBrokerSessionManagerConnected` (0x10006B74) queues to the worker (`lambda_fb5b22…`, 0x10007774): `CoreUIFactoryCreate`, factory method 3 with `{804D0167-BA0B-43D2-BBED-B942093816BB}`, factory method 5 opens the message proxy `L"System\\NavigationServer_BrokerSessionManager"`, QueryInterface `{804D0167-…}`, then method 7 registers the listener. It waits up to 5 s for `OnConnected`.
3. `OnConnected` (0x10006CE4) sets the event, reads the current foreground application ID (methods 6 and 5 of the `{804D0167-…}` interface: a CoreMessaging string, inline or by pointer) and keeps its product ID.
4. `OnPropertyChanged(proxy, 3)` (0x10006E4C, other properties ignored): reads the new application ID, `GetProductIdFromAppId`; if the product changed, proxy opnum 5 with the previous product and state 2 (left the foreground) and with the new product and state 1 (foreground). The null GUID is never sent.

`GetProductIdFromAppId` (0x10007064): method 3 of the PacMan interface `{D83400E1-…}` with the application ID as a `BSTR`, QueryInterface `{50AFB58A-438C-4088-9789-F8C4899829C7}` (`IPMApplicationInfo`) on the result, method 3 of it returns the product GUID (0x8004020D when the interface is missing).

`UnRegisterForegroundChangeNotifications` (0x10006744) queues `lambda_1594a1…` (0x100068C8): method 8 of the proxy (unregisters the listener), releases the proxy, stops the worker thread (work item type 6, waits up to 60 s); the caller waits up to 5 s.

### RPC

Binding: `ncalrpc`, endpoint resolved from the interface, `RPC_C_AUTHN_LEVEL_PKT_PRIVACY`, `RPC_C_AUTHN_WINNT`, server checked against the `BTSERV` service SID (see [Initialize](#backgroundtransferserviceclientinitialize-0x10003b24)). Service started with `StartAndWaitForService(L"BTSERV")` before the first bind and after the RPC errors listed in [Creating and using a request](#creating-and-using-a-request).

Interface `{EDA02478-D508-46E2-B742-1ACB85AFB609}` version 1.0 (stub descriptor 0x10001450), transfer requests:

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `LaunchRpcCall<…_BtsRequestCreationDisposition…>` (0x100058B4) | `BtsClientRequest::CreateBackgroundTransferRequest` | binding, `[in] wchar_t *name`, `[in] enum16 disposition`, `[in] BtsTransferParams *`, `[in, unique ?] DWORD *taskInstanceId`, `[out] context handle` | Create the request |
| 1 | `RpcCloseBackgroundTransferRequest` (0x1000314C) | `BtsClientRequest` destructor | `[in, out] context handle` | Close the request |
| 2 | `LaunchRpcCall<…BtsRequestStatus…>` (0x1000556C) | `BtsQueryBackgroundTransferRequestStatus` | `[in] request handle`, `[out] BtsRequestStatus *` | Status |
| 3 | `LaunchRpcCall<…long…>` (0x10005694) | `BtsCancelBackgroundTransferRequest` | `[in] request handle`, `[out] long *hr` | Cancel |
| 4 | `LaunchRpcCall<…BtsRequestEnum…>` (0x10005820) | `BtsEnumBackgroundTransferRequests` | binding, `[out] BtsRequestEnum **` | List the requests |
| 5 | `LaunchRpcCall<…BtsTransferParams *…>` (0x10005728) | `BtsEnqueueBackgroundTransferRequest` | `[in] request handle`, `[in] BtsTransferParams *` | Enqueue |
| 6 | `LaunchRpcCall<…void **…>` (0x10005994) | `_NotifyTransferStatusWorker` | `[in] request handle`, `[out] notification context handle` | Open the notifications |
| 7 | `RpcCloseBackgroundTransferRequestNotifyHandle` (0x10003168) | `BtsNotificationInfo` destructor | `[in, out] notification handle` | Close the notifications |
| 8 | `_NotifyBackgroundTransferRequestStatus` (0x100031D8, asynchronous) | `_NotifyTransferStatusWorker` | `[in] notification handle`, `[in] BtsRequestStatus *` last known status, `[out] BtsRequestNotificationParams **` | Wait for the next status change |
| 9 | `LaunchRpcCall<…BtsTransferParams **…>` (0x10005600) | `BtsQueryBackgroundTransferRequestParameters` | `[in] request handle`, `[out] BtsTransferParams **` | Parameters |

Interface `{60916721-C841-46FA-9834-6B6E1E2DCB57}` version 1.0 (stub descriptor 0x100014A0), service control by [BtsProxy](#btsproxy), on the same binding:

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `LaunchRpcCall<void *, void *&>` (0x100075AC) | `NotifyServiceTermination` | binding | Service termination notice (`BtsRpcAimTerminating` in [BtServ.dll](./btserv.md#rpc-server) returns `E_NOTIMPL`) |
| 1 | `LaunchRpcCall<…unsigned long *…>` (0x10007518) | `GetBackgroundServicePid` | binding, `[out] DWORD *pid` | Process ID of the service |
| 2 | `RpcCancelApplicationRequests` (0x10003184) | `CancelApplicationRequests` | binding, `[in] GUID *productId` | Cancel the requests of an application |
| 3 | `RpcDisableApplicationRequests` (0x100031A0) | `DisableApplicationRequests` | binding, `[in] GUID *productId` | Disable them |
| 4 | `RpcEnableApplicationRequests` (0x100031BC) | `EnableApplicationRequests` | binding, `[in] GUID *productId` | Enable them |
| 5 | `LaunchRpcCall<…FOREGROUNDAPP_STATE>` (0x100076CC) | `NotifyForegroundAppChange`, `OnPropertyChanged` | binding, `[in] GUID *productId`, `[in] DWORD state` (1 foreground, 2 left the foreground) | Foreground application |

The server is [BtServ.dll](./btserv.md#rpc-server), which gives the layout of `BtsRequestStatus` ([BtsRequestStatus](./btserv.md#btsrequeststatus)), of the whole `BtsTransferParams` ([BtsTransferParams](./btserv.md#btstransferparams)) and of `BtsRequestEnum`; `BtsRequestNotificationParams` wasn't decoded.

### Registry

| Key (HKLM) | Value | Use |
|------------|-------|-----|
| `System\CurrentControlSet\Services\BtServ\Parameters\Settings` | `MaxUploadFileSizeBytes` (`REG_DWORD`, default 5 242 880) | Upload limit above which the request gets flags 0x3 |
| `System\CurrentControlSet\Services\BtServ\Parameters\Settings` | `MaxUploadFileSizeAcWifiBytes` (`REG_DWORD`, default 104 857 600) | Hard upload limit (0x801882D0 above it) |
| `System\CurrentControlSet\Services\BtServ\Parameters\Settings\Restart` | `Start` (`REG_DWORD`) | 1 = `BtsProxy` starts the service with `BTS_AIM_PROXY_START` |

Read with `RegGetValueW(RRF_RT_REG_DWORD | RRF_ZEROONFAILURE)`; a missing value or 0 keeps the default.

### ETW

Provider `Microsoft-WindowsPhone-Comms-BackgroundTransferServiceClient` `{3AAEAD8C-C647-49D7-BD04-548449A63644}` (`WM_COMMS_BTS_CLIENT_PUBLISHER`), registered in `DllMain`. All events have version 0, channel 0, opcode 0, task 0.

| Event | Level | Keyword | Enable bit | Written when |
|-------|-------|---------|------------|--------------|
| 1 `CommsErrorOriginateEvent` | 2 | 0x1 | 0x1 | An error is created (`Log_HREvent`: HRESULT, source file, line) |
| 2 `CommsErrorPropagateEvent` | 3 | 0x400000000000 | 0x2 | An error is passed on (same data) |
| 20 `Comms_BtsCli_Request_Created` | 4 | 0x4 | 0x4 | Request created |
| 21 `Comms_BtsCli_Request_Closed` | 4 | 0x4 | 0x4 | `BtsCloseBackgroundTransferRequest` |
| 22 `Comms_BtsCli_Creating_File` | 4 | 0x4 | 0x4 | `_CreateFileToken` (path) |
| 23 `Comms_BtsCli_Notify_Callback` | 4 | 0x4 | 0x4 | Completion of opnum 8 (object, state) |
| 24 `Comms_BtsCli_Notify_Cleanup` | 4 | 0x4 | 0x4 | `Cleanup` (object, state) |
| 25 `Comms_BtsCli_Notify_Canceled` | 4 | 0x4 | 0x4 | Opnum 8 canceled |
| 26 `Comms_BtsCli_Notify_Created` | 4 | 0x4 | 0x4 | Opnum 6 done (callback, object) |
| 27 `Comms_BtsCli_Pause_Notification` | 4 | 0x4 | 0x4 | Task host paused |
| 28 `Comms_BtsCli_Resume_Notification` | 4 | 0x4 | 0x4 | Task host resumed |
| 29 `Comms_BtsCli_Request_Destroyed` | 5 | 0x4 | 0x8 | Request destructor |
| 30 `Comms_BtsCli_Notify_Destroyed` | 5 | 0x4 | 0x8 | Notification object destructor |
