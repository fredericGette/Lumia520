## Qcbattmngr8930.sys

Qualcomm **battery manager** driver (`P:\BattMngr\rel\8.2.1.1\BattMngr\build\arm\Release\qcbattmngr8930.pdb`, KMDF, 222 functions).  
It's the charging/fuel-gauge state machine behind [qcbattminiclass8930.sys](./qcbattminiclass8930.md): it exposes the interface `{F4116444-4837-49A5-B2C7-433FE501F2AA}`, answers the `IOCTL_BATT_MNGR_*` requests (device type `0x800B`) of the miniclass, and sends `IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS` back when the status changes. It drives a pluggable **charger** back-end and a pluggable **gauge** back-end, selected by the ACPI method `BDGC` or the registry. They talk to [qcpmic8930.sys](./qcpmic8930.md) (charger `0x8008`, interrupts `0x8007`), [qcbms8930.sys](./qcbms8930.md) (`0x8018`), the ADC driver (`0x8ADC`) and optional third-party charger (`0x8016`) and gauge (`0x8009`) drivers.  
The Lumia 520 ACPI tables have no node for this driver (no `BDGC` method), and the battery is handled by [NokiaEnergyDriver.sys](./nokiaenergydriver.md). This driver is probably inactive on the Lumia 520 ?

