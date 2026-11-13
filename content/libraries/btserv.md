## BtServ.dll

The Background Transfer Service (BTS) of Windows Phone 8.1: the system service that runs the HTTP downloads and uploads handed over by applications (`BackgroundTransferRequest`) and their background agents. "Bts" stands for Background Transfer Service, not Bluetooth.  
`BtServ.dll` is a C++ svchost service DLL (531 functions, the database has its full symbols, source `src\comms\product\services\backgroundtransfer\server\dll\btserv.cpp`, PDB `btserv.pdb`), registered as the `BtServ` service (`BTSERV`). It's the RPC server of the two interfaces used by [BtsCli.dll](./btscli.md): transfer requests `{EDA02478-D508-46E2-B742-1ACB85AFB609}` and service control `{60916721-C841-46FA-9834-6B6E1E2DCB57}`. Each request is stored in an ESE database (`btserv.vol`), checked against per-application quotas, and given to the download manager of the Zune Media Framework ("EDM", `Zmf_Client.dll`), which does the HTTP work. The service follows the battery saver and AC state (WNF), the network connectivity (`CommsNetworkHelperUtil`) and the foreground application (told by `BtsProxy`) to pause, resume and change the policy of the transfers; it retries failed transfers with Task Scheduler timers, moves the downloaded file to the application's file (shared file tokens, `dsclient`), publishes the final state in a WNF state chosen by the client, and stops itself when no request is left.  
The client side is [BtsCli.dll](./btscli.md); the callers of `BtsCli` (the `BackgroundTransferRequest` API and the execution model that hosts `BtsProxy`), `Zmf_Client.dll` and `BackupRecoverUtil.exe` aren't documented here; the Task Scheduler service is [TaskSchedulerSvc.dll](./taskschedulersvc.md).

