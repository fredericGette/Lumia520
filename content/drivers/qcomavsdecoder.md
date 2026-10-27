## Qcomavsdecoder.sys

Qualcomm AVS (Audio Video Subsystem) hardware audio decoder.  
It's a KS/AVStream minidriver (`ks.sys`) that exposes one decoder filter (categories audio / data decompressor / data transform): compressed audio (MP3, AAC, WMA, AMR, …) goes in through the input pin, PCM comes out of the output pin. The decoding itself is done by the ADSP (QDSP6): the driver opens a decoder stream through the Q6 audio driver [qcq6ad8930.sys](./qcq6ad8930.md) and passes it physically contiguous buffers. It's the kind of filter that the Media Foundation pipeline uses as a hardware decoder MFT through the KS proxy ?  
It doesn't read any file, and the only device it talks to is [qcq6ad8930.sys](./qcq6ad8930.md) (interface `{5F51A34C-…}`).  
PDB path: `P:\audio\rel\8.3.1\arm\Release\qcomavsdecoder.pdb`. Source files named in the asserts: `device.cpp`, `AvsDecodeFilter.cpp`, `inputpin.cpp`, `outputpin.cpp`, `HwStreamHelper.cpp`, `Q6AudioHw.cpp`.

There's no named device object and no symbolic link: the filter is reached through its KS device interfaces (see [Filter](#filter)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>` ?  

There's no parameters in the registry.

GUID of the ETW provider (manifest based, `McGenEventRegister` in `DriverEntry`, also used by [qcomavsencoder.sys](./qcomavsencoder.md)). Only one event is written, id 201 (`.rdata:0x408150`) with "LOGGING START" / "LOGGING STOP", the source file and the line:  
`{9893ae6b-b6a5-4f76-a42d-210deaef83e2}`

