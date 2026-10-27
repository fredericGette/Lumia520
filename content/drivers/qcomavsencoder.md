## Qcomavsencoder.sys

Qualcomm AVS (Audio Video Subsystem) hardware audio encoder.  
It's the mirror of [qcomavsdecoder.sys](./qcomavsdecoder.md): a KS/AVStream minidriver (`ks.sys`) that exposes one encoder filter. PCM goes in through the input pin, compressed audio (AAC, AMR-NB) comes out of the output pin. The encoding is done by the ADSP (QDSP6): the driver opens an encoder stream through the Q6 audio driver [qcq6ad8930.sys](./qcq6ad8930.md) and passes it physically contiguous buffers. Most of the code is shared with the decoder (same source file names, same `Q6AudioHw` class, same asserts naming `AvsDecodeFilter.cpp`).  
Unlike the decoder, it has a test mode that dumps the streams to files on `C:` (see [Test mode](#test-mode)), and only **one encoder stream can exist at a time**.  
PDB path: `P:\audio\rel\8.3.1\arm\Release\qcomavsencoder.pdb`. Source files named in the asserts: `device.cpp`, `AvsDecodeFilter.cpp`, `inputpin.cpp`, `outputpin.cpp`, `HwStreamHelper.cpp`, `Q6AudioHw.cpp`, `savedata.cpp`.

There's no named device object and no symbolic link: the filter is reached through its KS device interfaces (see [Filter](#filter)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>` ?  

There's no parameters in the driver's own registry key. The only value read is in the key of the **decoder** service (`sub_402930`, at each stream opening):  
| Registry value | value | comment |
|----------------|-------|---------|
| `HKLM\System\ControlSet001\Services\AVSDecoder\TestMode` | 0 | REG_DWORD. 1 enables the [test mode](#test-mode). Missing key or value → 0 |

GUID of the ETW provider (manifest based, `McGenEventRegister` in `DriverEntry`, same provider as qcomavsdecoder.sys). Only one event is written, id 201 (`.rdata:0x409170`) with "LOGGING START" / "LOGGING STOP", the source file and the line:  
`{9893ae6b-b6a5-4f76-a42d-210deaef83e2}`

GUID of the WPP control (`.rdata:0x409140`, all the other traces):  
`{dafad017-4ac4-40f0-a1b1-e51d5c9d0e18}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{5F51A34C-6834-479D-9EA2-EAFA622524BA}` | [qcq6ad8930.sys](./qcq6ad8930.md) (`\_SB.Q6AD`) | Q6 audio. [IOCTL 0xADAD2BA1](#ioctl-0xadad2ba1--get-q6-entry-points) returns the entry points, then all the commands go through them (see [Q6 audio entry points](#q6-audio-entry-points)) |
| — | ks.sys | AVStream class driver |
| `\DosDevices\C:\inputfileforencode.dat`, `\DosDevices\C:\STREAM_HOST.wav` | file system | See [Test mode](#test-mode) |

### Driver initialisation

`DriverEntry` (`FxDriverEntryWorker` 0x405778) initialises WPP, calls `KsInitializeDriver(DriverObject, RegistryPath, &DeviceDescriptor)` (descriptor `.rdata:0x409260`, no static filter descriptor) and registers the ETW provider.  
`KSDEVICE_DISPATCH` (`.rdata:0x409228`):  
| Callback | Function | Comment |
|----------|----------|---------|
| Add | sub_40C438 | Allocates the 16-byte device context (pool tag `KCNw`) |
| Start | sub_4050E0 → sub_40C530 | See below |
| Stop | sub_405100 → sub_40C650 | Unmaps (`sub_405450`) and frees (`sub_4054EC`) the buffers, releases the Q6 device (vtable +0x24), unregisters ETW and WPP |
| others | 0 | Not handled |

At start, the device:
1. creates the filter factory: `KsCreateFilterFactory(…, &FilterDescriptor, L"GLOBAL", NULL, KSCREATE_ITEM_FREEONSTOP (8), …)` (descriptor `.rdata:0x4093C0`);
2. allocates the [buffers](#buffers) shared with the ADSP (`sub_405554`);
3. creates the `Q6AudioHw` object (140 bytes, vtable `.rdata:0x409190`, `sub_402BEC`).

The Q6 device is opened at the creation of the first filter (`sub_40526C`, called by the filter constructor `sub_405C50`): `Q6AudioHw::Init` (vtable +0x00, `sub_402C24`) gets the entry points of [qcq6ad8930.sys](./qcq6ad8930.md), then the 2 buffer regions are mapped in the ADSP with [command 0xADAD2B45](#q6-audio-entry-points). No `Q6AudioHw` object → `STATUS_INVALID_DEVICE_STATE` (0xC0000184), init or map failure → `STATUS_DEVICE_CONFIGURATION_ERROR` (0xC0000182).

### Filter

| Property | Value |
|----------|-------|
| `KSFILTER_DESCRIPTOR` | `.rdata:0x4093C0` |
| Flags | 1 (`KSFILTER_FLAG_DISPATCH_LEVEL_PROCESSING`) |
| Reference string | `GLOBAL` |
| Create / Close | sub_40C72C / sub_40C840 |
| Automation table | `.rdata:0x4092C4`, 1 property set (see below) |
| Pins | 2 (`.rdata:0x4092F0`, 0x50 bytes each) |
| Connection | input pin 0 → output pin 1 (topology `.rdata:0x4093B0`) |

Reference GUID: `KSNAME_Filter` `{9b365890-165f-11d0-a195-0020afd156e4}`.  
Categories:  
| GUID | Category |
|------|----------|
| `{19689bf6-c384-48fd-ad51-90e58c79f70b}` | `KSCATEGORY_ENCODER` |
| `{91c64bd0-f91e-4d8c-9276-db248279d975}` | ? |

Property set `{b9d19a3e-f897-429c-bc46-8138b7272b2d}` (`.rdata:0x4092B0`): one property, id 0, get only, MinProperty 24, MinData 4. The handler (`sub_40600C`) only checks the set GUID and the `KSPROPERTY_TYPE_GET` flag and returns `STATUS_SUCCESS` without writing anything (stub), else `STATUS_NOT_SUPPORTED` (0xC00000BB).

The filter create (`sub_40C72C`) allocates the `AvsDecodeFilter` object (0xD0 bytes, tag `KCNw`) and fails with `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A) when the [buffer set](#buffers) is in use: **at most 1 encoder filter can exist at the same time**.

| Pin | Input (0) | Output (1) |
|-----|-----------|------------|
| Dispatch | `.rdata:0x409400` | `.rdata:0x409498` |
| Create / Close | sub_40C994 / sub_40C93C | sub_40CEA8 / sub_40CE50 |
| Process | thunk 0x406120 → sub_406184 (`CInputPin::InputPinProcess`) | thunk 0x406A60 → sub_406B40 (`COutputPin::OutputPinProcess`) |
| SetDataFormat | sub_406908 | sub_4072C0 |
| SetDeviceState | sub_406100 → sub_406648 | thunk 0x406A40 → sub_4070E4 |
| Intersect handler | sub_40CA68 | sub_40CFA8 |
| Data flow | `KSPIN_DATAFLOW_IN` | `KSPIN_DATAFLOW_OUT` |
| Communication | `KSPIN_COMMUNICATION_BOTH` | `KSPIN_COMMUNICATION_BOTH` |
| Flags | 0x10020 (`INITIATE_PROCESSING_ON_EVERY_ARRIVAL`, `PROCESS_IN_RUN_STATE_ONLY`) | 0 |
| Instances | 1, 0 necessary | 1, 0 necessary |
| Category | `KSCATEGORY_AUDIO` `{6994ad04-93ef-11d0-a3cc-00a0c9223196}` | `KSCATEGORY_AUDIO` |
| Name GUID | `{f2aec663-55d0-4775-b33c-e63832492561}` | `{47a4fa20-a251-11d1-a050-0000f8004788}` |
| Data ranges | 1: PCM (`WAVE_FORMAT_PCM`), 2 channels max, 8–16 bits, 8000–48000 Hz | 3, see below |

The input intersect handler (`sub_40CA68`) builds an 82-byte format (`KSDATAFORMAT` + `WAVEFORMATEX`) from the maximum values of the range, with the format tag 1 when the SubFormat is PCM. SetDataFormat (`sub_406908`) only checks that the format has at least 82 bytes and stores the `WAVEFORMATEX` in the filter (`+0x94`).

Data ranges of the output pin (`KSDATARANGE_AUDIO`, major format `KSDATAFORMAT_TYPE_AUDIO`, specifier `KSDATAFORMAT_SPECIFIER_WAVEFORMATEX`). The intersect handler (`sub_40CFA8`) builds the `WAVEFORMATEX` below; the "encoder type" is the value sent to the ADSP in the [media format](#media-format):  
| SubFormat | Format | Channels | Bits | Sample rate | Format built | Encoder type |
|-----------|--------|----------|------|-------------|--------------|--------------|
| `{00001610-0000-0010-8000-00aa00389b71}` | HE-AAC (`WAVE_FORMAT_MPEG_HEAAC`) | 2 | 8–16 | 8000–48000 | 96 bytes: tag 0x1610, `nAvgBytesPerSec` 12000, `HEAACWAVEINFO` with `wPayloadType` 0 (raw), `wAudioProfileLevelIndication` 0x29, AudioSpecificConfig `12 10` (AAC LC, 44100 Hz, 2 channels) | 7 |
| `{00007631-0000-0010-8000-00aa00389b71}` | AMR-NB ? | 1 | 13 | 8000 | 82 bytes: tag 0x7631, `nAvgBytesPerSec` 1525 (12.2 kbit/s) | 0xA |
| `{00007a21-0000-0010-8000-00aa00389b71}` | AMR-NB (`WAVE_FORMAT_GSM_AMR_CBR` ?) | 1 | 2–16 | 8000 | 82 bytes: tag 0x7A21, `nAvgBytesPerSec` 1525 | 0xA |

A caller range with the SubFormat `{e06d802b-db46-11cf-b4d1-00805f6cbbea}` (`MEDIASUBTYPE_MPEG2_AUDIO`) also gets the AAC format, but with an 82-byte size (the `HEAACWAVEINFO` fields are written after the 82 bytes anyway).  
The output SetDataFormat (`sub_4072C0`) accepts any format of at least 82 bytes and stores its `WAVEFORMATEX` in the filter (`+0x98`). Any other output format tag at the stream opening → no encoder type (0) and a trace.  
Both pins have the same allocator framing (`.rdata:0x409428`, `.rdata:0x4095D8`): 1 item, memory type `{4a6d5fc4-7895-11d1-b069-00a0c9062802}`.

### Stream life cycle

The encoder stream is opened when one of the pins goes from `KSSTATE_STOP` to `KSSTATE_ACQUIRE` (`sub_40589C`):
1. allocates the `HwStreamHelper` object (0x548 bytes, `sub_4056D8` / `sub_401274`);
2. takes the [buffer set](#buffers) (`sub_405138`);
3. opens the Q6 stream (`sub_4018F8`): creates `C:\inputfileforencode.dat` and reads `TestMode` (see [Test mode](#test-mode)), calls the open function with the input and output `WAVEFORMATEX` and the callback `sub_401374`, splits the buffers (`sub_402790`), sends [command 0xADAD2B79](#media-format) (media format), then starts the read thread (`sub_401C5C`), which waits for "output buffer free" events and sends the [read](#write-and-read-buffers) requests (`sub_401D5C`).

| Pin state change | Function | Q6 calls |
|------------------|----------|----------|
| Input or output pin STOP → ACQUIRE | sub_40589C | open, 0xADAD2B79 |
| Output pin → RUN | sub_401E68 | 0xADAD2B4D (run ?), then wakes up the read thread. Filter state 4 |
| Input pin RUN → PAUSE, filter state 4 | sub_40534C(1) | none: vtable +0x48 (`sub_403988`) only clears `Q6AudioHw+0x24`. Filter state 3 |
| Input pin PAUSE → RUN, filter state 3 | sub_40534C(0) | 0xADAD2B59 (resume ?). Filter state 4 |
| Output pin → ACQUIRE | sub_405EA0 | 0xADAD2B5D (?), only when the output pin flag `+0x3C` is 1, which is never set: dead code |
| Input pin → STOP (from another state) | sub_405DB4 | 0xADAD2B7D (end of stream) |
| Both pins → STOP | sub_401ECC, sub_4051FC | 0xADAD2B51 (pause ?), close function, stops the read thread, frees the buffer set |

Input data (`CInputPin::InputPinProcess`, `sub_4021B0`): the bytes of each stream pointer are copied into the free input buffers (8 KB each) and each buffer is passed to the [write function](#write-and-read-buffers). A stream pointer with the end-of-stream flag sends [command 0xADAD2B7D](#q6-audio-entry-points) instead.  
Output data (`COutputPin::OutputPinProcess`, `sub_4024C8`): each output buffer filled by the ADSP holds one encoded frame. When the output stream pointer has room for it, it's copied with:
* the time stamp of the ADSP (µs × 10), or the previous one for the last buffer;
* a duration of 1024 samples for AAC (1024 × 10⁷ / `nSamplesPerSec`), 200000 (20 ms) for the AMR formats;
* the flags `TIMEVALID`, `DURATIONVALID`, and `ENDOFSTREAM` after the end of stream event.

Nothing available → the IRP stays pending.

### Buffers

Allocated once at device start (`sub_405554`) with `MmAllocateContiguousMemorySpecifyCache` (`MmNonCached`, physical addresses 0x29000000–0xFFFFFFFF, no boundary, must be 4 KB aligned). There is only 1 set (table `.data:0x40A30C`, 24 bytes: input VA, input size, output VA, output size, free flag, mapped flag):  
| Region | Size | Split | Use |
|--------|------|-------|-----|
| Input | 163840 (0x28000) | 20 buffers of 8 KB | PCM written to the ADSP |
| Output | 20480 (0x5000) | 5 buffers of 4 KB | Encoded frames read from the ADSP |

The 2 regions are mapped in the ADSP with command 0xADAD2B45 when the Q6 device is opened, and unmapped with 0xADAD2B49 at device stop.

### Test mode

When `HKLM\System\ControlSet001\Services\AVSDecoder\TestMode` = 1 at the stream opening (read twice by `sub_402930`, into `HwStreamHelper+0x4FC` and `+0x500`):
* every input buffer is also appended to `\DosDevices\C:\inputfileforencode.dat` (raw PCM, `ZwWriteFile` in `sub_4021B0`);
* every output buffer is saved by `savedata.cpp` into `\DosDevices\C:\STREAM_HOST.wav` (name built with `"%s_%s.wav"`, `"\DosDevices\C:\STREAM"`, `"HOST"`): RIFF/`WAVE`/`fmt `/`data` header (`sub_40437C`), data written by 15 work items (`sub_40482C`, `sub_40490C`) from a 32 KB ring buffer of 2 frames.

> [!NOTE]
> `C:\inputfileforencode.dat` is created (`FILE_OPEN_IF`, `FILE_APPEND_DATA`) at **every** stream opening, even when `TestMode` is 0; the handle is global (`.data:0x40A308`) and closed at the stream close. Only the writes depend on `TestMode`.  
> With `TestMode` = 1, the WAV format pointer passed to `sub_404A1C` (`HwStreamHelper+0x4EC`) is never set: it dereferences NULL, so the test mode probably crashes the phone ?

---

### IOCTL 0xADAD2BA1 — get Q6 entry points

This IOCTL is sent by Qcomavsencoder.sys to [qcq6ad8930.sys](./qcq6ad8930.md) (interface `{5F51A34C-…}`), by `Q6AudioHw::Init` (`sub_402C24` → `sub_402CB0`: `IoGetDeviceInterfaces` + `IoGetDeviceObjectPointer(GENERIC_READ | GENERIC_WRITE)`, then `sub_402E5C` → `sub_402EF0`).

| Property | Value |
|----------|-------|
| Device | 0xADAD |
| Function | 0xAE8 (2792) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get Q6 entry points | interface `{5F51A34C-6834-479D-9EA2-EAFA622524BA}` | 0 | 20 |

Outputbuffer (stored at `Q6AudioHw+0x78`), same as for [qcomavsdecoder.sys](./qcomavsdecoder.md#ioctl-0xadad2ba1--get-q6-entry-points):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Open stream: `handle = fn(1, message, 116)`, see [Open message](#open-message) |
| 04-07 | ? | Close stream: `fn(handle)` |
| 08-0B | ? | Write buffer: `fn(handle, buffer, 40)`, see [Write and read buffers](#write-and-read-buffers) |
| 0C-0F | ? | Read buffer: `fn(handle, buffer, 40)` |
| 10-13 | ? | Command: `fn(handle, command, buffer, size)` |

Normal (not internal) IOCTL built with `IoBuildDeviceIoControlRequest`, waited for 5 s at most. Timeout → 0x80005002, no device → 0x80005003, interface not found → 0x80005001.

### Q6 audio entry points

`Q6AudioHw` vtable (`.rdata:0x409190`) and the commands sent with the command function (offset 0x10 above). The handle is the one returned by the open function, except for the memory map commands (0x10000).  
| Vtable | Function | Command | Handle | Buffer | Size | Comment |
|--------|----------|---------|--------|--------|------|---------|
| +0x00 | sub_402C24 | [IOCTL 0xADAD2BA1](#ioctl-0xadad2ba1--get-q6-entry-points) | | | | Init |
| +0x10 | sub_403C94 | write function | stream | 40 bytes | 40 | Write an input buffer |
| +0x14 | sub_403DF8 | read function | stream | 40 bytes | 40 | Read into an output buffer |
| +0x1C | sub_403B0C | 0xADAD2B51 | stream | 12 bytes of 0 | 12 | Pause ? No caller (vtable only) |
| +0x24 | sub_402C80 | | | | | Release the device object |
| +0x28 | sub_403EEC | 0xADAD2B7D | stream | NULL | 0 | End of stream. Only when `Q6AudioHw+0x24` = 1 (running), then sets it to 0 |
| +0x2C | sub_403018 | open function | 1 | [open message](#open-message) | 116 | |
| +0x30 | sub_403BF4 | close function | stream | | | |
| +0x34 | sub_403270 | 0xADAD2B45 | 0x10000 | 40 bytes | 1 | Memory map. Buffer: `+04` physical address, `+08` virtual address, `+0C` size, rest 0 |
| +0x38 | sub_403368 | 0xADAD2B49 | 0x10000 | 40 bytes | 1 | Memory unmap, same buffer |
| +0x3C | sub_40342C | 0xADAD2B79 | stream | [media format](#media-format) | 84 | Set the media format (input and output formats) |
| +0x40 | sub_4036B8 | 0xADAD2B4D | stream | 12 bytes of 0 | 12 | Run ? Sets `Q6AudioHw+0x24` = 1 |
| +0x44 | sub_4037A8 | 0xADAD2B51 | stream | 12 bytes of 0 | 12 | Pause ? Sets `Q6AudioHw+0x24` = 0 |
| +0x48 | sub_403988 | none | | | | Sets `Q6AudioHw+0x24` = 0 (traces only) |
| +0x4C | sub_403A1C | 0xADAD2B59 | stream | 12 bytes of 0 | 12 | Resume ? Sets `Q6AudioHw+0x24` = 0 |
| +0x50 | sub_403898 | 0xADAD2B5D | stream | 12 bytes of 0 | 12 | ? Sets `Q6AudioHw+0x24` = 1. Dead code (see [Stream life cycle](#stream-life-cycle)) |
| +0x04, +0x08, +0x0C, +0x18, +0x20 | sub_402B40, sub_402CA0 | | | | | Stubs returning 1 |

The commands return 0 on success. The errors of the driver are 0x800050xx values: 0x80005004 callback without context, 0x80005005 open failed, 0x80005006 media format failed, 0x80005008 map failed, 0x80005009 run / 0x2B5D failed, 0x8000500A end of stream failed, 0x8000500B unmap failed, 0x8000500F close failed, 0x80005011 write failed, 0x80005012 pause failed, 0x80005014 0x2B59 failed, 0x80005016 read failed.

Events received by the stream callback (`sub_401374` → `sub_401414`, `fn(event, payload, size, context)`):  
| Event | Payload | Comment |
|-------|---------|---------|
| 0xADAD6B41 | 40 bytes | Write done: `+04` = physical address of the input buffer, which becomes free again (`sub_4014D0`) |
| 0xADAD6B45 | 40 bytes | Read done: `+04` physical address of the output buffer, `+0C` number of bytes, `+1C`/`+20` time stamp in µs (`sub_401614`) |
| 0xADAD6B4D | ? | End of stream rendered: marks the current output buffer as last buffer (`sub_4017E8`) |

#### Open message

116 bytes, built by `Q6AudioHw::Open` (`sub_403018`) and passed to the open function:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | ? |
| 04-57 | ? | [Media format](#media-format) (84 bytes), with `40-43` left at 0 |
| 58-63 | 00 … | |
| 64-67 | 10 00 00 00 | 16 (bits per sample ?) |
| 68-6B | ? | Callback (`sub_401374`) |
| 6C-6F | ? | Callback context (`HwStreamHelper` object) |
| 70-73 | 00 00 00 00 | |

#### Media format

84 bytes, at offset 4 of the open message and alone with command 0xADAD2B79 (`sub_40342C`). Built from the input PCM format (`in`) and the output `WAVEFORMATEX` (`out`). It's the decoder's layout reversed: the PCM block comes first and the codec block last.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | ? |
| 04-07 | 0C 00 00 00 | Size of the PCM block (12) ? |
| 08-0B | ? | `in.nSamplesPerSec` |
| 0C-0D | ? | `in.nChannels` |
| 0E-0F | ? | `in.wBitsPerSample` |
| 10-11 | 01 00 | ? |
| 12-13 | 01 00 | ? |
| 14-37 | 00 … | |
| 38-3B | ? | Encoder type, see [Filter](#filter): 7 for 0x1610, 0xA for 0x7631 and 0x7A21 |
| 3C-3F | ? | Size of the codec block: 0x10 for AAC, 4 for AMR |
| 40-43 | 01 00 00 00 | ? (0 in the open message) |
| 44-53 | ? | Codec block, see below |

AAC codec block (encoder type 7):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 44-47 | ? | `out.nSamplesPerSec` |
| 48-49 | ? | `out.nChannels` |
| 4A-4B | 03 00 | Format ? (3 = raw in the decoder's transport mapping) |
| 4C-4F | ? | Bit rate: `out.nAvgBytesPerSec` × 8, at most 192000 |
| 50-53 | 02 00 00 00 | Audio object type ? (2 = AAC LC) |

AMR codec block (encoder type 0xA):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 44-45 | 07 00 | Band mode ? (7 = 12.2 kbit/s) |
| 46-47 | 00 00 | DTX ? |

#### Write and read buffers

40-byte descriptors passed to the write function (`sub_403C94`, one per filled 8 KB input buffer) and to the read function (`sub_403DF8`, one per free 4 KB output buffer):  
| Bytes | Write | Read |
|-------|-------|------|
| 00-01 | 00 00 | 00 00 |
| 04-07 | Physical address | Physical address |
| 08-0B | Virtual address | Virtual address |
| 0C-0F | Number of bytes | Size of the buffer (0x1000) |
| 10-13 | 0x80000000 (always; the "time stamp changed" argument is ignored, unlike the decoder) | 0 |
| 14-17 | 0 | 0 |
| 18-1B | 2 | 1 |
| 1C-1F | Time stamp in µs (stream pointer time / 10), high dword | 0 |
| 20-23 | Time stamp in µs, low dword | 0 |
| 24-27 | 0 | 0 |

### Interface GUID

Peer interface opened by Qcomavsencoder.sys:  
Q6 audio (qcq6ad8930.sys) `{5F51A34C-6834-479D-9EA2-EAFA622524BA}`

### Other GUID

ETW provider (shared with qcomavsdecoder.sys)  
`{9893ae6b-b6a5-4f76-a42d-210deaef83e2}`

WPP control GUID  
`{dafad017-4ac4-40f0-a1b1-e51d5c9d0e18}`

Property set of the filter  
`{b9d19a3e-f897-429c-bc46-8138b7272b2d}`
