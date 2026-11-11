## ci.dll

The kernel-mode Code Integrity module: it decides whether an image (driver, DLL, EXE) can be loaded, and at which signing level.  
`ci.dll` isn't a user-mode library but a kernel export driver loaded by [NTOSKRNL.EXE](./ntoskrnl.md) at boot (443 120 bytes, 1473 functions, full public symbols). The kernel calls `CiInitialize` once, gets back a table of 12 callbacks, and calls them for every section created for an image. CI checks the image's embedded Authenticode signature or looks its hash up in the system catalogs (`CatRoot`), with its own minimal crypto (`MinCrypK_*`, `MinCrypt*`, `MinAsn1*`, SymCrypt SHA-1/SHA-256/SHA-384/SHA-512/MD5, RSA "BSafe"). It turns the signer chain into a signing level using the Secure Boot policy of the phone (`CI\Signers`, `CI\Scenarios\<n>`, `EKUMappings`), and caches the result in a kernel extended attribute of the file (`$Kernel.Purge.ESBCache`), protected by the NTFS USN journal. It also checks Appx package files (`\AppxMetadata\CodeIntegrity.cat` of the package) and holds the kernel half of the Protected Environment (PEAuth: boot driver list, GRL revocation list, trust state), queried by `PEAuth.sys` through `CiGetPEInformation`.  
None of the binaries documented here import it: its only clients are NTOSKRNL.EXE (callback table) and `PEAuth.sys` (exports). [dxgkrnl.sys](../drivers/dxgkrnl.md) reads the CI options through `ZwQuerySystemInformation(SystemCodeIntegrityInformation)`, which the kernel answers with [CiQueryInformation](#ciqueryinformation-0x258a0).

Location on the phone: `C:\Windows\System32\ci.dll` ? (standard Windows location; the binary was extracted next to `NTOSKRNL.EXE`).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntoskrnl.exe (files, FSCTL, EA) | `ZwCreateFile`, `ZwOpenFile`, `ZwReadFile`, `ZwWriteFile`, `ZwClose`, `ZwQueryInformationFile`, `ZwQueryDirectoryFile`, `ZwFsControlFile`, `FsRtlKernelFsControlFile`, `FsRtlGetFileSize`, `FsRtlGetFileNameInformation`, `FsRtlReleaseFileNameInformation`, `FsRtlQueryKernelEaFile`, `FsRtlSetKernelEaFile`, `IoGetRelatedDeviceObject`, `IoGetDiskDeviceObject`, `IoGetDeviceAttachmentBaseRef`, `IoFileObjectType`, `ObReferenceObjectByHandle`, `ObOpenObjectByPointer`, `ObQueryNameString`, `ObfDereferenceObject` |
| ntoskrnl.exe (sections) | `ZwCreateSection`, `ZwMapViewOfSection`, `ZwUnmapViewOfSection`, `MmMapViewInSystemSpaceEx`, `MmUnmapViewInSystemSpace`, `MmSectionObjectType`, `ZwSetInformationVirtualMemory`, `RtlImageNtHeader` |
| ntoskrnl.exe (registry, firmware, policy) | `ZwOpenKey`, `ZwCreateKey`, `ZwQueryValueKey`, `ZwSetValueKey`, `ZwEnumerateKey`, `RtlCheckRegistryKey`, `ZwQuerySystemEnvironmentValueEx`, `ZwSetSystemEnvironmentValueEx`, `SeQuerySecureBootPolicyValue`, `ZwQuerySystemInformation`, `InitSafeBootMode`, `KdDebuggerEnabled`, `KdDebuggerNotPresent` |
| ntoskrnl.exe (processes, threads) | `PsGetCurrentProcess`, `IoGetCurrentProcess`, `PsGetCurrentProcessId`, `PsInitialSystemProcess`, `PsIsProtectedProcess`, `PsGetProcessProtection`, `SeLocateProcessImageName`, `PsReferencePrimaryToken`, `PsDereferencePrimaryToken`, `RtlQueryPackageIdentity`, `PsSetCreateProcessNotifyRoutine`, `PsCreateSystemThread`, `PsTerminateSystemThread`, `PsThreadType`, `KeGetCurrentThread`, `KeSetPriorityThread`, `NtQueryInformationThread`, `NtSetInformationThread`, `ZwQueryInformationThread`, `ZwSetInformationThread`, `PsIsCurrentThreadPrefetching`, `KeStackAttachProcess`, `KeUnstackDetachProcess`, `KeExpandKernelStackAndCalloutEx` |
| ntoskrnl.exe (sync, timers, work items) | `ExAcquirePushLockExclusiveEx`, `ExReleasePushLockExclusiveEx`, `ExAcquirePushLockSharedEx`, `ExReleasePushLockSharedEx`, `ExInitializeResourceLite`, `ExDeleteResourceLite`, `ExAcquireResourceExclusiveLite`, `ExAcquireResourceSharedLite`, `ExReleaseResourceLite`, `ExIsResourceAcquiredExclusiveLite`, `ExConvertExclusiveToSharedLite`, `KeEnterCriticalRegion`, `KeLeaveCriticalRegion`, `KeInitializeTimer`, `KeInitializeDpc`, `KeSetCoalescableTimer`, `KeWaitForMultipleObjects`, `ExQueueWorkItem`, `RtlRunOnceExecuteOnce`, `KeQueryActiveProcessorCountEx`, `KeGetCurrentNodeNumber`, `KeTickCount`, `KeBugCheck` |
| ntoskrnl.exe (ETW, audit, debug) | `EtwRegister`, `EtwUnregister`, `EtwEventEnabled`, `EtwWrite`, `SeReportSecurityEventWithSubCategory`, `DbgPrint`, `DbgPrintEx` |
| ntoskrnl.exe (memory, strings, compression) | `ExAllocatePoolWithTag`, `ExAllocatePoolWithQuotaTag`, `ExFreePoolWithTag`, `RtlInitUnicodeString`, `RtlCreateUnicodeString`, `RtlCopyUnicodeString`, `RtlAppendUnicodeToString`, `RtlAppendUnicodeStringToString`, `RtlFreeUnicodeString`, `RtlEqualUnicodeString`, `RtlCompareUnicodeString`, `RtlCompareUnicodeStrings`, `RtlPrefixUnicodeString`, `RtlInitAnsiString`, `RtlAnsiStringToUnicodeString`, `RtlEqualString`, `RtlUnicodeToUTF8N`, `RtlCompareMemory`, `RtlTimeFieldsToTime`, `RtlCompressBuffer`, `RtlDecompressBufferEx`, `RtlGetCompressionWorkSpaceSize`, `qsort`, `bsearch`, `bsearch_s`, `wcsstr`, `wcschr`, `wcslen`, `wcsncmp`, `_wcsicmp`, `_wcsupr`, `strlen`, `swprintf_s`, `_vsnwprintf`, `atoi`, `atol`, `isdigit`, `__chkstk`, `__C_specific_handler` |
| ext-ms-win-ntos-ksigningpolicy-l1-1-0.dll | `CiQueryLoadLegacyDisplayDriversExt`, `SeCodeIntegrityCacheExt` |

`__chkstk`, `__C_specific_handler` and the `/GS` cookie code (`__security_init_cookie`, `__security_push_cookie` / `__security_pop_cookie`, `__GSHandlerCheck*`) are compiler boilerplate. The `ext-ms-win-ntos-ksigningpolicy` API set extension is optional: each call goes through a stub that checks the import is resolved; the host module isn't known.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\SystemRoot\System32\CatRoot\{F750E6C3-38EE-11D1-85E5-00C04FC295EE}\*.cat` | `ZwQueryDirectoryFile` + `ZwOpenFile` / `ZwCreateSection` (`I_ReloadCatalogs`, `I_MapCatalog`) | System catalogs: file hashes and page hashes of the signed binaries |
| `\SystemRoot\System32\CodeIntegrity\bootcat.cache` | `ZwCreateFile` + `RtlCompressBuffer` (`MincrypK_UpdateCatalogCache`); read by `I_LoadCatalogCache` (worker thread `I_LoadCacheWorker`) | Compressed cache of the parsed catalogs, rebuilt after boot (see [Post-boot work](#post-boot-work)) |
| `\SystemRoot\System32\CodeIntegrity\driver.stl` | `MinCrypK_LoadRevocationList` (`CipLoadAndValidateRevocationList`) | Revocation list (revoked certificates / hashes) |
| `<package root>\<package full name>\AppxMetadata\CodeIntegrity.cat` | `CipGetAppxCatalog` | Catalog of an Appx package, used for the files of that package |
| `\SystemRoot\System32\Drivers\PEAuth.sys` | `I_PEVerifyAndLogPEAuthCerts` | Its certificates are checked for the Protected Environment |
| `\??\<DataPath>\Active.GRL` (`DataPath` value of `HKLM\System\CurrentControlSet\Services\PEAuth`) | `GetGRLFileName` + `ReadFromFile` (`MFGetGRL`) | Global Revocation List of the Protected Environment |
| Every boot driver of the loader list | `ZwCreateFile` (`I_PEVerifyBootDrivers`) | Hashed again for the PE trust state |
| Volumes backed by a WIM | FSCTL 0x9031F (`CipLoadWimIdentities`) | Identities of the WIM files, recorded in the file cache EA |

No user-mode process, COM server or DLL is loaded.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 9 | `CiInitialize` | 0x25000 | `ULONG CiOptions`, `LIST_ENTRY *LoaderBootDrivers`, `PVOID *KernelApis`, `CI_CALLBACKS *Callbacks` |
| 8 | `CiGetPEInformation` | 0x25F5C | request buffer, input size, output size, … (→ `PEProcessDispatch`) |
| 10 | `CiVerifyHashInCatalog` | 0x25FC0 | 10 arguments (→ `I_FindFileOrHeaderHashInCatalogs` with "file hash" = 1) |
| 4 | `CiCheckSignedFile` | 0x25FFC | hash, hash size, hash algorithm, `WIN_CERTIFICATE *`, certificate size, 3 output arguments (→ `MinCrypK_CheckSignedFile`) |
| 5 | `CiFindPageHashesInCatalog` | 0x26058 | 9 arguments (→ `I_FindFileOrHeaderHashInCatalogs` with "file hash" = 0) |
| 6 | `CiFindPageHashesInSignedFile` | 0x26094 | 3 arguments (→ `MinCrypK_FindPageHashesInSignedFile`) |
| 7 | `CiFreePolicyInfo` | 0x260B4 | `MINCRYPT_POLICY_INFO *` (→ `MincryptFreePolicyInfo`) |
| 1 | (none) `CiValidateFileAsImageType` | 0x2A274 | see the callback table |
| 2 | (none) `CiRegisterSigningInformation` | 0x2B180 | see the callback table |
| 3 | (none) `CiUnregisterSigningInformation` | 0x2B3E8 | see the callback table |

Ordinals 1…3 are exported without name. `CiVerifyHashInCatalog`, `CiCheckSignedFile`, `CiFindPageHashes*` and `CiFreePolicyInfo` are thin wrappers of the MinCrypK library, used by `PEAuth.sys` ? (the importer isn't analysed). All return an NTSTATUS.

### Startup

`CiInitialize` (0x25000) calls `__security_init_cookie` and `CipInitialize` (0x2563C); there is no `DriverEntry`/`DllMain` work. Most of the initialisation is lazy: [CiInitializePhase2](#ciinitializephase2-0x25288) runs on the first callback.

### CipInitialize (0x2563C)

1. Saves `*KernelApis` (`g_CiKernelApis`), `CiOptions` (`g_CiOptions`, computed by the kernel from the boot options: 6 by default, 0 with `DISABLE_INTEGRITY_CHECKS`, +0x8 with `TESTSIGNING`, see [SepInitializeCodeIntegrity](./ntoskrnl.md#code-integrity)) and the current process (`g_CiSystemProcess`, the System process).
2. Checks `Callbacks->Size == 0x34`, otherwise returns `STATUS_INVALID_PARAMETER_4` (0xC00000F2) after freeing the boot driver list.
3. Copies the loader boot driver list (`LoaderBootDrivers`): for each entry whose status (+0x1C) is 0xC0000428 (`STATUS_INVALID_IMAGE_HASH`), or successful with flag bit 0 (+0x20) set, a 0x18-byte entry + name (entry +0x08, `UNICODE_STRING`) is added to `g_BootDriverList`. Phase 2 logs them (events 3004 / 3025).
4. Crypto self-tests: `SymCryptSha1Selftest`, `SymCryptSha256Selftest`, `SymCryptSha512Selftest`, a 4-way parallel SHA-256 test against known answers (fast fail on mismatch), then `MincrypK_TestPKCS1SignVerify` with SHA-1 (0x8004, 1024-bit key) and SHA-256 (0x800C, 2048-bit key). Failure returns `STATUS_INVALID_IMAGE_HASH`.
5. Initialises the runtime signer list and the WIM list locks, fills the callback table (below) and calls `PESetPhase1Initialization(LoaderBootDrivers)`.

Callback table filled for the kernel (`Callbacks`):

| Offset | Function | Use |
|--------|----------|-----|
| 0x00 | (size, 0x34) | Checked |
| 0x04 | `CiSetFileCache` (0x26E88) | Writes the signing level cache EA of a file |
| 0x08 | `CiGetFileCache` (0x27258) | Reads it |
| 0x0C | `CiQueryInformation` (0x258A0) | `SystemCodeIntegrityInformation` |
| 0x10 | `CiValidateImageHeader` (0x273FC) | Validates an image when its section is created |
| 0x14 | `CiValidateImageData` (0x27FBC) | Validates the page hashes of a page read in |
| 0x18 | `CiHashMemory` (0x26374) | Hash of a buffer |
| 0x1C | `KappxIsPackageFile` (0x31B60) | Is the file under an Appx package root |
| 0x20 | `CiCompareSigningLevels` (0x2B150) | Signing level comparison |
| 0x24 | `CiValidateFileAsImageType` (0x2A274) | Validates a data file as a given image type |
| 0x28 | `CiRegisterSigningInformation` (0x2B180) | Adds a runtime signer |
| 0x2C | `CiUnregisterSigningInformation` (0x2B3E8) | Removes it |
| 0x30 | `CiInitializePolicy` (0x25024) | Reads the policy (below) |

### CiInitializePolicy (0x25024)

Called by the kernel with two output pointers: it returns `&g_CiProtectedContent` in the first and 5 in the second.

1. `ZwQuerySystemInformation(0x8F SystemSecureBootPolicyInformation, buf, 0x18)`: policy publisher GUID (16 bytes), version, options (+0x14). The status 0x80430006 is handled like a debug policy with every option set. A publisher equal to `{0CDAD82E-D839-4754-89A1-844AB282312B}` (`g_DebugPolicyPublisher`) marks a debug policy.
2. Reads the registry configuration (`CipCheckConfigOptions`, see [Registry](#registry)) and the test flags.
3. Turns the policy options into `g_CiDeveloperMode` bits (0x1/0x2/0x4 from the debug policy or options bit 0x10, 0x10/0x80/0x20 from the debug policy and the test flags, 0x220 from bit 0x40, 0x400 from bit 0x200000, 0x8 from bit 0x200, 0x40 from bit 0x1, 0x100 from bit 0x100000) and `g_CiOptions` bits (0x100 from bit 0x20, 0x800 from bit 0x4000, 0x1000 from bit 0x40). The meaning of most bits isn't known; `g_CiDeveloperMode` 0x100/0x200/0x400 are "trust flight signing", "mobile platform" and "ignore flight signing EKU" (names of the globals set in phase 2).
4. `CipReadCustomSigningPolicy` (0x2A848) reads the signers and scenarios of the Secure Boot policy, see [Signing policy](#signing-policy). With no custom signer, `CipSetEKUMappings` reads the Store EKU.
5. Minimum hash algorithm (`g_CiMinimumHashAlgorithm`): 0x800C (SHA-256) without custom signers, otherwise the smallest non-zero hash algorithm of the 18 scenarios.
6. If `g_CiDeveloperMode` bit 0x2 is set, `CipSetUmciExclusionPaths` reads the user-mode exclusion paths (`TRSData`).

### CiInitializePhase2 (0x25288)

Runs once (push lock `g_CiInitLock`, done when the ETW handle is set), from the first `CiQueryInformation` / `CiValidateImageHeader`:

1. `EtwRegister({4EE76BD8-3CF4-44A0-A0AC-3937643E37A3})` (Microsoft-Windows-CodeIntegrity).
2. Reads the UEFI variable `Kernel_FlightSignedNotBefore` (vendor `{77FA9ABD-0359-4D32-BD60-28F4E78F784B}`, 8 bytes).
3. Requires a minimum hash algorithm of SHA-1 (0x8004) or SHA-256 (0x800C), otherwise `STATUS_NOT_SUPPORTED`; with SHA-256, V1 catalogs aren't supported. Initialises SymCrypt and the MinCrypK callbacks (`CipMinCrypK_*`: file open/close and ETW events).
4. Unless `g_CiDeveloperMode` bit 0x40, revokes the pre-release Windows PCA (`MinCryptRevokePrereleaseWindowsPCA`); loads `driver.stl` (`CipLoadAndValidateRevocationList`).
5. `PESetInitialState`, see [Protected Environment](#protected-environment-peauth).
6. Notes WinPE if `HKLM\System\CurrentControlSet\Control\MiniNT` exists.
7. If not in safe mode, not WinPE, `BootCacheDelay` ≠ 0, no kernel debugger (or `g_CiOptions` bit 0x10) and not test signing (`g_CiOptions` bit 0x8): arms a coalescable timer of `BootCacheDelay` seconds (`CipPostBootTimerRoutine` → work item `CipPostBootWorker`, request 0 = update the catalog cache).
8. Logs the boot drivers kept by `CipInitialize`: event 3004 + audit 5038 for a hash failure, event 3025 for a driver without embedded signature.

On failure everything is freed and the error is returned to the caller.

### CiQueryInformation (0x258A0)

`CiQueryInformation(SYSTEM_CODEINTEGRITY_INFORMATION *info, ULONG size, BOOLEAN umci, ULONG *returned)`: runs phase 2, sets `*returned = 8` and requires `size == 8` and `info->Length == 8` (`STATUS_INFO_LENGTH_MISMATCH` otherwise). `CodeIntegrityOptions` (+4):

| Bit | Set when |
|-----|----------|
| 0x01 | `g_CiOptions` 0x2 and (no debugger attached or `g_CiOptions` 0x10): CI enabled |
| 0x02 | `g_CiOptions` 0x8: test signing |
| 0x04 | `umci` argument ≠ 0: UMCI enabled |
| 0x08 | `umci` and `g_CiDeveloperMode` 0x1: UMCI audit mode |
| 0x10 | `umci` and `g_CiDeveloperMode` 0x2: UMCI exclusion paths |
| 0x80 | Kernel debugger enabled and present |
| 0x200 | `g_CiDeveloperMode` 0x100: flight signing trusted |

### CiValidateImageHeader (0x273FC)

Called for every image section: file object, image type, maximum signing level, process, flags, image data context (in/out), required signing level, output signing level, output status, optional signing information output. The flags select the kind of check (bit 0 = kernel driver, bit 1 = page hashes, bit 2 = boot driver ?, bit 3/4 = SDL / protected process checks ?).

1. Runs phase 2, ETW 3038, `CipFixImageType`.
2. Files of a volume with journaling: `CipEnableJournalingAndSetTrust` once (see [File cache](#file-cache)).
3. Cached result: `CipGetFileCache` (or `SeCodeIntegrityCacheExt` when `g_CiOptions` 0x1000); if the cached signing level meets the requested one, done.
4. Otherwise page hashes (`CipValidatePageHash`: catalog, hint catalog or the image certificate) or the whole file hash (`CipValidateFileHash`: embedded signature, system catalogs, Appx catalog), then `CipMinCryptToSigningLevel` converts the chain to a signing level. A full file check is written back to the cache (`CipSetFileCache`).
5. Failures go through `CipCallPeauth` → `PECheckComponentLoad` (attached to the process) so that PEAuth learns of an untrusted component. Kernel images that fail are logged (3001/3002/3004/3021…/3023, 3032…/3036) with the security audit 5038 (6281 for page hashes); with a debugger attached the load is allowed after events 3003/3005/3022/3035 and a `Code Integrity violation` break if `g_CiOptions` 0x1.
6. User-mode images that don't reach the requested level: files under a `TRSData` exclusion path are only audited; otherwise events 3033/3034/3066 (`CiPolicyFailure*`) and `DbgPrintEx` `[file]: [process] 0x<required> > 0x<level>`. Unless the process is `\WINDOWS\EXPLORER.EXE`, `SEARCHPROTOCOLHOST.EXE`, `RUNDLL32.EXE` or `SVCHOST.EXE`, or the file is a `.NI.EXE` / `.NI.DLL` native image, a banner "This break indicates this binary is not signed correctly" is printed and the debugger breaks (not with `UMCINoDebugBreak`). For a packaged process with level 2…6, `KappxNotifyIntegrityFailureInPackagedProcess` records the failure ([Appx](#appx-packages)).
7. Protected-process SDL requirement not met: events 3063 / 3064 / 3065 and audit 6410, `STATUS_INVALID_IMAGE_PROTECT` (0xC000007B).

Returns 300 after a successful full file hash check, 0 otherwise on success.

`CiValidateImageData` checks the page hashes of the pages read later (events 3017 / 3018).

### Signing policy

`CipReadCustomSigningPolicy` reads Secure Boot policy values (`SeQuerySecureBootPolicyValue`, which reads the policy loaded by the boot manager, not the registry):

| Value | Type | Use |
|-------|------|-----|
| `CI\Signers` `Count` | DWORD | Number of custom signers (`g_CiSignersCount`) |
| `CI\Signers\<i>` `KnownRoot` | DWORD | Built-in root of signer *i* (0 = use `TBS`) |
| `CI\Signers\<i>` `TBS` | binary | Hash of the to-be-signed part of the signer certificate |
| `CI\Signers\<i>` `Hash` | DWORD | Hash algorithm of `TBS` (default 0x800C); its length must match `TBS` |
| `CI\Signers\<i>` `EKUs` | binary | Required EKUs: count byte then encoded OIDs (≤ 0x7F bytes each) |
| `CI\Scenarios\<n>` `ProductionSigners`, `TestSigners`, `TestsigningSigners` | DWORD array | Signer indexes allowed for scenario *n* (test signer lists only with test signing / developer mode 0x4) |
| `CI\Scenarios\<n>` `Hash` | DWORD | Minimum hash algorithm of the scenario (default 0x800C) |
| `CI\Scenarios\<n>` `Levels` | DWORD | Custom signing level comparison mask (for the scenarios that have one) |
| `EKUMappings` `Store` | string | EKU OID of the Store signer (converted to UTF-8) |

The 18 scenarios, in table order: 14, 12, 8, 6, 135, 131, 4, 11, 133, 2, 3, 5, 7, 9, 10, 15, 13, 130. A malformed signer returns 0xC0430003.

EKU OIDs found in the binary: 1.3.6.1.5.5.7.3.3 (code signing), 1.3.6.1.5.5.7.3.8 (time stamping), 1.3.6.1.4.1.311.10.3.5, .6, .19, .20, .21, .22, .23, .24, .25, 1.3.6.1.4.1.311.10.5.3, .5.4, 1.3.6.1.4.1.311.61.4.1, 1.3.6.1.4.1.311.76.3.1 (Store), 1.3.6.1.4.1.311.76.5.1. Built-in roots (certificates in `PAGECONS`): Microsoft Authenticode(tm) Root Authority, Microsoft Root Authority, Microsoft Root Certificate Authority, Microsoft Code Verification Root, Microsoft Root Certificate Authority 2010 / 2011, Microsoft Testing Root Certificate Authority 2010, Microsoft Development Root Certificate Authority 2014, Microsoft Test Root Authority, MS Protected Media Test Root, Microsoft Digital Media Authority 2005 (and "for preview releases").

`CiRegisterSigningInformation(level, data, data size, hash algorithm, EKU strings, EKU count, &handle)` adds a runtime signer for a runtime-customizable signing level (`CipIsSigningLevelRuntimeCustomizable`, `STATUS_INVALID_PARAMETER_1` otherwise): the hash size must match the algorithm, 1…3 EKUs as `UNICODE_STRING` OIDs (encoded with `MinAsn1StringToOid`), identical entries are reference counted. `CiUnregisterSigningInformation` removes it.

### File cache

`CipSetFileCache` (0x26C74) stores the result in the kernel extended attribute `$Kernel.Purge.ESBCache` of the file (`FsRtlSetKernelEaFile`; the `$Kernel.Purge.` prefix makes NTFS delete it when the file is modified). Before writing, `FSCTL_WRITE_USN_CLOSE_RECORD` (0x900EF) is sent (journaling enabled with `CipEnableJournaling` if it fails with 0xC00002B8), then `FSCTL_QUERY_USN_JOURNAL` (0x900F4). Value layout:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Size (0x1E + extra) |
| 0x04 | 2 | Version, 3 |
| 0x06 | 1 | 2 ? |
| 0x07 | 1 | Signing level |
| 0x08 | 8 | USN journal ID of the volume |
| 0x10 | 8 | `g_CiBlocklistUpdateTime` (time of the revocation list) |
| 0x18 | 4 | Flags: 0x1 = no hash, 0x2 = hashes present |
| 0x1C | 2 | Size of the extra data |
| 0x1E | … | Extra: optional WIM identity (length 0x12, type 2), then up to two hashes (length, type 1/0, DWORD algorithm, BYTE hash size, hash) |

`CipGetFileCache` / `CipVerifyFileCache` read it back (`FsRtlQueryKernelEaFile`) and only accept it when the journal ID and the revocation list time still match. `$Kernel.Purge.CatalogHint` (`CiGetCatalogHint` / `CiSetCatalogHint`) remembers which catalog held the hash of the file (events 3059…3062).

`CipEnableJournalingAndSetTrust` (0x26398) handles files whose USN is 0: it reads the UEFI variable `Kernel_USN` (vendor `{77FA9ABD-…}`), compares it with the journal ID and the revocation list (events 3050, 3057, 3058), writes it back with `ZwSetSystemEnvironmentValueEx` (event 3051) and sets `g_CiTrustUsnZero` (2 = cached level of a USN-0 file is trusted for unprotected processes ?).

### Post-boot work

`CipPostBootWorker` (0x25F6C) runs from a work item queued by the timer DPC `CipPostBootTimerRoutine`:
- request 0 (`BootCacheDelay` seconds after phase 2): `MincrypK_UpdateCatalogCache` rewrites `bootcat.cache` (event 3024 on failure);
- request 1 (`CiScheduleMemoryTrim`, 10 s later): `MinCrypK_TrimMemory` releases the catalog memory.

### Appx packages

The package roots come from `HKLM\Software\Microsoft\Windows\CurrentVersion\Appx\CodeIntegrity\Roots` (`Path` values, `KappxpQueryNormalizedPackageRepositoryDirPaths`). `KappxIsPackageFile` says whether a file is under a root; a non-packaged file under `\packages\…\ac\microsoft\…\nativeimages\` is flagged as a native image.

`KappxNotifyIntegrityFailureInPackagedProcess` (0x31CB4), on a user-mode failure in a packaged process:
- packaged file: derives the package full name from the path; if it differs from the package of the process (`RtlQueryPackageIdentity` on its token), sets bit 0x40 in the process package's status; sets bit 0x2 in `PackageStatus` (DWORD, ORed) and writes `BinaryName` (string) and `BinaryHash` (binary) under `HKLM\Software\Microsoft\Windows\CurrentVersion\AppModel\StateChange\PackageList\<package full name>`, increments `PackageVersion` of the `StateChange` key and returns 0xC0000462;
- non-packaged file: writes `BinaryName` and `BinaryHash` in the `StateChange` key and returns 0xC000047F for a native image (`\assembly\nativeimages`), 0xC000047E otherwise.

These keys are presumably watched by the AppModel state change service (not identified).

### Protected Environment (PEAuth)

`PESetPhase1Initialization` (from `CipInitialize`) initialises the obfuscated PEAuth store (`PEAuthInitStore`), builds `g_PEBootDriverList` from `ZwQuerySystemInformation(11 SystemModuleInformation)` and marks the drivers that failed in the loader list. `PESetInitialState` (phase 2) reads `Options` of `HKLM\System\CurrentControlSet\Services\PEAuth` (`g_PEAuthConfigOptions`), registers the ETW provider `{31A91186-0A64-4466-AA59-266568B4A936}` (events 3 / 4 begin / end of initialisation, 5 / 6 component load, 7 kernel untrusted, 8 user-mode component load failure), sets a process creation notify routine (`I_PEProcessNotify`) and queries `ZwQuerySystemInformation(0x95 SystemKernelDebuggerInformationEx)`: a debugger makes the state untrusted.

`CiGetPEInformation` → `PEProcessDispatch(request, inSize, outSize, …)`: request type at +0x08:

| Type | Use |
|------|-----|
| 2 | Trust state (`PEReturnState`, output ≥ 0x38); may start `PEWorkerThread` to verify the boot drivers |
| 3 | Reload the GRL (`PEReloadGRL`, `Active.GRL`) |
| 4 | Component list (`PEReturnComponentList`, input ≥ 0x24) |
| 5 | Initialisation checks (`PEPerformInitializationChecks`) |

Input < 0xC returns `STATUS_INVALID_BUFFER_SIZE` (0xC0000206); the caller is `PEAuth.sys` (not analysed). The PEAuth state, the GRL check and RSA code are in 1084 obfuscated functions named `Gv<hex>` (with `peauthvbn_*` wrappers in `PAGE`), not analysed.

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\System\CurrentControlSet\Control\CI` | `DebugFlags` | DWORD, bits 0x411 ORed into `g_CiOptions` |
| | `DebugComponent`, `DebugLevel` | DWORD, debug print filter |
| | `BootCacheDelay` | DWORD, seconds before the catalog cache is rewritten (0 = never) |
| | `UMCIAuditMode` | 1 → `g_CiOptions` 0x40 |
| | `UMCINoDebugBreak` | 1 → `g_CiOptions` 0x80 (no break on user-mode failures) |
| | `TestFlags` | DWORD, `g_CiTestFlags` |
| `HKLM\System\CurrentControlSet\Control\CI\TRSData` | `TestPath`, `TestFrameworks` | REG_MULTI_SZ, user-mode exclusion path prefixes (≤ 256 KB) |
| `HKLM\System\CurrentControlSet\Control\MiniNT` | (key) | WinPE |
| `HKLM\System\CurrentControlSet\Services\PEAuth` | `Options`, `DataPath` | PEAuth options; folder of `Active.GRL` (key name XOR-obfuscated in the binary) |
| `HKLM\Software\Microsoft\Windows\CurrentVersion\Appx\CodeIntegrity\Roots` | `Path` | Package roots |
| `HKLM\Software\Microsoft\Windows\CurrentVersion\AppModel\StateChange` | `PackageVersion`, `BinaryName`, `BinaryHash` | Written on failures, see [Appx](#appx-packages) |
| `…\AppModel\StateChange\PackageList\<package>` | `PackageStatus`, `BinaryName`, `BinaryHash` | Same |

UEFI variables (vendor `{77FA9ABD-0359-4D32-BD60-28F4E78F784B}`): `Kernel_FlightSignedNotBefore` (read), `Kernel_USN` (read / written).

### Devices and IOCTLs

FSCTLs sent to the file system (`FsRtlKernelFsControlFile` / `ZwFsControlFile`):

| Code | Name | Use |
|------|------|-----|
| 0x900E7 | `FSCTL_CREATE_USN_JOURNAL` | `CipEnableJournalingAlways` |
| 0x900EB | `FSCTL_READ_FILE_USN_DATA` | USN of a WIM file (`CipLoadWimIdentities`) |
| 0x900EF | `FSCTL_WRITE_USN_CLOSE_RECORD` | Before writing the cache EA |
| 0x900F4 | `FSCTL_QUERY_USN_JOURNAL` | Journal ID for the cache EA |
| 0x9031F | (device 9, function 199, `METHOD_NEITHER`) | Enumerates the WIM files backing a volume (`FSCTL_WIM_ENUMERATE_DATA_SOURCES` ?) |

### Security audit

`CiAudit` calls `SeReportSecurityEventWithSubCategory` with the event IDs 5038 (image hash invalid), 6281 (page hash invalid) and 6410 (SDL requirement not met), with the file name.

### ETW

Provider `{4EE76BD8-3CF4-44A0-A0AC-3937643E37A3}` (Microsoft-Windows-CodeIntegrity), registered in phase 2; every write is guarded by `EtwEventEnabled`. Channel 16 events have keyword 0x8000000000000000, channel 17 events 0x4000000000000000.

| Event | Level | Opcode, task | Channel | Written when |
|-------|-------|--------------|---------|--------------|
| 3001 | 3 | 101, 1 | 16 | Unsigned driver loaded (debugger) |
| 3002 / 3004 | 2 | 102 / 104, 1 | 16 | Page / file hash of an image not found |
| 3003 / 3005 | 3 | 103 / 105, 1 | 16 | Same, debugger attached (load allowed) |
| 3006 / 3007 / 3008 / 3009 | 4 | 0, 6…9 | 17 | Hash found in a catalog / the image certificate |
| 3010 / 3026 | 3 | 100, 2 | 16 | Invalid / revoked catalog |
| 3011 / 3012 | 4 | 2 / 1, 2 | 17 | Catalog load complete / start |
| 3013 / 3014 | 4 | 1 / 2, 3 | 17 | Catalog reload start / complete |
| 3015…3018 | 5 | 1 / 2, 4 / 5 | 17 | File / page hash validation start / complete |
| 3019 / 3020 / 3027 | 5 | 1 / 2 / 0, 10 | 17 | Catalog cache load |
| 3028 / 3029 / 3030 | 5 | 1 / 2 / 0, 11 | 17 | Catalog cache save |
| 3021 / 3022 / 3023 | 3 / 3 / 2 | 106…108, 1 | 16 | Revoked driver loaded / in debugger / not loaded |
| 3024 | 3 | 109, 11 | 16 | Catalog cache update failed |
| 3025 | 5 | 101, 1 | 17 | Driver without embedded signature loaded |
| 3032 / 3035 / 3036 | 3 / 3 / 2 | 113…115, 1 | 16 | Revoked image loaded / in debugger / not loaded |
| 3033 / 3034 / 3066 | 2 / 3 / 4 | 111, 1 | 16 | User-mode policy failure / ignored / audit |
| 3037 | 3 | 112, 1 | 16 | Unsigned image loaded |
| 3038 / 3039 | 5 | 1 / 2, 13 | 17 | `CiValidateImageHeader` start / complete |
| 3040…3043 | 5 | 1 / 2, 14 / 15 | 17 | Get / set file cache start / complete |
| 3050 / 3051 / 3052 / 3057 / 3058 | 0 | 0, 14 | 16 | `Kernel_USN` read / written, journaling failed, journal ID / revocation list mismatch |
| 3054 / 3055 | 5 | 1 / 2, 15 | 17 | `CipEnableJournalingAndSetTrust` start / complete |
| 3059…3062 | 4 | 0, 16 / 17 | 17 | Catalog hint set / used |
| 3063 / 3064 / 3065 | 2 / 3 / 4 | 116 / 0 / 116, 1 | 16 / 17 / 16 | SDL requirement not met / ignored / audit |
