## DWMCORE.DLL

The composition engine of Windows Phone 8.1 (Desktop Window Manager core, "MIL" / "UCE"). It draws every window and visual of the phone with Direct3D 11 and Direct2D.  
`DWMCORE.DLL` is a large DLL (5030 functions, all named from the PDB; the source paths in the strings are `windows\dwm\dwmcore\…`). It's the desktop Windows 8.1 composition engine, with the phone pieces added: the "mobile" swap chain built on [CompClient.dll](./compclient.md), input hit testing for the phone shell (`WpInputHitTestRequest`), and `mobileui.exe` accepted as the DWM process. Its exports are the MIL API: a client opens a connection (transport) to the engine, creates channels on it, and sends batches of resource commands; the engine renders them on its partition (render) threads. The kernel side of the composition (connections, frames, composition surfaces, input sinks) is reached through the `Nt*` functions of `dcomp.dll`.  
The users weren't analysed: the sibling `DWMMOBILE.DLL` (extracted with it) and the compositor of the shell process [MobileUI.exe](../applications/mobileui.md#startup), started by [CompServer!InitializeCompositor](./compserver.md#initializecompositor-0x10017dc4), are the likely callers. The stub [DWMAPI.DLL](./dwmapi.md) is loaded at run time for `DwmIsCompositionEnabled` only.

Location on the phone: `C:\Windows\System32\DWMCORE.DLL` ? (extracted with `DWMAPI.DLL` and `DWMMOBILE.DLL`).  

### Imports

| DLL | Functions |
|-----|-----------|
| dcomp.dll | `NtDCompositionCreateConnection`, `NtDCompositionDestroyConnection`, `NtDCompositionGetConnectionBatch`, `NtDCompositionCreateDwmChannel`, `NtDCompositionDestroyChannel`, `NtDCompositionSubmitDWMBatch`, `NtDCompositionBeginFrame`, `NtDCompositionGetFrameSurfaceUpdates`, `NtDCompositionGetFrameLegacyTokens`, `NtDCompositionConfirmFrame`, `NtDCompositionRetireFrame`, `NtDCompositionDiscardFrame`, `NtTokenManagerOpenEvent`, `NtTokenManagerOpenSection`, `NtTokenManagerThread`, `NtTokenManagerGetOutOfFrameDirectFlipSurfaceUpdates`, `NtTokenManagerDeleteOutstandingDirectFlipTokens`, `NtSetCompositionSurfaceOutOfFrameDirectFlipNotification`, `NtSetCompositionSurfaceStatistics`, `NtSetCompositionSurfaceBufferCompositionMode`, `NtSetCompositionSurfaceIndependentFlipInfo`, `SignalGpuFenceInFrame`, `ValidateCompositionSurfaceHandle`, `QueryCompositionSurfaceBinding`, `QueryCompositionSurfaceRenderingRealization`, `OpenCompositionSurfaceSectionInfo`, `OpenCompositionSurfaceSwapChainHandleInfo`, `OpenCompositionSurfaceDirtyRegion`, `NtQueryCompositionInputSink`, `NtQueryCompositionInputSinkLuid`, `NtCompositionInputThread`, `NtUpdateInputSinkTransforms`, `NtDuplicateCompositionInputSink` |
| api-ms-win-dx-d3dkmt-l1-1-0.dll | `D3DKMTOpenAdapterFromGdiDisplayName`, `D3DKMTQueryAdapterInfo`, `D3DKMTCloseAdapter`, `GdiEntry13`, `DrvQueryAdapterPopulationUniqueness` |
| ntdll.dll | ALPC (`ZwAlpcConnectPort`, `ZwAlpcSendWaitReceivePort`, `ZwAlpcCancelMessage`, `ZwAlpcDisconnectPort`, `ZwAlpcQueryInformation`, `AlpcInitializeMessageAttribute`, `AlpcGetMessageAttribute`, `TpAllocAlpcCompletion`, `TpWaitForAlpcCompletion`, `TpReleaseAlpcCompletion`), sections (`NtCreateSection`, `NtMapViewOfSection`, `NtUnmapViewOfSection`), `NtOpenDirectoryObject`, `NtQueryDirectoryObject`, `NtQuerySystemInformation`, `NtQueryInformationProcess`, `NtSetInformationThread`, generic tables, bitmaps, `RtlWaitOnAddress`, `RtlWakeAddressAll`, `WinSqmIsOptedIn`, `WinSqmAddToStream`, `DbgPrintEx`, `vDbgPrintEx`, `DbgPrompt`, … |
| api-ms-win-core-synch-l1-2-0.dll | events (`CreateEventW`, `OpenEventW`, `SetEvent`, `ResetEvent`), `CreateWaitableTimerExW`, `SetWaitableTimer`, critical sections, SRW locks, `WaitForSingleObject`, `Sleep`, `SleepEx` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `LoadLibraryW`, `FindResourceW`, `WaitForMultipleObjects`, `PulseEvent` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetProcAddress`, `GetModuleHandleW`, `FreeLibrary`, `LoadResource`, `LockResource`, `DisableThreadLibraryCalls`, `GetModuleFileNameA` |
| api-ms-win-core-memory-l1-1-2.dll | `CreateFileMappingW`, `OpenFileMappingW`, `MapViewOfFile`, `UnmapViewOfFile` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `ResumeThread`, `SetThreadPriority`, `TerminateThread`, `GetCurrentProcessId`, `GetCurrentThreadId`, … |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventEnabled`, `EventWrite` |
| api-ms-win-core-sysinfo-l1-2-2.dll, -profile-, -interlocked-, -heap-, -handle-, -string-, -debug- | `GetTickCount64`, `GetSystemInfo`, `GetVersionExW`, `QueryPerformanceCounter`, S-lists, heap, `DuplicateHandle`, `CompareStringOrdinal`, `OutputDebugStringW`, `IsDebuggerPresent` |
| msvcrt.dll | `malloc`, `free`, `memcpy`, `memset`, maths (`sinf`, `cosf`, `floorf`, …), `wcsstr`, `strstr`, `swprintf_s`, `_vsnwprintf`, … (CRT) |

