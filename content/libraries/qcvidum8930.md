## qcvidum8930.dll

The Qualcomm video user-mode driver: the DXVA part of the Direct3D UMD of the MSM8930, build `P:\VideoUM\rel\8.2.1\arm\Release\qcvidum8930.pdb`.  
It is not loaded by the Direct3D runtime but by [qcdx9um8930.dll](./qcdx9um8930.md), which calls its only export `DxVidCreateAdapter` the first time a video caps type is asked for. It answers the DXVA caps (decoder GUIDs, configurations, render target formats, video processor and DXVA-HD caps) from tables built from the adapter information of the KMD, and implements the video device functions: DXVA2 decode devices (H.264, VC-1, MPEG-2, MPEG-1, MPEG-4 part 2), three private devices that are video encoders (driven through `DecodeExtensionExecute`), the DXVA video processor and the DXVA-HD video processor. The content protection functions (authenticated channels, crypto sessions) are not implemented.  
Like the UMD, it has no direct contact with the kernel: it uses the device callbacks of the runtime, given by qcdx9um8930.dll, to create GPU contexts on the video node, submit command buffers and send escapes, which end in the VIDEO ("VED") engine of [qcdxkm8930.sys](../drivers/qcdxkm8930.md#engines).

Quick analysis: 397 functions, no symbols, almost no strings. The adapter, the caps, the device function table, the device creation and the encoder command set were decompiled; the bitstream parsing of the decoders (`sub_10013038`, `sub_1001369C`, `sub_10015BF8`, `sub_10016400`…) and the content of the command buffers were not.

Location on the phone: `C:\Windows\System32\qcvidum8930.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| MSVCR110 | `malloc`, `free`, `memset`, `memcpy`, `memcpy_s`, `memcmp`, `operator new`, `operator delete`, `_purecall`, CRT startup (`_initterm`, `_initterm_e`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_malloc_crt`, `_calloc_crt`, `_amsg_exit`, `__C_specific_handler`, `__CppXcptFilter`, `__clean_type_info_names_internal`) |
| api-ms-win-core-processthreads-l1-1-1 | `CreateThread`, `TlsAlloc`, `TlsFree`, `GetCurrentThreadId` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `WaitForMultipleObjectsEx`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-1 | `GetLastError` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister` |
| api-ms-win-eventing-classicprovider-l1-1-0 | `RegisterTraceGuidsW`, `UnregisterTraceGuids`, `GetTraceLoggerHandle`, `GetTraceEnableLevel`, `GetTraceEnableFlags`, `TraceMessage` |
| api-ms-win-core-profile-l1-1-0 | `QueryPerformanceCounter` |
| api-ms-win-core-sysinfo-l1-2-0 | `GetSystemTimeAsFileTime`, `GetTickCount64` |
| api-ms-win-core-util-l1-1-0 | `EncodePointer`, `DecodePointer` |

The CRT startup functions, `EncodePointer`/`DecodePointer`, `GetSystemTimeAsFileTime`, `GetCurrentThreadId`, `GetTickCount64`, `QueryPerformanceCounter` (`/GS` cookie) are the Visual C++ 2012 DLL boilerplate. The classic-provider functions are the WPP tracing. The thread and event functions are only used by the [encoder](#encoder-devices).

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DxVidCreateAdapter` | 0x10001118 | `IN *In`, `OUT *Out` |

There is no `LoadLibrary`, no registry access and no file access: the DLL depends on nothing but its static imports and the callbacks of its caller.

### Startup

