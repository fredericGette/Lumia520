## bthelpersvc.dll

A Bluetooth helper of Windows Phone 8.1: a COM local server that exposes the Bluetooth SDP functions of Winsock (namespace `NS_BTH`) through the interface `IBtHelperSvc`.  
`bthelpersvc.dll` is a very small C++ DLL (64 functions, most of them CRT and MIDL proxy/stub code; the database has its symbols). `InitializeBtHelperSvc` creates one `BtHelperSvc` object, calls `WSAStartup` and registers the object with `CoRegisterClassObject` as a local server. Its methods check whether a remote device offers a service (`WSALookupServiceBeginW` / `WSALookupServiceNextW` with the device address as context), run a service lookup step by step for the client, and publish or delete raw SDP records on the local SDP server (`WSASetServiceW` with a `BTH_SET_SERVICE` blob). The published records are remembered with the process id of the RPC client, and only that process can delete them. The same DLL is the proxy/stub DLL of `IBtHelperSvc` (`DllGetClassObject`, `GetProxyDllInfo`).  
The process that calls `InitializeBtHelperSvc` (the host of the server) and the clients of the interface are unknown: no other extracted binary references the DLL, its CLSID or its IID. Its role (giving SDP access to a process that can't use the Bluetooth namespace of Winsock itself, e.g. an application) is a guess ?. The Winsock Bluetooth provider is presumably `WSHBTH.DLL` (not analysed).

Location on the phone: `C:\Windows\System32\bthelpersvc.dll` ? (the extracted file has no notes).  
Source folder: `src\appplat\src\nativefx\network\bluetooth\bthelpersvc\lib\` (precompiled header symbol of the static library `BtHelperSvcLib`).  

### Imports

| DLL | Functions |
|-----|-----------|
| WS2_32 | `WSAStartup`, `WSACleanup`, `WSAGetLastError`, `WSASetServiceW`, `WSALookupServiceBeginW`, `WSALookupServiceNextW`, `WSALookupServiceEnd` |
| api-ms-win-core-com-l1-1-1 | `CoRegisterClassObject`, `CoRevokeClassObject` |
| RPCRT4 | `I_RpcBindingInqLocalClientPID`; `NdrDllGetClassObject`, `NdrDllCanUnloadNow`, `NdrOleAllocate`, `NdrOleFree`, `CStdStubBuffer_*`, `NdrCStdStubBuffer_Release`, `IUnknown_*_Proxy` |
| api-ms-win-core-synch-l1-2-0 | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `Sleep` |
| api-ms-win-core-libraryloader-l1-2-0 | `DisableThreadLibraryCalls` |
| api-ms-win-core-processthreads-l1-1-2, -errorhandling-l1-1-2, -rtlsupport-l1-2-0 | `GetCurrentProcess`, `TerminateProcess`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memcpy_s`, `memset`, `memcmp`, `_vsnwprintf`, `_initterm`, `_amsg_exit`, `_XcptFilter`, `__C_specific_handler` |

The processthreads, errorhandling, rtlsupport imports, `Sleep` and most of msvcrt are the Visual C++ DLL CRT startup and `/GS` security cookie code. The `CStdStubBuffer_*`, `IUnknown_*_Proxy` and `Ndr*` imports are the MIDL-generated proxy/stub of `IBtHelperSvc`.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| Winsock Bluetooth namespace provider (`WSHBTH.DLL` ?, not analysed) | `WSASetServiceW` / `WSALookupService*` with `dwNameSpace` = `NS_BTH` (16) | Local SDP records and SDP queries to remote devices (`WSHBTH.DLL` contains the client of the RPC interface of [BTHSERV.DLL](./bthserv.md#rpc), which publishes SDP records and queries the remote ones) |

No DLL is loaded at run time, and no process, file or COM server is opened.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 6 | `InitializeBtHelperSvc` | 0x1000153C | none, returns an HRESULT |
| 7 | `UninitializeBtHelperSvc` | 0x10001610 | none |
| 3 | `GetProxyDllInfo` | 0x10001658 | `const ProxyFileInfo ***`, `const CLSID **` |
| 5 | `DllGetClassObject` | 0x10001674 | `REFCLSID`, `REFIID`, `void **` (`NdrDllGetClassObject`) |
| 4 | `DllCanUnloadNow` | 0x100016A0 | none (`NdrDllCanUnloadNow(&gPFactory)`) |

`GetProxyDllInfo`, `DllGetClassObject` and `DllCanUnloadNow` are the standard MIDL proxy DLL exports: the proxy/stub class is `CLSID_PSFactoryBuffer` `{80B9DA98-52CA-4187-A919-5EAF30030E9B}`, for the single interface `IBtHelperSvc` `{280768FE-EE84-4B29-9709-1DB5E66FCD93}` (`bthelpersvc_ProxyFileInfo`, 0x10001308).

### Global state

| Address | Comment |
|---------|---------|
| 0x10004238 | `BtHelperSvc *`, the server object |
| 0x1000423C | Cookie returned by `CoRegisterClassObject` |

`BtHelperSvc` object (0x2C bytes, `operator new` in `InitializeBtHelperSvc`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `BtHelperSvc` (0x100013D8, see [IBtHelperSvc](#ibthelpersvc)) |
| 0x04 | 4 | Reference count (1 at creation, interlocked `AddRef` / `Release`) |
| 0x08 | 1 | `WSAStartup` succeeded |
| 0x0C | 8 | `LIST_ENTRY` head of the [published records](#published-records) |
| 0x14 | 0x18 | `CRITICAL_SECTION` protecting the list |

### Startup

`_DllMainCRTStartup` (0x10002418): CRT. `DllMain` (0x10001520) only calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH`.

### InitializeBtHelperSvc (0x1000153C)

1. Creates the `BtHelperSvc` object (vtable, reference count 1, empty list, `InitializeCriticalSection`) and stores it at 0x10004238; `E_OUTOFMEMORY` if `new` fails.
2. `WSAStartup(0x0202, &wsaData)`; on success sets the flag +0x08. A failure returns `HRESULT_FROM_WIN32(WSAGetLastError())`.
3. `CoRegisterClassObject({08E30C2B-1D1B-4A24-9AC1-FD75E92539EB}, object, CLSCTX_LOCAL_SERVER, REGCLS_MULTIPLEUSE, &cookie)`.
4. Any failure calls `UninitializeBtHelperSvc` and returns the error.

The object registered is the `BtHelperSvc` itself, not a class factory: its `QueryInterface` only accepts `IUnknown` and `IBtHelperSvc`, so a client must get it with `CoGetClassObject(CLSID {08E30C2B-…}, CLSCTX_LOCAL_SERVER, NULL, IID_IBtHelperSvc, …)`; `CoCreateInstance` (which asks for `IClassFactory`) would fail with `E_NOINTERFACE`. All the clients share this one object.

`UninitializeBtHelperSvc` (0x10001610): `CoRevokeClassObject(cookie)`, `WSACleanup` if the flag +0x08 is set, then `Release` of the object. The destructor (0x100016F4) deletes the critical section and frees the list nodes, without deleting the SDP records they describe.

### IBtHelperSvc

CLSID `{08E30C2B-1D1B-4A24-9AC1-FD75E92539EB}`, IID `{280768FE-EE84-4B29-9709-1DB5E66FCD93}`. Methods (vtable at 0x100013D8, names from the symbols; directions and types from the MIDL procedure format string at 0x10001112):

| Index | Method | Address | Parameters |
|-------|--------|---------|------------|
| 3 | `CheckDeviceServiceSupport` | 0x1000179C | `[in] ULONGLONG address`, `[in] REFGUID serviceClass`, `[out] BOOL *supported` |
| 4 | `PublishAdvancedSdpRecord` | 0x100018D4 | `[in] ULONG fCodService`, `[in] ULONG recordLength`, `[in, size_is(recordLength)] BYTE *record`, `[out] ULONG *sdpVersion`, `[out] int *recordHandle` |
| 5 | `UnpublishAdvancedSdpRecord` | 0x100019D0 | `[in] int recordHandle` |
| 6 | `BeginSimpleServiceLookup` | 0x10001B00 | `[in] ULONGLONG address`, `[in] REFGUID serviceClass`, `[in] ULONG controlFlags`, `[out] int *lookupHandle` |
| 7 | `NextServiceLookup` | 0x10001BB8 | `[in] int lookupHandle`, `[in] ULONG controlFlags`, `[in] ULONG bufferLength`, `[out, size_is(bufferLength)] BYTE *buffer`, `[out] ULONG *length`, `[out] UINT *serverBuffer` |
| 8 | `EndServiceLookup` | 0x10001C38 | `[in] int lookupHandle` |

They all return an HRESULT; a Winsock error is returned as `HRESULT_FROM_WIN32(WSAGetLastError())`, a NULL output pointer as `E_INVALIDARG`. The handles of the SDP records and of the lookups are passed as 32-bit integers.

**Lookup query.** `CheckDeviceServiceSupport` and `BeginSimpleServiceLookup` build the same `WSAQUERYSETW` (0x3C bytes): `dwSize` 0x3C, `lpServiceClassId` = copy of the service class GUID, `dwNameSpace` = `NS_BTH` (16), `dwNumberOfCsAddrs` 0, `lpszContext` = the device address formatted by `AddressToString` (0x10001C78) as `L"(%02X:%02X:%02X:%02X:%02X:%02X)"`, most significant byte first (20 characters).

**CheckDeviceServiceSupport** (0x1000179C):
1. `*supported` = FALSE; `WSALookupServiceBeginW(&query, LUP_FLUSHCACHE (0x1000), &h)`: the SDP search is always sent to the device. `WSASERVICE_NOT_FOUND` (10108) gives `S_OK` and FALSE; another error is returned.
2. `WSALookupServiceNextW(h, LUP_RETURN_ADDR (0x100), &len = 0x3C, buffer of 0x3C bytes)`. `WSAEFAULT` (10014, the result doesn't fit: there is a record) gives TRUE, `WSA_E_NO_MORE` (10110) gives FALSE, another error is returned. If the call succeeds `*supported` stays FALSE.
3. `WSALookupServiceEnd(h)`.

**BeginSimpleServiceLookup** (0x10001B00) calls `WSALookupServiceBeginW` with the `controlFlags` of the caller and returns the lookup handle. **NextServiceLookup** (0x10001BB8) calls `WSALookupServiceNextW(lookupHandle, controlFlags, &bufferLength, buffer)`; it sets `*serverBuffer` to the address of the buffer in the server, so that the client can rebase the pointers of the `WSAQUERYSETW` copied in the byte array ?; `*length` is the size of the result, or the size needed when the error is `WSAEFAULT` (0x8007271E). **EndServiceLookup** (0x10001C38) calls `WSALookupServiceEnd`.

### Published records

**PublishAdvancedSdpRecord** (0x100018D4):
1. Checks the pointers (`E_INVALIDARG`) and that `recordLength + 0x24` doesn't overflow (0x80070216, `ERROR_ARITHMETIC_OVERFLOW`).
2. Allocates `recordLength + 0x24` bytes and builds a `BTH_SET_SERVICE` (below), with the record copied after it.
3. `WSASetServiceW(&querySet, RNRSERVICE_REGISTER (0), 0)` with `dwSize` 0x3C, `dwNameSpace` `NS_BTH` and `lpBlob` = {`recordLength + 0x24`, buffer}.
4. `TrackRecordHandle` (0x10001CC0): `I_RpcBindingInqLocalClientPID(NULL, &pid)` gives the process id of the calling client; a node of 0x10 bytes (pid, record handle, `LIST_ENTRY`) is added at the end of the list, under the critical section.
5. Returns the SDP version and the record handle written by the provider.

`BTH_SET_SERVICE` blob:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `PULONG pSdpVersion` (points to 1 on input, version on output) |
| 0x04 | 4 | `HANDLE *pRecordHandle` (output) |
| 0x08 | 4 | `fCodService`: the class of device service bits, from the first parameter |
| 0x0C | 0x14 | Reserved (0) |
| 0x20 | 4 | `ulRecordLength` |
| 0x24 | `recordLength` | The SDP record, copied from the client |

**UnpublishAdvancedSdpRecord** (0x100019D0):
1. `I_RpcBindingInqLocalClientPID(NULL, &pid)`.
2. Searches the list for the node (pid, handle), removes and frees it; if there's none it returns `E_INVALIDARG`: a process can only delete the records it published.
3. `WSASetServiceW(&querySet, RNRSERVICE_DELETE (2), 0)` with a blob of 0x25 bytes whose first two fields point to the SDP version (1) and to the record handle.

The list isn't cleaned when a client process ends (no rundown): its records stay published until the server stops, and the destructor doesn't delete them either.
