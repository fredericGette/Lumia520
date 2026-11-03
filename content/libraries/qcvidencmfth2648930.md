## qcvidencmfth2648930.dll

Hardware Media Foundation transform (MFT) of the MSM8930 that encodes H.264 video: "QC H264 Encode HW-MFT", build `P:\QCVidEncMFT\rel\8.2.1.1\arm\Release\qcvidencmfth2648930.pdb`.  
`qcvidencmfth2648930.dll` is the H.264 build of Qualcomm's generic "VENC HWMFT" (`CQCVideoEncoderMft`), the same source as the H.263 encoder [qcvidencmfth2638930.dll](./qcvidencmfth2638930.md): same size (263 168 bytes), same 249 functions at the same addresses. The only differences in the code are the CLSID accepted by the class factory and registered, `{7790EE16-08E3-426D-AADA-F96774308EA1}`, and the media types given to `MFTRegister` (output `H264`). The codec type is therefore always 1 (H.264), which enables the code paths that the H.263 build never reaches: profile and level, the sequence header (SPS / PPS) put on the output type, the NAL unit mode and temporal layers.  
Like the H.263 build, it takes NV12 / `420O` frames and drives the H.264 [encoder device](./qcvidum8930.md#encoder-devices) `{129F7B40-5C5B-48E5-8178-48C0CEA05A90}` of [qcvidum8930.dll](./qcvidum8930.md) with `ID3D11VideoContext::DecoderExtension` commands; qcvidum8930.dll forwards them to the VIDEO engine of [qcdxkm8930.sys](../drivers/qcdxkm8930.md). The process that loads it (the media pipeline of the camera / video recording apps ?) isn't known.

Location on the phone: ?  

### Imports

Same functions as [qcvidencmfth2638930.dll](./qcvidencmfth2638930.md#imports), in a different order in the import table (only the import thunks at 0x10022A44–0x10022BE8 differ):

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

The util, processthreads and sysinfo imports and the CRT startup functions of MSVCR110 are the Visual C++ 2012 DLL startup and `/GS` security cookie code. The classic-provider functions are the WPP tracing; the `stdio` functions, `OutputDebugStringW` and the mutex are the [debug log](./qcvidencmfth2638930.md#debug-log-and-dumps).

### Dependencies

No DLL is loaded at run time, no process is started and no COM object is created with `CoCreateInstance`.

| File | How | Use |
|------|-----|-----|
| `ID3D11Device` / `ID3D11VideoDevice` / `ID3D11VideoContext` | from the `IMFDXGIDeviceManager` given by `MFT_MESSAGE_SET_D3D_MANAGER`, otherwise its own device (`D3D11CreateDevice` + `MFCreateDXGIDeviceManager`) | The H.264 encoder device of [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) (`CreateVideoDecoder` `{129F7B40…}`), the input / output textures |
| `<VEncLogFilePath>\VEncHWMFTLog<time>.txt` | `fopen_s` | [Debug log](./qcvidencmfth2638930.md#debug-log-and-dumps) |
| `<VEncLogFilePath>\VEncInputDump<time>_<this>.raw`, `…\VEncOutputDump<time>_<this>.raw` | `fopen_s`, `fwrite` | Dumps of the input frames / H.264 bitstream when `VEncInputDump` / `VEncOutputDump` are set |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x10002280 | none |
| 2 | `DllGetClassObject` | 0x100022A0 | `REFCLSID, REFIID, void **` |
| 3 | `DllRegisterServer` | 0x10002384 | none |
| 4 | `DllUnregisterServer` | 0x100026A0 | none |

`DllGetClassObject` (0x10002008) accepts only `{7790EE16-08E3-426D-AADA-F96774308EA1}` (`dword_10026170`), else `CLASS_E_CLASSNOTAVAILABLE` (0x80040111). The class factory, `CQCVideoEncoderMft::CreateInstance` (`sub_10003E48`), the 0x22F0-byte object and its interfaces are those of [qcvidencmfth2638930.dll](./qcvidencmfth2638930.md#mft-object). The codec selection `sub_10003FBC` finds `{7790EE16…}` and sets the codec type (+0x2250) to 1, `MFT_ENUM_HARDWARE_URL_Attribute` to `QCOM Hardware Encoder - H264` and the output subtype (+0x229C) to `H264`.

### Startup

`start` (`_DllMainCRTStartup`, 0x10023048): the usual CRT startup with `__security_init_cookie`. `DllMain` (`sub_10002228`): on `DLL_PROCESS_ATTACH` it keeps the module handle and calls `DisableThreadLibraryCalls`; nothing else. The ETW and WPP providers are registered by the first object, see [ETW](#etw).

### Registry

`DllRegisterServer` writes the same 7 `REG_SZ` values as the H.263 build under `HKEY_LOCAL_MACHINE`, then calls `MFTRegister`:

| Key | Value | Data |
|-----|-------|------|
| `Software\Classes\CLSID\{7790EE16-08E3-426d-AADA-F96774308EA1}` | (default) | `QCOM Hardware Encoder - H264` |
| `…\InProcServer32` | (default) | Path of the DLL (`GetModuleFileNameW`) |
| same | `ThreadingModel` | `Both` |
| same | `ERROR` | `1` |
| same | `HIGH`, `MED`, `LOW` | `0` (never read by the DLL) |

`MFTRegister(CLSID, MFT_CATEGORY_VIDEO_ENCODER {F79EAC7D-E545-4387-BDEE-D647D7BDE42A}, "QCOM Hardware Encoder - H264", 4 = MFT_ENUM_FLAG_HARDWARE, 2 input types, 1 output type, attributes)`. Input types: `MFMediaType_Video` + `420O` (Qualcomm's opaque NV12), `NV12` (the opposite order of the H.263 build); output type: `MFMediaType_Video` + `H264`. The 11 registration attributes are those of the [attributes](./qcvidencmfth2638930.md#attributes) table, with `MFT_ENUM_HARDWARE_URL_Attribute` = `QC H264 Encode HW-MFT`, `MFT_OUTPUT_TYPES_Attributes` = `H264`, `MFT_CODEC_MERIT_Attribute` = 7 and `MFT_TRANSFORM_CLSID_Attribute` = `{7790EE16…}`. On failure the messages are `H264Enc : DllRegisterServer MFCreateAttributes failed` and `DllRegisterServer: H264 MFTRegister failed hr 0x%0x`.

`DllUnregisterServer` deletes `Software\Classes\CLSID\{7790EE16-…}` (`RegDeleteTreeW`) and calls `MFTUnregister`.

The run-time configuration under `HKEY_LOCAL_MACHINE\Software\QCOM\MFTs\VideoEncoder` (`VEncLogMsgMask`, `VEncLogFilePath`, `VEncSliceMode`, `VEncSliceSize`, `VEncOutputSurfaceCount`, `720PTargetBitRate`, `1080PTargetBitRate`, `VEncDisableEncoding`…) is the same as in the [H.263 build](./qcvidencmfth2638930.md#registry). The `EnableMotionDump` and `SwVenc*Dump` values are only read when the subtype is `WMV3`, so never here.

### H.264 defaults

`InitializeDefaultConfiguration` (`sub_10005014`) fills the 0x78-byte [base configuration](./qcvidencmfth2638930.md#base-configuration) (+0x18D4 of the object). The H.264 branch (output subtype `H264`) gives:

| Offset | Value | Comment |
|--------|-------|---------|
| 0x00, 0x04 | 1280, 720 | Width, height |
| 0x08 | 1280 | Stride (H.263: the width too, 640) |
| 0x1C, 0x20 | 1, 30 | Frame rate 30/1 (all codecs) |
| 0x24, 0x28 | 0, 0 | Profile 0 (Baseline, see [Profile and level](#profile-and-level)), level 0 |
| 0x2C | 2 | Rate control mode (all codecs) |
| 0x30 | 59 | GOP distance (all codecs) |
| 0x34 | 24 | QP (H.263: 8) |
| 0x38, 0x3C | 8 000 000, 0 | Mean bitrate, from the default bitrate table for 1280 × 720 (`unk_1003F1F0`, below; 0x800000 = 8 388 608 if the size weren't in it), peak bitrate |
| 0x40 | 0 | Byte (H.263: 1); `EnableMotionDump` in the debug dump |
| 0x54 | 100 | Quality vs speed (all codecs) |
| 0x64, 0x68 | 1, 0 | Slice mode, slice size (all codecs, then `VEncSliceMode` / `VEncSliceSize`) |
| 0x6C | bit 0 set | Request flags: bit 0 is the NAL unit mode, see [ICodecAPI](#icodecapi) |

The field +0x1C60 of the object is also set to 1 for H.264 (?).

Default bitrate table (`unk_1003F1F0`, 10 entries {width, height, bits/s}), used when the output type has no `MF_MT_AVG_BITRATE`:

| Size | Bitrate |
|------|---------|
| 80 × 48 | 32 000 |
| 96 × 80 | 64 000 |
| 128 × 96 | 96 000 |
| 176 × 144 | 192 000 |
| 320 × 240 | 512 000 |
| 352 × 288 | 720 000 |
| 640 × 480 | 1 536 000 |
| 800 × 480 | 2 048 000 |
| 1280 × 720 | 8 000 000 |
| 1920 × 1080 | 12 000 000 |

The 720p, 1080p and FWVGA registry values (`720PTargetBitRate`…) override it for these sizes.

### Profile and level

`setLevel` (`sub_10020AC4`) is only active for codec type 1; `setProfile` (`sub_10020C88`) also has a VC-1 and an MPEG-4 branch (see [qcvidencmftmpeg48930.dll](./qcvidencmftmpeg48930.md#profile)), never reached here. They are called by `InitializeHardware` (`sub_10009128`) and when the output type is built or checked (`AddCodecPropertiesToOutputType`, `sub_100102BC`).

`setProfile` reads `MF_MT_MPEG2_PROFILE` `{AD76A80B-2D5C-4E0B-B375-64E520137036}` of the output type and looks it up in `unk_1003F0DC` (5 pairs {`eAVEncH264VProfile`, internal value}). The result goes to +0x24 of the base configuration, which [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) turns into the codec type 1–5 of escape 0x2200. When the type has no profile, the current value is written back to the type (`SetUINT32`); an unknown profile is only traced (`setProfile` error 0x40E) and the current value is kept.

| `MF_MT_MPEG2_PROFILE` | Profile | +0x24 |
|-----------------------|---------|-------|
| 66 | `eAVEncH264VProfile_Base` | 0 |
| 256 | `eAVEncH264VProfile_ConstrainedBase` (?) | 1 |
| 77 | `eAVEncH264VProfile_Main` | 2 |
| 100 | `eAVEncH264VProfile_High` | 3 |
| 257 | `eAVEncH264VProfile_UCConstrainedHigh` (?) | 4 |

`setLevel` reads `MF_MT_MPEG2_LEVEL` `{96F66574-11C5-4015-8666-BFF516436DA7}`. Level `0xFFFFFFFF` means "use the default". Any other value is looked up in `dword_1003F268` (16 pairs {`eAVEncH264VLevel`, internal value}) and the result goes to +0x28. When the type has no level, the current value is written back if it is in the table.

| `MF_MT_MPEG2_LEVEL` | 10 | 11 | 12 | 13 | 20 | 21 | 22 | 30 | 31 | 32 | 40 | 41 | 42 | 50 | 51 |
|---------------------|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|
| +0x28 | 2 | 3 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |

The table has two entries for 11 (level 1b and 1.1 share the value 11 in `eAVEncH264VLevel`): 11 → 3 matches first, so 4 is never used. qcvidum8930.dll maps the internal levels 2–16 to 1–15; any other value, such as level 5.1 (17), isn't an error but is sent to the KMD as 0, like the internal level 0 (see [encoder devices](./qcvidum8930.md#encoder-devices)).

### Sequence header

After `D3D_VIDENC_CMD_START_ENCODER`, `InitializeHardware` waits up to 5 s for the `D3D_VIDENC_CB_TYPE_SEQHDR` [callback](./qcvidencmfth2638930.md#umd-callback-sub_10019bc0). `ProcessSeqHdrCb` (`sub_100199D4`) keeps the header for codec types 1 and 4 (at most 0x200 bytes, size at +0x1A00, data at +0x1A04). For H.264 this is the SPS / PPS, which `InitializeHardware` puts on the output type as `MF_MT_MPEG_SEQUENCE_HEADER` (`IMFMediaType::SetBlob`) for the downstream multiplexer.

### ICodecAPI

`IsSupported` / `IsModifiable` (`sub_1000DA14`, `sub_1000DCFC`) use the H.264 table `unk_1003F348` (15 entries of 20 bytes {GUID, modifiable while streaming}) when the subtype at +0x2290 is `H264`. It has the 12 properties of the [H.263 table](./qcvidencmfth2638930.md#icodecapi) plus 3:

| Property | Modifiable |
|----------|------------|
| `CODECAPI_AVEncCommonRateControlMode` `{1C0608E9-370C-4710-8A58-CB6181C42423}` | no |
| `CODECAPI_AVEncCommonMaxBitRate` `{9651EAE4-39B9-4EBF-85EF-D7F444EC7465}` | yes, `D3D_VIDENC_PROP_SET_PEAKBITRATE` |
| `CODECAPI_AVEncCommonQuality` `{FCBF57A3-7EA5-4B0C-9644-69B40C39C391}` | no |
| `CODECAPI_AVEncCommonQualityVsSpeed` `{98332DF8-03CD-476B-89FA-3F9E442DEC9F}` | no |
| `CODECAPI_AVEncMPVGOPSize` `{95F31B26-95A4-41AA-9303-246A7FC6EEF1}` | yes, `D3D_VIDENC_PROP_SET_GOPDISTANCE` |
| `CODECAPI_AVEncCommonBufferSize` `{0DB96574-B6A4-4C8B-8106-3773DE0310CD}` | no |
| `CODECAPI_AVEncCommonMeanBitRate` `{F7222374-2144-4815-B550-A37F8E12EE52}` | yes, `D3D_VIDENC_PROP_SET_AVGBITRATE` |
| `CODECAPI_AVEncVideoForceKeyFrame` `{398C1B98-8353-475A-9EF2-8F265D260345}` | yes |
| `CODECAPI_AVEncCommonLowLatency` `{9D3ECD55-89E8-490A-970A-0C9548D5A56E}` | no |
| `CODECAPI_AVLowLatencyMode` `{9C27891A-ED7A-40E1-88E8-B22727A024EE}` | no |
| `CODECAPI_AVEncVideoEncodeQP` `{2CB5696B-23FB-4CE1-A0F9-EF5B90FD55CA}` | yes |
| `CODECAPI_AVEncVideoTemporalLayerCount` `{19CAEBFF-B74D-4CFD-8C27-C2F9D97D5F52}` | no: `VT_UI4`, copied to +0x60 of the base configuration (hierarchical P layers) by `UpdateBaseConfigFromCodecAPI` (`sub_1000ED88`) |
| `CODECAPI_AVEncVideoSelectLayer` `{EB1084F5-6AAA-4914-BB2F-6147227F12E7}` | yes: `VT_UI4`, kept at +0x1C58; it is the layer id of the next `D3D_VIDENC_PROP_SET_LAYER_QP` (`LayerQPChanged`, `sub_10011064`) |
| `CODECAPI_DropNumFrames` `{98C78118-70F8-4211-BC53-DE2ECB82C6D2}` | yes |
| `{F0496C31-AACB-441D-BFB7-4186571A11F3}`, "`CODECAPI_VideoEncNalUnits`" in the debug strings | no: `VT_BOOL`; `VARIANT_TRUE` (-1) sets bit 0 of the request flags (+0x6C of the base configuration), which qcvidum8930.dll passes to the KMD. `GetValue` (`sub_1000DFC0`) returns bit 0 of +0x60, not of +0x6C (bug ?) |

`SetValue` (`sub_1000E2A4`), `GetValue` and the rest of the interface work as in the [H.263 build](./qcvidencmfth2638930.md#icodecapi).

### Shared implementation

Everything else is the code of [qcvidencmfth2638930.dll](./qcvidencmfth2638930.md), at the same addresses, with the codec type 1:

- [MFT object](./qcvidencmfth2638930.md#mft-object), [attributes](./qcvidencmfth2638930.md#attributes) and [IMFTransform](./qcvidencmfth2638930.md#imftransform) methods. `SetOutputType` checks the `H264` subtype;
- [ProcessMessage](./qcvidencmfth2638930.md#processmessage-sub_1000c228) and the [encoder start](./qcvidencmfth2638930.md#encoder-start-initializehardware-sub_10009128). The encoder GUID chosen from the `H264` subtype is `{129F7B40-5C5B-48E5-8178-48C0CEA05A90}`, checked by `ValidateEncProfileConfig` (`sub_10016064`: the GUID must be one of the `ID3D11VideoDevice::GetVideoDecoderProfile` entries, else 0xC00D6D76);
- the [DecoderExtension commands](./qcvidencmfth2638930.md#decoderextension-commands), the [encoding](./qcvidencmfth2638930.md#encoding) path, the [encode frame](./qcvidencmfth2638930.md#encode-frame) parameters and the [UMD callback](./qcvidencmfth2638930.md#umd-callback-sub_10019bc0) `VideoUMDCb` (`sub_10019BC0`);
- [IOPMVideoOutput](./qcvidencmfth2638930.md#iopmvideooutput): same certificate and RSA key. The verifier is accepted when it is one of the four encoder CLSIDs, so this build also answers merit 7;
- [debug log and dumps](./qcvidencmfth2638930.md#debug-log-and-dumps).

### ETW

Same providers as the H.263 build: manifest provider `{CABA4C43-CDA9-4E5B-BF10-48FB256C8138}` (events 106–123, level 4, keyword 0x2, see [ETW](./qcvidencmfth2638930.md#etw)) and WPP provider `{CEA35F95-03DB-4F70-A5C2-25E3ACA61E2A}`.

### COM

| GUID | Use |
|------|-----|
| `{7790EE16-08E3-426D-AADA-F96774308EA1}` | CLSID of the MFT |
| `{670E88D4-B18A-483A-8E0F-65A027838718}`, `{ED93D261-C7CC-46E2-AE09-3CE7AE5C4ABC}`, `{8EB787DC-D1B6-421D-88A0-22539F9F12C3}` | CLSIDs of the H.263 ([qcvidencmfth2638930.dll](./qcvidencmfth2638930.md)), VC-1 (not analysed) and MPEG-4 ([qcvidencmftmpeg48930.dll](./qcvidencmftmpeg48930.md)) encoders of the same family, not registered here |
| `{F79EAC7D-E545-4387-BDEE-D647D7BDE42A}` | `MFT_CATEGORY_VIDEO_ENCODER` |
| `{129F7B40-5C5B-48E5-8178-48C0CEA05A90}` | H.264 encoder device of [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) |
| `{AD76A80B-2D5C-4E0B-B375-64E520137036}`, `{96F66574-11C5-4015-8666-BFF516436DA7}` | `MF_MT_MPEG2_PROFILE`, `MF_MT_MPEG2_LEVEL` |
| `{FB8D8600-25C3-435E-94C5-A4B50397EC46}`, `{B27227A5-59FB-4BFC-AF1E-42237F213DBC}` | Input formats NV12_16M2KA (linear) and TILE_4X2, [base configuration](./qcvidencmfth2638930.md#base-configuration) +0x0C |
