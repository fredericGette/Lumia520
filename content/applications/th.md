## TH.exe

TaskHostRunner: a console tool that installs, deploys, updates, uninstalls, moves and launches XAP and AppX applications from the command line.  
`TH.exe` is a Microsoft internal test tool (605 928 bytes, about 1 440 functions, no symbols; PDB `th.pdb`, source paths `src\appplat\test\common\tools\packagemanager\taskhostrunner\th.cpp` and `src\appplat\test\appmodel\packagemanager\lib\*.cpp`). It isn't part of the phone image: CMD Injector (WP8) copies it to `System32` together with `th.dll` and `TestDeploymentInfo.dll` (its `Contents\ConsoleApps` folder), and its "PacMan" page runs it. The tool has no install logic of its own. It is a client of the Package Manager service ([pacmanserver.dll](../libraries/pacmanserver.md)): every operation is a call to `IPMDeploymentManager` / `IPMDeploymentManager2` of `CLSID_PMSvc` (see [PacManClient.dll](../libraries/pacmanclient.md#managers-methods-of-cpmsvc)), followed by a wait for the PacMan life cycle notification of the product ID.  
A large part of the binary is code linked from the PacMan test library that the command line never reaches: the PacMan database code (`PacManDBManager`, ESENT `PackageManager\pacman.edb`, instance `PACMAN_JET_INSTANCE`), `CapabilityCheck`, `QueryExecutableProperties`, `CancelAgentRequests`, the tile templates and test GUIDs. No direct call path leads to them from `wmain`.

