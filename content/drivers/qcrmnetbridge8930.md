## Qcrmnetbridge8930.sys

Qualcomm RmNet bridge: connects the USB RmNet (QMI tethering) function to the modem.  
It's the Windows Phone counterpart of the Linux USB `rmnet` function in its "SMD control + BAM DMUX data" transport (`f_rmnet` / `u_ctrl_smd` / `u_data_bam`): the QMI control messages of the USB host go through the SMD channel `DATA40_CNTL` of [qcsmd8930.sys](./qcsmd8930.md), and the IP packets go through channel 8 of stream 2 of [qcbamdmux8930.sys](./qcbamdmux8930.md) (`BAM_DMUX_USB_RMNET_0` in Linux `bam_dmux.h`). A PC connected to the phone sees a QMI/RmNet network adapter, when the USB function exposes it.  
The driver also looks into the QMI messages it forwards: it records whether the host asked for TLP aggregation (QMI_CTL / QMI_WDA SET_DATA_FORMAT), does the (de)aggregation itself when the modem doesn't, and rewrites the modem's answers accordingly (see [QMI rewriting](#qmi-rewriting)).  
It is a KMDF driver built like [qcmbrg8930.sys](./qcmbrg8930.md): no `\Device\` object, no symbolic link, no queue, no device interface of its own, and it receives no IOCTL. Everything happens in three system threads and in request completion routines.  
PDB path `P:\RmNetBridge\rel\8.2.1.1\arm\Release\qcrmnetbridge8930.pdb`; source file names found in asserts: `rmnbrgdevice.c`, `rmnbrgsmd.c`, `rmnbrgbam.c`, `rmnbrgusb.c`. Pool tag: `rbrg`. There are no log messages (no ETW, no `DbgPrint`), only `RtlAssert` in checked mode.

ACPI device `\_SB.RMNT` (`_HID` `QCOM2148`, nothing else: no `_UID`, no resources, no `_DEP`) ? The binary doesn't name its hardware ID; `RMNT` is the only DSDT node next to `MBRG` that matches.

There's no named `\Device\` object and no symbolic link.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM2148\<instance>` ?  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>` (the `RegistryPath` given to `DriverEntry` itself, not its `Parameters` subkey; `sub_402048`, `ZwQueryValueKey` with `KeyValueFullInformation`):  
| Registry value | value | comment |
|----------------|-------|---------|
| SmdFifoSize | 8192 (0x2000) | REG_DWORD. FIFO size of the SMD channel `DATA40_CNTL`, passed as is to [internal IOCTL 0x22003](#internal-ioctl-0x22003). 0x2000 when the key can't be opened or the value is missing. The type and the length of the value aren't checked |

GUID of the ETW provider:  
None.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Interface `{F9D15453-8335-434C-AA72-FCD925F135F3}`. Channel `DATA40_CNTL`, edge 0 (APPS↔MODEM): QMI control messages. [internal IOCTL 0x22003](#internal-ioctl-0x22003), [internal IOCTL 0x2201F, 0x22027](#internal-ioctl-0x2201f-0x22027), plus read/write requests |
| \Device\DMUX | [qcbamdmux8930.sys](./qcbamdmux8930.md) | Interface `{CCCB7664-4951-40C3-8EB1-FDA3964A4479}` ("ready"). Stream 2, channel 8: IP packets. [internal IOCTL 0x82003](#internal-ioctl-0x82003), then the [BAM DMUX query-interface](./qcbamdmux8930.md#bam-dmux-interface) `{EA38864C-56D4-4426-B145-AC2E39C2BB72}` |
| \Device\USB_RMNET | USB RmNet function driver ? | Interface `{96F30BBF-0C5E-40F6-8A12-FFDCF265FF73}`. Control side of the USB function: [IOCTL 0x808520C0](#ioctl-0x808520c0), [IOCTL 0x808520CD](#ioctl-0x808520cd), [IOCTL 0x808520D2](#ioctl-0x808520d2) |
| Interface `{CEC7D47F-A1E1-4607-A693-9A0061465DB7}` | USB function driver ? | Opened by the symbolic link given in the PnP notification. Bulk data side: [internal IOCTL 0x2AC011](#internal-ioctl-0x2ac011) (to the host), [internal IOCTL 0x2AC016](#internal-ioctl-0x2ac016) (from the host) |

All targets are opened with `WdfIoTargetOpen` (`DesiredAccess` 0x1F0000 = `FILE_ALL_ACCESS`; share mode read/write for `\Device\SMD` and `\Device\DMUX`, none for the two USB targets). The 4 I/O targets are created in `EvtDriverDeviceAdd` (`sub_40802C`: context +0x04 = SMD, +0x08 = `\Device\USB_RMNET`, +0x0C = DMUX, +0x10 = USB data interface).

### Start sequence

1. `DriverEntry` (0x409008): `WdfDriverCreate`, then keeps a copy of `RegistryPath` (for `SmdFifoSize`). Returns `STATUS_NO_MEMORY` (0xC0000017) if the copy can't be allocated.
2. `EvtDriverDeviceAdd` (`sub_40802C`): IO type `WdfDeviceIoDirect`, PnP/power callbacks `EvtDeviceSelfManagedIoInit` (0x4019A0), `EvtDeviceSelfManagedIoSuspend` (0x408300, does nothing) and `EvtDeviceSelfManagedIoRestart` (= `EvtDeviceSelfManagedIoInit`), `WdfDeviceCreate`, 4 `WdfIoTargetCreate`, 6 collections, 2 spin locks, 3 events, and the two 4-byte memory objects +0x88 (value 9) and +0x8C (value 8) used by the [USB data IOCTLs](#internal-ioctl-0x2ac016).
3. `EvtDeviceSelfManagedIoInit`: four `IoRegisterPlugPlayNotification` (`EventCategoryDeviceInterfaceChange`, `PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`):
   - USB RmNet interface `{96F30BBF-…}`, callback `sub_402A50`, flag +0x2C;
   - SMD interface `{F9D15453-…}`, callback `sub_401D9C`, flag +0x9C;
   - BAM DMUX "ready" interface `{CCCB7664-…}`, callback `sub_401094`, flag +0x9D;
   - USB data interface `{CEC7D47F-…}`, callback `sub_402A50`, flag +0x2D. On arrival, the target +0x10 is opened with the symbolic link of the notification.

   On `GUID_DEVICE_INTERFACE_ARRIVAL` `{CB3A4004-46F0-11D0-B08F-00609713053F}` the callback sets its flag; on any other event it clears it. When a flag goes from 0 to 1 and all four flags are set, `sub_401B8C` starts the bridge: SMD side, then BAM side, then USB side.
4. SMD side (`sub_401C70`, `rmnbrgsmd.c`):
   1. `sub_401E68`: opens `\Device\SMD`.
   2. `sub_401EDC`: creates 10 SMD read requests with a 1 KB buffer (collection +0x1C).
   3. `sub_40217C`: starts the SMD thread `sub_402728`, then sends [internal IOCTL 0x22003](#internal-ioctl-0x22003) (open `DATA40_CNTL`).
   4. Posts the 10 SMD reads (`sub_402314`).
5. BAM side (`sub_401008`, `rmnbrgbam.c`):
   1. `sub_401160`: opens `\Device\DMUX`.
   2. `sub_40120C`: sends [internal IOCTL 0x82003](#internal-ioctl-0x82003) (bind to stream 2, channel 8, RX callback `sub_401394`), then gets the BAM DMUX interface with `WdfIoTargetQueryForInterface` (`{EA38864C-…}`, Size 0x18, Version 1) into the context +0xA4.
6. USB side (`sub_4028F8`, `rmnbrgusb.c`):
   1. `sub_402B5C`: opens `\Device\USB_RMNET`.
   2. `sub_402BD4`: creates 10 control read requests of 1 KB (collection +0x14), 3 data read requests of 32 KB (collection +0x18) and 1 data write request of 32 KB (collection +0x20).
   3. `sub_402F68`: initialises the D0 (+0x38) and D3 (+0x48) events, sends [IOCTL 0x808520C0](#ioctl-0x808520c0) synchronously, starts the USB thread `sub_4030FC` and the downlink thread `sub_403A18`.
   4. Sets +0x95 (USB side ready). If the USB function is already active (+0x94), posts the data reads and the control reads.

As in qcmbrg8930.sys, the PnP notifications are never unregistered, the threads never exit and nothing is freed (no cleanup callback).

### Control path (QMI)

| Direction | Read | Completion | Write |
|-----------|------|------------|-------|
| Host → Modem | 10 pending [IOCTL 0x808520D2](#ioctl-0x808520d2) on `\Device\USB_RMNET`, 1 KB each (`sub_4035CC`) | `sub_40369C`: on `STATUS_PIPE_NOT_AVAILABLE` (0xC00000AC) or `STATUS_CANCELLED` (0xC0000120) the request goes back to the collection +0x14 (re-posted at the next D0). Otherwise the QMI request is inspected (`sub_401480`, see [QMI rewriting](#qmi-rewriting)) | The same request is written to the SMD channel (`WdfIoTargetFormatRequestForWrite`). Completion `sub_4025A4` re-posts it as IOCTL 0x808520D2 |
| Modem → Host | 10 pending SMD reads, 1 KB each (`sub_402314`) | `sub_4023D8`: if the USB function is not active or the read failed, the read is re-posted (the message is dropped). Otherwise the QMI response is inspected and possibly modified (`sub_4015AC`) | The same request is sent as [IOCTL 0x808520CD](#ioctl-0x808520cd) to `\Device\USB_RMNET`. Completion `sub_4038B8` re-posts the SMD read |

> [!NOTE]
> A control request that completes with 0 bytes, or while the SMD channel is closed by the modem (+0xE0), is only reused, not re-posted nor put back in a collection. The SMD reads are also not re-posted while the channel is closed, and the thread doesn't re-post anything when the channel reopens (it only empties the collections). After a modem restart the control path seems to stay dead until the device is restarted ?

### Data path (IP packets)

| Direction | Read | Write |
|-----------|------|-------|
| Host → Modem (uplink) | 3 pending [internal IOCTL 0x2AC016](#internal-ioctl-0x2ac016), 32 KB each (`sub_40329C`) | Completion `sub_403370`: each packet is sent with `BamMuxWrite(2, 8, Data, Length)` (interface offset 0x14, context +0xB8), then the read is re-posted. If the host enabled uplink TLP and the modem didn't (+0x7D = 1, +0x7E = 0), the buffer is split first: a sequence of `[USHORT length][packet]`. On `STATUS_PIPE_NOT_AVAILABLE` / `STATUS_CANCELLED` or while the SMD channel is closed, the request goes back to the collection +0x18. The status of `BamMuxWrite` isn't checked: a packet > 2048 bytes is lost |
| Modem → Host (downlink) | BAM DMUX RX callback `sub_401394(Payload, Length, Context)` | If the USB function is not active, the buffer is given back to DMUX at once (interface offset 0x10, context +0xB4, `Stream` 2, `Buffer` = Payload − 8). Otherwise the payload is wrapped in a `WDFMEMORY` (free list +0x78, or `WdfMemoryCreatePreallocated`, at most 100), queued in the collection +0x70 and the event +0x5C is set. The downlink thread `sub_403A18` takes the single 32 KB USB write request, copies the packet into it, gives the DMUX buffer back and sends [internal IOCTL 0x2AC011](#internal-ioctl-0x2ac011). With downlink TLP (+0x7C), it prepends `length | 0xF800` (USHORT, written in the DMUX header just before the payload) to each packet and aggregates as many queued packets as fit in 32 KB. Completion `sub_403980` puts the request back and sets +0x5C |

When there are 100 wrappers in use and the free list is empty, the downlink packet is dropped (its buffer is given back to DMUX).

### QMI rewriting

The messages are QMUX frames: `01`, length (2), flags, service, client id, then the SDU. The SDU header is 2 bytes for QMI_CTL (service 0: flags, transaction id) and 3 bytes for the other services (flags, transaction id on 2 bytes), followed by the message id (2), the length (2) and the TLVs (type 1 byte, length 2 bytes, value). Only QMI_CTL (service 0) and QMI_WDA (service 0x1A, Wireless Data Administrative) are parsed; messages shorter than 5 bytes are ignored.

Flags kept in the device context:  
| Offset | Meaning |
|--------|---------|
| +0x7C | Downlink TLP requested by the host |
| +0x7D | Uplink TLP requested by the host |
| +0x7E | Uplink TLP accepted by the modem |
| +0x7F | Downlink TLP accepted by the modem (WDA only; not used) |

Host → modem (`sub_401480`), requests (flags 0):  
| Service | Message | TLV | Action |
|---------|---------|-----|--------|
| QMI_CTL | 0x0026 SET_DATA_FORMAT | 0x13 (DL TLP ?) | +0x7C = value, then the value is **set to 0** in the message: the modem is never asked for downlink TLP, the bridge does it |
| QMI_CTL | 0x0026 SET_DATA_FORMAT | 0x11 (UL TLP ?) | +0x7D = value |
| QMI_WDA | 0x0020 SET_DATA_FORMAT | 0x12 (UL data aggregation protocol) | +0x7D = (value == 1), 1 = TLP |
| QMI_WDA | 0x0020 SET_DATA_FORMAT | 0x13 (DL data aggregation protocol) | +0x7C = (value == 1) |

Modem → host (`sub_4015AC`), responses (QMI_CTL flags 1, QMI_WDA flags 2):  
| Service | Message | TLV | Action |
|---------|---------|-----|--------|
| QMI_CTL | 0x0021 GET_VERSION_INFO | 0x01 (service version list) | For the entry of service 0 (QMI_CTL) with major ≤ 1 and minor < 6, the minor version is raised to 6 |
| QMI_CTL | 0x0026 SET_DATA_FORMAT | 0x11 | +0x7E = value. If 0 and +0x7D set: replaced by 1 |
| QMI_CTL | 0x0026 SET_DATA_FORMAT | 0x13 | If 0 and +0x7C set: replaced by 1 |
| QMI_CTL | 0x0026 SET_DATA_FORMAT | 0x11 / 0x13 missing | Appended (`13 01 00 01` / `11 01 00 01`) when the matching flag is set; the QMUX and message lengths and the transfer length are increased by 4 |
| QMI_WDA | 0x0020 SET_DATA_FORMAT | 0x12 (4 bytes) | +0x7E = (value == 1). Otherwise, if +0x7D set: replaced by 1 |
| QMI_WDA | 0x0020 SET_DATA_FORMAT | 0x13 (4 bytes) | +0x7F = (value == 1). Otherwise, if +0x7C set: replaced by 1 |

So the host always sees TLP enabled when it asked for it. The TLV lengths aren't bounded by the message length: a malformed TLV makes the parser read (and write) past the message.

### Threads

USB thread `sub_4030FC` waits on 2 events given to the USB function by [IOCTL 0x808520C0](#ioctl-0x808520c0):  
| Event | Action |
|-------|--------|
| +0x38 (D0) | +0xE1 = 1. Unless the SMD channel is closed, sends [internal IOCTL 0x2201F](#internal-ioctl-0x2201f-0x22027) (DTR = 1). +0x94 = 1 (USB active); if the USB side is ready (+0x95), posts the data reads (collection +0x18) and the control reads (collection +0x14) |
| +0x48 (D3) | +0xE1 = 0. Unless the SMD channel is closed, sends [internal IOCTL 0x22027](#internal-ioctl-0x2201f-0x22027) (DTR = 0). +0x94 = 0 |

SMD thread `sub_402728` waits on the 2 events given by [internal IOCTL 0x22003](#internal-ioctl-0x22003):  
| Event | Set by qcsmd8930.sys on | Action |
|-------|-------------------------|--------|
| +0xBC | channel event 9 (remote close ?), 0x22003 offset `18` | +0xE0 = 1 (channel closed): the control requests are no longer re-posted |
| +0xCC | channel event 1 (open), 0x22003 offset `14` | Only if +0xE0 is set: empties the collections +0x1C, +0x14, +0x70, +0x78, +0x20 and +0x18, clears +0xE0, then sends 0x2201F (DTR = 1) if USB is in D0 (+0xE1), otherwise 0x22027 (DTR = 0) |

Downlink thread `sub_403A18` waits on the synchronization event +0x5C, see [Data path](#data-path-ip-packets).

### Device context

`DEVICE_CONTEXT`, from the code:  
| Offset | Content |
|--------|---------|
| 0x00 | `WDFDEVICE` |
| 0x04 | `WDFIOTARGET` `\Device\SMD` |
| 0x08 | `WDFIOTARGET` `\Device\USB_RMNET` |
| 0x0C | `WDFIOTARGET` `\Device\DMUX` |
| 0x10 | `WDFIOTARGET` USB data interface `{CEC7D47F-…}` |
| 0x14 | `WDFCOLLECTION` free USB control reads (10 × 1 KB) |
| 0x18 | `WDFCOLLECTION` free USB data reads (3 × 32 KB) |
| 0x1C | `WDFCOLLECTION` SMD reads (10 × 1 KB) |
| 0x20 | `WDFCOLLECTION` free USB data write (1 × 32 KB) |
| 0x24 | `WDFSPINLOCK` of +0x20 |
| 0x28 | `WDFSPINLOCK` of +0x70 |
| 0x2C | BOOLEAN USB RmNet interface present |
| 0x2D | BOOLEAN USB data interface open |
| 0x30, 0x34 | PnP notification entries (USB RmNet, USB data) |
| 0x38 | `KEVENT` USB D0 |
| 0x48 | `KEVENT` USB D3 |
| 0x58 | Handle of the USB thread |
| 0x5C | `KEVENT` downlink work (synchronization) |
| 0x6C | Handle of the downlink thread |
| 0x70 | `WDFCOLLECTION` received downlink packets |
| 0x74 | Number of `WDFMEMORY` wrappers created (max 100) |
| 0x78 | `WDFCOLLECTION` free wrappers |
| 0x7C-0x7F | TLP flags, see [QMI rewriting](#qmi-rewriting) |
| 0x80 | ULONG 9, input of [internal IOCTL 0x2AC016](#internal-ioctl-0x2ac016) |
| 0x84 | ULONG 8, input of [internal IOCTL 0x2AC011](#internal-ioctl-0x2ac011) |
| 0x88, 0x8C | `WDFMEMORY` on +0x80, +0x84 |
| 0x90 | `KSPIN_LOCK` of +0x94/+0x95 |
| 0x94 | BOOLEAN USB active (D0) |
| 0x95 | BOOLEAN USB side ready |
| 0x98, 0xA0 | PnP notification entries (SMD, DMUX) |
| 0x9C | BOOLEAN SMD interface present |
| 0x9D | BOOLEAN DMUX ready interface present |
| 0xA4 | BAM DMUX `INTERFACE` (24 bytes): +0xB4 give back an RX buffer, +0xB8 `BamMuxWrite` |
| 0xBC | `KEVENT` SMD remote close |
| 0xCC | `KEVENT` SMD channel open |
| 0xDC | Handle of the SMD thread |
| 0xE0 | BOOLEAN SMD channel closed by the modem |
| 0xE1 | BOOLEAN USB in D0 (for the DTR signal) |

---

### IOCTL 0x808520C0

This IOCTL is sent by Qcrmnetbridge8930.sys to `\Device\USB_RMNET` (`sub_402F68`). Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x830 (2096) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set power events | \Device\USB_RMNET | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT` `phHardwareEnterD0Event` (context +0x38): set when the USB RmNet function becomes active |
| 04-07 | ? | `PKEVENT` `phHardwareEnterD3Event` (context +0x48): set when it's suspended / disconnected |

Same IOCTL, same buffer and same assert (`usbOpenParams.phHardwareEnterD0Event && usbOpenParams.phHardwareEnterD3Event`, `rmnbrgusb.c`) as in [qcmbrg8930.sys](./qcmbrg8930.md#ioctl-0x808520c0) and [qcdiagrouter8930.sys](./qcdiagrouter8930.md#ioctl-0x808520c0). Kernel mode only: the buffer contains kernel pointers.

---

### IOCTL 0x808520CD

This IOCTL is sent by Qcrmnetbridge8930.sys to `\Device\USB_RMNET` (`sub_4023D8`). Asynchronous, the request is one of the 10 SMD read requests.

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x833 (2099) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Send a QMI response to the host ? | \Device\USB_RMNET | ≤ 1024 (+4) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | e.g. 01 … | QMUX message read from `DATA40_CNTL`, after [rewriting](#qmi-rewriting). The length is the length read, + 4 per appended TLV |

Probably delivered to the host as a CDC `GET_ENCAPSULATED_RESPONSE` (after a `RESPONSE_AVAILABLE` notification) ?

---

### IOCTL 0x808520D2

This IOCTL is sent by Qcrmnetbridge8930.sys to `\Device\USB_RMNET` (`sub_4035CC`). Asynchronous, 10 requests are kept pending.

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x834 (2100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_OUT_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a QMI request from the host ? | \Device\USB_RMNET | 0 | 1024 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | e.g. 01 … | QMUX message sent by the USB host (CDC `SEND_ENCAPSULATED_COMMAND` ?). Length in `Information` |

The completion routine `sub_40369C` inspects the message and writes it to the SMD channel `DATA40_CNTL`, see [Control path](#control-path-qmi).

---

### internal IOCTL 0x2AC011

This IOCTL is sent by Qcrmnetbridge8930.sys to the USB data interface `{CEC7D47F-A1E1-4607-A693-9A0061465DB7}` (downlink thread `sub_403A18`). Asynchronous, one request at a time.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x4 (4) |
| Access | READ_AND_WRITE |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Bulk transfer to the host ? | `{CEC7D47F-…}` | 4 | ≤ 32768 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 08 00 00 00 | Pipe / endpoint ? (context +0x84) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | IP packet(s) from the modem. With downlink TLP: `[USHORT length \| 0xF800][packet]` repeated. Despite METHOD_IN_DIRECT, the data is in the "output" memory (`WdfIoTargetFormatRequestForInternalIoctl` OutputBuffer, offset 0, length = data length) |

---

### internal IOCTL 0x2AC016

This IOCTL is sent by Qcrmnetbridge8930.sys to the USB data interface `{CEC7D47F-A1E1-4607-A693-9A0061465DB7}` (`sub_40329C`). Asynchronous, 3 requests are kept pending.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x5 (5) |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Bulk transfer from the host ? | `{CEC7D47F-…}` | 4 | 32768 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 09 00 00 00 | Pipe / endpoint ? (context +0x80) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | IP packet(s) from the host, length in `Information`. With uplink TLP done by the bridge: `[USHORT length][packet]` repeated |

The completion routine `sub_403370` sends the packets to BAM DMUX, see [Data path](#data-path-ip-packets).

---

### IOCTLs sent to qcsmd8930.sys

### internal IOCTL 0x22003

This IOCTL is sent by Qcrmnetbridge8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) (`sub_40217C`, disassembly only). Synchronous (`WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`), without timeout.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Open a SMD channel | \Device\SMD | 28 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the ANSI channel name `DATA40_CNTL` (0x40424C) |
| 04-07 | 00 00 00 00 | Edge 0 (APPS↔MODEM) |
| 08-0B | 01 00 00 00 | Flags 0x01 (packet mode, no wait for the remote side) |
| 0C-0F | e.g. 00 20 00 00 | FIFO size, registry value `SmdFifoSize` (default 8 KB) |
| 10-13 | 00 00 00 00 | No "data received" event: the reads are always pending |
| 14-17 | ? | `PKEVENT` context +0xCC, set when the channel is opened |
| 18-1B | ? | `PKEVENT` context +0xBC, set on remote close ? |

Unlike qcmbrg8930.sys, no [internal IOCTL 0x2200F](./qcsmd8930.md#internal-ioctl-0x2200f) is sent: the modem's signals are ignored. The status of the IOCTL isn't checked: the SMD reads are posted anyway.

---

### internal IOCTL 0x2201F, 0x22027

These IOCTLs are sent by Qcrmnetbridge8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) (`sub_402654`, disassembly only), synchronously, with a new request each time. No buffers.

| IOCTL | Function | Signal | Value | Sent when |
|-------|----------|--------|-------|-----------|
| 0x2201F | 0x807 | 0 (DTR/DSR) | 1 | USB D0 event, or channel reopened while USB is in D0 |
| 0x22027 | 0x809 | 0 (DTR/DSR) | 0 | USB D3 event, or channel reopened while USB is not in D0 |

Device 0x2, FILE_ANY_ACCESS, METHOD_NEITHER. Nothing is sent while the channel is closed by the modem. The DTR signal tells the modem that the USB RmNet host is connected (as the `DTR` of Linux `u_ctrl_smd` ?).

---

### IOCTLs sent to qcbamdmux8930.sys

### internal IOCTL 0x82003

This IOCTL is sent by Qcrmnetbridge8930.sys to [qcbamdmux8930.sys](./qcbamdmux8930.md#internal-ioctl-0x82003) (`sub_40120C`, disassembly only). Synchronous (`WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`).

| Property | Value |
|----------|-------|
| Device | 0x8 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Open channel | \Device\DMUX | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | Stream 2 |
| 04-07 | 08 00 00 00 | Channel 8 (`BAM_DMUX_USB_RMNET_0` in Linux) |
| 08-0B | ? | RX callback `sub_401394` (kernel address) |
| 0C-0F | ? | Callback context = the device context |

When the request succeeds, the [BAM DMUX interface](./qcbamdmux8930.md#bam-dmux-interface) is queried with `WdfIoTargetQueryForInterface`; both functions are used: offset 0x10 to give back the RX buffers, offset 0x14 (`BamMuxWrite`) to send the uplink packets.

---

### Other GUID

USB RmNet control interface, registered by the USB function driver that creates `\Device\USB_RMNET`  
`{96F30BBF-0C5E-40F6-8A12-FFDCF265FF73}`

USB data interface (bulk transfers, internal IOCTLs 0x2AC011 / 0x2AC016), USB function driver ?  
`{CEC7D47F-A1E1-4607-A693-9A0061465DB7}`

SMD interface (`SMD_DEVICE_INTERFACE_GUID`) of [qcsmd8930.sys](./qcsmd8930.md)  
`{F9D15453-8335-434C-AA72-FCD925F135F3}`

BAM DMUX "ready" interface (`DMUX_DEVICE_INTERFACE_GUID` in the asserts) of [qcbamdmux8930.sys](./qcbamdmux8930.md#interface-guid)  
`{CCCB7664-4951-40C3-8EB1-FDA3964A4479}`

BAM DMUX query-interface of [qcbamdmux8930.sys](./qcbamdmux8930.md#bam-dmux-interface)  
`{EA38864C-56D4-4426-B145-AC2E39C2BB72}`

GUID_DEVICE_INTERFACE_ARRIVAL  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
