## Cellnetmon.sys

Cellular pipe monitor (Microsoft, WP8.1 "cellcore", KMDF).  
It is a KMDF **filter** (`WdfFdoInitSetFilter`) that sits on a cellular pipe, between [cellmux.sys](./cellmux.md) (above) and the device that provides the pipe (below, probably [cellusermodeinterconnect.sys](./cellusermodeinterconnect.md)). It consumes the pipe query-interface `{B9086F29-6065-4DBE-8C90-3CD560547957}` of the device below and exposes the same interface to the driver above, so every packet between cellmux and the modem goes through it. The packets it sees still carry the 4-byte [mux header](./cellmux.md#mux-header-and-packet-types), so it is a lower filter of the cellmux FDO.  
For each packet of mux **queue 1** it makes a copy, zeroes the personal data (PII) fields of the RIL messages it knows, and:  
- writes the copy as an ETW event (when the provider is enabled);  
- sends the copy to a TCP client connected on **port 257**, when monitoring was started with [IOCTL 0x6E800C](#ioctl-0x6e800c--set-configuration).  

Source tree: `src\net\cellcore\product\emb\cellnetmon\` (`drivermain.c`, `filter.c`, `socket.c`) + `cellkernellib\` (`synchronizer.c`, `utility.c`). PDB: `cellnetmon.pdb`. Built Jan 23 2015 18:13:45 (one second after cellmux.sys). Driver pool tag `MdmN` (0x4E6D644D), allocations `Cell` (0x6C6C6543, NonPagedPoolNx). Imports `NETIO.SYS` (Winsock Kernel). No hardware access.

There's no named `\Device\` object and no device interface. The filter's only entry point from outside is [IOCTL 0x6E800C](#ioctl-0x6e800c--set-configuration), which reaches it through cellmux: the cellmux FDO forwards every IOCTL other than 0x716D8004 to its lower device.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\CellNetmon`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CellNetmon\Parameters`:  
| Registry value | value | comment |
|----------------|-------|---------|
| ZeroPIIData | 1 | REG_DWORD (type-checked). Read once in `DriverEntry` (`RtlQueryRegistryValuesEx`, `RTL_REGISTRY_SERVICES`, `CellNetmon\Parameters`) into `dword_1000601C`, default 1. Copied to each filter at start; non-zero = zero the PII fields of the copies. Can be changed per device with [IOCTL 0x6E800C](#ioctl-0x6e800c--set-configuration) |

`DriverEntry` (sub_10002448) refuses to load (`Refusing to load due to Abort flag`, STATUS_UNSUCCESSFUL 0xC0000001) if the global at `.data:0x10006748` is non-zero. This global is read only; nothing in the driver writes it.  
The result of the registry query is ignored. `DriverEntry` returns the `EtwRegister` status.

GUID of the ETW provider (traffic copy):  
`{3EA8C7A0-B9BB-4FC6-B2DB-F322CB1856C8}`  
Registered in `DriverEntry`, unregistered in `DriverUnload` (sub_100025AC). One event (`EventDescriptor` at `.text:0x100018F0`): Id 1, version 0, channel 0x10, level 4, opcode 0, task 100, keyword 0x8000000000000001. The payload is one data descriptor: the [PII-safe buffer](#pii-safe-buffer) (8-byte header + packet). It is written only for queue 1 packets and only if `EtwEventEnabled` (sub_10003860).

GUID of the ETW provider (fatal error):  
`{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}` (`Microsoft-WindowsPhone-Net-Debug`)  
Same `CellFatalError` as [cellmux.sys](./cellmux.md) (sub_10002A78, misnamed `McGenEventUnregister` by IDA): `DbgPrintEx` `Fatal Error (0x%08X) in kernel mode at api (%s) in file (%s) at line (%d)`, `EtwWrite` of `NET_FATAL_ERROR` (event 100, level 2, task 1, keyword 0x1), then `DbgBreakPointWithStatus(5)` if a kernel debugger is attached, **`__fastfail(7)`** otherwise.  
Debug messages go to `DbgPrintEx` (component id 0x31, prefix `CellNetmon!`).

> [!NOTE]
> Many errors are fatal: a failed WDF call, `WskRegister` / `WskCaptureProviderNPI` failure, a `WskBind` / `WskAccept` / `WskSend` / `WskReceive` / `WskCloseSocket` call that fails at once, a packet received in a wrong state. A failed pool allocation or a too-small IOCTL buffer hits `__debugbreak()`. Without a debugger, each of these **crashes the phone**.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device (pipe provider) | [cellusermodeinterconnect.sys](./cellusermodeinterconnect.md) PDO ? | `WdfFdoQueryForInterface` `{B9086F29-6065-4DBE-8C90-3CD560547957}`, size 28, version 1 (0xC0000000 accepted as success, like cellmux) |
| Upper device (pipe consumer) | [cellmux.sys](./cellmux.md) FDO | Queries `{B9086F29-…}` from the filter (`WdfDeviceAddQueryInterface`, `FilterHandleQueryInterface` sub_100035F0). Forwards [IOCTL 0x6E800C](#ioctl-0x6e800c--set-configuration) to the filter |
| WSK provider | `netio.sys` / `afd`, TCP/IP | `WskRegister`, `WskCaptureProviderNPI` (`WSK_NO_WAIT`), TCP listen socket on `0.0.0.0:257` |
| TCP client | ? (PC tool on USB network / Wi-Fi ?) | Receives the [PII-safe buffers](#pii-safe-buffer). Whatever it sends is only read to detect the disconnection |

### Filter device

`FilterDeviceAdd` (sub_10002828): `WdfFdoInitSetFilter`, `WdfDeviceCreate` with context `FILTER_DATA` (0x118 bytes), cleanup callback `FilterCleanupDevice` (sub_10002614), synchronization scope device. One default sequential queue whose `EvtIoDeviceControl` is `FilterIoDeviceControl` (sub_10002758). Then `FilterInitialize` (sub_100033EC).

Context `FILTER_DATA`:  
| Offset | Comment |
|--------|---------|
| 0x00-0x23 | Synchronizer (`cellkernellib`, same code as cellmux): spinlock, pending work list, free list (max 5 cached entries), busy flag at 0x18, WDFDEVICE at 0x24 |
| 0x28-0x3B | Context given to the wrappers called from below: self, self, `FilterReceivePacketFromBelow` (sub_100039A0), `FilterReturnPacketFromBelow` (sub_10003A78), `FilterPipeBrokenFromBelow` (sub_10003760) |
| 0x3C | WDFDEVICE |
| 0x40 / 0x44 | Socket list (head / tail): packets waiting to be sent on the socket |
| 0x48 | Listen socket |
| 0x4C | Client (accepted) socket |
| 0x50 | Client socket state: 0 none, 3 accepting, 2 connected, 4 closing |
| 0x54 | Listen socket state: 0 none, 1 starting (work item), 3 creating / binding, 2 listening, 4 closing |
| 0x58 | Receive pending on the client socket |
| 0x5C-0x67 | `WSK_BUF` of the send (MDL, offset, length) |
| 0x68-0x73 | `WSK_BUF` of the receive (4 bytes) |
| 0x74 | 4-byte receive buffer |
| 0x78 | ZeroPIIData |
| 0x7C-0x97 | Pipe interface returned to the upper driver (28 bytes) |
| 0x98-0xB3 | Pipe interface of the lower device (28 bytes) |
| 0xB4-0xC3 | Upper driver's entries (`InterfaceSpecificData`: context, `ReceivePacket`, `ReturnPacket`, `PipeBroken`) |
| 0xC4 | State: 0 not started, 1 open, 2 breaking, 3 broken |
| 0xC8 / 0xCC / 0xD0 | Broken from above / from below / in cleanup |
| 0xD4 / 0xD8 | Packets given to the upper driver and not returned / packets given to the lower device and not returned |
| 0xDC | WSK registered |
| 0xE0-0xEF | `WSK_REGISTRATION` |
| 0xF0-0xF7 | `WSK_CLIENT_NPI` (context 0, dispatch `.text:0x10001468`: version 0x0100, no `WskClientEvent`) |
| 0xF8-0xFF | `WSK_PROVIDER_NPI` (client, dispatch) |
| 0x100 | Listen socket dispatch passed to `WskSocket` (all zero: no callbacks) |
| 0x104 | KEVENT set when the state reaches broken |

### Pipe interface and packet flow

Interface returned to the upper driver (`{B9086F29-…}`, layout in [cellmux.sys](./cellmux.md#pipe-interface)):  
| Bytes | Comment |
|-------|---------|
| 00-01 | Size = 28 |
| 02-03 | Version = 1 |
| 04-07 | Context = `FILTER_DATA` |
| 08-0B / 0C-0F | InterfaceReference / InterfaceDereference: no-op (sub_10003BAC) |
| 10-13 | `SendPacket` = `FilterReceivePacketFromAbove` (sub_100038FC) |
| 14-17 | `ReturnPacket` = `FilterReturnPacketFromAbove` (sub_10003A40): calls the lower `ReturnPacket` |
| 18-1B | `BreakPipe` = sub_10003750 (broken from above) |

`FilterHandleQueryInterface` stores the upper entries, moves the state to 1 (a second query breaks the filter) and returns **0xC0000000**, the same private convention as cellmux.

Packet path, in both directions (all callbacks are serialised through the synchronizer):  
1. A packet arrives (from above: `SendPacket`, direction code 1; from below: `ReceivePacket`, direction code 3). In state 2 (breaking) it is returned at once. In any other state than 1 it is a fatal error.  
2. ETW copy (sub_10003860), see above. The not-returned counter of the destination side is incremented.  
3. The packet descriptor is tagged: offset 0x14 = 1 if from above / 0 if from below, 0x18 = `FILTER_DATA`, 0x1C = next in the socket list, 0x20 = buffer being sent. It is appended to the socket list (`SocketWriteSync` sub_100041A4).  
4. If no client is connected, the list is passed on at once: packets from above go to the lower `SendPacket`, packets from below to the upper `ReceivePacket`.  
5. If a client is connected, `SendPacketOnSocket` (sub_10003FAC) builds the [PII-safe buffer](#pii-safe-buffer) and sends it with `WskSend` (flags `WSK_FLAG_NODELAY`). Only when the send completes (`SendIrpComplete` sub_100045A0) is the packet passed on (`SocketFinishedWithPacket` sub_100044CC) and the next one sent. A send error closes the client socket.  

> [!NOTE]
> While a client is connected, the cellular traffic goes only as fast as the TCP client reads it: one packet at a time, each one waiting for its `WskSend` to complete.  
> If a packet that is **not** for queue 1 arrives while a client is connected, `SendPacketOnSocket` frees the copy and returns without passing the packet on and without moving to the next entry. The packet stays at the head of the socket list. Everything queued behind it is then blocked, in both directions. Nothing seems to flush the list when the client disconnects ?

Breaking (`FilterEnterBreakingState` sub_100036E8, flag 0 from above, 1 from below, 2 second query, 3 cleanup): state → 2, stop listening, call the lower `BreakPipe` and the upper `PipeBroken`. State 3 (broken, event set) is reached when the pipe is broken from below, and from above or in cleanup, with no packet outstanding, no socket left and no receive pending (`FilterAdvanceBreakingStateIfNeeded` sub_10003AB0). WSK is deregistered as soon as both sockets are gone. `FilterCleanupDevice` breaks the filter (flag 3) and waits for the event.

### Socket

1. `FilterStartListening` (sub_10004234, from [IOCTL 0x6E800C](#ioctl-0x6e800c--set-configuration)): listen state → 1. The first time, it creates a WDF work item (context `START_LISTENING_CONTEXT`, 4 bytes) whose callback `RegisterWithWinsock` (sub_100042E8) calls `WskRegister` and `WskCaptureProviderNPI(WSK_NO_WAIT)`. A failure is fatal, so this crashes if the WSK subsystem isn't ready.  
2. `WskSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, WSK_FLAG_LISTEN_SOCKET)` (sub_10004398).  
3. `CreateListeningSocketComplete` (sub_10003D70): `WskBind` to `sockaddr_in` {family 2, port bytes `01 01` = **257**, address `0.0.0.0`}. The socket listens on **every interface**, without any authentication.  
4. `BindComplete` → `SocketStartAcceptSync` (sub_10003E4C): `WskAccept`. Only one client at a time.  
5. `AcceptComplete` → client state 2, `StartReadOperationOnSocket` (sub_100040E0): `WskReceive` of 4 bytes. The data is ignored. When the receive completes, for any reason (data, close, error), the client socket is closed (`BreakClientSocket` sub_10004448) and a new `WskAccept` starts.  
6. Stop ([IOCTL 0x6E800C](#ioctl-0x6e800c--set-configuration) command 2, or breaking): the client socket and the listen socket are closed (`WskCloseSocket`).

### PII-safe buffer

Built by `CreatePIISafeBuffer` (sub_10003770) for each packet. Sent as is on the TCP socket (length = packet length + 8) and as the ETW payload. There's no other framing.  
| Bytes | Comment |
|-------|---------|
| 00-03 | Packet length (total length, chained packets included) |
| 04-07 | Direction: 1 = from above (cellmux → modem), 3 = from below (modem → cellmux) |
| 08-09 | Mux queue number. Only queue 1 is monitored |
| 0A-0B | Mux packet type (3 = data, see [cellmux.sys](./cellmux.md#mux-header-and-packet-types)) |
| 0C-0F | Message kind: 3, 0x80000003 or 7 (other values: no PII filtering) |
| 10-33 | ? |
| 34-37 | RIL message code (`v12[11]`) |
| 38-3B | Kind 0x80000003: PII filtered only if this DWORD is 2. Kind 7: start of the message data |
| 3C- | Kind 3 / 0x80000003: start of the message data |

The copy of the packet data is filtered only if ZeroPIIData is set, the mux type is 3, the payload is at least 12 bytes and the kind is 3, 7 or 0x80000003 (`ZeroPIIFields` sub_10002B8C). The queue 1 traffic is the RIL protocol of [msril.sys](./msril.md#pipe-protocol) ? (kind 3 = commands, 0x80000003 = responses, 7 = notifications; the code ranges are the same as the msril capability tables):  
| Kind | Codes handled | Comment |
|------|---------------|---------|
| 3, 0x80000003 | 0x05-0x76, 0x400-0x404 | For each code: a minimum (or exact) data size and the fields to zero (fixed strings of 256 / 500 / 512 bytes, counted WCHAR arrays, variable-length data). Some codes have different rules for kind 3 and kind 0x80000003. Some have no PII and are kept |
| 7 | 0x10000100-0x10000131 | Same, e.g. 0x10000118 (size 1628 or 2336, two 512-byte fields), 0x1000011E (≥ 0x8D8) |

If the code is unknown for the kind, or the data is too small or has an inconsistent length field, the whole data is zeroed. Helpers: sub_10003BB8 (records with a sub-type 0x10001 / 0x10002 / 0x10008 / 0x10020 at offset 0x228), sub_10003C8C (counted WCHAR string), sub_10003CD0 (array of 1628- or 2336-byte records).

---

### IOCTL 0x6E800C — Set configuration

This IOCTL is processed by Cellnetmon.sys (`FilterIoDeviceControl` sub_10002758 → `FilterSetConfigurationSettings` sub_10002924, run through the synchronizer). It reaches the filter through [cellmux.sys](./cellmux.md), which forwards it to its lower device.

| Property | Value |
|----------|-------|
| Device | 0x6E |
| Function | 0x3 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set configuration (start/stop the socket, PII filtering) | 8 | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Socket: 1 = start listening on TCP port 257 (if not already started), 2 = stop (close the client and the listen socket), other = no change |
| 04-07 | 01 00 00 00 | ZeroPIIData: 1 = on, 2 = off, other = no change |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Socket: 1 = started, 2 = stopped (2 right after a stop command) |
| 04-07 | 01 00 00 00 | ZeroPIIData: 1 = on, 2 = off |

The request is completed with STATUS_SUCCESS and information = 8. A buffer smaller than 8 bytes gives a debug message and `__debugbreak()` (the request isn't completed); any other `WdfRequestRetrieve*Buffer` error is fatal. Any other IOCTL is completed with STATUS_INVALID_DEVICE_REQUEST (0xC0000010) ("Unknown IOCTL"); unlike cellmux, the filter doesn't forward unknown IOCTLs to its lower device.  
The sender is unknown (a user-mode diagnostic tool or service that opens the cellmux interface `{2B70CD07-AED0-465B-A808-22C3CC914A30}` ?).

---

### Other GUID

Cellular pipe query-interface (consumed from the lower device, exposed to the upper driver)  
`{B9086F29-6065-4DBE-8C90-3CD560547957}`
