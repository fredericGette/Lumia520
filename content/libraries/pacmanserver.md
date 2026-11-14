## pacmanserver.dll

The Package Manager ("PacMan") of Windows Phone 8.1: the system service that installs, updates, uninstalls, moves and enumerates the applications, and keeps their Start tiles, tasks, extensions, background agents and licences.  
`pacmanserver.dll` is a large C++ svchost service DLL (892 928 bytes, 3 155 functions, no symbols but RTTI and one trace string per method: `PackageManager::BeginInstall`, `CPMDeploymentManager::BeginAppXInstall`, …), registered as the service `pacmanservice`. It's the out-of-process COM server of the class `CLSID_PMSvc` `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` (object `CPMSvc`, 15 interfaces: `IPMDeploymentManager`, `IPMEnumerationManager`, `IPMTileManager`, …, see [COM server](#com-server)) and of the deployment extension handler class `{423ADA85-AF21-49D9-BDDF-19ECAD616205}` (`CPMDEHExt`). Every method checks a capability of the caller (`ID_CAP_PM_INSTALL`, `ID_CAP_PM_1ST_PARTY`, …) and forwards to a global `PackageManager` object. The applications and their tiles are stored in an ESE database (`PackageManager\pacman.edb`); XAP packages are deployed by the service itself (manifest parsing, signature and licence checks, chamber and security provisioning), AppX packages through `Windows.Management.Deployment.PackageManager` / the AppX deployment server ([AppXDeploymentServer.dll](./appxdeploymentserver.md), reached through [AppXDeploymentClient.dll](./appxdeploymentclient.md)). The service starts helper processes for the long jobs (`InstallerWorker.exe`, `mdilbinder.exe`, `XbfGenerator.exe`, `hubtilerestorehost.exe`), notifies its clients through named pipes `\\.\pipe\PMCN…`, enables the live tile Task Scheduler tasks and publishes WNF states.  
Its clients include the PacMan client library linked in [Alarms_NoUI.exe](../applications/alarms_noui.md#com), [AlarmsSettingHandler.dll](./alarmssettinghandler.md) and [ShellChrome.dll](./shellchrome.md), and [BtsCli.dll](./btscli.md) / [BtServ.dll](./btserv.md), which use it to map an application to its product ID. The svchost host, the helper executables and the test hook `Pacmanth.dll` aren't documented here.

Location on the phone: `C:\Windows\System32\pacmanserver.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| ESENT | `JetCreateInstanceW`, `JetSetSystemParameterW`, `JetInit`, `JetTerm`, `JetBeginSessionW`, `JetEndSession`, `JetCreateDatabaseW`, `JetAttachDatabaseW`, `JetDetachDatabaseW`, `JetOpenDatabaseW`, `JetCloseDatabase`, `JetBackupInstanceW`, `JetCreateTableColumnIndexW`, `JetOpenTableW`, `JetCloseTable`, `JetDeleteTableW`, `JetAddColumnW`, `JetCreateIndex2W`, `JetDeleteIndexW`, `JetGetTableColumnInfoW`, `JetGetTableIndexInfoW`, `JetSetCurrentIndexW`, `JetBeginTransaction`, `JetCommitTransaction`, `JetRollback`, `JetPrepareUpdate`, `JetSetColumns`, `JetUpdate`, `JetDelete`, `JetMakeKey`, `JetSeek`, `JetMove`, `JetRetrieveColumns` |
| [SecRuntime](./secruntime.md) | `CapabilityCheck`, `CheckPrincipalClassCapabilityAuthorization`, `CheckCertificateChainCapabilityAuthorization`, `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor`, `BuildSecurityDescriptorForSharingAccess`, `GetChamberSid`, `GetChamberSidFromId`, `CreateProcessInChamber`, `QueryExecutableProperties`, `ReleaseExecutableProperties`, `GetDeveloperUnlockState` |
| ChamberProf | `CreateChamberProfile`, `UpdateChamberProfile`, `DeleteChamberProfile`, `DeleteChamberProfileAfterMove`, `ApplyCodeFolderACL`, `GetChamberFolderPath` |
| PreAuthz | `AddTrustedExecutable`, `AddTrustedExecutableFromCatalog`, `AddTrustedPreInstalledExecutable` |
| WPTrust | `SV_AuthenticateAppXSignatureFile`, `SV_AuthenticateEmbeddedSignedFile`, `SV_DeallocateSignedFileInfoMember` |
| EMSVCS | `CreateExecutionManager`, `CreateDebugManager`, `CreateBackgroundWorkerManager` |
| EMCLIENT | `RmAccessCheck`, `CancelAgentRequests` |
| WpnPhoneExt | `DeliverPhoneLegacyTileNotification` |
| InvalidLicenseUX | `LicenseInvalidDialog` |
| ZipContainer | `ZipContainerInitialize`, `ZipContainerUninitialize`, `ZipContainerCreateArchiveOnFile` |
| Zmf_Client | `ZmfClientInitialize`, `ZmfClientShutdown`, `AppxDownloadCreateSession`, `AppxDownloadReleaseSession` |
| AppxApplicabilityEngine | `GetApplicablePackagesForUser`, `FreeApplicablePackages` |
| ModernApiExtHost | `ProductInfoFromPackageFullName` |
| api-ms-win-appmodel-runtime-l1-1-1, -identity-l1-2-0, -state-l1-1-1 | `GetPackagesByPackageFamily`, `FindPackagesByPackageFamily`, `GetPackagePathByFullName`, `GetPackageFamilyName`, `PackageFamilyNameFromFullName`, `ParseApplicationUserModelId`, `AppXUpdatePackageCapabilities`, `OpenStateExplicit`, `GetStateFolder`, `CloseState` |
| USERENV | `DeriveAppContainerSidFromAppContainerName` |
| PhoneBrokerClient | `CreatePhoneBrokerClient` |
| HardwareConfiguration | `IsHardwareOnDevice`, `IsResolutionSupported` |
| PHONEINFO | `QueryPhoneInformation` |
| WPGLOBUTIL | `InitializeAppxScaleFactors`, `OnUserProfileChanged` |
| WPCOREUTIL | `SHGetKnownFolderPath`, `GetAppStorageFolder`, `GetStorageStateName`, `GetStorageSettings`, `GetStorageDeviceInfo`, `CreateStreamOnFile`, `MoveFileInheritSecurityW`, `RecursiveCreateDirectory`, `RecursiveRemoveDirectoryEx` |
| WerApiExtHost | `TelGetProcessFlags`, `TelSetProcessFlags` |
| GwpCPC | ordinal 9 |
| FLTLIB | `FilterInstanceFindFirst`, `FilterInstanceFindClose` |
| XmlLite | `CreateXmlReader` |
| CRYPT32, bcrypt | certificate chains, `CryptQueryObject`, `CryptMsgGetParam`, `CertGetNameStringW`, …; `BCryptOpenAlgorithmProvider`, `BCryptCreateHash`, `BCryptHashData`, `BCryptVerifySignature`, `BCryptDecrypt`, … (SHA256, ECDSA_P256: signatures and encrypted XAPs, `EXapDecrypter`) |
| WINHTTP | `WinHttpCrackUrl` |
| RPCRT4 | `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingFree`, `NdrClientCall2`, `I_RpcBindingInqLocalClientPID`, `RpcServerInqCallAttributesW`, `I_RpcExceptionFilter` |
| ntdll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlPublishWnfStateData`, `NtFsControlFile`, `NtQuerySystemInformation`, `NtQueryKey`, `RtlDosPathNameToNtPathName_U`, `WinSqmStartSession`, `WinSqmEndSession`, `WinSqmAddToStreamEx`, `WinSqmIncrementDWORD`, `DbgPrint`, SID and heap helpers |
| api-ms-win-core-com-l1-1-1, OLEAUT32, winrt-l1-1-0, winrt-string, winrt-error | `CoRegisterClassObject`, `CoResumeClassObjects`, `CoRevokeClassObject`, `CoAddRefServerProcess`, `CoReleaseServerProcess`, `CoCreateInstance`, `CoImpersonateClient`, `CoRevertToSelf`, `CoGetCallContext`, `CoDisconnectContext`, BSTR / VARIANT / SAFEARRAY, `RoActivateInstance`, `RoGetActivationFactory`, `Windows*String*`, `RoOriginateError` |
| api-ms-win-service-core-l1-1-1 | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-core-registry-l1-1-0, -l2-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegGetValueW`, `RegQueryValueExW`, `RegSetValueExW`, `RegSetKeyValueW`, `RegDeleteValueW`, `RegDeleteKeyExW`, `RegDeleteTreeW`, `RegEnumKeyExW`, `RegEnumValueW`, `RegSaveKeyW`, `RegRestoreKeyW`, `RegSetKeySecurity`, `RegOpenCurrentUser`, `RegOpenUserClassesRoot`, … |
| api-ms-win-core-file-l1-2-1, kernel32-legacy, path, shlwapi-legacy, url | files, directories, volumes (`GetVolumePathNameW`, `GetVolumeNameForVolumeMountPointW`), `CopyFileW`, `PathCch*`, `Path*W`, `PathCreateFromUrlW` |
| api-ms-win-core-namedpipe-l1-2-0, io | `CreateNamedPipeW`, `ConnectNamedPipe`, `GetOverlappedResult`, `CancelIo`, `CancelIoEx` |
| api-ms-win-core-processthreads-l1-1-2, security-base, sddl, lsalookup, provider | `CreateThread`, `TerminateThread`, `GetExitCodeProcess`, `OpenProcessToken`, `OpenThreadToken`, `GetTokenInformation`, `AdjustTokenPrivileges`, `LookupPrivilegeValueW`, `ImpersonateLoggedOnUser`, `ConvertStringSidToSidW`, `ConvertSidToStringSidW`, `Get/SetNamedSecurityInfoW`, `GetSecurityDescriptor*` |
| ext-ms-win-session-usertoken-l1-1-0 | `QueryUserToken` |
| api-ms-win-core-threadpool-l1-2-0, -legacy, synch, handle, memory, heap-obsolete, sysinfo, timezone, string, localization, processenvironment, shlwapi-obsolete, util, libraryloader | thread pool work and waits, `QueueUserWorkItem`, locks, events, semaphores, file mappings, `LoadLibraryExW`, `GetProcAddress`, `SHLoadIndirectString`, … |
| api-ms-win-shcore-stream-l1-1-0 | `SHCreateStreamOnFileEx` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-delayload-l1-1-1 | `DelayLoadFailureHook`, `ResolveDelayLoadedAPI` |
| msvcrt | `malloc`, `free`, `memcpy`, `wcs*`, `swscanf_s`, `_wtoi64`, `rand`, C++ exceptions, `__RTDynamicCast`, `_initterm`, `__dllonexit`, … |

The msvcrt imports, `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind`, `UnhandledExceptionFilter`, `SetUnhandledExceptionFilter`, `DebugBreak`, `DecodePointer` and the delay-load helpers are the Visual C++ CRT startup, C++ exception, delay-load and `/GS` security cookie code. Most imports go through small wrapper functions (0x1006A780…0x1006AF00).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `<HKLM\System\Features\Lockdown>` (a DLL path) | `RegGetValueW` + `LoadLibraryW` + `GetProcAddress("LockDownMgrIsAppAllowed")` ([Initialisation](#initialisation)) | Lockdown (kid's corner / assigned access ?) filter of the applications; no filter if the value is missing |
| `C:\Windows\System32\Pacmanth.dll` | `LoadLibraryW` + `GetProcAddress("ProduceFactory")` (`sub_1003DFEC`, when `HKLM\Software\Microsoft\PacMan\OrchestratorActivityFactory` exists), `GetProcAddress("IsResolutionSupported")` / `("IsHardwareOnDevice")` (`sub_10086908`, `sub_10086A5C`, when `HKLM\Software\Microsoft\PacMan\HardwareConfigLib` exists) | Test hook: replaces the install activities factory and the hardware checks of the manifest (otherwise HardwareConfiguration.dll) |
| [AppXDeploymentClient.dll](./appxdeploymentclient.md) | `LoadLibraryW` + `GetProcAddress("GetApplicability")` (`sub_1003DBA0`) | Applicability of an AppX bundle |
| `Windows.ApplicationModel.dll` | `LoadLibraryW` (`sub_100891A8`, `sub_10090F4C`, `sub_10094AB4`, `sub_100A52E8`) | AppX deployment (`AppXDeploymentServerWrapper::RemovePackage`, `GetApplicabilityForBundleUsingPFN`, tiles of modern applications) |
| `ZipContainer.dll` | `LoadLibraryW` + `ZipContainerInitialize`, `ZipContainerUninitialize`, `ZipContainerCreateArchiveOnFile` (`sub_10086BC4`) | Archives (also statically imported) |
| `sqlcese35.dll` | `LoadLibraryW` + `SqlCeMountDBVol`, `SqlCeUnmountDBVol` (`sub_10086C80`) | `CPMDeploymentManager::ReindexSQLCEDatabases`: re-index the `*.sdf` databases of the applications |
| `advapi32.dll` / `API-MS-Win-Core-LocalRegistry-L1-1-0.dll` | `LoadLibraryExW` + `GetProcAddress("RegDeleteKeyExW")`, fallback `RegDeleteKeyW` (`sub_10078134`) | Registry provisioning of applications |
| `<System32>\InstallerWorker.exe` | Background worker (`CreateBackgroundWorkerManager`, `sub_10052BDC`), command line `"%ls\%ls %ls \"%ls\" \"%ls\" %d %d"`, exit code read | `InstallWorkerManager::LaunchInstallWork`: install work out of the service (`OR_INSTALL_WORKER`) |
| `<System32>\mdilbinder.exe` | Background worker (`sub_10096D38`), command line `"%ls\%ls %ls %ls %ls %ls %ls %i %i %i"` | MDIL binding (native images) of .NET applications (`MDILFileList*.xml`) |
| `XbfGenerator.exe` | `CreateProcessInChamber` (`sub_10096FBC`): `/data "…" /xbftemp "…" /install "…" /framework "%SYSTEMROOT%\system32" /targetplatformversion "x.y" /productId "{…}"` [`/apprepository "…"`] [`/partial "…"`], timeout `XbfGeneratorTimeoutOverride` | Compiled XAML (`*.XbfContainer`) for the current locale |
| `<System32>\hubtilerestorehost.exe` | Background worker (`sub_1003B684`, chamber `HubTileRestoreHost`, timeout `HubRestoreTimeoutMs`) | Restore the tiles of hub applications |
| `<LocalAppData>\PackageManager\pacman.edb` (`pacman.snt`) | ESENT, instance `PACMAN_JET_INSTANCE` ([Database](#database)) | Applications, tiles, tasks, extensions, agents, licences |
| `WMAppManifest.xml`, `AppManifest.xaml`, `WMAppPRHeader.xml`, `WPInteropManifest.xml`, `XnaManifest.xml`, `AppxManifest.xml`, `AppxSignature.p7x`, `AppxBlockMap.xml`, `AppxMetadata\CodeIntegrity.cat`, `WindowsPhoneReservedAppInfo.xml`, `FirstPartyCapabilities.xml`, `MDILFileList*.xml`, `resources.pri` | XmlLite / MSXML, `CreateFileW` | Package manifests, signatures and resources |
| `%sWPSystem\Apps\WindowsApps\%s`, `%sWPSystem\AppRepository\%s`, `%sWPSystem\AppData\Local\Packages`, `%s\Data\USERS\DefApps\APPDATA\Local\Packages`, `c:\data\PROGRAMS`, `C:\windows\system32\aghost.exe` / `aghostsvcs.dll` | path templates (`%s` = system drive or SD card volume) | Install, data and repository folders; Silverlight host of the XAP background tasks |
| MSXML 6 `{88D96A05-F192-11D4-A65F-0040963251E5}` (`IXMLDOMDocument` / `IXMLDOMDocument2`), schema cache `{88D96A07-…}` | `CoCreateInstance` | Manifest and policy XML (`policy.xsd`) |
| AppX factories `{5842A140-FF9F-4166-8F5C-62F5B7B0C781}` (`IAppxFactory`), `{378E0446-5384-43B7-8877-E7DBDD883446}` (`IAppxBundleFactory`), `OpcFactory` `{6B2D6BA0-9F3E-4F27-920B-313CC426A39E}` (`IOpcFactory` `{6D0B4446-CD73-4AB3-94F4-8CCDF6116154}`, names from [AppXDeploymentServer.dll](./appxdeploymentserver.md#dependencies)) | `CoCreateInstance` (in-proc) | Reading AppX packages and bundles |
| `{C2F03A33-21F5-47FA-B4BB-156362A2F239}` (`IServiceProvider`; the immersive shell, which [AppXDeploymentServer.dll](./appxdeploymentserver.md#dependencies) queries for `SID_ProcessLifetimeManagerControl`), `{0C9281F9-6DA1-4006-8729-DE6E6B61581C}` | `CoCreateInstance(CLSCTX_LOCAL_SERVER)`, both for the service `{9FA045CB-B9B3-47BA-842F-E2AB458F2B0C}` (`sub_100510B4`, `sub_10085738`, `sub_10088470`, …) | ? (out-of-process server not identified) |
| `{228826AF-02E1-4226-A9E0-99A855E455A6}` (IID `{9767060C-9476-42E2-8F7B-2F10FD13765C}`) | `CoCreateInstance(0x404)` (`sub_100853B4`) | ? (also created by [ShellChrome.dll](./shellchrome.md#dependencies)) |
| `Windows.Management.Deployment.PackageManager` ([AppXDeploymentClient.dll](./appxdeploymentclient.md#packagemanager)), `Windows.Foundation.Uri` | `RoActivateInstance` | AppX deployment |
| RPC server of the Task Scheduler service (`ITaskSchedulerSvcRpc`) | `RpcBindingCreateW` ([RPC](#rpc)) | Live tile schedule tasks |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `ServiceMain` | 0x100687E8 | `DWORD argc, LPWSTR *argv` |
| 2 | `SvchostPushServiceGlobals` | 0x100699AC | `SVCHOST_GLOBAL_DATA *` (saved in `dword_100C602C`) |
| 3 | `DllCanUnloadNow` | 0x1006BE00 | none, always returns `S_FALSE` (1) |
| 4 | `DllGetClassObject` | 0x10078FF4 | always returns `E_FAIL` (the classes are only registered by the service) |
| 5 | `PackageManagerInitialize` | 0x100689EC | `PackageManager **` |

`PackageManagerInitialize(&p)`: `E_INVALIDARG` if `p` is NULL, `E_FAIL` if already called; otherwise creates and initialises the global `PackageManager` ([Initialisation](#initialisation)) and returns it.

### Startup

`DllEntryPoint` (0x1006B574): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then `dllmain_dispatch` (0x1006B280). `DllMain` (`sub_100791A0`) only saves the module handle and calls `DisableThreadLibraryCalls`. The ETW providers are registered on first use.

### ServiceMain (0x100687E8)

1. `RegisterServiceCtrlHandlerExW(L"pacmanservice", ServiceCtrlHandler)` (`sub_10079D74`: on `SERVICE_CONTROL_STOP` sets the stop event); `SERVICE_START_PENDING`.
2. Creates the stop event and the "classes registered" event, then registers a wait on the stop event through the svchost globals (method +0x60 of the structure given by `SvchostPushServiceGlobals`, callback `ServiceStop`, `sub_1007DC80`).
3. `StartService` (`sub_1006893C`): if `argv[1]` is `L"Debug"`, `DebugBreak()`; sets bit 0 of the WER process flags (`TelSetProcessFlags`); `PackageManagerInitialize`; then registers the class objects inside the COM context of the process (`CoCreateInstance(CLSID_ContextSwitcher {0000034E-…}, IID_IContextCallback)`, `ContextCallback(RegisterClasses)`): `CoRegisterClassObject({B9E511FC-…}, CObjCF<CPMSvc>, CLSCTX_LOCAL_SERVER, REGCLS_MULTIPLEUSE | REGCLS_SUSPENDED)`, the same for `{423ADA85-…}` (`CObjCF<CPMDEHExt>`), and `CoResumeClassObjects` (`sub_100691A8`). Waits 5 s for it (`E_FAIL` on timeout), `CoAddRefServerProcess`.
4. `SERVICE_RUNNING`, or `SERVICE_STOPPED` with the error.

`ServiceStop` (`sub_1007DC80`): `CoInitializeEx`, `SERVICE_STOP_PENDING`, revokes the class objects in the same COM context (`sub_1007AEF4`), `CoReleaseServerProcess`, `PackageManager` method +0xFC (shutdown), `SERVICE_STOPPED`.

### Initialisation

`PackageManagerInitialize` allocates the `PackageManager` object (0x1C8 bytes, constructor `sub_10068AB8`, vtable 0x10001F70, global `dword_100C5A88`, also kept in `dword_100C6090` by the service). It contains a critical section, request queues, an `SDCardCleanupTask` (+0xE4) and an `AppStateChangeTask` (+0x110), the notification sender (+0x30, see [Notifications](#notifications)) and the live token subscriptions. `PackageManager::Initialize` (`sub_1006A4B0`):

1. Opens the database (`PacManDBManager` singleton, `sub_1005B79C` → `sub_10066E38`, object at `unk_100C60BC`) and creates the helper objects.
2. Creates a semaphore and the startup thread `sub_1006980C` (`OnUserProfileChanged`, then three startup checks of the applications: `sub_10069840`, `sub_100699C0`, `sub_10069B84`).
3. Creates the thread pool work of the `SDCardCleanupTask` (`sub_10067B4C`).
4. Subscribes to the WNF state 0x418A063EA3BC3875 with the callback `OnShellReady` (`sub_100830E0`), see [WNF states](#wnf-states).
5. Reads `HKLM\System\Features\Lockdown` (`REG_SZ`), loads that DLL and keeps `LockDownMgrIsAppAllowed` in `off_100C5A80` (ETW event 779 if it isn't there).
6. ETW event 743 with the result; on failure, stops the startup thread (`sub_100B373C`) and the thread pool work.

`OnShellReady` (`sub_100830E0`): subscribes to the two storage WNF states of `GetStorageStateName(0, 2)` and `GetStorageStateName(4, 2)` (callback `sub_100B6908`: SD card inserted / removed, `PackageManager::OnSDCardStateChange`), starts the `AppStateChangeTask` work, calls method +0x154 of `PackageManager`, then `NotifyAppsReady` (`sub_1007F964`, publishes the WNF state 0x11900B29A3BC6875) unless a request of type 14 is still queued (it's published at the end of that request, `PackageManager::DoPostOperation`, `sub_100A1A64`).

### COM server

`CObjCF<CPMSvc>::CreateInstance` (`sub_10065664`) returns a new `CPMSvc` (0x40 bytes, reference count at +0x3C, `CLASS_E_NOAGGREGATION` with an outer object). Its `QueryInterface` (`sub_100657B0`) and the RTTI give the interfaces:

| Offset | Interface | IID | Vtable | Methods |
|--------|-----------|-----|--------|---------|
| 0x00 | `IPMDeploymentManager` | `{35F785FA-1979-4A8B-BC8F-FD70EB0D1544}` | 0x10002CDC | 34 |
| 0x04 | `IPMDeploymentManager2` | `{75E430A7-9559-4828-98DD-BC657620AB87}` | 0x10002C8C | 17 |
| 0x08 | `IPMEnumerationManager` | `{698D57C2-292D-4CF3-B73C-D95A6922ED9A}` | 0x10002C34 | 19 |
| 0x0C | `IPMEnumerationManager2` | `{D83400E1-A7A6-4990-9B84-10490AFF2063}` | 0x10002C14 | 5 |
| 0x10 | `IPMTileManager` | `{D622EEDE-5363-41FC-91C3-88E321191A34}` | 0x10002BEC | 7 |
| 0x14 | `IPMTileManager2` | `{D29905F5-BAA2-48C5-A98A-F0DC7E122B84}` | 0x10002BC8 | 6 |
| 0x18 | `IPMTileManagerInternal` | `{FDD4D1CC-282A-405C-B7B0-571C2BE66CAC}` | 0x10002BB0 | 3 |
| 0x1C | `IPMBssWriter` (`CBssDbWriter`) | `{1D275BED-9E6B-4F08-9A69-20B1B12C95AE}` | 0x10002B8C | 6 |
| 0x20 | `IPMBssManager` (`CBssDbManager`) | `{96F5B3C3-9610-427C-A522-7DABEAE417D5}` | 0x10002B58 | 10 |
| 0x24 | `IPMInternal` | `{5ECEF0F3-AD16-434D-8940-EDC1BB4617D9}` | 0x10002B34 | 6 |
| 0x28 | `IPMLiveTileJobManager` | `{15E673FD-0497-4CB3-97CB-99E698DD3B66}` | 0x10002B14 | 5 |
| 0x2C | `IPMLicenseManager` (`CLicenseManager`) | `{11ED725B-8820-45F8-96E6-6845524E46DA}` | 0x10002AF8 | 4 |
| 0x30 | `IPMLicenseManager2` | `{1B83665E-A1B1-455A-BEAC-C680B48BDA10}` | 0x10002AE0 | 3 |
| 0x34 | `IPMTestHook` | `{C1CB379E-BAEA-4BA5-9675-27FB34184E9E}` | 0x10002AB4 | 8 |
| 0x38 | `IFastRundown` | `{00000040-0000-0000-C000-000000000046}` | 0x10002AA4 | 1 |

"Methods" doesn't count `IUnknown`. The objects returned by the enumerations are `Application` (`IPMApplicationInfo` `{50AFB58A-438C-4088-9789-F8C4899829C7}`; `IPMApplicationInfo2` `{2925390A-D947-4062-9DAD-CF6F60E6A707}` is only returned when bit 0x400 of the flags at +0x114 is set, it's the embedded `Application2` at +0x148), `Token` (`IPMTileInfo`), `Token2` (`IPMTileInfo2`), `Task`, `Extension`, `BackgroundServiceAgent`, `TokenJob` and their enumerators (`IPM*Enumerator`).

**Security.** Most methods start with `CheckCallerCapability(name)` (`sub_100619B8`): gets the token of the client (`sub_10061A28`: `CoImpersonateClient`, `OpenThreadToken`; a call from the service process itself is always allowed), then `SecRuntime!CapabilityCheck(token, name, &granted)`; `E_ACCESSDENIED` (0x80070005) if not granted. The capabilities used are `ID_CAP_PM_INSTALL`, `ID_CAP_PM_1ST_PARTY`, `ID_CAP_PM_BSS`, `ID_CAP_ENTERPRISE_ENROLLMENT` (enterprise install / uninstall) and, through `SecurityValidator<1>::CheckPermissionForPMDebugAPI` (`sub_1004EEF8`), `ID_CAP_DEBUG_FOLDERS` together with `GetDeveloperUnlockState` (developer tools: uninstall, update, rebind of a sideloaded application). The `IPMEnumerationManager` getters that take a filter select a `PacManDBManager` method from the filter value (e.g. `sub_10056930`: filters 0…7 for the application enumerator, `sub_100596B4`: 8…11, `sub_100A1260`: 17…25, `sub_10069758`: 26…30); some filters need `ID_CAP_PM_1ST_PARTY`, others don't.

The methods, by vtable index (0…2 = `IUnknown`), with the name of their trace string when there is one:

| Interface | Index: method (capability) |
|-----------|----------------------------|
| `IPMDeploymentManager` | 3…7: install / update / deploy of XAP packages (`ID_CAP_PM_INSTALL`; `PackageManager::BeginInstall`, `BeginUpdate`, `BeginDeployPackage` ?); 8: debug API check; 9 `BeginUpdateDeployedPackageLegacy`; 10 `BeginUninstall` (`ID_CAP_PM_INSTALL` or `ID_CAP_ENTERPRISE_ENROLLMENT`, or debug); 11 `BeginEnterpriseAppInstall`, 12 `BeginEnterpriseAppUpdate` (`ID_CAP_ENTERPRISE_ENROLLMENT`); 13 `BeginUpdateLicense`, 14 ?, 15 `GetLicenseChallengeByProductID`, 16 ?, 17 `RevokeLicense` (`ID_CAP_PM_INSTALL`); 18 `RebindMdilBinaries` (debug), 19 `RebindAllMdilBinaries`; 20 `RegenerateXbf`, 21 ?, 22 `BeginProvision`, 23 `BeginDeprovision`, 24 `ReindexSQLCEDatabases` (`ID_CAP_PM_1ST_PARTY`); 25 `SetApplicationsNeedMaintenance`, 26 `UpdateChamberProfile` (`ID_CAP_PM_INSTALL`); 27 ? (`ID_CAP_PM_1ST_PARTY`); 28 `BeginUpdateDeployedPackage` (debug); 29 `ReportRestoreCancelled`; 30 ?; 31 `UpdateCapabilitiesForModernApps`, 32 `ReportDownloadStatusUpdate` (`ID_CAP_PM_INSTALL`); 33 `BeginUninstallWithOptions`; 34 `BindDeferredMdilBinaries`; 35 `GenerateXamlLightupXbfForCurrentLocale`; 36 ? |
| `IPMDeploymentManager2` | 3…5: not implemented (`sub_1006C118`); 6 `BeginAppXRegister`, 7 `BeginAppXUninstall`, 8 `BeginAppXInstall`, 9 `BeginAppXUpdate`, 10 ?, 13 ?, 14 `AppxGetApplicabilityUsingProductId`, 15 `BeginAppxDownload`, 16 `BeginMove` (internal storage ↔ SD card), 17 `StartSDCardCleanupTask`, 18 `DeletePackageVolume` (`ID_CAP_PM_INSTALL`); 11 `FindPackages`, 12 `FindPackagesByNamePublisher` (`ID_CAP_PM_1ST_PARTY`) |
| `IPMEnumerationManager` | 3: application enumerator by filter; 4…20: application by product ID / by AUMID, tiles, tasks, extensions, background agents and workers, by filter (`ID_CAP_PM_1ST_PARTY` for 3, 5, 7, 8, 12…15, 17, 18) |
| `IPMEnumerationManager2` | 3: application info from an application ID (used by [BtsCli.dll](./btscli.md#foreground-listener)), 4 `get_TileInfo`, 5, 6 (`ID_CAP_PM_1ST_PARTY`) |
| `IPMTileManager` | 3 `ConstructTile`, 4, 7 (`ID_CAP_PM_1ST_PARTY`), 5, 6 `CommitTileExternal`, 8 `PushUpdateTile` (`DeliverPhoneLegacyTileNotification` with privilege elevation) |
| `IPMTileManager2` / `IPMTileManagerInternal` | `ConstructTileInternal` (several overloads), 5 `DeleteTile`, 7 (`ID_CAP_PM_1ST_PARTY`) |
| `IPMBssWriter` | 3…6 (`ID_CAP_PM_BSS`): create (`PackageManager::ValidateForNotificationCreation`), update and delete the scheduled notifications of the `BSSACTION` table, 7 ? |
| `IPMBssManager` | 3 `GetNotificationIteratorById`, 6 `GetTotalActiveBackgroundAgents`, 7 `GetNotificationByIndex`, 9 `GetNotificationIteratorByLastRunTime`, 10 `GetNotificationIteratorById`, 11 `GetNotificationIteratorByProductId` |
| `IPMInternal` (`ID_CAP_PM_1ST_PARTY`) | 3: register a notification pipe ([Notifications](#notifications)); 4 ?; 5 `ReportInstallProgress`; 6, 7 ? |
| `IPMLiveTileJobManager` (`ID_CAP_PM_1ST_PARTY`) | 3 `AddLiveTokenSubscription` (with `FillLiveTokenSchedule`), 4 ?, 5 `RemoveLiveTokenSubscription`, 6 `UpdateTokenFromXML` |
| `IPMLicenseManager` (`ID_CAP_PM_1ST_PARTY`) | 3, 4, 5 ? |
| `IPMLicenseManager2` | 3 `IsTrialLicense` (package family name → product ID), 4 (`ID_CAP_PM_1ST_PARTY`) |
| `IPMTestHook` (`ID_CAP_PM_1ST_PARTY`) | 3 `UpdateAppState`, 4 `GetAppStorageID`, 5 `UpdateAppStorageID`, 6 `OnSDCardStateChange`, 7 `CheckAppsDuringStartup`, 8 `UpdateAppFlags`, 9 `GetAppFlags` |

The asynchronous `Begin*` methods create a request (`PackageManager::CreateInstallRequest`, `CreateUninstallRequest`, `SendUpdateRequest`, `EnqueueRequest`) for the request queue; the orchestrator runs the activities of the request (`ActivityContext`, saved in the database so that it can be rolled back or resumed after a reboot: `CROCOVERYOFUNINSTALL`, `Enqueue Recovered Uninstall Request: %s`). The orchestrator types are `OR_INSTALL`, `OR_UPDATE`, `OR_UPDATE_LICENSE`, `OR_DBPROVISION_INSTALL`, `OR_DBPROVISION_UNINSTALL`, `OR_DBPROVISION_UPDATE`, `OR_FORCEUNINSTALL`, `OR_INSTALL_WORKER`, `OR_LIGHTUP_INSTALL`, `OR_LIGHTUP_UPDATE`, `OR_SD_MOVE`, `OR_SD_MOVE_LIGHTUP` and `OR_APPX_EMPTY`.

**Deployment extension handlers.** `CPMDEHExt` (class `{423ADA85-AF21-49D9-BDDF-19ECAD616205}`, `QueryInterface` `sub_1007E084`) is called during the deployment of an AppX package to register its Windows Phone specific parts:

| Offset | Interface | IID | Use |
|--------|-----------|-----|-----|
| 0x000 | `IMCVisualElementsDEHExt` | `{3B56A13A-B071-4811-82A4-07631E63D9DB}` | Primary tile, application title and icon (`CPMVisualElementsDEHExt::UpdatePacmanDBRecords`, `WindowsPhoneReservedAppInfo.xml`) |
| 0x090 | `IMCFileTypeAssocDEHExt` | `{15892EC9-6103-4DAD-A8F4-3CBC5F4ED0C5}` | File type associations |
| 0x0CC | `IMCProtocolDEHExt` | `{F403DE30-808A-4FEB-84EF-5371864EA66D}` | Protocols |
| 0x108 | `IMCShareTargetDEHExt` | `{E9A06986-05E2-4911-B94B-50DEE8D188A1}` | Share target |
| 0x140 | `IMCFileOpenPickerDEHExt` | `{BFB872F2-1E12-4B92-9DDF-9C2A051E6BD3}` | File open picker |
| 0x180 | `IMCFileSavePickerDEHExt` | `{1EECD525-6D75-4046-AE79-F291A319D36B}` | File save picker |
| 0x1C0 | `IMCCachedFileUpdaterDEHExt` | `{40890D5F-C127-4B62-A582-41114C064770}` | Cached file updater |
| 0x1F0 | `IMCPacmanFinalizerDEHExt` | `{31FEA5F0-3625-4784-B81B-DDB1A2F3A17D}` | Commit of the PacMan records at the end of the deployment |

### Notifications

`IPMInternal` method 3 (`sub_10064484` → `PackageManager` method +0x88 → `sub_10058468` on the sender at `PackageManager`+0x30) registers a client for the install notifications: the name it gives must contain `\\.\pipe\PMCN` (`wcsstr`, `E_INVALIDARG` otherwise). The service creates the server end (`sub_10057194`): if the caller is another process, a security descriptor that gives access to the caller (`CoImpersonateClient`, `OpenThreadToken`, `BuildSecurityDescriptorForSharingAccess(token, 0, GENERIC_ALL)`), then `CreateNamedPipeW(name, PIPE_ACCESS_OUTBOUND | FILE_FLAG_FIRST_PIPE_INSTANCE | FILE_FLAG_OVERLAPPED, PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_NOWAIT, 2 instances, 8 KB, 8 KB)` and `ConnectNamedPipe` (`sub_100572BC`). The progress and life-cycle notifications are written to the pipe as messages (`CSender::SendNotification`, `IPCTransportSender`; `NotificationsListsHelper::AddLifeCycleNotification`). The message format isn't analysed.

### Database

ESENT instance `PACMAN_JET_INSTANCE`, database `PackageManager\pacman.edb` under `FOLDERID_LocalAppData` of the service (`sub_1006901C`), system files `PackageManager\pacman.snt` (`sub_1005E2EC`). Tables (`TableAccess<…>` classes) and some of their columns:

| Table | Columns |
|-------|---------|
| `Application` | `PRODUCTID`, `APP_TITLE`, `PUBLISHER`, `AUTHOR`, `DESCRIPTION`, `VERSION`, `PATH`, `ICON`, `STATE`, `FLAGS`, `APPINSTALLTYPE`, `INVALIDREASON`, `INSTALLDATE`, `INSTANCEID`, `DEFAULTTASK`, `OFFERID`, `APPPLATVERSION`, `PUBLISHERID`, `MULTICORE`, `APPPLATVERSIONLIGHTUP`, `DATAPATH`, `STORAGEID`, `PACKAGEFAMILYNAME`, `PRAID`, `GENRE`, `TITLE`, `MODIFIEDDATE`, `OPFLAGS`, `TOMBSTONE` |
| `Token` (tiles) | `PRODUCTID`, `TOKENID`, `POSITION`, `TYPE`, `TEMPLATE`, `DATA`, `TASKID`, `TASKPARMS`, `FLAGS`, `ICON`, `LASTTIMERUN`, `APP_TITLE`, `HUBTYPE`, `STATE`, `ORGTEMPLATE`, `ORGDATA`, `SIZE`, `TILEVERSION`, `PACKAGEFAMILYNAME`, `PRAID`, `ICONPATH`, `TITLE`, `TOMBSTONE` |
| `TokenJob` (live tile schedules) | `PRODUCTID`, `TOKENID`, `NEXTSCHED`, `STARTSCHED`, `INTERVALDUR`, `RUNFOREVER`, `MAXRUNCOUNT`, `RUNCOUNT`, `RECURTYPE`, `TOKENDATA`, `ATTEMPTCOUNT`, `DOWNLOADSTATE`, `URLXML` |
| `ApplicationLicense` | `PRODUCT_ID`, `PROHEADER`, `LICENSE`, `TOMBSTONE` |
| `Extension` | `CONSUMERPID`, `EXTENSIONID`, `SUPPLIERPID`, `SUPPLIERTASKID`, `EXTENSIONTITLE`, `EXTENSIONICON`, `EXTRAFILE`, `EXTCATEGORY`, `EXTCONTENTFILETYPELIST`, `EXTDATAFORMATSLIST`, `TOMBSTONE` |
| `Task` | `PRODUCTID`, `TASKID`, `NAVIGATIONPAGE`, `TASKTYPE`, `RUNTIMETYPE`, `ACTIVATIONPOLICY`, `FLAGS`, `IMAGEPATH`, `IMAGEPARAMS`, `TRANSITION`, `BGEXECABILITY`, `TOMBSTONE` |
| `BSA` (background service agents) | `PRODUCTID`, `TASKID`, `CATEGORY`, `BGSPECIFIER`, `BGNAME`, `BGSOURCE`, `BGTYPE`, `SCHEDULEALLOWED`, `DESCRIPTION`, `ISPERIODIC`, `MAXSTARTUPLATENCY`, `EXPECTEDRUNTIME`, `BOOTWORKER`, `TOMBSTONE` |
| `BSSACTION` (scheduled notifications) | `PRODUCTID`, `ACTIONID`, `TASKID`, `STARTTIME`, `ENDTIME`, `ACTIONTYPE`, `RECURRINGTYPE`, `ACTIONSTATE`, `LASTUSERACTION`, `CONTENT`, `FRIENDLYNAME`, `LAUNCHINGCONTEXT`, `SOUND`, `TITLE`, `APPINSTALLPATH`, `APPBASEURI`, `REMINDERID`, `ORIGSTARTTIME`, `LASTRESULT`, `AGENTID`, `LASTRUNTIME`, `AGENTUSESLOCATION`, `DISABLEBY`, `PUSHCHANNEL`, `RECURRINGINTERVAL` |
| `ActivityContext` | `PRODUCTID`, `ACTIVITY_TYPE`, `ORCHESTRATORTYPE`, `ISCANCELLED`, `ISFINISHED`, `ISROLLBACK`, `HREXECUTE`, `HRROLLBACK`, `XAPFILEPATH`, `APPMANIFEST`, `PBLICENSE`, … (state of a running install / uninstall) |

The table/column split of the last columns is inferred from the order of the strings. The tile properties (`Title`, `Count`, `BackgroundImageURI`, `BackContent`, `LargeContent1`… and the templates `TemplateFlip`, `TemplateIconic`, `TemplateCycle`, …) are kept in `DATA` (`CTileProp`, `CTilePropEnum`, `BinaryArrayPackStrategy`).

### RPC

Client of the Task Scheduler service, the same binding as [ReminderEvents.dll](./reminderevents.md#rpc) (`sub_1007C1E0`): `QueryTransientObjectSecurityDescriptor(9, L"ITaskSchedulerSvcRpc\\Server")`, `RpcBindingCreateW` (LRPC, dynamic endpoint, `RPC_C_AUTHN_LEVEL_PKT_PRIVACY`, `RPC_C_AUTHN_WINNT`, identify, server security descriptor), `RpcBindingBind` tried 3 times 500 ms apart.

Interface `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` version 2.0 (stub descriptor at 0x1001D6C8).

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 6 | `sub_1007B140` | `SetLiveTileTaskState` (`sub_10081244`) | `[in] GUID *`, `[in] long` | Enables (1) or disables (0) one of the four live tile tasks |

`SetLiveTileTaskState(?, state, type)` takes the task GUID from the schedule type 0…3 (`E_INVALIDARG` above 3):

| Type | Task GUID | Task name (from the [task store](./taskschedulersvc.md#tasks-of-a-phone)) |
|------|-----------|-----------|
| 0 | `{2B00BA79-D967-404E-B4E2-FB3C963EFA2B}` | `LiveTokenHourly` |
| 1 | `{F14C2492-5908-4808-A2FD-E74D27581F5F}` | `LiveTokenDaily` |
| 2 | `{284FDFA6-37DE-42F7-8235-AB7E3708FC51}` | `LiveTokenWeekly` |
| 3 | `{8ECFF87D-F3EA-4EFD-A0A1-B93E344F6774}` | `LiveTokenMonthly` |

The four tasks start `%systemdrive%\windows\system32\LiveToken.exe` on a list trigger (type 2) of WNF states (`CNET` 1, `SHL` 1, `CNET` 3, `OS` 8).

`AddLiveTokenSubscription` (`sub_100A6458`) enables the task of the schedule (field +0x3C of the subscription); `RemoveLiveTokenSubscription` (`sub_100A625C`) disables it when no subscription of that type is left.

### WNF states

Decoded with `wnf.py`.

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x418A063EA3BC3875 (`.text:0x10002144`) | `SHL`, 7 | – | Subscribed in `PackageManager::Initialize`, callback `OnShellReady` (`sub_100830E0`): shell ready ? |
| `GetStorageStateName(0, 2)`, `GetStorageStateName(4, 2)` | (WPCOREUTIL) | – | Subscribed by `sub_10067EA4`, callback `sub_100B6908`: storage (SD card) state |
| 0x11900B29A3BC6875 (`.text:0x1000214C`) | `DEVP`, 13 | empty | Published by `NotifyAppsReady` (`sub_1007F964`) when the startup checks are done |
| 0x11900B29A3BC4075 (`.text:0x10020298`) | `DEVP`, 8 | 4 bytes: 1 / 0 | Published by `sub_1007B08C(…, 0, value)`: a live tile subscription exists ? |
| 0x11900B29A3BC4875 (`.text:0x100202A0`) | `DEVP`, 9 | 4 bytes: 1 / 0 | Published by `sub_1007B08C(…, 1, value)`: same for the other kind of subscription ? |

`AddLiveTokenSubscription` publishes 1 in one of the two `DEVP` 8 / 9 states (chosen by the subscription); `RemoveLiveTokenSubscription` publishes 0 in both when the last subscription is removed. A failed publication is returned as the NTSTATUS with bit 28 set.

### ETW

Registered on first use (`sub_10066F30`, enable callback `sub_1004E90C`):

| Provider GUID | Registered by | Comment |
|---------------|---------------|---------|
| `{3C42000F-CC27-48C3-A005-48F6E38B131F}` | `sub_10066ED0` (handle `dword_100C6088`) | Main PacMan provider: failed HRESULT with method name and source line (`sub_1004FD0C`, event 714, level 2, task 10, keyword 0x120010), `PackageManager::Initialize` result (event 743, level 4), lockdown DLL missing (event 779, level 3), … |
| `{A0B8AC98-5E7E-40BD-BE8E-96CC6061E0B5}` | `sub_10066ED0` | ? |
| `{F4E559CD-6639-46E0-93F8-2AC9D6D33976}` | `sub_10066ED0` | ? |
| `{6C52775A-44CE-44D3-B266-7400DF95FDC4}` | `sub_10069958` (from `sub_1005B740`) | ? |

### Registry

| Key | Values |
|-----|--------|
| `HKLM\System\Features` | `Lockdown` (path of the lockdown DLL) |
| `HKLM\Software\Microsoft\PackageManager` | `ForceCheckAppBinding`, `SkipReindexingOnInstall`, `FailMDILMaintenance`, `NILocation`, `TempNILocation`, `XbfGeneratorTimeoutOverride`, `XbfGenerationMinVersionMajor`, `XbfGenerationMinVersionMinor`, `HubRestoreTimeoutMs`, `MDILBindTimeoutMs` |
| `HKLM\Software\Microsoft\PackageManager\Blacklist` | ? (read by `sub_1003D2C0`, blocked applications ?) |
| `HKLM\Software\Microsoft\PacMan\` | `OrchestratorActivityFactory`, `HardwareConfigLib` (test hooks, [Dependencies](#dependencies)) |
| `HKLM\Software\Microsoft\DeviceReg\Install` | `MaxUnsignedApp` (number of sideloaded applications allowed, with the developer unlock principal classes `PRINCIPAL_CLASS_ISV/OEM/FIRST_PARTY_DEVELOPER_UNLOCK`) |
| `HKLM\Software\Microsoft\EnterpriseAppManagement\Database\Policy` | `PolicyXml` (enterprise allow / deny list, `//p:AppPolicy/p:Allow/p:App`, `…/p:Publisher`) |
| `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx`, `…\Appx\PackageVolumes` | `PackageRepositoryRoot`, `PackageRoot`, `Name` |
| `HKLM\SOFTWARE\Microsoft\Shell\OOBE` | `Done` |
| `HKLM\System\ResourceManager\BatterySenseSettings` | `LastNotificationTimeStamp` (read and written) |
| `HKLM\SYSTEM\CurrentControlSet\Control\MUI\StringCacheSettings` | `StringCacheGeneration` (incremented) |
| `S-1-5-21-…-2781\Software\Classes\ActivatableClasses\Package\%s\…` | Written for each modern application: `ActivatableClassId\%s` (`DllPath`, `ActivationType`, `TrustLevel`, `Threading`), `Server\%s` (`ExePath`, `CommandLine`, `Instancing`, `Permissions`, `IdentityType`), `Interfaces\%s`, `ProxyStubCLSIDs\%s` (`ProxyStubCLSID`), `CLSID\%s` (`PackageMoniker`, `ActivatableClassId`) |
| `Microsoft\SecurityManager\Applications`, `…\Capabilities`, `…\CapabilityMapping`, `…\WindowsCapabilities` (security metastore) | Provisioning of the application SID, capabilities, privileges and signer certificate (`ProvisionRuntime_ProvisionMarketplaceApplication`, source `src\baseos\prod\securitymodel\provision\runtime\marketplaceapplication\marketplaceapplication.cpp`) |
| `SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications\Applications` | Push notification registration of the applications |
| `Software\Partner\Wallet`, `Software\Microsoft\FMRadio\OEM`, `System\Maps` | ? (strings next to the OEM application checks) |
