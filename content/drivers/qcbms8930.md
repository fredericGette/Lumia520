## Qcbms8930.sys

PMIC Battery Management System (BMS) / fuel-gauge driver.  
It provides the battery state-of-charge, voltage, current and charging-state control for Qualcomm MSM8930-class platforms. It exposes a set of `IOCTL_BMS_*` controls (device type `0x8018`) that are consumed by the Windows battery stack (`BATTC` → `NokiaEnergyDriver`), and it drives the actual PMIC fuel-gauge hardware through a companion PMIC device using `IOCTL_PM_GAUGE_*` (device type `0x8019`) and `IOCTL_PM_CCADC_*` (device type `0x8002`) controls.  
The battery profile — OCV/RBAT/FCC curves and charging limits — is loaded from the file `BATTERY.PROVISION` on the EFIESP partition, and is (re)selected by the battery-ID resistor ADC reading received through `IOCTL_BMS_SET_SYSTEM_INFO`.  
The state-of-charge is computed from a blend of coulomb counting and an OCV-vs-temperature-vs-SOC lookup, load-compensated with the battery internal resistance (Rbat), then temperature/aging-derated and slew-limited before being reported. The coulomb accumulator is persisted in a UEFI variable.

Symbolic link : `\DosDevices\Global\QCOMPMICBMS`  
There's no named `\Device\` object (the WDF device is unnamed; only the symbolic link is created).

All `IOCTL_BMS_*` requests go through `EvtWdfIoQueueIoDeviceControl` (rejects any code whose upper 16 bits are not `0x8018` with `STATUS_INVALID_DEVICE_REQUEST`) and `PmicBmsIoctlDispatch` (function codes 1000–1008). The dispatcher first validates each request's input/output buffer **lengths** by **exact match** against a per-IOCTL descriptor table (`PmicBmsValidateIoctlParams`). The descriptor table is at `.data:0x004191A8`, 9 entries of `0x10C` bytes each: `+0x00` = IoControlCode, `+0x04` = UTF-16 name (`0x100` bytes), `+0x104` = expected InputBuffer size, `+0x108` = expected OutputBuffer size.

NTSTATUS returned by the validation:
| Value | Comment |
|-------|---------|
| 0xC00000EF STATUS_INVALID_PARAMETER_1 | No descriptor |
| 0xC00000F0 STATUS_INVALID_PARAMETER_2 | InputBuffer is NULL but the descriptor expects input |
| 0xC00000F1 STATUS_INVALID_PARAMETER_3 | InputBufferLength ≠ descriptor `+0x104` |
| 0xC00000F2 STATUS_INVALID_PARAMETER_4 | OutputBuffer is NULL but the descriptor expects output |
| 0xC00000F3 STATUS_INVALID_PARAMETER_5 | OutputBufferLength ≠ descriptor `+0x108` |
| 0xC0000001 STATUS_UNSUCCESSFUL | Function code outside 1000–1008 |

All of them map to Win32 error 87 (`ERROR_INVALID_PARAMETER`) in user mode.

> [!NOTE]
> The handlers run under a wait-lock that is only created once the three companion PMIC interfaces have arrived (`PmicBmsOnAllDependenciesReady`). Before that, a correctly-sized request completes with `STATUS_SUCCESS` and 0 bytes returned **without running any handler**.

Note: two IOCTL names are misleading. `IOCTL_BMS_GET_BATTERY_CHARGING_PROFILE` is a **no-op stub** and `IOCTL_BMS_FORCE_OCV` does not force an OCV — it triggers a **hardware reconfigure** of the BMS block. See the respective sections.

`BytesReturned` reported by the read handlers is unreliable (several report 4 regardless of the real payload); the authoritative output size is the descriptor's `+0x108` value.

