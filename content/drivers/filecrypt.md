## Filecrypt.sys

Windows Phone 8.1 **SD card file-system minifilter**: access control by "chamber" and transparent encryption of the files on the SD card (148 functions, PDB name `filecrypt.pdb`).  
It's a Filter Manager minifilter (imports only `FLTMGR.SYS`, `ksecdd.sys` (CNG), `tbs.sys` (TPM Base Services), `ntoskrnl.exe` and `HAL.dll`). It attaches only to FAT / exFAT volumes on removable media (or to an internal volume labelled `SDCARD`). On those volumes it:
- gives every file under `\WPSystem\…` (apps installed on the SD card, their data) a security descriptor built from the Security Manager registry metastore (chamber SIDs, capability SIDs) and checks it with `SeAccessCheck` on each create, since FAT has no ACLs. The other files get the security descriptor of the transient object `SdMountPoint` ;
- encrypts / decrypts the content of the files of the encrypted chambers (installed apps, app data, and the `Music` / `Pictures` / `Videos` folders when `EncryptMedia` is set) on the fly in the non-cached read / write paths, with AES-128-CBC, one key per chamber derived from a 128-byte master key sealed by the TPM.

There's no device object, no symbolic link, no communication port (`FltCreateCommunicationPort` isn't imported) and no IOCTL.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\filecrypt` ?  

Registry values read by `DriverEntry` (`sub_10005198`) directly in the service key (`RegistryPath`, not `Parameters`), REG_DWORD:  
| Registry value | value | comment |
|----------------|-------|---------|
| DebugTraceLevel | 0 | Stored in `dword_1000B088`, not used elsewhere ? (read only once) |
| EncryptMedia | 0 | ≠ 0 → flag 0x02: encrypt the files under `\Music\`, `\Pictures\`, `\Videos\` (chambers `MusicChamber`, `PicturesChamber`, `VideosChamber`) |
| EncryptAll | 0 | ≠ 0 → flag 0x04: encrypt every file outside `\WPSystem\` with the chamber `{0b7992da-c5e6-41e3-b24f-55419b997a15}` (takes precedence over `EncryptMedia`) |
| FilterEmulatedExternalDrive | 1 | ≠ 0 → flag 0x08 (**set by default**): also attach to a non-removable volume whose label is `SDCARD`, and mark its device stack as removable |
| BypassAccessChecks | 0 | ≠ 0 → flag 0x10: no `SeAccessCheck` in the create path, and `FILE_DEVICE_SECURE_OPEN` is cleared on the disk device |

The flags are in `dword_1000B010` (default value 0x8). A missing value leaves the default.

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\StSec` (`RtlQueryRegistryValuesEx` / `RtlQueryRegistryValues` with `RTL_REGISTRY_SERVICES`, `sub_1000901C`), cache of the chamber keys:  
| Registry value | value | comment |
|----------------|-------|---------|
| CacheLifetime | 3600 | REG_DWORD, seconds (`dword_1000B02C`). Keys not used for that long are removed by the cleanup work item |
| CacheCleanupTriggerSize | 50 | REG_DWORD (`dword_1000B028`). Above this number of cached chambers, the cleanup work item (`sub_100095F0`) is queued |
| CacheMaxSize | 200 | REG_DWORD (`dword_1000B024`). Above this number, the first element of the table is removed at each insertion |

