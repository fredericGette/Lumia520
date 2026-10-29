## winhttp.dll

The Windows HTTP Services (WinHTTP) client library of Windows Phone 8.1, and the host of the WinHTTP Auto-Proxy service.  
`winhttp.dll` is a large DLL (2182 functions, only the exports are named in the database). It contains three things: the public WinHTTP API (sessions, connections, requests, WebSocket, URL helpers, proxy configuration), the COM object `WinHttp.WinHttpRequest.5.1`, and the `WinHttpAutoProxySvc` service (WPAD detection and PAC script execution), exported as a svchost `ServiceMain`. The HTTP protocol itself is delegated to `webio.dll` (imported by ordinal only) and WebSockets to `websocket.dll`. Proxy auto-detection uses DHCP option 252 (`dhcpcsvc.DLL`), DNS (`wpad`), the WinHTTP proxy registry settings, and a PAC script engine loaded from the `ProxyDllFile` registry value. A client process talks to the service through a local RPC interface (`{3473DD4D-2E88-4006-9CBA-22570909DD10}` v5.1) when it asks for out-of-process proxy resolution.  
None of the binaries documented on this site imports it. Its callers are applications and system components that use HTTP, not analysed here.

Location on the phone: `C:\Windows\System32\winhttp.dll` ? (the usual location of system DLLs; the extracted file has no notes).  

### Imports

Most imports are delay-loaded (marked "delay"): the DLL only loads them when the feature is used.

