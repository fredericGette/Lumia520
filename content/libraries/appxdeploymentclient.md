## AppXDeploymentClient.dll

The client side of the AppX deployment service: it implements the Windows Runtime classes `Windows.Management.Deployment.PackageManager` and `PackageVolume`, plus a few flat exports for system components.  
`AppXDeploymentClient.dll` is a C++/WRL in-process WinRT server (225 280 bytes, 1 254 functions, with public symbols). It doesn't deploy anything itself. Every `PackageManager` method checks its arguments and turns into an LRPC call to [AppXDeploymentServer.dll](./appxdeploymentserver.md) (service `appxsvc`) on the interface `{AE2DC901-…}`, or on `{FF9FD3C4-…}` for `AppxValidatePackages` (see [RPC](#rpc)). The client starts `appxsvc` when the binding fails. The asynchronous operations (`AddPackageAsync`, `RemovePackageAsync`, …) are `ClientDeploymentRequest` objects (`IAsyncOperationWithProgress<DeploymentResult, DeploymentProgress>`). They get their progress and result through a temporary WNF state that the server creates for them ([below](#clientdeploymentrequest)). The DLL also has the MIDL proxy/stub of the `Windows.Management.Deployment` interfaces (`DllGetClassObject`), and some local code that writes the `AppxAllUserStore` registry for push-button reset and runs the "Pre-staged app cleanup" task.  
Its known users are [pacmanserver.dll](./pacmanserver.md), which activates `Windows.Management.Deployment.PackageManager` and calls `GetApplicability` through `GetProcAddress`, and every application that uses the `PackageManager` WinRT class. `wsservice` (Windows Store service), `Windows.ApplicationModel.dll` (behind `Windows.ApplicationModel.Package`), `AppXAllUserStore.dll` and the DLL behind `ext-ms-win-appmodel-deployment-l1-1-0` aren't documented here.

