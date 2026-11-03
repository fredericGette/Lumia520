## qcvidencmftmpeg48930.dll

Hardware Media Foundation transform (MFT) of the MSM8930 that encodes MPEG-4 part 2 video: "QC MPEG4 Encode HW-MFT", build `P:\QCVidEncMFT\rel\8.2.1.1\arm\Release\qcvidencmftmpeg48930.pdb`.  
`qcvidencmftmpeg48930.dll` is the MPEG-4 build of Qualcomm's generic "VENC HWMFT" (`CQCVideoEncoderMft`), the same source as the H.263 and H.264 encoders [qcvidencmfth2638930.dll](./qcvidencmfth2638930.md) and [qcvidencmfth2648930.dll](./qcvidencmfth2648930.md): same size (263 168 bytes), same 249 functions at the same addresses. Its `.rdata` is laid out differently (about 94 000 bytes differ, and the `.text` differs only in the literal pools that point into it). The real differences are the CLSID accepted by the class factory and registered, `{8EB787DC-D1B6-421D-88A0-22539F9F12C3}`, and the media types given to `MFTRegister` (output `M4S2`). The codec type is therefore 4 (MPEG-4). It enables the code paths that the two other builds never reach: two output subtypes (`M4S2`, `MP4V`), the MPEG-4 profile, and an MPEG-4 sample description built from the VOL header.  
Like the other builds, it takes NV12 / `420O` frames and drives the MPEG-4 [encoder device](./qcvidum8930.md#encoder-devices) `{CBB1A2A4-4EA1-491E-ADC9-70B373B76036}` of [qcvidum8930.dll](./qcvidum8930.md) with `ID3D11VideoContext::DecoderExtension` commands; qcvidum8930.dll forwards them to the VIDEO engine of [qcdxkm8930.sys](../drivers/qcdxkm8930.md). The matching decoder is [qcviddecmft8930.dll](./qcviddecmft8930.md). The process that loads it (the media pipeline of the camera / video recording apps, MP4 / 3GP ?) isn't known.

Location on the phone: ?  

### Imports

Same functions as [qcvidencmfth2638930.dll](./qcvidencmfth2638930.md#imports), in a different order in the import table:

| DLL | Functions |
|-----|-----------|
| MFPlat.dll | `MFTRegister`, `MFTUnregister`, `MFCreateAttributes`, `MFCreateMediaType`, `MFCreateEventQueue`, `MFCreateMediaEvent`, `MFCreateTrackedSample`, `MFCreateMemoryBuffer`, `MFCreateDXGIDeviceManager`, `MFInitMediaTypeFromVideoInfoHeader` |
| d3d11.dll | `D3D11CreateDevice` |
| bcrypt.dll | `BCryptOpenAlgorithmProvider`, `BCryptCloseAlgorithmProvider`, `BCryptGenRandom`, `BCryptGetProperty`, `BCryptSetProperty`, `BCryptImportKey`, `BCryptImportKeyPair`, `BCryptDestroyKey`, `BCryptEncrypt`, `BCryptDecrypt` |
| OLEAUT32.dll | `SysAllocString`, `VariantInit`, `VariantCopy` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCreateKeyExW`, `RegSetValueExW`, `RegOpenKeyExW`, `RegQueryValueExW`, `RegDeleteTreeW`, `RegCloseKey` |
| api-ms-win-core-com-l1-1-0.dll | `CoTaskMemAlloc`, `CoTaskMemFree`, `PropVariantClear`, `StringFromCLSID` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `CreateMutexW`, `ReleaseMutex` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-libraryloader-l1-1-1.dll | `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-errorhandling-l1-1-1.dll | `GetLastError`, `RaiseException` |
| api-ms-win-core-string-l1-1-0.dll | `MultiByteToWideChar`, `WideCharToMultiByte` |
| api-ms-win-core-debug-l1-1-1.dll | `OutputDebugStringW` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter`, `QueryPerformanceFrequency` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-eventing-classicprovider-l1-1-0.dll | `RegisterTraceGuidsW`, `UnregisterTraceGuids`, `GetTraceLoggerHandle`, `GetTraceEnableLevel`, `GetTraceEnableFlags`, `TraceMessage` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-processthreads-l1-1-1.dll | `GetCurrentThreadId` |
| api-ms-win-core-sysinfo-l1-2-0.dll | `GetTickCount64`, `GetSystemTimeAsFileTime` |
| MSVCR110.dll | `memset`, `memcpy`, `memcpy_s`, `memcmp`, `strlen`, `wcsstr`, `malloc`, `free`, `operator new`/`delete` (`??2@YAPAXI@Z`, `??3@YAXPAX@Z`, `??_U@YAPAXI@Z`, `??_V@YAXPAX@Z`), `sprintf_s`, `vsprintf_s`, `fprintf_s`, `wcstombs_s`, `fopen_s`, `fwrite`, `fflush`, `fclose`, `_time64`, `_errno`, `_initterm`, `_initterm_e`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_malloc_crt`, `_calloc_crt`, `_amsg_exit`, `__CxxFrameHandler3`, `__C_specific_handler`, `__CppXcptFilter`, `__clean_type_info_names_internal` |

The util, processthreads and sysinfo imports and the CRT startup functions of MSVCR110 are the Visual C++ 2012 DLL startup and `/GS` security cookie code. The classic-provider functions are the WPP tracing. The `stdio` functions, `OutputDebugStringW` and the mutex are the [debug log](./qcvidencmfth2638930.md#debug-log-and-dumps).

### Dependencies

No DLL is loaded at run time, no process is started and no COM object is created with `CoCreateInstance`.

| File | How | Use |
|------|-----|-----|
| `ID3D11Device` / `ID3D11VideoDevice` / `ID3D11VideoContext` | from the `IMFDXGIDeviceManager` given by `MFT_MESSAGE_SET_D3D_MANAGER`, otherwise its own device (`D3D11CreateDevice` + `MFCreateDXGIDeviceManager`) | The MPEG-4 encoder device of [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) (`CreateVideoDecoder` `{CBB1A2A4…}`, `dword_10026150`), the input / output textures |
| `<VEncLogFilePath>\VEncHWMFTLog<time>.txt` | `fopen_s` | [Debug log](./qcvidencmfth2638930.md#debug-log-and-dumps) |
| `<VEncLogFilePath>\VEncInputDump<time>_<this>.raw`, `…\VEncOutputDump<time>_<this>.raw` | `fopen_s`, `fwrite` | Dumps of the input frames / MPEG-4 bitstream when `VEncInputDump` / `VEncOutputDump` are set |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x10002280 | none |
| 2 | `DllGetClassObject` | 0x100022A0 | `REFCLSID, REFIID, void **` |
| 3 | `DllRegisterServer` | 0x10002384 | none |
| 4 | `DllUnregisterServer` | 0x100026A0 | none |

`DllGetClassObject` (0x10002008) accepts only `{8EB787DC-D1B6-421D-88A0-22539F9F12C3}` (`dword_100262A0`); any other CLSID returns `CLASS_E_CLASSNOTAVAILABLE` (0x80040111). The class factory (vtable `off_100262C0`), `CQCVideoEncoderMft::CreateInstance` (`sub_10003E48`), the 0x22F0-byte object and its interfaces are those of [qcvidencmfth2638930.dll](./qcvidencmfth2638930.md#mft-object).

The codec selection `sub_10003FBC` finds `{8EB787DC…}` (its third test) and sets:
- the codec type (+0x2250) to 4 ("CodecType: MPEG4");
- `MFT_ENUM_HARDWARE_URL_Attribute` to `QCOM Hardware Encoder - MPEG4`;
- two output subtypes, `M4S2` at +0x229C and `MP4V` at +0x22AC;
- the subtype count (+0x22EC) to 2.

The count +0x22EC is the limit of `GetOutputAvailableType` (`sub_10008210`): index 0 gives `M4S2` and index 1 gives `MP4V`; a higher index returns `MF_E_NO_MORE_TYPES` (0xC00D36B9). Both types carry `MF_MT_MPEG2_PROFILE` = 0 and `MF_MT_MPEG2_LEVEL` = 0. For comparison, the H.264 and H.263 builds set the count to 1, and the VC-1 branch (`WMV3`, `WVC1`) to 2.

### Startup

`start` (`_DllMainCRTStartup`, 0x10023048): the usual CRT startup with `__security_init_cookie`. `DllMain` (`sub_10002228`): on `DLL_PROCESS_ATTACH` it keeps the module handle (`dword_1003FCBC`) and calls `DisableThreadLibraryCalls`; nothing else. The ETW and WPP providers are registered by the first object, see [ETW](#etw).

### Registry

`DllRegisterServer` writes the same 7 `REG_SZ` values as the H.263 build under `HKEY_LOCAL_MACHINE` (`sub_100022B0`), then calls `MFTRegister`:

| Key | Value | Data |
|-----|-------|------|
| `Software\Classes\CLSID\{8EB787DC-D1B6-421D-88A0-22539F9F12C3}` | (default) | `QCOM Hardware Encoder - MPEG4` |
| `…\InProcServer32` | (default) | Path of the DLL (`GetModuleFileNameW`) |
| same | `ThreadingModel` | `Both` |
| same | `ERROR` | `1` |
| same | `HIGH`, `MED`, `LOW` | `0` (never read by the DLL) |

The call is `MFTRegister(CLSID, MFT_CATEGORY_VIDEO_ENCODER {F79EAC7D-E545-4387-BDEE-D647D7BDE42A}, "QCOM Hardware Encoder - MPEG4", 4 = MFT_ENUM_FLAG_HARDWARE, 2 input types, 1 output type, attributes)`:
- input types: `MFMediaType_Video` + `NV12`, `420O` (the order of the H.263 build);
- output type: `MFMediaType_Video` + `M4S2` only (`MP4V` isn't registered, but it is offered by `GetOutputAvailableType` and accepted by `SetOutputType`);
- the 11 registration attributes are those of the [attributes](./qcvidencmfth2638930.md#attributes) table, with `MFT_ENUM_HARDWARE_URL_Attribute` = `QC MPEG4 Encode HW-MFT`, `MFT_OUTPUT_TYPES_Attributes` = `M4S2`, `MFT_CODEC_MERIT_Attribute` = 7 and `MFT_TRANSFORM_CLSID_Attribute` = `{8EB787DC…}`.

On failure the messages are `MPEG4 Enc DllRegisterServer : : DllRegisterServer MFCreateAttributes failed` and `DllRegisterServer: MPEG4 MFTRegister failed hr 0x%0x`.

`DllUnregisterServer` deletes `Software\Classes\CLSID\{8EB787DC-…}` (`RegDeleteTreeW`, `ERROR_FILE_NOT_FOUND` ignored) and calls `MFTUnregister` (`HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)` ignored).

The run-time configuration under `HKEY_LOCAL_MACHINE\Software\QCOM\MFTs\VideoEncoder` (`VEncLogMsgMask`, `VEncLogFilePath`, `VEncSliceMode`, `VEncSliceSize`, `VEncOutputSurfaceCount`, `VEncDisableEncoding`…) is the same as in the [H.263 build](./qcvidencmfth2638930.md#registry). The `EnableMotionDump` and `SwVenc*Dump` values are only read when the subtype is `WMV3`, so never here. `InitializeHardware` (`sub_10009128`, test at 0x10009950) only applies the `720P…`, `1080P…` and `FWVGA…` bitrates for codec type 1, so they have no effect on this build either.

### MPEG-4 defaults

`InitializeDefaultConfiguration` (`sub_10005014`) fills the 0x78-byte [base configuration](./qcvidencmfth2638930.md#base-configuration) (+0x18D4 of the object). The `M4S2` branch (0x1000530C) then joins the H.263 code (0x10005464). The values are the same as for H.263:

| Offset | Value | Comment |
|--------|-------|---------|
| 0x00, 0x04 | 640, 480 | Width, height |
| 0x08 | 640 | Stride |
| 0x1C, 0x20 | 1, 30 | Frame rate 30/1 |
| 0x24, 0x28 | 0, 0 | Profile 0 (see [Profile](#profile)), level 0 |
| 0x2C | 2 | Rate control mode |
| 0x30 | 59 | GOP distance |
| 0x34 | 8 | QP |
| 0x38, 0x3C | 1 536 000, 0 | Mean bitrate, from the [default bitrate table](./qcvidencmfth2648930.md#h264-defaults) for 640 × 480 (`unk_1003F1F0`; the fallback constant 0x177000 is the same value), peak bitrate |
| 0x40 | 1 | Byte; `EnableMotionDump` in the debug dump |
| 0x54 | 100 | Quality vs speed |
| 0x64, 0x68 | 1, 0 | Slice mode, slice size (then `VEncSliceMode` / `VEncSliceSize`) |
| 0x6C | 0 | Request flags (NAL unit mode is H.264 only) |

### Profile

`setProfile` (`sub_10020C88`) has a branch for codec type 4 (0x10020EE8). It reads `MF_MT_SUBTYPE` `{F7E34C9A-42E8-4714-B74B-CB29D72C35E5}` of the output type (`GetGUID`):
- the subtype can't be read: profile 0 and "Subtype not set in output type";
- `M4S2`: profile (+0x24 of the base configuration) set to 0;
- any other subtype (`MP4V`): the current profile is kept, with "Unable to set MPEG4 profile.  Using Default value: %d".

Unlike the H.264 branch, `MF_MT_MPEG2_PROFILE` is never read, so the profile is always 0. `setLevel` (`sub_10020AC4`) only works for codec type 1, so the level (+0x28) stays 0. `ValidateOutputType` (`sub_1000A1B4`) sets the codec type to 4 for both `M4S2` and `MP4V`. It reads `MF_MT_MPEG2_LEVEL` and `MF_MT_MPEG2_PROFILE`, but the range check is only made for H.264.

[qcvidum8930.dll](./qcvidum8930.md#encoder-devices) turns profile 0 into the encoder type 6 (profile 1, type 7, is never sent by this MFT). Its MPEG-4 level switch (0x10025ABE) maps 1–7 to 0x10–0x16 and returns `E_FAIL` above 7. The level 0 sent by this MFT is case 0 of that switch: it is sent as 0 at `+0x48` of escape 0x2200, the value H.264 also gets for level 0 or an unknown level. [qcdxkm8930.sys](../drivers/qcdxkm8930.md#encoder-session-setup) then chooses the level itself (`sub_4BE028`): the first Simple-profile level whose limits {bitrate, macroblocks/s, macroblocks per frame} hold the session: {64 000, 1485, 99} → level 1, {128 000, 5940, 396} → level 2, {384 000, 11880, 396} → level 3, else level 3. It writes it to the video core register `VIDC_PROFILE` as `profile_and_level_indication` level 1, 2 or 3 (profile 0). The [video firmware](../drivers/qcdxkm8930.md#video-firmware) copies it into the visual object sequence header of the bitstream (0x01–0x03; 0x08, Simple level 0, would only be written for level 0). With the default 640 × 480 at 30 fps, no row fits (1200 macroblocks), so the stream announces Simple level 3 although its frames exceed that level's 396 macroblocks. The firmware's own level check (status 182, frame too large) doesn't seem to run at a normal start (?).

### Sequence header and sample description

After `D3D_VIDENC_CMD_START_ENCODER`, `InitializeHardware` waits up to 5 s for the `D3D_VIDENC_CB_TYPE_SEQHDR` [callback](./qcvidencmfth2638930.md#umd-callback-sub_10019bc0). `ProcessSeqHdrCb` (`sub_100199D4`) keeps the header for codec types 1 and 4 (at most 0x200 bytes; size at +0x1A00, data at +0x1A04). For MPEG-4 this is the VOS / VO / VOL header.

Unlike the H.264 build, the header isn't set as `MF_MT_MPEG_SEQUENCE_HEADER`: that `SetBlob` (0x1000A06C) is only done for codec type 1. For codec types 3 and 4, `InitializeHardware` calls `OnOutputTypeChanged` (`sub_10020FE0`). For MPEG-4, it:
1. builds an ISO / 3GPP sample description on the stack. It copies the 0x8B-byte template `unk_1003F050`, then the header, then the 3 bytes `06 01 02` (`unk_1003F050`+0xB4: `SLConfigDescriptor`, predefined 2);
2. patches the template (table below);
3. sets it on the output type as `MF_MT_MPEG4_SAMPLE_DESCRIPTION` `{261E9D83-9529-4B8F-A111-8B9C950A81A9}` (`SetBlob`);
4. sets `MF_MT_MPEG4_CURRENT_SAMPLE_ENTRY` `{9AA7E155-B64A-4C1D-A500-455D600B6560}` = 0. "Setting Sample Description: %d" gives the size.

| Offset | Size | Content |
|--------|------|---------|
| 0x00 | 4 | `stsd` box size, big-endian: only the low byte is patched, to header size + 0x8E (the size of the whole blob) |
| 0x04 | 4 | `stsd`, version / flags 0, 1 entry |
| 0x0C | 4 | `mp4v` entry size: only the low byte is patched, to header size + 0x7E (4 less than the bytes that follow it, ?) |
| 0x10 | 4 | `mp4v`, data reference index 1 |
| 0x30, 0x32 | 2 + 2 | Width, height, big-endian, from the bytes of +0x17E8 and +0x17EC of the object (template: 176 × 144) |
| 0x34 | 8 | Resolution 0x00480000 / 0x00480000 (72 dpi), frame count 1, depth 0x18, pre-defined -1 |
| 0x66 | 0x46 | `esds` box (fixed size 0x46) |
| 0x72 | 3 + 3 | `ES_Descriptor` (tag 3, length 0x37), ES_ID 1, flags 0 |
| 0x78 | 3 + 2 | `DecoderConfigDescriptor` (tag 4, length 0x2E), object type 0x20 (MPEG-4 Visual), stream type 0x11 (visual) |
| 0x7D | 3 | Buffer size: 0 |
| 0x80 | 4 | Max bitrate, big-endian, from the peak bitrate (+0x3C of the base configuration) |
| 0x84 | 4 | Average bitrate, big-endian, from the mean bitrate (+0x38) |
| 0x88 | 3 | `DecoderSpecificInfo` (tag 5, length 0x1E) |
| 0x8B | header size | The sequence header |
| 0x8B + size | 3 | `SLConfigDescriptor` `06 01 02` |

The descriptor lengths and the `esds` size are fixed: they are only right for a 30-byte (0x1E) VOL header. The H.263 build uses the same function with a fixed 0x75-byte `s263` entry (`unk_1003F050`+0xB8, with a `d263` box, vendor `Qcom`), patched in place with the width and height.

### ICodecAPI

`IsSupported` / `IsModifiable` (`sub_1000DA14`, `sub_1000DCFC`) use the MPEG-4 table `unk_1003F978` (12 entries of 20 bytes {GUID, modifiable while streaming}) when the subtype at +0x2290 is `M4S2`. Its content is the same as the [H.263 table](./qcvidencmfth2638930.md#icodecapi) `unk_1003F478`. Modifiable while streaming: `CODECAPI_AVEncCommonMaxBitRate`, `CODECAPI_AVEncMPVGOPSize`, `CODECAPI_AVEncCommonMeanBitRate`, `CODECAPI_AVEncVideoForceKeyFrame`, `CODECAPI_AVEncVideoEncodeQP` and `CODECAPI_DropNumFrames`. Not modifiable: rate control mode, quality, quality vs speed, buffer size, `CODECAPI_AVEncCommonLowLatency` and `CODECAPI_AVLowLatencyMode`. With `MP4V` as the subtype, none of the tables is chosen (`unk_1003F568` is the VC-1 one, for `WVC1` / `WMV3`), so `IsSupported` reports no property at all.

### Shared implementation

Everything else is the code of [qcvidencmfth2638930.dll](./qcvidencmfth2638930.md), at the same addresses, with the codec type 4:

- [MFT object](./qcvidencmfth2638930.md#mft-object), [attributes](./qcvidencmfth2638930.md#attributes) and [IMFTransform](./qcvidencmfth2638930.md#imftransform) methods;
- [ProcessMessage](./qcvidencmfth2638930.md#processmessage-sub_1000c228) and the [encoder start](./qcvidencmfth2638930.md#encoder-start-initializehardware-sub_10009128). The encoder GUID chosen from the `M4S2` or `MP4V` subtype is `{CBB1A2A4-4EA1-491E-ADC9-70B373B76036}`, checked by `ValidateEncProfileConfig` (`sub_10016064`);
- the [DecoderExtension commands](./qcvidencmfth2638930.md#decoderextension-commands), the [encoding](./qcvidencmfth2638930.md#encoding) path, the [encode frame](./qcvidencmfth2638930.md#encode-frame) parameters and the [UMD callback](./qcvidencmfth2638930.md#umd-callback-sub_10019bc0) `VideoUMDCb` (`sub_10019BC0`);
- [IOPMVideoOutput](./qcvidencmfth2638930.md#iopmvideooutput): same certificate and RSA key, merit 7;
- [debug log and dumps](./qcvidencmfth2638930.md#debug-log-and-dumps).

### ETW

Same providers as the H.263 build:
- manifest provider `{CABA4C43-CDA9-4E5B-BF10-48FB256C8138}` (`unk_100261F0`; events 106–123, level 4, keyword 0x2, see [ETW](./qcvidencmfth2638930.md#etw));
- WPP provider `{CEA35F95-03DB-4F70-A5C2-25E3ACA61E2A}`.

### COM

| GUID | Use |
|------|-----|
| `{8EB787DC-D1B6-421D-88A0-22539F9F12C3}` | CLSID of the MFT |
| `{7790EE16-08E3-426D-AADA-F96774308EA1}`, `{ED93D261-C7CC-46E2-AE09-3CE7AE5C4ABC}`, `{670E88D4-B18A-483A-8E0F-65A027838718}` | CLSIDs of the H.264 ([qcvidencmfth2648930.dll](./qcvidencmfth2648930.md)), VC-1 (not analysed) and H.263 ([qcvidencmfth2638930.dll](./qcvidencmfth2638930.md)) encoders of the same family, not registered here |
| `{F79EAC7D-E545-4387-BDEE-D647D7BDE42A}` | `MFT_CATEGORY_VIDEO_ENCODER` |
| `{CBB1A2A4-4EA1-491E-ADC9-70B373B76036}` | MPEG-4 encoder device of [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) |
| `{F7E34C9A-42E8-4714-B74B-CB29D72C35E5}` | `MF_MT_SUBTYPE`, read by `setProfile` |
| `{261E9D83-9529-4B8F-A111-8B9C950A81A9}`, `{9AA7E155-B64A-4C1D-A500-455D600B6560}` | `MF_MT_MPEG4_SAMPLE_DESCRIPTION`, `MF_MT_MPEG4_CURRENT_SAMPLE_ENTRY` |
| `{AD76A80B-2D5C-4E0B-B375-64E520137036}`, `{96F66574-11C5-4015-8666-BFF516436DA7}` | `MF_MT_MPEG2_PROFILE`, `MF_MT_MPEG2_LEVEL` (set to 0 on the available types) |
| `{FB8D8600-25C3-435E-94C5-A4B50397EC46}`, `{B27227A5-59FB-4BFC-AF1E-42237F213DBC}` | Input formats NV12_16M2KA (linear) and TILE_4X2, [base configuration](./qcvidencmfth2638930.md#base-configuration) +0x0C |