GUID of the WPP control (`.rdata:0x408120`, all the other traces):  
`{988e9489-b05f-4243-9cc4-f4c17ee0300b}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{5F51A34C-6834-479D-9EA2-EAFA622524BA}` | [qcq6ad8930.sys](./qcq6ad8930.md) (`\_SB.Q6AD`) | Q6 audio. [IOCTL 0xADAD2BA1](#ioctl-0xadad2ba1--get-q6-entry-points) returns the entry points, then all the commands go through them (see [Q6 audio entry points](#q6-audio-entry-points)) |
| — | ks.sys | AVStream class driver |

### Driver initialisation

`DriverEntry` (`FxDriverEntryWorker` 0x404908) initialises WPP, calls `KsInitializeDriver(DriverObject, RegistryPath, &DeviceDescriptor)` (descriptor `.rdata:0x408210`, no static filter descriptor) and registers the ETW provider.  
`KSDEVICE_DISPATCH` (`.rdata:0x4081D8`):  
| Callback | Function | Comment |
|----------|----------|---------|
| Add | sub_40B438 | Allocates the 16-byte device context (pool tag `KCNw`) |
| Start | sub_4042E0 → sub_40B530 | See below |
| Stop | sub_404300 → sub_40B650 | Unmaps and frees the buffers (`sub_404580`, `sub_404620`), releases the Q6 device (`sub_402980`), unregisters ETW and WPP |
| others | 0 | Not handled |

At start, the device:
1. creates the filter factory: `KsCreateFilterFactory(…, &FilterDescriptor, L"GLOBAL", NULL, KSCREATE_ITEM_FREEONSTOP (8), …)` (descriptor `.rdata:0x408318`);
2. allocates the [buffers](#buffers) shared with the ADSP (`sub_404694`);
3. creates the `Q6AudioHw` object (140 bytes, vtable `.rdata:0x408160`, `sub_4028E8`).

The Q6 device is opened at the creation of the first filter (`sub_40446C`, called by the filter constructor `sub_404EDC`): `Q6AudioHw::Init` (`sub_402920`) gets the entry points of [qcq6ad8930.sys](./qcq6ad8930.md), then the 6 buffers are mapped in the ADSP with [command 0xADAD2B45](#q6-audio-entry-points). No `Q6AudioHw` object → `STATUS_INVALID_DEVICE_STATE` (0xC0000184), init or map failure → `STATUS_DEVICE_CONFIGURATION_ERROR` (0xC0000182).

### Filter

| Property | Value |
|----------|-------|
| `KSFILTER_DESCRIPTOR` | `.rdata:0x408318` |
| Reference string | `GLOBAL` |
| Create / Close | sub_40B72C / sub_40B840 |
| Automation table | none |
| Pins | 2 (`.rdata:0x408238`, 0x50 bytes each) |
| Connection | input pin 0 → output pin 1 (topology `.rdata:0x408308`) |

Reference GUID: `KSNAME_Filter` `{9b365890-165f-11d0-a195-0020afd156e4}`.  
Categories:  
| GUID | Category |
|------|----------|
| `{6994ad04-93ef-11d0-a3cc-00a0c9223196}` | `KSCATEGORY_AUDIO` |
| `{2721ae20-7e70-11d0-a5d6-28db04c10000}` | `KSCATEGORY_DATADECOMPRESSOR` |
| `{9ea73fb4-ef7a-4559-8d5d-719d8f0426c7}` | `KSCATEGORY_DATATRANSFORM` |

The filter create (`sub_40B72C`) allocates the `AvsDecodeFilter` object (0xD0 bytes, tag `KCNw`) and fails with `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A) when no [buffer set](#buffers) is free: **at most 3 decoder filters can exist at the same time**.

| Pin | Input (0) | Output (1) |
|-----|-----------|------------|
| Dispatch | `.rdata:0x408358` | `.rdata:0x408680` |
| Create / Close | sub_40B9B4 / sub_40B95C | sub_40C1D0 / sub_40C178 |
| Process | sub_405340 (`CInputPin::InputPinProcess`) | sub_405D80 (`COutputPin::OutputPinProcess`) |
| SetDataFormat | sub_405BA0 | sub_406798 |
| SetDeviceState | sub_405320 → sub_4058FC | sub_405D60 → sub_406508 |
| Intersect handler | sub_40BA88 | sub_40C2D0 |
| Data flow | `KSPIN_DATAFLOW_IN` | `KSPIN_DATAFLOW_OUT` |
| Communication | `KSPIN_COMMUNICATION_BOTH` | `KSPIN_COMMUNICATION_BOTH` |
| Flags | 0x10020 (`INITIATE_PROCESSING_ON_EVERY_ARRIVAL`, `PROCESS_IN_RUN_STATE_ONLY`) | 0 |
| Instances | unlimited (0xFFFFFFFF), 0 necessary | unlimited, 0 necessary |
| Category | `KSCATEGORY_AUDIO` | `KSCATEGORY_AUDIO` |
| Name GUID | `{47a4fa20-a251-11d1-a050-0000f8004788}` | `{f2aec663-55d0-4775-b33c-e63832492561}` |
| Data ranges | 10, see below | 1: PCM (`WAVE_FORMAT_PCM`), 2 channels max, 8–16 bits, 8000–48000 Hz |

Data ranges of the input pin (`KSDATARANGE_AUDIO`, major format `KSDATAFORMAT_TYPE_AUDIO`, specifier `KSDATAFORMAT_SPECIFIER_WAVEFORMATEX`). The intersect handler (`sub_40BA88`) builds the `WAVEFORMATEX` with the format tag below; the "decoder type" is the value sent to the ADSP in the [media format](#media-format):  
| SubFormat | Format | Channels | Bits | Sample rate | Format tag built | Decoder type |
|-----------|--------|----------|------|-------------|------------------|--------------|
| `{00000055-0000-0010-8000-00aa00389b71}` | MP3 | 2 | 16–24 | 8000–96000 | 0x0055 | 3 |
| `{00001610-0000-0010-8000-00aa00389b71}` | HE-AAC (`WAVE_FORMAT_MPEG_HEAAC`) | 2 | 16–24 | 8000–96000 | 0x1610 | 7 |
| `{00000161-0000-0010-8000-00aa00389b71}` | WMA (`WAVE_FORMAT_WMAUDIO2`) | 2 | 16–24 | 8000–96000 | 0x0161 | 5 |
| `{00000162-0000-0010-8000-00aa00389b71}` | WMA Pro (`WAVE_FORMAT_WMAUDIO3`) | 2 | 16–24 | 8000–96000 | 0x0162 | 6 |
| `{00000163-0000-0010-8000-00aa00389b71}` | WMA Lossless | 2 | 16–24 | 8000–96000 | 0x0163 | 6 |
| `{00007631-0000-0010-8000-00aa00389b71}` | ? | 2 | 16–24 | 8000 | 0x7631 | 0xA |
| `{00007371-0000-0010-8000-00aa00389b71}` | AMR-WB ? | 2 | 16–24 | 8000–16000 | 0x7371 | 0xE |
| `{e06d802c-db46-11cf-b4d1-00805f6cbbea}` | Dolby AC3 (`MEDIASUBTYPE_DOLBY_AC3`) | 2 | 16 | 32000–48000 | none: the intersection returns `STATUS_NO_MATCH` (0xC0000272) | 0x1A (`WAVE_FORMAT_EXTENSIBLE` with the AC3 SubFormat) |
| `{00007361-0000-0010-8000-00aa00389b71}` | AMR-NB (`WAVE_FORMAT_AMR_NB`) | 2 | 8–16 | 8000–16000 | 0x7361, forced to mono 8000 Hz 16 bits, extra data `FPAC`… | 0xA |
| `{73716370-767a-494d-b478-f29d25dc9037}` | QCELP ? (`pcqs`) | 1 | 16 | 8000 | 0xFFFE (`WAVE_FORMAT_EXTENSIBLE`, same SubFormat) | 0 (not set) |

Any other format tag at the stream opening → decoder type 3 (MP3) with a trace.

The output intersect handler (`sub_40C2D0`) always builds a `WAVE_FORMAT_PCM` format (82 bytes = `KSDATAFORMAT` + `WAVEFORMATEX`) from the maximum values of the range.  
Both pins have the same allocator framing (`.rdata:0x408610`, `.rdata:0x4086B0`): 1 item, memory type `{4a6d5fc4-7895-11d1-b069-00a0c9062802}`.

### Stream life cycle

The decoder stream is opened when one of the pins goes from `KSSTATE_STOP` to `KSSTATE_ACQUIRE` (`sub_404A2C`):
1. allocates the `HwStreamHelper` object (0x1B8 bytes, `sub_404888` / `sub_401348`);
2. takes the first free [buffer set](#buffers) (`sub_404338`);
3. opens the Q6 stream (`sub_401984`): open function with the input and output `WAVEFORMATEX` and the callback `sub_4013C0`, then [command 0xADAD2B79](#media-format) (media format), then starts the read thread (`sub_401C24`), which waits for "output buffer free" events and sends the [read](#write-and-read-buffers) requests.

| Pin state change | Function | Q6 calls |
|------------------|----------|----------|
| Input or output pin STOP → ACQUIRE | sub_404A2C | open, 0xADAD2B79 |
| Output pin → RUN | sub_401DFC | 0xADAD2B4D (run ?), then wakes up the read thread |
| Output pin RUN → ACQUIRE | sub_405048 | 0xADAD2B5D (?) |
| Input pin PAUSE → RUN, filter state 3 | sub_404E58 | 0xADAD2B59 (?). The filter state 3 is never set in the binary: dead code ? |
| Both pins → STOP | sub_404B3C | 0xADAD2B51 (pause ?), stops the read thread, close function, frees the buffer set |

Input data (`CInputPin::InputPinProcess`, `sub_402070`): the bytes of each stream pointer are copied into the free input buffers (8 KB each) and each buffer is passed to the [write function](#write-and-read-buffers). A stream pointer with the end-of-stream flag sends [command 0xADAD2B7D](#q6-audio-entry-points) instead.  
Output data (`COutputPin::OutputPinProcess`, `sub_40239C`): when the ADSP has filled the output buffer, its content is copied into the output stream pointer, with the time stamp of the ADSP (µs × 10) or a duration computed from the PCM format. Nothing available → the IRP stays pending (`STATUS_DEVICE_NOT_READY`).

### Buffers

Allocated once at device start (`sub_404694`) with `MmAllocateContiguousMemorySpecifyCache` (`MmNonCached`, physical addresses 0x80200000–0xC0000000, no boundary), and split into 3 sets (table `.data:0x409328`, 24 bytes per set):  
| Region | Size | Per set | Use |
|--------|------|---------|-----|
| Input | 98304 (0x18000) | 32 KB = 4 buffers of 8 KB | Compressed data written to the ADSP |
| Output | 1179648 (0x120000) | 384 KB (0x60000), 1 buffer | PCM read from the ADSP |

The 6 regions are mapped in the ADSP with command 0xADAD2B45 when the Q6 device is opened, and unmapped with 0xADAD2B49 at device stop.

---

### IOCTL 0xADAD2BA1 — get Q6 entry points

This IOCTL is sent by Qcomavsdecoder.sys to [qcq6ad8930.sys](./qcq6ad8930.md) (interface `{5F51A34C-…}`), by `Q6AudioHw::Init` (`sub_402920` → `sub_4029B0`: `IoGetDeviceInterfaces` + `IoGetDeviceObjectPointer(GENERIC_ALL)`, then `sub_402BF0`).

| Property | Value |
|----------|-------|
| Device | 0xADAD |
| Function | 0xAE8 (2792) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get Q6 entry points | interface `{5F51A34C-6834-479D-9EA2-EAFA622524BA}` | 0 | 20 |

Outputbuffer (stored at `Q6AudioHw+0x78`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Open stream: `handle = fn(1, message, 116)`, see [Open message](#open-message) |
| 04-07 | ? | Close stream: `fn(handle)` |
| 08-0B | ? | Write buffer: `fn(handle, buffer, 40)`, see [Write and read buffers](#write-and-read-buffers) |
| 0C-0F | ? | Read buffer: `fn(handle, buffer, 40)` |
| 10-13 | ? | Command: `fn(handle, command, buffer, size)` |

Normal (not internal) IOCTL built with `IoBuildDeviceIoControlRequest`, waited for 5 s at most. Timeout → 0x80005002, no device → 0x80005003.

### Q6 audio entry points

Commands sent with the command function (offset 0x10 above). The handle is the one returned by the open function, except for the memory map commands (0x10000).  
| Command | Function | Handle | Buffer | Size | Comment |
|---------|----------|--------|--------|------|---------|
| 0xADAD2B45 | sub_403180 | 0x10000 | 40 bytes | 1 | Memory map. Buffer: `+04` physical address, `+08` virtual address, `+0C` size, rest 0 |
| 0xADAD2B49 | sub_403278 | 0x10000 | 40 bytes | 1 | Memory unmap, same buffer |
| 0xADAD2B79 | sub_403348 | stream | [media format](#media-format) | 84 | Set the media format (input and output formats) |
| 0xADAD2B4D | sub_403718 | stream | 12 bytes of 0 | 12 | Run ? Sets `Q6AudioHw+0x24` = 1 |
| 0xADAD2B51 | sub_403808, sub_403BAC | stream | 12 bytes of 0 | 12 | Pause ? `sub_403808` sets `Q6AudioHw+0x24` = 0 |
| 0xADAD2B5D | sub_4038DC | stream | 12 bytes of 0 | 12 | ? Sets `Q6AudioHw+0x24` = 1 |
| 0xADAD2B55 | sub_4039CC | stream | 12 bytes of 0 | 12 | ? Sets `Q6AudioHw+0x24` = 0. No caller (vtable only) |
| 0xADAD2B59 | sub_403ABC | stream | 12 bytes of 0 | 12 | ? Sets `Q6AudioHw+0x24` = 0 |
| 0xADAD2B7D | sub_403F90 | stream | NULL | 0 | End of stream |

The commands return 0 on success. The errors of the driver are 0x800050xx values (e.g. 0x80005005 open failed, 0x80005006 media format failed, 0x80005008 map failed, 0x80005011 write failed, 0x80005016 read failed).

Events received by the stream callback (`sub_4013C0` → `sub_401460`, `fn(event, payload, size)`):  
| Event | Payload | Comment |
|-------|---------|---------|
| 0xADAD6B41 | 40 bytes | Write done: `+04` = physical address of the input buffer, which becomes free again (`sub_40151C`) |
| 0xADAD6B45 | 40 bytes | Read done: `+04` physical address of the output buffer, `+0C` number of bytes, `+10` flags, `+1C`/`+20` time stamp in µs (`sub_401660`) |
| 0xADAD6B4D | ? | End of stream rendered: marks the output as last buffer (`sub_401874`) |

#### Open message

116 bytes, built by `Q6AudioHw::Open` (`sub_402D1C`) and passed to the open function:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | ? |
| 04-57 | ? | [Media format](#media-format) (84 bytes) |
| 58-63 | 00 … | |
| 64-67 | 10 00 00 00 | Bits per sample of the output: 24 (0x18) if the output format has 24 bits, else 16 |
| 68-6B | ? | Callback (`sub_4013C0`) |
| 6C-6F | ? | Callback context (`HwStreamHelper` object) |
| 70-73 | 00 00 00 00 | |

#### Media format

84 bytes, at offset 4 of the open message and alone with command 0xADAD2B79 (`sub_403348`). Built from the input `WAVEFORMATEX` (`wfx`) and the output PCM format (`out`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Decoder type, see [Filter](#filter) |
| 04-07 | ? | Size of the codec block: 0x30 for WMA, 0x1C for AAC, 0 otherwise |
| 08-37 | ? | Codec block, see below |
| 38-3B | 01 00 00 00 | ? |
| 3C-3F | 0C 00 00 00 | Size of the output block (12) ? |
| 40-43 | 00 00 00 00 | |
| 44-47 | ? | `out.nSamplesPerSec` |
| 48-49 | ? | `out.nChannels` |
| 4A-4B | ? | `out.wBitsPerSample` |
| 4C-4D | 01 00 | ? |
| 4E-4F | 01 00 | ? |
| 50-53 | 00 00 00 00 | |

WMA codec block (decoder types 5 and 6, offsets in the media format):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 08-09 | ? | `wFormatTag` |
| 0A-0B | ? | `nChannels` |
| 0C-0F | ? | `nSamplesPerSec` |
| 10-13 | ? | `nAvgBytesPerSec` |
| 14-15 | ? | `nBlockAlign` |
| 16-17 | ? | Type 5: `wBitsPerSample`. Type 6: valid bits per sample (`wfx+0x12`, only when `cbSize` = 18) |
| 18-1B | ? | Channel mask. Type 5: 4 if mono, 3 otherwise. Type 6: `dwChannelMask` (`wfx+0x14`) |
| 1C-1D | ? | Encode options (type 5: `wfx+0x16` when `cbSize` = 10; type 6: `wfx+0x20`) |
| 1E-1F | ? | Type 6: advanced encode options (`wfx+0x22`) |
| 20-23 | ? | Type 6: advanced encode options 2 (`wfx+0x1C`) |
| 24-33 | 00 … | |
| 34-35 | 02 00 / 01 00 | 2 for type 5, 1 for type 6 |
| 36-37 | ? | `nBlockAlign` |

AAC codec block (decoder type 7, input `HEAACWAVEINFO`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 08-0B | ? | `nSamplesPerSec` |
| 0C-0D | ? | `nChannels` |
| 0E-0F | ? | Transport, from `wPayloadType`: raw (0) → 3, ADTS (1) → 0, ADIF (2) → 2, LOAS (3) → 1 |
| 10-11 | 02 00 | Audio object type: first byte of the AudioSpecificConfig >> 3, or 2 (AAC LC) when `wStructType` ≠ 0 or there's no AudioSpecificConfig |
| 12-19 | 00 … | |
| 1A-1B | 01 00 | ? |
| 1C-1D | 01 00 | ? |
| 20-23 | ? | Bit rate: `nAvgBytesPerSec` × 8 |

#### Write and read buffers

40-byte descriptors passed to the write function (`sub_403D34`, one per filled 8 KB input buffer) and to the read function (`sub_403EB8`, the 384 KB output buffer):  
| Bytes | Write | Read |
|-------|-------|------|
| 00-01 | 00 00 | 00 00 |
| 04-07 | Physical address | Physical address |
| 08-0B | Virtual address | Virtual address |
| 0C-0F | Number of bytes | Size of the buffer (0x60000) |
| 10-13 | Flags: 0x80000000 when the time stamp changed since the previous buffer, else 0x20000000 | 0 |
| 14-17 | 0 | 0 |
| 18-1B | 1 | 1 |
| 1C-1F | Time stamp in µs (stream pointer time / 10), high dword | 0 |
| 20-23 | Time stamp in µs, low dword | 0 |
| 24-27 | 0 | 0 |

### Interface GUID

Peer interface opened by Qcomavsdecoder.sys:  
Q6 audio (qcq6ad8930.sys) `{5F51A34C-6834-479D-9EA2-EAFA622524BA}`

### Other GUID

ETW provider  
`{9893ae6b-b6a5-4f76-a42d-210deaef83e2}`

WPP control GUID  
`{988e9489-b05f-4243-9cc4-f4c17ee0300b}`
