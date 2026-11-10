## BtConnectionManagerClient.dll

The client library of the Bluetooth connection manager of Windows Phone 8.1: a COM in-process server that hides the pipe protocol of the `BTConnMgr` service behind a set of `IBt…` interfaces.  
`BtConnectionManagerClient.dll` is a C++ DLL (94 208 bytes, 334 functions, the database has its full symbols, about half of the code is STL). It has a single COM class, `CClient`, which connects to the named pipe `\\.\Pipe\BtConnectionManager`, keeps a cache of the radio, device and profile states, and turns the messages of the service into calls on the callback interfaces of its users. It rebuilds the sockets and L2CAP channels handed over by the service, and passes them to the profile services. It also controls SCO audio: this part doesn't use the service, it sends the `IOCTL_BTH_WP8_*` directly to the audio device interface of the Bluetooth stack.  
The server is [BtConnectionManagerService.dll](./btconnectionmanagerservice.md), which also creates this COM class for its own A2DP and PAN code. The CLSID is present in [BTAGService.dll](./btagservice.md), [BthavctpSvc.dll](./bthavctpsvc.md), `BthOPPManager.dll` and `Bthpbapservice.dll` (the last two not analysed), with the IID of `IBtConnectionResponder`. [BTAGService.dll](./btagservice.md#sco-audio), the HFP audio gateway, is the user of the SCO functions.

Location on the phone: `C:\Windows\System32\BtConnectionManagerClient.dll` ? (the extracted file has no notes).  
CLSID: `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`.  
Source folder: `src\net\bluetooth\product\services\connectionmanager\client\`, `src\net\bluetooth\product\services\servicelib\` (strings).  

### Imports

| DLL | Functions |
|-----|-----------|
| WS2_32 | `WSAStartup`, `WSASocketW`, `closesocket` |
| CFGMGR32 | `CM_Get_Device_Interface_List_Size_ExW`, `CM_Get_Device_Interface_List_ExW` |
| errorhandlingext | `TelReportException` |
| api-ms-win-core-namedpipe-l1-2-0 | `ConnectNamedPipe`, `SetNamedPipeHandleState` |
| api-ms-win-core-file-l1-2-1, api-ms-win-core-io-l1-1-1 | `CreateFileW`, `ReadFile`, `WriteFile`, `DeviceIoControl`, `GetOverlappedResult` |
| api-ms-win-core-threadpool-l1-2-0, -legacy-l1-1-0, -private-l1-1-0 | `CreateThreadpoolWait`, `SetThreadpoolWait`, `CloseThreadpoolWait`, `CreateThreadpoolCleanupGroup`, `CloseThreadpoolCleanupGroup`, `RegisterWaitForSingleObjectEx`, `UnregisterWaitEx` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `Sleep`, `CreateWaitableTimerExW`, `SetWaitableTimerEx`, `CancelWaitableTimer`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCreateKeyExW`, `RegSetValueExW`, `RegDeleteKeyExW`, `RegCloseKey` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-libraryloader-l1-2-0 | `DisableThreadLibraryCalls`, `GetModuleFileNameW`, `GetModuleFileNameA`, `GetModuleHandleExW` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-processthreads-l1-1-2 | `GetCurrentProcess`, `TerminateProcess`, `GetCurrentProcessId`, `GetCurrentThreadId` |
| api-ms-win-core-errorhandling-l1-1-2 | `GetLastError`, `UnhandledExceptionFilter`, `SetUnhandledExceptionFilter`, `RaiseFailFastException` |
| api-ms-win-core-debug-l1-1-1 | `DebugBreak`, `IsDebuggerPresent`, `OutputDebugStringA` |
| api-ms-win-core-rtlsupport-l1-2-0 | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | C and C++ runtime (`malloc`, `free`, `operator new`/`delete`, `_CxxThrowException`, `__CxxFrameHandler3`, `_initterm`, `_vsnprintf`, `memcpy`, …) |

The msvcrt, rtlsupport, and part of the debug, errorhandling and processthreads imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. `ConnectNamedPipe` comes from `AsyncPipe`, the code shared with the service.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\\.\Pipe\BtConnectionManager` | `CreateFileW` ([Pipe connection](#pipe-connection)) | Protocol of [BtConnectionManagerService.dll](./btconnectionmanagerservice.md#pipe-protocol) |
| First device of the interface `GUID_BTHWP8_AUDIO_DEVICE_INTERFACE` `{5E1429D2-01B6-458D-8687-3F976014F4BB}` | `CM_Get_Device_Interface_List_ExW`, `CreateFileW` ([SCO audio](#sco-audio)) | Target of the `IOCTL_BTH_WP8_*`; the driver exposing it isn't known |

No DLL is loaded at run time, and no process or COM server is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllRegisterServer` | 0x1000AC50 | none |
| 2 | `DllUnregisterServer` | 0x1000ACF4 | none |
| 3 | `DllGetClassObject` | 0x1000AAD0 | `REFCLSID rclsid, REFIID riid, void **ppv` |

There's no `DllCanUnloadNow`. `DllGetClassObject` pins the DLL at its first call (`GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN, L"BtConnectionManagerClient.dll")`). It answers `REGDB_E_CLASSNOTREG` for any other CLSID, otherwise it creates a `CClientFactory`. `CClientFactory::CreateInstance` (0x100084C8) refuses aggregation (`CLASS_E_NOAGGREGATION`), allocates a `CClient` (0xF8 bytes) and calls `QueryInterface`. Each instance has its own pipe connection.

`DllRegisterServer` writes under `HKLM\SOFTWARE\Classes\CLSID\{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`: the default value `Client interface to Bluetooth Connection Manager`, then in `InProcServer32` the path of the DLL and `ThreadingModel` = `Both`. `DllUnregisterServer` deletes the two keys.

### Startup

`_DllMainCRTStartup` (0x10010A20): CRT. `DllMain` (0x1000AB88), on `DLL_PROCESS_ATTACH`: `McGenEventRegister`, reads `DebugConsoleEnabled` (default 0) and `DebugSevLevel` (default 3), sets `BtcmOutOfMemory` as `new` handler, stores the module handle and calls `DisableThreadLibraryCalls`. On `DLL_PROCESS_DETACH`: `McGenEventUnregister`.

### COM interfaces

| Interface | IID | Implemented by |
|-----------|-----|----------------|
| `IBtRadioController` | `{BB431756-4878-46C3-A8FC-EC95FF2DF54D}` | `CClient`+0x00, also the `IUnknown` |
| `IBtConnectionObserver` | `{83C91970-1D3D-48E3-859F-436EB34F34FD}` | `CClient`+0x04 |
| `IBtConnectionResponder` | `{4D1AC687-509C-48F7-A7BB-FE2B83A9C7DC}` | `CClient`+0x08 |
| `IBtRegisterTrigger` | `{3799DB18-FDFA-4010-8ACA-1D643246DB97}` | `CClient`+0x0C |
| `IAsyncPipeCallback` | `{0396A428-1EAE-4AD7-8965-DF041C68CAA8}` | `CClient`+0x10 |
| `IBtPairingRequest` | `{EB7C310F-C408-43FE-98E6-4B9BAE958C41}` | `PairingRequest`, `IncomingPairing` |
| `IBtScoAudioDevice` | `{D5D68018-3E53-4E0F-947D-4C8133B0E4F1}` | `CScoAudioDevice`+0x08 |
| `IBtConnectionObserverCallback2` | `{CBBC9044-EED8-49BD-BD3A-887AD84AC3F5}` | Asked from the observer of the user, optional |
| `IBtRegisterTriggerCallback` | `{E21A1912-8E69-472B-AED6-95C0AEB4AFCF}` | `SyncRegistrationCallback`, or the user |

The methods below start at vtable index 3, after `IUnknown`; their names are the symbols of the binary. A device address is an `unsigned __int64`. The callback interfaces are in [Callbacks](#callbacks).

`IBtRadioController` (vtable 0x10001CC4):

| Index | Method | Address | Message or action |
|-------|--------|---------|-------------------|
| 3 | `EnableBluetoothRadio(BYTE fEnable, IBtCommandCallback *, void *context)` | 0x10005234 | 1 |
| 4 | `SetInquiryMode(INQUIRY_MODE)` | 0x10005354 | 2 (the mode is kept, and sent again after a reconnection) |
| 5 | `SetDiscoveryMode(DISCOVERY_MODE)` | 0x10005388 | 3 (same) |
| 6 | `CreatePairingRequest(address, IBtPairingRequestCallback *, IBtPairingRequest **)` | 0x100053BC | Creates a [PairingRequest](#pairing) |
| 7 | `UnpairDevice(address)` | 0x10005438 | 9 |
| 8 | `ConnectDevice(address)` | 0x10005494 | 13 |
| 9 | `DisconnectDevice(address)` | 0x100054F0 | 14 |
| 10 | `RegisterForIncomingPairing(IBtIncomingPairingCallback *)` | 0x1000554C | 15 with 1; replaces the previous callback |
| 11 | `UnregisterForIncomingPairing()` | 0x10005588 | 15 with 0 |
| 12 | `CreateScoAudioDevice(address, BYTE volume, BYTE headset, IBtScoAudioDeviceCallback *, IBtScoAudioDevice **)` | 0x100055B8 | [SCO audio](#sco-audio) |
| 13 | `GetBluetoothAddress(unsigned __int64 *)` | 0x10005D18 | Local address of the last message -1; `ERROR_NOT_READY` if unknown |
| 14 | `Shutdown()` | 0x10005D4C | See [Shutdown](#shutdown) |
| 15 | `SynchronousShutdown(DWORD timeout)` | 0x10005DA4 | `Shutdown`, then waits for the shutdown event |

`IBtConnectionObserver` (vtable 0x10001CAC):

| Index | Method | Address | Action |
|-------|--------|---------|--------|
| 3 | `RegisterCallback(IBtConnectionObserverCallback *, int *id)` | 0x1000573C | Returns an id, replays the state to the new observer |
| 4 | `UnregisterCallback(int id)` | 0x1000593C | Same id space as the responders |
| 5 | `Shutdown()` | 0x1000822C (thunk) | |

`IBtConnectionResponder` (vtable 0x10001C8C):

| Index | Method | Address | Message |
|-------|--------|---------|---------|
| 3 | `RegisterCallback(REFGUID profile, IBtConnectionResponderCallback *, int *id)` | 0x10005AD8 | 10 |
| 4 | `UnregisterCallback(int id)` | 0x10008208 (thunk) | 11 |
| 5 | `SetProfileState(address, REFGUID profile, BLUETOOTH_CONNECTION_STATE)` | 0x10005B84 | 12 |
| 6 | `ConnectProfileToDevice(address, REFGUID profile, IBtCommandCallback *, void *context)` | 0x10005BE0 | 17 |
| 7 | `Shutdown()` | 0x10008250 (thunk) | |

`IBtRegisterTrigger` (vtable 0x10001C5C):

| Index | Method | Address | Message |
|-------|--------|---------|---------|
| 3 | `RegisterRfcommTriggerAsync(address, REFGUID, REFGUID, UINT, BYTE, BYTE, BYTE, UINT cbSdpRecord, const BYTE *sdpRecord, IBtRegisterTriggerCallback *)` | 0x10005EF8 | 18 |
| 5 | `RegisterDeviceConnectionChangeTriggerAsync(address, BYTE, BYTE, IBtRegisterTriggerCallback *)` | 0x10006054 | 19 |
| 7 | `RegisterRssiTriggerAsync(address, int, int, UINT, IBtRegisterTriggerCallback *)` | 0x10006134 | 20 |
| 9 | `RegisterCharacteristicTriggerAsync(address, USHORT, USHORT, USHORT, int count, USHORT *, IBtRegisterTriggerCallback *)` | 0x10006204 | 21 |
| 11 | `UnregisterTrigger(GUID)` | 0x10006410 | 22 |

The even indexes 4, 6, 8 and 10 are the `…Sync` versions: same parameters, with a `GUID *` in place of the callback. They create a `SyncRegistrationCallback` (0x20 bytes, `CreateEventW`), call the `Async` method, and wait without timeout (`SyncRegistrationCallback::Wait`, 0x1000B590) for the result and the GUID of the trigger.

Common results: `0x8007139F` (`ERROR_INVALID_STATE`) after a shutdown or in the wrong pairing state, `0x80070015` (`ERROR_NOT_READY`) when the pipe isn't connected.

### CClient

`CClient::CClient` (0x10004970) creates the shutdown event (manual reset), the waitable timer (`CreateWaitableTimerExW`, flags 0, access 0x100002) with `RegisterWaitForSingleObjectEx` on `TimeoutStatic`, calls `WSAStartup(0x202)`, creates the `AsyncPipe` (0x580 bytes), then `TryConnectPipe`.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `IBtRadioController` |
| 0x04 | 4 | vtable `IBtConnectionObserver` |
| 0x08 | 4 | vtable `IBtConnectionResponder` |
| 0x0C | 4 | vtable `IBtRegisterTrigger` |
| 0x10 | 4 | vtable `IAsyncPipeCallback` |
| 0x14 | 8 | `SynchronizedObject` (vtable, `Synchronizer *`) |
| 0x1C | 4 | Reference count |
| 0x20 | 4 | Counter of the cookies and ids |
| 0x24 | 1 | `m_fIsShutdown` |
| 0x28 | 4 | Shutdown event |
| 0x2C | 1 | Initial status received (message -4, or connection given up) |
| 0x30 | 4 | Radio state (`BLUETOOTH_RADIO_STATE`, values in [the service page](./btconnectionmanagerservice.md#radio-power)) |
| 0x34 | 0x10 | `CommandCallbackSet`: cookie → `CommandCallback` |
| 0x44 | 0x10 | `RegistrationCallbackSet`: cookie → trigger callback |
| 0x54 | 0x10 | `PairingRequestSet`: cookie → `PairingRequest` |
| 0x64 | 0x10 | `ObserverSet`: id → observer, observer2 |
| 0x74 | 0x14 | `DeviceStateSet`: address → `DeviceState` |
| 0x88 | 0x14 | `ProfileStateSet`: (address, profile) → state |
| 0x9C | 0x20 | `ResponderSet`: id → `Responder`, and profile GUID → `Responder` |
| 0xBC | 4 | Timer |
| 0xC0 | 4 | Wait handle of the timer |
| 0xC4 | 4 | `AsyncPipe *` |
| 0xC8 | 4 | Inquiry mode |
| 0xCC | 4 | Discovery mode |
| 0xD0 | 4 | `IBtIncomingPairingCallback *` |
| 0xD8 | 8 | Local Bluetooth address |
| 0xE0 | 4 | Connection retries |
| 0xE4 | 0x10 | Map address → `CScoAudioDevice *` |

Objects derive from `SynchronizedObject`. Each one owns a `Synchronizer` (0x3C bytes): a queue protected by a critical section. `Synchronizer::EnqueueEvent` (0x1000EFC0) runs the event on the calling thread if the queue is idle, otherwise the thread that is draining it runs the event. The handlers therefore never run concurrently. This is the same model as the service.

`CClient::Dispatch` (0x10007060) events:

| Event | Action |
|-------|--------|
| 0 | `EnableBluetoothRadioCallback` |
| 1, 2 | Set the inquiry, discovery mode |
| 3, 4, 5 | Unpair, connect, disconnect the device |
| 6, 7 | Register, unregister the incoming pairing callback |
| 8, 9 | `RegisterObserverCallback`, `UnregisterCallbackCallback` |
| 10 | `ResponderSet::Add` |
| 11 | Sends `SetProfileState` |
| 12 | `ConnectProfileToDeviceCallback` |
| 13 | `ShutdownCallback` |
| 14 | Timeout: `TryConnectPipe` if the pipe is closed |
| 15 | `IncomingMessageCallback` |
| 16 | `PipeBrokenCallback` |
| 17 | `BeginPairingCallback`: writes message 4 and adds the request to the set |
| 18 | `RemovePairingRequestCallback` |
| 19, 20 | Add, remove a `CScoAudioDevice` in the map |
| 21 | `RegisterTriggerCallback` |
| 22 | Sends `UnregisterTrigger` |

### Pipe connection

`CClient::TryConnectPipe` (0x10007580) calls `AsyncPipe::Connect` (0x1000F7AC):
1. `CreateFileW(L"\\\\.\\Pipe\\BtConnectionManager", GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, FILE_FLAG_OVERLAPPED | 0x10000, NULL)`. The name passed by the caller isn't used. The errors `ERROR_FILE_NOT_FOUND`, `ERROR_PIPE_BUSY` and `ERROR_ACCESS_DENIED` are returned, the others are fatal.
2. `SetNamedPipeHandleState` with `PIPE_READMODE_MESSAGE`. `ERROR_PIPE_NOT_CONNECTED` closes the handle and returns 0x800700E9.
3. Queues `StartConnect` (0x1000F89C); the completions then run on the thread pool (`CreateThreadpoolWait`).

On success, the client sends again what the service must know: message 2 and 3 if the modes aren't 0, message 10 for each responder, and message 15 if an incoming pairing callback is set.

On failure, it retries with the timer: after 50 ms for `ERROR_PIPE_BUSY`, up to 20 times, otherwise every 5 seconds. Before waiting 5 seconds the first time, it calls `InitializationComplete` on the observers, so a user doesn't wait for a service that isn't running.

`PipeBrokenCallback` (0x10006670) completes the pending commands, registrations and pairings with `ERROR_NOT_READY`, reports the radio state 0 (`BRS_UNKNOWN`) to the observers, clears the device and profile caches, closes the pipe and starts the 5-second timer.

`AsyncPipe` reads with a buffer of 0x4B0 bytes (`StartRead`, 0x1000FBFC) and writes one message at a time from a queue. Each read completes in `ReadCompletedStatic`, and `ReadCompletedCallback` (0x1000FE70) calls `IncomingMessage`. `ERROR_BROKEN_PIPE`, `ERROR_NO_DATA`, `ERROR_PIPE_NOT_CONNECTED` and `ERROR_CANCELLED` call `PipeBroken`, `ERROR_OPERATION_ABORTED` restarts the read if the pipe is open, and other errors are fatal.

### Pipe messages

The [service page](./btconnectionmanagerservice.md#pipe-protocol) has the sizes, handlers and access checks. This is the content seen from the client. Each message starts with a DWORD type.

Sent by the client:

| Type | Size | Fields |
|------|------|--------|
| 1 | 12 | +4 enable, +8 cookie |
| 2, 3 | 8 | +4 mode |
| 4 | 64 | +8 address, +0x10 cookie, +0x14 `AUTHENTICATION_REQUIREMENTS`, +0x18 byte OOB data present, +0x1C `BLUETOOTH_PAIRING_OOB_DATA` (36 bytes) |
| 5 | 28 | +4 cookie, +8 PIN size, +0xC PIN (16 bytes) |
| 7 | 8 | +4 cookie: accept the pairing |
| 8 | 8 | +4 cookie: refuse the pairing |
| 9, 13, 14 | 16 | +8 address |
| 10, 11 | 20 | +4 profile GUID |
| 12 | 40 | +8 address, +0x10 profile GUID, +0x20 state |
| 15 | 8 | +4 byte: wants the incoming pairings |
| 16 | 28 | +4 profile GUID, +0x14 connection cookie, +0x18 byte: connection accepted by the responder |
| 17 | 40 | +8 address, +0x10 profile GUID, +0x20 cookie |
| 18 | 1088 | +4 cookie, +8 address, +0x10 GUID, +0x20 GUID, +0x30 DWORD, +0x34…+0x36 3 bytes, +0x38 SDP size (0x400 at most), +0x3C SDP record |
| 19 | 24 | +4 cookie, +8 address, +0x10, +0x11 bytes |
| 20 | 32 | +4 cookie, +8 address, +0x10, +0x14, +0x18 DWORDs |
| 21 | 40 | +4 cookie, +8 address, +0x10, +0x12, +0x14 words, +0x18 count, +0x1C 5 words |
| 22 | 20 | +4 GUID of the trigger |

Received by `CClient::IncomingMessageCallback` (0x100064C0). The minimum size isn't checked here, an unknown type is fatal.

| Type | Fields | Action |
|------|--------|--------|
| -1 | +4 radio state, +8 local address | `RadioStateChanged` |
| -2 | +8 address, +0x10 `BLUETOOTH_DEVICE_STATE`, +0x14 class, +0x18 name, +0x58 RSSI (0x80000000: none), +0x5C size (0x20 at most), +0x60 advertising data | `ReceiveDeviceState`, see below |
| -3 | +8 address, +0x10 profile GUID, +0x20 state | `ReceiveProfileState` (0x10006D88); the entry is erased when the state is 0 |
| -4 | | `InitializationComplete`, once |
| -5 | +4 cookie, +8 HRESULT | Completes `EnableBluetoothRadio` |
| -6 | +4 cookie | Asks for a PIN |
| -7 | +4 cookie, +8 size, +0xC passkey | Shows a passkey |
| -8 | +4 cookie, +8 value | Numeric comparison |
| -9 | +4 cookie, +8 HRESULT | End of the pairing |
| -10 to -13 | +8 address, +0x10 cookie, +0x14 size or value, +0x18 passkey | [Incoming pairing](#pairing) |
| -14 | [New socket](#socket-message) | `ReceiveNewProfileSocketMessage` (0x100068D4) |
| -15 | +8 address, +0x10 profile GUID, +0x20 word PSM, +0x38 outgoing MTU, +0x3C incoming MTU, +0x40 channel handle, +0x44 byte, +0x48 connection cookie | `ReceiveNewProfileL2capConnectionMessage` (0x10006A64) |
| -16 | +8 address, +0x10 profile GUID | `ReceiveDisconnectProfile` (0x10006B8C) |
| -17 | +4 cookie, +8 Win32 error | Completes `ConnectProfileToDevice`, converted to HRESULT |
| -18 | +4 event GUID, +0x18 address, +0x20 byte type, +0x21 byte connected | `ReceiveDeviceHciEvent`, see [SCO audio](#sco-audio) |
| -19 | +4 cookie, +8 HRESULT, +0xC GUID of the trigger | `ReceiveRegisterTrigger` |

`DeviceStateSet::SetState` (0x1000975C) compares the fields with its cache and only calls the observers for what changed: `RemoteDeviceChanged` for address, state, class and name; `SignalStrengthChanged` for the RSSI; `AdvertisingDataChanged` for the data.

### Socket message

Message -14 carries a socket duplicated by the service (`WSADuplicateSocketW`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | -14 |
| 0x04 | 16 | Profile GUID |
| 0x14 | 0x274 | `WSAPROTOCOL_INFOW` |
| 0x288 | 0x1E | `SOCKADDR_BTH`: +0x28A address, +0x2A2 port |
| 0x2A6 | 0x1F2 | ?, pointer passed to the responder |
| 0x498 | 1 | Passed to the responder |
| 0x49C | 4 | Connection cookie |

`ReceiveNewProfileSocketMessage` looks for the responder of the profile, calls `WSASocketW` with the family, type and protocol of the structure (+0x60, +0x6C, +0x70), the `WSAPROTOCOL_INFOW` and `WSA_FLAG_OVERLAPPED`, then the responder callback. If there's no responder, or on a failure, the socket is closed, and message 16 reports failure. The L2CAP version does the same with the channel handle (`CloseHandle`).

### Callbacks

The callback interfaces are implemented by the users, so their names come from the log strings. All the methods are called from the event handlers. [BTAGService.dll](./btagservice.md) gives two of their IIDs: `IBtConnectionResponderCallback` `{EB794A01-E173-4D1E-9CD4-2037CDB529E3}` and `IBtScoAudioDeviceCallback` `{D9291D8E-B135-4E9F-85CD-2356C3B878F5}`.

| Interface | Index | Called for |
|-----------|-------|------------|
| `IBtCommandCallback` | 3 | `(context, HRESULT)` |
| `IBtConnectionObserverCallback` | 3 | `RadioStateChanged(state)` |
| | 4 | `RemoteDeviceChanged(address, state, class, name)` |
| | 5 | `ProfileConnectionChanged(address, profile, state)` |
| | 6 | `InitializationComplete()` |
| `IBtConnectionObserverCallback2` | 3 | `SignalStrengthChanged(address, rssi)` |
| | 4 | `AdvertisingDataChanged(address, size, data)` |
| `IBtConnectionResponderCallback` | 3 | New socket: `(SOCKET, SOCKADDR_BTH *, +0x2A6 *, byte)`, a negative result refuses it |
| | 4 | New L2CAP channel: `(handle, address, psm, outgoing MTU, incoming MTU, byte incoming)` (from [BthavctpSvc.dll](./bthavctpsvc.md#connection-manager)) |
| | 5 | Profile disconnected: `(address)` |
| `IBtPairingRequestCallback` | 3 | Get PIN: `(address)` |
| | 4 | Show passkey: `(address, size, passkey)` |
| | 5 | Compare numbers: `(address, value)` |
| | 6 | Complete: `(address, HRESULT)` |
| `IBtIncomingPairingCallback` | 3 | Get PIN: `(IBtPairingRequest *, address)` |
| | 4 | Show passkey: `(IBtPairingRequest *, address, size, passkey)` |
| | 5 | Compare numbers: `(IBtPairingRequest *, address, value)` |
| | 6 | Just works: `(IBtPairingRequest *, address)` |
| `IBtRegisterTriggerCallback` | 3 | `RegistrationCompleted(HRESULT, const GUID &)` |
| `IBtScoAudioDeviceCallback` | 3 | `ScoConnectionChanged(state, incoming)` |
| | 4 | `RequestAudioConnect()` |
| | 5 | `RequestAudioDisconnect()` |
| | 6 | `RequestChangeSpeakerVolume(level)` |
| | 7 | `RequestChangeMicrophoneVolume(level)` |
| | 8 | `RequestCodecId()` |

`RegisterObserverCallback` (0x1000579C) asks the observer for `IBtConnectionObserverCallback2` (optional), replays the radio state, each device (with RSSI and advertising data for an observer2) and each profile, then `InitializationComplete` if it already happened, and adds the observer to the set.

### Pairing

`IBtPairingRequest` has `StartPairing(AUTHENTICATION_REQUIREMENTS, BLUETOOTH_PAIRING_OOB_DATA *)`, `SetPin(int size, BYTE *pin)`, `AcceptPairing()` and `FailAuthentication()`.

`PairingRequest` (0x70 bytes) handles an outgoing pairing. The OOB data is copied only if its first DWORD has a bit of the mask 0xC000. States, offset +0x28:

| State | Meaning | Allowed call |
|-------|---------|--------------|
| 0 | Created | `StartPairing` |
| 1 | Started, waiting for the service | |
| 2 | PIN requested | `SetPin`: message 5, back to state 1 |
| 4 | Comparison requested | `AcceptPairing`: message 7, back to state 1 |
| 5 | Finished | |

`FailAuthentication` (0x1000C788) ends the request with 0x800704DC (`ERROR_NOT_AUTHENTICATED`): message 8 if it had started, then the complete callback. A non-zero return of the callback in message -6, -7 or -8 also calls `FailAuthentication`.

`IncomingPairing` (0x40 bytes, created by `ReceiveIncomingPairingMessage`, 0x100067B8) implements the same interface for the requests of a remote device. `StartPairing` returns `E_NOTIMPL` ("Method not implemented -- don't call"). The cookie comes from the service. The state is at offset +0x24: 0 created, 1 PIN requested, 2 accept requested, 3 finished. `SetPin`, `AcceptPairing` and `FailAuthentication` send messages 5, 7 and 8, then end the request. Without an incoming pairing callback, the client answers message 8 at once.

### SCO audio

`CScoAudioDevice` (0x30 bytes) doesn't use the pipe for its commands:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | `SynchronizedObject` |
| 0x08 | 4 | vtable `IBtScoAudioDevice` |
| 0x0C | 4 | Reference count |
| 0x10 | 8 | Device address |
| 0x18 | 1 | Volume |
| 0x19 | 1 | Headset |
| 0x1C | 4 | `IBtScoAudioDeviceCallback *` |
| 0x20 | 4 | Device handle, -1 when closed |
| 0x24 | 1 | Incoming; set to 1, cleared by `RequestAudioConnect` |
| 0x25 | 1 | Disconnecting, set by `DisconnectSco` |
| 0x28 | 4 | `CClient *` |

`Initialize(BYTE)` (0x1000E2BC) opens the first device of `GUID_BTHWP8_AUDIO_DEVICE_INTERFACE` (`GENERIC_READ | GENERIC_WRITE`, shared, `FILE_FLAG_OVERLAPPED`), returning S_OK even if this fails. `InitializeCallback` (0x1000E400) then sends `IOCTL_BTH_WP8_INITIALIZE_AUDIO_DEVICE`, and the first `IOCTL_BTH_WP8_GET_AUDIO_INDICATION`. `DestroyDevice` (0x1000E49C) closes the handle, removes the device from the map of `CClient` and releases the callback.

`IBtScoAudioDevice` (vtable 0x100032D0). All the IOCTLs are 0x41 device type, `METHOD_BUFFERED`, `FILE_ANY_ACCESS`, and are overlapped (`CreateIoctl`, 0x1000E860; `SendIoctlCallback`, 0x1000EA64):

| Index | Method | IOCTL | Function | Input | Output |
|-------|--------|-------|----------|-------|--------|
| 3 | `Initialize(BYTE)` | 0x411CC0 `IOCTL_BTH_WP8_INITIALIZE_AUDIO_DEVICE` | 0x730 | 0x10 | 0 |
| 5 | `AllowScoConnection()` | 0x411CC4 `IOCTL_BTH_WP8_ALLOW_INCOMING_SCO` | 0x731 | 0 | 0 |
| 6 | `ForbidScoConnection()` | 0x411CC8 `IOCTL_BTH_WP8_FORBID_INCOMING_SCO` | 0x732 | 0 | 0 |
| 7 | `ConnectSco()` | 0x411CCC `IOCTL_BTH_WP8_CONNECT_SCO` | 0x733 | 0 | 0 |
| 8 | `DisconnectSco()` | 0x411CD0 `IOCTL_BTH_WP8_DISCONNECT_SCO` | 0x734 | 0 | 0 |
| 9 | `SetAudioConnected()` | 0x411CD4 `IOCTL_BTH_WP8_SET_AUDIO_CONNECTED` | 0x735 | 0 | 0 |
| 10 | `SetAudioDisconnected()` | 0x411CD8 `IOCTL_BTH_WP8_SET_AUDIO_DISCONNECTED` | 0x736 | 0 | 0 |
| 11 | `ChangeSpeakerVolume(int)` | 0x411CDC `IOCTL_BTH_WP8_CHANGE_SPEAKER_VOLUME` | 0x737 | 4 | 0 |
| 12 | `ChangeMicrophoneVolume(int)` | 0x411CE0 `IOCTL_BTH_WP8_CHANGE_MICROPHONE_VOLUME` | 0x738 | 4 | 0 |
| | (internal) | 0x411CE4 `IOCTL_BTH_WP8_GET_AUDIO_INDICATION` | 0x739 | 0 | 0xC |
| 4 | `SetCodecId(int)` | 0x411CE8 `IOCTL_BTH_WP8_SET_CODEC_ID` | 0x73A | 4 | 0 |
| 13 | `DestroyDevice()` | | | | |

Input of `IOCTL_BTH_WP8_INITIALIZE_AUDIO_DEVICE`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | Device address |
| 0x08 | 1 | Volume |
| 0x09 | 1 | Headset |
| 0x0A | 1 | Parameter of `Initialize`, non-zero becomes 1; [BTAGService.dll](./btagservice.md#sco-audio) passes 1 when the hands-free uses codec negotiation (`AT+BAC`) |
| 0x0B | 5 | 0 |

Output of `IOCTL_BTH_WP8_GET_AUDIO_INDICATION` (`BTH_WP8_INDICATION_TYPE` at +0):

| +0 | +4 | +8 | Callback |
|----|----|----|----------|
| 0 | State | Byte incoming | `ScoConnectionChanged(state, incoming)`, not called if the state is 0 |
| 1 | | | `RequestAudioConnect` |
| 2 | | | `RequestAudioDisconnect` |
| 3 | Level | | `RequestChangeSpeakerVolume` |
| 4 | Level | | `RequestChangeMicrophoneVolume` |
| 5 | | | `RequestCodecId` |

`IndicationIoctlCompletedCallback` (0x1000EB48) always sends the next indication IOCTL while the handle is open. `ERROR_CANCELLED` (1223) and `ERROR_OPERATION_ABORTED` (995) aren't fatal.

The disconnection comes from message -18, in `CClient::ReceiveDeviceHciEvent` (0x10006E98), for all the SCO devices, whatever their address. `ScoConnectionChanged(0, 0)` is called:
- for `GUID_BLUETOOTH_HCI_EVENT` `{FC240062-1541-49BE-B463-84C4DCD7BF7F}`, if type = 2, connected = 0 and the device isn't disconnecting;
- for `GUID_BLUETOOTH_SCO_EVENT` `{BE43B0F1-79F4-4F21-BFBC-9A4529A4AC37}`, without any check of the type or the connected byte, and the disconnecting flag is cleared.

### Shutdown

`CClient::ShutdownCallback` (0x10005DD8):
1. Releases the incoming pairing callback, sends message 15 with 0.
2. Clears all the sets; pending commands, registrations and pairings get `ERROR_INVALID_STATE`.
3. Closes the pipe and releases it.
4. Sets `m_fIsShutdown`, cancels the timer and sets the shutdown event.

The SCO devices stay in the map until the destructor `CClient::~CClient` (0x10004EE4) releases them.

### Registry

| Key | Values |
|-----|--------|
| `HKLM\SYSTEM\ControlSet001\Services\BTConnMgr\Parameters` | `DebugConsoleEnabled` (`OutputDebugStringA` ?), `DebugSevLevel`: read in `DllMain` |
| `HKLM\SOFTWARE\Classes\CLSID\{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}` | Written by `DllRegisterServer` |

### ETW

Provider `{B67069E7-206C-4E4C-80CE-4663560EA07F}` (`Microsoft_WindowsPhone_Bluetooth_CMCL`), registered in `DllMain`.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 1000 | 0 | 0, 10 | 0x100 | 0x1 | `_ETWMESSAGE`, debug text (`EtwTraceMessage`, from `DebugPrintfInternal`) |

`__FatalError` (0x10008300) registers its own provider `{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}` (`Microsoft-WindowsPhone-Net-Debug`) and writes `NET_FATAL_ERROR` (event 100, level 2, task 1, keyword 0x1), as in the service. `DebugTerminateProcess` (0x100090CC) calls `DebugBreak` under a debugger, otherwise `RaiseFailFastException`, or `TelReportException` when `g_DebugNoFatalError` is set.
