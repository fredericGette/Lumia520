## AppXDeploymentServer.dll

The AppX deployment service (`appxsvc`): it installs, updates, removes, registers and enumerates the AppX packages (Windows Runtime applications) of Windows Phone 8.1, and keeps the package repository.  
`AppXDeploymentServer.dll` is a very large C++ svchost service DLL (1 159 168 bytes, 1 902 functions). It has no symbols, but it carries thousands of assertion strings (`Common::Deployment::…`, `PackageRepository::…`, `OSIntegration::…`) and the class names. The service is an LRPC server with two interfaces (`{AE2DC901-…}`, 19 procedures, and the asynchronous `{FF9FD3C4-…}`). Each procedure impersonates the caller and forwards to one of the exported `*Implementation` / `*Internal` functions. The packages, applications, dependencies and per-user visibility are stored in an ESE database (`PackageRepository.edb`). Package files are read with the AppX/OPC factories and their signatures are checked with WinTrust/CRYPT32. The service publishes progress through temporary WNF state names that it creates for its clients. It precompiles the JavaScript of packages (JS byte code) in a `ByteCodeGenerator.exe` process that it starts in an AppContainer, then talks to that process over RPC. Phone-specific steps are imported from `ext-ms-win-appmodel-deployment-l1-1-0` (`MdilBindPackage`, `CreateAppxInstallProfile`, `WPDeveloperAppAllowed`, `LaunchByteCodeRpcServer`, …).  
Its client is [AppXDeploymentClient.dll](./appxdeploymentclient.md), which calls both interfaces. That DLL implements `Windows.Management.Deployment.PackageManager`, which [pacmanserver.dll](./pacmanserver.md) uses for AppX packages (it also calls `AppXDeploymentClient!GetApplicability`). The svchost host, `ByteCodeGenerator.exe` and the DLL behind `ext-ms-win-appmodel-deployment-l1-1-0` aren't documented here.

Location on the phone: `C:\Windows\System32\AppXDeploymentServer.dll` ? (the extracted file has no notes).  
Service name: `appxsvc` (svchost DLL: exports `ServiceMain` and `SvchostPushServiceGlobals`).  

### Imports

