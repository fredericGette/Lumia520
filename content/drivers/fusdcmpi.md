## FusDcmpi.sys

**Sensor fusion** driver (orientation sensor), PDB `fusdcmpi.pdb`. The function names in its log strings start with `Dcmpi` ("DCM" = direction cosine matrix ?).  
It's a client of the Microsoft sensor class extension `SensorsClx` ([wpsensorsclx.sys](./wpsensorsclx.md)) with sensor **type 5** (sample of 208 bytes). It has no hardware: it's a root-enumerated device (`IoReportRootDevice` in `DriverEntry`) that opens the accelerometer, magnetometer and gyroscope sensor devices of SensorsClx, reads their samples and computes the orientation of the phone (rotation matrix, Euler angles, quaternion, heading, linear acceleration).  
The algorithm is a complementary filter on the rotation matrix: the gyroscope integrates the rotation, the accelerometer (gravity) and the magnetometer (north) correct its drift with a proportional/integral controller (`KP_*` / `KI_*` [registry values](#registry)). Without gyroscope, the matrix is built from the filtered accelerometer and magnetometer only.  
The log strings call it the "V1 fusion driver" and the SensorsClx sensor drivers the "V2 drivers".

> [!NOTE]
> The Lumia 520 has an accelerometer but **no magnetometer and no gyroscope**. 5 minutes after the start, `CheckForUnloadCondition` finds no magnetometer and removes the device ("Unloading fusion driver because magnetometer was not found."). The acquisition can't start without magnetometer either (see [PowerEnable](#sensorsclx-client)).

There's no device name and no symbolic link created by the driver itself (they are managed by `SensorsClx`). Applications open the fusion sensor through the type 5 device interface that SensorsClx creates:  
`{D4B5AED3-3819-45CB-A3CC-EA862A2013D1}`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\FusDcmpi` ?  

### Registry

Key `HKEY_LOCAL_MACHINE\Software\OEM\Fusion` (opened with `ZwOpenKey` by `FusionOpenRegistry`, 0x10008EF4, at each InitializeHardware). Except `USE_GYRO`, all the values are **REG_SZ** decimal numbers, converted by `WStringToFloat` (0x10008C5C): integer part with `RtlUnicodeStringToInteger`, then at most 3 decimals that are always **added** (so `-0.5` gives 0.5, the same bug as `StringToFloat` of [acckxtnk1000.sys](./acckxtnk1000.md#acpi-device)). A missing value or another type keeps the default.  
| Registry value | value | comment |
|----------------|-------|---------|
| USE_GYRO | 1 | REG_DWORD. 0 = don't use the gyroscope. Stored at context `+0x548` (also set by [USE GYRO MODE](#ioctl-0x220398--set-property)) |
| CACHED_DECL | | Magnetic declination (degrees). Read at start, **written** by the driver when a new declination is set (see below) |
| KI_Mag | 0.001 | Integral gain of the magnetometer correction |
| KP_Mag | 0.2 | Proportional gain of the magnetometer correction |
| KP_Mag_Max | 10.0 | Maximum proportional gain of the magnetometer correction (fast correction mode ?) |
| KI_Acc | 0.001 | Integral gain of the accelerometer correction |
| KP_Acc | 0.4 | Proportional gain of the accelerometer correction |
| KP_Acc_Max | 10.0 | Maximum proportional gain of the accelerometer correction |
| KF_Acc | 0.5 | Low-pass filter factor of the accelerometer samples |
| KF_Mag | 0.5 | Low-pass filter factor of the magnetometer samples |
| KFD_Acc | 0.1 | Second low-pass filter factor of the accelerometer samples (with gyroscope ?) |
| KFD_Mag | 0.1 | Second low-pass filter factor of the magnetometer samples (with gyroscope ?) |
| KMaxLagOnGyro | 0.5 | Seconds without gyroscope sample before "Reset to Fast Correction" ? |
| KFastCorrectionPeriod | 20.0 | Duration of the fast correction mode (s ?) |
| KGyroSaturationThreshold | 1900 | °/s, converted to rad/s. "Gyro saturation detected" |
| KGyroMovingThreshold | 10 | °/s, converted to rad/s. "Gyro indicates significant movement" |
| KAccInPureGravityMax | 1.05 | g. Above, the accelerometer isn't used for the correction ("Accelerometer Magnitude is too low or too big") |
| KAccInPureGravityMin | 0.95 | g. Below, idem |

`CACHED_DECL` is written by `sub_10008E04` with `WdfRegistryCreateKey` (`KEY_WRITE`) + `WdfRegistryAssignValue`, as REG_SZ formatted `"%d.%d"` with the integer part and (|fraction| × 100). The format is lossy: 5.05 is written `"5.5"`, and −0.5 is written `"0.50"` (sign lost).

There's no ETW provider. The driver prints with `vDbgPrintEx(DPFLTR_DEFAULT_ID (101), 0, …)`. Messages have a level 1–5; the masks at `.data:0x10002B98` (`FFFFFFFF FFFFFFFE FFFFFFFE 0 0`) only let errors and warnings through (levels 2 and 3).

Pool tag: `SFus` (`WDF_DRIVER_CONFIG.DriverPoolTag` and registration packet, 0x73754653).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| SensorsClx (class extension) | [wpsensorsclx.sys](./wpsensorsclx.md) | Bound through `WdfVersionBindClass("SensorsClx")` (version 1.0, 6 functions). Polls the fusion samples through GetData |
| Accelerometer interface `{C2FB0F5F-E2D2-4C78-BCD0-352A9582819D}` | [wpsensorsclx.sys](./wpsensorsclx.md) → [acckxtnk1000.sys](./acckxtnk1000.md) | Reads of 40 bytes, interval 25 ms |
| Magnetometer interface `{55E5EFFB-15C7-40DF-8698-A84B7C863C53}` | [wpsensorsclx.sys](./wpsensorsclx.md) → ? (none on the Lumia 520) | Reads of 56 bytes, interval 25 ms |
| Gyroscope interface `{09485F5A-759E-42C2-BD4B-A349B75C8643}` | [wpsensorsclx.sys](./wpsensorsclx.md) → ? (none on the Lumia 520) | Reads of 40 bytes, interval 4 ms |

### SensorsClx client

`DriverEntry` (0x10004E98) creates the WDF driver (`EvtDriverDeviceAdd` 0x10005048, `EvtCleanupCallback` `DcmpiEvtCleanup` 0x10004FEC, which calls `SENSOR_CLX_UnregisterClient`), calls `SENSOR_CLX_RegisterClient` and `IoReportRootDevice`. Registration packet: version 1, size 76, client context size 1384 (0x568), pool tag `SFus`.  
`DcmpiDeviceAdd` calls `SENSOR_CLX_ProcessAddDevicePreDeviceCreate`, `WdfDeviceCreate` and `SENSOR_CLX_ProcessAddDevicePostDeviceCreate` with sensor type 5.  
| Callback | Function | Comment |
|----------|----------|---------|
| InitializeDevice | `DcmpiInitializeDevice` 0x1000880C | Creates the locks and events, registers `IoRegisterPlugPlayNotification` (`EventCategoryDeviceInterfaceChange`, with existing interfaces) on the accelerometer, magnetometer and gyroscope interface GUIDs (callback `sub_100099BC`, see [Primary sensors](#primary-sensors)), and creates 4 system threads: `FusionProcessingThread` (0x100073DC), `AccDataListenerThread` (0x10006CDC), `MagDataListenerThread` (0x10006E90), `GyroDataListenerThread` (0x10007044) |
| UnInitializeDevice | `DcmpiUnInitializeDevice` 0x100092D0 | Stop flag (`+0x4F1`), unregisters the notifications, wakes and waits for the 4 threads, deletes the I/O targets and the locks |
| InitializeHardware | `DcmpiInitializeHardware` 0x100091A0 | Clears the state, reads the [registry](#registry), starts a one-shot timer of **300 s** (`CheckForUnloadCondition`, 0x10004DD8) |
| QueryDeviceInformation | `DcmpiQueryDeviceInformation` 0x100050E4 | Version 1, size 24, sensor type 5, maximum sample size 208, number of ranges 1, capabilities 1 (`SENSOR_CAPS_CLX_POLL`), flags 1 |
| GetSensorTiming | `DcmpiGetSensorTiming` 0x10005150 | `100`, `50`, minimum sample time 16 ms |
| AbortReading | `DcmpiAbortReading` 0x100051B8 | No-op (only checks the context) |
| GetData | `DcmpiGetData` 0x10007D74 | Fills the [fusion sample](#fusion-sample) (buffer ≥ 208 bytes, otherwise `STATUS_INVALID_PARAMETER`). Also (re)starts the fusion and records the time of the call. No output yet: `STATUS_DEVICE_NOT_READY` (0xC00000A3) |
| PowerEnable | `DcmpiPowerEnable` 0x10007C28 | Stores on/off (`+0x4F0`). On: if the fusion isn't running and a magnetometer is open, resets the rotation matrix to identity, notes if a gyroscope is open, and wakes `FusionProcessingThread` |
| DeviceIoControl | `DcmpiDeviceIoControl` 0x10009498 | The 3 IOCTLs below. Anything else: `STATUS_NOT_IMPLEMENTED` (0xC0000002) |

GetRangeResolution, SetRangeResolution, SetInterval, StartReading, StartAcquisition, StopAcquisition and InterruptEnable are not provided.

`CheckForUnloadCondition`: no accelerometer open (context `+0x30`) → error "unloading fusion driver because accelerometer was not found", no magnetometer open (`+0x44`) → "Unloading fusion driver because magnetometer was not found". In both cases `WdfDeviceSetDeviceState(Removed = WdfTrue)`: PnP removes the device and the driver unloads.

### Primary sensors

Context `+0x28`: 3 entries of 20 bytes (accelerometer, magnetometer, gyroscope):  
| Offset | Comment |
|--------|---------|
| 00 | Interface class GUID |
| 04 | PnP notification entry |
| 08 | `WDFIOTARGET` of the sensor (accelerometer `+0x30`, magnetometer `+0x44`, gyroscope `+0x58`) |
| 0C | 1 = this sensor is primary |
| 10 | `WDFDEVICE` |

`sub_100099BC` (PnP notification):
* `GUID_DEVICE_INTERFACE_ARRIVAL`: if a target is already open and marked primary, "Skipping second driver of same type, Primary already found.". Otherwise the old target is closed and a new one is opened by name (`WdfIoTargetCreate` + `WdfIoTargetOpen`, `GENERIC_READ | GENERIC_WRITE`, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`). Then [IOCTL 0x220020](./wpsensorsclx.md#ioctl-0x220020--isprimarysensor) (IsPrimarySensor, 4-byte output) sets the primary flag. If the target can't be created or opened: "Unloading V1 fusion driver because WdfIoTargetOpen failed to communicate with V2 drivers" and `WdfDeviceSetDeviceState(Removed)`.
* `GUID_DEVICE_INTERFACE_REMOVAL`: closes and deletes the target.

### Threads

`FusionProcessingThread` sleeps until PowerEnable/GetData wakes it. When the fusion runs:
1. Starts each sensor (`sub_100071F8`): [IOCTL 0x220024](#ioctl-0x220024--enableidleoperation) with 1, then [IOCTL 0x220014](#ioctl-0x220014--notificationconfigure) and [IOCTL 0x220018](#ioctl-0x220018--notificationstart) (`KSensorStart`). Interval 25 000 µs for the accelerometer and the magnetometer, 4 000 µs for the gyroscope. The gyroscope is started only if `USE_GYRO` is set. A failure is only a warning.
2. Waits for a new sample (one event per sensor). Accelerometer and magnetometer samples are low-pass filtered (`sub_10006988`: v = prev + (new − prev) × k) and stored at context `+0x1C0` (last accelerometer sample, 40 bytes, then last magnetometer sample, 56 bytes). Each gyroscope sample runs `UpdateFusion` (`sub_10005468`). Without gyroscope, each magnetometer sample runs it.
3. **3 s without GetData** ("Timeout since last GetData"): stops the sensors (`KSensorStop`: [IOCTL 0x22001C](#ioctl-0x22001c--notificationstop), then IOCTL 0x220024 with 0) and goes back to sleep.

The 3 listener threads (priority 16) loop on a read of the sensor target (`WdfIoTargetFormatRequestForRead` + `WdfRequestSend`, buffer in the context) while the sensor is started. Completion routines (0x10006A08, 0x10006AD4, 0x10006BA0) drop samples with a NaN, copy the sample under a spin lock and signal the fusion thread. The gyroscope samples go to a ring of 10 entries (context `+0x310`).

Samples read (layout of [wpsensorsclx.sys](./wpsensorsclx.md#client-interface)):  
| Sensor | Size | Values used |
|--------|------|-------------|
| Accelerometer | 40 | X, Y, Z (floats, g) at 0x18 |
| Magnetometer | 56 | X, Y, Z (floats) at 0x24 (used by the fusion, checked for NaN). 3 other floats at 0x18 (logged as "Read Magnetometer Data") and a WORD at 0x30 (copied, at most 180, to the fusion sample) |
| Gyroscope | 40 | X, Y, Z (floats, rad/s ?) at 0x18 |

### Fusion sample

Returned by GetData (and so by a read of the fusion sensor device). 208 bytes:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | D0 00 00 00 | Size (208) |
| 08-0F | | `KeQueryInterruptTime` (100 ns) |
| 10-13 | 05 00 00 00 | Sensor type (5) |
| 18-1B | 01 00 00 00 / 03 00 00 00 | Flags. bit 0: valid. bit 1: gyroscope used (or override) |
| 1C-1F | | Magnetic heading (float, degrees, 0–360), from the rotation matrix (`sub_10007CC4`) |
| 20-23 | | Declination (float, degrees) |
| 24-27 | | True heading = magnetic heading − declination, 0–360 (float, degrees) |
| 28-2B | 02 00 00 00 / 05 00 00 00 | Matrix column used for the heading: 5 when \|m7\| > 0.707 (phone upright ?), 2 otherwise |
| 2C-2D | | WORD at 0x30 of the magnetometer sample, at most 180 (accuracy ?) |
| 30-3B | | 3 floats at 0x18 of the magnetometer sample |
| 3C-47 | | 3 floats at 0x24 of the magnetometer sample |
| 48-53 | | Gravity: −m6, −m7, −m8 (floats, g) |
| 54-77 | | Rotation matrix m0…m8 (9 floats, row-major) |
| 78-7B | | Pitch (float, degrees) |
| 7C-7F | | Roll (float, degrees) |
| 80-83 | | Yaw (float, degrees) |
| 84-93 | | Quaternion X, Y, Z, W (floats) |
| 94-B7 | | Rotation matrix again (9 floats) |
| B8-C3 | | Angular velocity X, Y, Z (floats, °/s) |
| C4-CF | | Linear acceleration X, Y, Z = −gravity − accelerometer (floats, g) |

When the [override](#ioctl-0x220628--set-override-data) is active, the matrix, the angular velocity and the linear acceleration come from the override data.

Effective declination (`+0x290`): the value set by [DECLINATION OUTPUT](#ioctl-0x220398--set-property), or (override value − 1000) when a declination override is active.

---

### IOCTL 0x220394 — Get property

This IOCTL is processed by FusDcmpi.sys (received through SensorsClx `DeviceIoControl`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xE5 (229) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get property | ≤ 64 | 1 or ≥ 4 (see below) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | | Property name, UTF-16, compared case-insensitively on (input size / 2) characters |

Outputbuffer:  
| Property name | Size | Value |
|---------------|------|-------|
| `DECLINATION OUTPUT` | 4 | Declination set by [IOCTL 0x220398](#ioctl-0x220398--set-property) (float, degrees) |
| `OVERRIDE OUTPUT` | 1 | 1 = override active |
| `MAG MARGIN PRECISE` | 4 | 10.0 (float, constant) |
| `MAG MARGIN ACCURATE` | 4 | 20.0 (float, constant) |
| `MAG MARGIN POOR` | 4 | 30.0 (float, constant) |
| `HARDWARE PRESENT` | 1 | 1 if an accelerometer and a magnetometer are open |

Output too small: `STATUS_BUFFER_TOO_SMALL` (0xC0000023). Input > 64 bytes: `STATUS_NOT_IMPLEMENTED` (0xC0000002). Unknown name: `STATUS_OBJECT_NAME_NOT_FOUND` (0xC0000034).

---

### IOCTL 0x220398 — Set property

This IOCTL is processed by FusDcmpi.sys (received through SensorsClx `DeviceIoControl`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xE6 (230) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set property | 42, 33 or 29 | 0 |

Inputbuffer for `DECLINATION OUTPUT` (42 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-25 | `DECLINATION OUTPUT\0` | UTF-16 |
| 26-29 | | Declination (float, degrees) |

* Value ≤ 499: new declination (`+0x28C`). If it's the first one or it changed by ≥ 0.00001, it's written to `CACHED_DECL` ([registry](#registry)).
* Value > 499: declination override. 500 = off, any other value = on with declination (value − 1000).

The time of the call is stored (`+0x540`).

Inputbuffer for `OVERRIDE OUTPUT` (33 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-1F | `OVERRIDE OUTPUT\0` | UTF-16 |
| 20 | 00 / 01 | Override flag (`+0x1A8`), see [IOCTL 0x220628](#ioctl-0x220628--set-override-data) |

Inputbuffer for `USE GYRO MODE` (29 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-1B | `USE GYRO MODE\0` | UTF-16 |
| 1C | 00 / 01 | Use the gyroscope (`+0x548`, same flag as `USE_GYRO`) |

Wrong size: `STATUS_BUFFER_TOO_SMALL` (0xC0000023). Unknown name: `STATUS_OBJECT_NAME_NOT_FOUND` (0xC0000034).

---

### IOCTL 0x220628 — Set override data

This IOCTL is processed by FusDcmpi.sys (received through SensorsClx `DeviceIoControl`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x18A (394) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set override data ? | 60 | 0 |

Inputbuffer (copied to `+0x220`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-23 | | Rotation matrix (9 floats) |
| 24-2F | | Linear acceleration X, Y, Z (floats, g) |
| 30-3B | | Angular velocity X, Y, Z (floats, °/s) |

Sets the override flag: from now on the [fusion sample](#fusion-sample) is computed from these values instead of the sensors (test / simulation ?). `OVERRIDE OUTPUT` = 0 turns it off. Another size: `STATUS_NOT_IMPLEMENTED` (0xC0000002).

---

### IOCTL 0x220014 — NotificationConfigure

This IOCTL is sent by FusDcmpi.sys to the accelerometer, magnetometer and gyroscope sensor devices ([wpsensorsclx.sys](./wpsensorsclx.md#ioctl-0x220014--notificationconfigure))

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x5 (5) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| NotificationConfigure | Sensor interface | 24 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 18 00 00 00 | Total size (24) |
| 04-07 | 00 00 00 00 | Flags: mode 0 (every interval) |
| 08-0B | A8 61 00 00 / A0 0F 00 00 | Interval: 25 000 µs (accelerometer, magnetometer), 4 000 µs (gyroscope) |
| 0C-17 | 00 … | No threshold |

---

### IOCTL 0x220018 — NotificationStart

This IOCTL is sent by FusDcmpi.sys to the sensor devices, after [IOCTL 0x220014](#ioctl-0x220014--notificationconfigure) ([wpsensorsclx.sys](./wpsensorsclx.md#ioctl-0x220018--notificationstart))

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x6 (6) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| NotificationStart | Sensor interface | 0 | 0 |

---

### IOCTL 0x22001C — NotificationStop

This IOCTL is sent by FusDcmpi.sys to the sensor devices ([wpsensorsclx.sys](./wpsensorsclx.md#ioctl-0x22001c--notificationstop))

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x7 (7) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| NotificationStop | Sensor interface | 0 | 0 |

---

### IOCTL 0x220020 — IsPrimarySensor

This IOCTL is sent by FusDcmpi.sys to each new sensor device ([wpsensorsclx.sys](./wpsensorsclx.md#ioctl-0x220020--isprimarysensor))

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x8 (8) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IsPrimarySensor | Sensor interface | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Not 0 = primary sensor (see [Primary sensors](#primary-sensors)) |

---

### IOCTL 0x220024 — EnableIdleOperation

This IOCTL is sent by FusDcmpi.sys to the sensor devices ([wpsensorsclx.sys](./wpsensorsclx.md#ioctl-0x220024--enableidleoperation))

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x9 (9) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| EnableIdleOperation | Sensor interface | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 / 00 00 00 00 | 1 before starting the sensor, 0 after stopping it. The result is ignored |

---

### Interface GUID

Fusion sensor (type 5), created by SensorsClx  
`{D4B5AED3-3819-45CB-A3CC-EA862A2013D1}`

### Other GUID

Accelerometer interface (PnP notification)  
`{C2FB0F5F-E2D2-4C78-BCD0-352A9582819D}`  
Magnetometer interface (PnP notification)  
`{55E5EFFB-15C7-40DF-8698-A84B7C863C53}`  
Gyroscope interface (PnP notification)  
`{09485F5A-759E-42C2-BD4B-A349B75C8643}`
