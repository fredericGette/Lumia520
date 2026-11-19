## Bthl2cap.sys

Windows Phone Bluetooth filter driver: SCO audio for the hands-free profile, and L2CAP channels for user mode.  
It's a KMDF filter (`WdfFdoInitSetFilter`) installed on three kinds of devices of the Microsoft Bluetooth stack. `L2CapDriverDeviceAdd` (0x1000597C) picks the role from the device properties:  
- on the `BthMini` device (compatible ID `MS_BTHX_BTHMINI`, the child of [qcbluetooth8930.sys](./qcbluetooth8930.md)) it creates the **audio device**: user-mode control of the SCO link by the HFP/BTAG service through `IOCTL_BTH_WP8_*`, and the kernel audio interface `IOCTL_BTHHFP_*` used by the audio driver [qc8x60aud.sys](./qc8x60aud.md);
- on `BTH\MS_BTHBRB` (hardware ID) it only fetches the Bluetooth profile driver interface (`GUID_BTHDDI_PROFILE_DRIVER_INTERFACE`, BRB allocation and submission), once, into the global `g_profileInterface`; no device context is created;
- on a `BTHENUM` PDO whose enumerator type is "protocol" it creates a **protocol device**, which gives user mode an L2CAP API (`IOCTL_BTH_WP8_L2CAP_*`, then `ReadFile` / `WriteFile` on the channel), used by [BtConnectionManagerService.dll](../libraries/btconnectionmanagerservice.md).

