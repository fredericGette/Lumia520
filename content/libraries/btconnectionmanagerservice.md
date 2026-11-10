## BtConnectionManagerService.dll

The Bluetooth connection manager of Windows Phone 8.1: the `BTConnMgr` service, hosted by `svchost.exe`, which owns the radio on/off state, the paired devices, the profile connections and the pairing.  
`BtConnectionManagerService.dll` is a large C++ DLL (344 064 bytes, 1117 functions, the database has its full symbols). It talks down to the Microsoft Bluetooth stack with the `BthPort` IOCTLs, and offers a message protocol to its clients on the named pipe `\\.\Pipe\BtConnectionManager`. It switches the radio through the OEM `SupportDLL` of the registry, keeps the list of local profiles from the registry (`Parameters\Services\{GUID}`), starts or waits for the service of each profile, creates the listeners (RFCOMM sockets, L2CAP) and hands the connections to the clients. It also signals background tasks on Bluetooth events (RFCOMM, connection change, GATT characteristic change) through the Background Infrastructure, and has two built-in profiles: A2DP and PAN.  
It relies on [QcBtradioctrl8930.dll](./qcbtradioctrl8930.md) as `SupportDLL` for the radio power (according to the [Bluetooth stack](../bluetooth/README.md) diagram; the value itself comes from the registry). The client side of the pipe is [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md), which implements the COM class `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`. That CLSID is also present in [BTAGService.dll](./btagservice.md) (the HFP audio gateway, a client), [BthavctpSvc.dll](./bthavctpsvc.md) (the AVCTP transport of AVRCP, a client), [BthOPPManager.dll](./bthoppmanager.md) (the Object Push Profile, a client: profiles `{00001105-0000-1000-8000-00805F9B34FB}` and `{99999999-0000-1000-8000-00805F9B34FB}`) and [Bthpbapservice.dll](./bthpbapservice.md) (the Phone Book Access Profile server, a client: profile `{0000112F-0000-1000-8000-00805F9B34FB}`), the probable clients.

