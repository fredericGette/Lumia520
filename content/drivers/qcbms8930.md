## Qcbms8930.sys

PMIC Battery Management System (BMS) / fuel-gauge driver.  
It provides the battery state-of-charge, voltage, current and charging-state control for Qualcomm MSM8930-class platforms. It exposes a set of `IOCTL_BMS_*` controls (device type `0x8018`) that are consumed by the Windows battery stack (`BATTC` → `NokiaEnergyDriver`), and it drives the actual PMIC fuel-gauge hardware through a companion "chip backend" device using `IOCTL_PM_GAUGE_*` controls (device type `0x8019`).  
On start it loads the battery profile — OCV/RBAT/FCC curves and charging limits — from the file `BATTERY.PROVISION` on the EFIESP partition, selected by the battery-ID resistor ADC reading.  
The state-of-charge is computed from a blend of coulomb counting and an OCV-vs-temperature-vs-SOC lookup, load-compensated with the battery internal resistance (Rbat), then temperature/aging-derated and slew-limited before being reported.

All `IOCTL_BMS_*` requests go through `PmicBmsIoctlDispatch` (function codes 1000–1008), which first validates each request's input/output buffer **lengths** by **exact match** against a per-IOCTL descriptor table (`PmicBmsValidateIoctlParams`). A size mismatch fails with `STATUS_INVALID_PARAMETER` (Win32 error 87) before the handler runs. The descriptor table is at `.data:0x004191A8`, 9 entries of `0x10C` bytes each: `+0x00` = IoControlCode, `+0x04` = UTF-16 name (`0x100` bytes), `+0x104` = expected InputBuffer size, `+0x108` = expected OutputBuffer size.

Note: two IOCTL names are misleading. `IOCTL_BMS_GET_BATTERY_CHARGING_PROFILE` does **not** return a profile — it triggers a hardware reconfigure — and `IOCTL_BMS_FORCE_OCV` is a **no-op stub** in this build. See the respective sections.

`BytesReturned` reported by the read handlers is unreliable (several report 4 regardless of the real payload); the authoritative output size is the descriptor's `+0x108` value.

GUID of the ETW provider:  
`?` (not identified in this analysis; the driver uses ETW via `g_TraceFlags` / `EventWrite_0x` stubs)

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ? | (companion PMIC gauge, "chip backend") | Reached via `IOCTL_PM_GAUGE_*` (`0x8019xxxx`); three companion device interfaces are awaited at bring-up before the chip is brought online |
| ? | (PMIC RTC) | Time source via `IOCTL_PM_RTC_GET_TIME` (`0x800A0FA8`) |
| ? | NokiaEnergyDriver / BATTC | Consumer of the `IOCTL_BMS_*` controls below (observed caller) |

---

### IOCTL 0x80180FA0 — IOCTL_BMS_GET_BATTERY_CHARGING_PROFILE  *(misnamed)*

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_GET_BATTERY_CHARGING_PROFILE | PmicBmsReconfigure (sub_401008) | 4 | 16 |

Despite the name, this returns no charging-profile data. The backend is `PmicBmsReconfigure`: it writes `0` to the first output dword (`BytesReturned` = 4), ignores the input, and **side-effects a hardware reconfigure of the BMS block** (clear config → 70 ms delay → apply config mode 11,2,2,6). It must not be polled. The real charging limits live in `BATTERY.PROVISION` (`VBAT_MAX`, `IBAT_MAX`, `FCC`).

---

### IOCTL 0x80180FA4 — IOCTL_BMS_GET_BATTERY_CURRENT

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_GET_BATTERY_CURRENT | ReadCalibratedCurrentSeed-style getter (off_42C8B0) | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `92 FE FF FF` | Battery current, signed mA. Negative = discharge (e.g. −302 mA), positive = charge. |

Polled very frequently by the platform (coulomb counting, IR-drop/OCV compensation, charge regulation) — this is normal.

---

