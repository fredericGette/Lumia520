## BthOPPManager.dll

The Bluetooth Object Push Profile (OPP) of Windows Phone 8.1: a COM in-process server that sends and receives files over OBEX on an RFCOMM socket.  
`BthOPPManager.dll` is a C++ DLL (242 functions, the database has its full symbols, about a third of the code is STL and CRT). Its single COM class, `OPPManager`, registers with the Bluetooth connection manager as the responder of two profiles: the standard `OBEXObjectPushServiceClass_UUID` for incoming connections, and a private `BTCM_OPP_OUTGOING_PSEUDO_UUID` for the connections it opens itself. Each connection becomes an `OPPSession`, which runs its own OBEX client or server (`ObexSession`, over `AsyncDataSocket`: overlapped `WSASend` / `WSARecv`). Only OBEX `PUT` is implemented. The file data never goes through a path: the user of the DLL passes file handles, read and written with `ReadFile` / `WriteFile`.  
It relies on [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) (`IBtConnectionResponder`), and so on [BtConnectionManagerService.dll](./btconnectionmanagerservice.md), for the RFCOMM sockets and the SDP side. Its user (the process that creates `{B0DB6E5C-4726-4C27-BD69-FA322FCDD835}`, probably the share / "send via Bluetooth" UI and the receive notification) is unknown: no other extracted binary contains the CLSID, the IIDs of its interfaces or its name.

Location on the phone: `C:\Windows\System32\BthOPPManager.dll` ? (the extracted file has no notes).  
CLSID: `{B0DB6E5C-4726-4C27-BD69-FA322FCDD835}`.  
Source folder: `src\net\bluetooth\product\services\servicelib\` (string of `reghelper.cpp`); PDB `bthoppmanager.pdb`.  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance` |
| WS2_32 | `WSAStartup`, `WSACleanup`, `WSAGetLastError`, `WSACreateEvent`, `WSASetEvent`, `WSASend`, `WSARecv`, `WSAGetOverlappedResult`, `closesocket` |
| api-ms-win-core-file-l1-2-1 | `GetFileSizeEx`, `SetFilePointer`, `ReadFile`, `WriteFile` |
| api-ms-win-core-kernel32-legacy-l1-1-1, api-ms-win-core-threadpool-legacy-l1-1-0 | `RegisterWaitForSingleObject`, `UnregisterWaitEx` |
| api-ms-win-core-synch-l1-2-0 | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `Sleep` |
| api-ms-win-core-registry-l1-1-0 | `RegCreateKeyExW`, `RegSetValueExW`, `RegDeleteKeyExW`, `RegCloseKey` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-libraryloader-l1-2-0 | `DisableThreadLibraryCalls`, `GetModuleFileNameW`, `GetModuleFileNameA`, `GetModuleHandleExW` |
| api-ms-win-core-sysinfo-l1-2-2 | `GetTickCount` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-processthreads-l1-1-2 | `GetCurrentProcess`, `TerminateProcess`, `GetCurrentThreadId` |
| api-ms-win-core-errorhandling-l1-1-2 | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1 | `DebugBreak`, `IsDebuggerPresent`, `OutputDebugStringA` |
| api-ms-win-core-rtlsupport-l1-2-0 | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | C and C++ runtime (`malloc`, `free`, `operator new`/`delete`, `_CxxThrowException`, `__CxxFrameHandler3`, `_initterm`, `_vsnprintf`, `_vsnwprintf`, `memcpy`, `wcschr`, …) |

