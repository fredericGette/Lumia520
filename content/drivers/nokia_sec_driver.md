## Nokia_sec_driver.sys

Nokia security driver (version string `6.38.0.40844`).
It's the gateway between the Windows side and the Nokia security services of the TrustZone: certificates, eFuses, ESN, SIM lock, SD authentication, service tag, watchdog. Almost every IOCTL ends up in a request to a trustlet, sent as a raw [TrustZone syscall](#trustzone-calls) through [qcscm8930.sys](./qcscm8930.md).
It also gives access to the DPP partition (`C:\DPP`, file IOCTLs), to the UEFI variables, to some registry values, and sets the [SSM mode](#ssm-mode) of the MODEM at start.
It's a non-PnP driver with one control device: there's no `EvtDriverDeviceAdd` and no ACPI node. The PDB path is `c:\wa\git\wp_security_rg3\driver\ARM\Release\nokia_sec_driver.pdb`.

Device name : `\Device\NokiaSec`
Symbolic link : `\DosDevices\NokiaSec`
Device SDDL : `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GRGW;;;WD)(A;;GR;;;RC)`

> [!NOTE]
> The SDDL gives read/write access to Everyone (`WD`), and all the IOCTLs use `FILE_ANY_ACCESS`: the driver doesn't check who calls it. The only protection is on the TrustZone side.

Registry key `HKEY_LOCAL_MACHINE\SOFTWARE\OEM\Nokia\nokia_sec_driver`:
| Registry value | value | comment |
|----------------|-------|---------|
| Debug | 0 | REG_DWORD. Created with 0 if it's missing. See [Logging](#logging). Written back by [IOCTL 0x9C412454](#ioctl-0x9c412454--set-logging-state) |

There's no ETW provider and no device interface.

It communicates with the following devices:
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SysEnv | [qcscm8930.sys](./qcscm8930.md) | TrustZone syscalls, [internal IOCTL 0xC3514004](#internal-ioctl-0xc3514004). Opened by name the first time a call is needed (`ScmOpenTarget`, `sub_4130BC`) |
| \Device\DiagCSI | [qcdiagcsi8930.sys](./qcdiagcsi8930.md) | MODEM file system and NV items through DIAG commands. [IOCTL 0x80092440](#ioctl-0x80092440), [IOCTL 0x80092444](#ioctl-0x80092444) |
| \Device\SSM | [qcssm8930.sys](./qcssm8930.md) | Secure Services Module. [IOCTL 0x80092408](#ioctl-0x80092408), [IOCTL 0x80092414](#ioctl-0x80092414), [IOCTL 0x8009241C](#ioctl-0x8009241c) |

No client of this device has been found in the documented drivers, libraries and applications yet.

### Start-up

`DriverEntry` (0x416000):

1. `WdfDriverCreate` with `WdfDriverInitNonPnpDriver`. Unload callback `sub_411508` (`sub_4079A4`), cleanup callback `sub_411518` (does nothing).
2. Reads `Debug` in the registry (`sub_416128`).
3. `WdfControlDeviceInitAllocate` with the SDDL above, then `sub_411524`: assigns the name, `WdfDeviceCreate` with the context `NokiaSecData` (16 bytes), creates the symbolic link and the default queue (`WdfIoQueueDispatchSequential`, `EvtIoDeviceControl` = `IoctlHandler` 0x411000), `WdfControlFinishInitializing`.
4. Logs the KMDF version.
5. `SecInit` (`sub_407780`): initialises the semaphore `.data:0x40FB40` with 0 and starts a system thread, then returns success even if the thread can't be created.

The thread (`sub_407840`) calls `sub_4078E4`, then releases the semaphore. **The IOCTLs wait for this semaphore**, so they only start once the initialisation is done. `sub_4078E4` does:

1. `sub_4117E8`: if `Debug` = 0, deletes `C:\DPP\Nokia\seclabel.log` and `C:\Data\SharedData\Oem\Public\nokia_sec_driver_log.txt`.
2. `LoadSharedSecMemory` (`sub_409494`), only the first time: allocates the 2 [shared areas](#shared-memory) and registers them in the TrustZone (service 0xF000002E). "SSAPI_SHARED_PUB_AREA_SET_SERV not supported" (return 0x80040002 with PRET 1) is accepted.
3. `NokiaSecRdcImportService`: imports `C:\DPP\nokia\certs\rdc`.
4. `PapubKeysImport`: imports `C:\EFIESP\Nokia\Security\papubkeys_ape_MSM_v1.bin`.
5. `EsnInit`: imports `C:\DPP\nokia\certs\npc`.
6. `SecInitDebugInfo` (`sub_4119A4`): logs the version, the device info and the eFuses. Only if `Debug` ≠ 0.
7. `NokiaSecSsmModemMode` with the mode 2 and the retry enabled, see [SSM mode](#ssm-mode).

The errors of steps 3 to 5 aren't checked here. `.data:0x40FA0C` keeps the result: bit 0 = shared memory loaded, bit 1 = public keys imported, bit 2 = ESN initialised. See [IOCTL 0x9C412410](#ioctl-0x9c412410--nokiasecselftestservice).

`sub_4079A4` (unload) stops the SSM timer, frees the buffers, removes the shared area from the TrustZone (service 0xF000002F, `hal_sec_shared_pub_area_remove`) and frees the shared areas.

### IOCTL processing

`IoctlHandler` (0x411000) waits for the semaphore `.data:0x40FB40` for 10 s, calls the handler, completes the request and releases the semaphore.

- On timeout, the request is completed with `STATUS_TIMEOUT` (0x102), without any handler call. The semaphore is released anyway, although it wasn't acquired.
- An unknown code returns `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).
- A code in the range without handler ([0x9C412468](#ioctl-0x9c412468)) returns `STATUS_NOT_SUPPORTED` (0xC00000BB).
- `.data:0x40F9F4` keeps the status of the last IOCTL, read by [IOCTL 0x9C4124B0](#ioctl-0x9c4124b0--nokiasecgetsecreturnvalues).

The buffers are checked with `WdfRequestRetrieveInputBuffer` / `WdfRequestRetrieveOutputBuffer`, which only check a minimum size. Most of the buffers have a variable part: `struct { DWORD length; BYTE data[1]; }` has a size of 8 bytes, so the minimum size is `length + 7`. The driver reads the input buffer twice: once with the fixed size to get the length, and once with the total size.

### Shared memory

`LoadSharedSecMemory` allocates 2 contiguous buffers with `MmAllocateContiguousMemorySpecifyCache`:

| Global | Size | Content |
|--------|------|---------|
| `.data:0x40FA38` (also `0x40F9E8`) | 0x8000 | Secure call area, see below |
| `.data:0x40FA28` | 0x4000 | 4 slots of 0x1000 bytes for the files given to the TrustZone: +0 `papubkeys_ape_MSM_v1.bin`, +0x1000 `npc`, +0x2000 `rdc`, +0x3000 SIM lock `lock` |

Secure call area:
| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Service number, see [TrustZone calls](#trustzone-calls) |
| 0x04 | 4 | 0 |
| 0x08 | 56 | Arguments of the service. Its physical address is given to the trustlet |
| 0x40 | 72 | SCM buffer, copied from a template |
| 0x88 | 12 | `WDF_MEMORY_DESCRIPTOR` of the SCM buffer |
| 0x94 | 32620 | Small heap (`sub_4048FC` alloc, `sub_4049AC` free). 12-byte block header (next, size, used), sizes aligned on 4 bytes. All the requests and responses of the TrustZone are allocated here |

A call is protected by the mutex `.data:0x40FA9C`, the heap by the mutex `.data:0x40FAC4`. `sub_404E20` refuses a pointer outside of `area + 0xA0` … `area + 0x8000` with the error 6.

### TrustZone calls

`call_through_tz` (`sub_404B48`) fills the SCM buffer from the template at `.data:0x40F040`, and sends it with [internal IOCTL 0xC3514004](#internal-ioctl-0xc3514004):

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 48 00 00 00 | `len` |
| 04-07 | 10 00 00 00 | `command_start_off` |
| 08-0B | 20 00 00 00 | `response_write_off` |
| 0C-0F | 01 F4 03 00 | `command_id` 0x3F401 (send to trustlet) |
| 10-13 | | Application ID (`.data:0x40FAC0`) |
| 14-17 | | Service number |
| 18-1B | | Physical address of the arguments (area + 8) |
| 1C-1F | 77 77 77 77 | Filler. The template continues with `88 88 88 88`, `99 99 99 99`, `AA AA AA AA`, `BB BB BB BB`, `CC CC CC CC` |
| response +08 | | SCM status, must be 1 |
| response +0C | | `issw`: return value of the service (HRET) |

`getLocalAPPID` (`sub_404D5C`) finds the application ID the first time: it tries 2, 1, 3 then 4 with the service 0xF0000030 until the call returns 35. On failure the ID is -1 and no other call is sent: the return value is 10.

Services:
| Service | Function | Use |
|---------|----------|-----|
| 0xF0000007 | `PublicIdRead` (`sub_40883C`) | [IOCTL 0x9C412428](#ioctl-0x9c412428--publicidread) |
| 0xF000000A | `NokiaSecRandomDataGetService` (`sub_403AC8`) | [IOCTL 0x9C41242C](#ioctl-0x9c41242c--nokiasecrandomdatagetservice) |
| 0xF000000F | `RootKeyHashRead` (`sub_408544`) | [IOCTL 0x9C41241C](#ioctl-0x9c41241c--rootkeyhashread) |
| 0xF0000011 | `NokiaSecRdcImportService` (`sub_408D24`) | [IOCTL 0x9C412448](#ioctl-0x9c412448--nokiasecrdcimportservice) |
| 0xF0000012 | Protected application call | See the next table |
| 0xF0000018 | `NokiaSecHwDebugInfoGet` (`sub_409020`) | [IOCTL 0x9C412450](#ioctl-0x9c412450--nokiasecrdcdebuginfogetservice) |
| 0xF000001A | `PapubKeysImport` (`sub_407050`) | Start. The data must start with `UPAP` |
| 0xF000001D | `NokiaSecSwDebugInfoGet` (`sub_40911C`) | [IOCTL 0x9C412450](#ioctl-0x9c412450--nokiasecrdcdebuginfogetservice) |
| 0xF000002A | `NokiaSecEfuseWrite` (`sub_403998`) | [IOCTL 0x9C412414](#ioctl-0x9c412414--nokiasecefusewrite) |
| 0xF000002B | `NokiaSecRdPhoneReqService` (`sub_408E7C`) | [IOCTL 0x9C41244C](#ioctl-0x9c41244c--nokiasecrdphonereqservice) |
| 0xF000002C | `NokiaSecSecurityModeInfoGet` (`sub_409218`) | [IOCTL 0x9C412450](#ioctl-0x9c412450--nokiasecrdcdebuginfogetservice) |
| 0xF000002E | `SecSharedPubAreaSet` (`sub_404520`) | Start. Physical addresses and sizes of the 2 shared areas |
| 0xF000002F | `hal_sec_shared_pub_area_remove` | Unload |
| 0xF0000030 | ? | `getLocalAPPID`, must return 35 |
| 0xF0000032 | `NokiaSecEfuseRead` (`sub_403A30`) | [IOCTL 0x9C4124D8](#ioctl-0x9c4124d8--nokiasecefuseread) |
| 0xF0000033 | `NokiaSecGeneralDeviceInfo` (`sub_4052C4`) | `SecInitDebugInfo`, logged only |

The service 0xF0000012 calls a protected application (PA, meaning of the abbreviation ?). Arguments: +0x08 PA index, +0x0C 0, +0x10 physical address of the input, +0x14 physical address of the return value, +0x18 0. The byte at +2 of the input is the function of the PA.

| PA name | Index | Function | Comment |
|---------|-------|----------|---------|
| `PA_LABEL2` | 1 | 10 | `TerminalRespCreateVer0` / `TerminalRespCreateVer1` |
| `PA_LABEL2` | 1 | 11 | `TerminalResponseSize` |
| `PA_ESN` | 2 | 17 | `EsnInit` |
| `PA_ESN` | 2 | 33 | `NokiaSecEsnReadService` |
| `PA_SD` | 3 | 2 | `NokiaSecSdAuthInit` |
| `PA_SD` | 3 | 3 | `NokiaSecSdAuthenticate` |
| `PA_SD` | 3 | 4 | `NokiaSecSdVerify` |
| `PA_SD` | 3 | 5 | `NokiaSecSdAuthenticationReset` |
| `PA_SWD` | 6 | 11 | Reads the period and the maximum of the watchdog |
| `PA_SWD` | 6 | 31 | Updates the watchdog |
| `PA_CCC` | 11 | | Known by `sub_404A3C`, never called |
| `PA_SIMLOC30` | 22 | 1 | `NokiaSecSimlockService` |
| `PA_OTP` | 25 | 21 | `RootKeyHashWrite` |
| `PA_OTP` | 25 | 22 | `ChipSpecificInfoRead` |
| `PA_OTP` | 25 | 23 | `ChipSpecificDataWrite` |
| `PA_OTP` | 25 | 24 | `NokiaSecEfuseFinalize` |
| `PA_OTP` | 25 | 25 | `NokiaSecOtpEfuseReadLength` |
| `PA_OTP` | 25 | 26 | `NokiaSecOtpEfuseRead` |
| `PA_OTP` | 25 | 27 | SSM mode message (`NokiaSecSetSsmModemMode`) |
| `PA_OTP` | 25 | 28 | `DakImport` |
| `PA_OTP` | 25 | 29 | Gets the DAK to write in the DPP |
| `PA_OTP` | 25 | 30 | `NokiaSecEfuseReadSecFea` |
| `PA_CA` | 42 | 1 | `NokiaSecCaSelftestDevCertService` |
| `PA_CA` | 42 | 2 | `NokiaSecCaCheckAsedService` |
| `PA_CA` | 42 | 17 | `NokiaSecCaCreateCertService` |
| `PA_CA` | 42 | 18 | `NokiaSecCaCertLenService` |
| `PA_PVK` | 44 | 1 | `NokiaSecPvkAsedDecryptService` |
| `PA_OBC` | 45 | 1 | `NokiaSecObcService` |
| `PA_SSD` | 47 | 1 | `NokiaSecSsdDecryptData` |
| `PA_SVCTAG2` | 49 | 1 | `NokiaSecSvcTagLengthService` |
| `PA_SVCTAG2` | 49 | 2 | `NokiaSecSvcTagService` |
| `PA_MIRLINK` | 51 | 1 | `NokiaSecMirlinkCheckAsedService` |
| `PA_MIRLINK` | 51 | 2 | `NokiaSecMirlinkSignDigestService` |
| `PA_BIF` | 52 | 1 | `NokiaSecBifAsedVerify` |

`call_tz_oem_wd_reset` (`sub_404C98`) is the only other call: same buffer, template `.data:0x40F088`, `command_id` 0x3F801 (service 0xFE, command 1), the DWORD at +0x10 = 10000. It's sent by [IOCTL 0x9C41240C](#ioctl-0x9c41240c--software-watchdog).

### Return values

`sub_407570` converts the 2 return values into a NTSTATUS. HRET is the return of the call, PRET the return of the protected application. They are saved for [IOCTL 0x9C4124B0](#ioctl-0x9c4124b0--nokiasecgetsecreturnvalues).

| HRET | NTSTATUS |
|------|----------|
| 1 | Depends on PRET |
| 2 | 0xC00000BB `STATUS_NOT_SUPPORTED` |
| 4, 5 | 0xC0000708 |
| 6, -5 | 0xC000000D `STATUS_INVALID_PARAMETER` |
| 7, 20 | 0xC0000017 `STATUS_NO_MEMORY` |
| 18 | 0xC0000428 `STATUS_INVALID_IMAGE_HASH` |
| -10, -9, -7, -4 to -1 | 0xC0000225 `STATUS_NOT_FOUND` |
| Others | 0xC0000001 `STATUS_UNSUCCESSFUL` |

| PRET (HRET = 1) | NTSTATUS |
|-----------------|----------|
| 1 | 0 |
| 3, 20, 37, 38 | 0xC000000D `STATUS_INVALID_PARAMETER` |
| 4, 15, 16, 17, 21, 31, 34, 39, 57, 58, 64, 67, 68, 78, 95 | 0xC0000225 `STATUS_NOT_FOUND` |
| 7 | 0xC0000017 `STATUS_NO_MEMORY` |
| 8, 22, 94 | 0xC0000022 `STATUS_ACCESS_DENIED` |
| 9 | 0xC00000F2 |
| 24, 25, 29 | 0xC0000428 `STATUS_INVALID_IMAGE_HASH` |
| 35 | 0xC00000EF |
| 80 | 0x102 `STATUS_TIMEOUT` |
| 96 | 0xC00000F0 |
| 97 | 0xC00000F1 |
| Others | 0xC0000001 `STATUS_UNSUCCESSFUL` |

### Files

| File | Use |
|------|-----|
| `C:\EFIESP\Nokia\Security\papubkeys_ape_MSM_v1.bin` | Public keys. Read from the offset 145, where `UPAP` must be found. Max 4096 bytes |
| `C:\DPP\nokia\certs\npc` | Imported by `EsnInit`. Max 4096 bytes |
| `C:\DPP\nokia\certs\rdc` | Imported by `NokiaSecRdcImportService`. Max 4096 bytes |
| `C:\DPP\nokia\certs\dak.bin` | DAK, 32 bytes. Written by [IOCTL 0x9C412420](#ioctl-0x9c412420--chipspecificdatawrite), imported by [IOCTL 0x9C412408](#ioctl-0x9c412408--terminalresponse) |
| `C:\DPP\nokia\simlock\lock` | SIM lock data. Max 4096 bytes. If it's missing, 56 null bytes are used |
| `C:\DPP\nokia\simlock\keys` | At least 160 bytes, the first 160 are used |
| `C:\DPP\nokia\simlock\sign` | At least 134 bytes: 128 bytes of signature + 6 bytes |
| `C:\DPP\nokia\simlock\unlock.bin` | 147 bytes. Rewritten by the SIM lock command 6 |
| `C:\DPP\Nokia\product.dat` | Text file, the line `LPSN` gives the serial number (max 16 characters) used by [IOCTL 0x9C412470](#ioctl-0x9c412470--nokiasecsvctagservice) |
| `C:\DPP\Nokia\seclabel.log` | Only deleted by the driver |

Files of the MODEM (read through DIAG):
| File | Use |
|------|-----|
| `/nv/item_files/modem/ssm_mode` | Current SSM mode |
| NV item 0x226 (550) | IMEI (`SimlockDataReadImei`), see [IOCTL 0x80092444](#ioctl-0x80092444) |

### SSM mode

The driver sets the mode of the [Secure Services Module](./qcssm8930.md) with `NokiaSecSsmModemMode` (`sub_41335C`). It's called with the mode 2 at start and by [IOCTL 0x9C412438](#ioctl-0x9c412438--nokiasecssmmodemmode).

`NokiaSecSetSsmModemMode` (`sub_413788`):

1. `NokiaSecSetSsmMode` (`sub_4138A4`) with the pseudo mode 10: opens `\Device\SSM` and sends [IOCTL 0x80092408](#ioctl-0x80092408). The result must be 1 (MODEM key exchange done), else `STATUS_ACCESS_DENIED`.
2. Stops the retry timer. `.data:0x40FA74` = 1, returned by [IOCTL 0x9C4124AC](#ioctl-0x9c4124ac--ssm-ready).
3. Gets a 104-byte message from `PA_OTP` function 27, with the mode as input. For the modes 4, 5, 8 and 9, the error of the TrustZone is ignored.
4. `NokiaSecSetSsmMode` with the mode and the message.
5. If the mode read back isn't the requested one, step 4 again with mode + 16.

`NokiaSecSetSsmMode` for the other modes:

1. Registers to `\Device\DiagCSI` the first time (`DiagSendInit`).
2. Reads the current mode with the MODEM file `ssm_mode` (`sub_409CE8`). If the file doesn't exist the content is `1111`. If the first byte is a digit, and the second or the third byte isn't null, the mode is this digit. Otherwise it's the content as a DWORD.
3. Mode 9: returns the current mode. If the current mode is already the requested one, stops here.
4. Mode ≥ 16: the local copy of the message starts with `NOKI`, the bytes 4 and 7 = mode + 0xF0.
5. Sends [IOCTL 0x8009241C](#ioctl-0x8009241c) for the mode 8, [IOCTL 0x80092414](#ioctl-0x80092414) for the others.
6. Reads the mode again.

If the first try fails at start (the MODEM isn't ready), a 1 s periodic timer (`sub_4134A0`) enqueues a work item (`sub_4136E4`) that tries again. The timer is stopped after 10 tries ("10 times tried to set SSM mode -> stop.").

### SD authentication

The session is limited by 3 timers. Each of them calls `NokiaSecSdAuthenticationReset` (`sub_413FD8`) through a work item (`sub_414504`) when it expires.

| Timer | Delay | Started by | Stopped by |
|-------|-------|------------|------------|
| Authentication | 30 s, one shot | [IOCTL 0x9C412458](#ioctl-0x9c412458--nokiasecsdauthinit) | [IOCTL 0x9C412460](#ioctl-0x9c412460--nokiasecsdverify) |
| Message | 12 s, one shot | [IOCTL 0x9C412458](#ioctl-0x9c412458--nokiasecsdauthinit), [IOCTL 0x9C41245C](#ioctl-0x9c41245c--nokiasecsdauthenticate) | Each following command |
| Session | 180 s (period of 5 s, remaining time in `.data:0x40FAF0`) | [IOCTL 0x9C412460](#ioctl-0x9c412460--nokiasecsdverify) | [IOCTL 0x9C4124A0](#ioctl-0x9c4124a0--nokiasecsdclose) or end of the time |

An error of the TrustZone also resets the authentication.

### Software watchdog

The watchdog is driven by the `PA_SWD` protected application, see [IOCTL 0x9C41240C](#ioctl-0x9c41240c--software-watchdog). The initialisation (`sub_414AC8`) reads the period and the maximum (default 600 s for both), and creates a periodic timer. When the timer expires, the work item `sub_414C38` sends the update (`PA_SWD` function 31) with `min(maximum, 600)`, and saves the new period and the new maximum returned by the TrustZone (log "SWD next %d, max %d"). The timer period isn't changed. The name "software watchdog" for SWD is a guess ?

### Logging

`Debug` is a bit mask, kept in `.data:0x40FA04`:

| Bit | Comment |
|-----|---------|
| 0 | Log to `C:\Data\SharedData\Oem\Public\nokia_sec_driver_log.txt` |
| 1 | Log to `C:\Data\Users\Public\Documents\nokia_sec_driver_log.txt` |
| 2 | `DbgPrintEx` (component 0x4D) |

Bits 0 and 1 together are refused. The file lines start with `[%d-%d-%d, %d:%d:%d:%d] `. `SecInitDebugInfo` logs the public ID and the root key hash byte by byte, the RDC bits, the eFuse features and the TLV data of the eFuses.

### eFuse security features

Bytes returned by `PA_OTP` function 30 ([IOCTL 0x9C4124D0](#ioctl-0x9c4124d0--nokiasecfearead)):

| Byte | Bit | Name |
|------|-----|------|
| 0 | 0 | `SEC_EFUSE_FEA_SIMLOCK_ACTIVE` |
| 0 | 1 | `SEC_EFUSE_FEA_PRODUCTION_DONE` |
| 0 | 2 | `SEC_EFUSE_FEA_ROOT_KEY_HASH_WRITTEN` |
| 0 | 3 | `SEC_EFUSE_FEA_PUBLIC_ID_WRITTEN` |
| 0 | 4 | `SEC_EFUSE_FEA_DAK_WRITTEN` |
| 0 | 5 | `SEC_EFUSE_FEA_CRYPTO_HW_WRITTEN` |
| 0 | 6 | `SEC_EFUSE_FEA_SEC_GEN_WRITTEN` |
| 0 | 7 | `SEC_EFUSE_FEA_SEC_BOOT_ENABLED` |
| 1 | 0 | `SEC_EFUSE_FEA_OEM_ID_DISABLED` |
| 1 | 1 | `SEC_EFUSE_FEA_DEBUG_DISABLED` |
| 1 | 2 | `SEC_EFUSE_FEA_FAST_BOOT_ENABLED` |
| 1 | 3 | `SEC_EFUSE_FEA_SPDM_SEC_MODE` |
| 1 | 4 | `SEC_EFUSE_FEA_RPM_WDOG_ENABLED` |
| 1 | 5 | `SEC_EFUSE_FEA_SSM_ENABLED` |
| 1 | 6 | `SEC_EFUSE_FEA_FFU_VERIFY_ENABLED` |

The data of `PA_OTP` function 26 is in TLV format: total length, then `{DWORD type; DWORD length; data}` (`sub_4120AC`).

### DPP item

Structure returned by [IOCTL 0x9C412494](#ioctl-0x9c412494--nokiasecdpplistitems), 308 bytes each. The names of the fields come from the log.

| Bytes | Comment |
|-------|---------|
| 000-12B | `DppItemName`: WCHAR[150], null-terminated |
| 12C-12F | `DppItemSize` (low part of `EndOfFile`) |
| 130-133 | `DppItemAttribute` (`FileAttributes`) |

---

### IOCTL 0x9C412404 — TerminalResponseSize

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x901 (2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Size of the terminal response | ≥ 17 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Type, at +20 of the PA input |
| 01-04 | ? | ? |
| 05-08 | ? | ? |
| 09-0C | ? | ? |
| 0D-10 | ? | ? |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |

`sub_40A1B0`: `PA_LABEL2` function 11.

---

### IOCTL 0x9C412408 — TerminalResponse

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x902 (2306) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Create the terminal response | ≥ 187 + n | ≥ m + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Type |
| 01-10 | ? | 4 DWORDs, as in [IOCTL 0x9C412404](#ioctl-0x9c412404--terminalresponsesize). Bit 3 of the byte at 10 selects the version 1 of the response |
| 11-98 | ? | 136 bytes |
| 99-9B | ? | Not used |
| 9C-9F | ? | m: maximum size of the response |
| A0-B3 | ? | 20 bytes, version 1 only |
| B4-B7 | ? | n |
| B8-.. | ? | n bytes, version 1 only |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |
| 04-.. | ? | Terminal response |

`sub_40A274`:

1. `ReadDakFromDpp`: reads `\nokia\certs\dak.bin`, which must have 32 bytes (else 0xC0000173). A missing file isn't an error (0xC0000034, 0xC000003A).
2. `DakImport`: `PA_OTP` function 28. PRET 3 is accepted.
3. `TerminalRespCreateVer0` (`sub_40A3B8`) or `TerminalRespCreateVer1` (`sub_40A4D0`): `PA_LABEL2` function 10. The version 1 adds at +0xC0 of the PA input a pointer to `{2, 20, 20 bytes, 1, n, n bytes}`.

---

### IOCTL 0x9C41240C — Software watchdog

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x903 (2307) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Software watchdog | ≥ 8 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Command, see below |
| 04-07 | ? | Not used |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Period in seconds. Only set by the command 0. Information = 4 for all the commands |

| Command | Function | Comment |
|---------|----------|---------|
| 0 | `SwdServiceStart` (`sub_41483C`) | Starts the timer. 0xC0000145 if not initialised, 0xC0000708 if already running |
| 1 | `SwdServiceStop` (`sub_414920`) | Stops the timer. 0xC0000145 if not initialised or not running |
| 2 | `sub_4146D8` | Initialises, see [Software watchdog](#software-watchdog). Does nothing while the timer is running |
| 3 | `SwdReset` (`call_tz_oem_wd_reset`) | Sends the TZ command 0x3F801, see [TrustZone calls](#trustzone-calls) |
| Others | | `STATUS_NOT_SUPPORTED` |

---

### IOCTL 0x9C412410 — NokiaSecSelfTestService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x904 (2308) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Result of the initialisation | ≥ 4 | ≥ 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | 0 = security, 1 = SIM lock |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 1 = success |
| 04-07 | ? | Result bits |

Other values: `STATUS_NOT_SUPPORTED`.

- 0: clears `.data:0x40FA0C` and **runs the initialisation thread function again** (`sub_4078E4`). Success = bits 0, 1 and 2 set (value 7), see [Start-up](#start-up).
- 1: `sub_40941C` sends the [SIM lock](#ioctl-0x9c412430--nokiasecsimlockservice) command 8 with 0xFF in the bytes 23, 24 and 26 to 34 of the input. Success = value 3: bit 0 = files loaded (`SimlockDataReadAll`), bit 1 = byte +790 of the PA result is 0.

---

### IOCTL 0x9C412414 — NokiaSecEfuseWrite

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x905 (2309) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write eFuses | ≥ n + 11 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Identifier |
| 04-07 | ? | n |
| 08-.. | ? | n bytes |

`sub_407F90`: TZ service 0xF000002A.

> [!NOTE]
> The writing of eFuses is definitive.

---

### IOCTL 0x9C412418 — RootKeyHashWrite

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x906 (2310) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write the root key hash | ≥ 36 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ? |
| 04-23 | ? | 32 bytes |

`sub_408498`: `PA_OTP` function 21.

---

### IOCTL 0x9C41241C — RootKeyHashRead

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x907 (2311) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read the root key hash | 0 | ≥ 32 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-1F | ? | Root key hash |

`sub_408544`: TZ service 0xF000000F.

---

### IOCTL 0x9C412420 — ChipSpecificDataWrite

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x908 (2312) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write the chip specific data | ≥ 116 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-73 | ? | Input of the PA |

`sub_408664`: `PA_OTP` function 23, then function 29 to get the DAK, which is written in `\nokia\certs\dak.bin` (`WriteDakToDpp`, `sub_408B6C`). If function 29 returns the PRET 3 or 15, the file isn't written and the IOCTL succeeds.

---

### IOCTL 0x9C412424 — ChipSpecificInfoRead

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x909 (2313) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read the chip specific info | 0 | ≥ 320 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ? |
| 04-07 | ? | ? |
| 08-27 | ? | 32 bytes |
| 28-3B | ? | 20 bytes |
| 3C-3F | ? | ? |
| 40-13F | ? | 256 bytes |

`sub_408764`: `PA_OTP` function 22.

---

### IOCTL 0x9C412428 — PublicIdRead

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x90A (2314) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read the public ID | 0 | ≥ 20 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-13 | ? | Public ID |

`sub_40883C`: TZ service 0xF0000007.

---

### IOCTL 0x9C41242C — NokiaSecRandomDataGetService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x90B (2315) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Random data | ≥ 4 | ≥ n + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-.. | ? | Random data |

`sub_408C58`: TZ service 0xF000000A.

---

### IOCTL 0x9C412430 — NokiaSecSimlockService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x90C (2316) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SIM lock | ≥ 148 | ≥ 208 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Command |
| 01-14 | ? | 20 bytes |
| 15 | ? | ? |
| 16-19 | ? | 4 bytes |
| 1A-1D | ? | ? |
| 1E-21 | ? | ? |
| 22 | ? | ? |
| 23 | ? | ? |
| 24-93 | ? | 112 bytes |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | NTSTATUS of the PA |
| 04 | ? | ? |
| 08 | ? | ? |
| 09 | ? | ? |
| 0B | ? | 1 = byte +790 of the PA result is 0 |
| 0C-0F | ? | HRET, overwrites the start of the next field |
| 10-13 | ? | PRET, same |
| 14-5B | ? | End of the 80 bytes of the PA result |
| 5C | ? | ? |
| 5D-CC | ? | 112 bytes |

`sub_409A00` builds a 988-byte input for `PA_SIMLOC30` function 1, with: the content of `unlock.bin`, `SimlockDataReadAll` (`sub_409690`, the files `lock`, `keys` and `sign`), and `SimlockDataReadImei` (`sub_409864`, the IMEI of the MODEM).  
Command 6: if the byte +788 of the result is 0 and the 147 bytes at +640 differ from the old `unlock.bin`, they are written in `C:\DPP\nokia\simlock\unlock.bin` (`sub_409968`).  
The IOCTL returns success as soon as the input is allocated: the status of the service is in the output buffer.

---

### IOCTL 0x9C412434 — SecProductionReq

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x90D (2317) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Production state | 0 | ≥ 1 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | 1 if `SEC_EFUSE_FEA_PRODUCTION_DONE` is set |

`sub_40895C`, see [eFuse security features](#efuse-security-features).

---

### IOCTL 0x9C412438 — NokiaSecSsmModemMode

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x90E (2318) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the SSM mode | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Mode |

See [SSM mode](#ssm-mode). No retry here.

---

### IOCTL 0x9C41243C — NokiaSecPvkAsedDecryptService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x90F (2319) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Decrypt with PVK | ≥ n + 7 | ≥ n |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-.. | ? | Encrypted data |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | n bytes of decrypted data |

`sub_407AB0`: `PA_PVK` function 1. The decryption is done in place.

---

### IOCTL 0x9C412440 — EsnInit

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x910 (2320) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ESN initialisation | 0 | 0 |

`sub_4071CC`: reads `C:\DPP\nokia\certs\npc` again, then `PA_ESN` function 17.

---

### IOCTL 0x9C412444 — NokiaSecEsnReadService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x911 (2321) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read the ESN | ≥ 8 | ≥ 32 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ? |
| 04-07 | ? | ? |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-1F | ? | ESN |

`sub_4072D0`: `PA_ESN` function 33.

---

### IOCTL 0x9C412448 — NokiaSecRdcImportService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x912 (2322) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| RDC import | 0 | 0 |

`sub_408D24`: reads `C:\DPP\nokia\certs\rdc` again, then TZ service 0xF0000011.

---

### IOCTL 0x9C41244C — NokiaSecRdPhoneReqService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x913 (2323) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| RD phone request ? | 0 | ≥ 1 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | RDC status |

`sub_408E7C`: TZ service 0xF000002B.

---

### IOCTL 0x9C412450 — NokiaSecRdcDebugInfoGetService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x914 (2324) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| RDC debug info | ≥ 4 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | 0 = HW debug bits, 1 = SW debug bits, 2 = security mode bits |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Bits |

TZ services 0xF0000018, 0xF000001D and 0xF000002C. Other values: `STATUS_NOT_SUPPORTED`.

---

### IOCTL 0x9C412454 — Set logging state

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x915 (2325) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the `Debug` value | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | New mask, see [Logging](#logging) |

`sub_4116E0`: `STATUS_NOT_SUPPORTED` if the bits 0 and 1 are both set. The value is saved in the registry.

---

### IOCTL 0x9C412458 — NokiaSecSdAuthInit

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x916 (2326) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SD authentication, step 1 | 0 | ≥ 40 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | ? | 4 DWORDs |
| 10-23 | ? | 20 bytes |
| 24 | ? | ? |
| 25-27 | 00 00 00 |  |

`sub_413D04`: `PA_SD` function 2. See [SD authentication](#sd-authentication).

---

### IOCTL 0x9C41245C — NokiaSecSdAuthenticate

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x917 (2327) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SD authentication, step 2 | ≥ 120 | ≥ 24 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | ? | 24 bytes |
| 18-77 | ? | 96 bytes |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | ? | 24 bytes |

`sub_413DF0`: `PA_SD` function 3.

---

### IOCTL 0x9C412460 — NokiaSecSdVerify

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x918 (2328) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SD authentication, step 3 | ≥ 24 | ≥ 1 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | ? | 24 bytes |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | B4 | 180: duration of the session in seconds |

`sub_413F18`: `PA_SD` function 4. Starts the session timer.

---

### IOCTL 0x9C412464 — NokiaSecSdStatus

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x919 (2329) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SD session status | 0 | ≥ 1 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Remaining time in seconds |

`sub_4140C8`.

---

### IOCTL 0x9C412468

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x91A (2330) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

Always returns `STATUS_NOT_SUPPORTED`.

---

### IOCTL 0x9C41246C — NokiaSecSvcTagLengthService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x91B (2331) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Service tag length | ≥ 4 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ? |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Length |

`sub_409EF8`: `PA_SVCTAG2` function 1.

---

### IOCTL 0x9C412470 — NokiaSecSvcTagService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x91C (2332) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Service tag | ≥ n + 11 | ≥ m + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-07 | ? | m |
| 08-.. | ? | n bytes |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |
| 04-.. | ? | Service tag |

`sub_409FA8`: `PA_SVCTAG2` function 2, with the serial number of `product.dat` in the input (`sub_40A0C0`).

---

### IOCTL 0x9C412474 — NokiaSecObcService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x91D (2333) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| OBC | ≥ n + 15 | ≥ m + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | PA selection, 0 to 7 (`SetObcPaSelection`, else `STATUS_NOT_SUPPORTED`) |
| 04-07 | ? | n |
| 08-0B | ? | m |
| 0C-.. | ? | n bytes |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |
| 04-.. | ? | Result |

`sub_407E10`: `PA_OBC` function 1.

---

### IOCTL 0x9C412478 — NokiaSecEfuseFinalize

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x91E (2334) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Finalize the eFuses | 0 | 0 |

`sub_401C6C`: `PA_OTP` function 24, with the bit 0 of the byte at +8 of the input set.

---

### IOCTL 0x9C41247C — NokiaSecSsdDecryptData

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x91F (2335) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SSD decrypt | ≥ n + 7 | ≥ n + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-.. | ? | Encrypted data |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |
| 04-.. | ? | Decrypted data |

`sub_409BE4`: `PA_SSD` function 1. The decryption is done in place.

---

### IOCTL 0x9C412480 — NokiaSecDppFileSize

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x920 (2336) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Size of a DPP file | ≥ 300 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-12B | ? | WCHAR[150] path, relative to `C:\DPP` |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |

`sub_405E40`.

---

### IOCTL 0x9C412484 — NokiaSecDppReadFile

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x921 (2337) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read a DPP file | ≥ 308 | ≥ n + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-12B | ? | WCHAR[150] path, relative to `C:\DPP` |
| 12C-12F | ? | Offset |
| 130-133 | ? | n |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-.. | ? | Data |

`sub_405F14`. `STATUS_INVALID_PARAMETER` if the file is too short.

---

### IOCTL 0x9C412488 — NokiaSecDppWriteFile

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x922 (2338) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write a DPP file | ≥ n + 311 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-12B | ? | WCHAR[150] path, relative to `C:\DPP`, must start with `\` |
| 12C-12F | ? | 1 = overwrite, 2 = append |
| 130-133 | ? | n |
| 134-.. | ? | Data |

`sub_405FC0`: `CreateDirPath` (`sub_406654`) creates the sub-directories, then `WriteFile` (`sub_406D50`).

---

### IOCTL 0x9C41248C — NokiaSecDppDeleteFile

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x923 (2339) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Delete a DPP file | ≥ 300 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-12B | ? | WCHAR[150] path, relative to `C:\DPP` |

`sub_406070`.

---

### IOCTL 0x9C412490 — NokiaSecDppListItemsSize

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x924 (2340) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Size of a DPP directory list | ≥ 300 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-12B | ? | WCHAR[150] path, relative to `C:\DPP` |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size of the list: 308 × number of items |

`sub_406108`.

---

### IOCTL 0x9C412494 — NokiaSecDppListItems

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x925 (2341) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| List a DPP directory | ≥ 304 | ≥ n + 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-12B | ? | WCHAR[150] path, relative to `C:\DPP` |
| 12C-12F | ? | n |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size of the list |
| 04-07 | ? | Number of items |
| 08-.. | ? | [DPP items](#dpp-item) |

`sub_4061E4` (`DppListItems`, `sub_406298`): one call of `ZwQueryDirectoryFile` (`FileBothDirectoryInformation`) with a 4096-byte buffer, so a long directory is cut.

> [!NOTE]
> The items are written without any check against `n`: the output buffer must have the size given by [IOCTL 0x9C412490](#ioctl-0x9c412490--nokiasecdpplistitemssize).

---

### IOCTL 0x9C412498 — NokiaSecMirlinkCheckAsedService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x926 (2342) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Mirlink check | ≥ n + 7 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-.. | ? | Data |

`sub_407C2C`: `PA_MIRLINK` function 1.

---

### IOCTL 0x9C41249C — NokiaSecMirlinkSignDigestService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x927 (2343) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Mirlink sign | ≥ n + 103 | ≥ m + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | ? |
| 02 | ? | ? |
| 03 | ? | ? |
| 04-07 | ? | ? |
| 08-47 | ? | 64 bytes |
| 48-5B | ? | 20 bytes |
| 5C-5F | ? | n |
| 60-63 | ? | m |
| 64-.. | ? | n bytes |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |
| 04-.. | ? | Signature |

`sub_407CF0`: `PA_MIRLINK` function 2.

---

### IOCTL 0x9C4124A0 — NokiaSecSdClose

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x928 (2344) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Close the SD session | 0 | 0 |

`sub_414124`: clears the remaining time and calls `NokiaSecSdAuthenticationReset`.

---

### IOCTL 0x9C4124A4 — NokiaSecGetFirmwareEnvVar

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x929 (2345) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read a UEFI variable | ≥ 100 | ≥ n + 11 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-4F | ? | WCHAR[40] variable name |
| 50-5F | ? | GUID of the vendor |
| 60-63 | ? | n |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |
| 04-07 | ? | Attributes |
| 08-.. | ? | Data |

`sub_40A6F0`: `ExGetFirmwareEnvironmentVariable`, for any variable.

---

### IOCTL 0x9C4124A8 — NokiaSecSetFirmwareEnvVar

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x92A (2346) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write a UEFI variable | ≥ n + 107 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-4F | ? | WCHAR[40] variable name |
| 50-5F | ? | GUID of the vendor |
| 60-63 | ? | n |
| 64-67 | ? | Attributes |
| 68-.. | ? | Data |

`sub_40A79C`: `ExSetFirmwareEnvironmentVariable`, for any variable.

---

### IOCTL 0x9C4124AC — SSM ready

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x92B (2347) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SSM state | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | 1 = the MODEM key exchange was seen by `NokiaSecSetSsmModemMode` |

`sub_413454`, see [SSM mode](#ssm-mode).

---

### IOCTL 0x9C4124B0 — NokiaSecGetSecReturnValues

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x92C (2348) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Last return values | 0 | ≥ 12 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | NTSTATUS of the last IOCTL |
| 04-07 | ? | Last HRET |
| 08-0B | ? | Last PRET |

`sub_411790`. The values are cleared after the read. This IOCTL doesn't change the saved status.

---

### IOCTL 0x9C4124B4 — NokiaSecBifAsedVerify

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x92D (2349) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| BIF verify | ≥ n + 7 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-.. | ? | Data |

`sub_404EA4`: `PA_BIF` function 1.

---

### IOCTL 0x9C4124B8 — NokiaSecRegWriteValue

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x92E (2350) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write a connectivity registry value | ≥ n + 11 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | 0 = `HideAPN`, 1 = `HideMMSAPN` |
| 04-07 | 04 00 00 00 | n, must be 4 |
| 08-0B | ? | Value |

`sub_413000`: creates the keys `Microsoft` and `Connectivity`, then writes the REG_DWORD value in `HKLM\Software\Microsoft\Connectivity\CellUXOEMConfigurable`. Other values: `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x9C4124BC — NokiaSecGetFirmwareEnvVarSize

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x92F (2351) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Size of a UEFI variable | ≥ 96 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-4F | ? | WCHAR[40] variable name |
| 50-5F | ? | GUID of the vendor |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |

`sub_40A640`: `ExGetFirmwareEnvironmentVariable` with a size of 0. `STATUS_BUFFER_TOO_SMALL` is the normal result, and it's returned as a success.

---

### IOCTL 0x9C4124C0 — NokiaSecCaSelftestDevCertService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x930 (2352) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Device certificate self test | ≥ n + 287 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-117 | ? | 280 bytes |
| 118-11B | ? | n |
| 11C-.. | ? | n bytes |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Result |

`sub_404F68`: `PA_CA` function 1.

---

### IOCTL 0x9C4124C4 — NokiaSecCaCheckAsedService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x931 (2353) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| CA check | ≥ n + 7 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-.. | ? | Data |

`sub_40504C`: `PA_CA` function 2.

---

### IOCTL 0x9C4124C8 — NokiaSecCaCreateCertService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x932 (2354) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Create a certificate | ≥ n + 27 | ≥ m + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ? |
| 04-07 | ? | ? |
| 08-0B | ? | ? |
| 0C-0F | ? | ? |
| 10-13 | ? | m |
| 14-17 | ? | n |
| 18-.. | ? | n bytes |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |
| 04-.. | ? | Certificate |

`sub_4051B0`: `PA_CA` function 17.

---

### IOCTL 0x9C4124CC — NokiaSecFeaSizeRead

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x933 (2355) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Size of the security features | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |

`sub_408380`: `PA_OTP` function 30.

---

### IOCTL 0x9C4124D0 — NokiaSecFeaRead

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x934 (2356) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read the security features | 0 | ≥ 12 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size |
| 04-0B | ? | [Security features](#efuse-security-features) |

`sub_408408`: `PA_OTP` function 30.

---

### IOCTL 0x9C4124D4 — NokiaSecCaCertLenService

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x935 (2357) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Certificate length | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Length |

`sub_405110`: `PA_CA` function 18.

---

### IOCTL 0x9C4124D8 — NokiaSecEfuseRead

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x936 (2358) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read eFuses | ≥ 8 | ≥ n + 7 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Identifier |
| 04-07 | ? | n |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | n |
| 04-.. | ? | Data |

`sub_40806C`: TZ service 0xF0000032.

---

### IOCTL 0x9C41258C — Get version

This IOCTL is processed by Nokia_sec_driver.sys

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x963 (2403) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Driver version | ≥ 4 | ≥ 40 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not used |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 06 00 00 00 | Major version |
| 04-07 | 26 00 00 00 | Minor version |
| 08-24 | `6.38.0.40844` | Version string, 29 bytes |

`sub_402D94`. The code isn't next to the other ones. The input buffer is required.

---

### internal IOCTL 0xC3514004

This IOCTL is sent by Nokia_sec_driver.sys to [qcscm8930.sys](./qcscm8930.md#internal-ioctl-0xc3514004--ioctl_internal_scm_control_class_syscall)

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x1 (1) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_SCM_CONTROL_CLASS_SYSCALL | \Device\SysEnv | 72 | 72 |

`sub_413260`, sent synchronously with the same buffer for the input and the output. The content is in [TrustZone calls](#trustzone-calls).

---

### IOCTL 0x80092440

This IOCTL is sent by Nokia_sec_driver.sys to [qcdiagcsi8930.sys](./qcdiagcsi8930.md#ioctl-0x80092440)

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x910 (2320) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Register client | \Device\DiagCSI | 16 | 256 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 |  |
| 04-07 | 00 00 00 00 | No event |
| 08-09 | 02 00 |  |
| 0A-0B | 07 00 |  |
| 0C-0F | 00 00 00 00 |  |

`DiagSendInit` (`sub_405458`), once. `DiagOpenTarget` (`sub_405590`) opens the device first.

---

### IOCTL 0x80092444

This IOCTL is sent by Nokia_sec_driver.sys to [qcdiagcsi8930.sys](./qcdiagcsi8930.md#ioctl-0x80092444)

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x911 (2321) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Send command, synchronous | \Device\DiagCSI | see below | 4096 |

`DiagSendCmd` (`sub_405708`). The request is created with `WdfRequestCreate` and sent with `WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`, without timeout.

EFS2 commands (DIAG subsystem 0x13), to read the mode file:  
| Function | Request | Size | Response |
|----------|---------|------|----------|
| `sub_4059B8` open | `4B 13 02 00`, 8 null bytes, path | 76 | +4 handle, +8 error |
| `sub_405C04` read | `4B 13 04 00`, handle, 4, offset 0 | 16 | +0C bytes read, +10 error, +14 data |
| `sub_405AF8` close | `4B 13 03 00`, handle | 8 | +4 error |

The response must start with 0x4B. The error -2 (open) means the file doesn't exist.

NV read (DIAG subsystem 0x30), IMEI: `4B 30 01 00 26 02 00 00` + 130 null bytes (138 bytes). The response must start with 0x4B, the word at +0x88 must be 0, and the 8 bytes at +9 are copied.

---

### IOCTL 0x80092408

This IOCTL is sent by Nokia_sec_driver.sys to [qcssm8930.sys](./qcssm8930.md#ioctl-0x80092408)

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x902 (2306) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get the key exchange state | \Device\SSM | 128 | 128 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 1 = the MODEM key exchange succeeded |

`NokiaSecSendSsm` (`sub_413BBC`), same buffer for the input and the output.

---

### IOCTL 0x80092414

This IOCTL is sent by Nokia_sec_driver.sys to [qcssm8930.sys](./qcssm8930.md#ioctl-0x80092414)

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x905 (2309) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Mode update from the caller | \Device\SSM | n | n |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | Mode update message, from `PA_OTP` function 27. See [SSM mode](#ssm-mode) |

`NokiaSecSendSsm`, same buffer for the input and the output. n = size returned by the TrustZone.

---

### IOCTL 0x8009241C

This IOCTL is sent by Nokia_sec_driver.sys to [qcssm8930.sys](./qcssm8930.md#ioctl-0x8009241c)

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x907 (2311) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set the default mode | \Device\SSM | n | n |

`NokiaSecSendSsm` for the mode 8. Same buffer as [IOCTL 0x80092414](#ioctl-0x80092414), although qcssm8930.sys doesn't need it.
