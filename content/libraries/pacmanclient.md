## PacManClient.dll

The COM proxy/stub DLL of the Package Manager ("PacMan") interfaces: it marshals the calls between the clients of the PacMan service and [pacmanserver.dll](./pacmanserver.md).  
`PacManClient.dll` is a small MIDL-generated proxy/stub DLL (57 344 bytes, 39 functions, no code of its own besides the `NdrDll*` entry points, the IID lookup routines and the CRT). It contains the proxies and stubs (`/Oicf` stubless, NDR format strings, MIDL 8.0.603) of 53 interfaces in two proxy files: the 45 `IPM*` interfaces of the PacMan service (deployment, enumeration, tiles, background service scheduling, licences, notifications and the objects they return) and the 8 `IMC*DEHExt` deployment extension handler interfaces. Since the PacMan objects live in the `pacmanservice` process, every out-of-process caller (e.g. [BtServ.dll](./btserv.md), [EMSVCS.dll](./emsvcs.md), [ScreenRecorderImpl.dll](./screenrecorderimpl.md), [BtsCli.dll](./btscli.md)) goes through these proxies, and the service unmarshals with the stubs. The method names aren't in the binary (MIDL proxies carry only the interface names and IIDs); the parameter lists below are decoded from the NDR format strings, and the method names come from the trace strings of [pacmanserver.dll](./pacmanserver.md#com-server) when known.  

Location on the phone: `C:\Windows\System32\PacManClient.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4.dll | `NdrDllGetClassObject`, `NdrDllCanUnloadNow`, `NdrDllRegisterProxy`, `NdrDllUnregisterProxy`, `NdrOleAllocate`, `NdrOleFree`, `IUnknown_QueryInterface_Proxy`, `IUnknown_AddRef_Proxy`, `IUnknown_Release_Proxy`, `CStdStubBuffer_*` (`QueryInterface`, `AddRef`, `Connect`, `Disconnect`, `Invoke`, `IsIIDSupported`, `CountRefs`, `DebugServerQueryInterface`, `DebugServerRelease`), `NdrCStdStubBuffer_Release` |
| OLEAUT32.dll | `BSTR_UserSize`, `BSTR_UserMarshal`, `BSTR_UserUnmarshal`, `BSTR_UserFree`, `LPSAFEARRAY_UserSize`, `LPSAFEARRAY_UserMarshal`, `LPSAFEARRAY_UserUnmarshal`, `LPSAFEARRAY_UserFree` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `DisableThreadLibraryCalls` |
| msvcrt.dll | `malloc`, `free`, `memcmp`, `_initterm`, `_amsg_exit`, `_XcptFilter`, `__C_specific_handler` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |

The RPCRT4 and OLEAUT32 imports are the standard proxy/stub runtime (the `BSTR` and `SAFEARRAY` user marshal routines are the two entries of the user marshal table, index 0 and 1). The msvcrt, synch, processthreads, errorhandling and rtlsupport imports are the Visual C++ DLL CRT startup and the `/GS` security cookie code (`memcmp` is used by the IID lookup).

No file is loaded at run time, no process or COM server is started, no registry value, WNF state or ETW provider is used by the code itself (the registration is done by `NdrDllRegisterProxy`).

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 2 | `DllGetClassObject` | 0x100077EC | `REFCLSID, REFIID, void **` |
| 1 | `DllCanUnloadNow` | 0x10007828 | none |
| 3 | `DllRegisterServer` | 0x1000787C | none |
| 4 | `DllUnregisterServer` | 0x100078AC | none |

They're the four `dlldata.c` functions: `NdrDllGetClassObject(rclsid, riid, ppv, aProxyFileList, &CLSID_PSFactoryBuffer, &gPFactory)`, `NdrDllCanUnloadNow(&gPFactory)` (`unk_1000AC30`), `NdrDllRegisterProxy(hModule, aProxyFileList, &CLSID_PSFactoryBuffer)` and `NdrDllUnregisterProxy(…)`. There's no `PROXY_CLSID`: the class ID of the proxy/stub factory is the IID of the first interface of the first proxy file, `{1EECD525-6D75-4046-AE79-F291A319D36B}` (`IMCFileSavePickerDEHExt`, read through `off_10006BB4` → `dword_1000768C`). `DllRegisterServer` writes, for each of the 53 IIDs, `HKCR\Interface\{IID}\ProxyStubClsid32 = {1EECD525-…}` and registers the class `{1EECD525-…}` with `InprocServer32` = this DLL.

`aProxyFileList` (`off_1000A010`) has two `ExtendedProxyFileInfo`:

| Proxy file | Address | Interfaces | IID lookup (binary search on the sorted IIDs) |
|------------|---------|------------|-----------------------------------------------|
| Deployment extension handlers | 0x10006E9C | 8 `IMC*DEHExt` (type format string 0x100064E2) | `sub_100090C8` |
| PacMan | 0x100064B8 | 45 `IPM*` (type format string 0x10001062) | `sub_10009000` |

No interface is delegated (no base interface other than `IUnknown`): method 3 is the first method of each interface.

### Startup

`DllEntryPoint` (`_DllMainCRTStartup`, 0x10007F28): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then `dllmain_dispatch` (0x10007C34: CRT init, then `DllMain`). `DllMain` (`sub_10007858`) only saves the module handle (`dword_1000AC40`, used by the registration) and calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH`.

### Interfaces

