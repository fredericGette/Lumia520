## Ncsd.dll

Nokia Care Suite daemon ("NCSd for WP8"): the JSON-RPC 2.0 server that the PC care/recovery tools talk to over the NCSd USB interface.  
`Ncsd.dll` is a C++ library (281 992 bytes, 931 functions, most of them the statically linked jsoncpp library and STL code). It doesn't do any USB I/O. It takes one JSON-RPC request as a string and returns the JSON response string. In between it dispatches on `method` to about 85 methods, which read the phone identity (IMEI, MEID, BT/WLAN addresses, product code, service tag…), read and write modem NV items and EFS files, read the security logs, change the security mode, reboot the phone into flash/test mode or factory-reset it. Most of them go through Nokia's security library `npetsec.dll` (`NPETSEC_*`). The rest read the registry, the battery driver, a Qualcomm DIAG channel (`\\.\DiagCSI`) and a cellular COM object.  
It is loaded by the service executable [ncsdsvc.exe](../applications/ncsdsvc.md) (service `ncsd`), which opens the NCSd USB function interface `\\.\GenericUsbFn_{7eaff726-34cc-4204-b09d-f95471b873cf}` of [genericusbfnclass.sys](../drivers/genericusbfnclass.md#ncsd-instance), reads requests from the bulk OUT pipe, passes them to the DLL and writes the responses to the bulk IN pipe, see [Transport](#transport-ncsdsvcexe).

Location on the phone: ? ([ncsdsvc.exe](../applications/ncsdsvc.md) loads it with `LoadLibraryExW(L"Ncsd.dll", NULL, 0)`, so it's next to the service or in the system path).  
Build: "Jan 28 2015", PDB `E:\build_e\subtask\9BE7887C_98\output\ncsd\fre\Ncsd.pdb`.  

### Imports

| DLL | Functions |
|-----|-----------|
| npetsec.dll | `NPETSEC_Init`, `NPETSEC_Deinit`, `NPETSEC_LastErrorStr`, `NPETSEC_ReadBtId`, `NPETSEC_ReadWlanId`, `NPETSEC_ReadPublicId`, `NPETSEC_ReadImeiRaw`, `NPETSEC_ReadImeiStr`, `NPETSEC_ReadMeidRaw`, `NPETSEC_ReadMeidStr`, `NPETSEC_ReadServiceTagSize`, `NPETSEC_ReadServiceTag`, `NPETSEC_DppItemSize`, `NPETSEC_GetProductionData`, `NPETSEC_GetSimlockStatus`, `NPETSEC_RdcPhoneReq`, `NPETSEC_GetSecurityMode`, `NPETSEC_SetSecurityMode`, `NPETSEC_RebootDevice`, `NPETSEC_QcNvSpcUnlock`, `NPETSEC_QcNvItemIndexedRead`, `NPETSEC_QcNvItemWrite`, `NPETSEC_QcEfsFileRead`, `NPETSEC_QcEfsFileWrite`, `NPETSEC_QcEfsItemFileWrite`, `NPETSEC_QcEfsDataFileWrite`, `NPETSEC_QcEfsFileDelete`, `NPETSEC_GetSecurityLogFileSize`, `NPETSEC_ReadSecurityLogFile`, `NPETSEC_DeleteSecurityLogFile`, `NPETSEC_SetDriverLogging`, `NPETSEC_RegItemValueWrite`, `NPETSEC_IsProductionDone`, `NPETSEC_ReadSecFeaSize`, `NPETSEC_ReadSecFea`, `NPETSEC_GetUefiCertStates`, `NPETSEC_ReadManufacturingData` |
| PHONEINFO.dll | `GetPhoneVersion` |
| WPCOREUTIL.dll | `ResetPhone` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCreateKeyExW`, `RegSetValueExW`, `RegCloseKey` |
| api-ms-win-devices-config-l1-1-0.dll | `CM_Get_Device_Interface_List_SizeW`, `CM_Get_Device_Interface_ListW` |
| api-ms-win-core-file-l1-2-0.dll | `CreateFileW` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-psapi-l1-1-0.dll | `K32EnumProcesses` |
| api-ms-win-core-com-l1-1-0.dll | `CoInitializeEx`, `CoUninitialize`, `CoCreateInstanceFromApp` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `CreateMutexW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep` |
| api-ms-win-core-string-l1-1-0.dll | `MultiByteToWideChar`, `WideCharToMultiByte` |
| api-ms-win-core-errorhandling-l1-1-1.dll | `GetLastError` |
| api-ms-win-core-util-l1-1-0.dll, libraryloader, profile, processthreads, sysinfo | `EncodePointer`, `DecodePointer`, `DisableThreadLibraryCalls`, `QueryPerformanceCounter`, `GetCurrentThreadId`, `GetTickCount64`, `GetSystemTimeAsFileTime` |
| MSVCR110.dll, MSVCP110.dll | CRT, `sprintf_s`, `sscanf`, `strpbrk`, C++ exceptions, `std::ostream` / `std::streambuf` (used by jsoncpp) |

The util, libraryloader, profile, processthreads and sysinfo imports and most of MSVCR110 are the Visual C++ DLL CRT startup and `/GS` security cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [ncsdsvc.exe](../applications/ncsdsvc.md) (service `ncsd`) | Loader: `LoadLibraryExW` + `GetProcAddress("Ncsd2_CreateInstance" / "Ncsd2_DeleteInstance")` | Owns the USB pipes and calls the request handler, see [Transport](#transport-ncsdsvcexe) |
| `\\.\DiagCSI` ([qcdiagcsi8930.sys](../drivers/qcdiagcsi8930.md)) | `CreateFileW(GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING, FILE_FLAG_OVERLAPPED \| FILE_ATTRIBUTE_NORMAL)`, IOCTLs 0x80092440 / 0x80092444 / 0x80092448 | EFS2 sync of the modem file system for `FlushNVData`, see [DIAG](#diag-flushnvdata) |
| Battery device (interface `GUID_DEVICE_BATTERY` `{72631e54-78a4-11d0-bcf7-00aa00b7b32a}`) | `CM_Get_Device_Interface_ListW`, `CreateFileW` on the first interface, `IOCTL_BATTERY_*` | `ReadBatteryLevel`, see [Battery](#battery-readbatterylevel) |
| COM server of CLSID `{9d27b916-4f17-4ee8-a71c-d84222993d64}` (DLL ?) | `CoCreateInstanceFromApp`, IID `{17ae6dc1-3723-4085-99ba-7160cdb8bfc1}` | Cellular ("oemCellular") object, PRL id of CDMA phones, see [ReadPrlId](#readprlid) |
| Modem EFS files `/nv/item_files/data/dsd/ds_apn_switching`, `/nv/item_files/ims/qp_ims_reg_config`, `/nv/item_files/modem/data/3gpp/lteps/attach_profile` | `NPETSEC_QcEfsFileRead` / `NPETSEC_QcEfs*Write` | IMS test mode (Verizon only), see [IMS test mode](#ims-test-mode) |

No other DLL is loaded at run time and no process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `Ncsd2_CreateInstance` | 0x10002668 | none. Returns a new `CNcsd` object (12 bytes, `operator new`), or NULL |
| 2 | `Ncsd2_DeleteInstance` | 0x100026C0 | `CNcsd *`. Calls the virtual destructor (vtable +0xF8, scalar deleting destructor `sub_1000D6CC`) with flag 1 |

There's no other entry point: the caller uses the object through its vtable (`off_1002F158`, 64 entries). Slot +0xFC (`ProcessRequest`, `sub_1000D974`) is the only one called from outside, slots +0x00…+0xF4 are the method handlers and slot +0x3C (`SetError`, `sub_1000D7E8`) builds an error object.

`CNcsd` (constructor `sub_1000D610`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `off_1002F158` (base class vtable `off_1002F258`) |
| 0x04 | 4 | `CNpetsec` object (4 bytes, vtable `off_1002F370`): one thin wrapper per `NPETSEC_*` import, see [npetsec wrapper](#npetsec-wrapper) |
| 0x08 | 4 | Backend object (8 bytes, `sub_10012D4C`): +0x00 NPETSEC state (0 = not initialised, 1 = initialised, −1 = `NPETSEC_Init` failed), +0x04 pointer to the `CNpetsec` object. Its non-virtual methods (0x10012D70…0x100173BC) do the `NPETSEC_*` calls of the handlers |

### Startup

`start` (`_DllMainCRTStartup`, 0x10028D08): the usual CRT init (`_initterm`), `DisableThreadLibraryCalls`. There's no ETW provider and nothing is done at load time.  
`npetsec.dll` is initialised lazily: every backend method first calls `sub_10012D70`, which calls `NPETSEC_Init(0)` once (wrapper slot +0x04). A failure sets the state to −1 and throws a `CNcsdException` with `NPETSEC_LastErrorStr()`, so the method returns an error ("NPETSEC init").

### Transport (ncsdsvc.exe)

Summary of [ncsdsvc.exe](../applications/ncsdsvc.md#main-loop), which has the details (USB object, IOCTL buffers, service control).

1. Runs as the service `ncsd` (`StartServiceCtrlDispatcherW`, `RegisterServiceCtrlHandlerW(L"ncsd")`; argument `-s`, the default), or in the console with `-n`.
2. Opens `\\.\GenericUsbFn_{7eaff726-34cc-4204-b09d-f95471b873cf}` twice (`GENERIC_READ | GENERIC_WRITE`, `OPEN_EXISTING`), sends `IOCTL_GENERICUSBFN_GET_CLASS_INFO` (0x22C022, 552-byte output) and takes the pipe ids of the high-speed interface: the endpoint with bit 0x80 (IN, 0x81) for the responses, the other one (OUT, 0x02) for the requests. Then `IOCTL_GENERICUSBFN_ACTIVATE_USB_BUS` (0x22C02C), and starts a thread that loops on `IOCTL_GENERICUSBFN_BUS_EVENT_NOTIFICATION` (0x22C036) to set or reset an "attached" event (see [genericusbfnclass.sys](../drivers/genericusbfnclass.md#ioctl-forwarding)).
3. Main loop, with a 16 384-byte (0x4000) buffer: waits for the event, reads a request with `IOCTL_GENERICUSBFN_TRANSFER_OUT` (0x22C016) on the OUT pipe. Empty read → `Sleep(100)` and retry. A request starting with `-` stops the loop.
4. Loads `Ncsd.dll` and creates the object on the first request (and again after a detach: when the event is reset, the object is deleted and the DLL freed). If the DLL can't be loaded, it answers `{"error":{"code":-4294966182,"message":"Unable to load libraries"},"id":0,"jsonrpc":"2.0"}`.
5. Calls `ProcessRequest(std::string(request), &response)` (vtable +0xFC) and writes the response with `IOCTL_GENERICUSBFN_TRANSFER_IN` (0x22C00D) on the IN pipe. A response longer than 16 384 bytes stops the loop.

One USB bulk transfer is therefore one JSON-RPC message, at most 16 KB in each direction.

### ProcessRequest (sub_1000D974, vtable +0xFC)

`ProcessRequest(std::string request, std::string *response)` (always returns 0):

1. Parses the request with `Json::Reader::parse` (`sub_100244BC`, comments allowed). Failure → error `E_FAIL` (0x80004005) "Error while parsing request.".
2. Compares `request["method"]` with each method name in turn (table in [Methods](#methods)) and calls the handler `handler(this, request, result)`, a virtual method of `CNcsd` (5 handlers are called directly). A handler returns `true` with the result object filled, or `false` after calling `SetError`. Unknown method → error `E_INVALIDARG` (0x80070057) "Method not found.".
3. `BuildResponse` (`sub_1000D890`): `"jsonrpc": "2.0"`, `"id"` copied from the request (`null` if missing), then `"result"` (success) or `"error"`.
4. Serialises the response with the jsoncpp writer (`sub_1001C538`) into `*response`.

`SetError(error, message, code)` (`sub_1000D7E8`, vtable +0x3C): `error["code"] = code` (an HRESULT, e.g. 0x80070057 for a bad parameter, or the error of `npetsec.dll`), `error["message"] = message`.  
Request example: `{"jsonrpc":"2.0","id":1,"method":"ReadProductCode","params":{}}` → `{"id":1,"jsonrpc":"2.0","result":{"ProductCode":"…"}}`.

The handlers catch the `CNcsdException` thrown by the backend (HRESULT + message, e.g. `NPETSEC_LastErrorStr()`) and turn it into an error. Any other exception gives "`<Name>::Unknown unexpected error.`".

### Methods

`params` is an object; "→" gives the members of `result`. ID = identity read with `NPETSEC_*`; the helper names are those of the error strings.

| Method | Handler | Params → Result | Implementation |
|--------|---------|-----------------|----------------|
| GetVersion | `sub_10002704` (+0x00) | → `HelloString` = "NCSd for WP8", `Version` = "3.7", `BuildDate` = "Jan 28 2015", `BuildType` = "Release" | Constants |
| ReadSwVersion, ReadOperatorName, ReadManufacturerModelName, ReadSystemAsicVersion, ReadRfChipsetVersion | `sub_10002B40` (+0x04) | → `SwVersion`, `OperatorName`, `ManufacturerModelName`, `SystemAsicVersion`, `RfChipsetVersion` | [Registry](#registry) `DeviceTargetingInfo`: `PhoneFirmwareRevision`, `PhoneMobileOperatorName`, `PhoneManufacturerModelName`, `PhoneSOCVersion`, `PhoneRadioHardwareRevision` |
| ReadBtId, ReadPublicId, ReadSerialNumber, ReadMeid | `sub_10003118` (+0x08) | `SubscriptionId` (optional, 0/1) → `BtId` ?, `PublicId`, `SerialNumber`, `Meid` ? | `sub_10012E94`: `NPETSEC_ReadBtId` (6 bytes), `NPETSEC_ReadPublicId` (20 bytes), IMEI (`NPETSEC_ReadImeiRaw` 8 bytes / `NPETSEC_ReadImeiStr` 16 bytes, by `SubscriptionId` ?), `NPETSEC_ReadMeidStr` (14 bytes). Error "NPC fail" |
| ReadWlanMacAddress | `sub_1000352C` (+0x0C) | → `WlanMacAddress1` … `WlanMacAddress4` | `NPETSEC_ReadWlanId` (6 bytes) × 4 |
| ReadModuleCode, ReadProductCode, ReadBasicProductCode, ReadPsn, ReadHwVersion, ReadTypeDesignator | `sub_10003BFC` (+0x10) | → `ModuleCode`, `ProductCode`, `BasicProductCode`, `Psn` ?, `HWVersion`, `TypeDesignator` | `NPETSEC_GetProductionData` (100-byte buffer, `sub_1001369C`) |
| UnlockNvSpc | `sub_10003FA0` (+0x14) | `CodeString` → | `NPETSEC_QcNvSpcUnlock` (SPC unlock of the modem), with the [security mode switch](#security-mode) (`sub_100173BC`) |
| ReadNvItem | `sub_100044B0` (+0x18) | | Stub: "Invalid parameter" without `params`, otherwise fails without error object. `ReadNVData` is the working one |
| ReadServiceTag | `sub_1000454C` (+0x1C) | `Challenge` → `ServiceTag` | `NPETSEC_ReadServiceTagSize`, `NPETSEC_ReadServiceTag` (`sub_100138E8`) |
| ReadSimlockActive | `sub_10004858` (+0x20) | → `SimLockActive` (bool), `SimlockData` (array of 8 byte values) | `NPETSEC_GetSimlockStatus` (`sub_10013C2C`) |
| ReadImsi | `sub_10004BC0` (+0x24) | → `Imsi` (9 bytes) | `NPETSEC_GetSimlockStatus` (`sub_10013DB4`) |
| ReadPrlId | `sub_10004EA0` (+0x28) | → `PrlId` (decimal string) | [COM](#readprlid) |
| ReadPVKAvailable | `sub_100050A8` (+0x2C) | → `PVK` (bool) | `NPETSEC_DppItemSize` (`sub_10013F3C`) |
| ReadCertificateAvailable | `sub_10005274` (+0x30) | `CertName` = "RDC" → `RDC` (bool) | `NPETSEC_RdcPhoneReq` (`sub_10014094`) |
| SetSecurityMode | `sub_100054CC` (+0x34) | `SecurityMode` = "Restricted" / "Maintenance" → | `NPETSEC_SetSecurityMode` 1 / 2 (`sub_100141E8`) |
| GetSecurityMode | `sub_10005714` (+0x38) | → `SecMode` = "SwUpdate" / "Restricted" / "Maintenance" | `NPETSEC_GetSecurityMode` 0 / 1 / 2 (`sub_100143D0`) |
| SetDeviceMode | `sub_1000589C` (direct) | `DeviceMode`, `ResetMethod` → "Goodbye" ? | [Reboot](#setdevicemode) |
| ReadNVData | `sub_10005BA4` (direct) | `ID`, `index` (optional), `SubscriptionId` (optional) → `NVData` (array of bytes) | `NPETSEC_QcNvItemIndexedRead` (`sub_100148F4`) |
| WriteNVData | `sub_10005FC8` (direct) | `ID`, `NVData` (array of bytes), `SubscriptionId` → | `NPETSEC_QcNvItemWrite` behind the [NV firewall](#nv-and-efs-firewall) (`sub_10014A50`) |
| WriteHashData | `sub_100063B8` (direct) | `HashedData` → | `sub_1001504C`: NV item read then write (`sub_100148F4` + `sub_10014A50`) ? |
| FlushNVData | `sub_1000419C` (+0x40) | → | [DIAG](#diag-flushnvdata) EFS2 sync; "Diag fail" |
| WriteEFSData | `sub_100069C8` (direct) | `FilePath`, `Data` (array of bytes), `ItemType` = "Data" / other → | `NPETSEC_QcEfsDataFileWrite` / `NPETSEC_QcEfsItemFileWrite`, Maintenance mode only (`sub_10015264`) |
| ReadEFSData | `sub_1000661C` (+0x44) | `FilePath` → `EFSData` | `NPETSEC_QcEfsFileRead` (`sub_100150FC`) |
| DeleteEFSData | `sub_10006E30` (+0x48) | `FilePath` → | `NPETSEC_QcEfsFileDelete`, Maintenance mode only (`sub_100155C8`) |
| ReadLogFileSize | `sub_10007088` (+0x4C) | `LogFile` → `LogSize` | `NPETSEC_GetSecurityLogFileSize` (`sub_10015824`), see [Security logs](#security-logs) |
| ReadLogFile | `sub_10007328` (+0x50) | `LogFile`, `ReadSize`, `ReadOffset` → `Log`, `ReadSize` | `NPETSEC_ReadSecurityLogFile` (`sub_10015A7C`) |
| DeleteLogFile | `sub_10007800` (+0x54) | `LogFile` → | `NPETSEC_DeleteSecurityLogFile` (`sub_10015D24`) |
| ReadAkVersion | `sub_10007A58` (+0x58) | → `AkVersion` | `CurrentBuildNumber` (`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion`) + "." + a WORD of the `GetPhoneVersion` output (0x11C-byte structure, +0x0C) (`sub_1001ACA4`) |
| ReadBspVersion | `sub_10007D60` (+0x5C) | → `BspVersion` | `PhoneFirmwareRevision` cut before its second "." (`sub_1001AF28`) |
| ReadBatteryLevel | `sub_10008068` (+0x60) | → `BatteryLevel` (%) | [Battery](#battery-readbatterylevel) |
| SetSecDriverLogLevel | `sub_10008330` (+0x64) | `LogLevel` → | `NPETSEC_SetDriverLogging` (`sub_10015F5C`) |
| ReadDeviceMode | `sub_1000858C` (+0x68) | → `DeviceMode` = "Normal" | Constant |
| ReadSupportedTestModeBootMethods | `sub_10008740` (+0x6C) | → `BootMethod` = "eMMC" | Constant |
| SetApnSettings | `sub_1000885C` (+0x70) | `Hide` → | Only when `PhoneMobileOperatorName` = "VZW-US", otherwise "APN Setting writing NOT allowed". `NPETSEC_RegItemValueWrite` (`sub_1001602C`) |
| WriteMmsUAProf, WriteMmsUserAgentString | `sub_10008C54`, `sub_10008CE0` (+0x74, +0x78) | | Always "…::Not Supported" |
| ReadMmsUAProf, ReadMmsUserAgentString | `sub_10008D6C`, `sub_10008FA8` (+0x7C, +0x80) | → `UAProf`, `UserAgentString` | Registry `HKLM\SYSTEM\Messaging\MMS\` |
| ReadProductionDoneState | `sub_100091E4` (+0x84) | → `ProductionDone` (bool) | `NPETSEC_IsProductionDone` (`sub_1001710C`) |
| GetSupportedLogFiles | `sub_1000936C` (+0x88) | → `SupportedLogFiles` (array of names, or `["None"]`) | `sub_10017254`: log files whose `NPETSEC_GetSecurityLogFileSize` succeeds ? |
| ReadPlatformSecureBootEnabled, ReadSecureFfuEnabled, ReadDebugDisabled, ReadSHKEnabled | +0x8C…+0x98 | → `PlatformSecureBootEnabled`, `SecureFfuEnabled`, `DebugDisabled`, `SHKEnabled` (bool) | [eFuses](#efuses) |
| ReadUefiSecureBootEnabled | `sub_10009B10` (+0x9C) | → `UefiSecureBootEnabled` (bool) | `NPETSEC_GetUefiCertStates` (`sub_100168A4`) |
| ReadManufacturingData | `sub_10009C78` (+0xA0) | → `ManufacturingData` | `NPETSEC_ReadManufacturingData` (`sub_100169F8`) |
| ReadHVBatteryAuthSuccessCount, ReadHVBatteryAuthFailedCount, ReadHVBatteryAuthMaxTriesCount, ReadHVBatteryUID | +0xA4…+0xB0 | → `AuthSucceessCount` (sic), `AuthFailedCount`, `AuthMaxTriesCount`, `BatteryUID` | Registry `NokiaBIFDriver` (battery authentication, [Registry](#registry)) |
| GetUefiCertificateStatus | `sub_1000A6F8` (+0xB4) | → `Pk`, `Kek`, `Db`, `Dbx`, `BootPolicy` = "NA" / "Unknown" / "Unsecure" / "SecureRD" / "SecureProduction" | `NPETSEC_GetUefiCertStates` (`sub_10016C20`, names from `sub_10016B34`) |
| ResetPhone | `sub_1000B380` (+0xB8) | → | `WPCOREUTIL!ResetPhone(0, 0, 0)` (factory reset ?); its error is returned as is |
| ReadProcessCount | `sub_1000B4F4` (+0xBC) | → `ProcessCount` | `K32EnumProcesses` |
| SetConfigAccessMode / SetConfigurationAccessMode | `sub_1000A8D8` (+0xC0) / `sub_1000ABE8` (+0xC8) | `Mode` / `ConfigurationAccessMode` = "Restricted" / "Open" (/ "Maintenance") → | `NPETSEC_SetSecurityMode` ("Open" = Maintenance ?) |
| GetConfigAccessMode / GetConfigurationAccessMode | `sub_1000AEF8` (+0xC4) / `sub_1000B13C` (+0xCC) | → `Mode` / `ConfigurationAccessMode` = "Restricted" / "Open" / "Unknown" | `NPETSEC_GetSecurityMode`: Restricted → "Restricted", Maintenance → "Open" |
| SetImsTestMode / GetImsTestMode | `sub_1000B6BC` (+0xD0) / `sub_1000BC8C` (+0xD4) | `Setting` → / → `ImsTestModeStatus` | [IMS test mode](#ims-test-mode) |
| GetOobeNextSectionValue, GetOobeCompletionTime, GetOobeNextSectionAvailable | +0xD8, +0xDC, +0xE0 | → `OOBENextSectionValue`, `OOBECompleteTime`, `OOBENextSectionAvailable` (bool) | Registry `HKLM\SOFTWARE\Microsoft\Shell\OOBE\` `NextSection`, `OobeCompleteTime` |
| GetRefurbishStatus, SetRefurbishStatus, GetRefurbishStatusAvailable | +0xE4, +0xE8, +0xEC | → `RefurbishStatusValue` / `Value` → / → `RefurbishStatusAvailable` (bool) | Registry `HKLM\SOFTWARE\OEM\Nokia\NCSd\RefurbishStatus` (written with `RegCreateKeyExW` + `RegSetValueExW`) |
| ReadLabelID, ReadConfigurationID | `sub_1000D1D8`, `sub_1000D3F4` (+0xF0, +0xF4) | → `LabelID`, `ConfigurationID` | Registry `HKLM\SOFTWARE\OEM\Nokia\Variant\` |

The read/write handlers of the security log, NV, EFS, mode and reboot families all report the `npetsec.dll` error (`NPETSEC_LastErrorStr`) as message.

### Security mode

`npetsec.dll` keeps a security mode: 0 = "SwUpdate", 1 = "Restricted", 2 = "Maintenance" (names of `sub_100143D0`). The mode limits what the PC tool can change:

- `SetSecurityMode` accepts only "Restricted" (1) and "Maintenance" (2), anything else → "Invalid security mode" (0x80070057). How `npetsec.dll` authorises the change is not visible here (npetsec.dll not analysed).
- `UnlockNvSpc` and `WriteNVData` (whitelisted items): when the mode is 1, the backend switches to mode 0 with `NPETSEC_SetSecurityMode(0)`, does the operation, then restores mode 1.

### NV and EFS firewall

`WriteNVData` (`sub_10014A50`): unless the mode is Maintenance (2), the NV item id must be in the whitelist of `sub_10016F80`, otherwise error 0x84009999 "Writing NOT allowed due to firewall". Whitelisted items (decimal): 4, 5, 7, 20, 21, 25, 32…37, 43, 85, 88, 176…178, 219, 259, 285, 296, 298, 459…462, 465, 495, 546, 941, 1943, 2825, 6858, 6860, 67221, 67258, 67259.  
`WriteEFSData` (`sub_10015264`) and `DeleteEFSData` (`sub_100155C8`) work only in mode 2, otherwise 0x84009999 "Writing / Deleting NOT allowed due to firewall". `ReadEFSData` and `ReadNVData` aren't restricted by Ncsd.dll.

### SetDeviceMode

`sub_1000589C` reads `DeviceMode` and `ResetMethod` (strings) and calls `sub_10014584`, which converts them and calls `NPETSEC_RebootDevice(mode, method)` (wrapper slot +0x68):

| `DeviceMode` | mode | `ResetMethod` | method |
|--------------|------|---------------|--------|
| Normal | 0 | SwReset | 0 |
| Flash | 1 | HwReset | 1 |
| Test | 2 | Goodbye | 2 |
| PowerOff | 3 | | |
| MassStorage | error 0x32 (`ERROR_NOT_SUPPORTED`) "Boot to mass storage not supported" | | |

Other values → 0x80070057 "Invalid device mode" / "Invalid reboot mode". This is how the PC tools put the phone in flash mode.

### Security logs

`LogFile` names → `npetsec.dll` log ids (`sub_10015824`, `sub_10015A7C`, `sub_10015D24`): "Driver" 0, "Label" 1, "NviUpdater" 2, "CustomerNviLog" 3, "SimLock" 4, "RetailDriver" 5 (not accepted by `DeleteLogFile`). Other names → "Invalid parameter: LogFile.".

### eFuses

`sub_1001653C`, `sub_10016614`, `sub_100166F0`, `sub_100167CC` read the security feature bytes (`NPETSEC_ReadSecFeaSize`, then `NPETSEC_ReadSecFea`; size 0 → "ReadEFuseStatusSize is 0") and test one bit:

| Method | Byte | Bit |
|--------|------|-----|
| ReadPlatformSecureBootEnabled | 0 | 0x80 |
| ReadSHKEnabled | 0 | 0x20 |
| ReadSecureFfuEnabled | 1 | 0x40 |
| ReadDebugDisabled | 1 | 0x02 |

### DIAG (FlushNVData)

`FlushNVData` (`sub_1000419C`) creates a `QcDiag` object (`sub_10018660`, 32 bytes, vtable `off_1002F4AC`, exception class `QcDiag::ErrorDriver`) and calls its method +8 (`sub_100187E8`):

1. Open (`sub_10028014`): `CreateFileW(L"\\\\.\\DiagCSI", GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_FLAG_OVERLAPPED | FILE_ATTRIBUTE_NORMAL)`, an auto-reset event, then [IOCTL 0x80092440](../drivers/qcdiagcsi8930.md#ioctl-0x80092440) (register client) with `{1, hEvent, flags 2, types 7, 0}` (16 bytes). Then it waits until [IOCTL 0x80092448](../drivers/qcdiagcsi8930.md#ioctl-0x80092448) returns bit 1 (`DIAG_2` open), 5 s per wait (`WaitForSingleObject` on the event), and throws "Waiting for state changes failed" on timeout.
2. EFS2 hello (`sub_1002825C`) with [IOCTL 0x80092444](../drivers/qcdiagcsi8930.md#ioctl-0x80092444) (44-byte request, 6176-byte output): `4B 13 00 00` (DIAG subsystem command, subsystem 0x13 = EFS2, command 0 = hello), windows of 1 packet / 0x400 bytes for target, host and iterator, version 1, min 1, max 1, feature bits 0. The answer must start with `4B`; the maximum packet size it returns is kept.
3. `sub_100285C4`: EFS2 command 0x30 (`EFS2_DIAG_SYNC_NO_WAIT`) on "/", then command 0x31 (`EFS2_DIAG_SYNC_GET_STATUS`) with the returned token until it reports completion, at most 21 times, `Sleep(200)` between tries.

The object has an unused method +4 (`sub_100187BC` → `sub_10027F7C`): DIAG command `41` + 6-byte code (`DIAG_SPC_F`, send the service programming code); answer byte 1 = 0 → `E_INVALIDARG`.

### Battery (ReadBatteryLevel)

`sub_1001B0E4`: first interface of `GUID_DEVICE_BATTERY` `{72631e54-78a4-11d0-bcf7-00aa00b7b32a}` (`CM_Get_Device_Interface_ListW` with `CM_GET_DEVICE_INTERFACE_LIST_ALL_DEVICES`), `CreateFileW(GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, OPEN_EXISTING)`, then:

| IOCTL | Name | In / Out | Use |
|-------|------|----------|-----|
| 0x294040 | `IOCTL_BATTERY_QUERY_TAG` | 0 / 4 | Battery tag |
| 0x294044 | `IOCTL_BATTERY_QUERY_INFORMATION` | 12 / 36 | `BatteryInformation` → `FullChargedCapacity` |
| 0x29404C | `IOCTL_BATTERY_QUERY_STATUS` | 16 / 16 | `BATTERY_STATUS.Capacity` |

`BatteryLevel` = `Capacity / FullChargedCapacity × 100`, rounded (+0.5). The battery device is served by the battery class driver and the Qualcomm battery miniport (see [qcbattmngr8930.sys](../drivers/qcbattmngr8930.md) ?).

### ReadPrlId

`sub_10004EA0` builds a `CCellularPrl` ? object on the stack (`sub_1001B898`: mutex, two manual-reset events, three interface vtables at +0/+4/+8):

1. `CoInitializeEx(NULL, COINIT_MULTITHREADED)`, `CoCreateInstanceFromApp(CLSID {9d27b916-4f17-4ee8-a71c-d84222993d64}, NULL, CLSCTX_INPROC_SERVER, NULL, 1, &{IID {17ae6dc1-3723-4085-99ba-7160cdb8bfc1}})`, then method +0x0C of the interface with the object (registers a callback ?). A failure → "oemCellular init status." with the HRESULT.
2. `sub_1001BA7C`: waits up to 5 s for the "ready" event, then calls method +0x24 of the object received in the callback (object +0x10) with the callback interface (+4), a 12-byte request `{0x12, 4, 0x30004}`, 12 and 0x12, and waits up to 5 s for the answer event. Errors: 0x5B4 (`ERROR_TIMEOUT`) "Modem timeout.", 0x490 (`ERROR_NOT_FOUND`) "PRL ID not found.", other failure "Unknown error.".
3. The DWORD answer is formatted with `"%u"` into `PrlId`.

The COM server of this CLSID and the meaning of the request aren't known (the cellular OEM extension of the radio stack ?).

### IMS test mode

Verizon only: `PhoneMobileOperatorName` must be "VZW-US" ("IMS Test mode NOT allowed" / "Unable to get IMS Test mode status" otherwise).

- `SetImsTestMode` (`sub_1000B6BC`), `Setting` (bool ?): writes the modem EFS files `/nv/item_files/data/dsd/ds_apn_switching`, `/nv/item_files/ims/qp_ims_reg_config` and `/nv/item_files/modem/data/3gpp/lteps/attach_profile` (`NPETSEC_QcEfsFileRead` of the current data, then `sub_10015264` with type "Data"), checking the security mode with `NPETSEC_GetSecurityMode` first.
- `GetImsTestMode` (`sub_1000BC8C`): reads the same three files and returns `ImsTestModeStatus` (or "Unknown").

The byte values written aren't documented here.

### npetsec wrapper

`CNpetsec` vtable `off_1002F370` (constructor `sub_10017DC8`); each slot only forwards to one import:

| Slot | Function | Slot | Function |
|------|----------|------|----------|
| +0x04 | `NPETSEC_Init` | +0x50 | `NPETSEC_QcEfsDataFileWrite` |
| +0x08 | `NPETSEC_Deinit` | +0x54 | `NPETSEC_QcEfsFileDelete` |
| +0x0C | `NPETSEC_ReadBtId` | +0x58 | `NPETSEC_SetSecurityMode` |
| +0x10 | `NPETSEC_LastErrorStr` | +0x5C | `NPETSEC_GetSecurityMode` |
| +0x14 / +0x18 | `NPETSEC_ReadImeiRaw` / `NPETSEC_ReadImeiStr` | +0x60 | `NPETSEC_RdcPhoneReq` |
| +0x1C / +0x20 | `NPETSEC_ReadMeidRaw` / `NPETSEC_ReadMeidStr` | +0x64 | `NPETSEC_GetProductionData` |
| +0x24 | `NPETSEC_ReadWlanId` | +0x68 | `NPETSEC_RebootDevice` |
| +0x28 | `NPETSEC_ReadPublicId` | +0x6C | `NPETSEC_GetSimlockStatus` |
| +0x2C / +0x30 | `NPETSEC_ReadServiceTagSize` / `NPETSEC_ReadServiceTag` | +0x70 / +0x74 / +0x78 | `NPETSEC_GetSecurityLogFileSize` / `ReadSecurityLogFile` / `DeleteSecurityLogFile` |
| +0x34 | `NPETSEC_DppItemSize` | +0x7C | `NPETSEC_SetDriverLogging` |
| +0x38 | `NPETSEC_QcNvSpcUnlock` | +0x80 | `NPETSEC_RegItemValueWrite` |
| +0x3C | `NPETSEC_QcNvItemWrite` | +0x84 | `NPETSEC_IsProductionDone` |
| +0x40 | `NPETSEC_QcNvItemIndexedRead` | +0x88 / +0x8C | `NPETSEC_ReadSecFeaSize` / `NPETSEC_ReadSecFea` |
| +0x44 / +0x48 | `NPETSEC_QcEfsFileWrite` / `NPETSEC_QcEfsFileRead` | +0x90 | `NPETSEC_GetUefiCertStates` |
| +0x4C | `NPETSEC_QcEfsItemFileWrite` | +0x94 | `NPETSEC_ReadManufacturingData` |

`NPETSEC_QcEfsFileWrite` (+0x44) is imported but not used by any handler. The NV/EFS functions of `npetsec.dll` presumably go through [nokia_sec_driver.sys](../drivers/nokia_sec_driver.md), which talks to the modem through `\Device\DiagCSI` (npetsec.dll not analysed).

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\SYSTEM\Platform\DeviceTargetingInfo` | `PhoneManufacturer`, `PhoneROMVersion`, … `PhoneOEMSupportLink` (table of 16 names at `0x1003F090`, read by index with `sub_1001897C`) | Index 3 `PhoneMobileOperatorName` (`ReadOperatorName`, Verizon checks), 6 `PhoneManufacturerModelName`, 8 `PhoneSOCVersion`, 9 `PhoneFirmwareRevision` (`ReadSwVersion`, `ReadBspVersion`), 10 `PhoneRadioHardwareRevision` |
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion` | `CurrentBuildNumber` | `ReadAkVersion` |
| `HKLM\SYSTEM\Messaging\MMS` | `UAProf`, `UserAgentString` | `ReadMmsUAProf`, `ReadMmsUserAgentString` |
| `HKLM\SYSTEM\ControlSet001\services\NokiaBIFDriver` | `AuthSuccessCount`, `AuthFailedCount`, `AuthMaxTriesCount` (DWORD), `BatteryUID` (binary, size checked: "Invalid BatteryUID value size.") | `ReadHVBatteryAuth*`, `ReadHVBatteryUID` (battery interface / authentication driver, not documented here) |
| `HKLM\SOFTWARE\Microsoft\Shell\OOBE` | `NextSection`, `OobeCompleteTime` | `GetOobe*` |
| `HKLM\SOFTWARE\OEM\Nokia\NCSd` | `RefurbishStatus` | Read and written (`SetRefurbishStatus`, the only registry write) |
| `HKLM\SOFTWARE\OEM\Nokia\Variant` | `LabelID`, `ConfigurationID` | `ReadLabelID`, `ReadConfigurationID` |