Location on the phone: `C:\Windows\System32\BtConnectionManagerService.dll` ? (the extracted file has no notes).  
Service name: `BTConnMgr`.  
Source folder: `src\net\bluetooth\product\services\connectionmanager\server\`, `src\net\bluetooth\product\services\servicelib\` (strings).  

### Imports

| DLL | Functions |
|-----|-----------|
| BluetoothApis | `BluetoothFindFirstRadio`, `BluetoothFindRadioClose`, `BluetoothGetRadioInfo`, `BluetoothGATTGetServices`, `BluetoothGATTGetIncludedServices`, `BluetoothGATTGetCharacteristics`, `BluetoothGATTGetDescriptors`, `BluetoothGATTGetDescriptorValue`, `BluetoothGATTSetDescriptorValue` |
| WS2_32 | `WSASocketW`, `WSAAccept`, `WSAEventSelect`, `WSADuplicateSocketW`, `WSAStartup`, `WSAGetLastError`, `bind`, `closesocket`, `connect`, `getsockname`, `listen`, `setsockopt` |
| ntdll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlPublishWnfStateData`, `RtlQueryWnfStateData`, `NtQueryWnfStateData`, `RtlAllocateWnfSerializationGroup`, `WinSqmStartSession`, `WinSqmEndSession`, `WinSqmAddToStreamEx`, `WinSqmIncrementDWORD`, `WinSqmSetIfMaxDWORD`, `RtlInitUnicodeString`, `RtlQueryPackageIdentity`, `RtlNtStatusToDosError` |
| SecRuntime | `CapabilityCheck`, `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor` |
| policymanager | `PolicyManager_GetConnectivityPolicy_AllowBluetooth` |
| bcrypt | `BCryptOpenAlgorithmProvider`, `BCryptCloseAlgorithmProvider`, `BCryptGetProperty`, `BCryptCreateHash`, `BCryptHashData`, `BCryptFinishHash`, `BCryptDestroyHash`, `BCryptGenRandom` |
| api-ms-win-core-bicltapi-l1-1-2 | `BiCreateEventForPackageName`, `BiDeleteEvent`, `BiEnumerateBrokeredEvents`, `BiFreeMemory`, `BiQueryBrokeredEvent`, `BiQuerySystemStateBroadcastChannels`, `BiSignalTriggerEvent` |
| api-ms-win-devices-config-l1-1-1, CFGMGR32 | `CM_Register_Notification`, `CM_Unregister_Notification`, `CM_Get_Device_Interface_List*`, `CM_Get_Device_Interface_Property*`, `CM_Set_Device_Interface_PropertyW`, `CM_Get_Device_ID_List*`, `CM_Get_DevNode_Property*`, `CM_Get_DevNode_Status`, `CM_Locate_DevNode*`, `CM_Uninstall_DevNode` |
| api-ms-win-devices-query-l1-1-1 | `DevGetObjects`, `DevFreeObjects` |
| api-ms-win-service-management-l1-1-0, -l2-1-0, api-ms-win-service-winsvc-l1-2-0, api-ms-win-service-core-l1-1-1, api-ms-win-service-private-l1-1-1 | `OpenSCManagerW`, `OpenServiceW`, `CreateServiceW`, `DeleteService`, `StartServiceW`, `CloseServiceHandle`, `ChangeServiceConfig2W`, `QueryServiceStatus`, `ControlService`, `SetServiceStatus`, `RegisterServiceCtrlHandlerExW`, `WaitServiceState` |
| api-ms-win-core-namedpipe-l1-2-0, api-ms-win-core-kernel32-legacy-l1-1-1 | `CreateNamedPipeW`, `ConnectNamedPipe`, `ImpersonateNamedPipeClient`, `GetNamedPipeClientProcessId`, `GetNamedPipeServerProcessId`, `WaitForMultipleObjects`, `RegisterWaitForSingleObject`, `LoadLibraryW` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegCloseKey`, `RegQueryValueExW`, `RegQueryValueExA`, `RegSetValueExW`, `RegEnumKeyExW`, `RegEnumValueW`, `RegDeleteValueW`, `RegDeleteKeyExW`, `RegDeleteTreeW` |
| api-ms-win-core-file-l1-2-1, api-ms-win-core-io-l1-1-1 | `CreateFileW`, `ReadFile`, `WriteFile`, `DeviceIoControl`, `GetOverlappedResult`, `CancelIoEx` |
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance`, `CoCreateGuid`, `CLSIDFromString`, `StringFromGUID2`, `CoTaskMemFree` |
| api-ms-win-security-base-l1-2-0, api-ms-win-security-lsalookup-l2-1-1 | `DuplicateTokenEx`, `GetTokenInformation`, `AdjustTokenPrivileges`, `RevertToSelf`, `IsValidSid`, `GetLengthSid`, `LookupPrivilegeValueW` |
| api-ms-win-core-threadpool-l1-2-0, -legacy-l1-1-0, -private-l1-1-0 | `CreateThreadpoolWait`, `SetThreadpoolWait`, `CloseThreadpoolWait`, `CreateThreadpoolCleanupGroup`, `CloseThreadpoolCleanupGroup`, `QueueUserWorkItem`, `UnregisterWaitEx`, `RegisterWaitForSingleObjectEx` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateThread`, `ResumeThread`, `GetCurrentProcess`, `GetCurrentProcessId`, `GetCurrentThread`, `GetCurrentThreadId`, `TerminateProcess`, `OpenProcess`, `OpenProcessToken`, `OpenThreadToken`, `SetThreadToken` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `CreateEventExW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `WaitOnAddress`, `WakeByAddressAll` |
| api-ms-win-eventing-provider-l1-1-0, api-ms-win-eventing-classicprovider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite`, `TraceMessage` |
| api-ms-win-appmodel-runtime-l1-1-1 | `PackageFamilyNameFromFullName` |
| api-ms-win-core-libraryloader-l1-2-0 | `GetProcAddress`, `FreeLibrary`, `GetModuleFileNameW`, `GetModuleFileNameA`, `GetModuleHandleExW`, `DisableThreadLibraryCalls` |
| Others | sysinfo, errorhandling, string, handle, debug, console (`SetConsoleCtrlHandler`), processenvironment (`ExpandEnvironmentStringsW`), rtlsupport, localization, util, heap-obsolete (`LocalAlloc`, `LocalFree`) |
| msvcrt | C and C++ runtime (`malloc`, `free`, `operator new`/`delete`, `_CxxThrowException`, `__CxxFrameHandler3`, `_initterm`, `__dllonexit`, `setlocale`, …) |

The msvcrt, rtlsupport, debug and part of the errorhandling, processthreads and sysinfo imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. The binary also embeds the STL (`std::map`, `std::vector`, `std::tr1::function`, `std::regex`).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `SupportDLL` value of `HKLM\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Radio Support` ([QcBtradioctrl8930.dll](./qcbtradioctrl8930.md) according to the stack diagram) | `LoadLibraryW` + `GetProcAddress` `BluetoothEnableRadio`, `IsBluetoothRadioEnabled` ([Radio power](#radio-power)) | Switches the radio on and off |
| `mlang.dll` | `LoadLibraryW` + `GetProcAddress` `LcidToRfc1766A` (`SystemNaturalLanguageGet`, 0x10043CE4) | Language tag of the system, default value "en" ?; used by the PAN code |
| [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) | `CoCreateInstance` `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`, string `BtConnectionManager` | Used by A2DP and PAN (interfaces `{4D1AC687-509C-48F7-A7BB-FE2B83A9C7DC}`, `IBtConnectionResponder`, and `{83C91970-1D3D-48E3-859F-436EB34F34FD}`, `IBtConnectionObserver`): the service is a client of itself |
| Audio endpoints | `CoCreateInstance` `{BCDE0395-E52F-467C-8E3D-C4579291692E}` (`MMDeviceEnumerator`), `{A95664D2-9614-4F35-A746-DE8DB63617E6}` (`IMMDeviceEnumerator`) | A2DP: watches the Bluetooth audio endpoints; `GetTopologyDeviceInterfaceFromRenderDevice` also uses the topology (`{2A07407E-6497-4A18-9787-32F79BD0D98F}`) and `IKsControl` (`{28F54685-06FD-11D2-B27A-00A0C9223196}`) |
| `ICSSVC` service | `OpenServiceW`, `StartServiceW` (`PanService::QueryICSStatus`, `StartICSService`) | Internet Connection Sharing for PAN |
| `svchost.exe -k %s` | `CreateServiceW` command line (`CService::RegisterOneService`) | Service registration when run from the console; `ServiceDll` and `ServiceDllUnloadOnStop` are written in `Services\%s\Parameters`, and the group in `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Svchost` |
| `\\.\\BthPan` | `CreateFileW` (`OpenBthpanHandle`, `BTRegisterNetworkConnectionCallback`) | PAN network driver (`BthpanDriverRequest`, thread `BTNetworkConnectionThreadFunc`) |
| Service of each profile | Parameters\Services\{GUID} (`ServiceName`), `LocalService::StartServiceMonitor`, `WaitServiceState` | The services started or watched for each [local service](#local-services) |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `SvchostPushServiceGlobals` | 0x10029FE4 | `_SVCHOST_GLOBAL_DATA *` |
| 2 | `ServiceMain` | 0x10040130 | `DWORD argc, LPWSTR *argv` |

`SvchostPushServiceGlobals` creates the `BtService` object (0x228 bytes, a `CService`), links it in the `CService::s_pFirstService` list, and marks the DLL as running in svchost. If the first DWORD of the structure is 0x87654321, the structure is really a command line (`argc` at +4, `argv` at +8), parsed by `CService::ParseArgs`: register, unregister or run as a console program (`RunAsConsoleExe`). Otherwise it's the svchost data, which is kept.  
`ServiceMain` finds the service by `argv[0]` (`FindServiceByName`) and calls `CService::ServiceMain` (`RegisterServiceCtrlHandlerExW`).

### Startup

`_DllMainCRTStartup` (0x10044E70): CRT. `DllMain` (0x10029F8C) only calls `DisableThreadLibraryCalls`.

`BtService::OnStartCallback` (0x10019DC4):
1. `McGenEventRegister`, reads `DebugConsoleEnabled` and `DebugSevLevel` (`SYSTEM\ControlSet001\Services\BTConnMgr\Parameters`).
2. Resets the two events of the object, creates the first `Client` (the first instance of the pipe).
3. Creates `A2dpService`, `PanService` and `BackgroundBroker`, and starts them.
4. `SERVICE_RUNNING`, then sets bit 0x01 of [WNF_BLTH_BLUETOOTH_STATUS](#wnf-states).

The constructor `BtService::BtService` (0x100195B4) opens `SYSTEM\CurrentControlSet\services\BTConnMgr\Parameters`, the service manager, and reads `Active` and `ConfigFlags` from `SYSTEM\DriverDatabase\DriverInfFiles\bth_mc.inf` and `SYSTEM\DriverDatabase\DriverPackages\…\Configurations\BthGenericService.NT`.

Each object derives from `SynchronizedObject`: work is queued as events with `Synchronizer::EnqueueEvent` and run one at a time in `Dispatch`, so nearly every function exists as `xxx` + `xxxCallback`.

`BtService::OnControlCallback` (0x10019BF4) handles the user control codes 0x82 (queues event 0x15 of the `Radio` object, meaning ?), 0x83 (reads `A2DPAddress`, and uses the name `A2DP`) and 0x84 (name `AVRCP`, class `AVRemoteControlTargetService`, whose responder is [BthavctpSvc.dll](./bthavctpsvc.md#connection-manager)). The last two send `IOCTL_BTH_SET_LOCAL_SERVICE_INFO` (0x41104C) ?.

### Objects

| Class | Role |
|-------|------|
| `BtService` | The service; owns everything below |
| `Client`, `ClientSet`, `AsyncPipe` | One pipe instance per client, see [Pipe protocol](#pipe-protocol) |
| `Radio` | Radio state, inquiry, page scan, `BthPort` handle and notifications |
| `Device`, `DeviceSet`, `DeviceWatcherSet` | One object per remote device (state machine `UpdateDisconnected`, `UpdateConnecting`, `UpdateWaitPaired`, `UpdateConnectingSdp`, `UpdateGettingSdp`, `UpdateConnected`, `UpdateDisconnecting`, `UpdateUnpairing`) |
| `LocalService`, `ServiceSet`, `Connection`, `ConnectionSet` | One object per profile, and one connection per (profile, device) |
| `IncomingPairing`, `OutgoingPairing`, `PairingSet` | Pairing |
| `BackgroundBroker`, `TriggerBase`, `RfcommTrigger`, `ConnectionChangeTrigger`, `CharacteristicChangeTrigger`, `SignalStrengthTrigger` | Background tasks |
| `A2dpService`, `A2dpConnection`, `PanService`, `PanConnection` | Built-in profiles |
| `GattDescriptorInitializer` | Writes the client configuration descriptors of the monitored GATT characteristics |

### Radio power

`Radio::StartCallback` (0x1002E8F8):
1. `LoadPageScanSettings`, reads `SupportDLL`. Offset +0xF4 of the object (`m_fUseRadioOnOffSupportDll`) is set if the value isn't empty.
2. Queries and subscribes to `WNF_ENTR_CONNECTIVITY_POLICY_VALUE_CHANGED` (`PolicyChangedStatic`).
3. `CM_Register_Notification` on `GUID_BTHPORT_DEVICE_INTERFACE`.
4. `LoadRadioRoutines`, if the routines load: state `BRS_DISABLED` or, if `ShouldRadioBeEnabledAutomatically` is true, `StartEnableRadio`.
5. `CM_Register_Notification` on `GUID_BTH_DEVICE_INTERFACE` and `GUID_BLUETOOTHLE_DEVICE_INTERFACE`.

`ShouldRadioBeEnabledAutomatically` (0x1002E854) returns true when `EnableRadio` isn't 0, the radio state is `BRS_DISABLED` (2), and `RestartCount` is below 2, or `RestartTime` is more than 24 hours old (0xC92A69C000 × 100 ns), in which case `RestartCount` is reset. This limits the radio restarts after crashes. `Client::ReceiveEnableRadio` resets `RestartCount` when a client enables the radio.

`Radio::SetRadioState(fState)` (0x1002ED84) has two paths:
- With the support DLL: `BluetoothEnableRadio(fState)` then `IsBluetoothRadioEnabled(&state)`, up to 10 attempts 1 second apart while one of them returns an error (each attempt skips the call that already succeeded), then `FreeLibrary`.
- Without it: `OpenRadioOnOff` (interface `GUID_BLUETOOTH_RADIO_STATE_INTERFACE_CLASS`), `IOCTL_BTH_SET_RADIO_STATE` (0x411184, 4-byte input) then `IOCTL_BTH_QUERY_RADIO_STATE` (0x411180, 4-byte output; values 1 and 2 are read as enabled ?).

Radio states (`RadioStateName`, 0x10031370): 0 = `BRS_UNKNOWN`, 1 = `BRS_NO_HARDWARE`, 2 = `BRS_DISABLED`, 3 = `BRS_ENABLING`, 4 = `BRS_ENABLED`, 5 = `BRS_DISABLING`.

`Radio::StartEnableRadio` (0x1002FD2C), before enabling: copies the values of `Services\BtConnMgr\BthPortDeviceParameters` to the `Device Parameters` key of the BthPort device (`FindBthPortDeviceParametersKey`, `RegHelperCopyValues`), copies `SlaveRoleCODMasks` to `Slave Role COD Masks` of `Services\BthPort\Parameters`, then queues `EnableRadioWorkerStatic`. `Radio::OpenRadio` (0x10031560) impersonates with `SeLoadDriverPrivilege`, opens the first interface `GUID_BTHPORT_DEVICE_INTERFACE`, and registers its notifications.  
`WaitForDeadRadio` (0x1002FED0) waits, after a radio crash (`LastRadioCrashTime`), until the `GUID_BTHPORT_DEVICE_INTERFACE` and `GUID_BLUETOOTH_RADIO_STATE_INTERFACE_CLASS` devices have arrived again.  
If `BthPort` unloads during `IOCTL_BTH_LE_ENTER_ACTIVE_SCANNING`, `Radio::StartDisableRadio` calls `TerminateProcess` ("BTCM will die without Watson report and restart").

The policy `PolicyManager_GetConnectivityPolicy_AllowBluetooth` is read in `Radio::Dispatch` after each change of the WNF state (`Radio::PolicyChangedCallback`, log "Bluetooth is disabled by policy").

### Pipe protocol

`Client::Client` (0x1001C5B0) creates one instance of the pipe:
- `QueryTransientObjectSecurityDescriptor(6, L"\\\\.\\Pipe\\BtConnectionManager", &sd)`; NTSTATUS 0xC0000189 is accepted.
- `CreateNamedPipeW`: open mode 0x40000003 (`FILE_FLAG_OVERLAPPED | PIPE_ACCESS_DUPLEX`), pipe mode 0xE (`PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_REJECT_REMOTE_CLIENTS`), 255 instances, output buffer 0x400, input buffer 0x80, no timeout.

When a client connects, a new `Client` is created for the next one (`BtService::ClientConnectedCallback`), and the new client receives message -1, the devices (-2), the services (-3), then -4.

Each pipe message starts with a DWORD `BTCM_MESSAGE_TYPE`: positive from the client, negative from the service. `Client::IncomingMessageCallback` (0x1001CB68) checks the minimum size for the type: a shorter message closes the client. An unknown type (6 for example) goes to `DebugPrintfFatal`.

Messages from the client (`BtcmCs…`):

| Type | Size | Admin | Fields | Action |
|------|------|-------|--------|--------|
| 1 | 12 | no | +4 enable, +8 cookie | `ReceiveEnableRadio`; answer -5 |
| 2 | 8 | yes | +4 mode | `ReceiveEnableInquiry`: stored in the client, service event 9 |
| 3 | 8 | yes | +4 mode | `ReceiveEnableDiscovery`: stored in the client, the service uses the highest mode of the clients |
| 4 | 64 | no | +8 address, +0x10 cookie, +0x14 authentication requirements, +0x18 byte OOB present, +0x1C OOB data | `PairingSet::ReceiveBeginPairing`; duplicate cookie: answer -9 with 0x800707DE |
| 5 | 28 | no | +4 cookie, +8 PIN size, +0xC PIN | `ReceivePairingMessage` |
| 7, 8 | 8 | no | +4 cookie | `ReceivePairingMessage`: accept, refuse |
| 9 | 16 | yes | +8 address | Unpair (event 21) |
| 10 | 20 | no | +4 profile GUID | `RegisterProfileClient`, register |
| 11 | 20 | no | +4 profile GUID | `RegisterProfileClient`, unregister |
| 12 | 40 | no | `BtcmCsSetProfileState` | `SetProfileStateFromClientCallback` (event 25) |
| 13 | 16 | yes | +8 address | Connect the device (event 19) |
| 14 | 16 | yes | +8 address | Disconnect the device (event 20) |
| 15 | 8 | no | +4 byte | Adds or removes the client from the incoming pairing clients (event 22, `WantIncomingPairingCallback`) |
| 16 | 28 | no | +4 profile GUID, +0x14 connection cookie, +0x18 byte accepted | Event 29, sent to the `LocalService` as its event 18: answer to -14 and -15 |
| 17 | 40 | no | +8 address, +0x10 GUID, +0x20 DWORD | `ConnectProfileToDeviceFromClientCallback` (event 27) |
| 18 | 1088 | no | +0x38 size of the SDP record (0x400 at most), +0x3C record | Register a `RfcommTrigger` |
| 19 | 24 | no | +8 address, +0x10, +0x11 bytes | Register a `ConnectionChangeTrigger` |
| 20 | 32 | no | +4 cookie, +8 address, +0x10, +0x14, +0x18 DWORDs | Register a `SignalStrengthTrigger` |
| 21 | 40 | no | +8 address, +0x10, +0x12, +0x14 words, +0x18 count (5 at most), +0x1C words | Register a `CharacteristicChangeTrigger` |
| 22 | 20 | no | +4 GUID | Unregister a trigger (`ClientUnregisterMessageCallback`) |

The "Admin" requests are refused if `Client::IsBluetoothAdmin` is false. This function calls `CapabilityCheck(token, L"ID_CAP_BLUETOOTH_ADMIN", &result)` on the token of the client (`AsyncPipe::GetClientToken`, `ImpersonateNamedPipeClient`), but it doesn't read `result` and returns 1 unless the call fails: the check seems ineffective in this build ?

Messages from the service:

| Type | Size | Sent by | Fields |
|------|------|---------|--------|
| -1 | 16 | `ClientConnectedCallback`, `RadioStateChangedCallback` | +4 radio state, +8 local address |
| -2 | 0x80 | `Client::SendDeviceStateUpdate` | +8 address, +0x10 state, +0x14 class, +0x18 name (32 characters), +0x58 RSSI, +0x5C size, +0x60 advertising data (0x20 bytes at most) |
| -3 | 0x28 | `Connection::Dispatch`, `BtService::Dispatch` (event 26) | +8 address, +0x10 profile GUID, +0x20 state |
| -4 | 4 | `Client::Dispatch` | End of the initial status (`INITIALIZED`) |
| -5 | 12 | `Radio::CompleteEnableRequests`, `Client::Dispatch` | +4 cookie, +8 status |
| -6 | 8 | `OutgoingPairing::AuthenticationRequestCallback` | +4 cookie: asks for a PIN |
| -7 | 0x1C | `OutgoingPairing::AuthenticationRequestCallback` | +4 cookie, +8 size, +0xC passkey |
| -8 | ? | `OutgoingPairing::AuthenticationRequestCallback` | +4 cookie, +8 value to compare |
| -9 | 12 | `OutgoingPairing::FinishPairing`, `ReceiveBeginPairing` | +4 cookie, +8 status |
| -10 | 0x28 ? | `IncomingPairing::AuthenticationRequestCallback` | +8 address, +0x10 cookie: asks for a PIN |
| -11 | 0x28 | `IncomingPairing::AuthenticationRequestCallback` | +8 address, +0x10 cookie, +0x14 PIN size, +0x18 PIN (from `ConvertPasskeyToPin`) |
| -12, -13 | ? | `IncomingPairing::AuthenticationRequestCallback` | +8 address, +0x10 cookie; -12: +0x14 value to compare; -13: just works |
| -14 | 0x4A0 ? | `LocalService::SendSocket` (0x10037830) | [New socket](./btconnectionmanagerclient.md#socket-message) |
| -15 | 0x50 | `LocalService::SendSocket`, `L2capAttachCallback` | New L2CAP channel: +8 address, +0x10 profile GUID, +0x20 PSM, +0x38 outgoing MTU, +0x3C incoming MTU, +0x40 handle, +0x44 byte, +0x48 connection cookie |
| -16 | 0x20 | `LocalService::Dispatch` | Profile disconnected: +8 address, +0x10 profile GUID |
| -17 | 12 | `Client::Dispatch` (event 11) | +4 cookie, +8 Win32 error: end of `ConnectProfileToDevice` |
| -18 | 0x28 | `BtService::Dispatch` (event 33, from `DeviceHciEvent`) | +4 event GUID, +0x18 address, +0x20 byte type, +0x21 byte connected |
| -19 | 0x1C | `RegistrationRequest::SendClientResponse` | +4 cookie, +8 status, +0xC GUID of the trigger |

The socket is duplicated in the client process with `WSADuplicateSocketW` (`LocalService::SendSocket`, 0x100377A8), and the L2CAP device handle with `DuplicateHandle` (`DuplicateL2CAPDeviceHandleForTargetProcess`).

### Pairing

`IncomingPairing` and `OutgoingPairing` handle the notifications `GUID_BLUETOOTH_AUTHENTICATION_REQUEST` and `GUID_BLUETOOTH_LE_AUTHENTICATION_REQUEST`. The cookie of a message selects the object: negative for an incoming pairing, otherwise an outgoing one. The answers go to the stack with `IOCTL_BTH_AUTH_RESPONSE` (0x411004, 0x240 bytes), and outgoing pairings start with `IOCTL_BTH_PAIR_DEVICE` (0x411010). `GenerateRandomPasskey` (0x1002C018) uses `BCryptGenRandom`. "Incoming authentication not supported for LE" is fatal for an LE request in `IncomingPairing`.

### Local services

`ServiceSet::Populate` (0x10038A60) enumerates `SYSTEM\CurrentControlSet\Services\BtConnMgr\Parameters\Services`: each subkey name is a profile GUID, read by the constructor `LocalService::LocalService` (0x10034C40):

| Value | Use |
|-------|-----|
| `ServiceName` | Service of the profile |
| `SdpRecord` | Published with `IOCTL_BTH_SDP_SUBMIT_RECORD_WITH_INFO` (0x41021C) |
| `CODServiceFlags` | Class of device bits, `IOCTL_BTH_SET_LOCAL_SERVICE_INFO` (0x41104C) |
| `Listen`, `Connect` | Listener, outgoing connections |
| `ConnectOnIncomingAcl`, `ConnectOnIncomingAclExemptions` | Connects the profile on an incoming ACL (`BTCMShouldInitiateConnectionOnIncoming`) |
| `RemoveableIfMissingInSdpRecord` | `BtService::IsServiceRemovable` |
| `SingleConnectionOnly`, `Authenticate`, `Encrypt`, `LetServiceConnect` | Connection flags |
| `RemoteServiceClass` | GUID of the remote class |
| `Psm`, `Psm2` | L2CAP PSMs; no PSM means RFCOMM ? |
| `OutgoingMtuMin/Preferred/Max`, `OutgoingFlushTOMin/Preferred/Max`, `LinkTO`, `EnhancedModeFlags`, `EnhancedTxWindowSize`, `EnhancedRetransmitCount`, `EnhancedMaxPDUSize`, `IncomingMtuMin/Preferred/Max`, `IncomingFlushTOMin/Max`, `IncomingQueueDepth` | L2CAP configuration |
| `Psm2…` (same names), `Psm2FCS` | L2CAP configuration of the second PSM |
| `DumpSdpRecords` | Debug |
| `Devices` | Binary, list of 8-byte addresses: most recently used devices (`ReadMruList`, `AddToMruList`) |

The RFCOMM listener is `LocalService::StartRfcommListener` (0x100364E4, `WSASocketW`, `bind`, `listen`, `WSAAccept`), the L2CAP one uses `IOCTL_BTH_WP8_L2CAP_REGISTER`, `LISTEN` and `ATTACH`. `LocalService::StartServiceMonitor` watches the service of the profile with `WaitServiceState`.

### Background tasks

`BackgroundBroker::ClientRegisterMessage` (0x10016C6C) creates the trigger of messages 18 to 21, with the application identity of the client (`Client::GetClientAppId`, 0x1001CF68: the token of the pipe client, `OpenThreadToken` or `OpenProcessToken`, then `Broker::AppToken::GetAppId`). `RegisterMessageWorkerStatic` (0x10016F08) calls `BiCreateEventForPackageName` with `Broker::BILayer::BrokerId` and enables the trigger; the answer is message -19. An event calls `CreateTaskStatic` (0x100173A8), which calls `BiSignalTriggerEvent`.  
At startup, `GetEnumeratedEventsStatic` restores the registered events (`BiEnumerateBrokeredEvents`, `BiQueryBrokeredEvent`) with `InitializeFromSerializedData` of each trigger. RFCOMM triggers use a subkey `BackgroundBroker\{event GUID}` (`ServiceSet::EnableRfcommTrigger`, 0x10038C14), under `Parameters\Services` ?. Application uninstall and servicing are handled by `OnApplicationUninstallCallback`, `OnApplicationServicingStartCallback`, `OnApplicationServicingStopCallback`.

### PAN

`PanService::OnStartCallback` (0x1002DFC8) creates the `BtConnectionManager` COM object, registers as responder for `NAPServiceClass_UUID` and as observer, and opens `ICSSVC`. `PanService::RadioStateChangedCallback` registers the network callback (`BTRegisterNetworkConnectionCallback`, 0x10043B50) and sets the role from `StartUpRole` (`System\CurrentControlSet\Services\BthPan`, `IniGetBTDeviceConfig`, `IniSetBTDeviceRole`). The classes used are NAP and PANU. The strings "Network Access Point Service", "Personal Ad Hoc Network Service…" and "Personal Ad Hoc User Service" are probably their SDP service names.

### Registry

| Key | Values |
|-----|--------|
| `SYSTEM\CurrentControlSet\Services\BTConnMgr\Parameters` | `EnableRadio`, `RestartCount`, `RestartTime`, `A2DPAddress` |
| `SYSTEM\ControlSet001\Services\BTConnMgr\Parameters` | `DebugConsoleEnabled`, `DebugSevLevel` |
| ? (stored key handle) | `SlaveRoleCODMasks` (`StartEnableRadio`), `BTBusKeyName` (`FindBthPortDeviceParametersKey`), `LowDutyCyclePageScanWindow/Interval/Type`, `HighDutyCyclePageScanWindow/Interval/Type` (`LoadPageScanSettings`), `InquiryLength` (`StartInquiryIoctlIfNeeded`), `ScanModeOverride` (`DiscoveryGetCompletedCallback`), `LEGoodConnectionInterval`, `MinReadQueueBackoffInterval`, `MaxReadQueueBackoffInterval` (`Device`), `LastRadioCrashTime` (`WaitForDeadRadio`, `Ioctl::Complete`) |
| `…\BtConnMgr\Parameters\Services\{GUID}` | [Local services](#local-services) |
| `…\BtConnMgr\Parameters\Sqm` | `EnableSQM`; `LeDevices` subkey |
| `…\BTConnMgr\Parameters\Devices\%04x%08x` | Per device values; the `AVRCP` subkey holds `CTCanPlayOrAddFolders`, read and written by [BthAvrcp.dll](./bthavrcp.md#registry) |
| `SYSTEM\CurrentControlSet\Services\BTConnMgr` | `FilterInquiryAddr` |
| `…\BTConnMgr\FilterInquiryNames` | Filter of `AllowDeviceToBeVisible` (0x10032124): only these devices are shown |
| `…\BtConnMgr\BthPortDeviceParameters` | Copied to the BthPort `Device Parameters` key |
| `SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Radio Support` | `SupportDLL` |
| `System\CurrentControlSet\Services\BthPort\Parameters` | `Slave Role COD Masks` (written) |
| Device Parameters of BthPort | `Page Scan Window`, `Page Scan Interval`, `Page Scan Type` (`UpdatePageScanSettingsIfNeeded`) |
| `SYSTEM\CurrentControlSet\services\BTHPORT\Parameters\Devices\%012llx\CachedServices` | SDP cache (`Device::UpdateSdpRecordCache`); also written by [BTHSERV.DLL](./bthserv.md#activateservice) |
| `System\CurrentControlSet\Services\BTHPORT\Parameters\Devices` | `LEAddressType` (SQM) |

The key of the "?" row is a handle kept in an object (`BtService`+0x60 for `EnableRadio`, `RestartCount` and `RestartTime`); it wasn't traced for each value.

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x0992022FA3BC0875 `WNF_BLTH_BLUETOOTH_STATUS` (`.text:0x10002C80`) | `BLTH`, 1 | 4 bytes: bits below | Published by `BtService::ChangeWNFStatusBitCallback` (0x1001ADD8) when the value changes |
| 0x13920028A3BC2075 `WNF_ENTR_CONNECTIVITY_POLICY_VALUE_CHANGED` (`.text:0x10009720`) | `ENTR`, 4 | ? | Queried and subscribed by `Radio::StartCallback`: `PolicyChangedStatic` reads the policy again |
| 0x41C6072FA3BC7075 `WNF_BI_BI_READY` (`.text:0x10002420`) | `BI`, 14 | ? | Subscribed by `BackgroundBroker::Dispatch` (`BrokerReadyChangedStatic`) |
| Names from `BiQuerySystemStateBroadcastChannels` | ? | ? | `Broker::BILayer::NotificationChannel`, `WnfNotification` |

The three names are version 1, well-known, system scope, not permanent. The symbolic names come from the binary. The next state of the same owner, `BLTH` sequence 2 (0x0992022FA3BC1075), is published by [BTAGService.dll](./btagservice.md#wnf-states) with the state of the HFP audio gateway.

Bits of `WNF_BLTH_BLUETOOTH_STATUS`:

| Bit | Meaning | Set by |
|-----|---------|--------|
| 0x01 | Service running | `OnStartCallback`, `OnStopCallback` |
| 0x02 | Radio enabled (`BRS_ENABLED`) | `RadioStateChangedCallback` |
| 0x04 | Inquiry in progress | `StartInquiryIoctlIfNeeded`, `InquiryCompletedCallback` |
| 0x08 | Device state, connected ? | `SetDeviceStateCallback` |
| 0x10 | HFP connected | `ConnectionSet::UpdateIsConnected` |
| 0x20 | A2DP connected | `ConnectionSet::UpdateIsConnected` |

Bits 0x04 to 0x20 are cleared when bit 0x02 is clear.

### Devices and notifications

| Interface | Use |
|-----------|-----|
| `GUID_BTHPORT_DEVICE_INTERFACE` `{0850302A-B344-4FDA-9BE9-90576B8D46F0}` | Radio handle of the IOCTLs, and notifications |
| `GUID_BLUETOOTH_RADIO_STATE_INTERFACE_CLASS` `{92383B0E-F90E-4AC9-8D44-8C2D0D0EBDA2}` | Radio on/off without support DLL |
| `GUID_BTH_DEVICE_INTERFACE` `{00F40965-E89D-4487-9890-87C3ABB211F4}` | Remote devices |
| `GUID_BLUETOOTHLE_DEVICE_INTERFACE` `{781AEE18-7733-4CE4-ADD0-91F41C67B592}` | LE devices (`BtGetDeviceHandle`, `ConnectLEDeviceWorker`) |
| `GUID_BLUETOOTH_GATT_SERVICE_DEVICE_INTERFACE` `{6E3BB679-4372-40C8-9EAA-4509DF260CD8}` | GATT services (`GattDescriptorInitializer`) |

Custom notifications handled by `Radio::HandleNotificationCallback` (0x1002F044): `GUID_BLUETOOTH_HCI_EVENT`, `GUID_BLUETOOTH_SCO_EVENT`, `GUID_BLUETOOTH_L2CAP_EVENT`, `GUID_BLUETOOTH_RADIO_IN_RANGE`, `GUID_BLUETOOTH_RADIO_OUT_OF_RANGE`, `GUID_BLUETOOTH_AUTHENTICATION_REQUEST`, `GUID_BLUETOOTH_LE_AUTHENTICATION_REQUEST`, `GUID_BLUETOOTH_HCI_LE_ADVERTISEMENT`. [BTHSERV.DLL](./bthserv.md#radio) (the `BthServ` service) opens the same radio and handles most of these notifications too (it forwards the authentication requests to its RPC clients), and also `GUID_BLUETOOTH_MUST_SYNCHRONIZE_STORE` `{69F95E75-EB00-485B-9E61-34A330BAFBF2}`.

IOCTLs, with the names of `BthIoctlName` (0x10030DD8):

| IOCTL | Name | Sent by |
|-------|------|---------|
| 0x410000 | `IOCTL_BTH_GET_LOCAL_INFO` | `Radio` |
| 0x4100D8 | `IOCTL_BTH_DISCONNECT_DEVICE_EX` | `Device::DisconnectInternal` |
| 0x4100E4 | `IOCTL_BTH_LE_ENTER_ACTIVE_SCANNING` | `Radio::StartInquiryIoctlIfNeeded` |
| 0x410200, 0x410204 | `IOCTL_BTH_SDP_CONNECT`, `IOCTL_BTH_SDP_DISCONNECT` | `Device` |
| 0x41021C | `IOCTL_BTH_SDP_SUBMIT_RECORD_WITH_INFO` | `LocalService::SubmitSdpRecord` |
| 0x411000 | `IOCTL_BTH_INQUIRY_DEVICE` | `Radio::StartInquiryIoctlIfNeeded` |
| 0x411004 | `IOCTL_BTH_AUTH_RESPONSE` | Pairing, `Device` |
| 0x411008 | `IOCTL_BTH_UPDATE_SETTINGS` | `UpdatePageScanSettingsIfNeeded` |
| 0x411010 | `IOCTL_BTH_PAIR_DEVICE` | `OutgoingPairing` |
| 0x411018 | `IOCTL_BTH_QUERY_UNPAIR_DEVICE` | `Device::UpdateUnpairing` |
| 0x411020 | `IOCTL_BTH_SCAN_ENABLE` | `Radio` |
| 0x411030 | `IOCTL_BTH_UPDATE_DEVICE` | `Device` |
| 0x411038 | `IOCTL_BTH_GET_DEVICE_PROTOCOLS_INFO` | `Device` |
| 0x41104C | `IOCTL_BTH_SET_LOCAL_SERVICE_INFO` | `OpenProtocolDevice`, `OnControlCallback` |
| 0x411058 | `IOCTL_BTH_GET_DEVICE_INFO_EX` | `Radio::LocalInfoCompletedCallback` |
| 0x41110C | `IOCTL_BTH_UNPAIR_DEVICE_EX` | `Device::DisconnectInternal` |
| 0x411180 | `IOCTL_BTH_QUERY_RADIO_STATE` | `Radio::SetRadioState` |
| 0x411184 | `IOCTL_BTH_SET_RADIO_STATE` | `Radio::SetRadioState` |
| 0x411D00…0x411D14 | `IOCTL_BTH_WP8_L2CAP_REGISTER`, `UNREGISTER`, `LISTEN`, `CONNECT`, `ATTACH`, `DISPOSE` | `LocalService`, `Connection` |
| 0x414010, 0x414014 | `IOCTL_BTHLEENUM_READ_GATT_EVENT`, `IOCTL_BTHLEENUM_READ_QUEUE_ACTIVATE` | `Device::TryIssueReadQueueIoctls` |
| 0x4143C4 | `IOCTL_BTHLEENUM_TEST_FORCE_CONNECT` (log string) | `Device::ConnectLEDeviceWorker` |

`BthIoctlName` also knows the SCO IOCTLs 0x411CC4…0x411CD0: their sender is [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md#sco-audio). All are processed by the Microsoft stack (`BthPort`, `BthLEEnum`), which isn't analysed.

### ETW

Provider `{A9B5617D-6C0E-4ADC-B076-F3B0CDD4D0ED}` (`Microsoft_WindowsPhone_Bluetooth_CM`), registered in `OnStartCallback`.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 100 | 3 | 1, 1 | 0x100000 | ? | `ConnectingStart` |
| 200 | 3 | 1, 3 | 0x100000 | ? | `DisconnectingStart` |
| 500 | 3 | 2, 500 | 0x100000 | ? | `ConnectedEvent` |
| 600 | 3 | 2, 600 | 0x100000 | ? | `DisconnectedEvent` |
| 700 | 3 | 0, 0 | 0x10000 | ? | `DeviceFriendlyNameAssociation` |
| 1000 | 0 | 0, 10 | 0x100 | ? | `_ETWMESSAGE`, debug text (`EtwTraceMessage`, from `DebugPrintf`) |

The telemetry events are written by `Device::WriteTelemetry` (0x100232AC) and `Connection::LogConnectionToSQM`.  
`__FatalError` (0x1001E564) registers its own provider `{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}` (`Microsoft-WindowsPhone-Net-Debug`) and writes `NET_FATAL_ERROR` (event 100, level 2, task 1, keyword 0x1). There are also WPP traces (`TraceMessage`), used by `BackgroundBroker`.

### SQM

`IsBtSqmInitialized` (0x1003D764) starts a session on `g_WpSqmGlobalSession` if `EnableSQM` is set. `BtSqmLogPairing`, `BtSqmLogConnectionDuration`, `BtSqmLogUniqueDevice`, `BtSqmLogLEDevice`, `BtSqmLEServiceUsage` and `BtSqmLogDeviceFriendlyName` log with `WinSqmIncrementDWORD` and `WinSqmAddToStreamEx`. Addresses are hashed with SHA256 (`BtSqmGenerateDWORD64Hash`).
