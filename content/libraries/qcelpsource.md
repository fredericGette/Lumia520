## QcelpSource.dll

Media Foundation source for the QCELP / EVRC voice files (`.qcp`) of Windows Phone 8.1.  
`QcelpSource.dll` is a small in-process COM server (24 064 bytes, 118 functions, a third of them CRT). It registers a byte stream handler for the `.qcp` extension (CLSID `{C0747E08-49F2-4E2C-B2DE-5AA3B605DB01}`, "QCELP Source ByteStreamHandler"). When Media Foundation opens a `.qcp` file, the handler parses the RIFF `QLCM` header (chunks `fmt `, `vrat`, `data`) and creates a media source with one audio stream. The stream sends the raw packets in samples of at most 4 KB, 20 ms per packet. The source doesn't decode anything: the media type is a `WAVEFORMATEX` with format tag 0x7371 and nothing else, so decoding is left to a decoder MFT, probably the ADSP decoder [Qcomavsdecoder.sys](../drivers/qcomavsdecoder.md), whose input pin accepts the SubFormat `{00007371-0000-0010-8000-00aa00389b71}`.  
Its only callers are the Media Foundation source resolver (through the registry, see [Registry](#registry)) and the `IMFByteStream` it gets. It still contains the developer's `printf` debug traces ("fmt vrat=%x", "m_qcp_meta_data.qcp_size_in_packet=%d", "Entered Seek", …).

Location on the phone: ?  

### Imports

| DLL | Functions |
|-----|-----------|
| MFPlat.dll | `MFCreateEventQueue`, `MFCreateMediaEvent`, `MFCreateMediaType`, `MFInitMediaTypeFromWaveFormatEx`, `MFCreateWaveFormatExFromMFMediaType`, `MFCreateStreamDescriptor`, `MFCreatePresentationDescriptor`, `MFCreateMemoryBuffer`, `MFCreateSample`, `MFCreateAsyncResult`, `MFInvokeCallback` |
| api-ms-win-core-com-l1-1-0.dll | `CoTaskMemAlloc`, `CoTaskMemFree`, `PropVariantClear` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCreateKeyExW`, `RegSetValueExW`, `RegCloseKey`, `RegDeleteTreeW` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-eventing-classicprovider-l1-1-0.dll | `RegisterTraceGuidsW`, `UnregisterTraceGuids`, `GetTraceLoggerHandle`, `GetTraceEnableLevel`, `GetTraceEnableFlags`, `TraceMessage` |
| api-ms-win-core-libraryloader-l1-1-1.dll | `GetModuleFileNameW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-errorhandling-l1-1-1.dll | `GetLastError` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter` |
| api-ms-win-core-processthreads-l1-1-1.dll | `GetCurrentThreadId` |
| api-ms-win-core-sysinfo-l1-2-0.dll | `GetTickCount64`, `GetSystemTimeAsFileTime` |
| MSVCR110.dll | `printf`, `memcpy`, `memmove`, `memset`, `memcmp`, `operator new`/`delete`, `_initterm`, `_onexit`, `__dllonexit`, `__CxxFrameHandler3`, … |

The util, profile, processthreads and sysinfo imports and most of MSVCR110 are the Visual C++ 2012 DLL CRT startup and `/GS` security cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `*.qcp` file | `IMFByteStream` given by the source resolver to `BeginCreateObject` | The QCELP / EVRC file played, see [QCP file](#qcp-file) |
| Decoder of the media subtype `{00007371-0000-0010-8000-00AA00389B71}` | chosen by the Media Foundation topology, not by this DLL | Decoding of the packets, probably [Qcomavsdecoder.sys](../drivers/qcomavsdecoder.md) ? |

No DLL is loaded at run time, no process or other COM server is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllCanUnloadNow` | 0x100039F0 | none |
| 2 | `DllGetClassObject` | 0x10003A4C | `REFCLSID, REFIID, void **` |
| 3 | `DllRegisterServer` | 0x10003B80 | none |
| 4 | `DllUnregisterServer` | 0x10003CA4 | none |

The four standard exports of a COM server. A global counter (`dword_10007240`) counts the objects created by the DLL (class factory, handler, source); `DllCanUnloadNow` returns `S_FALSE` while it isn't 0, and also unregisters the WPP trace GUIDs (see [Startup](#startup)).

`DllGetClassObject` creates a class factory (24 bytes, vtable `off_100056C0`, refcount at +4, the requested CLSID at +8) and queries it for the requested interface (`IUnknown` or `IClassFactory`, otherwise `E_NOINTERFACE`). Its `CreateInstance` (`sub_10003900`) returns `CLASS_E_NOAGGREGATION` with an outer object, `CLASS_E_CLASSNOTAVAILABLE` (0x80040111) if the CLSID isn't `{C0747E08-49F2-4E2C-B2DE-5AA3B605DB01}`; otherwise it creates the [byte stream handler](#byte-stream-handler) (`sub_10001008`).

### Startup

`start` (`_DllMainCRTStartup`, 0x100042B0): the usual CRT startup with `__security_init_cookie`, then `DllMain` (`sub_1000398C`).  
`DllMain` registers the WPP control GUID `{448CDB1F-A5D2-45E5-A12E-9E960577B3FF}` (`RegisterTraceGuidsW`, callback `sub_10003750`) and, on `DLL_PROCESS_ATTACH`, saves the module handle (`dword_1000723C`) and calls `DisableThreadLibraryCalls`. There's no other initialisation: everything is done when Media Foundation creates the handler.

### Registry

`DllRegisterServer` gets the path of the DLL (`GetModuleFileNameW`) and writes 4 `REG_SZ` values (`sub_10003AD8`: `RegCreateKeyExW` + `RegSetValueExW`), all under `HKEY_LOCAL_MACHINE`:

| Key | Value | Data |
|-----|-------|------|
| `Software\Classes\CLSID\{C0747E08-49F2-4E2C-B2DE-5AA3B605DB01}` | (default) | `QCELP Source ByteStreamHandler` |
| `Software\Classes\CLSID\{C0747E08-49F2-4E2C-B2DE-5AA3B605DB01}\InProcServer32` | (default) | Path of the DLL |
| `Software\Classes\CLSID\{C0747E08-49F2-4E2C-B2DE-5AA3B605DB01}\InProcServer32` | `ThreadingModel` | `Both` |
| `Software\Microsoft\Windows Media Foundation\ByteStreamHandlers\.qcp` | `{C0747E08-49F2-4E2C-B2DE-5AA3B605DB01}` | `QCELP Source ByteStreamHandler` |

`DllUnregisterServer` deletes the CLSID key and the `.qcp` key with `RegDeleteTreeW` (`ERROR_FILE_NOT_FOUND` is ignored). On the phone these keys are probably written by the image, not by `DllRegisterServer` ?

### Byte stream handler

Object of 8 bytes (vtable `off_1000528C`, refcount at +4) implementing `IMFByteStreamHandler` `{BB420AA4-765B-4A1F-91FE-D6A8A143924C}`:

| Method | Function | Comment |
|--------|----------|---------|
| `BeginCreateObject` | sub_100011B8 | See below |
| `EndCreateObject` | sub_1000128C | Takes the source from the `IMFAsyncResult` object, queries `IMFMediaSource` and returns it with `MF_OBJECT_MEDIASOURCE` (0) |
| `CancelObjectCreation` | 0x10001320 | `E_NOTIMPL` |
| `GetMaxNumberOfBytesRequiredForResolution` | 0x10001330 | Returns 6 |

`BeginCreateObject(byteStream, url, flags, props, cancelCookie, callback, state)` works synchronously:
1. `E_INVALIDARG` if the byte stream, the URL or the callback is NULL; `*cancelCookie` = NULL.
2. Creates the [media source](#media-source) (`sub_10002188`).
3. Under the lock of the source: `MF_E_INVALIDREQUEST` (0xC00D36B2) if it already has a parser; otherwise creates the [parser](#parser) on the byte stream (`sub_10001598`) and reads the header (`ParseHeader`, `sub_1000166C`). On failure the source is shut down.
4. On success, `MFCreateAsyncResult(source, callback, state)` then `MFInvokeCallback`. On failure the error is returned directly and the callback isn't invoked.

The URL, the flags and the property store aren't used: the file type comes only from the extension registration and the header check.

### Media source

Object of 56 bytes (`sub_100021F4`, vtable `off_100053E0`) implementing `IMFMediaSource` `{279A808D-AEC7-40C8-9C6B-A6B492C78A66}` (and `IMFMediaEventGenerator`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 4 | Event queue (`MFCreateEventQueue`) |
| 0x08 | 4 | Presentation descriptor, built on first use |
| 0x0C | 4 | [Media stream](#media-stream), created by the first `Start` |
| 0x10 | 4 | Reference count |
| 0x14 | 0x18 | Critical section |
| 0x2C | 4 | Shut down: every method then returns `MF_E_SHUTDOWN` (0xC00D3E85) |
| 0x30 | 4 | State: 0 stopped, 1 paused, 2 started |
| 0x34 | 4 | [Parser](#parser) |

| Method | Function | Comment |
|--------|----------|---------|
| `GetEvent`, `BeginGetEvent`, `EndGetEvent`, `QueueEvent` | sub_10002458, sub_100023A0, sub_100023FC, sub_100024D4 | Forwarded to the event queue |
| `GetCharacteristics` | sub_100025B0 | 6 = `MFMEDIASOURCE_CAN_SEEK` \| `MFMEDIASOURCE_CAN_PAUSE` |
| `CreatePresentationDescriptor` | sub_10002538 | Builds the descriptor if needed (`sub_100029F4`, below) and returns a clone |
| `Start` | sub_10002608 | See below |
| `Stop` | sub_100028AC | State 0, flushes the pending requests of the stream, `MEStreamStopped` (208) then `MESourceStopped` (207) |
| `Pause` | sub_10002814 | Only from the started state (else `MF_E_INVALID_STATE_TRANSITION`, 0xC00D3E82): `MEStreamPaused` (210), `MESourcePaused` (209), state 1 |
| `Shutdown` | sub_1000293C | Shuts down the stream and the event queues, frees the parser, marks the source as shut down |

**Presentation descriptor** (`sub_100029F4`): `MFCreateMediaType` + `MFInitMediaTypeFromWaveFormatEx` with the 18-byte `WAVEFORMATEX` of the parser (format tag 0x7371, all other fields 0, see [ParseHeader](#parseheader-sub_1000166c)), one stream descriptor (id 0) with this single type set as current type, `MFCreatePresentationDescriptor`, stream 0 selected, and `MF_PD_DURATION` `{6C990D33-BB8E-477A-8598-0D5D96FCD88A}` = the duration of the parser (+0xD0).

**Start(pd, timeFormat, startPosition)** (`sub_10002608`):
1. `E_INVALIDARG` if the descriptor or the position is NULL; `MF_E_UNSUPPORTED_TIME_FORMAT` (0xC00D36C5) if the time format isn't `GUID_NULL`.
2. Position: `VT_I8` → that time (a seek if the source isn't stopped); `VT_EMPTY` → the current time of the stream if the source isn't stopped (restart from pause), else 0; another type → `MF_E_UNSUPPORTED_TIME_FORMAT`.
3. Checks the descriptor (`sub_10002AF4`): exactly one stream, selected, whose current type converted back with `MFCreateWaveFormatExFromMFMediaType` must be equal to the parser's `WAVEFORMATEX` (else `MF_E_INVALIDMEDIATYPE` 0xC00D36B4; not one selected stream → `MF_E_UNSUPPORTED_REPRESENTATION` 0xC00D36B7).
4. Creates the stream on first start and sends `MENewStream` (205), or sends `MEUpdatedStream` (206) with the existing stream (`sub_10002C0C`).
5. Positions the parser (`sub_10003650`): `MF_E_INVALIDREQUEST` if the position is after the duration, else [Seek](#seek-sub_10001f64), and the stream time = position.
6. Events with the position as `VT_I8`: `MESourceSeeked` (203) and `MEStreamSeeked` (204) for a seek; otherwise `MESourceStarted` (201, with `MF_EVENT_SOURCE_ACTUAL_START` `{A8CC55A9-6B31-419F-845D-FFB351A2434B}` when restarting with `VT_EMPTY`) and `MEStreamStarted` (202).
7. After a seek the pending sample requests are dropped (`sub_1000357C`); after a start they're served (`sub_10003444`). State 2. On failure an `MEError` (1) event is queued with the HRESULT.

### Media stream

Object of 88 bytes (`sub_10002CF4`, vtable `off_100053B8`) implementing `IMFMediaStream` `{D182108F-4EC6-443F-AA42-A71106EC825F}`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 4 | Reference count |
| 0x08 | 0x18 | Critical section |
| 0x20 | 4 | Shut down |
| 0x28 | 8 | Time of the next sample (100 ns) |
| 0x30 | 4 | Discontinuity: set by every start / seek, never cleared in the binary |
| 0x34 | 4 | End of stream reached |
| 0x38 | 4 | [Parser](#parser) |
| 0x3C | 4 | Event queue |
| 0x40 | 4 | Media source |
| 0x44 | 4 | Stream descriptor |
| 0x48 | 0x0C | List of the samples requested while paused |

`GetMediaSource` (sub_10003028) and `GetStreamDescriptor` (sub_100030A0) return the objects above (`E_UNEXPECTED` if missing). The event methods are forwarded to the event queue.

**RequestSample(token)** (`sub_10003110`):
1. `MF_E_END_OF_STREAM` (0xC00D3E84) after the end of stream; `MF_E_INVALIDREQUEST` if the source is stopped.
2. Builds a sample (`ReadSample`, `sub_1000325C`): `MFCreateMemoryBuffer` of min(4096, remaining bytes), filled with whole packets by `ReadPackets` (`sub_10001350`), current length set, `MFCreateSample` + `AddBuffer`, sample time = stream time, sample duration = 200 000 (20 ms) × number of packets, `MFSampleExtension_Discontinuity` `{9CDF01D9-A0F0-43BA-B077-EAA06CBD728A}` = 1 if the discontinuity flag is set. The stream time is then advanced by the duration.
3. The token, if any, is attached as `MFSampleExtension_Token` `{8294DA66-F328-4805-B551-00DEB4C57A61}`.
4. Source paused: the sample is kept in the list (sent by the next `Start`). Otherwise `MEMediaSample` (213) with the sample (`sub_100033B4`); then if the byte stream is at its end and no byte of the data chunk remains (`sub_10001ED4`), `MEEndOfStream` (212) and, from the source, `MEEndOfPresentation` (211).

### Parser

Object of 0x1100 bytes created by `sub_10001598` on the byte stream (`m_qcp_meta_data` in the traces):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Always 1 |
| 0x04 | 1 | `fmt ` major version |
| 0x05 | 1 | `fmt ` minor version |
| 0x08 | 16 | Codec GUID |
| 0x18 | 4 | 1 = EVRC GUID, 0 = QCELP GUID |
| 0x1C | 2 | Codec version |
| 0x1E | 2 | Average bit rate (`qcp_average_bps`) |
| 0x20 | 2 | Packet size (fixed rate) |
| 0x22 | 2 | Block size |
| 0x24 | 2 | Sampling rate |
| 0x26 | 2 | Sample size |
| 0x28 | 4 | Number of rates |
| 0x2C | 16 | Rate map: 8 × (packet size − 1, rate octet) |
| 0x4C | 4 | `vrat` variable rate flag (0 = fixed rate, no `vrat` chunk) |
| 0x50 | 4 | Codec type (see below) |
| 0x54 | 4 | `vrat` size in packets (`qcp_size_in_packet`) |
| 0x94 | 4 | `data` chunk size |
| 0xBC | 4 | Offset of the first packet |
| 0xC0 | 4 | Codec type, copy |
| 0xC4 | 4 | `IMFByteStream` |
| 0xC8 | 4 | `WAVEFORMATEX` (`CoTaskMemAlloc`, 18 bytes) |
| 0xCC | 4 | Size of the `WAVEFORMATEX`, 18 |
| 0xD0 | 8 | Duration: 20 × size in packets (see below) |
| 0xF0 | 8 | Bytes of packets not read yet |
| 0xF8 | 0x1000 | Read buffer |
| 0x10F8 | 4 | Position in the read buffer (0x1000 = empty) |

### QCP file

The file is the Qualcomm "QCP" RIFF format (RFC 3625). Every multi-byte field is little endian. The chunks are read at fixed places: the header must be RIFF, `fmt `, then optionally `vrat`, then `data`. Other chunks (`labl`, `offs`, `cnfg`, `text`) aren't skipped: a file that has one before `data` is rejected.

| Offset | Size | Content | Check |
|--------|------|---------|-------|
| 0x00 | 4 | `RIFF` | Required |
| 0x04 | 4 | RIFF size | Not used |
| 0x08 | 4 | `QLCM` | Required |
| 0x0C | 4 | `fmt ` | Required |
| 0x10 | 4 | `fmt ` size *n* | Next chunk at 0x14 + *n* |
| 0x14 | 1, 1 | Major, minor version | QCELP: must be 1.0 |
| 0x16 | 16 | Codec GUID | `{5E7F6D41-B115-11D0-BA91-00805FB4B97E}` or `{5E7F6D42-…}` (QCELP 13K), `{E689D48D-9076-46B5-91EF-736A5100CEB4}` (EVRC); anything else is rejected (SMV too) |
| 0x26 | 2 | Codec version | |
| 0x28 | 80 | Codec name | Not read |
| 0x78 | 2, 2, 2, 2, 2 | Average bps, packet size, block size, sampling rate, sample size | |
| 0x82 | 4 | Number of rates | |
| 0x86 | 16 | Rate map | |
| 0x96 | 20 | Reserved | |
| 0x14 + *n* | 4 + 4 + 4 + 4 | `vrat`, size *m*, variable rate flag, size in packets | Optional; absent → flag 0, *m* = 0 |
| next | 4 + 4 | `data`, size | Required; the packets follow |

A failed check returns `MF_E_INVALID_FILE_FORMAT` (0xC00D36BE).

#### ParseHeader (sub_1000166C)

1. `CheckRiff` (`sub_100017F0`): reads 12 bytes at 0, checks `RIFF` / `QLCM`.
2. `ReadFmt` (`sub_100018EC`): reads 0x9E bytes at 0x0C, checks `fmt ` and the GUID, copies the fields into the parser.
3. `ReadVrat` (`sub_10001C10`): reads 16 bytes after `fmt `; if they are a `vrat` chunk, stores the flag and the size in packets. Then sets the codec type (+0x50 / +0xC0) from the average bit rate. As +0x00 is always 1, only the first part is reachable:

| Average bps | Variable rate flag = 1 | Otherwise |
|-------------|------------------------|-----------|
| 13 000 – 14 399 | 3 | 1 |
| 6 000 – 7 199 | 4 | 2 |
| other | 6 | 6 |

   (Dead branch: 5 when the major version is 2, else 0.) The codec type isn't used anywhere else in the DLL.
4. `ReadData` (`sub_10001E10`): reads 8 bytes, checks `data`, stores its size. The offset of the first packet (+0xBC) = 0x0C + (`fmt ` size + 8) + (`vrat` size + 8, or 0) + 8.
5. Builds the 18-byte `WAVEFORMATEX`: only `wFormatTag` = 0x7371 is set; channels, sample rate, bits and `cbSize` are 0.
6. Bytes of packets = `IMFByteStream::GetLength` − offset of the first packet (the `data` size isn't used for this).
7. Duration (+0xD0) = 20 × size in packets when the `vrat` chunk gives it, else 0. This is the duration in ms, but it's used as a 100 ns value (`MF_PD_DURATION`, seek limit): the duration announced is 10 000 times too short ? A file without `vrat` has duration 0 and can only be started at 0.

#### Packets

Size of a packet, used by `ReadPackets` (`sub_10001350`) and `Seek`:
- fixed rate (flag 0): the packet size of `fmt ` (+0x20);
- variable rate (flag ≠ 0 and < 0xFFFF0000): the first byte of the packet is its rate octet; it's looked up in the 8 rate map entries, and the size is the matching entry's size + 1 (the rate byte itself). No matching entry → `MF_E_INVALID_STREAM_DATA` (0xC00D36CB).

`ReadPackets` copies whole packets from the 4 KB read buffer into the sample buffer (refilling it with `IMFByteStream::Read`, a packet can straddle two refills) until the next packet wouldn't fit, and counts 200 000 (20 ms) per packet.

#### Seek (sub_10001F64)

`Seek(parser, position)`: `MF_E_INVALIDREQUEST` if the position is after the duration. Otherwise it goes back to the first packet, reads the file 4 KB at a time and walks the packets (20 ms each) until the time reaches the position or the stream ends, then sets the byte stream position to that packet and recomputes the bytes not read (`GetLength` − position). Every seek reads the file from the start.

### ETW

WPP tracing only: control GUID `{448CDB1F-A5D2-45E5-A12E-9E960577B3FF}` (registered in `DllMain`, `RegisterTraceGuidsW`). `TraceMessage` (`sub_10003728`, message GUID `{DC8A829C-EA71-BDE0-05E1-D8F87BAE6283}`) is only called at the start and end of `DllRegisterServer` (messages 10 and 11) and `DllUnregisterServer`. The parser's traces are `printf`s.

### COM

| GUID | Use |
|------|-----|
| `{C0747E08-49F2-4E2C-B2DE-5AA3B605DB01}` | CLSID of the QCELP byte stream handler |
| `{00000001-0000-0000-C000-000000000046}` | `IClassFactory` |
| `{BB420AA4-765B-4A1F-91FE-D6A8A143924C}` | `IMFByteStreamHandler` |
| `{279A808D-AEC7-40C8-9C6B-A6B492C78A66}` | `IMFMediaSource` |
| `{2CD0BD52-BCD5-4B89-B62C-EADC0C031E7D}` | `IMFMediaEventGenerator` |
| `{D182108F-4EC6-443F-AA42-A71106EC825F}` | `IMFMediaStream` |