### IOCTL 0x80180FA8 — IOCTL_BMS_GET_BATTERY_VOLTAGE

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EA (1002) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_GET_BATTERY_VOLTAGE | PmicBmsIoctlGetBatteryVoltage (sub_42E040) | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `4E 05 00 00` | Selector-6 converted ADC reading — the VBAT value **at the ADC pin, before the divider**, in mV-scale. NOT the terminal voltage. |

The backend calls `ReadOutputRegConverted(BmsId=0, Selector=6)`. Observed value 1358 ≈ VBAT/divider; with a ~3× VBAT sense divider that is ~4.07 V terminal. Multiply by the board divider to recover terminal mV. Same unit as the XOADC 0.625 V / 1.25 V references.

---

### IOCTL 0x80180FAC — IOCTL_BMS_GET_PERCENT_CHARGE

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EB (1003) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_GET_PERCENT_CHARGE | PmicBmsIoctlGetPercentCharge (off_42C8B4) | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `34 03 00 00` | Raw internal state-of-charge in **per-mille** (0–1000). 820 = 82.0 %. |

This is the raw gauge SOC, not the UI figure. The OS/battery-miniclass remaps it through the profile usable window (top/bottom reserve): raw 82 % was displayed as 91 % on-screen (≈0.90 top-reserve ratio). The value is throttled (recompute ~once per session) and slew-limited.

---

### IOCTL 0x80180FB0 — IOCTL_BMS_SET_CHARGING_STATE

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EC (1004) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_SET_CHARGING_STATE | PmicBmsIoctlSetChargingState (sub_42E060) | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | NewChargingState: 0 = not charging/idle, 1 = charging, 2 = charge-complete / nominal-current rescale |

Forwards the new state to the companion PMIC (`IOCTL_PM_GAUGE_BMS_SET_CHARGING_STATE` 0x80190FC8); starts/stops the SOC-correction timer and rescales the nominal current on entry to state 2. (Sizes handler-inferred; not yet descriptor-dumped.)

---

### IOCTL 0x80180FB4 — IOCTL_BMS_SET_SYSTEM_INFO

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3ED (1005) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_SET_SYSTEM_INFO | PmicBmsIoctlSetSystemInfo (off_42C8A8) | 12 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `CC C6 00 00` | Timestamp — monotonic seconds-like counter |
| 04-07 | e.g. `40 9C 00 00` | Temperature in **milli-degrees-C** (40000 = 40.0 °C); indexes the OCV/FCC/RBAT temperature axes |
| 08-0B | e.g. `7E 03 00 00` | BatteryId — battery-ID **resistor ADC reading** (not a serial); matched against the profile's `BATTERY_ADC_MIN/MAX` to select the battery profile |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | echoes Timestamp | Result (LONG); METHOD_BUFFERED shares one buffer for in and out |

Stores the temperature index (`dword_419150`), detects battery removal / timestamp jumps, and re-triggers `PmicBmsLoadBatteryProvisioningData` if the battery ID leaves the profile's ADC window.

---

### IOCTL 0x80180FB8 — IOCTL_BMS_FORCE_OCV  *(no-op stub)*

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EE (1006) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_FORCE_OCV | PmicBmsIoctlGetConstant4 (sub_42E020) | 0 | 0 |

Backed by the constant-stub handler, which only sets `*BytesReturned = 4` (no data) and returns `STATUS_SUCCESS`. With `out=0` this IOCTL does nothing observable — it does **not** force an OCV. The real forced-OCV measurement lives in `PmicBmsForceOcvMeasurement` (sub_4028C4) / `PmicBmsForceOcvAndUpdateCapacity` (sub_403D30), invoked internally by the SOC estimator and timers, not through this IOCTL.

---

### IOCTL 0x80180FBC — IOCTL_BMS_SET_XOADC_CAL_VAL

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EF (1007) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_SET_XOADC_CAL_VAL | PmicBmsIoctlSetXoadcCalVal (sub_42E080) | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `48 79 00 00` | RawPointA — raw ADC code for the XOADC 0.625 V reference (converts ≈ 632) |
| 04-07 | e.g. `30 92 00 00` | RawPointB — raw ADC code for the XOADC 1.25 V reference (converts ≈ 1255) |

