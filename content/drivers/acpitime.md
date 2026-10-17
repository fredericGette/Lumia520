## Acpitime.sys

Microsoft driver for the ACPI **Time and Alarm device** (`ACPI000E`, ACPI spec §9.18) (KMDF, PDB symbols available, 35 functions).  
It is the function driver of the `ACPI000E` node, on top of [acpi.sys](./acpi.md). It gives the kernel access to the firmware real-time clock (`_GRT` / `_SRT`) and to the two firmware wake timers, AC and DC (`_STV`, `_STP`, `_TIV`, `_TIP`, `_GWS`, `_CWS`). Every operation is an evaluation of an ACPI method, sent to acpi.sys as an internal `IOCTL_ACPI_EVAL_METHOD`. The driver doesn't touch any hardware itself.  
When the firmware signals a wake (`Notify(…, 0x02)`), it finds which timer woke the system and reports it to the power manager with `PoSetFixedWakeSource`.

> [!NOTE]
> All IOCTLs are rejected with `STATUS_INVALID_DEVICE_REQUEST` when the requestor mode is user mode (`WdfRequestGetRequestorMode`): kernel-mode callers only.  
> On the Lumia 520, `_GCP` returns `0x4`: only Get/Set real time is supported. **There's no wake-alarm support** in the firmware (no AC/DC wake bits).

There's no named device and no `\DosDevices` link. The driver registers a device interface (`WdfDeviceCreateDeviceInterface`):  
Interface : `GUID_DEVICE_ACPI_TIME` `{97F99BF6-4497-4F18-BB22-4B9FB2FBEF9C}`  
Symbolic link on the Lumia 520 : `\GLOBAL??\ACPI#ACPI000E#2&daba3ff&0#{97f99bf6-4497-4f18-bb22-4b9fb2fbef9c}`

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\acpitime`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\ACPI000E\2&daba3ff&0`

There's no parameters in the registry.

GUID of the ETW provider:  
None. The only trace is a `DbgPrint` in `WaAcpiNotifyCallback` (`"WaAcpiNotifyCallback(%p, %#08lx)\n"`).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI PDO of `ACPI000E` (default I/O target) | [acpi.sys](./acpi.md) | internal `IOCTL_ACPI_EVAL_METHOD` (0x32C004) for every ACPI method; `GUID_ACPI_INTERFACE_STANDARD` to receive the `Notify` |
| Kernel power manager | ntoskrnl | `PoSetFixedWakeSource` |
| — | Kernel time service (HAL / `ExpTimeRefreshWork` ?) | Caller of `IOCTL_ACPI_GET_REAL_TIME` / `IOCTL_ACPI_SET_REAL_TIME` through the device interface ? |

### Lumia 520 ACPI node

From the DSDT. The node is `\_SB.PRTC` (`_HID` `ACPI000E`, no `_UID`), with `_DEP` on `\_SB.PMAP` ([qcpmicapps8930.sys](./qcpmicapps8930.md)). It defines only `_GCP`, `_GRT` and `_SRT`. There's no `_STV`/`_TIV`/`_GWS`…, so the wake-alarm IOCTLs fail in acpi.sys (method not found).

```
Method (_GCP) { Return (0x04) }
Field (\_SB.ABD.ROP1, BufferAcc, NoLock, Preserve) {
    Connection (I2cSerialBusV2 (0x0002, ControllerInitiated, 0, AddressingMode7Bit, "\_SB.ABD", ...)),
    AccessAs (BufferAcc, AttribRawBytes (0x10)),
    FLD0, 128
}
Method (_GRT) { BUFF (18 bytes) = FLD0; Return (bytes 2..17 of BUFF) }
Method (_SRT, 1) { bytes 2..17 of BUFF = Arg0; BUFF = (FLD0 = BUFF); Return (STAT != 0 ? 1 : 0) }
```

The real-time clock is therefore an I²C-like operation region on the software SPB controller `\_SB.ABD` ([qcabd8930.sys](./qcabd8930.md)), slave address 2. Slave address 2 is the one that [qcpmicapps8930.sys](./qcpmicapps8930.md) registers (its `GEPT` returns 2). The full path of `_GRT`/`_SRT` is: acpitime.sys → acpi.sys (AML) → [acpiex.sys](./acpiex.md) (`GenericSerialBus` region) → qcabd8930.sys (`IOCTL_SPB_EXECUTE_SEQUENCE`) → qcpmicapps8930.sys (`IOCTL_PM_ABD_GET/SET_PMIC_RTC_DATA`) → [qcpmic8930.sys](./qcpmic8930.md) (PMIC RTC). The 2 bytes in front of the 16-byte time are the status/length header of the `BufferAcc` access; byte 0 (`STAT`) is the status returned by `_SRT`.

### Start-up