`start` (`_DllMainCRTStartup`, 0x10028AFC): CRT initialisation, then `DllMain` (`sub_10001090`):
- `DLL_PROCESS_ATTACH`: `TlsAlloc` (index in `dword_1002B104`, not used elsewhere), then `sub_100014BC`: registers the manifest provider `{8EFF03D9-49C8-412C-9AC5-9521D22D66C1}` (`EventRegister`, callback `ETW_EnableCallback`) and the WPP provider `{CC501161-986D-4178-8919-72600831CDC1}` (`RegisterTraceGuidsW`, `sub_10001418`). See [ETW](#etw).
- `DLL_THREAD_ATTACH`: `sub_100014BC` again (nothing if already registered).
- `DLL_THREAD_DETACH` and `DLL_PROCESS_DETACH`: `sub_10001488` unregisters both providers; `DLL_PROCESS_DETACH` also frees the TLS index.

### DxVidCreateAdapter (0x10001118)

Both pointers must be non-null, else `E_INVALIDARG`. `sub_10002404` allocates the 0x58-byte [video adapter](#video-adapter) and `sub_10002198` fills it:

1. copies the dwords `In+0x04`…`In+0x50` to adapter `+0x00`…`+0x4C`;
2. copies the 1424-byte adapter information of the KMD pointed by `In+0x54` into a `malloc` buffer (adapter `+0x50`);
3. fills `Out` (see below);
4. creates the 0x59C-byte [caps object](#caps-object) (`sub_10004CD4`, adapter `+0x54`) and initialises it from the adapter information (`sub_100072DC`).

`E_OUTOFMEMORY` when an allocation fails.

`In` (0xBC bytes, built by qcdx9um8930.dll `sub_10001720`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | 0xBC, size |
| 0x04 | 4 | 4 (version ?), copied to adapter `+0x00` |
| 0x08 | 4 | 6 (version ?), copied to adapter `+0x04` |
| 0x10 | 4 | Adapter object of qcdx9um8930.dll, copied to adapter `+0x0C` |
| 0x14–0x50 | | Copied to adapter `+0x10`…`+0x4C`, not used by the analysed code |
| 0x54 | 4 | Pointer to the [adapter information](./qcdx9um8930.md#adapter-information-sub_10001660) of the KMD (1424 bytes) |

`Out` (0x100 bytes, kept by qcdx9um8930.dll at its adapter `+0x5CC`…):

| Offset | Value | Comment |
|--------|-------|---------|
| 0x00 | 256 | Size |
| 0x04 | adapter | Video adapter handle |
| 0x08 | `sub_10001F60` | `CreateDevice(In, Out)`, see [Device](#device) |
| 0x0C | `sub_1000210C` | `CloseAdapter(hAdapter)`: frees the caps object, the adapter information copy and the adapter |
| 0x10 | `sub_10001560` | Returns `E_NOTIMPL` |
| 0x48 | `sub_10001778` | [GetCaps](#getcaps-sub_10001778)`(hAdapter, D3DDDIARG_GETCAPS *)` |
| 0x88 | 4 | Same values as `In+0x04` |
| 0x8C | 6 | Same values as `In+0x08` |
| other | 0 | |

### Video adapter

0x58 bytes (`sub_10001700`).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00–0x4C | 80 | Copy of `In+0x04`…`In+0x50` (`+0x0C`: qcdx9um8930.dll adapter) |
| 0x50 | 4 | Copy of the KMD adapter information (1424 bytes) |
| 0x54 | 4 | [Caps object](#caps-object) |

### Caps object

0x59C bytes, `sub_10004CD4` (constructor), `sub_100072DC` (initialisation), `sub_10004794` (values from the adapter information).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Video adapter |
| 0x04 | 4 | Adapter information `+0x1C` (hardware version ?) |
| 0x08 | 4 | Adapter information `+0x20` (hardware version ?). "Newer" below means `+0x04` > 4 or `+0x08` ≥ 3 |
| 0x0C | 4 | 1 when initialised; before that the caps return `S_FALSE` and zeroed data |
| 0x10 | 160 | The 10 [decoder GUIDs](#decoders) |
| 0xB0 | 4 | 10, number of decoder GUIDs |
| 0xB4 | 4 | Render target format of the decoders: `420O` (0x4F303234) |
| 0xB8 | 4 | 1, number of render target formats |
| 0xBC | 64 | 4 compressed buffer descriptions (type, width, height, pool): {150 `PICTUREPARAMSDATA`, 1040, 1, 1}, {154 `INVERSEQUANTIZATIONDATA`, 516, 1, 1}, {155 `SLICECONTROLDATA`, 8100, 22, 1}, {156 `BITSTREAMDATA`, max width, max height × 0.75, 2} |
| 0xFC | 4 | 4, number of compressed buffer descriptions |
| 0x100 | 1100 | 11 `DXVA2_ConfigPictureDecode` (100 bytes), see [Decoders](#decoders) |
| 0x54C | 4 | 1, number of configurations per decoder |
| 0x550, 0x554 | 8 | Max decode width / height: adapter information `+0xE0` / `+0xE2` (16-bit), default 1920 × 1088 |
| 0x558, 0x55C | 8 | Adapter information `+0xE4`, `+0xE8` (?) |
| 0x560 | 4 | Number of entries of the list at `+0x564` |
| 0x564 | 4 | Decoder GUIDs enabled by the flags at adapter information `+0xEC` (built but not returned by the caps, which use the static list at `+0x10`) |
| 0x568 | 4 | Number of render target formats enabled by adapter information `+0xF0` bit 0 |
| 0x56C | 4 | `420O` |
| 0x570, 0x574 | 8 | Max encode width / height: adapter information `+0x80` / `+0x82` (16-bit), default 1920 × 1088 |
| 0x578, 0x57C | 8 | Adapter information `+0x88`, `+0x8C` (?) |
| 0x580 | 4 | Number of entries of the list at `+0x584` |
| 0x584 | 4 | [Encoder](#encoder-devices) GUIDs enabled by adapter information `+0x90` (bit 0 `{129F7B40…}`, bit 1 `{CBB1A2A4…}`, bit 3 `{B7BC9768…}`) |
| 0x588 | 4 | Number of entries at `+0x58C` |
| 0x58C | 8 | Buffer types enabled by adapter information `+0x94`: bit 0 → 159, bit 1 → 160 (`D3DDDIFMT_DXVA_RESERVED9` / `10`, encoder buffers ?) |
| 0x594 | 4 | Adapter information `+0x84` byte 0 |
| 0x598 | 4 | Adapter information `+0x84` bits 8–11 |

So the adapter information returned by [qcdx9um8930.dll](./qcdx9um8930.md#adapter-information-sub_10001660)'s `DxgkDdiQueryAdapterInfo` call has a video block from `+0x80`: encoder limits at `+0x80`…`+0x94`, decoder limits at `+0xE0`…`+0xF0`. Flags at `+0xEC`: bit 0 H.264, bit 1 MPEG-2 (two GUIDs), bit 2 VC-1, bit 3 MPEG-4 part 2 (three GUIDs), bit 4 `{F9AACCBB-C2B6-4CFC-8779-5707B1760552}` (?).

### GetCaps (sub_10001778)

`D3DDDIARG_GETCAPS` {`Type`, `pInfo`, `pData`, `DataSize`}. Only the video types reach this function (qcdx9um8930.dll answers types 1–13 itself). By `Type` (`D3DDDICAPS_TYPE`):

| Type | Function | Answer |
|------|----------|--------|
| 14 `GETDECODEGUIDCOUNT` | `sub_100052CC` | 10 |
| 15 `GETDECODEGUIDS` | `sub_10005148` | The 10 [decoder GUIDs](#decoders) |
| 16 `GETDECODERTFORMATCOUNT` | `sub_1000555C` | 1 |
| 17 `GETDECODERTFORMATS` | `sub_100053C0` | `420O` |
| 18 `GETDECODECOMPRESSEDBUFFERINFOCOUNT` | `sub_100071DC` | 4 |
| 19 `GETDECODECOMPRESSEDBUFFERINFO` | `sub_10007040` | The 4 buffer descriptions of the [caps object](#caps-object) `+0xBC` |
| 20 `GETDECODECONFIGURATIONCOUNT` | `sub_10006F04` | 1 (2 for VC-1) |
| 21 `GETDECODECONFIGURATIONS` | `sub_100069E4` | The `DXVA2_ConfigPictureDecode` of the decoder, see [Decoders](#decoders) |
| 22 `GETVIDEOPROCESSORDEVICEGUIDCOUNT` | `sub_10005078` | 2 (newer) or 3 |
| 23 `GETVIDEOPROCESSORDEVICEGUIDS` | `sub_10006858` | `DXVA2_VideoProcProgressiveDevice` `{5A54A0C9-C7EC-4BD9-8EDE-F3C75DC4393B}`, `DXVA2_VideoProcBobDevice` `{335AA36E-7884-43A4-9C91-7F87FAF3E37E}`, and if not newer `{CBC9F8A8-B311-4239-9A93-08E826B48A53}` (private ?) |
| 24 `GETVIDEOPROCESSORRTFORMATCOUNT` | `sub_1000631C` | Progressive / Bob: 2; `{CBC9F8A8…}`: 1 |
| 25 `GETVIDEOPROCESSORRTFORMATS` | `sub_1000611C` | Progressive / Bob: `X8R8G8B8` (22), `A8R8G8B8` (21); `{CBC9F8A8…}`: `420O` |
| 26 `GETVIDEOPROCESSORRTSUBSTREAMFORMATCOUNT` | `sub_10005F7C` | 5 / 1 |
| 27 `GETVIDEOPROCESSORRTSUBSTREAMFORMATS` | `sub_10005D5C` | `UYVY`, `YUY2`, `NV12`, `420O`, `AYUV` / `420O` |
| 28 `GETVIDEOPROCESSORCAPS` | `sub_1000666C` | 36-byte `DXVADDI_VIDEOPROCESSORCAPS`. Progressive / Bob: `InputPool` 2, `NumForwardRefSamples` 0, `NumBackwardRefSamples` 0, `OutputFormat` 22, `DeinterlaceTechnology` 0x40, `ProcAmpControlCaps` 0x0F, `VideoProcessorOperations` 0xDBFF, `NoiseFilterTechnology` 0, `DetailFilterTechnology` 4. `{CBC9F8A8…}`: output `NV12`, operations 0x8016 |
| 29 `GETPROCAMPRANGE` | `sub_100064BC` | Progressive / Bob, properties 1, 2, 4, 8 (brightness, contrast, hue, saturation): −100…100, default 0, step 0.1 (fixed 16.16) |
| 30 `FILTERPROPERTYRANGE` | `sub_10005BD8` | Only filter 7: 0…100, default 0, step 1 |
| 31 `GETEXTENSIONGUIDCOUNT` | | 0 |
| 32, 33, 35 | | `E_FAIL` (no extension, no overlay) |
| 34 `GETGAMMARAMPCAPS` | | `E_FAIL` |
| 36 `DXVAHD_GETVPDEVCAPS` | `sub_10005A68` | 44 bytes (11 dwords): 0, 11, 18, 0x2F, 0, 2 (`DeviceType`, `DeviceCaps`, `FeatureCaps`, `FilterCaps`, `InputFormatCaps`, `AutoStreamCaps` ?), then `OutputFormatCount` 3 or 4 (newer), `InputFormatCount` 7, `VideoProcessorCount` 1, `MaxInputStreams` 2, `MaxStreamStates` 2. `FilterCaps` 0x2F matches the filters of type 41 |
| 37 `DXVAHD_GETVPOUTPUTFORMATS` | `sub_1000590C` | `X8R8G8B8`, `A8R8G8B8`, `420O`, and `NV12` (newer) |
| 38 `DXVAHD_GETVPINPUTFORMATS` | `sub_100057C8` | `UYVY`, `YUY2`, `NV12`, `420O`, `AYUV`, `X8R8G8B8`, `A8R8G8B8` |
| 39 `DXVAHD_GETVPCAPS` | `sub_1000565C` | One 36-byte `DXVAHD_VPCAPS`: GUID Progressive (or Bob), 0 past / future frames, processor caps 0x0F |
| 40 `DXVAHD_GETVPCUSTOMRATES` | `sub_10004F38` | Zeroed 20 bytes, `S_FALSE` |
| 41 `DXVAHD_GETVPFILTERRANGE` | `sub_10004DB0` | `DXVAHD_FILTER_RANGE_DATA`. Filters 0–3 (brightness, contrast, hue, saturation): −100…100, default 0, multiplier 0.1; filter 5 (edge enhancement): 0…100, default 0, multiplier 1.0; filters 4, 6 and others: zeroed |
| 42–44 (content protection, certificates) | | `E_NOTIMPL` |
| other | | `E_FAIL` |

### Decoders

The decoder GUIDs (`.rdata`), the configuration each one returns (`GETDECODECONFIGURATIONS`, offset in the [caps object](#caps-object)) and the object `CreateDecodeDevice` builds:

| GUID | Name | Configuration | Decoder object |
|------|------|---------------|----------------|
| `{1B81BE68-A0C7-11D3-B984-00C04F2E73C5}` | `DXVA2_ModeH264_E` (H.264 VLD, no FGT) | `+0x100` | 0x950 bytes, `sub_100146B8` |
| `{1B81BEA4-A0C7-11D3-B984-00C04F2E73C5}` | `DXVA2_ModeVC1_D2010` | `+0x164` | 0x9C0 bytes, `sub_10017558` |
| `{EE27417F-5E28-4E65-BEEA-1D26B508ADC9}` | `DXVA2_ModeMPEG2_VLD` | `+0x22C` | 0x9C0 bytes, `sub_1001A230` |
| `{86695F12-340E-4F04-9FD3-9253DD327460}` | `DXVA2_ModeMPEG2and1_VLD` | `+0x290` | same as MPEG-2 |
| `{6F3EC719-3735-42CC-8063-65CC3CB36616}` | `DXVA2_ModeMPEG1_VLD` (not in the GUID list) | `+0x290` | same as MPEG-2 |
| `{EFD64D74-C9E8-41D7-A5E9-E9B0E39FA319}` | `DXVA2_ModeMPEG4pt2_VLD_Simple` | `+0x2F4` | 0x9D0 bytes, `sub_1001CF7C` |
| `{ED418A9F-010D-4EDA-9AE3-9A65358D8D2E}` | `DXVA2_ModeMPEG4pt2_VLD_AdvSimple_NoGMC` | `+0x358` | same as MPEG-4 Simple |
| `{BBC56996-08F7-4ACD-A623-D95808ADF8DA}` | ? (in the MPEG-4 part 2 group of the flags) | none (`E_FAIL`) | none |
| `{129F7B40-5C5B-48E5-8178-48C0CEA05A90}` | Private: [encoder](#encoder-devices) type 1–5 (H.264 ?) | `+0x3BC` | 0x5F8 bytes, `sub_100277B8` |
| `{CBB1A2A4-4EA1-491E-ADC9-70B373B76036}` | Private: encoder type 6–7 (MPEG-4 ?) | `+0x420` | same |
| `{B7BC9768-6665-4926-88A4-1751BC8515FB}` | Private: encoder type 8 (H.263 ?) | `+0x484` | same |

The configurations (`sub_100072DC`) are 11 copies of one template, then patched: `guidConfigBitstreamEncryption`, `guidConfigMBcontrolEncryption`, `guidConfigResidDiffEncryption` = `DXVA_NoEncrypt` `{1B81BED0-A0C7-11D3-B984-00C04F2E73C5}`, `ConfigBitstreamRaw` 2, `ConfigResidDiffAccelerator` 1, `ConfigHostInverseScan` 1, `ConfigMinRenderTargetBuffCount` 16. Entries 1–6 get `ConfigBitstreamRaw` 1 and `ConfigHostInverseScan` 0; entries 1–4 `ConfigMinRenderTargetBuffCount` 4, entries 5–6 5; entry 2 (not returned for any GUID) `ConfigDecoderSpecific` 128.

`CreateDecodeDevice` (`sub_1000EC5C`) also checks (`sub_10009460`) that `SampleWidth × SampleHeight` is at most the max decode size (caps `+0x550` × `+0x554`) for a decoder, or the max encode size (`+0x570` × `+0x574`) for an encoder; otherwise `E_FAIL`.

### Device

`CreateDevice` (`sub_10001F60` → `sub_1000FF04`) takes an `In` structure from qcdx9um8930.dll:

| Offset | Size | Comment |
|--------|------|---------|
| 0x04 | 4 | Video adapter handle (`Out+0x04` of `DxVidCreateAdapter`); must be non-null |
| 0x08 | 4 | Runtime `hDevice` (first argument of the callbacks) |
| 0x0C | 196 | Runtime device callbacks (49 pointers), copied into the device and into every GPU context |

It allocates the 0x11C-byte device (`sub_10008EB8`, vtable `off_10029350`), creates its resource list (`sub_10010244`, 0x1C bytes with a critical section), copies `In` (`sub_1000FD1C`: `+0x4C` adapter, `+0x50` `hDevice`, `+0x54` callbacks, `+0x118` = 1) and fills `Out` (`sub_1000F9C4`): `Out+0x04` = device, and the 0x20C-byte function table `Out[0]` = 524. Its entries 33–77 follow the order of the video functions of `D3DDDI_DEVICEFUNCS` from `pfnCreateDecodeDevice`, which the argument structures confirm:

| Index | Function | Name | Comment |
|-------|----------|------|---------|
| 2 | `sub_1000DDC0` | DestroyDevice | Destroys the two GPU contexts and the device |
| 3 | `sub_1000E30C` | CreateResource ? | `sub_1000ADD8`, adds the resource to the list |
| 4 | `sub_1000D7C0` | ? | `sub_10009F70`, updates the allocations of a resource of the list |
| 5 | `sub_1000E4D4` | DestroyResource ? | `sub_1000C7F8`, removes it from the list and frees it |
| 6, 7 | | | `E_NOTIMPL` |
| 8 | `sub_1000D210` | ? | Returns the context of an engine index (< 8, device `+0x2C`) |
| 9 | `sub_1000D16C` | ? | Compares a fence value with the one of an engine context (`sub_10009340`) |
| 10 | `sub_1000CE90` | Flush ? | Submits the command buffer of the 3D context (`sub_10011A8C`) |
| 11 | `sub_1000E3F0` | ? | `sub_1000C220`, two 64-byte structures |
| 12 | `sub_1000D0CC` | ? | `sub_100091BC`, updates the allocations of a resource |
| 13 | `sub_10008B5C` | Blt ? | `sub_100044B0`: chooses a copy path from the source / destination formats (103, 107, `UYVY`, 87, 88…): `sub_1000267C`, `sub_100036A4`, `sub_10003D1C`, `sub_10003188` |
| 33 | `sub_1000F8A0` | CreateDecodeDevice | `D3DDDIARG_CREATEDECODEDEVICE` {`pGuid`, `VideoDesc`, `pConfig` (+0x2C), `hDecode` (+0x30, out)}, see [Decoders](#decoders). Creates the video context on first use |
| 34 | `sub_1000F5DC` | DestroyDecodeDevice | Decoder vtable `+0x08`, then destroys the video context with the last decoder |
| 35 | `sub_1000DBCC` | SetDecodeRenderTarget | Decoder vtable `+0x18` |
| 36 | `sub_1000DAA8` | DecodeBeginFrame | Decoder vtable `+0x0C` |
| 37 | `sub_1000D860` | DecodeEndFrame | Decoder vtable `+0x14` |
| 38 | `sub_1000D984` | DecodeExecute | Decoder vtable `+0x10` |
| 39 | `sub_1000CF28` | DecodeExtensionExecute | Decoder vtable `+0x1C` (the [encoder](#encoder-devices) commands) |
| 40 | `sub_1000EB8C` | CreateVideoProcessDevice | 0x6C-byte object (`sub_1001F508`), handle written at `+0x34` (`hVideoProcess`) |
| 41 | `sub_1000E738` | DestroyVideoProcessDevice | |
| 42 | `sub_1000D6F0` | VideoProcessBeginFrame | |
| 43 | `sub_1000D620` | VideoProcessEndFrame | |
| 44 | `sub_1000DCF0` | SetVideoProcessRenderTarget | Keeps `hRenderTarget`, `SubResourceIndex` |
| 45 | `sub_1000D550` | VideoProcessBlt | `sub_10023A58` |
| 46 | `sub_1000EABC` | CreateVideoProcessor (DXVA-HD) | 0x214-byte object (`sub_1001F174`), handle written at `+0x04` |
| 47 | `sub_1000F7D0` | SetVideoProcessBltState | State 1000 (`DXVAHD_BLT_STATE_PRIVATE`) with GUID `{673BDBB6-14BD-434C-BF6A-FEB275A5EDA3}` → `sub_1001F444`, others `sub_1001EF5C` |
| 48 | `sub_1000F700` | GetVideoProcessBltStatePrivate | GUID `{B9039B5F-4827-47D7-A39C-F70479CDCEAA}` → `sub_1001F348`, others `sub_1001FD1C` (which knows `{3AD6379E-0D39-4312-95F5-622E26A5421D}`) |
| 49 | `sub_1000D480` | SetVideoProcessStreamState | `sub_1001EC10` |
| 50 | `sub_1000D3B0` | GetVideoProcessStreamStatePrivate | `sub_1001EB48` |
| 51 | `sub_1000D2E0` | VideoProcessBltHD | `sub_10023B84` |
| 52 | `sub_1000E808` | DestroyVideoProcessor | |
| 53–61 | | Authenticated channel (create, key exchange, query, configure, destroy), crypto session (create, key exchange, destroy), EncryptionBlt | `E_NOTIMPL` |
| 62 | `sub_1000D000` | GetPitch | Pitch of the resource whose handle matches (`sub_10008F68`) |
| 63–77 | | Session key refresh, DecryptionBlt, … | `E_NOTIMPL` |
| other | | | 0 |

### GPU contexts and escapes

The device keeps two contexts (`sub_1000AA64`, created on first use by `CreateVideoProcessDevice`, `CreateVideoProcessor` and the Blt ?) and the decoders share a third one (`sub_1000CA34`). Each is a 0x120-byte object with its own copy of the callbacks, created by `sub_100116CC` (callback with a `D3DDDICB_CREATECONTEXT`-like structure) and given a command buffer, an allocation list and a patch list (4096, 1024, 1024 for the video context, engine index 3 at context `+0x14`: the VIDEO engine of [qcdxkm8930.sys](../drivers/qcdxkm8930.md#engines)). Commands are appended to the command buffer (`sub_10010CE8`, `sub_10011D9C`, allocation and patch entries `sub_10010DC8`) and submitted with the render callback (`sub_10011940`: `D3DDDICB_RENDER` {`CommandLength`, `CommandOffset`, `NumAllocations`, `NumPatchLocations`, …, `hContext`}).

Escapes go through the escape callback (`sub_10011438`, `D3DDDICB_ESCAPE` {`hDevice` 0, `Flags`, `pPrivateDriverData`, `PrivateDriverDataSize`, `hContext`}): since `hContext` is set, the KMD forwards them to the escape function of the engine of the context ([Escapes](../drivers/qcdxkm8930.md#escapes)). After creation, the two device contexts send a 0x90-byte escape {0x40, 1, 0, 0x11000000 / 0x12000000, 4, …} (`sub_10011C4C`, `sub_10011F54`) and keep the dword returned at `+0x18`.

The video commands share a header (the buffers of `sub_100125C8` go into the command buffer, the others are escapes):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | 0x501 |
| 0x04 | 4 | Command code |
| 0x08 | 4 | Size of the whole buffer |
| 0x0C | 4 | Session (decoder / encoder id returned by the open command), or 0 |
| 0x10… | | Parameters |

| Code | Size | How | Sender | Comment |
|------|------|-----|--------|---------|
| 0x2001 | 0x1C | Escape | `sub_1001242C` | Open the video context; returns its id at `+0x18` |
| 0x2002 | 0x18 | Escape | `sub_10012324` | Close the video context |
| 0x2100 | 0x34 | Escape | `sub_10012ED4`, `sub_10015A94`, `sub_10018A34`, `sub_1001B778` | Decoder (H.264, VC-1, MPEG-2, MPEG-4): open the session; id returned at `+0x10` (0 = `E_FAIL`) |
| 0x1100 | 0xA8 | Command | `sub_10012C80`, `sub_10015840`, `sub_100187E0`, `sub_1001B524` | Decoder: session parameters ? |
| 0x1101 | 0x200 / 0x278 / 0x278 / 0x288 | Command | `sub_10013038`, `sub_10015BF8`, `sub_10018BA0`, `sub_1001B8DC` | Decoder: decode a frame (H.264 / VC-1 / MPEG-2 / MPEG-4) |
| 0x1102 | 0x20 | Command | `sub_10012B40`, `sub_10017184`, `sub_100186A0`, `sub_1001B3E4` | Decoder: ? (close / flush ?) |
| 0x2200 | 0x98 | Escape | `sub_10025850` | Encoder: open, see below |
| 0x2201 | 0x20–0x28 | Escape | `sub_10024484`… | Encoder: set property (id at `+0x10`) |
| 0x2202 | 0x20–0x28 | Escape | `sub_100242DC`… | Encoder: get property |
| 0x2203 | 0x230 | Escape | `sub_10027E2C` | Encoder: wait for / read an output event |
| 0x1200 | 0x20 | Command | `sub_10024194` | Encoder: start ? |
| 0x1201 | 0x80 | Command | `sub_10026820` | Encoder: encode a frame ? |
| 0x1202 | 0x98 | Command | `sub_10024ED4` | Encoder: ? |
| 0x1203 | 0x20 | Command | `sub_10025008` | Encoder: ? |
| 0x1204 | 0x20 | Command | `sub_10023F70` | Encoder: stop / flush ? (then waits on an event) |

The meaning of these codes on the KMD side wasn't checked: the escape function of the VIDEO engine of qcdxkm8930.sys isn't documented.

### Encoder devices

The three private "decoder" GUIDs create the same 0x5F8-byte object (`sub_100277B8`, vtable `off_100294D4`). `pfnDecodeExtensionExecute` (vtable `+0x1C`, `sub_1002725C`) dispatches on the `Function` code (the private data is the input):

| Function | Handler | Command |
|----------|---------|---------|
| 0 | `sub_10025850` | Open: escape 0x2200, events, thread |
| 1 | `sub_10024194` | 0x1200 |
| 2 | `sub_10023F70` | 0x1204 |
| 3 | `sub_10026820` | 0x1201 |
| 4 / 5 | `sub_10024BE0` / `sub_10024D60` | Get / set property 5 (0x24 bytes) |
| 6 / 7 | `sub_10025654` / `sub_10024A68` | Get / set property 3 (0x28 bytes) |
| 8 / 9 | `sub_100254A4` / `sub_100248F8` | Get / set property 1 |
| 10 / 11 | `sub_100252F4` / `sub_10024788` | Get / set property 2 |
| 12 / 13 | `sub_10025144` / `sub_10024618` | Get / set property 4 |
| 14, 15, 18 | `sub_100264A8`, `sub_10026290`, `sub_10023D84` | ? (no escape) |
| 16 / 17 | `sub_100242DC` / `sub_10024484` | Get / set property 6 (0x24 bytes) |
| 19 | `sub_10025008` | 0x1203 |
| 20 | `sub_10024ED4` | 0x1202 |
| other | | `E_FAIL` |

Open (`sub_10025850`): the 0x98-byte escape 0x2200 carries at `+0x18` a codec GUID chosen from the device GUID, at `+0x44` the codec type, at `+0x48` the level (from the profile / level given by the caller):

| Device GUID | Codec GUID sent | Type | Level values |
|-------------|-----------------|------|--------------|
| `{129F7B40…}` | `{13042960-A82D-4EE9-8949-A82C408D80E2}` | 1–5 | 0–15 |
| `{CBB1A2A4…}` | `{AAD1093E-86FB-4809-AE7B-986892DD1565}` | 6 or 7 | 0x10–0x16 |
| `{B7BC9768…}` | `{F79CE34B-24B5-4650-96A6-A49AE04F454A}` | 8 | ? |

The GUIDs `{FB8D8600-25C3-435E-94C5-A4B50397EC46}` and `{B27227A5-59FB-4BFC-AF1E-42237F213DBC}` and the buffer type 159 are also used there. It then creates two events (`CreateEventW`, encoder `+0xEC`, `+0xF0`) and a thread (`CreateThread`, `sub_100281AC` → `sub_10027E2C`).

The thread waits on the two events (`WaitForMultipleObjectsEx`, infinite); on the first it sends escape 0x2203 (0x230 bytes, session at `+0x0C`) and processes the reply (`sub_100278B8`) in a loop, until the encoder state (`+0x104`) is 5–8. The destructor (`sub_100270B4`) sets the state to 8, signals the event, waits for the thread for 5 s (`WaitForSingleObject`) and closes the handles.

### ETW

WPP provider `{CC501161-986D-4178-8919-72600831CDC1}` (`TraceMessage`, control block `off_1002B040`): flag 0x10 function entry / exit (level ≥ 4), 0x08 errors (level ≥ 2), 0x04 caps (level ≥ 4), 0x02 encoder thread (level ≥ 5).

Manifest provider `{8EFF03D9-49C8-412C-9AC5-9521D22D66C1}` (`EventRegister`, callback `ETW_EnableCallback` keeps the level and keywords): registered only, the DLL imports no `EventWrite`.
