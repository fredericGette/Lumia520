## IpOverUsb.dll

The *IP over USB* service of Windows Phone 8.1: it carries TCP connections between the phone and a PC over the USB cable, without any network adapter (used by the developer tools: deployment, debugging, Device Portal–like services).  
`IpOverUsb.dll` is a C++ service DLL hosted by `svchost.exe` (249 856 bytes, 634 functions, a large part of them STL and CRT; no symbols, but every function logs its own `Class::Method` name, which gives the class names used below). It opens the USB function interface `{30613563-7df3-4afb-80e0-e8c427c7e9bf}` exposed by [GenericUsbFnClassIpOverUsb.sys](../drivers/genericusbfnclassipoverusb.md), waits for the USB *Configured* event, then runs a reliable packet protocol (sequence numbers, CRC32, ACKs, retransmission) on the bulk IN/OUT pipes with a peer program on the PC. Over this tunnel it multiplexes TCP streams: it listens on local TCP ports configured in the registry and forwards each accepted connection to the PC (raw SOCKS, or a fixed destination with a SOCKS 4a request it builds itself), and it accepts streams opened by the PC, reads a SOCKS 4 / 4a request from them and connects to the requested address from the phone.  
It refuses the tunnel while the phone is locked (WNF lock state of [ShellChrome.dll](./shellchrome.md#wnf-states), unless `SkipLockCheck` is set) and when the enterprise policy `AllowUSBConnection` of `PolicyManager.dll` forbids it. It publishes a WNF state when the PC partner is available, and offers an LRPC interface (`IpOverUsb-DiscoverPartners-RPC-Endpoint`) that lists the connected partners and their forwarded services. The PC side (the IP over USB service of the Windows Phone SDK, `IpOverUsbSvc.exe` ?) isn't analysed; it runs the same protocol, as the handshake is symmetric.

Location on the phone: `C:\Windows\System32\IpOverUsb.dll` ? (the extracted file has no notes, it was extracted next to [GenericUsbFnClassIpOverUsb.sys](../drivers/genericusbfnclassipoverusb.md)).  
Service name: given by svchost in `ServiceMain` (`argv[0]`), not in the binary (`IpOverUsbSvc` ?).  
PDB: `ipoverusb.pdb`.  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4 | `RpcServerUseProtseqEpW`, `RpcServerRegisterIfEx`, `RpcServerUnregisterIf`, `NdrServerCall2` |
| api-ms-win-service-core-l1-1-1 | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-devices-config-l1-1-1 | `CM_Register_Notification`, `CM_Unregister_Notification`, `CM_Get_Device_Interface_List_SizeW`, `CM_Get_Device_Interface_ListW` |
| api-ms-win-core-file-l1-2-1, api-ms-win-core-io-l1-1-1 | `CreateFileW`, `DeviceIoControl`, `GetOverlappedResult`, `CancelIoEx` |
| ntdll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlQueryWnfStateData`, `RtlPublishWnfStateData` |
| WS2_32 | `WSAStartup`, `WSACleanup`, `WSAIoctl`, `WSASend`, `WSARecv`, `WSAConnectByNameW`, `WSAGetLastError`, `socket`, `bind`, `listen`, `getsockname`, `setsockopt`, `shutdown`, `closesocket`, `inet_addr`, `htonl`, `htons`, `ntohl`, `ntohs` |
| MSWSOCK | `AcceptEx` |
| api-ms-win-core-threadpool-l1-2-0, api-ms-win-core-threadpool-legacy-l1-1-0 | `CreateThreadpoolIo`, `StartThreadpoolIo`, `CancelThreadpoolIo`, `CloseThreadpoolIo`, `QueueUserWorkItem`, `UnregisterWaitEx` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegQueryValueExW`, `RegEnumKeyExW`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0, api-ms-win-core-kernel32-legacy-l1-1-1 | `LoadLibraryW`, `GetProcAddress`, `FreeLibrary`, `WaitForMultipleObjects` |
| api-ms-win-core-sysinfo-l1-2-2 | `GetSystemFirmwareTable`, `GetTickCount` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWriteString` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep`, critical sections, condition variables |
| api-ms-win-core-processthreads-l1-1-2 | `CreateThread`, `GetCurrentProcessId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-string-l1-1-0 | `MultiByteToWideChar`, `WideCharToMultiByte`, `GetStringTypeW` |
| api-ms-win-core-handle-l1-1-0, -errorhandling-l1-1-2, -rtlsupport-l1-2-0, -util-l1-1-0 | `CloseHandle`, `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `EncodePointer`, `DecodePointer` |
| msvcrt | C and C++ runtime (`malloc`, `free`, `operator new`/`delete`, `memcpy_s`, `vswprintf_s`, `wcscpy_s`, `_CxxThrowException`, `__CxxFrameHandler3`, `setlocale`, `_initterm`, `__dllonexit`, …) |

The msvcrt, rtlsupport, util, errorhandling and `GetCurrentProcess` / `TerminateProcess` imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. The binary also embeds the STL (`std::map`, `std::deque`, `std::tr1::function`, `std::tr1::shared_ptr`, iostreams / locale).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `PolicyManager.dll` | `LoadLibraryW` + `GetProcAddress("PolicyManager_GetConnectivityPolicy_AllowUSBConnection")` ([Startup](#platform-initialisation-sub_1001ac9c)), not in Manufacturing mode | Enterprise policy: is the USB connection allowed |
| `\\?\USBFN#IpOverUsb#…#{30613563-7df3-4afb-80e0-e8c427c7e9bf}` ([GenericUsbFnClassIpOverUsb.sys](../drivers/genericusbfnclassipoverusb.md)) | `CM_Get_Device_Interface_ListW` + `CreateFileW` (overlapped), opened twice: discovery and partner link | USB bus events and bulk transfers, see [IOCTLs](#ioctls) |
| SMBIOS table (`RSMB`) | `GetSystemFirmwareTable` ([GetHardwareGuid](#hardware-guid)) | UUID of the phone, sent in the handshake |

No process or COM server is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `ServiceMain` | 0x10018A74 | `DWORD argc, LPWSTR *argv` |
| 2 | `SvchostPushServiceGlobals` | 0x10018820 | `PSVCHOST_GLOBAL_DATA` (saved in `dword_10036F44`) |

`DllEntryPoint` (0x10032520) is the CRT entry point (`dllmain_dispatch`, 0x1003222C): CRT init only, nothing else is done at load time.

### Objects

The service is built from a few C++ singletons and classes:

| Class | Where | Role |
|-------|-------|------|
| `PhoneUsbPlatformAdapter` (derived from `PlatformAdapter`) | global at 0x10036078, pointer `off_10036054` | Logging (ETW), configuration, lock / policy state, factory of the USB objects. Vtable `off_100049BC`: [0] destructor, [1] `Log` (`sub_10022F9C`), [2] `StartDiscovery` (`sub_1001AF3C`), [3] `StopDiscovery` (`sub_1001B024`), [4] `CreatePartnerLink` (`sub_1001B04C`), [5] `NotifyPartnersAvailable` (`sub_1001B128`), [6] `NotifyPartnersUnavailable` (`sub_1001B184`), [7] `WaitForUnlock` (`sub_1001B1E0`), [8] `IsUsbConnectionAllowed` (`sub_1001B3F4`) |
| `ServiceController` | 0x64 bytes, `dword_10036F50` (shared pointer `dword_10036F54`) | Map partner Id → `ProxyController`; RPC enumeration |
| `PhoneUsbPartnerDiscovery` | 0x220 bytes | Watches the USB function device and its bus events, adds / removes the partner `PC` |
| `ProxyController` | 0x300 bytes, one per partner | Owns the tunnel, the listeners and the connections of one partner |
| `ReliableTransportTunnel` | in the `ProxyController` at +0x98 | Packet protocol over USB |
| `PhoneUsbPartnerLink` | 0xB4 bytes | Bulk read / write on the USB function device |
| `NetworkController` | global at 0x10036F58 | Winsock: asynchronous sockets on the thread pool, `ConnectEx` / `DisconnectEx` from `WSAIoctl` |
| `ConnectionListener` | one per configured port | Listening socket |
| `Connection` → `SocksConnection`, `MappedPortConnection`, `RemoteConnection` | one per stream | TCP socket ↔ tunnel stream |

`PhoneUsbPlatformAdapter` (0x10036078):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `off_100049BC` |
| 0x08 | 8 | ETW registration handle |
| 0x10 | 4 | `PartnerTransferBuffers` (default 4) |
| 0x14 | 4 | `PartnerTransferBufferSize` (default 0x3FFF) |
| 0x18 | 4 | `ConnectionBuffers` (default 16) |
| 0x1C | 4 | `ConnectionBufferSize` (default 4000) |
| 0x20 | 4 | `MaxRemoteConnections` (default 100) |
| 0x24 | 4 | `PartnerTransferErrorWait` (ms, default 200) |
| 0x28 | 4 | `PartnerTransferAckTimeout` (ms, default 500) |
| 0x2C | 1 | `PerDevicePortConfiguration` (default 0) |
| 0x30, 0x34 | 8 | Discovery object (shared pointer) |
| 0x38, 0x3C | 8 | "Phone unlocked" event (manual reset) |
| 0x40 | 4 | Subscription to the lock state (0x418A063EA3BC0875) |
| 0x44 | 1 | `SkipLockCheck` |
| 0x48 | 4 | Subscription to `WNF_ENTR_CONNECTIVITY_POLICY_VALUE_CHANGED` |
| 0x4C | 1 | USB connection allowed by policy (initially 1) |
| 0x50 | 0x18 | Critical section protecting +0x4C |
| 0x68 | 4 | Module handle of `PolicyManager.dll` |
| 0x6C | 4 | Terminate event of the service (created by `ServiceMain`) |

### ServiceMain (0x10018A74)

1. Creates the auto-reset *terminate* event, then initialises the platform adapter ([below](#platform-initialisation-sub_1001ac9c)); returns if it fails.
2. Checks `argc` ≠ 0 and the svchost global data, keeps `argv[0]` as service name and logs "IP Over USB Service starting, service name is '%s'".
3. `RegisterServiceCtrlHandlerExW(argv[0], ServiceHandler)`, status `SERVICE_START_PENDING` (type 0x20, `SERVICE_WIN32_SHARE_PROCESS`).
4. Creates the `ServiceController` (`sub_100205E4`) and starts it (`ServiceController::Start`, `sub_10020788`): `NetworkController::Initialize` (`WSAStartup` 2.2, a configuration socket, `ConnectEx` / `DisconnectEx` pointers), then `StartDiscovery`.
5. Starts the RPC server (`StartRpcServer`, `sub_100186A4`, see [RPC](#rpc)).
6. Registers the terminate event with the svchost global data (function at +0x60: `RegisterStopCallback(&hWait, name, hEvent, StopService, NULL, 8)`), so that `StopService` (`sub_100189A4`) runs when the event is set. Status `SERVICE_RUNNING`, controls accepted: `SERVICE_ACCEPT_STOP`.

Any failure calls `sub_10018834` (stop): status `SERVICE_STOP_PENDING`, closes the event and the wait, `ServiceController::Shutdown`, `RpcServerUnregisterIf`, unsubscribes the two WNF states, `FreeLibrary(PolicyManager.dll)`, `EventUnregister`, status `SERVICE_STOPPED`.  
`ServiceHandler` (`sub_100189D8`) only handles `SERVICE_CONTROL_STOP` (1): it sets the terminate event. The platform adapter also sets it (`TerminateService`, `sub_1001B28C`) when the USB device is removed or the bus is torn down: the service stops itself when the USB function goes away, and is started again on demand ?

### Platform initialisation (sub_1001AC9C)

`PhoneUsbPlatformAdapter::Initialize`:
1. Sets the default configuration (see [Objects](#objects)), `EventRegister({9a852f9a-bb71-4c78-8cc4-a3e722380f89})`, logs "Platform Initialization v%u.%u (PID: %u)" and reads the configuration ([Registry](#registry)).
2. Reads `SkipLockCheck`. If it isn't set: creates the "phone unlocked" event and subscribes to the lock state 0x418A063EA3BC0875 with `NotificationCallback` (`sub_1001AB40`).
3. If the phone isn't in Manufacturing mode (`MMOSHelper::IsMMOS`, `sub_1001B424`: `HKLM\Software\Microsoft\ManufacturingOS\ManufacturingMode` = 1): loads `PolicyManager.dll` and gets `PolicyManager_GetConnectivityPolicy_AllowUSBConnection`.
4. Reads (`RtlQueryWnfStateData`) and subscribes to `WNF_ENTR_CONNECTIVITY_POLICY_VALUE_CHANGED` with `AllowUSBConnectionWNFNotificationCallback` (`sub_1001AAA8`): it calls `PolicyManager_GetConnectivityPolicy_AllowUSBConnection(&flag)` and stores `flag == 1` as "allowed". The data of the state isn't used. Failures of step 3 / 4 are only logged (the connection stays allowed).

`NotificationCallback` checks that the data is 4 bytes and passes it to `LockStatusChanged` (`sub_1001ABB0`): 0 = unlocked → sets the "phone unlocked" event; 1 = screen locked, 2 = password locked, 0x7FFFFFFF = unknown, other values → resets it. `WaitForUnlock` returns at once if `SkipLockCheck` is set, otherwise waits for the "phone unlocked" event or the shutdown event of the caller.

### Partner discovery

`PhoneUsbPartnerDiscovery::Start` (`sub_10019374`):
1. `CM_Register_Notification` with a `CM_NOTIFY_FILTER` of 416 bytes, type `CM_NOTIFY_FILTER_TYPE_DEVICEINTERFACE`, class `{30613563-7df3-4afb-80e0-e8c427c7e9bf}`, callback `DeviceNotifyCallback` (`sub_100192B8`): removal (`CM_NOTIFY_ACTION_DEVICEINTERFACEREMOVAL`) → "Device removal, stopping service" → `TerminateService`; arrival is only logged as unexpected.
2. `CM_Get_Device_Interface_ListW` of the same class: if no device is present, the discovery doesn't start ("Device is not present on discovery start, not starting").
3. Opens the first interface (`GetDeviceHandle`, `sub_1001964C`: `CreateFileW(GENERIC_READ|GENERIC_WRITE, FILE_SHARE_READ|FILE_SHARE_WRITE, OPEN_EXISTING, FILE_FLAG_OVERLAPPED)`).
4. Sends `IOCTL_GENERICUSBFN_ACTIVATE_USB_BUS` (`ActivateUsbBus`, `sub_1001970C`).
5. Starts the thread `NotifyThreadRoutine` (`sub_10019834`).

`NotifyThreadRoutine` loops on `IOCTL_GENERICUSBFN_BUS_EVENT_NOTIFICATION` (output 12 bytes: `USBFN_NOTIFICATION`), retrying after 100 ms on error, and passes the event to `ProcessNotification` (`sub_10019A90`):

| Event (`USBFN_EVENT`) | Action |
|-----------------------|--------|
| 1 Attach, 2 Reset, 4 Suspend, 5 Resume, 6 SetupPacket | Logged only |
| 7 Configured | If no partner yet: `ServiceController::OnPartnerAdd(Id "PC", Instance "", Name "", Type 0)` (`sub_10019BB4`) |
| 3 Detach, 8 Unconfigured | If a partner was added: `ServiceController::OnPartnerRemove("PC")` (`sub_10019C5C`) |
| 10 BusTearDown | `TerminateService` |

There is only one partner, always named `PC`.

`ServiceController::OnPartnerAdd` (`sub_10020C08`) creates a `ProxyController` (`sub_10026A2C`) for the partner, which creates its `ReliableTransportTunnel` and its `PhoneUsbPartnerLink` (platform method [4]), and starts it (`sub_10026F24` → `ReliableTransportTunnel::Start`). `OnPartnerRemove` (`sub_10020FB4`) shuts it down. A reset requested by the tunnel (incompatible handshake, failed retries) restarts the `ProxyController` (`ResetProxyControllerTaskCallback`, `sub_10021448`).

### Partner link

`PhoneUsbPartnerLink::Start` (`sub_10019F9C`) opens the same device interface again (`sub_1001A4C8`) and reads its pipes (`GetPipeInformation`, `sub_1001A584`) with `IOCTL_GENERICUSBFN_GET_CLASS_INFO` (748-byte [USBFN_CLASS_INFORMATION_PACKET](../drivers/genericusbfnclass.md#usbfn_class_information_packet)). It uses the **high-speed** interface only: `PipeArr[1]` must be an IN endpoint (bit 7 of `bEndpointAddress`) and `PipeArr[2]` an OUT endpoint, and `PipeCount` must be at least 2. On the phone these are the endpoints 0x81 and 0x02 of the [interface descriptor](../drivers/genericusbfnclassipoverusb.md#usb-function-configuration).

| Offset | Size | Comment |
|--------|------|---------|
| 0x40 | 0x30 | Task controller (shutdown, pending tasks) |
| 0x70, 0x74 | 8 | Device handle (shared) |
| 0x78 | 4 | `PipeId` of the IN pipe (phone → PC) |
| 0x7C | 4 | `PipeId` of the OUT pipe (PC → phone) |
| 0x80 | 0x18 | Critical section of the IOCTLs |
| 0x98 | 0x1C | Device interface path |

- `Write` (`sub_1001A324`): `IOCTL_GENERICUSBFN_TRANSFER_IN`, input = IN `PipeId`, output = the packet. `Read` (`sub_1001A180`): `IOCTL_GENERICUSBFN_TRANSFER_OUT`, input = OUT `PipeId`, output = the buffer. Both are overlapped (`WaitOverlappedRead` / `WaitOverlappedWrite`).
- If the IOCTL fails, `ResetPipe` (`sub_1001A76C`): `IOCTL_GENERICUSBFN_GET_PIPE_STATE` (input `PipeId`, output 1 byte: stalled); if stalled, `IOCTL_GENERICUSBFN_SET_PIPE_STATE` with 0 (clear the stall).
- `Shutdown` cancels the pending transfers (`CancelIoEx`).

### Reliable transport

`ReliableTransportTunnel::Start` (`sub_1002A230`) builds the local [configuration](#handshake-configuration), allocates `PartnerTransferBuffers` buffers (max 127) and starts the threads: read (`ReadThreadRoutine`, `sub_1002AACC`), command packing (`ProcessCommandsThreadRoutine`, `sub_1002AE4C`), write (`WriteThreadRoutine`, `sub_1002B930`) and the two write-completion threads (reliable: `sub_1002BF10`, unreliable: `sub_1002BD0C`).

`ReadThreadRoutine`:
1. Leaves if the policy forbids the USB connection ("USB Connection is disabled by policy").
2. Waits for the phone to be unlocked (`WaitForUnlock`).
3. Starts the handshake read task (`ReadHandshakeTaskCallback`, `sub_1002E0C0`) and runs the handshake (`Handshake`, `sub_1002D770`): writes the configuration (command 7) and waits for the configuration of the PC, with retries, then resets the transport if it doesn't succeed.
4. Loops: reads a transfer of `PartnerTransferBufferSize` bytes and processes it (`ProcessReceivedPacket`, `sub_1002C998`); on error sleeps `PartnerTransferErrorWait` ms.

When the tunnel is configured, the `ProxyController` is notified (`OnReliableTransportTunnelReady`, `sub_100278A0`): it logs "Connected to Partner guid %s, version %u.%u…", publishes the [partners-available WNF state](#wnf-states) with 1, and starts the listeners (`sub_10028304` → `GetConfiguredServicePorts`). When the tunnel goes down it publishes 0 ("Tunnel down for Partner '%s'. Notifying Partners Unavailable").

**Packet** (one USB transfer, at most `PartnerTransferBufferSize` bytes; the default 0x3FFF is odd so that a full packet is never a multiple of 512 and needs no zero-length packet; a received transfer one byte longer than the header length is accepted as ZLT padding):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Length of the packet, header included (≥ 9) |
| 0x04 | 4 | CRC32 (reflected, polynomial 0xEDB88320, init 0xFFFFFFFF, final XOR) of the whole packet computed with this field set to 0 |
| 0x08 | 1 | Sequence number: 0 = no reliable payload (unreliable packet: ACKs, handshake), otherwise 1…255 (wraps to 1) |
| 0x09 | … | Commands, packed one after the other |

A packet with a sequence number is processed only if it's the expected one; then an ACK (command 6, tag = sequence) is sent back. A packet already received (sequence within `PartnerTransferBuffers` before the expected one) is acknowledged again without being processed; others are dropped. The writer keeps each reliable packet until its ACK arrives (timeout `PartnerTransferAckTimeout` ms) and retransmits every pending packet on timeout (`RetransmitPackets`, `sub_1002C3C8`).

**Command**:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Length of the command, header included (≥ 9) |
| 0x04 | 1 | Command |
| 0x05 | 4 | Tag: stream id (the sender XORs its own connection id with 0x80000000, so the ids of both sides never collide), ACK sequence, or handshake flag |
| 0x09 | … | Data |

| Command | Queue | Sent by | Received → |
|---------|-------|---------|------------|
| 1 open stream | in band (reliable) | `OpenStream` (`sub_1002A668`) | `ProxyController::OnOpenStream` (`sub_10027A3C`): creates a [RemoteConnection](#tcp-forwarding), unless `MaxRemoteConnections` streams are already open (then the stream is closed) |
| 2 data | in band | `BeginWriteData` (`sub_1002A870`) | `ProxyController::OnDataRead` (`sub_10027E20`) → connection |
| 3 close stream | in band | `CloseStream` (`sub_1002A7CC`) | `ProxyController::OnCloseStream` (`sub_10027CE4`) |
| 4 writer shutdown | in band | `WriterShutdown` (`sub_1002A728`) | `ProxyController::OnWriterShutdown` (`sub_10027BFC`): `shutdown(SD_SEND)` of the socket |
| 5 data delivered | out of band (reliable) | `DataDelivered` (`sub_1002A974`) | `ProxyController::OnDataDelivered` (`sub_1002800C`): flow control, the PC has written a data buffer to its socket |
| 6 ACK | unreliable | `ProcessReceivedPacket` | `ProcessReceivedAck` (`sub_1002D298`) |
| 7 handshake | unreliable | `Handshake`; reply with tag 1 | `ProcessReceivedHandshake` (`sub_1002D35C`) |

Commands 1…5 are accepted only once the tunnel is configured, and only in a packet with a sequence number. Flow control: each connection has `ConnectionBuffers` buffers of `ConnectionBufferSize` bytes; data read from a socket is sent only while fewer than `ConnectionBuffers` deliveries are pending.

### Handshake configuration

Data of command 7 (36 bytes), sent by both sides:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 16 | Hardware GUID of the sender ([below](#hardware-guid)); the one of the PC is shown by the RPC enumeration |
| 0x10 | 4 | Version, 1 |
| 0x14 | 4 | `PartnerTransferBuffers` (1…127) |
| 0x18 | 4 | `PartnerTransferBufferSize` (≥ 0x3FFF) |
| 0x1C | 4 | `ConnectionBuffers` (≥ 1) |
| 0x20 | 4 | `ConnectionBufferSize` (≥ 4000, then limited to the max payload of a packet) |

A received configuration out of range is ignored. Otherwise each value is set to the minimum of both sides, the configuration is answered (command 7 with tag 1) if the received one wasn't a reply, and the "configured" event is set. A handshake received after the tunnel is configured is ignored if it's compatible, otherwise the proxy is reset.

### Hardware GUID

`PlatformAdapter::GetHardwareGuid` (`sub_10023D70`): `GetSystemFirmwareTable('RSMB', 0, …)`, then searches the SMBIOS structures for the *System Information* (type 1) structure and takes its 16-byte UUID. If none is found the GUID is zero ?

### TCP forwarding

**Listeners**: `GetConfiguredServicePorts` (`sub_10023074`) enumerates the subkeys of the [configuration keys](#registry): one subkey per service, its name is the service name. For each one a `ConnectionListener` binds `LocalAddress:LocalPort` (retrying, then falling back to a variable port if the port is in use) and accepts connections with `AcceptEx`:
- with `DestinationAddress` and `DestinationPort` → **mapped port**: each accepted connection becomes a `MappedPortConnection`, which opens a stream and sends itself a SOCKS 4a request to the PC: `04 01 <port, big endian> 00 00 00 01 "MappedPort" 00 <DestinationAddress (ANSI)> 00`. The 8-byte reply must have `CD` = 0x5A (granted; 0x5B = rejected), then the data is forwarded both ways.
- without them → **SOCKS port**: each accepted connection becomes a `SocksConnection`, which opens a stream and forwards the bytes unchanged: the local client speaks SOCKS to the PC side.

**Streams opened by the PC**: a `RemoteConnection` (`sub_100315A4`) collects a SOCKS 4 / 4a request (max 0x4000 bytes; `VN` = 4, `CD` = 1 connect, user id ignored). SOCKS 4 (`DSTIP` outside 0.0.0.1…0.0.0.255): `NetworkController::BeginConnect` to `DSTIP:DSTPORT`; SOCKS 4a (`DSTIP` = 0.0.0.x, host name after the user id): `NetworkController::ConnectByName` (`WSAConnectByNameW`) with the host name. It answers the SOCKS reply (0x5A / 0x5B) and then forwards the data. Nagle is disabled on the sockets (`TCP_NODELAY`).

### RPC

Server: `RpcServerUseProtseqEpW(L"ncalrpc", 10, L"IpOverUsb-DiscoverPartners-RPC-Endpoint", NULL)` (`RPC_S_DUPLICATE_ENDPOINT` accepted), `RpcServerRegisterIfEx(if, NULL, NULL, RPC_IF_AUTOLISTEN, RPC_C_LISTEN_MAX_CALLS_DEFAULT, NULL)`: no security callback and no security descriptor, any local process can call it.

Interface `{d5189730-cf9e-4cd6-b915-aa44ed776be9}` version 1.0 (`RPC_SERVER_INTERFACE` at 0x100048F0, MIDL server info 0x100048CC).

| Opnum | Routine | Parameters | Use |
|-------|---------|------------|-----|
| 0 | `sub_10018744` → `ServiceController::RpcGetConnectedPartners` (`sub_10020994`) | implicit handle, `[out] PARTNER **` (unique, linked list), no return value | List of the connected partners and of their forwarded services |

The list is built with `malloc` (`MIDL_user_allocate` = `sub_100187A8`) under the lock of the partner map.

`PARTNER` (0x24 bytes, `FC_PSTRUCT`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `wchar_t *` Id (`PC`) |
| 0x04 | 4 | `wchar_t *` Instance (empty) |
| 0x08 | 4 | `wchar_t *` Name (empty) |
| 0x0C | 16 | Hardware GUID received in the handshake of the PC |
| 0x1C | 4 | `SERVICE *` first forwarded service (`ProxyController::RpcGetActiveServices`, `sub_10027254`) |
| 0x20 | 4 | `PARTNER *` next |

`SERVICE` (0x18 bytes):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `wchar_t *` service name (registry subkey) |
| 0x04 | 2 | Local port really bound |
| 0x08 | 4 | Type (mapped port / SOCKS) ? |
| 0x0C | 4 | `wchar_t *` destination address |
| 0x10 | 2 | Destination port |
| 0x14 | 4 | `SERVICE *` next |

The clients of this interface aren't known (developer tools on the phone ?).

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x418A063EA3BC0875 | `SHL`, 1 | 4 bytes: lock state (0 unlocked, 1 screen locked, 2 password locked) | Subscribed by `PhoneUsbPlatformAdapter::Initialize` unless `SkipLockCheck`; published by [ShellChrome.dll](./shellchrome.md#wnf-states) |
| 0x13920028A3BC2075 `WNF_ENTR_CONNECTIVITY_POLICY_VALUE_CHANGED` | `ENTR`, 4 | not read | Queried and subscribed: re-reads `PolicyManager_GetConnectivityPolicy_AllowUSBConnection` |
| 0x41C61D22A3BC8075 | `OS`, 16 | 4 bytes, low byte: 1 = partner available, 0 = unavailable | Published by `NotifyPartnersAvailable` / `NotifyPartnersUnavailable` when the tunnel goes up / down |

### ETW

Provider `{9a852f9a-bb71-4c78-8cc4-a3e722380f89}`, registered in `PhoneUsbPlatformAdapter::Initialize`, unregistered in `UninitializeBase` (`sub_10022F58`).  
All the traces go through `PlatformAdapter::Log` (`sub_10022F9C`, vtable method [1]: `this, level, function, line, format, …`): the message is formatted with `vswprintf_s` (512 characters), prefixed with `[RetailInfo] `, `[Error] `, `[Info] ` or `[Detail] ` for the levels 0…3, and written with `EventWriteString(handle, level, 0, text)`. Levels ≥ 4 are dropped. There's no manifest-based event.

### Registry

Configuration values (REG_DWORD), read by `PlatformAdapter::ReadConfigDwordValue` (`sub_10023AB0`) from the first of these `HKLM` keys that has the value: `Software\Microsoft\IpOverUsbKit`, `Software\Microsoft\IpOverUsbSdk`, `Software\Microsoft\IpOverUsb`.

| Value | Default | Comment |
|-------|---------|---------|
| `PartnerTransferBuffers` | 4 | Reliable packets in flight (max 127); 0 ignored |
| `PartnerTransferBufferSize` | 0x3FFF | Packet size; < 0x3FFF ignored, an even value is decremented |
| `ConnectionBuffers` | 16 | Buffers per connection; 0 ignored |
| `ConnectionBufferSize` | 4000 | < 4000 ignored |
| `MaxRemoteConnections` | 100 | Streams opened by the PC |
| `PartnerTransferErrorWait` | 200 | ms before retrying a failed read / write |
| `PartnerTransferAckTimeout` | 500 | ms before retransmitting |
| `PerDevicePortConfiguration` | 0 | ≠ 0: the port subkeys are read under `<key>\<GUID of the partner>` ? |

Forwarded ports: subkeys `HKLM\<one of the 3 keys above>\<service name>` (all three keys are enumerated):

| Value | Type | Comment |
|-------|------|---------|
| `LocalAddress` | REG_SZ | Default `0.0.0.0` |
| `LocalPort` | REG_DWORD | Required |
| `DestinationAddress` | REG_SZ | With `DestinationPort`: mapped port, see [TCP forwarding](#tcp-forwarding) |
| `DestinationPort` | REG_DWORD | |

Other values:

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\Software\Microsoft\IpOverUsb` | `SkipLockCheck` (REG_DWORD) | 1: don't wait for the phone to be unlocked |
| `HKLM\Software\Microsoft\ManufacturingOS` | `ManufacturingMode` (REG_DWORD) | 1: don't load `PolicyManager.dll` |

No port subkey or value was observed on the phone (not checked).

### IOCTLs

Sent to [GenericUsbFnClassIpOverUsb.sys](../drivers/genericusbfnclassipoverusb.md) (all `METHOD_*` as in [genericusbfnclass.sys](../drivers/genericusbfnclass.md#ioctl-forwarding)), overlapped:

| IOCTL | Name | Sent by | Input | Output |
|-------|------|---------|-------|--------|
| 0x22C02C | `IOCTL_GENERICUSBFN_ACTIVATE_USB_BUS` | `PhoneUsbPartnerDiscovery::ActivateUsbBus` | none | none |
| 0x22C036 | `IOCTL_GENERICUSBFN_BUS_EVENT_NOTIFICATION` | `PhoneUsbPartnerDiscovery::NotifyThreadRoutine` | none | 12 bytes `USBFN_NOTIFICATION` (event, then union) |
| 0x22C022 | `IOCTL_GENERICUSBFN_GET_CLASS_INFO` | `PhoneUsbPartnerLink::GetPipeInformation` | none | 748 bytes `USBFN_CLASS_INFORMATION_PACKET` |
| 0x22C00D | `IOCTL_GENERICUSBFN_TRANSFER_IN` | `PhoneUsbPartnerLink::Write` | IN `PipeId` (4) | packet |
| 0x22C016 | `IOCTL_GENERICUSBFN_TRANSFER_OUT` | `PhoneUsbPartnerLink::Read` | OUT `PipeId` (4) | buffer of `PartnerTransferBufferSize` bytes |
| 0x22C026 | `IOCTL_GENERICUSBFN_GET_PIPE_STATE` | `PhoneUsbPartnerLink::ResetPipe` | `PipeId` (4) | 1 byte: stalled |
| 0x22C029 | `IOCTL_GENERICUSBFN_SET_PIPE_STATE` | `PhoneUsbPartnerLink::ResetPipe` | `PipeId` (4) | 1 byte: 0 (clear stall) |

`IOCTL_GENERICUSBFN_DEACTIVATE_USB_BUS` (0x22C030) and the control-status handshakes aren't used.