The msvcrt, rtlsupport, `Sleep`, and part of the debug, errorhandling and processthreads imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. `GetModuleHandleExW` and `GetModuleFileNameA` are only in `EtwInitializeTraceMessaging` (0x10003BE8), which nothing calls; `CloseHandle` is only in the CRT range; `GetCurrentThreadId` is used by `Synchronizer::EnqueueEvent`.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) | `CoCreateInstance({101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}, NULL, 0x17, IID_IBtConnectionResponder)` ([BTCMAttach](#connection-manager)) | RFCOMM connections, profile states |
| Files of the user | Handles passed to `IBthOPPSession::Send` and `AcceptReceive`; `GetFileSizeEx`, `SetFilePointer`, `ReadFile`, `WriteFile` ([ObexFileObject](#obexfileobject)) | Content of the objects sent and received |

No DLL is loaded at run time, no file is opened by name and no process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllRegisterServer` | 0x10005C80 | none |
| 2 | `DllUnregisterServer` | 0x10005C98 | none |
| 3 | `DllCanUnloadNow` | 0x10005BEC | none |
| 4 | `DllGetClassObject` | 0x10005C08 | `REFCLSID rclsid, REFIID riid, void **ppv` |

`DllGetClassObject` answers `REGDB_E_CLASSNOTREG` (0x80040154) for any other CLSID; otherwise it creates an `OPPFactory` (8 bytes: vtable, reference count) and calls its `QueryInterface` (`IUnknown`, `IClassFactory`). `OPPFactory::CreateInstance` (0x10005B14) refuses aggregation (`CLASS_E_NOAGGREGATION`), allocates an `OPPManager` (0x4C bytes) and calls its `QueryInterface`. Each instance is independent. `LockServer` and every object change the module counter `g_lcModuleRef`; `DllCanUnloadNow` returns `S_FALSE` while it isn't 0.

`DllRegisterServer` (`COMServerRegister`, 0x10005CE4) writes under `HKLM\SOFTWARE\Classes\CLSID\{B0DB6E5C-4726-4c27-BD69-FA322FCDD835}`: the default value `Client interface to Bluetooth Object Push Profile (OPP) Manager`, then in `InProcServer32` the path of the DLL (`GetModuleFileNameW`) and `ThreadingModel` = `Both`. `DllUnregisterServer` deletes `InProcServer32`, then the CLSID key. An unexpected registry error calls `__FatalError`.

### Startup

`_DllMainCRTStartup` (0x10009BD0): CRT. `DllMain` (0x10005BAC), on `DLL_PROCESS_ATTACH`: stores the module handle, `DisableThreadLibraryCalls`, `McGenEventRegister` (the [ETW provider](#etw)) and sets `g_DebugEnabled`. On `DLL_PROCESS_DETACH`: clears `g_DebugEnabled` and `McGenEventUnregister`.

### COM interfaces

| Interface | IID | Implemented by |
|-----------|-----|----------------|
| `IBthOPPManager` | `{078FF414-A609-4BE2-AF2D-B152E5CAA154}` | `OPPManager`+0x00, also the `IUnknown` |
| `IBtConnectionResponderCallback` | `{EB794A01-E173-4D1E-9CD4-2037CDB529E3}` | `OPPManager`+0x04 |
| `IBtCommandCallback` | `{0EBA760C-C48D-4811-B4C4-8CE879B201B1}` | `OPPManager`+0x08 |
| `IBthOPPSession` | `{95A75BD1-4144-4D0F-82F4-89C1EBF27DBD}` | `OPPSession`+0x04 |
| `IObexSessionCallback` | `{B91E1328-9E45-4E18-9649-28C0F8B9398D}` | `OPPSession`+0x00 |
| `IObexObjectCallback` | `{64DA2352-F415-4F76-85B6-9106560F4A16}` | `ObexFileObject` |
| `IAsyncDataSocketCallback` | `{BD1CD81A-7761-447C-89A4-DBEE9B5F3AB2}` | `ObexSession`+0x08 |
| `IBthOPPListenerCallback`, `IBthOPPSessionCallback` | ? (implemented by the user) | See [Callbacks](#callbacks) |

The IID of `IBtCommandCallback` wasn't known from [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md#callbacks). The methods start at vtable index 3, after `IUnknown`; their names are the symbols of the binary. All of them only queue an event and return `S_OK`; the work is done by the `Dispatch` of the object (see [Threading](#threading)).

`IBthOPPManager` (vtable 0x10001678):

| Index | Method | Address | Event | Action |
|-------|--------|---------|-------|--------|
| 3 | `RegisterListener(IBthOPPListenerCallback *)` | 0x100056D4 | 0 | Replaces the listener, then `BTCMAttach` |
| 4 | `Connect(unsigned __int64 address, IBthOPPSession **)` | 0x10005704 | 1 | Returns at once a new outgoing `OPPSession`, then [DispatchConnect](#outgoing-connection) |
| 5 | `Close()` | 0x10005838 | 2 | Once: releases the listener and `BTCMDetach` (called twice) |

`IBtConnectionResponderCallback` (vtable 0x10001660), called by the connection manager client:

| Index | Method | Address | Event |
|-------|--------|---------|-------|
| 3 | `AcceptRfcommConnection(SOCKET, const SOCKADDR_BTH *, const WCHAR *name, BYTE fIncoming)` | 0x10002C08 | 4: [DispatchRFCOMMConnected](#incoming-connection) |
| 4 | `AcceptL2CapConnection(handle, address, psm, outMtu, inMtu, BYTE)` | 0x10002FB8 | none: "OPP does not support direct L2CAP", `E_FAIL` |
| 5 | `DisconnectConnection(unsigned __int64 address)` | 0x10002CA0 | 5: calls `Disconnect` on the outgoing and the incoming session of the address |

`IBtCommandCallback::CommandCompleted(void *context, HRESULT)` (0x10002F8C) ends a `ConnectProfileToDevice` (event 7, the HRESULT reduced to its Win32 code when it is an error).

`IBthOPPSession` (vtable 0x10001524):

| Index | Method | Address | Event | Action |
|-------|--------|---------|-------|--------|
| 3 | `RegisterStatusUpdate(IBthOPPSessionCallback *)` | 0x10004F10 | 4 | Sets the callback and starts the OBEX session |
| 4 | `GetDeviceInfo(BLUETOOTH_OPP_DEVICE_INFO *)` | 0x10004F48 | none | Copies the address and the name (below) |
| 5 | `Send(HANDLE hFile, const WCHAR *path, const char *type)` | 0x10004C5C | 1 | [Sending](#sending-a-file) |
| 6 | `AcceptReceive(HANDLE hFile)` | 0x10004E30 | 2 | [Receiving](#receiving-a-file) |
| 7 | `Cancel()` | 0x10004E60 | 3 | `DispatchCancel` |
| 8 | `Disconnect()` | 0x10004F98 | 5 | OBEX `DISCONNECT` |
| 9 | `Close()` | 0x10004FC4 | 6 | `DispatchClose` |

`BLUETOOTH_OPP_DEVICE_INFO`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | Device address |
| 0x08 | 0x1F2 | Device name, 249 `WCHAR`s, from the connection manager |

### OPPManager

`OPPManager::OPPManager` (0x100053B0, `/GS`) builds the object, increments `g_lcModuleRef` and calls `WSAStartup(0x202)` (an error is only logged). The destructor calls `WSACleanup`.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `IBthOPPManager` |
| 0x04 | 4 | vtable `IBtConnectionResponderCallback` |
| 0x08 | 4 | vtable `IBtCommandCallback` |
| 0x0C | 8 | `SynchronizedObject` (vtable, `Synchronizer *`) |
| 0x14 | 4 | Reference count (1 at creation) |
| 0x18 | 4 | `IBthOPPListenerCallback *` |
| 0x1C | 1 | Closed |
| 0x20 | 4 | `IBtConnectionResponder *` of [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) |
| 0x24 | 4 | Responder id of `OBEXObjectPushServiceClass_UUID` |
| 0x28 | 4 | Responder id of `BTCM_OPP_OUTGOING_PSEUDO_UUID` |
| 0x2C | 0x10 | `std::map<unsigned __int64, OPPSession *>`: outgoing sessions by address |
| 0x3C | 0x10 | `std::map<unsigned __int64, OPPSession *>`: incoming sessions by address |
| 0x48 | 4 | ? |

`OPPManager::Dispatch` (0x10005858) events: 0 `RegisterListener`, 1 `DispatchConnect`, 2 `Close`, 3 offers a session to the listener and closes it if refused (no caller found), 4 `DispatchRFCOMMConnected`, 5 `DisconnectConnection`, 6 `DispatchBTCMSetProfileState`, 7 `CommandCompleted`.

### Connection manager

The profile GUIDs:

| Name | GUID | Use |
|------|------|-----|
| `OBEXObjectPushServiceClass_UUID` | `{00001105-0000-1000-8000-00805F9B34FB}` | Incoming connections (OPP server) |
| `BTCM_OPP_OUTGOING_PSEUDO_UUID` | `{99999999-0000-1000-8000-00805F9B34FB}` | Outgoing connections (OPP client) |

The pseudo UUID isn't in any other extracted binary: the service presumably knows it from its profile list in the registry (`Parameters\Services\{GUID}`, see [BtConnectionManagerService.dll](./btconnectionmanagerservice.md)) ?.

`BTCMAttach` (0x10002B24), once (if +0x20 is NULL): `CoCreateInstance` of `CClient` with `IBtConnectionResponder`, then `RegisterCallback(OBEXObjectPushServiceClass_UUID, this+4, &id)` and `RegisterCallback(BTCM_OPP_OUTGOING_PSEUDO_UUID, this+4, &id)` (messages 10 of the pipe). Errors are only logged, the function always returns 0.  
`BTCMDetach` (0x10002BB4): `UnregisterCallback` of the two ids, `Shutdown` (index 7) and `Release` of the responder.

`BTCMSetProfileState(address, state, isServer)` (0x10002E84) queues event 6. `DispatchBTCMSetProfileState` (0x10002ED0) calls `IBtConnectionResponder::SetProfileState(address, isServer ? OBEXObjectPushServiceClass_UUID : BTCM_OPP_OUTGOING_PSEUDO_UUID, state)` (message 12). When the state is 0, it first removes the session of the address from the incoming or the outgoing map and releases it. The states sent: 1 when an RFCOMM connection is accepted (connecting ?), 2 when the OBEX session is connected, 0 when it is disconnected or closed.

### Incoming connection

`AcceptRfcommConnection` copies its parameters into a `CMConnectRequestData` (0x200 bytes): +0x00 address (from `SOCKADDR_BTH`+2), +0x08 socket, +0x0C byte `fIncoming`, +0x0E name (249 `WCHAR`s). `DispatchRFCOMMConnected` (0x10002CE4):
- incoming (`fIncoming` ≠ 0): accepted only if there is a listener and no incoming session for the address. Creates an `OPPSession` (0x238 bytes, server, with the socket), copies the name, adds it to the incoming map and calls `IBthOPPListenerCallback` index 3 with its `IBthOPPSession`. If the listener fails, the session is closed. Without a listener, or with a session already there, the socket is closed (`closesocket`);
- outgoing: the socket is the answer to a `Connect`. The session is looked for in the outgoing map, gets the name, and receives the socket (session event 0). Without a session the socket is closed.

In both cases it reports the profile state: 1 if the socket was taken, 0 otherwise.

### Outgoing connection

`Connect` creates the `OPPSession` (client, socket -1) and returns it at once. `DispatchConnect` (0x10005780):
1. If the outgoing map already has a session for the address, the new session gets the connection result 183 (`ERROR_ALREADY_EXISTS`).
2. Otherwise `BTCMAttach`, adds the session to the outgoing map, and calls `IBtConnectionResponder::ConnectProfileToDevice(address, BTCM_OPP_OUTGOING_PSEUDO_UUID, IBtCommandCallback, context = session)` (message 17).
3. The socket comes back through `AcceptRfcommConnection` with `fIncoming` = 0. A failure comes through `CommandCompleted` (message -17): the session is removed from the map and gets the error code.

### OPPSession

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `IObexSessionCallback` |
| 0x04 | 4 | vtable `IBthOPPSession` |
| 0x08 | 8 | `SynchronizedObject`; the `Synchronizer` is shared with the `OPPManager` |
| 0x10 | 4 | Reference count |
| 0x14 | 4 | `OPPManager *` (referenced) |
| 0x1C | 4 | RFCOMM socket, -1 until connected |
| 0x20 | 8 | Device address |
| 0x28 | 1 | Incoming (OPP server) |
| 0x2C | 4 | `IBthOPPSessionCallback *` |
| 0x30 | 4 | Connection error received before the callback was registered |
| 0x34 | 1 | Closed |
| 0x38 | 4 | `ObexSession *` |
| 0x3C | 4 | `ObexFileObject *` offered by the remote device, waiting for `AcceptReceive` |
| 0x40 | 4 | `IObexObjectCallback *` of the active transfer |
| 0x44 | 0x1F2 | Device name |

The `ObexSession` (0x60 bytes) is created with the socket: in the constructor for an incoming session, in `DispatchSocketConnectComplete` (0x10004A90) for an outgoing one. A connection error is passed to the callback (index 4), or kept at +0x30 until `RegisterStatusUpdate`. `RegisterStatusUpdate` (event 4, ignored after `Close`) starts the reception of the socket (OBEX event 0), and for an outgoing session sends the OBEX `CONNECT` (OBEX event 1).

`OPPSession::Dispatch` (0x100050C4) events:

| Event | From | Action |
|-------|------|--------|
| 0 | Manager | `DispatchSocketConnectComplete(socket, error)` |
| 1 | `Send` | `DispatchSend` |
| 2 | `AcceptReceive` | Stores the handle in the offered object, OBEX event 7 (accept) |
| 3 | `Cancel` | `DispatchCancel` |
| 4 | `RegisterStatusUpdate` | See above |
| 5 | `Disconnect` | OBEX event 2 (`DISCONNECT`) |
| 6 | `Close` | `DispatchClose` |
| 7 | `ObexSessionConnected` | Profile state 2, callback index 3 |
| 8 | `ObexSessionDisconnected` | Profile state 0, callback index 4 with 0 |
| 9 | `PutObjectRequested(name, type, length)` | Keeps the `ObexFileObject` at +0x3C, callback index 7; released without callback |
| 10 | `PutObjectStarted` | Becomes the active object; callback index 8 (incoming) or 5 (outgoing) with name and type |
| 11 | `PutObjectCompleted(object, result)` | Callback index 9 (incoming) or 6 (outgoing), releases the active object |
| 12 | `ObjectTransferProgress(object, done, total)` | Callback index 10 |

`DispatchCancel` (0x10004E8C): an offered object is refused (OBEX event 8: response `Forbidden`); an active transfer is cancelled (OBEX event 5); otherwise the result is 1168 (`ERROR_NOT_FOUND`). Then callback index 11 with the result.  
`DispatchClose` (0x10004FF0): marks the session closed, releases the offered object, shuts the `ObexSession` down (OBEX event 12), completes an active transfer with 351 (`ERROR_FAIL_SHUTDOWN` ?), calls callback index 12 and releases it, reports state 0 if there was a socket, and releases the manager.

### Sending a file

`Send(hFile, path, type)` (0x10004C5C) keeps only the part of the path after the last `\` as the OBEX name, copies the MIME type, and returns 0x80310009 on an incoming session. `DispatchSend` (0x10004D34) wraps the handle in an `ObexFileObject` and queues it on the `ObexSession` (OBEX event 3, request type 0 = put); without an `ObexSession` it calls the callback index 6 with 2250 (`ERROR_NOT_CONNECTED`).

When the request reaches the head of the queue and no other request is active (`DispatchCheckUserRequestQueue`, 0x100069A8), `PutObjectStarted` is called and `DispatchSendFirstPutPacket` (0x10006A1C, `/GS`) builds a `PUT` (0x02, not final) with the headers `Length` (0xC3, 4 bytes, from `ObexObjectGetLength`), `Name` (0x01, UTF-16 big endian with the terminating 0) and `Type` (0x42, ASCII with the terminating 0). Each `Continue` (0x90) answer gets the next packet (`DispatchSendSubsequentPutPacket`, 0x10006B9C): `ObexObjectGetBody` reads up to the packet size minus 6 bytes at the current offset, sent in a `Body` (0x48) header, or in an `End of Body` (0x49) header with the final opcode 0x82 for the last block; `ObjectTransferProgress` follows each packet. A read error sends `Abort` (0xFF) and completes the request with the error. The final response gives the result: `Success` (0xA0) → 0, `Not Implemented` (0xD1) → 120, others → 22 (`ERROR_BAD_COMMAND`).

### Receiving a file

A `PUT` received on a connected server session without active request (`DispatchProcessReceivedPutCommand`, 0x10006F2C, `/GS`) is parsed (`ObexPacketAttributes::Parse`): `Name` (0x01), `Type` (0x42) and `Length` (0xC3) go to `PutObjectRequested`, which creates an `ObexFileObject` without file (handle -1). The packet is kept (+0x44 of the `ObexSession`), and no response is sent until the user answers:
- `AcceptReceive(hFile)`: `DispatchAcceptObject` (0x100068FC) makes the object active, calls `PutObjectStarted`, then processes the body of the kept packet; each later `PUT` packet goes to `DispatchProcessReceivedPutPacketBody` (0x10007170), which writes the `Body` and `End of Body` headers with `ObexObjectSetBody` at the current offset and answers `Continue` (0x90), `Success` (0xA0) after `End of Body`, `Internal Error` (0xD0) if the write fails, `Bad Request` (0xC0) if the headers are malformed;
- `Cancel`: answer `Forbidden` (0xC3).

The size of the file is not checked against the `Length` header. A `PUT` in another state is answered `Not Acceptable` (0xC6).

### ObexFileObject

`ObexFileObject` (0x48 bytes, `IObexObjectCallback`): +0x04 file handle, +0x08 name (`std::wstring`), +0x24 type (`std::string`), +0x40 length, +0x44 reference count. The constructor takes the length from `GetFileSizeEx` when the handle is valid and the size is below 4 GB. Methods (vtable 0x10001340): `ObexObjectGetLength` (`E_FAIL` if the length is 0), `ObexObjectGetName`, `ObexObjectGetType`, `ObexObjectGetBody(buffer, size, offset, *read, *final)` (`SetFilePointer` + `ReadFile`; final when the read is short or reaches the length), `ObexObjectSetBody(buffer, size, offset, final)` (`SetFilePointer` + `WriteFile`). The offsets are 32-bit. The DLL never closes the handles: they belong to the user.

### ObexSession

A small OBEX engine (`ObexSession::Dispatch`, 0x100062A0), client or server depending on the constructor flag. Its own receive size is 0xFFFF bytes; the send size starts at 255 and becomes the maximum packet length of the peer (at least 255) after `CONNECT`.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | `SynchronizedObject` |
| 0x08 | 4 | vtable `IAsyncDataSocketCallback` |
| 0x0C | 4 | Reference count |
| 0x14 | 4 | `IObexSessionCallback *` (the `OPPSession`) |
| 0x18 | 4 | `AsyncDataSocket *` |
| 0x1C | 4 | State: 0 Disconnected, 1 Connecting, 2 Connected, 3 Disconnecting |
| 0x20 | 8 | `std::list<ObexObjectRequest *>`: requests of the user (type 0 put, 1 get; get has no sender) |
| 0x2C | 4 | Active `ObexObjectRequest *` |
| 0x30 | 4 | Length of the active object |
| 0x34 | 4 | Offset in the active object |
| 0x38 | 1 | Server |
| 0x39 | 1 | Client waiting for a response |
| 0x3A | 1 | Server processing a command |
| 0x3C | 4 | Receive buffer |
| 0x40 | 2 | Receive buffer size (0xFFFF) |
| 0x42 | 2 | Bytes received in the buffer |
| 0x44 | 4 | Copy of the first `PUT` packet |
| 0x48 | 2 | Its length |
| 0x4C | 4 | Send buffer (length, data) |
| 0x50 | 4 | Maximum send packet size |
| 0x54 | 4 | Log callback (`ObexDebugLogMessageCallback` → `DebugPrintf`) |
| 0x58 | 4 | Log level (3) |
| 0x5C | 4 | Log zone mask (0xFFFF) |

Events: 0 start receiving, 1 send `CONNECT`, 2 request `DISCONNECT`, 3 queue a put, 4 queue a get, 5 cancel, 7 accept, 8 reject, 9 data received, 10 send completed, 11 socket disconnected, 12 shutdown.

Commands sent: `CONNECT` 0x80 (version 0x10, flags 0, maximum packet length 0xFFFF), `DISCONNECT` 0x81, `PUT` 0x02 / 0x82, `ABORT` 0xFF. Commands answered by the server (`DispatchProcessReceivedCommand`, 0x10006D44):

| Opcode | Answer |
|--------|--------|
| `CONNECT` (0x80) | `Success` with the same 7-byte format if disconnected and the packet has at least 7 bytes, else `Bad Request` (0xC0), or `Not Acceptable` (0xC6) in another state |
| `DISCONNECT` (0x81) | `Success` if connected, else `Not Acceptable` |
| `PUT` (0x02 / 0x82) | See [Receiving](#receiving-a-file) |
| `SETPATH` (0x85) | `Success`, without action |
| `ABORT` (0xFF) | Completes the active transfer with 995 (`ERROR_OPERATION_ABORTED`), `Success` |
| `GET` and others | `Not Implemented` (0xD1) |

A packet is processed when the 16-bit length of its header has been received; a packet bigger than the buffer is dropped.

### AsyncDataSocket

`AsyncDataSocket` (0xCC bytes) owns the RFCOMM socket. Sends are queued and done one at a time with `WSASend`, receives with `WSARecv`; each operation has its own `WSACreateEvent` event, waited with `RegisterWaitForSingleObject(…, INFINITE, WT_EXECUTEONLYONCE)`, and the completion (`WSAGetOverlappedResult`, `UnregisterWaitEx`) is queued as an event. +0x80 holds 5000, the receive buffer size ?. An error other than `ERROR_OPERATION_ABORTED` closes the socket (`closesocket`) and calls `IAsyncDataSocketCallback::Disconnected`.

### Threading

As in the connection manager, the objects derive from `SynchronizedObject`; `Synchronizer::EnqueueEvent` (0x10007E2C) runs an event at once if the queue is idle, otherwise the thread draining the queue runs it, so the handlers of one object never run concurrently. The COM methods and the socket completions only queue events.

### Callbacks

The user implements two interfaces whose IIDs aren't in the DLL. Their method names are unknown; the meaning comes from the calls.

| Interface | Index | Called for |
|-----------|-------|------------|
| `IBthOPPListenerCallback` | 3 | New incoming session: `(IBthOPPSession *)`; a negative result closes it |
| `IBthOPPSessionCallback` | 3 | OBEX session connected |
| | 4 | Disconnected, or connection failed: `(error)` |
| | 5 | Sending started: `(name, type)` |
| | 6 | Sending completed: `(result)` |
| | 7 | Object offered by the remote device: `(name, length, type)`; answer with `AcceptReceive` or `Cancel` |
| | 8 | Receiving started: `(name, type)` |
| | 9 | Receiving completed: `(result)` |
| | 10 | Progress: `(bytes done, total)` |
| | 11 | `Cancel` done: `(result)` |
| | 12 | Session closed |

### Registry

| Key | Values |
|-----|--------|
| `HKLM\SOFTWARE\Classes\CLSID\{B0DB6E5C-4726-4c27-BD69-FA322FCDD835}` | Written by `DllRegisterServer`, deleted by `DllUnregisterServer` |

The DLL reads no registry value.

### ETW

Provider `Microsoft-WindowsPhone-Bluetooth-OPP` `{F780A2D1-75F6-4154-839D-404A04F49892}` (`BLUETOOTH_OPP_PROVIDER_GUID`), registered in `DllMain`.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 1000 (`_ETWMESSAGE`) | 0 | 0, 10 | 0x100 | 0x1 | Each `DebugPrintf` (0x10003A6C): the formatted text, as a string |

`DebugPrintfInternal` (0x10003974) can also prepend `GetTickCount` and write to `OutputDebugStringA`, but `g_DebugPrependTickCount` and `g_DebugConsoleOutput` are never set. All the log strings of the OBEX layer go through the same path.

`__FatalError` (0x10008620) writes `NET_FATAL_ERROR` with the provider `Microsoft-WindowsPhone-Net-Debug` `{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}`, as in the connection manager, then terminates the process.
