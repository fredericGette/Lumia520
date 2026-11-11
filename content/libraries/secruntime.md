## SecRuntime.dll

The user-mode client library of the Windows Phone 8.1 security model ("Security Manager"): chambers, capabilities, security descriptors of named objects and local RPC security.  
`SecRuntime.dll` is a small DLL (96 016 bytes, 214 functions, 48 exports). Most of its exports only read the security metastore in the registry (`HKLM\Software\Microsoft\SecurityManager\…`): the security descriptor that a named object (RPC endpoint, ALPC port, WNF state…) must have, the SIDs and properties of an application / service ("chamber"), the SIDs of a capability, and they check tokens against them (`CapabilityCheck`). The operations that need privileges are forwarded to the `LaunchAppSvc` service through four LRPC interfaces: starting a process in a chamber, creating a chamber token, opening other processes, the device unique ID, certificates, service start configuration and smart-card nodes. Two exports send IOCTLs to the `\\.\SecMgr` device (kernel privilege cache).  
It's imported by most system components that host or call an RPC server, or check a caller's capability: [ReminderEvents.dll](./reminderevents.md), [ShellChromeAPI.dll](./shellchromeapi.md), [ShellChrome.dll](./shellchrome.md), [AlarmsSettingHandler.dll](./alarmssettinghandler.md), [WPTimeSvc.dll](./wptimesvc.md), [BTAGService.dll](./btagservice.md), [BtConnectionManagerService.dll](./btconnectionmanagerservice.md), [BtServ.dll](./btserv.md), [pacmanserver.dll](./pacmanserver.md), [UpdateUefiDb.exe](../applications/updateuefidb.md), [MobileUI.exe](../applications/mobileui.md) (`CreateProcessInChamber` of the Narrator, transient object security descriptors of its endpoints and of the COM security), and loaded at run time by [w32time.dll](./w32time.md#ismobilecore-0x64ba6610). The `LaunchAppSvc` service (the RPC server) and the `\\.\SecMgr` driver aren't analysed.

Location on the phone: `C:\Windows\System32\SecRuntime.dll` ? (the usual location of system DLLs; the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `NtOpenKey`, `NtEnumerateKey`, `NtQueryValueKey`, `NtClose`, `NtOpenThreadTokenEx`, `NtOpenProcessTokenEx`, `NtDuplicateToken`, `NtQueryInformationToken`, `RtlCheckTokenCapability`, `RtlCheckTokenMembership`, `RtlGetAppContainerNamedObjectPath`, `RtlGetFullPathName_UEx`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlInitUnicodeString`, `RtlAppendUnicodeToString`, `RtlFreeUnicodeString`, `RtlUpcaseUnicodeChar`, `RtlConvertSidToUnicodeString`, SID functions (`RtlAllocateAndInitializeSid`, `RtlInitializeSid`, `RtlSubAuthoritySid`, `RtlSubAuthorityCountSid`, `RtlLengthSid`, `RtlLengthRequiredSid`, `RtlCopySid`, `RtlEqualSid`, `RtlValidSid`, `RtlFreeSid`), security descriptor functions (`RtlCreateSecurityDescriptor`, `RtlCreateAcl`, `RtlAddAccessAllowedAce`, `RtlAddMandatoryAce`, `RtlSetDaclSecurityDescriptor`, `RtlSetSaclSecurityDescriptor`, `RtlSetOwnerSecurityDescriptor`, `RtlLengthSecurityDescriptor`, `RtlAbsoluteToSelfRelativeSD`), `RtlCopyLuid`, `RtlNtStatusToDosError` |
| RPCRT4.dll | `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingFree`, `RpcBindingSetAuthInfoExW`, `RpcServerUseProtseqW`, `RpcServerRegisterIf3`, `RpcImpersonateClient`, `RpcRevertToSelf`, `RpcRevertToSelfEx`, `NdrClientCall2`, `I_RpcExceptionFilter` |
| CRYPT32.dll (delay-load) | `CryptHashCertificate2`, `CertGetEnhancedKeyUsage` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegEnumKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegCloseKey` |
| api-ms-win-service-management-l1-1-0.dll | `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `CloseServiceHandle` |
| api-ms-win-service-winsvc-l1-2-0.dll | `QueryServiceStatus` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-security-sddl-l1-1-0.dll | `ConvertSidToStringSidW` |
| api-ms-win-security-lsalookup-l1-1-1.dll | `LookupAccountNameLocalW` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentThread`, `OpenThreadToken`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-processenvironment-l1-2-0.dll | `GetCurrentDirectoryW` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalAlloc`, `LocalFree` |
| api-ms-win-core-string-l1-1-0.dll | `WideCharToMultiByte` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-synch-l1-2-0.dll | `InitOnceBeginInitialize`, `InitOnceComplete`, `Sleep` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `DisableThreadLibraryCalls`, `GetModuleHandleExW`, `GetModuleFileNameA` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1.dll | `DebugBreak` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| ntdll.dll (CRT) | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memcpy_s`, `memset`, `memcmp`, `wcscmp`, `_wcsicmp`, `strcmp`, `wcslen`, `wcsnlen`, `strrchr`, `strncpy_s`, … (CRT, `_initterm`, C++ exceptions, `std::list`) |

The msvcrt, processthreads (`GetCurrentProcess`, `TerminateProcess`), errorhandling, debug and the ntdll unwind imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code. `GetModuleHandleExW` / `GetModuleFileNameA` give the module name written in the ETW events.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| CRYPT32.dll | Delay-load | Certificate hash and EKU for [CheckCertificateChainCapabilityAuthorization](#checkcertificatechaincapabilityauthorization-0x1000a3c4) |
| `LaunchAppSvc` service (RPC server, dynamic LRPC endpoint) | `OpenServiceW` / `StartServiceW` and `RpcBindingCreateW` / `RpcBindingBind` ([RPC](#rpc)) | Process creation in a chamber, tokens, handles, device ID, certificates, service configuration, smart-card nodes. The service binary isn't known |
| `\\.\SecMgr` | `CreateFileW` + `DeviceIoControl` ([Kernel privilege cache](#kernel-privilege-cache)) | Driver of the Security Manager (not identified) |

### Exports

Strings are UTF-16. "Token" is optional (NULL = token of the current thread, or of the process if the thread doesn't impersonate). Unless noted, the functions return an NTSTATUS for the local ones and an HRESULT for the RPC ones.

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `CheckCertificateChainCapabilityAuthorization` | 0x1000A3C4 | `PCCERT_CHAIN_CONTEXT chain`, capability list ?, …, `BOOLEAN *authorized` (see [below](#checkcertificatechaincapabilityauthorization-0x1000a3c4)) |
| 2 | `CheckPrincipalClassCapabilityAuthorization` | 0x1000A088 | 3 parameters not used, `BOOL *authorized`: always sets 1 and returns 0 |
| 3 | `AddSubjectCertificateToEnrollmentNeededAccountStores` | 0x1000D360 | `BYTE *cert`, `DWORD cbCert`, `PCWSTR`, `DWORD` → RPC [certificates](#rpc) opnum 1 |
| 4 | `AddSubjectCertificateToStore` | 0x1000D2CC | `BYTE *cert`, `DWORD cbCert`, `PCWSTR store` ?, `DWORD` → opnum 0 |
| 5 | `BuildSecurityDescriptorForSharingAccess` | 0x10005510 | `HANDLE targetToken`, `HANDLE ownerToken`, `ACCESS_MASK access`, `PSECURITY_DESCRIPTOR *sd`: `…Ex` with no mandatory label |
| 6 | `BuildSecurityDescriptorForSharingAccessEx` | 0x10005068 | `HANDLE targetToken`, `HANDLE ownerToken`, `ACCESS_MASK access`, `ACCESS_MASK labelPolicy`, `PSECURITY_DESCRIPTOR *sd` ([below](#buildsecuritydescriptorforsharingaccessex-0x10005068)) |
| 7 | `CapabilityCheck` | 0x10002D30 | `HANDLE token`, `PCWSTR capability`, `BOOLEAN *granted` ([below](#capabilitycheck-0x10002d30)) |
| 8 | `ChangeServiceStartupConfig` | 0x1000D6BC | `PCWSTR service`, `DWORD` (start type ?) → RPC `LaunchAppSvc` opnum 0 |
| 9 | `CreateProcessInChamber` | 0x1000BF38 | `PCWSTR`, `PCWSTR`, `PCWSTR applicationName`, `PWSTR commandLine`, `BOOL inheritHandles` ?, `DWORD creationFlags`, `PCWSTR currentDirectory`, `STARTUPINFOW *si`, `PROCESS_INFORMATION *pi`: `…Ex` with 0 for the 64-bit value |
| 10 | `CreateProcessInChamberEx` | 0x1000BC64 | Same with a `ULONGLONG` after `applicationName` ([below](#createprocessinchamberex-0x1000bc64)) |
| 11 | `CreateSCardDevInfoNode` | 0x1000D7A0 | `PCWSTR name`, `DWORD` → RPC smart-card opnum 0; `E_UNEXPECTED` for `DefaultNFC` and `UICC` |
| 12 | `CreateTokenFromChamberSid` | 0x1000CE24 | `PCWSTR sid`, `DWORD`, `HANDLE *token`: `…Ex(sid, x, 0, token)` |
| 13 | `CreateTokenFromChamberSidEx` | 0x1000CE38 | `PCWSTR sid`, `DWORD`, `DWORD`, `HANDLE *token` → RPC opnum 4 |
| 14 | `DeleteCertificateChain` | 0x1000D5A8 | `BYTE *cert`, `DWORD cbCert` → certificates opnum 5 |
| 15 | `DeleteSubjectCertificateFromEnrollmentNeededAccountStores` | 0x1000D488 | `PCWSTR`, `DWORD` → certificates opnum 3 |
| 16 | `DeleteSubjectCertificateFromStore` | 0x1000D3F4 | `BYTE *cert`, `DWORD cbCert`, `PCWSTR store` ?, `DWORD` → certificates opnum 2 |
| 17 | `DestroySCardDevInfoNode` | 0x1000D858 | `PCWSTR name` → smart-card opnum 1 (second RPC parameter always 2); `E_UNEXPECTED` for `DefaultNFC` and `UICC` |
| 18 | `FreeTransientObjectSecurityDescriptor` | 0x10003ECC | `PSECURITY_DESCRIPTOR`: `RtlFreeHeap` on the process heap |
| 19 | `GetApplicationBNOPrefixPath` | 0x10005594 | `PCWSTR application`, `BOOLEAN relative`, `ULONG cchBuffer`, `PWSTR buffer`, `ULONG *cch` ([below](#chambers)) |
| 20 | `GetCapabilitySids` | 0x100082FC | `PCWSTR capability`, `PWSTR *serviceSid`, `PWSTR *applicationSid` (string SIDs, `LocalFree`) |
| 21 | `GetChamberSid` | 0x1000582C | `HANDLE token`, `ULONG cbSid`, `PSID sid`, `ULONG *cbNeeded`, `BOOLEAN *isAppContainer` |
| 22 | `GetChamberSidEx` | 0x10005A9C | `HANDLE token`, `ULONG cbSid`, `BOOL serviceSid`, `PSID sid`, `ULONG *cbNeeded`, `BOOLEAN *isAppContainer` |
| 23 | `GetChamberSidFromId` | 0x10008140 | `PCWSTR chamberId`, `PWSTR *sid` (string SID, `LocalFree`) |
| 24 | `GetDeveloperUnlockState` | 0x1000D9AC | `DWORD *state`: always sets 1 (unlocked) and returns 0 |
| 25 | `GetInternalApplicationChamberIDs` | 0x100089D8 | `PWSTR buffer` (MULTI_SZ, may be NULL), `DWORD *cch` (in/out) |
| 26 | `GetRpcClientSid` | 0x1000886C | `PWSTR *sid` (string SID of the RPC caller's chamber, `LocalFree`) |
| 27 | `InstallCertificateChain` | 0x1000D510 | `BYTE *cert`, `DWORD cbCert`, `DWORD`, `PCWSTR`, `DWORD` → certificates opnum 4 |
| 28 | `InstallEncryptionCertificate` | 0x1000D630 | `BYTE *cert`, `DWORD cbCert`, `PCWSTR` → certificates opnum 6 |
| 29 | `IsProductionConfiguration` | 0x1000D190 | `BOOL *production` → RPC opnum 6 |
| 30 | `LocalRpcBindingCreateWithSecurity` | 0x1000B5F0 | `RPC_BINDING_HANDLE_TEMPLATE_V1_W *template` (NULL = LRPC), `RPC_BINDING_HANDLE_OPTIONS_V1 *options`, `RPC_IF_HANDLE interface` (optional), `PCWSTR serverName`, `RPC_BINDING_HANDLE *binding` ([below](#local-rpc-security)) |
| 31 | `LocalRpcBindingSetAuthInfoEx` | 0x1000B88C | `RPC_BINDING_HANDLE binding`, `PCWSTR serverName` |
| 32 | `OpenProcessForQuery` | 0x1000C8D0 | `DWORD processId`, `ACCESS_MASK access`, `HANDLE *process` → RPC opnum 2 |
| 33 | `OpenProcessTokenForQuery` | 0x1000CA9C | `DWORD processId`, `HANDLE *token` → RPC opnum 1 |
| 34 | `OpenThreadForQuery` | 0x1000CC58 | `DWORD threadId`, `ACCESS_MASK access`, `HANDLE *thread` → RPC opnum 3 |
| 35 | `QueryChamberExtendedInfo` | 0x10006BD4 | `PCWSTR id`, `DWORD idType`, `DWORD *oemExtensible`, `DWORD *applicationType`, `DWORD *enterpriseId` ([below](#chambers)) |
| 36 | `QueryChamberProperties` | 0x10004748 | `PCWSTR chamberId`, `CHAMBER_PROPERTIES **properties` |
| 37 | `QueryExecutableProperties` | 0x10004454 | `DWORD lookup`, `PCWSTR name`, `DWORD mask`, `EXECUTABLE_PROPERTIES **properties` ([below](#queryexecutableproperties-0x10004454)) |
| 38 | `QueryKernelPrivilegeCache` | 0x1000BB6C | `PCWSTR name`, `BYTE out[8]` ([below](#kernel-privilege-cache)) |
| 39 | `QueryTransientObjectSecurityDescriptor` | 0x10003C20 | `DWORD objectType`, `PCWSTR name`, `PSECURITY_DESCRIPTOR *sd` ([below](#querytransientobjectsecuritydescriptor-0x10003c20)) |
| 40 | `RPCGetDeviceUniqueId` | 0x1000D21C | `BYTE *appData`, `DWORD cbAppData`, `DWORD version`, `BYTE *id`, `DWORD cbId` (≤ 1024), `DWORD *cbWritten` → RPC opnum 7 (like `GetDeviceUniqueID` of Windows CE) |
| 41 | `ReleaseChamberProperties` | 0x10004A00 | `CHAMBER_PROPERTIES *` |
| 42 | `ReleaseExecutableProperties` | 0x10004694 | `EXECUTABLE_PROPERTIES *` |
| 43 | `RpcClientCapabilityCheck` | 0x10008658 | `PCWSTR capability`: S_OK, or `E_ACCESSDENIED` if the RPC caller lacks it |
| 44 | `SetDeveloperUnlockState` | 0x1000D908 | `DWORD state` (0 or 1, else `E_INVALIDARG`): `HKLM\Software\Microsoft\SecurityManager\DeveloperUnlock` `DeveloperUnlockState` (REG_DWORD) |
| 45 | `SetLocalRpcServerInterfaceSecurity` | 0x1000B408 | `RPC_IF_HANDLE interface`, `PCWSTR name` (must end with `\Interface`), `RPC_IF_CALLBACK_FN *callback` |
| 46 | `SetLocalRpcServerProtseqSecurity` | 0x1000B2C0 | (parameters not used) |
| 47 | `UpdateKernelPrivilegeCache` | 0x1000BA78 | `PCWSTR name` ([below](#kernel-privilege-cache)) |
| 48 | `UpdateKernelPrivilegeCacheEx` | 0x1000D024 | `PCWSTR name` → RPC opnum 8 |

There is no global object: every call opens the registry keys or binds to the service again. Errors of the local functions are converted to HRESULT by the RPC-facing exports in the same way as in the client DLLs: 0xC0000109 → 0x8007013D, else `0x80070000 | RtlNtStatusToDosError(status)`, or `status | 0x10000000` when there is no Win32 code.

`GetDeveloperUnlockState` ignores the value written by `SetDeveloperUnlockState` and `CheckPrincipalClassCapabilityAuthorization` grants everything: both are stubs in this build.

### Startup

`DllEntryPoint` (0x1000E110) → `dllmain_dispatch` (0x1000DE1C): CRT initialisation, then `DllMain` (`sub_10009164`): on `DLL_PROCESS_ATTACH` `DisableThreadLibraryCalls` and `EventRegister` of the [ETW](#etw) provider, on `DLL_PROCESS_DETACH` `EventUnregister`. There is no other initialisation.

### Security metastore

All the local functions read the registry with `NtOpenKey(KEY_READ)` on `\REGISTRY\MACHINE\<path>` (`sub_10005CE0`) and `NtQueryValueKey(KeyValuePartialInformation)` into a heap copy (`sub_10005E14`). Keys under `HKLM\Software\Microsoft\SecurityManager\`:

| Key | Values read | Used by |
|-----|-------------|---------|
| `TransientObjects\<escaped name>` | `SecurityDescriptor` | [QueryTransientObjectSecurityDescriptor](#querytransientobjectsecuritydescriptor-0x10003c20) |
| `Capabilities\<capability>` | `ApplicationCapabilitySID`, `ServiceCapabilitySID` | `CapabilityCheck`, `GetCapabilitySids` |
| `Applications\<name>` | `ApplicationType` (DWORD), `ApplicationAccount`, `ApplicationSid`, `ApplicationBinaries`, `RequiredPrivileges`, `RequiredCapabilitySIDs`, `OEMExtensible`; value named after an executable path (data = application name) | [QueryExecutableProperties](#queryexecutableproperties-0x10004454), `GetInternalApplicationChamberIDs` |
| `Applications\<name>\SignerCertificate` | `EnterpriseId`, `ThumbprintCNGHashAlgId`, `Thumbprint`, `SHA1Thumbprint` (20 bytes) | `QueryExecutableProperties` (mask 0x40, 0x80) |
| `Services\<name>` | `ServiceGroup`, `ServiceAccount`, `ServiceSid`, `ServiceExecutablePath`, `RequiredPrivileges`, `OEMExtensible`; executable path values | `QueryExecutableProperties` |
| `ServiceGroups\<name>` | `ServiceAccount`, `ServiceSids`, `ServiceGroupExecutablePath`, `UnionRequiredPrivileges`, `UnionRequiredCapabilitySIDs`; executable path values | `QueryExecutableProperties` |
| `FullTrust\<name>` | `Account`, `FullTrustBinaries`; executable path values | `QueryExecutableProperties` |
| `ServiceAccounts\<account>` | `UserAccountSid`, `UnionRequiredCapabilities` | `QueryExecutableProperties`, `QueryChamberProperties`, `QueryChamberExtendedInfo` |
| `ApplicationAccounts\<account>` | `UserAccountSid` | `QueryExecutableProperties` |
| `CapabilityClasses\` | value `<class>` (MULTI_SZ of capabilities) | `CheckCertificateChainCapabilityAuthorization` |
| `CapabilityClasses\<class>` | `Inheritance` (MULTI_SZ of classes, recursive) | idem (`sub_100099A4`) |
| `AuthorizationRules\Capability\<rule>` | `CapabilityClass`, `PrincipalClass` | idem (`sub_1000718C`, `sub_10006FD0`) |
| `PrincipalClasses\<class>\<certificate>` | `Type` (`Root`, `Intermediate`, `Leaf`), `Eku`, `Alg` (`Sha256`, `Sha384`, `Sha512`), `Thumbprint` | idem |
| `DeveloperUnlock` | `DeveloperUnlockState` (written only) | `SetDeveloperUnlockState` |

The SID lists (`ServiceSids`, `RequiredCapabilitySIDs`, `UnionRequired…`) are a DWORD count followed by `count` entries of a DWORD (?) and a SID (`sub_1000622C`); the privilege lists are a DWORD count followed by `count` entries of 12 bytes whose LUID is at +4 (`sub_100067A8`).

### QueryTransientObjectSecurityDescriptor (0x10003C20)

Gives the security descriptor that a named object must have; the servers set it on their objects and the clients pass it as `ServerSecurityDescriptor` to check the server (see [ReminderEvents.dll](./reminderevents.md#rpc), [ShellChromeAPI.dll](./shellchromeapi.md), [w32time.dll](./w32time.md)).

1. `sub_10003A78(objectType)` gives the prefix (`E_INVALIDARG`-like 0xC000000D for another type):

   | Type | Prefix | Type | Prefix |
   |------|--------|------|--------|
   | 0 | `%5C%5C.%5CMutex%5C` | 7 | `%5C%5C.%5CMailSlot%5C` |
   | 1 | `%5C%5C.%5CEvent%5C` | 8 | `%5C%5C.%5CAlpcPort%5C` |
   | 2 | `%5C%5C.%5CSemaphore%5C` | 9 | `%5C%5C.%5CRpc%5C` |
   | 3 | `%5C%5C.%5CWaitableTimer%5C` | 10 | `%5C%5C.%5CWnf%5C` |
   | 4 | `%5C%5C.%5CJobObject%5C` | 11 | `%5C%5C.%5CTemplate%5C` |
   | 5 | `%5C%5C.%5CFileMapping%5C` | 12 | `%5C%5C.%5CPrivate%5C` |
   | 6 | `%5C%5C.%5CNamedPipe%5C` | | |

2. `sub_10003898(name)`: the name in upper case (`RtlUpcaseUnicodeChar`), each `\` replaced by `%5C`.
3. Reads `HKLM\Software\Microsoft\SecurityManager\TransientObjects\<prefix><name>` value `SecurityDescriptor` and returns the heap copy (to free with `FreeTransientObjectSecurityDescriptor`). For example `(9, L"LaunchAppSvc\Server")` reads the key `%5C%5C.%5CRpc%5CLAUNCHAPPSVC%5CSERVER`, `(8, L"DefaultRpcAccess")` the key `%5C%5C.%5CAlpcPort%5CDEFAULTRPCACCESS`.

### CapabilityCheck (0x10002D30)

1. `E_INVALIDARG`-like 0xC000000D if `capability` or `granted` is NULL. Without token, `sub_10007620`: `NtOpenThreadTokenEx`, or if there is none (0xC000007C) `NtOpenProcessTokenEx` + `NtDuplicateToken` (impersonation).
2. `NtQueryInformationToken(TokenIsAppContainer)` (`sub_10007848`).
3. `Capabilities\<capability>`: `ApplicationCapabilitySID` for an AppContainer token, else `ServiceCapabilitySID` (`sub_10006510`). Missing key or value: the error is returned.
4. AppContainer: `RtlCheckTokenCapability(token, sid, granted)`.
5. Otherwise: granted if the token user is `S-1-5-18` (`sub_10007950`), else `RtlCheckTokenMembership(token, sid)`. If not a member: granted if the token is a member of `S-1-5-21-2702878673-795188819-444038987-1030`, except for `ID_CAP_BUILTIN_TCB` (that group seems to hold every other capability; its name isn't known).

The same check is done in the kernel by [msgpiowinphone.sys](../drivers/msgpiowinphone.md) for `ID_CAP_BUTTONS`.

### QueryExecutableProperties (0x10004454)

Finds a principal of the metastore and returns an `EXECUTABLE_PROPERTIES` (88 bytes, heap) with the fields selected by `mask` (0x1…0x1FF, else 0xC000000D).

`lookup`:
- 0: `name` is a principal name. Tried in this order (`sub_10005FD4`): `Applications\<name>`, `Services\<name>` → its `ServiceGroup` → `ServiceGroups\<group>`, `Services\<name>`, `FullTrust\<name>`.
- 1: `name` is a path, made absolute with `RtlGetFullPathName_UEx` (`sub_10007B20`), then as 2.
- 2: `name` is an executable path, searched as a *value name* in `Applications`, `ServiceGroups`, `Services` and `FullTrust` (`sub_10006584`); the value data is the principal name (its size must be the string length + 4, else 0xC0000001).

Principal kinds (internal +0x08 of the lookup result): 0 = service group, 1 = service, 2 = application, 3 = full trust.

| Offset | Size | Mask | Comment |
|--------|------|------|---------|
| 0x00 | 4 | | Bits of the fields filled |
| 0x04 | 4 | 0x01 | Account name: `ServiceAccount` of the service / group, or the application / `Account` of the full trust principal |
| 0x08 | 4 | 0x02 | Kind: 0 service, 1 application, 2 full trust |
| 0x0C | 4 | 0x02 | Application type: 1 if `ApplicationType` = 0, 3 if 4, 2 otherwise; 0 for the others |
| 0x10 | 4 | 0x04 | `UserAccountSid` of `ServiceAccounts\<account>` (services) or `ApplicationAccounts\<ApplicationAccount>` (applications, full trust: `Account`) |
| 0x14 | 4 | 0x04 | Number of principal SIDs |
| 0x18 | 4 | 0x04 | Principal SIDs: `ServiceSids` (group), `ServiceSid` (service), `ApplicationSid` (application), none (full trust) |
| 0x1C | 4 | 0x08 | Raw value `ServiceGroupExecutablePath` / `ServiceExecutablePath` / `ApplicationBinaries` / `FullTrustBinaries` |
| 0x20 | 4 | 0x10 | Number of privileges |
| 0x24 | 4 | 0x10 | LUIDs of `UnionRequiredPrivileges` (group) / `RequiredPrivileges` (service, application) |
| 0x28 | 4 | 0x20 | Number of capability SIDs |
| 0x2C | 4 | 0x20 | `UnionRequiredCapabilitySIDs` (group), `UnionRequiredCapabilities` of the service account (service), `RequiredCapabilitySIDs` (application) |
| 0x30 | 4 | 0x40 | `EnterpriseId` of `SignerCertificate` (applications of type 2 or 3 only) |
| 0x34 | 4 | 0x80 | `ThumbprintCNGHashAlgId` (pointer to the value) |
| 0x38 | 4 | 0x80 | `Thumbprint` (pointer) |
| 0x3C | 4 | 0x80 | Size of `Thumbprint` |
| 0x40 | 20 | 0x80 | `SHA1Thumbprint` |
| 0x54 | 4 | 0x100 | `OEMExtensible` (applications, services); for a group, 1 if one of its services has it ([QueryChamberExtendedInfo](#chambers)) |

For a full trust principal, missing privileges / capabilities aren't an error; a missing `SignerCertificate` or `OEMExtensible` isn't either.

### Chambers

`QueryChamberProperties(id, &p)`: `QueryExecutableProperties(0, id, 4)`; `CHAMBER_PROPERTIES` (8 bytes) = `{ PSID userAccountSid; PSID applicationSid; }`, the second only for an application. If `id` isn't a principal, `ServiceAccounts\<id>` `UserAccountSid` is used instead (`sub_10006990`).

`GetChamberSidFromId(id, &sid)`: string SID of the application SID, else of the account SID: for example `GetChamberSidFromId(L"Alarms")` in [AlarmsSettingHandler.dll](./alarmssettinghandler.md).

`GetChamberSid(token, cb, sid, &cbNeeded, &isAppContainer)`: the AppContainer SID (`TokenAppContainerSid`) of an AppContainer token, else the token user (`sub_10007DB0`). The buffer must be at least 48 bytes (0xC0000023, `cbNeeded` = 48 or the SID length). `GetChamberSidEx` with `serviceSid` = TRUE, for a non-AppContainer token whose user is the `DefApps` account (`LookupAccountNameLocalW`), returns instead the first group SID of the token of the form `S-1-5-80-…` (the service SID, `sub_10008C04`). `GetRpcClientSid` uses it on the token of the RPC caller (`RpcImpersonateClient`, `OpenThreadToken`): it's the "application ID" of [BtServ.dll](./btserv.md).

`GetApplicationBNOPrefixPath(app, relative, cch, buffer, &cchNeeded)`: `QueryExecutableProperties(0, app, 4)`, needs exactly one principal SID (else 0xC00000E5), then `RtlGetAppContainerNamedObjectPath(NULL, sid, relative)`: the `\Sessions\…\AppContainerNamedObjects\<sid>` directory of the application, 0xC0000023 if `buffer` is too small.

`QueryChamberExtendedInfo(id, idType, &oem, &appType, &enterpriseId)`:
- `idType` 0: `id` is an executable path, `QueryExecutableProperties(2, id, 0x142)`: `oem` = +0x54, `appType` = +0x0C, `enterpriseId` = +0x30 (−1 if absent);
- 1: `id` is an account SID string. `S-1-5-18`, `S-1-5-19` and `S-1-5-20` are skipped (?); the `ServiceAccounts` key whose `UserAccountSid` matches is found by enumeration, and `oem` = 1 if a service of a group running under this account has `OEMExtensible` ≠ 0 (`sub_100069DC`); 0xC0000034 if none;
- 2: everything 0, `enterpriseId` = −1.

`GetInternalApplicationChamberIDs(buffer, &cch)`: the names of the `Applications` subkeys whose `ApplicationType` is 0, as a MULTI_SZ; `cch` returns the needed size, 0x8007007A (`ERROR_INSUFFICIENT_BUFFER`) when `buffer` is too small.

### BuildSecurityDescriptorForSharingAccessEx (0x10005068)

Builds a self-relative security descriptor that lets the principal of `targetToken` use an object of the principal of `ownerToken` (NULL = current process), e.g. a named pipe in [pacmanserver.dll](./pacmanserver.md#notifications).
1. User and AppContainer SIDs of both tokens (`sub_10007DB0`). If they are the same principal, no descriptor is built (`*sd` stays NULL).
2. If `labelPolicy` ≠ 0: mandatory label = the lower integrity level of the two tokens (`TokenIntegrityLevel`, `sub_10004E84`), SACL with `RtlAddMandatoryAce(…, S-1-16-<level>, SYSTEM_MANDATORY_LABEL_ACE_TYPE, labelPolicy)`.
3. `sub_10004A78`: DACL with `GENERIC_ALL` for the owner user, the owner AppContainer SID and `S-1-5-18`, and `access` for the target user (if it's neither the owner nor SYSTEM) and the target AppContainer SID; owner = owner user. Returned in a heap block.

### CheckCertificateChainCapabilityAuthorization (0x1000A3C4)

Decides if a certificate chain (application signer) can have a capability:
1. The capability classes of the capability, with their `Inheritance` classes (`sub_10009D50`, `sub_100099A4`, kept in a `std::list`).
2. For each class, the `AuthorizationRules\Capability` rules with this `CapabilityClass`, and their `PrincipalClass` certificates (`sub_1000718C`: entries of 20 bytes, type / EKU / algorithm / thumbprint).
3. `sub_10009734`: for each certificate entry, takes the root (last element), the intermediate (second) or the leaf (first) of the simple chain; if `Eku` is set, the certificate must have this EKU OID (`CertGetEnhancedKeyUsage`, `sub_10009474`); if `Thumbprint` is set, `CryptHashCertificate2(SHA256 / SHA384 / SHA512)` of the certificate must be equal (`sub_100091DC`). One matching entry authorises.

The exact layout of the capability list parameter isn't known.

### CreateProcessInChamberEx (0x1000BC64)

`(PCWSTR p1, PCWSTR p2, PCWSTR applicationName, ULONGLONG p4, PWSTR commandLine, DWORD p6, DWORD creationFlags, PCWSTR currentDirectory, STARTUPINFOW *si, PROCESS_INFORMATION *pi)`:
1. `E_INVALIDARG` if both `applicationName` and `commandLine` are NULL, if `creationFlags` has `EXTENDED_STARTUPINFO_PRESENT` (0x80000), or if `si` / `pi` is NULL.
2. Without `currentDirectory`, the current directory of the caller (`GetCurrentDirectoryW`).
3. `sub_1000C62C`: RPC opnum 0 with all the parameters (`si` copied, 0x44 bytes) and copies the 16-byte `PROCESS_INFORMATION` returned (the handles are opened in the caller by the service ?).

`p1` / `p2` are passed NULL by [ShellChrome.dll](./shellchrome.md#alarms_noui-command-lines) (chamber / account to use ?).

### Local RPC security

These exports let a server and its clients use the security descriptors of the metastore:
- `SetLocalRpcServerProtseqSecurity`: `RpcServerUseProtseqW(L"ncalrpc", RPC_C_PROTSEQ_MAX_REQS_DEFAULT, sd)` with `sd` = `QueryTransientObjectSecurityDescriptor(8, L"DefaultRpcAccess")`.
- `SetLocalRpcServerInterfaceSecurity(if, name, callback)`: `name` must end with `\Interface` (case-insensitive, else 0x80070490 `ERROR_NOT_FOUND`); `RpcServerRegisterIf3(if, NULL, NULL, RPC_IF_AUTOLISTEN | RPC_IF_ALLOW_SECURE_ONLY | RPC_IF_ALLOW_LOCAL_ONLY, 1234, …, callback, sd)` with `sd` = `QueryTransientObjectSecurityDescriptor(9, name)`.
- `LocalRpcBindingSetAuthInfoEx(binding, name)`: `name` must end with `\Server`; `RpcBindingSetAuthInfoExW(binding, NULL, RPC_C_AUTHN_LEVEL_PKT_PRIVACY, RPC_C_AUTHN_WINNT, NULL, 0, &qos)`, QoS version 5, `RPC_C_IMP_LEVEL_IDENTIFY`, `ServerSecurityDescriptor` = `QueryTransientObjectSecurityDescriptor(9, name)`.
- `LocalRpcBindingCreateWithSecurity(template, options, if, name, &binding)`: same check of `name`, `RpcBindingCreateW` with the given template (or LRPC, no endpoint), the security of the [RPC](#rpc) client below except a static identity tracking (`RPC_C_QOS_IDENTITY_STATIC`), then `RpcBindingBind(NULL, binding, if)` if `if` isn't NULL.

### Kernel privilege cache

Both functions open `\\.\SecMgr` (`CreateFileW(GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, OPEN_EXISTING)`); `name` is at most 260 characters with the NUL. On failure they return 0xC00000E5.

| Function | IOCTL | Input | Output |
|----------|-------|-------|--------|
| `UpdateKernelPrivilegeCache` | 0x0022E050 (device 0x22, function 0x814, `METHOD_BUFFERED`, `FILE_READ_ACCESS \| FILE_WRITE_ACCESS`) | `name` with its NUL | none |
| `QueryKernelPrivilegeCache` | 0x00226054 (device 0x22, function 0x815, `METHOD_BUFFERED`, `FILE_READ_ACCESS`) | `name` with its NUL | 8 bytes |

What `name` designates (principal or executable ?) and the meaning of the 8 bytes depend on the driver, not analysed. `UpdateKernelPrivilegeCacheEx` asks the service instead (RPC opnum 8).

### RPC

The four client interfaces have no endpoint (endpoint mapper) and share the binding function `sub_1000C334(interface, &binding)`:
1. `QueryTransientObjectSecurityDescriptor(9, L"LaunchAppSvc\Server", &sd)`, errors converted as above.
2. `RpcBindingCreateW(&template, &security, NULL, &binding)`: template version 1, flags 0, protocol sequence 3 (`RPC_PROTSEQ_LRPC`), no address, no endpoint; security version 1, authentication level 6 (`RPC_C_AUTHN_LEVEL_PKT_PRIVACY`), service 10 (`RPC_C_AUTHN_WINNT`), QoS version 5 with `RPC_C_QOS_IDENTITY_DYNAMIC`, `RPC_C_IMP_LEVEL_IDENTIFY` and `ServerSecurityDescriptor = sd`.
3. `RpcBindingBind(NULL, binding, interface)`. On 1722 (`RPC_S_SERVER_UNAVAILABLE`), 1708 (`RPC_S_NO_ENDPOINT_FOUND`), 1717 (`RPC_S_UNKNOWN_IF`) or 1753 (`EPT_S_NOT_REGISTERED`), `sub_1000BF94` starts the service and the bind is tried once more: `OpenSCManagerW(NULL, NULL, SC_MANAGER_CONNECT)`, `OpenServiceW(L"LaunchAppSvc", SERVICE_QUERY_STATUS | SERVICE_START)`, `StartServiceW` (1056 `ERROR_SERVICE_ALREADY_RUNNING` is fine), then `QueryServiceStatus` every 500 ms, up to 11 times, until `SERVICE_RUNNING` (`SERVICE_STOPPED` returns its `dwWin32ExitCode`).

`ChangeServiceStartupConfig` does step 1 itself before binding. The handles returned by opnums 1–4 are values of the caller's process (closed by the client on error).

Interface `{88154930-A697-4717-A8A1-21C3263846BB}` version 0.0 (client interface at 0x10001D20, stub descriptor 0x10002288):

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `sub_1000C62C` | `CreateProcessInChamberEx` | `[in,unique] wchar_t *` ×3, `[in] hyper`, `[in,out,unique] wchar_t *commandLine`, `[in] long` ×2, `[in,unique] wchar_t *currentDirectory`, `[in,ref] STARTUPINFOW` (0x44-byte struct with 3 string pointers), `[out,ref] PROCESS_INFORMATION` (4 longs) | Create the process in the chamber |
| 1 | `OpenProcessTokenForQuery` | export | `[in] long processId`, `[out] long *token` | Token of another process |
| 2 | `OpenProcessForQuery` | export | `[in] long processId`, `[in] long access`, `[out] long *process` | Handle of another process |
| 3 | `OpenThreadForQuery` | export | `[in] long threadId`, `[in] long access`, `[out] long *thread` | Handle of another thread |
| 4 | `CreateTokenFromChamberSidEx` | export, `CreateTokenFromChamberSid` | `[in,unique] wchar_t *sid`, `[in] long`, `[in] long`, `[out] long *token` | Token of a chamber (used with `SetThreadToken` by [AlarmsSettingHandler.dll](./alarmssettinghandler.md#applysetting-sub_10006f88)) |
| 6 | `IsProductionConfiguration` | export | `[out] long *` | Production / non-production device |
| 7 | `RPCGetDeviceUniqueId` | export | `[in,unique,size_is(cbAppData)] byte *`, `[in] long cbAppData`, `[in] long version`, `[out,size_is(cbId)] byte *`, `[in,range(0,1024)] long cbId`, `[out] long *` | Device unique ID |
| 8 | `UpdateKernelPrivilegeCacheEx` | export | `[in,unique] wchar_t *` | Update of the kernel privilege cache |

Opnum 5 isn't used.

Interface `{50B44AD4-6640-435D-93A2-E5F62DF44600}` version 0.0 (client interface at 0x10002320, stub descriptor 0x10002368), certificates:

| Opnum | Stub | Parameters |
|-------|------|------------|
| 0 | `AddSubjectCertificateToStore` | `[in,ref,size_is(cb)] byte *`, `[in] long cb`, `[in,unique] wchar_t *`, `[in] long` |
| 1 | `AddSubjectCertificateToEnrollmentNeededAccountStores` | same |
| 2 | `DeleteSubjectCertificateFromStore` | same |
| 3 | `DeleteSubjectCertificateFromEnrollmentNeededAccountStores` | `[in,unique] wchar_t *`, `[in] long` |
| 4 | `InstallCertificateChain` | `[in,ref,size_is(cb)] byte *`, `[in] long cb`, `[in] long`, `[in,unique] wchar_t *`, `[in] long` |
| 5 | `DeleteCertificateChain` | `[in,ref,size_is(cb)] byte *`, `[in] long cb` |
| 6 | `InstallEncryptionCertificate` | `[in,ref,size_is(cb)] byte *`, `[in] long cb`, `[in,unique] wchar_t *` |

Interface `{0D3603EC-0912-4A10-A0DD-6F6CFA9F5D22}` version 0.0 (client interface at 0x100023B8, stub descriptor 0x10002478): opnum 0 `ChangeServiceStartupConfig` (`[in,unique] wchar_t *`, `[in] long`).

Interface `{024D770A-0E1C-44EB-BF13-365E229D809B}` version 0.0 (client interface at 0x100022D8, stub descriptor 0x10002428), smart-card device nodes: opnum 0 `CreateSCardDevInfoNode`, opnum 1 `DestroySCardDevInfoNode` (`[in,unique] wchar_t *`, `[in] long`).

Every procedure returns a `long` (HRESULT), the binding is an explicit primitive handle.

### ETW

Provider `{BE48C7AB-DB3B-43B9-A338-10E3C66ACE1A}`, registered in `DllMain` (`McGenEventRegister`, context `unk_10010010`, enable callback `ETW_EnableCallback` 0x10009018). The events are written by `sub_100032A8` with a self-describing payload (module name from `GetModuleFileNameA`, then the typed arguments of the call); all have version 0, channel 0, level 0, opcode 0, task 0. The enable bit is tested against the match-any / match-all keywords (`dword_10010020`, `dword_10010028`).

| Event | Keyword | Enable bit | Written when |
|-------|---------|------------|--------------|
| 1 | 0x1 | 0x01 | Error (NTSTATUS / HRESULT of a failed step) |
| 3 | 0x8 | 0x08 | Entry and exit of the exports, with their parameters and result |
| 4 | 0x10 | 0x10 | Information (fallbacks: missing optional values, service start…) |
| 5 | 0x2 | 0x02 | Start and end of `CreateProcessInChamberEx`, of the binding and of the service start |

### Named objects and services

| Name | Use |
|------|-----|
| `LaunchAppSvc` | Service started on demand, server of the 4 interfaces |
| `LaunchAppSvc\Server` | Transient object name (type 9) of its security descriptor |
| `DefaultRpcAccess` | Transient object name (type 8) of the `ncalrpc` protocol sequence of the servers |
| `DefApps` | Account of the services whose service SID is returned by `GetChamberSidEx` |
| `\\.\SecMgr` | Device of the kernel privilege cache |
