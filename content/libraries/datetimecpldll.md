## DateTimeCPLdll.dll

The user interface and the code-behind of the "date+time" settings page of Windows Phone 8.1, started by [DateTimeCPL.exe](../applications/datetimecpl.md).  
`DateTimeCPLdll.dll` is a small DLL (61 440 bytes, 228 functions, most of them CRT, STL strings and UIX object boilerplate). Its resources hold the compiled UIX markup of the whole page (`Frame.uix`, `Main.uix`, `TimeZone.uix`…). Its code is a UIX schema (exports `UIXGetSchemaFactory` / `UIXSchemaUnloaded`) that gives the markup two types: `DateTimeProvider` (automatic time and time zone, 24-hour clock, time zone, date and time) and `TimeZoneData` (one entry of the time zone list). The settings are read from and written to the registry (`HKLM\System\State\DateTime`), the locale (`SetLocaleInfoWP`) and the system clock (`SetLocalTime`, `SetTimeZoneInformationByID`), and two WNF states of the shell are published when they change.  
It's loaded by `UIXMobile.dll` (the UIX framework, not analysed): as a resource module for `res://DateTimeCPLdll!…` and as a schema for `dll://DateTimeCPLdll`. [DateTimeCPL.exe](../applications/datetimecpl.md) only passes `res://DateTimeCPLdll!Frame.uix` to `UIXMobile!RunApplication`. The localised strings come from the sibling `DateTimeCPLRes.dll` (not analysed).

Location on the phone: ? (no path in the binary; probably next to `DateTimeCPL.exe`).  

### Imports

| DLL | Functions |
|-----|-----------|
| WPGLOBUTIL.dll | `GetTimeZoneList`, `GetTimeZoneInformationID`, `SetTimeZoneInformationByID`, `SetLocaleInfoWP` |
| ntdll.dll | `RtlPublishWnfStateData` |
| api-ms-win-core-registry-l1-1-0.dll | `RegGetValueW`, `RegOpenKeyExW`, `RegLoadMUIStringW`, `RegCloseKey` |
| api-ms-win-core-registry-l2-1-0.dll | `RegSetKeyValueW` |
| api-ms-win-core-timezone-l1-1-0.dll | `GetDynamicTimeZoneInformation`, `FileTimeToSystemTime` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `SetLocalTime` |
| api-ms-win-core-localization-l1-2-1.dll | `GetLocaleInfoW` |
| api-ms-win-core-localization-l2-1-0.dll | `EnumTimeFormatsEx` |
| api-ms-win-core-processthreads-l1-1-2.dll | `OpenProcessToken`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-security-lsalookup-l2-1-1.dll | `LookupPrivilegeValueW` |
| api-ms-win-security-base-l1-2-0.dll | `AdjustTokenPrivileges` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalAlloc`, `LocalFree` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSectionEx`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`, `Sleep` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleW`, `GetProcAddress` |
| api-ms-win-core-debug-l1-1-1.dll | `OutputDebugStringW` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memmove`, `memset`, `memcmp`, `wcslen`, `wcscmp`, `wcschr`, `wcsstr`, `qsort`, `swprintf_s`, … (CRT, `_initterm`, C++ exceptions) |

The msvcrt, rtlsupport, errorhandling, `TerminateProcess` and `Sleep` imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code. `GetModuleHandleW` / `GetProcAddress` / `OutputDebugStringW` / `RaiseException` are only used by the [out-of-memory handler](#out-of-memory).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `UIXMobile.dll` | Host: calls `UIXGetSchemaFactory` (`dll://DateTimeCPLdll` in the markup) and loads the `res://DateTimeCPLdll!…` resources | UIX framework running the page; its object passed to `UIXGetSchemaFactory` is used to create strings and to signal property changes |
| `UIXMobile.dll` resources | `res://UIXMobile!PageStack.uix`, `Frame.uix`, `Page.uix`, `Button.uix`, `List.uix`, `PickerBox.uix`, `PopupControl.uix`, `ToggleSwitch.uix`, `Styles.uix`, `DatePicker.uix`, `TimePicker.uix`, `dll://UIXMobile` (in `_DataTable.uib`) | Standard controls used by the markup |
| `DateTimeCPLRes.dll` | `res://DateTimeCPLRes!SplashStrings.uix` (in `_DataTable.uib`) | Localised strings `IDS_TITLE_LABEL`, `IDS_AUTOSET_LABEL`, `IDS_24_LABEL_ON_TEXT`… (`Resources.LoadString`) |
| `SettingsAssets{ScreenResolution}` (`SettingsAssets<resolution>.dll` ?) | `res://SettingsAssets{ScreenResolution}!Constants.uix` (in `_DataTable.uib`) | Layout constants of the settings pages, chosen by screen resolution |
| `emclient.dll` | `GetModuleHandleW` + `GetProcAddress("SHTerminateProcessForOOM")` | Called before terminating the process when out of memory, only if already loaded |

