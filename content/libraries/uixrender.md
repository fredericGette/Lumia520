## UIXRender.dll

The render and input engine ("Splash") under the UIX markup framework of Windows Phone 8.1: it hosts the UIX object system and threads, draws the visual tree with Direct3D 11, lays out text with DirectWrite, and reads the touch screen, the keyboard and the hardware buttons.  
`UIXRender.dll` is a large C++ DLL (802 816 bytes, 4622 functions, all named from the public symbols of `uixrender.pdb`). Its namespaces show its parts: `System` (object system, contexts, threads, dispatcher), `Engine` (UIX runtime, devices, windows, video sessions), `Components` (animations, `eCM` windows / input / gestures / UI Automation / magnifier, `Desktop`), `Drivers` (`Common`, `Direct3D11`), the text engine (`SplashTextFactory`, `TextLayout`, `SplashTextRasterizer`), `VideoComposition` (video frames received over ALPC), the gesture recognizers (`GestureSession`, `FlickRecognizer`, `CraneGrabRecognizer`…) and the input reader (`InputStateManager`, `TouchInputHost`). It exports 267 C functions `Sp*` used by the UIX engine `UIXn.dll` (not analysed) and by the UIX schema DLLs (`UIXGetSchemaFactory` / `UIXGetScriptProc` / `UIXSchemaUnloaded` are looked up in them).  
In the shell process, [CompServer.dll](./compserver.md#initializecompositor-0x10017dc4) calls `SpSetCompositorMode` to plug its compositor in: the engine then composes the system frame through the `Splash::ICompositorCallback` of CompServer instead of presenting its own swap chain, and the input reader of this DLL feeds the shell. It also takes part in the power management of the shell: every input publishes the WNF state `WNF_INP_USER_ACTIVITY` and wakes the screen from connected standby through the same RPC interface as [MobileUI.exe](../applications/mobileui.md#rpc-clients).

Location on the phone: `C:\Windows\System32\UIXRender.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| CoreMessaging.dll | `CoreUICreate`, `CoreUICreateAnonymousStream`, `CoreUIFailFastOOM` |
| CoreUIComponents.dll | `CoreUIClientCreate`, `CoreUIFactoryCreate`, `MsgStringCreateShared` |
| TextInputFramework.dll | `TextInputHostCreate`, `TextInputClientCreate` |
| WindowsCodecs.dll | `WICCreateImagingFactory_Proxy` |
| [ShellChromeAPI.dll](./shellchromeapi.md) | `Shell_IsLocked`, `Shl::ActionDialog::Create` |
| [DCOMP.DLL](./dcomp.md) | `NtQueryCompositionInputQueueAndTransform` |
| [SecRuntime.dll](./secruntime.md) | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor`, `OpenProcessForQuery` |
| RPCRT4.dll | `RpcStringBindingComposeW`, `RpcStringFreeW`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW`, `RpcBindingFree`, `NdrClientCall2`, `NdrRpcSmClientAllocate`, `NdrRpcSmClientFree`, `I_RpcExceptionFilter` |
| ntdll.dll | `NtCreateFile`, `NtClose`, `RtlInitUnicodeString`, `RtlPublishWnfStateData`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `NtAlpcConnectPort`, `NtAlpcAcceptConnectPort`, `NtAlpcSendWaitReceivePort`, `NtAlpcCancelMessage`, `AlpcInitializeMessageAttribute`, `AlpcGetMessageAttribute`, `NtSetTimerResolution`, `NtSetInformationThread` |
| OLEAUT32.dll | `SysAllocString*`, `SysReAllocString*`, `SysFreeString`, `SysStringLen`, `SysStringByteLen`, `VariantInit`, `VariantClear`, `SafeArray*` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegOpenKeyExA`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegQueryValueExA`, `RegSetValueExW`, `RegNotifyChangeKeyValue`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0, kernel32-legacy | `LoadLibraryExW`, `LoadLibraryW`, `LoadLibraryA`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleHandleExW`, `GetProcAddress`, `GetModuleFileNameW`, `GetModuleFileNameA`, `FindResourceExW`, `LoadResource`, `LockResource`, `SizeofResource`, `LoadStringW` |
| api-ms-win-core-file-l1-2-1, io-l1-1-1, processenvironment | `CreateFileW`, `ReadFile`, `WriteFile`, `GetFileSize`, `SetEndOfFile`, `GetOverlappedResult`, `CancelIoEx`, `GetStdHandle` |
| api-ms-win-core-memory-l1-1-2 | `CreateFileMappingW`, `OpenFileMappingW`, `MapViewOfFile`, `UnmapViewOfFile` |
| api-ms-win-core-synch-l1-2-0, kernel32-legacy | Critical sections, `CreateEventW`/`A`, `OpenEventW`/`A`, `SetEvent`, `ResetEvent`, `CreateMutexW`/`A`, `OpenMutexW`, `ReleaseMutex`, `WaitForSingleObject`, `WaitForMultipleObjects(Ex)`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateThread`, `ResumeThread`, `SetThreadPriority`, `GetCurrentThread(Id)`, `GetCurrentProcess(Id)`, `OpenProcessToken`, `Tls*`, `IsProcessorFeaturePresent`, `TerminateProcess` |
| api-ms-win-security-base-l1-2-0, lsalookup-l2-1-1 | `AdjustTokenPrivileges`, `LookupPrivilegeValueW` |
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance`, `StringFromGUID2` |
| api-ms-win-core-heap-l1-2-0, profile, sysinfo, string, localization, timezone, handle, shlwapi-legacy | `HeapCreate`/`Alloc`/…, `QueryPerformanceCounter`/`Frequency`, `GetSystemInfo`, `GetTickCount`, `GetLocalTime`, `GlobalMemoryStatusEx`, `CompareStringOrdinal`, `WideCharToMultiByte`, `GetLocaleInfoEx`/`W`, `LCIDToLocaleName`, `GetThreadUILanguage`, `FileTimeToSystemTime`, `SystemTimeToFileTime`, `DuplicateHandle`, `CloseHandle`, `PathFindFileNameW` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| Delay-load: ext-ms-win-ntuser-rectangle-ext, ext-ms-win-rtcore-ntuser-sysparams, ext-ms-win-rtcore-ntuser-dc-access, ext-ms-win-rtcore-gdi-devcaps, UIAutomationCore.dll, api-ms-win-devices-config-l1-1-1 | `OffsetRect`, `InflateRect`, `PtInRect`, `UnionRect`, `IntersectRect`, `EqualRect`; `GetSystemMetrics`, `EnumDisplaySettingsW`; `GetDC`, `ReleaseDC`; `GetDeviceCaps`; `UiaReturnRawElementProvider`, `UiaHostProviderFromHwnd`, `UiaClientsAreListening`, `UiaRaise*Event`; `CM_Register_Notification`, `CM_Unregister_Notification` |
| api-ms-win-core-errorhandling, debug, rtlsupport, msvcrt.dll | `RaiseException`, `RaiseFailFastException`, `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `DebugBreak`, `OutputDebugStringW`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `RtlRaiseException`; CRT (`malloc`, `free`, `mem*`, `wcs*`, maths `sinf`/`cosf`/`powf`…, `qsort`, `bsearch`, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, `TerminateProcess`, `SetUnhandledExceptionFilter` and `UnhandledExceptionFilter` imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code. `api-ms-win-core-delayload-l1-1-1` (`ResolveDelayLoadedAPI`, `DelayLoadFailureHook`) resolves the delay-loaded DLLs.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `d3d11.dll` | `LoadLibraryExW` + `GetProcAddress("D3D11CreateDeviceAndSwapChain")`, `("D3D11CreateDevice")` (`Drivers::Direct3D11::Device::LoadD3D11`, 0x100621A0) | Direct3D 11 device (the GPU driver is [qcdx9um8930.dll](./qcdx9um8930.md)) |
| `dxgi.dll` | `LoadLibraryExW` + `GetProcAddress("CreateDXGIFactory1")` (same function) | DXGI factory, swap chain |
| `D3DCompiler_47.dll` | `LoadLibraryExW` + `GetProcAddress("D3DReflect")`, `("D3DCompile")` (`Device::LoadD3D11Compiler`, 0x1008DE3C) | Only for an effect without a precompiled shader ("Performance warning: attempting to load the D3D compiler dll!"), from `SpDx11CompileEffect` |
| `gdi32.dll` | `LoadLibraryA` + `GetProcAddress("D3DKMTQueryStatistics")` (`Drivers::Direct3D11::GpuSchedulerQuery::Initialize`, 0x1008A8FC) | GPU scheduler statistics for the frame timing ([GDI32.DLL](./gdi32.md)) |
| `dwrite.dll` | `LoadLibraryW` + `GetProcAddress("DWriteCreateFactory")` (`SplashTextFactory::SplashTextFactory`, 0x10030D4C) | Text layout and rendering; skipped when `HKCU\Software\Microsoft\UIX\DWrite` = 0 |
| `msftedit` | `SpLoadLibrary` + `GetProcAddress("CreateTextServices")` (`Components::eCM::EditableText::InitClass`, 0x100582C4) | RichEdit text services of the edit boxes |
| `xmllite.dll` | `SpLoadLibrary` + `GetProcAddress("CreateXmlReader")`, `("CreateXmlWriter")` (`LoadXmlLite`, 0x1005984C) | `SpXmlLite*` exports |
| `api-ms-win-rtcore-session-l1-1-0.dll` | `LoadLibraryW` + `GetProcAddress("RegisterSharedInputGlobal")` (`InputStateManager::InitializeSharedInputGlobal`, 0x100669B8) | Registers the shared input state (last input time…) with the kernel; implemented by [MinUser.dll](./minuser.md) (`NtModerncoreRegisterSharedInputGlobal`) |
| `CoreUIComponents.dll` | `LoadLibraryW` + `GetProcAddress("MinUserGetPointerDeviceProperties")` (`GetTouchDeviceUsages`, 0x10063368) | Usages of the touch device (array of 28-byte entries) |
| `wpcoreutil.dll` | `LoadLibraryW` + `GetProcAddress("SHGetSpecialFolderPathW")`, CSIDL 26 (`CSIDL_APPDATA`) (`SpAutomationGetAppFolderPath`, 0x1007CF4C) | Application data folder for the UI automation |
| `AccessibilityCPLRes.dll` | `LoadLibraryExW(…, LOAD_LIBRARY_AS_DATAFILE)` + `LoadStringW` 10092…10095 (`LoadResourceString`, 0x1007AE74) | Texts of the magnifier prompt ([Magnifier](#magnifier)) |
| `UIAutomationCore.dll` | delay-load; `GetModuleHandleW` + `GetProcAddress("UiaDisconnectAllProviders")` (`UIAProviderRoot::Shutdown`, 0x1008545C) | UI Automation provider of the UIX tree |
| `emclient.dll` | `GetModuleHandleW` + `GetProcAddress("SHTerminateProcessForOOM")` (`UIXFailFastForOutOfMemory`, 0x1007C390) | Called if already loaded on out of memory, then exception 0xE055494D |
| Schema DLL of the markup (any module) | `GetProcAddress("UIXGetSchemaFactory")` (`GetSchemaFactory`, 0x10061B78), `("UIXGetScriptProc")` (`SpResolveScriptProc`), `("UIXSchemaUnloaded")` (`SpSendDllSchemaUnloadNotification`) | Native types of a UIX schema DLL (e.g. [UIXMobile.dll](./uixmobile.md), [DateTimeCPLdll.dll](./datetimecpldll.md)) |
| Module named by the caller | `LoadLibraryExW(name, NULL, 0 or LOAD_LIBRARY_AS_DATAFILE)` (`SpLoadLibrary`, 0x100597DC), `FindResourceExW` (`SpFindResource`), `LoadStringW` (`SpLoadString`), `SpLoadFontResource` | Modules, resources, strings and fonts of the markup; ERROR_NOT_ENOUGH_MEMORY-like errors (8, 1114, 1450, 1455) are returned as `E_OUTOFMEMORY` |
| File named by the caller | `CreateFileW(GENERIC_READ, FILE_SHARE_READ \| FILE_SHARE_DELETE, OPEN_EXISTING)` + `ReadFile` on a worker thread (`AsyncFileLoader::WorkItem::LoadFileContents`, 0x1008A5B8) | `SpFileDownload`: asynchronous file read with a callback |
| Trace file | `CreateFileW(GENERIC_WRITE, FILE_SHARE_READ, CREATE_ALWAYS)`, or `GetStdHandle(STD_OUTPUT_HANDLE)` for `L"stdout"` (`SpUpdateTraceSettings`, 0x10053E18) | Debug trace output |
| XML output file | `CreateFileW(GENERIC_WRITE, FILE_SHARE_READ, CREATE_ALWAYS)` (`XmlOutputStream::Initialize`, 0x100825A8) | `SpXmlLiteCreateXmlWriter` |
| `CUIAutomationRegistrar` `{6E29FABF-9977-42D1-8D0E-CA7E61AD87E6}` (UIAutomationCore) | `CoCreateInstance`, IID `IUIAutomationRegistrar` `{8609C4EC-4A1A-4D88-A357-5A66E060E1CF}` (`PatternRegistrar::RegisterAutomationActionPattern`, 0x10082FB8) | Registers the custom pattern `AutomationActionPattern` (`InvokeAction`, `RequestWaitForIdleEvent`, event `WaitForIdleComplete`) |
| `\Device\TouchClass0`, `\Device\WPKeyboardClass`, `\Device\PointerClass0` | `NtCreateFile` ([Input devices](#input-devices)) | Raw touch, keyboard / buttons and mouse input |
| RPC server of the connected standby interface `{85F9809B-…}` | `RpcBindingFromStringBindingW` ([RPC](#rpc)) | Leave connected standby on input |
| ALPC port of a video source (name given to `SpVideoConnect2`) | `NtAlpcConnectPort` ([Video](#video-composition)) | Video frames to compose |

No process is started.

### Exports

267 exports, all `Sp*` C functions, plus 3 without name. The linker folded identical functions: many small exports share the same address and only call a method of their first argument (e.g. 0x1002D8C8 = `SpDataQuerySetResultProperty` = `SpGetPotentialGestures` = `SpUIXListAdd` = call of vtable slot 10 of the object). `SpVideoConnect` and `SpReportAssertionFailure` are the same stub returning 0.

| Family | Exports (ordinal) | Role |
|--------|-------------------|------|
| Initialisation | `SpInit` (234), `SpUninit` (341), `SpRenderThreadInit` (301), `SpRenderThreadUninit` (302), `SpFrameworkUninit` (176), `SpCoreUIInitialize` (135), `SpImagingInit` (232), `SpImagingUninit` (233), `SpSetFrameworkRunningState` (313), `SpSetWatchDogCallback` (317), `SpEnsureApplicationThread` (168) | Contexts, threads, CoreMessaging, WIC, watchdog |
| Compositor | `SpSetCompositorMode` (311), `SpInCompositorMode` (110), `SpGetCompositorContentPrivacyLevel` (200) | [Compositor mode](#compositor-mode) |
| Contexts and messages | `SpContextRun` (131), `SpContextExit` (130), `SpGetThreadContext` (224), `SpGetThreadContextOrNull` (225), `SpPostEngineMessage` (283), `SpDispatchInstanceMessage` (165), `SpCallDeferredInvokeProc` (129), `SpDisableDeferredInvoke` (164), `SpInvoke` (237), `SpRegisterWaitHandler` (298), `SpUnregisterWaitHandler` (346), `SpEnableWaitHandler` (167), `SpGetCurrentMessageSession` (203), `SpMessageSession*` (111, 112, 249…257), `SpMessageGroupSet*` (247, 248), `SpMessageTimer*` (258…260) | Object system and CoreMessaging message sessions |
| Object model and schemas | `SpCreateObject` (144), `SpDestroyObject` (162), `SpFindClass` (174), `SpQuery*Definition` (285…291), `SpGet*Schema` (202, 206, 207, 214, 219, 230), `SpGetEnumNameValue` (205), `SpGetType*` (226…230), `SpInvokeConstructor` (238), `SpInvokeMethod` (240), `SpInvokeEnumToString` (239), `SpGetPropertyValue` (220), `SpSetPropertyValue` (314), `SpSetSchemaID` (315), `SpCreateDllLoadResult` (136), `SpCreateDllLoadResultFactory` (137), `SpResolveScriptProc` (304), `SpSendDllSchemaUnloadNotification` (310), `SpCreateNative{String,Blob,Image}` (140…142), `SpConvert*ToManaged` (132, 133), `SpGet{String,Blob,Image}Handle` (198, 209, 223), `SpCreateProxyWrapper` (145), `SpAddRefExternalObject` (113), `SpReleaseExternalObject` (299), `SpQueryForMarshalAsInterface` (287), `SpGetStateCache` (222), `SpSetStateCache` (316), `SpGetSize__System__String` (221), `SpCopyString` (134), `SpMemAlloc` (245), `SpMemFree` (246) | UIX code model: native types of the schema DLLs |
| Data and lists | `SpDataBaseObject*` (146…150), `SpDataProvider*` (151, 152), `SpDataQuery*` (153…160), `SpUIXList*` (321…340) | Data providers and virtual lists of the markup |
| Input | `SpOn*` (261…282, and ordinals 100…102: `SpOnHoverMove`, `SpOnHoverSessionBegin`, `SpOnHoverSessionEnd`), `SpGetInputHandlerOptions` (210), `SpCreateGestureRecognizer` (139), `SpGestureRecognizer*` (179…197), `SpReleaseGestureRecognizer` (300), `SpGetPotentialGestures` (218), `SpSet/GetExternalMotionHandlerCallback` (312, 208), `SpAnimationInput{Consumer,Publisher}Connect` (114, 115), `SpCreateEditableText` (138), `SpHandleCloseRequest` (231) | Key, touch and gesture events, gesture configuration ([Registry](#registry)) |
| Windows and video | `SpCreateNotifyWindow` (143), `SpDestroyNotifyWindow` (161), `SpRegisterVirtualTileProvider(2)` (296, 297), `SpUnregisterVirtualTileProvider` (345), `SpVideoConnect` (348), `SpVideoConnect2` (349), `SpVideoDisconnect` (350) | [Video composition](#video-composition) |
| Graphics | `SpDx11CompileEffect` (103), `SpDx11CreateShaderReflectionState` (104), `SpDx11DeleteShaderReflectionState` (105), `SpDx11LoadTexture` (106), `SpDx11LookupPropertyHandle` (107), `SpDx11ReleaseTexture` (108), `SpGLCompileEffect` (109), `SpBitmap*` (122…128), `SpGetColorFromName` (199, the X11 colour names `AliceBlue`…`YellowGreen`, `TVBlack`, `TVWhite`), `SpGetDpi` (204) | Effects, textures, bitmaps (WIC) |
| Text | `SpRichText*` (305…309), `SpSimpleTextMeasureAndRasterize` (318), `SpFreeTextBitmap` (178), `SpLoadFontResource` (241), `SpGetIsRtlLocale` (211) | DirectWrite layout and rasterisation |
| Automation | `SpAutomation*` (116…121), `SpDisableAutomation` (163) | UI Automation and the UIX automation channel ([Named objects](#named-objects)) |
| Files, XML, registry | `SpFileDownload` (169), `SpFileDownloadClose` (170), `SpFileDownloadGetBuffer` (171), `SpFileDownloadShutdown` (172), `SpXmlLite*` (351…365), `SpRegNotifyChangeKey` (292), `SpRegRevokeNotifyChangeKey` (293), `SpLoadLibrary` (242), `SpFreeLibrary` (177), `SpFindResource` (175), `SpLoadString` (243), `SpGetModuleHandle` (216), `SpGetModuleFileName` (215) | See [Dependencies](#dependencies) |
| Tracing and time | `SpInitializeEventTracing` (235), `SpUninitializeEventTracing` (342), `SpRegisterEventTracingControlCallback` (294), `SpInitializeTracing` (236), `SpUninitializeTracing` (343), `SpUpdateTraceSettings` (347), `SpTraceEvent` (320), `SpLogTrace` (244), `SpReportAssertionFailure` (303), `SpDoDebugCommand` (166), `SpGetLocalTime` (212), `SpFileTimeToSystemTime` (173), `SpSystemTimeToFileTime` (319) | [ETW](#etw), debug trace file |
| Native services | `SpRegisterNativeServicesCallbacks` (295), `SpUnregisterNativeServicesCallbacks` (344), `SpGetNativeServicesObject` (217) | Callbacks of the host |

The exports analysed:

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 234 | `SpInit` | 0x10054614 | `init *`: +0x04, +0x08, +0x0C, +0x14 copied into the `ContextInitArgs` (24 bytes) of `System::ObjectSystem::Context::Build_`, +0x10 passed to `ObCreateClassObject` for the class `Splash::Messaging::Broker` when ≠ 0, +0x1C byte: register the context with the watchdog; +0x08, +0x0C, +0x18 written back |
| 341 | `SpUninit` | 0x1002E020 | none: unregisters the current context from the watchdog, removes its profiler, destroys it |
| 301 | `SpRenderThreadInit` | 0x10057D90 | `InitArgs *`, `MessageThread **out`: profiler of the current context named "ApplicationThread", creates the render thread ([Startup](#startup)) |
| 302 | `SpRenderThreadUninit` | 0x100201CC | `MessageThread *`: `EtwProfile::Uninitialize`, deletes the thread object |
| 311 | `SpSetCompositorMode` | 0x10067990 | `Splash::ICompositorCallback *`: sets the compositor mode flag (`byte_100A9F5B`) and `Engine::Core::CoDevice::s_pCompositorCallback`; returns 0 |
| 110 | `SpInCompositorMode` | 0x1005A9AC | none: returns the flag |
| 200 | `SpGetCompositorContentPrivacyLevel` | 0x10061BDC | `x`: calls `ICompositorCallback::GetContentPrivacyLevel(x)` (vtable +0x1C) |
| 298 | `SpRegisterWaitHandler` | 0x100553CC | `HANDLE`, `callback`, `context`, `void **out`, `BYTE`: wraps them in an `ExternalWaitHandler` (20 bytes, signature 0x4EA1D7E5 at +4) registered with the dispatcher of the current context; the callback runs on that thread when the handle is signalled |
| 346 | `SpUnregisterWaitHandler` | 0x100292DC | `void *handler`: unregisters and frees it |
| 167 | `SpEnableWaitHandler` | 0x1009D100 | `void *handler`, `BOOL enable`: registers / unregisters it again |
| 135 | `SpCoreUIInitialize` | 0x10063CD4 | `void **out`: `CoreMessaging!CoreUICreate` |
| 242 | `SpLoadLibrary` | 0x100597DC | `LPCWSTR name`, `BOOL asDataFile`, `HMODULE *out`: `LoadLibraryExW`; last error kept in `g_dwLastLoadLibraryFailure` |
| 349 | `SpVideoConnect2` | 0x1002E2D8 | `UINT64 id ?`, `LPCWSTR portName`, `callback`, `VideoCallbackArgs *`: posts `VideoSessionManager::VideoConnectWorker` to the render thread (`SpInvoke`) |
| 350 | `SpVideoDisconnect` | 0x1002E284 | posts `VideoSessionManager::VideoDisconnectWorker` |
| 317 | `SpSetWatchDogCallback` | 0x1009E4CC | `void (*)(DWORD)`, `DWORD timeoutMs`: watchdog of the contexts (`Components::eCM::WatchdogManager`) |
| 313 | `SpSetFrameworkRunningState` | 0x10062DC0 | `bool`: `WatchdogManager::s_fFrameworkUpAndRunning` |
| 232 | `SpImagingInit` | 0x10063A34 | none: `WICCreateImagingFactory_Proxy(567, …)` once, reference counted |
| 235 | `SpInitializeEventTracing` | 0x1005394C | registers the ETW providers ([ETW](#etw)) |
| 347 | `SpUpdateTraceSettings` | 0x10053E18 | `LPCWSTR traceFile` (or `L"stdout"`, NULL closes it), `LPCWSTR linePrefix`, `BOOL toDebugger`, `BOOL showCategories`, `BOOL timedLines` |
| 292 | `SpRegNotifyChangeKey` | 0x100663BC | `HKEY root`, `LPCWSTR subKey`, `callback`, `context`, `RegChangeNotifyState **out`: `RegCreateKeyExW`, then `RegNotifyChangeKeyValue(subtree, filter 7)` on an event watched by the dispatcher |
| 119 | `SpAutomationGetAppFolderPath` | 0x1007CF4C | `WCHAR *path` (`MAX_PATH`): `SHGetSpecialFolderPathW(NULL, path, CSIDL_APPDATA, TRUE)` |

### Startup

The entry point is `SplashDllEntryPoint` (0x10057930), not the CRT one: on `DLL_PROCESS_ATTACH` it keeps the module handle (`g_hDll`) and calls `StPreInit` (process heap, `Engine::Runtime` pre-initialisation, TLS slot of the contexts), then `_DllMainCRTStartup` (0x1006957C). `DllMain` (0x10099588) calls `StInit`, the initialisation of every subsystem (`Init__Engine__Object`, `Init__Engine__Api`, `Init__Engine__Core`, `Init__Components__Animations`, `Init__Components__Desktop`, `Init__Components__eCM`, `Init__Drivers__Common`, `Init__Drivers__Direct3D11`), then `StPostInit`; on detach `StUninit`, and `SplashDllEntryPoint` frees the two TLS slots (contexts, threads) and destroys the process heap.

The engine itself is started by the host through the exports: `SpInit` builds the UIX context of the calling thread (the application thread); `SpRenderThreadInit` creates the render thread `Components::eCM::MessageThread::Create` (0x10057C54): a suspended `System::Threading::Thread` named "Render Thread (Splash)" (`RenderThread`), resumed, then waits for its start event.

The Direct3D device (`Drivers::Direct3D11::Device::ApiCreate`, 0x10099A50): dynamic surface pooling is enabled when `GlobalMemoryStatusEx` reports at least 256 MB of physical memory (`IsDynamicPoolingEnabled`, 0x10063C88); the frame callback is `Device::OnComposition` in compositor mode, `Device::OnRender` otherwise; `HKLM\SOFTWARE\Microsoft\Splash` `PresentInterval` and `EnableDebugClears` are read; the device is named "Device 0x%p (sec)" for the frame rate counter.

### Compositor mode

`SpSetCompositorMode` is called by [CompServer.dll](./compserver.md#initializecompositor-0x10017dc4) in the shell. With the flag set:
- `Drivers::Direct3D11::Device` composes through the callback (`Device::InitializeDx`, `Device::OnComposition`, `SurfacePool::CreateExternalProvider` call it) instead of presenting its own frames, and the ETW provider `Microsoft-WindowsMobile-Compositor` is registered;
- `Components::eCM::FormWindow::CreateFormWindow` (0x10064A04) creates the touch input host with flags 7 (14 otherwise) and the text input host as host, registers the navigation window, and connects to the CoreMessaging endpoint `System\RotationManager` (interface `{5DD528E4-51E6-4B28-89A2-71173F3B8F1D}`);
- `SystemInputRouter::TouchProcess`, `TouchDevice::PerformDwmHitTest` and `CoWindow::ApiSetForegroundWindow` call the callback (touch points, DWM input hit test, foreground window: `OnTouchPointsChanged`, `DwmInputHitTestRequest`… in CompServer).

### Input devices

`InputStateManager` reads the input drivers directly (ETW provider `MICROSOFT_WINDOWSPHONE_INPUT`, events `InputReader_*`).

`InputStateManager::Initialize` (0x10066860):
1. Creates the manual-reset events `TchReadyEvent` and `KbdReadyEvent`.
2. `CM_Register_Notification` for the device interfaces `GUID_WP_DEVINTERFACE_TCH` `{2C05CE1A-75E8-4EA7-A70A-E323B072258C}` and `GUID_DEVINTERFACE_KEYBOARD` `{884B96C3-56EF-11D1-BC8C-00A0C91405DD}` (callback `DeviceEventCallbackStatic`, which sets the ready events).
3. Screen size with `GetDeviceCaps(HORZRES / VERTRES)`.
4. `CheckAndInitialize0DButtons` (0x10066BA0): three button positions below the screen (y = height + 50; x = 1/6, 1/2 and 5/6 of the width; types 2, 1, 3), then `HKLM\SYSTEM\TOUCH\BUTTONS`: `Count` (≤ 3), `Vibrate`, and for each `SYSTEM\TOUCH\BUTTONS\<n>` the `VKey` of the button, converted to a button type (`ConvertVirtualKeyToButtonType`).
5. `InitializeSharedInputGlobal` (0x100669B8): `InitConnectedStandbyControl` ([RPC](#rpc)), first `UpdateLastInputTimestamp`, then `RegisterSharedInputGlobal(&this->shared)` from `api-ms-win-rtcore-session-l1-1-0.dll`.

| Device | Opened by | Read |
|--------|-----------|------|
| `\Device\TouchClass0` ([tchhid.sys](../drivers/tchhid.md)) | `ConnectDriverTouch` (0x10060908) | Overlapped `ReadFile` of 0xA8C bytes (`TriggerAsyncRead`), parsed by `ParseDataTouch`; the driver returns one [touch report](../drivers/tchhid.md#touch-report) per read |
| `\Device\WPKeyboardClass` ([kbdclasswp.sys](../drivers/kbdclasswp.md)) | `ConnectDriverKeyboard` (0x10060734) | 0x78 bytes (the driver returns one 12-byte `KEYBOARD_INPUT_DATA` record per read), `ParseDataKeyboard` (hardware buttons and keyboard) |
| `\Device\PointerClass0` ([mouclasswp.sys](../drivers/mouclasswp.md)) | `ConnectDriverTouchMouse` (0x10060EB8) | 0x78 bytes (up to 5 24-byte `MOUSE_INPUT_DATA` records), `ParseDataTouchMouse` |

The devices are opened with `NtCreateFile` (access `FILE_READ_DATA`); if the name doesn't exist yet (`STATUS_OBJECT_NAME_NOT_FOUND`), the touch and keyboard readers wait up to 10 s for their ready event and try again. No IOCTL is sent: the drivers are only read. The `Disconnect*` functions cancel the read (`CancelIoEx`).

`DeliverTouchEvent` (0x1008FB50): for a touch frame flagged 0x100 it checks `ShellChromeAPI!Shell_IsLocked` (touches on the lock screen don't count as user activity), otherwise calls `UpdateLastInputTimestamp(GetTickCount())`; it hit-tests every contact through the owner, adds the DWM input transform when needed (`AddDwmInputRoutingData`, 0x10083B1C: `NtQueryCompositionInputQueueAndTransform(…, 3, …)` of [DCOMP.DLL](./dcomp.md), the contacts are divided by the projective term of the returned matrix), then delivers the `TouchInfo` (contacts of 52 bytes from +0x14, count at +0x13).

`UpdateLastInputTimestamp` (0x10060AF0): publishes `WNF_INP_USER_ACTIVITY` (no data) at most every 500 ms; if the screen is in connected standby (flag +0x1128), calls `SetConnectedStandbyMode` and clears the flag.

CoreMessaging endpoints used by the input:

| Endpoint | Function | Use |
|----------|----------|-----|
| `System\TouchInputRouter` | `TouchInputHost::Initialize` (0x10064290), `TouchDevice::Initialize` (0x1008A344, security descriptor of the transient object `Input\Public.AlpcPort\Server`) | Touch routing to the windows |
| `System\TouchInputRedirection`, interface `TouchInputRedirection` `{548C27D0-A710-4EC7-92D1-67A7DEE54EFB}` | `UserRedirector::Initialize` (0x100661FC), security descriptor `Input\Injection.AlpcPort\Server` | Redirection of the system gestures (edge, magnifier) |
| `IRemoteInputInjectionApi` `{9978C53C-56B6-4C55-BA5F-5495E889E2FE}` | `ReaderInjectionEvent::Initialize` (0x10067420), port with the security descriptor `Input\Injection.AlpcPort\Server` (`SharedMessagePortRefPtr::Initialize`) | Injected input ([InputInjection.dll](./inputinjection.md)) ? |
| `System\RemoteTextInputProcessor` `{B30E303E-7340-4446-BD7B-C37FDEE42ABC}` | `KeyboardDevice::ConnectToInputProcessor` (0x1001D7C4) | Key events to the text input processor |

The other transient object names of the table at 0x10013B70 (`Input\Core.AlpcPort\Server`, `Input\Service…`, `Input\Features…`, `Input\Test…`, `Input\Locales…`) and the strings `System\RawShellButtonRouterInput`, `System\Accessibility` weren't traced to a use.

Edge gestures: `EdgeGestureRedirector::EnsureEdgeThresholds` (0x1005A844) computes 40 px scaled to the screen (480 × 800 reference) for each edge, overridden by `HKLM\System\Touch\EdgeGestureThresholds` `Top`, `Bottom`, `Left`, `Right`.

### Magnifier

`Components::eCM::MagnifierRedirector` is the screen magnifier gesture.
- Enabled by `HKLM\System\Accessibility\ScreenMagnifier`, watched (`RegNotifyEnableCallback`, 0x1006632C): state 1 (enabled) or 0 (off).
- On the first gesture (`OnGestureUpdate`, 0x10097154), if the prompt wasn't shown (`HaveShownPrompt`: OOBE done or headless, or `HKLM\System\Accessibility\ScreenMagARDConsent` ≠ 0), a thread `ShowMagPrompt` shows an action dialog (`ShellChromeAPI!Shl::ActionDialog::Create`, texts 10092…10095 of `AccessibilityCPLRes.dll`); the answer disables the magnifier in the registry (`DisableScreenMagInReg`) or switches it on, and `SavePromptAsShown` writes `System\Accessibility`.
- Test hooks: `HKLM\SOFTWARE\Microsoft\Splash\Magnifier` (`Enabled`, `MagnificationOverride`, `MagnificationPosLeft`, `MagnificationPosTop`, `MagnificationFactor` as a string clamped to 1…8), `Touch_Test_Sync_Event` set after a redirected input.
- `SetMagnifierState` (0x1007AF70) and `SetEffectiveMagnificationState` (0x1007AF30) publish `WNF_SHL_MAGNIFIER_STATE_CHANGED` ([WNF states](#wnf-states)).

`GetOobeState` (0x1007B020) reads `HKLM\Software\Microsoft\Shell\Oobe`: `Done` ≠ 0 → 0x7FFFFFFF, `OobeHeadless` ≠ 0 → 0x7FFFFFFD, `NextSection` ≠ 0 → 0, else −1.

### Video composition

`SpVideoConnect2` → `Engine::Core::VideoSession::InitVideoProvider` (0x10099738) → `VideoComposition::VideoProvider::CreateInstance` (0x10052898, registers the ETW provider `MICROSOFT_WINDOWSPHONE_VIDEOPROVIDER`), which connects to the ALPC port named by the caller (`Alpc::Client<VideoProvider,96>::ConnectToServer`, 0x10052BD8): `NtAlpcConnectPort` with port attributes flags 0x70000, QoS impersonation level 2, maximum message length 0x60, flags 0x20000 (`ALPC_MSGFLG_SYNC_REQUEST`), timeout 500 ms, and a context message attribute (0x20000000). The provider then receives the frames (`ProcessInput`: `NtAlpcSendWaitReceivePort`, `NtAlpcAcceptConnectPort`), opens the GPU synchronisation event of each frame by its GUID (`VideoFrame::SetGpuSyncEvent`: `StringFromGUID2` + `OpenEventW`), and presents them as video sprites. The video source (port name) isn't known from this binary.

### RPC

The connected standby client, identical to the one of [MobileUI.exe](../applications/mobileui.md#rpc-clients) and [ShellChrome.dll](./shellchrome.md#rpc-clients) (same function names):
1. `InitConnectedStandbyControl` (0x10066A40, from `InitializeSharedInputGlobal`): returns `HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS)` if already connected; enables `SeShutdownPrivilege` (`SetPrivileges`, 0x10082480) during the connection; `RpcStringBindingComposeW(NULL, L"ncalrpc", NULL, NULL, NULL)` (dynamic endpoint), `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW(NULL principal, level 6 PKT_PRIVACY, service 10 WINNT, QoS version 5, impersonation 3)`; opnum 0; then registers the ETW provider `Microsoft-WindowsPhone-Power`.
2. `SetConnectedStandbyMode` (0x1008A428): ETW event `ScreenOn`, opnum 1 with 0; on `RPC_E_DISCONNECTED` (0x80010006) `ReestablishConnection` (opnum 0 again, with the privilege) and one retry.
3. `DeinitConnectedStandbyControl` (0x10082414): opnum 4, `RpcBindingFree`, unregisters the provider.

Interface `{85F9809B-3B25-4EEB-8160-FA4A60B80746}` version 0.0 (stub descriptor 0x1000EE50).

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `SvcInitConnectedStandbyControl` (0x10066B80) | `InitConnectedStandbyControl`, `ReestablishConnection` | binding, `[out]` context handle | Open |
| 1 | `NdrClientCall2` in `SetConnectedStandbyMode` | `UpdateLastInputTimestamp` | `[in]` context handle, `[in] small` 0 | Leave connected standby (screen on) |
| 4 | `NdrClientCall2` in `DeinitConnectedStandbyControl` | `InputStateManager` destructor | `[in,out]` context handle | Close |

The server isn't known (not analysed).

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x41960024A3BC0875 `WNF_INP_USER_ACTIVITY` (`.text:0x10013B8C`) | `INP`, 1 | none | Published by `UpdateLastInputTimestamp` on input, at most every 500 ms |
| 0x418A063EA3BD1875 `WNF_SHL_MAGNIFIER_STATE_CHANGED` (`.text:0x10017CE4`) | `SHL`, 35 | 4 bytes | Published by `SetMagnifierState` (the state: 0 off, 1 enabled, 2 magnifying) and `SetEffectiveMagnificationState` (2 magnifying, 1 not) |

Both are version 1, well-known, system scope, not permanent (`wnf.py`). The names are the symbols of the PDB. `FormWindow::DestroyFormWindow` unsubscribes a WNF subscription (+0x100 of the window) whose subscription isn't in this binary's imports (made through another module ?).

### Registry

| Key | Values | Read by |
|-----|--------|---------|
| `HKLM\SOFTWARE\Microsoft\Splash` | `PresentInterval`, `EnableDebugClears` | `Device::ApiCreate` |
| `HKLM\SOFTWARE\Microsoft\Splash\Magnifier` | `Enabled`, `MagnificationOverride`, `MagnificationPosLeft`, `MagnificationPosTop`, `MagnificationFactor` | [Magnifier](#magnifier) test hooks |
| `HKLM\SOFTWARE\Microsoft\UIX` | `VideoScalerBitmask` (`VideoSession::GetVideoScalerBitmask`, −1 if absent), `SlowCodeModelMsec` (threshold of the slow code model calls, default 50) | |
| `HKCU\Software\Microsoft\UIX` | `DWrite` (0 = no DirectWrite) | `SplashTextFactory` |
| `HKLM\Software\Microsoft\Shell\Input\<width>x<height>`, else `HKLM\Software\Microsoft\Shell\Input` | Gesture settings: `Motion*` (`MotionFriction`, `MotionParkingSpeed`, `MotionMaximumSpeed`, `MotionCompress*`, `MotionSpring*`, `MotionDamperFactor`), `Editing*`, `CaretPlacementArrow*`, `PinchStretchMinimumUpdateThreshold`, `Flick*`, `DoubleTap*`, `TapAnd*`, `Crane*`, `Drag*`, `TwoFinger*`; `TouchTrackerLatency` (`TouchTracker::ReadRegistryForParameters`) | `GestureSession::OpenConfigRegKey` (0x10059488) |
| `HKLM\SYSTEM\TOUCH\DISPLAYPROPERTIES` | `DisplayWidth10um`, `DisplayHeight10um` (default 5000 × 8300, i.e. 50 × 83 mm): physical scale factor of the gestures | `GestureSession::RefreshScreenSize` |
| `HKLM\SYSTEM\TOUCH\BUTTONS`, `…\BUTTONS\<n>` | `Count`, `Vibrate`; `VKey` | `CheckAndInitialize0DButtons` |
| `HKLM\System\Touch\EdgeGestureThresholds` | `Top`, `Bottom`, `Left`, `Right` | `EnsureEdgeThresholds` |
| `HKLM\System\Accessibility` | `ScreenMagnifier`, `ScreenMagARDConsent` (written: values not identified) | [Magnifier](#magnifier) |
| `HKLM\Software\Microsoft\Shell\Oobe` | `Done`, `OobeHeadless`, `NextSection` | `GetOobeState` |

[ShellChrome.dll](./shellchrome.md) reads the same display and gesture keys.

### Named objects

| Name | Function | Use |
|------|----------|-----|
| `TchReadyEvent`, `KbdReadyEvent` | `InputStateManager::Initialize` (`CreateEventW`, manual reset) | Touch / keyboard device arrived |
| `UIX_AUTOMATIONLISTENER_CONNECT_EVENT_<pid>`, `…_CONNECT_PROCESSED_EVENT_<pid>`, `…_BUFFER_<pid>` (file mapping), `…_EVT_MUTEX_<pid>` (`%08X` of the own process id) | `AutomationConnectionListener::Initialize` (0x1005590C), created | The process waits for UIX automation clients |
| `UIX_AUTOMATION_DISCONNECT_EVENT_<id>`, `…_SEND_EVENT_`, `…_RECV_EVENT_`, `…_BUFFER_` (mapping), `…_EVT_EVENT_`, `…_EVT_MUTEX_` (`%08X_%08X_%02X`) | `AutomationConnection::Connect` (0x10056774), opened (`OpenProcessForQuery` on the other process) | Connection to an automation peer |
| `Touch_Test_Sync_Event` | `SystemInputRedirector::RaiseTestEventForRedirectedInput` (`OpenEventA` + `SetEvent`) | Test synchronisation |
| `Test_Touch_Disconnect_Sync_Event`, `Test_Keyboard_Disconnect_Sync_Event` | strings only (not traced) | Test hooks ? |

### ETW

| Provider | Registered by | Events |
|----------|---------------|--------|
| `Microsoft-WindowsMobile-Splash` `{872C8950-0DEF-4D5B-83F6-57DD027F88CE}` | `EtwProfile::Initialize` (`SpInitializeEventTracing`) | Frame rate, dropped frames, render profile (`EtwProfile::*`) |
| `Microsoft-WindowsMobile-Compositor` `{85FFFBA1-CF12-402C-B9B3-29A3217BB007}` | same, only in [compositor mode](#compositor-mode) | Compositor profile (`MobileEtwProfile` ?) |
| `MICROSOFT_WINDOWSPHONE_INPUT` `{ED07CE1C-CEE3-41E0-93E2-EEB312301848}` | `InputStateManager` and `TouchInputHost` constructors, `g_EtwLogger` | Error with function name and line (`Template_sqq`), `InputReader_TouchProcess_Start/Stop`, `InputReader_LogTouchInfo`, `InputReader_LogTouchContact`; the same provider as [InputInjection.dll](./inputinjection.md#etw) and [UIXMobile.dll](./uixmobile.md) |
| `MICROSOFT_WINDOWSPHONE_VIDEOPROVIDER` `{D5E118BB-E2CA-42E5-8F5A-BA2F9B13660A}` | `VideoProvider::CreateInstance` | Assertions (`_ETWERROR`: Id 10001, level 2, task 10000, keyword 0x400000) |
| `Microsoft-WindowsPhone-Power` `{5C103042-7E75-4629-A748-BDFA67607FAC}` | `InitConnectedStandbyControl` | `ScreenOn` (Id 504, level 4, task 2, keyword 0x2, enable bit 0x1) before RPC opnum 1 |