| DLL | Functions |
|-----|-----------|
| ESENT | `JetCreateInstanceW`, `JetSetSystemParameterW`, `JetInit`, `JetTerm`, `JetBeginSessionW`, `JetEndSession`, `JetCreateDatabaseW`, `JetAttachDatabaseW`, `JetDetachDatabase2W`, `JetOpenDatabaseW`, `JetCloseDatabase`, `JetCreateTableW`, `JetOpenTableW`, `JetCloseTable`, `JetAddColumnW`, `JetCreateIndex2W`, `JetGetTableColumnInfoW`, `JetSetCurrentIndexW`, `JetBeginTransaction`, `JetCommitTransaction`, `JetRollback`, `JetPrepareUpdate`, `JetSetColumn`, `JetRetrieveColumn`, `JetUpdate`, `JetDelete`, `JetMakeKey`, `JetSeek`, `JetMove`, `JetSetIndexRange`, `JetIndexRecordCount` |
| RPCRT4 | Server: `RpcServerUseProtseqW`, `RpcServerInqBindings`, `RpcServerRegisterIfEx`, `RpcServerRegisterIf3`, `RpcServerUnregisterIf`, `RpcEpRegisterW`, `RpcEpUnregister`, `RpcBindingVectorFree`, `NdrServerCall2`, `NdrAsyncServerCall`, `RpcAsyncCompleteCall`, `RpcImpersonateClient`, `RpcRevertToSelf`, `RpcServerInqCallAttributesW`, `RpcRaiseException`; client: `RpcBindingCreateW`, `RpcBindingBind`, `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW`, `RpcBindingFree`, `RpcStringFreeW`, `NdrClientCall2`; `UuidCreate`, `UuidToStringW` |
| AppXAllUserStore | `UpdatePackageInRegistryStore`, `IsNonInboxAllUserPackage`, `IsPackageInUpgradeKey`, `DidAppSurviveOSUpgradeForUser`, `IsSystemInAuditBoot`, `IsInboxPackage` |
| AppxApplicabilityEngine | `GetApplicablePackagesForUser`, `FreeApplicablePackages` |
| ext-ms-win-appmodel-deployment-l1-1-0 | `WPDeveloperAppAllowed`, `WPUnsignedAppAllowed`, `WPEnterpriseAppAllowed`, `IsWPStoreSigningAllowed`, `WPGetSignatureOriginForSL`, `WPSetEABitsForPackage`, `CreateAppxMetadataProfile`, `DeleteAppxMetadataProfile`, `CreateAppxInstallProfile`, `DeleteAppxInstallProfileEx`, `GetAppxDataRootPath`, `CheckPackageRestoreEligibility`, `IsRequestRestoreAllowed`, `IsProvisioningAllowed`, `LaunchByteCodeRpcServer`, `CleanupByteCodeRpcServer`, `IsLaunchByteCodeRpcServerImplemented`, `MdilBindPackage`, `MdilBindPackageEstimate`, `GetVolumeMediaId`, `ApplyStrongProtection` |
| api-ms-win-appmodel-runtime-l1-1-1, -runtime-internal-l1-1-1, -identity-l1-2-0, -state-l1-1-2 | `PackageFamilyNameFromFullName`, `PackageNameAndPublisherIdFromFamilyName`, `PackageIdFromFullName`, `GetPackagePath`, `GetStagedPackagePathByFullName`, `GetApplicationUserModelId`, `GetPackageFullName`, `GetPackagesByPackageFamily`, `GetSystemMetadataPathForPackage`, `GetPackageStatus`, `UpdatePackageStatus`, `UpdatePackageStatusForUser`, `IncrementPackageStatusVersion`, `GetAppModelVersion`, `AppContainerDeriveSidFromMoniker`, `GetStateFolder`, `GetStateRootFolder`, `OpenStateExplicit`, `CloseState`, `GetHivePath` |
| USERENV | `CreateAppContainerProfile`, `DeleteAppContainerProfile`, `DeriveAppContainerSidFromAppContainerName`, `GetProfileType` |
| api-ms-win-core-biplmapi-l1-1-2 | `BiChangeApplicationStateForPackageName` |
| WINTRUST, CRYPT32, bcrypt | `WinVerifyTrust`; `CryptQueryObject`, `CryptMsgGetParam`, `CryptMsgClose`, `CertGetCertificateChain`, `CertVerifyCertificateChainPolicy`, `CertGetEnhancedKeyUsage`, `CertGetSubjectCertificateFromStore`, `CertNameToStrW`, `CryptFindOIDInfo`, …; `BCryptOpenAlgorithmProvider`, `BCryptCreateHash`, `BCryptHashData`, `BCryptFinishHash`, `BCryptGetProperty`, … (SHA256 block map hashes) |
| ntdll | `NtCreateWnfStateName`, `NtDeleteWnfStateName`, `RtlPublishWnfStateData`, `RtlWaitForWnfMetaNotification`, `NtQuerySystemInformation`, `NtGetCachedSigningLevel`, `RtlAddProcessTrustLabelAce`, `NtSetSecurityObject`, `NtCreateSection` / `NtMapViewOfSection`, `NtOpenFile`, `ZwFlushBuffersFileEx`, AVL tables (`RtlInitializeGenericTableAvl`, …), SIDs, SRW locks, `WinSqm*`, `EtwEventRegister` / `EtwEventWrite`, … |
| tdh, ext-ms-win-wevtapi-eventlog-l1-1-0, ext-ms-win-wer-reporting-l1-1-0 | `TdhGetEventInformation`, `TdhGetEventMapInformation`, `TdhEnumerateProviderFieldInformation`; `EvtOpenChannelConfig`, `EvtGetChannelConfigProperty`, `EvtExportLog`, `EvtClose`; `WerReportCreate`, `WerReportSetParameter`, `WerReportAddFile`, `WerReportSubmit`, `WerReportCloseHandle` ([error report](#error-report)) |
| api-ms-win-service-core / winsvc / management | `RegisterServiceCtrlHandlerW`, `SetServiceStatus`, `QueryServiceStatus`, `OpenSCManagerW`, `OpenServiceW`, `CloseServiceHandle` |
| api-ms-win-core-com-l1-1-1, OLEAUT32, winrt, ext-ms-win-ole32-bindctx-l1-1-0 | `CoInitializeEx`, `CoCreateInstance`, `CoCreateGuid`, `CoDisconnectContext`, `RoGetAgileReference`, `CLSIDFromString`, `StringFromGUID2`, BSTR / VARIANT, `RoInitialize`, `CreateBindCtx`, `CoGetObject` |
| ext-ms-win-session-wtsapi32 / usertoken, ext-ms-win-advapi32-safer, ext-ms-win-ntuser-windowstation-l1-1-1, ext-ms-win-shell-settingsync-l1-1-0 | `WTSEnumerateSessionsW`, `WTSQueryUserToken`, `QueryActiveSession`, `QueryUserToken`; `SaferIdentifyLevel`, `SaferComputeTokenFromLevel`; `CreateWindowStationW`, `CreateDesktopW`, `SetProcessWindowStation`, …; `SettingSync_IsAllowedByGroupPolicy` |
| api-ms-win-core-file, -file-l2, kernel32-legacy, path, url, shlwapi, memory, io, version | files, directories, volumes, hard links (`CreateHardLinkW`), `CopyFileExW`, `MoveFileExW`, `GetVolumeNameForVolumeMountPointW`, `GetDiskFreeSpaceW`, file mappings, `PathCchAppend`, `PathAllocCombine`, `UrlCreateFromPathW`, `PathCreateFromUrlW`, `GetFileVersionInfoExW`, `CancelIoEx`, … |
| api-ms-win-security-*, profapi, SHCORE | tokens and ACLs (`CreateRestrictedToken`, `AdjustTokenPrivileges`, `SetNamedSecurityInfoW`, `SetEntriesInAclW`, `ConvertStringSecurityDescriptorToSecurityDescriptorW`, …), `LookupAccountSidW`, `GetBasicProfileFolderPath`, `IsOS` |
| api-ms-win-core-processthreads, threadpool, synch, registry, sysinfo, psapi, … | `CreateProcessAsUserW`, `ResumeThread`, `TerminateProcess`, `OpenProcess`, `K32EnumProcesses`, `QueryFullProcessImageNameW`, thread pool work items, waitable timers, events, registry (`RegCopyTreeW`, `RegDeleteTreeW`, `RegOpenUserClassesRoot`, …), `GetSystemInfo`, `GetOsSafeBootMode`, `LoadLibraryExW`, `GetProcAddress`, … |
| api-ms-win-eventing-provider / classicprovider | `EventRegister`, `EventWrite`, `EventActivityIdControl`, `EventUnregister`; `RegisterTraceGuidsW`, `TraceMessage`, … (WPP) |
| api-ms-win-core-crt-l2-1-0, ntdll (CRT) | `_initterm`, `_onexit`, `__dllonexit3`, `memcpy`, `wcs*`, `qsort`, `__C_specific_handler`, `RtlCaptureContext`, … |

The CRT, `__C_specific_handler`, `RtlAddFunctionTable` / `RtlDeleteFunctionTable`, `UnhandledExceptionFilter`, `RaiseFailFastException`, `DebugBreak` and `DecodePointer` / `EncodePointer` imports are the Visual C++ CRT startup, exception, delay-load and `/GS` security cookie code. Most imports are reached through small wrapper functions (0x100DA000…0x100DB400). The `ext-ms-win-*` sets are delay-loaded (their names are in the delay-load table): on the phone they may be absent or stubbed.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `<HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx!ExtensionsModule>` (environment variables expanded) | `LoadLibraryExW(…, LOAD_LIBRARY_SEARCH_SYSTEM32)` + `GetProcAddress("LoadExtensionRegistrationTable")`, `("LoadCategoryNameTable")` (`sub_100D5488`, `sub_100D52A8`) | Deployment extension handlers (`OSIntegrationManagerHost`): the table of extension categories and their handler classes |
| `tdh.dll` | `LoadLibraryExW` + `GetProcAddress("TdhFormatProperty")` (`sub_1005A7B0`) | Formatting ETW events into the text of the [error report](#error-report) |
| `Bcrypt.dll` | `LoadLibraryExW` + `GetProcAddress` from a table (`sub_100D3ED4`) | Hashing (also statically imported) |
| `<System32>\ByteCodeGenerator.exe <UUID>` (`<SysWOW64>` for a 32-bit package on a 64-bit system) | `CreateProcessAsUserW` (suspended, `EXTENDED_STARTUPINFO_PRESENT`), AppContainer `ByteCodeGeneration`, desktop `ByteCodeGeneratorWinStation\ByteCodeGeneratorDesktop`; or `LaunchByteCodeRpcServer` when `IsLaunchByteCodeRpcServerImplemented` ([Byte code](#byte-code-generation)) | JavaScript byte code cache (`JSByteCodeCache`) of a package, RPC server `{43D210C2-…}` |
| `<PackageRepositoryRoot>\PackageRepository.edb` | ESENT ([Repository](#package-repository)) | Packages, applications, dependencies, visibility |
| `AppxManifest.xml`, `AppxBlockMap.xml`, `AppxSignature.p7x`, `AppxMetadata\CodeIntegrity.cat`, `AppxMetadata\AppxBundleManifest.xml`, `resources.pri`, `*.rslc` | AppX / OPC factories, `CreateFileW` | Package and bundle contents, signature, block map hashes, resources |
| `<volume>\microsoft.system.package.metadata\<full name>[.pckgdep]`, `Microsoft.System.Package.Metadata\Autogen` | `CreateFileW`, file mapping (`ARI::DependencyMiniRepository`) | Local copy of the manifest and dependency mini-repository of a package |
| `AppxProvisioning.xml` (schema `http://schemas.microsoft.com/appx/2013/appxprovisionpackage`, `AppxProvisionList`: `EndOfLife` / `Provisioned` packages) | MSXML | Provisioned and end-of-life packages |
| `%windir%\windowsupdate.log`, exports of `Microsoft-Windows-AppXDeploymentServer/Operational` and `Microsoft-Windows-AppXPackaging/Operational` (`.evtx`) | `CopyFileW`, `EvtExportLog`, `WerReportAddFile` ([error report](#error-report)) | Files attached to a deployment failure report |
| MSXML 6 `{88D96A05-F192-11D4-A65F-0040963251E5}` (`IXMLDOMDocument2`), schema cache `{88D96A07-F192-11D4-A65F-0040963251E5}` (`IXMLDOMSchemaCollection`) | `CoCreateInstance` (in-proc) | Manifests and provisioning XML |
| `AppxFactory` `{5842A140-FF9F-4166-8F5C-62F5B7B0C781}` (`IAppxFactory`), `AppxBundleFactory` `{378E0446-5384-43B7-8877-E7DBDD883446}` (`IAppxBundleFactory`), `OpcFactory` `{6B2D6BA0-9F3E-4F27-920B-313CC426A39E}` (`IOpcFactory` `{6D0B4446-CD73-4AB3-94F4-8CCDF6116154}`), `AppxFactoryInternal2` `{A258718D-BE3E-40CC-A77F-75642516497C}` (IID `{AECE1B3D-6913-4AAC-8C7E-1908DD648E67}`) | `CoCreateInstance` (in-proc, names from the assertion strings) | Reading packages and bundles |
| Immersive shell `{C2F03A33-21F5-47FA-B4BB-156362A2F239}` (`IServiceProvider`) | `CoCreateInstance(CLSCTX_LOCAL_SERVER \| 0x400)` (`sub_1008FD64`, `EnumeratePlmSessionList`), then `QueryService(SID_ProcessLifetimeManagerControl {FD6BD19E-E84F-455B-9FC9-1B00953FCA50} ?)`; other sessions through `CoGetObject("Session:%d!clsid:…")` | Process lifetime manager: suspends / terminates the applications of a package being serviced |
| `CLSID_SettingSyncEngine` `{4AA0A5C4-1B9B-4F2E-99D7-99C6AEC83474}`, `CLSID_CollectionStagingManager` `{2744BC6A-4039-11E3-ABAD-8CFB6188709B}` | `CoGetObject("Session:%d!clsid:…")` in the session of the caller (`sub_100D4870`) | Roaming / backup of the application state (settings sync) |
| `{DCB00C01-570F-4A9B-8D69-199FDBA5723B}` (`INetworkListManager` `{DCB00000-…}`), `{EF30258D-9897-45CD-A760-FE5C195CB00E}` (IID `{FCACD78B-E466-4049-B7C9-367F5F6815C1}`), `{DBCE7E40-7345-439D-B12C-114A11819A09}` (IID `{130A2F65-2BE7-4309-9A58-A9052FF2B61C}`) | `CoCreateInstance` (in-proc) | Network state for settings sync; other two ? |
| `CLSID_ContextSwitcher` `{0000034E-0000-0000-C000-000000000046}` (`IContextCallback`) | `CoCreateInstance` (`sub_100513E0`) | Disconnects the COM context at service stop |
| Service `Sysmain` | `OpenServiceW` + `QueryServiceStatus` (`sub_100CB7F4`) | Is the prefetch service running (see [RPC client](#rpc-client)) |
| RPC server `{B58AA02E-2884-4E97-8176-4EE06D794184}` (LRPC, server running as LocalSystem) | [RPC client](#rpc-client) | Notification with the AppUserModelId of an application (prefetch / SysMain ?) |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 22 | `ServiceMain` | 0x10051C34 | `DWORD argc, LPWSTR *argv` (not used) |
| 27 | `SvchostPushServiceGlobals` | 0x10051C18 | `SVCHOST_GLOBAL_DATA *` (stored in `dword_100DF70C`) |
| 24 | `StartDeploymentImplementation` | 0x1004E938 | RPC opnum 0, see below |
| 2 | `CreateWnfStateNameImplementation` | 0x1004E810 | `WNF_STATE_NAME *out` |
| 1 | `CancelDeploymentImplementation` | 0x1004F398 | `WNF_STATE_NAME` (by value) |
| 15 | `GetSortedRegisterPackageListImplementation` | 0x1004F48C | `const GUID *activityId, allocator, deallocator, list **out` |
| 8 | `FixStagedPackagesImplementation` | 0x1004F628 | `const GUID *activityId` |
| 20 | `RDSRecoverRequestsImplementation` | 0x1004F954 | none |
| 3 | `EnumPackagesByUserSidInternal` | 0x1004CBEC | `LPCWSTR userSid, enum, allocator, deallocator, RpcPackageInfo **out` |
| 4 | `EnumPackagesByUserSidNamePublisherInternal` | 0x1004CDA8 | `LPCWSTR userSid, LPCWSTR name, LPCWSTR publisher, enum, allocator, deallocator, RpcPackageInfo **out` |
| 5 | `EnumPackagesByUserSidPackageFamilyNameInternal` | 0x1004CFF0 | `LPCWSTR userSid, LPCWSTR familyName, enum, allocator, deallocator, RpcPackageInfo **out` |
| 7 | `FindPackageByUserSidPackageFullNameInternal` | 0x1004D1F8 | `LPCWSTR userSid, LPCWSTR fullName, allocator, deallocator, RpcPackageInfo **out` |
| 6 | `EnumVisibilityByPackageFullNameInternal` | 0x1004D660 | `LPCWSTR fullName, allocator, deallocator, RpcVisibilityInfo **out` |
| 16 | `IsPackageInstalledInternal` | 0x1004DA4C | `LPCWSTR fullName, BOOL *out` |
| 14 | `GetPackageTypeImplementation` | 0x1004DCA8 | `LPCWSTR fullName, enum *out` |
| 11 | `GetApplicabilityImplementation` | 0x1004A6B4 | `LPCWSTR fullName, LPCWSTR userSid, DWORD verifyProfileIntegrity, enum *applicabilityState` |
| 13 | `GetPackageFilesDiskUsageImplementation` | 0x100548B4 | `LPCWSTR, UINT64 *out` |
| 19 | `PackageStatusOperationImplementation` | 0x1004F780 | `enum, LPCWSTR, DWORD` |
| 21 | `RequestPackageOperationImplementation` | 0x10050BC8 | `LPCWSTR, enum, BOOL, ?, ?` (RPC opnum 14 passes 0, 0, 0) |
| 9 | `GenerateBytecodeForPackageImplementation` | 0x10050E08 | `LPCWSTR fullName` ? |
| 10 | `GenerateBytecodeForPackagesImplementation` | 0x10050FD4 | `LPCWSTR *fullNames, DWORD count` |
| 26 | `AppXSetTrustLabelOnPackage` | 0x100B89CC | `LPCWSTR fullName, DWORD, LPCWSTR packagePath, DWORD` |
| 25 | `AddToPurgeList` | 0x100B79A4 | `LPCWSTR, DWORD, DWORD` ? |
| 12 | `GetDeploymentError` | 0x1004A0E8 | `HRESULT *, WORD *, …` |
| 23 | `SetDeploymentError` | 0x1004A108 | `HRESULT, …` |
| 17 | `PackageRepositoryAllocate` | 0x1004E544 | `SIZE_T` → pointer (`sub_1005A890`, process heap) |
| 18 | `PackageRepositoryFree` | 0x1004E55C | pointer |

The `*Implementation` / `*Internal` exports are the bodies of the [RPC procedures](#rpc-server). The RPC stubs pass `PackageRepositoryAllocate` / `PackageRepositoryFree` as allocator and deallocator, and these build the returned lists (`RpcPackageInfo`, `RpcVisibilityInfo`, `RpcRegisterPackageInfo`: package full name, name, publisher, publisher ID, resource ID, install location, display name, publisher display name, description, logo, user SID, dependency monikers, from the assertion strings). Their names suggest that they're also called in-process by another module, but that isn't proven; [AppXDeploymentClient.dll](./appxdeploymentclient.md) doesn't import them (it uses RPC).  
`GetDeploymentError` / `SetDeploymentError` hold the extended error of the current thread (HRESULT, a WORD and a text, in a TLS slot). The same code is linked in other modules ([AppXDeploymentClient.dll](./appxdeploymentclient.md) has it too): when it runs in a module other than `AppXDeploymentServer` (`GetModuleHandleExW`), it forwards to the export of the loaded `AppXDeploymentServer.dll` (`sub_1005A320`, `GetAppXServerModuleForRedirect`).  
`AddToPurgeList` (`sub_100B7098`) writes under `HKLM\Software\Microsoft\Windows\CurrentVersion\AppX\PurgeList` (`PerPackageEntries`, `PerPackageFamilyEntries`, `PerSystemEntries`, `DirtyPackages`).  
`AppXSetTrustLabelOnPackage` (`sub_100B8578`) puts a process trust label ACE (`RtlAddProcessTrustLabelAce`) on the folder of a package. It's called with 2 for every package of the asynchronous [RPC procedure](#rpc-server).

### Startup

`start` (`_DllMainCRTStartup`, 0x10055F14): CRT, then `DllMain` (`sub_10049A78`).  
`DllMain`, on `DLL_PROCESS_ATTACH`:
1. Registers WPP tracing (`RegisterTraceGuidsW`, control GUID `{BA44067A-3C4B-459C-A8F6-18F0D3CF0870}` ?) and the ETW provider (`McGenEventRegister`).
2. Initialises the global locks and caches: the WNF state name cache (`sub_10050320`), …

On `DLL_PROCESS_DETACH` it frees them, unregisters WPP (`UnregisterTraceGuids`) and ETW (`McGenEventUnregister`).

### ServiceMain (0x10051C34)

1. `RegisterServiceCtrlHandlerW(L"appxsvc", sub_10051AC8)`; status `SERVICE_START_PENDING` (wait hint 30 s).
2. Starts the [RPC server](#rpc-server) (`sub_100514A8`).
3. `CoInitializeEx(NULL, COINIT_MULTITHREADED)`; `CreateGlobalSynchronizationObjects` (`sub_10051248`): the stop event `dword_100DF8C4`, an event `dword_100DF8C8` and the idle waitable timer `dword_100DF8CC`.
4. `SERVICE_RUNNING`, then loop (`sub_10051B48`): `WaitForMultipleObjects` on the timer, the event and the stop event. When the idle timer fires, the service stops if `sub_10051978` says it can (no deployment request in progress). Every RPC call cancels the timer (`sub_100CA55C`) and returns 0x80070708 if the service is stopping.
5. On exit: `SERVICE_STOP_PENDING`, unregisters the RPC interfaces and endpoints (`sub_1005182C`), shuts the engine down (`sub_10049E90`: waits up to 5 s, in 200 ms steps, for the calls in progress, `JetTerm`), `CoDisconnectContext` through `CLSID_ContextSwitcher`, closes the handles, `SERVICE_STOPPED`, `CoUninitialize`.

The control handler accepts `SERVICE_CONTROL_STOP` (1) and `SERVICE_CONTROL_SHUTDOWN` (5): both set the stop event if `sub_10051978` agrees. The other controls only report the current status again.

### RPC server

`sub_100514A8`:
1. `sub_1005113C` builds a self-relative security descriptor (`AccessHelpers::CreateSelfRelativeSecurityDescriptor`) for LocalSystem (`WinLocalSystemSid`), Users (`WinBuiltinUsersSid`), Interactive (`WinInteractiveSid`) and ALL APPLICATION PACKAGES (`WinBuiltinAnyPackageSid`).
2. `RpcServerUseProtseqW(L"ncalrpc", 10, sd)`: dynamic LRPC endpoint protected by this descriptor; `RpcServerInqBindings`.
3. `RpcServerRegisterIfEx({AE2DC901-…}, NULL, NULL, 0x21, 1234, NULL)` (`RPC_IF_AUTOLISTEN | RPC_IF_ALLOW_LOCAL_ONLY`, no security callback).
4. `RpcServerRegisterIf3({FF9FD3C4-…}, NULL, NULL, 0x21, 1234, (UINT)-1, NULL, sd)`.
5. `RpcEpRegisterW` of both interfaces with the annotation `L"appxsvc"`.

Interface `{AE2DC901-312D-41DF-8B79-E835E63DB874}` version 1.0 (`RPC_SERVER_INTERFACE` at 0x1002D370, 19 procedures, `NdrServerCall2`). Each server routine increments the call count and checks that the service isn't stopping (`IncrementRpcRefCountAndCheckForShutdown`, `sub_100CA55C`), calls the export and raises the HRESULT as an RPC exception if it fails. Parameters are from the proc and type format strings (string = `[string] wchar_t *`, range-checked):

| Opnum | Server routine | Parameters | Export / use |
|-------|----------------|------------|--------------|
| 0 | `sub_100CA7EC` | `[in] enum16 rpcOperation`, `[in] enum32 deploymentOptions`, `[in] string mainParameter`, `[in, unique] string userSid` (from the client), `[in] long parameterCount`, `[in, size_is(parameterCount)] string parameters[]`, `[in] long registerForProgress`, `[in, ref] WNF_STATE_NAME *`, `[in, unique] GUID *activityId`, `[in] long` (volume ?), `[out] string *requestMoniker` | `StartDeploymentImplementation`: starts an asynchronous deployment request ([below](#startdeploymentimplementation-0x1004e938)) |
| 1 | `sub_100CA8A4` | `[out] WNF_STATE_NAME *` | `CreateWnfStateNameImplementation`: progress state of a request ([WNF](#wnf-states)) |
| 2 | `sub_100CA910` | `[in] WNF_STATE_NAME` | `CancelDeploymentImplementation`: cancels the request that publishes this state |
| 3 | `sub_100CA984` | `[in, unique] GUID *activityId`, `[out]` list | `GetSortedRegisterPackageListImplementation` (synchronous request `GetSortedRegisterPackageOperation`) |
| 4 | `sub_100CAA00` | `[in, unique] GUID *activityId` | `FixStagedPackagesImplementation` |
| 5 | `sub_100CAA6C` | none | `RDSRecoverRequestsImplementation`: replays the deployment requests interrupted by a reboot or a crash (resiliency data, `RDSAppXNotifyRecoveryTrigger`) ? |
| 6 | `sub_100CA654` | `[in] string userSid`, `[in] enum16`, `[out]` list | `EnumPackagesByUserSidInternal` |
| 7 | `sub_100CA6D4` | `[in] string userSid`, `[in] string name`, `[in] string publisher`, `[in] enum16`, `[out]` list | `EnumPackagesByUserSidNamePublisherInternal` |
| 8 | `sub_100CAAD4` | `[in] string fullName`, `[in] string userSid`, `[in] long`, `[out] enum16 *` | `GetApplicabilityImplementation`: applicability state of a package for one user or for any user (`GetApplicabilityForOneUser` / `GetApplicabilityForAnyUser`, end-of-life list); writes ETW events with the result |
| 9 | `sub_100CAC30` | `[in] string fullName`, `[out]` list | `EnumVisibilityByPackageFullNameInternal`: the users of a package |
| 10 | `sub_100CAE94` | `[in] string fullName`, `[out] long *` | `IsPackageInstalledInternal` (`VerifyInventoryAccess`, read-only repository session) |
| 11 | `sub_100CACAC` | `[in] string userSid`, `[in] string fullName`, `[out]` list | `FindPackageByUserSidPackageFullNameInternal` |
| 12 | `sub_100CAD2C` | `[in] enum16`, `[in] string`, `[in] long` | `PackageStatusOperationImplementation` |
| 13 | `sub_100CAF04` | `[in] string fullName`, `[out] enum16 *` | `GetPackageTypeImplementation`: looks for the package in the system package folder (`<system SIS path>\<name>*`) and in `HKLM\Software\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications\` |
| 14 | `sub_100CADA0` | `[in] string`, `[in] enum16` | `RequestPackageOperationImplementation(a, b, 0, 0, 0)` |
| 15 | `sub_100CAE18` | `[in] string`, `[in] enum16` | `sub_1004FA30`: deployment request with operation 12 and option 0x20000 if bit 0 is set; administrators only (`IsMemberOfAdministratorsGroup`) |
| 16 | `sub_100CAF74` | `[in] string`, `[out] hyper *` | `GetPackageFilesDiskUsageImplementation` (also `GetDiskFreeSpaceW("%systemdrive%\")`) |
| 17 | `sub_100CA764` | `[in] string userSid`, `[in] string familyName`, `[in] enum16`, `[out]` list | `EnumPackagesByUserSidPackageFamilyNameInternal` |
| 18 | `sub_100CB074` | `[in, size_is(count)] string fullNames[]`, `[in, range(1, 641)] long count` | `GenerateBytecodeForPackagesImplementation` (impersonating the caller) |

All 19 procedures are called by [AppXDeploymentClient.dll](./appxdeploymentclient.md#rpc), which lists the caller of each opnum.

Interface `{FF9FD3C4-742E-45E0-91DD-2F5BC632A1DF}` version 1.0 (0x1002CF30, asynchronous, `NdrAsyncServerCall`), called by `AppXDeploymentClient!AppxValidatePackages`:

| Opnum | Server routine | Parameters | Use |
|-------|----------------|------------|-----|
| 0 | `sub_100CAFE4` | `[in, range(1, 641)] long count`, `[in, size_is(count)] string fullNames[]`, `[in, unique] string path` | `sub_100B8A50`: `path` is allowed only with one package. It's checked first (`sub_100CA0E8` + `sub_100C8250`: opens the file, obfuscated code that calls `NtQuerySystemInformation(0x86)`, licence or policy check ?). Then, for every package, `GetStagedPackagePathByFullName` and `AppXSetTrustLabelOnPackage(fullName, 2, path, 0)`; `RpcAsyncCompleteCall` with the HRESULT. `E_INVALIDARG` if the arguments are inconsistent |

### StartDeploymentImplementation (0x1004E938)

Its body has no decompilation (`/GS` cookie); from the disassembly and the assertion strings:
1. Takes the activity ID (`EventActivityIdControl(EVENT_ACTIVITY_CTRL_SET_ID)`), checks `requestMoniker`, `wnfStateName` and `rpcOperation > RpcInvalidOperation`.
2. Impersonates the client, builds a command (`command.Initialize()`), gets the caller's SID and compares it with LocalSystem (`CreateWellKnownSid(WinLocalSystemSid)`, `RtlEqualSid`).
3. Logs the arguments (`LogStringArguments(deploymentOperation, options, mainParameter, parameters, parameterCount)`). For the volume operations the volume must be the default or the system volume (`packageVolumeId == DefaultVolumeKey || SystemVolumeKey`), and some operations require `parameterCount == 0`.
4. Queues the request (`command.Process(deploymentOperation, &args, telemetrySession, &requestMoniker)` or `command.ProcessVolumeRequest`) and returns its moniker.

A deployment request goes through the state handlers of the engine (names from the strings): applicability and dependency resolution (`AppxApplicabilityEngine`), approval (signature: `WinVerifyTrust`, `WPGetSignatureOriginForSL`, developer / enterprise / unsigned checks), staging (copy or hard links, block map comparison for updates, `MdilBindPackage`), indexing in the repository, AppContainer and install profiles (`CreateAppxInstallProfile`, `CreateAppxMetadataProfile`), OS integration (deployment extension handlers of the `ExtensionsModule`), registration per user, applications stopped through the PLM, settings sync restore, byte code generation, and destaging of the old version. Each request writes its package full name under `HKLM\Software\Microsoft\Windows\CurrentVersion\AppX\NewDeploymentOperation` (value = 1, `AllPackages` for a global one). If the request has a cancel notification state, it publishes 4 zero bytes there (`sub_10039528`).

### Package repository

`sub_1005CB4C` creates the ESE instance (`JetCreateInstanceW(…, L"Instance")`, `JetSetSystemParameterW` cache, log and page parameters) and `JetInit`. The database `PackageRepository.edb` is in the folder named by `HKLM\Software\Microsoft\Windows\CurrentVersion\Appx!PackageRepositoryRoot` (`sub_10071944`, up to 32 767 characters, `\\?\` prefix accepted). Tables and keys (from the column and index names): `Package` (`PackageKey`, `PackageFullName`, `PackageType`, `PackageVolumeKey`, `Architecture`, `Version`, `PublisherHash`, `IsInbox`, `IsDevelopmentMode`, …), `Application` (`ApplicationKey`, `PackageRelativeAppId`, `DisplayName`, `Description`, `SmallLogo`, `ForegroundText`, `BackgroundColor`, `StartPage`), `ApplicationContentUriRule`, `Extension`, `Dependency`, `DependencyGraph` and `WowDependencyGraph` (`Supplier`, `DependentPackage`, `DependencyType`, `User`), `File` (`RelativeFilePath`, `Digest`), `Resource`, `User` and `Visibility` (`UserSID`, `VisibilityState`), `PackageVolume`.  
Package volumes are listed in `HKLM\Software\Microsoft\Windows\CurrentVersion\AppX\PackageVolumes` (`MountPoint`, `SisPath`, `Name`, `Flags`, `NextVolumeIndex`).

### Byte code generation

`sub_100C700C` precompiles the JavaScript of a package into a byte code cache file (`CreateByteCodeCacheFile`, `GetFileListFromBlockMap`):
1. `sub_100C7CB8`: `UuidCreate` + `UuidToStringW`. If `IsLaunchByteCodeRpcServerImplemented()`, the server is started by `LaunchByteCodeRpcServer` (from `ext-ms-win-appmodel-deployment`, AppContainer SID from `DeriveAppContainerSidFromAppContainerName`). Otherwise `sub_100C79E8`:
   - `CreateAppContainerProfile(<name>, L"ByteCodeGeneration", L"ByteCodeGeneration", …)`;
   - process token with that AppContainer and the security descriptor `D:(A;OICI;GA;;;SY)(A;OICI;GR;;;S-1-2-1406295995-2538229729-1264070048-2919177457)(A;OICI;GR;;;AC)`;
   - `CreateProcessAsUserW("<System32 or SysWOW64>\ByteCodeGenerator.exe <UUID>", CREATE_SUSPENDED | …)`, desktop `ByteCodeGeneratorWinStation\ByteCodeGeneratorDesktop` (`CreateWindowStationW` / `CreateDesktopW`, `sub_100C36AC`), then `ResumeThread`.
2. `sub_100C7E6C` binds to the process: `RpcBindingCreateW` with protocol sequence 3 (LRPC) and the UUID as object UUID; security: authentication level 6 (`PKT_PRIVACY`), service 0x14, QoS version 5 (`RPC_C_QOS_IDENTITY_DYNAMIC`, `RPC_C_IMP_LEVEL_IDENTIFY`) and the security descriptor above as `ServerSecurityDescriptor`. `RpcBindingBind` is retried while it fails with 1753 (`EPT_S_NOT_REGISTERED`) and the process is still alive (`WaitForSingleObject` 100 ms, 200 ms, …).
3. `sub_100C80B8` duplicates the cache file handle into the process (`DuplicateHandle`) and calls opnum 1.
4. `sub_100C8170`: opnum 0, `RpcBindingFree`, then `CleanupByteCodeRpcServer`, or waits 15 s for the process (`TerminateProcess` after that), and `DeleteAppContainerProfile`.

The generation can be cancelled by a temporary WNF state (`PreCompilation::ByteCodeGenerationEngine::CreateCancelNotificationStateName`, [WNF](#wnf-states)). Packages to compile later are queued in `HKLM\Software\Microsoft\Windows\CurrentVersion\AppX\ByteCodeQueue`.

### RPC client

Interface `{43D210C2-4DFB-44D0-AB40-31AAB2E980F3}` version 1.0 (MIDL stub descriptor 0x1002C950), served by `ByteCodeGenerator.exe`:

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `sub_100C8170` | `sub_100C700C` | binding only | End of the session |
| 1 | `sub_100C7FE0` | `sub_100C80B8` | `[in] enum16`, `[in]` struct (by value), `[in, ref]`, `[in, ref]`, `[in] long`, `[in]` (type 12), `[in] long count`, `[in]` struct (by value), `[out] long *` | Generates the byte code of the files into the duplicated file handle |

Interface `{B58AA02E-2884-4E97-8176-4EE06D794184}` version 1.0 (stub descriptor 0x1002D760):

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `sub_100CB700` | `sub_1009AE54` (from `sub_1009AD00`, `sub_1009B00C`) | `[in, out]` command buffer, `[in, out] long *size` | Sends a command with an AppUserModelId |

The binding (`sub_100CB5AC`) is `ncalrpc` with a dynamic endpoint, `RpcBindingSetAuthInfoExW(…, RPC_C_AUTHN_LEVEL_PKT_PRIVACY, RPC_C_AUTHN_WINNT, …)` with a QoS that requires the server to be LocalSystem (`S-1-5-18`, `AllocateAndInitializeSid(…, 0x12)`). The call is tried a second time if it fails with 1753.  
The command (`sub_1009AE54`, 292 bytes + SID): +0x00 = 1, +0x04 = 0x04800000, +0x08 = a type (2 from `sub_1009AD00`), +0x18 = AppUserModelId (up to 130 characters), +0x11C = a state from the package information, +0x120 = a value, +0x124 = the user SID. The class keeps whether the `Sysmain` service is running (`sub_1009AB94`, `sub_100CB7F4`), so the server is probably SysMain (application prefetch) ?

### WNF states

The service uses no well-known WNF state. Instead it creates temporary state names (`NtCreateWnfStateName(…, WnfTemporaryStateName, 0, …)`):

| Created by | Max size | Security | Data |
|------------|----------|----------|------|
| `CreateWnfStateNameImplementation` → `sub_100506F0` (RPC opnum 1), kept in the cache `wnfStateNameCache` | 2048 | Built by `sub_10050510` from the token of the impersonated client (the client's SID) | Progress of the deployment request that the client passes to opnum 0 (`sub_10050290`, `RtlPublishWnfStateData`): 16 bytes (state, …; +0x00 = 2 at the end of a volume request), followed by an error text if any (`sub_10041638`, at most 2048 bytes) |
| `sub_100397B4` (byte code generation engine, cancel notification) | 4 | `D:(A;;GA;;;SY)(A;;GR;;;BU)(A;;GR;;;AC)` | 4 zero bytes, published when a new deployment operation starts (`sub_10039528`) |

When a state isn't needed any more, `sub_10037BA0` waits until its subscribers go away (`RtlWaitForWnfMetaNotification(…, 8, 500, 100, …)`) and deletes it (`NtDeleteWnfStateName`). The opnum 2 `CancelDeploymentImplementation` finds the request by its progress state name.

### Registry

| Key (HKLM unless stated) | Values | Use |
|-----|--------|-----|
| `SOFTWARE\Microsoft\Windows\CurrentVersion\Appx` | `PackageRepositoryRoot`, `ExtensionsModule` | Repository folder, extension handlers DLL |
| `Software\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\` (`InboxApplications`, `Staged`, `Deleted`, `EndOfLife`, `DownlevelInstalled`, `<user SID>`) | | Packages installed for all users (shared with AppXAllUserStore.dll) |
| `Software\Microsoft\Windows\CurrentVersion\AppX\PackageVolumes` | `MountPoint`, `SisPath`, `Name`, `Flags`, `NextVolumeIndex` | Package volumes |
| `Software\Microsoft\Windows\CurrentVersion\AppX\NewDeploymentOperation` | `<package full name>` / `AllPackages` = 1 | Deployment in progress |
| `Software\Microsoft\Windows\CurrentVersion\AppX\ByteCodeQueue`, `…\AppX\PurgeList` | | Byte code to generate, files to purge |
| `Software\Microsoft\Windows\CurrentVersion\Policies\AppX\Deployment\PackageManager` | `PackageManagerState`, `Type`, `PauseEvent`, `RestartEvent` | Pause / restart of the package manager |
| `Software\Microsoft\Windows\CurrentVersion\Policies\AppX\Deployment\OSIntegration` | `OsimState` ? | OS integration state |
| `Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages`, `…\Repository\Families\%s\%s`, `…\AppModel\PackageRepository\Packages` (per user, `RegOpenUserClassesRoot`) | | Per-user package registration (mini-repository) |
| `Software\Classes\ActivatableClasses\Package`, `Software\Classes\Extensions\ContractId\Windows.Launch\PackageId` | `ActivatableClassId`, `Server` (`ExePath`, compared with `wwahost.exe`) | Registration of the applications |
| `Software\Microsoft\Windows\CurrentVersion\AppHost` | `EnableWebContentEvaluation` | JavaScript applications |
| `Software\Policies\Microsoft\WindowsStore` (HKLM and HKCU) | `RemoveWindowsStore` | Store policy |
| `SOFTWARE\Policies\Microsoft\Windows\Appx` | `AllowAllTrustedApps`, `AllowDeploymentInSpecialProfiles` | Sideloading policies |
| `SOFTWARE\Policies\Microsoft\Windows\SettingSync`, `Software\Microsoft\Windows\CurrentVersion\SettingSync\…` | `EnableBackupForNonStoreApps`, `CollectionStagingRootPath`, … | Settings sync of the application data |
| Key with `DevelopmentMode` (`sub_10050A68`) | `DevelopmentMode` | Development mode deployments |

### Error report

When a deployment fails, `sub_1006C22C` creates a non-critical WER report `AppxDeploymentFailureBlue`. Its parameters are the package full name, the HRESULT, the ETW event ID, the deployment state, the extension handler and the OSIM state. A text file is attached (UTF-16, with `AppXDeploymentServer version`, `Deployment Operation`, `Result code`, `Failed component name`, `Component failure code`, `OSIM state`, `Package Manager State`, `ETW Event ID`), together with copies of `%windir%\windowsupdate.log` and of the `Microsoft-Windows-AppXDeploymentServer/Operational` and `Microsoft-Windows-AppXPackaging/Operational` channels (`EvtExportLog`, `.evtx`). The report is sent with `WerReportSubmit`.

### ETW

Provider `{3F471139-ACB7-4A01-B7A7-FF5DA4BA2D43}` (`Microsoft-Windows-AppXDeploymentServer`, channel `Microsoft-Windows-AppXDeploymentServer/Operational`), registered in `DllMain` (`McGenEventRegister`, `sub_1004A238`; enable bits in `dword_100DF680`). Most functions write events: entry and exit of the RPC procedures, applicability results, the steps of each request, and every failure with the source line (`sub_10034C70`, `sub_10036980`). There are too many event descriptors to list here. A few errors are written by functions that register the provider themselves, write one event and unregister it (`EtwEventRegister` / `EtwEventWrite` / `EtwEventUnregister`): events 7400 (0x1CE8, `sub_1003BFC4`), 7402 (`sub_10077150`), 7403 (`sub_10077248`), 7406 and 7407 (`sub_10077340`), all level 2 (error), channel 0x11, keyword 0x4000000000400000. WPP tracing is registered with `RegisterTraceGuidsW` as well.
