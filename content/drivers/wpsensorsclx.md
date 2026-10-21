## Wpsensorsclx.sys

Windows Phone **sensor class extension** (`SensorsClx`), PDB `wpsensorsclx.pdb`.  
It's a KMDF class library: it registers itself with `WdfRegisterClassLibrary` and the sensor drivers bind to it with `WdfVersionBindClass("SensorsClx")` (see [ltr554als02.sys](./ltr554als02.md)). The client driver only talks to the chip. Everything else is done by SensorsClx: PnP/power callbacks, the device interface, the I/O queues, the subscribers (one per opened handle), the notification modes and thresholds, the polling thread, the idle settings and the device security.  
On the Lumia 520 its clients are the accelerometer `\_SB.ACC1` (`KXTNK`, Kionix) and the ALS/proximity sensors `\_SB.ALS1`/`\_SB.PRX1` (`QPDS_T900`) or `\_SB.ALS2`/`\_SB.PRX2` ([ltr554als02.sys](./ltr554als02.md)). See the Nokia SSDT ([ssdt.dsl](../acpi/ssdt.dsl)).  
It also has accelerometer code (calibration file `C:\DPP\Sensors\Accelerometer.bin`, see [Accelerometer](#accelerometer)) and gyroscope code (DC offset filter). There's no gyroscope on the Lumia 520.

Device name : `\Device\WPSensorClassExt<n>` (control device, see below)  
There's no symbolic link. The sensor devices themselves are reached through their [device interface](#interface-guids).  

`SensorpClassLibraryCreate` (0x100097B8) creates a control device with `WdfControlDeviceInitAllocate` (SDDL `D:P`: empty DACL, so no access from user mode), named `\Device\WPSensorClassExt0` (the index is incremented while `WdfDeviceCreate` returns `STATUS_OBJECT_NAME_COLLISION`). This name is given to `WdfRegisterClassLibrary`.  
`WDF_CLASS_LIBRARY_INFO` (`.data:0x10013068`): version 1.0.0, `SensorClxClassLibraryInitialize` 0x100096C4, `SensorClxClassLibraryDeinitialize` 0x100096EC, `SensorClxClassLibraryBindClient` 0x10009720, `SensorClxClassLibraryUnbindClient` 0x10009784.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\SensorsClx0101` ? (KMDF class extensions are registered as `<ClassName><Major><Minor>`. The key is read by the driver, see below)  

There's no `Parameters` key.

Registry values read by the driver:  
| Registry key | Value | comment |
|--------------|-------|---------|
| Service key of each **client** driver (`WdfDriverGetRegistryPath`) | EnableOemSecurity | REG_DWORD. Not 0 = keep the security of the client device as is. Otherwise `WpSecurity` is applied (see [Device security](#device-security)) |
| `HKLM\SYSTEM\ControlSet001\Services\SensorsClx0101` | WpSecurity | REG_BINARY, self-relative security descriptor. Its DACL is applied to every sensor device |
| `HKLM\System\Sensors\Acc\Calibration` | ACC_X_OFFSET_\<n\>, ACC_Y_OFFSET_\<n\>, ACC_Z_OFFSET_\<n\> | REG_BINARY, 4 bytes (float, in g), one set per accelerometer range \<n\>. Read at start, written after a calibration or after reading the DPP file. The keys `\System\Sensors`, `\Sensors\Acc` and `\Acc\Calibration` are created if needed |
| Service key of wpsensorsclx (gyroscope only) | EnableMsftDCOffsetFilter | REG_DWORD, default 1. 0 = no DC offset filter |
| | DCOffsetFilterThreshold | REG_DWORD, ≤ 2000, default 17 |
| | DCOffsetFilterLength | REG_DWORD, 3 … 10000, default 10000 |
| | DCOffsetX, DCOffsetY, DCOffsetZ | REG_BINARY, 4 bytes (float), \|value\| ≤ 2000, default 0.0. Written back by `SaveDCOffsets` (0x1000EA64) |

GUID of the ETW provider:  
`{CF441505-1E7D-4907-8E5D-A5240CA18DB6}`

| Event | Level | Keyword | Content |
|-------|-------|---------|---------|
| 100 | 2 (error) | 0x1 | Text of the error messages |
| 102 | 4 | 0x2 | Text of the messages with flag 0x2 |
| 103 | 5 | 0x8 | Accelerometer sample: X, Y, Z (3 floats) |
| 104 | 5 | 0x8 | Ambient light sample |
| 105 | 5 | 0x8 | Proximity sample |
| 106 | 5 | 0x8 | Accelerometer sample with `+0x10` = 6 ? |

The driver also prints with `vDbgPrintEx(DPFLTR_DEFAULT_ID (101), 0, …)`. The masks at `.data:0x10002158` (`FFFFFFFF FFFFFFFE FFFFFFFE 0 0`) only let errors and warnings through (levels 2 and 3). Info (4) and function entry/exit (5) are disabled.

Pool tags: `SenX` (`WDF_DRIVER_CONFIG.DriverPoolTag`, 0x586E6553), `UTLx` (0x784C5455, ACPI evaluation buffer). Most allocations use the **pool tag of the client** (from its registration packet).  
Signature of the device extension: `SENS` (0x534E4553).

Power setting: `PoRegisterPowerSettingCallback` on `{E1233993-EAA4-470F-9DE7-A351C1B6FB71}` (the "low power epoch", see [msgpiowinphone.sys](./msgpiowinphone.md#low-power-epoch)). While it is active, the sensor is stopped, unless a subscriber has called [IOCTL 0x220024](#ioctl-0x220024--enableidleoperation).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Client drivers | [ltr554als02.sys](./ltr554als02.md), KXTNK accelerometer driver ?, QPDS_T900 driver ? | Called through the callbacks of their registration packet (see [Client interface](#client-interface)) |
| Own ACPI PDO (`WdfDeviceGetIoTarget`) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD_EX` (0x32C018) to evaluate `SCLX` and `PRIM` |
| Own sensor device (`WdfIoTargetOpen` on its own `DEVICE_OBJECT`) | wpsensorsclx.sys → client driver | Accelerometer only: [IOCTL 0x22031C](#ioctl-0x22031c) |

### Client interface

`SensorClxClassLibraryBindClient` checks that the client asks for exactly **6** functions and copies this table (`.rdata:0x1000216C`):  
| Index | Function | Comment |
|-------|----------|---------|
| 0 | `SensorClxRegisterClient` 0x1000A160 | (WDFDRIVER, registration packet, ? (must not be NULL)). Called from the client `DriverEntry`. Copies the packet into a client entry (0x58 bytes) of a global list |
| 1 | `SensorClxUnregisterClient` 0x1000A1D8 | (WDFDRIVER) |
| 2 | `SensorClxProcessAddDevicePreDeviceCreate` 0x10009D00 | (WDFDRIVER, WDFDEVICE_INIT, out WDF_OBJECT_ATTRIBUTES). Sets the PnP/power callbacks, the file object callbacks, `WdfDeviceIoBuffered`, and the attributes of the device extension: 128 bytes + client context size (at least 256) |
| 3 | `SensorClxProcessAddDevicePostDeviceCreate` 0x10009E78 | (WDFDRIVER, WDFDEVICE, sensor type). Builds the device extension, applies the security, creates the sensor manager, sets the power capabilities and the idle settings, creates the device interface and the queues |
| 4 | `SensorClxSampleReady` 0x1000A220 | (WDFDEVICE, sample). Push of a new sample by the client. The sample must be ≥ 32 bytes |
| 5 | `SensorClxGetClientContext` 0x1000A2A4 | (WDFDEVICE). Returns device extension + 0x80 (the client context) |

Registration packet (76 bytes). `SensorpValidateRegistrationPacket` only accepts version 1 and requires InitializeDevice, UnInitializeDevice and QueryDeviceInformation:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 01 00 | Version (1) |
| 02-03 | 4C 00 | Size (76) |
| 04-07 | | Size of the client context (e.g. 0x548 for ltr554als02) |
| 08-0B | | Pool tag (e.g. `LTR5`) |
| 0C-0F | | InitializeDevice (WDFDEVICE, context, ResourcesRaw, ResourcesTranslated). Called by `EvtDevicePrepareHardware` |
| 10-13 | | UnInitializeDevice. Called by `EvtDeviceReleaseHardware` |
| 14-17 | | InitializeHardware. Called at the first D0 entry |
| 18-1B | | QueryDeviceInformation (context, 24-byte buffer). See below |
| 1C-1F | | GetRangeResolution (context, index, min, min size, max, max size, resolution, resolution size) |
| 20-23 | | SetRangeResolution (context, index) |
| 24-27 | | SetInterval |
| 28-2B | | GetSensorTiming (context, 3 DWORDs). Mandatory. The 3rd DWORD is the minimum sample time (ms) |
| 2C-2F | | StartReading. Mandatory for poll clients unless QueryDeviceInformation flag 0x1 |
| 30-33 | | AbortReading. Mandatory for poll clients |
| 34-37 | | GetData. Mandatory for poll clients |
| 38-3B | | StartAcquisition (context, interval). Mandatory for push clients |
| 3C-3F | | StopAcquisition |
| 40-43 | | PowerEnable (context, on/off). Mandatory |
| 44-47 | | InterruptEnable. Called by `EvtDeviceD0EntryPostInterruptsEnabled` / `D0ExitPreInterruptsDisabled` |
| 48-4B | | DeviceIoControl (context, queue, request, output size, input size, code, out information). Receives the IOCTLs SensorsClx doesn't handle |

QueryDeviceInformation buffer (24 bytes), checked by `SensorMgrValidateClientInformation` (0x1000B084):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 01 00 | Version ? |
| 02-03 | 18 00 | Size (24) ? |
| 04-07 | | Sensor type, < 6 (see below) |
| 08-0B | e.g. 20 00 00 00 | Maximum sample size (`MaxDataSize`, must not be 0) |
| 0C-0F | e.g. 01 00 00 00 | Number of ranges (≤ 1024 for the accelerometer) |
| 10-13 | e.g. 02 00 00 00 | Capabilities (see below) |
| 14-17 | | bit 0: StartReading not needed ? |

Capabilities:  
| Bit | Meaning |
|-----|---------|
| 0x00000001 | `SENSOR_CAPS_CLX_POLL`: SensorsClx polls the sensor (StartReading / GetData / AbortReading) from its `SensorStateThread` |
| 0x00000002 | `SENSOR_CAPS_CLIENT_PUSH`: the client pushes its samples with `SensorClxSampleReady`. One of these 2 bits is required, not both |
| 0x00000400 | Notification mode 0x60 supported |
| 0x00000800 | Notification mode 0x30 supported |
| 0x00001000 | Notification mode 0x10 supported |
| 0x00002000 | Notification mode 0x20 supported |
| 0x00004000 | Notification mode 0x40 supported |
| 0x00008000 | Notification mode 0x50 supported |
| 0x80000000 | `ACC_CAPABILITY_HW_ORIENTATION` (accelerometer only, requires `SENSOR_CAPS_CLIENT_PUSH`) |

For the accelerometer, bits 0x400–0xFC00 are cleared: no threshold notification.

Sensor types (`SensorSpecificAlloc`, 0x1000FB74):  
| Type | Sensor | Minimum read size | Interface GUID |
|------|--------|-------------------|----------------|
| 0 | Accelerometer | 40 | `{C2FB0F5F-E2D2-4C78-BCD0-352A9582819D}` |
| 1 | Proximity | 32 | `{5220DAE9-3179-4430-9F90-06266D2A34DE}` |
| 2 | Ambient light | 32 | `{97F115C8-599A-4153-8894-D2D12899918A}` |
| 3 | Compass / magnetometer ? | 56 | `{55E5EFFB-15C7-40DF-8698-A84B7C863C53}` |
| 4 | Gyroscope | 40 | `{09485F5A-759E-42C2-BD4B-A349B75C8643}` |
| 5 | ? | 208 | `{D4B5AED3-3819-45CB-A3CC-EA862A2013D1}` |

Sample (output of a read, or of `SensorClxSampleReady`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Size |
| 08-0F | | `KeQueryInterruptTime` (100 ns) |
| 10-13 | | Sensor type (proximity/ALS). Accelerometer: 0, or 6 ? |
| 18-… | | Data. Accelerometer: X, Y, Z (floats, g) at 18, 1C, 20. ALS: milli-lux (DWORD). Proximity: 1 = detected, 0 = not detected |

### Device setup

`SensorClxProcessAddDevicePostDeviceCreate`:
1. Device extension: signature `SENS`, copy of the registration packet at `+0x28`, manager at `+0x74`, queues at `+0x78` / `+0x7C`, client context at `+0x80`.
2. [Device security](#device-security).
3. `SensorManagerAlloc`.
4. `WdfDeviceSetPowerCapabilities`: D1/D2 not supported, S0 → D0, S1…S5 → D3, IdealDxStateForSx = D3.
5. `WdfDeviceAssignS0IdleSettings`: `IdleCannotWakeFromS0`, D3, timeout 500 ms, no user control, enabled. The idle timeout type is `DriverManagedIdleTimeout`, or `SystemManagedIdleTimeoutWithHint` if bit 0 of the ACPI method `SCLX` is set.
6. `WdfDeviceCreateDeviceInterface` with the GUID of the sensor type. A failure is only logged.
7. `SensorpSetupIoQueues` (0x1000A2D4): a sequential default queue (read, write, IOCTL, internal IOCTL) and a parallel queue (read, IOCTL) that receives all the reads. Both are not power managed.

`EvtDevicePrepareHardware` calls InitializeDevice, then QueryDeviceInformation (`SensorpInitializeControllerInformation`, 0x1000F944), validates the callbacks and creates the 2 threads of the manager (`SensorStateThread` for the polling, `NotifStateThread` priority 16 for the notifications).  
At the first D0 entry `SensorMgrUpdatePowerState` (0x1000F04C) calls InitializeHardware and PowerEnable(0). The sensor is then started (PowerEnable(1) + StartAcquisition with the smallest interval of the subscribers) when there is at least one subscriber, and stopped (StopAcquisition + PowerEnable(0)) when there is none, or during the low power epoch.

ACPI methods, evaluated on the sensor device by `GetMethodArgumentFromAcpi` (0x10010CC0) with `IOCTL_ACPI_EVAL_METHOD_EX` (signature `AeiA`, result `AeoB` with 1 buffer argument):  
| Method | Size | Use |
|--------|------|-----|
| `SCLX` | 4 bytes, big-endian | SensorsClx flags. bit 0: system-managed idle timeout |
| `PRIM` | 1 byte | "Is primary sensor", returned by [IOCTL 0x220020](#ioctl-0x220020--isprimarysensor) |

None of the sensor devices of the Lumia 520 SSDT has these methods.

### Device security

`SensorClxApplySecurity` (0x10009A7C), called for each new sensor device:
1. Read `EnableOemSecurity` in the service key of the client driver. If it's not 0, nothing is done.
2. Read `WpSecurity` (REG_BINARY) in `\REGISTRY\MACHINE\SYSTEM\ControlSet001\Services\SensorsClx0101`.
3. `ObOpenObjectByPointer` on the FDO, then `ZwSetSecurityObject(DACL_SECURITY_INFORMATION)` with this descriptor.

If one of the keys can't be opened or `WpSecurity` is missing, `SensorClxProcessAddDevicePostDeviceCreate` fails and the sensor device isn't started.

### Subscribers

Each `CreateFile` on a sensor device creates a subscriber (`SubscriberAllocate`, 0x10010080). A file object can only have one (`STATUS_INVALID_DEVICE_STATE` otherwise). The subscriber stores the process that opened the handle (`IoGetInitiatorProcess`). When the notification starts, it calls `IoIncrementKeepAliveCount` on this process.  
A **read** (`EvtIoRead`, buffer ≥ 32 bytes and ≥ the minimum read size of the sensor type, otherwise `STATUS_INSUFFICIENT_RESOURCES` 0xC000009A) returns the last sample if a new one is ready. Otherwise the read is pended until the next notification. Only one pending read per handle (`STATUS_TOO_MANY_COMMANDS`, 0xC00000C1). The notification must have been started first (`STATUS_DEVICE_NOT_READY` otherwise).  
**Write** and **internal IOCTL** fail with `STATUS_NOT_IMPLEMENTED`.

Notification modes (bits 4–6 of the flags of [IOCTL 0x220014](#ioctl-0x220014--notificationconfigure), evaluated by `EvaluateThreshold`, 0x100105F8). Threshold 1 = "low", threshold 2 = "high", threshold 3 = "delta". The thresholds are samples (size at `+0`, sensor type at `+0x10`, value at `+0x18`):  
| Mode | Capability | Thresholds | A sample is reported when | One-shot |
|------|------------|------------|---------------------------|----------|
| 0x00 | — | — | Every interval | No |
| 0x10 | 0x1000 | 2 | value ≥ high | Yes |
| 0x20 | 0x2000 | 1 | value < low | Yes |
| 0x30 | 0x800 | 2 | First sample, then each crossing of high (up or down) | No |
| 0x40 | 0x4000 | 1, 2 | low ≤ value ≤ high | Yes |
| 0x50 | 0x8000 | 1, 2 | value outside \[low, high\] | Yes |
| 0x60 | 0x400 | 3 | First sample, then when the value moved by more than delta from the last reported one | No |

"One-shot": the notification stops after the sample is read.  
For the proximity the threshold values are ignored: `ProximityCompareThresh` (0x1000E5A8) answers "above" for NOT DETECTED (0) and "below" for DETECTED (any other value).

### Accelerometer

`AccelerometerInit` (0x1000D120) loads the calibration offsets (one X/Y/Z float triplet per range):
1. From `HKLM\System\Sensors\Acc\Calibration` (`ACC_X_OFFSET_<n>` …).
2. If a value is missing: from `\??\C:\DPP\Sensors\Accelerometer.bin`, then written to the registry. If both fail: "WARNING Accelerometer not calibrated" and the offsets are 0.

`C:\DPP\Sensors\Accelerometer.bin`: one 12-byte record per range, no header:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | X offset (float, g) |
| 04-07 | | Y offset (float, g) |
| 08-0B | | Z offset (float, g) |

At power on, `InitializeRange` (0x1000DECC) reads all the ranges of the client (GetRangeResolution: min, max, resolution as floats in g). It selects the one closest to ±2 g (`STATUS_NOT_SUPPORTED` "+/- 2G range not found" if there's no range).  
The offset of the current range is **added** to every sample (X, Y, Z at `+0x18`), unless the mode set through [IOCTL 0x22031C](#ioctl-0x22031c) is 2.

---

### IOCTL 0x220004 — GetCaps

This IOCTL is processed by Wpsensorsclx.sys (`IoControlGetCaps`, 0x10008D30)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| GetCaps | 0 | ≥ 20 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 14 00 00 00 | Size (20) |
| 04-07 | | Capabilities (from QueryDeviceInformation) |
| 08-0B | | Sensor type |
| 0C-0F | | Minimum interval in µs (3rd DWORD of GetSensorTiming × 1000, at least 1000) |
| 10-13 | | Number of ranges |

Fails with `STATUS_UNSUCCESSFUL` if the client sets both `SENSOR_CAPS_CLX_POLL` and `SENSOR_CAPS_CLIENT_PUSH`.

---

### IOCTL 0x22000C — GetRangeResolution

This IOCTL is processed by Wpsensorsclx.sys (`IoControlGetRangeResolution`, 0x10008DE4)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x3 (3) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| GetRangeResolution | ≥ 16 | ≥ 12 + size1 + size2 + size3 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Range index |
| 04-07 | | size1: size of the minimum value |
| 08-0B | | size2: size of the maximum value |
| 0C-0F | | size3: size of the resolution |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | size1 |
| 04-07 | | size2 |
| 08-0B | | size3 |
| 0C-… | | Minimum, maximum and resolution, one after the other (accelerometer: floats in g) |

A size of 0 or > 1024 gives a NULL buffer to the client. The client function GetRangeResolution is called directly.

---

### IOCTL 0x220010 — SetRangeResolution

This IOCTL is processed by Wpsensorsclx.sys (`IoControlSetRangeResolution`, 0x10008F44)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x4 (4) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SetRangeResolution | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Range index, passed to the client SetRangeResolution |

---

### IOCTL 0x220014 — NotificationConfigure

This IOCTL is processed by Wpsensorsclx.sys (`IoControlNotificationConfigure`, 0x1000902C)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x5 (5) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| NotificationConfigure | 24 … 1023 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Total size |
| 04-07 | | Flags. bits 4–6: notification mode (see [Subscribers](#subscribers)) |
| 08-0B | | Interval in µs. Must be ≥ the minimum interval of [GetCaps](#ioctl-0x220004--getcaps), otherwise `STATUS_INVALID_PARAMETER` |
| 0C-0F | | Size of threshold 1 (low) |
| 10-13 | | Size of threshold 2 (high) |
| 14-17 | | Size of threshold 3 (delta) |
| 18-… | | Thresholds 1, 2, 3 (samples), one after the other |

Fails with `STATUS_INVALID_DEVICE_STATE` while the notification is running. The configuration is stored in the subscriber of the handle (`SubscriberNotifConfigure`, 0x100103B0).

---

### IOCTL 0x220018 — NotificationStart

This IOCTL is processed by Wpsensorsclx.sys (`IoControlNotificationStart`, 0x10009108)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x6 (6) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| NotificationStart | 0 | 0 |

Validates the configuration again, adds the subscriber to the notification list and starts the sensor if needed (`SensorMgrStartAcquisition`). Then it **waits up to 10 s for the first sample**. On timeout (outside the low power epoch) the notification is stopped and the IOCTL fails with `STATUS_DEVICE_NOT_READY`. Already started: `STATUS_DEVICE_BUSY` (0x80000011).

---

### IOCTL 0x22001C — NotificationStop

This IOCTL is processed by Wpsensorsclx.sys (`IoControlNotificationStop`, 0x100091B8)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x7 (7) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| NotificationStop | 0 | 0 |

Removes the subscriber from the notification list. The sensor is stopped when no subscriber is left.

---

### IOCTL 0x220020 — IsPrimarySensor

This IOCTL is processed by Wpsensorsclx.sys (inline in `EvtIoDeviceControl`, 0x10008A7C)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x8 (8) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IsPrimarySensor | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Byte returned by the ACPI method `PRIM`, or 0 if it doesn't exist (always 0 on the Lumia 520) |

---

### IOCTL 0x220024 — EnableIdleOperation

This IOCTL is processed by Wpsensorsclx.sys (`IoControlEnableIdleOperation`, 0x10009268)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x9 (9) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| EnableIdleOperation | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Not 0 = this subscriber keeps the sensor running during the low power epoch (screen off ?). 0 = cancel |

The manager counts the subscribers that enabled it (`+0xC0`). Sending the current value again fails with `STATUS_INVALID_DEVICE_STATE`.

---

### IOCTL 0x220028

This IOCTL is processed by Wpsensorsclx.sys (`SubscriberDeviceIoControl`, inline in `IoControlDeviceIoControl` 0x100093A0)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xA (10) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 / 02 00 00 00 | Data mode of the subscriber. Other values: `STATUS_INVALID_PARAMETER` |

Only from user mode, and only if the sensor-specific code didn't handle the code first. The value is used when the notification starts or stops (`SensorSpecificSetVariable`). The accelerometer counts its subscribers per mode. The mode is 1 when at least one subscriber uses mode 1 (or 0, the default), otherwise 2. When it changes, it's sent to the client with [IOCTL 0x22031C](#ioctl-0x22031c). In mode 2 the calibration offsets are not added (raw data ?).

---

### IOCTL 0x220110 — Accelerometer calibration

This IOCTL is processed by Wpsensorsclx.sys (`AccelerometerDeviceIoControl`, 0x1000D444). For other sensor types it is passed to the client.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x44 (68) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Calibrate accelerometer | 0 | 0 |

When it arrives on the sequential default queue, the request is forwarded to the parallel queue, because it stays pending during the calibration. The phone must lie **flat, screen up** (expected X = 0, Y = 0, Z = −1 g).
1. Fails with `STATUS_INVALID_DEVICE_STATE` if the sensor is off or if a calibration is running.
2. For each range of the client: switch to the range, ignore the samples for 0.5 s, then average 100 samples (`ProcessCalibrationSample`, 0x1000E10C). Offsets = (−avg X, −avg Y, −(avg Z + 1)).
3. Restore the previous range, write the offsets to `HKLM\System\Sensors\Acc\Calibration` and complete the request with `STATUS_SUCCESS`.

If the sensor is powered off during the calibration, the request is completed with `STATUS_DEVICE_NOT_READY`.

---

### IOCTL 0x22031C

This IOCTL is sent by Wpsensorsclx.sys to the accelerometer client driver (through its own device: `WdfIoTargetOpen` on its own `DEVICE_OBJECT`, then `IoControlDeviceIoControl` → client DeviceIoControl)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xC7 (199) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set accelerometer data mode ? | Sensor device (accelerometer) | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 / 02 00 00 00 | Mode chosen from the subscribers (see [IOCTL 0x220028](#ioctl-0x220028)) |

Sent asynchronously (`AccelerometerSetVariable`, 0x1000D5A8). The result is ignored.

---

### Other IOCTLs

Any other code is passed to the sensor-specific code (accelerometer: `AccelerometerDeviceIoControl`), then to the DeviceIoControl callback of the client (for example the OEM calibration IOCTLs of [ltr554als02.sys](./ltr554als02.md)). If the client has no DeviceIoControl, the request fails with `STATUS_INVALID_DEVICE_REQUEST`.

---

### Interface GUIDs

Created by `SensorClxProcessAddDevicePostDeviceCreate` according to the sensor type given by the client:  
Accelerometer  
`{C2FB0F5F-E2D2-4C78-BCD0-352A9582819D}`  
Proximity  
`{5220DAE9-3179-4430-9F90-06266D2A34DE}`  
Ambient light  
`{97F115C8-599A-4153-8894-D2D12899918A}`  
Type 3 (compass ?)  
`{55E5EFFB-15C7-40DF-8698-A84B7C863C53}`  
Gyroscope  
`{09485F5A-759E-42C2-BD4B-A349B75C8643}`  
Type 5 (?)  
`{D4B5AED3-3819-45CB-A3CC-EA862A2013D1}`

### Other GUID

Low power epoch power setting  
`{E1233993-EAA4-470F-9DE7-A351C1B6FB71}`
