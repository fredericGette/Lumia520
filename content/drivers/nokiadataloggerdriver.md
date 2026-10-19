## NokiaDataLoggerDriver.sys

Nokia battery data logger (KMDF, `NokiaDataLoggerDriver.pdb`; the device context type is `NOKIA_DATA_LOGGER_DRIVER_DEVICE_CONTEXT`).  
When started by a user-mode client, it samples periodically the battery voltage, the battery temperature, the battery current and the state of charge, and stores them with a timestamp in a ring buffer of 256 records that the client reads with an IOCTL.  
The values come from three peers: the ADC driver (channels `BATT_THERM` and `VBATT`), [qcbms8930.sys](./qcbms8930.md) (`IOCTL_BMS_GET_BATTERY_CURRENT`) and the battery device of [battc.sys](./battc.md) / [NokiaEnergyDriver.sys](./nokiaenergydriver.md) (`IOCTL_BATTERY_QUERY_*`).  
It has no hardware resource, reads no registry value and has no ETW provider: the only traces are `DbgPrint` calls (`NokiaDataLogger.sys: ...`).

On the Lumia 520 the device is `\_SB.NDLD` (`_HID` `DATA_LOGGER`, no `_UID`, no `_CRS`), defined in the Nokia SSDT (see [ACPI tables](../acpi/README.md)).

Device name : none (the WDF device is unnamed)  
Symbolic link : `\DosDevices\NokiaDataLoggerDriver` (created with `WdfDeviceCreateSymbolicLink`, so it points to the PDO name)  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\DATA_LOGGER\<instance>`  

There's no parameters in the registry.

GUID of the ETW provider:  
None (`DbgPrint` only).

It communicates with the following devices. The three interfaces are found with `IoRegisterPlugPlayNotification` (`EventCategoryDeviceInterfaceChange`, `PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`, callback `sub_40158C`) and opened by name with `WdfIoTargetOpen` (`STANDARD_RIGHTS_ALL`, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`) on `GUID_DEVICE_INTERFACE_ARRIVAL`:  
| Interface class GUID | Driver | Comment |
|----------------------|--------|---------|
| `{10542F20-9718-452A-897A-45785468E57A}` | ADC driver ? (not documented yet) | `IOCTL_ADC_GET_CHANNEL` (0x8ADC2000) / `IOCTL_ADC_READ` (0x8ADC2004), channels `BATT_THERM` and `VBATT`. Context `+0x08` |
| `{23B7D0DD-101F-4EFE-A4D4-BED70E754419}` | [qcbms8930.sys](./qcbms8930.md) | `IOCTL_BMS_GET_BATTERY_CURRENT` (0x80180FA4). Context `+0x10` |
| `{72631E54-78A4-11D0-BCF7-00AA00B7B32A}` `GUID_DEVICE_BATTERY` | [battc.sys](./battc.md) on the [NokiaEnergyDriver.sys](./nokiaenergydriver.md) device, through the upper filter [battfltr.sys](./battfltr.md) | `IOCTL_BATTERY_QUERY_TAG` / `QUERY_INFORMATION` / `QUERY_STATUS`. Context `+0x18` |

> [!NOTE]
> The notifications are never unregistered and the targets are never closed (no removal handling). A new arrival of the same interface class overwrites the stored target. Only the ADC target is checked for NULL before use: a sample taken before qcbms8930 or the battery device has arrived sends an IOCTL to a NULL target ?

### Initialisation

`EvtDriverDeviceAdd` (0x4080BC):
1. Empty PnP/power callbacks (no `EvtDevicePrepareHardware`), `WdfDeviceCreate` with the context `NOKIA_DATA_LOGGER_DRIVER_DEVICE_CONTEXT` (0x2C bytes).
2. A spinlock (context `+0x00`, protects the targets), the device interface `{A01A52BA-0853-4D47-9DD4-6B12FB9A97EF}`, a parallel default queue (`EvtIoDeviceControl` 0x401008), the symbolic link.
3. `sub_4013D8`: the work item `sub_401C74` (handle `dword_405A8C`).
4. `sub_401320`: a one-shot timer `sub_401720` (handle `dword_405A98`, period 0).
5. `sub_401478`: the three PnP notifications.

