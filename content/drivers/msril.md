## Msril.sys

Microsoft RIL (Radio Interface Layer) kernel driver (WP8.1 "cellcore", KMDF).  
It is a cellular **pipe client** (consumer of the query-interface `{B9086F29-6065-4DBE-8C90-3CD560547957}`, see [cellmux.sys](./cellmux.md#pipe-interface)). It turns the pipe into a device that several user-mode clients can open. A client sends RIL commands with `WriteFile` and gets the responses and the notifications with `ReadFile`. Msril checks a set of `ID_CAP_CELL_API_*` capabilities for every command and every notification. It adds a transaction id to each command, matches the responses from the modem side to the pending commands, and copies each notification to all the clients that enabled it.  
Source tree: `src\net\cellcore\product\ril\msril\` (`drivermain.c`, `msril.c`, `client.c`, `service.c`) + `src\net\cellcore\product\emb\cellkernellib\` (`synchronizer.c`, `utility.c`). PDB: `msril.pdb`. Driver name string `MSRil`. Allocations `Cell` (0x6C6C6543, NonPagedPoolNx, 5 tries before a fatal error) and `Secr` (0x72636553, PagedPool, capability check). No hardware access, no IOCTL.

The device is probably the function driver of a [cellmux.sys](./cellmux.md) queue PDO: it queries the pipe interface from its parent with `WdfFdoQueryForInterface` and accepts the private 0xC0000000 status of the cellmux providers as success. The hardware ID of the queue PDO is chosen by the sender of [IOCTL 0x716D8004](./cellmux.md#ioctl-0x716d8004--create-queue), so the binding can't be confirmed from the binaries. The traffic matches the queue 1 messages that [cellnetmon.sys](./cellnetmon.md) filters (kinds 3, 0x80000003 and 7, same code ranges).

There's no named `\Device\` object. The FDO registers the device interface `{47CA0628-71C1-4BE1-8FFB-503201FEAD27}` (no reference string). Clients open it with `CreateFile`.

There's no parameters in the registry. The only registry access is the capability lookup in `HKLM\Software\Microsoft\SecurityManager\Capabilities\<capability>` (see [Capabilities](#capabilities)).

GUID of the ETW provider:  
`{39E95AD8-E195-4890-B512-6DEDE1E2C9F1}`  
Registered in `DriverEntry` (`McGenEventRegister` sub_10002C9C), unregistered in `EvtDriverUnload`. Events for entry/exit of the callbacks, state changes, protocol errors, denied commands and command latency.  
The fatal error routine (`McGenEventUnregister_0` sub_10002A28, misnamed by IDA) is the same as `CellFatalError` of [cellmux.sys](./cellmux.md#guid-of-the-etw-provider): `DbgPrintEx` (component 0x31) of `Fatal Error (0x%08X) in kernel mode at api (%s) in file (%s) at line (%d)`, one `EtwWrite` on `{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}` (`Microsoft-WindowsPhone-Net-Debug`), then `DbgBreakPointWithStatus` with a debugger, **bugcheck** without. It is called when a WDF call fails, when an allocation fails 5 times, and for some protocol errors from the modem side (see [Pipe protocol](#pipe-protocol)).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Parent device (lower stack of the FDO) | [cellmux.sys](./cellmux.md) queue PDO ? | `WdfFdoQueryForInterface` `{B9086F29-6065-4DBE-8C90-3CD560547957}`, size 28, version 1. See [Pipe protocol](#pipe-protocol) |
| — | ? (user mode, RIL client) | Opens interface `{47CA0628-…}`, `WriteFile` commands, `ReadFile` responses and notifications. See [Client messages](#client-messages) |

### Initialisation

`EvtDriverDeviceAdd` (sub_100027AC):
1. File object config: `EvtDeviceFileCreate`, `EvtFileCleanup`, `EvtFileClose`, class `WdfFileObjectWdfCannotUseFsContexts`, context `CLIENT_DATA`.
2. `WdfDeviceCreate` with context `MSRIL_DATA`, synchronization scope device, passive execution level.
3. Default parallel queue with `EvtIoRead` (sub_100031BC) and `EvtIoWrite` (sub_10003200). No `EvtIoDeviceControl`.
4. Synchronizer (`cellkernellib`, at `MSRIL_DATA`+0xB8): all the work of the service and the clients is serialised through it (`SynchronizerRun` sub_100056F0), like in cellmux.
5. `ServiceInitialize` (sub_10005018): queries the pipe interface, then sends the [open packet](#pipe-protocol) and **waits without timeout** until the open succeeds or the pipe breaks. So `EvtDriverDeviceAdd` blocks until the modem side answers.
6. `WdfDeviceCreateDeviceInterface` `{47CA0628-…}`.

`MSRIL_DATA` context (partial):  
| Offset | Comment |
|--------|---------|
| 0x00 | List of the clients (`CLIENT_DATA`) |
| 0x10 | Service (pipe side) |
| 0x18 | Service state: 0 not started, 1 opening, 2 open, 3 breaking, 4 broken |
| 0x1C | Event set when the open is finished (state 2 or 3) |
| 0x2C | Event set when the state reaches 4 (waited for by the device cleanup, sub_1000263C) |
| 0x3C | Pipe broken from below |
| 0x40 | Packets given to the pipe and not returned yet |
| 0x44 | Pending commands count |
| 0x48 | Packet dispatcher (`ServiceDispatch` sub_10004F44) |
| 0x50-0x63 | Context given to the pipe wrappers: synchronizer, service, `ReceivePacket` sub_10004228, `ReturnPacket` sub_1000442C, `PipeBroken` sub_100043E4 |
| 0x64-0x7F | Pipe interface (28 bytes): context at 0x68, `SendPacket` at 0x74, `ReturnPacket` at 0x78, `BreakPipe` at 0x7C |
| 0x80 | List of the pending commands |
| 0x88 | Transaction id counter (31 bits, never 0) |
| 0x90 / 0x98 | Packets sent / received (64-bit) |
| 0xA0 | `KeQueryTimeIncrement` |
| 0xA8 / 0xB0 | Maximum send time / maximum response time (ms, 64-bit) |
| 0xB8 | Synchronizer |

### Capabilities

`EvtDeviceFileCreate` (sub_10002DC8) computes the capability mask of the caller (sub_100055F0) and stores it in the client context. The check (sub_10007000) is the same algorithm as in [kbdclasswp.sys](./kbdclasswp.md) and [SecRuntime.dll](../libraries/secruntime.md): `RtlCheckTokenCapability` with the `ApplicationCapabilitySID` of `HKLM\Software\Microsoft\SecurityManager\Capabilities\<capability>` for an AppContainer token; otherwise LocalSystem, then `RtlCheckTokenMembership` with the `ServiceCapabilitySID`, then membership of `S-1-5-21-2702878673-795188819-444038987-1030`.  
| Bit | Capability |
|-----|------------|
| 0x001 | `ID_CAP_CELL_API_COMMON` |
| 0x002 | `ID_CAP_CELL_API_UICC` |
| 0x004 | `ID_CAP_CELL_API_UICC_LOWLEVEL` |
| 0x008 | `ID_CAP_CELL_API_TELEPHONY` |
| 0x010 | `ID_CAP_CELL_API_MESSAGING` |
| 0x020 | `ID_CAP_CELL_API_ADMIN` |
| 0x040 | `ID_CAP_CELL_API_LOCATION` |
| 0x080 | `ID_CAP_CELL_API_OEM_PASSTHROUGH` |
| 0x100 | `ID_CAP_CELL_API_MODEMLOGGING` |

The open itself never fails on capabilities (a client with mask 0 can open the device but every command is denied). The open fails with `STATUS_INVALID_DEVICE_STATE` (0xC0000184) if the service isn't open (state ≠ 2).

Capability required for each command code (`CommandAllowed` sub_100054F8). A command is accepted if the client has **one** of the bits:  
| Command codes | Bits |
|---------------|------|
| 0x03-0x07, 0x0C, 0x0D, 0x25, 0x27, 0x29, 0x2B-0x2D | 0x001 COMMON |
| 0x0F, 0x12-0x16, 0x1B, 0x1C, 0x1E-0x22, 0x5E-0x60, 0x6B-0x6D | 0x002 UICC |
| 0x10, 0x17-0x1A, 0x1D, 0x61-0x63, 0x6A | 0x004 UICC_LOWLEVEL |
| 0x23, 0x31-0x33, 0x38-0x3A, 0x3D-0x45, 0x64, 0x65, 0x6F-0x71 | 0x008 TELEPHONY |
| 0x34-0x37, 0x3B, 0x3C | 0x088 TELEPHONY or OEM_PASSTHROUGH |
| 0x46-0x51, 0x69 | 0x010 MESSAGING |
| 0x52 | 0x090 MESSAGING or OEM_PASSTHROUGH |
| 0x08-0x0B, 0x0E, 0x11, 0x24, 0x26, 0x28, 0x2A, 0x2F, 0x30, 0x66-0x68, 0x72-0x76 | 0x020 ADMIN |
| 0x53 | 0x040 LOCATION |
| 0x400-0x404 | 0x100 MODEMLOGGING |
| 0x00-0x02, 0x2E, 0x54-0x5D, 0x6E, 0x77-0x3FF, > 0x404 | 0x080 OEM_PASSTHROUGH |

Capability required for each notification code (`NotificationAllowed` sub_1000547C):  
| Notification codes | Bits |
|--------------------|------|
| 0x10000101, 0x10000104-0x10000106, 0x1000010D, 0x1000010E, 0x10000111, 0x10000114, 0x10000115, 0x10000130 | 0x001 COMMON |
| 0x10000102, 0x10000103, 0x10000107-0x1000010B, 0x10000125, 0x10000127 | 0x002 UICC |
| 0x1000010C, 0x1000010F, 0x10000117-0x10000121, 0x10000126, 0x10000129-0x1000012D | 0x008 TELEPHONY |
| 0x10000122, 0x10000123, 0x10000128 | 0x010 MESSAGING |
| 0x10000124 | 0x090 MESSAGING or OEM_PASSTHROUGH |
| 0x10000100, 0x10000110, 0x10000112, 0x10000113, 0x10000116, 0x1000012E, 0x1000012F | 0x020 ADMIN |
| 0x10000000-0x100000FF, 0x10000131 | 0x080 OEM_PASSTHROUGH |

Valid notification codes are 0x10000000-0x10000131 (one enable byte per code in the client context).

### Clients

`CLIENT_DATA` (file object context, initialised by sub_100034B0):  
| Offset | Comment |
|--------|---------|
| 0x00 | List entry in `MSRIL_DATA` |
| 0x08 | Client id (counter) |
| 0x0C | State: 0 active, 1 closing, 2 closed, 3 stalled |
| 0x10 | `MSRIL_DATA` |
| 0x14 | Manual queue of the pending reads |
| 0x18 | List of the messages waiting for a read, count at 0x20 |
| 0x24 | Commands sent and not yet returned by the pipe |
| 0x28 | Event set when the state reaches 2 (waited for by `EvtFileCleanup`) |
| 0x38 | WDFFILEOBJECT |
| 0x3C | Capability mask |
| 0x40 | Tick count of the last read (64-bit) |
| 0x48 | Bytes waiting in the message list |
| 0x4C-0x17D | Enabled notifications, 1 byte per code (index = code − 0x10000000) |

A client that doesn't read is cut off (sub_10003610): if more than 1 MB (0x100000 bytes) is waiting and the last read is older than 10 minutes (600000 ms), the state becomes 3. The reads and writes of the client then fail with `STATUS_CANCELLED` (0xC0000120), and its new messages are dropped.  
`EvtFileCleanup` (sub_10002F68) removes the client from the list, detaches its pending commands (their responses will be dropped), completes the pending reads with `STATUS_CANCELLED`, frees the waiting messages and waits until all its commands are returned by the pipe. When the pipe breaks, every client goes the same way.

### Client messages

All the messages are little-endian DWORDs. The first DWORD is the message type.

**Write: command (type 3).** `EvtIoWrite` (sub_10003200). Length 12 to 15328 (12 + 0x3BD4) bytes, else `STATUS_INVALID_PARAMETER` (0xC000000D).  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | Type: command. Other values → `STATUS_INVALID_PARAMETER` |
| 04-07 | ? | Command code. Not allowed by the capabilities → `STATUS_ACCESS_DENIED` (0xC0000022) |
| 08-0B | ? | Client context (not sent to the modem, given back in the response) |
| 0C- | ? | Command data (length − 12 bytes) |

Command 3 is handled by msril (see below). The others are sent on the pipe (`ServiceSendCommand` sub_100048A4): the write is pended and completed with `STATUS_SUCCESS` and Information = the write length when the pipe returns the packet (sub_10004D70), so before the response arrives. It fails with `STATUS_DEVICE_NOT_READY` (0xC00000A3) if the service isn't open.

**Write: command 3 "Enable notifications"** (sub_100036D4). Handled by msril, not sent to the modem.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | Type: command |
| 04-07 | 03 00 00 00 | Command code 3 (needs `ID_CAP_CELL_API_COMMON`) |
| 08-0B | ? | Client context |
| 0C-0F | ? | Count N |
| 10- | ? | N notification codes (DWORD each) |

The length must be exactly 16 + 4 × N. A code outside 0x10000000-0x10000131 → `STATUS_INVALID_PARAMETER`, a code not allowed by the capabilities → `STATUS_ACCESS_DENIED`. In both cases no code is enabled. On success all the codes are enabled (there's no way to disable one), the write completes with the write length, and msril queues a response `04 00 00 00` `01 00 00 00` `03 00 00 00` + client context (16 bytes) to the client.

**Read.** `EvtIoRead` (sub_100031BC → sub_10003B6C). Returns one whole message per read. If the output buffer is smaller than the next message → `STATUS_BUFFER_TOO_SMALL` (0xC0000023), and the message stays queued. If no message is waiting, the read is put in the client's queue and completed when a message arrives (sub_10003860).

Response (type 4):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 04 00 00 00 | Type: response |
| 04-07 | 01 00 00 00 | Status (1 = success ?, other values are logged as failed commands) |
| 08-0B | ? | Command code |
| 0C-0F | ? | Client context from the command |
| 10- | ? | Response data |

Notification (type 5):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 05 00 00 00 | Type: notification |
| 04-07 | ? | Notification code (0x10000000-0x10000131) |
| 08- | ? | Notification data |

A notification is given only to the clients that enabled the code with command 3 **and** have the capability for it.

### Pipe protocol

Msril uses its own messages inside the cellmux data packets. Every packet is allocated with 52 bytes of descriptor + 32 bytes of headroom, like in cellmux. The first DWORD is the message kind (the 0x80000000 bit marks a response from the modem side). Every received packet is returned to the pipe at once after processing (`ServiceReceivePacket` sub_10004228).  
RIL GUID (checked in every response and notification):  
`{71564B71-6F61-4510-861F-7C9CBCC229E9}`

| Kind | Direction | Name | Comment |
|------|-----------|------|---------|
| 1 | msril → modem | Open | 16 bytes, sent at start (`ServiceOpen` sub_10004610). State → opening |
| 0x80000001 | modem → msril | Open response | Accepted in state opening only if the WORDs at 0x14 and 0x16 are both 1 (version 1.1 ?), state → open. Else breaking. Ignored in state breaking / broken, fatal error in any other state |
| 3 | msril → modem | Command | Command of a client |
| 0x80000003 | modem → msril | Response | Matched with the pending command by transaction id |
| 7 | modem → msril | Notification | Copied to the clients |
| other | modem → msril | — | Pipe broken |

Open (kind 1):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Kind |
| 04-07 | 10 00 00 00 | Size (16) |
| 08-0B | ? | Transaction id |
| 0C-0F | 00 00 00 00 | ? |

Command (kind 3), length = client write length + 32:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | Kind |
| 04-07 | ? | Total size |
| 08-0B | ? | Transaction id (31-bit counter, never 0) |
| 0C-0D | 01 00 | Version 1.0 ? |
| 0E-0F | 00 00 | |
| 10-1F | 71 4B 56 71 61 6F 10 45 86 1F 7C 9C BC C2 29 E9 | RIL GUID |
| 20-23 | ? | Command code |
| 24-27 | ? | Not written by msril (uninitialised pool) |
| 28-2B | ? | Data size (total size − 44) |
| 2C- | ? | Command data from the client |

Response (kind 0x80000003):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 80 | Kind |
| 04-07 | ? | ? |
| 08-0B | ? | Transaction id of the command |
| 0C-0F | ? | ? |
| 10-1F | 71 4B 56 71 … | RIL GUID |
| 20-23 | ? | Command code |
| 24-27 | ? | Status (1 = success ?) |
| 28-2B | ? | Data size; the packet length must be data size + 44 |
| 2C- | ? | Response data |

Notification (kind 7):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 07 00 00 00 | Kind |
| 04-0F | ? | ? |
| 10-1F | 71 4B 56 71 … | RIL GUID |
| 20-23 | ? | Notification code |
| 24-27 | ? | Data size; the packet length must be data size + 40 |
| 28- | ? | Notification data |

A wrong length or a wrong GUID in a response or a notification, an unknown kind, or a response with an unknown transaction id **breaks the pipe** (`BreakPipe`; service state → breaking, then broken when all the packets are returned). There is no reconnection: the device stays broken until it is restarted.  
Pending command entries (40 bytes, sub_100048A4): list entry, client, client context, transaction id, time sent and time returned by the pipe (ms). A send time above 10 s and a response time above 60 s are logged (ETW), and the maxima are kept in `MSRIL_DATA`. There's no timeout on commands.

### Interface GUID

Msril interface class GUID (opened by the RIL clients)  
`{47CA0628-71C1-4BE1-8FFB-503201FEAD27}`

### Other GUID

Cellular pipe query-interface (consumed from the parent, see [cellmux.sys](./cellmux.md#pipe-interface))  
`{B9086F29-6065-4DBE-8C90-3CD560547957}`

RIL message GUID (in the pipe messages)  
`{71564B71-6F61-4510-861F-7C9CBCC229E9}`
