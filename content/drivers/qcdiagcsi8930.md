## Qcdiagcsi8930.sys

Qualcomm DIAG Consumer Interface (DCI) driver.  
It lets clients on the application processor (drivers or applications) use the DIAG services of the modem without the host tool (QPST/QXDM): send DIAG commands, and receive log packets and events filtered by their own masks. The modem side is the SMD channel `DIAG_2`, which is separate from the `DIAG` channel used by [qcdiagrouter8930.sys](./qcdiagrouter8930.md) for the host. Masks are not sent on `DIAG_2`: they are pushed to the modem through the router (DIAG_CNTL stream id 2). Commands registered by a local DIAG client of the router are delivered to that client through the router.  
The PDB path is `P:\Diag\rel\8.3\arm\Release\qcdiagcsi8930.pdb`. The device context type is named `DIAGCI_DEVICE_CONTEXT` (sic); the other context types are `DIAGCSI_*`.

ACPI node on the Lumia 520 (DSDT): `\_SB.QDCI` (`_HID` `QCOM0F81`, nothing else) ? The DCI name suggests it; the router is then `\_SB.QDIG` (`QCOM0F80`).

Device name : `\Device\DiagCSI`  
Symbolic link : `\DosDevices\DiagCSI`  
I/O type : direct (`WdfDeviceIoDirect`)  

There's no parameters in the registry.

