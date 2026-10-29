## Alarms_NoUI.exe

The background part of the "Alarms" application of Windows Phone 8.1: it creates, enables, disables and reschedules the alarms, and updates the alarm indicator of the lock screen and the Start tile of Alarms.  
`Alarms_NoUI.exe` has no window (53 248 bytes, 275 functions). It's a command-line tool: each run executes one command given in `argv[1]` and exits. The alarms themselves are shell reminders (`Shell_*Reminder*` of [ShellChromeAPI.dll](../libraries/shellchromeapi.md#reminders)): the shell rings them, and when the user dismisses one it starts `Alarms_NoUI.exe ReminderDismissed <index>` again. The tile is updated through the Package Manager (PacMan) COM client, statically linked in the binary.  
The user interface is [Alarms.exe](./alarms.md) (UIX markup in `AlarmsDll`). [ReminderEvents.dll](../libraries/reminderevents.md) receives the reminders from the Task Scheduler service and hands them to the shell. [AlarmsSettingHandler.dll](../libraries/alarmssettinghandler.md) backs up and restores the alarms with the same alarm code (statically linked). `AlarmsRes.dll` (localized strings, loaded as a data file) isn't documented here.

Location on the phone: `C:\Programs\Alarms\Alarms_NoUI.exe` (string at 0x1001138, used as the application path of the reminders).  

### Imports

