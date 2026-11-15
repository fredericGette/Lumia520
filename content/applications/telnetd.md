## telnetd.exe

Minimal telnet server: it gives a remote command prompt (any console program given on its command line) to a telnet client on the network.  
`telnetd.exe` is a small console program (49 152 bytes for ARM, 126 functions, full symbols `telnetd.pdb`). It needs no `conhost.exe`: it is its own console server. It opens the console driver (`\Device\ConDrv\Server`), starts the shell attached to that console, and serves the console API requests of the shell itself (the `Srv*` functions, a cut-down conhost). The screen buffer it keeps is translated into VT100 escape sequences sent on the socket, and the bytes received from the client are turned into console key events.  
Everything is asynchronous on the Win32 thread pool (`CreateThreadpoolIo` on the listening socket and on each client socket, `TpAllocIoCompletion` on the ConDrv server handle).

Location on the phone: ? (no path string in the binary).  
Started by: ? (no caller found among the analysed binaries; meant to be started by hand, e.g. `telnetd.exe cmd.exe`).

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `NtOpenFile`, `NtDeviceIoControlFile`, `NtCreateEvent`, `NtDuplicateObject`, `NtOpenProcess`, `NtSetInformationFile`, `NtClose`, `RtlInitUnicodeString`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlUTF8ToUnicodeN`, `RtlUnicodeToUTF8N`, `RtlCreateUserThread`, `LdrGetDllHandle`, `LdrGetProcedureAddress`, `TpAllocIoCompletion`, `TpReleaseIoCompletion`, `TpStartAsyncIoOperation`, `TpCancelAsyncIoOperation`, `TpWaitForIoCompletion`, `RtlInitializeSRWLock`, `RtlAcquireSRWLockExclusive`, `RtlReleaseSRWLockExclusive`, `RtlAcquireSRWLockShared`, `RtlReleaseSRWLockShared`, `RtlInitializeConditionVariable`, `RtlSleepConditionVariableSRW`, `RtlWakeAllConditionVariable`, `RtlNtStatusToDosError`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| WS2_32.dll | `WSAStartup`, `WSACleanup`, `WSAGetLastError`, `socket`, `setsockopt`, `bind`, `listen`, `htons`, `closesocket`, `WSARecv`, `WSASend` |
| MSWSOCK.dll | `AcceptEx` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateProcessW`, `InitializeProcThreadAttributeList`, `UpdateProcThreadAttribute`, `DeleteProcThreadAttributeList`, `TerminateProcess`, `GetCurrentProcess` |
| api-ms-win-core-threadpool-l1-2-0.dll | `CreateThreadpoolIo`, `StartThreadpoolIo`, `CancelThreadpoolIo`, `WaitForThreadpoolIoCallbacks`, `CloseThreadpoolIo`, `CreateThreadpoolTimer`, `SetThreadpoolTimer`, `WaitForThreadpoolTimerCallbacks`, `CloseThreadpoolTimer`, `CreateThreadpoolWork`, `SubmitThreadpoolWork`, `WaitForThreadpoolWorkCallbacks`, `CloseThreadpoolWork` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapFree` |
| api-ms-win-core-handle-l1-1-0.dll | `SetHandleInformation`, `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |
| api-ms-win-core-crt-l1-1-0.dll | `memmove`, `memcpy`, `memset`, `memcmp`, `_vsnprintf_s`, `toupper`, `isdigit`, `wcstoul` |
| api-ms-win-core-crt-l2-1-0.dll | `__wgetmainargs`, `_initterm`, `_initterm_e`, `exit`, `wprintf` |

