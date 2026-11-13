## WpToolsWrapper.exe

Helper of the Windows Phone developer tools: it starts the phone-side diagnostic tools (Application Verifier, battery logger, memory profiler) for a tool driven from the PC, and signals completion through WNF.  
`WpToolsWrapper.exe` is a small console program (262 functions, nearly all of them CRT, STL `iostream` / `locale` and `std::function` code; no UI, no exports). It takes one switch on its command line; the real arguments come from text files under `\DATA\SharedData\PhoneTools\` (written there by the PC tool ?). The work is done by the programs it starts: `AppVerif.exe`, `BatteryLogger.exe` and `rld.exe` (not analysed). The paths (`PwTools` = Windows Phone Power Tools ?, `MemoryProfiler`) suggest the Visual Studio phone tools as the caller.

Location on the phone: `\Windows\System32\WpToolsWrapper.exe` (package `Microsoft.Tools.DevToolSupport`, with `BatteryLogger.exe`; `Version` `8.1.0.1` under `HKLM\Software\Microsoft\Windows Phone\Power Tools\Packages\WpToolsWrapper.exe`, read by the `getVersion` command of [WpToolsSvc.exe](./wptoolssvc.md)).  
Triggered by: [WpToolsSvc.exe](./wptoolssvc.md#wnf-trigger-sub_1003448-0x1003448), which writes `appverif_input.txt` and publishes the value 1 on the state 0x0D92063DA3BC1875 (`startAppVerifier`) or 0x0D92063DA3BC1075 (`startBatteryLogger`), then waits 1 s for the value 2 published here. The value 1 fires a task of [TaskSchedulerSvc.dll](../libraries/taskschedulersvc.md#tasks-of-a-phone) (WNF trigger condition 1, value 1; action: start `%systemdrive%\windows\system32\WpToolsWrapper.exe` with the command line given here): `AppVerifWrapperImmediate` `{F6E92EC0-E5F9-41DF-B1BF-A0BBB4AD1071}` (0x0D92063DA3BC1875, `WpToolsWrapper.exe -appverif`), `BatteryLoggerStartImmediate` `{F6C28102-D5A4-4EC4-B31F-81FEA2735D6E}` (0x0D92063DA3BC1075, `-poweron`), `TracingFlagsSetterStartImmediate` `{B9801F66-B23F-4BD8-915D-1FD8651B88A0}` (0x0D92063DA3BC2875, `-tracingFlags`).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `RtlPublishWnfStateData`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `GetFileSizeEx`, `SetFilePointer`, `ReadFile` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateProcessW`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-processenvironment-l1-2-0.dll | `GetStdHandle` |
| api-ms-win-core-synch-l1-2-0.dll | `WaitForSingleObject`, `Sleep`, `InitializeCriticalSectionEx`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCreateKeyExW`, `RegSetValueExW`, `RegCloseKey` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleA` |
| api-ms-win-core-string-l1-1-0.dll | `GetStringTypeW`, `WideCharToMultiByte`, `MultiByteToWideChar` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| msvcrt.dll | `_wcsicmp`, `_vsnwprintf`, `malloc`, `calloc`, `free`, `wcslen`, `_wcsdup`, `__wgetmainargs`, C++ runtime (`new` / `delete`, `exception`, `bad_cast`, `_CxxThrowException`, `__CxxFrameHandler3`), locale functions and the CRT startup functions |

