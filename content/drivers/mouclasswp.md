## Mouclasswp.sys

Windows Phone mouse class driver (Microsoft).  
It is a WDM port of the WDK `mouclass` sample (same function names: `MouseClassServiceCallback`, `MouCreateClassObject`, `MouseClassFindMorePorts`, …) with three phone changes: the device interface is a private `GUID_CLASS_WPMOUSE`, the symbolic link is `\DosDevices\PhonePointerClass<n>`, and the DACL also gives read/write access to `ALL APPLICATION PACKAGES`.  
It is an upper filter (class driver) on mouse port stacks: it connects its `MouseClassServiceCallback` to the port driver below with [internal IOCTL 0xF0203](#internal-ioctl-0xf0203--ioctl_internal_mouse_connect), queues the 24-byte `MOUSE_INPUT_DATA` records the port delivers, and returns them to the readers of `\Device\PointerClass<n>` (the shell, see [UIXRender.dll](../libraries/uixrender.md), which reads `\Device\PointerClass0`). It also serves legacy (non-PnP) ports `\Device\PointerPort<n>`.  
No WDF, no ETW/WPP. PDB `mouclasswp.pdb`. It imports `ntoskrnl.exe`, `HAL.dll` (`KeGetCurrentIrql`) and `WMILIB.SYS`.

Device name : `\Device\PointerClass<n>` (`<n>` = 0, 1, … in creation order, `FILE_DEVICE_MOUSE`, extension 0xCC bytes, `DO_BUFFERED_IO`)  
Symbolic link : `\DosDevices\PhonePointerClass<n>`  
Device name for a legacy port : `\Device\PointerClassLegacy<n>` (only when `ConnectMultiplePorts` = 0)  

The base name `PointerClass` comes from the registry value `PointerDeviceBaseName`. The name index is a global counter (`dword_10007040`) shared by all the devices; on `STATUS_OBJECT_NAME_COLLISION` the next index is tried. When `ConnectMultiplePorts` ≠ 0, only the first device (the "grand master", `Globals`) gets a name and every port is connected to it; the other devices are unnamed.

Security descriptor (`MouClassSetDeviceDacl`, 0x10005744, applied with `ZwSetSecurityObject(DACL_SECURITY_INFORMATION)`):  
| SID | Access |
|-----|--------|
| SYSTEM (`SeLocalSystemSid`) | 0xC0010000 GENERIC_READ \| GENERIC_WRITE \| DELETE |
| Administrators (`SeAliasAdminsSid`) | 0xC0010000 GENERIC_READ \| GENERIC_WRITE \| DELETE |
| Users (`SeAliasUsersSid`) | 0x80000000 GENERIC_READ |
| ALL APPLICATION PACKAGES (`SeAllAppPackagesSid`) | 0xC0000000 GENERIC_READ \| GENERIC_WRITE |

There's no capability check on open (unlike [kbdclasswp.sys](./kbdclasswp.md)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\mouclasswp` (service name ?)  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters` (`MouConfiguration`, 0x10004534, `RtlQueryRegistryValuesEx` if exported, otherwise `RtlQueryRegistryValues`, `RTL_REGISTRY_ABSOLUTE | RTL_REGISTRY_OPTIONAL`, all `RTL_QUERY_REGISTRY_DIRECT`):  
| Registry value | value | comment |
|----------------|-------|---------|
| MouseDataQueueSize | 100 | REG_DWORD, number of records of the input queue. 0 or > 0xAAAAAAA → 100. Stored ×24 (size in bytes: 2400 by default) |
| MaximumPortsServiced | 1 | REG_DWORD, maximum number of legacy ports `\Device\PointerPort<n>` opened |
| PointerDeviceBaseName | PointerClass | REG_SZ, base of the device names |
| ConnectMultiplePorts | 0 | REG_DWORD. ≠ 0: one named "grand master" device for all the ports (the internal flag `dword_10007094` is the inverse of this value) |

If the query fails, all four defaults are used.

Registry key of the device (`IoOpenDeviceRegistryKey(PLUGPLAY_REGKEY_DEVICE)`):  
| Registry value | value | comment |
|----------------|-------|---------|
| WaitWakeEnabled | ? | REG_DWORD (≤ 4 bytes). Read in `MouseStart` (`MouseClassGetWaitWakeEnableState`, 0x10005200); written by `MouseToggleWaitWakeWorker` when wake is enabled/disabled through WMI. If absent, wake is enabled when `RtlVerifyVersionInfo` says workstation (`VER_PRODUCT_TYPE` = 1) and `ZwPowerInformation(SystemPowerCapabilities)` reports a sleep state S1/S2/S3 at least as deep as the device wake capability |

`HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\PointerClass` (`RtlWriteRegistryValue(RTL_REGISTRY_DEVICEMAP)`, `MouseAddDeviceEx`): value = device name (e.g. `\Device\PointerClass0`), data = service registry path (REG_SZ). The legacy ports are counted from the values of `HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\PointerPort` (`MouDeterminePortsServiced`, 0x10005BF4).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Device below in the PnP stack (`IoAttachDeviceToDeviceStack`) | mouse port / HID mouse driver ? | [internal IOCTL 0xF0203](#internal-ioctl-0xf0203--ioctl_internal_mouse_connect) at `AddDevice`, then `IRP_MJ_CREATE` / `IRP_MJ_CLOSE` forwarded on the first open / last close, pass-through of the HID and button IOCTLs |
| `\Device\PointerPort0` … `\Device\PointerPort<MaximumPortsServiced-1>` | legacy port driver (none known on the Lumia 520 ?) | `IoGetDeviceObjectPointer`; [internal IOCTL 0xF0203](#internal-ioctl-0xf0203--ioctl_internal_mouse_connect), then [0xF0803 / 0xF1003](#internal-ioctl-0xf0803--ioctl_internal_mouse_enable) on the first open / last close. Searched again later by `MouseClassFindMorePorts` (`IoRegisterDriverReinitialization`) |

Pool tag: `MuoC` (0x436F754D, written `'CouM'` in the source).

### Initialisation

`DriverEntry` (0x10004000):
1. Clears `Globals` (0x10007060, 0x320 bytes), copies the registry path, `MouConfiguration`.
2. If `ConnectMultiplePorts` ≠ 0: creates the grand master device (`MouCreateClassObject`) and registers it (`MouseAddDeviceEx`).
3. Builds `\Device\PointerPort` (base name with `Class` replaced by `Port`), counts the ports in the device map, and for each index `0 … min(count, MaximumPortsServiced) - 1`: creates a legacy class device, opens `\Device\PointerPort<i>` and connects to it (`MouseAddDeviceEx`).
4. `IoRegisterDriverReinitialization(MouseClassFindMorePorts)`.
5. Dispatch: `IRP_MJ_CREATE` `MouseClassCreate`, `IRP_MJ_CLOSE` `MouseClassClose`, `IRP_MJ_READ` `MouseClassRead`, `IRP_MJ_FLUSH_BUFFERS` `MouseClassFlush`, `IRP_MJ_DEVICE_CONTROL` `MouseClassDeviceControl`, `IRP_MJ_INTERNAL_DEVICE_CONTROL` `MouseClassPassThrough`, `IRP_MJ_CLEANUP` `MouseClassCleanup`, `IRP_MJ_PNP` `MousePnP`, `IRP_MJ_SYSTEM_CONTROL` `MouseClassSystemControl`, `IRP_MJ_POWER` `MouseClassPower`, `AddDevice` `MouseAddDevice`.

`MouseAddDevice` (0x100050D0): creates the class device (`\Device\PointerClass<n>` + symbolic link + DACL), allocates the input queue (`NonPagedPoolNx`, `MouseDataQueueSize` × 24 bytes), attaches to the stack, sets `DO_POWER_PAGABLE`, registers `GUID_CLASS_WPMOUSE` on the PDO and sends [internal IOCTL 0xF0203](#internal-ioctl-0xf0203--ioctl_internal_mouse_connect) to the device below.

`MousePnP` (0x10002688):
* `IRP_MN_START_DEVICE`: forwarded first, then `MouseStart` (in a work item from the completion routine): `IRP_MN_QUERY_CAPABILITIES` (stores `DeviceState[]`, `SystemWake`, `DeviceWake`), wake-enable state, `IoWMIRegistrationControl(WMIREG_ACTION_REGISTER)`, enables the port if a reader is already open, `IoSetDeviceInterfaceState(TRUE)`, and a wait-wake IRP if enabled.
* `IRP_MN_REMOVE_DEVICE`: cancels the wait-wake IRP, WMI deregistration, disables the interface, completes the pending reads with `STATUS_CANCELLED`, detaches and deletes the device.
* `IRP_MN_SURPRISE_REMOVAL`: same cleanup; later reads fail with `STATUS_DEVICE_NOT_CONNECTED` (0xC000009D).
* `IRP_MN_STOP_DEVICE`: disables the port (grand master mode only).

### Reading the input

* `IRP_MJ_CREATE` (`MouseClassCreate`, 0x10001B3C): refused with `STATUS_UNSUCCESSFUL` while a PnP device is not started. The file object is marked as a reader (`FsContext2` = `DriverEntry`) — any opener allowed by the DACL, there's no `SeTcbPrivilege` check as in the original sample. On the first open the port is enabled (PnP: `IRP_MJ_CREATE` sent down; legacy: [0xF0803](#internal-ioctl-0xf0803--ioctl_internal_mouse_enable)).
* `IRP_MJ_CLOSE`: the reverse (`IRP_MJ_CLOSE` down, or [0xF1003](#internal-ioctl-0xf1003--ioctl_internal_mouse_disable)).
* `IRP_MJ_READ` (`MouseClassRead`, 0x1000206C): length 0 → success with 0 bytes; length not a multiple of 24 → `STATUS_BUFFER_TOO_SMALL` (0xC0000023); file not marked as a reader → `STATUS_PRIVILEGE_NOT_HELD` (0xC0000061). If records are queued, as many as fit are copied and the read completes; otherwise it stays pending (cancel routine `MouseClassCancel`). [UIXRender.dll](../libraries/uixrender.md) reads 0x78 bytes = 5 records.
* `MouseClassServiceCallback` (0x10002178), called by the port at DISPATCH_LEVEL with `(ClassDevice, InputDataStart, InputDataEnd, &InputDataConsumed)`: fills the oldest pending read first, puts the rest into the circular queue, then serves the other pending reads from the queue, and completes them with priority boost 6 (`IO_MOUSE_INCREMENT`). Unlike the original sample, it doesn't check for queue overflow (no error log, the counter keeps growing ?).
* `IRP_MJ_FLUSH_BUFFERS`: empties the queue; `STATUS_NOT_SUPPORTED` on an unnamed device of the grand master, `STATUS_PRIVILEGE_NOT_HELD` if not a reader.
* `IRP_MJ_CLEANUP`: completes the pending reads of this file object with `STATUS_CANCELLED`.

The records are not modified by the driver; layout `MOUSE_INPUT_DATA` (24 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 00 00 | UnitId |
| 02-03 | ? | Flags (`MOUSE_MOVE_RELATIVE` 0, `MOUSE_MOVE_ABSOLUTE` 1, `MOUSE_VIRTUAL_DESKTOP` 2, …) |
| 04-05 | ? | ButtonFlags (`MOUSE_LEFT_BUTTON_DOWN` 1, `MOUSE_LEFT_BUTTON_UP` 2, …, `MOUSE_WHEEL` 0x400) |
| 06-07 | ? | ButtonData (wheel delta) |
| 08-0B | ? | RawButtons |
| 0C-0F | ? | LastX |
| 10-13 | ? | LastY |
| 14-17 | ? | ExtraInformation |

### Power and WMI

The device follows the system power IRPs (`PoRequestPowerIrp` for the matching D-state, `DeviceState[]` from the capabilities) and keeps a wait-wake IRP (`IRP_MN_WAIT_WAKE`) when wake is enabled.

WMI (`WMILIB`, `MouseClassWmiGuidList` at 0x1000701C):  
| GUID | Name | Comment |
|------|------|---------|
| `{4731F89B-71CB-11D1-A52C-00A0C9062910}` | `MSMouse_ClassInformation` | Query: 8 bytes = the address of the class device object (`MouseClassQueryWmiDataBlock` returns the `DEVICE_OBJECT` pointer, a kernel address) |
| `{A9546A82-FEB0-11D0-BD26-00AA00B7B32A}` | `GUID_POWER_DEVICE_WAKE_ENABLE` | Query: 1 byte, wait-wake IRP pending. Set: 1 byte, enables/disables wake (`MouseToggleWaitWake`, stored in `WaitWakeEnabled`) |

### Device extension

0xCC bytes, initialised from the template at `Globals + 0x3C`:  
| Offset | Comment |
|--------|---------|
| 0x00 | Own device object |
| 0x04 | Class device that owns the queue (itself, or the grand master) |
| 0x08 | Device below (port) |
| 0x0C | PDO |
| 0x10 | Remove lock (tag `MuoC`) |
| 0x28 | PnP device (0 = legacy port or grand master) |
| 0x29 | Started |
| 0x30 | Number of reader handles |
| 0x34 | Number of queued records |
| 0x38 | Interface symbolic link name (`UNICODE_STRING`) |
| 0x40, 0x44, 0x48 | Queue buffer, DataIn, DataOut |
| 0x54 | Queue size in bytes |
| 0x58 | Spin lock of the queue, 0x5C list of the pending reads |
| 0x68, 0x6C | System power state, device power state |
| 0x70 | Index in the port list (`Globals + 4`, entries of 12 bytes) |
| 0x74 | `WMILIB_CONTEXT` |
| 0x94 | `DeviceState[S1…S5]` from the capabilities |
| 0xA8, 0xAC | `SystemWake`, `DeviceWake` |
| 0xB0 | Wait-wake IRP |
| 0xB8 | Target device notification handle (legacy port) |
| 0xC8 | Port enabled |
| 0xC9 | Wake enabled |
| 0xCA | Surprise removed |

---

### IOCTL 0xF0000 — IOCTL_MOUSE_QUERY_ATTRIBUTES

This IOCTL is processed by Mouclasswp.sys (`MouseClassDeviceControl`, 0x10005494) and forwarded to the port

| Property | Value |
|----------|-------|
| Device | 0xF |
| Function | 0x0 (0) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_MOUSE_QUERY_ATTRIBUTES | 0 or ≥ 2 | 12 (`MOUSE_ATTRIBUTES`, filled by the port) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 00 00 | UnitId: index of the port, used only on the grand master (an unknown or disabled port → the first enabled one; none → `STATUS_INVALID_PARAMETER` 0xC000000D) |

An input buffer of 1 byte → `STATUS_BUFFER_TOO_SMALL`. On an unnamed device of the grand master → `STATUS_NOT_SUPPORTED`. The IRP is turned into an `IRP_MJ_INTERNAL_DEVICE_CONTROL` with the same code and sent to the port.

Outputbuffer (`MOUSE_ATTRIBUTES`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | MouseIdentifier |
| 02-03 | ? | NumberOfButtons |
| 04-05 | ? | SampleRate |
| 08-0B | ? | InputDataQueueLength |

---

### Pass-through IOCTLs

These IOCTLs are forwarded unchanged to the device below (`MouseClassDeviceControl`), only on a PnP device (otherwise `STATUS_INVALID_DEVICE_REQUEST` 0xC0000010, like every other code):  
| IOCTL | Name |
|-------|------|
| 0xB0190 | IOCTL_HID_GET_DRIVER_CONFIG |
| 0xB0191 | IOCTL_HID_SET_FEATURE |
| 0xB0192 | IOCTL_HID_GET_FEATURE |
| 0xB0193 | IOCTL_HID_GET_COLLECTION_DESCRIPTOR |
| 0xB0194 | IOCTL_HID_SET_DRIVER_CONFIG |
| 0xB0197 | IOCTL_HID_FLUSH_QUEUE |
| 0xB0198 | IOCTL_HID_GET_POLL_FREQUENCY_MSEC |
| 0xB019A | IOCTL_GET_PHYSICAL_DESCRIPTOR |
| 0xB019C | IOCTL_HID_SET_POLL_FREQUENCY_MSEC |
| 0xB019E | IOCTL_HID_GET_HARDWARE_ID |
| 0xB01A0 | IOCTL_GET_NUM_DEVICE_INPUT_BUFFERS |
| 0xB01A4 | IOCTL_SET_NUM_DEVICE_INPUT_BUFFERS |
| 0xB01A8 | IOCTL_HID_GET_COLLECTION_INFORMATION |
| 0xB01BA | IOCTL_HID_GET_MANUFACTURER_STRING |
| 0xB01BE | IOCTL_HID_GET_PRODUCT_STRING |
| 0xB01C2 | IOCTL_HID_GET_SERIALNUMBER_STRING |
| 0xB01E2 | IOCTL_HID_GET_INDEXED_STRING |
| 0x294140 | IOCTL_GET_SYS_BUTTON_CAPS |
| 0x294144 | IOCTL_GET_SYS_BUTTON_EVENT |

0xB0195 (`IOCTL_HID_SET_OUTPUT_REPORT`) and 0xB0196 are refused. All `IRP_MJ_INTERNAL_DEVICE_CONTROL` requests are passed down without any check (`MouseClassPassThrough`).

---

### internal IOCTL 0xF0203 — IOCTL_INTERNAL_MOUSE_CONNECT

This IOCTL is sent by Mouclasswp.sys to the port (device below, or `\Device\PointerPort<n>`) (`MouSendConnectRequest`, 0x10005E50, `IoBuildDeviceIoControlRequest` internal, synchronous)

| Property | Value |
|----------|-------|
| Device | 0xF |
| Function | 0x80 (128) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_MOUSE_CONNECT | port | 8 | 0 |

Inputbuffer (`CONNECT_DATA`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ClassDeviceObject: the class device that owns the queue (extension `+4`) |
| 04-07 | ? | ClassService: address of `MouseClassServiceCallback` (0x10002178, +1 for Thumb, relocated at load) |

### internal IOCTL 0xF0803 — IOCTL_INTERNAL_MOUSE_ENABLE

This IOCTL is sent by Mouclasswp.sys to a legacy port `\Device\PointerPort<n>` on the first open (`MouEnableDisablePort`, 0x10005CC0)

| Property | Value |
|----------|-------|
| Device | 0xF |
| Function | 0x200 (512) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_MOUSE_ENABLE | `\Device\PointerPort<n>` | 0 | 0 |

### internal IOCTL 0xF1003 — IOCTL_INTERNAL_MOUSE_DISABLE

This IOCTL is sent by Mouclasswp.sys to a legacy port `\Device\PointerPort<n>` on the last close (`MouEnableDisablePort`)

| Property | Value |
|----------|-------|
| Device | 0xF |
| Function | 0x400 (1024) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_MOUSE_DISABLE | `\Device\PointerPort<n>` | 0 | 0 |

For a PnP device the enable/disable is done with `IRP_MJ_CREATE` / `IRP_MJ_CLOSE` sent down the stack instead.

---

### Interface GUID

Interface registered on the PDO in `MouseAddDevice`, enabled in `MouseStart` (`GUID_CLASS_WPMOUSE`, not the standard `GUID_DEVINTERFACE_MOUSE` `{378DE44C-56EF-11D1-BC8C-00A0C91405DD}`)  
`{53FE41E5-01AC-4243-BFD1-963EB724CD0C}`

### Other GUID

WMI class information (`MSMouse_ClassInformation`)  
`{4731F89B-71CB-11D1-A52C-00A0C9062910}`

WMI wake enable (`GUID_POWER_DEVICE_WAKE_ENABLE`)  
`{A9546A82-FEB0-11D0-BD26-00AA00B7B32A}`

Target device notifications of a legacy port (`IoRegisterPlugPlayNotification(EventCategoryTargetDeviceChange)`, `MouseClassPlugPlayNotification`): `GUID_TARGET_DEVICE_QUERY_REMOVE` `{CB3A4006-46F0-11D0-B08F-00609713053F}` and `GUID_TARGET_DEVICE_REMOVE_COMPLETE` `{CB3A4008-46F0-11D0-B08F-00609713053F}` disable the port, `GUID_TARGET_DEVICE_REMOVE_CANCELLED` `{CB3A4007-46F0-11D0-B08F-00609713053F}` enables it again.
