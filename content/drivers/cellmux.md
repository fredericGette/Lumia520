## Cellmux.sys

Cellular pipe multiplexer (Microsoft, WP8.1 "cellcore", KMDF 1.11).  
It is a bus driver. Its FDO sits on one cellular **pipe**: a packet transport to the modem side, reached through the query-interface `{B9086F29-6065-4DBE-8C90-3CD560547957}` of the device below. It splits this pipe into up to 65536 numbered **queues**. Each queue gets a child PDO, created on request with [IOCTL 0x716D8004](#ioctl-0x716d8004--create-queue). Each queue PDO exposes the same pipe interface to the driver loaded on it, so a client sees an ordinary pipe. Every packet gets a 4-byte header (queue number + packet type). Each queue negotiates a protocol version with the other end, then runs credit-based flow control (window updates).  
Source tree: `src\net\cellcore\product\emb\cellmux\` (`drivermain.c`, `muxbusfdo.c`, `queuepdo.c`) + `cellkernellib\` (`utility.c`, `synchronizer.c`). PDB: `cellmux.pdb`. Built Jan 23 2015 18:13:44. Driver pool tag `MdmM` (0x4D6D644D), allocations `Cell` (0x6C6C6543, NonPagedPoolNx, 5 tries before a fatal error). No hardware access.

Same family (same pipe GUID, same `cellkernellib`, same ETW provider): [cellusermodeinterconnect.sys](./cellusermodeinterconnect.md) (root bus `\??\UserModeInterconnectBus`, gives pipes to a user-mode process through ring buffers and doorbells), [cellnetmon.sys](./cellnetmon.md) (pipe filter that copies the queue 1 traffic to ETW and to a TCP socket) and [msril.sys](./msril.md) (RIL driver, pipe client). The stack is probably [msril.sys](./msril.md) → cellmux queue PDO → cellmux FDO → [cellnetmon.sys](./cellnetmon.md) → [cellusermodeinterconnect.sys](./cellusermodeinterconnect.md) PDO → user-mode modem adaptation. Cellnetmon parses the mux header, so it is a lower filter of the cellmux FDO. The cellusermodeinterconnect PDO provides the pipe interface, and the hardware ID of that PDO is chosen by the user-mode process, so the driver loaded on it can't be confirmed from the binaries.

There's no named `\Device\` object. The FDO registers the device interface `{2B70CD07-AED0-465B-A808-22C3CC914A30}` (no reference string) so that clients can open it and send [IOCTL 0x716D8004](#ioctl-0x716d8004--create-queue).

There's no parameters in the registry.

GUID of the ETW provider:  
`{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}` (`Microsoft-WindowsPhone-Net-Debug`)  
It is used only by the fatal error routine (`CellFatalError`, sub_100026D0, misnamed `McGenEventUnregister` by IDA). The provider is registered and unregistered around a single `EtwWrite` of `NET_FATAL_ERROR` (event 100, level 2, task 1, keyword 0x1) with the file name, line, API name and NTSTATUS. It is the shared provider of the `__FatalError` routines of the other cellcore drivers and of the Bluetooth binaries ([bthl2cap.sys](./bthl2cap.md), [BtConnectionManagerService.dll](../libraries/btconnectionmanagerservice.md), …).  
Debug messages go to `DbgPrintEx` (component id 0x31 `DPFLTR_IHVDRIVER_ID`?, prefix `CellMux!`).

> [!NOTE]
> `CellFatalError` prints `Fatal Error (0x%08X) in kernel mode at api (%s) in file (%s) at line (%d)`, writes the ETW event, then calls `DbgBreakPointWithStatus(5)` if a kernel debugger is attached and **`__fastfail(7)`** (bugcheck 0x139) otherwise. It is called after almost every failed WDF call and for protocol violations (packet sent on a queue that isn't started or is broken, too-small IOCTL buffer, queue number in use, `Sync block stuck`…). A bad [IOCTL 0x716D8004](#ioctl-0x716d8004--create-queue) from any client that can open the interface **crashes the phone**.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Parent device (lower stack of the FDO) | [cellnetmon.sys](./cellnetmon.md) filter, then [cellusermodeinterconnect.sys](./cellusermodeinterconnect.md) PDO ? | `WdfFdoQueryForInterface` `{B9086F29-6065-4DBE-8C90-3CD560547957}`, size 28, version 1, see [Pipe interface](#pipe-interface). IOCTLs other than 0x716D8004 sent to the FDO are forwarded to it unchanged (`WdfRequestSend`, `WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET`), e.g. [IOCTL 0x6E800C](./cellnetmon.md#ioctl-0x6e800c--set-configuration) processed by cellnetmon.sys |
| Queue PDOs (children) | [msril.sys](./msril.md) ? | The function driver loaded on a queue PDO queries `{B9086F29-…}` from it (msril.sys accepts the 0xC0000000 status too) |
| — | ? (user mode, RIL / cellular service ?) | Opens interface `{2B70CD07-…}` and sends [IOCTL 0x716D8004](#ioctl-0x716d8004--create-queue) |

### Devices

**Bus FDO** (`MuxBusFdoDeviceAdd` sub_100027E4). Context `MUX_BUS_FDO_DATA` (0x6C bytes), synchronization scope device, passive execution level. One sequential default queue with `EvtIoDeviceControl` = `MuxBusFdoDeviceControl` (sub_10002A78).  
| Offset | Comment |
|--------|---------|
| 0x00 | State: 0 active, 1 breaking (pipe broken from below), 2 broken (no queue PDO left) |
| 0x04 | WDFDEVICE |
| 0x08-0x23 | Lower pipe interface (28 bytes, see below) |
| 0x24-0x48 | Synchronizer (`cellkernellib`): spinlock, pending work list, free list (max 5 cached entries), busy flag at 0x3C, WDFDEVICE referenced while a work item runs |
| 0x4C-0x5F | Context given to the wrappers called from below: synchronizer, FDO data, `MuxBusFdoReceivePacketFromBelow`, `MuxBusFdoReturnPacketFromBelow`, `MuxBusFdoPipeBrokenFromBelow` |
| 0x60 | Spinlock of the queue table |
| 0x64 | Queue table size (8 at start, doubled when needed) |
| 0x68 | Queue table (array of WDFDEVICE of the queue PDOs, index = queue number) |

All the callbacks of the pipe (from above and from below) are serialised through the synchronizer (`SynchronizerRun` sub_10003E38): if a callback is already running, the new one is queued and run by the same thread afterwards.

**Queue PDO** (`QueuePdoDeviceAdd` sub_100030FC, created by [IOCTL 0x716D8004](#ioctl-0x716d8004--create-queue), added with `WdfFdoAddStaticChild`). Device ID = hardware ID = the string from the IOCTL, instance ID = the second string. PnP capabilities: Removable, SilentInstall and SurpriseRemovalOK set, Address and UINumber 0xFFFFFFFF. One default queue whose `EvtIoDeviceControl` (`QueuePdoDeviceControl` sub_100033DC) fails every IOCTL with `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) ("Unknown IOCTL"). Query-interface `{B9086F29-…}` handled by `QueuePdoHandleQueryInterface` (sub_10003448).  
Context `QUEUE_PDO_DATA` (0xD8 bytes):  
| Offset | Comment |
|--------|---------|
| 0x00 | WDFDEVICE |
| 0x04 | Bus FDO data |
| 0x08 | Queue number |
| 0x0C | Per-packet overhead (bytes) from the IOCTL, sent in window updates |
| 0x10 | Receive window (bytes) from the IOCTL |
| 0x14-0x2F | Pipe interface returned to the client (28 bytes) |
| 0x30-0x40 | Synchronizer pointer, self, internal handlers |
| 0x44 | Client context (0x44-0x53 come from the `InterfaceSpecificData` of the client's query) |
| 0x48 | Client `ReceivePacket` callback |
| 0x4C | Client `ReturnPacket` callback |
| 0x50 | Client `PipeBroken` callback |
| 0x54 | Peer's per-packet overhead (from its window update) |
| 0x58 / 0x60 | Packets / bytes sent (64-bit) |
| 0x68 | Send window limit (64-bit, from the peer's window update) |
| 0x70 / 0x78 | Packets / bytes received and returned by the client (64-bit) |
| 0x80 | Receive window limit advertised to the peer (64-bit) |
| 0x88 | Send list (packets from above waiting for window), count at 0x90 |
| 0x94 | Session GUID (`ExUuidCreate`, sent in the negotiation request) |
| 0xA4 | State: 0 `NOT_STARTED`, 1 `NEGOTIATING`, 2 open, 3 breaking, 4 `BROKEN` |
| 0xA8 | Event set when the state reaches `BROKEN` |
| 0xB8 / 0xBC / 0xC0 | Broken from above / from below / released (cleanup) |
| 0xC4 | Client `PipeBroken` already called |
| 0xC8 | Reset packet sent |
| 0xCC / 0xD0 | Packets given to the client and not returned / packets given to the lower pipe and not returned |

### Pipe interface

`{B9086F29-6065-4DBE-8C90-3CD560547957}`, version 1, 28 bytes. The provider (lower side) fills a standard `INTERFACE` with 3 functions. The consumer (upper side) passes its own 4 entries in `InterfaceSpecificData`.  
Interface returned by the provider:  
| Bytes | Comment |
|-------|---------|
| 00-01 | Size = 28 |
| 02-03 | Version = 1 |
| 04-07 | Context |
| 08-0B | InterfaceReference (no-op in cellmux, sub_1000406C) |
| 0C-0F | InterfaceDereference (no-op) |
| 10-13 | `SendPacket(Context, Packet)`: the consumer sends a packet down. Cellmux: `QueuePdoReceivePacketFromAbove` |
| 14-17 | `ReturnPacket(Context, Packet)`: the consumer gives back a packet it received. Cellmux: `QueuePdoReturnPacketFromAbove` |
| 18-1B | `BreakPipe(Context)`: the consumer closes the pipe. Cellmux: `QueuePdoPipeBrokenFromAbove` |

`InterfaceSpecificData` given by the consumer (16 bytes):  
| Bytes | Comment |
|-------|---------|
| 00-03 | Consumer context |
| 04-07 | `ReceivePacket(ctx, Packet)`: a packet arrives from below |
| 08-0B | `ReturnPacket(ctx, Packet)`: a packet sent earlier is given back (sent, or dropped while breaking) |
| 0C-0F | `PipeBroken(ctx)`: the pipe is broken |

`QueuePdoHandleQueryInterface` stores the consumer entries, builds the [negotiation request](#packet-types) and returns **0xC0000000** (a non-standard error code, after the interface has been filled). The FDO accepts 0xC0000000 from its own `WdfFdoQueryForInterface` as success, so it is a private convention of the pipe providers.

Packet descriptor (as used by cellmux; the packets cellmux allocates are 52 bytes of descriptor + 32 bytes of headroom + the payload):  
| Offset | Comment |
|--------|---------|
| 0x00 | Buffer pointer |
| 0x04 | Offset of the data in the buffer (headroom) |
| 0x08 | Length of the data in this buffer |
| 0x0C | Total length (including chained packets) |
| 0x10 | Chained (inner) packet |
| 0x14 | List entry / owner, used by the layers while they hold the packet |

To add the 4-byte header (`PacketPushHeader` sub_10004078), cellmux takes it from the headroom (offset − 4, lengths + 4). If the headroom is less than 4, it allocates an 88-byte header packet that chains the original. `PacketPopHeader` (sub_100040C0) undoes it.

### Mux header and packet types

| Bytes | Comment |
|-------|---------|
| 00-01 | Queue number |
| 02-03 | Packet type |

| Type | Name | Payload after the header | Comment |
|------|------|--------------------------|---------|
| 1 | Negotiation request | `01 00 00 00` `01 00 00 00` + 16-byte session GUID (total 28 bytes) | Sent when a client opens the queue (query-interface). The two DWORDs are probably the min/max protocol versions ? |
| 2 | Negotiation response | 00-03 negotiated version, 04-13 session GUID | Accepted in state `NEGOTIATING` only if the GUID matches; version ≠ 1 → "finds no common protocol" → breaking |
| 3 | Data | client data | Header added on send, removed before delivery to the client |
| 4 | Window update | 00-03 per-packet overhead, 04-0B new window limit (64-bit) (total 16 bytes) | Received: sets the send overhead and the send window limit, then retries the send list |
| 5 | Reset | — (total 4 bytes) | Sent when the queue starts breaking (unless broken from below). Received → broken from below |

Any other type in the open state → `DbgBreak` ("Invalid packet type"), then handled like a reset. Packets for a queue number with no PDO are only logged ("Packet for nonexistent queue"). They are **not returned** to the lower pipe.

### Queue protocol

1. **Open**. The client's query-interface creates the type 1 packet (state → `NEGOTIATING` via `QueuePdoAdvanceAfterQueryInterface`). A second query on a started queue breaks it. Data sent by the client in this state is held in the send list.
2. **Negotiation**. A valid type 2 response → state open. Cellmux sends its first window update (limit = receive window) and tries to send the held packets. Other packets in `NOT_STARTED` / `NEGOTIATING` are logged and returned.
3. **Flow control**. A data packet is sent only if `sent bytes + sent packets × peer overhead + peer overhead + align4(packet length) ≤ send window limit` (`QueuePdoTrySendQueuedPackets` sub_10003CDC). The send window limit is 0 until the peer's first window update. On the receive side, every packet the client returns adds `align4(total length)` bytes. When `received bytes + received packets × own overhead + receive window / 2 ≥ advertised limit`, cellmux advertises a new limit = that amount + receive window (`QueuePdoSendWindowUpdateIfNeeded` sub_10003C0C).
4. **Breaking** (`QueuePdoEnterBrokenState` sub_10003784; flag 1 from above, 2 from below, 3 cleanup, 4 re-query). Cellmux returns the send list to the client, calls the client's `PipeBroken` once and sends a reset (type 5) if not broken from below. State → 3. Packets sent by the client are then returned at once.
5. **Broken**. Reached when broken from below, and broken from above or released, and no packet is outstanding in either direction. Cellmux sets the event.
6. **Cleanup** of the PDO (`QueuePdoDeviceCleanup` sub_100032BC). It breaks the queue (flag 3), waits for `BROKEN`, then waits up to 100 × 100 ms for the synchronizer to be idle (fatal `Sync block stuck` after that) and removes the queue from the table.

When the lower pipe breaks (`MuxBusFdoPipeBrokenFromBelow` sub_10002E18), the FDO goes to state 1 and calls the lower `BreakPipe`. Every queue is broken from below and its PDO is reported missing (`WdfPdoMarkMissing` from a work item). When no queue is left, the FDO goes to state 2. While the FDO is breaking or broken, packets for the lower pipe are completed at once, and IOCTLs fail with `STATUS_DEVICE_NOT_READY` (0xC00000A3).

---

### IOCTL 0x716D8004 — Create queue

This IOCTL is processed by Cellmux.sys (bus FDO, `MuxBusFdoDeviceControlCreateQueue` sub_10002B34)

| Property | Value |
|----------|-------|
| Device | 0x716D |
| Function | 0x1 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Create queue | ≥ 140 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Queue number, ≤ 0xFFFF and not in use |
| 04-07 | ? | Per-packet overhead in bytes (used in the window accounting, sent to the peer) |
| 08-0B | ? | Receive window in bytes |
| 0C-4B | ? | Device ID and hardware ID of the queue PDO, WCHAR[32], NUL-terminated (not checked) |
| 4C-8B | ? | Instance ID of the queue PDO, WCHAR[32], NUL-terminated (not checked) |

Creates the queue PDO (see [Devices](#devices)), stores it in the queue table (which grows by doubling) and completes with `STATUS_SUCCESS` and no output.  
An input buffer smaller than 140 bytes ("IOCTL input buffer is too small") or a queue number that is out of range or in use ("Queue %d is out of range or in use") causes a `DbgBreak` followed by [`CellFatalError`](#guid-of-the-etw-provider) (bugcheck without a debugger). It isn't returned as an error status.  
The sender isn't known. No analysed binary contains the code.

All other IOCTL codes sent to the FDO are forwarded to the lower device (e.g. [IOCTL 0x6E800C](./cellnetmon.md#ioctl-0x6e800c--set-configuration), processed by [cellnetmon.sys](./cellnetmon.md)).

---

### Interface GUID

Cellmux bus interface class GUID (opened to send [IOCTL 0x716D8004](#ioctl-0x716d8004--create-queue))  
`{2B70CD07-AED0-465B-A808-22C3CC914A30}`

### Other GUID

Cellular pipe query-interface (consumed from the parent, exposed by every queue PDO; also used by [cellusermodeinterconnect.sys](./cellusermodeinterconnect.md), [cellnetmon.sys](./cellnetmon.md) and [msril.sys](./msril.md))  
`{B9086F29-6065-4DBE-8C90-3CD560547957}`
