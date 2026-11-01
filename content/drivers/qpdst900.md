## Qpdst900.sys

Driver of the Avago **QPDS-T900** ambient light (ALS) + proximity (PS) sensor (I²C address 0x39). It also accepts the **QPDS-T930** variant.  
It's a client of the Microsoft sensor class extension `SensorsClx` ([wpsensorsclx.sys](./wpsensorsclx.md)) (KMDF, PDB `E:\build_e\subtask\D06E3E63_98\output\sensors\fre\QPDST900.pdb`). It has no device name of its own: the sensor device and its interface are managed by SensorsClx, which calls the driver through a table of callbacks (see [SensorsClx client](#sensorsclx-client)). The code is the same Nokia framework as [ltr554als02.sys](./ltr554als02.md) (same SensorsClx glue, test mode, dynamic proximity thresholds, DPP files, log format), with a different chip layer and a generic "parameter" layer (defaults → DPP → registry → calibration replay).  
The same chip is described by **two ACPI devices**, `\_SB.ALS1` (`QPDS_T900_ALS`) and `\_SB.PRX1` (`QPDS_T900_PRX`), so the driver is loaded twice. The ACPI method `MODE` tells each instance what it is. Both instances share one global context at `.data:0x00415AD0` (one I²C target, one register shadow, one wait lock, one worker thread): the first `DriverEntry` initializes it (`InitSharedContext`, 0x406310).  
The chip can't measure the light and the proximity at the same time with the right settings, so the driver **time-shares** it: the proximity runs continuously, and once per ALS interval it is suspended for one ALS integration (see [Scheduling](#scheduling)). Both functions are interrupt driven (shared GPIO 49).  
Calibration is read from `C:\DPP\Nokia\Sensors\ALS_AVAGO_QPDST900.bin` and `C:\DPP\Nokia\Sensors\PRX_AVAGO_QPDST900.bin`, and the driver can **rewrite** these files (see [DPP calibration files](#dpp-calibration-files) and [IOCTL 0x222000](#ioctl-0x222000--calibration-request)).  
It's the alternative of the Lite-On LTR-554ALS-02 ([ltr554als02.sys](./ltr554als02.md), `\_SB.ALS2` / `\_SB.PRX2`, address 0x23) on the same I²C bus: see [qcgsbi8930.sys](./qcgsbi8930.md) and [acpiex.sys](./acpiex.md).

There's no device name and no symbolic link created by the driver itself (they are managed by `SensorsClx`). Applications open the sensor through the device interface that SensorsClx creates for the sensor type:  
ALS instance: `{97F115C8-599A-4153-8894-D2D12899918A}`  
Proximity instance: `{5220DAE9-3179-4430-9F90-06266D2A34DE}`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qpdst900` ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QPDS_T900_ALS\1`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QPDS_T900_PRX\1`  

### Registry

All parameters go through a small framework (`ParamRegistryOpen` 0x401B54, `ParamRegistryRead` 0x401C10). Each parameter has a name, a type (long or float), a value and a *source*: `PARAM_SOURCE_DEFAULT` (0), `DPP_STATIC` (1), `DPP_CALIBRATED` (2), `CALCULATED` (3), `REGISTRY` (4). The whole configuration is printed at each step (level 4 logs "ALS configuration after …" / "PRX config after …").

`T900ReadParameters` (0x4054A0) loads the configuration of an instance in this order:
1. "setting defaults" (`0x404504` ALS, `0x404E40` PRX).
2. "reading DPP": the DPP file. Each field is marked `DPP_CALIBRATED` if its bit is set in the file's IsCalibrated mask, `DPP_STATIC` otherwise.
3. "reading registry": a value is taken from the registry only if the parameter is still a default, or if it comes from a `DPP_STATIC` field and the registry `ConfigVersion` ≥ the DPP config version. **Calibrated DPP fields are never overridden by the registry.**
4. "initial finalization": derived values and range checks (`0x404AD4` ALS, `FinalizePrxConfig` 0x40527C).
5. "calibration replay (final configuration)": the calibrations recorded in `*_CALIB.bin` are applied again (see [Calibration replay](#calibration-replay)).
6. Minimum intervals: ALS 250 ms; proximity = ⌈IntegrationTime × 2.72⌉ ms + the proximity cycle time (see [Scheduling](#scheduling)).

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters` (`WdfDriverOpenParametersRegistryKey`):  
| Registry value | value | comment |
|----------------|-------|---------|
| ConfigVersion | | REG_DWORD. Compared with the config version of the DPP file (see above). Missing = 0 |
| DppFormat | | REG_DWORD. 0 = write the short DPP files (72 / 48 bytes), ≠ 0 = the full ones (424 / 324 bytes). Only used when the driver writes the DPP files |
| DefaultHwRevisionMajor, DefaultHwRevisionMinor | | REG_DWORD. Name of the fallback subkey, see below |
| DynThrCrosstalk | | REG_DWORD. Crosstalk stored by the driver itself (`DynThrWriteToRegistry`, 0x403FC4, when the proximity is stopped and the measured crosstalk differs from the stored one by at least `DynThrAdjustHysteresis`). Read back by `0x40513C` |

The parameters themselves are read from the subkey `Parameters\<a>\<b>` (format `%lu\%lu`, `ParamRegistryOpenSubkey` 0x401900). Both callers pass the DPP "HW major revision" field for `<a>` **and** for `<b>` (the minor revision is never used, a bug ?). The short DPP files of the Lumia 520 have no revision field, so the subkey is `Parameters\0\0`. If it can't be opened, the driver opens `Parameters\<DefaultHwRevisionMajor>\<DefaultHwRevisionMinor>` instead (0\0 when these values are missing). Values are REG_DWORD; floats are stored as value × 10000.

ALS instance (defaults set by `0x404504`, read by `0x4049A4`):  
| Registry value | value | comment |
|----------------|-------|---------|
| Calibration | 1.0 | Float. Overall lux multiplier ("MasterCc"). Set by the [irradiance calibration](#method-1-irradiance-als) |
| VisibleCc | 1.0 | Float. Multiplier of the visible channel (CH0) |
| IrCc | 1.0 | Float. Multiplier of the IR channel (CH1) |
| VisibleDarkCurrent | 0 | Counts subtracted from CH0 |
| IrDarkCurrent | 0 | Counts subtracted from CH1 |
| CoeffGA | 11.594 | Float. Glass attenuation (GA of the Avago lux formula) |
| CoeffB | 1.891 | Float |
| CoeffC | 0.497 | Float |
| CoeffD | 0.921 | Float |
| IntegrationTime | 18 | ALS integration time in cycles of 2.72 ms (ATIME = 256 − value). Default 48.96 ms, full scale 18 × 1024 = 18432 counts |
| AlsInitialGainIndex | 2 | 0–3, index in the [gain table](#chip-registers) (2 = 16X) |
| AlsGainIncr1Threshold | 1 % of full scale | CH0 at or below: gain + 1. Default computed only if the value is still a default |
| AlsGainIncr2Threshold | 0.1 % of full scale | CH0 at or below: gain + 2 |
| AlsGainDecr1Threshold | 75 % of full scale | CH0 at or above: gain − 1 (at full scale: gain − 2) |
| LuxCorrNumPoints | 0 | 0–8. Number of points of the lux correction table |
| LuxCorrLux00 … LuxCorrLux07 | 0 | Lux of each point |
| LuxCorrFac00 … LuxCorrFac07 | 0.0 | Float. Correction factor of each point (applied to the lux, piecewise ?) |
| DynRangeExtEnable | 0 | ≠ 0: when CH0 is saturated but not CH1, CH0 is rebuilt as CH1 / channel ratio |
| DynExtChRatioMin | 0.4 | Float. Range of acceptable remembered ratios, ≤ the maximum ratio |
| DynExtChRatioMax | 0.5 | Float |
| DynExtChRatioDef | 0.45 | Float. Ratio used when no remembered ratio is in range |

Proximity instance (defaults set by `0x404E40`, read by `0x40513C`):  
| Registry value | value | comment |
|----------------|-------|---------|
| PulseCount | 1 | PPULSE register (number of LED pulses) |
| LEDdriveStrength | 1 | PDRIVE, bits 6–7 of CONTROL (0 = 100 mA, 1 = 50 mA, 2 = 25 mA, 3 = 12.5 mA) |
| PrxPersistence | 3 | 0–15. PPERS (number of consecutive samples out of range before an interrupt) |
| PrxOffset | 0 | POFFSET register value, QPDS-T930 only. > 255 is reset to 0 |
| TargetCrosstalk | 100 | 0–1023. Target of the [offset calibration](#method-3-offset-proximity-qpds-t930-only) |
| NearToFar | 600 | Counts below which the object is gone (static thresholds) |
| FarToNear | 700 | Counts above which an object is detected (static thresholds) |
| MarginToCrosstalk | 200 | Used by the [crosstalk calibration](#method-1-crosstalk-proximity): NearToFar = crosstalk + margin. Also the initial crosstalk of the dynamic thresholds = NearToFar − margin |
| ThresholdHysteresis | 100 | FarToNear = NearToFar + hysteresis (calibrations) |
| DynamicThresholds | 0 | ≠ 0 = use dynamic thresholds. Ignored in manufacturing mode |
| DynThrMarginToCrosstalk | 150 | Near-to-far = crosstalk + margin |
| DynThrThresholdHyst | 100 | Far-to-near = near-to-far + hysteresis |
| DynThrLpfAlpha | 0.5 | Float, 0–1. Low-pass filter of the samples |
| DynThrMinNumSamples | 25 | 1–128 |
| DynThrMaxNumSamples | 25 | ≥ DynThrMinNumSamples |
| DynThrMaxDeviation | 15 | Stored squared (max variance) |
| DynThrMinHeadroom | 50 | MaxCrosstalk = 1023 − headroom − hysteresis − margin |
| DynThrAdjustHysteresis | 25 | Minimum change of the crosstalk, also DecrCrosstalkLimit = crosstalk − this value |
| DynThrDecrNumSamples | 5 | |
| PrxDelayNotDetected | 0 | ms. A NOT DETECTED sample is delayed until this time has elapsed since the previous report (`ReportOrDelayProximitySample`, 0x403384) |

The dynamic thresholds work like in [ltr554als02.sys](./ltr554als02.md#proximity) (same state machine: static / idle / qualify / sample decreased, `EvaluateProxyThresholds` 0x40318C, `ObtainCrosstalk` 0x402604), with a 10-bit range (0–1023). They are suspended while the ALS is saturated.

Other registry keys:  
| Registry key | Value | comment |
|--------------|-------|---------|
| `HKLM\SOFTWARE\Microsoft\ManufacturingOS` | ManufacturingMode | REG_DWORD, read once (`ReadManufacturingMode`, 0x401EDC). Not 0: the dynamic thresholds are disabled |
| `HKLM\SYSTEM\CurrentControlSet\Services\Sensors\ALS\TestInterface` | Enable, Value | REG_DWORD. Watched with `ZwNotifyChangeKey`. Enable ≠ 0: every ALS sample is replaced by `Value` (mLux). Written by [oempanel.sys](./oempanel.md) `IOCTL_SET_REGISTRY_VALUE2` |
| `HKLM\SYSTEM\CurrentControlSet\Services\Sensors\PS\TestInterface` | Enable, Value | REG_DWORD. Watched with `ZwNotifyChangeKey`. Enable ≠ 0: real proximity samples are not sent; a sample DETECTED (`Value` ≠ 0) / NOT DETECTED is sent when the value changes and at each start |

These 3 keys are the same as for [ltr554als02.sys](./ltr554als02.md).

There's no ETW provider. The driver prints with `vDbgPrintEx(DPFLTR_DEFAULT_ID (101), 0, …)`. Messages have a level 1–5; the masks at `.data:0x0041514C` (`FFFFFFFF FFFFFFFE FFFFFFFE 0 0`) only let errors and warnings through (levels 2 and 3).

Pool tags: `QPTS` (`WDF_DRIVER_CONFIG.DriverPoolTag`, 0x51505453), `UTLx` (0x784C5455, ACPI evaluation buffer).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| SensorsClx (class extension) | [wpsensorsclx.sys](./wpsensorsclx.md) | Bound through `WdfVersionBindClass("SensorsClx")`. Receives the samples, calls the callbacks |
| `\Device\RESOURCE_HUB\<connection id>` | [acpiex.sys](./acpiex.md) → [qci2c8930.sys](./qci2c8930.md) | I²C connection to `\_SB.IC12`, address 0x39, 400 kHz. Opened with `WdfIoTargetOpen` by the first instance only |
| Own ACPI PDO (`WdfDeviceGetIoTarget`) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD_EX` (0x32C018) to evaluate `MODE` |
| GPIO interrupt | [qcgpio.sys](./qcgpio.md) | GPIO 49, shared by both instances (`WdfInterrupt` with passive-level handling, `IsrAtPassive` 0x403DC4) |
| Files `C:\DPP\Nokia\Sensors\*_AVAGO_QPDST900*.bin` | file system | Read and written, see below |

### ACPI devices

From the Nokia SSDT ([ssdt.dsl](../acpi/ssdt.dsl)):  
| Device | _HID | MODE | Sensor type |
|--------|------|------|-------------|
| `\_SB.ALS1` | `QPDS_T900_ALS` | Buffer `01` | 2 = ambient light |
| `\_SB.PRX1` | `QPDS_T900_PRX` | Buffer `02` | 1 = proximity |

Both have `_UID` 1, `_DEP` on `\_SB.IC12`, `\_SB.PRXY`, `\_SB.PEP0`, and the same `_CRS`:
* `I2cSerialBus`: slave address 0x39, 7-bit, 400 kHz, `\_SB.IC12`.
* `GpioInt`: GPIO 49 (0x31) of `\_SB.GIO0`, edge, active low, shared, pull-up.

Their `_STA` reads the ID register (command 0x92) over the `GenericSerialBus` region of `\_SB.IC12` and reports the device only if it is 0x29 (QPDS-T900): a QPDS-T930 (ID 0x39), although supported by the driver, would not be enumerated. Their `_PS0` / `_PS3` write `\_SB.ALS1` / `\_SB.PRX1` + D-state to `\_SB.PRXY` ([qcpepproxy8930.sys](./qcpepproxy8930.md)). `\_SB.ALS1` also has a method `PASS` (Buffer `42`) that the driver doesn't use.

`GetMethodArgumentFromAcpi` (0x40970C) is the same as in [ltr554als02.sys](./ltr554als02.md#acpi-devices): any `MODE` other than 1 / 2 makes `EvtDriverDeviceAdd` (`T900DeviceAdd`, 0x403E1C) fail with `STATUS_INVALID_PARAMETER`.  
`T900InitializeDevice` (0x40599C) requires an I²C connection resource (`CM_RESOURCE_CONNECTION_CLASS_SERIAL`, type I2C) and a non message-signaled interrupt resource, otherwise `STATUS_UNSUCCESSFUL`.

### SensorsClx client

`DriverEntry` (0x4070CC) creates the WDF driver (`EvtDriverDeviceAdd` = `T900DeviceAdd`, `EvtDriverUnload` = `DriverUnload` 0x407034, `EvtCleanupCallback` = `T900EvtCleanup` 0x407230), initializes the shared context (wait lock, 3 events, worker thread `T900ThreadProc` 0x405DFC, manufacturing mode), calls `SENSOR_CLX_RegisterClient` and opens the two `TestInterface` keys. Registration packet: version 1, size 76, client context size 36, pool tag `QPTS`.  
| Callback | Function | Comment |
|----------|----------|---------|
| InitializeDevice | `T900InitializeDevice` 0x40599C | Opens the I²C target (first instance), reads `MODE`, loads the parameters (`T900ReadParameters`) |
| UnInitializeDevice | `T900UnInitializeDevice` 0x405BFC | Closes the I²C target |
| InitializeHardware | `T900InitializeHardware` 0x405CBC | First call only: reads REV/ID (command 0xB1, 2 bytes). Accepted: `01 29` (QPDS-T900) and `02 39` (QPDS-T930), otherwise `STATUS_UNSUCCESSFUL`. Then reads the 16 registers 0x00–0x0F into the shadow at `.data:0x004169F4` |
| QueryDeviceInformation | `T900QueryDeviceInformation` 0x405C58 | Version 1, size 24, sensor type (1 = PS, 2 = ALS), maximum sample size 32, number of ranges 1, capabilities 2 (`SENSOR_CAPS_CLIENT_PUSH`), flags 0 |
| GetSensorTiming | `T900GetSensorTiming` 0x40623C | `3` (⌈2.72⌉), `0`, minimum interval in ms: ALS 250, PS ⌈ALS integration + proximity cycle⌉ (81 ms with the defaults) |
| StartAcquisition | `T900StartAcquisition` 0x406488 | Interval in µs. Below the minimum interval: `STATUS_NOT_SUPPORTED`. Sets the timer resolution to 1 ms |
| StopAcquisition | `T900StopAcquisition` 0x406910 | Stops the function. PS: stores the crosstalk (dynamic thresholds). When both are off, the chip oscillator is switched off (ENABLE = 0) |
| PowerEnable | `T900PowerEnable` 0x405DB8 | Stub, returns 0 |
| InterruptEnable | `T900InterruptEnable` 0x4061C8 | Only logs |
| DeviceIoControl | `T900DeviceIoControl` 0x4093A4 | The 4 IOCTLs below. Anything else: `STATUS_INVALID_DEVICE_REQUEST` |

Context of an instance (36 bytes): `+0x10` sensor type, `+0x14` shared context, `+0x18` gain table, `+0x1C` ALS configuration (`.data:0x00415B40`), `+0x20` PS configuration (`.data:0x00416218`).  
Samples are sent to SensorsClx (`SensorClxSampleReady`) with the same 32-byte buffer as [ltr554als02.sys](./ltr554als02.md#sensorsclx-client):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 20 00 00 00 | Size (32) |
| 08-0F | | `KeQueryInterruptTime` (100 ns) |
| 10-13 | 01 / 02 00 00 00 | 1 = proximity, 2 = ALS |
| 18-1B | | ALS: milli-lux (0xFFFFFFFF = saturated). PS: 1 = DETECTED, 0 = NOT DETECTED |

### Chip registers

The QPDS-T900 has the register map of the Avago APDS-9900 (QPDS-T930: APDS-9930, with POFFSET). Every access starts with a command byte: 0x80 | register (single byte), 0xA0 | register (auto-increment), 0xE0 | function (special function). The driver reads with `I2CSensorReadRegister` (0x409934, `IOCTL_SPB_EXECUTE_SEQUENCE` 0x41808: write of the command + read) and writes with `I2CSensorWriteRegister` (0x409AC8, `WdfIoTargetSendWriteSynchronously` of command + data). Timeout 250 ms. All accesses are serialized by the shared wait lock (`LockSensor` / `UnlockSensor`).  
| Command | Register | Use |
|---------|----------|-----|
| 0x80 | ENABLE | bit 0 PON, 1 AEN (ALS), 2 PEN (PS), 3 WEN (wait), 4 AIEN, 5 PIEN |
| 0x81 | ATIME | 256 − ALS cycles (2.72 ms each). `FE` during proximity, 256 − IntegrationTime during ALS |
| 0x82 | PTIME | `FF` (1 cycle) |
| 0x83 | WTIME | `FF` |
| 0xA4, 0xA6 | AILT, AIHT | ALS interrupt thresholds (2 bytes each) |
| 0xA8, 0xAA | PILT, PIHT | PS interrupt thresholds |
| 0x8C | PERS | bits 4–7 PPERS = PrxPersistence, bits 0–3 APERS (1 during proximity, 0 during ALS) |
| 0x8E | PPULSE | PulseCount |
| 0x8F | CONTROL | bits 6–7 PDRIVE = LEDdriveStrength, bits 4–5 PDIODE = `10` (CH1 diode), bits 2–3 PGAIN (`10` = 4X on the T930 only), bits 0–1 AGAIN |
| 0x9E | POFFSET | T930 only. PrxOffset (bit 7 = sign) |
| 0xB1 | REV, ID | Read once |
| 0x93 / 0xB3 | STATUS | bit 0 AVALID, 1 PVALID, 4 AINT, 5 PINT |
| 0xB4 | CDATA, IRDATA | CH0 (visible + IR), CH1 (IR), 16 bits each |
| 0xB8 | PDATA | 10 bits |
| 0xE5 / 0xE6 / 0xE7 | special function | Clear the PS / ALS / both interrupts (`ClearInterrupts`, 0x403088, checks STATUS afterwards) |

ALS gain table (`.data:0x00415160`, 8 bytes per entry, float gain + AGAIN code): index 0 = 1X (`00`), 1 = 8X (`01`), 2 = 16X (`02`), 3 = 120X (`03`).

### Scheduling

The global measurement state (`.data:0x004169A8`) is 0 = idle, 1 = proximity running, 2 = one ALS measurement running.  
* `StartProxyMeasurement` (0x402C18): ENABLE = PON only, at the first start PERS / PTIME / PPULSE / PDRIVE / POFFSET / thresholds are written (`T900ProximityApplyCalibration` 0x4058AC), ATIME = `FE` (2 cycles, the "proxy sunlight workaround"), CONTROL with AGAIN 1X, then ENABLE |= PEN + AEN + PIEN (+ AIEN). The ALS still runs during the proximity, only to detect sunlight: CH0 ≥ 2048 = saturated.
* `StartAlsMeasurement` (0x402E9C): ENABLE = PON, APERS = 0, ATIME = 256 − IntegrationTime, AGAIN of the current gain index, then ENABLE |= AEN + AIEN. The ALS interrupt ends the measurement.
* The worker thread `T900ThreadProc` sleeps until the next ALS start time, then starts one ALS measurement (also a watchdog when the interrupt doesn't come). When the ALS starts, the proximity is suspended; when the ALS sample is processed, the proximity is restarted if enabled. If the proximity has just started, the ALS waits until a full proximity cycle is done (proximity cycle time = ⌈3 × PrxPersistence × 2.9⌉ + 5 ms).
* An ALS measurement whose gain had to change ("short cycle") is repeated at once.

The interrupt (`IsrAtPassive` → `ServiceComponentInterrupt` 0x403A2C) is handled by the instance of the running measurement ("Interrupt is for another driver" otherwise). It reads STATUS, disables the interrupts, services the PS or ALS, clears the interrupts and re-enables them.

### ALS

`ProcessALSData` (0x402890) reads CH0/CH1 and checks the gain (`0x40272C`): CH0 ≥ full scale → gain − 2, ≥ AlsGainDecr1Threshold → − 1, ≤ AlsGainIncr2Threshold → + 2, ≤ AlsGainIncr1Threshold → + 1 (clamped to 0–3). If the gain changed because the sample was too high or too low, the sample is dropped ("No good ALS measurement with this gain, report nothing") and measured again with the new gain. When the lux can't be computed, the previous value is reported.

Lux calculation (`CalculateLuxValue`, 0x407350), Avago formula:
1. ch0 = (CH0 − VisibleDarkCurrent) × VisibleCc, ch1 = (CH1 − IrDarkCurrent) × IrCc. ch0 < 0.01 → 0 lux.
2. Raw channel ≥ full scale (IntegrationTime × 1024) → saturated, 0xFFFFFFFF. With DynRangeExtEnable, a saturated CH0 alone is rebuilt from ch1 and the median ? of the last 5 channel ratios (or DynExtChRatioDef when it is outside DynExtChRatioMin…Max).
3. ratio = ch1 / ch0 is remembered only if below the max ratio = min(1, max(CoeffC / CoeffD, 1 / CoeffB)).
4. IAC1 = ch0 − CoeffB × ch1, IAC2 = CoeffC × ch0 − CoeffD × ch1, IAC = max(IAC1, IAC2).
5. lux = IAC × CoeffGA × 52 × Calibration / (gain × integration time in ms), then × the LuxCorr factor when LuxCorrNumPoints > 0.
6. Reported value = lux × 1000 + 0.5 (milli-lux), 0xFFFFFFFF if it overflows.

### Proximity

`ServiceProxyInterrupt` (0x403484) reads PDATA. The first sample after a start is ignored if less than the PS minimum interval (ALS integration + proximity cycle) elapsed. Without valid ALS data (AVALID = 0) the sample is skipped. It reads CH0: if CH0 ≥ 2048 (sunlight), a detection is corrected to NOT DETECTED, the gain of the next ALS measurement is forced to 1X and the ALS interrupt is used to detect the end of the saturation.  
The sample is compared with the current threshold: NOT DETECTED → DETECTED when above far-to-near, DETECTED → NOT DETECTED when at or below near-to-far. The new state is sent only when it changes (and not in test mode). Then the hardware window is reprogrammed (`SetProxyThresholdsInHw` 0x402ABC): NOT DETECTED → (0 or DecrCrosstalkLimit, far-to-near), DETECTED → (near-to-far, 1023).

### DPP calibration files

`ReadDppFile` (0x404160) opens the file with `ZwOpenFile` and reads up to the full structure size. The file needs at least the 36-byte header and the manufacturer `AVAGO` / model `QPDS-T900`; the size field must be ≥ the number of bytes read; otherwise `STATUS_INVALID_PARAMETER_MIX` (0xC00000E5). A shorter file is accepted: each field is taken only if the file reaches its end, the others keep their value ("missing data that will replaced with default values").

`ALS_AVAGO_QPDST900.bin` (`ReadAlsParametersFromDpp`, 0x40472C, up to 424 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 48 00 00 00 / A8 01 00 00 | Size (72 short format, 424 full) |
| 04-13 | `AVAGO` | Manufacturer, NUL-padded |
| 14-23 | `QPDS-T900` | Model, NUL-padded |
| 24-27 | float | Calibration (IsCalibrated bit 0) |
| 28-2B | float | VisibleCc (bit 1) |
| 2C-2D | | VisibleDarkCurrent, signed (bit 2) |
| 30-33 | float | IrCc (bit 3) |
| 34-35 | | IrDarkCurrent, signed (bit 4) |
| 38-3B | float | CoeffGA (bit 5) |
| 3C-3F | float | CoeffB (bit 6) |
| 40-43 | float | CoeffC (bit 7) |
| 44-47 | float | CoeffD (bit 8) |
| 48-4B | | HW major revision (selects the registry subkey) |
| 4C-4F | | DPP config version |
| 50-14F | | Comment, text, printed at level 3 |
| 150-153 | | IsCalibrated mask. Missing: 0x1F (the 5 calibration fields) |
| 154-157 | | LuxCorrNumPoints, 0–8 (bit 9) |
| 158-197 | | 8 × (LuxCorrLux, float LuxCorrFac) |
| 198-19B | | DynRangeExtEnable (bit 10) |
| 19C-1A7 | float[3] | DynExtChRatioMin, Max, Def (bits 11–13) |

`PRX_AVAGO_QPDST900.bin` (`ReadPrxParametersFromDpp`, 0x404FC0, up to 324 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 30 00 00 00 / 44 01 00 00 | Size (48 short format, 324 full) |
| 04-13 | `AVAGO` | Manufacturer |
| 14-23 | `QPDS-T900` | Model |
| 24-25 | | NearToFar (IsCalibrated bit 0) |
| 26-27 | | FarToNear (bit 1) |
| 28-29 | | PulseCount (bit 2) |
| 2A-2B | | LEDdriveStrength (bit 3) |
| 2C-2D | | MarginToCrosstalk (bit 4) |
| 2E-2F | | ThresholdHysteresis (bit 5) |
| 30 | | PrxOffset (bit 6) |
| 34-37 | | HW major revision |
| 38-3B | | DPP config version |
| 3C-13B | | Comment |
| 13C-13F | | IsCalibrated mask. Missing: 0x4F |
| 140-141 | | TargetCrosstalk (bit 7) |

`T900WriteCalibrationDataDPP` (0x4055F8) writes these files back from the current configuration (`ZwCreateFile`, `FILE_OVERWRITE_IF`): the short format when the registry `DppFormat` is 0, the full one otherwise. In the short format, PrxOffset and the IsCalibrated mask are not saved.

> [!NOTE]
> A successful calibration through [IOCTL 0x222000](#ioctl-0x222000--calibration-request) **overwrites** `C:\DPP\Nokia\Sensors\ALS_AVAGO_QPDST900.bin` or `PRX_AVAGO_QPDST900.bin`, the factory calibration of the phone. Save them first.

#### Values of a Lumia 520

Files copied from `C:\DPP\Nokia\Sensors\` of a Lumia 520 (dated 2013-03-05, the phone has the Lite-On sensor, these files are probably left from the factory image). Both are in the short format, i.e. written by this driver with `DppFormat` = 0.

`ALS_AVAGO_QPDST900.bin` (72 bytes):  
| Bytes | Raw | Field | Value |
|-------|-----|-------|-------|
| 24-27 | 00 00 80 3F | Calibration | 1.0 |
| 28-2B | 00 00 80 3F | VisibleCc | 1.0 |
| 2C-2D | 00 00 | VisibleDarkCurrent | 0 |
| 30-33 | 00 00 80 3F | IrCc | 1.0 |
| 34-35 | 00 00 | IrDarkCurrent | 0 |
| 38-3B | 19 60 56 42 | CoeffGA | 53.594 |
| 3C-3F | 4C 4F F2 3F | CoeffB | 1.893 |
| 40-43 | 0A 85 88 3D | CoeffC | 0.0667 |
| 44-47 | A2 D1 DD 3D | CoeffD | 0.1083 |

The 5 calibration fields are marked calibrated (default mask 0x1F) but hold neutral values; the 4 coefficients replace the driver defaults.

`PRX_AVAGO_QPDST900.bin` (48 bytes):  
| Bytes | Raw | Field | Value |
|-------|-----|-------|-------|
| 24-25 | 4F 01 | NearToFar | 335 |
| 26-27 | 81 01 | FarToNear | 385 |
| 28-29 | 03 00 | PulseCount | 3 |
| 2A-2B | 01 00 | LEDdriveStrength | 1 (50 mA) |
| 2C-2D | FA 00 | MarginToCrosstalk | 250 |
| 2E-2F | 32 00 | ThresholdHysteresis | 50 |

### Calibration replay

Each successful calibration request with raw data (methods 1 and 2 of [IOCTL 0x222000](#ioctl-0x222000--calibration-request)) is saved in `C:\DPP\Nokia\Sensors\ALS_AVAGO_QPDST900_CALIB.bin` or `PRX_AVAGO_QPDST900_CALIB.bin` (overwritten each time):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 10 00 00 00 | Header size (16) |
| 04-07 | 01 00 00 00 | Format, must be 1 |
| 08-0B | | Request size (≤ 36 used) |
| 0C-0F | | Raw data size (≤ 136 ALS / 66 PS used) |
| 10-… | | Request (input buffer of the IOCTL) |
| … | | Raw data (the samples measured by the driver) |

`ReplayCalibrationFromFile` (0x409074) reads all the records of the file at every parameter load and executes the request again with the stored raw data, without measuring and without rewriting the DPP file. So a calibration done on the phone survives even if the registry or the DPP static values change.

---

### IOCTL 0x2204B8 — IOCTL_SENSOR_OEM_CALIBRATION_QUERY

This IOCTL is processed by Qpdst900.sys (received through SensorsClx `DeviceIoControl`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x12E (302) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SENSOR_OEM_CALIBRATION_QUERY | 0 | ≥ 68 (ALS) / ≥ 40 (PS) |

ALS instance (last sample):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 44 00 00 00 | Size (68) |
| 04-13 | `AVAGO` | Manufacturer |
| 14-23 | `QPDS-T900` | Model |
| 24-25 | | Raw CH0 |
| 26-27 | | Raw CH1 |
| 28-29 | 00…03 | AGAIN code of the sample (0 = 1X … 3 = 120X) |
| 2A-2B | | IntegrationTime (cycles) |
| 2C-2F | float | CoeffGA |
| 30-33 | float | CoeffB |
| 34-37 | float | CoeffC |
| 38-3B | float | CoeffD |
| 3C-3F | | Lux of the sample with the current configuration (mLux) |
| 40-43 | | Lux without Calibration and without the LuxCorr table (mLux) |

PS instance: `PrxGetRawData` (0x408584) switches to calibration mode, waits for one new PS sample (after one discarded sample, 5 s timeout each) and returns:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 28 00 00 00 | Size (40) |
| 04-13 | `AVAGO` | Manufacturer |
| 14-23 | `QPDS-T900` | Model |
| 24-25 | | Raw PDATA (0…1023) |

A smaller buffer returns `STATUS_BUFFER_TOO_SMALL` (0xC0000023). The PS variant needs the proximity to be running, otherwise it fails after the timeout (`STATUS_UNSUCCESSFUL`).

---

### IOCTL 0x2204BC — IOCTL_SENSOR_OEM_CALIBRATION_READ_DPP

This IOCTL is processed by Qpdst900.sys

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
| 00-… | e.g. `\??\C:\Data\PRX.bin` | NUL-terminated UTF-16 NT path of the DPP file to read instead of the default one |

It reloads the whole configuration (`T900ReadParameters`: defaults, DPP from the given file or the default one when the input is 8 bytes or less, registry, finalization, calibration replay). For the PS instance the new settings are written to the chip (`T900ProximityApplyCalibration`). The returned information is the input length.

> [!NOTE]
> The path comes straight from the request buffer and is opened from kernel mode: any file with the right header can be loaded.

---

### IOCTL 0x2204C0 — IOCTL_SENSOR_OEM_INFO_QUERY

This IOCTL is processed by Qpdst900.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x130 (304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SENSOR_OEM_INFO_QUERY | 0 | ≥ 36 (300 used) |

Outputbuffer (zeroed first):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 2C 01 00 00 | Size (300) |
| 04-13 | `AVAGO/AMS` | Manufacturer |
| 14-23 | `QPDS-T900` / `QPDS-T930` | Model, from the chip ID |
| 24-27 | e.g. `01 29 00 00` | REV / ID registers (if the buffer has 40 bytes) |
| 28-127 | `1.1.5.10` | Driver version string (if the buffer has 296 bytes) |
| 128-12B | 01 00 00 00 | ? (if the buffer has 300 bytes) |

The returned information is the number of bytes filled (36, 40, 296 or 300). Less than 36 bytes: `STATUS_BUFFER_TOO_SMALL`.

---

### IOCTL 0x222000 — Calibration request

This IOCTL is processed by Qpdst900.sys (Nokia OEM IOCTL, name unknown; the log strings call its actions `MTE_…`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 8–36 (larger is truncated) | depends on the method |

Inputbuffer (`CalibrationRequest`, 0x408E70):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 / 02 00 00 00 | Sensor: 1 = ALS, 2 = proximity. Anything else: `STATUS_INVALID_PARAMETER` |
| 04-07 | | Action: 1 = MTE_RESET, 2 = MTE_CALIBRATE_CONTINUE (both not implemented, `STATUS_NOT_IMPLEMENTED`), 4 = calibrate, 5 = value read (PS only) |
| 08-0B | | Action 4: method (see below) |
| 0C-… | | Method parameters |

The measurements wait for samples of the running sensor (the sensor must have been started by a client), 5 s timeout per sample. The output fields are filled as long as the output buffer is large enough; the returned information is the number of bytes filled. After a successful action 4 with raw data, the request and the raw data are saved in the `*_CALIB.bin` file ([Calibration replay](#calibration-replay)).

#### Method 1 "Irradiance" (ALS)

Inputbuffer 0x10-0x13: target illuminance in milli-lux (the light source the phone is exposed to). 0x0C-0x0F: ? (not used).  
The driver takes 3 samples once the gain is stable (raw data 16 bytes: gain index, integration time, 3 × CH0/CH1), computes their lux without Calibration and LuxCorr, takes the median (must be ≥ 10 mLux, otherwise `STATUS_INVALID_PARAMETER_MIX`), and sets **Calibration = target / median**. Then it rewrites the ALS DPP file.  
Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | float | MasterCc (the new Calibration) |
| 04-17 | float[5] | Cc1…Cc5, always 1.0 |
| 18-1B | | VisibleRawSample (CH0 of the median sample) |
| 1C-1F | | IrRawSample (CH1) |
| 20-23 | | MilliLuxes (the target) |

Method 2 (ALS "CALIB_HW") is not implemented.

#### Method 1 "Crosstalk" (proximity)

Nothing in front of the sensor. Median of 11 samples (raw data 22 bytes) = crosstalk. NearToFar = crosstalk + MarginToCrosstalk, FarToNear = NearToFar + ThresholdHysteresis, then the PS DPP file is rewritten and the new thresholds applied (and the dynamic-threshold crosstalk updated).  
Outputbuffer: 00-03 NearToFar, 04-07 FarToNear, 08-0B crosstalk.

#### Method 2 "Reflector" (proximity)

A reference reflector at the detection distance. Median of 11 samples = signal, which must be within ThresholdHysteresis … 1022. FarToNear = signal, NearToFar = signal − ThresholdHysteresis, then the DPP file is rewritten.  
Outputbuffer: 00-03 NearToFar, 04-07 FarToNear.

#### Method 3 "Offset" (proximity, QPDS-T930 only)

Inputbuffer 0x0C-0x0F: target crosstalk, 0 = TargetCrosstalk, ≤ 1023. Needs REV/ID `02 39`, otherwise `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). Starting from offset 0, it measures the median of 11 samples and corrects the offset by −3 × (crosstalk − target) / (2 × PulseCount), at most twice, until the difference is below 10. The offset is kept ≤ 0, written to POFFSET and to the DPP file. It is not recorded for replay (a replay of this method fails with `STATUS_INVALID_PARAMETER_MIX`).  
Outputbuffer: 00-03 new crosstalk, 04-07 POFFSET value ("OffsetFactor").

#### Action 5 "Value read" (proximity)

Waits for one PS sample.  
Outputbuffer: 00-03 ProximityState (0 / 1 / 0xFFFFFFFF), 04-07 RawSample.

---

### IOCTL 0x41808 — IOCTL_SPB_EXECUTE_SEQUENCE

This IOCTL is sent by Qpdst900.sys to qci2c8930.sys (through SpbCx)

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x602 (1538) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SPB_EXECUTE_SEQUENCE | `\Device\RESOURCE_HUB\<connection id>` | 52 | 0 |

`SPB_TRANSFER_LIST` with 2 entries: a write of the 1-byte command, then a read of *n* bytes. Used by every register read.

---

### IOCTL 0x32C018 — IOCTL_ACPI_EVAL_METHOD_EX

This IOCTL is sent by Qpdst900.sys to acpi.sys

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
