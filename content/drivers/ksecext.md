## Ksecext.sys

Kernel security extension of Windows Phone 8.1: phone-specific signing policy and AppContainer privileges for [NTOSKRNL.EXE](../libraries/ntoskrnl.md) and [ci.dll](../libraries/ci.md) (67 functions, PDB name `ksecext.pdb`).  
It's a kernel **export driver** (a kernel DLL): `DllInitialize` and `DllUnload` are the same function and just return 0, `DriverEntry` does nothing either. All the work happens in its exports. It hosts the API set extensions `ext-ms-win-ntos-ksecurity-l1-1-1` (imported by the kernel) and `ext-ms-win-ntos-ksigningpolicy-l1-1-0` (imported by the kernel and by `ci.dll`). What it does:
- picks the signing level that a new process (and the DLLs it loads ?) must have, from the Security Manager metastore (`HKLM\Software\Microsoft\SecurityManager\…`): system processes, Store / enterprise / OEM applications, developer unlocked applications ([SeQuerySigningPolicyExt](#sequerysigningpolicyext-0x10004840));
- gives signing level 6 (Store) to the binaries of the applications installed on the SD card, where `ci.dll` can't store its signing level cache EA ([SeCodeIntegrityCacheExt](#secodeintegritycacheext-0x10004c38));
- allows the Qualcomm user-mode display drivers ([CiQueryLoadLegacyDisplayDriversExt](#ciqueryloadlegacydisplaydriversext-0x10004188));
- asks the Security Manager driver ([SecMgr.sys](./secmgr.md), `\Device\SecMgr`) which privileges an AppContainer gets ([AppContainerPrivilegesEnabledExt](#appcontainerprivilegesenabledext-0x100052cc)).

It imports only `ntoskrnl.exe`.

There's no device object, no symbolic link, no IOCTL received and no ETW provider.  

Pool tags: `Ksec` (0x6365734B, most buffers), `Secr` (0x72636553, metastore buffers, `sub_100070CC` / `sub_100070EC`), `CIsc` (0x63734943, `CiQueryLoadLegacyDisplayDriversExt`).

Registry key `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\CI`, read once by `sub_100056EC` (`ZwOpenKey(KEY_QUERY_VALUE)` + `ZwQueryValueKey(KeyValuePartialInformation)`, only REG_DWORD values are taken):  
| Registry value | value | comment |
|----------------|-------|---------|
| DebugFlags | 0 | Bit 0x1 → `CI_OPTIONS` 0x1, bit 0x10 → `CI_OPTIONS` 0x10. The other bits are ignored |
| DebugComponent | 0xFFFFFFFF | Copied to `CI_DEBUGCOMPONENTS` (`dword_1000800C`) |
| DebugLevel | 0 | Copied to `CI_DEBUGLEVEL` (`dword_10008020`) |
| BootCacheDelay | 10 | Copied to `CI_BOOTCACHEDELAY` (`dword_10008008`) |
| RestrictKernelSigners | 0 | 1 → `CI_OPTIONS` 0x20 |
| UMCIAuditMode | 0 | 1 → `CI_OPTIONS` 0x40: every signing level returned by `SeQuerySigningPolicyExt` becomes 8 (Microsoft) and its errors are ignored |
| DeveloperMode | 0 | 1 → `CI_DEVELOPERMODE` = 1. When missing and Secure Boot is off (`SystemSecureBootInformation`, class 0x91, `SecureBootEnabled` = 0) → `CI_DEVELOPERMODE` = 2 |
| UMCINoDebugBreak | 0 | 1 → `CI_OPTIONS` 0x80 |

The same values are also read by [ci.dll](../libraries/ci.md#registry).

The resulting settings are then **written** into the same key (`sub_10005994`, `ZwCreateKey` + `ZwSetValueKey`, all REG_DWORD):  
| Registry value | value | comment |
|----------------|-------|---------|
| CI_OPTIONS | 0 | `dword_1000801C`: bits 0x1, 0x10, 0x20, 0x40, 0x80 above |
| CI_DEBUGCOMPONENTS | 0xFFFFFFFF | `dword_1000800C` |
| CI_DEBUGLEVEL | 0 | `dword_10008020` |
| CI_BOOTCACHEDELAY | 10 | `dword_10008008` |
| CI_DEVELOPERMODE | 0 | `dword_10008018`: 0, 1 (`DeveloperMode`) or 2 (Secure Boot off) |
| CI_ALLOWUNSIGNED | 0 | `byte_10008024`: 1 if `UMCIAuditMode` and (`CI_DEVELOPERMODE` ≠ 0 or a kernel debugger is attached) |

Registry key `HKEY_LOCAL_MACHINE\Software\Microsoft\SecurityManager\DeveloperUnlock` (`sub_1000710C`, opened with `ZwCreateKey`):  
| Registry value | value | comment |
|----------------|-------|---------|
| DeveloperUnlockState | 0 | REG_DWORD. 1 → AppContainer applications that have the capability `ID_CAP_DEVELOPERUNLOCK` or `ID_CAP_DEVELOPERUNLOCK_CODEDUI` aren't signature checked. Written by `SecRuntime!SetDeveloperUnlockState` ([SecRuntime.dll](../libraries/secruntime.md)). Missing = 0 |

Other keys read under `HKLM\Software\Microsoft\SecurityManager\` (same metastore as [SecRuntime.dll](../libraries/secruntime.md#security-metastore); generic lookup code `sub_10006F70`, which only reads what the caller asks for):  
| Key | Values | Use |
|-----|--------|-----|
| `Applications`, `ServiceGroups`, `Services`, `FullTrust` | value name = string SID, data = chamber name | Reverse lookup of a SID (`sub_10006224`), tried in this order |
| `Applications\<chamber>` | `ApplicationType` | 0 → type 1, 4 → type 3, other → type 2 (see [SeQuerySigningPolicyExt](#sequerysigningpolicyext-0x10004840)) |
| | `OEMExtensible` | DWORD |
| | `ApplicationAccount` → `ApplicationAccounts\<account>\UserAccountSid` | Account of the application |
| | `SignerCertificate\EnterpriseId` | DWORD, 4 bytes. Present = enterprise application |
| | `ApplicationSid`, `ApplicationBinaries`, `RequiredPrivileges`, `RequiredCapabilitySIDs`, `SignerCertificate\Thumbprint`, `ThumbprintCNGHashAlgId`, `SHA1Thumbprint` | Read by the generic code, not used by the exports |
| `Services\<service>` | `ServiceGroup`, `ServiceAccount`, `OEMExtensible` | OEM extensible service (`sub_100066C0`, `sub_10006B40`) |
| `ServiceGroups\<group>` | `ServiceAccount` | |
| `ServiceAccounts\<account>` | `UserAccountSid` | Account SID of a service account; `ServiceAccounts\DefApps` is the account of the default applications (`sub_1000426C`) |
| `Capabilities\<capability>` | `ApplicationCapabilitySID` | SID of `ID_CAP_DEVELOPERUNLOCK` / `ID_CAP_DEVELOPERUNLOCK_CODEDUI`, compared with the capabilities of the token (`sub_10004754`) |
| `StorageCardProfiles\Chambers` | value `<chamber>` | Present = the application is installed on the SD card ([SeCodeIntegrityCacheExt](#secodeintegritycacheext-0x10004c38)) |

UEFI variable read by `GetDeviceSecurityPolicyState`:  
| Variable | GUID | Use |
|----------|------|-----|
| `SecureBoot` | `{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}` (`EFI_GLOBAL_VARIABLE`) | 1 byte, ≠ 0 = Secure Boot enabled |

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SecMgr | [SecMgr.sys](./secmgr.md) | [IOCTL 0x226054](#ioctl-0x226054) from `AppContainerPrivilegesEnabledExt` |

### Exports

| Ordinal | Name | Address | API set | Comment |
|---------|------|---------|---------|---------|
| 0 | `AppContainerPrivilegesEnabledExt` | 0x100052CC | ext-ms-win-ntos-ksecurity-l1-1-1 | [below](#appcontainerprivilegesenabledext-0x100052cc) |
| 1 | `CiQueryLoadLegacyDisplayDriversExt` | 0x10004188 | ext-ms-win-ntos-ksigningpolicy-l1-1-0 | [below](#ciqueryloadlegacydisplaydriversext-0x10004188) |
| 2 | `DllInitialize` | 0x10004260 | — | Returns 0 |
| 3 | `DllUnload` | 0x10004260 | — | Same function as `DllInitialize` |
| 4 | `GetDeviceSecurityPolicyState` | 0x10004000 | ? | [below](#getdevicesecuritypolicystate-0x10004000) |
| 5 | `KAddTrustedExecutable` | 0x10005108 | ? | [below](#kaddtrustedexecutable-0x10005108) |
| 6 | `QueryUpdateFileEaAllowedExt` | 0x100026B8 | ext-ms-win-ntos-ksecurity-l1-1-1 | `ULONG *allowed`: always sets 1 and returns 0 (`STATUS_INVALID_PARAMETER` if NULL). **Stub** |
| 7 | `SeCodeIntegrityCacheExt` | 0x10004C38 | ext-ms-win-ntos-ksigningpolicy-l1-1-0 | [below](#secodeintegritycacheext-0x10004c38) |
| 8 | `SeQuerySigningPolicyExt` | 0x10004840 | ext-ms-win-ntos-ksigningpolicy-l1-1-0 | [below](#sequerysigningpolicyext-0x10004840) |
| 9 | `start` (`FxDriverEntry`) | 0x100026EC | — | Entry point: `__security_init_cookie`, then `DllInitialize` |

Callers of `GetDeviceSecurityPolicyState` and `KAddTrustedExecutable` aren't known (no documented binary imports them).

Signing levels used below (`SE_SIGNING_LEVEL`): 0 = unchecked, 2 = enterprise, 3 = custom 1 (developer ?), 6 = Store, 8 = Microsoft, 12 = Windows.

### Initialisation

Done once, at the first `SeQuerySigningPolicyExt` call (`sub_10005580`; the pointer `off_10008028` is set with `LDREX`/`STREX` when it's done):
1. `ZwQuerySystemInformation(SystemSecureBootPolicyInformation = 0x8F)`. If it returns `STATUS_SECUREBOOT_NOT_ENABLED` (0x80430006): `DbgPrintEx(0x4D, 0, "**** SECURE BOOT IS NOT ENABLED ***\r\n")` and the two configurable levels `byte_10008010` (3) and `byte_10008011` (2) become 0 (unchecked). Any other error stops the initialisation.
2. Builds the `UNICODE_STRING` `\??\<NtSystemRoot>\System32\` (`NtSystemRoot` from `KUSER_SHARED_DATA` at 0xFFFF9030, e.g. `\??\C:\Windows\System32\`).
3. Reads `Control\CI` (`sub_100056EC`, [table above](#ksecextsys)), computes `CI_ALLOWUNSIGNED`, writes the `CI_*` values (`sub_10005994`; a write failure is ignored).

### SeQuerySigningPolicyExt (0x10004840)

`NTSTATUS SeQuerySigningPolicyExt(PACCESS_TOKEN token, PUNICODE_STRING imageName, ULONG flags, BOOLEAN b, SE_SIGNING_LEVEL *level, SE_SIGNING_LEVEL *sectionLevel ?, BOOLEAN *out)`  
Called by the kernel for a new process. `level` is probably the level of the process image and `sectionLevel` the level required for the images it maps (`EPROCESS.SignatureLevel` / `SectionSignatureLevel` ?). `*out` is always set to 0.  
`STATUS_INVALID_PARAMETER` if `token`, `level`, `sectionLevel` or `out` is NULL; `STATUS_NOT_IMPLEMENTED` (0xC0000002) if `b` ≠ 0 or `flags` bit 0 is set.

1. Default: `level` = `sectionLevel` = 12 (Windows). [Initialisation](#initialisation) if not done yet.
2. **System processes** (`sub_1000546C`). `imageName` must start with `\??\C:\Windows\System32\` (when its second character is `?`) or with `\SystemRoot\System32\`, and the rest must be one of these names (case-insensitive, no subfolder), table `dword_10001120`:

   | Image | level | sectionLevel |
   |-------|-------|--------------|
   | smss.exe | 12 | 12 |
   | sppsvc.exe | 12 | 12 |
   | csrss.exe | 12 | 12 |
   | wininit.exe | 12 | 12 |
   | services.exe | 12 | 12 |
   | BootPrep.exe | 12 | 12 |
   | lsass.exe | 12 | 12 |
   | mobileui.exe | 12 | 12 |

   With a kernel debugger attached (`KdDebuggerEnabled` and not `KdDebuggerNotPresent`), levels above 8 become 8 (Microsoft). On a match the function ends here (step 6). `NtQuerySystemInformation(0x91)` is called but its result isn't used.
3. Otherwise (and `imageName` not NULL), `sub_100044C0` classifies the token:
   - **AppContainer** (`TokenIsAppContainer`): the chamber of `TokenAppContainerSid` is looked up in the metastore (`sub_100068B8` → `sub_10006F70(2, sid, 0x142)`): application type, `OEMExtensible`, `SignerCertificate\EnterpriseId`.
   - **Other tokens**: `TokenUser`. `S-1-5-18` (LocalSystem) or the `DefApps` account SID (`ServiceAccounts\DefApps\UserAccountSid`) → no restriction: levels stay 12 / 12. Otherwise the service account is searched (`S-1-5-19` and `S-1-5-20` are skipped): enumeration of `ServiceAccounts\*` until `UserAccountSid` matches, then of `Services\*` for a service (or its service group) that runs as that account and has `OEMExtensible` ≠ 0.
4. Non-AppContainer token of a known service account: `sub_10004380`. If the image file name is `SvcHost.exe` and the service is OEM extensible: `level` = 12, `sectionLevel` = `byte_10008010` (3, or 0 without Secure Boot): OEM DLLs can be loaded in that svchost. Otherwise 12 / 12. Unknown account → 12 / 12.
5. AppContainer token:
   - If `DeveloperUnlockState` = 1: capability `ID_CAP_DEVELOPERUNLOCK_CODEDUI` → `level` = 12, `sectionLevel` = 0; capability `ID_CAP_DEVELOPERUNLOCK` → 0 / 0 (no check at all). The capabilities are compared through `TokenAccessInformation` → `CapabilitiesHash`.
   - Chamber not found in the metastore → 12 / 12.
   - Application type 1 (`ApplicationType` = 0): `level` = 12, `sectionLevel` = `byte_10008010` (3) if `OEMExtensible`, else 6.
   - Enterprise application (`EnterpriseId` present): 2 / 2 (`byte_10008011`, 0 without Secure Boot).
   - Other applications: 6 / 6 (Store).
6. If `CI_OPTIONS` bit 0x40 (`UMCIAuditMode`): both levels = 8 and a failure is turned into `STATUS_SUCCESS`.

### SeCodeIntegrityCacheExt (0x10004C38)

`NTSTATUS SeCodeIntegrityCacheExt(PEPROCESS process, PFILE_OBJECT file, SE_SIGNING_LEVEL *level)`  
Called by [ci.dll](../libraries/ci.md#civalidateimageheader-0x273fc) instead of reading its signing level cache EA when `g_CiOptions` 0x1000 is set. It gives level 6 (Store) to a binary of an application installed on the SD card, if the file is in that application's folder. `*level` is first set to 1.

1. Full name of the file (`sub_10004A20`): `ObQueryNameString(file->DeviceObject)` + `ZwQueryInformationFile(FileNameInformation)` (e.g. `\Device\<volume>\WPSystem\Apps\…`), or `file->FileName` if that fails.
2. Primary token of the process: must be an AppContainer (`STATUS_INVALID_IMAGE_HASH` 0xC0000428 otherwise). `RtlQueryPackageIdentity` → package full name. It's a real Appx package unless the name ends with `_neutral__0000000000000` (more than 24 characters needed, `STATUS_UNSUCCESSFUL` otherwise).
3. `TokenAppContainerSid` → chamber (`sub_10006F70(2, sid, 5)`), then the value `<chamber>` must exist in `StorageCardProfiles\Chambers` (`STATUS_INVALID_IMAGE_HASH` otherwise).
4. Prefixes tested (case-insensitive) against the file name. `<device>` is the device name from step 1:

   | Application | Prefix |
   |-------------|--------|
   | All | `<device>\WPSystem\Apps\<chamber>\NI\` |
   | Appx | `<device>\WPSystem\AppRepository\<package full name>\NI\` (instead of the line above) |
   | Not Appx | `<device>\WPSystem\Apps\<chamber>\Install\` |
   | Appx | `<device>\WPSystem\Apps\WindowsApps\<package full name>\` |

   A match → `*level` = 6 and `STATUS_SUCCESS`. No match → `STATUS_INVALID_IMAGE_HASH`.

`\WPSystem\…` is the layout of the SD card used by [filecrypt.sys](./filecrypt.md) (`NI` = native images precompiled by the phone ?).

### CiQueryLoadLegacyDisplayDriversExt (0x10004188)

`NTSTATUS CiQueryLoadLegacyDisplayDriversExt(PFILE_OBJECT file)`  
Returns `STATUS_SUCCESS` if the file is on the system boot partition (`DeviceObject->Flags` & `DO_SYSTEM_BOOT_PARTITION` 0x100) and its `FileName` is `<NtSystemRoot without the drive>\System32\<name>` (e.g. `\Windows\System32\qcdx9um8930.dll`, case-insensitive) with one of these names (`off_1000B150`); `STATUS_UNSUCCESSFUL` otherwise:  
| MSM8960 | MSM8930 | MSM8974 |
|---------|---------|---------|
| qca2xxcompiler8960.dll | [qca3xxcompiler8930.dll](../libraries/qca3xxcompiler8930.md) | qca3xxcompiler8974.dll |
| qcdx9um8960.dll | [qcdx9um8930.dll](../libraries/qcdx9um8930.md) | qcdx9um8974.dll |
| qcvidum8960.dll | [qcvidum8930.dll](../libraries/qcvidum8930.md) | qcvidum8974.dll |

These are the Qualcomm user-mode display / video drivers.

### AppContainerPrivilegesEnabledExt (0x100052CC)

`NTSTATUS AppContainerPrivilegesEnabledExt(PSID appContainerSid, ?, ULONGLONG defaultPrivileges, ULONGLONG *present, ULONGLONG *enabled)`  
(`defaultPrivileges` is passed in r2/r3; `present` / `enabled` are guesses from the name, both receive the same value.)

1. `*present` = `*enabled` = `defaultPrivileges`.
2. If the SID is a user-mode address and the previous mode is user, it's probed and captured (`sub_100051C4`: `RtlLengthRequiredSid`, `RtlValidSid`).
3. `RtlConvertSidToUnicodeString` → `S-1-15-2-…`.
4. [IOCTL 0x226054](#ioctl-0x226054) to `\Device\SecMgr` with that string. If it returns a non-zero 64-bit value, `*present` = `*enabled` = that value.

Any error leaves the default value and returns `STATUS_SUCCESS`.

### GetDeviceSecurityPolicyState (0x10004000)

`NTSTATUS GetDeviceSecurityPolicyState(ULONG *state)`, `STATUS_INVALID_PARAMETER` if NULL. Secure Boot state of the device:  
| state | Condition |
|-------|-----------|
| 0 | `ZwQuerySystemInformation(0x8F)` → `STATUS_INVALID_INFO_CLASS` (status `STATUS_SUCCESS`) |
| 1 | Secure Boot not enabled: `STATUS_SECUREBOOT_NOT_ENABLED`, or UEFI variable `SecureBoot` = 0, or `ZwQuerySystemEnvironmentValueEx` → `STATUS_NOT_IMPLEMENTED` |
| 2 | Policy publisher `{0CDAD82E-D839-4754-89A1-844AB282312B}` |
| 3 | Policy publisher `{8053E904-59C9-482C-9930-2B8733A7E40F}` and Secure Boot policy value `Debug` / `DeviceID` (`SeQuerySecureBootPolicyValue`, 8 bytes) ≠ 0 (debug policy bound to a device ?) |
| 4 | Policy publisher `{D7B18629-B99B-4AEA-A10C-9E551EB9C3D5}` |
| 5 | Other publisher, or publisher `{8053E904-…}` without `DeviceID` (initial value) |

The publisher is the first field (GUID) of `SYSTEM_SECUREBOOT_POLICY_INFORMATION` (24 bytes). The names of the 3 policies aren't known (production / debug / ... ?). Other errors are returned as is.

### KAddTrustedExecutable (0x10005108)

`NTSTATUS KAddTrustedExecutable(PCWSTR path)`  
Called by [SecMgr.sys](./secmgr.md#ioctl-0x22e008) for IOCTL 0x22E008. Opens the file (`ZwCreateFile(0x10000000 GENERIC_ALL, FILE_ATTRIBUTE_NORMAL, FILE_SHARE_READ, FILE_OPEN, FILE_NON_DIRECTORY_FILE | FILE_SYNCHRONOUS_IO_NONALERT)`) and calls `ZwSetCachedSigningLevel(flags 2, level 6, &handle, 1, handle)`: the file's signing level cache says level 6 (Store) **without checking its signature**. `STATUS_INVALID_PARAMETER` if `path` is NULL.

---

### IOCTL 0x226054

This IOCTL is sent by Ksecext.sys to [SecMgr.sys](./secmgr.md#ioctl-0x226054) (`\Device\SecMgr`, `sub_10002564`). It's the same IOCTL as `QueryKernelPrivilegeCache` of [SecRuntime.dll](../libraries/secruntime.md#kernel-privilege-cache).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x815 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Query kernel privilege cache | \Device\SecMgr | length of the string + 2 | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | `S-1-15-2-…` | String SID of the AppContainer, UTF-16 with its NUL |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | Privileges of the AppContainer: 64-bit mask, bit n = privilege LUID n (`RequiredPrivileges` of the chamber in the [cache of SecMgr.sys](./secmgr.md#privilege-cache)). 0 = not in the cache, use the default |

The device is opened with `ZwCreateFile(SYNCHRONIZE, FILE_OPEN, FILE_SYNCHRONOUS_IO_NONALERT)` and the request built with `IoBuildDeviceIoControlRequest` (not internal) on `IoGetRelatedDeviceObject` of the file object.