The application imports are `RtlPublishWnfStateData`, the file, process and registry functions and `_wcsicmp` / `_vsnwprintf`. The rest is the Visual C++ CRT startup, `/GS` cookie code, and the STL (`std::wstringstream`, `std::vector<std::wstring>`, `std::function`, locale). There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [`\Windows\System32\AppVerif.exe`](./appverif.md) | `CreateProcessW` (`-appverif`) | Application Verifier, run with the arguments read from `appverif_input.txt` |
| [`appverif.exe`](./appverif.md) (found through the search path) | `CreateProcessW` (`-tracingFlags`, `RLD` command) | `appverif.exe -installprovider vfgcleak.dll`, `appverif.exe -enable/-disable GcLeak -for <exe>` |
| `vfgcleak.dll` | Argument of `appverif.exe -installprovider` | Application Verifier provider of the `GcLeak` check (memory profiler) |
| [`\Windows\System32\BatteryLogger.exe`](./batterylogger.md) | `CreateProcessW` (`-poweron`) | Battery / power logger, merges its power samples into `wppr.etl` |
| `rld.exe` (found through the search path, location ?) | `CreateProcessW` (`-tracingFlags`, `RLD` command) | Starts, stops and analyses the `MemProfSession` trace session of the memory profiler |
| `\DATA\SharedData\PhoneTools\PwTools\log\appverif_input.txt` | `CreateFileW` (read) | Command line of `AppVerif.exe` |
| `\DATA\SharedData\PhoneTools\PwTools\log\appverif_output.txt` | `CreateFileW` (`CREATE_ALWAYS`, inheritable handle) | Receives stdout and stderr of `AppVerif.exe` |
| `\data\shareddata\phonetools\pwtools\temp`, `\data\shareddata\phonetools\pwtools\log\wppr.etl` | Arguments of `BatteryLogger.exe` | Temporary folder and output trace of the battery logger |
| `\DATA\SharedData\PhoneTools\MemoryProfiler\tracing_input.txt` | `CreateFileW` (read) | [Commands](#tracing_inputtxt) of `-tracingFlags` |
| `\DATA\SharedData\PhoneTools\MemoryProfiler\MemProfSession.rld` | Argument of `rld.exe -start … -o` | Output of the memory profiler session |

### Parameters

`wmain` (`sub_100434C`, 0x100434C) compares `argv[1]` (case-insensitive, `_wcsicmp`); other arguments are ignored. The return value (an HRESULT) is the exit code.

| Command line | Usage | Exit code | WNF published |
|---|---|---|---|
| `WpToolsWrapper.exe` | No argument | `E_FAIL` (0x80004005) | — |
| `WpToolsWrapper.exe -appverif` | [`RunTool`](#runtool-0x10040d8)(`\Windows\System32\AppVerif.exe`, arguments = content of `appverif_input.txt`, output to `appverif_output.txt`, wait) | HRESULT of the file / process calls | 0x0D92063DA3BC1875 = 2 |
| `WpToolsWrapper.exe -poweron` | [`RunTool`](#runtool-0x10040d8)(`\Windows\System32\BatteryLogger.exe`, arguments `\data\shareddata\phonetools\pwtools\temp \data\shareddata\phonetools\pwtools\log\wppr.etl`, inherited std handles, no wait) | HRESULT of the process call | 0x0D92063DA3BC1075 = 2 |
| `WpToolsWrapper.exe -tracingFlags` | Runs the commands of [`tracing_input.txt`](#tracing_inputtxt) (`sub_10042A4`, 0x10042A4) | 0, or the HRESULT of the failure | 0x0D92063DA3BC2875 = 2 (success) / 3 (failure) |
| any other value | — | `E_INVALIDARG` (0x80070057) | — |

### RunTool (0x10040D8)

`sub_10040D8(exe, args, argsFile, outFile, wait, wnfLow, wnfHigh)`, used by `-appverif` and `-poweron`:

1. If `args` is NULL, reads the whole `argsFile` with `sub_1003E44` (0x1003E44): `CreateFileW(GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING)`, `GetFileSizeEx` (empty or ≥ 4 GB → `ERROR_INVALID_DATA`), `SetFilePointer(2, FILE_BEGIN)` to skip the UTF-16 BOM, `ReadFile` into a zeroed buffer. The file is UTF-16LE text, used as is as the argument string.
2. Builds the command line `"%s %s"` (exe, args) with `_vsnwprintf`.
3. If `outFile` is set, opens it with `CreateFileW(GENERIC_WRITE, 0, SECURITY_ATTRIBUTES{bInheritHandle = TRUE}, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL)`.
4. `STARTUPINFOW` (cb 0x44) with `STARTF_USESTDHANDLES`: stdin = `GetStdHandle(STD_INPUT_HANDLE)`, stdout and stderr = the output file, or the own std handles when there's no output file.
5. `CreateProcessW(NULL, cmdline, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)`; with `wait` = 1 (`-appverif`), `WaitForSingleObject(INFINITE)`. The exit code of the tool isn't read.
6. Always (also after a failure) publishes the 4-byte value 2 to the WNF state `wnfHigh:wnfLow` with `RtlPublishWnfStateData(state, NULL, &value, 4, NULL)`, then closes the handles. Returns S_OK or `HRESULT_FROM_WIN32(GetLastError())`.

### tracing_input.txt

`-tracingFlags` wraps the work in a `std::function` called by `sub_1003DEC` (0x1003DEC), which catches the exceptions: `ATL::CAtlException` → its HRESULT, `std::bad_alloc` → `E_OUTOFMEMORY`, anything else → `E_FAIL`. Every check below throws `CAtlException(E_INVALIDARG)` (`sub_1004B08`); Win32 failures throw their HRESULT (`sub_1004B20`).

`sub_1003F6C` (0x1003F6C) reads `\DATA\SharedData\PhoneTools\MemoryProfiler\tracing_input.txt` like step 1 above (UTF-16LE, BOM skipped) and splits it at each LF (0x0A) into a vector of lines (a CR before the LF would stay in the line ?). `sub_1005218` (0x1005218) looks up line 0 in a table of two commands and calls its handler (table at 0x10026F8):

| Line 0 | Handler | Lines expected |
|---|---|---|
| `TracingFlagsSetter` | `sub_1004B48` (0x1004B48) | 3 |
| `RLD` | `sub_1005044` (0x1005044) | 3 (`-enable`, `-disable`) or 2 (`-analyze`) |

**TracingFlagsSetter** — sets the `TracingFlags` of an executable:

| Line | Content |
|---|---|
| 0 | `TracingFlagsSetter` |
| 1 | `-disable` (value 0) or `-enable` (value 1) |
| 2 | Image file name, e.g. `app.exe` (must not contain `\`) |

`RegCreateKeyExW(HKEY_LOCAL_MACHINE, L"Software\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options\\" + line 2, 0, NULL, REG_OPTION_VOLATILE, KEY_WRITE, NULL, &key, NULL)`, then `RegSetValueExW(key, L"TracingFlags", 0, REG_DWORD, &value, 4)` with value = 0 / 1.

**RLD** — memory profiler session:

| Line | Content |
|---|---|
| 0 | `RLD` |
| 1 | `-enable`, `-disable` or `-analyze` |
| 2 | Image file name for `-enable` / `-disable` (written into the command between `"`, with `\` and `"` escaped ?, `sub_1004DA8`) |

Commands run one after the other with `sub_1004F04` (0x1004F04): `CreateProcessW(NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)`, `WaitForSingleObject(INFINITE)` (exit code not checked).

| Action | Commands, in order |
|---|---|
| `-enable` | `appverif.exe -installprovider vfgcleak.dll`; `appverif.exe -enable GcLeak -for <exe> -with Core.MinimumMemoryOverhead=true GcLeak.WaitOnExitTimeout=60`; `rld.exe -start MemProfSession -o \DATA\SharedData\PhoneTools\MemoryProfiler\MemProfSession.rld` |
| `-disable` | `rld.exe -stop MemProfSession`; `appverif.exe -disable GcLeak -for <exe>` |
| `-analyze` | `rld.exe -analyze MemProfSession` |

### Registry

| Key | Value | Type | Access |
|---|---|---|---|
| `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<exe>` | `TracingFlags` | REG_DWORD | Written (0 / 1) by `TracingFlagsSetter`; key created volatile if it doesn't exist |

### WNF states

All three are published with a 4-byte value; they decode to the tag `PHTL`, version 1, well-known lifetime, system scope, sequence numbers 2, 3 and 5 (sequence number 4, 0x0D92063DA3BC2075, is the start / stop state of [BatteryLogger.exe](./batterylogger.md#wnf-states), stopped by [WpWpr.exe](./wpwpr.md#wnf-state); sequence number 1, 0x0D92063DA3BC0875, is published with the value 1 by the `startPerfmon` command of the Power Tools agent [WpToolsSvc.exe](./wptoolssvc.md) to start [WpPerfMonServer.exe](./wpperfmonserver.md)) (the readable names aren't in the binary). The value 2 is awaited by [WpToolsSvc.exe](./wptoolssvc.md#wnf-states), which publishes the value 1 on 0x0D92063DA3BC1075 and 0x0D92063DA3BC1875 to request the start.

| State name | Published by | Value |
|---|---|---|
| 0x0D92063DA3BC1075 | `-poweron` | 2 |
| 0x0D92063DA3BC1875 | `-appverif` | 2 |
| 0x0D92063DA3BC2875 | `-tracingFlags` | 2 = success, 3 = failure |
