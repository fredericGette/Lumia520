## AlarmsSettingHandler.dll

The backup / restore handler of the "Alarms" application of Windows Phone 8.1: it turns the alarms and the custom ringtones they use into "settings" that the system backup can save, and recreates them from a backup.  
`AlarmsSettingHandler.dll` is an in-process COM server (114 688 bytes, 567 functions, ATL). It has a single class, `{0FA7A163-646C-4909-86B2-50F4A31E41D3}`, that implements three Windows Phone interfaces (enumerate / get / apply a setting, begin / end of a session, read the content of a file setting). Each alarm is a setting named `Alarm-<slot>` whose value is a serialized property store (`AlarmTime`, `DisplayName`, `SoundName`, `IsActive`, `ActiveDays`, `SnoozeTime`). Each sound file is a setting named `<display name>-SoundFile-<file name>`, whose content is read and written by another setting handler of the system (a generic "folder" handler, CLSID `{C0AB2A0D-F2D2-46E2-9DF9-8885A424C29A}`). To restore an alarm, it impersonates the `Alarms` chamber and recreates the shell reminder itself: it statically links the same alarm library as [Alarms_NoUI.exe](../applications/alarms_noui.md) (32 slots, `Shell_CreateReminder`, WNF states, Start tile and lock screen update, PacMan client).  
The process that loads it (the backup service / settings sync engine ?) and the names of the interfaces are unknown. The other binaries of the same folder: [Alarms.exe](../applications/alarms.md), [Alarms_NoUI.exe](../applications/alarms_noui.md), [ReminderEvents.dll](./reminderevents.md), `AlarmsRes.dll` (localized strings).

Location on the phone: `C:\Programs\Alarms\AlarmsSettingHandler.dll` ? (extracted with `Alarms.exe` and `Alarms_NoUI.exe`, whose path `c:\Programs\Alarms\Alarms_NoUI.exe` is also a string of this DLL).  

### Imports

| DLL | Functions |
|-----|-----------|
| [ShellChromeAPI.dll](./shellchromeapi.md) | `Shell_InitReminders`, `Shell_DeInitReminders`, `Shell_CreateReminder`, `Shell_GetReminderData`, `Shell_ReleaseReminderData`, `Shell_DeleteReminder`, `Shell_SetLockScreenAlarmIndication` |
| SecRuntime.dll | `GetChamberSidFromId`, `CreateTokenFromChamberSid`, `CreateProcessInChamber` |
| ntdll.dll | `RtlPublishWnfStateData` |
| PROPSYS.dll | `PSCreateMemoryPropertyStore`, `PSPropertyBag_WriteStr`, `PropVariantToStringAlloc`, `PropVariantToFileTime`, `PropVariantToBoolean`, `InitPropVariantFromFileTime` |
| SHCORE.dll | `SHCreateMemStream`, `IStream_Reset` |
| WPCOREUTIL.dll | `SHGetKnownFolderPath` |
| OLEAUT32.dll | `SysAllocString`, `SysFreeString`, `SysStringLen`, `VariantInit`, `VariantClear`, `SystemTimeToVariantTime` |
| ZTrace.dll | `ZTraceReportOriginationNoThis`, `ZTraceReportPropagationNoThis` |
| api-ms-win-core-com-l1-1-1.dll | `CoCreateInstance`, `CoInitializeEx`, `CoUninitialize`, `CLSIDFromString`, `CoTaskMemAlloc`, `CoTaskMemRealloc`, `CoTaskMemFree`, `PropVariantClear` |
| api-ms-win-core-registry-l1-1-0.dll | `RegGetValueW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegLoadMUIStringW`, `RegCloseKey` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `FindFirstFileW`, `FindNextFileW`, `FindClose`, `GetFileSize`, `GetFileSizeEx`, `GetFullPathNameW`, `GetFinalPathNameByHandleW`, `CompareFileTime` |
| api-ms-win-core-shlwapi-legacy-l1-1-0.dll | `PathFileExistsW`, `PathFindFileNameW`, `PathMatchSpecW`, `PathGetCharTypeW` |
| api-ms-win-core-processthreads-l1-1-2.dll | `SetThreadToken`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-security-base-l1-2-0.dll | `RevertToSelf` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetLocalTime`, `GetSystemTime` |
| api-ms-win-core-timezone-l1-1-0.dll | `FileTimeToSystemTime`, `SystemTimeToFileTime`, `SystemTimeToTzSpecificLocalTime` |
| api-ms-win-core-datetime-l1-1-1.dll | `GetTimeFormatW` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `FreeLibrary`, `GetProcAddress`, `LoadStringW`, `DisableThreadLibraryCalls`, `GetModuleHandleExW`, `GetModuleFileNameA` |
| api-ms-win-core-string-l1-1-0.dll, api-ms-win-core-string-obsolete-l1-1-0.dll, api-ms-win-shcore-obsolete-l1-1-0.dll | `MultiByteToWideChar`, `WideCharToMultiByte`, `GetStringTypeW`, `lstrcmpiW`, `SHStrDupW` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `InitializeCriticalSectionEx`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `InitOnceBeginInitialize`, `InitOnceComplete`, `Sleep` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-debug-l1-1-1.dll | `DebugBreak` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memset`, `wcslen`, `wcsstr`, `wcsncmp`, `_wcsnicmp`, `swscanf_s`, `_wtol`, `_vsnwprintf`, … (CRT, C++ exceptions, `std::` containers and locale) |

