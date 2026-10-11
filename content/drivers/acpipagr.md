## Acpipagr.sys

Microsoft ACPI Processor Aggregator Device driver (KMDF, PDB symbols available, 32 functions).  
It is the function driver of the ACPI **Processor Aggregator Device** (`ACPI000C`, ACPI spec §8.5). The firmware uses it to ask the OS to **idle (park) a number of processors**: when the `ACPI000C` node gets a `Notify(…, 0x80)`, the driver evaluates `_PUR` (Processor Utilization Request), passes the requested number of idle processors to the kernel power manager, then reports the result with `_OST`.  
It also exposes a thermal cooling interface, so a thermal zone can use it for passive cooling by idling processors.

The binary contains no Lumia-specific code. The Lumia 520 firmware does define an `ACPI000C` device, **`\_SB.AGR0`**, and acpipagr.sys is loaded on it (see [Lumia 520 device node](#lumia-520-device-node)). What its `_PUR` returns, and whether the firmware ever sends `Notify(AGR0, 0x80)`, is still ?

There's no named device and no symbolic link (`AdEvtDeviceAdd` creates an unnamed FDO).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\acpipagr`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\ACPI000C\2&daba3ff&0`

There's no parameters in the registry.

GUID of the ETW provider:  
`{CBA16CF2-2FAB-49F8-89AE-894E718649E7}` (`AD_ETW_PROVIDER`, manifest-based, registered in `AdRegisterEtw`)  
| Event | Id | Level | Task | Payload |
|-------|----|-------|------|---------|
| `AD_ETW_PUR` | 1 | 4 (information) | 1 | ULONG: number of processors requested by `_PUR` |
| `AD_ETW_OST` | 2 | 4 (information) | 2 | 3 ULONGs: requested count, idled count returned by the kernel, success (1/0) |

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI PDO of `ACPI000C` (default I/O target) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) on `_PUR` and `_OST`; `GUID_ACPI_INTERFACE_STANDARD` to receive the `Notify` |
| Kernel power manager | ntoskrnl | `ZwPowerInformation(0x38, …)` |
| ACPI thermal zone | acpi.sys | Caller of the `GUID_THERMAL_COOLING_INTERFACE` returned by this driver |

### Behaviour

1. `AdEvtDeviceAdd` (0x15064): creates the device with an `AD_EXTENSION` context. Initial thermal limit = 100 %, processor count = `KeQueryActiveProcessorCountEx(ALL_PROCESSOR_GROUPS)`. Adds a query interface `GUID_THERMAL_COOLING_INTERFACE` (size 28, version 1) whose `PassiveCooling` callback is `AdThermalNotification`.
2. `AdEvtDevicePrepareHardware` (0x151A0): creates the work item `AdEventWorker`, queries `GUID_ACPI_INTERFACE_STANDARD` (size 44, version 1) from the PDO and calls `RegisterForDeviceNotifications(AdAcpiNotifyCallback)`, then queues a first evaluation of `_PUR`.
3. `AdAcpiNotifyCallback` (0x110F4): only notification value **0x80** is handled (queues a `_PUR` evaluation); other values are ignored.
4. `AdThermalNotification` (0x15714): `PassiveCooling(Context, Percentage)`. When the percentage changes, it is stored and a thermal update is queued.
5. `AdEventWorker` (0x153F4) processes the pending flags (bit 0 = `_PUR`, bit 1 = thermal, bit 2 = queued), see below.
6. `AdEvtDeviceReleaseHardware` (0x152A4): stops new work, unregisters the notification, dereferences the ACPI interface, deletes the work item.

Number of processors to idle for thermal reasons: `count − count × percentage / 100` (e.g. 4 processors, 50 % → 2).

### `_PUR` evaluation

Sent with `AdAcpiEvaluateMethod` (0x15000, `WdfIoTargetSendIoctlSynchronously` on the default target).

Inputbuffer (8 bytes, `ACPI_EVAL_INPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 69 42` 'AeiB' | Signature |
| 04-07 | `5F 50 55 52` "_PUR" | Method name |

Outputbuffer (28 bytes, `ACPI_EVAL_OUTPUT_BUFFER`). The result is used only if all the checks below pass, otherwise the previous value is kept:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 6F 42` 'AeoB' | Signature (not checked) |
| 04-07 | | Length |
| 08-0B | 02 00 00 00 | Count: must be 2 |
| 0C-0D | 00 00 | Element 0 type: must be integer |
| 10-13 | 01 00 00 00 | RevisionID: must be ≤ 1 |
| 14-15 | 00 00 | Element 1 type: must be integer |
| 18-1B | | NumProcessors: number of processors to idle |

### Request to the kernel

When the `_PUR` count or the thermal count has changed, the worker calls:  
`ZwPowerInformation(0x38, InputBuffer, 8, OutputBuffer, 4)`

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Processors to idle requested by `_PUR` |
| 04-07 | | Processors to idle requested by thermal management |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Number of processors actually idled |

Information level 0x38 (56) is the processor-aggregator request of the power manager; its official `POWER_INFORMATION_LEVEL` name is ?

### `_OST` evaluation

After a `_PUR`-triggered request (not after a thermal-only change), the driver reports to the firmware. Inputbuffer (40 bytes, `ACPI_EVAL_INPUT_BUFFER_COMPLEX`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 69 43` 'AeiC' | Signature |
| 04-07 | `5F 4F 53 54` "_OST" | Method name |
| 08-0B | 28 00 00 00 | Size (40) |
| 0C-0F | 03 00 00 00 | Argument count |
| 10-13 | 00 00 04 00 | Arg 0: integer, length 4 |
| 14-17 | 80 00 00 00 | Source event: notification 0x80 |
| 18-1B | 00 00 04 00 | Arg 1: integer, length 4 |
| 1C-1F | 00 00 00 00 / 01 00 00 00 | Status: 0 = success, 1 = failure (`ZwPowerInformation` failed) |
| 20-23 | 02 00 04 00 | Arg 2: buffer, length 4 |
| 24-27 | | Number of processors idled (output of `ZwPowerInformation`) |

The 20-byte output and the result of `_OST` are ignored.

### Lumia 520 device node

Values read from `HKLM\SYSTEM\CurrentControlSet\Enum\ACPI\ACPI000C\2&daba3ff&0` (the `Properties` subkeys are device properties, decoded here):  
| Value / property | Content | Comment |
|------------------|---------|---------|
| HardwareID | `ACPI\VEN_ACPI&DEV_000C`, `ACPI\ACPI000C`, `*ACPI000C` | |
| Service | `acpipagr` | The driver is bound to the device |
| ClassGUID | `{4d36e97d-e325-11ce-bfc1-08002be10318}` | System devices |
| DeviceDesc | `@acpipagr.inf,%devicedesc%;ACPI Processor Aggregator` | |
| Driver | `{4d36e97d-e325-11ce-bfc1-08002be10318}\0004` | |
| Capabilities | 0x20 | `CM_DEVCAP_SILENTINSTALL` |
| ConfigFlags | 0x0 | No problem flag: the device installed and started normally |
| Device Parameters\FirmwareIdentified | 1 | Set by acpi.sys for firmware-enumerated devices |
| BIOS device name (`{540b947e-…}`,10) | `\_SB.AGR0` | ACPI namespace path |
| Location paths (`{a45c254e-…}`,37) | `ACPI(_SB_)#ACPI(AGR0)` | |
| Parent (`{83da6326-…}`,10) | `ACPI_HAL\PNP0C08\0` | ACPI root device of [acpi.sys](./acpi.md) |
| Driver INF / section (`{a8b865dd-…}`,5/6) | `acpipagr.inf`, `PagrInstall` | |
| Matching device id (`{a8b865dd-…}`,8) | `*ACPI000C` | |
| Driver version (`{a8b865dd-…}`,3) | 6.3.9651.0 | Windows Phone 8.1 build |
| Driver date (`{a8b865dd-…}`,2) | 2006-06-21 | Standard date of inbox INFs |
| Driver provider (`{a8b865dd-…}`,9) | Microsoft | |
| Install date (`{83da6326-…}`,100/101) | 2015-01-14 04:05:50 UTC | First install of the phone image |

### Interface GUID

Thermal cooling interface returned by acpipagr.sys (`WdfDeviceAddQueryInterface`)  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}` (GUID_THERMAL_COOLING_INTERFACE)

ACPI interface queried from the PDO  
`{B091A08A-BA97-11D0-BD14-00AA00B7B32A}` (GUID_ACPI_INTERFACE_STANDARD)
