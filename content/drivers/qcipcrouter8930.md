## Qcipcrouter8930.sys

IPC Router.  
It implements the Qualcomm "MSM IPC Router" protocol (the QMI transport, same protocol as `ipc_router.c` of the Qualcomm Linux kernels): every processor of the SoC is a *node*, every endpoint is a *port* (`node:port` address), and services are published as `service:instance` *servers*. Messages are packets with a 32-byte header, carried here over SMD channels opened on [qcsmd8930.sys](./qcsmd8930.md).  
Each handle opened on `\Device\IPC` is one local port. User mode clients (QMI clients/services) send and receive packets with `WriteFile`/`ReadFile` and register or look up servers with the IOCTLs below. The router also forwards packets and control messages between its transports (node-to-node routing), and tells the other nodes about the local servers.  
The SMD links are described in the registry (one subkey per transport). They are opened when the SMD interface arrives.  
Built from `P:\IPC_Router\rel\8.5\arm\Release\qcipcrouter8930.pdb`.

Device name : `\Device\IPC`  
Symbolic link : `\DosDevices\IPC`  
SDDL : `D:P(A;;GA;;;LS)(A;;GA;;;BA)` (LocalService and Administrators only)

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcipcrouter8930` ?

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters` (`WdfDriverOpenParametersRegistryKey` in `EvtDriverDeviceAdd`, 0x409008):  
| Registry value | value | comment |
|----------------|-------|---------|
| ProcessorID | 1 | REG_DWORD. Node id of the application processor (`dword_407BE0`), written as the source node of every packet sent. The query status is ignored: default 1 |
| NumTransports | ? | REG_DWORD. Number of transport subkeys `0`, `1`, …, `NumTransports-1`. 0: no transport. Missing: `EvtDriverDeviceAdd` returns the query error, so the device isn't started |

