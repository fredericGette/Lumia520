## Qcmbrg8930.sys

Qualcomm modem bridge ("MBRG"): connects the USB modem function to the modem's SMD channel `DATA2`.  
It copies bytes in both directions between `\Device\USB_MODEM_BRIDGE` (USB function, interface `{FE132432-112D-49EC-9178-A9512BB79217}`) and the SMD channel `DATA2` on edge 0 (APPS↔MODEM) of [qcsmd8930.sys](./qcsmd8930.md). It also bridges the RS-232-like control lines: DTR/RTS set by the USB host are forwarded to the modem as SMD signals, and the modem's DSR is reported back to the USB host. This is what a PC sees as the phone's "modem" COM port (AT commands / dial-up data), when the USB function exposes it.  
It is a KMDF driver without any `\Device\` object, symbolic link, queue or device interface of its own: it receives no IOCTL. Everything happens in two system threads and in request completion routines.  
PDB path `P:\MBRG\rel\8.2.1.1\arm\Release\qcmbrg8930.pdb`; source file names found in asserts: `mbrgdevice.c`, `mbrgsmd.c`, `mbrgusb.c`. Pool tag of the WDF memory: `mbrg`. There are no log messages (no ETW, no `DbgPrint`), only `RtlAssert` in checked mode.

ACPI device `\_SB.MBRG` (`_HID` `QCOM2145`, nothing else: no `_UID`, no resources, no `_DEP`).

There's no named `\Device\` object and no symbolic link.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM2145\<instance>`  

There's no parameters in the registry.