Location on the phone: `C:\Windows\System32\TH.exe` (copy of `C:\Data\Programs\WindowsApps\CMDInjector_1.3.0.0_arm__kqyng60eng17c\Contents\ConsoleApps\TH.exe`, same bytes).  
Started by: CMD Injector's PacMan page, through its injected command prompt: `TH.exe "<package>" -<option> ><log> 2>&1&echo. ><done>` (install, update, deploy), `TH.exe "<package>" -e "C:\Data\Programs\{<GUID>}"&del "C:\Data\Programs\{<GUID>}\AppxSignature.p7x"&TH.exe "C:\Data\Programs\{<GUID>}\AppxManifest.xml" -de ...` ("register" mode), and `start TH.exe "<update>" -di` for its own updates (strings of `CMDInjector WP8.dll`). It also works from an SSH or telnet prompt.

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-core-com-l1-1-1 | `CoInitializeEx`, `CoUninitialize`, `CoCreateInstance`, `CLSIDFromString`, `StringFromCLSID`, `StringFromGUID2`, `StringFromIID`, `CoCreateGuid`, `CoTaskMemAlloc`, `CoTaskMemFree`, `CoImpersonateClient`, `CoRevertToSelf` |
| OLEAUT32 | `SysAllocString`, `SysAllocStringLen`, `SysAllocStringByteLen`, `SysFreeString`, `SysStringLen`, `SysStringByteLen`, `VariantInit`, `VariantClear`, `VarBstrCat` |
| [SecRuntime.dll](../libraries/secruntime.md) | `GetDeveloperUnlockState`, `SetDeveloperUnlockState`, `CapabilityCheck`, `QueryExecutableProperties`, `ReleaseExecutableProperties` |
| WPCOREUTIL | `GetStorageSettings`, `SetStorageSettings`, `GetStorageDeviceInfo`, `RecursiveCreateDirectory`, `RecursiveRemoveDirectory`, `RecursiveRemoveDirectoryEx`, `CreateStreamOnFile`, `SHGetKnownFolderPath` |
| [TestDeploymentInfo](../libraries/testdeploymentinfo.md) | `GetTestDeployBinPath` |
| TH (`th.dll`) | ordinal 7 |
| WPTrust | `SV_AuthenticateXAPFile`, `SV_AuthenticateAppXSignatureFile`, `SV_AuthenticateEmbeddedSignedFile`, `SV_DeallocateSignedFileInfoMember` |
| EMCLIENT | `CancelAgentRequests` |
| ESENT | 33 `Jet*` functions (`JetInit`, `JetCreateInstanceW`, `JetAttachDatabaseW`, `JetOpenTableW`, `JetSeek`, `JetRetrieveColumns`, …) |
| WININET | `InternetOpenA`, `InternetConnectA`, `InternetCrackUrlA`, `InternetSetOptionW`, `HttpOpenRequestA`, `HttpSendRequestA`, `HttpQueryInfoA`, `InternetReadFile`, `InternetCloseHandle` |
| WS2_32 | `WSAStartup`, `WSACleanup` |
| CRYPT32 | `CertOpenStore`, `CertCloseStore`, `CertDuplicateStore`, `CertFindCertificateInStore`, `CertAddCertificateContextToStore`, `CertGetCertificateContextProperty`, `CertFreeCertificateContext`, `CertNameToStrW`, `PFXImportCertStore`, `CryptAcquireCertificatePrivateKey` |
| bcrypt | `BCryptOpenAlgorithmProvider`, `BCryptCloseAlgorithmProvider`, `BCryptGenerateSymmetricKey`, `BCryptSetProperty`, `BCryptGetProperty`, `BCryptDecrypt`, `BCryptDestroyKey` |
| ncrypt, CRYPTSP | `NCryptFreeObject`; `CryptReleaseContext` |
| XmlLite | `CreateXmlReader` |
| CoreMessaging, CoreUIComponents | `CoreUICreate`; `CoreUIFactoryCreate` |
| ext-ms-win-session-usertoken-l1-1-0 | `QueryUserToken` |
| api-ms-win-security-base-l1-2-0, api-ms-win-security-sddl-l1-1-0 | `ImpersonateLoggedOnUser`, `RevertToSelf`; `ConvertSidToStringSidW` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateProcessW`, `OpenThreadToken`, `GetCurrentThread`, `GetCurrentProcess`, `GetCurrentProcessId`, `TerminateProcess` |
| api-ms-win-core-file-l1-2-1 | `CreateFileW`, `ReadFile`, `WriteFile`, `GetFileSize`, `SetFilePointer`, `GetFileAttributesW`, `DeleteFileW`, `CreateDirectoryW`, `FindFirstFileW`, `FindNextFileW`, `FindClose`, `GetTempPathW` |
| api-ms-win-core-kernel32-legacy-l1-1-1 | `CopyFileW`, `LoadLibraryW` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleExW`, `GetModuleHandleA`, `GetModuleFileNameA` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey` |
| api-ms-win-core-memory-l1-1-2 | `CreateFileMappingW`, `MapViewOfFile`, `UnmapViewOfFile` |
| api-ms-win-core-path-l1-1-0, api-ms-win-core-shlwapi-legacy-l1-1-0, api-ms-win-core-shlwapi-obsolete-l1-1-0 | `PathCchFindExtension`, `PathCchCombine`; `PathFileExistsW`, `PathFindFileNameW`, `PathRemoveExtensionW`, `PathRemoveFileSpecW`; `StrStrIW`, `StrStrIA`, `SHLoadIndirectString` |
| api-ms-win-shcore-stream-l1-1-0 | `SHCreateStreamOnFileEx` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| RPCRT4 | `RpcServerInqCallAttributesW` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `ResetEvent`, `CreateSemaphoreExW`, `ReleaseSemaphore`, `WaitForSingleObject`, `Sleep`, critical sections, `InitOnceBeginInitialize`, `InitOnceComplete` |
| api-ms-win-core-string-l1-1-0, -l2-1-0, -obsolete-l1-1-0 | `MultiByteToWideChar`, `WideCharToMultiByte`, `CompareStringW`; `CharLowerBuffW`; `lstrcmpiW`, `lstrlenW` |
| api-ms-win-core-localization-l1-2-1, -obsolete-l1-2-0, api-ms-win-core-timezone-l1-1-0, api-ms-win-core-sysinfo-l1-2-2 | `FormatMessageW`; `GetSystemDefaultUILanguage`; `FileTimeToSystemTime`; `GetTickCount`, `GetSystemTimeAsFileTime` |
| api-ms-win-core-handle-l1-1-0, api-ms-win-core-heap-obsolete-l1-1-0, api-ms-win-core-debug-l1-1-1, ntdll | `CloseHandle`; `LocalAlloc`, `LocalFree`; `DebugBreak`; `DbgPrint` |
| api-ms-win-core-errorhandling-l1-1-2, api-ms-win-core-rtlsupport-l1-2-0 | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`; `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | 68 functions: `wprintf`, `printf`, `_wfopen_s`, `fgetws`, `fclose`, `_wfullpath`, `wcstok_s`, `_wcsicmp`, `rand_s`, C++ exception and string helpers, CRT startup |

The exception filters, `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind`, `GetModuleHandleA`, `TerminateProcess` and most of msvcrt are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. ESENT, `CapabilityCheck`, `QueryExecutableProperties` and `CancelAgentRequests` are used only by the unreachable linked code.  
Export: `GetKato` (0x1047B4C). Kato is the logging interface of the Windows CE / Windows Phone test harness (Tux).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `th.dll` (`C:\Windows\System32\th.dll`, 73 728 bytes, copied by CMD Injector) | Static import, ordinal 7 (`sub_1047084`) | Called with the `MY` certificate store (`CertOpenStore(CERT_STORE_PROV_SYSTEM, …, L"MY")`) and a callback (`sub_1046F24`) that compares the EKU of each certificate with `HKLM\Software\Microsoft\GwpCPC` `EKU`: looks for a client certificate, probably for the licence server ? |
| [TestDeploymentInfo.dll](../libraries/testdeploymentinfo.md) (copied by CMD Injector) | Static import, `GetTestDeployBinPath` | Folder of the test tools (`\data\test\bin\`, hard-coded), used to build the command line of [TestNavigationAPI.exe](./testnavigationapi.md) (`-r`) |
| [TestNavigationAPI.exe](./testnavigationapi.md) | `CreateProcessW` (`sub_104D284`): `\data\test\bin\TestNavigationAPI.exe LaunchModernApplication <AUMID>` (folder from `GetTestDeployBinPath`) | Launches an AppX application (`-r`, `-ir`, `-dir`). Not present on the phone, so these options can't launch a modern application. The analysed build of `TestNavigationApi.exe` also requires a `<TileID>` after the AUMID ([Parameters](./testnavigationapi.md#parameters)) |
| PacMan service [pacmanserver.dll](../libraries/pacmanserver.md), `CLSID_PMSvc` `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` | `CoCreateInstance(CLSCTX_ALL (0x17))` with `IPMDeploymentManager` `{35F785FA-1979-4A8B-BC8F-FD70EB0D1544}`, `IPMDeploymentManager2` `{75E430A7-9559-4828-98DD-BC657620AB87}`, `IPMEnumerationManager` `{698D57C2-292D-4CF3-B73C-D95A6922ED9A}`, `IPMLicenseManager` `{11ED725B-8820-45F8-96E6-6845524E46DA}` | All the operations ([PacMan calls](#pacman-calls)). A new instance is created for every call (`sub_1055B7C` … `sub_1056C54`, `pmclientapiwrapper.cpp`) |
| COM server `{D0DF0C7D-33BF-4E04-9B11-B1D7AE572EED}` | `CoCreateInstance(CLSCTX_ALL)`, `IPMNotificationManager` `{095BF7A5-F134-42B9-A4B0-7C5F1A9E199A}` (`sub_1058E84`, `PMTestNotificationQueue`) | Registers a sink for the life cycle and tile notifications, used to wait for the end of each operation ([Waiting for the result](#waiting-for-the-result)) |
| `WindowsEmbeddedDeviceLockdownProfile.dll` | `LoadLibraryW` + `GetProcAddress("LockDownMgrIsAppAllowed")` (`sub_1058E84`) | Lockdown check of the application, when the DLL exists ? |
| `pacman_ierror.dll`, `pacmanerr.dll`, `EmErr.dll` | `LoadLibraryW` as message modules (`sub_1056DDC`, names from `sub_1023B40`, `sub_1023B68`, `sub_1023B90`), then `FormatMessageW` | Text of a failed HRESULT: `- PacMan Error Code = 0x%x` / `- PacMan Error Description = %s` |
| `AppxPackaging.dll` | `LoadLibraryExW` (`sub_1054B48`), `GetProcAddress` ordinal 3 (`unpack`) or 4 (`unbundle`), called with `(package, destination folder, 0, 0, 0)` (`sub_1054514`) | Unpacks an `.appx` / `.appxbundle` (`-e`, `-di`) |
| `ZipContainer.dll` | `LoadLibraryW` + `ZipContainerInitialize`, `ZipContainerUninitialize`, `ZipContainerCreateArchiveOnFile` (`sub_102F864`) | Opens XAP files (manifest, encrypted XAP) |
| `AppxFactory` `{5842A140-FF9F-4166-8F5C-62F5B7B0C781}` (`IAppxFactory` `{BEB94909-E451-438B-B5A7-D79E767B75D8}`), `AppxBundleFactory` `{378E0446-5384-43B7-8877-E7DBDD883446}` (`IAppxBundleFactory` `{BBA65864-965F-4A5F-855F-F074BDBF3A7B}`), `OpcFactory` `{6B2D6BA0-9F3E-4F27-920B-313CC426A39E}` (`IOpcFactory` `{6D0B4446-CD73-4AB3-94F4-8CCDF6116154}`) | `CoCreateInstance` (`sub_102D358`, `sub_1054BD8`, `sub_1054E60`, `sub_1055090`, `sub_10556A8`) | Reads the AppX manifest: product ID, package full name, bundle or not |
| MSXML 6 `{88D96A05-F192-11D4-A65F-0040963251E5}` (`IXMLDOMDocument` `{2933BF81-7B36-11D2-B20E-00C04F983E60}`, `IXMLDOMDocument2` `{2933BF96-…}`) | `CoCreateInstance` (`sub_10461F0`, `sub_10469E4`) | Licence XML (`//*[local-name() = 'DATA']/*[local-name() = 'KID']` …) |
| COM server `{66D0DB14-5638-475F-A386-629522D8C461}` (IID `{56A4BDD5-835A-4DD5-95B5-44805CA37DB0}`) | `CoCreateInstance` (`sub_104C3A4`) | OMA-DM configuration manager (`ppCfgMgr2`) ?: `-m` writes `./vendor/MSFT/ALBR` … `InstallFromMarketplace` with `AppMetaData` = `NOID;<metadata>` |
| `https://licensing.marketplace.windowsmobile-int.com/rightsmanager.asmx`, `…/objectheader.asmx` | WININET (`sub_102DF08`), SOAP `AcquireLicense` (`User-Agent: DevPlat_License`) and `GetEncryptionKey` (`User-Agent: DevPlat_Encryption`) | Licences and XAP decryption keys from Microsoft's internal ("-int") Marketplace servers (signed installs `-i`, `-ul`); the server URL can be replaced by `HKLM\Security\PacMan` `LicenseServer` |
| `<package>_License.xml` | `CreateFileW` | Pre-install licence placed next to the package, used instead of the server (`Checking if a pre-install license exists for %s...`) |
| `-lp <license.xml>`, `-file <config.xml>`, `-if` / `-df <list.txt>` | `CreateFileW`, `CopyFileW`, `_wfopen_s` + `fgetws` | Licence file, XML file copied to the install folder of the XAP, list of packages (one per line) |
| `c:\Data\Test\AppPlat\TH_Temp`, `<temp>\PMTest\XapUtil` | `RecursiveCreateDirectory`, `CreateFileW`, `DeleteFileW` | Work folders: decrypted XAP, `WMAppManifest.xml` / `WMAppPRHeader.xml` extracted from a XAP |

