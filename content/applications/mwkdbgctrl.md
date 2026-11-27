## mwkdbgctrl.exe

Command-line tool of Windows Phone 8.1 that checks and changes the state of the kernel debugger (enable / disable, auto-enable, enable block, user-mode exception handling, size of the `DbgPrint` buffer), and takes a kernel triage dump of a process.  
`mwkdbgctrl.exe` is a small console program (36 864 bytes for ARM, 42 functions, PDB `mwkdbgctrl.pdb`, no other symbols): every option is a single call to `ntdll!NtSystemDebugControl` (or `NtQuerySystemInformation` for the state of the debugger), and its result is printed with `printf`. Only the triage dump (`-td`) uses dbgeng (`dbgeng.dll`, loaded at run time) to get the thread handles of the target process.  
It's the phone counterpart of the desktop `kdbgctrl.exe` of the Debugging Tools for Windows (same options and messages).

Location on the phone: ?  
Started by: ? (no caller found among the analysed binaries; it's meant to be run by hand, e.g. from [cmd.exe](./cmd.md) over [telnetd.exe](./telnetd.md)).

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `NtSystemDebugControl`, `NtQuerySystemInformation`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `printf`, `strcmp`, `strtoul`, `getenv`, `malloc`, `calloc`, `free`, `_vsnwprintf`, `wcslen`, `iswprint`, `iswspace`, `memcpy`, `memset`, `__getmainargs`, `_initterm`, `_amsg_exit`, `_exit`, `_cexit`, `exit`, `__set_app_type`, `__setusermatherr`, `_fmode`, `_commode`, `_XcptFilter`, `__C_specific_handler`, `?terminate@@YAXXZ` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileA`, `WriteFile`, `DeleteFileA` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleHandleA` |
| api-ms-win-core-memory-l1-1-2.dll | `VirtualAlloc`, `VirtualFree` |
| api-ms-win-core-processthreads-l1-1-2.dll | `OpenProcessToken`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-security-base-l1-2-0.dll | `AdjustTokenPrivileges` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetVersionExA` |
| api-ms-win-core-localization-l1-2-1.dll | `FormatMessageW` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |

`Rtl*Context` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind`, `TerminateProcess`, `Sleep`, `SetUnhandledExceptionFilter` / `UnhandledExceptionFilter`, `GetModuleHandleA` and the msvcrt startup functions (`__getmainargs` … `?terminate@@YAXXZ`) are the standard Visual C++ CRT startup and `/GS` boilerplate. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `dbgeng.dll` | `LoadLibraryExW(L"dbgeng.dll", 0, 0)`, `GetProcAddress("DebugCreate")` (sub_401EB8, 0x401EB8) | Debugger engine, only for `-td`: non-invasive attach to the target process to collect its thread handles, see [triage dump](#triage-dump--td) |
| `kernel32.dll` | `LoadLibraryExW`, `GetProcAddress("HeapSetInformation")` (sub_4022E4, 0x4022E4) | `HeapSetInformation(NULL, HeapEnableTerminationOnCorruption, NULL, 0)` at startup, then `FreeLibrary` |
| `ntdll.dll`, `netmsg.dll` | `GetModuleHandleW`, else `LoadLibraryExW` (sub_4027CC, 0x4027CC) | Message tables for the text of the error codes printed: `ntdll.dll` for an NTSTATUS, `netmsg.dll` for a Win32 error 2100–2999 (network errors), the system otherwise; text from `FormatMessageW` (`FORMAT_MESSAGE_FROM_HMODULE` / `FROM_SYSTEM`, `IGNORE_INSERTS`). A `RtlFindMessage`-like pointer (0x405574, called with `RT_MESSAGETABLE` 11) is tested first but is never set in the binary |
| `<file>` of `-td` | `CreateFileA(<file>, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL)`, `WriteFile`; `DeleteFileA` on failure (sub_40211C, 0x40211C) | Output triage dump |

### Parameters

`main` (sub_4022E4, 0x4022E4; `argv`, ANSI) first enables `SeDebugPrivilege` (sub_402944, see [debug privilege](#debug-privilege)); on failure it prints `Unable to enable debug privilege, …` and exits with 1. Then the options are processed **one after the other, from left to right** (`mwkdbgctrl -d -cdb -sdb 0x10000` is valid). Options are case-sensitive (`strcmp`). No option, `-?`, an unknown option or a missing argument stops the processing, prints the usage (sub_401BE8, 0x401BE8) and exits with 1. Otherwise the exit code is 0, even when an option failed (except `-cx`).

Errors are printed as `<message>, <code>\n    <text>`, the code being formatted by sub_402768 (0x402768) as `NTSTATUS 0x%08X`, `Win32 error 0n%d` or `HRESULT 0x%08X`.

| Command line | Usage | Exit code |
|---|---|---|
| `-c` | `NtQuerySystemInformation(SystemKernelDebuggerInformation` 35`, buf, 2)`: prints `Kernel debugger is enabled` / `disabled` (`KernelDebuggerEnabled`, byte 0) | |
| `-cx` | Same query, no output: exits at once | 0x10001 enabled, 0x10002 disabled, the NTSTATUS if the query failed |
| `-ca` | `NtSystemDebugControl(SysDbgGetAutoKdEnable` 23`)` (sub_401D6C, 0x401D6C): prints `Kernel debugger auto-enable: true` / `false` | |
| `-cb` | `SysDbgGetKdBlockEnable` 30 (sub_401D6C): `Kernel debugger enable block: true` / `false` | |
| `-cu` | `SysDbgGetKdUmExceptionEnable` 27 (sub_401D6C): `Kernel debugger user exception enable: true` / `false` | |
| `-cdb` | `SysDbgGetPrintBufferSize` 25, output ULONG: `Kernel DbgPrint buffer size: 0x<size>` | |
| `-e` | Enables the kernel debugger. If `SystemKernelDebuggerInformation` already says enabled: `Kernel debugger is already enabled`. Else if `SysDbgGetKdBlockEnable` returns TRUE: `Kernel debugger enable is blocked, use -db to disable`. Else `SysDbgEnableKernelDebugger` 21 (sub_401CE0, 0x401CE0): `Kernel debugger enabled`; on `STATUS_DEBUGGER_INACTIVE` (0xC0000354) the hint `Unable to enable KD, Windows may have been booted with kernel debugging off.` | |
| `-d` | `SysDbgDisableKernelDebugger` 22 (sub_401CE0): `Kernel debugger disabled` | |
| `-ea` / `-da` | `SysDbgSetAutoKdEnable` 24 with TRUE / FALSE (sub_401DE4, 0x401DE4): `Kernel debugger auto-enable set to: true` / `false` | |
| `-eb` / `-db` | `SysDbgSetKdBlockEnable` 31 with TRUE / FALSE (sub_401DE4): `Kernel debugger block-enable set to: …` | |
| `-eu` / `-du` | `SysDbgSetKdUmExceptionEnable` 28 with TRUE / FALSE (sub_401DE4): `Kernel debugger user exception enable set to: …` | |
| `-sdb <size>` | `<size>` read by `strtoul(…, 0, 0)` (decimal, `0x` hex or `0` octal, no check). `SysDbgSetPrintBufferSize` 26 with the ULONG: `Kernel DbgPrint buffer size set to: 0x<size>` | |
| `-td <pid> <file>` | `<pid>` by `strtoul(…, 0, 0)`. Writes a kernel triage dump of the process to `<file>` (sub_40211C, 0x40211C), see [below](#triage-dump--td): `Dump created in <file>, <n> bytes` | |

### NtSystemDebugControl calls

All calls pass `NtSystemDebugControl(Command, InputBuffer, InputBufferLength, OutputBuffer, OutputBufferLength, ReturnLength = NULL)`:

| Command | Value | Input | Output | Options |
|---------|-------|-------|--------|---------|
| `SysDbgEnableKernelDebugger` | 21 (0x15) | — | — | `-e` |
| `SysDbgDisableKernelDebugger` | 22 (0x16) | — | — | `-d` |
| `SysDbgGetAutoKdEnable` | 23 (0x17) | — | 1 byte (BOOLEAN) | `-ca` |
| `SysDbgSetAutoKdEnable` | 24 (0x18) | 1 byte (BOOLEAN) | — | `-ea`, `-da` |
| `SysDbgGetPrintBufferSize` | 25 (0x19) | — | 4 bytes (ULONG) | `-cdb` |
| `SysDbgSetPrintBufferSize` | 26 (0x1A) | 4 bytes (ULONG) | — | `-sdb` |
| `SysDbgGetKdUmExceptionEnable` | 27 (0x1B) | — | 1 byte (BOOLEAN) | `-cu` |
| `SysDbgSetKdUmExceptionEnable` | 28 (0x1C) | 1 byte (BOOLEAN) | — | `-eu`, `-du` |
| `SysDbgGetTriageDump` | 29 (0x1D) | 0x24 bytes `SYSDBG_TRIAGE_DUMP` | 0x400000 bytes, ReturnLength = size of the dump | `-td` |
| `SysDbgGetKdBlockEnable` | 30 (0x1E) | — | 1 byte (BOOLEAN) | `-cb`, `-e` |
| `SysDbgSetKdBlockEnable` | 31 (0x1F) | 1 byte (BOOLEAN) | — | `-eb`, `-db` |

(names of the `SYSDBG_COMMAND` enumeration from the public NT headers; the values match the messages of the binary).

### Triage dump (-td)

sub_40211C (0x40211C):

1. sub_401EB8 (0x401EB8) loads `dbgeng.dll` and calls `DebugCreate(IID_IDebugClient {27FE5639-8407-4F47-8364-EE118FB08AC8})`, then `QueryInterface` for `IID_IDebugControl` {5182E668-105E-416E-AD92-24EF800424BA} and `IID_IDebugSystemObjects` {6B86FE2C-2C4F-4F0C-9DA2-174311ACC327}.
2. `IDebugClient::AttachProcess(Server 0, <pid>, DEBUG_ATTACH_NONINVASIVE` 1`)`, `IDebugControl::WaitForEvent(0, INFINITE)`.
3. `IDebugSystemObjects::GetNumberThreads`, then for each thread `GetThreadIdsByIndex(i, 1, &id, NULL)`, `SetCurrentThreadId(id)`, `GetCurrentThreadHandle(&handle)`: the handles go into a `malloc`'ed array.
4. `VirtualAlloc` of a 4 MB (0x400000) output buffer, then `NtSystemDebugControl(SysDbgGetTriageDump` 29`, &dump, 0x24, buffer, 0x400000, &size)` with the structure below.
5. `CreateFileA` / `WriteFile` of `size` bytes to `<file>`. If anything fails after the attach, the file is deleted (`DeleteFileA`).
6. Cleanup (sub_401E68, 0x401E68): `IDebugClient::EndSession(DEBUG_END_ACTIVE_DETACH` 2`)`, `Release`, `FreeLibrary(dbgeng)`, `free` of the handle array.

Each step prints its own error (`Unable to load dbgeng.dll`, `AttachProcess failed`, `WaitForEvent failed`, `Unable to allocate dump buffer`, `Unable to get dump`, `Unable to create <file>`, `Unable to write <file>`…).

### SYSDBG_TRIAGE_DUMP parameter

Input of `SysDbgGetTriageDump`, 0x24 bytes on the stack, zeroed first:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0 | `Flags` |
| 0x04 | 4 | 0x69696969 | `BugCheckCode` written in the dump (not a real bugcheck) |
| 0x08 | 16 | 0 | `BugCheckParam1`–`4` |
| 0x18 | 4 | 0 | `ProcessHandles`: no process handle |
| 0x1C | 4 | number of threads | `ThreadHandles` (`IDebugSystemObjects::GetNumberThreads`) |
| 0x20 | 4 | pointer | `Handles`: array of the thread handles of the target (from dbgeng) |

### Debug privilege

sub_402944 (0x402944), called once at startup:

- Does nothing (success) if the environment variable `DBGENG_NO_DEBUG_PRIVILEGE` is set, if `GetVersionExA` reports a platform other than `VER_PLATFORM_WIN32_NT` (2), or if it already succeeded (flag 0x4055B0).
- Otherwise `OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES` 0x20`)` and `AdjustTokenPrivileges` with a 0x10-byte `TOKEN_PRIVILEGES` from `calloc`: `PrivilegeCount` 1, LUID {20, 0} = `SeDebugPrivilege`, `Attributes` `SE_PRIVILEGE_ENABLED` (2).
- `NtSystemDebugControl` needs `SeDebugPrivilege` (kernel side, not analysed), so the tool must run in an account that holds it ?
