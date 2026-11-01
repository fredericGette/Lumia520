## qcremoteatsrvc8930.dll

Qualcomm Remote AT Command Processor Service (`RemoteAtSrvc`), build `P:\RemoteAT\rel\8.2.1.1\remoteatsrvc\arm\Release\qcremoteatsrvc8930.pdb`.  
It's the user-mode client of [qcremoteat8930.sys](../drivers/qcremoteat8930.md): a small service DLL (62 functions) that opens `\\.\REMOTEAT\REMOTEATDevice`, waits in a loop for the AT commands that the modem forwards to the application processor (`ReadFile`, 404 bytes), executes them and returns the answer (`WriteFile`, 476 bytes). It handles the 6 commands that the driver registers with the modem: `+CFUN` reboots the phone, `+CKPD` presses the hardware buttons and `+CTSA` touches the screen (both through `InputInjection.dll`), `+CSS` returns the screen size, `+CMAR` and `+CRSL` are only acknowledged. So an AT command sent to the modem (e.g. from a PC on the diagnostic / AT port, or over the air ?) can remotely drive the phone's UI.  
It's a shared service DLL (`SERVICE_WIN32_SHARE_PROCESS`, so hosted by `svchost.exe` ?) with the exports `ServiceMain` and `HandlerEx`. Nothing else in the documented binaries calls it.

Location on the phone: `C:\Windows\System32\qcremoteatsrvc8930.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| [InputInjection](./inputinjection.md) | `ApiInjectInitialize`, `ApiInjectUninitialize`, `ApiInjectButtonEvent`, `ApiInjectTouchEvent` |
| api-ms-win-core-file-l1-2-0 | `CreateFileW`, `ReadFile`, `WriteFile` |
| api-ms-win-core-io-l1-1-1 | `CancelSynchronousIo` |
| api-ms-win-core-namedpipe-l1-2-0 | `CreatePipe` |
| api-ms-win-core-threadpool-l1-2-0 | `CreateThreadpoolTimer`, `SetThreadpoolTimer`, `WaitForThreadpoolTimerCallbacks`, `CloseThreadpoolTimer` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `WaitForMultipleObjectsEx`, `Sleep`, `InitializeCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection` |
| api-ms-win-core-processthreads-l1-1-1 | `CreateThread`, `OpenThread`, `GetCurrentThreadId`, `GetCurrentProcess`, `OpenProcessToken` |
| api-ms-win-service-core-l1-1-1 | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-service-management-l1-1-0 | `OpenSCManagerW`, `OpenServiceW`, `CloseServiceHandle` |
| api-ms-win-security-lsalookup-l2-1-0 | `LookupPrivilegeValueW` |
| api-ms-win-security-base-l1-2-0 | `AdjustTokenPrivileges` |
| api-ms-win-core-shutdown-l1-1-0 | `InitiateSystemShutdownExW` |
| api-ms-win-ntuser-sysparams-l1-1-0 | `GetSystemMetrics` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-1 | `GetLastError` |
| api-ms-win-core-sysinfo-l1-2-0 | `GetTickCount`, `GetTickCount64`, `GetSystemTimeAsFileTime` |
| api-ms-win-core-debug-l1-1-1 | `OutputDebugStringW` |
| api-ms-win-core-util-l1-1-0 | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0 | `QueryPerformanceCounter` |
| MSVCR110 | `malloc`, `free`, `memset`, `memcpy`, `strcpy_s`, `_stricmp`, `isdigit`, `atoi`, `pow`, `_vsnprintf`, `_vsnwprintf`, CRT startup (`_initterm`, `_initterm_e`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_malloc_crt`, `_calloc_crt`, `_amsg_exit`, `__C_specific_handler`, `__CppXcptFilter`, `__clean_type_info_names_internal`) |

