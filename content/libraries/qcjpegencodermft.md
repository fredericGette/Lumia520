## QCJpegEncoderMFT.dll

Media Foundation transform of the camera stack that turns a YCbCr frame into a JPEG file (with EXIF, thumbnail and Qualcomm "mobicat" data), using the Gemini hardware encoder when it can.  
`QCJpegEncoderMFT.dll` is an in-process COM server (141 312 bytes, 416 functions) registered as the MFT "Qualcomm Jpeg Encoder" (CLSID `{83D175FD-272D-475E-8A2E-0DE0D014B6E9}`). The MFT has 3 input streams (the image, an EXIF tag list, a camera attributes blob) and one output stream (a JPEG image). It's a wrapper around the Qualcomm `jpege` library ("Jpeg HARDWARE Encode Engine", "Jpeg Software Encode Engine", "Jpeg Bitstream Encode Engine"), which is linked in. The hardware engine drives [Qccamgemini8930.sys](../drivers/qccamgemini8930.md) through `\??\QcCamGeminiDriver` and its IOCTLs; the thumbnail, and the main image when the hardware can't do it, are encoded in software.  
It's part of the same Nokia camera build as the camera drivers (PDB path `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\Driver\fre\QCJpegEncoderMFT.pdb`, same workspace as [qccamgemini8930.sys](../drivers/qccamgemini8930.md)). The process that loads it (the camera pipeline / capture engine) isn't known. The trace function (`sub_10001020`) is empty: none of the log strings ("[JpegMFT] Input buffer VA: 0x%x. Length: 0x%x", "Thumbnail Enabled: %s", …) is output.

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| MFPlat.dll | `MFTRegister`, `MFTUnregister`, `MFCreateAttributes`, `MFCreateMediaType`, `MFCreateAlignedMemoryBuffer`, `MFCreateSample` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-core-file-l1-2-0.dll | `CreateFileA` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExA`, `RegQueryValueExA`, `RegCloseKey`, `RegCreateKeyExW`, `RegSetValueExW`, `RegDeleteTreeW` |
| api-ms-win-core-com-l1-1-0.dll | `CoTaskMemAlloc`, `CoTaskMemFree`, `PropVariantClear`, `StringFromCLSID` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventA`, `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-processthreads-l1-1-1.dll | `CreateThread`, `GetCurrentProcessId`, `GetCurrentThreadId` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-libraryloader-l1-1-1.dll | `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-errorhandling-l1-1-1.dll | `GetLastError` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter` |
| api-ms-win-core-sysinfo-l1-2-0.dll | `GetTickCount64`, `GetSystemTimeAsFileTime` |
| MSVCR110.dll | `malloc`, `free`, `memcpy`, `memset`, `memcmp`, `strstr`, `strcpy_s`, `_wassert`, `operator new`/`delete`, `_initterm`, `_onexit`, `__dllonexit`, `__CxxFrameHandler3`, … |

The util, profile, sysinfo, `GetCurrentProcessId` / `GetCurrentThreadId` imports and most of MSVCR110 are the Visual C++ 2012 DLL CRT startup and `/GS` security cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\??\QcCamGeminiDriver` ([Qccamgemini8930.sys](../drivers/qccamgemini8930.md)) | `CreateFileA` (`GENERIC_READ` \| `GENERIC_WRITE`, `OPEN_EXISTING`) + `DeviceIoControl`, see [Gemini driver](#gemini-driver) | Hardware JPEG encoding of the main image |

No DLL is loaded at run time, no process or other COM server is started, no file is opened: the input and output buffers come from the Media Foundation samples.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x100027E0 | none |
| 2 | `DllGetClassObject` | 0x100027FC | `REFCLSID, REFIID, void **` |
| 3 | `DllRegisterServer` | 0x10002930 | none |
| 4 | `DllUnregisterServer` | 0x10002A54 | none |

The four exports of a COM server. A global counter (`dword_100257E4`) counts the objects (class factory, MFT, encoder); `DllCanUnloadNow` returns `S_FALSE` while it isn't 0.

`DllGetClassObject` creates a class factory (24 bytes, vtable `off_10022E08`, refcount at +4, the requested CLSID at +8) without checking the CLSID, and queries it. Its `QueryInterface` (`sub_100025F0`) only accepts `IClassFactory` `{00000001-0000-0000-C000-000000000046}` (not `IUnknown`). `CreateInstance` (`sub_100026E8`) returns `CLASS_E_NOAGGREGATION` with an outer object, `CLASS_E_CLASSNOTAVAILABLE` (0x80040111) if the CLSID isn't `{83D175FD-272D-475E-8A2E-0DE0D014B6E9}`; otherwise it builds the [MFT](#mft-object) (0x130 bytes, `sub_10002AAC`), reads the [model name](#registry) for EXIF (`sub_1000205C`) and queries the requested interface.

### Startup

`start` (`_DllMainCRTStartup`, 0x10019E54): the usual CRT startup with `__security_init_cookie`; the dynamic initialisers (0x1001CE80–0x1001D300) fill the media type tables of the [MFT](#media-types). `DllMain` (`sub_100027AC`) saves the module handle (`dword_100257E0`) and calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH`. There's no ETW / WPP registration.

### Registry

`DllRegisterServer` gets the path of the DLL (`GetModuleFileNameW`), writes 3 `REG_SZ` values (`sub_10002888`) under `HKEY_LOCAL_MACHINE`, then calls `MFTRegister`:

| Key | Value | Data |
|-----|-------|------|
| `Software\Classes\CLSID\{83D175FD-272D-475E-8A2E-0DE0D014B6E9}` | (default) | `Qualcomm Jpeg Encoder` |
| `Software\Classes\CLSID\{83D175FD-272D-475E-8A2E-0DE0D014B6E9}\InProcServer32` | (default) | Path of the DLL |
| `Software\Classes\CLSID\{83D175FD-272D-475E-8A2E-0DE0D014B6E9}\InProcServer32` | `ThreadingModel` | `Both` |

`MFTRegister(CLSID, {12E17C21-532C-4A6E-8A1C-40825A736397}, "Qualcomm Jpeg Encoder", 1 = MFT_ENUM_FLAG_SYNCMFT, 4 input types, 5 output types, no attributes)`. The category GUID isn't one of the documented `MFT_CATEGORY_*` (camera specific ?). The input types are video NV12, `420O`, YUY2, UYVY; the output types are Image/JPEG and the same 4 video types (see [Media types](#media-types)). `DllUnregisterServer` deletes the CLSID key (`RegDeleteTreeW`, `ERROR_FILE_NOT_FOUND` ignored) and calls `MFTUnregister`.

At creation of each MFT, `sub_1000205C` reads two values for the EXIF "Model" tag (`RegOpenKeyExA` / `RegQueryValueExA` in `HKEY_LOCAL_MACHINE`, up to 64 bytes):

| Key | Value | Use |
|-----|-------|-----|
| `SYSTEM\Platform\DeviceTargetingInfo` | `PhoneModelName` | EXIF model if it contains the string "id" or if `ExifModelName` is missing / shorter than 2 bytes |
| `SOFTWARE\OEM\Nokia\Camera` | `ExifModelName` | EXIF model otherwise |

The same two values are read by [qccamavs8930.sys](../drivers/qccamavs8930.md) for its own EXIF data. The string is copied to the encoder (+0x8C, length at +0xCC) and replaces the model of the default EXIF table. The default make is "Nokia" and the default date/time "2002:12:08 12:00:00" (`.data` 0x10025010–0x100251C4).

### MFT object

Object of 0x130 bytes (`sub_10002AAC`, vtable `off_10022E88`) implementing `IMFTransform` `{BF94C121-5B05-4E6F-8000-BA598961414D}` only (its `QueryInterface`, `sub_10002C70`, accepts no other IID, not even `IUnknown`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 4 | Reference count (`_wassert` "m_nRefCount >= 0", `JpegEncoderMFT.cpp` line 126) |
| 0x08 | 12 | `IMFAttributes` of the 3 input streams (created on first `GetInputStreamAttributes`) |
| 0x14 | 4 | `IMFAttributes` of the output stream |
| 0x18 | 0x18 | Critical section |
| 0x30 | 12 | Current input type of the 3 streams |
| 0x3C | 4 | Current output type |
| 0x40 | 8 | Input types of stream 0 (pointer, count 4) |
| 0x48 | 8 | Input types of stream 1 (pointer, count 1) |
| 0x50 | 8 | Input types of stream 2 (pointer, count 1) |
| 0x58 | 8 | Output types (pointer, count 5) |
| 0x60 | 0xD0 | [Encoder](#encoder-object) |

| Method | Function | Comment |
|--------|----------|---------|
| `GetStreamLimits` | sub_10002CE4 | 3 inputs (min = max), 1 output |
| `GetStreamCount` | 0x10002D1C | 3, 1 |
| `GetStreamIDs`, `DeleteInputStream`, `AddInputStreams`, `ProcessEvent` | 0x10002D40 | `E_NOTIMPL`: the stream ids are 0, 1, 2 |
| `GetInputStreamInfo` | 0x10002D50 | Flags 3 (`MFT_INPUT_STREAM_WHOLE_SAMPLES` \| `SINGLE_SAMPLE_PER_BUFFER`), size 0, alignment 8 |
| `GetOutputStreamInfo` | 0x10002D8C | Flags 0x203 (whole samples, single sample per buffer, `MFT_OUTPUT_STREAM_CAN_PROVIDE_SAMPLES`), size = output sample size (encoder +0x74) once a type is set, alignment 8 |
| `GetAttributes` | sub_10002DD8 | The [attributes](#attributes) of the encoder |
| `GetInputStreamAttributes`, `GetOutputStreamAttributes` | sub_10002E0C, sub_10002E6C | Empty attribute stores |
| `GetInputAvailableType` | sub_10002F88 | Type *n* of the stream's list: `MF_MT_MAJOR_TYPE` + `MF_MT_SUBTYPE` |
| `GetOutputAvailableType` | sub_10002FCC | Needs the input type of stream 0 (else `MF_E_TRANSFORM_TYPE_NOT_SET` 0xC00D6D60). Type *n* of the output list + `MF_MT_ALL_SAMPLES_INDEPENDENT` = 1, `MF_MT_SAMPLE_SIZE` = sample size, `MF_MT_FRAME_SIZE` = size of the input |
| `SetInputType` | sub_100030A8 | See below |
| `SetOutputType` | sub_1000319C | Needs the input type of stream 0. The type must be Image/JPEG, or have the same major type and subtype as the input (pass-through); else `MF_E_INVALIDMEDIATYPE` (0xC00D36B4) |
| `GetInputCurrentType`, `GetOutputCurrentType` | sub_10003240, sub_100032D0 | Copy of the current type |
| `GetInputStatus` | sub_10003360 | `MFT_INPUT_STATUS_ACCEPT_DATA` when the stream has no pending sample |
| `GetOutputStatus` | sub_100033D8 | `MFT_OUTPUT_STATUS_SAMPLE_READY` when every stream with a type has a sample |
| `SetOutputBounds` | 0x10003460 | Returns `S_OK`, does nothing |
| `ProcessMessage` | sub_1000346C | Only `MFT_MESSAGE_COMMAND_FLUSH` (0): releases the pending input samples and the output buffer. Other messages: `S_OK` |
| `ProcessInput` | sub_100034DC | See below |
| `ProcessOutput` | sub_100035B8 | See below |

**SetInputType(stream, type, flags)**: `MF_E_INVALIDSTREAMNUMBER` (0xC00D36B3) for stream ≥ 3, `E_INVALIDARG` for flags other than `MFT_SET_TYPE_TEST_ONLY`, `MF_E_TRANSFORM_CANNOT_CHANGE_MEDIATYPE_WHILE_PROCESSING` (0xC00D6D74) while a sample is pending. The major type and subtype must be in the stream's list (`sub_10003794`). For stream 0, `sub_10001C40` reads `MF_MT_FRAME_SIZE` (width at encoder +0x68, height at +0x6C), computes the output sample size = width × height × 1.5 + 0x1C200 (encoder +0x74), then accepts only NV12 (color format 1 at +0x70). `420O` also sets +0x70 = 1 but returns `E_NOTIMPL` (the `HRESULT` is loaded before the comparison), and YUY2 / UYVY return `E_NOTIMPL`: only **NV12** can be encoded, although the 4 types are announced.

**ProcessInput(stream, sample, 0)**: needs the input type of stream 0 and the output type; `MF_E_NOTACCEPTING` (0xC00D36B5) if the stream already has a sample.
- Stream 0 (`sub_10001F38`): `IMFSample::ConvertToContiguousBuffer`, the sample and the buffer are kept (encoder +0x18 / +0x1C, one image only).
- Streams 1 and 2 (`sub_10001AE0`): the previous sample is released; if the sample has buffers, `ConvertToContiguousBuffer` (encoder +0x24 / +0x28 for stream 1, +0x30 / +0x34 for stream 2). A sample without buffer is accepted and counts as "present".

**ProcessOutput(0, 1, buffers, status)**: `E_INVALIDARG` for a count other than 1; `MF_E_TRANSFORM_NEED_MORE_INPUT` (0xC00D6D72) until every input stream that has a type has a sample: streams 1 and 2 are optional only if their type isn't set. Then `sub_10003644`:
1. Output type not Image/JPEG (pass-through): the input sample of stream 0 is returned as is.
2. Otherwise the sample of the caller is used (its first buffer), or the MFT creates one: `MFCreateAlignedMemoryBuffer(sample size, 8)` + `MFCreateSample` + `AddBuffer`.
3. The buffer is given to the encoder (`sub_10001EC0`) and the image is [encoded](#encoding-sub_10001d24) synchronously.
4. The input samples are released whatever the result.

### Media types

| List | Entries |
|------|---------|
| Stream 0 input (`dword_10025AD0`), registered input types (`dword_100259B0`) | `MFMediaType_Video` + NV12, `420O` `{4F303234-…}`, YUY2, UYVY |
| Stream 1 input (`dword_10025554`) | `MFMediaType_Binary` `{72178C25-E45B-11D5-BC2A-00B0D0F3F4AB}` + `{55A9746A-3B19-47F0-9704-ACB15A739F27}`: [EXIF tags](#exif-input-stream-1) |
| Stream 2 input (`dword_10025574`) | `MFMediaType_Binary` + `{E2F541A9-6D6B-4AAE-B61C-0EF85916EF90}`: [camera attributes](#camera-attributes-input-stream-2) |
| Output (`dword_10025A30`), registered output types (`dword_10025910`) | `MFMediaType_Image` `{72178C23-E45B-11D5-BC2A-00B0D0F3F4AB}` + `MFImageFormat_JPEG` `{19E4A5AA-5662-4FC5-A0C0-1758028E1057}`, then the 4 video types of stream 0 |

### Attributes

Attribute store of the MFT (`sub_10002248`, `MFCreateAttributes(5)`), returned by `GetAttributes`. Read with `GetUINT32` (`sub_100024C4`, default value if missing) at each encoding:

| GUID | Type | Default | Use |
|------|------|---------|-----|
| `{B00FF797-0B7C-476E-9CE5-0BC9861805A2}` | `VT_VECTOR` \| `VT_CLSID` | the 5 GUIDs below | List of the supported keys ? |
| `{AE65C4A2-7E39-44D8-8015-E15C1454C7CD}` | UINT32 | 95 | JPEG quality ? Only read for the (empty) trace: the quality is always 95 for the main image and 75 for the thumbnail |
| `{81D1395D-8033-4C26-85DA-1490CD19A63C}` | UINT32 | 0 | Encoder preference: 1 = "Software", other = "Hardware", see [Engines](#engines) |
| `{9A2E241A-3F79-43A6-AB44-788826639D7A}` | UINT32 | 0 | Rotation in degrees: 0, 90, 180 or 270 (other values → 0), main image and thumbnail |
| `{35B38EC9-B2A9-423E-A2EB-2F041F60054E}` | blob (≥ 24 bytes), not set | — | [Crop rectangle](#crop-rectangle) |
| `{483247F0-6AB8-4AA7-9A88-05567DE670F2}` | UINT32 | 1 | Thumbnail enabled |

#### Crop rectangle

Blob read by `sub_1000255C`; it's used only if every check passes, otherwise the whole frame is encoded:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | ? (not read) |
| 0x08 | 4 | Left (≥ 0, < right) |
| 0x0C | 4 | Top (≥ 0, < bottom) |
| 0x10 | 4 | Right (≥ 2, ≤ width) |
| 0x14 | 4 | Bottom (≥ 2, ≤ height) |

When the rectangle isn't the whole frame, the encoder crops (x, y, width, height rounded down to even values). The hardware engine refuses a crop, so a cropped image is encoded in software.

### Encoder object

Object of 0xD0 bytes inside the MFT (+0x60, constructor `sub_1000102C`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `IMFAttributes` (see [Attributes](#attributes)) |
| 0x04 | 4 | Output buffer descriptor of `jpege` |
| 0x08 | 4 | Output `IMFMediaBuffer` |
| 0x0C | 1 | Output buffer locked |
| 0x10 | 4 | Input buffer descriptor (Y), 88 bytes |
| 0x14 | 4 | Input buffer descriptor (CbCr) |
| 0x18 | 4 | Input `IMFSample` (stream 0) |
| 0x1C | 4 | Input `IMFMediaBuffer` |
| 0x20 | 1 | Input buffer locked |
| 0x24, 0x28, 0x2C | 4, 4, 1 | Stream 1: sample, buffer, locked |
| 0x30, 0x34, 0x38 | 4, 4, 1 | Stream 2: sample, buffer, locked |
| 0x3C | 4 | Number of images (0 or 1) |
| 0x40 | 4 | Offset of the CbCr plane: width × height |
| 0x44 | 0x18 | Critical section |
| 0x5C | 1 | Encoding in progress |
| 0x60 | 4 | Number of JPEG bytes written |
| 0x64 | 4 | "Done" event (`CreateEventW`, manual reset) |
| 0x68 | 4 | Width |
| 0x6C | 4 | Height |
| 0x70 | 4 | Color format given to `jpege` (1 = NV12) |
| 0x74 | 4 | Output sample size |
| 0x78 | 4 | EXIF table (792 bytes) |
| 0x7C | 4 | `jpege` encoder handle |
| 0x80 | 12 | EXIF parser: entries left, current entry, bytes left |
| 0x8C | 64 | EXIF model name (see [Registry](#registry)) |
| 0xCC | 4 | Length of the model name |

### Encoding (sub_10001D24)

Called by `ProcessOutput`, under the critical section of the encoder:
1. `ResetEvent` on the done event, busy flag set, previous `jpege` handle destroyed (`jpege_destroy`, `sub_10005674`).
2. Configuration (`sub_100011C4`): `jpege_get_default_config` (`sub_100051E4`: 2300 bytes, quality 75, standard quantization tables and Huffman tables for the main image and the thumbnail), engine profile 3 if the preference attribute is 1 else 0, main quality **95**, rotation from the attribute.
3. Input (`sub_1000124C`): `IMFMediaBuffer::Lock` of the image; Y plane = start of the buffer, CbCr plane = start + width × height (NV12 without padding), image source of 144 bytes: color format, width, height, 1 fragment.
4. Output (`sub_10001444`): `Lock` + `GetMaxLength` of the output buffer, destination with callback `sub_100021F4` (adds the bytes of each chunk to +0x60).
5. Crop (`sub_10001714`) and thumbnail (`sub_10001504`): if the thumbnail attribute is 1, scale = max(width / 320, height / 240) (≤ 16), thumbnail size = image size / scale rounded up to 16, quality 75, same crop as the main image.
6. EXIF (`sub_10001798`): EXIF table with the default tags and the model name, then the tags of [stream 1](#exif-input-stream-1).
7. `jpege_init` (`sub_100050FC`: 2768-byte context, event callback `sub_100021A4`), then the camera attributes of [stream 2](#camera-attributes-input-stream-2) (`sub_10001B98`).
8. Image sources checked (`sub_10005ABC`), `jpege_set_output` (`sub_10005340`), `jpege_start` (`sub_100053D0`), then `WaitForSingleObject(done event, INFINITE)`.
9. The callback `sub_100021A4` receives the end event of `jpege`: 0 (done) → `IMFMediaBuffer::SetCurrentLength(bytes written)`; 2 or 3 (error, abort) → `SetCurrentLength(0)`; then sets the done event. Event 1 is ignored.
10. Buffers unlocked, EXIF table freed, `jpege` destroyed. Any error returns `E_FAIL` and sets the output length to 0.

When the thumbnail is enabled it's encoded first (`jpege` state 1, always with profile 3), then the main image (state 2, profile of the preference). `jpege` writes the whole JPEG file (EXIF header with the thumbnail, [APP5 camera attributes](#camera-attributes-input-stream-2), main image) in the output buffer; the exact order of the header segments wasn't checked.

### Engines

`jpege` tries the engines of the profile in order (`sub_10005E2C`, table `off_10025288`) until one accepts the configuration (its check function) and starts:

| Profile | Engines | Used for |
|---------|---------|----------|
| 0 | Bitstream, Hardware, Software | Main image, preference ≠ 1 |
| 1 | Bitstream, Hardware | — |
| 2 | Bitstream, Software, Hardware | — |
| 3 | Bitstream, Software | Thumbnail, main image with preference 1 |

| Engine | Profile entry, create | Check | Comment |
|--------|-----------------------|-------|---------|
| "Jpeg Bitstream Encode Engine" | 0x1002529C, sub_1000868C | sub_100087DC | Only for the color formats 12–18 (not NV12): never used by the MFT ? Output thread `sub_10008F7C` |
| "Jpeg HARDWARE Encode Engine" | 0x100252AC, sub_1000CA24 | sub_1000CB38 | [Gemini driver](#gemini-driver). Needs rotation 0/90/180/270, width multiple of 16, no crop, 8-byte aligned Y and CbCr addresses (else not supported) |
| "Jpeg Software Encode Engine" | 0x100252A4, sub_10009368 | sub_100094D0 | ARM code (DCT and Huffman, segments `jpege_en` and `idct_fun`), thread `sub_1000A76C` |

The strings "PPF Jpeg Software Decode Engine" and "PPF Jpeg Software Encode Engine" are not referenced.

### Gemini driver

The hardware engine (functions `sub_1000CA88` init, `sub_1000CBC8` start, `sub_1000D078` abort, `sub_1000D158` destroy) opens `\??\QcCamGeminiDriver` at init (`CreateFileA`, 184-byte context, handle at +0x78). `start` copies the configuration and starts the encode thread `sub_1000CCFC`, which sends to [Qccamgemini8930.sys](../drivers/qccamgemini8930.md) (every buffer is `METHOD_NEITHER`, a user-mode pointer):

| Step | IOCTL | Input | Comment |
|------|-------|-------|---------|
| 1 | [0x23200B](../drivers/qccamgemini8930.md#ioctl-0x23200b--ioctl_kmd_gemini_device_open) open | — | |
| 2 | 0x232403 reset (command 1) | — | |
| 3 | 0x232417 input configuration (command 6) | 16 | inputFormat 1 (constant), input_cbcr_order 1 if the color format of the image is even (0 for NV12 = 1), fe_burst_length 1, byte ordering 0, height in MCUs = (height + 15) / 16, width in MCUs = width / 16 |
| 4 | 0x23241B output configuration (command 7) | 2 | we_burst_length 2, byte ordering 0 |
| 5 | 0x232413 operation configuration (command 5) | 8 | useMode 0, rotation 0° → 0, 90° → 3, 180° → 2, 270° → 1 |
| 6 | 0x23241F encode configuration (command 8) | 0x44, output 4 | See below |
| 7 | [0x232007](../drivers/qccamgemini8930.md#ioctl-0x232007--set-events) set events | 8 | Event "SharedGeminiEvent" (`CreateEventA`, manual reset), second handle 0 |
| 8 | 0x232427 input buffer enqueue (command 10) | 8 | 1 buffer, see below |
| 9 | 0x23242F JPEG output buffer enqueue (command 12) | 8 | 1 buffer, see below |
| 10 | 0x23240B encode (command 3) | 8, output 4 | Byte 0 = 1 frame, rest 0 |
| 11 | `WaitForSingleObject(event, 1000)` | | Timeout or failure → error |
| 12 | [0x232013](../drivers/qccamgemini8930.md#ioctl-0x232013--get-result) get result | output 12 | Status ≠ 0 → error; +4 output address (stored at +0xB4), +8 JPEG size (+0xB0) |
| 13 | Output (`sub_1000C8A0`) | | The JPEG bytes are given to the destination of `jpege`, in chunks of the output buffers |
| 14 | [0x23200F](../drivers/qccamgemini8930.md#ioctl-0x23200f--ioctl_kmd_gemini_device_close) close | — | Then the end event of `jpege`: 0 done, 2 error |

Encode configuration (0x44 bytes, on the stack of `sub_1000CCFC`):

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 0: restart interval |
| 0x04 | 1 | 0: default Huffman tables |
| 0x08 | 16 | 0: no Huffman table pointers |
| 0x18 | 4 | Pointer to the luma quantization table (64 bytes, from the 16-bit table of the configuration) |
| 0x1C | 4 | Pointer to the chroma quantization table (64 bytes) |
| 0x20 | 1 | 0: no file size control |
| 0x24 | 4 | 1 |
| 0x28 | 0x1C | 0: the tables are written as is (no quality scaling) |

Input buffer (24 bytes, `sub_1000C640`):

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 0 |
| 0x04 | 4 | Y address |
| 0x08 | 4 | CbCr address |
| 0x0C | 4 | Number of MCU rows: height rounded up to 16, / 16 |
| 0x10 | 4 | Luma length: width × padded height |
| 0x14 | 4 | Chroma length: luma length / 2 |

When the height isn't a multiple of 16, the image is copied into a page-aligned buffer (`malloc` of width × padded height × 1.5 + 4096, kept in `dword_10025C84`) with the padding rows at the end, or at the start for 90° and 180° (so that they end up at the bottom of the rotated image). The Y and CbCr planes must be in the same buffer for the driver (gap ≤ 16 bytes): they are, NV12 without padding.

Output buffer (12 bytes, `sub_1000C540`): +0 address of the output buffer of `jpege` (+ offsets), +4 0 (written by the driver), +8 free length rounded down to 64 bytes.

### EXIF (input stream 1)

The contiguous buffer of the stream 1 sample is a list of tags, parsed by `sub_10003AA8`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | ? |
| 0x04 | 4 | Number of entries (0 → no tag) |
| 0x08 | … | Entries |

Entry (16 + *n* bytes, the next one follows immediately):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | ? |
| 0x04 | 2 (4) | EXIF tag id (e.g. 0x010F Make) |
| 0x08 | 4 | EXIF type: 1 BYTE, 2 ASCII, 3 SHORT, 4 LONG, 5 RATIONAL, 7 UNDEFINED, 9 SLONG, 10 SRATIONAL; other types end the parsing |
| 0x0C | 4 | *n*: length of the data in bytes |
| 0x10 | *n* | Data |

The tag id is converted to the `jpege` tag index (`sub_10003D6C`, 198 tags) and the value replaces the one of the default table (`sub_10003C98`): a tag of stream 1 wins over the default make, model or date.

### Camera attributes (input stream 2)

The contiguous buffer of the stream 2 sample is a list of GUID-tagged blobs, searched by `sub_10003C1C`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | ? |
| 0x04 | 4 | Number of entries |
| 0x08 | … | Entries: 4 bytes ?, GUID (16), size *n* (4), data (*n*) |

Only the entry `{9FF18357-64AE-4882-8C1C-11273414E6CB}` is used: its data is copied by `jpege_set_mobicat_data` (`sub_100052CC`, "JpegEncoder calling jpege_set_mobicat_data() with data lenght = %d"), and written by `sub_10006620` as APP5 segments (0xFFE5): length, a byte 29 and the string "Qualcomm Camera Attributes v2", then up to 65 503 bytes of data per segment, at most 720 533 bytes in total. Its content (Qualcomm "mobicat" tuning / 3A data ?) isn't parsed.

### COM

| GUID | Use |
|------|-----|
| `{83D175FD-272D-475E-8A2E-0DE0D014B6E9}` | CLSID of the MFT "Qualcomm Jpeg Encoder" |
| `{12E17C21-532C-4A6E-8A1C-40825A736397}` | MFT category given to `MFTRegister` |
| `{00000001-0000-0000-C000-000000000046}` | `IClassFactory` |
| `{BF94C121-5B05-4E6F-8000-BA598961414D}` | `IMFTransform` |
| `{55A9746A-3B19-47F0-9704-ACB15A739F27}` | Subtype of input stream 1 (EXIF tags) |
| `{E2F541A9-6D6B-4AAE-B61C-0EF85916EF90}` | Subtype of input stream 2 (camera attributes) |
| `{9FF18357-64AE-4882-8C1C-11273414E6CB}` | Camera attributes entry written as APP5 |

### Named objects

| Name | Type | Comment |
|------|------|---------|
| `SharedGeminiEvent` | Event (manual reset), `CreateEventA` | Created for each hardware encoding, given to the Gemini driver as "JpegDone" event, closed after the result |
