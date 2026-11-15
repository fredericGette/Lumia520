## DCOMP.DLL

The DirectComposition client library of Windows Phone 8.1: the user-mode half of the composition API, and the win32k system call stubs of the compositor.  
`DCOMP.DLL` is a medium-sized DLL (248 920 bytes, 1283 functions, all named from the PDB `dcomp.pdb`; the source paths in the strings are `windows\dwm\…`). It's the desktop Windows 8.1 `dcomp.dll`. It does two jobs:
- It implements the DirectComposition COM objects (`CDevice`, visuals, surfaces, virtual surfaces, transforms, animations, primitives…). They are proxies of resources that live in the kernel (win32k): each method writes a property of the resource through a `NtDComposition*` system call. The surfaces are drawn with the Direct3D 11 / Direct2D device given by the application, in atlases and tiles (`CAtlasSurface`, `CTileClump`, `CVirtualSurface`).
- It contains the user-mode stubs of 245 win32k system calls (0x1000…0x10F4): composition, token manager, composition input sinks, D3DKMT (`NtGdiDdDDI*`), OPM, display configuration, and the phone "Moderncore" calls (`NtModerncoreRegisterCompositorProcess`, `NtModerncoreProcessConnect`, …). 32 of them are exported by ordinal for the compositor.

[DWMCORE.DLL](./dwmcore.md) imports 33 exports by ordinal: 26 system calls (connection, DWM channel, frames, token manager, input sinks, surface statistics) and 7 surface wrappers, and [DWMMOBILE.DLL](./dwmmobile.md) imports only ordinal 1014 (`ZwDCompositionReferenceSharedResourceOnDwmChannel`), to import the shared visual of each redirected window (resource type 25) into its DWM channel. The applications that use `DCompositionCreateDevice*` weren't identified.

Location on the phone: `C:\Windows\System32\dcomp.dll` ? (extracted with `DWMCORE.DLL`, `DWMAPI.DLL`, `DWMMOBILE.DLL`, `CompClient.dll` and `CompServer.dll`).  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-rtcore-ntuser-private-l1-1-1.dll | `CreateDCompositionHwndTarget`, `DestroyDCompositionHwndTarget` |
| ntdll.dll | `RtlCreateHeap`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlDestroyHeap`, `NtUnmapViewOfSection`, `RtlGetLastNtStatus`, `NtQuerySystemInformation`, `DbgPrintEx`, `DbgPrompt` |
| api-ms-win-core-memory-l1-1-2.dll | `MapViewOfFile`, `VirtualAlloc`, `VirtualFree` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapReAlloc`, `HeapFree` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `Sleep` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetNativeSystemInfo`, `GetTickCount`, `GetTickCount64` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceFrequency` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleW`, `GetProcAddress` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `GetCurrentProcessId`, `GetCurrentThread`, `GetCurrentThreadId`, `TerminateThread`, `TerminateProcess`, `ExitProcess` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlCaptureStackBackTrace`, `RtlRaiseException`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1.dll | `IsDebuggerPresent` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| msvcrt.dll | `malloc`, `free`, `memcpy`, `memset`, `memcmp`, `wcslen`, `qsort`, `_finite`, `operator new[]`/`delete[]`, `_purecall`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

Delay-loaded (`ResolveDelayLoadedAPI`):

| DLL | Functions |
|-----|-----------|
| ext-ms-win-ntuser-private-l1-1-1.dll | `WaitForRedirectionStartComplete` |
| ext-ms-win-ntuser-rectangle-ext-l1-1-0.dll | `IsRectEmpty`, `SetRectEmpty`, `IntersectRect` |
| ext-ms-win-ntuser-window-l1-1-2.dll | `IsWindow`, `GetWindowThreadProcessId` |
| ext-ms-win-rtcore-ntuser-sysparams-l1-1-0.dll | `EnumDisplayDevicesW`, `EnumDisplaySettingsW` |