The PDB name is `bthl2cap.pdb`, the build date `Jan 23 2015 18:14:09`, the source path `src\net\bluetooth\product\drivers\bthl2cap\` (`driver.c`, `device.c`, `file.c`, `scohandler.c`, `protocoldevice.c`, `protocolchannel.c`, `protocolfile.c`). The function names come from the debug strings.

There's no named device object and no symbolic link. Each IOCTL queue is the default queue of its device, parallel, and every IOCTL not handled is forwarded to the next driver (`WdfRequestSend`, `WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET`). File creation is forwarded synchronously to the next driver too.

Registry key: the `Parameters` subkey of the service key received by `DriverEntry` (`g_BthL2CAPDriverParametersRegistryPathName`). The values are read by `BthL2CAPQueryRegistryDWord` (0x10005BC8, `ZwQueryValueKey`, only accepted if REG_DWORD) each time an audio device is initialised (`L2CapScoCreateDevice`). They are the SCO link parameters (HCI `Setup_Synchronous_Connection`):  
| Registry value | value | comment |
|----------------|-------|---------|
| ScoTxOctetsPerSecond | 8000 (0x1F40) | Transmit bandwidth. Default 8000 |
| ScoRxOctetsPerSecond | 8000 (0x1F40) | Receive bandwidth. Default 8000 |
| ScoMaxLatency | 0xFFFF | Max latency, default 0xFFFF (don't care) |
| ScoVoiceSetting | 0x60 | Voice setting, default 0x60 (CVSD, 16-bit linear input) |
| ScoRetransmissionEffort | 1 | Byte, default 1 (power consumption optimised) |
| ScoAllowedPacketTypes | 0x37 | Packet types, default 0x37 (HV1, HV2, HV3, EV4, EV5). EV3 (0x8) is added when wide band audio is requested |
| ScoDisallowedPacketTypes | 0x280 | "No EDR" packet type bits, default 0x280 (no 3-EV3, no 3-EV5). 0x40 (no 2-EV3) is removed when wide band audio is requested |

GUID of the ETW provider (only used by the fatal error routine):  
`{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}` (`Microsoft-WindowsPhone-Net-Debug`)

The fatal error routine (`McGenEventUnregister_0` 0x10005700, misnamed by IDA) is the same as `CellFatalError` of [cellmux.sys](./cellmux.md#guid-of-the-etw-provider): `DbgPrintEx` of `Fatal Error (0x%08X) in kernel mode at api (%s) in file (%s) at line (%d)`, one `EtwWrite` of `NET_FATAL_ERROR`, then `DbgBreakPointWithStatus` with a debugger, **bugcheck** (`__fastfail(7)`) without. It is called when almost any WDF call fails. The debug traces (`DbgPrintEx` component 0x91, prefix `BthL2Cap`) are always compiled in.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Next driver of the `BTH\MS_BTHBRB` stack | BthEnum.sys / BthPort.sys (Microsoft) | `IRP_MN_QUERY_INTERFACE` `GUID_BTHDDI_PROFILE_DRIVER_INTERFACE` (size 36, version 0x200), in `L2CapDeviceInitializeInterface` (0x1000557C). The interface is used for every BRB (`BthAllocateBrb` / `BthFreeBrb`) |
| Next driver of the `BTHENUM` stack | BthEnum.sys (Microsoft) | [internal IOCTL 0x410007](#internal-ioctl-0x410007--ioctl_internal_bthenum_get_enuminfo) to recognise a protocol PDO, then the L2CAP BRBs (`IOCTL_INTERNAL_BTH_SUBMIT_BRB`, `WdfIoTargetFormatRequestForInternalIoctlOthers`) |
| Next driver of the `BthMini` stack | BthMini.sys / BthPort.sys (Microsoft) | SCO BRBs |

### Device contexts

| Device | Context | Content |
|--------|---------|---------|
| Audio device (`L2CapDeviceCreate`, 0x10005364) | `L2CAP_DEVICE_CONTEXT` | +0 WDFDEVICE, +4 audio (SCO) object of the device or NULL, +8 interface string, +0x14 manual queue of the pending `IOCTL_BTHHFP_STREAM_OPEN`, +0x18 manual queue of the pending `IOCTL_BTHHFP_DEVICE_GET_CODEC_ID` |
| Audio device file | `L2CAP_FILE_CONTEXT` | +0 audio (SCO) object owned by this handle |
| Protocol device (`L2CapProtocolDeviceCreate`, 0x10009624) | `L2CAP_PROTOCOL_DEVICE` | +4 protocol GUID (from the enumerator info), +0x14 owner file, +0x18 PSM, +0x1A PSM2, +0x1C server handle, +0x24 manual queue of the pending LISTEN, +0x28 / +0x30 channel lists (+0x30 = unattached channels), +0x38 / +0x80 L2CAP configuration of the two PSMs (0x48 bytes each), +0xC8 surprise-removed flag |
| Protocol device file | `L2CAP_PROTOCOL_FILE` | +0 device context, +4 attached channel, +8 owner flag |

---

## Audio device

The audio device is created on the `BthMini` device. `L2CapDeviceCreate` creates and enables the interface `GUID_BTHWP8_AUDIO_DEVICE_INTERFACE` `{5E1429D2-01B6-458D-8687-3F976014F4BB}`. [BtConnectionManagerClient.dll](../libraries/btconnectionmanagerclient.md#sco-audio) opens it (for [BTAGService.dll](../libraries/btagservice.md)) and sends `IOCTL_BTH_WP8_INITIALIZE_AUDIO_DEVICE` with the address of the hands-free device: this creates the audio (SCO) object (`L2CapScoCreateDevice`, 0x1000B964, 0x90 bytes) owned by this handle, and creates and enables the interface `GUID_DEVINTERFACE_BLUETOOTH_HFP_SCO_HCIBYPASS` `{BE446647-F655-4919-8BD0-125BA5D4CE65}` on the same device. The arrival of this interface makes [qc8x60aud.sys](./qc8x60aud.md#ioctl-0x0022000b0x0022002f--bluetooth-hfp) open it and use the `IOCTL_BTHHFP_*`. Only one audio object exists per device and per handle.  
Closing the handle (`L2CapFileCleanup`, 0x10005C64) disables the HFP interface, asks for the SCO disconnection and the server unregistration, and sets the connection status to 0 (disconnected).

The driver is the link between both sides:  
- the audio driver's requests (stream open / close, volume) become **indications** that the user-mode service reads with [IOCTL 0x411CE4](#ioctl-0x411ce4--ioctl_bth_wp8_get_audio_indication) and executes (AT commands to the hands-free, SCO connection);
- the service's answers (audio connected, volume changed by the hands-free, codec) update the **statuses** that the audio driver monitors with the `*_GET_*_STATUS_UPDATE` IOCTLs.

The SCO link itself is opened by the driver (`L2CapScoHelperScoStateMachine`, 0x1000C5C4) from the flags set by [IOCTL 0x411CC4…0x411CD0](#ioctl-0x411cc40x411cd0--sco-connection-requests), with BRBs submitted to the `BthMini` stack: 0x200 (register a SCO server for incoming connections), 0x210 / 0x211 (open the channel), 0x204 (close), 0x201 (unregister the server). 0x209 (`L2CapScoHelperCompleteGetSystemInfoBrb`) is sent once at creation, and its word at +0x50 (supported packet types ?) is kept at +0x76. The SCO link state is 0 = idle, 1 = connecting, 2 = connected, 3 = disconnecting.

Audio (SCO) object:  
| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `L2CAP_DEVICE_CONTEXT *` |
| 0x08 | 8 | Bluetooth address of the hands-free |
| 0x10 | 1 | "Supports volume" (byte 8 of the INITIALIZE input) |
| 0x11 | 1 | Headset (byte 9 of the INITIALIZE input) |
| 0x14 | 4 | Manual queue of the pending `IOCTL_BTH_WP8_GET_AUDIO_INDICATION` |
| 0x18 | 8 | List of the indications not yet read (`{type, value}`, 16 bytes each, tag `8SCO`) |
| 0x20 | 4×16 | 4 [status slots](#status-slots): value, multiplier, "changed" flag, manual queue of the pending monitor requests |
| 0x60 | 4 | SCO request flags: 1 allow incoming, 2 forbid incoming, 4 connect, 8 disconnect |
| 0x64 | 4 | SCO server state (0…3); +0x68 server handle |
| 0x6C | 4 | SCO link state (0…3); +0x70 channel handle |
| 0x74 | 1 | "Incoming" byte reported with the state (set by the open channel completion when the BRB word at +0x0E is 0x211 ?) |
| 0x78 | 4 | Last state reported to user mode (-1 at creation) |
| 0x80 | 1 | Codec id ([IOCTL 0x411CE8](#ioctl-0x411ce8--ioctl_bth_wp8_set_codec_id)) |
| 0x82…0x8E | | SCO parameters from the registry |

#### Status slots

| Slot | Status | Initial value | Multiplier | Set by | Monitored with |
|------|--------|---------------|------------|--------|----------------|
| 0 | Speaker volume | 0 | 0x1111 | [IOCTL 0x411CDC](#ioctl-0x411cdc--0x411ce0--ioctl_bth_wp8_change_speaker_volume--change_microphone_volume) | 0x22001F |
| 1 | Microphone volume | 0 | 0x1111 | [IOCTL 0x411CE0](#ioctl-0x411cdc--0x411ce0--ioctl_bth_wp8_change_speaker_volume--change_microphone_volume) | 0x220027 |
| 2 | Connection status | 1 (connected) | 1 | 0 on handle close | 0x220017 |
| 3 | Stream status | 0xC00000A3 STATUS_DEVICE_NOT_READY | 1 | [IOCTL 0x411CD4 / 0x411CD8](#ioctl-0x411cd4--0x411cd8--ioctl_bth_wp8_set_audio_connected--set_audio_disconnected) | 0x220033 |

The value returned to the audio driver is value × multiplier: the HFP volume levels 0…15 become 0…0xFFFF. `L2CapScoUpdateStatus` (0x1000BE44) stores the value and completes a pending monitor request, or sets the "changed" flag if none is pending. `L2CapScoRequestUpdateNotification` (0x1000BD5C) completes the monitor request at once if its input is non-zero or if the flag is set (and clears the flag), otherwise it parks the request.

#### Indications

`L2CapScoEnqueueIndication` (0x1000BCD0) completes a pending [IOCTL 0x411CE4](#ioctl-0x411ce4--ioctl_bth_wp8_get_audio_indication) with `{type, value}`, or queues the indication if none is pending.  
| Type | Value | Source |
|------|-------|--------|
| 0 | SCO link state, + "incoming" byte | Change of the link state (not queued: reported when the state differs from the last one reported) |
| 1 | 0 | `IOCTL_BTHHFP_STREAM_OPEN` (audio connection request) |
| 2 | 0 | `IOCTL_BTHHFP_STREAM_CLOSE` |
| 3 | Volume 0…15 | `IOCTL_BTHHFP_SPEAKER_SET_VOLUME` |
| 4 | Volume 0…15 | `IOCTL_BTHHFP_MIC_SET_VOLUME` |
| 5 | 0 | `IOCTL_BTHHFP_DEVICE_GET_CODEC_ID` |

---

### IOCTL 0x411CC0 — IOCTL_BTH_WP8_INITIALIZE_AUDIO_DEVICE

This IOCTL is processed by Bthl2cap.sys (audio device). It is sent by [BtConnectionManagerClient.dll](../libraries/btconnectionmanagerclient.md#sco-audio).

| Property | Value |
|----------|-------|
| Device | 0x41 (FILE_DEVICE_BLUETOOTH) |
| Function | 0x730 (1840) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTH_WP8_INITIALIZE_AUDIO_DEVICE | ≥ 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | e.g. `78 92 3E C7 7B 53 00 00` | Bluetooth address of the hands-free |
| 08 | 01 | Supports volume control (returned in `BTHHFP_DESCRIPTOR`) |
| 09 | 00 or 01 | Headset: selects the KS node types (headphones + personal microphone, otherwise communication speaker + microphone) |
| 0A | 00 or 01 | Wide band audio: adds EV3 to the allowed packet types and allows 2-EV3 |
| 0B-0F | 00 | Not used |

The caller must have the capability `ID_CAP_BLUETOOTH_ADMIN` (`IsCapabilityPresent` → `CapabilityCheck` on the thread or process token), otherwise 0xC0000022 STATUS_ACCESS_DENIED. If the handle or the device already owns an audio object: 0x80000011 STATUS_DEVICE_BUSY. Otherwise `L2CapFileInitializeAudioDevice` (0x100075DC) creates the audio object (see [Audio device](#audio-device)) and returns STATUS_SUCCESS.

---

### IOCTL 0x411CC4…0x411CD0 — SCO connection requests

This IOCTL is processed by Bthl2cap.sys (audio device). It is sent by [BtConnectionManagerClient.dll](../libraries/btconnectionmanagerclient.md#sco-audio).

| Property | Value |
|----------|-------|
| Device | 0x41 (FILE_DEVICE_BLUETOOTH) |
| Function | 0x731…0x734 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x411CC4 IOCTL_BTH_WP8_ALLOW_INCOMING_SCO | 0 | 0 |
| 0x411CC8 IOCTL_BTH_WP8_FORBID_INCOMING_SCO | 0 | 0 |
| 0x411CCC IOCTL_BTH_WP8_CONNECT_SCO | 0 | 0 |
| 0x411CD0 IOCTL_BTH_WP8_DISCONNECT_SCO | 0 | 0 |

`L2CapFileScoChannelRequest` (0x1000840C) sets one flag of the audio object (+0x60) and clears the opposite one, then runs the SCO state machine: allow = set 1 clear 2, forbid = set 2 clear 1, connect = set 4 clear 8, disconnect = set 8 clear 4. Returns STATUS_SUCCESS, or 0xC0000184 STATUS_INVALID_DEVICE_STATE if the handle has no audio object. The result of the connection is reported later as an indication of type 0.

---

### IOCTL 0x411CD4 / 0x411CD8 — IOCTL_BTH_WP8_SET_AUDIO_CONNECTED / SET_AUDIO_DISCONNECTED

This IOCTL is processed by Bthl2cap.sys (audio device). It is sent by [BtConnectionManagerClient.dll](../libraries/btconnectionmanagerclient.md#sco-audio).

| Property | Value |
|----------|-------|
| Device | 0x41 (FILE_DEVICE_BLUETOOTH) |
| Function | 0x735 / 0x736 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x411CD4 IOCTL_BTH_WP8_SET_AUDIO_CONNECTED | 0 | 0 |
| 0x411CD8 IOCTL_BTH_WP8_SET_AUDIO_DISCONNECTED | 0 | 0 |

`L2CapFileRequestSetAudioConnected` (0x10008154) sets the stream status (slot 3) to STATUS_SUCCESS (connected) or 0xC00000A3 STATUS_DEVICE_NOT_READY (disconnected), and completes all the pending `IOCTL_BTHHFP_STREAM_OPEN` with this status. It's the answer of the service to an indication of type 1.

---

### IOCTL 0x411CDC / 0x411CE0 — IOCTL_BTH_WP8_CHANGE_SPEAKER_VOLUME / CHANGE_MICROPHONE_VOLUME

This IOCTL is processed by Bthl2cap.sys (audio device). It is sent by [BtConnectionManagerClient.dll](../libraries/btconnectionmanagerclient.md#sco-audio).

| Property | Value |
|----------|-------|
| Device | 0x41 (FILE_DEVICE_BLUETOOTH) |
| Function | 0x737 / 0x738 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x411CDC IOCTL_BTH_WP8_CHANGE_SPEAKER_VOLUME | ≥ 4 | 0 |
| 0x411CE0 IOCTL_BTH_WP8_CHANGE_MICROPHONE_VOLUME | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `0F 00 00 00` | HFP volume level 0…15 (set by the hands-free, `+VGS` / `+VGM`) |

`L2CapFileChangeVolume` (0x10006A70) → `L2CapFileUpdateStatus`: stores the level in slot 0 (speaker) or 1 (microphone). The audio driver reads it × 0x1111.

---

### IOCTL 0x411CE4 — IOCTL_BTH_WP8_GET_AUDIO_INDICATION

This IOCTL is processed by Bthl2cap.sys (audio device). It is sent by [BtConnectionManagerClient.dll](../libraries/btconnectionmanagerclient.md#sco-audio), which always keeps one pending.

| Property | Value |
|----------|-------|
| Device | 0x41 (FILE_DEVICE_BLUETOOTH) |
| Function | 0x739 (1849) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTH_WP8_GET_AUDIO_INDICATION | 0 | ≥ 12 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `03 00 00 00` | Indication type, see [Indications](#indications) |
| 04-07 | e.g. `0A 00 00 00` | Type 0: SCO link state (0 idle, 1 connecting, 2 connected, 3 disconnecting). Types 3 / 4: volume 0…15 |
| 08 | 00 or 01 | Type 0 only: "incoming" |
| 09-0B | ? | Not written |

`L2CapFileGetAudioIndication` (0x10006E10): if the SCO state differs from the last one reported, it returns a type 0 indication; else the first queued indication; else the request is parked in the queue of the audio object. 0xC0000184 STATUS_INVALID_DEVICE_STATE if the handle has no audio object. Always completed with 12 bytes.

---

### IOCTL 0x411CE8 — IOCTL_BTH_WP8_SET_CODEC_ID

This IOCTL is processed by Bthl2cap.sys (audio device). It is sent by [BtConnectionManagerClient.dll](../libraries/btconnectionmanagerclient.md#sco-audio).

| Property | Value |
|----------|-------|
| Device | 0x41 (FILE_DEVICE_BLUETOOTH) |
| Function | 0x73A (1850) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTH_WP8_SET_CODEC_ID | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `01 00 00 00` | HFP codec id (1 = CVSD, 2 = mSBC). Only the low byte is kept (audio object +0x80) |

`L2CapFileSetCodecId` (0x100079F0) stores the codec and completes all the pending [IOCTL 0x22003C](#ioctl-0x22003c--ioctl_bthhfp_device_get_codec_id) with it (`L2CapFileCompletePendingGetCodecIdRequests`). It's the answer of the service to an indication of type 5.

---

### IOCTL 0x220003…0x220033 — IOCTL_BTHHFP_*

These IOCTLs are processed by Bthl2cap.sys (audio device, opened through `GUID_DEVINTERFACE_BLUETOOTH_HFP_SCO_HCIBYPASS`). They are the Microsoft `bthhfpddi.h` interface ("HFP SCO HCI bypass"); the names come from the debug strings. Some of them are sent by [qc8x60aud.sys](./qc8x60aud.md#ioctl-0x0022000b0x0022002f--bluetooth-hfp).

| Property | Value |
|----------|-------|
| Device | 0x22 (FILE_DEVICE_UNKNOWN) |
| Function | 0…12 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x220003 IOCTL_BTHHFP_GET_DEVICEOBJECT | 0 | ≥ 4 |
| 0x220007 IOCTL_BTHHFP_DEVICE_GET_KSNODETYPES | 0 | ≥ 32 |
| 0x22000B IOCTL_BTHHFP_DEVICE_GET_CONTAINERID | 0 | ≥ 16 |
| 0x22000F IOCTL_BTHHFP_DEVICE_REQUEST_CONNECT | 0 | 0 |
| 0x220013 IOCTL_BTHHFP_DEVICE_REQUEST_DISCONNECT | 0 | 0 |
| 0x220017 IOCTL_BTHHFP_DEVICE_GET_CONNECTION_STATUS_UPDATE | ≥ 4 | ≥ 4 |
| 0x22001B IOCTL_BTHHFP_SPEAKER_SET_VOLUME | ≥ 4 | 0 |
| 0x22001F IOCTL_BTHHFP_SPEAKER_GET_VOLUME_STATUS_UPDATE | ≥ 4 | ≥ 4 |
| 0x220023 IOCTL_BTHHFP_MIC_SET_VOLUME | ≥ 4 | 0 |
| 0x220027 IOCTL_BTHHFP_MIC_GET_VOLUME_STATUS_UPDATE | ≥ 4 | ≥ 4 |
| 0x22002B IOCTL_BTHHFP_STREAM_OPEN | 0 | 0 |
| 0x22002F IOCTL_BTHHFP_STREAM_CLOSE | 0 | 0 |
| 0x220033 IOCTL_BTHHFP_STREAM_GET_STATUS_UPDATE | ≥ 4 | ≥ 4 |

All of them return 0xC0000184 STATUS_INVALID_DEVICE_STATE when no audio object exists on the device.

- 0x220003 (`L2CapFileGetDeviceObject`, 0x1000718C): returns the `PDEVICE_OBJECT` of the physical device (`WdfDeviceWdmGetPhysicalDevice`), 4 bytes. Kernel callers only.
- 0x220007 (`L2CapFileGetDeviceKsNodeTypes`, 0x10007358): bytes 00-0F = speaker node type, 10-1F = microphone node type (`L2CapFileHelperGetPinCategories`, 0x10007580). Headset: `KSNODETYPE_HEADPHONES` `{DFF21CE2-F70F-11D0-B917-00A0C9223196}` and `KSNODETYPE_PERSONAL_MICROPHONE` `{DFF21BE3-F70F-11D0-B917-00A0C9223196}`; otherwise `KSNODETYPE_COMMUNICATION_SPEAKER` `{DFF21CE6-F70F-11D0-B917-00A0C9223196}` and `KSNODETYPE_MICROPHONE` `{DFF21BE1-F70F-11D0-B917-00A0C9223196}`.
- 0x22000B (`L2CapFileGetDeviceContainerId`, 0x10006FC8): the 16-byte container id of the physical device (`IoGetDevicePropertyData` `DEVPKEY_Device_ContainerId`).
- 0x22000F / 0x220013: no-op, completed with STATUS_SUCCESS (the connection is driven by user mode).
- 0x220017 / 0x22001F / 0x220027 / 0x220033 (`L2CapFileRequestMonitor`, 0x10007D88): status slot 2 / 0 / 1 / 3. The input is a `BOOL` "immediate": if it's non-zero, or if the status has changed since the last one returned, the request is completed at once (4 bytes: the value × multiplier, `L2CapScoHelperCompleteUpdateNotification`); otherwise it stays pending until the next change.
- 0x22001B / 0x220023 (`L2CapFileRequestSet`, 0x10007F78): the input `LONG` (0…0xFFFF) is converted to a level (value + 2184) / 4369 = 0…15 and sent as an indication of type 3 / 4. The status slot isn't updated: the level comes back through `IOCTL_BTH_WP8_CHANGE_*_VOLUME`.
- 0x22002B (`L2CapFileRequestStreamOpen`, 0x1000822C): sends an indication of type 1, parks the request in the queue +0x14 of the device and starts a 500 ms one-shot timer (`WdfTimerCreate` / `WdfTimerStart`, due time -5 000 000). `IOCTL_BTH_WP8_SET_AUDIO_CONNECTED` / `DISCONNECTED` completes it with STATUS_SUCCESS / STATUS_DEVICE_NOT_READY. If nothing came after 500 ms, `L2CapFileTimerCompleteRequest` completes it with **STATUS_SUCCESS** anyway.
- 0x22002F (`L2CapFileRequestSet`): sends an indication of type 2 and returns at once.

---

### IOCTL 0x22003C — IOCTL_BTHHFP_DEVICE_GET_CODEC_ID

This IOCTL is processed by Bthl2cap.sys (audio device).

| Property | Value |
|----------|-------|
| Device | 0x22 (FILE_DEVICE_UNKNOWN) |
| Function | 0xF (15) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTHHFP_DEVICE_GET_CODEC_ID | ≥ 4 | ≥ 1 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version, must be 1, otherwise 0xC000000D STATUS_INVALID_PARAMETER |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | e.g. 02 | Codec id |

`L2CapRequestGetCodecId` (0x10007BA0) sends an indication of type 5 and parks the request in the queue +0x18 of the device, until [IOCTL 0x411CE8](#ioctl-0x411ce8--ioctl_bth_wp8_set_codec_id) completes it with 1 byte.

---

### IOCTL 0x220193 — IOCTL_BTHHFP_DEVICE_GET_DESCRIPTOR

This IOCTL is processed by Bthl2cap.sys (audio device).

| Property | Value |
|----------|-------|
| Device | 0x22 (FILE_DEVICE_UNKNOWN) |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTHHFP_DEVICE_GET_DESCRIPTOR | 0 | ≥ 64 |

Outputbuffer (`BTHHFP_DESCRIPTOR`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | | Input pin category: microphone node type (see 0x220007) |
| 10-1F | | Output pin category: speaker node type |
| 20-2F | | Container id |
| 30-33 | 01 00 00 00 | Supports volume (byte 8 of the INITIALIZE input) |
| 34-37 | 00 00 00 00 | Size of the volume property values |
| 38-3F | ? | Friendly name (`UNICODE_STRING`), not written |

`L2CapRequestGetDeviceDescriptor` (0x10007774). Completed with 64 bytes.

### IOCTL 0x220197 — IOCTL_BTHHFP_DEVICE_GET_VOLUMEPROPERTYVALUES

This IOCTL is processed by Bthl2cap.sys (audio device). Function 0x65, METHOD_NEITHER.  
Not implemented (`L2CapRequestGetVolumePropertyValues`, 0x10007954): always 0xC0000010 STATUS_INVALID_DEVICE_REQUEST.

---

## Protocol device

`L2CapDriverDeviceIsProtocol` (0x10005A84) checks that the enumerator name is `BTHENUM`, then sends [internal IOCTL 0x410007](#internal-ioctl-0x410007--ioctl_internal_bthenum_get_enuminfo) to the stack: the device is a protocol device if the enumerator type is 0 (protocol). The protocol GUID of the answer is kept in the device context.

Opening a handle requires one of the capabilities `ID_CAP_BLUETOOTH`, `ID_CAP_BLUETOOTH_ADMIN` or `ID_CAP_NETWORKING` (0xC0000022 STATUS_ACCESS_DENIED otherwise); 0xC0000056 STATUS_DELETE_PENDING after a surprise removal. One handle registers as the owner of the device (PSMs, listen); the other handles are attached to a channel and carry its data with `ReadFile` / `WriteFile` (`L2CapProtocolFileReadWrite`, 0x1000B2BC: BRB 0x105 `BRB_L2CA_ACL_TRANSFER`, at most 10 outstanding requests per handle).

BRBs submitted to the `BTHENUM` stack: 0x109 `BRB_REGISTER_PSM`, 0x10A `BRB_UNREGISTER_PSM`, 0x100 `BRB_L2CA_REGISTER_SERVER`, 0x101 `BRB_L2CA_UNREGISTER_SERVER`, 0x104 `BRB_L2CA_CLOSE_CHANNEL`, 0x105 `BRB_L2CA_ACL_TRANSFER`, 0x212 / 0x213 (open channel / open channel response, with the L2CAP configuration of the registration ?).

### IOCTL 0x411D00…0x411D14 — IOCTL_BTH_WP8_L2CAP_*

These IOCTLs are processed by Bthl2cap.sys (protocol device, `L2CapProtocolFileControl` 0x1000A6A4). They are sent by [BtConnectionManagerService.dll](../libraries/btconnectionmanagerservice.md) (`LocalService`, `Connection`). The names come from that DLL.

| Property | Value |
|----------|-------|
| Device | 0x41 (FILE_DEVICE_BLUETOOTH) |
| Function | 0x740…0x745 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x411D00 IOCTL_BTH_WP8_L2CAP_REGISTER | ≥ 152 | 0 |
| 0x411D04 IOCTL_BTH_WP8_L2CAP_UNREGISTER | 0 | 0 |
| 0x411D08 IOCTL_BTH_WP8_L2CAP_LISTEN | ≥ 16 | ≥ 48 |
| 0x411D0C IOCTL_BTH_WP8_L2CAP_CONNECT | ≥ 48 | 0 |
| 0x411D10 IOCTL_BTH_WP8_L2CAP_ATTACH | ≥ 48 | ≥ 8 |
| 0x411D14 IOCTL_BTH_WP8_L2CAP_DISPOSE | ≥ 48 | 0 |

Inputbuffer of REGISTER:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | e.g. `17 00` | PSM |
| 02-03 | e.g. `1B 00` | PSM2 (second PSM), 0 if none ? |
| 04 | 01 | Listen (register an L2CAP server) |
| 08-4F | | L2CAP configuration of the PSM (0x48 bytes) |
| 50-97 | | L2CAP configuration of PSM2 (0x48 bytes) |

Channel descriptor (48 bytes; output of LISTEN, input of CONNECT, ATTACH and DISPOSE):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | | Bluetooth address of the remote device |
| 08-17 | ? | ? |
| 18-19 | | PSM |
| 1A-1B | ? | ? |
| 1C-2B | | The 16 bytes of the LISTEN input (cookie ?) |
| 2C-2F | ? | ? |

- REGISTER (`L2CapProtocolFileRegister`, 0x1000A77C → `L2CapProtocolDeviceRegisterOwner`, 0x10009EB0): makes the handle the owner of the device and registers the PSM(s) and the server. 0xC0000038 STATUS_DEVICE_ALREADY_ATTACHED if another handle owns the device, 0xC0000056 after a surprise removal.
- UNREGISTER, LISTEN, CONNECT, DISPOSE: 0xC00000A3 STATUS_DEVICE_NOT_READY if the handle doesn't own the device.
- LISTEN (`L2CapProtocolDeviceListen`): the request stays pending until an incoming channel arrives, then is completed with its 48-byte descriptor; the channel is kept in the list of unattached channels.
- CONNECT (`L2CapProtocolChannelConnect`, 0x10008A7C): opens an outgoing channel to the address and PSM of the descriptor; the request is completed when the open BRB completes, and the channel waits for an ATTACH.
- ATTACH (`L2CapProtocolFileAttach`, 0x1000AE2C): on a handle that isn't the owner, takes the unattached channel whose descriptor is identical (`memcmp` of the 48 bytes) and binds it to the handle. Output: 2 dwords of the channel (+0x48, +0x4C: outgoing / incoming MTU ?). 0xC0000038 if the handle is already attached, 0xC0000225 STATUS_NOT_FOUND if no channel matches.
- DISPOSE (`L2CapProtocolFileDispose`, 0x1000B12C): closes the unattached channel matching the descriptor (no error if none).

---

### internal IOCTL 0x410007 — IOCTL_INTERNAL_BTHENUM_GET_ENUMINFO

This IOCTL is sent by Bthl2cap.sys to the `BTHENUM` stack (BthEnum.sys, Microsoft), in `L2CapDriverDeviceIsProtocol`, with `IoBuildDeviceIoControlRequest` (internal) to the top of the attached device stack.

| Property | Value |
|----------|-------|
| Device | 0x41 (FILE_DEVICE_BLUETOOTH) |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_BTHENUM_GET_ENUMINFO | `BTHENUM` PDO | 0 | 1840 (`BTH_ENUMERATOR_INFO`) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Enumerator type: 0 = protocol (device kept), 1 = service |
| 10-1F | | Protocol / service GUID, kept in the device context +4 |

0xC0000010 STATUS_INVALID_DEVICE_REQUEST from the stack means "not a protocol device"; any other error is fatal.

---

### Interface GUID

Audio device interface, created on the `BthMini` device (target of the `IOCTL_BTH_WP8_*` audio IOCTLs)  
`GUID_BTHWP8_AUDIO_DEVICE_INTERFACE` `{5E1429D2-01B6-458D-8687-3F976014F4BB}`

HFP SCO interface for the audio driver, created on the same device by `IOCTL_BTH_WP8_INITIALIZE_AUDIO_DEVICE`, disabled when the handle is closed  
`GUID_DEVINTERFACE_BLUETOOTH_HFP_SCO_HCIBYPASS` `{BE446647-F655-4919-8BD0-125BA5D4CE65}`

### Other GUID

Bluetooth profile driver interface, queried on `BTH\MS_BTHBRB`  
`GUID_BTHDDI_PROFILE_DRIVER_INTERFACE` `{94A59AA8-4383-4286-AA4F-34A160F40004}`

Container id property  
`DEVPKEY_Device_ContainerId` `{8C7ED206-3F8A-4827-B3AB-AE9E1FAEFC6C}`