Registry key `HKEY_LOCAL_MACHINE\Software\Microsoft\StorageSec\Encrypt` (read and **written** by the driver, `sub_10008ED0`):  
| Registry value | value | comment |
|----------------|-------|---------|
| MK | REG_BINARY | Master key sealed by the TPM: TPM 2.0 `TPM2B_PRIVATE` + `TPM2B_PUBLIC` returned by `TPM2_Create` (see [Master key](#master-key-and-tpm)). Created at the first need of a key if missing |

Other registry keys read (`HKLM\Software\Microsoft\SecurityManager\…`, same metastore as [SecRuntime.dll](../libraries/secruntime.md#security-metastore)):  
| Key | Values | Use |
|-----|--------|-----|
| `Applications\<chamber>` | `ApplicationSid` | SID of the app that owns a `\WPSystem\` folder (ACE in the folder's DACL) |
| `ApplicationAccounts\DefApps` | `UserAccountSid` | Account of the default apps (DACL of the app data folders) |
| `Capabilities\<capability>` | `ApplicationCapabilitySID`, `ServiceCapabilitySID` | SIDs of the `ID_CAP_*` capabilities that are granted access ([list](#chamber-profiles)) |
| `StorageCardProfiles\Chambers` | value `<chamber>` (DWORD) | ≠ 0 → debug chamber: `_DEBUG` is appended to the chamber name before deriving its key, and `ID_CAP_DEBUG_FOLDERS` gets full access |
| `StorageCardProfiles\Override` | value = path prefix (case-insensitive), data REG_SZ = transient object name | Security descriptor of the files outside `\WPSystem\` whose path starts with the value name: `TransientObjects\%5C%5C.%5CPrivate%5C<NAME>` (`sub_10008B2C`) |
| `TransientObjects\%5C%5C.%5CPrivate%5CSDMOUNTPOINT` | `SecurityDescriptor` | Default security descriptor of the files outside `\WPSystem\` (`SdMountPoint`, cached in `dword_1000B094`) |

The transient object key name is built like `QueryTransientObjectSecurityDescriptor(12, name)` of [SecRuntime.dll](../libraries/secruntime.md#querytransientobjectsecuritydescriptor-0x10003c20) (`sub_10009FC0`: upper case, `\` → `%5C`).

GUID of the ETW provider:  
`{DADEFA21-806E-4241-8D0E-E23293C74E06}` (manifest-based, `McGenEventRegister`; keyword bit 0 = errors, bit 1 = access denials / failed opens, `dword_1000B188`)

Chamber of the whole SD card when `EncryptAll` is set:  
`{0b7992da-c5e6-41e3-b24f-55419b997a15}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Filter Manager | fltmgr.sys | `FltRegisterFilter`, contexts, file names, generic work items |
| TPM Base Services | tbs.sys | `Tbsi_Context_Create` (version 2, flags 4 = TPM 2.0), `Tbsip_Submit_Command`: `TPM2_Create`, `TPM2_Load`, `TPM2_Unseal` |
| CNG kernel provider | ksecdd.sys | AES (CBC), SHA256 (HMAC), RNG |
| Disk device of the volume | (SD card / storage stack) | `FltGetDiskDeviceObject`, `RtlVolumeDeviceToDosName`; device characteristics changed (see [Instance setup](#instance-setup)) |

### Filter registration

`FLT_REGISTRATION` at `.rdata:0x100012BC` (size 0x3C, version 0x0203, flags 0):  
| Callback | Address | Comment |
|----------|---------|---------|
| FilterUnload | `sub_100062C8` | Frees the key cache and the master key, unregisters |
| InstanceSetup | `sub_10006000` | [Instance setup](#instance-setup) |
| InstanceQueryTeardown | `sub_100062BC` | Returns `STATUS_SUCCESS` (manual detach allowed) |

Operations (`.rdata:0x10001258`):  
| Major function | Flags | Pre-operation | Post-operation |
|----------------|-------|---------------|----------------|
| IRP_MJ_CREATE | 0 | `sub_1000632C` (path → security descriptor + chamber, access check) | `sub_1000658C` (stream context with the chamber key) |
| IRP_MJ_READ | `FLTFL_OPERATION_REGISTRATION_SKIP_CACHED_IO` | `sub_10002FC8` | `sub_1000315C` (decrypt) |
| IRP_MJ_WRITE | `FLTFL_OPERATION_REGISTRATION_SKIP_CACHED_IO` | `sub_100034B0` (encrypt into a shadow buffer) | `sub_100037FC` (frees it) |
| IRP_MJ_SET_INFORMATION | 0 | `sub_100068C0` (rename check only) | — |

Contexts:  
| Type | Size | Pool tag | Cleanup | Content |
|------|------|----------|---------|---------|
| Volume | 0x24 | `FCvx` | `sub_10006260` | +00 `UNICODE_STRING` DOS name of the volume (e.g. `D:`); +08 sector size (≥ 512); +0C AES algorithm handle; +10 key object length; +14 AES block length (16); +18 encryption unit = sector size; +1C key length = 16; +20 algorithm opened |
| Stream | 0x14 | `FCsx` | `sub_1000629C` | +00 `BCRYPT_KEY_HANDLE`; +04 key object; +08 key object length; +0C chamber name; +10 key type (1 = `Install`, 2 = `Data`) |

### Instance setup

`sub_10006000`:
1. Only `FILE_DEVICE_DISK_FILE_SYSTEM` volumes of type `FLT_FSTYPE_FAT` (3) or `FLT_FSTYPE_EXFAT` (0x16), else `STATUS_FLT_DO_NOT_ATTACH`.
2. The volume must be removable (`FltGetVolumeProperties`, `FILE_REMOVABLE_MEDIA`), or, with `FilterEmulatedExternalDrive`, have the volume label `SDCARD` (`FileFsVolumeInformation`, label length 12).
3. Allocates the volume context: sector size, DOS name (`RtlVolumeDeviceToDosName`, else the real or the Filter Manager device name + `:`), opens `AES` and sets `ChainingModeCBC` (`sub_10006C30`).
4. Sets the flag 0x20000 in a field at +0x1C of the structure at +0x08 of the disk device's +0x24 (?).
5. Emulated `SDCARD` drive: ORs `FILE_REMOVABLE_MEDIA` into the characteristics of every device of the disk stack (`IoGetAttachedDeviceReference` / `IoGetLowerDeviceObject`).
6. `BypassAccessChecks`: clears `FILE_DEVICE_SECURE_OPEN` on the disk device.

### Create path

Pre-create (`sub_1000632C`):
1. `FltGetFileNameInformation(FLT_FILE_NAME_NORMALIZED | FLT_FILE_NAME_QUERY_DEFAULT)` and `FltParseFileNameInformation`; the path relative to the volume (`ParentDir` + `FinalComponent`, ending with `\`) is built by `sub_10006B90`. A volume open (no final component) isn't filtered.
2. `sub_10006748` → `sub_10006FBC`: [security descriptor and chamber of the path](#chamber-profiles).
3. `sub_10006AE8`: `SeAccessCheck` of the requested access (+ `DELETE` (0x10000) for `FILE_DELETE_ON_CLOSE`, + `FILE_WRITE_DATA` for the dispositions `FILE_OVERWRITE` / `FILE_OVERWRITE_IF`) against the descriptor, unless `BypassAccessChecks`. A failure completes the create (`FLT_PREOP_COMPLETE`) with the status, usually `STATUS_ACCESS_DENIED` (0xC0000022).
4. If the path is in an encrypted chamber, the chamber name and the key type go to the post-create.

Post-create (`sub_1000658C`): for a file (not a directory) that has no stream context yet, derives the chamber key (`sub_10006CD4`: [key derivation](#master-key-and-tpm), `BCryptGenerateSymmetricKey`) and attaches a stream context. If that fails, `FltCancelFileOpen` and the open fails with the error status.

Pre-set-information (`sub_100068C0`): only `FileRenameInformation` (class 10). It computes the chamber of the source and of the destination (`FltGetDestinationFileNameInformation`) and, when they differ, only logs an ETW event: **the rename isn't blocked**, so a file moved to another chamber keeps the encryption of its original chamber.

### Encryption

Only non-cached I/O (paging I/O, non-cached handles) is processed; the cached data in memory is plaintext.
- Unit = sector size of the volume (≥ 512 bytes), one AES-128-CBC operation per unit, no padding.
- IV = the 64-bit byte offset of the unit in the file, written twice (16 bytes, little-endian) (`sub_100038BC` / `sub_10003980`).
- Write (`sub_100034B0`): encrypts into a shadow buffer (lookaside list of 64 KB `FCsb` buffers, or pool for bigger writes), swaps the MDL / buffer of the request (`FltSetCallbackDataDirty`), restores and frees it in the post-write.
- Read: the pre-read (`sub_10002FC8`) calls `FltSetFsZeroingOffsetRequired`; the post-read (`sub_1000315C`, or `sub_100032E0` in a work item at DISPATCH_LEVEL) decrypts in place, and the bytes beyond the file system zeroing offset (`FltGetFsZeroingOffset`) are set to zero instead of decrypted.

### Master key and TPM

The keys of the chambers are derived from a 128-byte master key (`sub_100091A8`, kept in `dword_1000B0A8`):
1. If `HKLM\Software\Microsoft\StorageSec\Encrypt\MK` exists, the blob is unsealed by the TPM (`sub_1000A410`).
2. Else 128 random bytes (`BCryptGenRandom`, `BCRYPT_USE_SYSTEM_PREFERRED_RNG`), sealed by the TPM (`sub_1000A1C4`) and written to `MK` (REG_BINARY, `ZwFlushKey`).

TPM 2.0 commands (sent with `Tbsip_Submit_Command`, locality 0, priority 200, buffers of 512 bytes):  
| Command | Code | Content |
|---------|------|---------|
| `TPM2_Create` | 0x00000153 | tag `TPM_ST_SESSIONS` (0x8002), parent `0x81000001` (persistent storage root key), password session `TPM_RS_PW` (0x40000009) with empty auth, `inSensitive` = the master key (≤ 128 bytes), `inPublic` = `TPM_ALG_KEYEDHASH` (0x0008), name alg `TPM_ALG_SHA256` (0x000B), attributes 0x00000452 (`fixedTPM`, `fixedParent`, `userWithAuth`, `noDA`), no policy, scheme `TPM_ALG_NULL`; no outside info, no PCR. The returned `outPrivate` + `outPublic` is the `MK` value |
| `TPM2_Load` | 0x00000157 | parent `0x81000001`, `TPM_RS_PW`, the `MK` blob (≤ 485 bytes) |
| `TPM2_Unseal` | 0x0000015E | the handle returned by `TPM2_Load`, `TPM_RS_PW`; returns the master key |

The loaded object isn't flushed (`TPM2_FlushContext` isn't sent) ?.

Chamber key (`sub_10007358` → `sub_10009330` (cache) or `sub_10008CA8`):
1. Chamber name, plus `_DEBUG` for a debug chamber (`StorageCardProfiles\Chambers`).
2. `H` = HMAC-SHA256 keyed with the master key, over the chamber name (UTF-16, without terminator).
3. `Install` key = first 16 bytes of HMAC(…, name ‖ `Install`) (UTF-16), `Data` key = first 16 bytes of HMAC(…, name ‖ `Data`).
4. Both are cached in a generic table keyed by the chamber name (case-insensitive), with the last use time (`KeTickCount`). See `StSec` above.

The key type comes from the path: 1 (`Install`) for the code folders and the media chambers, 2 (`Data`) for the data folders ?.

### Chamber profiles

`sub_10006FBC` matches the path relative to the volume against these prefixes (first match), and builds a DACL whose owner is `SYSTEM`:  
| Prefix | Function | Chamber | Capabilities that get an ACE |
|--------|----------|---------|------------------------------|
| `\WPSystem\Apps\WindowsApps\` | `sub_100075E4` | Package name (first component, product fields up to the 4th `_`, `sub_1000752C`), or `Deleted` | `ID_CAP_CHAMBER_PROFILE_CODE_R`, `ID_CAP_CHAMBER_PROFILE_CODE_RW`, `ID_CAP_DEBUG_FOLDERS` |
| `\WPSystem\Apps\` | `sub_10007CB8` | App folder; also `TempNI\`, `TempInstall` | `…CODE_R`, `…CODE_RW`, `ID_CAP_CHAMBER_PROFILE_CODE_NITEMP_RW`, `ID_CAP_CHAMBER_PROFILE_CODE_INSTALLTEMP_RWD`, `ID_CAP_DEBUG_FOLDERS` |
| `\WPSystem\AppRepository\` | `sub_10007944` | Package name; `TempNI\` | `…CODE_R`, `…CODE_RW`, `…CODE_NITEMP_RW`, `ID_CAP_DEBUG_FOLDERS` |
| `\WPSystem\AppData\Local\Packages\` | `sub_10008020` | Package; subfolders `AC\`, `LocalState\`, `RoamingState\`, `TempState\`, `LocalCache\`, `Settings\`, `Local\Shared\Media\`, `Local\Shared\ShellContent\`, `PlatformData\`, `PlatformData\LiveTiles\` | `ID_CAP_CHAMBER_PROFILE_DATA_R`, `…DATA_RW`, `…DATA_MEDIA_RWD`, `…DATA_SHELLCONTENT_R`, `…DATA_SHELLCONTENT_RWD`, `…DATA_PLATFORMDATA_ALL`, `…DATA_LIVETILES_RWD`, `ID_CAP_DEBUG_FOLDERS`; account `DefApps` |
| `\WPSystem\AppData\` | `sub_100084C8` | App data folder; same subfolders as above (without the package ones) | same `…DATA_*` capabilities |
| `\WPSystem\SharedData\EdmCache\` | `sub_100088CC` | `EdmCache` | `ID_CAP_EDM_CACHE_WRITE`, `ID_CAP_EDM_CACHE_RWDELETE`, `ID_CAP_ZMFSERVICES` |
| `\WPSystem\SharedData\PhoneTools\AppXLayouts\` | `sub_10003A80` | `WPTOOLS` | `…CODE_R`, `…CODE_RW`, `ID_CAP_WPTOOLS_INSTALL_FOLDER`, `ID_CAP_DEBUG_FOLDERS` |
| Other path, prefix in `StorageCardProfiles\Override` | `sub_10008B2C` | — (or media / `EncryptAll` chamber) | Security descriptor of the transient object |
| Other path | `sub_10009B88` | `MusicChamber` (`\Music\`), `PicturesChamber` (`\Pictures\`), `VideosChamber` (`\Videos\`) with `EncryptMedia`; `{0b7992da-…}` with `EncryptAll`; else not encrypted | `SdMountPoint` security descriptor |

Fixed ACEs of a code folder (e.g. `sub_100075E4`): `SYSTEM` and `NT SERVICE\TrustedInstaller` (`S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464`, `.rdata:0x100013C4`) `FILE_ALL_ACCESS` (0x1F01FF); `Administrators`, `LocalService`, `NetworkService`, `Users` and the app's `ApplicationSid` read / execute (0x1200A9). The capability ACEs get 0x1200A9 (`…_R`), 0x1201BF (`…_RW`) or 0x1F01FF (`ID_CAP_DEBUG_FOLDERS` on a debug chamber). Each capability gives two ACEs, with its application and its service capability SID (`sub_100096F8` / `sub_10007458`).

Pool tags: `FCin` (registry path copy), `FCpp` (lookaside lists of contexts), `FCsb` (shadow buffers), `FCdc` (post-read work item), `FCvx` / `FCsx` (contexts), `FCnv` (volume name), `FCnf` (file name), `FCCr` (keys), `StSp` / `StSn` / `Secr` (security descriptors, key cache, registry data).
