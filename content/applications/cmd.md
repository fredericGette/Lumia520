## cmd.exe

The Windows command interpreter (command prompt and `.bat` / `.cmd` batch files), built for ARM / Windows Phone 8.1.  
`cmd.exe` is the regular Windows `cmd.exe` (192 512 bytes, 492 functions, full symbols `cmd.pdb`) built against the API sets of the phone. It's a console program: it needs a console host (e.g. [telnetd.exe](./telnetd.md), which serves the console itself). All the internal commands are in the binary (`DIR`, `COPY`, `SET`, `FOR`, `IF`, `CALL`, `START`, `MKLINK`, `ASSOC`, `FTYPE`, `PUSHD`, `COLOR`, `TITLE`…). The messages are in the MUI file `cmd.exe.mui`, and the shell-related helpers (ShellExecute, Safer, network drives, alternate streams, account names) are delay-loaded from the API set `ext-ms-win-cmd-util-l1-1-0`. Each call checks first that the API set is present.

Location on the phone: `C:\Windows\System32\cmd.exe` ? (no path string in the binary; `COMSPEC` defaults to the path of the running module, see [Environment](#environment)).  
Started by: [telnetd.exe](./telnetd.md) when it's given `cmd.exe` as its shell. No other caller was found among the analysed binaries.

### Imports

| DLL | Functions |
|-----|-----------|
| msvcrt.dll | `_wpopen`, `_pclose`, `_pipe`, `_dup`, `_dup2`, `_close`, `_open_osfhandle`, `_get_osfhandle`, `_setmode`, `_tell`, `_getch`, `fgets`, `feof`, `ferror`, `fflush`, `printf`, `fprintf`, `_iob`, `_vsnwprintf`, `swscanf`, `wcstol`, `wcstoul`, `_wtol`, `_ultoa`, `wcslen`, `wcscmp`, `wcsncmp`, `_wcsicmp`, `_wcsnicmp`, `wcschr`, `wcsrchr`, `wcsstr`, `wcsspn`, `_wcslwr`, `_wcsupr`, `towlower`, `towupper`, `iswalpha`, `iswdigit`, `iswxdigit`, `iswspace`, `strlen`, `memcpy`, `memmove`, `memset`, `memcmp`, `calloc`, `realloc`, `free`, `qsort`, `rand`, `srand`, `time`, `setlocale`, `setjmp`, `longjmp`, `__jump_unwind`, `_errno`, `__getmainargs`, `_initterm`, `_amsg_exit`, `_exit`, `_cexit`, `exit`, `__set_app_type`, `__setusermatherr`, `_fmode`, `_commode`, `_XcptFilter`, `__C_specific_handler`, `?terminate@@YAXXZ` |
| ntdll.dll | `NtOpenFile`, `NtSetInformationFile`, `NtQueryVolumeInformationFile`, `NtFsControlFile`, `NtCancelSynchronousIoFile`, `NtQueryInformationProcess`, `NtSetInformationProcess`, `NtOpenProcessToken`, `NtOpenThreadToken`, `NtQueryInformationToken`, `NtClose`, `RtlDosPathNameToNtPathName_U`, `RtlDosPathNameToRelativeNtPathName_U_WithStatus`, `RtlReleaseRelativeName`, `RtlCreateUnicodeStringFromAsciiz`, `RtlFreeUnicodeString`, `RtlFreeHeap`, `RtlNtStatusToDosError`, `RtlFindLeastSignificantBit`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateProcessW`, `CreateProcessAsUserW`, `InitializeProcThreadAttributeList`, `UpdateProcThreadAttribute`, `DeleteProcThreadAttributeList`, `GetStartupInfoW`, `OpenThread`, `ResumeThread`, `GetCurrentThreadId`, `GetCurrentProcess`, `GetExitCodeProcess`, `TerminateProcess` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `ReadFile`, `WriteFile`, `FlushFileBuffers`, `SetFilePointer`, `SetFilePointerEx`, `SetEndOfFile`, `GetFileSize`, `GetFileType`, `GetFileAttributesW`, `GetFileAttributesExW`, `SetFileAttributesW`, `SetFileTime`, `CompareFileTime`, `FileTimeToLocalFileTime`, `FindFirstFileW`, `FindFirstFileExW`, `FindNextFileW`, `FindClose`, `DeleteFileW`, `CreateDirectoryW`, `RemoveDirectoryW`, `GetFullPathNameW`, `GetVolumePathNameW`, `GetVolumeInformationW`, `GetDiskFreeSpaceExW`, `GetDriveTypeW` |
| api-ms-win-core-file-l2-1-1.dll | `CreateSymbolicLinkW`, `CreateHardLinkW`, `MoveFileExW`, `MoveFileWithProgressW`, `GetFileInformationByHandleEx` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `CopyFileW` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegDeleteValueW`, `RegDeleteKeyExW`, `RegEnumKeyExW`, `RegCloseKey` |
| api-ms-win-core-console-l1-1-0.dll | `ReadConsoleW`, `WriteConsoleW`, `GetConsoleMode`, `SetConsoleMode`, `SetConsoleCtrlHandler`, `GetConsoleOutputCP` |
| api-ms-win-core-console-l2-1-0.dll | `GetConsoleTitleW`, `SetConsoleTitleW`, `GetConsoleScreenBufferInfo`, `SetConsoleCursorPosition`, `SetConsoleTextAttribute`, `FillConsoleOutputAttribute`, `FillConsoleOutputCharacterW`, `ScrollConsoleScreenBufferW`, `FlushConsoleInputBuffer` |
| api-ms-win-core-processenvironment-l1-2-0.dll | `GetCommandLineW`, `GetStdHandle`, `GetEnvironmentStringsW`, `FreeEnvironmentStringsW`, `SetEnvironmentStringsW`, `GetEnvironmentVariableW`, `SetEnvironmentVariableW`, `ExpandEnvironmentStringsW`, `GetCurrentDirectoryW`, `SetCurrentDirectoryW`, `SearchPathW`, `NeedCurrentDirectoryForExePathW` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `GetModuleHandleW`, `GetModuleHandleA`, `GetModuleFileNameW` |
| api-ms-win-core-localization-l1-2-1.dll | `FormatMessageW`, `GetThreadLocale`, `SetThreadLocale`, `GetUserDefaultLCID`, `GetLocaleInfoW`, `GetACP`, `GetCPInfo` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetLocalTime`, `SetLocalTime`, `GetSystemTime`, `GetVersion`, `GetWindowsDirectoryW` |
| api-ms-win-core-timezone-l1-1-0.dll | `FileTimeToSystemTime`, `SystemTimeToFileTime` |
| api-ms-win-core-datetime-l1-1-1.dll | `GetDateFormatW`, `GetTimeFormatW` |
| api-ms-win-security-base-l1-2-0.dll | `GetFileSecurityW`, `GetSecurityDescriptorOwner`, `RevertToSelf` |
| api-ms-win-core-memory-l1-1-2.dll | `VirtualAlloc`, `VirtualFree`, `VirtualQuery`, `ReadProcessMemory` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapReAlloc`, `HeapFree`, `HeapSize`, `HeapSetInformation` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `GlobalAlloc`, `GlobalFree`, `LocalFree` |
| api-ms-win-core-synch-l1-2-0.dll | `WaitForSingleObject`, `InitializeCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `AcquireSRWLockShared`, `ReleaseSRWLockShared`, `TryAcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`, `Sleep` |
| api-ms-win-core-string-l1-1-0.dll | `MultiByteToWideChar`, `WideCharToMultiByte` |
| api-ms-win-core-string-obsolete-l1-1-0.dll | `lstrcmpW`, `lstrcmpiW` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle`, `DuplicateHandle` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetLastError`, `SetErrorMode`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-systemtopology-l1-1-0.dll | `GetNumaHighestNodeNumber`, `GetNumaNodeProcessorMaskEx` |
| api-ms-win-core-processtopology-l1-2-0.dll | `GetThreadGroupAffinity` |
| api-ms-win-core-processtopology-obsolete-l1-1-0.dll | `SetProcessAffinityMask` |
| api-ms-win-core-apiquery-l1-1-0.dll | `ApiSetQueryApiSetPresence` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| ext-ms-win-cmd-util-l1-1-0.dll (delay-load) | `ShellExecuteWorker`, `SaferWorker`, `CmdBatNotificationStub`, `MessageBeepStub`, `GetVDMCurrentDirectoriesStub`, `DoSHChangeNotify`, `QueryFullProcessImageNameWStub`, `WNetGetConnectionWStub`, `WNetAddConnection2WStub`, `WNetCancelConnection2WStub`, `LookupAccountSidWStub`, `FindFirstStreamWStub`, `FindNextStreamWStub` |
| ext-ms-win-branding-winbrand-l1-1-0.dll (delay-load) | `BrandingFormatString` |

`__getmainargs`, `_initterm`, `_amsg_exit`, `_exit`, `_cexit`, `__set_app_type`, `__setusermatherr`, `_fmode`, `_commode`, `_XcptFilter`, `?terminate@@YAXXZ`, the `Rtl*Unwind` / `RtlCaptureContext`, the unhandled-exception functions and the `/GS` cookie code are the CRT startup. The delay-load imports go through `__delayLoadHelper2` with the hook `CmdDelayHook` (0x41A108): if `ReportDelayLoadErrors` is set, a failed load prints message 0x400027DC and a missing function prints 0x400027DD / 0x400027DE, followed by the Win32 error. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `cmd.exe.mui` (`<language>\cmd.exe.mui` ?, not analysed) | `FormatMessageW(FORMAT_MESSAGE_FROM_HMODULE \| FROM_SYSTEM \| …, NULL, id, …)` in `FindMsg` (0x404F1C), `GetMsg` (0x4115A4) and `WriteMsgString` (0x40355C) | All the messages and help texts. The `MUI` resource of cmd.exe lists `MESSAGETABLE` (type 11) among the types held by the MUI file. Only the string tables, the icon `IDI_APPICON`, the version and the manifest are in cmd.exe. If a message can't be found, `FindMsg` prints message 0x13D with the number in hex and `"Application"` (ids ≥ 0x2328) or `"System"` |
| `KERNEL32.DLL` | `GetModuleHandleW` + `GetProcAddress` (`Init`, 0x405DB8; `CmdSetThreadUILanguage`, 0x40B568) | `SetThreadUILanguage` (falls back to `SetThreadLocale(1033)` when missing), `CopyFileExW` (`lpCopyFileExW`, used by `COPY`), `IsDebuggerPresent`, `SetConsoleInputExeNameW` |
| `NTDLL.DLL` | `LoadLibraryExW(L"NTDLL.DLL", NULL, 0)` + `GetProcAddress("NtQueryInformationProcess")` (`GetProcessSubsystemTypeFromAddressSpace`, 0x419070) | Reads the PEB of a started process (`ProcessBasicInformation`, then `ReadProcessMemory` of the PEB and of the PE header of its image) to get its subsystem. An interactive cmd doesn't wait for a GUI (subsystem 2) program |
| `ext-ms-win-cmd-util-l1-1-0` (host DLL on the phone: ?) | Delay-load. Each call is guarded by `ApiSetQueryApiSetPresence` (`IsQueryFullProcessImageNameWStubPresent`, 0x4126B0). When the API set is absent, the feature is skipped | `ShellExecuteWorker`: `ExecPgm` and `START` when `CreateProcessW` fails with `ERROR_BAD_EXE_FORMAT` (0xC1, extensions on) or `ERROR_ELEVATION_REQUIRED` (0x2E4). `SaferWorker`: Safer check of a batch file (`SetBat`). `CmdBatNotificationStub`: begin / end of a batch (`BatProc`, `SigCleanUp`). `DoSHChangeNotify`: after `ASSOC` changes. `QueryFullProcessImageNameWStub`: `GetProcessSubsystemType`. `WNet*`: `PUSHD` / `POPD` of UNC paths and the `$M` prompt code. `LookupAccountSidWStub`: `DIR /Q`. `FindFirstStreamWStub` / `FindNextStreamWStub`: `DIR /R`. `MessageBeepStub`: beep of the line editor. `GetVDMCurrentDirectoriesStub`: `RestoreCurrentDirectories` |
| `ext-ms-win-branding-winbrand-l1-1-0` (host DLL on the phone: ?) | Delay-load, guarded by `ApiSetQueryApiSetPresence` (`IsBrandingFormatStringPresent`, 0x412610) | `BrandingFormatString(L"%WINDOWS_COPYRIGHT%")` for the banner (`CmdGetBrandingString`, 0x418CD0). Fallback: the built-in `"Copyright (c) Microsoft Corporation. All rights reserved."`. `©` and `®` are replaced by `(c)` |
| Any program found through `PATH` / `PATHEXT` | `CreateProcessW` / `CreateProcessAsUserW` (`ExecPgm`, 0x40D84C), see [Starting programs](#starting-programs) | External commands |
| `cmd.exe` / `%COMSPEC%` | `CreateProcessW` (`Start`, 0x40E870) | `START` with no program runs `cmd.exe`. `START` of a batch file runs `%COMSPEC% /K <batch>` |
| `%COMSPEC%` | msvcrt `_wpopen` (`FParseWork`, 0x40CE84) | `FOR /F ('command')`: the command runs in a child command interpreter whose output is read through a pipe |
| `XCOPY.EXE` | Name compared in `ExecPgm` | When `xcopy.exe` is started from a batch file or `/C` / `/K`, `AppendEnvVar` adds `/-Y` to `COPYCMD` for the child. `COPYCMD` is restored afterwards |
| `AutoRun` commands | Registry, see [Registry](#registry) | Command lines run before the first prompt / command (unless `/D`) |

### Parameters

The command line is read with `GetCommandLineW` (at most 0x2000 characters, copied into `TmpBuf`) and parsed by `CheckSwitches` (0x40703C), called from `Init` (0x405DB8). Each switch is a `/` followed by one letter (case-insensitive). Processed switches are removed from the buffer. Parsing stops at `/C`, `/R` or `/K`: the rest of the line is the command.

| Command line | Usage | Exit code |
|---|---|---|
| `cmd /?` | Prints help messages 0x40002399–0x4000239B, plus 0x4000239C–0x4000239E when command extensions are enabled. Output pauses page by page (`BeginHelpPause`) | 1 |
| `cmd /C <string>` (or `/R`) | `SingleCommandInvocation = 1`. Runs `<string>` (`Parser` + `Dispatch` in `main`, 0x40DCA0) after the AutoRun commands, then exits. Quotes: if `/S` wasn't given and `<string>` starts with `"`, the quotes are kept only when (1) the string has exactly two quotes, (2) there's none of `& < > @ ^ \|` between them, (3) there's whitespace between them, and (4) the quoted text names an executable (`SearchForExecutable`). Otherwise the first and the last quote are removed | Value returned by the command (`ERRORLEVEL` of the last external program). 255 after a fatal error (`longjmp` to `MainEnv`) |
| `cmd /K <string>` | `SingleBatchInvocation = 1`. Same quote rules as `/C`. Runs `<string>`, then continues with the interactive prompt | Code given to `EXIT` |
| `/S` | Turns off the quote-keeping rules of `/C` / `/K` (the outer quotes are always removed) | |
| `/Q` | `Necho = 1`: echo off | |
| `/D` | Clears the HKLM and HKCU `AutoRun` commands already read | |
| `/A` / `/U` | `fOutputUnicode = 0 / 1`: ANSI or UTF-16 output to a pipe or a file | |
| `/T:fg` | Only when extensions are enabled: exactly two hex digits, background `f` and foreground `g` (`wDefaultColor`), applied with `SetColor` if stdout is a console | |
| `/E:ON`, `/E:OFF`, `/E` | Command extensions on / off (`fEnableExtensions`); `/E` alone = on. `/X` = `/E:ON`, `/Y` = `/E:OFF` | |
| `/F:ON`, `/F:OFF`, `/F` | File and directory name completion: `CompletionChar` = Ctrl+F (6), `PathCompletionChar` = Ctrl+D (4), or both off (0x20) | |
| `/V:ON`, `/V:OFF`, `/V` | Delayed expansion with `!var!` (`fDelayedExpansion`) | |

Without `/C` or `/K`, `main` runs the AutoRun commands, then the read / parse / dispatch loop on stdin. If stdin isn't a device, it's switched to binary mode (`_setmode(0, _O_BINARY)`). The loop ends on end of file (exit code 0) or `EXIT`.

If the `DisableCMD` policy is 1, cmd.exe prints message 0x40002729, waits for a key (`ePause`) and exits with code 255 right after `Init`. If it's 2, the same happens only when the interactive prompt would start, so `/C` commands and batch files still run.

### Registry

| Key | Value | Type | Use |
|-----|-------|------|-----|
| `HKCU\Software\Policies\Microsoft\Windows\System` | `DisableCMD` | DWORD | Read by `main`. 1 = command interpreter disabled; 2 = only the interactive prompt disabled |
| `HKLM\Software\Microsoft\Command Processor`, then `HKCU\…` (same values, HKCU wins) | `DisableUNCCheck` | DWORD or string (`_wtol`) | 1 = no error when the current directory is a UNC path (`fDisableUNCCheck`) |
| | `EnableExtensions` | DWORD / string | Default of the command extensions (on when the value is absent) |
| | `DelayedExpansion` | DWORD / string | Default of delayed expansion |
| | `DefaultColor` | DWORD / string (`wcstol`, base auto) | Console colour, as for `COLOR` / `/T` |
| | `CompletionChar` | DWORD / string | Control character for file name completion; values 0, 0x0D or > 0x20 mean off (0x20) |
| | `PathCompletionChar` | DWORD / string | Same, for directory names. If only one of the two is set, the other gets the same value |
| | `AutoRun` | REG_SZ or REG_EXPAND_SZ (expanded with `ExpandEnvironmentStringsW`), up to 0x1000 bytes | Command run at start-up (HKLM first, then HKCU) unless `/D` was given |
| `HKLM\Software\Classes\<.ext>` | default value | REG_SZ | Read and written (`RegCreateKeyExW` / `RegSetValueExW` / `RegDeleteKeyExW`) by `ASSOC` (`AssocWork`, 0x41BB6C; `SetAssoc`, 0x41A484) |
| `HKLM\Software\Classes\<filetype>\Shell\Open\Command` | default value | REG_SZ | Read and written by `FTYPE` (`FTypeWork`, 0x41BA84; `SetFType`, 0x41A160; `DisplayFType`, 0x41A2BC) |

The `Command Processor` values are read by `GetRegistryValues` (0x405B68), which also seeds `rand` with `srand(time(NULL))` for `%RANDOM%`.

### Environment

`SetUpEnvironment` (0x40D7B4) gives defaults to the variables that are missing: `PATH` = empty, `PATHEXT` = `.COM;.EXE;.BAT;.CMD;.VBS;.JS;.WS;.MSC`, `PROMPT` = `$P$G`, `COMSPEC` = the path of the module from `GetModuleFileNameW` (with `\CMD.EXE` appended if it has no extension). `KEYS=ON` turns on the line editor. Dynamic variables: `%CD%`, `%DATE%`, `%TIME%`, `%RANDOM%`, `%ERRORLEVEL%`, `%CMDEXTVERSION%`, `%CMDCMDLINE%`, `%HIGHESTNUMANODENUMBER%`, and `=ExitCode` / `=ExitCodeAscii`, set after each external program (`%08X` and, for codes 0x20–0x7E, the character).

### Line input

cmd.exe has no command history: no history code and no `DOSKEY`. Line editing and history belong to the console server that handles `ReadConsoleW` (the console host, or [telnetd.exe](./telnetd.md#line-input)).

File name completion is done by cmd.exe itself. `ReadBufFromConsole` (0x411DC0) reads a line with `ReadConsoleW(stdin, buffer, size, &read, &control)`. It passes a `CONSOLE_READCONSOLE_CONTROL` only when extensions are on, both completion characters are below 0x20 and `GetConsoleScreenBufferInfo` succeeds on stdout. Otherwise it passes no control structure:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0x10 | `nLength` |
| 0x04 | 4 | 0, then the length of the completed text | `nInitialChars`: the characters already in the buffer, which the console must keep |
| 0x08 | 4 | `(1 << chCompletionCtrl) \| (1 << chPathCompletionCtrl)` | `dwCtrlWakeupMask`: the read ends as soon as one of these characters is typed |
| 0x0C | 4 | 0 (returned by the console) | `dwControlKeyState` |

When the returned line ends with a completion character instead of CR:

1. The line is cut at that character. The completion is for directories only when the character is `PathCompletionChar`, or when the line starts with `cd `, `rd `, `md `, `chdir `, `rmdir `, `mkdir ` or `pushd `.
2. `DoComplete` (0x41C6D0) takes the last word of the line. Words are separated by a space or one of ``&()[]{}^=;!%'+,`~``, and quotes are honoured. It appends `*` when the word has no `*` / `?` and lists the matches with `CompleteDir` (0x41C438). Each new press moves to the next match, and to the previous one when `dwControlKeyState` has `SHIFT_PRESSED` (0x10). The list wraps around and is kept until the line changes.
3. The line is redrawn: `SetConsoleCursorPosition` back to the start of the input, `FillConsoleOutputCharacterW` with spaces, `WriteConsoleW` of the new line.
4. `ReadConsoleW` is called again with `nInitialChars` = the length of the new line.

With no match, the line is kept and `MessageBeepStub(0xFFFFFFFF)` is called (only when `ext-ms-win-cmd-util-l1-1-0` is present). The default characters are Tab for both; they are set by `CompletionChar` / `PathCompletionChar` ([Registry](#registry)) or `/F:ON` (Ctrl+F / Ctrl+D) and `/F:OFF` ([Parameters](#parameters)).

### Starting programs

`ExecPgm` (0x40D84C) starts an external command:

1. A one-entry attribute list with `UpdateProcThreadAttribute(0x60001 = PROC_THREAD_ATTRIBUTE_EXTENDED_FLAGS, value 1 = EXTENDED_PROCESS_CREATION_FLAG_ELEVATION_HANDLED ?)`.
2. A `STARTUPINFOEXW` (see the table below).
3. `CreateProcessW(<full path>, <command line>, NULL, NULL, TRUE, EXTENDED_STARTUPINFO_PRESENT, NULL, <current directory>, &si, &pi)`. When a batch file is running and saved a token (`CurrentBatchFile+0x30`, from `SaferWorker`), `CreateProcessAsUserW` is used with that token and the same arguments.
4. If that fails, `ShellExecuteWorker` is tried (see [Dependencies](#dependencies)). Otherwise `ExecError` prints the error.
5. The thread handle is closed. cmd.exe waits for the process (`WaitProc`: `WaitForSingleObject` + `GetExitCodeProcess`, stored in `LastRetCode` / `ERRORLEVEL`) unless the command is one side of a pipe, or the program is a GUI one (subsystem 2, `GetProcessSubsystemType`) started from the interactive prompt with extensions on.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0x48 | `cb` (`sizeof(STARTUPINFOEXW)`) |
| 0x08 | 4 | `lpDesktop` from cmd's own `GetStartupInfoW` | Same desktop as cmd.exe |
| 0x0C | 4 | Title (argument of `ExecPgm`) | `lpTitle` |
| 0x10 | 0x10 | 0, 1, 100, 100 | `dwX`, `dwY`, `dwXSize`, `dwYSize`, ignored (`dwFlags` = 0) |
| 0x2C | 4 | 0 | `dwFlags`: the standard handles are inherited (`bInheritHandles = TRUE`), not passed |
| 0x30 | 2 | 1 | `wShowWindow` = `SW_SHOWNORMAL` (ignored; also passed to `ShellExecuteWorker`) |
| 0x44 | 4 | Attribute list | `lpAttributeList` |

`START` (`Start`, 0x40E870) options include `MIN`, `MAX`, `SEPARATE`, `SHARED`, `LOW`, `BELOWNORMAL`, `NORMAL`, `ABOVENORMAL`, `HIGH`, `REALTIME`, `NODE`, `AFFINITY` and `WAIT` (strings of the binary). It builds an attribute list with room for two entries: the same extended flags, plus a second attribute when a NUMA node is given. Then it calls `CreateProcessW(…, bInheritHandles = TRUE, <flags> | CREATE_UNICODE_ENVIRONMENT, <environment>, <directory>, …)`, where `<flags>` starts as `EXTENDED_STARTUPINFO_PRESENT`. Without `WAIT` it doesn't wait (`WaitProc` is called only on the wait path).

Pipes (`ePipe`, 0x406268): `_pipe(…, 0, _O_BINARY)`; both sides are dispatched with stdout / stdin redirected. Internal commands in a pipe run in a child `%COMSPEC% /S /D /c" <command>"` (`UnParse`, 0x40540C).

### File system controls

| Code | Name | Sent by | Buffers |
|------|------|---------|---------|
| 0x900A8 (device 0x9 `FILE_DEVICE_FILE_SYSTEM`, function 0x2A, `METHOD_BUFFERED`, `FILE_ANY_ACCESS`) | `FSCTL_GET_REPARSE_POINT` | `DeviceIoControl` in `NewDisplayFile` (0x41113C, `DIR` of a reparse point) | Handle from `CreateFileW(path, FILE_READ_EA, share 7, NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS \| FILE_FLAG_OPEN_REPARSE_POINT)`. No input, output 0x4002 bytes (`REPARSE_DATA_BUFFER`). Used to print the target of a reparse point; `" [...]"` is printed when the call fails (`" [..]"` when the file can't be opened) |
| 0x900A4 (device 0x9, function 0x29, `METHOD_BUFFERED`, `FILE_ANY_ACCESS`) | `FSCTL_SET_REPARSE_POINT` | `NtFsControlFile` in `MakeJunction` (0x419474, `MKLINK /J`) | See below |

`MKLINK` (`MakeLink`, 0x41C2A4): no switch or `/D` → `CreateSymbolicLinkW(link, target, /D ? SYMBOLIC_LINK_FLAG_DIRECTORY : 0)`. Error 1314 (privilege not held) prints message 0x40002731. `/H` → `CreateHardLinkW`. `/J` → `MakeJunction`, which works only on a local volume (`MaybeVolumeLocal`; otherwise message 0x40002749). It calls `CreateDirectoryW(link)` and `CreateFileW(link, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS)`, converts the target with `RtlDosPathNameToNtPathName_U`, then sends this `REPARSE_DATA_BUFFER` (no output buffer):

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0xA0000003 | `IO_REPARSE_TAG_MOUNT_POINT` |
| 0x04 | 2 | total size − 8 | `ReparseDataLength` |
| 0x06 | 2 | 0 | Reserved |
| 0x08 | 2 | 0 | `SubstituteNameOffset` |
| 0x0A | 2 | length of the NT path (bytes) | `SubstituteNameLength` |
| 0x0C | 2 | `SubstituteNameLength` + 2 | `PrintNameOffset` |
| 0x0E | 2 | `wcslen(target) * 2` | `PrintNameLength` |
| 0x10 | … | `\??\<target>`, NUL, `<target>` as typed | `PathBuffer` |

`DEL` (`FastDeleteFile`, 0x404C7C) opens the file with `NtOpenFile(DELETE, FILE_SHARE_DELETE, FILE_NON_DIRECTORY_FILE | FILE_DELETE_ON_CLOSE | FILE_OPEN_FOR_BACKUP_INTENT)` and closes it. `NtSetInformationFile(FileDispositionInformation, TRUE)` is added only when `IsWorkaroundForDeleteFileOnOldSambaNeeded` says so. Otherwise, or when the open fails, it falls back to `DeleteFileW`. `RD /S` on long paths goes through the `\\?\` prefix (`RmDirSlashS`).
