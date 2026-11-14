## CompClient.dll

The client side of the Windows Phone 8.1 compositor: it lets a process hand the frames of its windows to the compositor running in the shell process, take screenshots, and set the external display mode.  
`CompClient.dll` is a small DLL (118 functions, all named from the PDB `compclient.pdb`, half of them CRT and a hash map). It talks to the compositor server over an ALPC port, `CompositorAlpcPort`, in the named object directory of `MobileUI` (see [ALPC](#alpc)). For each window, the server gives a "client map", a shared memory section with two frame slots, and two events. The client then presents frames by writing the slot and signalling the compose event, with no ALPC message (see [Shared state](#shared-state-and-presents)). The other exports send one ALPC request each: screenshot (into a file mapping of the caller, turned into a WIC bitmap), display topology (Miracast / USB projection) and "protected session".  
Known users: [DWMCORE.DLL](./dwmcore.md#phone-swap-chain) (`FindSharedState`, `RegisterSurfaceIdentitiesForPresent`, phone swap chain), [ShellChrome.dll](./shellchrome.md) (`CaptureScreen`, `CreateCaptureScreenEvent`: screenshots) and [MirrorUX.dll](./mirrorux.md#display-topology) (`GetDisplayTopology`, `SetDisplayTopology`). The server is [CompServer.dll](./compserver.md), started in [MobileUI.exe](../applications/mobileui.md#startup) by `CompServer!InitializeCompositor`.

Location on the phone: `C:\Windows\System32\CompClient.dll` ? (extracted with `CompServer.dll`, `DWMCORE.DLL`, `DWMAPI.DLL` and `DCOMP.DLL`).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `NtAlpcConnectPortEx`, `NtAlpcSendWaitReceivePort`, `AlpcInitializeMessageAttribute`, `RtlInitUnicodeString`, `NtClose` |
| [SecRuntime.dll](./secruntime.md) | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor`, `GetApplicationBNOPrefixPath` |
| WindowsCodecs.dll | `WICCreateImagingFactory_Proxy` |
| api-ms-win-core-memory-l1-1-2.dll | `CreateFileMappingW`, `OpenFileMappingW`, `MapViewOfFile`, `UnmapViewOfFile` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `OpenEventW`, `SetEvent`, `WaitForSingleObject`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `InitOnceBeginInitialize`, `InitOnceComplete`, `Sleep` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey` |
| ext-ms-win-ntuser-rectangle-ext-l1-1-0.dll | `IsRectEmpty`, `IntersectRect`, `UnionRect` |
| ext-ms-win-rtcore-ntuser-dc-access-l1-1-0.dll (delay-load) | `GetDC`, `ReleaseDC` |
| ext-ms-win-rtcore-gdi-devcaps-l1-1-0.dll (delay-load) | `GetDeviceCaps` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcessId`, `GetCurrentThreadId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapFree` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `DisableThreadLibraryCalls`, `GetModuleHandleExW`, `GetModuleFileNameA` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1.dll | `DebugBreak` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memcpy_s`, `memset`, `_vsnwprintf`, `strrchr`, `strncpy_s`, `strlen`, `strnlen`, `wcsnlen`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, delayload, `GetCurrentProcess` / `TerminateProcess`, errorhandling filters and `DebugBreak` imports are the Visual C++ DLL CRT startup, the delay-load helper and the `/GS` security cookie code. `GetModuleHandleExW`, `GetModuleFileNameA` and `InitOnce*` are the trace message helper (`EtwInitializeTraceMessaging`).

### Dependencies

Files and named objects used other than the static imports.

| File | How | Use |
|------|-----|-----|
| ALPC port `<MobileUI BNO directory>\CompositorAlpcPort` | `NtAlpcConnectPortEx` ([ALPC](#alpc)) | Compositor server ([CompServer.dll](./compserver.md#alpc-server) in [MobileUI.exe](../applications/mobileui.md)) |
| `<MobileUI BNO directory>\Compositor{<server id>}.%08x.State` | `OpenFileMappingW(FILE_MAP_READ \| FILE_MAP_WRITE)` ([CreateSharedState](#createsharedstate-0x10002f40)) | Client map of a window: frames, region, statistics |
| `<MobileUI BNO directory>\Compositor{<server id>}.ComposeEvent`, `…{<server id>}.<client id>.FrameEvent` | `OpenEventW` | Present signal to the compositor / frame done signal back |
| `ScreenCap.Map.<thread id>` | `CreateFileMappingW` ([CaptureScreen](#capturescreen-0x100037ac)) | Screenshot pixels, filled by the compositor |
| `ScreenCap.Evt.<pid>.<counter>` | `CreateEventW` ([CreateCaptureScreenEvent](#createcapturescreenevent-0x10003b6c)) | Event passed to the compositor with a screenshot request |
| `HKLM\Software\Microsoft\Compositor\MirrorSettings`, `HKLM\Software\Microsoft\Compositor` | `RegQueryValueExW` ([GetDisplayTopology](#getdisplaytopology-0x10003d88)) | Current display topology and orientation |

No DLL is loaded at run time (only the two delay-loaded API sets), no process is started and no COM object is created by CLSID (the WIC factory comes from `WICCreateImagingFactory_Proxy`).

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 7 | `GetCompClientVersion` | 0x10002F34 | none; returns 3 |
| 4 | `CreateSharedState` | 0x10002F40 | `const CREATE_SHARED_STATE_DESC *create`, `SHARED_STATE_DESC *state` ([below](#createsharedstate-0x10002f40)) |
| 5 | `DestroySharedState` | 0x100030B0 | `ClientState *` |
| 6 | `FindSharedState` | 0x100030CC | `HWND`, `ClientState **` |
| 2 | `ClaimNextBuffer` | 0x100031D4 | `ClientState *`, `CLAIMED_BUFFER_DESC *` |
| 22 | `UnclaimCurrentBuffer` | 0x10003298 | `ClientState *` |
| 11 | `PresentBufferEx` | 0x1000347C | `ClientState *`, `const PRESENT_BUFFER_EX_DESC *` |
| 15 | `SetWindowRegion` | 0x100033B8 | `ClientState *`, `const SET_WINRGN_DESC *` |
| 10 | `IsOccluded` | 0x10003540 | `ClientState *`, `BOOL *` |
| 12 | `RegisterSurfaceIdentitiesForPresent` | 0x100035CC | `ClientState *`, `const DWORD identities[16]`, `DWORD planeMask`, (unused) |
| 9 | `GetFrameStatistics` | 0x100036BC | `ClientState *`, `GET_FRAME_DESC *` (32 bytes) |
| 1 | `CaptureScreen` | 0x100037AC | `DWORD flags`, `IWICBitmap **`, `PCWSTR captureEventName` |
| 3 | `CreateCaptureScreenEvent` | 0x10003B6C | `CAPTURE_EVENT_DESC *` (`WCHAR name[32]`, `HANDLE` at +0x40) |
| 14 | `SetDisplayTopology` | 0x10003CB0 | `const DISPLAY_TOPOLOGY_DESC *` (8 bytes) |
| 8 | `GetDisplayTopology` | 0x10003D88 | `DISPLAY_TOPOLOGY_DESC *` |
| 17 | `SrStartSession` | 0x10003E64 | `ICompositorAlpcClient **session` |
| 16 | `SrProcessCommand` | 0x10003F94 | `ICompositorAlpcClient *session` |
| 18 | `SrStopSession` | 0x10003F2C | `ICompositorAlpcClient *session` |
| 19 | `StartProtectedSession` | 0x10004024 | `ICompositorAlpcClient **session`, (unused) |
| 20 | `StopProtectedSession` | 0x10003F2C | same code as `SrStopSession` |
| 13, 21, 23 | `RegisterTestFramework`, `TestFrameworkCommand`, `UnregisterTestFramework` | 0x10004110 | stub: returns `E_NOTIMPL` (0x80004001) |

Every export returns an HRESULT, except `GetCompClientVersion`, `DestroySharedState` and `GetDisplayTopology` (Win32 code of the last registry call). The descriptors start with `dwVersion`, which must be 3 (else `E_INVALIDARG`); a NULL descriptor gives `E_POINTER`.

The per-window object, `ClientState` (0x18 bytes, `operator new`), is the "shared state" handle given to the callers:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `HWND` of the window (key of the global map `ClientState::s_mapClients`) |
| 0x04 | 4 | `m_pClientMap`: view of the `.State` mapping ([Client map](#client-map)) |
| 0x08 | 4 | `m_hevtNextFrame`: `…FrameEvent` (`SYNCHRONIZE`) |
| 0x0C | 4 | `m_hevtCompose`: `…ComposeEvent` (`EVENT_MODIFY_STATE`) |
| 0x10 | 4 | `ICompositorAlpcClient *` (one ALPC connection per window) |
| 0x14 | 4 | `m_fClaimedBuffer` |

`s_mapClients` (an `unordered_map<HWND, ClientState *>`) is protected by the critical section `ClientState::s_csClients`, and destroyed by an `atexit` handler.

### Startup

`_DllMainCRTStartup` (0x100071FC): `__security_init_cookie` then the CRT init (`__DllMainCRTStartup`, `_CRT_INIT`, `_initterm`: the `s_mapClients` initialiser).  
`DllMain` (0x1000490C), on `DLL_PROCESS_ATTACH`: `DisableThreadLibraryCalls`, registers the ETW provider (`McGenEventRegister`, see [ETW](#etw)), `InitializeCriticalSection(&s_csClients)`. On `DLL_PROCESS_DETACH`: asserts that `s_mapClients` is empty, `DeleteCriticalSection`, unregisters the provider. There is no other initialisation: each export opens its own ALPC connection when it needs one.

### ALPC

`CreateCompositorAlpcClient` (0x10005CD4) creates a `CompositorAlpcClient` (0x22C bytes, reference counted: `AddUsage` / `RemoveUsage`) and calls `Open` (0x10005EA8):

1. `QueryTransientObjectSecurityDescriptor(8, L"MobileUI\\Compositor.AlpcPort\\Server", &sd)`: type 8 is the `AlpcPort` prefix ([SecRuntime](./secruntime.md#querytransientobjectsecuritydescriptor-0x10003c20)), i.e. the key `%5C%5C.%5CAlpcPort%5CMOBILEUI%5CCOMPOSITOR.ALPCPORT%5CSERVER`. Its error is returned as NTSTATUS | 0x10000000.
2. `GetApplicationBNOPrefixPath(L"MobileUI", TRUE, 0x103, this+0x24, &cch)`, then appends `\`: the object directory of `MobileUI`, kept for the names of the shared objects (`GetServerBNOPrefixPath`).
3. `GetApplicationBNOPrefixPath(L"MobileUI", FALSE, …)` + `\CompositorAlpcPort`: the port name.
4. `ClientConnection::OpenConnection` (0x1000674C): `NtAlpcConnectPortEx(&hPort, {port name}, NULL, &attributes, ALPC_MSGFLG_SYNC_REQUEST (0x20000), sd, …)`. Port attributes: flags 0x10000, QoS `SecurityIdentification`, dynamic tracking, effective only, `MaxMessageLength` 0xA0. The server's security descriptor must be `sd`. It then allocates the message buffer (0xA0 bytes) and a message attribute buffer for `ALPC_MESSAGE_CONTEXT_ATTRIBUTE` (0x20000000).

Every request uses the same buffer: a `PORT_MESSAGE` (0x18 bytes) followed by a DWORD message type at +0x18. It's sent with `NtAlpcSendWaitReceivePort(port, 0x20000, msg, attrs, msg, …)` (`SendPacket`), and the reply must have `u2.s2.Type` = 2 (`LPC_REPLY`), the expected length and the expected type, else `E_UNEXPECTED` (0x8000FFFF). An NTSTATUS error is returned with bit 28 set.

| Request | Data length, total | Request fields | Reply type, total | Reply fields | Sent by |
|---------|--------------------|----------------|-------------------|--------------|---------|
| 0 `ClientCreate` | 12, 36 | +0x1C `HWND`, +0x20 `dwFormat` | 1, 40 | +0x1C HRESULT, +0x20 `CLIENT_DESC` (`dwServerId`, `dwClientId`) | [CreateSharedState](#createsharedstate-0x10002f40) |
| 2 `ClientDestroy` | 8, 32 | +0x1C `HWND` | none (sent with flag 0x10000 `ALPC_MSGFLG_RELEASE_MESSAGE`, no wait) | | `~ClientState` |
| 3 `CaptureScreen` | 136, 160 | +0x1C flags, +0x20 `szMappingName` (`WCHAR[32]`), +0x60 `szCaptureInitiatedEventName` (`WCHAR[32]`, may be empty) | 4, 48 | +0x1C HRESULT, +0x20 `CAPTUREHEADER` (`uWidth`, `uHeight`, `cbStride`, `DXGI_FORMAT`) | [CaptureScreen](#capturescreen-0x100037ac) |
| 9 `SrProcessCommand` | 4, 28 | none | 10, 32 | +0x1C HRESULT | `SrProcessCommand` |
| 11 `SetDisplayTopology` | 12, 36 | +0x1C 8-byte `DISPLAY_TOPOLOGY_DESC` | 12, 32 | +0x1C HRESULT | `SetDisplayTopology` |
| 15 `SetProtectedStatus` | 4, 28 | none | 16, 32 | +0x1C HRESULT | `StartProtectedSession` |

The types 5…8, 13 and 14 aren't used by this client (on the [server](./compserver.md#alpc-requests), 5 is `TestFrameworkCommand`, `E_NOTIMPL`; 7 `NotifyOnDisplayStateChange` and 13 `CreateSystemThreads` are accepted only from kernel mode; 6, 8 and 14 are their replies); the three interface slots between them (vtable +0x14, +0x1C, +0x24) are the `E_NOTIMPL` stub, probably the removed test framework commands.

### CreateSharedState (0x10002F40)

`CreateSharedState(create, state)` connects a window to the compositor. `CREATE_SHARED_STATE_DESC`: +0x00 `dwVersion` = 3, +0x04 `hWindow`, +0x08 `dwFormat`.

1. `CreateCompositorAlpcClient`, then `ClientState::Create` (0x10004C40):
2. ALPC request 0 `ClientCreate(hWindow, dwFormat)` returns `dwServerId` and `dwClientId`.
3. With the BNO prefix of `MobileUI`, opens `Compositor{<dwServerId>}.ComposeEvent` (`OpenEventW(EVENT_MODIFY_STATE)`), `Compositor{<dwServerId>}.<dwClientId>.State` (`OpenFileMappingW(FILE_MAP_READ | FILE_MAP_WRITE)`, whole section mapped, then the section handle is closed) and `Compositor{<dwServerId>}.<dwClientId>.FrameEvent` (`OpenEventW(SYNCHRONIZE)`). All ids are printed with `%08x`.
4. Adds `hWindow` → object to `s_mapClients` (`E_OUTOFMEMORY` if the insertion fails).
5. Fills `SHARED_STATE_DESC`: +0x00 the `ClientState *`, +0x04 `hGpuSync` (client map +0x08), +0x08 `hDummyBuffer` (client map +0x04).

On failure the object is destroyed. `DestroySharedState` runs `~ClientState` (0x10004B40): closes the events, unmaps the view, sends `ClientDestroy(hWnd)`, releases the ALPC client and removes the window from the map.  
`FindSharedState(hWnd, &state)` looks the window up in the map: `HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)` (0x80070002) if the window has no shared state. [DWMCORE.DLL](./dwmcore.md#phone-swap-chain) uses it, so the shared state of a window is created by another module of the same process.

### Client map

The `.State` section, created by the server. Offsets from the code; the field names come from the assertion strings.

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 4 | Occluded (`IsOccluded` returns it; no buffer is given while it's set) |
| 0x004 | 4 | `hDummyBuffer`: a layer may not present this surface |
| 0x008 | 4 | `hGpuSync`; 0 means the compositor dropped the client: every call then fails with `E_ABORT` (0x80004004) (`ClientState::Validate`) |
| 0x00C | 4 | `ClaimBufferHint`, written by the server with `hShared` ([CompServer](./compserver.md#clients-and-presents)) |
| 0x010 | 4 | `hShared`: next free buffer, taken (atomic exchange with 0) by `ClaimNextBuffer` |
| 0x014 | 4 | Index (0 / 1) of the statistics entry being written |
| 0x018 | 2 × 0x20 | Frame statistics; `GetFrameStatistics` copies entry `1 - index` |
| 0x058 | 4 | `fInPresent`: set by the client, cleared by the compositor when it has taken the frame |
| 0x05C | 4 | Index (0 / 1) of the frame slot the client writes |
| 0x060 | 2 × 0x4A0 | Frame slots ([below](#frame-slot)) |
| 0x9A0 | 32 × 16 | `rgrcInput`: input region (`RECT`s) |
| 0xBA0 | 4 | `cInput` |
| 0xBA4 | 32 × 16 | `rgrcRender`: render region |
| 0xDA4 | 4 | `cRender`; -1 if the caller gave more than 32 rectangles (whole window ?) |

#### Frame slot

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 4 | `PRESENT_BUFFER_EX_DESC` +0x04 |
| 0x008 | 0x10 | `PRESENT_BUFFER_EX_DESC` +0x08…+0x14 (the first two are traced with each present: dirty rect ?); [CompServer](./compserver.md#clients-and-presents) reads +0x010…+0x017 as a 64-bit GPU fence value |
| 0x018 | 4 | Mask of the planes that have a surface |
| 0x01C | 4 | `dwMaskLayersToUpdate`: planes changed by this present (0x10000000 if none) |
| 0x020 | 16 × 0x44 | Layers (one per plane): `COMPOSITION_LAYER_DESC` (one per plane): +0x00 `nPlaneIndex`, +0x04 `fEnable` (0 = plane removed), +0x08 `hSurface`, +0x0C ?, +0x10 flags (0x200: the server opens the surface with its registered identity, see [CompServer](./compserver.md#clients-and-presents)), +0x14…+0x43 ? |
| 0x460 | 16 × 4 | Surface identities (`RegisterSurfaceIdentitiesForPresent`) |

### Shared state and presents

`ClaimNextBuffer(state, desc)` (`ClientState::ClaimSurface`, 0x10005210), `CLAIMED_BUFFER_DESC`: +0x00 `dwVersion` = 3, +0x04 returned buffer handle. `WaitForLastFrameFinish` (0x1000510C) loops while a present is pending or the window is occluded: it waits on the frame event for 500 ms. A timeout returns `E_PENDING` (0x8000000A), a wait error `E_ABORT`, and an already claimed buffer `E_UNEXPECTED`. Otherwise it takes `hShared` from the map and sets `m_fClaimedBuffer`.

`PresentBufferEx(state, desc)` (`ClientState::Present`, 0x100054E4). `PRESENT_BUFFER_EX_DESC`: +0x00 `dwVersion` = 3, +0x04…+0x14 copied into the frame slot, +0x18 number of layers, +0x1C pointer to the layers (0x44 bytes each, same layout as in the slot).
1. Checks each layer: plane < 16, no plane twice, `hSurface` ≠ `hDummyBuffer` (all `E_INVALIDARG`). A layer with `fEnable` = 0 removes the plane (skipped if the plane was already empty). An enabled layer on plane 0 needs a claimed buffer (`E_UNEXPECTED`).
2. Without a claimed buffer, waits for the last frame (`WaitForLastFrameFinish(NULL)`).
3. Writes the current slot: header fields, changed layers copied (or removed), the plane mask updated. The planes not changed are copied from the other slot, with their surface identity.
4. `SignalPresentToCompositor` (0x10005884): clears `m_fClaimedBuffer`, sets `fInPresent` = 1, `SetEvent(compose event)`, then waits on the frame event until the compositor clears `fInPresent` (checking `hGpuSync` each time; a wait failure calls `DebugBreak` and returns `E_UNEXPECTED`).
5. The compositor must have switched the slot index (else `E_PENDING`).

On an error, the DLL sends an empty present (same header, no layer) so that the compositor isn't left waiting.  
`UnclaimCurrentBuffer` gives a claimed buffer back: it copies the header +0x08…+0x14 of the previous slot, clears the change mask, and signals the compositor in the same way.  
`RegisterSurfaceIdentitiesForPresent(state, ids, mask)` copies `ids[i]` into the identities of the current slot for each bit `i` of `mask`. It doesn't signal anything: the identities go with the next present.  
`SetWindowRegion(state, desc)` (`ClientState::SetWindowRegion`, 0x10005314). `SET_WINRGN_DESC`: +0x00 `dwVersion` = 3, +0x04 `cRender`, +0x08 `rgrcRender`, +0x0C `cInput`, +0x10 `rgrcInput`. More than 32 input rectangles → `HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER)` (0x8007007A). The render rectangles are copied into the map (or `cRender` = -1 above 32), and each one that intersects an earlier one is merged into it (`UnionRect`) and emptied.  
`GetFrameStatistics(state, desc)`: `dwVersion` = 3, then the 32-byte statistics entry is copied over the whole descriptor.

### CaptureScreen (0x100037AC)

`CaptureScreen(flags, &bitmap, eventName)`:
1. `flags` may only contain the bits 0x01 and 0x10 (else `E_INVALIDARG`); `bitmap` may not be NULL.
2. Opens an ALPC connection. Size of the screen: `GetDC(NULL)`, `GetDeviceCaps(HORZRES)` and `GetDeviceCaps(VERTRES)`. Mapping size = ((width × 4 + 3) & ~3) × height (`UIntMult`, `HRESULT_FROM_WIN32(ERROR_ARITHMETIC_OVERFLOW)` on overflow).
3. `QueryTransientObjectSecurityDescriptor(5, L"MobileUI\\ScreenCap.Map")` (type 5 = `FileMapping`), then `CreateFileMappingW(INVALID_HANDLE_VALUE, {sd}, PAGE_READWRITE | SEC_COMMIT, 0, size, L"ScreenCap.Map.<thread id %08x>")`.
4. ALPC request 3 with `flags`, the mapping name and `eventName` (empty if NULL). The compositor writes the screen into the mapping and returns the `CAPTUREHEADER`.
5. `MapViewOfFile(FILE_MAP_READ)`. Pixel format from the header: `DXGI_FORMAT_B5G6R5_UNORM` (85) → `GUID_WICPixelFormat16bppBGR565`, `DXGI_FORMAT_B8G8R8A8_UNORM` (87) → `GUID_WICPixelFormat32bppPBGRA`, anything else → `E_UNEXPECTED`.
6. `WICCreateImagingFactory_Proxy(0x237, &factory)`, `factory->CreateBitmapFromMemory(uWidth, uHeight, format, cbStride, cbStride × uHeight, view, bitmap)`. The bitmap is a copy: the view, the mapping, the factory and the connection are then released.

The meaning of the flags 0x01 and 0x10 is unknown.

### CreateCaptureScreenEvent (0x10003B6C)

`CreateCaptureScreenEvent(desc)` builds the event that the compositor signals when a capture starts (`szCaptureInitiatedEventName`):
1. `QueryTransientObjectSecurityDescriptor(1, L"MobileUI\\ScreenCap.Evt")` (type 1 = `Event`).
2. Name `ScreenCap.Evt.<pid %08x>.<counter %08x>` in `desc->wszCaptureEventName` (32 characters). The counter is a global incremented atomically.
3. `CreateEventW({sd}, auto-reset, non-signalled, name)`; the handle is stored at `desc` +0x40.

The caller then passes the name to `CaptureScreen` and waits on the handle. In both functions the object name has no BNO prefix, so it's relative to the caller's own named object directory.

### Display topology

`SetDisplayTopology(desc)` sends the 8 bytes of `desc` with ALPC request 11 and returns the HRESULT of the compositor.  
`GetDisplayTopology(desc)` doesn't ask the compositor. It reads the registry:
- +0x00 = `HKLM\Software\Microsoft\Compositor\MirrorSettings` value `DisplayTopology` (REG_DWORD), 0 if missing;
- +0x04 = `HKLM\Software\Microsoft\Compositor` value `DisplayOrientation` (REG_DWORD), 3 if missing.

These values are written by the compositor ([CompServer!UpdateTopology](./compserver.md#display-topology)) when it applies a topology. The meaning of the values is on the [MirrorUX.dll](./mirrorux.md#display-topology) page (mode 0 / 1 / 2, `DISPLAY_ORIENTATION`).

### Sessions

The session handle is a `CompositorAlpcClient` (one ALPC connection), released by `SrStopSession` / `StopProtectedSession` (`Release`, vtable +4).
- `SrStartSession(&session)` only opens the connection. `SrProcessCommand(session)` sends request 9; the server status 0xCFFF0001 is turned into `E_ACCESSDENIED` (0x80070005). "Sr" is probably screen recording ?
- `StartProtectedSession(&session, …)` opens the connection and sends request 15 `SetProtectedStatus`: while the connection is open the client is "protected" (protected content, no screen capture ?).

The callers of these exports aren't known.

### ETW

Provider `{54C2DE61-5A35-413A-8443-085EC0C4640B}` (`Microsoft-WindowsPhone-CompositionTrace`), registered in `DllMain` (enable callback `ETW_EnableCallback` 0x10004A60, enable bits in `Microsoft_WindowsPhone_CompositionTraceEnableBits`). The DLL writes no manifest events, only trace messages (`EtwTraceMessageVarArgs`, 0x1000431C) with the failed expression as text:

| Enable bit | Message | Written when |
|------------|---------|--------------|
| 0x02 | `ETWERROR` | Failed check (`FEHM fail: Code %1!d!, %2!s!`) or assertion (`Asserting %1!s!`) |
| 0x10 | `ETWBUFFERS` | Buffer claimed (window handle), present (header +0x08, +0x0C) |