Delay-loaded (`api-ms-win-core-delayload-l1-1-1!ResolveDelayLoadedAPI`):

| DLL | Functions |
|-----|-----------|
| d3d11.dll | `D3D11CreateDevice` |
| dxgi.dll | `CreateDXGIFactory1` |
| d2d1.dll | ordinals 1 (`D2D1CreateFactory`) and 5 (`D2D1InvertMatrix`) |
| DWrite.dll | `DWriteCreateFactory` |
| WindowsCodecs.dll | `WICCreateImagingFactory_Proxy` |
| ext-ms-win-ntuser-private-l1-1-1.dll | ordinal 1553 (`DwmGetDxRgn`), `DwmGetRemoteSessionOcclusionEvent`, `DwmGetRemoteSessionOcclusionState`, `UpdateWindowInputSinkHints` |
| ext-ms-win-gdi-private-l1-1-0.dll | ordinals 1000…1013 (`DwmGetSurfaceData`, `DwmQueryCompositionId`, `DwmGetRedirectionStyle`, `DwmHLSurfGetDirtyRgn`, `DwmHLSurfSetSignalOnDirty`, `DwmHLsurfSetUpdatedId`, `DwmHLSurfOpenCompositorRef`, `DwmHLSurfCloseCompositorRef`, `DwmGenerateMoveData`) |
| ext-ms-win-rtcore-ntuser-sysparams-l1-1-0.dll | `EnumDisplayMonitors`, `GetMonitorInfoW`, `EnumDisplayDevicesW`, `EnumDisplaySettingsW`, `QueryDisplayConfig`, `GetDisplayConfigBufferSizes`, `SystemParametersInfoW`, `GetSystemMetrics` |
| other ext-ms-win-ntuser / gdi sets | `GetGuiResources`, rectangles, `GetDC`/`ReleaseDC`, `InvalidateRect`, `PostMessageW`, `GetClientRect`, `ClientToScreen`, `IsWindow`, `DeleteObject`, `GetDeviceCaps`, regions |
| api-ms-win-security-sddl-l1-1-0.dll | `ConvertStringSecurityDescriptorToSecurityDescriptorW` |
| api-ms-win-core-com-l1-1-1.dll | `CoGetApartmentType` |

The msvcrt, rtlsupport and errorhandling imports, `TerminateProcess` and `ExitProcess` are the CRT startup, C++ exception and `/GS` code. The names of the ordinal imports are the ones IDA gives from the import libraries.

### Dependencies

Files used other than the static and delay-load imports.

