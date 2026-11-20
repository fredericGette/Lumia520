## nokia_mft_still.dll

Media Foundation transform of the Nokia camera stack that post-processes the still pictures: chroma noise reduction, a luma filter, red-eye removal and a "vibrance" color boost, applied in place on the NV12 picture before it's encoded.  
`nokia_mft_still.dll` is an in-process COM server (248 832 bytes, 500 functions) registered as the MFT "Nokia RedEyeRemoval MFT" (CLSID `{64AA37E0-0A1B-4C30-AB52-721309B5E350}`). Unlike its sibling [nokia_mft_preview.dll](./nokia_mft_preview.md), it has **4 input and 4 output streams**: stream 0 is the NV12 picture, stream 1 a binary blob with the capture [metadata](#metadata-blob) (and maybe extra frames), streams 2 and 3 are binary streams passed through unchanged. Each output stream gives back the input sample of the same stream ([pass-through](#processinput--processoutput)); the picture of stream 0 is modified in place. The filters are configured per picture by the metadata blob (gain, strengths, flash fired ?), and can be turned off by [attributes](#attributes). They run on [worker threads](#worker-threads), the picture being cut in horizontal slices.  
The red-eye library is linked in and takes most of the code (0x100073D8…0x1002B9AC), but has no copyright or version string (vendor unknown). The other filters are small: a multi-scale [chroma denoiser](#chroma-noise-reduction), an edge-aware 5 × 5 [luma filter](#luma-filter) in NEON, and a [vibrance](#vibrance-filter) filter that still prints `wprintf` timing traces ("Algorithm PerfTesting: …").  
It's part of the same Nokia camera build as [nokia_mft_preview.dll](./nokia_mft_preview.md), the camera drivers and [QCJpegEncoderMFT.dll](./qcjpegencodermft.md) (PDB path `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\MFT\fre\nokia_mft_still.pdb`), and shares the COM registration code, the class factory and the MFT category with nokia_mft_preview.dll. The process that loads it and the component that builds the metadata blob (the camera pipeline, from the driver data ?) aren't known.

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| MFPlat.dll | `MFTRegister`, `MFTUnregister`, `MFCreateMediaType`, `MFCreateAttributes` |
| api-ms-win-core-com-l1-1-0.dll | `CoTaskMemAlloc`, `CoTaskMemFree`, `StringFromGUID2` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCreateKeyExW`, `RegSetValueExW`, `RegCloseKey`, `RegDeleteTreeW` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `WaitForMultipleObjectsEx`, `InitializeCriticalSectionAndSpinCount`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-processthreads-l1-1-1.dll | `CreateThread`, `SetThreadPriority`, `GetThreadIdealProcessorEx`, `SetThreadIdealProcessorEx`, `GetCurrentThreadId`, `IsProcessorFeaturePresent` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-libraryloader-l1-1-1.dll | `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-errorhandling-l1-1-1.dll | `GetLastError` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter` |
| api-ms-win-core-sysinfo-l1-2-0.dll | `GetSystemTimeAsFileTime`, `GetTickCount64` |
| MSVCR110.dll | `clock`, `wprintf`, `memcpy`, `memcpy_s`, `memset`, `memcmp`, `_vsnwprintf`, `_wassert`, `operator new`/`delete`, `_purecall`, `_initterm`, `_onexit`, `__dllonexit`, … |

The util, profile, sysinfo, `GetCurrentThreadId`, `IsProcessorFeaturePresent` imports and most of MSVCR110 are the Visual C++ 2012 DLL CRT startup and `/GS` security cookie code. There's no Direct3D, no PROPSYS and no thread termination: unlike the preview MFT, it works on samples in system memory and doesn't talk to the driver.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x100011FC | none |
| 2 | `DllGetClassObject` | 0x100012E0 | `REFCLSID, REFIID, void **` |
| 3 | `DllRegisterServer` | 0x1000121C | none |
| 4 | `DllUnregisterServer` | 0x100012B4 | none |

The four exports of a COM server. A global counter (`dword_1003D2A4`) counts the MFT objects; `DllCanUnloadNow` returns `E_FAIL` (0x80004005) while it isn't 0.

`DllGetClassObject` returns `CLASS_E_CLASSNOTAVAILABLE` (0x80040111) for any CLSID other than `{64AA37E0-0A1B-4C30-AB52-721309B5E350}`; otherwise it creates a class factory (12 bytes, vtable `off_1002F36C`, the creation function `sub_10002454` at +8) and queries it (if `operator new` fails it returns `S_OK` without object). `CreateInstance` (`sub_100010C4`) accepts an outer object only when `IUnknown` is requested (it isn't used), and `sub_10002454` allocates the [MFT](#mft-object) (`CoTaskMemAlloc(0x9C)`, constructor `sub_100024D4`), initialises it (`sub_10002788`) and queries the requested interface.

### Startup

`start` (`_DllMainCRTStartup`, 0x1002C374): the usual CRT startup with `__security_init_cookie`; the static initialisers copy `MFVideoFormat_NV12` into 7 globals (`dword_1003D2A8`…, one of them, `dword_1003D2D8`, is the subtype of the type template). `DllMain` (`sub_100011C8`) saves the module handle (`dword_1003D2A0`) and calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH`. There's no ETW / WPP registration; the only trace output is the `wprintf` of the [vibrance filter](#vibrance-filter).

### Registry

Same code as [nokia_mft_preview.dll](./nokia_mft_preview.md#registry) (`..\..\CommonHeaders\MFTs\COMDllRegistration.cpp`, "g_hModule != NULL" assert line 130). `DllRegisterServer` writes 3 `REG_SZ` values (`sub_10001350`, `sub_1000158C`) under `HKEY_CLASSES_ROOT`, then calls `MFTRegister`:

| Key | Value | Data |
|-----|-------|------|
| `CLSID\{64AA37E0-0A1B-4C30-AB52-721309B5E350}` | (default) | `Nokia RedEyeRemoval MFT` |
| `CLSID\{64AA37E0-0A1B-4C30-AB52-721309B5E350}\InprocServer32` | (default) | Path of the DLL (`GetModuleFileNameW`) |
| `CLSID\{64AA37E0-0A1B-4C30-AB52-721309B5E350}\InprocServer32` | `ThreadingModel` | `Both` |

`MFTRegister(CLSID, {90175D57-B7EA-4901-AEB3-933A8747756F}, "Nokia RedEyeRemoval MFT", 1 = MFT_ENUM_FLAG_SYNCMFT, no input type, no output type, no attributes)`: the same undocumented category as the preview MFT. `DllUnregisterServer` calls `MFTUnregister` and deletes the CLSID key (`sub_100014FC`, `RegDeleteTreeW`); it always returns `S_OK`.

### MFT object

Object of 0x9C bytes (constructor `sub_100024D4` on the base class `sub_1000199C`, initialisation `sub_10002788`, destructor `sub_100025A0`). `QueryInterface` (`sub_10001AD8`) accepts `IUnknown`, `IMFTransform` `{BF94C121-5B05-4E6F-8000-BA598961414D}` (+0x04) and `IMFAttributes` `{2CD2D921-C447-44A7-A13C-4ADABFC247E3}` (+0x08, forwarded to the attribute store at +0x14).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `off_1002F4D8` |
| 0x04 | 4 | `IMFTransform` vtable `off_1002F598` |
| 0x08 | 4 | `IMFAttributes` vtable `off_1002F4E0` (forwarder) |
| 0x0C | 4 | vtable `off_1002F610` (destructor thunk) |
| 0x10 | 4 | Reference count |
| 0x14 | 4 | `IMFAttributes` store (`MFCreateAttributes(4)`), see [Attributes](#attributes) |
| 0x18 | 0x18 | Critical section (spin count 0x100) |
| 0x30 | 4 | Stream count, 4 |
| 0x34 | 4 × 4 | Input types of streams 0…3 |
| 0x44 | 4 × 4 | Output types of streams 0…3 |
| 0x54 | 4 | Type template: `MFMediaType_Video` + `MFVideoFormat_NV12` (`sub_10002154`) |
| 0x58 | 4 × 4 | Pending input samples of streams 0…3 |
| 0x68 | 4 | Sample size of stream 0: width × height × 3 / 2 (`sub_100033E4`) |
| 0x6C | 4 | Array of the 7 [filters](#filters) (0x1C bytes) |
| 0x70 | 4 | Array of the 3 [processors](#processors) (0xC bytes) |
| 0x74 | 4 × 6 | Pointers into the current [metadata blob](#metadata-blob): general (md0), chroma NR (md1), vibrance (md2), luma filter (md3), unused, frame list |
| 0x90 | 4 | Number of frame entries in the blob |
| 0x94 | 4 | Number of valid frames |
| 0x98 | 4 | Frame array: `{data, width, height}` × count (12 bytes each) |

| Method | Function | Comment |
|--------|----------|---------|
| `GetStreamLimits`, `GetStreamCount` | sub_10001BE8, 0x10001C24 | 4 inputs, 4 outputs (min = max = 4) |
| `GetStreamIDs` | sub_10001C44 | Ids 0…3 |
| `GetInputStreamInfo` | sub_10002A04 | Any stream: flags 0x803 (`MFT_INPUT_STREAM_WHOLE_SAMPLES` \| `SINGLE_SAMPLE_PER_BUFFER` \| `PROCESSES_IN_PLACE`), size = sample size of stream 0 once a type is set, no lookahead, no alignment |
| `GetOutputStreamInfo` | sub_10002A78 | Any stream: flags 0x107 (whole samples, single sample per buffer, `FIXED_SAMPLE_SIZE`, `MFT_OUTPUT_STREAM_PROVIDES_SAMPLES`), size = sample size of stream 0 |
| `GetAttributes` | 0x10001C84 | The [attribute store](#attributes) |
| `GetInputStreamAttributes`, `GetOutputStreamAttributes`, `DeleteInputStream`, `AddInputStreams`, `SetOutputBounds`, `ProcessEvent` | 0x10001CC0… | `E_NOTIMPL` |
| `GetInputAvailableType` | sub_10002AE8 | Index 0 only (else `MF_E_NO_MORE_TYPES` 0xC00D36B9): copy of the output type of stream 0 if set, else of the NV12 template, whatever the stream |
| `GetOutputAvailableType` | sub_10002B58 | Index 0 only: copy of the input type of stream 0 if set, else of the template |
| `SetInputType` | sub_10002BC8 | See below |
| `SetOutputType` | sub_10002D44 | See below |
| `GetInputCurrentType`, `GetOutputCurrentType` | sub_10002F1C, sub_10002F9C | Copy, or `MF_E_TRANSFORM_TYPE_NOT_SET` (0xC00D6D60) |
| `GetInputStatus` | sub_1000301C | `MFT_INPUT_STATUS_ACCEPT_DATA` when the stream has no pending sample |
| `GetOutputStatus` | sub_10003084 | `MFT_OUTPUT_STATUS_SAMPLE_READY` when all 4 streams have a pending sample |
| `ProcessMessage` | 0x100030E4 | See below |
| `ProcessInput`, `ProcessOutput` | sub_10003108, sub_10003234 | See [below](#processinput--processoutput) |

Stream numbers above 3 return `MF_E_INVALIDSTREAMNUMBER` (0xC00D36B3).

**SetInputType / SetOutputType(stream, type, flags)**: flags other than `MFT_SET_TYPE_TEST_ONLY` → `E_INVALIDARG`. A NULL type clears the current type of the stream and the sample size. Otherwise:
- stream 0: the major type and subtype must be those of the template (`sub_10002220`): **only NV12 video**. `SetOutputType` compares `MF_MT_FRAME_SIZE` with the input type (`sub_10002328`): a type without frame size gets the one of the input, a different size is refused;
- streams 1…3: the major type must be `MFMediaType_Binary` `{72178C25-E45B-11D5-BC2A-00B0D0F3F4AB}`, the subtype isn't checked.

Otherwise `MF_E_INVALIDMEDIATYPE` (0xC00D36B4). The type is stored, and also used for the other side of the same stream if it's not set yet. For stream 0 the sample size is computed from `MF_MT_FRAME_SIZE` (missing → 0xC00D3E98), and when the frame size or subtype changed (`sub_10003444`), or a processor isn't initialised, the 3 [processors](#processors) are reinitialised with the frame size (`sub_10003504`: `Uninit`, then `Init(width, height, stride = width)`). With `MFT_SET_TYPE_TEST_ONLY` the type is set anyway.

**ProcessMessage**:

| Message | Action |
|---------|--------|
| `MFT_MESSAGE_COMMAND_FLUSH` (0) | Forgets the 4 pending samples (sets the pointers to NULL without `Release`: the samples leak) |
| `MFT_MESSAGE_SET_D3D_MANAGER` (2) | `E_NOTIMPL`: the MFT works on system memory samples only |
| others | `S_OK` |

### ProcessInput / ProcessOutput

**ProcessInput(stream, sample, 0)** (`sub_10003108`):
1. Flags other than 0 → `E_INVALIDARG`; `GetBufferCount` must be 1 (`MF_E_SAMPLE_HAS_TOO_MANY_BUFFERS` 0xC00D36DF for more, `E_FAIL` for none).
2. Stream 0 needs its input and output types and the sample size; any stream must have no pending sample (else `MF_E_NOTACCEPTING` 0xC00D36B5). The length of the buffer isn't checked.
3. The sample is kept as the pending sample of the stream (`AddRef`).

**ProcessOutput(0, 4, buffers, status)** (`sub_10003234`): the flags must be 0, the count 4 and every `pSample` NULL (`E_INVALIDARG`). If a stream has no pending sample: `MF_E_TRANSFORM_NEED_MORE_INPUT` (0xC00D6D72). Otherwise:
1. Stream 1: the [metadata blob](#metadata-blob) is parsed and given to the filters, and the extra frames are processed (`sub_10003638`).
2. Streams 2 and 3: the buffers are locked and unlocked, nothing else (`sub_1000385C`, `sub_100038E8`).
3. Stream 0: the picture is [processed](#processors) in place (`sub_10003568`): `IMFMediaBuffer::Lock`, frame size from the input type, then each processor gets `{Y = buffer, CbCr = buffer + width × height}`, the stride being the width; `Unlock`.
4. Each output buffer gets the input sample of the same stream (stream id = index, no event), and the pending samples are released from the MFT. `*pdwStatus` = 0.

So the MFT is synchronous: `ProcessOutput` blocks until the worker threads have processed the picture.

### Metadata blob

Content of the stream 1 buffer, parsed by `sub_10003974`. The blob starts with 2 non-zero `DWORD`s, then a list of entries, each `{DWORD size, GUID id, …}`. The entry with the id `{E86CE608-EE73-4B43-8CCA-6B49CA05F258}` is searched; its payload starts at +24 of the entry:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Version |
| 0x08 | 4 | Size (bounds check) |
| 0x0C | 4 | Offset of md0, general (24 bytes) |
| 0x10 | 4 | Offset of md1, [chroma noise reduction](#chroma-noise-reduction) (20 bytes) |
| 0x14 | 4 | Offset of md3, [luma filter](#luma-filter) (24 bytes) |
| 0x28 | 4 | Version ≥ 2: offset of the frame list (24-byte header: count at +0x0C, offset of the first entry at +0x14) |
| 0x2C | 4 | Version ≥ 4: offset of md2, [vibrance](#vibrance-filter) (20 bytes) |

The offsets are relative to the payload, a 0 offset or a structure outside the buffer leaves the pointer NULL. The fields that are read:

| Structure | Offset | Use |
|-----------|--------|-----|
| md0 | 0x10 | Gain, 256 … 3072 (×1 … ×12 in 8.8 fixed point, sensor gain / ISO ?), used by the chroma denoiser |
| md0 | 0x14 | 1 = run the [red-eye removal](#red-eye-removal) (flash fired ?) |
| md1 | 0x0C | Chroma NR strength, 0 … 2048, 0 = off |
| md1 | 0x10 | Chroma NR kernel size: 3, 5 or 7 |
| md2 | 0x0C | Vibrance strength, 0 … 100 %, 0 = off |
| md2 | 0x10 | Vibrance on skin tones, 0 … 100 % |
| md3 | 0x0C | Luma filter strength, 0 … 255, 0 = off |
| md3 | 0x10, 0x14 | Luma filter parameters, 0 … 255 |

Each frame entry of the list: size of the entry (+0x08, to the next one), 0 = valid (+0x0C), width (+0x10), height (+0x14), data size (+0x18), data offset relative to the entry (+0x1C). Out-of-range values are ignored (the filter keeps its previous value).

After parsing, each processor gets the pointers (method 7, `SetMetadata`). Then, if there are frames in the blob (`sub_10003638`):
- when exactly one filter is turned on by the metadata, the frames are processed by that filter alone, on up to 2 threads (`sub_10003B40`, with new filter objects initialised with the size of the first frame);
- when several are on, each frame is given to the 3 processors in turn, like the main picture.

What these frames are (thumbnail / postview of the same capture, so that it gets the same corrections ?) isn't known.

### Processors

The MFT runs 3 processors, in this order, on the picture (+0x70):

| Index | Processor | Filters (thread) | Slices |
|-------|-----------|------------------|--------|
| 0 | Group of 4 threads (`sub_100043AC(4, …)`) | [Luma filter](#luma-filter) slice 0, 1, 2 (threads 0…2), [chroma noise reduction](#chroma-noise-reduction) (thread 3) | Luma cut in 3 slices with 4 lines of overlap; the chroma filter does the whole CbCr plane at the same time |
| 1 | [Red-eye removal](#red-eye-removal) alone, on the calling thread | | |
| 2 | Group of 2 threads | [Vibrance](#vibrance-filter) × 2 | 2 slices, no overlap |

The 7 filter objects (+0x6C) are created by `sub_10002788`: [chroma NR](#chroma-noise-reduction) (`sub_10003FFC`), 3 [luma filters](#luma-filter) (`sub_10005388(slice, overlap)` with (0, 0), (1, 4), (2, 4)), [red-eye](#red-eye-removal) (`sub_10004F9C`), 2 [vibrance filters](#vibrance-filter) (`sub_10005758`).

Every filter and group has the same interface (vtables `off_1002F614`, `off_1002F708`, `off_1002F6D4`, `off_1002F868`, groups `off_1002F69C`):

| Index | Method | Comment |
|-------|--------|---------|
| 0 | `Process(planes, planes2)` | `planes` = `{Y, CbCr}`; `planes2` (output) is NULL: in place |
| 2 | `PostProcess(Y, CbCr)` | Called by the group after all threads finished (the luma filter copies back its saved border lines) |
| 3 | `Init(width, height, stride)` | |
| 4 | `Uninit` | |
| 5 | `IsInitialized` | |
| 6 | `IsEnabled` | From the [attributes](#attributes); a group is enabled if one of its filters is |
| 7 | `SetMetadata(pointers)` | The 6 pointers of the [blob](#metadata-blob) |
| 9 | `SetSlices(count, overlap)` | Groups only (`sub_10004C40`) |
| 10 | `SetFrames(count, Y[], CbCr[])` | Groups only (`sub_10004D24`): list of frames to process |

#### Worker threads

`sub_10004480` creates one worker per thread of the group (44 bytes: filter, group, thread, 2 events stop / work, last frame done, state, stop flag, done event, thread index). `sub_1000160C` creates the thread (`sub_10001900` → `sub_100017A8`) with `THREAD_PRIORITY_BELOW_NORMAL`, and its ideal processor = thread index & 1 (core 0 or 1 of the dual-core SoC). The group `Process` (`sub_10004A48`) sets the work event of each thread and waits for their done events (`WaitForMultipleObjectsEx`, infinite); each thread asks the group for its slice or frame (`sub_10004E4C`: slice = start line × stride, the CbCr at start line / 2; `ERROR_NOT_FOUND` 0x80070490 when there are no more frames), calls its filter `Process`, then signals its done event.

### Chroma noise reduction

Filter of 48 bytes (`sub_10003FFC`, vtables `off_1002F67C` / `off_1002F614`), working on the CbCr plane only (half width, half height).

- **Init** (`sub_1000411C`): engine of 232 bytes (`sub_10005AD4`); `sub_10005B58` sizes a 3-level pyramid on the CbCr plane (dimensions rounded down to 8) and allocates its buffers; `sub_10005C4C` sets the parameters.
- **Parameters** (`sub_10005C4C`, from md0 gain, md1 strength and kernel): gain 256…65535, strength ≤ 2048 (above 200 it becomes 4 × (strength − 150)), kernel 3, 5 or 7. Per level, a threshold 0x800000 / strength² (×4 per level, limited to 0xFFFF); defaults gain 256, kernel 3, strength 0.
- **Process** (`sub_10004234` → `sub_10005D50`): only when the [attribute](#attributes) `{02A13F44-…}` allows it and the strength isn't 0. From the coarsest level to the finest: filtering of the level (`sub_10005EC8`), reconstruction to the upper level (`sub_100068BC`), then the final level written back into the picture (`sub_10006544`).

### Luma filter

Filter of 64 bytes (`sub_10005388(slice, overlap)`, vtables `off_1002F73C` / `off_1002F708`), 3 instances that each process a third of the Y plane.

- **Init** (`sub_100054F0`): the stride must equal the width (else 0x80090029); `sub_10006B68` allocates a line buffer (13 × width + 128) and a buffer for the overlap lines (overlap × width), then sets the parameters.
- **Parameters** (`sub_10006AC8`, from md3: strength +0x0C, parameter A +0x10 (default 128), parameter B +0x14): 3 weights computed from A and the strength (9 × strength × w / 64), a threshold (5 × (strength − 40) / 2, 0…240), (B + 1) / 8 and (strength / 8) + 18. The md0 gain is stored but not used.
- **Process** (`sub_100055A4` → `sub_10006C10`): only when the attribute `{8481FE29-…}` allows it and the strength isn't 0. Sliding window of 5 lines: each line is pre-filtered (`sub_1002DCB8`, `sub_1002D43C`) into a ring of 5 line buffers, then `sub_1002D7F2` (NEON) computes the output line from the 5 lines: the weights come from the saturated absolute differences between the centre pixel and its neighbours (`vabdq_u8` against a threshold 0x30), so the edges are preserved. An edge-preserving denoiser, maybe with sharpening (the meaning of the parameters isn't known).
- **PostProcess** (`sub_10005628`): slices 1 and 2 copy back the lines they saved, so that the overlap lines aren't filtered twice.

### Red-eye removal

Filter of 96 bytes (`sub_10004F9C`, vtables `off_1002F6D0` / `off_1002F6D4`) around the red-eye library; at most **20** eyes (+0x08).

- **Init** (`sub_100050DC`): 563 200 bytes of working memory (the library needs at least 389 120), and a result buffer of 96 bytes per eye.
- **SetMetadata** (0x10005354): arms the filter for the next picture when md0 +0x14 = 1.
- **Process** (`sub_10005200`): only when the attribute `{D6E41F71-…}` exists and isn't 0 (**off by default**) and the filter is armed. Image descriptor: width, height, format 0x3A (NV12 in the library numbering ?), Y and CbCr strides, Y and CbCr planes. `sub_100073D8` detects the red eyes (returns their number), `sub_100078B0` corrects them in the picture. The filter is disarmed after each picture. The library errors are converted by `sub_100051AC`: −2 `E_INVALIDARG`, −4 `E_OUTOFMEMORY`, −3 0xC00D3E98, −7 0xC00D36BB, −8 0xC00D4278, others `E_FAIL`.

### Vibrance filter

Filter of 40 bytes (`sub_10005758`, vtables `off_1002F864` / `off_1002F868`), 2 instances that each process half of the picture, CbCr plane only.

- **Init** (`sub_1000582C`): engine of 0x40410 bytes (`sub_1002B9AC`): a 256 × 256 table of divisions (`float` a / b, for the sine and cosine of the hue) and a saturation curve of 256 entries built from control points.
- **SetMetadata** (0x10005A94): strength and skin factor from md2, both ≤ 100, else both 0.
- **Process** (`sub_100058A8` → `sub_1002BB70`): only when the attribute `{7DCAF1EE-…}` allows it and the strength isn't 0. For each CbCr pair: saturation = √(Cb² + Cr²), target = curve[saturation], new saturation = saturation + (target − saturation) × strength, at constant hue. In the skin tone quadrant (Cb ≤ 0, Cr ≥ 0), the change is multiplied by the skin factor for hues between 20° and 55°, and by 0.8 for 15°…20° and 55°…60° (transition). So the weakly saturated colors get more saturation than the saturated ones, and the skin tones are protected. Each step prints a trace to the console: `Algorithm PerfTesting: Vibrance Filter: Start / Init done, Process / Done : Clock = …, CLOCKS_PER_SEC = 1000`.

### Attributes

Attribute store of the MFT (+0x14, `MFCreateAttributes(4)` in `sub_10002788`), also reachable by `QueryInterface(IMFAttributes)` on the MFT. The filters read their enable attribute (`GetUINT32`) on each picture:

| GUID | Type | Default | Use |
|------|------|---------|-----|
| `{B00FF797-0B7C-476E-9CE5-0BC9861805A2}` | blob (32 bytes) | `{7DCAF1EE-…}`, `{D6E41F71-…}` | List of the keys the host can set ? (same attribute as in [nokia_mft_preview.dll](./nokia_mft_preview.md#attributes) and [QCJpegEncoderMFT.dll](./qcjpegencodermft.md#attributes)) |
| `{7DCAF1EE-191A-4326-AC3C-B04E98077CD8}` | UINT32 | not set = on | [Vibrance](#vibrance-filter) on (≠ 0) |
| `{D6E41F71-84D2-47FE-95AD-033BF8921A04}` | UINT32 | not set = **off** | [Red-eye removal](#red-eye-removal) on (≠ 0) |
| `{02A13F44-F5DE-48B3-AC57-23B65E418914}` | UINT32 | not set = on | [Chroma noise reduction](#chroma-noise-reduction) on (≠ 0) |
| `{8481FE29-99C2-4308-9410-CF38313C07EF}` | UINT32 | not set = on | [Luma filter](#luma-filter) on (≠ 0) |

The attributes only allow a filter: what it does, and if it runs at all, comes from the [metadata blob](#metadata-blob) of each picture. There's no `MF_SA_D3D11_AWARE`.

### COM

| GUID | Use |
|------|-----|
| `{64AA37E0-0A1B-4C30-AB52-721309B5E350}` | CLSID of the MFT "Nokia RedEyeRemoval MFT" |
| `{90175D57-B7EA-4901-AEB3-933A8747756F}` | MFT category given to `MFTRegister` (same as nokia_mft_preview.dll) |
| `{00000001-0000-0000-C000-000000000046}` | `IClassFactory` |
| `{BF94C121-5B05-4E6F-8000-BA598961414D}` | `IMFTransform` |
| `{2CD2D921-C447-44A7-A13C-4ADABFC247E3}` | `IMFAttributes` |
| `{72178C25-E45B-11D5-BC2A-00B0D0F3F4AB}` | `MFMediaType_Binary`, major type of streams 1…3 |
| `{E86CE608-EE73-4B43-8CCA-6B49CA05F258}` | Id of the Nokia entry in the [metadata blob](#metadata-blob) |
