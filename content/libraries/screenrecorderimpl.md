## ScreenRecorderImpl.dll

The screen recorder of the Windows Phone 8.1 compositor: it copies the composed frames into surfaces given by a recording application.  
`ScreenRecorderImpl.dll` is a small C++ DLL (126 functions, most of them CRT, string and trace helpers; PDB `screenrecorderimpl.pdb`). It's delay-loaded by [CompServer.dll](./compserver.md#screen-recording), which gets from it one object with two interfaces: the recorder (`IScreenRecorder`, `GetSR`), which receives the commands of the recording application, and a frame listener (`ICompositorPALFrameListener`, `GetSRFrameListener`), which the compositor calls for every frame (interface names from the CompServer symbols). The recorder and the application talk through a 28-byte shared section `ScreenRecorderMetaData` and two events `ScreenRecorderCommandCompleted` / `ScreenRecorderSampleReady`, created by the application in its own AppContainer named object directory ([Shared section](#shared-section)). For each recorded frame the listener copies the compositor's surface into the surface the application registered, then signals "sample ready". Recording pauses during a phone call and on protected content. The first time an application records, the DLL asks the user for consent with a shell action dialog ([ShellChromeAPI.dll](./shellchromeapi.md#action-dialogs)) and remembers the answer in the application's chamber registry (`ChamberReadOnly\CaptureConsent`).  
The client side is the ALPC request 9 `SrProcessCommand` of [CompClient.dll](./compclient.md) (`SrStartSession` / `SrProcessCommand`). The frame is copied with the compositor's own buffer / graphics interfaces (`ICompositorPALBuffer`, `ICompositorPALGraphics` of CompServer.dll). The recording application itself isn't analysed.

Location on the phone: `C:\Windows\System32\ScreenRecorderImpl.dll` ? (delay-loaded by name by CompServer.dll).  

### Imports

| DLL | Functions |
|-----|-----------|
| [ShellChromeAPI.dll](./shellchromeapi.md) | `Shl::ActionDialog::ActionDialog::Create` (`ACTION_DIALOG_PARTIAL_SCREEN_CONFIG` overload) |
| [EMSVCS.dll](./emsvcs.md) | `CreateExecutionManager` |
| ChamberProf.dll | `GetChamberRegistryLocation` |
| [SecRuntime.dll](./secruntime.md) | `QueryExecutableProperties`, `ReleaseExecutableProperties` |
| phoneom.dll | `PhoneGetCallCounts` |
| api-ms-win-core-com-l1-1-1.dll | `CoCreateInstance` |
| OLEAUT32.dll | `SysFreeString` |
| api-ms-win-core-memory-l1-1-2.dll | `OpenFileMappingW`, `MapViewOfFile`, `UnmapViewOfFile` |
| api-ms-win-core-synch-l1-2-0.dll | `OpenEventW`, `SetEvent`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `InitOnceBeginInitialize`, `InitOnceComplete`, `Sleep` |
| api-ms-win-security-appcontainer-l1-1-0.dll | `GetAppContainerNamedObjectPath` |
| api-ms-win-core-registry-l1-1-0.dll, api-ms-win-core-registry-l2-1-0.dll | `RegCreateKeyExW`, `RegCloseKey`, `RegOpenKeyW` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadStringW`, `FindResourceExW`, `LoadResource`, `LockResource`, `SizeofResource`, `DisableThreadLibraryCalls`, `GetModuleHandleExW`, `GetModuleFileNameA` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventWrite` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapReAlloc`, `HeapFree`, `HeapSize`, `HeapDestroy` |
| api-ms-win-core-errorhandling-l1-1-2.dll, api-ms-win-core-debug-l1-1-1.dll, api-ms-win-core-rtlsupport-l1-2-0.dll | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `DebugBreak`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memmove`, `memset`, `wcsstr`, `wcslen`, `strrchr`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, errorhandling, debug, `GetCurrentProcess` / `TerminateProcess` imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code. `GetModuleHandleExW`, `GetModuleFileNameA` and `InitOnce*` are the trace message helper (as in CompServer.dll), the heap functions and the critical section belong to the ATL string manager and resource module list.

### Dependencies

Files and named objects used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `ScreenRecorderImpl.dll.mui` (the DLL only has an `MUI` resource, language `en-US`) | `LoadStringW(hInstance, 101…104)`, `FindResourceExW(RT_STRING)` on the ATL resource modules | Title, text and the two buttons of the [consent dialog](#consent-thread-sub_10002788); not analysed |
| Section `<caller's AppContainer named objects>\ScreenRecorderMetaData` | `OpenFileMappingW(FILE_MAP_READ \| FILE_MAP_WRITE)`, `MapViewOfFile(…, 0x1C)` ([OpenHandles](#openhandles-sub_10002ca8)) | Commands and status, see [Shared section](#shared-section) |
| Events `<…>\ScreenRecorderCommandCompleted`, `<…>\ScreenRecorderSampleReady` | `OpenEventW(EVENT_MODIFY_STATE)` | Signalled to the application: status written / frame copied |
| Execution manager ([EMSVCS.dll](./emsvcs.md#createexecutionmanager-0x10008000)) | `CreateExecutionManager`, method +0x0C (AppX execution RPC opnum 1 on `AppXExecutionSvc\Server`) | Product ID of the recording process |
| PacMan server [pacmanserver.dll](./pacmanserver.md), CLSID `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` | `CoCreateInstance(…, CLSCTX_ALL (0x17), {698D57C2-292D-4CF3-B73C-D95A6922ED9A})` (`IPMEnumerationManager`) | Title and SID of the application ([Application identity](#application-identity-sub_1000264c)) |
| Chamber registry of the application, `ChamberReadOnly\CaptureConsent` | `GetChamberRegistryLocation`, `RegOpenKeyW` / `RegCreateKeyExW` | Consent already given |
| Server of `System\ActionDialogManagerEndpoint` | through [ShellChromeAPI.dll](./shellchromeapi.md#action-dialogs) `Shl::ActionDialog::Create` | Consent dialog |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 2 | `GetSR` | 0x100023CC | `IScreenRecorder **recorder`: returns the object +0x0C |
| 3 | `GetSRFrameListener` | 0x10002390 | `ICompositorPALFrameListener **listener`: returns the object +0x08 |
| 1 | `DestroySR` | 0x10002408 | none: calls `Release` of the listener interface (+0x08) and forgets the object; returns 0 |

`GetSR` and `GetSRFrameListener` return `E_INVALIDARG` for a NULL pointer, `E_OUTOFMEMORY` if the object can't be created, else `S_OK`. Both create the object on first use (`GetScreenRecorder`, `sub_100032F4`): one 0x258-byte object (`operator new`), pointer kept in `off_10005310`, reference count 1. The decorated names imported by CompServer.dll are `?GetSR@@YAJPAPAUIScreenRecorder@@@Z`, `?GetSRFrameListener@@YAJPAPAUICompositorPALFrameListener@@@Z` and `?DestroySR@@YAJXZ` (this DLL exports them undecorated); the object's own class name isn't in the binary.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `off_10001348` (destructor `sub_10002430`: closes the handles, `operator delete`) |
| 0x04 | 4 | Reference count (1) |
| 0x08 | 4 | Frame listener vtable `off_1000131C` ([Frame listener](#frame-listener)) |
| 0x0C | 4 | Recorder vtable `off_10001304` ([Recorder](#recorder)) |
| 0x10 | 4 | 0 (not used ?) |
| 0x14 | 4 | View of `ScreenRecorderMetaData` |
| 0x18 | 4 | Section handle |
| 0x1C | 4 | Event `ScreenRecorderCommandCompleted` |
| 0x20 | 4 | Event `ScreenRecorderSampleReady` |
| 0x24 | 1 | Active (1 at creation, cleared by `CloseHandles`) |
| 0x25 | 1 | ? (returned by recorder method 2, which CompServer doesn't call; only cleared in this DLL) |
| 0x28 | 4 | Recorded window (first window accepted by the [window check](#frame-listener)) |
| 0x2C | 4 | Process ID of the caller (`CallerContextInfo` +0x00, the `ClientId` of the ALPC message) |
| 0x30 | 4 | Client token (`CallerContextInfo` +0x0C, see [OpenHandles](#openhandles-sub_10002ca8)) |
| 0x34 | 1 | `allowed` from CompServer (recorder method 5): no consent, no window check, records during a call |
| 0x35 | 1 | Paused (call / protected content) |
| 0x38 | 16 | Sample slot (one): +0x00 frame ID (8 bytes), +0x08 surface handle of the application, +0x0C ? |
| 0x48 | 1 | A surface is waiting for the next frame (set by command 2) |
| 0x4C | 4 | Index of that slot (always 0) |
| 0x50 | 520 | Account name of the application (260 WCHAR), from `QueryExecutableProperties` |

### Startup

`DllEntryPoint` (`_DllMainCRTStartup`, 0x10004668): `__security_init_cookie`, then `dllmain_dispatch` (0x10004374: `_initterm`, which builds the ATL resource module list, the string manager and the critical section, then `DllMain`).  
`DllMain` (`sub_10001B24`), on `DLL_PROCESS_ATTACH`: keeps the instance (`dword_100052F0`, used by `LoadStringW`), `DisableThreadLibraryCalls`, registers the [ETW](#etw) provider. Nothing else: the object is created by the exports.

### Recorder

Vtable `off_10001304`, called by CompServer.dll with `this` = object +0x0C:

| Slot | Function | Comment |
|------|----------|---------|
| 0 | `ProcessCommand` (`sub_100025A0`) | [below](#processcommand-sub_100025a0) |
| 1 | 0x10002480 | Returns byte +0x24 (active): after each command, CompServer tears the recorder down when it's 0 (or when the command failed) |
| 2 | `sub_10002474` | Returns byte +0x25; not called by CompServer |
| 3 | `OpenHandles` (`sub_10002CA8`) | [below](#openhandles-sub_10002ca8) |
| 4 | 0x1000248C | Returns +0x28 (recorded window) |
| 5 | `sub_10002498` | Sets byte +0x34 (`allowed`) |
| 6 | `sub_10002C18` | AddRef |

The method names `OpenHandles` and `ProcessCommand` come from the assert strings of CompServer (`CHR(m_pScreenRecorder->OpenHandles(pcontext))`, `CHR(m_pScreenRecorder->ProcessCommand())`). `Compositor::SrProcessCommand(context, allowed)` (0x1002604C) calls them in this order:
1. First request (no recorder yet): keeps the connection id (`context` +0x08), `GetSR`, `GetSRFrameListener`, `OpenHandles(context)`, method 5 with `allowed`, then `RegisterFrameListener` on its `ICompositorContext`.
2. Every request: `ValidateWindowAndOwner(method 4 (recorded window), context pid)` must succeed unless `allowed`, and the connection must be the first one, else `E_ACCESSDENIED`; then `ProcessCommand()`.
3. If `ProcessCommand` failed or method 1 returns 0: `UnregisterFrameListener` and `DestroySR` (`StartScreenRecorderTearDown` / `TearDownScreenRecorderThread`).

`allowed` is given by `Decode_SrProcessCommand` (0x100267F0): capability `ID_CAP_SCREEN_RECORDER_BKG` **and** `PolicyManager_GetExperiencePolicy_AllowScreenCapture`.

#### OpenHandles (sub_10002CA8)

`context` is the `CallerContextInfo` of the ALPC request ([CompServer](./compserver.md#alpc-server)); `Decode_SrProcessCommand` puts the client token (`GetCallerToken`, impersonation token of the caller) at its +0x0C.
1. Keeps the process ID (`context` +0x00) at +0x2C and the token (`context` +0x0C) at +0x30.
2. `GetAppContainerNamedObjectPath(token, NULL, 260, path, &len)` and appends `\`. `ERROR_NOT_APPCONTAINER` (0x109A) is accepted (empty prefix: global names); any other error fails.
3. `OpenEventW(EVENT_MODIFY_STATE, FALSE, <path>ScreenRecorderCommandCompleted)` → +0x1C, then `<path>ScreenRecorderSampleReady` → +0x20.
4. `OpenFileMappingW(FILE_MAP_READ | FILE_MAP_WRITE, FALSE, <path>ScreenRecorderMetaData)` → +0x18, `MapViewOfFile(…, FILE_MAP_READ | FILE_MAP_WRITE, 0, 0, 0x1C)` → +0x14, and clears the rotation (+0x14 of the section).

Errors are returned as `HRESULT_FROM_WIN32(GetLastError())` (`E_OUTOFMEMORY` for the name buffers) and reported with status 4 ([Shared section](#shared-section)). The names are resolved in the caller's AppContainer directory, so the application creates them relative to its own directory, like the `ScreenCap.*` objects of the [screen capture](./compserver.md#screen-capture).

#### ProcessCommand (sub_100025A0)

Reads the command at +0x00 of the section (`E_FAIL` if the section isn't mapped):

| Command | Action |
|---------|--------|
| 0 | Nothing |
| 1 | `CloseHandles` (`sub_100024A8`): unmaps the section, closes the section and the two events, clears the state (active, window, slot, pending flag). Stops the recording |
| 2 | Puts the DWORD at +0x0C of the section (surface handle of the application) in the free slot (+0x40) and sets "waiting for a frame" (+0x48). If the slot is already used, nothing is done |
| 3 | Starts the [consent thread](#consent-thread-sub_10002788) (`CreateThread(sub_10002638)`, handle closed at once) and writes status 8 (pending) |
| other | `E_INVALIDARG` |

The result is written at +0x08 of the section and returned to CompServer (and to the application as the ALPC reply).

### Consent thread (sub_10002788)

1. Finds the application ([Application identity](#application-identity-sub_1000264c)): its title (BSTR) and its account name (+0x50).
2. `GetChamberRegistryLocation(accountName, KEY_READ (0x20019), &key)`, `RegOpenKeyW(key, L"ChamberReadOnly\\CaptureConsent")`: the key exists → consent already given.
3. If neither `allowed` nor the key: builds an `ACTION_DIALOG_PARTIAL_SCREEN_CONFIG` with string 101 (title ?), string 102 with every `<app name>` replaced by the application's title (text), and the buttons 103 and 104 (strings of the `.mui`, not available). `Shl::ActionDialog::Create(importance 2, config, &dialog)`, then dialog method +0x0C (wait for the answer ?, 8-byte result): {0, 0} (first button) → `GetChamberRegistryLocation(accountName, KEY_READ | KEY_WRITE (0x2001F))` and `RegCreateKeyExW(…, L"ChamberReadOnly\\CaptureConsent", …, KEY_ALL_ACCESS)`, result `S_OK`; any other answer → `E_ACCESSDENIED` (0x80070005). The dialog is closed with method +0x18 and released (+0x08).
4. Writes status 9 with the result ([Shared section](#shared-section)) and frees the name.

Consent is given once per application: the key is in the `ChamberReadOnly` part of its chamber, which the application can't write itself ? An application with `allowed` (capability `ID_CAP_SCREEN_RECORDER_BKG` and the policy allows screen capture) is never asked.

#### Application identity (sub_1000264C)

1. `CreateExecutionManager(&em)`, `em` method +0x0C (`+0x2C` of the object, `&productId`): product ID of the recording process.
2. `CoCreateInstance(CLSID_PMSvc {B9E511FC-E364-497A-A121-B7B3612CEDCE}, NULL, CLSCTX_ALL, IID_IPMEnumerationManager {698D57C2-292D-4CF3-B73C-D95A6922ED9A})` ([PacMan](./pacmanserver.md)), method +0x24 (index 9, `get_ApplicationInfo(GUID productId, IPMApplicationInfo **)`: `sub_100B12D0` in pacmanserver.dll, GUID passed by value) → `IPMApplicationInfo` (class `Application`, vtable 0x1000912C in pacmanserver.dll).
3. Application method +0x1C (index 7, `get_AppTitle` ?, `sub_10062910`) → BSTR title (`<app name>` of the dialog); method +0x78 (index 30, `get_SID` ?, `sub_1006282C`) → BSTR: the application's SID string (for an application with flag 0x400 or 0x40000, `ConvertSidToStringSidW` of the principal SID from `QueryExecutableProperties(0, name, 0x04)`, else a stored string). The method names are those of the public `IPMApplicationInfo` header, matched by index (the server binary has no symbols for them).
4. `QueryExecutableProperties(2, sid, 0x01 (account name), &props)` ([SecRuntime](./secruntime.md#queryexecutableproperties-0x10004454)), copies `props+0x04` (account name) to +0x50, `ReleaseExecutableProperties`. Lookup 2 is described on the SecRuntime page as an executable path searched as a value name: how a SID string is found that way isn't checked.

### Frame listener

Vtable `off_1000131C`, called by the compositor with `this` = object +0x08 (`Release` at +0x04: not a COM interface):

| Slot | Function | Comment |
|------|----------|---------|
| 0, 1 | `sub_10002C18`, `sub_10002C3C` | AddRef, Release (deletes the object at 0) |
| 2, 3 | `sub_10002C74` | `OnInitialized(ctx)`, `OnUninitialized(ctx)`: trace only |
| 4 | `sub_10002ED8` | `(ctx, hwndForeground)`: called by `CompServer::SetActiveWindows` (0x10011324) when the foreground window changes. Window check |
| 5 | 0x10002F60 | `NeedsFrameRender(ctx)`: returns 1 |
| 6 | `sub_10002F6C` | `OnFrameRenderStart(ctx, const COMPOSITOR_FRAME_DESC *, DWORD *flags)` |
| 7 | `sub_10003118` | `OnFrameRenderEnd(ctx, desc)`: copy |
| 8, 9 | 0x10003270 | `OnFrameAborted`, `OnFramePresented`: empty |
| 10 | `sub_1000327C` | `OnFramePresentCompleted(ctx, desc)`: sample ready |

The slot names come from the other `ICompositorPALFrameListener` implementations of CompServer.dll (`DisplayFrameListener`, `VidStream`, `ScreenCaptureService::CaptureRequestDispatcher`); slot 4 has no named implementation there. `ctx` is the `ICompositorContext` of `CompServer`.

**Window check** (`sub_10002ED8`), when active, not `allowed` and `hwnd` ≠ NULL: `ctx->GetServices(&services)` (+0x14) and, while no window is recorded, `services->ValidateWindowAndOwner(hwnd, pid +0x2C)` (+0x0C); on success `hwnd` is kept at +0x28. Another foreground window afterwards → status 1 with 1 (the recording application isn't in the foreground any more).

`COMPOSITOR_FRAME_DESC` fields used (filled by `CompServer::BeginRender`, 0x10028740): +0x00 frame ID (8 bytes), +0x0C render target (`ICompositorPALBuffer`), +0x48C flags = flags of the render parameters | `CompositorDisplay::GetProtectionStatus()` (0x1D while a connection has called `SetProtectedStatus`, see [CompServer](./compserver.md#alpc-requests)), +0x490 present rotation, +0x494 rectangle (left, top, right, bottom).

**OnFrameRenderStart** (`sub_10002F6C`), when active:
1. Present rotation `desc+0x490` (1…4) → 0, 90, 180, 270 at +0x14 of the section.
2. `desc+0x48C`: bit 0x08 (part of the protection status 0x1D) and bit 0x20 (from the render parameters, meaning unknown).
3. `PhoneGetCallCounts`: if the two counts at +0x24 and +0x28 of the 44-byte structure differ (call in progress ?), byte +0x18 of the section = 1.
4. If bit 0x08, bit 0x20 or a call: the frame is skipped, unless `allowed` and bit 0x08 clear (so `allowed` records during a call, never protected content). The first skipped frame writes status 2 with 1 (paused). When frames are recorded again after a pause: status 11 (0xB) with 1 (resumed).
5. Sets flag 0x08 in `*flags` (asks the compositor for a render, as VidStream does) and, if a surface is waiting, puts the frame ID in its slot.

**Copy** (`sub_10003118` → `sub_10003138`), when active and not paused, for the slot of this frame ID with a surface handle:
1. `desc->renderTarget->GetGraphics(&graphics)` (+0x08), `graphics->OpenSharedBuffer(handle, FALSE, 0, 0, &dst)` (+0x2C): the application's surface.
2. If the rectangle `desc+0x494` has left, top ≥ 0 and right ≤ `renderTarget->GetWidth()` (+0x20): `GetHeight()` (+0x24, result not compared).
3. `graphics->ClearBufferEx(dst, {0, 0, 0, 0} (0x100012F4), &rect, 1, 1)` (+0x44), then `graphics->DrawOver(dst, renderTarget, &rect, &rect, 0, rotation 1, blend 0)` (+0x48): copies the rectangle of the composed frame into the application's surface.
4. Releases both; a failure → status 5 with the HRESULT.

**OnFramePresentCompleted** (`sub_1000327C`): for the slot of this frame ID, writes its surface handle at +0x10 of the section, `SetEvent(ScreenRecorderSampleReady)` and frees the slot. The application then registers its next surface with command 2.

### Shared section

`ScreenRecorderMetaData`, 28 bytes, created by the recording application:

| Offset | Size | Written by | Comment |
|--------|------|------------|---------|
| 0x00 | 4 | Application | Command: 0 none, 1 stop, 2 new surface, 3 ask consent |
| 0x04 | 4 | Recorder | Status (below) |
| 0x08 | 4 | Recorder | HRESULT of the command / of the status |
| 0x0C | 4 | Application | Surface handle (command 2) |
| 0x10 | 4 | Recorder | Surface handle of the copied sample (with `ScreenRecorderSampleReady`) |
| 0x14 | 4 | Recorder | Rotation of the frame: 0, 90, 180, 270 |
| 0x18 | 1 | Recorder | 1 during a phone call |

Each status is written with its value (+0x08) and signalled with `ScreenRecorderCommandCompleted` (`ReportStatus`, `sub_10002548`):

| Status | Value | When |
|--------|-------|------|
| 1 | 1 | Another window than the recorded one |
| 2 | 1 | Paused: call or protected content |
| 4 | HRESULT | `OpenHandles` failed |
| 5 | HRESULT | Frame copy failed |
| 8 | – | Command 3 accepted, consent pending (written without event) |
| 9 | `S_OK` / `E_ACCESSDENIED` | Consent result |
| 11 | 1 | Recording resumed |

### ETW

Provider `{54C2DE61-5A35-413A-8443-085EC0C4640B}` (`Microsoft-WindowsPhone-CompositionTrace`, the same as [CompServer.dll](./compserver.md#etw) and [CompClient.dll](./compclient.md#etw)), registered in `DllMain` (`EventRegister(…, sub_10001A08, &unk_10005028, &qword_10005308)`, enable bits in `dword_10005300`). The DLL writes no manifest event, only trace messages (`sub_10001DA0`, message GUID at 0x10001188, module and PDB signature found by `sub_10001C48`), all under enable bit 0x10 (`ETWBUFFERS` in CompServer): command start / end, close handles, status reports, sample copies.