| File | How | Use |
|------|-----|-----|
| [DWMAPI.DLL](./dwmapi.md) | `LoadLibraryW(L"DWMAPI.dll")` (`CDelayLoadedModule<DWMAPI::CDWMAPIModuleInfo>::Load`, 0x100AD45C, only if the OS major version ≥ 6), `GetProcAddress("DwmIsCompositionEnabled")` (`DWMAPI::LOAD_DwmIsCompositionEnabled`, 0x100B4D34) | Falls back to a built-in stub if the DLL or the export is missing |
| `avrt.dll` | `LoadLibraryW`, `GetProcAddress` of `AvSetMmThreadCharacteristicsW`, `AvRevertMmThreadCharacteristics`, `AvSetMmThreadPriority` (`CMmcssTask::LoadRuntime`, 0x10059F68) | MMCSS registration of the engine threads (e.g. task `L"Capture"` for the input thread) |
| `d3d11.dll` | `LoadLibraryW` (`CD3DModuleLoaderInternal::CreateD3DObjects`, 0x10075D70), kept loaded; failure prints `WARNING: DWMCore: Direct3D 11 is not installed or load failed.` | Direct3D 11 runtime (also delay-loaded) |
| [CompClient.dll](./compclient.md) | `GetModuleHandleW` (must already be loaded), `GetProcAddress` of `FindSharedState` and `RegisterSurfaceIdentitiesForPresent` (`CMobileHwndSwapChain::Init`, 0x100BA2D4) | Phone swap chain: shared state of the target and surface identities given at each present |
| `rdsdwmdr.dll` | `LoadLibraryW`, `GetProcAddress` of `DwmIndirectCreate`, `DwmIndirectSetDebugFlag` (`CDWMOffScreenSwapChain::InitForGdiBlt`, 0x100AC628) and `DwmIndirectOutput` (`CDisplaySet::EnumerateDevicesForBitmapRemoting`, 0x100B1CD0) | Remote desktop (bitmap remoting) display driver of the desktop; probably absent on the phone |
| `setupapi.dll` | `LoadLibraryW`, `SetupDiGetClassDevsW(GUID_DEVCLASS_SYSTEM)`, `SetupDiEnumDeviceInfo`, `SetupDiGetDeviceInstanceIdW`, `SetupDiDestroyDeviceInfoList` (`GetFirstPciDevice`, 0x1009BAF8) | Looks for a device instance id containing `PCI` |
| `ntdll.dll` | `LoadLibraryW`, `GetProcAddress("ShipAssert")` (`MilShipAssert`, 0x1009BA58) | Ship assertion, code 86017 |
| `kernel32.dll` | `GetModuleHandleW`, `GetProcAddress("WerRegisterMemoryBlock")` (`EnsureStackCaptureRegisteredWithWER`, 0x1000FDCC) | Adds the stack capture buffer (`g_StackCaptureFrames`, 6144 bytes) to the error reports |
| Pixel and vertex shaders | `FindResourceW` / `LoadResource` / `LockResource` on its own module (`Load_g_rgPixelShaders` 0x10072420, `Load_g_rgVertexShaders` 0x10074D50) | Compiled HLSL shaders stored as resources; other shader and D2D effect sources (`DWM Mesh2D Vertex Shader Effect`) are strings in `.text` |

No process is started and no COM server is instantiated by CLSID.

### Exports

