## Qcgnss.sys

Qualcomm GNSS (GPS) driver.  
It doesn't touch any hardware and doesn't talk to any other driver: it's a **message broker** between two kinds of user-mode clients that open the same device.  
- The **location clients** (the Windows Phone location framework) send the GNSS IOCTLs (start/stop a fix session, inject assistance data, SUPL configuration, geofences…).  
- A **GNSS engine service** (Qualcomm user-mode process, name ?) registers itself with `IOCTL 0x220804`, then loops on `IOCTL 0x220808` to fetch the requests of the clients, and answers them with `IOCTL 0x220804`. The engine talks to the GPS of the modem by other means (probably QMI over [qcsmd8930.sys](./qcsmd8930.md)).

Each client request is copied into a message (header + the client's input buffer) and put in a queue for the engine. The client's WDF request is parked in a manual queue until the engine posts a response with the same IOCTL code and the same client file object.  
The driver was built from `ngp_drv` sources ("Next Generation Positioning" ?), PDB `E:\build_e\subtask\9BE4833D_98\output\gnss\fre\qcgnss.pdb`. Version string `2.1 (3058.51000.4130.98)`, build date `Jan 28 2015`. Pool tag `NGPD`.

Symbolic link : `\DosDevices\GnssDriver`  
There's no named `\Device\` object (the WDF device is unnamed; only the symbolic link and the device interface are created).

The ACPI node is `\_SB.SMD0.GPS` (`_HID` `QCOM_GPS`, `_CID` `ACPIQCOM_GPS`, `_UID` 0), a child of the node of [qcsmd8930.sys](./qcsmd8930.md). It has no `_CRS`, and the driver doesn't evaluate any ACPI method.

There's no parameters in the registry.

GUID of the ETW provider (WPP control GUID):  
`{E91083E9-CC8F-400C-B046-E0B090AB21E2}`

It communicates with the following devices:  
None. The driver doesn't open any other device. Its only peers are the user-mode processes that open `\\.\GnssDriver`.

The IOCTL codes, the buffer sizes and the content of `IOCTL 0x220008` match the GNSS driver interface published later for Windows 10 (`gnssdriver.h`, [GNSS driver IOCTLs](https://learn.microsoft.com/en-us/windows-hardware/drivers/gnss/gnss-driver-ioctls)). The `IOCTL_GNSS_*` names below come from that match: they're inferred from the sizes and behaviour, and they're marked with "?".

### Internal design

Device context (`DEVICE_CONTEXT`):  
| Offset | Comment |
|--------|---------|
| +0x00 | WDFDEVICE |
| +0x04 | Default queue (parallel), `EvtWdfIoQueueIoDeviceControl` and `EvtWdfIoQueueIoStop` |
| +0x08 | Manual queue holding the pending client requests and the pending `0x220808` requests of the engine |
| +0x0C | KEVENT (synchronization) that wakes up the worker thread |
| +0x1C | LIST_ENTRY: messages waiting for the engine |
| +0x24 | Wait-lock of the list +0x1C |
| +0x28 | Wait-lock of the list +0x2C |
| +0x2C | Singly linked list of the open file objects (one per client handle) |
| +0x30 | LIST_ENTRY: buffered geofence alerts (`0x220148`) not yet read by a client |
| +0x38 | Wait-lock of the list +0x30 |
| +0x3C | Pending `IOCTL 0x22000C` request with `CommandType` = 16 |
| +0x40 | 1 when an engine is registered |
| +0x44 | File object of the engine |
| +0x48 | The single pending `IOCTL 0x220140` request |

A system thread (`sub_40445C`, created by `PsCreateSystemThread` in `EvtDriverDeviceAdd`) waits on the event +0x0C. When it wakes up and the message list isn't empty, it takes a pending `IOCTL 0x220808` request from the manual queue, removes the first message from the list, copies it to the request's output buffer, and completes the request with `STATUS_SUCCESS`. If the output buffer is too small, the request fails and the message is lost. The thread never exits.

Open and close:  
- `EvtWdfDeviceFileCreate` adds the file object to the list +0x2C and queues a message `0x4010` (16 bytes, client file object at +0x0C) for the engine.  
- `EvtWdfFileClose` removes the file object from the list. If it's the engine's file object, it clears +0x40/+0x44, purges the manual queue (cancels all the pending client requests), drops all the messages not yet delivered, and restarts the queue. Otherwise it queues a message `0x4011` (16 bytes, client file object at +0x0C).

### Messages exchanged with the engine

Header of a message sent to the engine (type `0x4013`, built from a client IOCTL):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 13 40 | Message type 0x4013 |
| 02-03 | ? | Total size of the message = input size + 24 |
| 04-0B | 00 … | ? (always 0) |
| 0C-0F | e.g. 40 00 22 00 | IOCTL code of the client request |
| 10-13 | ? | WDFFILEOBJECT of the client (used as the client id) |
| 14-15 | ? | Size of the payload |
| 16-17 | ? | Only for `IOCTL 0x220080`: number of fragments still to come |
| 18-… | ? | Payload = copy of the client's input buffer |

Other messages sent to the engine:  
| Type | Size | Comment |
|------|------|---------|
| 0x4008 | 72 | Driver version, answer to a message `0x4000` containing an element `0x1A0` (see below) |
| 0x4010 | 16 | A client opened the device. +0x0C = client file object |
| 0x4011 | 16 | A client closed the device. +0x0C = client file object |
| 0x4013 | 24 + n | Client request (see above) |

Messages sent by the engine (input buffer of `IOCTL 0x220804`), processed by `sub_40358C`:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 14 40 | Message type: 0x4014 = response, 0x4015 = event, 0x4000 = control message |
| 02-03 | ? | Total size of the message. Must be equal to the InputBufferLength of the IOCTL |
| 04-0B | ? | ? (not read) |
| 0C-0F | e.g. 4C 00 22 00 | IOCTL code of the client request to complete |
| 10-13 | ? | WDFFILEOBJECT of the client. 0 = any client |
| 14-17 | 00 00 00 00 | NTSTATUS used to complete the client request |
| 18-19 | ? | Size of the output data |
| 1A-1B | ? | ? |
| 1C-… | ? | Output data, copied to the output buffer of the client request |

- `0x4014`: if the client file object isn't 0 and isn't open anymore, the message is dropped. Otherwise the driver looks in the manual queue for a request with this IOCTL code (and this file object, when it isn't 0), and completes it. A response to `0x220140` completes the request stored at +0x48 instead. If the completed request is the one stored at +0x3C (`IOCTL 0x22000C` with `CommandType` 16), the buffered geofence alerts are deleted.  
- `0x4015`: same as `0x4014`, except for IOCTL code `0x220148` with file object 0: when no client is waiting, the message is copied into the list +0x30, and the next `IOCTL 0x220148` gets it immediately.  
- `0x4000`: +0x0C (1 byte) = number of elements, elements start at +0x10. Each element starts with a WORD type and a WORD size (including these 4 bytes). The only element type handled is `0x1A0` (version handshake: build date at element+0x0C, version string at element+0x18, both only traced). The driver answers with a message `0x4008`.  
- Other types are ignored.

Content of the message `0x4008` (from `sub_403E14`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 08 40 | Message type 0x4008 |
| 02-03 | 48 00 | Size 72 |
| 04-0E | 00 … | |
| 0F | 01 | Number of elements ? |
| 10-11 | A0 01 | Element type 0x1A0 |
| 12-13 | 38 00 | Element size 56 |
| 14-15 | 02 00 | ? |
| 16-17 | 00 00 | |
| 18-19 | 02 00 | ? (same value as +0x44 of `IOCTL 0x22080C`) |
| 1A-1B | 04 00 | ? (same value as +0x48 of `IOCTL 0x22080C`) |
| 1C-27 | `Jan 28 2015` | Build date, ASCII, 12 bytes |
| 28-47 | `2.1 (3058.51000.4130.98)` | Version, ASCII, 32 bytes |

### Common behaviour of the client IOCTLs

The "fixed size" IOCTLs (`sub_4021DC`) read the first DWORD of the input buffer (`Size`). It must be ≤ InputBufferLength and equal to the expected size, otherwise the request fails with `STATUS_INVALID_PARAMETER` (0xC000000D). The input buffer is copied into a message `0x4013`, the request is parked in the manual queue, and the message is queued for the engine.  
The "listen" IOCTLs (`sub_402754`) are only parked in the manual queue: no message is sent to the engine and the input buffer is ignored. They complete when the engine posts a response or an event with the same IOCTL code.  
The output buffer must be at least as big as the output data sent by the engine, otherwise the request fails with `STATUS_BUFFER_TOO_SMALL`.  
Other errors: `STATUS_INSUFFICIENT_RESOURCES` (0xC0000017) when an allocation fails, and `STATUS_BUFFER_OVERFLOW` (0x80000005) for a bad buffer in the variable size IOCTLs.  
Unknown IOCTL codes fail with `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

Summary:  
| IOCTL | Name | Handling | InputBuffer size |
|-------|------|----------|------------------|
| 0x220004 | IOCTL_GNSS_SEND_PLATFORM_CAPABILITY ? | to engine | 532 |
| 0x220008 | IOCTL_GNSS_GET_DEVICE_CAPABILITY ? | answered by the driver | 0 |
| 0x22000C | IOCTL_GNSS_SEND_DRIVERCOMMAND ? | to engine | ≥ 532 |
| 0x220040 | IOCTL_GNSS_START_FIXSESSION ? | to engine | 588 |
| 0x220044 | IOCTL_GNSS_MODIFY_FIXSESSION ? | to engine | 588 |
| 0x220048 | IOCTL_GNSS_STOP_FIXSESSION ? | to engine | 524 |
| 0x22004C | IOCTL_GNSS_GET_FIXDATA ? | listen | - |
| 0x220080 | IOCTL_GNSS_INJECT_AGNSS ? | to engine, in fragments | ≥ 536 |
| 0x2200C0 | IOCTL_GNSS_LISTEN_AGNSS ? | listen | - |
| 0x220100 | IOCTL_GNSS_LISTEN_NI ? | listen | - |
| 0x220104 | IOCTL_GNSS_SET_SUPL_HSLP ? | to engine | 1044 |
| 0x220108 | IOCTL_GNSS_CONFIG_SUPL_CERT ? | to engine | ≥ 792 |
| 0x22010C | IOCTL_GNSS_RESPOND_NI ? | to engine | 16 |
| 0x220120 | IOCTL_GNSS_SET_V2UPL_CONFIG ? | to engine | 1044 |
| 0x220140 | IOCTL_GNSS_CREATE_GEOFENCE ? | to engine, one at a time | 1056 |
| 0x220144 | IOCTL_GNSS_DELETE_GEOFENCE ? | to engine | 524 |
| 0x220148 | IOCTL_GNSS_LISTEN_GEOFENCE_ALERT ? | listen, buffered | - |
| 0x22014C | IOCTL_GNSS_LISTEN_GEOFENCES_TRACKINGSTATUS ? | listen | - |
| 0x220510 | ? | listen | - |
| 0x220514 | ? | no-op | - |
| 0x220804 | (engine) post a message | answered by the driver | ≥ 12 |
| 0x220808 | (engine) get the next message | waits for a message | - |
| 0x22080C | get driver/engine version | to engine, or answered by the driver | - |

---

### IOCTL 0x220004 — IOCTL_GNSS_SEND_PLATFORM_CAPABILITY ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_SEND_PLATFORM_CAPABILITY ? | 532 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 14 02 00 00 | Size, must be 532 |
| 04-213 | ? | Forwarded to the engine |

Fixed size IOCTL, forwarded to the engine.

---

### IOCTL 0x220008 — IOCTL_GNSS_GET_DEVICE_CAPABILITY ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x2 (2) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_GET_DEVICE_CAPABILITY ? | 0 | 604 |

Answered by the driver itself (`sub_40306C`), the engine isn't involved. The whole output buffer is filled with `FF`, then the first 24 DWORDs are written. The names in the comments are the fields of `GNSS_DEVICE_CAPABILITY` in `gnssdriver.h`.  
Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 5C 02 00 00 | Size = 604 |
| 04-07 | 02 00 00 00 | Version ? |
| 08-0B | 00 00 00 00 | SupportMultipleFixSessions ? |
| 0C-0F | 00 00 00 00 | SupportMultipleAppSessions ? |
| 10-13 | 01 00 00 00 | RequireAGnssInjection ? |
| 14-17 | 03 00 00 00 | AgnssFormatSupported ? (XTRA1 \| XTRA2 ?) |
| 18-1B | 02 00 00 00 | AgnssFormatPreferred ? (XTRA2 ?) |
| 1C-1F | 00 00 00 00 | SupportDistanceTracking ? |
| 20-23 | 00 00 00 00 | SupportContinuousTracking ? |
| 24-27 | 01 00 00 00 | ? |
| 28-37 | 00 … | ? |
| 38-3B | 00 00 00 00 | GeofencingSupport ? |
| 3C-43 | 00 … | ? |
| 44-47 | 01 00 00 00 | SupportCpLocation ? |
| 48-4B | 01 00 00 00 | SupportUplV2 ? |
| 4C-4F | 01 00 00 00 | SupportSuplV1 ? |
| 50-53 | 01 00 00 00 | SupportSuplV2 ? |
| 54-57 | 01 00 00 00 | SupportedSuplVersion.MajorVersion ? |
| 58-5B | 00 00 00 00 | SupportedSuplVersion.MinorVersion ? |
| 5C-5F | 00 00 00 00 | MaxGeofencesSupported ? |
| 60-25B | FF … | Unused |

The geofence IOCTLs exist (`0x220140`–`0x22014C`) even though GeofencingSupport is 0 here (if the name is right).

---

### IOCTL 0x22000C — IOCTL_GNSS_SEND_DRIVERCOMMAND ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x3 (3) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_SEND_DRIVERCOMMAND ? | ≥ 532 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size of the data to forward |
| 04-07 | ? | Version ? |
| 08-0B | e.g. 10 00 00 00 | CommandType ? |
| 0C-0F | ? | ? |
| 10-13 | ? | CommandDataSize ? |
| 14-213 | ? | Unused ? |
| 214-… | ? | CommandData ? |

Handler `sub_402814`. The InputBufferLength must be ≥ `Size`, ≥ 532, and ≥ the DWORD at +0x10 + 532, otherwise `STATUS_BUFFER_OVERFLOW`. `Size` bytes are forwarded to the engine.  
When `CommandType` is 16 (`GNSS_ResetGeofencesTracking` ?), the request is also stored in the device context: when the engine completes it, the buffered geofence alerts are deleted.

---

### IOCTL 0x220040 — IOCTL_GNSS_START_FIXSESSION ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x10 (16) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_START_FIXSESSION ? | 588 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 4C 02 00 00 | Size, must be 588 |
| 04-24B | ? | Forwarded to the engine |

Fixed size IOCTL, forwarded to the engine.

---

### IOCTL 0x220044 — IOCTL_GNSS_MODIFY_FIXSESSION ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x11 (17) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_MODIFY_FIXSESSION ? | 588 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 4C 02 00 00 | Size, must be 588 |
| 04-24B | ? | Forwarded to the engine |

Fixed size IOCTL, forwarded to the engine.

---

### IOCTL 0x220048 — IOCTL_GNSS_STOP_FIXSESSION ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x12 (18) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_STOP_FIXSESSION ? | 524 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 0C 02 00 00 | Size, must be 524 |
| 04-20B | ? | Forwarded to the engine |

Fixed size IOCTL, forwarded to the engine.

---

### IOCTL 0x22004C — IOCTL_GNSS_GET_FIXDATA ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x13 (19) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_GET_FIXDATA ? | ignored | defined by the engine |

Listen IOCTL: parked until the engine posts the position fix.

---

### IOCTL 0x220080 — IOCTL_GNSS_INJECT_AGNSS ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x20 (32) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_INJECT_AGNSS ? | ≥ 536 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size of the data to forward |
| 04-0F | ? | ? |
| 10-13 | ? | Size of the assistance data ? |
| 14-… | ? | Assistance data (e.g. XTRA file) ? |

Handler `sub_402B0C`. The InputBufferLength must be ≥ 536 and ≥ the DWORD at +0x10 + 536, otherwise `STATUS_BUFFER_OVERFLOW`.  
The `Size` bytes are split into `Size / 10240 + 1` messages `0x4013` of at most 10240 bytes of payload (allocated with 10264 bytes). In each message, +0x14 is the size of the fragment and +0x16 the number of fragments still to come (0 for the last one). The client request is parked only with the last fragment, and is completed by the response of the engine.

---

### IOCTL 0x2200C0 — IOCTL_GNSS_LISTEN_AGNSS ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x30 (48) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_LISTEN_AGNSS ? | ignored | defined by the engine |

Listen IOCTL: parked until the engine asks for assistance data.

---

### IOCTL 0x220100 — IOCTL_GNSS_LISTEN_NI ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x40 (64) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_LISTEN_NI ? | ignored | defined by the engine |

Listen IOCTL: parked until the engine posts a network-initiated (SUPL/control plane) location request ?

---

### IOCTL 0x220104 — IOCTL_GNSS_SET_SUPL_HSLP ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x41 (65) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_SET_SUPL_HSLP ? | 1044 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 14 04 00 00 | Size, must be 1044 |
| 04-413 | ? | Forwarded to the engine (SUPL server address ?) |

Fixed size IOCTL, forwarded to the engine.

---

### IOCTL 0x220108 — IOCTL_GNSS_CONFIG_SUPL_CERT ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x42 (66) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_CONFIG_SUPL_CERT ? | ≥ 792 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size of the data to forward |
| 04-… | ? | Forwarded to the engine (certificate name and data ?) |

Handler `sub_4024DC`. The InputBufferLength must be ≥ `Size` and ≥ 792, otherwise `STATUS_BUFFER_OVERFLOW`. Unlike the other variable size IOCTLs, the whole input buffer (InputBufferLength bytes, not `Size`) is forwarded to the engine.

---

### IOCTL 0x22010C — IOCTL_GNSS_RESPOND_NI ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x43 (67) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_RESPOND_NI ? | 16 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 10 00 00 00 | Size, must be 16 |
| 04-07 | ? | Version ? |
| 08-0B | ? | Request id ? |
| 0C-0F | ? | User response ? |

Fixed size IOCTL, forwarded to the engine.

---

### IOCTL 0x220120 — IOCTL_GNSS_SET_V2UPL_CONFIG ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x48 (72) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_SET_V2UPL_CONFIG ? | 1044 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 14 04 00 00 | Size, must be 1044 |
| 04-413 | ? | Forwarded to the engine |

Fixed size IOCTL, forwarded to the engine.

---

### IOCTL 0x220140 — IOCTL_GNSS_CREATE_GEOFENCE ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x50 (80) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_CREATE_GEOFENCE ? | 1056 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 20 04 00 00 | Size, must be 1056 |
| 04-41F | ? | Forwarded to the engine |

Fixed size IOCTL, forwarded to the engine, with a difference: the request isn't parked in the manual queue but stored in the device context (+0x48), so only one can be pending at a time. A second request fails with `STATUS_DEVICE_BUSY` (0x80000011). The response of the engine completes the stored request whatever the client file object of the response.

> [!NOTE]
> The stored request isn't in a queue, so it can't be cancelled, and it isn't released when the client or the engine closes its handle: if the engine never answers, the request stays pending and `IOCTL 0x220140` fails with `STATUS_DEVICE_BUSY` for every client.

---

### IOCTL 0x220144 — IOCTL_GNSS_DELETE_GEOFENCE ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x51 (81) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_DELETE_GEOFENCE ? | 524 | defined by the engine |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 0C 02 00 00 | Size, must be 524 |
| 04-07 | ? | Version ? |
| 08-0B | ? | Geofence id ? |
| 0C-20B | ? | Unused ? |

Fixed size IOCTL, forwarded to the engine.

---

### IOCTL 0x220148 — IOCTL_GNSS_LISTEN_GEOFENCE_ALERT ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x52 (82) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_LISTEN_GEOFENCE_ALERT ? | ignored | defined by the engine |

Handler `sub_402E64`. Listen IOCTL, except that the alerts posted by the engine (message `0x4015` with file object 0) while no client is listening are kept in a list. If the list isn't empty, the request is completed immediately with the oldest alert (status +0x14, output data +0x1C of the buffered message). Otherwise it's parked.  
The list is deleted when the engine completes an `IOCTL 0x22000C` with `CommandType` 16.

---

### IOCTL 0x22014C — IOCTL_GNSS_LISTEN_GEOFENCES_TRACKINGSTATUS ?

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x53 (83) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_GNSS_LISTEN_GEOFENCES_TRACKINGSTATUS ? | ignored | defined by the engine |

Listen IOCTL.

---

### IOCTL 0x220510

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x144 (324) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ignored | defined by the engine |

Listen IOCTL (parked until the engine posts a message with this code). Purpose unknown.

---

### IOCTL 0x220514

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x145 (325) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ignored | 0 |

No-op: completed immediately with `STATUS_SUCCESS` and 0 bytes. It's probably meant to be paired with `IOCTL 0x220510`, but it doesn't cancel or complete the pending `0x220510` requests.

---

### IOCTL 0x220804 — engine: post a message

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x201 (513) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 12 | 0 |

Inputbuffer: a message `0x4014`, `0x4015` or `0x4000`, see [Messages exchanged with the engine](#messages-exchanged-with-the-engine).

Handler `sub_4031BC`. The WORD at +0x02 must be equal to InputBufferLength, otherwise `STATUS_BUFFER_OVERFLOW`. The file object of the caller becomes the engine's file object (+0x44), and the first call sets the "engine registered" flag (+0x40). Then the message is processed by `sub_40358C`, and the IOCTL completes with the result (`STATUS_SUCCESS` in most cases, even when the message was dropped).  
There's no check on who sends it: any process that can open `\\.\GnssDriver` can take the role of the engine and complete the requests of the other clients.

---

### IOCTL 0x220808 — engine: get the next message

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x202 (514) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ignored | ≥ size of the next message (up to 10264 for `IOCTL 0x220080`) |

Outputbuffer: a message `0x4008`, `0x4010`, `0x4011` or `0x4013`, see [Messages exchanged with the engine](#messages-exchanged-with-the-engine).

Handler `sub_40332C`. The request is parked in the manual queue and the worker thread is woken up. The thread completes it with the oldest message waiting for the engine (`BytesReturned` = size of the message). The messages queued before the engine started are kept and delivered later.

---

### IOCTL 0x22080C — get the version

This IOCTL is processed by Qcgnss.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x203 (515) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ignored | 448 |

Handler `sub_4033C0`. When an engine is registered, the request is forwarded to the engine as a message `0x4013` without payload, and the engine's response completes it. Otherwise the driver answers by itself.  
Outputbuffer (answer of the driver):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | C0 01 00 00 | Size = 448 |
| 04-07 | 01 00 00 00 | Version ? |
| 08-43 | 00 … | |
| 44-47 | 02 00 00 00 | ? |
| 48-4B | 04 00 00 00 | ? |
| 4C-57 | `Jan 28 2015` | Build date, ASCII |
| 58-77 | `2.1 (3058.51000.4130.98)` | Driver version, ASCII |
| 78-1BF | 00 … | |

---

### Interface GUID

Qcgnss Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{BE318A30-66BD-46C7-BBE8-736164D78DE7}`
