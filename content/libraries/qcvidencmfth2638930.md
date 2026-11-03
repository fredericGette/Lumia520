## qcvidencmfth2638930.dll

Hardware Media Foundation transform (MFT) of the MSM8930 that encodes H.263 video: "QC H263 Encode HW-MFT", build `P:\QCVidEncMFT\rel\8.2.1.1\arm\Release\qcvidencmfth2638930.pdb`.  
`qcvidencmfth2638930.dll` is an in-process COM server (249 functions) registered as an asynchronous hardware video encoder MFT, CLSID `{670E88D4-B18A-483A-8E0F-65A027838718}`, merit 7. The code is Qualcomm's generic "VENC HWMFT" (`CQCVideoEncoderMft`, the class names are in the debug strings) shared by the H.264 ([qcvidencmfth2648930.dll](./qcvidencmfth2648930.md), same code at the same addresses), VC-1, MPEG-4 ([qcvidencmftmpeg48930.dll](./qcvidencmftmpeg48930.md), same code) and H.263 encoders; this build only registers the H.263 CLSID, so the codec type is always 3 (H.263). It doesn't encode anything itself: it takes NV12 / `420O` frames, opens a private "decoder" `{B7BC9768-6665-4926-88A4-1751BC8515FB}` on a Direct3D 11 video device and drives it with `ID3D11VideoContext::DecoderExtension` commands (`D3D_VIDENC_CMD_*` / `D3D_VIDENC_PROP_*`). That device is the H.263 [encoder device](./qcvidum8930.md#encoder-devices) of [qcvidum8930.dll](./qcvidum8930.md), which forwards the commands to the VIDEO engine of [qcdxkm8930.sys](../drivers/qcdxkm8930.md) and calls back this DLL ([VideoUMDCb](#umd-callback-sub_10019bc0)) with the sequence header and each encoded frame.  
Like [qcviddecmft8930.dll](./qcviddecmft8930.md#iopmvideooutput-merit-certification) it implements `IOPMVideoOutput` with the same embedded certificate chain to prove its merit. The process that loads it (the media pipeline of the apps recording H.263 video, e.g. the camera for 3GP / MMS ?) isn't known.

Location on the phone: ?  

### Imports

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

The util, processthreads and sysinfo imports and the CRT startup functions of MSVCR110 are the Visual C++ 2012 DLL startup and `/GS` security cookie code. The classic-provider functions are the WPP tracing; the `stdio` functions, `OutputDebugStringW` and the mutex are the [debug log](#debug-log-and-dumps).

### Dependencies

No DLL is loaded at run time, no process is started and no COM object is created with `CoCreateInstance`.

| File | How | Use |
|------|-----|-----|
| `ID3D11Device` / `ID3D11VideoDevice` / `ID3D11VideoContext` | from the `IMFDXGIDeviceManager` given by `MFT_MESSAGE_SET_D3D_MANAGER`, otherwise its own device: `D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, …, D3D11_SDK_VERSION)` + `MFCreateDXGIDeviceManager` + `ResetDevice` | The H.263 encoder device of [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) (`CreateVideoDecoder` `{B7BC9768…}`), the input / output textures |
| `<VEncLogFilePath>\VEncHWMFTLog<time>.txt` | `fopen_s` | Debug log, see [Debug log](#debug-log-and-dumps) |
| `<VEncLogFilePath>\VEncInputDump<time>_<this>.raw`, `…\VEncOutputDump<time>_<this>.raw` | `fopen_s`, `fwrite` | Dumps of the input frames / encoded bitstream when `VEncInputDump` / `VEncOutputDump` are set |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x10002280 | none |
| 2 | `DllGetClassObject` | 0x100022A0 | `REFCLSID, REFIID, void **` |
| 3 | `DllRegisterServer` | 0x10002384 | none |
| 4 | `DllUnregisterServer` | 0x100026A0 | none |

The four exports of a COM server. A global counter (`dword_1003FCC0`) counts the class factories and MFT objects; `DllCanUnloadNow` returns `S_FALSE` while it isn't 0.

`DllGetClassObject` (0x10002008) accepts only `{670E88D4…}` (`dword_10026038`), else `CLASS_E_CLASSNOTAVAILABLE` (0x80040111). It builds a 12-byte class factory (vtable `off_100262A0`, refcount at +4, creation function `sub_10003E20` at +8). `IClassFactory::CreateInstance` (`sub_100021A0`) returns `CLASS_E_NOAGGREGATION` with an outer object, otherwise `CQCVideoEncoderMft::CreateInstance` (`sub_10003E48`) allocates the 0x22F0-byte [MFT object](#mft-object) (constructor `sub_10004260`), queries the requested interface, selects the codec from the CLSID (`sub_10003FBC`) and loads the [configuration](#registry) (`sub_10005014`).

### Startup

`start` (`_DllMainCRTStartup`, 0x10023048): the usual CRT startup with `__security_init_cookie`. `DllMain` (`sub_10002228`): on `DLL_PROCESS_ATTACH` it keeps the module handle (`dword_1003FCBC`) and calls `DisableThreadLibraryCalls`; nothing else. The manifest ETW provider is registered by the first object constructor (`McGenEventRegister`), the WPP provider by the [debug log](#debug-log-and-dumps) initialisation.

### Registry

`DllRegisterServer` gets the path of the DLL (`GetModuleFileNameW`), writes 7 string values under `HKEY_LOCAL_MACHINE` (`sub_100022B0`: `RegCreateKeyExW` + `RegSetValueExW` `REG_SZ`, table of 16-byte entries {root, key, value name, data}), then calls `MFTRegister`:

| Key | Value | Data |
|-----|-------|------|
| `Software\Classes\CLSID\{670E88D4-B18A-483A-8E0F-65A027838718}` | (default) | `QCOM Hardware Encoder - H263` |
| `…\InProcServer32` | (default) | Path of the DLL |
| same | `ThreadingModel` | `Both` |
| same | `ERROR` | `1` |
| same | `HIGH` | `0` |
| same | `MED` | `0` |
| same | `LOW` | `0` |

The four `ERROR` / `HIGH` / `MED` / `LOW` values are never read by this DLL (log levels of another build ?).

`MFTRegister(CLSID, MFT_CATEGORY_VIDEO_ENCODER {F79EAC7D-E545-4387-BDEE-D647D7BDE42A}, "QCOM Hardware Encoder - H263", 4 = MFT_ENUM_FLAG_HARDWARE, 2 input types, 1 output type, attributes)`. Input types: `MFMediaType_Video` + `NV12`, `420O` (Qualcomm's opaque NV12); output type: `MFMediaType_Video` + `H263`. The 11 registration attributes are the [attributes](#attributes) of the object (`MFCreateAttributes(11)`).

`DllUnregisterServer` deletes `Software\Classes\CLSID\{670E88D4-…}` (`RegDeleteTreeW`, `ERROR_FILE_NOT_FOUND` ignored) and calls `MFTUnregister` (`HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)` ignored).

At run time the configuration is read from `HKEY_LOCAL_MACHINE\Software\QCOM\MFTs\VideoEncoder` (`RegOpenKeyExW` `KEY_READ`, `RegQueryValueExW`), in `InitializeDefaultConfiguration` (`sub_10005014`) and `VideoDebugMsgInit` (`sub_10002AF4`). None of these values is created by the DLL:

| Value | Default | Use |
|-------|---------|-----|
| `VEncLogMsgMask` | ? | Mask of the debug messages sent to `OutputDebugStringW` (`sub_10003184`) |
| `VEncLogFileMask` | ? | Mask of the debug messages written to the log file |
| `VEncLogFilePath` | `\users` | Folder of the log and dump files (< 200 characters) |
| `EnableMotionDump`, `SwVencMEDump`, `SwVencOpDump`, `SwVencYUVDump` | 0 | Dump flags (motion estimation, software encoder output / YUV); `EnableMotionDump` is copied in the base config |
| `VEncSliceMode`, `VEncSliceSize` | codec default | Slice mode / size; ignored (default used) when the size is 0, or when the mode is `D3D_VIDENC_MSLICE_DISABLE` with a non-zero size |
| `VEncOutputSurfaceCount`, `VEncSystemOutputSurfaceCount` | default when out of range | Number of output buffers (video memory / system memory) |
| `VEncInputDump`, `VEncOutputDump` | 0 | Dump the input frames / encoded bitstream to `VEncInputDump…raw` / `VEncOutputDump…raw` |
| `720PTargetBitRate`, `720PThresholdBitRate` | 10 000 000, 14 000 000 | Default bitrate for 1280 × 720 when the output type has none |
| `1080PTargetBitRate`, `1080PThresholdBitRate` | 19 000 000, 20 000 000 | Same for 1920 × 1080 / 1088 |
| `FWVGATargetBitRate`, `FWVGAThresholdBitRate` | 4 500 000, 14 000 000 | Same for 854 / 864 × 480 |
| `VEncDisableEncoding` | 0 | "skip encode": `ProcessInput` only answers `METransformNeedInput` without encoding |

### MFT object

0x22F0 bytes (`sub_10004260`). The `QueryInterface` table (`off_1003AEF8`, `sub_10006898`) gives the offset of each interface:

| Offset | Vtable | IID | Interface |
|--------|--------|-----|-----------|
| 0x00 | `off_1003B0B0` | `{BF94C121-5B05-4E6F-8000-BA598961414D}` | `IMFTransform` |
| 0x04 | `off_1003B11C` | `{2CD0BD52-BCD5-4B89-B62C-EADC0C031E7D}` | `IMFMediaEventGenerator`: forwarded to the event queue (+0x17C0) |
| 0x08 | `off_1003AE50` | `{97EC2EA4-0E42-4937-97AC-9D6D328824E1}` | `IMFShutdown` |
| 0x0C | `off_1003AFA8` | `{901DB4C7-31CE-41A2-85DC-8FA0BF41B8DA}` | `ICodecAPI`, see [ICodecAPI](#icodecapi) |
| 0x10 | `off_1003AE3C` | `{73F0BE8E-57F7-4F01-AA66-9F57340CFE0E}` | Private interface (?) with `SetPartialOutputType` (`sub_10008A7C`) and `GetPrivateData` (`sub_10008904`) |
| 0x14 | `off_1003B15C` | `{03910848-AB16-4611-B100-17B88AE2F248}` | `IMFRealTimeClientEx`: the methods return `S_OK` and do nothing |
| 0x18 | `off_1003B030` | `{0A15159D-41C7-4456-93E1-284CD61D4E8D}` | `IOPMVideoOutput`, see [OPM](#iopmvideooutput) |
| 0x1C | `off_1003B138` | | `IMFAsyncCallback` (not in the table), allocator callback of the tracked output samples: `Invoke` (`sub_10003A94`) calls the 27th `IMFTransform` method `OnInvokeDelete` (`sub_100111D4`) |

Main fields (from the constructor and the methods; most of the others are queues and counters):

| Offset | Size | Comment |
|--------|------|---------|
| 0x20, 0x38, 0x50, 0x68, 0x80 | 5 × 0x18 | Critical sections (events, input queue, output list, output states, sample list) |
| 0x98 | 0x14 | Queue of the frames submitted and not yet returned by the encoder (`InternalProcessInput`) |
| 0xB0 | 4 | Output sample list (`VEncOutputSurfaceCount` entries of 32 bytes, default 8) |
| 0x174C | 4 | Encoder started (?): the bitrate / GOP / QP changes are only sent when set |
| 0x1774, 0x1778 | 8 | `ID3D11VideoContext`, `ID3D11VideoDecoder` (the encoder session) |
| 0x1780 | 4 | `m_hStartRespEvent` (auto-reset): sequence header received |
| 0x1784, 0x1788, 0x178C | 12 | `m_hStopDoneEvent`, `m_hFlushDone`, `m_hEOSDone` |
| 0x1790, 0x1794 | 8 | Input sample list (32-byte entries, default 8 entries), `m_hFreeIpSampleAvailable` (+0x179C) |
| 0x17A8, 0x17B0, 0x17BC | | `m_hFreeOpSampleAvailable`, `m_hRecvdAllOpBuff`, `m_hSystemFreeOpSampleAvailable` |
| 0x17C0 | 4 | `IMFMediaEventQueue` (`MFCreateEventQueue`) |
| 0x17C4 | 4 | Number of `METransformNeedInput` sent and not yet answered |
| 0x17E0 | 4 | Current output type |
| 0x17E4 | 4 | `IMFAttributes` of the MFT (50 entries), see [Attributes](#attributes) |
| 0x1808 | 0xB8 | Encoder caps returned by `D3D_VIDENC_PROP_GET_ENC_CAPS` |
| 0x18D4 | 0x78 | [Base configuration](#base-configuration), input of `D3D_VIDENC_CMD_INIT` |
| 0x1A00, 0x1A04 | 4 + 0x200 | Sequence header (size, data), only kept for H.264 and MPEG-4 |
| 0x1C04 | 0x1C | `D3D11_VIDEO_DECODER_EXTENSION` used for every [command](#decoderextension-commands) |
| 0x1C28 | 48 | [Encode frame](#encode-frame) parameters |
| 0x1C68 | 200 | Log / dump folder (`VEncLogFilePath`) |
| 0x1D30, 0x1D34 | 8 | Input / output dump flags; files at +0x1D38, +0x1D3C |
| 0x1D94–0x1DA8 | 24 | Target / threshold bitrates for 720p, 1080p, FWVGA |
| 0x2250 | 4 | Codec type: 1 H.264, 2 VC-1, 3 H.263, 4 MPEG-4 |
| 0x2268 | 4 | `SwVENCtoMFTCB` (`sub_1001BA08`), callback of the software encoder path (VC-1 only) |
| 0x229C | 16 | Output subtype |
| 0x22EC | 4 | Number of output subtypes at +0x229C, set with the codec type (1 for H.264 and H.263, 2 for VC-1 and MPEG-4): limit of `GetOutputAvailableType`, `MF_E_NO_MORE_TYPES` beyond |

`sub_10003FBC` compares the CLSID with the four CLSIDs of the family (`{7790EE16-08E3-426D-AADA-F96774308EA1}` H.264, `{ED93D261-C7CC-46E2-AE09-3CE7AE5C4ABC}` VC-1, `{8EB787DC-D1B6-421D-88A0-22539F9F12C3}` MPEG-4, `{670E88D4…}` H.263) and sets the codec type, the output subtypes and `MFT_ENUM_HARDWARE_URL_Attribute` = `QCOM Hardware Encoder - H263` in the attributes; only `{670E88D4…}` can reach it in this DLL. `{7790EE16…}` is the CLSID of [qcvidencmfth2648930.dll](./qcvidencmfth2648930.md), `{8EB787DC…}` the one of [qcvidencmftmpeg48930.dll](./qcvidencmftmpeg48930.md); the VC-1 one is probably that of another sibling encoder DLL (not analysed).

### Attributes

Attribute store of the object (`MFCreateAttributes(50)` in the constructor), returned by `GetAttributes`; `DllRegisterServer` gives the same values to `MFTRegister`:

| Attribute | Value |
|-----------|-------|
| `MFT_ENUM_HARDWARE_VENDOR_ID_Attribute` `{3AECB0CC-…}` | `VEN_QCOM` |
| `MFT_ENUM_HARDWARE_URL_Attribute` `{2FB866AC-…}` | `QC H263 Encode HW-MFT` at registration, `QCOM Hardware Encoder - H263` in the object |
| `MF_TRANSFORM_ASYNC` `{F81A699A-…}` | 1 |
| `MF_TRANSFORM_ASYNC_UNLOCK` `{E5666D6B-…}` | 0 in the object (every `IMFTransform` method returns `MF_E_TRANSFORM_ASYNC_LOCKED` until the client sets it, `MFTLocked` `sub_10018B0C`), 1 at registration |
| `MF_SA_D3D11_AWARE` `{206B4FC8-…}` | 1 |
| `MFT_SUPPORT_DYNAMIC_FORMAT_CHANGE` `{53476A11-…}` | 1 |
| `MF_TRANSFORM_CATEGORY_Attribute` `{CEABBA49-…}` | `MFT_CATEGORY_VIDEO_ENCODER` (registration) |
| `MFT_INPUT_TYPES_Attributes` `{4276C9B1-…}` | `NV12`, `420O` (registration) |
| `MFT_OUTPUT_TYPES_Attributes` `{8EAE8CF3-…}` | `H263` (registration) |
| `MFT_CODEC_MERIT_Attribute` `{88A7CB15-…}` | 7, proved by the [OPM](#iopmvideooutput) handshake |
| `MFT_TRANSFORM_CLSID_Attribute` `{6821C42B-…}` | `{670E88D4-B18A-483A-8E0F-65A027838718}` (registration) |

### IMFTransform

| Method | Function | Comment |
|--------|----------|---------|
| `GetStreamLimits`, `GetStreamCount` | sub_10006A28, sub_10006AB8 | 1 input, 1 output |
| `GetInputStreamInfo`, `GetOutputStreamInfo` | sub_1000BFE0, sub_1000C148 | Stream flags and sizes |
| `GetAttributes` | sub_100069B0 | The [attributes](#attributes) |
| `GetInputStreamAttributes` | sub_100157C8 | |
| `GetInputAvailableType` | sub_10006D14 | `NV12` and `420O`, built from the output type (`SetAvailableTypeProperties` `sub_10006E4C`: frame size, frame rate, progressive) |
| `GetOutputAvailableType` | sub_10008210 | The output type (`H263`, frame size, frame rate, `MF_MT_AVG_BITRATE`; profile / level only for H.264, VC-1, MPEG-4) |
| `SetInputType` | sub_10006F6C | See [Types](#types) |
| `SetOutputType` | sub_10008E0C | See [Types](#types) |
| `GetInputCurrentType`, `GetOutputCurrentType` | sub_10006B44, sub_10007E4C | Copy of the current type |
| `GetInputStatus`, `GetOutputStatus` | sub_1000D76C, sub_1000D17C | |
| `ProcessMessage` | sub_1000C228 | See [ProcessMessage](#processmessage-sub_1000c228) |
| `ProcessInput` | sub_1000C824 | See [Encoding](#encoding) |
| `ProcessOutput` | sub_1000D294 | See [Encoding](#encoding) |
| other stream methods | sub_10006B20 | `E_NOTIMPL` |

The MFT is asynchronous: it asks for input with `METransformNeedInput` (601) and announces each encoded frame with `METransformHaveOutput` (602), on its event queue (`QueueEvent`, `sub_10015B8C`); a drain ends with `METransformDrainComplete` (603), a marker with `METransformMarker` (604).

#### Types

The output type must be set first. `SetOutputType` (`ValidateOutputType`, `sub_1000A1B4`) checks the major type and the `H263` subtype, the frame size and frame rate, the profile / level, the interlace mode (progressive only) and the bitrate (`MF_MT_AVG_BITRATE`, at most the encoder's maximum; when missing, the default of the [registry](#registry) for the resolution, or failure in CBR). To validate the size it opens a temporary encoder session: device from the D3D manager (or its own D3D11 device), `ID3D11VideoDevice::CreateVideoDecoder({B7BC9768…}, width, height, format 106 DXGI_FORMAT_420_OPAQUE}, config)` and `DecoderExtension` 18 (`D3D_VIDENC_PROP_GET_ENC_CAPS`, 0xB8 bytes of output at +0x1808). Then `AddCodecPropertiesToOutputType` (`sub_100102BC`) and `UpdateBaseConfigProperties` (`sub_1000B28C`) copy the type into the [base configuration](#base-configuration): size, frame rate, `MF_MT_PIXEL_ASPECT_RATIO` (1:1 when missing), mean bitrate, GOP distance, rate control mode, QP, quality; `MF_MT_FIXED_SIZE_SAMPLES` 0, `MF_MT_ALL_SAMPLES_INDEPENDENT` 0, `MF_MT_COMPRESSED` 1 are set on the type. A new output type while streaming only updates the bitrate and GOP size (`CheckOutputTypeForDynamicChangesAndSignal`, `sub_1000AF5C`).

`SetInputType` (`ValidateInputType`, `sub_10007164`): major type `vids`, subtype `NV12` or `420O`, same width / height as the output type (or the `MF_MT_MINIMUM_DISPLAY_APERTURE`; the output size is taken from the input when it isn't set), `MF_MT_DEFAULT_STRIDE` at least the width, a frame rate of at most 240 fps and within 0.001 of the output frame rate, progressive, same pixel aspect ratio as the output.

### ProcessMessage (sub_1000C228)

| Message | Action |
|---------|--------|
| `MFT_MESSAGE_COMMAND_FLUSH` (0) | `OnFlush` (`sub_10017814`): `DecoderExtension` 19 (`D3D_VIDENC_CMD_FLUSH`), waits for `m_hFlushDone`, returns the queued samples |
| `MFT_MESSAGE_COMMAND_DRAIN` (1) | `OnDrain` (`sub_100174B0`): `DecoderExtension` 20 (`D3D_VIDENC_CMD_EOS`); `METransformDrainComplete` when the encoder answers `EOS_DONE` and all the frames are out |
| `MFT_MESSAGE_SET_D3D_MANAGER` (2) | `OnSetD3DManager` (`sub_10018A1C`): `ulParam` must be an `IMFDXGIDeviceManager`; device handle, `ID3D11Device`, `ID3D11VideoDevice`, immediate `ID3D11VideoContext` (`CheckD3D11Support` `sub_100185C8`). There is no Direct3D 9 path |
| `MFT_MESSAGE_NOTIFY_BEGIN_STREAMING` (0x10000000) | `OnBeginStreaming`: allocates the buffers and starts the encoder (`sub_10017B64`) |
| `MFT_MESSAGE_NOTIFY_START_OF_STREAM` (0x10000003) | `OnStartOfStream`: same if not done, then the first `METransformNeedInput` |
| `MFT_MESSAGE_NOTIFY_END_STREAMING` (0x10000001) | `StopEncoder` (`sub_1001811C`): `DecoderExtension` 2 (`D3D_VIDENC_CMD_STOP_ENCODER`), waits for `m_hStopDoneEvent` |
| `MFT_MESSAGE_NOTIFY_END_OF_STREAM` (0x10000002) | `OnEndOfStream` (`sub_10018078`) |
| `MFT_MESSAGE_COMMAND_MARKER` (0x20000000) | `OnCommandMarker`: `METransformMarker` once the frames before it are out (`ProcessMarkerEvent` `sub_100183D0`) |

#### Encoder start (InitializeHardware, sub_10009128)

1. `setProfile` / `setLevel` (`sub_10020C88`, `sub_10020AC4`) from the output type (`setProfile` only for H.264, VC-1, MPEG-4, `setLevel` only for H.264);
2. `MF_LOW_LATENCY` from the attributes (copied to the base config);
3. without a D3D manager (+0x19F4, +0x1764 null): `MFCreateDXGIDeviceManager`, `D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, 0, 0, NULL, 0, D3D11_SDK_VERSION, …)`, `ResetDevice`, `OnSetD3DManager`;
4. the encoder GUID from the subtype (`H264`, `WVC1`, `WMV3` → `{129F7B40…}`, `M4S2` / `MP4V` → `{CBB1A2A4…}`, `H263` → `{B7BC9768…}`; else "No cap exists for the VideoFormat"), `ValidateEncProfileConfig` (`sub_10016064`);
5. `ID3D11VideoDevice::CreateVideoDecoder({guid, width, height, 106}, D3D11_VIDEO_DECODER_CONFIG all 0)`;
6. default bitrate when needed (720p / 1080p / FWVGA from the registry), peak bitrate corrected to at least the mean bitrate;
7. `DecoderExtension` 0 (`D3D_VIDENC_CMD_INIT`) with the 0x78-byte [base configuration](#base-configuration) as input;
8. `DecoderExtension` 1 (`D3D_VIDENC_CMD_START_ENCODER`), then `WaitForSingleObject(m_hStartRespEvent, 5000)` for the [sequence header callback](#umd-callback-sub_10019bc0) ("Timeout(5 sec) for sequence header from START COMMAND"). For H.264 the header is put on the output type as `MF_MT_MPEG_SEQUENCE_HEADER` (`SetBlob`); for H.263 and MPEG-4 `OnOutputTypeChanged` (`sub_10020FE0`) is called instead: it sets `MF_MT_MPEG4_SAMPLE_DESCRIPTION`, for H.263 a fixed 0x75-byte `stsd` with an `s263` entry and a `d263` box (vendor `Qcom`, template `unk_1003F108`) patched with the width and height, for MPEG-4 an `mp4v` entry with the VOL header (see [qcvidencmftmpeg48930.dll](./qcvidencmftmpeg48930.md)#sequence-header-and-sample-description).

`AllocateResources` (`sub_100161B4`) asks the buffer requirements (`DecoderExtension` 6 `D3D_VIDENC_PROP_GET_BUFFER_REQ`, 16 bytes of output) and creates the output buffers (`ID3D11Device::CreateBuffer`) and, when the input frames have to be copied, the input textures (`CreateTexture2D`, `AllocateInputResources` `sub_10016DCC`); `AllocateSystemOutputBuffer` (`sub_10016A88`) creates the system memory buffers (`MFCreateMemoryBuffer`) returned to the client in tracked samples (`MFCreateTrackedSample`).

When a command returns `DXGI_ERROR_DEVICE_REMOVED` (0x887A0005), or the encoder reports a TDR (`NotifyTDREvent` `sub_1001A078`), `RestartHardware` / `ReconfigD3DDevice` (`sub_1001DC94`, `sub_1001E18C`) sends `STOP_ENCODER`, recreates the device and the session, and sends `INIT` and `START_ENCODER` again.

### Base configuration

0x78 bytes at +0x18D4, sent as the input of `D3D_VIDENC_CMD_INIT` (filled by `InitializeDefaultConfiguration`, `UpdateBaseConfigProperties` and `InitializeHardware`). The names come from the "HW BASE CONFIG" dump (`sub_100205FC`); [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) copies the fields into the open escape 0x2200:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00, 0x04 | 8 | Width, height (default 640 × 480 for H.263, 1280 × 720 for H.264) |
| 0x08 | 4 | Stride |
| 0x0C | 16 | Input format: `{FB8D8600-25C3-435E-94C5-A4B50397EC46}` NV12_16M2KA (default, linear NV12), `{B27227A5-59FB-4BFC-AF1E-42237F213DBC}` TILE_4X2 (set by `InternalProcessInput`, with a hardware restart, when the client's texture has `D3D11_BIND_DECODER`) |
| 0x1C, 0x20 | 8 | Frame rate denominator, numerator (default 1, 30) |
| 0x24, 0x28 | 8 | Profile, level (`setProfile` / `setLevel`; profile 0 for H.263) |
| 0x2C | 4 | Rate control mode (`CODECAPI_AVEncCommonRateControlMode`, mapped through a table) |
| 0x30 | 4 | GOP distance |
| 0x34 | 4 | QP (default 8 for H.263, 24 for H.264) |
| 0x38, 0x3C | 8 | Mean bitrate (default 1 536 000 for H.263, 8 000 000 for H.264: table `unk_1003F1F0` for 640 × 480 / 1280 × 720), peak bitrate |
| 0x40 | 1 | `EnableMotionDump` |
| 0x44 | 4 | Layer count, at most 2 (temporal layers ?) |
| 0x48 | 4 | UAB protection level |
| 0x4C | 4 | [VideoUMDCb](#umd-callback-sub_10019bc0) (`sub_10019BC0`): callback called by the UMD |
| 0x50 | 4 | Callback context: the MFT object |
| 0x54 | 4 | Quality vs speed |
| 0x58 | 1 | Low latency (`MF_LOW_LATENCY`) |
| 0x5C | 4 | VBV buffer size |
| 0x60 | 4 | Hierarchical P layers |
| 0x64, 0x68 | 8 | Slice mode (default 1 = `D3D_VIDENC_MSLICE_DISABLE` ?), slice size (`VEncSliceMode`, `VEncSliceSize`) |
| 0x6C | 4 | Request flags (bit 0: NAL unit mode, "`CODECAPI_VideoEncNalUnits`", set by default for H.264, see [qcvidencmfth2648930.dll](./qcvidencmfth2648930.md#icodecapi); bits 0 and 1 are passed to the KMD) |
| 0x70, 0x74 | 8 | Pixel aspect ratio numerator, denominator (must be non-zero) |

### DecoderExtension commands

Every command goes through `ID3D11VideoContext::DecoderExtension(decoder, &ext)` (vtable +0x30) with the `D3D11_VIDEO_DECODER_EXTENSION` at +0x1C04 or on the stack. The `Function` codes are those dispatched by the encoder device of [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) (`sub_1002725C`):

| Function | Name (debug strings) | Sender | Input / output | qcvidum8930.dll |
|----------|----------------------|--------|----------------|-----------------|
| 0 | `D3D_VIDENC_CMD_INIT` | InitializeHardware, ReconfigD3DDevice | in: [base config](#base-configuration), 0x78 | Open: escape 0x2200, events, thread |
| 1 | `D3D_VIDENC_CMD_START_ENCODER` | InitializeHardware, RestartHardware | none | Command 0x1200 |
| 2 | `D3D_VIDENC_CMD_STOP_ENCODER` | StopEncoder, Shutdown, RestartHardware | none | Command 0x1204 |
| 3 | `D3D_VIDENC_CMD_ENCODE_FRAME` | DoEncoding (`sub_10012004`) | in: [encode frame](#encode-frame), 48; 2 resources (input texture, output buffer) | Command 0x1201 |
| 6 | `D3D_VIDENC_PROP_GET_BUFFER_REQ` | AllocateResources | out: 16 | Get property 3 |
| 9 | `D3D_VIDENC_PROP_SET_AVGBITRATE` | BitRateChanged (`sub_10010DE4`), `CODECAPI_AVEncCommonMeanBitRate` | in: 4 (bits/s) | Set property 1 |
| 11 | `D3D_VIDENC_PROP_SET_PEAKBITRATE` | BitRateChanged, `CODECAPI_AVEncCommonMaxBitRate` | in: 4 | Set property 2 |
| 13 | `D3D_VIDENC_PROP_SET_GOPDISTANCE` | GopSizeChanged (`sub_10010F5C`) | in: 4 | Set property 4 |
| 14 | `D3D_VIDENC_PROP_SET_LOCKRES` | LockRes (`sub_1001A1B4`) | in: 8 {subresource, map mode 1 read / 2 write}; out: 16 {pointer, ?, 64-bit size}; 1 resource | Local: lock callback of the runtime |
| 15 | `D3D_VIDENC_PROP_SET_UNLOCKRES` | UnLockRes (`sub_1001A4B8`) | in: 4 (subresource); 1 resource | Local: unlock callback |
| 17 | `D3D_VIDENC_PROP_SET_LAYER_QP` | LayerQPChanged (`sub_10011064`) | | Set property 6 |
| 18 | `D3D_VIDENC_PROP_GET_ENC_CAPS` | ValidateOutputType | out: 0xB8 (max size, encoder GUIDs, input formats) | Local: copy of the caps |
| 19 | `D3D_VIDENC_CMD_FLUSH` | OnFlush | none | Command 0x1203 |
| 20 | `D3D_VIDENC_CMD_EOS` | OnDrain | none | Command 0x1202 |

`LockRes` / `UnLockRes` give the CPU address of a texture or buffer of the session: they are used to copy the input frame into the encoder's own textures (`CopyInputFrame`, `sub_1001EB5C`, when the client's sample isn't usable directly), to read the bitstream into the system memory sample (`CopyOutputData`, `sub_10014B90`) and for the dumps.

### Encoding

`ProcessInput(0, sample, 0)` (`sub_1000C824`): `MF_E_NOTACCEPTING` without a pending `METransformNeedInput`. With `VEncDisableEncoding` the sample is dropped and a new `METransformNeedInput` queued. Otherwise `InternalProcessInput` (`sub_10011658`) / `DoEncoding` (`sub_10012004`):
1. finds the `ID3D11Texture2D` of the sample; an NV12 or `420O` texture is used directly, otherwise (system memory, or a stride that "might lead to TDR") the frame is copied into a free input texture (`GetFreeInputSampleIndex`, `LockRes`, `CopyInputFrame`, `UnLockRes`);
2. takes a free output buffer (`GetFreeOutputSampleIndex`, `sub_10014710`);
3. queues the input sample in the pending list (+0x98) and fills the [encode frame](#encode-frame) parameters;
4. `DecoderExtension` 3 (`D3D_VIDENC_CMD_ENCODE_FRAME`);
5. queues another `METransformNeedInput` while input buffers are free.

The encoded frame comes back asynchronously in the [bitstream callback](#umd-callback-sub_10019bc0), which queues `METransformHaveOutput`. `ProcessOutput` (`sub_1000D294`) / `InternalProcessOutput` (`sub_10014534`) / `GetOutputEncodedSample` (`sub_100151AC`) returns the oldest encoded frame in a tracked system memory sample (copy of the bitstream with `CopyOutputData`), with its time stamp and duration and `MFSampleExtension_CleanPoint` for a key frame. When the client releases the sample, `OnInvokeDelete` (`sub_100111D4`) puts the buffer back in the free list.

#### Encode frame

48 bytes at +0x1C28:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Cookie of the input: pending-list entry (sample, texture), returned in the bitstream callback |
| 0x04 | 4 | Cookie of the output buffer entry, returned in the bitstream callback |
| 0x08 | 4 | Array slice of the input texture |
| 0x10 | 8 | Sample time (100 ns) |
| 0x18 | 8 | Sample duration (?) |
| 0x20 | 1 | 1 |
| 0x24 | 4 | QP (+0x34 of the [base configuration](#base-configuration)) |
| 0x28 | 1 | Flag at +0x19FC, cleared after each frame: force key frame (`CODECAPI_AVEncVideoForceKeyFrame`) ? |

[qcvidum8930.dll](./qcvidum8930.md#encoder-devices) copies these fields into the 0x80-byte command 0x1201 (`VED_EncodeFrame` in the KMD).

### UMD callback (sub_10019BC0)

`VideoUMDCb` is called by [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) from its event thread (the events read with escape 0x2203, or type 6 when that escape fails or the session is stopping). The structure has the type at +0, the data from +8 and the context (the MFT object) at +0x210:

| Type | Name | Action |
|------|------|--------|
| 0 | `D3D_VIDENC_CB_TYPE_SEQHDR` | `ProcessSeqHdrCb` (`sub_100199D4`): {size ≤ 0x200, data}; kept for H.264 / MPEG-4 (+0x1A00), then `SetEvent(m_hStartRespEvent)` |
| 1 | `D3D_VIDENC_CB_TYPE_BITSTREAM` | `ProcessBitStreamCb` (`sub_10018B8C`): {+0 input done, +4 input cookie, +8 output done, +0xC output cookie, +0x10 ?, +0x14 filled length, +0x1C frame type 1, 2, 4, 8 or 16 (1 / 16: key frame)}; frees the input, sets the length of the output buffer and queues `METransformHaveOutput`; an empty frame returns the buffer and asks for more input. VC-1 goes to the software path (`CallSwEncodeFrame`, `sub_1001A75C`) instead |
| 2 | | Error (data: `E_FAIL`, flag): trace only |
| 3 | `D3D_VIDENC_CB_TYPE_STOP_DONE` | `SetEvent(m_hStopDoneEvent)`; never sent by qcvidum8930.dll |
| 4 | `D3D_VIDENC_CB_TYPE_EOS_DONE` | `SetEvent(m_hEOSDone)` |
| 5 | `D3D_VIDENC_CB_TYPE_FLUSH_DONE` | `SetEvent(m_hFlushDone)` |
| 6 | `D3D_VIDENC_CB_TYPE_DESTROY_SESSION` (?) | `NotifyTDREvent` (`sub_1001A078`) then `SetEvent(m_hStopDoneEvent)`: the end of a stop, or a lost session |

### ICodecAPI

`IsSupported` (`sub_1000DA14`) and `IsModifiable` (`sub_1000DCFC`) use a table per codec; for H.263 (`unk_1003F478`, 12 entries of 20 bytes {GUID, modifiable while streaming}):

| Property | Modifiable |
|----------|------------|
| `CODECAPI_AVEncCommonRateControlMode` `{1C0608E9-370C-4710-8A58-CB6181C42423}` | no |
| `CODECAPI_AVEncCommonMaxBitRate` `{9651EAE4-39B9-4EBF-85EF-D7F444EC7465}` | yes, `D3D_VIDENC_PROP_SET_PEAKBITRATE` |
| `CODECAPI_AVEncCommonQuality` `{FCBF57A3-7EA5-4B0C-9644-69B40C39C391}` | no |
| `CODECAPI_AVEncCommonQualityVsSpeed` `{98332DF8-03CD-476B-89FA-3F9E442DEC9F}` | no |
| `CODECAPI_AVEncMPVGOPSize` `{95F31B26-95A4-41AA-9303-246A7FC6EEF1}` | yes, `D3D_VIDENC_PROP_SET_GOPDISTANCE` |
| `CODECAPI_AVEncCommonBufferSize` `{0DB96574-B6A4-4C8B-8106-3773DE0310CD}` | no |
| `CODECAPI_AVEncCommonMeanBitRate` `{F7222374-2144-4815-B550-A37F8E12EE52}` | yes, `D3D_VIDENC_PROP_SET_AVGBITRATE` |
| `CODECAPI_AVEncVideoForceKeyFrame` `{398C1B98-8353-475A-9EF2-8F265D260345}` | yes, flag of the next [encode frame](#encode-frame) ? |
| `CODECAPI_AVEncCommonLowLatency` `{9D3ECD55-89E8-490A-970A-0C9548D5A56E}` | no |
| `CODECAPI_AVLowLatencyMode` `{9C27891A-ED7A-40E1-88E8-B22727A024EE}` | no |
| `CODECAPI_AVEncVideoEncodeQP` `{2CB5696B-23FB-4CE1-A0F9-EF5B90FD55CA}` | yes |
| `CODECAPI_DropNumFrames` `{98C78118-70F8-4211-BC53-DE2ECB82C6D2}` | yes |

`GetValue` (`sub_1000DFC0`) and `SetValue` (`sub_1000E2A4`) convert between `VARIANT` and `PROPVARIANT` (`QcVariantToPropVariant` / `QcPropVariantToVariant`); before streaming the values go into the output type / base config (`UpdateBaseConfigFromCodecAPI`, `sub_1000ED88`), while streaming the modifiable ones are sent with the commands above. `GetParameterRange`, `GetParameterValues`, `RegisterForEvent`… return `E_NOTIMPL` (`sub_1000D8C0`).

### IOPMVideoOutput

Same handshake as [qcviddecmft8930.dll](./qcviddecmft8930.md#iopmvideooutput-merit-certification) (interface at +0x18): `StartInitialization` (`sub_10021648`) returns 16 random bytes (`BCryptGenRandom`, kept at +0x2259) and a copy of the 3833-byte certificate (`unk_1003C290`, "Windows 8 Prerelease Merit 50", "Microsoft Digital Media Authority 2005"); `FinishInitialization` (`sub_10021BA0`) decrypts the 256-byte parameters with the obfuscated RSA key (`ConvertLegacyRsaPrivateKeyToBCryptBlob` `sub_1002206C`, RSA-OAEP / SHA-512); `GetInformation` (`sub_100217B4`) checks the OMAC (`ComputeOMAC` `sub_100223B0`), the sequence number, `OPM_GET_CODEC_INFO` and a verifier equal to one of the four encoder CLSIDs, and answers merit **7**. `COPPCompatibleGetInformation` and `Configure` return `E_NOTIMPL`.

### Debug log and dumps

`VideoDebugMsgInit` (`sub_10002AF4`, from `InitializeDefaultConfiguration`; reference counted, `VideoDebugMsgDeInit` `sub_10003028` in the destructor) registers the WPP provider, creates the mutex `MFTDebugLogMutex` (`CreateMutexW`, waited 5 s), reads `VEncLogMsgMask`, `VEncLogFileMask` and `VEncLogFilePath`, and opens `<path>\VEncHWMFTLog<_time64>.txt` (or keeps the file of the previous session). `sub_10003184(this, level, format, …)` formats a message (`vsprintf_s`) and sends it to `OutputDebugStringW` and / or the log file according to the masks; levels 1, 2, 4, 8 (8 = errors, written as `##ERROR## 0x<this>,<message>`). `PrintPerf` (`sub_100033B4`) writes `VENCPERF,<name>,<id>,<time>,…` lines with `QueryPerformanceCounter`.

### ETW

Manifest provider `{CABA4C43-CDA9-4E5B-BF10-48FB256C8138}` (`EventRegister` in the first constructor, callback `ETW_EnableCallback`). The events are written by `sub_10003800` (one string), `sub_10003860`, `sub_100038C4` and `sub_1000393C` (string + 64-bit time, + size), only when bit 0x10 of the enable mask (`dword_1003FC80`) is set. All are level 4, keyword 0x2:

| Event | Written when |
|-------|--------------|
| 106 | `D3D_VIDENC_CMD_INIT` (InitializeHardware, RestartHardware) |
| 107 | `D3D_VIDENC_CMD_START_ENCODER` |
| 109 | `QueueEvent` (`sub_10015B8C`) |
| 110 | `ProcessInput` |
| 111 | `D3D_VIDENC_CMD_ENCODE_FRAME` |
| 112 | `ProcessBitstreamCb` (with the length) |
| 113, 114 | `ProcessOutput` begin / end |
| 116 | `OnInvokeDelete` |
| 117 | `OnDrain` |
| 119 | `InternalProcessInput` |
| 120, 121 | `SwVENCtoMFTCB` (software path) |
| 122 | `D3D_VIDENC_CMD_STOP_ENCODER` (StopEncoder, Shutdown, RestartHardware) |
| 123 (opcode 1) | `MFT_MESSAGE_NOTIFY_END_OF_STREAM` |

WPP provider `{CEA35F95-03DB-4F70-A5C2-25E3ACA61E2A}` (`RegisterTraceGuidsW` in `sub_10002A7C`, control block at `dword_1003FC90`, `TraceMessage`): flag 0x08 errors (level ≥ 2), 0x04 information, 0x02 details (level ≥ 4), 0x01 (level ≥ 5).

### COM

| GUID | Use |
|------|-----|
| `{670E88D4-B18A-483A-8E0F-65A027838718}` | CLSID of the MFT |
| `{7790EE16-08E3-426D-AADA-F96774308EA1}`, `{ED93D261-C7CC-46E2-AE09-3CE7AE5C4ABC}`, `{8EB787DC-D1B6-421D-88A0-22539F9F12C3}` | CLSIDs of the H.264 ([qcvidencmfth2648930.dll](./qcvidencmfth2648930.md)), VC-1 and MPEG-4 ([qcvidencmftmpeg48930.dll](./qcvidencmftmpeg48930.md)) encoders of the same family (not registered here) |
| `{F79EAC7D-E545-4387-BDEE-D647D7BDE42A}` | `MFT_CATEGORY_VIDEO_ENCODER` |
| `{B7BC9768-6665-4926-88A4-1751BC8515FB}` | H.263 encoder device of [qcvidum8930.dll](./qcvidum8930.md#encoder-devices) |
| `{129F7B40-5C5B-48E5-8178-48C0CEA05A90}`, `{CBB1A2A4-4EA1-491E-ADC9-70B373B76036}` | H.264 (opened by [qcvidencmfth2648930.dll](./qcvidencmfth2648930.md)) and MPEG-4 (opened by [qcvidencmftmpeg48930.dll](./qcvidencmftmpeg48930.md)) encoder devices (other codec types) |
| `{FB8D8600-25C3-435E-94C5-A4B50397EC46}` | Input format NV12_16M2KA (linear NV12), [base configuration](#base-configuration) +0x0C; buffer type 160 in qcvidum8930.dll |
| `{B27227A5-59FB-4BFC-AF1E-42237F213DBC}` | Input format TILE_4X2 (tiled, decoder-bound textures); buffer type 159 |
| `{4F374491-8F5F-4445-9DBA-95588F6B58B4}` | `OPM_GET_CODEC_INFO` |
| `{73F0BE8E-57F7-4F01-AA66-9F57340CFE0E}` | Private interface at +0x10 (?) |
