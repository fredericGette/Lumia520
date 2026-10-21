## Qc8x60aud.sys

Qualcomm audio adapter driver (PortCls miniport) of the MSM8x60/8960/8930 family, with Nokia extensions.  
It is a WDM PortCls adapter (`PcInitializeAdapterDriver` / `PcAddAdapterDevice`) linked with KMDF only for its stub library. It publishes two pairs of KS filters: the main audio endpoint (`TopologyHeadset` + `WaveHeadset`) and a second "stereo" pair (`Topology Stereo` + `Wave Stereo`) used for the Nokia "Enhanced Audio Recording Device" (Rich Recording). The audio data is played/recorded by the QDSP6 (LPASS) through the Q6 audio driver `qcq6ad8930.sys` (ASM/ADM sessions, AFE ports), and the codec (ADIE, WCD93xx "Tabla"/"Sitar" family) is switched on and routed through the audio codec driver. It also handles the voice call path, Bluetooth SCO (HFP HCI-bypass), the headset detection (MBHC), FM, telecoil and the Nokia audio effects (Dolby Headphone, graphic equalizer, volume normalizer).  
Next to the PortCls IRP path, it exposes three private device interfaces with their own IOCTLs (see [Interfaces](#interfaces)).  
PDB path `E:\build_e\subtask\E05A4CC0_98\output\audio\fre\qc8x60aud.pdb`. Pool tags `QAU0`…`QAU5`, `MSVD`, `PcCr`, `1GER`, `IPCA`.

ACPI device `\_SB.QCRT` (`_HID` `QCOM0744`), with `_DEP` on `\_SB.Q6AD` (QCOM0750, Q6 audio), `\_SB.AHWI` (QCOM0743), `\_SB.MBGP` (QCOM2149, GPIO headset detection), `\_SB.TICO` (QCOM0742) and `\_SB.ACHW` (QCOM0741, audio codec hardware).

There's no named `\Device\` object and no symbolic link created by the driver: PortCls creates the device object, and the driver registers device interfaces on it.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\QC8x60AUD`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0744\<instance>`  

### Start sequence

The start is done in three steps, each one waiting for a device interface:
1. `StartDevice` (`sub_435380`) waits for the arrival of the Q6 audio interface `{5F51A34C-…}` (`IoRegisterPlugPlayNotification`, callback `sub_435518`).
2. Then (work item `sub_436328`) it waits for the codec interface `{3FE58EBD-…}` (callback `sub_435658`).
3. Then (work item `sub_43648C` → `sub_43579C`) it creates the adapter common object (`IID_IAdapterCommon` `{7EDA2950-BF9F-11D0-871F-00A0C911B544}`, the MSVAD sample one), registers the power management, its three private interfaces, and the subdevices:  

| Subdevice name | Port | Miniport |
|----------------|------|----------|
| TopologyHeadset | `CLSID_PortTopology` `{B4C90A32-5791-11D0-86F9-00A0C911B544}` | `sub_42A734` (topology object kept in `dword_422C04`) |
| WaveHeadset | `CLSID_PortWaveRT` `{CC9BE57A-EB9E-42B4-94FC-0CAD3DBCE7FA}` | `sub_42E3E4` |
| Topology Stereo | `CLSID_PortTopology` | `sub_425008` (topology object kept in `dword_422BB4`) |
| Wave Stereo | `CLSID_PortWaveRT` | `sub_42E44C` |

Between the headset and the stereo pairs, it starts waiting for the Bluetooth HFP interface `{BE446647-…}` (`sub_435A88`).  
The two calls to `PcRegisterPhysicalConnection` (`sub_435EF8`) are made with port pointers that are never filled (always NULL), so **no physical connection is registered** ?  

> [!NOTE]
> The work items are allocated with tag `QAU4` but freed with tag `MSVD` (`ExFreePoolWithTag(…, 'DVSM')`). Harmless as long as the pool tag is not protected.

### ACPI _DEV

At start the driver evaluates the method `_DEV` of its ACPI node (`IOCTL_ACPI_EVAL_METHOD` 0x32C004 sent to the PDO, `sub_408970` / `sub_408F28`, input 8 bytes `'BieA'` + `"_DEV"`, output buffer 1108 bytes). It expects a package: one integer (flag stored at `ctx+0x2C4`, must be 0 or 1) followed by sub-packages of 6 integers (at most 49 ?), terminated by `0xFF`. Each sub-package is stored as an 8-dword entry of a device table (`ctx+0x48 + 32*i`). It's the table of the audio devices (Rx device, Tx device, Rx/Tx sample rates, Rx/Tx bits per sample ?).  
On the Lumia 520 (`\_SB.QCRT._DEV`), the flag is 1 and there are 20 entries:  
| Index | Values | Comment |
|-------|--------|---------|
| 0 | 0x0E, 0x0B, 48000, 48000, 16, 16 | |
| 1 | 0x0A, 0x08, 48000, 48000, 16, 16 | |
| 2 | 0x07, 0x04, 48000, 48000, 16, 16 | |
| 3 | 0x44, 0x00, 48000, 48000, 16, 16 | |
| 4 | 0x00, 0x00, 48000, 48000, 16, 16 | |
| 5–7 | 0x0E, 0x04, 48000, 48000, 16, 16 | |
| 8 | 0x00, 0x00, 48000, 48000, 16, 16 | |
| 9 | 0x07, 0x04, 48000, 48000, 16, 16 | |
| 10 | 0x0E, 0x27, 48000, 48000, 16, 16 | |
| 11 | 0x0A, 0x27, 48000, 48000, 16, 16 | |
| 12 | 0x25, 0x24, 8000, 8000, 16, 16 | 8 kHz: Bluetooth SCO ? |
| 13 | 0x25, 0x40, 8000, 8000, 16, 16 | 8 kHz: Bluetooth SCO ? |
| 14 | 0x11, 0x10, 48000, 48000, 16, 16 | |
| 15–16 | 0x00, 0x00, 48000, 48000, 16, 16 | |
| 17–18 | 0x0E, 0x04, 48000, 48000, 16, 16 | |
| 19 | 0x00, 0x0B, 48000, 48000, 16, 16 | |

### Registry

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\QCAUD` (read with `RtlQueryRegistryValues(RTL_REGISTRY_SERVICES, L"QCAUD", …)` in `sub_42F160`, `RTL_QUERY_REGISTRY_DIRECT`, REG_DWORD). Note the key name: `QCAUD`, not the service name `QC8x60AUD`. A missing value keeps the default.  
| Registry value | value | comment |
|----------------|-------|---------|
| GpioBasedHeadsetDetection | 1 | Selects the headset detection driver: ≠0 → GPIO based (MBGP) interface `{093C3754-…}`, 0 → codec MBHC interface `{790370AE-…}` (`sub_42B850`) |
| OffloadPreAllocMemorySize | 0x200000 | Size in bytes of the contiguous memory pre-allocated for the offload (compressed) playback (`MmAllocateContiguousMemorySpecifyCache`) ? |
| MinBufferSize | 10 | WaveRT buffer size limit (unit ?) |
| MaxBufferSize | 60000 | WaveRT buffer size limit (unit ?) |
| EnableDRM | 0 | Read for the render pins (pin types 0 and 1) |

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\QC8x60AUD` (`ZwOpenKey` + `ZwQueryValueKey`, `sub_409250` / `sub_403A30`):  
| Registry value | value | comment |
|----------------|-------|---------|
| Fluence | 0 | Enables the Qualcomm Fluence (dual-mic noise suppression) ? |
| EnableWVE | 0 | Enables the WVE (wide voice enhancement ?) |
| StereoRecordingEndpointMonoOverride | 0 | When ≠0, the "stereo" recording endpoint records in mono (and `IOCTL 0x90007408` reports 1 channel) |

Other registry keys:  
| Registry key | Value | comment |
|--------------|-------|---------|
| `HKLM\Software\Microsoft\ManufacturingOS` | ManufacturingMode | When ≠0, a manufacturing default device is selected (`ctx+0x14` = 7) |
| `HKLM\System\Accessibility` | telecoil_UI, telecoil | `telecoil` is read only when `telecoil_UI` = 1 (hearing-aid telecoil mode), watched with `ZwNotifyChangeKey` (`sub_409BB4`) |
| `HKLM\Software\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{…}` | DeviceState, `Properties\{a45c254e-df1c-4efd-8020-67d146a850e0},2` | Searched by IOCTL 0x90007400 / 0x90007404 to find the "Enhanced Audio Recording Device" endpoint |
| `HKLM\Software\OEM\Nokia\Audio\EnhancedRecording\Orientation` | Orientation | Read for the stereo recording (`sub_436D88`) |
| `HKLM\Software\OEM\Nokia\Audio\EnhancedRecording\LowFrequencyPreset` | Preset | Read for the stereo recording (`sub_436E0C`) |
| `HKLM\Software\OEM\Nokia\Audio\EnhancedRecording\Vibra` | Disable | **Written** (`ZwSetValueKey`): 1 when the enhanced (stereo) recording starts (`sub_40A1D4`), 0 when it stops (`sub_40A294`). It's the value watched by [hwnvibradime.sys](./hwnvibradime.md) to refuse vibrations during the recording |
| `HKLM\Software\OEM\Nokia\DolbyHeadphone` | Supported, Available, Enabled, AllowedForAudio\Allowed, AllowedForVideo\Allowed, NotAvailableReason | Dolby Headphone effect. `Supported`, `Available` and `NotAvailableReason` (0 or 2) are written by the driver; `Enabled`/`Allowed` are read and watched with `ZwNotifyChangeKey` |
| `HKLM\Software\OEM\Nokia\GraphicEqualizer` | Supported, Available, Enabled, GeqBandLevel1…7\BandLevel, NotAvailableReason | 7-band graphic equalizer, same principle |
| `HKLM\Software\OEM\Nokia\VolumeNormalizer` | Supported, Available, Enabled, NotAvailableReason | Volume normalizer, same principle |

GUID of the ETW provider (manifest, `EtwRegister`):  
`{F7DDD6D0-D9D5-4448-85DB-CF6FFA861E4A}`

GUIDs of the WPP providers:  
`{B92C2819-2DAA-4804-BC96-720A82209897}`  
`{410BA701-C0A7-4806-803C-CFAB7D50AB21}`

It also writes debug messages with `DbgPrintEx` (component 0x4F), e.g. `CTablaTxHelper::CodecHardwareStart ADIE_CODEC_DRIVER_IOCTL_ACQUIRE_DEVICE Status - 0x%x`.

It communicates with the following devices (found with `IoGetDeviceInterfaces` / `IoRegisterPlugPlayNotification`, opened with `IoGetDeviceObjectPointer`):  
| Interface class GUID | Driver | Comment |
|----------------------|--------|---------|
| `{5F51A34C-6834-479D-9EA2-EAFA622524BA}` | qcq6ad8930.sys (`\_SB.Q6AD`) | Q6 audio (APR: ASM, ADM, AFE, voice). Mandatory at start. `IOCTL 0xADAD2BA1` returns its entry point, then all the commands go through that function (see [Q6 audio](#q6-audio-entry-point)) |
| `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` | audio codec driver (`\_SB.ACHW` ?) | ADIE codec. Mandatory at start. `ADIE_CODEC_DRIVER_IOCTL_*` (`0x5001xxxx`) |
| `{6DB5B55F-B7D5-4D95-A0AE-40DD78A17817}` | ? | `0x50012004` (4 bytes in, 4 bytes out) and `0x50012008` (8 bytes in, 4 bytes out), same IOCTL family as the codec |
| `{ABFE8B0D-5D26-4C5A-B5F2-1F33E47A4F65}` | ? (`\_SB.TICO` or `\_SB.AHWI` ?) | `0x50032000` / `0x50032004`, 16-byte input |
| `{093C3754-B2D1-4AC7-B93E-A8FD62FDF7C3}` | GPIO headset detection (`\_SB.MBGP`) ? | Used when `GpioBasedHeadsetDetection` ≠ 0. `0x500A2800` |
| `{790370AE-6E34-4800-8927-351A338FB740}` | codec headset detection (`\_SB.MBHC`) ? | Used when `GpioBasedHeadsetDetection` = 0. `0x500A2800` |
| `{BE446647-F655-4919-8BD0-125BA5D4CE65}` | Bluetooth HFP profile driver | `GUID_DEVINTERFACE_BLUETOOTH_HFP_SCO_HCIBYPASS`. SCO audio over HCI bypass. `IOCTL_BTHHFP_*` (`0x0022xxxx`) |
| ACPI node of the device | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` `_DEV` |

---

### Interfaces

The driver registers three device interfaces with a reference string on the PortCls device object (`sub_414768`, `sub_414864`, `sub_4148D8`). `IRP_MJ_CREATE`/`IRP_MJ_CLOSE` (`sub_4361A8`) and `IRP_MJ_DEVICE_CONTROL` (`sub_435FFC`) compare the file name of the request with the three reference strings; a match is handled by the driver itself, anything else goes to `PcDispatchIrp`. Before the adapter common object exists (start step 3), these requests fail with `STATUS_UNSUCCESSFUL`.  
| Interface class GUID | Reference string | Dispatch | IOCTLs |
|----------------------|------------------|----------|--------|
| `{83BF8857-5742-4B77-988D-1B7E9604E98D}` | `QC_AUDIO_THIRD_PARTY_PROPERTY_REF_STRING` | adapter `+0x6C` → `sub_41494C` | 0x90002C00, 0x90003000–0x90003048 |
| `{EF0CD115-6835-4702-BF26-8391AF34294F}` | `NOKIA_AUDIO_IOCTL_REF_STRING` | adapter `+0x70` → `sub_414BB0` | 0x9000B414, 0x9000B418 |
| `{3820686D-03BE-4825-9D71-9BBB06150C59}` | `NOKIA_ENHANCED_AUDIO_RECORDING_IOCTL_REF_STRING` | adapter `+0x74` → `sub_414C98` | 0x90007400–0x90007410 |

An unknown code completes with `STATUS_INVALID_PARAMETER` (third-party, Nokia audio) or `STATUS_INVALID_DEVICE_REQUEST` (enhanced recording).

> [!NOTE]
> None of these handlers checks `InputBufferLength`: they only check that the system buffer isn't NULL.

---

### IOCTL 0x90002C00

This IOCTL is processed by Qc8x60aud.sys (interface `QC_AUDIO_THIRD_PARTY_PROPERTY_REF_STRING`)

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xB00 (2816) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set a Q6 post-processing parameter ? | 12 + n (not checked) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Module id ? (copied to the Q6 message `+0x10`) |
| 04-07 | ? | Not used |
| 08-0B | ? | Parameter size ? (copied to the Q6 message `+0x14`) |
| 0C-… | ? | Parameter data (its address is passed in the Q6 message `+0x18`) |

The handler gets the Q6 entry point (`sub_414DB4`: `IoGetDeviceInterfaces({5F51A34C-…})` + `IoGetDeviceObjectPointer` + `IOCTL 0xADAD2BA1`), builds a 28-byte message `{ session ?, ?, 1, 0x10005010, in[0], in[2], &in[3] }` (the first two dwords come from the topology object, `sub_406D7C`) and calls `entry(0x10003, 0xADAD2BCD, &message, 28)`. Completed with `STATUS_SUCCESS` when the call returns 0.  
`sub_414DB4` never dereferences the file object returned by `IoGetDeviceObjectPointer`: each request leaks a reference.

---

### IOCTL 0x90003000…0x90003048 — headset / voice test controls

These IOCTLs are processed by Qc8x60aud.sys (interface `QC_AUDIO_THIRD_PARTY_PROPERTY_REF_STRING`). They are forwarded to the topology object (vtable `+0x34`, `sub_42BC4C`).

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xC00–0xC12 (3072–3090) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| IOCTL | Function | InputBuffer | Backend | Comment |
|-------|----------|-------------|---------|---------|
| 0x90003000 | 0xC00 | — | `sub_42751C` | Headset detection: entry point command 4 (start ?) |
| 0x90003004 | 0xC01 | — | `sub_404F54` | ? (voice/device manager) |
| 0x90003008 | 0xC02 | — | `sub_4279C4(0)` | Headset detection: command 5 with value 2 |
| 0x9000300C | 0xC03 | — | `sub_4279C4(1)` | Headset detection: command 5 with value 3 |
| 0x90003010 | 0xC04 | — | `sub_4279C4(2)` | Headset detection: command 1 (restart ?) |
| 0x90003014 | 0xC05 | — | `sub_4278A4` | Headset detection: command 5 with value 1 |
| 0x90003018 | 0xC06 | — | `sub_427768` | Headset detection: command 5 with value 0, then waits for the headset event |
| 0x9000301C | 0xC07 | 4 | `sub_405B08(n+1)` | Selects the Rx device ? n is the **byte pointed to by** the first dword of the input |
| 0x90003020 | 0xC08 | 4 | `sub_405F90(n+1)` | Selects the Tx device ? Same input as 0x9000301C |
| 0x90003024 | 0xC09 | — | none | Not handled by the switch: completed with the IRP's current status |
| 0x90003028 | 0xC0A | — | `sub_427640` | Headset detection: command 1 (reset ?) |
| 0x90003040 | 0xC10 | — | `sub_409CD0` | Returns a count (> 0) in the output, else `STATUS_INSUFFICIENT_RESOURCES` |
| 0x90003044 | 0xC11 | — | `sub_4049A0(1)` | Sets a global flag (`dword_422BD4`) to 1 |
| 0x90003048 | 0xC12 | — | `sub_4049A0(0)` | Sets the same flag to 0 |

Codes 0x90003000–0x90003028 are refused (trace only, status unchanged) while the topology flag `+0x758` is 0 (cleared at init; set elsewhere, probably once the headset detection is ready ?).  
Output buffer: when `OutputBufferLength` = 4, the driver writes the result: 0 = success, −1 (`FF FF FF FF`) = failure (or the count for 0x90003040). `Information` is always 4. Errors complete with `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A).

> [!NOTE]
> 0x9000301C and 0x90003020 read the first dword of the system buffer as a **pointer** and dereference it (`**(BYTE**)SystemBuffer`). A user-mode caller can make the kernel read any address (or crash it). It looks like test code that expected a kernel caller.

---

### IOCTL 0x9000B414 — set call state ?

This IOCTL is processed by Qc8x60aud.sys (interface `NOKIA_AUDIO_IOCTL_REF_STRING`)

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xD05 (3333) |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 4 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | State. Stored in the voice manager (`sub_4057D4`, `ctx+0x204`). 2 = sets the flag `+0x540` when no voice call is active, 3 = clears it, 4 = stops the voice processing and restores the default devices (`sub_405B08(2)`). Other values are only stored |

When `OutputBufferLength` = 4, the driver writes `FF FF FF FF` and returns 4 bytes. Always `STATUS_SUCCESS`.

---

### IOCTL 0x9000B418 — voice call path

This IOCTL is processed by Qc8x60aud.sys (interface `NOKIA_AUDIO_IOCTL_REF_STRING`)

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xD06 (3334) |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 4 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 1 = tear down the voice path (log `"Inactive Voice Call"`), other = set up the voice path on the current Rx/Tx devices (log `"Active Voice Call"`) |

Backend `sub_42B0E0` → `sub_4053D0` (only when the topology flag `+0x754` is 0). Same output as 0x9000B414.

---

### IOCTL 0x90007400 — get enhanced recording endpoint id

This IOCTL is processed by Qc8x60aud.sys (interface `NOKIA_ENHANCED_AUDIO_RECORDING_IOCTL_REF_STRING`)

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xD00 (3328) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | n |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | `{0.0.1.00000000}.{…}` | UTF-16 MMDevice endpoint id, zero terminated |

`sub_402530` enumerates the subkeys of `HKLM\…\MMDevices\Audio\Capture`. For each endpoint with `DeviceState & 0xF` = 1 (active), it reads `Properties\{a45c254e-df1c-4efd-8020-67d146a850e0},2` (`PKEY_Device_DeviceDesc`) and compares it (case sensitive) with `"Enhanced Audio Recording Device"`. The id is `"{0.0.1.00000000}."` + the subkey name.  
Returns `STATUS_SUCCESS` with `Information` = size in bytes, `STATUS_BUFFER_TOO_SMALL` (0xC0000023) with `Information` = required size, or `STATUS_NOT_FOUND` (0xC0000225).

---

### IOCTL 0x90007404 — get enhanced recording endpoint id size

This IOCTL is processed by Qc8x60aud.sys (interface `NOKIA_ENHANCED_AUDIO_RECORDING_IOCTL_REF_STRING`)

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xD01 (3329) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `5A 00 00 00` | Size in bytes of the id returned by 0x90007400, terminating zero included |

Same search as 0x90007400 with a NULL buffer.

---

### IOCTL 0x90007408 — get recording levels ?

This IOCTL is processed by Qc8x60aud.sys (interface `NOKIA_ENHANCED_AUDIO_RECORDING_IOCTL_REF_STRING`)

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xD02 (3330) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 4 | 4 × (count + 1) |

Inputbuffer / Outputbuffer (same buffer):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | In: number of values requested. 0 = only return the number of values available. Out: number of values returned |
| 04-07 | ? | Value of channel 1 (default `00 00 00 80` = INT_MIN) |
| 08-0B | ? | Value of channel 2 (only when the stereo recording isn't overridden to mono) |

`sub_436E90` / `sub_437010`: the values are read from the active stereo recording stream through the Q6 entry point (command `0xADAD2C51`, 20-byte buffer, `sub_415D6C`). 1 value in mono, 2 in stereo (`StereoRecordingEndpointMonoOverride`). If the output buffer is too small, it returns `STATUS_SUCCESS` with `Information` = required size and no data.

---

### IOCTL 0x9000740C — get recording mode

This IOCTL is processed by Qc8x60aud.sys (interface `NOKIA_ENHANCED_AUDIO_RECORDING_IOCTL_REF_STRING`)

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xD03 (3331) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 0 = topology not created, 1 = normal, 2 = topology flag `+0x754` set (voice call ?) |

---

### IOCTL 0x90007410 — get recording state

This IOCTL is processed by Qc8x60aud.sys (interface `NOKIA_ENHANCED_AUDIO_RECORDING_IOCTL_REF_STRING`)

| Property | Value |
|----------|-------|
| Device | 0x9000 |
| Function | 0xD04 (3332) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Bit 0 = a recording stream is running (`sub_40A5D4`, stream state 1, 2 or 3), bit 1 = `sub_401D00` (?). `FF FF FF FF` if the topology isn't created |

---

### IOCTL 0xADAD2BA1 — get Q6 entry point

This IOCTL is sent by Qc8x60aud.sys to qcq6ad8930.sys (interface `{5F51A34C-…}`)

| Property | Value |
|----------|-------|
| Device | 0xADAD |
| Function | 0xAE8 (2792) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ? | interface `{5F51A34C-6834-479D-9EA2-EAFA622524BA}` | 0 | 20 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | ? | ? |
| 10-13 | ? | Entry point `NTSTATUS fn(handle, command, buffer, size)` |

Sent by each Q6 client object of the driver (`sub_40BF84`, `sub_40CF14`, `sub_40E168`, `sub_40FBEC`, `sub_411A54`, `sub_438C28`, `sub_414DB4`).

### Q6 audio entry point

All the audio commands are then calls of the entry point, with command codes in the same `0xADADxxxx` format (they are not IOCTLs). Codes found in the binary:  
| Command | Used by | Comment |
|---------|---------|---------|
| 0xADAD2B45, 2B49, 2B4D, 2B51, 2B55, 2B59, 2B5D, 2B71, 2B79, 2B7D, 2B81, 2B85, 2B89 | stream objects (`sub_4152D0`…`sub_4166A4`, `sub_40B8C4`, …) | ASM/ADM session control ? (open, format, run, pause, close, …) |
| 0xADAD2BA9, 2BAD, 2BB1, 2BB5, 2BBD, 2BC5, 2BC9 | `sub_416A5C`, `sub_415430`, `sub_415ABC`, `sub_40D6D0`, `sub_4166A4` | ? |
| 0xADAD2BCD | `sub_41494C` | Set post-processing parameters (IOCTL 0x90002C00) |
| 0xADAD2C45, 2C49, 2C4D, 2C51, 2C55, 2C59 | `sub_416D1C`…`sub_415EEC` | 2C51 = read recording values (IOCTL 0x90007408) |
| 0xADAD6B41, 6B45, 6B4D, 6B55, 6B59 | `sub_4163F0` | ? |

---

### IOCTL 0x50012004 / 0x50012008 / 0x5001200C / 0x50012010 — ADIE codec

These IOCTLs are sent by Qc8x60aud.sys to the audio codec driver (interface `{3FE58EBD-…}`), from `CTablaTxHelper::CodecHardwareStart` (`sub_4283AC`) and `CodecHardwareStop` (`sub_428218`), and by the Rx helper (`sub_42E204`, `sub_42E0C0`).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x801–0x804 (2049–2052) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x50012004 ADIE_CODEC_DRIVER_IOCTL_ACQUIRE_DEVICE | interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` | 12 | 0 |
| 0x50012008 ADIE_CODEC_DRIVER_IOCTL_RELEASE_DEVICE | interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` | 12 | 0 |
| 0x5001200C ADIE_CODEC_DRIVER_IOCTL_ACTIVATE_DEVICE | interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` | 12 | 0 |
| 0x50012010 ADIE_CODEC_DRIVER_IOCTL_DEACTIVATE_DEVICE | interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` | 12 | 0 |

Inputbuffer (ACQUIRE_DEVICE):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | ? |
| 04-07 | 01 00 00 00 | Number of entries ? |
| 08-0B | ? | Kernel pointer to a 16-byte descriptor `{ device id, 1, ?, bits per sample }` |

The names come from the `DbgPrintEx` messages of the driver. Other codes of the same family sent to the same interface: 0x50012020 (`sub_42DBC4`), 0x50012040 (`sub_42D884`), 0x50012044 (`sub_42D980`).

---

### IOCTL 0x500A2800 — get headset detection entry point

This IOCTL is sent by Qc8x60aud.sys to the headset detection driver (`sub_427020` → `sub_426E88`)

| Property | Value |
|----------|-------|
| Device | 0x500A |
| Function | 0xA00 (2560) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ? | interface `{093C3754-…}` or `{790370AE-…}` | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 04 00 00 00 | Size of the result |
| 04-07 | ? | Kernel pointer to a dword that receives the entry point `fn(command, buffer, size)` |

Commands then sent to the entry point: 3 = register the callback `{sub_404688, context}` (8 bytes), 1 = start/reset, 4 = ?, 5 = set mode (4-byte value 0–3). Jack events come back through the callback (`DbgPrint "HeadSet Event"` in `sub_427244`).

---

### IOCTL 0x0022000B…0x0022002F — Bluetooth HFP

These IOCTLs are sent by Qc8x60aud.sys to the Bluetooth HFP driver (interface `GUID_DEVINTERFACE_BLUETOOTH_HFP_SCO_HCIBYPASS`). The interface arrival (`sub_435B4C`) opens it (`sub_42966C`) and starts a system thread (`sub_429860`) that keeps a connection-status request pending. The names are guesses from the Microsoft `bthhfpddi.h` interface, matched by behaviour.

| Property | Value |
|----------|-------|
| Device | 0x22 (FILE_DEVICE_UNKNOWN) |
| Function | 2, 3, 4, 5, 10, 11 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x22000B IOCTL_BTHHFP_DEVICE_GET_DESCRIPTOR ? | interface `{BE446647-F655-4919-8BD0-125BA5D4CE65}` | 0 | 16 |
| 0x22000F IOCTL_BTHHFP_DEVICE_REQUEST_CONNECT ? | interface `{BE446647-F655-4919-8BD0-125BA5D4CE65}` | 0 | 0 |
| 0x220013 IOCTL_BTHHFP_DEVICE_REQUEST_DISCONNECT ? | interface `{BE446647-F655-4919-8BD0-125BA5D4CE65}` | 0 | 0 |
| 0x220017 IOCTL_BTHHFP_DEVICE_GET_CONNECTION_STATUS_UPDATE ? | interface `{BE446647-F655-4919-8BD0-125BA5D4CE65}` | 4 | 4 |
| 0x22002B IOCTL_BTHHFP_STREAM_OPEN ? | interface `{BE446647-F655-4919-8BD0-125BA5D4CE65}` | 0 | 0 |
| 0x22002F IOCTL_BTHHFP_STREAM_CLOSE ? | interface `{BE446647-F655-4919-8BD0-125BA5D4CE65}` | 0 | 0 |

- 0x22000B (`sub_429D0C`): the 16 bytes are kept at `ctx+0x74`. 
- 0x22000F / 0x220013 are sent by the "BTSCO Property Handler" (`sub_410570`) for `KSPROPSETID_BtAudio` (`{7FA06C40-B8F6-4C7E-8556-E8C33A12E54D}`) properties 0 (`ONESHOT_RECONNECT`) and 1 (`ONESHOT_DISCONNECT`). The same handler also answers `KSPROPSETID_Jack` (`{4509F757-…}`) properties 1, 2 and 4 (container id = 16 bytes from 0x22000B), and property 1 of `{7F50F0BE-8E26-4F96-A079-1CF84102B918}` (?).
- 0x220017 (`sub_410944`): input = previous status, output = new status; the request stays pending until the status changes. It's cancelled with `IoCancelIrp` when the thread must stop. The status updates the jack "connected" field of the KS jack descriptions (`sub_429AD0`).
- 0x22002B / 0x22002F are sent when the SCO stream starts / stops (`sub_429B6C` / `sub_429C3C`, only if not already open / open).

---

### Other GUID

`IID_IAdapterCommon` (MSVAD sample)  
`{7EDA2950-BF9F-11D0-871F-00A0C911B544}`

Interface queried on the ports after registration (`sub_43522C`) ?  
`{47BA0351-BC4B-4869-8134-B74FE17852D8}`

Property set handled by the BT SCO property handler ?  
`{7F50F0BE-8E26-4F96-A079-1CF84102B918}`
