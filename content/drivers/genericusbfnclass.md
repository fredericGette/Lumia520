## Genericusbfnclass.sys

Generic USB function class driver (Microsoft, "GenericUsbFn").  
It is the KMDF function driver of a USB *function* (device-side) interface: it exposes the interface to user mode with a symbolic link `\DosDevices\GenericUsbFn_<interface GUID>` and a device interface of the same GUID, and forwards the public `IOCTL_GENERICUSBFN_*` requests of a user-mode service/application to the USB function class extension below it, converted into the corresponding kernel `IOCTL_INTERNAL_USBFN_*` requests. It doesn't implement any transfer itself: it is a thin user-mode → kernel-mode translator.  
The pipes and the interface GUID are not hardcoded: they are retrieved from the lower driver with [internal IOCTL 0x2AC022](#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info) (`IOCTL_INTERNAL_USBFN_GET_CLASS_INFO`), i.e. from the USB function interface configuration of the class extension (registry `HKLM\SYSTEM\CurrentControlSet\Control\USBFN` ?).  
It contains a statically linked copy of the Microsoft library `kusbfnclasslib` (`src\drivers\product\drivers\usbfn\lib\kusbfnclasslib\kusbfnclasslib.c`).  
Built `Jan 23 2015 18:07:53`. PDB: `genericusbfnclass.pdb`.  
The same binary (byte-identical, MD5 `add2618c05260684daabc0e0b5792cc0`) is also installed as [genericusbfnclassipoverusb.sys](./genericusbfnclassipoverusb.md) and [genericusbfnclassmtp.sys](./genericusbfnclassmtp.md), one service per USB function interface.  
It only imports `ntoskrnl.exe` (`RtlCopyUnicodeString`, `ExAllocatePoolWithTag`, `ExFreePoolWithTag`, `DbgPrint`, `_vsnwprintf`, `RtlGUIDFromString`) and `WDFLDR.SYS`. There's no ETW / WPP provider: all the traces are `DbgPrint` (prefix `GenericUsbFnClass`).

There's no device name.  
Symbolic link : `\DosDevices\GenericUsbFn_{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}` (one per instance, GUID = `InterfaceGuid` of the class information)  

There's no parameters in the registry.  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device of its stack (`WdfDeviceGetIoTarget`) | USB function class extension (UFX) / controller driver ? | Receives the forwarded `IOCTL_INTERNAL_USBFN_*`. The internal IOCTLs of the same family 0x2AC03A / 0x2AC03E are handled by [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md) in the controller stack |

### WDF configuration

`DriverEntry` (0x10003000): `WdfDriverCreate` with `EvtDriverDeviceAdd`, pool tag `GUFN` (0x4E465547). A failure is returned as `STATUS_UNSUCCESSFUL` (0xC0000001).

`EvtDriverDeviceAdd` (`OnDeviceAdd`, 0x10004000):
- PnP/power callbacks: only `EvtDevicePrepareHardware` (0x10004144).
- `WdfDeviceCreate`, device context `GENERICCLASS_CONTEXT` (4 bytes: pointer to the `KUSBFNCLASSLIB_CONTEXT` below).
- One default queue, `WdfIoQueueDispatchSequential`, `PowerManaged` = `WdfFalse`, with only `EvtIoDeviceControl` (`OnIoDeviceControl`, 0x10002174).
- `UsbFnKmClassLibRegisterClassDevice` (`sub_1000233C`): creates the class-library object and adds it to a global `WDFCOLLECTION` (protected by a `WDFSPINLOCK`, both created on the first call).
- `AssignS0IdleSettings` (`sub_10002100`): `WdfDeviceAssignS0IdleSettings` with the defaults of `WDF_DEVICE_POWER_POLICY_IDLE_SETTINGS_INIT(IdleCanWakeFromS0)`: `DxState` = `PowerDeviceMaximum`, `IdleTimeout` = 0 (default), `UserControlOfIdleSettings` = `IdleAllowUserControl`, `Enabled` = `WdfUseDefault`, `PowerUpIdleDeviceOnSystemWake` = `WdfUseDefault`, `IdleTimeoutType` = `DriverManagedIdleTimeout`, `ExcludeD3Cold` = `WdfUseDefault`. A failure is only traced (`OnDeviceAdd` returns `STATUS_SUCCESS`).
- Any other failure → `STATUS_UNSUCCESSFUL` (0xC0000001).

`KUSBFNCLASSLIB_CONTEXT` (0x44 bytes, allocated with pool tag `Ufkm`, 0x6D6B6655):  
| Offset | Comment |
|--------|---------|
| 0x00 | Size = 0x44 |
| 0x04 | Signature `UFNK` (0x4B4E4655). Checked by the library functions, `WdfVerifierKeBugCheck` (0x121) when wrong |
| 0x08 | BYTE, 0 |
| 0x0C | 2 |
| 0x10 | `WDFDEVICE` |
| 0x14 | `WDFLOOKASIDE` "notification" list (elements of 12 bytes, NonPagedPoolNx) |
| 0x1C | `WDFLOOKASIDE` "StallSet" list (elements of 1 byte, NonPagedPoolNx) |
| 0x20 / 0x24 | Full-speed pipe count / array of {`WDFMEMORY`, `PipeId`} (8 bytes per pipe) |
| 0x28 / 0x2C | High-speed pipe count / array |
| 0x30 / 0x34 | Super-speed pipe count / array |
| 0x40 | `WDFSPINLOCK` "notification" |

The lookaside lists, the notification spinlock and the pipe `WDFMEMORY` objects (`WdfMemoryCreatePreallocated` on the 4-byte `PipeId`) are created but never used by this driver (library code used by other class drivers ?).

### Prepare hardware

`EvtDevicePrepareHardware` (`OnDevicePrepareHardware`, 0x10004144):
1. `UsbFnKmClassLibGetClassInformation` (`sub_100025D0`): sends [internal IOCTL 0x2AC022](#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info) to the lower device, then copies the pipe IDs of the full-, high- and super-speed interfaces into the library context. Failure → `STATUS_UNSUCCESSFUL`.
2. If `HasInterfaceGuid` is set, builds `\DosDevices\GenericUsbFn_` + `InterfaceGuid` (`RtlUnicodeStringPrintf("%s%s")`, max 132 bytes) and calls `WdfDeviceCreateSymbolicLink`.
3. `RtlGUIDFromString` on `InterfaceGuid` (38 characters, with braces), `WdfDeviceCreateDeviceInterface` with this GUID (no reference string) and `WdfDeviceSetDeviceInterfaceState(TRUE)`.

> [!NOTE]
> When `HasInterfaceGuid` is 0, it traces "No interface GUID found." but still calls `WdfDeviceCreateSymbolicLink` with an empty name, so `EvtDevicePrepareHardware` fails and the device doesn't start ?.

The user-mode side therefore opens the interface either with `\\.\GenericUsbFn_{GUID}` or by enumerating the device interface `{GUID}` (SetupDi / CM API).

### USBFN_CLASS_INFORMATION_PACKET

Output buffer of [internal IOCTL 0x2AC022](#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info) (748 bytes, offsets checked in the binary; names from the public `usbfnioctl.h` / `usbfnbase.h`):  
| Bytes | Name | Comment |
|-------|------|---------|
| 000-0C3 | FullSpeedClassInterface | `USBFN_CLASS_INTERFACE` (196 bytes) |
| 0C4-187 | HighSpeedClassInterface | `USBFN_CLASS_INTERFACE` |
| 188-1D7 | InterfaceName | WCHAR[40], not used |
| 1D8-225 | InterfaceGuid | WCHAR[39], e.g. `{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}` |
| 226 | HasInterfaceGuid | BOOLEAN |
| 227 | | padding |
| 228-2EB | SuperSpeedClassInterface | `USBFN_CLASS_INTERFACE` |

`USBFN_CLASS_INTERFACE` (196 bytes):  
| Bytes | Name | Comment |
|-------|------|---------|
| 00 | InterfaceNumber | |
| 01 | PipeCount | Number of valid entries in PipeArr (max 16) |
| 02-03 | | padding |
| 04-C3 | PipeArr | 16 × `USBFN_PIPE_INFORMATION` (12 bytes): `USB_ENDPOINT_DESCRIPTOR` (7 bytes) + 1 padding byte + `USBFNPIPEID` PipeId (4 bytes) |

---

### IOCTL forwarding

All the IOCTLs are processed by Genericusbfnclass.sys in `OnIoDeviceControl` (0x10002174) the same way: the IoControlCode of the IRP stack location is replaced by the internal code, the MajorFunction is changed to `IRP_MJ_INTERNAL_DEVICE_CONTROL` (0x0F), the request is formatted with `WdfRequestWdmFormatUsingStackLocation` and sent to the lower device with `WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET`. The buffers are not checked nor touched: they are passed unchanged, the lower driver completes the request. If `WdfRequestSend` fails, the request is completed with `WdfRequestGetStatus`.  
Any other IoControlCode → `STATUS_NOT_SUPPORTED` (0xC00000BB). This includes the later public codes `IOCTL_GENERICUSBFN_GET_CLASS_INFO_EX` (0x22C03A) and `IOCTL_GENERICUSBFN_REGISTER_USB_STRING` (0x22C041), which this WP8.1 build doesn't know.

The IOCTL codes are those of the public `genericusbfnioctl.h` (CTL_CODE(0x22, n, …, FILE_READ_ACCESS | FILE_WRITE_ACCESS)); the internal ones are those of `usbfnioctl.h` (CTL_CODE(0x2A, n, …)), with the same function number and method:  
| IOCTL (user mode) | Name | Internal IOCTL sent | Name | Method |
|-------------------|------|---------------------|------|--------|
| 0x22C00D | IOCTL_GENERICUSBFN_TRANSFER_IN | 0x2AC00D | IOCTL_INTERNAL_USBFN_TRANSFER_IN | METHOD_IN_DIRECT |
| 0x22C011 | IOCTL_GENERICUSBFN_TRANSFER_IN_APPEND_ZERO_PKT | 0x2AC011 | IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT | METHOD_IN_DIRECT |
| 0x22C016 | IOCTL_GENERICUSBFN_TRANSFER_OUT | 0x2AC016 | IOCTL_INTERNAL_USBFN_TRANSFER_OUT | METHOD_OUT_DIRECT |
| 0x22C018 | IOCTL_GENERICUSBFN_CONTROL_STATUS_HANDSHAKE_IN | 0x2AC018 | IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_IN | METHOD_BUFFERED |
| 0x22C01C | IOCTL_GENERICUSBFN_CONTROL_STATUS_HANDSHAKE_OUT | 0x2AC01C | IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_OUT | METHOD_BUFFERED |
| 0x22C022 | IOCTL_GENERICUSBFN_GET_CLASS_INFO | 0x2AC022 | IOCTL_INTERNAL_USBFN_GET_CLASS_INFO | METHOD_OUT_DIRECT |
| 0x22C026 | IOCTL_GENERICUSBFN_GET_PIPE_STATE | 0x2AC026 | IOCTL_INTERNAL_USBFN_GET_PIPE_STATE | METHOD_OUT_DIRECT |
| 0x22C029 | IOCTL_GENERICUSBFN_SET_PIPE_STATE | 0x2AC029 | IOCTL_INTERNAL_USBFN_SET_PIPE_STATE | METHOD_IN_DIRECT |
| 0x22C02C | IOCTL_GENERICUSBFN_ACTIVATE_USB_BUS | 0x2AC02C | IOCTL_INTERNAL_USBFN_ACTIVATE_USB_BUS | METHOD_BUFFERED |
| 0x22C030 | IOCTL_GENERICUSBFN_DEACTIVATE_USB_BUS ? | 0x2AC030 | IOCTL_INTERNAL_USBFN_DEACTIVATE_USB_BUS ? | METHOD_BUFFERED |
| 0x22C036 | IOCTL_GENERICUSBFN_BUS_EVENT_NOTIFICATION | 0x2AC036 | IOCTL_INTERNAL_USBFN_BUS_EVENT_NOTIFICATION | METHOD_OUT_DIRECT |

The buffer layouts are those documented by Microsoft for the public IOCTLs, e.g. [IOCTL_GENERICUSBFN_TRANSFER_IN](https://learn.microsoft.com/en-us/windows/win32/api/genericusbfnioctl/ni-genericusbfnioctl-ioctl_genericusbfn_transfer_in): InputBuffer = `USBFNPIPEID` (4 bytes), OutputBuffer = data. See the [genericusbfnioctl.h reference](https://learn.microsoft.com/en-us/windows/win32/api/genericusbfnioctl).

Example, IOCTL 0x22C00D:  
| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x3 |
| Access | READ_AND_WRITE |
| Method | METHOD_IN_DIRECT |

---

### internal IOCTL 0x2AC022 — IOCTL_INTERNAL_USBFN_GET_CLASS_INFO

This internal IOCTL is sent by Genericusbfnclass.sys to the lower driver of its stack (USB function class extension ?), from `UsbFnKmClassLibHelperSendDeviceIoControlSynchronous` (`sub_100026D0`), during `EvtDevicePrepareHardware`.  
It is sent with `WdfIoTargetSendInternalIoctlSynchronously`, no input buffer, the output buffer as a `WDFMEMORY` handle (`WdfMemoryCreatePreallocated` on the caller's 748-byte buffer), send options `WDF_REQUEST_SEND_OPTION_TIMEOUT | WDF_REQUEST_SEND_OPTION_SYNCHRONOUS` with `Timeout` = 20000 (0x4E20). The value is positive, so WDF treats it as an *absolute* time (2 ms after 1601-01-01, already in the past) and not as a relative 2 ms: the request only succeeds when the lower driver completes it immediately ?  
It is also the translation of the user-mode `IOCTL_GENERICUSBFN_GET_CLASS_INFO` (0x22C022), see [IOCTL forwarding](#ioctl-forwarding).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x8 |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_GET_CLASS_INFO | lower device | 0 | 748 |

Outputbuffer: [USBFN_CLASS_INFORMATION_PACKET](#usbfn_class_information_packet).

A failure → "Failed to query for class information via IOCTL." and `EvtDevicePrepareHardware` fails with `STATUS_UNSUCCESSFUL`.

### Interface GUID

Device interface class GUID: not fixed, it's the `InterfaceGuid` returned by [internal IOCTL 0x2AC022](#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info) (one per configured USB function interface).