Registry values, read with `ZwOpenKey`/`ZwQueryValueKey` from the driver's **service key** (`WdfDriverGetRegistryPath`, i.e. `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>` — not the `Parameters` subkey). All are `REG_DWORD`; a missing value or a value outside the accepted range keeps the default.  
| Registry value | value | comment |
|----------------|-------|---------|
| OverwriteSenseResistor | 0 | Boolean. When 1, `SenseResistorMicroOhms` replaces the sense-resistor value from ACPI `PMCF` |
| SenseResistorMicroOhms | ? | Battery current-sense resistor in µΩ (only with `OverwriteSenseResistor`=1) |
| S1VsenseThrUV | 100100 | BMS state-1 Vsense threshold in µV, sent in `IOCTL_PM_GAUGE_BMS_CONFIGURE` |
| S2VsenseThrUV | 45100 | BMS state-2 Vsense threshold in µV (accepted range 25000–100100) |
| S3VsenseThrUV | 25000 | BMS state-3 Vsense threshold in µV |
| ResetChargeCycle | 0 | When 1, the persisted coulomb accumulator is zeroed at start and written back to the UEFI variable |
| MaxOCVIncrease | 3000 | ? |
| DisableSocCorrection | 0 | Boolean. Disables the periodic SOC-correction timer |
| SocCorrectionTimer | 120 | SOC-correction period in seconds. <20 → 0 (disabled), >120 → 120 |
| FastCorrectionTimer | 40 | Fast SOC-correction period in seconds (accepted range 20–60) |
| FastCorrectionSOC | 100 | SOC threshold below which the fast correction period is used (accepted range 1–250, unit ?) |
| VCutoffMV | 3300 | Cut-off voltage in mV (accepted range 3000–3700) |
| MinValidOCVInMV | 3000 | Minimum OCV accepted as valid, in mV (accepted range 1–3700) |
| UseRbatTableInOCVEst | 0 | Boolean. Use the `RBAT_VS_TEMP_VS_SOC` table in the OCV estimation |

`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ProductOptions`:  
| Registry value | value | comment |
|----------------|-------|---------|
| ProductSuite | `PhoneNT` | REG_MULTI_SZ. When it contains `PhoneNT`, `BATTERY.PROVISION` is read as a file from the EFIESP partition; otherwise it's read from raw disk blocks (see [Battery provisioning](#battery-provisioning)) |

UEFI variable (read with `ExGetFirmwareEnvironmentVariable`, written with `ExSetFirmwareEnvironmentVariable`, attribute NON_VOLATILE):  
| Name | Vendor GUID | Size | Comment |
|------|-------------|------|---------|
| BmsDataVariables | `{882F8C2B-9646-435F-8DE5-F208FF80C1BD}` | 28 | Persisted coulomb accumulator. Written every 30 minutes, on charging-state change, and on D0 exit |

Content of `BmsDataVariables` as written by `PmicBmsUpdateAndPersistAccumulator` (sub_401F3C):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Valid marker |
| 04-07 | ? | Current PMIC RTC time (`IOCTL_PM_RTC_GET_TIME`) |
| 08-0B | ? | Reference value at the previous update (`g_FastCorrectionSocThreshold` in the IDB) ? |
| 0C-0F | ? | Coulomb accumulator (`dword_42C92C`) |
| 10-13 | ? | `dword_42C938` / 1000 |
| 14-17 | ? | `dword_4254D0` |
| 18-1B | ? | `dword_42C8E0` (flags/status ?) |

ACPI: at `EvtDevicePrepareHardware` the driver evaluates the method `PMCF` on its ACPI node (`IOCTL_ACPI_EVAL_METHOD` 0x32C004, no arguments). It expects a package of 7 integers, stored in the device context at `+0x04`…`+0x1C`:  
| Index | Comment |
|-------|---------|
| 0 | Sense resistor in µΩ (overridable by the registry) |
| 1 | ? |
| 2 | ? |
| 3 | PMIC/BMS instance id — first dword of every `IOCTL_PM_CCADC_*` input and of the configure calls of `PmicBmsReconfigure` |
| 4 | ? (copied to the BMS config header, used as the id in `IOCTL_PM_GAUGE_BMS_CONFIGURE` at chip init) |
| 5 | ? |
| 6 | ? |

GUID of the ETW provider:  
None. `EtwWrite` is called with a `RegHandle` of 0 (the driver never calls `EtwRegister`) and the trace-flag word `g_TraceFlags` is never set, so the `EventWrite_0x` tracing is dead code.

