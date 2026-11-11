## bootshsvc.dll

The "Bootsh" service: a small boot-time script interpreter hosted by svchost, which runs the commands of `$:\windows\system32\boot\startup.bsc` once when the service starts.  
`bootshsvc.dll` is a small DLL (58 functions, about a third of them CRT, `/GS` and SHA-256 code). It's the service version of a former `bootsh.exe` (the debug messages still say `exiting bootsh.exe`). At the first start of the service, `ServiceMain` raises the priority of the process, reads the script (UTF-16LE) and runs its commands: copy, rename and delete files, start processes, set the host name, include other scripts. The `sethostname` command writes the computer name and the TCP/IP host name to the registry; a `*` in the name is replaced by a 12-digit hex suffix derived from the SMBIOS system UUID (HMAC-SHA256), or by random characters. All the output goes to the kernel debugger (`DbgPrintEx`).  
The service is loaded by svchost.exe (exports `ServiceMain` and `SvchostPushServiceGlobals`); its service registration (svchost group, start type) isn't in the binary. No other page of this site references it.

Location on the phone: `C:\Windows\System32\bootshsvc.dll` ?  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `NtCreateKey`, `NtSetValueKey`, `NtFlushKey`, `NtClose`, `RtlInitUnicodeString`, `NtRaiseHardError`, `NtTerminateProcess`, `RtlGetLastNtStatus`, `NtQueryInformationProcess`, `RtlRandomEx`, `DbgPrint`, `DbgPrintEx` |
| api-ms-win-service-core-l1-1-1.dll | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-core-threadpool-legacy-l1-1-0.dll | `UnregisterWaitEx` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `WaitForSingleObject` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `ReadFile`, `WriteFile`, `DeleteFileW`, `GetFileAttributesW`, `GetDriveTypeW`, `SetFileInformationByHandle` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateProcessW`, `GetCurrentProcess`, `SetPriorityClass`, `GetCurrentThread`, `SetThreadPriority`, `TerminateProcess` |
| api-ms-win-core-processenvironment-l1-2-0.dll | `SearchPathW`, `SetEnvironmentVariableW` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetSystemWindowsDirectoryW`, `GetSystemFirmwareTable`, `GetComputerNameExW`, `GetLocalTime` |
| api-ms-win-core-apiquery-l1-1-0.dll | `ApiSetQueryApiSetPresence` |
| api-ms-win-core-heap-l1-2-0.dll | `HeapSetInformation`, `GetProcessHeap`, `HeapFree` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `GlobalAlloc`, `GlobalFree` |
| api-ms-win-core-string-obsolete-l1-1-0.dll | `lstrcmpiW`, `lstrlenW` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| ntdll.dll (CRT) | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-crt-l1-1-0.dll, api-ms-win-core-crt-l2-1-0.dll | `wcscpy_s`, `memcpy_s`, `memcpy`, `memmove`, `memset`, `wcslen`, `_vsnwprintf_s`, `swprintf_s`, `__C_specific_handler`, `_initterm`, `_initterm_e` |

