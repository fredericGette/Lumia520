## SSPISRV.DLL

The server side of the SSPI RPC interface of the LSA: it gives the client processes access to the security packages through the local endpoint `lsasspirpc`.  
`SSPISRV.DLL` (36 864 bytes, 52 functions, public symbols) is loaded in the LSA process (`lsass.exe`, started by [WININIT.EXE](../applications/wininit.md)). Its only work is RPC: `SspiSrvInitialize` registers the interface `{4F32ADC8-6052-4A04-8701-293CCF2096F0}` on `ncalrpc:[lsasspirpc]` with a security descriptor that also lets the AppContainers in, and saves the table of functions given by its caller. Each of the 16 server routines checks its arguments, narrows the 64-bit handles and pointers of the wire format to 32 bits and calls the matching function of this table: the real work (credentials, contexts, logons) is done by the caller, in the LSA. The second export, `SspiSrvClientCallback`, lets the LSA call back the client of the current RPC call.  
The caller of the two exports is not in the extracted files analysed here: it's the LSA server (LSASRV.dll, not documented here). The client side of the interface is the SSPI client library of each process (SspiCli.dll, not documented here). The security packages behind the calls are in the LSA process, e.g. [MSV1_0.DLL](./msv1_0.md).

Location on the phone: `C:\Windows\System32\sspisrv.dll` ? (the export directory gives the name `SspiSrv.dll`).  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4.dll | `RpcServerUseProtseqEpW`, `RpcServerRegisterIf3`, `RpcServerInqCallAttributesW`, `RpcImpersonateClient`, `RpcRevertToSelfEx`, `NdrServerCall2`, `NdrClientCall2`, `I_RpcExceptionFilter`, `I_RpcMapWin32Status` |
| ntdll.dll | `RtlAllocateAndInitializeSid`, `RtlFreeSid`, `RtlValidSid`, `RtlCreateAndSetSD`, `RtlFreeHeap`, `NtOpenThreadToken`, `NtQueryInformationToken`, `NtClose`, `DbgPrintEx`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-processthreads-l1-1-2 | `GetCurrentProcessId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-libraryloader-l1-2-0 | `DisableThreadLibraryCalls` |
| api-ms-win-core-crt-l1-1-0, l2-1-0 | `memcpy`, `memset`, `strlen`, `strcpy_s`, `_vsnprintf_s`, `__C_specific_handler`, `_initterm`, `_initterm_e` |
| api-ms-win-core-heap-l1-2-0 | `GetProcessHeap`, `HeapFree` |
| api-ms-win-core-util-l1-1-0 | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-errorhandling-l1-1-2 | `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |

