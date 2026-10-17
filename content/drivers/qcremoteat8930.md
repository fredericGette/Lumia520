## Qcremoteat8930.sys

Qualcomm Remote AT driver (QMI AT service bridge).  
It lets a user-mode client answer AT commands that the modem forwards to the application processor. The driver registers a fixed list of AT commands with the modem (QMI AT `REG_AT_CMD_FWD`), receives each forwarded command (QMI AT `FWD_AT_CMD_IND`) through [qcqmux8930.sys](./qcqmux8930.md), returns it to the client with `ReadFile`, and sends the client's answer back to the modem (QMI AT `FWD_RESP_AT_CMD`) when the client calls `WriteFile`. There are no IOCTLs.  
The PDB path is `P:\RemoteAT\rel\8.2.1.1\arm\Release\qcremoteat8930.pdb`, source files `device.c` and `remoteatqmux.c`.

ACPI node on the Lumia 520 (DSDT): `\_SB.RMAT` (`_HID` `QCOM2155`, no `_UID`, no `_CRS`, no `_DEP`, no method) ?. The driver doesn't use any ACPI method or hardware resource.

Device name : `\Device\REMOTEAT`  
Symbolic link : `\DosDevices\REMOTEAT`  

There's no parameters in the registry.

GUID of the ETW provider:  
None (no `EtwRegister`, no WPP). The only diagnostics are `RtlAssert` calls, active only with the WDF verifier flag (`WdfDriverGlobals+4` bit 2).