Device name : none (unnamed WDF device)  
Symbolic link : none  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcbattmngr8930` ?

### Configuration

The configuration is built in three steps in `EvtDriverDeviceAdd` (sub_419008):
1. Built-in defaults (sub_405AE8, called by `DriverEntry`).
2. ACPI method `BDGC` (sub_401008): `IOCTL_ACPI_EVAL_METHOD` (0x0032C004) sent to the device's own lower target (the ACPI PDO), 1024-byte output buffer. sub_4010B0 accepts the result only if the signature is `AeoB` (0x426F6541), there are exactly **25** arguments and argument 0 = 1000. Each argument is read as a 32-bit integer. If the evaluation fails, the defaults stay. The return value is ignored.
3. Registry overrides (sub_403210), read only when `RegMasterEna` = 7631 (0x1DCF).

#### ACPI method `BDGC`

| Arg | Variable | Default | Comment |
|-----|----------|---------|---------|
| 0 | `dword_416E20` | — | Version, must be 1000 |
| 1 | `dword_416E6C` | 27000 | Heartbeat period while charging, ms (`HeartBeatTimerChgOn`) |
| 2 | `dword_416E68` | 120000 | Heartbeat period while not charging, ms (`HeartBeatTimerChgOff`) |
| 3 | `dword_416EE4` | 0 | Battery tag management (`DefaultErrorBehavior`), see [IOCTL_BATT_MNGR_GET_BATTERY_ID](#ioctl-0x800b0fa4--ioctl_batt_mngr_get_battery_id) |
| 4 | `dword_416EDC` | 0 | Charger back-end (`ChargerHW`), see [Charger back-ends](#charger-back-ends) |
| 5 | `dword_416EE0` | 0 | Gauge back-end (`GaugeHW`), see [Gauge back-ends](#gauge-back-ends) |
| 6 | `byte_417710` | 0 | ≠ 0: create the interrupts below |
| 7 | `byte_417711` | 0 | Interrupt 1; its DPC wakes the charger detection |
| 8–10 | `byte_417712`–`byte_417714` | 0 | Interrupts 2–4; their DPC wakes the heartbeat |
| 11 | `dword_416ECC` | 3700 | Nominal battery voltage, mV |
| 12 | `dword_416ED0` | 4150 | Maximum (charge) voltage, mV |
| 13 | `dword_416ED4` | 3400 | Empty voltage, mV (`MinVBattMV`) |
| 14 | `dword_416EC4` | 900 | Maximum charge current, mA |
| 15 | `dword_416E98` | 700 | `BATTERY_INFORMATION.DefaultAlert1` |
| 16 | `dword_416E9C` | 350 | `BATTERY_INFORMATION.DefaultAlert2` |
| 17 | `dword_416E90` | 3515 | `BATTERY_INFORMATION.DesignedCapacity` |
| 18 | `dword_416E94` | 3515 | `BATTERY_INFORMATION.FullChargedCapacity` |
| 19 | `byte_416E88` | 1 | `BATTERY_INFORMATION.Technology` (1 = rechargeable) |
| 20 | `byte_416EC0` | 1 | Use the charging current given by battc (`EnaBattcUSBI`) |
| 21 | `dword_416E70` | 0 | Cable poll period, ms; 0 = no polling (`CablePollTimer`) |
| 22–24 | — | — | All three are stored in the same field (+0x4C of the copy), which is never used |

#### Registry

The values are read under the **service key** itself (`WdfDriverGetRegistryPath`), not under `Parameters`. Only 4-byte values are accepted. A missing value reads as 0xFFFF, which means "keep the current setting".

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcbattmngr8930`:  
| Registry value | value | comment |
|----------------|-------|---------|
| RegMasterEna | 7631 | Any other value: the other values are ignored |
| ForceNoHW | | ≠ 0: charger and gauge back-ends = 0 (no hardware, simulated battery) |
| ForceTestMode | | 1: start in test mode (state 8), see [IOCTL_BATT_MNGR_SET_OPERATIONAL_MODE](#ioctl-0x800b0fbc--ioctl_batt_mngr_set_operational_mode) |
| EnaBattcUSBI | | ≠ 0: use the charging current given by battc (ACPI arg 20) |
| TDoneVal | 28080000 | Maximum charging time, ms (7.8 h). When it expires: state 6 |
| HeartBeatTimerChgOff | 120000 | ACPI arg 2 |
| HeartBeatTimerChgOn | 27000 | ACPI arg 1 |
| GaugeHW | | ACPI arg 5 |
| ChargerHW | | ACPI arg 4 |
| NotifyAlways | | Stored in `byte_417715`, never used |
| DefaultErrorBehavior | | ACPI arg 3 |
| CablePollTimer | | ACPI arg 21 |
| ThermalLimit | 250 | mA. Compared with the maximum charge current on each `SET_CHARGE_RATE`: below it, state 9 (thermal) |
| WAEOCI | 100 | mA. End-of-charge current threshold for gauge 5 |
| HeartBeatTimerChgOffFast | 50000 | Heartbeat period when not charging and the voltage is ≤ `LowVBattMV`, ms |
| MinVBattMV | 3400 | ACPI arg 13 |
| LowVBattMV | 3500 | mV |

The other built-in defaults (sub_405AE8) are the [BATTERY_INFORMATION](#ioctl-0x800b0fac--ioctl_batt_mngr_get_battery_info) strings and values, 100 % for the charge-rate percentage (`dword_416EC8`), 2981 for the temperature and 0xFFFF for the battery id.

GUID of the ETW provider:  
None. The driver contains `EtwWrite` calls (sub_407CE8, sub_407F48, sub_40801C, sub_408534, with source names `BattMngrValidate.c`, `PmicValidateIoctl.c`, `PmicDriverRequest.c`), but it never calls `EtwRegister`: the registration handle is always 0. The trace flags (`dword_417778`) are never set either, so the trace code is dead.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI PDO | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD` `BDGC` |
| Interface `{6C7FF145-BE42-4ED4-ADF1-2ECD06EF23B7}` | [qcbattminiclass8930.sys](./qcbattminiclass8930.md) | Receives [IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS](#ioctl-0x800c0fa4--ioctl_pmic_batt_mini_notify_status) |
| Interface `{1CF4643A-F9BF-42D3-88E8-F37EE6C0677C}` | [qcpmic8930.sys](./qcpmic8930.md) (interface 15) | Charger `IOCTL_PM_CHG_*` (`0x8008`). Chargers 1, 2, 3 |
| Interface `{9A8FF884-5882-4B62-9E0F-172ACE2A9EC0}` | [qcpmic8930.sys](./qcpmic8930.md) (interface 5) | `IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS` (`0x80070FA8`). Charger 2, gauges 3 and 5 |
| Interface `{EF512E80-3E93-45D7-AF9D-D375D53596B8}` | [qcpmic8930.sys](./qcpmic8930.md) (interface 10, MPP) | Charger 1: only awaited, nothing is sent to it |
| Interface `{23B7D0DD-101F-4EFE-A4D4-BED70E754419}` | [qcbms8930.sys](./qcbms8930.md) | `IOCTL_BMS_*` (`0x8018`). Charger 2, gauges 3 and 5 |
| Interface `{10542F20-9718-452A-897A-45785468E57A}` | ADC driver ? (not documented yet) | `IOCTL_ADC_GET_CHANNEL` / `IOCTL_ADC_READ` (`0x8ADC`). Gauges 3, 4, 5 |
| Interface `{3469F855-D4E1-4AD4-AA07-56BFE57E3BC3}` | ? (third-party charger) | `IOCTL_PM_3P_CHG_*` (`0x8016`). Chargers 1 and 3 |
| Interface `{00E1078B-CD2B-4E06-AB3A-DACD8AC7FEEB}` | ? (third-party gauge) | `IOCTL_PM_3P_GAUGE_GET_BATT_PERC` (`0x80090FA0`). Gauges 1 and 2 |

All the interfaces are watched with `IoRegisterPlugPlayNotification` (`RegisterForInterfaceEvent`, sub_408870) and opened with `IoGetDeviceObjectPointer` (`GENERIC_ALL`). They all share the same callback, sub_4037D8.

### Initialisation

1. `DriverEntry` (0x4039B4): built-in defaults (sub_405AE8), `WdfDriverCreate` (pool tag `0mbq` 0x71626D30, the same as qcbattminiclass8930), two wait locks (`dword_417914` = state lock, `dword_417A20` = miniclass lock).
2. `EvtDriverDeviceAdd` (0x403AB4) → sub_419008:
   * PnP/power callbacks: `EvtDeviceD0Entry` and `EvtDeviceQueryRemove` (no-ops), `EvtDeviceD0Exit` (sub_40319C), `EvtDevicePrepareHardware` (sub_4030B0, only counts the resources with `DbgPrint`), `EvtDeviceReleaseHardware` (sub_403160), `EvtDeviceSelfManagedIoInit`/`Restart` (sub_403068, start the queue), `EvtDeviceSelfManagedIoSuspend` (sub_4191E0, stop the queue), `EvtDeviceQueryStop` (sub_402FA0, always `STATUS_UNSUCCESSFUL`: the device can't be stopped).
   * `WdfDeviceCreate`, then the configuration (ACPI `BDGC`, then the registry), see [Configuration](#configuration).
   * Sequential default queue (`EvtIoDeviceControl` 0x406224), with a 10 s WDF timer (sub_4061B8) that completes a request stored in the queue context. Nothing ever stores a request there, so this timer is dead code, as in qcbattminiclass8930.
   * Up to 4 `WdfInterruptCreate` (sub_40537C), only when ACPI arg 6 ≠ 0. ISR sub_4052C8 queues the DPC. The DPC (sub_4052F4 / sub_405338) sets the charger-detection or the heartbeat event.
3. sub_403B18: selects the charger (sub_40128C) and gauge (sub_403C08) back-ends, registers their interface notifications, and also registers for the miniclass interface `{6C7FF145-…}`.
4. Arrival of an interface (sub_4037D8): the gauge and charger arrival handlers open the device and report whether all their interfaces are present. When both back-ends are complete (immediately if both are 0), sub_402FB0(TRUE):
   * starts the worker thread (sub_4068FC), see [State machine](#state-machine), and creates the 3 WDF timers;
   * creates and enables the device interface `{F4116444-4837-49A5-B2C7-433FE501F2AA}`. This makes [qcbattminiclass8930.sys](./qcbattminiclass8930.md) initialise the battery class.
5. Arrival of `{6C7FF145-…}`: opens the miniclass device (`dword_417740`).
6. Removal of an interface: back-end incomplete → sub_402FB0(FALSE): disables `{F4116444-…}`, stops the timers and ends the worker thread (sub_406B08). Note: sub_406B08 then calls `ZwClose` with the **addresses** of the WDF timer and thread handle variables, not with the handles themselves.
7. `EvtDeviceD0Exit` to `WdfPowerDeviceD3Final`: purges the queue, releases the miniclass device, same teardown as step 6, frees the configuration copy (pool tag `1gbq`).

### Charger back-ends

`ChargerHW` (ACPI arg 4) selects a table of 14 functions (`off_416C68`…`off_416C9C`) in sub_40128C:  
| Value | Interfaces awaited | Behaviour |
|-------|--------------------|-----------|
| 1 | `{1CF4643A-…}` PMIC charger, `{3469F855-…}` third-party charger, `{EF512E80-…}` MPP | First call: `VREF_BATT_THERM_CNTRL` (0, 1), `BATT_TEMP_CONFIG` (zeros), `BATT_TEMP_CNTRL` (0, 0). Charging: once `CHGPATH_ENABLE` (0, 0) (disables the PMIC charge path), then `3P_CHG_CHARGE_BATTERY` with the current in mA (0 = stop). In states 3 and 4 the heartbeat repeats `3P_CHG_CHARGE_BATTERY`. Charger present = byte `09` of `CHG_GET_STATE` |
| 2 | `{1CF4643A-…}` PMIC charger, `{9A8FF884-…}` PMIC interrupts, `{23B7D0DD-…}` qcbms | Internal PM8038 charger, see below |
| 3 | `{1CF4643A-…}`, `{3469F855-…}` | Like 1 for the detection and the thermistor setup. Charging starts on phase 2 (`3P_CHG_CHARGE_BATTERY` with maximum current × charge-rate %) and stops on phase 3 |
| other | — | No charger: no IOCTL, never reports a charger |

Slot `off_416C84` ("get charging state", e.g. sub_401D4C which sends `3P_CHG_GET_CHARGER_STATUS` for charger 3) is filled but never called.

Charger 2 (internal charger, sub_402064…sub_402C70):
* First call (sub_4022E8): `CHG_BATTSAFE` (0, 4225, 1500), then the same 3 thermistor calls as charger 1.
* Charging parameters (sub_4023D0): `CHG_PARAMS` with `04` input current (starts at 500 mA), `08` battery current, `0C` 0, `10` 512, `14` charge voltage (mV), `18` 4100.
* Charging enable (sub_40246C): `CHG_PET_WDOG` (30), then `CHG_FSM_ENABLE` (`04` enable, `08` byte from the parameters, `0C` 0). Charging control: `CHG_CHGPATH_ENABLE`. In states 3 and 4 the heartbeat sends `CHG_PET_WDOG` (30).
* Charger present (sub_402558): `CHG_GET_STATE`, bytes `08` and `09` → 0 none, 1 = `08` only, 2 = `09` only, 3 = both.
* Heartbeat while on line (sub_402C70):
  * Battery current regulation (sub_402AFC): when the charger state is 7, it reads `CHG_GET_REGULATION_LOOP` and `BMS_GET_BATTERY_CURRENT`, and corrects the battery current by ±50 mA. The tolerance comes from the table at `.data:0x40B16C`: 325–1024 mA → 200, 1025–1524 → 150, 1525–2024 → 200, 2025–2475 → 250.
  * Input current ramp: +100 mA every 50 ms up to the target. It steps back by 100 mA as soon as byte 3 of `CHG_GET_REGULATION_LOOP` is set (input-voltage loop ?).
  * At 500 mA, or while the rate stays negative with a charger present (up to 10 times): `CHG_VIN_MIN` (off, then 4300 mV 20 ms later).
  * PMIC interrupt bit 27 set (`IRQ_GET_INTERRUPTS_STATUS`, real-time) and charger present: up to 10 cycles of `CHG_FORCE_OVPFET_ON_OFF` / `CHG_OVP_SET_DEBOUNCE_TIME` (OVP recovery ?).

### Gauge back-ends

`GaugeHW` (ACPI arg 5) selects a table of 11 functions (`off_416D98`…`off_416DC0`) in sub_403C08:  
| Value | Interfaces awaited | Percentage / voltage / rate | Temperature, battery id | End of charge |
|-------|--------------------|-----------------------------|-------------------------|---------------|
| 1, 2 | `{00E1078B-…}` third-party gauge | `3P_GAUGE_GET_BATT_PERC` (1 byte). Voltage unknown (−1), rate unknown (0x80000000) | 25 °C, 98 (fixed) | percentage ≥ 100 |
| 3 | `{23B7D0DD-…}` qcbms, `{10542F20-…}` ADC, `{9A8FF884-…}` PMIC interrupts | `BMS_GET_PERCENT_CHARGE` (‰, rounded to %), ADC `VBATT`, rate = −(`BMS_GET_BATTERY_CURRENT` × VBATT + 500) / 1000 | ADC `BATT_THERM`, `BATT_ID` | PMIC interrupt bits 8 and 12 clear, bit 24 set (read twice), and current between 0 and −50 mA, 3 times in a row |
| 4 | `{10542F20-…}` ADC | Estimated from the ADC `VBATT` (averaged with weight 1/3) between `MinVBattMV` and the maximum voltage − 50 mV, smoothed. Rate = +500 mA × nominal voltage when charging, 0 on line, −500 mA × nominal voltage on battery | ADC `BATT_THERM`, `BATT_ID` | percentage ≥ 100 |
| 5 | as 3 | as 3 | as 3 | Current ≤ 0 and \|current\| ≤ `WAEOCI` 3 times in a row |
| other | — | 75 %, voltage −1, rate 0x80000000 | 25 °C, 98 | never |

Gauges 3 and 5, on each change of charging phase (sub_405024):  
| Phase | Request to qcbms8930 |
|-------|----------------------|
| 0 (start) | `BMS_SET_SYSTEM_INFO` (`PMIC_THERM`, 1000 × temperature, battery id), then `BMS_SET_XOADC_CAL_VAL` (`V0P625`, `V1P25`) if the last one is more than 300 s old |
| 1 (not charging) | `BMS_SET_CHARGING_STATE` 1 |
| 2 (charging) | `BMS_SET_CHARGING_STATE` 0 |
| 3, 4 (no battery, test mode) | `BMS_SET_SYSTEM_INFO` (0x7FFFFFFF, 0x7FFFFFFF, 0) |
| 5 (charged) | `BMS_SET_CHARGING_STATE` 2 |
| 6 (not charging: timeout, thermal) | `BMS_SET_CHARGING_STATE` 3 |

When phases 3/4 are left, `BMS_FORCE_OCV` (which reconfigures the BMS) is sent first. Their heartbeat repeats `SET_SYSTEM_INFO` and the XOADC calibration. This matches the meaning of `SET_CHARGING_STATE` used by [NokiaEnergyDriver.sys](./nokiaenergydriver.md#charging-control): 0 = charging, 1 = not charging, 2 = charge complete.

The battery is considered valid (sub_407B48) when the battery id is 51–1499 and the temperature is 1–59 °C.

### State machine

The worker thread (sub_4063C8, priority 16) waits on 7 notification events (`.data:0x40B1A4`):  
| Index | Event | Set by | Action |
|-------|-------|--------|--------|
| 0 | `stru_417780` | Heartbeat timer (sub_405338), interrupts 2–4, `GET_CHARGER_STATUS` | Run the current state's periodic function, re-arm the heartbeat: `HeartBeatTimerChgOn` when on line, otherwise `HeartBeatTimerChgOffFast` if voltage ≤ `LowVBattMV`, `HeartBeatTimerChgOff` otherwise |
| 1 | `unk_4177C0` | Teardown | Thread exit |
| 2 | `stru_4177B0` | `TDoneVal` timer (sub_406384) | State 6 |
| 3 | `stru_4178D0` | Cable poll timer (sub_4052F4), interrupt 1, `CONTROL_CHARGING` | Charger detection (sub_406764): when the charger type or current changes, restart from state 0 |
| 4 | `stru_417900` | `SET_OPERATIONAL_MODE` 0 | State 8 |
| 5 | `stru_4178E0` | `SET_OPERATIONAL_MODE` 1 | State 0 |
| 6 | `stru_4177A0` | `SET_CHARGE_RATE` | State 9 if the maximum charge current (ACPI arg 14) < `ThermalLimit`, else periodic function. `SET_CHARGE_RATE` doesn't change that value, so state 9 is only reachable with a configuration where arg 14 < `ThermalLimit` ? |

After each event, the thread sends [IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS](#ioctl-0x800c0fa4--ioctl_pmic_batt_mini_notify_status) to the miniclass if a notification is pending (sub_4060DC).

State table (`.data:0x40B1C0`, 10 entries of 36 bytes: enter function, periodic function, low %, high %, mode, next state when low, next state when high, ?, flag). Current state in `dword_40B328`. While test mode is forced (`ForceTestMode` = 1) the machine stays in state 8.  
| State | Enter | Periodic | Power state | Description |
|-------|-------|----------|-------------|-------------|
| 0 | sub_406EE8 | sub_406F78 | — | Start. Phase 0. Test mode → 8, invalid battery → 7, no charger → 1, charger → 3 |
| 1 | sub_407088 | sub_4078C0 | `DISCHARGING` (2) | Not charging, phase 1 |
| 2 | (none) | sub_4078C0 | — | Unused (mode 3 → state 3) |
| 3 | sub_407138 | sub_4078C0 | `ON_LINE` + `CHARGING` (5) | Charging, phase 2, current = maximum × charge-rate %. Starts the `TDoneVal` timer. ≥ 92 % → 4 |
| 4 | sub_407220 | sub_4078C0 | 5 | Charging, maximum voltage. End of charge detected → 5, < 90 % → 3 |
| 5 | sub_407300 | sub_4078C0 | `ON_LINE` (1) | Charged, phase 5, charger off. ≤ 99 % → 4 |
| 6 | sub_4073B8 | sub_4078C0 | 1 | Charging time exceeded, phase 6. ≤ 80 % → 0 |
| 7 | sub_407510 | sub_407470 | 1 or 2 | Missing/invalid battery, phase 3: reports 100 %, 4155 mV, rate 0. Valid battery → 0 |
| 8 | sub_407618 | sub_40772C | 2 | Test mode, phase 4: charging off, reports 100 %, 4155 mV, rate 0 |
| 9 | sub_40776C | sub_40781C | 1 | Thermal: charging stopped, phase 6. Charge rate ≠ 0 → 0, invalid battery → 7 |

The generic periodic function (sub_4078C0) updates the charge current if the charge-rate % changed, reads percentage/voltage/rate from the gauge (capacity = % × FullChargedCapacity / 100), runs the gauge and charger heartbeat functions, then applies the transitions of the table. A notification is queued when the capacity leaves the window set by `SET_STATUS_NOTIFICATION_CRITERIA`, or when it falls below `DefaultAlert1`. Below `DefaultAlert1` the `BATTERY_CRITICAL` flag (8) is also set.

### Requests to the peer drivers

Two helpers build the IRPs with `IoBuildDeviceIoControlRequest` (not internal):
* `PmicSendDriverRequest` (sub_40861C) → `PmicSendDriverRequestWithTimeout` (sub_4086B0): waits **without** a timeout despite the name. Used by chargers 1 and 3.
* `PmicSendDriverRequestWithDebugBreakTimeOut` (sub_408910): waits 5 s, writes a trace, then waits again without a timeout. Used by everything else.

Sent to [qcpmic8930.sys](./qcpmic8930.md) charger `{1CF4643A-…}` (layouts in [qcpmic8930.sys](./qcpmic8930.md); `00-03` is the PMIC index, always 0):  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Values |
|-------|------|------------------|-------------------|--------|
| 0x80080FA8 | IOCTL_PM_CHG_PARAMS | 28 | 4 | See charger 2 |
| 0x80080FAC | IOCTL_PM_CHG_GET_STATE | 4 | 16 | `04-07` state (7 = regulation check), bytes `08`, `09` = charger present |
| 0x80080FB0 | IOCTL_PM_CHG_FSM_ENABLE | 16 | 4 | `04` enable, `08` byte, `0C` 0 |
| 0x80080FB4 | IOCTL_PM_CHG_PET_WDOG | 8 | 4 | 30 |
| 0x80080FB8 | IOCTL_PM_CHG_CHGPATH_ENABLE | 8 | 4 | enable |
| 0x80080FBC | IOCTL_PM_CHG_BATTSAFE | 12 | 4 | 4225, 1500 |
| 0x80080FC0 | IOCTL_PM_CHG_VIN_MIN | 12 | 4 | `04` enable, `08` 4300 mV or 0 |
| 0x80080FC4 | IOCTL_PM_CHG_BATT_TEMP_CONFIG | 16 | 4 | zeros |
| 0x80080FC8 | IOCTL_PM_CHG_BATT_TEMP_CNTRL | 8 | 4 | 0 |
| 0x80080FCC | IOCTL_PM_CHG_VREF_BATT_THERM_CNTRL | 8 | 4 | 1 |
| 0x80080FD4 | IOCTL_PM_CHG_GET_REGULATION_LOOP | 4 | 8 | byte `01`, byte `03` |
| 0x80080FD8 | IOCTL_PM_CHG_FORCE_OVPFET_ON_OFF | 12 | 4 | `04` 0/1, `08` 0/1 |
| 0x80080FDC | IOCTL_PM_CHG_OVP_SET_DEBOUNCE_TIME | 12 | 4 | `04` 0/1, `08` 0 or 2 |

Sent to [qcpmic8930.sys](./qcpmic8930.md) interrupts `{9A8FF884-…}`:  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Values |
|-------|------|------------------|-------------------|--------|
| 0x80070FA8 | IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS | 24 | 16 | Block 0, 64-bit mask of one bit (8, 12, 24 or 27), type 1 (real-time) |

Sent to [qcbms8930.sys](./qcbms8930.md) `{23B7D0DD-…}`:  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Values |
|-------|------|------------------|-------------------|--------|
| 0x80180FA4 | IOCTL_BMS_GET_BATTERY_CURRENT | 0 | 4 | Rate, end of charge, charger 2 regulation |
| 0x80180FAC | IOCTL_BMS_GET_PERCENT_CHARGE | 0 | 4 | ‰ → (value + 5) / 10 %. When the last `SET_CHARGING_STATE` was 1 (not charging) and VBATT stays ≤ `MinVBattMV` over 2 readings, the value is capped at 50 ‰, then 40 ‰, … 0 on the following calls |
| 0x80180FB0 | IOCTL_BMS_SET_CHARGING_STATE | 4 | 0 | 0–3, see [Gauge back-ends](#gauge-back-ends) |
| 0x80180FB4 | IOCTL_BMS_SET_SYSTEM_INFO | 12 | 4 | `PMIC_THERM`, 1000 × °C, battery id |
| 0x80180FB8 | IOCTL_BMS_FORCE_OCV | 0 | 0 | |
| 0x80180FBC | IOCTL_BMS_SET_XOADC_CAL_VAL | 8 | 0 | `V0P625`, `V1P25` |

Sent to the ADC driver `{10542F20-…}`:  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Values |
|-------|------|------------------|-------------------|--------|
| 0x8ADC2000 | IOCTL_ADC_GET_CHANNEL | strlen + 1 (gauge 4: 6 or 11) | 8 | `VBATT`, `BATT_THERM`, `BATT_ID`, `PMIC_THERM`, `V0P625`, `V1P25` (`.rdata:0x409748`) |
| 0x8ADC2004 | IOCTL_ADC_READ | 4 | 20 | Value at `04-07` (signed 16 bits for gauge 4) |

Sent to the third-party drivers:  
| IOCTL | Name | Device name | InputBuffer size | OutputBuffer Size | Values |
|-------|------|-------------|------------------|-------------------|--------|
| 0x80160FA0 | IOCTL_PM_3P_CHG_CHARGE_BATTERY | `{3469F855-…}` | 4 | 4 | Charge current, mA (0 = stop). Output: error, must be 0 |
| 0x80160FA8 | IOCTL_PM_3P_CHG_GET_CHARGER_STATUS | `{3469F855-…}` | 0 | 8 | `00-03` charging state, `04-07` error. Dead code (sub_401D4C is never called) |
| 0x80090FA0 | IOCTL_PM_3P_GAUGE_GET_BATT_PERC | `{00E1078B-…}` | 0 | 1 | Percentage |

---

### IOCTL 0x800C0FA4 — IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS

This IOCTL is sent by Qcbattmngr8930.sys to [Qcbattminiclass8930.sys](./qcbattminiclass8930.md#ioctl-0x800c0fa4--ioctl_pmic_batt_mini_notify_status)

| Property | Value |
|----------|-------|
| Device | 0x800C |
| Function | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS | `{6C7FF145-…}` device | 0 | 0 |

Sent by sub_4060DC after a state-machine event, when a notification is pending (`byte_41773C`) and the miniclass device is open. On success, the next [GET_CHARGER_STATUS](#ioctl-0x800b0fa8--ioctl_batt_mngr_get_charger_status) doesn't wake the heartbeat (`byte_417720`).

---

### Received IOCTLs

`EvtIoDeviceControl` (0x406224) accepts only device type `0x800B`, otherwise `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). `ValidateBattMngrRequest` (sub_407E44) accepts the functions 1001–1010 (other → `STATUS_UNSUCCESSFUL` 0xC0000001). It checks the buffer lengths by **exact match** against the descriptor table at `.data:0x40B330` (10 entries of `0x10C` bytes, same format as in qcbattminiclass8930) with `ValidateParameters` (sub_4080DC): `STATUS_INVALID_PARAMETER_1`…`5` as in [qcbms8930.sys](./qcbms8930.md). The handler (sub_40590C) runs under the state lock, except `NOTIFY_MINICLASS_REMOVAL`.

The only expected caller is [qcbattminiclass8930.sys](./qcbattminiclass8930.md); the buffer layouts below match that page.

---

### IOCTL 0x800B0FA4 — IOCTL_BATT_MNGR_GET_BATTERY_ID

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_GET_BATTERY_ID | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `01 00 00 00` | Battery tag (`dword_416EE8`, initial value 1), or 0 when the battery is marked absent (`byte_416EEC` = 0) |

When ACPI arg 3 / `DefaultErrorBehavior` is ≠ 0, the states with a battery increment the tag on each return from "absent", and state 7 marks the battery absent. Otherwise the tag stays 1.

---

### IOCTL 0x800B0FA8 — IOCTL_BATT_MNGR_GET_CHARGER_STATUS

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EA (1002) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_GET_CHARGER_STATUS | 4 | 16 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag, ignored |

Outputbuffer (sub_405548):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `05 00 00 00` | PowerState (`dword_416F0C`): `ON_LINE` 1, `DISCHARGING` 2, `CHARGING` 4, `CRITICAL` 8 |
| 04-07 | ? | Capacity = % × FullChargedCapacity / 100 (initial value 0xFFFFFFFF) |
| 08-0B | ? | Voltage, mV (initial value 0xFFFFFFFF) |
| 0C-0F | ? | Rate (initial value 0x80000000, unknown) |

The data is returned even when the battery is marked absent, but then the status is `STATUS_NO_SUCH_DEVICE` (0xC000000E). Each call also wakes the heartbeat (event 0), except the first call after a notification.

---

### IOCTL 0x800B0FAC — IOCTL_BATT_MNGR_GET_BATTERY_INFO

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EB (1003) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_GET_BATTERY_INFO | 12 | 512 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag, ignored |
| 04-07 | 00 00 00 00 … 08 00 00 00 | InformationLevel |
| 08-0B | ? | AtRate, ignored |

Outputbuffer (sub_4055DC, zeroed then filled, always 512 bytes returned):  
| Level | Content (built-in defaults) |
|-------|-----------------------------|
| 0 `BatteryInformation` | `BATTERY_INFORMATION`: Capabilities 0x80000007 (`SYSTEM_BATTERY`, set charge/discharge/charging source supported ?), Technology 1, Chemistry `LION`, DesignedCapacity 3515, FullChargedCapacity 3515, DefaultAlert1 700, DefaultAlert2 350, CriticalBias 0, CycleCount 1 |
| 1 `BatteryGranularityInformation` | `00-03` 1, `04-07` current capacity |
| 2 `BatteryTemperature` | (100 × °C + 27315) / 10, in tenths of kelvin |
| 3 `BatteryEstimatedTime` | 0xFFFFFFFF (`BATTERY_UNKNOWN_TIME`); `dword_416F08` is never updated |
| 4 `BatteryDeviceName` | `QCOMBATT01` |
| 5 `BatteryManufactureDate` | Day 6, Month 30, Year 2011: day and month are swapped (30 June ?) |
| 6 `BatteryManufactureName` | `Qualcomm` |
| 7 `BatteryUniqueID` | `QCOMBAT01_07012011` |
| 8 `BatterySerialNumber` | `07012011` |
| other | `STATUS_INVALID_PARAMETER` (0xC000000D) |

The strings are UTF-16, copied with `wcscpy_s` (256 characters).

---

### IOCTL 0x800B0FB0 — IOCTL_BATT_MNGR_CONTROL_CHARGING

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EC (1004) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_CONTROL_CHARGING | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag, ignored |
| 04-07 | ? | `SetInformation` level |
| 08-0B | ? | Ignored |
| 0C-0F | ? | Level 3: `MaxCurrent` of the `BATTERY_CHARGING_SOURCE` |

Handler sub_4057B0:
* level 1 (`BatteryCharge`) or 2 (`BatteryDischarge`): wakes the charger detection (event 3) if `EnaBattcUSBI` is set;
* level 3 (`BatteryChargingSource`): if `EnaBattcUSBI` is set and `MaxCurrent` ≠ 0xFFFFFFFF, stores it as the charging-source current (`dword_416EB8`) and wakes the charger detection;
* any other level, including 0 (`BatteryCriticalBias`, which qcbattminiclass8930 always sends): `STATUS_NOT_SUPPORTED` (0xC00000BB).

---

### IOCTL 0x800B0FB4 — IOCTL_BATT_MNGR_SET_STATUS_NOTIFICATION_CRITERIA

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3ED (1005) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_SET_STATUS_NOTIFICATION_CRITERIA | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Battery tag, ignored |
| 04-07 | ? | PowerState, ignored |
| 08-0B | ? | LowCapacity (`dword_416EF8`) |
| 0C-0F | ? | HighCapacity (`dword_416EF4`) |

Enables the notification (`byte_416EF0` = 1): the periodic function queues a notification when the capacity is > HighCapacity or < LowCapacity.

---

### IOCTL 0x800B0FB8 — IOCTL_BATT_MNGR_DISABLE_STATUS_NOTIFICATION

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EE (1006) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_DISABLE_STATUS_NOTIFICATION | 0 | 0 |

Clears `byte_416EF0`. The low-capacity (`DefaultAlert1`) notification stays active.

---

### IOCTL 0x800B0FBC — IOCTL_BATT_MNGR_SET_OPERATIONAL_MODE

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3EF (1007) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_SET_OPERATIONAL_MODE | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `00 00 00 00` / `01 00 00 00` | Mode |

Handler sub_405868:
* 0: **test mode**. Sets `ForceTestMode` (`dword_416E2C`) = 1 and wakes event 4: state 8. Charging is off and the battery is reported as 100 %, 4155 mV. The machine stays in state 8 until mode 1.
* 1: **normal mode**. `ForceTestMode` = 0 and wakes event 5: state 0.
* other: `STATUS_INVALID_PARAMETER` (0xC000000D).

qcbattminiclass8930 sends mode 0 when battc gives a charging source with `MaxCurrent` = 0xFFFFFFFE, and mode 1 for any other charging source.

---

### IOCTL 0x800B0FC0 — IOCTL_BATT_MNGR_GET_CURRENT_STATE

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3F0 (1008) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_GET_CURRENT_STATE | 0 | 4 |

Returns `STATUS_SUCCESS` with 4 bytes, but **writes nothing** to the output buffer: the caller gets whatever the buffer already contained. The current state (`dword_40B328`) is never returned.

---

### IOCTL 0x800B0FC4 — IOCTL_BATT_MNGR_SET_CHARGE_RATE

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3F1 (1009) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_SET_CHARGE_RATE | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `64 00 00 00` | Charge rate, % (`dword_416EC8`, default 100) |

Sent by the `PassiveCooling` routine of qcbattminiclass8930. When the value changes, wakes event 6. The charge current becomes maximum charge current × % / 100 at the next periodic function. There's no range check.

---

### IOCTL 0x800B0FC8 — IOCTL_BATT_MNGR_NOTIFY_MINICLASS_REMOVAL

This IOCTL is processed by Qcbattmngr8930.sys

| Property | Value |
|----------|-------|
| Device | 0x800B |
| Function | 0x3F2 (1010) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATT_MNGR_NOTIFY_MINICLASS_REMOVAL | 0 | 0 |

sub_406060: unregisters the `{6C7FF145-…}` notification and releases the miniclass device. No more notifications are sent after this, even if the miniclass comes back, until the battery manager restarts.

---

### Interface GUID

Battery manager interface (created and enabled when the charger and gauge back-ends are complete)  
`{F4116444-4837-49A5-B2C7-433FE501F2AA}`

### Other GUID

qcbattminiclass8930 device interface (consumed)  
`{6C7FF145-BE42-4ED4-ADF1-2ECD06EF23B7}`

Third-party charger interface (consumed, provider unknown)  
`{3469F855-D4E1-4AD4-AA07-56BFE57E3BC3}`

Third-party gauge interface (consumed, provider unknown)  
`{00E1078B-CD2B-4E06-AB3A-DACD8AC7FEEB}`

`GUID_DEVICE_INTERFACE_ARRIVAL`  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`

`GUID_DEVICE_INTERFACE_REMOVAL`  
`{CB3A4005-46F0-11D0-B08F-00609713053F}`
