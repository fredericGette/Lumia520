## NokiaEnergyDriver.sys

Nokia battery miniclass and charging-control driver (KMDF, `NokiaEnergyDriver.pdb`, source `src\ned_adc.c`; the device context type is `NED_DEVICE_CONTEXT`).  
It is the battery **miniclass driver** of the Windows battery stack: it registers with [battc.sys](./battc.md) (`BatteryClassInitializeDevice`) and answers the `IOCTL_BATTERY_*` requests (tag, information, status, set-information, status notification). It also **runs the charger**: a worker thread selects the charging voltage/current from temperature tables in ACPI, programs the PMIC charger through [qcpmic8930.sys](./qcpmic8930.md) (`IOCTL_PM_CHG_*`, device type `0x8008`), detects the end of charge, and protects against low battery voltage with the PMIC battery alarm.  
The state of charge comes from [qcbms8930.sys](./qcbms8930.md) (`IOCTL_BMS_*`). In return, this driver feeds qcbms8930 with the battery temperature, the PMIC temperature, the battery-ID reading and the XOADC calibration points, read from an ADC driver (device type `0x8ADC`, channel names `BATT_ID`, `BATT_THERM`, `VBATT`…).  
It reads 3 GPIO lines and up to 6 interrupts from its ACPI resources, and reads its battery and charging parameters from the ACPI methods `CONF`, `CUTF`, `CHGR` and `CGHV`. It exposes the passive-cooling interface `GUID_THERMAL_COOLING_INTERFACE`, used to cut the charging current.

On the Lumia 520 the device is `\_SB.NEDD` (`_HID` `NOKI0B00`, no `_UID`, no `_DEP`). It's defined in the Nokia SSDT (`NOKIA `/`MSM8930 `, OEM revision 4), not in the DSDT; see [Lumia 520 ACPI node](#lumia-520-acpi-node). The ADC channels that it reads (`VBATT`, `BATT_THERM`, `BATT_ID`, `BATT_RID`…) are defined in the `CHAN` method of `\_SB.ADC1` (`QCOM0C00`, PMIC ADC driver) in the DSDT.

There's no named `\Device\` object and no symbolic link (the WDF device is unnamed). The driver creates the device interface `{00DC4DBB-BDFF-4051-8A95-754CE94CB57C}`; [battc.sys](./battc.md) also registers the standard battery interface `GUID_DEVICE_BATTERY` `{72631E54-78A4-11D0-BCF7-00AA00B7B32A}` and the power meter interface `GUID_DEVICE_POWER_METER` `{E849804E-C719-43D8-AC88-96B894C191E2}` on its PDO.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>`