The msvcrt, rtlsupport, util, processthreads (except `SetThreadToken`), errorhandling and debug imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code. `ZTrace.dll` and the `StringRes::*`, `SoundSettings_*`, `MyRegistry*` strings come from shared helper code (resource strings, sound settings).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `c:\Programs\Alarms\Alarms_NoUI.exe` | `CreateProcessInChamber` without argument ([BeginSession](#beginsession-sub_10006478)); program and command line of the restored alarm reminders (`CreateReminder`) | See [Alarms_NoUI.exe](../applications/alarms_noui.md#parameters) |
| `AlarmsRes.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)` (`sub_10010D7C`, name set by `LoadAlarms`, `sub_1000D2A0`) | Localized strings of the Alarms tile (see [Alarm library](#alarm-library)) |
| `SoundsRes.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)` (`sub_10011CC8`) | Display names of the built-in sound files |
| `PacManMock.dll` | `LoadLibraryExW` + `GetProcAddress` (`sub_1000E7A0`) | Test replacement of the PacMan COM client (same library as in [Alarms_NoUI.exe](../applications/alarms_noui.md#com)) |
| Sound files of the ringtones folders (`{E555AB60-…}`, `{C870044B-…}`) and of `HKLM\Software\Microsoft\EventSounds\Sounds\<category>\Sound` | `FindFirstFileW(<folder>\*.*)` (`sub_1001270C`), `CreateFileW` (`sub_1000601C`, `_VerifyRingtoneInternal` `sub_10011A88`, `sub_10012038`) | Backed up / restored with their content (see [EnumerateSettings](#enumeratesettings-sub_10007084), [GetFileContent](#getfilecontent-sub_10005d50)) |
| Setting item factory, CLSID `{3F66CF3F-68BE-485E-8BFE-0A005B2D00F2}` | `CoCreateInstance` (`sub_10007D6C`) | Setting items given to the backup engine (server DLL unknown) |
| Folder handler, CLSID `{C0AB2A0D-F2D2-46E2-9DF9-8885A424C29A}` | `CoCreateInstance` (`CreateFolderHandler`, `sub_10007DA0`) | Ringtones folder of the backup session (server DLL unknown) |
| Metadata parser, CLSID `{9E164D20-64A5-411E-B690-880DD2C6D5D9}` | `CoCreateInstance(CLSCTX_INPROC_SERVER)` (`MetadataParserLoader::GetMetadataMunger`, `sub_10012348`) | Reads the metadata of a ringtone file when it's verified (server DLL unknown) |
| PacMan server, CLSID `{B9E511FC-E364-497A-A121-B7B3612CEDCE}`, and `{D0DF0C7D-33BF-4E04-9B11-B1D7AE572EED}` | `CoCreateInstance` (PacMan client library) | Alarms tile, as in [Alarms_NoUI.exe](../applications/alarms_noui.md#com) |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x10005114 | none |
| 2 | `DllGetClassObject` | 0x10005134 | `REFCLSID`, `REFIID`, `void **` |

The standard ATL exports: `DllGetClassObject` searches the ATL object map (0x10015194, one entry at 0x10016068) and returns the class factory (`sub_10005220`, created once under the critical section `unk_10016510`). `CLASS_E_CLASSNOTAVAILABLE` (0x80040111) for another CLSID, `E_UNEXPECTED` if the module failed to initialise. There's no `DllRegisterServer`: the class is registered by the phone image.

| CLSID | Creator | Interfaces (QI table 0x10001540) |
|-------|---------|----------------------------------|
| `{0FA7A163-646C-4909-86B2-50F4A31E41D3}` | `sub_100052D4` (`CComObject`, 0x8C bytes, or `CComAggObject`, 0x98 bytes, when aggregated) | `{6A01F55B-4AA5-444B-8CA5-56FF9401A730}` (offset 0), `{22FFBB0C-954E-47E9-86EE-F94FB719D76B}` (offset 4), `{9F3B31DF-CE39-4DA3-A2F0-F240C1E10F06}` (offset 8) |

The handler object (constructor `sub_10005BE0`, destructor `sub_10005C64`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable of `{6A01F55B-…}` (`off_100013D8`): settings |
| 0x04 | 4 | vtable of `{22FFBB0C-…}` (`off_100013C4`): session |
| 0x08 | 4 | vtable of `{9F3B31DF-…}` (`off_100013B4`): file content |
| 0x0C | 4 | Reference count |
| 0x10 | 0x18 | Critical section (initialised flag at 0x28) |
| 0x2C | 4 | Setting item factory: `CoCreateInstance({3F66CF3F-68BE-485E-8BFE-0A005B2D00F2}, CLSCTX_ALL, {67F82BE4-31CE-4CFF-9599-D61DA7E3B639})`, created on first use (`sub_10007D6C`) |
| 0x30 | 4 | Folder setting handler (`{C0AB2A0D-…}`, interface `{6A01F55B-…}`), created by `BeginSession` |
| 0x34 | 0x44 | `STARTUPINFOW` for `CreateProcessInChamber` |
| 0x78 | 16 | `PROCESS_INFORMATION` (the two handles are closed by `EndSession` and the destructor) |
| 0x88 | 4 | Set to 1 when an alarm is restored: `EndSession` then checks the sound files |

The path of the ringtones folder is a global (`dword_10016828`, `CoTaskMemFree` in the destructor).

### Startup

`start` (`_DllMainCRTStartup`, 0x10012F30): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then `dllmain_dispatch` (`sub_10012C3C`: CRT init with `_initterm`, which also initialises the ATL module `sub_10004E2C`, then `DllMain`).  
`DllMain` (`sub_100050C8`) registers the ETW provider `{FFEF6934-…}` and calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH` (fails if the ATL module failed), and unregisters the provider on `DLL_PROCESS_DETACH`.

### Interfaces

The interfaces are Windows Phone private ones, their names are unknown. The method names below are descriptive.

| Interface | Vtable slot | Function | Use |
|-----------|-------------|----------|-----|
| `{6A01F55B-…}` | 3 | `ApplySetting` (`sub_10006F88`) | Restore one setting from the backup |
| | 4 | `GetSetting` (`sub_10007CC8`) | Build the setting item of a name (backup) |
| | 5 | `EnumerateSettings` (`sub_10007084`) | List all the settings to back up |
| | 6 | `sub_10007074` | `E_NOTIMPL` |
| `{22FFBB0C-…}` | 3 | `BeginSession` (`sub_10006478`) | Start of a backup / restore |
| | 4 | `EndSession` (`sub_100064DC`) | End: fixes the alarms after a restore |
| `{9F3B31DF-…}` | 3 | `GetFileContent` (`sub_10005D50`) | Content of a `-SoundFile-` setting |

The folder handler `{C0AB2A0D-…}` implements the same interfaces: the DLL calls its `ApplySetting` (+0x0C), `GetSetting` (+0x10) and its `{9F3B31DF-…}` method. The setting items exchanged with the caller are COM objects with (vtable offsets): +0x0C name (string, freed with `CoTaskMemFree`), +0x10 value as an `IStream`, +0x14 an 8-byte value (timestamp ?), +0x18 a DWORD (see [Alarm setting](#alarm-setting)). They're created by the factory at +0x2C: method +0x0C (`name, stream, 0, 1, 0, &item`) for an alarm, +0x14 (`name, &value8, content provider, dword, 0, &item`) for a file. The collection returned by `EnumerateSettings` is a local object (`sub_10011480`, vtable `off_100022D8`, interface `{5632B1A4-E38A-400A-928A-D4CD63230295}`, returned as `{92CA9DCD-5622-4BBA-A805-5E9F541BD8C9}`), method +0x14 = add an item.

### Setting names

Names are encoded before they're given to the caller (`EncodeName`, `sub_10011890`) and decoded when they're received (`DecodeName`, `sub_10011994`): every character that isn't valid in a file name (`PathGetCharTypeW` without `GCT_LFNCHAR`) is replaced by `-` and a code letter (table `sub_100117D8`), `-` itself included. Names are limited to 256 characters (`0x8007007A`); an unknown escape gives `0x8007007B` and ETW event 900 / 901.

| Decoded name | Setting |
|--------------|---------|
| `Alarm-<slot>` (`wcsncmp` 6 characters) | An alarm, slot 0…31 (decimal) |
| `<display name>-SoundFile-<file name>` (`wcsstr`) | A sound file of the ringtones folder |
| Anything else | `E_UNEXPECTED` (0x8000FFFF) |

### BeginSession (sub_10006478)

Does nothing (returns `S_OK`) unless bit 3 (0x08) of `flags` is set (`this` = object + 4). Then, stopping at the first failure:

1. Starts `c:\Programs\Alarms\Alarms_NoUI.exe` with `CreateProcessInChamber` (no command line; startup / process information stored in the object).
2. Gets the ringtones folder with `SHGetKnownFolderPath(FOLDERID_{E555AB60-153B-4D17-9F04-A5FE99FC15EC})` into a global.
3. Creates the folder handler for that folder with `CreateFolderHandler` (`sub_10007DA0`) and returns its HRESULT.

`Alarms_NoUI.exe` is started without argument: it does nothing (see [Alarms_NoUI.exe](../applications/alarms_noui.md#parameters)), the purpose is probably to make the `Alarms` chamber exist before the impersonation ?. The meaning of the other flag bits is unknown.  
`CreateFolderHandler` (`sub_10007DA0`): `CoCreateInstance({C0AB2A0D-F2D2-46E2-9DF9-8885A424C29A}, NULL, CLSCTX_ALL, {6A01F55B-…})`, a memory property bag (`PSCreateMemoryPropertyStore(IID_IPropertyBag)`) with `FolderFullPath` = the folder, then `IPersistPropertyBag::Load(bag)` on the handler.

The known folder `{E555AB60-…}` is `FOLDERID_PublicRingtones` and `{C870044B-F49E-4126-A9C3-B52A1FF411E8}` (used below) is `FOLDERID_Ringtones` in the desktop SDK; their paths on the phone are unknown.

### EnumerateSettings (sub_10007084)

1. Creates the collection, loads the 32 alarm slots (`LoadAlarms`, `sub_1000D2A0`, see [Alarm library](#alarm-library)).
2. Lists the files of the ringtones folder (`sub_1001270C`: `FindFirstFileW(<folder>\*.*)`, callback `sub_10005F08`): files matching `*.wma`, `*.mp3` or `*.m4r` (`sub_10011A88`, `PathMatchSpecW`) are kept.
3. For each existing slot: name `Alarm-<slot>` → `GetSetting` → add to the collection. The sound of the alarm is kept if it's in `{E555AB60-…}` or `{C870044B-…}`, not in `{C870044B-…}`, and exists.
4. Same for the default sound of 6 event categories: `HKLM\Software\Microsoft\EventSounds\Sounds\<category>`, value `Sound` (`REG_SZ`, `sub_10012880`), category = `Ringtone`, `IM`, `sms`, `SMSNudge`, `voicemail`, `reminder` (table 0x10001C8C).
5. The list is checked (`sub_1000601C`: `CreateFileW`, `GetFileSizeEx`, duplicates removed ?), then for each file: display name (`SoundSettings_GetDisplayNameForSoundFile`, `sub_10011CC8`: from the registry with `RegLoadMUIStringW` or from the resources of `SoundsRes.dll`), name `<display name>-SoundFile-<path relative to the folder>` → `GetSetting` → add.
6. Returns the collection.

### GetSetting (sub_10007CC8)

`GetSetting(name, &item)` decodes the name and calls:

- **Alarm** (`sub_100078E8`): `_wtol(name + 6)` = slot, `LoadAlarms`, `GetAlarm(slot, &rec)` (`sub_1000D61C`, `Shell_GetReminderData`). It fills a memory property store (`PSCreateMemoryPropertyStore(IID_INamedPropertyStore)`) with the values of the [Alarm setting](#alarm-setting), saves it with `IPersistStream::Save` in a memory stream (`SHCreateMemStream`), rewinds it, and creates the item with the factory (`name, stream, 0, 1, 0`).
- **Sound file** (`sub_10007BC0`): `GetSetting(<file name>)` of the folder handler, reads its +0x14 and +0x18 values, then creates an item with the factory method +0x14, with the original name and `this + 8` (`{9F3B31DF-…}`) as content provider.

### GetFileContent (sub_10005D50)

`GetFileContent(name, &out)` (`{9F3B31DF-…}` method 3): decodes the name, takes the part after `-SoundFile-`, gets `{9F3B31DF-…}` of the folder handler and forwards the call with the encoded file name. `E_INVALIDARG` if the name has no `-SoundFile-`.

### ApplySetting (sub_10006F88)

`ApplySetting(item)`: gets and decodes the name of the item (+0x0C), then restores it; ETW event 902 with the name if it fails. Returns `E_INVALIDARG` if `item` is NULL.

**Alarm** (`sub_10006634`):

1. Sets `alarmRestored` (+0x88) in the object and reads the "local time" flag of the item (+0x18).
2. Gets the current local time as a `FILETIME` (`GetLocalTime` + `SystemTimeToFileTime`).
3. Parses the index from the name after the 6-character prefix (`swscanf_s(L"%u")`, `E_INVALIDARG` if it isn't a number).
4. Gets the stream of the item (+0x10), loads it into a memory property store (`PSCreateMemoryPropertyStore(IID_IPersistStream)` + `Load`) and queries `INamedPropertyStore`.
5. Fills the alarm record from the named properties: `DisplayName` (max 130 characters), `SoundName` (max 262 characters), `AlarmTime` (`FILETIME`, converted from UTC with `SystemTimeToTzSpecificLocalTime` when the item isn't local), `IsActive`, `ActiveDays`, `SnoozeTime`.
6. If the alarm time has already passed: a repeating alarm (`ActiveDays & 0x7F`) gets tomorrow's date, a one-time alarm is disabled.
7. Impersonates the Alarms chamber (`ImpersonateAlarmsChamber`, `sub_10005CEC`), loads the alarms (`LoadAlarms`, `sub_1000D2A0`), adds the record (`AddAlarm`, `sub_1000D52C`), then `RevertToSelf`.

`ImpersonateAlarmsChamber` (`sub_10005CEC`): `GetChamberSidFromId(L"Alarms", &sid)`, `CreateTokenFromChamberSid(sid, 2, &token)`, `SetThreadToken(NULL, token)`: the reminders are created with the identity of the Alarms application.

**Sound file** (`sub_10006CD4`): the part before `-SoundFile-` (max 260 characters) is the display name, the part after is the file name.
1. Creates an item for the file name with the factory (method +0x14, with the +0x14 / +0x18 values of the received item) and gives it to `ApplySetting` of the folder handler, which writes the file.
2. Registers the file as a custom ringtone (`SoundSettings_RestoreCustomRingtoneRegistry`): full path `"%s\%s"` (ringtones folder, file name); if the path is in `{C870044B-…}` (`IsKnownFolder`, `sub_100121B8`, case-insensitive prefix comparison of the final paths) the key is `HKLM\Software\Microsoft\Shell\Sounds\CustomProtectedRingtones`, else `HKLM\Software\Microsoft\Shell\Sounds\CustomRingtones`. Value name = file name, data = display name (`REG_SZ`, `MyRegistrySetString`, `sub_100125C4`).

### EndSession (sub_100064DC)

If an alarm was restored (+0x88): reads the default alarm sound (`HKLM\Software\Microsoft\EventSounds\Sounds\Alarm`, value `Sound`), impersonates the `Alarms` chamber, loads the slots, and for every alarm whose sound file doesn't exist (`PathFileExistsW`), isn't empty and isn't `*vibrate*` (`lstrcmpiW`), sets the default sound and updates the alarm (`UpdateAlarm`, `sub_1000D714`). Then `RevertToSelf`. In all cases it closes the two handles of `Alarms_NoUI.exe`.

### Alarm setting

The value of an `Alarm-<slot>` setting is an `INamedPropertyStore` saved with `IPersistStream`:

| Property | Type | Slot record field (see [Alarms_NoUI.exe](../applications/alarms_noui.md#alarm-slots)) |
|----------|------|------------------------------------|
| `AlarmTime` | `VT_FILETIME` | +0x004 `SYSTEMTIME`, local time |
| `DisplayName` | `VT_LPWSTR` | +0x014 name |
| `SoundName` | `VT_LPWSTR` | +0x118 sound file |
| `IsActive` | `VT_BOOL` | +0x324 enabled |
| `ActiveDays` | `VT_UI1` (0x11) | +0x329 repeat days (bit 0 = Monday … bit 6 = Sunday) |
| `SnoozeTime` | `VT_UI4` (0x13) | +0x32C snooze time (minutes ?) |

On restore, a property with another type gives `E_UNEXPECTED`, a missing one `0x80070490` (`ERROR_NOT_FOUND`); `ActiveDays` and `SnoozeTime` are optional (0 if missing). The item DWORD (+0x18) is 1 when the item is created by `GetSetting`; when it's 0, `AlarmTime` is taken as UTC and converted to local time ?

### Alarm library

The same code as in [Alarms_NoUI.exe](../applications/alarms_noui.md), linked in the DLL (manager object of `LoadAlarms`: slot list at +0x18, `Shell_InitReminders` handle at +0x28, PacMan client at +0x2C):

| Function | Equivalent in Alarms_NoUI.exe |
|----------|-------------------------------|
| `LoadAlarms` (`sub_1000D2A0`): `AlarmsRes.dll` as string resource DLL, `Shell_InitReminders`, PacMan client init (`sub_1000E5AC`, `CoInitializeEx(NULL, COINIT_MULTITHREADED)`), `GetAlarm` for the 32 slots | `sub_1002EA0` |
| `GetAlarm` (`sub_1000D61C`, via `sub_1000CDDC`: `Shell_GetReminderData` / `Shell_ReleaseReminderData`) | `sub_1003CEC` |
| `CreateReminder` (0x1000CC30): same [Shell_CreateReminder parameters](../applications/alarms_noui.md#shell_createreminder-parameters) (slot GUID table at 0x10016090, `L"Alarms"`, `"%s\n%s"`, `Alarms_NoUI.exe ReminderDismissed <slot>`), then WNF 0x418A063EA3BCF075 = slot GUID | `CreateAlarmReminder` |
| `AddAlarm` (`sub_1000D52C`): moves a repeating alarm to its first selected day, `CreateReminder`, adds the record, updates tile and lock screen (`sub_1000D4E8`) | `sub_10030DC` |
| `UpdateAlarm` (`sub_1000D714`): same day adjustment, `Shell_DeleteReminder` (`sub_1000CEF0`), `CreateReminder`, replaces the record, tile / lock screen, WNF 0x418A063EA3BC3075 = slot index | `sub_100338C` |
| `sub_1000D4E8` → `sub_1000CF48`: tile `Default` of `{5B04B775-356B-4AA0-AAF8-6491FFEA560A}` (strings of `AlarmsRes.dll`, `GetTimeFormatW`), `Shell_SetLockScreenAlarmIndication` | `sub_1003098` → `sub_1003ED0` |

The PacMan COM client (0x1000E9A8…0x10010CF4, `PacManMock.dll` test hook) is the same library as in Alarms_NoUI.exe.

### WNF states

Published with `RtlPublishWnfStateData(name, NULL, buffer, size, NULL)` by the alarm library, as in [Alarms_NoUI.exe](../applications/alarms_noui.md#wnf-states):

| Name | Owner, sequence | Data | Published by |
|------|-----------------|------|--------------|
| 0x418A063EA3BC3075 (`.text:0x10001E5C`) | `SHL`, 6 | 4 bytes: slot index | `UpdateAlarm` (`EndSession`) |
| 0x418A063EA3BCF075 (`.text:0x10001E10`) | `SHL`, 30 | 16 bytes: GUID of the reminder | `CreateReminder` (`ApplySetting` of an alarm, `EndSession`) |

Unlike `Alarms_NoUI.exe`, adding a restored alarm (`AddAlarm`) doesn't publish the slot index.

### ETW

| Provider GUID | Registered by | Comment |
|---------------|---------------|---------|
| `{FFEF6934-8D7F-41C9-A33F-0BDD2AE8887C}` | `DllMain` (context `unk_10016030`, enable bits in `dword_10016800`) | Setting handler events |
| `{B55B0DE9-E22B-4201-ACF8-974585BE7935}` | PacMan client init (`sub_1000E5AC`) | Events of the PacMan client library (as in Alarms_NoUI.exe) |

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 900 | 2 (error) | 0, 11 | 0 | 0x08 | `DecodeName` failed (name, error, position) |
| 901 | 2 (error) | 0, 11 | 0 | 0x08 | `EncodeName` failed |
| 902 | 2 (error) | 0, 11 | 0 | 0x08 | `ApplySetting` failed (HRESULT, name) |

The alarm library also writes events 2000…2003 and 2006 (create / delete reminder, update alarm; level 4) when the bits of `dword_10016900` are set, but with a NULL registration handle: no provider is registered for them in this DLL, so they're never written.

### Registry

| Key (HKLM) | Value | Access |
|------------|-------|--------|
| `Software\Microsoft\EventSounds\Sounds\Alarm` | `Sound` (`REG_SZ`) | Read: default sound of a restored alarm whose file is missing |
| `Software\Microsoft\EventSounds\Sounds\{Ringtone, IM, sms, SMSNudge, voicemail, reminder}` | `Sound` (`REG_SZ`) | Read: sound files to back up |
| `Software\Microsoft\Shell\Sounds\CustomRingtones` / `CustomProtectedRingtones` | `<file name>` = display name (`REG_SZ`) | Written when a sound file is restored |
| `Software\Microsoft\Shell\Sounds\{Ringtones, Notifications, Alarms}`, `Software\Microsoft\Shell\OEM\Sounds\{Ringtones, Notifications, Alarms}`, `Software\Microsoft\Shell\MO\Sounds\Ringtones` | ? | Read by `SoundSettings_GetDisplayNameForSoundFile` (display name of a sound) ? |