Location on the phone: `C:\Windows\System32\BtServ.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4 | `RpcServerUseProtseqW`, `RpcServerRegisterIf3`, `RpcServerUnregisterIfEx`, `RpcServerInqBindings`, `RpcEpRegisterW`, `RpcEpUnregister`, `RpcBindingVectorFree`, `RpcServerInqCallAttributesW`, `RpcImpersonateClient`, `RpcRevertToSelf`, `NdrServerCall2`, `NdrAsyncServerCall`, `RpcAsyncCompleteCall`, `RpcAsyncAbortCall`, `RpcServerSubscribeForNotification`, `RpcServerUnsubscribeForNotification`, `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingFree`, `NdrClientCall2`, `UuidCreate`, `I_RpcExceptionFilter` |
| Zmf_Client (delay-load) | `ZmfClientInitialize`, `ZmfClientShutdown`, `DownloadManagerCreate`, `DownloadManagerCreateUpload`, `DownloadManagerStart`, `DownloadManagerCancel`, `DownloadManagerRelease`, `DownloadManagerUpdatePolicy`, `DownloadManagerQueryDwordProperty`, `DownloadManagerQueryStringProperty`, `DownloadManagerBeginBatchingBackgroundTransfers`, `DownloadManagerEndBatchingBackgroundTransfers`, `ZCacheRemoveEntry` |
| ZTrace (delay-load) | `ZTraceInit`, `ZTraceClose` |
| ESENT (delay-load) | `JetCreateInstanceA`, `JetSetSystemParameterA/W`, `JetGetSystemParameterW`, `JetInit2`, `JetTerm2`, `JetBeginSessionA`, `JetEndSession`, `JetCreateDatabaseW`, `JetAttachDatabaseW`, `JetDetachDatabaseA/W`, `JetOpenDatabaseW`, `JetCloseDatabase`, `JetCreateTableColumnIndexA`, `JetOpenTableA`, `JetCloseTable`, `JetGetTableColumnInfoA`, `JetBeginTransaction`, `JetCommitTransaction(2)`, `JetRollback`, `JetPrepareUpdate`, `JetSetColumns`, `JetUpdate`, `JetDelete`, `JetRetrieveColumn`, `JetEnumerateColumns`, `JetSetCurrentIndexA`, `JetMakeKey`, `JetSeek`, `JetMove`, `JetGotoBookmark`, `JetGetErrorInfoW` |
| CommsPlatformHelperUtil | `DefaultMakeHresultFromJetError`, `JetReallocMethod`, `FreeEnumColumn` |
| CommsNetworkHelperUtil | `CreateConnAPI`, `IsDpuStateSatisfied` |
| EMSVCS | `CreateExecutionManager`, `CreateAIMProxy` |
| dsclient | `DSCopyFromSharedFile`, `DSMoveToSharedFile`, `DSGetSharingTokenOwner`, `DSRemoveSharingToken`, `DSFreeString` |
| [SecRuntime](./secruntime.md) | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor`, `GetChamberSid` |
| unistore | `GetUSDeviceStoreFolderPath` |
| WPCOREUTIL | `SHGetKnownFolderPath`, `RecursiveCreateDirectory`, `RecursiveRemoveDirectoryEx` |
| ntdll | `RtlQueryWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlPublishWnfStateData`, `NtQueryWnfStateNameInformation`, `RtlNtStatusToDosError`, `WinSqmStartSession`, `WinSqmEndSession`, `WinSqmIncrementDWORD`, `WinSqmAddToAverageDWORD` |
| api-ms-win-service-core-l1-1-1, api-ms-win-service-private-l1-1-1 | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus`, `I_QueryTagInformation` |
| api-ms-win-core-registry-l1-1-0, -l2-1-0 | `RegGetValueW`, `RegOpenKeyExW`, `RegCreateKeyExW`, `RegSetValueExW`, `RegQueryValueExW`, `RegDeleteKeyW`, `RegCloseKey` |
| api-ms-win-core-file-l1-2-1, -l2-1-1, shlwapi-legacy | `CreateDirectoryW`, `DeleteFileW`, `GetFileAttributesExW`, `FindFirstFileW`, `FindNextFileW`, `FindClose`, `MoveFileExW`, `PathFileExistsW` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateProcessW`, `OpenThreadToken`, `GetCurrentThread`, `GetCurrentThreadId`, `GetCurrentProcessId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-threadpool-l1-2-0, -legacy | `CreateThreadpoolCleanupGroup`, `CloseThreadpoolCleanupGroup(Members)`, `CreateThreadpoolWork`, `SubmitThreadpoolWork`, `CloseThreadpoolWork`, `CreateThreadpoolWait`, `SetThreadpoolWait`, `CloseThreadpoolWait`, `UnregisterWaitEx` |
| api-ms-win-core-synch-l1-2-0, handle | `InitializeSRWLock`, `Acquire/ReleaseSRWLockExclusive/Shared`, `InitializeCriticalSection(Ex)`, `Enter/LeaveCriticalSection`, `DeleteCriticalSection`, `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `CreateMutexW`, `ReleaseMutex`, `Sleep`, `CloseHandle` |
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance`, `CLSIDFromString`, `CoTaskMemFree`, `CoFreeUnusedLibrariesEx` |
| other api-ms-win-core sets | `GetLocalTime`, `GetTickCount64`, `LocalAlloc`, `LocalFree`, `ConvertSidToStringSidW`, `EventRegister`, `EventUnregister`, `EventWrite`, `DisableThreadLibraryCalls`, `GetLastError`, `SetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `DelayLoadFailureHook`, `ResolveDelayLoadedAPI` |
| msvcrt, rtlsupport | C runtime (`malloc`, `free`, `memcpy`, `_wcsicmp`, `_wcsupr`, `_vsnwprintf`, `_initterm`, `__CxxFrameHandler3`, …), `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |

The msvcrt, rtlsupport, `TerminateProcess` / `GetCurrentProcess`, exception filter and delay-load helper imports are the Visual C++ DLL CRT, C++ exception, `/GS` and delay-load code. The ESE wrappers (`CommsESE_*`), the `CommsEDB*` recovery functions (`src\comms\product\utils\recoveredb\commsedbwrapper\*.cpp`) and `ServiceBase` are static libraries shared with other Comms services.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `Zmf_Client.dll` (not analysed) | Delay-load | Download manager doing the HTTP transfers ([HTTP provider](#http-provider)) |
| `ZTrace.dll` (not analysed) | Delay-load | `ZTraceInit` / `ZTraceClose` around the HTTP provider |
| `ESENT.dll` | Delay-load | Request store ([Request store](#request-store)) |
| `%LocalAppData%\BTSERV\Store\btserv.vol` (and the ESE logs in the same folder, base name `BTS`) | `JetCreateDatabaseW` / `JetAttachDatabaseW` | Persisted requests; `%LocalAppData%` of the service account (`SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_CREATE)`) |
| `%LocalAppData%\BTSERV\Upload\` | `CreateDirectoryW`, `DSCopyFromSharedFile` | Private copy of each file to upload ([Uploads](#uploads)) |
| Application files (destination of a download, source and response file of an upload) | Shared file tokens: `DSGetSharingTokenOwner`, `DSCopyFromSharedFile`, `DSMoveToSharedFile`, `DSRemoveSharingToken` | Created and shared by [BtsCli.dll](./btscli.md#transfer-parameters) with the name `BTSERV`; the service never sees the paths |
| ZMF cache entry `0bb73f43-cb03-40ff-a911-57b108972264<…>` | `DownloadManagerQueryStringProperty`, `ZCacheRemoveEntry` | Downloaded file before it's moved to the application ([HTTP provider](#http-provider)) |
| `\Windows\System32\BackupRecoverUtil.exe` (not analysed) | `CreateProcessW(L"\"%s\" %s")` with `Backup`, `Recover`, `Restore`, `RpsRestore`, `Reboot`, `ScheduleReboot`, `RetailDemoModeRestore`, … | ESE volume backup / recovery ([Recovery](#ese-recovery)) |
| Unified store folder (`GetUSDeviceStoreFolderPath`) and a known folder (`SHGetKnownFolderPath`) | `MoveFileExW`, `RecursiveRemoveDirectoryEx`, `RecursiveCreateDirectory` | Destination of a corrupted volume (`%s\%s`, `%X`) in `ReplaceVolume` |
| Task Scheduler service ([TaskSchedulerSvc.dll](./taskschedulersvc.md#rpc)), interface `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` v2.0 | RPC client ([Timers](#timers)) | Retry and self-stop timers (same interface as [WPTimeSvc.dll](./wptimesvc.md)) |
| PacMan server [pacmanserver.dll](./pacmanserver.md), CLSID `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` | `CoCreateInstance(…, CLSCTX_ALL, {698D57C2-292D-4CF3-B73C-D95A6922ED9A})` (`IPMEnumerationManager`) | Application of the caller ([Creating a request](#creating-a-request)) |
| Execution manager, application instance manager (`EMSVCS`) | `CreateExecutionManager`, `CreateAIMProxy` | Foreground application, application of the caller, agent notifications |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `ServiceMain` | 0x10004F60 | `DWORD argc, LPWSTR *argv` |
| 2 | `SvchostPushServiceGlobals` | 0x10004F4C | `SVCHOST_GLOBAL_DATA *` (kept at 0x100180B0, `g_Bts`+0x90; its method at +0x60 registers the stop callback) |

`ServiceMain` sets the flag `g_Bts`+0x131 when `argc == 2` and `argv[1]` is `BTS_AIM_PROXY_START` (the argument given by [BtsProxy](./btscli.md#btsproxy)), then calls `ServiceBase::ServiceMain`.

The whole service is the global `g_Bts` (`BackgroundTransferService`, derived from `ServiceBase`, 0x10018090). Fields used in this page:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 0x40 | Service name (copy of `argv[0]`) |
| 0x44 | 4 | Service status handle |
| 0x48 | 4 | Stop event (`ServiceBase`) |
| 0x6C, 0x70, 0x74 | 4 each | `ServiceBase` state: running, stop requested, stopped by system shutdown / preshutdown |
| 0x90 | 4 | Svchost globals |
| 0x94, 0x98 | 4 each | `MaxRequestsPerInRomApp`, `MaxRequestsPerThirdPartyApp` |
| 0x9C | 1 | RPC server started |
| 0xA0 | 0xC | List of the `IBackgroundTransferRequest` objects (+0xA8 count) |
| 0xB0 | 0x10 | `BtsSrwLock` protecting the list and the counters |
| 0xC0 | 4 | `IBackgroundTransferServiceHttpProvider *` |
| 0xC4 | 4 | Last AC state (`ePowerState` 4 AC / 8 battery, 16 = unknown) |
| 0xC8 | 4 | Last battery saver state (1 off / 2 on, 16 = unknown) |
| 0xD0 | 0x10 | `BtsSrwLock` of the power state |
| 0xE0 | 4 | `EventCallbackCookies *`: the two WNF subscriptions and two `IConnAPI` / `ConnectivityCallback` pairs |
| 0xE8, 0xEC | 4 each | `MaxTotalRequestsForInRomApps`, `MaxTotalRequestsForThirdPartyApps` |
| 0xF0, 0xF4 | 4 each | `MaxRetries`, `InitialRetryIntervalSecs` |
| 0xF8, 0xFC | 4 each | Current number of requests of in-ROM / third-party applications |
| 0x100 | 4 | `MaxNoConnectivityRetries` |
| 0x104 | 4 | `IApplicationInstanceManagerProxy *` (`CreateAIMProxy`) |
| 0x10C | 4 | `IBtsPersistenceStore *` |
| 0x110, 0x114 | 4 each | Upload limits (smaller of the two settings, `MaxUploadFileSizeAcWifiBytes`) |
| 0x118 | 4 | `MinProgressNotifyMsecs` |
| 0x11C, 0x120 | 4 each | `MaxNonACTransferSizeBytesThirdParty`, `MaxNonACTransferSizeBytesInRom` |
| 0x124 | 4 | `%LocalAppData%\BTSERV\Upload` |
| 0x128 | 1 | Stopping (set by `OnStopping`) |
| 0x12C | 4 | `SelfStopCallback *` |
| 0x130 | 1 | `DisableSelfStop` |
| 0x131 | 1 | Started with `BTS_AIM_PROXY_START` |
| 0x134, 0x138 | 4 each | WNF change stamps (AC online, battery saver) |
| 0x140 | 0x10 | `BtsSrwLock` + foreground product ID (0x150, GUID) |
| 0x160 | 0x14 | Hash map service name → service tag ([HTTP provider](#http-provider)) |
| 0x174 | 4 | Self-stop delay in seconds (`SelfStopTimeoutMin` × 60) |

### Startup

`_DllMainCRTStartup` (0x10015788): CRT, with the global constructors: `g_Bts` (registers the `ServiceBase` ETW provider), `_AtlModule` / `_AtlComModule`, the `RecoverEdb` ETW provider, `s_csGlobalCS`. `DllMain` (0x10004E4C): on `DLL_PROCESS_ATTACH`, `DisableThreadLibraryCalls`, registers the BTS ETW provider, `WinSqmStartSession(g_WpSqmGlobalSession {C6CF0920-A353-48C5-82D0-0640C6F09D94}, 9, 0)`; on detach, `WinSqmEndSession` and unregisters the provider.

`ServiceBase::ServiceMain` (0x100135F0) copies the service name, `RegisterServiceCtrlHandlerExW(name, _ServiceCtrlHandler, &g_Bts)`, then `_ServiceMainInner` (0x10013814):
1. Fails with `E_NOTIMPL` if `SvchostPushServiceGlobals` wasn't called.
2. If the key `HKLM\System\CurrentControlSet\Services\BtServ\Parameters\Settings\Shutdown` exists, refuses to start (0x8007045B `ERROR_SHUTDOWN_IN_PROGRESS`).
3. Creates the stop event, status `SERVICE_START_PENDING`, `OnStarting`, status `SERVICE_RUNNING`, `OnStarted`, then registers the stop callback through the svchost globals and `CoFreeUnusedLibrariesEx(30000)`.

`_ServiceCtrlHandler` (0x10013474): `SERVICE_CONTROL_STOP` (1), `SHUTDOWN` (5) and `PRESHUTDOWN` (15) set the stop flags, status `SERVICE_STOP_PENDING` and the stop event; `INTERROGATE` returns 0; codes 0x80–0xFF and the other ones < 0x80 go to virtual methods (not overridden: the service only accepts `SERVICE_ACCEPT_PRESHUTDOWN`, `GetControlsAccepted` returns 0x100). `ServiceStop` (0x1001371C) calls `OnStopping`, creates the `Shutdown` key when the stop came from a system shutdown, and sets `SERVICE_STOPPED`.

`OnStarting` (0x10004F9C): creates the thread-pool cleanup group used for all the work items, then `_Initialize` (0x100050E8):
1. Default settings (see [Registry](#registry)).
2. `RtlQueryWnfStateData` of `WNF_OS_BATTERY_SAVINGS_STATE` and `WNF_OS_BATTERY_AC_ONLINE` with the two callbacks of [Power](#power-and-connectivity), to get their current value and change stamp.
3. `_StartRpcServer` ([RPC server](#rpc-server)); ETW event 7.

`OnStarted` (0x10005040): when started with `BTS_AIM_PROXY_START`, sleeps `StartDelaySecs` (default 45 s); then `_AsyncInitializeWorker`.

### _AsyncInitializeWorker (0x10006D00)

Run once, under the lock 0xB0; also called by the RPC functions that need the service ready (creation, enumeration), so the first client doesn't wait for `OnStarted`:
1. `_CreateUploadDirectory`: `%LocalAppData%\BTSERV` and `%LocalAppData%\BTSERV\Upload`.
2. `_InitializeSettings` (0x10007308): reads the settings ([Registry](#registry)); the per-application limit is ignored (defaults used) when it isn't smaller than the total.
3. Creates the HTTP provider (`CComObject<BackgroundTransferServiceHttpProvider>`, 0x30 bytes) and its `Initialize` (event, lock, `ZTraceInit`).
4. `_InitializeDeviceStateNotifications` (0x10007180): subscribes to the two WNF states ([Power](#power-and-connectivity)), creates two `IConnAPI` (`CreateConnAPI`) and registers a `ConnectivityCallback` on each (method 3 with 1 and with 4).
5. `BtsOpenPersistenceStore` ([Request store](#request-store)), then `_CreateAllRequestsAndEnqueue` (0x10006858): every persisted request is created again (`_CreateRequestAndEnqueue` → `CreateTransferRequest`) and enqueued; a request that can't be restored is deleted, with its file tokens (`DSRemoveSharingToken`) and its upload copy (`DeleteFileW`).
6. `CreateAIMProxy` (kept at +0x104) and a call on it; `CreateExecutionManager`, then the foreground application (`0x8004020C` = none → `GUID_NULL`) → `SetForegroundAppProductId`.
7. `_AttemptInitiateSelfStop` ([Self-stop](#self-stop)); ETW event 26.

### RPC server

`_StartRpcServer` (0x1000DA8C):
1. `QueryTransientObjectSecurityDescriptor(8, L"DefaultRpcAccess")` → `RpcServerUseProtseqW(L"ncalrpc", 1234, sd)` (dynamic endpoint).
2. `QueryTransientObjectSecurityDescriptor(9, L"BtsMgmt\\Interface")` → `RpcServerRegisterIf3(BtsMgmt, NULL, NULL, RPC_IF_AUTOLISTEN | RPC_IF_ALLOW_SECURE_ONLY | RPC_IF_ALLOW_LOCAL_ONLY (0x29), RPC_C_LISTEN_MAX_CALLS_DEFAULT, 0, _RpcSecurityCallback, sd)`.
3. Same with `L"Bts\\Interface"` for the request interface.
4. `_RegisterUnregisterEndpoint(TRUE)`: `RpcServerInqBindings`, `RpcEpRegisterW` of both interfaces (that's how [BtsCli.dll](./btscli.md#rpc) finds the endpoint from the interface).

`_RpcSecurityCallback` (0x1000DE28): `RpcServerInqCallAttributesW`; the call is accepted only over `ncalrpc` (protocol sequence 3) with `RPC_C_AUTHN_LEVEL_PKT_PRIVACY` (6) and `RPC_C_AUTHN_WINNT` (10), else `E_ACCESSDENIED`.

Interface `{EDA02478-D508-46E2-B742-1ACB85AFB609}` version 1.0 (`RPC_SERVER_INTERFACE` 0x10001870), the requests:

| Opnum | Server routine | Address | Action |
|-------|----------------|---------|--------|
| 0 | `BtsRpcCreateBackgroundTransferRequest` | 0x1000D54C | `RpcServerInqCallAttributesW`, then [CreateTransferRequest](#creating-a-request); returns a `BTS_REQUEST_HANDLE` context handle (an `IBackgroundTransferRequest` reference) |
| 1 | `BtsRpcCloseBackgroundTransferRequest` | 0x1000D660 | Releases the context handle (the request keeps running) |
| 2 | `BtsRpcQueryBackgroundTransferRequestStatus` | 0x1000D67C | Copies the 28-byte [BtsRequestStatus](#btsrequeststatus) |
| 3 | `BtsRpcCancelBackgroundTransferRequest` | 0x1000D6AC | `_CancelTransferRequest` under the list lock, then cancels the transfer; HRESULT also in `[out] long` |
| 4 | `BtsRpcEnumBackgroundTransferRequests` | 0x1000D768 | `EnumTransferRequests` (0x10005D68): the names of the requests whose application ID is the caller's chamber SID, in one `LocalAlloc` block (`count`, pointer to entries of 8 bytes, names stored at the end) |
| 5 | `BtsRpcEnqueueBackgroundTransferRequest` | 0x1000D7EC | `_PersistRequestAndEnqueue` with the new parameters |
| 6 | `BtsRpcOpenBackgroundTransferRequestNotifyHandle` | 0x1000D8A0 | New `BTS_NOTIFY_HANDLE` referencing the request |
| 7 | `BtsRpcCloseBackgroundTransferRequestNotifyHandle` | 0x1000D92C | Releases it |
| 8 | `BtsRpcNotifyBackgroundTransferRequestStatus` | 0x1000D94C | Asynchronous (`NdrAsyncServerCall`): the `RPC_ASYNC_STATE` is kept by the request (`NotifyTransferRequestStatus`, vtable +0x44) and completed when the status differs from the one given by the client ([Notifications](#notifications)) |
| 9 | `BtsRpcQueryBackgroundTransferRequestParameters` | 0x1000DA1C | Copy of the [BtsTransferParams](#btstransferparams) |

`BTS_REQUEST_HANDLE_rundown` (0x1000DA60) and `BTS_NOTIFY_HANDLE_rundown` (0x1000DA74) release the references when a client dies.

Interface `{60916721-C841-46FA-9834-6B6E1E2DCB57}` version 1.0 (`RPC_SERVER_INTERFACE` 0x100017F0), service control by [BtsProxy](./btscli.md#btsproxy):

| Opnum | Server routine | Address | Action |
|-------|----------------|---------|--------|
| 0 | `BtsRpcAimTerminating` | 0x1000DF48 | Returns `E_NOTIMPL` |
| 1 | `BtsRpcGetServicePid` | 0x1000DF14 | `GetCurrentProcessId()` |
| 2 | `BtsRpcCancelApplicationRequests` | 0x1000DF58 | `CancelTransfers(productId)`: cancels every request of the product |
| 3 | `BtsRpcDisableApplicationRequests` | 0x1000DF90 | `PauseTransfers(TRUE, TRUE, 0, AC state, saver state, productId)` |
| 4 | `BtsRpcEnableApplicationRequests` | 0x1000E01C | `ResumeTransfers(AC state, saver state, productId, state 4, …, reason 6)` |
| 5 | `BtsRpcNotifyForegroundAppStateChange` | 0x1000E0A4 | State 1 (foreground): `SetForegroundAppProductId(productId)`, `UpdateTransfers(productId, TRUE, …)` and `ResumeTransfers`; state 2: foreground = `GUID_NULL`, `UpdateTransfers(productId, FALSE, …)`; other states `E_INVALIDARG` |

### Creating a request

`BackgroundTransferService::CreateTransferRequest(name, disposition, binding, params, &appId, …, &request, …)` (0x100055D4):
1. Checks the arguments (`E_INVALIDARG`); `BtsUtils::GetRpcClientSid` (0x1000FF20): `RpcImpersonateClient`, `OpenThreadToken`, `GetChamberSid` and `ConvertSidToStringSidW`: the application ID of a request is the string SID of the caller's chamber. Then `_AsyncInitializeWorker`; ETW event 24.
2. Disposition 1: looks for an existing request with this name and application ID (shared lock); fails with 0x801882C2 if parameters are given, 0x801882D6 when the service is stopping. Other dispositions, under the exclusive lock: an existing request with disposition 2 gives `HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS)`; `ERROR_NOT_FOUND` goes on to the creation. The meaning of the dispositions is inferred from these branches.
3. `_CheckApplicationQuotaExceeded` (0x10007F84): number of requests of the application = per-app limit → 0x801882C1; total = global limit → 0x801882CD (ETW event 16). In-ROM and third-party applications have separate limits.
4. `BtsAutoNotifyAim::NotifyAim` (0x1000ADD0): with `CreateExecutionManager` and the PacMan server (`CoCreateInstance(CLSID_PMSvc, CLSCTX_ALL, {698D57C2-…})`, then `{2925390A-D947-4062-9DAD-CF6F60E6A707}` `IPMApplicationInfo2`, see [pacmanserver.dll](./pacmanserver.md#com-server)), finds the product ID of the application and whether it's in ROM, and tells the application instance manager that a background request exists (ETW event 44; the destructor reports the end, event 45). A refused application gives `E_ACCESSDENIED`.
5. `CreateAndInitializeComObject<BackgroundTransferRequest>` (`Initialize` 0x10008320: name, application ID, product ID, in-ROM flag).
6. With parameters: `_PersistRequestAndEnqueue` (0x100075D8): `_ValidateTransferParams` (0x10009398: strings, sizes, `_ValidateTransferFileTokenOwner`: `DSGetSharingTokenOwner` of each token must match the caller, `NtQueryWnfStateNameInformation` on the WNF state name: `ERROR_NOT_FOUND` if it doesn't exist), `CopyUploadFile` for an upload, `IBtsPersistenceStore::CreatePersistedRequest`, then `EnqueueTransferRequest`. `_CreateServiceNameTagMap` builds the service tag map the first time a request uses data attribution type 2.
7. `_SetBootStart(TRUE)` (0x10006748): creates `…\BtServ\Parameters\Settings\Restart` with `Start = 1`, so that [BtsProxy](./btscli.md#btsproxy) starts the service again at the next boot; cancels the pending self-stop; adds the request to the list and increments the counter of its application type.
8. SQM: `WinSqmIncrementDWORD` of the data points 0x56E and 0x570; ETW event 25.

The request (`BackgroundTransferRequest`, a COM object behind `IBackgroundTransferRequest`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x0C | 4 | Name (`ce::RCStringBasic`) |
| 0x10 | 0x10 | `BtsSrwLock` |
| 0x20 | 0x1C | [BtsRequestStatus](#btsrequeststatus) |
| 0x3C | 4 | Application ID (chamber SID string) |
| 0x44 | 0xC | List of the pending notification calls |
| 0x50 | 4 | [BtsTransferParams](#btstransferparams) * (`LocalAlloc`) |
| 0x58 | 4 | `IBtsPersistedRequest *` |
| 0x5C | 4 | Retry count |
| 0x68 | 8 | Tick count of the start (SQM durations) |
| 0x84 | 0x10 | Product ID |

`_CancelTransferRequest` (0x10007A20, list lock held): cancels the request (vtable +0x40), removes it from the list and decrements the counter of its application type; when no request is left, `_SetBootStart(FALSE)` deletes the `Restart` key and the [self-stop](#self-stop) timer is started. The application instance manager is notified for requests with a product ID.

### BtsTransferParams

64 bytes, the same structure as on the client side ([BtsCli.dll](./btscli.md#transfer-parameters)); the field names come from the columns they're stored in ([Request store](#request-store)):

| Offset | Size | Column | Comment |
|--------|------|--------|---------|
| 0x00 | 4 | `Uri` | `wchar_t *` |
| 0x04 | 4 | `Verb` | 1 = download, 2 = upload (`DownloadManagerCreateUpload`) |
| 0x08 | 4 | `UserData` | `wchar_t *`, optional |
| 0x0C | 4 | `Headers` | Number of header strings |
| 0x10 | 4 | `Headers` | `wchar_t **` headers; stored as `count, (byte length, UTF-16 text)…` |
| 0x14 | 4 | `File` | Destination file of a download / response file of an upload (path given by the client) |
| 0x18 | 4 | `UploadFile` | File to upload |
| 0x1C | 4 | `Flags` | Bit 1: transfer only on external power ([Power](#power-and-connectivity)); bit 0: Wi-Fi only ? (policy 1035 / 1033 in [UpdateTransferPolicy](#http-provider)) |
| 0x20 | 4 | `FileToken` | Shared file token of 0x14 |
| 0x24 | 4 | `UploadFileToken` | Shared file token of 0x18 |
| 0x28 | 4 | `WnfStateName` | Size of the WNF state name (must be 8) |
| 0x2C | 4 | `WnfStateName` | `WNF_STATE_NAME *` published when the request completes ([Notifications](#notifications)) |
| 0x30 | 4 | `ConnectionDpuState` | `_BtsConnectionDataPlanUsageState` (1…5), mapped to a `CM_DATA_PLAN_USAGE_STATE` by `BtsEdmDpuStateMapping` |
| 0x34 | 4 | `DataAttributionType` | 0 none, 1 GUID, 2 service name |
| 0x38 | 4 | `TransferOriginatorId` | `GUID *` (type 1) or `wchar_t *` service name (type 2): who the data usage is charged to |
| 0x3C | 4 | `CertificateSearchCriteria` | `wchar_t *` |

### BtsRequestStatus

28 bytes, at +0x20 of the request, returned by opnum 2:

| Offset | Size | Column | Comment |
|--------|------|--------|---------|
| 0x00 | 4 | `State` | `_BtsRequestState`: 2 transferring, 3 waiting (paused, retry or conditions not met), 5 completed (final, published in the WNF state); others ? |
| 0x04 | 4 | `TotalBytes` | |
| 0x08 | 4 | `TotalUploadBytes` | |
| 0x0C | 4 | `CurrentBytes` | Stored as 0 while 0x10 is set |
| 0x10 | 4 | — | Upload phase flag (`SetUploadingFlagCurrentBytes`) |
| 0x14 | 4 | `HResult` | Result of the transfer |
| 0x18 | 4 | `Status` | HTTP status |

### HTTP provider

`BackgroundTransferServiceHttpProvider` (`IBackgroundTransferServiceHttpProvider` + `IZDownloadCallback`) turns a request into an EDM download:

- `EnqueueTransferRequest(params, request, …, &downloadId)` (0x1000EADC): cache name `0bb73f43-cb03-40ff-a911-57b108972264` + suffix, flags 0x1011042 (0x1011442 when the application isn't in the foreground ?), `BTS_TASK_GUID` and `BTS_DEFAULT_PRODUCTID` when the request has no product ID, DPU state through `BtsEdmDpuStateMapping`, service tag for attribution type 2 (`GetServiceTagFromName`, from `I_QueryTagInformation(NULL, 3, …)`, names upper-cased); `ZmfClientInitialize`, `DownloadManagerCreate` (download) or `DownloadManagerCreateUpload` (upload), `DownloadManagerStart`. ETW event 105.
- `Progress` (0x1000F108): updates `CurrentBytes` / `TotalBytes`, at most every `MinProgressNotifyMsecs`; cancels the transfer (`DownloadManagerCancel`, event 104) when it goes beyond the non-AC size limit while on battery (`MaxNonACTransferSizeBytesThirdParty` / `…InRom`). SQM average 0x571.
- `Notify` (0x1000F334): `_DM_NOTIFICATION` 2 / 3 → request method +0x68 with TRUE / FALSE (event 103).
- `Complete(downloadId, hr, stream, httpStatus)` (0x1000F410): maps the EDM errors with `EdmBtsErrorMap` (0x805A2019 / 0x805A2020 handled apart, unknown errors → 0x801882CB), `DownloadManagerQueryDwordProperty`, updates the request (`_UpdateProviderTransferRequestState`), event 102.
- `IsTransientError(hr, httpStatus, &retry)` (0x1000F800): HTTP 500–599 and two BTS codes are transient (event 108).
- `UpdateTransferPolicy(downloadId, wifiOnly, dpu, foreground)` (0x1000F9F8): `DownloadManagerUpdatePolicy(id, 1035 / 1033 / 1034, dpu)`.
- `BeginBatchTransfers` / `EndBatchTransfers` (`DownloadManagerBeginBatchingBackgroundTransfers` / `End…`), used by `ResumeTransfers` around a batch of resumes.
- `RemoveCacheFile(name)` (0x1000F910): `ZCacheRemoveEntry`.

When a request ends (`_UpdateProviderTransferRequestState`, 0x100095C0): a failure without connectivity is retried up to `MaxNoConnectivityRetries` (then 0x801882D1, event 33); a transient error schedules a retry ([Timers](#timers)) while `RetryCount < MaxRetries` (state 3, 0x1882CF); otherwise state 5: the status is persisted, a successful download is moved to the application (`_MoveTransferFileToAppStore`, 0x1000A38C: `DownloadManagerQueryStringProperty` gives the cache file, `DSMoveToSharedFile` to the `FileToken`, event 34), SQM counters (data point 1391: kilobytes transferred), the WNF state of the request is published ([Notifications](#notifications)), event 9.

### Uploads

`CopyUploadFile` (0x10009074): `DSCopyFromSharedFile(UploadFileToken, %LocalAppData%\BTSERV\Upload\<name>)`, `GetFileAttributesExW`; a file bigger than `MaxUploadFileSizeAcWifiBytes` is rejected with 0x801882D0 (the same limit as in [BtsCli.dll](./btscli.md#transfer-parameters)). Event 32. The copy is deleted with the request (`BtsAutoDeleteFile`).

### Notifications

Opnum 8 is kept pending until the status changes: `NotifyTransferRequestStatus` (0x10008898) stores the `RPC_ASYNC_STATE` and subscribes to the client leaving (`RpcServerSubscribeForNotification`, `BtsRpcNotifyClientLeaveCallback` 0x1000DEB8 → `NotifyClientLeave`, work item `_NotifyClientLeaveCallback`, `RpcAsyncAbortCall`). When the status changes, `_NotifyRpcClientTransferStatus` / `_ReplyNotificationRequest` build the `BtsRequestNotificationParams` (`_GetNotificationParameters`, 0x1000990C) and `RpcAsyncCompleteCall` (events 38, 41–43). This is the other side of `BtsNotificationInfo` in [BtsCli.dll](./btscli.md#notifications).

When the request reaches its final state and its parameters have a WNF state name, `RtlPublishWnfStateData(name, NULL, &status.State, 4, NULL)`: the 4-byte state (5) is written to the WNF state chosen by the client, so that an application that isn't running can be told of the end of its transfer.

### Power and connectivity

| Callback | Source | Action |
|----------|--------|--------|
| `_PowerLevelCallback` (0x10007E44) | `WNF_OS_BATTERY_SAVINGS_STATE`, 4 bytes | 1 → `ProcessPowerCallback(2)`, 0 → `ProcessPowerCallback(1)`; called without context by the initial `RtlQueryWnfStateData`, it only stores the state |
| `_PowerChargingCallback` (0x10007ED0) | `WNF_OS_BATTERY_AC_ONLINE`, 4 bytes | 0 → `ProcessPowerCallback(4)`, other values → `(8)` (same rule as above for the initial query). The code treats 4 as external power, so 0 meaning "on AC" looks inverted: not checked on the phone |
| `ConnectivityCallback::Callback` (0x100081D8) | `IConnAPI` states 1 and 8 | `ResumeTransfers(…, state 3, reason 5)` |

`ProcessPowerCallback(ePowerState)` (0x10007D00), under the lock 0xD0, event 36:
- 2 (battery saver on): `PauseTransfers(TRUE, FALSE, 0x1882D4, …)` of every request;
- 1 (saver off) after 2: `ResumeTransfers(…, state 3, reason 1)`;
- 4 (AC) after 8: `ResumeTransfers(…, state 3, reason 2)`;
- 8 (battery) after 4: `PauseTransfers(FALSE, …)`: each request checks its conditions.

`_TransferConditionsSatisfied` (0x100049E0): a request can run if (flag 0x2 is clear or the phone is on AC) and (the phone is on AC or the battery saver is off); otherwise it waits with 0x1882D4 (battery saver) or 0x1882C5 (waiting for external power). Event 48.

`OnStopping` (0x10004BB4, event 54) sets the stopping flag and calls `_Terminate` (0x100052A4): terminates each request, unregisters both interfaces and their endpoints, flushes the store, releases the WNF / connectivity subscriptions, pauses all transfers with 0x1882D5, terminates the HTTP provider and the self-stop timer; event 23.

### Timers

`TaskSchedulerEvents` (used by `RetryCallback` and `SelfStopCallback`) implements a one-shot timer with the Task Scheduler service:
1. `TaskSchedulerInit` (0x1000FC68): `RpcBindingCreateW` with the template `TaskScheduler_Template` (0x10018060: version 1, `RPC_PROTSEQ_LRPC`, no address, no endpoint), `RPC_C_AUTHN_LEVEL_PKT_PRIVACY`, `RPC_C_AUTHN_WINNT`, QoS version 5 with `ServerSecurityDescriptor = QueryTransientObjectSecurityDescriptor(9, L"ITaskSchedulerSvcRpc\\Server")`), then `RpcBindingBind`, retried up to 3 times every 500 ms on `RPC_S_SERVER_UNAVAILABLE` (1722), `RPC_S_NO_ENDPOINT_FOUND` (1708), `RPC_S_UNKNOWN_IF` (1717), `EPT_S_NOT_REGISTERED` (1753).
2. Creates the event `Global\BTS_TaskScheduler_Event<n>` (`<n>` a 64-bit counter, another one tried on `ERROR_ALREADY_EXISTS`), a schedule GUID (`UuidCreate`) and the schedule name `BTS_TaskScheduler_Schedule<n>`, start time from `GetLocalTime` + delay. The callers give the delay in seconds and pass it in minutes (a delay that isn't a multiple of 60 s is only logged).
3. Opnum 0 creates the schedule; a thread-pool wait on the event calls `TaskSchedulerCallback::Callback` (event 50). `Terminate` deletes the schedule with opnum 1 (events 58, 59).

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `TaskSchedulerCreateSchedule` (0x1000FD8C) | `TaskSchedulerEvents::_CreateSchedule` | binding, `[in] _TASK_SCHEDULE *`, `[in] long` | Create the timer schedule |
| 1 | `TaskSchedulerDeleteSchedule` (0x1000FDF0) | `TaskSchedulerEvents::_DeleteSchedule` | binding, `[in] GUID *` | Delete it |

Retry (`_ScheduleRetry`, 0x1000A6E8; `RetryCallback::Callback`, 0x1000ABFC): delay `InitialRetryIntervalSecs`, then `ResumeTransferOnRetry` with the current power state (events 12, 35).

### Self-stop

`_AttemptInitiateSelfStop` (0x10007C7C): when there's no request and `DisableSelfStop` is 0, creates a `SelfStopCallback` with the delay `SelfStopTimeoutMin` × 60 s (default 600 s). `SelfStopCallback::Callback` (0x1000B2D8): if still no request, `_ServiceCtrlHandler(SERVICE_CONTROL_STOP)` (event 52). A new request cancels the timer.

### Request store

`BtsOpenPersistenceStore` (0x10010130) → `BtsPersistenceStore::FinalConstruct` (0x100102A0): `GetBtsStoreVolumePath` gives `%LocalAppData%\BTSERV\Store` and `btserv.vol`; `CreateDirectoryW`, then `EseVolume::_Initialize`:
1. `JetCreateInstanceA`, system parameters (paths in the store folder, base name `BTS`, others not decoded), `JetInit2`; a fatal initialisation error triggers the recovery and `JetTerm2`.
2. `JetBeginSessionA`, `JetAttachDatabaseW(btserv.vol)`; if the attach fails with 0x80070002 (file not found), `_CreateVolume`: `JetCreateDatabaseW` and `_CreateTable` (`JetCreateTableColumnIndexA` of `BTS_REQUESTS_STORE`, 26 columns, 2 indexes).
3. `OpenTable` of the two indexes: `ByRowId` (`+RowId`, primary) and `ByReqId` (`+AppIdType +AppId +RequestId`, unique).

`BTS_REQUESTS_STORE` (column table 0x10002210; the property ID of a column is its index):

| ID | Column | JET type | Max size |
|----|--------|----------|----------|
| 0 | `RowId` | Long (autoincrement) | 4 |
| 1 | `RequestId` | Text | 0x80 |
| 2 | `AppIdType` | UnsignedLong | 4 |
| 3 | `AppId` | LongText | 0x200 |
| 4–9 | `State`, `TotalBytes`, `TotalUploadBytes`, `CurrentBytes`, `Status`, `HResult` | UnsignedLong | 4 |
| 10 | `Uri` | LongText | 0x1000 |
| 11 | `Verb` | UnsignedLong | 4 |
| 12 | `Headers` | LongText | 0x3C000 |
| 13 | `File` | LongText | 0x208 |
| 14 | `Flags` | UnsignedLong | 4 |
| 15 | `UserData` | LongText | 0x1F40 |
| 16 | `FileToken` | Text | 0x4E |
| 17 | `UploadFile` | LongText | 0x208 |
| 18 | `UploadFileToken` | Text | 0x4E |
| 19 | `RetryCount` | UnsignedLong | 4 |
| 20 | `ProductId` | Binary | 0x10 |
| 21 | `WnfStateName` | Binary | 0x10 |
| 22 | `ConnectionDpuState` | UnsignedLong | 4 |
| 23 | `DataAttributionType` | UnsignedLong | 4 |
| 24 | `TransferOriginatorId` | LongBinary | 0x200 |
| 25 | `CertificateSearchCriteria` | LongText | 0x100 |

`BtsPersistedRequest` reads and writes them as `_SQLCEPROPVAL` (`GetPropsFromTransferParams` 0x10011F34, `GetPropsFromRequestStatus` 0x10011E98, `GetTransferParamsFromProps` 0x100122F8).

### ESE recovery

Every ESE call goes through `ShouldTriggerRecovery` (`JetGetErrorInfoW`): on a corruption error, `GetCommsVolumeTypeFromBaseName` (`BTS`, `USS`, …), `TriggerRecovery` and `LaunchBackupRecoverUtil` (0x100149FC: `CreateProcessW` of `"\Windows\System32\BackupRecoverUtil.exe" <command>`). `RestoreVolume` / `ReplaceVolume` move the corrupted volume away (`MoveFileExW` to a folder under the unified store path) and recreate the folder. The state is shared between the Comms services through the mutex `CommsEDBWrapper_f5305a3c-baa9-4a31-977b-0b48fbcb8464` and the registry ([Registry](#registry)).

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x41C61D22A3BC4075 `WNF_OS_BATTERY_SAVINGS_STATE` (`.text:0x10002DE0`) | `OS`, 8 | 4 bytes: 1 = battery saver on | Queried at start, subscribed; `_PowerLevelCallback` |
| 0x41C61D22A3BC2875 `WNF_OS_BATTERY_AC_ONLINE` (`.text:0x10002DE8`) | `OS`, 5 | 4 bytes: 0 → `ePowerState` 4 (external power), other → 8 | Queried at start, subscribed; `_PowerChargingCallback` |
| Name given by the client (`BtsTransferParams`+0x2C) | — | 4 bytes: request state | Checked with `NtQueryWnfStateNameInformation`, published when the request completes |

### ETW

Provider `Microsoft-WindowsPhone-Comms-BackgroundTransferService` `{C80A2212-526F-4B48-B6B4-6DD27B01F322}` (`WM_COMMS_BTS_PUBLISHER`), registered in `DllMain`. All events have version 0, channel 0, opcode 0, task 0. Enable bits seen in the code: 0x1 errors created, 0x2 errors propagated, 0x4 level-4 service events, 0x8 level-2 events, 0x10 level-5 service events, 0x20 level-4 HTTP events, 0x80 level-5 HTTP events.

| Event | Level | Keyword | Written when |
|-------|-------|---------|--------------|
| 1 `CommsErrorOriginateEvent` / 2 `CommsErrorPropagateEvent` | 2 / 3 | 0x1 / 0x400000000000 | `Log_HREvent` (HRESULT, file, line) |
| 7 `Started`, 23 `Stopped`, 54 `External_Stop`, 26 `AsyncInit_Success` | 4 | 0x4 | Service life cycle |
| 13, 22, 57 `Initial_Settings*` | 4 | 0x4 | Settings read |
| 8 `State_Change`, 9 `Transfer_Complete`, 14 `Request_Persisted`, 15 `Request_Deleted`, 18 `Request_Enqueue`, 24 `Create_Params`, 25 `Create_Success`, 27 `Request_Canceled`, 28–31 `Request_Pausing/Paused/Resuming/Resumed`, 32 `UploadFile_Copied`, 33 `Request_NoConnectivity_Limit`, 34 `MoveFile_To_Store`, 37 `Update_Status` | 4 | 0x4 | Request life cycle |
| 16 `Request_Limit_Reached`, 17 `Request_Create_Failed` | 2 | 0x5 | Quota / creation failure |
| 19 `Boot_Start`, 20, 21, 55 `Read_From_Store_*`, 56 `Foreground_ProductId` | 4 | 0x4 | `Restart` key, store, foreground |
| 11 `Connectivity_Notification`, 36 `Power_Callback`, 48 `Power_Condition` | 4 | 0x4 | Device state |
| 12 `Retry_Callback`, 35 `Schedule_Retry`, 51–53 `SelfStop_*`, 58, 59 `SelfStop_Delet*_Schedule` | 4 | 0x4 | Timers |
| 38–43 `Send/Register/Leave/Pending_Abort/Abort_Notification`, `Send_Notification2` | 4 | 0x4 | Opnum 8 |
| 44, 45 `Notify_Aim_Create/Complete` | 4 | 0x4 | Application instance manager |
| 46 `Request_Destroyed`, 47 `Retry_Callback_Destroyed`, 49, 50 `TaskEvent_Destroyed/Created` | 5 | 0x4 | Destructors |
| 101–105, 107, 108, 110–112 `Comms_BtsHttp_*` | 4 | 0x8 | HTTP provider |
| 106 `Comms_BtsHttp_Zero_Total_Bytes` | 3 | 0x400000000008 | Transfer without size |
| 109 `Comms_BtsHttp_EDM_Context_Destroyed` | 5 | 0x8 | EDM context released |

Other providers: `ServiceBase` `{7816CB46-9F5E-40BB-A1EB-5C42719F9338}` (events 3 error, 4 starting, 5 started, 6 shutting down, 7 control handler) and `Microsoft-WindowsPhone-Comms-RecoverEdb` `{2E65F68E-5BFF-4E7B-8A78-A4AAD36CB91B}` (200 `Data_Purge`, 201 `GetRecoveryCounters`).

### Registry

| Key (HKLM) | Value | Use |
|------------|-------|-----|
| `System\CurrentControlSet\Services\BtServ\Parameters\Settings` | `MaxRequestsPerInRomApp` (100), `MaxTotalRequestsForInRomApps` (5000), `MaxRequestsPerThirdPartyApp` (25), `MaxTotalRequestsForThirdPartyApps` (2500) | Quotas |
| same | `MaxRetries` (3), `InitialRetryIntervalSecs` (60), `MaxNoConnectivityRetries` (10) | Retries |
| same | `MaxUploadFileSizeBytes` (5 MB), `MaxUploadFileSizeAcWifiBytes` (100 MB), `MaxNonACTransferSizeBytesThirdParty` (100 MB), `MaxNonACTransferSizeBytesInRom` (500 MB) | Size limits |
| same | `MinProgressNotifyMsecs` (1000), `StartDelaySecs` (45), `DisableSelfStop` (0), `SelfStopTimeoutMin` (10) | Behaviour |
| `…\BtServ\Parameters\Settings\Restart` | `Start` = 1 | Written while requests exist; deleted when the last one ends ([BtsProxy](./btscli.md#btsproxy) reads it) |
| `…\BtServ\Parameters\Settings\Shutdown` | (key) | Created when stopped by a system shutdown; the service refuses to start while it exists |
| `Software\Microsoft\CommsEDBRecovery` | `State` (`REG_BINARY`, 20 bytes: recovery counters) | ESE recovery |
| `Software\Microsoft\CommsEDBRecovery\CommsVolumeMounted`, `…\RecoveryActive` | (keys) | First mount, recovery in progress |
| `Software\Microsoft\CommsEDBRecovery\UTHooks` | `RestoreCount`, `BackupCount`, `RecoveryTriggeredCount`, …, `TestHookDialog*` | Test counters |

The settings are read with `RegGetValueW(RRF_RT_REG_DWORD | RRF_ZEROONFAILURE)`; a missing value keeps the default (in parentheses), and for some settings a sentinel value (0 or 0xFFFFFFFF) also keeps it.

### HRESULTs

Codes of facility 0x18 seen in the service (meaning from the context):

| HRESULT | Meaning |
|---------|---------|
| 0x001882C0 | Request canceled |
| 0x801882C1 / 0x801882CD | Per-application / total request quota reached |
| 0x801882C2 | Request already exists (creation with disposition 1 and parameters) |
| 0x001882C5 | Waiting for external power |
| 0x801882C7 / 0x801882C8 / 0x801882CE | Pause / resume / cancel of at least one request failed |
| 0x801882CB | Unknown EDM error |
| 0x001882CF | Retry scheduled |
| 0x801882D0 | Upload file too big |
| 0x801882D1 | Too many retries without connectivity |
| 0x001882D4 | Paused by the battery saver |
| 0x001882D5 | Paused because the service stops |
| 0x801882D6 | Service stopping |
