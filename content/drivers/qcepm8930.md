## Qcepm8930.sys

Qualcomm Energy / Power Meter driver (`QCEPM8930.pdb`, built from `P:\QCEPM\rel\8.2.1\ARM\Release`).  
It's a very small KMDF driver (48 functions) that publishes a Windows **power meter** device interface (`GUID_DEVICE_POWER_METER`) and answers the PMI IOCTLs (device type `0x45`, `FILE_DEVICE_PMI`). The only real measurement is `IOCTL_PMI_GET_MEASUREMENT`: the battery power in mW, computed as `VBATT × current / 1000000`. The battery voltage comes from the ADC driver (`IOCTL_ADC_READ`, channel `VBATT`) and the current from [qcepmadc8930.sys](./qcepmadc8930.md) (device type `0x9ADC`, a QMI client of the modem EPM service).  
The power meter interface is only enabled while both peer interfaces are present. The two I/O targets are opened by the first measurement and closed again by a timer after `ActivityTimeout` seconds.  
It's the second power meter on the phone. [battc.sys](./battc.md) registers the same interface on the battery miniclass PDO and computes the power from the cached battery status.

There's no named `\Device\` object and no symbolic link (the WDF device is unnamed). The only way in is the device interface `GUID_DEVICE_POWER_METER` (see [Interface GUID](#interface-guid)).  
The PMI capabilities report the name `\\.\QCPowerMeter`, but the driver doesn't create that link.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>` (service name ?)

Registry value read with `WdfRegistryOpenKey` (`KEY_READ`) + `WdfRegistryQueryULong` from the driver's **service key** (`WdfDriverGetRegistryPath`, not the `Parameters` subkey), in `EvtDriverDeviceAdd` (sub_406008):  
| Registry value | value | comment |
|----------------|-------|---------|
| ActivityTimeout | 60 | REG_DWORD, seconds. Delay after the last `IOCTL_PMI_GET_MEASUREMENT` before the two I/O targets are closed (one-shot `WdfTimer`, restarted by every measurement). Missing value → 60 (0x3C). No range check |

GUID of the ETW provider:  
`{5BB75EA7-C9E8-4B4C-8B89-D535D860F4DB}`  
Registered in `DriverEntry` (`McGenEventRegister`, sub_4010F4). There's only one event, id 1000 (0x3E8), version 0, channel 0x10, level 2 (error), keyword 0x8000000000000000 (descriptor `.rdata:0x004030F0`). It's written by sub_401170 when a WDF/IO call of `EvtDriverDeviceAdd` fails. Payload: function name (UTF-16, e.g. `WdfDeviceCreate`, `WdfIoTargetCreate`, `IoRegisterPlugPlayNotification`), NTSTATUS (4 bytes), source file (`driver.c`), line (4 bytes).

