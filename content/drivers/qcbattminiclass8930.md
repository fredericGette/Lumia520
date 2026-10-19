## Qcbattminiclass8930.sys

Qualcomm **battery miniclass** driver (`P:\BattMiniClass\rel\8.2.1.1\BatteryMiniclass\build\arm\Release\qcbattminiclass8930.pdb`, KMDF, 86 functions).  
It's a thin adapter between the Microsoft battery class driver [battc.sys](./battc.md) and a Qualcomm "battery manager" device: every `BATTERY_MINIPORT_INFO` callback is turned into one synchronous `IOCTL_BATT_MNGR_*` request (device type `0x800B`) sent to the device that exposes the interface `{F4116444-4837-49A5-B2C7-433FE501F2AA}`. The driver has no battery logic of its own: no registry values, no ACPI method, no hardware access.  
The battery class device is only initialised once that battery manager interface arrives, and torn down when it goes away. None of the drivers documented so far exposes `{F4116444-…}` or handles the `0x800B` IOCTLs ([qcpmic8930.sys](./qcpmic8930.md) only knows their names), and on the Lumia 520 the miniclass used by [battc.sys](./battc.md) is [NokiaEnergyDriver.sys](./nokiaenergydriver.md). This driver is probably inactive on the Lumia 520 ?

