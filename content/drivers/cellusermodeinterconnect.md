## Cellusermodeinterconnect.sys

Cellular user-mode interconnect bus (Microsoft, WP8.1 "cellcore", KMDF 1.11).  
It is a root-enumerated bus driver that lets a **user-mode process act as the lower end of a cellular pipe**. The process opens `\??\UserModeInterconnectBus` and sends [IOCTL 0x6A8004](#ioctl-0x6a8004--create-device). The driver then creates a child PDO with the device ID / hardware ID chosen by the process, and maps a shared buffer holding two ring buffers into that process. The PDO exposes the cellular pipe query-interface `{B9086F29-6065-4DBE-8C90-3CD560547957}` (the same as [cellmux.sys](./cellmux.md#pipe-interface)) to the driver loaded on it. Packets that driver sends down are copied into one ring for the process. Packets the process writes into the other ring are given to the driver in place (no copy). The process wakes the driver with [IOCTL 0x756D8008](#ioctl-0x756d8008--doorbell) ("doorbells"), and the driver wakes the process with two events.  
It is probably the bottom of the cellular stack: [msril.sys](./msril.md) → [cellmux.sys](./cellmux.md) queue PDO → cellmux FDO → [cellnetmon.sys](./cellnetmon.md) → cellusermodeinterconnect PDO → user-mode modem adaptation process ?  

Source tree: `src\net\cellcore\product\emb\cellusermodeinterconnect\` (`drivermain.c`, `busfdo.c`, `interconnect.c`) + `cellkernellib\` (`synchronizer.c`, `utility.c`). PDB: `cellusermodeinterconnect.pdb`. Built Jan 23 2015 18:13:46 (two seconds after cellmux.sys). Driver pool tag `MdmI` (0x496D644D), allocations `Cell` (0x6C6C6543, NonPagedPoolNx, 5 tries before a fatal error). No hardware access.

`DriverEntry` (sub_10002E0C) calls `WdfDriverCreate` and then **`IoReportRootDevice`**: the driver creates its own root devnode, so no INF hardware ID is needed for the bus FDO. It refuses to load (`Refusing to load due to Abort flag`, STATUS_UNSUCCESSFUL 0xC0000001) if the global at `.data:0x10006740` (misnamed `WdfDriverStubDisplacedDriverUnload` by IDA) is non-zero. Nothing in the driver writes it (same as [cellnetmon.sys](./cellnetmon.md)).

Device name : none (no `WdfDeviceInitAssignName`)  
Symbolic link : `\??\UserModeInterconnectBus`  
Child PDOs: one more symbolic link each, name given in [IOCTL 0x6A8004](#ioctl-0x6a8004--create-device).

There's no parameters in the registry.

GUID of the ETW provider:  
`{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}` (`Microsoft-WindowsPhone-Net-Debug`)  
Same `CellFatalError` as [cellmux.sys](./cellmux.md#guid-of-the-etw-provider) (sub_10002CF8, misnamed `McGenEventUnregister` by IDA): `DbgPrintEx` `Fatal Error (0x%08X) in kernel mode at api (%s) in file (%s) at line (%d)`, `EtwWrite` of `NET_FATAL_ERROR` (event 100, level 2, task 1, keyword 0x1), then `DbgBreakPointWithStatus(5)` if a kernel debugger is attached, **`__fastfail(7)`** otherwise.  
Debug messages go to `DbgPrintEx` (component id 0x31, prefix `CellUserModeInterconnect!`).

> [!NOTE]
> Every failed WDF / Ob / Mm call, a failed allocation, and a packet received in a wrong state are fatal. The IOCTL checks (buffer too small, too many devices, bad ring size, bad serial number) print a message and hit `__debugbreak()`. Without a kernel debugger, a breakpoint in kernel mode **crashes the phone** too.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| — | ? (user-mode process: modem adaptation / RIL service ?) | Opens `\??\UserModeInterconnectBus`, sends [IOCTL 0x6A8004](#ioctl-0x6a8004--create-device) and [IOCTL 0x756D8008](#ioctl-0x756d8008--doorbell), reads and writes the shared ring buffers, waits on the two events |
| Child PDO (consumer above) | [cellmux.sys](./cellmux.md) FDO, through the [cellnetmon.sys](./cellnetmon.md) lower filter ? | The driver loaded on the PDO (chosen by the hardware ID from the IOCTL) queries `{B9086F29-…}` from it (`WdfDeviceAddQueryInterface`, `BusFdoHandleQueryInterface` sub_10002C38) |

### Devices

**Bus FDO** (`EvtDriverDeviceAdd` sub_10002370): device context none, execution level passive, synchronization scope device. File object config: `EvtFileCleanup` = `BusFdoFileCleanup` (sub_10002628), `WdfFileObjectWdfCannotUseFsContexts`, file context `BUS_FDO_FILE_OBJECT_DATA` (0x44 bytes). One sequential default queue with `EvtIoDeviceControl` = `BusFdoDeviceControl` (sub_100026CC). Then `WdfDeviceCreateSymbolicLink` `\??\UserModeInterconnectBus`.

File context `BUS_FDO_FILE_OBJECT_DATA` (one per handle opened on the bus):  
| Offset | Comment |
|--------|---------|
| 0x00-0x3F | WDFDEVICE of the PDOs created through this handle (16 entries). The index is the **serial number** used by [IOCTL 0x756D8008](#ioctl-0x756d8008--doorbell) |
| 0x40 | Number of PDOs created (max 16) |

When the handle is closed (`BusFdoFileCleanup`), every PDO created through it is broken (`InterconnectBreakPipeFromPnpSync` sub_10002F18, through the synchronizer), the shared buffer is unmapped from the process (`MmUnmapLockedPages`), and the PDO is reported missing (`WdfPdoMarkMissing`). The pipes live only as long as the process keeps the handle open.

**Interconnect PDO** (created by [IOCTL 0x6A8004](#ioctl-0x6a8004--create-device), added with `WdfFdoAddStaticChild`). Device ID = hardware ID = first string of the IOCTL, instance ID = second string. Context `INTERCONNECT_DATA` (0x264 bytes), `EvtCleanupCallback` = `InterconnectDeleteDevice` (sub_10002534). PnP capabilities: Removable, SilentInstall and SurpriseRemovalOK set, Address and UINumber 0xFFFFFFFF (same as cellmux queue PDOs). A PnP state-change callback (`WdfDeviceInitRegisterPnpStateChangeCallback`, state 0x119, enter) creates the PDO's symbolic link (third string of the IOCTL) the first time the state is entered (sub_100024A4). The PDO has no I/O queue.  
`InterconnectDeleteDevice` waits for the state `BROKEN`, frees the cached work entries of the synchronizers, dereferences the two events, frees the MDL and the shared buffer.

Context `INTERCONNECT_DATA`:  
| Offset | Comment |
|--------|---------|
| 0x00 | Size of ring A (process → driver), rounded up to 4 KiB |
| 0x04 | Size of ring B (driver → process), rounded up to 4 KiB |
| 0x08 | Size of the shared buffer = 0x1000 + ring A + ring B |
| 0x0C | Shared buffer (kernel address, pool `Cell`) |
| 0x10 | MDL of the shared buffer |
| 0x14 | User-mode address of the shared buffer (in the process that sent the create IOCTL) |
| 0x18 / 0x1C | Event A: handle in the process / `KEVENT` pointer |
| 0x20 / 0x24 | Event B: handle in the process / `KEVENT` pointer |
| 0x28-0x4F | Synchronizer (`cellkernellib`, same code as cellmux): spinlock, pending work list, free list (max 5 cached entries), busy flag at 0x40, bus FDO WDFDEVICE at 0x4C |
| 0x50-0x6B | Pipe interface returned to the consumer (28 bytes) |
| 0x6C-0x7F | Context of the interface wrappers: synchronizer, self, `InterconnectReceivePacketFromAboveSync` (sub_100033A0), `InterconnectReturnPacketFromAboveSync` (sub_100035D8), `InterconnectPipeBrokenFromAboveSync` (sub_10003364) |
| 0x80-0x8F | Consumer's entries (`InterfaceSpecificData`: context, `ReceivePacket`, `ReturnPacket`, `PipeBroken`) |
| 0x90-0xDB | Receiver (ring A): own synchronizer (0x90-0xB7), self pointer at 0xB8, ring base 0xBC, ring size 0xC0, control block 0xC4, `KEVENT` A 0xC8, started 0xCC, list of the packets given out and not returned 0xD0, read position 0xD8 |
| 0xDC-0x123 | Sender (ring B): own synchronizer (0xDC-0x103), self pointer at 0x104, ring base 0x108, ring size 0x10C, control block 0x110, `KEVENT` B 0x114, started 0x118, send list 0x11C |
| 0x124 | Packets from above held until the negotiation is done |
| 0x12C | State: 0 `INTERCONNECT_STATE_UNINITIALIZED`, 1 negotiating, 2 open, 3 breaking, 4 `BROKEN` |
| 0x130 | Counter of entries in PnP state 0x119 (the symbolic link is created at 1) |
| 0x134 | Broken before any consumer ? (set with 0x138 when the pipe breaks with no consumer) |
| 0x138 | Pipe broken from above |
| 0x13C | Packets given to the consumer and not returned |
| 0x140 | Negotiated version |
| 0x144-0x153 | Session GUID (`ExUuidCreate`) |
| 0x154-0x253 | Symbolic link name of the PDO (WCHAR[128], from the IOCTL) |
| 0x254 | `KEVENT` set when the state reaches `BROKEN` |

### Shared buffer and ring buffers

Created by `InterconnectCreateDevice` (sub_10002F50). The buffer is allocated from NonPagedPoolNx, described by an MDL (`IoAllocateMdl` + `MmBuildMdlForNonPagedPool`) and mapped **writable into the calling process** (`MmMapLockedPagesSpecifyCache(UserMode, MmCached, NULL, FALSE, HighPagePriority | MdlMappingNoExecute)`). The two events are synchronization events created with `ZwCreateEvent` (kernel handle, closed at once). Then they are opened again with `ObOpenObjectByPointer` (EVENT_ALL_ACCESS, no `OBJ_KERNEL_HANDLE`), which gives a handle in the calling process. The mapping and the handles belong to the process in whose context the create IOCTL runs.

| Offset | Comment |
|--------|---------|
| 0x0000 | Offset of ring A = 0x1000 |
| 0x0004 | Size of ring A |
| 0x0008 | Offset of ring B = 0x1000 + size of ring A |
| 0x000C | Size of ring B |
| 0x0010 | Ring A read index (written by the driver) |
| 0x0014 | Ring A write index (written by the process) |
| 0x0018 | Ring A "process waits for space" flag: set by the process; the driver clears it and sets **event A** when it frees space |
| 0x001C | Ring A "driver waits for data" flag: set by the driver when it has read everything; the process should then send the doorbell "ring not empty" (it isn't cleared by the driver ?) |
| 0x0020 | Ring B read index (written by the process) |
| 0x0024 | Ring B write index (written by the driver) |
| 0x0028 | Ring B "driver waits for space" flag: set by the driver when ring B is full; the process should then send the doorbell "ring not full" (it isn't cleared by the driver ?) |
| 0x002C | Ring B "process waits for data" flag: set by the process; the driver clears it and sets **event B** when it writes data |
| 0x0030-0x0FFF | Unused (zero) |
| 0x1000- | Ring A, then ring B |

Ring record (both rings), aligned to 4 bytes:  
| Bytes | Comment |
|-------|---------|
| 00-01 | Record length, header included. 0 = wrap marker: the next record is at the start of the ring |
| 02-03 | Record type: 1 = negotiation request, 2 = negotiation response, 3 = data |
| 04- | Payload |

This 4-byte header replaces the [mux header](./cellmux.md#mux-header-and-packet-types) of cellmux (queue number + type): here the first word is a length, because the ring has no other framing. The data payload is the packet of the consumer, so with cellmux above it still starts with the mux header.

**Ring B (driver → process)**, `Sender*` functions (sub_10003ADC `SenderSendQueuedPacketsSync`): each packet from the send list is copied into the ring (all the chained buffers). If it doesn't fit before the end of the ring, the rest of the ring is zeroed (wrap marker) and the copy starts again at 0. If the ring is full, the driver sets the flag at 0x28, checks the read index once more, and stops. The write index is updated after the copy, then event B is set if the flag at 0x2C was set. Each copied data packet is given back to the consumer at once (`ReturnPacket`).  
**Ring A (process → driver)**, `Receiver*` functions (sub_10003800 `ReceiverDeliverPacketsFromBufferSync`): for each record between the driver's read position and the write index, the driver allocates a 52-byte packet descriptor that **points into the ring** (no copy) and passes it to `InterconnectReceivePacketFromBelowSync` (sub_10003470). When it has caught up, it sets the flag at 0x1C and checks the write index once more. The read index at 0x10 moves only when the packets are returned, in ring order (`ReceiverReturnPacketSync` sub_100038E8). Then event A is set if the flag at 0x18 was set.  
The record lengths written by the process are trusted: they aren't checked against the ring size or the write index.

### Pipe interface and protocol

Interface returned to the consumer (`{B9086F29-…}`, layout in [cellmux.sys](./cellmux.md#pipe-interface)):  
| Bytes | Comment |
|-------|---------|
| 00-01 | Size = 28 |
| 02-03 | Version = 1 |
| 04-07 | Context = `INTERCONNECT_DATA` + 0x50 |
| 08-0B / 0C-0F | InterfaceReference / InterfaceDereference: no-op (sub_10003EAC) |
| 10-13 | `SendPacket` = sub_10003E38 → `InterconnectReceivePacketFromAboveSync` |
| 14-17 | `ReturnPacket` = sub_10003E68 → `InterconnectReturnPacketFromAboveSync` (gives the record back to the receiver, decrements the not-returned counter) |
| 18-1B | `BreakPipe` = sub_10003E98 → `InterconnectPipeBrokenFromAboveSync` |

`BusFdoHandleQueryInterface` (sub_10002C38) fails with STATUS_INVALID_DEVICE_STATE (0xC0000184) if the state isn't 0. Otherwise it stores the consumer entries, starts the receiver and the sender, sets the state to 1, and sends the negotiation request. Then it returns **0xC0000000**, the same private convention as cellmux.

1. **Negotiation request** (sub_10003688), written directly to ring B: `1C 00 01 00` `01 00 00 00` `01 00 00 00` + 16-byte session GUID (28 bytes, same payload as the cellmux type 1 packet).  
2. **Negotiation response** expected in ring A in state 1: type 2, length ≥ 24, 04-07 version, 08-17 session GUID. If the GUID matches, the version is stored and the state goes to 2 (open). Then the held packets go to the sender. A version other than 1 only gives `Unsupported protocol version` and a `__debugbreak()`. Any other record received in state 1 is ignored and returned to the ring.  
3. **Open**: a packet from above gets the 4-byte header (length, type 3; taken from the headroom, or an 88-byte header packet if the headroom is less than 4) and goes to the sender. A type 3 record from ring A loses its header and goes to the consumer's `ReceivePacket`. Another type gives `Received packet type %d; resetting connection` and a `__debugbreak()`, but no reset is done: the record is then handed to the consumer like data.  
4. **Breaking** (sub_1000378C), entered when the consumer calls `BreakPipe` or when the handle of the process is closed: the consumer's `PipeBroken` is called once, the held packets are returned, and packets sent later are returned at once. The process isn't told through the ring. **Broken** (state 4, event set) is reached when the pipe was broken from above and the consumer has returned every packet (`InterconnectAdvanceBreakingStateIfNeeded` sub_10003710).  
In state 0, or in state 4 for a packet from above, a packet is a fatal error.

---

### IOCTL 0x6A8004 — Create device

This IOCTL is processed by Cellusermodeinterconnect.sys (bus FDO, `BusFdoDeviceControlCreate` sub_1000273C)

| Property | Value |
|----------|-------|
| Device | 0x6A |
| Function | 0x1 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Create device | ≥ 392 | ≥ 24 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size of ring A (process → driver), 0x800..0x100000, rounded up to 4 KiB |
| 04-07 | ? | Size of ring B (driver → process), 0x800..0x100000, rounded up to 4 KiB |
| 08-47 | ? | Device ID and hardware ID of the PDO, WCHAR[32], NUL-terminated if shorter |
| 48-87 | ? | Instance ID of the PDO, WCHAR[32] |
| 88-187 | ? | Symbolic link of the PDO, WCHAR[128] (e.g. `\??\…`), created when the PDO starts |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Serial number (index of the PDO for this handle, 0..15), for [IOCTL 0x756D8008](#ioctl-0x756d8008--doorbell) |
| 04-07 | ? | User-mode address of the [shared buffer](#shared-buffer-and-ring-buffers) |
| 08-0F | ? | Handle of event A (64-bit, sign-extended): "ring A has space" |
| 10-17 | ? | Handle of event B (64-bit, sign-extended): "ring B has data" |

Completed with STATUS_SUCCESS and information = 24.  
Errors (each one after a debug message and a `__debugbreak()`): input or output buffer too small → STATUS_BUFFER_TOO_SMALL (0xC0000023) ("IOCTL input/output buffer is too small"); 16 PDOs already created on this handle ("This opener has already created %d devices") or a ring size out of range ("Ring buffer sizes (%d, %d) must be in the range %d..%d") → STATUS_INVALID_PARAMETER (0xC000000D). Any other IOCTL code is completed with STATUS_INVALID_DEVICE_REQUEST (0xC0000010) ("Unknown IOCTL").  
The sender isn't known. No analysed binary contains the code.

---

### IOCTL 0x756D8008 — Doorbell

This IOCTL is processed by Cellusermodeinterconnect.sys (bus FDO, `BusFdoDeviceControlDoorbell` sub_10002B28)

| Property | Value |
|----------|-------|
| Device | 0x756D |
| Function | 0x2 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Doorbell | ≥ 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Serial number returned by [IOCTL 0x6A8004](#ioctl-0x6a8004--create-device) on the **same handle** |
| 04-07 | 00 00 00 00 | 0 = "ring A not empty": the process wrote records (`ReceiverRingNotEmptyDoorbellSync` sub_100038B0). Non-zero = "ring B not full": the process consumed records (`SenderRingNotFullDoorbellSync` sub_10003A30) |

The doorbell is run through the receiver's or the sender's synchronizer. Completed with STATUS_SUCCESS, no output.  
A buffer smaller than 8 bytes gives `IOCTL input buffer is too small` and a `__debugbreak()`. A serial number ≥ the number of PDOs of the handle gives `Bad SerialNumber %d` and a `__debugbreak()`, then the handler **goes on** and reads the WDFDEVICE out of the bounds of the 16-entry array.  
The sender isn't known. No analysed binary contains the code.

---

### Other GUID

Cellular pipe query-interface (exposed by every interconnect PDO)  
`{B9086F29-6065-4DBE-8C90-3CD560547957}`
