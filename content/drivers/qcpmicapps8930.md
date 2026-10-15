## Qcpmicapps8930.sys

PMIC "apps" driver: real-time clock (wall-clock time) on top of the PMIC RTC (Qualcomm KMDF driver, PDB `pmicapps\fre\qcpmicapps8930.pdb`, 76 functions).  
The PMIC RTC of [qcpmic8930.sys](./qcpmic8930.md) is only a free-running seconds counter (it's not a Unix time). This driver turns it into a date: it keeps the offset between the counter and the real time in the UEFI variable `RTCInfo`, and converts `counter + offset` (seconds since 1980-01-06, the GPS epoch) into the 16-byte ACPI `_GRT`/`_SRT` time structure.  
It exposes two IOCTLs, `IOCTL_PM_ABD_GET_PMIC_RTC_DATA` and `IOCTL_PM_ABD_SET_PMIC_RTC_DATA`, and registers them with [qcabd8930.sys](./qcabd8930.md) (`{2B0FDE10-…}` interface). That driver is a software I²C target: an ACPI `GenericSerialBus` operation region access on the I²C slave address given by `GEPT` reaches these two IOCTLs. ACPI `_GRT` / `_SRT` ([acpitime.sys](./acpitime.md)) probably get to the PMIC RTC this way: AML → [acpiex.sys](./acpiex.md) → qcabd8930.sys → this driver → qcpmic8930.sys ?  
It also writes `0` to up to two GPIO lines listed in its ACPI resources each time the device enters D0.

There's no named device and no `\DosDevices` link. The driver registers a device interface (`WdfDeviceCreateDeviceInterface`):  
Interface : `{CA95CEB1-A382-4F06-B65E-0A90115609A5}`

`WdfDeviceSetStaticStopRemove(FALSE)` is called: the device can't be stopped or removed.

> [!NOTE]
> The surprise-removal callback (`EvtWdfDeviceSurpriseRemoval`, 0x402218) calls `KeBugCheckEx(0x14E, 0x51706130 'Qpa0', 0, 0, 0)`: removing the device crashes the phone (same behaviour as qcpmic8930.sys, with `'Qpm0'`).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcpmicapps8930`  

Registry value, read and written in the driver's **service key** (`WdfDriverGetRegistryPath`, not the `Parameters` subkey):  
| Registry value | value | comment |
|----------------|-------|---------|
| IsRTCTimeValid | 0 | REG_DWORD. Despite its name, it's the PMIC RTC counter (seconds) at the moment the time was last set with `IOCTL_PM_ABD_SET_PMIC_RTC_DATA` (written by `sub_4010C0`, read by `sub_401008`). At start-up the time is considered valid if the current counter is **greater** than this value, i.e. the RTC hasn't been reset since the last set |

UEFI variable (read with internal IOCTL 0x520004, written with internal IOCTL 0x520008 of [qcscm8930.sys](./qcscm8930.md), attribute 1 = NON_VOLATILE, extended to 7 = NV+BS+RT by qcscm8930.sys):  
| Name | Vendor GUID | Size | Comment |
|------|-------------|------|---------|
| RTCInfo | `{882F8C2B-9646-435F-8DE5-F208FF80C1BD}` | 8 | Offset between the PMIC RTC counter and the real time. Same vendor GUID as `BmsDataVariables` of [qcbms8930.sys](./qcbms8930.md) |

Content of `RTCInfo` (global `dword_411AAC`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Offset in seconds: real time (seconds since 1980-01-06 00:00:00) − PMIC RTC counter |
| 04-05 | 00 00 | Always 0 when written (`word_411AB0`) |
| 06-07 | 00 00 | Always 0 when written (`word_411AB2`) |

GUID of the ETW provider:  
None. The driver contains `EtwWrite` calls (`PmicSendDriverRequest*` entry/exit and errors, in `PmicDriverRequest.c`) but never calls `EtwRegister`: they use a null registration handle, and the enable flags (`dword_411ABC`) are never set.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of the device (default I/O target) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) on method `GEPT` (see below) |
| `{61630799-922A-4980-99D9-90C39084A979}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC RTC: `IOCTL_PM_RTC_GET_TIME` (0x800A0FA8), `IOCTL_PM_RTC_START` (0x800A0FA0) |
| `{2B0FDE10-DED1-40C1-AF2E-031836A066A8}` | [qcabd8930.sys](./qcabd8930.md) | ABD (software I²C target for ACPI): attach (0xC3502FA4) / detach (0xC3502FA8) of the two IOCTLs of this driver. In return, qcabd8930.sys sends them to this driver |
| `{A942B3D9-EC95-4754-AE45-49C48735B893}` | [qcscm8930.sys](./qcscm8930.md) | UEFI variable service `GUID_SYSENV_INTERFACE` (`\Device\SysEnv`): internal IOCTLs 0x520004 (`IOCTL_SYSENV_GET_VARIABLE`) and 0x520008 (`IOCTL_SYSENV_SET_VARIABLE`) for `RTCInfo`. Also awaited by [qcbms8930.sys](./qcbms8930.md) and [wpcrdmp.sys](./wpcrdmp.md) |
| `\Device\RESOURCE_HUB\<connection id>` | GPIO controller | Up to two GPIO lines from the ACPI resources, written to 0 on D0 entry (`IOCTL_GPIO_WRITE_PINS` 0x480004) |

The three interfaces are found with `IoRegisterPlugPlayNotification(EventCategoryDeviceInterfaceChange, PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES)` (`sub_401588`), callback `sub_4014F8`; on arrival the symbolic link is opened with `IoGetDeviceObjectPointer(GENERIC_ALL)`.

### Start-up

1. `DriverEntry` (0x402248): `WdfDriverCreate`, pool tag `'qpa0'`.
2. `EvtDriverDeviceAdd` → `sub_413008`: PnP/power callbacks, `WdfDeviceCreate` (context `PMIC_APPS_DEVICE_CONTEXT`, passive execution level), default queue (`sub_413110`, sequential, `EvtIoDeviceControl` = `EvtWdfIoQueueIoDeviceControl`).
3. `EvtWdfDevicePrepareHardware` (0x401E90): counts the translated resources of type `CmResourceTypeConnection` (0x84) with class GPIO (1) / type GPIO_IO (2), and stores their connection IDs (at most 2, context `+0x08`). Any other connection resource → `STATUS_UNSUCCESSFUL`. Then `sub_401690`:
   * evaluates ACPI `GEPT` (`sub_401168`); a failure makes the device fail to start,
   * prepares the 32-byte registration block (see [IOCTL 0xC3502FA4](#ioctl-0xc3502fa4)),
   * registers the 3 PnP notifications,
   * creates the `{CA95CEB1-…}` interface.
4. When the qcpmic8930 interface arrives (`sub_4012A8`): reads `IsRTCTimeValid`, sends `IOCTL_PM_RTC_GET_TIME`.
   * PMIC error 30 (RTC not running ?) → `IOCTL_PM_RTC_START` with start time 0.
   * no error and counter > `IsRTCTimeValid` → time valid flag `byte_411AA8` = 1.
5. When both the qcpmic8930 and the `{2B0FDE10-…}` ([qcabd8930.sys](./qcabd8930.md)) interfaces are present: sends the attach IOCTL 0xC3502FA4. When one of them goes away: sends 0xC3502FA8.
6. `EvtWdfDeviceD0Entry` (0x402200) → `sub_401F98`: for each GPIO connection, opens `\Device\RESOURCE_HUB\<id as %016I64x>` (`FILE_GENERIC_WRITE`) and sends `IOCTL_GPIO_WRITE_PINS` with 1 byte = `00` (synchronous, 1 s timeout). The status is ignored by D0Entry.
7. `EvtWdfDeviceSelfManagedIoInit` / `Restart` start the queue, `Suspend` stops it. `EvtWdfDeviceD0Exit` does nothing. `EvtWdfDeviceReleaseHardware` unregisters the PnP notifications.

### ACPI `GEPT`

`GEPT` is evaluated without argument (`ACPI_EVAL_INPUT_BUFFER` signature `'AeiB'`, 20-byte output buffer). If the output signature is `'AeoB'` and the count is non-zero, the **low byte** of the first argument's data is stored as a WORD at context `+0x28` (offset `0x10` of the registration block). The argument type isn't checked. This value is the I²C slave address that [qcabd8930.sys](./qcabd8930.md) matches against the `I2cSerialBus` connection of the operation region, so `GEPT` probably returns the slave address of the "RTC" behind that operation region ? (only the low byte is kept, so a 10-bit address can't be used).

### Time format

Time is converted between a seconds counter and the 16-byte structure of the ACPI `_GRT` / `_SRT` methods (ACPI spec §9.18, same layout as in [acpitime.sys](./acpitime.md)):  
| Bytes | Field | Comment |
|-------|-------|---------|
| 00-01 | Year | |
| 02 | Month | 1-12 |
| 03 | Day | 1-31 |
| 04 | Hour | |
| 05 | Minute | |
| 06 | Second | |
| 07 | Valid | GET: `byte_411AA8` (0 = time not valid, 1 = valid) |
| 08-09 | Milliseconds | GET: always 0 |
| 0A-0B | TimeZone | GET: always 0. SET: signed, minutes, added to the time (`seconds + 60 × TimeZone`) |
| 0C | Daylight | GET: 0 |
| 0D-0F | Pad | Not written |

Conversion functions: `sub_401C3C` (date → seconds) and `sub_401B40` (seconds → date), both with the origin 1980-01-06 00:00:00 (seconds since 1980-01-01 − 432000).

### Other remarks

* `EvtIoDefault` is a no-op (`nullsub_1`): a read or write request is never completed.
* The queue context holds a 10-second WDF timer (`sub_413218`, callback `sub_402370`) that completes a stored request; nothing stores a request there and `WdfTimerStart` is never called (same unused code as in qcpmic8930.sys).
* The GPIO I/O targets opened on D0 entry are closed only on failure: a new target is opened on every D0 entry.
* The GPIO resource counter is a global (`dword_411AB8`) that is never reset: a second `PrepareHardware` (device restart) would count from the previous value and fail with `STATUS_UNSUCCESSFUL`.
* `EvtWdfDeviceReleaseHardware` doesn't unregister the `{A942B3D9-…}` notification. On its removal, the file object is dereferenced without a null check.
* `RTCInfo` is read with the size returned by the variable service (`out+4`) into a 8-byte global, without bound check.

---

### IOCTL 0x80100FA0 — IOCTL_PM_ABD_GET_PMIC_RTC_DATA

This IOCTL is processed by Qcpmicapps8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x8010 |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PM_ABD_GET_PMIC_RTC_DATA | ignored | 16 |

Sent by [qcabd8930.sys](./qcabd8930.md#ioctl-0x41808--ioctl_spb_execute_sequence) when the last transfer of an SPB sequence on the registered slave address is a read. The input is 4 bytes holding the read buffer length, and the output is the read buffer itself.

Handler `sub_40199C`:
1. OutputBufferLength must be exactly 16, otherwise `STATUS_INVALID_PARAMETER_4` (0xC00000F2).
2. Reads the PMIC RTC counter (`IOCTL_PM_RTC_GET_TIME`). Its status is ignored once the offset is loaded.
3. On the first call, reads the UEFI variable `RTCInfo` (`sub_401854`, internal IOCTL 0x520004). Failure → its status is returned.
4. Converts `counter + offset` into the [time structure](#time-format).

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | ? | ACPI time structure, see [Time format](#time-format) |

Information = 16.

---

### IOCTL 0x80100FA4 — IOCTL_PM_ABD_SET_PMIC_RTC_DATA

This IOCTL is processed by Qcpmicapps8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x8010 |
| Function | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_PM_ABD_SET_PMIC_RTC_DATA | 16 | not written |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | | ACPI time structure, see [Time format](#time-format). Only Year…Second and TimeZone are used |

Sent by [qcabd8930.sys](./qcabd8930.md#ioctl-0x41808--ioctl_spb_execute_sequence) when the last transfer of an SPB sequence on the registered slave address is a write. The input is the write buffer, with no output.

Handler `sub_401A58`:
1. InputBufferLength must be exactly 16, otherwise `STATUS_INVALID_PARAMETER_2` (0xC00000F0).
2. Converts the date into seconds since 1980-01-06, plus `60 × TimeZone`.
3. Reads the PMIC RTC counter (`IOCTL_PM_RTC_GET_TIME`). On success: the time valid flag is set to 1 and the counter is written to the registry value `IsRTCTimeValid`.
4. Requested time < counter → `STATUS_INVALID_PARAMETER_1` (0xC00000EF): a date before the RTC counter can't be represented.
5. `offset = requested − counter` is written to the UEFI variable `RTCInfo` (`sub_401720`, internal IOCTL 0x520008). Its status is returned.

The output buffer isn't touched, but Information is set to OutputBufferLength.

> [!NOTE]
> Any other code of device type 0x8010 is completed with `STATUS_SUCCESS` and Information = 0. Codes of another device type → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### IOCTL 0xC3502FA4

This IOCTL is sent by Qcpmicapps8930.sys to [qcabd8930.sys](./qcabd8930.md#ioctl-0xc3502fa4--attach) (`{2B0FDE10-DED1-40C1-AF2E-031836A066A8}` interface)  

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0xBE9 (3049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ABD attach | `{2B0FDE10-…}` interface | 32 | 0 |

Sent by `sub_4013B0` once both the `{2B0FDE10-…}` and the qcpmic8930 interfaces are present. The block is stored in the device context at `+0x18`.

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | B1 CE 95 CA 82 A3 06 4F B6 5E 0A 90 11 56 09 A5 | `{CA95CEB1-A382-4F06-B65E-0A90115609A5}`, interface of this driver. qcabd8930.sys waits for it with a PnP notification to get the device object |
| 10-11 | ? | Low byte of the ACPI `GEPT` result: the I²C slave address served |
| 12-13 | 00 00 | |
| 14-17 | A0 0F 10 80 | 0x80100FA0 `IOCTL_PM_ABD_GET_PMIC_RTC_DATA`, sent for a read |
| 18-1B | A4 0F 10 80 | 0x80100FA4 `IOCTL_PM_ABD_SET_PMIC_RTC_DATA`, sent for a write |
| 1C-1F | 10 00 00 00 | 16, size of the time structure (stored but unused by qcabd8930.sys) |

---

### IOCTL 0xC3502FA8

This IOCTL is sent by Qcpmicapps8930.sys to [qcabd8930.sys](./qcabd8930.md#ioctl-0xc3502fa8--detach) (`{2B0FDE10-DED1-40C1-AF2E-031836A066A8}` interface)  

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0xBEA (3050) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ABD detach | `{2B0FDE10-…}` interface | 16 | 0 |

Sent by `sub_401240` when the `{2B0FDE10-…}` or the qcpmic8930 interface goes away.

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | B1 CE 95 CA 82 A3 06 4F B6 5E 0A 90 11 56 09 A5 | `{CA95CEB1-A382-4F06-B65E-0A90115609A5}` |

---

### IOCTL 0x800A0FA8 — IOCTL_PM_RTC_GET_TIME

This IOCTL is sent by Qcpmicapps8930.sys to qcpmic8930.sys (see [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x800axxxx--rtc))  

| Property | Value |
|----------|-------|
| Device | 0x800A |
| Function | 0x3EA (1002) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_RTC_GET_TIME | `{61630799-…}` interface | 4 | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 90 35 09 00 | RTC counter in seconds (603 536) |
| 04-07 | 00 00 00 00 | PMIC error. 30 (`1E 00 00 00`) at start-up → `IOCTL_PM_RTC_START` |

---

### IOCTL 0x800A0FA0 — IOCTL_PM_RTC_START

This IOCTL is sent by Qcpmicapps8930.sys to qcpmic8930.sys, only at start-up when `IOCTL_PM_RTC_GET_TIME` returned PMIC error 30  

| Property | Value |
|----------|-------|
| Device | 0x800A |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_RTC_START | `{61630799-…}` interface | 8 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | 00 00 00 00 00 00 00 00 | Start time 0 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | PMIC error |

---

### internal IOCTL 0x520004 — IOCTL_SYSENV_GET_VARIABLE

This IOCTL is sent by Qcpmicapps8930.sys to [qcscm8930.sys](./qcscm8930.md) (`{A942B3D9-EC95-4754-AE45-49C48735B893}` interface) to read a UEFI variable  

| Property | Value |
|----------|-------|
| Device | 0x52 |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SYSENV_GET_VARIABLE | `{A942B3D9-…}` interface | 36 | 20 |

Inputbuffer (`sub_401854`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 2B 8C 2F 88 46 96 5F 43 8D E5 F2 08 FF 80 C1 BD | Vendor GUID `{882F8C2B-9646-435F-8DE5-F208FF80C1BD}` |
| 10-13 | 10 00 00 00 | Size of the name in bytes (16) |
| 14-23 | `R\0T\0C\0I\0n\0f\0o\0\0\0` | Name `RTCInfo`, UTF-16 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Attributes of the variable |
| 04-07 | 08 00 00 00 | Data size, used as the copy length |
| 08-13 | | Data (`RTCInfo`, 8 bytes) |

---

### internal IOCTL 0x520008 — IOCTL_SYSENV_SET_VARIABLE

This IOCTL is sent by Qcpmicapps8930.sys to [qcscm8930.sys](./qcscm8930.md) (`{A942B3D9-EC95-4754-AE45-49C48735B893}` interface) to write a UEFI variable  

| Property | Value |
|----------|-------|
| Device | 0x52 |
| Function | 0x2 (2) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SYSENV_SET_VARIABLE | `{A942B3D9-…}` interface | 56 | 0 |

Inputbuffer (`sub_401720`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | |
| 04-07 | 30 00 00 00 | Offset of the data (48) |
| 08-0B | 08 00 00 00 | Data size |
| 0C-0F | 01 00 00 00 | Attributes: NON_VOLATILE. qcscm8930.sys always adds BOOTSERVICE_ACCESS \| RUNTIME_ACCESS |
| 10-1F | 2B 8C 2F 88 46 96 5F 43 8D E5 F2 08 FF 80 C1 BD | Vendor GUID `{882F8C2B-9646-435F-8DE5-F208FF80C1BD}` |
| 20-2F | `R\0T\0C\0I\0n\0f\0o\0\0\0` | Name `RTCInfo`, UTF-16 |
| 30-37 | | Data, see the content of `RTCInfo` above |

---

### IOCTL 0x480004 — IOCTL_GPIO_WRITE_PINS

This IOCTL is sent by Qcpmicapps8930.sys to the GPIO controller, on each D0 entry, for each GPIO connection resource (max 2)  

| Property | Value |
|----------|-------|
| Device | 0x48 |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_GPIO_WRITE_PINS | `\Device\RESOURCE_HUB\<connection id>` | 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 | Pin value 0 (low) |

---

### Interface GUID

qcpmicapps8930 device interface  
`{CA95CEB1-A382-4F06-B65E-0A90115609A5}`

PMIC RTC companion interface (one of the device interfaces of [qcpmic8930.sys](./qcpmic8930.md))  
`{61630799-922A-4980-99D9-90C39084A979}`

Interface of [qcabd8930.sys](./qcabd8930.md), receiver of the attach / detach  
`{2B0FDE10-DED1-40C1-AF2E-031836A066A8}`

UEFI variable service interface `GUID_SYSENV_INTERFACE` of [qcscm8930.sys](./qcscm8930.md) (also awaited by [qcbms8930.sys](./qcbms8930.md) and [wpcrdmp.sys](./wpcrdmp.md))  
`{A942B3D9-EC95-4754-AE45-49C48735B893}`

### Other GUID

UEFI vendor GUID of the `RTCInfo` variable  
`{882F8C2B-9646-435F-8DE5-F208FF80C1BD}`

PnP notification event GUIDs  
`{CB3A4004-46F0-11D0-B08F-00609713053F}` (GUID_DEVICE_INTERFACE_ARRIVAL)  
`{CB3A4005-46F0-11D0-B08F-00609713053F}` (GUID_DEVICE_INTERFACE_REMOVAL)