1. `WaDeviceAdd` (0x15000): PnP callbacks, a `WA_EXTENSION` context (52 bytes), a default queue with `EvtIoDeviceControl` = `WaIoDeviceControl`, and the `GUID_DEVICE_ACPI_TIME` interface.
2. `WaEvtDevicePrepareHardware` (0x151E8): queries `GUID_ACPI_INTERFACE_STANDARD` (44 bytes, version 1) into the context (`+00`…`+2B`) and calls `RegisterForDeviceNotifications(PDO, WaAcpiNotifyCallback, Device)`. A registration failure only dereferences the interface and **isn't reported**. It then reads the capabilities (`WaGetCapabilities`). If that fails, the device fails to start.
3. `WaEvtDeviceReleaseHardware` (0x15268): unregisters the notification and dereferences the interface.

Context `WA_EXTENSION`:  
| Offset | Comment |
|--------|---------|
| +00-2B | `ACPI_INTERFACE_STANDARD` returned by acpi.sys (`RegisterForDeviceNotifications` at +24, `UnregisterForDeviceNotifications` at +28) |
| +2C | Mask of the timers set by `IOCTL_SET_WAKE_ALARM_VALUE`: 0x08 = AC timer, 0x10 = DC timer (bit cleared when the value is 0xFFFFFFFF). Named `Capabilities_Flags` in the IDB, but it isn't the capabilities |
| +30 | Result of `_GCP` |

### ACPI `_GCP` (capabilities)

`WaGetCapabilities` (0x15854) evaluates `_GCP` (`'AeiB'`, no argument, 20-byte output). The result must be one integer (`Length` = 20, `Count` = 1, type 0). If the method doesn't exist (`0xC0000034 STATUS_OBJECT_NAME_NOT_FOUND`), the driver assumes **0xFF** (everything supported). Any other error → `STATUS_UNSUCCESSFUL`, and the device fails to start.  
| Bit | Meaning (ACPI) | Use in the driver | Lumia 520 |
|-----|----------------|-------------------|-----------|
| 0 | AC wake implemented | — | 0 |
| 1 | DC wake implemented | — | 0 |
| 2 | Get/Set real time implemented | Required by the real-time IOCTLs (`STATUS_NOT_SUPPORTED` 0xC00000BB otherwise) | **1** |
| 3 | Real-time accuracy in milliseconds | When 0, `IOCTL_ACPI_GET_REAL_TIME` forces Milliseconds = 500 | 0 |
| 4 | `_GWS` implemented | — | 0 |
| 5-8 | Wake from S4/S5 on AC/DC | — | 0 |

