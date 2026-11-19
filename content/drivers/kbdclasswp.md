## Kbdclasswp.sys

Windows Phone keyboard class driver (Microsoft).  
It replaces `kbdclass.sys` on the phone: it is a KMDF **upper filter** on HID keyboard collections (`WdfFdoInitSetFilter`, not power policy owner). For each filtered collection it reads the HID input reports, converts the Keyboard-page usages to scan codes and delivers them as 12-byte `KEYBOARD_INPUT_DATA` records to the readers of two control devices: `\Device\WPKeyboardClass` (the shell, see [UIXRender.dll](../libraries/uixrender.md)) and `\Device\KeyboardRaw0`.  
It is the consumer of the hardware buttons of [msgpiowinphone.sys](./msgpiowinphone.md) (HID collection Usage Page Generic Desktop, Usage 0xEE, which is the only top-level collection it accepts). While the display is off (`GUID_MONITOR_POWER_ON`) it drops the key presses of the buttons that must not wake the phone. It also drives the LEDs and the backlight level of a real keyboard through HID output reports, and exposes them with [8 IOCTLs](#ioctl-0xb0400--get-device-count).  
Build path `src\uxplat\input\dev\drivers\keyboard\kbdclasswp\driver.c`, PDB `kbdclasswp.pdb`. It imports `ntoskrnl.exe`, `HIDPARSE.SYS` and `WDFLDR.SYS`.

Device name : `\Device\WPKeyboardClass` (control device, `FILE_DEVICE_KEYBOARD`, no symbolic link)  
Security descriptor : `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GRGWGX;;;AU)(A;;GRGWGX;;;AC)`, and [opening it requires `ID_CAP_KEYBOARD`](#access-check)  

Device name : `\Device\KeyboardRaw0` (control device)  
Symbolic link : `\DosDevices\KeyboardRaw0`  
Security descriptor : `D:P(A;;GA;;;SY)(A;;GRGX;;;BA)` (SYSTEM, and read-only for Administrators)  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\KEYBOARD` (opened with `WdfRegistryOpenKey`, KEY_READ):  
| Registry value | value | comment |
|----------------|-------|---------|
| EnableStartOnIdle | ? | REG_DWORD, read once in `DriverEntry` (sub_10003244), default 0. Non-zero → driver context `+0xB` = 1: the key press of F2 (0x3B, Start ?) is still delivered while the display is off (see [Key filtering](#key-filtering-while-the-display-is-off)) |
| Flags | ? | REG_DWORD, default 0 (sub_100027DC). Read in `EvtDevicePrepareHardware` for a full keyboard only (device type 0) into the device context `+0x134`. Bit 0x10: the backlight is always enabled (the key 0xF6 doesn't toggle it). Bit 0x400 is forced to 1 by the driver |

GUID of the ETW provider (manifest-based, `EtwRegister` in `McGenEventRegister`):  
`{d7d16fce-43b4-4e1b-b2e2-251204a14e4e}`  

GUID of the WPP control provider:  
`{7c5747ae-8c08-49cf-9b12-c81877eea0a6}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| HID collection below the filter (`GUID_DEVINTERFACE_HID` `{4D1E55B2-F16F-11CF-88CB-001111000030}` of its own PDO) | HID class (`hidclass.sys`), e.g. over [msgpiowinphone.sys](./msgpiowinphone.md) | `IOCTL_HID_GET_COLLECTION_INFORMATION` / `IOCTL_HID_GET_COLLECTION_DESCRIPTOR`, `IRP_MJ_READ` of the input reports, `IRP_MJ_WRITE` of the output reports (LEDs, backlight) |

Pool tag (`ExAllocatePoolWithTag` and `DriverPoolTag`): `cKbd` (0x64624B63, `NonPagedPoolNx`). The same value is the signature at offset 0 of the device context.

### Initialisation

`DriverEntry` (0x10007000):
1. WPP and ETW registration, `WdfDriverCreate` (context `KEYBOARDWP_DRIVER_CONTEXT`, `EvtDriverDeviceAdd` = 0x10003430).
2. Creates the control device `\Device\WPKeyboardClass` (`WdfControlDeviceInitAllocate`, file callbacks `EvtWdfDeviceFileCreate` 0x10003374 / `EvtWdfFileClose` 0x100033E8), reads `EnableStartOnIdle`, creates its default parallel queue (not power-managed, `EvtIoRead` 0x10003744, `EvtIoDeviceControl` 0x10005424).
3. Creates a work item that calls `PoLatencySensitivityHint(1)` (sub_10006220).
4. `PoRegisterPowerSettingCallback(GUID_MONITOR_POWER_ON {02731015-4510-4526-99e6-e5a17ebd1aea})`, callback sub_100045A0.
5. Creates the device collection, the event queue of `WPKeyboardClass` (manual queue + list, sub_10002414) and the control device `\Device\KeyboardRaw0` (sub_10005D78): parallel default queue with `EvtIoRead` sub_10005FC0 and `EvtIoDeviceControl` sub_100060F8, file callbacks sub_10006024 (open count) / sub_10006074 (on the last close, drops the pending events).

`EvtDriverDeviceAdd` (0x10003430): at most **5** devices (otherwise 0xC000020E). Filter device with `EvtDevicePrepareHardware` / `ReleaseHardware` / `D0Entry` / `D0Exit`. The device index (0…4, device context `+0xF9`) is the `UnitId` of the records and of the IOCTLs. Registers for the arrival of `GUID_DEVINTERFACE_HID` on its own PDO (`IoRegisterPlugPlayNotification`, callback sub_100038F4: `IoGetDeviceInterfaces`, `WdfIoTargetOpen`, then starts the continuous read), creates and enables the device interface `GUID_DEVINTERFACE_KEYBOARD` `{884B96C3-56EF-11D1-BC8C-00A0C91405DD}` (the interface [UIXRender.dll](../libraries/uixrender.md) waits for before opening `\Device\WPKeyboardClass`).

`EvtWdfDevicePrepareHardware` (0x10002B70):
1. [IOCTL 0xB01A8](#ioctl-0xb01a8--ioctl_hid_get_collection_information) and [IOCTL 0xB0193](#ioctl-0xb0193--ioctl_hid_get_collection_descriptor) to the local I/O target, then `HidP_GetCaps`.
2. The top-level collection must be Usage Page 0x01 (Generic Desktop), **Usage 0xEE**, otherwise `STATUS_UNSUCCESSFUL`. A standard keyboard collection (Usage 0x06) is refused.
3. The device type (device context `+0x138`) is chosen from the input button caps of the Keyboard usage page (0x07):

| Type | Test | Device |
|------|------|--------|
| 0 | usages 0xF0, 0xF1, 0xF4 and 0xF3 all present (sub_10003E70) | Full keyboard. Only one is allowed (driver context `+0xA`, otherwise 0xC000020E). `Flags` is read, and the LEDs / backlight are parsed (sub_10003AA8) |
| 1 | default | Other |
| 2 | 0x68 (F13), 0x43 (F10), 0x42 (F9), 0x3F (F6), 0x40 (F7) all present and ≥ 5 input button caps | Hardware buttons ([msgpiowinphone.sys](./msgpiowinphone.md): power, volume, camera) |
| 3 | at least two of 0x3B (F2), 0x3C (F3), 0x29 (Escape) and ≤ 3 input button caps | Start / Search / Back keys ? |

   Type 3 is tested before type 2 (sub_10003F8C).
4. For a full keyboard (sub_10003AA8): output button caps of the LED page (0x08) with usage 0x50 → LED 1 (tied to the key 0xF0, scan code 0xE06E), usage 0x51 → LED 2 (key 0xF1, scan code 0xE06F); an 8-bit output value cap of Usage Page 0x14, Usage 0xA0 (backlight level ?) is required, and at least 8 input button caps.
5. Creates the read request and buffer (input report length), the write request and buffer (output report length) and the usage lists.

`EvtWdfDeviceD0Entry`: the first time (sub_1000294C), backlight enabled = 1 if `Flags` bit 0x10, toggles 0xF7 / F23 cleared, backlight level 0 and both LEDs off.  
`EvtWdfDeviceReleaseHardware`: queues a release for every key still down, cancels the pending read (waits 5 s steps), frees the buffers and unregisters the PnP notification.

### Access check

`EvtWdfDeviceFileCreate` of `\Device\WPKeyboardClass` (sub_10008328) checks the capability `ID_CAP_KEYBOARD`, otherwise `STATUS_ACCESS_DENIED` (0xC0000022). Same algorithm as in [msgpiowinphone.sys](./msgpiowinphone.md) and [SecRuntime.dll](../libraries/secruntime.md):
* AppContainer token (`TokenIsAppContainer`): `RtlCheckTokenCapability` with the `ApplicationCapabilitySID` of `HKLM\Software\Microsoft\SecurityManager\Capabilities\ID_CAP_KEYBOARD`;
* otherwise: LocalSystem is allowed. Else `RtlCheckTokenMembership` with the `ServiceCapabilitySID` of the same key. Else membership of `S-1-5-21-2702878673-795188819-444038987-1030` (the `ID_CAP_BUILTIN_TCB` list compared afterwards never matches `ID_CAP_KEYBOARD`).

`\Device\KeyboardRaw0` has no capability check (only its security descriptor).

### Key events

For each completed read of an input report (sub_10005A1C): `HidP_GetUsages` (Keyboard page, max 20 usages), `HidP_UsageListDifference` with the previous list → break list and make list (sub_100057DC). The break events are generated first. Each usage is converted by the table at `.data:0x10009070` (183 entries `{u16 HID usage, u32 scan code}`, sub_10006184; a usage without a scan code → 0xC0000002) into a record (sub_1000559C):

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 00 00 | UnitId: device index |
| 02-03 | 64 00 | MakeCode: scan code set 1 (low byte only when there is a prefix), e.g. 0x64 for F13 |
| 04-05 | 00 00 | Flags: bit 0 `KEY_BREAK` (released), bit 1 `KEY_E0` (scan code 0xE0xx), bit 2 `KEY_E1` (scan code 0xE1xxxx) |
| 06-07 | 00 00 | Reserved |
| 08-0B | ? | `KeQueryInterruptTime() / 10000`: time in ms |

Examples of the table: 0x29 → 0x01, 0x3B → 0x3C, 0x3C → 0x3D, 0x3F → 0x40, 0x40 → 0x41, 0x42 → 0x43, 0x43 → 0x44, 0x68 → 0x64, 0x72 → 0x6E, 0xF0…0xF6 → 0xE06E…0xE074, 0xF7 → 0xE03F.

On a key **release**, three usages also toggle a state of the device: 0x72 (F23) → `+0x170`, 0xF6 → backlight enabled `+0x168` (ignored if `Flags` bit 0x10), 0xF7 → `+0x16C`. They can be read with [IOCTL 0xB0418](#ioctl-0xb0418--query-toggle-state).

Delivery (sub_1000550C): each record goes to the `KeyboardRaw0` queue, and also to the `WPKeyboardClass` queue unless the raw client set the flag of [IOCTL 0xB02BC](#ioctl-0xb02bc--suppress-wpkeyboardclass-delivery). A record is only kept if the device has at least one open handle: it completes a pending read, otherwise it is added to a list (no limit). Every read (`IRP_MJ_READ`, ≥ 12 bytes, otherwise `STATUS_INVALID_PARAMETER`) returns **one record of 12 bytes**, even with a larger buffer (UIXRender reads 0x78 bytes).

### Key filtering while the display is off

The power setting callback sets the driver context flag `+0x1C` = 1 when `GUID_MONITOR_POWER_ON` is 0 (display off), 0 otherwise (initial value 1). While it is 1, release events are always delivered, but key presses are filtered by device type:

| Type | Key presses delivered while the display is off |
|------|-----------------------------------------------|
| 0, 1 | only 0x68 (F13, power) |
| 2 | all except 0x29 (Escape) and 0x3C (F3); 0x3B (F2) only if `EnableStartOnIdle` |
| 3 | only 0x3B (F2), and only if `EnableStartOnIdle` |

When the display goes off, every pressed key that would be filtered gets a release event (sub_100056F4). Then for the full keyboard (sub_100043E4) the LED states and backlight level are saved (`+0x158`, `+0x15C`, `+0x160`) and switched off; when the display comes back, they are restored and sent to the keyboard.

### HID output report

sub_10005C84 builds the output report: `HidP_SetUsages(HidP_Output, LED page 0x08, 0x50 / 0x51)` for the LEDs that are on, and `HidP_SetUsageValue(HidP_Output, 0x14, usage 0xA0, level)`. sub_10005B54 sends it to the HID collection with `IRP_MJ_WRITE` (`WdfIoTargetFormatRequestForWrite`, synchronous). Switching a LED on or setting a level ≠ 0 is refused with `STATUS_INVALID_DEVICE_STATE` (0xC0000184) while the backlight is disabled (`+0x168` = 0). The level must be ≤ 100.

### Device context

`KEYBOARDWP_DEVICE_CONTEXT`, main fields:  
| Offset | Comment |
|--------|---------|
| 0x000 | Signature `cKbd` |
| 0x030 | Preparsed data, 0x034 `HIDP_CAPS` |
| 0x0F9 | Device index (UnitId) |
| 0x130 | Attributes (28 bytes, see [IOCTL 0xB041C](#ioctl-0xb041c--get-device-attributes)) |
| 0x14C, 0x150 | Current state of LED 1, LED 2 |
| 0x154 | Current backlight level |
| 0x158, 0x15C, 0x160 | Saved LED 1, LED 2, backlight level (display off) |
| 0x168 | Backlight enabled (toggled by 0xF6) |
| 0x16C | Toggle of the key 0xF7 |
| 0x170 | Toggle of the key 0x72 (F23) |

---

### IOCTL 0xB0400 — Get device count

This IOCTL is processed by Kbdclasswp.sys (`\Device\WPKeyboardClass`, sub_1000481C)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x100 (256) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get device count | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Number of filtered devices (driver context `+9`) |

Returns `STATUS_UNSUCCESSFUL` if the output buffer is smaller than 4 bytes.

---

The IOCTLs 0xB0404 to 0xB0418 use the same 12-byte buffer. With `METHOD_BUFFERED` the output is the input buffer updated in place.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 00 00 | UnitId (device index) |
| 02-03 | ? | Not used |
| 04-07 | 01 00 00 00 | LED id (1 or 2) / selector |
| 08-0B | ? | Value |

The IOCTLs 0xB0404 to 0xB0414 also require a full keyboard: the UnitId must be a valid device whose attributes are valid (size 28) with `Flags` bit 0x400, otherwise `STATUS_UNSUCCESSFUL`. A too small buffer → `STATUS_INVALID_BUFFER_SIZE` (0xC0000206).

### IOCTL 0xB0404 — Get backlight level

This IOCTL is processed by Kbdclasswp.sys (sub_100048C8)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x101 (257) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get backlight level ? | ≥ 12 | ≥ 12 |

Outputbuffer byte 08 = level: the saved level (`+0x160`) while the display is off, the current level (`+0x154`) otherwise.

### IOCTL 0xB0408 — Set backlight level

This IOCTL is processed by Kbdclasswp.sys (sub_10004A54)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x102 (258) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set backlight level ? | ≥ 12 | 12 |

Inputbuffer byte 08 = level (0…100). While the display is off the level is sent to the keyboard at once (sub_100020E4, `HidP_SetUsageValue` + output report); while it is on, it is only stored in the saved level (`+0x160`), which is applied at the next "display on". This looks inverted compared with the save / restore of sub_100043E4 (?).

### IOCTL 0xB040C — Get LED state

This IOCTL is processed by Kbdclasswp.sys (sub_10004BCC)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x103 (259) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get LED state | ≥ 12 | ≥ 12 |

Inputbuffer bytes 04-07 = LED id 1 or 2 (otherwise `STATUS_UNSUCCESSFUL`; an id not found in the attributes → `STATUS_NOT_SUPPORTED` 0xC00000BB). Outputbuffer bytes 08-0B = state: saved state (`+0x158` / `+0x15C`) while the display is off, current state (`+0x14C` / `+0x150`) otherwise.

### IOCTL 0xB0410 — Set LED state

This IOCTL is processed by Kbdclasswp.sys (sub_10004DEC)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x104 (260) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set LED state | ≥ 12 | 12 |

Inputbuffer bytes 04-07 = LED id (must be in the attributes, otherwise `STATUS_NOT_SUPPORTED`), bytes 08-0B = state (0 = off). Same display rule as [IOCTL 0xB0408](#ioctl-0xb0408--set-backlight-level): sent to the keyboard (sub_1000415C, LED usage 0x50 / 0x51) while the display is off, stored in the saved state otherwise.

### IOCTL 0xB0414 — Get backlight enabled

This IOCTL is processed by Kbdclasswp.sys (sub_10004FC4)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x105 (261) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get backlight enabled | ≥ 2 | ≥ 4 |

Inputbuffer bytes 00-01 = UnitId. Outputbuffer bytes 00-03 = `+0x168` (toggled by the key 0xF6).

### IOCTL 0xB0418 — Query toggle state

This IOCTL is processed by Kbdclasswp.sys (sub_1000511C)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x106 (262) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Query toggle state | ≥ 12 | ≥ 12 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | FF FF | UnitId, or 0xFFFF = all the devices |
| 04-07 | 02 00 00 00 | Selector: 1 = key 0xF7 (`+0x16C`), 2 = key 0xF6 / backlight enabled (`+0x168`), 3 = key 0x72 F23 (`+0x170`). Other → `STATUS_UNSUCCESSFUL` |

Outputbuffer: bytes 08-0B = the first non-zero state found, bytes 00-01 = the device that has it; bytes 08-0B = 0 if no device has it. No full keyboard check.

### IOCTL 0xB041C — Get device attributes

This IOCTL is processed by Kbdclasswp.sys (sub_100052F4)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x107 (263) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get device attributes | ≥ 2 | ≥ 28 |

Inputbuffer bytes 00-01 = UnitId. Outputbuffer = copy of the device context `+0x130`:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 1C 00 00 00 | Size (28) |
| 04-07 | 00 04 00 00 | `Flags` (registry value, bit 0x400 forced for a full keyboard) |
| 08-0B | 02 00 00 00 | Device type (0 full keyboard, 1 other, 2 hardware buttons, 3 Start/Search/Back ?). 0xFFFFFFFF before `PrepareHardware` |
| 0C-0D | 6E E0 | Scan code of the key tied to LED 1 (0xE06E) |
| 10-13 | 01 00 00 00 | Id of LED 1 (0 = none) |
| 14-15 | 6F E0 | Scan code of the key tied to LED 2 (0xE06F) |
| 18-1B | 02 00 00 00 | Id of LED 2 (0 = none) |

---

### IOCTL 0xB02BC — Suppress WPKeyboardClass delivery

This IOCTL is processed by Kbdclasswp.sys (`\Device\KeyboardRaw0`, sub_100060F8)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0xAF (175) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Suppress WPKeyboardClass delivery ? | 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Stored in the driver context `+0xC`. Non-zero: the key records only go to `KeyboardRaw0`, no longer to `WPKeyboardClass` |

Other sizes → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). Any other IOCTL code on `KeyboardRaw0` → `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0xB01A8 — IOCTL_HID_GET_COLLECTION_INFORMATION

This IOCTL is sent by Kbdclasswp.sys to the HID class driver (local I/O target), in `EvtWdfDevicePrepareHardware`.

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x6A (106) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_HID_GET_COLLECTION_INFORMATION | HID collection | 0 | 12 |

Outputbuffer `HID_COLLECTION_INFORMATION`: bytes 00-03 = `DescriptorSize`, the size of the preparsed data to allocate.

### IOCTL 0xB0193 — IOCTL_HID_GET_COLLECTION_DESCRIPTOR

This IOCTL is sent by Kbdclasswp.sys to the HID class driver (local I/O target), in `EvtWdfDevicePrepareHardware`.

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_HID_GET_COLLECTION_DESCRIPTOR | HID collection | 0 | `DescriptorSize` |

Returns the preparsed data, used with `HidP_GetCaps`, `HidP_GetUsages`, `HidP_SetUsages`, …

---

### Interface GUID

Interface created for each filtered device  
`{884B96C3-56EF-11D1-BC8C-00A0C91405DD}` (`GUID_DEVINTERFACE_KEYBOARD`)

### Other GUID

HID interface waited for on the PDO (`GUID_DEVINTERFACE_HID`)  
`{4D1E55B2-F16F-11CF-88CB-001111000030}`

Power setting (`GUID_MONITOR_POWER_ON`)  
`{02731015-4510-4526-99e6-e5a17ebd1aea}`
