## Battc.sys

Microsoft **Battery Class driver** (`battc.pdb`, 56 functions, PDB symbols available).  
It isn't a device driver but a kernel-mode **export library** (`DriverEntry` at 0x19000 only returns 0; the real initialisation is in `DllInitialize`). A battery **miniclass driver** links to it and calls its exports. On the Lumia 520 the only miniclass driver is [NokiaEnergyDriver.sys](./nokiaenergydriver.md).  
BATTC owns the generic part of the battery stack. It registers the `GUID_DEVICE_BATTERY` interface for the miniclass device and queues the `IOCTL_BATTERY_*` requests. A worker thread turns them into calls to the miniclass callbacks (`QueryTag`, `QueryInformation`, `QueryStatus`, `SetInformation`, `SetStatusNotify`, `DisableStatusNotify`). It completes the long-running "wait for status/tag" requests when their condition is met or when they time out. If the miniclass driver can't notify, BATTC also polls it.  
It adds the Microsoft battery WMI data blocks (`MSBatteryClass`) and a **power meter** interface (`GUID_DEVICE_POWER_METER`, PMI IOCTLs) built from the cached battery status. It forwards the charger type and current from a "charging power source" interface to the miniclass driver as `BatteryChargingSource`.

There's no named device and no `\DosDevices` link. For each miniclass device, BATTC registers two device interfaces on the miniclass PDO (`IoRegisterDeviceInterface`):  
Battery interface : `GUID_DEVICE_BATTERY` `{72631E54-78A4-11D0-BCF7-00AA00B7B32A}`  
Power meter interface : `GUID_DEVICE_POWER_METER` `{E849804E-C719-43D8-AC88-96B894C191E2}`

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\BattC`

There are no parameters in the service key. `DllInitialize` (0x1900C) reads two REG_DWORD values in **seconds** from `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power` (`BattCGetRegistryDwordValue`, `RtlQueryRegistryValuesEx` with `RTL_QUERY_REGISTRY_DIRECT`). A missing value or 0 keeps the default:  
| Registry value | value | comment |
|----------------|-------|---------|
| BatteryMinPollRate | 180 | Longest interval (s) between two status polls when the miniclass can't notify (see [Status polling](#status-polling)). Stored ×10,000,000 (100 ns units) in `BatteryMinPollRate` (`.data:0x140C0`) |
| BatteryMinBackupPollRate | 3600 or 180 | Longest interval (s) between two status queries while a status request is waiting, even when the miniclass notifies. Default 3600 s when `ZwPowerInformation(PlatformInformation)` reports `AoAc` = 1 (connected standby, the case on Windows Phone ?), else 180 s. Stored in `BatteryMinBackupPollRate` (`.data:0x140D0`) |

GUID of the ETW provider (Microsoft-Windows-Battery ?):  
`{59819D0A-ADAF-46B2-8D7C-990BC39C7C15}`  
The only event is `BATTERY_EVT_BATTERY_BAY_RUNDOWN` (Id 3, version 0, channel 0x10, level 4, task 3, keyword 0x8000000000000000). It's written by `BattCTraceBatteryBay` for each battery when a session sends `EVENT_CONTROL_CODE_CAPTURE_STATE` (`BattCTraceControlCallback`, 0x177F8). Payload: the battery handle (4 bytes) and a BOOL "a tag is cached" (4 bytes).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Miniclass device | [nokiaenergydriver.sys](./nokiaenergydriver.md) | Direct calls to the `BATTERY_MINIPORT_INFO` callbacks, no IRP |
| Battery class upper filter | [battfltr.sys](./battfltr.md) | Not called by BATTC. The `IOCTL_BATTERY_*` requests go through it before reaching the miniclass driver and `BatteryClassIoctl`; it can change `BATTERY_WAIT_STATUS` and the returned status/information |
| Device with interface `GUID_INTERFACE_CHARGING_POWERSOURCE` `{DE246FC9-6529-4927-BED2-907856A9C14F}` | ? (USB charger detection ?) | `IoRegisterPlugPlayNotification`, `IoGetDeviceObjectPointer`, then `IRP_MN_QUERY_INTERFACE` (see [Charging power source](#charging-power-source)) |
| Kernel power manager | ntoskrnl | `ZwPowerInformation(PlatformInformation)` |
| WMI | [wmilib.sys](./wmilib.md) | `WmiSystemControl`, `WmiCompleteRequest` |

### Exports

| Export | Address | Comment |
|--------|---------|---------|
| BatteryClassInitializeDevice | 0x16030 | Named `FxDriverEntry` in the IDB, but it is `BatteryClassInitializeDevice(PBATTERY_MINIPORT_INFO, PVOID *ClassData)` (see below) |
| BatteryClassUnload | 0x162E0 | Removes the battery: interfaces off, timers cancelled, waits for the pending work, releases the charging interface, frees everything |
| BatteryClassIoctl | 0x16480 | Called by the miniclass driver for each `IRP_MJ_DEVICE_CONTROL` (see [IOCTLs](#ioctl-0x294040--ioctl_battery_query_tag)). Returns `STATUS_NOT_SUPPORTED` (0xC00000BB) **without completing the IRP** for any other code, so the miniclass driver can handle it itself |
| BatteryClassStatusNotify | 0x119BC | Called by the miniclass driver when the status changed. Sets the "status changed" (+C0) and "tag changed" (+C4) flags and queues the worker: status and tag are queried again, ignoring the 2 s cache |
| BatteryClassSystemControl | 0x16610 | `IRP_MJ_SYSTEM_CONTROL` handler, adds the BATTC WMI GUIDs (see [WMI](#wmi)) |
| BatteryClassQueryWmiDataBlock | 0x167C4 | WMI query of one of the BATTC data blocks; the request is queued for the worker (`STATUS_PENDING`) |
| DllInitialize | 0x1900C | ETW registration, battery list, poll rates from the registry |
| DllUnload | 0x16000 | ETW unregistration |

### BatteryClassInitializeDevice

`BATTERY_MINIPORT_INFO` given by the miniclass driver (the first 40 bytes are copied into the class data at +70):  
| Bytes | Comment |
|-------|---------|
| 00 | MajorVersion: must be 1, otherwise `STATUS_REVISION_MISMATCH` (0xC0000059) |
| 01 | MinorVersion: when ≠ 0, the work item is allocated on the device object at +28 (FDO ?) instead of the PDO |
| 04-07 | Context, first argument of every callback |
| 08-0B | QueryTag |
| 0C-0F | QueryInformation |
| 10-13 | SetInformation (may be NULL: `IOCTL_BATTERY_SET_INFORMATION` then fails with `STATUS_NOT_SUPPORTED`) |
| 14-17 | QueryStatus |
| 18-1B | SetStatusNotify |
| 1C-1F | DisableStatusNotify |
| 20-23 | Pdo: owner of the two device interfaces |
| 28-2B | Device object for the work item (MinorVersion ≠ 0 only) |

Steps:
1. Allocates the class handle (256 bytes, non-paged) and the class data (208 bytes), pool tag `Batt` (0x74746142).
2. Initialises 2 timers + DPCs (status poll `BattCWorkerDpc` at handle +10, tag timeout `BattCTagDpc` at handle +60), the work item (`BattCWorkerThread`) and 4 IRP queues in the class data: +28 new requests, +30 status waits, +38 tag waits, +40 WMI requests.
3. Registers and enables `GUID_DEVICE_BATTERY` on the PDO.
4. Registers for `GUID_INTERFACE_CHARGING_POWERSOURCE` arrivals (`IoRegisterPlugPlayNotification`, `EventCategoryDeviceInterfaceChange`, `PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`).
5. Registers and enables `GUID_DEVICE_POWER_METER` on the PDO.
6. Adds the battery to the global list (used by the ETW rundown) and returns the class handle in `*ClassData`.

### Worker thread

`BattCQueueWorker` (0x11B7C) queues the work item (`DelayedWorkQueue`) only on the 0 → 1 transition of a counter. `BattCWorkerThread` (0x16D04) runs until that counter goes back to 0. It runs **pinned to processor 0** (`KeSetSystemGroupAffinityThread`, group 0, mask 1).  
1. Moves each request of the "new" queue: `IOCTL_BATTERY_QUERY_STATUS` (input 20, output 16) → status queue, `IOCTL_BATTERY_QUERY_TAG` (input 0 or 4, output 4) → tag queue. A cancel routine is set on both (`BattCCancelStatus`, `BattCCancelTag`). `QUERY_INFORMATION` and `SET_INFORMATION` are executed at once and completed (see the IOCTLs below).
2. `BattCCheckStatusQueue` if the status flag (+B8) is set, `BattCCheckTagQueue` if the tag flag (+BC) is set.
3. Executes the queued WMI requests (`BattCWmi`).

When the battery is being removed (handle +E8 = 1), every queued IRP is completed with `STATUS_DEVICE_REMOVED` (0xC00002B6).  
If a miniclass callback returns `STATUS_NO_SUCH_DEVICE` (0xC000000E), `BattCMiniportStatus` completes all the status waits with that status.

Cached values in the class data:  
| Offset | Comment |
|--------|---------|
| +24 | Battery tag (last `QueryTag` result) |
| +48-4F | Time of the last `QueryTag` (100 ns, from `KeTickCount`) |
| +50-57 | Time of the last `QueryStatus` |
| +58-67 | Last `BATTERY_STATUS` (PowerState, Capacity, Voltage, Rate) |
| +68 | Number of successive polls with an unknown capacity |
| +70-97 | Copy of `BATTERY_MINIPORT_INFO` (callbacks at +78…+8C, Context at +74) |
| +98-9F | `GUID_DEVICE_BATTERY` symbolic link (`UNICODE_STRING`) |
| +A0-A7 | `GUID_DEVICE_POWER_METER` symbolic link (`UNICODE_STRING`) |
| +A8-BF | Charging power source interface (24 bytes) |
| +C0-C7 | Symbolic link of the charging power source device |
| +C8 / +CC | PnP notification handles (interface arrival / target device) |

### Status polling

`BattCCheckStatusQueue` (0x170C0):
1. Calls `QueryStatus` again when the last status is **older than 2 s** (20,000,000 × 100 ns) or after `BatteryClassStatusNotify`. If it fails, all the status waits are completed with its error.
2. For each wait (`BATTERY_WAIT_STATUS`): tag ≠ current tag → `STATUS_NO_SUCH_DEVICE`; cancelled → `STATUS_CANCELLED` (0xC0000120). The wait is completed with the current `BATTERY_STATUS` (16 bytes, `STATUS_SUCCESS`) when PowerState ≠ the requested PowerState, Capacity < LowCapacity, Capacity > HighCapacity, or the timeout (ms) has expired. Timeout 0 completes at once, 0xFFFFFFFF never expires.
3. If waits remain, calls `SetStatusNotify(Context, Tag, {PowerState, max LowCapacity, min HighCapacity})`. When there are no waits any more, calls `DisableStatusNotify` once.
4. Restarts the poll timer (`KeSetCoalescableTimer`, tolerance 1000 ms) with the smallest of `BatteryMinBackupPollRate`, the remaining timeouts and, **only if `SetStatusNotify` failed**:
   * capacity unknown (0xFFFFFFFF): 1 s, up to 10 times, then `BatteryMinPollRate`;
   * rate 0 or `BATTERY_UNKNOWN_RATE` (0x80000000): `BatteryMinPollRate`;
   * otherwise 75 % of the time to reach the limit (`(High − Capacity)` when charging, `(Low − Capacity)` when discharging, × 0.75 h / Rate), clamped between **20 s** and `BatteryMinPollRate`.

`BattCCheckTagQueue` (0x1750C) works the same way for the tag waits: `QueryTag` again when the tag is older than 2 s or after `BatteryClassStatusNotify`. `STATUS_NO_SUCH_DEVICE` from the miniclass means "no battery" (tag 0) and isn't an error. A wait is completed with the tag (4 bytes) as soon as the tag is non-zero, or with `STATUS_NO_SUCH_DEVICE` when its timeout expires. The timeout timer is at handle +60 (`KeSetTimer`, `BattCTagDpc`).

### Charging power source

Only the first device that exposes `GUID_INTERFACE_CHARGING_POWERSOURCE` `{DE246FC9-6529-4927-BED2-907856A9C14F}` is used (`ChargingPowerSourcePnpNotifyInterfaceChange`, 0x16AC0):
1. Arrival: copies the symbolic link, `IoGetDeviceObjectPointer` (access 0x1F0000), registers a target-device notification (`ChargingPowerSourcePnpNotifyTargetDeviceChange`) and calls `RegisterChargerChangeCallback`.
2. `RegisterChargerChangeCallback` (0x16940) sends `IRP_MJ_PNP` / `IRP_MN_QUERY_INTERFACE` (synchronous, `IoSynchronousCallDriver`) with this 24-byte interface (Size 24, Version 1):

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 18 00 | Size (filled by the provider) |
| 02-03 | 01 00 | Version |
| 04-07 | | Context (filled by the provider) |
| 08-0B | | InterfaceReference (filled by the provider) |
| 0C-0F | | InterfaceDereference (filled by the provider; called on release) |
| 10-13 | `ChargeNotificationCallback` | Callback given **by BATTC** to the provider |
| 14-17 | class handle | Context of the callback |

3. `ChargeNotificationCallback(Context, Type, MaxCurrent)` (0x168A8): calls the miniclass `QueryTag` then `SetInformation(Tag, BatteryChargingSource (3), {Type, MaxCurrent})`. On the Lumia 520, NokiaEnergyDriver uses type 2 (`BatteryChargingSourceType_USB`) as the USB input current limit.
4. Query-remove: the interface is dereferenced; remove-cancelled: it is queried again. Interface removal or remove-complete (`ChargingDeviceRemoved`, 0x16A2C): the interface is released and `SetInformation(BatteryChargingSource)` is sent 3 times with `{Type 1, 0}`, `{Type 2, 0}`, `{Type 3, 0}` (AC, USB, wireless: no current).

### WMI

On the first `BatteryClassSystemControl` call, BATTC copies the miniclass [`WMILIB_CONTEXT`](./wmilib.md#wmilib_context) and appends 8 GUIDs (`BattWmiGuidList`, 1 instance each, flag 0x20). For `IRP_MN_REGINFO`/`IRP_MN_REGINFO_EX` it adds the MOF resource `BATTCWMI` from `\REGISTRY\MACHINE\SYSTEM\CurrentControlSet\Services\BattC`.  
| Index | GUID | Name | Size | Content (`BattCWmi`, 0x11C64) |
|-------|------|------|------|-------------------------------|
| 0 | `{FC4670D1-EBBF-416E-87CE-374A4EBC111A}` | BATTERY_STATUS_WMI_GUID | 24 | Tag, RemainingCapacity, ChargeRate (Rate if ≥ 0, else 0), DischargeRate (−Rate if < 0, else 0), Voltage, then 4 bytes PowerOnline, Charging, Discharging, Critical. From the **cached** status (no new query) |
| 1 | `{535A3767-1AC2-49BC-A077-3F7A02E40AEC}` | BATTERY_RUNTIME_WMI_GUID | 8 | Tag, `BatteryEstimatedTime` |
| 2 | `{1A52A14D-ADCE-4A44-9A3E-C8D8F15FF2C2}` | BATTERY_TEMPERATURE_WMI_GUID | 8 | Tag, `BatteryTemperature` (tenths of K) |
| 3 | `{40B40565-96F7-4435-8694-97E0E4395905}` | BATTERY_FULL_CHARGED_CAPACITY_WMI_GUID | 8 | Tag, `BATTERY_INFORMATION.FullChargedCapacity` |
| 4 | `{EF98DB24-0014-4C25-A50B-C724AE5CD371}` | BATTERY_CYCLE_COUNT_WMI_GUID | 8 | Tag, `BATTERY_INFORMATION.CycleCount` |
| 5 | `{05E1E463-E4E2-4EA9-80CB-9BD4B3CA0655}` | BATTERY_STATIC_DATA_WMI_GUID | 1144 | See below |
| 6 | `{CDDFA0C3-7C5B-4E43-A034-059FA5B84364}` | BATTERY_STATUS_CHANGE_WMI_GUID | — | Event, but **never fired** (no `WmiFireEvent`); a query → `STATUS_WMI_GUID_NOT_FOUND` (0xC0000295) |
| 7 | `{5E1F6E19-8786-4D23-94FC-9E746BD5D888}` | BATTERY_TAG_CHANGE_WMI_GUID | — | Same as 6 |

Static data block (index 5):  
| Bytes | Comment |
|-------|---------|
| 00-03 | Tag |
| 04-35 | ManufactureDate, 25 UTF-16 characters (CIM datetime). `BatteryManufactureDate` (level 5) is printed with the format `"%d4%d2%d2******.**********"`: this is a **bug** (`%04d%02d%02d` was meant), so the result is year + `4` + month + `2` + day + `2`. All `*` when the level fails (NokiaEnergyDriver doesn't support it) |
| 38-57 | `BatteryGranularityInformation` (4 × `BATTERY_REPORTING_SCALE`) |
| 58-73 | `BATTERY_INFORMATION`: Capabilities, Technology (1 byte), Chemistry, DesignedCapacity, DefaultAlert1, DefaultAlert2, CriticalBias |
| 74- | 4 counted strings (USHORT length + at most 128 bytes, length 0 on error): DeviceName (level 4), ManufactureName (level 6), SerialNumber (level 8), UniqueID (level 7) |

Only a `BatteryInformation` failure fails the request; the other levels are optional.

---

### IOCTL 0x294040 — IOCTL_BATTERY_QUERY_TAG

This IOCTL is processed by Battc.sys (through `BatteryClassIoctl`)

| Property | Value |
|----------|-------|
| Device | 0x29 (FILE_DEVICE_BATTERY) |
| Function | 0x10 (16) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATTERY_QUERY_TAG | 0 or 4 | 4 |

Inputbuffer (optional):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Timeout in ms. 0 (or no input) = return at once, 0xFFFFFFFF = wait forever |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `EF BE 00 00` | Battery tag (0xBEEF with NokiaEnergyDriver) |

Queued, `STATUS_PENDING`. Completed by `BattCCheckTagQueue` with the tag as soon as it is non-zero, or `STATUS_NO_SUCH_DEVICE` (0xC000000E) at timeout. Wrong sizes → `STATUS_INVALID_BUFFER_SIZE` (0xC0000206).

---

### IOCTL 0x294044 — IOCTL_BATTERY_QUERY_INFORMATION

This IOCTL is processed by Battc.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x11 (17) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATTERY_QUERY_INFORMATION | 12 | depends on the level |

Inputbuffer (`BATTERY_QUERY_INFORMATION`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | BatteryTag |
| 04-07 | | InformationLevel: 0 BatteryInformation, 1 BatteryGranularityInformation, 2 BatteryTemperature, 3 BatteryEstimatedTime, 4 BatteryDeviceName, 5 BatteryManufactureDate, 6 BatteryManufactureName, 7 BatteryUniqueID, 8 BatterySerialNumber |
| 08-0B | | AtRate (for BatteryEstimatedTime) |

Outputbuffer: what the miniclass returns (see [NokiaEnergyDriver QueryInformation](./nokiaenergydriver.md#battery-class)).

Executed by the worker: `QueryInformation(Context, Tag, Level, AtRate, OutputBuffer, OutputLength, &ReturnedLength)`. The status and the returned length come from the miniclass. Input ≠ 12 → `STATUS_INVALID_BUFFER_SIZE` (0xC0000206).

---

### IOCTL 0x298048 — IOCTL_BATTERY_SET_INFORMATION

This IOCTL is processed by Battc.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x12 (18) |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATTERY_SET_INFORMATION | ≥ 12 | 0 |

Inputbuffer (`BATTERY_SET_INFORMATION`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | BatteryTag |
| 04-07 | | InformationLevel: 0 BatteryCriticalBias, 1 BatteryCharge, 2 BatteryDischarge, 3 BatteryChargingSource… |
| 08- | | Level-specific data, e.g. `BATTERY_CHARGING_SOURCE` {Type, MaxCurrent} |

Executed by the worker: `SetInformation(Context, Tag, Level, &Input[8])`. No `SetInformation` callback → `STATUS_NOT_SUPPORTED` (0xC00000BB). Input < 12 or output ≠ 0 → `STATUS_INVALID_BUFFER_SIZE`.

---

### IOCTL 0x29404C — IOCTL_BATTERY_QUERY_STATUS

This IOCTL is processed by Battc.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x13 (19) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATTERY_QUERY_STATUS | 20 | 16 |

Inputbuffer (`BATTERY_WAIT_STATUS`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | BatteryTag |
| 04-07 | | Timeout in ms (0 = return at once, 0xFFFFFFFF = never) |
| 08-0B | | PowerState to compare with |
| 0C-0F | | LowCapacity |
| 10-13 | | HighCapacity |

Outputbuffer (`BATTERY_STATUS`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `05 00 00 00` | PowerState: 1 `BATTERY_POWER_ON_LINE`, 2 `DISCHARGING`, 4 `CHARGING`, 8 `CRITICAL` |
| 04-07 | | Capacity (mWh) |
| 08-0B | | Voltage (mV) |
| 0C-0F | | Rate (mW, negative = discharging) |

Queued, `STATUS_PENDING`, completed by `BattCCheckStatusQueue` (see [Status polling](#status-polling)). Wrong sizes → `STATUS_INVALID_BUFFER_SIZE`.

---

### IOCTL 0x454000 / 0x454004 / 0x458008 / 0x45C010 — PMI IOCTLs not implemented

This IOCTL is processed by Battc.sys

| Property | Value |
|----------|-------|
| Device | 0x45 |
| Function | 0x0 / 0x1 / 0x2 / 0x4 |
| Access | FILE_READ_ACCESS / FILE_READ_ACCESS / FILE_WRITE_ACCESS / READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PMI_GET_CAPABILITIES (0x454000) ? | — | — |
| IOCTL_PMI_GET_CONFIGURATION (0x454004) ? | — | — |
| IOCTL_PMI_SET_CONFIGURATION (0x458008) ? | — | — |
| IOCTL_PMI_REGISTER_EVENT_NOTIFY (0x45C010) ? | — | — |

Completed at once with `STATUS_NOT_IMPLEMENTED` (0xC0000002). The names are the Windows power meter interface codes for these function numbers.

---

### IOCTL 0x45400C — IOCTL_PMI_GET_MEASUREMENT ?

This IOCTL is processed by Battc.sys

| Property | Value |
|----------|-------|
| Device | 0x45 |
| Function | 0x3 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PMI_GET_MEASUREMENT ? | ignored | ≥ 8 |

Outputbuffer (`PMI_MEASUREMENT_DATA` ?):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version |
| 04-07 | | Power in mW: −Rate from the cached status when `BATTERY_DISCHARGING` is set, else 0 |

Answered directly in `BatteryClassIoctl`, without asking the miniclass. The returned length is the **whole output buffer length**, not 8. Output < 8 → `STATUS_BUFFER_TOO_SMALL` (0xC0000023).

---

### Interface GUID

Battery device interface (registered by battc.sys on the miniclass PDO)  
`{72631E54-78A4-11D0-BCF7-00AA00B7B32A}` (GUID_DEVICE_BATTERY)

Power meter device interface (registered by battc.sys on the miniclass PDO)  
`{E849804E-C719-43D8-AC88-96B894C191E2}` (GUID_DEVICE_POWER_METER)

### Other GUID

Charging power source interface (consumed by battc.sys)  
`{DE246FC9-6529-4927-BED2-907856A9C14F}` (GUID_INTERFACE_CHARGING_POWERSOURCE)
