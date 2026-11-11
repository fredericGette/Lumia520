## Ufnvidstream.sys

USB function "video stream" class driver (Microsoft, `src\uxplat\vidstream\dev\ufnvidstream`): the phone side of the WP8.1 screen projection over USB ("Project My Screen").  
It is the KMDF function driver of a USB *function* interface (a `USBFN\<interface>` child of the USB function controller `ACPI\QCOM01C0\1`, like [genericusbfnclass.sys](./genericusbfnclass.md) and [ufnserialclass.sys](./ufnserialclass.md)): the `VidStream` interface of the [USB function configuration](./genericusbfnclassipoverusb.md#usb-function-configuration). It is bound to WinUSB on the PC, and the PC client finds it by its interface GUID `{31648E59-6FCB-4D81-9C97-D00999B0459A}` (see [PC side](#pc-side-project-my-screen)). It implements a small private protocol itself: 4 class requests on the control endpoint drive a state machine, the user-mode client sends frames (512-byte header + screen image) on the bulk IN pipe and receives the [input messages](#input-message) of the PC (touch contacts and hardware button clicks made in the PC viewer, same header format) from the bulk OUT pipe. Everything goes to the lower driver (USB function class extension [usbfnclx.sys](./usbfnclx.md)) as `IOCTL_INTERNAL_USBFN_*` requests.  
The client opens `\\.\UfnVidStream` and uses 8 private IOCTLs (all `FILE_DEVICE_UNKNOWN`, `FILE_READ_ACCESS | FILE_WRITE_ACCESS`). The settings page [MirrorUX.dll](../libraries/mirrorux.md#usb-agent) opens this device and shows the USB connection as connected in state 7. It only uses [IOCTL 0x22C344](#ioctl-0x22c344); the process that sends the frames isn't known.  
PDB: `ufnvidstream.pdb` (no path). The PE timestamp (0x3CAE9F26) is not a build date. KMDF 1.11. Imports only `ntoskrnl.exe` (`_vsnwprintf`, `RtlCopyUnicodeString`) and `WDFLDR.SYS`. MD5 `1e8b249cb92532786eeb924655775537`, 36864 bytes.  
Pool tag `UfnV` (0x566E6655) for the driver (`DriverPoolTag`) and its `WdfMemoryCreate` buffers. Device context type `UFN_VIDSTREAM_CONTEXT` (0x538 bytes). Source files named in the binary: `ufnhelper.cpp`, `ufnreceive.cpp`.

Device name : none (`WdfDeviceInitAssignName` is not called, KMDF uses the PDO name)  
Symbolic link : `\DosDevices\UfnVidStream` (created in `EvtDevicePrepareHardware`)  

There's no parameters in the registry.

There's no ETW provider and no device interface.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device of its stack (`WdfDeviceGetIoTarget`) = PDO `USBFN\<interface>`, child of `ACPI\QCOM01C0\1` | USB function class extension [usbfnclx.sys](./usbfnclx.md) / controller driver [usbfnchipidea.sys](./usbfnchipidea.md) | Receives all the `IOCTL_INTERNAL_USBFN_*`, see [IOCTLs sent](#ioctls-sent) |

### WDF configuration

`DriverEntry` (0x10003150): `WdfDriverCreate` with only `EvtDriverDeviceAdd` (0x10002DFC) and the pool tag `UfnV`.

`EvtDriverDeviceAdd` (0x10002DFC, read from the disassembly):
- PnP/power callbacks: `EvtDevicePrepareHardware` (`sub_10002AF0`), `EvtDeviceD0Entry` (`sub_10002DA4`). No `EvtDeviceReleaseHardware`, no `EvtDeviceD0Exit`.
- No file object callbacks, not exclusive, default I/O type (buffered).
- `WdfDeviceCreate` (context `UFN_VIDSTREAM_CONTEXT`, zeroed, state = 1), then the collections, spin locks and memories of the context (see below).
- One default queue: `WdfIoQueueDispatchParallel`, `PowerManaged` = `WdfUseDefault`, `NumberOfPresentedRequests` = -1, only `EvtIoDeviceControl` (`sub_10001F74`).
- `WdfDeviceAssignS0IdleSettings`: `IdleCaps` = `IdleCanWakeFromS0`, `DxState` = `PowerDeviceMaximum`, `IdleTimeout` = 0 (default), `UserControlOfIdleSettings` = `IdleAllowUserControl`, `Enabled` / `PowerUpIdleDeviceOnSystemWake` / `ExcludeD3Cold` = `WdfUseDefault` (the defaults of `WDF_DEVICE_POWER_POLICY_IDLE_SETTINGS_INIT(IdleCanWakeFromS0)`). Its status is the return value of `EvtDriverDeviceAdd`.

`UFN_VIDSTREAM_CONTEXT` (0x538 bytes):  
| Offset | Comment |
|--------|---------|
| 0x000 | DWORD, state of the driver, see [State machine](#state-machine) |
| 0x004 | DWORD, bus speed of the last `UsbfnEventReset` (`USBFN_BUS_SPEED`, 2 = high speed) |
| 0x008 / 0x00C / 0x010 | `WDFCOLLECTION` (client requests) + `WDFCOLLECTION` (requests sent to the lower driver, same index) + `WDFSPINLOCK`: transmissions in progress (IOCTL 0x22C349, 0x22C3AC, 0x22C3B5) |
| 0x014 / 0x018 | Client request (IOCTL 0x22C354) and request sent to the lower driver of the reception in progress (only one at a time) |
| 0x01C | `WDFMEMORY` 512 bytes: template of the reception buffer (never written, zeros) |
| 0x020 | `WDFSPINLOCK` of the reception |
| 0x024 / 0x028 | `WDFCOLLECTION` + `WDFSPINLOCK`: pending IOCTL 0x22C344 (wait for state change) |
| 0x02C | `WDFMEMORY` 12 bytes: output of the bus event notification (`USBFN_NOTIFICATION`) |
| 0x030 | `WDFSPINLOCK` of the frame header |
| 0x034-0x31F | `USBFN_CLASS_INFORMATION_PACKET` (748 bytes, the version with `SuperSpeedClassInterface`) returned by [internal IOCTL 0x2AC022](#ioctls-sent). 0x0F8 = high-speed `InterfaceNumber`, 0x0F9 = high-speed `PipeCount`, 0x0FC = high-speed `PipeArr` |
| 0x320 | `WDFMEMORY` on the `PipeId` of `PipeArr[0]` (control) |
| 0x324 | `WDFMEMORY` on the `PipeId` of `PipeArr[1]` (bulk IN, device → host) |
| 0x328 | `WDFMEMORY` on the `PipeId` of `PipeArr[2]` (bulk OUT, host → device) |
| 0x330-0x52F | Frame header (512 bytes), see [Frame header](#frame-header) |
| 0x530 | `WDFMEMORY` preallocated on the frame header |

### Prepare hardware

`EvtDevicePrepareHardware` (`sub_10002AF0`, read from the disassembly):
1. Sends [internal IOCTL 0x2AC022](#ioctls-sent) (`IOCTL_INTERNAL_USBFN_GET_CLASS_INFO`, synchronous) to the lower device, output 748 bytes into context+0x034.
2. Checks the **high-speed** interface strictly, otherwise `STATUS_UNSUCCESSFUL` (0xC0000001):

| Pipe | bLength | bDescriptorType | bmAttributes | wMaxPacketSize | bInterval |
|------|---------|-----------------|--------------|----------------|-----------|
| `PipeCount` = 3 | | | | | |
| `PipeArr[0]` | 7 | 5 | 0 (control) | 64 | 0 |
| `PipeArr[1]` | 7 | 5 | 2 (bulk) | 512 | 0 |
| `PipeArr[2]` | 7 | 5 | 2 (bulk) | 512 | 0 |

   The direction (`bEndpointAddress`) is not checked: `PipeArr[1]` is used for the IN transfers, `PipeArr[2]` for the OUT transfers. The PC client sees 2 bulk endpoints (`bNumEndpoints` = 2, the control endpoint is EP0): its pipe 0 (bulk IN, frames) and pipe 1 (bulk OUT).
3. Creates the 3 `PipeId` memories (context+0x320/0x324/0x328, deleting the previous ones).
4. `WdfDeviceCreateSymbolicLink` `\DosDevices\UfnVidStream`.
5. Sends [internal IOCTL 0x2AC02C](#ioctls-sent) (`IOCTL_INTERNAL_USBFN_ACTIVATE_USB_BUS`, synchronous, no buffer).
6. State = 2.

`EvtDeviceD0Entry` (`sub_10002DA4`): sends [internal IOCTL 0x2AC036](#ioctls-sent) (`IOCTL_INTERNAL_USBFN_BUS_EVENT_NOTIFICATION`) asynchronously with the completion routine `sub_10001C20`, then state = 3. Unlike [ufnserialclass.sys](./ufnserialclass.md#bus-events) there is no thread: the completion routine handles the event and resends the same request. Nothing cancels it on D0 exit.

### Bus events

`sub_10001C20` (completion of the bus event notification, 12-byte `USBFN_NOTIFICATION`):  
| Event | Name | Action |
|-------|------|--------|
| 2 | UsbfnEventReset | stores the bus speed (context+0x004), state = 2 |
| 3 | UsbfnEventDetach | state = 2 |
| 6 | UsbfnEventSetupPacket | see [Class requests](#class-requests) |
| 7 | UsbfnEventConfigured | state = 4 if the bus speed is high speed (2), otherwise state = 2 |
| 8 | UsbfnEventUnConfigured | state = 2 |
| other | Attach, Suspend, Resume, PortType | ignored |

Then the request is reused and sent again. If the notification fails (or a step fails), the request is deleted and no more bus events are received.

### Class requests

Setup packets received with `UsbfnEventSetupPacket` (`sub_10001AE0`). A request is accepted only if the state is 4 to 8, `bmRequestType` is host → device / class / interface (0x21, bit 7 = 0, bit 5 = 1, bit 0 = 1), `wValue` = 0 and `wLength` = 0 (no data stage, `wIndex` is not checked). The [PC clients](#pc-side-project-my-screen) send exactly `bmRequestType` = 0x21 with everything else 0. Their use in the official `ProjectMyScreenApp.exe` (names from WinPhoneProjection):  
| bRequest | Name | Sent by the PC | Handling |
|----------|------|----------------|----------|
| 0x01 | stop | when the viewer closes (`CFramePresenter` destructor) or can't create its rendering resources | state = 5, then status stage `CONTROL_STATUS_HANDSHAKE_IN` |
| 0x02 | `NOTIFY` (start) | first start, right after opening the device ("the phone shows the projection notification") | state = 6, then `CONTROL_STATUS_HANDSHAKE_IN` |
| 0x03 | `READY` | before reading each frame, and again after 2.5 s without data | state 6 or 7: `CONTROL_STATUS_HANDSHAKE_IN`, state unchanged. Other states: no status stage (the host request fails and the PC reconnects) |
| 0x04 | `FORCE` (restart) | the following starts (the official app replaces 2 by 4 after the first successful start) | state 7: `CONTROL_STATUS_HANDSHAKE_IN`, state unchanged. State 4-6: state = 6 + handshake. State 8: no status stage |

The driver doesn't tell its user-mode client about `READY`: the request is only acknowledged (flow control on the PC side), the phone sends its frames on its own.

Anything else (other request, other state, `bmRequestType`, non-zero `wValue` / `wLength`, or a failure of the state change) stalls the control pipe: [internal IOCTL 0x2AC029](#ioctls-sent) `SET_PIPE_STATE`, input = control `PipeId`, output = 1 byte `01`.

### State machine

The state (context+0x000) is a private DWORD; every change completes the pending [IOCTL 0x22C344](#ioctl-0x22c344) requests with the new value (`sub_10002158`).  
| State | Set by | Meaning ? |
|-------|--------|-----------|
| 1 | `EvtDriverDeviceAdd` | created |
| 2 | `EvtDevicePrepareHardware`, bus reset / detach / unconfigured, configured at full speed | not connected |
| 3 | `EvtDeviceD0Entry` | waiting for the host |
| 4 | `UsbfnEventConfigured` at high speed | connected |
| 5 | class request 0x01 | PC viewer stopped |
| 6 | class request 0x02 `NOTIFY` / 0x04 `FORCE` | PC asks for the projection (the phone shows its notification ?) |
| 7 | [IOCTL 0x22C340](#ioctl-0x22c340) | client set the format, streaming |
| 8 | [IOCTL 0x22C3B8](#ioctl-0x22c3b8) (from state 6 or 7) | client stopped (the next `READY` of the PC fails) |

Normal sequence: 3 → 4 (USB configured) → 6 (PC `NOTIFY`) → 7 (phone client sets the format) → frames, each one requested by a PC `READY` → 5 (PC closes) or 8 (phone stops).

### Frame header

512-byte header (context+0x330) sent before each frame of [IOCTL 0x22C349](#ioctl-0x22c349). The [input messages](#input-message) received with [IOCTL 0x22C354](#ioctl-0x22c354) start with the same magic and size fields. The image starts at offset 0x200. Checks of the official PC app (`sub_10073FB` of `ProjectMyScreenApp.exe`) in the comments.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 08 56 55 44 | Magic 0x44555608 (checked on reception, and by the PC) |
| 04-07 | 02 00 00 00 | Message type: 2 = frame (the PC requires 2). 3 = [input message](#input-message) |
| 08-0B | ? | Total size = image size + 512 (header included). On reception: 24 ≤ size ≤ 512. The PC requires it to be exactly the number of bytes read |
| 0C-17 | 00 | |
| 18-2F | ? | Copy of the 24-byte format of IOCTL 0x22C340 (see there): 18 = bits per pixel (the PC requires 16), 1C = bytes per line (recomputed by IOCTL 0x22C349), 20/22 = phone screen width/height, 24/26 = image width/height, 28 = orientation (overwritten by IOCTL 0x22C34C), 2C = soft navigation bar flag |
| 30-1FF | 00 | |

### Input message

192-byte message that the official PC app writes on the bulk OUT pipe (`WinUsb_WritePipe`, `sub_10076EE`), received on the phone with [IOCTL 0x22C354](#ioctl-0x22c354). It carries the mouse / touch / pen input on the viewer window and the clicks on the hardware buttons of the phone image. The PC builds the 168-byte body in `VidStreamViewerInputHandler.dll` (`CInputPointerTracker`, from `WM_POINTER*` messages), its own `CFramePresenter` adds the header (`sub_100729B` / `sub_10063C7`). It keeps up to 32 messages in a queue and sends them only while the projection is started.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 08 56 55 44 | Magic 0x44555608 |
| 04-07 | 03 00 00 00 | Message type 3 = input |
| 08-0B | C0 00 00 00 | Size = 192 (within the 24-512 limits of the driver) |
| 0C-17 | ? | Not initialised by the PC |
| 18-1B | ? | DWORD, event type: 0 = touch, 1 = hardware button |
| 1C-BF | ? | Touch or button event, see below |

Touch event (type 0), sent when a contact changes, at most every 12 ms when only positions change:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 1C-1F | ? | DWORD, number of contacts (max 10) |
| 20-BF | ? | 10 × 16-byte contacts |

Contact (16 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | WORD, contact id (allocated by the PC, unique among the active contacts) |
| 02-03 | ? | |
| 04-07 | ? | DWORD, current state: 0 = up / removed, 1 = in range (hover), 2 = in contact |
| 08-0B | ? | DWORD, previous state |
| 0C-0D | ? | WORD, X in phone screen pixels (portrait, rotated back according to the orientation) |
| 0E-0F | ? | WORD, Y in phone screen pixels |

State from the `WM_POINTER` flags: `INCONTACT` → 2, `INRANGE` → 1. A mouse moving without button (in range) is ignored unless Ctrl is held; with Ctrl held, a touch / pen contact is sent as hover (1) instead of contact.

Hardware button event (type 1), when a click (state 2) starts or ends on one of the `backButton` / `windowsButton` / `searchButton` rectangles of `Config.xml`:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 1C-1F | ? | DWORD, button: 0 = Back, 1 = Windows (Start), 2 = Search |
| 20 | 01 / 00 | Pressed / released |
| 21-BF | ? | |

---

### IOCTL 0x22C340

This IOCTL is processed by Ufnvidstream.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xD0 (208) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set format / start streaming | 24 | 0 |

Inputbuffer (names from the [PC client](#pc-side-project-my-screen)):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 10 00 00 00 | DWORD, bits per pixel (the PC client expects 16 = RGB565, also handles 24 and 32) |
| 04-07 | ? | DWORD, bytes per line: replaced by IOCTL 0x22C349 with image size / image height (WORD at 0E). Ignored by the PC client (it uses width × bytes per pixel) |
| 08-09 | ? | WORD, width of the phone screen (e.g. 480) |
| 0A-0B | ? | WORD, height of the phone screen (e.g. 800) |
| 0C-0D | ? | WORD (signed), width of the transmitted image |
| 0E-0F | ? | WORD (signed), height of the transmitted image |
| 10-13 | ? | Orientation, see [IOCTL 0x22C34C](#ioctl-0x22c34c) |
| 14 | ? | Soft navigation bar ("user managed navigation bar") flag: the official PC app then draws the `umNavBarImageRelPath` phone image of `Config.xml` |
| 15-17 | ? | |

Requires state ≥ 5 (in practice 6, after the PC `NOTIFY`), otherwise `STATUS_DEVICE_NOT_READY` (0xC00000A3). Input size other than 24 → `STATUS_INVALID_BUFFER_SIZE` (0xC0000206).  
Initialises the [frame header](#frame-header): magic, version 2, total size = `bpp * width * height / 8 + 512`, copy of the 24 bytes at header offset 0x18. Then state = 7.

---

### IOCTL 0x22C344

This IOCTL is processed by Ufnvidstream.sys
This IOCTL is sent by [MirrorUX.dll](../libraries/mirrorux.md#usb-agent) (overlapped, in a loop, to follow the state of the USB projection)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xD1 (209) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Wait for state change | 4 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | State known by the client |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 04 00 00 00 | Current state of the driver, see [State machine](#state-machine) |

Both sizes must be exactly 4 (`STATUS_INVALID_BUFFER_SIZE`). If the input differs from the current state, the request is completed at once with the current state. Otherwise it is kept pending (cancelable, collection context+0x024) until the next state change. Cancelled → `STATUS_CANCELLED` (0xC0000120).

---

### IOCTL 0x22C349

This IOCTL is processed by Ufnvidstream.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xD2 (210) |
| Access | READ_AND_WRITE |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send frame (with header) | frame size | 0 |

Inputbuffer: the frame payload (`InputBuffer`; with METHOD_IN_DIRECT the data is in the buffer passed as `lpInBuffer`).

Requires state 7, otherwise `STATUS_DEVICE_NOT_READY`. Under the header lock (`sub_10001EAC`):
- payload size + 512 > header size: the header size becomes payload size + 512 and header DWORD 0x1C (bytes per line) = payload size / WORD 0x26 (image height, format WORD 0E);
- payload size + 512 < header size: `STATUS_INVALID_BUFFER_SIZE`;
- equal: no change.

Then it sends the 512-byte header on the bulk IN pipe (`IOCTL_INTERNAL_USBFN_TRANSFER_IN` 0x2AC00D, asynchronous, status ignored) and a copy of the payload (`sub_100024A0`, `IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT` 0x2AC011, asynchronous). The header is exactly one 512-byte packet without zero-length packet, so it doesn't end the USB transfer: the PC reads header + image with a single `WinUsb_ReadPipe`, ended by the short or zero-length packet of the payload. The client request stays pending (cancelable) and is completed with the status of the payload transfer, information = 0 (`sub_1000224C`). Cancelling it cancels the transfer (`STATUS_CANCELLED`).

---

### IOCTL 0x22C34C

This IOCTL is processed by Ufnvidstream.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xD3 (211) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set orientation | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Screen orientation, stored at header offset 0x28 (format bytes 10-13) and sent with the next frames. 0 = default (portrait), 1 = portrait, 2 = landscape towards the Back key, 4 = portrait upside down, 8 = landscape towards the Search key (4 from the touch coordinate rotation of the official PC app, the others from WinPhoneProjection) |

No state check. Input size other than 4 → `STATUS_INVALID_BUFFER_SIZE`.

---

### IOCTL 0x22C354

This IOCTL is processed by Ufnvidstream.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xD5 (213) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Receive input message from the PC | 0 | ≥ 24 (192 for the official PC app) |

Outputbuffer: the message sent by the host, in practice the 192-byte [input message](#input-message).  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 08 56 55 44 | Magic |
| 04-07 | 03 00 00 00 | Message type (3 = input), not checked by the driver |
| 08-0B | C0 00 00 00 | Size of the message (24-512), = information returned |
| 0C-... | ? | Rest of the message, see [Input message](#input-message) |

Requires state ≥ 2 (`STATUS_DEVICE_NOT_READY`), output ≥ 24 bytes (`STATUS_INVALID_BUFFER_SIZE`), and no other reception in progress (`STATUS_DEVICE_NOT_READY`).  
Sends `IOCTL_INTERNAL_USBFN_TRANSFER_OUT` (0x2AC016) on the bulk OUT pipe into a new 512-byte buffer (`sub_10002760`). On completion (`sub_100028C4`): magic different from 0x44555608 → `STATUS_UNSUCCESSFUL`; size field < 24 or > 512 → `STATUS_INVALID_BUFFER_SIZE`; size > client output size → `STATUS_BUFFER_TOO_SMALL` (0xC0000023); otherwise the first *size* bytes are copied and the request completes with information = size. Cancelling it cancels the transfer (`STATUS_CANCELLED`).

---

### IOCTL 0x22C3AC

This IOCTL is processed by Ufnvidstream.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xEB (235) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send raw data | > 0 | 0 |

Sends a copy of the input buffer as is (no header) on the bulk IN pipe with `IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT`, same path as [IOCTL 0x22C349](#ioctl-0x22c349) (`sub_100024A0`). No state check. Empty input → `STATUS_INVALID_PARAMETER` (0xC000000D).

---

### IOCTL 0x22C3B5

This IOCTL is processed by Ufnvidstream.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xED (237) |
| Access | READ_AND_WRITE |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send raw data | > 0 | 0 |

Same handler as [IOCTL 0x22C3AC](#ioctl-0x22c3ac), METHOD_IN_DIRECT variant.

---

### IOCTL 0x22C3B8

This IOCTL is processed by Ufnvidstream.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xEE (238) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Stop streaming ? | 0 | 0 |

If the state is 6 or 7, state = 8. Always completed with `STATUS_SUCCESS`.

---

Any other IoControlCode → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

### IOCTLs sent

All sent to the lower device of the stack (USB function class extension ?), codes of the public `usbfnioctl.h` (same as in [ufnserialclass.sys](./ufnserialclass.md#ioctls-sent)). Synchronous ones use `WDF_REQUEST_SEND_OPTION_SYNCHRONOUS` without timeout (`sub_10002688`), the others are sent asynchronously (`sub_10002608`). For the transfers, the "input" `WDFMEMORY` is the 4-byte `PipeId` and the "output" one is the data.  
| Internal IOCTL | Name | Method | Sent by | Pipe / buffers |
|----------------|------|--------|---------|----------------|
| 0x2AC00D | IOCTL_INTERNAL_USBFN_TRANSFER_IN | METHOD_IN_DIRECT | IOCTL 0x22C349 | bulk IN, 512-byte frame header |
| 0x2AC011 | IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT | METHOD_IN_DIRECT | IOCTL 0x22C349, 0x22C3AC, 0x22C3B5 | bulk IN, copy of the client input |
| 0x2AC016 | IOCTL_INTERNAL_USBFN_TRANSFER_OUT | METHOD_OUT_DIRECT | IOCTL 0x22C354 | bulk OUT, 512 bytes |
| 0x2AC018 | IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_IN | METHOD_BUFFERED | Class requests 0x01-0x04 | no buffer |
| 0x2AC022 | IOCTL_INTERNAL_USBFN_GET_CLASS_INFO | METHOD_OUT_DIRECT | `EvtDevicePrepareHardware` (synchronous) | output 748 bytes `USBFN_CLASS_INFORMATION_PACKET` |
| 0x2AC029 | IOCTL_INTERNAL_USBFN_SET_PIPE_STATE | METHOD_IN_DIRECT | Rejected class request | input = control `PipeId`, output = 1 byte `01` (stall) |
| 0x2AC02C | IOCTL_INTERNAL_USBFN_ACTIVATE_USB_BUS | METHOD_BUFFERED | `EvtDevicePrepareHardware` (synchronous) | no buffer |
| 0x2AC036 | IOCTL_INTERNAL_USBFN_BUS_EVENT_NOTIFICATION | METHOD_OUT_DIRECT | `EvtDeviceD0Entry`, then its own completion routine | output 12 bytes `USBFN_NOTIFICATION` |

> [!NOTE]
> The header (0x2AC00D) and the payload (0x2AC011) of a frame are two independent asynchronous requests on the same pipe: their order on the bus relies on the lower driver queuing them in order. The status of the header transfer is ignored.

### PC side (Project My Screen)

#### ProjectMyScreenApp.exe

The official Microsoft PC viewer (`ProjectMyScreenApp.pdb`, x86, Direct3D, ETW logging). Optional parameter: an XML configuration file (`ProjectMyScreenApp.exe Config.xml`) with one `PhoneConfiguration` per phone resolution (480×800 for the Lumia 520): phone image, `umNavBarImageRelPath` for phones with a soft navigation bar, position of the video, rectangles of the Back / Windows / Search hardware buttons, `TouchDots`. On Windows 8 and later it loads `VidStreamViewerInputHandler.dll` (`CreateInputPointerTracker`) to send the input to the phone.  
Thread `sub_1006799` (class `CFramePresenter`, USB helper `sub_100AC24`, 0x220 bytes):
1. `sub_100AF6E`: `SetupDiGetClassDevs` on `{31648E59-6FCB-4D81-9C97-D00999B0459A}` (first interface only), `CreateFileW` overlapped, `WinUsb_Initialize`. Requires `bNumEndpoints` = 2, pipe 0 = bulk **IN** (frames), pipe 1 = bulk **OUT** (input messages), otherwise prints "USB device doesn't advertise the proper interface". Sets `RAW_IO` on both pipes and keeps the `MaximumPacketSize` of pipe 0.
2. Class request 0x02 (`sub_100AC45`; this function sends 0x04 from then on). Retries every second if the device or the request fails.
3. Read buffer: 820352 bytes (= 854 × 480 × 2 + 512) if the packet size is 512, 820864 if it is 1024 (rounded up to the packet size).
4. Loop: class request 0x03 then overlapped `WinUsb_ReadPipe`; waits on the read, the input queue and a 2.5 s timeout (→ new request 0x03). Pending [input messages](#input-message) are written on pipe 1, one at a time, and must complete with exactly 192 bytes.
5. Frame check (`sub_10073FB`): magic, type 2, size field = bytes read, 16 bpp. If the bytes per line (0x1C) are 0, the resolution is guessed from the size (480×800, 480×854, 480×640, 450×800, with 512 or 1024 bytes of header); otherwise it is read at 0x24/0x26 and the lines are copied with the 0x1C pitch. The image is at offset 0x200, or 0x400 when the packet size is 1024 (SuperSpeed: the header is then probably 1024 bytes, not supported by this driver). Header 0x20/0x22 (phone resolution) selects the `PhoneConfiguration`, byte 0x2C the soft navigation bar image, 0x28 the orientation (unless forced in the menu).
6. Any error: reset of the pipes, back to step 1. On exit (or when the rendering setup fails): class request 0x01.

#### WinPhoneProjection

[WinPhoneProjection](https://github.com/evolution124/WinPhoneProjection) (2014) is a third-party PC client reverse-engineered from the "Project My Screen" app 8.10.12349 (view only, no input). It confirms the protocol of this driver from the host side:
1. Finds the phone with `SetupDiGetClassDevs` on the device interface `{31648E59-6FCB-4D81-9C97-D00999B0459A}` (the `InterfaceGuid` of `VidStream`), opens it and `WinUsb_Initialize`.
2. Checks that the interface has 2 bulk endpoints: pipe 0 = data (bulk IN), pipe 1 = "control" (bulk OUT, never written: no input messages). Sets `RAW_IO` on both.
3. Class request 0x02 (`NOTIFY`), then resets both pipes.
4. For each frame: class request 0x03 (`READY`), then one overlapped `WinUsb_ReadPipe` of 0xC8600 bytes (854 × 480 × 2 + 512 rounded to 512) on pipe 0. It checks the magic, version 2 and a non-zero size, then reads bpp, image width/height and orientation from the [frame header](#frame-header) and the image (RGB565) at offset 0x200. A failure (e.g. `READY` timing out in state 8) ends the projection.
