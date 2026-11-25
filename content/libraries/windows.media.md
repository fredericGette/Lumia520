# Windows.Media.dll

Reverse-engineering notes on `C:\Windows\System32\Windows.Media.dll` from Windows Phone 8.1 (Lumia, ARM Thumb-2).

| | |
|---|---|
| File version | 6.3.9651.0 (winbluephone_gdr1.150113-1731) |
| Description | Windows Media Runtime DLL |
| Size | 1 130 496 bytes |
| Image base | 0x10000000 |
| Functions | 7 873 (full public symbols from `Windows.Media.pdb`) |
| Built with | WRL (Windows Runtime C++ Template Library), WPP tracing |

The DLL is the in-process **WinRT server** for most of the `Windows.Media.*` API surface that a phone app uses: camera capture, camera device controls, transcoding, `MediaStreamSource`, encoding profiles, PlayReady protection manager and media extension registration. It is a thin layer over Media Foundation (`MFPlat`, `MFCORE`, `MFTranscode`, the MF Capture Engine) plus a phone-only platform abstraction layer, `ext-ms-win-mf-pal`.

The classes listed below are the ones this DLL implements. Other `Windows.Media` namespaces live in other DLLs. For example, `Windows.Media.Playback`, `SystemMediaTransportControls` and `Windows.Media.SpeechSynthesis` are not here.

## Exports

| Export | Role |
|---|---|
| `DllGetActivationFactory` | WinRT entry point. It walks the WRL object map (`__pobjectentryfirst`..`__pobjectentrylast`) |
| `DllGetClassObject` | Classic COM entry point. It goes to `NdrDllGetClassObject` and serves the MIDL proxy/stubs (`.orpc` section) for the internal interfaces |
| `DllCanUnloadNow` | WRL module plus NDR unload check |
| `_DllMainCRTStartup` | CRT entry point |

## Activatable classes

The WRL object map at `0x100e6f44..0x100e6fa4` holds 22 entries. Each `__minATLObjMap_*` entry points to a `CreatorMap` = {factory creator, `GetRuntimeClassName`, `GetTrustLevel`, factory cache}.

| Runtime class | Implementation class | Factory |
|---|---|---|
| `Windows.Media.Capture.MediaCapture` | `Windows::Media::Capture::MediaCaptureServer` | SimpleSealedActivationFactory (default ctor) |
| `Windows.Media.Capture.MediaCaptureInitializationSettings` | `MediaCaptureInitializationSettingsServer` | SimpleSealedActivationFactory |
| `Windows.Media.Devices.VideoDeviceController` | `Windows::Media::Devices::VideoDeviceControllerServer` | `VideoDeviceControllerFactory` (internal `IVideoDeviceControllerFactory`) |
| `Windows.Media.Devices.FocusSettings` | `FocusSettingsServer` | SimpleSealedActivationFactory |
| `Windows.Media.Devices.RegionOfInterest` | `RegionOfInterestServer` | SimpleSealedActivationFactory |
| `Windows.Media.Devices.Core.FrameController` | `Windows::Media::Devices::Core::FrameSettingControlServer` | SimpleSealedActivationFactory |
| `Windows.Media.Transcoding.MediaTranscoder` | `Windows::Media::Transcoding::CTranscoder` | `CTranscoderFactory` |
| `Windows.Media.Core.MediaStreamSource` | `CWinRTMediaStreamSource` | `CMediaStreamSourceFactory` |
| `Windows.Media.Core.MediaStreamSample` | `CMediaStreamSample` | `CMediaStreamSampleFactory` (statics) |
| `Windows.Media.Core.VideoStreamDescriptor` | `CWinRTVideoStreamDescriptor` | `CVideoStreamDescriptorFactory` |
| `Windows.Media.Core.AudioStreamDescriptor` | `CWinRTAudioStreamDescriptor` | `CAudioStreamDescriptorFactory` |
| `Windows.Media.Protection.MediaProtectionManager` | `Windows::Media::Protection::MediaProtectionManagerServer` | SimpleSealedActivationFactory |
| `Windows.Media.MediaExtensionManager` | `Windows::Media::MediaPluginRegistrar` | `MediaPluginRegistrarFactory` |
| `Windows.Media.VideoEffects` | `Windows::Media::VideoEffects` | statics only |
| `Windows.Media.MediaProperties.MediaEncodingProfile` | `CEncodingProfile` | `CEncodingProfileFactory` |
| `Windows.Media.MediaProperties.ContainerEncodingProperties` | `CContainerProperties` | `CContainerPropertiesFactory` |
| `Windows.Media.MediaProperties.VideoEncodingProperties` | `CVideoProperties` | `CVideoPropertiesFactory` |
| `Windows.Media.MediaProperties.AudioEncodingProperties` | `CAudioProperties` | `CAudioPropertiesFactory` |
| `Windows.Media.MediaProperties.ImageEncodingProperties` | `CImageProperties` | `CImagePropertiesFactory` |
| `Windows.Media.MediaProperties.MediaPropertySet` | `CMediaPropertySet` | SimpleSealedActivationFactory |
| `Windows.Media.MediaProperties.MediaEncodingSubtypes` | `CMediaEncodingSubtypes` | statics only |
| `Windows.Media.MediaProperties.H264ProfileIds` | `CH264ProfileIdsFactory` | statics only |
| `Windows.Media.MediaProperties.Mpeg2ProfileIds` | `CMpeg2ProfileIdsFactory` | statics only |

