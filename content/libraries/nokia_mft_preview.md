## nokia_mft_preview.dll

Media Foundation transform of the Nokia camera stack that watches the preview stream: it tracks the faces and measures the amount of motion in the scene, and sends both to the camera driver.  
`nokia_mft_preview.dll` is an in-process COM server (488 448 bytes, 386 functions) registered as the MFT "Nokia FaceTracker et AMBR MFT" (CLSID `{5CF675C1-59F1-4B50-932D-10B64A8D6ED0}`). The MFT has one NV12 input and one output, and it gives back each input sample unchanged ([pass-through](#processinput--processoutput)). On the side, it copies the frames out of their Direct3D 11 textures, scales them down, and gives them to two worker threads: a face tracker, the ArcSoft "FT 3.1.3000.7" library (05/13/2011, "Copyright (C) 2011, Arcsoft Inc."), which is linked in and takes most of the binary (the `.rdata` section is 0x55000 bytes, mostly its model data), and a block-based [motion detector](#motion-detector) (`motionedetector.cpp`), the "AMBR" of the name (anti motion blur ?). The results go to the driver as properties of a camera control interface that the host puts in the MFT attributes (`{665F66E6-815B-472A-B1ED-D2D5B726142F}`, see [Camera control properties](#camera-control-properties)): face rectangles for the 3A (focus and exposure on the faces ?), and a motion value.  
It's part of the same Nokia camera build as the camera drivers and [QCJpegEncoderMFT.dll](./qcjpegencodermft.md) (PDB path `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\MFT\fre\nokia_mft_preview.pdb`). The process that loads it (the camera pipeline / capture engine) and the driver side of the properties aren't known: the GUIDs don't appear in the camera driver pages ([qccamavs8930.sys](../drivers/qccamavs8930.md) and the others). The sibling [nokia_mft_still.dll](./nokia_mft_still.md) is the still capture MFT (red-eye removal, noise reduction, vibrance).

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| MFPlat.dll | `MFTRegister`, `MFTUnregister`, `MFCreateMediaType`, `MFCreateAttributes` |
| PROPSYS.dll | `InitPropVariantFromBuffer`, `PropVariantToUInt32`, `PropVariantGetUInt32Elem` |
| api-ms-win-core-com-l1-1-0.dll | `CoTaskMemAlloc`, `CoTaskMemFree`, `PropVariantClear`, `StringFromGUID2` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCreateKeyExW`, `RegSetValueExW`, `RegCloseKey`, `RegDeleteTreeW` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `WaitForMultipleObjectsEx`, `InitializeCriticalSectionAndSpinCount`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-processthreads-l1-1-1.dll | `CreateThread`, `TerminateThread`, `SetThreadPriority`, `GetThreadIdealProcessorEx`, `SetThreadIdealProcessorEx`, `GetCurrentThreadId`, `IsProcessorFeaturePresent` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-libraryloader-l1-1-1.dll | `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-errorhandling-l1-1-1.dll | `GetLastError` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter` |
| api-ms-win-core-sysinfo-l1-2-0.dll | `GetSystemTimeAsFileTime`, `GetTickCount64` |
| MSVCR110.dll | `clock`, `malloc`, `free`, `memcpy`, `memset`, `memcmp`, `_vsnwprintf`, `_wassert`, `operator new`/`delete`, `_initterm`, `_onexit`, `__dllonexit`, … |

The util, profile, sysinfo, `GetCurrentThreadId`, `IsProcessorFeaturePresent` imports and most of MSVCR110 are the Visual C++ 2012 DLL CRT startup and `/GS` security cookie code. Direct3D 11 and DXGI aren't imported: their objects come from the Media Foundation D3D manager given by the host.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x100011FC | none |
| 2 | `DllGetClassObject` | 0x100012E0 | `REFCLSID, REFIID, void **` |
| 3 | `DllRegisterServer` | 0x1000121C | none |
| 4 | `DllUnregisterServer` | 0x100012B4 | none |

The four exports of a COM server. A global counter (`dword_10077234`) counts the MFT objects; `DllCanUnloadNow` returns `S_FALSE` while it isn't 0.

`DllGetClassObject` returns `CLASS_E_CLASSNOTAVAILABLE` (0x80040111) for any CLSID other than `{5CF675C1-59F1-4B50-932D-10B64A8D6ED0}`; otherwise it creates a class factory (12 bytes, vtable `off_100222E8`, the creation function `sub_10002174` at +8) and queries it (if `operator new` fails it returns `S_OK` without object). The factory accepts `IUnknown` and `IClassFactory`; `CreateInstance` (`sub_100010C4`) accepts an outer object only when `IUnknown` is requested (it isn't used), and `sub_10002174` allocates the [MFT](#mft-object) (`CoTaskMemAlloc(0xC4)`, constructor `sub_100021F4`), initialises it (`sub_10002414`) and queries the requested interface.

### Startup

`start` (`_DllMainCRTStartup`, 0x10020CC0): the usual CRT startup with `__security_init_cookie`. `DllMain` (`sub_100011C8`) saves the module handle (`dword_10077230`) and calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH`. There's no ETW / WPP registration and no trace output.

### Registry

`DllRegisterServer` asserts that the module handle is set (`_wassert` "g_hModule != NULL", `..\..\CommonHeaders\MFTs\COMDllRegistration.cpp` line 130), writes 3 `REG_SZ` values (`sub_10001350`, `sub_1000158C`) under `HKEY_CLASSES_ROOT`, then calls `MFTRegister`:

| Key | Value | Data |
|-----|-------|------|
| `CLSID\{5CF675C1-59F1-4B50-932D-10B64A8D6ED0}` | (default) | `Nokia FaceTracker et AMBR MFT` |
| `CLSID\{5CF675C1-59F1-4B50-932D-10B64A8D6ED0}\InprocServer32` | (default) | Path of the DLL (`GetModuleFileNameW`) |
| `CLSID\{5CF675C1-59F1-4B50-932D-10B64A8D6ED0}\InprocServer32` | `ThreadingModel` | `Both` |

`MFTRegister(CLSID, {90175D57-B7EA-4901-AEB3-933A8747756F}, "Nokia FaceTracker et AMBR MFT", 1 = MFT_ENUM_FLAG_SYNCMFT, no input type, no output type, no attributes)`. The category GUID isn't one of the documented `MFT_CATEGORY_*` (Nokia camera specific ?). `DllUnregisterServer` calls `MFTUnregister` and deletes the CLSID key (`sub_100014FC`, `RegDeleteTreeW`); it always returns `S_OK`.

### MFT object

Object of 0xC4 bytes (constructor `sub_100021F4` on the base class `sub_10001690`, destructor `sub_100022FC`). `QueryInterface` (`sub_100017CC`) accepts `IUnknown`, `IMFTransform` `{BF94C121-5B05-4E6F-8000-BA598961414D}` (+0x04) and `IMFAttributes` `{2CD2D921-C447-44A7-A13C-4ADABFC247E3}` (+0x08, every method forwarded to the attribute store at +0x14, `sub_10001AB0`…`sub_10001E20`).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `off_100224F8` |
| 0x04 | 4 | `IMFTransform` vtable `off_10022528` |
| 0x08 | 4 | `IMFAttributes` vtable `off_100225A0` (forwarder) |
| 0x0C | 4 | vtable `off_10022690` (destructor thunk) |
| 0x14 | 4 | `IMFAttributes` store (`MFCreateAttributes(4)`), see [Attributes](#attributes) |
| 0x30 | 4 | Stream count, 1 |
| 0x34 | 4 | Callback interface (vtable `off_10022500`) given to the engine: [faces changed](#face-results) `sub_10002E44`, [motion changed](#motion-results) `sub_10002E7C` |
| 0x38 | 4 | Current input type |
| 0x3C | 4 | Current output type |
| 0x40 | 4 | Type template: `MFMediaType_Video` + `MFVideoFormat_NV12` (`sub_10001E34`) |
| 0x44 | 4 | Pending sample |
| 0x48 | 0x1C | Lock (vtable `off_10022674`, critical section at 0x4C) |
| 0x64 | 4 | Sample size: width × height × 3 / 2 (`sub_10002F24`) |
| 0x68 | 4 | Face tracking enabled (constructor 1, then from attribute `{67704B03-…}`) |
| 0x6C | 4 | Motion detection enabled (constructor 1, then from attribute `{64253EC7-…}`) |
| 0x70 | 4 | Motion allowed by the driver: -1 = not asked yet, 0, 1 (see [ProcessInput](#processinput--processoutput)) |
| 0x74 | 4 | `clock()` at `MFT_MESSAGE_NOTIFY_START_OF_STREAM` |
| 0x78 | 4 | [Engine](#engine) (`sub_10004608`) |
| 0x7C | 4 | Camera control interface `{665F66E6-…}` |
| 0x80 | 4 | [Property sender](#property-sender) (0x6C bytes) |
| 0x84 | 4 | Face buffer (80 bytes: 10 × `{WORD x, y, width, height}`) |
| 0x88 | 4 | Number of faces |
| 0x8C | 4 | Faces were sent |
| 0x90, 0x94 | 4, 4 | Width and height of the analysed frames |
| 0x98 | 4 | Last motion value sent |
| 0x9C, 0xA0 | 4, 4 | Centre of the main face (previous frame) |
| 0xA4 | 4 | Main face valid |
| 0xA8 | 4 | `IMFDXGIDeviceManager` `{EB533D5D-2DB6-40F8-97A9-494692014F07}` |
| 0xAC, 0xB4 | 4, 4 | Staging textures (CPU read) |
| 0xB0, 0xB8 | 4, 4 | Default textures |
| 0xBC | 4 | Device handle of the D3D manager |
| 0xC0 | 4 | Frame counter (selects the texture pair) |

| Method | Function | Comment |
|--------|----------|---------|
| `GetStreamLimits`, `GetStreamCount` | sub_100018DC, 0x10001918 | 1 input, 1 output |
| `GetStreamIDs` | sub_10001938 | Ids 0…count-1 |
| `GetInputStreamInfo` | sub_1000253C | Flags 0x803 (`MFT_INPUT_STREAM_WHOLE_SAMPLES` \| `SINGLE_SAMPLE_PER_BUFFER` \| `PROCESSES_IN_PLACE`), size = sample size once a type is set, no lookahead, no alignment |
| `GetOutputStreamInfo` | sub_100025B0 | Flags 0x107 (whole samples, single sample per buffer, `FIXED_SAMPLE_SIZE`, `MFT_OUTPUT_STREAM_PROVIDES_SAMPLES`), size = sample size |
| `GetAttributes` | 0x10001978 | The [attribute store](#attributes) |
| `GetInputAvailableType` | sub_10002620 | Index 0 only (else `MF_E_NO_MORE_TYPES` 0xC00D36B9): copy of the output type if set, else of the NV12 template |
| `GetOutputAvailableType` | sub_10002684 | Index 0 only: copy of the input type if set, else of the template |
| `SetInputType` | sub_100026E8 | See below |
| `SetOutputType` | sub_100027D4 | See below |
| `GetInputCurrentType`, `GetOutputCurrentType` | sub_10002918, sub_10002980 | Copy, or `MF_E_TRANSFORM_TYPE_NOT_SET` (0xC00D6D60) |
| `GetInputStatus` | sub_100029E8 | `MFT_INPUT_STATUS_ACCEPT_DATA` when no sample is pending |
| `GetOutputStatus` | sub_10002A4C | `MFT_OUTPUT_STATUS_SAMPLE_READY` when a sample is pending |
| `ProcessMessage` | sub_10002AA4 | See below |
| `ProcessInput`, `ProcessOutput` | sub_10002BC4, sub_10002D68 | See [below](#processinput--processoutput) |

Stream numbers other than 0 return `MF_E_INVALIDSTREAMNUMBER` (0xC00D36B3).

**SetInputType / SetOutputType(0, type, flags)**: flags other than `MFT_SET_TYPE_TEST_ONLY` → `E_INVALIDARG`. A NULL type clears the current type, the sample size and stops the engine (`Shutdown`). Otherwise the major type and subtype must be those of the template (`sub_10001F00`): **only NV12 video** is accepted (`MF_E_INVALIDMEDIATYPE` 0xC00D36B4 otherwise). `SetOutputType` compares `MF_MT_FRAME_SIZE` with the input type (`sub_10002008`): a type without frame size gets the one of the input, a different size returns `E_FAIL`. The type is stored, and also used for the other side if it's not set yet. The sample size is computed from `MF_MT_FRAME_SIZE` (missing → 0xC00D3E98). When the frame size or subtype changed (`sub_10002F84`), or the engine isn't initialised, the engine is [reinitialised](#engine) (`sub_10003154`). With `MFT_SET_TYPE_TEST_ONLY` the type is set anyway (the flag is only checked for validity).

**ProcessMessage**:

| Message | Action |
|---------|--------|
| `MFT_MESSAGE_COMMAND_FLUSH` (0) | Releases the pending sample; tells the property sender to stop (+0x60 = 1); returns 0xC00D3E82 if the engine isn't initialised |
| `MFT_MESSAGE_SET_D3D_MANAGER` (2) | Releases the textures and the previous manager (`sub_10003C3C`); `QueryInterface(IMFDXGIDeviceManager)` on the parameter (+0xA8), `OpenDeviceHandle` (+0xBC). No parameter → `E_UNEXPECTED`, no interface → `E_NOINTERFACE` |
| `MFT_MESSAGE_NOTIFY_END_OF_STREAM` (0x10000002) | `sub_1000322C`: engine `Stop` if it runs, the property sender is stopped and released |
| `MFT_MESSAGE_NOTIFY_START_OF_STREAM` (0x10000003) | Engine `Start`, the property sender is restarted (+0x60 = 0), +0x74 = `clock()` |
| others | `S_OK` |

The MFT announces `MF_SA_D3D11_AWARE` and needs the D3D manager to analyse the frames: [sub_100032A4](#frame-capture) uses +0xA8 without NULL check.

### ProcessInput / ProcessOutput

**ProcessInput(0, sample, 0)** (`sub_10002BC4`):
1. `GetBufferCount` must be 1 (`MF_E_SAMPLE_HAS_TOO_MANY_BUFFERS` 0xC00D36DF for more, `E_FAIL` for none).
2. Both types must be set, the sample size known and no sample pending (else `MF_E_NOTACCEPTING` 0xC00D36B5); `GetTotalLength` must be the sample size (else `E_INVALIDARG`).
3. The sample is kept as the pending sample (`AddRef`).
4. On the first sample, the camera control interface and the property sender are created (`sub_10003044`): `IMFAttributes::GetItem({665F66E6-…})` on the MFT attributes must be `VT_UNKNOWN` (missing → no sender, no error), `QueryInterface` with the same GUID as IID (+0x7C), then the [property sender](#property-sender) (+0x80).
5. The enable attributes are read again (`sub_10003AAC`, see [Attributes](#attributes)).
6. Nothing else happens during the first **3 seconds** after the start of stream (`clock()` − +0x74 > 3000 ms). Then:
   - the first time (+0x70 = -1), the driver property `{6B8EA09B-8BD2-42F5-BA1B-2149A04B1EC6}` is read (`sub_10003A00`, see [Camera control properties](#camera-control-properties)): +0x70 = 0 if its first `UINT32` is 0, else 1; 1 also when the read fails;
   - when +0x70 = 0, motion detection is turned off (+0x6C = 0, engine `Enable(1, FALSE)`);
   - if face tracking or motion detection is on, the frame is [captured](#frame-capture) and given to the engine.

**ProcessOutput(0, 1, buffers, status)** (`sub_10002D68`): the count must be 1 and the caller's `pSample` NULL (`E_INVALIDARG`). Without pending sample: `MF_E_TRANSFORM_NEED_MORE_INPUT` (0xC00D6D72). Otherwise the pending sample itself is returned as output sample (no copy, no change, no event), and released from the MFT.

The analysis is asynchronous: `ProcessInput` only copies the frame and signals the worker threads, and the results come later through the engine callbacks.

### Frame capture

`sub_100032A4(sample)` copies the frame out of the GPU:
1. `IMFDXGIDeviceManager::LockDevice(handle, IID_ID3D11Device {DB6F6DDB-AC77-4E88-8253-819DF9BBF140}, TRUE)`, `ID3D11Device::GetImmediateContext`.
2. `sub_10003B8C`: `IMFSample::GetBufferByIndex(0)`, `QueryInterface(IMFDXGIBuffer {E7174CFA-1C9E-48B1-8866-626226BFC258})`, `IMFDXGIBuffer::GetResource(IID_ID3D11Texture2D {6F15AAF2-D208-4E89-9AB4-489535D34F9C})`. A sample in system memory fails here (`E_NOINTERFACE`): no analysis.
3. `ID3D11Texture2D::GetDesc`: the format must be `DXGI_FORMAT_NV12` (103), else `E_UNEXPECTED`.
4. On first use, `sub_10003CC4` creates 4 textures of the frame size, 1 mip, 1 array slice, NV12, no multisampling: +0xAC and +0xB4 `D3D11_USAGE_STAGING` with `D3D11_CPU_ACCESS_READ`, +0xB0 and +0xB8 `D3D11_USAGE_DEFAULT`, no bind flags.
5. Pipeline on two pairs, alternated by the frame counter (+0xC0): odd frames `CopyResource(0xAC ← 0xB0)`, `CopyResource(0xB8 ← input)`, map 0xB4; even frames `CopyResource(0xB4 ← 0xB8)`, `CopyResource(0xB0 ← input)`, map 0xAC. The mapped frame is the one received two frames before, so the GPU copy never stalls the pipeline.
6. `QueryInterface(IDXGISurface {CAFCB56C-6AC3-4889-BF47-9E23BBD260EC})`, `IDXGISurface::Map(DXGI_MAP_READ)`, engine `ProcessFrame(pBits)`, `Unmap`, `UnlockDevice`. The `Pitch` of the mapped rectangle isn't used: the engine assumes a stride equal to the width.

If any of the 4 textures is missing, they are recreated and the frame is skipped.

### Engine

Object of 92 bytes (`sub_10004608`, vtable `off_100226A4`, init `sub_100046C0`) that owns the frame pool, the two processors and their two worker threads.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 4 | Processor callback (`off_100226D4`, `sub_10004BB4`): face processor → MFT callback method 0, motion processor → method 1 |
| 0x0C | 4 | MFT callback (MFT +0x34) |
| 0x10 | 4 | [Frame pool](#frame-pool) (84 bytes, `sub_10005600`) |
| 0x14 | 4 | [Face processor](#face-tracker) (84 bytes, `sub_10004D1C`) |
| 0x18 | 4 | [Motion processor](#motion-detector) (52 bytes, `sub_10005348`) |
| 0x1C | 4 | Array of the 2 [worker threads](#worker-threads) (face, motion) |
| 0x24 | 4 | State: 0 not initialised, 1 initialised / stopped, 2 started |
| 0x28 | 4 | Run state: 1 stopped, 3 started |
| 0x2C | 0x18 | Configuration given by the MFT: width, height, color format (1 NV12, 3 YV12), 3, Y stride, chroma stride |
| 0x44 | 0x18 | Analysis configuration: width, height, format, 3 buffers, Y stride, chroma stride |

| Index | Method | Function | Comment |
|-------|--------|----------|---------|
| 1 | `Initialize(config)` | sub_100048CC | See below |
| 2 | `Shutdown` | sub_1000499C | Stops the threads, uninitialises the processors, frees the pool |
| 3 | `Start` | 0x10004A1C | Needs an initialised engine (`MF_E_NOT_INITIALIZED` 0xC00D36B6) |
| 4 | `Stop` | 0x10004A40 | |
| 5 | `ProcessFrame(pBits)` | sub_10004A60 | Only when started (else `MF_E_NOTACCEPTING`) and at least one processor enabled: copies the frame into the pool (`sub_100058AC`), then sets the work event of each enabled thread |
| 6 | `GetState` | sub_10004B00 | +0x24 |
| 7 | `GetConfig` | sub_10004B34 | |
| 8 | `Enable(processor, BOOL)` | sub_10004B20 | 0 = faces, 1 = motion (thread +0x20) |
| 9 | `GetFaces(buffer, &count, &width, &height)` | sub_10004B68 | Analysis size and up to 10 faces (`sub_1000526C`) |
| 10 | `GetMotion(&value)` | sub_10004B84 | Last [motion value](#motion-detector) |

**Initialize** (`sub_100048CC`, called by `sub_10003154` with the frame size, format 1 for NV12 or 3 for YV12, and the strides; the YV12 branch can't be reached since only NV12 is accepted):
1. Computes the analysis size (`sub_10004BEC`): larger than 1920 × 1120 → fitted in 480 × 280 (even values); larger than 960 × 560 → ¼; larger than 480 × 280 → ½; else unchanged. A 1280 × 720 preview is analysed at 320 × 180.
2. Frame pool with 3 buffers of the analysis size (`sub_100056D8`).
3. Face processor and motion processor initialised with (format, width, height, stride) (method 3 of each).
4. Starts the two worker threads (`sub_10006968`); state 1.

Then the MFT applies the enable attributes (`sub_10003AAC`).

#### Frame pool

`sub_100058AC` takes a free buffer of the pool and copies the frame into it: plain copy when the sizes match (`sub_10005A68`, line by line if the strides differ), else a downscale of the Y and CbCr planes (`sub_10005B10`): exact ½ (`sub_10005CC0`), exact ¼ (`sub_10005F64`), else bilinear in 14-bit fixed point (`sub_10006758`, interleaved CbCr for NV12). The buffer gets a frame number (pool +0x4C, incremented). The threads lock the latest frame with `sub_10005964` (reference count, state 3) and release it with `sub_10005A00`.

#### Worker threads

Object of 44 bytes per processor: processor, frame pool, thread handle (+0x0C), 2 events (+0x10: stop, work), last frame done (+0x14), state (+0x18: 2 idle, 3 busy, 1 stopping), stop flag (+0x1C), enabled (+0x20), ideal processor (+0x28, -1 = none). `sub_10006968` creates the events and the thread (`sub_10006C40` → `sub_10006B04`) with `THREAD_PRIORITY_BELOW_NORMAL`. The thread waits for its events; on the work event it processes the latest frame of the pool if it's newer than the last one done (frames that arrive while it works are skipped), then releases it.

### Face tracker

Processor of 84 bytes (`sub_10004D1C`, vtables `off_10022708` / `off_10022724`) around the ArcSoft face tracking library.

**Init** (`sub_10004E34`, method 3): a 10 MB working memory (`CoTaskMemAlloc(10485760)`, managed by the library's own allocator `sub_10006D04` / `sub_10006D5C`), a 44-byte image descriptor and a 160-byte result. The color format is converted to the ArcSoft one: 1 → 0x801 (NV12), 2 → 0x802 (NV21), 3 → 0x605 (YV12). `sub_1000ADE8` creates the tracking engine (width, height, format, stride); the processor then writes 2, 4 and 871 into internal fields of the engine (meaning unknown). Uninit: `sub_10005050` (`sub_1000BBEC` frees the engine).

**Process** (`sub_100050E8`, method 0): `sub_10006C58` → `sub_1000A9A4` tracks the faces of the frame (the second plane address of YV12 is computed from the Y plane). The result (count, then 16-byte rectangles left, top, right, bottom) is compared with the previous one: if the count differs or any coordinate moved by more than 2 pixels, it's copied under the processor lock and the engine callback is called ([Face results](#face-results)).

`GetFaces` (`sub_1000526C`) returns at most 10 faces, as `WORD` x, y, width, height in analysis pixels, stops at the first rectangle outside the frame, and zeroes the unused entries.

### Motion detector

Processor of 52 bytes (`sub_10005348`, vtables `off_1002273C` / `off_10022740`), sources `..\src\motionedetector.cpp`.

**Init** (`sub_10006DB8` → `sub_10006FF0`): the frame must be at least 32 × 32 (`_wassert` "(aFrameWidth >= KMinBlockSize * 2) && (aFrameHeight >= KMinBlockSize * 2)", line 291) and not already initialised ("!iIsInitialized", line 61). The Y plane is cut in a grid of blocks: block width and height = next power of two of width / 11 and height / 11, limited to 16…64; the grid is centred. One `DWORD` per block keeps its last value.

**Process** (`sub_10006E48`): for each block, the variance of the luma (on 4-bit samples, sum and sum of squares) is compared with the previous frame; the blocks whose value changed by 2 or more are counted. The result is `((previous & 0x7FFF) + changed) / 2` in bits 0–14 (running average of the number of changed blocks) and the number of blocks in bits 16–31. The first frame only fills the table. A change of the result calls the engine callback ([Motion results](#motion-results)).

### Face results

`sub_10002E44` (MFT callback 0, on the face thread) gets the faces with engine `GetFaces` (buffer +0x84, count +0x88, analysis size +0x90 / +0x94) and calls `sub_10003514`:
1. No face, and none sent before: nothing (+0xA4 = 0).
2. Builds the [face blob](#face-blob) and the weight of each face = width × height; the face nearest to the previous main face centre gets × 1.5, the face nearest to the frame centre × 2.5. The faces are sorted by decreasing weight; the first one is the main face, its centre is kept (+0x9C, +0xA0).
3. Main face rectangle packed in a `UINT32`, each value scaled to 0…255 of the frame: bits 24–31 left, 16–23 top, 8–15 width, 0–7 height (0 when there's no face).
4. If the engine runs (state 2) and the property sender exists: property `{1D032F49-8A1B-4CC7-B9AE-8046D92614D0}` = `VT_UI4` main face, then property `{08256CFF-F5EE-4A6F-B442-CE91C8369D65}` = the blob (`InitPropVariantFromBuffer`, 212 bytes).

When the last face disappears, one update with 0 faces is sent (+0x8C remembers that faces were sent).

#### Face blob

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 1 | Number of faces (0…10), rest of the `DWORD` 0 |
| 0x04 | 4 | Width of the analysed frame |
| 0x08 | 4 | Height of the analysed frame |
| 0x0C | 10 × 20 | Faces, main face first: x, y, width, height (`DWORD`s, analysis pixels), then a `DWORD` always 1 (`sub_100038FC`); unused entries 0, 0, 0, 0, 1 |

### Motion results

`sub_10002E7C` (MFT callback 1, on the motion thread) reads engine `GetMotion`; if the value differs from the last one sent (+0x98), it's stored and `sub_10003990` sends property `{DA2D3EFD-CB8D-4210-BFEE-4C2D4C073242}` = `VT_UI4` value, when the engine runs. When motion detection is turned off, the value 0 is sent.

### Attributes

Attribute store of the MFT (+0x14, `MFCreateAttributes(4)` in `sub_10002414`), also reachable by `QueryInterface(IMFAttributes)` on the MFT:

| GUID | Type | Default | Use |
|------|------|---------|-----|
| `{B00FF797-0B7C-476E-9CE5-0BC9861805A2}` | blob (48 bytes) | the 3 GUIDs below | List of the keys the host can set ? (the same attribute lists the keys of [QCJpegEncoderMFT.dll](./qcjpegencodermft.md#attributes)) |
| `{665F66E6-815B-472A-B1ED-D2D5B726142F}` | `VT_UNKNOWN`, not set | — | Camera control interface, read on the first sample, see [Camera control properties](#camera-control-properties) |
| `{67704B03-95B8-4E66-B62F-5EF126238451}` | UINT32 | 0 | Face tracking on (≠ 0) |
| `{64253EC7-2DD6-4F2D-B8DA-FE461956542D}` | UINT32 | 0 | Motion detection on (≠ 0) |
| `MF_SA_D3D11_AWARE` `{206B4FC8-FCF9-4C51-AFE3-9764369E33A0}` | UINT32 | 1 | The MFT wants D3D11 samples |

Both features are off by default: the host must set the two UINT32. `sub_10003AAC` reads them after each engine initialisation and on each input sample (`GetUINT32`, a missing key counts as 0):
- faces: engine `Enable(0, value)`; when tracking is turned off, the face list is cleared and an empty update is [sent](#face-results);
- motion: engine `Enable(1, value)`; turned off, or refused by the driver (+0x70 = 0), the motion value 0 is [sent](#motion-results).

### Property sender

Object of 0x6C bytes (MFT +0x80, created by `sub_10003044`, started by `sub_10003E60`) that calls the camera control interface on its own thread, so that `ProcessInput` and the worker threads never wait for the driver:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Camera control interface |
| 0x04 | 0x1C | Lock (queue) |
| 0x20 | 0x1C | Lock (call in progress) |
| 0x40 | 4 | Thread (`sub_10004520` → `sub_10004218`) |
| 0x44 | 4 | 3 events: stop, work, read done |
| 0x48 | 4 | State: 2 idle, 3 busy, 1 stopping |
| 0x4C | 4 | Stop requested |
| 0x54 | 4 | Read pending |
| 0x58 | 4 | `IMFAttributes`: property GUID → `PROPVARIANT` value |
| 0x5C | 4 | `IMFAttributes`: property GUID → request type (0 set, 1 get, 2 set blob) |
| 0x60 | 4 | Flushing: queued requests are dropped |
| 0x64 | 4 | Call in progress |

`sub_10004010` (set) and `sub_10004184` (set blob) store the value and the type under the property GUID and set the work event; a new value replaces a value not sent yet, so only the latest value of each property reaches the driver. `sub_100040A4` (get) queues type 1 and waits up to 200 ms for the result (else `E_FAIL`). The thread takes the requests one by one (`GetItemByIndex`) and calls the interface. `sub_10003F34` stops the thread (1 s, then `TerminateThread`).

### Camera control properties

The interface `{665F66E6-815B-472A-B1ED-D2D5B726142F}` (Nokia, undocumented) is called with a property GUID (passed by value) and a `PROPVARIANT *`:

| Method | Use |
|--------|-----|
| 3 (vtable +0x0C) | Set, used for the blob |
| 4 (+0x10) | Set |
| 5 (+0x14) | Get |

| Property | Call | Data | Sent when |
|----------|------|------|-----------|
| `{1D032F49-8A1B-4CC7-B9AE-8046D92614D0}` | set | `VT_UI4`: main face, left / top / width / height scaled to 0…255 | Faces changed ([Face results](#face-results)) |
| `{08256CFF-F5EE-4A6F-B442-CE91C8369D65}` | set blob | `VT_VECTOR` \| `VT_UI1`, 212 bytes: [face blob](#face-blob) | Faces changed, after the previous one |
| `{DA2D3EFD-CB8D-4210-BFEE-4C2D4C073242}` | set | `VT_UI4`: [motion value](#motion-detector) | Motion value changed |
| `{6B8EA09B-8BD2-42F5-BA1B-2149A04B1EC6}` | get | First `UINT32` element (`PropVariantGetUInt32Elem`): 0 = no motion detection | Once, 3 s after the start of stream |

Which component implements the interface (the camera pipeline or a user-mode part of the driver, then KS properties of [qccamavs8930.sys](../drivers/qccamavs8930.md) ?) isn't known.

### COM

| GUID | Use |
|------|-----|
| `{5CF675C1-59F1-4B50-932D-10B64A8D6ED0}` | CLSID of the MFT "Nokia FaceTracker et AMBR MFT" |
| `{90175D57-B7EA-4901-AEB3-933A8747756F}` | MFT category given to `MFTRegister` |
| `{00000001-0000-0000-C000-000000000046}` | `IClassFactory` |
| `{BF94C121-5B05-4E6F-8000-BA598961414D}` | `IMFTransform` |
| `{2CD2D921-C447-44A7-A13C-4ADABFC247E3}` | `IMFAttributes` |
| `{EB533D5D-2DB6-40F8-97A9-494692014F07}` | `IMFDXGIDeviceManager` |
| `{E7174CFA-1C9E-48B1-8866-626226BFC258}` | `IMFDXGIBuffer` |
| `{DB6F6DDB-AC77-4E88-8253-819DF9BBF140}` | `ID3D11Device` |
| `{6F15AAF2-D208-4E89-9AB4-489535D34F9C}` | `ID3D11Texture2D` |
| `{CAFCB56C-6AC3-4889-BF47-9E23BBD260EC}` | `IDXGISurface` |
| `{665F66E6-815B-472A-B1ED-D2D5B726142F}` | Camera control interface (attribute key and IID) |
