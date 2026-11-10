## BthAvrcp.dll

The Bluetooth AVRCP target profile of Windows Phone 8.1: it answers the remote controls of a car kit or a headset (play, pause, next, volume…), sends the track information and the playback status, and lets the remote browse the music library.  
`BthAvrcp.dll` is a C++ in-process COM server (873 functions, the database has its full symbols, a large part of the code is STL, WRL and WinRT helpers). It has a single class, `AVRCPProfile` (CLSID `{208F7A6F-FB35-4686-9494-AB22B7B2CD78}`, "AVRCP profile interface to AVCTP"), which implements the [profile interface](#profile-interface) `IBtAVCTPProfileInterface` `{F7B743E7-B737-4AB7-B762-33D9FDDCFDD9}`. It parses the AV/C frames received on the control channel (UNIT INFO, SUBUNIT INFO, PASS THROUGH, the vendor-dependent AVRCP 1.3/1.4 PDUs) and the browsing PDUs, and builds the answers. The media side uses the System Media Transport Controls provider of `MediaService.dll` (playback state, commands, metadata), the Zune media queue and library (`ZMediaqueueClient.dll`, `zmedialib_client.dll`: now playing list, play all), the WinRT class `PhoneInternal.Experiences.Media.MediaStoreManager` (virtual file system of the music library), and [ShellChromeAPI.dll](./shellchromeapi.md) for the volume.  
It's loaded by [BthavctpSvc.dll](./bthavctpsvc.md#profiles) (the AVCTP transport, `BthAVCTPSvc` service), which creates it from the registry subkey `Parameters\Profiles\{CLSID}` and gives it the AVCTP channels opened by the remote controller.

Location on the phone: `C:\Windows\System32\BthAvrcp.dll` ? (the extracted file has no notes).  
Source folder: `src\net\bluetooth\product\services\avrcp\dll\` (`avrcp.cpp`, `avrcp_avctp.cpp`, `avrcp_ash.cpp`, `mediaapi.cpp`, `mediaapi_browsing.cpp`, `mediavfs.cpp`, `zm_cgetitemsoperation.cpp`, `dllmain.cpp`), `src\net\bluetooth\product\services\servicelib\` (strings).  

### Imports

| DLL | Functions |
|-----|-----------|
| MediaService | `CreateSMTCProviderInstance` |
| ZMediaqueueClient | `ZMediaQueue_ConnectToService`, `ZMediaQueue_DisconnectFromService`, `ZMediaQueue_GetPlayState`, `ZMediaQueue_SetPlayState`, `ZMediaQueue_GetClientQueueType`, `ZMediaQueue_HasAudio`, `ZMediaQueue_GetProperty`, `ZMediaQueue_GetItemCount`, `ZMediaQueue_GetItemMediaAt`, `ZMediaQueue_GetCurrentItemMedia`, `ZMediaQueue_FindItem`, `ZMediaQueue_AddItem`, `ZMediaQueue_Clear`, `ZMediaQueue_MoveTo`, `ZMediaQueue_PlayList`, `ZMediaQueue_SetShuffle`, `ZMediaQueue_RegisterForNotifications`, `ZMediaQueue_UnregisterForNotifications` |
| zmedialib_client | `ZMediaLib_RequireLibrary`, `ZMediaLib_ReleaseLibrary`, `ZMediaLib_CreateList`, `ZMediaLib_GetItemIntAttribute`, `ZMediaLib_GetItemStringAttribute`, `ZMediaLib_ClearVideoToken`, `ZMediaLib_ClearRichDisplayItem`, `ZMediaList_GetItemCount`, `ZMediaList_GetItem`, `ZMediaList_Flatten`, `ZMediaList_Release` |
| ShellChromeAPI | `Shell_AdjustVolume` |
| ZTrace | `ZTraceHelperNoThis`, `ZTraceReportIgnoreNoThis` |
| ntdll | `NtQueryWnfStateData`, `WinSqmStartSession`, `WinSqmEndSession`, `WinSqmIncrementDWORD` |
| api-ms-win-core-winrt-l1-1-0, -winrt-string-l1-1-0, -winrt-error-l1-1-1 | `RoGetActivationFactory`, `WindowsCreateString`, `WindowsCreateStringReference`, `WindowsGetStringRawBuffer`, `RoOriginateError`, `RoOriginateErrorW`, `RoTransformError`, `GetRestrictedErrorInfo`, `SetRestrictedErrorInfo` |
| api-ms-win-core-com-l1-1-1 | `CoTaskMemAlloc`, `CoWaitForMultipleObjects`, `PropVariantClear`, `CoCreateFreeThreadedMarshaler`, `CoGetApartmentType` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `LoadStringW`, `FreeLibrary`, `GetModuleFileNameW`, `GetModuleFileNameA`, `GetModuleHandleExW` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegDeleteKeyExW`, `RegCloseKey` |
| api-ms-win-core-threadpool-l1-2-0, -threadpool-legacy-l1-1-0, -kernel32-legacy-l1-1-1 | `CreateThreadpool`, `CreateThreadpoolWork`, `SubmitThreadpoolWork`, `CloseThreadpoolWork`, `CloseThreadpool`, `QueueUserWorkItem`, `CreateTimerQueueTimer`, `DeleteTimerQueueTimer`, `RegisterWaitForSingleObject`, `UnregisterWaitEx` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `CreateEventExW`, `SetEvent`, `WaitForSingleObject`, `Sleep`, `InitOnceExecuteOnce`, critical sections, SRW locks |
| bcrypt | `BCryptGenRandom` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-sysinfo-l1-2-2, -string-l1-1-0, -localization-l1-2-1 | `GetTickCount`, `GetTickCount64`, `WideCharToMultiByte`, `MultiByteToWideChar`, `GetStringTypeW`, `FormatMessageA` |
| api-ms-win-core-heap-l1-2-0, -handle-l1-1-0, -util-l1-1-0 | `GetProcessHeap`, `HeapAlloc`, `CloseHandle`, `EncodePointer`, `DecodePointer` |
| api-ms-win-core-processthreads-l1-1-2, -errorhandling-l1-1-2, -debug-l1-1-1, -rtlsupport-l1-2-0 | `GetCurrentThreadId`, `GetCurrentProcess`, `TerminateProcess`, `GetLastError`, `SetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `IsDebuggerPresent`, `DebugBreak`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | C and C++ runtime (`malloc`, `operator new`/`delete`, `_CxxThrowException`, `__CxxFrameHandler3`, `_initterm`, `swscanf_s`, `setlocale`, …) |

The msvcrt, rtlsupport, util and part of the debug, errorhandling and processthreads imports are the Visual C++ CRT startup, C++ exception, STL locale and `/GS` security cookie code. The registry imports are used by `DllRegisterServer` / `DllUnregisterServer`, the `RegHelper` code shared with [BthavctpSvc.dll](./bthavctpsvc.md) and the `CTCanPlayOrAddFolders` value. The threadpool, `CoWaitForMultipleObjects` and most WinRT imports come from the WRL helpers (asynchronous operations, `AwaitOperationResult`).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `BthAVRCPRes.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)`, `LoadStringW` | String 108: name of the media player in the [player list](#browsing); strings 102 to 106: names of the root folders (with the English names "Artists", "Albums", "Songs", "Playlists", "Genres" as fallback) |
| `BthCommonRes.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)` in `GetMediaPlayerList` | Fallback for string 108, only when `BthAVRCPRes.dll` can't be loaded and `GetLastError` returns 0 |
| `MediaService.dll` (SMTC provider) | `CreateSMTCProviderInstance`, then `QueryInterface` `ISystemMediaTransportControlsProvider2` `{464BFFE9-D051-4B6A-93F4-04065BDD398F}` | State, capabilities, metadata and commands of the current media application ([Media](#media)) |
| Media store (`PhoneInternal.Experiences.Media.MediaStoreManager`) | `RoGetActivationFactory`, IID `{5969B618-2274-3D98-AFCA-C188ABCC0493}` (`IMediaStoreManagerStatics`), `GetDeviceStoreAsync` | Music library for the [virtual file system](#browsing); the server DLL of the WinRT class isn't named in this binary |

No process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x1000FAF8 | none; returns `g_lcModuleRef != 0` (S_FALSE while objects exist) |
| 2 | `DllGetClassObject` | 0x1000FB14 | `REFCLSID`, `REFIID`, `void **` |
| 3 | `DllRegisterServer` | 0x1000FB8C | none |
| 4 | `DllUnregisterServer` | 0x1000FC18 | none |

`DllGetClassObject` only knows the CLSID `{208F7A6F-FB35-4686-9494-AB22B7B2CD78}` (`CLASS_E_CLASSNOTAVAILABLE` otherwise): it creates a `CAvrcpClientFactory` (8 bytes: vtable, reference count; `IUnknown` and `IClassFactory`). `CreateInstance` refuses aggregation and builds an `AVRCPProfile` (0x220 bytes, `AVRCPProfile::AVRCPProfile` at 0x1000A2F4). `LockServer` and every object change the global count `g_lcModuleRef`.

`DllRegisterServer` writes, under `HKLM\SOFTWARE\Classes\CLSID\{208f7a6f-fb35-4686-9494-ab22b7b2cd78}`, the default value "AVRCP profile interface to AVCTP", and under `…\InProcServer32` the module path (`GetModuleFileNameW`) and `ThreadingModel` = `Both`. `DllUnregisterServer` deletes the two keys. A registry error is fatal (`__FatalError`). The `Parameters\Profiles` subkey of `BthAvctpSvc` that makes the service load this class isn't written here.

### Startup

`_DllMainCRTStartup` (0x1002257C): CRT. There's no `DllMain` of its own: the dynamic initialisers only create the global `g_spMediaStoreManagerStatics` (an empty `ComPtr`, released by `atexit`).

The constructor of `AVRCPProfile` (0x1000A2F4):
1. builds its `SynchronizedObject` with a new `Synchronizer` (the event queue that runs every `Dispatch` one at a time, same model as [BthavctpSvc.dll](./bthavctpsvc.md#global-object)), the 14 notification slots, the continuation state;
2. `WinSqmStartSession(g_WpSqmBiWeeklySession {E2D43DAC-5CAB-4C09-8D18-5DF758ED1570}, 2, 0)`;
3. `RoGetActivationFactory("PhoneInternal.Experiences.Media.MediaStoreManager", IID {5969B618-…})` into `g_spMediaStoreManagerStatics` (fatal on error);
4. `McGenEventRegister` of the [ETW](#etw) provider.

### AVRCPProfile

`AVRCPProfile` derives from `IBtAVCTPProfileInterface` (+0x00), `SynchronizedObject` (+0x04) and `IMediaApiNotification` (+0x0C, the callbacks of the [media object](#media)).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `IBtAVCTPProfileInterface` |
| 0x04 | 8 | `SynchronizedObject` (vtable, `Synchronizer *`) |
| 0x0C | 4 | vtable `IMediaApiNotification` |
| 0x10 | 4 | Reference count |
| 0x18 | 4 | Seek state: 2 = no seek started by the remote, 0 / 1 = command (Play / Pause) that ends the seek |
| 0x1C | 4 | `IBtAVCTPUserInterface *` of the AVCTP service |
| 0x20 | 4 | Bytes to keep in front of each sent buffer (4, given by `Initialization`) |
| 0x24 | 4 | Event signalled at the end of `Shutdown` |
| 0x28 | 4 | Initialised (1 after `Initialization`, 0 after `Shutdown`) |
| 0x2C | 4 | 1 = the Pause button toggles play / pause; cleared by a Play button and by any vendor-dependent PDU |
| 0x34, 0x38 | 4, 4 | Playback position timer started, timer handle (`CreateTimerQueueTimer`) |
| 0x3C | 4 | SQM session |
| 0x40 | 4 | `SysTimer *`: button-release timer of the seek |
| 0x44 | 4 | Last fast forward / rewind button |
| 0x48, 0x4C | 4, 4 | `std::tr1::shared_ptr<MediaApi>` |
| 0x50 | 4 | `MediaVFS *` |
| 0x54 | 4 | `CTCanPlayOrAddFolders` ([Registry](#registry)) |
| 0x58 | 14 × 0x18 | Notification slots, indexed by the AVRCP event id: +0 registered, +8 address of the device, +0x10 transaction label |
| 0x1A8 | 2 | UID counter |
| 0x1B0 | 8 | Address of the control channel being accepted |
| 0x1B8, 0x1BC | 4, 4 | Control, browsing channel accepted, waiting for `ConnectResult` |
| 0x1C0, 0x1C4 | 4, 4 | Control, browsing channel connected |
| 0x1C8 | 8 | Address of the connected device |
| 0x1D0 | 2 | Low byte: highest AVRCP version used by the remote (3: 1.3 PDU, 4: 1.4 PDU or browsing); 0x100 at reset |
| 0x1D4 | 4 | 1 when the track changed notification was sent with UID 0 (1.3 behaviour) |
| 0x1E0 | 0x10 | `Timer` of the now playing debounce (event 8, 500 ms) |
| 0x1F0 | 1 | Browsing traversal in progress ? (delays event 8) |
| 0x1F4 | 4 | Tick count of the last traversal ? |
| 0x1F8, 0x1FC, 0x200 | 4, 4, 4 | Parameters of the control response: buffer, used, size (grows by 512 bytes) |
| 0x204, 0x208, 0x20C | 4, 4, 4 | Parameters of the browsing response: buffer, used, maximum (browsing MTU − 3) |
| 0x210, 0x214, 0x218 | 4, 4, 4 | Continuing response: PDU id (255 none), ctype, data |
| 0x21C, 0x21E | 2, 2 | Continuing response: total size, bytes already sent |

### Profile interface

The vtable of `IBtAVCTPProfileInterface`, called by [BthavctpSvc.dll](./bthavctpsvc.md#profile-interface). Except `Initialization`, each method copies its parameters in a heap block, queues an event of `AVRCPProfile::Dispatch` (0x1001C2F0) and returns at once; they return 1062 (`ERROR_SERVICE_NOT_ACTIVE`) before `Initialization` or after `Shutdown`.

| Index | Method | Address | Event |
|-------|--------|---------|-------|
| 3 | `Initialization(IBtAVCTPUserInterface *, int headerSpace)` | 0x1000EDA4 | none |
| 4 | `ConnectionIndication(AVCTP_CHANNEL_TYPE, BTH_ADDR, WORD mtu)` | 0x1000F3DC | 0 |
| 5 | `DisconnectIndication(AVCTP_CHANNEL_TYPE, BTH_ADDR)` | 0x1000F428 | 1 |
| 6 | `MessageRecvIndication(AVCTP_CHANNEL_TYPE, BTH_ADDR, BYTE transaction, AVCT_TYPE, BYTE *packet, WORD offset, WORD size)` | 0x1000F514 | 2 |
| 7 | `DisconnectOut(AVCTP_CHANNEL_TYPE, BTH_ADDR, int result)` | 0x1000F574 | 3 (only logged) |
| 8 | `ConnectResult(AVCTP_CHANNEL_TYPE, BTH_ADDR, int result)` | 0x1000F49C | 5 |
| 9 | `Shutdown()` | 0x1000F5EC | 4, then waits for the event at +0x24 (only if the control channel is connected) |

`AVCTP_CHANNEL_TYPE`: 0 control, 1 browsing. The `IBtAVCTPUserInterface` methods used (the AVCTP side): 3 `ConnectResponse(type, address, WORD result)`, 4 `SendMessage(type, address, transaction, AVCT_TYPE 2 (response), BD_BUFFER *)`, 5 `DisconnectConnection(type, address)`.

`Initialization` (0x1000EDA4):
1. creates the shutdown event (`CreateEventW`, auto reset);
2. creates the `MediaApi` object (0x1F8 bytes) on the same `Synchronizer`, if not done;
3. if the media object has no provider: `CreateSMTCProviderInstance`, then `QueryInterface(ISystemMediaTransportControlsProvider2 {464BFFE9-D051-4B6A-93F4-04065BDD398F})`; then `MediaApi::RefreshState`;
4. keeps the `IBtAVCTPUserInterface` (`AddRef`) and the header space (4, the bytes `GetBuffer` leaves in front of the data for the AVCTP header), and sets the initialised flag.

`AVRCPProfile::Dispatch` (0x1001C2F0):

| Event | Queued by | Action |
|-------|-----------|--------|
| 0 | `ConnectionIndication` | `AVCT_ConnectInd` (control) or `AVCT_BrowseConnectInd` (browsing) |
| 1 | `DisconnectIndication` | `AVCT_DisconnectInd` or `AVCT_BrowseDisconnectInd` |
| 2 | `MessageRecvIndication` | `AVCT_MsgRecInd` or `AVCT_BrowseMsgRecInd` on packet + offset, then frees the packet |
| 3 | `DisconnectOut` | Logged |
| 4 | `Shutdown` | `DoDisconnectCleanup`, then `SetEvent` |
| 5 | `ConnectResult` | `DispatchConnectResult` (0x1001C4C0): result 0 for the channel being accepted → connected (+0x1C0 or +0x1C4); SQM data point 3226 for a browsing result |
| 6 | Button-release timer | `DispatchButtonRelease` ([Pass through](#pass-through)) |
| 7 | Playback position timer | `DispatchPlaybackPositionTimer` |
| 8 | Now playing debounce timer | Waits again 500 ms while a traversal is in progress (less than 500 ms ago), otherwise sends the notification `NOW_PLAYING_CONTENT_CHANGED` |

### Connections

`AVCT_ConnectInd` (0x1000F054), control channel:
- if a device is already connected: result 0 for the same address, 2402 for another one;
- otherwise clears the pushed button bitmask, takes a random UID counter (`BCryptGenRandom`, 2 bytes, not 0) and remembers the address as being accepted;
- on success creates the `MediaVFS` ([Browsing](#browsing)) and queues event 0 of the media object (binding to the SMTC provider);
- answers with `ConnectResponse(0, address, result)`.

`AVCT_BrowseConnectInd` (0x1000F198), browsing channel: refused with 5023 (`ERROR_INVALID_STATE`) without a control channel, with 2402 for another device; accepted otherwise (the maximum browsing response is MTU − 3). It answers with `ConnectResponse(1, …)` and reads `CTCanPlayOrAddFolders` for the device.

`AVCT_DisconnectInd` (0x1000F100): unknown address → 1168 (`ERROR_NOT_FOUND`). Clears the channel state, calls `DoDisconnectCleanup` and, if the browsing channel was connected, asks the AVCTP service to close it (`DisconnectConnection(1, address)`). `AVCT_BrowseDisconnectInd` (0x1000F2F8) writes `CTCanPlayOrAddFolders` = 1 when the flag is set, and clears the browsing state.

`DoDisconnectCleanup` (0x1000EF3C): stops the button-release and debounce timers, releases the play queue and the `MediaVFS`, queues event 1 of the media object (unbinding), sends the command that ends a seek in progress, unregisters the 13 notifications, frees the response buffers and resets the continuation.

### AV/C frames

`AVCT_MsgRecInd` (0x1000D2C8) handles a frame of the control channel (`ctype`, `subunit_type << 3 | subunit_id`, `opcode`, operands). The answer goes back with `SendMessage(0, address, transaction, response, buffer)`. Without a connected control channel it returns 2250, a frame shorter than 3 bytes 122, a `ctype` above 0x0F 13; on any error the answer is the 3-byte frame `REJECTED` (0x0A), or `NOT_IMPLEMENTED` (0x08) for an unknown opcode (error 120).

| Opcode | Accepted | Answer |
|--------|----------|--------|
| 0x30 UNIT INFO, 0x31 SUBUNIT INFO | `ctype` STATUS (1), subunit 0x1F (unit), id 0 or 7, 5 operands | STABLE (0x0C), 0xFF, opcode, 0x07, 0x48 (panel), 0xFF 0xFF 0xFF |
| 0x7C PASS THROUGH | Subunit panel (9), id 0 | CONTROL (0): [button](#pass-through) handled → ACCEPTED (0x09), otherwise NOT_IMPLEMENTED; SPECIFIC INQUIRY (2): STABLE for the 9 known buttons, NOT_IMPLEMENTED otherwise. The operands are echoed |
| 0x00 VENDOR DEPENDENT | Subunit panel, id 0, company id 0x001958 (Bluetooth SIG) | [AVRCP PDU](#avrcp-pdus) |

### Pass through

`ProcessPassthroughControlCommandOperand` (0x1000AB64): the first operand is the state flag (bit 7: released) and the operation id. A release of a button that wasn't pushed is ignored ("spurious"); the pushed buttons are kept in the bitmask `g_ButtonPushedStateBitmask`. The button-release timer is stopped first. Most actions are done on the release:

| Operation id | Name (`GetButtonName`) | Action |
|--------------|------------------------|--------|
| 0x41 | `VolUp_t` | `Shell_AdjustVolume(1)` ([ShellChromeAPI.dll](./shellchromeapi.md)) |
| 0x42 | `VolDown_t` | `Shell_AdjustVolume(-1)` |
| 0x44 | `Play_t` | Play; clears the toggle flag (+0x2C) |
| 0x45 | `Stop_t` | Command 2, which `sendPlayerCommand` sends as Pause |
| 0x46 | `Pause_t` | Pause; while the toggle flag is set: Pause if playing, Play otherwise (status 255 excepted) |
| 0x48, 0x49 | `Rewind_t`, `FastFwd_t` | On the push: remembers Play or Pause to get out of the seek, sends Rewind / FastForward and starts the `SysTimer` (5000 ms, event 6). On the release: sends the remembered command if the player is still seeking |
| 0x4B | `Forward_t` | Next |
| 0x4C | `Backward_t` | Previous |

Another operation id → error 87 (NOT_IMPLEMENTED). `DispatchButtonRelease` (0x1000CA28), when the release never came within 5 s, clears the button and sends Play if the player is still seeking. A track change or a playback status other than seeking also ends the seek ("SEEK:" log strings).

### AVRCP PDUs

`ProcessAVRCPSpecificAVCPDU` (0x1000CDE4) gets the bytes after the company id: PDU id, packet type (must be 0, single), parameter length (big endian), parameters. The answer is built in the response buffer (+0x1F8) and framed as `ctype`, 0x48, 0x00, 0x00 0x19 0x58, PDU id, packet type, length (2 bytes BE), parameters. Parameters bigger than 502 bytes are cut: the first packet is sent with packet type 1 (start) and the rest is kept for `RequestContinuingResponse` (packet type 2 continue, 3 end). An error gives `REJECTED` with one byte of AVRCP status (`convertWin32ToAVRCPStatus`: 87 → 1 invalid parameter, 8 and 13 → 2 parameter not found, 50 and 1002 → 0 invalid command, other → 3 internal error). An unknown PDU id is error 1002 (invalid command).

| PDU | Name | `ctype` | Answer |
|-----|------|---------|--------|
| 0x10 | GetCapabilities | STATUS | Capability 2 (company id): 1 id, 0x001958. Capability 3 (events): 6 events, 0x01, 0x02, 0x08, 0x0B, 0x0A, 0x09 |
| 0x11 | ListPlayerApplicationSettingAttributes | STATUS | 2 attributes: 0x02 repeat, 0x03 shuffle |
| 0x12 | ListPlayerApplicationSettingValues | STATUS | Repeat: 0x01 off, 0x03 all, 0x02 single; shuffle: 0x01 off, 0x02 all |
| 0x13 | GetCurrentPlayerApplicationSettingValue | STATUS | Only attributes 2 and 3 accepted; values from the media object |
| 0x14 | SetPlayerApplicationSettingValue | CONTROL | ACCEPTED; repeat 1/2/3 → provider repeat mode 0/1/2 (capability bit 0x2000), shuffle → provider shuffle on / off (capability bit 0x1000) |
| 0x20 | GetElementAttributes | STATUS | Identifier must be 0 (playing track); attributes of `MediaApi::getCurrentTrack` (`FillMediaItemElement`) |
| 0x30 | GetPlayStatus | STATUS | Song length (ms), position (ms), play status, each 4 bytes big endian; 0, 0, STOPPED without a player |
| 0x31 | RegisterNotification | NOTIFY | INTERIM (0x0F), [Notifications](#notifications) |
| 0x40 | RequestContinuingResponse | CONTROL | Next fragment of the pending PDU |
| 0x41 | AbortContinuingResponse | CONTROL | ACCEPTED, the pending response is dropped |
| 0x60 | SetAddressedPlayer | CONTROL | Player id 1000 → ACCEPTED, status 4 (success); other id → REJECTED, status 0x11 (invalid player id) |
| 0x74 | PlayItem | CONTROL | `ProcessAVRCPAddToNowPlaying` with play = 1; SQM data point 3227 |
| 0x90 | AddToNowPlaying | CONTROL | Same with play = 0; SQM data point 3227 |

`ProcessAVRCPAddToNowPlaying` (0x1000B2C4) expects 11 bytes: scope (1 file system, 2 search, 3 now playing), UID (8 bytes BE), UID counter. Status: scope 0 or above 3 → 0x0A (invalid scope), UID 0 → 0x01, invalid UID → 0x09 (does not exist), folder other than the "all songs" folder → 0x0C (not playable), success 0x04 (ACCEPTED). For the file system scope `DetermineItemToAdd` (0x1000B424) looks up the item in the `MediaVFS` (when the first method of the object found returns non-zero, a folder ?, it sets the `CTCanPlayOrAddFolders` flag), and PlayItem first clears the now playing list. The "all songs" folder is added with `Platform::AddAllAudioToNowPlayingList`, any other item with `MediaApi::addToNowPlaying`; PlayItem then calls `MediaApi::play(uid)`.

### Notifications

`ProcessAVRCPRegisterNotification` (0x1000AF64) accepts the events below (the event 5, `TRACK_PLAYBACK_POS_CHANGED`, passes the first check but has no case, so it's refused with 87). It remembers the address and the transaction label in the slot of the event and answers INTERIM with the current value. When the value changes, `GenerateNotification` (0x1000CC68) sends the frame CHANGED (0x0D) with PDU 0x31 and the new value, then clears the slot: the remote has to register again.

| Event | Name | Value | Sent when |
|-------|------|-------|-----------|
| 0x01 | `PLAYBACK_STATUS_CHANGED` | 1 byte: play status | `PlaybackStatusChanged` (provider state, 150 ms debounce) |
| 0x02 | `TRACK_CHANGED` | 8 bytes: UID of the track; 0 (track selected, AVRCP 1.3) when the remote never used a 1.4 PDU; 0xFFFFFFFFFFFFFFFF when stopped | `TrackChanged` |
| 0x08 | `PLAYER_APPLICATION_SETTING_CHANGED` | 5 bytes: 2 attributes, 0x03 shuffle, 0x02 repeat | Shuffle or repeat mode change |
| 0x09 | `NOW_PLAYING_CONTENT_CHANGED` | none | 500 ms after a change of the play queue (event 8) |
| 0x0A | `AVAILABLE_PLAYERS_CHANGED` | none | Never sent |
| 0x0B | `ADDRESSED_PLAYER_CHANGED` | Player id 0x03E8, UID counter | Never sent |
| 0x0C | `UIDS_CHANGED` | UID counter | Never sent |

Play status values (`GetPlayStatusName`): 0 STOPPED, 1 PLAYING, 2 PAUSED, 3 FWD_SEEK, 4 REV_SEEK, 0xFF ERROR. The 0x09 to 0x0C registrations also raise the version byte (+0x1D0) to 4.

### Browsing

`AVCT_BrowseMsgRecInd` (0x1000D538) / `ProcessAVRCPBrowsingCommand` (0x1000D5E0) handle the PDUs of the browsing channel: PDU id, parameter length (BE), parameters. The answer is PDU id, length, parameters, sent with `SendMessage(1, …)`; an error gives PDU 0xA0 (general reject) with the status byte. 0x80 (GetTotalNumberOfItems) is refused with 120, the other unknown ids with 1002.

| PDU | Name | Handling |
|-----|------|----------|
| 0x70 | SetBrowsedPlayer | Player id 1000 only (status 0x11 otherwise); creates the `MediaVFS` if needed and answers status 4, UID counter, number of items of the current folder, character set 0x006A (UTF-8), folder depth and the folder names (2-byte length + UTF-8) |
| 0x71 | GetFolderItems | Scope, start, end (4 bytes BE each), attribute count (0: all, 0xFF: none) and attribute ids. Scope 0 media player list (`GetMediaPlayerList`: one player, id 1000, name = string 108 of `BthAVRCPRes.dll`), 1 virtual file system (`GetMediaList`), 3 now playing (`GetNowPlayingList`), 2 search: no item. Answer: status 4, UID counter, number of items, items; status 0x0B (range out of bounds) when start > end or nothing is found |
| 0x72 | ChangePath | At least 11 bytes: UID counter, direction, folder UID; answer: number of items of the new folder |
| 0x73 | GetItemAttributes | At least 12 bytes: scope, UID, UID counter, attribute ids |

`MediaVFS` (0x0C bytes: `IMediaStore *`, root folder, current folder) is built from the media store (`GetMediaStore` 0x10019DFC: `GetDeviceStoreAsync` of `IMediaStoreManagerStatics`). The root folder (UID 0x8100000000000000) holds five folders: Artists, Albums, Songs (`AllSongsFolder`), Playlists and Genres, each with its song folders (`ArtistSongFolder`, `AlbumSongFolder`, `PlaylistSongFolder`, `GenreSongFolder`), filled from audio query results. The UIDs (`IsUIDValid`, 0x1000AA68): non-negative = media item; high DWORD 0x81000000 = folder, with an index up to the number of folders; 0x82000000 = playing track that isn't in the play queue (the low DWORD is a tick count). The item attributes (`MediaBrowsedItem::Att`, `AVRCP_MEDIA_ID`): title, artist, album, track number, total tracks, genre, duration; the item names are converted to UTF-8.

### Media

`MediaApi` (0x1F8 bytes, constructor 0x1000FF30) is a `SynchronizedObject` on the same `Synchronizer` and the `IMediaApiEventCallback` of a `MediaApiEventBinding`, the WRL object registered as `ISystemMediaTransportControlsProviderEventHandler` on the provider and as handler of the `ContentsChanged` event of the play queue.

| Offset | Size | Comment |
|--------|------|---------|
| 0x0C | 4 | `ISystemMediaTransportControlsProvider2 *` |
| 0x10 | 4 | `MediaApiEventBinding *` |
| 0x14 | 4 | Capabilities of the current player (`GetSupportedCapabilities`); 0 = no media player |
| 0x18 | 4 | AVRCP play status |
| 0x1C | 4 | Shuffle: 1 off, 2 on |
| 0x20 | 4 | Repeat: 1 off, 2 single, 3 all |
| 0x24 | 0x10 | `Timer`, event 4 (150 ms) |
| 0x38 | 0x88 | Track information from the provider: UID, title, artist, album, genre, duration |
| 0xC0 | 1 | Valid |
| 0xC8 | 0x88 | Track information from the play queue: UID, title, artist, album, genre, duration (ms), index, count |
| 0x150 | 1 | Valid |
| 0x158 | 0x88 | Current track sent to the remote |
| 0x1E0 | 1 | A track is known |
| 0x1E4 | 4 | `IMediaApiNotification *` (the `AVRCPProfile`) |
| 0x1E8 | 0x10 | `Timer`, event 5 (150 ms) |

`MediaApi::Dispatch` (0x10010128): 0 binds the provider (`MakeAndInitialize<MediaApiEventBinding>`, fatal on error) and calls `RefreshState`; 1 unbinds (the binding is released by a `QueueUserWorkItem`, `s_CleanupWorkItem`); 2 handles a provider event; 3 the play queue changed (track information again, then `NowPlayingContentChanged`); 4 the metadata changed (provider and play queue, `TrackChanged` if the track differs); 5 `UpdatePlaybackStatus`.

Provider events (`MTCProviderEvents`): 1 `StateChanged` and 7 `PlaybackRateChanged` → play status (timer, event 5); 2 `CapabilitiesChanged` → new capabilities; 3 `MediaObjectInfoChanged` → timer, event 4; 4 `CurrentPositionChanged` → nothing; 5 `ShuffleStateChanged`, 6 `RepeatModeChanged` → `PlayerApplicationSettingChanged`; 9 `CurrentApplicationChanged` → status, shuffle and repeat. `ComputePlaybackStatus` maps the provider status: Closed (0) and Stopped (2) → STOPPED, or PAUSED when a track is known; Changing (1) → unchanged; Playing (3) / Paused (4) → FWD_SEEK when the rate is above 1, REV_SEEK when it's negative, otherwise PLAYING / PAUSED. The metadata comes from the property store of the provider (`PKEY_Title`, `PKEY_Music_Artist`, `PKEY_Music_AlbumTitle`, `PKEY_Music_Genre`, duration) and from the current item of the play queue (`IPlayQueue`, `hstring2uid` through `IMediaStoreManagerStatics` or `"%lx,%lx,%lx"`); the play queue track is used when its title is the same.

`sendPlayerCommand` (0x10010E9C) calls `SendMediaPlaybackCommand` of the provider when the capability bit is set: Play (0, bit 0x01), Pause (1, bit 0x02), FastForward (4, 0x10), Rewind (5, 0x20), Next (6, 0x40), Previous (7, 0x80); other commands are dropped ("suppressed"). Play is ignored while the audio gateway status has bit 0x004 or 0x400 (SCO, call); Pause is ignored when the player is stopped or paused, or with bit 0x008 or 0x800 (speech recognition). Without a media player, Play starts the whole music library shuffled: `ZMediaQueue_SetShuffle(1, FALSE)`, `AddAllAudioToNowPlayingList` (`ZMediaLib_CreateList(1, 0)`, `ZMediaQueue_PlayList(1, list, 0)`), `ZMediaQueue_SetShuffle(1, TRUE)`, `ZMediaQueue_SetPlayState(1, 3)`.

The play queue is `ZM_PlayQueue`, an `IPlayQueue` implemented on the Zune media queue 1: `GetCount` / `GetItemsAsync` (`CGetItemsOperation`, a threadpool work item reading `ZMediaQueue_GetItemMediaAt`), `Clear`, `AppendSongOrContainer` (a container, item id high byte 6 to 9 or 15, is expanded with `ZMediaList_Flatten`; items already in the queue are skipped), `put_CurrentIndex` (`ZMediaQueue_MoveTo`), `ContentsChanged` (`ZMediaQueue_RegisterForNotifications`). `ZM_GetActiveQueue` (0x10020250) looks for the active queue among the queues 1 to 15 (playing first, then paused, …); a queue other than 1 is controllable only for the client queue types 1 and 3, or 4 with audio.

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x0992022FA3BC1075 `WNF_BLTH_BLUETOOTH_AUDIO_GATEWAY_STATUS` (`.text:0x10004190`) | `BLTH`, 2 | 4 bytes: [status bits of BTAGService](./btagservice.md#wnf-states) | Read with `NtQueryWnfStateData` by `BTAGStatusHelper_GetStatus` (0x1000FEE0) before each Play and Pause command |

Version 1, well-known, system scope, not permanent. The binary also contains a table of `WNF_ESB_*` names (media and marketplace states, at 0x100251F0) that no code uses.

### Registry

| Key | Values |
|-----|--------|
| `HKLM\SOFTWARE\Classes\CLSID\{208f7a6f-fb35-4686-9494-ab22b7b2cd78}` | Default "AVRCP profile interface to AVCTP"; `InProcServer32`: default (module path), `ThreadingModel` = `Both`. Written by `DllRegisterServer` |
| `HKLM\System\CurrentControlSet\Services\BTConnMgr\Parameters\Devices\%012I64X\AVRCP` | `CTCanPlayOrAddFolders` (DWORD): read when the browsing channel opens, set to 1 when it closes if the flag was set (`DetermineItemToAdd`, a folder ?). The flag isn't used otherwise in this binary |

### SQM

Session `g_WpSqmBiWeeklySession` `{E2D43DAC-5CAB-4C09-8D18-5DF758ED1570}`. `WinSqmIncrementDWORD` data points: 3226 (connect result of a browsing channel), 3227 (PlayItem or AddToNowPlaying received).

### ETW

Provider `{77B174B4-C0FB-4F2C-96E1-E9771C435686}` (`Microsoft_WindowsPhone_Bluetooth_AVRCP`), registered in the constructor of `AVRCPProfile`.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 1000 | 0 | 0, 10 | 0x100 | 0x1 | `_ETWMESSAGE`, debug text (`AVRCPEtwMessage`, 0x1000F7D0, through `FormatMessageA`); `Log_HREvent` uses it for the failed HRESULTs ("Comms Status: … Location: … Line Number: …") |

`__FatalError` (0x1000EA5C) writes `NET_FATAL_ERROR` (event 100, level 2, task 1, keyword 0x1) with the provider `Microsoft-WindowsPhone-Net-Debug`, then terminates the process, as in [BthavctpSvc.dll](./bthavctpsvc.md#etw). The ZMedia helpers write through `ZTrace.dll`.