Location on the phone: `C:\Windows\System32\AppXDeploymentClient.dll` ? (the extracted file has no notes).  
Activatable classes: `Windows.Management.Deployment.PackageManager`, `Windows.Management.Deployment.PackageVolume`, `Windows.Management.Deployment.Internal.PackageOperation` (WRL `SimpleSealedActivationFactory`, `DllGetActivationFactory`).  
Proxy/stub: `CLSID_PSFactoryBuffer` `{73959FD1-7360-42F7-807D-622341783DC0}` (`packagemanagerapi_ProxyFileInfo`), for `IPackageManager` `{9A7D4B65-5E8F-4FC7-A2E5-7F6925CB8B53}`, `IPackageManager2` `{F7AAD08D-0840-46F2-B5D8-CAD47693A095}`, `IPackageManager3` `{DAAD9948-36F1-41A7-9188-BC263E0DCB72}`, `IDeploymentResult` `{2563B9AE-B77D-4C1F-8A7B-20E6AD515EF3}`, `IPackageUserInformation` `{F6383423-FA09-4CBC-9055-15CA275E2E7E}`, `IPackageVolume` `{CF2672C3-1A40-4450-9739-2ACE2E898853}` and the parameterized interfaces they use (`IAsyncOperationWithProgress`, `IVector`/`IVectorView`/`IIterable`/`IIterator` of `PackageUserInformation`, …).  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4 | `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingUnbind`, `RpcBindingFree`, `NdrClientCall2`, `NdrAsyncClientCall`, `RpcAsyncInitializeHandle`, `RpcAsyncCancelCall`, `RpcAsyncCompleteCall`, `I_RpcExceptionFilter`; proxy/stub: `NdrDllGetClassObject`, `NdrDllCanUnloadNow`, `NdrStubCall2`, `NdrOleAllocate`, `NdrOleFree`, `CStdStubBuffer_*`, `IUnknown_*_Proxy`, … |
| combase | `ObjectStublessClient3…21`, `NdrProxyForwardingFunction3…5` (proxy/stub) |
| ntdll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlAllocateWnfSerializationGroup`, `NtQueryInformationThread`, `NtOpenFile`, `NtSetInformationFile`, `NtQueryInformationFile`, `NtCreateSection` / `NtMapViewOfSection` / `NtUnmapViewOfSection`, `RtlConvertSidToUnicodeString`, `EtwEventRegister` / `EtwEventWrite` / `EtwEventUnregister`, heap, SRW locks, critical sections, … |
| api-ms-win-core-winrt-l1-1-0, -winrt-string-l1-1-0, -winrt-error-l1-1-1 | `RoInitialize`, `RoUninitialize`, `RoGetActivationFactory`; `WindowsCreateString`, `WindowsCreateStringReference`, `WindowsGetStringRawBuffer`, …, `HSTRING_UserSize` / `UserMarshal` / `UserUnmarshal` / `UserFree`; `RoOriginateError`, `RoOriginateErrorW`, `RoTransformError`, `SetRestrictedErrorInfo`, … |
| api-ms-win-core-com-l1-1-1, OLEAUT32 | `CoInitializeEx`, `CoUninitialize`, `CoCreateInstance`, `CoGetCallContext`, `CoCreateFreeThreadedMarshaler`, `CoGetApartmentType`, `CoTaskMemAlloc` / `Free`, `StringFromGUID2`; `SysAllocStringLen`, `SysFreeString` |
| api-ms-win-appmodel-runtime-l1-1-1, -runtime-internal-l1-1-1, -state-l1-1-2 | `PackageFamilyNameFromFullName`, `PackageNameAndPublisherIdFromFamilyName`, `PackageIdFromFullName`, `GetPackageFullName`, `OpenPackageInfoByFullName`, `GetPackageInfo`; `GetPackageStatus`, `GetSystemMetadataPathForPackage`; `OpenStateExplicit`, `GetStateRootFolder`, `GetSystemAppDataFolder`, `CloseState` |
| AppXAllUserStore | `IsNonInboxAllUserPackage` |
| ext-ms-win-appmodel-deployment-l1-1-0 | `GetVolumeMediaId` (presence checked with `ApiSetQueryApiSetPresence`) |
| api-ms-win-service-management-l1-1-0, -l2-1-0 | `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `CloseServiceHandle`; `QueryServiceStatusEx`, `NotifyServiceStatusChangeW` |
| api-ms-win-security-base-l1-2-0 | `InitializeAcl`, `AddAccessAllowedAceEx`, `InitializeSecurityDescriptor`, `SetSecurityDescriptorDacl`, `GetTokenInformation`, `CopySid`, `GetLengthSid`, `ImpersonateLoggedOnUser`, `RevertToSelf` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegEnumKeyExW`, `RegDeleteKeyExW`, `RegDeleteTreeW`, `RegFlushKey`, `RegCloseKey` |
| api-ms-win-core-file-l1-2-1 | `CreateFileW`, `DeleteFileW`, `RemoveDirectoryW`, `FindFirstFileW` / `FindNextFileW` / `FindClose`, `GetFileAttributesW`, `SetFileAttributesW`, `GetVolumePathNameW`, `GetVolumeNameForVolumeMountPointW` |
| tdh, ext-ms-win-wevtapi-eventlog-l1-1-0 | `TdhGetEventInformation`, `TdhGetEventMapInformation`, `TdhEnumerateProviderFieldInformation`; `EvtOpenChannelConfig`, `EvtGetChannelConfigProperty`, `EvtClose` (formatting of the extended error text, `GetAppXLogMessage`) |
| api-ms-win-eventing-provider / classicprovider | `EventRegister`, `EventWrite`, `EventActivityIdControl`, `EventUnregister`; `RegisterTraceGuidsW`, `TraceMessage`, … (WPP) |
| api-ms-win-core-synch, processthreads, libraryloader, heap, localization, sysinfo, string, handle, errorhandling | events, SRW locks, `InitOnceExecuteOnce`, `SleepEx`, `WaitForSingleObject`, TLS, `OpenProcessToken` / `OpenThreadToken`, `GetModuleFileNameW`, `GetModuleHandleExW`, `LoadLibraryExW`, `GetProcAddress`, `LoadStringW`, `FormatMessageW`, `GetWindowsDirectoryW`, `GetVersionExW`, `CompareStringEx`, … |
| api-ms-win-core-crt-l1-1-0, -l2-1-0 | `memcpy`, `memset`, `wcs*`, `_vsnwprintf_s`, `_initterm`, `_onexit`, `__dllonexit3`, `_purecall`, `__C_specific_handler` |

The CRT, `__C_specific_handler`, `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind`, `UnhandledExceptionFilter`, `TerminateProcess`, `DebugBreak` and `DecodePointer` / `EncodePointer` imports are the Visual C++ CRT startup, exception, delay-load and `/GS` security cookie code. Most of the appmodel, WinRT string, OLEAUT32, `AppXAllUserStore`, `ext-ms-win-*` and `tdh` imports are delay-loaded (`__delayLoadHelper2`).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [AppXDeploymentServer.dll](./appxdeploymentserver.md) (service `appxsvc`) | LRPC, dynamic endpoint ([RPC](#rpc)); `StartServiceW(L"appxsvc")` when the bind fails | Every deployment and query operation |
| Service `wsservice` (Windows Store service) | `StartServiceW(L"wsservice")`, without waiting (`PrepareForRpcCall`, 0x1000FB80) | Started before each deployment request ? (only when the call option bit 0 is clear; event 303 if it fails) |
| `Windows.ApplicationModel.Package` (`Windows.ApplicationModel.dll` ?) | `RoGetActivationFactory`, IID `{BB95C564-53D6-41F7-AFDA-54AF141A881C}` (internal statics, `Create(name, version, architecture, resourceId, publisher, publisherId, fullName, familyName, installLocation, …)`) | Builds the `Package` objects returned by the `FindPackages*` methods |
| `Windows.Foundation.Uri` | `RoGetActivationFactory`, `IUriRuntimeClassFactory` `{44A9796F-723E-4FDF-A218-033E75B0C084}` | Manifest URIs ([recovery](#appxpackagerepositoryrecoveruserinstalls-0x10026420)) |
| `tdh.dll` | `LoadLibraryExW` + `GetProcAddress("TdhFormatProperty")` (`GetFormatPropertyHandle`, 0x1001470C) | Formatting an ETW event into the error text |
| Task Scheduler `CLSID_TaskScheduler` `{0F87369F-A4E5-4CFC-BD3E-73E6154572DD}` (`ITaskService` `{2FABA4C7-4DA9-4013-9697-20CC3FD40F85}`) | `CoCreateInstance(CLSCTX_INPROC_SERVER)` ([task](#pre-staged-app-cleanup-task)) | Task `\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup` |
| `OpcFactory` `{6B2D6BA0-9F3E-4F27-920B-313CC426A39E}` (`IOpcFactory` `{6D0B4446-CD73-4AB3-94F4-8CCDF6116154}`), `AppxBundleFactory` `{378E0446-5384-43B7-8877-E7DBDD883446}` (`IAppxBundleFactory` `{BBA65864-965F-4A5F-855F-F074BDBF3A7B}`) | `CoCreateInstance(CLSCTX_INPROC_SERVER)` (`IsApplicationPackageInBundleManifest`, `AddStagedPackagesInBundleToAllUserStore`) | Reads `AppxMetadata\AppxBundleManifest.xml` of a bundle |
| `<install location>\AppxManifest.xml`, `<install location>\AppxMetadata\AppxBundleManifest.xml` | `FileExists`, `IOpcFactory::CreateStreamOnFile` | Manifest path written to the registry, packages of a bundle |
| `<system metadata folder of the package or install location>\microsoft.system.package.metadata\<user SID>.pckgdep` and `….recovery` | `CreateFileW` + section mapping (`ARI::DependencyMiniRepository::Open`, 0x1001C730) | Dependency mini-repository of a package (dependencies to copy to the `AppxAllUserStore`) |
| `<system SIS path>\<full name>\Microsoft.System.Package.Metadata\Autogen` | `FindFirstFileW` tree walk | Size of the byte code cache (`GetPackageDiskUsage`) |
| `<SisPath>\DeletedAllUserPackages` | `RemoveDirectoryTree` ([task](#pre-staged-app-cleanup-task)) | Files of removed all-user packages |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 19 | `DllGetActivationFactory` | 0x1000B9E8 | `HSTRING classId, IActivationFactory **out` |
| 20 | `DllGetClassObject` | 0x10024904 | `REFCLSID, REFIID, void **` (proxy/stub, `NdrDllGetClassObject`) |
| 18 | `DllCanUnloadNow` | 0x100107F4 | none |
| 2 | `GetApplicability` | 0x100253B4 | `LPCWSTR fullName, LPCWSTR userSid, ApplicabilityState *out`: opnum 8 with `verifyProfileIntegrity = 0` |
| 15 | `GetPackageApplicabilityForUserLogon` | 0x100253C8 | same, opnum 8 with 1 |
| 9 | `IsPackageInstalled` | 0x10024B34 | `LPCWSTR fullName, BOOL *out`: opnum 10 |
| 3 | `AppxGetPackageType` | 0x10024A90 | `LPCWSTR fullName, enum *out`: opnum 13 |
| 12 | `AppxPreRegisterPackage` | 0x10024A10 | `LPCWSTR fullName, DWORD flags`: opnum 15 |
| 16 | (none, `GenerateBytecodeForPackages`) | 0x100249C8 | `LPCWSTR *fullNames, DWORD count`: opnum 18 |
| 1 | (none, `GetPackageDiskUsage`) | 0x1002511C | `LPCWSTR fullName, UINT64 *packageSize, UINT64 *dataSize` ([below](#getpackagediskusage-0x1002511c)) |
| 4 | `AppxPackageRepositoryRecoverStagedPackages` | 0x10024BDC | `const GUID *activityId` ?: opnum 4, events 308 / 309 |
| 10 | `RDSRecoverRequests` | 0x10024D0C | none: opnum 5, events 1030 / 1031 |
| 17 | `AppxValidatePackages` | 0x10023030 | `LPCWSTR *fullNames, DWORD count, LPCWSTR path, DWORD timeoutMs` ([below](#appxvalidatepackages-0x10023030)) |
| 7 | `AppxDeletePackageFiles` | 0x1002770C | `LPCWSTR fullName`: synchronous deployment request, operation 9 (`DeletePackageFilesOperation`) |
| 8 | `AppxRequestRemovePackageForUser` | 0x10027420 | `LPCWSTR packageName, LPCWSTR userSid`: synchronous request, operation 2 (`RemoveOperation`) for that user |
| 5 | `AppxPackageRepositoryRecoverUserInstalls` | 0x10026420 | `DWORD mode, callback, DWORD *failedPackageCount` ([below](#appxpackagerepositoryrecoveruserinstalls-0x10026420)) |
| 6 | `AppxRecoverUserInstallsForUpgrade` | 0x10026C74 | none: `AppxPackageRepositoryRecoverUserInstalls(1, NULL, &count)` |
| 14 | `AppxAddPackageToAllUserStoreForPbr` | 0x100225A8 | `LPCWSTR userSid, LPCWSTR familyName, LPCWSTR fullName, LPCWSTR installedLocation` ([below](#appxaddpackagetoalluserstoreforpbr-0x100225a8)) |
| 11 | `AppxPreStageCleanupRunTask` | 0x10022598 | none ([task](#pre-staged-app-cleanup-task)) |
| 13 | `ReArmAppxPreStageCleanupTask` | 0x1001BC04 | none ([task](#pre-staged-app-cleanup-task)) |

The flat exports return an HRESULT, and `E_INVALIDARG` when a pointer is NULL. The synchronous requests (`AppxDeletePackageFiles`, `AppxRequestRemovePackageForUser`) create a `ClientDeploymentRequest`, start it and wait for it (`WaitForDeploymentOperation`, 0x10026244), all inside `RoInitialize(RO_INIT_MULTITHREADED)`.  
The module object (`PackageManagerInternal::PackageManagerClientModule`, 4 bytes on the process heap) is created by `StaticInitialization`. The two binding handles are globals: `IPackageManagerServer_IfHandle` (`{AE2DC901-…}`) and `IPackageManagerServerAppContainer_IfHandle` (`{FF9FD3C4-…}`), protected by `rpcSrwLock`.

### Startup

`start` (`_DllMainCRTStartup`, 0x1000E80C): CRT, then `DllMain` (0x10023620).  
On `DLL_PROCESS_ATTACH`, `DllMain` clears the two binding handles, initialises WPP (`WppInitUm`, `RegisterTraceGuidsW`) and calls `StaticInitialization` (0x1000EC90): it keeps the module handle and the process heap, creates the WRL module object and registers the ETW provider (`McGenEventRegister`). Then it initialises `rpcSrwLock`.  
On `DLL_PROCESS_DETACH` it undoes this and frees the binding handles (`RpcBindingFree`).

### PackageManager

`Windows::Management::Deployment::PackageManager` (`IPackageManager`, `IPackageManager2`, `IPackageManager3`). The deployment methods create a `ClientDeploymentRequest` with an operation of the server's `Common::Deployment::DeploymentOperation`, and return it as the `IAsyncOperationWithProgress`:

| Method | Operation | Checks |
|--------|-----------|--------|
| `AddPackageAsync`, `AddPackageToVolumeAsync` | 1 `AddOperation` | `ValidateAddDeploymentOptions`; the URI must not end with `AppxManifest.xml` (`CreateInstallRequest`, 0x1000B6C4) |
| `UpdatePackageAsync` | 3 `UpdateOperation` | `ValidateUpdateDeploymentOptions`; same URI check |
| `StagePackageAsync`, `StagePackageWithOptionsAsync`, `StagePackageToVolumeAsync` | 4 `StageOperation` | `SetPriorityOption`; same URI check |
| `RemovePackageAsync`, `RemovePackageWithOptionsAsync` | 2 `RemoveOperation` | full name, removal options |
| `CleanupPackageForUserAsync` | 2 `RemoveOperation` with package name and user SID | `Configuration::IsSpecialProfileDeploymentAllowed` (`HKLM\SOFTWARE\Policies\Microsoft\Windows\Appx!AllowDeploymentInSpecialProfiles`) |
| `RegisterPackageAsync` | 6 `RegisterOperation` | `ValidateRegistrationDeploymentOptions`; the URI must end with `AppxManifest.xml` or `AppxMetadata/AppxBundleManifest.xml` |
| `RegisterPackageByFullNameAsync` | 10 | `ValidateNonDevelopmentMode` (`CreateDeploymentOperationWithFullNames`, 0x10026CEC) |
| `MovePackageToVolumeAsync` | 13 | `ValidateMoveDeploymentOptions` |
| `StageUserDataAsync`, `StageUserDataWithOptionsAsync` | 11 `StageUserDataOperation` | `SetPriorityOption` |
| `AddPackageVolumeAsync` | 14 `AddVolumeOperation` | no trailing backslash, `VolumeManager::GetVolumeInformation` |
| `RemovePackageVolumeAsync`, `SetPackageVolumeOfflineAsync`, `SetPackageVolumeOnlineAsync` | 15, 16, 17 | volume must exist (`VolumeManager::FindByKey`) (`CreateRequestForPackageVolume`, 0x10026EF8) |

`SetPriorityOption` (0x10016B88) adds option 0x10 when the I/O priority of the calling thread (`NtQueryInformationThread(ThreadIoPriority)`) is very low or low. A target volume is turned into its key from `HKLM\Software\Microsoft\Windows\CurrentVersion\AppX\PackageVolumes` (`GetTargetVolumeId`, `VolumeManager`).

The synchronous methods call the server directly:
- `FindPackages*` (opnums 6, 7, 11, 17): without a user, the SID is `S-1-1-0` (Everyone, all users); with an empty one, the SID of the caller (`SidHelper::GetCurrentUserSid`). The returned [RpcPackageInfo](#rpcpackageinfo) list becomes a vector of `Windows.ApplicationModel.Package`, with the dependencies as a nested vector.
- `FindUsers` (opnum 9): [RpcVisibilityInfo](#rpcpackageinfo) list → `PackageUserInformation` (user SID, install state).
- `SetPackageState` (0x1000EF98), `SetPackageStatus`, `ClearPackageStatus`: read the status with `GetPackageStatus` and call opnum 12 only if it would change (`PackageStatusOperationImpl(op, fullName, mask)`). The operation is 1 (set) or 2 (clear) with the mask given (only bits 0…3 accepted). `SetPackageState` maps `Normal` → clear 7, `LicenseInvalid` → op 3 mask 1, `Modified` → set 2, `Tampered` → set 4.
- `FindPackageVolumeByName`: `VolumeManager::FindByName`, from the registry, no RPC.

`PackageVolume` holds `Name`, `PackageStorePath`, `IsOffline` and `SupportsHardLinks` (from the volume `Flags`). `Internal.PackageOperation::TriggerOperation(HSTRING fullName, PackageOperationType type)` (0x10025868) accepts only `type == 0`. It gets the full name of the calling package (`CoGetCallContext` IID `{68C6A1B9-DE39-42C3-8D28-BF40A5126541}` → process handle, `GetPackageFullName`) and calls `ProcessRequest` (0x1002527C). The target must be the caller's own package or one of its direct dependencies (`GetPackageInfo(PACKAGE_FILTER_DIRECT)`), otherwise `E_INVALIDARG`; then opnum 14.

### ClientDeploymentRequest

`Initialize` stores the operation (+0x5C), the options, the volume, the main parameter (URI, full name or name), the user SID and the secondary parameters (dependency URIs or full names), and creates the `ClientDeploymentResult` (+0x64). When the operation is started, `OnStart` (0x1000C2C4):
1. writes the start event of the operation (`LogPerformanceEventToETW`, events 1008…1047);
2. opnum 1 creates the progress WNF state name, stored at +0x7C;
3. `RtlAllocateWnfSerializationGroup`, then `RtlSubscribeWnfStateChangeNotification(stateName, 0, NULL, WnfCallBack, this, …)`, subscription at +0x84;
4. takes the activity ID of the result and calls opnum 0 (`StartDeployment`) with the operation, options, main parameter, user SID, secondary parameters, a flag that is 0 for a remove (operation 2) and 1 otherwise (`registerForProgress` ?), the WNF state name, the activity ID and the volume. The server returns the request moniker.

`WnfCallBack` (0x1000BB74) runs `RoInitialize(RO_INIT_MULTITHREADED)` and ignores the notification unless the state name is the request's own. A `ChangeStamp` of 0 means that the state was deleted, so the request fails with `RPC_S_CALL_FAILED` (0x800706BE). Data of 16 bytes is a [status](#deployment-status) (`UpdateStatus`, 0x10026378); longer data is a status followed by an error text (`UpdateExtendedErrorStatus`, 0x10026B1C: the text is stored in the result as `ErrorText` and passed to `RoOriginateErrorW`). Anything else fails with 0xCFFFFF3E.  
`UpdateStatus` fires `Progress` while the request runs, and on the final state completes the operation (`Completed`, `Canceled` for `ERROR_INSTALL_CANCEL` 0x80073CF8, or `Error` with the mapped HRESULT). It also writes the stop event. The WNF subscription is released by `OnClose` and the destructor (`ReleaseWnfResource`, 0x1000E490: `RtlUnsubscribeWnfStateChangeNotification` from the callback thread, `RtlUnsubscribeWnfNotificationWaitForCompletion` otherwise).  
`Cancel` (0x10025350) calls opnum 2 with the WNF state name if the request is still running (`CancelImpl`).

`Common::Deployment::MapError` (0x1001615C) gives the error of a failed request: `ERROR_DISK_FULL` / `ERROR_NOT_ENOUGH_QUOTA` → `ERROR_INSTALL_OUT_OF_DISK_SPACE` (0x80073CF4), `ERROR_BAD_NETPATH` / `ERROR_NETWORK_UNREACHABLE` → `ERROR_INSTALL_NETWORK_FAILURE` (0x80073CF5), 0x800704EC → `ERROR_DEPLOYMENT_BLOCKED_BY_POLICY` (0x80073D01). The AppX (0x80073CF0…0x80073D09), trust (0x800B0001…0x800B0100), 0x80080200…0x80080208 and `E_ACCESSDENIED` codes are kept. Other errors become `ERROR_INSTALL_FAILED` (0x80073CF9) for operations 1, 3, 4, 6, 10, 11, `ERROR_REMOVE_FAILED` (0x80073CFA) for 2, 5, and 0x80073D0B for 13.

### Deployment status

Published by the server in the request's WNF state (`PackageManagerInternal::DeploymentRequestStatus`, copied to +0x6C of the request):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | State: 1 = queued (`DeploymentProgressState.Queued`), 2 = processing, 3 = completed |
| 0x04 | 4 | Progress percentage (`DeploymentProgress.percentage`) |
| 0x08 | 4 | HRESULT of the request |
| 0x0C | 4 | Extended error code (`DeploymentResult.ExtendedErrorCode`; the HRESULT if 0 and the HRESULT isn't mapped) |
| 0x10 | n | Optional: error text, UTF-16, the last character is overwritten with a NUL |

### RpcPackageInfo

Element of the list returned by opnums 6, 7, 11 and 17 (`RpcPackageInfoToPackageInfo`, 0x1000F7B0; freed by `FreeRpcPackageInfoList`, 0x1000F24C):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Name |
| 0x04 | 4 | Publisher |
| 0x08 | 4 | Publisher ID |
| 0x0C | 4 | Resource ID (NULL = none) |
| 0x10 | 2 | Processor architecture |
| 0x18 | 8 | Version (major in the high word) |
| 0x20 | 4 × 4 | Passed to `Package` creation (flags ?) |
| 0x30 | 4 | Package full name |
| 0x34 | 4 | Install location |
| 0x38…0x44 | 4 × 4 | Optional strings (display name, publisher display name, description, logo ?) |
| 0x48 | 4 | Dependency packages (nested list) |
| 0x4C | 4 | Next element |

The family name is computed by the client (`PackageFamilyNameFromFullName`).

### GetPackageDiskUsage (0x1002511C)

1. Event 1034. `PackageFamilyNameFromFullName`, then the application data root of the package (`GetPackageAppDataRoot`: `OpenStateExplicit` with the caller's token, `GetStateRootFolder`, `GetSystemAppDataFolder`). If it doesn't exist, `ERROR_INSTALL_PACKAGE_NOT_FOUND` (0x80073CF1).
2. `*dataSize` = size on disk of that tree (`GetDirectoryTreeSizeOnDisk`).
3. Opnum 16 gives the size of the package files. If it isn't 0, `*packageSize` = that size + the byte code cache size (`<system SIS path>\<full name>\Microsoft.System.Package.Metadata\Autogen`); otherwise 0. Event 1035.

### AppxValidatePackages (0x10023030)

Asynchronous call of opnum 0 of `{FF9FD3C4-…}`, which puts a trust label on the folders of the packages (`AppXSetTrustLabelOnPackage` in the [server](./appxdeploymentserver.md#rpc-server)). It creates its own binding (`CreateAndBindRpcBindingHandle`, not cached), calls `NdrAsyncClientCall` with an event notification and waits `timeoutMs`. On a timeout it returns `HRESULT_FROM_WIN32(WAIT_TIMEOUT)` after `RpcAsyncCancelCall`; otherwise the result is from `RpcAsyncCompleteCall`. The call is retried once on a retriable RPC error.

### AppxPackageRepositoryRecoverUserInstalls (0x10026420)

Re-registers the packages of the current user (after an OS upgrade or a reset). `failedPackageCount` must not be NULL (`E_POINTER`).
1. Creates an activity ID, events 304 and 1026.
2. Opnum 3 (`GetSortedRegisterPackageList`) gives the list of packages to register for the current user (by SID).
3. For each one: `GetApplicability(fullName, userSid)`. An installed package is skipped (event 306). Otherwise the manifest URI is built from `Configuration::GetSystemSisManifestPathFromPackageFullName`, together with the URIs of its dependencies, and `PackageManager::RegisterPackageAsync` is called and waited for.
4. Each failure increments the count (event 310). With `mode == 0` the callback is called with `(2, length, fullName, hr)`.
5. Events 305 and 1027.

### AppxAddPackageToAllUserStoreForPbr (0x100225A8)

Writes a package into the `AppxAllUserStore` so that it's reinstalled after a push-button reset (PBR):
1. Looks for a bundle of the family next to the install location (`FindBundleInFamilyRelativeToPackageInstalledLocation`: `<name>_*_neutral_~_<publisherId>`, highest version that contains the package). If one is found, the bundle and its staged packages are added under `…\AppxAllUserStore\Staged`; otherwise the package itself.
2. Stops if `AppXAllUserStore!IsNonInboxAllUserPackage` says that the package is already an all-user package.
3. Writes `…\AppxAllUserStore\Upgrade\<user SID>\<family name>\<full name>` (value `Path` = the manifest path), and one subkey per dependency read from the dependency mini-repository (`<user SID>.pckgdep`, required; `.recovery`, optional). It also writes `…\AppxAllUserStore\DownlevelInstalled\<user SID>\…`.

### Pre-staged app cleanup task

`ReArmAppxPreStageCleanupTask` (0x1001A464): `CoCreateInstance(CLSID_TaskScheduler)`, `ITaskService::Connect`, folder `\Microsoft\Windows\AppxDeploymentClient`, task `Pre-staged app cleanup`, `put_Enabled(VARIANT_TRUE)`.  
`AppxPreStageCleanupRunTask` (0x10021084), the action of the task:
1. Writes event 301 with the calling module. Nothing happens in audit mode (`IsAuditBoot`: `HKLM\System\Setup\Status!AuditBoot`).
2. Deletes `<SisPath>\DeletedAllUserPackages` (`Configuration::GetSisDeletedAllUserPackagesPath`, `RemoveDirectoryTree`) and the key `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppX\AppxAllUserStore\Deleted` (`RegDeleteTreeW`).
3. Disables the task (`put_Enabled(VARIANT_FALSE)`) and sets `CleanupTaskComplete` = 1 in the `AppxAllUserStore` key.

### RPC

Binding (`CreateAndBindRpcBindingHandle`, 0x1000CC00):
- `RpcBindingCreateW` template: version 1, protocol sequence 3 (`ncalrpc`), no address, no endpoint (resolved by the endpoint mapper), no object UUID;
- security: `RPC_C_AUTHN_LEVEL_PKT_PRIVACY` (6), authentication service 0x14, QoS version 5 with `RPC_C_QOS_CAPABILITIES_MUTUAL_AUTH`, dynamic identity tracking, `RPC_C_IMP_LEVEL_IMPERSONATE`, the server SID `S-1-5-18` and a `ServerSecurityDescriptor` that gives `GENERIC_ALL` to LocalSystem only (built once, `InitializeAcl` + `AddAccessAllowedAceEx`). The server must therefore run as LocalSystem;
- options: `RPC_BHO_NONCAUSAL`, default communication timeout.

`BindToServer` (0x1000CD84) calls `RpcBindingBind`. If it fails with a retriable error (`RetriableHrRpcError`: `EPT_S_NOT_REGISTERED`, `RPC_S_SERVER_UNAVAILABLE`, `RPC_S_CALL_FAILED`, `RPC_S_CALL_FAILED_DNE`, `RPC_S_UNKNOWN_IF`), it starts `appxsvc` and waits for it to be running, then binds again. Otherwise it writes event 311 (or 302 if the service doesn't start).  
`StartServiceW` (0x1000CADC) opens the service with `SERVICE_QUERY_STATUS | SERVICE_START`, starts it if it's stopped and, when asked, waits for `SERVICE_NOTIFY_RUNNING` (`NotifyServiceStatusChangeW` + `SleepEx(30000, TRUE)`, `ERROR_TIMEOUT` after that).  
Every call goes through `DoRpcCall`: `PrepareForRpcCall` (starts `wsservice` when option bit 0 is clear; creates the binding if there is none, or recreates it with bit 2), then the stub under `rpcSrwLock` (shared). On a retriable error the binding is dropped and the call is tried again.

Interface `{AE2DC901-312D-41DF-8B79-E835E63DB874}` version 1.0 (MIDL stub descriptor 0x100028D0, proc format 0x100021A0). The opnum numbers and parameters match the [server table](./appxdeploymentserver.md#rpc-server):

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `DoRpcCall` 0x1000C70C | `ClientDeploymentRequest::OnStart` | `[in] enum16 operation`, `[in] enum32 options`, `[in] string mainParameter`, `[in, unique] string userSid`, `[in] long count`, `[in, size_is(count)] string parameters[]`, `[in] long`, `[in, ref] WNF_STATE_NAME *`, `[in, unique] GUID *activityId`, `[in] long volume`, `[out] string *requestMoniker` | Starts a deployment request |
| 1 | `DoRpcCall` 0x1000C574 | `OnStart` | `[out] WNF_STATE_NAME *` | Progress state of the request |
| 2 | 0x10024204 | `ClientDeploymentRequest::CancelImpl` | `[in] WNF_STATE_NAME` | Cancels the request |
| 3 | 0x10024388 | `GetSortedRegisterPackageListImpl` (`AppxPackageRepositoryRecoverUserInstalls`) | `[in, unique] GUID *activityId`, `[out]` list | Packages to register |
| 4 | 0x10023F14 | `AppxPackageRepositoryRecoverStagedPackages` | `[in, unique] GUID *activityId` | `FixStagedPackages` |
| 5 | 0x10023FD0 | `RDSRecoverRequests` | none | Replays the interrupted requests |
| 6 | 0x1000FA8C | `FindPackagesByUserSecurityIdImpl` | `[in] string userSid`, `[in] enum16 packageTypes`, `[out]` list | `FindPackages*` |
| 7 | 0x1002475C | `FindPackagesByUserSecurityIdNamePublisherImpl` | `[in] string userSid`, `[in] string name`, `[in] string publisher`, `[in] enum16`, `[out]` list | `FindPackages*ByNamePublisher` |
| 8 | 0x100242C0 | `GetApplicabilityImpl` | `[in] string fullName`, `[in] string userSid`, `[in] long`, `[out] enum16 *` | `GetApplicability`, `GetPackageApplicabilityForUserLogon` |
| 9 | 0x10024508 | `PackageManager::FindUsersImpl` | `[in] string fullName`, `[out]` list | `FindUsers` |
| 10 | 0x10023E58 | `IsPackageInstalled` | `[in] string fullName`, `[out] long *` | |
| 11 | 0x100245C8 | `FindPackageByUserSecurityIdPackageFullNameImpl` | `[in] string userSid`, `[in] string fullName`, `[out]` list | `FindPackage*ByPackageFullName` |
| 12 | 0x10024444 | `PackageStatusOperationImpl` | `[in] enum16 op`, `[in] string fullName`, `[in] long mask` | Package status |
| 13 | 0x10023D9C | `AppxGetPackageType` | `[in] string`, `[out] enum16 *` | |
| 14 | 0x10024148 | `ProcessRequest` (`PackageOperation::TriggerOperation`) | `[in] string fullName`, `[in] enum16 type` | `RequestPackageOperation` |
| 15 | 0x10023CE0 | `AppxPreRegisterPackage` | `[in] string fullName`, `[in] enum16 flags` | Pre-registration (administrators only on the server) |
| 16 | 0x1002408C | `GetPackageDiskUsage` | `[in] string fullName`, `[out] hyper *` | Size of the package files |
| 17 | 0x10024690 | `FindPackagesByUserSecurityIdPackageFamilyNameImpl` | `[in] string userSid`, `[in] string familyName`, `[in] enum16`, `[out]` list | `FindPackages*ByPackageFamilyName` |
| 18 | 0x10023C24 | `GenerateBytecodeForPackages` | `[in, size_is(count)] string fullNames[]`, `[in] long count` | JavaScript byte code |

Interface `{FF9FD3C4-742E-45E0-91DD-2F5BC632A1DF}` version 1.0 (stub descriptor 0x1000AF88, asynchronous):

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `AppxValidatePackages` (0x10023164) | export | `PRPC_ASYNC_STATE`, `[in] long count`, `[in, size_is(count)] string fullNames[]`, `[in, unique] string path` | Trust label on the packages ([above](#appxvalidatepackages-0x10023030)) |

### WNF states

No well-known state. Each deployment request subscribes to the temporary state name that opnum 1 creates for it ([ClientDeploymentRequest](#clientdeploymentrequest)). The data is a 16-byte [status](#deployment-status), optionally followed by an error text.

### ETW

Provider `{8127F6D4-59F9-4ABF-8952-3E3A02073D5F}` (`Microsoft-Windows-AppXDeployment`, `APPXDEPLOYMENT_ETW_CONTROL_GUID`), registered in `StaticInitialization` (`McGenEventRegister`; enable bits in `Microsoft_Windows_AppXDeploymentEnableBits`). This provider isn't the server's (`{3F471139-…}`).

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 301 `ClientCallingProcess` | 4 | 0, 4 | 0x4000000000010000 | 0x1 | Module name of the caller (`LogCallingModule`, cleanup task) |
| 302 `ServiceStartupFailure` | 2 | 0, 4 | 0x4000000000010000 | 0x2 | `appxsvc` couldn't be started |
| 303 `WindowsStoreServiceStartupFailure` | 3 | 0, 4 | 0x4000000000010000 | 0x4 | `wsservice` couldn't be started |
| 304 / 305 `RecoveryStart` / `RecoveryEnd` | 4 | 0, 4 | 0x4000000000010000 | 0x1 | `AppxPackageRepositoryRecoverUserInstalls` |
| 306 `RecoveryAlreadyInstalled`, 307 `RecoveryReturnValue`, 310 `RecoverySkipped` | 4 | 0, 4 | 0x4000000000010000 | 0x1 | Per package of the recovery |
| 308 / 309 `RecoverStagedPackageStart` / `End` | 4 | 0, 4 | 0x4000000000010000 | 0x1 | `AppxPackageRepositoryRecoverStagedPackages` |
| 311 `FailedToBindToRpcServer` | 2 | 0, 4 | 0x4000000000010000 | 0x2 | `RpcBindingBind` failed |
| 312 `AppModelRuntimeDMRCorrupt` | 2 | 0, 0 | 0x4000000000000002 | none (own `EtwEventRegister` / `EtwEventWrite` / `EtwEventUnregister`, `LogDMRCorrupt`) | Corrupted dependency mini-repository |
| 1001 / 1003 `ClientServiceStartupStart` / `Stop` | 4 | 1 / 2, 1 | 0x8001000000010000 | 0x10 | Service startup |
| 1008…1019, 1036…1047 `ClientSide<Operation>Start` / `Stop` | 4 | 1 / 2, 4 | 0x8001000000010000 | 0x10 | Start and end of a deployment request (Add, Remove, Update, Stage, DeStage, Register, StageUserData, MovePackage, AddVolume, DeleteVolume, SetVolumeOffline, SetVolumeOnline) |
| 1020…1025, 1028 / 1029 | 4 | 1 / 2, 5 or 4 | 0x8001000000010000 | 0x10 | `EnumPackagesByUserSid`, `…NamePublisher`, `FindUsers`, `FindPackageByPackageFullName` |
| 1026 / 1027 `ClientRecoveryStart` / `Stop`, 1030 / 1031 `ClientRDSRecoverRequestsStart` / `Stop`, 1034 / 1035 `GetPackageDiskUsageStart` / `Stop` | 4 | 1 / 2, 4 or 5 | 0x8001000000010000 | 0x10 | The exports of the same name |

All are on channel 16 (1001…) or 17 (301…). WPP tracing is registered too (`WppInitUm`).

### Registry

| Key (HKLM) | Values | Use |
|-----|--------|-----|
| `Software\Microsoft\Windows\CurrentVersion\AppX\PackageVolumes\<key>` | `Flags`, `MountPoint`, `Name`, `SisPath` | Package volumes (`VolumeManager::ReadVolume`; `WriteVolume` / `FixIncompleteVolume` too) |
| `SOFTWARE\Policies\Microsoft\Windows\Appx` | `AllowDeploymentInSpecialProfiles` | `CleanupPackageForUserAsync` |
| `SOFTWARE\Microsoft\Windows\CurrentVersion\AppX\AppxAllUserStore\Staged`, `\Upgrade\<SID>\<family>\<full name>`, `\DownlevelInstalled\<SID>\…` | `Path` | [AppxAddPackageToAllUserStoreForPbr](#appxaddpackagetoalluserstoreforpbr-0x100225a8) |
| `SOFTWARE\Microsoft\Windows\CurrentVersion\AppX\AppxAllUserStore`, `…\Deleted` | `CleanupTaskComplete` | [Cleanup task](#pre-staged-app-cleanup-task) |
| `System\Setup\Status` | `AuditBoot` | Audit mode |