Transport subkeys `Parameters\0`, `Parameters\1`, … (all values are required. A subkey that can't be read is skipped, but if it's the last one its error status is returned by `EvtDriverDeviceAdd`):  
| Registry value | value | comment |
|----------------|-------|---------|
| Type | 0 | REG_DWORD. Must be 0 (SMD). Any other value: the subkey is skipped |
| Edge | ? | REG_DWORD. SMD edge (`smd_channel_type`), e.g. 0 = APPS↔MODEM, 1 = APPS↔QDSP, 6 = APPS↔RIVA |
| Flags | ? | REG_DWORD. SMD open flags. The driver adds 0x09 (bit 0x08 = MDL chains) before sending [internal IOCTL 0x22003](#internal-ioctl-0x22003) |
| FifoSize | ? | REG_DWORD. SMD FIFO size in bytes (0 = default 0x2000) |
| PortName | e.g. `IPCRTR` | REG_SZ. SMD channel name, converted to ANSI, at most 20 bytes |

Each subkey is stored in a 0x50-byte transport descriptor (pool tag `qir0`): `+0x00` WDFDEVICE, `+0x04` channel name (20 bytes), `+0x18` Edge, `+0x1C` Flags, `+0x20` FifoSize, `+0x24` PnP notification handle, `+0x28` "started" flag, `+0x2C`/`+0x30` list links.

There's no ETW provider. The only trace is `DbgPrintEx(0x4D, 0, "%s:%d: malloc failed\n", "rx_cb", 117)`.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Shared Memory Driver. One I/O target per transport subkey, opened when the interface `{F9D15453-8335-434C-AA72-FCD925F135F3}` arrives (`IoRegisterPlugPlayNotification`, one registration per transport). [internal IOCTL 0x22003](#internal-ioctl-0x22003), [internal IOCTL 0x22013](#internal-ioctl-0x22013), plus read/write requests |

### WDF setup

`sub_4093C4` (called by `EvtDriverDeviceAdd`):
- `WdfDeviceInitAssignName` `\Device\IPC`, the SDDL above, not exclusive, IO type `WdfDeviceIoDirect`.
- PnP/power callbacks: `EvtDeviceD0Exit` = `sub_4015A0` (returns `STATUS_SUCCESS`). `EvtDeviceSurpriseRemoval` = `sub_4015AC`, which calls `KeBugCheckEx(0x14E, 0x71697063 'qipc', 0, 0, 0)`: removing the device crashes the phone.
- File object callbacks: `EvtDeviceFileCreate` = `sub_4096DC` (creates the local port), `EvtFileClose` = `sub_40990C` (deletes the port).
- Device context cleanup `sub_4093AC`: unregisters the PnP notifications, then sends `Bye` on every transport and closes them (`sub_402730`).
- Device interface `{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`, the symbolic link `\DosDevices\IPC`, `WdfDeviceSetStaticStopRemove`.
- Default queue, parallel dispatch: `EvtIoRead` = `sub_409948`, `EvtIoWrite` = `sub_409AFC`, `EvtIoDeviceControl` = `sub_409BF4`.

Each `CreateFile` on `\Device\IPC` gets a `PORT_CONTEXT` on the WDF file object:  
| Offset | Content |
|--------|---------|
| 0x00 | WDFFILEOBJECT |
| 0x04 | Router port (0x54 bytes: `+0x00` port id, `+0x04` type (2 = user port), `+0x08` rx callback `sub_4010A4`, `+0x10` event callback `sub_40127C`, `+0x1C` tx quota = 5) |
| 0x08 | Mutex of the receive list |
| 0x28-0x30 | Receive list (head, tail, count): received packets not read yet |
| 0x34 | Mutex of the event list |
| 0x54-0x5C | Event list (head, tail, count): server/client notifications not read yet |
| 0x60 | Manual queue: pending `ReadFile` (never used, see [Read](#read--receive-a-packet)) |
| 0x64 | Manual queue: pending [IOCTL 0x122017](#ioctl-0x122017) |
| 0x68 | Manual queue: pending [IOCTL 0x122000](#ioctl-0x122000) and [IOCTL 0x12201B](#ioctl-0x12201b) |
| 0x6C | Flags. Bit 0x02 is set by [IOCTL 0x12201B](#ioctl-0x12201b). Bit 0x01 (read can wait) is never set |

The local port id is a global counter (`sub_4015F4`) starting at 1. 0 and ids already in use are skipped. The address of the port is `ProcessorID:port id`. If the port can't be created, `CreateFile` fails with `STATUS_INTERNAL_ERROR` (0xC00000E5).  
Closing the handle sends `Rem_client` (with the address of the port) on all transports, and removes the servers that the port had registered.

### Packet format

Every packet on an SMD channel starts with this header (`sub_402304` for data, `sub_401BF8` for control messages). The payload is padded to a multiple of 4 bytes:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version. Received packets with another version are dropped |
| 04-07 | ? | Message type, see the table below |
| 08-0B | ? | Source node id |
| 0C-0F | ? | Source port id. 0xFFFFFFFE (`IPC_ROUTER_ADDRESS`) for control messages |
| 10-13 | ? | Confirm RX: 1 when the receiver must answer with `Resume_tx` |
| 14-17 | ? | Payload size in bytes (20 for control messages) |
| 18-1B | ? | Destination node id |
| 1C-1F | ? | Destination port id (0xFFFFFFFE for control messages) |

Message types (the names are the strings of the table at `.rdata:0x00406110`):  
| Type | Name | Control payload (20 bytes, dwords) |
|------|------|------------------------------------|
| 0 | Invalid | — |
| 1 | Data | (not a control message: user payload) |
| 2 | Hello | 2, 0x0EA7BEEF, transport mask (1 for SMD), 0, 0 |
| 3 | Bye | 3, … |
| 4 | New_server | 4, service, instance, node id, port id |
| 5 | Rem_server | 5, service, instance, node id, port id |
| 6 | Rem_client | 6, node id, port id |
| 7 | Resume_tx | 7, node id, port id (of the receiver that read the packet) |

Processing of the received control messages (`sub_401AF0`):
- `Hello`: the remote node is attached to the transport. The router answers with its own `Hello` (if it hasn't sent one yet), then sends `New_server` for every server it knows (`sub_40174C`).
- `Bye` (and the SMD channel close event): every server and client of the remote node is removed. `Rem_server` / `Rem_client` are sent on the other transports and the local ports are notified (`sub_401850`).
- `New_server`, `Rem_server`, `Rem_client`: forwarded to the other transports, recorded, then the local ports are notified (event 1, 2 or 3).
- `Resume_tx`: clears the tx quota toward that remote port and notifies the local ports that were blocked (event 4).

Data packets whose destination node isn't the local node are forwarded on the transport of that node (`sub_401DE4`).

Flow control: each remote port has a quota of 5 unconfirmed packets (`sub_404B80`). The 5th packet is sent with Confirm RX = 1. Further writes fail with `STATUS_DEVICE_BUSY` until a `Resume_tx` comes back. When a local port reads a packet received with Confirm RX = 1, the router sends `Resume_tx` to the sender.

### SMD transport

For each transport subkey, the arrival of the SMD interface calls `sub_401544`, which creates the transport `"SMD"` (function table `off_407150`: open `sub_402A4C`, start `sub_403238`, close `sub_402D68`, write `sub_403304`) and sends `Hello`.
1. `sub_402A4C`: `WdfIoTargetOpen` on `\Device\SMD`, then [internal IOCTL 0x22003](#internal-ioctl-0x22003) (synchronous, no timeout) with the name, edge, flags and FIFO size of the registry and 3 events.
2. `sub_403238`: starts a system thread (`sub_4030C8`) that waits on the 3 events:
   - data received: [internal IOCTL 0x22013](#internal-ioctl-0x22013) gets the number of bytes available, then a read of that size (`sub_402DB4`). The packet is parsed by `sub_401F90`. This is repeated until the FIFO is empty.
   - channel opened by the remote side: if the link was down, `Hello` is sent again.
   - channel closed by the remote side: the link is marked down and the remote node is cleaned up as for `Bye`.
3. `sub_403304`: each packet is sent with an asynchronous write request whose IRP holds an MDL chain (header, payload, padding).

---

### Read : receive a packet

`ReadFile` on a port handle (`sub_409948`) returns the oldest received packet:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Source node id |
| 04-07 | ? | Source port id |
| 08-.. | ? | Payload |

- No packet waiting: completes at once with `STATUS_SUCCESS` and 0 bytes (bit 0x01 of the flags is never set, so a read never stays pending). Use [IOCTL 0x122017](#ioctl-0x122017) to wait for a packet.
- Buffer smaller than payload + 8: `STATUS_BUFFER_TOO_SMALL` (0xC0000023) with `Information` = required size. The packet stays in the list.
- No file object: `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

### Write : send a packet

`WriteFile` on a port handle (`sub_409AFC`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Destination node id |
| 04-07 | ? | Destination port id |
| 08-.. | ? | Payload |

- Less than 8 bytes: `STATUS_BUFFER_TOO_SMALL` (0xC0000023).
- Destination not known (no `New_server`/`Hello` seen for that node:port): `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).
- Tx quota reached: `STATUS_DEVICE_BUSY` (0x80000011). The packet is **not** sent: write it again after event `Resume_tx` ([IOCTL 0x122000](#ioctl-0x122000), type 0).
- A destination on the local node is delivered directly to the other port, without a transport.

---

### IOCTL 0x122000

This IOCTL is processed by Qcipcrouter8930.sys  
This IOCTL is also sent by [qcremotefs8930.sys](./qcremotefs8930.md#ioctl-0x122000)  

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the next server/client event | 0 | 20 (exact) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Event: 1 = `New_server`, 2 = `Rem_server`, 3 = `Rem_client`, 0 = `Resume_tx` |
| 04-07 | ? | Types 1/2: service. Types 3/0: node id |
| 08-0B | ? | Types 1/2: instance. Types 3/0: port id |
| 0C-0F | ? | Types 1/2: node id |
| 10-13 | ? | Types 1/2: port id |

The oldest event of the port is returned. If there is none, the request is pended in the queue +0x68 and completed by the event callback `sub_40127C` when the next event arrives. After [IOCTL 0x12201B](#ioctl-0x12201b), a request with no event waiting completes at once with 0 bytes.  
OutputBuffer ≠ 20 bytes: `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### IOCTL 0x122004

This IOCTL is processed by Qcipcrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Check that a server exists | 12 (exact) | 16 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Service |
| 04-07 | ? | Instance |
| 08-0B | ? | Instance mask: a server matches when `(instance & mask) == (server instance & mask)` |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Service (copy of the input) |
| 04-07 | ? | Instance (copy of the input) |
| 08-0B | 10 00 00 00 | OutputBuffer length (16) |
| 0C-0F | ? | Not initialised (4 bytes of kernel stack) |

`sub_4041C0` only searches the server table. It doesn't return the address of the server: use [IOCTL 0x122008](#ioctl-0x122008) for that.  
Not found: `STATUS_NOT_FOUND` (0xC0000225).

---

### IOCTL 0x122008

This IOCTL is processed by Qcipcrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Lookup servers | 16 (exact) | 8 + 16 × MaxEntries (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Service |
| 04-07 | ? | Instance |
| 08-0B | ? | Instance mask (as for [IOCTL 0x122004](#ioctl-0x122004)) |
| 0C-0F | ? | MaxEntries. 0 = only count the servers |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Number of matching servers |
| 04-07 | ? | Number of entries returned (≤ MaxEntries) |
| 08-0B | ? | Entry 0: service |
| 0C-0F | ? | Entry 0: instance |
| 10-13 | ? | Entry 0: node id |
| 14-17 | ? | Entry 0: port id |
| … | | Next entries, 16 bytes each |

Backend `sub_4025C4`. `Information` = 8 + 16 × entries returned.  
No matching server: `STATUS_NOT_FOUND` (0xC0000225). Allocation failure: `STATUS_NO_MEMORY` (0xC0000017).

---

### IOCTL 0x12200C

This IOCTL is processed by Qcipcrouter8930.sys  
This IOCTL is also sent by [qcremotefs8930.sys](./qcremotefs8930.md#ioctl-0x12200c)  

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Register a server | 8 (exact) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Service |
| 04-07 | ? | Instance |

`sub_4024AC`: records the server `service:instance` at the address of the port, notifies the local ports (event 1), and sends `New_server` on all transports.  
Already registered at this address, or failure: `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). `Information` = 8.

---

### IOCTL 0x122010

This IOCTL is processed by Qcipcrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Unregister a server | 8 (exact) | 0 |

Inputbuffer: same as [IOCTL 0x12200C](#ioctl-0x12200c).

`sub_40253C`: removes the server, notifies the local ports (event 2), and sends `Rem_server` on all transports.  
Not registered: `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### IOCTL 0x122017

This IOCTL is processed by Qcipcrouter8930.sys  
This IOCTL is also sent by [qcremotefs8930.sys](./qcremotefs8930.md#ioctl-0x122017)  

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x805 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Wait for a packet | 0 | 0 |

No buffer is used. If a packet is waiting, the IOCTL completes at once with `Information` = payload size + 8, i.e. the buffer size needed by the next `ReadFile`. Otherwise it's pended in the queue +0x64 and completed the same way by the rx callback (`sub_4010A4`) when a packet arrives.

---

### IOCTL 0x12201B

This IOCTL is processed by Qcipcrouter8930.sys  
This IOCTL is also sent by [qcremotefs8930.sys](./qcremotefs8930.md#ioctl-0x12201b)  

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x806 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Stop waiting for events ? | 0 | 0 |

Sets bit 0x02 of the port flags: from then on, [IOCTL 0x122000](#ioctl-0x122000) doesn't wait any more. If no event is waiting, the request itself is pended in the event queue (+0x68). The next event completes it with `STATUS_SUCCESS` and `Information` = 20, without writing anything to a buffer. The event stays in the list. If an event is already waiting, the IOCTL completes at once with `Information` = 20.

---

### internal IOCTL 0x22003

This IOCTL is sent by Qcipcrouter8930.sys to qcsmd8930.sys (`sub_402A4C`). See [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003).

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Open a SMD channel | \Device\SMD | 28 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the ANSI channel name (`PortName` of the registry) |
| 04-07 | ? | `Edge` of the registry |
| 08-0B | ? | `Flags` of the registry OR 0x09 |
| 0C-0F | ? | `FifoSize` of the registry |
| 10-13 | ? | `PKEVENT` data received (transport +0x28) |
| 14-17 | ? | `PKEVENT` channel opened (transport +0x38) |
| 18-1B | ? | `PKEVENT` channel closed (transport +0x48) |

---

### internal IOCTL 0x22013

This IOCTL is sent by Qcipcrouter8930.sys to qcsmd8930.sys (`sub_402F98`). See [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22013).

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Read status | \Device\SMD | 0 | 0 |

Sent synchronously with no buffer. `Information` = number of bytes available in the receive FIFO. A read request of that size follows.

---

### Interface GUID

IPC Router Interface Class GUID  
`{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`

### Other GUID

SMD interface of [qcsmd8930.sys](./qcsmd8930.md) (PnP notification target)  
`{F9D15453-8335-434C-AA72-FCD925F135F3}`