The DLL also implements the non-activatable classes that these return. They have runtime class names but no factory:

* Capture: `LowLagPhotoCapture`, `LowLagPhotoSequenceCapture`, `LowLagMediaRecording`, `CapturedPhoto`, `CapturedFrame`, `CapturedFrameControlValues`, `MediaCaptureSettings`, `Core.VariablePhotoSequenceCapture`, event args (`MediaCaptureFailed`, `PhotoCaptured`, `PhotoConfirmationCaptured`, `MediaCaptureFocusChanged`, `VariablePhotoCaptured`)
* Devices: `AudioDeviceController`, `MediaDeviceControl`, `MediaDeviceControlCapabilities`, `FocusControl`, `ExposureControl`, `ExposureCompensationControl`, `IsoSpeedControl`, `WhiteBalanceControl`, `ZoomControl`, `FlashControl`, `TorchControl`, `SceneModeControl`, `RegionsOfInterestControl`, `PhotoConfirmationControl`, `LowLagPhotoControl`, `LowLagPhotoSequenceControl`, `Core.VariablePhotoSequenceController`, `Core.Frame*Control` / `Core.Frame*Capabilities`
* Core: `MediaStreamSource*EventArgs`, `*Request`, `*Deferral`, `MediaStreamSampleProtectionProperties`
* Transcoding: `PrepareTranscodeResult`
* Protection: `ServiceRequestedEventArgs`, `ComponentLoadFailedEventArgs`, `MediaProtectionServiceCompletion`
* `MediaRatio`

`MediaProtectionManager.Properties` is a `Windows.Foundation.Collections.PropertySet`, made with `RoActivateInstance`.

## Architecture by area

### Camera capture (`MediaCaptureServer`, `CaptureSharedState`)

* `MediaCapture` wraps the **MF Capture Engine**. `_Initialize(IMFCaptureEngine*)` creates it with `CLSID_MFCaptureEngineClassFactory` / `CLSID_MFCaptureEngine`. `GetMFCaptureEnginePtr` exposes it internally.
* Devices are opened by `Windows::Media::Capture::GetDeviceActivate` → `MFEnumDeviceSources`, or by `CreateVideoDeviceActivate` / `CreateAudioDeviceActivate`, which read device-interface properties through `CM_Get_Device_Interface_PropertyW`.
* A D3D11 device is created (`_CreateD3DDevice` → `D3D11CreateDevice`) and handed to the engine through a DXGI device manager (`MF_CAPTURE_ENGINE_D3D_MANAGER`). When the MF PAL is present, the code also sets `MF_SA_D3D11_SHARED_WITHOUT_MUTEX` and `MF_SA_D3D11_USE_MULTIPLANE_OVERLAY`.
* Each async method is a WRL async-operation class: `InitializeOperationServer`, `StartPreviewOperationServer`, `StopPreviewOperationServer`, `StartRecordOperationServer`, `StopRecordOperationServer`, `CapturePhotoOperationServer`, `AddEffectOperationServer`, `ClearEffectsOperationServer`, `SetStreamSettingsOperationServer`, plus the `LowLag*Prepare/Start/Stop/Finish` and `VariablePhotoSequence*` operations.
* `CaptureSharedState` (78 methods) is the state machine shared by the capture object and its controls: preview, record and photo states, sink preparation (`PreparePreviewSink`, `PrepareRecordSink`, `PreparePhotoSink`), encoder profile adjustment, photo-sequence and thumbnail capabilities, and the KS control used to talk to the driver (`GetKsControl`, `GetCaptureDeviceExtendedPropertyControl`).
* Preview can go to XAML (`CCaptureXAMLSource`), to a WWA/HTML host (`CCaptureWWASource`), or to a custom sink (`StartPreviewToCustomSinkAsync`). `CCapturePreviewSource*` exposes the preview as an MF source.
* Phone-specific inputs:
  * **Shutter sound level**: `HKLM\Software\Microsoft\Photos\OEM\RegionalSettings\Camera\CameraSoundLevel` (DWORD, capped at 100) → `MF_CAPTURE_ENGINE_CAMERA_REGIONAL_SOUND_LEVEL`. If the app supplied its own sound setting, `MF_CAPTURE_ENGINE_CUSTOM_CAMERA_SOUND` is set instead.
  * **Anti-flicker**: `_UpdateAntiFlickerSettings` reads the SIM MCC with `MFMCPalGetMobileCountryCode`. `_MapMobileCountryCodeToPowerLineFrequency` does a `bsearch` over a table of 50 MCCs that get **60 Hz**; every other MCC gets **50 Hz**. The pair MCC 362 / MNC 51 is also forced to 60 Hz.
    60 Hz MCCs: 302, 310–316, 330, 334, 344, 346, 348, 350, 354, 356, 363, 364, 365, 368, 370, 372, 374, 376, 420, 450, 466, 515, 534, 535, 544, 547, 550, 551, 552, 618, 702, 704, 706, 708, 710, 712, 714, 716, 724, 732, 734, 738, 740, 746.
  * **Encoder arbitration**: `ResourceManager` uses `MFMCPalAcquireResources`, `MFMCPalRegisterForResourceNotifications` and `MFMCPalAcquireVideoEncoderResource` (full or partial encoder) so that only one app holds the hardware video encoder. `ResourceManager::IsPresent()` tests for the `ext-ms-win-mf-pal` API set.

