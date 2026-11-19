## Hwnled.sys

Hardware-notification LED driver (key LEDs / notification LEDs driven by the PMIC).  
Like [hwnvibradime.sys](./hwnvibradime.md) and [hwnhaptics.sys](./hwnhaptics.md), it is a client of the Microsoft Hardware Notification class extension `HwNClx` ([mshwnclx.sys](./mshwnclx.md)): it has no IOCTL of its own. Requests come in as `HWN_HEADER` / `HWN_SETTINGS` buffers through the `ClientSetState` / `ClientGetState` callbacks, and the driver turns them into PMIC requests to [qcpmic8930.sys](./qcpmic8930.md): RGB LED enable (`0x8013`), PWM / LPG and LUT (`0x800E`), and WLED (`0x8014`) for an optional backlight-type output.  
The board configuration (PMIC index, number of LEDs, RGB LED / LPG channel of each LED) comes from the ACPI method `HWNL` of `\_SB.HWN0` (`_HID` `QCOM0D50`). On the Lumia 520 it declares 3 LEDs. The only known sender of requests is [oempanel.sys](./oempanel.md#ioctl-0x228000--hwn-set-state-) (capacitive key LEDs), and on a Lumia 520 it sends nothing (`LIGHT_LedGroupN_Pct` = 0).  
KMDF, PDB path `E:\build_e\subtask\3701FCA2_98\output\hwnled\fre\hwnled.pdb`. Pool tag `LNWH`.

> [!NOTE]
> The 3 capacitive keys of the Lumia 520 are never lit (observed on a real device). This matches the software: oempanel.sys sends no request because all its `LIGHT_LedGroupN_Pct` values are 0 (and `HKLM\SYSTEM\TOUCH\BUTTONS\BACKLIGHT` `LedCount` = 0), so hwnled.sys loads, reads `HWNL` and then stays idle. The `\_SB.HWN0` node and its 3-LED `HWNL` configuration are probably inherited from a board shared with other MSM8930 Lumia models that do have lit keys. Whether the LEDs physically exist on the 520 hasn't been tested.

There's no device name and no symbolic link created by the driver itself (the device object and interface are managed by `HwNClx`).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\hwnled`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0D50\0`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\ACPI\QCOM0D50\0\Device Parameters\Hardware Config` (hardware key of the device, `WdfDeviceOpenRegistryKey(PLUGPLAY_REGKEY_DEVICE)` + `WdfRegistryOpenKey`, `sub_408298`), read once in ClientInitializeDevice:  
| Registry value | value | comment |
|----------------|-------|---------|
| UseHardware | 1 | **String** (`WdfRegistryQueryUnicodeString`, at most 8 characters), converted in base 10 with `RtlUnicodeStringToInteger` into `ctx+0x20`. Default 1 when the key or value is missing. When 0, every Set state / Get state returns `STATUS_UNSUCCESSFUL` (0xC0000001) |

GUID of the ETW provider (WPP control GUID):  
`{1B23D121-227A-4CA9-A143-BAF9205EF142}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI PDO (`WdfDeviceGetIoTarget`) | [acpi.sys](./acpi.md) | Evaluates the method `HWNL`, see [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method) |
| Interface `{F9938F2D-3756-4760-A044-CB29AFBA5A69}` | [qcpmic8930.sys](./qcpmic8930.md) | Target of the RGB LED (`0x8013`) and PWM / LPG (`0x800E`) IOCTLs. Driver context `+0x00` |
| Interface `{2F706348-47C5-4873-A66C-6B6BC6B01698}` | [qcpmic8930.sys](./qcpmic8930.md) | Opened (driver context `+0x04`) but **never used** |
| Interface `{5B9DF049-70D3-4698-8E48-85B26C1AA59F}` | [qcpmic8930.sys](./qcpmic8930.md) | Target of the WLED (`0x8014`) IOCTLs. Driver context `+0x08` (the same interface as [oempanel.sys](./oempanel.md)) |

The 3 PMIC interfaces are opened by `sub_401B60` with `IoGetDeviceInterfaces` (`DEVICE_INTERFACE_INCLUDE_NONACTIVE`) + `IoGetDeviceObjectPointer` (`GENERIC_ALL`), first symbolic link only, at the end of `DriverEntry`. Set state opens again the first and the third one when their pointer is still NULL.  
All IOCTLs to qcpmic8930 are sent by `sub_401AAC`: `IoBuildDeviceIoControlRequest` (external IOCTL), 4-byte output buffer (PMIC error), waits without timeout. The result of most of them is ignored.

> [!NOTE]
> `sub_40114C` registers a PnP notification (`PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`, callback `sub_4011F4`) for each of the 3 interfaces, but on `GUID_DEVICE_INTERFACE_ARRIVAL` the callback calls `sub_401B60` with a **local variable** as destination, so the device pointer is thrown away (same bug as hwnhaptics.sys). The file objects returned by `IoGetDeviceObjectPointer` are never dereferenced. The notifications are registered once per driver but unregistered by ClientUnInitializeDevice.

### HwNClx client

`DriverEntry` (0x409000) initializes WPP, creates the WDF driver (context `HWNLED_DRIVER_CONTEXT`), calls `HwNRegisterClientDriver` (class `HwNClx` version 1, bound through `WdfVersionBindClass`, imported functions at `.data:0x00406D50`), registers the PnP notifications and opens the 3 PMIC interfaces. Registration packet (`HWN_CLIENT_REGISTRATION_PACKET`, Version 1, Size 40, client context size 40 bytes):  
| Callback | Function | Comment |
|----------|----------|---------|
| ClientInitializeDevice | `sub_408338` | See [Initialization](#initialization) |
| ClientUnInitializeDevice | `sub_408464` | If a setting for HwN Id 3 was stored, switches the WLED off (`sub_401490` with intensity 0, mode 0). Frees the settings list, unregisters the 3 PnP notifications. The RGB LEDs are not switched off |
| ClientQueryDeviceInformation | `sub_408530` | Returns 3 USHORTs `1, 6, n` (version, size, number of HwN = `HWNL` element 1) |
| ClientStartDevice | `sub_408560` | Does nothing |
| ClientStopDevice | `sub_408560` | Does nothing |
| ClientSetState | `sub_4086D0` | See [Set state](#set-state) |
| ClientGetState | `sub_408564` | See [Get state](#get-state) |

`EvtDriverDeviceAdd` (0x4010C0) calls `sub_408000`, which only calls `HwNProcessAddDevicePreDeviceCreate`, `WdfDeviceCreate` (context type `HWNLED_DEVICE_CONTEXT`) and `HwNProcessAddDevicePostDeviceCreate` with the GUID `{6B2A25E2-AAF5-482C-99A5-6205CDCC176A}` (device interface created by [mshwnclx.sys](./mshwnclx.md), opened by [oempanel.sys](./oempanel.md)).  
`EvtDriverUnload` calls `HwNUnregisterClientDriver`.

Driver context (`HWNLED_DRIVER_CONTEXT`): `+0x00`, `+0x04`, `+0x08` = DEVICE_OBJECT of the 3 PMIC interfaces (see the table above).

Device context (client context, 40 bytes):  
| Offset | Size | Comment |
|--------|------|---------|
| +0x00 | 4 | Driver context |
| +0x04 | 4 | Head of the list of the last settings per HwN Id (40-byte nodes, `PagedPool`) |
| +0x08 | 4 | WDFDEVICE |
| +0x0C | 2 | `HWNL` element 0: PMIC index |
| +0x0E | 2 | `HWNL` element 1: number of HwN (LEDs) |
| +0x10 | 4 × 4 | Per HwN Id n: `+0x10+4n` USHORT = RGB LED channel, `+0x12+4n` USHORT = LPG channel (or WLED string for Id 3). `HWNL` elements 4–11 |
| +0x20 | 4 | `UseHardware` (default 1) |
| +0x24 | 2 | `HWNL` element 2 (default 15): first value of `IOCTL_PM_CONFIGURE_LUT` |
| +0x26 | 2 | `HWNL` element 3 (default 20): LUT step divisor |

### Initialization

`sub_408338`:
1. Initializes the context with the defaults above.
2. `sub_401820`: initializes the 4 per-Id events (`.data:0x00406E20`) and builds the [PWM period table](#pwm-period-table).
3. `sub_40810C` evaluates `HWNL` ([IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method)). The device fails to initialize if the method is missing or invalid.
4. Reads `UseHardware`. A missing key or value is not an error.

`HWNL` of the Lumia 520 ([DSDT](../acpi/dsdt.dsl), `\_SB.HWN0`) returns `Package (10) { 0, 3, 0x0F, 0x14, 0, 3, 1, 4, 2, 5 }`:  
| Element | Value | Context | Comment |
|---------|-------|---------|---------|
| 0 | 0 | +0x0C | PMIC index |
| 1 | 3 | +0x0E | 3 LEDs (HwN Id 0–2) |
| 2 | 0x0F | +0x24 | LUT parameter (ramp step ?) |
| 3 | 0x14 | +0x26 | LUT step divisor: 20 / 20 = 1, so the LUT is used unchanged |
| 4, 5 | 0, 3 | +0x10, +0x12 | LED 0: RGB LED channel 0, LPG 3 |
| 6, 7 | 1, 4 | +0x14, +0x16 | LED 1: RGB LED channel 1, LPG 4 |
| 8, 9 | 2, 5 | +0x18, +0x1A | LED 2: RGB LED channel 2, LPG 5 |
| 10, 11 | — | +0x1C, +0x1E | LED 3 / WLED string, not defined on the Lumia 520 |

The RGB channels 0–2 and LPG channels 3–5 probably are the red / green / blue outputs of the PM8038 RGB LED block ? The DSDT doesn't say which key LED is wired where.

### Set state

Input buffer (`HWN_HEADER` with n `HWN_SETTINGS`, same layout as [hwnvibradime.sys](./hwnvibradime.md#set-state)):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Payload size. Ignored |
| 04-07 | | Version. Ignored |
| 08-0B | | Number of settings. Ignored: the number comes from the buffer length |
| 0C-0F | 00 00 00 00 | HwN Id. Must be < `HWNL` element 1, otherwise `STATUS_INVALID_PARAMETER` (0xC000000D). Id 3 selects the WLED path |
| 10-13 | e.g. `01 00 00 00` | HwN type. Not checked (1 = LED) |
| 14-17 | e.g. `64 00 00 00` | Intensity in %. Used only by the LUT modes (start/end index) and the WLED (12-bit level) |
| 18-1B | | Period in ms. Selects the PWM period (modes 0–2); total blink duration = period × cycle count (mode 2) |
| 1C-1F | e.g. `64 00 00 00` | Duty cycle in %. Becomes the PWM value (modes 0–2). Not checked against 100 |
| 20-23 | | Cycle count (mode 2) |
| 24-27 | 00 00 00 00 | Forced to 0 by the driver before being stored |
| 28-2B | FF FF FF FF | Forced to -1 by the driver before being stored |
| 2C-2F | 00…04 00 00 00 | Mode: 0 = off, 1 = on, 2 = blink, 3 = LUT ramp from the previous intensity to the new one, ≥ 4 = LUT ramp in the other direction ? |

Fields 0C-2F are repeated for each setting (36 bytes). The length must be larger than 12 and `(length − 12)` a multiple of 36, otherwise `STATUS_INVALID_BUFFER_SIZE` (0xC0000206).  
For each setting, `sub_401994` drives the hardware, then `sub_4018A8` stores the setting in the list (replacing the one with the same Id).  
[oempanel.sys](./oempanel.md#ioctl-0x228000--hwn-set-state-) sends one setting per non-zero `LIGHT_LedGroupN_Pct` (Id = group 0–3, type 1, period 0): mode 1 with intensity = `LIGHT_LedGroupN_Pct` and duty cycle = key-light level when the lights are on, mode 0 with everything 0 when they are off. With period 0 hwnled picks the shortest PWM period, and since the duty cycle is the PWM value, the key-light level sets the brightness while the `LIGHT_LedGroupN_Pct` intensity is ignored (it only matters in the LUT modes). A group 3 would be refused on a Lumia 520 (only 3 HwN).

`sub_401994`:
1. Id ≥ number of HwN → `STATUS_INVALID_PARAMETER`.
2. Opens again the interfaces `{F9938F2D-…}` / `{5B9DF049-…}` if their pointer is NULL.
3. Signals the event of the Id (ends a running blink, see mode 2), creates the timer of the Id on first use (`sub_401F30`: `WdfTimerCreate`, one-shot, passive level, parent = WDFDEVICE, callback `sub_401FA8` which signals the event), stops it, and stores the context pointer in the per-Id request block (`.data:0x00406D60`, 40 bytes per Id: context + copy of the setting).
4. Id 3 → [WLED](#wled-hwn-id-3), whatever the mode.
5. Mode 0 or 1 (`sub_40129C`): [IOCTL_PM_RGB_LED_ENABLE](#ioctl-0x80130fa0--ioctl_pm_rgb_led_enable) with enable = mode, then `sub_401308`: [IOCTL_PM_PWM_SELECT_LPG_PARAMETERS](#ioctl-0x800e0fa0--ioctl_pm_pwm_select_lpg_parameters) with the period and duty cycle of the setting and the enable bytes = mode. There's no timeout: the LED stays on until the next request.
6. Mode 2 (`sub_401BE0`): busy-waits until the previous blink thread of the Id has ended, starts the system thread `sub_402014` and the timer with a due time of period × cycle count ms. The thread switches the LED on (RGB enable 1 + PWM with the requested period / duty cycle: the blinking itself is done by the PMIC PWM), waits for the event (timer expiry or new request), then switches it off (RGB enable 0 + PWM with enable 0). A cycle count of 0 gives a due time of 0 (the LED probably goes off at once ?). The thread handle is never closed.
7. Mode ≥ 3 (`sub_401688`): [LUT mode](#lut-modes-mode--3).

#### PWM period table

`sub_401DEC` / `sub_401CC8` build at initialization a table of 192 entries of 24 bytes (`.data:0x00405B50`, sorted by period): every combination of  
| Parameter | Values | IOCTL value |
|-----------|--------|-------------|
| Clock | 32.768 kHz, 19.2 MHz | 2, 3 (1 = 1 kHz, not in the table) |
| PWM size | 6, 7, 9 bits | 0, 2, 1 |
| Pre-divider | 1, 3, 5, 6 | 0, 1, 2, 3 |
| Exponent | 0–7 | 0–7 |

with period (ms) = 2^bits × pre-divider × 2^exponent / clock (kHz), from 0.0033 ms to 12 s. `sub_401308` takes the first entry whose period is ≥ the requested period (`STATUS_UNSUCCESSFUL` when > 12 s), and the PWM value = (2^bits − 1) × duty cycle / 100 (`sub_401D80`).

#### LUT modes (mode ≥ 3)

`sub_401688`:
1. [IOCTL_PM_RGB_LED_ENABLE](#ioctl-0x80130fa0--ioctl_pm_rgb_led_enable) with enable 1.
2. `sub_4015A0` computes two LUT indexes: 1 + intensity × 0.2 for the previous setting of the Id (intensity 0 if there is none) and for the new one (1 to 21). If `HWNL` element 3 is ≥ 2 and divides 20 into q > 1, the entries of the global LUT whose index is not a multiple of q are replaced by the previous entry (in place, so the change accumulates).
3. [IOCTL_PM_PWM_SELECT_LPG_PARAMETERS](#ioctl-0x800e0fa0--ioctl_pm_pwm_select_lpg_parameters) twice with a fixed configuration (19.2 MHz, 9 bits, pre-divider 1, exponent 0, value 0).
4. [IOCTL_PM_CONFIGURE_LUT](#ioctl-0x800e0fa8--ioctl_pm_configure_lut) with the 21-entry LUT.
5. [IOCTL_PM_START_LUT](#ioctl-0x800e0fac--ioctl_pm_start_lut) with the two indexes (previous → new for mode 3, new → previous otherwise).

LUT (`.data:0x00405158`, 21 DWORDs, 9-bit PWM values): `0, 0, 50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 511`.

#### WLED (HwN Id 3)

`sub_401490` sends, to the interface `{5B9DF049-…}`, with level = intensity × 4095 / 100 and string = `ctx+0x1E` (`HWNL` element 11):  
1. The first time (global flag `byte_405B4C`): [IOCTL_PM_WLED_CONFIG](#ioctl-0x80140fa0--ioctl_pm_wled_config) (25 mA, level); the following times: [IOCTL_PM_WLED_DIMMING_CONFIG](#ioctl-0x80140fa8--ioctl_pm_wled_dimming_config) (level).
2. [IOCTL_PM_WLED_ENABLE](#ioctl-0x80140fa4--ioctl_pm_wled_enable) with enable = mode (low byte).

On the Lumia 520 `HWNL` declares only 3 HwN, so Id 3 is refused (by [mshwnclx.sys](./mshwnclx.md) and by `sub_401994`) and this path is never used.

### Get state

The output buffer must be larger than 12 bytes and `(length − 12)` a multiple of 36, otherwise `STATUS_INVALID_BUFFER_SIZE` (0xC0000206). `UseHardware` = 0 → `STATUS_UNSUCCESSFUL`.

Without input buffer, it returns the default state: header `36 × n + 12`, version 1, count n (`HWNL` element 1), then one setting per 36 bytes of the output buffer with the Id = index, type 1, all fields 0 except bytes 28-2B = FF FF FF FF (`sub_401834`). The stored settings are not returned.

With an input buffer (same length rule), each setting of the input buffer is looked up by HwN Id in the list (`sub_401864`) and overwritten with the stored values: the result is in the **input** buffer. An Id that has never been set returns `STATUS_UNSUCCESSFUL` (0xC0000001).

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Hwnled.sys to [acpi.sys](./acpi.md#ioctl-0x32c004--ioctl_acpi_eval_method)

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI PDO of the device | 8 | 256 |

Sent by `sub_40810C` with `WdfIoTargetSendIoctlSynchronously` (output buffer in `NonPagedPoolNx`).  

Inputbuffer (`ACPI_EVAL_INPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `AeiB` |
| 04-07 | 48 57 4E 4C | Method name `HWNL` |

Outputbuffer (`ACPI_EVAL_OUTPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature `AeoB` |
| 04-07 | | Length |
| 08-0B | 0A 00 00 00 | Number of elements, at most 12 |
| 0C- | | Elements: USHORT type, USHORT data length, data. Each one takes `4 + max(length, 4)` bytes |

Only the first element is checked: it must be an integer (type 0) of at most 256 bytes. A bad signature, count, type or length returns `STATUS_ACPI_INVALID_DATA` (0xC014000F). The low 16 bits of each element are stored in the device context, see [Initialization](#initialization).

---

### IOCTL 0x80130FA0 — IOCTL_PM_RGB_LED_ENABLE

This IOCTL is sent by Hwnled.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8013xxxx--rgb-led)

| Property | Value |
|----------|-------|
| Device | 0x8013 |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_RGB_LED_ENABLE | Interface `{F9938F2D-3756-4760-A044-CB29AFBA5A69}` | 12 | 4 |

Sent by `sub_40129C` (modes 0/1), `sub_402014` (blink thread) and `sub_401688` (LUT modes).  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index (`HWNL` element 0) |
| 04 | 00 | Always 0 |
| 05 | 00 / 01 | Enable |
| 06-07 | | Not initialized |
| 08-0B | e.g. `00 00 00 00` | RGB LED channel of the HwN Id (`ctx+0x10+4n`) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code |

When it fails, `sub_40129C` doesn't send the PWM request.

---

### IOCTL 0x800E0FA0 — IOCTL_PM_PWM_SELECT_LPG_PARAMETERS

This IOCTL is sent by Hwnled.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x800exxxx--pwm--lpg)

| Property | Value |
|----------|-------|
| Device | 0x800E |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_PWM_SELECT_LPG_PARAMETERS | Interface `{F9938F2D-3756-4760-A044-CB29AFBA5A69}` | 40 | 4 |

Always sent **twice** in a row with the same buffer, by `sub_401308` (modes 0–2) and `sub_401688` (LUT modes).  

Inputbuffer:  
| Bytes | Modes 0–2 | LUT modes | Comment |
|-------|-----------|-----------|---------|
| 00-03 | PMIC index | PMIC index | |
| 04-07 | LPG channel | LPG channel | `ctx+0x12+4n` (3–5 on the Lumia 520) |
| 08-0B | 2 / 3 | 3 | Clock: 1 = 1 kHz, 2 = 32 kHz, 3 = 19.2 MHz |
| 0C-0F | 0 / 1 / 2 | 1 | PWM size: 0 = 6 bits, 2 = 7 bits, 1 = 9 bits |
| 10-13 | 0–3 | 0 | Pre-divider 1 / 3 / 5 / 6 |
| 14-17 | 0–7 | 0 | Pre-divider exponent |
| 18-1B | PWM value | 0 | (2^bits − 1) × duty cycle / 100 |
| 1C | enable | 1 | Enable flag ? |
| 1D | enable | 0 | Enable flag ? |
| 1E | enable | 1 | Enable flag ? |
| 1F | enable | 1 | Enable flag ? |
| 20 | enable | 0 | Enable flag ? |
| 21-23 | 0 | 0 | |
| 24-27 | 0 | 0 | |

"enable" = 0 for mode 0 and the end of a blink, 1 otherwise. From the trace strings of qcpmic8930 the bytes `1C`–`20` are probably among glitch removal, full scale, stagger, phase delay, bypass, LPG enable, PWM enable and PWM output enable, but the exact mapping isn't decoded.

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code |

---

### IOCTL 0x800E0FA8 — IOCTL_PM_CONFIGURE_LUT

This IOCTL is sent by Hwnled.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x800exxxx--pwm--lpg)

| Property | Value |
|----------|-------|
| Device | 0x800E |
| Function | 0x3EA (1002) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_CONFIGURE_LUT | Interface `{F9938F2D-3756-4760-A044-CB29AFBA5A69}` | 40 | 4 |

Sent by `sub_401688` (modes ≥ 3).  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | 0F 00 00 00 | `HWNL` element 2 (`ctx+0x24`). Ramp step / interval ? |
| 08 | 01 | ? |
| 09 | 00 | ? |
| 0A | 01 / 00 | 1 for mode 3, 0 for mode ≥ 4 (ramp direction / toggle ?) |
| 0B-1B | 0 | |
| 1C-1F | 01 00 00 00 | ? |
| 20-23 | 15 00 00 00 | Number of LUT entries (21) |
| 24-27 | e.g. `58 51 xx xx` | **Kernel address** of the LUT in hwnled (`.data:0x00405158`) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code |

The buffer carries no LPG channel: it is selected by the preceding `IOCTL_PM_PWM_SELECT_LPG_PARAMETERS` ?

---

### IOCTL 0x800E0FAC — IOCTL_PM_START_LUT

This IOCTL is sent by Hwnled.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x800exxxx--pwm--lpg)

| Property | Value |
|----------|-------|
| Device | 0x800E |
| Function | 0x3EB (1003) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_START_LUT | Interface `{F9938F2D-3756-4760-A044-CB29AFBA5A69}` | 16 | 4 |

Sent by `sub_401688` (modes ≥ 3), after `IOCTL_PM_CONFIGURE_LUT`.  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | 1–21 | Start LUT index: previous intensity (mode 3) or new intensity (mode ≥ 4), as 1 + intensity × 0.2 |
| 08-0B | 1–21 | End LUT index: the other one |
| 0C | 00 | ? |
| 0D-0F | 00 00 00 | |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code |

---

### IOCTL 0x80140FA0 — IOCTL_PM_WLED_CONFIG

This IOCTL is sent by Hwnled.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8014xxxx--wled-display-backlight)

| Property | Value |
|----------|-------|
| Device | 0x8014 |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_WLED_CONFIG | Interface `{5B9DF049-70D3-4698-8E48-85B26C1AA59F}` | 56 | 4 |

Sent by `sub_401490` for the first request on HwN Id 3 (never on a Lumia 520). The flag `byte_405B4C` is set only when it succeeds.  

Inputbuffer (field meanings from [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8014xxxx--wled-display-backlight)):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC index |
| 04-07 | | String number (`ctx+0x1E`, `HWNL` element 11) |
| 08 | 01 | Modulator control flag ? |
| 09 | 01 | Modulator control flag ? |
| 0C-0F | 19 00 00 00 | Full-scale current 25 mA |
| 10-13 | 0–0xFFF | Brightness = intensity × 4095 / 100 |
| 14 | 00 | |
| 15 | 00 | Sync configuration |
| 16 | 01 | Not used by qcpmic8930 |
| 17 | 00 | |
| 18-1B | 02 00 00 00 | `0x265` bits 4:3 |
| 1C-1F | 03 00 00 00 | `0x265` bits 2:1 |
| 20 | 00 | |
| 24-27 | 00 00 00 00 | OVP threshold ? |
| 28-2B | 02 00 00 00 | Boost current limit ? |
| 2C-2F | 00 00 00 00 | Feedback selection ? |
| 30-33 | 03 00 00 00 | Resistor compensation ? |
| 34-37 | 02 00 00 00 | High-pole capacitor ? |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code |

---

### IOCTL 0x80140FA8 — IOCTL_PM_WLED_DIMMING_CONFIG

This IOCTL is sent by Hwnled.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8014xxxx--wled-display-backlight)

| Property | Value |
|----------|-------|
| Device | 0x8014 |
| Function | 0x3EA (1002) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_WLED_DIMMING_CONFIG | Interface `{5B9DF049-70D3-4698-8E48-85B26C1AA59F}` | 12 | 4 |

Sent by `sub_401490` for the following requests on HwN Id 3.  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC index |
| 04-07 | | String number (`ctx+0x1E`) |
| 08-0B | 0–0xFFF | Brightness = intensity × 4095 / 100 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code |

---

### IOCTL 0x80140FA4 — IOCTL_PM_WLED_ENABLE

This IOCTL is sent by Hwnled.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8014xxxx--wled-display-backlight)

| Property | Value |
|----------|-------|
| Device | 0x8014 |
| Function | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_WLED_ENABLE | Interface `{5B9DF049-70D3-4698-8E48-85B26C1AA59F}` | 8 | 4 |

Sent by `sub_401490` after the configuration / dimming request, if it succeeded.  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC index |
| 04 | 00 / 01 | Enable = low byte of the mode of the setting (so mode 2 = 2) |
| 05-07 | | Not initialized |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code |

---

### Other GUID

HwNClx device interface of the LEDs (passed to `HwNProcessAddDevicePostDeviceCreate`, created by [mshwnclx.sys](./mshwnclx.md), opened by [oempanel.sys](./oempanel.md))  
`{6B2A25E2-AAF5-482C-99A5-6205CDCC176A}`

qcpmic8930 interface (RGB LED and PWM / LPG IOCTLs)  
`{F9938F2D-3756-4760-A044-CB29AFBA5A69}`

qcpmic8930 interface (opened, not used)  
`{2F706348-47C5-4873-A66C-6B6BC6B01698}`

qcpmic8930 interface (WLED IOCTLs)  
`{5B9DF049-70D3-4698-8E48-85B26C1AA59F}`
