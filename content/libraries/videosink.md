## VideoSink.dll

The Media Foundation video sink of Windows Phone 8.1: the renderer at the end of a video playback topology, which does not draw the frames itself but hands them over ALPC to the processes that display them.  
`VideoSink.dll` is an ATL COM in-process server (515 functions, no symbols except the PDB name `videosink.pdb`; error strings are the assertion texts of the source). It registers two classes: an activation object (`IMFActivate`) and the media sink itself (`IMFMediaSink`, one fixed `IMFStreamSink`). The stream sink allocates Direct3D 11 video samples (its own D3D11 device and DXGI device manager, `IMFVideoSampleAllocatorEx`) for the decoder upstream, and for every sample whose time has come sends a message with the shared surface to each client connected to an ALPC port that the sink creates ([ALPC broadcast server](#alpc-broadcast-server)); the clients return the samples and report dropped frames. While the presentation clock runs, it keeps a power dependency coordinator scenario active (`\PdcPort`, component 0x412, [PDC scenario](#pdc-scenario)). For protected content it creates an output trust authority with [VideoSinkOTA.dll](./videosinkota.md)`!MFVideoSinkCreateVideoOTA` and checks certificate chains against the Global Revocation List of PEAuth ([Protected content](#protected-content)).  
No documented binary loads it; the name of the SecRuntime transient object of its port, `MFMediaEngine\VideoSink.AlpcPort\Server`, says the client is the Media Foundation media engine (`MFMediaEngine.dll`, not analysed), which creates the sink through the activation object and gives it the port name in an attribute. Related binaries: [VideoSinkOTA.dll](./videosinkota.md) (the OTA) and [VideoSink_RT.dll](./videosink_rt.md) (the same sink as the WinRT class `Windows.Phone.Media.Capture.MediaCapturePreviewSink`), extracted with it.

Location on the phone: ? (extracted next to [VideoSinkOTA.dll](./videosinkota.md) and [VideoSink_RT.dll](./videosink_rt.md)).  

### Imports

| DLL | Functions |
|-----|-----------|
| MFPlat.DLL | `MFCreateAttributes`, `MFCreateMediaType`, `MFCreateEventQueue`, `MFCreateMediaEvent`, `MFCreateDXGIDeviceManager`, `MFCreateVideoSampleAllocatorEx`, `MFSerializeAttributesToStream`, `MFDeserializeAttributesFromStream` |
| d3d11.dll | `D3D11CreateDevice` |
| [VideoSinkOTA.dll](./videosinkota.md) (delay-load) | `MFVideoSinkCreateVideoOTA` |
| ext-ms-win-rtcore-ntuser-sysparams-l1-1-0.dll (delay-load) | `EnumDisplayMonitors` |
| ntdll.dll | `NtAlpcCreatePort`, `NtAlpcAcceptConnectPort`, `NtAlpcSendWaitReceivePort`, `NtAlpcCancelMessage`, `NtAlpcImpersonateClientOfPort`, `AlpcInitializeMessageAttribute`, `AlpcGetMessageAttribute`, `ZwAlpcConnectPort`, `ZwAlpcSendWaitReceivePort`, `ZwAlpcCancelMessage`, `ZwAlpcDisconnectPort`, `ZwAlpcQueryInformation`, `TpAllocAlpcCompletion`, `TpWaitForAlpcCompletion`, `TpReleaseAlpcCompletion`, `RtlWaitOnAddress`, `RtlWakeAddressAll`, `RtlInitUnicodeString`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlNtStatusToDosError`, `vDbgPrintEx`, `NtClose`, `ZwClose` |
| [SecRuntime.dll](./secruntime.md) | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor`, `BuildSecurityDescriptorForSharingAccess` |
| bcrypt.dll | `BCryptOpenAlgorithmProvider`, `BCryptCloseAlgorithmProvider`, `BCryptGetProperty`, `BCryptCreateHash`, `BCryptHashData`, `BCryptFinishHash`, `BCryptDestroyHash`, `BCryptImportKeyPair`, `BCryptDestroyKey`, `BCryptVerifySignature` |
| OLEAUT32.dll | `SysAllocString`, `SysAllocStringByteLen`, `SysFreeString`, `SysStringByteLen`, `VarUI4FromStr` |
| api-ms-win-core-com-l1-1-1.dll | `CoCreateInstance`, `CoCreateGuid`, `StringFromGUID2`, `PropVariantCopy`, `PropVariantClear`, `CoTaskMemAlloc`, `CoTaskMemRealloc`, `CoTaskMemFree` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey`, `RegCreateKeyExW`, `RegSetValueExW`, `RegDeleteValueW`, `RegEnumKeyExW`, `RegQueryInfoKeyW` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `ReadFile`, `GetFileSize` |
| api-ms-win-core-memory-l1-1-2.dll | `CreateFileMappingW`, `MapViewOfFile` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `GetCurrentThread`, `OpenThreadToken`, `GetCurrentThreadId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-security-base-l1-2-0.dll | `RevertToSelf` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `WaitForMultipleObjectsEx`, critical sections, SRW locks, `Sleep` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetTickCount` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `MulDiv` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `DisableThreadLibraryCalls`, `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleHandleExW`, `GetModuleFileNameW`, `GetModuleFileNameA`, `FindResourceExW`, `LoadResource`, `SizeofResource` |
| api-ms-win-core-heap-l1-2-0.dll, heap-obsolete | `GetProcessHeap`, `HeapAlloc`, `HeapFree`, `LocalAlloc`, `LocalFree` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-string-*.dll | `MultiByteToWideChar`, `CharNextW`, `lstrcmpiW` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `RtlRaiseException` |
| api-ms-win-core-debug-l1-1-1.dll | `OutputDebugStringA` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| msvcrt.dll | `malloc`, `free`, `realloc`, `operator new`/`delete`, `memcpy`, `memcpy_s`, `memmove`, `memset`, `memcmp`, `wcslen`, `wcsncmp`, `wcscpy_s`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, errorhandling, debug, `GetCurrentProcess` / `TerminateProcess` imports are the Visual C++ DLL CRT and `/GS` code. The registry functions other than `RegOpenKeyExW` / `RegQueryValueExW`, the resource functions, `CharNextW`, `VarUI4FromStr`, `LoadLibraryExW` / `GetProcAddress` and `CoCreateInstance` (`CLSID_StdGlobalInterfaceTable`) belong to the ATL module (registrar, `RegDeleteKeyExW` fallback, global interface table). The ntdll ALPC `Zw*` / `Tp*` functions and `RtlWaitOnAddress` / `RtlWakeAddressAll` are the PDC client library.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [VideoSinkOTA.dll](./videosinkota.md) | delay-load (`MFVideoSinkCreateVideoOTA`) | Output trust authority of the stream sink ([Protected content](#protected-content)) |
| ext-ms-win-rtcore-ntuser-sysparams-l1-1-0.dll | delay-load (`EnumDisplayMonitors`) | Monitors given to the OTA |
| advapi32.dll | `LoadLibraryExW` + `GetProcAddress("RegDeleteKeyExW")` | ATL registry helper, not used by the sink |
| `<DataPath>\Active.GRL` (`DataPath` value of `HKLM\System\CurrentControlSet\Services\PEAuth`) | `CreateFileW` (`GENERIC_READ`) | Global Revocation List, header `MSGRL` ([Protected content](#protected-content)) |
| ALPC port named by the attribute `{5E402C0D-…}` | `NtAlpcCreatePort` ([ALPC broadcast server](#alpc-broadcast-server)) | Video frames sent to the renderer clients |
| ALPC port `\PdcPort` | `ZwAlpcConnectPort` ([PDC scenario](#pdc-scenario)) | Power dependency coordinator, served by the kernel |
| Named events `{GUID}` (one per client) | `CreateEventW` | GPU synchronisation event of a client ([ALPC broadcast server](#alpc-broadcast-server)) |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x100076E4 | none; `S_OK` when the module lock count is 0 |
| 2 | `DllGetClassObject` | 0x10007704 | `REFCLSID`, `REFIID`, `void **` |

`DllGetClassObject` walks the ATL object map (0x10019048, 36-byte entries) and creates the class factory of the entry on first use (critical section of the module); an unknown CLSID returns `CLASS_E_CLASSNOTAVAILABLE` (`sub_10008610`). No `DllRegisterServer`: the classes are registered by the phone image.

| CLSID | Create function | Object | Interfaces |
|-------|-----------------|--------|------------|
| `{8E57905B-23B6-4D65-BEC4-28765069F46C}` | `sub_100078CC` → `sub_10007B3C` (no aggregation: `CLASS_E_NOAGGREGATION`) | Activation object, 0x30 bytes, vtable 0x100013F0 | `IMFActivate`, `IMFAttributes`, `IPersist`, `IPersistStream` (+8) |
| `{2D56A785-4085-4580-A677-A366A5FB8FFE}` | `sub_100078B4` → `sub_1000798C` (0x54 bytes) or, aggregated, `sub_10007A28` (0x60 bytes) | Media sink ([Media sink](#media-sink)) | `IMFMediaSink`, `IMFGetService` (+4), `IMFMediaSinkPreroll` (+8), `IMFClockStateSink` (+0xC), `IMFRateSupport` (+0x10), `{BCCD7224-1179-4F9A-8290-7F1DE5A2A549}` (+0x14), `{63DF056D-A8C7-4A2E-87FF-215DE332C21F}` (+0x18), `IQualProp` (+0x1C) |

### Startup

`DllEntryPoint` (0x10015E60): CRT and `/GS` cookie, then `DllMain` (`sub_1000762C`): on `DLL_PROCESS_ATTACH`, `DisableThreadLibraryCalls`, ETW registration (`McGenEventRegister`, [ETW](#etw)) and the ATL object map initialisation; on `DLL_PROCESS_DETACH`, ETW unregistration, release of the class factories and ATL module termination. Static constructors (`sub_100074F8`) fill the table of the three subtypes offered by the stream sink.

### Activation object

`sub_10007B3C` creates the object with an attribute store (`MFCreateAttributes`, 1) and sets `MF_SA_D3D11_AWARE` (`{206B4FC8-FCF9-4C51-AFE3-9764369E33A0}`) = 1.

- `ActivateObject` (`sub_1000BCAC`): creates the sink once (`CreateVideoSink`, `sub_1000B668`, with the activation's own `IMFAttributes`), keeps it at +0x2C and queries it for the requested interface.
- `ShutdownObject` (`sub_1000BD7C`): `IMFMediaSink::Shutdown` and release. `DetachObject` returns `E_NOTIMPL`.
- `IPersistStream`: `GetClassID` returns `{8E57905B-…}`, `Load` / `Save` are `MFDeserializeAttributesFromStream` / `MFSerializeAttributesToStream` of the attributes, `GetSizeMax` returns 0.

`CreateVideoSink` (`sub_1000B668`, disassembly only):

1. Creates the media sink (`sub_1000B964`).
2. `IMFAttributes::GetString({5E402C0D-D239-43FC-B2E4-B69DCA46CE63}, buf, 260)`: name of the ALPC port; required (the error is returned).
3. Calls method 4 of `{BCCD7224-…}` (`SetBroadcastPort`) with `L"MFMediaEngine\\VideoSink.AlpcPort\\Server"` and that name ([ALPC broadcast server](#alpc-broadcast-server)).
4. `GetUINT32({53C1211A-9901-4B22-AA8D-49FA6DB55109})`: if bit 0 is set, method 6 (`EnableOTA(0, TRUE)`) ([Protected content](#protected-content)).
5. Returns the sink's `IMFMediaSink`.

### Media sink

Constructor `sub_1000A810` (shared by the normal and aggregated objects), initialisation `sub_1000A880`: critical section (spin count 4000), the stream sink ([Stream sink](#stream-sink), `sub_1000B8D8`), its event queue (`MFCreateEventQueue`), and the PDC scenario client (`PdcScenarioClientRegister`, `sub_10018000`).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00…0x1C | 4 each | vtables of the 8 interfaces |
| 0x28 | 0x18 | Critical section |
| 0x40 | 4 | Stream sink |
| 0x44 | 4 | `IMFPresentationClock` |
| 0x48 | 1 | Shut down |
| 0x4C | 4 | PDC scenario client (component 0x412) |

`IMFMediaSink`:
- `GetCharacteristics` (`sub_1000AAC4`): 0x19 = `MEDIASINK_FIXED_STREAMS | MEDIASINK_CLOCK_REQUIRED | MEDIASINK_CAN_PREROLL`.
- `AddStreamSink` / `RemoveStreamSink`: `MF_E_STREAMSINKS_FIXED` (0xC00D4A3B). `GetStreamSinkCount`: 1. `GetStreamSinkByIndex(0)` / `GetStreamSinkById(0)` return the stream sink, other values `MF_E_INVALIDINDEX` (0xC00D36BF) / `MF_E_INVALIDSTREAMNUMBER` (0xC00D36B3).
- `SetPresentationClock` (`sub_1000AD20`): removes the sink from the old clock (`RemoveClockStateSink`), keeps the clock in the sink and the stream sink (+0x6C), and adds itself (`AddClockStateSink`). `GetPresentationClock`: `MF_E_NO_CLOCK` (0xC00D36D7) without clock.
- `Shutdown` (`sub_1000AED8`): `SetPresentationClock(NULL)`, shuts the stream sink down (`sub_1000C8AC`), sets the flag. Every method returns `MF_E_SHUTDOWN` (0xC00D3E85) afterwards.

`IMFMediaSinkPreroll::NotifyPreroll` (`sub_1000AF54`) goes to the stream sink (`sub_1000DA50`).  
`IMFClockStateSink` (`sub_1000AFC4`, `sub_1000B02C`, `sub_1000B08C`, `sub_1000B0EC`, `sub_1000B198`): `OnClockStart` / `OnClockRestart` activate the PDC scenario (once), `OnClockStop` / `OnClockPause` release it, then each calls the stream sink. `OnClockSetRate` stores the rate (stream +0x28) and queues `MEStreamSinkRateChanged` (304).  
`IMFGetService::GetService` (`sub_1000AA28`): `MF_RATE_CONTROL_SERVICE` → `IMFRateSupport`, `MR_VIDEO_RENDER_SERVICE` → `{63DF056D-…}`; anything else `E_NOINTERFACE`. `IMFRateSupport`: slowest rate 0, fastest rate `-FLT_MAX` / `FLT_MAX` (reverse / forward), every rate supported.  
`IQualProp`: `get_FramesDroppedInRenderer` = stream +0x264, `get_FramesDrawn` = stream +0x268 − +0x264, `get_AvgFrameRate` from the two clock times at stream +0x270 / +0x278 and the frame count; the other three `E_NOTIMPL`.

**`{BCCD7224-1179-4F9A-8290-7F1DE5A2A549}`** (private, 4 methods):

| Method | Function | Action |
|--------|----------|--------|
| 3 | `sub_1000B324` | Returns a copy (`BSTR`) of the port name (stream +0x25C) |
| 4 | `sub_1000B3A4` → `sub_1000E32C` | `SetBroadcastPort(securityName, portName)`: creates the ALPC server; a second call returns `E_UNEXPECTED` |
| 5 | `sub_1000B3E0` | Reset: releases the clock, allocator, device manager and device, resets the times, counters and rate, increments the generation (stream +0x5C) and recreates the event queue |
| 6 | `sub_1000B4D4` → `sub_1000EE1C` | `EnableOTA(arg, BOOL)`: stores the flag (stream +0x263) and, if set, creates the OTA |

**`{63DF056D-A8C7-4A2E-87FF-215DE332C21F}`** (private, 22 methods, given by `MR_VIDEO_RENDER_SERVICE`): method 4 (`sub_1000BF10`) returns the two DWORDs at stream +0x298 / +0x29C, method 5 (`sub_1000BFEC`) those at +0x290 / +0x294; both are video sizes computed by `sub_1000EFFC` when the media type is set (frame size, apertures and pixel aspect ratio with `MulDiv`; native and display size ?). The other methods return `E_NOTIMPL` or `S_OK` with 0.

### Stream sink

0x2A0-byte object (`sub_1000BA10`, initialised by `sub_1000C62C`). Interfaces: `IMFAttributes` (+0), `IMFStreamSink` / `IMFMediaEventGenerator` (+8), `IMFMediaTypeHandler` (+0xC), `IMFGetService` (+0x10), and `IMFTrustedOutput` (`{D19F8E95-B126-4446-890C-5DCB7AD71453}`), forwarded to the OTA object at +0x284.  
Attributes set at creation: `MF_SA_D3D11_SHARED_WITHOUT_MUTEX` (`{39DBD44D-…}`) = 1, `MF_SA_REQUIRED_SAMPLE_COUNT` = 7, `MF_SA_REQUIRED_SAMPLE_COUNT_PROGRESSIVE` (`{B172D58E-…}`) = 7. Then the AV sync marker object (`sub_10012870`, signature `kySV`): interval `HKLM\Software\Microsoft\Windows Media Foundation\AvSyncMarkerInterval` (DWORD, ms; default 5 s). Two lists of 30 sample items (+0x84, +0x170).

| Offset | Size | Comment |
|--------|------|---------|
| 0x08 | 4 | `IMFMediaEventGenerator` vtable (events queued with `QueueEventParamVar`) |
| 0x20 | 4 | Critical section of the media sink |
| 0x28 | 4 | Rate (float, 1.0) |
| 0x2C | 4 | State (5 = running ?) |
| 0x30 | 4 | 2 when scrubbing (rate 0 ?) |
| 0x50…0x58 | 4 each | Sample counters (ETW event 138) |
| 0x5C | 4 | Generation, starts at 1, incremented by each reset; sent to the clients |
| 0x60 | 4 | `MFCreateDXGIDeviceManager` reset token |
| 0x64 | 4 | Current `IMFMediaType` |
| 0x68 | 4 | `ID3D11Device` |
| 0x6C | 4 | `IMFPresentationClock` |
| 0x70 | 4 | `IMFMediaEventQueue` |
| 0x74 | 4 | `IMFVideoSampleAllocatorEx` |
| 0x78 | 4 | `IMFDXGIDeviceManager` |
| 0x7C | 4 | ALPC broadcast server ([ALPC broadcast server](#alpc-broadcast-server)) |
| 0x80 | 4 | AV sync marker object |
| 0x25C | 4 | Port name (`BSTR`) |
| 0x260 | 1 | Shut down |
| 0x263 | 1 | OTA enabled |
| 0x264 | 4 | Frames dropped by the clients (message 7) |
| 0x268 | 4 | Frames returned by the clients |
| 0x270, 0x278 | 8 each | Clock times of the first and the last returned frame |
| 0x280 | 4 | OTA object (from `MFVideoSinkCreateVideoOTA`) |
| 0x284 | 4 | Interface returned by the OTA (method 3), target of `IMFTrustedOutput` |
| 0x288 | 4 | Number of monitors last given to the OTA |
| 0x28C | 4 | OTA callback object ([Protected content](#protected-content)) |
| 0x290…0x29C | 4 each | Video sizes (`{63DF056D-…}` methods 4 and 5) |

`IMFMediaTypeHandler`:
- `GetMediaTypeCount`: 3. `GetMediaTypeByIndex(i)` (`sub_1000D4F0`): a new media type with `MF_MT_MAJOR_TYPE` = `MFMediaType_Video` and `MF_MT_SUBTYPE` = `MFVideoFormat_420O` (0), `MFVideoFormat_NV12` (1), `MFVideoFormat_RGB32` (2); `MF_E_NO_MORE_TYPES` beyond.
- `SetCurrentMediaType` (`sub_1000D5AC`): `IsMediaTypeSupported` or `MF_E_INVALIDMEDIATYPE` (0xC00D36B4); a change of an existing type queues `MEStreamSinkFormatChanged` (309). Then `sub_1000EFFC` computes the video sizes.

`IMFGetService::GetService` (`sub_1000D714`): `MR_VIDEO_ACCELERATION_SERVICE` → the DXGI device manager, created on first use by `sub_1000D7D8`; for `IMFVideoSampleAllocator` / `IMFVideoSampleAllocatorEx`, the allocator, created by `sub_1000D908`; any other request goes to the media sink.

- `sub_1000D7D8`: `D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, D3D11_CREATE_DEVICE_VIDEO_SUPPORT (0x800), {11_1, 11_0, 10_1, 10_0, 9_3, 9_2, 9_1}, 7, D3D11_SDK_VERSION, …)`, `ID3D10Multithread::SetMultithreadProtected(TRUE)`, `MFCreateDXGIDeviceManager` and `ResetDevice`.
- `sub_1000D908`: `MFCreateVideoSampleAllocatorEx(IID_IMFVideoSampleAllocatorEx)`, `InitializeSampleAllocatorEx(1, 7, attributes of the stream, current media type)`, `SetDirectXManager`.

`ProcessSample` (`sub_1000CCA0`, disassembly only): `MF_E_SHUTDOWN` after shutdown; it expects an outstanding sample request, wraps the sample in a sample item (`sub_1000FC88`: `IMFDXGIBuffer` → `ID3D11Texture2D` and subresource index, `IDXGIResource::GetSharedHandle`, frame size / apertures and pixel aspect ratio of the media type), and when the sink runs sends it to the clients (`sub_1000E9A4`); while scrubbing it queues `MEStreamSinkScrubSampleComplete` (308, `sub_1000ED70`). It also updates the monitors of the OTA (`sub_1000EF98`). `PlaceMarker` (`sub_1000D024`) and `Flush` (`sub_1000D1F0`) handle markers and the queued samples.

`SendSample` (`sub_1000E9A4`), only in state 5:
1. Converts the sample time into a presentation time (`sub_10010344`): (`IMFSample::GetSampleTime` − clock time from `GetCorrelatedTime`) / rate, added to the system time; also stored as a `GetTickCount` deadline.
2. Feeds the AV sync marker (`sub_100129FC`).
3. Broadcasts it (`sub_10010F74`, [ALPC broadcast server](#alpc-broadcast-server)), increments the counter +0x54; when scrubbing, queues event 308.

When a client returns a sample (message 6, `sub_1000E64C`), the item is freed once no client holds it, +0x268 is incremented and the clock time is recorded (+0x270 for the first frame, +0x278 for each); a sample with flag 0x8000 writes ETW event 146.

### ALPC broadcast server

`SetBroadcastPort` (`sub_1000E32C`) creates a 0x1C-byte broadcaster (`sub_100107E0`): two auto-reset events, the server port object (0x20 bytes, vtable 0x1000381C, `sub_10011B24`) and a listening thread (`sub_10010AE8`, started by `sub_10010A18`, which waits for the thread's ready event).

`sub_10011B24` (port creation):
1. `QueryTransientObjectSecurityDescriptor(8, L"MFMediaEngine\\VideoSink.AlpcPort\\Server", &sd)`: type 8 = `AlpcPort` ([SecRuntime](./secruntime.md)), error returned as NTSTATUS | 0x10000000.
2. `NtAlpcCreatePort(&port, {Length 0x18, ObjectName = name from the attribute, SecurityDescriptor = sd}, attributes)`: flags 0x60000, QoS length 12 `SecurityImpersonation` / dynamic tracking / effective only, `MaxMessageLength` 0x60.
3. A 0x60-byte message buffer and a message attribute buffer for `ALPC_MESSAGE_CONTEXT_ATTRIBUTE` (0x20000000).

The listening thread waits on its stop event and the port; each wake-up runs `ProcessMessages` (`sub_10011498`) under the media sink's critical section: `NtAlpcSendWaitReceivePort(port, 0x10000, reply, …)` until there is no message. Requests (1) and datagrams (3) go to `DispatchMessage` (`sub_1001060C`), a request getting a 0x28-byte reply with the HRESULT at +0x20. `LPC_CONNECTION_REQUEST` (10) is always accepted (`NtAlpcAcceptConnectPort`) and the connection is added to the client list (`OnConnect`, `sub_10011814`); `LPC_PORT_CLOSED` / `LPC_CLIENT_DIED` (5, 6) remove it (`OnClose`, `sub_1001194C`). Other types are cancelled if they wait for a reply.

Each message is a `PORT_MESSAGE` header (0x18 bytes) followed by a DWORD type at +0x18. The size is checked exactly:

| Type | Direction | Size | Content | Action |
|------|-----------|------|---------|--------|
| 0 | internal | 0x28 | +0x20 client port | Client gone (made by `OnClose`): its samples are returned (`sub_1000E64C` for all), its sync events closed. ETW 141 |
| 1 | internal | 0x28 | +0x20 client port | Client connected (made by `OnConnect`): if the sink runs, sends message 2, then re-sends the samples already broadcast (`sub_1000E48C`). ETW 140 |
| 2 | → clients | 0x28 | +0x20 generation, +0x24 OTA enabled (byte) | Stream start / reset (`sub_10010EC0`, sent to all clients by `sub_100112F4`) |
| 4 | → client | 0x60 | [Sample message](#sample-message) | A frame to show (`sub_10010F74`) |
| 5 | ← client | 0x20 | | Ignored |
| 6 | ← client | 0x30 | +0x20 shared handle, +0x24 subresource index (WORD), +0x28 generation, +0x2C byte (0: the client's sync event is closed) | Sample returned (`sub_10010C10` → `sub_1000E64C`); a stale generation is ignored; on error `MEError` is queued |
| 7 | ← client | 0x28 | +0x20 count | Frames dropped, added to +0x264. ETW 142 |
| 10 | ← client | 0x20 | | `sub_10010D80`: `NtAlpcImpersonateClientOfPort`, `OpenThreadToken(TOKEN_QUERY)`, `RevertToSelf`; the client's token is kept for its sync events |

A client is identified by the process and thread ids of the `PORT_MESSAGE` (`ClientId`). Each sample can be held by at most 3 clients.

#### Sample message

`sub_10010F74` sends the message to every client that has given its token (message 10), with `sub_10011708` → `sub_10011C7C` (`NtAlpcSendWaitReceivePort(clientPort, 0x10000, msg, NULL)` as a datagram; `STATUS_PORT_DISCONNECTED` (0xC0000037) is ignored).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 0x18 | `PORT_MESSAGE`: `DataLength` 0x48, `TotalLength` 0x60 |
| 0x18 | 4 | 4 |
| 0x20 | 4 | Shared handle of the texture (`IDXGIResource::GetSharedHandle`) ? |
| 0x24 | 16 | GUID naming the client's sync event, `GUID_NULL` when the sample has no GPU synchronisation |
| 0x34 | 4 | `GetTickCount` deadline |
| 0x38 | 8 | Presentation time (system time, 100 ns) |
| 0x40 | 4 | Width of the video area |
| 0x44 | 4 | Height of the video area |
| 0x48 | 4 | Generation (stream +0x5C) |
| 0x4C | 2 | Subresource index of the texture (`MAX_SUBINDEX_TEXTURE`) |
| 0x50 | 4 | Value from the interface `{1103D32E-9997-4FF6-AE5C-BBEFDF9F478C}` of the sample ? |
| 0x54 | 4 | Pixel aspect ratio numerator |
| 0x58 | 4 | Pixel aspect ratio denominator |

Before the first send of a sample to a client (`sub_10010154`), the sink makes the client's GPU sync event if needed (`sub_10012558`): `CoCreateGuid`, `StringFromGUID2`, `BuildSecurityDescriptorForSharingAccess(clientToken, 0, SYNCHRONIZE)`, `CreateEventW(sd, FALSE, FALSE, L"{GUID}")`; the event is recorded with the client and the GUID goes into the message, so that the client opens it by name. The event is then passed to the sample's GPU synchronisation (method 16 of the object at item +0x50 ?).

### PDC scenario

The media sink is a "scenario client" of the power dependency coordinator, the same code as `PdcScenarioClientRegister` / `PdcScenarioClientRequest` / `PdcScenarioClientUnregister` in [DWMCORE.DLL](./dwmcore.md#pdc-scenarios) (here in the `PAGE` section: `sub_10018000`, `sub_10018068`, `sub_100180E8`):

- Register: 32-byte object, signature `Pdcs` (0x73636450), component 0x412. `PdcPortOpen` (`sub_10013394`): port object `PdcP` / `PDCt`, `ZwAlpcConnectPort(L"\\PdcPort", attributes flags 0x20000, max message 0x30, connect flags 0xA0000)` with a register message (component 0x412, client type 5), then `TpAllocAlpcCompletion` with `sub_10013630` (errors printed by `PdcpAlpcProcessMessage` / `PdcpProcessMessageInternal`).
- Request (`sub_10018068`): reference count; the first activation and the last release send message type 8 with byte +0x20 = 1 / 0.

`OnClockStart` / `OnClockRestart` take the reference, `OnClockStop` / `OnClockPause` release it, the sink's destruction unregisters. So component 0x412 is active while a video plays. Its effect is decided by the kernel PDC (not analysed); see the other components in [DWMCORE.DLL](./dwmcore.md#pdc-scenarios) and [wppower.sys](../drivers/wppower.md#pdc-clients).

### Protected content

`EnableOTA(arg, TRUE)` (`sub_1000EE1C`):
1. Creates the OTA callback object (`sub_1000F5F8`, 0x20 bytes, vtable 0x10002D00) linked to the stream sink, and queries its interface `{D66C7B93-78A6-4E6C-8B63-FFB52E83CFA4}`.
2. Lists the monitors (`EnumDisplayMonitors`, callback `sub_1000EDF8`, at most 3); none → `E_UNEXPECTED`.
3. `MFVideoSinkCreateVideoOTA(arg, firstMonitor, callback, &stream->ota)` in [VideoSinkOTA.dll](./videosinkota.md) (`arg` is unused there), then OTA method 3 with the stream's event generator (+0x08), which returns the interface kept at +0x284 (for the [Apollo OTA](./videosinkota.md#apollo-ota), its own `IUnknown`; the event generator is ignored).
4. `sub_1000EF98` gives the OTA the first monitor again (method 9) when the number of monitors changes; it is also called from `ProcessSample`.

The callback interface `{D66C7B93-…}` (methods 3…11, all under the media sink lock and failing with `MF_E_SHUTDOWN` once the sink is shut down):

| Method | Function | Action |
|--------|----------|--------|
| 3 | `sub_10011F34` | Forwards an `IMFMediaEvent` of the OTA (type, status) to the stream sink's event queue. ETW 148 |
| 4 | `sub_1001203C` | Returns 0 |
| 5 | `sub_1001206C` | Returns 0 |
| 6 | `sub_100121B4` | `E_UNEXPECTED` |
| 7 | `sub_10012154` | Certificate check (below) |
| 8, 9 | `sub_10011EC0`, `sub_10011F18` | Lock / unlock the media sink's critical section |
| 10 | `sub_100120DC` | Stores a flag (+0x11) |
| 11 | `sub_10012214` | Returns 1 |

Method 7 calls `sub_10012B74(certificate data, size, …, "1.3.6.1.4.1.311.10.5.8")`:
1. Loads the GRL (`sub_10012C78`): path from `HKLM\System\CurrentControlSet\Services\PEAuth`, value `DataPath`, + `\Active.GRL`; `CreateFileW`, header `MSGRL` and version checks, the revocation tables read with `ReadFile`, then the GRL signature is verified (`sub_100131E8`). Failure: 0xC00D715F.
2. Parses the certificate chain (`sub_100148C4`) and verifies it (`sub_10013A50`: RSA signatures with `BCryptImportKeyPair(RSAPUBLICBLOB)` / `BCryptVerifySignature`, hashes SHA1 / SHA256 / SHA384 / SHA512 through the "Microsoft Primitive Provider") up to one of the Microsoft roots embedded in `.text` ("Microsoft Root Authority", "Microsoft Root Certificate Authority 2010", "Microsoft Code Verification Root", "Microsoft Test Root Authority", "Microsoft Testing Root Certificate Authority 2010", "MS Protected Media Test Root", "Microsoft Digital Media Authority 2005", …).
3. Requires the usage OID `1.3.6.1.4.1.311.10.5.8` (a second OID, `1.3.6.1.4.1.311.10.5.4`, is used inside the chain check) and checks the certificates against the revocation list (`sub_10013038`, SHA-1 of the certificate); revoked: 0xC00D715C.

[VideoSinkOTA.dll](./videosinkota.md#mfvideosinkcreatevideoota-0x100049b8) gives one of two OTAs: the media engine OTA of `MFSVR.DLL` (`MFCreateMediaEngineVideoOTA`, which receives the callback; not analysed, so what it asks to check is unknown) when the monitor has OPM outputs, or, on an "Apollo generation" display driver without OPM, its own OTA, which allows every action, never calls the callback and holds a [CompClient](./compclient.md#sessions) protected session.

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\Software\Microsoft\Windows Media Foundation` | `AvSyncMarkerInterval` (DWORD, ms) | Interval of the AV sync markers, default 5000 |
| `HKLM\System\CurrentControlSet\Services\PEAuth` | `DataPath` | Folder of `Active.GRL` (also read by [ci.dll](./ci.md#protected-environment-peauth)) |

### ETW

Provider `{B34B0123-EB9D-411A-8F1E-9C5EF8577109}`, registered by `DllMain` (`McGenEventRegister`, enable callback `ETW_EnableCallback`, flags in `dword_10019480`).

| Event | Level | Task | Keyword | Enable bit | Written when |
|-------|-------|------|---------|------------|--------------|
| 10001 | 2 | 10000 | 0x400000 | 0x2 | Every failed check / HRESULT (`sub_10008828` with the assertion text or the error), in almost every function |
| 10002 | 3 | 10000 | 0x100000 | 0x4 | Warnings: `GetStreamSinkByIndex` with a bad index, stale sample generation, `ProcessSample`, sample item creation |
| 10000 | 4 | 10000 | 0x200000 | 0x1 | Information traces (activation, thread exit, timings) |
| 100…149 | 4 | 1…50 | 0x2 | 0x10 | State traces, one per method: 100 `SetPresentationClock`, 101 unsupported service, 106 `Shutdown`, 107 `NotifyPreroll`, 110 sink created, 116 / 149 `ProcessSample`, 123 `OnClockRestart`, 124 `OnClockSetRate`, 131 stream sink created, 135 `SetCurrentMediaType`, 136 stream `GetService`, 138 sample counters, 139 broadcast port set, 140 client connected, 141 client gone, 142 dropped frames, 145 allocator created, 146 sync marker sample, 148 OTA event, … |
