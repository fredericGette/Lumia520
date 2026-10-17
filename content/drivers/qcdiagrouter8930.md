## Qcdiagrouter8930.sys

Qualcomm DIAG protocol router.  
It connects a host DIAG tool (QPST, QXDM) to the DIAG services of the subsystems (modem, LPASS, RIVA/WCNSS) and to local DIAG clients on the application processor. Requests from the host are routed to the subsystem(s) or the local client that registered the command. Log, event and F3 messages coming back from the subsystems are sent to the host. Masks (log/event/F3) set by the host are pushed to the subsystems through their `DIAG_CNTL` channels.  
The host link (the "transport") is selected in the registry: TCP socket (WSK), USB DIAG function (`\Device\USB_DIAG`) or UART. Packets on the host link are HDLC framed (CRC-16, `0x7D` escaping, `0x7E` terminator).  
The PDB path is `P:\Diag\rel\8.3\arm\Release\qcdiagrouter8930.pdb`; source file names found in asserts: `DiagRouterDriver.c`, `DiagRouterSMD.c`, `DiagRouterSerial.c`, `DiagRouterUART.c`, `DiagRouterComposite.c`.

ACPI node on the Lumia 520 (DSDT): `\_SB.QDIG` (`_HID` `QCOM0F80`, nothing else) ? The DCI driver [qcdiagcsi8930.sys](./qcdiagcsi8930.md) would then be `\_SB.QDCI` (`QCOM0F81`).