The heap, util, errorhandling, `TerminateProcess`, `GetCurrentProcess`, `_initterm*`, `__C_specific_handler` and `Rtl*` unwind imports are the Visual C++ DLL CRT startup and `/GS` cookie code. `strcpy_s`, `strlen`, `_vsnprintf_s` and `DbgPrintEx` are the [debug output](#debug-output). `NtOpenThreadToken`, `NtQueryInformationToken`, `NtClose`, `RpcImpersonateClient` and `RpcRevertToSelfEx` are used only by unreachable code ([SspirLogonUser](#sspirlogonuser-0x10002274)).

No other file is used: no DLL is loaded at run time, no process is started, no COM server, file or registry value is used.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 2 | `SspiSrvInitialize` | 0x1000295C | `PVOID *FunctionTable` (the [extension table](#extension-table)), returns an `NTSTATUS` |
| 1 | `SspiSrvClientCallback` | 0x100027E4 | 4 `ULONG`, `PVOID InBuffer` (12 bytes), `PVOID OutBuffer` (12 bytes), returns an `NTSTATUS` ([details](#sspisrvclientcallback-0x100027e4)) |

Global state:

| Variable | Address | Comment |
|----------|---------|---------|
| `gLsapSspiExtension` | | Pointer to the [extension table](#extension-table) given to `SspiSrvInitialize`. NULL until the RPC interface is registered: every server routine then returns `STATUS_NOT_SUPPORTED` (0xC00000BB) |
| `SspiInprocFunctions` | 0x10004008 | Table of 8 pointers returned by [SspirGetInprocDispatchTable](#sspirgetinprocdispatchtable-0x10002e1c): `MIDL_user_free`, `SspirAcquireCredentialsHandle`, `SspirFreeCredentialsHandle`, `SspirProcessSecurityContext`, `SspirDeleteSecurityContext`, `SspirApplyControlToken`, `SspirLogonUser`, `SspirGetUserName` |
| `DebugComponentName`, `DebugDpfltrId`, `DebugInfoLevel` | | `"LSASSPI"`, 138, 0 ([debug output](#debug-output)) |

### Extension table

Table of function pointers given by the caller of `SspiSrvInitialize` (in the LSA). Each RPC routine calls one entry; an entry left NULL makes the routine return `STATUS_NOT_SUPPORTED` (0xC00000BB). The names are those of the RPC routines that use them.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Allocate(`Size`): `MIDL_user_allocate`, and the buffers returned by `SspirCallRpc` and the query routines |
| 0x04 | 4 | Free: `MIDL_user_free` |
| 0x08 | 4 | Rundown of an `LSA_SSPI_HANDLE` context handle (client gone, `SspirDisconnectRpc`) |
| 0x0C | 4 | Connect ([opnum 0](#rpc)) |
| 0x10 | 4 | CallRpc (opnum 3) |
| 0x14 | 4 | AcquireCredentialsHandle (opnum 4) |
| 0x18 | 4 | FreeCredentialsHandle (opnum 5) |
| 0x1C | 4 | ProcessSecurityContext (opnum 6) |
| 0x20 | 4 | DeleteSecurityContext (opnum 7) |
| 0x24 | 4 | SslQueryCredentialsAttributes (opnum 8) |
| 0x28 | 4 | NegQueryContextAttributes (opnum 9) |
| 0x2C | 4 | SslSetCredentialsAttributes (opnum 10) |
| 0x30 | 4 | ApplyControlToken (opnum 11) |
| 0x34 | 4 | LookupAccountSid (opnum 13) |
| 0x38 | 4 | LogonUser (opnum 12) |
| 0x3C | 4 | GetUserName (opnum 14) |

### Startup

`_DllMainCRTStartup` (0x10002CE4): `__security_init_cookie`, CRT init, then `DllMain`. `DllMain` (0x100032E0) only calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH`.

### SspiSrvInitialize (0x1000295C)

1. Sets the [debug output](#debug-output) variables (`"LSASSPI"`, filter id 138, level 0).
2. `LsapMakeLowBoxRpcSD` (0x10002A2C) builds the [security descriptor](#security-descriptor) of the endpoint.
3. `RpcServerUseProtseqEpW(L"ncalrpc", RPC_C_PROTSEQ_MAX_REQS_DEFAULT (10), L"lsasspirpc", SD)`.
4. `RpcServerRegisterIf3(<interface>, NULL, NULL, RPC_IF_AUTOLISTEN | RPC_IF_ALLOW_LOCAL_ONLY (0x21), RPC_C_LISTEN_MAX_CALLS_DEFAULT (1234), MaxRpcSize 0x100000, no security callback, SD)`.
5. Frees the security descriptor (process heap) and saves the argument in `gLsapSspiExtension`.

The RPC errors are converted by `I_RpcMapWin32Status`. The server isn't started here: `RPC_IF_AUTOLISTEN` makes the interface listen on its own.

### Security descriptor

`LsapMakeLowBoxRpcSD` (0x10002A2C) calls `RtlCreateAndSetSD` with 6 ACEs, no owner, no group:

| ACE | Type | SID | Access |
|-----|------|-----|--------|
| 1 | Allow | `S-1-1-0` (Everyone) | `GENERIC_READ \| GENERIC_WRITE \| GENERIC_EXECUTE` (0xE0000000) |
| 2 | Deny | `S-1-5-12` (Restricted code) | 0xE0000000 |
| 3 | Allow | `S-1-5-7` (Anonymous) | `GENERIC_READ` (0x80000000) |
| 4 | Allow | `S-1-5-32-544` (Administrators) | `GENERIC_ALL` (0x10000000) |
| 5 | Allow | `S-1-3-4` (Owner rights) | `GENERIC_ALL` |
| 6 | Allow | `S-1-15-2-1` (All application packages) | `GENERIC_READ` |

The last ACE lets the AppContainer (lowbox) processes, i.e. the Store applications, connect to the endpoint.

### RPC

Server: endpoint `ncalrpc:[lsasspirpc]`, local clients only, no security callback, no check of the authentication level. A client opens an `LSA_SSPI_HANDLE` context handle with opnum 0 and gives it to all the other calls; its rundown (`LSA_SSPI_HANDLE_rundown`, 0x100027C4; `LSA_SSPI_HANDLE_SERIALIZED_rundown`, 0x100033C4, for the serialized flavour of the handle) calls entry 0x08 of the [extension table](#extension-table).

Interface `{4F32ADC8-6052-4A04-8701-293CCF2096F0}` version 1.0 (NDR transfer syntax), 16 procedures (`NdrServerCall2`, proc format at 0x100016A2, type format at 0x1000110A).

The security handles (`CredHandle`, `CtxtHandle`) are sent as 16 bytes (two 64-bit values) and the pointers / handles returned to the client as 64-bit values, so that the format is the same for 32-bit and 64-bit clients. Each routine refuses a value that doesn't fit in 32 bits with `STATUS_INTEGER_OVERFLOW` (0xC0000095), and a NULL required pointer with `STATUS_INVALID_PARAMETER` (0xC000000D). `UNICODE_STRING` below is the 8-byte structure type of the format string (length, maximum length, unique buffer).

| Opnum | Routine | Parameters (after the binding or context handle) | Use |
|-------|---------|----------------------------------------------|-----|
| 0 | `SspirConnectRpc` (0x1000276C) | `handle_t` (explicit binding), `[in, unique, string] char *ClientName ?`, `[in] ULONG`, `[out] ULONG *`, `[out] ULONG *`, `[out] LSA_SSPI_HANDLE *` | Connection: the binding handle is dropped and the 5 other arguments are given to entry 0x0C |
| 1 | `SspirDisconnectRpc` (0x100027A8) | `[in, out] LSA_SSPI_HANDLE *` | Calls the rundown, sets the handle to NULL, returns 0 |
| 2 | same function (0x100027A8, named `SspirDisconnectRpcAsync` in the symbols) | `[in, out] LSA_SSPI_HANDLE_SERIALIZED *` | Same, other flavour of context handle |
| 3 | `SspirCallRpc` (0x100021D0) | `[in] ULONG RequestSize`, `[in, size_is(RequestSize)] BYTE *Request`, `[out] ULONG *ReplySize`, `[out] BYTE **Reply` | [Generic call](#sspircallrpc-0x100021d0) |
| 4 | `SspirAcquireCredentialsHandle` (0x100024F8) | 16-byte handle ?, `[in, unique] UNICODE_STRING *Principal ?`, `[in] UNICODE_STRING Package ?`, `[in] ULONG CredentialUse ?`, `[in, unique] LUID *LogonId ?`, `[in]` 24-byte authentication data, `[in] hyper GetKeyFn ?`, `[in] hyper GetKeyArgument ?`, `[in] ULONG`, `[out]` 16-byte `CredHandle`, `[out] TimeStamp *Expiry ?` | Entry 0x14. The authentication data is passed as (pointer at +0x10 when the first DWORD isn't 0, else the DWORD at +8; DWORD at +0); both hypers must be below 2^32 |
| 5 | `SspirFreeCredentialsHandle` (0x10002600) | 16-byte handle ?, `[in]` 16-byte `CredHandle` | Entry 0x18 |
| 6 | `SspirProcessSecurityContext` (0x10002038) | 16-byte handle ?, `[in, out] ULONG *`, `[in, unique] UNICODE_STRING *Target ?`, `[in]` 16-byte `CredHandle` ?, `[in]` 16-byte `CtxtHandle` ?, 2 `[in] ULONG` (`ContextReq`, `TargetDataRep` ?), `[in, unique]` pointer, `[in]` 12-byte buffer descriptor, `[in]` pointer, `[out]` 12-byte buffer descriptor, `[out]` pointer, `[out]` 12-byte buffer descriptor, `[out]` 16-byte new `CtxtHandle`, `[out] ULONG *ContextAttr ?`, `[out] TimeStamp *Expiry ?`, `[out] ULONG *` | Entry 0x1C: the common path of `InitializeSecurityContext` / `AcceptSecurityContext` ? (18 arguments) |
| 7 | `SspirDeleteSecurityContext` (0x100026C8) | 16-byte handle ?, `[in]` 16-byte `CtxtHandle` | Entry 0x20 |
| 8 | `SspirSslQueryCredentialsAttributes` (0x10003560) | 16-byte handle ?, `[in]` 16-byte `CredHandle`, `[in] ULONG Attribute`, `[out]` union | [Query](#query-routines) of an SSL (Schannel) credential |
| 9 | `SspirNegQueryContextAttributes` (0x1000347C) | 16-byte handle ?, `[in]` 16-byte `CtxtHandle`, `[in] ULONG Attribute`, `[out]` union | [Query](#query-routines) of a Negotiate context |
| 10 | `SspirSslSetCredentialsAttributes` (0x10001EFC) | 16-byte handle ?, `[in]` 16-byte `CredHandle`, `[in]` 48-byte structure (required) | Entry 0x2C |
| 11 | `SspirApplyControlToken` (0x1000289C) | 16-byte handle ?, `[in]` 16-byte `CtxtHandle`, `[in]` 12-byte buffer descriptor (required) | Entry 0x30 |
| 12 | `SspirLogonUser` (0x10002274) | see [SspirLogonUser](#sspirlogonuser-0x10002274) | Entry 0x38 |
| 13 | `SspirLookupAccountSid` (0x100033D4) | 16-byte handle ?, `[in] SID *` (checked by `RtlValidSid`, else `STATUS_INVALID_SID` 0xC0000078), `[out] UNICODE_STRING *Name ?`, `[out] UNICODE_STRING *Domain ?`, `[out] SID_NAME_USE *` ? | Entry 0x34 |
| 14 | `SspirGetUserName` (0x10001F90) | 16-byte handle ?, `[in] ULONG NameFormat ?`, `[out] UNICODE_STRING *`, `[out] ULONG *` | Entry 0x3C (`GetUserNameEx` ?) |
| 15 | `SspirGetInprocDispatchTable` (0x10002E1C) | `[out] ULONG *Table` | [In-process table](#sspirgetinprocdispatchtable-0x10002e1c) |

The 12-byte "buffer descriptor" is a structure of two `ULONG` and a pointer (`SecBufferDesc`: `ulVersion`, `cBuffers`, `pBuffers` ?).  
The 16-byte "handle ?" that comes first in opnums 4…14 is converted to two 32-bit values like the security handles and passed to the LSA as is: its meaning (client / package reference) is unknown.

One callback procedure (`FC_CALLBACK_HANDLE`, callback opnum 0) is called by [SspiSrvClientCallback](#sspisrvclientcallback-0x100027e4).

### SspirCallRpc (0x100021D0)

1. `RequestSize` above 0x100 → `STATUS_INVALID_PARAMETER` (0xC000000D).
2. Allocates a 256-byte buffer with entry 0x00 (`STATUS_INSUFFICIENT_RESOURCES` 0xC000009A on failure), zeroes it and copies the request into it.
3. The `SHORT` at +2 of the request must be equal to `RequestSize`, else `STATUS_INVALID_PARAMETER_2` (0xC00000F0). This matches the `TotalLength` of a `PORT_MESSAGE` header: the request is probably one of the old LPC messages of the SSPI client, sent over RPC ?.
4. Calls entry 0x10 with the context handle and the buffer, which is answered in place: on success the buffer is returned as `Reply` and its `SHORT` at +2 as `ReplySize`; on failure it's freed.

### Query routines

`SspirSslQueryCredentialsAttributes` and `SspirNegQueryContextAttributes` accept only some attributes, allocate the result with entry 0x00 (size below), call entry 0x24 / 0x28 and free the buffer on failure. Any other attribute: `STATUS_INVALID_PARAMETER`.

| Routine | Attribute | Result size | Structure |
|---------|-----------|-------------|-----------|
| SslQueryCredentialsAttributes | 1 (`SECPKG_CRED_ATTR_NAMES`) | 4 | `SecPkgCredentials_NamesW` |
| | 86 (`SECPKG_ATTR_SUPPORTED_ALGS`) | 8 | `SecPkgCred_SupportedAlgs` |
| | 87 (`SECPKG_ATTR_CIPHER_STRENGTHS`) | 8 | `SecPkgCred_CipherStrengths` |
| | 88 (`SECPKG_ATTR_SUPPORTED_PROTOCOLS`) | 4 | `SecPkgCred_SupportedProtocols` |
| NegQueryContextAttributes | 0 (`SECPKG_ATTR_SIZES`) | 16 | `SecPkgContext_Sizes` |
| | 12 (`SECPKG_ATTR_NEGOTIATION_INFO`) | 8 | `SecPkgContext_NegotiationInfoW` |

### SspirLogonUser (0x10002274)

The RPC form of `LsaLogonUser` (17 parameters, the names come from the `LsaLogonUser` ones and are tentative):

| Stack | Direction | Type | Meaning |
|-------|-----------|------|---------|
| +0x00 | in | `LSA_SSPI_HANDLE` | Context handle |
| +0x04 | in | 16 bytes | Handle ? (narrowed to two 32-bit values) |
| +0x08 | in | 8-byte string (`STRING`) | `OriginName` (a non-empty string needs a buffer) |
| +0x0C | in | `enum16` | `LogonType` (`SECURITY_LOGON_TYPE`) |
| +0x10 | in | `ULONG` | `AuthenticationPackage` |
| +0x14 | in | 24-byte buffer | `AuthenticationInformation`: DWORD at +0 (length, a non-zero one needs the pointer at +0x10), DWORD at +8, pointer at +0x10 |
| +0x18 | in | 16-byte structure | `SourceContext` (`TOKEN_SOURCE`) |
| +0x1C | in, unique | `TOKEN_GROUPS *` | `LocalGroups`: every `Sid` must be non-NULL |
| +0x20 | in | `ULONG` | ? |
| +0x24 | in | pointer | ? |
| +0x28 | out | `ULONG *` | ? |
| +0x2C | out | `hyper *` | `ProfileBuffer` (32-bit pointer returned zero-extended) |
| +0x30 | out | `ULONG *` | `ProfileBufferLength` ? |
| +0x34 | in, out | 8-byte structure | `LogonId` (`LUID`) ? |
| +0x38 | out | `hyper *` | `Token` (handle zero-extended) |
| +0x3C | out | 48-byte structure | `Quotas`: the 32-bit `QUOTA_LIMITS` returned by the LSA (5 `SIZE_T` + `TimeLimit`) widened to five 64-bit sizes + the 64-bit `TimeLimit` |

All the pointers except `LocalGroups` are required (`STATUS_INVALID_PARAMETER` 0xC000000D).  
Before the call, when the context handle isn't NULL, `CheckLowboxAccess` (0x10002454) must say "allowed", else `STATUS_ACCESS_DENIED` (0xC0000022). In this build `CheckLowboxAccess` always says "allowed" (it sets its output to 1 and returns 0). The code just after it (0x1000245C, never called) is the real check: `RpcImpersonateClient`, `NtOpenThreadToken(TOKEN_QUERY)`, `NtQueryInformationToken(TokenIsAppContainer)`, allowed only when the client isn't an AppContainer, then `RpcRevertToSelfEx`. So on the phone an AppContainer client can call `SspirLogonUser`, unless the LSA checks it itself.

### SspirGetInprocDispatchTable (0x10002E1C)

`RpcServerInqCallAttributesW` (version 2, flags `RPC_QUERY_CLIENT_PID` 0x10) gives the process id of the client. If it's the LSA process itself (`GetCurrentProcessId`), the routine returns the address of `SspiInprocFunctions`, so that the SSPI client code running inside the LSA can call the routines directly instead of through RPC. Any other process gets `STATUS_ACCESS_DENIED` (0xC0000022); an error of `RpcServerInqCallAttributesW` is converted by `I_RpcMapWin32Status`.

### SspiSrvClientCallback (0x100027E4)

Called by the LSA while it serves an RPC call of this interface, to call back its client: `NdrClientCall2` with the callback procedure at 0x10001BA0 (`FC_CALLBACK_HANDLE`, so it goes to the client of the current call; callback opnum 0, 6 parameters). Arguments:

1. Four `ULONG` (R0…R3), sent as is.
2. An input structure of 12 bytes (`ULONG`, `ULONG`, `LONG`) sent as 16 bytes, the third field sign-extended to 64 bits: a `SecBuffer` (`cbBuffer`, `BufferType`, `pvBuffer`) ?.
3. An output structure of the same format, of which the first 12 bytes (the 64-bit value truncated) are copied back.

An RPC exception is converted by `I_RpcMapWin32Status`. What the client does with the callback depends on SspiCli.dll (not analysed).

### Debug output

`LsapDebugOut` (0x100032FC) writes `"LSASSPI: <message>"` with `DbgPrintEx(138, level, …)` when the mask of the message is in `DebugInfoLevel`. `DebugInfoLevel` is set to 0 and never changed, so nothing is printed. Messages: `SspiSrvInitialize: failed to build RPC SD %#x`, `SspiSrvInitialize: RpcServerUseProtseqEp failed: 0x%lx`, `LsapRPCInit: RpcServerRegisterIf2 failed: 0x%lx`, `SspirGetInprocDispatchTable: RpcServerInqCallAttributes failed: %lu`, `SspirGetInprocDispatchTable: Remote client ID: %p vs %p`.

There is no ETW provider, WNF state, registry value or file.
