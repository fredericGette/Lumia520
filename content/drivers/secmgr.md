## SecMgr.sys

Security Manager runtime driver of Windows Phone 8.1 ("[SecMgr Runtime]" in its debug messages, PDB name `secmgr.pdb`, 89 functions).  
It decides which executables may start. A process-creation callback (`PsSetCreateProcessNotifyRoutineEx`) checks every new process against the Security Manager metastore in the registry (`HKLM\Software\Microsoft\SecurityManager\…`, the same store as [SecRuntime.dll](../libraries/secruntime.md#security-metastore) and [ksecext.sys](./ksecext.md)). A process is allowed only if its executable is in the metastore and its token matches the declared account, AppContainer, capabilities and privileges, or if an `AuthorizationRules\Execute` rule allows it. Otherwise process creation fails with `STATUS_ACCESS_DENIED`.  
It also keeps the **kernel privilege cache** (string SID of a chamber → 64-bit privilege mask), which [SecRuntime.dll](../libraries/secruntime.md#kernel-privilege-cache) fills and [ksecext.sys](./ksecext.md#appcontainerprivilegesenabledext-0x100052cc) reads. It also offers a few privileged helpers through IOCTLs: trusting an executable's signature, setting the security of a device stack, and the SoC production test of [SOCProdTest.sys](./socprodtest.md).  

It imports `ntoskrnl.exe`, `HAL.dll` (`KeQueryPerformanceCounter`), [KSecExt.sys](./ksecext.md) (`KAddTrustedExecutable`) and [SOCProdTest.sys](./socprodtest.md) (`ProdTestDeviceControl`).

Device name : `\Device\SecMgr`  
Symbolic link : `\DosDevices\SecMgr`  

The device is created with `IoCreateDevice(DeviceType 0x22 FILE_DEVICE_UNKNOWN, Characteristics 0x100 FILE_DEVICE_SECURE_OPEN, not exclusive)`. Its DACL is then replaced (`sub_10004184`, "SmrSetDeviceACL", `ObSetSecurityObjectByPointer(DACL_SECURITY_INFORMATION)`):  
| SID | Access | Comment |
|-----|--------|---------|
| `S-1-5-18` (`SeExports->SeLocalSystemSid`) | 0x10000000 `GENERIC_ALL` | LocalSystem |
| `S-1-5-80-3215959076-2773177830-1034472450-959912374-972189589` | 0xE0000000 `GENERIC_READ \| GENERIC_WRITE \| GENERIC_EXECUTE` | Service SID of `NT SERVICE\SecMgr` (SHA-1 of the UTF-16 string `SECMGR`). Built from the table at `.rdata:0x10001A24` |

Registry of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\SecMgr` ?  

There's no parameters in the registry. `DriverEntry` doesn't use `RegistryPath`.

There's no ETW provider and no interface GUID. The driver logs with `DbgPrintEx(ComponentId 0x4D, …)`: level 0 for errors, level 1 for traces.

Pool tags: `secM` (0x4D636573, NonPagedPoolNx for the cache table, PagedPool for the other buffers) and `Secr` (0x72636553, metastore buffers, `sub_10008874` / `sub_10008894`).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\MountPointManager | mountmgr.sys | `IOCTL_MOUNTMGR_QUERY_POINTS` (0x6D0008) and `IOCTL_MOUNTMGR_QUERY_DOS_VOLUME_PATH` (0x6D0034): converts the NT path of an image into a DOS path (`sub_10005BE4`) |
| none (export) | [KSecExt.sys](./ksecext.md#kaddtrustedexecutable-0x10005108) | `KAddTrustedExecutable(path)` for [IOCTL 0x22E008](#ioctl-0x22e008) |
| none (export) | [SOCProdTest.sys](./socprodtest.md#ioctl-0x22e014) | `ProdTestDeviceControl(DeviceObject, Irp)` for every IOCTL code that SecMgr doesn't handle itself, e.g. [IOCTL 0x22E014](./socprodtest.md#ioctl-0x22e014) |

### Security metastore

Keys read under `HKLM\Software\Microsoft\SecurityManager\` (`ZwOpenKey(KEY_READ)` on `\REGISTRY\MACHINE\…`, `sub_100074FC`; values read with `ZwQueryValueKey(KeyValuePartialInformation)`, `sub_10007630`). The code is the same as in [ksecext.sys](./ksecext.md):  
| Key | Values | Use |
|-----|--------|-----|
| `Applications`, `ServiceGroups`, `Services`, `FullTrust` | value name = executable path (+ arguments) or string SID, data = chamber name (REG_MULTI_SZ with one string: size must be 2 × length + 4) | Lookup of a chamber by executable (`sub_10007CC0`), tried in this order. The chamber type is 2 (application), 0 (service group), 1 (service), 3 (full trust) |
| `Applications\<chamber>` | `ApplicationType` | 0 → 1, 4 → 3, other → 2 |
| | `ApplicationSid` | SID of the application (AppContainer SID) |
| | `ApplicationAccount` → `ApplicationAccounts\<account>\UserAccountSid` | Account of the application |
| | `ApplicationBinaries` | REG_MULTI_SZ, executables of the application (case-insensitive exact match) |
| | `RequiredPrivileges` | REG_BINARY: DWORD count + count × 12 bytes; a LUID at offset 4 of each entry |
| | `RequiredCapabilitySIDs` | REG_BINARY: DWORD count + SIDs one after the other |
| | `SignerCertificate\EnterpriseId`, `ThumbprintCNGHashAlgId`, `Thumbprint`, `SHA1Thumbprint` (20 bytes) | Read by the generic code (flags 0x40 / 0x80), not used by the authorization |
| | `OEMExtensible` | DWORD (flag 0x100, not used by the authorization) |
| `Services\<service>` | `ServiceGroup`, `ServiceAccount`, `ServiceSid`, `ServiceExecutablePath`, `RequiredPrivileges`, `UnionRequiredCapabilities`, `OEMExtensible` | Service chamber |
| `ServiceGroups\<group>` | `ServiceAccount`, `ServiceSids`, `ServiceGroupExecutablePath`, `UnionRequiredPrivileges`, `UnionRequiredCapabilitySIDs` | Service group chamber |
| `ServiceAccounts\<account>` | `UserAccountSid` | Account SID. Also enumerated to find the account of a SID (`sub_100031C0`) |
| `FullTrust\<chamber>` | `Account` (→ `ApplicationAccounts\<account>`), `FullTrustBinaries` | Full trust chamber |
| `AuthorizationRules\Execute\<rule>` | `TargetChamber`, `PrincipalClass` | Enumerated (`sub_10008424`): the principal classes whose rule targets a chamber (case-insensitive) |
| `PrincipalClasses\<class>` | `Executables` (REG_MULTI_SZ, exact match), `Directories` (REG_MULTI_SZ, prefix match) | Executables that the principal class may start (`sub_100085E0`) |
| `AppXProfiles\<chamber>` | first value (REG_SZ) | Install folder of an AppX application: `<data>\` is a prefix of its binaries (`sub_100086A8`) |
| `StorageCardProfiles\Chambers` | value `<chamber>` | Present = application installed on the SD card |
| `StorageCardProfiles` | `StorageCardDrive` | Prefix `<drive>WPSystem\Apps\<chamber>` of the binaries of an SD card application. If the application isn't on the SD card: `C:\Data\Programs\<chamber>` |

The generic lookup `sub_100070C0(kind, name, flags, &props)` fills an 88-byte structure (freed by `sub_100071B4`) from the chamber key. `kind` 0 = by chamber name (`Applications`, then `Services` → `ServiceGroup`, then `Services`, then `FullTrust`), 1 and 2 = by executable / SID (`sub_10007CC0`):  
| Offset | Flag | Content |
|--------|------|---------|
| 0x00 | | Flags actually read |
| 0x04 | 0x01 | Chamber / account name ("ChamberID" in the logs) |
| 0x08 | 0x02 | Type: 0 service or service group, 1 application, 2 full trust |
| 0x0C | 0x02 | Application type (1, 2, 3, from `ApplicationType`) |
| 0x10 | 0x04 | `UserAccountSid` |
| 0x14 / 0x18 | 0x04 | Count / array of the chamber SIDs (`ApplicationSid`, `ServiceSid`, `ServiceSids`) |
| 0x1C | 0x08 | Binaries (`ApplicationBinaries`, `ServiceExecutablePath`, …) |
| 0x20 / 0x24 | 0x10 | Count / array of the required privileges (LUIDs) |
| 0x28 / 0x2C | 0x20 | Count / array of the required capability SIDs |
| 0x30 | 0x40 | `EnterpriseId` |
| 0x34-0x40 | 0x80 | Thumbprint, its length, hash algorithm, SHA-1 thumbprint |
| 0x54 | 0x100 | `OEMExtensible` |

### Process creation filter

`sub_10005980` ("SmrProcessNotifyHandler") is registered with `PsSetCreateProcessNotifyRoutineEx` in `DriverEntry`. `CreateInfo->CreationStatus` is first set to `STATUS_ACCESS_DENIED` (0xC0000022), so a process is blocked unless one of the checks succeeds.

Process creation:
1. "PrivilegeCacheAddRefForProcess" (`sub_10005508`): opens the token of the new process (`ZwOpenProcess` + `ZwOpenProcessTokenEx`). If it's an AppContainer, the string of its AppContainer SID must be in the [privilege cache](#privilege-cache), and its reference count is incremented. If it isn't in the cache, **the creation is denied**. So an AppContainer process can only start after its chamber has been added with [IOCTL 0x22E050](#ioctl-0x22e050).
2. If `FileOpenNameAvailable`: "SmrProcessAuthorization" (`sub_10006564`) with `ImageFileName` and `CommandLine`.
3. If that fails (or the name isn't available): `SeLocateProcessImageName`, then conversion to a DOS path (`sub_10005F48`: `ZwOpenFile` of the image, `ObQueryNameString` of its device, the drive letter from the Mount Point Manager, `FileNameInformation`), and "SmrProcessAuthorization" again with that path. The log says `Allowed` or `Blocked!`.
4. The result is the `CreationStatus`.

SmrProcessAuthorization (`sub_10006564`):
1. Removes a leading `\??\` from the image path (max. 260 characters).
2. Queries the token: `TokenUser`, `TokenGroupsAndPrivileges`, `TokenIntegrityLevel`, `TokenIsAppContainer`, `TokenAppContainerSid`, `TokenCapabilities` (`sub_10006A88`). The SID of the process is the AppContainer SID, or the user SID otherwise.
3. Builds `<image path><arguments>` from the command line: the first token (quoted or up to the first space) is replaced by the image path (`sub_10006B88`).
4. Looks for this string as a value name in the metastore ("QueryExecutableProperties", flags 0x37). If it's not found (0xC0000034), looks up the SID of the process instead. If that finds an application, the image must be in its `ApplicationBinaries` or under its install folder (`sub_100072F4`, `sub_100086A8`).
5. If a chamber was found, "SmrDatabaseAuthorize" (`sub_1000647C`), see below. Success = process allowed.
6. Otherwise "SmrModuleAuthorization" (`sub_10007398`). The chamber is the one found above, or the account of the process SID (`Applications` value of the SID, or a `ServiceAccounts\*` whose `UserAccountSid` is the SID), or `SYSTEM`. The image must be in a principal class of an `AuthorizationRules\Execute` rule whose `TargetChamber` is that chamber, **or of a rule whose `TargetChamber` is `SYSTEM`**. Otherwise → `STATUS_ACCESS_DENIED`.
7. If `AuthorizationRules\Execute` doesn't exist (SOFTWARE hive not loaded yet) and the chamber is `SYSTEM`, only `<SystemRoot>\System32\smss.exe` and `<SystemRoot>\System32\bootprep.exe` are allowed (`SystemRoot` read from `KUSER_SHARED_DATA.NtSystemRoot`, 0xFFFF9030).

SmrDatabaseAuthorize (`sub_1000647C`): flags 0x36 or 0x07 must all have been read (else `STATUS_INVALID_PARAMETER`). Every check failure returns `STATUS_ACCESS_DENIED`:  
| Chamber type | Checks |
|--------------|--------|
| All | Token user SID = `UserAccountSid` |
| 1 application | The process is an AppContainer, the chamber has exactly 1 SID and it's the token's AppContainer SID, every capability SID of the token is in the chamber's capabilities, every privilege of the token is in `RequiredPrivileges` |
| 2 full trust | The process isn't an AppContainer |
| 0 service | The process isn't an AppContainer. Every group SID of the token whose string starts with `S-1-5-81` must be in the chamber's capabilities (`sub_10006324`), and every privilege of the token must be in the required privileges (`sub_1000642C`) |

> [!NOTE]
> The `S-1-5-81` test in `sub_10006294` compares the whole SID string (`_wcsnicmp` with the length of the SID) with the 8-character literal, and only for SIDs longer than 8 characters. So it seems to never match, and the service group SID check always passes ?

Process exit: "PrivilegeCacheRemoveForProcess" (`sub_10005338`) decrements the reference count of the AppContainer SID. The entry is deleted when the count drops back to 1, so a cache entry lives until the first process of the chamber exits.

### Privilege cache

`RtlInitializeGenericTable` at `.data:0x1000903C`, protected by a fast mutex (`.data:0x1000901C`). 24-byte entries, compared with `_wcsicmp` on the key:  
| Offset | Content |
|--------|---------|
| 0x00 | Key: string SID of the chamber, e.g. `S-1-15-2-…` (PagedPool, tag `secM`) |
| 0x08-0x0F | 64-bit privilege mask: bit n = privilege LUID n (`RequiredPrivileges` of the chamber) |
| 0x10 | Reference count (1 at insertion) |

Filled by [IOCTL 0x22E050](#ioctl-0x22e050), read by [IOCTL 0x226054](#ioctl-0x226054), emptied at unload.

### Statistics

48 bytes at `.data:0x10009068`, returned and reset by [IOCTL 0x226004](#ioctl-0x226004). Each pair is updated with interlocked 64-bit adds (`sub_10005B54`): elapsed time in µs (`KeQueryPerformanceCounter`), then count.  
| Bytes | Comment |
|-------|---------|
| 00-07 / 08-0F | Total time / count of the SmrProcessAuthorization calls (process creation) |
| 10-17 / 18-1F | Time / count of the `ZwOpenFile` of the image in the path conversion |
| 20-27 / 28-2F | Time / count of the metastore lookups (`sub_100070C0`) |

---

### IOCTL 0x226004

This IOCTL is processed by SecMgr.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x801 |
| Access | READ_AND_WRITE ||
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get and reset the statistics | ignored | 48 minimum |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-2F | ? | The [statistics](#statistics), then zeroed in the driver |

`STATUS_INVALID_PARAMETER` if `OutputBufferLength` < 48, otherwise `IoStatus.Information` = 48. No caller found.

---

### IOCTL 0x226054

This IOCTL is processed by SecMgr.sys (`sub_10005294`). It's sent by [ksecext.sys](./ksecext.md#ioctl-0x226054) and by `QueryKernelPrivilegeCache` of [SecRuntime.dll](../libraries/secruntime.md#kernel-privilege-cache).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x815 |
| Access | READ_AND_WRITE ||
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Query kernel privilege cache | not 0 | 8 exactly |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | `S-1-15-2-…` | String SID of the chamber, UTF-16 with its NUL |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | 64-bit privilege mask of the [cache](#privilege-cache) entry (bit n = privilege LUID n). 0 if the SID isn't in the cache |

`STATUS_INVALID_PARAMETER` if the input length is 0 or the output length isn't 8. Otherwise `STATUS_SUCCESS` and `IoStatus.Information` = 8, even when the SID isn't found.

---

### IOCTL 0x22E008

This IOCTL is processed by SecMgr.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x802 |
| Access | READ_AND_WRITE |\| FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Add trusted executable | path + 2 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | `C:\…` | Path of the executable, UTF-16 with its NUL |

Calls [KAddTrustedExecutable](./ksecext.md#kaddtrustedexecutable-0x10005108) of KSecExt.sys with the system buffer: the file gets signing level 6 (Store) in its signing level cache **without its signature being checked**. The length isn't checked, only that the system buffer isn't NULL (else `STATUS_INVALID_PARAMETER`). `IoStatus.Information` = 0. No caller found.

---

### IOCTL 0x22E028

This IOCTL is processed by SecMgr.sys (`sub_10006D20`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x80A |
| Access | READ_AND_WRITE |\| FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the security of a device stack | 12 exactly | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle of a file opened on the device, in the caller's process (`ObReferenceObjectByHandle(UserMode, IoFileObjectType)`) |
| 04-07 | 04 00 00 00 | `SECURITY_INFORMATION`, e.g. `DACL_SECURITY_INFORMATION` |
| 08-0B | ? | Pointer to the `SECURITY_DESCRIPTOR` in the caller's address space, passed as is. Must not be NULL |

Starting at the top of the stack (`IoGetAttachedDeviceReference`), it calls `ObSetSecurityObjectByPointer` and sets `FILE_DEVICE_SECURE_OPEN` (0x100) in `Characteristics` of every device object, then goes down (`IoGetLowerDeviceObject`). It stops after the first device that has a VPB (`DEVICE_OBJECT` + 0x24). If it reaches the bottom without a VPB, it returns `STATUS_INVALID_PARAMETER` **although the security of the whole stack has been changed**. No caller found.

---

### IOCTL 0x22E050

This IOCTL is processed by SecMgr.sys. It's sent by `UpdateKernelPrivilegeCache` of [SecRuntime.dll](../libraries/secruntime.md#kernel-privilege-cache).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x814 |
| Access | READ_AND_WRITE |\| FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Update kernel privilege cache | not 0 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | ? | Chamber name (not a SID), UTF-16 with its NUL |

1. `sub_10005054`: metastore lookup by chamber name (flags 0x14: SIDs and privileges). The first SID of the chamber (`ApplicationSid` / `ServiceSid`) must be valid (else `STATUS_INVALID_SID` 0xC0000078), and it's converted to its string. The required privileges become a 64-bit mask (low DWORD: `1 << LUID`, high DWORD: `1 << (LUID - 32)`).
2. "PrivilegeCacheAddChamber" (`sub_10005148`): if the string SID is already in the [cache](#privilege-cache), its mask is replaced and its reference count incremented. Otherwise a new entry is inserted with a reference count of 1.

`STATUS_INVALID_PARAMETER` if the input length is 0 or the string has no NUL. Other errors come from the metastore (e.g. 0xC0000034 if the chamber doesn't exist).

---

### Other IOCTLs

Any other code is passed to `ProdTestDeviceControl(DeviceObject, Irp)` of [SOCProdTest.sys](./socprodtest.md#ioctl-0x22e014). SecMgr then completes the IRP with the returned status. So [IOCTL 0x22E014](./socprodtest.md#ioctl-0x22e014) (SoC production test) is reached through `\Device\SecMgr`. If the status is `STATUS_INVALID_PARAMETER`, the message `Unrecognized ioctl code` is logged.

Every IOCTL sent to a device object other than `\Device\SecMgr` returns `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). `IRP_MJ_CREATE`, `IRP_MJ_CLOSE` and `IRP_MJ_CLEANUP` just succeed.