GUID of the ETW provider:  
None.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Interface `{F9D15453-8335-434C-AA72-FCD925F135F3}`. Channel `DATA2`, edge 0 (APPS↔MODEM). Internal IOCTLs, see [IOCTLs sent to qcsmd8930.sys](#ioctls-sent-to-qcsmd8930sys), plus read/write requests |
| \Device\USB_MODEM_BRIDGE | USB modem function driver ? | Interface `{FE132432-112D-49EC-9178-A9512BB79217}`. [IOCTL 0x808520C0](#ioctl-0x808520c0), [IOCTL 0x808520C4](#ioctl-0x808520c4), [IOCTL 0x808520C8](#ioctl-0x808520c8), plus read/write requests |

Both targets are opened by name with `WdfIoTargetOpen` (`DesiredAccess` 0x1F0000 = `FILE_ALL_ACCESS`; share mode read/write for `\Device\SMD`, none for `\Device\USB_MODEM_BRIDGE`). The I/O targets themselves are created in `EvtDriverDeviceAdd` (`sub_40702C`, context +0x04 = SMD, +0x08 = USB).

### Start sequence

1. `DriverEntry`: `WdfDriverCreate` only.
2. `EvtDriverDeviceAdd` (`sub_40702C`): PnP/power callbacks `EvtDeviceSelfManagedIoInit` (0x401008), `EvtDeviceSelfManagedIoSuspend` (0x407140, does nothing) and `EvtDeviceSelfManagedIoRestart` (= `EvtDeviceSelfManagedIoInit`), `WdfDeviceCreate`, 2 `WdfIoTargetCreate`, `KeInitializeSemaphore` (+0xE8, count 0, limit 1).
3. `EvtDeviceSelfManagedIoInit`: two `IoRegisterPlugPlayNotification` (`EventCategoryDeviceInterfaceChange`, `PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`):
   - USB modem interface `{FE132432-…}`, callback `sub_4020D4`, flag +0x44;
   - SMD interface `{F9D15453-…}`, callback `sub_401338`, flag +0x7C.

   On `GUID_DEVICE_INTERFACE_ARRIVAL` `{CB3A4004-46F0-11D0-B08F-00609713053F}` the callback sets its flag; on any other event it clears it. When the flag goes from 0 to 1 and both flags are set, `sub_40114C` starts the bridge: first the USB side (`sub_402014`), then the SMD side (`sub_4011DC`).
4. USB side (`sub_402014`, `mbrgusb.c`):
   1. `sub_40219C`: opens `\Device\USB_MODEM_BRIDGE`.
   2. `sub_402214`: creates 2 USB read requests (+0x0C, +0x10) and 2 USB write requests (+0x34, +0x38), each with a 32 KB (0x8000) buffer, and 2 collections (+0x3C completed SMD reads, +0x40 completed USB reads).
   3. `sub_4024BC`: initialises the events +0x4C (D0), +0x5C (D3), +0xA4, +0xB4, sends [IOCTL 0x808520C0](#ioctl-0x808520c0) synchronously, and starts the USB thread `sub_402614`.
5. SMD side (`sub_4011DC`, `mbrgsmd.c`):
   1. `sub_401400`: opens `\Device\SMD`.
   2. `sub_401474`: creates 4 SMD read requests (+0x24…+0x30) and 4 SMD write requests (+0x14…+0x20), each with an 8 KB (0x2000) buffer.
   3. `sub_401684`: sends [internal IOCTL 0x2200F](#internal-ioctl-0x2200f) then [internal IOCTL 0x22003](#internal-ioctl-0x22003) (open `DATA2`), and starts the SMD thread `sub_40195C`.
   4. Posts the 4 SMD reads (`sub_401C3C`) and the 2 USB reads (`sub_4027B0`), then releases the semaphore +0xE8.

`EvtDeviceSelfManagedIoRestart` is the same function as `EvtDeviceSelfManagedIoInit`: on a restart the two PnP notifications are registered again. They are never unregistered, the threads never exit and nothing is freed (there's no cleanup or release callback).

### Data path

| Direction | Read | Completion | Write |
|-----------|------|------------|-------|
| Modem → USB | 4 pending SMD reads, 8 KB each (`sub_401C3C`) | `sub_401CF4`: adds the request to the collection +0x3C, sets event +0xA4 | SMD thread, `sub_401D54`: takes a free USB write request, concatenates all completed SMD reads in its 32 KB buffer (a read that doesn't fit is dropped), re-posts the SMD reads, writes to USB. Completion `sub_402C58` frees the request and sets +0xA4 again |
| USB → Modem | 2 pending USB reads, 32 KB each (`sub_4027B0`) | `sub_402BC4`: adds the request to the collection +0x40, sets event +0xB4. On `STATUS_PIPE_NOT_AVAILABLE` (0xC00000AC) or `STATUS_CANCELLED` (0xC0000120) the request is only marked free | USB thread, `sub_402CD0`: does nothing while the modem has closed the channel (+0xC4); otherwise takes a free SMD write request, concatenates all completed USB reads (up to 32 KB), re-posts the USB reads, writes to SMD. Completion `sub_401EC8` frees the request and sets +0xB4 again |

> [!NOTE]
> The SMD write requests have an 8 KB buffer but `sub_402CD0` accepts up to 32 KB of USB data: `WdfMemoryCopyFromBuffer` fails when more than 8 KB are pending (its status isn't checked) and the write then sends the old content of the buffer ?

Each request context (`REQUEST_CONTEXT`) holds the `WDFMEMORY` (+0x00) and a state (+0x04): 0 = free, 1 = write pending, 2 = read pending.

### Threads

USB thread `sub_402614` waits on 3 events:  
| Event | Set by | Action |
|-------|--------|--------|
| +0x4C (D0) | USB function driver, given by [IOCTL 0x808520C0](#ioctl-0x808520c0) | +0x6C = 1 (USB active). Sends [IOCTL 0x808520C8](#ioctl-0x808520c8) (wait for control line state), waits for the semaphore +0xE8 (SMD side ready), posts the free USB reads, releases the semaphore |
| +0x5C (D3) | USB function driver | +0x6C = 0. Sends [internal IOCTL 0x22027](#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) (DTR = 0) to SMD |
| +0xB4 | USB read/SMD write completion | `sub_402CD0`, USB → modem copy |

SMD thread `sub_40195C` waits on 5 events:  
| Index | Event | Set by qcsmd8930.sys on | Action |
|-------|-------|-------------------------|--------|
| 0 | +0x80 | channel event 6 (CTS change ?), [0x2200F](#internal-ioctl-0x2200f) offset `04` | None, the event is only cleared |
| 1 | +0x90 | channel event 5 (DSR change ?), [0x2200F](#internal-ioctl-0x2200f) offset `00` | Sends [internal IOCTL 0x2202F](#internal-ioctl-0x2202f) (read the modem's DTR/DSR signal), copies the result to bit 1 of the serial state +0x74, sends it to USB with [IOCTL 0x808520C4](#ioctl-0x808520c4) |
| 2 | +0xA4 | (internal) SMD read/USB write completion | `sub_401D54`, modem → USB copy |
| 3 | +0xC8 | channel event 9 (remote close ?), [0x22003](#internal-ioctl-0x22003) offset `18` | +0xC4 = 1: USB → modem copy suspended |
| 4 | +0xD8 | channel event 1 (open), [0x22003](#internal-ioctl-0x22003) offset `14` | If +0xC4 was set (reopen after a close): clears it, re-posts the completed USB reads (their data is discarded), then sends [IOCTL 0x808520C8](#ioctl-0x808520c8) if USB is active, otherwise [internal IOCTL 0x22027](#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) (DTR = 0) (`sub_401B78`) |

### Control lines

Serial state word (context +0x74), sent to USB with [IOCTL 0x808520C4](#ioctl-0x808520c4):  
| Bit | Source | Meaning |
|-----|--------|---------|
| 0x0001 | USB host DTR ([IOCTL 0x808520C8](#ioctl-0x808520c8) bit 0) | DCD (`bRxCarrier` of the CDC `SERIAL_STATE` notification) ? |
| 0x0002 | Modem DTR/DSR signal ([internal IOCTL 0x2202F](#internal-ioctl-0x2202f)) | DSR (`bTxCarrier` of the CDC `SERIAL_STATE` notification) ? |

USB host → modem (completion `sub_402970` of [IOCTL 0x808520C8](#ioctl-0x808520c8)):  
| Bit of the USB line state | Set | Clear |
|---------------------------|-----|-------|
| 0x01 (DTR) | [0x2201F](#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) (signal 0 = 1) | [0x22027](#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) (signal 0 = 0) |
| 0x02 (RTS) | [0x22023](#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) (signal 1 = 1) | [0x2202B](#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) (signal 1 = 0) |

The bit layout matches the USB CDC `SET_CONTROL_LINE_STATE` request (bit 0 DTR, bit 1 RTS).

### Device context

`DEVICE_CONTEXT`, from the code:  
| Offset | Content |
|--------|---------|
| 0x00 | `WDFDEVICE` |
| 0x04 | `WDFIOTARGET` `\Device\SMD` |
| 0x08 | `WDFIOTARGET` `\Device\USB_MODEM_BRIDGE` |
| 0x0C-0x10 | 2 USB read requests (32 KB) |
| 0x14-0x20 | 4 SMD write requests (8 KB) |
| 0x24-0x30 | 4 SMD read requests (8 KB) |
| 0x34-0x38 | 2 USB write requests (32 KB) |
| 0x3C | `WDFCOLLECTION` completed SMD reads |
| 0x40 | `WDFCOLLECTION` completed USB reads |
| 0x44 | BOOLEAN USB interface present / target open |
| 0x48 | PnP notification entry (USB) |
| 0x4C | `KEVENT` USB D0 |
| 0x5C | `KEVENT` USB D3 |
| 0x6C | BOOLEAN USB active (D0) |
| 0x70 | Handle of the USB thread |
| 0x74 | USHORT serial state, see [Control lines](#control-lines) |
| 0x78 | PnP notification entry (SMD) |
| 0x7C | BOOLEAN SMD interface present |
| 0x80 | `KEVENT` CTS change ? |
| 0x90 | `KEVENT` DSR change ? |
| 0xA0 | Handle of the SMD thread |
| 0xA4 | `KEVENT` modem → USB work |
| 0xB4 | `KEVENT` USB → modem work |
| 0xC4 | BOOLEAN channel closed by the modem |
| 0xC8 | `KEVENT` remote close |
| 0xD8 | `KEVENT` channel open |
| 0xE8 | `KSEMAPHORE` SMD side ready |

---

### IOCTL 0x808520C0

This IOCTL is sent by Qcmbrg8930.sys to `\Device\USB_MODEM_BRIDGE` (`sub_4024BC`). Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x830 (2096) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set power events | \Device\USB_MODEM_BRIDGE | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT` `phHardwareEnterD0Event` (context +0x4C): set when the USB modem function becomes active |
| 04-07 | ? | `PKEVENT` `phHardwareEnterD3Event` (context +0x5C): set when it's suspended / disconnected |

Same IOCTL and same buffer as the one sent by [qcdiagrouter8930.sys](./qcdiagrouter8930.md#ioctl-0x808520c0) to `\Device\USB_DIAG`; the names come from the same assert (`usbOpenParams.phHardwareEnterD0Event && usbOpenParams.phHardwareEnterD3Event`, `mbrgusb.c`). Kernel mode only: the buffer contains kernel pointers.

---

### IOCTL 0x808520C4

This IOCTL is sent by Qcmbrg8930.sys to `\Device\USB_MODEM_BRIDGE` (`sub_402AA4`). Asynchronous, the request is deleted by its completion routine (`sub_402BA4`).

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x831 (2097) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set serial state ? | \Device\USB_MODEM_BRIDGE | 2 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | e.g. 03 00 | Serial state (context +0x74). Bit 0x01 DCD ?, bit 0x02 DSR ?, see [Control lines](#control-lines) |

Sent each time the state changes: on a DSR change from the modem and on each line state change from the USB host.

---

### IOCTL 0x808520C8

This IOCTL is sent by Qcmbrg8930.sys to `\Device\USB_MODEM_BRIDGE` (`sub_402874`). Asynchronous, it stays pending until the USB host changes the control lines.

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x832 (2098) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for control line state ? | \Device\USB_MODEM_BRIDGE | 0 | 2 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | e.g. 03 00 | Line state set by the USB host. Bit 0x01 DTR, bit 0x02 RTS (CDC `SET_CONTROL_LINE_STATE`) |

The completion routine `sub_402970` copies DTR to bit 0 of the serial state, sends [IOCTL 0x808520C4](#ioctl-0x808520c4), sends the matching signal IOCTLs to SMD (see [Control lines](#control-lines)), and re-sends the same request unless it completed with `STATUS_CANCELLED` (0xC0000120). The status of the request isn't checked otherwise: the buffer is parsed even when it failed.

---

### IOCTLs sent to qcsmd8930.sys

These internal IOCTLs are sent by Qcmbrg8930.sys to `\Device\SMD` ([qcsmd8930.sys](./qcsmd8930.md)). They are METHOD_NEITHER and the buffers contain kernel pointers.  
| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| [0x2200F](#internal-ioctl-0x2200f) Set the signal events | \Device\SMD | 8 | 0 |
| [0x22003](#internal-ioctl-0x22003) Open `DATA2` | \Device\SMD | 28 | 0 |
| [0x2202F](#internal-ioctl-0x2202f) Get signal 0 (DTR/DSR) | \Device\SMD | 0 | 0 |
| [0x2201F, 0x22023, 0x22027, 0x2202B](#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) Set signal 0/1 | \Device\SMD | 0 | 0 |

### internal IOCTL 0x2200F

This IOCTL is sent by Qcmbrg8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x2200f) (`sub_401684`), before 0x22003. Synchronous (`WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`).

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x803 (2051) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set the signal events | \Device\SMD | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT` context +0x90, set on a DSR change ? (SMD thread index 1) |
| 04-07 | ? | `PKEVENT` context +0x80, set on a CTS change ? (SMD thread index 0, ignored) |

---

### internal IOCTL 0x22003

This IOCTL is sent by Qcmbrg8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) (`sub_401684`). Synchronous, without timeout.

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
| 00-03 | ? | Pointer to the ANSI channel name `DATA2` (0x4033D4) |
| 04-07 | 00 00 00 00 | Edge 0 (APPS↔MODEM) |
| 08-0B | 01 00 00 00 | Flags 0x01 (packet mode, no wait for the remote side) |
| 0C-0F | 00 20 00 00 | FIFO size 8 KB |
| 10-13 | 00 00 00 00 | No "data received" event: the reads are always pending |
| 14-17 | ? | `PKEVENT` context +0xD8, set when the channel is opened |
| 18-1B | ? | `PKEVENT` context +0xC8, set on remote close ? |

If the IOCTL fails, the SMD thread isn't started, but the SMD and USB reads are still posted.

---

### internal IOCTL 0x2202F

This IOCTL is sent by Qcmbrg8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x2202f-0x22033) (SMD thread `sub_40195C`), each time the event +0x90 is set. Synchronous, the same request object is reused.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x80B (2059) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get signal 0 (DTR/DSR) of the modem | \Device\SMD | 0 | 0 |

The value is read from `Information` (`WdfRequestGetInformation`): ≠ 0 sets bit 0x02 of the serial state, 0 clears it. Then [IOCTL 0x808520C4](#ioctl-0x808520c4) is sent.

---

### internal IOCTL 0x2201F, 0x22023, 0x22027, 0x2202B

These IOCTLs are sent by Qcmbrg8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x2201f-0x22023-0x22027-0x2202b) (`sub_401F40`), synchronously, with a new request each time. No buffers.

| IOCTL | Function | Signal | Value | Sent when |
|-------|----------|--------|-------|-----------|
| 0x2201F | 0x807 | 0 (DTR/DSR) | 1 | USB host sets DTR |
| 0x22023 | 0x808 | 1 (RTS/CTS) | 1 | USB host sets RTS |
| 0x22027 | 0x809 | 0 (DTR/DSR) | 0 | USB host clears DTR, USB D3 event, channel reopened while USB is inactive |
| 0x2202B | 0x80A | 1 (RTS/CTS) | 0 | USB host clears RTS |

Device 0x2, FILE_ANY_ACCESS, METHOD_NEITHER.

---

### Other GUID

USB modem bridge interface (`USB_MODEM_INTERFACE_GUID`), registered by the USB function driver that creates `\Device\USB_MODEM_BRIDGE`  
`{FE132432-112D-49EC-9178-A9512BB79217}`

SMD interface (`SMD_DEVICE_INTERFACE_GUID`) of [qcsmd8930.sys](./qcsmd8930.md)  
`{F9D15453-8335-434C-AA72-FCD925F135F3}`

GUID_DEVICE_INTERFACE_ARRIVAL  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