The CRT startup functions, `EncodePointer`/`DecodePointer`, `GetSystemTimeAsFileTime`, `GetTickCount64`, `GetCurrentThreadId` (except in `ServiceMain`) and `QueryPerformanceCounter` (`/GS` cookie) are the Visual C++ 2012 DLL boilerplate.  
The only traces are `OutputDebugStringW` strings ("RemoteAtSrvc, …", "RAT:…"); there's no ETW and no WPP.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\\.\REMOTEAT\REMOTEATDevice` ([qcremoteat8930.sys](../drivers/qcremoteat8930.md), symbolic link `\DosDevices\REMOTEAT`) | `CreateFileW` (`GENERIC_READ \| GENERIC_WRITE`, share 3, `OPEN_EXISTING`, synchronous), [ReadFile](../drivers/qcremoteat8930.md#readfile) / [WriteFile](../drivers/qcremoteat8930.md#writefile) | Forwarded AT commands and their answers, see [ServiceMain](#servicemain-0x100024cc). The `\REMOTEATDevice` part is the file name of the open, the driver doesn't look at it ? |
| Anonymous pipe | `CreatePipe` | Queue of the `+CTSA` actions between the main thread and the [touch thread](#touch-thread-sub_10001c34) |

[InputInjection.dll](./inputinjection.md) is a static import: it forwards the button and touch events to the CoreMessaging endpoint `IRemoteInputInjectionApi`. No DLL is loaded at run time, and no process or COM server is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `HandlerEx` | 0x10002F98 | `DWORD dwControl`, `DWORD dwEventType`, `LPVOID lpEventData`, `LPVOID lpContext`. Returns 0 (`NO_ERROR`) |
| 2 | `ServiceMain` | 0x100024CC | `DWORD argc`, `LPWSTR *argv` (both unused) |

Global state:  
| Address | Size | Comment |
|---------|------|---------|
| 0x10008210 | 1016 | Pending `+CKPD` key sequence ([below](#ckpd-key-sequence)), protected by the critical section 0x10008608 |
| 0x10008620 | 4 | Write handle of the `+CTSA` pipe |
| 0x10008624 | 4 | Handle of the `ServiceMain` thread (`OpenThread(THREAD_ALL_ACCESS)`), for `CancelSynchronousIo` |
| 0x10008628 | 4 | `SERVICE_STATUS_HANDLE` |
| 0x1000862C | 4 | Exit event of the touch thread |
| 0x10008630 | 28 | `SERVICE_STATUS`: type 0x20 (`SERVICE_WIN32_SHARE_PROCESS`), state, controls accepted 0x105 (`STOP \| SHUTDOWN \| PRESHUTDOWN`), exit codes 0, checkpoint 0, wait hint 300 000 ms |
| 0x1000864C | 4 | Stop requested (set by `HandlerEx`) |
| 0x10008650 | 4 | Event "new key sequence" (auto-reset) |
| 0x10008654 | 4 | Exit event of the keypad thread (auto-reset) |
| 0x10008658 | 4 | Touch state: 1 = finger down |
| 0x1000865C | 2 | Y of the last touch down |
| 0x10008660 | 2 | X of the last touch down |
| 0x10008664 | 4 | Handle closed when the touch timer expires; never assigned (always NULL) |

### Startup

`start` (`_DllMainCRTStartup`, 0x10003428) → `dllmain_dispatch` (`sub_1000332C`): CRT initialisation (`sub_100030D0`). `DllMain` (`sub_100024C0`) only returns TRUE.

### ServiceMain (0x100024CC)

1. `RegisterServiceCtrlHandlerExW(L"Qualcomm Remote AT Command Processor Service", HandlerEx, NULL)`. On failure it returns.
2. `OpenThread(THREAD_ALL_ACCESS, FALSE, GetCurrentThreadId())`, kept for `HandlerEx`. Fills the `SERVICE_STATUS` (see [global state](#exports)).
3. `OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS)` and `OpenServiceW(…, L"RemoteAtSrvc", SERVICE_CHANGE_CONFIG)`: only checks that the service `RemoteAtSrvc` exists, both handles are closed at once. On failure: state `SERVICE_STOPPED` and return.
4. Opens `\\.\REMOTEAT\REMOTEATDevice` ([Dependencies](#dependencies)). On failure: `SERVICE_STOPPED`, and the `SERVICE_STATUS_HANDLE` is passed to `CloseHandle` (?).
5. `InitAtCmdServices` (`sub_10002338`): creates the two keypad events and the [keypad thread](#keypad-thread-sub_1000139c), then the touch exit event and the [touch thread](#touch-thread-sub_10001c34). A failure is only traced: the service goes on.
6. `SERVICE_RUNNING`, then the loop, until the stop flag is set:
   1. `ReadFile` of 404 bytes (0x194) on the device. It blocks until the modem forwards a command. Any other size, or an error, ends the loop (`ERROR_OPERATION_ABORTED` 0x3E3 is the normal case, after `CancelSynchronousIo`).
   2. Builds the 476-byte answer (0x1DC, [WriteFile buffer](../drivers/qcremoteat8930.md#writefile)): zeroed, the first 0x110 bytes of the request copied (command handle at 0x00), result `+0x110` = 1, empty text at `+0x114`.
   3. Compares the command name (`+0x08`) with `_stricmp` and calls the handler: [`+cfun`](#cfun-sub_10002a38), [`+ckpd`](#ckpd-sub_1000108c), [`+ctsa`](#ctsa-sub_100019b4), [`+cmar`](#cmar-sub_10002dc0), [`+crsl`](#crsl-sub_10002e44), [`+css`](#css-sub_10002c64). For `+ckpd` and `+ctsa`, `ApiInjectInitialize()` is called first if it wasn't done yet; if it fails, the command isn't executed but the default answer (OK, no text) is still sent. An unknown name is answered OK too.
   4. `WriteFile` of the 476 bytes. An error is only traced.
7. On exit: sets the two exit events (threads), `SERVICE_STOPPED`, `ApiInjectUninitialize()` if it was initialised, closes the handles.

`HandlerEx`: for `SERVICE_CONTROL_STOP` (1) and `SERVICE_CONTROL_PRESHUTDOWN` (15) it sets `SERVICE_STOP_PENDING`, the stop flag and calls `CancelSynchronousIo` on the `ServiceMain` thread to end the pending `ReadFile`. `SERVICE_CONTROL_SHUTDOWN` (5), although accepted, and the other controls are ignored.

### Command request

The 404-byte buffer read from [qcremoteat8930.sys](../drivers/qcremoteat8930.md#readfile), as the service reads it:  
| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 4 | Command handle (copied into the answer) |
| 0x004 | 4 | Operation flags. The handlers test 0x0B (`NA \| EQ \| AR`: write `AT+X=…`) and 0x07 (`NA \| EQ \| QU`: test `AT+X=?`) |
| 0x008 | 22 | Command name, e.g. `+CKPD` |
| 0x01E | 2 | Number of tokens |
| 0x0D4 | 4 | If not 0, error / test answers are framed with the 2 characters below (`%c%c…%c%c`, verbose mode ?) |
| 0x0DC | 4 | First framing character (S3 ?) |
| 0x0E0 | 4 | Second framing character (S4 ?) |
| 0x0EC | 4 | `+CMEE` mode: 1 = numeric, 2 = verbose, other = no error text |
| 0x0FC | 4 | `+CMEC` keypad: 0 = `+CKPD` refused |
| 0x108 | 4 | `+CMEC` touch screen: 0 = `+CTSA` refused, only if `+0x10C` is 1 |
| 0x10C | 1 | `+0x108` is valid |
| 0x110 | 44 | Token texts |
| 0x13C | 2 × n | Offset of each token in `+0x110` |

> [!NOTE]
> In [qcremoteat8930.sys](../drivers/qcremoteat8930.md#readfile), 0x20-0xFB are the kernel pointers to the tokens, and nothing else is written at 0xD4, 0xDC, 0xE0 and 0xEC (`sub_401A48` zeroes the structure, and those are the pointers of tokens 45, 47, 48 and 51). So with this driver the `+CMEE` mode is always 0 and the error answers have no text. The `+CMEC` values at 0xFC-0x10C do come from the driver (sub-TLVs 0x18 and 0x19 of TLV 0x11).

`SetCmeeError` (`sub_100021DC`) writes the error text: `+CMEE` 1 → `+CME ERROR: 3`, 2 → `+CME ERROR: operation not allowed`, framed with the 2 characters when `+0xD4` isn't 0. The callers set the result `+0x110` to 0.

### Answer

Result at `+0x110`: 1 = OK, 0 = error. Text (200 bytes max.) at `+0x114`.

### +CFUN (sub_10002A38)

`SendWindowsShutdown`, for any form of the command (`AT+CFUN=…`, `AT+CFUN?`, …, arguments not read):
1. `OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY)`, `LookupPrivilegeValueW(NULL, L"SeShutdownPrivilege")`, `AdjustTokenPrivileges` (1 privilege, `SE_PRIVILEGE_ENABLED`).
2. `InitiateSystemShutdownExW(NULL, NULL, 0, TRUE, TRUE, SHTDN_REASON_FLAG_PLANNED)`: immediate forced **reboot**.

Result 1 if the shutdown was started; otherwise 0 and `ERROR`.

### +CKPD (sub_1000108C)

Keypad emulation (3GPP TS 27.007 `AT+CKPD=<keys>[,<time>[,<pause>]]`).
- `+CMEC` keypad (`+0xFC`) = 0: CME error, then the text is replaced by `ERROR` (result 0).
- Test (flags 0x07): OK.
- Write (flags 0x0B), 1 to 3 tokens:
  1. `BtBuildKeymap` (`sub_100012B0`) translates `<keys>` (blanks skipped, optional double quotes, up to 250 keys, stops at `,` `;` `"` `+`) with the table at 0x100048D0. Any other character fails.

     | Character | Button code |
     |-----------|-------------|
     | `D` / `d` | 3 (volume down ?) |
     | `P` / `p` | 0 (power ?) |
     | `U` / `u` | 2 (volume up ?) |

  2. `<time>` and `<pause>` (`ProcessNumArg`, `sub_10002104`: decimal digits only, 11 characters max.), in tenths of a second, default 1, must be < 256.
  3. Copies the sequence to the global 0x10008210 (critical section), sets the event 0x10008650: OK. The keys are pressed asynchronously.
- Other flags or bad arguments: `ERROR`.

#### CKPD key sequence

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 4 × 250 | Button codes |
| 0x3E8 | 4 | `<time>`: key down duration, × 100 ms |
| 0x3EC | 4 | `<pause>`: pause after each key, × 100 ms |
| 0x3F0 | 4 | Number of keys |
| 0x3F4 | 4 | Index of the next key (reset to 0 by a new command) |

### Keypad thread (sub_1000139C)

`KeybdEventThread` waits on {new sequence 0x10008650, exit 0x10008654}. For each key of the sequence: `ApiInjectButtonEvent(1, code)` (down), `Sleep(100 × time)`, `ApiInjectButtonEvent(4, code)` (up), `Sleep(100 × pause)`. The critical section is held during the whole sequence. [InputInjection.dll](./inputinjection.md#buttons) turns the codes 0, 2 and 3 into the virtual keys `VK_F13`, `VK_F9` and `VK_F10`.

### +CTSA (sub_100019B4)

Touch screen emulation (3GPP TS 27.007 `AT+CTSA=<action>,<x>,<y>`).
- `+0x10C` = 1 and `+CMEC` touch screen (`+0x108`) = 0: CME error (result 0).
- Write (flags 0x0B), at least 3 tokens: `<action>` 0 to 3, `<x>`, `<y>` (16 bits). Writes the 12-byte message {0, action, x, y} (dword, dword, int16, int16) to the pipe: OK. Bad arguments: result 0, no text.
- Test (flags 0x07): `+CTSA: (0-3)` (framed when `+0xD4` isn't 0).
- Other flags: `operation not supported`, result 0.

### Touch thread (sub_10001C34)

`TscrnEventThread` creates the pipe and a thread-pool timer (callback `HandleCtsaTimerExpiredCb`, `sub_10001944`, that writes the message {0, 4, 0, 0}), then waits on {pipe, exit event 0x1000862C} and reads 12-byte messages:  
| Action | Meaning | What is done |
|--------|---------|--------------|
| 0 | Release | If down: stops the timer; release at (x, y), or a drag from the down position to (x, y) then release. Without a previous down, ignored |
| 1 | Depress | Not down: touch down at (x, y). Already down: move at (x, y) or drag to it. Then starts the timer (1 s, one shot) |
| 2 | Single tap | Stops the timer, tap at (x, y) |
| 3 | Double tap | Stops the timer, two taps 16 ms apart |
| 4 | Timer expired (internal) | If still down: release at (0, 0) (the coordinates of the timer message) and `CloseHandle(NULL)` |

`EmulateTouch` (`sub_10001638`, x, y, flags) calls `ApiInjectTouchEvent` with a 0x8C-byte structure on the stack (only these fields are set):  
| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 2 | 0x8C (size ?) |
| 0x04 | 4 | `GetTickCount()` (time stamp ?) |
| 0x0C | 4 | 0 |
| 0x10 | 4 | 1 (number of contacts ?) |
| 0x14 | 2 | 0 (contact id ?) |
| 0x16 | 2 | Flags: 1 = down, 2 = move, 0x1004 = up |
| 0x18 | 2 | X |
| 0x1A | 2 | Y |

The flag value 5 is internal: a down (1) followed by an up (0x1004) with a time stamp 8 ms later.  
The 1 at +0x10 is a 4-byte write (`STR`), and the rest of the structure is not cleared (stack garbage at 0x02, 0x08, 0x1C…0x8B). [InputInjection.dll](./inputinjection.md#touch-structure) rejects any structure whose byte at +0x13 isn't 1…10. That byte is 0 here, so with the analysed InputInjection.dll every touch fails with `E_INVALIDARG` (0x80070057), traced as `RAT:TscrnEventThread() Touch emulation failed (release). 0x%x` / `failed (single tap)`. The `+CTSA` answer is still OK. The structure was probably written for another version of the API.  
`Drag` (`sub_10001784`, x0, y0, x1, y1, release): moves (flags 2) every 3 pixels along the line from (x0, y0) to (x1, y1), 16 ms apart, then a move to (x1, y1) and, if asked, an up there.

### +CSS (sub_10002C64)

Screen size: `GetSystemMetrics(SM_CXSCREEN)` and `GetSystemMetrics(SM_CYSCREEN)`, answered as `<x>,<y>` (no `+CSS:` prefix). Accepted without argument or with a token that starts with `?`; otherwise, or if a metric is 0, CME error.

### +CMAR (sub_10002DC0)

Master reset: **nothing is done**, the answer is OK. A token that is empty or starts with `?` gives a CME error. The phone lock code isn't checked.

### +CRSL (sub_10002E44)

Ringer sound level, not implemented: a token `?` → `+CRSL: 0`, `=?` → `+CRSL: (0 - 0)`, a number → OK (ignored), anything else (and no argument) → CME error.
