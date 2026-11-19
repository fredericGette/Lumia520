## Cad.sys

Charging Arbitration Driver (Microsoft, WP8.1, KMDF).  
It collects the charging sources reported by other drivers (USB from [usbfnclx.sys](./usbfnclx.md), wireless) and forwards them to **every battery device** (`GUID_DEVICE_BATTERY`) as `IOCTL_BATTERY_SET_INFORMATION` / `BatteryChargingSource` (or `BatteryChargerId`). On the Lumia 520 the battery device is [NokiaEnergyDriver.sys](./nokiaenergydriver.md) under [battc.sys](./battc.md).  
It can also block charging (per-handle request from user mode), disable USB charging with a DPP file, and fakes a USB source of 900 mA (or 500 mA) while a kernel debugger is attached over USB/NET, so the phone keeps charging while the USB function stack isn't running.  
PDB: `cad.pdb`. Pool tag `CAD.`. No hardware access.

There's no named `\Device\` object. The driver creates its own root-enumerated device (`IoReportRootDevice` in `DriverEntry`, no INF/ACPI node) and registers the device interface `GUID_DEVINTERFACE_CHARGING_ARBITRATION` [`{EC0A1CC9-4294-43FB-BF37-B850CE95F337}`](#interface-guid) with the reference string `Charging Arbitration Driver Status`.

Both the IOCTLs and the internal IOCTLs go through one sequential default queue (`EvtIoDeviceControl` sub_10004504, `EvtIoInternalDeviceControl` sub_10004730). Unknown codes → `STATUS_NOT_SUPPORTED` (0xC00000BB).

There's no parameters in the registry.  
Only when a kernel debugger is enabled (`KdDebuggerEnabled`), sub_10002470 reads `\Registry\Machine\System\ControlSet001\Control` value `SystemStartOptions` (REG_SZ) to find the debug transport:  
| Substring | Debug port type (context `+0x68`) | KD charging |
|-----------|-----------------------------------|-------------|
| `DEBUGPORT=NET` | 0 | yes |
| `DEBUGPORT=USB` | 1 | yes |
| `DEBUGPORT=COM` | 2 | no |
| none / error | 3 | yes |