### WP8 driver quirk mode

`MediaCaptureServer::_UpdateWP8DriverQuirkMode` reads the camera device-interface property

```
DEVPKEY_WP8Camera_Flags = {b7b4d61c-5a64-4187-a52e-b1539f359099}, pid 2   (DWORD)
```

If bit 0 is set, `CaptureSharedState::SetWP8DriverQuirkMode(true)` is called. From then on, `VideoDeviceControllerServer::get_*Control` creates the **`*ServerWP8`** variant of each control instead of the standard one:

| Standard | WP8 quirk variant |
|---|---|
| `FocusControlServer` | `FocusControlServerWP8` (+ `WP8FocusTriggerAsyncAction`) |
| `ExposureControlServer` | `ExposureControlServerWP8` |
| `ExposureCompensationControlServer` | `ExposureCompensationControlServerWP8` |
| `IsoSpeedControlServer` | `IsoSpeedControlServerWP8` |
| `WhiteBalanceControlServer` | `WhiteBalanceControlServerWP8` (`WBPresetToWP8DDIValue` / `WP8DDIValueToWBPreset`) |
| `ZoomControlServer` | `ZoomControlServerWP8` |
| `FlashControlServer` | `FlashControlServerWP8` |
| `TorchControlServer` | `TorchControlServerWP8` |
| `SceneModeControlServer` | `SceneModeControlServerWP8` |
| `RegionsOfInterestControlServer` | `RegionsOfInterestControlServerWP8` (`RegionsOfInterestSetOperationWP8`) |

These variants drive camera drivers that were written for the Windows Phone 8.0 camera DDI. That is how 8.0-era Lumia camera drivers keep working under the 8.1 `Windows.Media.Devices` API.

### Device controls (`VideoDeviceControllerServer`)

* Legacy `IMediaDeviceControl` properties (`Brightness`, `Contrast`, `Hue`, `WhiteBalance`, `BacklightCompensation`, `Pan`, `Tilt`, `Roll`, `Zoom`, `Focus`, `Exposure`) go through `MediaDeviceControlServer` to `IAMVideoProcAmp`/`IAMCameraControl`-style KS properties (`_GetKsControl`).
* Advanced 8.1 controls use `IMFCaptureEngine` events and the extended-property KS control. Their async setters are template classes named `...SetValueAsyncCausalityDescr`, `...SetPresetAsyncCausalityDescr` and so on.
* `GetDeviceProperty` / `SetDeviceProperty` give direct access to camera properties by GUID string (`_PropertyKeyFromString`). `GetDeviceExtension` returns the device MFT0 (`_GetDeviceMFT0`). This is the documented hook for OEM camera extensions.
* `TryGetPowerlineFrequency` / `TrySetPowerlineFrequency` expose the anti-flicker setting described above.

### Transcoding (`CTranscoder`)