It communicates with the following devices:  
| Device | Driver | Interface GUID | Comment |
|--------|--------|----------------|---------|
| `\Device\QMUX` | [qcqmux8930.sys](./qcqmux8930.md) | `{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}` | QMI multiplexer. Awaited with `IoRegisterPlugPlayNotification`, then opened **by name** (`WdfIoTargetOpen`, `DesiredAccess` 0x1F0000, no sharing, `FILE_NON_DIRECTORY_FILE`). [IOCTL 0x12410](#ioctl-0x12410), [IOCTL 0x12430](#ioctl-0x12430), plus read/write requests carrying QMI SDUs |

### Startup

`EvtDriverDeviceAdd` (sub_40702C):
1. Sets the PnP callbacks `EvtDeviceSelfManagedIoInit` (sub_401008), `EvtDeviceSelfManagedIoSuspend` (sub_401154) and `EvtDeviceSelfManagedIoRestart` (sub_4010D4), and assigns the name `\Device\REMOTEAT`.
2. Creates the device, initializes the event `+0x28` (notification event, not signaled) and creates an unopened WDF I/O target (`+0x0C`).
3. Creates the symbolic link and the device interface `{8D12E7F9-C9EC-4431-B186-D4145B27B26D}`.
4. Creates the default queue (sequential): `EvtIoRead` (sub_4072F8), `EvtIoWrite` (sub_4073D0), `EvtIoStop` (sub_4074AC). No `EvtIoDeviceControl`.

`EvtDeviceSelfManagedIoInit` registers a PnP notification on the QMUX interface `{7DCB3244-…}` (callback sub_401398) and starts the queue. When the interface arrives, the callback opens `\Device\QMUX` (sub_40168C) and creates 2 requests on that target, each with a 512-byte buffer: the QMI read request (`+0x18`, sub_4014D8) and the service-state request (`+0x1C`, sub_4015B0).

The QMI session is only started by the **first** `ReadFile` or `WriteFile` on `\\.\REMOTEAT` (flag `+0x08`, sub_4028F4):
1. [IOCTL 0x12410](#ioctl-0x12410): gets a QMI client id. On failure, nothing else is done (and the flag is still set, so it's never retried).
2. [IOCTL 0x12430](#ioctl-0x12430): waits (asynchronously) for a service-state notification.
3. Sends the QMI read request (`WdfIoTargetFormatRequestForRead`), re-sent after each received message.
4. Registers the AT commands ([REG_AT_CMD_FWD](#qmi-message-0x0020--register-the-at-commands)).

Modem restart: when [IOCTL 0x12430](#ioctl-0x12430) completes with state 1 (SMD channel closed by the modem), a work item (sub_4026E8 → sub_40127C) cancels the read, closes and reopens `\Device\QMUX`, gets a new client id, restarts the read and registers the AT commands again. The flag `+0x38` is set during this reset. Messages received during the reset are answered "No Handler" and not given to the client. IOCTL 0x12430 is then sent again.

`EvtDeviceSelfManagedIoSuspend` cancels the QMI read, purges the I/O target and the queue, and completes the pending `ReadFile` with `STATUS_CANCELLED`. `EvtDeviceSelfManagedIoRestart` restarts the target and the QMI read, then calls `EvtDeviceSelfManagedIoInit` again (a second PnP notification is registered).

> [!NOTE]
> The input byte of [IOCTL 0x12410](#ioctl-0x12410) is the device context byte `+0x15`, which is set to 0 in `EvtDriverDeviceAdd` and never written again. The handle is never bound with [IOCTL 0x12418](./qcqmux8930.md#ioctl-0x12418--ioctl-0x1241c) either. The QMUX handle seems to be bound to service **0** (QMI_CTL), not to the QMI AT service (8 in Qualcomm's numbering). The rest of the code builds QMI AT messages. How this works on a real phone is not known (?).

Device context (`DEVICE_CONTEXT`):  
| Offset | Comment |
|--------|---------|
| 0x00 | WDF device |
| 0x04 | Default queue |
| 0x08 | Byte: QMI session started (first read/write done) |
| 0x0C | WDF I/O target `\Device\QMUX` |
| 0x10 | PnP notification entry |
| 0x14 | Byte: I/O target opened |
| 0x15 | Byte: QMI service type sent with IOCTL 0x12410. Always 0 |
| 0x18 | QMI read request |
| 0x1C | IOCTL 0x12430 request |
| 0x20 | Last QMI transaction id (16 bits, starts at 1) |
| 0x24 | Last QMI message id sent (0x20 or 0x22) |
| 0x28 | KEVENT: QMI response received |
| 0x38 | Byte: reset in progress |

The queue context holds only the pending `ReadFile` request (one at a time).

### ReadFile

`EvtIoRead` (sub_4072F8). The OutputBuffer must be at least 404 bytes, otherwise `STATUS_BUFFER_TOO_SMALL` (0xC0000023).  
The request is made cancelable and kept in the queue context. If a read is already pending, the previous one is completed with `STATUS_CANCELLED` (0xC0000120). It's completed when the modem forwards an AT command. It returns the 404-byte structure below with `Information` = 404.  
If no read is pending when a command arrives, the driver answers the modem itself with result 0 and the response `No Handler`. The command is lost.

Outputbuffer (built by sub_401A48 from the QMI AT indication 0x0021, see [below](#qmi-message-0x0021--forwarded-at-command)):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Command handle (TLV 0x01). To be returned in the `WriteFile` answer |
| 04-07 | ? | Operation flags (TLV 0x01). In QMI AT: 0x01 no argument, 0x02 `=`, 0x04 `?`, 0x08 arguments ? |
| 08-1D | e.g. `+CFUN` | Command name, zero terminated (TLV 0x01) |
| 1E-1F | ? | Number of tokens (TLV 0x10) |
| 20-FB | ? | Kernel pointers to the tokens in the driver's receive buffer. Meaningless in user mode (kernel address leak) |
| FC-107 | ? | 3 dwords of the sub-TLV 0x18 of TLV 0x11 (state info: S3/S4/S5 ?) |
| 108-10B | ? | Dword of the sub-TLV 0x19 of TLV 0x11 (CMEE ?) |
| 10C | 01 | 1 when the sub-TLV 0x19 is present |
| 10D-10F | 00 00 00 | Padding |
| 110-13B | ? | Tokens, zero terminated, one after the other (44 bytes in total) |
| 13C-193 | ? | Offset of each token in the area `110-13B` (16-bit values) |

The tokens are copied with `StringCchCopyA`-like code into the 44-byte area. If they don't fit, the indication is dropped: the read stays pending and the modem gets no answer.  
The command name length (1 byte) and the number of tokens aren't checked: a name longer than 21 characters overwrites the following fields, and more than 55 tokens overflow the structure on the stack (?).

### WriteFile

`EvtIoWrite` (sub_4073D0). Sends the answer to a forwarded AT command. The InputBuffer must be at least 476 bytes. A shorter buffer completes with `STATUS_SUCCESS` and nothing is sent.

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Command handle, from the `ReadFile` output |
| 04-10F | ? | Not used |
| 110-113 | e.g. `01 00 00 00` | Result. Only the low byte is sent. In QMI AT: 0 = error, 1 = OK, 2 = other ? |
| 114-1DB | e.g. `+CFUN: 1` | Response text, zero terminated (200 bytes in a 476-byte buffer) |

The handler sends [FWD_RESP_AT_CMD](#qmi-message-0x0022--at-command-response) and always completes with `STATUS_SUCCESS`, `Information` = 0. The result of the modem is not returned.  
The response length (`strlen`) isn't checked against the 512-byte QMI buffer: a text longer than 494 bytes (with a larger InputBuffer) overflows it (?).

### QMI messages

All messages are QMI SDUs without the QMUX header (see [qcqmux8930.sys](./qcqmux8930.md#qmux-message-format)). They're sent with `WdfIoTargetFormatRequestForWrite` + `WdfRequestSend` (options: timeout + ignore target state, 20 s). The driver then waits up to 20 s on the event `+0x28`. That event is set when a non-indication message arrives whose 16-bit value at offset 0x0A (result of TLV 0x02) isn't 1 (QMI_RESULT_FAILURE). It's a notification event and it's never cleared. After the first success, the later waits return immediately.

Header of every message:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 | Control flags: 0 = request (sent), 4 = indication (received) |
| 01-02 | ? | Transaction id (`+0x20`, incremented for each message, never 0) |
| 03-04 | ? | Message id |
| 05-06 | ? | Length of the TLVs |
| 07-… | ? | TLVs: type (1 byte), length (2 bytes), value |

#### QMI message 0x0020 — register the AT commands

Sent by sub_40239C (QMI_AT_REG_AT_CMD_FWD_REQ). 69 bytes in total: TLV 0x01, 59 bytes, containing one 0x01 sub-TLV per command:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 | Request |
| 01-02 | ? | Transaction id |
| 03-04 | 20 00 | Message id 0x0020 |
| 05-06 | 3E 00 | 62 bytes |
| 07 | 01 | TLV 0x01 |
| 08-09 | 3B 00 | 59 bytes |
| 0A-13 | `01 07 00 00 05` `+cfun` | Command: type 0x01, length 7, abort flag 0 ?, name length 5, name |
| 14-1D | `01 07 00 00 05` `+ckpd` | |
| 1E-27 | `01 07 00 00 05` `+ctsa` | |
| 28-31 | `01 07 00 00 05` `+cmar` | |
| 32-3B | `01 07 00 00 05` `+crsl` | |
| 3C-44 | `01 06 00 00 04` `+css` | |

| Command | 3GPP TS 27.007 meaning |
|---------|------------------------|
| `+CFUN` | Set phone functionality |
| `+CKPD` | Keypad control |
| `+CTSA` | Touch screen action |
| `+CMAR` | Master reset |
| `+CRSL` | Ringer sound level |
| `+CSS` | Screen size |

#### QMI message 0x0021 — forwarded AT command

Indication received from the modem (QMI_AT_FWD_AT_CMD_IND), parsed by sub_401A48 (or sub_401D4C during a reset). Other message ids with control flags 4 are ignored.  
| TLV | Comment |
|-----|---------|
| 0x01 | Handle (4 bytes), operation flags (4 bytes), name length (1 byte), name |
| 0x10 | Tokens: repeated 16-bit length + text |
| 0x11 | State info, sub-TLVs: 0x18 = 3 dwords, 0x19 = 1 dword |

#### QMI message 0x0022 — AT command response

Sent by sub_402144 (QMI_AT_FWD_RESP_AT_CMD_REQ), 18 bytes + text:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 | Request |
| 01-02 | ? | Transaction id |
| 03-04 | 22 00 | Message id 0x0022 |
| 05-06 | ? | 11 + text length |
| 07 | 01 | TLV 0x01 |
| 08-0A | ? | 8 + text length |
| 0B-0E | ? | Command handle |
| 0F | ? | Result (0 for `No Handler`) |
| 10 | 02 | Response type ? (always 2) |
| 11-12 | ? | Text length |
| 13-… | ? | Text, not zero terminated |

---

### IOCTL 0x12410

This IOCTL is sent by Qcremoteat8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x12410) (get a QMI client id), synchronously (sub_401704, 60 s timeout).

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x904 (2308) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get a QMI client id | \Device\QMUX | 1 | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 | Device context byte `+0x15`, always 0. qcqmux8930 reads a full dword here, so bytes 01-03 of its system buffer are undefined (?) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | QMI client id. Not stored: the driver only checks that 1 byte is returned (`bytesReturned == sizeof(qmi_client_id_type)`, checked build assert) |

---

### IOCTL 0x12430

This IOCTL is sent by Qcremoteat8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x12430) (wait for a service state notification), asynchronously (sub_40283C, completion sub_402790).

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x90C (2316) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a service state notification | \Device\QMUX | 0 | 512 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | State. 1 (SMD channel closed by the modem) triggers the reset described in [Startup](#startup). Other values are ignored |
| 04-07 | ? | QMI service type. Not used |

The request is re-sent after each completion.

---

### Interface GUID

Qcremoteat8930 Interface Class GUID  
`{8D12E7F9-C9EC-4431-B186-D4145B27B26D}`

### Other GUID

QMUX interface (`GUID_DEVINTERFACE_QMUX`, [qcqmux8930.sys](./qcqmux8930.md#interface-guid)), waited for  
`{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`

`GUID_DEVICE_INTERFACE_ARRIVAL`  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