DPP files (only their existence is tested, `ZwOpenFile`), read once in `EvtDriverDeviceAdd`:  
| File | Effect |
|------|--------|
| `C:\Dpp\Microsoft\UsbNoCurrentDraw.txt` | "Disabling USB charging based on DPP file": USB sources are always forwarded with MaxCurrent 0 (and no charger id), the KD source is disabled, [IOCTL 0x29C4C4](#ioctl-0x29c4c4--get-usb-charging-disabled) returns 1 |
| `C:\Dpp\Microsoft\UsbKdMaxCurrent500mA.txt` | KD source = 500 mA instead of 900 mA ("Limiting KD power draw over USB to 500mA / 900mA") |

GUID of the ETW provider:  
`{F184D934-D688-4AE7-B078-24CB2C8063FF}`  
Debug messages also go to `vDbgPrintEx` (component id 101, mask 0x4000).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Every battery device, `GUID_DEVICE_BATTERY` `{72631E54-78A4-11D0-BCF7-00AA00B7B32A}` (`IoRegisterPlugPlayNotification`, opened by symbolic link with `WdfIoTargetOpen`, GENERIC_READ \| GENERIC_WRITE) | [battfltr.sys](./battfltr.md) (class upper filter, top of the stack) → [NokiaEnergyDriver.sys](./nokiaenergydriver.md) + [battc.sys](./battc.md) | `IOCTL_BATTERY_QUERY_TAG`, `QUERY_INFORMATION`, `QUERY_STATUS`, `SET_INFORMATION`, `CHARGING_SOURCE_CHANGE`, see [Battery devices](#battery-devices) |
| — | [usbfnclx.sys](./usbfnclx.md) | Opens this driver's interface and sends the USB source with [internal IOCTL 0x29C4C0](#internal-ioctl-0x29c4c0--charging-source-notification) (`NotifyCad`) |
| — | ? | Wireless charging source (type 3), same internal IOCTL. No sender known on the Lumia 520 |
| — | ? (user mode) | Clients of the [IOCTLs](#ioctl-0x29c480--block-charging) on the interface. None found yet |

### Charging sources

The device context (`CADCONTEXT`) keeps 3 source records of 32 bytes: USB at `+0x08`, wireless at `+0x28`, KD (debugger) at `+0x48`.  
| Bytes | Comment |
|-------|---------|
| 00-03 | Type: 2 USB, 3 wireless, 4 KD (internal) |
| 04-07 | MaxCurrent in mA. 0xFFFFFFFF at start (unknown) |
| 08 | Connected (byte). For the KD record: KD charging active (context `+0x50`) |
| 0C-0F | Copied from the notification (USB: port type), only used to detect changes and in traces |
| 10-1F | Charger id GUID (zero = none) |

Other fields of the context: `+0x00` number of handles that [block charging](#ioctl-0x29c480--block-charging), `+0x04` byte USB charging enabled (0 with `UsbNoCurrentDraw.txt`), `+0x68` debug port type, `+0x6C` PnP notification entry, `+0x70` collection of battery devices, `+0x78` event that stops the KD thread, `+0x88` KD thread handle.

When a source changes (sub_100053D0, called by internal IOCTL 0x29C4C0):
1. If the notification says connected with a current ≠ 0 or a charger id, the KD thread is stopped (event `+0x78`, for good).
2. Type 2 → USB record, 3 → wireless record, other → `STATUS_INVALID_PARAMETER` (0xC000000D). A connected USB source clears the KD flag.
3. If the record is unchanged (32-byte compare) nothing is sent. Otherwise MaxCurrent and charger id are copied when connected (and, for USB, USB charging enabled), else set to 0.
4. If charging is blocked (`+0x00` > 0) and MaxCurrent ≠ 0, nothing is sent.
5. If a debugger is enabled, the port isn't COM, and neither USB nor wireless is connected, the KD flag is set again.
6. The source is sent to every battery (sub_10005134 → sub_10005198).

What is sent to a battery (sub_10005198 / `NotifyBatteryDriverOfSource` sub_1000526C):
* USB record (as source type 2), when connected (or always after a source change);
* wireless record (as source type 3), same rule;
* KD record as source type **2** (USB) when the KD flag is set and neither USB nor wireless is connected;
* when charging is blocked, the same with a zeroed record (MaxCurrent 0).

For each record: if the battery supports charger ids and the record has one, `IOCTL_BATTERY_SET_INFORMATION` level 4 `BatteryChargerId` (asynchronous, sub_10004D5C); otherwise level 3 `BatteryChargingSource` (synchronous), 16-byte form `{Type, MaxCurrent}` if the battery supports charging sources, 12-byte form `{MaxCurrent}` otherwise. See [IOCTL 0x298048](#ioctl-0x298048--ioctl_battery_set_information).

### KD charging

Started in `EvtDriverDeviceAdd` when `KdDebuggerEnabled`, the debug port isn't COM and `UsbNoCurrentDraw.txt` is absent: KD record MaxCurrent = 900 (or 500), KD flag = 1, then a system thread (sub_10004010) loops every **30 s** (`KeWaitForSingleObject` on event `+0x78`, timeout −300000000): while no handle blocks charging and the KD flag is set, the KD source is sent to every battery. It ends when a real source arrives (step 1 above) or when the device is cleaned up (sub_1000441C, which also unregisters the PnP notification).

### Battery devices

On battery interface arrival (sub_10004880), a 36-byte record is created:  
| Bytes | Comment |
|-------|---------|
| 00-03 | WDFIOTARGET |
| 04-07 | WDFSTRING symbolic link (used to find the record on removal) |
| 08-0B | Battery tag |
| 0C | 1 = `BATTERY_SET_CHARGER_ID_SUPPORTED` (Capabilities bit 0x8) |
| 0D | 1 = `BATTERY_SET_CHARGINGSOURCE_SUPPORTED` (Capabilities bit 0x4) |
| 10-13 | WDFREQUEST of the charging-source-change request |
| 14-17 | WDFMEMORY over `18-1F` |
| 18-1F | Output of `IOCTL_BATTERY_CHARGING_SOURCE_CHANGE`: Type (4 bytes), On (byte) |
| 20-23 | FullChargedCapacity (only logged) |

Then: [QUERY_TAG](#ioctl-0x294040--ioctl_battery_query_tag), [QUERY_INFORMATION](#ioctl-0x294044--ioctl_battery_query_information), [QUERY_STATUS](#ioctl-0x29404c--ioctl_battery_query_status) (logged), the current sources are sent if charging isn't blocked, the record is added to the collection and [IOCTL_BATTERY_CHARGING_SOURCE_CHANGE](#ioctl-0x294050--ioctl_battery_charging_source_change) is sent.  
On removal, the record is found by symbolic link and deleted.

All these requests go first through [battfltr.sys](./battfltr.md#request-processing): `SET_INFORMATION`, `QUERY_TAG` and `CHARGING_SOURCE_CHANGE` are forwarded unchanged. When `BatteryFixedPercent.txt` exists, the `QUERY_INFORMATION` answer has Chemistry "Fltr" (Capabilities unchanged) and the logged `QUERY_STATUS` capacity is the fake one.  
NokiaEnergyDriver reports Capabilities `0x80000007`: no charger id support, charging source supported, so it receives `BatteryChargingSource` `{Type, MaxCurrent}`.

---

### IOCTL 0x29C480 — block charging

This IOCTL is processed by Cad.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x120 (288) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00/01 | 1 = block charging for this handle, 0 = release |

The flag is kept per file object (`CADFILEOBJECTCONTEXT`, 1 byte). When it changes, the block counter (context `+0x00`) is incremented / decremented. On 0 → 1, a zero source (MaxCurrent 0) is sent to every battery for USB, wireless and KD; on 1 → 0, the real sources are sent again. Closing the handle (`EvtFileClose` sub_1000449C) releases the block.  
Note: [battfltr.sys](./battfltr.md#ioctl-0x29c480--set-fake-battery-status) uses the same code for another purpose, on the battery stack (set fake battery status). There's no conflict: cad.sys never sends 0x29C480 to the batteries, and battfltr only sees requests sent to a battery device.

---

### IOCTL 0x29C488 — get sources

This IOCTL is processed by Cad.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x122 (290) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | ≥ 52 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | | USB record: Type, MaxCurrent, field `0C`, Connected (byte) |
| 10-1F | | KD record, same layout (Connected = KD flag) |
| 20-2F | | Wireless record, same layout |
| 30-33 | | Number of handles blocking charging |

Charger ids aren't returned. 52 bytes returned.

---

### IOCTL 0x29C48C — get/set full sources

This IOCTL is processed by Cad.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x123 (291) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | (100) | ≥ 100 |

Buffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-1F | | USB record (32 bytes, see [Charging sources](#charging-sources)) |
| 20-3F | | KD record |
| 40-5F | | Wireless record |
| 60-63 | | Output: number of handles blocking charging |

> [!NOTE]
> Probably meant as the "full" version of 0x29C488, but the copies go the wrong way: the handler `memmove`s **from** the output buffer **into** the three records of the context, then writes only the counter at `60-63`. With METHOD_BUFFERED the output buffer is the system buffer holding the caller's input, so this IOCTL **overwrites the driver's source records** with caller data (nothing is sent to the batteries until the next change). 100 bytes returned.

---

### IOCTL 0x29C4C4 — get USB charging disabled

This IOCTL is processed by Cad.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x131 (305) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | ≥ 1 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00/01 | 1 = USB charging disabled by `C:\Dpp\Microsoft\UsbNoCurrentDraw.txt` |

---

### internal IOCTL 0x29C4C0 — charging source notification

This IOCTL is processed by Cad.sys (`EvtIoInternalDeviceControl` only; as a normal IOCTL it gets `STATUS_NOT_SUPPORTED`)  
It is sent by [usbfnclx.sys](./usbfnclx.md#ioctl-0x29c4c0--charging-notification) for the USB source.  
This IOCTL is also sent by [ufx01000.sys](./ufx01000.md#internal-ioctl-0x29c4c0--ioctl_internal_cad_power_source_update) (`IOCTL_INTERNAL_CAD_POWER_SOURCE_UPDATE`, 32 bytes, with the proprietary charger GUID at 10-1F).

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x130 (304) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Charging source notification | 16 or ≥ 32 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | Source type: 2 USB, 3 wireless (other → `STATUS_INVALID_PARAMETER`) |
| 04-07 | e.g. DC 05 00 00 | MaxCurrent in mA |
| 08 | 00/01 | 1 = connected |
| 0C-0F | e.g. 02 00 00 00 | Kept in the record (USB port type), not forwarded |
| 10-1F | | Charger id GUID; only with ≥ 32 bytes, zero with 16 bytes |

Input < 16 → `STATUS_INVALID_PARAMETER` (0xC000000D). Processing: see [Charging sources](#charging-sources).

---

### IOCTL 0x294040 — IOCTL_BATTERY_QUERY_TAG

This IOCTL is sent by Cad.sys to [battc.sys](./battc.md#ioctl-0x294040--ioctl_battery_query_tag) (each battery, at arrival, synchronous)

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATTERY_QUERY_TAG | battery `{72631E54-…}` | 4 | 4 |

Input: timeout, not initialised (stack variable). Output: tag, stored at battery record `+08`.

---

### IOCTL 0x294044 — IOCTL_BATTERY_QUERY_INFORMATION

This IOCTL is sent by Cad.sys to [battc.sys](./battc.md#ioctl-0x294044--ioctl_battery_query_information) (each battery, at arrival, synchronous)

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATTERY_QUERY_INFORMATION | battery `{72631E54-…}` | 12 | 36 |

Input: tag, level 0 (`BatteryInformation`), 0. Output `BATTERY_INFORMATION`: Capabilities bit 0x8 / 0x4 → battery record `+0C` / `+0D`, FullChargedCapacity (`10-13`) → `+20`.

---

### IOCTL 0x29404C — IOCTL_BATTERY_QUERY_STATUS

This IOCTL is sent by Cad.sys to [battc.sys](./battc.md#ioctl-0x29404c--ioctl_battery_query_status) (each battery, at arrival, synchronous)

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATTERY_QUERY_STATUS | battery `{72631E54-…}` | 20 | 16 |

Input: tag, then 0 (timeout 0, return at once). Output `BATTERY_STATUS`: only logged ("Capacity:%u, FullChargedCapacity:%u, Voltage:%u, Rate:%d").

---

### IOCTL 0x298048 — IOCTL_BATTERY_SET_INFORMATION

This IOCTL is sent by Cad.sys to [battc.sys](./battc.md#ioctl-0x298048--ioctl_battery_set_information) (each battery)

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATTERY_SET_INFORMATION | battery `{72631E54-…}` | 16, 12 or 24 | 0 |

Inputbuffer, `BatteryChargingSource` with charging-source support (synchronous):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Battery tag |
| 04-07 | 03 00 00 00 | `BatteryChargingSource` |
| 08-0B | 02 00 00 00 | Type: 2 USB (also for the KD source), 3 wireless |
| 0C-0F | e.g. 84 03 00 00 | MaxCurrent in mA |

Inputbuffer, `BatteryChargingSource` without charging-source support (synchronous):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Battery tag |
| 04-07 | 03 00 00 00 | `BatteryChargingSource` |
| 08-0B | | MaxCurrent in mA |

Inputbuffer, `BatteryChargerId` (charger id supported and non-zero; asynchronous, request deleted on completion):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Battery tag |
| 04-07 | 04 00 00 00 | `BatteryChargerId` |
| 08-17 | | Charger id GUID |

---

### IOCTL 0x294050 — IOCTL_BATTERY_CHARGING_SOURCE_CHANGE

This IOCTL is sent by Cad.sys to each battery (asynchronous, `SendChargeSourceChangeNotificationRequestASync` sub_10005548, re-sent by the completion routine `CADSourceChangeCompletionRoutine` sub_10005634)

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x14 (20) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_BATTERY_CHARGING_SOURCE_CHANGE | battery `{72631E54-…}` | 0 | 8 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Type: 1 AC, 2 USB, 3 wireless |
| 04 | | 1 = on |

The result is only traced ("USB power source ON", "AC power source OFF", …); nothing else is done. On failure the request isn't re-sent ("ignoring future requests"). The [battc.sys](./battc.md) page doesn't list this code, so it probably fails at once on the Lumia 520 (?).

---

### Interface GUID

`GUID_DEVINTERFACE_CHARGING_ARBITRATION` (reference string `Charging Arbitration Driver Status`)  
`{EC0A1CC9-4294-43FB-BF37-B850CE95F337}`

### Other GUID

`GUID_DEVICE_BATTERY` (PnP notification target)  
`{72631E54-78A4-11D0-BCF7-00AA00B7B32A}`