* `CTranscodeOperation` and `CPrepareTranscodeOperation` call `MFCreateTranscodeEngine` and `MFCreateTranscodeProfile` from `MFTranscode.dll`.
* `put_HardwareAccelerationEnabled` asks `MFTEPalSupportSoftwareTranscoding` whether a software fallback is allowed. `VideoEffects.VideoStabilization` checks the same thing before it returns `Windows.Media.VideoStabilizationEffect`.
* `MFADKPerfGetRecommendedEncodeResolution` picks the encode resolution from
  `HKLM\Software\Microsoft\Windows Media Foundation\CodecSelection\Transcode\Performance\` values. Value names look like `H264_1080_DXVA_EHW_AC` and `VC1_720_DXVA_ESW_AC`: codec × SD/720/1080 × hardware (EHW) or software (ESW) encoder. `HKLM\...\Windows Media Foundation\HardwareMFT\EnableEncoders = 0` turns the hardware-encoder rows off.

### MediaStreamSource (`CWinRTMediaStreamSource`, `CMFMediaStreamSource`)

* The WinRT object (`CWinRTMediaStreamSource`) turns app events (`Starting`, `SampleRequested`, `SwitchStreamsRequested`, `Closed`, `Paused`) into an `IMFMediaSource` implementation (`CMFMediaStreamSource`, 95 methods, with `CMFMediaStream` streams and its own event and operation queues).
* The source is registered as a local scheme or byte-stream handler (`MFRegisterLocalSchemeHandler` / `MFRegisterLocalByteStreamHandler`), so the media pipeline can resolve it.
* `CMFMediaStreamSource::_CreateRemoteITAs` calls `IsImmersiveProcess`. This is the path used when the source has to cross into the out-of-process media pipeline.
* `CMFMediaStream` reads `Network\EnableNetworkSampleBasedBursting` and `Network\BurstTimeMs` through `MFGetConfigurationDWORD`.
* Metadata and thumbnails: `CMssAudioMetadataHandler` / `CMssVideoMetadataHandler` map `MusicProperties` / `VideoProperties` to WM/ASF attribute names (`WM/AlbumArtist`, `WM/Genre`, …). `CMFVideoThumbnail` produces `image/jpeg` thumbnails.

### Media extensions (`MediaPluginRegistrar`)

`MediaExtensionManager.Register{Audio,Video}{Decoder,Encoder}`, `RegisterByteStreamHandler` and `RegisterSchemeHandler` (with or without settings) map onto `MFTRegisterLocal`, `MFRegisterLocalByteStreamHandler` and `MFRegisterLocalSchemeHandler`. Each takes an `MFCreateMediaExtensionActivate` activator built from the WinRT class id. The registration is process-local only.

### Protection (`MediaProtectionManagerServer`)

This class implements `IMFContentProtectionManager` (`BeginEnableContent` / `EndEnableContent`) for the playback pipeline and raises `ServiceRequested`, `ComponentLoadFailed` and `RebootNeeded` to the app. The handlers are kept in the GIT (`GitPtr`), so they can be called back from MF work-queue threads.

## Dependencies

* **Media Foundation**: `MFPlat` (47 imports), `MFCORE` (`MFEnumDeviceSources`, `MFGetService`), `MFTranscode` (3)
* **Phone-only**: `ext-ms-win-mf-pal-l1-1-0` (8 imports: `MFMCPal*` resource and MCC functions, `MFTEPalSupportSoftwareTranscoding`). It is delay-loaded, and its presence is checked with `ApiSetQueryApiSetPresence`.
* **Graphics**: `d3d11` (`D3D11CreateDevice`)
* **Device config**: `CFGMGR32` (`CM_Get_Device_Interface_PropertyW`)
* **WinRT/COM**: `combase`, `api-ms-win-core-winrt-*`, `RPCRT4` (NDR proxy/stubs), `PROPSYS`, `OLEAUT32`
* **Tracing**: WPP (`TraceMessage`, control GUID `WPP_ThisDir_CTLGUID_CTRLGUID_MF_PLATFORM`) and ETW `EventWrite`

## Useful addresses (6.3.9651.0)

| Symbol | Address |
|---|---|
| `DllGetActivationFactory` | `0x1003480c` |
| `DllGetClassObject` | `0x10036184` |
| WRL object map (`__pobjectentryfirst`) | `0x100e6f40` |
| `MediaCaptureServer::_MapMobileCountryCodeToPowerLineFrequency` | `0x1005066c` |
| `DEVPKEY_WP8Camera_Flags` | `0x1002a60c` |

Look up any other function by its symbol name in IDA. The PDB symbols resolve all 7 873 functions.