Device name : `\Device\DiagRouter`  
Symbolic link : `\DosDevices\DiagRouter`  
I/O type : buffered (`WdfDeviceIoBuffered`)  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcdiagrouter` (the service key itself, from `WdfDriverGetRegistryPath`, not the `Parameters` subkey):  
| Registry value | value | comment |
|----------------|-------|---------|
| TransportType | 0 | REG_DWORD. Host link. 0=TCP, 1=USB, 2=UART. Any other value: no transport is started (`STATUS_UNSUCCESSFUL`). Missing value: no transport either, but the device is still created |
| ServerName | e.g. `1.2.3.4` | REG_SZ. TCP only. Address of the machine where QPST/QXDM runs. With `HostAsName`=0 it must be a dotted IPv4 address (`RtlIpv4StringToAddressA`) |
| TCPPort | e.g. `2500` | REG_SZ (not a DWORD). TCP only. Port of the server. With `HostAsName`=0 it's converted with `atoi` |
| HostAsName | 0 | REG_DWORD. TCP only. 0: `ServerName`/`TCPPort` are a literal IPv4 address and port. ≠0: they are a host name and a service name, resolved with `WskGetAddressInfo` (up to 10 tries, 5 s apart) |

With TCP the phone is the **client**: it creates an `AF_INET`/`SOCK_STREAM`/`IPPROTO_TCP` connection socket, binds it to `0.0.0.0:0` and connects to `ServerName:TCPPort`. If the connection fails, it retries every 5 seconds without limit. QPST/QXDM must be listening on the PC.

Interface Class GUID:  
`{5ff73d59-fab7-456e-884e-d5386cd5f581}`

GUID of the ETW provider (WPP control GUID):  
`{9cba380d-42ba-45db-94f0-ac310885ce4e}`

It communicates with the following devices:  
| Device | Driver | Interface GUID | Comment |
|--------|--------|----------------|---------|
| `\Device\SMD` | [qcsmd8930.sys](./qcsmd8930.md) | `{f9d15453-8335-434c-aa72-fcd925f135f3}` | Shared Memory Driver. 3 DIAG data channels + 3 DIAG control channels, see [SMD channels](#smd-channels) |
| `\??\QCOM_ChipInfo` | [qcchipinfo8930.sys](./qcchipinfo8930.md) | `{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}` | Chip identification, used for the Build-ID answer (cmd `0x7C`) |
| `\Device\USB_DIAG` | ? | `{39ab5403-6551-4dfe-a22c-6cc6f4ed2fd0}` | USB DIAG function. Host link when `TransportType`=1 |
| `\Device\RESOURCE_HUB\%08X%08X` or `\DosDevices\COM5` | ? | `{86e0d1e0-8089-11d0-9ce4-08003e301f73}` (GUID_DEVINTERFACE_COMPORT) | UART. Host link when `TransportType`=2 |
| `\Device\DiagCSI` | [qcdiagcsi8930.sys](./qcdiagcsi8930.md) | `{23ccade6-34e8-42e4-8845-99411146dc22}` | DCI (Diag Consumer Interface). Receives the answers of the local clients to DCI commands (packets starting with `0x93`) |
| TCP socket | NETIO.SYS (WSK) | | Host link when `TransportType`=0 |

`\Device\DiagCSI` is opened only after [qcdiagcsi8930.sys](./qcdiagcsi8930.md) sent [internal IOCTL 0x80082458](#internal-ioctl-0x80082458). The DCI driver is a kernel client of the router: it opens `\Device\DiagRouter` and uses the internal IOCTLs 0x80082450 to 0x80082461 to route DCI commands and to set the DCI log/event masks (stream id 2). Its own modem link is the SMD channel `DIAG_2`.

### Startup

`EvtDriverDeviceAdd` (0x41FF84):
1. Creates `\Device\DiagRouter` with the file callbacks `EvtWdfDeviceFileCreate`/`EvtWdfFileClose` and the `EvtWdfIoInCallerContext` callback (needed to reference the event handle of [IOCTL 0x80082400](#ioctl-0x80082400) in the caller's process).
2. Starts a system thread `init_SMD_channels` (0x41B348): waits for the SMD interface, then opens the 6 SMD channels.
3. `init_transport` (0x40B7F4): reads `TransportType` and starts a system thread `transportType0` (TCP, 0x41E9C0), `transportType1` (USB, 0x4014DC) or `transportType2` (UART, 0x408E60).
4. Starts a system thread `query_ChipInfo` (0x41B060).
5. Creates the device interface `{5ff73d59-…}` and the symbolic link.
6. Creates 3 queues: one for IOCTL and internal IOCTL, one for read, one for write.

USB transport: it opens `\Device\USB_DIAG` and gives it two events with [IOCTL 0x808520C0](#ioctl-0x808520c0). On the "D0" event (USB function active), it opens the serial layer and starts reading. On the "D3" event, it purges all pending I/O on the SMD channels and on USB.  
UART transport: `EvtWdfDevicePrepareHardware` looks for a `CmResourceTypeConnection` resource of class SERIAL (2) / type UART (3). When found, the UART is opened as `\Device\RESOURCE_HUB\<ConnectionId.HighPart><ConnectionId.LowPart>`. Otherwise `\DosDevices\COM5` is used. The port is then configured with 4 standard serial IOCTLs (see [IOCTLs sent to the UART](#ioctls-sent-to-the-uart)). `EvtWdfDeviceD0Exit` closes the UART on `WdfPowerDeviceD3Final`.

### SMD channels

Opened by `init_SMD_channels` on `\Device\SMD` with internal IOCTLs of [qcsmd8930.sys](./qcsmd8930.md). The edge numbers match the Qualcomm `smd_channel_type` values (0 = APPS↔MODEM, 1 = APPS↔QDSP, 6 = APPS↔WCNSS).  
| Port | Data channel | Control channel | SMD edge | Subsystem |
|------|--------------|-----------------|----------|-----------|
| 0 | `DIAG` | `DIAG_CNTL` | 0 | Modem |
| 1 | `DIAG` | `DIAG_CNTL` | 1 | QDSP6 / LPASS ? |
| 2 | `APPS_RIVA_DATA` | `APPS_RIVA_CTRL` | 6 | RIVA (WCNSS: Wi-Fi, Bluetooth, FM) |

The control channels carry the DIAG_CNTL protocol (same layout as the Linux `diagfwd_cntl` messages). The subsystems announce the command codes they handle (registration tables, used to route the host requests). The router sends them log masks (cmd 9) and event masks (cmd 10), see [internal IOCTL 0x8008245D](#internal-ioctl-0x8008245d).

### Routing of the host requests

`main_DIAG_packet_receiver_dispatcher` (0x401EFC) decodes each HDLC frame received from the host. The command is identified by:
- the first byte (command code). If it's `0x93`, the real command code is at offset 8, the subsystem id at offset 9 and the subsystem command at offsets 10-11.
- for `0x4B` (subsystem command) and `0x80` (subsystem command v2): the subsystem id (byte 1) and the 16-bit subsystem command code (bytes 2-3).

Commands handled by the router itself (Qualcomm DIAG command codes):  
| Code | DIAG command | Handler (IDA name) | Comment |
|------|--------------|--------------------|---------|
| `0x00` | Version number | `Ping_keepalive` (0x404D3C) | Answered locally only when no control channel has the flag `DIAGROUTER_SMD_CTRL_PORT_CONTEXT+0x15E4` = 1 (flag received on DIAG_CNTL ?). Otherwise routed |
| `0x4B 0x32 0x03` | Polling for "apps only" DIAG | `Control_channel_command` (0x404FE8) | Same condition as `0x00` |
| `0x60` | Event report control | `Diag_configuration_negotiation` (0x404A9C) | |
| `0x73` op 0 | Log config: disable | `no_payload_event` (0x405E7C) | |
| `0x73` op 1 | Log config: get ID ranges | `Stream_log_packet` (0x405880) | Forwarded to the modem when its DIAG channel is open |
| `0x73` op 3 | Log config: set mask | `Event_packet` (0x405B50) | Mask stored and pushed to the subsystems (DIAG_CNTL cmd 9) |
| `0x73` op 4 | Log config: get mask | `sub_4059BC` | Forwarded to the modem when its DIAG channel is open |
| `0x78` | Log on demand ? | `sub_404E8C` | Answered locally when the modem control channel doesn't have the flag `+0x15E5` = 1 |
| `0x7C` | Extended build ID | `Subsystem_0x7C_SMD_control` (0x404C1C) | Same condition as `0x00`. 13-byte answer containing the MSM "tools ID" derived from [IOCTL 0x8C1F2014](#ioctl-0x8c1f2014) |
| `0x7D` op 1 | Ext. message config: get SSID ranges | `sub_405118` | Forwarded to the modem when its DIAG channel is open |
| `0x7D` op 2, 3 | Ext. message config: get build / runtime mask | `sub_405254` | Forwarded to the modem when its DIAG channel is open |
| `0x7D` op 4 | Ext. message config: set runtime mask | `Service_control` (0x40547C) | The IDA name is misleading |
| `0x7D` op 5 | Ext. message config: set all masks | `DTR_RTS` (0x4056AC) | The IDA name is misleading |
| `0x81` | Event mask get | `sub_404770` | Forwarded to the modem when its DIAG channel is open |
| `0x82` | Event mask set | `sub_4048AC` | Mask pushed to the subsystems (DIAG_CNTL cmd 10) |

Other commands go to every port whose registration table (received on its DIAG_CNTL channel) contains the command, and to the local client that registered it with [IOCTL 0x80082404](#ioctl-0x80082404). When nobody handles a command, the router answers with `0x13` (bad command). A truncated `0x4B`/`0x80` request (< 4 bytes) gets `0x15` (bad length) (`fallback_error_handler`, 0x4063E0).

### Local DIAG clients

An application or driver can act as a DIAG service on the application processor:
1. Open `\\.\DiagRouter` (or `\Device\DiagRouter`).
2. [IOCTL 0x80082400](#ioctl-0x80082400): give an event.
3. [IOCTL 0x80082404](#ioctl-0x80082404): register the command codes to receive.
4. Wait for the event, then `ReadFile`: returns one request from the host (one packet per read, at most 4096 bytes). 3 receive buffers of 4096 bytes are allocated per handle. A `ReadFile` with no pending packet fails with `STATUS_UNSUCCESSFUL` (it doesn't block).
5. `WriteFile`: sends the answer to the host (at most 4096 bytes, HDLC-encoded by the router). A buffer starting with `0x93` is sent to `\Device\DiagCSI` instead (internal IOCTL `0x80092491`): it's the answer to a DCI request received with byte 0 = `0x93`, and the client must keep the first 8 bytes of the request (bytes 04-07 = DCI transaction id).

Closing the handle removes the registrations of this handle.

---

### IOCTL 0x80082400

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Register client event | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | User mode: HANDLE of an event (referenced in `EvtWdfIoInCallerContext` with `ObReferenceObjectByHandle(EVENT_MODIFY_STATE, ExEventObjectType)`). Kernel mode: `PKEVENT`. Must not be 0 |

Must be the first IOCTL on a handle. It allocates the 3 receive buffers (4096 bytes, pool tag `qige`), a 8192-byte transmit buffer (tag `qigf`), an MDL and an IRP. The event is set every time a packet is stored in a receive buffer.  
NTSTATUS:  
| Value | Comment |
|-------|---------|
| 0xC000000D STATUS_INVALID_PARAMETER | InputBufferLength ≠ 4 or handle is 0 |
| 0xC0000022 STATUS_ACCESS_DENIED | An event is already registered on this handle |
| 0xC0000010 STATUS_INVALID_DEVICE_REQUEST | No file object |

---

### IOCTL 0x80082404

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x901 (2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Register command codes | 12 + 4×N (min 16) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 01 00 | Command type. 1 = plain command code (byte 0 of the request), 2 = subsystem command `0x4B`, 3 = subsystem command v2 `0x80` |
| 02-03 | ? | Subsystem id (types 2 and 3 only; stored as 0xFF for type 1) |
| 04-05 | N | Number of ranges. Must not be 0 |
| 06-0B | ? | Ignored |
| 0C-0D | ? | Range 1: first command code (type 1) or first subsystem command code (types 2/3) |
| 0E-0F | ? | Range 1: last code (inclusive) |
| … | | N ranges of 4 bytes |

InputBufferLength must be exactly `4 × (N + 3)`, otherwise `STATUS_INVALID_PARAMETER`. [IOCTL 0x80082400](#ioctl-0x80082400) must have been done on the same handle, otherwise `STATUS_INVALID_DEVICE_REQUEST`.  
`called_by_ioctl_0x80082404` (0x40B0E8) copies the table into a global linked list (`memoryPool_24bytes`, pool tag `qigh`) with the file object. The list is searched by `sub_40B210` for each host request and by internal IOCTLs 0x80082450/0x80082454. The entries of a handle are removed on close (`sub_40B04C`).

---

### IOCTL 0x80082408

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x902 (2306) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get new id ? | 0 | 2 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Device-global 16-bit counter (`DIAGROUTER_DEVICE_CONTEXT+0x168`), incremented before being returned |

OutputBufferLength must be exactly 2. Purpose unknown (unique client id ?).

---

### IOCTL 0x8008240C

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x903 (2307) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send "bad length" response | max 4096 | 0 |

Same as `WriteFile`, but the byte `0x15` (DIAG "bad length" response code) is prepended to the packet before HDLC encoding: the host receives `15 <InputBuffer>`. A client uses it to reject a request (the input buffer is normally the original request).  
Backend: `called_by_ioctl_0x8008240C_and_0x80082410` (0x40A980) with third parameter 21 (0x15). Requires [IOCTL 0x80082400](#ioctl-0x80082400) on the handle. Input larger than 4096 bytes → `STATUS_INVALID_DEVICE_REQUEST`.  
If byte 0 of the input buffer is `0x93`, the buffer is sent unchanged to `\Device\DiagCSI` with internal IOCTL `0x80092491` (context type `DIAGCMD_CLNT_DCIRSPSEND_CONTEXT`). This is true for `WriteFile`, 0x8008240C and 0x80082410.

---

### IOCTL 0x80082410

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x904 (2308) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send "bad parameter" response | max 4096 | 0 |

Same as [IOCTL 0x8008240C](#ioctl-0x8008240c) with the prefix byte `0x14` (DIAG "bad parameter" response code), third parameter 20.

---

### internal IOCTL 0x80082450

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x914 (2324) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Query command owner | 4 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 4B | Command code. `0x4B` or `0x80` = subsystem command, other = plain command |
| 01 | ? | Subsystem id (0xFF for a plain command) |
| 02-03 | ? | Subsystem command code (`0x4B`/`0x80` only) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00…03 00 00 00 | Bit 0: a local client registered this command ([IOCTL 0x80082404](#ioctl-0x80082404)). Bit 1: the modem registered it (registration table of the `DIAG_CNTL` channel of port 0, `sub_40676C`) |

Both lengths must be exactly 4, otherwise `STATUS_INVALID_PARAMETER`.  
Sent by [qcdiagcsi8930.sys](./qcdiagcsi8930.md) for each DCI command, to decide where to send it (see [Commands](./qcdiagcsi8930.md#commands)).

---

### internal IOCTL 0x80082454

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x915 (2325) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Deliver request to local client | min 8 | 0 |

Inputbuffer: a DIAG request.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 4B, 80, 93 or other | Command code |
| 01 | ? | Subsystem id (`0x4B`/`0x80`) |
| 02-03 | ? | Subsystem command code (`0x4B`/`0x80`) |
| 08 | ? | `0x93` only: real command code |
| 09 | ? | `0x93` only (size ≥ 12): subsystem id |
| 0A-0B | ? | `0x93` only (size ≥ 12): subsystem command code |

The request is copied into a free receive buffer of the local client that registered the command, and the client's event is set. This is how a DCI request reaches a local client.  
Sent by [qcdiagcsi8930.sys](./qcdiagcsi8930.md) when bit 0 of [0x80082450](#internal-ioctl-0x80082450) is set. The request is `93 ?? ?? ?? <DCI transaction id:4> <DIAG request>`.  
NTSTATUS: `STATUS_INVALID_PARAMETER` if InputBufferLength < 8, `STATUS_UNSUCCESSFUL` if no client registered the command or its 3 buffers are full.

---

### internal IOCTL 0x80082458

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x916 (2326) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Connect to DiagCSI | 0 | 0 |

The request is pended. A work item (`sub_40B388`, context `DIAGCMD_DIAGCSI_WRK_CONTEXT`) registers a PnP notification on `{23ccade6-34e8-42e4-8845-99411146dc22}`. When the interface arrives, `diagCSI_arrived` (0x40B454) opens `\Device\DiagCSI` as I/O target (`DIAGROUTER_DEVICE_CONTEXT+0x16C`) and completes the request with the status of the open. Only the first arrival is handled.  
Sent once by [qcdiagcsi8930.sys](./qcdiagcsi8930.md) right after it enabled the `{23ccade6-…}` interface. Its success unlocks the DCI commands of qcdiagcsi8930.sys.

---

### internal IOCTL 0x8008245D

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x917 (2327) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set DCI log masks | min 8208 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 00 or ≠00 | One byte per equipment id 0…15. ≠0: the mask of this equipment is updated |
| 10-20F | ? | Log mask of equipment 0 (512 bytes = 4096 log items) |
| … | | |
| 1E10-200F | ? | Log mask of equipment 15 |

Processed in a work item (`sub_4068DC`, context `DIAGCMD_DIAGCSI_MSKCFG_WRK_CONTEXT.field_0` = 0). The masks are stored for stream id 2 (the host QXDM uses stream id 1). For each flagged equipment, `sub_404064` sends a DIAG_CNTL "log mask" message to the modem `DIAG_CNTL` channel:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 09 00 00 00 | DIAG_CNTL command: log mask |
| 04-07 | 0B 02 00 00 | Data length = 11 + 512 |
| 08 | 02 | Stream id |
| 09 | 03 | Status: mask valid |
| 0A | ? | Equipment id |
| 0B-0E | FF 0F 00 00 | Last log item = 4095 |
| 0F-12 | 00 02 00 00 | Mask size = 512 |
| 13-212 | ? | Mask |

The request is completed when the write completes (`sub_40373C`). `STATUS_INVALID_PARAMETER` if InputBufferLength < 8208.  
Sent by [qcdiagcsi8930.sys](./qcdiagcsi8930.md): the masks are the OR of the log masks of its (at most 2) mask clients, see [Masks](./qcdiagcsi8930.md#masks).

---

### internal IOCTL 0x80082461

This IOCTL is processed by Qcdiagrouter8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x918 (2328) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set DCI event mask | 512 | 0 |

Inputbuffer: event mask (512 bytes = 4096 event ids), stored for stream id 2.  
Same work item as [0x8008245D](#internal-ioctl-0x8008245d) with `field_0` = 1. `sub_403DAC` sends a DIAG_CNTL "event mask" message to the modem `DIAG_CNTL` channel:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 0A 00 00 00 | DIAG_CNTL command: event mask |
| 04-07 | 07 02 00 00 | Data length = 7 + 512 |
| 08 | 02 | Stream id |
| 09 | 03 | Status: mask valid |
| 0A | ? | Event config of the stream (`byte_410878[stream]`, event reporting on/off ?) |
| 0B-0E | 00 02 00 00 | Mask size = 512 |
| 0F-20E | ? | Mask |

InputBufferLength must be exactly 512, otherwise `STATUS_INVALID_PARAMETER`.  
Sent by [qcdiagcsi8930.sys](./qcdiagcsi8930.md): OR of the event masks of its mask clients.

---

### internal IOCTL 0x80092491

This IOCTL is sent by Qcdiagrouter8930.sys to `\Device\DiagCSI` ([qcdiagcsi8930.sys](./qcdiagcsi8930.md#internal-ioctl-0x80092491))

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x924 (2340) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Send DCI response | `\Device\DiagCSI` | max 4096 | 0 |

Inputbuffer: the buffer written by a local client, unchanged (byte 0 = `0x93`, bytes 04-07 = DCI transaction id, DIAG answer from byte 08).  
The client's request is completed with the status and information of this IOCTL (`completion_routine_6`).

---

### IOCTL 0x808520C0

This IOCTL is sent by Qcdiagrouter8930.sys to `\Device\USB_DIAG`

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x830 (2096) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set power events | `\Device\USB_DIAG` | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT` `phHardwareEnterD0Event`: set when the USB DIAG function becomes active |
| 04-07 | ? | `PKEVENT` `phHardwareEnterD3Event`: set when it's suspended / disconnected |