| DLL | Functions |
|-----|-----------|
| webio.dll (delay) | ordinals 1, 4, 5, 8–11, 14, 17–26, 28, 29, 31–33, 35–39, 42 (the HTTP stack; no names) |
| websocket.dll (delay) | `WebSocketCreateClientHandle`, `WebSocketBeginClientHandshake`, `WebSocketEndClientHandshake`, `WebSocketSend`, `WebSocketReceive`, `WebSocketGetAction`, `WebSocketCompleteAction`, `WebSocketAbortHandle`, `WebSocketDeleteHandle`, `WebSocketGetGlobalProperty` |
| ext-ms-win-winhttp-pal-l1-1-0.dll (delay) | `WinHttpPalIsImplemented`, `WinHttpPalDllInit`, `WinHttpPalDllUnload`, `WinHttpPalCreateRequestCtx`, `WinHttpPalFreeRequestCtx`, `WinHttpPalCreateCmSessionReference`, `WinHttpPalGetProxyForCurrentInterface`, `WinHttpPalFreeProxyInfo`, `WinHttpPalAcquireNextInterfaceAsync`, `WinHttpPalOnSendRequestComplete`, `WinHttpPalGetProxyCreds`, `WinHttpPalCancelRequest` |
| WS2_32.dll (delay) | `WSAStartup`, `WSACleanup`, `GetAddrInfoW`, `FreeAddrInfoW`, `WSAIoctl`, `socket`, `closesocket`, `setsockopt`, `ntohs`, `WSAGetLastError` (some by ordinal) |
| IPHLPAPI.DLL (delay) | `GetAdaptersAddresses`, `GetIfEntry2`, `GetBestInterfaceEx`, `GetIpForwardTable2`, `GetIpNetEntry2`, `ResolveIpNetEntry2`, `NotifyIpInterfaceChange`, `NotifyUnicastIpAddressChange`, `CancelMibChangeNotify2`, `ConvertInterfaceGuidToLuid`, `FreeMibTable` |
| NSI.dll (delay) | `NsiAllocateAndGetTable`, `NsiFreeTable` |
| dhcpcsvc.DLL (delay) | `DhcpRequestParams` |
| DNSAPI.dll (delay) | `DnsGetProxyInformation`, `DnsFreeProxyName` |
| ext-ms-win-firewallapi-webproxy-l1-1-0.dll (delay) | `FWIndicateProxyForUrl` |
| RPCRT4.dll (delay) | client: `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW`, `RpcBindingSetOption`, `RpcBindingFree`, `RpcStringFreeW`, `NdrClientCall2`, `NdrAsyncClientCall`, `RpcAsyncInitializeHandle`, `RpcAsyncCompleteCall`, `RpcAsyncCancelCall`; server: `RpcServerUseProtseqW`, `RpcServerRegisterIf3`, `RpcServerInqBindings`, `RpcEpRegisterW`, `RpcServerUnregisterIf`, `RpcBindingVectorFree`, `NdrServerCall2`, `NdrAsyncServerCall`, `RpcAsyncAbortCall`, `RpcServerTestCancel`, `RpcImpersonateClient`, `RpcRevertToSelf`, `RpcRevertToSelfEx`, `RpcRaiseException`; serialisation: `MesEncodeDynBufferHandleCreate`, `MesDecodeBufferHandleCreate`, `MesHandleFree`, `NdrMesTypeEncode2`, `NdrMesTypeDecode2`; `I_RpcExceptionFilter` |
| api-ms-win-service-*.dll (delay) | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus`, `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `CloseServiceHandle`, `NotifyServiceStatusChangeW`, `QueryServiceStatus` |
| api-ms-win-security-credentials-l1-1-0.dll (delay) | `CredReadW`, `CredWriteW`, `CredEnumerateW`, `CredReadDomainCredentialsW`, `CredFree` |
| CRYPT32.dll (delay) | `CryptUnprotectData`, `CryptProtectMemory`, `CryptUnprotectMemory`, `CertOpenStore`, `CertFindCertificateInStore`, `CertDuplicateCertificateContext`, `CertFreeCertificateContext`, `CertNameToStrW`, `CertCloseStore` |
| SspiCli.dll (delay) | `EnumerateSecurityPackagesA`, `FreeContextBuffer`, `SspiCopyAuthIdentity`, `SspiEncryptAuthIdentity`, `SspiIsAuthIdentityEncrypted`, `SspiEncodeAuthIdentityAsStrings`, `SspiZeroAuthIdentity`, `SspiFreeAuthIdentity`, `SspiLocalFree` |
| CRYPTBASE.dll (delay) | `SystemFunction036` (`RtlGenRandom`) |
| OLEAUT32.dll (delay) | by ordinal: `SysAllocString`, `SysAllocStringLen`, `SysFreeString`, `Variant*`, `SafeArray*`, `DispGetParam`, `LoadTypeLib`, `GetErrorInfo`, `SetErrorInfo`, `CreateErrorInfo` |
| CFGMGR32.dll (delay) | `CM_Open_Class_Key_ExW` |
| ext-ms-win-ntuser-*.dll (delay) | `RegisterClassA`, `UnregisterClassA`, `CreateWindowExA`, `DestroyWindow`, `DefWindowProcA`, `GetWindowLongA`, `SetWindowLongA`, `PeekMessageA`, `TranslateMessage`, `DispatchMessageA`, `PostMessageA`, `MsgWaitForMultipleObjects` |
| ntdll.dll | `RtlPublishWnfStateData`, `NtOpenFile`, `RtlGUIDFromString`, `RtlIpv4/Ipv6AddressToStringExW`, `RtlIpv4/Ipv6StringToAddressExW`, `RtlConvertSidToUnicodeString`, `RtlNtStatusToDosError`, `RtlDllShutdownInProgress`, `EtwEventRegister`, `EtwEventUnregister`, `EtwEventWrite`, `EtwRegisterTraceGuidsW`, `EtwUnregisterTraceGuids`, `EtwGetTraceLoggerHandle`, `EtwGetTraceEnableFlags`, `EtwGetTraceEnableLevel` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExA/W`, `RegCreateKeyExA/W`, `RegQueryValueExA/W`, `RegGetValueW`, `RegSetValueExA/W`, `RegDeleteValueW`, `RegDeleteKeyExW`, `RegEnumKeyExW`, `RegQueryInfoKeyA`, `RegCloseKey` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `ReadFile`, `WriteFile`, `GetFileSizeEx`, `SetFilePointer`, `SetEndOfFile`, `DeleteFileW`, `CreateDirectoryW`, `RemoveDirectoryW`, `FindFirstFileW`, `FindNextFileW`, `FindClose`, `GetFileAttributesW`, `SetFileAttributesW`, `CompareFileTime`, `LocalFileTimeToFileTime` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-core-libraryloader-l1-2-0.dll, api-ms-win-core-kernel32-legacy-l1-1-1.dll | `LoadLibraryExA/W`, `LoadLibraryW`, `GetProcAddress`, `FreeLibrary`, `GetModuleFileNameW`, `GetModuleHandleExA` |
| api-ms-win-core-apiquery-l1-1-0.dll | `ApiSetQueryApiSetPresence` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoUninitialize`, `CoCreateInstance`, `CoTaskMem*`, `CreateStreamOnHGlobal`, `GetHGlobalFromStream` |
| api-ms-win-security-base-l1-2-0.dll, api-ms-win-security-sddl-l1-1-0.dll | `CreateWellKnownSid`, `CheckTokenMembership`, `GetTokenInformation`, `DuplicateToken`, `ImpersonateLoggedOnUser`, `RevertToSelf`, `CopySid`, `ConvertSidToStringSidW`, `ConvertStringSecurityDescriptorToSecurityDescriptorW` |
| api-ms-win-core-threadpool-*.dll | thread-pool work, wait, timer and cleanup-group functions, `FreeLibraryWhenCallbackReturns`, `QueueUserWorkItem`, `RegisterWaitForSingleObjectEx`, `UnregisterWaitEx` |
| api-ms-win-core-url-l1-1-0.dll, api-ms-win-core-shlwapi-obsolete-l1-1-0.dll | `UrlCanonicalizeW`, `UrlCombineW`, `UrlUnescapeA`, `Str*` |
| api-ms-win-core-localization-l1-2-1.dll | `IdnToAscii`, `FormatMessageW` |
| api-ms-win-eventing-*.dll | `EventRegister`, `EventUnregister`, `EventWrite`, `EventWriteTransfer`, `EventActivityIdControl`, `TraceMessageVa` |
| other api-ms-win-core-*.dll | synchronisation, heap, string, time, process/thread, TLS, interlocked SList, environment (`ExpandEnvironmentStringsW`), delay-load helpers |
| msvcrt.dll | `malloc`, `free`, `memcpy`, `memset`, `qsort`, `rand`, string functions, `_initterm`, `__dllonexit`, `__C_specific_handler`, … |

