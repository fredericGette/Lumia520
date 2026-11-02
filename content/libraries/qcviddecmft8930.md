## qcviddecmft8930.dll

Hardware Media Foundation transform (MFT) of the MSM8930 that decodes MPEG-4 part 2 and H.263 video: "QC MPEG4 Part 2 Dec HW-MFT", build `P:\QCVidDecMFT\rel\8.2.1.1\arm\Release\qcviddecmft8930.pdb`.  
`qcviddecmft8930.dll` is an in-process COM server (220 functions) registered as an asynchronous hardware video decoder MFT, CLSID `{DF20DDFA-0D19-463A-AB46-E5D8EF6EFD69}`, merit 7. It doesn't decode anything itself: it parses the MPEG-4 headers (VOS, VO, VOL, GOV, VOP, H.263 short header) of each input sample, fills the DXVA buffers (picture parameters, inverse quantisation matrices, bitstream) and submits them to a DXVA decoder created on the Direct3D device given by the pipeline, either through Direct3D 9 / DXVA2 (`IDirect3DDeviceManager9`) or Direct3D 11 (`IMFDXGIDeviceManager`). That decoder is the MPEG-4 part 2 decoder of [qcvidum8930.dll](./qcvidum8930.md#decoders), which sends the frames to the VIDEO engine of [qcdxkm8930.sys](../drivers/qcdxkm8930.md). The decoded pictures are `420O` surfaces / `DXGI_FORMAT_420_OPAQUE` texture slices, returned as tracked samples.  
To prove its merit to Media Foundation it implements `IOPMVideoOutput` with an embedded certificate chain issued by the "Microsoft Digital Media Authority 2005" and an embedded RSA key (see [OPM](#iopmvideooutput-merit-certification)). The process that loads it (the media pipeline of the apps playing MPEG-4 / H.263 video) isn't known.

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| MFPlat.dll | `MFTRegister`, `MFTUnregister`, `MFCreateAttributes`, `MFCreateMediaType`, `MFCreateEventQueue`, `MFCreateMediaEvent`, `MFFrameRateToAverageTimePerFrame`, `MFCreateTrackedSample`, `MFCreateDXSurfaceBuffer`, `MFCreateDXGISurfaceBuffer`, `MFCalculateImageSize` |
| bcrypt.dll | `BCryptOpenAlgorithmProvider`, `BCryptCloseAlgorithmProvider`, `BCryptGenRandom`, `BCryptGetProperty`, `BCryptSetProperty`, `BCryptImportKey`, `BCryptImportKeyPair`, `BCryptDestroyKey`, `BCryptEncrypt`, `BCryptDecrypt` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCreateKeyExW`, `RegSetValueExW`, `RegOpenKeyExW`, `RegDeleteTreeW`, `RegCloseKey` |
| api-ms-win-core-com-l1-1-0.dll | `CoTaskMemAlloc`, `CoTaskMemFree` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-libraryloader-l1-1-1.dll | `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-errorhandling-l1-1-1.dll | `GetLastError` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister` |
| api-ms-win-eventing-classicprovider-l1-1-0.dll | `RegisterTraceGuidsW`, `UnregisterTraceGuids`, `GetTraceLoggerHandle`, `GetTraceEnableLevel`, `GetTraceEnableFlags`, `TraceMessage` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter` |
| api-ms-win-core-processthreads-l1-1-1.dll | `GetCurrentThreadId` |
| api-ms-win-core-sysinfo-l1-2-0.dll | `GetTickCount64`, `GetSystemTimeAsFileTime` |
| MSVCR110.dll | `memset`, `memcpy`, `memcpy_s`, `memcmp`, `free`, `operator new`/`delete` (`??2@YAPAXI@Z`, `??3@YAXPAX@Z`, `??_U@YAPAXI@Z`, `??_V@YAXPAX@Z`), `_initterm`, `_initterm_e`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_malloc_crt`, `_calloc_crt`, `_amsg_exit`, `__CxxFrameHandler3`, `__C_specific_handler`, `__CppXcptFilter`, `__clean_type_info_names_internal` |

The util, profile, processthreads and sysinfo imports and the CRT functions of MSVCR110 are the Visual C++ 2012 DLL startup and `/GS` security cookie code. The classic-provider functions are the WPP tracing.

### Dependencies

No DLL is loaded at run time, no process is started, no file is opened and no COM object is created with `CoCreateInstance`. Every Direct3D / DXVA object comes from the device manager the pipeline gives to [ProcessMessage](#processmessage-sub_1000995c) (`MFT_MESSAGE_SET_D3D_MANAGER`):

| Object | How | Use |
|--------|-----|-----|
| `IDirect3DDeviceManager9` → `IDirectXVideoDecoderService` → `IDirectXVideoDecoder` | `OpenDeviceHandle`, `GetVideoService`, `CreateVideoDecoder` | DXVA2 decoding (D3D9 mode) by the decoder of [qcvidum8930.dll](./qcvidum8930.md#decoders) through [qcdx9um8930.dll](./qcdx9um8930.md) |
| `IMFDXGIDeviceManager` → `ID3D11Device`, `ID3D11VideoDevice`, `ID3D11VideoContext` | `OpenDeviceHandle`, `GetVideoService`, `GetImmediateContext`, `CreateVideoDecoder` | D3D11 video decoding (D3D11 mode), probably the same video user-mode driver ? |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x10001914 | none |
| 2 | `DllGetClassObject` | 0x1000198C | `REFCLSID, REFIID, void **` |
| 3 | `DllRegisterServer` | 0x100019D8 | none |
| 4 | `DllUnregisterServer` | 0x10001F20 | none |

The four exports of a COM server. A global counter (`dword_1001E2BC`) counts the class factories and MFT objects; `DllCanUnloadNow` returns `S_FALSE` while it isn't 0.

`DllGetClassObject` (`sub_1000148C`) looks the CLSID up in a one-entry table (`off_1001A960`: `{DF20DDFA…}` → `sub_1000727C`), else `CLASS_E_CLASSNOTAVAILABLE` (0x80040111). It builds a 12-byte class factory (vtable `off_1001BE88`, refcount at +4, creation function at +8) and queries the requested interface. `IClassFactory::CreateInstance` (`sub_100015DC`) returns `CLASS_E_NOAGGREGATION` with an outer object, otherwise `sub_100072F0` allocates the 0x968-byte [MFT object](#mft-object) (`sub_10007404`) and queries the requested interface.

### Startup

`start` (`_DllMainCRTStartup`, 0x10018820): the usual CRT startup with `__security_init_cookie`. `DllMain` (`sub_10001798`):
- `DLL_PROCESS_ATTACH`: keeps the module handle (`dword_1001E2B8`), `DisableThreadLibraryCalls`, registers the manifest provider (`McGenEventRegister`) and the WPP provider (`sub_100011FC`, `RegisterTraceGuidsW`), see [ETW](#etw).
- `DLL_PROCESS_DETACH`: unregisters both (`sub_1000126C`).

### Registry

`DllRegisterServer` gets the path of the DLL (`GetModuleFileNameW`), writes 8 values under `HKEY_LOCAL_MACHINE` (`sub_10001644`: `RegCreateKeyExW` + `RegSetValueExW`, table of 24-byte entries {root, key, value name, string, type, dword}), then calls `MFTRegister`:

| Key | Value | Data |
|-----|-------|------|
| `Software\Classes\CLSID\{df20ddfa-0d19-463a-ab46-e5d8ef6efd69}\InProcServer32` | (default) | `MPEG-4 Decoder`, then overwritten by the next entry |
| same | (default) | Path of the DLL |
| same | `ThreadingModel` | `Both` |
| same | `Mpeg4DecLogMsgMask` | `REG_DWORD` 0x18 |
| same | `Mpeg4DecLogFileMask` | `REG_DWORD` 0x18 |
| same | `Mpeg4HostDecParamsDump` | `REG_DWORD` 0 |
| same | `Mpeg4BitStreamDump` | `REG_DWORD` 0 |
| `SOFTWARE\Microsoft\Windows Media Foundation\HardwareMFT` | `EnableDecoders` | `REG_DWORD` 1 |

All the entries of the CLSID use the `InProcServer32` key, so the friendly name "MPEG-4 Decoder" ends up nowhere (the CLSID key itself has no default value). The four `Mpeg4Dec…` values are never read by this DLL (it imports no `RegQueryValueEx`): they look like the debug switches of another build.

`MFTRegister(CLSID, MFT_CATEGORY_VIDEO_DECODER {D6C02D4B-6833-45B4-971A-05A4B04BAB91}, "MPEG-4 Decoder", 6 = MFT_ENUM_FLAG_ASYNCMFT | MFT_ENUM_FLAG_HARDWARE, 8 input types, 1 output type, attributes)`. The input types are `MFMediaType_Video` + `MP4V`, `mp4v`, `M4S2`, `m4s2`, `V4PM`, `v4pm`, `h263`, `H263` (FOURCC subtypes `{xxxxxxxx-0000-0010-8000-00AA00389B71}`; `V4PM` `{4D503456-…}` and `v4pm` are `MP4V` / `mp4v` with the bytes reversed, a bug ?). The output type is `MFMediaType_Video` + `420O` (`{4F303234-…}`, Qualcomm's opaque NV12). The 12 registration attributes are the same as the [attributes](#attributes) of the object.

`DllUnregisterServer` deletes `Software\Classes\CLSID\{df20ddfa-…}` (`RegDeleteTreeW`, `ERROR_FILE_NOT_FOUND` ignored), calls `MFTUnregister`, then sets `HardwareMFT\EnableDecoders` to 0 (`RegOpenKeyExW` + `RegSetValueExW`).

### MFT object

0x968 bytes (`sub_10007404`). The `QueryInterface` table (`off_1001C038`, `sub_10001350`) gives the offset of each interface:

| Offset | Vtable | IID | Interface |
|--------|--------|-----|-----------|
| 0x00 | `off_1001C138` | `{BF94C121-5B05-4E6F-8000-BA598961414D}` | `IMFTransform` (+ a private 27th method `sub_1000ACA4`) |
| 0x04 | `off_1001C1A4` | `{2CD0BD52-BCD5-4B89-B62C-EADC0C031E7D}` | `IMFMediaEventGenerator`: forwarded to the event queue (+0x458) |
| 0x08 | `off_1001BFC4` | `{97EC2EA4-0E42-4937-97AC-9D6D328824E1}` | `IMFShutdown` |
| 0x0C | `off_1001C088` | `{FA993888-4383-415A-A930-DD472A8CF6F7}` | `IMFGetService` |
| 0x10 | `off_1001C124` | `{88DDCD21-03C3-4275-91ED-55EE3929328F}` | `IMFRateControl` |
| 0x14 | `off_1001C0FC` | `{0A9CCDBC-D797-4563-9667-94EC5D79292D}` | `IMFRateSupport` |
| 0x18 | `off_1001BF4C` | `{0A15159D-41C7-4456-93E1-284CD61D4E8D}` | `IOPMVideoOutput`, see [OPM](#iopmvideooutput-merit-certification) |
| 0x1C | `off_1001C0DC` | `{EC15E2E9-E36B-4F7C-8758-77D452EF4CE7}` | `IMFQualityAdvise` |
| 0x20 | `off_1001BF8C` | `{03910848-AB16-4611-B100-17B88AE2F248}` | `IMFRealTimeClientEx`: the 3 methods return `S_OK` and do nothing |
| 0x24 | `off_1001C0A8` | `{A27003CF-2354-4F2A-8D6A-AB7CFF15437E}` | `IMFAsyncCallback` (only through its own `QueryInterface`, not in the table): `Invoke` (`sub_10006F14`) calls `sub_1000ACA4`, see [Output samples](#output-samples) |

Main fields (from the constructor and the methods; many others are parser and timestamp state):

| Offset | Size | Comment |
|--------|------|---------|
| 0x28 | 16 | OPM: random number sent by `StartInitialization` |
| 0x38 | 24 | OPM: AES key (16) and the two sequence numbers received by `FinishInitialization` |
| 0x50 | 4 | Reference count |
| 0x54 | 0x18 | Critical section |
| 0x6C | 0xD8 | Bitstream parser state (`sub_1000216C`), with the default MPEG-4 intra / non-intra matrices (`byte_1001A968`, `byte_1001AAA8`) |
| 0x144 | 4 | Streaming started (`MFT_MESSAGE_NOTIFY_START_OF_STREAM`) |
| 0x148 | 4 | Shut down: every method then returns `MF_E_SHUTDOWN` (0xC00D3E85) |
| 0x14C | 4 | D3D11 mode (`IMFDXGIDeviceManager` given) |
| 0x150 | 8 | Surfaces allocated, per bank |
| 0x158, 0x15C, 0x160 | 12 | Draining, drain requested, end of stream |
| 0x164 | 2 | Current surface bank (0 or 1), switched at each format change |
| 0x168 | 4 | Format change pending |
| 0x170 | 4 | D3D9 mode (`IDirect3DDeviceManager9` given) |
| 0x17C | 4 | Frames per second (rounded down) |
| 0x180, 0x184 | 8 | Frame rate numerator / denominator |
| 0x188, 0x18C | 8 | Width, height |
| 0x190 | 4 | `IMFAttributes` of the MFT (12 entries), see [Attributes](#attributes) |
| 0x194 | 4 | `IMFAttributes` of the output stream (empty, filled by the caller) |
| 0x198–0x1B4 | | D3D11: `IMFDXGIDeviceManager`, `ID3D11VideoDevice`, `ID3D11Device`, immediate context, `ID3D11VideoContext`, device handle, `ID3D11VideoDecoder` of each bank |
| 0x1C8–0x1D8 | | D3D9: `IDirect3DDeviceManager9`, device handle, `IDirectXVideoDecoderService`, render target format |
| 0x214 | 100 | `DXVA2_ConfigPictureDecode` chosen (D3D9) |
| 0x278 | 8 | `IDirectXVideoDecoder` of each bank (D3D9) |
| 0x284 | 16 | Decoder GUID: always `DXVA2_ModeMPEG4pt2_VLD_AdvSimple_NoGMC` |
| 0x294 | 4 | DXGI format of the output textures: 106 (`DXGI_FORMAT_420_OPAQUE`) |
| 0x29C | | `D3D11_VIDEO_DECODER_CONFIG` chosen (D3D11) |
| 0x304 | 2 × 7 × 24 | Output surfaces, 2 banks of 7: {+0 `IMFMediaBuffer`, +4 tracked `IMFSample`, …, +0x10 state}, see [Output samples](#output-samples) |
| 0x458 | 4 | `IMFMediaEventQueue` (`MFCreateEventQueue`) |
| 0x45C | 4 | Number of `METransformNeedInput` sent and not yet answered by `ProcessInput` |
| 0x464 | 4 | Number of `METransformHaveOutput` sent and not yet answered by `ProcessOutput` |
| 0x468, 0x46C | 8 | Sequence header (size, `CoTaskMem` pointer) taken from the input type |
| 0x470 | 8 | Average time per frame (`MFFrameRateToAverageTimePerFrame`) |
| 0x478 | 4 | Context of the last `MFT_MESSAGE_COMMAND_MARKER` |
| 0x47C, 0x480 | 8 | Available output types (count, array of {`IMFMediaType`, flag}) |
| 0x488 | 256 | The 8 input `MFT_REGISTER_TYPE_INFO` |
| 0x588 | 4 | Current input type |
| 0x5B8 | 4 | `MF_SA_D3D11_BINDFLAGS` of the output stream |
| 0x5BC | 4 | `MF_MT_INTERLACE_MODE` of the input |
| 0x5E0 | 32 | The output `MFT_REGISTER_TYPE_INFO` (`420O`) |
| 0x600 | 4 | Current output type |
| 0x604, 0x608 | 8 | Output stream flags and sample size |
| 0x758 | 4 | Fastest rate: min(16, 1920 × 1088 / (width × height)), as a float |
| 0x75C | 4 | Current rate (float, 1.0) |
| 0x948 | 16 | Subtype of the input type |

### Attributes

Attribute store of the object (`MFCreateAttributes(12)` in the constructor; the same values are given to `MFTRegister`), returned by `GetAttributes`:

| Attribute | Value |
|-----------|-------|
| `MFT_ENUM_HARDWARE_VENDOR_ID_Attribute` `{3AECB0CC-…}` | `VEN_QCOM` |
| `MFT_ENUM_HARDWARE_URL_Attribute` `{2FB866AC-…}` | `QC MPEG4 Part 2 Dec HW-MFT` |
| `MF_TRANSFORM_ASYNC` `{F81A699A-…}` | 1 |
| `MF_TRANSFORM_ASYNC_UNLOCK` `{E5666D6B-…}` | 0: every `IMFTransform` method returns `MF_E_TRANSFORM_ASYNC_LOCKED` (0xC00D6D77) until the client sets it to 1 (`sub_1000D3A4`) |
| `MF_SA_D3D_AWARE` `{EAA35C29-…}` | 1 |
| `MF_SA_D3D11_AWARE` `{206B4FC8-…}` | 1 |
| `MFT_SUPPORT_DYNAMIC_FORMAT_CHANGE` `{53476A11-…}` | 1 |
| `MF_TRANSFORM_CATEGORY_Attribute` `{CEABBA49-…}` | `MFT_CATEGORY_VIDEO_DECODER` |
| `MFT_INPUT_TYPES_Attributes` `{4276C9B1-…}` | The 8 input types (256 bytes) |
| `MFT_OUTPUT_TYPES_Attributes` `{8EAE8CF3-…}` | The output type (32 bytes) |
| `MFT_CODEC_MERIT_Attribute` `{88A7CB15-…}` | 7, proved by the [OPM](#iopmvideooutput-merit-certification) handshake |
| `MFT_TRANSFORM_CLSID_Attribute` `{6821C42B-…}` | `{DF20DDFA-0D19-463A-AB46-E5D8EF6EFD69}` |

### IMFTransform

| Method | Function | Comment |
|--------|----------|---------|
| `GetStreamLimits` | sub_1000928C | 1 input, 1 output (min = max) |
| `GetStreamCount` | sub_10009110 | 1, 1 |
| `GetStreamIDs`, `GetInputStreamAttributes`, `DeleteInputStream`, `AddInputStreams`, `GetInputAvailableType`, `GetOutputStatus`, `SetOutputBounds` | sub_100091C4, sub_100087F0, sub_1000824C, sub_10008184, sub_10008408, sub_10008E20, sub_1000B654 | `E_NOTIMPL` |
| `GetInputStreamInfo` | sub_100088B8 | Flags 0x103 (`MFT_INPUT_STREAM_WHOLE_SAMPLES` \| `SINGLE_SAMPLE_PER_BUFFER` \| `DOES_NOT_ADDREF`) |
| `GetOutputStreamInfo` | sub_10008FF4 | Flags \|= 0x103 (whole samples, single sample per buffer, `MFT_OUTPUT_STREAM_PROVIDES_SAMPLES`), size (+0x608), alignment 0x2000 |
| `GetAttributes` | sub_10008314 | The [attributes](#attributes) |
| `GetOutputStreamAttributes` | sub_10008EE8 | The output stream attributes (+0x194): the caller can put `MF_SA_D3D11_BINDFLAGS` and the D3D11 sharing attributes there, see [D3D11 surfaces](#d3d11-mode-sub_1000fa94) |
| `GetOutputAvailableType` | sub_100089E8 | Needs an input type (`MF_E_TRANSFORM_TYPE_NOT_SET` 0xC00D6D60). Only index 0: the type built by `sub_1000E494`, else `MF_E_NO_MORE_TYPES` (0xC00D36B9) |
| `SetInputType` | sub_1000B060 | See [Input type](#input-type) |
| `SetOutputType` | sub_1000B720 | See [Output type](#output-type) |
| `GetInputCurrentType`, `GetOutputCurrentType` | sub_100084D0, sub_10008C54 | Copy of the current type (`MFCreateMediaType` + `CopyAllItems`) |
| `GetInputStatus` | sub_1000869C | 0 once an input type is set |
| `ProcessEvent` | sub_10009380 | Reads the event type (trace only), `S_OK` |
| `ProcessMessage` | sub_1000995C | See [ProcessMessage](#processmessage-sub_1000995c) |
| `ProcessInput` | sub_100094D0 | See [ProcessInput](#processinput-sub_100094d0) |
| `ProcessOutput` | sub_1000A6A4 | See [ProcessOutput](#processoutput-sub_1000a6a4) |

Stream ids other than 0 return `MF_E_INVALIDSTREAMNUMBER` (0xC00D36B3).

The MFT is asynchronous: it asks for input with `METransformNeedInput` (601) and announces each decoded picture with `METransformHaveOutput` (602), queued on its event queue (`IMFMediaEventGenerator::QueueEvent` of the interface at +4). It ends a drain with `METransformDrainComplete` (603) and answers a marker with `METransformMarker` (604).

#### Input type

`SetInputType(0, type, flags)` (`sub_1000B060`): a null type releases the current one. `sub_1000D6C8` checks the type:
1. major type `MFMediaType_Video` and a subtype among the 8 input subtypes (kept at +0x948), else `MF_E_INVALIDMEDIATYPE` (0xC00D36B4);
2. `MF_MT_FRAME_SIZE` at most **1920 × 1088** (the maximum decode size of [qcvidum8930.dll](./qcvidum8930.md#caps-object));
3. `MF_MT_FRAME_RATE` → frames per second (+0x17C);
4. the codec private data (`GetAllocatedBlob`), tried in order from `MF_MT_AM_FORMAT_TYPE` (sic), `MF_MT_MPEG_SEQUENCE_HEADER`, `MF_MT_USER_DATA` (+0x46C pointer, +0x468 size);
5. for `h263` / `H263`: `MF_MT_INTERLACE_MODE`, and in the sequence header the `d263` box (3GPP H263SpecificBox, `sub_1000D20C`, header ≤ 1024 bytes): the byte 7 bytes after the tag (the profile ?) must be 0;
6. `MF_SA_D3D11_BINDFLAGS` read from the output stream attributes (+0x5B8);
7. it then writes on the caller's type: `MF_MT_AVG_BITRATE` 0x1400000, `{799CABD6-3508-4DB4-A3C7-569CD533DEB1}` 0, `MF_MT_PAN_SCAN_ENABLED` 0, `MF_MT_COMPRESSED` 1, `MF_MT_ALL_SAMPLES_INDEPENDENT` 0, `MF_MT_FIXED_SIZE_SAMPLES` 0, `MF_MT_DEFAULT_STRIDE` 1, `MF_MT_VIDEO_NOMINAL_RANGE` 1, `MF_MT_TRANSFER_FUNCTION`, `MF_MT_VIDEO_PRIMARIES`, `MF_MT_YUV_MATRIX` 0.

If a type is already set, `IMFMediaType::IsEqual` decides: identical (`S_OK`) → nothing to do, different (`S_FALSE`) → continue, error → `MF_E_TRANSFORM_CANNOT_CHANGE_MEDIATYPE_WHILE_PROCESSING` (0xC00D6D74). With `MFT_SET_TYPE_TEST_ONLY` it stops there. Otherwise `sub_1000E144` keeps the type, the frame size, the frame rate, the average time per frame and the fastest rate (+0x758); the sequence header is parsed (`sub_10003F08`, the VOL), the output type is built (`sub_1000E494`), the device is tested (D3D11: `ID3D11Device::GetDeviceRemovedReason`, the DXGI "device removed / hung / reset / driver internal error" codes trigger a [device reset](#device-reset-sub_10016a68); D3D9: `IDirect3DDeviceManager9::TestDevice`) and the decoder is created ([sub_10016254](#decoder-creation-sub_10016254)).

#### Output type

`sub_1000E494` builds the only available output type: a copy of the input type (`CopyAllItems`) with
- `MF_MT_SUBTYPE` `420O`, `MF_MT_DEFAULT_STRIDE` = width rounded up to 128, `MF_MT_INTERLACE_MODE` of the input, `MF_MT_FIXED_SIZE_SAMPLES` 1, `MF_MT_ALL_SAMPLES_INDEPENDENT` 1, `MF_MT_SAMPLE_SIZE` = width × height × 1.5, `MF_MT_FRAME_SIZE`, `MF_MT_FRAME_RATE`;
- `MF_MT_PIXEL_ASPECT_RATIO` from the `aspect_ratio_info` of the VOL: 1 → 1:1, 2 → 12:11, 3 → 10:11, 4 → 16:11, 5 → 40:33, 15 (extended PAR) → `par_width`:`par_height`;
- `MF_MT_VIDEO_NOMINAL_RANGE` 1, `MF_MT_COMPRESSED` 0, `MF_MT_AVG_BITRATE` = width × height × fps × 3 / 2 (width × height × 45 without frame rate), `{799CABD6…}` 0, `MF_MT_PAN_SCAN_ENABLED` 0, `MF_MT_TRANSFER_FUNCTION`, `MF_MT_VIDEO_PRIMARIES`, `MF_MT_YUV_MATRIX` 0.

`SetOutputType` (`sub_1000B720`) needs an input type and a device manager (`MF_E_UNSUPPORTED_D3D_TYPE` 0xC00D6D76 without one). The type must contain the items of the available type (`IMFAttributes::Compare`, `MF_ATTRIBUTES_MATCH_OUR_ITEMS`), else `MF_E_INVALIDMEDIATYPE`. Then `sub_1000EDBC` reads the subtype, frame size and frame rate of the new type and computes the output sample size with `MFCalculateImageSize` (+0x608). The [surfaces](#output-samples) are allocated later, at `MFT_MESSAGE_NOTIFY_START_OF_STREAM`. After a format change, setting the new output type sends the pending `METransformHaveOutput` and switches the surface bank (+0x164).

### ProcessMessage (sub_1000995C)

| Message | Action |
|---------|--------|
| `MFT_MESSAGE_COMMAND_FLUSH` (0) | `sub_10010FD8`: drops the queued pictures, resets the reference and output order state |
| `MFT_MESSAGE_COMMAND_DRAIN` (1) | `sub_100108AC`: sends a `METransformHaveOutput` for each decoded picture still waiting; when there is none, `METransformDrainComplete` |
| `MFT_MESSAGE_SET_D3D_MANAGER` (2) | `ulParam` is queried for `IMFDXGIDeviceManager` `{EB533D5D-…}` → D3D11 mode, else `IDirect3DDeviceManager9` `{A0CADE0F-…}` → D3D9 mode. A change of manager destroys the decoder and surfaces and resets the types. `sub_100110C8` opens a device handle and gets the video services (see [Dependencies](#dependencies)). A null manager is refused |
| `MFT_MESSAGE_NOTIFY_BEGIN_STREAMING` (0x10000000) | Resets two flags and the frame counter |
| `MFT_MESSAGE_NOTIFY_END_STREAMING` (0x10000001) | Resets the drain flags and the output order state |
| `MFT_MESSAGE_NOTIFY_END_OF_STREAM` (0x10000002) | Sends `METransformHaveOutput` for the last picture if there is one |
| `MFT_MESSAGE_NOTIFY_START_OF_STREAM` (0x10000003) | Allocates the surfaces if not done (`sub_1000F1A8`), resets the counters, sends the first `METransformNeedInput` |
| `MFT_MESSAGE_COMMAND_MARKER` (0x20000000) | `sub_10010BD8`: outputs the pictures waiting, then queues `METransformMarker` with `MF_EVENT_MFT_CONTEXT` `{B7CD31F1-…}` = `ulParam` |
| other | Error |

### ProcessInput (sub_100094D0)

`ProcessInput(0, sample, 0)`: `MF_E_NOTACCEPTING` (0xC00D36B5) without a pending `METransformNeedInput` or before both types are set, `E_INVALIDARG` with flags. The sample time and duration (`GetSampleTime`, `GetSampleDuration`) are kept, then `sub_1001246C`:
1. reads `MFSampleExtension_CleanPoint`, `ConvertToContiguousBuffer` and `Lock`;
2. looks for the start codes (`sub_10002360`: `00 00 01` + code, or an H.263 picture start code `00 00 8x`) and parses the headers (`sub_100060D8`): `0x1B0` visual object sequence, `0x1B5` visual object, `0x120`–`0x12F` video object layer (`sub_10002794`), `0x1B3` group of VOP, `0x1B2` user data, `0x1B6` VOP (`sub_100040E4`), H.263 short header;
3. decodes each VOP (`sub_10012F3C`), see [Decoding](#decoding).

A VOL with a new picture size starts a format change (`sub_10014C98`, called by both decoding paths: new width / height at +0x188 / +0x18C, flag +0x168, output order state reset); it ends in [ProcessOutput](#processoutput-sub_1000a6a4). After the frame, if at least 2 surfaces are free (`sub_10012D0C`), a new `METransformNeedInput` is queued.

### Decoding

The decoder is called through DXVA2 (`sub_10013EE0`) or D3D11 (`sub_10013118`), with the same 3 buffers:
1. device test (`IDirect3DDeviceManager9::TestDevice` / `ID3D11Device::GetDeviceRemovedReason`), [reset](#device-reset-sub_10016a68) if it was lost;
2. `BeginFrame` on a free surface (`sub_100116B0`: `IDirectXVideoDecoder::BeginFrame`; `sub_100114EC`: `ID3D11VideoContext::DecoderBeginFrame` with the output view of the slice);
3. `GetBuffer` / `GetDecoderBuffer` and copy (`memcpy_s`) of the 3 buffers:

| Type | Size | Content |
|------|------|---------|
| 0 picture parameters | 0x3E (62) | Built by `sub_100060D8` from the VOL / VOP headers |
| 4 inverse quantisation matrix | 0x204 (516) | 4 flags + 4 × 64 16-bit coefficients (`DXVA_QmatrixData` layout), default MPEG-4 matrices or the ones of the VOL |
| 6 bitstream | VOP size | The VOP data |

4. `ReleaseBuffer` / `ReleaseDecoderBuffer`, `Execute` (`DXVA2_DecodeExecuteParams` with 3 `DXVA2_DecodeBufferDesc`) / `SubmitDecoderBuffers`, `EndFrame` / `DecoderEndFrame`;
5. reference management and display order (`sub_10015344`): the forward / backward references (+0x764 / +0x766) keep their surfaces; a B-VOP, or the previous reference when a new one arrives, is put in the output order ring (7 entries per bank) and announced with `METransformHaveOutput`.

These sizes match the compressed buffer descriptions of [qcvidum8930.dll](./qcvidum8930.md#caps-object) (`PICTUREPARAMSDATA`, `INVERSEQUANTIZATIONDATA` 516 bytes, `BITSTREAMDATA`). If a step fails, `sub_10015168` releases the buffers already taken.

### Decoder creation (sub_10016254)

- D3D11: `ID3D11VideoDevice::GetVideoDecoderProfileCount` / `GetVideoDecoderProfile`; for any of the 8 subtypes, a profile `DXVA2_ModeMPEG4pt2_VLD_AdvSimple_NoGMC` `{ED418A9F-…}` or `DXVA2_ModeMPEG4pt2_VLD_Simple` `{EFD64D74-…}` selects **`DXVA2_ModeMPEG4pt2_VLD_AdvSimple_NoGMC`** (+0x284); `DXVA2_ModeMPEG4pt2_VLD_AdvSimple_GMC` `{BBC56996-…}` is recognised but not used. Then `CheckVideoDecoderFormat(guid, DXGI_FORMAT_420_OPAQUE)`, `GetVideoDecoderConfigCount` / `GetVideoDecoderConfig` (+0x29C).
- D3D9: `IDirectXVideoDecoderService::GetDecoderDeviceGuids` (same choice), `GetDecoderRenderTargets` (+0x1D8, `420O` with [qcvidum8930.dll](./qcvidum8930.md#getcaps-sub_10001778)), `GetDecoderConfigurations` (the first `DXVA2_ConfigPictureDecode` is copied to +0x214).

### Output samples

`sub_1000F1A8` allocates the 7 surfaces of the current bank:
- D3D9 mode (`sub_1000F40C`): `IDirectXVideoDecoderService::CreateSurface(width, height, 6 back buffers, render target format, …)`; for each surface `MFCreateDXSurfaceBuffer(IID_IDirect3DSurface9, surface)`, `SetCurrentLength`, a tracked sample (`MFCreateTrackedSample`, `sub_1000F2F4`) with the buffer; then `IDirectXVideoDecoderService::CreateVideoDecoder(guid, DXVA2_VideoDesc, config, surfaces, 7)`. The `DXVA2_VideoDesc` has the size, the format, the frame rate and the `DXVA2_ExtendedFormat` built by `sub_10015AD8` from the input type (`MF_MT_INTERLACE_MODE`, `MF_MT_VIDEO_CHROMA_SITING`, `MF_MT_VIDEO_NOMINAL_RANGE`, `MF_MT_YUV_MATRIX`, `MF_MT_VIDEO_LIGHTING`, `MF_MT_VIDEO_PRIMARIES`, `MF_MT_TRANSFER_FUNCTION`).
- D3D11 mode (`sub_1000FA94`): `ID3D11Device::CreateTexture2D` of a 7-slice array (`DXGI_FORMAT_420_OPAQUE`, bind flags = `MF_SA_D3D11_BINDFLAGS` \| 0x200 `D3D11_BIND_DECODER`, misc flags \| 0x10000 when the output stream attributes ask for sharing: `MF_SA_D3D11_SHARED_WITHOUT_MUTEX` `{39DBD44D-…}` and another one ?), one `ID3D11VideoDecoderOutputView` per slice (`CreateVideoDecoderOutputView`), `MFCreateDXGISurfaceBuffer(IID_ID3D11Texture2D, texture, slice)` + tracked sample per slice, then `CreateVideoDecoder({guid, width, height, format}, config)`.

The length given to each buffer is the Qualcomm NV12 layout: with S = width rounded up to 128 and H = height rounded up to 32, Y = S × H rounded up to 8 KB, total = (Y + S × (H / 2 rounded up to 32)) rounded up to 8 KB.

Surface states (+0x10 of each 24-byte entry, `sub_10015DB0` / `sub_10015CA4`): 1 free, 2 decoded and waiting for output, 3 being output / in use as a reference, 5 released by the client. `ProcessOutput` gives the tracked sample of the next picture of the ring; when the client releases it, the tracked sample calls the `IMFAsyncCallback` of the object (`IMFTrackedSample::SetAllocator(callback at +0x24)`), `sub_1000ACA4` finds the surface (`QueryInterface(IID_IMFSample)` on the state object) and marks it free, and queues `METransformNeedInput` if none is pending.

### ProcessOutput (sub_1000A6A4)

`ProcessOutput(0, 1, buffers, status)`: `E_INVALIDARG` for another count (or without sample while the output stream flags don't have `MFT_OUTPUT_STREAM_PROVIDES_SAMPLES`, which `GetOutputStreamInfo` always sets); `MF_E_TRANSFORM_TYPE_NOT_SET` before both types; `E_UNEXPECTED` without a pending `METransformHaveOutput`.
- Draining with nothing left: queues `METransformDrainComplete` and returns.
- Format change pending: the old surfaces are released (`sub_100103BC` D3D11 / `sub_100105C0` D3D9), the output type is released, `dwStatus` = `MFT_OUTPUT_DATA_BUFFER_FORMAT_CHANGE` (0x100), returns `MF_E_TRANSFORM_STREAM_CHANGE` (0xC00D6D61). The client then gets and sets the new output type.
- Otherwise `sub_10011874` takes the next picture of the output order ring and sets its time and duration (`sub_10012014`: `SetSampleTime`, `SetSampleDuration`); the tracked sample is returned in `pSample` (`AddRef`), with `MFSampleExtension_CleanPoint` and, for interlaced content (+0x5BC not progressive), `MFSampleExtension_Interlaced` 1, `MFSampleExtension_BottomFieldFirst` and `MFSampleExtension_SingleField` from the interlace mode (3 → top field first, 4 → bottom field first, 5 / 6 single field, 7 → from the picture).

### Device reset (sub_10016A68)

When the D3D device is lost or a new device is set (`DXVA2_E_NEW_VIDEO_DEVICE` 0x80041001 from `TestDevice`, `DXGI_ERROR_DEVICE_REMOVED` / `HUNG` / `RESET` / `DRIVER_INTERNAL_ERROR`): releases the surfaces, marks the 7 surfaces free, resets the output state, opens a new device handle, gets the video services again, recreates the decoder (`sub_10016254`) and the surfaces (`sub_1000F1A8`).

### Other interfaces

- `IMFShutdown`: `Shutdown` (`sub_1000BFA8`) shuts the event queue down, releases the decoder and the surfaces, sets the flag at +0x148. `GetShutdownStatus` (`sub_1000C2BC`): `MFSHUTDOWN_COMPLETED` after it, `MF_E_INVALIDREQUEST` (0xC00D36B2) before.
- `IMFGetService::GetService` (`sub_1000C40C`): only `MF_RATE_CONTROL_SERVICE` `{866FA297-B802-4BF8-9DC9-5E3B6A9F53C9}`, by `QueryInterface`; else `MF_E_UNSUPPORTED_SERVICE` (0xC00D36BA).
- `IMFRateControl`: `SetRate(thin, rate)` (`sub_1000C99C`) accepts 0 … fastest rate and −16 … 0 (16 with thinning), else 0xC00D36D0; `GetRate` (`sub_1000C8C4`).
- `IMFRateSupport`: `GetSlowestRate` (`sub_1000CD4C`) 0; `GetFastestRate` (`sub_1000CBCC`) the fastest rate (+0x758), 16 with thinning, −16 in reverse; `IsRateSupported` (`sub_1000CE84`) the same limits.
- `IMFQualityAdvise`: `SetDropMode` (`sub_1000C704`) modes 0–3 (else `MF_E_NO_MORE_DROP_MODES` 0xC00DA028), `SetQualityLevel` (`sub_1000C7E8`) only `MF_QUALITY_NORMAL` (else `MF_E_NO_MORE_QUALITY_LEVELS` 0xC00DA029), `GetDropMode`, `GetQualityLevel`, `DropTime` (`sub_1000C518`) `MF_E_DROPTIME_NOT_SUPPORTED` (0xC00DA02A). The drop mode isn't used by the decoding code.

### IOPMVideoOutput (merit certification)

Media Foundation only trusts the `MFT_CODEC_MERIT_Attribute` of a hardware MFT after an OPM handshake on `IOPMVideoOutput`. This implementation (interface at +0x18):

| Method | Function | Comment |
|--------|----------|---------|
| `StartInitialization(prnRandomNumber, ppbCertificate, pulCertificateLength)` | sub_1001707C | `BCryptGenRandom` 16 bytes (kept at +0x28, returned), and a `CoTaskMemAlloc` copy of the 3833-byte certificate (`unk_1001AD30`) |
| `FinishInitialization(pParameters)` | sub_100175B4 | See below |
| `GetInformation(pParameters, pRequestedInformation)` | sub_100172DC | See below |
| `COPPCompatibleGetInformation`, `Configure` | sub_10017260, sub_100171E4 | `E_NOTIMPL` |

The certificate is a PKCS #7 `SignedData` (`30 82 0E F5`, OID 1.2.840.113549.1.7.2) with a chain under "Microsoft Digital Media Authority 2005-beb13d97-7b24-45d0-bf66-da471a691b0f". Readable strings, in order: `CPP2S10`, validity 2012-03-08 23:35:35 → 2013-03-08 23:45:35, "Windows 8 Prerelease Merit 50"; then certificates of the authority valid 2012-03-08 21:02:03 → 2017-03-08 21:12:03 and 2012-03-08 22:44:21 → 2014-03-08 22:54:21. The certificate with the merit seems to have expired in March 2013 (whether the OS checks the dates wasn't checked).

`FinishInitialization`: the private key matching the certificate is stored obfuscated in the binary and rebuilt in a temporary buffer by `sub_100178B4` (XOR of two tables, `unk_1001AAE8` and `unk_1001BC30`); it's imported as `RSAPRIVATEBLOB` (provider "RSA" / "Microsoft Primitive Provider"), and the 256-byte `OPM_ENCRYPTED_INITIALIZATION_PARAMETERS` are decrypted with RSA-OAEP / SHA-512 (`BCryptDecrypt`, `BCRYPT_PAD_OAEP`). The first 16 bytes must be the random number of `StartInitialization` (else `E_ACCESSDENIED`); the AES key (16 bytes) and the two starting sequence numbers that follow are kept at +0x38.

`GetInformation`: the OMAC of the `OPM_GET_INFO_PARAMETERS` (AES-128 CMAC, `sub_10017B28`: "AES", `ChainingModeCBC`, `KeyDataBlob`, subkeys with the constant 0x87) must match, the sequence number must be the expected one (then incremented), the information GUID must be `OPM_GET_CODEC_INFO` `{4F374491-8F5F-4445-9DBA-95588F6B58B4}`, and the verifier (16 bytes) must be the CLSID of the MFT. The answer is an `OPM_REQUESTED_INFORMATION` with 20 bytes of information: the random number of the request and the merit **7**, signed with the same OMAC.

### ETW

Manifest provider `{4AF99AD7-8F3B-440B-951F-3AA0291892B2}` (`EventRegister` in `DllMain`, callback `ETW_EnableCallback` keeps the level and keywords): registered only, the DLL imports no `EventWrite`.

WPP provider `{7D41DBE7-CEF1-45FC-A4C9-45580223FB43}` (`RegisterTraceGuidsW`, control block `off_1001E048`, `TraceMessage` with the message GUIDs `{5A284CFD-49DA-CC7D-C168-B42313F532C9}` and `{1284006C-AF73-3555-149E-062005CCC86B}`): flag 0x10 function entry / exit (level ≥ 4), 0x08 errors (level ≥ 2), 0x04 information (level ≥ 4), 0x02 and 0x01 details (level ≥ 5).

### COM

| GUID | Use |
|------|-----|
| `{DF20DDFA-0D19-463A-AB46-E5D8EF6EFD69}` | CLSID of the MFT |
| `{D6C02D4B-6833-45B4-971A-05A4B04BAB91}` | `MFT_CATEGORY_VIDEO_DECODER` |
| `{ED418A9F-010D-4EDA-9AE3-9A65358D8D2E}` | `DXVA2_ModeMPEG4pt2_VLD_AdvSimple_NoGMC`, the decoder used |
| `{EFD64D74-C9E8-41D7-A5E9-E9B0E39FA319}` | `DXVA2_ModeMPEG4pt2_VLD_Simple`, accepted as a sign of MPEG-4 support |
| `{BBC56996-08F7-4ACD-A623-D95808ADF8DA}` | `DXVA2_ModeMPEG4pt2_VLD_AdvSimple_GMC`, recognised, not used |
| `{4F374491-8F5F-4445-9DBA-95588F6B58B4}` | `OPM_GET_CODEC_INFO` |
| `{EB533D5D-2DB6-40F8-97A9-494692014F07}`, `{A0CADE0F-06D5-4CF4-A1C7-F3CDD725AA75}` | `IMFDXGIDeviceManager`, `IDirect3DDeviceManager9` |
| `{10EC4D5B-975A-4689-B9E4-D0AAC30FE333}`, `{DB6F6DDB-AC77-4E88-8253-819DF9BBF140}`, `{61F21C45-3C0E-4A74-9CEA-67100D9AD5E4}` | `ID3D11VideoDevice`, `ID3D11Device`, `ID3D11VideoContext` |
| `{FC51A551-D5E7-11D9-AF55-00054E43FF02}` | `IDirectXVideoDecoderService` |
| `{0CFBAF3A-9FF6-429A-99B3-A2796AF8B89B}`, `{6F15AAF2-D208-4E89-9AB4-489535D34F9C}` | `IDirect3DSurface9`, `ID3D11Texture2D` (surface buffers) |
| `{245BF8E9-0755-40F7-88A5-AE0F18D55E17}`, `{C40A00F2-B93A-4D80-AE8C-5A1C634F58E4}`, `{7DC9D5F9-9ED9-44EC-9BBF-0600BB589FBB}` | `IMFTrackedSample`, `IMFSample`, `IMF2DBuffer` |
| `{799CABD6-3508-4DB4-A3C7-569CD533DEB1}` | Media type attribute set to 0 on the input and output types (?) |
