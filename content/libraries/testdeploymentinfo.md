## TestDeploymentInfo.dll

Gives the test tools the folders of the test deployment on the phone.  
`TestDeploymentInfo.dll` is a tiny Microsoft internal test DLL (28 392 bytes, 25 functions, almost all CRT; PDB `testdeploymentinfo.pdb`). Its two exports copy a hard-coded path into the caller's buffer: `\data\test\` and `\data\test\bin\`. It reads no registry value or file.  
[TH.exe](../applications/th.md) imports it to build the command line of [TestNavigationApi.exe](../applications/testnavigationapi.md). CMD Injector (WP8) copies it next to `TH.exe` and `th.dll`.

Location on the phone: `C:\Windows\System32\TestDeploymentInfo.dll` (copied by CMD Injector from its `Contents\ConsoleApps` folder, like [TH.exe](../applications/th.md)).  

### Imports

| DLL | Functions |
|-----|-----------|
| msvcrt.dll | `wcscpy_s`, `malloc`, `free`, `_initterm`, `_amsg_exit`, `_XcptFilter`, `__C_specific_handler` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |

Everything except `wcscpy_s` is the Visual C++ DLL CRT startup code.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `GetTestDeployBinPath` | 0x10001148 | `WCHAR *buffer`, `size_t count` (in characters) |
| 2 | `GetTestDeployRootPath` | 0x10001130 | `WCHAR *buffer`, `size_t count` (in characters) |

Each export is a tail call to `wcscpy_s(buffer, count, <path>)` and returns its `errno_t` (0 on success, `ERANGE` / `EINVAL` when the buffer is too small or NULL):

| Export | Path copied | String |
|--------|-------------|--------|
| `GetTestDeployBinPath` | `L"\\data\\test\\bin\\"` | 0x10001070 (pointer `off_10002004`) |
| `GetTestDeployRootPath` | `L"\\data\\test\\"` | 0x10001058 (pointer `off_10002000`) |

The paths have no drive letter and end with a backslash: callers append a file name. A root-relative path is resolved on the drive of the current directory, so `C:\Data\Test\bin\` from a usual prompt. For example, [TH.exe](../applications/th.md#dependencies) `-r` runs `\data\test\bin\TestNavigationAPI.exe LaunchModernApplication <AUMID>`.

### Startup

`DllEntryPoint` (0x100016A4) → `dllmain_dispatch` (0x100013B0) → `_CRT_INIT`. `DllMain` (`unknown_libname_1`, 0x100017CC) only returns TRUE.
