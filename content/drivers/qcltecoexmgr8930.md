## Qcltecoexmgr8930.sys

LTE coexistence manager.  
It's a QMI client of the modem's **COEX** service (QMI service 0x22). It registers for the "WWAN state" indication and keeps the last LTE band information received (uplink/downlink frequency and bandwidth). Bluetooth and WLAN drivers read this state with `ReadFile` on `\Device\LTECoexMgr` to avoid the frequencies used by LTE (e.g. the 2.4 GHz ISM band next to LTE band 7/40).  
A `WriteFile` of the same 24-byte record injects a state, as if it came from the modem (test path, see the `TEST` interface).  
The QMI client library (QCCI) is the same as in [qcamss8930.sys](./qcamss8930.md) and [qcepmadc8930.sys](./qcepmadc8930.md). It reaches the modem through the IPC router [qcipcrouter8930.sys](./qcipcrouter8930.md) or through [qcqmux8930.sys](./qcqmux8930.md).  
The PDB path embedded in the binary is `P:\LteCoexMgr\rel\8.2.1.1\arm\Release\QcLteCoexMgr8930.pdb`.

Device name : `\Device\LTECoexMgr`  
Symbolic link : `\DosDevices\LTECoexMgr`  
SDDL : `D:P(A;;GA;;;SY)(A;;GA;;;BA)` (SYSTEM and Administrators only)  

There's no parameters in the registry.

