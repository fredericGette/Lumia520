## MFPalWP.dll

The Windows Phone "platform abstraction layer" of Media Foundation (MF PAL): the phone-specific functions that the media stack calls for hardware resources, audio focus, network, protected output and a few device facts.  
`MFPalWP.dll` (120 808 bytes, 371 functions, ATL + CRT, PDB `mfpalwp.pdb`) exports 39 flat functions in five families, named by prefix: `MFMEPal*` for the media engine (playback), `MFTEPal*` for the transcode engine, `MFMCPal*` for media capture, `MFNetPal*` for the network source and `MFPal*` for the rest. Most of them are thin wrappers around other phone components:
- hardware decoder / encoder / camera capacity is reserved from the execution manager resource manager (`EMCLIENT!RmAcquireResources`, [resource requests](#resource-requests)), with one [resource client](#resource-client-object) per registered engine, asynchronous completion through `MFPutWorkItemEx` and revocation through `RmGetNotification`;
- playback is also reported to the media service (`MediaService!CreateMediaService`, [media service](#media-service)), and the media transport controls get the position (`CreateSMTCAppInstance`);
- protected output goes to [VideoSinkOTA.dll](./videosinkota.md) and [CompClient.dll](./compclient.md) (delay-loaded);
- background audio is "muted" by opening an `IAudioClient2` stream of a dedicated category ([background audio](#background-audio)), the proxy comes from `ConnState!GetPreferredConnectionDetails` and the country code from two `CELL` WNF states.

It's reached through the API set `ext-ms-win-mf-pal-l1-1-0` (the contract that maps to this DLL ?). `WINDOWS.MEDIA.DLL` (the `Windows.Media` WinRT classes, not documented here, client of the capture engine [MFCaptureEngine.dll](./mfcaptureengine.md)) delay-loads 8 functions from it, the [capture](#capture-resources) ones and `MFTEPalSupportSoftwareTranscoding` ([callers in WINDOWS.MEDIA.DLL](#callers-in-windowsmediadll)). The callers of the `MFMEPal*`, `MFNetPal*` and other `MFTEPal*` exports aren't known (the media engine and the network source ?); their parameter lists come from how the arguments are used.

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| MediaService | `CreateMediaService`, `CreateSMTCAppInstance` |
| EMCLIENT | `RmAcquireResources`, `RmReleaseResources`, `RmGetNotification` |
| MFPlat | `MFCreateAttributes`, `MFUnwrapMediaType`, `MFCreateAsyncResult`, `MFPutWorkItem`, `MFPutWorkItemEx` |
| PROPSYS | `PSCreateMemoryPropertyStore` |
| ConnState | `GetPreferredConnectionDetails` |
| policymanager | `PolicyManager_GetCameraPolicy_AllowCamera` |
| WPCOREUTIL | `GetDeviceUniqueID` |
| [VideoSinkOTA.dll](./videosinkota.md) (delay-load) | `MFVideoSinkCreateVideoOTA`, `VerifyApolloGenerationDisplayDriver` |
| [CompClient.dll](./compclient.md) (delay-load) | `StartProtectedSession`, `StopProtectedSession` |
| PsmApp (delay-load) | `PsmRegisterAppStateChangeNotification`, `PsmUnregisterAppStateChangeNotification` |
| ModernApiExtHost (delay-load) | `ProductInfoFromPackageFullName` |
| ext-ms-win-rtcore-ntuser-sysparams-l1-1-0 (delay-load) | `MonitorFromWindow` |
| WS2_32 | `WSAIoctl`, `WSAGetLastError` |
| ntdll | `RtlQueryWnfStateData`, `NtQueryWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlQueryPackageIdentity`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlLengthSid` |
| OLEAUT32 | `SysFreeString`, `VarUI4FromStr` |
| api-ms-win-core-com-l1-1-1 | `CoCreateInstance`, `CoTaskMemAlloc`, `CoTaskMemRealloc`, `CoTaskMemFree`, `PropVariantClear`, `StringFromCLSID` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey`, `RegCreateKeyExW`, `RegSetValueExW`, `RegDeleteValueW`, `RegEnumKeyExW`, `RegQueryInfoKeyW` |
| api-ms-win-core-synch-l1-2-0, api-ms-win-core-kernel32-legacy-l1-1-1 | `CreateEventW`, `OpenEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `WaitForMultipleObjects`, critical sections, `InitOnceBeginInitialize`, `InitOnceComplete`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2, api-ms-win-security-base-l1-2-0, api-ms-win-core-handle-l1-1-0 | `CreateThread`, `GetCurrentProcess`, `GetCurrentProcessId`, `OpenProcessToken`, `GetTokenInformation`, `DuplicateHandle`, `CloseHandle`, `TerminateProcess` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleHandleExW`, `GetModuleFileNameW`, `GetModuleFileNameA`, `FindResourceExW`, `LoadResource`, `SizeofResource`, `DisableThreadLibraryCalls` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-string-*, errorhandling, rtlsupport, debug, delayload | `MultiByteToWideChar`, `CharNextW`, `lstrcmpiW`, `GetLastError`, `RaiseException`, exception filters, `OutputDebugStringA`, `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| msvcrt.dll | `malloc`, `free`, `realloc`, `operator new`/`delete`, `memcpy`, `memset`, `memcmp`, `wcslen`, `wcscmp`, `_wcsnicmp`, `_vsnwprintf`, `wcsncpy_s`, `strcpy_s`, `strrchr`, … (CRT, C++ exceptions) |

The msvcrt, rtlsupport, errorhandling and debug imports and `TerminateProcess` are the Visual C++ DLL CRT, C++ exception and `/GS` code. The registry writes, `LoadLibraryExW` / `FindResourceExW`, `CharNextW`, `lstrcmpiW` and `VarUI4FromStr` belong to the ATL registrar (`REGISTRY` resource script parser, `HKEY_CLASSES_ROOT`…, `ForceRemove`, `NoRemove`), linked in with the ATL module but not reachable from an export (the DLL has no `DllRegisterServer`).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [VideoSinkOTA.dll](./videosinkota.md) | delay-load | Video OTA ([MFMEPalCreateVideoOTA](#protected-output)), Apollo driver check ([MFPalNeedGPUSyncEvent](#other-exports)) |
| [CompClient.dll](./compclient.md) | delay-load | Compositor protected session ([protected output](#protected-output)) |
| `PsmApp.dll`, `ModernApiExtHost.dll`, ntuser sysparams | delay-load | App state notifications ([PSM](#resource-client-object)), product info of the package ([MFPalLegacyProcess](#other-exports)), `MonitorFromWindow` |
| `advapi32.dll` / `API-MS-Win-Core-LocalRegistry-L1-1-0.dll` | `GetModuleHandleW` / `LoadLibraryExW` + `GetProcAddress("RegDeleteKeyExW")`, `"RegDeleteKeyW"` (`sub_10005C80`) | ATL registrar only (unreachable) |
| Own module, `REGISTRY` resource | `LoadLibraryExW` (data file), `FindResourceExW` (`sub_100064F8`) | ATL registrar only (unreachable) |
| Media service (in-process object of `MediaService.dll`) | `CreateMediaService` | Playback state, audio focus, background state ([media service](#media-service)) |
| Event named by the media service | `OpenEventW(SYNCHRONIZE, FALSE, name)` | Name returned by service method 3; wakes the [manager thread](#manager-thread) |
| MMDevice API (`CLSID_MMDeviceEnumerator` `{BCDE0395-E52F-467C-8E3D-C4579291692E}`) | `CoCreateInstance(CLSCTX 0x17, IID_IMMDeviceEnumerator {A95664D2-9614-4F35-A746-DE8DB63617E6})` | Audio client of the [background audio](#background-audio) mute |

No process is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllMain` | 0x100049D4 | Exported by name; the ordinary `DllMain` ([Startup](#startup)) |
| 2 | `MFMCPalAcquireResources` | 0x1000795C | `DWORD cookie, DWORD flags` (1 = microphone, 4 = camera, 2 asserts) |
| 3 | `MFMCPalAcquireVideoEncoderResource` | 0x10007A34 | `DWORD cookie, DWORD macroblocksPerSecond, DWORD *id` |
| 4 | `MFMCPalGetMobileCountryCode` | 0x10007B58 | `DWORD *mcc, DWORD *mnc` |
| 5 | `MFMCPalMuteBackgroundAudio` | 0x10007B80 | none used |
| 6 | `MFMCPalRegisterForResourceNotifications` | 0x10007850 | `IUnknown *callback` (method 3: `OnResourceDeparted(DWORD)`), `DWORD *cookie` |
| 7 | `MFMCPalReleaseResources` | 0x10007A1C | `DWORD cookie` |
| 8 | `MFMCPalReleaseVideoEncoderResource` | 0x10007A8C | `DWORD cookie, DWORD id` |
| 9 | `MFMCPalResumeBackgroundAudio` | 0x10007C70 | none |
| 10 | `MFMCPalUnregisterForResourceNotifications` | 0x10007944 | `DWORD cookie` |
| 11 | `MFMEPalBeginAcquireResource` | 0x100074BC | `DWORD kind, IMFMediaSource *source, DWORD cookie, IMFAsyncCallback *callback, IUnknown *state` |
| 12 | `MFMEPalCancelAcquireResource` | 0x100074E4 | `DWORD cookie`; always fails (`E_NOTIMPL` once the cookie is found) |
| 13 | `MFMEPalCreateVideoOTA` | 0x10007530 | `IUnknown *callback, IUnknown **ota` |
| 14 | `MFMEPalEndAcquireResource` | 0x100074FC | `DWORD cookie, IMFAsyncResult *result` |
| 15 | `MFMEPalEventNotify` | 0x1000744C | `DWORD cookie, DWORD event, DWORD value` |
| 16 | `MFMEPalRegisterForResourceNotifications` | 0x10007418 | `IUnknown *callback, DWORD *cookie` |
| 17 | `MFMEPalReleaseResource` | 0x10007518 | `DWORD cookie` |
| 18 | `MFMEPalStartProtectedSession` | 0x100075CC | `ICompositorAlpcClient **session` |
| 19 | `MFMEPalStopProtectedSession` | 0x10007620 | `ICompositorAlpcClient *session` |
| 20 | `MFMEPalUnRegisterForResourceNotifications` | 0x10007434 | `DWORD cookie` |
| 21 | `MFMEPalUpdateCreationInfo` | 0x100073F4 | `DWORD flagsIn, IMFAttributes *attributes, DWORD *flagsOut, IMFAttributes **newAttributes` |
| 22 | `MFMEPalUpdateTopologyAttributes` | 0x1000746C | `IMFMediaSource *source, IMFAttributes **topologyAttributes, IMFAttributes **audioRendererAttributes, void **other` |
| 23 | `MFMEPalUpdateTopologyAttributesEx` | 0x10007494 | same with `IMFAttributes *creationAttributes` as second parameter |
| 24 | `MFNetPalGetProxy` | 0x100076E0 | `const WCHAR *url ?, WCHAR *proxy, DWORD *length` (in: buffer size, out: length, in characters) |
| 25 | `MFNetPalSetAppProdIDOnSocket` | 0x10007674 | `GUID productId` (by value, R0–R3), `SOCKET s` |
| 26 | `MFNetPalUseProxyLocator` | 0x10004F14 | none; returns 0 |
| 27 | `MFNetPalUseWinINetCaching` | 0x10004F14 | none; returns 0 |
| 28 | `MFPalGetDeviceUniqueID` | 0x10007330 | forwarded to `WPCOREUTIL!GetDeviceUniqueID` |
| 29 | `MFPalLegacyProcess` | 0x10007344 | none; returns a `BOOL` |
| 30 | `MFPalNeedGPUSyncEvent` | 0x100073D4 | none; returns a `BOOL` |
| 31 | `MFPalUpdateDecoderAttributes` | 0x10007320 | `IMFMediaType *type, IMFTopology *topology, IMFAttributes **attributes` |
| 32 | `MFPalUseMonitorsForOTA` | 0x10004F08 | none; returns 1 |
| 33 | `MFTEPalBeginAcquireResource` | 0x10007774 | `DWORD cookie, IMFMediaSource *source, IMFAsyncCallback *callback, IUnknown *state` ? |
| 34 | `MFTEPalEndAcquireResource` | 0x10007798 | `DWORD cookie, IMFAsyncResult *result` |
| 35 | `MFTEPalOnEngineCreated` | 0x100077CC | `?, void *a, void *b`: `E_INVALIDARG` if `a` or `b` is NULL, `0xC00D3E85` if the transcode manager is shut down, `S_OK` if it's started, else `E_UNEXPECTED`; nothing is stored |
| 36 | `MFTEPalRegisterForResourceNotifications` | 0x10007740 | `IUnknown *callback, DWORD *cookie` |
| 37 | `MFTEPalReleaseResource` | 0x100077B4 | `DWORD cookie` |
| 38 | `MFTEPalSupportSoftwareTranscoding` | 0x10004F14 | none; returns 0 |
| 39 | `MFTEPalUnRegisterForResourceNotifications` | 0x1000775C | `DWORD cookie` |

All the others return an HRESULT. The three resource families each work on a global singleton built on first use under an `INIT_ONCE`:

| Singleton | Address | Constructor | Used by |
|-----------|---------|-------------|---------|
| Media engine manager | 0x10013EE4 | `sub_10007FC4` (vtable `off_10001E18`), via `GetMEManager` (`sub_10007D60`) | `MFMEPal*` |
| Transcode manager | 0x10013F68 | `sub_1000CBBC` (vtable `off_10001FE4`), via `GetTEManager` (`sub_10007DE0`) | `MFTEPal*` |
| Capture manager | 0x10013FCC | inline in `GetMCManager` (`sub_10007E60`) | `MFMCPal*` |
| Network helper | 0x10013F60 | vtable `off_1000206C` only | `MFNetPal*` |
| Background audio object | 0x10014000 | pointer, set by `MFMCPalMuteBackgroundAudio` | `MFMCPal*BackgroundAudio` |

Media engine manager (0x78 bytes; the transcode manager, 0x60 bytes, has the same layout up to +0x54, then +0x58 started and +0x5C shut down):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 0x18 | Critical section (state, client map) |
| 0x1C | 0x18 | Critical section (start / stop) |
| 0x34 | 4 | Last cookie (interlocked increment) |
| 0x38 | 0x14 | Hash map cookie → [resource client](#resource-client-object) |
| 0x4C | 4 | Event given to the resource manager for the notifications of every client |
| 0x50 | 4 | Stop event of the [manager thread](#manager-thread) |
| 0x54 | 4 | Manager thread |
| 0x58 | 4 | Event named by the media service (`OpenEventW`) |
| 0x5C | 4 | ? |
| 0x60 | 4 | Started |
| 0x64 | 4 | Shutting down (media engine) |
| 0x68 | 4 | Media service object |
| 0x6C | 4 | Last value given to media service method 18 |
| 0x70 | 4 | Event set when the media service is (re)connected or lost |
| 0x74 | 4 | WNF watcher of the media service ([WNF states](#wnf-states)) |

### Startup

`DllEntryPoint` (`_DllMainCRTStartup`, 0x10011024): `__security_init_cookie`, then the usual `dllmain_dispatch`.  
`DllMain` (0x100049D4), on `DLL_PROCESS_ATTACH`: `DisableThreadLibraryCalls`, calls the `ObjectMain(TRUE)` of each entry of the ATL object map (0x10013E88, 36-byte entries) and of the auto object map (0x10013C04–0x10013C08), then registers the [ETW provider](#etw). On `DLL_PROCESS_DETACH`: unregisters the provider, releases the class objects and calls `ObjectMain(FALSE)`, and destroys the ATL module (`sub_10004BD0`). Nothing else is started before an export is called.

### Media engine resources

`MFMEPalRegisterForResourceNotifications(callback, &cookie)` (`sub_10008B14`):
1. Starts the manager if it isn't (`StartMEManager`, `sub_10008310`): creates the events +0x70 and +0x50, [connects to the media service](#media-service) (`sub_100084B8`), creates the event +0x4C and the [manager thread](#manager-thread) (`sub_10009B6C`), and the WNF watcher (`sub_1000F40C`, [WNF states](#wnf-states)). Any failure stops everything again (`sub_10008174`).
2. Increments the cookie, creates a [resource client](#resource-client-object) of type 1 (`sub_1000AAC4(cookie, callback, manager+0x4C, 1, mediaService)`) and inserts it in the map; returns the cookie. `E_OUTOFMEMORY` (0x8007000E) if the insertion fails.

`MFMEPalUnRegisterForResourceNotifications(cookie)` (`sub_10008D0C`): releases the client's resources (`sub_1000BFA0`), shuts it down (`sub_1000ADC8`), removes it from the map, tells the media service whether a video is still playing (`sub_100097D8`, below) and stops the manager when the map is empty (`sub_10008174`: unsubscribes the WNF states, shuts the clients down, media service methods 10 (FALSE) and 5, stops the thread with the event +0x50 and waits 5 s, method 5 then 8 (4, 0), closes the handles). `0xC00D3E85` if the manager is shutting down, `E_UNEXPECTED` (0x8000FFFF) for an unknown cookie or a manager not started.

`MFMEPalBeginAcquireResource(kind, source, cookie, callback, state)` (`sub_100091D0`), `E_INVALIDARG` if `callback` is NULL:
- kind 1, hardware decoders (`sub_1000B760`): `E_UNEXPECTED` if the client already has a request pending or granted. Reads the source characteristics (`IMFMediaSource::GetCharacteristics`): `MFMEDIASOURCE_DOES_NOT_USE_NETWORK` (0x80) sets client +0x68. Keeps `callback` / `state` (+0x48 / +0x4C), resets the client event (+0x70), builds the [resource requests](#resource-requests) from the source's streams (`sub_1000B5B8`) and calls `RmAcquireResources(count, requests, 1, GetCurrentProcessId(), client, client+0x34 (manager event), 4, 1, &pending, &client->rmHandle)`. If the request is granted at once (`pending` = 0), the completion is queued (`sub_1000C224`: `MFCreateAsyncResult(callback, callback, state)`, status `S_OK`, `MFPutWorkItemEx(MFASYNC_CALLBACK_QUEUE_MULTITHREADED)`); otherwise it comes from a resource manager notification ([manager thread](#manager-thread)). Then the manager calls media service method 18 with 0 if the source is local, 1 if not (only when it changes, kept at +0x6C), and `sub_100097D8`.
- kind 2, audio focus ? (`sub_1000BA64`): keeps `callback` / `state` in the second pair (+0x50 / +0x54). If the client has audio streams (+0x64), it asks the media service (method 4) and the answer comes from the service ([manager thread](#manager-thread)); otherwise the completion is queued at once with `S_OK` (`sub_1000C314`).
- other kinds: `E_UNEXPECTED`.

`MFMEPalEndAcquireResource(cookie, result)` (`sub_1000BE18`): `IMFAsyncResult::GetObject`; if it's the kind-1 callback it releases the pair +0x48/+0x4C, if it's the kind-2 callback the pair +0x50/+0x54, else `E_UNEXPECTED`. The HRESULT of the operation is left in the result for the caller.

`MFMEPalReleaseResource(cookie)` (`sub_1000966C` → `sub_1000BFA0`): `RmReleaseResources(client->rmHandle)`, sets the client event (+0x70), releases both callback pairs; then media service method 18 (0) if needed, and `sub_100097D8`.

`sub_100097D8` calls media service method 10 with TRUE if one of the clients has both video streams (+0x44) and a macroblock rate (+0x40), else FALSE (video playback active ?).

`MFMEPalEventNotify(cookie, event, value)` (`sub_10008E54`), media engine events forwarded to the media service method 8 (`Notify(code, cookie)`):

| Event | Action |
|-------|--------|
| 1 | `Notify(5, cookie)` |
| 9 | Method 18 (0) if set, then `Notify(2, cookie)` |
| 13 | Method 18 (0 if the client's source is local, else 1), then `Notify(1, cookie)` |
| 19 | Method 18 (0) if set, then `Notify(3, cookie)` |
| 17, 20 | `CreateSMTCAppInstance(&smtc)`, `QueryInterface({4A783B80-BED0-4417-B7CF-7F3B3D62F08C})`, then method 13 (event 17) or method 11 (event 20) with `value / 1000.0` (milliseconds → seconds; position / duration of the media transport controls ?) |
| other | ignored |

### Resource client object

0x78-byte object (`sub_1000AAC4`, initialised by `sub_1000AC34`), shared by the media engine and transcode managers. `QueryInterface` (`sub_1000AA10`) accepts `IUnknown`, `IMFAsyncCallback` and `{C7A4DCA1-F5F0-47B6-B92B-BF0106D25791}`.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable (`off_10001FD4`) |
| 0x04 | 4 | `IMFAsyncCallback` vtable (`off_10001FB8`); `Invoke` = `sub_1000AA80` (revocation) |
| 0x08 | 4 | Reference count |
| 0x0C | 4 | Cookie |
| 0x10 | 0x18 | Critical section |
| 0x28 | 4 | Engine callback for type 1, `QueryInterface({E250A985-5C91-49A6-ABF2-0FCDB5B80AAD})` on the registered callback |
| 0x2C | 4 | Engine callback for type 2, `{4F0E4EC1-6CC4-4D12-9995-7F996B709726}` |
| 0x30 | 4 | Resource manager handle (`RmAcquireResources`) |
| 0x34 | 4 | Notification event of the manager (+0x4C) |
| 0x38 | 4 | Audio stream count (request 23) |
| 0x3C | 4 | Audio stream count (request 22) |
| 0x40 | 4 | Video macroblocks per second (request 26) |
| 0x44 | 4 | Video stream count (request 24) |
| 0x48 | 8 | Kind-1 callback and state |
| 0x50 | 8 | Kind-2 callback and state |
| 0x58 | 4 | Type: 1 media engine, 2 transcode |
| 0x5C | 4 | Media service object (type 1) |
| 0x60 | 4 | Shut down |
| 0x64 | 4 | Has audio streams (type 1 only) |
| 0x68 | 4 | Local source (`MFMEDIASOURCE_DOES_NOT_USE_NETWORK`) |
| 0x6C | 4 | Kind-2 request sent to the media service |
| 0x70 | 4 | Manual-reset event, set when the resources are released |
| 0x74 | 4 | PSM registration |

At initialisation the client also registers for the app state changes: `PsmRegisterAppStateChangeNotification(sub_1000C760, 3, 0, client, …, &client->psm)`. The callback, for state 1 (suspending ?) while resources are held, waits up to 2 200 ms on the client event (+0x70), so that the engine can release them. The first client reads the decoder capacity from the [registry](#registry) (`sub_1000C830`).

Revocation: when `RmGetNotification` returns a notification of type 1, `sub_1000C404` queues the client itself (`MFPutWorkItem(5, &client->IMFAsyncCallback)`); its `Invoke` (`sub_1000C07C`) calls method 3 of the engine callback (+0x28 or +0x2C) with the cookie (release request), then media service method 5.

### Resource requests

`sub_1000B0EC` walks the presentation descriptor of the source (`CreatePresentationDescriptor`, selected streams only, `GetMediaTypeHandler`, `GetMajorType`, `GetCurrentMediaType`; `MFMediaType_Protected` types are unwrapped with `MFUnwrapMediaType`):
- audio stream (`MFMediaType_Audio`) of a type-1 client: increments both audio counts;
- video stream of a type-2 client: the macroblock rate is set to the maximum (`VideoProcessor`, [registry](#registry));
- other video stream: skipped if the subtype is an uncompressed format (`sub_1001023C`: the D3D formats 0x14–0x18, 0x29, `AI44`, `AYUV`, `YUY2`, `YVYU`, `YVU9`, `UYVY`, `NV11`, `NV12`, `YV12`, `I420`, `IYUV`, `Y210`, `Y216`, `Y410`, `Y416`, `Y41P`, `Y41T`, `Y42T`, `P210`, `P216`, `P010`, `P016`, `v210`, `v216`, `v410`); otherwise counts the stream and adds `ceil(width × height × frameRate / 256)` (macroblocks per second, `MF_MT_FRAME_SIZE`, `MF_MT_FRAME_RATE` or 30/1), capped by the maximum.

`sub_1000B5B8` turns the non-zero counts into an array of 16-byte requests (`sub_1000B558`, at most 8):

| Offset | Size | Value/Comment |
|--------|------|---------------|
| 0x00 | 4 | Resource type: 22, 23 (audio counts), 24 (video decoders), 26 (macroblocks per second) |
| 0x04 | 4 | Amount |
| 0x08 | 4 | 10 (priority ?) |
| 0x0C | 1 | 0 |
| 0x0D | 1 | 1 |

The capture manager uses the same format with priority 8: type 3 amount 0 flags 0x0100 (flag 1, microphone), type 4 amount 1 flags 0x0101 (flag 4, camera), type 26 amount = macroblocks per second flags 0x0100 (video encoder). Type 26 is thus the shared video processing capacity of the decoders and encoders.

### Manager thread

`sub_10009B7C` (media engine) waits forever on the stop event (+0x50), the resource manager event (+0x4C), the event +0x70 and, when the media service gave one, its named event (+0x58):
- stop: exits;
- resource manager event (`sub_1000980C`): for each client, `sub_1000C478` reads its notifications with `RmGetNotification(client->rmHandle, &notification)` until it returns 0x490 (none left): type 0 completes the pending kind-1 request (`sub_1000C224`), type 1 starts the [revocation](#resource-client-object);
- event +0x70: only re-reads the handles;
- media service event (`sub_10009918`): media service method 6; if it returns TRUE, every client gets the kind-2 completion with `S_OK` (`sub_1000C314`); otherwise method 7: a negative value is sent as completion status to every client (`sub_1000C67C`), a positive one starts the revocation of every client (`sub_1000C5BC`).

The transcode manager thread (`sub_1000D834`, created at the first registration by `sub_1000CE58`) only waits on its stop and resource manager events.

### Media service

`sub_100084B8`: `CreateMediaService(&manager->mediaService)`, method 3 returns the name of an event (`BSTR`), opened with `OpenEventW(SYNCHRONIZE, FALSE, name)` (+0x58); every client gets the service object (`sub_1000B004`, which also calls method 4 again for a client with a kind-2 request pending). Methods of the media service object used (interface unknown):

| Method | Use |
|--------|-----|
| 3 | Name of the event signalled on service changes |
| 4 | Kind-2 request of a client (audio focus ?) |
| 5 | Called when the manager stops and after a revocation |
| 6, 7 | State read by the manager thread (above) |
| 8 | `Notify(code, cookie)`: 1–3, 5 from `MFMEPalEventNotify`, 4 with cookie 0 when the manager stops |
| 10 | `BOOL`: a client plays video |
| 18 | `BOOL`: a client plays a network source |

The WNF watcher (`sub_1000F40C`, 0x28-byte object) subscribes to two `MS` states ([WNF states](#wnf-states)); its callback (`sub_1000F4F4`, 4-byte data) calls `sub_10009D00` with 1 for sequence 1 (reconnect: `sub_100084B8`) or 2 for sequence 2 (service lost: sets +0x70, releases the service object and its event, clears it in every client). So these states are probably the start / stop of the media service process ?

### Topology attributes

`MFMEPalUpdateTopologyAttributes[Ex]` (`sub_1000A888`):
1. `sub_1000A628`: source characteristics bit 0x80 (local), and whether the presentation has audio and video streams.
2. `sub_1000A33C`, topology attributes: audio only → `MF_TOPOLOGY_ENABLE_XVP` `{D2D362FD-4E4F-4191-A579-C618B66706AF}` = 0; with video → 1, unless `HKLM\Software\Microsoft\Zune\Playback\DisableHardwareMFTUse` is non-zero (then no attributes).
3. `sub_1000A4AC`, audio renderer attributes: if the creation attributes have `CODECAPI_AVLowLatencyMode` `{9C27891A-ED7A-40E1-88E8-B22727A024EE}` non-zero, sets `{AFB3C3A0-5EBA-482F-BBF2-85BBBB69DD2F}` = 1; else, without video, sets the UINT64 `{9901C02C-CAE5-472A-BAAD-B8171D048B0A}` to the offload buffer duration: `HKLM\Software\Microsoft\Zune\Playback\Audio\OffloadBufferSize` (ms) × 10 000, default 20 000 000 (2 s).
4. The third output is set to NULL.

`MFMEPalUpdateCreationInfo(flagsIn, attributes, &flagsOut, &newAttributes)` (`sub_1000880C`): copies the attributes (`MFCreateAttributes` + `CopyAllItems`), `flagsOut` = `flagsIn`, ORed with 1 when none of `{D988879B-67C9-4D92-BAA7-6EADD446039D}`, `{FCCAE4DC-0B7F-41C2-9F96-4659948ACDDC}`, `{6DEBD26F-6AB9-4D7E-B0EE-C61A73FFAD15}`, `{5066893C-8CF9-42BC-8B8A-472212E52726}` is present. The property store of attribute `{0AC0C497-B3C4-48C9-9CDE-BB8CA2442CA3}` (created with `PSCreateMemoryPropertyStore` if missing) gets the defaults: key `{3CB1F287-0505-4C5D-AE71-0A556344EFA1}`,0 = `VT_UI4` 2 and key `{FB023EDB-80BC-458D-9B46-878EAF1BF521}`,0 = `VT_BOOL` TRUE when they are empty, and key `{EDA8AFDF-C171-417F-8D17-2E0918303292}`,1 = `VT_BOOL` FALSE always.

`MFPalUpdateDecoderAttributes(type, topology, &attributes)` (`sub_10006AD8`), video types only:
1. Whether the content is protected (`sub_1000681C`): for each source node of the topology (`MF_TOPOLOGY_SOURCESTREAM_NODE`), the presentation descriptor (`MF_TOPONODE_PRESENTATION_DESCRIPTOR`) has a stream descriptor with `MF_SD_PROTECTED` `{00AF2181-BDC2-423C-ABCA-F503593BC121}`.
2. For each output node whose stream sink's media sink implements the private interface `{BCCD7224-1179-4F9A-8290-7F1DE5A2A549}` of [VideoSink.dll](./videosink.md#media-sink) / [VideoSink_RT.dll](./videosink_rt.md): creates the attributes (3 items) and sets `MF_SA_D3D11_SHARED_WITHOUT_MUTEX` `{39DBD44D-…}` = 1, `MF_SA_REQUIRED_SAMPLE_COUNT` `{18802C61-…}` = 7, `{4A4F1CB5-8F2E-4BA6-9C11-35961B969E88}` = 1 and, for protected content, `{8B4BB190-7D75-4A9B-A930-FF9A7AE1C8A1}` = 1. These are the decoder output attributes matching the sink's own.

### Protected output

- `MFMEPalCreateVideoOTA(callback, &ota)`: `MonitorFromWindow(NULL, MONITOR_DEFAULTTOPRIMARY)` (`E_UNEXPECTED` if none), then [VideoSinkOTA.dll](./videosinkota.md#mfvideosinkcreatevideoota-0x100049b8)`!MFVideoSinkCreateVideoOTA(0, monitor, callback, ota)`.
- `MFMEPalStartProtectedSession(session)` / `MFMEPalStopProtectedSession(session)`: [CompClient.dll](./compclient.md#sessions)`!StartProtectedSession(session)` / `StopProtectedSession(session)`.

### Transcode resources

The `MFTEPal*` exports are the media engine ones without the media service: `MFTEPalRegisterForResourceNotifications` (`sub_1000D0B0`) starts the transcode manager (`sub_1000CE58`) and creates a client of type 2 (no media service); `MFTEPalBeginAcquireResource` (`sub_1000D3EC` → `sub_1000BBB8`) builds the requests (video at the maximum rate) and calls `RmAcquireResources` like kind 1; `MFTEPalEndAcquireResource` (`sub_1000BE18`), `MFTEPalReleaseResource` (`sub_1000BFA0`) and `MFTEPalUnRegisterForResourceNotifications` (`sub_1000D29C`, stops the manager with the last client) behave as above.

### Capture resources

Capture manager (0x10013FCC): critical section, list of registration objects (+0x18), next cookie (+0x2C, starts at 1).

- `MFMCPalRegisterForResourceNotifications(callback, &cookie)`: `ERROR_ALREADY_REGISTERED` (0x800704DA) if the callback is already registered; else a registration object (`sub_1000E8EC`, `sub_1000DFF8`) holding the callback and the cookie, registered for the app states with `PsmRegisterAppStateChangeNotification(sub_1000E710, 1, 2, …)`: on state 1 (suspending ?) with resources held, the callback's method 3 is called with 4 (for WINDOWS.MEDIA.DLL, `ResourceManager::OnResourceDeparted`, which fails the capture with 0x80000013 and closes it).
- `MFMCPalAcquireResources(cookie, flags)`: for flags 4 (camera) and 1, if another registration already holds a resource of that type, it's shared (added to this registration's list, `sub_1000E648`); the remaining flags go to `sub_1000E4C0`: flag 4 first checks `PolicyManager_GetCameraPolicy_AllowCamera` (`E_ACCESSDENIED` 0x80070005 if the camera is forbidden), then requests type 4; flag 1 requests type 3; flag 2 asserts.
- Each request (`sub_1000E16C`) is synchronous: `RmAcquireResources(1, request, 1, pid, 0, event, 0, 1, &pending, &handle)` (failure → 0x80131509), wait up to 10 s on the event if pending, `RmGetNotification` (a non-zero type → 0x80080500); then a resource object (`sub_1000EB14`, keeps a duplicate of the handle) is added to the registration.
- `MFMCPalAcquireVideoEncoderResource(cookie, rate, &id)` requests type 26 with the rate; `id` = the rate, which `MFMCPalReleaseVideoEncoderResource(cookie, id)` uses to find the resource object.
- `MFMCPalReleaseResources` and `MFMCPalUnregisterForResourceNotifications` release the resource objects (`sub_1000ECAC`, `RmReleaseResources`).

### Background audio

`MFMCPalMuteBackgroundAudio` (`sub_1000FA0C(0xDFFFF)`): the byte 2 of the constant (13) indexes the table at 0x10001860 (`0, 4, 8, 9, 3, 10, 11, 12, 13, 2, 14, 15, 16, 17, 19, 20`), which gives audio category 17. `sub_1000FB68` creates a 0x240-byte object (interface `{53E42E39-A1A2-4D4B-B083-2F6CE396FC16}`, private) for data flow 0 (render) and that category:
1. `sub_100100D8`: `IMMDeviceEnumerator`, `QueryInterface({7CFAD5A6-6390-40B7-99CA-995BDCB733F6})`, its method 3 (flow, category) gives the default device of the category, `Activate(IID_IAudioClient2 {726778CD-F60A-4EDA-82DE-E47610CD78AA})`, `SetClientProperties` (0x14-byte structure: size 0x14, category at +0x10), `GetMixFormat`, `Initialize(shared, 0, 0, 0, format, NULL)`.
2. `sub_1000FDAC`: reads and subscribes to the WNF state of the category (table at 0x100137B8, 28-byte entries, one per category 0–21: `AUD` sequences 103–127, e.g. 105 = `WNF_AUD_CATEGORY_BACKGROUNDCAPABLEMEDIA`, 120 for category 17), 0x208 bytes. The callback (`sub_1000FD28`) compares the device id string (+0x08 for capture, +0x108 for render; flags at +0x00 / +0x04) with the previous one and, when it changes, recreates the audio client (`sub_1000FE4C`) and restarts it if it was started.
3. Method 3 of the private interface starts the stream (`IAudioClient::Start`, `sub_1000FC68`).

So muting is done by playing an (empty) stream of category 17, which makes the audio policy mute or pause the background audio. `MFMCPalResumeBackgroundAudio` calls method 4 (`IAudioClient::Stop`, `sub_1000FCAC`) and releases the object; it returns 1 (`S_FALSE`) if nothing was muted.

### Mobile country code

`MFMCPalGetMobileCountryCode(&mcc, &mnc)`, `E_POINTER` (0x80004003) if one is NULL:
1. `sub_10006ECC` queries the `CELL` state 0x0D8A0B2EA3BCA875 (0x1DC bytes: count at +0, entries of 0xEC bytes from +4). In the first entry whose flags (+0x08) have 0x100, the field flags (+0xD4) give the MCC (+0xDC, bit 2) and MNC (+0xE0, bit 4).
2. If no MCC was found (`ERROR_NOT_SUPPORTED`, 0x80070032), `sub_10006FC4` queries the `CELL` state 0x0D8A0B2EA3BCC075 (0x44 bytes: count at +0, 32-byte entries from +4) and takes the last entry: flags +0x04, MCC +0x0C (bit 2), MNC +0x10 (bit 4).

Both use `RtlQueryWnfStateData` with a copy callback (`sub_10006E98`). Registered / serving network ? The country code is used by the camera for its anti-flicker setting ([callers](#callers-in-windowsmediadll)).

### Network

`MFNetPalGetProxy(url, proxy, &length)` (`sub_1000EED0`): `GetPreferredConnectionDetails(url, 0, 0, host, 0x100, &port)`; an empty host gives `0xC00D2EED`. The result is `host` if it starts with `http://` or `https://`, else `http://` + host, followed by `:port` unless the port is 0 or 80 (`%s%s:%d`, `%s%s`, `%s:%d`), at most 0x10F characters. `length` is the buffer size on input (`E_INVALIDARG` if 0) and the length on output; with a NULL buffer only the length is returned.

`MFNetPalSetAppProdIDOnSocket(productId, socket)` (`sub_1000F15C`): `StringFromCLSID(productId)`, the user SID of the process token (`GetTokenInformation(TokenUser)`), serialized by `NduSerializeAppContextData` (`sub_1000F68C`), then `WSAIoctl(socket, 0x980000E7, buffer, size, …)` (vendor `IOC_IN` code 231, network data usage app context ?). Serialized context (on the process heap, at most 0x10000 bytes):

| Offset | Size | Value/Comment |
|--------|------|---------------|
| 0x00 | 4 | Total size |
| 0x04 | 4 | Data size (bytes; 4 for type 1) |
| 0x08 | 4 | Type: 0 string (used here, the product id `{…}`), 1 DWORD, 2 string |
| 0x0C | 4 | Type 1: the DWORD; else offset of the string from +0x0C |
| 0x10 | 4 | SID size |
| 0x14 | 4 | Offset of the SID from +0x14 |
| 0x18 | | String (UTF-16, NUL), then SID |

### Other exports

- `MFPalLegacyProcess`: TRUE if the process token has a package identity (`RtlQueryPackageIdentity`, the returned boolean set) and `ModernApiExtHost!ProductInfoFromPackageFullName` succeeds on its full name (a Windows Phone 8 / Silverlight app ?).
- `MFPalNeedGPUSyncEvent`: [VideoSinkOTA.dll](./videosinkota.md)`!VerifyApolloGenerationDisplayDriver(&isApollo)`, returns `isApollo`.
- `MFPalGetDeviceUniqueID`: jump to `WPCOREUTIL!GetDeviceUniqueID`.
- `MFPalUseMonitorsForOTA` returns 1; `MFNetPalUseProxyLocator`, `MFNetPalUseWinINetCaching` and `MFTEPalSupportSoftwareTranscoding` share one function returning 0.

### Callers in WINDOWS.MEDIA.DLL

`WINDOWS.MEDIA.DLL` (1 130 496 bytes, with public symbols) delay-loads `MFMCPalRegisterForResourceNotifications`, `MFMCPalUnregisterForResourceNotifications`, `MFMCPalAcquireResources`, `MFMCPalReleaseResources`, `MFMCPalAcquireVideoEncoderResource`, `MFMCPalReleaseVideoEncoderResource`, `MFMCPalGetMobileCountryCode` and `MFTEPalSupportSoftwareTranscoding` from `ext-ms-win-mf-pal-l1-1-0`. Only `MFMCPalGetMobileCountryCode` is checked first (`IsMFMCPalGetMobileCountryCodePresent`, `ApiSetQueryApiSetPresence`, result cached).

| Caller | Calls | Use |
|--------|-------|-----|
| `ResourceManager::RuntimeClassInitialize(MediaCaptureServer *, StreamingCaptureMode, bool)` (0x10063810) | `MFMCPalRegisterForResourceNotifications(this, &this->cookie)` (cookie at +0x10), `MFMCPalAcquireResources(cookie, flags & ~2)` | Flags from the capture mode: `Audio` (1) → 1, `Video` (2) → 6, `AudioAndVideo` → 7; flag 4 removed when the bool is false. The flags (with 2) are kept at +0x18. On failure: release and unregister |
| `ResourceManager::OnResourceDeparted(DWORD)` (0x100C315C, vtable method 3) | — | Callback of the registration: `MediaCaptureServer::NotifyFailed(0x80000013)` and `Close` |
| `ResourceManager::TryAcquirePartialEncoder(IMFMediaType *)` (0x1007EA40) | `MFMCPalAcquireVideoEncoderResource(cookie, rate, &this->encoderId)` (+0x14) | H.264 only (`MF_MT_SUBTYPE` = `MFVideoFormat_H264`): `rate = ceil(width × height × frameRate / 256)` from `MF_MT_FRAME_SIZE` / `MF_MT_FRAME_RATE` |
| `ResourceManager::_TryAcquireFullEncoder(IMFCaptureEngine *, UINT)` (0x10073570) | Release then acquire with the new rate | Same computation on the record sink's output type, when the rate changed; called by `NotifyRecordState` on the transitions 10 → 11 and 22 → 23 |
| `ResourceManager::NotifyRecordState` (0x1008767C), `ResourceManager::_Close` (0x1007EBA8) | `MFMCPalReleaseVideoEncoderResource(cookie, encoderId)`; `_Close` also `MFMCPalReleaseResources` and `MFMCPalUnregisterForResourceNotifications` | Record stopped (state 0) / capture closed |
| `MediaCaptureServer::_UpdateAntiFlickerSettings` (0x1008E408) | `MFMCPalGetMobileCountryCode(&mcc, &mnc)` | In WP8 quirk mode: KS property `PROPSETID_VIDCAP_CAMERACONTROL` `{C6E13370-30AC-11D0-A18C-00A0C9118956}` id 1030, `KSPROPERTY_TYPE_SET`, value = MCC (the driver chooses). Otherwise `_MapMobileCountryCodeToPowerLineFrequency(mcc, mnc)` and `PROPSETID_VIDCAP_VIDEOPROCAMP` property 13 (`KSPROPERTY_VIDEOPROCAMP_POWERLINE_FREQUENCY`, 50 / 60 Hz) |
| `VideoEffects::get_VideoStabilization` (0x1006A030), `CTranscoder::put_HardwareAccelerationEnabled` (0x100777F4) | `MFTEPalSupportSoftwareTranscoding()` | It returns 0 here, so both fail with `ERROR_NOT_SUPPORTED` (0x80070032): no `Windows.Media.VideoStabilizationEffect` and no way to turn off hardware transcoding |

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x0D8A0B2EA3BCA875 (`.text:0x10001B00`) | `CELL`, 21 | 0x1DC bytes: cell entries (MCC, MNC) | Queried by `MFMCPalGetMobileCountryCode` |
| 0x0D8A0B2EA3BCC075 (`.text:0x10001AF8`) | `CELL`, 24 | 0x44 bytes: up to 2 entries (MCC, MNC) | Queried, fallback |
| 0x41C61D20A3BC0875 (`.text:0x10002078`) | `MS`, 1 | 4 bytes | `NtQueryWnfStateData` then subscribed; media service available ? (reconnect) |
| 0x41C61D20A3BC1075 (`.text:0x10002070`) | `MS`, 2 | 4 bytes | Same; media service lost ? |
| 0x41821B2CA3BF3875 … 0x41821B2CA3BFF875 (table `.data:0x100137B8`) | `AUD`, 103–127 (22 states, one per audio category) | 0x208 bytes: +0 / +4 flags, +8 / +0x108 device id strings | The state of the category used by the [background audio](#background-audio) stream (category 17 → sequence 120) is queried and subscribed |

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\System\Multimedia\DeviceCapability\ResourceSettings` | `VideoProcessor` (DWORD) | Maximum video macroblocks per second of a request; default 243 000 (1080p at 30 fps) |
| `HKLM\Software\Microsoft\Zune\Playback` | `DisableHardwareMFTUse` (DWORD) | Non-zero: no `MF_TOPOLOGY_ENABLE_XVP` attribute for video |
| `HKLM\Software\Microsoft\Zune\Playback\Audio` | `OffloadBufferSize` (DWORD, ms) | Audio offload buffer duration, default 2 s |

### ETW

Provider `{70B36A56-9BFD-40AB-9282-CCF9E295D8CF}`, registered in `DllMain` (`McGenEventRegister`). The enable bits are in `dword_10013E80`:

| Event | Level | Keyword | Enable bit | Written when |
|-------|-------|---------|------------|--------------|
| 10000 | 4 | 0x200000 | 0x01 | Trace points and non-fatal failures (`sub_100071D4`: caller address, module name and PDB signature from the `RSDS` debug directory, data) |
| 10001 | 2 | 0x400000 | 0x02 | Failures (same function; the HRESULT as data) |
| 10–26 (13 with opcode 1, 15 with opcode 2 task 13) | 4 | 0x4 | 0x10 | Resource client life: init 10, destroy 11, request summary 12, begin acquire 13, acquired 14, end acquire 15, release 16, revoke 17, completion 18, revocation queued 19, notification 20, service change 21–22, 24, reset 23, PSM state 25, wait done 26 |
| 100, 200 | 4 | 0x4 | 0x10 | Media engine / transcode manager reset |
| 300–303, 306 | 4 | 0x2 | 0x20 | Capture: register 300, unregister 301, request 302, granted 303, release 306 |

The `NduSerializeAppContextData` traces (events 2002, 2012, 2013, channel 16, keyword 0x8000000000000001, flags `dword_100141B4`) are written with a NULL registration handle.