Registry values, read with `WdfRegistryQueryULong` from the driver's **service key** (`WdfDriverGetRegistryPath`, not the `Parameters` subkey) by `sub_4056C4` when all the peer devices are present. All are REG_DWORD; a missing value keeps the default (no range check):  
| Registry value | value | comment |
|----------------|-------|---------|
| DisableChargingSource | 0 | Bit 0 set: a charger reported by `IOCTL_BATTERY_SET_INFORMATION`/`BatteryChargingSource` is not used to start charging ? |
| UsbOverride | 0 | When not 0, replaces the USB input current limit (mA) given by BATTC (from the [charging power source](./battc.md#charging-power-source) interface) / the PMIC |
| DefaultVdd | 3600 | Charger voltage (mV) programmed when no charging is wanted (charge complete, no table entry) |
| ImprovedWlcDetection | 0 | Read but never used in this binary |
| IbatMaxOverride | 0 | When not 0, replaces the battery charging current (mA) of the tables (only while charging) |
| WirelessInputVoltage | 6700 | `IOCTL_PM_CHG_VIN_MIN` value (mV) when no USB current is set (wireless charging ?). With a USB current, 4300 mV (USB current > 900 mA) or 4450 mV is used |
| WirelessChargingCovers | 0 | Must be 3 for [IOCTL 0x222004](#ioctl-0x222004) to work |
| CCIPassiveCooling | 0 | Selects the thermal rule: 0 = the charging current is scaled by the passive-cooling percentage; ≠ 0 = the PMIC-temperature rule with a 325 mA limit (see [Thermal throttling](#thermal-throttling)) |

GUID of the ETW provider:  
None. The trace function `sub_401D88` (called with strings like `Level = %s`, `Terminate charging: %s`, `Res name: %ls`) is an empty stub.

It communicates with the following devices. The six interfaces are found with `IoRegisterPlugPlayNotification` (`EventCategoryDeviceInterfaceChange`, callback `sub_404B58`) and opened with `WdfIoTargetOpen`; the driver starts (`sub_405074`) only when **all six** are present:  
| Interface class GUID | Driver | Comment |
|----------------------|--------|---------|
| `{1CF4643A-F9BF-42D3-88E8-F37EE6C0677C}` | [qcpmic8930.sys](./qcpmic8930.md) (interface 15) | Target of the charger `IOCTL_PM_CHG_*` (`0x8008xxxx`) and interrupt `IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS` (`0x80070FA8`) requests |
| `{10542F20-9718-452A-897A-45785468E57A}` | ADC driver ? (not documented yet) | ADC channels, device type `0x8ADC`, see [ADC channels](#adc-channels). [qcpep8930.sys](./qcpep8930.md#thermal-zones) uses the same interface and IOCTLs for `BATT_THERM` and `PA_THERM` |
| `{23B7D0DD-101F-4EFE-A4D4-BED70E754419}` | [qcbms8930.sys](./qcbms8930.md) | `IOCTL_BMS_*` (`0x8018xxxx`) |
| `{FF22FC8B-383D-40D3-AFC0-2C37A30D060A}` | [qcpmic8930.sys](./qcpmic8930.md) (interface 19) | Battery alarm `IOCTL_PM_BATALRM_*` (`0x801Axxxx`) |
| `{9A8FF884-5882-4B62-9E0F-172ACE2A9EC0}` | [qcpmic8930.sys](./qcpmic8930.md) (interface 5, PMIC interrupts `0x8007`) | Only awaited: no IOCTL is sent to it |
| `{9E03B1E8-9445-4497-81D1-8DB0C0FF7D78}` | ? | `IOCTL 0x222404`, 4-byte output. Success with 0 selects the `CGHV` charging tables (wireless charging ?) |
| ACPI node of the device | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) `CONF`, `CUTF`, `CHGR`, `CGHV` |
| `\Device\RESOURCE_HUB\<connection id>` | GPIO controller ([acpiex.sys](./acpiex.md)) | 3 GPIO lines, `IOCTL_GPIO_READ_PINS` (0x480000) / `IOCTL_GPIO_WRITE_PINS` (0x480004) |
| — (export library) | [battc.sys](./battc.md) | Battery class: `BatteryClassInitializeDevice`, `BatteryClassIoctl`, `BatteryClassStatusNotify` |
| — | thermal manager ? | Consumer of `GUID_THERMAL_COOLING_INTERFACE` |

> [!NOTE]
> Nothing handles the removal of a peer: its target is never closed (except the GPIO targets, see below).

### Initialisation

`EvtDriverDeviceAdd` (0x4048C8):
1. PnP/power callbacks: `EvtDevicePrepareHardware` = `sub_404CBC`; `EvtDeviceReleaseHardware`, `EvtDeviceD0Entry` and `EvtDeviceD0Exit` all point to the same function that only returns `STATUS_SUCCESS` (0x405068).
2. `WdfDeviceInitAssignWdmIrpPreprocessCallback(IRP_MJ_DEVICE_CONTROL)` → `sub_40234C`: every IOCTL first goes to `BatteryClassIoctl`; only when BATTC doesn't own it (no battery class handle yet, or `STATUS_NOT_SUPPORTED`, which [battc.sys](./battc.md#exports) returns without completing the IRP for every code other than `IOCTL_BATTERY_*` and the PMI codes `0x45xxxx`) is the IRP given to the WDF queue.
3. Creates the device interface `{00DC4DBB-…}`, a parallel default queue (`EvtIoDeviceControl` 0x401008), the GUID table of the six peers, the GPIO access modes (connection 0 = write, 1 and 2 = read), 3 notification events, and adds the query interface `GUID_THERMAL_COOLING_INTERFACE` (version 1, `PassiveCooling` = `sub_4046AC`, no `ActiveCooling`).

`EvtDevicePrepareHardware` (`sub_404CBC`) walks the resources:
* `CmResourceTypeConnection`, class GPIO, type IO: up to 3 connections. The path `\Device\RESOURCE_HUB\<16 hex digits>` is built and opened with `FILE_GENERIC_WRITE` (connection 0) or `FILE_GENERIC_READ` (connections 1 and 2).
* `CmResourceTypeInterrupt`: up to 6 interrupts, `WdfInterruptCreate` with the ISR `sub_4052AC` (queues the work item once the driver is started) and a passive-level work item from the table at `.data:0x4081E0`:

| Interrupt # | Work item | Action |
|-------------|-----------|--------|
| 0, 2, 5 | `sub_404468` | Wake the charging worker |
| 1 | `sub_4045E0` | Re-read the charger state (`IOCTL_PM_CHG_GET_STATE`) |
| 3 | `sub_40307C` | Start the low-voltage monitor in 1 ms (battery alarm interrupt ?) |
| 4 | `sub_40460C` | Record the time; wake the charging worker if the previous one was more than 1 s ago (charger event ?) |

* Then registers the six PnP notifications.

When all six peers are open, `sub_405074`:
1. Reads the registry values, then `sub_4032F0` reads the ACPI methods `CHGR` and `CGHV` (see [Charging tables](#charging-tables)), creates the timers, sends `IOCTL_PM_CHG_READ_CHARGING_PARAMTERS` (0x80080FE4) and keeps its first output dword as the initial USB current limit (context `+0x6C`).
2. Sets the 8 ADC channel ids to 9 (unknown), creates the (unused) ADC-threshold timer.
3. `sub_4024B4`: starts the 187-second capacity timer, reads `CUTF`, starts the low-voltage monitor (first run after 5 s).
4. Default battery data (`+0x210`…): 100, 0, 5, 7, 1200, 1500, overwritten by the ACPI method `CONF`.
5. `BatteryClassInitializeDevice` (`sub_402294`), then the worker thread `sub_4051E8` (`PsCreateSystemThread`).

The worker thread waits on 3 events:  
| Event | Set by | Action |
|-------|--------|--------|
| 0 | the 5 s and 120 s charging timers, interrupts, BATTC set-information, passive cooling | `sub_403E6C`: charging control |
| 1 | 187 s timer | `sub_402C64`: capacity update |
| 2 | — (never set) | Set the `BATTERY_CRITICAL` power-state bit |

### ACPI methods

All are evaluated with `IOCTL_ACPI_EVAL_METHOD` (0x32C004, signature `AeiB`, no argument) on the device's own stack, with a 2048-byte output and a 1-second timeout; the output signature must be `AeoB`.  
| Method | Content | Use |
|--------|---------|-----|
| `CONF` | Package of 6 integers; the first one must be 100…199 (version ?) | `+0x210` version, `+0x214` flag (adds `0x10000000` to the battery capabilities), `+0x218` alert 1 (%), `+0x21C` alert 2 (%), `+0x220` full-charged capacity, `+0x224` designed capacity. Defaults 100, 0, 5, 7, 1200, 1500 |
| `CUTF` | Package of 3 integers | Battery voltage thresholds in mV, see [Low-voltage monitor](#low-voltage-monitor) |
| `CHGR` | Package: integer + 1 or 2 tables | Termination current in mA (`+0x7C`, default 250), normal charging table, alternate charging table |
| `CGHV` | Package: 1 or 2 tables | Same as `CHGR` without the integer; used instead of `CHGR` when the `{9E03B1E8-…}` device reports 0 |

The name of `CHGR`/`CGHV` is byte-swapped by `sub_4011FC` (the code holds `RGHC`/`VHGC`).

### Charging tables

A table is a package of n ≥ 2 packages of 6 integers, parsed by `sub_401354` into `n, n × 24 bytes`. It's rejected when the temperature ranges aren't increasing, when an entry other than the last one has a zero voltage or current, or when the last entry doesn't have both 0. Without a valid `CHGR` table, a hardcoded table at `.rdata:0x40712C` is used.  
| Field | Comment |
|-------|---------|
| 0 | Lower battery temperature, in K |
| 1 | Upper battery temperature, in K |
| 2 | Charging voltage, in mV (0 in the last entry = no charging) |
| 3 | Charging current, in mA (0 in the last entry) |
| 4 | Charging voltage after the first termination (0 = same as field 2) ? |
| 5 | Battery voltage below which charging restarts after the termination (0 = use field 2) ? |

The current entry follows the battery temperature (`BATT_THERM` + 273), with the bounds of the neighbouring entries as hysteresis.

### Lumia 520 ACPI node

From the Nokia SSDT, `Device (NEDD)` (`_HID` `NOKI0B00`).

`_CRS` has **6 `GpioInt` and no `GpioIo`**. So on the Lumia 520 the driver gets 6 interrupts and **no GPIO connection**: connections 0–2 (charger-present input, charger control output) don't exist, and the GPIO reads/writes described on this page have no target. How the driver behaves without them (e.g. how it detects the charger) hasn't been checked ?  
The interrupts, assuming they're numbered in `_CRS` order:  
| Interrupt # | Controller, pin | Descriptor | Work item (from the table above) |
|-------------|-----------------|------------|-----------------------------------|
| 0 | `\_SB.PM01` 15 (PMIC IRQ block 0, bit 15) | Edge, ActiveBoth, Shared, Wake, PullUp | Wake the charging worker |
| 1 | `\_SB.PM01` 42 (block 0, bit 42) | Edge, ActiveBoth, Shared, Wake, PullUp | Re-read the charger state |
| 2 | `\_SB.PM01` 13 (block 0, bit 13) | Edge, ActiveLow, Shared, Wake, PullUp, debounce 2 ms | Wake the charging worker |
| 3 | `\_SB.PM01` 46 (block 0, bit 46) | Edge, ActiveHigh, Shared, Wake, PullUp | Low-voltage monitor (battery alarm ?) |
| 4 | `\_SB.GIO0` 91 (TLMM) | Edge, ActiveHigh, Shared, Wake, PullNone, debounce 200 ms | Charger event ? |
| 5 | `\_SB.PM01` 192 (block 3, bit 0 = interrupt of PMIC GPIO index 0, GPIO1) | Edge, ActiveBoth, Shared, Wake, PullUp | Wake the charging worker |

The `\_SB.PM01` pins are PMIC interrupt numbers (block × 64 + bit), handled by [qcpmicgpio8930.sys](./qcpmicgpio8930.md#pin-numbering): it programs them with `IOCTL_PM_IRQ_CONFIG_INTERRUPT` on [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8007xxxx--interrupts), and pin 192 is first configured as a GPIO input. Which PM8038 interrupt source bits 13, 15, 42 and 46 of block 0 are hasn't been identified.

`CONF` = `Package { 100, 0, 2, 8, 1350, 1430 }`:  
| Index | Value | Meaning (see [ACPI methods](#acpi-methods)) |
|-------|-------|---------------------------------------------|
| 0 | 100 | Version (must be 100…199) |
| 1 | 0 | Flag: no `0x10000000` in the battery capabilities |
| 2 | 2 | Alert 1 (%) |
| 3 | 8 | Alert 2 (%) |
| 4 | 1350 | Full-charged capacity (mAh) |
| 5 | 1430 | Designed capacity (mAh): the 1430 mAh BL-5J battery of the Lumia 520 |

`CUTF` = `Package { 0, 3300, 3400 }`. `CUTF[0]` = 0 replaces the default 5000 mV, so level 2 of the [low-voltage monitor](#low-voltage-monitor) is never reached. Level 0 (capacity ramped to 0, `BATTERY_CRITICAL`) is below **3300 mV**, and level 1 (capacity limited to 9 %) below **3400 mV** when not charging. The battery alarm is armed with 4500 mV and 3450 mV.

`CHGR` = `Package { 90, <normal table>, <alternate table> }`: termination current **90 mA**. `CGHV` isn't defined. When the `{9E03B1E8-…}` device reports 0, the driver asks for `CGHV`, the evaluation fails, and the fallback (hard-coded table ?) hasn't been checked.  
Normal table (temperatures in K, °C in brackets):  
| Entry | Lower T | Upper T | Voltage (mV) | Current (mA) | Field 4 (mV) | Field 5 (mV) |
|-------|---------|---------|--------------|--------------|--------------|--------------|
| 0 | 270 (−3) | 272 (−1) | 3900 | 325 | 0 | 0 |
| 1 | 280 (7) | 282 (9) | 4100 | 875 | 4050 | 4000 |
| 2 | 290 (17) | 292 (19) | 4200 | 875 | 4150 | 4100 |
| 3 | 302 (29) | 304 (31) | 4200 | 875 | 4150 | 4100 |
| 4 | 314 (41) | 316 (43) | 4100 | 875 | 4050 | 4000 |
| 5 | 333 (60) | 335 (62) | 0 | 0 | 0 | 0 |

The alternate table is identical except the last entry: 329–331 K (56–58 °C). Charging therefore stops 4 °C earlier when the alternate table is selected.

### Charging control

`sub_403E6C` (event 0) does, in order:
1. Status (`sub_403730`): battery presence through `BATT_RID` (10…400 after ÷1000, 3 tries 100 ms apart, else the run fails), charger plugged = GPIO connection 1 bit 0 is **0**, battery temperature, `VBATT`, current (`IOCTL_BMS_GET_BATTERY_CURRENT`), `IOCTL_PM_CHG_GET_STATE`.
2. Chooses the USB input current (BATTC charging source of type 2 `BatteryChargingSourceType_USB`, or `UsbOverride`; only when `GET_STATE` byte `08` ≠ 0), the table (`CHGR`/`CGHV`; the alternate table when `sub_403DCC` is true: charger plugged and a 330 s window after an event ?) and the entry for the temperature.
3. Charging phase (context `+0x78`): 0 = charging with field 2/3, 1 = recharge with field 4 (or 2) and 3, 2 = **charge complete** (no current, `DefaultVdd`). Phase 2 is entered when the PMIC charger state is 7 and `sub_403604` sees the end of charge: 5 current readings 20 ms apart whose median is below the termination current (and above −50 mA), with PMIC real-time interrupt bit 24 of block 0 still set (`IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS`).
4. Thermal throttling, then programs the charger (`sub_403A48`): `PET_WDOG` (0, 30), `CHGPATH_ENABLE`, GPIO connection 0 (see [IOCTLs sent](#ioctls-sent)), `VIN_MIN`, `CHG_PARAMS`, `FSM_ENABLE`. When charging, the voltage is ramped up from the present battery voltage in 50 mV steps every 5 ms. Every 30 minutes the charger FSM is disabled and re-enabled.
5. `sub_403C90`: when the input-voltage regulation loop is active (`IOCTL_PM_CHG_GET_REGULATION_LOOP` byte 3), at most every 2 s, `VIN_MIN` is set to 0 and restored 20 ms later.
6. Power state for BATTC, applied after 500 ms: 5 (`BATTERY_POWER_ON_LINE` + `BATTERY_CHARGING`) when charging, 3 (`ON_LINE` + `DISCHARGING`) when a charger is usable but not charging (e.g. charge complete), 2 (`DISCHARGING`) otherwise, and `IOCTL_BMS_SET_CHARGING_STATE` when the state changes.
7. Re-arms the 5 s timer (charging) and the 120 s timer (any phase but 0). If the status or the charger programming fails, the worker is woken once more and the failure flag `+0x70` is set: from then on every run programs the charger with charging **disabled**, and `QueryTag` reports no battery.

`IOCTL_BMS_SET_CHARGING_STATE` value sent to [qcbms8930.sys](./qcbms8930.md):  
| Value | Sent when |
|-------|-----------|
| 0 | Charging |
| 1 | Not charging |
| 2 | Charge complete or recharge (phase 1 or 2) |

> [!NOTE]
> This is not the meaning given on the [qcbms8930.sys](./qcbms8930.md#ioctl-0x80180fb0--ioctl_bms_set_charging_state) page (0 = not charging, 1 = charging): one of the two interpretations is wrong.

### Thermal throttling

`PassiveCooling(percent)` (`sub_4046AC`) stores the percentage (≤ 100, context `+0x84`) and wakes the worker.
* `CCIPassiveCooling` = 0: charging current × percent / 100; below 20 % charging is disabled.
* `CCIPassiveCooling` ≠ 0: when the current is above 325 mA, it's limited to 325 mA once `PMIC_THERM` > 62000 (m°C ?) with a percentage below 100, and the limit is released when `PMIC_THERM` < 59000 with a percentage of 100.
* `IbatMaxOverride` then replaces the current while charging.

### Capacity

`sub_402C64` (every 187 s, and on `IOCTL_BATTERY_QUERY_STATUS` if the last update is more than 1 s old):
1. At most every 300 s, reads the raw ADC values of `V0P625` and `V1P25` and sends them to qcbms8930 with `IOCTL_BMS_SET_XOADC_CAL_VAL`.
2. Sends `IOCTL_BMS_SET_SYSTEM_INFO` (`PMIC_THERM`, 1000 × `BATT_THERM`, `BATT_ID`), then `IOCTL_BMS_GET_PERCENT_CHARGE`. The value is scaled by 10/9 (90 % from qcbms8930 is reported as full), capped at 1000 ‰, and multiplied by the full-charged capacity.
3. The reported capacity (`sub_402B6C`) moves by at most 3 % of the full capacity per minute towards the raw value. It jumps to the raw value when the difference exceeds 20 % or when the raw value is below half the capacity, and it's the full capacity during the charge-complete phase.

The capacity given to BATTC is also clamped by the low-voltage monitor (max/min limits).

### Low-voltage monitor

`sub_402E68`, a timer, uses the 3 `CUTF` thresholds (VBATT from the ADC):  
| Level | Condition | Effect |
|-------|-----------|--------|
| 0 | VBATT < `CUTF[1]` for more than 5 checks | Reported capacity ramps down to 0 (−0.5 % per 100 ms), `BATTERY_CRITICAL` set |
| 1 | VBATT < `CUTF[2]` for more than 3 checks, not charging | Capacity limited to 9 % |
| 2 | VBATT < `CUTF[0]` (default 5000 mV) | No limit |
| 3 | Charging, or VBATT > `CUTF[2]` + 250 mV | Capacity at least alert 1 − 1 % |

While VBATT ≤ `CUTF[2]` + 250 mV the check runs every 5 s (20 s above `CUTF[1]`, 100 ms at level 0) with the PMIC battery alarm disabled. Above, polling stops and the battery alarm is armed (`IOCTL_PM_BATALRM_CONFIG_CONTROL_REGISTER` with 4500 mV and `CUTF[2]` + 50 mV, then `IOCTL_PM_BATALRM_ENABLE_CONTROL_REGISTER`).

### ADC channels

The ADC channel id is looked up once by name (`IOCTL 0x8ADC2000`) and cached at context `+0xD8 + 4 × index`, then read with `IOCTL 0x8ADC2004`. Names are at `.data:0x408140`, 20 bytes each:  
| Index | Name | Use |
|-------|------|-----|
| 0 | `BATT_ID` | Battery-ID reading sent in `IOCTL_BMS_SET_SYSTEM_INFO` |
| 1 | `BATT_THERM` | Battery temperature in °C (−300 when the read fails): table entry, BATTC temperature, `IOCTL_BMS_SET_SYSTEM_INFO` |
| 2 | `ICHG` | Not used |
| 3 | `PMIC_THERM` | PMIC temperature (m°C ?, −300000 when the read fails) |
| 4 | `VBATT` | Battery voltage in mV (BATTC status, low-voltage monitor) |
| 5 | `VPH_PWR` | Not used |
| 6 | `IBATT` | Not used |
| 7 | `BATT_RID` | Battery presence check |
| — | `V0P625`, `V1P25` | XOADC 0.625 V / 1.25 V references, raw values for qcbms8930 (looked up on each use) |

### Battery class

[BATTC](./battc.md) miniport callbacks (`BATTERY_MINIPORT_INFO` version 1.0). BATTC calls them from its worker thread, pinned to processor 0, and caches the tag and the status for 2 s ([Status polling](./battc.md#status-polling)):  
| Callback | Function | Comment |
|----------|----------|---------|
| QueryTag | `sub_401DFC` | Tag `0xBEEF`, or 0 (no battery) once the charging worker has failed |
| QueryInformation | `sub_401E5C` | See below. Wrong tag → `STATUS_NO_SUCH_DEVICE` (0xC000000E) |
| SetInformation | `sub_40200C` | `BatteryCharge` (allow charging), `BatteryDischarge` (block charging), `BatteryChargingSource` (type and max current; type 2 USB sets the USB current). BATTC sends it from `ChargeNotificationCallback` when the [charging power source](./battc.md#charging-power-source) provider reports a charger, and sends types 1, 2 and 3 with 0 mA when that provider goes away. `BatteryCriticalBias` and others → `STATUS_NOT_SUPPORTED`. A NULL buffer for `BatteryChargingSource` → `STATUS_INVALID_PARAMETER_4` |
| QueryStatus | `sub_40212C` | PowerState, Capacity, Voltage = `VBATT` (−1 on error), Rate = −(qcbms8930 current) or `BATTERY_UNKNOWN_RATE` |
| SetStatusNotify | `sub_4021D8` | Stores PowerState / LowCapacity / HighCapacity, `BatteryClassStatusNotify` when they're crossed. Because it succeeds, BATTC doesn't poll; it only re-queries the status every `BatteryMinBackupPollRate` (3600 s by default on AoAc platforms) while a status request is waiting |
| DisableStatusNotify | `sub_40225C` | |

`QueryInformation` levels:  
| Level | Size | Content |
|-------|------|---------|
| 0 BatteryInformation | 36 | Capabilities `0x80000007` (`BATTERY_SYSTEM_USE` + set charge/discharge/charging-source supported ?) \| `0x10000000` when `CONF` flag ≠ 0; Technology 1 (rechargeable); Chemistry `LION`; Designed = `CONF[5]`; FullCharged = `CONF[4]`; DefaultAlert1/2 = `CONF[2]`/`CONF[3]` % of FullCharged; CriticalBias 0; CycleCount 0 |
| 1 BatteryGranularityInformation | 8 | One scale: granularity = FullCharged / 100, capacity = FullCharged |
| 2 BatteryTemperature | 4 | 10 × `BATT_THERM` + 2732 (tenths of K) |
| 3 BatteryEstimatedTime | 4 | 3600 × capacity / rate; the rate is the requested one, or else the qcbms8930 current; `BATTERY_UNKNOWN_TIME` (−1) when it's ≤ 0 |
| 4 BatteryDeviceName | 26 | `Nokia BX-XXX` (UTF-16) |
| others | — | `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) |

A buffer too small gives `STATUS_INVALID_PARAMETER` (0xC000000D).  
Because levels 5 to 8 aren't supported, the BATTC WMI static data block (`BATTERY_STATIC_DATA_WMI_GUID`) has an all-`*` ManufactureDate and empty ManufactureName / SerialNumber / UniqueID strings. Its `BATTERY_CYCLE_COUNT_WMI_GUID` is always 0. The BATTC power meter (`IOCTL_PMI_GET_MEASUREMENT` ?, 0x45400C) reports −Rate, i.e. the qcbms8930 current value, while `BATTERY_DISCHARGING` is set ([details](./battc.md#ioctl-0x45400c--ioctl_pmi_get_measurement-)).

---

### IOCTL 0x222004

This IOCTL is processed by NokiaEnergyDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (wireless charging cover present ?) | ignored | ≥ 1 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 / 01 | Result of `sub_4010E0` |

Sent to the device interface `{00DC4DBB-…}`. `STATUS_NOT_SUPPORTED` (0xC00000BB) unless `WirelessChargingCovers` = 3; `STATUS_DEVICE_NOT_READY` (0xC00000A3) before the driver is started. Any other code → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).  
`sub_4010E0` returns 1 when GPIO connection 1 bit 0 is 0 (charger present). Otherwise, at most once a second, it reads GPIO connection 2 (returns 1 when bit 0 is 0) and writes 0 to GPIO connection 0; in between, it returns the cached result.

---

### IOCTLs sent

All are sent synchronously (`WdfIoTargetSendIoctlSynchronously`, 1-second timeout) and use METHOD_BUFFERED / FILE_ANY_ACCESS. The first input dword of the qcpmic8930 requests is the PMIC index, always 0. See [qcpmic8930.sys](./qcpmic8930.md) and [qcbms8930.sys](./qcbms8930.md) for the buffer layouts.

Sent to [qcbms8930.sys](./qcbms8930.md) `{23B7D0DD-…}`:  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x80180FA4 | IOCTL_BMS_GET_BATTERY_CURRENT | 0 | 4 | Rate, estimated time, end-of-charge detection |
| 0x80180FAC | IOCTL_BMS_GET_PERCENT_CHARGE | 0 | 4 | Capacity |
| 0x80180FB0 | IOCTL_BMS_SET_CHARGING_STATE | 4 | 0 | 0, 1 or 2, see [Charging control](#charging-control) |
| 0x80180FB4 | IOCTL_BMS_SET_SYSTEM_INFO | 12 | 4 | `PMIC_THERM`, 1000 × `BATT_THERM`, `BATT_ID` |
| 0x80180FBC | IOCTL_BMS_SET_XOADC_CAL_VAL | 8 | 0 | Raw `V0P625`, raw `V1P25` |

Sent to [qcpmic8930.sys](./qcpmic8930.md) `{1CF4643A-…}`:  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x80070FA8 | IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS | 24 | 16 | Block 0, mask `0x01000000`, type 1 (real-time) |
| 0x80080FA8 | IOCTL_PM_CHG_PARAMS | 28 | 4 | `04` USB current (mA), `08` battery current (mA), `0C` 0, `10` 60, `14` voltage (mV, ramped), `18` voltage + 300 mV |
| 0x80080FAC | IOCTL_PM_CHG_GET_STATE | 4 | 16 | `04-07` charger state (7 = end-of-charge candidate), `08` ≠ 0 enables the USB current (input valid ?), `09` watched: a change wakes the worker (checked 0.5 s later when set, 3 s otherwise) |
| 0x80080FB0 | IOCTL_PM_CHG_FSM_ENABLE | 16 | 4 | `04` battery current > 0, `08` 1, `0C` USB current = 0 |
| 0x80080FB4 | IOCTL_PM_CHG_PET_WDOG | 8 | 4 | 30 |
| 0x80080FB8 | IOCTL_PM_CHG_CHGPATH_ENABLE | 8 | 4 | Charging enabled |
| 0x80080FC0 | IOCTL_PM_CHG_VIN_MIN | 12 | 4 | `04` charging enabled, `08` minimum input voltage (mV) |
| 0x80080FD4 | IOCTL_PM_CHG_GET_REGULATION_LOOP | 4 | 8 | Byte 3: input-voltage loop active ? |
| 0x80080FE4 | IOCTL_PM_CHG_READ_CHARGING_PARAMTERS | 4 | 28 | At start; the first dword becomes the initial USB current |

Sent to [qcpmic8930.sys](./qcpmic8930.md) `{FF22FC8B-…}`:  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x801A0FA0 | IOCTL_PM_BATALRM_CONFIG_CONTROL_REGISTER | 16 | 4 | 0, 4500 (upper mV ?), `CUTF[2]` + 50 (lower mV ?), 7 |
| 0x801A0FA4 | IOCTL_PM_BATALRM_ENABLE_CONTROL_REGISTER | 16 | 4 | 0, 1, 0, enable |

Sent to the ADC driver `{10542F20-…}`:  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x8ADC2000 | ? (get channel) | strlen + 1 | 8 | Input: channel name (ASCII). Output: `00-03` 1 = found, `04-07` channel id |
| 0x8ADC2004 | ? (read channel) | 4 | 20 | Input: channel id. Output: `04-07` converted value, `10-13` raw value, rest ? |
| 0x8ADC2008 | ? (threshold / async read) | 16 | 24 | Sent asynchronously by `sub_401A1C` with 2 values, 1000000, 0. Only reachable from its own timer, which is never started: unused |

Sent to `{9E03B1E8-…}`:  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x222404 | ? | 0 | 4 | Only when `CGHV` was found. 0 → the `CGHV` tables are used |

Sent to the GPIO controller (`\Device\RESOURCE_HUB\…`):  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x480000 | IOCTL_GPIO_READ_PINS | 0 | 4 | Connections 1 and 2, bit 0 |
| 0x480004 | IOCTL_GPIO_WRITE_PINS | 4 | 0 | Connection 0. Written by the charger programming: 1 only in the charge-complete phase with the alternate-table condition, 0 otherwise; also written 0 by IOCTL 0x222004 (meaning ?) |

The GPIO target is re-opened before each use if needed (`sub_4052FC` closes the other connection's target first).

Sent to the ACPI node: `IOCTL_ACPI_EVAL_METHOD` (0x32C004), see [ACPI methods](#acpi-methods).

---

### Interface GUID

NokiaEnergyDriver device interface (target of [IOCTL 0x222004](#ioctl-0x222004))  
`{00DC4DBB-BDFF-4051-8A95-754CE94CB57C}`

### Other GUID

Thermal cooling interface exposed (`GUID_THERMAL_COOLING_INTERFACE`, `WdfDeviceAddQueryInterface`)  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`

qcpmic8930 interface 15 (charger and interrupts)  
`{1CF4643A-F9BF-42D3-88E8-F37EE6C0677C}`

qcpmic8930 interface 19 (battery alarm)  
`{FF22FC8B-383D-40D3-AFC0-2C37A30D060A}`

qcpmic8930 interface 5 (PMIC interrupts, awaited only)  
`{9A8FF884-5882-4B62-9E0F-172ACE2A9EC0}`

qcbms8930 interface  
`{23B7D0DD-101F-4EFE-A4D4-BED70E754419}`

ADC driver interface  
`{10542F20-9718-452A-897A-45785468E57A}`

Unknown peer (`IOCTL 0x222404`)  
`{9E03B1E8-9445-4497-81D1-8DB0C0FF7D78}`

`GUID_DEVICE_INTERFACE_ARRIVAL` (PnP notifications)  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