| DLL | Functions |
|-----|-----------|
| [ShellChromeAPI.dll](../libraries/shellchromeapi.md) | `Shell_InitReminders`, `Shell_DeInitReminders`, `Shell_CreateReminder`, `Shell_GetReminderData`, `Shell_ReleaseReminderData`, `Shell_DeleteReminder`, `Shell_SetReminderState`, `Shell_SetLockScreenAlarmIndication` |
| ntdll.dll | `RtlPublishWnfStateData` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoUninitialize`, `CoCreateInstance`, `CLSIDFromString` |
| OLEAUT32.dll | `SysAllocString`, `SysFreeString`, `SystemTimeToVariantTime` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey` |
| api-ms-win-core-path-l1-1-0.dll | `PathCchCombine` |
| api-ms-win-core-datetime-l1-1-1.dll | `GetTimeFormatW` |
| api-ms-win-core-timezone-l1-1-0.dll | `SystemTimeToFileTime`, `FileTimeToSystemTime` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetLocalTime`, `GetSystemTime` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| ZTrace.dll | `ZTraceReportOriginationNoThis`, `ZTraceReportPropagationNoThis` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `FreeLibrary`, `GetProcAddress`, `LoadStringW`, `GetModuleHandleExW`, `GetModuleFileNameA`, `GetModuleHandleA` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `InitOnceBeginInitialize`, `InitOnceComplete`, `Sleep` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1.dll | `DebugBreak` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `__wgetmainargs`, `_initterm`, `_wtoi`, `_wcstoui64`, `_wcsicmp`, `_vsnwprintf`, `wcslen`, `wcsnlen`, `memcpy`, `memset`, … (CRT, C++ exceptions, `operator new`/`delete`) |

The msvcrt, rtlsupport, processthreads, errorhandling and debug imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. `ZTrace.dll` and the `StringRes::*` strings come from a shared resource-string helper. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `AlarmsRes.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)` (`sub_100737C`, name set by `sub_1002EA0`) | Localized strings of the Start tile and of the lock screen (see [Start tile and lock screen](#start-tile-and-lock-screen)) |
| `PacManMock.dll` | `LoadLibraryExW` + `GetProcAddress` (`sub_1004CC8`) | Test replacement of the PacMan COM client (see [COM](#com)) |
| `c:\Programs\Alarms\Alarms_NoUI.exe` (itself) | Program and command line of the reminders (`CreateAlarmReminder`) | Started again by the shell when an alarm is dismissed (see [Parameters](#parameters)) |
| Sound file of `HKLM\Software\Microsoft\EventSounds\SoundCategories\Alarm\DefaultSound` | Path built with `PathCchCombine` (`ValidateAlarmDefaultSound`), not opened | Default sound of a new alarm (+0x118 of the alarm record, see [Commands](#commands)) |
| PacMan server, CLSID `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` | `CoCreateInstance` | Start tile of Alarms (see [COM](#com)) |
| COM server `{D0DF0C7D-33BF-4E04-9B11-B1D7AE572EED}` | `CoCreateInstance` (`sub_1005C10`, IID `{095BF7A5-F134-42B9-A4B0-7C5F1A9E199A}`) | ? (part of the linked PacMan client library, not used by the alarm code; also created by [ShellChrome.dll](../libraries/shellchrome.md#dependencies)) |

### Parameters

Each run executes the command given in `argv[1]` (`wmain` = `HandleAlarmCommand`, 0x1002A00) and exits. Hex-Rays fails on this function and on most of the functions it calls (what follows comes from the disassembly). Every run registers the ETW provider `{8373B2DE-…}` and writes an ETW event with the result (see [ETW](#etw)). What each command does is described in [Commands](#commands).

| Command line | Usage | Exit code | Started by |
|---|---|---|---|
| `Alarms_NoUI.exe ReminderDismissed <index>` | Case-insensitive. `<index>` = alarm slot (`_wtoi`, see [Alarm slots](#alarm-slots)); -1 or ≥ 32 fails with `E_FAIL`, missing does nothing. Calls `ReminderDismissed(index)` (`sub_1002528`) | 0 | The shell, when an alarm reminder is dismissed (command line stored in the reminder, see [Shell_CreateReminder](#shell_createreminder-parameters)): [ShellChrome.dll](../libraries/shellchrome.md#reminders) with `CreateProcessInChamber` |
| `Alarms_NoUI.exe UpdateLockAndStartInfo` | Case-insensitive. Calls `UpdateLockAndStartInfo_or_TimeChanged(0)` | 0 | The Task Scheduler task `AlarmLockIconTask` created by [ShellChrome.dll](../libraries/shellchrome.md#alarmlockicontask), on the WNF state `WNF_SHL_START_READY` |
| `Alarms_NoUI.exe TimeChanged` | Case-sensitive. Calls `UpdateLockAndStartInfo_or_TimeChanged(1)` | 0 | [ShellChrome.dll](../libraries/shellchrome.md#alarms_noui-command-lines) exports `SystemTimeChanged` / `SystemTimeFormatChanged` (`CreateProcessInChamber`) |
| `Alarms_NoUI.exe CreateAlarm <filetime> [<name>]` | Case-sensitive. `<filetime>`: `FILETIME` in decimal or `0x…` (`_wcstoui64(…, 0)`), missing or 0 gives `E_INVALIDARG`. `<name>`: optional (`L""` if absent). Calls `CreateAlarm(time, name)` | HRESULT | ? (`Alarms.exe` UI ?; not [AlarmsSettingHandler.dll](../libraries/alarmssettinghandler.md), which creates the reminders itself) |
| `Alarms_NoUI.exe EnableAlarm {guid}` / `DisableAlarm {guid}` | Case-sensitive. `{guid}`: GUID of the alarm slot, parsed with `CLSIDFromString` (missing gives `E_INVALIDARG`). Calls `EnableAlarm_or_DisableAlarm(&id, enable)` | HRESULT | ? |
| `Alarms_NoUI.exe` (no argument) or any other command | Does nothing | 0 | [AlarmsSettingHandler.dll](../libraries/alarmssettinghandler.md#beginsession-sub_10006478), with `CreateProcessInChamber` at the start of a backup / restore session (no argument) |

The `<filetime>` of `CreateAlarm` is converted with `FileTimeToSystemTime` without time zone conversion, and compared later with `GetLocalTime`: it's a local time. The name is truncated to 129 characters (`0x8007007A` returned in that case).

### Alarm slots

There are at most 32 alarms. Each slot has a fixed GUID (table `unk_1009048`, 32 × 16 bytes) that is the ID of its shell reminder; `EnableAlarm`/`DisableAlarm` find the slot by searching this table (`E_INVALIDARG` if the GUID isn't in it).

| Index | GUID | Index | GUID |
|---|---|---|---|
| 0 | `{F6BAF232-298F-4DF7-96AA-189E4F53EA56}` | 16 | `{F8540795-833B-418A-91F3-CDE2BB8334D0}` |
| 1 | `{6DDE298F-5165-4453-BDC2-7A639EB8A160}` | 17 | `{121E4215-65A5-4761-A9B8-ABD44A756D4A}` |
| 2 | `{01CDD6E0-D397-43FD-93ED-76F532FC556D}` | 18 | `{61FC4CB5-694A-4A82-89C0-63665EA823A0}` |
| 3 | `{E359B8B8-B911-4C32-9502-F0D61204F593}` | 19 | `{13F3064D-C6EB-4842-ADF2-15C5CAEF4957}` |
| 4 | `{3BD8B9B6-7ECC-43EF-81F0-1F49672A78AA}` | 20 | `{5FDB52A2-59C1-439A-AD48-0D3BBC2FC58A}` |
| 5 | `{FB55788F-69F2-4220-8373-B43F82F6B241}` | 21 | `{81711245-D73A-43D5-9E91-DC8FD95D5E54}` |
| 6 | `{F9702F8C-1EB2-4119-A26B-58200E2E1406}` | 22 | `{C733BC4C-5D4B-41B2-9E1B-9C257F999431}` |
| 7 | `{F507B14B-4BBB-44C5-B19A-925AC0D4DD0C}` | 23 | `{82677424-7C7B-47B5-A228-CF7910CD1DAE}` |
| 8 | `{C47FE1AB-4C05-44E8-8389-758D14349FE5}` | 24 | `{7ABFEA60-A652-4BCD-A416-AC8DE17F061C}` |
| 9 | `{1D74E2A0-7776-46C6-8A7D-A731D17ECC00}` | 25 | `{A0246D3F-B29B-461A-BFE8-0ADEE7EAC25E}` |
| 10 | `{4E62D43B-62C8-4CD9-BABB-2E5CEA4E0084}` | 26 | `{A8BF6A3F-0699-41A1-AA54-1BD0A9F01945}` |
| 11 | `{67003880-F516-4D28-9CA5-5729ECD0FFA8}` | 27 | `{5D2554D2-0C87-45BE-8D7A-0296F515C712}` |
| 12 | `{1D3DB46C-AAE3-4954-BEEF-C2A291639C53}` | 28 | `{3C1857E2-1B3F-436C-A66D-A60C0CA1BF11}` |
| 13 | `{3600BBF8-97B1-45C1-89B5-3C6420C92F2D}` | 29 | `{2071C0D1-2BBE-48E8-BA86-DD89036496CE}` |
| 14 | `{CBC02069-21C0-411B-8927-4BCEC06EC3C6}` | 30 | `{33506C9D-E665-4A67-9A63-F416FD8474A5}` |
| 15 | `{75C8C7B5-AC36-411B-BD30-B6C1A45B2FE2}` | 31 | `{72309536-68A5-4380-9AE9-12197F77FF8E}` |

Every command starts by loading all the slots (`sub_1002EA0`): `Shell_InitReminders`, PacMan client init (`sub_1004AD4`: `CoInitializeEx(NULL, COINIT_MULTITHREADED)`), then `Shell_GetReminderData` for the 32 GUIDs (`sub_1003CEC`). Slots whose reminder doesn't exist are free. The in-memory copy of a slot is a 0x330-byte record (initialised by `sub_10042EC`):

| Offset | Size | Default | Comment |
|--------|------|---------|---------|
| 0x000 | 4 | -1 | Slot index (0…31) |
| 0x004 | 16 | 0 | `SYSTEMTIME` of the alarm (local time) |
| 0x014 | 0x104 | "" | Name, `WCHAR[130]` |
| 0x118 | 0x20C | "" | Sound file, `WCHAR[262]` |
| 0x324 | 4 | 0 | Enabled |
| 0x328 | 1 | 1 | Start of the 8-byte data blob stored in the reminder: version ? (must be 1) |
| 0x329 | 1 | 0 | Repeat days, bit 0 = Monday … bit 6 = Sunday. 0 = one-time alarm |
| 0x32A | 2 | | Padding |
| 0x32C | 4 | 10 | Snooze time in minutes ? |

### Commands

**CreateAlarm** (`CreateAlarm`, 0x1002764): takes the first free slot (`0x80070161` if the 32 are used), sets the time and the name, enabled = 1, and reads the default sound:

- Registry: `HKLM\Software\Microsoft\EventSounds\SoundCategories\Alarm`, value `DefaultSound` (`REG_SZ`, up to 0x20C bytes, `E_FAIL` if another type) → +0x118 (`ValidateAlarmDefaultSound`, 0x10072A0).

Then `sub_10030DC`: if the alarm repeats, its date is moved to the first selected day of the week; `CreateAlarmReminder`; next alarm / tile / lock screen update (`sub_1003098`); publishes the slot index in the WNF state 0x418A063EA3BC3075.

**EnableAlarm / DisableAlarm** (`EnableAlarm_or_DisableAlarm`, 0x10028EC): nothing is done if the slot is already in the requested state. Otherwise it changes +0x324, moves the date of the alarm to today, or tomorrow if the time has passed (`sub_1004254`), then `sub_100338C`: date adjusted to the next selected day for a repeating alarm, `Shell_DeleteReminder`, `CreateAlarmReminder` (a disabled alarm keeps a reminder, with flag 0x200), `sub_1003098`, WNF 0x418A063EA3BC3075 = index.

**ReminderDismissed** (`sub_1002528`): reloads the slot (`sub_1003200`) then `sub_10032EC`:
- one-time alarm: `Shell_SetReminderState(h, &guid, 0)`, enabled = 0, `sub_1003098`;
- repeating alarm: `sub_10034C4` computes the next selected day after today and recreates the reminder with this date (`CreateAlarmReminder`), then `sub_1003098`;
- then WNF 0x418A063EA3BC3075 = index.

**UpdateLockAndStartInfo / TimeChanged** (`UpdateLockAndStartInfo_or_TimeChanged`, 0x10026EC, loop `sub_10025E4`): for every enabled slot:
- alarm time in the past: `UpdateLockAndStartInfo` handles it as dismissed (`sub_10032EC`); `TimeChanged` leaves it;
- repeating alarm more than one day in the future (the clock went back): rescheduled with `sub_10034C4`.

Then `sub_1003098`.

**Next alarm update** (`sub_1003098`): `sub_10035B8` looks for the next ring time among the enabled slots (today's or tomorrow's date for one-time alarms, next selected day for repeating ones), then `sub_1003ED0(next or NULL)` updates the Start tile and the lock screen (see [Start tile](#start-tile-and-lock-screen)).

### Shell_CreateReminder parameters

`CreateAlarmReminder` (0x1003B2C) calls `Shell_CreateReminder(hReminders, &reminder, &launch)`. The reminder is a 0xA8-byte structure on the stack, zeroed except:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 16 | GUID of the slot | Reminder ID |
| 0x10 | 4 | 0x200 if the alarm is disabled, else 0 | Flags ? |
| 0x14 | 4 | 1 | ? |
| 0x18 | 16 | +0x004 with seconds and milliseconds = 0 | `SYSTEMTIME`, ring time |
| 0x28 | 16 | Same | `SYSTEMTIME`, second time (snooze / original time ?) |
| 0x38 | 4 | `L"Alarms"` | Category / application name ? |
| 0x3C | 4 | → +0x014 | Name of the alarm |
| 0x40 | 4 | → `L"<time>\n<name>"` | Text shown: `GetTimeFormatW(LOCALE_USER_DEFAULT, TIME_NOSECONDS, …)` then `"%s\n%s"` (`sub_10041AC`, max 0x182 chars) |
| 0x44 | 4 | → +0x118 | Sound file |
| 0x48 | 4 | → +0x328 | Custom data (version, days, snooze) |
| 0x4C | 4 | 8 | Size of the custom data |
| 0x50 | 4 | 5 | Structure version (see [ReminderEvents.dll](../libraries/reminderevents.md#reminder-data)) |

The launch structure is 5 DWORDs:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | `L"c:\Programs\Alarms\Alarms_NoUI.exe"` | Program started when the reminder is dismissed |
| 0x04 | 4 | `L"c:\Programs\Alarms\Alarms_NoUI.exe ReminderDismissed <index>"` | Command line (`"%s %s %d"`, max 0x104 chars) |
| 0x08 | 12 | 0 | ? |

`Shell_CreateReminder` packs the two structures (the launch structure lands at 0xA8…0xBB of the WNF data) and creates a Task Scheduler task named `_Reminder_`, see [ShellChromeAPI.dll](../libraries/shellchromeapi.md#reminders). After the creation, the GUID of the slot is published in the WNF state 0x418A063EA3BCF075.

`Shell_GetReminderData(hReminders, &guid, &pData)` returns the same layout (offsets 0x18, 0x3C, 0x44, 0x48/0x4C are read back), plus fields set by the shell: 0xBC = enabled (→ +0x324), 0xC0 = 16-byte `SYSTEMTIME` (next ring time ? compared with the current time by `TimeChanged`). A custom data blob of 1 byte (older format ?) is accepted: it's the days mask, with snooze = 10. The data is released with `Shell_ReleaseReminderData(hReminders, pData)`.

### Start tile and lock screen

`sub_1003ED0(const SYSTEMTIME *next)` (0x1003ED0):
1. Gets the tile `L"Default"` of the application `{5B04B775-356B-4AA0-AAF8-6491FFEA560A}` (product ID of Alarms) through the PacMan client (`off_1009248` method +0x28, `sub_10054D8`).
2. If there is a next alarm: string 105 of `AlarmsRes.dll`; if it rings within 24 hours, its time (`GetTimeFormatW`, `TIME_NOSECONDS`), else string 119. Without alarm: empty string and string 119.
3. Sets the two strings in the tile properties 0x1000F and 0x10004 (tile vtable +0x34, then property vtable +0x14 with a `BSTR`), and saves the tile (`off_1009270` method +0x10, `sub_1004FE4`).
4. `Shell_SetLockScreenAlarmIndication(next != NULL)`.

The strings are read with `LoadStringW(hRes, id, &ptr, 0)` (pointer into the resource) from `AlarmsRes.dll`, loaded once with `LoadLibraryExW(L"AlarmsRes.dll", NULL, LOAD_LIBRARY_AS_DATAFILE)` (`sub_100737C`). The meaning of the two tile properties is unknown (`PacMan` isn't analysed).

### COM

The PacMan client creates its interfaces on demand with `CoCreateInstance(CLSID {B9E511FC-E364-497A-A121-B7B3612CEDCE}, NULL, CLSCTX_ALL (0x17), IID, …)` (one exception, `sub_1005C10`):

| Function | IID |
|----------|-----|
| `sub_100518C` (used to get the tile) | `{698D57C2-292D-4CF3-B73C-D95A6922ED9A}` |
| `sub_1004ED0` (used to save the tile) | `{D622EEDE-5363-41FC-91C3-88E321191A34}` |
| `sub_1005A0C` | `{D83400E1-A7A6-4990-9B84-10490AFF2063}` |
| `sub_1005C10` | `{095BF7A5-F134-42B9-A4B0-7C5F1A9E199A}` (with CLSID `{D0DF0C7D-33BF-4E04-9B11-B1D7AE572EED}`, not the PacMan one) |
| `sub_1005D78` | `{75E430A7-9559-4828-98DD-BC657620AB87}` |
| `sub_1006358` | `{11ED725B-8820-45F8-96E6-6845524E46DA}` |
| `sub_100650C` | `{35F785FA-1979-4A8B-BC8F-FD70EB0D1544}` |
| `sub_1007094` | `{D29905F5-BAA2-48C5-A98A-F0DC7E122B84}` |

Only the first two are used by the alarm code; the others belong to the linked library. If `PacManMock.dll` can be loaded (`sub_1004CC8`), its exports `CreatePacManMockInterfaces`, `GetSampleLegacyApplications`, `GetSampleModernApplications`, `GetSampleLegacyTiles`, `GetSampleModernTiles`, `AddApplicationsToDatabase`, `AddModernApplicationsToDatabase`, `AddTilesToDatabase`, `AddModernTilesToDatabase`, `OpenIPCEntryPoint`, `CloseIPCEntryPoint` replace `CoCreateInstance` (test hook, the DLL isn't on a retail phone ?).

### WNF states

Published with `RtlPublishWnfStateData(name, NULL, buffer, size, NULL)`. Decoded by XOR with 0x41C64E6DA3BC0074 (as in [wppower.sys](../drivers/wppower.md#wnf-states)): version 1, well-known, system scope, not permanent, owner tag `SHL`.

| Name | Owner, sequence | Data |
|------|-----------------|------|
| 0x418A063EA3BC3075 (`.text:0x10013A4`) | `SHL`, 6 | 4 bytes: index of the slot that changed (create, enable/disable, dismiss) |
| 0x418A063EA3BCF075 (`.text:0x1001464`) | `SHL`, 30 | 16 bytes: GUID of the reminder just created |

The symbolic names (`WNF_SHL_...`) are unknown. A failure of the publication is returned as the HRESULT with bit 28 set. The same two states are published by [AlarmsSettingHandler.dll](../libraries/alarmssettinghandler.md#wnf-states) when it restores alarms.

### ETW

| Provider GUID | Registered by | Comment |
|---------------|---------------|---------|
| `{8373B2DE-90B7-4C65-BED5-D1B1F86C8DAF}` | `wmain` (`sub_10023E4`, context `unk_1009010`) | Alarms_NoUI events: command, result, reminder create/delete/state (enable bits 1, 2, 4 in `dword_1009600`) |
| `{B55B0DE9-E22B-4201-ACF8-974585BE7935}` | PacMan client init (`sub_1004AD4`) | Events of the PacMan client library (also linked in [AlarmsSettingHandler.dll](../libraries/alarmssettinghandler.md#etw)) |

Both use the enable callback `ETW_EnableCallback` (0x1002304), the standard manifest-based provider callback.
