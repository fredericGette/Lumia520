## MSCOREE.DLL

The .NET host of Windows Phone 8.1: it starts the CoreCLR (`CoreClr.dll`) for managed executables and managed Windows Runtime components.  
`MSCOREE.DLL` is a small DLL (57 344 bytes, 153 functions, most of them CRT, `std::wstring` / `std::vector` and WRL code; the public symbols are present). It builds the start-up properties of the runtime (trusted platform assemblies, application paths, native-image paths), loads `CoreClr.dll` from System32, gets its `ICLRRuntimeHost2` (`GetCLRRuntimeHost`), creates one AppDomain and then either executes the managed `.exe` (`_CorExeMain`) or returns the activation factory of a managed WinRT class (`DllGetActivationFactory`). In an application package it also forces a full garbage collection when the memory usage of the application becomes high (`Windows.System.MemoryManager`).  
`_CorExeMain` is the entry point of a managed executable (the process image is itself the assembly that is executed). `DllGetActivationFactory` is the standard WinRT in-process server entry point; which registrations point to `MSCOREE.DLL` (managed WinRT classes ?) isn't known. Some test settings are read from `HKLM\SOFTWARE\Microsoft\TaskHost` (`TaskHost.exe`, the host of the phone applications, wasn't analysed).

Location on the phone: `C:\Windows\System32\MSCOREE.DLL` ?  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `GetModuleHandleExW`, `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-processenvironment-l1-2-0.dll | `GetEnvironmentVariableW`, `SetEnvironmentVariableW`, `ExpandEnvironmentStringsW`, `GetCommandLineW`, `GetCurrentDirectoryW` |
| api-ms-win-shcore-obsolete-l1-1-0.dll | `CommandLineToArgvW` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalFree` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `ReadFile`, `GetFileSize`, `GetFileAttributesW` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegGetValueW`, `RegCloseKey` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetSystemDirectoryW` |
| api-ms-win-appmodel-runtime-l1-1-1.dll | `GetCurrentPackageInfo` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoUninitialize` |
| api-ms-win-core-winrt-l1-1-0.dll | `RoGetActivationFactory` |
| api-ms-win-core-winrt-string-l1-1-0.dll | `WindowsCreateStringReference`, `WindowsGetStringRawBuffer` |
| api-ms-win-core-synch-l1-2-0.dll | `AcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`, `Sleep` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `wcstok_s`, `wcsstr`, `_wcsicmp`, `_wcsnicmp`, `_waccess`, `wcslen`, `strlen`, `memset`, `memcpy_s`, `memmove_s`, `malloc`, `free`, `exit`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, processthreads, `Sleep` and errorhandling imports (except `GetLastError` / `RaiseException`) are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `C:\Windows\System32\CoreClr.dll` | `LoadLibraryExW` + `GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN)`, `GetProcAddress("GetCLRRuntimeHost")` ([StartCoreCLR](#startcoreclr-0x10006d1c)) | The CoreCLR runtime; the only search directory is System32 |
| `<System32>\*.NI.DLL`, `<System32>\WINMETADATA\WINDOWS.NI.WINMD` | Paths passed in `TRUSTED_PLATFORM_ASSEMBLIES` ([list](#trusted-platform-assemblies)) | Native images of the framework assemblies, loaded by CoreClr.dll |
| `<System32>\mscoree.TPALIST` | `CreateFileW` / `ReadFile` (`ReadTPAFile`, 0x10004B64) | Extra trusted assemblies, only when the test value `AllowTestTPAs` is set ([TPA list file](#tpa-list-file)) |
| `<PackageRepositoryRoot>\Packages\<package full name>\NI`, `<drive>:\WPSystem\APPREPOSITORY\<package full name>\NI` | Paths passed in `APP_NI_PATHS` (`GetNIFolderPathForPackage`, 0x10005160) | Native images of the application (internal storage / SD card) |
| Install folder of the package(s) of the process | `GetCurrentPackageInfo`, passed in `APP_PATHS` | Assemblies of the application |
| The managed `.exe` of the process | `GetModuleFileNameW(NULL)` → `ICLRRuntimeHost2::ExecuteAssembly` | Assembly run by `_CorExeMain`; its folder is also put in `APP_PATHS` |
| `mscoreehelper, Version=0.0.0.0` (managed assembly) | `ICLRRuntimeHost2::CreateDelegate` | Test helper `Microsoft.Phone.Test.MSCoreeRunHelper.WaitForDebuggerInManaged`, only when the debugger wait is enabled |
| `Windows.System.MemoryManager` (WinRT class) | `RoGetActivationFactory`, `IMemoryManagerStatics` {5C6C279C-D7CA-4779-9188-4057219CE64C} | Memory usage level of the application ([low memory GC](#low-memory-gc)) |

No process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 2 | `_CorExeMain` | 0x10005B2C | none; doesn't return (`exit` with the exit code of the assembly or the HRESULT) |
| 1 | `DllGetActivationFactory` | 0x10005DD0 | `HSTRING activatableClassId, IActivationFactory **factory`; returns an HRESULT |

Global state:

| Address | Name | Comment |
|---------|------|---------|
| 0x1000A304 | `g_pCoreCLRInstance` | `CoreCLRInstance *` (below), allocated by `StartCoreCLR` |
| 0x1000A308 | `g_coreCLRMustBeStarted` | Set while `DllGetActivationFactory` holds `g_startCoreCLRLock` to start the runtime |
| 0x1000A309 | `g_isCoreCLRStarted` | Set once the AppDomain is created |
| 0x1000A30C | `g_bShouldWaitForDebugger` | `TestDebuggerAttach` / `MSCOREE_DEBUG` |
| 0x1000A310 | `g_startCoreCLRLock` | SRW lock around the start by `DllGetActivationFactory` |
| 0x1000A010 | `g_wsTestTrustedPath` | `TestTrustedPath` (expanded), the `[TESTBIN]` folder |
| 0x1000A02C | `c_saList` | `L"TailoredDeploy.exe"`, a white list that isn't used (`CompareWithWhiteList` always returns `S_OK`) |

`CoreCLRInstance` (0x10 bytes):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `ICLRRuntimeHost2 *` (IID {712AB73F-2C22-4807-AD7E-F501D7B72C2D}) |
| 0x04 | 4 | `ICLRControl *` (`GetCLRControl`) |
| 0x08 | 4 | AppDomain ID |
| 0x0C | 4 | `HMODULE` of CoreClr.dll |

### Startup

`_DllMainCRTStartup` (0x10008CF0): the usual CRT startup; the dynamic initialisers build `g_wsTestTrustedPath` and `c_saList`. `DllMain` (0x10004AC0) only calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH`. Nothing is started before one of the two exports is called.

