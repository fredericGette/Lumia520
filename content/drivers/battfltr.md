## Battfltr.sys

Microsoft **battery filter** driver (`battfltr.pdb`, KMDF, 27 functions, no symbols).  
A test/demo filter that **fakes the battery charge level**. It's only active when the file `C:\Dpp\Microsoft\BatteryFixedPercent.txt` exists when the device is added. Then it reports a fixed **50 %** (half of the full-charged capacity) in `IOCTL_BATTERY_QUERY_STATUS`, or a capacity and power state set with [IOCTL 0x29C480](#ioctl-0x29c480--set-fake-battery-status). Without the file, it forwards every request unchanged.  
It's a KMDF filter (`WdfFdoInitSetFilter`) installed as a **class upper filter** of the Battery class `{72631E54-78A4-11D0-BCF7-00AA00B7B32A}`. So it sits above every battery device, on the Lumia 520 the [NokiaEnergyDriver.sys](./nokiaenergydriver.md) FDO, and sees the `IOCTL_BATTERY_*` requests before NokiaEnergyDriver passes them to [battc.sys](./battc.md).  
`DriverEntry` (`FxDriverEntry`, 0x10002000) also calls `IoReportRootDevice` after `WdfDriverCreate`. That creates a root-enumerated device `Root\Battfltr\0000` ("Charging filter Driver", System class, installed by `BattFltr.inf`). `EvtDriverDeviceAdd` attaches the same filter to it, with the PnP manager's root PDO below. That second instance sees no battery traffic. Its purpose is probably only to get the INF and the service installed ?

There's no named device and no symbolic link.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\Battfltr`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\Root\Battfltr\0000`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0092`  

Battery class key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{72631e54-78a4-11d0-bcf7-00aa00b7b32a}`:  
| Registry value | value | comment |
|----------------|-------|---------|
| UpperFilters | `battfltr` | REG_MULTI_SZ. Loads the filter above every battery device |

Driver key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0092` (System class):  
| Registry value | value | comment |
|----------------|-------|---------|
| InfPath | `BattFltr.inf` | |
| InfSection | `Battfltr_Inst.NT` | |
| MatchingDeviceId | `ROOT\Battfltr` | |

Device instance `Root\Battfltr\0000`:  
| Registry value | value | comment |
|----------------|-------|---------|
| HardwareID | `ROOT\Battfltr` | REG_MULTI_SZ |
| Service | `Battfltr` | |
| DeviceDesc | `@BattFltr.inf,%battfltr_devdesc%;Charging filter Driver` | |
| Mfg | `@BattFltr.inf,%StdMfg%` | |

There's no parameters in the registry.

GUID of the ETW provider:  
None. The only trace is a `vDbgPrintEx` (component id 101, level 0) wrapper (`sub_100012A4`). It prints `*** Found Battery Fixed Percent DPP File: %S` when the file is found.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Battery device (lower device, `WdfDeviceGetIoTarget`) | [nokiaenergydriver.sys](./nokiaenergydriver.md) + [battc.sys](./battc.md) | Class upper filter: all battery requests are forwarded to it |
| Root PDO of `Root\Battfltr\0000` (lower device) | PnP manager | Second instance of the filter, no battery traffic |
| `\??\C:\Dpp\Microsoft\BatteryFixedPercent.txt` | file system | Existence test only (see below) |

### DPP file

`sub_10003000` (called by `EvtDriverDeviceAdd`, 0x1000308C) opens `\??\C:\Dpp\Microsoft\BatteryFixedPercent.txt` with `ZwOpenFile` (GENERIC_READ, FILE_SHARE_READ, OBJ_KERNEL_HANDLE) and closes it at once. **The content isn't read**: only the existence matters. The test runs once per device. Creating or deleting the file later has no effect until the device is restarted.

### Device context

`FILTER_EXTENSION`, 24 bytes (`WDF_FILTER_EXTENSION_TYPE_INFO`, `.data:0x10004004`):  
| Offset | Initial value | Comment |
|--------|---------------|---------|
| +00 | 0 | Not used |
| +04 | 1 if the DPP file exists, else 0 | Filter enabled (byte) |
| +08 | 100 | FullChargedCapacity, updated from each `BatteryInformation` answer |
| +0C | 50 | Fake Capacity (set by IOCTL 0x29C480) |
| +10 | 0 | Fake PowerState (set by IOCTL 0x29C480) |
| +14 | 0 | Byte. 1 once IOCTL 0x29C480 has been received: then the values at +0C/+10 are used instead of FullChargedCapacity / 2 |

### Request processing

