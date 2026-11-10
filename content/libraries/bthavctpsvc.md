## BthavctpSvc.dll

The Bluetooth AVCTP transport of Windows Phone 8.1: the `BthAVCTPSvc` service, hosted by `svchost.exe`, which carries the AVCTP (Audio/Video Control Transport Protocol) packets of the AV remote control profile (AVRCP target).  
`BthavctpSvc.dll` is a small C++ DLL (61 440 bytes, 187 functions, the database has its full symbols). It registers with the Bluetooth connection manager as the responder of the AV remote control target class, and receives the L2CAP channels opened by the remote controllers (control PSM 0x17, browsing PSM 0x1B). It loads the profiles listed in the registry as COM objects, offers each of them the new channels, reads and writes the L2CAP channel handles with overlapped `ReadFile` / `WriteFile`, adds and removes the AVCTP header, cuts and reassembles the fragmented packets, and answers the commands for an unknown profile id. The profile itself (the AVRCP commands) isn't in this DLL.  
It uses [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) (COM class `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`), which talks to [BtConnectionManagerService.dll](./btconnectionmanagerservice.md). The profile is [BthAvrcp.dll](./bthavrcp.md) (CLSID `{208F7A6F-FB35-4686-9494-AB22B7B2CD78}`, "AVRCP profile interface to AVCTP"), which implements the [profile interface](#profile-interface).

Location on the phone: `C:\Windows\System32\BthavctpSvc.dll` ? (the extracted file has no notes).  
Service name: `BthAVCTPSvc`, svchost group `WPTCBNoNetwork`.  
Source folder: `src\net\bluetooth\product\services\avctp\service\`, `src\net\bluetooth\product\services\servicelib\` (strings).  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance`, `CLSIDFromString`, `CoFreeUnusedLibrariesEx` |
| api-ms-win-core-file-l1-2-1, api-ms-win-core-io-l1-1-1 | `ReadFile`, `WriteFile`, `GetOverlappedResult` |
| api-ms-win-core-threadpool-legacy-l1-1-0, -private-l1-1-0 | `QueueUserWorkItem`, `UnregisterWaitEx`, `RegisterWaitForSingleObjectEx` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `Sleep`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegEnumKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegDeleteValueW`, `RegDeleteKeyExW`, `RegCloseKey` |
| api-ms-win-service-* | `OpenSCManagerW`, `OpenServiceW`, `CreateServiceW`, `DeleteService`, `CloseServiceHandle`, `ChangeServiceConfig2W`, `ControlService`, `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-core-console-l1-1-0 | `SetConsoleCtrlHandler` |
| api-ms-win-core-processenvironment-l1-2-0 | `ExpandEnvironmentStringsW` |
| api-ms-win-core-libraryloader-l1-2-0 | `GetModuleFileNameW`, `GetModuleFileNameA`, `GetModuleHandleExW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-localization-l1-2-1 | `FormatMessageA` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-heap-l1-2-0, -handle-l1-1-0 | `GetProcessHeap`, `HeapAlloc`, `HeapFree`, `CloseHandle` |
| api-ms-win-core-processthreads-l1-1-2, -errorhandling-l1-1-2, -debug-l1-1-1, -rtlsupport-l1-2-0 | `GetCurrentProcess`, `GetCurrentThreadId`, `TerminateProcess`, `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `IsDebuggerPresent`, `DebugBreak`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | C and C++ runtime (`malloc`, `free`, `operator new`/`delete`, `_CxxThrowException`, `__CxxFrameHandler3`, `_initterm`, `_vsnwprintf`, `_wcsicmp`, …) |

The msvcrt, rtlsupport, and part of the debug, errorhandling and processthreads imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. The service manager, console and most registry imports come from the `CService` / `RegHelper` code shared with [BtConnectionManagerService.dll](./btconnectionmanagerservice.md) and [BTAGService.dll](./btagservice.md). There's no socket, WNF, RPC or pipe import.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) | `CoCreateInstance` `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`, IID `IBtConnectionResponder` `{4D1AC687-509C-48F7-A7BB-FE2B83A9C7DC}`, `CLSCTX_ALL` ([Connection manager](#connection-manager)) | Incoming L2CAP channels of the AV remote control target class, profile state |
| Profile DLLs ([BthAvrcp.dll](./bthavrcp.md)) | `CLSIDFromString` of each subkey of `Parameters\Profiles`, then `CoCreateInstance(CLSCTX_ALL)`, IID `{F7B743E7-B737-4AB7-B762-33D9FDDCFDD9}` ([Profiles](#profiles)) | The AVCTP users: the server DLL comes from the COM registration of the CLSID |
| L2CAP channel handles | Received from the connection manager (duplicated by the service with `DuplicateHandle`), `ReadFile` / `WriteFile` overlapped, `CloseHandle` ([Channels](#channels)) | AVCTP packets |

No process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `SvchostPushServiceGlobals` | 0x10003800 | `_SVCHOST_GLOBAL_DATA *` |
| 2 | `ServiceMain` | 0x100066A0 | `DWORD argc, LPWSTR *argv` |

The two exports are the `CService` code of [BtConnectionManagerService.dll](./btconnectionmanagerservice.md#exports): `SvchostPushServiceGlobals` links the global `BthAVCTPSvc` object in `CService::s_pFirstService`, with the group `WPTCBNoNetwork`. The value 0x87654321 in the first DWORD of the structure means a command line (`ParseArgs`: register, unregister, run as console program). `RegisterOneService` (0x10006940) writes `@<dll>,-101` and `@<dll>,-102`, and the command line `svchost.exe -k WPTCBNoNetwork`.

### Global object

`g_AVCTPService` (at 0x1000A050) is built by a dynamic initialiser (0x10003770), destroyed by `atexit`. It derives from `CService` and from `SynchronizedObject` (at +0x58): the work is done by `AVCTPService::Dispatch`, one event at a time, on the `Synchronizer` queue (same model as the connection manager).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `CService` |
| 0x04 | 4 | `L"BthAVCTPSvc"` |
| 0x08, 0x0C | 4, 4 | 101, 102 (resource ids) |
| 0x28 | 4 | Next `CService` |
| 0x54 | 4 | Index mask of the service |
| 0x58 | 8 | `SynchronizedObject` (vtable, `Synchronizer *`) |
| 0x60 | 4 | List of the profiles: nodes of 0xC bytes (profile interface, `AVCTPProfileUser *`, next) |
| 0x64 | 4 | List of the `AVCTPChannel` (linked by channel+0x0C) |
| 0x68 | 4 | `IBtConnectionResponder *` |
| 0x6C | 4 | Id of the responder registration |

### Startup

`_DllMainCRTStartup` (0x10008F18): CRT. `DllMain` (0x100037E4) only calls `DisableThreadLibraryCalls`.

`CService::ServiceMain` calls `AVCTPService::OnStart` (0x10003944), which sets `AvctpOutOfMemory` as `new` handler and queues event 0. `AVCTPService::DispatchServiceStart` (0x10003980):
1. `McGenEventRegister` of the [ETW](#etw) provider.
2. If a responder already exists: `UnregisterCallback(id)`, `Shutdown`, `Release`.
3. `CoCreateInstance` of the connection manager client, then `RegisterCallback` of the AV remote control target class ([Connection manager](#connection-manager)). A failure of either is fatal (`__FatalError`, then `SERVICE_STOPPED`).
4. `PopulateProfiles` ([Profiles](#profiles)).
5. `SERVICE_RUNNING`.

`OnStop` (0x10003A84): `SERVICE_STOP_PENDING` and event 1. `DispatchServiceStop` (0x10003AB8) unregisters and releases the responder, calls method 9 (`Shutdown` ?) of each profile and releases the profile and its `AVCTPProfileUser`, releases the channels, `McGenEventUnregister`, `CoFreeUnusedLibrariesEx(0, 0)` (unloads the profile DLLs), and `SERVICE_STOPPED`.

### Events

`AVCTPService::Dispatch` (0x1000437C):

| Event | Queued by | Action |
|-------|-----------|--------|
| 0, 1 | `OnStart`, `OnStop` | Start, stop |
| 2 | `ConnectionResponder::AcceptL2CapConnection` | `DispatchBTCMConnectionRequest` |
| 3 | `ConnectionResponder::DisconnectConnection` | `DispatchBTCMDisconnectionRequest` |
| 4 | `AVCTPProfileUser` (events 10 and 11) | A profile released a channel: `RemoveChannel` if no other profile uses it (otherwise "cannot disconnect channel … as it is in use") |

### Connection manager

`DispatchServiceStart` creates the client with `CoCreateInstance(CLSID {101C5B9F-…}, NULL, CLSCTX_ALL, IID_IBtConnectionResponder)`, and calls `IBtConnectionResponder::RegisterCallback(AVRemoteControlTargetServiceClass_UUID {0000110C-0000-1000-8000-00805F9B34FB}, ConnectionResponder, &id)`. This is the class that [BtConnectionManagerService.dll](./btconnectionmanagerservice.md) uses for its `AVRCP` local service (control code 0x84).

`ConnectionResponder` (0xC bytes: vtable, reference count, `AVCTPService *`) implements `IBtConnectionResponderCallback` `{EB794A01-E173-4D1E-9CD4-2037CDB529E3}`:
- `AcceptRfcommConnection` (0x1000423C) is fatal: "AVCTP does not support RFCOMM connections, this should not be called";
- `AcceptL2CapConnection(HANDLE, address, psm, outMTU, inMTU, BYTE incoming)` (0x1000426C) returns `E_FAIL` for an outgoing connection ("AVCTP does not support outgoing connections for Apollo") or a PSM other than 0x17 (control) and 0x1B (browsing); otherwise it queues event 2 with the handle, address, PSM and MTUs;
- `DisconnectConnection(address)` (0x100042F4) queues event 3.

`DispatchBTCMConnectionRequest` (0x1000443C):
1. Channel type 0 (`Control`) for PSM 0x17, 1 (`Browsing`) for PSM 0x1B. An existing channel of the same type with the device is only logged.
2. Creates an `AVCTPChannel` (0xB0 bytes, [Channels](#channels)) with the handle, the address, the MTUs, and a read buffer of the incoming MTU (`HeapAlloc`), and adds it to the list.
3. Adds the channel to every profile (state 2), then queues event 0 of each `AVCTPProfileUser`, which calls the `IndicateConnect` method of the profile with the type, the address and the outgoing MTU minus 3 (state 3).
4. `IBtConnectionResponder::SetProfileState(address, AV remote control target class, 2)` (connected).

On failure (unknown PSM: 2, out of memory: 4, no profile: 3) the handle is closed and the profile state is set to 0 (disconnected).

`DispatchBTCMDisconnectionRequest` (0x10004710), for the browsing then the control channel of the device: each profile that has the channel connected (state 4) gets `IndicateDisconnect`; the channel is closed (channel event 1) and removed. `RemoveChannel` (0x10003E38) sets the channel state 2 and the profile state 0 (disconnected).

### Profiles

`PopulateProfiles` (0x10003B70) enumerates the subkeys of `HKLM\SYSTEM\CurrentControlSet\Services\BthAvctpSvc\Parameters\Profiles`. The name of each subkey is a CLSID (`CLSIDFromString`, fatal on error). It reads `ProfileName` (string) and `ProfileID` (DWORD, 0 when missing) from the subkey, and creates the profile with `CoCreateInstance(clsid, NULL, CLSCTX_ALL, {F7B743E7-B737-4AB7-B762-33D9FDDCFDD9})`. A failure is only logged ("[AVCTPProfileUserSet::Populate] Failed to CoCreateInstance"). For each profile it creates an `AVCTPProfileUser` and calls method 3 of the profile with the `AVCTPProfileUser` and the value 4: the bytes the profile keeps free in front of the data of each `BD_BUFFER` it sends, room for the [AVCTP header](#avctp-packets) ([BthAvrcp.dll](./bthavrcp.md#profile-interface) `Initialization`).

`AVCTPProfileUser` (0x424 bytes) is the object given to the profile:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `IBtAVCTPUserInterface` `{DED09705-3DE5-443B-ADFD-EA6A37F10917}` |
| 0x04 | 4 | vtable `IAVCTPChannelCallback` `{11A2341E-10CE-498C-9038-A481ED3CF2B5}` |
| 0x08 | 8 | `SynchronizedObject` (vtable, `Synchronizer *` of the service) |
| 0x10 | 4 | Reference count |
| 0x14 | 4 | Profile interface |
| 0x18 | 4 | List of the channels of the profile: nodes of 0x14 bytes (next, `AVCTPChannel *`, state: 2 new, 3 indicated, 4 connected, 5 closed) |
| 0x1C | 2 | `ProfileID`: the AVCTP PID, compared with the 2 bytes of the header as a little-endian WORD |
| 0x1E | 0x400 | `ProfileName` (WCHAR[512]) |
| 0x420 | 4 | `AVCTPService *` |

`IBtAVCTPUserInterface`, called by the profile; each method queues an event and returns `E_OUTOFMEMORY` if the allocation fails:

| Index | Method | Address | Event |
|-------|--------|---------|-------|
| 3 | `ConnectResponse(AVCTP_CHANNEL_TYPE, address, WORD result)` | 0x10004E28 | 5 |
| 4 | `SendMessage(AVCTP_CHANNEL_TYPE, address, BYTE transaction, AVCT_TYPE, BD_BUFFER *)` | 0x10004F74 | 6 |
| 5 | `DisconnectConnection(AVCTP_CHANNEL_TYPE, address)` | 0x10005364 | 9 |

### Profile interface

IID `{F7B743E7-B737-4AB7-B762-33D9FDDCFDD9}` (`IBtAVCTPProfileInterface`), implemented by the profile; the names come from the log strings of the caller and from the symbols of [BthAvrcp.dll](./bthavrcp.md#profile-interface) (`Initialization`, `ConnectionIndication`, `DisconnectIndication`, `MessageRecvIndication`, `DisconnectOut`, `ConnectResult`, `Shutdown`).

| Index | Called from | Parameters | Meaning |
|-------|-------------|------------|---------|
| 3 | `PopulateProfiles` | `IBtAVCTPUserInterface *`, 4 | `Initialization`: the interface to call back and the header space |
| 4 | Event 0 | `AVCTP_CHANNEL_TYPE`, address, `WORD` MTU | `IndicateConnect`: a new channel; the profile answers with `ConnectResponse` |
| 5 | Event 1 | `AVCTP_CHANNEL_TYPE`, address | `IndicateDisconnect` |
| 6 | Event 3 | `AVCTP_CHANNEL_TYPE`, address, `BYTE` transaction, `AVCT_TYPE` (1 command, 2 response), `BYTE *` packet, `WORD` offset, `WORD` size | `IndicateMessageRecv`: the message starts at packet + offset |
| 7 | `DispatchDisconnectConnection` (and event 4, never queued) | `AVCTP_CHANNEL_TYPE`, address | `DisconnectOut`: end of a disconnection asked by the profile (BthAvrcp.dll declares a third `int` result parameter, only logged) |
| 8 | `DispatchConnectResponse` | `AVCTP_CHANNEL_TYPE`, address | `ConnectResult`: end of the connect response (BthAvrcp.dll reads a third `int` result, 0 = connected) |
| 9 | `DispatchServiceStop` | none | `Shutdown` |

`AVCTPProfileUser::Dispatch` (0x100054B8):

| Event | Action |
|-------|--------|
| 0, 1, 3 | Methods 4, 5 and 6 of the profile (3 only if the channel is still in the list of the profile, otherwise "Discarding received message") |
| 2 | `DispatchIncomingMessage` ([Packets](#avctp-packets)) |
| 5 | `DispatchConnectResponse` (0x10004E90): result 0 and channel in state 3 → channel connected (state 1), profile state 4, the profile becomes the callback of the channel and the first `ReadFile` starts. Any other result removes the channel from the profile and, if no profile uses it, queues event 10. Then method 8 |
| 6 | `DispatchSendMessage` ([Packets](#avctp-packets)) |
| 9 | `DispatchDisconnectConnection` (0x100053C0): removes the channel of the profile, closes it (channel event 1), queues event 10, then method 7 |
| 10 | Queues event 4 of the service |
| 11 | `ChannelClosed` (read or write error): `IndicateDisconnect`, then event 4 of the service |

### Channels

`AVCTPChannel` (0xB0 bytes, constructor 0x1000594C) owns the L2CAP handle. It derives from `SynchronizedObject` (its own events) and calls back the `IAVCTPChannelCallback` of the profile user (`IncomingMessage`, `ChannelClosed`).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | `SynchronizedObject` (vtable, `Synchronizer *`) |
| 0x08 | 4 | Reference count |
| 0x0C | 4 | Next channel of the service |
| 0x10 | 4 | `IAVCTPChannelCallback *` (set by the connect response) |
| 0x14 | 4 | `AVCTP_CHANNEL_TYPE`: 0 `Control`, 1 `Browsing` |
| 0x18 | 4 | Name of the type |
| 0x20 | 8 | Address of the device |
| 0x2C | 4 | Number of profiles using the channel |
| 0x34 | 4 | State: 0 new, 1 connected, 2 closed |
| 0x38 | 4 | Read buffer (incoming MTU bytes) |
| 0x40 | 4 | `FragmentList`: packets being reassembled |
| 0x44 | 0x14 | `OVERLAPPED` of the read, event at 0x6C |
| 0x58 | 0x14 | `OVERLAPPED` of the write, event at 0x70 |
| 0x6C, 0x70 | 4, 4 | Read and write events (`CreateEventW`, auto reset) |
| 0x74, 0x78 | 4, 4 | Waits on them (`RegisterWaitForSingleObjectEx`, `ReadCompletedStatic` / `WriteCompletedStatic`) |
| 0x7C | 4 | `AVCTPProfileUser *` |
| 0x82 | 2 | Incoming MTU |
| 0x84 | 2 | Outgoing MTU |
| 0x88 | 4 | L2CAP handle (-1 when closed) |
| 0x8C | 1 | 1 |
| 0x90 | 0x14 | Queue of the writes waiting (`std::deque<std::vector<BYTE> *>`) |
| 0xA8 | 4 | Write in progress (`std::vector<BYTE> *`) |

Channel events (`AVCTPChannel::Dispatch`, 0x10005E20): 0 write (`WriteCallback`: starts the `WriteFile` or queues the buffer), 1 close (`CloseHandle`, state 2, the queued writes are dropped), 2 read complete, 3 write complete; another value is fatal.

`StartRead` (0x10005E70) calls `ReadFile(handle, buffer, incoming MTU, NULL, &overlapped)`. `ReadCompletedCallback` (0x10005F24) passes the bytes to `IncomingMessage` (copied, then event 2 of the profile user) and starts the next read. `StartWrite` (0x10006010) calls `WriteFile` with the next buffer; `WriteCompletedCallback` (0x100060D4) starts the next queued buffer. The errors 64, 232, 995, 109, 1167 and 1223 close the channel (`ChannelClosed`); any other error is fatal.

### AVCTP packets

Header written and parsed by the service (Bluetooth AVCTP format):

| Byte | Bits | Comment |
|------|------|---------|
| 0 | 7…4 | Transaction label |
| | 3…2 | Packet type: 0 single, 1 start, 2 continue, 3 end |
| | 1 | C/R: 0 command, 1 response (`AVCT_TYPE` 2) |
| | 0 | IPID: 1 = invalid profile id (only in the answer below) |
| 1 | | Start packet only: number of packets |
| 1…2 (single), 2…3 (start) | | Profile id, compared with `ProfileID` |

`DispatchIncomingMessage` (0x100056C4):
- single packet: the PID must be the one of the profile and the channel connected for it; the message (after the 3-byte header) goes to method 6 of the profile;
- start packet: same check, then `FragmentList::AddNewPkt` (0x100047F4) allocates number of packets × incoming MTU bytes (at most 128 000) and copies the data;
- continue and end packets (1-byte header): `AddContinuePkt` (0x100048D0) appends the data; the end packet with the expected count gives the whole message to the profile;
- a command with another PID gets a 3-byte answer: `transaction << 4 | 3` (single, response, IPID) and the received PID.

`DispatchSendMessage` (0x10004FF4) looks up the channel of the profile, which must be connected. The `BD_BUFFER` must keep at least 4 free bytes before the data: the 3-byte header (transaction, C/R from the `AVCT_TYPE`, IPID 0, PID of the profile) is written there, and `SendData` (0x10005140) copies the bytes into a `std::vector` queued to the channel (event 0). If the data plus 3 is bigger than the outgoing MTU, `SendFragPkt` (0x100051D8) sends a start packet (4-byte header with the number of packets) and continue / end packets (1-byte header); fragmenting on the browsing channel is fatal ("Attempt to Fragment Browse Packet"). The buffer is freed (`HeapFree`) unless its +0x0C field is set.

`BD_BUFFER` (`BufferAlloc`, 0x10008864, `HeapAlloc` of size + 0x14):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Size of the data area |
| 0x04 | 4 | Offset of the first byte |
| 0x08 | 4 | Offset of the end |
| 0x0C | 4 | Don't free after sending |
| 0x10 | 4 | Data pointer (+0x14 for `BufferAlloc`) |

### Registry

| Key | Values |
|-----|--------|
| `HKLM\SYSTEM\CurrentControlSet\Services\BthAvctpSvc\Parameters\Profiles\{CLSID}` | `ProfileName` (string), `ProfileID` (DWORD): one subkey per [profile](#profiles) |
| `SYSTEM\CurrentControlSet\Services\%s\Parameters`, `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Svchost` | `ServiceDll`, `ServiceDllUnloadOnStop`, group: written by `RegisterOneService` |

### ETW

Provider `{7355CA5C-21C2-4834-A8A0-3057011B4533}` (`Microsoft_WindowsPhone_Bluetooth_AVCTP`), registered in `DispatchServiceStart`.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 1000 | 0 | 0, 10 | 0x100 | 0x1 | `_ETWMESSAGE`, debug text (`AVCTPEtwMessage`, 0x1000499C, through `FormatMessageA`) |

`__FatalError` (0x10004074) writes `NET_FATAL_ERROR` with the provider `Microsoft-WindowsPhone-Net-Debug` `{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}`, as in the connection manager.
