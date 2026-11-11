## MSV1_0.DLL

The MSV1_0 authentication package of the LSA: local SAM logons, the NTLM security package (`NTLM`) and the cache of domain logons.  
`MSV1_0.DLL` is the desktop Windows 8.1 package built for ARM (360 480 bytes, 693 functions, public symbols). The code is the same as on the desktop: it's loaded in the LSA process (`lsass.exe`, started by [WININIT.EXE](../applications/wininit.md)), gives the LSA its function tables (`SpLsaModeInitialize`, `SpUserModeInitialize`), validates the passwords of the SAM accounts (local logons, `LsaApLogonUserEx2`), runs the NTLM challenge/response protocol (NTLMv1, NTLMv2, LM, session security with RC4 / HMAC-MD5), keeps the logon cache of domain users under `HKLM\Security\Cache`, and serves the `MSV1_0_PROTOCOL_MESSAGE_TYPE` requests of `LsaCallAuthenticationPackage`. It also has the domain code (Netlogon pass-through, password change on a domain controller, gMSA), which is useless on a phone. No phone-specific code was found: the only Windows 8.1-specific part is the "connected user" mapping of a Microsoft account to a local account (`MsvpMapConnectedUserLogon`, through the identity provider API).  
It relies on LSASRV.dll (the `LsaI*` / `Lsar*` internals of the LSA), SAMSRV.dll (the in-process SAM, `SamI*` / `Samr*`), cryptdll.dll and CRYPTSP.dll (`SystemFunction00x`: OWF and DES/RC4 helpers). Almost all of these are delay-loaded. Neither the LSA process nor its other packages are documented here; the RPC server through which the client processes reach the packages is [SSPISRV.DLL](./sspisrv.md).