No DLL is loaded with `LoadLibrary`, no process or COM server is started, and no file is opened.

### Resources

Type 10 (`RT_RCDATA`), language 1033. All are compiled UIX (`UIB` signature); each markup file refers to the common string / symbol table `res://DateTimeCPLdll!_DataTable.uib`.

| Name | Size | Content |
|------|------|---------|
| `FRAME.UIX` | 278 | Root markup passed by [DateTimeCPL.exe](../applications/datetimecpl.md#runapplication-parameter) (`MainFrame`, page stack, `Home`) |
| `DIRECTORY.UIX` | 302 | `DateTimeCPLDirectory`, `DestinationToUIMap`: maps the page names to `res://DateTimeCPLdll!Main.uix#Default` |
| `MAIN.UIX` | 3232 | The page: `HourToggle`, `AutoSetToggle`, `AutoSetTimeZoneToggle`, `TimeZoneButton`, `DatePicker`, `TimePicker`, `ManualPanel`, a `MinuteTimer` |
| `TIMEZONE.UIX` | 1161 | `TimeZonePicker`: list of `TimeZoneData` (`Display`, `GMT`), `SelectedTimeZoneId` |
| `DATATYPE.UIX` | 1190 | Data types of the markup (`TimeZoneItemType` ?) |
| `STYLES.UIX` | 432 | Margins (`DateTimeCPLSecondaryPanelMargins`, `DateTimeCPLDockPanelMargins`, …) |
| `_DATATABLE.UIB` | 7558 | Names, URIs and string IDs used by the markup files |

The markup uses the names of the schema types, properties and methods below. It also contains `SetSystemDateAndTime`, which isn't a method of the schema (a markup-side method calling `SetDateAndTime` ?).

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `UIXGetSchemaFactory` | 0x10004288 | `IUnknown **factory` (out), `host` (interface of `UIXMobile.dll`) |
| 2 | `UIXSchemaUnloaded` | 0x10004340 | `DWORD` (0: unload) |

**UIXGetSchemaFactory** creates (once; a second call crashes on purpose) the schema object (28 bytes, `dword_100072E0`, built from the schema description at 0x1000149C) and a factory object (16 bytes, `dword_100072E8`) that holds a reference on it, saves `host` in `off_100072EC` and returns the factory with a reference added. Returns `E_OUTOFMEMORY` (0x8007000E) if an allocation fails, `S_OK` otherwise.  
The host object is used with two methods: vtable +8 = property changed (`sub_100045F0`, with the object and the property ID) and vtable +12 = create a string object from a `WCHAR *` (properties of type string).  
**UIXSchemaUnloaded(0)** releases the objects cached by the schema (two arrays at +0x10 and +0x14), the schema and the factory, and resets the cached type IDs (`dword_100072E4`, `dword_10007028`) to -1. Any other value does nothing.

### Schema

The description at 0x1000149C lists 2 types (table at 0x100016A4). Each type has a name, an ID, a constructor, a property getter and a method dispatcher; each property / method has a name, a type code and, for methods, the parameter types.

| ID | Type | Size | Constructor | Getter | Methods |
|----|------|------|-------------|--------|---------|
| 10 | `DateTimeProvider` (0x100015A0) | 392 | `sub_10003EF4` → `sub_10002640` | `sub_10004058` | `sub_10003F44` |
| 18 | `TimeZoneData` (0x10001648) | 480 | `sub_1000410C` → `sub_10003204` | `sub_1000415C` | none |

Type codes seen: -13 (0xFFFFFFF3, int, returned as value kind 3), -18 (0xFFFFFFEE, string, value kind 0x81), -19 (0xFFFFFFED, void), -11 (0xFFFFFFF5, list, value kind 0x80), -3 (0xFFFFFFFD, bool ?), -8 (0xFFFFFFF8, date/time as a 64-bit `FILETIME`). A constructor called with another type ID writes to address 0 (fail fast).

### DateTimeProvider

Properties (getter `sub_10004058`), all read-only. The ID passed to the host when the value changes is in the cell given (table at 0x1000141C).

| ID | Property | Type | Object field | Change ID cell | Meaning |
|----|----------|------|--------------|----------------|---------|
| 11 | `AutoSetAvailable` | int | +0x20 | `unk_1000701C` | `NetworkTime Enabled` or `NTP Enabled` is non-zero |
| 12 | `AutoSetEnabled` | int | +0x24 | `dword_10007010` | `NetworkTime Sync` (automatic time on) |
| 13 | `AutoTimeZoneSetAvailable` | int | +0x28 | `unk_10007020` | `NetworkTime Enabled` is non-zero |
| 14 | `AutoTimeZoneSetEnabled` | int | +0x2C | `unk_10007024` | `NetworkTime TimeZone Sync` (default 1) |
| 15 | `Hour24Available` | int | +0x30 | `dword_1000700C` | The locale offers both 12-hour and 24-hour time formats |
| 16 | `Hour24Enabled` | int | +0x34 | `dword_10007018` | The current time format is a 24-hour one |
| 17 | `DisplayName` | string | +0xDC | `dword_10007014` | Display name of the current time zone |

Methods (dispatcher `sub_10003F44`, switch on the ID):

| ID | Method | Parameters | Returns | Function |
|----|--------|------------|---------|----------|
| 2 | `Init` | none | void | [`sub_10002878`](#init-sub_10002878) |
| 3 | `SetNetworkTime` | `bool autoTime, bool autoTimeZone` ? | void | [`sub_10002CCC`](#setnetworktime-sub_10002ccc) |
| 4 | `ChangeTimeFormat` | none | void | [`sub_10002D70`](#changetimeformat-sub_10002d70) |
| 5 | `GetCurrentTimeZoneId` | none | int | `WPGLOBUTIL!GetTimeZoneInformationID()` |
| 6 | `GetTimeZones` | none | list of `TimeZoneData` | [`sub_100030D8`](#gettimezones-sub_100030d8) |
| 7 | `ChangeTimeZone` | `int id` | void | [`ChangeTimeZone`](#changetimezone-and-setdateandtime) |
| 8 | `SetDateAndTime` | `FILETIME` (local time) | int (`BOOL` of `SetLocalTime`) | [`sub_10002C30`](#changetimezone-and-setdateandtime) |
| 9 | `SetDisplayName` | none | void | [`sub_10002B1C`](#setdisplayname-sub_10002b1c) |

Every method returns `S_OK` to the framework; errors aren't reported.

Object (392 bytes, `sub_10002640`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable (`off_10001380`) |
| 0x08 | 0x18 | UIX object base (vtable `off_10001318`, reference count +0x0C, type handle +0x10 from `off_100072D8`) |
| 0x20…0x34 | 4 each | The six int properties above |
| 0x38 | 0xA0 | Current time format (`LOCALE_STIMEFORMAT`, 80 characters) |
| 0xDC | 0x8C | Display name of the time zone (70 characters) |
| 0x168 | 0x18 | Critical section protecting the time zone list |
| 0x180 | 4 | List of `TimeZoneData` (48-byte UIX list object, vtable `off_100013A0`; count at +0x20) |

The enumerated time formats are kept in a global array of 15 `LocalAlloc` strings (`dword_100072D0`, count `dword_100072D4`), freed by the destructor `sub_10002784`.

### Startup

`DllEntryPoint` (0x10006284): `__security_init_cookie`, then `dllmain_dispatch` (0x10005F90: CRT init with `_initterm` in `sub_10005D80`, then `DllMain`). `DllMain` (`unknown_libname_4`, 0x1000574C) only returns `TRUE`. Everything is done when the markup creates a `DateTimeProvider` and calls `Init`.

### Init (sub_10002878)

1. Reads the DWORDs `NetworkTime Enabled` and `NTP Enabled` of `HKLM\System\State\DateTime` (`RegGetValueW`, `RRF_RT_REG_DWORD`). If `NetworkTime Enabled` is 0 or missing and `NTP Enabled` can't be read, steps 2…4 are skipped.
2. `AutoSetAvailable` = one of them non-zero; then `AutoSetEnabled` = `NetworkTime Sync` != 0.
3. `AutoTimeZoneSetAvailable` = `NetworkTime Enabled` != 0; then `AutoTimeZoneSetEnabled` = `NetworkTime TimeZone Sync` != 0 (1 if missing).
4. Time formats (`sub_100029C8`): `EnumTimeFormatsEx(sub_10002978, LOCALE_NAME_USER_DEFAULT, 0, 0)` copies up to 15 formats. `Hour24Available` = 1 if one format contains `"h:"` or `"h."` (12-hour) and another one an `H` (24-hour). Then `GetLocaleInfoW(LOCALE_USER_DEFAULT, LOCALE_STIMEFORMAT)` into +0x38: `Hour24Enabled` = 0 if it contains `"h:"` / `"h."`, 1 if it contains `H`. Returns `E_OUTOFMEMORY` or `E_FAIL` on error.
5. [SetDisplayName](#setdisplayname-sub_10002b1c).

### SetNetworkTime (sub_10002CCC)

1. Writes the two arguments as 0/1 REG_DWORDs `NetworkTime Sync` and `NetworkTime TimeZone Sync` of `HKLM\System\State\DateTime` (`RegSetKeyValueW`).
2. Stores the first one in `AutoSetEnabled` and publishes it (4 bytes) in the WNF state 0x418A063EA3BDA875 (see [WNF states](#wnf-states)).
3. If the publication succeeded and `AutoSetEnabled` changed, signals the change of `AutoSetEnabled`.

`AutoTimeZoneSetEnabled` isn't updated in the object (only in the registry).

### ChangeTimeFormat (sub_10002D70)

Toggles the 24-hour clock:
1. Removes the AM/PM part (`tt`) from the current format (+0x38).
2. If `Hour24Enabled`, replaces the first two `H` by `h`, otherwise the first two `h` by `H`.
3. Looks for an enumerated format containing the result (`wcsstr`) and takes it; otherwise the first enumerated format with `"h:"` / `"h."` (to 12-hour) or with `H` (to 24-hour).
4. If no format is found, sets `Hour24Available` to 0, signals it and stops.
5. Otherwise `SetLocaleInfoWP(LOCALE_USER_DEFAULT, LOCALE_STIMEFORMAT, format)` and `SetLocaleInfoWP(LOCALE_USER_DEFAULT, LOCALE_SSHORTTIME (0x79), shortFormat)`, where the short format is built from the new one by `sub_100024DC` (seconds removed ?), then updates `Hour24Enabled` and signals it.

`SetLocaleInfoWP` is the WPGLOBUTIL version of `SetLocaleInfoW` (not analysed).

### GetTimeZones (sub_100030D8)

Under the critical section, and only the first time (list empty):
1. `GetTimeZoneList(NULL, 0)` returns the number of time zones; a buffer of `count × 444` bytes is filled by `GetTimeZoneList(buffer, count)` (WPGLOBUTIL).
2. `qsort` with `sub_100030AC`: by decreasing bias (record +4: west to east), then by display name (`wcscmp` on record +0xB0).
3. For each record, a `TimeZoneData` is created, the 444 bytes are copied at its +0x20, and it's added to the list (+0x180).

Returns the list (a reference is added). The list isn't refreshed later.

### TimeZoneData

Object of 480 bytes (`sub_10003204`): the UIX object base (+0x00…+0x1F, type handle from `off_100072DC`), then the 444-byte record of `GetTimeZoneList` at +0x20:

| Offset (record) | Size | Comment |
|-----------------|------|---------|
| 0x00 | 4 | Time zone ID (the ID of `GetTimeZoneInformationID` / `SetTimeZoneInformationByID`) |
| 0x04 | 4 | Bias (minutes ?, sort key) |
| 0xB0 | 2 × 70 | Display name, `"(GMT±hh:mm) City…"` ? (only the first 70 characters are used) |
| other | | ? |

Properties (getter `sub_1000415C`):

| ID | Property | Type | Value |
|----|----------|------|-------|
| 19 | `Display` | string | Display name after the first space (the city names) |
| 20 | `GMT` | string | Display name up to the first space (the `(GMT…)` prefix ?) |
| 21 | `Id` | int | Record +0x00 |
| 22 | `Bias` | int | Record +0x04 |

### ChangeTimeZone and SetDateAndTime

**ChangeTimeZone(id)** (method 7): enables `SeTimeZonePrivilege`, `SetTimeZoneInformationByID(id)` (WPGLOBUTIL); on success [SetDisplayName](#setdisplayname-sub_10002b1c). Then the privilege is restored.  
**SetDateAndTime(fileTime)** (method 8, `sub_10002C30`): `FileTimeToSystemTime`, enables `SeSystemtimePrivilege`, `SetLocalTime`; on success publishes a DWORD 0 in the WNF state 0x418A063EA3BC5875. Returns the `BOOL` of `SetLocalTime` (0 if the conversion or the privilege fails).

The privilege helper (`sub_10005B34`) opens the process token (`TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY`), `LookupPrivilegeValueW` and `AdjustTokenPrivileges` with `SE_PRIVILEGE_ENABLED`; `sub_10005AF0` disables it again and closes the token.

### SetDisplayName (sub_10002B1C)

1. `GetDynamicTimeZoneInformation`; `HRESULT_FROM_WIN32(GetLastError())` on `TIME_ZONE_ID_INVALID`.
2. Opens `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones\<TimeZoneKeyName>` (`KEY_READ`).
3. `RegLoadMUIStringW(key, L"MUI_Display", +0xDC, 140 bytes, …)`.
4. On success, signals the change of `DisplayName`. `E_FAIL` if the key can't be opened.

### Out of memory

`sub_100047C8` (`UIXFailFastForOutOfMemory`, called when an allocation of the constructors fails): `OutputDebugStringW(L"UIXFailFastForOutOfMemory : Terminating process.\r\n")`, `emclient.dll!SHTerminateProcessForOOM(0)` if that DLL is loaded, then `RaiseException(0xE055494D)` and a write to address 0.

### Registry

| Key | Value | Access | Use |
|-----|-------|--------|-----|
| `HKLM\System\State\DateTime` | `NetworkTime Enabled` (DWORD) | Read | Network time (and time zone) supported → `AutoSetAvailable`, `AutoTimeZoneSetAvailable` |
| `HKLM\System\State\DateTime` | `NTP Enabled` (DWORD) | Read | NTP supported → `AutoSetAvailable` |
| `HKLM\System\State\DateTime` | `NetworkTime Sync` (DWORD) | Read / write | Automatic time on |
| `HKLM\System\State\DateTime` | `NetworkTime TimeZone Sync` (DWORD) | Read / write | Automatic time zone on (default 1) |
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones\<key>` | `MUI_Display` | `RegLoadMUIStringW` | Display name of the current time zone |

### WNF states

Decoded with `wnf.py`: version 1, well-known, system scope, not permanent, owner tag `SHL`.

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x418A063EA3BDA875 (`.text:0x100016D8`) | `SHL`, 53 (`WNF_SHL_AUTOTIMEUPDATE_STATE_CHANGED`) | 4 bytes: automatic time on (0/1) | Published by `SetNetworkTime`; consumed by [WPTimeSvc.dll](./wptimesvc.md#wnf-dispatch) (on → time sync, off → stops W32Time) |
| 0x418A063EA3BC5875 (`.text:0x100016F0`) | `SHL`, 11 (`WNF_SHL_SYSTEM_CLOCK_CHANGED`) | 4 bytes: 0 | Published by `SetDateAndTime` after the clock is changed; also published by [WPTimeSvc.dll](./wptimesvc.md#wnf-states) after each automatic time change |

The symbolic names come from the trace strings of [WPTimeSvc.dll](./wptimesvc.md); the subscribers of `WNF_SHL_SYSTEM_CLOCK_CHANGED` aren't known. Nothing is published when the time zone or the time format changes.
