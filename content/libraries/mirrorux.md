## MirrorUX.dll

The "Project my screen" page of the Windows Phone 8.1 settings: discovers Miracast displays, pairs with them, starts and stops the projection, and watches the USB projection.  
`MirrorUX.dll` (139 264 bytes, 551 functions, many of them STL, `shared_ptr` and UIX object boilerplate) holds the code of the settings page that [MirrorCPL.exe](../applications/mirrorcpl.md) starts with `res://MirrorUX!mainpage.uix`. The UI strings are in a separate resource DLL, `MirrorUXres.dll`, and the markup files in the resources of this DLL (not extracted). It's a UIX schema (exports `UIXGetSchemaFactory` / `UIXSchemaUnloaded`, as in [DateTimeCPLdll.dll](./datetimecpldll.md#exports)) with three types: `MainPage`, `Device` and `AdvancedPage`.  
It handles two kinds of projection:
- **Miracast** over Wi-Fi Direct: the DLL finds the Miracast sinks with device queries (`CFGMGR32!DevCreateObjectQuery*`), pairs with them through the device association framework (`deviceassociation!Daf*`), then starts and stops the session with the `D3DKMTNetDisp*Miracast*` functions of `gdi32.dll` (the kernel side is in [Dxgkrnl.sys](../drivers/dxgkrnl.md)). It also listens to the WNF state `WNF_DX_NETWORK_DISPLAY_STATE_CHANGE_NOTIFICATION` published by Dxgkrnl.sys.
- **USB**: it opens `\\.\UfnVidStream` ([Ufnvidstream.sys](../drivers/ufnvidstream.md)) and only waits for its state changes (IOCTL 0x22C344). It doesn't send any frames: that's done by [VidStream.dll](./vidstream.md) in the compositor process, which also asks the user to confirm and sets the topology.