It communicates with the following devices (found with `IoRegisterPlugPlayNotification` on their interface class; the symbolic link name is saved and opened later with `WdfIoTargetOpen` by name):  
| Interface class GUID | Driver | Comment |
|----------------------|--------|---------|
| `{10542F20-9718-452A-897A-45785468E57A}` | ADC driver ? (not documented yet) | `IOCTL_ADC_GET_CHANNEL` (0x8ADC2000) / `IOCTL_ADC_READ` (0x8ADC2004), channel `VBATT`. Same interface as [NokiaEnergyDriver.sys](./nokiaenergydriver.md#adc-channels), [qcpep8930.sys](./qcpep8930.md), [qcbattmngr8930.sys](./qcbattmngr8930.md). Context `+0x10` |
| `{75EC568A-D2EA-48FE-AE3D-395A7B45E65F}` (`\??\QCOM_EPM_ADC`) | [qcepmadc8930.sys](./qcepmadc8930.md) | Battery current, IOCTL `0x9ADC2400` (device type `0x9ADC`, EPM ADC read over QMI). Context `+0x00` |

Both targets are opened with `DesiredAccess` 0x1F0000 (`STANDARD_RIGHTS_ALL`), `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE` (sub_40129C). sub_40129C returns `STATUS_INVALID_PARAMETER` (0xC000000D) when the symbolic link of the interface isn't known yet.

### Startup and device context

`EvtDriverDeviceAdd` (sub_406008):
1. `WdfDeviceCreate` with the context `DEVICE_CONTEXT` and the cleanup callback sub_401220 (unregisters both PnP notifications and frees the saved symbolic link names).
2. `WdfDeviceCreateDeviceInterface(GUID_DEVICE_POWER_METER)`, then `WdfDeviceSetDeviceInterfaceState(FALSE)`: the interface exists but is disabled.
3. Default queue (sequential), `EvtIoDeviceControl` = sub_401468.
4. One-shot timer (passive level, `AutomaticSerialization`), callback sub_401318: closes both I/O targets.
5. Reads `ActivityTimeout`.
6. Creates the two I/O targets (`WdfIoTargetCreate`) and closes them at once. They're only opened by a measurement.
7. `IoRegisterPlugPlayNotification(EventCategoryDeviceInterfaceChange, PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES)` on the ADC interface `{10542F20-…}`, then on `{75EC568A-…}`, both with the callback sub_4015F0.

PnP callback sub_4015F0:
* `GUID_DEVICE_INTERFACE_ARRIVAL`: copies the symbolic link name into the context (pool tag `qep1` for `{75EC568A-…}`, `qep2` for the ADC). When both names are known, it enables the power meter interface.
* `GUID_DEVICE_INTERFACE_REMOVAL`: frees the name and disables the power meter interface.

`DEVICE_CONTEXT`:  
| Offset | Comment |
|--------|---------|
| +0x00 | WDFIOTARGET of `{75EC568A-…}` (current) |
| +0x04 | PnP notification entry of `{75EC568A-…}` |
| +0x08 | UNICODE_STRING symbolic link of `{75EC568A-…}` (buffer at `+0x0C`) |
| +0x10 | WDFIOTARGET of the ADC `{10542F20-…}` |
| +0x14 | PnP notification entry of the ADC |
| +0x18 | UNICODE_STRING symbolic link of the ADC (buffer at `+0x1C`) |
| +0x20 | Cached ADC channel id of `VBATT`, −1 = not looked up yet |
| +0x24 | WDFTIMER (idle close) |
| +0x28 | `ActivityTimeout` in seconds |

### PMI IOCTL dispatch

`EvtIoDeviceControl` (sub_401468):  
| IOCTL | Name | Result |
|-------|------|--------|
| 0x454000 | IOCTL_PMI_GET_CAPABILITIES | See below |
| 0x454004 | IOCTL_PMI_GET_CONFIGURATION | `STATUS_NOT_IMPLEMENTED` (0xC0000002) |
| 0x45400C | IOCTL_PMI_GET_MEASUREMENT | See below |
| 0x458008 | IOCTL_PMI_SET_CONFIGURATION | `STATUS_NOT_IMPLEMENTED` (0xC0000002) |
| any other (e.g. 0x45C010 IOCTL_PMI_REGISTER_EVENT_NOTIFY) | | `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) |

The names are the Windows power meter interface codes, as in [battc.sys](./battc.md#ioctl-0x454000--0x454004--0x458008--0x45c010--pmi-ioctls-not-implemented).

---

### IOCTL 0x454000 — IOCTL_PMI_GET_CAPABILITIES

This IOCTL is processed by Qcepm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x45 |
| Function | 0x0 (0) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PMI_GET_CAPABILITIES | ≥ 152 | ≥ 54 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | Not read |
| 08-0B | 01 00 00 00 | Capability type. Only 1 (`PmiMeteredHardware` ?) is accepted, anything else → `STATUS_NOT_IMPLEMENTED` (0xC0000002) |
| 0C-97 | ? | Not read |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version |
| 04-07 | 36 00 00 00 | Size = 54 |
| 08-0B | 01 00 00 00 | Capability type (`PmiMeteredHardware` ?) |
| 0C-0F | 01 00 00 00 | Number of metered hardware entries ? |
| 10-31 | `\\.\QCPowerMeter` | UTF-16 with NUL (34 bytes) |
| 32-35 | 00 00 00 00 | Padding |

The minimum input length (152) is the size of a full `PMI_CAPABILITIES` structure ?. The type is read at the same offset (`+0x08`) as in the output. The whole output buffer (`OutputBufferLength`) is zeroed before it's filled. `BytesReturned` = 54. The PMI targets aren't touched.

---

### IOCTL 0x45400C — IOCTL_PMI_GET_MEASUREMENT

This IOCTL is processed by Qcepm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x45 |
| Function | 0x3 (3) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PMI_GET_MEASUREMENT | 0 | ≥ 8 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version |
| 04-07 | ? | Battery power in mW |

Steps:
1. Opens the ADC target, then the current target (sub_40129C, nothing is done if they're already open). If either open fails, both are closed and the error is returned (e.g. 0xC000000D before both interfaces have arrived). Otherwise the idle timer is (re)started with `ActivityTimeout` seconds.
2. sub_40136C: if the `VBATT` channel id isn't cached yet, sends `IOCTL_ADC_GET_CHANNEL` and caches the id. A failed IOCTL keeps −1 and returns `STATUS_UNSUCCESSFUL` (0xC0000001). The "found" flag (output `00-03`) **isn't checked**.
3. sub_4017A8: `IOCTL_ADC_READ` with the channel id → VBATT in mV. The output `00-03` must be 1, otherwise `STATUS_UNSUCCESSFUL`.
4. VBATT < 3200 mV → `STATUS_INVALID_DEVICE_STATE` (0xC0000184).
5. sub_401700: IOCTL `0x9ADC2400` → battery current (µA ?).
6. Power = `VBATT × current / 1000000` (signed 64-bit product, **unsigned** 64-bit division `__rt_udiv64`, truncated to 32 bits). A negative current gives a meaningless huge value instead of a negative power.

`BytesReturned` = 8.

---

### IOCTL 0x8ADC2000 — IOCTL_ADC_GET_CHANNEL

This IOCTL is sent by Qcepm8930.sys to the ADC driver (interface `{10542F20-…}`)

| Property | Value |
|----------|-------|
| Device | 0x8ADC |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ADC_GET_CHANNEL | ADC `{10542F20-…}` | 6 | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-05 | `VBATT\0` | ASCII channel name (`.rdata:0x0040286C`) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 1 = found (not checked by this driver) |
| 04-07 | ? | Channel id, cached at context `+0x20` |

---

### IOCTL 0x8ADC2004 — IOCTL_ADC_READ

This IOCTL is sent by Qcepm8930.sys to the ADC driver (interface `{10542F20-…}`)

| Property | Value |
|----------|-------|
| Device | 0x8ADC |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ADC_READ | ADC `{10542F20-…}` | 4 | 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Channel id of `VBATT` |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 1 = valid, required |
| 04-07 | ? | VBATT in mV |
| 08-13 | ? | Not used |

---

### IOCTL 0x9ADC2400

This IOCTL is sent by Qcepm8930.sys to [qcepmadc8930.sys](./qcepmadc8930.md#ioctl-0x9adc2400) (interface `{75EC568A-D2EA-48FE-AE3D-395A7B45E65F}`)

| Property | Value |
|----------|-------|
| Device | 0x9ADC |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ? (read EPM channel) | `{75EC568A-…}` | 8 | 12 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Measurement type ? (≠ 0 = current ?) |
| 04-07 | 07 00 00 00 | EPM channel ? (7 = battery current ?) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Status, must be 0, otherwise `STATUS_UNSUCCESSFUL` (0xC0000001) |
| 04-07 | ? | Battery current, signed (µA ?, the result divided by 1000000 is used as mW) |
| 08-0B | FF FF 00 00 | Always 0xFFFF, not used |

---

### Interface GUID

Power meter device interface (created by qcepm8930.sys, enabled only while both peer interfaces are present)  
`{E849804E-C719-43D8-AC88-96B894C191E2}` (GUID_DEVICE_POWER_METER)

### Other GUID

ADC interface (consumed)  
`{10542F20-9718-452A-897A-45785468E57A}`

EPM ADC interface of [qcepmadc8930.sys](./qcepmadc8930.md), device type `0x9ADC` (consumed)  
`{75EC568A-D2EA-48FE-AE3D-395A7B45E65F}`

ETW provider  
`{5BB75EA7-C9E8-4B4C-8B89-D535D860F4DB}`
