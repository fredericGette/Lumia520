## BTAGService.dll

The Bluetooth audio gateway of Windows Phone 8.1: the `BTAGService` service, hosted by `svchost.exe`, which implements the phone side of the Hands-Free Profile (HFP AG).  
`BTAGService.dll` is a C++ DLL (126 976 bytes, 458 functions, the database has its full symbols). It registers with the Bluetooth connection manager as the responder of the HFP audio gateway class, and receives the RFCOMM socket of each hands-free device. It parses the AT commands of the device and answers them from the state of the phone (calls, network, signal, battery, phonebook, call history), and drives the calls through the phone API (`phoneom`). It opens and closes the SCO audio link with the SCO functions of the connection manager client, suspends A2DP streaming during calls and voice recognition, and offers a named pipe `\\.\Pipe\BTAudioGateway` to the speech / audio components. It publishes its state in a WNF state of the `BLTH` owner.  
It uses [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) (COM class `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`), which talks to [BtConnectionManagerService.dll](./btconnectionmanagerservice.md). The client side of its pipe is [BTAudioGatewayClient.dll](./btaudiogatewayclient.md) (COM class `{EDFC5E7D-115E-4939-BFE9-59F275F2B230}`); the users of that class aren't known.

Location on the phone: `C:\Windows\System32\BTAGService.dll` ? (the extracted file has no notes).  
Service name: `BTAGService`, svchost group `WPNoNetwork`.  
Source folder: `src\net\bluetooth\product\services\hfp\server\`, `src\net\bluetooth\product\services\servicelib\`, `src\net\bluetooth\product\services\connectionmanager\btaudiohelper\` (strings).  

### Imports

| DLL | Functions |
|-----|-----------|
| phoneom | `PhoneAPIInitialize`, `PhoneAPIUninitialize`, `PhoneAddListener`, `PhoneRemoveListener`, `PhoneGetState`, `PhoneFreeCallInfo`, `PhoneGetDefaultOutgoingLine`, `PhoneGetProviderLineInfo`, `PhoneGetProviderLineServiceInfo`, `PhoneIsActionAvailable`, `PhoneDial`, `PhoneEnd`, `PhoneAcceptIncomingEx`, `PhoneRejectIncoming`, `PhoneSetHold`, `PhonePrivate`, `PhoneDropAccept`, `PhoneConference`, `PhoneSwap`, `PhoneSendDTMF` |
| PHONEINFO | `QueryPhoneInformation`, `GetPhoneVersion` |
| UserDataModelClient | `UdmCreateDataSession`, `UdmCreateSyncCallbackHandler` |
| PIMSTORE | `FindMatchingContactEx` |
| WS2_32 | `WSAStartup`, `WSACleanup`, `WSARecv`, `WSASend`, `WSACreateEvent`, `WSASetEvent`, `WSAGetOverlappedResult`, `WSAGetLastError`, `closesocket` |
| ntdll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlPublishWnfStateData`, `NtQueryWnfStateData`, `WinSqmStartSession`, `WinSqmEndSession`, `WinSqmIncrementDWORD`, `WinSqmSetIfMaxDWORD`, `WinSqmAddToStreamEx` |
| [SecRuntime](./secruntime.md) | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor` |
| bcrypt | `BCryptOpenAlgorithmProvider`, `BCryptCloseAlgorithmProvider`, `BCryptGetProperty`, `BCryptCreateHash`, `BCryptHashData`, `BCryptFinishHash`, `BCryptDestroyHash` |
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance`, `CoTaskMemFree` |
| api-ms-win-core-namedpipe-l1-2-0 | `CreateNamedPipeW`, `ConnectNamedPipe` |
| api-ms-win-core-file-l1-2-1, api-ms-win-core-io-l1-1-1 | `ReadFile`, `WriteFile`, `GetOverlappedResult` |
| api-ms-win-core-threadpool-l1-2-0, -legacy-l1-1-0, api-ms-win-core-kernel32-legacy-l1-1-1 | `CreateThreadpoolWait`, `SetThreadpoolWait`, `CloseThreadpoolWait`, `CreateThreadpoolCleanupGroup`, `CloseThreadpoolCleanupGroup`, `QueueUserWorkItem`, `CreateTimerQueueTimer`, `DeleteTimerQueueTimer`, `UnregisterWaitEx`, `RegisterWaitForSingleObject` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep`, `WaitOnAddress`, `WakeByAddressAll`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegDeleteValueW`, `RegDeleteKeyExW`, `RegCloseKey` |
| api-ms-win-service-* | `OpenSCManagerW`, `OpenServiceW`, `CreateServiceW`, `DeleteService`, `CloseServiceHandle`, `ChangeServiceConfig2W`, `ControlService`, `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-core-console-l1-1-0 | `SetConsoleCtrlHandler` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `LoadStringW`, `FreeLibrary`, `GetModuleHandleExW`, `GetModuleFileNameW`, `GetModuleFileNameA`, `DisableThreadLibraryCalls` |
| api-ms-win-core-string-l1-1-0, -localization-l1-2-1 | `MultiByteToWideChar`, `WideCharToMultiByte`, `FormatMessageA` |
| api-ms-win-core-sysinfo-l1-2-2 | `GetTickCount`, `GetTickCount64`, `GetLocalTime` |
| api-ms-win-core-processenvironment-l1-2-0 | `ExpandEnvironmentStringsW` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-heap-l1-2-0, -heap-obsolete-l1-1-0, -handle-l1-1-0 | `GetProcessHeap`, `LocalFree`, `CloseHandle` |
| api-ms-win-core-processthreads-l1-1-2, -errorhandling-l1-1-2, -debug-l1-1-1, -rtlsupport-l1-2-0 | `GetCurrentProcess`, `GetCurrentThreadId`, `TerminateProcess`, `GetLastError`, `SetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `RaiseFailFastException`, `IsDebuggerPresent`, `DebugBreak`, `OutputDebugStringW`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | C and C++ runtime (`malloc`, `free`, `operator new`/`delete`, `_CxxThrowException`, `__CxxFrameHandler3`, `_initterm`, `_vsnprintf`, `sscanf_s`, `strtok`, `atoi`, …) |

