## CompServer.dll

The compositor server of Windows Phone 8.1: it runs in the shell process, combines the frames that the applications present into the image sent to the display, and handles screenshots, screen recording and the external display (Miracast / USB projection).  
`CompServer.dll` is a C++ DLL (628 functions, all named from the PDB `compserver.pdb`) with a single export, `InitializeCompositor`, called by [MobileUI.exe](../applications/mobileui.md#startup) at startup. The work is done by a `Compositor` singleton that plugs into the UIX render engine ("Splash", `UIXRender.dll`): `UIXRender!SpSetCompositorMode` gives the engine the compositor callbacks, and the engine then hands it its Direct3D 11 device and calls it for every frame ([Compositor](#compositor)). The compositor is the server side of [CompClient.dll](./compclient.md): an ALPC port `CompositorAlpcPort` in the `MobileUI` named object directory ([ALPC server](#alpc-server)), and for each window a shared "client map" section with two events, through which the client presents its buffers without any message ([Clients](#clients-and-presents)). The frame is drawn with Direct3D 11 (own precompiled shaders) and given to the display through the phone DXGI swap chain, with hardware overlay planes when the scaler can do it. The external display is driven by a topology manager (`SetDisplayConfig`, `VidStream.dll` for USB), and screen recording by `ScreenRecorderImpl.dll`.  
Related binaries not analysed: `UIXRender.dll`, `dwmmobile.dll` (`InitializeMinDWM`, foreground window), `CoreMessaging.dll` (window validator), `minuser.dll`, `ScreenRecorderImpl.dll`, `policymanager.dll`. [DWMCORE.DLL](./dwmcore.md) gives it the input hit test. [VidStream.dll](./vidstream.md) sends the USB mirroring frames.

Location on the phone: `C:\Windows\System32\CompServer.dll` ? (extracted with `CompClient.dll`, `DWMCORE.DLL`, `DWMAPI.DLL` and `DCOMP.DLL`).  

### Imports

| DLL | Functions |
|-----|-----------|
| UIXRender.dll | `SpSetCompositorMode`, `SpRegisterWaitHandler`, `SpUnregisterWaitHandler` |
| dwmmobile.dll | `InitializeMinDWM`, `IsHwndForeground`, `SetForegroundHwnd` |
| [DWMCORE.DLL](./dwmcore.md) | `WpInputHitTestRequest` |
| CoreMessaging.dll | `CoreUICreateWindowValidator` |
| [ShellChromeAPI.dll](./shellchromeapi.md) | `Shell_IdleTimerReset` |
| policymanager.dll | `PolicyManager_GetExperiencePolicy_AllowScreenCapture` |
| ScreenRecorderImpl.dll (delay-load) | `GetSR`, `GetSRFrameListener`, `DestroySR` |
| [SecRuntime.dll](./secruntime.md) | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor`, `BuildSecurityDescriptorForSharingAccess`, `CapabilityCheck`, `GetCapabilitySids` |
| ntdll.dll | `NtAlpcCreatePort`, `NtAlpcAcceptConnectPort`, `NtAlpcSendWaitReceivePort`, `NtAlpcCancelMessage`, `NtAlpcImpersonateClientOfPort`, `AlpcInitializeMessageAttribute`, `AlpcGetMessageAttribute`, `RtlGetAppContainerNamedObjectPath`, `RtlInitUnicodeString`, `RtlFreeUnicodeString`, `NtClose`, `WinSqmStartSession`, `WinSqmEndSession`, `WinSqmIncrementDWORD`, `WinSqmSetIfMaxDWORD` |
| ext-ms-win-rtcore-ntuser-sysparams-l1-1-0.dll (delay-load) | `SetDisplayConfig`, `QueryDisplayConfig`, `GetDisplayConfigBufferSizes`, `EnumDisplayDevicesW`, `EnumDisplaySettingsW` |
| ext-ms-win-ntuser-rectangle-ext-l1-1-0.dll (delay-load) | `IntersectRect`, `SetRect`, `SetRectEmpty`, `EqualRect`, `IsRectEmpty`, `PtInRect` |
| api-ms-win-devices-config-l1-1-1.dll | `CM_Register_Notification`, `CM_Unregister_Notification` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegNotifyChangeKeyValue`, `RegCloseKey` |
| api-ms-win-core-memory-l1-1-2.dll | `CreateFileMappingW`, `OpenFileMappingW`, `MapViewOfFile`, `UnmapViewOfFile` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `OpenEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep`, `InitOnceBeginInitialize`, `InitOnceComplete` |
| api-ms-win-core-file-l1-2-1.dll, api-ms-win-core-io-l1-1-1.dll | `CreateFileW`, `DeviceIoControl` ([Forced crash](#forced-crash)) |
| api-ms-win-core-libraryloader-l1-2-0.dll, api-ms-win-core-kernel32-legacy-l1-1-1.dll | `LoadLibraryExW`, `LoadLibraryW`, `GetProcAddress`, `FreeLibrary`, `FindResourceExW`, `LoadResource`, `LockResource`, `SizeofResource`, `DisableThreadLibraryCalls`, `GetModuleHandleExW`, `GetModuleFileNameA` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `SetThreadPriority`, `GetCurrentThread`, `GetCurrentThreadId`, `GetCurrentProcess`, `GetCurrentProcessId`, `OpenThreadToken`, `TerminateProcess` |
| api-ms-win-security-*.dll | `ConvertStringSidToSidW`, `RevertToSelf`, `GetAppContainerNamedObjectPath` |
| api-ms-win-core-threadpool-legacy-l1-1-0.dll | `CreateTimerQueueTimer`, `DeleteTimerQueueTimer` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetTickCount`, `GetTickCount64` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-heap-l1-2-0.dll, api-ms-win-core-heap-obsolete-l1-1-0.dll, api-ms-win-core-handle-l1-1-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapFree`, `LocalFree`, `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2.dll, api-ms-win-core-debug-l1-1-1.dll, api-ms-win-core-rtlsupport-l1-2-0.dll, api-ms-win-core-delayload-l1-1-1.dll | `GetLastError`, `SetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `DebugBreak`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memmove`, `memset`, `memcmp`, `ceilf`, `_vsnwprintf`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, delayload, errorhandling filters, `GetCurrentProcess` / `TerminateProcess` and `DebugBreak` imports are the Visual C++ DLL CRT startup, the delay-load helper and the `/GS` security cookie code. `GetModuleHandleExW`, `GetModuleFileNameA` and `InitOnce*` are the trace message helper (`EtwInitializeTraceMessaging`). Direct3D 11 and DXGI aren't imported: the compositor uses the `ID3D11Device` given by the render engine.

### Dependencies

Files and named objects used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `minuser.dll` | `LoadLibraryExW`, `GetProcAddress` of `RegisterSessionProcess`, `RegisterSessionWorkerThread`, `SetNavigationServiceSid` ([InitializeCompositor](#initializecompositor-0x10017dc4)), `ModerncoreCreateSystemThreads` ([CreateSystemThreads](#alpc-requests)) | Registers the shell process with the window manager |
| `gdi32.dll` | `LoadLibraryExW`, `D3DKMTSetProcessSchedulingPriorityClass` | GPU scheduling priority of the process (class 5, realtime ?) |
| `api-ms-win-rtcore-session-l1-1-0.dll` | `LoadLibraryExW`, `RegisterCompositorPort` (else `RegisterSessionPort`) | Gives the ALPC port to the session ([ConnectAlpcServer](#compositor)) |
| [`C:\Windows\System32\VidStream.dll`](./vidstream.md) | `LoadLibraryW`, `CreateUsbVidStreamService` | USB projection service ([Topology](#display-topology)) |
| `ScreenRecorderImpl.dll` | delay-load: `GetSR`, `GetSRFrameListener`, `DestroySR` | Screen recorder ([Screen recording](#screen-recording)) |
| Resources of `CompServer.dll` | `FindResourceExW(type 10 RT_RCDATA, id 100, 200…203, 304, 305)` (`CompositorGraphics::LoadPrecompiledShaderResource`, 0x1001744C) | Precompiled vertex / pixel shaders (id 100 is used for the input layout `POSITION` / `TEXCOORD` ?) |
| ALPC port `<session BNO>\CompositorAlpcPort` | `NtAlpcCreatePort` ([ALPC server](#alpc-server)) | Requests of [CompClient.dll](./compclient.md#alpc) |
| Event `Compositor{<server id>}.ComposeEvent` | `CreateEventW` ([CompServer::Create](#compserver)) | Signalled by the clients when they present |
| Section `Compositor{<server id>}.<client id>.State`, event `…<client id>.FrameEvent` | `CreateFileMappingW`, `CreateEventW` ([Clients](#clients-and-presents)) | Client map of a window, frame done signal |
| `ScreenCap.Map.*`, `ScreenCap.Evt.*` of the caller | `OpenFileMappingW(FILE_MAP_WRITE)`, `OpenEventW(EVENT_MODIFY_STATE)` ([Screen capture](#screen-capture)) | Screenshot destination and "capture started" event, created by CompClient |
| `\\.\SAVER` | `CreateFileW`, `DeviceIoControl` ([Forced crash](#forced-crash)) | Bug check request when the GPU can't be initialised |
| `HKLM\Software\Microsoft\Compositor`, `…\Compositor\MirrorSettings` | `RegCreateKeyExW` ([Registry](#registry)) | Topology, orientation, touch points |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `InitializeCompositor` | 0x10017DC4 | none; returns an HRESULT |

### Startup

`_DllMainCRTStartup` (0x10018DA8): `__security_init_cookie` then the CRT init (`_initterm`: the `g_sqmLogger` initialiser, which opens the SQM session, see [SQM](#sqm)).  
`DllMain` (0x10021A90), on `DLL_PROCESS_ATTACH`: stores `g_hinstDLL`, `DisableThreadLibraryCalls`, registers the ETW provider (`CompositionTraceInitialize`, see [ETW](#etw)); on `DLL_PROCESS_DETACH` unregisters it.

### InitializeCompositor (0x10017DC4)

1. `Singleton<Compositor>::GetInstance()` creates the [Compositor](#compositor) (`E_OUTOFMEMORY` if it fails), then `UIXRender!SpSetCompositorMode(&compositor->ICompositorCallback)`: the render engine now composes through this DLL.
2. `LoadLibraryExW(L"minuser.dll")`, `RegisterSessionProcess(0, 0)`.
3. `LoadLibraryExW(L"gdi32.dll")`, `D3DKMTSetProcessSchedulingPriorityClass(GetCurrentProcess(), 5)`.
4. `GetNavigationCapabilitySid` (0x10017F50): `GetCapabilitySids(L"ID_CAP_FOREGROUND_TASK_MANAGER")` → `ConvertStringSidToSidW` of the account SID, passed to `minuser!SetNavigationServiceSid`.
5. If `minuser!RegisterSessionWorkerThread` exists, starts `PowerNotificationThread` (0x10018308), which only calls `RegisterSessionWorkerThread(0)` (the thread then belongs to the window manager: power notifications ?).
6. `dwmmobile!InitializeMinDWM()`.

A missing `minuser.dll` / `gdi32.dll` gives `E_FAIL`. A missing `minuser` export or a failure of `RegisterSessionProcess`, of the GPU priority or of `SetNavigationServiceSid` is fatal: `GenerateKernelBugCheck` ([Forced crash](#forced-crash)) then a write to address 0.

### Compositor

`Compositor` (singleton, constructor 0x100180E8) implements four interfaces:

| Interface | Methods | Called by |
|-----------|---------|-----------|
| `Splash::ICompositorCallback` (vtable 0x10001708) | `NeedsRender`, `PreRender`, `PostRender`, `GetSurfaceProvider`, `GetDisplayState`, `OnDisplayStateChangeCompleted`, `CheckStatus`, `GetContentPrivacyLevel`, `OnTouchPointsChanged`, `DwmInputHitTestRequest` | UIXRender.dll (render loop) |
| `Splash::ID3D11SurfaceProviderCallback` (0x100016E4) | `GetSubcomponent`, `GetNextUpdateTime`, `AdvanceToTargetTime`, `ContainsSurface`, `RemoveSurface`, `InitializeProvider`, `UninitializeProvider`, `OnDeviceCreationStatus`, `GetSurfaceDesc` | UIXRender.dll (device, surfaces) |
| `ICompositorPALServices` (0x100016CC) | `ValidateWindow`, `ValidateWindowAndOwner`, `GetTouchPointRenderer`, `GetProtectionStatus` | The compositor's own objects |
| `ICompositorApiSet` (0x100016A0) | `OnAcceptConnection` (empty), `OnCloseConnection` (`RemoveUsage`), `ClientCreate`, `ClientDestroy`, `CaptureScreen`, `NotifyOnDisplayStateChange`, `SrProcessCommand`, `TestFrameworkCommand` (`E_NOTIMPL`), `SetDisplayTopology`, `CreateSystemThreads`, `SetProtectedStatus` | The [ALPC server](#alpc-server) |

`InitializeProvider(ID3D11Device *)` (0x10016750), called when the render engine has its device:
1. `CompServer::Create(GetTickCount(), …)` (once): the server id is the tick count ([CompServer](#compserver)).
2. `InitializeTopologyManager`: `TopologyManager::Create`, `SpRegisterWaitHandler(<topology event>, OnTopologyActivity)` ([Display topology](#display-topology)).
3. `CoreUICreateWindowValidator`: used by `ValidateWindow` / `ValidateWindowAndOwner` (window exists, and belongs to the calling process).
4. `ScreenCaptureService::Create`.
5. `ConnectAlpcServer` (0x10017594): `GetCompositorAlpcServer` + `Open` ([ALPC server](#alpc-server)), `SpRegisterWaitHandler(<port>, OnAlpcActivity)` (the render engine's thread waits on the port and calls `ProcessIncomingMessages`), then `api-ms-win-rtcore-session-l1-1-0!RegisterCompositorPort` (or `RegisterSessionPort`) with the port handle.
6. `CompositorGraphics::Create(device)`, `CreateD3D11CompositorDisplay(graphics, services, 0)` (display 0, the panel), then gives both to the `CompServer` and registers the topology manager as a frame listener.

`OnDeviceCreationStatus(hr)` (0x100182E8): while the device creation fails, it notes the time of the first failure. After 5 s it writes the ETW event `DEVICE_CREATE_TIMEOUT` (once), after 30 s it crashes the phone ([Forced crash](#forced-crash)).  
`CheckStatus` returns 0x88860005 when the display is lost (render engine then recreates the device ?).  
`DwmInputHitTestRequest(hwnd, pt, &object)` (0x1000FED8) asks [DWMCORE!WpInputHitTestRequest](./dwmcore.md) only if `dwmmobile!IsHwndForeground(hwnd)`; otherwise `object` = NULL.  
`GetContentPrivacyLevel(name)` (0x10015880) returns a level from a table built on the first call (0 for any other name): 0x29 for `CallProgressHost` and `EmergencyDialerHost`, 0x21 for `AboveNormal`, `ContentSharingHost`, `LoadingResuming`, `LockElementHost`, `MessageToasts`, `PopupLayer`, `ReminderHost`, `SIMSecurityHost`, `SpeechUXHost`, `TaskSwitcherHost`, `Urgent`, `ActionCenterHost`, `OverlayApp`, `LockApp`. The names are shell layers / hosts; the meaning of the bits (hidden from screen capture or projection ?) isn't known.  
`GetDisplayState` / `NotifyOnDisplayStateChange` / `OnDisplayStateChangeCompleted`: see [ALPC requests](#alpc-requests).

### ALPC server

`CompositorAlpcServer::Open` (0x10017694):
1. `QueryTransientObjectSecurityDescriptor(8, L"MobileUI\\Compositor.AlpcPort\\Server")` (type 8 = `AlpcPort`, [SecRuntime](./secruntime.md#querytransientobjectsecuritydescriptor-0x10003c20)): the same descriptor CompClient requires from the server.
2. `RtlGetAppContainerNamedObjectPath(NULL, NULL, FALSE, &path)`: the named object directory of the session, and the port name `<path>\CompositorAlpcPort` (CompClient finds it with `GetApplicationBNOPrefixPath(L"MobileUI", FALSE)`).
3. `ServerConnection::OpenConnection` (0x10017788): `NtAlpcCreatePort` (`OBJ_CASE_INSENSITIVE`, the descriptor above; port flags 0x40000, QoS length 12, `MaxMessageLength` 0xA0), a 0xA0-byte message buffer and a message attribute buffer with `ALPC_MESSAGE_CONTEXT_ATTRIBUTE` (0x20000000). Decoder table `s_rgpfnDecoderTable` (0x10001D50, 17 entries), accept / close callbacks `Decode_OnAcceptConnection` / `Decode_OnCloseConnection`.

`ProcessIncomingMessages` (0x1001098C) loops on `NtAlpcSendWaitReceivePort(port, 0x10000, reply, …)` until there is no more message (`STATUS_UNSUCCESSFUL`, 0xC0000001 ends the loop): requests (`LPC_REQUEST`, datagrams) go to `DispatchRequest`, `LPC_CONNECTION_REQUEST` (10) is always accepted (`NtAlpcAcceptConnectPort`), `LPC_PORT_CLOSED` / `LPC_CLIENT_DIED` close the connection's port and call `OnCloseConnection`. `DispatchRequest` (0x10010B18) needs at least 0x1C bytes and a type (DWORD at +0x18) below 17, then calls the decoder, which checks the exact total length and type and builds the reply in the same buffer.

The caller is identified by `CallerContextInfo` (`GetCallerContext`, 0x10010BDC): +0x00 `ClientId` (pid, tid) of the message, +0x08 connection id (port context attribute), +0x10 `MessageId`, +0x14 `CallbackId`. When a request needs it, `GetCallerToken` (0x100108AC) impersonates the client (`NtAlpcImpersonateClientOfPort`) and opens the thread token for `CapabilityCheck`.

#### ALPC requests

Same packet format as on the [CompClient](./compclient.md#alpc) page: `PORT_MESSAGE` then the type at +0x18.

| Type | Decoder | Length | Check | Action | Reply |
|------|---------|--------|-------|--------|-------|
| 0 `ClientCreate` | 0x10010C34 | 36 | caller token | `Compositor::ClientCreate(hwnd, format)`: the window must be valid and belong to the caller (`ValidateWindowAndOwner`, `E_ACCESSDENIED`), then `CompServer::CreateClient` ([Clients](#clients-and-presents)) | type 1, 40: HRESULT, `CLIENT_DESC` (`dwServerId`, `dwClientId`) |
| 2 `ClientDestroy` | 0x1000F3B8 | 32 | – | `CompServer::DestroyClient(connection, hwnd)` | none |
| 3 `CaptureScreen` | 0x1000F79C | 160 | `ID_CAP_SCREENCAPTURE` | [Screen capture](#screen-capture) | type 4, 48, sent later by `ScreenCaptureResult` (0x1000F220): HRESULT, `CAPTUREHEADER` (zero on failure) |
| 5 `TestFrameworkCommand` | 0x10024A54 | – | – | stub: `E_NOTIMPL` | |
| 7 `NotifyOnDisplayStateChange` | 0x10026978 | 32 | kernel-mode sender only (type flag 0x8000, else `E_ACCESSDENIED`) | `+0x1C` state 1: if the state is idle, asks the render engine to change the display state and replies when it has (`OnDisplayStateChangeCompleted`); state 0: back to state 0 when the change is done. Other states `E_INVALIDARG`, a request at the wrong time 0x8000000E | type 8, 32: HRESULT, sent by `NotifyOnDisplayStateChangeResult` (0x100230BC) |
| 9 `SrProcessCommand` | 0x100267F0 | 28 | `ID_CAP_SCREEN_RECORDER_BKG` and `PolicyManager_GetExperiencePolicy_AllowScreenCapture` (both give one flag) | [Screen recording](#screen-recording) | type 10, 32: HRESULT |
| 11 `SetDisplayTopology` | 0x10026674 | 36 | `ID_CAP_EXTERNAL_DISPLAY`, else `E_ACCESSDENIED` | `Compositor::SetDisplayTopology` ([Display topology](#display-topology)) | type 12, 32: HRESULT |
| 13 `CreateSystemThreads` | 0x100265BC | 28 | kernel-mode sender only | `Compositor::CreateSystemThreads` (0x100233BC): a thread that calls `minuser!ModerncoreCreateSystemThreads()` | type 14, 32: HRESULT |
| 15 `SetProtectedStatus` | 0x100264CC | 28 | – | adds the connection id to `m_ProtectedHandleList` (`E_INVALIDARG` if already there); removed when the connection closes | type 16, 32: HRESULT |

The types 1, 4, 6, 8, 10, 12, 14 and 16 are replies (decoder: `E_NOTIMPL`). Types 7 and 13 come from the kernel (win32k ?), which explains why CompClient doesn't send them. While at least one connection is in the protected list, `GetProtectionStatus` returns TRUE: the display gets it through `CompositorDisplay::GetProtectionStatus` (0x10015638), so the content is protected (no capture or mirroring ?).

`OnCloseConnection` (`Compositor::RemoveUsage`, 0x1000F4DC): `CompServer` releases the clients of the connection, the screen recorder is torn down if it belonged to it, and the connection leaves the protected list.

### CompServer

`CompServer::Create(serverId, …)` (0x10017B38) allocates the object (0x14D8 bytes, `ICompositorContext`, vtable 0x10001EEC) and creates `Compositor{<serverId %08x>}.ComposeEvent`: `QueryTransientObjectSecurityDescriptor(1, L"MobileUI\\Compositor.ComposeEvent")` (type 1 = `Event`), `CreateEventW(sd, auto-reset, non-signalled, name)`. The name has no prefix, so the event is in the object directory of MobileUI.exe, where CompClient opens it. The render engine waits on it (`GetClientWaitHandle`) to know that a client presented.

`CompServer` keeps the clients in a map `HWND` → `CompPresentClient` (`m_mapClients`), the set of active windows, the buffer manager (swap buffers, client buffers pinned / purged, reconstruction of an application's last frame), the frame listeners and a swap queue. Per frame (`BeginRender` / `EndRender` / `Swap`) it decides from the active windows what goes on screen: an application in exclusive / primary mode can be shown directly on a plane (hardware scaler if `MatchesCurrentScalerConfiguration`), otherwise its buffer is composed by Direct3D with the shell content (`ConstructCompositeBuffer`, flags `AllowApplicationSurfaces`, `RequirePrimary`, `RequireScalerEmulation`, `AllowPreviousPrimary`).

`SetActiveWindows(hwndForeground, hwnds, count, …)` (0x10011324): resizes the swap buffer pool (`IncreaseSwapBuffers` / `DecreaseSwapBuffers`), deactivates the windows that are no longer active (`OnWindowDeactivated`), un-occludes the new ones (client map +0x00 = 0) and, when the foreground window changes, calls `dwmmobile!SetForegroundHwnd` and the frame listeners.

`SwapWatcher` (`RunSwapWatcher`, 0x100162E4): thread at `THREAD_PRIORITY_TIME_CRITICAL` that waits for a swap, then polls the display (`CheckForSwapCompletion`, from the DXGI frame statistics) and `WaitForVBlank` until the swap is done, and signals the swap event; every 11 vblanks it calls `CompositorDisplay::CheckForSwapError` (0x1002139C).

### Clients and presents

`CompServer::CreateClient(desc, &clientDesc)` (0x100110A8). `CREATE_CLIENT_DESC`: +0x00 owner (connection id), +0x04 client token, +0x08 `HWND`, +0x0C format. Only `DXGI_FORMAT_B8G8R8A8_UNORM` (87) is accepted (else `E_NOTIMPL`), and a window can have only one client (`E_ACCESSDENIED`). The client id is a counter (never 0).

`CompPresentClient::Create(serverId, owner, clientId, hwnd, token)` (0x1001452C):
1. `Compositor{<serverId>}.<clientId>.FrameEvent`: `BuildSecurityDescriptorForSharingAccess(token, 0, SYNCHRONIZE, &sd)`, `CreateEventW(sd, auto-reset, non-signalled)`.
2. `Compositor{<serverId>}.<clientId>.State`: `BuildSecurityDescriptorForSharingAccess(token, 0, FILE_MAP_READ | FILE_MAP_WRITE)`, `CreateFileMappingW(INVALID_HANDLE_VALUE, sd, …, 0xDA8 bytes)`, mapped with `FILE_MAP_ALL_ACCESS`.

So only the client's token can open the two objects. `InitializeGraphics` then creates the GPU sync object (its handle → map +0x08 `hGpuSync`) and stores the dummy swap buffer (its handle → map +0x04 `hDummyBuffer`). The client is occluded unless its window is active.

The server's view of the [client map](./compclient.md#client-map):

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 4 | `fOccluded` (`SetOccluded`) |
| 0x004 | 4 | `hDummyBuffer` |
| 0x008 | 4 | `hGpuSync`; set to 0 when the graphics are released (client "dead") |
| 0x00C | 4 | `ClaimBufferHint` (`SetClaimBuffer`) |
| 0x010 | 4 | Handle of the buffer the client may claim (`SetClaimBuffer`, taken back by `TryRevokeClaimBuffer` with an atomic exchange) |
| 0x058 | 4 | `fInPresent`, cleared by `ReleasePresent` |
| 0x05C | 4 | Index of the frame slot, switched by `ReleasePresent` when the frame was used |
| 0x060 | 2 × 0x4A0 | Frame slots |
| 0x9A0 | 32 × 16, 4 | `rgrcInput`, `cInput` (input region; copied with each present, used for hit testing ?) |
| 0xBA4 | 32 × 16, 4 | `rgrcRender`, `cRender` (-1 or none = whole buffer) |

Frame slot, as read by `HandlePresent` (0x10015DE4):

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 4 | Copied to the present request +0x08 |
| 0x008 | 8 | Copied to the present request +0x00 |
| 0x010 | 8 | GPU fence value: if it's beyond the fence of the client's GPU sync, the compositor queues a GPU wait on it (`EnqueueWaitOnGpuSync`) before using the buffers |
| 0x018 | 4 | Mask of the planes that have a layer (bits 16…31 must be 0) |
| 0x01C | 4 | Mask of the planes changed by this present (only bit 28, 0x10000000, allowed above bit 15) |
| 0x020 | 16 × 0x44 | `COMPOSITION_LAYER_DESC` per plane: +0x00 `nPlaneIndex`, +0x04 `fEnable`, +0x08 surface handle (may not be `hDummyBuffer`), +0x0C ?, +0x10 flags (0x200: open the surface with its registered identity), rest ? |
| 0x460 | 16 × 4 | Surface identities |

When the client sets `fInPresent` and signals the compose event, `HandlePresent` copies the slot into a present request, opens / resolves the shared surfaces of the changed planes (`ResolveBuffers`, 0x10024540: plane 0 without a new surface reuses the window's current buffer; a claimed buffer must be the one in layer 0), validates the layers against the buffer sizes, copies the input and render regions, and pins the buffers. `ReleasePresent` (0x1000F33C) then switches the slot index, clears `fInPresent`, copies the occlusion flag back and signals the client's frame event.

### Screen capture

`Decode_CaptureScreen`: after the capability check, builds `<caller's AppContainer named object path>\<szMappingName>` (`GetAppContainerNamedObjectPath(token)`, so the names CompClient creates relative to its own directory are found) and, if given, the same path + `szCaptureInitiatedEventName`. `ScreenCaptureService::RequestScreenCapture` (0x1000F9D4) opens the mapping (`FILE_MAP_WRITE`) and the event (`EVENT_MODIFY_STATE`), then queues a request on one of two dispatchers: flag 0x10 selects the second one, and flag 0x01 clear sets a request field (full native capture ?). The capture is taken from a later frame (`SnapshotTracker`: start, render, GPU copy, completed) and the reply is sent with `ScreenCaptureResult`.

### Screen recording

`Compositor::SrProcessCommand(context, allowed)` (0x1002604C), only while no teardown is in progress (else 0x8000000E):
1. First call: remembers the connection, `ScreenRecorderImpl!GetSR(&recorder)`, `GetSRFrameListener(&listener)`, `recorder->OpenHandles(context)`, passes `allowed` to the recorder, and registers the listener as a frame listener of the compositor.
2. The recorder's window must be valid for the caller (unless `allowed`), and the connection must be the one of step 1 (else `E_ACCESSDENIED`).
3. `recorder->ProcessCommand()`.

If the command fails or the recorder says it's finished, `StartScreenRecorderTearDown`: unregisters the listener and calls `ScreenRecorderImpl!DestroySR` (in a new thread when called from the connection close). "Sr" is the screen recorder.

### Display topology

`TopologyManager` (`Create` 0x10017A8C, constructor 0x10018358, object 0x54 bytes) is a frame listener of the compositor.
- At creation: reads `HKLM\Software\Microsoft\Compositor` `DisplayOrientation` (default 3) and `DisplayAlwaysOnMiracast` (default 1); the mode starts at 0. It creates an event and `CM_Register_Notification` for the interface class `GUID_DEVINTERFACE_MONITOR_DRIVER`; `OnConfigManagerNotification` (0x10024A64) signals the event on an arrival / removal of a monitor (and handles the Miracast keep-alive), and the render engine thread then calls `OnTopologyActivity` → `UpdateTopology(TRUE)`.
- `OnInitialized` (0x10017FB0): `LoadLibraryW(L"C:\\Windows\\System32\\VidStream.dll")`, `CreateUsbVidStreamService(3, displayWidth, displayHeight, &service)` (3 frame buffers, see [VidStream.dll](./vidstream.md#createusbvidstreamservice-0x10004d44)). When the PC asks for the projection, VidStream.dll itself calls `CompClient!SetDisplayTopology({2, 0})` after the user's confirmation.

`Compositor::SetDisplayTopology(desc)` (0x10027EBC) accepts the `DISPLAY_TOPOLOGY_DESC` of [MirrorUX.dll](./mirrorux.md#display-topology) with mode ≤ 2 and orientation ≤ 4 (else `E_INVALIDARG`), stores it as the preferred topology and calls `UpdateTopology(FALSE)` (0x100183C8):

| Mode | Name in the asserts | Action |
|------|---------------------|--------|
| 0 | – (phone only) | `SetDisplayConfig(SDC_TOPOLOGY_INTERNAL \| SDC_APPLY)` unless the current mode is 0 or 2 (no external display configured) |
| 1 | `displayTopologyMirror` | `ApplyExtendTopology` (0x100273F0): `QueryDisplayConfig(QDC_ALL_PATHS)`, chooses a mode for the external monitor (`ComputeExternalMode`: `EnumDisplayDevicesW`, `EnumDisplaySettingsW`), `SetDisplayConfig(…)`; on failure, falls back to mode 0. The external display is a second `CompositorDisplay` (index 1) fed by a `DisplayFrameListener` |
| 2 | `displayTopologyMirrorOverUsb` | same display configuration as 0; a `VidStream` frame listener (`InitializeMirrorUsb` 0x10026EA8, 3 snapshots) renders each frame into a snapshot (B5G6R5 or B8G8R8A8, capture size given by the service, touch points drawn) and gives it to the USB video stream service of [VidStream.dll](./vidstream.md#compositor-side) (`SubmitSurface`) |
| 3 | `displayTopologyMirrorOverTest` | same display configuration as 0, mirrored like 1 (`InitializeMirrorDisplay` accepts modes 1 and 3: test mode ?); not accepted from ALPC |

Then it writes `MirrorSettings` `DisplayTopology` = mode and `Compositor` `DisplayOrientation` = orientation (if not 0): that's what `CompClient!GetDisplayTopology` reads. On a mode change the old mirroring listener is unregistered. The mirrored image keeps the aspect ratio of the phone's capture rectangle and is rotated from the phone rotation and the external orientation (`ComputeMirrorOutputConfiguration`, 0x100253D4).

During a Miracast session with `DisplayAlwaysOnMiracast` = 1, a timer (`CreateTimerQueueTimer`, every 20 s) calls `ShellChromeAPI!Shell_IdleTimerReset(8)` so that the phone screen doesn't time out (`OnMiracastEventStart` / `OnMiracastEventStop`).

### Touch points

`TouchPointSettingsProvider::Update` (0x100241D4) reads `HKLM\Software\Microsoft\Compositor` `TouchPointsEnabled`, `TouchPointSize` and `TouchPointColorRGB` (REG_DWORD) and re-arms `RegNotifyChangeKeyValue` on the key. When enabled, `TouchPointRenderer` draws a dot (contact points and "BHF" points, with different alpha) on top of the frame at each touch reported by `OnTouchPointsChanged` (for demos / projection).

### Forced crash

`GenerateKernelBugCheck` (0x100214D0) opens `\\.\SAVER` (`GENERIC_READ | GENERIC_WRITE`, `OPEN_EXISTING`) and sends IOCTL 0xCFC42004 with a 20-byte input buffer and no output:

| Property | Value |
|----------|-------|
| Device | 0xCFC4 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | 0x1000F008 (bug check code ?) |
| 0x04 | 4 | Process id |
| 0x08 | 4 | Thread id |
| 0x0C | 4 | HRESULT of the failure |
| 0x10 | 4 | 5th argument (not set by the callers) |

The driver behind `\\.\SAVER` isn't known (it isn't documented here). The callers then write to address 0 in case the IOCTL returns.

### Registry

| Key | Value | Access |
|-----|-------|--------|
| `HKLM\Software\Microsoft\Compositor\MirrorSettings` | `DisplayTopology` (REG_DWORD) | written by `UpdateTopology` |
| `HKLM\Software\Microsoft\Compositor` | `DisplayOrientation` (REG_DWORD, default 3) | read at startup, written by `UpdateTopology` |
| `HKLM\Software\Microsoft\Compositor` | `DisplayAlwaysOnMiracast` (REG_DWORD, default 1) | read at startup |
| `HKLM\Software\Microsoft\Compositor` | `TouchPointsEnabled`, `TouchPointSize`, `TouchPointColorRGB` (REG_DWORD) | read, change notification |

### SQM

`SqmLogger` opens `WinSqmStartSession(&g_WpSqmGlobalSession, 9, 0)` at load time and counts the projection sessions (durations in minutes, from `GetTickCount64`):

| Data point | Written when |
|------------|--------------|
| 2924 | Miracast / external display mirroring started (`DisplayFrameListener::OnInitialized`) |
| 2926, 2920, 2925 (max) | It stopped: count, total minutes, longest session |
| 2919 | USB mirroring started (`VidStream::OnInitialized`) |
| 2921, 2922, 2923 (max) | It stopped: count, total minutes, longest session |

### ETW

Provider `{54C2DE61-5A35-413A-8443-085EC0C4640B}` (`Microsoft-WindowsPhone-CompositionTrace`, the same as [CompClient.dll](./compclient.md#etw)), registered in `DllMain`.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 200 `DEVICE_CREATE_TIMEOUT` | 1 (critical) | 0, 102 | 0x400 | 0x40 | The Direct3D device still fails 5 s after the first failure (data: elapsed ms) |

The other traces are trace messages (`EtwTraceMessageVarArgs`): enable bit 0x02 `ETWERROR` (failed checks `FEHM fail: Code %1!d!, %2!s!` and asserts), 0x10 `ETWBUFFERS` (presents, layers, screen recorder), 0x20 (swap watcher timing).