Location on the phone: `C:\Windows\System32\msv1_0.dll` ? (the name of the module is `msv1_0.dll`, and `SpGetExtendedInformation` gives `%SystemRoot%\SysWOW64\msv1_0.DLL` as the WOW64 path).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `RtlInitializeGenericTable`, `RtlInsertElementGenericTable`, `RtlLookupElementGenericTable`, `RtlDeleteElementGenericTable`, `RtlAvlInsertNodeEx`, `RtlAvlRemoveNode`, `RtlInitializeResource`, `RtlAcquireResourceShared`/`Exclusive`, `RtlReleaseResource`, `RtlConvertSharedToExclusive`, `RtlInitializeCriticalSection`, SID functions (`RtlAllocateAndInitializeSid`, `RtlCopySid`, `RtlEqualSid`, `RtlCreateServiceSid`, …), string functions (`RtlEqualUnicodeString`, `RtlUpcaseUnicodeStringToOemString`, `RtlEqualDomainName`, `RtlRunDecodeUnicodeString`, `RtlEraseUnicodeString`, …), `RtlCheckTokenMembershipEx`, `RtlIpv6StringToAddressExW`, `NtOpenKey`, `NtCreateKey`, `NtQueryValueKey`, `NtSetValueKey`, `NtDeleteValueKey`, `NtCreateEvent`, `NtOpenEvent`, `NtSetEvent`, `NtWaitForSingleObject`, `NtOpenProcess`, `NtOpenProcessToken`, `NtOpenThreadToken`, `NtDuplicateToken`, `NtFilterToken`, `NtQueryInformationToken`, `NtSetInformationThread`, `NtDuplicateObject`, `NtSetSecurityObject`, `NtQuerySystemInformation`, `NtQuerySystemTime`, `NtAllocateLocallyUniqueId`, `EtwEventRegister`, `EtwEventWrite`, `EtwEventEnabled`, `EtwEventUnregister`, `EtwRegisterTraceGuidsW`, `EtwTraceMessage`, `EtwLogTraceEvent`, `WinSqmIncrementDWORD`, `WinSqmSetDWORD`, … |
| [LSASRV.dll](#lsa-internals) (delay-load) | 41 functions: `LsaIAuditLogonEx`, `LsaIAuditAccountLogonEx`, `LsaISetLogonInfo`, `LsaIAddCredentialKeys`, `LsaIGetSupplementalTokenInfo`, `LsaICallPackagePassthrough`, `LsaIRegisterNotification`, `LsaIRegisterPolicyChangeNotificationCallback`, `LsaIOpenPolicyTrusted`, `LsarQueryInformationPolicy`, `LsarOpenSecret`, `LsarQuerySecret`, `LsarSetSecret`, `LsarCreateSecret`, `LsarLookupSids`, `LsaINotifyPasswordChanged`, `LsaIEventWritePackageNoCredential`, … |
| SAMSRV.dll (delay-load) | `SamIConnect`, `SamrOpenDomain`, `SamrQueryInformationDomain`, `SamIGetUserLogonInformationEx`, `SamIGetUserLogonInformation2`, `SamIAccountRestrictions`, `SamIUpdateLogonStatistics`, `SamrSetInformationUser`, `SamIUPNFromUserHandle`, `SamrCloseHandle`, `SamIFree*` |
| SAMLIB.dll (delay-load) | `SamConnect`, `SamOpenDomain`, `SamQueryInformationDomain`, `SamChangePasswordUser2`, `SamFreeMemory`, `SamCloseHandle` |
| NETLOGON.dll (delay-load) | `NetILogonSamLogon`, `I_NetLogonMixedDomain` |
| NTDSA.dll (delay-load) | `GetConfigurationInfo` |
| cryptdll.dll | `CDLocateCheckSum`, `PBKDF2`, `HMACwithSHA`, `aesCTSEncryptMsg`, `aesCTSDecryptMsg` |
| CRYPTSP.dll (delay-load) | `SystemFunction006`, `007`, `008`, `009`, `011`, `027` (LM/NT OWF, challenge responses) |
| CRYPTBASE.dll (delay-load) | `SystemFunction036` (`RtlGenRandom`) |
| CRYPT32.dll (delay-load) | `CryptProtectData` |
| SspiCli.dll (delay-load) | `SspiUnmarshalAuthIdentity`, `SspiValidateAuthIdentity`, `SspiDecryptAuthIdentityEx`, `SspiPrepareForCredRead`, `SspiFreeAuthIdentity`, `SspiLocalFree`, `CredMarshalTargetInfo`, `CredUnmarshalTargetInfo`, `QuerySecurityPackageInfoW`, `FreeContextBuffer`, `GetUserNameExW`, `LsaGetLogonSessionData`, `LsaFreeReturnBuffer` |
| api-ms-win-security-credentials-l1-1-0 / l2-1-0 (delay-load) | `CredIsProtectedW`, `CredUnprotectW`, `CredUnmarshalCredentialW`, `CredFree`, `CredParseUserNameWithType` |
| api-ms-win-security-lsapolicy-l1-1-0 (delay-load) | `LsaOpenPolicy`, `LsaQueryInformationPolicy`, `LsaFreeMemory`, `LsaClose` |
| api-ms-win-security-lsalookup-l1-1-1 (delay-load) | `GetDefaultIdentityProvider`, `GetIdentityProviderInfoByName` |
| api-ms-win-security-activedirectoryclient-l1-1-0 | `DsBindWithSpnExW`, `DsCrackNamesW`, `DsFreeNameResultW`, `DsUnBindW` |
| logoncli.dll (delay-load) | `DsGetDcNameW` |
| netutils.dll (delay-load) | `NetRemoteComputerSupports`, `NetApiBufferFree` |
| DSPARSE.dll (delay-load) | `DsMakeSpnW` |
| DNSAPI.dll (delay-load) | `DnsNameCompare_W` |
| WS2_32.dll (delay-load) | `WSAStartup`, `WSAGetLastError`, `GetAddrInfoW`, `FreeAddrInfoW` |
| IPHLPAPI.DLL (delay-load) | `GetAdaptersAddresses` |
| api-ms-win-service-management-l1-1-0 / l2-1-0, api-ms-win-service-winsvc-l1-2-0 (delay-load) | `OpenSCManagerW`, `OpenServiceW`, `QueryServiceConfigW`, `QueryServiceStatus`, `CloseServiceHandle` |
| api-ms-win-eventlog-legacy-l1-1-0 (delay-load) | `RegisterEventSourceW`, `ReportEventW`, `DeregisterEventSource` |
| api-ms-win-base-util-l1-1-0 (delay-load) | `IsTextUnicode` |
| api-ms-win-security-base-l1-2-0 | `CheckTokenMembership`, `GetTokenInformation`, `AdjustTokenPrivileges`, `ImpersonateAnonymousToken`, `RevertToSelf`, `EqualSid`, `GetLengthSid` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegOpenKeyExA`, `RegQueryValueExW`, `RegQueryValueExA`, `RegSetValueExW`, `RegDeleteValueW`, `RegNotifyChangeKeyValue`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `LoadLibraryExA`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-file-l1-2-1, l2-1-1 | `CreateFileW`, `WriteFile`, `SetFilePointer`, `FlushFileBuffers`, `CreateDirectoryW`, `CompareFileTime`, `MoveFileExW` |
| api-ms-win-core-memory-l1-1-2 | `CreateFileMappingW`, `OpenFileMappingW`, `MapViewOfFileEx`, `UnmapViewOfFile`, `VirtualAlloc`, `VirtualProtect`, `VirtualQuery` |
| api-ms-win-eventing-controller-l1-1-0 | `StartTraceW`, `ControlTraceW`, `EnableTraceEx2` |
| api-ms-win-core-sysinfo-l1-2-2 | `GetComputerNameExW`, `GetVersionExW`, `GetSystemInfo`, `GetWindowsDirectoryW`, `GetSystemDirectoryW`, `GetSystemTimeAsFileTime`, `GetLocalTime`, `GetTickCount` |
| api-ms-win-core-threadpool-legacy-l1-1-0, …-private-l1-1-0 | `CreateTimerQueueTimer`, `ChangeTimerQueueTimer`, `DeleteTimerQueueTimer`, `RegisterWaitForSingleObjectEx`, `UnregisterWaitEx` |
| api-ms-win-core-psapi-l1-1-0 | `QueryFullProcessImageNameW` |
| api-ms-win-core-privateprofile-l1-1-1 | `GetProfileIntW` |
| others | processthreads (`OpenProcess`, `SetThreadToken`, `GetCurrentProcessId`, …), synch, handle, heap-obsolete (`LocalAlloc`/`LocalFree`), localization (`FormatMessageW`/`A`), processenvironment (`ExpandEnvironmentStringsW`, `Get`/`SetCurrentDirectoryW`), debug, errorhandling |
| msvcrt.dll | `malloc`, `free`, `memcpy`, `memset`, `wcs*`/`str*` safe string functions, `_snwprintf_s`, `_vsnprintf_s`, `_initterm`, `__C_specific_handler`, … |

The msvcrt, rtlsupport (`RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`), debug, errorhandling (except `GetLastError`/`SetLastError`), `TerminateProcess`, `SetThreadStackGuarantee` and delayload imports are the Visual C++ DLL CRT startup, SEH, `/GS` cookie and delay-load helper code. The `Etw*TraceGuids`/`EtwTraceMessage`, eventing-controller, file-mapping, `MoveFileExW`/`CreateDirectoryW` and version imports are the WPP / debug tracing ([ETW](#etw)). The Netlogon, NTDSA, logoncli, DSPARSE, DNSAPI, activedirectoryclient and service-management imports are used only by the domain code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `netlogon.dll` | `LoadLibraryExA("netlogon")` (`NlInitialize`) | Module handle kept for the sub-authentication code (the DLL is also delay-loaded for `NetILogonSamLogon`) |
| Sub-authentication DLLs | `LoadLibraryExA` of the name in the registry value `Auth<n>` ([ReferenceSubAuth](#sub-authentication)), `GetProcAddress` of `Msv1_0SubAuthenticationRoutine`, `Msv1_0SubAuthenticationRoutineEx`, `Msv1_0SubAuthenticationRoutineGeneric`, `Msv1_0SubAuthenticationFilter` | Optional third-party password checks; none is known on the phone |
| `samlib.dll` | `LoadLibraryExW` (`MspChangePasswordSam`) | Password change on a remote SAM (also delay-loaded) |
| `rpcrt4.dll` | `LoadLibraryExW` + `GetProcAddress("I_RpcMapWin32Status")` | Maps the RPC errors of the password change |
| `ntdll.dll` | `LoadLibraryExW` (`MsvpReportEntryDeletedEvent`) | Message table for `FormatMessageW` (text of an NTSTATUS in an event) |
| `<system directory>\version.dll` | `LoadLibraryExW` + `GetFileVersionInfoSizeW`, `GetFileVersionInfoW`, `VerQueryValueW` (`_DbgpGetFileVersionString`) | File version written in the name of the debug trace file |
| `%windir%\debug\PASSWD.LOG` | `CreateFileW(GENERIC_WRITE, share read/write, CREATE_ALWAYS)` then `SetFilePointer(FILE_END)` (`MsvPaswdInitializeLog`, called by `LsaApInitializePackage`) | Log of the password changes (`MspIChangePassword`, `MspChangePasswordSam`): lines `"%02u/%02u %02u:%02u:%02u "` + message. `PASSWD.BAK` is built next to it but not used |
| `%windir%\tracing\…\<…>.etl` | `CreateDirectoryW`, `StartTraceW`, `MoveFileExW` (`_DbgpControlTracing`) | Debug trace session, file name `%s_%wZ_%d_%d_%d_%d_%d_%d_%s_%x_%s.etl` (module, computer, version…) |
| `%SystemRoot%\SysWOW64\msv1_0.DLL` | Only returned by `SpGetExtendedInformation(SecpkgWowClientDll)` | WOW64 client DLL path, irrelevant on ARM |

No process is started and no COM server is used.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `SpInitialize` | 0x4D119DE8 | `ULONG_PTR PackageId, PSECPKG_PARAMETERS, PLSA_SECPKG_FUNCTION_TABLE` |
| 3 | `SpLsaModeInitialize` | 0x4D11BF28 | `ULONG LsaVersion, PULONG PackageVersion, PSECPKG_FUNCTION_TABLE *Tables, PULONG TableCount` |
| 4 | `SpUserModeInitialize` | 0x4D119BA0 | `ULONG LsaVersion, PULONG PackageVersion, PSECPKG_USER_FUNCTION_TABLE *Tables, PULONG TableCount` |
| 32 | `SpInstanceInit` | 0x4D119A34 | `ULONG Version, PSECPKG_DLL_FUNCTIONS, PVOID *UserFunctions` |
| 9 | `LsaApInitializePackage` | 0x4D11A640 | `ULONG AuthenticationPackageId, PLSA_DISPATCH_TABLE, PLSA_STRING Database, PLSA_STRING Confidentiality, PLSA_STRING *AuthenticationPackageName` |
| 11 | `LsaApLogonUserEx2` | 0x4D104944 | standard `LSA_AP_LOGON_USER_EX2` |
| 10 | `LsaApLogonTerminated` | 0x4D110E0C | `PLUID LogonId` |
| 6 | `LsaApCallPackage` | 0x4D118A94 | `PLSA_CLIENT_REQUEST, PVOID ProtocolSubmitBuffer, PVOID ClientBufferBase, ULONG SubmitBufferLength, PVOID *ProtocolReturnBuffer, PULONG ReturnBufferLength, PNTSTATUS ProtocolStatus` |
| 8 | `LsaApCallPackageUntrusted` | 0x4D1197E8 | same as `LsaApCallPackage` |
| 7 | `LsaApCallPackagePassthrough` | 0x4D13C7D0 | same as `LsaApCallPackage` |
| 16 | `MsvSamValidate` | 0x4D103498 | `SAMPR_HANDLE DomainHandle, BOOLEAN UasCompatibility, NETLOGON_SECURE_CHANNEL_TYPE, PUNICODE_STRING LogonServer, PUNICODE_STRING LogonDomainName, PSID LogonDomainId, NETLOGON_LOGON_INFO_CLASS, PVOID LogonInformation, NETLOGON_VALIDATION_INFO_CLASS, PVOID *ValidationInformation, PBOOLEAN Authoritative, PBOOLEAN BadPasswordCountZeroed, DWORD AccountsToCheck` (desktop prototype; 13 arguments read) |
| 15 | `MsvSamLogoff` | 0x4D11E07C | `SAMPR_HANDLE DomainHandle, NETLOGON_LOGON_INFO_CLASS, PVOID LogonInformation` |
| 17 | `MsvValidateTarget` | 0x4D13F360 | `?, ULONG InfoClass (only 2 accepted), PVOID Info` (checks the target info of an authenticate message; the rest is unknown) |
| 14 | `MsvGetLogonAttemptCount` | 0x4D13BD48 | none: returns `NlpLogonAttemptCount` |
| 2 | `MsvIsLocalhostAliases` | 0x4D10E200 | `PUNICODE_STRING Name`: `TRUE` if the name is in `BackConnectionHostNames` or in the ephemeral host table (case-insensitive) |
| 12 | `Msv1_0ExportSubAuthenticationRoutine` | 0x4D144800 | `NETLOGON_LOGON_INFO_CLASS, PVOID LogonInformation, ULONG Flags, ULONG DllNumber, PUSER_ALL_INFORMATION, PULONG WhichFields, PULONG UserFlags, PBOOLEAN Authoritative, PLARGE_INTEGER LogoffTime, PLARGE_INTEGER KickoffTime`: calls the `Msv1_0SubAuthenticationRoutine` of DLL `DllNumber` (0xC000007A if it has none) |
| 13 | `Msv1_0SubAuthenticationPresent` | 0x4D14487C | `ULONG DllNumber`: `TRUE` if the sub-authentication DLL can be loaded |
| 5 | `DllMain` | 0x4D14202C | standard |

The LSA uses the tables returned by `SpLsaModeInitialize` (in LSA mode) and `SpUserModeInitialize` (in the client processes, for signing and sealing once a context is exported):

- `NtLmFunctionTable` (0x4D14CB80), package version 0x200000 (`SECPKG_INTERFACE_VERSION`…): `LsaApInitializePackage` = NULL (called from `SpInitialize`), `LsaApLogonUser` = NULL, `LsaApCallPackage`, `LsaApLogonTerminated`, `LsaApCallPackageUntrusted`, `LsaApCallPackagePassthrough`, `LogonUserEx` = NULL, `LsaApLogonUserEx2`, `SpInitialize`, `SpShutdown`, `SpGetInfo`, `SpAcceptCredentials`, `SpAcquireCredentialsHandle`, `SpQueryCredentialsAttributes`, `SpFreeCredentialsHandle`, (save/get/delete credentials = NULL), `SpInitLsaModeContext`, `SpAcceptLsaModeContext`, `SpDeleteContext`, `SpApplyControlToken`, (get user info = NULL), `SpGetExtendedInformation`, `SpQueryLsaModeContextAttributes`, (`AddCredentials` = NULL), `SpSetExtendedInformation`, (`SetContextAttributes`, `SetCredentialsAttributes` = NULL), `SpChangeAccountPassword`, (`QueryMetaData`, `ExchangeMetaData`, `GetCredUIContext`, `UpdateCredentials` = NULL), `SpValidateTargetInfo`. Any LSA version other than 0x10000 is refused with `STATUS_INVALID_PARAMETER`.
- `NtLmUserFunctionTable` (0x4D14CB40), version 0x10000: `SpInstanceInit`, `SpInitUserModeContext`, `SpMakeSignature`, `SpVerifySignature`, `SpSealMessage`, `SpUnsealMessage`, `SpGetContextToken`, `SpQueryContextAttributes`, `SpCompleteAuthToken`, `SpDeleteUserModeContext`, `SpFormatCredentials`, `SpMarshallSupplementalCreds`, `SpExportSecurityContext`, `SpImportSecurityContext`.

`SpGetInfo` describes the package: name `NTLM`, comment `NTLM Security Package`, capabilities 0x00882B37, version 1, RPC id 10 (`RPC_C_AUTHN_WINNT`), maximum token 2888 (0xB48) bytes. `LsaApInitializePackage` returns the authentication package name `MICROSOFT_AUTHENTICATION_PACKAGE_V1_0` (`MSV1_0_PACKAGE_NAME`).

### Startup

`_DllMainCRTStartup` (0x4D11C734): `__security_init_cookie`, CRT init, then `DllMain`.  
`DllMain` (0x4D14202C) calls `DisableThreadLibraryCalls` and `NtLmInitializeDebugging` (→ `WppInitUm`, WPP registration) on `DLL_PROCESS_ATTACH`; on `DLL_PROCESS_DETACH` it calls `SspCleanup` (unless the process is ending) and `NtLmUnloadDebugging`.

### SpInitialize (0x4D119DE8)

Called by the LSA after `SpLsaModeInitialize`:

1. Debug tracing: `_DbgpCreateTraceControl` with the control GUID `{5BBB6C18-AA45-49B1-A15F-085F7ED0AA90}`, the shared memory `Debug.Trace.Memory.<pid>` (`_DbgpOpenOrCreateSharedMem`) and a timer (`CreateTimerQueueTimer`, 180 000 ms) that watches the registry value `NtLmInfoLevel` of `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` (see [ETW](#etw)). Skipped when the process is protected (PEB `BitField` bit 1, `IsProtectedProcess`).
2. `NtLmOpenRegistryKeys`: sets the defaults (LM compatibility level 3, old password allowed for 5 min, minimum client/server security 0x20000000 = 128-bit) and opens `\Registry\Machine\System\CurrentControlSet\Control\Lsa` and `…\Lsa\Msv1_0`.
3. Initialises the locks (global, host table, IP addresses, hosted targets, allowed targets, IP address observer), the loopback context list, the product type (`RtlGetNtProductType`, `GetVersionExW` → personal SKU), a LUID, the package name/SIDs, `LsaIOpenPolicyTrusted`, the NetBIOS and DNS computer names (`GetComputerNameExW`) and the anonymous SID.
4. `SspCredentialInitialize`, `NtLmQueryGlobals` (the [registry values](#registry)), `NtLmSetPolicyInfo` (domain names from the LSA policy), `LsaApInitializePackage`, `NtLmRegisterForPolicyChange` (`LsaIRegisterPolicyChangeNotificationCallback` → `NtLmPolicyChangeCallback`).
5. `SspGenerateRandomBits(NtlmGlobalMagicNumber)`, `WSAStartup`, `SspInitializeChallengeTracking`, the service SID of `CscService` (`NtLmAllocateAndInitializeServiceSid` / `RtlCreateServiceSid`; a caller with this SID is treated specially in the logon code, `RtlCheckTokenMembershipEx`, purpose ?).

On failure it calls `SpShutdown`, which deletes the debug tracing and unregisters the ETW provider.

### LsaApInitializePackage (0x4D11A640)

Once: saves the package id and copies the 240-byte LSA dispatch table, opens `PASSWD.LOG` (`MsvPaswdInitializeLog`, see [Dependencies](#dependencies)), then `NlInitialize`:

1. Constant passwords (`NlInitializeConstantPwds`), computer name (`GetComputerNameExW`, `NlpLanmanInstalled` = 1 if it works).
2. `HKLM\System\CurrentControlSet\Control\SafeBoot\Option` `OptionValue`: if present, safe boot; value 1 (minimal) clears `NlpLanmanInstalled`.
3. Product type (workstation unless `NtProductLanManNt`), active logon list and table, `NlpCacheInitialize`: watches `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon` (`RegNotifyChangeKeyValue` + `RegisterWaitForSingleObjectEx` → `NlpWatchCachedLogonsCountKey`, which resizes the cache when `CachedLogonsCount` changes).
4. `LoadLibraryExA("netlogon")` and `Msv1_0SubAuthenticationInitialization` (empty list of sub-authentication DLLs).

### LsaApCallPackage (0x4D118A94)

The first DWORD of the submit buffer is the `MSV1_0_PROTOCOL_MESSAGE_TYPE`, below 0x14, used as index in `MspCallPackageDispatch` (0x4D1013B8):

| Type | Handler | `MSV1_0_PROTOCOL_MESSAGE_TYPE` |
|------|---------|--------------------------------|
| 0 | `MspLm20Challenge` | `MsV1_0Lm20ChallengeRequest` |
| 1 | `MspLm20GetChallengeResponse` | `MsV1_0Lm20GetChallengeResponse` |
| 2 | `MspLm20EnumUsers` | `MsV1_0EnumerateUsers` |
| 3 | `MspLm20GetUserInfo` | `MsV1_0GetUserInfo` |
| 4 | `MspLm20ReLogonUsers` | `MsV1_0ReLogonUsers` |
| 5, 6 | `MspLm20ChangePassword` | `MsV1_0ChangePassword`, `MsV1_0ChangeCachedPassword` |
| 7 | `MspLm20GenericPassthrough` | `MsV1_0GenericPassthrough` (`NetILogonSamLogon`) |
| 8 | `MspLm20CacheLogon` | `MsV1_0CacheLogon` |
| 9 | `MspNtSubAuth` | `MsV1_0SubAuth` |
| 10 | `MspNtDeriveCredential` | `MsV1_0DeriveCredential` |
| 11, 17 | `MspLm20CacheLookup` | `MsV1_0CacheLookup`, `MsV1_0CacheLookupEx` |
| 12 | `MspSetProcessOption` (handled inline) | `MsV1_0SetProcessOption` |
| 13 | `MspConfigLocalAliases` | `MsV1_0ConfigLocalAliases` |
| 14 | `MspLm20ClearCachedCredentials` | `MsV1_0ClearCachedCredentials` |
| 15 | `MspLookupToken` | `MsV1_0LookupToken` |
| 16 | `MspValidateAuth` | `MsV1_0ValidateAuth` (only for the LSA itself: client request -1, else `STATUS_NOT_SUPPORTED` 0xC00000BB) |
| 18 | `MspGetCredentialKey` | `MsV1_0GetCredentialKey` |
| 19 | `MspSetThreadOption` | `MsV1_0SetThreadOption` |

Type 12 (12 bytes at least: type, options at +4, `DisableOptions` byte at +8) adds or removes options in the entry of the calling process (`GetClientInfo` → process id) of `NtLmProcessOptionsList`, creating the 28-byte entry if needed.  
Other values or a buffer smaller than 4 bytes return `STATUS_INVALID_PARAMETER` (0xC000000D).

`LsaApCallPackageUntrusted` (0x4D1197E8) is used for the callers that aren't logon processes. It dispatches only types 0, 2, 3, 5, 6, 10, 12, 15 and 19; any other type returns `STATUS_ACCESS_DENIED` (0xC0000022). Some of them need the membership of `S-1-5-32-544` (Administrators), checked by `CheckTokenMembership` on the impersonated client:
- 2, 3, 6 (and 13, refused afterwards anyway): always;
- 10: the buffer must be at least 0x18 bytes and the logon id at +4 must be the caller's own (`GetClientInfo`), else access denied; Administrators is required when this logon id is SYSTEM (0x3E7);
- 12, 19: at least 12 bytes; Administrators is required when the options at +4 have bits other than 0x1C.

`LsaApCallPackagePassthrough` (0x4D13C7D0) accepts only types 9 and 16 (`STATUS_ACCESS_DENIED` 0xC0000022 otherwise).

### Sub-authentication

`ReferenceSubAuth` (0x4D11BE0C) looks for DLL number `n` in the list `SubAuthenticationDlls`; if it isn't loaded, it reads the value `Auth<n>` (`RtlIntegerToChar`) of `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0` (or of `…\Lsa\Kerberos` when bit 31 of the number is set), loads this DLL and takes its `Msv1_0SubAuthenticationRoutine`, `…RoutineEx`, `…RoutineGeneric` and `…Filter` entry points. `STATUS_PROCEDURE_NOT_FOUND` (0xC000007A) when there is no DLL. No `Auth<n>` value is known on the phone.

### Logon cache

The cache of domain logons (`NlpInternalCacheInitialize`, on first use):

- Key `\Registry\Machine\Security\Cache` (`NtCreateKey`, `NlpOpenCache`): value `NL$Control` (cache control: revision, number of entries), `NL$IterationCount` (PBKDF2 iterations of the salted hash, `NlpComputeSaltedHashedPassword`), one value `NL$<n>` per entry (`NlpMakeCacheEntryName`).
- The entries are encrypted with the LSA secret `NL$KM` (`LsarOpenSecret` / `LsarCreateSecret`, `NlpCacheKeyInitialize`) using `HMACwithSHA` and `aesCTSEncryptMsg`/`aesCTSDecryptMsg` (cryptdll).
- Size: `GetProfileIntW(L"Winlogon", L"CachedLogonsCount", 10)`, re-read when the Winlogon key changes. `NtLmFlushLogonCache` deletes `NL$Control` from `HKLM\SECURITY\Cache`.

On a phone that is never joined to a domain the cache stays empty.

### Registry

Read by `NtLmQueryGlobals` / `NtLmQueryDynamicGlobals` at start-up and again by `NtLmPolicyChangeCallback`:

| Key | Value | Default | Use |
|-----|-------|---------|-----|
| `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` | `LmCompatibilityLevel` | 3 | LM / NTLM / NTLMv2 responses sent and accepted |
| | `UseMachineId` | 1 | LocalSystem uses the computer account for NTLM |
| | `ForceGuest` | 0 | Network logons mapped to Guest (ignored when domain-joined) |
| | `DisallowMsvChapv2` | 0 | Refuse MS-CHAPv2 sub-auth |
| | `LimitBlankPasswordUse` | 1 | Blank passwords only for console logons |
| | `DisableLoopbackCheck` | 0 | |
| | `DebugBreakIfDebugged` | 0 | |
| | `OldPasswordAllowedPeriod` | 5 (minutes, max 60) | Old password still accepted after a change |
| | `NtLmInfoLevel` | | Debug trace level (`_DbgpCreateTraceControl`) |
| `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0` | `AllowLegacySrvCall`, `SendNt2ResponseOnly` | 0 | |
| | `NtlmMinClientSec`, `NtlmMinServerSec` | 0x20000000 | Minimum session security (mask 0xE0080031: NTLM2, 128-bit, 56-bit, sign, seal) |
| | `BackConnectionHostNames` | | `REG_MULTI_SZ` of local host aliases ([MsvIsLocalhostAliases](#exports)) |
| | `RestrictSendingNTLMTraffic`, `RestrictReceivingNTLMTraffic`, `AuditReceivingNTLMTraffic`, `ClientAllowedNTLMServers` | | NTLM blocking / auditing policy ([ETW](#etw) events 4001…8003) |
| | `NTLMInfoEvent`, `allownullsessionfallback`, `AllowS4UForDomainUsers` | | |
| | `MappedDomain`, `PreferredDomain` | | Domain name substitution (`NlpMapLogonDomain`) |
| | `IPAddressRefreshInterval` | | Refresh of the local IP addresses (`GetAdaptersAddresses`, loopback detection) |
| | `Auth<n>` | | [Sub-authentication](#sub-authentication) DLLs |
| `HKLM\System\CurrentControlSet\Control\SafeBoot\Option` | `OptionValue` | | Safe boot |
| `HKLM\SYSTEM\Setup` | `SystemSetupInProgress` | | `NlDoingSetup` |
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon` | `CachedLogonsCount` (through `GetProfileIntW`) | 10 | [Logon cache](#logon-cache) size |
| `HKLM\Security\Cache` | `NL$Control`, `NL$IterationCount`, `NL$<n>` | | [Logon cache](#logon-cache) |

### LSA internals

Other interfaces with the rest of the LSA:

- LSA secrets: `NL$KM` (cache key), `_SA_{262E99C9-6160-4871-ACEC-4E61736B6F21}` (prefix of the gMSA password secrets, `MsvpGetGMSAPwdHash`).
- `LsaIRegisterNotification(SspIPAddressObserverCallback, …)`: re-reads the IP addresses of the adapters to recognise loopback NTLM.
- Named events waited for: `\SAM_SERVICE_STARTED` (`NlSamInitialize`, up to 1200 s) and `\NETLOGON_SERVICE_STARTED` (`NlWaitForNetlogon`, which also queries the `NETLOGON` service with the service-management API).
- `MsvpMapConnectedUserLogon` (0x4D1455C0): for a logon with a domain name other than the SAM domain, asks `GetDefaultIdentityProvider` / `GetIdentityProviderInfoByName` whether it's an identity provider (Microsoft account). If so, it finds the local account linked to the internet name (`SamIGetUserLogonInformation2`, `user@provider`; user info +0x11C = linked name, +0x13C = flag) and logs on with it; `STATUS_NO_SUCH_USER` becomes 0xC0000225 (`STATUS_NOT_FOUND`).
- Event log: source `LsaSrv` (`NetpEventlogOpen`, duplicate events suppressed for 3 600 000 ms): events 6038/6039 (NTLM usage warning), 0xB002 (cache entry flushed), 0xB001 (cache entry deleted), 0xB000 (cache disabled), 6037 (0x1795, rejected loopback).
- SQM counters (`WinSqmIncrementDWORD`) for each NTLM version used (LMv1, LMv2, NTLMv1, NTLMv1 with ESS, NTLMv2, loopback, NTLM/Negotiate ISC/ASC).

### ETW

Provider `{AC43300D-5FCC-4800-8E99-1BD3F85F0320}` (`NTLMEventProviderId`, Microsoft-Windows-NTLM), registered on first use by `SspInitEtwLogHandle`, unregistered by `SpShutdown`. Each `EventWrite` is preceded by `EtwEventEnabled`; the blocking events also give the process name (`OpenProcess` + `QueryFullProcessImageNameW`).

| Event | Level | Channel | Opcode, task | Keyword | Written when |
|-------|-------|---------|--------------|---------|--------------|
| 100 | 2 (error) | 17 | 0, 0 | 0x4000000000000000 | NTLM logon refused for a member of Protected Users (`SspLogAuthEventCommon`) |
| 101 | 2 (error) | 18 | 0, 0 | 0x2000000000000000 | NTLM logon refused by an access control restriction |
| 4001 | 3 (warning) | 16 | 0, 1 | 0x8000000000000000 | Outgoing NTLM blocked (`SspLogNTLMClientBlocked`) |
| 4002 | 3 | 16 | 0, 1 | 0x8000000000000000 | Incoming NTLM blocked (`SspLogNTLMServerBlockedChallenge`) |
| 4003 | 3 | 16 | 0, 1 | 0x8000000000000000 | Incoming NTLM blocked by the domain policy (`SspLogNTLMServerBlockedHigher`) |
| 4010, 4011 | 3 | 16 | 0, 0 | 0x8000000000000000 | Minimum client / server session security not met (`SspLogMinimumSecurityFailure`) |
| 8001, 8002, 8003 | 4 (info) | 16 | 0, 2 | 0x8000000000000000 | Audit versions of 4001…4003 |

WPP / legacy tracing:
- `NtlmInitializeTrace` registers the control GUID `{C92CF544-91B3-4DC0-8E11-C580339A0BF8}` (`NtlmControlGuid`, `EtwRegisterTraceGuidsW`, MOF resource `MofResource`) with 5 trace GUIDs: `NtlmInitializeGuid` `{6DF28B22-73BE-45CC-BA80-8B332B35A21D}`, `NtlmAcceptGuid` `{94D4C9EB-0D01-41AE-99E8-15B26B593A83}`, `NtlmLogonGuid` `{19196B33-A302-4C12-9D5A-EAC149E93C46}`, `NtlmValidateGuid` `{34D84181-C28A-41D8-BB9E-995190DF83DF}`, `NtlmGenericPassthroughGuid` `{21ABB5D9-8EEC-46E4-9D1C-F09DD57CF70B}`.
- `WppInitUm` registers the WPP control GUID `{5BBB6C18-AA45-49B1-A15F-085F7ED0AA90}` (`NtLmGlobalDebugTraceControlGuid`), also used by the `_Dbgp*` trace controller of [SpInitialize](#spinitialize-0x4d119de8).