The msvcrt, rtlsupport, and part of the debug, errorhandling and processthreads imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. The service manager, bcrypt and `WinSqm*` imports come from the code shared with [BtConnectionManagerService.dll](./btconnectionmanagerservice.md) (`CService`, `BtSqm*`: hash of the device addresses for SQM).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) | `CoCreateInstance` `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`, IID `IBtConnectionResponder`, `CLSCTX_ALL` ([Connection manager](#connection-manager)) | Incoming HFP connections, profile state, SCO audio |
| `\\.\Pipe\BTAudioGateway` | `CreateNamedPipeW` (server, [Pipe](#pipe-btaudiogateway)) | Voice recognition and audio requests of local clients ([BTAudioGatewayClient.dll](./btaudiogatewayclient.md)) |
| `BthCommonRes.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)`, `LoadStringW` (`ResourceHelperGetString`, 0x10016CF8) | Strings 101 (Cortana enabled) or 102: name of the Cortana entry of the phonebook (`GetCortanaName`, 0x10011AE8) |
| POOM `Application` `{05058F23-20BE-11D2-8F18-0000F87A4335}` | `CoCreateInstance`, IID `IPOutlookApp3` `{A65CCAEB-6558-4656-AD3D-ECCC00D00F0D}`, `CLSCTX_INPROC_SERVER` | Contacts: caller names (`FindMatchingContactEx`) and the `AT+CPBR` phonebook; server DLL not known |
| Call history of the User Data Model | `UdmCreateDataSession` (`CallHistoryProvider`, `GetMostRecentlyDialedPhoneNumber`) | `AT+BLDN`, phonebooks `DC`, `MC`, `RC` |
| `MMDeviceEnumerator` `{BCDE0395-E52F-467C-8E3D-C4579291692E}` | `CoCreateInstance`, IID `IMMDeviceEnumerator` `{A95664D2-9614-4F35-A746-DE8DB63617E6}` ([A2DP suspender](#a2dp-suspender)) | Bluetooth render endpoints, then `IKsControl` on their topology filter |

No process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `SvchostPushServiceGlobals` | 0x10007C7C | `_SVCHOST_GLOBAL_DATA *` |
| 2 | `ServiceMain` | 0x100138F8 | `DWORD argc, LPWSTR *argv` |

The two exports are the `CService` code of [BtConnectionManagerService.dll](./btconnectionmanagerservice.md#exports): `SvchostPushServiceGlobals` links the global `BTAGService` object in `CService::s_pFirstService`, with the group `WPNoNetwork`. The value 0x87654321 in the first DWORD of the structure means a command line (`ParseArgs`: register, unregister, run as console program). `RegisterOneService` writes `@<dll>,-101` and `@<dll>,-102` (display name and description ?), and the command line `svchost.exe -k WPNoNetwork`.

### Global object

`g_BTAGService` (at 0x1001A4F8) is built by a dynamic initialiser (`BTAGService::BTAGService`, 0x10007F78), destroyed by `atexit`. It derives from `CService` and from `SynchronizedObject` (at +0x58): all the work is done by `BTAGService::Dispatch`, one event at a time, on the `Synchronizer` queue (same model as the connection manager).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `CService` |
| 0x04 | 4 | `L"BTAGService"` |
| 0x08, 0x0C | 4, 4 | 101, 102 (resource ids) |
| 0x58 | 8 | `SynchronizedObject` (vtable, `Synchronizer *`) |
| 0x60 | 4 | Event set when the stop is complete |
| 0x64 | 4 | `PipeClient *` waiting for the next pipe client |
| 0x68 | 0xC | Vector of the connected `PipeClient *` |
| 0x78 | 4 | Value of the [WNF state](#wnf-states) |
| 0x7C, 0x80, 0x84 | 4 × 3 | WNF subscriptions: battery, call endpoint, background media |
| 0x88 | 4 | `AsyncPhoneController *` |
| 0x8C | 4 | Network registration state (`PhoneGetProviderLineServiceInfo`) |
| 0x90 | 0x80 | Operator name (WCHAR[64]) |
| 0x110 | 4 | Signal strength |
| 0x114 | 0x40 | Own number, canonical form (`AT+CNUM`) |
| 0x154 | 0x80 | Number dialled by `ATD>1` (second number of `PhoneGetProviderLineInfo`, voicemail ?) |
| 0x1D4 | 8 | `std::map<unsigned, BTAG_PHONE_CALL>`: calls by call index |
| 0x1E4…0x1FC | 4 × 7 | Call counts: active, held, held mask, active + held, incoming, outgoing, state 6 |
| 0x200 | 4 | Call index of the call being set up |
| 0x204 | 4 | Last `+CREG` status |
| 0x208 | 4 | `IPOutlookApp3 *` |
| 0x20C | 4 | `IBtConnectionResponder *` |
| 0x210 | 4 | Id of the responder registration |
| 0x218 | 4 | HF connection state (`BLUETOOTH_CONNECTION_STATE`: 0 disconnected, 1 connecting, 2 connected, 3 disconnecting) |
| 0x21C | 1 | Profile is HFP (1) or HSP (0) |
| 0x220 | 4 | RFCOMM socket |
| 0x228 | 8 | Address of the connected device |
| 0x230 | 4 | Connecting timer (15 s) |
| 0x234 | 4 | `IgnoreCHUPAfterVCEndsPeriodMs` |
| 0x238 | 4 | Tick count at the end of the last virtual call |
| 0x23C | 4 | `HFConnection *` |
| 0x240 | 0x400 | Response buffer, sent at the end of each event |
| 0x640 | 4 | Final result: 0 none, 1 `ERROR`, 2 `OK` |
| 0x644 | 4 | Flags of the response (see [Send flags](#rfcomm-link)) |
| 0x648 | 1 | Replace the 0xFF bytes by 0 in the response |
| 0x64A | 2 | AG supported features (`SupportedFeaturesMask`, default 0x3E7) |
| 0x64C | 1 | Service level connection: indicators read |
| 0x64E | 2 | HF supported features (`AT+BRSF`) |
| 0x650, 0x652 | 2, 2 | HF speaker gain (`AT+VGS`), microphone gain (`AT+VGM`) |
| 0x654 | 2 | Indicator mask (`AT+BIA`), bits = indicator index |
| 0x656 | 1 | Indicator events enabled (`AT+CMER`) |
| 0x657, 0x658, 0x659 | 1 × 3 | `AT+CCWA`, `AT+CLIP` enabled; `AT+COPS=3,0` received |
| 0x65C | 4 | `AT+CMEE` |
| 0x660 | 1 | Codec negotiation (`AT+BAC` received) |
| 0x664 | 0xC | Codecs of the HF (`std::vector<BYTE>`) |
| 0x67C…0x694 | 4 × 7 | Indicators 1…7: service, call, callsetup, callheld, signal, roam, battchg |
| 0x698 | 4 | Battery level 0…5 |
| 0x6A0 | 1 | In call |
| 0x6A4 | 4 | Ring timer (5 s) |
| 0x6A8 | 8 | `BTAGVirtualCallManager`: `BTAGService *`, state (0 `VCS_Closed`, 1 `VCS_Open`) |
| 0x6B0 | 1 | `NeverUseVirtualCallsForVR` |
| 0x6B4 | 1 | In voice recognition (`+BVRA: 1` sent) |
| 0x6B8 | 0x18 | Timer: deferred audio connection (`DeferredConnectAudioTimerDurationMs`) |
| 0x6D0 | 0x18 | Timer: speech start pending (5 s) |
| 0x6E0 | 1 | `BTAGManagesSCO` |
| 0x6E4 | 4 | `AudioConnectionFSM *` |
| 0x6E8 | 4 | Codec connection status: 0 none, 1 `+BCS` sent, 2 ready |
| 0x6EC | 4 | Selected codec (1 CVSD, 2 mSBC) |
| 0x6F4 | 4 | `PhoneNumberProvider *` |
| 0x6F9 | 1 | `DisableCallHistoryProvider` |
| 0x6FC | 4 | Character set (`AT+CSCS`) |
| 0x700 | 1 | Voice recognition started by dialling the Cortana number |
| 0x704 | 0x48 | `A2DPSuspender` |
| 0x74C | 4 | SQM session (`g_WpSqmBiWeeklySession`) |

### Startup

`_DllMainCRTStartup` (0x1001825C): CRT. `DllMain` (0x10007C60) only calls `DisableThreadLibraryCalls`.

`CService::ServiceMain` calls `BTAGService::OnStart` (0x1000838C), which queues event 0. `BTAGService::DispatchServiceStart` (0x100083AC):
1. Reads `SupportedFeaturesMask` (default 0x3E7), `BTAGManagesSCO` (1), `DeferredConnectAudioTimerDurationMs` (250), `DisableCallHistoryProvider` (0), `IgnoreCHUPAfterVCEndsPeriodMs` (9000) from `HKLM\SYSTEM\CurrentControlSet\Services\BTAGService\Parameters\Settings`.
2. `McGenEventRegister`, then `DebugEnabled` (1), `DebugZoneMask` (-1), `DebugSevLevel` (3) from the same key. Sets `BtagOutOfMemory` as `new` handler.
3. `PhoneAPIInitialize`, creates the first `PipeClient` ([Pipe](#pipe-btaudiogateway)), `WSAStartup(0x202)`.
4. `BTCMAttach`: `CoCreateInstance` of the connection manager client, then `BTCMRegisterResponderInterfaces` ([Connection manager](#connection-manager)).
5. Creates the `AsyncPhoneController` ([Phone](#phone)).
6. `SERVICE_RUNNING` (or `SERVICE_STOPPED` if `PhoneAPIInitialize` failed), and sets bit 0x01 of the WNF state.
7. Reads `NeverUseVirtualCallsForVR` (0), subscribes to the three [WNF states](#wnf-states), starts the SQM session `g_WpSqmBiWeeklySession`, and creates the POOM `Application` (`IPOutlookApp3`).

`OnStop` (0x100086A0): `SERVICE_STOP_PENDING`, queues event 1 and waits 10 s for the stop event. `DispatchServiceStop` (0x100087A8) clears bit 0x01, unsubscribes the WNF states, shuts down the pipe clients, disconnects the device, `BTCMDetach`, `WSACleanup`, shuts down the phone controller, `PhoneAPIUninitialize`, and `SERVICE_STOPPED`.

### Events

`BTAGService::Dispatch` (0x1000A8F4), the events of the global object. After each event, the response buffer and the final result (`\r\nOK\r\n` or `\r\nERROR\r\n`) are sent to the device in one `HFConnection::SendString`.

| Event | Queued by | Action |
|-------|-----------|--------|
| 0, 1 | `OnStart`, `OnStop` | Start, stop |
| 2 | `ConnectionResponder::AcceptRfcommConnection` | `DispatchConnectionRequest` |
| 3 | Connecting timer (15 s) | Disconnects if the service level connection isn't up |
| 4 | `ConnectionResponder::DisconnectConnection` | `Disconnect` if the address is the connected device |
| 5 | `HFConnection` | One AT command received: `DispatchHFCommandReceived` |
| 6 | `HFConnection` | Socket disconnected: `Disconnect` |
| 7, 8 | `AudioConnectionFSM` (driver request) | Sends `+VGM: n`, `+VGS: n` |
| 10 | Ring timer (every 5 s) | `RING`, and `+CLIP: "number",128` if enabled; sets bit 0x20 |
| 11, 12 | `PipeClient` | Pipe client connected, closed |
| 13 | `PipeClient` | [Pipe request](#pipe-btaudiogateway) |
| 14 | WNF callback | [Battery level](#wnf-states) |
| 15 | `HFConnection` (send complete with flags) | Bit 0: SLC response sent; bit 1: call state allows SCO; bit 2: codec setup (event 25) |
| 16, 17 | Codec code, `AudioConnectionFSM` | Set or clear WNF bits |
| 18 | `AudioConnectionFSM::RequestAudioConnect`, pipe | Connect audio, at once or after the deferred timer |
| 19 | Event 23 | Begin voice command |
| 20 | ? | End voice command: closes audio |
| 21 | ? | Start speech recognition |
| 22 | `AudioConnectionFSM` (SCO closed during voice recognition or a virtual call) | End speech recognition |
| 23 | Deferred audio timer | Connect audio, or queue event 19 |
| 24 | `AsyncPhoneController` | [Phone event](#phone) |
| 25 | `AT+BAC`, `RequestCodecId`, … | `SelectCodec`, then `+BCS: n` |
| 26 | Speech pending timer | Clears bit 0x800 |

### Connection manager

`BTCMAttach` creates the client with `CoCreateInstance(CLSID {101C5B9F-…}, NULL, CLSCTX_ALL, IID_IBtConnectionResponder)`. `BTCMRegisterResponderInterfaces` (0x1000B178) calls `IBtConnectionResponder::RegisterCallback(HandsfreeAudioGatewayServiceClass_UUID {0000111F-0000-1000-8000-00805F9B34FB}, ConnectionResponder, &id)`; a failure is fatal. Only the HFP class is registered; the HSP gateway class `{00001112-…}` is only used for the profile state of a connection that isn't HFP.

`ConnectionResponder` (0x10 bytes) implements `IBtConnectionResponderCallback` `{EB794A01-E173-4D1E-9CD4-2037CDB529E3}`:
- `AcceptRfcommConnection(SOCKET, SOCKADDR_BTH *, …, BYTE incoming)` (0x1000AF6C) queues event 2 with the address, socket and flags;
- `AcceptL2CapConnection` returns `E_FAIL` ("HFP/BTAG does not support direct L2CAP connections");
- `DisconnectConnection(address)` queues event 4.

`DispatchConnectionRequest` (0x10009B7C): a second device is refused (`closesocket`, profile state sent again), unless the request isn't incoming, in which case the current device is disconnected first. Then it resets the HF state, stores the address and the socket, sets the state to 1 (connecting), starts the connecting timer (15 s), creates the `HFConnection` (0x408 bytes) on the socket, and for an HSP device ends the connection set-up at once (`ServiceConnectionUp`).

`SetConnectionState` (0x100099C0) reports each change with `IBtConnectionResponder::SetProfileState(address, HFP or HSP class, state)` and sets bit 0x02 of the WNF state in state 2. `ServiceConnectionUp` (0x10009A38) creates the [AudioConnectionFSM](#sco-audio), sets the state to 2, sends the current `+CIEV` of service, call and callsetup (HFP only), and opens audio if a call is in progress. It's called after `AT+CMER=3,0,0,n`, unless the HF (feature bit 1) and the AG (feature bit 0) both support three-way calling: then after `AT+CHLD=?`.

`Disconnect` (0x10009E10) closes audio, shuts down the `AudioConnectionFSM`, closes the socket, sets the state to 0 and deletes the phonebook providers.

### RFCOMM link

`HFConnection` owns an `AsyncDataSocket` (`WSARecv` / `WSASend`, overlapped). It implements `IAsyncDataSocketCallback` `{BD1CD81A-7761-447C-89A4-DBEE9B5F3AB2}`. `DispatchReceiveData` (0x1000F800) accumulates the bytes in a 1000-byte buffer and cuts a command at each `\r`, 0x1A or 0x1B; a longer command closes the socket.

`DispatchHFCommandReceived` (0x10009F74) removes the leading blanks and the spaces after the first one, sets the default result to `ERROR`, and calls `OnCommand` (0x100112FC). `OnCommand` looks the prefix up in a table (0x10001704, case-insensitive) and runs the handler; an unknown command answers `ERROR`.

`SendString` (0x1000F724) sends the response with a flag DWORD, returned with event 15 when the send completes.

### AT commands

| Command | Response or action |
|---------|--------------------|
| `AT+BRSF=n` | Stores the HF features, `+BRSF: <SupportedFeaturesMask>` |
| `AT+BAC=` | List of HF codecs; sets codec negotiation and WNF bit 0x80 |
| `AT+CIND=?` | `+CIND: ("service",(0,1)),("call",(0,1)),("callsetup",(0-3)),("callheld",(0-2)),("signal",(0-5)),("roam",(0,1)),("battchg",(0-5))` |
| `AT+CIND?` | `+CIND: …` (fixed values during a virtual call or voice recognition) |
| `AT+CMER=3,0,0,n` | Indicator events on/off, end of the service level connection |
| `AT+BIA?`, `AT+BIA=` | Indicator mask (bits 2…4 always on) |
| `AT+CHLD=` | `?`: `+CHLD: (0,1,1x,2,2x,3)` if the AG feature bit 7 (ECC) is set, else `(0,1,2,3)`. 0 releases held or waiting calls, 1 releases the active call (1x: call x), 2 swaps (2x: private with call x), 3 conference (`OnCallHold`, 0x1001365C); `+CME ERROR: 30` on error when `AT+CMEE=1` |
| `ATA`, `AT+CKPD=200` | Answers (`PhoneAcceptIncomingEx`); the headset button also swaps or ends calls |
| `ATD<number>;` | Dials (`PhoneDial`), or starts voice recognition if the number contains the [Cortana number](#cortana) |
| `ATD>1;` | Dials the number at +0x154 |
| `AT+BLDN` | Starts voice recognition again if the last `ATD` was the Cortana number, otherwise redials the most recent outgoing call of the call history |
| `AT+CHUP`, `ATH` | Ends a call (ignored for `IgnoreCHUPAfterVCEndsPeriodMs` after a virtual call) |
| `AT+VTS=` | DTMF (`PhoneSendDTMF`), characters `1234567890*#ABCD,!` |
| `AT+CCWA=`, `AT+CLIP=`, `AT+CMEE=`, `AT+CREG=` | Enable `+CCWA`, `+CLIP`, `+CME ERROR`, `+CREG` |
| `AT+CNUM` | `+CNUM: ,"number",128,,4` |
| `AT+CLCC` | `+CLCC: idx,dir,state,0,mpty,"number",128,"name"` (name from the contacts) |
| `AT+COPS=3,0`, `AT+COPS?` | `+COPS: 0,0,"operator"` |
| `AT+CREG=?`, `AT+CREG?` | `+CREG: (0,1)`, `+CREG: n,stat` |
| `AT+BVRA=0/1` | Voice recognition through the pipe [speech responders](#pipe-btaudiogateway) |
| `AT+NREC=0` | Sets WNF bit 0x10 (only if the AG feature bit 1 is set and audio is closed) |
| `AT+VGM=`, `AT+VGS=` | Gain 0…15, passed to the SCO device |
| `AT+BCS=n` | Codec confirmed: `CodecConnectionReady` |
| `AT+BCC` | Codec connection request from the HF |
| `AT+CGMI`, `AT+CGMM` | `QueryPhoneInformation` 0, 5 |
| `AT+CGMR` | `+CGMR: "Windows Phone a.b.c.d"` (`GetPhoneVersion`) |
| `AT+CSCS` | `"GSM"`, `"IRA"`, `"UCS2"`, `"UTF-8"` |
| `AT+CPBS`, `AT+CPBR` | Phonebooks `ME` (contacts), `DC`, `MC`, `RC` (call history), `+CPBR: idx,"number",129,"name/type"`; only `ME` with `DisableCallHistoryProvider` |
| `AT+BTRH` | Nothing (`ERROR`) |
| `OK`, `ERROR` | Ignored |

The phonebook commands check `PbapTrustLevel` in `HKLM\System\CurrentControlSet\Services\BTConnMgr\Parameters\Devices\%04x%08x\PBAP` (`ATPhonebookAccessAllowed`, 0x1000FBAC): access is refused for the values 2, 3 and 4, allowed for 0, 1, 5 and more, or when the value can't be read. The value is written by the PBAP service [Bthpbapservice.dll](./bthpbapservice.md#authorisation) from the answer of the user: 0 unknown, 1 approved, 2 denied, 3 denied for the current connection.

### Cortana

`IsCortanaCalled` (0x10013178): if `AddCortanaPhonebookEntry` (default 1) is set, the number `CortanaPhoneNumber` (default `5555559876`) of the `Settings` key is looked for in the dialled number (`wcsstr`). The contact provider adds this number to the `ME` phonebook, with the name from `BthCommonRes.dll` (string 101 if `WNF_RW_CA_ENABLED` is non-zero, else 102). Dialling it starts voice recognition (`DispatchRequestToSpeechEngine(1)`), SQM datapoint 3228.

Voice recognition uses either `+BVRA` (if the HF supports it, feature bit 3, and `AlwaysUseVirtualCallsForVR` is 0) or a virtual outgoing call (`BTAGVirtualCallManager`: `+CIEV` callsetup 2, 3, call 1, callsetup 0) so that the HF opens audio.

### Phone

`AsyncPhoneController` (0x1D0 bytes) registers `PhoneStateCallback` with `PhoneAddListener` (4 events: 1, 8, 7, 9) and queries the state at once. The callback queues `RefreshWorker` (`QueueUserWorkItem`), which reads the state (`PhoneGetState`, `PhoneGetProviderLineInfo`, `PhoneGetProviderLineServiceInfo`) and queues event 24 of the service with an `AsyncPhoneEvent`:

| Type | Content | Action in `DispatchAsyncPhoneEvent` (0x1000FEE8) |
|------|---------|--------------------------------------------------|
| 0 | Call list (`PH_CALL_INFO`) | `DispatchCallsChanged`: call map, `+CCWA`, `UpdateCallCounts` |
| 1 | Registration state | Indicators service (state 5 or 6), roam (state 6), `+CREG: n` |
| 2 | Operator name | Stored for `+COPS` |
| 3 | Signal strength | Indicator signal |
| 4 | Own number | Stored for `+CNUM` |
| 5 | Second number | Stored for `ATD>1` |

`UpdateCallCounts` (0x10010068) sets the indicators call, callheld (1 active and held, 2 held only), callsetup (1 incoming, 2 outgoing, 3 alerting), starts the ring timer, and sets the WNF bit 0x400 while call or callsetup is non-zero. The call commands run in work items (`AsyncPhoneDialUserWorkItem`, `AsyncPhoneEndUserWorkItem`, …) which call the `Phone*` function.

### SCO audio

`AudioConnectionFSM` (0x108 bytes, 0x1000D938) is created when the connection is up:
1. Reads the delays of the `Settings` key (below).
2. Asks `IBtRadioController` from the responder, and calls `CreateScoAudioDevice(address, HF feature bit 4 (remote volume), 1, this, &device)` of [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md#sco-audio).
3. `IBtScoAudioDevice::Initialize(codec negotiation)`, then `AllowScoConnection`.

It implements `IBtScoAudioDeviceCallback` `{D9291D8E-B135-4E9F-85CD-2356C3B878F5}` (its `QueryInterface` accepts `IID_IDispatch` in place of `IUnknown`). The callbacks queue events: `ScoConnectionChanged` → state machine, `RequestAudioConnect` → service event 18 (or `SetAudioConnected` when the AG itself opened SCO), `RequestAudioDisconnect` → close, volume requests → `+VGS` / `+VGM`, `RequestCodecId` → event 25 (or `SetCodecId(1)` without codec negotiation).

The desired state (0 shutdown, 1 closed, 2 opened, 3 open after delay) and the SCO state (`BLUETOOTH_CONNECTION_STATE`) drive `ExecuteFSM` (0x1000E38C): `ConnectSco` when opened is wanted, the call is in progress and the codec (or SLC) is ready; `DisconnectSco` when closed is wanted. An open failure is retried up to `MaxOpenRetries`. When SCO changes, it calls `SetAudioConnected` / `SetAudioDisconnected`, completes the pipe requests, updates the A2DP suspender, and sets WNF bit 0x04 (bit 0x40 when the AG initiated the change).

| Value of `Settings` | Default | Timer |
|---------------------|---------|-------|
| `CodecSetupReadyDelayMs` | 100 | After the codec is selected |
| `SLCUpDelayMs` | 200 | After the SLC response |
| `CallInProgressDelayMs` | 100 | After the call starts |
| `ReopenDelayMs` | 500 | Before reopening after a close |
| `OpenRetryMs`, `MaxOpenRetries` | 200, 10 | Open retries |
| `IgnoreAudioDriverSCORequests` | 1 | |
| `IgnoreSCOCloseAfterCallStartsPeriodMs` | 1500 | A close by the HF just after the call starts is ignored |

The open-after-delay timer is 100 ms. Codec selection (`SelectCodec`, 0x1000EDB8) takes the first codec (1 or 2) of the binary value `HfpCodecs` of `HKLM\System\CurrentControlSet\Services\QCAUD` that the HF supports, default 1 (CVSD); then `+BCS: n`, and WNF bit 0x100 when the codec is 2 (mSBC).

SQM datapoints: 2443 (SCO open), 2444 (open given up), 2445 (SCO connected), 2451 and 2452 (SCO duration in minutes).

### A2DP suspender

`A2DPSuspender` (at +0x704) blocks A2DP streaming while a call, a call setup, a held call, an open SCO or voice recognition exists (`OnExternalChange`, 0x1000B248). A worker (`QueueUserWorkItem`) runs `SuspendResumeAll` (0x1000B450): for each render endpoint with `PKEY_Endpoint_IsBluetooth` = true, it gets the `IKsControl` of the connected topology filter (`GetTopologyDeviceInterfaceFromRenderDevice`) and calls `KsMethod` with set `{0E62540F-BAC4-4B85-B344-0D82ED5008AC}`, id 3 (block) or 2 (allow), flags 1. `ERROR_NOT_FOUND` is ignored. `OnExternalChange` waits until the streams are blocked before returning.

### Pipe BTAudioGateway

`PipeClient::PipeClient` (0x1000C9C8) creates one instance of `\\.\Pipe\BTAudioGateway` with `CreateNamedPipeW(PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED, PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_REJECT_REMOTE_CLIENTS, 255 instances, 1024, 128)`, and a security descriptor from `QueryTransientObjectSecurityDescriptor(6, L"\\\\.\\Pipe\\BTAudioGateway")`. When a client connects, a new instance is created for the next one. `PipeClient` implements `IAsyncPipeCallback` `{0396A428-1EAE-4AD7-8965-DF041C68CAA8}` and `IAsyncPipeListenCallback` `{053577B8-339C-4BB9-AC4B-E776EE489236}`.

Messages received (DWORD type at +0):

| Type | Fields | Action |
|------|--------|--------|
| 1 | +4 request id, +8 byte | Byte 1: begin voice command (opens audio after delay); byte 0: end voice command (closes audio) |
| 2 | +4 byte | The client is a speech responder (receives the speech requests) |
| 3 | +4 request id, +8 byte | Byte 1: connect audio (event 18); byte 0: close audio |

Messages sent:

| Type | Size | Fields |
|------|------|--------|
| -1 | 12 | +4 request id, +8 HRESULT: completion of a type 1 or 3 request. 0 when SCO reaches the requested state (at once if it's already there); the requests for the other state get 0x80070717 (SCO opened) or 0x800705E9 (SCO closed); 0x80070015 (`ERROR_NOT_READY`) without a connected device or during shutdown |
| -2 | 8 | +4 byte: start (1) or stop (0) speech recognition, sent to the speech responders |

A start sets the WNF bit 0x800 for 5 s (or until recognition starts).

The client is [BTAudioGatewayClient.dll](./btaudiogatewayclient.md#pipe-messages): type 1 comes from `IBTAGController::StartSpeechRecognition` / `StopSpeechRecognition`, type 3 from `OpenAudioChannel` / `ReleaseAudioChannel`, type 2 from the registration of the first / removal of the last `IBTAGSpeechResponderCallback`. The client also handles the types -3, -4 and -5 (observer notifications), which this service never sends.

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x41C61D22A3BC1075 `WNF_OS_BATTERY_STRENGTH` (`.text:0x1000127C`) | `OS`, 2 | 4 bytes: percentage ? | Subscribed; event 14. 0 → 1, 21 → 2, 41 → 3, 61 → 4, 91 and 100 → 5, other values → 0: indicator battchg |
| 0x41821B2CA3BF3075 `WNF_AUD_ACTIVE_CALL_ENDPOINT` (`.text:0x100011FC`) | `AUD`, 102 | 4 bytes: 0 Default, 1 Speakerphone, 2 Handset, 3 Wired, 4 Wired+MIC, 5 SCO, 6 SCO+NREC | Subscribed, only logged |
| 0x41821B2CA3BF4875 `WNF_AUD_CATEGORY_BACKGROUNDCAPABLEMEDIA` (`.text:0x10001178`) | `AUD`, 105 | 0x208 bytes: +4 flags, +0x108 id (string) | Subscribed, only logged |
| 0x41C6193FA3B95C75 `WNF_RW_CA_ENABLED` (`.text:0x10001244`) | `RW`, 171 | 4 bytes | Queried (`NtQueryWnfStateData`) for the Cortana name |
| 0x0992022FA3BC1075 `WNF_BLTH_BLUETOOTH_AUDIO_GATEWAY_STATUS` | `BLTH`, 2 | 4 bytes: bits below | Published by `DispatchSetWNFStatus` (0x10008944) when the value changes; read by [BthAvrcp.dll](./bthavrcp.md#wnf-states) (bits 0x004 / 0x400 block an AVRCP Play, 0x008 / 0x800 a Pause) |

The first four are version 1, well-known, system scope; `WNF_RW_CA_ENABLED` is permanent. The symbolic names come from the binary; the name of the published state comes from [BTAudioGatewayClient.dll](./btaudiogatewayclient.md#wnf-states), which subscribes to it and connects to the pipe when bit 0x001 is set. The callback is `WNFNotificationCallback` (0x1000AD70).

Bits of the published state:

| Bit | Meaning |
|-----|---------|
| 0x001 | Service running |
| 0x002 | HF device connected |
| 0x004 | SCO audio connected |
| 0x008 | Voice recognition active |
| 0x010 | Echo cancellation and noise reduction disabled by the HF (`AT+NREC=0`) |
| 0x020 | Ringing, or call waiting |
| 0x040 | Last SCO change initiated by the AG |
| 0x080 | Codec negotiation supported by the HF |
| 0x100 | Wide band codec (mSBC) selected |
| 0x200 | Voice recognition through a virtual call |
| 0x400 | Call or call setup in progress |
| 0x800 | Speech recognition requested, pending |

When bit 0x002 is clear, bits 0x004 to 0x200 are cleared.

### Registry

| Key | Values |
|-----|--------|
| `HKLM\SYSTEM\CurrentControlSet\Services\BTAGService\Parameters\Settings` | `SupportedFeaturesMask`, `BTAGManagesSCO`, `DeferredConnectAudioTimerDurationMs`, `DisableCallHistoryProvider`, `IgnoreCHUPAfterVCEndsPeriodMs`, `DebugEnabled`, `DebugZoneMask`, `DebugSevLevel`, `NeverUseVirtualCallsForVR`, `AlwaysUseVirtualCallsForVR`, `AddCortanaPhonebookEntry`, `CortanaPhoneNumber`, and the [SCO delays](#sco-audio) |
| `HKLM\System\CurrentControlSet\Services\QCAUD` | `HfpCodecs` (binary: codec ids in order of preference) |
| `HKLM\System\CurrentControlSet\Services\BTConnMgr\Parameters\Devices\%04x%08x\PBAP` | `PbapTrustLevel` |
| `HKLM\System\CurrentControlSet\Services\BtConnMgr\Parameters\Sqm` | `EnableSQM` |
| `HKLM\System\CurrentControlSet\Services\BTHPORT\Parameters\Devices` | `LEAddressType`, `DeviceNames` (SQM code) |
| `SYSTEM\CurrentControlSet\Services\%s\Parameters`, `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Svchost` | `ServiceDll`, `ServiceDllUnloadOnStop`, group: written by `RegisterOneService` |

### ETW

Provider `{22A7B160-F6E8-46B9-8E0B-A51989C85C66}` (`Microsoft_WindowsPhone_Bluetooth_AG`), registered in `DispatchServiceStart`.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 1000 | 0 | 0, 10 | 0x100 | 0x1 | `_ETWMESSAGE`, debug text (`BTAGEtwMessage`, 0x10009238, through `FormatMessageA`) |

`__FatalError` (0x100148DC) writes `NET_FATAL_ERROR` with the provider `Microsoft-WindowsPhone-Net-Debug`, as in the connection manager.