Context layout:  
| Offset | Content |
|--------|---------|
| 0x00 | WDFSPINLOCK |
| 0x04 / 0x08 | Pointer to the ADC GUID / ADC target |
| 0x0C / 0x10 | Pointer to the qcbms8930 GUID / qcbms8930 target |
| 0x14 / 0x18 | Pointer to `GUID_DEVICE_BATTERY` / battery target |
| 0x1C | ADC channel id of `BATT_THERM` |
| 0x20 | ADC channel id of `VBATT` |

The logger state is in global variables, not in the context:  
| Address | Content |
|---------|---------|
| `dword_405A94` | Sampling period (ms) |
| `dword_405AC0` | Logger enabled (1) / disabled (0) |
| `word_405A90` | Index of the last written record (low byte used), 0xFFFF = empty |
| `0x405AE0` | Ring buffer: 256 records × 16 bytes |
| `0x406AE0` | Ring header (`dword_405A88` points to it): `+2` word = read index, `+4` word = count of overwritten records (never reported) |

### Sampling

Started by [IOCTL 0x222004](#ioctl-0x222004--nokia_data_logger_driver_ioctl_start), the work item `sub_401C74` (PASSIVE_LEVEL):
1. Advances the write index. On the first sample after a start it's 0, and the read index and the lost counter are reset to 0. When the write index reaches the read index (buffer full), the read index and the lost counter are incremented: the oldest record is overwritten.
2. `sub_401A34` (ADC), `sub_401780` (qcbms8930), `sub_40184C` (battery), in this order, fill the record.
3. Writes the timestamp when the **last** step (battery) succeeded; otherwise the record keeps the timestamp of the record previously at this place (0 on the first lap).
4. Restarts the timer with the period. The timer callback `sub_401720` queues the work item again while the logger is enabled.

Record (16 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | `KeQuerySystemTime` (100 ns since 1601, UTC) |
| 08-09 | ? | `VBATT`, mV, signed 16 bits. `FF FF` (−1) when the ADC read is invalid, `00 80` when > 0x7FFF |
| 0A-0B | ? | `IOCTL_BMS_GET_BATTERY_CURRENT`, mA, signed 16 bits (sign: see [qcbms8930](./qcbms8930.md#ioctl-0x80180fa4--ioctl_bms_get_battery_current)). `00 80` when the IOCTL fails or the value is > 0x7FFF |
| 0C | ? | `BATT_THERM`, °C, signed 8 bits. `FF` (−1) when the ADC read is invalid, `80` when > 127 |
| 0D | ? | State of charge in %: 100 × `Capacity` / `FullChargedCapacity` from BATTC. `80` when an IOCTL fails, `FullChargedCapacity` is 0, or the result is > 127 |
| 0E-0F | 00 00 | Never written |

ADC (`sub_401A34`): for each channel, the channel id is looked up by name with `IOCTL_ADC_GET_CHANNEL` (0x8ADC2000) (on every sample, it isn't cached), then read with `IOCTL_ADC_READ` (0x8ADC2004); `sub_401BD0` stores the converted value (output `04-07`) when output `00-03` is 1. When the lookup fails, the field isn't written (it keeps the value of the previous lap). Returns `STATUS_UNSUCCESSFUL` (0xC0000001) when the ADC target isn't open yet.  
Battery (`sub_40184C`): `QUERY_TAG` (timeout 1000 ms), `QUERY_INFORMATION` level 0 `BatteryInformation`, `QUERY_STATUS` (timeout 2000 ms). The `PowerState` / `LowCapacity` / `HighCapacity` fields of the `BATTERY_WAIT_STATUS` aren't initialised (stack content), so BATTC returns at once if they differ from the current status, or after up to 2 s ?

> [!NOTE]
> The worker writes the ring buffer and [IOCTL 0x22200C](#ioctl-0x22200c--nokia_data_logger_driver_ioctl_read_data) reads it without any lock.

---

### IOCTL 0x222004 — NOKIA_DATA_LOGGER_DRIVER_IOCTL_START

This IOCTL is processed by NokiaDataLoggerDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| NOKIA_DATA_LOGGER_DRIVER_IOCTL_START | ≥ 4 | 0 (≥ 1 for an error code, see below) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `E8 03 00 00` (1000) | Sampling period in ms, 250…300000 |

Stores the period, enables the logger, empties the ring buffer (write index 0xFFFF) and queues the work item: the first sample is taken at once. Calling it again while running restarts the logging with the new period.  
* Input shorter than 4 bytes: the status of `WdfRequestRetrieveInputBuffer` (`STATUS_BUFFER_TOO_SMALL`, 0xC0000023).
* Period out of range: `STATUS_INVALID_PARAMETER_1` (0xC00000EF), with Information = 1 when an output buffer exists.

The error path is meant to write an error code in the first byte of the output buffer (`sub_401248`: 3 = period out of range; 2 = no input buffer, an unreachable case). But `sub_401248` stores the byte into its **local pointer variable** instead of the buffer (`STRB R6, [R5]` with `R5` = address of the pointer), so the output byte is never written: with METHOD_BUFFERED the caller gets back the first byte of its own input.

---

### IOCTL 0x222008 — NOKIA_DATA_LOGGER_DRIVER_IOCTL_STOP

This IOCTL is processed by NokiaDataLoggerDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| NOKIA_DATA_LOGGER_DRIVER_IOCTL_STOP | 0 | 0 |

Disables the logger and returns `STATUS_SUCCESS`. The timer isn't stopped: when it fires the callback sees the flag and doesn't queue the work item. The ring buffer is kept and can still be read.

---

### IOCTL 0x22200C — NOKIA_DATA_LOGGER_DRIVER_IOCTL_READ_DATA

This IOCTL is processed by NokiaDataLoggerDriver.sys

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| NOKIA_DATA_LOGGER_DRIVER_IOCTL_READ_DATA | 0 | 16 × n (≤ 4096) |

Outputbuffer: n records of 16 bytes (see [Sampling](#sampling)), oldest first.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | | Record at the read index |
| … | | |
| 16 × (n−1) … | | Record at the write index (last sample) |

n = number of records from the read index to the write index, **both included**, with wrap-around. The output buffer must hold all of them, otherwise `WdfRequestRetrieveOutputBuffer` fails and the request completes with `STATUS_BUFFER_TOO_SMALL` (0xC0000023) (the code that follows for a too-small buffer, error byte 4 + `STATUS_INVALID_PARAMETER_1`, is unreachable). Allocating 4096 bytes is always enough. Information = 16 × n.  
`sub_401294` copies the records and sets the read index to the **write index** (not write index + 1): the last record of a read is returned again as the first record of the next read. Before the first START (write index 0xFFFF, read index 0), the whole table (256 zero records) is returned.

Any other IOCTL code is completed with `STATUS_SUCCESS`.

---

### IOCTLs sent

All are sent synchronously (`WdfIoTargetSendIoctlSynchronously`, no timeout option).

| IOCTL | Name | Device | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|--------|------------------|-------------------|---------|
| 0x8ADC2000 | IOCTL_ADC_GET_CHANNEL | ADC `{10542F20-…}` | strlen + 1 | 8 | Input: `BATT_THERM` or `VBATT` (ASCII, `.data:0x40513C`, 20 bytes each). Output: `00-03` 1 = found, `04-07` channel id |
| 0x8ADC2004 | IOCTL_ADC_READ | ADC `{10542F20-…}` | 4 | 20 | Input: channel id. Output: `00-03` 1 = valid, `04-07` converted value (°C / mV), rest not used |
| 0x80180FA4 | IOCTL_BMS_GET_BATTERY_CURRENT | [qcbms8930.sys](./qcbms8930.md) `{23B7D0DD-…}` | 0 | 4 | Battery current, mA |
| 0x294040 | IOCTL_BATTERY_QUERY_TAG | battery `{72631E54-…}` | 4 | 4 | Input: timeout 1000 ms. Output: tag (0xBEEF with NokiaEnergyDriver) |
| 0x294044 | IOCTL_BATTERY_QUERY_INFORMATION | battery `{72631E54-…}` | 12 | 36 | Input: tag, level 0, `AtRate` not initialised. Output: `BATTERY_INFORMATION`, only `FullChargedCapacity` (`10-13`) is used |
| 0x29404C | IOCTL_BATTERY_QUERY_STATUS | battery `{72631E54-…}` | 20 | 16 | Input: tag, timeout 2000 ms, rest not initialised. Output: `BATTERY_STATUS`, only `Capacity` (`04-07`) is used |

---

### Interface GUID

NokiaDataLoggerDriver device interface  
`{A01A52BA-0853-4D47-9DD4-6B12FB9A97EF}`

### Other GUID

`GUID_DEVICE_INTERFACE_ARRIVAL` (checked in the PnP notification callback)  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