For both, the display mode is set with [CompClient.dll](./compclient.md#display-topology)`!SetDisplayTopology` (the compositor client), and the "advanced" settings (touch points shown on the external display, their colour and size, orientation) are kept under `HKLM\Software\Microsoft\Compositor`.  
The DLL also exports five functions with no UI (`GetConnectedDisplayName`, `RegisterMirroringConnectionObserverCallback`, `StartDiscoveryAgentWithAutoreconnect`, `StopMirroringSession`, `UnRegisterMirroringConnectionObserverCallback`) that run their own copy of the Miracast and USB code on a private thread. None of the documented binaries imports them: their caller isn't known (a shell quick action or the system tray ?).

Location on the phone: `C:\Windows\System32\MirrorUX.dll` ? (no path in the binary; it was extracted next to `MirrorCPL.exe`).  

### Imports

| DLL | Functions |
|-----|-----------|
| [CompClient.dll](./compclient.md) | `GetDisplayTopology`, `SetDisplayTopology` |
| deviceassociation.dll | `DafCreateAssociationContext`, `DafCloseAssociationContext`, `DafStartEnumCeremonies`, `DafSelectCeremony`, `DafStartWriteCeremonyData`, `DafStartFinalize`, `DafStartRemoveAssociation`, `DafStartDeviceStatusNotification` |
| CFGMGR32.dll | `DevCreateObjectQuery`, `DevCreateObjectQueryEx`, `DevCloseObjectQuery`, `DevGetObjects`, `DevFreeObjects` |
| IcsClient.dll | `IcsGetSharingState` |
| CoreMessaging.dll | `CoreUICreate`, `CoreUICreateAnonymousStream` |
| ntdll.dll | `RtlQueryWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfStateChangeNotification`, `WinSqmStartSession`, `WinSqmEndSession`, `WinSqmSetDWORD`, `WinSqmIncrementDWORD`, `WinSqmSetIfMaxDWORD` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl`, `GetOverlappedResult`, `CancelIoEx` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegCloseKey` |
| api-ms-win-core-com-l1-1-1.dll | `CoCreateInstance` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `LoadStringW`, `GetModuleHandleW` |
| api-ms-win-core-threadpool-legacy-l1-1-0.dll | `CreateTimerQueueTimer`, `DeleteTimerQueueTimer`, `UnregisterWaitEx` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `RegisterWaitForSingleObject`, `WaitForMultipleObjects` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `GetCurrentThreadId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetSystemTimeAsFileTime` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetLastError`, `RaiseException`, `RaiseFailFastException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1.dll | `OutputDebugStringW` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memmove`, `memset`, `memcmp`, `wcslen`, `wcscmp`, `swprintf_s`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, `GetCurrentProcess` / `TerminateProcess`, `SetUnhandledExceptionFilter` / `UnhandledExceptionFilter` imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `MirrorUXres.dll` | `LoadLibraryExW(…, LOAD_LIBRARY_AS_DATAFILE)` (`sub_1000A97C`, loaded once) then `LoadStringW` | UI strings (status, errors, display names), see [String IDs](#string-ids). Not available, not analysed |
| `gdi32.dll` | `LoadLibraryExW` + `GetProcAddress` (in the Miracast agent constructor `sub_1000AA6C`) | `D3DKMTNetDispQueryMiracastDisplayDeviceSupport`, `D3DKMTNetDispStartMiracastDisplayDevice2`, `D3DKMTNetDispStopMiracastDisplayDevice`, `D3DKMTNetDispQueryMiracastDisplayDeviceStatus` (the pointers aren't checked before use) |
| `emclient.dll` | `GetModuleHandleW` + `GetProcAddress("SHTerminateProcessForOOM")` (`sub_10011F74`) | Called on out of memory (after `OutputDebugStringW(L"UIXFailFastForOutOfMemory : Terminating process.\r\n")`), then `RaiseException(0xE054004D)` |
| `\\.\UfnVidStream` | `CreateFileW(GENERIC_READ \| GENERIC_WRITE, share read/write, OPEN_EXISTING, FILE_FLAG_OVERLAPPED)` | USB projection state, see [USB agent](#usb-agent) |
| COM server `{AF7FEAD8-C345-4600-8894-6D6F0E5EDDCD}`, interface `{AF7FEAD8-C340-4600-8894-6D6F0E5EDDCD}` | `CoCreateInstance(CLSCTX_ALL)` (`sub_1000AE1C`) | Wi-Fi state ? (vtable +72 returns a state; 0 or 2 → error `WIFI_DISABLED`). Server DLL unknown |
| `UIXn.dll` (UIX engine started by [UIXMobile.dll](./uixmobile.md)) | Host: calls `UIXGetSchemaFactory` and loads the `res://MirrorUX!…` markup | UIX framework running the page (see [MirrorCPL.exe](../applications/mirrorcpl.md#runapplication-parameter)) |

No process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `UIXGetSchemaFactory` | 0x10007184 | `IUnknown **factory` (out), `host` (`IUIXServices` of the UIX engine, see [UIXMobile.dll](./uixmobile.md#uix-schema)) |
| 6 | `UIXSchemaUnloaded` | 0x10009CD4 | `DWORD` (0: unload) |
| 2 | `GetConnectedDisplayName` | 0x10008058 | `BYTE *connected` (out), `WCHAR *name` (out), `WCHAR *status` (out), `DWORD cch` (size of both buffers) |
| 3 | `RegisterMirroringConnectionObserverCallback` | 0x100084D4 | `observer` (C++ object: vtable[0] is called on every change) |
| 7 | `UnRegisterMirroringConnectionObserverCallback` | 0x100085B8 | `observer` |
| 4 | `StartDiscoveryAgentWithAutoreconnect` | 0x10008278 | none |
| 5 | `StopMirroringSession` | 0x10008358 | none |

**UIXGetSchemaFactory** / **UIXSchemaUnloaded** are built like those of [DateTimeCPLdll.dll](./datetimecpldll.md#exports): the first one starts the [dispatcher](#dispatcher-thread) on the calling thread (`sub_10006E58`), creates the schema object (28 bytes, `dword_10016600`, from the description at 0x10001900) and the factory (16 bytes, `dword_100165FC`), saves `host` in `dword_10016628` and returns the factory. A second call writes to address 0. `UIXSchemaUnloaded(0)` releases the cached objects, the schema and the factory, and resets the 7 cached type IDs to -1; a non-zero value closes the dispatcher (`sub_10006F20`).

The other five exports run their work on the dispatcher thread: if the caller isn't that thread (`sub_100070D4`), they post a work item to the CoreMessaging stream (vtable +12 of the stream `off_10016640`), wait for it on an event and return its result (a failed post throws `tlx::hr_error`). `RegisterMirroringConnectionObserverCallback` first creates that thread if it doesn't exist (`sub_10006F70`), and `UnRegisterMirroringConnectionObserverCallback` ends it when there's no more observer (`sub_10007028`).

- **RegisterMirroringConnectionObserverCallback** (`sub_10007AB0`): the first time, creates the global state (28 bytes, pointer at 0x1001665C, wrongly named `Concurrency::details::HostModule` by IDA, see below), a Miracast agent (`off_1001664C`) and a USB agent (`dword_10016654`), all separate from the ones of the UI. Then adds `observer` to the list.
- **UnRegisterMirroringConnectionObserverCallback** (`sub_10007EB8`): removes `observer`; when the list is empty, destroys the agents and the global state.
- **StartDiscoveryAgentWithAutoreconnect** (`sub_100078E4`): sets the "auto-reconnect" flag (state +0x09), notifies all the observers, restarts the discovery of the Miracast agent (its vtable +4, [Discovery](#discovery)), and arms a 4-second timer (`sub_10009404`, posts a work item to the dispatcher; what it does isn't analysed). If the Miracast agent has no active connection, it notifies the observers again. Returns 0.
- **StopMirroringSession** (`sub_10008438`): disconnects the active connection of the Miracast agent, then that of the USB agent (vtable +24 of the [connection](#connection-object)). Returns 0.
- **GetConnectedDisplayName** (`sub_10008164`): takes the active connection of the Miracast agent, otherwise of the USB agent. If there's one: `*connected` = 1, and its display name (connection +0x34) is copied to both `name` and `status`. Otherwise `*connected` = 0, `name` = string 137 and `status` = string 138 if the auto-reconnect flag is set, 139 if the flag at +0x08 is set, else 155. Returns 0.

The *active connection* of an agent is the first one whose `ConnectionState` is neither `DISCONNECTED` (1) nor `ERROR` (4) (`sub_1000BF2C`).

Global state of the exports (28 bytes, vtable `off_10001204`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 4 | Callable object (`std::function` ?), reset by the start and the stop |
| 0x08 | 1 | Flag ? (string 139 in `GetConnectedDisplayName`) |
| 0x09 | 1 | Auto-reconnect requested (`StartDiscoveryAgentWithAutoreconnect`) |
| 0x0C | 12 | `std::vector` of the observers |

### Startup

`DllEntryPoint` (0x10013D14): CRT startup (`__security_init_cookie`, `dllmain_dispatch`, `_initterm`). One of the C++ initializers (`sub_10006DDC`) starts an SQM session (`WinSqmStartSession({C6CF0920-A353-48C5-82D0-0640C6F09D94}, 9, 0)`, handle in `dword_1001666C`) and registers its end with `atexit` (`sub_100143B0`, `WinSqmEndSession`). Everything else starts when the markup creates a `MainPage`, or with `RegisterMirroringConnectionObserverCallback`.

### Dispatcher thread

`sub_10006E58`: `CoreUICreate(&off_1001663C)` (a CoreMessaging dispatcher), registers the work-item handler `sub_10007134` (vtable +52, it calls vtable +4 of each posted item and deletes it; registration ID in `dword_100165F4`), creates the stream `CoreUICreateAnonymousStream(&off_10016640)` and saves the thread ID (`dword_100165F0`). Every callback of the device queries, of the WNF state, of the timers and of the association framework posts its work to this stream, so the agents only run on this thread.  
For the exports, the thread is `sub_100070FC` (created by `sub_10006F70`): `sub_10006E58`, signals `dword_10016648`, runs the dispatcher loop (vtable +120) and closes it.

### Schema

The description at 0x10001900 lists 3 types (table at 0x100017A4) and 4 enumerations (table at 0x100018EC). Type codes: -3 bool, -5 colour (returned as value kind 5), -11 list, -13 int, -15 type, -18 string, -19 void, ≥ 0 type or enumeration ID (1 = `Device`, 28…31 = the enumerations below). Flags: 9 = read-only, 0xB = read/write.

| ID | Type | Size | Constructor | Getter | Setter | Methods |
|----|------|------|-------------|--------|--------|---------|
| 8 | `MainPage` (0x10001610) | 128 | `sub_10009834` → `sub_1000D538` | `sub_10009928` | none | `sub_10009880` |
| 16…20 | `Device` (0x10001710) | 104 (Miracast) / 176 (USB) | none (created by the agents) | `sub_10009A6C` | none | `sub_10009A18` |
| 22 | `AdvancedPage` (0x100017B0) | 40 | `sub_10009AD8` | `sub_10009B78` | `sub_10009C30` | `sub_10009B54` |

**MainPage** (`sub_1000D538`) creates its own [USB agent](#usb-agent) and [Miracast agent](#discovery), copies `MiracastSupported` from the Miracast agent, and starts the discovery (`sub_1000DABC`) if there's no active device.

| ID | Member | Type | Function / meaning |
|----|--------|------|--------------------|
| 9 | `SearchVisible` | bool | object +0x24 > 0 |
| 10 | `MiracastSupported` | bool | object +0x6C, result of the [support check](#miracast-support-check) |
| 11 | `DeviceList` | list of `Device` | |
| 12 | `ActiveDevice` | `Device` | |
| 13 | `ErrorType` | `DISCOVERY_ERROR` | object +0x60 |
| 14, 15 | `ErrorTitle`, `ErrorText` | string | |
| 3 | `DeviceTapped(Device)` | method | `sub_1000DD2C`: makes the device the selected one, or clears the selection if it was already selected (connect / disconnect ?) |
| 4 | `CancelPairing()` | method | clears the selection |
| 5 | `ClearError()` | method | `ErrorType` = 0 |
| 6 | `Closing()` | method | `sub_1000DB8C` |
| 7 | `PageStateChange(bool, bool)` | method | (false, true) → start the discovery (`sub_1000DABC`); otherwise `sub_1000DB8C` (stop ?) |

**Device**: one object per Miracast sink or for the USB connection, see [Connection object](#connection-object).

| ID | Member | Type | Function / meaning |
|----|--------|------|--------------------|
| 17 | `PairingState` | `PAIRING_STATE` | connection +0x6C |
| 18 | `ConnectionState` | `CONNECTION_STATE` | connection +0x70 |
| 19, 20 | `LegibleName`, `LegibleStatus` | string | name (+0x34) and status (+0x50) |
| 16 | `SetPin(string)` | method | vtable +32 of the connection: PIN typed by the user, see [Pairing](#pairing) |

**AdvancedPage**: the values are in `HKLM\Software\Microsoft\Compositor` (`RegCreateKeyExW`, then `RegQueryValueExW` / `RegSetValueExW` REG_DWORD; read in `sub_10011B6C`, written in `sub_10011BB4`).

| ID | Member | Type | Function / meaning |
|----|--------|------|--------------------|
| 23 | `TouchpointsEnabled` | bool, r/w | `TouchPointsEnabled` (default 1). Write: SQM 3025 incremented |
| 24 | `AccentColor` | colour, r/w | `TouchPointColorRGB` (default 0xF79608). Write: SQM 3026 incremented |
| 25 | `TouchpointSize` | int, r/w | `TouchPointSize` (default 80), shown as index `value / 20 - 2`, written as `20 × (index + 2)` |
| 26 | `ExternalDisplayOrientation` | `DISPLAY_ORIENTATION`, r/w | second DWORD of the [display topology](#display-topology). Write: `SetDisplayTopology`, SQM 3027 = value |
| 27 | `ClearConnectionsInProgress` | bool | object +0x24 |
| 21 | `ClearConnections()` | method | `sub_1000F234`: see [Clear connections](#clear-connections) |

Enumerations:

| ID | Name | Values |
|----|------|--------|
| 28 | `PAIRING_STATE` | 0 `NONE`, 1 `NEEDS_PIN`, 2 `NEEDS_PBC`, 3 `NEEDS_DISPLAY` |
| 29 | `DISCOVERY_ERROR` | 0 `NONE`, 1 `ICS_ENABLED`, 2 `WIFI_DISABLED`, 3 `GENERIC` |
| 30 | `CONNECTION_STATE` | 0 `DISCONNECTING`, 1 `DISCONNECTED`, 2 `CONNECTING`, 3 `CONNECTED`, 4 `ERROR` |
| 31 | `DISPLAY_ORIENTATION` | 0 `UNKNOWN`, 1 `PORTRAIT`, 2 `PORTRAIT_FLIPPED`, 3 `LANDSCAPE`, 4 `LANDSCAPE_FLIPPED` |

Only `NEEDS_PIN` is used by the code (state 4 of the [Miracast connection](#miracast-connection-states)).

### Connection object

Base class (`sub_10009D90`, vtable `off_10001B98`); the Miracast sinks (`sub_1000F618`, vtable `off_100021FC`) and the USB connection (`sub_1000CD2C`, vtable `off_10001C84`) derive from it.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable: +20 connect, +24 disconnect, +32 `SetPin` |
| 0x18 | 4 | Owner (agent), notified (vtable +4) when the connection state changes |
| 0x20 | 0x0C | UIX property-change helper (`sub_1000A888` with the change IDs `dword_1001602C…38`) |
| 0x34 | 0x1C | `std::wstring`: name (`LegibleName`) |
| 0x50 | 0x1C | `std::wstring`: status (`LegibleStatus`) |
| 0x6C | 4 | `PAIRING_STATE` |
| 0x70 | 4 | `CONNECTION_STATE` (initially 1) |
| 0x78 | 4 | Miracast: internal state, see [Miracast connection states](#miracast-connection-states). USB: last state of the driver |

### Discovery

The Miracast agent (`sub_1000AA6C`, 68 bytes, vtable `off_10001C20`: [0] active connection, [1] restart discovery `sub_1000ACD8`, [2] stop discovery `sub_1000BEFC`) resolves the `gdi32.dll` functions, runs the [support check](#miracast-support-check) and, if Miracast is usable, reads and subscribes to the WNF state [0x41C61629A3BC2035](#wnf-states).

**Restart discovery** (`sub_1000ACD8`): drops the sinks that aren't connecting or connected (internal state other than 2, 3), tells the owner about each one left, runs the support check again, then starts the queries (`sub_1000B38C`) or closes them.

The queries (all with `DevCreateObjectQuery*`, callbacks posted to the dispatcher). Filters are `DEVPROP_FILTER_EXPRESSION` arrays (operator 2 = `DEVPROP_OPERATOR_EQUALS`, 0x4000 = `DEVPROP_OPERATOR_LIST_ELEMENT_CONTAINS`; types 0x0D GUID, 0x10 FILETIME, 0x11 BOOLEAN, 0x12 string):

| Function | Object type, flags | Filter | Callback |
|----------|--------------------|--------|----------|
| `sub_1000B38C` | 1 (`DevObjectTypeDeviceInterface`) | `DEVPKEY_DeviceInterface_ClassGuid` ({026E516E-B814-414B-83CD-856D6FEF4822},4) = {64F1F453-D465-4097-B8F8-CDFF171FC335} and `DEVPKEY_DeviceInterface_Enabled` (…,3) = TRUE | `sub_1000B7CC`: one Miracast `Device` per interface already paired (added / updated / removed) |
| `sub_1000B38C` | 3 (`DevObjectTypeDevice`) | `DEVPKEY_Device_ClassGuid` ({A45C254E-DF1C-4EFD-8020-67D146A850E0},10) = {D421B08E-6D16-41CA-9C4D-9147E5AC98E0} and `DEVPKEY_Device_LastRemovalDate` ({83DA6326-97A6-4088-9453-A1923F573B29},103) > now − 30 days | `sub_1000C01C`: if `LastRemovalDate` > `LastArrivalDate` (…,102), removes the association (`sub_1000BF8C`: `DafCreateAssociationContext` on the AEP of {3B2CE006-…},1, `DafStartRemoveAssociation`) |
| `sub_1000B52C` | 5 (AEP), 7 (update results, all properties, localize), `DevCreateObjectQueryEx` with 1 extended parameter ({A4A001EF-6408-4D59-B32C-3E1530155842},1 = TRUE) | {E7C3FB29-CAA7-4F47-8C8B-BE59B330D4C5},3 = TRUE (can pair ?), {A35996AB-11CF-4935-8B61-A6761081ECDF},16 = FALSE (is paired ?), `DEVPKEY_WiFiDirect_Services` ({1506935D-E3E7-450F-8637-82233EBE5F6E},10) contains `"Miracast"`, {3B2CE006-5E61-4FDE-BAB8-9B8AAC9B26DF},2 = `"WiFiDirect"` | `sub_1000B6BC`: one Miracast `Device` per sink not paired yet |

Each `Device` keeps the interface / AEP ID, `DEVPKEY_NAME` ({B725F130-47EF-101A-A5F1-02608C9EEBAC},10) as name, `DEVPKEY_Device_InstanceId` ({78C34FC8-104A-4ACA-9EA4-524D52996E57},256) without its first 15 characters (`SWD\WiFiDirect\`) and `DEVPKEY_Device_ContainerId` ({8C7ED206-3F8A-4827-B3AB-AE9E1FAEFC6C},2) (`sub_1000F48C`). SQM 3024 = maximum number of sinks seen (`WinSqmSetIfMaxDWORD`, `sub_1000BABC`).  
The names of the {E7C3FB29…}, {A35996AB…}, {3B2CE006…} and {A4A001EF…} keys aren't in the binary (they look like the AEP keys of later SDKs, `System.Devices.Aep.*` ?).

### Miracast support check

`sub_1000AE1C` returns 1 if Miracast can be used, and reports the error to the owner otherwise (vtable +12: error type, device, string ID):
1. `D3DKMTNetDispQueryMiracastDisplayDeviceSupport` (8-byte output) fails → 0 (no error shown).
2. `IcsGetSharingState` fails → 0. State 2, 4 or 5 (Internet sharing on) → error `ICS_ENABLED` (1), string 148, 0.
3. `CoCreateInstance({AF7FEAD8-C345-…}, CLSCTX_ALL, {AF7FEAD8-C340-…})` and vtable +72 → state 0 or 2 → error `WIFI_DISABLED` (2), string 147, 0. A failure → 0.
4. Otherwise 1.

### Pairing

A sink found by the AEP query is paired through the device association framework when it's selected (internal states 2…7):
1. `sub_100104DC` (state 2 "finding aep"): new AEP query, same filter as above, with a 5-second timer (`sub_10011684`).
2. `sub_1000FB24` (state 3): `DafCreateAssociationContext(AEP ID)`, `DafStartEnumCeremonies` (callback `sub_1000FB80`).
3. `sub_1000FC3C`: picks the first ceremony supported by the device in this order and `DafSelectCeremony`:

| Ceremony GUID | Next step |
|---------------|-----------|
| {A1BAEFEE-E74A-450B-B25D-A5273B954D4B} | finalize at once |
| {D42FEB11-FD6D-438A-A58D-C577F67E58C9} | finalize at once |
| {94BF607D-4BE8-4B9C-8C0A-CB1ACEE1A951} | `sub_1000FD4C`: state 4 "waiting for pin" (`PAIRING_STATE` = `NEEDS_PIN`) |

   No match → string 142, state 8 ("associating failed").
4. `SetPin` → `sub_1000FD5C` (state 5 "writing pin"): `DafStartWriteCeremonyData` with the PIN for the ceremony {94BF607D…}.
5. `sub_1000FF44` (state 6 "finalizing"): `DafStartFinalize`.
6. `sub_1001130C` (state 7 "creating dev nodes"): `DafStartDeviceStatusNotification` (callback `sub_100100A0`).
7. `sub_100109A0` (state 10 "waiting for instance"): device-interface query on `DEVPKEY_Device_ContainerId` = container of the sink, `DEVPKEY_DeviceInterface_ClassGuid` = {64F1F453-…}, `Enabled` = TRUE, with a 5-second timer (`sub_100116CC`), then the session is started.

A failure in these steps (`sub_1000FAC8`) reports string 141 if the error is 0x8064000E, 142 otherwise, and goes to state 8.

### Miracast session

**Start** (`sub_100101CC`, state 11 "starting miracast"):
1. [Display topology](#display-topology) mode 0, then mode 1.
2. `D3DKMTNetDispStartMiracastDisplayDevice2(interface path, 1, hEvent)`.
3. Result 0x80000006: the path is cleared and the interface is looked for again (`sub_100109A0`). Result 2: waits for the event (`RegisterWaitForSingleObject`, `sub_10010E58`), then `sub_100107F8` checks the status.
4. Otherwise: topology mode 0, string 143, state 12 ("projecting failed").

**Status** (`sub_100107F8`, `sub_1000F8D8` on a WNF update): `D3DKMTNetDispQueryMiracastDisplayDeviceStatus(path, &status)`. Return 0x80000004 → removes the association and restarts the pairing (`sub_10010380`); return 1 → string 144 and stop; status 2 → state 13 ("projecting"); status 1 → state 11; status 3 → state 14; status 0 → back to state 9. Other failures: topology mode 0, string 143, state 12.

**Stop** (`sub_100108A0`, the disconnect method `sub_1000FA0C` when the state is ≥ 11): topology mode 0, state 14 ("stopping miracast"), `D3DKMTNetDispStopMiracastDisplayDevice(path, hEvent)`, then waits for the event (`sub_10010908`: back to state 9 unless the status is still 2 or 3).

### Miracast connection states

`sub_1000FA58` sets the internal state (+0x78) from the table at 0x100020D0 (15 entries of 5 DWORDs), which also gives the `PAIRING_STATE`, the `CONNECTION_STATE`, a debug name and the string ID of the status:

| State | Debug name | `PAIRING_STATE` | `CONNECTION_STATE` | Status string |
|-------|------------|-----------------|--------------------|---------------|
| 0 | `Unknown` | 0 | 1 `DISCONNECTED` | 136 |
| 1 | `tap to pair` | 0 | 1 | 136 |
| 2 | `finding aep` | 0 | 2 `CONNECTING` | 113 |
| 3 | `enumerating ceremonies` | 0 | 2 | 113 |
| 4 | `waiting for pin` | 1 `NEEDS_PIN` | 2 | 113 |
| 5 | `writing pin` | 0 | 2 | 113 |
| 6 | `finalizing` | 0 | 2 | 113 |
| 7 | `creating dev nodes` | 0 | 2 | 113 |
| 8 | `associating failed` | 0 | 1 | 136 |
| 9 | `tap to connect` | 0 | 1 | 136 |
| 10 | `waiting for instance` | 0 | 2 | 113 |
| 11 | `starting miracast` | 0 | 2 | 113 |
| 12 | `projecting failed` | 0 | 1 | 136 |
| 13 | `projecting` | 0 | 3 `CONNECTED` | 114 |
| 14 | `stopping miracast` | 0 | 0 `DISCONNECTING` | 140 |

### USB agent

`sub_1000C9CC` (36 bytes, vtable `off_10001CA0`) creates one USB connection (`sub_1000CD2C`, 176 bytes, name = string 115, three manual-reset events at +0x9C, +0xA0, +0xA4) and opens `\\.\UfnVidStream` ([Ufnvidstream.sys](../drivers/ufnvidstream.md)). If the device opens, it starts the thread `sub_1000D0B8` → `sub_1000D0C8` and waits until it's running:

1. Sends [IOCTL 0x22C344](../drivers/ufnvidstream.md#ioctl-0x22c344) (`sub_1000CEE0`, overlapped, event +0xA4): input = state known (+0x78), output = new state (+0x7C). Synchronous completion sets the event itself; an error other than `ERROR_IO_PENDING` throws.
2. Waits for the stop event (+0xA0) or the IOCTL event.
3. IOCTL completed (`sub_1000CF84`): state = output. State 7 (the driver is streaming) → `CONNECTION_STATE` = 3 `CONNECTED`, status string 114, the owner is told that the connection is active. State 6 or 8 → `DISCONNECTED`, string 111, owner told. Other states → `DISCONNECTED`, string 112. Failure → string 111, state 9. Then the IOCTL is sent again.
4. Stop event: cancels the IOCTL (`CancelIoEx`, `GetOverlappedResult`) and closes the handle. An unexpected wait result → `RaiseFailFastException`.

So the USB connection is only shown: the stream itself (IOCTL 0x22C340, 0x22C349…) is fed by another process. Its connect / disconnect methods (`sub_1000D1D0` / `sub_1000D1F4`) only set the [display topology](#display-topology) mode to 2 / 0.

### Display topology

`CompClient!GetDisplayTopology` / `SetDisplayTopology` take an 8-byte structure; the DLL always reads it, changes one field and writes it back. In [CompClient.dll](./compclient.md#display-topology), `SetDisplayTopology` sends it to the compositor (ALPC request 11), and `GetDisplayTopology` reads it from the registry: `HKLM\Software\Microsoft\Compositor\MirrorSettings` value `DisplayTopology` (default 0) and `HKLM\Software\Microsoft\Compositor` value `DisplayOrientation` (default 3).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Mode: 0 = phone only (projection stopped), 1 = Miracast, 2 = USB; the compositor refuses higher values (it has a 3, test mode ?, see [CompServer.dll](./compserver.md#display-topology)) |
| 0x04 | 4 | `DISPLAY_ORIENTATION` of the external display (`ExternalDisplayOrientation`), ≤ 4 |

### Clear connections

`ClearConnections` (`sub_1000F234`) sets `ClearConnectionsInProgress`, then queries the devices (`DevCreateObjectQuery`, type 3) of class {D421B08E-6D16-41CA-9C4D-9147E5AC98E0} (`DEVPKEY_Device_ClassGuid`); the callback `sub_1000C068` removes the association of each one (`sub_1000BF8C`) and, at the end of the enumeration, signals an event. The end is signalled through an event (`RegisterWaitForSingleObject`, `sub_1000F380`). {D421B08E…} is then probably the device class of the paired Miracast sinks ?

### String IDs

Strings of `MirrorUXres.dll` used by the code (their text isn't known):

| ID | Use |
|----|-----|
| 111, 112, 114 | USB connection status (disconnected, other state, projecting) |
| 113, 114, 136, 140 | Miracast connection status (see the state table) |
| 115 | Name of the USB connection |
| 137, 138, 139, 155 | `GetConnectedDisplayName` when nothing is connected |
| 141, 142 | Pairing failed (0x8064000E / other error) |
| 143, 144 | Projection failed to start / stopped by the sink |
| 147 | Wi-Fi disabled |
| 148 | Internet sharing on |

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x41C61629A3BC2035 `WNF_DX_NETWORK_DISPLAY_STATE_CHANGE_NOTIFICATION` (`sub_1000AA6C`) | `DX`, 4 | ≥ 0x214 bytes | Queried (`sub_1000AF28`) then subscribed (`sub_1000AF4C`) when Miracast is usable. The callback copies 0x214 bytes and posts them to the dispatcher; `sub_1000B1CC` finds the sink concerned and updates it (`sub_1000F8D8`): the DWORD at +0x20C gives the internal state, 1 → 11, 2 → 13, 3 → 14 (if the state is > 9), 0 → 9 (if the state is 14). Published by [Dxgkrnl.sys](../drivers/dxgkrnl.md) (`DpiMiracastBroadcastDeviceStateChange`) |

### Registry

| Key | Value | Type | Use |
|-----|-------|------|-----|
| `HKLM\Software\Microsoft\Compositor` | `TouchPointsEnabled` | REG_DWORD | Touch points shown on the external display (default 1) |
| | `TouchPointColorRGB` | REG_DWORD | Their colour (default 0xF79608) |
| | `TouchPointSize` | REG_DWORD | Their size (default 80, steps of 20) |

### SQM

Session `{C6CF0920-A353-48C5-82D0-0640C6F09D94}`:

| Data ID | Call | When |
|---------|------|------|
| 3024 | `WinSqmSetIfMaxDWORD` | Number of Miracast sinks found |
| 3025 | `WinSqmIncrementDWORD` | `TouchpointsEnabled` changed |
| 3026 | `WinSqmIncrementDWORD` | `AccentColor` changed |
| 3027 | `WinSqmSetDWORD` | `ExternalDisplayOrientation` set (value) |
