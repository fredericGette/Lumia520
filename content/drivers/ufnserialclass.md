## Ufnserialclass.sys

USB function serial class driver (Qualcomm, "QC USB FN"): a USB CDC ACM–style serial port on the device side of the USB link.  
It is the KMDF function driver of a USB *function* interface (a `USBFN\<interface>` child of the USB function controller `ACPI\QCOM01C0\1`, like [genericusbfnclass.sys](./genericusbfnclass.md)), but unlike the generic class driver it implements the protocol itself: it handles the CDC class requests received on the control endpoint (`SET_LINE_CODING`, `SET_CONTROL_LINE_STATE`, `SEND_ENCAPSULATED_COMMAND`, …), turns `ReadFile` / `WriteFile` into transfers on the bulk OUT / bulk IN pipes, and sends the CDC notifications (`SERIAL_STATE`, `RESPONSE_AVAILABLE`) on the interrupt IN pipe. Everything goes to the lower driver (USB function class extension, UFX ?) as `IOCTL_INTERNAL_USBFN_*` requests.  
Its client opens the device exclusively and uses 5 private IOCTLs (`IOCTL_USB_OPEN_PORT`, …) to get the connect / disconnect events, the DTR/RTS state, and to exchange the encapsulated commands / responses. [IOCTL_USB_OPEN_PORT](#ioctl-0x808520c0--ioctl_usb_open_port) passes kernel `KEVENT` pointers, so the client must be a kernel-mode driver ?  
Which USB function interfaces it serves is not in the binary: the interfaces of `SerialCompositeConfig` (`MODEM_SER`, `NMEA_SER`, `TRACE`, `DIAG`, see the [USB function configuration](./genericusbfnclassipoverusb.md#usb-function-configuration)) are the likely candidates ?  
Built `Mar 24 2014 19:51:04`. PDB: `P:\ufnserialclass\rel\8.2.1\arm\Release\ufnserialclass.pdb` (same build tree as [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md)). KMDF 1.11. Imports only `ntoskrnl.exe`, `HAL.dll` (`KeGetCurrentIrql`) and `WDFLDR.SYS`. MD5 `3629f1890b64b2e9af1ac6bf2bd9f361`, 33280 bytes.  
Strings in the binary use the prefix `UsbGx` (`UsbGxDeviceCreate`) and the pool tag `Ugxc` (0x63786755) for all its `WdfMemoryCreate` buffers.

Device name : first string of the registry value `DeviceNames` (see below), not hardcoded  
There's no symbolic link (`WdfDeviceCreateSymbolicLink` is not called).  
Device interface : first string of the registry value `DeviceInterfaceGUIDs`, not hardcoded  

Registry key of the device instance (`WdfFdoInitOpenRegistryKey`, `PLUGPLAY_REGKEY_DEVICE` = `HKLM\SYSTEM\CurrentControlSet\Enum\USBFN\<interface>\<instance>\Device Parameters`, `KEY_QUERY_VALUE`):  
| Registry value | value | comment |
|----------------|-------|---------|
| DeviceNames | ? | REG_MULTI_SZ, `WdfRegistryQueryMultiString`. Only the first string is used: name of the device object (`WdfDeviceInitAssignName`), e.g. `\Device\<name>` ? |
| DeviceInterfaceGUIDs | ? | REG_MULTI_SZ. Only the first string is used: `RtlGUIDFromString` (with braces) then `WdfDeviceCreateDeviceInterface` (no reference string) |

Any failure (key missing, value missing, bad GUID) makes `EvtDriverDeviceAdd` fail, so both values are mandatory. They are presumably written by the INF of each serial interface ?

GUID of the ETW provider (WPP):  
`{d5393b53-8aae-40b1-938b-c207e999605f}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device of its stack (`WdfDeviceGetIoTarget`) = PDO `USBFN\<interface>`, child of `ACPI\QCOM01C0\1` | USB function class extension [usbfnclx.sys](./usbfnclx.md) / controller driver [usbfnchipidea.sys](./usbfnchipidea.md) | Receives all the `IOCTL_INTERNAL_USBFN_*`, see [IOCTLs sent](#ioctls-sent) |

### WDF configuration

`DriverEntry` (0x40B008): WPP registration, then `WdfDriverCreate` with only `EvtDriverDeviceAdd` (0x409E40 → `sub_409008`).

`EvtDriverDeviceAdd` (`sub_409008`):
- PnP/power callbacks: `EvtDevicePrepareHardware` (`sub_402D70`), `EvtDeviceD0Entry` (`sub_4030E0`), `EvtDeviceD0Exit` (`sub_40320C`).
- File object: `EvtDeviceFileCreate` (`sub_403384`), `EvtFileClose` (`sub_403440`), `EvtFileCleanup` (`sub_4034B8`), `AutoForwardCleanupClose` = `WdfUseDefault`, `FileObjectClass` = `WdfFileObjectWdfCannotUseFsContexts`, context `FILE_OBJECT_CONTEXT`.
- `WdfDeviceInitSetExclusive(TRUE)`: only one open handle at a time.
- `DeviceNames` → `WdfDeviceInitAssignName`, `WdfDeviceInitSetIoType(WdfDeviceIoDirect)`, `WdfDeviceCreate` (context `DEVICE_CONTEXT`), `DeviceInterfaceGUIDs` → `WdfDeviceCreateDeviceInterface`.
- Creates the collections, wait locks and spin locks of the device context, then the queues (`sub_409E54`):

| Queue | Context offset | Dispatch | Callbacks | Usage |
|-------|----------------|----------|-----------|-------|
| default | 0x268 | Sequential, `PowerManaged` = `WdfFalse` | `EvtIoDeviceControl` (`EvtWdfIoQueueIoDeviceControl`, 0x403794) | Private IOCTLs |
| read | 0x26C | Parallel | `EvtIoRead` (0x404820), `EvtIoStop` (0x40463C) | `IRP_MJ_READ` |
| write | 0x270 | Parallel | `EvtIoWrite` (0x404A30), `EvtIoStop` | `IRP_MJ_WRITE` |
| manual | 0x274 | Manual | `EvtIoCanceledOnQueue` (`sub_404744`) | Pending `IOCTL_USB_GET_CONTROL_LINE_STATE` |
| manual | 0x278 | Manual | `EvtIoCanceledOnQueue` | Pending `IOCTL_USB_GET_ENCAPSULATED_COMMAND` |
| manual | 0x27C | Manual | `EvtIoCanceledOnQueue` | Pending `IOCTL_USB_SEND_RESPONSE` (waiting for the host's `GET_ENCAPSULATED_RESPONSE`) |

A request cancelled while parked in a manual queue is completed with `STATUS_CANCELLED` (0xC0000120).

- `WdfDeviceAssignS0IdleSettings` with the defaults of `WDF_DEVICE_POWER_POLICY_IDLE_SETTINGS_INIT(IdleCanWakeFromS0)` (`DxState` = `PowerDeviceMaximum`, `IdleTimeout` default, user control allowed), then `WdfDeviceAssignSxWakeSettings` (`DxState` = `PowerDeviceMaximum`, `UserControlOfWakeSettings` = `WakeAllowUserControl`, `Enabled` = `WdfTrue`). A failure is only traced with `DbgPrint` ("UsbGxDeviceCreate: Failed to set S0 idle settings: 0x%08X" / "…Failed to set wake settings.") but is returned by `EvtDriverDeviceAdd`.

The device is kept in D0 while the USB function is configured: on the transition to `UsbfnDeviceStateConfigured` it calls `WdfDeviceStopIdleNoTrack`, and `WdfDeviceResumeIdleNoTrack` when leaving that state (`sub_401554`).

`DEVICE_CONTEXT` (0x2A4 bytes ?, offsets checked in the binary):  
| Offset | Comment |
|--------|---------|
| 0x000 | `WDFDEVICE` |
| 0x004-0x22B | `USBFN_CLASS_INFORMATION_PACKET` (552 bytes) returned by [internal IOCTL 0x2AC022](#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info). 0x0C8 = high-speed `InterfaceNumber` (used as `wIndex` of the notifications), 0x0C9 = high-speed `PipeCount`, 0x0CC = high-speed `PipeArr`, 0x18C = `InterfaceName` (WCHAR, printed in the traces) |
| 0x22C-0x237 | `USBFN_NOTIFICATION` (12 bytes) filled by the bus event notification: 0x22C `Event`, 0x230 setup packet / configuration value |
| 0x238 | Current `USBFN_DEVICE_STATE` |
| 0x23C | Previous `USBFN_DEVICE_STATE` (restored on resume) |
| 0x244 / 0x248 | `WDFCOLLECTION` + `WDFWAITLOCK`: last control line state received (one 2-byte `WDFMEMORY`) |
| 0x24C / 0x250 | `WDFWAITLOCK` + `WDFCOLLECTION`: received encapsulated commands (FIFO of `WDFMEMORY`) |
| 0x254 / 0x258 | `WDFCOLLECTION` + `WDFSPINLOCK`: requests sent to the lower driver (read, write, serial state), cancelled by `EvtIoStop` |
| 0x25C / 0x260 | `WDFCOLLECTION` + `WDFSPINLOCK`: private IOCTL requests pending in the manual queues |
| 0x264 | `WDFFILEOBJECT` of the open handle (set by `EvtDeviceFileCreate`, cleared by `EvtFileClose`) |
| 0x268-0x27C | Queues, see above |
| 0x280 | WORD, last `SERIAL_STATE` value sent |
| 0x284 | `WDFCOLLECTION` of the pipes: one `WDFMEMORY` per `PipeArr` entry (`WdfMemoryCreatePreallocated` on its 4-byte `PipeId`), same order as `PipeArr` |
| 0x288 | `WDFREQUEST` reused for the bus event notification |
| 0x28C | `HANDLE` of the bus event system thread |
| 0x290 | `KEVENT` (notification event) "device in D0": the bus event thread runs while it is set |
| 0x2A0 | `WDFWAITLOCK` protecting the connect / disconnect events |

`FILE_OBJECT_CONTEXT` (12 bytes):  
| Offset | Comment |
|--------|---------|
| 0x00 | `PKEVENT` "connected", from [IOCTL_USB_OPEN_PORT](#ioctl-0x808520c0--ioctl_usb_open_port) |
| 0x04 | `PKEVENT` "disconnected", from IOCTL_USB_OPEN_PORT |
| 0x08 | Last event signalled: 0 = none, 1 = connected, 2 = disconnected |

`EvtFileCleanup` clears both event pointers.

### Prepare hardware

`EvtDevicePrepareHardware` (`sub_402D70`):
1. Sends [internal IOCTL 0x2AC022](#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info) to the lower device, output in `DEVICE_CONTEXT`+0x004.
2. Takes only the **high-speed** interface: `PipeCount` must be 3 or 4, otherwise `STATUS_UNSUCCESSFUL` (0xC0000001). For each pipe it creates the `PipeId` `WDFMEMORY` and builds a mask from its endpoint descriptor: bit 0 = control (`bmAttributes & 3` = 0), bit 1 = bulk IN, bit 2 = bulk OUT, bit 3 = interrupt IN.
3. 3 pipes require mask 0x7 (control + bulk IN + bulk OUT), 4 pipes mask 0xF (+ interrupt IN); otherwise `STATUS_UNSUCCESSFUL`. The control requests always use the first pipe of the collection, so `PipeArr[0]` must be the control pipe.
4. Sends [internal IOCTL 0x2AC02C](#ioctls-sent) (`IOCTL_INTERNAL_USBFN_ACTIVATE_USB_BUS`).
5. `KeInitializeEvent` (`DEVICE_CONTEXT`+0x290, notification, not signalled), then `PsCreateSystemThread` (`THREAD_ALL_ACCESS`) running the [bus event thread](#bus-events) (`sub_4013D8`).

Without the interrupt IN pipe (3 pipes), `IOCTL_USB_SEND_SERIAL_STATE` and `IOCTL_USB_SEND_RESPONSE` fail with `STATUS_NOT_FOUND` (0xC0000225).

> [!NOTE]
> There's no `EvtDeviceReleaseHardware` and the bus event thread has no exit path (infinite loop, the thread handle is never closed): after a remove or a restart of the device, the old thread stays blocked on the event of a freed device context ?

`EvtDeviceD0Entry` (`sub_4030E0`): sets the "D0" event (the bus event thread resumes) and restarts the manual queues 0x27C and 0x278 if they were stopped.  
`EvtDeviceD0Exit` (`sub_40320C`): when the target state is `WdfPowerDeviceD3Final` (5) or `WdfPowerDevicePrepareForHibernation` (6), clears the "D0" event and cancels the pending bus event notification (`WdfRequestCancelSentRequest`). In every case it purges the queues 0x27C and 0x278 and deletes the encapsulated commands not yet read.

### Bus events

The system thread `sub_4013D8` creates one `WDFREQUEST` and loops forever: wait for the "D0" event, send [internal IOCTL 0x2AC036](#ioctls-sent) (`IOCTL_INTERNAL_USBFN_BUS_EVENT_NOTIFICATION`, synchronous, no timeout, output 12 bytes into `DEVICE_CONTEXT`+0x22C), handle the event (`sub_401644`), `WdfRequestReuse`.

The event (`USBFN_EVENT` of the public `usbfnbase.h`) sets the device state (`USBFN_DEVICE_STATE`, names from the strings of the binary):  
| Event | Name | New device state |
|-------|------|------------------|
| 1 | UsbfnEventAttach | 1 `UsbfnDeviceStateAttached` |
| 2 | UsbfnEventReset | 2 `UsbfnDeviceStateDefault` |
| 3 | UsbfnEventDetach | 3 `UsbfnDeviceStateDetached` |
| 4 | UsbfnEventSuspend | 6 `UsbfnDeviceStateSuspended` |
| 5 | UsbfnEventResume | previous state (unchanged if none) |
| 6 | UsbfnEventSetupPacket | unchanged, see [CDC class requests](#cdc-class-requests) |
| 7 | UsbfnEventConfigured | 5 `UsbfnDeviceStateConfigured` (the configuration value is traced) |
| 8 | UsbfnEventUnConfigured | 4 `UsbfnDeviceStateAddressed` |
| 9 | UsbfnEventPortType | unchanged, only traced |
| other | | unchanged, traced "unknown" |

On every state change (`sub_402144`, under the wait lock 0x2A0): if the new state is `Configured` and an open handle has a "connected" event, `KeSetEvent` on it (once); otherwise `KeSetEvent` on the "disconnected" event (once). Then the idle policy is updated (`sub_401554`, see above). The same check is done right after `IOCTL_USB_OPEN_PORT`, so the client gets the current state immediately.

### CDC class requests

Setup packets received with `UsbfnEventSetupPacket` (`sub_402010`), on the control pipe (`PipeArr[0]`). The request names are those of the strings of the binary (CDC PSTN subclass):  
| bmRequestType | bRequest | Name | Handling |
|---------------|----------|------|----------|
| 0x21 | 0x00 | USB_CDC_SEND_ENCAPSULATED_COMMAND | `sub_402524`: `TRANSFER_OUT` of `wLength` bytes, the data is queued (collection 0x250) and given to the next [IOCTL_USB_GET_ENCAPSULATED_COMMAND](#ioctl-0x808520d2--ioctl_usb_get_encapsulated_command); then status stage `CONTROL_STATUS_HANDSHAKE_IN` |
| 0x21 | 0x02 | USB_CDC_SET_COMM_FEATURE | `sub_4026D0`: `TRANSFER_OUT` of 2 bytes, value only traced, then `CONTROL_STATUS_HANDSHAKE_IN` |
| 0x21 | 0x20 | USB_CDC_SET_LINE_CODING | `sub_40281C`: `TRANSFER_OUT` of 7 bytes (`dwDTERate`, `bCharFormat`, `bParityType`, `bDataBits`), only traced (not stored, not applied), then `CONTROL_STATUS_HANDSHAKE_IN` |
| 0x21 | 0x22 | USB_CDC_SET_CONTROL_LINE_STATE | `sub_4022CC`: no data stage; `wValue` (bit 0 = DTR, bit 1 = RTS) replaces the stored control line state and completes a pending [IOCTL_USB_GET_CONTROL_LINE_STATE](#ioctl-0x808520c8--ioctl_usb_get_control_line_state); then `CONTROL_STATUS_HANDSHAKE_IN` |
| 0xA1 | 0x01 | USB_CDC_GET_ENCAPSULATED_RESPONSE | `sub_402AA4`: takes the request pending in the queue 0x27C ([IOCTL_USB_SEND_RESPONSE](#ioctl-0x808520cd--ioctl_usb_send_response)), `TRANSFER_IN_APPEND_ZERO_PKT` of its whole input buffer (`wLength` is ignored), `CONTROL_STATUS_HANDSHAKE_OUT`, then completes the IOCTL |
| 0xA1 | 0x21 | USB_CDC_GET_LINE_CODING | `sub_402974`: `TRANSFER_IN` of a constant 7-byte line coding, then `CONTROL_STATUS_HANDSHAKE_OUT` |

Line coding returned to the host (constant, `SET_LINE_CODING` doesn't change it):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 C2 01 00 | dwDTERate = 115200 bauds |
| 04 | 00 | bCharFormat = 1 stop bit |
| 05 | 00 | bParityType = none |
| 06 | 08 | bDataBits = 8 |

Any other request (e.g. `GET_COMM_FEATURE`, `CLEAR_COMM_FEATURE`, `SEND_BREAK`) is ignored (`RtlAssert("FALSE")` on a checked WDF, no response, no stall). When one of the handlers above fails, the control pipe is stalled (`sub_401F1C`: [internal IOCTL 0x2AC029](#ioctls-sent) `SET_PIPE_STATE` with the control `PipeId` and a 1-byte `TRUE`).

### Read / write

- `ReadFile` (`EvtIoRead`): the request is formatted as `IOCTL_INTERNAL_USBFN_TRANSFER_OUT` (0x2AC016) on the **bulk OUT** pipe (host → device), input = `PipeId` memory, output = the read buffer, and sent asynchronously; completed with the status and length of the transfer.
- `WriteFile` (`EvtIoWrite`): formatted as `IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT` (0x2AC011) on the **bulk IN** pipe (device → host), output = the write buffer.

The requests in progress are tracked in the collection 0x254 so that `EvtIoStop` can cancel them (`WdfRequestCancelSentRequest`). No pipe found → `STATUS_NOT_FOUND`.

---

### IOCTL 0x808520C0 — IOCTL_USB_OPEN_PORT

This IOCTL is processed by Ufnserialclass.sys

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x830 (2096) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_USB_OPEN_PORT | 8 (only ≥ 4 checked) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT` signalled when the USB function is configured (port connected) |
| 04-07 | ? | `PKEVENT` signalled when it leaves the configured state (port disconnected) |

The pointers are copied into the `FILE_OBJECT_CONTEXT` of the open handle by a work item (`sub_403670`), which completes the request with `STATUS_SUCCESS` and immediately signals the event matching the current state. They are used directly with `KeSetEvent`: the caller must be in kernel mode (a user-mode caller would crash the system).  
Input length 0 or `NULL` first pointer → `STATUS_INVALID_PARAMETER` (0xC000000D).

---

### IOCTL 0x808520C4 — IOCTL_USB_SEND_SERIAL_STATE

This IOCTL is processed by Ufnserialclass.sys

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x831 (2097) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_USB_SEND_SERIAL_STATE | 2 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | e.g. 03 00 | CDC `UART State Bitmap`: bit 0 bRxCarrier (DCD), bit 1 bTxCarrier (DSR), bit 2 bBreak, bit 3 bRingSignal, bit 4 bFraming, bit 5 bParity, bit 6 bOverRun |

If the value is the same as the last one sent (`DEVICE_CONTEXT`+0x280), the request is completed with `STATUS_SUCCESS` without any transfer. Otherwise it builds the 10-byte `SERIAL_STATE` notification below and sends it on the **interrupt IN** pipe with `IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT` (0x2AC011), the request is completed with the status of the transfer (`sub_4043C0`).

SERIAL_STATE notification sent to the host:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | A1 | bmRequestType |
| 01 | 20 | bNotification `SERIAL_STATE` |
| 02-03 | 00 00 | wValue |
| 04-05 | e.g. 00 00 | wIndex = high-speed `InterfaceNumber` |
| 06-07 | 02 00 | wLength |
| 08-09 | | UART state bitmap from the input buffer |

Input length 0 → `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x808520C8 — IOCTL_USB_GET_CONTROL_LINE_STATE

This IOCTL is processed by Ufnserialclass.sys

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x832 (2098) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_USB_GET_CONTROL_LINE_STATE | 0 | ≥ 2 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | e.g. 03 00 | `wValue` of the last `SET_CONTROL_LINE_STATE` from the host: bit 0 = DTR, bit 1 = RTS |

The request is parked in the manual queue 0x274. It is completed (work item `sub_401A58`) as soon as a control line state is available: immediately if one was received since the last call, otherwise at the next `SET_CONTROL_LINE_STATE`. Each state is returned only once (it's deleted after being copied). The `Information` is the output buffer length.

---

### IOCTL 0x808520CD — IOCTL_USB_SEND_RESPONSE

This IOCTL is processed by Ufnserialclass.sys

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x833 (2099) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_USB_SEND_RESPONSE | ≥ 1, response data | 0 |

Inputbuffer: the encapsulated response (e.g. a QMI / AT response ?), sent unchanged to the host.

1. Builds the 8-byte `RESPONSE_AVAILABLE` notification below and sends it on the **interrupt IN** pipe with `IOCTL_INTERNAL_USBFN_TRANSFER_IN` (0x2AC00D), using a separate request (context `INTR_REQUEST_CONTEXT` = the original request).
2. Parks the IOCTL in the manual queue 0x27C.
3. When the host then sends `GET_ENCAPSULATED_RESPONSE`, the input buffer is sent on the control pipe and the IOCTL is completed with the status of that transfer, `Information` = input length (see [CDC class requests](#cdc-class-requests)). If the notification transfer fails, the IOCTL is completed at once (`sub_404434`).

RESPONSE_AVAILABLE notification sent to the host:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | A1 | bmRequestType |
| 01 | 01 | bNotification `RESPONSE_AVAILABLE` |
| 02-03 | 00 00 | wValue |
| 04-05 | e.g. 00 00 | wIndex = high-speed `InterfaceNumber` |
| 06-07 | 00 00 | wLength |

Input length 0 → `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x808520D2 — IOCTL_USB_GET_ENCAPSULATED_COMMAND

This IOCTL is processed by Ufnserialclass.sys

| Property | Value |
|----------|-------|
| Device | 0x8085 |
| Function | 0x834 (2100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_OUT_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_USB_GET_ENCAPSULATED_COMMAND | 0 | ≥ length of the command |

Outputbuffer: the data of the oldest `SEND_ENCAPSULATED_COMMAND` received from the host. `Information` = length of the command.

The request is parked in the manual queue 0x278 and completed by the work item `sub_401C14` as soon as a command is available (FIFO, collection 0x250). If the output buffer is too small the request fails (`STATUS_BUFFER_TOO_SMALL`) and the command is lost.

---

Any other IoControlCode → `STATUS_INVALID_PARAMETER` (0xC000000D). The names of the 5 IOCTLs come from the strings of the binary (`sub_404358`).

### IOCTLs sent

All sent to the lower device of the stack (USB function class extension ?), codes of the public `usbfnioctl.h` (same as in [genericusbfnclass.sys](./genericusbfnclass.md#ioctl-forwarding)). For the transfers, the "input" `WDFMEMORY` is the 4-byte `PipeId` and the "output" one is the data.  
| Internal IOCTL | Name | Method | Sent by | Pipe / buffers |
|----------------|------|--------|---------|----------------|
| 0x2AC00D | IOCTL_INTERNAL_USBFN_TRANSFER_IN | METHOD_IN_DIRECT | `GET_LINE_CODING`, `IOCTL_USB_SEND_RESPONSE` | control (7 bytes) / interrupt IN (8 bytes) |
| 0x2AC011 | IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT | METHOD_IN_DIRECT | `WriteFile`, `IOCTL_USB_SEND_SERIAL_STATE`, `GET_ENCAPSULATED_RESPONSE` | bulk IN / interrupt IN (10 bytes) / control |
| 0x2AC016 | IOCTL_INTERNAL_USBFN_TRANSFER_OUT | METHOD_OUT_DIRECT | `ReadFile`, `SEND_ENCAPSULATED_COMMAND`, `SET_COMM_FEATURE`, `SET_LINE_CODING` | bulk OUT / control |
| 0x2AC018 | IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_IN | METHOD_BUFFERED | Host → device class requests | no buffer |
| 0x2AC01C | IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_OUT | METHOD_BUFFERED | Device → host class requests | no buffer |
| 0x2AC022 | IOCTL_INTERNAL_USBFN_GET_CLASS_INFO | METHOD_OUT_DIRECT | `EvtDevicePrepareHardware` | see below |
| 0x2AC029 | IOCTL_INTERNAL_USBFN_SET_PIPE_STATE | METHOD_IN_DIRECT | Failed class request | input = control `PipeId`, output = 1 byte `01` (stall) |
| 0x2AC02C | IOCTL_INTERNAL_USBFN_ACTIVATE_USB_BUS | METHOD_BUFFERED | `EvtDevicePrepareHardware` | no buffer, timeout 25 ms |
| 0x2AC036 | IOCTL_INTERNAL_USBFN_BUS_EVENT_NOTIFICATION | METHOD_OUT_DIRECT | Bus event thread | output 12 bytes `USBFN_NOTIFICATION` |

The class-request transfers, the handshakes and the stall are sent synchronously without timeout (`WdfIoTargetSendInternalIoctlSynchronously`, no options); read, write and the notifications asynchronously (`WdfRequestSend`). This driver never sends `IOCTL_INTERNAL_USBFN_DEACTIVATE_USB_BUS` nor `GET_PIPE_STATE`.

### internal IOCTL 0x2AC022 — IOCTL_INTERNAL_USBFN_GET_CLASS_INFO

This internal IOCTL is sent by Ufnserialclass.sys to the lower driver of its stack (USB function class extension ?), during `EvtDevicePrepareHardware`.  
`WdfIoTargetSendInternalIoctlSynchronously`, no input buffer, output = 552 bytes in the device context, `WDF_REQUEST_SEND_OPTION_TIMEOUT` with `Timeout` = -250000 (relative 25 ms).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x8 |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_GET_CLASS_INFO | lower device | 0 | 552 |

Outputbuffer: the first 552 bytes (0x000-0x227) of the [USBFN_CLASS_INFORMATION_PACKET](./genericusbfnclass.md#usbfn_class_information_packet): full-speed interface, high-speed interface, `InterfaceName`, `InterfaceGuid`, `HasInterfaceGuid`, without the `SuperSpeedClassInterface` that [genericusbfnclass.sys](./genericusbfnclass.md) (built in 2015) reads at 0x228 (older version of the structure ?). Only the high-speed interface is used, `InterfaceGuid` is ignored (the device interface GUID comes from the registry).

A failure makes `EvtDevicePrepareHardware` fail with the status of the IOCTL.
