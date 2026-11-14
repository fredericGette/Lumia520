## MinUser.dll

The window manager of Windows Phone 8.1: a cut-down `user32` that keeps windows, messages, timers, hooks and pointer input in user mode, inside each process.  
`MINUSER.DLL` is a large DLL (2072 functions, 225 exports, all named from the PDB). It is not written like the rest of the system: the names show a managed-style runtime compiled to native code (`Cn::` runtime with a garbage-collected heap, GC handle table, `System::String`, `System::Collections`, reflection, `Cn::Throw` exceptions; the module strings are `nCnRuntime` and `MinUser`). The window manager itself is in the namespaces `Core` (windows, classes, atoms, message queues, timers, focus), `Input` (pointer / touch frames, input queues, delegation), `Hooks` (`SetWindowsHookEx`, WinEvents), `Power` (power setting notifications) and `SystemWindows` (desktop and message-only root). Every export is a thin native entry (`Cn::Com::NativeEntry` prologue / exit) that turns the exceptions into a return value and a last error.

What it relies on:
- `CoreMessaging.dll` for the message loop of each GUI thread (`CoreUICreate`: the thread's dispatcher drives `GetMessage` / `MsgWaitForMultipleObjects`), for the session-wide window handles (`CoreUICreateClientWindowIDManager`) and for the pointer input: CoreMessaging is the "MinUser host", from which it takes 7 `MinUser*` functions at run time ([MinUser host](#minuser-host)).
- win32k for what must stay in the kernel: the process connection (`NtModerncoreProcessConnect`, shared server info), display configuration, monitors, DPI, system parameters, and the session / compositor registration exports, which are bare system call stubs ([System calls](#system-calls)).
- [GDI32.DLL](./gdi32.md) for the display DC (`GetDC` = `CreateICW("DISPLAY")`); the two DLLs initialise each other ([Startup](#startup)).

Users found in the other pages: [GDI32.DLL](./gdi32.md) imports `ModerncoreUserInit` and `UserClientDllInitialize`; [CompServer.dll](./compserver.md#initializecompositor-0x10017dc4) (in [MobileUI.exe](../applications/mobileui.md)) loads it with `LoadLibraryExW` for `RegisterSessionProcess`, `RegisterSessionWorkerThread`, `SetNavigationServiceSid` and `ModerncoreCreateSystemThreads`. The `ext-ms-win-rtcore-ntuser-*` / `api-ms-win-rtcore-ntuser-private-*` API sets imported by [DWMMOBILE.DLL](./dwmmobile.md) (`RegisterSessionPort`), [CompClient.dll](./compclient.md), [ShellChromeAPI.dll](./shellchromeapi.md), [UIXMobile.dll](./uixmobile.md) (`GetDC` / `ReleaseDC`), [DCOMP.DLL](./dcomp.md) and [DWMCORE.DLL](./dwmcore.md) export names that this DLL has: they probably resolve here (?, the API set schema wasn't analysed).

Location on the phone: `C:\Windows\System32\minuser.dll` ?  

### Imports

| DLL | Functions |
|-----|-----------|
| msvcrt | `malloc`, `free`, `realloc`, `_aligned_offset_malloc`, `_aligned_free`, `memcpy`, `memmove`, `memset`, `memcmp`, `memchr`, `wcslen`, `wcscmp`, `wcsnlen`, `wcscpy_s`, `strlen`, `strnlen`, `swprintf_s`, `_wtoi`, `fmod`, `floor`, `_copysign`, `_CxxThrowException`, `__CxxFrameHandler3`, `__C_specific_handler`, `?terminate@@YAXXZ`, `??3@YAXPAX@Z`, `??1type_info@@UAA@XZ`, `_XcptFilter`, `_lock`, `_unlock`, `__dllonexit`, `_onexit`, `_initterm`, `_amsg_exit` |
| ntdll | `NtOpenKey`, `NtQueryValueKey`, `NtClose`, `RtlInitUnicodeString`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlMultiByteToUnicodeN`, `RtlUnicodeToMultiByteN`, `NlsMbCodePageTag`, `RtlCompareUnicodeStrings`, `RtlSetLastWin32Error`, `RtlNtStatusToDosError`, `RtlIsThreadWithinLoaderCallout`, `NtCallbackReturn` |
| CoreMessaging | `CoreUICreate`, `CoreUICreateClientWindowIDManager` |
| GDI32 | `ModerncoreGdiInit`, `GdiDllInitialize`, `CreateICW`, `DeleteDC`, `GetDeviceCaps`, `SelectObject`, `GetStockObject`, `GdiClearStockObjectCache` |
| ext-ms-win-rtcore-ntuser-dc-access-l1-1-0 | `GetDC`, `ReleaseDC` |
| ext-ms-win-rtcore-ntuser-window-ext-l1-1-0 | `GetWindowRect` |
| api-ms-win-core-apiquery-l1-1-0 | `ApiSetQueryApiSetPresence` |
| api-ms-win-core-synch-l1-2-0 | `InitializeCriticalSection(Ex)`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`, `InitOnceInitialize`, `InitOnceExecuteOnce`, `CreateEventW`, `SetEvent`, `WaitForSingleObjectEx`, `WaitForMultipleObjectsEx`, `Sleep` |
| api-ms-win-core-kernel32-legacy-l1-1-1 | `WaitForMultipleObjects` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleExW`, `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateThread`, `GetCurrentProcess(Id)`, `GetCurrentThread(Id)`, `TlsAlloc`, `TlsFree`, `TlsGetValue`, `TlsSetValue`, `TerminateProcess` |
| api-ms-win-core-handle-l1-1-0 | `DuplicateHandle`, `CloseHandle` |
| api-ms-win-core-threadpool-l1-2-0 | `CreateThreadpoolWait`, `SetThreadpoolWait`, `CloseThreadpoolWait` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventWrite` |
| api-ms-win-core-heap-l1-2-0 | `HeapCreate`, `HeapDestroy`, `HeapAlloc`, `HeapFree` |
| api-ms-win-core-interlocked-l1-2-0 | `InitializeSListHead`, `InterlockedPushEntrySList`, `InterlockedFlushSList` |
| api-ms-win-core-string-l1-1-0, localization-l1-2-1, localization-obsolete-l1-2-0 | `MultiByteToWideChar`, `WideCharToMultiByte`, `CompareStringW`, `LCMapStringW`, `GetLocaleInfoW`, `GetNumberFormatW` |
| api-ms-win-core-sysinfo-l1-2-2, timezone-l1-1-0, profile-l1-1-0 | `GetSystemTime`, `GetTickCount`, `SystemTimeToFileTime`, `QueryPerformanceFrequency` |
| api-ms-win-core-file-l1-2-1 | `WriteFile`, `FlushFileBuffers`, `LocalFileTimeToFileTime` |
| api-ms-win-core-errorhandling-l1-1-2 | `SetLastError`, `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-rtlsupport-l1-2-0 | `RtlCaptureContext`, `RtlCaptureStackBackTrace`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `RtlRaiseException` |

The msvcrt startup / C++ exception imports, `TerminateProcess`, `UnhandledExceptionFilter` and `RtlCaptureContext` are the CRT and `/GS` boilerplate. The heap, SList, string, localization, time, file (`System::Console`), `GetModuleFileNameW` (`System::Reflection::Assembly`) and unwind imports belong to the `Cn` runtime (GC heap, `System::String` formatting, exceptions). `GetDC`, `ReleaseDC` and `GetWindowRect` of the `ext-ms-win-rtcore-ntuser-*` API sets are delay-load thunks: only `GetWindowRect` is used ([Monitors](#display-monitors-and-system-metrics)).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `CoreMessaging.dll` | `LoadLibraryExW` + `GetProcAddress` of 7 functions ([MinUser host](#minuser-host)) | Pointer input initialisation, pointer device properties, pointer input targets, global handle notifications |
| `kernel32Legacy.dll` | `LoadLibraryExW`, `GetProcAddress("RaiseFailFastException")` (`Cn::FailFast::OutOfMemory`, 0x1001D7CC) | Fail-fast on out of memory or on a broken window manager thread; then a write to address 0 |
| `ext-ms-win-rtcore-ntuser-window-ext-l1-1-0` (`GetWindowRect`) | delay-load, only if `ApiSetQueryApiSetPresence` says the API set exists (`IsGetWindowRectPresent`, 0x100198A4) | `MonitorFromWindow` |
| win32k (`NtUser*`, `NtModerncore*`, display / DPI calls) | `SVC 1` system calls 0x1000…0x10F4 ([System calls](#system-calls)) | Process connection, display configuration, session registration |
| `HKLM\Software\Microsoft\Windows\Tablet PC`, `HKLM\Software\Microsoft\Windows\CurrentVersion\Media Center` | `NtOpenKey` / `NtQueryValueKey` ([Registry](#registry)) | `GetSystemMetrics` |

`OleAut32.dll` appears as a string of the runtime but nothing references it. No process, COM server or other file is opened.

### Exports

224 named exports (ordinals 2506…2726), 9 ordinal-only exports (2503…2505, 2516, 2523…2526, 2538) and `_DllMainCRTStartup` (entry point, garbage ordinal). Several names share one function (`GetWindowLongW` = `GetWindowLongA`, `WindowFromPhysicalPoint` = `WindowFromPoint`, `RealChildWindowFromPoint` = `ChildWindowFromPoint`, `GetPointerFramePenInfo` = `GetPointerPenInfoHistory`, …). The internal name is `min<Export>` for the window manager functions, `Moderncore<Export>` for the few written in C.

**Standard `user32` API** (documented signatures, implemented in the `Cn` code unless noted):

| Group | Exports |
|-------|---------|
| Windows | `CreateWindowExW`, `DestroyWindow`, `ShowWindow`, `MoveWindow`, `SetWindowPos`, `BeginDeferWindowPos` / `DeferWindowPos` / `EndDeferWindowPos`, `GetWindow`, `GetParent`, `SetParent`, `GetAncestor`, `GetTopWindow`, `IsChild`, `IsWindow`, `IsWindowVisible`, `IsWindowEnabled`, `EnableWindow`, `GetWindowRect`, `GetClientRect`, `ClientToScreen`, `ScreenToClient`, `MapWindowPoints`, `LogicalToPhysicalPoint`, `PhysicalToLogicalPoint`, `WindowFromPoint`, `ChildWindowFromPoint(Ex)`, `FindWindowW`, `FindWindowExW`, `EnumWindows`, `EnumChildWindows`, `EnumThreadWindows`, `GetWindowTextW`, `SetWindowTextW`, `GetWindowLong(Ptr)A/W`, `SetWindowLong(Ptr)A/W`, `GetWindowThreadProcessId`, `GetWindowInfo`, `RedrawWindow`, `GetPropW` / `SetPropW` / `RemovePropW` / `EnumProps(Ex)W`, `GetDesktopWindow`, `GetShellWindow` / `SetShellWindow`, `GetTaskmanWindow` / `SetTaskmanWindow` |
| Classes | `RegisterClassW`, `RegisterClassExW`, `UnregisterClassW`, `GetClassInfoW`, `GetClassInfoExW`, `GetClassNameW`, `RealGetWindowClassW`, `DefWindowProcW`, `CallWindowProcW`, `RegisterWindowMessageW` |
| Messages | `GetMessageW`, `PeekMessageW`, `DispatchMessageW`, `TranslateMessage`, `PostMessageW`, `PostThreadMessageW`, `PostQuitMessage`, `SendMessageW`, `SendMessageTimeoutW`, `SendMessageCallbackW`, `SendNotifyMessageW`, `InSendMessage(Ex)`, `WaitMessage`, `MsgWaitForMultipleObjects(Ex)`, `GetQueueStatus`, `GetMessagePos`, `GetMessageTime`, `Get/SetMessageExtraInfo`, `GetCurrentInputMessageSource`, `IsGUIThread`, `GetGUIThreadInfo` |
| Timers | `SetTimer`, `SetCoalescableTimer`, `KillTimer` |
| Focus | `GetActiveWindow`, `SetActiveWindow`, `GetFocus`, `SetFocus`, `GetForegroundWindow`, `SetForegroundWindow`, `AllowSetForegroundWindow` |
| Hooks | `SetWindowsHookExW`, `UnhookWindowsHookEx`, `CallNextHookEx`, `SetWinEventHook`, `UnhookWinEvent`, `NotifyWinEvent`, `IsWinEventHookInstalled`, `RegisterShellHookWindow`, `DeregisterShellHookWindow` |
| Pointer input | `GetPointerInfo(History)`, `GetPointerTouchInfo(History)`, `GetPointerPenInfo(History)`, `GetPointerFrameInfo(History)`, `GetPointerFrameTouchInfo(History)`, `GetPointerFramePenInfo`, `GetPointerType`, `GetPointerCursorId`, `GetPointerInputTransform`, `GetPointerDevice(s)`, `GetPointerDeviceProperties`, `GetPointerDeviceRects`, `GetRawPointerDeviceData`, `GetPointerDeviceFields`, `RegisterPointerInputTarget`, `UnregisterPointerInputTarget`, `InitializeTouchInjection`, `InjectTouchInput`, `GetCursorPos`, `SetCursorPos` |
| Power | `RegisterPowerSettingNotification`, `UnregisterPowerSettingNotification` |
| Rectangles (C) | `CopyRect`, `SetRect`, `SetRectEmpty`, `IsRectEmpty`, `EqualRect`, `InflateRect`, `OffsetRect`, `IntersectRect`, `UnionRect`, `SubtractRect`, `PtInRect` |
| Display, DPI, metrics (C, win32k) | `EnumDisplayDevicesW`, `EnumDisplaySettings(Ex)W`, `ChangeDisplaySettingsExW`, `QueryDisplayConfig`, `SetDisplayConfig`, `GetDisplayConfigBufferSizes`, `DisplayConfigGet/SetDeviceInfo`, `EnumDisplayMonitors`, `MonitorFromPoint/Rect/Window`, `GetMonitorInfoW`, `GetDpiForMonitorInternal`, `GetProcessDpiAwarenessInternal`, `SetProcessDpiAwarenessInternal`, `IsProcessDPIAware`, `SetProcessDPIAware`, `GetSystemMetrics`, `SystemParametersInfoA/W`, `GetSysColor`, `SetSysColors`, `GetDC`, `ReleaseDC` |
| Clipboard (C) | `RegisterClipboardFormatA/W`, `GetClipboardFormatNameA/W`, `CountClipboardFormats`, `IsClipboardFormatAvailable`, `OpenClipboard`, `CloseClipboard`, `EmptyClipboard`, `SetClipboardData` |
| Text (C) | `CheckDBCSEnabledExt` (`*NlsMbCodePageTag != 0`), `MBToWCSExt` |

**Stubs**: `OpenClipboard`, `CloseClipboard`, `EmptyClipboard` and `SetClipboardData` are one function (0x1001D0B4) that fails with `ERROR_NOT_SUPPORTED` (there is no clipboard data, only the format atoms). `EnableMouseInPointer`, `IsMouseInPointerEnabled` and `SkipPointerFrameMessages` are one function (0x1000D610) that fails with `ERROR_NOT_SUPPORTED`. `SetCursorPos` only stores the point in the window manager (+0x40, +0x44; initially −32768, −32768): there is no cursor.

**Private exports**:

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 2503 | (`minDelegateInput`) | 0x10002C48 | `DWORD threadId` (0 = current), `PVOID callback`, `PVOID context`, `HWND`, `DWORD` (must be 0x1000), `DWORD` (must be 0); stores a `DelegateInfo` (thread, callback, context) in the input info of the window ([Input delegation](#input)) |
| 2504 | (`minUndelegateInput`) | 0x10002538 | 2 arguments → `Input::Api::UndelegateInput` |
| 2505 | (`minHandleDelegatedInput`) | 0x10004A08 | `PVOID` → `Input::Api::HandleDelegatedInput` |
| 2516 | (`minDelegateCapturePointers`) | 0x1000D994 | `?, PVOID` → `Input::Api::DelegateCapturePointers` |
| 2538 | (`minLayoutCompleted`) | 0x1002A8D4 | `HWND`; `Window::NotifyIAM(37)` (see [Shell hook](#shell-hook-notifications)) |
| 2523…2526 | (no name) | | Same functions as `GetWindow`, `EnumWindows`, `EnumChildWindows`, `EnumThreadWindows` |
| 2506 | `InjectWinEvent` | 0x100297C8 | `DWORD event, HWND, LONG idObject, LONG idChild, DWORD threadId, DWORD time` → `Hooks::ApiPrivate::InjectWinEvent` (a WinEvent raised on behalf of another thread) |
| 2507 | `ActivateHost` | 0x10009AB0 | `BOOL`; TRUE: sets the window manager's input group (+0x3C) as foreground input group and the "host active" flag (+0x38); FALSE: no foreground group |
| 2519 | `ConfigureDesktop` | 0x100094F4 | `int, int` (ignored); applies a position change to the desktop window (`WindowPosChange::Apply`), returns TRUE |
| 2528 | `CreateWindowInBand` | 0x1000D3D8 | the `CreateWindowExW` arguments + `DWORD band` (z-band; 0 = band of the parent) |
| 2606 | `GetWindowBand` | 0x1002BC74 | `HWND, DWORD *band` |
| 2632 | `IsWindowInDestroy` | 0x1002B194 | `HWND` |
| 2682 | `SetClassScope` | 0x1002A858 | `LPCWSTR class name or atom, HINSTANCE, DWORD scope` (1 or 2, else `ERROR_INVALID_PARAMETER`); only once per class (`ERROR_ALREADY_INITIALIZED` 1247 after); the windows of a scope-2 class get a session-wide handle ([Window handles](#window-handles)) |
| 2665 | `RegisterPointerHooks` | 0x10009D14 | `BOOL register, PVOID fn1, PVOID fn2`; installs (only one pair, else `ERROR_INVALID_PARAMETER`) or removes (must be the same pair) a `DispatchHookPair` in the window manager (+0x50), used by `Hooks::DispatchHookPair::DeliverHookedMessage` |
| 2619 | `InjectInput` | 0x1000494C | `DWORD type, PVOID data`: type 0, `data` is a [touch info](#injectinput); type 1, `data` = { touch info pointer, `HWND` (ignored) }; other types `ERROR_INVALID_PARAMETER` |
| 2620 | `InjectPowerSettingNotification` | 0x1001880C | `POWERBROADCAST_SETTING *` ([Power](#power-setting-notifications)) |
| 2639 | `ModerncoreUserInit` | 0x10018134 | none; returns TRUE when the process is connected ([ModerncoreUserInit](#moderncoreuserinit-0x10018134)) |
| 2723 | `UserClientDllInitialize` | 0x10018530 | `HINSTANCE, DWORD reason, PVOID reserved` ([Startup](#startup)) |
| 2638 | `ModerncoreCreateSystemThreads` | 0x1001C9F0 | none → `NtUserCallNoParam(0)` |
| 2669 | `RegisterSessionProcess` | 0x10001698 | system call `NtModerncoreRegisterCompositorProcess` (0x10CB); [CompServer.dll](./compserver.md#initializecompositor-0x10017dc4) calls it with `(0, 0)` |
| 2670 | `RegisterSessionWorkerThread` | 0x10001680 | system call `ZwModerncoreIdleTimerThread` (0x10C8): the calling thread is given to win32k (idle timer thread ?) |
| 2690 | `SetNavigationServiceSid` | 0x100016B0 | system call `ZwModerncoreSetNavigationServiceSid` (0x10CE), `PSID` |
| 2663 | `RegisterCompositorPort` | 0x10001690 | system call `NtModerncoreRegisterCompositorPort` (0x10CA) |
| 2668, 2722 | `RegisterSessionPort`, `UnregisterSessionPort` | 0x100017B8, 0x100017D8 | system calls `ZwUserRegisterSessionPort` (0x10EF), `ZwUserUnregisterSessionPort` (0x10F3) |
| 2664, 2719 | `RegisterNavigationWindowHandle`, `UnregisterNavigationWindowHandle` | 0x100016A0, 0x100016B8 | system calls 0x10CC, 0x10CF |
| 2671 | `RegisterSharedInputGlobal` | 0x100016A8 | system call `NtModerncoreRegisterSharedInputGlobal` (0x10CD) |
| 2522, 2532 | `CreateDCompositionHwndTarget`, `DestroyDCompositionHwndTarget` | 0x10001778, 0x10001780 | system calls 0x10E7, 0x10E8 |
| 2544 | `EnumDisplayMonitors` | 0x10001098 | system call `ZwUserEnumDisplayMonitors` (0x100B), the monitor callback comes back through the [kernel callback table](#startup) |

The system call exports have no wrapper: their arguments are those of the kernel function and aren't checked here.

Window manager singleton (`Core::WindowManager::s_instance`, created by `WindowManager::_Construct`, 0x1000F458), fields used here:

| Offset | Size | Comment |
|--------|------|---------|
| 0x10 | 4 | Window manager thread handle |
| 0x14 | 4 | Class map (`Map<Atom, WindowClass>`) |
| 0x18 | 4 | Desktop window (class `DESKTOP`) |
| 0x1C | 4 | Message-only root (class `MESSAGE`, `HWND_MESSAGE`) |
| 0x24 | 4 | Window that receives the [shell hook notifications](#shell-hook-notifications) ? |
| 0x2C, 0x30 | 4 + 4 | Two `FocusMachine`s (activation and focus ?) with their validator / notifier delegates |
| 0x38 | 1 | Host active ([ActivateHost](#exports)) |
| 0x3C | 4 | Input group of the process |
| 0x40, 0x44 | 4 + 4 | Cursor position (`SetCursorPos`) |
| 0x48 | 4 | Message ID of `RegisterWindowMessage("SHELLHOOK")` |
| 0x4C | 4 | `IdentityTableManager` (window handles) |
| 0x50 | 4 | Pointer hook pair ([RegisterPointerHooks](#exports)) |

### Startup

`_DllMainCRTStartup` (0x100194C4): `__security_init_cookie`, then the CRT init and `DllMain` (0x10029EE0).  
On `DLL_PROCESS_ATTACH`, `DllMain` stores the instance, sets the runtime module callbacks (`InitializeGlobals__MinUser` / `UninitializeGlobals__MinUser`), then `Cn::HostInitialize` (0x1001850C): installs the host object `g_cnHost` (`CnHost`) and calls **`UserClientDllInitialize(hinst, DLL_PROCESS_ATTACH)`**; then `Cn::Process::Initialize` and the module strings. On `DLL_PROCESS_DETACH`: `Cn::Process::Uninitialize`, `Cn::HostUninitialize` → `UserClientDllInitialize(hinst, 0)`.

`UserClientDllInitialize` (0x10018530):
- attach: `__security_init_cookie`, `DisableThreadLibraryCalls`, creates `gcsModerncoreUserInit`, writes **`apfnDispatch` (0x10033224) to `PEB+0x2C` (`KernelCallbackTable`)** and clears `PEB+0x14C`, takes the process heap (`PEB+0x18`) as `pUserHeap`, initialises the clipboard format lock.
- detach: frees the clipboard format names, deletes the critical section.
- in both cases ends with `GDI32!GdiDllInitialize(hinst, reason)`: this is the caller that the [GDI32.DLL page](./gdi32.md#startup) was looking for.

The kernel callback table has only 3 entries: 0 and 2 `__fnEMPTY` (0x1001C8B8), 1 `__ClientMonitorEnumProc` (0x100185F0, the `EnumDisplayMonitors` callback).

The window manager itself starts lazily, on the first export call: the native entry prologue finds no runtime context and calls `CnHost::OnEnterUninitializedContext` → `InitOnceExecuteOnce(CnHost::InitializeProcess)` (0x10017094): creates the default runtime context (heap sizes 256 / 512 / 2048) and runs `Core::WindowManager::StartUp` (0x1000E6CC):

1. Boot time and tick count, the `Yield` object, registers the [ETW provider](#etw).
2. Identity lock, `IdentityGroupManager`, `ThreadInfo::GlobalInit` (TLS index), maps of WinEvent managers (per thread) and power notification lists (per GUID).
3. `WindowManager::_Construct`: atom table, identity table manager, class map, input group, focus machines, cursor (−32768, −32768), `RegisterWindowMessage("SHELLHOOK")`, `s_instance`.
4. `WindowManager::NativeStart` (0x10016F60): `CreateThread(WindowManagerThread)` and waits for its event; if the thread exits first, `HRESULT_FROM_WIN32(ERROR_NO_SYSTEM_RESOURCES)`.

`WindowManagerThread` (0x10016558): creates the desktop window (`DesktopWindow`, class `DESKTOP`, `WS_VISIBLE`) and the message-only root (`MessageOnlyRoot`, class `MESSAGE`, child of the desktop), sets the event, calls `MinUserHost::InputInitialize` (`CoreMessaging!MinUserInputInitialize`, [MinUser host](#minuser-host)), then runs `GetMessageW` / `DispatchMessageW` forever. Any failure, or the end of the loop, is a fail-fast.

### ModerncoreUserInit (0x10018134)

Once per process, under `gcsModerncoreUserInit`; called by [GDI32.DLL](./gdi32.md#moderncoregdiinit-0x4d502940) after its own init and by `GetMonitorInfoW`:

1. `NtModerncoreProcessConnect(&info, &gfServerProcess)` (0x10C9): 284 bytes copied to `gSharedInfo`; the first DWORD is `gpsi` (the shared server info read by `GetSystemMetrics`).
2. Server process (the flag returned by win32k): `gDpiAwareness` = 2; other processes call `SetProcessDpiAwarenessInternal(2)` (per-monitor aware, `NtUserSetProcessDpiAwareness`, then `ForceUpdateClientDpi` which refreshes the stock objects with `GdiClearStockObjectCache` / `GetStockObject` / `SelectObject`).
3. Marks the process connected and calls `GDI32!ModerncoreGdiInit`.

### Message loop

Each GUI thread gets a `Core::ThreadInfo` (TLS `s_tlsIndex`), created on first use:
- `ThreadInfo::NativeThreadInit` (0x1000FE88): duplicates the thread handle and waits on it with a thread pool wait (`CreateThreadpoolWait(ThreadTerminationThunk)`): the thread's windows and queue are destroyed when it ends, without `DLL_THREAD_DETACH`.
- `CoreUIAdapter::AdapterInit` (0x10015F04): `CoreUICreate` (CoreMessaging dispatcher of the thread), then on its interfaces registers `GuestLoopEntryThunk` (changes the dispatch mode when the dispatcher enters / leaves a modal loop), `GuestMessageLoopThunk` (pumps `PeekMessageW(PM_REMOVE)` / `DispatchMessageW` until the queue is empty) and `GuestCancellationThunk`.

`GetMessageW`, `WaitMessage` and `MsgWaitForMultipleObjects(Ex)` wait in `ThreadInfo::gggWaitForObjects` → `CoreUIAdapter::gggWait`: the CoreMessaging dispatcher waits for the handles, the posted / sent messages and the timers (`TimerQueue`, wake timer of the adapter). So a thread can run a CoreMessaging loop and the window messages together.

### Window handles

A window handle is an identity of the `IdentityTableManager`. Local handles come from the process table (`IdentityTable::AllocateHandle`). Session-wide handles (windows of a scope-2 class, see `SetClassScope`, and top-level windows of band 8 without owner ?) are allocated by CoreMessaging: `SystemIdManager::NativeInit` (0x1000D2F0) creates `CoreUICreate` + `CoreUICreateClientWindowIDManager`; `IdentityTableManager::AllocateGlobalIdentity` (0x1000CDA0) calls method +0x10 of the ID manager, then `CoreMessaging!MinUserNotifyGlobalHandleAllocated(handle)`; `FreeGlobalIdentity` (0x10028A68) calls `MinUserNotifyGlobalHandleFreed` then method +0x14. For a session window of another process, `SessionWindowIdAccessor` asks the ID manager (method +0x1C) for its band and owner thread / process (`ERROR_INVALID_WINDOW_HANDLE` if it isn't known).

### MinUser host

`MinUserHost::TryLoad` (0x10016C50), once: loads `Core::g_dllMinUserHost` = **`CoreMessaging.dll`** (`LoadLibraryExW`, `DllNotFoundException` if missing) and takes 7 functions (`EntryPointNotFoundException` if one is missing):

| Function | Called by |
|----------|-----------|
| `MinUserNotifyGlobalHandleAllocated(handle)` | [Window handles](#window-handles) |
| `MinUserNotifyGlobalHandleFreed(handle)` | [Window handles](#window-handles) |
| `MinUserInputInitialize()` | the window manager thread, at start |
| `MinUserRegisterPointerInputTarget(HWND)` | `RegisterPointerInputTarget` |
| `MinUserUnregisterPointerInputTarget(HWND)` | `UnregisterPointerInputTarget` |
| `MinUserGetPointerDeviceProperties(device, props *, count *)` | `GetPointerDeviceProperties` (`MinUserHost::GetPointerDeviceProperties`, 0x1000288C) |
| `MinUserGetPointerDeviceMaxInputs(2, *, *)` | `MinUserHost::GetPointerDeviceMaxInputs` (0x1000273C) |

So the touch input reaches the processes through CoreMessaging; the side of CoreMessaging that calls back into `InjectInput` / `minDelegateInput` wasn't analysed.

### Input

`Input::InputBroker` turns touch contacts into `TouchFrame`s (frame and pointer IDs from 1 / 0, coalescing, primary contact, input transform history), writes them in the `InputQueue` of the target thread and posts the pointer messages; the `GetPointer*` exports read the frames back. Device dimensions come from `GDI32!GetDeviceCaps` (`TouchFrame::GetDeviceDimensions`).

Delegation: `minDelegateInput` attaches a callback to a window; the input for it is then given to that callback (`DelegateInfo::Callback`, ETW events 1 / 2) instead of the queue, and `minDelegateCapturePointers` / `minUndelegateInput` / `minHandleDelegatedInput` manage the captured pointers. The users of these ordinal-only exports aren't known (UIX ?).

#### InjectInput

`InjectInput` type 0 / 1 → `InputBroker::InjectInput` (0x100049E0) → `InjectTouchInputCore` if the contact count isn't 0. Touch info, as read here:

| Offset | Size | Comment |
|--------|------|---------|
| 0x02 | 2 | First argument of `InjectTouchInputCore` ? |
| 0x04 | 4 | Second argument (time / frame ?) |
| 0x13 | 1 | Contact count |
| 0x14 | n × ? | `TouchContact`s |

`InitializeTouchInjection` / `InjectTouchInput` are the documented API (`InputBroker::InitializeContactsForInjection`).

### Shell hook notifications

`Window::NotifyIAM(code)` (0x10016158): if the window has misc flag 0x4000, posts the `SHELLHOOK` message (manager +0x48) with `wParam` = code and `lParam` = the window handle to the window at manager +0x24 (registered with `RegisterShellHookWindow` ?). `minLayoutCompleted` sends code 37.

### Power setting notifications

`RegisterPowerSettingNotification` keeps per GUID a `PowerNotifyList` of windows. `InjectPowerSettingNotification(setting)` (`Power::ApiPrivate::InjectPowerSettingNotification`, 0x1001887C): finds the list of `setting->PowerSetting` (nothing if none), and **sends** `WM_POWERBROADCAST` (0x218), `wParam` = `PBT_POWERSETTINGCHANGE` (0x8013), `lParam` = the setting, to each valid window of the list. The process that injects them isn't known.

### Display, monitors and system metrics

- `GetDC(hwnd)`: only `NULL` is accepted → `GDI32!CreateICW(L"DISPLAY", NULL, NULL, NULL)`; `ReleaseDC(NULL, hdc)` → `DeleteDC`. Any window gives `ERROR_INVALID_PARAMETER`.
- `ChangeDisplaySettingsExW`: `hwnd` must be NULL (else `DISP_CHANGE_BADPARAM`), then `NtUserChangeDisplaySettings` (0x10E6). `EnumDisplaySettingsExW` goes through a heap copy with `dmSize` 220. The display configuration exports go straight to the kernel and convert the NTSTATUS.
- `MonitorFromWindow` uses the delay-loaded `GetWindowRect` only if `ApiSetQueryApiSetPresence(L"ext-ms-win-rtcore-ntuser-window-ext-l1-1-0")` succeeds (result cached).
- `GetSystemMetrics` (`RealGetSystemMetrics`, 0x10017DD8): the values come from `gpsi` (+0x5D0, +0x754 or +0x8D8 depending on the DPI awareness), bits of `gpsi+0x724` for 0x2000…0x2006, `SM_REMOTESESSION` from `PEB.SessionId`, and the [registry](#registry) for `SM_TABLETPC`, `SM_DIGITIZER`, `SM_MAXIMUMTOUCHES` and `SM_MEDIACENTER`.

### Registry

Read with `NtOpenKey(KEY_READ)` / `NtQueryValueKey` (`GetRegistryKeyValue`, 0x1001829C), at each call of `GetSystemMetrics`:

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\Software\Microsoft\Windows\Tablet PC` | `IsTabletPC` (DWORD) | `SM_TABLETPC` (86): TRUE if `value & 0xD` and `value & 0x80`; `SM_DIGITIZER` (94): `value & 0xCF`; `SM_MAXIMUMTOUCHES` (95): bits 8…23 |
| `HKLM\Software\Microsoft\Windows\CurrentVersion\Media Center` | `Ident` (string, `_wtoi`) | `SM_MEDIACENTER` (87): TRUE if ≥ 5 |

### ETW

Provider `Microsoft-Windows-ModernCore-MinUser` `{43EB9151-5F00-49BF-A76F-F9873FF4EDB4}`, registered in `WindowManager::StartUp` (`McGenEventRegister`, 0x1000E5C0). All events: version 0, channel 0, level 4, keyword 0x10001000, enable bit 0x1.

| Event | Opcode, task | Written when |
|-------|--------------|--------------|
| 1 `MinUserDelegateCallbackBegin` | 1, 1 | Before a delegated input callback (`DelegateInfo::Callback`) |
| 2 `MinUserDelegateCallbackEnd` | 2, 1 | After it |
| 3 `MinUserInputQueueWrite` | 10, 2 | `InputQueue::Write` |
| 4 `MinUserInputQueueRead` | 11, 2 | `TraceEvent::InputQueueRead` (frame, pointer, message, time) |
| 5 `MinUserTouchFrameCoalesced` | 12, 3 | `TouchFrame::Coalesce` |
| 6 `MinUserPostTouchFrame` | 13, 3 | `InputBroker::PostMessages` |
| 7 `MinUserInputQueueReassign` | 14, 2 | `InputQueue::ReassignQueue` |
| 8 `MinUserSetAmbientEntry` | 16, 4 | `InputQueue::SetAmbientEntry` |
| 11 `MinUserDelegateCapturePointer` | 19, 1 | `TraceEvent::DelegateCapturePointer` |
| 16 `MinUserInputQueueMarkedOutOfRange` | 22, 2 | `InputQueue::MarkFinalEntryForPointer` |

### System calls

245 stubs (`MOVW R12, #n; SVC 1; BX LR`) from `ZwUserGetThreadState` (0x1000) to `NtValidateCompositionSurfaceHandle` (0x10F4): the same table as [DCOMP.DLL](./dcomp.md#system-calls) and [GDI32.DLL](./gdi32.md#system-calls). Used here: `NtUserGetThreadState`, `NtUserCallNoParam`, `NtUserSystemParametersInfo`, `NtUserEnumDisplayMonitors/Devices/Settings`, `NtModerncoreProcessConnect`, `NtUserChangeDisplaySettings`, the display configuration and DPI calls (0x10E9…0x10F1), `ZwUserSetSysColors` (0x10F2), and the stubs exported directly (see [Exports](#exports)). The composition, D3DKMT, OPM and region stubs are dead code in this DLL.

No RPC, WNF, COM or device.