### _CorExeMain (0x10005B2C)

Calls the lambda at 0x10005B44 and passes its result to `exit`:

1. `GetModuleFileNameW(NULL)`: path of the executable; its directory is the first entry of `APP_PATHS`.
2. `InitializeStartInfo` ([below](#initializestartinfo-0x10005884)), which also returns "test settings" and "packaged" flags.
3. `CoInitializeEx(NULL, COINIT_MULTITHREADED)`; `CoUninitialize` at the end if it succeeded.
4. `StartCoreCLR`.
5. If the debugger wait is enabled: `CreateDelegate("mscoreehelper, Version=0.0.0.0", "Microsoft.Phone.Test.MSCoreeRunHelper", "WaitForDebuggerInManaged")` and calls the delegate with 1; any non-zero result stops here.
6. If COM is initialised and the process is packaged: registers the [low memory GC](#low-memory-gc) handler.
7. `RunAssembly(<executable path>)`:
   - `CommandLineToArgvW(GetCommandLineW())`; `ICLRRuntimeHost2::ExecuteAssembly(domainId, exePath, argc − 1, argv + 1, &exitCode)` (argv[0] is dropped).
   - `UnloadAppDomain(domainId, FALSE)`, `Stop()`, release of `ICLRControl` and of the host; returns the exit code of the managed `Main`, or the failing HRESULT.
8. Removes the memory handler (`remove_AppMemoryUsageIncreased`).

### DllGetActivationFactory (0x10005DD0)

1. If `g_isCoreCLRStarted` isn't set: takes `g_startCoreCLRLock`, checks again, sets `g_coreCLRMustBeStarted`, then `InitializeStartInfo` and `StartCoreCLR` (which releases the lock). The executable directory isn't added to `APP_PATHS` here, and the low memory handler isn't registered.
2. Returns `E_FAIL` (0x80004005) if the runtime isn't started or the class name is empty, otherwise `ICLRRuntimeHost2::DllGetActivationFactory(domainId, <class name>, factory)`.

### InitializeStartInfo (0x10005884)

Fills a [CoreCLRStartInfo](#coreclrstartinfo):

1. `GetSystem32Directory` (`GetSystemDirectoryW`): System32 is the only directory searched for `CoreClr.dll` (`AppendCoreClrDllSearchPath`).
2. `ConfigureTestSettings` ([registry](#registry)).
3. `PopulateTPAListForProduct` (0x10005428): System32 → `PLATFORM_RESOURCE_ROOTS`, and the 62 [framework native images](#trusted-platform-assemblies) → `TRUSTED_PLATFORM_ASSEMBLIES`.
4. `PopulateAppPaths` (0x100052AC): `GetCurrentPackageInfo(PACKAGE_FILTER_HEAD | PACKAGE_FILTER_DIRECT (0x30))`; for each `PACKAGE_INFO` (0x34 bytes), its `path` → `APP_PATHS` and `GetNIFolderPathForPackage(path, packageFullName)` → `APP_NI_PATHS`:
   - path on `%SystemDrive%`: `HKLM\Software\Microsoft\Windows\CurrentVersion\AppX\PackageRepositoryRoot` + `\Packages\` + full name + `\NI`;
   - other drive (SD card): `<drive letter>:\WPSystem\APPREPOSITORY\` + full name + `\NI`.
5. Result of `PopulateAppPaths`:
   - `APPMODEL_ERROR_NO_PACKAGE` (0x80073D54, the process has no package): with the test settings, AppDomain flag 0x20 and `APP_PATHS` is appended to `APP_NI_PATHS`; otherwise `CompareWithWhiteList` (stub, `S_OK`). Startup flags 0x00800001.
   - package found: startup flags 0x01800001, "packaged" = 1. Any other error is returned.
6. With the test settings: [`<System32>\mscoree.TPALIST`](#tpa-list-file) is added to the TPA list.
7. Startup flags at +0x9C; AppDomain flags at +0xA0 = (0 or 0x20) | 0x50.

With the values of the public CoreCLR `mscoree.h` (not checked against the phone build): startup flags 0x1 = `STARTUP_CONCURRENT_GC`, 0x800000 = `STARTUP_SINGLE_APPDOMAIN`, 0x1000000 = `STARTUP_APPX_APP_MODEL` ?; AppDomain flags 0x10 = `APPDOMAIN_ENABLE_PINVOKE_AND_CLASSIC_COMINTEROP`, 0x40 = `APPDOMAIN_ENABLE_PLATFORM_SPECIFIC_APPS`, 0x20 = `APPDOMAIN_SET_TEST_KEY` ?.

### StartCoreCLR (0x10006D1C)

Allocates `g_pCoreCLRInstance`, then (lambda at 0x10006EB4, `E_FAIL` if already started):

1. Property bag: `TRUSTED_PLATFORM_ASSEMBLIES` (always), `APP_PATHS`, `PLATFORM_RESOURCE_ROOTS`, `APP_NI_PATHS`, `NATIVE_DLL_SEARCH_DIRECTORIES` (each only if not empty; nothing fills the last one).
2. `FindCoreClr`: first `<dir>\CoreClr.dll` of the search list for which `GetFileAttributesW` succeeds; `E_FAIL` if none.
3. `LoadLibraryExW(path, NULL, 0)`, `GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN)`, `GetProcAddress("GetCLRRuntimeHost")`, `GetCLRRuntimeHost(IID_ICLRRuntimeHost2, &host)`.
4. `host->Authenticate(0x01C6CA6F94025800)`, `GetCLRControl(&instance+4)`, `SetStartupFlags(+0x9C)`, `Start()`.
5. `CreateAppDomainWithManager(L".", <+0xA0 flags>, NULL, NULL, nProperties, keys, values, &instance+8)`, then `g_isCoreCLRStarted = 1`.

Releases `g_startCoreCLRLock` if `g_coreCLRMustBeStarted` is set, and frees the instance on failure.

`ICLRRuntimeHost2` methods used (vtable offset): `Start` 0x0C, `Stop` 0x10, `GetCLRControl` 0x18, `UnloadAppDomain` 0x1C, `CreateAppDomainWithManager` 0x30, `CreateDelegate` 0x34, `Authenticate` 0x38, `SetStartupFlags` 0x40, `DllGetActivationFactory` 0x44, `ExecuteAssembly` 0x48.

### CoreCLRStartInfo

0xA4 bytes; the strings are `std::wstring` (0x1C bytes), the lists are separated by `;`.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 0x1C | `APP_PATHS` |
| 0x1C | 0x1C | `PLATFORM_RESOURCE_ROOTS` (System32) |
| 0x38 | 0x1C | `APP_NI_PATHS` |
| 0x54 | 0x1C | `NATIVE_DLL_SEARCH_DIRECTORIES` (always empty) |
| 0x70 | 0x1C | `TRUSTED_PLATFORM_ASSEMBLIES` |
| 0x8C | 0x10 | `std::vector<std::wstring>`: directories searched for `CoreClr.dll` (System32) |
| 0x9C | 4 | Startup flags |
| 0xA0 | 4 | AppDomain flags |

### Trusted platform assemblies

The table at 0x100015D8 (62 entries of 0x78 bytes) gives the files appended after the System32 path: `INTERNAL.NUMERICS`, `MICROSOFT.CSHARP`, `MICROSOFT.VISUALBASIC`, `MSCORLIB.EXTENSIONS`, `MSCORLIB`, `SYSTEM.COLLECTIONS.CONCURRENT`, `SYSTEM.COLLECTIONS`, `SYSTEM.COMPONENTMODEL.EVENTBASEDASYNC`, `SYSTEM.COMPONENTMODEL`, `SYSTEM.CORE`, `SYSTEM.DIAGNOSTICS.CONTRACTS`, `SYSTEM.DIAGNOSTICS.DEBUG`, `SYSTEM.DIAGNOSTICS.TOOLS`, `SYSTEM.DIAGNOSTICS.TRACING`, `SYSTEM.DYNAMIC.RUNTIME`, `SYSTEM.GLOBALIZATION`, `SYSTEM.IO.COMPRESSION`, `SYSTEM.IO`, `SYSTEM.LINQ.EXPRESSIONS`, `SYSTEM.LINQ`, `SYSTEM.LINQ.PARALLEL`, `SYSTEM.LINQ.QUERYABLE`, `System.Net.Http`, `System.Net.Http.Phone`, `System.Net.Http.Primitives`, `System.Net.NetworkInformation`, `System.Net`, `System.Net.Primitives`, `System.Net.Requests`, `SYSTEM`, `SYSTEM.OBJECTMODEL`, `SYSTEM.REFLECTION.EXTENSIONS`, `SYSTEM.REFLECTION`, `SYSTEM.REFLECTION.PRIMITIVES`, `SYSTEM.RESOURCES.RESOURCEMANAGER`, `SYSTEM.RUNTIME.EXTENSIONS`, `SYSTEM.RUNTIME.INTEROPSERVICES`, `SYSTEM.RUNTIME.INTEROPSERVICES.WINDOWSRUNTIME`, `SYSTEM.RUNTIME`, `SYSTEM.RUNTIME.NUMERICS`, `SYSTEM.RUNTIME.SERIALIZATION.JSON`, `SYSTEM.RUNTIME.SERIALIZATION`, `SYSTEM.RUNTIME.SERIALIZATION.PRIMITIVES`, `SYSTEM.RUNTIME.SERIALIZATION.XML`, `System.Runtime.WindowsRuntime`, `System.Runtime.WindowsRuntime.UI.Xaml`, `SYSTEM.SECURITY.PRINCIPAL`, `SYSTEM.SERVICEMODEL.WEB`, `SYSTEM.TEXT.ENCODING.EXTENSIONS`, `SYSTEM.TEXT.ENCODING`, `SYSTEM.TEXT.REGULAREXPRESSIONS`, `SYSTEM.THREADING`, `SYSTEM.THREADING.TASKS`, `SYSTEM.THREADING.TASKS.PARALLEL`, `SYSTEM.THREADING.TIMER`, `SYSTEM.XML.LINQ`, `SYSTEM.XML`, `SYSTEM.XML.READERWRITER`, `SYSTEM.XML.SERIALIZATION`, `SYSTEM.XML.XDOCUMENT`, `SYSTEM.XML.XMLSERIALIZER` (each `\<name>.NI.DLL;`), and `\WINMETADATA\WINDOWS.NI.WINMD;`. Their existence isn't checked.

### TPA list file

`PopulateTPAListFromFile` (0x10004E48), only when `AllowTestTPAs` is set:

1. `ReadTPAFile`: the file must start with the UTF-16LE BOM `FF FE` (`E_FAIL` otherwise); the rest is read as one string.
2. Tokens separated by `;`, CR or LF (`wcstok_s`). In each, the first placeholder found is replaced: `[SYSTEM32]` → System32, else `[TESTBIN]` → `g_wsTestTrustedPath` (System32 if empty), else `[APPDIR]` → the current directory.
3. Tokens whose file exists (`_waccess`) are added to `TRUSTED_PLATFORM_ASSEMBLIES`.

### Low memory GC

`RunGcOnLowMemory`, registered by `_CorExeMain` in a packaged process: `RoGetActivationFactory("Windows.System.MemoryManager", IMemoryManagerStatics)` → `add_AppMemoryUsageIncreased`. The handler `OnAppMemoryUsageIncreased` (0x100059C4) reads `AppMemoryUsageLevel`; when it's `High` (2), it gets `ICLRGCManager` ({54D9007E-A8E2-4885-B7BF-F998DEEE4F2A}) with `ICLRControl::GetCLRManager` and calls `Collect(-1)` (all generations).

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\SOFTWARE\Microsoft\TaskHost` | `DisableNIs` (DWORD) | ≠ 0: `SetEnvironmentVariableW("COMPLUS_ZAPDISABLE", "1")`, the runtime doesn't use the native images |
| | `TestDebuggerAttach` (DWORD) | ≠ 0: wait for a managed debugger (`WaitForDebuggerInManaged`, `_CorExeMain` only); also enabled when the environment variable `MSCOREE_DEBUG` exists |
| | `AllowTestTPAs` (DWORD) | ≠ 0: enables the test settings below, the `mscoree.TPALIST` file and AppDomain flag 0x20 for an unpackaged process |
| | `TestTrustedPath` (REG_SZ, expanded) | `[TESTBIN]` folder of `mscoree.TPALIST`; required when `AllowTestTPAs` is set |
| | `TestAppPaths` (REG_SZ, expanded) | Appended to `APP_PATHS` |
| `HKLM\Software\Microsoft\Windows\CurrentVersion\AppX` | `PackageRepositoryRoot` (REG_SZ) | Root of the native images of the packages on the system drive |

The `TaskHost` key is opened with `KEY_QUERY_VALUE`; if it doesn't exist, no test setting is applied.