### Parameters

`wmain` (`sub_1048E80`) calls `WSAStartup(0x202)` and `CoInitializeEx(NULL, COINIT_MULTITHREADED)`, then the parser `sub_1047B68`. The parser turns the command line into a mode bitmask (`dword_10630C8`) and options, and `sub_1048E80` runs the handler of each mode bit. `argv[1]` is the package (made absolute with `_wfullpath`, replaced by an empty string if the file doesn't exist), a `{PRODUCTID}`, or a single option. `argv[2]` is the operation, and options can follow it (up to 7 arguments). Options are compared case-insensitively (`lstrcmpiW`). Without arguments, or with `-?` / `/?`, `sub_104A294` prints the usage and the list of installed applications (`sub_104B900`). The process exit code is 0, even when the operation fails (checked on the phone with a missing package): read the output (`TH: Completed Successfully.` or `ERROR: …`).

The package type comes from its extension (`.XAP`, `.APPX`, `.APPXBUNDLE`). The product ID comes from `-id {GUID}` or is read from the package (`sub_104A138`, `GetProductIdFromAppPackage` = `sub_104DF10`; for an AppX it's the GUID of the manifest, e.g. `{9AB7781E-…}` for an `Identity Name="9ab7781e-…"`).

| Command line | Mode | Usage |
|---|---|---|
| `TH <pkg>` | 3 (initial value of `dword_10630C8`) | Install (1) and launch (2) |
| `TH <pkg> -i [-dp <dep.appx>] [-lp <license.xml>] [-lt FULL\|TRIAL\|BETA [-expirydate <mm/dd/yy [hh:mm:ss]>]] [-file <cfg.xml>] [-disableuninstall] [-sdoptout] [-lightup] [-id {GUID}]` | 1 | Install a signed package (`sub_104B1A4`). If PacMan reports it as already installed, uninstalls it and installs again. On failure prints "Please try the -di option for unsigned applications." |
| `TH <pkg> -is …` | 1, SD | Same, on the SD card (`dword_10AB070` = 1) |
| `TH <pkg> -oi {GUID}` | 1 | Install with this Marketplace offer ID |
| `TH <pkg> -ir` / `-irs` | 1 + 2 + 0x10 | Install if not installed (`IPMEnumerationManager::get_ApplicationInfo`), then launch; `-irs` on SD |
| `TH <pkg> -di [-dp <dep.appx>] [-lightup]` | 0x20 | Deploy an unsigned (developer) package (`sub_104B380`), see [Deploy (-di)](#deploy--di). An `.appxbundle` is refused ("Side loading of an Appx bundle is not supported") |
| `TH <pkg> -dis …` | 0x20, SD | Same, on the SD card |
| `TH <pkg> -dir` / `-dirs` | 0x20 + 2 + 0x10 | Deploy if not deployed, then launch; `-dirs` on SD |
| `TH <AppxManifest.xml> -de [-dp <dep.appx>]` | 0x2000 | Register an already extracted package (`sub_10502A8`, the second half of `-di`) |
| `TH <pkg> -e <folder>` | 0x1000 | Extract the package to `<folder>` (`sub_1054514`, `AppxPackaging.dll` `unpack` / `unbundle`); no PacMan call |
| `TH <pkg> -sload` | 0x20000 | Sideload an AppX (`sub_104E614` → `sub_104F864` → `BeginAppXInstall`) |
| `TH <pkg> -ua [-dp …] [-lp …]` | 0x100 | Update an installed package (`sub_1056B40` `IsTrialLicense`, then `sub_104E7B4`): XAP `BeginUpdate`, AppX the install path again |
| `TH <pkg> -uda` | 0x10000 | Update a deployed package (`sub_104E974`): AppX = `-di` again; XAP = `BeginUninstallWithOptions(…, 0x1000 PM_REMOVAL_OPTIONS_PRESERVE_APPLICATION_DATA)` + deploy, or `BeginUpdateDeployedPackage` |
| `TH <pkg> -usload` | 0x40000 | Update a sideloaded AppX (`sub_104EBC0` → `BeginAppXUpdate`) |
| `TH <pkg>\|{PRODUCTID} -u [-force]` | 4 | Uninstall (`sub_104B138` → `sub_104ED04`): XAP `BeginUninstall`, AppX `BeginAppXUninstall(productId, option)`, wait up to 600 000 ms. `-force` (`dword_10AB078`) for an application installed with `-disableuninstall` |
| `TH <pkg> -du` | 4 | Undeploy (same handler as `-u`) |
| `TH {PRODUCTID} -mv` | 0x8000 | Move between SD and internal storage (`sub_104F034` → `IPMDeploymentManager2::BeginMove`) |
| `TH <pkg> -checkapplicability` | 0x400000 | `IPMDeploymentManager2::AppxGetApplicability(<package full name>)` (`sub_10532DC`); prints "The package is APPLICABLE." or "NOT APPLICABLE." |
| `TH <pkg> -r` | 2 | Launch (`sub_104D284`): AppX → `TestNavigationAPI.exe LaunchModernApplication <AUMID>` (AUMID from `IPMApplicationInfo2::get_InvocationInfo`); XAP → CoreUI session manager (`sub_104D628`) |
| `TH <uri> -b` | 0x40 | Launch a URI (`app://<guid>/<page>`): `CoreUICreate` / `CoreUIFactoryCreate`, connection `System\NavigationServer_TestSessionManager`, `LaunchNewSession` (`sub_104D18C`), the endpoint also used by [TestNavigationApi.exe](./testnavigationapi.md#connection) |
| `TH <pkg> -v` | 8 | Verify the signature (`sub_102EB98`, WPTrust `SV_AuthenticateEmbeddedSignedFile`, `SV_AuthenticateXAPFile`, `SV_AuthenticateAppXSignatureFile`) |
| `TH <pkg>\|{PRODUCTID} -revoke` | 0x200 | `IPMDeploymentManager::RevokeLicense` (`sub_1056628`) |
| `TH <pkg> -ul [-lt …] [-lp …]` | 0x80 | Update the licence: from the server or a file, then `BeginUpdateLicense` |
| `TH {PRODUCTID} -m [-lt FULL\|TRIAL]` | 0x400 | Install from the Marketplace (`sub_104C450`, configuration manager `./vendor/MSFT/ALBR`, `InstallFromMarketplace`) |
| `TH -if <list.txt>` / `TH -df <list.txt>` | 1 / 0x20 | Install / deploy every package of the list (`sub_104AE7C`) |
| `TH -ml` | 0x800 | List the installed applications (`sub_104B900`, mode 1: `ProductID;OfferID;App`) |
| `TH -checkcpl` | 0x100000 | `GetStorageSettings`: prints "CPL set to install on SD" / "on internal" (`sub_104DBEC`, also used by the install paths) |
| `TH -flipcpl` | 0x80000 | Toggles the "install apps on SD" setting (`sub_104DC3C`): `GetStorageSettings(2, 0, 2, &value)`, bit 0x10 set if clear, else the whole value is cleared (`value &= ~value`), then `SetStorageSettings(2, 0, 2, value)` |
| `TH -pairsd` | 0x200000 | `SetStorageSettings` ("Failed to pair SD, error: 0x%x", `sub_104DCC8`) |

`-flipcpl`, `-checkcpl` and `-pairsd` aren't in the usage text.  
The deploy (0x20) and install (1) handlers start with `GetDeveloperUnlockState`. If the state isn't 1 they print "Device is not developer unlocked. Unlocking.." and call `SetDeveloperUnlockState(1)`. In this build `GetDeveloperUnlockState` of [SecRuntime.dll](../libraries/secruntime.md) always returns 1, so the output is always "Device is developer unlocked.".

### Installed applications list

`sub_104B900` impersonates the logged-on user (`QueryUserToken(0)`, `ImpersonateLoggedOnUser`), creates `IPMEnumerationManager` and enumerates the applications (`get_AllApplications`, method 3). For each one it prints `AppTitle` (`SHLoadIndirectString` for `@{…}` resource strings), `AUMID` (modern application, `IPMApplicationInfo2::get_InvocationInfo`) or `InvocationInfo` (`app://<GUID>/_default`, XAP), `InstallType`, `InstallLocation`, `ProductID` and `MarketPlace OfferID`. The install types are printed as `NORMAL (Marketplace)`, `IN_ROM (1st party)`, `PA (OEM/MO app)`, `DEBUG (Developer deploy)`, `ENTERPRISE`, `INVALID`. In mode 1 (`-ml`) it prints only `ProductID;OfferID;App` lines.

### Deploy (-di)

`sub_104B380` → `sub_104E404` (`install.cpp`):

1. Product ID (`GetProductIdFromAppPackage`) unless `-id` was given. Package type: `IsXapPackage` (`sub_104E040`), `IsAppxFatPackage` (`sub_104E138`, i.e. a bundle).
2. XAP → `sub_104F1D8` → `sub_104F334` → `IPMDeploymentManager::BeginDeployPackage` (`struct72`, see [PacManClient.dll](../libraries/pacmanclient.md#structures)).
3. AppX → `sub_104F2B4` → `sub_1050080`:
   1. Layout folder (`sub_104FC70`). Internal storage: `c:\Data\SharedData\PhoneTools\<package full name>\`. SD card, when `-dis` or when the storage setting says SD: `<SD root>PhoneTools\AppxLayouts\…` (root from `GetStorageDeviceInfo`; `0x8103012A` if the card isn't mounted). The package is unpacked there with `AppxPackaging.dll` (`sub_1054514`), and the manifest path is `<folder>\AppxManifest.xml` (`\AppxMetadata\AppxBundleManifest.xml` for a bundle).
   2. No licence is requested in deploy mode.
   3. Registration (`sub_10502A8`, the same function as `-de`): the dependencies given with `-dp` are installed first, each with `IPMDeploymentManager2::BeginAppXInstall` (`sub_104F764` → `sub_105135C`). The main package is then registered: `IPMDeploymentManager2::BeginAppXRegister` with the [request below](#beginappxregister-parameter) (`sub_105150C` → `sub_1055E2C`).
4. If the result is `0x8103010D` (already deployed): "The package is already deployed. Undeploying and re-reploying..", uninstall (`sub_104B138`), deploy again.

Checked on the phone with a Debug build: `TH.exe C:\Data\Users\Public\wp81DxTest.appx -di` unpacked the package to `C:\Data\SharedData\PhoneTools\9ab7781e-aa76-47af-ae47-ac51eb44a90b_1.0.0.0_arm__fkkem3zpb3x42\` and the application appears as `DEBUG (Developer deploy)`.

**Install (-i) of an AppX** follows the same `sub_104F2B4` path with the deploy flag clear. A licence is obtained first (`sub_10509DC`: `<package>_License.xml`, `-lp` file, or the licence server with `-lt`). The layout folder is `c:\Data\Programs\WindowsApps\<package full name>\` (SD: `<SD root>WPSystem\Apps\WindowsApps\…`). TH doesn't write it itself: PacMan fills it, through `IPMDeploymentManager2::BeginAppxDownload` (method 15) with the package path (`sub_105470C` → `sub_1055EFC`). The `-dp` dependencies are unpacked the same way and passed in the request's dependency array. Then `BeginAppXRegister`. A XAP uses `IPMDeploymentManager::BeginInstall` (`sub_105116C`).

### BeginAppXRegister parameter

`IPMDeploymentManager2` method 6 (`BeginAppXRegister`) receives a pointer to a 0x68-byte structure (`struct104` of [PacManClient.dll](../libraries/pacmanclient.md#structures)), zeroed and then filled by `sub_10502A8`:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 16 | Product ID | From the package when not given (`sub_1053BA8`) |
| 0x10 | 4 | `BSTR`: path of `AppxManifest.xml` | Deploy mode only |
| 0x18 | 4 | `BSTR` | Install mode only: second string returned by the layout step (`sub_104FC70`) ? |
| 0x1C | 16 | `GUID` | From the caller (offer ID ?) |
| 0x2C | 16 | 0 | |
| 0x3C | 16 | `GUID` | From the caller ? |
| 0x4C | 4 | `BYTE*`: licence | Install mode only (NULL when deploying) |
| 0x50 | 4 | Size of the licence | Install mode only |
| 0x54 | 4 | 1, or 8 for a bundle manifest (`IsBundleManifest`, `sub_10555B0`) | Package type ? |
| 0x58 | 4 | Flags: 2 = deploy (unsigned), 0x100 = ? (caller flag), 1 = ? (from the licence step), 0x10000 = SD card (`-is` / `-dis`, or the storage setting says SD), 0x20000 = ? (caller flag) | |
| 0x5C | 4 | 0 | |
| 0x60 | 4 | Number of dependencies | 0 in deploy mode (they're installed before) |
| 0x64 | 4 | Dependency array | 0x28-byte entries: +0x20 path of the `-dp` package, +0x24 `BSTR` path of its unpacked `AppxManifest.xml` |

### PacMan calls

The wrappers (`pmclientapiwrapper.cpp`) each create `CLSID_PMSvc` with `CoCreateInstance(CLSCTX_ALL)` and call one method (vtable index of [PacManClient.dll](../libraries/pacmanclient.md#managers-methods-of-cpmsvc)):

| Wrapper | Interface | Index, method | Used by |
|---------|-----------|---------------|---------|
| `sub_1055C8C` | `IPMDeploymentManager` | 6 `BeginInstall` | XAP `-i` |
| `sub_1056428` | `IPMDeploymentManager` | 7 `BeginUpdate` | XAP `-ua` |
| `sub_105685C` | `IPMDeploymentManager` | 8 `BeginDeployPackage` | XAP `-di` |
| `sub_105600C` | `IPMDeploymentManager` | 10 `BeginUninstall` | XAP `-u` |
| `sub_1056738` | `IPMDeploymentManager` | 13 `BeginUpdateLicense` | `-ul` |
| `sub_1056628` | `IPMDeploymentManager` | 17 `RevokeLicense` | `-revoke` |
| `sub_105695C` | `IPMDeploymentManager` | 28 `BeginUpdateDeployedPackage` | XAP `-uda` |
| `sub_1056118` | `IPMDeploymentManager` | 33 `BeginUninstallWithOptions` | XAP `-uda` (option 0x1000) |
| `sub_1055B7C` | `IPMDeploymentManager` | 5 `ReportDownloadComplete` | Install paths |
| `sub_1055E2C` | `IPMDeploymentManager2` | 6 `BeginAppXRegister` | AppX `-i`, `-di`, `-de`, `-ua`, `-uda` |
| `sub_1056228` | `IPMDeploymentManager2` | 7 `BeginAppXUninstall` | AppX `-u` |
| `sub_1055D5C` | `IPMDeploymentManager2` | 8 `BeginAppXInstall` | `-sload`, `-dp` dependencies when deploying |
| `sub_1056528` | `IPMDeploymentManager2` | 9 `BeginAppXUpdate` | `-usload` |
| `sub_105633C` | `IPMDeploymentManager2` | 13 `AppxGetApplicability` | `-checkapplicability` |
| `sub_1055EFC` | `IPMDeploymentManager2` | 15 `BeginAppxDownload` | AppX `-i` (fills `Programs\WindowsApps`) |
| `sub_1056A5C` | `IPMDeploymentManager2` | 16 `BeginMove` | `-mv` |
| `sub_1056C54` | `IPMEnumerationManager` | 9 `get_ApplicationInfo` | "already installed" checks, `-r` |
| `sub_1056B40` | `IPMLicenseManager` | 3 `IsTrialLicense` | `-ua` |

### Waiting for the result

The `Begin*` methods are asynchronous. Before the call, `sub_1058E84` (`PMTestNotificationQueue`) creates `{D0DF0C7D-33BF-4E04-9B11-B1D7AE572EED}` / `IPMNotificationManager` and registers a sink (`RegisterForNotification`). The sink queues the life cycle notifications (`get_Type`, `get_ProductID`, `get_Progress`, `get_HResult`) and the tile notifications (`get_TileType`, `get_TileID`), and signals two semaphores. `sub_1059D68` then waits for the notification of the expected type and product ID, and returns its HRESULT. A failed HRESULT is printed with its PacMan text ([Dependencies](#dependencies), `pacmanerr.dll`). Before `BeginAppXRegister`, `sub_105150C` asks `get_ApplicationInfo` for the product ID. If it returns `0x80070019` (not installed ?), it waits for notification types 0 and 1, otherwise for types 2 and 3 (first install vs. update ?).

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\Security\PacMan` | `LicenseServer` (REG_SZ) | Licence server URL, default `https://licensing.marketplace.windowsmobile-int.com/rightsmanager.asmx` (`sub_102BE2C`) |
| `HKLM\Security\PacManTest` | `InstallAndMoveToSD` | Test hook: install, then move to SD (`sub_1052F74`) |
| `HKLM\Security\PacManTest` | `CancelRestore` | Test hook: "Detected restore-cancellation registry key, simulating restore cancellation" (`sub_1053128`, then `ReportRestoreCancelled` ?) |
| `HKLM\Software\Microsoft\GwpCPC` | `EKU` | EKU of the client certificate looked for in the `MY` store (`sub_1047968`, through `th.dll` ordinal 7) |

### ETW

Providers registered by the linked library code (no call path from the command-line handlers found):

| GUID | Registered by | Use |
|------|---------------|-----|
| `{6C52775A-44CE-44D3-B266-7400DF95FDC4}` | `sub_1045A08` ("Failed to register AppPlat perf provider 0x%08x") | AppPlat performance events |
| `{A0B8AC98-5E7E-40BD-BE8E-96CC6061E0B5}`, `{3C42000F-CC27-48C3-A005-48F6E38B131F}`, `{F4E559CD-6639-46E0-93F8-2AC9D6D33976}` | `sub_1036C40` | ? |
