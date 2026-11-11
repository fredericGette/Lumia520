## WSHBTH.DLL

The Winsock helper and namespace provider of Bluetooth on Windows Phone 8.1: it gives Winsock the address family `AF_BTH` (32) with its two protocols (L2CAP and RFCOMM) and the namespace `NS_BTH` (16) used by `WSALookupService*` and `WSASetService`.  
`WSHBTH.DLL` is a small C DLL (152 functions, the database has its full symbols, PDB `wshbth.pdb`). It has two halves:
- the **WSH helper** (`WSH*` exports) called by the Winsock kernel-mode transport (AFD) layer: it maps `socket(AF_BTH, …)` to the device `\Device\BthTdi` (L2CAP) or `\Device\BTHMS_RFCOMM` (RFCOMM), converts the `SOCKADDR_BTH` addresses to and from strings, and turns the Bluetooth socket options (`SOL_RFCOMM`) and `WSAIoctl` codes (`SIO_BTH_*`, `SIO_RFCOMM_*`) into IOCTLs sent to these devices;
- the **namespace provider** (`NSPStartup` and the `NSP*` routines): device inquiry and the list of known devices, SDP queries to a remote device, and publishing / deleting local SDP records. The device list and the local SDP records go through the RPC interface of [BTHSERV.DLL](./bthserv.md#rpc) (`BthServEp`); the SDP queries are sent directly to the radio (`BthPort`, `IOCTL_BTH_SDP_*`).

It is loaded by `ws2_32.dll` / `mswsock.dll` (not analysed) in every process that uses Bluetooth sockets or the Bluetooth namespace, e.g. [bthelpersvc.dll](./bthelpersvc.md) (`WSALookupService*`, `WSASetServiceW`), [Bthpbapservice.dll](./bthpbapservice.md) (`WSASetServiceW`, `setsockopt(SOL_RFCOMM, …)`), [BtConnectionManagerService.dll](./btconnectionmanagerservice.md) (sockets).

Location on the phone: `C:\Windows\System32\wshbth.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4 | `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW`, `RpcBindingFree`, `RpcStringFreeW`, `NdrClientCall2` |
| ntdll | `NtDeviceIoControlFile`, `RtlGetLastNtStatus`, `RtlInitUnicodeString`, `RtlCompareMemory`, `EtwRegisterTraceGuidsW`, `EtwUnregisterTraceGuids`, `EtwTraceMessage`, `EtwGetTraceLoggerHandle`, `EtwGetTraceEnableLevel`, `EtwGetTraceEnableFlags`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| DEVOBJ (delay-load) | `DevObjCreateDeviceInfoList`, `DevObjGetClassDevs`, `DevObjEnumDeviceInterfaces`, `DevObjGetDeviceInterfaceDetail`, `DevObjDestroyDeviceInfoList` |
| api-ms-win-security-lsalookup-l1-1-1 (delay-load) | `LookupAccountSidLocalW` |
| api-ms-win-security-base-l1-2-0 | `AllocateAndInitializeSid`, `FreeSid` |
| api-ms-win-core-io-l1-1-1, api-ms-win-core-file-l1-2-1, api-ms-win-core-handle-l1-1-0 | `DeviceIoControl`, `CreateFileW`, `CloseHandle` |
| api-ms-win-core-synch-l1-2-0 | `InitializeCriticalSectionAndSpinCount`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`, `CreateEventW`, `WaitForMultipleObjectsEx`, `Sleep` |
| api-ms-win-core-heap-l1-2-0, api-ms-win-core-heap-obsolete-l1-1-0 | `GetProcessHeap`, `HeapAlloc`, `HeapFree`, `LocalAlloc`, `LocalFree` |
| api-ms-win-core-string-l1-1-0 | `MultiByteToWideChar`, `WideCharToMultiByte` |
| api-ms-win-core-libraryloader-l1-2-0 | `DisableThreadLibraryCalls` |
| api-ms-win-core-errorhandling-l1-1-2, api-ms-win-core-processthreads-l1-1-2 | `GetLastError`, `SetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `TerminateProcess`, `GetCurrentProcess` |
| api-ms-win-core-delayload-l1-1-1 | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| msvcrt | `malloc`, `free`, `memcpy`, `memmove`, `memset`, `memcmp`, `strlen`, `wcslen`, `_wcsicmp`, `_vsnwprintf`, `_initterm`, `_amsg_exit`, `_XcptFilter`, `__C_specific_handler` |

The msvcrt startup functions, the `Rtl*` unwind functions, `TerminateProcess`, `GetCurrentProcess` and the exception filters are the CRT startup and `/GS` code. The `Etw*` imports are the WPP tracing ([ETW](#etw)). The DLL also contains its own copy of the SDP parsing library (`SdpTreeFromStream`, `SdpStreamFromTreeEx`, `SdpCreateNode*`, `SdpFindAttributeInTree`, `SdpValidateStream`, … in the `PAGE` segment, 0x10008000), allocating with `LocalAlloc`.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\Device\BthTdi` | Name given to AFD by `WSHOpenSocket2` (AFD opens it) | Transport of the L2CAP sockets ([Sockets](#sockets)) |
| `\Device\BTHMS_RFCOMM` | Same | Transport of the RFCOMM sockets |
| Radio of the Bluetooth stack (`BthPort`, interface `GUID_BTHPORT_DEVICE_INTERFACE` `{0850302A-B344-4FDA-9BE9-90576B8D46F0}`) | `DevObjGetClassDevs` / `DevObjEnumDeviceInterfaces` (first interface) / `DevObjGetDeviceInterfaceDetail`, `CreateFileW(GENERIC_READ \| GENERIC_WRITE, no sharing, OPEN_EXISTING)` (`BthFindInterface` 0x10004190, `OpenInterface` 0x10004098), `DeviceIoControl` | Local radio information and SDP queries ([NSPLookupServiceBegin](#nsplookupservicebegin)) |
| [BTHSERV.DLL](./bthserv.md) (service `BthServ`) | RPC `ncalrpc:[BthServEp]` | Device list, local SDP records ([RPC](#rpc)) |

No DLL is loaded at run time (other than the delay-load imports), and no process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `NSPStartup` | 0x100049D4 | `LPGUID lpProviderId`, `LPNSP_ROUTINE lpnspRoutines` |
| 2 | `WSHAddressToString` | 0x10002E50 | `LPSOCKADDR Address`, `INT AddressLength`, `LPWSAPROTOCOL_INFOW ProtocolInfo`, `LPWSTR AddressString`, `LPDWORD AddressStringLength` |
| 3 | `WSHEnumProtocols` | 0x10002120 | `LPINT lpiProtocols`, `LPWSTR lpTransportKeyName`, `LPVOID lpProtocolBuffer`, `LPDWORD lpdwBufferLength` |
| 4 | `WSHGetBroadcastSockaddr` | 0x100025E0 | `PVOID HelperDllSocketContext`, `PSOCKADDR Sockaddr`, `PINT SockaddrLength` |
| 5 | `WSHGetProviderGuid` | 0x1000249C | `LPWSTR ProviderName`, `LPGUID ProviderGuid` |
| 6 | `WSHGetSockaddrType` | 0x100022E8 | `PSOCKADDR Sockaddr`, `DWORD SockaddrLength`, `PSOCKADDR_INFO SockaddrInfo` |
| 7 | `WSHGetSocketInformation` | 0x10002AC0 | `PVOID HelperDllSocketContext`, `SOCKET SocketHandle`, `HANDLE TdiAddressObjectHandle`, `HANDLE TdiConnectionObjectHandle`, `INT Level`, `INT OptionName`, `PCHAR OptionValue`, `PINT OptionLength` |
| 8 | `WSHGetWSAProtocolInfo` | 0x100023E0 | `LPWSTR ProviderName`, `LPWSAPROTOCOL_INFOW *ProtocolInfo`, `LPDWORD ProtocolInfoEntries` |
| 9 | `WSHGetWildcardSockaddr` | 0x10002558 | `PVOID HelperDllSocketContext`, `PSOCKADDR Sockaddr`, `PINT SockaddrLength` |
| 10 | `WSHGetWinsockMapping` | 0x10002668 | `PWINSOCK_MAPPING Mapping`, `DWORD MappingLength` |
| 11 | `WSHIoctl` | 0x10002760 | `PVOID HelperDllSocketContext`, `SOCKET SocketHandle`, `HANDLE TdiAddressObjectHandle`, `HANDLE TdiConnectionObjectHandle`, `DWORD IoControlCode`, `LPVOID InputBuffer`, `DWORD InputBufferLength`, `LPVOID OutputBuffer`, `DWORD OutputBufferLength`, `LPDWORD NumberOfBytesReturned`, `LPWSAOVERLAPPED Overlapped`, `LPWSAOVERLAPPED_COMPLETION_ROUTINE CompletionRoutine`, `LPBOOL NeedsCompletion` |
| 12 | `WSHJoinLeaf` | 0x10003150 | (not supported: returns `WSAEINVAL`, 10022) |
| 13 | `WSHNotify` | 0x1000319C | `PVOID HelperDllSocketContext`, `SOCKET SocketHandle`, `HANDLE TdiAddressObjectHandle`, `HANDLE TdiConnectionObjectHandle`, `DWORD NotifyEvent` |
| 14 | `WSHOpenSocket` | 0x10003308 | `PINT AddressFamily`, `PINT SocketType`, `PINT Protocol`, `PUNICODE_STRING TransportDeviceName`, `PVOID *HelperDllSocketContext`, `PDWORD NotificationEvents`: calls `WSHOpenSocket2` with group 0 and flags 0 |
| 15 | `WSHOpenSocket2` | 0x10003358 | `PINT AddressFamily`, `PINT SocketType`, `PINT Protocol`, `GROUP Group`, `DWORD Flags`, `PUNICODE_STRING TransportDeviceName`, `PVOID *HelperDllSocketContext`, `PDWORD NotificationEvents` |
| 16 | `WSHSetSocketInformation` | 0x10002C84 | Same as `WSHGetSocketInformation`, `INT OptionLength` by value |
| 17 | `WSHStringToAddress` | 0x10002F98 | `LPWSTR AddressString`, `DWORD AddressFamily`, `LPWSAPROTOCOL_INFOW ProtocolInfo`, `LPSOCKADDR Address`, `LPDWORD AddressStringLength` |

The `WSH*` functions return a Winsock error code (0 on success); the parameters are those of the standard `wsahelp.h` prototypes, confirmed by the way they are used.

Global state: `g_BthCs` (critical section, created in `DllMain`), `g_NspContextList` (open [lookups](#lookup-context)) and `g_SdpContextList` ([published SDP records](#published-record-context)), both `LIST_ENTRY` heads protected by `g_BthCs`.

### Startup

`_DllMainCRTStartup` (0x10006D94): CRT. `DllMain` (0x10001F68), on `DLL_PROCESS_ATTACH`: registers the WPP tracing ([ETW](#etw)), `DisableThreadLibraryCalls`, initialises the two lists and `InitializeCriticalSectionAndSpinCount(&g_BthCs, 0x80000000)` (failure → `DllMain` returns FALSE). On detach: `DeleteCriticalSection` and `EtwUnregisterTraceGuids`.

### Sockets

**Protocols.** Two `WSAPROTOCOL_INFOW` entries are returned by `WSHGetWSAProtocolInfo` for the provider names `BthTdi` and `RFCOMM` (`_wcsicmp`; another name gives `WSAEINVAL`), and two provider GUIDs by `WSHGetProviderGuid`:

| Provider name | Provider GUID | `szProtocol` | `dwServiceFlags1` | `iProtocol` | Device |
|---------------|---------------|--------------|-------------------|-------------|--------|
| `BthTdi` | `{42A6920F-E18B-4CD9-AC3C-ED490446EECB}` | `MSAFD L2CAP [Bluetooth]` | 0x20006 (guaranteed delivery and order, IFS handles) | 0x100 (`BTHPROTO_L2CAP`) | `\Device\BthTdi` |
| `RFCOMM` | `{9FC48064-7298-43E4-B7BD-181F2089792A}` | `MSAFD RfComm [Bluetooth]` | 0x20026 (+ graceful close) | 3 (`BTHPROTO_RFCOMM`) | `\Device\BTHMS_RFCOMM` |

Both: `dwProviderFlags` 8 (`PFL_MATCHES_PROTOCOL_ZERO`), protocol chain length 1, `iVersion` 2, `iAddressFamily` 32 (`AF_BTH`), `iMaxSockAddr` = `iMinSockAddr` = 30 (`sizeof(SOCKADDR_BTH)`), `iSocketType` 1 (`SOCK_STREAM`), big-endian, no security scheme, stream (`dwMessageSize` 0).  
`WSHGetWinsockMapping` returns 2 rows × 3 columns per protocol (needs 56 bytes): (32, `SOCK_STREAM`, 0x100), (32, 0, 0x100) and (32, `SOCK_STREAM`, 3), (32, 0, 3). `WSHEnumProtocols` (the old `PROTOCOL_INFO` interface) returns only RFCOMM, and only when 3 is in the protocol list: 92 bytes, `dwServiceFlags` 6, address family 32, sockaddr 30 / 30, `SOCK_STREAM`, protocol 3, name `RFCOMM`.

**WSHOpenSocket2** (0x10003358): compares (family, type, protocol) with the mapping rows of L2CAP, then of RFCOMM (unknown triple → `WSAEINVAL`), rewrites them with the first row (so protocol 0 becomes 0x100 or 3), gives the device name (`RtlInitUnicodeString`), and allocates the 32-byte socket context (`LocalAlloc`, `WSAENOBUFS` 10055 on failure). The notifications asked are 0x8F (`WSH_NOTIFY_BIND`, `LISTEN`, `CONNECT`, `ACCEPT`, `CLOSE`).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Address family (32) |
| 0x04 | 4 | Socket type |
| 0x08 | 4 | Protocol (0x100 or 3) |
| 0x0C | 4 | `Flags` of `WSHOpenSocket2` (bit 0 = `WSA_FLAG_OVERLAPPED`) |
| 0x10 | 8 | List of the cached options to apply on the address object (state 1, "bound") |
| 0x18 | 8 | List of the cached options for the connection object (state 2, "connected") |

`WSHNotify` (0x1000319C): on `WSH_NOTIFY_BIND` (1) it sends every option of the list at +0x10 to the address object handle (`WshBthDeviceIoControl` with the IOCTL and the value saved by `WshCacheOption`); `LISTEN` (2), `CONNECT` (4) and `ACCEPT` (8) only trace; `CLOSE` (0x80) frees the two lists and the context (`DeleteSocketRecords`, 0x10003B40).

**Addresses.** `SOCKADDR_BTH` (30 bytes): `WORD addressFamily` (32), `BTH_ADDR btAddr` (8 bytes, at +2), `GUID serviceClassId` (+0x0A), `ULONG port` (+0x1A).
- `WSHGetSockaddrType`: family must be 32 (`WSAEAFNOSUPPORT` 10047) and the length ≥ 30 (`WSAEFAULT` 10014); the address is "wildcard" when `btAddr` is 0, the port is "wildcard" when `port` is 0.
- `WSHGetWildcardSockaddr` returns a zeroed `SOCKADDR_BTH` with family 32; `WSHGetBroadcastSockaddr` fills the same and returns `WSAEINVAL` (no broadcast).
- `WSHAddressToString`: `L"(%02X:%02X:%02X:%02X:%02X:%02X)"`, most significant byte first, followed by `L":%u"` and the port when it isn't 0 (`StringCbPrintfW`, 0x10001C9C); the returned length is in bytes.
- `WSHStringToAddress` (family must be 32): up to 6 groups of hexadecimal digits, an optional `(` at the start, separated by `:` or `.`, closed by `)`; fewer than 6 groups → `WSAEINVAL`. The port isn't parsed.

**Socket options** (`WshOptionValidate`, 0x10002958, checks level / name, socket protocol, value pointer and minimum length; an unknown option gives `WSAENOPROTOOPT` 10042). Level 3 is `SOL_RFCOMM`; only an RFCOMM socket accepts level 3 options and only an L2CAP socket would accept level 0x100 (no option of this level exists). The "state" column says on which handle the IOCTL is sent: 1 = address object (before the connection), 2 = connection object.

| Level | Option | Get / set | Min. size | IOCTL (`\Device\…`) | State |
|-------|--------|-----------|-----------|---------------------|-------|
| 3 | 0x80000007 `SO_BTH_MTU` | get | 4 | 0x12006C | 2 |
| 3 | 0x80000007 `SO_BTH_MTU` | set | 4 | 0x120070 | 1 |
| 3 | 0x80000008 `SO_BTH_MTU_MAX` | set | 4 | 0x120074 | 1 |
| 3 | 0x8000000A `SO_BTH_MTU_MIN` | set | 4 | 0x120078 | 1 |
| 3 | 0x80000001 `SO_BTH_AUTHENTICATE` | set | 4 | 0x120030 | 1 |
| 3 | 2 `SO_BTH_ENCRYPT` | set | 4 | 0x120034 | 1 |
| 0xFFFE (`SOL_INTERNAL`) | 1 (`SO_CONTEXT`) | get / set | 32 | — | Copies the 32-byte socket context (`LocalAlloc` of a copy when AFD sets it on a new socket) |

The three MTU values must be between 23 and 1011 (0x17…0x3F3), otherwise `WSAEINVAL`. A "state 1" option set before the socket has an address object (the handle is NULL) is saved by `WshCacheOption` (0x10003BE8: one `LocalAlloc` entry per option, a previous value of the same option is replaced) and sent at `WSH_NOTIFY_BIND`. Setting a "state 2" option or getting `SO_BTH_MTU` without a connection object gives `WSAEINVAL`.

**WSHIoctl** (0x10002760): the code is looked up in a table of 7 entries (protocol of the socket, code, device IOCTL, min. input, min. output, state); a completion routine needs an overlapped socket and an `OVERLAPPED`. Unknown code, too small buffers or missing handle → `WSAEINVAL`; NULL context / socket / pointers → `WSAEFAULT`.

| Protocol | `WSAIoctl` code | Name (`ws2bth.h`) | IOCTL | Min. in / out | State |
|----------|-----------------|-------------------|-------|---------------|-------|
| 0x100 (L2CAP) | 0xD8000008 | `SIO_BTH_PING` | 0x120028 | 0x35 / 0x2D | 2 |
| 0 | 0xD8000009 | `SIO_BTH_INFO` | 0x12002C | 0x0A / 0x2F | 2 (never matches: the protocol of a socket is never 0) |
| 3 (RFCOMM) | 0xD8000065 | `SIO_RFCOMM_SEND_COMMAND` | 0x1201B8 | 0x0B / 0x0B | 2 |
| 3 | 0xD8000066 | `SIO_RFCOMM_WAIT_COMMAND` | 0x1201BC | 0 / 0x0B | 2 |
| 3 | 0xD8000069 | `SIO_RFCOMM_USECFC` | 0x1201A0 | 1 / 0 | 1 |
| 3 | 0xD8000067 | `SIO_RFCOMM_SESSION_FLOW_OFF` | 0x120198 | 1 / 0 | 2 |
| 3 | 0xD8000068 | `SIO_RFCOMM_TEST` | 0x12019C | 1 / 1 | 2 |

All the device IOCTLs are `FILE_DEVICE_NETWORK` (0x12), `METHOD_BUFFERED`, `FILE_ANY_ACCESS` (functions 10, 11, 12, 13, 27…30, 102…104, 110, 111); their names and the drivers behind `\Device\BthTdi` / `\Device\BTHMS_RFCOMM` (presumably `BthTdi` and `RFCOMM` in the stack, not analysed) aren't known.

`WshBthDeviceIoControl` (0x10003824): with a completion routine, `NtDeviceIoControlFile` with the APC `IoctlCompletionRoutine` (0x100026FC, converts the `NTSTATUS` and calls the Winsock routine); otherwise `DeviceIoControl`, and on an overlapped socket without `OVERLAPPED` it creates an event and waits up to 60 s (`WSA_OPERATION_ABORTED` 995 on timeout). The `NTSTATUS` is converted by `NtStatusToSocketError` (0x100034F0). A NULL or `INVALID_HANDLE_VALUE` handle gives 10108.

### NSPStartup

`NSPStartup` (0x100049D4) copies the `NSP_ROUTINE` table (`NspTable`): `cbSize` 0x2C, version 1.1, `NSPCleanup` (only traces), `NSPLookupServiceBegin`, `NSPLookupServiceNext`, `NSPLookupServiceEnd`, `NSPSetService`, `NSPInstallServiceClass`, `NSPRemoveServiceClass`, `NSPGetServiceClassInfo` (the last three: `WSAEOPNOTSUPP` 10045), and `NSPIoctl` = NULL when the caller's structure has room for it (48 bytes; 44 bytes are copied otherwise, less → `WSAEINVALIDPROCTABLE` 10104).

### NSPLookupServiceBegin

`NSPLookupServiceBegin(lpProviderId, lpqsRestrictions, lpServiceClassInfo, dwControlFlags, lphLookup)` (0x10004B18, `/GS`):
1. `dwNameSpace` must be `NS_BTH` (16), else `WSASERVICE_NOT_FOUND` (10108); `dwSize` ≥ 0x3C, else `WSAEFAULT`.
2. Opens the radio (`BthFindInterface`) and reads `IOCTL_BTH_GET_LOCAL_INFO` (0x410000, 0x124 bytes `BTH_LOCAL_RADIO_INFO`); the local address is at +8.
3. **Device inquiry** (`LUP_CONTAINERS`, 2): `lpServiceClassId` must be NULL (`WSAEINVAL`). The optional `lpBlob` (≥ 5 bytes, `BTH_QUERY_DEVICE`) gives the inquiry length at +4 (default 6, at most 60). `BthDeviceInquiry(flush, length × 100 / 128 + 1, …)` ([RPC](#rpc)) asks [BTHSERV](./bthserv.md#device-list) for its device list, with a new inquiry when `LUP_FLUSHCACHE` (0x1000) is set. The context type is 100.
4. **SDP query** (otherwise): `lpszContext` must hold the remote address (`WSHStringToAddress`, else `WSAEINVAL`). The query is the `lpBlob` (≥ 0x100 bytes, `BTH_QUERY_SERVICE`, checked by `NspValidateQueryService` 0x10004844: type 1…3; for types 1 and 3 up to 12 UUIDs of type 0x130 / 0x220 / 0x430 (UUID16 / 32 / 128) and at least one; for types 2 and 3 at least one attribute range, ascending and not overlapping). Without blob it builds a type 3 query (service search + attributes) with one UUID from `lpServiceClassId` — UUID16 or UUID32 if the GUID is on the Bluetooth base UUID `xxxxxxxx-0000-1000-8000-00805F9B34FB`, else UUID128 — and the range 0…0xFFFF.
5. If the remote address is the local radio, the SDP handle is `HANDLE_SDP_LOCAL` (−2); otherwise `IOCTL_BTH_SDP_CONNECT` (0x410200, 21 bytes: address, `fSdpConnect` = 1 (cached connection) unless `LUP_FLUSHCACHE`, handle out).
6. The query, by type: 1 `IOCTL_BTH_SDP_SERVICE_SEARCH` (0x410208, output 0x3FFC bytes: record handles), 2 `IOCTL_BTH_SDP_ATTRIBUTE_SEARCH` (0x41020C, with the record handle at +4 of the blob), 3 `IOCTL_BTH_SDP_SERVICE_ATTRIBUTE_SEARCH` (0x410210). For 2 and 3 a first call with a 9-byte output gives `requiredSize`, then the full response is read. A `DeviceIoControl` error 68 gives `WSAEMSGSIZE` (10040), other errors → `WSASERVICE_NOT_FOUND`.
7. Allocates the [lookup context](#lookup-context), adds it to `g_NspContextList` and returns it as `*lphLookup`. Then `IOCTL_BTH_SDP_DISCONNECT` (0x410204) if a connection was opened and `CloseHandle` of the radio: all the data are read in this call.

Errors: `SetLastError(code)` and −1.

### Lookup context

Allocated by `NSPLookupServiceBegin` (0x150 bytes + the data):

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 8 | `LIST_ENTRY` in `g_NspContextList` |
| 0x008 | 4 | Allocated size |
| 0x00C | 4 | 0x2050534E (`NSP `), checked by `NSPLookupServiceNext` (`ERROR_INVALID_HANDLE`, 6, if wrong) |
| 0x010 | 8 | Remote address (SDP query) |
| 0x018 | 0x124 | Local radio information (`BTH_LOCAL_RADIO_INFO`; local address at +0x020) |
| 0x13C | 4 | Type: 100 = device list, 1 / 2 / 3 = SDP query type |
| 0x140 | 4 | Type 100: index of the next device; type 1: pointer to the record handles; type 3: offset of the next record |
| 0x144 | 4 | Type 100: device count; type 1: number of handles; types 2, 3: pointer to the SDP response (after the 8-byte `requiredSize` / `responseSize` header) |
| 0x148 | 4 | Type 100: device list (`BLUETOOTH_DEVICE_INFO[]`, 560 bytes each); types 2, 3: response size; type 1: "already returned" byte |
| 0x14C | 4 | Type 2: "already returned" byte |
| 0x150 | n | Data (device list or SDP response) |

`NSPLookupServiceEnd` (0x10005DB8) removes it from the list and frees it (`ERROR_INVALID_HANDLE` if it isn't in the list).

### NSPLookupServiceNext

`NSPLookupServiceNext(hLookup, dwControlFlags, lpdwBufferLength, lpqsResults)` (0x10005AEC): the buffer must hold at least 0x3C bytes (`WSAEFAULT`); it is zeroed, `dwSize` = 0x3C, `dwNameSpace` = 16. End of the results: `WSA_E_NO_MORE` (10110); nothing at all: `WSANO_DATA` (11004). `LUP_FLUSHPREVIOUS` (0x2000) skips one result. A result that doesn't fit gives `WSAEFAULT` with the size needed and stays the current one.

| Type | Result (one per call) |
|------|-----------------------|
| 100 | `NSPQuerySetFromDevInfo` (0x10005440), needs 936 bytes, from one `BLUETOOTH_DEVICE_INFO` |
| 1 | `NSPQuerySetFromPvoid` (0x10005604): `lpBlob` = the array of record handles (4 bytes each), once |
| 2 | `NSPQuerySetFromSdpRecord` (0x1000587C) on the whole response, once |
| 3 | The next record of the response (`SdpGetNextElement` on the outer sequence) through `NSPQuerySetFromSdpRecord` |

`NSPQuerySetFromDevInfo`:
- `dwOutputFlags`: `BTHNS_RESULT_DEVICE_CONNECTED` (0x10000), `…_REMEMBERED` (0x20000), `…_AUTHENTICATED` (0x40000) from the `fConnected`, `fRemembered`, `fAuthenticated` fields.
- `LUP_RETURN_NAME` (0x10): `lpszServiceInstanceName` = the device name (248 `WCHAR`s).
- `LUP_RETURN_TYPE` (0x20): `lpServiceClassId` points to a GUID whose first DWORD is the class of device.
- `LUP_RETURN_ADDR` (0x100): one `CSADDR_INFO`, `RemoteAddr` = `SOCKADDR_BTH` of the device; with `LUP_RES_SERVICE` (0x8000) also `LocalAddr` = the local radio. `iSocketType` 1, protocol 0.
- `LUP_RETURN_BLOB` (0x200): a `BTH_DEVICE_INFO` (272 bytes): flags 7 (address, class, name) | 0x20 if connected | 0x08 if authenticated (paired) | 0x10 if remembered, address, class, UTF-8 name (`WideCharToMultiByte(CP_UTF8)`).

`NSPQuerySetFromSdpRecord` (1160 bytes + the record if `LUP_RETURN_BLOB`): parses the record (`SdpTreeFromStream`, failure → `WSASERVICE_NOT_FOUND`); `LUP_RETURN_NAME`: attribute 0x100 (service name, UTF-8 string → `WCHAR`); `LUP_RETURN_COMMENT` (0x80): attribute 0x101 (description); `LUP_RETURN_ADDR`: `CSADDR_INFO` with the remote address and, as protocol and port, the first L2CAP PSM or RFCOMM channel of the protocol descriptor list (`SdpProtocolFromTree` 0x100056C4: attribute 4, L2CAP UUID → protocol 0x100 and the UINT16, RFCOMM UUID → protocol 3 and the UINT8; RFCOMM wins since it comes later in the list); `LUP_RETURN_TYPE`: `lpServiceClassId` points to a zeroed GUID (not filled); `LUP_RETURN_BLOB`: the raw record.

### NSPSetService

`NSPSetService(lpProviderId, lpServiceClassInfo, lpqsRegInfo, essOperation, dwControlFlags)` (0x10005E88):
1. `SERVICE_MULTIPLE` (1) and `dwSize` < 0x3C are refused (`WSAEINVAL`).
2. With a blob of at least 0x25 bytes, it is a `BTH_SET_SERVICE` (same layout as in [bthelpersvc.dll](./bthelpersvc.md#published-records): `pSdpVersion`, `pRecordHandle`, `fCodService`, reserved, `ulRecordLength`, record at +0x24), checked by `NspValidateSetService` (0x10006110: both pointers non-NULL, `*pSdpVersion` non-zero). For a registration the record is parsed to find its protocol and port (`SdpProtocolFromTree`). `*pSdpVersion` is set to 1.
3. Without blob, `NspSetServiceFromQuerySet` (0x10006274) builds the record from the `WSAQUERYSETW`: `lpServiceClassId` is required, the first `CSADDR_INFO` must have a protocol and a non-zero port in its `LocalAddr`, and `lpszServiceInstanceName`, if given, must not be empty. Attributes: 4 (protocol descriptor list: `{{UUID16 0x0100, UINT16 PSM}}` for L2CAP, `{{UUID16 0x0100}, {UUID16 0x0003, UINT8 channel}}` for RFCOMM), 1 (service class ID list: one UUID128), 0x100 (service name, UTF-8), 0x101 (`lpszComment`, UTF-8). The stream is validated (`SdpValidateStream`) and put in a temporary `BTH_SET_SERVICE` (freed at the end).
4. By `essOperation`:
   - `RNRSERVICE_REGISTER` (0): `*pRecordHandle` must be 0; `SdpPublishRecord` ([below](#published-record-context)).
   - `RNRSERVICE_DEREGISTER` (1): `WSAEINVAL`.
   - `RNRSERVICE_DELETE` (2): the record is found by `*pRecordHandle` (`NspFindSdpContextByHandle`, 0x10006788) or, if the handle is 0, by protocol and port (`NspFindSdpContextByPort`, 0x100066D4), removed from the list and `SdpRemoveRecord`; not found → `WSAEINVAL`.

### Published record context

`SdpPublishRecord(BTH_SET_SERVICE *, protocol, port)` (0x1000445C): opens a [BthServ](#rpc) context (`OpenBthServ`), calls `BthServSetSdpRecordWithInfo` (opnum 12) with the header DWORDs 0, 0, `fCodService`, the length and the record, and writes the returned handle to `*pRecordHandle`. On success it keeps the context open in a 32-byte entry of `g_SdpContextList`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | `LIST_ENTRY` |
| 0x08 | 4 | Record handle |
| 0x0C | 4 | Protocol (0x100 / 3) |
| 0x10 | 4 | Port (PSM / channel) |
| 0x14 | 4 | String binding (`RpcStringBindingComposeW`) |
| 0x18 | 4 | Binding handle |
| 0x1C | 4 | BthServ context handle |

`SdpRemoveRecord` (0x100045EC) calls `BthServRemoveSdpRecord` (opnum 13) with the handle, then `CloseBthServ`. Since [BTHSERV](./bthserv.md#rpc) removes the records of a client when its context is closed or run down, a record published through Winsock lives as long as the process that published it (or until it is deleted).

### RPC

`OpenBthServ(&binding, &context)` (0x10003DB4, `/GS`):
1. `RpcStringBindingComposeW(NULL, L"ncalrpc", NULL, L"BthServEp", NULL)`, `RpcBindingFromStringBindingW`.
2. The server principal is the account of the SID S-1-5-19 (`AllocateAndInitializeSid(SECURITY_NT_AUTHORITY, 1, SECURITY_LOCAL_SERVICE_RID)`, `LookupAccountSidLocalW`): `LOCAL SERVICE`.
3. `RpcBindingSetAuthInfoExW(binding, name, RPC_C_AUTHN_LEVEL_PKT_PRIVACY (6), RPC_C_AUTHN_WINNT (10), NULL, 0, QoS {version 1, RPC_C_QOS_CAPABILITIES_MUTUAL_AUTH, RPC_C_QOS_IDENTITY_DYNAMIC, RPC_C_IMP_LEVEL_IMPERSONATE})` (BthServ requires the privacy level).
4. `BthServOpen` (opnum 0) with the client id of the thread (TEB +0x20 / +0x24: process id, thread id). On failure everything is freed and it returns FALSE; there is no retry.

`CloseBthServ` (0x1000401C): `BthServClose` (opnum 1), `RpcBindingFree`, `RpcStringFreeW`. Each operation opens its own binding and context.

Interface `{2ACB9D68-B434-4B3E-B966-E06B4B3A84CB}` version 1.0 (`BthServRPCService`).

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `OpenBthServ` | `BthDeviceInquiry`, `SdpPublishRecord` | `[out] context`, `[out] long *status`, `[in]` struct (process id, thread id) by value | Opens the BthServ context |
| 1 | `CloseBthServ` | `BthDeviceInquiry`, `SdpRemoveRecord` | `[in, out] context`, `[out] long *status` | Closes it |
| 7 | `BthDeviceInquiry` (0x1000425C) | `NSPLookupServiceBegin` | `context`, `[out] status`, `[in] long` inquiry (1 if `LUP_FLUSHCACHE`), `[in] byte` length, `[in] long` size, `[out, size_is] BLUETOOTH_DEVICE_INFO[]`, `[out] long *` size | `BthServGetDeviceList`. The first call is made with size 0; on `HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER)` (0x8007007A) the buffer (0x150 + size bytes: the lookup context and the list) is allocated and the call repeated without a new inquiry. Fewer than 560 bytes → `WSASERVICE_NOT_FOUND` |
| 12 | `SdpPublishRecord` | `NSPSetService` | `context`, `[out] status`, `[in] long` 0, `[in] long` 0, `[in] long fCodService`, `[in] long` size, `[in, size_is] byte[]` record, `[out] hyper *` handle | `BthServSetSdpRecordWithInfo` |
| 13 | `SdpRemoveRecord` | `NSPSetService` | `context`, `[out] status`, `[in] hyper` handle | `BthServRemoveSdpRecord` |

`MIDL_user_allocate` / `MIDL_user_free` use the process heap.

### IOCTLs

To the radio (`BthPort`), names from the public `bthioctl.h` and [BTHSERV.DLL](./bthserv.md#ioctls):

| IOCTL | Name | Sent by |
|-------|------|---------|
| 0x410000 | `IOCTL_BTH_GET_LOCAL_INFO` | `NSPLookupServiceBegin` |
| 0x410200 | `IOCTL_BTH_SDP_CONNECT` | `NSPLookupServiceBegin` |
| 0x410204 | `IOCTL_BTH_SDP_DISCONNECT` | `NSPLookupServiceBegin` |
| 0x410208 | `IOCTL_BTH_SDP_SERVICE_SEARCH` | `NSPLookupServiceBegin` (type 1) |
| 0x41020C | `IOCTL_BTH_SDP_ATTRIBUTE_SEARCH` | `NSPLookupServiceBegin` (type 2) |
| 0x410210 | `IOCTL_BTH_SDP_SERVICE_ATTRIBUTE_SEARCH` | `NSPLookupServiceBegin` (type 3) |

To the socket transports (`\Device\BthTdi`, `\Device\BTHMS_RFCOMM`), through the AFD handles: see [Sockets](#sockets).

### ETW

WPP tracing only: control GUID `{9B65317A-28C3-43D8-9740-81A404A621ED}`, registered in `DllMain` (`EtwRegisterTraceGuidsW`, callback `WppControlCallback` 0x10001F0C); the messages go through `EtwTraceMessage` (`WPP_SF_*`) with the level tested before each one.