GUID of the ETW provider (WPP control GUID, `WppInitKm` in `DriverEntry`):  
`{EA888489-DA55-4C45-9463-E789D758B6F2}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\IPC (interface `{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`) | [qcipcrouter8930.sys](./qcipcrouter8930.md) | QCCI "IPC router" transport (ops table `.data:0x00408194`). [IOCTL 0x122008](#ioctl-0x122008), [IOCTL 0x122017](#ioctl-0x122017), [IOCTL 0x12201B](#ioctl-0x12201b), read/write of QMI messages |
| \Device\QMUX (interface `{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`) | [qcqmux8930.sys](./qcqmux8930.md) | QCCI "QMUX" transport (ops table `.data:0x004081A8`), registered 6 times with the parameters 16 to 21 (QMUX ports 0 to 5). [IOCTL 0x12418](#ioctl-0x12418), [IOCTL 0x12410](#ioctl-0x12410), [IOCTL 0x12430](#ioctl-0x12430), read/write of QMI messages |
| ? | Bluetooth / WLAN drivers ? | Clients of the `BT` and `WLAN` device interfaces (`ReadFile`). No page in this folder references `{FDAE87E4-…}` yet (?) |

There's no hardcoded physical address (no `MmMapIoSpace`) and no IOCTL is handled: the driver only accepts `ReadFile` and `WriteFile`.

### WDF setup

`EvtDriverDeviceAdd` (0x40A3E8):
- `EvtDeviceD0Exit` (`sub_40AAC0`): when the target state is `WdfPowerDeviceD3Final` (5), all the pending reads are completed with `STATUS_CANCELLED` (0xC0000120).
- Exclusive: no. Name `\Device\LTECoexMgr`, SDDL above, symbolic link `\DosDevices\LTECoexMgr`.
- File object: `EvtDeviceFileCreate` = `sub_40ABD0`, cleanup of the file context (`COEX_FILE_CONTEXT`) = `sub_4010F0`.
- Default queue (parallel, not power managed): `EvtIoRead` = `sub_40ACC0`, `EvtIoWrite` = `sub_401134`.
- Manual queue (+0x10): reads waiting for a new state.
- Work item (+0x38, `sub_4010AC` → `sub_40AE30`): completes all the waiting reads with the new state.
- Three device interfaces with the same class GUID `{FDAE87E4-EB5F-48A9-ACF8-735C9C8DBD2E}` and the reference strings `BT`, `WLAN` and `TEST`. The three of them lead to the same device; the driver doesn't look at the reference string.
- At the end, a system thread (`sub_401514` → `sub_401418`) is started to connect to the QMI COEX service (see [QMI COEX](#qmi-coex)).

Device context `COEX_DEVICE_CONTEXT` (0x3C bytes, pointer also kept in `.data:0x00408E0C`):  
| Offset | Comment |
|--------|---------|
| 0x00 | WDFDEVICE |
| 0x04 | Wait lock of the client bitmaps |
| 0x08 | Wait lock of the QMI connection (thread `sub_401418`) |
| 0x0C | Default queue |
| 0x10 | Manual queue of the waiting reads |
| 0x14 | Bitmap of the clients that already got the current state |
| 0x18 | Bitmap of the free client slots (initially 0xFFFFFFFF) |
| 0x1C-0x33 | Last state (24 bytes, see [Read](#read)) |
| 0x34 | Byte: 1 once a state has been received or written |
| 0x38 | Work item |

### Clients

Each `CreateFile` takes a free bit of the bitmap +0x18 (lowest first, `sub_40AF38`) and stores it in the file context: there's at most **32** open handles; the 33rd `CreateFile` fails with `STATUS_UNSUCCESSFUL` (0xC0000001). The bit is given back when the handle is closed (`sub_40B034`).

### Read

`EvtIoRead` (`sub_40ACC0`): the length must be exactly **24** bytes, otherwise `STATUS_UNSUCCESSFUL` (0xC0000001).
- If a state is known (+0x34) and this handle hasn't read it yet (its bit isn't set in +0x14), the read completes at once with the state and 24 bytes, and the bit is set.
- Otherwise the read is forwarded to the manual queue and completed by the work item when the next state arrives (from the modem or from a write). All the waiting reads get the state at once.

So the first read of a handle returns the current state, and every following read waits for the next change. The bitmap +0x14 is never cleared on a new state: a handle that has no read pending when a state arrives doesn't get that state, its next read waits for the following one.

Outputbuffer (24 bytes, copied from the context +0x1C):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | LTE **uplink** frequency (TLV 0x10 `ul_band.freq` of the indication), 0 when the TLV is absent |
| 04-07 | ? | LTE uplink bandwidth (TLV 0x10 `ul_band.bandwidth`), 0 when the TLV is absent |
| 08-0B | ? | LTE **downlink** frequency (TLV 0x10 `dl_band.freq`), 0 when the TLV is absent |
| 0C-0F | ? | LTE downlink bandwidth (TLV 0x10 `dl_band.bandwidth`), 0 when the TLV is absent |
| 10-13 | 01 00 00 00 or 00 00 00 00 | 1 when the TDD TLV 0x11 is **absent** (FDD ?), 0 when it's present |
| 14-17 | 01 00 00 00 or 00 00 00 00 | 1 when TLV 0x10 is present and the downlink frequency isn't 0 (LTE active ?) |

The units are those of the QMI COEX service (MHz and Hz ?). The rest of the indication (TDD configuration, off period) is ignored.

### Write

`EvtIoWrite` (`sub_401134`): the length must be exactly **24** bytes, otherwise `STATUS_UNSUCCESSFUL` (0xC0000001). The 24 bytes (same layout as the [read](#read)) are stored as the new state (`sub_40AB88`) exactly like an indication from the modem, and the waiting reads are completed with it. The write completes with 24 bytes.

> [!NOTE]
> Any handle can write, not only the one opened on the `TEST` interface: a client can fake the LTE state seen by the Bluetooth and WLAN drivers. The SDDL limits the device to SYSTEM and Administrators.

### QMI COEX

Service object `.data:0x00408160` (QMI IDL):  
| Property | Value |
|----------|-------|
| Library version | 5 |
| IDL version | 1 (minor 1) |
| Service id | 0x22 (COEX) |
| Max message length | 99 |

Messages of the service object (only 0x20 and 0x21 are used by the driver). The names are those of Qualcomm's `coex_v01` IDL (?), matched on the message ids and the TLV layouts:  
| Message id | Request (C size) | Response (C size) | Indication (C size) | Name |
|------------|------------------|-------------------|---------------------|------|
| 0x0000 | 0 | 8 | | ? (reset ?) |
| 0x0020 | 2 | 8 | | QMI_COEX_INDICATION_REGISTER. Request: optional TLV 0x10, 1 byte (report WWAN state) |
| 0x0021 | | | 52 | QMI_COEX_WWAN_STATE_IND. Optional TLVs 0x10 LTE band info (UL freq, UL bandwidth, DL freq, DL bandwidth: 4 × u32), 0x11 LTE TDD info (5 × u32), 0x12 LTE off period (u32) |
| 0x0022 | 0 | 56 | | QMI_COEX_GET_WWAN_STATE. Response: result + same 3 TLVs as the indication |
| 0x0023 | 104 | 8 | | QMI_COEX_SET_WLAN_STATE ? Request: optional TLVs 0x10 (16 bytes) and 0x11 (80 bytes) |
| 0x0024 | 4 | 28 | | QMI_COEX_GET_WLAN_SCAN_STATE ? Request: mandatory u32 (TLV 0x01). Response: TLV 0x10 (16 bytes) |
| 0x0025 | 4 | 92 | | QMI_COEX_GET_WLAN_CONN_STATE ? Request: mandatory u32 (TLV 0x01). Response: TLV 0x10 (80 bytes) |

Connection (`sub_4012F8`, run by the thread `sub_401418`):
1. Register the transports (`sub_4027B0`): the IPC router, then 6 QMUX ports (parameters 16 to 21).
2. Create a notifier client for the service (`sub_401D0C`) and wait up to **5 s** for a server (the result of the wait isn't checked).
3. Get the list of the servers of the service on all the transports (`sub_40263C`, `qmi_client_get_any_service`) and open a client on the first one (`sub_401F44`). The indication callback is `sub_401254`.
4. Register the error callback `sub_4012E0` (`sub_402728`): when the server goes away (modem restart), the thread is started again and the connection is redone.
5. Send the request 0x0020 synchronously (`sub_40226C`, message id hardcoded in `sub_4017B8`, 1 s timeout ?) with the request:

| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | TLV 0x10 valid |
| 01 | 01 | Report the WWAN state |

The response result must be 0 (success), otherwise the connection fails with `STATUS_UNSUCCESSFUL` and is not retried (until the next error callback).

Indication 0x0021 (`sub_401254`): decoded into a 52-byte structure (valid flag +0x00, band info +0x04-0x13, TDD valid +0x14, TDD info +0x18-0x2B, off period valid +0x2C, off period +0x30), converted to the 24-byte record of the [read](#read) and stored with `sub_40AB88`.

Pool tag of the library: `qck0`. Memory tag of the WDF memory objects: `QCCI`.

---

### IOCTL 0x122008

This IOCTL is sent by Qcltecoexmgr8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x122008) by the IPC transport of the QMI client library (`sub_404D34`, lookup of the servers of a service), on a target opened on `\Device\IPC` for the request. Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Lookup servers | \Device\IPC | 16 | 8 + 16 × MaxEntries |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 22 00 00 00 | Service 0x22 = COEX |
| 04-07 | 01 00 00 00 | Instance (IDL version of the service object ?) |
| 08-0B | FF 00 00 00 | Instance mask |
| 0C-0F | ? | MaxEntries |

The node and port of each server found are copied into the service info records of the library (20 bytes each).

---

### IOCTL 0x122017

This IOCTL is sent by Qcltecoexmgr8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x122017) by the IPC transport of the QMI client library (`sub_4046CC` when the port is opened, then re-sent by the completion work item `sub_404028`). Asynchronous, no buffer.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x805 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a packet | \Device\IPC | 0 | 0 |

When it completes, the next packet is read and given to the library.

---

### IOCTL 0x12201B

This IOCTL is sent by Qcltecoexmgr8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x12201b) by the IPC transport of the QMI client library (`sub_4046CC`, then re-sent by the work item `sub_404200`, "qcci_xport_ipc_wdf_event_peek_cb_workitem"). Asynchronous.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x806 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a server/client event (IOCTL_IPC_READ_OOB) | \Device\IPC | 0 | 0 (20-byte memory attached) |

Used to be told about new or removed servers ("IOCTL_IPC_READ_OOB returned status" in the `DbgPrintEx` traces).

---

### IOCTL 0x12418

This IOCTL is sent by Qcltecoexmgr8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x12418--ioctl-0x1241c) by the QMUX transport of the QMI client library (`sub_405B88`, lookup of a service), on a target opened on `\Device\QMUX` for the request. Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x906 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Bind the handle to a QMI service | \Device\QMUX | 8 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 22 00 00 00 | QMI service type (0x22 = COEX) |
| 04-07 | 00 00 00 00 … 05 00 00 00 | QMUX port: transport parameter (16 to 21) − 16 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Major version of the service. The service is "found" only when it's equal to the IDL version of the service object (1) |
| 02-03 | ? | Minor version (not used) |

---

### IOCTL 0x12410

This IOCTL is sent by Qcltecoexmgr8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x12410) by the QMUX transport of the QMI client library (`sub_4053FC`, open of a client). Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get a QMI client id | \Device\QMUX | ? | 1 |

---

### IOCTL 0x12430

This IOCTL is sent by Qcltecoexmgr8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x12430) by the QMUX transport of the QMI client library (`sub_4053FC`, then re-sent by the work item `sub_405240`). Asynchronous.

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x90C |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a service state notification | \Device\QMUX | 0 | 8 |

When the notification says the channel was closed by the modem, the library is told that the server is gone, which calls the error callback (new connection, see [QMI COEX](#qmi-coex)).

---

### Interface GUID

LTE coexistence manager Interface Class GUID (reference strings `BT`, `WLAN`, `TEST`)  
`{FDAE87E4-EB5F-48A9-ACF8-735C9C8DBD2E}`

### Other GUID

IPC router interface, awaited with `IoRegisterPlugPlayNotification` ([qcipcrouter8930.sys](./qcipcrouter8930.md))  
`{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`

QMUX interface, awaited with `IoRegisterPlugPlayNotification` ([qcqmux8930.sys](./qcqmux8930.md))  
`{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`