`__wgetmainargs`, `_initterm*`, `exit`, the `Rtl*Unwind`/`RtlCaptureContext`, `GetCurrentProcess`/`TerminateProcess`, the unhandled-exception functions and the `/GS` cookie code are the CRT startup. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `<shell>` (first command-line argument) | `CreateProcessW` (in `TnLaunchProcess`, 0x401EB8) | Console program started for each telnet client, attached to the console served by telnetd.exe |
| `KernelBase.dll` (already loaded in the shell) | `LdrGetDllHandle` + `LdrGetProcedureAddress` of `CtrlRoutine` (in `CspGenerateControlEvent`, 0x405EE4) | The address of `KernelBase!CtrlRoutine` (the same in every process) is the start address of the thread created in the shell with `RtlCreateUserThread`, to deliver Ctrl+C / Ctrl+Break |
| `\Device\ConDrv` (`ConDrv.sys`) | `NtOpenFile` | Console driver, see [ConDrv](#condrv) |

### Parameters

| Command line | Usage | Exit code |
|---|---|---|
| `telnetd.exe <shell>` | Listens on TCP port 23. `<shell>` is the command line given unchanged to `CreateProcessW` for every client (e.g. `cmd.exe`). | Doesn't return on success (`Sleep(INFINITE)`). If the server can't be created: `"Error: %d\n"` and the Win32 / Winsock error as exit code |
| `telnetd.exe <shell> <port>` | Same, on the port `<port>` (decimal, `wcstoul` base 10, truncated to 16 bits, not checked) | Same |
| other number of arguments | Prints `"Usage: %s <shell> [port]\n"` | 87 (`ERROR_INVALID_PARAMETER`) |

`wmain` (0x402B4C) calls `WSAStartup(2.2)` (`"Failed to start winsock: %u\n"` on failure, exit code = the error), then `WsCreateServer` (0x402FAC) with the port and a pointer to the shell string, then `Sleep(INFINITE)`. `WsCloseServer` and `WSACleanup` are only reached after a failure.

### Network server

`WsCreateServer` (0x402FAC) allocates the server context (372 bytes, client context size 164, callbacks `TnpInitializeClient` / `TnpFinalizeClient`) and:

1. `WspCreateListeningSocket` (0x402BFC): `socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP)`, made non-inheritable (`SetHandleInformation`), `setsockopt(IPPROTO_IPV6, IPV6_V6ONLY, 0)` (dual stack: IPv4 clients are accepted as IPv4-mapped addresses), `bind` to `in6addr_any:<port>`, `listen(SOMAXCONN)`. No address filter and no authentication.
2. `CreateThreadpoolIo(listen socket, WspClientAccepted)`, a retry timer (`WspRetryRoutine`) and a close work item (`WspClientCloseWorker`).
3. `WspPostClientAccept` (0x402CE0): creates the next client socket (same parameters) and posts `AcceptEx` (address buffers 144 + 144 bytes, no data). If posting fails, the timer retries after 300 s, then every 60 s.

`WspClientAccepted` (0x402E64) links the new client into the server list, calls `TnpInitializeClient` and posts the next `AcceptEx`. Any number of clients can be connected at the same time, each with its own shell and console.

`TnpInitializeClient` (0x4029D0):

1. `NtSetInformationFile(socket, FileCompletionNotificationInformation (41), FILE_SKIP_COMPLETION_PORT_ON_SUCCESS)`, `CreateThreadpoolIo(socket, TnpIoCompleted)`.
2. Receive buffer 1024 bytes, send buffer 2048 bytes, input timer `TnpInputTimedOut`.
3. Sends the option negotiation (15 bytes, see below) with `TnFlushBuffer` (`WSASend`).
4. `TnLaunchProcess` (0x401EB8), then the first `WSARecv` (`TnpPostReceive`).

`TnpFinalizeClient` (0x4028F0), when the socket closes: `TerminateProcess(shell, 995)` (`ERROR_OPERATION_ABORTED`), `closesocket`, closes the thread-pool objects and the console (`CsCloseConsole`). When the shell closes its last console handle, `TnpLastClientClosed` closes the socket.

### Telnet protocol

Options sent at connection:

| Bytes | Meaning |
|---|---|
| `FF FE 01` | IAC DONT ECHO |
| `FF FB 01` | IAC WILL ECHO (the server echoes, line editing is done by telnetd.exe) |
| `FF FB 03` | IAC WILL SUPPRESS-GO-AHEAD |
| `FF FD 03` | IAC DO SUPPRESS-GO-AHEAD |
| `FF FD 1F` | IAC DO NAWS (window size) |

The client's replies are not checked. `TnpFilterIncomingData` (0x4023F8) removes every IAC command from the received data (`IAC IAC` gives a 0xFF byte) and the LF of CR LF; sub-negotiations (`IAC SB … IAC SE`, at most 16 bytes kept) go to `TnpHandleSubnegotiation` (0x402350), which only handles NAWS (`SB 1F <width:16 BE> <height:16 BE>`): width and height ≤ 300 resize the console screen buffer and window (`CsResizeScreenBuffer`, 0x403524).

`TnpGenerateInput` (0x402538) turns the remaining bytes into key events (`TnpWriteKey` → `CsWriteInput`, 0x405FBC):

| Received | Key (virtual-key code) |
|---|---|
| 0x03 | Ctrl+C (`VK 'C'` with left Ctrl, char 3) |
| 0x08, 0x09, 0x0D | Backspace, Tab, Enter |
| 0x7F | Delete (`VK_DELETE`, enhanced) |
| letters, digits | `VK` = upper-case character |
| `ESC [ A` / `B` / `C` / `D` | Up / Down / Right / Left (enhanced) |
| `ESC [ 1~` `2~` `4~` `5~` `6~` | Home, Insert, End, Page Up, Page Down |
| `ESC O P` … `ESC O S` | F1 … F4 |
| `ESC [ 15~` `17~` … `21~` `23~` `24~` | F5 … F12 |
| other bytes | character only (virtual-key 0) |

An incomplete escape sequence is sent as plain characters after 200 ms (`TnpInputTimedOut`, 0x40289C). The screen goes back to the client as VT100 sequences: `ESC[%u;%uH` (cursor position), `ESC[%uH ESC[K` (line redraw), `ESC[%um` (colour of the console attribute, `TnpSetCurrentAttribute`), text in UTF-8 (`RtlUnicodeToUTF8N`); raw `WriteConsole` output is forwarded directly (`TnpForwardOutput` / `TnpForwardOutputW`), other changes redraw the dirty region (`TnpRedrawScreen`, 0x401BFC).

### ConDrv

`TnLaunchProcess` (0x401EB8) creates a console for each client:

1. `NtOpenFile("\Device\ConDrv\Server", GENERIC_ALL, OBJ_CASE_INSENSITIVE, share read/write/delete)` → server handle.
2. `CsCreateClientHandle` (0x4053C4) opens `\Reference` relative to the server handle (`NtOpenFile`, `GENERIC_READ|GENERIC_WRITE|SYNCHRONIZE`, `FILE_SYNCHRONOUS_IO_NONALERT`).
3. `CsCreateConsole` (0x40541C): console context (2320 bytes, 80×25 window and buffer, attribute 7), `NtCreateEvent` (input-available event, `NotificationEvent`, `SYNCHRONIZE|EVENT_MODIFY_STATE`), IOCTL 0x50001F with that event, first screen buffer (`CspAllocateServerScreen`), `TpAllocIoCompletion(server handle, CspConsoleIoRead)`.
4. `\Input` and `\Output` opened like `\Reference` but inheritable (`OBJ_INHERIT`); `NtDuplicateObject` of `\Output` (same access and attributes) for the standard error.
5. Attribute list with 2 attributes: `PROC_THREAD_ATTRIBUTE_CONSOLE_REFERENCE` (0x2000A) = the `\Reference` handle, `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` (0x20002) = the 3 standard handles.
6. `CreateProcessW(NULL, <shell>, NULL, NULL, TRUE, EXTENDED_STARTUPINFO_PRESENT, NULL, NULL, &STARTUPINFOEXW, …)` with `STARTF_USESTDHANDLES` and the handles of step 4; the thread handle is closed, the process handle kept for `TerminateProcess`.
7. `CspReadNextConsoleIo` (0x404E6C) posts the first read of console requests.

| Device | IOCTL | CTL_CODE | Use |
|---|---|---|---|
| `\Device\ConDrv\Server` | 0x500006 | `FILE_DEVICE_CONSOLE` (0x50), function 1, `METHOD_OUT_DIRECT`, `FILE_ANY_ACCESS` | `IOCTL_CONDRV_READ_IO` ?: `CspReadNextConsoleIo`, asynchronous. Input = the completion of the previous request (0x1C bytes, or none), output = the next request (0x64 bytes at console + 0xBC) |
| `\Device\ConDrv\Server` | 0x50000B | function 2, `METHOD_NEITHER` | `IOCTL_CONDRV_COMPLETE_IO` ?: `CspCompleteConsoleIo` (0x404F9C), input 0x1C bytes (connect, create object) |
| `\Device\ConDrv\Server` | 0x50000F | function 3, `METHOD_NEITHER` | `IOCTL_CONDRV_READ_INPUT` ?: `ReadMessageInput` (0x404CC8), reads the client's input buffer of a request; input 0x14 bytes (request identifier 8, offset, size, buffer) |
| `\Device\ConDrv\Server` | 0x500013 | function 4, `METHOD_NEITHER` | `IOCTL_CONDRV_WRITE_OUTPUT` ?: `WriteMessageOutput` (0x404C64) and `CspReadNextConsoleIo`, writes the reply data of a request; input 0x14 bytes |
| `\Device\ConDrv\Server` | 0x50001B | function 6, `METHOD_NEITHER` | `IOCTL_CONDRV_DISCONNECT_PIPE` ?: `CsCloseConsole` (0x405580), no buffer |
| `\Device\ConDrv\Server` | 0x50001F | function 7, `METHOD_NEITHER` | `IOCTL_CONDRV_SET_SERVER_INFORMATION` ?: `CsCreateConsole`, input 4 bytes = input-available event handle |

The names are those of the Windows console driver interface (`condrv.h` of conhost); the codes match.

`CspConsoleIoRead` (0x4051A8) dispatches the requests by function code:

| Code | Request | Handling |
|---|---|---|
| 1 | Connect | `ConsoleHandleConnectionRequest` (0x404FDC): `NtOpenProcess(PROCESS_CREATE_THREAD)` of the client process (kept for the Ctrl events), completes with 0xC bytes |
| 2 | Disconnect | Removes the process from the list |
| 3 | Create object | `ConsoleCreateObject` (0x4050E0): input (type 1), current output (type 2), new screen buffer (type 3); type 4 = generic, chosen from the desired access |
| 4 | Close object | Frees a screen buffer when its reference count reaches 0 |
| 5 | Raw write (`WriteFile`) | `SrvWriteConsole` |
| 6 | Raw read (`ReadFile`) | `SrvReadConsole` |
| 7 | Console API | `ConsoleApiLayerTable`: API number = layer << 24 \| index, input message ≤ 0x5C bytes |
| other | | `STATUS_UNSUCCESSFUL` |

Console APIs served (layer 1 / layer 2; minimal input size in brackets):

| Layer | Index → function |
|---|---|
| 1 | 0 `SrvGetConsoleCP` (8), 1 `SrvGetConsoleMode` (4), 2 `SrvSetConsoleMode` (4), 3 `SrvGetConsoleNumberOfInputEvents` (4), 4 `SrvGetConsoleInput` (8), 5 `SrvReadConsole` (0x14), 6 `SrvWriteConsole` (8), 7–9 `SrvNotSupported` |
| 2 | 0 `SrvFillConsoleOutput`, 1 `SrvGenerateConsoleCtrlEvent`, 2 `SrvSetConsoleActiveScreenBuffer`, 3 `SrvFlushConsoleInputBuffer`, 4 `SrvSetConsoleCP`, 5 `SrvGetConsoleCursorInfo`, 6 `SrvSetConsoleCursorInfo`, 7 `SrvGetConsoleScreenBufferInfo` (0x5C), 8 `SrvGenerateConsoleCtrlEvent` (0x5C, `SetConsoleScreenBufferInfoEx` slot ?), 9 `SrvSetConsoleScreenBufferSize`, 10 `SrvSetConsoleCursorPosition`, 11 `SrvGetLargestConsoleWindowSize`, 12 `SrvScrollConsoleScreenBuffer`, 13 `SrvSetConsoleTextAttribute`, 14 `SrvSetConsoleWindowInfo`, 15 `SrvReadConsoleOutputString`, 16 `SrvWriteConsoleInput`, 17 `SrvWriteConsoleOutput`, 18 `SrvWriteConsoleOutputString`, 19 `SrvReadConsoleOutput`, 20 `SrvGetConsoleTitle`, 21 `SrvSetConsoleTitle` |

Layer 3 (aliases, history, fonts, display mode…) isn't served. Line input (`ENABLE_LINE_INPUT`) is edited by telnetd.exe itself, with a history (`CspAddHistoryEntry`, `CspUseHistory`). Ctrl+C / Ctrl+Break (`CspGenerateControlEvent`, 0x405EE4) start `KernelBase!CtrlRoutine` in every connected process with `RtlCreateUserThread`, parameter = the event type.