The msvcrt, `RtlCaptureContext`/`RtlLookupFunctionEntry`/`RtlVirtualUnwind`, `UnhandledExceptionFilter`/`SetUnhandledExceptionFilter`/`TerminateProcess` imports are the Visual C++ DLL CRT startup and `/GS` security cookie code; `ResolveDelayLoadedAPI`/`DelayLoadFailureHook` are the delay-load helpers.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| PAC script engine, name from the registry value `ProxyDllFile` ([Registry](#registry)) | `LoadLibraryW` after `ExpandEnvironmentStringsW` (`sub_760C2594`, `sub_760D5EC4`); `GetProcAddress` of `InternetInitializeAutoProxyDll`, `InternetDeInitializeAutoProxyDll`, `InternetGetProxyInfo` and the `…Ex` versions | Runs the downloaded PAC script (`FindProxyForURL`); the default name when the value is missing isn't in the binary (`jsproxy.dll` on the desktop ?) |
| `winhttp.dll` (itself) | `LoadLibraryExA("winhttp.dll")` (`sub_76096310`, session creation) and `LoadLibraryExW(L"winhttp.dll", LOAD_LIBRARY_SEARCH_SYSTEM32)` (`sub_760AA14C`) + `GetProcAddress` of `WinHttpCreateProxyResolver`, `WinHttpGetProxyForUrlEx`, `WinHttpGetProxyResult`, `WinHttpFreeProxyResult`, `WinHttpCloseHandle`, `WinHttpOpen`, `WinHttpSetStatusCallback`, `WinHttpResetAutoProxy` | Extra reference on its own module while a session or a thread-pool callback is alive; the function pointers are used by the code shared with WinInet |
| `winhttp.dll` (itself), Passport | `LoadLibraryExW` + `GetProcAddress` of 14 `WinHttp*` functions (`sub_760CFE2C` / `sub_760BB9E0`, from `sub_760CBD74`) | Passport 1.4 authentication session (`Microsoft-WinHttp-Passport-Authentication-Service/1.4`); the code compares the name with `WinInet.dll`, it is shared with WinInet |
| mlang.dll ? (`CMultiLanguage` {275C23E2-3747-11D0-9FEA-00AA003F8646}) | `CoCreateInstance(…, CLSCTX_INPROC_SERVER, IID_IMultiLanguage {275C23E1-…})`, then `QueryInterface(IID_IMultiLanguage2 {DCCFC164-2B38-11D2-B7EC-00C04F8F5D9A})` (`sub_760C21F0`) | Character set conversion of `WinHttpRequest.ResponseText` (the charset table `_autodetect` … `x-x-big5` is in the binary) |
| Type library of winhttp.dll | `GetModuleFileNameW` + `LoadTypeLib` (`sub_760BE5D0`) | `IDispatch` of `WinHttpRequest` |
| `%userprofile%\…\winhttp\cachev3.dat` | `ExpandEnvironmentStringsW(L"%userprofile%")` (`sub_760CD7FC`), `CreateFileW` (`sub_760DE270`, `sub_760D3238`, `sub_760CCE7C`) | Auto-proxy script cache index (the middle of the path is built by `sub_760CF6D4`, not resolved) ; deleted by `WinHttpResetAutoProxy(WINHTTP_RESET_SCRIPT_CACHE)` |
| `<cache folder>\<random>.cache` | `"%s\\%u.cache"` with a `SystemFunction036`/`rand` number, `CreateFileW` + `WriteFile` (`sub_760D48EC`) | Downloaded PAC scripts |
| `\DEVICE\{NetCfgInstanceId}` | `NtOpenFile` + `DeviceIoControl` (`sub_760CF2E0` → `sub_760CD1C4`), see [Devices](#devices-and-ioctls) | Network adapter query, used to identify the current network (WPAD per network) |
| `WinHttpAutoProxySvc` (this DLL in svchost) | `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `NotifyServiceStatusChangeW` (`sub_760C7C08`) and RPC ([RPC](#rpc)) | Out-of-process proxy resolution |
| `ext-ms-win-winhttp-pal-l1-1-0` | delay-load, after `ApiSetQueryApiSetPresence` (`sub_760AC694`) | Platform adaptation layer (connection manager sessions, per-interface proxy and credentials); the DLL that implements this API set on the phone isn't known |

No process is started.

### Exports

The `WinHttp*` exports are the documented Win32 WinHTTP API; their parameters are those of `winhttp.h` and aren't repeated here.

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x760BE648 | none; `S_FALSE` while a class factory or object is alive |
| 2 | `DllGetClassObject` | 0x760C9B0C | `REFCLSID, REFIID, void **`; only {2087C2F4-2CEF-4953-A8AB-66779B670495} (`WinHttp.WinHttpRequest.5.1`), IID `IUnknown` or `IClassFactory`, else `CLASS_E_CLASSNOTAVAILABLE` / `E_NOINTERFACE` |
| 3 | `Private1` | 0x760E8020 | ? (undocumented) |
| 4 | `SvchostPushServiceGlobals` | 0x760BDE60 | `SVCHOST_GLOBAL_DATA *`, stored in `dword_760FB394` |
| 5 | `WinHttpAddRequestHeaders` | 0x7609C190 | documented |
| 6 | `WinHttpAutoProxySvcMain` | 0x760ECFF8 | `DWORD argc, LPWSTR *argv` (service main, see [below](#winhttpautoproxysvcmain-0x760ecff8)) |
| 7 | `WinHttpCheckPlatform` | 0x760ACD78 | none; always returns `TRUE` |
| 8 | `WinHttpCloseHandle` | 0x7609E180 | documented |
| 9 | `WinHttpConnect` | 0x760A28B4 | documented |
| 10 | `WinHttpCrackUrl` | 0x760A7150 | documented |
| 11 | `WinHttpCreateProxyResolver` | 0x7608EADC | documented |
| 12 | `WinHttpCreateUrl` | 0x760A67FC | documented |
| 13 | `WinHttpDetectAutoProxyConfigUrl` | 0x760E73E4 | documented |
| 14 | `WinHttpFreeProxyResult` | 0x76091F2C | documented |
| 15 | `WinHttpGetDefaultProxyConfiguration` | 0x760A864C | documented (reads `WinHttpSettings`) |
| 16 | `WinHttpGetIEProxyConfigForCurrentUser` | 0x7608F530 | documented (reads `DefaultConnectionSettings`) |
| 17 | `WinHttpGetProxyForUrl` | 0x760AA544 | documented |
| 18 | `WinHttpGetProxyForUrlEx` | 0x760915B4 | documented |
| 19 | `WinHttpGetProxyResult` | 0x76091B94 | documented |
| 20 | `WinHttpOpen` | 0x76097F78 | documented |
| 21 | `WinHttpOpenRequest` | 0x7609A998 | documented |
| 22 | `WinHttpProbeConnectivity` | 0x760EEE70 | undocumented, 4 arguments ?; see [below](#winhttpprobeconnectivity-0x760eee70) |
| 23 | `WinHttpQueryAuthSchemes` | 0x760E71D0 | documented |
| 24 | `WinHttpQueryDataAvailable` | 0x7608D520 | documented |
| 25 | `WinHttpQueryHeaders` | 0x7609D824 | documented |
| 26 | `WinHttpQueryOption` | 0x760A1428 | documented |
| 27 | `WinHttpReadData` | 0x7609EAE4 | documented |
| 28 | `WinHttpReceiveResponse` | 0x760A2CC8 | documented |
| 29 | `WinHttpResetAutoProxy` | 0x760E6618 | documented (`HINTERNET, DWORD dwFlags`), see [RPC](#rpc) |
| 30 | `WinHttpSendRequest` | 0x760A2324 | documented |
| 31 | `WinHttpSetCredentials` | 0x760E7084 | documented |
| 32 | `WinHttpSetDefaultProxyConfiguration` | 0x760DE540 | documented (writes `WinHttpSettings`) |
| 33 | `WinHttpSetOption` | 0x7609B66C | documented |
| 34 | `WinHttpSetStatusCallback` | 0x760A1980 | documented |
| 35 | `WinHttpSetTimeouts` | 0x76093C50 | documented |
| 36 | `WinHttpTimeFromSystemTime` | 0x760A9EC4 | documented |
| 37 | `WinHttpTimeToSystemTime` | 0x760930F4 | documented |
| 38 | `WinHttpWebSocketClose` | 0x7608E538 | documented |
| 39 | `WinHttpWebSocketCompleteUpgrade` | 0x7608E7AC | documented |
| 40 | `WinHttpWebSocketQueryCloseStatus` | 0x7609300C | documented |
| 41 | `WinHttpWebSocketReceive` | 0x7608FA78 | documented |
| 42 | `WinHttpWebSocketSend` | 0x7608FB30 | documented |
| 43 | `WinHttpWebSocketShutdown` | 0x760EC420 | documented |
| 44 | `WinHttpWriteData` | 0x7609065C | documented |

### Startup

`start` (`_DllMainCRTStartup`, 0x760AB4FC): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then the CRT dispatch (`sub_760AB208`) and `DllMain` (`sub_760DCFEC`).  
`DllMain` on `DLL_PROCESS_ATTACH` calls `sub_760AA960`: saves the module handle (`dword_760FAB1C`), registers the WPP tracing provider (`EtwRegisterTraceGuidsW`, control GUID {B3A7698A-0C45-44DA-B73D-E181C9B5C8E6}), keeps the process heap and initialises the global state (`sub_760AAA50`, `sub_760AAA24`, not analysed). `DLL_PROCESS_DETACH` calls `sub_760AA8D0`, `DLL_THREAD_DETACH` `sub_76093F5C`.  
The manifest ETW providers are registered later, on first use (see [ETW](#etw)).

The first session (`sub_76096310`, from `WinHttpOpen`) takes a reference on `winhttp.dll`, calls `WSAStartup(1.1)`, creates a thread-pool timer and, when the API set `ext-ms-win-winhttp-pal-l1-1-0` is present and `WinHttpPalIsImplemented()` is true, `WinHttpPalDllInit()`.

### WinHttpAutoProxySvcMain (0x760ECFF8)

The service main of `WinHttpAutoProxySvc`, run in svchost (svchost first calls `SvchostPushServiceGlobals`).

1. `RegisterServiceCtrlHandlerExW(L"WinHttpAutoProxySvc", ServiceHandler)`; two events (stop, idle).
2. Initialises the library (`sub_760A36E0(1)`) and creates the service object (`sub_760E5580` → `sub_760C54C4`, 128 bytes, `dword_760FB398`).
3. `SERVICE_START_PENDING` (wait hint 1000 ms), then starts the RPC server (`StartRpcServer`, `sub_760ECCF0`, see [RPC](#rpc)); on failure the service stops with `ERROR_SERVICE_SPECIFIC_ERROR` (1066) and the RPC error.
4. `SERVICE_RUNNING`, controls accepted 0x41 (`STOP` | `POWEREVENT`).
5. `RegisterWaitForSingleObjectEx` on the idle event with a 90 000 ms timeout (callback `sub_760BF88C`: idle stop ?), then the svchost stop callback (`SVCHOST_GLOBAL_DATA` +0x60, `RegisterStopCallback` ?) on the stop event with `sub_760E5E94`.

`ServiceHandler` (`sub_760E5F18`): `SERVICE_CONTROL_STOP` → `SERVICE_STOP_PENDING` (wait hint 8000) and sets the stop event; `INTERROGATE` → reports the status; `SERVICE_CONTROL_POWEREVENT` (13) → `sub_760E5C68`; anything else `ERROR_CALL_NOT_IMPLEMENTED`.

On the client side, `EnsureServiceStarted` (`sub_760CC570` → `sub_760C7C08`) opens the service with `SERVICE_QUERY_STATUS | SERVICE_START | SERVICE_INTERROGATE` (0x94), starts it (`ERROR_SERVICE_ALREADY_RUNNING` is accepted) and waits for it with `NotifyServiceStatusChangeW`. After a failure it doesn't retry for 0x107AC0 ms (18 minutes) and returns `ERROR_WINHTTP_AUTOPROXY_SERVICE_ERROR` (12178).

### RPC

Interface `{3473DD4D-2E88-4006-9CBA-22570909DD10}` version 5.1, both client (`RPC_CLIENT_INTERFACE` at 0x76087988, stub descriptor 0x76087A70) and server (`RPC_SERVER_INTERFACE` at 0x76087E10, dispatch table 0x76087C6C with `NdrAsyncServerCall` / `NdrServerCall2`).

**Server** (`StartRpcServer`, `sub_760ECCF0`, in the service):
- `RpcServerUseProtseqW(L"ncalrpc", default, SD)` with the security descriptor `D:(A;;GRGWGX;;;WD)(A;;GRGWGX;;;RC)(A;;GA;;;BA)(A;;GA;;;OW)(A;;GR;;;AC)` (Everyone and Restricted read/write/execute, Administrators and Owner all, AppContainers read).
- `RpcServerRegisterIf3(if, NULL, NULL, 0x29, 1234, -1, NULL, SD)`: flags `AUTOLISTEN | ALLOW_SECURE_ONLY | ALLOW_LOCAL_ONLY`, 1234 concurrent calls.
- `RpcServerInqBindings` + `RpcEpRegisterW(…, L"WinHttp Auto-Proxy Service")`: dynamic endpoint registered in the endpoint mapper.

**Client** (`sub_760964A8`): `RpcStringBindingComposeW(NULL, L"ncalrpc", NULL, NULL, …)` (no endpoint: resolved by the endpoint mapper), and two bindings (`sub_7609656C`), one with impersonation level `IDENTIFY` and one with `IMPERSONATE`. Both use `RpcBindingSetAuthInfoExW(authn level 6 = PKT_PRIVACY, authn service 0x14, QoS v4 with capabilities 0x11 (mutual authentication), dynamic identity tracking, server principal = SID `WinLocalServiceSid` from `CreateWellKnownSid(0x17)`)` and `RpcBindingSetOption(9, 1)` (`RPC_C_OPT_DONT_LINGER` ?). The service therefore runs as LocalService.

| Opnum | Server routine | Client caller | Parameters | Use |
|-------|----------------|---------------|------------|-----|
| 0 | `sub_760EB164` → `sub_760EA598` | `sub_760D7018` (`NdrAsyncClientCall`, from `sub_760D9184`) | `[in] RPC_ASYNC_STATE`, binding, `[in]` URL (request +0xE8), `[in]` auto-proxy options (+0xEC), `[in]` structure (+0xF0, session settings ?), `[out]` proxy result (+0x130), `[out] DWORD` error (+0x140) | Asynchronous proxy resolution for a URL (out-of-process `WinHttpGetProxyForUrl[Ex]`) |
| 1 | `sub_760E7314` | `WinHttpResetAutoProxy` (`NdrClientCall2`) | `[in] DWORD dwFlags`, returns `DWORD` | Reset of the service's auto-proxy state |

`WinHttpResetAutoProxy` calls opnum 1 when `WINHTTP_RESET_OUT_OF_PROC` (0x20000) is set. The server routine handles `WINHTTP_RESET_SCRIPT_CACHE` (0x8: deletes the PAC script cache, `sub_760DE65C` / `sub_760D81BC`), `WINHTTP_RESET_NOTIFY_NETWORK_CHANGED` (0x10000: network change, `sub_760C8B68` / `sub_760E3D60`) and `WINHTTP_RESET_STATE` (0x1: `sub_760E56CC` on the service object).

A third interface-like structure at 0x7608B610 (null GUID, NDR transfer syntax) is used with `MesEncodeDynBufferHandleCreate` / `NdrMesTypeEncode2`: serialisation of a structure, probably the WPAD/auto-proxy cache ?.

### Auto-proxy (WPAD)

- **DHCP**: `sub_760D7A38` asks DHCP option 252 (`DhcpRequestParams(DHCPCAPI_REQUEST_SYNCHRONOUS, …, adapter name, …, {option 252}, …)`, retried with a larger buffer on `ERROR_MORE_DATA`) and returns the PAC URL.
- **DNS**: `sub_760D16A4` builds `http://wpad.<domain>/wpad.dat` (`"http://%s/%s"`), walking up the domain; `DnsGetProxyInformation` is also used (`sub_760A4584`).
- **Download**: the script is accepted with the content type `application/x-ns-proxy-autoconfig` or a file extension in `.dat;.js;.pac;.jvs` (`sub_760DA540`), with `If-None-Match` / `If-Modified-Since` and `Cache-Control: max-age` / `no-cache` handling. Requests use the user agent `WinHttp-Autoproxy-Service/5.1`.
- **Execution**: in the PAC DLL ([Dependencies](#dependencies)); `InternetInitializeAutoProxyDllEx` is called with 0x30000 as first argument when the `…Ex` functions exist (`sub_760DD0D4`), else `InternetInitializeAutoProxyDll`. After the result, `FWIndicateProxyForUrl(…)` tells the firewall which proxy is used (`sub_760DB280`).
- **Per-network decision**: the network is identified from the adapters (`GetAdaptersAddresses`, NSI tables, net class registry, WWAN interfaces named `{WWAN-D00AA0AC-5A6E-4001-B586-E4B72BECDC19}`, MAC address formatted as `%02x-…`), and the decision is stored in `…\Internet Settings\Wpad` ([Registry](#registry)). A decision expires after `WpadExpirationDays` (default 30 days).
- `sub_760ED82C` checks a proxy with a `HEAD /` request.

### WinHttpProbeConnectivity (0x760EEE70)

Calls `sub_760EE6C4` then `sub_760EEEA2(0)`. `sub_760EE6C4` reads `ActiveWebProbeHost` / `ActiveWebProbePath` under `SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet` (`sub_760CD61C`), defaulting to `www.msftncsi.com` and `/ncsi.txt`, sends `GET` with `WinHttpConnect` / `WinHttpOpenRequest`, and on a proxy authentication challenge retries with credentials (`WinHttpSetCredentials`); credentials that worked are saved with `CredWriteW` (`sub_760C729C`). It is the same probe as the Network Connectivity Status Indicator.

### WinHttpRequest COM object

`DllGetClassObject` creates the class factory of `WinHttp.WinHttpRequest.5.1` ({2087C2F4-2CEF-4953-A8AB-66779B670495}, vtable 0x76085C50). The `IDispatch` names in the binary are `Open`, `SetRequestHeader`, `Send`, `Status`, `WaitForResponse`, `GetResponseHeader`, `ResponseBody`, `ResponseText`, `ResponseStream`, `StatusText`, `SetAutoLogonPolicy`, `SetClientCertificate`, `SetCredentials`, `SetProxy`, `GetAllResponseHeaders`, `Abort`, `SetTimeouts`, `Option`. Default user agent: `Mozilla/4.0 (compatible; Win32; WinHttp.WinHttpRequest.5)`. Events are marshalled to the caller's thread through a hidden window of class `_WinHttpEventMarshaller51` (`sub_760C0C44`, `sub_760CBC58`). Client certificates are looked up in the `LOCAL_MACHINE` / `CURRENT_USER` stores (`CertOpenStore`, `CertFindCertificateInStore`).

### Credentials

- `sub_760D7FBC`: `CredReadW` then `CredEnumerateW(L"Microsoft_WinInet_<server>:*")`; the WinInet credential blobs are decrypted with `CryptUnprotectData` and the entropy `abe2869f-9b47-4cd9-a358-c22904dba7f7`, and must start with `WININETCred` (`sub_760D4538`). Allowed by `ShareCredsWithWinHttp`.
- Passport single sign-on blobs: entropy `82BD0E67-9FEA-4748-8672-D5EFE5B779B0`, description `SSOCred` (`sub_760C60E8`).
- Passport 1.4 authentication (`Passport1.4`, `PassportURLs`, `PassportConfig` headers, `nexus.passport.com/rdr/pprdr.asp`, `DALogin`, `DARealm`, cookies `MSPAuth`, `MSPProf`, `MSPProfC`, `PPLState`).

### Registry

| Key | Values | Use |
|-----|--------|-----|
| `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp` | `DisableBranchCache`, `DisableAutoProxyAuth` | Global settings (`sub_760944E0`) |
| `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings` | `ShareCredsWithWinHttp` | Use of the WinInet saved credentials (`sub_760944AC`) |
| `Software\Microsoft\windows\CurrentVersion\Internet Settings` | `WinHttpLowerCaseHost` | Host name case (`sub_760924B8`) |
| `Software\Microsoft\windows\CurrentVersion\Internet Settings\Connections` | `WinHttpSettings` (binary) | `WinHttpGet/SetDefaultProxyConfiguration` (`sub_760A876C`, `sub_760CB628`) |
| same key (HKCU) | `DefaultConnectionSettings` | `WinHttpGetIEProxyConfigForCurrentUser` (`sub_7608F6B8`) |
| `SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings` | `ProxySettingsPerUser` | Per-user or per-machine proxy (`sub_7608F834`) |
| `Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad` (subkey per network ?) | `WpadDecisionReason`, `WpadDecisionTime`, `WpadDecision`, `WpadNetworkName`, `WpadDetectedUrl`, `WpadDhcp`, `WpadDns` (written, `sub_760C3AD4`); `WpadExpirationDays`, `ForceFailure` (read) | WPAD decision cache |
| `SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp\Passport Test` | `LoginServerUrl`; `LoginServerRealm`, `ConfigVersion` | Passport test configuration |
| `SYSTEM\CurrentControlSet\Services\WinHttpAutoProxySvc\Parameters` | `ProxyDllFile` (`REG_EXPAND_SZ`) | PAC script engine DLL |
| `SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet` | `ActiveWebProbeHost`, `ActiveWebProbePath` | Connectivity probe |
| Net class key {4D36E972-E325-11CE-BFC1-08002BE10318} (`CM_Open_Class_Key_ExW`), each subkey | `NetCfgInstanceId`, `Characteristics` | Adapter lookup (`sub_760BB864`) |

### Devices and IOCTLs

`sub_760CF2E0` formats `\DEVICE\%s` with an adapter `NetCfgInstanceId`, opens it with `NtOpenFile` (`sub_760C9FB4`) and sends one IOCTL (`sub_760CD1C4`):

| Property | Value |
|----------|-------|
| IOCTL | 0x0017003E |
| Device | 0x17 (`FILE_DEVICE_PHYSICAL_NETCARD`) |
| Function | 0xF (15) |
| Access | `FILE_ANY_ACCESS` |
| Method | `METHOD_OUT_DIRECT` |

| Buffer | Offset | Size | Comment |
|--------|--------|------|---------|
| Input | 0x00 | 4 | 0x80010202 (constant at 0x760FA4C4, an NDIS OID ?) |
| Output | 0x00 | 0x30 | Result; if the DWORD at +0x04 is 8, the 8 bytes at +0x08 are returned, else the DWORD at +0x08 ? |

The meaning of the value read isn't known.

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x1192063AA3BC0875 (`.text:0x7608B5F8`) | `WHTP`, 1 (version 1, well-known, system scope) | none (published with a NULL buffer, length 0) | Published by `sub_760C5C24`, method 7 of the auto-proxy object vtable at 0x7608B570, when the object's +0x44 is set: change notification of the auto-proxy state ? |

### ETW

| Provider | Registered in | Comment |
|----------|---------------|---------|
| {7D44233D-3055-4B9C-BA64-0D47CA40A232} (Microsoft-Windows-WinHttp) | `sub_760A8B28` (`EtwEventRegister`) | Manifest events |
| {83ED54F0-4D48-4E45-B16E-726FFD1FA4AF} (Microsoft-Windows-Networking-Correlation ?) | `sub_760A8BFC` (`EventRegister`), called by `sub_760A8B28` | Activity correlation ? |
| {43D1A55C-76D6-4F7E-995C-64C711E5CAFE} | `sub_760BF5FC` (`EtwEventRegister`) | ? |
| WPP control GUID {B3A7698A-0C45-44DA-B73D-E181C9B5C8E6} | `DllMain` (`EtwRegisterTraceGuidsW`, `sub_760AAAC4`) | WPP software tracing (`.wpp_sf` section, `TraceMessageVa`); the trace calls `sub_760F94D0` / `sub_760F9398` are everywhere |

The individual `EVENT_DESCRIPTOR`s weren't listed.
