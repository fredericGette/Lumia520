## DateTimeCPL.exe

The "date+time" page of the Windows Phone 8.1 settings (time zone, automatic time, date and time, 24-hour clock).  
`DateTimeCPL.exe` is only a small launcher (28 672 bytes, 23 functions), built like [Alarms.exe](./alarms.md): it has no UI code. The whole user interface is a UIX markup file stored as a resource of `DateTimeCPLdll`, and it's started by `RunApplication` of [UIXMobile.dll](../libraries/uixmobile.md), the UIX framework of the Windows Phone shell.  
The settings logic is in the sibling binaries [DateTimeCPLdll.dll](../libraries/datetimecpldll.md) (UIX markup and its code-behind, the `DateTimeProvider` schema) and `DateTimeCPLRes.dll` (8 192 bytes, localised strings `res://DateTimeCPLRes!SplashStrings.uix`, not analysed).

Location on the phone: `C:\Windows\System32\DateTimeCPL.exe` ? (no path in the binary).

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
| [DateTimeCPLdll.dll](../libraries/datetimecpldll.md) | `res://DateTimeCPLdll!Frame.uix`, passed to `RunApplication` | Resource module holding the UIX markup of the whole user interface (resource `FRAME.UIX`), loaded by the UIX engine `UIXn.dll` started by [UIXMobile.dll](../libraries/uixmobile.md) |

No other file, process, COM server or device is used directly: there is no `LoadLibrary`, `CreateProcess`, `CoCreateInstance` or file API in the binary. `DateTimeCPLRes.dll` isn't referenced by `DateTimeCPL.exe`: it's referenced by the markup of DateTimeCPLdll.dll (`res://DateTimeCPLRes!SplashStrings.uix`, see [its dependencies](../libraries/datetimecpldll.md#dependencies)).

### Parameters

`wWinMain` (`sub_1001188`, 0x1001188) doesn't parse the command line: it copies the `lpCmdLine` pointer (the command line after the program name, quotes and leading blanks skipped by the CRT) unchanged into the [parameter block](#runapplication-parameter) passed to `RunApplication`, so it's parsed by [UIXMobile.dll](../libraries/uixmobile.md#command-line): only `/taskhandle:<hex>` is read before a `/uix` switch, the UIX switches (`/locale`, `/themeoverride`, `/resolution`…) after it. `nShowCmd` is ignored. The return value of `RunApplication` is ignored and the exit code is always 0.  
The caller and the possible arguments (e.g. a sub-page to open from the settings list) aren't known.

### RunApplication parameter

`UIXMobile!RunApplication` receives a pointer to a 0x40-byte structure (`RUNAPPLICATION_OPTIONS`, of which UIXMobile.dll reads 0x3C bytes, see [UIXMobile.dll](../libraries/uixmobile.md#runapplication_options)), zeroed by `memset` except for the fields below. Compared to [Alarms.exe](./alarms.md#runapplication-parameter), three more fields are set.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | `L"res://DateTimeCPLdll!Frame.uix"` | URI of the frame markup of the application (loaded in `res://UIXMobile!AppHost.uix`): resource `FRAME.UIX` of [DateTimeCPLdll.dll](../libraries/datetimecpldll.md#resources) |
| 0x04 | 4 | `L"Home"` | Destination (page) of the initial navigation |
| 0x08 | 8 | 0 | No navigation arguments |
| 0x10 | 4 | `lpCmdLine` | Command line of the process, parsed by [UIXMobile.dll](../libraries/uixmobile.md#command-line) |
| 0x14 | 0xC | 0 | No `argc`/`argv`, default flags |
| 0x20 | 4 | 11 (0xB) | Allowed rotations (bit mask: portrait and the two landscape orientations ?) |
| 0x24 | 4 | 0 | Theme override: none |
| 0x28 | 4 | 2 | High contrast override: system |
| 0x2C | 0x14 | 0 | No services callback, default flags, default root markup (`AppHost.uix`), computed scale factor |

[RunApplication](../libraries/uixmobile.md#runapplication-0x1003152c) starts the UIX engine with this markup and runs it until the application is closed (`UIXn!UIXRunApplication`).