Loads the two-point ADC calibration anchors (stored to `dword_42C924` / `dword_42C8DC`); subsequent readings are remapped through `PmicBmsRemapViaTwoPointCalibration` to cancel ADC offset/gain error. Observed caller: `NokiaEnergyDriver` via `BATTC` at init.

---

### IOCTL 0x80180FC0 — IOCTL_BMS_GET_INTERNAL_CALC

This IOCTL is received by qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3F0 (1008) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Backend | InputBuffer size | OutputBuffer Size |
|------|---------|------------------|-------------------|
| IOCTL_BMS_GET_INTERNAL_CALC | PmicBmsIoctlGetInternalCalc (sub_42E098) | 0 | 12 |

Outputbuffer (three dwords; `BytesReturned` misreports 4, but the descriptor requires a **12-byte** buffer):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | DeratedFullChargeCapacity (`dword_42C8D8`) |
| 04-07 | ? | RemainingChargeReference (`dword_42C8D4`) |
| 08-0B | ? | RemainingChargeHeadroom (`dword_42C91C`) |

---

### Outbound IOCTLs (sent by qcbms8930.sys to the companion PMIC gauge / RTC)

Device type `0x8019` (PMIC gauge) and `0x800A` (RTC). Reached through `PmicBmsSendIoctlToDevice`.

| IOCTL | Name | Comment |
|-------|------|---------|
| 0x80190FD0 | IOCTL_PM_GAUGE_BMS_CONFIGURE | Configure/clear the BMS block |
| 0x80190FC4 | IOCTL_PM_GAUGE_BMS_OVERRIDE_VBAT_MODE | Engage/disengage VBAT-override sampling |
| 0x80190FA4 | IOCTL_PM_GAUGE_READ_BMS_OUTPUT_REG_BMS | Read a BMS output register (selector/mode in input) |
| 0x80190FC8 | IOCTL_PM_GAUGE_BMS_SET_CHARGING_STATE | Forward charging-state changes |
| 0x80190FAC | IOCTL_PM_GAUGE_ENABLE_BMS | Enable the BMS block |
| 0x80190FA8 | IOCTL_PM_GAUGE_CALIBRATE_BMS | Calibration step |
| 0x800A0FA8 | IOCTL_PM_RTC_GET_TIME | Read the PMIC RTC (shared time source) |

---

### Battery provisioning

At bring-up the driver parses `BATTERY.PROVISION` (EFIESP partition, INI-style) via `PmicBmsLoadBatteryProvisioningData` (sub_4019A8). The unit analysed carries the Nokia **BL-5J** profile. Key fields and their runtime use:

| File key | Runtime use |
|----------|-------------|
| `BATTERY_ADC_MIN` / `MAX` (0 / 2000) | Valid ID-resistor ADC window; matched vs the `SET_SYSTEM_INFO` BatteryId reading to select the profile |
| `FCC` (1430 mAh) | Base full-charge capacity → derated into `dword_42C8D8` |
| `VBAT_MAX` / `IBAT_MAX` (4200 mV / 950 mA) | Actual charging limits (the real "charging profile") |
| `FCC_vs_TEMP[]` / `FCC_vs_CYCLES[]` | Capacity deration by temperature and aging cycles |
| `OCV_vs_TEMP_vs_SOC[]` | Primary OCV/capacity curve → `dword_425778` (temps −20…70 °C × SOC 100…0 %) |
| `CORRECTION_vs_CYCLES_vs_SOC[]` | SOC correction-factor table |
| `RBAT_NOM` (185 mΩ) / `RBAT_VS_TEMP_VS_SOC[]` | Internal resistance for IR-drop compensation: `OCV ≈ Vterm + I·Rbat(SOC,T)` |

---

### Interface GUID

The driver publishes a device interface consumed by the battery stack; the specific GUIDs were not captured in this analysis.

| Item | GUID |
|------|------|
| qcbms8930 device interface | `?` (not identified) |
| Companion PMIC gauge interface | `?` (not identified) |
