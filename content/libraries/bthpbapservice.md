## Bthpbapservice.dll

The Bluetooth Phone Book Access Profile server of Windows Phone 8.1: the `BluetoothPBAPSvc` service, hosted by `svchost.exe`, which lets a car kit or a hands-free device read the contacts and the call history over OBEX (PBAP PSE role).  
`Bthpbapservice.dll` is a C++ DLL (122 880 bytes, 369 functions, the database has its full symbols). It registers with the Bluetooth connection manager as the responder of the `Phonebook Access PSE` class, and receives the RFCOMM socket of each client. It runs a small OBEX server on these sockets (one thread for all the connections), turns on the Bluetooth authentication and encryption of the link, asks the user to allow the device (a Shell action dialog) and remembers the answer in the registry per device. It then answers the PBAP requests `PullPhoneBook`, `SetPhoneBook`, `PullvCardListing` and `PullvCardEntry` on a virtual folder tree (`telecom/pb`, `ich`, `och`, `mch`, `cch`, `SIM1/telecom/pb`). The contacts come from POOM (`IPOutlookApp3`, `PIMSTORE`), the call history from the User Data Model (`UserDataModelClient`), and the vCards are made by `CommsVCardParser` (`IVCardGen`) or by a built-in stub.  
It uses [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) (COM class `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`), which talks to [BtConnectionManagerService.dll](./btconnectionmanagerservice.md). The authorisation dialog is created by [ShellChromeAPI.dll](./shellchromeapi.md#action-dialogs). The `PbapTrustLevel` value it writes is also read by [BTAGService.dll](./btagservice.md) for the HFP phonebook commands.

Location on the phone: `C:\Windows\System32\Bthpbapservice.dll` ? (the extracted file has no notes; the export directory gives `BthPbapService.dll`).  
Service name: `BluetoothPBAPSvc`, svchost group `WPTCBNoNetwork`.  
Source folder: `src\net\bluetooth\product\services\servicelib\` (strings); PDB `bthpbapservice.pdb`.  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance`, `StringFromGUID2` |
| OLEAUT32 | `SysAllocString`, `SysAllocStringLen`, `SysFreeString` |
| WS2_32 | `WSAStartup`, `WSACleanup`, `WSAGetLastError`, `WSASend`, `WSARecv`, `WSAGetOverlappedResult`, `WSASetServiceW`, `socket`, `setsockopt`, `getsockname`, `ntohs`, `closesocket` |
| MSWSOCK | `AcceptEx` |
| ShellChromeAPI | `Shl::ActionDialog::Create` (`ACTION_DIALOG_PARTIAL_SCREEN_CONFIG`) |
| CommsVCardParser | `CreateVCardGen` |
| UserDataModelClient | `UdmCreateDataSession`, `UdmCreateSyncCallbackHandler` |
| phoneom | `PhoneAPIInitialize`, `PhoneAPIUninitialize`, `PhoneGetLines`, `PhoneGetDefaultOutgoingLine`, `PhoneGetProviderLineInfo` |
| PIMSTORE | `FindMatchingContactEx`, `FindAllMatchingAggregates` |
| PHONEINFO | `QueryPhoneInformation` |
| ntdll | `NtQueryWnfStateData`, `WinSqmStartSession`, `WinSqmEndSession`, `WinSqmIncrementDWORD`, `WinSqmAddToStreamEx` |
| bcrypt | `BCryptOpenAlgorithmProvider`, `BCryptCloseAlgorithmProvider`, `BCryptGetProperty`, `BCryptCreateHash`, `BCryptHashData`, `BCryptFinishHash`, `BCryptDestroyHash` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegDeleteValueW`, `RegDeleteKeyExW`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0, api-ms-win-core-kernel32-legacy-l1-1-1 | `LoadLibraryExW`, `LoadLibraryW`, `GetProcAddress`, `FreeLibrary`, `LoadStringW`, `GetModuleFileNameW`, `GetModuleFileNameA`, `GetModuleHandleExW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `WaitForSingleObjectEx`, `WaitForMultipleObjectsEx`, `Sleep`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `WaitOnAddress`, `WakeByAddressAll` |
| api-ms-win-core-processthreads-l1-1-2, api-ms-win-core-handle-l1-1-0 | `CreateThread`, `GetCurrentProcess`, `TerminateProcess`, `DuplicateHandle`, `CloseHandle` |
| api-ms-win-core-threadpool-legacy-l1-1-0 | `QueueUserWorkItem`, `UnregisterWaitEx` |
| api-ms-win-core-string-l1-1-0 | `MultiByteToWideChar`, `WideCharToMultiByte` |
| api-ms-win-core-file-l1-2-1, api-ms-win-core-timezone-l1-1-0 | `FileTimeToLocalFileTime`, `FileTimeToSystemTime` |
| api-ms-win-core-sysinfo-l1-2-2 | `GetTickCount64` |
| api-ms-win-service-* | `OpenSCManagerW`, `OpenServiceW`, `CreateServiceW`, `DeleteService`, `CloseServiceHandle`, `ChangeServiceConfig2W`, `ControlService`, `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-core-console-l1-1-0 | `SetConsoleCtrlHandler` |
| api-ms-win-core-processenvironment-l1-2-0 | `ExpandEnvironmentStringsW` |
| api-ms-win-core-localization-l1-2-1 | `FormatMessageA` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-heap-l1-2-0, api-ms-win-core-heap-obsolete-l1-1-0 | `GetProcessHeap`, `HeapAlloc`, `HeapFree`, `LocalAlloc`, `LocalFree` |
| api-ms-win-core-errorhandling-l1-1-2, -debug-l1-1-1, -rtlsupport-l1-2-0 | `GetLastError`, `SetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `IsDebuggerPresent`, `DebugBreak`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | C and C++ runtime (`malloc`, `free`, `operator new`/`delete`, `_CxxThrowException`, `__CxxFrameHandler3`, `_initterm`, `_vsnwprintf`, `_wcsicmp`, `wcsstr`, `strcpy_s`, …) |

The msvcrt, rtlsupport, and part of the debug, errorhandling and processthreads imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. The service manager, console, bcrypt and `WinSqm*` imports, and most of the registry ones, come from the `CService` / `RegHelper` / `BtSqm*` code shared with [BtConnectionManagerService.dll](./btconnectionmanagerservice.md) and [BTAGService.dll](./btagservice.md). `socket`, `getsockname`, `WSASetServiceW` and `AcceptEx` are only in `CBluetoothChannel::WaitForConnection` (0x10015B90) and `WaitForConnectionAsync`, a listening mode of the OBEX library that the service never calls: the sockets come from the connection manager.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md) | `CoCreateInstance` `{101C5B9F-C6F7-41C4-815B-69AAC1ECA0A9}`, IID `IBtConnectionResponder` `{4D1AC687-509C-48F7-A7BB-FE2B83A9C7DC}`, `CLSCTX_ALL` ([Connection manager](#connection-manager)) | Incoming RFCOMM connections of the PBAP PSE class, profile state |
| `btuxres.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)`, `LoadStringW` ([Authorisation dialog](#authorisation-dialog)) | Strings 0x7F, 0x8B, 0x8C, 0x8D, 0x8E of the dialog |
| `BthCommonRes.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)`, `LoadStringW` (`GetCortanaName`, 0x1000EC84) | String 101 (if `WNF_RW_CA_ENABLED` is non-zero) or 102: name of the Cortana entry of the phonebook, as in [BTAGService.dll](./btagservice.md#cortana) |
| `ContactsUtil.dll` | `LoadLibraryW`, `GetProcAddress("GetContactsHygiene")`, `FreeLibrary` (`ContactProvider::InitHygieneMask`, in `GetContacts`) | Mask of the contact sources to export ([Contacts](#contacts)) |
| POOM `Application` `{05058F23-20BE-11D2-8F18-0000F87A4335}` | `CoCreateInstance`, IID `IPOutlookApp3` `{A65CCAEB-6558-4656-AD3D-ECCC00D00F0D}` (`VirtualFolderMgr::Init`), also `IPOutlookApp` in the vCard encoder, `CLSCTX_INPROC_SERVER` | Contacts (`IAggregate`, `IContact`); server DLL not known |
| `IVCardGen` of `CommsVCardParser` | `CreateVCardGen` (static import, `VCardGenWrapper::PrepareEncoder`) | vCard 2.1 / 3.0 encoding; the built-in stub is used when it returns `REGDB_E_CLASSNOTREG` |
| Call history of the User Data Model | `UdmCreateDataSession`, `IUdmCallHistorySession` (`CallHistoryProvider::PopulateList`) | Folders `ich`, `och`, `mch`, `cch`; unseen missed calls |
| RFCOMM sockets | Received from the connection manager, `WSASend` / `WSARecv` overlapped, `setsockopt`, `closesocket` ([OBEX server](#obex-server)) | OBEX packets |

No process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `SvchostPushServiceGlobals` | 0x10011CBC | `_SVCHOST_GLOBAL_DATA *` |
| 2 | `ServiceMain` | 0x10013158 | `DWORD argc, LPWSTR *argv` |

The two exports are the `CService` code of [BtConnectionManagerService.dll](./btconnectionmanagerservice.md#exports): `SvchostPushServiceGlobals` links the global `BluetoothPBAPSvc` object in `CService::s_pFirstService`, with the group `WPTCBNoNetwork` (a second registration of the same name is a `__FatalError`). The value 0x87654321 in the first DWORD of the structure means a command line (`ParseArgs`: register, unregister, run as console program). `RegisterOneService` (0x10013418) writes `@<dll>,-101` and `@<dll>,-102`, and the command line `svchost.exe -k WPTCBNoNetwork`.

### Global object

`g_PBAPService` (at 0x100180A8) is built by a dynamic initialiser (0x10007288), destroyed by `atexit`. It derives from `CService`.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `PbapService` |
| 0x04 | 4 | `L"BluetoothPBAPSvc"` |
| 0x08, 0x0C | 4, 4 | 101, 102 (resource ids of the name and the description) |
| 0x28 | 4 | Next `CService` |
| 0x54 | 4 | Index mask of the service |
| 0x58 | 4 | `CObexServerSession *` ([OBEX server](#obex-server)) |
| 0x5C | 4 | List of the `pbapClientSession` (below) |
| 0x60 | 0x18 | Critical section of the list |
| 0x7C | 4 | Handle of the OBEX thread `s_PbapThread` |
| 0x80 | 4 | Stop event |
| 0x84 | 4 | `IBtConnectionResponder *` |
| 0x88 | 4 | Id of the responder registration |

`pbapClientSession` (0x218 bytes, reference counted):

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 4 | `Session *`, created on OBEX `CONNECT` ([Sessions](#sessions)) |
| 0x004 | 4 | `UNAUTHORIZED` already sent (a second one hangs up) |
| 0x008 | 4 | OBEX connection id (from `CObexServerSession::AddClientConnection`) |
| 0x010 | 8 | Bluetooth address |
| 0x018 | 0x1F2 | Device name, 249 `WCHAR`s, from the connection manager |
| 0x20C | 4 | Next session |
| 0x210 | 4 | Reference count |
| 0x214 | 1 | OBEX connected |

### Startup

`_DllMainCRTStartup` (0x10016888): CRT. `DllMain` (0x10011CA0) only calls `DisableThreadLibraryCalls`.

`CService::ServiceMain` calls `PbapService::OnStart` (0x1001090C):
1. `McGenEventRegister` of the PBAP [ETW](#etw) provider, `CreateEventW` (stop event, +0x80).
2. Creates the `CObexServerSession` (0x3C bytes: connection list, critical section, a second event, the stop event at +0x38, 8080 at +0x34: buffer size ?) and registers the OBEX server ETW provider.
3. `BTCMDetach`, then `CoCreateInstance` of the connection manager client, and `IBtConnectionResponder::RegisterCallback(PhonebookAccessPseServiceClass_UUID, ConnectionResponder, &id)` (vtable index 3).
4. `CreateThread(s_PbapThread)` and `SERVICE_RUNNING`. Any failure sets `SERVICE_STOPPED`.

`PbapService::OnStop` (0x10010AAC): `SERVICE_STOP_PENDING`, sets the stop event and waits 100 ms for the thread, reports the state 0 of each session to the connection manager and releases it, destroys the OBEX server and its connections, ends the SQM session (writing the pending pairing streams), `BTCMDetach`, `SERVICE_STOPPED`.

### Connection manager

| Name | GUID |
|------|------|
| `PhonebookAccessPseServiceClass_UUID` | `{0000112F-0000-1000-8000-00805F9B34FB}` |

The responder callback is a small `ConnectionResponder` object (0xC bytes: vtable, reference count, `PbapService *`) which answers `QueryInterface` for `IUnknown` and `IBtConnectionResponderCallback` `{EB794A01-E173-4D1E-9CD4-2037CDB529E3}`:
- `AcceptRfcommConnection(SOCKET, const SOCKADDR_BTH *, const WCHAR *name, BYTE fIncoming)` (0x10011E34) copies the socket, the address and the name (249 `WCHAR`s) into a 0x218-byte block and queues `HandleConnectNotificationStatic` (`QueueUserWorkItem`); it always returns 0. The work item increments SQM datapoint 2455 and calls `ClientConnection`;
- `DisconnectConnection(unsigned __int64 address)` (0x10011EFC) queues `HandleDisconnectNotificationStatic`, which finds the session of the address, `DisconnectClientConnection` and `CleanupSession`;
- `GetConnectionName` (0x10011EEC) does nothing.

`ClientConnection(socket, SOCKADDR_BTH, name)` (0x10010D2C):
1. Allocates the `pbapClientSession` (SQM datapoint 2457 if it fails).
2. If the device's `PbapTrustLevel` is 3 (denied for this session), resets it to 0 (`ClearOneTimeSessionAuthorizationDenial`): the next connection will prompt again.
3. `CObexServerSession::AddClientConnection(socket)` (wraps the socket in a `CBluetoothChannel` and gives a connection id), fills the session and adds it at the head of the list.

`BTCMSetProfileState(address, state)` (0x10011F98) calls `IBtConnectionResponder::SetProfileState(address, PhonebookAccessPseServiceClass_UUID, state)` (vtable index 5): 2 when the PBAP session is created, 0 when it is cleaned up. `BTCMDetach` (0x10011F54) calls `UnregisterCallback(id)` (index 4), `Shutdown` (index 7) and `Release`.

### OBEX server

The OBEX layer (`CObexServerSession`, `CBluetoothChannel`, `ObexParser`) is a generic server library; its messages go through `OBEXEtwMessage`.

- `CBluetoothChannel` (constructor 0x100154AC: `WSAStartup`) owns one RFCOMM socket. `TurnEncryptionOn` (0x10015518, vtable index 0) is `setsockopt(SOL_RFCOMM, SO_BTH_ENCRYPT, TRUE)`, `TurnAuthenticationOn` (0x1001556C, index 1) `setsockopt(SOL_RFCOMM, SO_BTH_AUTHENTICATE, TRUE)`. Packets are sent with `WSASend` and received with `WSARecv` from a per-socket thread (`SockOperationThreadProc`), with an event set when data arrive.
- `CObexServerSession::GetNextOperation(&connId, &command)` (0x100151BC) waits (`WaitForMultipleObjectsEx`) on the receive events of all the connections and on the stop event, accumulates the data until a whole packet (16-bit length of the OBEX header) is there, and parses it (`_ParseOBEXPacket`, 0x10014D28) into an `_obex_command`: opcode, final bit, header ids, values (string, byte sequence, byte, DWORD). A broken packet answers `Bad Request`; an error on a connection disconnects it and returns its id; the stop event returns `E_ABORT` (0x80004004).
- `SendResponse(connId, code, command)` (0x100149CC) builds and sends the response packet; `SendTrivialResponse` sends a response without headers; the response codes `OBEX_RESP_HANGUP` / `DISCONNECT` remove the connection.

`s_PbapThread` (0x10010C8C) loops on `GetNextOperation` and calls `HandleRequest` for each packet; on error it calls `CleanupSession` for the returned connection id, and it ends on `E_ABORT`.

### HandleRequest (0x10010F08)

1. Finds the `pbapClientSession` of the connection id (`E_FAIL` if none) and takes a reference.
2. If the session already has a `Session`, the packet goes to `Session::CreateResponse` ([Requests](#requests)).
3. Otherwise only `CONNECT` and `DISCONNECT` are accepted. `CONNECT`: [CreateConnectResponse](#obex-connect), then [CreateNewSession](#authorisation); `DISCONNECT`: hang-up response `Success`. Anything else: "Session has not been created and we received something other than Connect or Disconnect".
4. An error becomes a response through `CreateResponseForError` (0x100112D0), below.
5. `CObexServerSession::SendResponse`. If the response is a hang-up (type 9) or something failed, the connection is closed (`DisconnectClientConnection`) and the session cleaned up (`CleanupSession`, 0x10010E98: state 0 to the connection manager, `Release`).

The internal error codes are 0x88890000 plus the OBEX response code without the final bit. `CreateResponseForError` turns `E_OUTOFMEMORY` into `SERVICE_UNAVAILABLE`, any unknown code into `FORBIDDEN`, and a second `UNAUTHORIZED` on the same session into a hang-up (`FORBIDDEN`, then the socket is closed).

| Code | OBEX response |
|------|---------------|
| 0x88890040 | `BAD_REQUEST` (0xC0) |
| 0x88890041 | `UNAUTHORIZED` (0xC1) |
| 0x88890043 | `FORBIDDEN` (0xC3) |
| 0x88890044 | `NOT_FOUND` (0xC4) |
| 0x88890046 | `NOT_ACCEPTABLE` (0xC6) |
| 0x8889004C | `PRECONDITION_FAILED` (0xCC) |
| 0x88890051 | `NOT_IMPLEMENTED` (0xD1) |
| 0x88890053 | `SERVICE_UNAVAILABLE` (0xD3) |

### OBEX CONNECT

`ObexRequest::ParseConnectPacket` (0x10007A30) keeps the `Target` header (0x46), the maximum packet length of the client, and from an `Authenticate Challenge` header (0x4D) the 16-byte nonce (tag 0) and the options (tag 1).

`CreateConnectResponse` (0x1001143C, `/GS`):
- without challenge: `CreateAcceptConnectionResponse` with the target;
- with a challenge: reads `ObexAuthPassword` (`REG_SZ`, up to 100 characters) under `HKLM\Software\Microsoft\Bluetooth\PBAP`, default `0000` ("Could not read ObexAuthPassword from registry, will use default password"), converts it to ANSI, and computes the response digest `MD5(nonce ":" password)` (own `MD5Update` / `MD5Final`).

`ObexResponse::CreateAcceptConnectionResponse` (0x100083F0): `Success` (0xA0), OBEX version 0x10, flags 0, maximum packet length 0x400; headers `Authenticate Response` (0x4E: tag 0 digest of 16 bytes, tag 1 user id `uid`, 4 bytes, when there was a challenge), `Who` (0x4A, the target received) and `Connection Id` (0xCB).

### Authorisation

`CreateNewSession(connId, session, request, remote info)` (0x10011130):
1. `TurnAuthenticationOn`, then `TurnEncryptionOn` on the socket. If one fails and `IsEncryptionRequired` (`HKLM\Software\Microsoft\Bluetooth\PBAP`, default 1) is non-zero, the connection is refused (`FORBIDDEN`).
2. `IsAuthorized(remote info)` (below): 1 (approved) creates the session; 4 (denied repeatedly) creates a session too, but with the "denied" flag, so all the folders are empty ([Sessions](#sessions)); anything else answers `FORBIDDEN`.
3. Creates the `Session` (0xAC bytes) with the maximum packet length of the client, and reports the profile state 2.

The trust levels of the device (`TrustLevel`, names from the log strings), in `PbapTrustLevel` of `HKLM\System\CurrentControlSet\Services\BTConnMgr\Parameters\Devices\%04x%08x\PBAP` (the address as NAP, then SAP):

| Value | Name | Meaning |
|-------|------|---------|
| 0 | `UNKNOWN` | Ask the user (default, also for values ≥ 5) |
| 1 | `APPROVED` | Always allowed |
| 2 | `DENIED` | Always refused |
| 3 | `DENIED_FOR_SESSION` | Refused until the next RFCOMM connection (reset to 0 by `ClientConnection`) |
| 4 | `DENIED_REPEATEDLY` | Returned by `IsAuthorized` only, not stored |

`IsAuthorized` (0x10008A10, `/GS`):
1. Reads `PbapTrustLevel` and `PbapAllowPhotos` (into `g_AllowPhotos`) for the device.
2. Level 0: reads `PBAPAuthAction` in `HKLM\System\CurrentControlSet\Services\Bluetoothpbapsvc` (default 2). 1 approves without asking; 2 shows the [dialog](#authorisation-dialog): `CreateEventW`, `DuplicateHandle`, `CreateThread(s_HandlePBAPAuthRequestThread)` with a copy of the remote info (0x1F8 bytes and the event), `WaitForSingleObject` of 62 s, then reads the two values again; any other value refuses (level 2).
3. Level 2: the refusal is counted in `g_RetryInfo` (address, `GetTickCount64`, count). Another device resets the count; for the same device the count increases when the previous refusal is less than 20 s old, and restarts at 1 otherwise. After more than 2 quick refusals the result is 4 (`DENIED_REPEATEDLY`).
4. Other levels are returned as they are.

### Authorisation dialog

`s_HandlePBAPAuthRequestThread` (0x10008D2C, `/GS`) loads `btuxres.dll` as a data file and its strings 0x8B (title), 0x8C (text, a format string filled with the device name three times), 0x8D and 0x7F (the two buttons) and 0x8E (check box text). The check box starts with the current `PbapAllowPhotos`. It calls `Shl::ActionDialog::Create(2, ACTION_DIALOG_PARTIAL_SCREEN_CONFIG, &dialog)` with the sound `SystemExclamation` and a timeout of 60 000 ms, then the dialog method at vtable +0x0C to get the result:

| Result | Offset in the result | `PbapTrustLevel` written |
|--------|----------------------|--------------------------|
| Closed with reason 1, 2 or 3 (timeout, cancel… ?) | +0x00 | 3 (`DENIED_FOR_SESSION`), `PbapAllowPhotos` unchanged |
| Other non-zero reason | +0x00 | 0 |
| First button (0x8D: allow ?) | +0x04 = 0 | 1 (`APPROVED`) |
| Second button (0x7F: deny ?) | +0x04 ≠ 0 | 2 (`DENIED`) |

After a button, the check box state (+0x08 of the result) is written to `PbapAllowPhotos`. Then the dialog methods +0x18 and +0x08 (`Release`) are called, the library is freed and the event is set. The partial screen configuration fields used (offsets in the local structure, as in [ShellChromeAPI.dll](./shellchromeapi.md#action-dialogs)): +0x00 title, +0x10 text, +0x20 check box text, +0x30 check state, +0x34 vector of two button strings, +0x60 sound name, +0x90 timeout.

### Sessions

`Session` (constructor 0x10009818) holds the state of one PBAP client:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | OBEX connection id |
| 0x04 | 4 | Denied repeatedly: snapshots stay empty |
| 0x08 | 0x1C | Name of the folder of the current snapshot (`std::wstring`) |
| 0x24 | 8 | Filter of the snapshot |
| 0x2C | 4 | Order of the snapshot |
| 0x34 | 0x1C | Search value of the snapshot (`std::wstring`) |
| 0x50 | 0x38 | `Packetizer`: +0x50 maximum body per packet = packet length − 15, with the packet length clamped to 50…12000 |
| 0x70 | 4 | Transfer in progress (a `GET` without request headers continues it) |
| 0x88 | 0x14 | `VirtualFolderMgr`: +0x88 current folder, +0x8C vector of `VirtualFolder *`, +0x98 `VCardGenWrapper *` |
| 0x9C | 4 | `VirtualFolder *` of the current snapshot |
| 0xA0 | 4 | `Fetcher *` of the current transfer (`PullPbFetcher`, `PullListingFetcher`) |

`VirtualFolderMgr::Init` (0x10010470) creates the POOM application (`CoCreateInstance`, then `Logon`) and the folders:

| Folder | Class | Content |
|--------|-------|---------|
| `telecom/pb.vcf` | `ContactProvider`, store 0 | Owner card, Cortana entry, POOM contacts |
| `telecom/ich.vcf` | `CallHistoryProvider`, mask 1 | Received calls (UDM call types 1 and 3) |
| `telecom/och.vcf` | `CallHistoryProvider`, mask 2 | Dialled calls (type 0) |
| `telecom/mch.vcf` | `CallHistoryProviderForMissedCall`, mask 4 | Missed calls (type 2), with the `NewMissedCalls` parameter |
| `telecom/cch.vcf` | `CallHistoryProvider`, mask −1 | All the calls |
| `SIM1/telecom/pb.vcf` | `ContactProvider`, store 1 | Only the owner card: no SIM contact is read |

The current folder of `SetPhoneBook` is a number: 0 root, 1 `telecom`, 2 `pb`, 3 `ich`, 4 `och`, 5 `mch`, 6 `cch`, 7 `SIM1`, 8 `SIM1/telecom`, 9 `SIM1/telecom/pb`. `GetFullVcfName` (0x1000AB80) turns the current folder and the name of a listing request into the name of the virtual folder.

`TakeVirtualFolderSnapshot` (0x1000999C) reuses the current snapshot if the folder, filter, order and search value are the same; otherwise it finds the folder by name (`NOT_FOUND`) and calls its `TakeSnapshot(denied, filter, order, search attribute, search value)`.

### Requests

`ObexRequest::Parse` (0x10007958) needs the final bit (otherwise the packet is treated as the continuation of a transfer). The commands (`PbapCmd`):

| Cmd | OBEX | Condition | Handler |
|-----|------|-----------|---------|
| 1 `CmdConnect` | `CONNECT` | | [CONNECT](#obex-connect) |
| 2 `CmdDisconnect` | `DISCONNECT` | | `FlushStates`, hang-up `Success` |
| 3 `CmdAbort` | `ABORT` | | `FlushStates`, `Success` |
| 4 `CmdPullPhoneBook` | `GET` | `Type` `x-bt/phonebook` | `CreatePullPhoneBookResponse` (0x1000A268) |
| 5 `CmdSetPhoneBook` | `SETPATH` | | `CreateSetPhoneBookResponse` (0x1000A4F8) |
| 6 `CmdPullVCardListing` | `GET` | `Type` `x-bt/vcard-listing` | `CreatePullVCardListingResponse` (0x1000A668) |
| 7 `CmdPullVCardEntry` | `GET` | `Type` `x-bt/vcard` | `CreatePullVCardEntryResponse` (0x1000A888) |

Other types answer `NOT_IMPLEMENTED`, `PUT` and other opcodes `BAD_REQUEST`. `ParsePbapPacket` (0x10007B48) reads the headers `Name` (0x01, up to 260 characters, required except for a listing), `Type` (0x42), `Application Parameters` (0x4C) and `Connection Id` (0xCB, only logged when different). Only one session may be active: a request with another connection id answers `SERVICE_UNAVAILABLE`.

`SETPATH` flags: bits 0 and 1 → up one level; bit 1 only, with a name → down into that folder (`telecom`, `SIM1` from the root, then `pb`, `ich`, `och`, `mch`, `cch`), without a name → back to the root. An unknown folder answers `NOT_FOUND`, other flags `NOT_ACCEPTABLE`.

Application parameters read by `ParseAppParams` (0x1000777C; a length beyond the header answers `BAD_REQUEST`, a bad value is ignored):

| Tag | Name | Size | Values |
|-----|------|------|--------|
| 1 | Order | 1 | < 3 (listing) |
| 2 | SearchValue | n | UTF-8, up to 259 characters (listing) |
| 3 | SearchAttribute | 1 | < 3 (listing) |
| 4 | MaxListCount | 2 | Big endian; 0 = size query; default 0xFFFF |
| 5 | ListStartOffset | 2 | Big endian; default 0 |
| 6 | Filter | 8 | vCard property mask |
| 7 | Format | 1 | 0 vCard 2.1, 1 vCard 3.0 |

Responses:
- `PullPhoneBook` takes a snapshot of the folder named in the request, adds the folder parameter (`NewMissedCalls` for `mch`), and with MaxListCount 0 only `PhonebookSize` (tag 8, 2 bytes, limited to `PhoneBookSizeHardLimit`); otherwise sets the start offset (`ListStartOffset` greater than the count answers an error) and sends the vCards with a `PullPbFetcher`;
- `PullvCardListing` does the same on the folder given by `GetFullVcfName` (`NOT_FOUND` if the current folder isn't a leaf and no name was given), with order, search attribute and search value; the body is the XML listing between `<?xml version="1.0"?>` / `<!DOCTYPE vcard-listing SYSTEM "vcard-listing.dtd">` / `<vCard-listing version="1.0">` and `</vCard-listing>`, one `<card handle="N.vcf" name="…"/>` per entry (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;` escaped), converted to UTF-8;
- `PullvCardEntry` parses the number of `N.vcf` and returns that vCard (`NOT_FOUND` if out of range).

The body is cut by the `Packetizer` (0x10008694); each following `GET` gets the next packet (`MultiPacketResponse::AddVcards`), `Continue` until the last one.

### Contacts

`ContactProvider::TakeSnapshot` (0x1000D52C, `/GS`) prepares the vCard encoder, then (unless the session is denied) builds the list of `ContactEntry` (16 bytes each):
- store 1 (`SIM1`): only the owner entry, filtered by the search value;
- store 0: the owner entry (handle 0), the Cortana entry if `AddCortanaPhonebookEntry` (default 1, `HKLM\SYSTEM\CurrentControlSet\Services\BTAGService\Parameters\Settings`) is set, with the number `CortanaPhoneNumber` (default `5555559876`) and the name from `BthCommonRes.dll`, then the POOM aggregates (count from the POOM folder, `FindAllMatchingAggregates` for a search), sorted by display name (`AggregateComparator`, `[DisplayName]`), kept only if they follow the hygiene mask (`FollowsHygieneMask`: the source bits of the aggregate AND the mask from `ContactsUtil!GetContactsHygiene`) and match the search (`ShouldInclude`, `ShouldIncludeAggregate`). Recently deleted items are skipped.

`GetVCardAt` (0x1000DF1C): the owner card uses `GetOwnerInfo` (0x1000CD98: own number and name from `PhoneAPIInitialize`, `PhoneGetDefaultOutgoingLine`, `PhoneGetProviderLineInfo`, and `QueryPhoneInformation` for the phone name; `Voice Mail` label); the Cortana entry its name and number; a contact the merged `IContact` of the aggregate (`MergeContactAggregate`: properties and picture of the linked contacts).

### Call history

`CallHistoryProvider::PopulateList` (0x1000B6A0) opens a UDM data session and its call history session (once), enumerates the items, and keeps those whose call type matches the folder mask (see the table in [Sessions](#sessions)), up to `PhoneBookSizeHardLimit`. Each item keeps the number, the name of the matching contact (`FindMatchingContactEx`, IID `IContact`) and the timestamp `X-IRMC-CALL-DATETIME;<DIALED|RECEIVED|MISSED>:yyyymmddThhmmss` (local time). A call without number and with a presentation other than `AVAILABLE` is a private number: its vCard has the name `*****`. The listing uses the contact's `FileAs`, or the number.

`CallHistoryProviderForMissedCall::_UpdateNewMissedCalls` (0x1000BE20) adds the unseen call counts of every phone line (`PhoneGetLines`, the line GUID as string, `GetUnseenCallCount` of the call history session), capped to 255. `GetFolderSpecificAppParam` returns the application parameter tag 9 (`NewMissedCalls`), 1 byte.

### vCards

`VCardGenWrapper::PrepareEncoder` (0x1000F444) creates `IVCardGen` (`CreateVCardGen`) unless `UseVCardGenStub` is non-zero or an earlier call returned `REGDB_E_CLASSNOTREG`, which switches to the stub for good. `GetFilter` (0x100103E4) uses the filter of the request (or of the snapshot); an all-zero filter means all properties; the photo bit (bit 3) is removed when `g_AllowPhotos` is 0.

`EncodeVCardUsingStub` (0x1000F960) writes `BEGIN:VCARD`, `VERSION:`, the name, `TEL;CELL;VOICE:`, `TEL;HOME;VOICE:`, `TEL;WORK;VOICE:`, `TEL:`, `ORG:`, `EMAIL;TYPE=internet:`, `X-IRMC-CALL-DATETIME;…` and `END:VCARD`; `VCardGenStubVC3Flavor` changes the 3.0 output (the exact differences aren't analysed). Phone numbers are made dialable first (`getDialableNumber`, `ensureIConDialableNumbers`: characters ` -()+./pw,*#`).

### Registry

| Key | Values |
|-----|--------|
| `HKLM\Software\Microsoft\Bluetooth\PBAP` | `IsEncryptionRequired` (default 1), `PhoneBookSizeHardLimit` (default 0xFFFF), `ObexAuthPassword` (`REG_SZ`, default `0000`), `UseVCardGenStub` (0), `VCardGenStubVC3Flavor`; DWORDs read by `ReadReg` (0x10007334), values > 0xFFFF ignored |
| `HKLM\System\CurrentControlSet\Services\BTConnMgr\Parameters\Devices\%04x%08x\PBAP` | `PbapTrustLevel`, `PbapAllowPhotos` (read and written, `PBAPRegGetDeviceDWORDValue` 0x100088CC / `PBAPRegSetDeviceDWORDValue` 0x10008968) |
| `HKLM\System\CurrentControlSet\Services\Bluetoothpbapsvc` | `PBAPAuthAction` (default 2: ask) |
| `HKLM\SYSTEM\CurrentControlSet\Services\BTAGService\Parameters\Settings` | `AddCortanaPhonebookEntry` (1), `CortanaPhoneNumber` (`5555559876`) |
| `HKLM\System\CurrentControlSet\Services\BtConnMgr\Parameters\Sqm` | `EnableSQM` |
| `HKLM\System\CurrentControlSet\Services\BTHPORT\Parameters\Devices` | `LEAddressType`, `DeviceNames` (SQM code) |
| `SYSTEM\CurrentControlSet\Services\%s\Parameters`, `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Svchost` | `ServiceDll`, `ServiceDllUnloadOnStop`, group: written by `RegisterOneService` |

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| `WNF_RW_CA_ENABLED` 0x41C6193FA3B95C75 (`.text:0x100035A4`) | `RW`, 171 | 4 bytes | Queried (`NtQueryWnfStateData`) by `GetCortanaName`: chooses the string 101 or 102 |

### ETW

Providers `Microsoft_WindowsPhone_Bluetooth_PBAP` `{2FF93DC3-EEA4-4DDA-BDC5-8539E1490D32}` (`BLUETOOTH_PBAP_PROVIDER_GUID`, registered in `OnStart`) and `Microsoft_WindowsPhone_Bluetooth_OBEXServer` `{CBD1C3E5-E1F5-4999-B122-676776F99D95}` (`BLUETOOTH_OBEXSERVER_PROVIDER_GUID`, registered with the `CObexServerSession`).

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 1000 (`_ETWMESSAGE`) | 0 | 0, 10 | 0x100 | 0x1 of the PBAP provider | `PBAPEtwMessage` (0x10011918): `"<function> <text>"` through `FormatMessageA` |
| 1000 (`_ETWMESSAGE`) | 0 | 0, 10 | 0x100 | 0x1 of the OBEX server provider | `OBEXEtwMessage` (0x10015D74) |

Both functions write through `EtwTraceMessage` (0x10011AF0), which always uses the PBAP provider handle: the OBEX server provider only gates the OBEX messages.

`__FatalError` (0x10012BDC) writes `NET_FATAL_ERROR` with the provider `Microsoft-WindowsPhone-Net-Debug` `{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}`, as in the connection manager. SQM datapoints: 2455 (PBAP connection), 2457 (session allocation failed).
