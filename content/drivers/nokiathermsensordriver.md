## NokiaThermSensorDriver.sys

Nokia battery thermal sensor (KMDF, `NokiaThermSensorDriver.pdb`; the device context types are `FDO_DATA` and `READ_REQUEST_CONTEXT`).  
It provides the temperature of a thermal zone with the standard `IOCTL_THERMAL_READ_TEMPERATURE`, read from the ADC channel `BATT_THERM2` of the ADC driver. Read requests can wait for the temperature to leave a window: they are kept in a manual queue and checked again every 60 s and when their timeout expires.  
It also has two private IOCTLs: one returns the ADC reading as text, the other forces a fake temperature ("hot testing"). Every other IOCTL is forwarded to the lower device.  
It reads no registry value and has no ETW provider: the only traces are `DbgPrintEx` calls (`NokiaThermSensorDriver: ...`).

On the Lumia 520 the device is probably the thermal zone `\_SB.TZ10` (`_HID` `NOKIA_THERMAL`, `_UID` 0, `_TZD` = CPU0, CPU1, `_PSV` 3780 = 104.8 °C, `_CRT` 3830 = 109.8 °C), defined in the DSDT (see [ACPI tables](../acpi/README.md) and [acpipagr.sys](./acpipagr.md#lumia-520-acpi-definition)) ?

Device name : none (the WDF device is unnamed)  
Symbolic link : `\DosDevices\NokiaThermSensorDriver` (`\??\NokiaThermSensorDriver`, created with `WdfDeviceCreateSymbolicLink`, so it points to the PDO name)  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\NOKIA_THERMAL\<instance>` ?  

There's no parameters in the registry.

GUID of the ETW provider:  
None (`DbgPrintEx` only).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{10542F20-9718-452A-897A-45785468E57A}` | ADC driver ? (not documented yet) | `IOCTL_ADC_GET_CHANNEL` (0x8ADC2000) / `IOCTL_ADC_READ` (0x8ADC2004), channel `BATT_THERM2`. Context `+0x10` |
| Lower device (`WdfDeviceGetIoTarget`) | acpi.sys ? | Receives every other IOCTL and every internal IOCTL, forwarded unchanged |

The ADC interface is found with `IoRegisterPlugPlayNotification` (`EventCategoryDeviceInterfaceChange`, `PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`, callback `sub_40154C`) in `EvtDevicePrepareHardware` (0x40148C), and opened by name with `WdfIoTargetOpen` (`STANDARD_RIGHTS_ALL`, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`) on `GUID_DEVICE_INTERFACE_ARRIVAL`. A second arrival is ignored ("Interface %d was already opened"). The notification is never unregistered and the target never closed.

### Initialisation

`EvtDriverDeviceAdd` (0x4010B0):
1. PnP/power callbacks: `EvtDevicePrepareHardware`, `EvtDeviceSelfManagedIoSuspend` (0x40194C); `EvtDeviceD0Entry`, `EvtDeviceD0Exit` and `EvtDeviceReleaseHardware` are the same stub returning `STATUS_SUCCESS` (0x401480). `WdfDeviceCreate` with the context `FDO_DATA`.
2. The default queue, parallel, `EvtIoDeviceControl` (0x4016F4) and `EvtIoInternalDeviceControl` (0x401854).
3. A manual queue (context `+0x00`) for the pending temperature reads. `EvtIoStop` (0x401900) is written into the queue config **after** `WdfIoQueueCreate`: it's never registered.
4. A wait lock (context `+0x04`), the device interface `{DD09FBB6-9739-4949-B13C-F22352182CEC}`, the symbolic link.
5. A second wait lock (context `+0x38`) and the polling timer `sub_4019F0` (context `+0x08`, one-shot, passive level, parent = device). It isn't started here.

Context `FDO_DATA` layout:  
| Offset | Content |
|--------|---------|
| 0x00 | WDFQUEUE: manual queue of pending `IOCTL_THERMAL_READ_TEMPERATURE` |
| 0x04 | WDFWAITLOCK (scan of the manual queue) |
| 0x08 | WDFTIMER: polling timer |
| 0x0C | Pointer to the ADC interface GUID (`.rdata:0x4040B4`) |
| 0x10 | ADC target (NULL until the interface arrives) |
| 0x14 | 1 = ADC target open |
| 0x18 | Set to 3 when the ADC target opens, never read (slot for the unused channel `BATT_THERM` ?) |
| 0x1C | ADC channel id of `BATT_THERM2`; 3 = not looked up yet |
| 0x20 | (byte) Test mode, set by [IOCTL 0x222010](#ioctl-0x222010) |
| 0x24 | Test temperature, tenths of K (default 3730 = 100 °C) |
| 0x2C | Highest `LowTemperature` of the requests still pending (init 0). Written, never read |
| 0x30 | Lowest `HighTemperature` of the requests still pending (init 0xFFFFFFFF). Written, never read |
| 0x34 | Last temperature, tenths of K (init 21). Written, never read |
| 0x38 | WDFWAITLOCK (protects `0x20` … `0x34`) |

The string `BATT_THERM` (`.data:0x405140`) is present but not referenced; only `BATT_THERM2` (`.data:0x405154`) is used. In the DSDT, `BATT_THERM2` is entry 0x06 of the ADC channel table.

### Temperature

`sub_402334` (under the lock `+0x38`):
* Test mode: returns the test temperature.
* Otherwise `sub_4023E8` reads the ADC: if the channel id is 3, `IOCTL_ADC_GET_CHANNEL` with `BATT_THERM2` first (the id is cached when output `00-03` is 1), then `IOCTL_ADC_READ`. The value (output `04-07`, °C) is converted to tenths of Kelvin: (°C + 273) × 10. When the read fails, 0 °C (2730) is returned. When `IOCTL_ADC_READ` succeeds with output `00-03` ≠ 1 (invalid reading), only a debug message is printed and the value is used anyway.
* Stores the result at `+0x34`.

### Pending reads

Each pending request has a `READ_REQUEST_CONTEXT` (16 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | Deadline, absolute system time (100 ns). `FF FF FF FF FF FF FF FF` = no timeout |
| 08-0B | ? | `HighTemperature` |
| 0C-0F | ? | `LowTemperature` |

`sub_402008` (scan): reads the temperature once, then for each request of the manual queue (`WdfIoQueueFindRequest`) `sub_402138` completes it when the temperature is ≤ `LowTemperature` or ≥ `HighTemperature`, or when the deadline has passed. The scan restarts from the beginning when a request disappears during the walk (`STATUS_NOT_FOUND`). Finally the window of the remaining requests is stored at `+0x2C` / `+0x30`.  
The scan runs:
* when a read request goes pending;
* from the polling timer `sub_4019F0`, every 60 s. The timer is (re)started with 60 s each time a request goes pending, and re-arms itself after each scan, even with an empty queue: once started, it runs forever;
* from a per-request timer `sub_401990`, created for each pending request with a timeout and started with the timeout. These timers are parented to the device and never deleted: one WDFTIMER object is kept per request until the device is removed.

`EvtDeviceSelfManagedIoSuspend` stops the manual queue with `WdfIoQueueStopSynchronously`. There's no `EvtDeviceSelfManagedIoRestart`, so the queue is never restarted after a suspend ?

The test mode doesn't trigger a scan: pending requests see the test temperature at the next scan (≤ 60 s or their timeout).

---

### IOCTL 0x294090 — IOCTL_THERMAL_READ_TEMPERATURE

This IOCTL is processed by NokiaThermSensorDriver.sys (`sub_401A68`)

| Property | Value |
|----------|-------|
| Device | 0x29 (FILE_DEVICE_BATTERY) |
| Function | 0x24 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_THERMAL_READ_TEMPERATURE | 12 | 4 |

Inputbuffer (`THERMAL_WAIT_READ`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `00 00 00 00` | Timeout in ms. 0 = return at once, `FF FF FF FF` = wait without timeout |
| 04-07 | ? | `LowTemperature`, tenths of K |
| 08-0B | ? | `HighTemperature`, tenths of K |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `E0 0B 00 00` (3040 = 31 °C) | Temperature, tenths of K |

The request is completed at once when the temperature is ≤ `LowTemperature` or ≥ `HighTemperature`, or when the timeout is 0; otherwise it's queued (see [Pending reads](#pending-reads)) and completed later the same way. Information = 4.
* Input shorter than 12 bytes: the status of `WdfRequestRetrieveInputBuffer` (`STATUS_BUFFER_TOO_SMALL`, 0xC0000023). Longer than 12 bytes: `STATUS_SUCCESS` with Information = 0 and no temperature.
* Output size ≠ 4: `STATUS_INVALID_PARAMETER` (0xC000000D).
* ADC target not open yet: `STATUS_DEVICE_NOT_READY` (0xC00000A3).

---

### IOCTL 0x22200C — IOCTL_NOKIA_THERM_SENSOR_DRIVER_IOCTL_GET_DATA

This IOCTL is processed by NokiaThermSensorDriver.sys (`sub_401D8C`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_NOKIA_THERM_SENSOR_DRIVER_IOCTL_GET_DATA | ≥ 12 (content not used) | ≥ 128 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-7F | e.g. `BTEMP2 temperature from NokiaThermSensorDriver: 31\n` | ASCII, NUL-terminated (`sprintf`), the ADC value of `BATT_THERM2` in °C |

Reads the ADC directly (`sub_4023E8`, without the lock): the test mode is ignored and the value isn't converted to Kelvin. When the ADC read fails, 0 is printed and the status is still `STATUS_SUCCESS`. Information = 128.
* Input shorter than 12 bytes: the status of `WdfRequestRetrieveInputBuffer` ("IOCTL_NOKIA_THERM_SENSOR_DRIVER_IOCTL_GET_DATA is malformed").
* Output shorter than 128 bytes: `STATUS_INVALID_PARAMETER` (0xC000000D).
* ADC target not open yet: `STATUS_DEVICE_NOT_READY` (0xC00000A3).

---

### IOCTL 0x222010

This IOCTL is processed by NokiaThermSensorDriver.sys (`sub_401EAC`)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (hot test) | ≥ 4 (8 to set a temperature) | ≥ 128 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `01 00 00 00` | 1 = test mode on, other = test mode off |
| 04-07 | e.g. `92 0E 00 00` (3730) | Test temperature in tenths of K; 0 = default 3730 (100 °C). Only read when `00-03` is 1 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-7F | `OK, it is getting hot here.\n` / `OK, hot testing over, back to normal.\n` | ASCII, NUL-terminated |

While the test mode is on, `IOCTL_THERMAL_READ_TEMPERATURE` returns the test temperature instead of the ADC reading. The input length isn't checked (`MinimumRequiredLength` 0): bytes `04-07` are read even when the input is 4 bytes. The mode is changed before the output buffer is checked, so a too-small output (`STATUS_INVALID_PARAMETER`, 0xC000000D) still changes it. Information = 128.  
Unlike the two IOCTLs above, it works without the ADC target.

---

### Other IOCTLs

Any other IOCTL code, and every internal IOCTL, is forwarded to the lower device with `WdfRequestFormatRequestUsingCurrentType` + `WdfRequestSend` (`WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET`). When `WdfRequestSend` fails, the request is completed with the status of the send.

> [!NOTE]
> In `EvtIoDeviceControl`, when the send fails with `STATUS_DEVICE_NOT_READY`, the code falls into the "ADC target not open" path and completes the request a second time.

---

### IOCTLs sent

All are sent synchronously (`WdfIoTargetSendIoctlSynchronously`, no timeout option) to the ADC interface `{10542F20-…}`. The names come from the log strings of this driver.

| IOCTL | Name | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|------------------|-------------------|---------|
| 0x8ADC2000 | IOCTL_ADC_GET_CHANNEL | 12 | 8 | Input: `BATT_THERM2` (ASCII + NUL). Output: `00-03` 1 = found, `04-07` channel id |
| 0x8ADC2004 | IOCTL_ADC_READ | 4 | 20 | Input: channel id. Output: `00-03` 1 = valid, `04-07` temperature in °C, rest not used |

---

### Interface GUID

NokiaThermSensorDriver device interface  
`{DD09FBB6-9739-4949-B13C-F22352182CEC}`

### Other GUID

`GUID_DEVICE_INTERFACE_ARRIVAL` (checked in the PnP notification callback)  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
