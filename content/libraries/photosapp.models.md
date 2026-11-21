## PhotosApp.Models.dll

The model layer of the built-in Photos / Camera application: a C++/CX Windows Runtime component (`PhotosApp.Models.*` classes) used by the XAML front end of the app.  
`PhotosApp.Models.dll` (6 770 688 bytes, about 24 900 functions, ARM Thumb-2, no PDB names) exports only the WinRT entry points (`DllGetActivationFactory`, `DllCanUnloadNow`). It contains:
- the **camera**: two camera models behind one `ICamera`-like interface, one on `Windows.Phone.Media.Capture` (`PhotoCaptureDevice` / `AudioVideoCaptureDevice`, "WPMC", class `PhotosApp.Models.Camera`) and one on `Windows.Media.Capture.MediaCapture` ("WMC", class `PhotosApp.Models.WMCCamera`), chosen in [CameraFactory::Create](#camera-model-selection-camerafactorycreate-0x1020ae60), with a task queue (`CameraTaskEngine`: Load / Prepare / StartStillCapture / StartVideoCapture / Focus … tasks), burst ("Blink") capture, OEM camera settings read from [CameraSettings.xml](#oem-camera-settings-camerasettingsxml) and OEM custom KS properties ([WMCCamera::SetCustomProperty](#oem-custom-properties-wmccamerasetcustomproperty-0x103ad3c8));
- the **photo library**: albums, events and items on `PhoneInternal.Experiences.Media.MediaStoreManager` (local pictures and videos), online albums (`PhoneInternal.Experiences.OnlinePhotos.OnlinePictureAlbumManager`, `SkyDrivePhotoManager`), `photos://` [URIs](#photo-uris), files shared through the data sharing service (`dss://`, [dsclient](#dependencies)), auto-upload settings;
- **image processing**: WIC decoding / encoding (thumbnails, EXIF/GPS metadata, NV12 → JPEG), Direct2D / Direct3D 11 effects for the photo editor (`ImagePresetEditor`: LUT, highlights/shadows, vignette effects described by inline XML), Media Foundation source resolver for videos;
- the **Start tile** (`StartTileManager`, pinned album backgrounds), app discovery of camera "lenses" and rich media editors (`AppDiscoveryHelper`), orientation tracking, SQM, ETW traces.

All the system-specific calls go through `Photos.ModelsNonKit.dll` (64 imports: registry, files, WNF, SQM, sounds, shutter button, media DB lock, post-processing queue; not analysed here). Others: `ShellChromeAPI.dll` ([ShellChromeAPI.dll](./shellchromeapi.md)) for the lock state and idle timer, `dsclient.dll` for shared files, `Orientation.dll` for the orientation sensor. The `Windows.Media.Capture` camera model ends in [MFCaptureEngine.dll](./mfcaptureengine.md) and the camera driver [qccamavs8930.sys](../drivers/qccamavs8930.md).

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| Photos.ModelsNonKit | 64 functions in namespace `PhotosApp::ModelsNonKit`: `WnfSubscribe(WnfId, ULONG, ULONG, void(*)(void*), void*, WnfSubscription**)`, `WnfUnsubscribe`, `WnfQueryUInt32`; `NonKit_RegCreateOrOpenKey(RegistryHive, PCWSTR, RegistryAccess, HKEY*)`, `NonKit_RegGet/SetDwordValue`, `NonKit_RegGet/SetQwordValue`, `NonKit_RegGet/SetStringValue`, `NonKit_RegValueExists`, `NonKit_RegDeleteValue`, `NonKit_RegDeleteTree`, `NonKit_RegEnumKey`, `NonKit_RegEnumValue`, `NonKit_RegQuerySubkeyAndValueCount`, `NonKit_RegCloseKey`; `NonKit_WpSqmGetSession`, `NonKit_WinSqmIncrementDWORD`, `NonKit_WinSqmSetDWORD`, `NonKit_WinSqmAddToAverageDWORD`, `NonKit_WinSqmSetIfMaxDWORD`, `NonKit_WinSqmAddToStreamEx`; `NonKit_GetKnownFolderPath(FolderType, PWSTR, ULONG)`, `NonKit_GetPhotosAppCachePath`, `NonKit_CreateFile`, `NonKit_CopyFile`, `NonKit_MoveFile`, `NonKit_FileExists`, `NonKit_CreateStreamOnFile`, `NonKit_WriteStreamToFile` (2 overloads), `NonKit_GetFileTimeByPath`, `NonKit_FileTimeToLocalFileTime`, `NonKit_Path*` (`CchCombine`, `CchRemoveExtension`, `CchRemoveFileSpec`, `FindExtension`, `FindFileName`, `IsDirectory`, `IsFileSpec`), `NonKit_FileExtentionFromMTPFormatCode`; `NonKit_DBInitialize`, `NonKit_DBWriteLock`, `NonKit_DBWriteUnlock`, `NonKit_DBRelease`; `NonKit_GetPictureUniqueIdByFilePath`, `NonKit_GetPictureZmiByFilePath`, `QueueMediaForPostProcessing(ULONG, bool, bool)`; `InitializeSounds`, `UninitializeSounds`, `PlayShutterStartSound`, `PlayShutterStopSound`, `CameraShutterButtonGetEnabledOnIdle`, `CameraShutterButtonSetEnabledOnIdle`; `NonKit_IsFacebookAccountDeprecated`, `NonKit_IsFaceBookReplacementAppInstalled`, `NonKit_GetFaceBookAccountReplacementAppId`; `NonKit_GetScreenResolution`, `NonKit_GetLocaleName`, `NonKit_SHLoadIndirectString`, `NonKit_CoCreateInstance`, `NonKit_SysAllocString`, `NonKit_SysFreeString` |
| ShellChromeAPI | `Shell_GetCurrentLockState`, `Shell_IdleTimerReset` |
| dsclient | `DSOpenSharedFile`, `DSGetSharedFileName`, `DSCopyFromSharedFile`, `DSFreeString` |
| Orientation | `DeviceOrientationInit`, `DeviceOrientationStart`, `DeviceOrientationStop`, `DeviceOrientationDeinit` |
| d3d11 | `D3D11CreateDevice` |
| d2d1 | `D2D1CreateFactory` |
| MFPlat | `MFStartup`, `MFShutdown`, `MFCreateSourceResolver` |
| MFCORE | `MFGetService` |
| XmlLite | `CreateXmlReader` |
| SHCORE | `SHCreateStreamOnFileW` |
| api-ms-win-shcore-stream-winrt-l1-1-0 | `CreateStreamOverRandomAccessStream` |
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance`, `CoCreateFreeThreadedMarshaler`, `CoCreateGuid`, `CLSIDFromString`, `IIDFromString`, `StringFromGUID2`, `CoGetApartmentType`, `CoGetContextToken`, `CoGetObjectContext`, `CoMarshalInterThreadInterfaceInStream`, `CoGetInterfaceAndReleaseStream`, `CreateStreamOnHGlobal`, `CoTaskMemAlloc`, `CoTaskMemFree`, `PropVariantClear` |
| OLEAUT32 | `VariantInit`, `VariantClear` |
| api-ms-win-core-file-l1-2-1 | `DeleteFileW`, `CreateDirectoryW`, `RemoveDirectoryW`, `FindFirstFileExW`, `FindNextFileW`, `FindClose`, `GetFileAttributesExW`, `GetFileTime`, `GetDiskFreeSpaceExW` |
| api-ms-win-core-sysinfo-l1-2-1, -timezone-l1-1-0, -datetime-l1-1-1, -localization-l1-2-1 | `GetTickCount`, `GetTickCount64`, `GetSystemTimeAsFileTime`, `GetLocalTime`, `FileTimeToSystemTime`, `SystemTimeToFileTime`, `SystemTimeToTzSpecificLocalTime`, `TzSpecificLocalTimeToSystemTime`, `GetTimeFormatEx`, `GetLocaleInfoEx` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventExW`, `SetEvent`, `ResetEvent`, `CreateSemaphoreExW`, `ReleaseSemaphore`, `WaitForSingleObject(Ex)`, `Sleep`, critical sections, SRW locks |
| api-ms-win-core-winrt-string-l1-1-0, -winrt-error-l1-1-0 | `WindowsCreateString(Reference)`, `WindowsDeleteString`, `WindowsGetStringRawBuffer`, …, `RoOriginateError` |
| wincorlib | 62 C++/CX runtime functions (`Platform::Details::GetActivationFactory`, `Platform::Object`, exceptions, event sources, boxing) |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventWrite`, `EventUnregister` |
| msvcrt, api-ms-win-core-errorhandling, -rtlsupport, -processthreads, -util, -handle | CRT (`_initterm`, `__dllonexit`, `malloc`, `swprintf_s`, `qsort`, `pow`, …), C++ exceptions, `TerminateProcess`, `CloseHandle`, `DecodePointer` |

msvcrt, rtlsupport, errorhandling, processthreads and util are the Visual C++ DLL CRT startup, C++ exception and `/GS` cookie code; wincorlib and the winrt-string imports are the C++/CX runtime.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `<FolderType 7>\OEM\Settings\CameraSettings.xml` | XmlLite `CreateXmlReader` (`IID_IXmlReader`) on a file stream (`FilePathHelper::GetOEMSettingsPath` / `GetOEMSettingsFile`) | [OEM camera settings](#oem-camera-settings-camerasettingsxml); icons referenced in it are turned into `file://` URIs (`FilePathHelper::GetOEMIconUri`) |
| `{317D06E8-5F24-433D-BDF7-79CE68D8ABC2}` `CLSID_WICImagingFactory2` (WindowsCodecs.dll) | `CoCreateInstance`, `IWICImagingFactory` `{EC5EC8A9-C395-4314-9C77-54D7A935FF70}` | Decoding, thumbnails, metadata, JPEG encoding (`NativeImageDecoder`, `NativeImageHelper`, `ThumbnailHelper`, `ImageStatistics`, `ImagePresetEditor`, `StartTileManager::CopyImageWithCorrectedOrientation`) |
| `{68ED5C62-F534-4979-B2B3-686A12B2B34C}` `CLSID_WICJpegQualcommPhoneEncoder` (DLL ?) | `CoCreateInstance`, `IWICBitmapEncoder` `{00000103-A8F2-4877-BA0A-FD2B6645FB94}` (`sub_1037A82C`) | Hardware JPEG encoder; falls back to the WIC factory ("Hardware encoder not available") |
| `{F81B1B56-7613-4EE4-BC05-1FAB5DE5C07E}` (DLL ?) | `CoCreateInstance`, interface `{B824B49D-22AC-4161-AC8A-9916E8FA3F7F}` (`NativeVideoDecoder`, `sub_10338474`) then `SHCreateStreamOnFileW` | Video metadata (`NativeVideoDecoder::GetMetadata`) ? |
| `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` (DLL ?) | `NonKit_CoCreateInstance`, `CLSCTX` 0x17, interface `{698D57C2-292D-4CF3-B73C-D95A6922ED9A}` | Created by `StartTileManager` and `AppDiscoveryHelper` constructors (application / tile management ?) |
| Media Foundation source for video files | `MFCreateSourceResolver` (`sub_103AC234`), `MFGetService` | Video thumbnails / properties |
| `<FolderType 5>\Bursts\<n>.jpg` | `NonKit_GetKnownFolderPath(5)`, `CreateDirectoryW`, files `%d.jpg` (`FilePathHelper::CreateBackingDataFolder`, `GetBackingDataFileName`) | Backing data of burst ("Blink") captures; aged out after `BackingDataAgeoutInterval` |
| `<FolderType 6>\PinnedAlbumBackground_<id>.jpg` | `NonKit_GetKnownFolderPath(6)`, `FindFirstFileExW("\PinnedAlbumBackground_*.jpg")`, `DeleteFileW` (`StartTileManager::GetImagePath`, `RemoveStaleTileImages`) | Background images of pinned album tiles |
| `<photos cache>\<GUID>.<ext>` | `NonKit_GetPhotosAppCachePath`, name `%08x-%04x-…%s` from `CoCreateGuid` (`FilePathHelper::CreateTempFileInternalAsync`), and `NonKit_GetKnownFolderPath(5)` (`CreateTempFileForEdit`) | Temporary files for edits and video recording (`.mpeg4`, `.wmv`) |
| `<FolderType 2 / 3>\WP_YYYYMMDD_NNN.jpg` | `NonKit_GetKnownFolderPath(2 or 3)` + `NonKit_WriteStreamToFile` / `NonKit_CopyFile` / `NonKit_MoveFile` (`AddPictureFromStreamAsync`, `LocalPhotoAlbum::PerformFileOperationTask`, `GetUniqueFileName`: `WP_%04d%02d%02d`, `%s_%03d%s`) | New pictures; 2 or 3 depends on a flag of the album (camera roll / saved pictures ?) |
| `dss://…` files | `DSGetSharedFileName`, `DSOpenSharedFile(name, 0x80, &h)`, `DSCopyFromSharedFile` (dsclient) | Pictures shared by another app (`FileSystemPhotoItem`, `LocalPhotoAlbum::AddPictureToStoreAsync`) |
| `PhoneInternal.Experiences.Media.*`, `PhoneInternal.Experiences.OnlinePhotos.*`, `PhoneInternal.Experiences.AppDiscovery.AppDiscovery` (WinRT, DLL ?) | activation factories | Media store, online albums, app discovery |

`FolderType` values are an enum of Photos.ModelsNonKit.dll (not analysed); the meaning above comes from the callers.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x10223F20 | none; returns `!Platform::Details::TerminateModule(module)` |
| 2 | `DllGetActivationFactory` | 0x10223F04 | `HSTRING activatableClassId`, `IActivationFactory **factory`; forwarded to `Platform::Details::GetActivationFactory(module, …)` (module object at 0x105D4A98) |

Activatable classes (those with a `__<Class>ActivationFactory`): `NativeImageMetadata`, `InMemoryStream`, `PhotoModel`, `CaptureResult`, `App`, `TypeStore`, `MediaTransferNotifier`, `SDCardNotifier`, `CameraPropertyRange`, `PhotosSqm`, `ExtensionAppData`, `AppDiscoveryHelper`, `ApplicationSettings`, `RegistryKey`, `NativeImageDecoder`, `AssociatedPhotoItem`, `ThumbnailHelper`, `BitmapInfo`, `NativeImageHelper`, `OrphanFileTracker`, `FrameAcquiredEventArgs`, `CaptureStoppedEventArgs`, `FocusChangedEventArgs`, `Log.Trace`, `WMCCamera`, `FilePathHelper`, `OEMSettingValue`, `OEMOverrideSetting`, `EnumOEMSetting`, `ToggleOEMSetting`, `OEMSettings`, `CameraSettings`, `OrientationChangedEventArgs`, `CameraController`, `FileSystemPhotoItem`, `LocalVideoItem`, `VirtualPhotoEvent`, `ImagePresetEditor`, `ImageStatistics`, `LocalPhotoItem`, `LazyMediaItemIterator`, `LazyMediaItemVectorView`, `LocalPhotoEvent`, `MediaRTUTHelper`, `NativeVideoMetadata`, `NativeVideoDecoder`, `OnlinePhotoItem`, `OnlineVideoItem`, `PagedPhotoItemCache`, `WnfSubscription`, `StartTileManager`, `UploadJobItemModel`, `UploadMediaManager`, `VideoCaptureMonitor` (all in namespace `PhotosApp.Models`).

### Startup

`DllEntryPoint` (0x102246BC): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then `dllmain_dispatch` (CRT). The ETW provider is registered lazily by `sub_10222F9C` (`EventRegister` if the handle at 0x105D49B8 is 0, called from `sub_10222F88`). The rest is created on demand by the activation factories.

### Camera model selection (CameraFactory::Create, 0x1020AE60)

1. Reads DWORD `CameraStack` of `Software\Microsoft\Camera\Settings` (override):
   - 1 → `Camera` (`sub_1020CB10`, 0x70 bytes): "Creating WPMC-based camera model based on override key", `Windows.Phone.Media.Capture.PhotoCaptureDevice` / `AudioVideoCaptureDevice`;
   - 2 → `WMCCamera` (`sub_1038A4AC`, 0xB0 bytes): "Creating WMC-based camera model based on override key", `Windows.Media.Capture.MediaCapture` + `LowLagPhotoCapture` / `LowLagPhotoSequenceCapture`, preview through `Windows.Phone.Media.Capture.MediaCapturePreviewSink`.
2. Otherwise reads DWORD `UpdatedApolloDriver` of `Software\Microsoft\CaptureService`: 0 (or absent ?) → `WMCCamera` ("Creating WMC-based camera model for ARM"), other value → `Camera` ("Creating WPMC-based camera model for ARM").

`IsBlinkSupported` (`sub_1020B7E0`): DWORD `IsBlinkSupported` of `Software\Microsoft\Photos\OEM`, 1 when absent. `HWCameraShutterButtonNotPresent` (`sub_10377180`): same key, a hardware shutter button is assumed unless the value exists and is non-zero.

The `WMCCamera` traces (`[WMCCamera] …`) show what it does: enumerates the sensors (`DeviceInformation`), initialises `MediaCapture`, starts the preview, prepares low-lag photo / photo sequence ("FUTURE" and "HISTORY" frames for burst capture), sets 60 fps (disabling video stabilisation) or 30 fps for video, continuous auto-focus and focus regions (`RegionOfInterest`), scene mode, focus range, white balance presets.

### OEM custom properties (WMCCamera::SetCustomProperty, 0x103AD3C8)

For a property GUID coming from the OEM settings:
1. Opens `Software\Microsoft\CaptureService\OEMCustomProperties\<GUID>`.
2. Reads string `KSSET` (property set GUID) and DWORD `KSID` (property id).
3. Formats `"%s %d"` (`KSSET KSID`) and sets the value on the `MediaCapture` video device controller by that name (`sub_1036C5E8` → interface method +0x18, `SetDeviceProperty` ?).

The KS properties end in [qccamavs8930.sys](../drivers/qccamavs8930.md#automation-table) through [MFCaptureEngine.dll](./mfcaptureengine.md).

### OEM camera settings (CameraSettings.xml)

`XmlSettingsReader` (constructor `sub_101F2FF8`) parses `<FolderType 7>\OEM\Settings\CameraSettings.xml`. Element / attribute names found: `CameraSettings`, `Configuration` (attributes for the camera: `still` / `video`, `front` / `rear`, `Sensor`), `UserSetting`, `OverrideSetting`, `Value`, `IsDefault`, `DWORD`, `PropertyGuid`, `DisplayName`, `TrueIcon`, `FalseIcon`. The settings become `OEMSettings` / `EnumOEMSetting` / `ToggleOEMSetting` / `OEMOverrideSetting` objects; the user's choice is saved under `Software\Microsoft\Photos\Shared\CameraSettings\OEMSettings\{Still,Video}\{Rear,Front}` (`ApplicationSettings::LoadOEMSetting`, `ClearOEMSettings`).

### Photo URIs

`PhotoUriBuilder` / `PhotoUriParser` use `photos://album/<x>` (`cameraroll`, `saved`, `screenshots`, `sample`, `favorites`, `loose`, `allvideo`, `all`, `local`, `localex`, `online`, `onlineex`, `onlineroot`, `tokenlist`), `photos://photo/{local,localex,onlineex}`, `photos://video/{localex,onlineex}`, with the query keys `?app=`, `&rid=`, `&albumType=`, `?Title=`, `&tokens=`. Special album types (`SpecialAlbumType`): `CameraRoll`, `SavedPictures`, `ScreenShots`, `Favorites`, `SamplePictures`, `AllPictures`, `LoosePictures`, `AllVideos`.

### Other system calls

- `Shell_GetCurrentLockState` (`sub_102234EC`): "above lock" when the state is 1 or 0x7FFFFFFF (`AboveLockPhotoAlbum`).
- `Shell_IdleTimerReset(8)` (`sub_102C0B08`, `DisableIdleDetectionTimer`): keeps the screen on while the camera runs.
- `DeviceOrientationInit(callback sub_1021339C, ctx, &handle)` + `DeviceOrientationStart` (`DeviceOrientationTracker::Start`, 0x102132DC).
- `D3D11CreateDevice(NULL, HARDWARE, NULL, BGRA_SUPPORT, …)`, `IDXGIDevice` `{54EC77FA-1377-44E6-8C32-88FD5F44C84C}`, `D2D1CreateFactory(SINGLE_THREADED, IID_ID2D1Factory)` (`ImagePresetEditor::CreateAssortedGraphicsDevices`, 0x10335418).
- `QueueMediaForPostProcessing(id, …)` after `SetPictureMetadataAsync` / `SetVideoMetadataAsync` (`sub_1034D47C`, `sub_1034D568`, `sub_103AC980`).
- `NonKit_DBInitialize` + `NonKit_DBWriteLock` (`DBWriteLock`, 0x1028FFAC).
- `PlayShutterStartSound` at the start of a burst capture (`sub_104689E8`).
- `NonKit_WpSqmGetSession({C6CF0920-A353-48C5-82D0-0640C6F09D94})` (`sub_1026F780`, `PhotosSqm`).
- `OrphanFileTracker` (`Software\Microsoft\Photos\OrphanFileIndex`, `sub_103CADC0`): each value is a file path; files older than one day (`GetFileTimeByPath`, 864 000 000 000 × 100 ns) are deleted with `DeleteFileW` and the value removed.
- App discovery (`AppDiscoveryHelper`): category GUIDs `{5B04B775-356B-4AA0-AAF8-6491FFEA5631}` (camera apps / lenses, used by `CameraAppsList`), `…5632}`, `…5633}`, `…568C}`, `{A8FF395E-2EA9-4FD7-A16E-3203C93709CA}`, names `Camera_Capture_App`, `Photos_Rich_Media_Edit`; the Facebook account replacement app id comes from `NonKit_GetFaceBookAccountReplacementAppId`.
- `PhoneROMLanguage` of `System\Platform\DeviceTargetingInfo` (`sub_10379190`): returns true when it is 804 (Chinese, PRC).

### WNF states

Subscriptions go through `PhotosApp.Models.WnfSubscription` (constructors `sub_10212684` / `sub_102127F8`) → `ModelsNonKit::WnfSubscribe(WnfId, …, callback sub_103A6EBC)`; the class raises a `ValueChangedEventHandler` event, and `WnfQueryUInt32` reads the value (`sub_103332EC`). The state names are behind the `WnfId` enum of Photos.ModelsNonKit.dll (not analysed).

| WnfId | Subscribed by | Use |
|-------|---------------|-----|
| 3, 4, 8 | `MediaTransferNotifier::StartListening` (0x10212210) | media transfer (MTP / sync ?) notifications ("[PN] StartListening") |
| 5 | same, with two extra dwords | ? |
| any | `WnfSubscription` factory (`sub_103878A0`, `sub_103878E8`) | given by the app |

### Registry

All under HKLM/HKCU as chosen by `NonKit_RegCreateOrOpenKey` (hive enum not resolved).

| Key | Values |
|-----|--------|
| `Software\Microsoft\Photos\Shared\CameraSettings` | `FlashMode`, `FFCFlashMode`, `VideoLampMode`, `FFCVideoLampMode`, `FlashNoFlashMode`, `TouchMode`, `CaptureMode`, `ProximityAboveLock`, `DefaultLens` / `DefaultCameraAppID` ? |
| `…\CameraSettings\QuickBarSaved` | quick bar buttons (`ApplicationSettings::QuickBarButtons`) |
| `…\CameraSettings\OEMSettings\{Still,Video}\{Rear,Front}` | OEM setting choices |
| `…\CameraSettings\CaptureSequenceNumber`, `…\SavedPicturesSequenceNumber` | file name sequence numbers |
| `Software\Microsoft\Photos\Shared\PhotoSettings` | `EmbedLocation`, `EnableEventGrouping`, `LastBackgroundWorkerCompletedTime`, `LastReverseGeocodeLanguage`, `OldestAllowableReverseGeocodeCache` ?, `BackingDataAgeoutInterval` ? |
| `Software\Microsoft\Photos\Shared\AutoUploadSettings\{Photo,Video}` | auto-upload (SkyDrive) settings |
| `Software\Microsoft\Zune\AutoUploadSettings` | `PhotoLowResEnabled`, `PhotoFullResEnabled`, `VideoLowResEnabled`, `VideoFullResEnabled` (older location) |
| `Software\Microsoft\Zune\PhotosAppSettings` | `HasLaunchedAlternatePhotoSelectionPageBefore` ? |
| `Software\Microsoft\Photos\Shared\PhotosStartTileSettings` | `PhotosStartTileSourceIndex`, `PhotosStartTileUpdatedWithUGC` |
| `Software\Microsoft\Photos\OEM` | `IsBlinkSupported`, `HWCameraShutterButtonNotPresent`, camera apps list (`CameraAppsList`, `%s\%s` subkeys) |
| `Software\Microsoft\Photos\OEM\QuickBarDefault` | default quick bar |
| `Software\Microsoft\Photos\OrphanFileIndex` | orphan file paths |
| `Software\Microsoft\Camera\Settings` | `CameraStack` |
| `Software\Microsoft\CaptureService` | `UpdatedApolloDriver` |
| `Software\Microsoft\CaptureService\OEMCustomProperties\<GUID>` | `KSSET`, `KSID` |
| `System\Platform\DeviceTargetingInfo` | `PhoneROMLanguage` |

Values marked "?" are matched to the key by their position in the string table, not by the code.

### ETW

Provider `{E4515607-2C65-4073-BE59-FB517E9EBD0A}`, registered in `sub_10222F9C`; the enable bits are kept at 0x105D4A80.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 2 | 2 (error) | 0, 0 | 0x1 | 0x1 | HRESULT failure with the function name and line (`sub_102A3880`, 687 callers; string payloads) |
| 14 | 2 | 0, 0 | 0x1 | 0x1 | other failure trace (`sub_102A38B8`, 106 callers) |
| 3 | 4 | 0, 0 | 0x4 | 0x2 | camera factory messages (`sub_102A384C`) |
| 4 | 5 (verbose) | 0, 0 | 0x8 | 0x4 | general trace strings (`sub_101F45EC`, 219 callers: "[PN] …", "Camera::…", "[WMCCamera] …") |
| 6 | 4 | 0, 0 | 0x1 | 0x10 | `sub_1020CA0C` (5 callers) |
| 7–24 | 4 | 1 (start) / 2 (stop), tasks 1–8 | 0x2 | 0x8 | activity start / stop pairs, through a table of 18 functions at 0x10506A28 (`Log.Trace` methods ?) |
| 25–36 | 4 | 1 / 2, tasks 11–16 | 0x2 | 0x8 | camera activity start / stop pairs (capture, focus, …) |

Event markers known by name (`EventMarkerID`, `sub_102DBD0C`): `AppLaunchBegin`, `AppActivated`, `AppDeactivated`, `AppClosing`, `AlbumRootViewPage`, `SubAlbumLocalPage`, `SubAlbumSocialPage`, `EnteredMultiSelect`, `ExitedMultiSelect`.