Device name : none (unnamed WDF device)  
Symbolic link : `\DosDevices\Global\QCBatteryMiniclass` (created each time the battery manager arrives)  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcbattminiclass8930` ?

There's no parameters in the registry. `DriverEntry` only keeps a copy of the registry path in the driver context.

GUID of the ETW provider (WPP control GUID, registered with `EtwRegisterClassicProvider`):  
`{97413F1D-5298-4884-94EB-6FEFBC0AC4A7}`  
Trace flags (`dword_410AE0`): bit 0 = errors, bit 1 = outgoing IOCTL names (`PmicIoctlCodeToTraceName`, sub_402470), bit 2 = function entry/exit. The source files named in the traces are `PmicValidateBattMini.c`, `PmicValidateIoctl.c` and `PmicDriverRequest.c`.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Device with the interface `{F4116444-4837-49A5-B2C7-433FE501F2AA}` | ? (Qualcomm battery manager) | Found with `IoRegisterPlugPlayNotification` (`PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`), opened with `IoGetDeviceObjectPointer` (`GENERIC_ALL`). Target of all the `IOCTL_BATT_MNGR_*` requests |
| Battery class | [battc.sys](./battc.md) | `BatteryClassInitializeDevice`, `BatteryClassIoctl`, `BatteryClassSystemControl`, `BatteryClassQueryWmiDataBlock`, `BatteryClassStatusNotify`, `BatteryClassUnload` |
| Thermal framework | ? | Can call the `PassiveCooling` routine of the `GUID_THERMAL_COOLING_INTERFACE` this driver exposes |
| `\DosDevices\Global\QCBatteryMiniclass` | ? (the battery manager ?) | Sender of `IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS` |

### Initialisation

1. `DriverEntry` (0x401BD0): WPP init, `WdfDriverCreate` (pool tag `0mbq`, 0x71626D30), keeps the registry path.
2. `EvtDriverDeviceAdd` (0x401CE4) → `sub_412008`:
   * PnP/power callbacks: `EvtDevicePrepareHardware` (sub_4018D4, only checks the resource descriptors, `STATUS_DEVICE_CONFIGURATION_ERROR` 0xC0000182 if one is missing), `EvtDeviceReleaseHardware` (sub_40192C), `EvtDeviceD0Exit` (sub_401968), `EvtDeviceSurpriseRemoval` (sub_401A38), `EvtDeviceQueryRemove` (sub_401A20), `EvtDeviceQueryStop` (sub_401A00, always `STATUS_UNSUCCESSFUL`: the device can't be stopped). No `EvtDeviceD0Entry`.
   * WDM IRP preprocess callbacks for `IRP_MJ_DEVICE_CONTROL` (sub_4121B4) and `IRP_MJ_SYSTEM_CONTROL` (sub_41224C), see [IRP handling](#irp-handling).
   * `WdfDeviceCreate`, two wait locks, a sequential default queue (`EvtIoDeviceControl` 0x401E5C) with a 10 s WDF timer (sub_401DF0) that completes a request stored in the queue context; nothing ever stores a request there, so the timer is dead code.
   * `WdfDeviceSetDeviceState` (`NotDisableable` = false).
   * Registers for the arrival/removal of `{F4116444-…}` (`RegisterForInterfaceEvent`, sub_402AC4, callback sub_401AEC).
3. Arrival of `{F4116444-…}` (`GUID_DEVICE_INTERFACE_ARRIVAL`): opens the device, then `sub_401708(Device, TRUE)`:
   * The first time only: creates the device interface `{6C7FF145-BE42-4ED4-ADF1-2ECD06EF23B7}` and adds the query interface `GUID_THERMAL_COOLING_INTERFACE` (see [Thermal cooling interface](#thermal-cooling-interface)).
   * `BatteryClassInitializeDevice` (sub_4015B0) with the `BATTERY_MINIPORT_INFO` below.
   * Fills the `WMILIB_CONTEXT` (no GUIDs of its own; `QueryWmiRegInfo` = sub_412318 with `WMIREG_FLAG_INSTANCE_PDO`, `QueryWmiDataBlock` = sub_41237C → `BatteryClassQueryWmiDataBlock`), `IoWMIRegistrationControl(WMIREG_ACTION_REGISTER)`.
   * `WdfDeviceCreateSymbolicLink` `\DosDevices\Global\QCBatteryMiniclass`, then enables the interface `{6C7FF145-…}`.
4. Removal of `{F4116444-…}` (`GUID_DEVICE_INTERFACE_REMOVAL`), or `EvtDeviceD0Exit` to `WdfPowerDeviceD3Final`: releases the device object, `IoWMIRegistrationControl(WMIREG_ACTION_DEREGISTER)`, `BatteryClassUnload`, disables `{6C7FF145-…}`. D0Exit, surprise removal and query-remove also send `IOCTL_BATT_MNGR_NOTIFY_MINICLASS_REMOVAL` (once, flag in the driver context `+0x18`) and purge the queue.

### Battery miniclass callbacks

`BATTERY_MINIPORT_INFO` given to `BatteryClassInitializeDevice` (MajorVersion 1, MinorVersion 0, Context = device context, `DeviceName` NULL):  
| Callback | Function | IOCTL sent to the battery manager |
|----------|----------|-----------------------------------|
| QueryTag | sub_401008 | [IOCTL_BATT_MNGR_GET_BATTERY_ID](#ioctl-0x800b0fa4--ioctl_batt_mngr_get_battery_id) |
| QueryInformation | sub_401138 | [IOCTL_BATT_MNGR_GET_BATTERY_INFO](#ioctl-0x800b0fac--ioctl_batt_mngr_get_battery_info) |
| SetInformation | sub_401344 | [IOCTL_BATT_MNGR_CONTROL_CHARGING](#ioctl-0x800b0fb0--ioctl_batt_mngr_control_charging), [IOCTL_BATT_MNGR_SET_OPERATIONAL_MODE](#ioctl-0x800b0fbc--ioctl_batt_mngr_set_operational_mode) |
| QueryStatus | sub_401090 | [IOCTL_BATT_MNGR_GET_CHARGER_STATUS](#ioctl-0x800b0fa8--ioctl_batt_mngr_get_charger_status) |
| SetStatusNotify | sub_401450 | [IOCTL_BATT_MNGR_SET_STATUS_NOTIFICATION_CRITERIA](#ioctl-0x800b0fb4--ioctl_batt_mngr_set_status_notification_criteria) |
| DisableStatusNotify | sub_4014E4 | [IOCTL_BATT_MNGR_DISABLE_STATUS_NOTIFICATION](#ioctl-0x800b0fb8--ioctl_batt_mngr_disable_status_notification) |

The battery manager is expected to send [IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS](#ioctl-0x800c0fa4--ioctl_pmic_batt_mini_notify_status) back when the status changes; this driver then calls `BatteryClassStatusNotify`.

### IRP handling

* `IRP_MJ_DEVICE_CONTROL` (sub_4121B4): passed first to `BatteryClassIoctl` under the wait lock (the `IOCTL_BATTERY_*` codes, see [battc.sys](./battc.md#ioctl-0x294040--ioctl_battery_query_tag)). When battc returns `STATUS_NOT_SUPPORTED` (0xC00000BB), or before the battery class is initialised, the IRP goes to the WDF default queue and `EvtIoDeviceControl`.
* `EvtIoDeviceControl` (0x401E5C): only device type `0x800C` is accepted, otherwise `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). `ValidatePmicBattMiniRequest` (sub_4020A4) accepts the functions 1000–1001 (other → `STATUS_UNSUCCESSFUL` 0xC0000001) and checks the buffer lengths by **exact match** against the descriptor table at `.data:0x00405168` (2 entries of `0x10C` bytes: `+0x00` IoControlCode, `+0x04` UTF-16 name, `+0x104` InputBuffer size, `+0x108` OutputBuffer size) with `ValidateParameters` (sub_40233C). It returns the same `STATUS_INVALID_PARAMETER_1`…`5` codes as [qcbms8930.sys](./qcbms8930.md). The request is completed with 0 bytes.
* `IRP_MJ_SYSTEM_CONTROL` (sub_41224C): `BatteryClassSystemControl` with the driver's `WMILIB_CONTEXT`; the IRP is completed or forwarded according to the returned disposition.