It communicates with the following devices (all found with `IoRegisterPlugPlayNotification` on their interface class, then opened with `IoGetDeviceObjectPointer`):  
| Interface class GUID | Driver | Comment |
|----------------------|--------|---------|
| `{D17B2593-7189-4E1E-91F1-00798E07B8AB}` | ? (PMIC driver) | Primary companion. Target of all `IOCTL_PM_GAUGE_*` (`0x8019xxxx`) and `IOCTL_PM_CCADC_*` (`0x8002xxxx`) requests. Its removal stops the BMS and disables this driver's interface |
| `{61630799-922A-4980-99D9-90C39084A979}` | ? (PMIC RTC) | Time source via `IOCTL_PM_RTC_GET_TIME` (`0x800A0FA8`) |
| `{A942B3D9-EC95-4754-AE45-49C48735B893}` | ? | Only awaited: its arrival sets a flag, no IOCTL is sent to it |
| ACPI node of the device | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` `PMCF` |
| `\Device\Harddisk0`…`5` | disk.sys | `IOCTL_DISK_GET_DRIVE_LAYOUT_EX` (0x70050) to find the EFIESP partition |
| — | NokiaEnergyDriver / BATTC | Consumer of the `IOCTL_BMS_*` controls below (observed caller) |

When all three companion interfaces are present, the driver brings the chip online (`PmicBmsProbeAndInitializeChip`: `IOCTL_PM_GAUGE_BMS_CONFIGURE`, CCADC init, `IOCTL_PM_GAUGE_ENABLE_BMS`), loads the persisted accumulator, reads the registry values, starts the 30-minute accumulator timer, then publishes its own device interface.

> [!NOTE]
> The surprise-removal callback (sub_42E46C) calls `KeBugCheckEx(0x14E, 0x51706230 'Qpb0', 0, 0, 0)`: removing the device crashes the phone.

---

### IOCTL 0x80180FA0 — IOCTL_BMS_GET_BATTERY_CHARGING_PROFILE  *(no-op stub)*

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_GET_BATTERY_CHARGING_PROFILE | 4 | 16 |

Backend: `PmicBmsIoctlGetConstant4` (sub_42E020, jump-table case 0 at 0x401138). It only sets `BytesReturned` = 4 and returns `STATUS_SUCCESS`; the input is ignored and nothing is written to the output buffer. Despite the name, no charging profile is returned. The real charging limits live in `BATTERY.PROVISION` (`VBAT_MAX`, `IBAT_MAX`, `FCC`).

---

### IOCTL 0x80180FA4 — IOCTL_BMS_GET_BATTERY_CURRENT

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_GET_BATTERY_CURRENT | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `92 FE FF FF` | Battery current, signed mA. Negative = discharge (e.g. −302 mA), positive = charge. |

Backend: `PmicBmsReadCalibratedCurrentSeed` (sub_402C44, via `pPmicBmsReadCalibratedCurrentSeed`). It reads BMS output register selector 5 (`IOCTL_PM_GAUGE_READ_BMS_OUTPUT_REG_BMS`), takes the signed low 16 bits, and scales them by the sense resistor (`dword_419198`, default 10000) and the CCADC gain (`g_CurrentGainScale`, default 1000).  
Polled very frequently by the platform (coulomb counting, IR-drop/OCV compensation, charge regulation) — this is normal.

---

### IOCTL 0x80180FA8 — IOCTL_BMS_GET_BATTERY_VOLTAGE

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EA (1002) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_GET_BATTERY_VOLTAGE | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `4E 05 00 00` | Selector-6 converted ADC reading — the VBAT value **at the ADC pin, before the divider**, in mV-scale. NOT the terminal voltage. |

Backend: `PmicBmsIoctlGetBatteryVoltage` (sub_42E040) → `PmicBmsReadOutputRegConverted(0, 6)` (sub_402A68). Each call runs a full measurement sequence on the PMIC: `IOCTL_PM_GAUGE_BMS_CONFIGURE` → VBAT override on (`IOCTL_PM_GAUGE_BMS_OVERRIDE_VBAT_MODE`) → read → **40 ms delay** → read → override off → configure back to mode 11. Conversion: `((max(raw − 0x6000, 0) × 1000 / 1024) + 5) / 10`.  
Observed value 1358 ≈ VBAT/divider; with a ~3× VBAT sense divider that is ~4.07 V terminal. Multiply by the board divider to recover terminal mV. Same unit as the XOADC 0.625 V / 1.25 V references.

---

### IOCTL 0x80180FAC — IOCTL_BMS_GET_PERCENT_CHARGE

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EB (1003) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_GET_PERCENT_CHARGE | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `34 03 00 00` | Raw internal state-of-charge in **per-mille** (0–1000). 820 = 82.0 %. |

Backend: `PmicBmsIoctlGetPercentCharge` (sub_402F14). The dispatcher clamps the result to 1000. While charging (state 1) with SOC correction enabled, the first call computes the SOC and arms the SOC-correction timer; later calls return the value cached by that timer instead of recomputing it. Otherwise the SOC is recomputed by `PmicBmsEstimateAndRateLimitSoc` (slew-limited). With no battery profile loaded the SOC is −1 and the call fails.  
This is the raw gauge SOC, not the UI figure. The OS/battery-miniclass remaps it through the profile usable window (top/bottom reserve): raw 82 % was displayed as 91 % on-screen (≈0.90 top-reserve ratio).

---

### IOCTL 0x80180FB0 — IOCTL_BMS_SET_CHARGING_STATE

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EC (1004) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_SET_CHARGING_STATE | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | NewChargingState: 0 = not charging/idle, 1 = charging, 2 = charge-complete / nominal-current rescale |

Backend: `PmicBmsIoctlSetChargingState` (sub_42E060) → `PmicBmsSetChargingState` (sub_402F78). When leaving state 1 it stops the SOC-correction timer; when entering state 1 it arms it. When leaving state 0 it reloads and persists the accumulator (`BmsDataVariables`). On entry to state 2 it rescales `dword_4254D0`. Finally it forwards the state to the companion PMIC with `IOCTL_PM_GAUGE_BMS_SET_CHARGING_STATE` (0x80190FC8); the byte flag in that request is 1 only for state 0.

---

### IOCTL 0x80180FB4 — IOCTL_BMS_SET_SYSTEM_INFO

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3ED (1005) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_SET_SYSTEM_INFO | 12 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `CC C6 00 00` | PMIC die temperature in milli-degrees-C ? (50892). Not a timestamp: a change of more than 5000 (5 °C) since the last CCADC calibration, or 5 minutes elapsed, restarts the CCADC calibration |
| 04-07 | e.g. `40 9C 00 00` | Battery temperature in **milli-degrees-C** (40000 = 40.0 °C); indexes the OCV/FCC/RBAT temperature axes (`dword_419150`) |
| 08-0B | e.g. `7E 03 00 00` | BatteryId — battery-ID **resistor ADC reading** (not a serial); matched against the profile's `BATTERY_ADC_MIN/MAX` to select the battery profile. 0 = battery removed |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Result (LONG): 1 = battery removed (BatteryId = 0), 2 = same battery, no re-provisioning, otherwise the status of `PmicBmsLoadBatteryProvisioningData` (0 = profile loaded). Not written when nothing changed — METHOD_BUFFERED shares one buffer for in and out, so the first input dword is then echoed back |

Backend: `PmicBmsIoctlSetSystemInfo` (sub_402718, via `pPmicBmsIoctlSetSystemInfo`). The battery profile is reloaded when no battery is provisioned yet, or when the new BatteryId differs by more than ±10 % (`dword_419148` = 100 ‰) from the provisioned one and is outside the profile's ADC window. If loading `BATTERY.PROVISION` fails, a hardcoded profile is copied instead (see [Battery provisioning](#battery-provisioning)).

---

### IOCTL 0x80180FB8 — IOCTL_BMS_FORCE_OCV  *(misnamed: reconfigures the BMS)*

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EE (1006) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_FORCE_OCV | 0 | 0 |

Backend: `PmicBmsReconfigure` (sub_401008, jump-table case 24 at 0x4011D2). It sets `BytesReturned` = 0 and **side-effects a hardware reconfigure of the BMS block**: `IOCTL_PM_GAUGE_BMS_CONFIGURE` (id, 0,0,0,0,−1,−1,−1,−1) → 70 ms delay → `IOCTL_PM_GAUGE_BMS_CONFIGURE` (id, 11,2,2,6,−1,−1,−1,−1). It does not take an OCV reading and returns no data; it must not be polled. The real forced-OCV measurement lives in `PmicBmsForceOcvMeasurement` (sub_4028C4) / `PmicBmsForceOcvAndUpdateCapacity` (sub_403D30), invoked internally by the SOC estimator and timers.

---

### IOCTL 0x80180FBC — IOCTL_BMS_SET_XOADC_CAL_VAL

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3EF (1007) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_SET_XOADC_CAL_VAL | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `48 79 00 00` | RawPointA — raw ADC code for the XOADC 0.625 V reference (converts to 632) |
| 04-07 | e.g. `30 92 00 00` | RawPointB — raw ADC code for the XOADC 1.25 V reference (converts to 1255) |

Backend: `PmicBmsIoctlSetXoadcCalVal` (sub_42E080) → `PmicBmsSetXoadcCalibration` (sub_4030F0). Each point is converted with `(1000 × (raw − 0x6000) + 5120) / 10240` and stored to `dword_42C924` / `dword_42C8DC`; subsequent readings are remapped through `PmicBmsRemapViaTwoPointCalibration` to cancel ADC offset/gain error. Observed caller: `NokiaEnergyDriver` via `BATTC` at init.

---

### IOCTL 0x80180FC0 — IOCTL_BMS_GET_INTERNAL_CALC

This IOCTL is processed by Qcbms8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8018 |
| Function | 0x3F0 (1008) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BMS_GET_INTERNAL_CALC | 0 | 12 |

Backend: `PmicBmsIoctlGetInternalCalc` (sub_42E098) → `PmicBmsGetInternalCalc` (sub_40313C).

Outputbuffer (three dwords; `BytesReturned` misreports 4, but the descriptor requires a **12-byte** buffer):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | DeratedFullChargeCapacity (`dword_42C8D8`) |
| 04-07 | ? | RemainingChargeReference (`dword_42C8D4`) |
| 08-0B | ? | RemainingChargeHeadroom (`dword_42C91C`) |

---

### Outbound IOCTLs (sent by qcbms8930.sys to the companion PMIC devices)

All are sent synchronously through `PmicBmsSendIoctlToDevice` (`IoBuildDeviceIoControlRequest`, with a timeout and `IoCancelIrp`). All use METHOD_BUFFERED / FILE_ANY_ACCESS. The first input dword is always the PMIC/BMS instance id.

Sent to the `{D17B2593-…}` device, PMIC gauge (device type `0x8019`):  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x80190FD0 | IOCTL_PM_GAUGE_BMS_CONFIGURE | 36 | 4 | 9 dwords: id, mode, 3 parameters, 4 thresholds (−1 = unchanged). At init the thresholds carry `S1/S2/S3VsenseThrUV` scaled to bytes |
| 0x80190FAC | IOCTL_PM_GAUGE_ENABLE_BMS | 8 | 4 | id, enable = 1 |
| 0x80190FA4 | IOCTL_PM_GAUGE_READ_BMS_OUTPUT_REG_BMS | 8 | 8 | id, selector (4 = raw register, 5 = current, 6 = VBAT) |
| 0x80190FC4 | IOCTL_PM_GAUGE_BMS_OVERRIDE_VBAT_MODE | 8 | 4 | id, 2 byte flags (1,1 = on / 0,0 = off) |
| 0x80190FC8 | IOCTL_PM_GAUGE_BMS_SET_CHARGING_STATE | 8 | 4 | id, byte flag (1 when the new state is 0) |
| 0x80190FA8 | IOCTL_PM_GAUGE_CALIBRATE_BMS | 8 | 4 | Calibration step |

Sent to the `{D17B2593-…}` device, CCADC (coulomb-counter ADC, device type `0x8002`):  
| IOCTL | Name | InputBuffer size | OutputBuffer Size |
|-------|------|------------------|-------------------|
| 0x80021000 | IOCTL_PM_CCADC_READ_DATA | 4 | 8 |
| 0x80021004 | IOCTL_PM_CCADC_SET_ENABLE | 8 | 4 |
| 0x80021008 | IOCTL_PM_CCADC_REQUEST_CONVERSION | 4 | 4 |
| 0x8002100C | IOCTL_PM_CCADC_SET_DECIMATION_RATIO | 8 | 4 |
| 0x80021010 | IOCTL_PM_CCADC_SET_CONVERSION_RATE | 8 | 4 |
| 0x80021014 | IOCTL_PM_CCADC_CONNECT_RSENSE | 8 | 4 |
| 0x80021018 | IOCTL_PM_CCADC_CONFIGURE_OFFSET | 8 | 4 |
| 0x8002101C | IOCTL_PM_CCADC_CONFIGURE_GAIN | 8 | 4 |
| 0x80021020 | IOCTL_PM_CCADC_SET_OFFSET_TRIM | 8 | 4 |
| 0x80021024 | IOCTL_PM_CCADC_GET_CONVERSION_STATUS | 4 | 8 |
| 0x80021030 | IOCTL_PM_CCADC_SET_SEL_SHIFT | 8 | 4 |

Sent to the `{61630799-…}` device, PMIC RTC (device type `0x800A`):  
| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x800A0FA8 | IOCTL_PM_RTC_GET_TIME | 4 | 8 | Time source for elapsed-time and accumulator computations; first output dword = time |

The binary also contains a table of ~190 PMIC IOCTL names (`IOCTL_PM_*`, `IOCTL_BATT_MNGR_*`, `IOCTL_PMIC_BATT_MINI_*` at `.data:0x00419B20`–`0x00424B50`) with their codes, used only by `PmicIoctlCodeToTraceName` for tracing. It's a useful code ↔ name reference for the other Qualcomm PMIC drivers.

---

### Battery provisioning

The profile is parsed by `PmicBmsLoadBatteryProvisioningData` (sub_4019A8) from a buffer of less than 64 KB. Where it is read from depends on `ProductSuite`:

* `PhoneNT` present (Windows Phone): the file `\Device\HarddiskN\PartitionM\BATTERY.PROVISION`, where the partition is the first GPT partition named `EFIESP` found on `Harddisk0`…`5` (`PmicBmsFindEspPartitionPath`).
* Otherwise: a record named `QCOM` / `BATTERY.PROVISION` (type 1) found in a directory table of 0x400-byte entries read from raw disk blocks (`PmicBmsLoadAlternateProvisioningData`). Details ?

If loading fails, one of two hardcoded profiles (29564 bytes each, at `.rdata:0x004091A8`) is copied instead: `Hardcoded Profile for LIQUID 8960` or `Hardcoded Profile for FLUID 8960`. The choice depends on whether `dword_419170` (default 1500) is closer to 5200 or to 1500 (capacity in mAh ?).

The file is INI-style. Keys recognised by the parser: `VERSION_CHAR_SW`, `VERSION_DATA_FMT`, `BATTERY_PROFILE`, `BATTERY_NAME`, `BATTERY_ID`, `BATTERY_ADC_MIN`, `BATTERY_ADC_MAX`, `VBAT_MAX`, `IBAT_MAX`, `RBAT_NOM`, `FCC`, `FCC_VS_TEMP`, `FCC_VS_CYCLES`, `OCV_VS_TEMP_VS_SOC`, `CORRECTION_VS_CYCLES_VS_SOC`, `RBAT_VS_TEMP_VS_SOC`.  
The unit analysed carries the Nokia **BL-5J** profile. Key fields and their runtime use:

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

qcbms8930 device interface (published once the chip is online, disabled when the primary companion goes away)  
`{23B7D0DD-101F-4EFE-A4D4-BED70E754419}`

PMIC gauge / CCADC companion interface  
`{D17B2593-7189-4E1E-91F1-00798E07B8AB}`

PMIC RTC companion interface  
`{61630799-922A-4980-99D9-90C39084A979}`

Third awaited companion interface  
`{A942B3D9-EC95-4754-AE45-49C48735B893}`

### Other GUID

UEFI vendor GUID of the `BmsDataVariables` variable  
`{882F8C2B-9646-435F-8DE5-F208FF80C1BD}`

EFI System Partition type (used to locate the ESP when `PhoneNT` is absent)  
`{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}`