The crt, util, rtlsupport and errorhandling imports, `GetProcessHeap`/`HeapFree` and `TerminateProcess` are the Visual C++ DLL CRT startup and `/GS` security cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `<boot drive>:\windows\system32\boot\startup.bsc` | `CreateFileW` / `ReadFile` ([BootshMain](#bootshmain-0x100028c8)) | Boot script. If it can't be opened, the service raises a fatal hard error |
| Files named by `include` | `CreateFileW` / `ReadFile` | Included scripts |
| Files named by `copy`, `ren`, `del` | `CreateFileW`, `ReadFile`/`WriteFile`, `SetFileInformationByHandle`, `DeleteFileW` | Script commands, see [Script language](#script-language) |
| Executables named by `start` and by bare command lines | `CreateProcessW` | Script commands |
| `ext-ms-win-mobilecore-deviceinfo-l1-1-0` (API set) | `ApiSetQueryApiSetPresence` only | Its presence selects the SMBIOS-based host name suffix (no function of it is called) |
| SMBIOS table | `GetSystemFirmwareTable('RSMB')` | System UUID for the host name suffix |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `ServiceMain` | 0x100018EC | `DWORD argc`, `LPWSTR *argv` |
| 2 | `SvchostPushServiceGlobals` | 0x100017D0 | `SVCHOST_GLOBAL_DATA *` (stored in `g_svcsGlobalData`) |

Global service state:

| Address | Size | Comment |
|---------|------|---------|
| 0x100154A0 | 0x1C | `SERVICE_STATUS g_status` (`dwServiceType` = `SERVICE_WIN32_SHARE_PROCESS` 0x20) |
| `g_hStatus` | 4 | `SERVICE_STATUS_HANDLE` |
| `g_hEventTerminated` | 4 | Event set by the stop control |
| `g_hRegisteredWait` | 4 | Wait registered by svchost on that event |
| `g_svcsGlobalData` | 4 | svchost global data |
| `g_FirstTime` (0x10005008) | 4 | 1 at load: the script runs only at the first `ServiceMain` of the process |

### Startup

`_DllMainCRTStartup` (0x10002D08): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then `__DllMainCRTStartup` (`_CRT_INIT` only). There's no `DllMain` code: everything is done by `ServiceMain`.

### ServiceMain (0x100018EC)

1. Clears `g_status`, sets `SERVICE_WIN32_SHARE_PROCESS` and calls `RegisterServiceCtrlHandlerExW(argv[0], ServiceHandler, NULL)`. On failure, prints `RegisterServiceCtrlHandler failed!  %d` and returns.
2. Reports `SERVICE_START_PENDING` (wait hint 3000 ms) through `UpdateServiceStatus` (0x100017E4: accepts `SERVICE_ACCEPT_STOP` in every state but start pending, increments the checkpoint except in the running and stopped states).
3. Creates the unnamed auto-reset event `g_hEventTerminated`.
4. If `g_FirstTime` is set, runs the script synchronously ([BootshMain](#bootshmain-0x100028c8)), then clears `g_FirstTime`. Its return value is ignored.
5. Calls the function at offset 0x60 of the svchost global data (`RegisterStopCallback` ?) with `&g_hRegisteredWait`, `L"Bootsh"` (the service name), the event and `StopService` as callback. Success → `SERVICE_RUNNING`. Failure → unregisters the wait, closes the event and reports `SERVICE_STOPPED`.

`ServiceHandler` (0x100018B8) only handles `SERVICE_CONTROL_STOP`: reports `SERVICE_STOP_PENDING` (exit code 1066 `ERROR_SERVICE_SPECIFIC_ERROR`, wait hint 3000 ms) and sets the event. `StopService` (0x10001838), called by svchost when the event is signalled, unregisters the wait (`UnregisterWaitEx(…, INVALID_HANDLE_VALUE)`), closes the event, clears `g_svcsGlobalData` and reports `SERVICE_STOPPED`.

So the service stays "running" after the script, doing nothing until it's stopped.

### BootshMain (0x100028C8)

1. `HeapSetInformation(NULL, HeapEnableTerminationOnCorruption)`, `SetPriorityClass(GetCurrentProcess(), HIGH_PRIORITY_CLASS)` and `SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_HIGHEST)`; returns 0x400 if one of the last two fails. (The priority class of the whole svchost process is changed and never restored.)
2. Prints `bootsh`, calls [SetMachineName](#setmachinename-0x10002840) and prints the Windows directory (`GetSystemWindowsDirectoryW`). Its first letter, upper-cased, becomes the boot drive letter (`bootdriveletter`, 0x10015480) that replaces `$` in file names.
3. Opens `$:\windows\system32\boot\startup.bsc` with `InitInputState` (0x10001F3C). If it fails: `NtRaiseHardError(STATUS_SYSTEM_PROCESS_TERMINATED 0xC000021A, 3 parameters, mask 5, {"Failed to open boot script file.", status, path}, OptionShutdownSystem)` then `NtTerminateProcess(NtCurrentProcess(), …)`.
4. Loops on `GetToken` (0x1000211C) and runs each command (see [Script language](#script-language)) until the end of the script or `exit`, then prints `exiting bootsh.exe` and returns 0. A command without its argument at the end of a line / file prints `failure parsing script` and stops the script (returns -1).

### Script language

The script is a UTF-16LE text file that must start with the BOM `FF FE`. Tokens are separated by characters ≤ 0x20; a line ends with LF (CR is ignored). A token or a line is at most 256 characters (`element`, 0x10015280). Commands are case-insensitive.

| Command | `GetToken` code | Effect |
|---------|-----------------|--------|
| `# …` | 8 | Comment (only at the start of a token): the line is printed to the debugger and ignored |
| empty line | 9 | Ignored |
| end of file | 10 | End of the current included file (back to the including file), or end of the script |
| `exit` | 1 | Same as end of file. `exit -a` stops the whole script, even from an included file |
| `copy <src> [<dst>]` | 2 | Copies a file (`ShCopyFile`, 0x100022C4). `<dst>` defaults to `.`. The source is opened like a script (`$` / `%CD%` substitution); if `<dst>` is an existing directory, the file name of the source (from `SearchPathW`) is appended. The destination is created with `CREATE_ALWAYS` and the data copied by blocks of 64 KiB (`filebuf`, 0x10005240) |
| `ren <src> [<dst>]` | 3 | Moves a file (`ShRenameFile`, 0x10002438). `<src>` must exist and not be a directory. Only the case where `<dst>` is an existing directory works: the source is opened with `DELETE \| GENERIC_WRITE` and renamed to `<dst>\<file name>` with `SetFileInformationByHandle(FileRenameInfo)`, `ReplaceIfExists` = TRUE. Otherwise `CreateFileW` is called with an empty path and the command fails |
| `del <file>` | 4 | `DeleteFileW` if the file exists and isn't a directory |
| `start [-s \| -c] <command line>` | 5 | Starts the rest of the line with `CreateProcessW` without waiting. Default flag `DETACHED_PROCESS`; `-c` → `CREATE_NEW_CONSOLE`; `-s` → the command isn't started at all (`ShStartNewProcess` returns FALSE: printed as ` error`) |
| `sethostname <name>` | 6 | [SetHostname](#sethostname-0x100025f0), then [SetMachineName](#setmachinename-0x10002840) |
| `include <file>` | 7 | Opens `<file>` (`InitInputState`) and pushes it on the stack of input files; `not found.  Continuing...` if it can't be opened |
| anything else | 0 | The whole line is a command line: `CreateProcessW` (`DETACHED_PROCESS`) and waits for the end of the process |

Every command prints its name, arguments and ` done` / ` error` to the debugger.

File names given to `copy` (source) and `include` (and the script itself) are opened by `CreateInputFile` (0x10001E24), with `GENERIC_READ`, no sharing, `OPEN_EXISTING`, after two substitutions:

- `$` as first character → boot drive letter.
- `%CD%…` → letter of the CD-ROM drive selected last (first one by default), `%CDn%…` (n = 1 to 9) → letter of the n-th CD-ROM drive, followed by `:`. The drives `A:\` to `Z:\` are scanned once with `GetDriveTypeW` (`DRIVE_CDROM`) and their letters stored in `CDdriveletters` (0x10015260, count `CDsFound`, current `CDdefault`). Nothing is substituted when no CD-ROM drive was found.

The other file names (`del`, `ren`, destination of `copy`) are used as is.

Input file state (`GlobalAlloc(GPTR, 0x2010)`, current one in `pCurrent`, 0x10015244):

| Offset | Size | Comment |
|--------|------|---------|
| 0x0000 | 4 | Including (previous) input state, NULL for the main script |
| 0x0004 | 4 | File handle, `INVALID_HANDLE_VALUE` once the file is fully read (closed after a `ReadFile` shorter than 0x2000 bytes) |
| 0x0008 | 0x2000 | Read buffer |
| 0x2008 | 4 | Current position in the buffer |
| 0x200C | 4 | Remaining count (set to the number of bytes read but decremented once per character) |

The states of the included files aren't freed when they end.

### SetHostname (0x100025F0)

The name is the token after `sethostname`.

1. Looks for a `*` in the name. The part before it is the prefix, cut to 15 characters.
2. If there's a `*` (and the prefix is shorter than 15 characters), a suffix replaces it, in this order of preference:
   1. If `ApiSetQueryApiSetPresence("ext-ms-win-mobilecore-deviceinfo-l1-1-0")` says the API set exists: `GetSMBIOSUniqueId` (0x10001B84) — 12 hex digits computed from the SMBIOS UUID (see below).
   2. Otherwise, or if it fails: `GenerateRandomChars` (0x10001A04) — `15 - prefix length - 1` characters of `0123456789ABCDEFGHIJKLMNOPQRSTUV` (5 random bits each). The seed is the process cookie (`NtQueryInformationProcess(NtCurrentProcess(), ProcessCookie)`) passed through `RtlRandomEx`.
   3. If that fails: the local time `"%02x%02x%02x%02x%02x%03x"` (month, day, hour, minute, second, milliseconds).
   The name is the prefix followed by the suffix, cut to 15 characters (a NetBIOS name).
3. Writes the name as `REG_SZ` with `NtCreateKey` (`KEY_READ | KEY_WRITE` 0x2001F, `OBJ_CASE_INSENSITIVE`), `NtSetValueKey` and `NtFlushKey` to the four values of the [Registry](#registry) table. Stops at the first error and returns FALSE.

`GetSMBIOSUniqueId`:

1. Reads the raw SMBIOS table (`GetSystemFirmwareTable('RSMB', 0, …)`) into a `GlobalAlloc` buffer.
2. Walks the structures (skipping the formatted part with the length byte, then the string set up to the double NUL) to the first type 1 structure (System Information). None → `ERROR_NOT_FOUND` (0x490).
3. Computes HMAC-SHA256 of the 16-byte UUID (offset 8 of the type 1 structure, the same UUID that [IpOverUsb.dll](./ipoverusb.md#hardware-guid) sends in its handshake) with the key `"MAC_KEY"` (8 bytes with the NUL).
4. Overwrites the first two bytes of the digest with `00 11` and formats the first 6 bytes with `%02x`: a string `0011xxxxxxxx` (looks like a MAC address in the `00:11:…` range), in a 13-character buffer.

### SetMachineName (0x10002840)

`GetComputerNameExW(ComputerNameNetBIOS)`, `SetEnvironmentVariableW("COMPUTERNAME", name)` for the svchost process and prints `Machine name is "<name>"`. Returns the Win32 error, 0 on success.

### Registry

Written by `sethostname`:

| Key | Value | Type |
|-----|-------|------|
| `HKLM\System\CurrentControlSet\Control\ComputerName\ComputerName` | `ComputerName` | `REG_SZ` |
| `HKLM\System\CurrentControlSet\Control\ComputerName\ActiveComputerName` | `ComputerName` | `REG_SZ` |
| `HKLM\System\CurrentControlSet\Services\Tcpip\Parameters` | `Hostname` | `REG_SZ` |
| `HKLM\System\CurrentControlSet\Services\Tcpip\Parameters` | `NV Hostname` | `REG_SZ` |

### Debug output

There's no ETW provider. Every message goes through `OutA` / `OutW` (0x10001DB8 / 0x10001DE4), which call `DbgPrintEx(77, DPFLTR_ERROR_LEVEL, …)` twice with the same text (so every line appears twice in the debugger).
