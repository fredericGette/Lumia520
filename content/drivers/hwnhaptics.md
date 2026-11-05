## Hwnhaptics.sys

Haptic actuator driver for an I²C haptic controller.  
Like [hwnvibradime.sys](./hwnvibradime.md), it is a client of the Microsoft Hardware Notification class extension `HwNClx` (`hwnclx.sys`): it has no IOCTL of its own, requests come in as `HWN_HEADER` / `HWN_SETTINGS` buffers through the `ClientSetState` / `ClientGetState` callbacks. It registers the same device interface as hwnvibradime, so an application such as [ShellChrome.dll](../libraries/shellchrome.md#haptic-feedback) doesn't need to know which of the two is present.  
It powers the controller with a PMIC clock, a PMIC GPIO and 3 GPIO lines of the SoC, sends it a fixed 7-byte configuration over I²C, then switches the actuator on and off by writing one register. The intensity, the period and the duty cycle of the request are **ignored**: it is a pure on/off driver.  
The board configuration comes from the ACPI method `HWNH` and the connection resources of the device. Up to 4 actuators are supported, one I²C connection each.  
KMDF 1.11, PDB path `P:\hwnhaptics\rel\8.3\arm\release\hwnhaptics.pdb`. Pool tag `HNWH`.

> [!NOTE]
> The Lumia 520 doesn't use this driver: `HWNH` isn't defined in its [DSDT or SSDT](../acpi/README.md) and its vibrator is `\_SB.VIB1`, handled by hwnvibradime.sys. The hardware ID of the device isn't in the binary (it would be in the INF), so the actuator chip, its I²C address and the values below can't be checked against a real ACPI node.

There's no device name and no symbolic link created by the driver itself (the device object and interface are managed by `HwNClx`).  

There's no parameters in the registry.

GUID of the ETW provider (WPP control GUID):  
`{03096FC8-5F52-427A-9E71-F121E1EFE6F1}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI PDO (`WdfDeviceGetIoTarget`) | [acpi.sys](./acpi.md) | Evaluates the method `HWNH`, see [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method) |
| `\Device\RESOURCE_HUB\<connection id>` | [acpiex.sys](./acpiex.md) → I²C controller | One connection per actuator. Opened with `FILE_ALL_ACCESS` (0x1F01FF), written with `WdfIoTargetSendWriteSynchronously`, see [I²C writes](#ic-writes) |
| `\Device\RESOURCE_HUB\<connection id>` | [acpiex.sys](./acpiex.md) → GPIO controller | 3 GPIO lines. Opened with `FILE_GENERIC_WRITE` (0x120116), see [IOCTL 0x480004](#ioctl-0x480004--ioctl_gpio_write_pins) |
| Interface `{DB6DE05B-0144-4F22-A9E1-67C729658533}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC clock (`0x801E`) |
| Interface `{5186FCEA-68FC-420A-9400-601A6D0CA988}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC GPIO (`0x8003`) |

Both PMIC interfaces are opened by `sub_4019A8` with `IoGetDeviceInterfaces` (`DEVICE_INTERFACE_INCLUDE_NONACTIVE`) + `IoGetDeviceObjectPointer` (`GENERIC_ALL`), first symbolic link only.

### HwNClx client

`DriverEntry` (0x407000) creates the WDF driver, calls `HwNRegisterClientDriver` (class `HwNClx` version 1, bound through `WdfVersionBindClass`, 4 imported functions at `.data:0x00404B10`), then `sub_4018B4` registers a PnP notification for each of the 2 PMIC interfaces (`PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`, callback `sub_40192C`). Registration packet (`HWN_CLIENT_REGISTRATION_PACKET`, Version 1, Size 40, client context size 128 bytes):  
| Callback | Function | Comment |
|----------|----------|---------|
| ClientInitializeDevice | `sub_406290` | Reads `HWNH`, parses the resources, opens the I²C and GPIO connections, see [Initialization](#initialization) |
| ClientUnInitializeDevice | `sub_4064E0` | Frees the settings list, writes 0 to register 0x30, [powers off](#power-sequence), unregisters the PnP notifications, deletes the I/O targets |
| ClientQueryDeviceInformation | `sub_4065B4` | Returns 3 USHORTs `1, 6, n` (version, size, number of HwN = `HWNH` element 0) |
| ClientStartDevice | `sub_4065D4` | Opens the PMIC interfaces if needed, [powers on](#power-sequence) |
| ClientStopDevice | `sub_406628` | [Powers off](#power-sequence) |
| ClientSetState | `sub_406790` | See [Set state](#set-state) |
| ClientGetState | `sub_406640` | See [Get state](#get-state) |

`EvtDriverDeviceAdd` (0x4010B8) calls `sub_406000`, which only calls `HwNProcessAddDevicePreDeviceCreate`, `WdfDeviceCreate` (context type `HWNHAPTICS_CONTEXT`) and `HwNProcessAddDevicePostDeviceCreate` with the GUID `{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}`.

Device context (128 bytes):  
| Offset | Size | Comment |
|--------|------|---------|
| +0x00 | 4 | WDFDEVICE |
| +0x04 | 4 | Head of the list of the last settings per HwN Id |
| +0x08 | 8 × 4 | I²C connection ids |
| +0x28 | 4 × 4 | I²C I/O targets |
| +0x38 | 8 × 3 | GPIO connection ids |
| +0x50 | 4 × 3 | GPIO I/O targets |
| +0x5C | 4 | Number of I²C connections |
| +0x60 | 4 | Number of GPIO connections |
| +0x64 | 2 × 7 | The 7 elements of `HWNH` (USHORT each) |
| +0x74 | 4 | PMIC clock DEVICE_OBJECT |
| +0x78 | 4 | PMIC GPIO DEVICE_OBJECT |

### Initialization

`sub_406290`:
1. `sub_40610C` evaluates `HWNH` ([IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method)). The device fails to initialize if the method is missing.
2. Walks the translated resources. Only `CmResourceTypeConnection` (0x84) is kept, other types are skipped:  
   class 2 (serial) / type 1 (I²C): the id is stored at `ctx+0x08 + 8*n`;  
   class 1 (GPIO) / type 2 (I/O): the id is stored at `ctx+0x38 + 8*n`;  
   any other class/type returns `STATUS_INVALID_PARAMETER` (0xC000000D).
3. Fewer than 4 resources in total returns `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A). The power sequence needs 3 GPIO lines, so the minimum is 1 I²C connection + 3 GPIO lines.
4. `sub_4012BC` opens each connection (`WdfIoTargetCreate`, `WdfIoTargetOpen` by name, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`). The path is `\Device\RESOURCE_HUB\` + the 64-bit id in 16 hexadecimal digits (`%0*I64x`). Only the status of the last open is returned.

### Power sequence

Power on (`sub_401F9C`, from ClientStartDevice), skipped when the flag `byte_404B08` is already set:
| Step | Action |
|------|--------|
| 1 | PMIC clock + PMIC GPIO on (`sub_401E34`), see [IOCTL 0x801E0FA0](#ioctl-0x801e0fa0--0x801e0fa4--ioctl_pm_clk_set_mpx_gpio_div_register) and [IOCTL 0x80030FA8](#ioctl-0x80030fa8--ioctl_pm_gpio_config_digital_output) |
| 2 | GPIO 0 ← 1 |
| 3 | GPIO 1 ← 0, GPIO 2 ← 0 |
| 4 | Wait 1 ms |
| 5 | GPIO 1 ← 1, GPIO 2 ← 1 |
| 6 | Wait 10 ms |
| 7 | Sends the [configuration block](#ic-writes) to each actuator |
| 8 | `byte_404B08` = 1 |

Steps 2 to 5 look like a power enable (GPIO 0) followed by a reset pulse (GPIO 1 and 2) ?  

Power off (`sub_401FF8`), only when `byte_404B08` is set: PMIC clock divider 0 + PMIC GPIO off, then GPIO 0, 1 and 2 ← 0, `byte_404B08` = 0.

When `HWNH` element 1 is not 0, ClientStartDevice and ClientStopDevice do nothing and [Set state](#set-state) doesn't touch the hardware: the driver only records the settings.  

> [!NOTE]
> The result of the PMIC requests is ignored. If the interfaces aren't there when the device starts, the pointers at `ctx+0x74` / `ctx+0x78` stay NULL, both requests fail with `STATUS_INVALID_PARAMETER` and the sequence continues without the clock and the PMIC GPIO.  
> The notification callback `sub_40192C` can't fix this: on `GUID_DEVICE_INTERFACE_ARRIVAL` it calls `sub_4019A8` with a **local variable** as destination, so the device pointer is thrown away. The file object returned by `IoGetDeviceObjectPointer` is never dereferenced either, here and in ClientStartDevice.  
> `byte_404B08` is a global, not a field of the context: with two devices the second one wouldn't be powered on.

### Set state

Input buffer (`HWN_HEADER` with n `HWN_SETTINGS`, same layout as [hwnvibradime.sys](./hwnvibradime.md#set-state)):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Payload size. Ignored |
| 04-07 | | Version. Ignored |
| 08-0B | | Number of settings. Ignored: the number comes from the buffer length |
| 0C-0F | 00 00 00 00 | HwN Id. Must be < `HWNH` element 0 and < 4, otherwise `STATUS_INVALID_PARAMETER` (0xC000000D) |
| 10-13 | | HwN type. Stored only, not checked |
| 14-17 | | Intensity. Stored only |
| 18-1B | | Period. Stored only |
| 1C-1F | | Duty cycle. Stored only |
| 20-23 | | Cycle count. Stored only |
| 24-27 | 00 00 00 00 | Forced to 0 by the driver |
| 28-2B | FF FF FF FF | Forced to -1 by the driver |
| 2C-2F | 00/01 00 00 00 | Mode: 0 = off, 1 = on. Any other value is accepted and stored, but nothing is sent to the hardware (no blink mode) |

Fields 0C-2F are repeated for each setting (36 bytes). The length must be larger than 12 and `(length − 12)` a multiple of 36, otherwise `STATUS_INVALID_BUFFER_SIZE` (0xC0000206).

For each setting, `sub_402050` writes register 0x35 of the actuator (table `.data:0x00404154`: HwN Id n = I²C connection n), then `sub_402140` stores the settings in a linked list (40-byte nodes, `PagedPool`). There's no timer: the actuator runs until the next request.

### Get state

The output buffer must be larger than 12 bytes and `(length − 12)` a multiple of 36, otherwise `STATUS_INVALID_BUFFER_SIZE` (0xC0000206).

Without input buffer, it returns the default state: header `36 × n + 12`, version 1, count n, then one setting per 36 bytes of the output buffer with the Id = index, type 2, all fields 0 except bytes 28-2B = FF FF FF FF.

With an input buffer (same length rule), each setting of the input buffer is looked up by HwN Id in the list (`sub_4020FC`) and overwritten with the stored values: the result is in the **input** buffer. An Id that has never been set returns `STATUS_UNSUCCESSFUL` (0xC0000001).

### I²C writes

These are plain writes, not IOCTLs: `WdfIoTargetSendWriteSynchronously` on the I²C connection, timeout 100 ms. The buffer is the register number followed by the data (`PagedPool`, length + 1 bytes). A failed write is attempted 4 times in total, with a delay of 15 ms after each failure.

| Function | When | Register | Length | Data | Table |
|----------|------|----------|--------|------|-------|
| `sub_401CE0` → `sub_40158C` | End of power on, all actuators | 0x30 | 7 | `91 CB 02 11 00 6B D6` | `.data:0x00404148`, data at `0x00404140` |
| `sub_401ADC` | Set state, mode 1 | 0x35 | 1 | `D3` | `.data:0x00404174`, data at `0x00404147` |
| `sub_401ADC` | Set state, mode 0 | 0x35 | 1 | `6B` | `.data:0x00404184`, data at `0x00404180` |
| `sub_401D84` → `sub_40158C` | ClientUnInitializeDevice, all actuators | 0x30 | 1 | `00` | `.data:0x00404190`, data at `byte_404B09` (never written) |

The configuration block is probably written with an auto-incrementing register address: its sixth byte would go to register 0x35 with the value `6B`, the same as the "off" value of Set state. The meaning of the registers is unknown.

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Hwnhaptics.sys to acpi.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI PDO of the device | 8 | 256 |

Sent by `sub_40610C` with `WdfIoTargetSendIoctlSynchronously`.  

Inputbuffer (`ACPI_EVAL_INPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `AeiB` |
| 04-07 | 48 57 4E 48 | Method name `HWNH` |

Outputbuffer (`ACPI_EVAL_OUTPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature `AeoB` |
| 04-07 | | Length |
| 08-0B | | Number of elements, at most 7 |
| 0C- | | Elements: USHORT type, USHORT data length, data. Each one takes `4 + max(length, 4)` bytes |

Only the first element is checked: it must be an integer (type 0) of at most 256 bytes. A bad signature, count, type or length returns `STATUS_ACPI_INVALID_DATA` (0xC014000F).

Elements of `HWNH` (each one stored as a USHORT in the device context):  
| Element | Context | Comment |
|---------|---------|---------|
| 0 | +0x64 | Number of actuators, at most 4 |
| 1 | +0x66 | When not 0: no hardware access, see [Power sequence](#power-sequence) |
| 2 | +0x68 | PMIC index for the clock IOCTL |
| 3 | +0x6A | Clock IOCTL: 1 = 0x801E0FA0, 2 = 0x801E0FA4, any other value = no clock |
| 4 | +0x6C | Clock divider at power on |
| 5 | +0x6E | PMIC GPIO number |
| 6 | +0x70 | Value of the PMIC GPIO "source" field at power on |

---

### IOCTL 0x480004 — IOCTL_GPIO_WRITE_PINS

This IOCTL is sent by Hwnhaptics.sys to the GPIO controller (through `\Device\RESOURCE_HUB\…`)

| Property | Value |
|----------|-------|
| Device | 0x48 |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_GPIO_WRITE_PINS | `\Device\RESOURCE_HUB\<connection id>` | 1 | 1 |

Sent by `sub_40173C` with `WdfIoTargetFormatRequestForIoctl` + `WdfRequestSend` (synchronous). The same memory is used as input and output.  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 / 01 | Level of the line |

---

### IOCTL 0x801E0FA0 / 0x801E0FA4 — IOCTL_PM_CLK_SET_MPx_GPIO_DIV_REGISTER

This IOCTL is sent by Hwnhaptics.sys to qcpmic8930.sys

| Property | 0x801E0FA0 | 0x801E0FA4 |
|----------|------------|------------|
| Device | 0x801E | 0x801E |
| Function | 0x3E8 (1000) | 0x3E9 (1001) |
| Access | FILE_ANY_ACCESS | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_CLK_SET_MP3_1_GPIO_DIV_REGISTER | Interface `{DB6DE05B-0144-4F22-A9E1-67C729658533}` | 8 | 4 |
| IOCTL_PM_CLK_SET_MP3_2_GPIO_DIV_REGISTER | Interface `{DB6DE05B-0144-4F22-A9E1-67C729658533}` | 8 | 4 |

Sent by `sub_401E34` through `sub_401A28` (`IoBuildDeviceIoControlRequest`, no timeout). `HWNH` element 3 selects the IOCTL. When it fails, the PMIC GPIO request isn't sent.  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC index, `HWNH` element 2 |
| 04-07 | | Divider: `HWNH` element 4 at power on, 0 at power off |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code. Not read by the driver |

---

### IOCTL 0x80030FA8 — IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT

This IOCTL is sent by Hwnhaptics.sys to qcpmic8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8003 |
| Function | 0x3EA (1002) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT | Interface `{5186FCEA-68FC-420A-9400-601A6D0CA988}` | 24 | 4 |

Sent by `sub_401E34` through `sub_401A28`. The field names are those of [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8003xxxx--gpio).  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | GPIO number, `HWNH` element 5 |
| 08-0B | 00 00 00 00 | Buffer ? |
| 0C-0F | 02 00 00 00 | Voltage source ? |
| 10-13 | | Source ?: `HWNH` element 6 at power on, 0 at power off |
| 14-17 | 01 / 00 00 00 00 | Strength ?: 1 at power on, 0 at power off |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code. Not read by the driver |

---

### Other GUID

HwNClx device interface ? (passed to `HwNProcessAddDevicePostDeviceCreate`, same GUID as [hwnvibradime.sys](./hwnvibradime.md#other-guid))  
`{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}`

qcpmic8930 interface used for the clocks  
`{DB6DE05B-0144-4F22-A9E1-67C729658533}`

qcpmic8930 GPIO interface  
`{5186FCEA-68FC-420A-9400-601A6D0CA988}`

GUID_DEVICE_INTERFACE_ARRIVAL  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