All return an HRESULT unless said otherwise. Invalid arguments return `E_INVALIDARG` (0x80070057) and every failure is passed to `MilInstrumentationCheckHR` with the source line.

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 52 | `MILCreateFactory` | 0x100C261C | `IMILFactory **ppFactory, UINT sdkVersion` (must be 0x570C3D0B, else 0x88982F0B) |
| 47 | `MilVersionCheck` | 0x100782DC | `UINT sdkVersion`: `S_OK` for 0x570C3D0B, else 0x88982F0B |
| 26 | `MilCoreClientIsDwm` | 0x100783DC | none, `void`: does nothing |
| 41 | `MilTransport_InitializeConnectionManager` | 0x100778D4 | `IMilRedirectedGDISurfaceManager *, HMIL_CONNECTIONMANAGER *out` (`CConnectionManager::Create`) |
| 45 | `MilTransport_ShutDownConnectionManager` | 0x100BB680 | `HMIL_CONNECTIONMANAGER` |
| 39 | `MilTransport_CreateTransportParameters` | 0x100AE6BC | `bool, int *pType, UINT *, MIL_TRANSPORT_PARAMETERS *, UINT cb` (must be 36): clears the structure, +0x0C = 1, `*pType` = 1, `*arg3` = 0 |
| 37 | `MilTransport_Create` | 0x10076D8C | `HMIL_CONNECTIONMANAGER, MIL_TRANSPORT_PARAMETERS *, UINT cb` (36), `HMIL_CONNECTION *out`: transport type +0x00 = 1 → kernel transport (`CKernelTransport`, dcomp connection), 0 → cross-thread transport (in-process), else `E_UNEXPECTED` |
| 38 | `MilTransport_CreateFromPacketTransport` | 0x100C25B8 | `HMIL_CONNECTIONMANAGER, HMIL_COMMANDTRANSPORT, HMIL_CONNECTION *out` |
| 27 | `MilCrossThreadPacketTransport_Create` | 0x100C09F8 | `HMIL_CONNECTIONMANAGER, MilMarshalType, HMIL_COMMANDTRANSPORT *out` |
| 35 | `MilTransport_AddRef` | 0x10018A48 | `HMIL_CONNECTION`; returns the count |
| 44 | `MilTransport_Release` | 0x1004DCC0 | `HMIL_CONNECTION`; returns the count (same code as `CMILFactory::Release`) |
| 40 | `MilTransport_DisconnectTransport` | 0x100C1908 | `HMIL_CONNECTION`: `CConnection::Disconnect`, then releases it |
| 36 | `MilTransport_Close` | 0x100AE76C | `HMIL_COMMANDTRANSPORT` (vtable +0x08) |
| 42 | `MilTransport_Open` | 0x100AE7A4 | `HMIL_COMMANDTRANSPORT, IMilNotificationTransport *` (vtable +0x04) |
| 43 | `MilTransport_PostPacket` | 0x100AE720 | `HMIL_COMMANDTRANSPORT, UCE_RDP_HEADER *` (vtable +0x00) |
| 12, 13 | `MilCommandTransport_AddRef`, `_Release` | 0x100A2C0C, 0x100A2BF8 | `HMIL_COMMANDTRANSPORT` (vtable +0x24 / +0x28) |
| 22 | `MilConnectionManager_NotifyHostEvent` | 0x1007AC5C | ? : returns `S_OK` without doing anything (same code as `CCrossThreadTransport::RetireFrame`) |
| 23 | `MilConnection_CreateChannel` | 0x10076888 | `HMIL_CONNECTION, MIL_CHANNEL *source` (optional, its handle +0x24 is passed), `MIL_CHANNEL **out` |
| 24 | `MilConnection_DestroyChannel` | 0x100C0488 | `MIL_CHANNEL *`: flushes, destroys it on the connection, releases it |
| 25 | `MilConnection_GetChannelKernelHandle` | 0x10062238 | `MIL_CHANNEL *, UINT *` (channel +0x24) |
| 4 | `MilChannel_BeginCommand` | 0x10029C7C | `MIL_CHANNEL *, void *cmd, UINT cbCmd` (≥ 4), `UINT cbExtra` |
| 3 | `MilChannel_AppendCommandData` | 0x10029CBC | `MIL_CHANNEL *, void *data, UINT cb` (only between begin and end, else 0x88980412) |
| 6 | `MilChannel_EndCommand` | 0x10029B68 | `MIL_CHANNEL *` |
| 5 | `MilChannel_CommitChannel` | 0x10014F94 | `MIL_CHANNEL *`: submits the pending batch to the transport, frees the released handles |
| 9 | `MilChannel_SendSyncCommand` | 0x10014B10 | `const void *cmd, UINT cb, MIL_CHANNEL *, MIL_MESSAGE *reply, UINT cbReply` |
| 7 | `MilChannel_FreeSyncCommandReplay` | 0x100AE654 | `MIL_CHANNEL *, MIL_MESSAGE *, UINT`: frees the data of a reply of type 16 or 17 |
| 8 | `MilChannel_GetMarshalType` | 0x1005DAAC | `MIL_CHANNEL *, MilMarshalType *`: always 1 |
| 10 | `MilChannel_SetNotificationWindow` | 0x100AE604 | `MIL_CHANNEL *, HWND, UINT message` (stored at +0xA4 / +0xA8) |
| 11 | `MilChannel_SetReceiveBroadcastMessages` | 0x100783AC | `MIL_CHANNEL *, bool` (+0xAE) |
| 19 | `MilComposition_PeekNextMessage` | 0x10015690 | `MIL_CHANNEL *, MIL_MESSAGE *, UINT cb, BOOL *pfMessage` |
| 21 | `MilComposition_WaitForNextMessage` | 0x10014DC0 | `MIL_CHANNEL *, DWORD cHandles` (≤ 63), `const HANDLE *, BOOL waitAll, DWORD timeout, DWORD *pResult`: commits, then `WaitForMultipleObjects` on the handles plus the message event of the channel |
| 20 | `MilComposition_SyncFlush` | 0x1006D7EC | `MIL_CHANNEL *` |
| 28 | `MilResource_CreateOrAddRefOnChannel` | 0x100298AC | `MIL_CHANNEL *, MIL_RESOURCE_TYPE, UINT *handle` |
| 31 | `MilResource_ReleaseOnChannel` | 0x10029A0C | `MIL_CHANNEL *, UINT handle, BOOL *pfDeleted` |
| 29 | `MilResource_DuplicateHandle` | 0x1005C7D0 | `MIL_CHANNEL *src, UINT handle, MIL_CHANNEL *dst, UINT *out` |
| 30 | `MilResource_DuplicateHandleOnTarget` | 0x10015174 | `UINT, UINT, MIL_RESOURCE_TYPE, MIL_CHANNEL *, UINT *` |
| 32 | `MilResource_SendCommand` | 0x10029DC8 | `void *cmd, UINT cb, MIL_CHANNEL *` |
| 33 | `MilResource_SendCommandBitmapSource` | 0x100BD478 | `UINT handle, IUnknown *bitmap, BOOL, BOOL, MIL_CHANNEL *` (pixels sent in a section, `SendCommandBitmapSection`) |
| 34 | `MilResource_SendCommandBitmapSourceEx` | 0x1001528C | `UINT handle, IWICBitmap *, IWICImagingFactory *, BOOL, MIL_CHANNEL *` |
| 17 | `MilCompositionEngine_InitializePartitionManager` | 0x10075440 | `int priority, MilThreadPriorityType, MilScheduleType` ([below](#partition-manager)) |
| 18 | `MilCompositionEngine_UpdateSchedulerSettings` | 0x10075450 | same parameters |
| 14 | `MilCompositionEngine_DeinitializePartitionManager` | 0x100BD184 | none |
| 15 | `MilCompositionEngine_GetComposedEventId` | 0x1006DFFC | `UINT *`: id used in the name of the [composed event](#named-objects) |
| 16 | `MilCompositionEngine_GetFeedbackReader` | 0x10077444 | `void **`: reader of the shared `DWM_TIMING_INFO_EX` buffer (`CMrowReader`) |
| 48 | `MilVisualTarget_AttachToHwnd` | 0x100B9188 | `HWND`: adds it to `g_hwndMap` (`E_ACCESSDENIED` if already there) |
| 49 | `MilVisualTarget_DetachFromHwnd` | 0x100B14A4 | `HWND`: removes it |
| 51 | `WpInputHitTestRequest` | 0x100C763C | `HWND, const POINT &, void **result`, returns `BOOL` (`CInputManager::WpInputHitTestRequest`); called by [CompServer.dll](./compserver.md#compositor) for the foreground window |
| 1 | `MIL3DCalcBrushToIdealSampleSpace` | 0x100AEF74 | 3D brush matrix helper (4 pointers) |
| 2 | `MIL3DCalcProjected2DBounds` | 0x100AEF3C | `const CMatrix *, const CMilPointAndSize3F *, CRectF *out` (`CalcProjectedBounds`) |
| 46 | `MilUtility_GetTileBrushMapping` | 0x100AB238 | 13 parameters (matrices, stretch, alignments, mapping modes, rectangles), `void` (`CTileBrushUtils::CalculateTileBrushMapping`) |
| 50 | `SetMilPerfInstrumentationFlags` | 0x1009D95C | `UINT`, `void`: stored in `g_uMilPerfInstrumentationFlags` |

The engine state is global: `g_pPartitionManager` and `g_csCompositionEngine` (taken by most exports), `g_hwndMap` (attached windows), `g_deviceTable` (Direct3D devices), `g_pMediaControl`.

### Startup

`_DllMainStartup` (0x10078074, the entry point) creates the process heap of the DLL (`AvCreateProcessHeap`) on `DLL_PROCESS_ATTACH` and destroys it on detach, around `_DllMainCRTStartup` (0x1007953C: `__security_init_cookie`, CRT init, then `DllMain`, 0x100B9CB0).  
`DllMain` calls `DwmCoreDllMain` (0x10072238). On attach: saves the instance, `DisableThreadLibraryCalls`, initialises `g_csCompositionEngine` and `g_csDesktopTreeLock`, `Startup()`, `CD3DDeviceManager::Init`, then registers the two [ETW providers](#etw). On detach: unregisters them, deletes the device manager, releases d3d11.dll and the critical sections.

`IsCurrentProcessDwm` (0x100708F8, used by `CSurfaceManager::Initialize`) compares the module file name of the process with `strstr` against `dwm.exe`, then `mobileui.exe`, then `mindwm.exe`: on the phone the compositor runs in [MobileUI.exe](../applications/mobileui.md) (or `mindwm.exe`, not analysed).

### Partition manager

`MilCompositionEngine_InitializePartitionManager` → `EnsurePartitionManager` (0x1007549C) → `CPartitionManager::Initialize` (0x10075570):

1. Opens `HKLM\Software\Microsoft\Avalon.Graphics`; if `EnableDebugControl` is non-zero, `CPerformanceCounter::Initialize` and `CMediaControl::Create(L"DwmCore-<pid>")` ([below](#media-control)).
2. Initialises its critical section and applies the scheduler settings (`UpdateSchedulerSettings`: `UpdateSchedulerType` creates two auto-reset events the first time, else stops the worker threads, and stores the schedule type).
3. The render threads are `CPartitionThread`s (`StartThread`, 0x100756E0: `CreateThread(ThreadMain)`, priority from the parameters through `SetThreadPriority` / `NtSetInformationThread`). The throttled scheduler (`CPartitionThrottledScheduler::Initialize`, 0x100B62B8) uses a waitable timer (`CreateWaitableTimerExW(…, 0x1F0003)`) whose period is derived from the refresh rate; the vertical blank scheduler waits for the vblank (`CPartitionVerticalBlankScheduler::Run`).

An unexpected error of a render thread (other than out of memory, 0x8898009B, 0x8898008D, 0x88980006) prints `MIL FAILURE: Unexpected HRESULT …` (`DbgPrintEx`), breaks if `BreakOnUnexpectedErrors` is set, and raises the exception 0xE0464645 with the HRESULT (`CPartitionManager::ZombifyPartitionAndCompleteProcessing`, 0x100A98F0).

Other threads: the input thread (`CInputManager::CreateInputThread`, 0x10070328, `s_InputThreadMain`, priority 16 `THREAD_PRIORITY_TIME_CRITICAL`, MMCSS task `Capture`) and the token thread of the surface manager (`CLocalSurfaceManager::CreateTokenThread`, 0x1007815C, `s_TokenThreadMain`, priority 15), which handles the composition surface tokens (`NtTokenManagerThread`).

### Media control

`CMediaControl::Initialize` (0x100A2F38): `CreateFileMappingW(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, 0, 0x84, L"DwmCore-<pid>")`; fails with `E_FAIL` if the mapping already exists. The 132-byte view is cleared and its first DWORD set to 3 (version ?). It's a debug / performance control block that an external tool can open; only created when `EnableDebugControl` is set.

### Phone swap chain

`CMobileHwndSwapChain::Init` (0x100BA2D4) is the swap chain of a window on the phone:
1. Requires the window target (+0xC0, 8 bytes) to be set (else 0x88980080), then `CSwapChainBase::Init`.
2. Queries the swap chain for interface `{B56387A9-2BE5-4C10-A2B5-5DB43DC1A0AF}` (unknown name).
3. `CompClient!FindSharedState(target, &state)` and keeps `CompClient!RegisterSurfaceIdentitiesForPresent` for the presents. `CompClient.dll` must already be in the process (`GetModuleHandleW`). The target is the `HWND`: [CompClient.dll](./compclient.md#createsharedstate-0x10002f40) finds the `ClientState` created by `CreateSharedState` for that window, and `RegisterSurfaceIdentitiesForPresent` stores the identities in the frame slot of the [client map](./compclient.md#client-map) for the next present.

### PDC scenarios

The DLL contains a user-mode client of the power dependency coordinator (`\PdcPort`), like [ShellChrome.dll](./shellchrome.md) and [WPTimeSvc.dll](./wptimesvc.md#pdc-activation). It is the user-mode copy of the "scenario client" code that [wppower.sys](../drivers/wppower.md#pdc-clients) uses for its component 0x411 (same object, same messages, kernel transport `ZwPowerInformation(PdcInvocation)` instead of ALPC):

- `PdcScenarioClientRegister(id, &client)` (0x100D40CC): 32-byte object, signature `Pdcs` (0x73636450) at +0x00, id at +0x0C. It calls `PdcPortOpen` (0x1006E598): port object signatures `PdcP` (0x50636450) and `PDCt` (0x74434450), `ZwAlpcConnectPort(L"\PdcPort", attributes flags 0x20000, max message 0x30, connect flags 0xA0000)`. The connection message (0x18-byte `PORT_MESSAGE` header + 0x18 bytes) has DWORD 6 = 0 (register), DWORD 8 = component id, DWORD 9 = 5 (client type: scenario client), the layout of the register message of wppower.sys.
- `PdcScenarioClientRequest(client, BOOL activate)` (0x100D4000): reference count at +0x14. The first activation and the last release send a 48-byte message with `ZwAlpcSendWaitReceivePort` (`PdcPortSendMessageSynchronously`, 0x10017400): DWORD 6 = 8 (activate), byte +0x20 = 1 / 0. Releasing with no reference returns `STATUS_UNSUCCESSFUL`; a bad object `STATUS_INVALID_PARAMETER_1` (0xC00000EF).
- `PdcScenarioClientUnregister` (0x100D4088): closes the port (`PdcPortClose`) and frees the object (`~CHwndRenderTarget`, `~CPartitionVerticalBlankScheduler`).

Errors of the ALPC code are printed by `PdcpAlpcProcessMessage` / `PdcpProcessMessageInternal`.  
The same ALPC port code (`PdcPortOpen`, signatures `PdcP` / `PDCt`) is in [WPTimeSvc.dll](./wptimesvc.md#pdc-activation), but there it serves a different kind of client: object `PDcA`, client type 2 (component 0x44), activation by message type 4 with the status returned at +0x20, and an ALPC completion on the thread pool for the messages of the PDC. The scenario clients of DWMCORE register no completion (connection object +0x24 = 0) and use message type 8.

| Component id | Registered by | Activated / released |
|--------------|---------------|----------------------|
| 0x400 | `CHwndRenderTarget::InitFullScreen` (client at +0x1B8) | `CHwndRenderTarget::NotifyPowerManagerContentType`, called by `Present` and `PresentOutOfFrameDirectFlip`: active while the full-screen content is a direct-flip or overlay surface that isn't desktop content and whose surface type (+0x88 of its realization) is 1 (full-screen video ?) |
| 0x407 | `CHwndRenderTarget::InitFullScreen` (client at +0x1BC) | Same function: active in the case above or while any full-screen overlay plane of type ≤ 2 is used |
| 0x40A | `CTelemetryTouchLatencyAnalysis` constructor | Active from the first touch scenario (`AllocateScenario`) until the last one is retired (`RetireScenario`) |
| 0x40B | `CAnimationTracking` constructor | Active from the first tracked animation (`EnsureScenario`) until the last one is deleted (`DeleteScenario`) |

Each change of 0x400 / 0x407 writes the ETW event `ETWGUID_NOTIFYPOWERMANAGER` (252) with the id (1024 / 1031). So the compositor tells the power manager when full-screen video / overlay content is shown and while animations or touch interactions are measured. What the PDC does with these components (e.g. which power state it keeps) is decided in the kernel (ntoskrnl), not analysed.

### Animation and touch telemetry

`CAnimationTracking` measures the frame rate of the shell animations, identified by GUID; `ScenarioNameFromGuid` (0x100171D0) maps 57 GUIDs (table at 0x100D59F8, 20 bytes per entry) to names such as `App Launch from Start`, `Launcher Show`, `Close App - Fadeout`, `Switch List Open - Peek`, `Touch Keyboard Show`, `Lock Screen Slideshow Show`, `Tile Notification`, `Charms Bar Show (Touch)` (many are desktop Windows scenarios). The results are written as ETW events `TELEMETRY_ANIMATION_*` with a `<name>|<flags>|<details>` string. `CTelemetryTouchLatencyAnalysis` writes the `TELEMETRY_TOUCH_ANALYSIS_*` events. `CDwmCoreWinSqm::RecordDisplayDriverName` (0x100A7714) sends the `DriverVersion` of each display device to SQM (`WinSqmAddToStream`, datapoint 0xD07).

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\Software\Microsoft\Avalon.Graphics` | `UseD3DDebugLayer`, `Force10Level9`, `Force10OnWDDM1_0` | `CCommonRegistryData::InitializeFromRegistry` (0x100784A0) |
| `HKLM\Software\Microsoft\Avalon.Graphics` | `EnableDebugControl` | [Media control](#media-control) |
| `HKLM\Software\Microsoft\Avalon.Graphics` | `BreakOnUnexpectedErrors`, `DisableInstrumentationBreaking` | Debug breaks (`MilUnexpectedError` 0x100A6E78, `BreakForInstrumentation` 0x100A3FC4) |
| `HKLM\Software\Microsoft\Windows\Dwm` | `OverlayTestMode` | Read if `HKCU\Software\Microsoft\Windows\DWM` exists (`InitializeDWMKeysFromRegistry`, 0x100A4004) |
| `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows` | `GDIProcessHandleQuota` (default 10000) | `CheckGUIHandleQuota` (0x1009CBC8): out of memory when the GDI handles reach 7/8 of the quota |
| `HKLM` / `HKCU` display key of each display (`CDisplayRegKey`) | `PixelStructure`, `GammaLevel` (HKLM); `ClearTypeLevel`, `TextContrastLevel` (HKCU, max 6) | Text rendering settings (`CDisplaySet::ReadIndividualDisplaySettings`, 0x100569E4) |
| Display driver key (`\Registry\Machine\…` from `EnumDisplayDevicesW`) | `DriverVersion`, `HardwareInformation.MemorySize`, `InstalledDisplayDrivers` | SQM and `CDisplay` constructor |

### Named objects

| Name | Type | Use |
|------|------|-----|
| `DWM_DX_FULLSCREEN_TRANSITION_EVENT` | Event, manual reset, created with `D:(A;;0x00100002;;;WD)` (Everyone: `SYNCHRONIZE` + `EVENT_MODIFY_STATE`) | `CDesktopRenderTarget` constructor (0x100779B0) |
| `DwmComposedEvent_<id>` (`%s%x`) | Event, opened (`OpenEventW(EVENT_MODIFY_STATE)`) | `OpenComposedEvent` (0x10077D48); not found → 0x80263001 |
| `DwmDxBltEvent_<64-bit id>` (`%s%I64x`) | Event, opened | `OpenDxBltEvent` (0x100654CC): tried in the global namespace, then in every `\Sessions\<n>\AppContainerNamedObjects\<SID>` directory (`NtOpenDirectoryObject` / `NtQueryDirectoryObject`) |
| `Local\WarpResource_0x<handle>` | File mapping, opened (`OpenFileMappingW(0xF001F)`) | Shared WARP texture (`CDWMOffScreenSwapChain::Create`, 0x100BB6FC) |
| `DwmCore-<pid>` | File mapping, created | [Media control](#media-control) |
| `\PdcPort` | ALPC port | [PDC scenarios](#pdc-scenarios) |

### ETW

Two providers, registered in `DwmCoreDllMain`:

| Provider | GUID |
|----------|------|
| Microsoft-Windows-Dwm-Core | `{9E9BBA3C-2E38-40CB-99F4-9E8281425164}` |
| Microsoft-Windows-DesktopWindowManager-Diag | `{31F60101-3703-48EA-8143-451F8DE779D2}` |

There are 219 `EVENT_DESCRIPTOR`s (`EVTDESC_*`, 0x10001610…), level 4 or 5, keyword 0x8000000000000001 for most: the frame scheduler (`SCHEDULE_FRAMEINFO` 1, `SCHEDULE_RENDER_Start/Stop` 13/14, `SCHEDULE_PRESENT_*` 15/16, `SCHEDULE_VBLANK_LOOP_*` 79/80, `SCHEDULE_GLITCH_DETECTED` 172), UCE processing (`MILEVENT_MEDIA_UCE_*`), flip chains and direct flip, overlays, hit testing (208…211), render target capture, DComp animations (`DCOMPEVENT_*`), and the telemetry events with keyword 0x8001000000020001 (`TELEMETRY_ANIMATION_PERFORMANCE_ANALYSIS_EVENT` 237, `TELEMETRY_ANIMATION_TTFF_ANALYSIS_EVENT` 259, `TELEMETRY_TOUCH_ANALYSIS_SUMMARY1_EVENT` 190, `…SUMMARY2_EVENT` 257, `TELEMETRY_AGGREGATED_VSYNC_ANALYSIS_EVENT` 240, …).
