## Acckxtnk1000.sys

Driver of the Kionix **KXTNK-1000** 3-axis accelerometer (I²C address 0x1E). It also accepts an ST part reported as **LISN3DSH**.  
It's a client of the Microsoft sensor class extension `SensorsClx` ([wpsensorsclx.sys](./wpsensorsclx.md)) (KMDF, PDB `E:\build_e\subtask\D06E3E63_98\output\sensors\fre\AccKXTNK1000.pdb`). It has no device name of its own: the sensor device and its interface are managed by SensorsClx, which calls the driver through a table of callbacks (see [SensorsClx client](#sensorsclx-client)). It's built on the same Nokia framework as [ltr554als02.sys](./ltr554als02.md) and [qpdst900.sys](./qpdst900.md) (same SensorsClx glue, I²C helpers, log format, DPP file), but much simpler: one ACPI device, one instance, no registry parameters, no test mode.  
The samples are **polled**: a system thread reads the chip at the interval requested by SensorsClx and pushes each sample (X, Y, Z in g). The chip interrupt is only counted, to check it during the [self test](#ioctl-0x2204b4--self-test).  
The raw values are converted to g, corrected by the offsets of `C:\DPP\Nokia\Sensors\ACC_KIONIX_KXTNK1000.bin` and rotated into the phone coordinate system with the matrix of the ACPI method `ROTM`.

There's no device name and no symbolic link created by the driver itself (they are managed by `SensorsClx`). Applications open the sensor through the accelerometer device interface that SensorsClx creates:  
`{C2FB0F5F-E2D2-4C78-BCD0-352A9582819D}`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\AccKXTNK1000` ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\KXTNK\1`  

There's no parameters in the registry (the driver doesn't open any registry key). The calibration offsets that SensorsClx itself applies are stored in `HKLM\System\Sensors\Acc\Calibration` (see [wpsensorsclx.sys](./wpsensorsclx.md#accelerometer)).

There's no ETW provider. The driver prints with `vDbgPrintEx(DPFLTR_DEFAULT_ID (101), 0, …)`. Messages have a level 1–5; the masks at `.data:0x00409150` (`FFFFFFFF FFFFFFFE FFFFFFFE 0 0`) only let errors and warnings through (levels 2 and 3).

Pool tags: `ccAS` (`WDF_DRIVER_CONFIG.DriverPoolTag` and registration packet, 0x63634153), `UTLx` (0x784C5455, ACPI evaluation buffer).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| SensorsClx (class extension) | [wpsensorsclx.sys](./wpsensorsclx.md) | Bound through `WdfVersionBindClass("SensorsClx")`. Receives the samples, calls the callbacks |
| `\Device\RESOURCE_HUB\<connection id>` | [acpiex.sys](./acpiex.md) → [qci2c8930.sys](./qci2c8930.md) | I²C connection to `\_SB.IC12`, address 0x1E, 400 kHz. Opened with `WdfIoTargetOpen` |
| Own ACPI PDO (`WdfDeviceGetIoTarget`) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD_EX` (0x32C018) to evaluate `ROTM` |
| GPIO interrupt | [qcgpio.sys](./qcgpio.md) | One `WdfInterrupt` with passive-level handling (`IsrAtPassive` 0x401928), i.e. the first `GpioInt` of `_CRS` (GPIO 46 ?). Only counts the interrupts |
| File `C:\DPP\Nokia\Sensors\ACC_KIONIX_KXTNK1000.bin` | file system | Read only, see [DPP calibration file](#dpp-calibration-file) |

### ACPI device

From the Nokia SSDT ([ssdt.dsl](../acpi/ssdt.dsl)), `\_SB.ACC1`, `_HID` `KXTNK`, `_UID` 1, `_DEP` on `\_SB.PRXY`. `_CRS`:
* `I2cSerialBus`: slave address 0x1E, 7-bit, 400 kHz, `\_SB.IC12`.
* `GpioInt`: GPIO 46 (0x2E) of `\_SB.GIO0`, edge, active low, exclusive, pull-down.
* `GpioInt`: GPIO 67 (0x43) of `\_SB.GIO0`, same settings.

`_PS0` … `_PS3` write `\_SB.ACC1` + D-state to `\_SB.PRXY` ([qcpepproxy8930.sys](./qcpepproxy8930.md)).

`ROTM` returns a package of 3 strings, one per row of the rotation matrix. Lumia 520:  
| Row | Value |
|-----|-------|
| 0 | `"1 0 0"` |
| 1 | `"0 1 0"` |
| 2 | `"0 0 -1"` |

`GetRotationMatrixFromAcpi` (0x403BEC) checks the `AeoB` signature and a count of 3; each element must be a string (type 1) of 5–20 bytes. `ParseRotationMatrixEntry` (0x403B0C) splits it at the spaces and converts each number with `StringToFloat` (0x4035D0): integer part with `RtlUnicodeStringToInteger`, then at most 3 decimals that are always **added** (so `-0.5` gives 0.5 and `-1.5` gives −0.5, a bug that doesn't matter for a matrix of 0 / ±1). If `ROTM` fails, `KXTNInitializeDevice` continues without rotation (context `+0x2C` = 0).

`TranslateAxes` (0x40374C) computes v' = M × v (M row-major at context `+0x08`). With the Lumia 520 matrix, Z is inverted.

### SensorsClx client

`DriverEntry` (0x403454) creates the WDF driver (`EvtDriverDeviceAdd` = `KXTNDeviceAdd` 0x401F3C, `EvtCleanupCallback` = `KXTNEvtCleanup` 0x403570, which calls `SENSOR_CLX_UnregisterClient`) and calls `SENSOR_CLX_RegisterClient`. Registration packet: version 1, size 76, client context size 120, pool tag `ccAS`.  
`KXTNDeviceAdd` calls `SENSOR_CLX_ProcessAddDevicePreDeviceCreate`, `WdfDeviceCreate`, `WdfInterruptCreate` (passive handling, `IsrAtPassive`) and `SENSOR_CLX_ProcessAddDevicePostDeviceCreate`.  
| Callback | Function | Comment |
|----------|----------|---------|
| InitializeDevice | `KXTNInitializeDevice` 0x40201C | Looks for the I²C connection resource (`CM_RESOURCE_CONNECTION_CLASS_SERIAL`, type I2C; interrupts are skipped, any other resource is logged as invalid), opens `\Device\RESOURCE_HUB\<id>`, creates the wait lock, reads `ROTM`, creates the worker thread `AccThreadProc` (0x401A6C). No I²C connection: `STATUS_UNSUCCESSFUL` |
| UnInitializeDevice | `KXTNUnInitializeDevice` 0x40227C | Stops the worker thread (stop flag + event, waits for it), deletes the I²C target |
| InitializeHardware | `KXTNInitializeHardware` 0x402800 | Reads WHO_AM_I (0x0F): 0x6E = Kionix, 0x3B = ST, otherwise `STATUS_NOT_SUPPORTED` (0xC00000BB). Reads INFO1/INFO2 (0x0D, 2 bytes, failure is only a warning), the 4 control registers 0x1B–0x1E into the shadow at context `+0x4C`, the [DPP file](#dpp-calibration-file) (failure ignored), range index = 0 |
| QueryDeviceInformation | `KXTNQueryDeviceInformation` 0x402304 | Version 1, size 24, sensor type 0 (accelerometer), maximum sample size 40, number of ranges 4, capabilities 2 (`SENSOR_CAPS_CLIENT_PUSH`), flags 1 |
| GetRangeResolution | `KXTNGetRangeResolution` 0x40294C | Index 0–3, or −1 = current range. Returns minimum, maximum, resolution (floats, g) from the [range table](#ranges). Other index or buffer < 4 bytes: `STATUS_INVALID_PARAMETER` |
| SetRangeResolution | `KXTNSetRangeResolution` 0x402A00 | Index 0–3. Writes the range code to CNTL1 bits 5–6 |
| GetSensorTiming | `KXTNGetSensorTiming` 0x402420 | `2`, `1`, minimum sample time 10 ms |
| StartAcquisition | `KXTNStartAcquisition` 0x40235C | Interval in µs, no minimum check. Sets the CNTL1 data rate (bits 2–4: `101` if interval ≥ 11 ms, `110` otherwise) and wakes the worker thread |
| PowerEnable | `KXTNPowerEnable` 0x402490 | CNTL1 bit 7 (PC) = on/off. On: timer resolution 1 ms (`ExSetTimerResolution(10000, TRUE)`). Off: interval = −1 (thread stops sampling), timer resolution released |
| DeviceIoControl | `KXTNDeviceIoControl` 0x4032E0 | The 4 IOCTLs below. Anything else: `STATUS_NOT_IMPLEMENTED` (0xC0000002) |

SetInterval, StartReading, AbortReading, GetData, StopAcquisition and InterruptEnable are not provided: the acquisition stops through PowerEnable(off).

Context of the device (120 bytes):  
| Offset | Comment |
|--------|---------|
| 00 | I²C `WDFIOTARGET` |
| 04 | `WDFWAITLOCK` (`LockSensor` 0x4019DC / `UnlockSensor` 0x401A28) |
| 08-2B | Rotation matrix, 9 floats |
| 2C | 1 = rotation matrix valid |
| 30-38 | Last sample in g, before offsets and rotation (X, Y, Z floats) |
| 3C-44 | Calibration offsets X, Y, Z (floats, g) from the DPP file |
| 48 | Current range index |
| 4C-4F | Shadow of registers 0x1B–0x1E |
| 50 | Interrupt counter (incremented by `IsrAtPassive`) |
| 54 | `KEVENT` of the worker thread |
| 64 | Stop flag |
| 68 | Sampling interval (µs), 0xFFFFFFFF = stopped |
| 6C | Worker thread object |
| 70 | `WDFDEVICE` |
| 74 | 1 = Kionix, 0 = ST |
| 75-76 | INFO1, INFO2 |

### Chip registers

Accessed with `I2CSensorReadRegister` (0x4037F8, `IOCTL_SPB_EXECUTE_SEQUENCE`: write of the register number + read) and `I2CSensorWriteRegister` (0x40398C, `WdfIoTargetSendWriteSynchronously` of register + up to 16 bytes), timeout 250 ms. `I2CRead` / `I2CWrite` (0x4017E0 / 0x401884) retry 5 times. Register names are those of the log strings, the others are guesses.  
| Register | Name | Use |
|----------|------|-----|
| 0x0D-0x0E | INFO1, INFO2 | Read once, returned by [IOCTL 0x2204C0](#ioctl-0x2204c0--ioctl_sensor_oem_info_query) |
| 0x0F | WHO_AM_I | 0x6E Kionix (KXTNK-1000), 0x3B ST (LISN3DSH) |
| 0x10-0x15 | XOUT, YOUT, ZOUT | Little-endian 16-bit words, bits 0–11 used (sign-extended 12-bit value) |
| 0x18 | STATUS ? | bit 0 = new data ready |
| 0x1B | CNTL1 | bit 7 PC (operating mode), bits 5–6 range, bits 2–4 data rate, bit 0 ? |
| 0x1C-0x1D | ? | Only saved / restored |
| 0x1E | ? | bit 1 = self test, bits 3 and 7 set during the self test (interrupt enable ?) |

#### Ranges

Table at `.data:0x00409168` (16 bytes per entry: min, max, resolution as floats, CNTL1 code):  
| Index | Range | Resolution (g/count) | CNTL1 bits 5–6 |
|-------|-------|----------------------|----------------|
| 0 | ±2 g | 1/1024 | 00 |
| 1 | ±4 g | 1/512 | 01 |
| 2 | ±6 g | 3/1024 | 10 |
| 3 | ±8 g | 1/256 | 11 |

### Sampling

`AccThreadProc` (priority 16) waits on its event, with no timeout while the interval is −1. When the event is set it reads the new interval, waits 10 ms, then starts a periodic timer (`PeriodicTimerInit` 0x4015CC). At each timeout it calls `PushSample` and computes the next wait (`PeriodicTimerGetWaitTime` 0x401644: missed periods are skipped, there's no drift).

`PushSample` (0x401CC8), under the wait lock, does nothing if the interval is −1. Otherwise `KXTNKReadSample` (0x401B74):
1. Reads 0x18 until bit 0 is set, 3 tries with 1 ms sleep, otherwise `STATUS_UNSUCCESSFUL` ("Data not ready").
2. Reads the 6 data bytes from 0x10 until two consecutive reads are identical (at most 5 reads), otherwise `STATUS_UNSUCCESSFUL` ("Can't get consistent data").

Each axis = count × resolution of the current range (stored at context `+0x30`) − DPP offset, then rotated by `ROTM`. The sample goes to SensorsClx (`SensorClxSampleReady`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 28 00 00 00 | Size (40) |
| 08-0F | | `KeQueryInterruptTime` (100 ns) |
| 10-13 | 00 00 00 00 | Sensor type (0 = accelerometer) |
| 18-1B | float | X (g) |
| 1C-1F | float | Y (g) |
| 20-23 | float | Z (g) |

### DPP calibration file

`KXTNReadCalibrationData` (0x402578) opens `\??\C:\DPP\Nokia\Sensors\ACC_KIONIX_KXTNK1000.bin` (or the path given by [IOCTL 0x2204BC](#ioctl-0x2204bc--ioctl_sensor_oem_calibration_read_dpp)) with `ZwOpenFile` and reads 48 bytes. The read must return exactly 48 bytes, otherwise the offsets are left unchanged ("calibration data read failure"). A wrong size, manufacturer or model gives `STATUS_INVALID_PARAMETER_MIX` (0xC00000E5). The driver never writes this file.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 30 00 00 00 | Size (48) |
| 04-13 | `KIONIX` | Manufacturer, NUL-padded (7 bytes compared) |
| 14-23 | `KXTNK-1000` | Model, NUL-padded (11 bytes compared) |
| 24-27 | float | X offset (g), subtracted from X |
| 28-2B | float | Y offset (g) |
| 2C-2F | float | Z offset (g) |

The offsets are applied in the component coordinate system, before the rotation.

#### Values of a Lumia 520

File copied from `C:\DPP\Nokia\Sensors\` of a Lumia 520 (dated 2013-03-05, 48 bytes): `30 00 00 00`, `KIONIX`, `KXTNK-1000`, and the 3 offsets are `00 00 00 00` (0.0). The factory calibration of this phone is therefore neutral.

---

### IOCTL 0x2204B4 — Self test

This IOCTL is processed by Acckxtnk1000.sys (received through SensorsClx `DeviceIoControl`; name unknown, it follows the `IOCTL_SENSOR_OEM_*` codes)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x12D (301) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | ≥ 76 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 4C 00 00 00 | Size (76) |
| 04-13 | `KIONIX` | Manufacturer |
| 14-23 | `KXTNK-1000` | Model |
| 24-27 | | Result: 0 = passed, 1 = not completed (failed before the measurements), 2 = an axis failed, 3 = power off / restore failed after the test, 4 = less than 2 interrupts |
| 28-33 | float[3] | Average X, Y, Z without self test (g) |
| 34-3F | float[3] | Average X, Y, Z with self test (g) |
| 40-4B | CD CC 4C 3D × 3 | Minimum difference per axis (0.05 g) |

`KXTNPerformSelfTest` (0x402E6C):
1. Power off (CNTL1 PC = 0); register 0x1E |= 0x88, CNTL1 = (CNTL1 & 0x82) | 0x15 (range ±2 g, data rate `101`, bit 0), write 0x1B–0x1E; interrupt counter = 0.
2. Power on, 50 ms, average of 10 samples (`KXTNKGetAverageSample` 0x402ACC: for each sample, up to 20 polls of 0x18 bit 0 without delay, then read; no offset, no rotation, "component coordinate system").
3. Power off, 0x1E |= 0x02 (self test), power on, 50 ms, average of 10 samples.
4. Each axis must change by at least 0.05 g, otherwise result 2.
5. Power off, at least 2 interrupts must have been counted (result 4), write back the 4 saved registers, power on.

The returned information is 76 (except for `STATUS_INVALID_PARAMETER`); a smaller buffer gives `STATUS_BUFFER_TOO_SMALL` (0xC0000023).

> [!NOTE]
> The test doesn't take the wait lock, so it can run while the worker thread reads samples. At the end, the 4 registers are restored, but then CNTL1 is written again with the **test** value + PC: the chip stays at ±2 g and powered on, while the driver still uses the resolution of the previous range (a bug ?).

---

### IOCTL 0x2204B8 — IOCTL_SENSOR_OEM_CALIBRATION_QUERY

This IOCTL is processed by Acckxtnk1000.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x12E (302) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SENSOR_OEM_CALIBRATION_QUERY | 0 | ≥ 48 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 30 00 00 00 | Size (48) |
| 04-13 | `KIONIX` | Manufacturer |
| 14-23 | `KXTNK-1000` | Model |
| 24-27 | float | X of the last sample (g), before offsets and rotation |
| 28-2B | float | Y |
| 2C-2F | float | Z |

The returned information is 48. A smaller buffer: `STATUS_BUFFER_TOO_SMALL` (0xC0000023). It doesn't measure: the sensor must be running to get a recent value.

---

### IOCTL 0x2204BC — IOCTL_SENSOR_OEM_CALIBRATION_READ_DPP

This IOCTL is processed by Acckxtnk1000.sys

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
| 00-… | e.g. `\??\C:\Data\ACC.bin` | NUL-terminated UTF-16 NT path of the DPP file to read instead of the default one |

Reloads the calibration offsets from the file (see [DPP calibration file](#dpp-calibration-file)), under the wait lock. The returned information is the input length; the status is the one of the read.

> [!NOTE]
> The path comes straight from the request buffer and is opened from kernel mode: any file with the right header can be loaded.

---

### IOCTL 0x2204C0 — IOCTL_SENSOR_OEM_INFO_QUERY

This IOCTL is processed by Acckxtnk1000.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x130 (304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SENSOR_OEM_INFO_QUERY | 0 | ≥ 36 (300 used) |

Outputbuffer (built in the global `.data:0x00409AF0`, then the first min(size, 300) bytes are copied):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 2C 01 00 00 | Size (300) |
| 04-13 | `KIONIX` / `ST` | Manufacturer, from WHO_AM_I |
| 14-23 | `KXTNK-1000` / `LISN3DSH` | Model |
| 24-27 | e.g. `xx yy 00 00` | INFO1, INFO2 |
| 28-127 | 00 … | Driver version string: empty |
| 128-12B | 01 00 00 00 | ? |

The returned information is min(output size, 300). Less than 36 bytes: `STATUS_BUFFER_TOO_SMALL`.

---

### IOCTL 0x41808 — IOCTL_SPB_EXECUTE_SEQUENCE

This IOCTL is sent by Acckxtnk1000.sys to qci2c8930.sys (through SpbCx)

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x602 (1538) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SPB_EXECUTE_SEQUENCE | `\Device\RESOURCE_HUB\<connection id>` | 52 | 0 |

`SPB_TRANSFER_LIST` with 2 entries: a write of the 1-byte register number, then a read of *n* bytes. Used by every register read.

---

### IOCTL 0x32C018 — IOCTL_ACPI_EVAL_METHOD_EX

This IOCTL is sent by Acckxtnk1000.sys to acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x6 (6) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD_EX | Own PDO | 260 | 83 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 41 | `AeiA` |
| 04-08 | `ROTM` | Method name, NUL-terminated |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | `AeoB` |
| 04-07 | | Length |
| 08-0B | 03 00 00 00 | Count |
| 0C-… | | 3 × `ACPI_METHOD_ARGUMENT`: type 1 (string), length 5–20, the row text (e.g. `1 0 0`) |