All the requests to the battery manager go through `PmicSendDriverRequest` (sub_402874) → `PmicSendDriverRequestWithTimeout` (sub_402908): `IoBuildDeviceIoControlRequest` (not internal), `IofCallDriver`, then `KeWaitForSingleObject` **without a timeout** despite the name. No device object → `STATUS_INVALID_PARAMETER` (0xC000000D); IRP allocation failure → `STATUS_UNSUCCESSFUL`.

> [!NOTE]
> The battery manager's IOCTL names and sizes come from the PMIC IOCTL name table embedded in the binary (`.data:0x00405380`, the same table as in [qcpmic8930.sys](./qcpmic8930.md) and [qcbms8930.sys](./qcbms8930.md)). The meaning of the buffers is deduced from how this driver fills and reads them.

---

### IOCTL 0x800C0FA0 — IOCTL_PMIC_BATT_MINI_TEST

This IOCTL is processed by Qcbattminiclass8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800C |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PMIC_BATT_MINI_TEST | 0 | 0 |

Only validated, then completed with `STATUS_SUCCESS`. Does nothing.

---

### IOCTL 0x800C0FA4 — IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS

This IOCTL is processed by Qcbattminiclass8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800C |
| Function | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS | 0 | 0 |

After validation, calls `BatteryClassStatusNotify` with the battery class handle: [battc.sys](./battc.md#status-polling) queries the tag and the status again. The descriptor table entry of this IOCTL wrongly carries the code `0x800C0FA0` (copy of the previous entry); it has no effect because the table is indexed by the function number.

---

### IOCTL 0x800B0FA4 — IOCTL_BATT_MNGR_GET_BATTERY_ID

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager (`{F4116444-…}`)

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_GET_BATTERY_ID | `{F4116444-…}` device | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag, returned as is to battc |

Sent by `QueryTag`. Returned length ≠ 4 → `STATUS_INVALID_PARAMETER` (0xC000000D). Tag 0 → `STATUS_NO_SUCH_DEVICE` (0xC000000E), i.e. "no battery" for battc.

---

### IOCTL 0x800B0FA8 — IOCTL_BATT_MNGR_GET_CHARGER_STATUS

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EA (1002) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_GET_CHARGER_STATUS | `{F4116444-…}` device | 4 | 16 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag |

Outputbuffer (copied field by field into the `BATTERY_STATUS` given by battc):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | PowerState (`BATTERY_POWER_ON_LINE` 1, `DISCHARGING` 2, `CHARGING` 4, `CRITICAL` 8) |
| 04-07 | ? | Capacity |
| 08-0B | ? | Voltage |
| 0C-0F | ? | Rate |

Sent by `QueryStatus`. Returned length ≠ 16 → `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x800B0FAC — IOCTL_BATT_MNGR_GET_BATTERY_INFO

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EB (1003) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_GET_BATTERY_INFO | `{F4116444-…}` device | 12 | 512 |

Inputbuffer (the `QueryInformation` arguments):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag |
| 04-07 | ? | InformationLevel (`BatteryInformation` 0 … `BatterySerialNumber` 8) |
| 08-0B | ? | AtRate |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 000-1FF | ? | Level-dependent data: the raw structure, or a NUL-terminated UTF-16 string for the string levels |

Sent by `QueryInformation` (sub_401138) into a 512-byte stack buffer. Returned length ≠ 512 → `STATUS_INVALID_PARAMETER`. Then:
* levels 4 (`BatteryDeviceName`), 6 (`BatteryManufactureName`), 7 (`BatteryUniqueID`), 8 (`BatterySerialNumber`): `ReturnedLength` = (string length + 1) × 2 and the string is copied with `wcscpy_s(Buffer, length + 1, …)`;
* any other level (including 5 `BatteryManufactureDate`): `ReturnedLength` = the caller's buffer length, and that many bytes are copied from the 512-byte buffer.

Note: neither path checks the caller's buffer length against the data. A string longer than the caller's buffer overflows it, and a caller buffer larger than 512 bytes reads past the stack buffer.

---

### IOCTL 0x800B0FB0 — IOCTL_BATT_MNGR_CONTROL_CHARGING

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EC (1004) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_CONTROL_CHARGING | `{F4116444-…}` device | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag |
| 04-07 | `00 00 00 00` or `03 00 00 00` | `SetInformation` level: 0 = `BatteryCriticalBias`, 3 = `BatteryChargingSource` |
| 08-0B | ? | Level 0: the critical bias value; level 3: 0 |
| 0C-0F | ? | Level 0: 0; level 3: `MaxCurrent` of the `BATTERY_CHARGING_SOURCE` |

Sent by `SetInformation` (sub_401344):
* `BatteryCriticalBias` (0): always sent. NULL data → `STATUS_INVALID_PARAMETER`.
* `BatteryChargingSource` (3): first the operational mode is updated (see the next section). Not sent when the source type is 3 (wireless) or when `MaxCurrent` = 0xFFFFFFFE. The source type itself isn't forwarded.
* `BatteryCharge` (1), `BatteryDischarge` (2) and the other levels: nothing is sent, `STATUS_SUCCESS`.

---

### IOCTL 0x800B0FB4 — IOCTL_BATT_MNGR_SET_STATUS_NOTIFICATION_CRITERIA

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3ED (1005) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_SET_STATUS_NOTIFICATION_CRITERIA | `{F4116444-…}` device | 16 | 0 |

Inputbuffer (tag + the `BATTERY_NOTIFY` given by battc):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag |
| 04-07 | ? | PowerState |
| 08-0B | ? | LowCapacity |
| 0C-0F | ? | HighCapacity |

Sent by `SetStatusNotify`. A non-zero returned length → `STATUS_INVALID_PARAMETER`. When a criterion is met, the battery manager is expected to send [IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS](#ioctl-0x800c0fa4--ioctl_pmic_batt_mini_notify_status).

---

### IOCTL 0x800B0FB8 — IOCTL_BATT_MNGR_DISABLE_STATUS_NOTIFICATION

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EE (1006) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_DISABLE_STATUS_NOTIFICATION | `{F4116444-…}` device | 0 | 0 |

Sent by `DisableStatusNotify`. A non-zero returned length → `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x800B0FBC — IOCTL_BATT_MNGR_SET_OPERATIONAL_MODE

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EF (1007) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_SET_OPERATIONAL_MODE | `{F4116444-…}` device | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `00 00 00 00` / `01 00 00 00` | New operational mode (global `dword_405140`, initial value 1) |

Sent by `SetInformation(BatteryChargingSource)`, only when the mode changes:
* `MaxCurrent` = 0xFFFFFFFE and mode = 1 → mode 0 is sent, and the call returns (no `CONTROL_CHARGING`);
* any other `MaxCurrent` and mode = 0 → mode 1 is sent, then `CONTROL_CHARGING` as above.

Meaning of the modes (and of `MaxCurrent` = 0xFFFFFFFE) ?

---

### IOCTL 0x800B0FC4 — IOCTL_BATT_MNGR_SET_CHARGE_RATE

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3F1 (1009) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_SET_CHARGE_RATE | `{F4116444-…}` device | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Percentage given to `PassiveCooling` (0–100) |

Sent by the `PassiveCooling` routine (sub_401550) of the [thermal cooling interface](#thermal-cooling-interface), without any check or conversion.

---

### IOCTL 0x800B0FC8 — IOCTL_BATT_MNGR_NOTIFY_MINICLASS_REMOVAL

This IOCTL is sent by Qcbattminiclass8930.sys to the battery manager

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3F2 (1010) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATT_MNGR_NOTIFY_MINICLASS_REMOVAL | `{F4116444-…}` device | 0 | 0 |

Sent once (sub_401690) by `EvtDeviceD0Exit` (D3Final), `EvtDeviceSurpriseRemoval` and `EvtDeviceQueryRemove`.

`IOCTL_BATT_MNGR_GET_CURRENT_STATE` (0x800B0FC0, input 0, output 4) is in the name table but is never sent.

---

### Thermal cooling interface

Added with `WdfDeviceAddQueryInterface` (`GUID_THERMAL_COOLING_INTERFACE`, `ImportInterface` false), like [NokiaEnergyDriver.sys](./nokiaenergydriver.md) and [monitor.sys](./monitor.md):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 1C 00 | Size |
| 02-03 | 01 00 | Version |
| 04-07 | WDFDEVICE | Context |
| 08-0B | nullsub_1 | InterfaceReference (no-op) |
| 0C-0F | nullsub_1 | InterfaceDereference (no-op) |
| 10-13 | 00 00 00 00 | Flags |
| 14-17 | NULL | ActiveCooling |
| 18-1B | sub_401550 | PassiveCooling → [IOCTL_BATT_MNGR_SET_CHARGE_RATE](#ioctl-0x800b0fc4--ioctl_batt_mngr_set_charge_rate) |

---

### Interface GUID

Battery manager interface (consumed; the provider is unknown)  
`{F4116444-4837-49A5-B2C7-433FE501F2AA}`

qcbattminiclass8930 device interface (enabled while the battery manager is present)  
`{6C7FF145-BE42-4ED4-ADF1-2ECD06EF23B7}`

Thermal cooling interface exposed (`GUID_THERMAL_COOLING_INTERFACE`)  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`

Battery device interface registered by [battc.sys](./battc.md) on this driver's PDO  
`{72631E54-78A4-11D0-BCF7-00AA00B7B32A}` (GUID_DEVICE_BATTERY)

### Other GUID

`GUID_DEVICE_INTERFACE_ARRIVAL`  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`

`GUID_DEVICE_INTERFACE_REMOVAL`  
`{CB3A4005-46F0-11D0-B08F-00609713053F}`