Sent synchronously by `UsbDiag_Ioctl_0x808520C0` (0x40196C) after opening `\Device\USB_DIAG` (access 0x1F0000). The names come from an assert in `DiagRouterComposite.c` (`pUsbOpenParams->phHardwareEnterD0Event && pUsbOpenParams->phHardwareEnterD3Event`). Kernel mode only: the buffer contains kernel pointers.

---

### IOCTL 0x8C1F2014

This IOCTL is sent by Qcdiagrouter8930.sys to [qcchipinfo8930.sys](./qcchipinfo8930.md#ioctl-0x8c1f2014)

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x805 (2053) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get chip family | `\??\QCOM_ChipInfo` | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 1E 00 00 00 | Chip family (e.g. 30 = MSM8627 family, which includes the MSM8227 of the Lumia 520 ?), see [qcchipinfo8930.sys](./qcchipinfo8930.md#chip-ids). Converted to the MSM "tools ID" returned in the answer to command `0x7C` (`result_Ioctl_0x8C1F2014_chipinfo`) |

| Output value | Family | Tools ID |
|--------------|--------|----------|
| 0x16 | MSM8960, MSM8660A, MSM8260A, APQ8060A | 0xFE0 (4064) |
| 0x1A | MSM8930, MSM8630, MSM8230, APQ8030 (and AA variants) | 0xFEC (4076) |
| 0x1E | MSM8627, MSM8227 (Lumia 520 ?) | 0xFF0 (4080) |
| 0x20 | MSM8974 | 0xFF3 (4083) |
| 0x22 | APQ8064, MPQ8064, MPQ8062, APQ8064V2P | 0xFE8 (4072) |
| other | (e.g. 0x25 MSM8930AB, 0 unknown chip) | 0 |

Sent once, from the `query_ChipInfo` thread, when the ChipInfo interface arrives. The target is opened with GENERIC_READ|GENERIC_WRITE.

---

### IOCTLs sent to qcsmd8930.sys

These internal IOCTLs are sent by Qcdiagrouter8930.sys to `\Device\SMD` ([qcsmd8930.sys](./qcsmd8930.md)), through `send_request_to_iotarget` (0x403960). Each channel has its own I/O target. They are METHOD_NEITHER and the buffers contain kernel pointers.  
| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| `0x2200F` (Device 0x2, Function 0x803) | `\Device\SMD` | 8 | 0 |
| `0x22003` (Device 0x2, Function 0x800) | `\Device\SMD` | 28 | 0 |
| `0x22033` (Device 0x2, Function 0x80C) | `\Device\SMD` | 0 | 0 |

Sequence for each port (0, 1, 2): on the data channel `0x2200F`, `0x22003`, `0x22033`, then on the control channel `0x22003`.

`0x2200F` inputbuffer (data channels only):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT`, `DIAGROUTER_SMD_PORT_CONTEXT+0x20` |
| 04-07 | ? | `PKEVENT`, `DIAGROUTER_SMD_PORT_CONTEXT+0x10` |

`0x22003` inputbuffer (open channel):  
| Bytes | Data channel | Control channel | Comment |
|-------|--------------|-----------------|---------|
| 00-03 | ? | ? | Pointer to the ASCII channel name (`DIAG`, `APPS_RIVA_DATA`, `DIAG_CNTL`, `APPS_RIVA_CTRL`) |
| 04-07 | 00, 01 or 06 | 00, 01 or 06 | SMD edge |
| 08-0B | 01 00 00 00 | 01 00 00 00 | ? |
| 0C-0F | 00 00 00 00 | 00 04 00 00 (ports 0, 1), 00 00 00 00 (port 2) | ? (FIFO size ?) |
| 10-13 | ? | 00 00 00 00 | Data: pointer to the port context (`KEVENT` at offset 0) |
| 14-17 | ? | 00 00 00 00 | Data: `PKEVENT`, port context `+0x40` |
| 18-1B | ? | 00 00 00 00 | Data: `PKEVENT`, port context `+0x30` |

`0x22033`: no buffer. Purpose ? (state change, see qcsmd8930.sys).

---

### IOCTLs sent to the UART

Sent by `config_UART` (0x409368), in this order, to the UART I/O target (`TransportType`=2). Standard `IOCTL_SERIAL_*` codes (device `FILE_DEVICE_SERIAL_PORT` 0x1B, METHOD_BUFFERED).  
| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| `0x1B0064` IOCTL_SERIAL_SET_HANDFLOW | `\Device\RESOURCE_HUB\…` or `\DosDevices\COM5` | 16 | 0 |
| `0x1B000C` IOCTL_SERIAL_SET_LINE_CONTROL | same | 3 | 0 |
| `0x1B0004` IOCTL_SERIAL_SET_BAUD_RATE | same | 4 | 0 |
| `0x1B001C` IOCTL_SERIAL_SET_TIMEOUTS | same | 20 | 0 |

`IOCTL_SERIAL_SET_HANDFLOW` (`SERIAL_HANDFLOW`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | F7 FF FF FF | ControlHandShake = 0xFFFFFFF7: every bit except `SERIAL_CTS_HANDSHAKE` |
| 04-07 | 7F FF FF FF | FlowReplace = 0xFFFFFF7F: every bit except `SERIAL_RTS_HANDSHAKE` |
| 08-0B | 00 00 00 00 | XonLimit |
| 0C-0F | 00 00 00 00 | XoffLimit |

The handflow values look like a bug: `~SERIAL_CTS_HANDSHAKE` and `~SERIAL_RTS_HANDSHAKE` are assigned instead of being AND-ed with the current values.

`IOCTL_SERIAL_SET_LINE_CONTROL` (`SERIAL_LINE_CONTROL`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 | StopBits: 1 stop bit |
| 01 | 00 | Parity: none |
| 02 | 08 | WordLength: 8 bits |

`IOCTL_SERIAL_SET_BAUD_RATE` (`SERIAL_BAUD_RATE`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 C2 01 00 | 115200 bauds |

`IOCTL_SERIAL_SET_TIMEOUTS` (`SERIAL_TIMEOUTS`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 05 00 00 00 | ReadIntervalTimeout = 5 ms |
| 04-07 | 00 00 00 00 | ReadTotalTimeoutMultiplier |
| 08-0B | 00 00 00 00 | ReadTotalTimeoutConstant |
| 0C-0F | 00 00 00 00 | WriteTotalTimeoutMultiplier |
| 10-13 | C8 00 00 00 | WriteTotalTimeoutConstant = 200 ms |

---

### Example of Bluetooth logs

From the WCN subsystem (RIVA), as seen in QXDM:
```
LOG          [0x1365]               BT HCI Command                          01:01:24.480        Length: 0003                                                      0x03 0C 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                PFAL_DBG.c  00272  MBAAAANAZW1150088                      0x79 00 00 00 00 1C 00 FA 2C 00 00 00 10 01 04 00 01 00 00 00 4D 42 41 41 41 41 4E 41 5A 57 31 31 35 30 30 38 38 00 50 46 41 4C 5F 44 42 47 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                PFAL_DBG.c  00272  LLM Pre Reset called                   0x79 00 00 00 00 5C 00 FA 2C 00 00 00 10 01 04 00 01 00 00 00 4C 4C 4D 20 50 72 65 20 52 65 73 65 74 20 63 61 6C 6C 65 64 00 50 46 41 4C 5F 44 42 47 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                PFAL_DBG.c  00272  HCI pre reset complete                 0x79 00 00 00 00 64 00 FA 2C 00 00 00 10 01 04 00 01 00 00 00 48 43 49 20 70 72 65 20 72 65 73 65 74 20 63 6F 6D 70 6C 65 74 65 00 50 46 41 4C 5F 44 42 47 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                 riva_pm.c  01399  PM_SetPowerMode Mode = 0x10 Override = 0x00x79 00 02 00 00 68 00 FA 2C 00 00 00 77 05 04 00 01 00 00 00 10 00 00 00 00 00 00 00 50 4D 5F 53 65 74 50 6F 77 65 72 4D 6F 64 65 20 4D 6F 64 65 20 3D 20 30 78 25 58 20 4F 76 65 72 72 69 64 65 20 3D 20 30 78 25 58 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                 riva_pm.c  01734  PM_resolveResources: WLAN:0xE0009 BT:0x1 FM:0x00x79 00 03 00 00 6C 00 FA 2C 00 00 00 C6 06 04 00 01 00 00 00 09 00 0E 00 01 00 00 00 00 00 00 00 50 4D 5F 72 65 73 6F 6C 76 65 52 65 73 6F 75 72 63 65 73 3A 20 57 4C 41 4E 3A 30 78 25 58 20 42 54 3A 30 78 25 58 20 46 4D 3A 30 78 25 58 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                 riva_pm.c  02733  PM_resolveResourceSleepEnable:Prev:0 Curr:00x79 00 02 00 00 70 00 FA 2C 00 00 00 AD 0A 04 00 01 00 00 00 00 00 00 00 00 00 00 00 50 4D 5F 72 65 73 6F 6C 76 65 52 65 73 6F 75 72 63 65 53 6C 65 65 70 45 6E 61 62 6C 65 3A 50 72 65 76 3A 25 64 20 43 75 72 72 3A 25 64 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.481                 riva_pm.c  02599  icbarb_issue_request Ab=491133600, Ib=8683350000x79 00 02 00 00 8C 00 FA 2C 00 00 00 27 0A 04 00 01 00 00 00 A0 1A 46 1D 98 BD C1 33 69 63 62 61 72 62 5F 69 73 73 75 65 5F 72 65 71 75 65 73 74 20 41 62 3D 25 64 2C 20 49 62 3D 25 64 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.505                PFAL_DBG.c  00272  LLM Reset called                       0x79 00 00 00 00 58 14 FA 2C 00 00 00 10 01 04 00 01 00 00 00 4C 4C 4D 20 52 65 73 65 74 20 63 61 6C 6C 65 64 00 50 46 41 4C 5F 44 42 47 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.505                 riva_pm.c  01399  PM_SetPowerMode Mode = 0xD Override = 0x00x79 00 02 00 00 6C 14 FA 2C 00 00 00 77 05 04 00 01 00 00 00 0D 00 00 00 00 00 00 00 50 4D 5F 53 65 74 50 6F 77 65 72 4D 6F 64 65 20 4D 6F 64 65 20 3D 20 30 78 25 58 20 4F 76 65 72 72 69 64 65 20 3D 20 30 78 25 58 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.505                 riva_pm.c  01734  PM_resolveResources: WLAN:0xE0009 BT:0x0 FM:0x00x79 00 03 00 00 70 14 FA 2C 00 00 00 C6 06 04 00 01 00 00 00 09 00 0E 00 00 00 00 00 00 00 00 00 50 4D 5F 72 65 73 6F 6C 76 65 52 65 73 6F 75 72 63 65 73 3A 20 57 4C 41 4E 3A 30 78 25 58 20 42 54 3A 30 78 25 58 20 46 4D 3A 30 78 25 58 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.505                 riva_pm.c  02733  PM_resolveResourceSleepEnable:Prev:0 Curr:00x79 00 02 00 00 70 14 FA 2C 00 00 00 AD 0A 04 00 01 00 00 00 00 00 00 00 00 00 00 00 50 4D 5F 72 65 73 6F 6C 76 65 52 65 73 6F 75 72 63 65 53 6C 65 65 70 45 6E 61 62 6C 65 3A 50 72 65 76 3A 25 64 20 43 75 72 72 3A 25 64 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.506                 riva_pm.c  02599  icbarb_issue_request Ab=489500000, Ib=8581250000x79 00 02 00 00 8C 14 FA 2C 00 00 00 27 0A 04 00 01 00 00 00 60 2D 2D 1D C8 F2 25 33 69 63 62 61 72 62 5F 69 73 73 75 65 5F 72 65 71 75 65 73 74 20 41 62 3D 25 64 2C 20 49 62 3D 25 64 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.506                PFAL_DBG.c  00272  HCI reset complete                     0x79 00 00 00 00 A8 14 FA 2C 00 00 00 10 01 04 00 01 00 00 00 48 43 49 20 72 65 73 65 74 20 63 6F 6D 70 6C 65 74 65 00 50 46 41 4C 5F 44 42 47 2E 63 00
LOG          [0x1366]               BT HCI Event                            01:01:24.506        Length: 0006                                                      0x0E 04 01 03 0C 00
```