Notation of the parameters (decoded from the NDR proc format strings, the HRESULT return isn't listed): `[in]`, `[out]` and `[in, out]` are the NDR parameter directions; `GUID` / `structN` without `*` are passed by value; `structN` is a structure of N bytes described in [Structures](#structures); `BYTE**, LONG*` is a conformant byte array allocated by the callee with its size; `BSTR**` is a conformant array of `BSTR`; `enum` is a 32-bit enum. The getters of the info objects mostly take `[in, out] BSTR*` (not `[out]`), so the caller must initialise the `BSTR` (NULL).

#### Managers (methods of `CPMSvc`)

These are the interfaces of the PacMan service object `CLSID_PMSvc` `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` (see [pacmanserver.dll](./pacmanserver.md#com-server) for the capabilities checked by each method). The vtables of `CPMSvc` in pacmanserver.dll have exactly the same number of entries as the proxies, so the indices match one to one. The server method is the one at that index of the `CPMSvc` vtable; its name comes from its trace string, or from the `PackageManager` method it calls (`PackageManager` vtable 0x10001F70, global object `dword_100C6090`). `IPMTileManagerInternal` (`{FDD4D1CC-…}`, one method, `CPMTileManager2::ConstructTileInternal`) is exposed by `CPMSvc` but has no proxy here, so it can't be called from another process through this DLL.

**IPMDeploymentManager** `{35F785FA-1979-4A8B-BC8F-FD70EB0D1544}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] GUID` | `CPMDeploymentManager::ReportDownloadBegin` (`sub_100431E4`) |
| 4 | `[in] GUID, [in] SHORT` | `CPMDeploymentManager::ReportDownloadProgress` (`sub_1004E9C4`) |
| 5 | `[in] GUID, [in] LONG` | `CPMDeploymentManager::ReportDownloadComplete` (`sub_1004331C`) |
| 6 | `[in] struct72*` | `CPMDeploymentManager::BeginInstall` (`sub_1004EC30`) |
| 7 | `[in] struct52*` | `CPMDeploymentManager::BeginUpdate` (`sub_1004F09C`) |
| 8 | `[in] struct72*` | `CPMDeploymentManager::BeginDeployPackage` (`sub_1004EDA4`) |
| 9 | `[in] struct48*` | `CPMDeploymentManager::BeginUpdateDeployedPackageLegacy` (`sub_1007F8D4`) |
| 10 | `[in] GUID` | `CPMDeploymentManager::BeginUninstall` (`sub_1008CF8C`) |
| 11 | `[in] struct72*` | `CPMDeploymentManager::BeginEnterpriseAppInstall` (`sub_1008B954`) |
| 12 | `[in] struct52*` | `CPMDeploymentManager::BeginEnterpriseAppUpdate` (`sub_1008B8CC`) |
| 13 | `[in] GUID, [in] GUID, [in] const BYTE*, [in] LONG` | `CPMDeploymentManager::BeginUpdateLicense` (`sub_1008CB54`) |
| 14 | `[in] BSTR, [out] BYTE**, [out] LONG*, [in, out, unique] BYTE**, [in, out, unique] LONG*, [in, out, unique] BYTE**, [in, out, unique] LONG*, [in, out, unique] BYTE**, [in, out, unique] LONG*, [in, out, unique] BYTE**, [in, out, unique] LONG*` | `CPMDeploymentManager::GetLicenseChallenge` (`sub_10043EF8`) |
| 15 | `[in] GUID, [out] BYTE**, [out] LONG*` | `CPMDeploymentManager::GetLicenseChallengeByProductID` (`sub_1008CA9C`) |
| 16 | `[in] GUID, [out] BYTE**, [out] LONG*, [in, out, unique] BYTE**, [in, out, unique] LONG*, [in, out, unique] BYTE**, [in, out, unique] LONG*, [in, out, unique] BYTE**, [in, out, unique] LONG*, [in, out, unique] BYTE**, [in, out, unique] LONG*` | `CPMDeploymentManager::GetLicenseChallengeByProductID2` (`sub_100441A8`) |
| 17 | `[in] GUID` | `CPMDeploymentManager::RevokeLicense` (`sub_1008CC00`) |
| 18 | `[in] GUID, [in] SAFEARRAY*` | `CPMDeploymentManager::RebindMdilBinaries` (`sub_1008B9DC`) |
| 19 | `[in] GUID, [in] GUID` | `CPMDeploymentManager::RebindAllMdilBinaries` (`sub_1008CE30`) |
| 20 | `[in] GUID, [in] SAFEARRAY*` | `CPMDeploymentManager::RegenerateXbf` (`sub_1008C294`) |
| 21 | `[in] GUID` | `CPMDeploymentManager::GenerateXbfForCurrentLocale` (`sub_10057BFC`) |
| 22 | `[in] GUID, [in] BSTR` | `CPMDeploymentManager::BeginProvision` (`sub_1008C0E4`) |
| 23 | `[in] GUID` | `CPMDeploymentManager::BeginDeprovision` (`sub_1008C050`) |
| 24 | `[in] GUID` | `CPMDeploymentManager::ReindexSQLCEDatabases` (`sub_1008C184`) |
| 25 | `[in] LONG, [out] LONG*` | `CPMDeploymentManager::SetApplicationsNeedMaintenance` (`sub_1008CDA8`) |
| 26 | `[in] GUID` | `CPMDeploymentManager::UpdateChamberProfile` (`sub_1008CD18`) |
| 27 | `[in] GUID, [in] LPCWSTR, [out] LONG*` | `CPMDeploymentManager::EnterprisePolicyIsApplicationAllowed` (`sub_1004E034`) |
| 28 | `[in] struct52*` | `CPMDeploymentManager::BeginUpdateDeployedPackage` (`sub_1008BA6C`) |
| 29 | `[in] GUID` | `CPMDeploymentManager::ReportRestoreCancelled` (`sub_1008C974`) |
| 30 | `[in] LPCWSTR, [in, out] BSTR*` | `CPMDeploymentManager::ResolveResourceString` (`sub_10050CAC`) |
| 31 | none | `CPMDeploymentManager::UpdateCapabilitiesForModernApps` (`sub_1008CC94`) |
| 32 | `[in] GUID` | `CPMDeploymentManager::ReportDownloadStatusUpdate` (`sub_1008CA08`) |
| 33 | `[in] GUID, [in] LONG` | `CPMDeploymentManager::BeginUninstallWithOptions` (`sub_1008CED0`) |
| 34 | none | `CPMDeploymentManager::BindDeferredMdilBinaries` (`sub_1008C3C8`) |
| 35 | `[in] BSTR` | `CPMDeploymentManager::GenerateXamlLightupXbfForCurrentLocale` (`sub_1008C214`) |

**IPMDeploymentManager2** `{75E430A7-9559-4828-98DD-BC657620AB87}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] BSTR, [in] BSTR, [in] GUID, [in] BSTR, [in] IPMTileInfo2*` | not implemented (`sub_1006C118`) |
| 4 | `[in] GUID, [in] BSTR, [in] IPMTileInfo2*` | not implemented (`sub_1006C118`) |
| 5 | `[in] BSTR, [in] BSTR, [in] GUID` | not implemented (`sub_1006C118`) |
| 6 | `[in] struct104*` | `CPMDeploymentManager::BeginAppXRegister` (`sub_1008C8E4`) |
| 7 | `[in] GUID, [in] LONG` | `CPMDeploymentManager::BeginAppXUninstall` (`sub_1008C844`) |
| 8 | `[in] struct100*` | `CPMDeploymentManager::BeginAppXInstall` (`sub_1008C7B4`) |
| 9 | `[in] struct100*` | `CPMDeploymentManager::BeginAppXUpdate` (`sub_1008C724`) |
| 10 | `[in] GUID, [out] GUID*` | `CPMDeploymentManager::GetPayloadIdbyProductId` (`sub_10051C40`) |
| 11 | `[out] pkg104**` | `CPMDeploymentManager::FindPackages` (`sub_1008BFC8`) |
| 12 | `[in] BSTR, [in] BSTR, [out] pkg104**` | `CPMDeploymentManager::FindPackagesByNamePublisher` (`sub_1008BF38`) |
| 13 | `[in] BSTR, [out] LONG*` | `CPMDeploymentManager::AppxGetApplicability` (`sub_10051DE4`) |
| 14 | `[in] GUID, [out] LONG*` | `CPMDeploymentManager::AppxGetApplicabilityUsingProductId` (`sub_1008C5E4`) |
| 15 | `[in] BSTR, [in] GUID, [in] LONG, [in] LONG, [in] struct28[]` | `CPMDeploymentManager::BeginAppxDownload` (`sub_1008C67C`) |
| 16 | `[in] GUID` | `CPMDeploymentManager::BeginMove` (`sub_1008C550`) |
| 17 | none | `CPMDeploymentManager::StartSDCardCleanupTask` (`sub_1008C4CC`) |
| 18 | `[in] BSTR` | `CPMDeploymentManager::DeletePackageVolume` (`sub_1008C444`) |

**IPMEnumerationManager** `{698D57C2-292D-4CF3-B73C-D95A6922ED9A}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[out] IPMApplicationInfoEnumerator**, [in] struct24` | application enumerator by filter (`sub_10056930`) |
| 4 | `[out] IPMTileInfoEnumerator**, [in] struct24` | tile enumerator by filter (`sub_100596B4`) |
| 5 | `[out] IPMTaskInfoEnumerator**, [in] struct24` | task enumerator by filter (`sub_1009AC80`) |
| 6 | `[out] IPMExtensionInfoEnumerator**, [in] struct24` | extension enumerator by filter (`sub_100A1260`) |
| 7 | `[out] IPMBackgroundServiceAgentInfoEnumerator**, [in] struct24` | background service agent enumerator by filter (`sub_10069758`) |
| 8 | `[out] IPMBackgroundWorkerInfoEnumerator**, [in] struct24` | background worker enumerator by filter (`sub_10056378`) |
| 9 | `[in] GUID, [out] IPMApplicationInfo**` | `get_ApplicationInfo` (product ID) (`sub_100B12D0`) |
| 10 | `[in] GUID, [in] BSTR, [out] IPMTileInfo**` | ? (`sub_1005B2B8`) |
| 11 | `[in] GUID, [in] BSTR, [out] IPMTaskInfo**` | ? (`sub_10064178`) |
| 12 | `[in] GUID, [in] LPCWSTR, [out] IPMTaskInfo**` | ? (`sub_10063684`) |
| 13 | `[in] LONG, [out] IPMBackgroundServiceAgentInfo**` | ? (`sub_1009ABB8`) |
| 14 | `[out] IPMLiveTileJobInfoEnumerator**` | live tile job enumerator (`sub_100512C8`) |
| 15 | `[in] GUID, [in] BSTR, [in] enum, [out] IPMLiveTileJobInfo**` | ? (`sub_1009AC2C`) |
| 16 | `[in] GUID, [out] IPMApplicationInfo**` | ? (`sub_100B1304`) |
| 17 | `[in] BSTR, [in] enum, [in, out] BSTR*` | ? (`sub_10046024`) |
| 18 | `[in] BSTR, [in] BSTR, [out] IPMApplicationInfo**` | `CPMEnumerationManager::get_ApplicationInfoFromAccessClaims` (`sub_1004DAA8`) |
| 19 | `[in] struct24, [out] LONG*, [out] struct192**` | tiles by filter, as an array (`sub_100A4594`) |
| 20 | `[in] struct24, [out] LONG*, [out] struct68**` | applications by filter, as an array (`sub_100A4934`) |

**IPMEnumerationManager2** `{D83400E1-A7A6-4990-9B84-10490AFF2063}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] BSTR, [out] IPMApplicationInfo2**` | `CPMEnumerationManager2::get_ApplicationInfo` (`sub_1004DE9C`) |
| 4 | `[in] BSTR, [in] BSTR, [out] IPMTileInfo2**` | `CPMEnumerationManager2::get_TileInfo` (`sub_1009EE60`) |
| 5 | `[in] BSTR, [out] IPMApplicationInfoEnumerator**` | ? (`sub_10064090`) |

**IPMTileManager** `{D622EEDE-5363-41FC-91C3-88E321191A34}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] GUID, [in] BSTR, [in] enum, [in] enum, [out] IPMTileInfo**` | `CPMTileManager::ConstructTile` (`sub_1004FC18`) |
| 4 | `[in] IPMTileInfo*` | `CPMTileManager::CommitTile` (`sub_10061958`) |
| 5 | `[in] GUID, [in] BSTR` | `CPMTileManager::DeleteTile` (`sub_100695A0`) |
| 6 | `[in] IPMTileInfo*` | `CPMTileManager::CommitTileExternal` (`sub_100B1544`) |
| 7 | `[in] IPMTileInfo*` | `CPMTileManager::CommitTileSilent` (`sub_10051A74`) |
| 8 | `[in] GUID, [in] BSTR` | `CPMTileManager::PushUpdateTile` (`sub_1009C868`) |

**IPMTileManager2** `{D29905F5-BAA2-48C5-A98A-F0DC7E122B84}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] BSTR, [in] BSTR, [in] enum, [out] IPMTileInfo2**` | `CPMTileManager2::ConstructTileInternal` (`sub_100A7364`) |
| 4 | `[in] IPMTileInfo2*` | commit tile (`this` method +0x1C with 0) ? (`sub_1004FECC`) |
| 5 | `[in] BSTR, [in] BSTR` | `CPMTileManager2::DeleteTile` (`sub_1009ED18`) |
| 6 | `[in] IPMTileInfo2*` | commit tile (`this` method +0x1C with 1) ? (`sub_1004FEE0`) |

**IPMBssWriter** `{1D275BED-9E6B-4F08-9A69-20B1B12C95AE}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] struct3360*` | `BnsDbWriter::CreateNotification` (`sub_1008BB94`) |
| 4 | `[in] GUID` | `BnsDbWriter::DeleteNotification` (`sub_1008BB58`) |
| 5 | `[in] GUID` | `BnsDbWriter::DeleteApplication` (`sub_1008BB1C`) |
| 6 | `[in] struct3360*` | `BnsDbWriter::UpdateNotification` (`sub_1008BAEC`) |
| 7 | `[in] LONG` | `BnsDbWriter::ExtendAgentEndTime` (`sub_1007AED8`) |

**IPMBssManager** `{96F5B3C3-9610-427C-A522-7DABEAE417D5}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] GUID, [in, out] struct3360*` | notification by ID (`BnsDBManager::GetNotificationIteratorById`) (`sub_100AD34C`) |
| 4 | `[in] GUID, [in, out] LONG*` | `BnsDBManager::GetNotificationCount` (`sub_10052098`) |
| 5 | `[in, out] LONG*, [in, out] LONG*` | `BnsDBManager::GetTotalActiveBackgroundAgents` ? (`sub_100AC89C`) |
| 6 | `[in, out] LONG*` | `BnsDBManager::GetTotalActiveBackgroundAgents` ? (`sub_100AD0F0`) |
| 7 | `[in] GUID, [in] LONG, [in, out] struct3360*` | `BnsDBManager::GetNotificationByIndex` (`sub_100AC8B0`) |
| 8 | `[out] IPMBssNotificationEnumerator**` | `BnsDBManager::GetNotificationIterator` (`sub_10066134`) |
| 9 | `[out] IPMBssNotificationEnumerator**` | `BnsDBManager::GetNotificationIteratorByLastRunTime` (`sub_100ACB50`) |
| 10 | `[in] GUID, [out] IPMBssNotificationEnumerator**` | `BnsDBManager::GetNotificationIteratorById` (`sub_100ACB18`) |
| 11 | `[in] GUID, [out] IPMBssNotificationEnumerator**` | `BnsDBManager::GetNotificationIteratorByProductId` (`sub_100ACA6C`) |

**IPMInternal** `{5ECEF0F3-AD16-434D-8940-EDC1BB4617D9}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] BSTR, [in] LONG, [in] LONG` | register a notification pipe (`PackageManager` +0x88) (`sub_10064484`) |
| 4 | `[in] BSTR, [in] LONG` | unregister it (`NotificationsSender::RemoveListener`) (`sub_1004DB74`) |
| 5 | `[in] GUID, [in] SHORT` | `PackageManager::ReportInstallProgress` (`sub_1004E760`) |
| 6 | `[in] BSTR` | `PackageManager` +0x10C → database manager method +0x1A4 ? (`sub_1008BD88`) |
| 7 | `[in] GUID, [in] SHORT` | `PackageManager` +0xCC: sends a notification (`CSender::SendNotification`) ? (`sub_1008BDB8`) |

**IPMLiveTileJobManager** `{15E673FD-0497-4CB3-97CB-99E698DD3B66}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] GUID, [in] BSTR, [in] struct44, [in] const BYTE*, [in] LONG, [in] const BYTE*, [in] LONG` | `PackageManager::AddLiveTokenSubscription` (`sub_1008BEB4`) |
| 4 | `[in] IPMLiveTileJobInfo*` | ? (`sub_1009AB8C`) |
| 5 | `[in] GUID, [in] BSTR, [in] enum` | `PackageManager::RemoveLiveTokenSubscription` (`sub_1008BE44`) |
| 6 | `[in] GUID, [in] const BYTE*, [in] LONG` | `PackageManager::UpdateTokenFromXML` (`sub_1008BDFC`) |

**IPMLicenseManager** `{11ED725B-8820-45F8-96E6-6845524E46DA}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] GUID, [out] LONG*` | `IsTrial` (`PackageManager` +0x40, `LicenseChecker::IsTrial`) (`sub_100501D4`) |
| 4 | `[in] GUID, [in] LONG` | `PackageManager::VerifyLicenseForExecute` (`sub_10066B40`) |
| 5 | `[in] GUID, [out] BYTE**, [out] LONG*` | `PackageManager::RetrieveContentKeyFromLicense` (`sub_10050404`) |

**IPMLicenseManager2** `{1B83665E-A1B1-455A-BEAC-C680B48BDA10}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] BSTR, [out] LONG*` | `CLicenseManager::IsTrialLicense` (`sub_100AE59C`) |
| 4 | `[in] BSTR, [in] LONG` | `CLicenseManager::VerifyLicenseForExecute` (`sub_100500E4`) |

**IPMTestHook** `{C1CB379E-BAEA-4BA5-9675-27FB34184E9E}`

| Index | Parameters | Server method (pacmanserver.dll) |
|-------|------------|----------------------------------|
| 3 | `[in] GUID, [in] enum` | `PackageManager::UpdateAppState` (`sub_1008BD48`) |
| 4 | `[in] GUID, [out] GUID*` | `PackageManager::GetAppStorageID` (`sub_1008BD08`) |
| 5 | `[in] GUID, [in] GUID` | `PackageManager::UpdateAppStorageID` (`sub_1008BCB8`) |
| 6 | `[in] GUID, [in] LONG, [in] BSTR` | `PackageManager::OnSDCardStateChange` (`sub_1008BC70`) |
| 7 | none | `PackageManager::CheckAppsDuringStartup` (`sub_1008BC44`) |
| 8 | `[in] GUID, [in] LONG` | `PackageManager::UpdateAppFlags` (`sub_1008BC04`) |
| 9 | `[in] GUID, [out] LONG*` | `PackageManager::GetAppFlags` (`sub_1008BBC4`) |

#### Objects returned by the managers

The info objects of the service (`Application`, `Token`, `Token2`, `Task`, `Extension`, `BackgroundServiceAgent`, `TokenJob`, … in [pacmanserver.dll](./pacmanserver.md#com-server)). Methods with `[in]` parameters only are setters. `IPMApplicationInfo` index 7 returns the title and index 30 the SID string (server side, `Application` vtable 0x1000912C).

| Interface | IID | Methods (index: parameters) |
|-----------|-----|-----------------------------|
| `IPMApplicationInfo` | `{50AFB58A-438C-4088-9789-F8C4899829C7}` | 3 `[out] GUID*`; 4 `[out] GUID*`; 5 `[out] GUID*`; 6 `[in, out] BSTR*`; 7 `[in, out] BSTR*`; 8 `[in, out] BSTR*`; 9 `[out] LONG*`; 10 `[out] enum*`; 11 `[out] enum*`; 12 `[out] LONG*`; 13 `[out] LONG*`; 14 `[out] struct8*`; 15 `[out] LONG*`; 16 `[out] LONG*`; 17 `[out] LONG*`; 18 `[in, out] BSTR*`; 19 `[in, out] BSTR*`; 20 `[out] enum*`; 21 `[in, out] BSTR*`; 22 `[in, out] BSTR*`; 23 `[in, out] BSTR*`; 24 `[in, out] BSTR*`; 25 `[in, out] BSTR*, [in, out] BSTR*`; 26 `[out] BYTE*`; 27 `[out] BYTE*`; 28 `[out] GUID*`; 29 `[out] LONG*`; 30 `[in, out] BSTR*`; 31 `[out] BYTE*`; 32 `[out] BYTE*`; 33 `[in] LONG`; 34 `[in] LONG`; 35 `[in] BSTR`; 36 `[in] LONG`; 37 `[out] LONG*`; 38 `[out] LONG*`; 39 `[out] LONG*`; 40 `[out] LONG*`; 41 `[out] LONG*`; 42 `[in] LONG`; 43 `[in] LONG`; 44 `[out] LONG*`; 45 `[out] LONG*`; 46 `[out] LONG*`; 47 `[out] LONG*`; 48 `[out] GUID*`; 49 `[in, out] struct68*`; 50 `[out] LONG*`; 51 `[out] enum*`; 52 `[out] struct8*`; 53 `[out] LONG*`; 54 `[out] LONG*`; 55 `[out] LONG*`; 56 `[in] LONG`; 57 `[in] BSTR` |
| `IPMApplicationInfo2` | `{2925390A-D947-4062-9DAD-CF6F60E6A707}` | 3 `[in, out] BSTR*`; 4 `[in, out] BSTR*`; 5 `[in, out] BSTR*`; 6 `[in, out] BSTR*, [in, out] BSTR*`; 7 `[out] LONG*`; 8 `[out] LONG*`; 9 `[out] LONG*`; 10 `[out] SHORT*`; 11 `[out] LONG*`; 12 `[in] LONG`; 13 `[out] LONG*`; 14 `[in] LONG` |
| `IPMTileInfo` | `{D1604833-2B08-4001-82CD-183AD734F752}` | 3 `[out] GUID*`; 4 `[in, out] BSTR*`; 5 `[out] enum*`; 6 `[in] enum, [out] LONG*`; 7 `[in] enum, [out] LONG*`; 8 `[out] LONG*`; 9 `[out] LONG*`; 10 `[in, out] BSTR*`; 11 `[out] enum*`; 12 `[out] LONG*`; 13 `[in] LONG, [out] IPMTilePropertyInfo**`; 14 `[in, out] BSTR*, [in, out] BSTR*`; 15 `[out] IPMTilePropertyEnumerator**`; 16 `[in] enum, [out] enum*`; 17 `[in] enum, [in] LONG`; 18 `[in] LONG`; 19 `[in] enum, [in] LONG`; 20 `[in] enum, [in] enum`; 21 `[in] BSTR, [in] BSTR`; 22 `[in, out] struct192*`; 23 `[out] LONG*`; 24 `[out] LONG*`; 25 `[in] LONG`; 26 `[in] LONG` |
| `IPMTileInfo2` | `{660D205D-1ED7-4C42-B40E-5BA9AC427DDF}` | 3 `[in, out] BSTR*`; 4 `[in, out] BSTR*`; 5 `[in, out] BSTR*, [in, out] BSTR*`; 6 `[in] BSTR` |
| `IPMTilePropertyInfo` | `{6C2B8017-1EFA-42A7-86C0-6D4B640BF528}` | 3 `[out] LONG*`; 4 `[in, out] BSTR*`; 5 `[in] BSTR` |
| `IPMTaskInfo` | `{BF1D8C33-1BF5-4EE0-B549-6B9DD3834942}` | 3 `[out] GUID*`; 4 `[in, out] BSTR*`; 5 `[in, out] BSTR*`; 6 `[out] enum*`; 7 `[out] enum*`; 8 `[out] enum*`; 9 `[out] enum*`; 10 `[in, out] BSTR*, [in, out] BSTR*`; 11 `[in, out] BSTR*`; 12 `[in, out] BSTR*`; 13 `[in, out] BSTR*`; 14 `[in, out] BSTR*`; 15 `[out] LONG*`; 16 `[out] LONG*`; 17 `[out] enum*`; 18 `[out] enum*`; 19 `[out] BYTE*, [out] BYTE*`; 20 `[out] SHORT*`; 21 `[out] LONG*`; 22 `[in, out] BSTR*`; 23 `[out] LONG*` |
| `IPMExtensionInfo` | `{49ACDE79-9788-4D0A-8AA0-1746AFDB9E9D}` | 3 `[out] GUID*`; 4 `[in, out] BSTR*`; 5 `[in, out] BSTR*`; 6 `[in, out] BSTR*`; 7 `[in, out] BSTR*`; 8 `[in, out] BSTR*, [in, out] BSTR*` |
| `IPMExtensionContractInfo` | `{E5666373-7BA1-467C-B819-B175DB1C295B}` | 3 `[in, out] BSTR*, [in, out] BSTR*` |
| `IPMExtensionProtocolInfo` | `{1E3FA036-51EB-4453-BAFF-B8D8E4B46C8E}` | 3 `[in, out] BSTR*`; 4 `[in, out] BSTR*, [in, out] BSTR*` |
| `IPMExtensionFileExtensionInfo` | `{6B87CB6C-0B88-4989-A4EC-033714F710D4}` | 3 `[in, out] BSTR*`; 4 `[in, out] BSTR*`; 5 `[in] enum, [in, out] BSTR*`; 6 `[in] BSTR, [in, out] BSTR*`; 7 `[in] BSTR, [in, out] BSTR*`; 8 `[in, out] BSTR*, [in, out] BSTR*`; 9 `[out] LONG*, [out] BSTR**` |
| `IPMExtensionFileOpenPickerInfo` | `{6DC91D25-9606-420C-9A78-E034A3418345}` | 3 `[out] LONG*, [out] BSTR**`; 4 `[out] LONG*` |
| `IPMExtensionFileSavePickerInfo` | `{38005CBA-F81A-493E-A0F8-922C8680DA43}` | 3 `[out] LONG*, [out] BSTR**`; 4 `[out] LONG*` |
| `IPMExtensionShareTargetInfo` | `{5471F48B-C65C-4656-8C70-242E31195FEA}` | 3 `[out] LONG*, [out] BSTR**`; 4 `[out] LONG*, [out] BSTR**`; 5 `[out] LONG*` |
| `IPMExtensionCachedFileUpdaterInfo` | `{E2D77509-4E58-4BA9-AF7E-B642E370E1B0}` | 3 `[out] LONG*` |
| `IPMBackgroundServiceAgentInfo` | `{3A8B46DA-928C-4879-998C-09DC96F3D490}` | 3 `[out] GUID*`; 4 `[in, out] BSTR*`; 5 `[out] LONG*`; 6 `[in, out] BSTR*`; 7 `[in, out] BSTR*`; 8 `[in, out] BSTR*`; 9 `[in, out] BSTR*`; 10 `[out] LONG*`; 11 `[out] LONG*`; 12 `[out] LONG*`; 13 `[in, out] BSTR*`; 14 `[out] LONG*`; 15 `[in] LONG`; 16 `[in] LONG` |
| `IPMBackgroundWorkerInfo` | `{7DD4531B-D3BF-4B6B-94F3-69C098B1497D}` | 3 `[out] GUID*`; 4 `[in, out] BSTR*`; 5 `[in, out] BSTR*`; 6 `[out] LONG*`; 7 `[out] LONG*`; 8 `[out] LONG*` |
| `IPMLiveTileJobInfo` | `{6009A81F-4710-4697-B5F6-2208F6057B8E}` | 3 `[out] GUID*`; 4 `[in, out] BSTR*`; 5 `[out] struct8*`; 6 `[in] struct8`; 7 `[out] struct8*`; 8 `[in] struct8`; 9 `[out] LONG*`; 10 `[in] LONG`; 11 `[out] LONG*`; 12 `[in] LONG`; 13 `[out] LONG*`; 14 `[in] LONG`; 15 `[out] LONG*`; 16 `[in] LONG`; 17 `[out] LONG*`; 18 `[in] LONG`; 19 `[out] BYTE**, [out] LONG*`; 20 `[in] const BYTE*, [in] LONG`; 21 `[out] BYTE**, [out] LONG*`; 22 `[in] const BYTE*, [in] LONG`; 23 `[out] LONG*`; 24 `[in] LONG`; 25 `[out] LONG*`; 26 `[in] LONG` |

#### Enumerators

Each enumerator has a single method (index 3) that returns the next object (`IPMBssNotificationEnumerator` returns structures).

| Interface | IID | Method 3 |
|-----------|-----|----------|
| `IPMTilePropertyEnumerator` | `{CC4CD629-9047-4250-AAC8-930E47812421}` | 3 `[out] IPMTilePropertyInfo**` |
| `IPMTileInfoEnumerator` | `{DED83065-E462-4B2C-ACB5-E39CEA61C874}` | 3 `[out] IPMTileInfo**` |
| `IPMBackgroundServiceAgentInfoEnumerator` | `{18EB2072-AB56-43B3-872C-BEAFB7A6B391}` | 3 `[out] IPMBackgroundServiceAgentInfo**` |
| `IPMLiveTileJobInfoEnumerator` | `{BC042582-9415-4F36-9F99-06F104C07C03}` | 3 `[out] IPMLiveTileJobInfo**` |
| `IPMExtensionInfoEnumerator` | `{403B9E82-1171-4573-8E6F-6F33F39B83DD}` | 3 `[out] IPMExtensionInfo**` |
| `IPMApplicationInfoEnumerator` | `{0EC42A96-4D46-4DC6-A3D9-A7ACAAC0F5FA}` | 3 `[out] IPMApplicationInfo**` |
| `IPMBackgroundWorkerInfoEnumerator` | `{87F479F8-90D8-4EC7-92B9-72787E2F636B}` | 3 `[out] IPMBackgroundWorkerInfo**` |
| `IPMTaskInfoEnumerator` | `{0630B0F8-0BBC-4821-BE74-C7995166ED2A}` | 3 `[out] IPMTaskInfo**` |
| `IPMBssNotificationEnumerator` | `{262093FC-FB45-4E15-996C-A13DA8D5C9D4}` | 3 `[out] struct3360**`; 4 `[in, out] struct3360*` |

#### Notifications

`IPMNotificationManager` 3 registers an `IPMNotificationsSink` for a kind of notification (enum) and 4 unregisters it; the sink receives the notification objects through method 5 (an interface pointer whose IID is given by the `GUID*`: `IPMLifeCycleNotification`, `IPMTileNotification`, `IPMBnsNotification` ?). The object that implements `IPMNotificationManager` isn't identified; clients create it with CLSID `{D0DF0C7D-33BF-4E04-9B11-B1D7AE572EED}` ([TH.exe](../applications/th.md#waiting-for-the-result), [Alarms_NoUI.exe](../applications/alarms_noui.md)). None of these six IIDs appears in pacmanserver.dll, so they're implemented by another binary: probably a client library that reads the notification pipe and builds the objects ? ( the service also notifies its clients through `\\.\pipe\PMCN…` pipes, see [pacmanserver.dll](./pacmanserver.md#notifications)).

| Interface | IID | Methods (index: parameters) |
|-----------|-----|-----------------------------|
| `IPMNotificationManager` | `{095BF7A5-F134-42B9-A4B0-7C5F1A9E199A}` | 3 `[in] enum, [in] IPMNotificationsSink*`; 4 `[in] IPMNotificationsSink*` |
| `IPMNotificationsSink` | `{19A9815A-DE09-4B11-BFA5-070C27900D88}` | 3 `[out] LONG*`; 4 `[in] LONG`; 5 `[in] GUID*, [in] IUnknown* (iid_is)` |
| `IPMLifeCycleNotification` | `{E08C57AD-68C0-4851-A4B9-6A6041004B9A}` | 3 `[out] enum*`; 4 `[out] GUID*`; 5 `[out] LONG*`; 6 `[out] SHORT*`; 7 `[out] BSTR*`; 8 `[out] BSTR*`; 9 `[out] BSTR*` |
| `IPMTileNotification` | `{60326D1D-6A8E-450D-B3E3-0EF880A979B0}` | 3 `[out] enum*`; 4 `[out] enum*`; 5 `[out] GUID*`; 6 `[in, out] BSTR*`; 7 `[out] enum*` |
| `IPMTileNotification2` | `{580DA7E0-EC95-418C-A15A-C803AB8C5C47}` | 3 `[in, out] BSTR*` |
| `IPMBnsNotification` | `{73279F3D-F4CF-42C0-B75A-AC5950BFDB89}` | 3 `[out] enum*`; 4 `[out] GUID*`; 5 `[out] LONG*` |

#### Deployment extension handlers

Implemented by `CPMDEHExt` (class `{423ADA85-AF21-49D9-BDDF-19ECAD616205}`) in [pacmanserver.dll](./pacmanserver.md#com-server), called during the deployment of an AppX package by the AppX deployment server ([AppXDeploymentServer.dll](./appxdeploymentserver.md), through its extension handlers module). Methods 3 and 4 take a string and a structure of strings ([Structures](#structures)), the methods without parameters are probably the transaction steps (commit, rollback, …) ?.

| Interface | IID | Methods (index: parameters) |
|-----------|-----|-----------------------------|
| `IMCFileSavePickerDEHExt` | `{1EECD525-6D75-4046-AE79-F291A319D36B}` | 3 `[in] LPCWSTR, [in] deh4*`; 4 `[in] LPCWSTR, [in] deh4*`; 5 `none`; 6 `none`; 7 `none`; 8 `none` |
| `IMCProtocolDEHExt` | `{F403DE30-808A-4FEB-84EF-5371864EA66D}` | 3 `[in] LPCWSTR, [in] deh12*`; 4 `[in] LPCWSTR, [in] deh12*`; 5 `none`; 6 `none`; 7 `none`; 8 `none` |
| `IMCVisualElementsDEHExt` | `{3B56A13A-B071-4811-82A4-07631E63D9DB}` | 3 `[in] LPCWSTR, [in] deh48*`; 4 `[in] LPCWSTR, [in] deh48*`; 5 `none`; 6 `none`; 7 `none`; 8 `none`; 9 `[in] LPCWSTR` |
| `IMCCachedFileUpdaterDEHExt` | `{40890D5F-C127-4B62-A582-41114C064770}` | 3 `[in] LPCWSTR, [in] deh4*`; 4 `[in] LPCWSTR, [in] deh4*`; 5 `none`; 6 `none`; 7 `none`; 8 `none` |
| `IMCShareTargetDEHExt` | `{E9A06986-05E2-4911-B94B-50DEE8D188A1}` | 3 `[in] LPCWSTR, [in] deh8*`; 4 `[in] LPCWSTR, [in] deh8*`; 5 `none`; 6 `none`; 7 `none`; 8 `none` |
| `IMCFileTypeAssocDEHExt` | `{15892EC9-6103-4DAD-A8F4-3CBC5F4ED0C5}` | 3 `[in] LPCWSTR, [in] deh24*`; 4 `[in] LPCWSTR, [in] deh24*`; 5 `none`; 6 `none`; 7 `none`; 8 `none` |
| `IMCPacmanFinalizerDEHExt` | `{31FEA5F0-3625-4784-B81B-DDB1A2F3A17D}` | 3 `none`; 4 `none`; 5 `[in] LPCWSTR, [in] LPCWSTR, [in] LONG`; 6 `[in] LPCWSTR, [in] LPCWSTR, [in] LONG`; 7 `[in] LPCWSTR` |
| `IMCFileOpenPickerDEHExt` | `{BFB872F2-1E12-4B92-9DDF-9C2A051E6BD3}` | 3 `[in] LPCWSTR, [in] deh4*`; 4 `[in] LPCWSTR, [in] deh4*`; 5 `none`; 6 `none`; 7 `none`; 8 `none` |

### Structures

Layouts decoded from the NDR type format strings (types only: the field names aren't in the binary). `BYTE*` is a conformant array pointer whose size is given by another field (which one isn't decoded) ?.

**Enumeration filter** (`struct24`, passed by value to `IPMEnumerationManager` 3…8, 19, 20): a `LONG` filter type, then a 20-byte union selected by it (`FC_NON_ENCAPSULATED_UNION`, switch on +0x00). The filter values select the `PacManDBManager` query on the server side ([pacmanserver.dll](./pacmanserver.md#com-server)).

| Filter type (+0x00) | Union at +0x04 |
|---------------------|----------------|
| 2, 4, 10, 13 | enum (4 bytes) |
| 11, 12, 21, 28 | `GUID` |
| 15 | `GUID`, enum |
| 17, 27, 32 | `GUID`, `BSTR` |
| 18, 19, 20, 22 | `BSTR` |
| others | `LONG` |

**XAP deployment requests** (`IPMDeploymentManager` 6…9, 11, 12, 28):

| Offset | `struct72` (6, 8, 11) | `struct52` (7, 12, 28) | `struct48` (9) |
|--------|-----------------------|------------------------|----------------|
| 0x00 | `GUID`: product ID | `GUID` | `GUID` |
| 0x10 | `BSTR`: path of the package file | `BSTR` | `BSTR` |
| 0x14 | `GUID` | `GUID` | `GUID` |
| 0x24 | `BYTE*` (licence ?) | `BYTE*` | `BYTE*` |
| 0x28 | `LONG`: size of +0x24 | `LONG` | `LONG` |
| 0x2C | `LONG` | `BSTR` | `BSTR` |
| 0x30 | `LONG`: flags | `LONG` | – |
| 0x34 | `GUID` | – | – |
| 0x44 | `BSTR` | – | – |

The `struct72` fields are proven by `PackageManager::BeginInstall` (0x1004EC78 in pacmanserver.dll). It formats +0x00 with `StringFromGUID2`, then returns `E_INVALIDARG` unless the file at +0x10 exists (`PathFileExistsW`, `sub_1004F278`) and +0x24 and +0x28 are both non-zero. `sub_1004F20C` then examines the package (`IsEncryptedXap`, `AppXManifest.xml`) and sets bit 3 of the flags at +0x30 for an encrypted XAP. `CheckExistingRequestInQueue` gets the product ID (+0x00…+0x0C, by value), and `CreateInstallRequest` gets the structure, with a mode chosen from bits 0 and 3 of the flags.

**AppX deployment requests** (`IPMDeploymentManager2`):

| Offset | `struct104` (6 `BeginAppXRegister`) | Offset | `struct100` (8 `BeginAppXInstall`, 9 `BeginAppXUpdate`) |
|--------|-------------------------------------|--------|---------------------------------------------------------|
| 0x00 | `GUID` | 0x00 | `GUID` |
| 0x10, 0x14, 0x18 | 3 `BSTR` | 0x10, 0x14 | 2 `BSTR` |
| 0x1C, 0x2C, 0x3C | 3 `GUID` | 0x18, 0x28, 0x38 | 3 `GUID` |
| 0x4C | `BYTE*` | 0x48 | `BYTE*` |
| 0x50 | `LONG` | 0x4C | `LONG` |
| 0x54 | enum | 0x50 | enum |
| 0x58, 0x5C, 0x60 | 3 `LONG` | 0x54, 0x58, 0x5C | 3 `LONG` |
| 0x64 | pointer to an array (`FC_BOGUS_ARRAY`) | 0x60 | pointer to an array (`FC_BOGUS_ARRAY`) |

[TH.exe](../applications/th.md#beginappxregister-parameter) fills `struct104` as follows: +0x00 product ID, +0x10 path of `AppxManifest.xml` (deploy of an unsigned package), +0x18 a string used instead of +0x10 for a signed install, +0x4C / +0x50 licence and its size (signed install only), +0x54 1 (8 for a bundle manifest), +0x58 flags (2 = deploy, 0x10000 = SD card), +0x60 / +0x64 number and array of dependency packages.

`BeginAppxDownload` (method 15) takes an array of `struct28`: `GUID`, `BSTR`, `LONG`, `LONG`.

**Package found** (`pkg104`, returned by `FindPackages` / `FindPackagesByNamePublisher`, methods 11 and 12):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 16 | `GUID` |
| 0x10…0x1C | 4 × 4 | `LPWSTR` |
| 0x20 | 2 | `SHORT` |
| 0x28 | 8 | 64-bit value (version ?) |
| 0x30…0x3C | 4 × 4 | `LONG` |
| 0x40…0x58 | 7 × 4 | `LPWSTR` |
| 0x5C, 0x60 | 4 each | Unique pointers to other `pkg104` (linked list ?) |

**Tile** (`struct192`, `IPMTileInfo` 22 and the array returned by `IPMEnumerationManager` 19):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `LONG` |
| 0x04 | 16 | `GUID` (product ID ?) |
| 0x14 | 4 | `BSTR` (tile ID ?) |
| 0x18 | 4 | enum |
| 0x1C | 128 | Fixed array |
| 0x9C, 0xA0 | 4 each | `LONG` |
| 0xA4 | 4 | enum |
| 0xA8 | 4 | `BYTE*` |
| 0xAC, 0xB0, 0xB4 | 4 each | `LONG` |
| 0xB8 | 8 | `struct8` |

**Application** (`struct68`, `IPMApplicationInfo` 49 and the array returned by `IPMEnumerationManager` 20):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `LONG` |
| 0x04 | 16 | `GUID` (product ID ?) |
| 0x14, 0x18 | 4 each | `BSTR` |
| 0x1C | 4 | `LONG` |
| 0x20 | 4 | enum |
| 0x24 | 16 | `GUID` |
| 0x34 | 4 | enum |
| 0x38, 0x3C | 4 each | `LONG` |
| 0x40 | 2 | `SHORT` |

**Live tile job** (`struct44`, by value to `IPMLiveTileJobManager` 3 `AddLiveTokenSubscription`): enum (+0x00), enum (+0x04), 4 `LONG` (+0x08…+0x14), two `struct8` (+0x18, +0x20), `LONG` (+0x28).

**`struct8`**: two `LONG` (a `FILETIME` ?); used by `IPMApplicationInfo` 14 and 52, `IPMLiveTileJobInfo` 5…8, the tile structure and `struct44`.

**Background service notification** (`struct3360`, 0xD20 bytes, `IPMBssWriter` 3 / 6, `IPMBssManager` 3 / 7, `IPMBssNotificationEnumerator`; a row of the `BSSACTION` table of [pacmanserver.dll](./pacmanserver.md#database) ?):

| Offset | Size | Comment |
|--------|------|---------|
| 0x000, 0x010 | 16 each | `GUID` |
| 0x020 | 4 | `LONG` |
| 0x024, 0x034 | 16 each | `GUID` |
| 0x044…0x050 | 4 × 4 | enum |
| 0x054 | 16 | `GUID` |
| 0x064 | 4 | `LONG` |
| 0x068, 0x268 | 512 each | Fixed arrays (`WCHAR[256]` ?) |
| 0x468, 0x568 | 256 each | Fixed arrays (`WCHAR[128]` ?) |
| 0x668 | 128 | Fixed array |
| 0x6E8 | 520 | Fixed array (`WCHAR[MAX_PATH]` ?) |
| 0x8F0, 0xAF0 | 512 each | Fixed arrays |
| 0xCF0 | 4 | `LONG` |
| 0xCF4, 0xD04 | 16 each | `GUID` |
| 0xD14, 0xD18, 0xD1C | 4 each | `LONG` |

**Deployment extension handler data** (method 3 and 4 of the `IMC*DEHExt` interfaces, after a package name ? string): structures of string pointers.

| Structure | Interfaces | Layout |
|-----------|------------|--------|
| `deh4` | `IMCFileOpenPickerDEHExt`, `IMCFileSavePickerDEHExt`, `IMCCachedFileUpdaterDEHExt` | `LPWSTR` (the cached file updater one is a `LONG`) |
| `deh8` | `IMCShareTargetDEHExt` | 2 `LPWSTR` |
| `deh12` | `IMCProtocolDEHExt` | 3 `LPWSTR` |
| `deh24` | `IMCFileTypeAssocDEHExt` | 6 `LPWSTR` |
| `deh48` | `IMCVisualElementsDEHExt` | 5 `LPWSTR` (+0x00…+0x10), `LONG` (+0x14), 4 `LPWSTR` (+0x18…+0x24), `LONG` (+0x28), `LPWSTR` (+0x2C) |