The msvcrt, rtlsupport, errorhandling, processthreads (except `GetCurrentProcessId`), `DbgPrompt`, `IsDebuggerPresent` and `NtQuerySystemInformation` imports are the Visual C++ DLL CRT startup, `/GS` cookie and the assertion / instrumentation break code. There is no import of d3d11, dxgi or d2d1: the Direct3D / Direct2D objects all come from the device that the application passes to `DCompositionCreateDevice*`.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| win32k (DirectComposition, token manager, D3DKMT, Moderncore) | `SVC 1` system calls 0x1000…0x10F4 ([System calls](#system-calls)) | All the composition resources, channels, frames and surfaces live in the kernel |
| `kernel32.dll` | `GetModuleHandleW(L"kernel32.dll")`, `GetProcAddress("WerRegisterMemoryBlock")` (`EnsureStackCaptureRegisteredWithWER`, 0x1002234C) | Registers the stack capture buffer (`g_StackCaptureFrames`, 6144 bytes, and `g_nCurrentStackCaptureIndex`) for the error reports |
| The application's Direct3D 11 / Direct2D device | `IUnknown` passed to `DCompositionCreateDevice*`, `QueryInterface` (`CDxDevice::Initialize`, 0x10019EF0) | Drawing of the surfaces ([CDxDevice](#cdxdevice)) |

No DLL is loaded with `LoadLibrary*`, and no process or COM server is started (the COM objects are only created by the exports).

### Exports

The 48 exports. Apart from the three `DCompositionCreate*` functions, they're exported by ordinal only. The names below are the ones in the PDB.

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 520 | `DCompositionCreateDevice` | 0x1001BECC | `IUnknown *renderingDevice, REFIID iid, void **device` ([below](#dcompositioncreatedevice-0x1001becc-dcompositioncreatedevice2-0x1000b394)) |
| 1017 | `DCompositionCreateDevice2` | 0x1000B394 | `IUnknown *renderingDevice, REFIID iid, void **device` |
| 521 | `DCompositionCreateSurfaceHandle` | 0x1001CE58 | `DWORD desiredAccess, SECURITY_ATTRIBUTES *sa, HANDLE *surfaceHandle` ([below](#dcompositioncreatesurfacehandle-0x1001ce58)) |
| 1018 | `DCompositionRegisterThumbnailVisual` | 0x10022BEC | 5 arguments, passed to `NtDCompositionRegisterThumbnailVisual` (0x1033) |
| 500 | `ValidateCompositionSurfaceHandle` | 0x1001CE88 | → `NtValidateCompositionSurfaceHandle` (0x10F4) |
| 501 | `BindCompositionSurface` | 0x1001D040 | `a, b, void *c` → `ZwBindCompositionSurface(a, b, c, c + 8)` (0x1015) |
| 502 | `UnBindCompositionSurface` | 0x1001D300 | → `NtUnBindCompositionSurface` (0x10E4) |
| 503 | `QueryCompositionSurfaceBinding` | 0x1001D010 | → `ZwQueryCompositionSurfaceBinding` (0x10D7) |
| 504 | `NotifyPresentToCompositionSurface` | 0x10022C70 | → `ZwNotifyPresentToCompositionSurface` (0x10D0) |
| 505 | `QueryCompositionSurfaceStatistics` | 0x10022C5C | → `NtQueryCompositionSurfaceStatistics` (0x10D9) |
| 506 | `OpenCompositionSurfaceSectionInfo` | 0x10022C3C | → `NtOpenCompositionSurfaceSectionInfo` (0x10D2) |
| 507 | `OpenCompositionSurfaceSwapChainHandleInfo` | 0x1001CFF4 | → `ZwOpenCompositionSurfaceSwapChainHandleInfo` (0x10D3) |
| 508 | `QueryCompositionSurfaceRenderingRealization` | 0x1001D02C | → `ZwQueryCompositionSurfaceRenderingRealization` (0x10D8) |
| 509 | `OpenCompositionSurfaceDirtyRegion` | 0x1001CEC4 | → `NtOpenCompositionSurfaceDirtyRegion` (0x10D1) |
| 515 | `SignalGpuFenceInFrame` | 0x10022C1C | `UINT64 a, UINT64 b, …`: the values are passed by address to `ZwDCompositionSignalGpuFence` (0x1044) |
| 510…519, 1000…1016, 1019…1026 | system calls | 0x10005CCC…0x10006344 | see [System calls](#system-calls) |

The wrappers (500…509, 515, 521, 1018) return the NTSTATUS of the system call converted by `CDevice::HRESULTFromNTSTATUS` (0x1001260C): 0 → `S_OK`, `STATUS_UNSUCCESSFUL` → `E_FAIL`, `STATUS_NOT_IMPLEMENTED` → `E_NOTIMPL`, `STATUS_INVALID_HANDLE` / `STATUS_OBJECT_TYPE_MISMATCH` → `E_HANDLE`, `STATUS_INVALID_PARAMETER` / `STATUS_NOT_SUPPORTED` → `E_INVALIDARG`, `STATUS_NO_MEMORY` → `E_OUTOFMEMORY`, `STATUS_ACCESS_DENIED` → `E_ACCESSDENIED`, 0x803F0006 → 0x88980800 (`DCOMPOSITION_ERROR_WINDOW_ALREADY_COMPOSED`), anything else → `HRESULT_FROM_NT` (status | 0x10000000). The system call stubs return the raw NTSTATUS.

### Startup

`_DllMainCRTStartup` (0x1001E8FC): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then `__DllMainCRTStartup` (0x1001E608: `_CRT_INIT`, then `DllMain`).  
`DllMain` (0x10025434):
- `DLL_PROCESS_ATTACH`: `AvCreateProcessHeap` (0x1001E0CC: the WPF-style heap wrapper `WPF::g_pProcessHeap` on top of `GetProcessHeap`), `CProxyTable::CalculateProxyTableSize` (0x1001E214: page size from `GetNativeSystemInfo`, proxies per page = (page size − 20) / 12), then registers the ETW provider (`McGenEventRegister`). Fails the load if the heap can't be allocated.
- `DLL_PROCESS_DETACH`: `AvDestroyProcessHeap`, `McGenEventUnregister`.

There is no other initialisation: everything is created by `DCompositionCreateDevice*`.

### DCompositionCreateDevice (0x1001BECC), DCompositionCreateDevice2 (0x1000B394)

1. `device` NULL → `E_INVALIDARG`.
2. Checks the IID: `DCompositionCreateDevice` only accepts `IDCompositionDevice` {C37EA93A-E7AA-450D-B16F-9746CB0407F3}. `DCompositionCreateDevice2` accepts `IDCompositionDevice`, `IDCompositionDesktopDevice` {5F4633FE-1E08-4CB8-8C75-CE24333F5602} and {D14B6158-C3FA-4BCE-9C1F-B61D8665EAB0} (a partner interface?). Note that `IDCompositionDevice2` {75F6468D-1B8E-447C-9BC6-75FEA80B5B25} isn't in the list, though `QueryInterface` returns it later. Another IID → `E_NOINTERFACE`.
3. `CDevice::Create` (0x10019120) with device version 1 or 2: allocates the 0xB0-byte [CDevice](#cdevice), then `CDevice::Initialize`. Writes the ETW event `DCOMPEVENT_DEVICE_CREATE` (device, channel) when enable bit 4 is set.
4. `QueryInterface(iid)` on the device, releases the creation reference. On failure `*device` = NULL.

`CDevice::Initialize` (0x10019184, `/GS`) works under the device critical section:
1. For the first device of the process only (`CDevice::s_qpcFrequency` still 0): `QueryPerformanceFrequency` (failure → `E_FAIL`) and `GetFrameStatistics` (`ZwDCompositionGetFrameStatistics`, 0x102E; a value it returns is kept in `CDevice::s_minSafeFeatureLevel`).
2. If `renderingDevice` isn't NULL: creates the default surface factory (`CSurfaceFactory::Create`, 0x1001A4CC, 184 bytes): [CDxDevice](#cdxdevice) on that device, a scratch surface manager and a surface manager. It's stored at +0x94.
3. `ZwDCompositionCreateChannel(&device->channel)` (0x1020): the kernel channel that receives the resource commands.
4. Allocates the virtual surface optimiser (16 bytes, +0x74), sets +0x34 = 1 and returns `S_OK`. Out of memory → `E_OUTOFMEMORY`.

### CDevice

The object behind every device interface (`CDevice::Create`, 0xB0 bytes from the process heap):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `IDCompositionDevice` (0x10001688): `Commit`, `WaitForCommitCompletion`, `GetFrameStatistics`, `CreateTargetForHwnd`, `CreateVisual`, `CreateSurface`, `CreateVirtualSurface`, `CreateSurfaceFromHandle`, `CreateSurfaceFromHwnd`, the transforms, `CreateEffectGroup`, `CreateRectangleClip`, `CreateAnimation`, `CheckDeviceState` |
| 0x04 | 4 | vtable `IDCompositionDesktopDevicePartner2` (0x100015D0): the `IDCompositionDevice2` / `IDCompositionDesktopDevice` methods plus `CreateSharedResource`, `OpenSharedResource`, `OpenSharedResourceHandle`, `CreateAnimationTrigger`, `CreateGradientSurface`, `CreateScalar`, `CreateColor`, `CreatePrimitiveGroup`, `CreatePrimitive` (3 forms), `DrawPrimitiveGroup`, `EnableWhitePixelOptimization`, `OfferSurfaceResources`, `ReclaimSurfaceResources`, `DisableD2DStatePreservation`, `Flush`, `CreateYCbCrSurface`, `CreateSurfaceFromVisualSnapshot` |
| 0x08 | 4 | vtable `IDCompositionDeviceInternal` (0x1000159C): `HintSize`, `HintTiles`, `TelemetryTouchInteractionBegin/Update/End`, `SetCommitCompletionEvent`, `TelemetrySetApplicationId`, `TelemetryAnimationScenarioBegin/Reference/Unreference` |
| 0x0C | 4 | vtable `IDCompositionDeviceDebug` (0x10001588): `EnableDebugCounters`, `DisableDebugCounters` |
| 0x10 | 0x18 | Critical section of the device |
| 0x28 | 4 | Reference count |
| 0x2C | 4 | Kernel channel handle (`ZwDCompositionCreateChannel`), first argument of all the resource system calls |
| 0x30 | 4 | Device version: 1 (`DCompositionCreateDevice`) or 2 (`DCompositionCreateDevice2`) |
| 0x34 | 4 | Offer state: 1 normal, 2 offer requested (`OfferSurfaceResources`), 3 surfaces offered (done by the next `Commit`) |
| 0x3C | 0x14 | Dynamic array of [proxy tables](#proxy-tables) (data +0x3C, capacity +0x48, count +0x4C) |
| 0x50 | 4 | Batch id returned by the last `NtDCompositionCommitChannel`, + 1 |
| 0x54 | 4 | Current batch id (`ZwDCompositionCurrentBatchId`) |
| 0x58 | 4 | Last batch id seen; when it changes, the scratch and dead surfaces are collected |
| 0x5C | 4 | Non-zero while a surface is being drawn: `Commit` (version 1) and `OfferSurfaceResources` then fail with 0x88980801 (`DCOMPOSITION_ERROR_SURFACE_BEING_RENDERED`) |
| 0x60 | 0x14 | Array of objects whose pending reference is released at each `Commit` (count at +0x70) |
| 0x74 | 4 | `CVirtualSurfaceOptimizer` |
| 0x78 | 4 | List of `CPrimitiveGroup`s to rebuild at the next `Commit` |
| 0x7C | 8 | List of shared memory allocations waiting for the compositor (`CCompositorSynchronizedObject`) |
| 0x84 | 8 | List of unused `CSharedSection`s (freed after 4 s) |
| 0x8C | 8 | List ? |
| 0x94 | 4 | Default `CSurfaceFactory` (created from the rendering device) |
| 0x98 | 0xC | List of the surface factories (head at 0x9C) |
| 0xA4 | 4 | Deferred error, returned and cleared by the next `Commit` / `Flush` |
| 0xA8 | 8 | Counters cleared by `Commit` ? |

`QueryInterface` (on the base object): `IDCompositionDeviceInternal` {6B556968-2D25-11E2-99F6-8BC36088709B} → +0x08; `IDCompositionDevice` → +0x00 (version ≥ 1); `IDCompositionDevice2`, `IDCompositionDesktopDevice`, {D14B6158-…} and {69E42256-0D75-4C43-B817-044F4AD942E9} → +0x04 (version ≥ 2 only); `IDCompositionDeviceDebug` {A1A3C64A-224F-4A81-9773-4F03A89D3C6C} → +0x0C (version ≥ 2); `IUnknown` → +0x00.

### Proxy tables

Every COM object of a resource (visual, transform, surface proxy, animation…) is a 12-byte proxy (vtable, reference count, kernel resource handle) allocated in a proxy table:
- A proxy table is one page (`VirtualAlloc`, `MEM_COMMIT | MEM_RESERVE`, `PAGE_READWRITE`) with a 20-byte header (device, used count, next free index, index in the global list, free list) and (page size − 20) / 12 proxies (`CProxyTable::CreateProxyTable`, 0x1000A3C8).
- The tables are registered in the global `CProxyTable::s_proxyTableList` (256 entries, `s_csProxyTableCreation`). `CProxyTable::FromProxy` (0x10012634) finds the table of a proxy by rounding its address down to the page and checks it against that list. This lets the device check that an interface given to it is one of its own proxies (`CDevice::GetDeviceAndHandle`).
- `CreateVisual` (0x10010AE4), for example, takes a free proxy, calls `ZwDCompositionCreateResource(channel, 25, 0, &handle)` (0x1023, resource type 25 = visual), writes a resource creation ETW event (`DCOMPEVENT_RESOURCE_CREATION` ?, enable bit 1) and initialises the proxy with `CVisualProxy::vftable`. The other `Create*` functions do the same through `CDevice::CreateProxyInternal` with their resource type: 0x19 visual / HWND target root, 0x43 surface from a composition surface handle (`CreateSurfaceFromHandle`, integer property 0 = the handle), 0x45 HWND bitmap (`CreateSurfaceFromHwnd`, only for a window of the calling process: `IsWindow` + `GetWindowThreadProcessId`), 0x46 shared section, 0x4B visual snapshot (integer properties 1 and 2 = width, height, reference property 0 = the visual).
- The properties are set with `NtDCompositionSet{Integer,Float,Handle,Reference,ReferenceArray,Buffer,Animation}Property` (0x1041, 0x103F, 0x1040, 0x1043, 0x1042, 0x103D, 0x103C). The proxies are released with `NtDCompositionReleaseResource` (0x1035).

### CreateTargetForHwnd (0x100094A8)

1. Allocates a `CHwndTarget` (20 bytes: vtable, reference count, HWND, topmost flag, target visual proxy).
2. `CreateDCompositionHwndTarget(hwnd, topmost, &sharedHandle)` (win32k through `api-ms-win-rtcore-ntuser-private`); on failure the HRESULT comes from `RtlGetLastNtStatus`.
3. `CDevice::OpenSharedProxy(sharedHandle, 0x19, …)`: `NtDCompositionOpenSharedResource(channel, handle, type, &resource)` (0x1030) into a new proxy, then `CreateTargetVisualProxy`. The shared handle is closed.

The destructor (0x10007140) clears the root (`CTargetVisualProxy::SetRoot(NULL)`) and calls `DestroyDCompositionHwndTarget(hwnd, topmost)`.  
`CheckDeviceState` (0x10008204) asks every surface factory whether its Direct3D device is still valid. When one isn't, it reports the device as invalid and calls `WaitForRedirectionStartComplete`.

### Commit (0x10010CB8)

Under the device critical section:
1. Version 1 with a surface being drawn → 0x88980801.
2. Virtual surface optimiser (if `g_VSAllowOptimizer`): the virtual surfaces flagged for it, or untouched for 1000 ms or more (`GetTickCount64`), are optimised (trimmed and repacked).
3. Offer state 2 → `CDevice::HideSurfaces`.
4. Releases the pending references, `CSurfaceFactory::Present` on every surface factory (ends the drawing of the surfaces updated since the last commit), and rebuilds the dirty primitive groups (`CPrimitiveGroup::Rebuild`).
5. `NtDCompositionCommitChannel(channel, &batchId, &hasDeletedResources)` (0x101C). Stores batch id + 1 at +0x50. If resources were deleted, `CheckForDelayedDestructionObjects`.
6. `ZwDCompositionCurrentBatchId(channel, 1, &id)` (0x1024). When the id has changed, collects the scratch surfaces and the dead surfaces of each factory.
7. `CSurfaceManager::CapMaximumAllocations` on each factory (ETW `DCOMPEVENT_CAP_MAXIMUM_Start/Stop`). If a factory has 8 MB or more of surfaces pending and that's more than half of its total ?, the commit blocks: `CommitToKernel` + `WaitForCommitCompletionInternal` in a loop while `ShouldBlockForExcessivePending` (ETW `DCOMPEVENT_BLOCK_FOR_EXCESSIVE_PENDING_Start/Stop`).
8. Frees the shared sections unused for 4 s (0xFA0 ms), and the shared memory allocations that the compositor has released (ETW `DCOMPEVENT_FREE_FROM_SHARED_MEMORY_SECTION`, enable bit 0x10).
9. ETW `DCOMPEVENT_DEVICE_COMMIT` (device, channel, batch, current batch).
10. Offer state 2: `CommitToKernel`, waits for the completion, `OfferSurfaceResourcesInternal`, state = 3.

Returns the first error, or the deferred error at +0xA4.  
`WaitForCommitCompletion` = `WaitForCommitCompletionInternal(TRUE)`. `SetCommitCompletionEvent(event)` → `NtDCompositionSetChannelCommitCompletionEvent` (0x103A). `Flush` (0x1000CF7C) flushes every surface factory. `OfferSurfaceResources` (0x1001D148) only moves the offer state from 1 to 2 (`E_FAIL` in another state). `TelemetrySetApplicationId(length, name)` limits the name to 100 characters → `NtDCompositionTelemetrySetApplicationId` (0x104A).

### Shared resources

- `CreateSharedResource(iid, &object)` (0x1000C3E0): `SharedProxyDataFromIID` gives the resource type and the proxy constructor for the IID; creates a shareable proxy (`CreateProxyInternal(type, TRUE)`) and returns the interface.
- `OpenSharedResourceHandle(object, &handle)` (0x1000C454): the object must belong to this device → `NtDCompositionOpenSharedResourceHandle(channel, resource, &handle)` (0x1031).
- `OpenSharedResource(handle, iid, &object)` (0x1000C048): `NtDCompositionOpenSharedResource` (0x1030) into a new proxy. A NULL handle → `E_HANDLE`.
- `CSharedSection::Create` (0x1000BB28, `/GS`): `NtDCompositionCreateAndBindSharedSection(channel, resource, size, &section)` (0x101F, resource type 0x46), `MapViewOfFile(section, FILE_MAP_READ | FILE_MAP_WRITE, 0, 0, size)`, closes the section handle. With the heap flag, an `RtlCreateHeap(HEAP_NO_SERIALIZE, base, size, size)` is built in the view. ETW `DCOMPEVENT_CREATE_SHARED_MEMORY_SECTION` (bit 0x10). These sections carry the data shared with the compositor (primitive groups, …).

### DCompositionCreateSurfaceHandle (0x1001CE58)

Builds an `OBJECT_ATTRIBUTES` from the optional `SECURITY_ATTRIBUTES` and calls `NtCreateCompositionSurfaceHandle(&oa or NULL, desiredAccess, surfaceHandle, 0)` (0x1018). On failure `*surfaceHandle` = NULL.

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 24 (`Length`) |
| 0x04 | 4 | 0 (`RootDirectory`) |
| 0x08 | 4 | 0 (`ObjectName`) |
| 0x0C | 4 | `OBJ_INHERIT` (2) if `sa->bInheritHandle`, else 0 |
| 0x10 | 4 | `sa->lpSecurityDescriptor` |
| 0x14 | 4 | 0 (`SecurityQualityOfService`) |

### CDxDevice

`CDxDevice::Initialize(IUnknown *renderingDevice)` (0x10019EF0, `/GS`) accepts a Direct2D device or a DXGI device:
1. `QueryInterface(ID2D1Device {47DD575D-AC05-4CDD-8049-9B02CD16F44C})`. If that works, it gets `ID2D1PrivateDevice` and, through it, the underlying Direct3D device (+0x20).
2. Then `IDXGIDevice` {54EC77FA-1377-44E6-8C32-88FD5F44C84C}, then {A04BFB29-08EF-43D6-A49C-A9BDBDCBE686} (`ID3D11Device1` ?), `ID3D10Multithread` {9B7E4E00-342C-4106-A19F-4F2704F689F0} (+0x0C), {F13EBCD1-672C-4F8B-A631-9539CA748D71} (+0x14) and {07F857E7-077F-4119-86B9-E7AE7104CF33} (+0x10): private interfaces ?
3. Gets the feature level (supported levels `CDxDevice::msc_supportedFeatureLevels`) and the maximum texture size (`CDevice::MaxTextureSizeFromFeatureLevel`, +0x34), and queries a 0x38-byte capability structure.
4. `ReadPrimaryDisplayDevice` (0x1001A0F0): `EnumDisplayDevicesW(NULL, i, &dd, EDD_GET_DEVICE_INTERFACE_NAME)` over all the adapters. For each device attached to the desktop (`StateFlags` & 1) that isn't disconnected (0x2000000), a mirroring driver (8) or flag 0x40, `EnumDisplaySettingsW(name, ENUM_CURRENT_SETTINGS, &dm)`. If it's the primary device (4), `dmPelsWidth` and `dmPelsHeight` are kept at +0x2C and +0x30 (0 if no primary device is found).

The surfaces are textures (`CDxDevice::CreateTexture`, `CreateCompositionBuffer` through a private device method that returns a shared handle) drawn with an `ID2D1DeviceContext` (`CreateD2DDeviceContext`). The gutters of the atlas tiles are drawn with two small built-in HLSL shaders ("Microsoft (R) HLSL Shader Compiler 9.30.9293.0", input `POSITION`, `CreateGutterExtensionResources` 0x1001B2F0).

### System calls

Each stub is `MOVW R12, #n; SVC 1; BX LR`. The numbers are the win32k (shadow table) indexes of this build. [GDI32.DLL](./gdi32.md#system-calls) contains the same 245 stubs, and exports the D3DKMT and OPM ones under their user-mode names. The table follows the alphabetical order of the names, from `NtUserGetThreadState` (0x1000) to `NtValidateCompositionSurfaceHandle` (0x10F4):

| Range | Group |
|-------|-------|
| 0x1000…0x1014 | `NtUserGetThreadState`, `NtUserCallOneParam`, `NtUserCallNoParam`, `NtUserGetDC`, `NtGdiFlush`, regions (`NtGdiCombineRgn`, `NtGdiCreateRectRgn`, …), `NtUserSystemParametersInfo`, `NtUserEnumDisplayMonitors/Devices/Settings`, `NtGdiOpenDCW` |
| 0x1015…0x104F | `NtBindCompositionSurface`, `NtCompositionInputThread`, `NtCreateCompositionInputSink`, `NtCreateCompositionSurfaceHandle`, all the `NtDComposition*` calls, `NtDuplicateCompositionInputSink` |
| 0x1050…0x10C5 | OPM (`NtGdi*OPM*`), D3DKMT (`NtGdiDdDDI*`: adapters, devices, allocations, present, overlays, keyed mutexes, synchronisation objects, Miracast, output duplication), `NtGdiGetDeviceCaps`, `NtGdiInit` |
| 0x10C6…0x10CF | `NtModerncoreDdDDINetDispStart/StopMiracastDisplayDevice`, `NtModerncoreIdleTimerThread`, `NtModerncoreProcessConnect`, `NtModerncoreRegisterCompositorPort`, `NtModerncoreRegisterCompositorProcess`, `NtModerncoreRegisterNavigationWindowHandle`, `NtModerncoreRegisterSharedInputGlobal`, `NtModerncoreSetNavigationServiceSid`, `NtModerncoreUnregisterNavigationWindowHandle` |
| 0x10D0…0x10E5 | composition surfaces, composition input sinks, token manager, `NtUpdateInputSinkTransforms` |
| 0x10E6…0x10F4 | display configuration, DPI, `NtUserCreate/DestroyDCompositionHwndTarget`, session ports, `NtUserSetSysColors`, `NtValidateCompositionSurfaceHandle` |

The exported ones (the name is the one in the PDB, `Nt`/`Zw` as given there):

| Ordinal | Name | Number | Imported by |
|---------|------|--------|-------------|
| 1000 | `ZwDCompositionCreateConnection` | 0x1021 | DWMCORE |
| 1001 | `NtDCompositionGetConnectionBatch` | 0x102B | DWMCORE |
| 1002 | `ZwDCompositionDestroyConnection` | 0x1026 | DWMCORE |
| 1003 | `ZwDCompositionCreateDwmChannel` | 0x1022 | DWMCORE |
| 1004 | `NtDCompositionDestroyChannel` | 0x1025 | DWMCORE |
| 1006 | `ZwDCompositionSubmitDWMBatch` | 0x1045 | DWMCORE |
| 1007 | `ZwDCompositionBeginFrame` | 0x101B | DWMCORE |
| 1008 | `ZwDCompositionGetFrameSurfaceUpdates` | 0x102F | DWMCORE |
| 1009 | `NtDCompositionGetFrameLegacyTokens` | 0x102D | DWMCORE |
| 1011 | `ZwDCompositionConfirmFrame` | 0x101D | DWMCORE |
| 1012 | `ZwDCompositionRetireFrame` | 0x1039 | DWMCORE |
| 1013 | `NtDCompositionDiscardFrame` | 0x1027 | DWMCORE |
| 1014 | `ZwDCompositionReferenceSharedResourceOnDwmChannel` | 0x1032 | [DWMMOBILE](./dwmmobile.md#messages) |
| 1015 | `NtDCompositionGetChannels` | 0x102A | ? |
| 1016 | `ZwDCompositionConnectPipe` | 0x101E | ? |
| 1019 | `NtCreateCompositionInputSink` | 0x1017 | ? |
| 1020 | `ZwQueryCompositionInputSink` | 0x10D5 | DWMCORE |
| 1021 | `ZwQueryCompositionInputSinkLuid` | 0x10D6 | DWMCORE |
| 1022 | `ZwCompositionInputThread` | 0x1016 | DWMCORE |
| 1023 | `NtUpdateInputSinkTransforms` | 0x10E5 | DWMCORE |
| 1024 | `NtDCompositionDuplicateHandleToProcess` | 0x1028 | ? |
| 1025 | `ZwDuplicateCompositionInputSink` | 0x104F | DWMCORE |
| 1026 | `NtQueryCompositionInputQueueAndTransform` | 0x10D4 | [UIXRender.dll](./uixrender.md#input-devices) (input transform of the touch contacts) |
| 510 | `ZwTokenManagerOpenEvent` | 0x10E1 | DWMCORE |
| 511 | `ZwTokenManagerThread` | 0x10E3 | DWMCORE |
| 512 | `NtTokenManagerGetOutOfFrameDirectFlipSurfaceUpdates` | 0x10E0 | DWMCORE |
| 513 | `ZwSetCompositionSurfaceOutOfFrameDirectFlipNotification` | 0x10DC | DWMCORE |
| 514 | `NtSetCompositionSurfaceStatistics` | 0x10DD | DWMCORE |
| 516 | `NtSetCompositionSurfaceBufferCompositionMode` | 0x10DA | DWMCORE |
| 517 | `NtSetCompositionSurfaceIndependentFlipInfo` | 0x10DB | DWMCORE |
| 518 | `ZwTokenManagerDeleteOutstandingDirectFlipTokens` | 0x10DF | DWMCORE |
| 519 | `ZwTokenManagerOpenSection` | 0x10E2 | DWMCORE |

DWMCORE.DLL also imports the wrappers 500, 503, 506…509 and 515. Ordinal 1005 and 1010 don't exist.

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\Software\Microsoft\Avalon.Graphics` | `DisableInstrumentationBreaking` (DWORD) | Read by `MilInstrumentationBreak` (0x10023E1C, through `RegGetHKLMDword` 0x100227EC) before it breaks into the debugger on an instrumentation failure ("Unexpected HRESULT in MilInstrumentation* caller"). Same value as in [DWMCORE.DLL](./dwmcore.md#registry) |

### ETW

Provider `Microsoft-Windows-DirectComposition` {C44219D0-F344-11DF-A5E2-B307DFD72085}, registered in `DllMain` (`McGenEventRegister`, 0x1001E2EC).

53 `EVENT_DESCRIPTOR`s, all version 0, channel 16, level 5 (verbose). The keyword is 0x8000000000000000 plus the bits below. The test before each write is on `Microsoft_Windows_DirectCompositionEnableBits`. The bits seen: 1 for the resource creation event, 4 for the device and commit events (`DEVICE_CREATE`, `DEVICE_COMMIT`, `CAP_MAXIMUM_*`, `BLOCK_FOR_EXCESSIVE_PENDING_*`), 0x10 for the shared memory events. The other writes weren't checked.

| Events (Id) | Task | Keyword bits |
|-------------|------|--------------|
| `RESOURCE_CREATION` 1, `RESOURCE_RELEASE` 30 | 1, 22 | 0x1 |
| `BEGIN_DRAW_Start/Stop` 2/3, `END_DRAW_Start/Stop` 4/5, `TRIM_Start/Stop` 6/7, `RESIZE_Start/Stop` 8/9, `UPDATE_TOKEN_Start/Stop` 10/11, `SUSPEND_DRAW_*` 12/13, `RESUME_DRAW_*` 14/15, `SCROLL_*` 21/22 | 2…8, 14 | 0x1 (0x5 for `BEGIN_DRAW_Start`, `TRIM_Start`, `RESIZE_Start`) |
| `ATLAS_ALLOCATE` 16, `ATLAS_FREE` 17, `ATLAS_ENTRY_ALLOCATE/FREE` 18/19, `ATLAS_UTILIZATION` 20, `ATLAS_USE_INFO` 26, `ATLAS_ENTRY_MARK_FOR_DISPOSE` 27, `…MARK_AVAILABLE` 28, `…REUSE` 29 | 9…13, 18…21 | 0x6 |
| `DEVICE_CREATE` 23, `DEVICE_DESTROY` 24, `DEVICE_COMMIT` 25 | 15…17 | 0x6 |
| `CREATE_CLUMP` 31, `DESTROY_CLUMP` 32, `PUSH_DOWN_START/STOP` 33/34, `RECLUMP_START/STOP` 35/36, `VIRTUAL_SURFACE_COUNTERS` 37, `CAP_ALLOCATION_STATS` 38, `CAP_RELEASE_SURFACE` 39, `BLOCK_FOR_EXCESSIVE_PENDING_Start/Stop` 40/41, `CAP_MAXIMUM_Start/Stop` 44/45 | 23…30, 32 | 0x6 |
| `OFFER` 42, `RECLAIM` 43 | 31 | 0xC |
| `CREATE_SHARED_MEMORY_SECTION` 46, `DESTROY_…` 47, `ALLOCATE_FROM_SHARED_MEMORY_SECTION` 48, `FREE_FROM_…` 49 | 33…36 | 0x12 |
| `ANIMATION_SCENARIO_BEGIN` 50, `…REFERENCE` 51, `…UNREFERENCE` 52 | 37…39 | 0x22 |
| `PRIMITIVE_GROUP_UPDATE` 53 | 40 | 0x40 |

All the names start with `DCOMPEVENT_`.
