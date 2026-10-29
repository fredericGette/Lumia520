## Alarms.exe

The "Alarms" application of Windows Phone 8.1 (the alarm clock with the list of alarms).  
`Alarms.exe` is only a small launcher (24 576 bytes, 23 functions): it has no UI code. The whole user interface is a UIX markup file stored as a resource of `AlarmsDll`, and it's started by `RunApplication` of `UIXMobile.dll`, the UIX framework of the Windows Phone shell.  
The alarms are managed and rung by other binaries of the same folder: [Alarms_NoUI.exe](./alarms_noui.md) (shell reminders, Start tile, lock screen), [AlarmsSettingHandler.dll](../libraries/alarmssettinghandler.md) (backup / restore of the alarms), and [ReminderEvents.dll](../libraries/reminderevents.md) (hands the reminders to the shell).

Location on the phone: `C:\Programs\Alarms\Alarms.exe` ? (same folder as `Alarms_NoUI.exe`, whose path `c:\Programs\Alarms\Alarms_NoUI.exe` is a string of that binary).

### Imports

| DLL | Functions |
|-----|-----------|
| UIXMobile.dll | `RunApplication` |
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
| `AlarmsDll` (`AlarmsDll.dll` ?) | `res://AlarmsDll!Frame.uix`, passed to `RunApplication` | Resource module holding the UIX markup of the whole user interface (loaded by `UIXMobile.dll`) |

No other file, process, COM server or device is used directly: there is no `LoadLibrary`, `CreateProcess`, `CoCreateInstance` or file API in the binary.

### Parameters

The command line isn't used: `wWinMain` (`call_RunApplication`, 0x1001174) ignores its parameters, calls `RunApplication` with the [parameter block](#runapplication-parameter) below and always exits with code 0 (the return value of `RunApplication` is ignored).

### RunApplication parameter

`UIXMobile!RunApplication` receives a pointer to a 0x40-byte structure. Only the first two fields are set by Alarms.exe, the rest is zero.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | `L"res://AlarmsDll!Frame.uix"` | URI of the root UIX markup: resource `Frame.uix` of the module `AlarmsDll` (`AlarmsDll.dll` ?) |
| 0x04 | 4 | `L"Home"` | Name of the page shown at startup |
| 0x08 | 0x38 | 0 | Unknown (not used by Alarms.exe; [DateTimeCPL.exe](./datetimecpl.md#runapplication-parameter) sets 0x10, 0x20 and 0x28) |

`RunApplication` probably loads the markup, creates the window and runs the message loop until the application is closed ? (`UIXMobile.dll` isn't analysed).
