## MFCaptureEngine.dll

The Media Foundation capture engine (`IMFCaptureEngine`): it turns a camera and a microphone into preview, video recording and photo outputs. On the phone it's the engine behind the `Windows.Media.Capture` API.  
`MFCaptureEngine.dll` (323 296 bytes, 1353 functions, all named from the PDB `MFCaptureEngine.pdb`, ATL + CRT) is Microsoft's capture engine. It builds a source reader on the camera / microphone media source (`CCaptureSource`), and three sinks on top of it (`CCapturePreviewSink`, `CCaptureRecordSink`, `CCapturePhotoSink`). Each sink is backed by a sink writer to a video renderer, a file (URL), an application media sink or a sample grabber. Operations are queued and run on MF work queues (`CCaptureEngineOpQueue`), and the results go back to the application as `MF_CAPTURE_ENGINE_*` events. The phone build adds:
- "WP8" camera controls: `PROPSETID_VIDCAP_CAMERACONTROL` properties 1000–1031, with the range read from property 1024 ([device controls](#device-controls)), on top of the extended camera controls (`KSPROPERTYSETID_ExtendedCameraControl`). Per-device [registry overrides](#extended-control-overrides) can disable an extended control or replace its capability;
- the shutter / record [camera sounds](#camera-sound), from `audioses.dll` and `CoreMmRes.dll`, with a "regional" sound level, and background audio muted while recording;
- power dependency coordinator [scenarios](#pdc-scenarios) (`\PdcPort`, components 0x408, 0x413, 0x417) while the preview runs and while a video is recorded;
- the Qualcomm phone WIC JPEG encoder for NV12 photos, with the capture metadata passed along ([photo encoder](#photo-encoder)), and a [photo buffer budget](#photo-buffer-budget) that depends on the RAM size.

The client is `WINDOWS.MEDIA.DLL` (`Windows.Media` WinRT classes, not documented here): `MediaCaptureServer::_Initialize` creates the engine by COM (`CLSID_MFCaptureEngineClassFactory`, see [MFCreateCaptureEngine](#mfcreatecaptureengine-0x10019d4c)). It sets the phone attributes [read by the engine](#configuration-attributes) (`MF_CAPTURE_ENGINE_CAMERA_REGIONAL_SOUND_LEVEL`, `MF_CAPTURE_ENGINE_CUSTOM_CAMERA_SOUND`, `MF_DO_NOT_MUTE_BACKGROUND_AUDIO`, `MF_DEVICE_BROKER_THREADID`, `MF_CAPTURE_ENGINE_MEDIA_CATEGORY`, `MF_CAPTURE_ENGINE_RECORD_DURATION_LIMITATION`; values in the [client](#client-windowsmediadll) section). It reserves the hardware with [MFPalWP.dll](./mfpalwp.md#callers-in-windowsmediadll) and sends some KS properties itself. The camera driver on the other side of the KS properties is [qccamavs8930.sys](../drivers/qccamavs8930.md#automation-table).

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| MFPlat.DLL (delay-load) | `MFStartup`, `MFShutdown`, `MFLockPlatform`, `MFUnlockPlatform`, `MFAllocateSerialWorkQueue`, `MFUnlockWorkQueue`, `MFPutWorkItem`, `MFPutWorkItemEx`, `MFPutWaitingWorkItem`, `MFCancelWorkItem`, `MFCreateAsyncResult`, `MFCreateMediaEvent`, `MFCreateAttributes`, `MFCreateMediaType`, `MFCreateSample`, `MFCreateMemoryBuffer`, `MFCreateAlignedMemoryBuffer`, `MFCreate2DMediaBuffer`, `MFCreateWICBitmapBuffer`, `MFCreateCollection`, `MFCreateStreamOnMFByteStream`, `MFCalculateImageSize`, `MFGetStrideForBitmapInfoHeader`, `MFGetSystemTime`, `MFRegisterPlatformWithMMCSS`, `MFUnregisterPlatformFromMMCSS` |
| MFCORE.dll (delay-load) | `MFEnumDeviceSources`, `MFCreateAggregateSource`, `MFCreateSampleGrabberSinkActivate` |
| MFReadWrite.dll (delay-load) | `MFCreateSourceReaderFromMediaSource`, `MFCreateSinkWriterFromURL`, `MFCreateSinkWriterFromMediaSink` |
| ext-ms-win-audiocore-pal-l1-1-0.dll (delay-load) | `IsAudioPlayerSupported`, `CreateCameraSoundPlaybackWrapper` |
| api-ms-win-core-com-l1-1-1.dll (delay-load) | `CoCreateInstance`, `CoTaskMemAlloc`, `CoTaskMemRealloc`, `CoTaskMemFree`, `PropVariantClear`, `StringFromGUID2`, `CreateStreamOnHGlobal`, `GetHGlobalFromStream` |
| OLEAUT32.dll (delay-load) | `VariantInit`, `VariantClear`, `VarUI4FromStr` |
| api-ms-win-devices-config-l1-1-1.dll (delay-load) | `CM_Open_Device_Interface_KeyW`, `CM_Get_Device_Interface_PropertyW`, `CM_Locate_DevNodeW`, `CM_Get_DevNode_PropertyW`, `CM_MapCrToWin32Err` |
| ntdll.dll | `ZwAlpcConnectPort`, `ZwAlpcSendWaitReceivePort`, `ZwAlpcDisconnectPort`, `ZwAlpcCancelMessage`, `ZwAlpcQueryInformation`, `AlpcInitializeMessageAttribute`, `AlpcGetMessageAttribute`, `TpAllocAlpcCompletion`, `TpWaitForAlpcCompletion`, `TpReleaseAlpcCompletion`, `ZwClose`, `RtlInitUnicodeString`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlWaitOnAddress`, `RtlWakeAddressAll`, `vDbgPrintEx` |
| api-ms-win-core-registry-l1-1-0.dll | `RegGetValueW`, `RegOpenKeyExW`, `RegCreateKeyExW`, `RegSetValueExW`, `RegDeleteValueW`, `RegEnumKeyExW`, `RegQueryInfoKeyW`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleFileNameW`, `DisableThreadLibraryCalls`, `FindResourceExW`, `LoadResource`, `SizeofResource` |
| api-ms-win-core-quirks-l1-1-0.dll | `QuirkIsEnabled` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GlobalMemoryStatusEx` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-eventing-classicprovider-l1-1-0.dll | `RegisterTraceGuidsW`, `UnregisterTraceGuids`, `GetTraceLoggerHandle`, `GetTraceEnableLevel`, `GetTraceEnableFlags`, `TraceMessage` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `InitializeSRWLock`, `AcquireSRWLockShared`, `ReleaseSRWLockShared`, `AcquireSRWLockExclusive`, `ReleaseSRWLockExclusive`, `CreateEventW`, `SetEvent`, `ResetEvent`, `Sleep` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `WaitForMultipleObjects` |
| api-ms-win-core-heap-l1-2-0.dll, api-ms-win-core-heap-obsolete-l1-1-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapFree`, `GlobalAlloc`, `GlobalLock`, `GlobalUnlock` |
| api-ms-win-core-string-l1-1-0.dll, -l2-1-0, -obsolete-l1-1-0 | `MultiByteToWideChar`, `WideCharToMultiByte`, `CharNextW`, `lstrcmpiW` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentThreadId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-debug-l1-1-1.dll | `OutputDebugStringA` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| msvcrt.dll | `malloc`, `free`, `realloc`, `operator new`/`delete`, `memcpy`, `memmove`, `memset`, `memcmp`, `wcslen`, `_vsnwprintf`, `log10`, `_CxxThrowException`, `__CxxFrameHandler3`, … (CRT, `_initterm`, `__dllonexit`) |

The msvcrt, rtlsupport, errorhandling, debug, `TerminateProcess` and delayload imports are the Visual C++ DLL CRT startup, C++ exceptions, delay-load helper and `/GS` cookie code. The registry writes, the resource functions and `RegEnumKeyExW` belong to the ATL registrar (`CRegObject` / `CRegParser`), linked in but not used by the engine. The ntdll ALPC functions are the [PDC](#pdc-scenarios) client. `GetTraceEnableLevel` … `TraceMessage` are WPP.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `audioses.dll` | `LoadLibraryExW(…, LOAD_LIBRARY_SEARCH_SYSTEM32)`, `GetProcAddress("DllGetClassObject")`, class `AudioPlayerFacade` `{4606D211-AFD4-42FA-8C8F-161D81519688}` ([camera sound](#camera-sound)) | Plays the camera sounds |
| `CoreMmRes.dll` | `LoadLibraryExW(…, LOAD_LIBRARY_SEARCH_SYSTEM32)`, module handle passed to the audio player | Resource module of the camera sounds (ids 0xC2F, 0xC30, 0xC31) |
| DLL behind `ext-ms-win-audiocore-pal-l1-1-0` (?) | delay-load (`IsAudioPlayerSupported`, `CreateCameraSoundPlaybackWrapper`) | Other camera sound player, used when `IsAudioPlayerSupported` returns 0 |
| `{D313A859-B510-461A-B4A7-70FF73AEF1F1}` `CLSID_DeviceAccessPolicyCheck` (DLL ?) | `CoCreateInstance`, interface `{7D276FF2-CE90-4275-A2A8-9A48B10D3E0B}` ([access check](#device-access-check)) | Checks the app's access to the camera / microphone |
| `{68ED5C62-F534-4979-B2B3-686A12B2B34C}` `CLSID_WICJpegQualcommPhoneEncoder` (DLL ?) | `CoCreateInstance`, `IWICBitmapEncoder` ([photo encoder](#photo-encoder)) | JPEG encoding of NV12 photos (also created by [PhotosApp.Models.dll](./photosapp.models.md#dependencies)) |
| `{317D06E8-5F24-433D-BDF7-79CE68D8ABC2}` `CLSID_WICImagingFactory2` (WindowsCodecs.dll) | `CoCreateInstance`, `IWICImagingFactory` | Other photo encoders, format conversion |
| `{88753B26-5B24-49BD-B2E7-0C445C78C982}` `CLSID_VideoProcessorMFT` | `CoCreateInstance`, `IMFTransform` | Photo scaling / colour conversion ("XVP") |
| `{4D4DEDAA-43C5-480D-9EE0-1464F9F4FF4B}` `CLSID_SVRActivate` (video renderer) | `CoCreateInstance`, `IMFActivate` (`CCaptureRendererBasedSink::CreateSVR`) | Preview to a window / surface |
| `{BCDE0395-E52F-467C-8E3D-C4579291692E}` `CLSID_MMDeviceEnumerator` (MMDevAPI) | `CoCreateInstance`, `IMMDeviceEnumerator` (`GetAudioDeviceContainerID`) | `PKEY_Device_ContainerId` of the microphone, to pick the microphone of the camera's container |
| `{00000323-0000-0000-C000-000000000046}` `CLSID_StdGlobalInterfaceTable` | `CoCreateInstance` (ATL `GetGITPtr`) | ATL |
| ALPC port `\PdcPort` | `ZwAlpcConnectPort` ([PDC scenarios](#pdc-scenarios)) | Power dependency coordinator, served by the kernel |
| Camera and microphone devices | `MFEnumDeviceSources`, `CM_*` on the symbolic link, `IKsControl` on the source | Capture devices; KS properties go to [qccamavs8930.sys](../drivers/qccamavs8930.md) |

No process is started. The output files (recordings, photos) are URLs or byte streams given by the application.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x1000EC6C | none |
| 2 | `DllGetClassObject` | 0x100288C0 | `REFCLSID, REFIID, void **` |
| 3 | `MFCreateCaptureEngine` | 0x10019D4C | `IMFCaptureEngine **ppEngine` |

There's no `DllRegisterServer`: the class is registered by the system image. `DllGetClassObject` is `CComModule::GetClassObject` with an object map of one class, `CMFCaptureEngineClassFactory` (`IMFCaptureEngineClassFactory`). `DllCanUnloadNow` returns `S_FALSE` while the ATL lock count (`dword_1003D6AC`) isn't 0.

### MFCreateCaptureEngine (0x10019D4C)

A jump to `MFCaptureEngineCreateInstance` (0x10013A10). The engine is created the same way as by the WinRT client:
1. `E_POINTER` if `ppEngine` is NULL.
2. `CoCreateInstance(CLSID_MFCaptureEngineClassFactory {EFCE38D3-8914-4674-A7DF-AE1B3D654B8A}, CLSCTX_INPROC_SERVER, IID_IMFCaptureEngineClassFactory {8F02D140-56FC-4302-A705-3A97C78BE779})`.
3. `IMFCaptureEngineClassFactory::CreateInstance(CLSID_MFCaptureEngine` (same GUID)`, IID_IMFCaptureEngine {A6BBA433-176B-48B2-B375-53AA03473207}, ppEngine)`; `*ppEngine` = NULL on failure.

The engine object is `CCaptureEngine` (`CreateInstance` 0x10035618, constructor `??0CCaptureEngine` 0x1001E300). `IMFCaptureEngine::Initialize` (0x1002E238) queues the initialisation, `DoInitialize` (0x10039088) runs it: [attributes check](#configuration-attributes), the source (`CCaptureSource::Initialize`, with the [access check](#device-access-check)), the PDC registrations, then the camera sound player. `StartPreview` / `StopPreview` / `StartRecord` / `StopRecord` / `TakePhoto` / `StartPhotoSequence` / `StopPhotoSequence` work the same way (`Do*` functions on the operation queue).

Fields of `CCaptureEngine` used below:

| Offset | Size | Comment |
|--------|------|---------|
| 0x08 | ? | `CCaptureEngineManager` (event and callback dispatch, camera sound queue) |
| 0x34 | 8 | `CCameraSoundPlayer`: `ICameraSoundPlayback *` (+0), flags (+4: bit 0 = play the sounds, bit 1 = mute background audio while recording) |
| 0x8C | 0x18 | Critical section |
| 0x104 | 4 | `IMFAttributes *` given to `Initialize` |
| 0x128 | 4 | PDC client, component 0x408, preview |
| 0x12C | 4 | PDC client, component 0x408, recording |
| 0x130 | 4 | PDC client, component 0x417, preview |
| 0x134 | 4 | PDC client, component 0x413, recording |
| 0x138 | 1 | Preview scenario active |
| 0x139 | 1 | Recording scenario active |
| 0x13C | 4 | `MF_CAPTURE_ENGINE_CUSTOM_CAMERA_SOUND` ≠ 0 (no sound played by the engine) |
| 0x22C | 1 | Mute background audio (1 by default, 0 when `MF_DO_NOT_MUTE_BACKGROUND_AUDIO` is set) |

### Startup

`start` (`_DllMainCRTStartup`, 0x10006318): `__security_init_cookie`, then `__DllMainCRTStartup` (CRT init, `_initterm`: ATL modules, `SVRSupportedSubtypes`) and `DllMain`.  
`DllMain` (0x100236B4), on `DLL_PROCESS_ATTACH`: `CComModule::Init`, `DisableThreadLibraryCalls`, `MfWmiInit` (registers the `Microsoft-Windows-MediaFoundation-Performance` provider), WPP init (`WppInitUm`, 9 control GUIDs), and registers the `Microsoft-Windows-MediaFoundation-MFCaptureEngine` provider ([ETW](#etw)). `DLL_PROCESS_DETACH` undoes it.

### Configuration attributes

`CCaptureEngine::CheckAttributes` (0x1000FCC4) checks the type of each known attribute of the `Initialize` attributes (`E_INVALIDARG` otherwise). It then applies the [registry](#registry) values `ForceDisableDX` and `RecordDurationLimitation`. The attributes that the phone client sets, and what the engine does with them:

| Attribute | GUID | Type | Use |
|-----------|------|------|-----|
| `MF_CAPTURE_ENGINE_CAMERA_REGIONAL_SOUND_LEVEL` | `{33D1CF25-758C-4A4A-930F-F34D74CCB3EE}` | UINT32 | Volume of the camera sounds, 0–100 (0 = no sound). Read in `DoInitialize`, passed to `CCameraSoundPlayer::Initialize` ([camera sound](#camera-sound)) |
| `MF_CAPTURE_ENGINE_CUSTOM_CAMERA_SOUND` | `{E7E745DF-6D9B-4CC3-A3B6-7DDED4F61272}` | UINT32 | Non-zero: the engine doesn't play its sounds (+0x13C) |
| `MF_DO_NOT_MUTE_BACKGROUND_AUDIO` | `{39558842-D689-489F-8AB5-E4E2A90F2C82}` | UINT32 | Present and non-zero: background audio isn't muted while recording (+0x22C) |
| `MF_CAPTURE_ENGINE_PRIVATE_SOUND_TYPE` | `{1402C349-F08B-4D90-A092-5F69159D9C69}` | UINT32 | Sound type carried by the queued camera sound work item (`InvokeCameraSoundPlayback`) |
| `MF_DEVICE_BROKER_THREADID` | `{41281299-9544-4E44-B354-44F863898E22}` | UINT32 | Thread of the app, for the [access check](#device-access-check) |
| `MF_CAPTURE_ENGINE_MEDIA_CATEGORY` | `{8E3F5BD5-DBBF-42F0-8542-D07A3971762A}` | UINT32 | 1 (communications, the WinRT `MediaCategory` value) → PDC component 0x408. 0 (other) → the source reader may leave low latency off ([low latency](#low-latency)) |
| `MF_CAPTURE_ENGINE_RECORD_DURATION_LIMITATION` | `{2309730F-9807-4DED-88AA-E3D727A5787F}` | UINT64 | Maximum recording duration; `MF_CAPTURE_ENGINE_RECORD_LIMITATION_EXCEEDED` `{1A97FF93-FFBF-48E3-8C52-7F699466381D}` is sent when it's reached |
| `MF_CAPTURE_ENGINE_D3D_MANAGER` | `{76E25E7B-D595-4283-962C-C594AFD78DDF}` | IUnknown | DXGI device manager; used by the source reader only if `IsOptimalDXDriver` (which tests `CheckDX9RotationSupport` on the `ID3D11VideoDevice`) says so |

Others checked: `MF_CAPTURE_ENGINE_RECORD_SINK_{VIDEO,AUDIO}_MAX_{UNPROCESSED,PROCESSED}_SAMPLES`, `MF_CAPTURE_ENGINE_USE_{AUDIO,VIDEO}_DEVICE_ONLY`, `MF_CAPTURE_ENGINE_DISABLE_HARDWARE_TRANSFORMS`, `MF_CAPTURE_ENGINE_DISABLE_DXVA`, `MF_CAPTURE_ENGINE_AUDIO_PROCESSING`, `MF_CAPTURE_ENGINE_MEDIASOURCE_CONFIG`, `MF_CAPTURE_ENGINE_{DECODER,ENCODER}_MFT_FIELDOFUSE_UNLOCK_Attribute`, `MF_CAPTURE_ENGINE_SHUTDOWN_EFFECTS`.

### Client (WINDOWS.MEDIA.DLL)

`WINDOWS.MEDIA.DLL` (7873 functions, named from its PDB, not documented here) is the `Windows.Media.Capture.MediaCapture` implementation. `MediaCaptureServer::_Initialize` (0x100AA4C0) builds the attributes, then creates the engine (`CoCreateInstance(CLSID_MFCaptureEngineClassFactory)` + `CreateInstance(CLSID_MFCaptureEngine, IID_IMFCaptureEngine)`) and calls `Initialize`:

| Attribute | Value set |
|-----------|-----------|
| `MF_CAPTURE_ENGINE_CAMERA_REGIONAL_SOUND_LEVEL` | When the app gave no `VideoSource` in `MediaCaptureInitializationSettings`: DWORD `CameraSoundLevel` of `HKLM\Software\Microsoft\Photos\OEM\RegionalSettings\Camera` (`RegGetValueW`, `RRF_RT_REG_DWORD`), clamped to 100. Not set when the value doesn't exist |
| `MF_CAPTURE_ENGINE_CUSTOM_CAMERA_SOUND` | 1 when the app gave its own `VideoSource` (then no regional level) |
| `MF_CAPTURE_ENGINE_D3D_MANAGER` | DXGI device manager (`_InitializeDXGIDeviceManager`); with `MF_SA_D3D11_SHARED_WITHOUT_MUTEX` = 1 and `MF_SA_D3D11_USE_MULTIPLANE_OVERLAY` = 1 when the resource manager ([MFPalWP.dll](./mfpalwp.md#callers-in-windowsmediadll)) is present and there's no custom video source |
| `MF_CAPTURE_ENGINE_RECORD_DURATION_LIMITATION` | 108 000 000 000 (100 ns units = 3 hours) |
| `MF_CAPTURE_ENGINE_USE_AUDIO_DEVICE_ONLY` / `_USE_VIDEO_DEVICE_ONLY` | 1 for `StreamingCaptureMode` `Audio` (1) / `Video` (2) |
| `MF_CAPTURE_ENGINE_MEDIA_CATEGORY` | `MediaCategory` of the settings (`IMediaCaptureInitializationSettings2`): 0 `Other`, 1 `Communications` |
| `MF_CAPTURE_ENGINE_AUDIO_PROCESSING` | `AudioProcessing` of the settings (not for video-only capture) |
| `MF_DEVICE_BROKER_THREADID` | Thread of the calling app, from `CoGetCallerTID` (`_StoreCallerThreadID`) |
| `MF_CAPTURE_ENGINE_SHUTDOWN_EFFECTS` | 1 |
| `MF_DO_NOT_MUTE_BACKGROUND_AUDIO` | 1 when the app's custom video (or audio) source exposes this attribute, non-zero, in its `IMFMediaSourceEx` source attributes (`SourceRequireDoNotMuteBackgroundAudio`) |

**WP8 driver quirk mode** (`MediaCaptureServer::_UpdateWP8DriverQuirkMode`, 0x1008E140): `CM_Get_Device_Interface_PropertyW(video device id, DEVPKEY_WP8Camera_Flags {B7B4D61C-5A64-4187-A52E-B1539F359099} pid 2)`. A 4-byte value with bit 0 set turns the mode on (`CaptureSharedState::SetWP8DriverQuirkMode`); a missing property leaves it off. The mode selects the [WP8 controls](#wp8-control-ids), the stream index table (`_FillStreamTypeToIndexMappingTable`), and the anti-flicker by country code. The setter of this property (camera driver INF ?) isn't known.

### Registry

All under `HKEY_LOCAL_MACHINE\Software\Microsoft\Windows Media Foundation\Platform\CaptureEngine`, read with `RegGetValueW`:

| Value | Type | Read by | Effect |
|-------|------|---------|--------|
| `ForceDisableDX` | DWORD | `CCaptureEngine::CheckAttributes` | Non-zero: deletes `MF_CAPTURE_ENGINE_D3D_MANAGER` from the attributes (no DirectX in the pipeline) |
| `RecordDurationLimitation` | QWORD | `CCaptureEngine::CheckAttributes` | If the app set `MF_CAPTURE_ENGINE_RECORD_DURATION_LIMITATION`, replaces its value |
| `ForceDisableSourceLowLatency` | DWORD | `CCaptureSource::ConfigureSourceReader` (0x100374E8) | Non-zero: no `MF_LOW_LATENCY` on the source reader when no media category is given |
| `UseLowLatencySettingsForCaptureToFile` | DWORD | `CCaptureInternalSinkWrapper::ConfigureEncoderAttributes` (0x1001CB58) | Non-zero: the video encoder of a recording keeps the low-latency settings instead of the file settings (H.264 profile check, `CODECAPI_AVEncCommonRateControlMode` `{1C0608E9-370C-4710-8A58-CB6181C42423}`, `{8D390AAC-DC5C-4200-B57F-814D04BABAB2}` = 2, `{B98E1B31-19FA-4D4F-9931-D6A5B8AAB93C}` = frame rate ?) |

Per camera, under the device interface key of the camera (`CM_Open_Device_Interface_KeyW(symbolic link, KEY_READ)`), subkey `ExtPropControls`: see [extended control overrides](#extended-control-overrides).

### Low latency

`CCaptureSource::ConfigureSourceReader` builds the source reader attributes (`MFCreateSourceReaderFromMediaSource`): D3D manager, `MF_SOURCE_READER_MEDIASOURCE_CONFIG`, field-of-use unlock, `MF_READWRITE_ENABLE_HARDWARE_TRANSFORMS` (unless disabled), `MF_SOURCE_READER_DISABLE_DXVA`, async callback, advanced video processing, MMCSS class `Capture` (video and audio) with priority 0, then `MFRegisterPlatformWithMMCSS(L"Audio", …, -2)`. `MF_LOW_LATENCY`:
- no `Initialize` attributes: 1;
- no media category: 1, unless `ForceDisableSourceLowLatency`;
- media category set: 1, then 0 if the category is 0, the flag at +0x88 of the source is 0 (?) and the quirk 0xB0001 isn't enabled (`QuirkIsEnabled(720897)`, the only quirk tested).

### Device controls

`IMFCaptureSource::GetCaptureDeviceExtendedPropertyControl(streamIndex, set, id, ppControl)` (`CCaptureSource`, 0x1002C154) picks a class by property set. All of them talk to the driver with `IKsControl::KsProperty` on the device source:

| Set | Class | Comment |
|-----|-------|---------|
| `{1CB79112-C0D2-4213-9CA6-CD4FDB927972}` `KSPROPERTYSETID_ExtendedCameraControl` | `CCaptureSourceDeviceControl` | Stream index mapped from the friendly index (`MapFriendlyNameToActualDeviceIndex`). Asynchronous commits through `BeginAsyncExtendedPropertyOperation` and the events `MF_CAPTURE_ENGINE_EVENT_EXTENDEDPROP_CONTROL` / `_COOKIE` |
| `{C6E13370-30AC-11D0-A18C-00A0C9118956}` `PROPSETID_VIDCAP_CAMERACONTROL`, ids 1000–1031 | `CCaptureSourceWP8DeviceControl` | Windows Phone 8 controls, range read from property 1024 |
| `PROPSETID_VIDCAP_CAMERACONTROL`, other ids; `{C6E13360-30AC-11D0-A18C-00A0C9118956}` `PROPSETID_VIDCAP_VIDEOPROCAMP` | `CCaptureSourceBasicDeviceControl` | Standard `KSPROPERTY_CAMERACONTROL_S` / `VIDEOPROCAMP_S` (value, flags, `BASICSUPPORT` range) |
| `{F1F3E261-DEE6-4537-BFF5-EE206DB54AAC}` (per-frame settings) | `CCaptureSourceFrameSettingDeviceControl` | Capability and setting payloads |

Any other set: `MF_E_UNSUPPORTED_SERVICE` (0xC00D36BA). [qccamavs8930.sys](../drivers/qccamavs8930.md#automation-table) only has the two `PROPSETID_VIDCAP_*` sets among these (camera control ids 1000–1028 and 1030), so on the Lumia 520 the extended and per-frame controls fail at the first `KsProperty`.

**Extended control** (`CCaptureSourceDeviceControl::InternalInitialize`, 0x10014EC8): `KsProperty(KSPROPERTY{set, id, KSPROPERTY_TYPE_GET}, NULL, 0)` gives the size (`ERROR_MORE_DATA`, at least 0x38 bytes), then a GET into a buffer with this layout:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 16 | `{A612CDFD-DC58-43CC-9C0B-816B6907504F}` (buffer tag ?) |
| 0x10 | 4 | Version = 1 (`KSCAMERA_EXTENDEDPROP_HEADER`) |
| 0x14 | 4 | Pin id (stream index) |
| 0x18 | 4 | Size |
| 0x1C | 4 | Result |
| 0x20 | 8 | Flags |
| 0x28 | 8 | Capability |
| 0x30 | … | Property payload |

After each GET, `CheckForExtendedPropOverride` (0x1000C53C) applies the [registry override](#extended-control-overrides) of the control: disabled → `E_NOTIMPL` (0x80004001) from `InternalGetKsProperty` (0x10011B18), `ERROR_NOT_FOUND` (0x80070490) at creation; replaced capability → the 8 bytes at +0x28 are overwritten.

**WP8 control** (`CCaptureSourceWP8DeviceControl`, object of 0x48 bytes on the basic control, `CreateInstance` 0x1002242C). `InternalRefreshRange` (0x1000DA64) sends a 40-byte property `{PROPSETID_VIDCAP_CAMERACONTROL, Id 1024, KSPROPERTY_TYPE_GET}` + the id of the control (+0x18) + 0 (+0x1C), and reads 32 bytes:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Type: 0 or 1 = bit mask, 4 = range, other → `E_UNEXPECTED` |
| 0x04 | 4 | Mask (types 0 and 1): min = lowest set bit, max = highest set bit, step 0. Step (type 4) |
| 0x0C | 4 | Min (type 4) |
| 0x10 | 4 | Max (type 4); min ≥ max → `ERROR_INVALID_DATA` (0x8007064A) |

`InternalRefreshSetting` (0x1000D9DC) reads the value with the basic control's GET and clears the flags.

#### WP8 control ids

The client decides between the two families of controls. When the camera's device interface has bit 0 set in `DEVPKEY_WP8Camera_Flags` ([client](#client-windowsmediadll)), each WinRT control of `VideoDeviceController` is a `*ControlServerWP8` object built on `GetCaptureSourceBasicDeviceControl(engine, PROPSETID_VIDCAP_CAMERACONTROL, id)` (→ `CCaptureSourceWP8DeviceControl`). Otherwise it's a `*ControlServer` object on `KSPROPERTYSETID_ExtendedCameraControl`. Ids used by `WINDOWS.MEDIA.DLL`; the meaning comes from the WinRT methods that use each control:

| Id | WinRT class (`Windows.Media.Devices`) | Used by |
|----|---------------------------------------|---------|
| 1000 | `FocusControlServerWP8`, `RegionsOfInterestControlServerWP8` | Focus / regions of interest (`SetRegionsWithLockAsync`, `ClearRegionsAsync`) |
| 1001 | `FocusControlServerWP8` | Focus preset / range (`get_Preset`, supported distances, ranges and presets, `UnlockAsync`) |
| 1002 | `FocusControlServerWP8` | Focus mode (`get_Supported`, supported modes) |
| 1003 | `FocusControlServerWP8` | Focus position (`get_Value`, `SetValueAsync`, `LockAsync`) |
| 1004 | `RegionsOfInterestControlServerWP8` | Region payload, 72 bytes, sent as a raw KS SET (`_ConstructPayloadFromExtendedROICollectionsAndSettings`) |
| 1005 | `FocusControlServerWP8` | Focus `Configure` / `FocusAsync` / `SetValueAsync` (trigger ?) |
| 1006 | `ZoomControlServerWP8` | Zoom |
| 1007, 1008 | `FlashControlServerWP8` | Flash (`get_Supported`, assistant light), flash power |
| 1009, 1010 | `TorchControlServerWP8` | Torch, torch power |
| 1011 | `FocusControlServerWP8` | `get_SupportedFocusModes` |
| 1012, 1013, 1014 | `WhiteBalanceControlServerWP8` | White balance mode, preset, value |
| 1018, 1019 | `ExposureControlServerWP8` | Auto exposure, exposure value |
| 1020 | `ExposureCompensationControlServerWP8` | Exposure compensation |
| 1021, 1022 | `IsoSpeedControlServerWP8` | ISO preset, ISO supported / mode |
| 1023 | `SceneModeControlServerWP8` | Scene mode |
| 1024 | — | Range of another control, read by this DLL ([above](#device-controls)) |
| 1025 | `CaptureSharedState::_PrepareWP8Storyboard` | Storyboard, raw KS SET |
| 1030 | `MediaCaptureServer::_UpdateAntiFlickerSettings` | Mobile country code for anti-flicker, in WP8 quirk mode ([MFPalWP.dll](./mfpalwp.md#callers-in-windowsmediadll)) |

All of them are in the automation table of [qccamavs8930.sys](../drivers/qccamavs8930.md#automation-table) (1000–1028, 1030).

### Extended control overrides

`CCaptureSource::PopulateExtendedPropControlOverrideList` (0x1002B088), once per source:
1. Symbolic link of the camera (`MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_SYMBOLIC_LINK`), `CM_Open_Device_Interface_KeyW(link, KEY_READ, RegDisposition_OpenExisting)`.
2. Nothing to do if the subkey `ExtPropControls` doesn't exist.
3. For each extended control id 0–26: key `ExtPropControls\<id>`. DWORD `Disable` ≠ 0 → the control is disabled. Otherwise, for each of the values `Photo`, `Preview`, `Record`, `Filter` (`g_ExtPropOverrideNames`, 0x1003D100): an 8-byte `REG_BINARY` (any other size → `ERROR_INVALID_DATA`) is the capability to report for the stream used for photo (0xFFFFFFF8), preview (0xFFFFFFFA), record (0xFFFFFFF9), or the filter (0xFFFFFFFF, no stream).
4. One 0x48-byte entry per control id with an override (array at +0x08 of the source): disabled flag (+0x00), then 4 × 16 bytes from +0x08: set flag, stream index (+0x0C), capability (+0x10).

### Camera sound

`CCameraSoundPlayer::Initialize(flags, level)` (0x1002A28C), called by `DoInitialize`:
- flags bit 0 = video source and no `MF_CAPTURE_ENGINE_CUSTOM_CAMERA_SOUND`, bit 1 = mute background audio (+0x22C). `level` = `MF_CAPTURE_ENGINE_CAMERA_REGIONAL_SOUND_LEVEL`; level 0 clears bit 0. A missing attribute counts as 0 (`MFGetAttributeUINT32` returns 0), so on the phone the sounds play only if the OEM registry value `CameraSoundLevel` exists ([client](#client-windowsmediadll)) (trace strings "Regionl Camera Sound Required" / "Not Required").
- If `IsAudioPlayerSupported()` is non-zero, the player is `CCameraSoundAudioPlayerWrapper` (`Initialize` 0x1001C004). Level clamped to 100, gain = 20 × log10(level / 100) dB (float at +0x0C). It loads `audioses.dll` and `CoreMmRes.dll` (`LOAD_LIBRARY_SEARCH_SYSTEM32`) and gets `AudioPlayerFacade` from `audioses!DllGetClassObject` (`CreateAudioPlayerFacade` 0x10008A80, facade interface `{21D4FBA9-6C76-4ACA-B694-48C7C67F61DB}`). It then creates the player (facade method 3, `{7B392C5E-3497-4133-8B75-0C58AF205167}`, options from `GetDefaultAudioPlayerOptions`: 44 bytes, GUID `{A9EF3FD9-4240-455E-A4D5-F2B3301887B2}` at +0x08, +0x04 = 3, then 0x10000, 40, 500, 10000, 250).
- Otherwise `CreateCameraSoundPlaybackWrapper(level, &player)` from `ext-ms-win-audiocore-pal-l1-1-0`.

Both implement `ICameraSoundPlayback` `{6AE0038B-C4D8-4FBF-9931-B0EC2DB17423}`: method 3 `Play(type, flag)`, method 4 `MuteBackgroundAudio(BOOL)`. The wrapper's `Play` (0x1000F248) loads the sound from `CoreMmRes.dll` (facade method 5, `{AA66E9D1-A5A6-435D-8677-155E8A01EE9F}`, resource id) and plays it with the gain (player method 5, 16-byte parameters).

| Type | Resource id in CoreMmRes.dll | Played by | Mode |
|------|------------------------------|-----------|------|
| 0 | 0xC2F | `DoTakePhoto`, `DoStartPhotoSequence` | Queued work item (`QueueCameraSoundPlayback(…, 1)`) |
| 1 | 0xC30 | `DoStartRecord` | Synchronous, then `MuteBackgroundAudio(TRUE)` if bit 1 |
| 2 | 0xC31 | `DoStopRecord` | `MuteBackgroundAudio(FALSE)`, then queued |

`QueueCameraSoundPlayback` (`CCaptureEngineManager`) does nothing when `MF_CAPTURE_ENGINE_CUSTOM_CAMERA_SOUND` is set or when flag bit 0 is clear. Background audio is also unmuted by `Shutdown` and the destructor.

### Photo encoder

`CCapturePhotoSink::CCaptureImageProcessor::ConfigureImageEncoder` (0x100132B4): for a JPEG container (`GUID_ContainerFormatJpeg`) with an NV12 input, it first tries `CoCreateInstance(CLSID_WICJpegQualcommPhoneEncoder {68ED5C62-F534-4979-B2B3-686A12B2B34C}, IWICBitmapEncoder)`. Otherwise it uses the WIC imaging factory's encoder. With the Qualcomm encoder, the `MFSampleExtension_CaptureMetadata` attributes of the sample are passed to the frame as the encoder option `SampleMetadata` (`VT_UNKNOWN`). The DLL of this WIC encoder isn't known; the camera's MFT JPEG encoder is [QCJpegEncoderMFT.dll](./qcjpegencodermft.md) (different CLSID).

### Photo buffer budget

`CCaptureSource::GetDevicePipelineNumbers` (0x10025948), called by `AdjustSourceAllocatorRequirements`, sizes the extra buffers of the photo stream from `GlobalMemoryStatusEx().ullTotalPhys`. It picks the entry of the table at 0x10003A00 whose memory size is closest:

| Memory size | Budget for pipelined photos | Second value |
|-------------|-----------------------------|--------------|
| 512 MB | 0 | 10 MB |
| 1 GB | 100 MB | 50 MB |
| 2 GB | 300 MB | 100 MB |

For an independent photo stream (stream category 2) when +0x198 of the source is 1 (?), the number of buffers is budget / frame size (`MFCalculateImageSize`, or width × height × 3 / 5 for JPEG), at most 20; it's 0 otherwise, so always 0 on the 512 MB Lumia 520. The numbers go to the device proxy through `TrySendAllocatorRequirementsToDevProxy` (interface `{59CD78A0-0DBF-4815-9A9E-3430DCE51FEB}` of the source, method 5).

### Device access check

In `CCaptureSource::Initialize`: thread id from `MF_DEVICE_BROKER_THREADID`, `CoCreateInstance(CLSID_DeviceAccessPolicyCheck)`, then `CheckAccess(threadId, policy, category)` (0x1000EAA0, method 6 of the interface with the GUID as a string) for `{E5323777-F976-4F5B-9B55-B94699C46E44}` (`KSCATEGORY_VIDEO_CAMERA`) if there's a video device, and `{2EEF81BE-33FA-4800-9670-1CD474972C3F}` (`DEVINTERFACE_AUDIO_CAPTURE`) if there's an audio device. `ERROR_NOT_APPCONTAINER` (0x8007109A) counts as allowed.

### PDC scenarios

The engine has the scenario client of the power dependency coordinator, the same code as [DWMCORE.DLL](./dwmcore.md#pdc-scenarios) and [VideoSink.dll](./videosink.md#pdc-scenario): `PdcScenarioClientRegister` (0x1003C080, in `PAGE`), `PdcScenarioClientRequest` (0x1003C000), `PdcScenarioClientUnregister` (0x1003C0E8), `PdcPortOpen` (0x100145C8: `PdcP` / `PDCt`, `ZwAlpcConnectPort(L"\\PdcPort", flags 0x20000, max message 0x30, connect flags 0xA0000)`, client type 5, completion `PdcpAlpcCalback`). Messages of type 8 (byte +0x20 = 1 / 0) on the first activation / last release.

| Component id | Registered in `DoInitialize` | Activated / released |
|--------------|------------------------------|----------------------|
| 0x408 (two clients) | When `MF_CAPTURE_ENGINE_MEDIA_CATEGORY` = 1 | One with the preview, one with the recording |
| 0x417 | Video source (not audio-only) | `PDCCameraPreview` (0x10014594): `DoStartPreview` / `DoStopPreview` |
| 0x413 | Video source (not audio-only) | `PDCVideoRecording` (0x10014560): `DoStartRecord` / `DoStopRecord`, `OnRecordSinkFinalize` |

`Shutdown` unregisters the four clients. What the kernel does with these components isn't analysed.

### ETW

Provider `Microsoft-Windows-MediaFoundation-MFCaptureEngine` `{B8197C10-845F-40CA-82AB-9341E98CFC2B}`, registered in `DllMain` (`McGenEventRegister`). Writes are guarded by bit 0x1 of `Microsoft_Windows_MediaFoundation_MFCaptureEngineEnableBits`. All events are version 0, channel 100, level 4 (5 for 259 / 260), keyword 0x8000000000000000 (0x8001000000000000 for 206, 210, 212, 213, 219, 253, 270, 271). Opcode 1 = begin, 2 = end, 0 = single.

| Events | Task | Name |
|--------|------|------|
| 200 / 201, 202 / 203 | 100, 101 | `Begin/End_Initialization`, `Begin/End_Shutdown` |
| 204 / 205 | 102 | `Begin/End_TakePhoto` |
| 206 / 207, 208 / 209 | 103, 109 | `Begin/End_StartPreview`, `Begin/End_StopPreview` |
| 210 / 211, 212 / 213 | 104, 110 | `Begin/End_StartRecord`, `Begin/End_StopRecord` |
| 214 / 215 | 105 | `Source_ReadSample_Begin/End` |
| 216, 217, 218 | 106 | `Streaming_Photo/Record/Preview_Sample` |
| 219 / 220, 239, 270, 271 | 107 | `Sink_WriteSample_Begin/End`, `Sink_Sample_Dropped`, `RecordSink/PreviewSink_WriteFirstSample` |
| 221 / 222, 223 / 224, 227 / 228, 238 | 111, 112, 114 | `Photo_Encode`, `Photo_FormatConvert`, `Photo_XVP` begin / end, `Photo_XVP_Creation` |
| 229 / 230, 251 / 252 | 115, 122 | `PhotoSink_Configure`, `PhotoSink_Prepare` begin / end |
| 231 | 100 | `SourceAndSinks` |
| 232–235 | 108 | `SampleProbe_OnProcessSample`, `_OnProcessIMFSample`, `_CallbackBegin`, `_CallbackEnd` |
| 236, 237 | 104, 103 | `RecordSinkWriter`, `PreviewSinkWriter` |
| 240 / 241, 244 / 245, 246 | 116, 118, 119 | `FlushRequiredStreams`, `FlushAllStreams` begin / end, `OnFlushForAllStreams` |
| 242 / 243 | 117 | `SetCurrentDeviceMediaType_Begin/End` |
| 247 / 248, 249 / 250 | 120, 121 | `SetExtendedPropertyAsync`, `KSAsynPropertySet` begin / end |
| 253 / 254, 255 / 256 | 123, 124 | `Start/StopCapturePhotoSequence_Begin/End` |
| 257, 258 | 125, 126 | `CaptureSinkAddStream`, `OnEvent_Notification` |
| 259 / 260, 261 / 262, 263 | 127, 128, 129 | `GetAvailableDeviceMediaType_Start/End`, `BridgeSourceSink_Start/End`, `Source_Stream_Info` |
| 264 / 265, 266 / 267, 268 / 269 | 130, 131, 132 | `Camera_Sound_Init`, `Camera_Sound_Queue_Playback`, `Camera_Sound_Playback` start / stop |

`MfWmiInit` also registers `Microsoft-Windows-MediaFoundation-Performance` `{F404B94E-27E0-4384-BFE8-1D8D390B0AA3}`.  
WPP (`RegisterTraceGuidsW`, `TraceMessage`): the 9 control GUIDs of Media Foundation, `{0000000n-0DC9-401D-B9B8-05E4ECA4977E}` with n = 0 `MF_PLATFORM`, 1 `MF_PIPELINE`, 2 `MF_CORE_SINKS`, 3 `MF_CORE_SOURCES`, 4 `MF_NETWORK`, 5 `MF_CORE_MFTS`, 6 `MF_PLAY`, 7 `MF_CAPTURE_ENGINE`, 8 `MF_VIDEO_PROCESSOR`.