Interface Class GUID:  
`{23ccade6-34e8-42e4-8845-99411146dc22}`  
The interface is created disabled and enabled only once `\Device\DiagRouter` is open (see [Startup](#startup)).

GUID of the ETW provider (WPP control GUID):  
`{5ab48ed9-aafe-40a2-84cf-dbd60690e80d}`

It communicates with the following devices:  
| Device | Driver | Interface GUID | Comment |
|--------|--------|----------------|---------|
| `\Device\DiagRouter` | [qcdiagrouter8930.sys](./qcdiagrouter8930.md) | `{5ff73d59-fab7-456e-884e-d5386cd5f581}` | DIAG router. Command ownership, delivery to local DIAG clients, DCI log/event masks |
| `\Device\SMD` | [qcsmd8930.sys](./qcsmd8930.md) | `{f9d15453-8335-434c-aa72-fcd925f135f3}` | Shared Memory Driver. Channel `DIAG_2`, SMD edge 0 (APPS↔MODEM) |

### Startup

`EvtDriverDeviceAdd` (0x40B418):
1. Creates `\Device\DiagCSI` with the file callbacks `EvtDeviceFileCreate` (`sub_40116C`) / `EvtFileClose` (`sub_40124C`), the `EvtIoInCallerContext` callback `sub_4014B0` (references the event handle of [IOCTL 0x80092440](#ioctl-0x80092440) in the caller's process) and `EvtDeviceD0Exit` (`sub_40BD50`).
2. Creates the device interface `{23ccade6-…}` (disabled) and the symbolic link.
3. Creates 3 work items in the device context and 2 collections (registered clients, mask clients).
4. Creates 4 queues: IOCTL (`sub_401720`, parallel), internal IOCTL (`sub_401E38`, parallel), read (`sub_40166C`, parallel) and a manual queue holding the pending reads (device context `+0x100`).
5. Enqueues work item 1 and starts a system thread `sub_404260`.

Router side (work items):
1. `sub_4026A0`: registers a PnP notification on the router interface `{5ff73d59-…}`. On the first arrival (`sub_40BE18`), work item 2 is enqueued.
2. `sub_40274C`: opens `\Device\DiagRouter` as I/O target (device context `+0xC`), enables the `{23ccade6-…}` interface, enqueues work item 3.
3. `sub_40292C`: sends [internal IOCTL 0x80082458](#internal-ioctl-0x80082458) to the router. When it completes with success (`sub_403FB8`), the flag "router connected" (device context `+0xFC`) is set. The router then opens `\Device\DiagCSI` as I/O target.

SMD side (thread `sub_404260`):
1. Registers a PnP notification on the SMD interface `{f9d15453-…}` and waits for its arrival.
2. Opens `\Device\SMD` and the channel `DIAG_2` with 3 internal IOCTLs (see [IOCTLs sent to qcsmd8930.sys](#ioctls-sent-to-qcsmd8930sys)).
3. Starts the system thread `sub_40BEDC`, which keeps 5 read requests of 16384 bytes (pool tag `qid1`) pending on `DIAG_2` and waits on 5 objects:

| Index | Object | Action |
|-------|--------|--------|
| 0 | stop event | Exits the thread and closes the channel |
| 1 | read completed | Parses the received buffer (`sub_404EA0`, see [DIAG_2 stream](#diag_2-stream)) and re-sends the read |
| 2 | SMD "channel open" event | Channel state = open. Sets the event of the clients that asked for notification type 1. Re-pushes the merged masks to the router (`sub_403BF0`) |
| 3 | SMD "channel closed" event | Channel state = closed. Sets the event of the clients that asked for notification type 2. Cancels the synchronous commands waiting for the modem |
| 4 | 500 ms timer | Timeout of [IOCTL 0x80092444](#ioctl-0x80092444): the synchronous commands waiting for the modem are completed with `STATUS_CANCELLED` |

`EvtDeviceD0Exit` to `WdfPowerDeviceD3Final` cancels every pending command and the timer.

### Client usage

1. Open `\\.\DiagCSI` (or `\Device\DiagCSI`).
2. [IOCTL 0x80092440](#ioctl-0x80092440): register the client (optionally with an event). Needed for commands and reads.
3. Commands: [IOCTL 0x80092444](#ioctl-0x80092444) (answer in the output buffer) or [IOCTL 0x8009244C](#ioctl-0x8009244c) (answer returned by `ReadFile`).
4. Logs and events: [IOCTL 0x80092450](#ioctl-0x80092450) once, then set log codes ([0x80092454](#ioctl-0x80092454)) and event ids ([0x80092460](#ioctl-0x80092460)).
5. `ReadFile` with a buffer of at least 6176 bytes (0x1820, otherwise `STATUS_INVALID_PARAMETER`). The read is pended in the manual queue and completed with one or more DCI frames (see [DIAG_2 stream](#diag_2-stream)).

Closing the handle removes the client, its pending commands and its masks (the merged masks are pushed again to the router).

### Commands

Each command gets a transaction id (32-bit counter, device context `+0x28`, starting at 1, 0 skipped). The pending commands are kept in a list (pool tag `qidD`, 32 bytes per entry: id, client tag, mode, request or file object, file object, owner bits).  
The work item `sub_401FB8` extracts the command code, the subsystem id and the subsystem command code of the request (same rules as the router: `0x4B`/`0x80` use bytes 1-3; `0x93` uses bytes 8-11) and asks the router who handles it with [internal IOCTL 0x80082450](#internal-ioctl-0x80082450). Then:

| Owner bits | Action |
|------------|--------|
| 0 | Nobody: answered locally with `13 <request>` (DIAG "bad command") |
| bit 0 | Local DIAG client of the router: sent to the router with [internal IOCTL 0x80082454](#internal-ioctl-0x80082454). The client answers with a buffer starting with `0x93`, which comes back as [internal IOCTL 0x80092491](#internal-ioctl-0x80092491) |
| bit 1 | Modem: written to `DIAG_2` as `7E 01 <len> 93 <id> <request> 7E`. The answer comes back as a `0x93` frame on `DIAG_2` |

Frame written to `DIAG_2` (request of N bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 7E | Start |
| 01 | 01 | Version |
| 02-03 | ? | Length = N + 5 |
| 04 | 93 | DCI command |
| 05-08 | ? | Transaction id |
| 09-(N+8) | ? | DIAG request |
| N+9 | 7E | End |

Buffer sent to the router for a local client (request of N bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 93 | DCI command |
| 01-03 | ? | Not initialized |
| 04-07 | ? | Transaction id |
| 08-(N+7) | ? | DIAG request |

The writes use 2 buffers of 4096 bytes per client (pool tags `qid2` and `qid3`).

### DIAG_2 stream

The modem sends frames `7E 01 <len:2> <payload: len bytes> 7E` (len + 5 bytes per frame). The first payload byte selects the type:  
| Byte 4 | Type | Processing |
|--------|------|------------|
| `0x10` | Log packet | Log code at offset 10. The frame is copied unchanged to each client whose log mask has this code (equipment = code >> 12, item = code & 0xFFF) |
| `0x60` | Event report | Number of bytes of events at offset 5, events from offset 7 (Qualcomm event format: 12-bit id, 2-bit payload length, truncated time flag, `sub_4064C8`). Each event enabled in a client's event mask is sent as a separate frame `7E 01 <len> 60 <len:2> <id:2> <timestamp:8> <payload> 7E`, with the full 64-bit timestamp |
| `0x93` | Command response | Transaction id at offset 5. [0x80092444](#ioctl-0x80092444): bytes 9…(len+3) (the DIAG response) are copied to the output buffer. [0x8009244C](#ioctl-0x8009244c): the frame is copied to a read of the client with the transaction id replaced by the client's tag |
| `0x94` | Delayed response ? | Transaction id at offset 8. Only for [0x8009244C](#ioctl-0x8009244c). The read receives `<bytes 0-3> 94 <tag:4> <bytes 12…>` (length − 3). The command is kept pending while the words at offsets 20/22 announce more responses |
| other | | Ignored |

A read request is filled with as many frames as fit and completed at the end of each received SMD buffer. A frame that doesn't fit completes the read and goes to the next pending read of the client. The frames for which no read is available are dropped and counted (see [IOCTL 0x8009246C](#ioctl-0x8009246c)).

### Masks

Each mask client has a log mask of 16 equipments × 512 bytes (4096 items per equipment) and an event mask of 512 bytes (4096 event ids) in its file context. At most 2 handles can register as mask client ([IOCTL 0x80092450](#ioctl-0x80092450)).  
On every change, the masks of all mask clients are OR-ed together (`sub_405F54` for logs, `sub_406108` for events) and sent to the router: [internal IOCTL 0x8008245D](#internal-ioctl-0x8008245d) (8208 bytes, pool tag `qidF`) or [internal IOCTL 0x80082461](#internal-ioctl-0x80082461) (512 bytes). The router forwards them to the modem `DIAG_CNTL` channel as stream id 2. The client's own mask is updated only when the router request succeeds (`sub_404030`).

File context of a handle (`DIAGCSI_FILE_CONTEXT`, 0x223C bytes):  
| Offset | Size | Comment |
|--------|------|---------|
| 0x0000 | 4 | `PKEVENT` of the client, or 0 |
| 0x0004 | 4 | 1 = registered ([0x80092440](#ioctl-0x80092440)) |
| 0x0008 | 2 | Notification flags |
| 0x000A | 2 | Notification types |
| 0x000C | 4 | Command work item (`DIAGCSI_WRKCOMMANDSEND_CONTEXT`) |
| 0x0010 | 4 | 1 = mask client ([0x80092450](#ioctl-0x80092450)) |
| 0x0014 | 8192 | Log masks, 16 × 512 bytes |
| 0x2014 | 512 | Event mask |
| 0x2214 | 4 | Mask work item (`sub_403668`) |
| 0x2218 | 32 | 8 counters, see [IOCTL 0x8009246C](#ioctl-0x8009246c) |
| 0x2238 | 4 | 1 = event referenced from a user-mode handle |

---

### IOCTL 0x80092440

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x910 (2320) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Register client | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Ignored |
| 04-07 | ? | Optional. User mode: HANDLE of an event (referenced with `ObReferenceObjectByHandle(EVENT_MODIFY_STATE, ExEventObjectType)`). Kernel mode: `PKEVENT`. 0 = no event |
| 08-09 | 02 00 | Notification flags, 1…3. Bit 1: notify the DIAG_2 channel state |
| 0A-0B | 03 00 | Notification types, 1…7. Bit 0: channel open, bit 1: channel closed, bit 2: ? |
| 0C-0F | ? | Ignored |

The checks are done in `EvtIoInCallerContext` (`sub_4014B0`): the words at 08 and 0A are checked only when an event is given.  
The handler creates the command work item of the handle, 3 requests and 2 buffers of 4096 bytes, and adds the handle to the client collection. If the event is set up for notification type 1 and `DIAG_2` is already open, the event is set immediately.  
NTSTATUS:  
| Value | Comment |
|-------|---------|
| 0xC00000A3 STATUS_DEVICE_NOT_READY | `\Device\DiagRouter` is not open yet |
| 0xC000000D STATUS_INVALID_PARAMETER | InputBufferLength ≠ 16, or a flags/types word out of range |
| 0xC0000022 STATUS_ACCESS_DENIED | The handle is already registered |

---

### IOCTL 0x80092444

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x911 (2321) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send command, synchronous | min 1 | min 4096 |

Inputbuffer: a DIAG request (e.g. `4B 32 03 00`).  
Outputbuffer: the DIAG response, without DCI header. `13 <request>` if nobody handles the command.

The request is pended and processed by the command work item (see [Commands](#commands)). A 500 ms timer is started: if the modem doesn't answer in time, the request is completed with `STATUS_CANCELLED` (0xC0000120). It's also cancelled when `DIAG_2` closes. When the command goes to the modem, the request is completed only when both the write to `DIAG_2` and the response are complete (reference count 2, `DIAGCSI_CLNTCMDREQ_CONTEXT`).  
NTSTATUS:  
| Value | Comment |
|-------|---------|
| 0xC0000022 STATUS_ACCESS_DENIED | [IOCTL 0x80092440](#ioctl-0x80092440) not done on the handle |
| 0xC00000A3 STATUS_DEVICE_NOT_READY | The router didn't complete [internal IOCTL 0x80082458](#internal-ioctl-0x80082458) yet |
| 0xC000000D STATUS_INVALID_PARAMETER | Empty input or OutputBufferLength < 4096 |
| 0xC0000037 STATUS_PORT_DISCONNECTED | The command goes to the modem but `DIAG_2` is closed |

---

### IOCTL 0x80092448

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x912 (2322) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get status | 0 | 2 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 02 00 | Bit 1: `DIAG_2` is open. Other bits are 0 |

OutputBufferLength must be exactly 2, otherwise `STATUS_INVALID_PARAMETER`. Doesn't require [IOCTL 0x80092440](#ioctl-0x80092440).

---

### IOCTL 0x8009244C

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x913 (2323) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send command, asynchronous | min 5 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Client tag, returned in place of the transaction id in the response frame |
| 04-… | ? | DIAG request |

The IOCTL is completed with the status of the write to `DIAG_2`. The response is returned later by `ReadFile` as a frame `7E 01 <len> 93 <tag> <response> 7E` (or `94` for a delayed response). If nobody handles the command, the IOCTL succeeds and a pending read of the client receives `7E 01 <N+6> 93 <tag> 13 <request> 7E` (this needs a read already pending, otherwise the IOCTL fails with the status of `WdfIoQueueRetrieveRequestByFileObject`).  
There's no timeout. The response of a local DIAG client ([internal IOCTL 0x80092491](#internal-ioctl-0x80092491)) is only handled for [IOCTL 0x80092444](#ioctl-0x80092444): with this IOCTL it's dropped.  
Same NTSTATUS as [IOCTL 0x80092444](#ioctl-0x80092444).

---

### IOCTL 0x80092450

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x914 (2324) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Register mask client | 0 | 0 |

`sub_403248` creates the mask work item of the handle and adds the handle to the mask-client collection. At most 2 handles: a third one gets `STATUS_UNSUCCESSFUL`. Needed by IOCTLs 0x80092454 to 0x80092468, which return `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) otherwise.

---

### IOCTL 0x80092454

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x915 (2325) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set log codes | 4 + 2×N | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 01 00 | 0 = disable, ≠0 = enable |
| 02-03 | N | Number of log codes. Must not be 0 |
| 04-05 | e.g. 6D 13 | Log code 1 (e.g. 0x136D). Equipment = bits 12-15, item = bits 0-11 |
| … | | N log codes |

InputBufferLength must be exactly 4 + 2×N, otherwise `STATUS_INVALID_PARAMETER`. The request is completed when the router completes [internal IOCTL 0x8008245D](#internal-ioctl-0x8008245d). Only the equipments that contain one of the codes are flagged as updated.

---

### IOCTL 0x80092458

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x916 (2326) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Is log code enabled | 2 | 1 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Log code |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 or 01 | 1 if the code is enabled in the client's own log mask |

Both lengths must be exact, otherwise `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x8009245C

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x917 (2327) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Clear log mask | 0 | 0 |

Clears the client's log masks, then sends the merged masks of the other mask client to the router ([internal IOCTL 0x8008245D](#internal-ioctl-0x8008245d), all 16 equipments flagged).

---

### IOCTL 0x80092460

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x918 (2328) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set event ids | 4 + 2×N | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 01 00 | 0 = disable, ≠0 = enable |
| 02-03 | N | Number of event ids. Must not be 0 |
| 04-05 | ? | Event id 1 (0…4095, larger values are ignored) |
| … | | N event ids |

Same checks as [IOCTL 0x80092454](#ioctl-0x80092454). The merged event mask is sent with [internal IOCTL 0x80082461](#internal-ioctl-0x80082461).

---

### IOCTL 0x80092464

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x919 (2329) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Is event enabled | 2 | 1 |

Same as [IOCTL 0x80092458](#ioctl-0x80092458) for an event id. The output byte is the masked bit (`1 << (id & 7)`), not 0/1.

---

### IOCTL 0x80092468

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x91A (2330) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Clear event mask | 0 | 0 |

Same as [IOCTL 0x8009245C](#ioctl-0x8009245c) for the event mask ([internal IOCTL 0x80082461](#internal-ioctl-0x80082461)).

---

### IOCTL 0x8009246C

This IOCTL is processed by Qcdiagcsi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x91B (2331) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get statistics | 1 | 32 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 or 01 | ≠0: reset the counters after reading them |

Outputbuffer: counters of the handle (file context `+0x2218`), saturating at 0xFFFFFFFF.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Log packets dropped (no read available or read failed) |
| 04-07 | ? | Log packets matching the log mask |
| 08-0B | ? | Events dropped |
| 0C-0F | ? | Events matching the event mask |
| 10-13 | ? | Responses (`0x93`) dropped |
| 14-17 | ? | Responses (`0x93`) received, asynchronous commands |
| 18-1B | ? | Delayed responses (`0x94`) dropped |
| 1C-1F | ? | Delayed responses (`0x94`) received |

Both lengths must be exact, otherwise `STATUS_INVALID_PARAMETER`. Doesn't require [IOCTL 0x80092440](#ioctl-0x80092440).

---

### internal IOCTL 0x80092491

This IOCTL is processed by Qcdiagcsi8930.sys. It's sent by [qcdiagrouter8930.sys](./qcdiagrouter8930.md#internal-ioctl-0x80092491)

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x924 (2340) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| DCI response from a local client | min 8 | 0 |

Inputbuffer: the buffer written by a local DIAG client of the router.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 93 | DCI response |
| 01-03 | ? | Ignored |
| 04-07 | ? | Transaction id of the command (copied from the request) |
| 08-… | ? | DIAG response |

`sub_401E38` removes the pending command with this id. If it was sent with [IOCTL 0x80092444](#ioctl-0x80092444), bytes 08… are copied to its output buffer and it's completed (the output buffer must be at least as large as this whole input buffer). Any other internal IOCTL code gets `STATUS_INVALID_DEVICE_REQUEST`.

---

### internal IOCTL 0x80082450

This IOCTL is sent by Qcdiagcsi8930.sys to [qcdiagrouter8930.sys](./qcdiagrouter8930.md#internal-ioctl-0x80082450)

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x914 (2324) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Query command owner | `\Device\DiagRouter` | 4 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Command code (byte 8 of the request if byte 0 is `0x93`) |
| 01 | ? | Subsystem id, 0xFF if none |
| 02-03 | ? | Subsystem command code, 0xFFFF if none |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00…03 00 00 00 | Bit 0: local DIAG client of the router. Bit 1: modem |

Sent synchronously by the command work item `sub_401FB8`.

---

### internal IOCTL 0x80082454

This IOCTL is sent by Qcdiagcsi8930.sys to [qcdiagrouter8930.sys](./qcdiagrouter8930.md#internal-ioctl-0x80082454)

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x915 (2325) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Deliver request to local client | `\Device\DiagRouter` | N + 8 | 0 |

Inputbuffer: `93 ?? ?? ?? <transaction id:4> <request>`, see [Commands](#commands). Sent synchronously when the owner bit 0 is set.

---

### internal IOCTL 0x80082458

This IOCTL is sent by Qcdiagcsi8930.sys to [qcdiagrouter8930.sys](./qcdiagrouter8930.md#internal-ioctl-0x80082458)

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x916 (2326) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Connect to DiagCSI | `\Device\DiagRouter` | 0 | 0 |

Sent asynchronously once, by work item `sub_40292C`, right after the `{23ccade6-…}` interface is enabled. The router completes it when it has opened `\Device\DiagCSI`. Success sets the "router connected" flag needed by [IOCTL 0x80092444](#ioctl-0x80092444) / [0x8009244C](#ioctl-0x8009244c).

---

### internal IOCTL 0x8008245D

This IOCTL is sent by Qcdiagcsi8930.sys to [qcdiagrouter8930.sys](./qcdiagrouter8930.md#internal-ioctl-0x8008245d)

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x917 (2327) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set DCI log masks | `\Device\DiagRouter` | 8208 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 00 or 01 | One byte per equipment 0…15, 1 = updated. All 01 when a client clears its mask or closes |
| 10-200F | ? | Merged log masks of all mask clients, 16 × 512 bytes |

Sent asynchronously by the mask work item (`sub_403668`) for [IOCTL 0x80092454](#ioctl-0x80092454) / [0x8009245C](#ioctl-0x8009245c) and on close, and by `sub_403BF0` when `DIAG_2` opens.

---

### internal IOCTL 0x80082461

This IOCTL is sent by Qcdiagcsi8930.sys to [qcdiagrouter8930.sys](./qcdiagrouter8930.md#internal-ioctl-0x80082461)

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x918 (2328) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set DCI event mask | `\Device\DiagRouter` | 512 | 0 |

Inputbuffer: merged event mask of all mask clients (512 bytes, bit `id` = event id).  
Sent in the same cases as [0x8008245D](#internal-ioctl-0x8008245d), for [IOCTL 0x80092460](#ioctl-0x80092460) / [0x80092468](#ioctl-0x80092468).

---

### IOCTLs sent to qcsmd8930.sys

These internal IOCTLs are sent synchronously by Qcdiagcsi8930.sys to `\Device\SMD` ([qcsmd8930.sys](./qcsmd8930.md)) through `sub_404AE8`, to open the channel `DIAG_2` (thread `sub_404260`). They are METHOD_NEITHER and the buffers contain kernel pointers. It's the same sequence as the data channels of [qcdiagrouter8930.sys](./qcdiagrouter8930.md#ioctls-sent-to-qcsmd8930sys).  
| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| `0x2200F` (Device 0x2, Function 0x803) | `\Device\SMD` | 8 | 0 |
| `0x22003` (Device 0x2, Function 0x800) | `\Device\SMD` | 28 | 0 |
| `0x22033` (Device 0x2, Function 0x80C) | `\Device\SMD` | 0 | 0 |

`0x2200F` inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT` (channel state event ?) |
| 04-07 | ? | `PKEVENT` (channel state event ?) |

`0x22003` inputbuffer (open channel):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the ASCII channel name `DIAG_2` |
| 04-07 | 00 00 00 00 | SMD edge 0 = APPS↔MODEM |
| 08-0B | 01 00 00 00 | ? |
| 0C-0F | 00 00 00 00 | ? (FIFO size ?) |
| 10-13 | ? | Pointer to the port context |
| 14-17 | ? | `PKEVENT` |
| 18-1B | ? | `PKEVENT` |

The open buffers use the pool tags `qidA`, `qidB`, `qidC`. After the open, the channel is read with `WdfIoTargetFormatRequestForRead` and written with `WdfIoTargetFormatRequestForWrite`.
