## npetsec.dll

Nokia's user-mode security library (version string `6.38.0.40844`, the same as [Nokia_sec_driver.sys](../drivers/nokia_sec_driver.md)): the C API (`NPETSEC_*`) the production and service tools use for the phone identity, the secure storage and the modem.  
`npetsec.dll` is a C++ library (218 528 bytes, 395 functions, about a third of them CRT/STL and exception code). It doesn't contain any security logic: almost every export becomes one or more IOCTLs to the Nokia security driver `\\.\NokiaSec` ([Nokia_sec_driver.sys](../drivers/nokia_sec_driver.md)), which forwards them to the TrustZone. The DLL adds the parameter checks, the buffer packing, the [authorisation check](#dpp-authorisation) of the DPP writes, and an error/log layer. The second half of the library is a Qualcomm DIAG client on `\\.\DiagCSI` ([qcdiagcsi8930.sys](../drivers/qcdiagcsi8930.md)): modem NV items, modem EFS files, SPC unlock, modem reset and the IMEI/MEID provisioning. A few exports also read the battery level, the SSD partition, the UEFI secure boot variables and reboot the phone.  
It's imported by [Ncsd.dll](./ncsd.md) (37 of the 102 exports, through its `CNpetsec` wrapper), the JSON-RPC back end of the PC tools service [ncsdsvc.exe](../applications/ncsdsvc.md). The other exports (eFuse burning, certificate import, DPP initialisation, SuperDongle, SSD keys) are for the production line tools; their callers aren't in the documented binaries. The PDB path is `c:\wa\git\wp_security_rg3\driver\ARM\Release\npetsec.pdb` (same repository as the driver).

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileA`, `CreateFileW`, `ReadFile`, `WriteFile`, `GetFileSize`, `SetFilePointer`, `SetFilePointerEx`, `FlushFileBuffers`, `DeleteFileA`, `CreateDirectoryA`, `FindFirstFileA`, `FindNextFileA`, `FindClose`, `GetVolumeNameForVolumeMountPointW` |
| api-ms-win-devices-config-l1-1-1.dll | `CM_Get_Device_Interface_List_SizeW`, `CM_Get_Device_Interface_ListW` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateMutexA`, `ReleaseMutex`, `CreateEventA`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `WaitForMultipleObjectsEx`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `GetCurrentProcess`, `OpenProcessToken`, `GetCurrentProcessId`, `GetCurrentThreadId` |
| api-ms-win-security-lsalookup-l2-1-1.dll | `LookupPrivilegeValueW` |
| api-ms-win-security-base-l1-2-0.dll | `AdjustTokenPrivileges` |
| api-ms-win-core-shutdown-l1-1-1.dll | `InitiateSystemShutdownExW` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExA`, `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `DisableThreadLibraryCalls` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetSystemTimeAsFileTime`, `GetTickCount64` |
| api-ms-win-core-timezone-l1-1-0.dll | `FileTimeToSystemTime` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| MSVCR120.dll | `_fsopen`, `fprintf`, `vfprintf`, `fread`, `fwrite`, `fseek`, `ftell`, `fflush`, `fclose`, `_chsize`, `_fileno`, `__iob_func`, `strstr`, `_strdup`, `memcpy_s`, `strcpy_s`, `strncpy_s`, `wcscpy_s`, `sprintf_s`, `vsprintf_s`, `_wassert`, `_CxxThrowException`, `__CxxFrameHandler3`, … |
| MSVCP120.dll | `std::_Xbad_alloc`, `std::_Xlength_error`, `std::_Xout_of_range`, `std::_Winerror_map`, `std::_Syserror_map` |

The util, profile, part of the sysinfo and processthreads imports, and most of MSVCR120/MSVCP120 are the DLL CRT startup, the `/GS` cookie, C++ exceptions and `std::string`/`std::list`. The `f*` functions write the [log file](#logging).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\\.\NokiaSec` ([Nokia_sec_driver.sys](../drivers/nokia_sec_driver.md)) | `CreateFileA` (`GENERIC_READ`, no sharing) in `NPETSEC_Init` | Every security operation, see [IOCTLs to the security driver](#ioctls-to-the-security-driver) |
| `\\.\DiagCSI` ([qcdiagcsi8930.sys](../drivers/qcdiagcsi8930.md)) | `CreateFileW` (`GENERIC_READ`, `FILE_SHARE_READ`), opened on first use | Modem DIAG commands, see [DIAG client](#diag-client) |
| `\\.\QCOM_XoAdc` ([qcxoadc8930.sys](../drivers/qcxoadc8930.md)) | `CreateFileW` | `BATT_ID` channel, see [Battery level](#battery-level) |
| Battery interface `{72631E54-78A4-11D0-BCF7-00AA00B7B32A}` (`GUID_DEVICE_BATTERY`) or [qcbms8930.sys](../drivers/qcbms8930.md) interface `{23B7D0DD-101F-4EFE-A4D4-BED70E754419}` | `CM_Get_Device_Interface_ListW` + `CreateFileW` | [Battery level](#battery-level) |
| `\\.\PhysicalDrive0` … `\\.\PhysicalDrive5` | `CreateFileW`, `IOCTL_DISK_GET_DRIVE_LAYOUT_EX` (0x70050), `ReadFile` | Hash of the SSD partition, see [SSD](#ssd) |
| `C:\EFIESP\`, `C:\DPP\`, `C:\Data\`, `\\.\C:` | `GetVolumeNameForVolumeMountPointW`, `CreateFileW`, `FlushFileBuffers` | Volumes flushed before a reboot |
| [ShellChromeAPI.dll](./shellchromeapi.md) | `LoadLibraryExA("shellchromeapi.dll", NULL, 0x10)` (`LOAD_IGNORE_CODE_AUTHZ_LEVEL`), `GetProcAddress("Shell_RequestShutdown")` | Reboot method 2, see [RebootDevice](#npetsec_rebootdevice) |
| `c:\windows\system32\BinaryPartitionDecrypt.dll` (not analysed) | `LoadLibraryExW`, `GetProcAddress`: `BinaryPartitionDecrypt_Init`, `_DeInit`, `_ProvisionKeyStore`, `_DecryptData` | `NPETSEC_ProvisionQcSsdKeyStore` |
| `C:\efiesp\nokia_uefi_start_flag.txt` | `CreateFileA` (`CREATE_ALWAYS`), `WriteFile` (1 character) | Boot mode hint, see [RebootDevice](#npetsec_rebootdevice) |
| `C:\efiesp\Nokia\Security\<file>` (`Nokia_Production_PK.bin`, `Nokia_RD_PK.bin`, `KEK.bin`, `production_db.bin`, `rd_db.bin`, `dbx.bin`, `SecureBootPolicy.p7b`, `SecureBootPolicy_test.p7b`) | `CreateFileA` read; written by `NPETSEC_UefiCertificatesAsedImport` (`CreateDirectoryA` of `C:\efiesp\Nokia` and `C:\efiesp\Nokia\Security`) | [UEFI certificates](#uefi-certificates) |
| `\windows\system32\LabelingCA_cert.der` | `CreateFileA`, `ReadFile` | Public key used by `NPETSEC_DeviceCertSelfTest` |
| `C:\Programs\CommonFiles\OEM\Public\Security\mirlink_subca.bin` | `CreateFileA`, `ReadFile` | MirrorLink sub-CA, see [MirrorLink](#mirrorlink) |
| `C:\DPP\NOKIA\CERTS\NPC` | `CreateFileA`, `ReadFile` | IDs read before production is done, see [Identity](#identity) |
| Security logs `C:\Data\SharedData\OEM\Public\nokia_sec_driver_log.txt`, `C:\Data\SharedData\Oem\Public\nvupdater.log`, `C:\Data\SharedData\OEM\Public\simlock.log`, `C:\Data\Users\Public\Documents\nokia_sec_driver_log.txt` | `CreateFileA`, `ReadFile`, `DeleteFileA` | [Security logs](#security-logs) |
| Files of the DPP partition (`\Nokia\…`, `\QCOM\…`, `\Microsoft\Microsoft.PVK`) | Driver file IOCTLs (not opened directly) | [DPP items](#dpp-items) |
| Log file given to `NPETSEC_Init` | `_fsopen` (`r+`, else `w+`) | [Logging](#logging) |

No COM server, no RPC, no ETW, no WNF, no registry access (the registry writes go through the driver, [IOCTL 0x9C4124B8](../drivers/nokia_sec_driver.md#ioctl-0x9c4124b8--nokiasecregwritevalue)).

### Exports

All the exports return a DWORD error code, 0 on success (see [Errors](#errors)), except `NPETSEC_ReadVersion`, `NPETSEC_LastError`, `NPETSEC_LastErrorStr` and `NPETSEC_Deinit`. Each export resets the last error to 0 / `"Success"`, checks its pointers (error 30002 `"<name> is null."`) and most check that `NPETSEC_Init` was called (20008 `"Library Init() not called."`).

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 34 | `NPETSEC_Init` | 0x10008060 | `const char *logFile` (may be NULL) |
| 35 | `NPETSEC_InitSuppressedLogging` | 0x10008080 | `const char *logFile` |
| 3 | `NPETSEC_Deinit` | 0x10008090 | none |
| 80 | `NPETSEC_ReadVersion` | 0x10007EFC | none, returns `"6.38.0.40844"` |
| 38 | `NPETSEC_LastError` | 0x10008134 | none, returns the last error code |
| 39 | `NPETSEC_LastErrorStr` | 0x10008148 | none, returns the last error message (`char[200]`) |
| 89 | `NPETSEC_SetVerboseLogging` | 0x1000C004 | `BOOL verbose` |
| 85 | `NPETSEC_SetDriverLogging` | 0x1000C3AC | `DWORD state` |
| 68 | `NPETSEC_ReadImeiRaw` | 0x1000815C | `BYTE imei[8]` |
| 69 | `NPETSEC_ReadImeiStr` | 0x10008288 | `char imei[16]` |
| 71 | `NPETSEC_ReadMeidRaw` | 0x10008370 | `BYTE meid[8]` |
| 72 | `NPETSEC_ReadMeidStr` | 0x1000849C | `char meid[15]` |
| 66 | `NPETSEC_ReadBtId` | 0x10008590 | `BYTE address[6]` |
| 81 | `NPETSEC_ReadWlanId` | 0x100086C0 | `DWORD index` (0…3), `BYTE address[6]` |
| 74 | `NPETSEC_ReadPublicId` | 0x10008814 | `BYTE publicId[20]` |
| 79 | `NPETSEC_ReadServiceTagSize` | 0x10008910 | `? a1`, `DWORD *length` |
| 78 | `NPETSEC_ReadServiceTag` | 0x10008A3C | `const void *backEndData`, `DWORD length`, `void *serviceTag`, `DWORD *serviceTagLength` |
| 40 | `NPETSEC_ObcRequest` | 0x10008B90 | `DWORD pa` (0…7), `const void *dataIn`, `DWORD dataInLength`, `void *response`, `DWORD *responseLength` |
| 15 | `NPETSEC_DppItemWrite` | 0x10008D24 | `DWORD item`, `const void *content`, `DWORD size` |
| 11 | `NPETSEC_DppItemAppend` | 0x10008E88 | `DWORD item`, `const void *content`, `DWORD size` |
| 14 | `NPETSEC_DppItemSize` | 0x10008FE8 | `DWORD item`, `DWORD *size` |
| 13 | `NPETSEC_DppItemRead` | 0x10009118 | `DWORD item`, `DWORD offset`, `void *content`, `DWORD size` |
| 12 | `NPETSEC_DppItemDelete` | 0x1000927C | `DWORD item` |
| 10 | `NPETSEC_DppInitialize` | 0x100093AC | `const char *sourcePath`, `DWORD *copyCount` |
| 62 | `NPETSEC_QcNvSpcUnlock` | 0x100094DC | `const char *code` (6 digits) |
| 61 | `NPETSEC_QcNvItemWrite` | 0x1000960C | `DWORD itemId`, `DWORD contextId`, `const BYTE *data`, `DWORD length` |
| 60 | `NPETSEC_QcNvItemRead` | 0x10009720 | `DWORD itemId`, `DWORD contextId`, `BYTE *data`, `DWORD *length` |
| 59 | `NPETSEC_QcNvItemIndexedRead` | 0x1000986C | `DWORD itemId`, `DWORD contextId`, `BYTE index`, `BYTE *data`, `DWORD *length` |
| 54 | `NPETSEC_QcEfsFileWrite` | 0x100099BC | `const char *fileName`, `const void *data`, `DWORD length` |
| 53 | `NPETSEC_QcEfsFileRead` | 0x10009B08 | `const char *fileName`, `void *data`, `DWORD *length` |
| 57 | `NPETSEC_QcEfsItemFileWrite` | 0x10009C1C | `const char *fileName`, `const void *data`, `DWORD length` |
| 56 | `NPETSEC_QcEfsItemFileRead` | 0x10009D54 | `const char *fileName`, `void *data`, `DWORD *length` |
| 51 | `NPETSEC_QcEfsDataFileWrite` | 0x10009E68 | `const char *fileName`, `const void *data`, `DWORD length` |
| 50 | `NPETSEC_QcEfsDataFileRead` | 0x10009FA0 | `const char *fileName`, `void *data`, `DWORD *length` |
| 55 | `NPETSEC_QcEfsGetFileSize` | 0x1000A0B4 | `const char *fileName`, `DWORD *size` |
| 52 | `NPETSEC_QcEfsFileDelete` | 0x1000A1E4 | `const char *fileName` |
| 58 | `NPETSEC_QcModemModeSet` | 0x1000FD68 | `DWORD mode` |
| 63 | `NPETSEC_QcWaitForModemReady` | 0x100104F8 | `DWORD timeoutMs` |
| 36 | `NPETSEC_InitializeQcGoldenCopy` | 0x1000F7C8 | none |
| 88 | `NPETSEC_SetSecurityMode` | 0x1000A2E4 | `DWORD mode` |
| 23 | `NPETSEC_GetSecurityMode` | 0x1000A4B0 | `DWORD *mode` |
| 37 | `NPETSEC_IsProductionDone` | 0x1000BA54 | `BOOL *state` |
| 33 | `NPETSEC_ImportRdCertificate` | 0x1000A664 | `const void *cert`, `DWORD size` |
| 29 | `NPETSEC_ImportHwCertificate` | 0x1000A768 | `const void *cert`, `DWORD size` |
| 28 | `NPETSEC_ImportCcCertificate` | 0x1000A86C | `const void *cert`, `DWORD size` |
| 31 | `NPETSEC_ImportNpCertificate` | 0x1000AC4C | `const void *cert`, `DWORD size` |
| 4 | `NPETSEC_DeleteRdCertificate` | 0x1000A970 | none |
| 65 | `NPETSEC_RdcPhoneReq` | 0x1000AA44 | `BOOL *isRdPhone` |
| 64 | `NPETSEC_RdcDebugInfoGet` | 0x1000AB48 | `DWORD selection`, `void *debugInfo` |
| 90 | `NPETSEC_SuperDongleAuthInit` | 0x1000AD50 | `void **response`, `DWORD *responseLength` |
| 91 | `NPETSEC_SuperDongleAuthenticate` | 0x1000AE80 | `const void *request`, `DWORD length`, `void **response`, `DWORD *responseLength` |
| 97 | `NPETSEC_SuperDongleVerify` | 0x1000AFA4 | `const void *request`, `DWORD length`, `void **response`, `DWORD *responseLength` |
| 96 | `NPETSEC_SuperDongleStatus` | 0x1000B0C8 | `void **response`, `DWORD *responseLength` |
| 95 | `NPETSEC_SuperDongleReleaseResponse` | 0x1000B1F8 | `void *response` (`delete[]`) |
| 92 | `NPETSEC_SuperDongleCloseTunnel` | 0x1000B2F8 | none |
| 93 | `NPETSEC_SuperDongleGetSessionTimeout` | 0x1000B3CC | `DWORD *timeout` |
| 94 | `NPETSEC_SuperDongleProvisionAsedKeys` | 0x1000B4D0 | `const void *ased`, `DWORD size` |
| 19 | `NPETSEC_GetProductionData` | 0x1000B5D4 | `DWORD id` (0…6), `char value[100]` ? |
| 86 | `NPETSEC_SetProductionData` | 0x1000B798 | `DWORD id`, `const char *value` |
| 87 | `NPETSEC_SetProductionDataUnchecked` | 0x1000B8E8 | `DWORD id`, `const char *value` |
| 82 | `NPETSEC_RebootDevice` | 0x1000BB58 | `DWORD mode`, `DWORD method` |
| 18 | `NPETSEC_GetMirLinkSignDigestResultSize` | 0x1000BC94 | 6 × ? (not used), `DWORD *size` |
| 17 | `NPETSEC_GetMirLinkSignDigestResult` | 0x1000BDA4 | 6 × ?, `void *result`, `DWORD *resultSize` |
| 24 | `NPETSEC_GetSimlockStatus` | 0x1000BF00 | `void *simlockStatus` |
| 22 | `NPETSEC_GetSecurityLogFileSize` | 0x1000C04C | `DWORD logId`, `DWORD *size` |
| 77 | `NPETSEC_ReadSecurityLogFile` | 0x1000C16C | `DWORD logId`, `void *buffer`, `DWORD *size`, `DWORD offset`, `BOOL *eof` |
| 5 | `NPETSEC_DeleteSecurityLogFile` | 0x1000C2BC | `DWORD logId` |
| 100 | `NPETSEC_ValidateSsdHash` | 0x1000C64C | `BOOL *valid` |
| 49 | `NPETSEC_ProvisionSsdHash` | 0x1000FC0C | none |
| 48 | `NPETSEC_ProvisionQcSsdKeyStore` | 0x1000F894 | `const void *data`, `DWORD size` |
| 2 | `NPETSEC_DecryptDeviceSwKeysAsed` | 0x1000DE78 | `const void *in`, `DWORD inLength`, `void *out`, `DWORD *outLength` |
| 42 | `NPETSEC_PermanentDataItemSize` | 0x1000C7A8 | `DWORD id` (0), `DWORD *size` (always 20) |
| 41 | `NPETSEC_PermanentDataItemRead` | 0x1000C8E4 | `DWORD id`, `void *data`, `DWORD *size` |
| 43 | `NPETSEC_PermanentDataItemWrite` | 0x1000CA1C | `DWORD id`, `const void *data`, `DWORD size` |
| 83 | `NPETSEC_RegItemValueWrite` | 0x1000CB28 | `DWORD item` (0, 1), `const void *data`, `DWORD size` |
| 76 | `NPETSEC_ReadSecFeaSize` | 0x1000CC5C | `DWORD *secFeaLength` |
| 75 | `NPETSEC_ReadSecFea` | 0x1000CD84 | `BYTE *secFea`, `DWORD *secFeaLength` |
| 70 | `NPETSEC_ReadManufacturingData` | 0x1000CEA0 | `BYTE data[500]` |
| 101 | `NPETSEC_WriteManufacturingData` | 0x1000F95C | `const BYTE data[500]` |
| 27 | `NPETSEC_GetUefiCertStates` | 0x1000D188 | `DWORD states[5]` |
| 99 | `NPETSEC_UefiCertificatesAsedImport` | 0x1000FFEC | `const void *data`, `DWORD size` |
| 7 | `NPETSEC_DeviceCertCaCertSize` | 0x1000D260 | `DWORD *size` |
| 6 | `NPETSEC_DeviceCertCaCertCreate` | 0x1000D338 | 5 × ?, `DWORD *size` |
| 8 | `NPETSEC_DeviceCertImport` | 0x1000FE38 | `const void *ased`, `DWORD size` |
| 9 | `NPETSEC_DeviceCertSelfTest` | 0x1000FF14 | `DWORD *status` |
| 21 | `NPETSEC_GetRemainingBatteryLevel` | 0x1000D430 | `DWORD *level` (%) |
| 20 | `NPETSEC_GetRandomData` | 0x1000DD04 | `void *buffer`, `DWORD length` |
| 26 | `NPETSEC_GetTerminalResponseSize` | 0x1000D994 | `BYTE type`, `const BYTE in[16]`, `DWORD *size` |
| 25 | `NPETSEC_GetTerminalResponse` | 0x1000DB00 | `BYTE type`, `const BYTE in[16]`, `const BYTE challenge[136]`, `void *response`, `DWORD *responseLength` |
| 98 | `NPETSEC_Swd` | 0x1000E1E4 | `DWORD command`, `DWORD *result` |
| 32 | `NPETSEC_ImportPVKAsed` | 0x1000E358 | `const void *ased`, `DWORD size` |
| 30 | `NPETSEC_ImportMirlinkAsed` | 0x1000E79C | `const void *ased`, `DWORD size` |
| 47 | `NPETSEC_PermanentlyBurnRootKeyHash` | 0x1000EB3C | `const BYTE *hash`, `DWORD length` (32) |
| 44 | `NPETSEC_PermanentlyBurnChipSpecificData` | 0x1000ECB8 | `const BYTE *data`, `DWORD length` (≤ 116) |
| 45 | `NPETSEC_PermanentlyBurnEfuseMode` | 0x1000EE24 | `DWORD mode` (0, 1, 2) |
| 46 | `NPETSEC_PermanentlyBurnFinalConfig` | 0x1000EF84 | none |
| 67 | `NPETSEC_ReadChipSpecificData` | 0x1000F21C | `BYTE data[320]` |
| 84 | `NPETSEC_SecuritySelftest` | 0x1000F334 | `WORD result[4]`, `BOOL *ok` |
| 102 | `NPETSEC_WritePsnEfuse` | 0x100100C8 | `const char *psn` (< 15 characters) |
| 73 | `NPETSEC_ReadPsnEfuse` | 0x1001021C | `char *psn`, `DWORD size` |
| 16 | `NPETSEC_GetFfuConfigOptions` | 0x100105CC | `BOOL *writeNviFull` |
| 1 | `NPETSEC_ClearFfuConfigOptions` | 0x100106FC | ? |

The global state:

| Address | Size | Comment |
|---------|------|---------|
| `dword_100312A4` | 4 | `NPETSEC_Init` reference count. Only the first call initialises, `NPETSEC_Deinit` releases at 0 |
| `dword_100312A8` | 4 | Service object (`operator new(0x18)`, vtable `off_10022D80`): +0x04 log tag `"NokiaSecService"`, +0x08 current security mode, +0x14 handle of `\\.\NokiaSec`. NULL before `NPETSEC_Init` |
| `dword_100312BC` | 4 | DIAG object (0x20 bytes, `sub_1001B15C`), created on first use, see [DIAG client](#diag-client) |
| `dword_100312AC`, `byte_100312F8` | 4, 200 | Last error code and message |
| `dword_100312B4`, `dword_100312B8` | 4, 4 | Log file path (`_strdup`) and log level mask |
| `dword_100312B0` | 4 | Handle of the `NokiaSecDebug` mutex of the log file |
| `dword_10031018` | 4 | Console log mask (0: nothing on stdout) |

### Startup

`DllEntryPoint` (`_DllMainCRTStartup`, 0x1001D658): `__security_init_cookie`, then `dllmain_dispatch` (CRT init). There's no ETW provider and nothing else at load.

### NPETSEC_Init (sub_10007F10)

`NPETSEC_Init(logFile)` = `sub_10007F10(logFile, 0)`, `NPETSEC_InitSuppressedLogging(logFile)` = `sub_10007F10(logFile, 1)`:

1. Increments the reference count; only the first call goes on.
2. If `logFile` isn't NULL, keeps a copy of the path and sets the log mask: 0xFFFFFFEF (everything but bit 4) normally, 0x22 with the suppressed logging.
3. Creates the service object and opens the driver (`sub_10017874` → `sub_10017F0C`): `CreateFileA("\\\\.\\NokiaSec", GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL)`. On failure it logs "Unable create pipe 0x%x." and throws the error 102; the export frees the object and returns the error with "Instantiating service object failed.".

`NPETSEC_Deinit` decrements the count; at 0 it closes the driver handle ("Driver pipe closed."), deletes the service object, frees the log path and stops the [DIAG client](#diag-client) (`sub_1001B4BC`).

### Logging

`sub_10017554(tag, level, format, …)` writes `"<tag>: <message>"` lines; `sub_10017764` writes a hex dump (level 8) of the buffers exchanged with the driver. A line is written when `level & mask` is set. The levels used are 1 (important steps), 2 (errors), 4 (trace) and 8 (dumps). `NPETSEC_SetVerboseLogging(TRUE)` sets the mask to 0xFFFFFFEF, `FALSE` to 2 (errors only).  
The file is opened for every line (`_fsopen` `r+`, else `w+`), under the named mutex `NokiaSecDebug`. Each line starts with a timestamp `hh:mm:ss.mmm`. When the file is over 3 MiB (0x300000), its last 1.5 MiB are moved to the start, the file is truncated and the line "**** Log split point (%d bytes) ****" is written.

`NPETSEC_SetDriverLogging(state)` is different: it sends `state` (4 bytes) to the driver with [IOCTL 0x9C412454](../drivers/nokia_sec_driver.md#ioctl-0x9c412454--set-logging-state).

### Errors

The functions throw C++ exceptions (`NokiaSec::Error`: code + message, logged as "Exception thrown: %d: %hs"); each export catches them, stores the code and the message (`sub_10007EB8`) for `NPETSEC_LastError` / `NPETSEC_LastErrorStr`, and returns the code.

| Code | Meaning |
|------|---------|
| 102 | `\\.\NokiaSec` can't be opened |
| 10001 | Internal: mutex, event or thread creation, wrong DPP file, invalid driver op |
| 20001 | "Unable to change mode; the modem mode did not change." |
| 20002 | "Modem SSM ready wait timeout." / "Unable to get security mode." |
| 20007 | Not authorised: "Production line or SD authentication or RDC required.", "This item cannot be directly written" |
| 20008 | "Library Init() not called." / "Sec driver might not been initialized" (`DeviceIoControl` failed with `ERROR_TIMEOUT` 1460) |
| 20010 | Buffer too small (`DeviceIoControl` failed with `ERROR_INSUFFICIENT_BUFFER` 122, or a size check) |
| 30002 | Invalid parameter |
| 30003 | MirrorLink sub-CA file can't be read |
| 50003 | `\\.\DiagCSI` can't be opened, or a DIAG IOCTL failed |
| 50007 | "QC modem did not become ready during wait timeout." |
| 50001…50007 (0xC351…0xC357) | DIAG errors (bad response, NV/EFS status) |
| 1000 − HRET | "Secure HAL layer error occurred" (HRET 0xFFFFxxxx) |
| 2000 + (HRET & 0xFF) | "Secure ISSW/Romlite layer error occurred" |
| 3000 + (HRET & 0xFF) | "Secure ISSW layer error occurred" (HRET 0x8004xxxx) |
| 5000 + PRET | "Secure PA layer error occurred" |
| 100000 + (NTSTATUS & 0xFFFF) | Driver error without HRET/PRET |

When a driver IOCTL fails with another error, `sub_1001790C` asks the driver for the details with [IOCTL 0x9C4124B0](../drivers/nokia_sec_driver.md#ioctl-0x9c4124b0--nokiasecgetsecreturnvalues) (12 bytes: NTSTATUS, HRET, PRET, logged as "NTSTATUS: %8.8x, HRET: %8.8x, PRET: %8.8x") and builds the code from them as in the table: HRET ≥ 2 first, then PRET ≥ 2, else the NTSTATUS.

### IOCTLs to the security driver

Every IOCTL is sent under the named mutex `NokiaSecDrvSvcLib` (`CreateMutexA` + `WaitForSingleObject(INFINITE)` around each `DeviceIoControl`), so the calls of all the processes using the library are serialised. Most functions call `DeviceIoControl` inline; `sub_10017AB4(service, op, in, inSize, out, outSize)` does the same from an op index: a switch maps the ops 0…53 to the codes 0x9C412404…0x9C4124D8 (not in order: op 9 = 0x9C412478, op 10 = 0x9C412410) and op 99 to 0x9C41258C. Only the ops 0, 1, 2, 3, 4, 6, 7 and 8 are used.

All the codes are `FILE_DEVICE` 0x9C41, `METHOD_BUFFERED`, `FILE_ANY_ACCESS`. The buffers are described on the [driver page](../drivers/nokia_sec_driver.md); the variable-size buffers start with a DWORD size, and the DLL allocates them with 7 extra bytes.

| IOCTL | Driver name | Sent by | Input given by the DLL |
|-------|-------------|---------|------------------------|
| [0x9C412404](../drivers/nokia_sec_driver.md#ioctl-0x9c412404--terminalresponsesize) | TerminalResponseSize | `NPETSEC_GetTerminalResponseSize` | 17 bytes: `type`, then the 16 bytes of `in`. Output: DWORD size |
| [0x9C412408](../drivers/nokia_sec_driver.md#ioctl-0x9c412408--terminalresponse) | TerminalResponse | `NPETSEC_GetTerminalResponse` | 0xBC bytes: `type`, 16 bytes, 136 bytes, the response size at +0x9C. Output: DWORD size + data |
| [0x9C41240C](../drivers/nokia_sec_driver.md#ioctl-0x9c41240c--software-watchdog) | Software watchdog | `NPETSEC_Swd`, `NPETSEC_RebootDevice` (method 3) | `{command, 0}`; the reboot sends command 3 (`SwdReset`). Output: DWORD |
| [0x9C412410](../drivers/nokia_sec_driver.md#ioctl-0x9c412410--nokiasecselftestservice) | NokiaSecSelfTestService | `NPETSEC_SecuritySelftest` | Sent twice, with 0 then 1. Output 8 bytes: status (1 = OK), two WORDs copied to `result[0..1]` then `result[2..3]` |
| [0x9C412414](../drivers/nokia_sec_driver.md#ioctl-0x9c412414--nokiasecefusewrite) | NokiaSecEfuseWrite | `NPETSEC_WritePsnEfuse`, `NPETSEC_PermanentlyBurnEfuseMode` | PSN: identifier 0x200, n = 16, the PSN string (27 bytes). Mode: identifier 4 (mode 0), 1 (mode 1) or 2 (mode 2), n = 0 (12 bytes) |
| [0x9C412418](../drivers/nokia_sec_driver.md#ioctl-0x9c412418--rootkeyhashwrite) | RootKeyHashWrite | `NPETSEC_PermanentlyBurnRootKeyHash` | 36 bytes: 0, then the 32-byte hash. Other lengths: "Unsupported length of root key hash." |
| [0x9C412420](../drivers/nokia_sec_driver.md#ioctl-0x9c412420--chipspecificdatawrite) | ChipSpecificDataWrite | `NPETSEC_PermanentlyBurnChipSpecificData` | 116 bytes, the data padded with zeros |
| [0x9C412424](../drivers/nokia_sec_driver.md#ioctl-0x9c412424--chipspecificinforead) | ChipSpecificInfoRead | `NPETSEC_ReadChipSpecificData` | None. Output 320 bytes, straight into the caller's buffer |
| [0x9C412428](../drivers/nokia_sec_driver.md#ioctl-0x9c412428--publicidread) | PublicIdRead | `NPETSEC_ReadPublicId` (`sub_10010AF8`) | None. Output 20 bytes |
| [0x9C41242C](../drivers/nokia_sec_driver.md#ioctl-0x9c41242c--nokiasecrandomdatagetservice) | NokiaSecRandomDataGetService | `NPETSEC_GetRandomData` (`sub_10012DCC`) | DWORD length. Output: DWORD size + data |
| [0x9C412430](../drivers/nokia_sec_driver.md#ioctl-0x9c412430--nokiasecsimlockservice) | NokiaSecSimlockService | `NPETSEC_GetSimlockStatus` (`sub_10014B18`) | 0x94 bytes, first DWORD = 11. Output 0xD0 bytes ("Unknown lock info response from secure driver." for an unexpected answer) |
| [0x9C412434](../drivers/nokia_sec_driver.md#ioctl-0x9c412434--secproductionreq) | SecProductionReq | `NPETSEC_IsProductionDone` (`sub_100058AC`), [DPP authorisation](#dpp-authorisation), [Identity](#identity) | None. Output 1 byte |
| [0x9C412438](../drivers/nokia_sec_driver.md#ioctl-0x9c412438--nokiasecssmmodemmode) | NokiaSecSsmModemMode | `NPETSEC_SetSecurityMode` | DWORD mode, see [Security mode](#security-mode) |
| [0x9C41243C](../drivers/nokia_sec_driver.md#ioctl-0x9c41243c--nokiasecpvkaseddecryptservice) | NokiaSecPvkAsedDecryptService | `NPETSEC_ImportPVKAsed` | DWORD size + ASED data. The decrypted output (big-endian offsets) gives the key written to the DPP item `\Microsoft\Microsoft.PVK` |
| [0x9C412440](../drivers/nokia_sec_driver.md#ioctl-0x9c412440--esninit) | EsnInit | `NPETSEC_ImportNpCertificate` (`sub_10007694`) | None, after writing `\Nokia\certs\npc` |
| [0x9C412444](../drivers/nokia_sec_driver.md#ioctl-0x9c412444--nokiasecesnreadservice) | NokiaSecEsnReadService | `sub_10006960`, see [Identity](#identity) | 8 bytes: the ESN name in ASCII (`"GSM"`, `"MEID"`, `"BT_ID"`, `"WLAN_ID"`, `"WLAN2ID"`, `"WLAN3ID"`, `"WLAN4ID"`), zero padded. Output 32 bytes |
| [0x9C412448](../drivers/nokia_sec_driver.md#ioctl-0x9c412448--nokiasecrdcimportservice) | NokiaSecRdcImportService | `NPETSEC_ImportRdCertificate` (`sub_10013218`) | None, after writing `\Nokia\certs\rdc` |
| [0x9C41244C](../drivers/nokia_sec_driver.md#ioctl-0x9c41244c--nokiasecrdphonereqservice) | NokiaSecRdPhoneReqService | `NPETSEC_RdcPhoneReq` (`sub_10013498`), [DPP authorisation](#dpp-authorisation) | None |
| [0x9C412450](../drivers/nokia_sec_driver.md#ioctl-0x9c412450--nokiasecrdcdebuginfogetservice) | NokiaSecRdcDebugInfoGetService | `NPETSEC_RdcDebugInfoGet` (`sub_100136A0`) | The selection ("Unsupported RDC info selection: %d" otherwise) |
| [0x9C412454](../drivers/nokia_sec_driver.md#ioctl-0x9c412454--set-logging-state) | Set logging state | `NPETSEC_SetDriverLogging` | DWORD state |
| [0x9C412458](../drivers/nokia_sec_driver.md#ioctl-0x9c412458--nokiasecsdauthinit) | NokiaSecSdAuthInit | `NPETSEC_SuperDongleAuthInit` (`sub_10014DB4`) | Response allocated by the DLL, freed with `NPETSEC_SuperDongleReleaseResponse` |
| [0x9C41245C](../drivers/nokia_sec_driver.md#ioctl-0x9c41245c--nokiasecsdauthenticate) | NokiaSecSdAuthenticate | `NPETSEC_SuperDongleAuthenticate` (`sub_10014FD0`) | The request, with the provisioned keys read from the DPP (`\Nokia\CERTS\superdongle_ased.bin`, else `\Nokia\superdongle_ased.bin`; length checked) |
| [0x9C412460](../drivers/nokia_sec_driver.md#ioctl-0x9c412460--nokiasecsdverify) | NokiaSecSdVerify | `NPETSEC_SuperDongleVerify` (`sub_100153F4`) | The request (size checked) |
| [0x9C412464](../drivers/nokia_sec_driver.md#ioctl-0x9c412464--nokiasecsdstatus) | NokiaSecSdStatus | `NPETSEC_SuperDongleStatus`, `NPETSEC_SuperDongleGetSessionTimeout`, [DPP authorisation](#dpp-authorisation) | None |
| [0x9C41246C](../drivers/nokia_sec_driver.md#ioctl-0x9c41246c--nokiasecsvctaglengthservice) | NokiaSecSvcTagLengthService | `NPETSEC_ReadServiceTagSize` (`sub_10014674`) | |
| [0x9C412470](../drivers/nokia_sec_driver.md#ioctl-0x9c412470--nokiasecsvctagservice) | NokiaSecSvcTagService | `NPETSEC_ReadServiceTag` (`sub_10014874`) | The back end data (challenge) |
| [0x9C412474](../drivers/nokia_sec_driver.md#ioctl-0x9c412474--nokiasecobcservice) | NokiaSecObcService | `NPETSEC_ObcRequest` (`sub_100107F8`) | `pa` (0…7), the input length, the response size, then the input (n + 15 bytes). Output: DWORD size + data |
| [0x9C412478](../drivers/nokia_sec_driver.md#ioctl-0x9c412478--nokiasecefusefinalize) | NokiaSecEfuseFinalize | `NPETSEC_PermanentlyBurnFinalConfig` | None |
| [0x9C41247C](../drivers/nokia_sec_driver.md#ioctl-0x9c41247c--nokiasecssddecryptdata) | NokiaSecSsdDecryptData | `NPETSEC_DecryptDeviceSwKeysAsed` | DWORD size + data; output of the same size ("Too small buffer for SSD payload.") |
| [0x9C412480](../drivers/nokia_sec_driver.md#ioctl-0x9c412480--nokiasecdppfilesize) | NokiaSecDppFileSize | `sub_10003A04` ([DPP items](#dpp-items)) | DPP path |
| [0x9C412484](../drivers/nokia_sec_driver.md#ioctl-0x9c412484--nokiasecdppreadfile) | NokiaSecDppReadFile | `sub_1000371C` | DPP path, offset, size |
| [0x9C412488](../drivers/nokia_sec_driver.md#ioctl-0x9c412488--nokiasecdppwritefile) | NokiaSecDppWriteFile | `sub_100030D0` (write), `sub_10003408` (append) | DPP path, data |
| [0x9C41248C](../drivers/nokia_sec_driver.md#ioctl-0x9c41248c--nokiasecdppdeletefile) | NokiaSecDppDeleteFile | `sub_10003C54` (with authorisation), `sub_10003F00` | DPP path |
| [0x9C412498](../drivers/nokia_sec_driver.md#ioctl-0x9c412498--nokiasecmirlinkcheckasedservice) | NokiaSecMirlinkCheckAsedService | `NPETSEC_ImportMirlinkAsed` | DWORD size + ASED; then written to `\Nokia\certs\mirlink.bin` |
| [0x9C41249C](../drivers/nokia_sec_driver.md#ioctl-0x9c41249c--nokiasecmirlinksigndigestservice) | NokiaSecMirlinkSignDigestService | `NPETSEC_GetMirLinkSignDigestResult` (`sub_100054AC`) | See [MirrorLink](#mirrorlink) |
| [0x9C4124A0](../drivers/nokia_sec_driver.md#ioctl-0x9c4124a0--nokiasecsdclose) | NokiaSecSdClose | `NPETSEC_SuperDongleCloseTunnel` (`sub_1001587C`) | None |
| [0x9C4124A4](../drivers/nokia_sec_driver.md#ioctl-0x9c4124a4--nokiasecgetfirmwareenvvar) | NokiaSecGetFirmwareEnvVar | [UEFI variables](#uefi-variables) | Name, vendor GUID, size |
| [0x9C4124A8](../drivers/nokia_sec_driver.md#ioctl-0x9c4124a8--nokiasecsetfirmwareenvvar) | NokiaSecSetFirmwareEnvVar | [UEFI variables](#uefi-variables) | Name, vendor GUID, size, attributes 7, data |
| [0x9C4124AC](../drivers/nokia_sec_driver.md#ioctl-0x9c4124ac--ssm-ready) | SSM ready | `sub_100066F4` ([Security mode](#security-mode)) | None. Output DWORD, 1 = ready |
| [0x9C4124B0](../drivers/nokia_sec_driver.md#ioctl-0x9c4124b0--nokiasecgetsecreturnvalues) | NokiaSecGetSecReturnValues | `sub_1001790C` ([Errors](#errors)) | None. Output 12 bytes |
| [0x9C4124B8](../drivers/nokia_sec_driver.md#ioctl-0x9c4124b8--nokiasecregwritevalue) | NokiaSecRegWriteValue | `NPETSEC_RegItemValueWrite` (`sub_1001441C`) | `item` (0 or 1, "Invalid registry item (%d) specified." otherwise), size, data |
| [0x9C4124BC](../drivers/nokia_sec_driver.md#ioctl-0x9c4124bc--nokiasecgetfirmwareenvvarsize) | NokiaSecGetFirmwareEnvVarSize | `sub_10015DA4` ([UEFI certificates](#uefi-certificates)) | Name, vendor GUID |
| [0x9C4124C0](../drivers/nokia_sec_driver.md#ioctl-0x9c4124c0--nokiaseccaselftestdevcertservice) | NokiaSecCaSelftestDevCertService | `NPETSEC_DeviceCertSelfTest` (`sub_1000281C`) | The devCA read from `\Nokia\certs\devcert.bin`, converted to an RSA public key (modulus as big integer) with the key of `LabelingCA_cert.der` |
| [0x9C4124C4](../drivers/nokia_sec_driver.md#ioctl-0x9c4124c4--nokiaseccacheckasedservice) | NokiaSecCaCheckAsedService | `NPETSEC_DeviceCertImport` (`sub_1000257C`) | DWORD size + ASED; then written to `\Nokia\certs\devcert.bin` |
| [0x9C4124C8](../drivers/nokia_sec_driver.md#ioctl-0x9c4124c8--nokiaseccacreatecertservice) | NokiaSecCaCreateCertService | `NPETSEC_DeviceCertCaCertCreate` (`sub_10002D84`) | With `\Nokia\certs\devcert.bin` |
| [0x9C4124CC](../drivers/nokia_sec_driver.md#ioctl-0x9c4124cc--nokiasecfeasizeread) | NokiaSecFeaSizeRead | `NPETSEC_ReadSecFeaSize` (`sub_10010B98`) | None |
| [0x9C4124D0](../drivers/nokia_sec_driver.md#ioctl-0x9c4124d0--nokiasecfearead) | NokiaSecFeaRead | `NPETSEC_ReadSecFea` (`sub_10010D94`) | None |
| [0x9C4124D4](../drivers/nokia_sec_driver.md#ioctl-0x9c4124d4--nokiaseccacertlenservice) | NokiaSecCaCertLenService | `NPETSEC_DeviceCertCaCertSize` (`sub_10002BF4`) | None |
| [0x9C4124D8](../drivers/nokia_sec_driver.md#ioctl-0x9c4124d8--nokiasecefuseread) | NokiaSecEfuseRead | `NPETSEC_ReadPsnEfuse` | `{0x200, 16}`; output 23 bytes, the PSN at +4 |
| [0x9C41258C](../drivers/nokia_sec_driver.md#ioctl-0x9c41258c--get-version) | Get version | op 99 of `sub_10017AB4` | No caller found |

The codes 0x9C412468, 0x9C412490, 0x9C412494 and 0x9C4124B4 are in the op table of `sub_10017AB4` but no function uses them.

### Identity

`NPETSEC_ReadImeiRaw`, `NPETSEC_ReadMeidRaw`, `NPETSEC_ReadBtId` and `NPETSEC_ReadWlanId` call `sub_10006E04(name, buffer)` with the ESN names `"GSM"`, `"MEID"`, `"BT_ID"`, `"WLAN_ID"`/`"WLAN2ID"`/`"WLAN3ID"`/`"WLAN4ID"` (index 0…3):

- Production done ([IOCTL 0x9C412434](../drivers/nokia_sec_driver.md#ioctl-0x9c412434--secproductionreq) returns 1): `sub_10006960` reads the 32-byte ESN from the TrustZone with [IOCTL 0x9C412444](../drivers/nokia_sec_driver.md#ioctl-0x9c412444--nokiasecesnreadservice) ("Requesting ESN securely '%s'").
- Otherwise: `sub_10006BA4` reads `C:\DPP\NOKIA\CERTS\NPC` and looks for the name in its ESN entries ("NPC has %d esn entries, total expected size %d bytes.").

The exports then copy 8 bytes (IMEI, MEID) or the 6 first bytes in reverse order (BT and WLAN addresses). `NPETSEC_ReadImeiStr` turns the raw IMEI (BCD) into 15 digits: the high nibble of byte 0, then low and high nibbles of bytes 1…7. `NPETSEC_ReadMeidStr` writes the 7 first bytes as 14 lowercase hex digits.

`NPETSEC_ImportNpCertificate` (`sub_10007920`) keeps the current `\Nokia\certs\npc`, writes the new one and sends [IOCTL 0x9C412440](../drivers/nokia_sec_driver.md#ioctl-0x9c412440--esninit) (`sub_10007694`); if that fails it restores the previous certificate. Then `sub_10007030` provisions the identifiers in the modem and the connectivity files:

1. BT_ID → DPP `\QCOM\BT.Provision`, WLAN_ID, WLAN2ID, WLAN3ID, WLAN4ID → DPP `\QCOM\WLAN.Provision` (`sub_10006EA4`, `sub_10006F60`, with the [DPP authorisation](#dpp-authorisation)).
2. GSM → modem NV item 550 (0x226, IMEI) with the DIAG NV write (`sub_1001ABC4`), MEID → NV item 1943 (0x797, `sub_1001A744`). If the write fails, the item is read back (`sub_1001AA74`, `sub_1001A6C0`): the same value is accepted, a different one gives "Unable to re-provision IMEI (it appears it is being rewritten to different value.)".

### Security mode

The security mode is the SSM mode of the modem: 0 = SwUpdate, 1 = Restricted, 2 = Maintenance, 3 = AllowDiag (the names come from the log strings and from [Ncsd.dll](./ncsd.md#security-mode)).

`NPETSEC_GetSecurityMode(&mode)`:
1. Waits until the SSM is ready: [IOCTL 0x9C4124AC](../drivers/nokia_sec_driver.md#ioctl-0x9c4124ac--ssm-ready) must return 1, at most 10 tries 500 ms apart (20002 "Modem SSM ready wait timeout.").
2. Reads the modem EFS file `/nv/item_files/modem/ssm_mode` (`NPETSEC_QcEfsFileRead`, 256 bytes): the first character is the mode in ASCII (`'0'`…`'3'`); anything else gives 20002.

`NPETSEC_SetSecurityMode(mode)`: the same wait, then [IOCTL 0x9C412438](../drivers/nokia_sec_driver.md#ioctl-0x9c412438--nokiasecssmmodemmode) with the mode (`sub_1000610C` for 0, `sub_100064D4` for 1, `sub_10005EEC` for 2, `sub_100062F0` for 3; other values: 30002 "The provided security mode is not supported."). It then reads the mode back with `NPETSEC_GetSecurityMode` up to 20 times, 100 ms apart, and fails with 20001 if it didn't change. The DLL doesn't check any authorisation itself: the change is accepted or refused by the driver / TrustZone.

### DPP items

The DPP files are accessed through the driver ([IOCTL 0x9C412480](../drivers/nokia_sec_driver.md#ioctl-0x9c412480--nokiasecdppfilesize) to [0x9C41248C](../drivers/nokia_sec_driver.md#ioctl-0x9c41248c--nokiasecdppdeletefile)), never opened directly. `NPETSEC_DppItem*` take an item number, an index in the table at `0x1001E950` (23 entries of 20 bytes: id, path, readable, writable, authorisation needed); other numbers give "Unsupported DPP item specified (%d)".

| Item | DPP path | Read | Write | Authorisation |
|------|----------|------|-------|---------------|
| 0 | `\Microsoft\Microsoft.PVK` | n | y | y |
| 1 | `\QCOM\BT.Provision` | y | y | y |
| 2 | `\QCOM\WLAN.Provision` | y | y | y |
| 3 | `\Nokia\CoverColor.txt` (read at first boot by [nrsdriver.sys](../drivers/nrsdriver.md#cover-colour-multivariant)) | y | y | y |
| 4 | `\Nokia\customer_nvi_log.txt` | y | y | y |
| 5 | `\Nokia\simlock\sign` | y | y | y |
| 6 | `\Nokia\simlock\keys` | y | y | y |
| 7 | `\Nokia\simlock\lock` | y | y | y |
| 8 | `\Nokia\product.dat` | y | y | y |
| 9 | `\Nokia\certs\hwc` | y | n | |
| 10 | `\Nokia\certs\ccc` | y | n | |
| 11 | `\Nokia\certs\npc` | y | n | |
| 12 | `\Nokia\certs\rdc` | y | n | |
| 13 | `\Nokia\certs\devcert.bin` | y | y | y |
| 14 | `\Nokia\certs\mirlink.bin` | y | y | y |
| 15 | `\Nokia\RegScreen\imagelabel_dark.png` | y | y | y |
| 16 | `\Nokia\RegScreen\imagelabel_light.png` | y | y | y |
| 17 | `\Nokia\simlock\unlock.bin` | y | y | n |
| 18 | `\Nokia\ssdhash.bin` | y | y | y |
| 19 | `\Nokia\certs\label_data.bin` | y | y | n |
| 20 | `\Nokia\RegScreen\coo.txt` | y | y | y |
| 21 | `\Nokia\testfile.txt` | y | y | n |
| 22 | `\Nokia\testfilerestricted.txt` | y | y | y |

The certificates 9…12 can't be written with `NPETSEC_DppItemWrite` (20007); they're written by `NPETSEC_ImportHwCertificate`, `NPETSEC_ImportCcCertificate`, `NPETSEC_ImportNpCertificate` and `NPETSEC_ImportRdCertificate`. `NPETSEC_DppItemAppend` never checks the authorisation; `NPETSEC_DppItemDelete` uses the "readable" column to accept the item (the message says "non-readable").  
`NPETSEC_DppInitialize(sourcePath, &count)` (`sub_10004318`) copies a directory tree into the DPP (`FindFirstFileA`, "Copying file %s -> %s"), only if the DPP is still empty ("DPP already has content, will not re-initialize."). `sourcePath` must start with `\`.

#### DPP authorisation

`sub_10005E68` is called before the writes and deletes marked "y" above, and by `NPETSEC_SetProductionData`:
- before production is done ([IOCTL 0x9C412434](../drivers/nokia_sec_driver.md#ioctl-0x9c412434--secproductionreq) returns 0), everything is allowed (production line);
- after, the SuperDongle session must be open ([IOCTL 0x9C412464](../drivers/nokia_sec_driver.md#ioctl-0x9c412464--nokiasecsdstatus)) or the phone must be an R&D phone ([IOCTL 0x9C41244C](../drivers/nokia_sec_driver.md#ioctl-0x9c41244c--nokiasecrdphonereqservice)); otherwise error 20007 "Production line or SD authentication or RDC required.".

This check is in the DLL only: the driver's DPP write IOCTL doesn't check anything ([IOCTL 0x9C412488](../drivers/nokia_sec_driver.md#ioctl-0x9c412488--nokiasecdppwritefile)).

#### Production data

`\Nokia\product.dat` is a text file of `KEY:value` lines (separators `:` and `\n`, `sub_10011788` / `sub_10011BF4`). The `id` of `NPETSEC_GetProductionData` / `NPETSEC_SetProductionData` selects the key (table `off_1001EB30`; other ids: "Invalid production data id provided."):

| id | Key |
|----|-----|
| 0 | `HWID` |
| 1 | `LPSN` |
| 2 | `MC` |
| 3 | `BTR` |
| 4 | `CTR` |
| 5 | `ODR` |
| 6 | `TYPE` |

`NPETSEC_GetProductionData` copies the value in a 100-byte buffer ("No value provisioned for given key." if missing). `NPETSEC_SetProductionData` replaces or adds the line and rewrites the file with the [authorisation](#dpp-authorisation). `NPETSEC_SetProductionDataUnchecked` writes without the check, but only for `LPSN`, `BTR` and `CTR`; for the other keys it calls `NPETSEC_SetProductionData`.

### UEFI variables

Read with [IOCTL 0x9C4124A4](../drivers/nokia_sec_driver.md#ioctl-0x9c4124a4--nokiasecgetfirmwareenvvar) and written with [IOCTL 0x9C4124A8](../drivers/nokia_sec_driver.md#ioctl-0x9c4124a8--nokiasecsetfirmwareenvvar): `WCHAR[40]` name, vendor GUID, size, attributes 7 (non volatile, boot service and runtime access), data. The Nokia variables use the GUID `{4E6F6B69-6147-5549-4447-656E65726963}`, the bytes of the ASCII string `"ikoNGaIUDGeneric"` ("NokiaGUIDGeneric").

| Variable | Size | Used by |
|----------|------|---------|
| `ManufacturingState` | 500 | `NPETSEC_ReadManufacturingData` (size must be 500, "Manufacturing data content size not 500 bytes."), `NPETSEC_WriteManufacturingData` |
| `NokiaUefiStartFlag` | 4 | Boot mode hint of `NPETSEC_RebootDevice` |
| `FfuConfigurationOptions` | ? | `NPETSEC_GetFfuConfigOptions` (`sub_100047C8`): `*writeNviFull` = 1 if the value contains `"WriteNvi: Full"` (`strstr`). `NPETSEC_ClearFfuConfigOptions` (`sub_10004A90`) reads it and writes it back (exact change ?) |
| `PermanentStorage` | 20 | `NPETSEC_PermanentDataItem*` (`sub_10010FB4`, `sub_10011334`), only item 0 ("Permanent storage size in uefi is not correct.") |

#### UEFI certificates

`NPETSEC_GetUefiCertStates(states)` (`sub_10016650`) checks 5 secure boot variables. For each one (`sub_10016548`), it reads the variable (`sub_10015DA4`: size with [IOCTL 0x9C4124BC](../drivers/nokia_sec_driver.md#ioctl-0x9c4124bc--nokiasecgetfirmwareenvvarsize), then the value), and compares it with the end of a file of `C:\efiesp\Nokia\Security\`:

| states[] | Variable | GUID | Production file | R&D file |
|----------|----------|------|-----------------|----------|
| 0 | `PK` | `{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}` (EFI global) | `Nokia_Production_PK.bin` | `Nokia_RD_PK.bin` |
| 1 | `KEK` | EFI global | `KEK.bin` | |
| 2 | `db` | `{D719B2CB-3D3A-4596-A3BC-DAD00E67656F}` (image security database) | `production_db.bin` | `rd_db.bin` |
| 3 | `dbx` | image security database | `dbx.bin` | |
| 4 | `CurrentPolicy` | `{77FA9ABD-0359-4D32-BD60-28F4E78F784B}` (secure boot policy) | `SecureBootPolicy.p7b` | `SecureBootPolicy_test.p7b` |

Value: 2 = variable empty, 4 = matches the production file, 3 = matches the R&D file, 1 = matches neither. [Ncsd.dll](./ncsd.md) names them "Unsecure", "SecureProduction", "SecureRD" and "Unknown".  
`NPETSEC_UefiCertificatesAsedImport` (`sub_10016724`) parses a "Production UEFI data" block (version, sub-blocks with a mode and a type) and writes each certificate both to the DPP (`\Nokia\UefiCerts\<file>`) and to `C:\efiesp\Nokia\Security\<file>`.

### NPETSEC_RebootDevice

`NPETSEC_RebootDevice(mode, method)` (the values sent by [Ncsd.dll](./ncsd.md#setdevicemode)):

1. Boot mode hint (`sub_10013980`): mode 0 → `'N'`, 1 → `'S'`, 2 → `'Y'`, 3 → `'Z'`, 4 → no hint, other → 30002 "Unknown boot mode encountered.". The character is written to `C:\efiesp\nokia_uefi_start_flag.txt` and to the UEFI variable `NokiaUefiStartFlag` (Nokia GUID, 4 bytes). With Ncsd's modes, `'S'` is the flash mode, `'Y'` the test mode and `'Z'` the power off ?
2. Flushes the volumes `C:\EFIESP\`, `C:\DPP\`, `C:\Data\` and `\\.\C:` (`sub_100140CC`), and the modem file system (EFS2 sync, `sub_1001CCD0`).
3. Method (`sub_10013D74`):

| method | Action |
|--------|--------|
| 0 | Modem reset: DIAG `CONTROL_F` mode 1 (offline), `Sleep`, then mode 2 (reset), see [DIAG client](#diag-client) |
| 1 | "Initiating HW reset": enables `SeShutdownPrivilege`, then `InitiateSystemShutdownExW(NULL, NULL, 0, TRUE, FALSE, 0)` |
| 2 | [ShellChromeAPI.dll](./shellchromeapi.md)`!Shell_RequestShutdown(1)`, loaded at run time |
| 3 | Secure watchdog reset: [IOCTL 0x9C41240C](../drivers/nokia_sec_driver.md#ioctl-0x9c41240c--software-watchdog) command 3 |
| other | 30002 "Unknown boot method encountered." |

### Security logs

`logId` of `NPETSEC_GetSecurityLogFileSize`, `NPETSEC_ReadSecurityLogFile` and `NPETSEC_DeleteSecurityLogFile`:

| logId | File |
|-------|------|
| 0 | `C:\Data\SharedData\OEM\Public\nokia_sec_driver_log.txt` |
| 1 | DPP `\Nokia\seclabel.log` |
| 2 | `C:\Data\SharedData\Oem\Public\nvupdater.log` |
| 3 | DPP `\Nokia\customer_nvi_log.txt` |
| 4 | `C:\Data\SharedData\OEM\Public\simlock.log` |
| 5 | `C:\Data\Users\Public\Documents\nokia_sec_driver_log.txt` |

The DPP logs go through the driver file IOCTLs, the others are opened directly (`CreateFileA`, `SetFilePointer`, `ReadFile`, `DeleteFileA`). `NPETSEC_ReadSecurityLogFile` sets `*eof` when fewer bytes than asked were read.

### MirrorLink

`NPETSEC_GetMirLinkSignDigestResultSize` returns the size of `C:\Programs\CommonFiles\OEM\Public\Security\mirlink_subca.bin` + 2328; its first 6 parameters aren't used. `NPETSEC_GetMirLinkSignDigestResult` (`sub_100054AC`) reads that sub-CA and the ASED data of `\Nokia\certs\mirlink.bin` (DPP), and sends them with its 6 parameters to [IOCTL 0x9C41249C](../drivers/nokia_sec_driver.md#ioctl-0x9c41249c--nokiasecmirlinksigndigestservice); the exact layout wasn't decoded.

### SSD

- `NPETSEC_ProvisionSsdHash`: hashes the SSD partition (`sub_10016EE8`) and writes the hash to the DPP item 18 (`\Nokia\ssdhash.bin`).
- `NPETSEC_ValidateSsdHash(&valid)`: hashes the partition again and compares with `\Nokia\ssdhash.bin` (`sub_100171BC`).
- `sub_10016C30` finds the partition: for `\\.\PhysicalDrive0` to 5, `IOCTL_DISK_GET_DRIVE_LAYOUT_EX`; the disk must be GPT, and the partition type `{2C86E742-745E-4FDD-BFD8-B6A7AC638772}`; the offset and size of the first matching partition are kept. The whole partition is read and hashed with the library's own hash code (no crypto import; algorithm ?).
- `NPETSEC_ProvisionQcSsdKeyStore(data, size)` loads `c:\windows\system32\BinaryPartitionDecrypt.dll` and calls `BinaryPartitionDecrypt_Init`, `BinaryPartitionDecrypt_ProvisionKeyStore(data, size)` ?, `BinaryPartitionDecrypt_DeInit`.
- `NPETSEC_DecryptDeviceSwKeysAsed` decrypts with [IOCTL 0x9C41247C](../drivers/nokia_sec_driver.md#ioctl-0x9c41247c--nokiasecssddecryptdata).

### Battery level

`NPETSEC_GetRemainingBatteryLevel(&level)` (`sub_10001AC4`):

1. Looks for a battery device (`CM_Get_Device_Interface_ListW` with `GUID_DEVICE_BATTERY`). If one is found (`sub_1000189C`): `IOCTL_BATTERY_QUERY_TAG` (0x294040), `IOCTL_BATTERY_QUERY_INFORMATION` (0x294044) and `IOCTL_BATTERY_QUERY_STATUS` (0x29404C); level = 100 × capacity / full charged capacity, rounded.
2. Otherwise it looks for the [qcbms8930.sys](../drivers/qcbms8930.md) interface `{23B7D0DD-…}` (`sub_10001734`): reads the `BATT_ID` channel of `\\.\QCOM_XoAdc` with [IOCTL_ADC_GET_CHANNEL](../drivers/qcxoadc8930.md#ioctl-0x8adc2000--ioctl_adc_get_channel) (`sub_100015F4`), sends [IOCTL_BMS_SET_SYSTEM_INFO](../drivers/qcbms8930.md#ioctl-0x80180fb4--ioctl_bms_set_system_info) with `{30000, 30000, BATT_ID}` (both temperature fields fixed, 30 °C ?), then [IOCTL_BMS_GET_PERCENT_CHARGE](../drivers/qcbms8930.md#ioctl-0x80180fac--ioctl_bms_get_percent_charge); level = ‰ / 10.
3. Neither: "Failure to find device to read battery information.".

### DIAG client

The DIAG object (`sub_1001AF78`, created once, kept in `dword_100312BC`) opens the modem DIAG channel (`sub_1001B15C`):

1. `CreateFileW(L"\\\\.\\DiagCSI", GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL)`; failure → 50003.
2. Three events (state, abort, modem ready) and the listener thread `sub_1001AFF8`.
3. Registers with [IOCTL 0x80092440](../drivers/qcdiagcsi8930.md#ioctl-0x80092440): `{1, hStateEvent, 0x00070002, 0}` (16 bytes), the same registration as [Ncsd.dll](./ncsd.md#diag-flushnvdata).
4. Waits up to 7 s for the modem ready event (50007).

The listener waits on the state event; each time it sends [IOCTL 0x80092448](../drivers/qcdiagcsi8930.md#ioctl-0x80092448) (2-byte output) and sets the ready event when bit 1 is set ("Modem state now: Ready"), resets it otherwise. `NPETSEC_QcWaitForModemReady(timeout)` waits on that event.

The commands go through [IOCTL 0x80092444](../drivers/qcdiagcsi8930.md#ioctl-0x80092444) (`sub_1001B598`, retried 3 times 168 ms apart on `ERROR_OPERATION_ABORTED`), with a response buffer of 0x1820 bytes:

| Request | Command | Used by |
|---------|---------|---------|
| `29 mm mm` | `DIAG_CONTROL_F`, mode (WORD) | `NPETSEC_QcModemModeSet(mode)`, reboot method 0 (modes 1 then 2) (`sub_1001B758`). The response must give back the mode |
| `41 dddddd` | `DIAG_SPC_F`, 6 ASCII digits | `NPETSEC_QcNvSpcUnlock` (`sub_1001D0C0`). "Unlock SPC code error." if the modem refuses |
| `4B 30 01 00 item ctx …` | NV read (subsystem 0x30), item id, context, 128 bytes of data (138-byte request) | `NPETSEC_QcNvItemRead`, `NPETSEC_QcNvItemIndexedRead` (first data byte = index) (`sub_1001CD3C`) |
| `4B 30 02 00 item ctx …` | NV write | `NPETSEC_QcNvItemWrite` (`sub_1001CEE0`): ≤ 128 bytes ("NV data too large."). Status messages for item already written, store full, "access denied due to secure mode", SPC locked |
| `4B 13 00 00 …` | EFS2 hello (windows of 1 packet / 0x400 bytes) | Before each EFS sequence (`sub_1001B83C`) |
| `4B 13 02 00`, `03 00`, `04 00`, `05 00` | EFS2 open, close, read, write | Data files: `NPETSEC_QcEfsDataFileRead` / `Write` (`sub_1001BB7C`, `sub_1001BC94`) |
| `4B 13 08 00` | EFS2 unlink | `NPETSEC_QcEfsFileDelete` |
| `4B 13 09 00 FF 01 …` | EFS2 mkdir, mode 0777 | Missing parent directories of a write (`sub_1001C788`, absolute paths only) |
| `4B 13 0F 00` | EFS2 stat | `NPETSEC_QcEfsGetFileSize` |
| `4B 13 26 00`, `27 00` | EFS2 put / get item file | Item files: `NPETSEC_QcEfsItemFileWrite` / `Read` |
| `4B 13 30 00`, `31 00` | EFS2 sync, sync status (polled 20 × 200 ms) | Flush before a reboot (`sub_1001CCD0`) |
| `4B 13 35 00 01 00 …` | EFS2 make golden copy | `NPETSEC_InitializeQcGoldenCopy` (`sub_1001CB7C`) |

- `NPETSEC_QcEfsFileWrite` uses an item file up to 106 bytes and a data file above; `NPETSEC_QcEfsFileRead` reads it as an item file (`sub_100129FC` → `sub_1001272C`).
- NV items 20000 to 40000 are RF NV items: they're read and written as the EFS file `/nv/item_files/rfnv/%08d` (item file up to 64 bytes, data file above) instead of the NV command.
- `NPETSEC_QcNvSpcUnlock` requires exactly 6 characters ("SPC code length mismatch. Need %d digits.").
- Unlike [Ncsd.dll](./ncsd.md#nv-and-efs-firewall), the DLL has no whitelist: any NV item or EFS file can be written if the modem accepts it.

### Other exports

- `NPETSEC_GetRandomData(buffer, length)` → [IOCTL 0x9C41242C](../drivers/nokia_sec_driver.md#ioctl-0x9c41242c--nokiasecrandomdatagetservice).
- `NPETSEC_RegItemValueWrite(item, data, size)` → [IOCTL 0x9C4124B8](../drivers/nokia_sec_driver.md#ioctl-0x9c4124b8--nokiasecregwritevalue): item 0 = `HideAPN`, 1 = `HideMMSAPN` in `HKLM\Software\Microsoft\Connectivity\CellUXOEMConfigurable`.
- `NPETSEC_ImportHwCertificate` / `NPETSEC_ImportCcCertificate` write `\Nokia\certs\hwc` / `\Nokia\certs\ccc` to the DPP, without driver call (`sub_10001EE0`, `sub_10001E08`).
- `NPETSEC_ImportRdCertificate` (`sub_1001309C`) keeps the previous `\Nokia\certs\rdc`, writes the new one, sends [IOCTL 0x9C412448](../drivers/nokia_sec_driver.md#ioctl-0x9c412448--nokiasecrdcimportservice), and restores the previous certificate on failure. `NPETSEC_DeleteRdCertificate` deletes `\Nokia\certs\rdc`.
- `NPETSEC_SuperDongleProvisionAsedKeys` writes `\Nokia\CERTS\superdongle_ased.bin` to the DPP (no driver call).
- `NPETSEC_ReadSecFeaSize` / `NPETSEC_ReadSecFea` return the eFuse security feature bytes ([IOCTL 0x9C4124CC](../drivers/nokia_sec_driver.md#ioctl-0x9c4124cc--nokiasecfeasizeread), [0x9C4124D0](../drivers/nokia_sec_driver.md#ioctl-0x9c4124d0--nokiasecfearead)), decoded by [Ncsd.dll](./ncsd.md#efuses).
- `NPETSEC_PermanentlyBurn*` and `NPETSEC_WritePsnEfuse` burn eFuses: these writes are definitive.

### Named objects

| Name | Type | Use |
|------|------|-----|
| `NokiaSecDrvSvcLib` | Mutex | Serialises the IOCTLs to `\\.\NokiaSec` |
| `NokiaSecDebug` | Mutex | Protects the log file |