The wake-alarm IOCTLs only check that the whole `_GCP` value is non-zero, so on the Lumia 520 they aren't rejected by the driver: they fail when acpi.sys can't find `_STV`/`_TIV`… (if the firmware doesn't implement them ?).

### ACPI notification

`WaAcpiNotifyCallback` (0x15118) only handles **0x02** (device wake):
1. `_GWS(0)` and `_GWS(1)` (`'AeiI'`, Get Wake Status): bit 1 (timer caused the wake) of the result → wake flag 0x08 (AC timer) / 0x10 (DC timer).
2. If both `_GWS` calls failed: for each timer that is set (mask `+2C`), `WaIsAlarmExpired` is used instead (see below).
3. Otherwise `_CWS(0)` and `_CWS(1)` (Clear Wake Status, result must be integer 0).
4. `PoSetFixedWakeSource(flags)`.

`WaIsAlarmExpired` (0x157F0) considers a timer expired when `_TIV` returns 0xFFFFFFFF **and** `_TIP` returns 0xFFFFFFFF.

---

### IOCTL 0x294210 — IOCTL_ACPI_GET_REAL_TIME

This IOCTL is processed by Acpitime.sys

| Property | Value |
|----------|-------|
| Device | 0x29 (FILE_DEVICE_BATTERY) |
| Function | 0x84 (132) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_GET_REAL_TIME | 0 | ≥ 16 |

Backend: `WaHandleAcpiGetRealTime` (0x155AC). Requires `_GCP` bit 2. Evaluates `_GRT` (`'AeiB'`, 36-byte output). The result must be one buffer (type 2) of exactly 16 bytes whose `Valid` byte is non-zero, otherwise `STATUS_UNSUCCESSFUL`. The 16 bytes are copied unchanged (it is **not** a `TIME_FIELDS`), 16 bytes returned.

Outputbuffer (ACPI time buffer, ACPI spec `_GRT`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | e.g. `EA 07` | Year (2026) |
| 02 | | Month (1-12) |
| 03 | | Day (1-31) |
| 04 | | Hour (0-23) |
| 05 | | Minute (0-59) |
| 06 | | Second (0-59) |
| 07 | 01 | Valid: 0 = time not valid (rejected by the driver) |
| 08-09 | F4 01 | Milliseconds. Forced to 500 when `_GCP` bit 3 is 0 (Lumia 520) |
| 0A-0B | | TimeZone in minutes from UTC (−1440…1440, 2047 = unspecified) |
| 0C | | Daylight: bit 0 = time adjusted for daylight saving, bit 1 = time zone observes daylight saving |
| 0D-0F | | Padding |

---

### IOCTL 0x298214 — IOCTL_ACPI_SET_REAL_TIME

This IOCTL is processed by Acpitime.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x85 (133) |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ACPI_SET_REAL_TIME | ≥ 16 | 0 |

Inputbuffer: the same 16-byte ACPI time buffer as above.

Backend: `WaHandleAcpiSetRealTime` (0x156C8). Requires `_GCP` bit 2. Evaluates `_SRT` (`'AeiC'`, one buffer argument of 16 bytes, the input copied unchanged). The result must be the integer 0, otherwise `STATUS_UNSUCCESSFUL`. 0 bytes returned.

---

### IOCTL 0x298200 — IOCTL_SET_WAKE_ALARM_VALUE
### IOCTL 0x298204 — IOCTL_SET_WAKE_ALARM_POLICY
### IOCTL 0x29C208 — IOCTL_GET_WAKE_ALARM_VALUE
### IOCTL 0x29C20C — IOCTL_GET_WAKE_ALARM_POLICY

These IOCTLs are processed by Acpitime.sys

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x80 / 0x81 / 0x82 / 0x83 |
| Access | FILE_WRITE_ACCESS (0x80, 0x81) / READ_AND_WRITE (0x82, 0x83) |
| Method | METHOD_BUFFERED |

| Name | ACPI method | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SET_WAKE_ALARM_VALUE | `_STV` (Set Timer Value) | 8 | any (nothing returned) |
| IOCTL_SET_WAKE_ALARM_POLICY | `_STP` (Set Expired Timer Wake Policy) | 8 | any (nothing returned) |
| IOCTL_GET_WAKE_ALARM_VALUE | `_TIV` (Timer Values) | 8 | 8 |
| IOCTL_GET_WAKE_ALARM_POLICY | `_TIP` (Expired Timer Wake Policy) | 8 | 8 |

Sizes are checked by **exact** match in `WaIoDeviceControl` (input = 8, and output = 8 for the two GET codes), otherwise `STATUS_INFO_LENGTH_MISMATCH` (0xC0000004).

Inputbuffer (`WAKE_ALARM_INFORMATION` ?):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 / 01 00 00 00 | TimerIdentifier: 0 = AC timer, 1 = DC timer. Other → `STATUS_INVALID_PARAMETER` (0xC000000D) |
| 04-07 | | SET only: value in seconds (`_STV`: time until the wake; `_STP`: how long after an expiry the system still wakes). 0xFFFFFFFF = disabled / never. Ignored by the GET codes |

Outputbuffer (GET codes only, 8 bytes returned):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | TimerIdentifier (copied from the input) |
| 04-07 | | `_TIV`: seconds remaining, 0xFFFFFFFF = timer disabled. `_TIP`: policy in seconds, 0xFFFFFFFF = never wake |

Backend: `WaHandleWakeAlarmControl` (0x153E4). Fails with `STATUS_NOT_SUPPORTED` when `_GCP` is 0. Evaluates the method with `'AeiC'`: argument 0 = TimerIdentifier, plus argument 1 = value for the SET codes. The output must be 20 bytes with one integer, otherwise `STATUS_UNSUCCESSFUL`. For the SET codes the integer must be 0 (`STATUS_NOT_SUPPORTED` otherwise). `IOCTL_SET_WAKE_ALARM_VALUE` also updates the timer mask at context `+2C`.

---

### IOCTLs sent by acpitime.sys

All are sent as **internal** `IOCTL_ACPI_EVAL_METHOD` (0x32C004, `WdfIoTargetSendInternalIoctlSynchronously`) to the default I/O target (the `ACPI000E` PDO of [acpi.sys](./acpi.md#ioctl-0x32c000--ioctl_acpi_async_eval_method)):  
| Method | Input signature | Arguments | Output size | Expected result |
|--------|-----------------|-----------|-------------|-----------------|
| `_GCP` | 'AeiB' | — | 20 | Integer |
| `_GRT` | 'AeiB' | — | 36 | Buffer of 16 bytes |
| `_SRT` | 'AeiC' | Buffer (16 bytes) | 20 | Integer 0 |
| `_STV`, `_STP` | 'AeiC' | Integer timer, integer value | 20 | Integer 0 |
| `_TIV`, `_TIP` | 'AeiC' | Integer timer | 20 | Integer |
| `_GWS` | 'AeiI' | Integer timer | 20 | Integer |
| `_CWS` | 'AeiI' | Integer timer | 20 | Integer 0 |

### Interface GUID

ACPI time device interface (created by acpitime.sys)  
`{97F99BF6-4497-4F18-BB22-4B9FB2FBEF9C}` (GUID_DEVICE_ACPI_TIME)

ACPI interface queried from the PDO  
`{B091A08A-BA97-11D0-BD14-00AA00B7B32A}` (GUID_ACPI_INTERFACE_STANDARD)
