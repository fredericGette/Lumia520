## Ltr554als02.sys

Driver of the Lite-On **LTR-554ALS-02** ambient light (ALS) + proximity (PS) sensor.  
It's a client of the Microsoft sensor class extension `SensorsClx` ([wpsensorsclx.sys](./wpsensorsclx.md)) (KMDF, PDB `E:\build_e\subtask\D06E3E63_98\output\sensors\fre\ltr554als02.pdb`). It has no device name of its own: the sensor device and its interface are managed by SensorsClx, which calls the driver through a table of callbacks (see [SensorsClx client](#sensorsclx-client)).  
The same chip is described by **two ACPI devices**, `\_SB.ALS2` (`LTR_554ALS_02_ALS`) and `\_SB.PRX2` (`LTR_554ALS_02_PRX`), so the driver is loaded twice. The ACPI method `MODE` tells each instance what it is. Both instances share one global context (one I²C target, one register shadow, one wait lock, one ALS polling thread): the first `DriverEntry` initializes it, the second waits for it (`InitSharedContext`, 0x4058FC).  
The ALS is polled by a system thread (the chip interrupt is only used for the proximity). The lux value is computed from the 2 photodiode channels with a Lite-On ratio table and reported in milli-lux. The proximity is reported as DETECTED / NOT DETECTED, optionally with "dynamic thresholds" that follow the crosstalk of the cover glass.  
Calibration is read from `C:\DPP\Nokia\Sensors\ALS_LITEON_LTR554ALS02.bin` and `C:\DPP\Nokia\Sensors\PRX_LITEON_LTR554ALS02.bin` (see [DPP calibration files](#dpp-calibration-files)).  
It's the alternative of the `QPDS_T900` sensor (`\_SB.ALS1` / `\_SB.PRX1`, address 0x39) on the same I²C bus: see [qcgsbi8930.sys](./qcgsbi8930.md) and [acpiex.sys](./acpiex.md).

There's no device name and no symbolic link created by the driver itself (they are managed by `SensorsClx`). Applications open the sensor through the device interface that SensorsClx creates for the sensor type:  
ALS instance: `{97F115C8-599A-4153-8894-D2D12899918A}`  
Proximity instance: `{5220DAE9-3179-4430-9F90-06266D2A34DE}`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\ltr554als02` ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\LTR_554ALS_02_ALS\1`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\LTR_554ALS_02_PRX\1`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters` (`WdfDriverOpenParametersRegistryKey`; the log messages wrongly call it "device parameters key"). All values are REG_DWORD, read once by `LTR554InitializeDevice`. A value that is missing or out of range keeps the default. Both instances read the same key.  

ALS instance (`ReadAlsParameterDataFromRegistry`, 0x40328C):  
| Registry value | value | comment |
|----------------|-------|---------|
| AlsLuxAlgorithmType | 2 | 2 = Lite-On, 3 = Lite-On 2, 4 = Lite-On 3. See [Lux calculation](#lux-calculation) |
| AlsLuxAlgorithmNumParams | 10 | ≤ 16 |
| AlsLuxAlgorithmParam00 … AlsLuxAlgorithmParam15 | | Signed, value / 10000 → float. The 3 values above are taken only if they are all present and pass `CheckAlsParameterValidity`. When they are, the algorithm parameters of the DPP file are ignored |
| AlsDynStateStartIndex | 2 | ≤ 3. Gain state used when the ALS is enabled (see [ALS](#als)) |

Proximity instance (`ReadPrxParameterDataFromRegistry`, 0x4035B0):  
| Registry value | value | comment |
|----------------|-------|---------|
| PrxFarToNearThreshold | 1000 | ≤ 0x7FF. Counts above which an object is detected |
| PrxNearToFarThreshold | 800 | ≤ 0x7FF. Counts below which the object is gone |
| PrxGainCoeff | 16 | ≤ 128, rounded to 16 or 128 (PS_CONTR gain) |
| PrxPulseCount | 5 | ≤ 16. PS_N_PULSES |
| PrxLedCurrent | 100 | mA, ≤ 100, rounded to 5/10/20/50/100 |
| PrxLedPulseFrequency | 60 | kHz, ≤ 100, rounded to 30…100 by steps of 10 |
| PrxLedDutyCycle | 100 | %, ≤ 100, rounded to 25/50/75/100 |
| PrxPersistence | 4 | ≤ 15. Number of consecutive samples needed before a change is reported (INTERRUPT_PERSIST) |
| DynamicThresholds | 0 | Not 0 = use dynamic thresholds. Forced to 0 (not read) in manufacturing mode |
| DynThrCrosstalk | 0 | ≤ 1647. Crosstalk stored by the driver itself (see below). 0 = none |
| DynThrMarginToCrosstalk | 150 | ≤ 500. Near-to-far threshold = crosstalk + margin |
| DynThrThresholdHyst | 200 | ≤ 200. Far-to-near threshold = near-to-far + hysteresis |
| DynThrLpfAlpha | 5000 | value / 10000 (default 0.5), must be ≤ 0.99. Low-pass filter of the samples |
| DynThrMinNumSamples | 25 | ≤ 128 |
| DynThrMaxNumSamples | 25 | ≤ 1000, forced ≥ DynThrMinNumSamples |
| DynThrMaxDeviation | 15 | ≤ 150. Stored squared (max variance, default 225) |
| DynThrMinHeadroom | 50 | ≤ 200 |
| DynThrAdjustHysteresis | 25 | ≤ 100 |
| DynThrDecrNumSamples | 5 | ≤ 25 |

The rest of the dynamic-threshold state has no registry value: DecrCrosstalkLimit (default 625), MinCrosstalk (25), MaxCrosstalk (1647).  
`DynThrCrosstalk` is **written** by the driver (`DynThrWriteToRegistry`, 0x403494, `WdfRegistryAssignULong`) when the proximity is stopped and the measured crosstalk differs from the stored one by at least `DynThrAdjustHysteresis`.

Other registry keys:  
| Registry key | Value | comment |
|--------------|-------|---------|
| `HKLM\SOFTWARE\Microsoft\ManufacturingOS` | ManufacturingMode | REG_DWORD, read once (`ReadManufacturingMode`, 0x4048C4). Not 0 = "ALS/Proximity sensor in manufacturing mode": the dynamic thresholds are disabled |
| `HKLM\SYSTEM\CurrentControlSet\Services\Sensors\ALS\TestInterface` | Enable, Value | REG_DWORD. Watched with `ZwNotifyChangeKey`. Enable ≠ 0: every ALS sample is replaced by `Value` (mLux). Written by [oempanel.sys](./oempanel.md) `IOCTL_SET_REGISTRY_VALUE2` |
| `HKLM\SYSTEM\CurrentControlSet\Services\Sensors\PS\TestInterface` | Enable, Value | REG_DWORD. Watched with `ZwNotifyChangeKey`. Enable ≠ 0: real proximity samples are not sent; a sample DETECTED (`Value` ≠ 0) / NOT DETECTED (`Value` = 0) is sent when the value changes and at each start |

If a `TestInterface` key doesn't exist, the test mode is simply not used.

There's no ETW provider. The driver prints with `vDbgPrintEx(DPFLTR_DEFAULT_ID (101), 0, …)`. Messages have a level 1–5; the masks at `.data:0x0040F150` (`FFFFFFFF FFFFFFFE FFFFFFFE 0 0`) only let errors and warnings through (levels 2 and 3); info (4) and function entry/exit (5) are disabled.

Pool tags: `LTR5` (`WDF_DRIVER_CONFIG.DriverPoolTag`, 0x4C545235), `UTLx` (0x784C5455, ACPI evaluation buffer).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| SensorsClx (class extension) | [wpsensorsclx.sys](./wpsensorsclx.md) | Bound through `WdfVersionBindClass("SensorsClx")`. Receives the samples, calls the callbacks |
| `\Device\RESOURCE_HUB\<connection id>` | [acpiex.sys](./acpiex.md) → [qci2c8930.sys](./qci2c8930.md) | I²C connection to `\_SB.IC12`, address 0x23, 400 kHz. Opened with `WdfIoTargetOpen` by the first instance only |
| Own ACPI PDO (`WdfDeviceGetIoTarget`) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD_EX` (0x32C018) to evaluate `MODE` |
| GPIO interrupt | — | Only the proximity instance creates a `WdfInterrupt` (passive-level handling) |

### ACPI devices

From the Nokia SSDT ([ssdt.dsl](../acpi/ssdt.dsl)):  
| Device | _HID | MODE | Sensor type |
|--------|------|------|-------------|
| `\_SB.ALS2` | `LTR_554ALS_02_ALS` | Buffer `01` | 2 = ambient light |
| `\_SB.PRX2` | `LTR_554ALS_02_PRX` | Buffer `02` | 1 = proximity |

Both have `_UID` 1, `_DEP` on `\_SB.IC12`, `\_SB.PRXY`, `\_SB.PEP0`, and the same `_CRS`:
* `I2cSerialBus`: slave address 0x23, 7-bit, 400 kHz, `\_SB.IC12`.
* `GpioInt`: GPIO 49 (0x31) of `\_SB.GIO0`, edge, active low, shared, pull-up.

Their `_PS0` / `_PS3` write `\_SB.ALS2` / `\_SB.PRX2` + D-state 0 / 3 to `\_SB.PRXY` (the ABD software target of [qcabd8930.sys](./qcabd8930.md)).

`GetMethodArgumentFromAcpi` (0x40686C) sends `IOCTL_ACPI_EVAL_METHOD_EX` with signature `AeiA` (0x41696541) and the method name. It expects signature `AeoB` (0x426F6541), 1 argument of type 2 (buffer) of at most 1 byte, otherwise `STATUS_ACPI_INVALID_DATA` (0xC014000F). Any other `MODE` value makes `EvtDriverDeviceAdd` fail with `STATUS_INVALID_PARAMETER`.

`LTR554InitializeDevice` (0x404AFC) requires both an I²C connection resource (`CM_RESOURCE_CONNECTION_CLASS_SERIAL`, type I2C) and a (non message-signaled) interrupt resource, even for the ALS instance. Otherwise it fails with `STATUS_UNSUCCESSFUL`.

### SensorsClx client

`DriverEntry` (0x405E2C) creates the WDF driver (`EvtDriverDeviceAdd` = `LTR554DeviceAdd` 0x4049D8, `EvtDriverUnload` = `DriverUnload` 0x405DB0), initializes the shared context and calls `SENSOR_CLX_RegisterClient`. Registration packet: version 1, size 76, client context size 1352 (0x548), pool tag `LTR5`.  
| Callback | Function | Comment |
|----------|----------|---------|
| InitializeDevice | `LTR554InitializeDevice` 0x404AFC | Opens the I²C target (first instance), reads `MODE`, loads defaults → registry → DPP, starts the test mode |
| UnInitializeDevice | `LTR554UnInitializeDevice` 0x404D9C | Stops the test mode, closes the I²C target |
| InitializeHardware | `LTR554InitializeHardware` 0x404E68 | First instance: reads PART_ID / MANUFAC_ID (0x86, 2 bytes). Fails with `STATUS_NOT_SUPPORTED` if the part number (PART_ID >> 4) isn't 9. Then sets the default register shadow |
| QueryDeviceInformation | `LTR554QueryDeviceInformation` 0x404E04 | Returns version 1, size 24, sensor type (1 = PS, 2 = ALS), maximum sample size 32, number of ranges 1, capabilities 2 (`SENSOR_CAPS_CLIENT_PUSH`), flags 0 |
| GetSensorTiming | `LTR554GetSensorTiming` 0x405860 | `110`, `1`, sample time: 225 ms (ALS) or 15 × (PrxPersistence + 1) ms (PS). SensorsClx uses the sample time as the minimum notification interval |
| StartAcquisition | `LTR554StartAcquisition` 0x405B6C | Interval in µs. Minimum 225 ms (ALS) / 15 ms (PS), otherwise `STATUS_NOT_SUPPORTED` and the sensor is stopped |
| StopAcquisition | `LTR554StopAcquisition` 0x405AC4 | Disables the function. When both ALS and PS are off, the chip will be reset at the next start |
| PowerEnable | `LTR554PowerEnable` 0x404F68 | Stub, returns 0 |
| InterruptEnable | `LTR554InterruptEnable` 0x405798 | Sets the PS (or ALS, unused) interrupt flag and rewrites INTERRUPT (0x8F) |
| DeviceIoControl | `LTR554DeviceIoControl` 0x4052F8 | The 3 OEM IOCTLs below. Anything else: `STATUS_INVALID_DEVICE_REQUEST` |

The other entries of the table are NULL. This is allowed because the driver is a push client: SensorsClx only requires GetSensorTiming, PowerEnable and StartAcquisition (see [wpsensorsclx.sys](./wpsensorsclx.md#client-interface)).  
The capabilities declare no threshold notification mode, so applications can only use the periodic mode (mode 0x00 of IOCTL 0x220014).  
SensorsClx starts the sensor (PowerEnable(1) + StartAcquisition with the smallest interval of the subscribers) when the first handle starts its notification. It stops the sensor when the last one stops, and also during the "low power epoch" unless a subscriber enabled idle operation.  
SensorsClx applies the DACL of `WpSecurity` to the sensor devices, unless the service key of ltr554als02 has `EnableOemSecurity` ≠ 0.  
The OEM IOCTLs below are not handled by SensorsClx itself: they reach `LTR554DeviceIoControl` through the SensorsClx fallback.  
Samples are sent to SensorsClx (`SensorClxSampleReady`) with a 32-byte buffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 20 00 00 00 | Size (32) |
| 08-0F | | `KeQueryInterruptTime` (100 ns) |
| 10-13 | 01 / 02 00 00 00 | 1 = proximity, 2 = ALS |
| 18-1B | | ALS: milli-lux (0xFFFFFFFF = saturated). PS: 1 = DETECTED, 0 = NOT DETECTED |

### Chip registers

The driver accesses the chip with `I2CSensorReadRegister` (0x406A38: `IOCTL_SPB_EXECUTE_SEQUENCE` 0x41808, write of the register address + read) and `I2CSensorWriteRegister` (0x406BCC: one `WdfIoTargetSendWriteSynchronously` of address + up to 16 bytes, auto-increment). Timeout 250 ms. All accesses are serialized by the shared wait lock (`LockSensor` / `UnlockSensor`).  
| Register | Name | Use |
|----------|------|-----|
| 0x80 | ALS_CONTR | bit 0 ALS active, bit 1 SW reset, bits 2–4 ALS gain |
| 0x81 | PS_CONTR | bits 0–1 PS mode (`10` = active), bits 2–3 PS gain (16X = 0x00, 128X = 0x08 ?) |
| 0x82 | PS_LED | bits 5–7 pulse frequency, bits 3–4 duty cycle, bits 0–2 peak current |
| 0x83 | PS_N_PULSES | Number of LED pulses |
| 0x84 | PS_MEAS_RATE | bits 0–3 repeat rate |
| 0x85 | ALS_MEAS_RATE | bits 3–5 integration time, bits 0–2 repeat rate |
| 0x86-0x87 | PART_ID, MANUFAC_ID | Read once. PART_ID is returned by the info IOCTL |
| 0x88-0x8B | ALS_DATA_CH1, ALS_DATA_CH0 | Little-endian 16-bit |
| 0x8C | ALS_PS_STATUS | bit 0 PS new data, bit 1 PS interrupt, bit 2 ALS new data, bit 3 ALS interrupt, bits 4–6 ALS gain of the data, bit 7 ALS data invalid |
| 0x8D-0x8E | PS_DATA | 11 bits |
| 0x8F | INTERRUPT | `01` (PS interrupt) when the PS is active and its interrupt enabled, else `00` |
| 0x90-0x93 | PS_THRES_UP, PS_THRES_LOW | |
| 0x97-0x9A | ALS_THRES_UP, ALS_THRES_LOW | `FF FF 00 00` (ALS interrupt never used) |
| 0x9E | INTERRUPT_PERSIST | PS persistence in bits 4–7 |
| 0xA0 | ? | Written with `04` after each reset. Not in the LTR-554 register list |

`ResetAndInitializeDevice` (0x401DD0), at the first start after both functions were stopped:
1. Write ALS_CONTR = `02` (SW reset), up to 10 tries.
2. Read ALS_CONTR until bit 1 is clear (up to 10 reads, `STATUS_DEVICE_BUSY` otherwise).
3. Write 0xA0 = `04`, PS thresholds (0x90, 4 bytes `FF 07 00 00`), ALS thresholds (0x97, 4 bytes `FF FF 00 00`), 0x80–0x85 (6 bytes, default `00 00 6B 05 06 05`), INTERRUPT_PERSIST = `40`, INTERRUPT = `00`.

### ALS

The ALS has no interrupt: the shared thread `LTR554ThreadProc` (0x4054B0) wakes up every *interval* ms (the timer resolution is set to 1 ms with `ExSetTimerResolution` while the ALS runs). It also wakes up when the sample should be ready (integration time × 1.5) after a gain change. Then it reads ALS_PS_STATUS and calls `ProcessALSData` (0x402958). If no new value is available, the previous one is sent again.

`ProcessALSData` reads the 2 channels and uses 4 "dynamic states" (table at `.data:0x0040F168`, 20 bytes each) to keep the channel sum in range:  
| Index | Low exit (→ index + 1) | High exit (→ index − 1) | Valid ChSum for lux | ALS_CONTR | ALS_MEAS_RATE | Gain / integration time |
|-------|------------------------|-------------------------|---------------------|-----------|---------------|-------------------------|
| 0 | 2000 | 50000 | 2000 … 0xFFFFFFFF | `00` | `01` | 1X, 100 ms |
| 1 | 2000 | 50000 | 2000 … 50000 | `0C` | `01` | 8X, 100 ms |
| 2 | 100 | 50000 | 100 … 50000 | `1C` | `01` | 96X, 100 ms |
| 3 | 0 | 600 | 0 … 50000 | `1C` | `1B` | 96X, 400 ms (repeat 500 ms) |

(Low exit = ChSum below it moves up one index; high exit = ChSum above it moves down.) A state change (`ActivateAlsDynamicState`, 0x4023B0) disables the ALS, clears the data registers by reading them, writes the new gain / rate and enables it again. A sample outside the valid range is not converted (except for the very first one), and the previous lux value is reported.

#### Lux calculation

`LTR554CalculateLuxValue` (0x4066F0) → `CalculateLuxValueLiteon` (0x405FBC):
1. If the gain is 1X and CH0 + CH1 > 50000 → saturated, the value is 0xFFFFFFFF.
2. vis = (CH0 − VisibleDarkCurrent) × VisibleCc, ir = (CH1 − IrDarkCurrent) × IrCc. If vis + ir < 0.01 → 0 lux.
3. ratio = ir / (vis + ir). It must be within 0.05 … 0.95, otherwise "Channel ratio not supported" and 0 lux.
4. Params is a list of triplets (ratio limit, ch0 coeff, ch1 coeff) starting at index 1 (type 2), 2 (type 3) or 5 (type 4). The first triplet whose limit is above the ratio is used.
5. lux = (ch0coeff × vis + ch1coeff × ir) / gain / (integration time / 100) × Param[0] × LuxCc. Type 4 uses Param[1] instead of Param[0] × LuxCc for the last triplet, and applies a further correction from Param[2…4] ?
6. Reported value = lux × 1000 + 0.5 (milli-lux).

Valid sizes (`CheckAlsParameterValidity`, 0x4031AC): type 2: NumParams = 1 + 3n; type 3: 2 + 3n; type 4: 5 + 3n with Param[2] < Param[3]; at least one triplet, at most 16 params.

Default parameters (`.data:0x0040E540`, type 2, 10 params). They are Lite-On's 3-segment formula:  
| Param | Value |
|-------|-------|
| 0 | 25.0 (correction factor) |
| 1–3 | ratio < 0.45: 1.7743 × CH0 + 1.1059 × CH1 |
| 4–6 | ratio < 0.73: 3.77 × CH0 − 1.3363 × CH1 |
| 7–9 | ratio < 0.95: 0.0693 × CH0 + 0.032 × CH1 |

LuxCc, VisibleCc, IrCc default to 1.0 and the dark currents to 0. They come from the DPP file.

### Proximity

`EnableSensorMeasurements` (0x402690) programs PS_LED, PS_N_PULSES, PS_MEAS_RATE and PS_CONTR from the parameters. The hardware repeat rate is chosen so that *persistence + 1* samples fit in the requested interval: PS_MEAS_RATE = interval × 100 / 150 / (persistence + 1), rounded down to 10/50/70/100/200/500/1000/2000 ms. The thresholds are first set to low = 1, high = 0 so that the first sample always raises an interrupt.

The interrupt runs `IsrAtPassive` (0x4040D4) at passive level. It reads ALS_PS_STATUS and PS_DATA, and compares the sample with the far-to-near threshold (when NOT DETECTED) or the near-to-far threshold (when DETECTED). The new state is sent to SensorsClx only when it changes. Then it reprograms the thresholds for the next transition: DETECTED → (near-to-far, 0x7FF), NOT DETECTED → (0, far-to-near). With dynamic thresholds, the low threshold is DecrCrosstalkLimit instead of 0 (`SetProxyThresholdsInHw`, 0x4025E4).

Dynamic thresholds (`EvaluateProxyThresholds` 0x403F68, `ObtainCrosstalk` 0x403E88), states at context `+0x94`:  
| State | Meaning |
|-------|---------|
| 0 | Static thresholds |
| 1 | Idle: thresholds derived from the current crosstalk |
| 2 | Qualify (after each start): samples are low-pass filtered. A new crosstalk is accepted after DynThrMinNumSamples samples if the variance ≤ DynThrMaxDeviation² and the value lies between crosstalk + DynThrAdjustHysteresis and MaxCrosstalk. Gives up after DynThrMaxNumSamples |
| 3 | Sample decreased (a sample below DecrCrosstalkLimit): DynThrDecrNumSamples samples are collected, and a lower crosstalk (≥ MinCrosstalk) is accepted |

On a new crosstalk: near-to-far = crosstalk + DynThrMarginToCrosstalk, far-to-near = near-to-far + DynThrThresholdHyst, DecrCrosstalkLimit = crosstalk − DynThrAdjustHysteresis. While in states 2/3, the hardware persistence is set to 0 and the driver applies PrxPersistence itself. MaxCrosstalk = 0x7FF − DynThrMinHeadroom − DynThrThresholdHyst − DynThrMarginToCrosstalk.

### DPP calibration files

`ReadParameterDataFromDpp` (0x403AD4) reads the file with `ZwOpenFile` / `ZwReadFile`. The file must have the exact size, and the size, manufacturer and model fields must match, otherwise `STATUS_INVALID_PARAMETER_MIX` (0xC00000E5). It's called at initialization, after the registry (so DPP values override the registry, except the ALS algorithm when the registry has one). It's also called by [IOCTL 0x2204BC](#ioctl-0x2204bc--ioctl_sensor_oem_calibration_read_dpp).

`ALS_LITEON_LTR554ALS02.bin` (120 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 78 00 00 00 | Size (120) |
| 04-13 | `LITEON` | Manufacturer, NUL-padded (7 bytes compared) |
| 14-23 | `LTR-554ALS-02` | Model, NUL-padded (14 bytes compared) |
| 24-27 | float | LuxCc |
| 28-2B | float | VisibleCc |
| 2C-2F | float | IrCc |
| 30-31 | | VisibleDarkCurrent (counts, signed) |
| 32-33 | | IrDarkCurrent (counts, signed) |
| 34-35 | | LuxAlgoType |
| 36-37 | | LuxAlgoNumParams |
| 38-77 | float[16] | LuxAlgoParam (used only if valid and not given in the registry) |

`PRX_LITEON_LTR554ALS02.bin` (52 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 34 00 00 00 | Size (52) |
| 04-13 | `LITEON` | Manufacturer |
| 14-23 | `LTR-554ALS-02` | Model |
| 24-25 | | NearToFarThreshold |
| 26-27 | | FarToNearThreshold |
| 28-29 | 10 00 / 80 00 | GainCoeff, must be 16 or 128 |
| 2A | | LedPulseCount, ≤ 16 |
| 2B | | LedPulseFrequency (kHz), must be an exact table value |
| 2C | | LedDutyCycle (%), must be an exact table value |
| 2D | | LedCurrent (mA), must be an exact table value |
| 2E-2F | | Margin used at calibration ?: with dynamic thresholds, initial crosstalk = NearToFarThreshold − this value, unless a `DynThrCrosstalk` is stored in the registry |
| 30-33 | | ? |

---

### IOCTL 0x2204B8 — IOCTL_SENSOR_OEM_CALIBRATION_QUERY

This IOCTL is processed by Ltr554als02.sys (received through SensorsClx `DeviceIoControl`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x12E (302) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SENSOR_OEM_CALIBRATION_QUERY | 0 | 120 (ALS) / 44 (PS), at least 36 |

ALS instance: it first recomputes the lux of the last raw sample **without** calibration (dark currents 0, coefficients 1.0). Output (copy of the context at `+0x94`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 78 00 00 00 | Size (120) |
| 04-13 | `LITEON` | Manufacturer |
| 14-23 | `LTR-554ALS-02` | Model |
| 24-27 | | Last calibrated value (mLux) |
| 28-2B | | Uncalibrated value of the last sample (mLux) |
| 2C-2D | | Last CH0 |
| 2E-2F | | Last CH1 |
| 30-31 | | Gain of the last sample (1…96) |
| 32-33 | | Integration time of the last sample (ms) |
| 34-35 | | LuxAlgoType |
| 36-37 | | LuxAlgoNumParams |
| 38-77 | float[16] | LuxAlgoParam |

PS instance: it calls `LTR554ProximityReadSingleSample` (0x404FAC). This disables the PS, enables it with a 10 ms repeat rate, polls ALS_PS_STATUS every 15 ms (10 times max), reads one raw PS_DATA, and restores the previous configuration. Output (context `+0x4C`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 2C 00 00 00 | Size (44) |
| 04-13 | `LITEON` | Manufacturer |
| 14-23 | `LTR-554ALS-02` | Model |
| 24-25 | | Raw PS sample (0…0x7FF) |
| 26-27 | | GainCoeff |
| 28 | | LedPulseCount |
| 29 | | LedPulseFrequency |
| 2A | | LedDutyCycle |
| 2B | | LedCurrent |

min(output length, size) bytes are copied. If the output buffer is smaller than 36 bytes, the data is still copied but the IOCTL returns `STATUS_BUFFER_TOO_SMALL` (0xC0000023).

---

### IOCTL 0x2204BC — IOCTL_SENSOR_OEM_CALIBRATION_READ_DPP

This IOCTL is processed by Ltr554als02.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x12F (303) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SENSOR_OEM_CALIBRATION_READ_DPP | 0, or > 8 | 0 |

Inputbuffer (optional):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | e.g. `\??\C:\Data\PRX.bin` | NUL-terminated UTF-16 NT path of the file to read instead of the default DPP file |

It reloads the calibration ([DPP calibration files](#dpp-calibration-files)) from the given file, or from the default one when the input buffer is 8 bytes or less. If the proximity is running, it is disabled and enabled again with the new parameters. The returned information is the input length.

> [!NOTE]
> The path comes straight from the request buffer and is opened from kernel mode (`ZwOpenFile` with `OBJ_KERNEL_HANDLE`): any file of the right size and header can be loaded.

---

### IOCTL 0x2204C0 — IOCTL_SENSOR_OEM_INFO_QUERY

This IOCTL is processed by Ltr554als02.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x130 (304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SENSOR_OEM_INFO_QUERY | 0 | ≥ 36 (300 used) |

Outputbuffer (built by `LTR554GetInfo`, 0x40526C, in `.data:0x0040FB10`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 2C 01 00 00 | Size (300) |
| 04-13 | `LITEON` | Manufacturer |
| 14-23 | `LTR-554ALS-02` | Model |
| 24-27 | e.g. `92 00 00 00` | PART_ID register (part number 9, revision in bits 0–3) |
| 28-127 | 00 … | 256 bytes, zero |
| 128-12B | 01 00 00 00 | ? |

A smaller buffer than 36 bytes returns `STATUS_BUFFER_TOO_SMALL`. Otherwise min(output length, 300) bytes are returned.

---

### IOCTL 0x41808 — IOCTL_SPB_EXECUTE_SEQUENCE

This IOCTL is sent by Ltr554als02.sys to qci2c8930.sys (through SpbCx)

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x602 (1538) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SPB_EXECUTE_SEQUENCE | `\Device\RESOURCE_HUB\<connection id>` | 52 | 0 |

`SPB_TRANSFER_LIST` with 2 entries: a write of the 1-byte register address, then a read of *n* bytes. Used by every register read.

---

### IOCTL 0x32C018 — IOCTL_ACPI_EVAL_METHOD_EX

This IOCTL is sent by Ltr554als02.sys to acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x6 (6) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD_EX | Own PDO | 260 | 21 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 41 | `AeiA` |
| 04-08 | `MODE` | Method name, NUL-terminated |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | `AeoB` |
| 04-07 | | Length |
| 08-0B | 01 00 00 00 | Count |
| 0C-0D | 02 00 | Type: buffer |
| 0E-0F | 01 00 | Data length |
| 10 | 01 / 02 | 1 = ALS, 2 = proximity |
