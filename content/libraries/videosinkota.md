## VideoSinkOTA.dll

The output trust authority (OTA) factory of the Windows Phone 8.1 Media Foundation video sink: it gives [VideoSink.dll](./videosink.md#protected-content) the object that the protected media path asks before sending protected video to the sink.  
`VideoSinkOTA.dll` is a small DLL (147 functions, no symbols except the PDB name `videosinkota.pdb`; most of the code is ATL and CRT). Its only real export, `MFVideoSinkCreateVideoOTA`, chooses between two OTAs for the monitor given by the sink: when the display has OPM outputs (`DXVA2!OPMGetVideoOutputsFromHMONITOR`), or when the OPM API isn't there, it delegates to the full Media Foundation OTA of the media engine (`MFSVR.DLL!MFCreateMediaEngineVideoOTA`); when OPM fails, it checks that the display driver is an "Apollo generation" driver (Windows Phone 8, a capability bit of the Direct3D 11 device) and returns its own minimal OTA, which allows every action and only holds a protected session of the compositor ([CompClient.dll](./compclient.md#sessions) `StartProtectedSession`) for its lifetime. A second export, `VerifyApolloGenerationDisplayDriver`, gives the driver check alone.  
Loaded by [VideoSink.dll](./videosink.md) (delay-load import of `MFVideoSinkCreateVideoOTA`, called by `EnableOTA`); also delay-loaded by [MFPalWP.dll](./mfpalwp.md), which calls `MFVideoSinkCreateVideoOTA(0, primaryMonitor, callback, ota)` in [`MFMEPalCreateVideoOTA`](./mfpalwp.md#protected-output) and `VerifyApolloGenerationDisplayDriver` in [`MFPalNeedGPUSyncEvent`](./mfpalwp.md#other-exports). Not imported by [VideoSink_RT.dll](./videosink_rt.md), which has no OTA.

Location on the phone: ? (extracted next to [VideoSink.dll](./videosink.md) and [VideoSink_RT.dll](./videosink_rt.md)).  

### Imports

| DLL | Functions |
|-----|-----------|
| d3d11.dll | `D3D11CreateDevice` |
| dxgi.dll (delay-load) | `CreateDXGIFactory` |
| [CompClient.dll](./compclient.md) (delay-load) | `StartProtectedSession`, `StopProtectedSession` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `DisableThreadLibraryCalls`, `GetModuleHandleW`, `GetModuleHandleExW`, `GetModuleFileNameW`, `GetModuleFileNameA`, `FindResourceExW`, `LoadResource`, `SizeofResource` |
| api-ms-win-core-com-l1-1-1.dll | `CoCreateInstance`, `CoTaskMemAlloc`, `CoTaskMemRealloc`, `CoTaskMemFree` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegSetValueExW`, `RegDeleteValueW`, `RegEnumKeyExW`, `RegQueryInfoKeyW`, `RegCloseKey` |
| OLEAUT32.dll | `VarUI4FromStr` |
| api-ms-win-core-string-*.dll | `MultiByteToWideChar`, `CharNextW`, `lstrcmpiW` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`, `Sleep` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-debug-l1-1-1.dll | `OutputDebugStringA` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| msvcrt.dll | `malloc`, `free`, `realloc`, `operator new`/`delete`, `memset`, `memcpy_s`, `strcpy_s`, `wcsncpy_s`, `strlen`, `wcslen`, `strrchr`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, errorhandling, debug, `GetCurrentProcess` / `TerminateProcess` imports are the Visual C++ DLL CRT and `/GS` code. The registry, resource, `CharNextW`, `lstrcmpiW`, `VarUI4FromStr` and `CoCreateInstance` imports belong to the ATL module (registrar strings `HKCR`, `ForceRemove`, …, global interface table), which the DLL doesn't use: it has no COM class and no `DllRegisterServer`. `GetModuleHandleExW` / `GetModuleFileNameA` serve the error events ([ETW](#etw)).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `DXVA2.DLL` | `LoadLibraryExW(L"DXVA2.DLL", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32)`, `GetProcAddress("OPMGetVideoOutputsFromHMONITOR")` | Does the monitor have OPM video outputs ([MFVideoSinkCreateVideoOTA](#mfvideosinkcreatevideoota-0x100049b8)) |
| `MFSVR.DLL` | `LoadLibraryExW(L"MFSVR.DLL", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32)`, `GetProcAddress("MFCreateMediaEngineVideoOTA")` | Full OTA of the media engine (not analysed) |
| dxgi.dll | delay-load (`CreateDXGIFactory`) | First adapter, for the driver check |
| [CompClient.dll](./compclient.md) | delay-load (`StartProtectedSession`, `StopProtectedSession`) | Protected session of the compositor held by the Apollo OTA |
| advapi32.dll | `LoadLibraryExW` + `GetProcAddress("RegDeleteKeyExW")` | ATL registry helper, not used |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllMain` | 0x10002430 | `HINSTANCE`, `DWORD reason`, `void *` (exported by name, also the CRT's `DllMain`) |
| 2 | `MFVideoSinkCreateVideoOTA` | 0x100049B8 | `arg` (unused), `HMONITOR monitor`, `IUnknown *callback`, `IUnknown **ota`; returns an HRESULT |
| 3 | `VerifyApolloGenerationDisplayDriver` | 0x100049C8 | `BOOL *isApollo`; `E_INVALIDARG` (0x80070057) if NULL, else `S_OK` |

`MFVideoSinkCreateVideoOTA` is a jump to `sub_10004810`. VideoSink.dll calls it as `MFVideoSinkCreateVideoOTA(arg, firstMonitor, callback, &stream->ota)` with `arg` = 0 (from `CreateVideoSink`) and the callback object of interface `{D66C7B93-78A6-4E6C-8B63-FFB52E83CFA4}`.

### Startup

`DllEntryPoint` (0x10005780): CRT and `/GS` cookie, `dllmain_dispatch`, then `DllMain` (0x10002430): on `DLL_PROCESS_ATTACH`, `DisableThreadLibraryCalls`, ETW registration (`McGenEventRegister`, [ETW](#etw)) and the ATL object map initialisation (empty); on `DLL_PROCESS_DETACH`, ETW unregistration and ATL module termination. Static constructors (`sub_100022F4`, `sub_1000237C`, `sub_100023CC`) build the ATL module objects; the ATL module's lock count is taken by each OTA object.

### MFVideoSinkCreateVideoOTA (0x100049B8)

`sub_10004810`:

1. `LoadLibraryExW(L"DXVA2.DLL", NULL, 0x800)` and `GetProcAddress("OPMGetVideoOutputsFromHMONITOR")`. If either fails, go to step 3.
2. `OPMGetVideoOutputsFromHMONITOR(monitor, OPM_VOS_OPM_SEMANTICS (1), &count, &outputs)`:
   - success: releases every `IOPMVideoOutput` and frees the array (`CoTaskMemFree`), then step 3;
   - failure: the display has no OPM outputs; if the driver check ([below](#apollo-driver-check)) is false, returns `E_UNEXPECTED` (0x8000FFFF); else ETW event 100 and the [Apollo OTA](#apollo-ota) is created (`sub_10004BF4`) and queried for `{24E65A24-042D-457A-B25E-BEE6877CED74}` into `*ota`.
3. ETW event 101, `LoadLibraryExW(L"MFSVR.DLL", NULL, 0x800)`, `GetProcAddress("MFCreateMediaEngineVideoOTA")` and `MFCreateMediaEngineVideoOTA(callback, 0, ota)`; its HRESULT is returned. `MFSVR.DLL` or the function missing: `E_UNEXPECTED`.

So the callback of the sink is only used by the media engine OTA. `DXVA2.DLL` and `MFSVR.DLL` are never freed. Which branch is taken on the Lumia 520 isn't known (if the phone has no OPM, the Apollo OTA ?).

### Apollo driver check

`sub_100046A4`, also the body of `VerifyApolloGenerationDisplayDriver`:

1. `CreateDXGIFactory(IID_IDXGIFactory {7B7166EC-21C7-44AE-B21A-C9AE321AE369})`, `IDXGIFactory::EnumAdapters(0)`.
2. `D3D11CreateDevice(adapter, D3D_DRIVER_TYPE_UNKNOWN, NULL, 0, NULL, 0, D3D11_SDK_VERSION (7), &device, &featureLevel, &context)`.
3. `QueryInterface({07F857E7-077F-4119-86B9-E7AE7104CF33})` on the device (a private interface ?) and its method 11 (vtable +0x2C, no argument): the result is TRUE when bit 1 (0x2) of the returned value is set.

Every failure gives FALSE (ETW 10001 with the HRESULT). The objects are released before returning.

### Apollo OTA

0x18-byte C++ object created by `sub_10004BF4` (destructor `sub_10004A1C`, deleting destructor `sub_10004BD0` at slot 12 of the main vtable), with an interlocked reference count; QueryInterface (`sub_10004B0C`) uses the table at 0x10001720:

| IID | Offset | Interface |
|-----|--------|-----------|
| `{00000000-0000-0000-C000-000000000046}` | 0x00 | `IUnknown` |
| `{24E65A24-042D-457A-B25E-BEE6877CED74}` | 0x00 | Private OTA interface used by VideoSink.dll (vtable 0x100016A8) |
| `{D19F8E94-B126-4446-890C-5DCB7AD71453}` | 0x04 | `IMFOutputTrustAuthority` (vtable 0x10001694) |
| `{D19F8E95-B126-4446-890C-5DCB7AD71453}` | 0x08 | `IMFTrustedOutput` (vtable 0x1000167C) |

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `{24E65A24-…}` vtable |
| 0x04 | 4 | `IMFOutputTrustAuthority` vtable |
| 0x08 | 4 | `IMFTrustedOutput` vtable |
| 0x0C | 4 | Reference count (0xC0000001 written by the destructor) |
| 0x10 | 4 | ? (0) |
| 0x14 | 4 | Compositor session (`ICompositorAlpcClient *`) from `CompClient!StartProtectedSession` |

Creation: `operator new(0x18)`, lock of the ATL module, `StartProtectedSession(&obj->session)`; a failure deletes the object and is returned. The destructor calls `StopProtectedSession(session)` if there is one and unlocks the module. So the compositor treats the client as protected ([CompClient request 15 `SetProtectedStatus`](./compclient.md#sessions)) as long as the sink keeps its OTA.

Methods:
- `{24E65A24-…}` (9 methods): 3 (`sub_10004278`) returns the object's `IUnknown` in its first argument (`E_POINTER` if NULL), the second argument is ignored; 7 (`sub_10004304`) writes 0 to its argument; 4, 5, 6, 8, 9, 10, 11 return `S_OK` (`unknown_libname_3`). VideoSink.dll calls method 3 with `(&stream->+0x284, stream event generator)` and keeps the returned pointer as its `IMFTrustedOutput` target, and method 9 with the first monitor when the monitor count changes (ignored here).
- `IMFOutputTrustAuthority`: `GetAction` (`sub_10004350`) returns 1 (`PEACTION_PLAY`), `SetPolicy` returns `S_OK` without looking at the policies.
- `IMFTrustedOutput`: `GetOutputTrustAuthorityCount` = 1, `GetOutputTrustAuthorityByIndex` (`sub_1000439C`): index 0 → `QueryInterface(IID_IMFOutputTrustAuthority)`, other index `E_INVALIDARG`, `IsFinal` = TRUE.

This OTA enforces nothing itself: it accepts every policy and never calls the sink's callback, so the certificate check of VideoSink.dll ([callback method 7](./videosink.md#protected-content)) is only reached through the media engine OTA. The content protection on this path is the compositor's protected session.

### ETW

Provider `{A13ABC63-C22D-49E7-8D35-7EBAA2309E73}`, registered by `DllMain` (`McGenEventRegister`, enable callback `ETW_EnableCallback` 0x10002510, enable bits in `dword_10007380`).

| Event | Level | Task | Keyword | Enable bit | Written when |
|-------|-------|------|---------|------------|--------------|
| 10001 | 2 | 10000 | 0x400000 | 0x2 | Every failed HRESULT (`sub_10004558`): return address ?, marker 0xDEC00002, image size, PDB GUID and age (RSDS debug entry, read once by `sub_1000443C`), module file name, then the HRESULT |
| 100 | 4 | 100 | 0x2 | 0x10 | The Apollo OTA is created |
| 101 | 4 | 101 | 0x2 | 0x10 | The media engine OTA is used |
