## MirrorCPL.exe

The "project my screen" page of the Windows Phone 8.1 settings (screen projection to a Miracast display or over USB), see [MirrorUX.dll](../libraries/mirrorux.md).  
`MirrorCPL.exe` is only a small launcher (24 576 bytes, 23 functions), built like [Alarms.exe](./alarms.md) and [DateTimeCPL.exe](./datetimecpl.md): it has no UI code. The whole user interface is a UIX markup file stored as a resource of [MirrorUX.dll](../libraries/mirrorux.md), and it's started by `RunApplication` of [UIXMobile.dll](../libraries/uixmobile.md), the UIX framework of the Windows Phone shell.  
The settings logic is in [MirrorUX.dll](../libraries/mirrorux.md) (UIX schema with the types `MainPage`, `Device` and `AdvancedPage`); its markup resources werent extracted.

Location on the phone: `C:\Windows\System32\MirrorCPL.exe` ? (no path in the binary).

### Imports

| DLL | Functions |
|-----|-----------|
| [UIXMobile.dll](../libraries/uixmobile.md) | `RunApplication` |
| msvcrt.dll | `__wgetmainargs`, `_wcmdln`, `_initterm`, `_amsg_exit`, `_exit`, `_cexit`, `exit`, `__set_app_type`, `__setusermatherr`, `_fmode`, `_commode`, `_XcptFilter`, `__C_specific_handler`, `?terminate@@YAXXZ`, `memset` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetStartupInfoW`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleA` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |

Everything except `RunApplication` is the standard Visual C++ CRT startup and `/GS` security cookie code. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [MirrorUX.dll](../libraries/mirrorux.md) | `res://MirrorUX!mainpage.uix`, passed to `RunApplication` | Resource module holding the UIX markup of the whole user interface (loaded by the UIX engine `UIXn.dll` started by [UIXMobile.dll](../libraries/uixmobile.md)) |

No other file, process, COM server or device is used directly: there is no `LoadLibrary`, `CreateProcess`, `CoCreateInstance` or file API in the binary.

### Parameters

`wWinMain` (`sub_1001198`, 0x1001198) doesn't parse the command line: like [DateTimeCPL.exe](./datetimecpl.md#parameters), it copies the `lpCmdLine` pointer (the command line after the program name, quotes and leading blanks skipped by the CRT) unchanged into the [parameter block](#runapplication-parameter) passed to `RunApplication`, so it's parsed by [UIXMobile.dll](../libraries/uixmobile.md#command-line) (`/taskhandle`, then UIX switches after `/uix`). `nShowCmd` is ignored. The return value of `RunApplication` is ignored and the exit code is always 0.  
The caller and the possible arguments aren't known.

### RunApplication parameter

`UIXMobile!RunApplication` receives a pointer to a structure built on the stack: 0x3C bytes are reserved, the 0x38 bytes after the first field are zeroed by `memset`, then the fields below are set (the other launchers document it as 0x40 bytes; UIXMobile.dll reads 0x3C bytes, see [RUNAPPLICATION_OPTIONS](../libraries/uixmobile.md#runapplication_options)). Unlike [DateTimeCPL.exe](./datetimecpl.md#runapplication-parameter), the fields 0x20 (allowed rotations: 0 = portrait only) and 0x28 (high contrast override: 0 = off) are left at 0.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | `L"res://MirrorUX!mainpage.uix"` | URI of the frame markup of the application (loaded in `res://UIXMobile!AppHost.uix`): resource `mainpage.uix` of the module `MirrorUX` ([MirrorUX.dll](../libraries/mirrorux.md)) |
| 0x04 | 4 | `L"DictEntryMainPage"` | Destination (page) of the initial navigation (a dictionary entry of the markup ?) |
| 0x08 | 8 | 0 | No navigation arguments |
| 0x10 | 4 | `lpCmdLine` | Command line of the process, parsed by [UIXMobile.dll](../libraries/uixmobile.md#command-line) |
| 0x14 | 0x28 | 0 | No `argc`/`argv`, default options (portrait, no overrides, computed scale factor) |

[RunApplication](../libraries/uixmobile.md#runapplication-0x1003152c) starts the UIX engine with this markup and runs it until the application is closed (`UIXn!UIXRunApplication`).