`EvtWdfIoQueueIoDeviceControl` (0x10003164), default parallel queue:
1. Filter disabled, or any other IOCTL: the request is forwarded with `WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET`.
2. `IOCTL_BATTERY_QUERY_INFORMATION` (0x294044) with input ≥ 12 bytes and InformationLevel (input +04) = 0 (`BatteryInformation`): forwarded with the completion routine.
3. `IOCTL_BATTERY_QUERY_STATUS` (0x29404C) with input ≥ 20 bytes: the `BATTERY_WAIT_STATUS` is **modified before forwarding**: LowCapacity (+0C) = 0 and HighCapacity (+10) = 0xFFFFFFFF. A real capacity change then never completes the wait; only a PowerState change or the timeout do (see [battc status polling](./battc.md#status-polling)). It's then forwarded with the completion routine.
4. IOCTL 0x29C480: handled by the filter, not forwarded (see below).

If `WdfRequestSend` fails, the request is completed with `WdfRequestGetStatus`. If `WdfRequestRetrieveInputBuffer` fails (input smaller than the minimum), the request is completed with its error.

Completion routine `sub_100032D8`. It runs only if the filter is enabled and the lower driver returned a success status:
* `BatteryInformation` (output ≥ 36 bytes, `BATTERY_INFORMATION`): saves FullChargedCapacity (+10) in the context at +08. It overwrites Chemistry (+08-0B) with `46 6C 74 72` = **"Fltr"**: a sign that the filter is active.
* `BATTERY_STATUS` (output ≥ 16 bytes): Capacity (+04) = FullChargedCapacity / 2 (shift right by 1), or Capacity = context +0C and PowerState (+00) = context +10 after IOCTL 0x29C480. Voltage and Rate are left as they are.

The request is then completed with the status of the lower driver.

> [!NOTE]
> Until a `BatteryInformation` query has gone through the filter, the fake capacity is 100 / 2 = 50 (mWh), not 50 % of the real battery. Battery clients normally ask for `BatteryInformation` first, so the computed percentage is 50 %.

---

### IOCTL 0x29C480 — set fake battery status

This IOCTL is processed by Battfltr.sys (only when the DPP file exists; otherwise it's forwarded to the lower driver)

| Property | Value |
|----------|-------|
| Device | 0x29 (FILE_DEVICE_BATTERY) |
| Function | 0x120 (288) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 16 | 0 |

Inputbuffer (same layout as `BATTERY_STATUS`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PowerState returned by the next `IOCTL_BATTERY_QUERY_STATUS` (1 `BATTERY_POWER_ON_LINE`, 2 `DISCHARGING`, 4 `CHARGING`, 8 `CRITICAL`) |
| 04-07 | | Capacity returned by `IOCTL_BATTERY_QUERY_STATUS` (same unit as FullChargedCapacity, mWh, **not** a percentage) |
| 08-0F | | Ignored (Voltage, Rate) |

Stores the values in the context (+10, +0C) and sets the override flag (+14). It's completed at once with `STATUS_SUCCESS` and 0 bytes. There's no way to clear the override except restarting the device. Input < 16 bytes → the `STATUS_BUFFER_TOO_SMALL` from `WdfRequestRetrieveInputBuffer`.  
The status waits queued by battc aren't completed when this IOCTL is received: the new values appear at the next `QUERY_STATUS` answer.

---

### IOCTL 0x294044 — IOCTL_BATTERY_QUERY_INFORMATION

This IOCTL is filtered by Battfltr.sys and processed by [battc.sys](./battc.md#ioctl-0x294044--ioctl_battery_query_information)

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x11 (17) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATTERY_QUERY_INFORMATION | 12 | 36 for `BatteryInformation` |

Outputbuffer for `BatteryInformation`, fields changed or read by the filter:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 08-0B | `46 6C 74 72` | Chemistry, overwritten with "Fltr" |
| 10-13 | | FullChargedCapacity, saved in the context |

Other information levels are forwarded without change.

---

### IOCTL 0x29404C — IOCTL_BATTERY_QUERY_STATUS

This IOCTL is filtered by Battfltr.sys and processed by [battc.sys](./battc.md#ioctl-0x29404c--ioctl_battery_query_status)

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x13 (19) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BATTERY_QUERY_STATUS | 20 | 16 |

Inputbuffer (`BATTERY_WAIT_STATUS`), fields changed before forwarding:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 0C-0F | `00 00 00 00` | LowCapacity |
| 10-13 | `FF FF FF FF` | HighCapacity |

Outputbuffer (`BATTERY_STATUS`), fields changed on completion:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PowerState: unchanged, or the value given by IOCTL 0x29C480 |
| 04-07 | | Capacity: FullChargedCapacity / 2, or the value given by IOCTL 0x29C480 |
