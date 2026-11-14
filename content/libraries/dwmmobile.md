## DWMMOBILE.DLL

The "minimal DWM" of Windows Phone 8.1: the small part of the Desktop Window Manager that the phone's compositor process runs to show the redirected windows.  
`DWMMOBILE.DLL` is a small DLL (159 functions, all named from the PDB `dwmmobile.pdb`; the source paths are `windows\dwm\common\…` and `windows\dwm\shared\…`). It creates an LPC port, registers it with the window manager as the session port (`RegisterSessionPort`), and waits on it in a thread. The window manager sends it a message when a window gets or loses its DirectComposition redirection visual. The DLL opens a MIL connection and channel with [DWMCORE.DLL](./dwmcore.md), imports each window's shared visual into its channel ([dcomp.dll](./dcomp.md)`!NtDCompositionReferenceSharedResourceOnDwmChannel`), and keeps the list of windows. It puts only the visual of the foreground window in an HWND render target. In "modern core" mode (`InitializeMinDWMEx(TRUE)`), it uses one desktop render target with a grey full-screen background, and adds every window's visual to it.  
It is loaded by [CompServer.dll](./compserver.md), which calls `InitializeMinDWM` at the end of [InitializeCompositor](./compserver.md#initializecompositor-0x10017dc4) (in the shell process [MobileUI.exe](../applications/mobileui.md#startup)), `SetForegroundHwnd` when the foreground window changes, and `IsHwndForeground` before an input hit test. The callers of `InitializeMinDWMEx` and `UninitializeMinDWM` weren't found (DWMCORE.DLL also accepts a `mindwm.exe` process, not analysed).

Location on the phone: `C:\Windows\System32\DWMMOBILE.DLL` ? (extracted with `DWMCORE.DLL`, `DWMAPI.DLL`, `dcomp.dll`, `CompClient.dll` and `CompServer.dll`).  

### Imports

| DLL | Functions |
|-----|-----------|
| [DWMCORE.DLL](./dwmcore.md) | `MilCompositionEngine_InitializePartitionManager`, `MilTransport_InitializeConnectionManager`, `MilTransport_Create`, `MilTransport_Release`, `MilTransport_ShutDownConnectionManager`, `MilConnection_CreateChannel`, `MilConnection_GetChannelKernelHandle`, `MilConnection_DestroyChannel`, `MilChannel_BeginCommand`, `MilChannel_AppendCommandData`, `MilChannel_EndCommand`, `MilChannel_CommitChannel`, `MilResource_CreateOrAddRefOnChannel`, `MilResource_SendCommand`, `MilResource_DuplicateHandleOnTarget`, `MilResource_ReleaseOnChannel`, `MilComposition_PeekNextMessage`, `MilComposition_WaitForNextMessage` |
| [dcomp.dll](./dcomp.md) | `NtDCompositionReferenceSharedResourceOnDwmChannel` |
| api-ms-win-rtcore-ntuser-private-l1-1-1.dll | `RegisterSessionPort`, `UnregisterSessionPort` |
| ntdll.dll | LPC (`NtCreateWaitablePort`, `NtReplyWaitReceivePort`, `NtAcceptConnectPort`, `NtCompleteConnectPort`, `NtReplyPort`, `NtConnectPort`, `NtRequestPort`, `NtRequestWaitReplyPort`), generic tables (`RtlInitializeGenericTable`, `RtlLookupElementGenericTable`, `RtlInsertElementGenericTable`, `RtlDeleteElementGenericTable`, `RtlEnumerateGenericTableWithoutSplaying`), `NtQueryInformationProcess`, `NtQuerySystemInformation`, `RtlInitUnicodeString`, `DbgPrintEx`, `DbgPrompt` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `SetThreadPriority`, `GetCurrentProcessId`, `GetCurrentProcess`, … |
| api-ms-win-core-synch-l1-2-0.dll | critical sections, `WaitForSingleObject`, `WaitForMultipleObjectsEx`, `Sleep` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey` |
| api-ms-win-core-heap-l1-2-0.dll, -heap-obsolete-, -handle- | `HeapAlloc`, `HeapReAlloc`, `HeapFree`, `GetProcessHeap`, `LocalFree`, `CloseHandle` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `DisableThreadLibraryCalls`, `GetModuleHandleW`, `GetProcAddress` |
| api-ms-win-core-wow64-l1-1-0.dll | `IsWow64Process` |
| api-ms-win-core-errorhandling-l1-1-2.dll, -debug-, -rtlsupport- | `RaiseException`, `GetLastError`, `SetLastError`, `IsDebuggerPresent`, `RtlCaptureStackBackTrace`, … |
| msvcrt.dll | `malloc`, `free`, `memcpy`, `memset`, `operator new[]`/`delete[]`, … (CRT) |

Delay-loaded (`api-ms-win-core-delayload-l1-1-1!ResolveDelayLoadedAPI`):

| DLL | Functions |
|-----|-----------|
| api-ms-win-security-sddl-l1-1-0.dll | `ConvertStringSecurityDescriptorToSecurityDescriptorW` |
| ext-ms-win-rtcore-ntuser-sysparams-l1-1-0.dll | `GetSystemMetrics` |

The msvcrt, rtlsupport and errorhandling imports (except `RaiseException`), `TerminateProcess`, `ExitProcess` and `UnhandledExceptionFilter` are the CRT startup and `/GS` code. `NtConnectPort`, `NtRequestPort`, `NtRequestWaitReplyPort` belong to the generic `CPortClient` class, used only to stop the port thread.

### Dependencies

Files used other than the static and delay-load imports.

| File | How | Use |
|------|-----|-----|
| `kernel32.dll` | `GetModuleHandleW`, `GetProcAddress("WerRegisterMemoryBlock")` (`EnsureStackCaptureRegisteredWithWER`, 0x10004454) | Adds the stack capture buffer (`g_StackCaptureFrames`, 6144 bytes, and its index) to the error reports, as in DWMCORE.DLL |

No DLL is loaded with `LoadLibrary`, no process or COM server is started, and no file is opened.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `InitializeMinDWM` | 0x10002AFC | none; returns an HRESULT |
| 2 | `InitializeMinDWMEx` | 0x10005BB8 | `BOOL modernCore`; returns an HRESULT |
| 5 | `UninitializeMinDWM` | 0x10004978 | none, `void` |
| 4 | `SetForegroundHwnd` | 0x10002420 | `HWND`; returns `S_OK` |
| 3 | `IsHwndForeground` | 0x100023B4 | `HWND`; returns `BOOL` |

The state is the global `g_minCompositionInfo` (`MinCompositionInfo`, 0x100072A0, constructor 0x10002FB8 and `atexit` destructor from the CRT initialiser) plus `g_pSessionPort` (the `CSessionPort`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `HMIL_CONNECTIONMANAGER` |
| 0x04 | 4 | `HMIL_CONNECTION` (kernel transport) |
| 0x08 | 4 | `MIL_CHANNEL *` |
| 0x0C | 4 | Kernel handle of the channel (`MilConnection_GetChannelKernelHandle`) |
| 0x10 | 4 | Render target resource (type 0x1F) |
| 0x14 | 4 | Root visual resource (type 0x19) |
| 0x18 | 4 | Background brush ? resource (type 0x3A, modern core only) |
| 0x1C | 4 | Background render data ? resource (type 0x1B, modern core only) |
| 0x20 | 0x18 | Critical section protecting the window list |
| 0x38 | 4 | Foreground `HWND` |
| 0x3C | 0x14 | `DynArray<DCompWindow>`: data pointer (+0x3C), capacity (+0x48), count (+0x4C) |
| 0x50 | 4 | Modern core flag |

A `DCompWindow` is 8 bytes: the `HWND` and the handle of its visual on the DLL's channel.

### Startup

`_DllMainStartup` (0x10002F20, the entry point) creates the DLL's process heap (`AvCreateProcessHeap`, `WPF::g_pProcessHeap`) on `DLL_PROCESS_ATTACH` and destroys it on detach, around `_DllMainCRTStartup` (0x100038E0: `__security_init_cookie`, CRT init, then `DllMain`). `DllMain` (0x10004528) only calls `DisableThreadLibraryCalls`. Everything else is done by `InitializeMinDWM`.

### InitializeMinDWM (0x10002AFC) / InitializeMinDWMEx (0x10005BB8)

1. Creates the `CSessionPort` (`g_pSessionPort`; `E_OUTOFMEMORY` if it fails) and `CSessionPort::InitializePort` (0x10002CE0, see [Session port](#session-port)).
2. `RegisterSessionPort(portHandle)`: gives the port to the window manager. If it fails, `HRESULT_FROM_WIN32(GetLastError())` (0x88980003 if there is no error code).
3. `InitializeDesktopCompositor(…, modernCore)` (0x10002B78): 0 for `InitializeMinDWM`, the argument for `InitializeMinDWMEx`.

`InitializeDesktopCompositor`:
1. `InitializeCriticalSection`, then `MilCompositionEngine_InitializePartitionManager(12, 2, 3)` (priority 12, `MilThreadPriorityType` 2, `MilScheduleType` 3, see [DWMCORE](./dwmcore.md#partition-manager)).
2. `MilTransport_InitializeConnectionManager(NULL, &info+0x00)`.
3. `MilTransport_Create(manager, params, 36, &info+0x04)` with a 36-byte `MIL_TRANSPORT_PARAMETERS`: +0x00 = 1 (kernel transport, dcomp connection), +0x04 = 1, +0x08 = 1, +0x10 = 1, the rest 0.
4. `MilConnection_CreateChannel(connection, NULL, &info+0x08)` and `MilConnection_GetChannelKernelHandle(channel, &info+0x0C)`.
5. Sends the command `{5, 1}` (8 bytes, meaning unknown; `{5, 0}` is sent at shutdown).
6. Stores the modern core flag; in modern core mode, `InitializeDesktopRenderTarget(NULL)` ([Render target](#render-target)).
7. `MilChannel_CommitChannel`.

Any failure calls `ShutdownDesktopCompositor` and returns the HRESULT. The port isn't freed on failure.

### UninitializeMinDWM (0x10004978)

Deletes the `CSessionPort`: its destructor (0x10005F28) stops the port thread (`StopPortThread`: a `CPortClient` sends a datagram with command 0xFFFFFFFF to the port, then waits for the thread) and calls `UnregisterSessionPort`. Then `ShutdownDesktopCompositor` (0x100044CC): command `{5, 0}`, `MilConnection_DestroyChannel`, `MilTransport_Release`, `MilTransport_ShutDownConnectionManager`, `DeleteCriticalSection`.

### Session port

`CSessionPort::InitializePort` (0x10002CE0):
1. `NtQueryInformationProcess(GetCurrentProcess(), ProcessBasicInformation)`: keeps `InheritedFromUniqueProcessId` (+0x14) at port +0x4C (not used elsewhere ?).
2. `ConvertStringSecurityDescriptorToSecurityDescriptorW(L"D:(A;;0x001F0001;;;SY)(A;;0x001F0001;;;WD)(A;;0x001F0001;;;AC)")`: `0x1F0001` (`PORT_ALL_ACCESS`) for SYSTEM, Everyone and ALL APPLICATION PACKAGES.
3. `NtCreateWaitablePort(&port+0x08, attributes)`: no name, this security descriptor.
4. `StartPortThread`: `CreateThread(CPortBase::PortThread)` with `SetThreadPriority(1)` (`THREAD_PRIORITY_ABOVE_NORMAL`).

The port thread (`CPortBase::PortThreadInternal`, 0x10002698) loops:
1. `CSessionPort::WaitForMultipleObjects` (0x1000256C): `MilComposition_WaitForNextMessage(channel, 1, &port, FALSE, INFINITE)` waits for the port and the channel's messages. A channel message is read with `MilComposition_PeekNextMessage` (52-byte `MIL_MESSAGE`); type 6 raises the exception 0xE0464645 (`RaiseException`, flags argument 0xC0000025) with the HRESULT of the message as its only parameter: the same code DWMCORE raises when a partition fails ([Partition manager](./dwmcore.md#partition-manager)), so a compositor failure kills the process. Without a channel, `WaitForMultipleObjectsEx` on the port.
2. `NtReplyWaitReceivePort(port, &context, NULL, msg)` into a 280-byte `CPortMessage` (256-byte message buffer at +0x18), then by `PORT_MESSAGE` type:
   - 10 `LPC_CONNECTION_REQUEST`: always accepted (`CSessionPort::ProcessConnect` → `PortCompleteConnect`, `NtAcceptConnectPort` + `NtCompleteConnectPort`). The 24-byte `PORT_CONTEXT` holds the communication port and the client id; a generic table counts the connections of each process id.
   - 5 `LPC_CLIENT_DIED`: closes the client's port and frees its context.
   - 1 `LPC_REQUEST`, 3 `LPC_DATAGRAM`: `CSessionPort::ProcessCommand` (0x10001D64, inlined), see below. A datagram from the same process with command 0xFFFFFFFF disconnects every client and ends the thread.
3. A request (type 1) gets a reply (`ReplyToRequest` → `NtReplyPort`).

#### Messages

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 2 | `DataLength`: 16 for 0x4000004C, 12 for 0x4000004D, else `HRESULT_FROM_WIN32(ERROR_BAD_LENGTH)` 0x80070018 |
| 0x02 | 2 | `TotalLength`: at least 32 (28 if bit 0x8000 of the type is set, `LPC_KERNELMODE_MESSAGE`) |
| 0x04 | 2 | Type (1 or 3) |
| 0x08 | 8 | `ClientId` |
| 0x10 | 8 | `MessageId`, `ClientViewSize` |
| 0x18 | 4 | Command: 0x4000004C create the window's target, 0x4000004D destroy it, 0xFFFFFFFF stop (own process only) |
| 0x1C | 4 | `HWND` |
| 0x20 | 4 | ? (0x4000004C only, not read) |
| 0x24 | 4 | Handle of the window's shared DirectComposition visual (0x4000004C only), closed after use |

Other commands are ignored. The sender is the window manager the port was registered with (`RegisterSessionPort`: in [MinUser.dll](./minuser.md#exports) it is the bare system call `ZwUserRegisterSessionPort`, so the port is given to win32k, which is probably the sender ?); the shared visual is probably the redirection visual of `DCompositionCreateTargetForHwnd` ?

**0x4000004C** (`RedirCreateDCompositionHwndTarget`, inlined in the port thread):
1. `NtDCompositionReferenceSharedResourceOnDwmChannel(channelKernelHandle, sharedHandle, 25, &a, &b)` (25 = visual), then `MilResource_DuplicateHandleOnTarget(a, b, 25, channel, &visual)`: the window's visual on the DLL's channel.
2. Adds `{hwnd, visual}` to the window list (critical section).
3. If the window is the foreground window, `AttachWindowVisual` (0x100021B8): `InitializeDesktopRenderTarget(hwnd)` then the command `{0x30, rootVisual, visual, 0}` and a commit; otherwise only a commit.
4. `CloseHandle(sharedHandle)`.

Modern core (`RedirCreateDCompositionHwndTargetForModernCore`, 0x10005C74): the same import and list, then `{0x30, rootVisual, visual, count − 1}` adds every window's visual to the single root visual.

**0x4000004D** (`RedirDestroyDCompositionHwndTarget`, 0x10001FD8): looks up the window (`E_INVALIDARG` if absent), removes it from the list and sends `{0x13, visual, 0x19}` (release). If it was the foreground window, `ShutdownDesktopRenderTarget` (0x1000232C: releases the root visual `{0x13, root, 0x19}` and the target `{0x13, target, 0x1F}`, commits); else a commit. The foreground `HWND` isn't cleared.  
Modern core (`RedirDestroyDCompositionHwndTargetForModernCore`, 0x10005AB8): `{0x2F, rootVisual, visual}` (remove the child), `MilResource_ReleaseOnChannel(visual)`, commit.

### Render target

`InitializeDesktopRenderTarget(hwnd)` (0x10002224):
1. `MilResource_CreateOrAddRefOnChannel(channel, 0x1F, &info+0x10)`, then the 48-byte command 0x57 for it (see [MIL commands](#mil-commands)) with the `HWND` (NULL in modern core mode).
2. `MilResource_CreateOrAddRefOnChannel(channel, 0x19, &info+0x14)`: the root visual; `{0x5C, target, root}` sets it as the target's root.
3. Modern core only: creates resource type 0x3A (+0x18) with the 124-byte command 0xBD (colour 0.4, 0.4, 0.4, 1.0: dark grey), resource type 0x1B (+0x1C), `{0x2C, root, +0x1C}` (content of the root visual ?), then `GenerateDesktopBackground` (0x100055E4): `MilChannel_BeginCommand({0x23, +0x1C, 32})` with 32 bytes `{0x20, 0x9B, 0.0f, 0.0f, (float)GetSystemMetrics(SM_CXSCREEN), (float)GetSystemMetrics(SM_CYSCREEN), +0x18, ?}` (a rectangle of the screen size filled with the brush ?), `MilChannel_EndCommand`, commit.

So in the normal mode a render target exists only while there is a foreground window with a visual: it shows that window alone. In modern core mode there is one target with the grey background and all the windows.

### SetForegroundHwnd (0x10002420)

Does nothing in modern core mode. Otherwise, under the critical section, if `hwnd` isn't already the foreground window:
1. If a root visual exists and the old foreground window is in the list, tears down the render target (same commands as `ShutdownDesktopRenderTarget`).
2. If `hwnd` is in the list, `InitializeDesktopRenderTarget(hwnd)` and attaches its visual (`{0x30, root, visual, 0}`, commit).
3. Stores `hwnd` as the foreground window, even if it has no visual.

Always returns `S_OK`; failures are only reported to `MilInstrumentationCheckHR`. Called by [CompServer!SetActiveWindows](./compserver.md#compserver).

### IsHwndForeground (0x100023B4)

TRUE when `hwnd` isn't NULL, is in the window list and is the foreground window (under the critical section). In modern core mode the foreground window is never set, so it always returns FALSE. [CompServer.dll](./compserver.md#compositor) asks DWMCORE for an input hit test only for this window.

### MIL commands

Commands sent with `MilResource_SendCommand` (first DWORD = command id, second = resource handle). The names are guesses from their use.

| Id | Size | Fields | Use |
|----|------|--------|-----|
| 0x05 | 8 | `{5, 1}` / `{5, 0}` | Sent at init / shutdown (?) |
| 0x13 | 12 | `{0x13, handle, type}` | Release a resource (type 0x19 / 0x1F) |
| 0x23 | 12 + 32 | `{0x23, renderData, 32}` + data | Background drawing ([Render target](#render-target)) |
| 0x2C | 12 | `{0x2C, root, renderData}` | Set the root visual's content ? |
| 0x2F | 12 | `{0x2F, root, visual}` | Remove a child visual |
| 0x30 | 16 | `{0x30, root, visual, index}` | Insert a child visual |
| 0x57 | 48 | `{0x57, target, hwnd, 0, 0, 0, 0.0f, 1.0f, 0.0f, 1.0f, 0x18010, 1}` | Create the HWND render target (four floats: colour ?, 0x18010: flags ?) |
| 0x5C | 12 | `{0x5C, target, root}` | Set the target's root visual |
| 0xBD | 124 | handle +0x18, doubles 1.0, 0.5, 0.0, 0.5, 1.0, DWORDs 1, 2, 0x30, floats 0, 1, 0, 1, double 1.0, floats 0.4, 0.4, 0.4, 1.0 | Background brush ? |

Resource types: 0x19 visual ([dcomp.dll](./dcomp.md) uses 25 for its visuals), 0x1F render target, 0x1B render data ?, 0x3A brush ?.

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\Software\Microsoft\Avalon.Graphics` | `DisableInstrumentationBreaking` (DWORD) | `MilInstrumentationBreak` (0x10004B70) asserts only if the value exists and is 0. Every `MilInstrumentationCheckHR` call of the DLL uses flags 0x14, without the break flag 1, so it's never read in practice |

With flags 0x14, a failed HRESULT not in the expected list is saved in the stack capture buffer (`DoStackCapture`), and an out-of-memory error ends the process (`ExitProcess(hr)`) unless a debugger is attached.
