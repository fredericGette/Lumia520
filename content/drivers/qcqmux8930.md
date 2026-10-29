## Qcqmux8930.sys

Qualcomm QMUX driver (QMI multiplexer).  
It carries QMI messages between the clients on the application processor (typically the RIL) and the QMI services of the modem. The modem link is a set of 8 SMD control channels (`DATA5_CNTL` … `DATA14_CNTL`) of [qcsmd8930.sys](./qcsmd8930.md). The driver adds/removes the 6-byte QMUX header, routes the received messages to the right client by QMI service type and client id, and implements the QMI control service (QMI_CTL, service 0) itself: client id allocation/release, version info, data format, power-save.  
A client opens `\\.\QMUX`, binds its handle to a QMI service with [IOCTL 0x12418](#ioctl-0x12418--ioctl-0x1241c) and [IOCTL 0x12410](#ioctl-0x12410), then sends QMI requests with `WriteFile` and gets responses and indications with `ReadFile`.  
The PDB path is `P:\QMUX\rel\8.2.1\arm\Release\qcqmux8930.pdb`, source file `qmux.c`, build date `Mar 24 2014 19:47:46`.

ACPI node on the Lumia 520 (DSDT): `\_SB.QMUX` (`_HID` `QCOM0FA0`, no `_UID`, no `_CRS`, no `_DEP`, no method).

Device name : `\Device\QMUX`  
Symbolic link : `\DosDevices\QMUX`  
I/O type : buffered (`WdfDeviceIoBuffered`)  

There's no parameters in the registry.

GUID of the WPP control provider:  
`{31B96960-EEDF-4E09-9107-322DA4505634}`  
WPP trace message GUIDs: `{C68C0A1C-7181-1AC1-E2D5-357255B49DCC}`, `{C8E84ED7-B507-2CD9-09AE-F00446C144B9}`, `{13359DAE-6521-6F95-0C0B-1AEA4E274440}`

GUID of the ETW provider (`McGenEventRegister`):  
`{601E23F3-B43B-471A-853A-EAA5FA28E05B}`

It communicates with the following devices:  
| Device | Driver | Interface GUID | Comment |
|--------|--------|----------------|---------|
| `\Device\SMD` | [qcsmd8930.sys](./qcsmd8930.md) | `{F9D15453-8335-434C-AA72-FCD925F135F3}` | Shared Memory Driver. 8 control channels, see [SMD channels](#smd-channels). [internal IOCTL 0x22003](#internal-ioctl-0x22003), [internal IOCTL 0x22007](#internal-ioctl-0x22007), [internal IOCTL 0x22013](#internal-ioctl-0x22013), plus read/write requests |
| ACPI node of the device | acpi.sys | | [IOCTL 0x32C004](#ioctl-0x32c004) `EXQM`, selects the transport |
| ? | ? | `{6064DC13-78B4-4A57-8D55-C49BA16CF99D}` | Alternative transport ("MBIM" mode), only when the ACPI method `EXQM` exists. Not used on the Lumia 520 |

[qcremoteat8930.sys](./qcremoteat8930.md) waits for the interface `{7DCB3244-…}`, opens `\Device\QMUX` and uses [IOCTL 0x12410](#ioctl-0x12410), [IOCTL 0x12430](#ioctl-0x12430), `ReadFile` and `WriteFile` to carry QMI AT messages. The WWAN miniport [qcmbb8930.sys](./qcmbb8930.md) is another client: its QMI client library (QCCI) uses [IOCTL 0x12410](#ioctl-0x12410), [IOCTL 0x12418](#ioctl-0x12418--ioctl-0x1241c), [IOCTL 0x12430](#ioctl-0x12430) and read/write for its WDS, DMS, NAS, WMS, UIM and VOICE clients, and it sends [IOCTL 0x1242C](#ioctl-0x1242c) once per adapter. In user mode, the QMI client library [qccium8930.dll](../libraries/qccium8930.md#qmux-transport) opens `\\.\QMUX\QmuxDevice` (QMUX ports 0 to 5) and uses [IOCTL 0x12410](#ioctl-0x12410), [IOCTL 0x12418](#ioctl-0x12418--ioctl-0x1241c), [IOCTL 0x12430](#ioctl-0x12430) and read/write; its users are `QcShutdownSvc8930.exe` and `qcfmminiport.dll` (not analysed). The other clients are probably the user-mode RIL (?).

### Startup

`EvtDriverDeviceAdd` (0x4173FC):
1. Creates `\Device\QMUX` with the file callbacks `EvtDeviceFileCreate` (sub_417C00) and `EvtFileCleanup` (sub_417A64), the PnP callbacks `EvtDevicePrepareHardware` (sub_4045D4, does nothing), `EvtDeviceD0Exit` (sub_404618) and `EvtDeviceSurpriseRemoval` (sub_404880), and the symbolic link. The device is not stoppable/removable (`WdfDeviceSetStaticStopRemove`) and is hidden from Device Manager (`WdfDeviceSetDeviceState`, `DontDisplayInUI`).
2. Evaluates the ACPI method `EXQM` with a 10 MB (0xA00000) output buffer ([IOCTL 0x32C004](#ioctl-0x32c004)). Only the success matters (`byte_40A7B8`): the result is never read. On the Lumia 520 the `QMUX` node has no `EXQM`, the call fails and the driver uses the **SMD** transport (`byte_40A7B8` = 0).
3. Creates the default queue (sequential): `EvtIoRead` (sub_4181C8), `EvtIoWrite` (sub_418214), `EvtIoDeviceControl` (sub_41847C), `EvtIoStop` (sub_418048), `EvtIoCanceledOnQueue` (sub_4181A0). The queue is **stopped**: it's only started when the modem has answered QMI_CTL GET_VERSION_INFO (see below). Until then, requests wait in the queue.
4. Queues a work item that enables the device interface `{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`.
5. `IoRegisterPlugPlayNotification` on the SMD interface `{F9D15453-…}` (or on `{6064DC13-…}` in MBIM mode), callback sub_404A40.

When the SMD interface arrives (work item sub_404B5C → sub_4056E8):
1. For each of the 8 ports (only port 0 in MBIM mode), `sub_405100` opens a WDF I/O target on the interface's symbolic link (`DesiredAccess` 0x1F0000, share read/write, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`), opens the SMD channel with [internal IOCTL 0x22003](#internal-ioctl-0x22003) and starts one system thread per port (sub_406D7C).
2. `sub_4039F0` initialises the QMUX core (13 port slots, 0–12) and, for each port, sends a QMI_CTL **SYNC** (0x0027) request on the channel.
3. Each reader thread waits for the "channel opened" event, then queues a work item (sub_405C94) that sends QMI_CTL **GET_VERSION_INFO** (0x0021) on port 0.
4. When the answer arrives (sub_4065CC), the service version table (`word_40F1A0`, 4 words per service type) is filled, all clients get a state notification "0" ([IOCTL 0x12430](#ioctl-0x12430)) and the default queue is started.

Reader thread (sub_406D7C), one per port, waits on 3 events of the channel:
- data received: while [internal IOCTL 0x22013](#internal-ioctl-0x22013) reports bytes in the FIFO, reads them with a read request (8193-byte buffer, 1 s timeout) and dispatches the message (sub_404E70 → sub_401924).
- remote close (SMD event 9, e.g. modem restart): stops and purges the default queue, closes the channel with [internal IOCTL 0x22007](#internal-ioctl-0x22007), sends the state notification "1" to the clients of the port, clears the version table (port 0), then reopens the channel and waits again for GET_VERSION_INFO.
- driver stop (`stru_40D160`, set by `EvtDeviceD0Exit` on `WdfPowerDeviceD3Final`): closes the channel and terminates.

MBIM mode (not used on the Lumia 520): a single port, and the 3 events are named events created by the driver: `\GLOBAL??\MBIMDataReadyEvent`, `\GLOBAL??\MBIMArrivalEvent`, `\GLOBAL??\MBIMRemovalEvent`.

`EvtDeviceD0Exit` (D3Final only): sets the stop event, waits for the 8 reader threads, closes and dereferences the named events created by [IOCTL 0x12420](#ioctl-0x12420)/[0x12424](#ioctl-0x12424), and disables the device interface. `EvtDeviceSurpriseRemoval` only disables the device interface.

### SMD channels

Channel table at `.data:0x0040A7C0` (`aData5Cntl`), 24-byte entries: control channel name (12 bytes) + data channel name (12 bytes). Only the control channel names of entries 0–7 are used. The data channel names (`DATA5`…`DATA14`) and the entries 8–15 (`SDIO0_CNTL`/`SDIO0` … `SDIO7_CNTL`/`SDIO7`) are not used. The binary contains 4 more copies of the same table (0x40A158, 0x40A2F0, 0x40A488, 0x40A620) without any reference.  
| Port | SMD channel | SMD edge |
|------|-------------|----------|
| 0 | `DATA5_CNTL` | 0 (APPS↔MODEM) |
| 1 | `DATA6_CNTL` | 0 |
| 2 | `DATA7_CNTL` | 0 |
| 3 | `DATA8_CNTL` | 0 |
| 4 | `DATA9_CNTL` | 0 |
| 5 | `DATA12_CNTL` | 0 |
| 6 | `DATA13_CNTL` | 0 |
| 7 | `DATA14_CNTL` | 0 |

Each port has a 416-byte context (`IOTARGET_SMD_PORT_CONTEXT`, port 0 at `dword_40D2A0`, ports 1–7 at `dword_40D440`): `+0x00` WDF device, `+0x04` pointer to the 3 channel events, `+0x08` WDF I/O target, `+0x0C` port number.  
QMI_CTL messages generated by the driver (version info, client ids…) are sent on port 0, unless the client chose another port.

### QMUX message format

Every message on a channel (written by `sub_401BB4`, parsed by `sub_401924`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Interface type, must be 1 |
| 01-02 | ? | Length of the message without this first byte, little endian |
| 03 | 00 | Control flags. 0 when sent by the driver |
| 04 | ? | QMI service type. 0 = QMI_CTL, otherwise < 100 (0x64) |
| 05 | ? | QMI client id. 0xFF = broadcast |
| 06-… | ? | QMI SDU (service header + TLVs) |

Received messages are dispatched as follows:
- service 0 (QMI_CTL): handled by the driver (`sub_402F74`). QMI_CTL SYNC (0x0027) messages are dropped.
- client id 0xFF: delivered to every client bound to the same port and service.
- otherwise: delivered to the client that owns the (port, service, client id) triple.

The client receives the QMI SDU without the QMUX header (bytes 06-…), see [Read](#read).

QMI_CTL requests built by the driver (`sub_402670`, command numbers of the `cmd` field of [IOCTL 0x12404](#ioctl-0x12404)):  
| cmd | QMI_CTL message | TLVs sent |
|-----|-----------------|-----------|
| 1 | 0x0022 GET_CLIENT_ID | 0x01: service type (1 byte) |
| 2 | 0x0023 RELEASE_CLIENT_ID | 0x01: service type, client id (2 bytes) |
| 3 | 0x0026 SET_DATA_FORMAT | 0x01: QoS header flag (1 byte); 0x10: link protocol (2 bytes), only if ≠ 0 |
| 4 | — | Registers the caller for the QMI_CTL indications (local list, nothing is sent) |
| 5 | — | Unregisters the caller, and forgets its client ids |
| 6 | 0x0028 REG_PWR_SAVE_MODE | 0x01: 4 bytes |
| 8 | 0x0029 CONFIG_PWR_SAVE_SETTINGS | 0x01: 4 bytes + 1 byte; 0x11: up to 10 message ids (2 bytes each) |
| 9 | 0x002A SET_PWR_SAVE_MODE | 0x01: 4 bytes |
| 10 | 0x002B GET_PWR_SAVE_MODE | none |
| 11 | 0x0021 GET_VERSION_INFO | none |
| 12 | — | The payload is already a QMI_CTL SDU, only the transaction id is set |
| 13 | 0x0027 SYNC | none |

Responses handled: 0x0021 (version table), 0x0022 (client id, wakes up [IOCTL 0x12410](#ioctl-0x12410)), 0x0023 (wakes up the cleanup of a closing handle), 0x0026 (link protocol, wakes up [IOCTL 0x1242C](#ioctl-0x1242c)), 0x0028 indication (forwarded internally as cmd 7 to the registered callers).

### Client handles

`EvtDeviceFileCreate` (sub_417C00) gives each handle a `CLIENT_CONTEXT`, with 2 manual queues (pending reads, pending state notifications), 2 collections (queued messages, queued state notifications) and 5 events. It's added to the global client collection.  
| Offset | Comment |
|--------|---------|
| 0x00 | Manual queue of the pending reads |
| 0x0C | Manual queue of the pending [IOCTL 0x12430](#ioctl-0x12430) |
| 0x08 / 0x14 | Collections of the received messages / state notifications not read yet |
| 0x18 | Port (SMD channel index, default 0) |
| 0x1C | Unique client number, from a counter starting at 1 (`dword_40A7BC`) |
| 0x20 | QMI service type (0 = not bound) |
| 0x24 | QMI client id (byte, 0xFF = none) |
| 0x28, 0x38, 0x48, 0x58, 0x68 | Events: client id received, client id released, DMS answer, data format answer, cancel |
| 0xA0 | Link protocol (2 bytes) |
| 0xA8 | 1 when a client id has been allocated |
| 0xB0 | Last state sent with [IOCTL 0x12430](#ioctl-0x12430) (initially −1) |

`EvtFileCleanup` (sub_417A64): if the handle has a service and a client id, sends QMI_CTL RELEASE_CLIENT_ID and waits up to 5 s for the answer. Then it purges the 2 queues and removes the client from the collection.

### Read

`ReadFile` (and [IOCTL 0x1240C](#ioctl-0x1240c)): returns the next message received for this handle: the QMI SDU without the 6-byte QMUX header. If none is queued, the request is pended until a message arrives. The output buffer must be at least as large as the message.

### Write

`WriteFile`: the InputBuffer is a QMI SDU (QMI service header + TLVs, without the QMUX header). The driver prepends the QMUX header with the handle's port, service type and client id, and writes it to the SMD channel (asynchronous write request).  
- Service ≠ 0: completes with `Information` = length written, or 0 if the write failed.
- Service 0 (QMI_CTL): the SDU is sent as a raw QMI_CTL message (cmd 12, the driver sets the transaction id). Completes with `Information` = 0.  
Returns `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) when the handle has no client context.

---

### IOCTL 0x12400

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (reset client) | 8 (exact) | 12 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | Not used |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0B | 00 … 00 | Always zeroed (`sub_403BA0`) |

The handler then copies the first dword of the (zeroed) output into the client number (`+0x1C`), i.e. sets it to **0**, and sets `+0xA4` = 1. Completes with `STATUS_SUCCESS` and `Information` = 0 (the 12 zero bytes are not reported).  
With wrong sizes the request is **never completed** (the handler just returns).

---

### IOCTL 0x12404

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x901 (2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send a QMUX / QMI_CTL request | ≥ 32 | 0 |

Inputbuffer (`sub_401D44`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `cmd`. 0 = raw QMI SDU, 1–13 = QMI_CTL command (see [QMUX message format](#qmux-message-format)). ≥ 13 is refused |
| 04-07 | ? | Caller id (−1 = none) |
| 08-13 | ? | ? |
| 14-17 | ? | Port (0–12) |
| 18-1B | ? | QMI service type (cmd 0) |
| 1C | ? | QMI client id (cmd 0) |
| 1D-1F | ? | ? |
| 20-… | ? | cmd 0: QMI SDU. Other cmd: a 1464-byte (0x5B8) parameter block, at least 1464 bytes are required |

The result of the send is ignored: the IOCTL completes with `STATUS_SUCCESS` and `Information` = 0, nothing is returned. With an InputBuffer shorter than 32 bytes, nothing is sent.

---

### IOCTL 0x12408

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x902 (2306) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (shutdown) | 4 (exact) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Only traced |

Sets the events `stru_40D120` and `stru_40D280` and the flag `byte_40D154`, then calls `WdfIoTargetClose` and `WdfObjectDelete` on `dword_40F180`, and completes with `STATUS_SUCCESS`. After that, [IOCTL 0x1240C](#ioctl-0x1240c) fails.  
`dword_40F180` is never written anywhere in the driver, so the I/O target passed to WDF is always NULL: calling this IOCTL probably crashes the phone (?).  
With a wrong size the request is never completed.

---

### IOCTL 0x1240C

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x903 (2307) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read a QMI message | 0 | n |

Same as `ReadFile` (see [Read](#read)), unless [IOCTL 0x12408](#ioctl-0x12408) has been called: then it completes with `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A).

---

### IOCTL 0x12410

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x904 (2308) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get a QMI client id | 4 or 8 | 1 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `03 00 00 00` | QMI service type (e.g. 1 = WDS, 2 = DMS, 3 = NAS…) |
| 04-07 | 00 00 00 00 | Optional (InputBuffer of 8 bytes). Port |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | QMI client id allocated by the modem |

Stores the service type in the handle, then a work item (sub_40581C) sends QMI_CTL GET_CLIENT_ID and waits for the answer. The request is pended (cancelable) meanwhile.  
Returns:
- `STATUS_SUCCESS`, `Information` = 1: client id received.
- `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A): the request couldn't be sent, or the modem returned no client id (0 or 0xFF; error 0x1F gives 0xFF).
- `STATUS_INVALID_DEVICE_STATE` (0xC0000184): driver stopping.
- `STATUS_CANCELLED` (0xC0000120): request cancelled.

---

### IOCTL 0x12414

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x905 (2309) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (DMS get device serial numbers) | 0 | any |

Only for a handle bound to service 2 (DMS), otherwise `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).  
A work item (sub_405A84) sends the QMI request `0x0025` (QMI_DMS_GET_DEVICE_SERIAL_NUMBERS ?) with the handle's client id (`sub_4034A0`), then waits for the event `+0x48`.  
That event is only set by `sub_406380`, which copies the TLV 0x12 (IMEI ?) of the answer into the client context (`+0x78`). That path is only taken for a handle whose `+0xA4` = 2, and no code sets that value: the answer is delivered to `ReadFile` like any other message, and the IOCTL stays pending until it's cancelled. If the event is ever set, the IOCTL completes with `STATUS_UNSUCCESSFUL` (0xC0000001) and no data.

---

### IOCTL 0x12418 / IOCTL 0x1241C

These IOCTLs are processed by Qcqmux8930.sys (same handler for both codes)

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x906 (2310) / 0x907 (2311) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Bind the handle to a QMI service | 4 or 8 | 4 or 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `02 00 00 00` | QMI service type. Not checked against the size of the version table |
| 04-07 | 00 00 00 00 | Optional (InputBuffer of 8 bytes). Port |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Major version of the service, from QMI_CTL GET_VERSION_INFO (TLV 0x01) |
| 02-03 | ? | Minor version |
| 04-05 | ? | Only with an OutputBuffer of 8 bytes. Third word of the version table entry (TLV 0x10 addendum list ?) |
| 06-07 | ? | Only with an OutputBuffer of 8 bytes. Fourth word |

Stores the service type in the handle and resets the client id to 0. When the handle wasn't bound before and the third word of the service's entry isn't 0, a state notification "0" is queued for [IOCTL 0x12430](#ioctl-0x12430).  
Completes with `Information` = 0, 4 or 8 (OutputBuffer size).

---

### IOCTL 0x12420

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x908 (2312) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Create a named event | n | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | ? | UTF-16 name of the event, zero terminated |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | Kernel handle of the event (64-bit) |

Copies the name into a 256-byte pool buffer, formats `\BaseNamedObjects\<name>` with `sprintf_s("%ls")`, converts it to UNICODE_STRING and creates it with `IoCreateNotificationEvent`. The event object and its handle are kept in the device context (`+0x284` objects, `+0xA84` handles, count at `+0x1284`). No code of the driver signals these events.  
Returns `STATUS_UNSUCCESSFUL` (0xC0000001) if the creation fails.  
The name is copied **without any length check**: an InputBuffer larger than 256 bytes overflows the pool buffer. The number of events (512 slots) is not checked either.

---

### IOCTL 0x12424

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x909 (2313) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Create a named event | n | 8 |

Same as [IOCTL 0x12420](#ioctl-0x12420), with 512-byte buffers and `swprintf_s(L"\\BaseNamedObjects\\%s")` + `RtlInitUnicodeString` (no ANSI conversion). Same missing length check (overflow above 512 bytes).

---

### IOCTL 0x12428

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x90A (2314) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Close a named event | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | Handle returned by [IOCTL 0x12420](#ioctl-0x12420) / [0x12424](#ioctl-0x12424) |

Closes the handle, dereferences the event and removes it from the table. Returns `STATUS_UNSUCCESSFUL` (0xC0000001) if the handle isn't found.

---

### IOCTL 0x1242C

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x90B (2315) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| QMI_CTL SET_DATA_FORMAT | 12 | 2 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | QoS header flag, sent in TLV 0x01 (1 byte) |
| 04-05 | ? | Link protocol, sent in TLV 0x10 (omitted if 0). In QMI, 1 = 802.3, 2 = IP |
| 06-07 | ? | Not used |
| 08-0B | ? | Port |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Link protocol returned by the modem (TLV 0x10 of the answer) |

A work item (sub_405D88) sends QMI_CTL SET_DATA_FORMAT and waits for the answer. Completes with `Information` = 2, or `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A) / `STATUS_INVALID_DEVICE_STATE` (0xC0000184) like [IOCTL 0x12410](#ioctl-0x12410).  
Sent by [qcmbb8930.sys](./qcmbb8930.md#ioctl-0x1242c) at initialisation with QoS flag 0, link protocol 3 (802.3 and IP) and port = adapter index; bytes 06-07 are left uninitialised.

---

### IOCTL 0x12430

This IOCTL is processed by Qcqmux8930.sys

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x90C (2316) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Wait for a service state notification | 0 | 8 |

Outputbuffer (`sub_407500`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | State. 0 = service available (modem answered GET_VERSION_INFO), 1 = SMD channel closed by the modem (reset) |
| 04-07 | ? | QMI service type of the handle |

Returns the oldest queued notification, or pends the request until the next one. A notification is only generated for handles bound to a service with a client id, and only when the state changes (`+0xB0`).

---

### IOCTL 0x32C004

This IOCTL is sent by Qcqmux8930.sys to acpi.sys (`IOCTL_ACPI_EVAL_METHOD`, sub_404534)

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | FILE_READ_ACCESS \| FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI node `\_SB.QMUX` | 8 | 10485760 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `AeiB` (ACPI_EVAL_INPUT_BUFFER) |
| 04-07 | 45 58 51 4D | Method name `EXQM` |

The output is not used. Success → MBIM transport, failure (the Lumia 520 case) → SMD transport.

---

### internal IOCTL 0x22003

This IOCTL is sent by Qcqmux8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) (open a SMD channel), once per port.

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Open a SMD channel | \Device\SMD | 28 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the channel name, e.g. `DATA5_CNTL` |
| 04-07 | 00 00 00 00 | Edge 0 (APPS↔MODEM) |
| 08-0B | 01 00 00 00 | Flags (packet mode, no wait) |
| 0C-0F | 00 04 00 00 | FIFO size: 1024 bytes |
| 10-13 | ? | `PKEVENT` data received (synchronization event) |
| 14-17 | ? | `PKEVENT` channel opened (notification event) |
| 18-1B | ? | `PKEVENT` remote close (synchronization event) |

### internal IOCTL 0x22007

Sent by Qcqmux8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22007) (close the channel) when the modem closed it, and when the reader thread stops (1 s timeout). No buffer.

### internal IOCTL 0x22013

Sent by Qcqmux8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22013) (number of bytes in the receive FIFO) before each read. No buffer; the answer is the `Information` of the request.

---

### Interface GUID

Qcqmux8930 Interface Class GUID  
`{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`

### Other GUID

SMD interface (qcsmd8930.sys), waited for in SMD mode  
`{F9D15453-8335-434C-AA72-FCD925F135F3}`

Transport interface waited for in MBIM mode (driver unknown)  
`{6064DC13-78B4-4A57-8D55-C49BA16CF99D}`
