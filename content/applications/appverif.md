## AppVerif.exe

Application Verifier, command-line version 6.3.9651 (no GUI on the phone). It sets up the user-mode verifier checks (`Heaps`, `Handles`, `Locks`…) of an executable before it runs.  
`AppVerif.exe` is a console program (242 functions, full symbols: `AppVerif::` namespace, STL `vector` / `basic_string`). It only parses the command line and turns it into calls to [vrfcore.dll](../libraries/vrfcore.md), the Application Verifier core library, which stores the settings (under the `Image File Execution Options` key of the target) and knows the logging directory. The checks themselves are done by the verifier provider DLLs (`vfbasics.dll` ?, `vfgcleak.dll`…) loaded into the target process; none of them is documented here.  
On the phone it's run by [WpToolsWrapper.exe](./wptoolswrapper.md) for the PC tool "Windows Phone Application Verifier" (through [WpToolsSvc.exe](./wptoolssvc.md#startappverifier)) and by the memory profiler.

Location on the phone: `C:\Windows\System32\AppVerif.exe` (path used by [WpToolsWrapper.exe](./wptoolswrapper.md)).  

### Imports

| DLL | Functions |
|-----|-----------|
| [vrfcore.dll](../libraries/vrfcore.md) | `VerifierQueryRegisteredLayers`, `VerifierEnableLayer`, `VerifierDisableLayer`, `VerifierDisableVerifier`, `VerifierIsLayerEnabled`, `VerifierOpenLayerProperties`, `VerifierCreateLayerProperties`, `VerifierCloseLayerProperties`, `VerifierQueryLayerProperty`, `VerifierQueryLayerProperties`, `VerifierSetLayerProperty`, `VerifierSetLayerBreak`, `VerifierQueryLayerBreaks`, `VerifierGetLoggingDirectory` |
| ntdll.dll | `NtCreateFile`, `NtClose`, `NtQueryValueKey`, `RtlDoesFileExists_U`, `RtlDosPathNameToNtPathName_U`, `RtlInitUnicodeString`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlInitializeCriticalSection`, `RtlEnterCriticalSection`, `RtlLeaveCriticalSection`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegEnumKeyExW`, `RegCloseKey` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `SetFilePointer`, `LockFile`, `UnlockFile`, `WriteFile`, `DeleteFileW`, `FindFirstFileW`, `FindNextFileW`, `FindClose`, `CompareFileTime` |
| api-ms-win-core-file-l2-1-1.dll | `CopyFileExW` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `GetModuleHandleW`, `GetModuleHandleA`, `GetModuleFileNameW`, `LoadStringW` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetSystemDirectoryW` |
| api-ms-win-security-base-l1-2-0.dll | `AllocateAndInitializeSid`, `CheckTokenMembership`, `FreeSid` |
| api-ms-win-core-heap-l1-2-0.dll | `HeapSetInformation` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalAlloc`, `LocalFree`, `GlobalFree` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess`, `GetStartupInfoW` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |
| msvcrt.dll | `printf`, `fputws`, `_iob`, `_vsnwprintf`, `_wcsicmp`, `_wcsnicmp`, `wcsstr`, `wcsrchr`, `wcschr`, `wcslen`, `wcstol`, `wcstoul`, `_wcstoui64`, `strlen`, `malloc`, `free`, `memset`, `memcpy`, `memcpy_s`, `memmove_s`, `exit`, C++ exception and CRT startup functions |

The `api-ms-win-core-processthreads`, `errorhandling` (exception filters), `synch`, `rtlsupport` functions and most of msvcrt.dll are the Visual C++ CRT startup, C++ EH and `/GS` code. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| Provider DLLs listed in `VerifierProviders` (e.g. `vfgcleak.dll`) | `LoadLibraryExW("<System32>\<name>", NULL, 0)` in `LoadInstalledProviderDlls` (0x406F6C), at every start except `-installprovider` and `/setupstandardproviders` | Verifier providers: loading them registers their layers (tests) with `vrfcore.dll`. No `GetProcAddress` on them |
| `<file>` given to `-installprovider` | `CopyFileExW` to `<System32>\<file name>` | New provider DLL, then added to `VerifierProviders` |
| ntdll.dll | `GetModuleHandleW` + `GetProcAddress` (`RtlCommitDebugInfo`, `RtlSetProcessDebugInformation`, `RtlDeCommitDebugInfo`) in `ParseSlashVerifyOption` (0x40D424) | Pointers saved in globals, never called |
| `<logging directory>\<image>.*.dat` | `VerifierGetLoggingDirectory`, `FindFirstFileW` / `FindNextFileW`, then `DeleteFileW` (`-delete logs`) or `CreateFileW(GENERIC_WRITE, FILE_SHARE_READ\|FILE_SHARE_WRITE, OPEN_EXISTING)` + `WriteFile` (`-stamp`) | Verifier log files of the target (written by the providers in the target process) |
| Protected process log directory | `NtCreateFile` (`-sppath`) | Created if it doesn't exist (see [-sppath](#-sppath-and--cppath)) |

### Parameters

The command line is split by `AvrfCommandLineToArgvW` (0x40DCF0) from `lpCmdLine` (program name excluded). The first argument selects the command; keywords are case-insensitive and can be abbreviated (`-enable`, `/enable`, `-enab`, `-e`…). Everything except `-?`, `-query`, `-delete logs` and `-stamp` requires membership of `BUILTIN\Administrators` (`CheckTokenMembership`, S-1-5-32-544, result in `g_UserIsAdmin`), otherwise `0x700A` "Access is denied. This application requires administrator privileges."

| Command line | Usage | Exit code | Started by |
|---|---|---|---|
| `AppVerif.exe` / `-?` / `/?` | Loads the providers and the layers (`CommonStartupActions`, 0x406630) and prints the usage (`PrintHelp`, 0x405240): string resources 0x8000–0x800D, the registered layers, and the examples 0x8301–0x831A | 1 | |
| `-installprovider PROVIDERBINARY` | `InstallProvider` (0x40721C): copies the file to `GetSystemDirectoryW()\<file name>` (`CopyFileExW`), then `AviRegisterProvider` (0x407300) appends the file name (space separated, if not already there: `wcsstr`) to the `VerifierProviders` string of the global settings | 0 (0x9020 if not exactly one argument) | [WpToolsWrapper.exe](./wptoolswrapper.md) (`-installprovider vfgcleak.dll`) |
| `/setupstandardproviders` | Does nothing (kept for compatibility ?) | 0 | |
| `/uninstall` | Same as `-disable * -for *` | 0 | |
| `-verify TARGET [-faults [PROBABILITY [TIMEOUT [DLL ...]]]]` (also `/verify`, `/faults`) | `ParseSlashVerifyOption` (0x40D424) → `EnableSlashVerify` (0x40D1F4): see [-verify](#-verify) | 0 | |
| `-sppath [PATH]` (also `/sppath`) | Without argument: prints the current `ProtectedProcessLogPath`. With a path (≤ 260 characters): `RegisterProtectedProcessLogPath` (0x405878). `ParseProtectedPathOption` (0x40D960) | 0 | |
| `-cppath` (also `/cppath`) | Deletes `ProtectedProcessLogPath` of the global settings (no argument allowed) | 0 | |
| `-logtofile enable\|disable` (also `/logtofile`) | `ParseLogToFileOption` (0x40DABC): `LogToFile` (REG_DWORD 1 / 0) in the global settings | 0 | |
| `-enable TEST ... -for TARGET ... [-with [TEST.]PROPERTY=VALUE ...]` | `ParseCommandLine` (0x40A41C) → `EnableLayer` (0x406954) for each target and layer: see [Layer commands](#layer-commands) | 0 | [WpToolsWrapper.exe](./wptoolswrapper.md) (`-enable GcLeak -for <exe> -with Core.MinimumMemoryOverhead=true GcLeak.WaitOnExitTimeout=60`), PC tool (`-enable {0} -for {1}`) |
| `-disable TEST ... -for TARGET ...` | `DisableLayer` (0x406C04); with `*` also `DisableVerifier` (0x406D2C) | 0 | [WpToolsWrapper.exe](./wptoolswrapper.md), PC tool (`-disable * -for {0}`) |
| `-query TEST ... -for TARGET ...` | `QueryLayer` (0x406C7C): prints `Test [x] enabled.` / `not enabled.` and the properties with their values | 0 | PC tool (`-query * -for *`) |
| `-configure STOP ... -for TARGET ... -with PROPERTY=VALUE ...` | `ConfigureStops` (0x406D88): STOP = stop codes (decimal or hex); properties `ErrorReport`, `Severity`, `Flavor` only (numbers); `VerifierSetLayerBreak` on the layer that issues the stop. Images only, the layer must be enabled | 0 | |
| `-delete logs -for TARGET ...` | `DeleteLogs` (0x407514): `ReadLogSessions` + `DeleteFileW` of every log file of the image | 0 (0x9025 on failure) | |
| `-delete settings -for TARGET ...` | `DeleteSettings` (0x407408): `DisableLayer` of every registered layer, then `DisableVerifier` | 0 | |
| `-stamp log -for TARGET -with Stamp=LOG_STAMP [Log=RELATIVE_TO_LAST_INDEX]` | `AddStamp` (0x4075C0): appends a [stamp record](#stamp-record) to the log file selected by `Log` (0 = most recent, sorted by `CompareFileTime`) | 0 | |
| `-export log -for TARGET -with To=XML_FILE ...`, `-logtoxml LOGFILE XMLFILE` | In the usage text, but not implemented in this build: `-export` is recognised (`ExportVariants`) and then rejected | 0x901D | |
| Old syntax: `/s`, `/r`, `/q`, `/a`, `/n`, `/d`, `+LAYER`, `-LAYER`, `IMAGE ...` | `ParseObsoletelCommandline` (0x40D564), used when no new keyword is found: `/s` = `-query * -for *`, `/r` = `-disable * -for *`, `/q` quiet, `/a` enable all normal layers, `/n` disable all layers, `/d` enable the default layers, `+X` / `-X` enable / disable layer X (old names mapped by `GetNewLayerName` (0x40D528) with the table `AVLayerNames`: `PageHeap` / `Heap` → `Heaps`, `TlsChecks` → `Tls`, `VirtualMemory` → `Memory`, `FirstChanceAccessViolations` → `Exceptions`, `HangVerifier` → `Hangs`, `SecurityChecks` → `Security`, `EncryptionChecks` → `Encryption`; `+Heap` also sets `Heaps.full=false`) | 0 | |

Exit codes: an error is reported by `AvReportError` (0x4060C0) on stderr with the prefix `AVRF: Error: `, and **the process exits at once**, with the string resource ID as exit code when the message is a resource (e.g. 0x700A, 0x9015, 0x901A, 0x901D), else with 1. Otherwise `wWinMain` (0x40598C) returns 0 on success, 1 or 2 on failure. Normal output goes to stdout (level 2), warnings (`AVRF: Warning: `) to stderr; debug messages (levels 3–4) are disabled (`AVDisplayDebug` = 0).

### Layer commands

`ParseCommandLine` (0x40A41C) handles, in this order, `-for`, `-configure`, `-delete`, `-stamp` and finally `-enable` / `-disable` / `-query`:

- **Targets** (`ParseTargetList`, 0x409E10): image names with an extension (path removed by `FindImageNameWithoutPath`; else 0x901A), or numbers (PIDs: refused later with 0x9000 "Functionality not implemented [Enable layer for PID]"). `*` or `all` = every image already verified: `GetVerifiedImages` (0x40B9B0) enumerates the subkeys of `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\` (except `Your Image File Name Here without a path` and `{default}`) whose `GlobalFlag` (REG_DWORD, or REG_SZ in hex) has bit 0x100 (`FLG_APPLICATION_VERIFIER`). `all` is allowed only for `-disable` and `-query` (0x900E).
- **Layers**: the names given, or with `*` / `all` the "normal" layers (registered layers except `Core`, `Stacks`, `LowRes`) for `-enable`, all registered layers except `Core` for `-disable` / `-query`. `-enable` always enables the `Core` layer first. A layer not registered by a loaded provider gives 0x9005.
- **Properties** (`-with`, `ParsePropertyDescriptor`, 0x40A0F4): `[LAYER.]PROPERTY=VALUE` or `:VALUE`. An unqualified property goes to `Core` if `Core` has it, else to the single other layer (0x900D when there are several). The value is converted to the property type declared by the layer (`ValidatePropertyType`, 0x406888): DWORD, QWORD, boolean (`true` / `false`), string, multi-string (space separated list converted by `SZToMultiSz`).
- `EnableLayer`: `VerifierEnableLayer(image, layer)`, then `VerifierCreateLayerProperties` + `VerifierSetLayerProperty` for each property. `-disable`: `VerifierDisableLayer(image, layer)`. `-disable *` also calls `VerifierDisableVerifier(image)`, which wipes the verifier settings of the image.

### -verify

`AppVerif.exe -verify TARGET [-faults [PROBABILITY [TIMEOUT [DLL ...]]]]`:

1. TARGET entirely numeric → treated as a PID: "Run time settings hasn't been implemented yet." Otherwise an image name with extension (0x901A if not).
2. Enables the layers `Heaps`, `Handles`, `Locks`, `Exceptions`, `Memory`, `TLS`, `Threadpool` (`AVVistaQGTests`), plus `Leak` and `SRWLock` when `PEB.OSBuildNumber` ≥ 6400 (0x1900; always the case on WP8.1), with `VerifierEnableLayer`.
3. With `-faults`: enables `LowRes` (fault injection) and sets its properties:

| Property | Type | Value | Default |
|---|---|---|---|
| `Include` | REG_MULTI_SZ (7) | DLL list | `*` |
| `TimeOut` | REG_DWORD (4) | TIMEOUT, ms after the start of the process | 500 |
| `HEAP_ALLOC` | REG_DWORD (4) | PROBABILITY, in 1/1 000 000 (decimal) | 50000 (5 %) |
| `OLE_ALLOC` | REG_DWORD (4) | PROBABILITY | 50000 |

### Layer property parameter

`VerifierQueryLayerProperty` / `VerifierSetLayerProperty` receive a pointer to a 16-byte structure built on the stack:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 1, 4, 7… | Registry value type: REG_SZ, REG_DWORD, REG_MULTI_SZ; 0x101 (REG_SZ + 0x100) with no value deletes the property (`-cppath`) |
| 0x04 | 4 | `L"VerifierProviders"`, `L"LogToFile"`… | Property name |
| 0x08 | 4 | pointer | Value buffer |
| 0x0C | 4 | size | Size of the value in bytes (buffer size for a query: 0x800 for `VerifierProviders`, 0x208 for `ProtectedProcessLogPath`) |

The global settings are the pseudo-layer `{ApplicationVerifierGlobalSettings}` (`VerifierOpenLayerProperties` / `VerifierCreateLayerProperties("{ApplicationVerifierGlobalSettings}", 1, &handle)`); their properties used here:

| Property | Type | Written by | Use |
|---|---|---|---|
| `VerifierProviders` | REG_SZ | `-installprovider` | Space separated list of provider DLL names in System32, read at every start |
| `ProtectedProcessLogPath` | REG_SZ | `-sppath`, deleted by `-cppath` | Log directory for protected processes |
| `LogToFile` | REG_DWORD | `-logtofile` | 1 = providers log to a file, 0 = no log file |

[vrfcore.dll](../libraries/vrfcore.md#registry) stores them as values of the key `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\{ApplicationVerifierGlobalSettings}` (the pseudo-image name is opened like an image key). The settings of each layer go to `IFEO\<image>\<Layer>-<GUID>`, see [vrfcore.dll](../libraries/vrfcore.md#registry).

### -sppath and -cppath

`RegisterProtectedProcessLogPath(path, length)` (0x405878): if `RtlDoesFileExists_U(path)` is false, converts it with `RtlDosPathNameToNtPathName_U` and creates the directory with `NtCreateFile(DesiredAccess = 0x100181 (SYNCHRONIZE | FILE_READ/WRITE_ATTRIBUTES | FILE_LIST_DIRECTORY), OBJ_CASE_INSENSITIVE, FileAttributes = FILE_ATTRIBUTE_DIRECTORY, ShareAccess = 3, Disposition = FILE_CREATE, Options = 0x204021 (FILE_DIRECTORY_FILE | FILE_SYNCHRONOUS_IO_NONALERT | FILE_OPEN_FOR_BACKUP_INTENT | FILE_OPEN_REPARSE_POINT))`. Then stores the path (REG_SZ, `(length + 1) * 2` bytes) as `ProtectedProcessLogPath`.

### Stamp record

`AVLogInstance::Stamp` (0x40CAE0) opens the log file (`CreateFileW(GENERIC_WRITE, FILE_SHARE_READ|FILE_SHARE_WRITE, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL)`, retried up to 10 times on `ERROR_SHARING_VIOLATION`), moves to the end, locks the range and writes one record:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | (2 × length + 0x11) & ~7 | Record size, header included, 8-byte aligned (≤ 0x2000) |
| 0x04 | 4 | 4 | Record type: stamp ? |
| 0x08 | n | `LOG_STAMP` | UTF-16 string (≤ 0xFFC characters), NUL terminated, zero padding |

Log files are found by `AVLOGs::ReadLogSessions` (0x40C588) as `<VerifierGetLoggingDirectory()>\<image>.*.dat` (one file per run of the image).
