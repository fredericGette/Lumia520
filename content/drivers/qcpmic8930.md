## Qcpmic8930.sys

PMIC driver (Qualcomm "PMIC" KMDF driver, build `P:\PMIC\rel\8.3.1\kmdf`).  
It owns the Power Management IC(s) of the MSM8930 (on the Lumia 520: a PM8038) and exposes almost every PMIC block to the rest of the system through ~140 IOCTLs, grouped by device type (`0x8001`–`0x801E`): ADC/XOADC/CCADC, GPIO, MPP, keypad/power key, voltage regulators (VREG), interrupts, charger, RTC, audio headset detection, PWM/LPG, LEDs, WLED backlight, loudspeaker, vibrator, BMS fuel gauge, battery alarm, coin-cell charger, clocks and "PSI".  
The PMIC is accessed over the SSBI 2.0 bus through the PMIC arbiter, whose physical addresses come from the ACPI method `PMCF`. Each IOCTL is a thin wrapper around an internal Qualcomm PMIC library (`pm_*` functions, tables of function pointers per PMIC), selected at start-up according to the detected PMIC model.  
It is the companion driver that [qcbms8930.sys](./qcbms8930.md) talks to (BMS, CCADC and RTC IOCTLs). A debug mode (registry `UseUsb`) redirects the SSBI accesses to a PMIC reached through a Qualcomm USB serial port.

Symbolic link : `\DosDevices\Global\QCOMPMIC`  
There's no named `\Device\` object (the WDF device is unnamed; only the symbolic link is created).

`WdfDeviceSetStaticStopRemove(FALSE)` is called: the device can't be stopped or removed.

> [!NOTE]
> The surprise-removal callback (`EvtWdfDeviceSurpriseRemoval`, 0x4090EC) calls `KeBugCheckEx(0x14E, 0x51706D30 'Qpm0', 0, 0, 0)`: removing the device crashes the phone.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcpmic8930`  

Registry values, read from the driver's **service key** (`WdfDriverGetRegistryPath`, not the `Parameters` subkey). All are optional and only used by the USB debug mode (see [USB simulation mode](#usb-simulation-mode)):  
| Registry value | value | comment |
|----------------|-------|---------|
| UseUsb | 0 | REG_DWORD (any other type → `STATUS_INVALID_PARAMETER`). When non-zero, the PMIC is accessed through a USB serial port instead of the SSBI arbiter. Stored at device context `+0x65` |
| UsbPmics\\MirrorMode | 0 | REG_DWORD, device context `+0x64`. With `UseUsb`, initialise both the USB and the SSBI access paths ? |
| UsbPmics\\number_of_pmics | 0 | REG_DWORD, clamped to 2 |
| UsbPmics\\PM0\\…, UsbPmics\\PM1\\… | | Per-PMIC subkeys (`PM` + index), REG_DWORD values `bool_simulate_pmic`, `pmic_model`, `pmic_number`, `pmic_revision`, `simulated_pmic_model`, `simulated_pmic_revision`. When `bool_simulate_pmic` = 1 the model/revision are taken from `simulated_pmic_*` instead of being read from the chip |

`ReadRegistryUSBSettings` (0x40782C) is only called when `UseUsb` is set.

GUID of the ETW provider:  
`{1A01E46E-E48A-4C7E-908C-E84F193B44CE}`  
Keyword bits tested in `g_EtwEnableFlags`: 1 = errors (`"E1"`, `"E2"`… plus the NTSTATUS / PMIC error), 2 = information (IOCTL name and buffers, ACPI values), 4 = function entry/exit.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of the device | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) on method `PMCF` (see below) |
| PMIC arbiter (SSBI 2.0) | — | Physical registers mapped with `MmMapIoSpace` (addresses from `PMCF`) |
| `\Device\QCUSB_COM%d_%d` | Qualcomm USB serial driver | Only in USB simulation mode: device `USB\VID_05C6&PID_F005` |
| — | [qcbms8930.sys](./qcbms8930.md) | Consumer of the `IOCTL_PM_GAUGE_*`, `IOCTL_PM_CCADC_*` and `IOCTL_PM_RTC_GET_TIME` controls, through the `{D17B2593-…}` and `{61630799-…}` interfaces |

### Start-up

1. `EvtDriverDeviceAdd` → `PmicDeviceCreate` (0x43F008): PnP/power callbacks, `WdfDeviceCreate`, default queue (`PmicQueueInitialize`, sequential, `EvtIoDeviceControl` = `OnIoDeviceControl`), symbolic link.
2. `EvtWdfDevicePrepareHardware` (0x408BC0): reads `UseUsb` (`UpdatePmPlatConfigFromRegistry`).
   * `UseUsb` = 0: evaluates ACPI `PMCF` (`ParsePmicAcpiConfig`), checks the translated resources (only types 1, 2, 3 and 0x84 are accepted, anything else → `STATUS_INVALID_PARAMETER`) and calls `InitializePmicLibrary`.
   * `UseUsb` ≠ 0: reads the `UsbPmics` registry values and registers a PnP notification on `GUID_DEVINTERFACE_USB_DEVICE`; `InitializePmicLibrary` runs once one `USB#VID_05C6&PID_F005` device per PMIC has arrived.
3. `InitializePmicLibrary` (0x408E08): maps the SSBI arbiter, detects each PMIC (model/revision), fills the per-PMIC function tables of every block, calls `pm_chg_init` (a no-op that only traces) and finally creates the 22 device interfaces (`RegisterDeviceInterfaces`, see [Interface GUID](#interface-guid)).
4. `EvtWdfDeviceReleaseHardware` disables the interfaces and closes the USB handles if any.

### ACPI `PMCF`

`PMCF` is evaluated without argument (`ACPI_EVAL_INPUT_BUFFER` signature `'AeiB'`, 1 KB output buffer). `ParseAndUpdatePmicAcpiData` (0x401480) requires output signature `'AeoB'` and **exactly 9 integer** arguments (otherwise `0xC014000F STATUS_ACPI_INVALID_DATA`), stored in the device context by `AssignPmicAcpiValue` (0x40124C):  
| Index | Context offset | Name (from the trace strings) |
|-------|----------------|-------------------------------|
| 0 | +0x00 | Number of PMICS |
| 1 | +0x04 | PMIC_1_INDEX ssbi2_cfg_base_phys |
| 2 | +0x08 | PMIC_1_INDEX ssbi2_cfg_base_size |
| 3 | +0x0C | PMIC_1_INDEX ssbi2_cmd_base_phys |
| 4 | +0x10 | PMIC_1_INDEX ssbi2_cmd_base_size |
| 5 | +0x18 | PMIC_2_INDEX ssbi2_cfg_base_phys |
| 6 | +0x1C | PMIC_2_INDEX ssbi2_cfg_base_size |
| 7 | +0x20 | PMIC_2_INDEX ssbi2_cmd_base_phys |
| 8 | +0x24 | PMIC_2_INDEX ssbi2_cmd_base_size |

Note: [qcbms8930.sys](./qcbms8930.md) evaluates a method with the same name `PMCF` on its own ACPI node, but expects 7 integers there.

The cfg/cmd windows of each PMIC are mapped `MmNonCached` by `PmicSsbiMapIoSpace` (0x4214F4; bus ids `PMIC_SSBI` = 10 and `PMIC_SSBI2` = 11; pointers `g_Ssbi1CfgBase`/`g_Ssbi1CmdBase` and `g_Ssbi2CfgBase`/`g_Ssbi2CmdBase`). Register accesses go through the `HAL_SBI_SSBI_V2_PMIC_ARBITER_CMD` routines.

### PMIC detection

For each PMIC, `PmicDetectModelRevision` (0x413BD4) reads register `0x002` (REV) and, if its high nibble is `0xF`, register `0x0E8` (REV2), retrying 5 times at 100 ms intervals:  
| REV[7:4] | REV2 | Model | Comment |
|----------|------|-------|---------|
| 0xE | — | 0 | ? |
| 0xF | 0x06 | 1 | PM8921 ? |
| 0xF | 0x0B | 2 | ? |
| 0xF | 0x09 | 3 | PM8038 ? (Lumia 520). Some blocks (e.g. the WLED table `g_PmWledFuncTable`, filled by `PmicLibraryInit` 0x41259C) are only initialised for this model |
| other | other | 4 | Unknown, the PMIC is skipped |

REV[3:0] is kept as the revision. The result is stored in `g_PmicsInfo` (count, then index/model/revision per PMIC) and returned by `IOCTL_PM_HARDWARE_GET_PMICS_INFO`. Most blocks are only populated for models 1 and 3; for the others their function table is zeroed and the IOCTLs return PMIC error 19.

### USB simulation mode

When `UseUsb` ≠ 0, `PmicUsbOpenPort` (0x4212F0) opens `\Device\QCUSB_COM%d_%d` and checks a handshake (`XB` → `=XB03`). SSBI accesses are then sent as ASCII lines terminated by CR LF (`PmicUsbSendCommand`, 0x4210C8), and the answer is read until LF (bytes > 0x7F are XORed with 0xA5):  
| Command | Meaning |
|---------|---------|
| `SR%03X` | Read PMIC register |
| `SW%03X%02X` | Write PMIC register |
| `XR%08I64X` | ? |

---

### IOCTL dispatch

All requests go through `OnIoDeviceControl` (0x40F7D4) → `HandleIoCtlRequest` (0x40A4AC), which switches on the device type (upper 16 bits). Every code uses **METHOD_BUFFERED** / **FILE_ANY_ACCESS**, and function = 1000 + index in the device type's descriptor table (`0x…0FA0` = 1000, `0x…0FA4` = 1001, …). Use `python .claude/skills/driver-doc/scripts/ioctl.py <code>` to decode a code.

| Device type | Block | Handler | Descriptor table |
|-------------|-------|--------------------|------------------|
| 0x8001 | Test | `HandlePmicTestRequest` 0x410A4C | 0x42ADF0 |
| 0x8002 | ADC, XOADC sequencer, BTM, CCADC | `HandlePmicAdcRequest` 0x401900 | 0x42BC48 |
| 0x8003 | GPIO | `HandlePmicGpioRequest` 0x409D0C | 0x430C38 |
| 0x8004 | Keypad / power key | `HandlePmicKeypadRequest` 0x40CB80 | 0x432128 |
| 0x8005 | MPP | `HandlePmicMppRequest` 0x40E268 | 0x4331F0 |
| 0x8006 | Voltage regulators | `HandlePmicVregRequest` 0x410D94 | 0x435060 |
| 0x8007 | Interrupts | `HandlePmicIrqRequest` 0x40B3B4 | 0x431AE0 |
| 0x8008 | Charger | `HandlePmicChargerRequest` 0x405564 | 0x42F638 |
| 0x800A | RTC | `HandlePmicRtcRequest` 0x410648 | 0x4345E0 |
| 0x800D | Audio (headset detection) | `HandlePmicAudioRequest` 0x404340 | 0x42E328 |
| 0x800E | PWM / LPG | `HandlePmicPwmRequest` 0x40E7AC | 0x4340A0 |
| 0x800F | LED | `HandlePmicLedRequest` 0x40D1C8 | 0x432880 |
| 0x8011 | PSI | `HandlePmicPsiRequest` 0x40E63C | 0x433D78 |
| 0x8012 | Loudspeaker | `HandlePmicLoudspeakerRequest` 0x40D368 | 0x432BA8 |
| 0x8013 | RGB LED | `HandlePmicRGBLedRequest` 0x40FAF4 | 0x4344D0 |
| 0x8014 | WLED (backlight) | `HandlePmicWLedRequest` 0x411250 | 0x436338 |
| 0x8015 | Hardware info | `HandlePmicHardwareRequest` 0x40A1D4 | 0x4316B0 |
| 0x8019 | BMS (fuel gauge) | `HandlePmicBmsRequest` 0x405308 | 0x42E880 |
| 0x801A | Battery alarm | `HandlePmicBatAlrmRequest` 0x4046D0 | 0x42E540 |
| 0x801B | Coin-cell charger | `HandlePmicCoinChgRequest` 0x407574 | 0x430B28 |
| 0x801D | Vibrator | `HandlePmicVibRequest` 0x410B48 | 0x434F50 |
| 0x801E | Clocks | `HandlePmicClkRequest` 0x407210 | 0x430910 |

Other device types → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). The binary also contains descriptors for device types it doesn't handle (`0x8009` `IOCTL_PM_3P_GAUGE_*`, `0x800B` `IOCTL_BATT_MNGR_*`, `0x800C` `IOCTL_PMIC_BATT_MINI_*`, `0x8010` `IOCTL_PM_ABD_*`, `0x8016` `IOCTL_PM_3P_CHG_*`); they are used only to print IOCTL names in traces (`getIoControlCodeString`, 0x411BF8).

The descriptors (`IOCTL_INFO`, 0x10C bytes: `+0x00` IoControlCode, `+0x04` UTF-16 name (0x100 bytes), `+0x104` InputBuffer size, `+0x108` OutputBuffer size) are checked by `ValidateParameters` (0x41370C) with an **exact match** on both lengths:  
| Value | Comment |
|-------|---------|
| 0xC00000EF STATUS_INVALID_PARAMETER_1 | No descriptor |
| 0xC00000F0 STATUS_INVALID_PARAMETER_2 | InputBuffer is NULL but the descriptor expects input |
| 0xC00000F1 STATUS_INVALID_PARAMETER_3 | InputBufferLength ≠ descriptor `+0x104` |
| 0xC00000F2 STATUS_INVALID_PARAMETER_4 | OutputBuffer is NULL but the descriptor expects output |
| 0xC00000F3 STATUS_INVALID_PARAMETER_5 | OutputBufferLength ≠ descriptor `+0x108` |

A code that passes the validation but has no `case` in its block handler returns `STATUS_NOT_SUPPORTED` (0xC00000BB). Otherwise the handler returns `STATUS_SUCCESS`, or `STATUS_UNSUCCESSFUL` (0xC0000001) when the PMIC library reports an error.

Buffer conventions (true for almost every IOCTL below):
* InputBuffer bytes `00-03` = **PMIC index** (0 = primary PMIC, 1 = second PMIC). An index ≥ 2 gives PMIC error 9.
* The following input dwords are passed unchanged, in order, as the arguments of the library function (`pm_xxx(pmic, in[1], in[2], …)`); a byte-sized argument is read from the low byte of its dword.
* The OutputBuffer holds a **PMIC error code** (`pm_err_flag`, 0 = success): at `00-03` when the IOCTL returns nothing else, otherwise after the returned values (offset given in the tables).

PMIC error codes seen in the driver:  
| Value | Comment |
|-------|---------|
| 0 | Success |
| 9 | PMIC index out of range |
| 19 | Function not available on this PMIC model (NULL entry in the function table) |
| 89 / 93 | VREG interface not initialised |
| 92 | No PMIC information |
| 95 | Invalid state/parameter (e.g. `IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS` with an unknown type) |
| 105 | NULL pointer |

In the tables below, "In" / "Out" are the exact buffer sizes required, "Input" lists the dwords after the PMIC index, "—" in "Handled" means the code passes the validation but returns `STATUS_NOT_SUPPORTED`.

---

### IOCTL 0x8001xxxx — Test

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out |
|-------|----|------|----|-----|
| 0x80010FA0 | 1000 | IOCTL_PM_TEST_VREG_VOLT_CURR_FREQ | 4 | 16 |
| 0x80010FA4 | 1001 | IOCTL_PM_TEST_MPP_GET_STATUS | 8 | 12 |

Not implemented: after the size validation (`ValidatePmicTestRequest`, 0x410890) the handler always returns `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0x8002xxxx — ADC / BTM / CCADC

This IOCTL is processed by Qcpmic8930.sys  
Function table: `g_PmAdcFuncTable` (61 entries per PMIC), only for models 1 and 3.

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x80020FA0 | 1000 | IOCTL_PM_ADC_READ_DATA | 4 | 8 | — | `00-03` data, `04-07` error |
| 0x80020FA4 | 1001 | IOCTL_PM_ADC_CONFIG_MUX | 8 | 4 | mux | error |
| 0x80020FA8 | 1002 | IOCTL_PM_ADC_SET_ENABLE | 8 | 4 | enable | error |
| 0x80020FAC | 1003 | IOCTL_PM_ADC_REQUEST_CONVERSION | 4 | 4 | — | error |
| 0x80020FB0 | 1004 | IOCTL_PM_ADC_GET_CONVERSION_STATUS | 4 | 8 | — | `00-03` status, `04-07` error |
| 0x80020FB4 | 1005 | IOCTL_PM_ADC_SET_INPUT | 8 | 4 | input | error |
| 0x80020FB8 | 1006 | IOCTL_PM_ADC_SET_DECIMATION_RATIO | 8 | 4 | ratio | error |
| 0x80020FBC | 1007 | IOCTL_PM_ADC_SET_CONVERSION_RATE | 8 | 4 | rate | error |
| 0x80020FC0 | 1008 | IOCTL_PM_ADC_GET_PRESCALAR | 8 | 12 | AMUX channel (0–14, see below) | `00-03` numerator, `04-07` denominator, `08-0B` error |
| 0x80020FC4 | 1009 | IOCTL_PM_ADC_CONFIG_PREMUX | 8 | 4 | premux | error |
| 0x80020FC8 | 1010 | IOCTL_PM_ADC_CONFIG_CONVERSION_SEQUENCER | 16 | 4 | 3 values, applied as 3 calls: `in[2]`, then `in[1]`, then `in[3]` | error |
| 0x80020FCC | 1011 | IOCTL_PM_ADC_ENABLE_CONVERSION_SEQUENCER | 8 | 4 | enable (byte) | error |
| 0x80020FD0 | 1012 | IOCTL_PM_ADC_BTM_ENABLE | 8 | 4 | 2 bytes at `04` and `05` | error |
| 0x80020FD4 | 1013 | IOCTL_PM_ADC_BTM_DISABLE | 4 | 4 | — | error |
| 0x80020FD8 | 1014 | IOCTL_PM_ADC_BTM_READ_DATA | 4 | 8 | — | `00-03` data, `04-07` error |
| 0x80020FDC | 1015 | IOCTL_PM_ADC_BTM_SET_WARM_THRESHOLD | 8 | 4 | threshold (passed by pointer) | error |
| 0x80020FE0 | 1016 | IOCTL_PM_ADC_BTM_SET_COOL_THRESHOLD | 8 | 4 | threshold (passed by pointer) | error |
| 0x80020FE4 | 1017 | IOCTL_PM_ADC_BTM_GET_CONVERSION_STATUS | 4 | 8 | — | `00-03` status, `04-07` error |
| 0x80020FE8 | 1018 | IOCTL_PM_ADC_BTM_REQUEST_CONVERSION | 4 | 4 | — | error |
| 0x80020FEC | 1019 | IOCTL_PM_ADC_SET_PREMUX_OUTPUT | 8 | 4 | output (read **from the output buffer**, see below) | error |
| 0x80020FF0 | 1020 | IOCTL_PM_ADC_BTM_CONFIG_MUX | 8 | 4 | mux | error |
| 0x80020FF4 | 1021 | IOCTL_PM_ADC_BTM_SET_INPUT | 8 | 4 | input | error |
| 0x80020FF8 | 1022 | IOCTL_PM_READ_SEQUENCER_TIMEOUT_FLAG | 4 | 8 | — | `00-03` flag, `04-07` error |
| 0x80020FFC | 1023 | IOCTL_PM_READ_SEQUENCER_FIFO_FLAG | 4 | 8 | — | `00-03` flag, `04-07` error |
| 0x80021000 | 1024 | IOCTL_PM_CCADC_READ_DATA | 4 | 8 | — | `00-03` data, `04-07` error. `BytesReturned` = 4 |
| 0x80021004 | 1025 | IOCTL_PM_CCADC_SET_ENABLE | 8 | 4 | enable | error |
| 0x80021008 | 1026 | IOCTL_PM_CCADC_REQUEST_CONVERSION | 4 | 4 | — | error |
| 0x8002100C | 1027 | IOCTL_PM_CCADC_SET_DECIMATION_RATIO | 8 | 4 | ratio | error |
| 0x80021010 | 1028 | IOCTL_PM_CCADC_SET_CONVERSION_RATE | 8 | 4 | rate | error |
| 0x80021014 | 1029 | IOCTL_PM_CCADC_CONNECT_RSENSE | 8 | 4 | connect (byte) | error |
| 0x80021018 | 1030 | IOCTL_PM_CCADC_CONFIGURE_OFFSET | 8 | 4 | byte | error |
| 0x8002101C | 1031 | IOCTL_PM_CCADC_CONFIGURE_GAIN | 8 | 4 | byte | error |
| 0x80021020 | 1032 | IOCTL_PM_CCADC_SET_OFFSET_TRIM | 8 | 4 | trim | error |
| 0x80021024 | 1033 | IOCTL_PM_CCADC_GET_CONVERSION_STATUS | 4 | 8 | — | `00-03` status, `04-07` error |
| 0x80021028 | 1034 | IOCTL_PM_BTM_CONFIG_PREMUX | 8 | 4 | premux | error |
| 0x8002102C | 1035 | IOCTL_PM_BTM_SET_PREMUX_OUTPUT | 8 | 4 | output | error |
| 0x80021030 | 1036 | IOCTL_PM_CCADC_SET_SEL_SHIFT | 8 | 4 | shift | error |

`IOCTL_PM_ADC_GET_PRESCALAR` on a Lumia 520 (PM8038). The ratios match the PM8921/PM8038 XOADC AMUX channel table (channel names from the Linux `pm8xxx-adc` driver). Channel 15 (MUXOFF ?) → `STATUS_UNSUCCESSFUL`:  
| Channel | Prescaler | Name (Linux) |
|---------|-----------|--------------|
| 0 | 1/3 | VCOIN |
| 1 | 1/3 | VBAT |
| 2 | 1/6 | DCIN |
| 3 | 1/1 | ICHG |
| 4 | 1/3 | VPH_PWR |
| 5 | 1/1 | IBAT |
| 6 | 1/1 | MPP_1 |
| 7 | 1/3 | MPP_2 |
| 8 | 1/1 | BATT_THERM |
| 9 | 1/1 | BATT_ID |
| 10 | 1/4 | USBIN |
| 11 | 1/1 | DIE_TEMP |
| 12 | 1/1 | 0.625 V reference |
| 13 | 1/1 | 1.25 V reference |
| 14 | 1/1 | CHG_TEMP |

Values read on a Lumia 520: `ADC_READ_DATA` = 0x9814, `ADC_GET_CONVERSION_STATUS` = 1, `ADC_BTM_READ_DATA` = 0x7F27, `ADC_BTM_GET_CONVERSION_STATUS` = 0, both sequencer flags = 0, `CCADC_READ_DATA` = 0xCD29 (only 4 bytes returned, as expected), `CCADC_GET_CONVERSION_STATUS` = 1.

`PM_ADC_SET_PREMUX_OUTPUT` (0x403120) reads the PMIC index and value from the *output* buffer pointer; it only works because METHOD_BUFFERED uses the same system buffer for input and output.

---

### IOCTL 0x8003xxxx — GPIO

This IOCTL is processed by Qcpmic8930.sys  
Function table: `g_PmGpioFuncTable` (36 entries per PMIC).

| IOCTL | Fn | Name | In | Out | Handled | Input (after PMIC index) | Output |
|-------|----|------|----|-----|---------|--------------------------|--------|
| 0x80030FA0 | 1000 | IOCTL_PM_GPIO_CONFIG_BIAS_VOLTAGE | 12 | 4 | yes | gpio, voltage source | error |
| 0x80030FA4 | 1001 | IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT | 20 | 4 | yes | gpio, pull, voltage source, source (a 0 is inserted before the last argument) | error |
| 0x80030FA8 | 1002 | IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT | 24 | 4 | yes | gpio + 4 values (buffer, voltage source, source, strength ?) | error |
| 0x80030FAC | 1003 | IOCTL_PM_GPIO_SET_INVERSION_CONFIGURATION | 12 | 4 | yes | gpio, invert | error |
| 0x80030FB0 | 1004 | IOCTL_PM_GPIO_SET_EXT_PIN_CONFIG | 12 | 4 | yes | gpio, config | error |
| 0x80030FB4 | 1005 | IOCTL_PM_GPIO_GET_GPIO_STATE | 12 | 8 | yes | gpio, source (see below) | `00-03` error, `04-07` state |
| 0x80030FB8 | 1006 | IOCTL_PM_GPIO_REGISTER | 4 | 4 | — | | |
| 0x80030FBC | 1007 | IOCTL_PM_GPIO_UNREGISTER | 0 | 4 | — | | |
| 0x80030FC0 | 1008 | IOCTL_PM_GPIO_GET_NUMBER_OF_GPIOS | 4 | 12 | yes | — | `00-03` PMIC index, `04-07` number of GPIOs, `08-0B` error |
| 0x80030FC4 | 1009 | IOCTL_PM_GPIO_GET_GPIO_CONFIG | 12 | 2816 | yes | pointer to a GPIO number array, count | 44 bytes per GPIO (see below) |

`GET_GPIO_STATE` (`PmicGpioGetGpioState`, 0x409A3C): when `in[2]` ≠ 0 the state is read with the GPIO function; when it is 0 the real-time status of interrupt `192 + gpio` is read through the IRQ block instead.

On a Lumia 520 (PM8038): `GET_NUMBER_OF_GPIOS` returns 12. With source ≠ 0, `GET_GPIO_STATE` returns state 0 for all 12 GPIOs; with source = 0 (interrupt real-time status) GPIOs 0, 2, 3, 7, 9 and 10 read 1. These are the same bits as `IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS` block 3, type 1.

`GET_GPIO_CONFIG` (0x80030FC4) Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | ? | **Pointer** to an array of `count` GPIO numbers — dereferenced directly by the driver |
| 08-0B | ? | count (must be ≤ number of GPIOs + 1) |

Output: `count` entries of 44 bytes (`BytesReturned` = 44 × count; the buffer must still be exactly 2816 = 64 × 44 bytes). Entry: `00-03` GPIO number, `04-07` error, `08-1B` 5 configuration dwords, `1C-2B` 16 more bytes (`PmicGpioGetGpioConfig`, 0x409BFC). Field meanings ?

> [!NOTE]
> `IOCTL_PM_GPIO_GET_GPIO_CONFIG` reads the GPIO list through a raw pointer taken from the input buffer, without probing it. It is only safe for kernel-mode callers.

---

### IOCTL 0x8004xxxx — Keypad / power key

This IOCTL is processed by Qcpmic8930.sys  
Function tables: `g_PmKeypadFuncTable` (keypad, 13 entries per PMIC) and `g_PmPwrKeyFuncTable` (power key, 12 entries per PMIC).

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x80040FA0 | 1000 | IOCTL_PM_KEYPAD_CONFIG | 36 | 4 | 8 configuration dwords; the whole input buffer is passed by pointer | error |
| 0x80040FA4 | 1001 | IOCTL_PM_KEYPAD_ENABLE | 8 | 4 | enable | error |
| 0x80040FA8 | 1002 | IOCTL_PM_KEYPAD_GET_MATRIX | 8 | 76 | ? (passed as 7th argument) | `00-03` error, `04-07` ?, `08-0B` count ?, `0C-2B` matrix (32 bytes), `2C-4B` 32 bytes ? |
| 0x80040FAC | 1003 | IOCTL_PM_KEYPAD_POLL_RECENT_MATRIX | 4 | 40 | — | `00-03` error, `04-07` count ?, `08-27` matrix (32 bytes) |
| 0x80040FB0 | 1004 | IOCTL_PM_KEYPAD_GET_POWER_KEY | 4 | 8 | — | `00-03` error, `04-07` power-key state |
| 0x80040FB4 | 1005 | IOCTL_PM_KEYPAD_CONFIG_POWER_KEY | 12 | 4 | 2 values | error |
| 0x80040FB8 | 1006 | IOCTL_PM_KEYPAD_CONFIG_HARD_RESET | 24 | 4 | 5 values, applied as 3 calls: `(in[1])`, `(in[2])`, `(in[4], in[5], in[3])` | error |

On a Lumia 520 (PM8038), `IOCTL_PM_KEYPAD_GET_POWER_KEY` fails with `STATUS_UNSUCCESSFUL` and returns 0 bytes, so the PMIC error code isn't visible. The power-key function is probably missing for model 3 (error 19 ?).

---

### IOCTL 0x8005xxxx — MPP (multi-purpose pins)

This IOCTL is processed by Qcpmic8930.sys  
Function table: `g_PmMppFuncTable` (24 entries per PMIC), only for models 1–3.

| IOCTL | Fn | Name | In | Out | Handled | Input (after PMIC index) | Output |
|-------|----|------|----|-----|---------|--------------------------|--------|
| 0x80050FA0 | 1000 | IOCTL_PM_MPP_CONFIG_DIGITAL_INPUT | 16 | 4 | yes | mpp, level, detection ? | error |
| 0x80050FA4 | 1001 | IOCTL_PM_MPP_CONFIG_DIGITAL_OUTPUT | 12 | 4 | yes | mpp, level/control ? | error |
| 0x80050FA8 | 1002 | IOCTL_PM_MPP_CONFIG_DIGITAL_INOUT | 16 | 4 | yes | mpp + 2 values | error |
| 0x80050FAC | 1003 | IOCTL_PM_MPP_CONFIG_ANALOG_INPUT | 12 | 4 | yes | mpp, channel | error |
| 0x80050FB0 | 1004 | IOCTL_PM_MPP_CONFIG_ANALOG_OUTPUT | 16 | 4 | yes | mpp, level, on/off ? | error |
| 0x80050FB4 | 1005 | IOCTL_PM_MPP_CONFIG_I_SINK | 16 | 4 | yes | mpp, current level, switch ? | error |
| 0x80050FB8 | 1006 | IOCTL_PM_MPP_CONFIG_ATEST | 12 | 4 | yes | mpp, channel | error |
| 0x80050FBC | 1007 | IOCTL_PM_MPP_GET_INPUT_STATE | 12 | 8 | yes | mpp, source (≠0: MPP function, 0: real-time status of interrupt `128 + mpp`) | `00-03` error, `04-07` state |
| 0x80050FC0 | 1008 | IOCTL_PM_MPP_SET_OUTPUT_STATE | 12 | 4 | yes | mpp, state | error |
| 0x80050FC4 | 1009 | IOCTL_PM_MPP_REGISTER | 4 | 4 | — | | |
| 0x80050FC8 | 1010 | IOCTL_PM_MPP_UNREGISTER | 0 | 4 | — | | |

On a Lumia 520 (PM8038), `GET_INPUT_STATE` with source ≠ 0 fails with `STATUS_UNSUCCESSFUL` for every MPP (0–11). With source = 0 it succeeds for MPPs 0–11, all reading 0, even though the PM8038 has fewer MPPs. The interrupt path doesn't check the MPP number.

---

### IOCTL 0x8006xxxx — Voltage regulators (VREG)

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Handled |
|-------|----|------|----|-----|---------|
| 0x80060FA0 | 1000 | IOCTL_PM_BEGIN_SEQUENCE | 0 | 4 | yes |
| 0x80060FA4 | 1001 | IOCTL_PM_END_SEQUENCE | 0 | 4 | yes |
| 0x80060FA8 | 1002 | IOCTL_PM_VREG_SMPS_CLOCK_SEL | 4 | 4 | — |
| 0x80060FAC | 1003 | IOCTL_PM_VREG_SMPS_TCXO_DIV_SEL | 4 | 4 | — |
| 0x80060FB0 | 1004 | IOCTL_PM_VREG_BUCK_CONFIG_COMP | 8 | 4 | — |
| 0x80060FB4 | 1005 | IOCTL_PM_VREG_LDO_BYPASS_SET | 4 | 4 | — |
| 0x80060FB8 | 1006 | IOCTL_PM_VREG_LDO_BYPASS_CLEAR | 4 | 4 | — |
| 0x80060FBC | 1007 | IOCTL_PM_VREG_LDO_CURRENT_LIMIT_ENABLE | 8 | 4 | — |
| 0x80060FC0 | 1008 | IOCTL_PM_VREG_SMPS_SWITCH_SIZE_SET | 8 | 4 | — |
| 0x80060FC4 | 1009 | IOCTL_PM_VREG_SMPS_CONFIG | 12 | 4 | — |
| 0x80060FC8 | 1010 | IOCTL_PM_VREG_SMPS_SWITCH_DRIVER_SIZE_SET | 8 | 4 | — |
| 0x80060FCC | 1011 | IOCTL_PM_VREG_SMPS_PULSE_SKIPPING_ENABLE | 8 | 4 | — |
| 0x80060FD0 | 1012 | IOCTL_PM_VREG_SMPS_SET_STEPPER_CONFIG | 16 | 4 | — |
| 0x80060FD4 | 1013 | IOCTL_PM_VREG_VOTE_FOR_POWER_SETTINGS | 60 | 4 | yes |
| 0x80060FD8 | 1014 | IOCTL_PM_VREG_REGISTER | 4 | 4 | — |
| 0x80060FDC | 1015 | IOCTL_PM_VREG_UNREGISTER | 0 | 4 | — |
| 0x80060FE0 | 1016 | IOCTL_PM_VREG_INITIALIZE | 0 | 4 | yes |
| 0x80060FE4 | 1017 | IOCTL_PM_VREG_GET_POWER_SETTINGS | 4 | 60 | yes |

The regulators are managed by a vote-aggregation layer (`PmicCommonInterface.c`, `InitializePmicDevice` 0x421AC0, mutex `g_VregMutex`): each client's vote is kept in a per-resource list and the aggregated setting is programmed into the PMIC.

* `IOCTL_PM_VREG_INITIALIZE` (`InitializePmicVRegInterface`, 0x411194): initialises the vote layer if needed. Output: error (0, or 89 on failure).
* `IOCTL_PM_BEGIN_SEQUENCE` / `IOCTL_PM_END_SEQUENCE` (`BeginVoltageRegulatorsSequenceVote` 0x422F24 / `EndVoltageRegulatorsSequenceVote` 0x42305C): bracket a group of votes (the mutex is held during the callback). Output: error (93 if not initialised).
* `IOCTL_PM_VREG_VOTE_FOR_POWER_SETTINGS` (`VoteForPmicPowerSettings`, 0x4228F8): Output: error (0, 89 or 93).

Inputbuffer of `IOCTL_PM_VREG_VOTE_FOR_POWER_SETTINGS` (also the Outputbuffer of `IOCTL_PM_VREG_GET_POWER_SETTINGS`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | ? (client ?). Always 0 in `GET_POWER_SETTINGS` |
| 04-07 | ? | Resource id, 0–54 (see table below) |
| 08-0B | ? | Resource kind 0–8 (selects the aggregation routine in `VRegAggregateVote`, 0x422C6C). 0 = LDO, 1 = SMPS, 3 = LVS (the library routines `pm_vreg_config_ldo_01`, `pm_vreg_config_smps_01` and `pm_vreg_config_lvs_01` require kind 0, 1 and 3), 5 = CXO buffers, 6 = CXO clock. 2 MVS ?, 4 NCP ? (shares the routines of kind 3), 7 VDDCX corner ? (shares the routines of kind 6), 8 discrete ?. Other values → error 36. The vote compares 10 dwords (`00-27`) for kind 0, 13 dwords (`00-33`) for kind 1 and 8 dwords for kinds 3/4 |
| 0C-0F | ? | Voltage in µV (e.g. `90 05 10 00` = 1 050 000 = 1.05 V) |
| 10-17 | ? | LVS: both dwords = 1 when switched on (enable ?, ?) |
| 18-23 | ? | ? |
| 24-27 | ? | LDO: 1 on the LDOs above 1.8 V and on some 1.8 V ones, 0 on the low-voltage ones (LDO1/2/20/24/26) ? |
| 28-3B | ? | ? |

`IOCTL_PM_VREG_GET_POWER_SETTINGS` (`GetPmicPowerSettings`, 0x422B30): input `00-03` = resource id; output = the 60-byte structure above (current aggregated setting).

Aggregated settings read on a Lumia 520 (PM8038):  
| Resource | Kind | Voltage | Comment |
|----------|------|---------|---------|
| SMPS1 | 1 | 1.050 V | |
| SMPS2 | 1 | 0.550 V | |
| SMPS3, SMPS4 | 1 | 0 | |
| SMPS5 | 1 | 1.050 V | |
| SMPS6 | 1 | 0.975 V | |
| SMPS7, SMPS8 | — | — | `STATUS_UNSUCCESSFUL` |
| LDO1 / LDO2 | 0 | 1.300 V / 1.200 V | |
| LDO3 / LDO4 / LDO5 | 0 | 3.075 V / 1.800 V / 2.850 V | `24-27` = 1 |
| LDO8 / LDO10 / LDO11 | 0 | 2.800 V / 3.000 V / 1.800 V | `24-27` = 1 |
| LDO14 / LDO17 | 0 | 1.800 V / 2.800 V | `24-27` = 1 |
| LDO20 | 0 | 1.250 V | |
| LDO22 / LDO23 | 0 | 1.850 V / 1.800 V | `24-27` = 1 |
| LDO24 / LDO26 | 0 | 1.1875 V / 1.050 V | |
| other LDOs up to LDO29 | 0 | 0 | Off |
| LVS1, LVS2 | 3 | — | `10-17` = 1, 1 |
| LVS3–LVS7 | — | — | Success, but the whole structure is zero (resource id 0 too): not present |
| MVS1, MVS2, NCP, VDDCX_CORNER, DV1–DV5 | — | — | `STATUS_UNSUCCESSFUL` |
| CXO_BUFFERS | 5 | — | All settings 0 |
| CXO_CLOCK | 6 | — | All settings 0 |

Resource ids, in the order of the `PM_VREG_RESOURCE_ID_*` string table (`.data:0x0042A170`):  
| Id | Resource |
|----|----------|
| 0–7 | SMPS1–SMPS8 |
| 8–36 | LDO1–LDO29 |
| 37–43 | LVS1–LVS7 |
| 44–45 | MVS1–MVS2 |
| 46 | NCP |
| 47 | CXO_BUFFERS |
| 48 | CXO_CLOCK |
| 49 | VDDCX_CORNER |
| 50–54 | DV1–DV5 (discrete regulators) |
| 55 | COUNT |

---

### IOCTL 0x8007xxxx — Interrupts

This IOCTL is processed by Qcpmic8930.sys  
Function table: `g_PmIrqFuncTable` (28 entries per PMIC), only for models 1 and 3.

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x80070FA0 | 1000 | IOCTL_PM_IRQ_CONFIG_INTERRUPT | 24 | 4 | `04` block, `08` bit, `14` trigger — interrupt id = block × 64 + bit | error |
| 0x80070FA4 | 1001 | IOCTL_PM_IRQ_CLEAR_ACTIVE_INTERRUPTS | 16 | 4 | `04` block (byte), `08-0F` 64-bit mask | error |
| 0x80070FA8 | 1002 | IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS | 24 | 16 | `04` block (byte), `08-0F` 64-bit mask, `10` type (0 = latched status, 1 = real-time status) | `00-07` 64-bit status, `08-0B` error, `0C-0F` not written |
| 0x80070FAC | 1003 | IOCTL_PM_IRQ_MASK_INTERRUPTS | 16 | 4 | `04` block (byte), `08-0F` 64-bit mask | error |
| 0x80070FB0 | 1004 | IOCTL_PM_IRQ_UNMASK_INTERRUPT | 24 | 4 | `04` block, `08` bit, `10` trigger | error |
| 0x80070FB4 | 1005 | IOCTL_PM_IRQ_TRIGGER_INTERRUPT | 8 | 4 | interrupt id | error |

`PM_IRQ_GET_INTERRUPTS_STATUS` (0x40B568) calls function-table entry 1 (`sub_41A780`) for type 0 and entry 2 (`sub_41A460`) for type 1, always with interrupt master 2. Both write the block number to register `0x1C0` (IRQ_BLK_SEL). Type 0 then reads `0x1C1` (IT_STATUS, latched) and type 1 reads `0x1C3` (RT_STATUS, real-time). The register names come from the Linux `pm8xxx-irq` driver (base `0x1BB`). The single-interrupt read used by `GET_GPIO_STATE` / `MPP_GET_INPUT_STATE` with source 0 (entry 8, `sub_41A398`) reads the same `0x1C3` register. The IRQ function table is filled by `sub_414EF4` for models 1 and 3.

Type 1 is therefore the real-time status: on a Lumia 520, block 3 type 1 returns `0x68D` (bits 0, 2, 3, 7, 9, 10). These are exactly the GPIOs (interrupts 192 + n) that `IOCTL_PM_GPIO_GET_GPIO_STATE` with source 0 reports as 1. Type 0 returned 0 for blocks 0–3. Type 1 also returned `0x000613000502B000` for block 0 and `0xA000000000000000` for block 1 (interrupts 125 and 127). The driver leaves output bytes `0C-0F` untouched but reports 16 bytes returned.

`GET_INTERRUPTS_STATUS` with a type other than 0/1 returns `STATUS_INVALID_PARAMETER` (0xC000000D) and error 95.  
`TRIGGER_INTERRUPT` (0x40BE60) has no hardware "software trigger": it reads the current trigger type of the interrupt and temporarily reprograms its polarity/edge so that it fires, and remembers it in `g_IrqSwTriggerState`. `CLEAR_ACTIVE_INTERRUPTS` restores the original trigger of such interrupts before clearing them.

---

### IOCTL 0x8008xxxx — Charger

This IOCTL is processed by Qcpmic8930.sys  
Function table: `g_PmChgFuncTable` (57 entries per PMIC), only for models 1 and 3. Besides the descriptor check, each function re-checks the output length and returns `STATUS_INVALID_PARAMETER_4` (0xC00000F2) on mismatch.

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x80080FA0 | 1000 | IOCTL_PM_CHG_DEVICE_BOOT_DONE | 4 | 4 | — | error |
| 0x80080FA4 | 1001 | IOCTL_PM_CHG_USB_ENUM_TIMER_STOP | 8 | 4 | (ignored) | error |
| 0x80080FA8 | 1002 | IOCTL_PM_CHG_PARAMS | 28 | 4 | 6 values, set in this order through table entries 4, 3, 5, 9, 7, 8 (VMAX, IMAX, VBATDET, ITERM, … ?) | error |
| 0x80080FAC | 1003 | IOCTL_PM_CHG_GET_STATE | 4 | 16 | — | `00-03` 0, `04-07` charger state (32 → error 95), `08` byte ?, `09` byte ?, `0C-0F` error |
| 0x80080FB0 | 1004 | IOCTL_PM_CHG_FSM_ENABLE | 16 | 4 | `04` byte, `08` dword, `0C` byte (3 calls: `in[2]`, `in[3]`, `in[1]`) | error |
| 0x80080FB4 | 1005 | IOCTL_PM_CHG_PET_WDOG | 8 | 4 | value | error |
| 0x80080FB8 | 1006 | IOCTL_PM_CHG_CHGPATH_ENABLE | 8 | 4 | enable (byte) | error |
| 0x80080FBC | 1007 | IOCTL_PM_CHG_BATTSAFE | 12 | 4 | 2 values. The call always targets **PMIC 0**, whatever `00-03` says | error |
| 0x80080FC0 | 1008 | IOCTL_PM_CHG_VIN_MIN | 12 | 4 | `04` byte, `08` dword | error |
| 0x80080FC4 | 1009 | IOCTL_PM_CHG_BATT_TEMP_CONFIG | 16 | 4 | 3 values | error |
| 0x80080FC8 | 1010 | IOCTL_PM_CHG_BATT_TEMP_CNTRL | 8 | 4 | value | error |
| 0x80080FCC | 1011 | IOCTL_PM_CHG_VREF_BATT_THERM_CNTRL | 8 | 4 | value | error |
| 0x80080FD0 | 1012 | IOCTL_PM_CHG_GET_BATTSAFE | 4 | 12 | — | `00-03` ?, `04-07` ?, `08-0B` error |
| 0x80080FD4 | 1013 | IOCTL_PM_CHG_GET_REGULATION_LOOP | 4 | 8 | — | `00`–`03` 4 byte flags, `04-07` error |
| 0x80080FD8 | 1014 | IOCTL_PM_CHG_FORCE_OVPFET_ON_OFF | 12 | 4 | `04` dword, `08` byte | error |
| 0x80080FDC | 1015 | IOCTL_PM_CHG_OVP_SET_DEBOUNCE_TIME | 12 | 4 | 2 values | error |
| 0x80080FE0 | 1016 | IOCTL_PM_CHG_CLOCK_KICKSTART_CRITICAL | 4 | 4 | — | error |
| 0x80080FE4 | 1017 | IOCTL_PM_CHG_READ_CHARGING_PARAMTERS | 4 | 28 | — | 6 dwords (`00`–`17`, written in the order `04`, `00`, `10`, `08`, `0C`, `14`), `18-1B` error |

Values read on a Lumia 520 (connected to USB):
* `GET_STATE`: `00-03` = 0, charger state = 7, byte `08` = 1, byte `09` = 0.
* `GET_BATTSAFE`: `00-03` = 4200, `04-07` = 925. These look like the safety limits in mV / mA (VMAX_SAFE, IMAX_SAFE ?).
* `GET_REGULATION_LOOP`: flags 1, 0, 0, 0.
* `READ_CHARGING_PARAMTERS`: 500, 875, 200, 60, 4200, 4500. Possible meaning: input current limit (mA) ?, battery current (mA, ≤ the 925 safety limit) ?, VBATDET delta (mV) ?, ITERM (mA) ?, VMAX 4200 mV, VIN_MIN 4500 mV ?

---

### IOCTL 0x800Axxxx — RTC

This IOCTL is processed by Qcpmic8930.sys  
Function table: `g_PmRtcFuncTable` (25 entries per PMIC, `perhaps_InitRtcFunctionTable`), only for models 1 and 3.

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x800A0FA0 | 1000 | IOCTL_PM_RTC_START | 8 | 4 | start time (seconds) | error |
| 0x800A0FA4 | 1001 | IOCTL_PM_RTC_STOP | 4 | 4 | — | error |
| 0x800A0FA8 | 1002 | IOCTL_PM_RTC_GET_TIME | 4 | 8 | — | `00-03` time (seconds), `04-07` error |
| 0x800A0FAC | 1003 | IOCTL_PM_RTC_GET_TIME_ADJUST | 4 | 8 | — | `00-03` adjust, `04-07` error |
| 0x800A0FB0 | 1004 | IOCTL_PM_RTC_SET_TIME_ADJUST | 8 | 4 | adjust (byte) | error |
| 0x800A0FB4 | 1005 | IOCTL_PM_RTC_ENABLE_ALARM | 12 | 4 | alarm id, delay in seconds **relative to the current RTC time** | error |
| 0x800A0FB8 | 1006 | IOCTL_PM_RTC_DISABLE_ALARM | 8 | 4 | alarm id | error |
| 0x800A0FBC | 1007 | IOCTL_PM_RTC_GET_ALARM_TIME | 8 | 8 | alarm id | `00-03` alarm time, `04-07` error |
| 0x800A0FC0 | 1008 | IOCTL_PM_RTC_GET_ALARM_STATUS | 4 | 8 | — | `00-03` status (byte), `04-07` error |

`IOCTL_PM_RTC_GET_TIME` is used by [qcbms8930.sys](./qcbms8930.md) as its time base.

The RTC alarm armed with `IOCTL_PM_RTC_ENABLE_ALARM` stays active when the phone is powered off, and turns the phone on when it expires (tested on a Lumia 520). By contrast, the ACPI time device ([acpitime.sys](./acpitime.md)) doesn't report any wake alarm capability.

On a Lumia 520 the RTC read 603 536 s (about 7 days). It is **not** a Unix time, so the wall-clock offset is kept elsewhere. `GET_TIME_ADJUST` = 69, `GET_ALARM_STATUS` = 0, and `GET_ALARM_TIME` for alarm 0 = `0xFFFFFFFF` (no alarm set).

---

### IOCTL 0x800Dxxxx — Audio (headset detection)

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x800D0FA0 | 1000 | IOCTL_PM_AUDIO_HSED_CONFIG_CONTROL_REGISTER | 32 | 4 | 7 values (`04`–`1F`) ? | error |
| 0x800D0FA4 | 1001 | IOCTL_PM_AUDIO_HSED_ENABLE_CONTROL_REGISTER | 12 | 4 | 2 values (HSED id ?, enable ?) | error |

---

### IOCTL 0x800Exxxx — PWM / LPG

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out |
|-------|----|------|----|-----|
| 0x800E0FA0 | 1000 | IOCTL_PM_PWM_SELECT_LPG_PARAMETERS | 40 | 4 |
| 0x800E0FA4 | 1001 | IOCTL_PM_SET_PWM_VALUE | 12 | 4 |
| 0x800E0FA8 | 1002 | IOCTL_PM_CONFIGURE_LUT | 40 | 4 |
| 0x800E0FAC | 1003 | IOCTL_PM_START_LUT | 16 | 4 |

Output: error. Field offsets of the 40-byte inputs are not decoded (0x40E940 and 0x40EE90 don't decompile). From the trace strings, `PM_PWM_SELECT_LPG_PARAMETERS` programs in sequence: LPG selection, PWM clock rate, glitch removal, full scale, stagger, phase delay, bit mode, pre-divider, bypass, PWM value, LPG enable, PWM enable, PWM output enable. `PM_CONFIGURE_LUT` (0x40EFFC) programs: LUT enable, ramp, toggle, interval counter, low/high pause counters and enables, LUT values. `PM_START_LUT` (0x40F34C) input: `04` dword, `08` dword, `0C` byte.

---

### IOCTL 0x800Fxxxx — LED

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input | Output |
|-------|----|------|----|-----|-------|--------|
| 0x800F0FA0 | 1000 | IOCTL_PM_LED_CONFIG | 16 | 4 | 4 dwords ? | error |
| 0x800F0FA4 | 1001 | IOCTL_GET_LED_INTERFACE | 0 | 8 | — | 2 function pointers (see below) |
| 0x800F0FA8 | 1002 | IOCTL_PM_LED_SLEEP_CONFIG | 20 | 4 | 4 dwords ? | error |

`IOCTL_GET_LED_INTERFACE` (`PM_LED_GET_INTERFACE`, 0x40CEE0) returns the **kernel addresses** of `PM_LED_CONFIG` (`00-03`) and `PM_LED_CONFIG_SLEEP` (`04-07`), so that another kernel driver can call them directly. Example from a Lumia 520: `0x87345F69` and `0x873460A1`. Bit 0 is set because these are Thumb-2 entry points, and it also shows where the driver is loaded.

---

### IOCTL 0x8011xxxx — PSI

This IOCTL is processed by Qcpmic8930.sys  
Function table: `g_PmPsiFuncTable` (26 entries per PMIC). Meaning of "PSI" ?

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x80110FA0 | 1000 | IOCTL_PM_PSI_SET_MODE | 12 | 4 | 2 values | error |
| 0x80110FA4 | 1001 | IOCTL_PM_PSI_SEND | 912 | 4 | `04-387` data (900 bytes), `388-38B` length | error. `BytesReturned` = 908 |
| 0x80110FA8 | 1002 | IOCTL_PM_PSI_SEND_RECEIVE | 912 | 908 | `04-387` data, `388-38B` length, `38C-38F` ? | `00-383` received data, `384-387` length ?, `388-38B` error |

The descriptor of `IOCTL_PM_PSI_SEND` carries the wrong code (0x80110FA0, same as `SET_MODE`); the handler dispatches on 0x80110FA4.

---

### IOCTL 0x8012xxxx — Loudspeaker

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x80120FA0 | 1000 | IOCTL_PM_SPEAKER_ENABLE | 8 | 4 | enable (byte) | error |
| 0x80120FA4 | 1001 | IOCTL_PM_SPEAKER_MUTE | 8 | 4 | mute (byte) | error |
| 0x80120FA8 | 1002 | IOCTL_PM_SPEAKER_BYPASS_ENABLE | 8 | 4 | enable (byte) | error |
| 0x80120FAC | 1003 | IOCTL_PM_SPEAKER_ADDMODE_ENABLE | 8 | 4 | enable (byte) | error |
| 0x80120FB0 | 1004 | IOCTL_PM_SPEAKER_CD_GAIN | 12 | 4 | `04` dword, `08` byte | error |
| 0x80120FB4 | 1005 | IOCTL_PM_SPEAKER_NOISE_PARAMETERS | 36 | 4 | noise parameters (`14` byte, `18`, `1C` …) ? | error |

---

### IOCTL 0x8013xxxx — RGB LED

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x80130FA0 | 1000 | IOCTL_PM_RGB_LED_ENABLE | 12 | 4 | `04` byte, `05` byte, `08` dword (colour mask, enable, source ?) | error |

---

### IOCTL 0x8014xxxx — WLED (display backlight)

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x80140FA0 | 1000 | IOCTL_PM_WLED_CONFIG | 56 | 4 | see below (programmed as 7 separate library calls) | error |
| 0x80140FA4 | 1001 | IOCTL_PM_WLED_ENABLE | 8 | 4 | enable (byte) | error |
| 0x80140FA8 | 1002 | IOCTL_PM_WLED_DIMMING_CONFIG | 12 | 4 | 2 values | error |
| 0x80140FAC | 1003 | IOCTL_PM_WLED_CONFIG_ADDITIONAL_PARAM | 56 | 4 | `04`, `08` (byte), `0C`, `10`, `14`, `18`, `1C` | error |

`IOCTL_PM_WLED_CONFIG` (`PM_WLED_CONFIG`, 0x41140C) calls slots 1 to 7 of the per-PMIC WLED function table `g_PmWledFuncTable` (0x43B560, see [WLED function table](#wled-function-table)) in sequence and stops at the first error (traced as `"E1"`…`"E7"`). Every step is a masked write `g_pfnPmicRegWrite(bus, addr, mask, value)`. Output: PMIC error (9 = PMIC index not 0/1 or invalid string, 19 = table not filled); the NTSTATUS is `STATUS_UNSUCCESSFUL` when the error is not 0.  
The register names below come from the Linux `leds-pm8xxx` driver (PM8038 WLED) and are not confirmed by the binary.

Inputbuffer of `IOCTL_PM_WLED_CONFIG`:  
| Bytes | Step (routine) | Register (mask) | Comment |
|-------|----------------|-----------------|---------|
| 00-03 | all | — | PMIC index (0 or 1) |
| 04-07 | 1–4 | — | String number (0–2) |
| 08 | 1 (`PmWledSetModCtrl`) | `0x25A` bit 1 (string 0) / bit 2 (string 1) | Modulator control flag ? Nothing is written for string 2 |
| 09 | 1 | `0x25A` bit 4 (string 0) / bit 5 (string 1) | Modulator control flag ? |
| 0C-0F | 2 (`PmWledSetMaxCurrent`) | `0x25B` / `0x25C` / `0x25D` (`0x1F`) | Full-scale current of string 0/1/2, then pulse of the sync bit (`0x264` bit 2/1/0) |
| 10-13 | 3 (`PmWledConfigStringBrightness`) | `0x25E`+`0x25F` / `0x260`+`0x261` / `0x262`+`0x263` | 12-bit brightness: bits 11:8 → first register (`0x0F`), bits 7:0 → second register (`0xFF`), then pulse of the sync bit |
| 14 | 3 | first brightness register bit 7 (`0x80`) | Per-string flag (CABC enable ?) |
| 15 | 4 (`PmWledSetSyncCfg`) | `0x264` bit 3/4/5 (string 0/1/2) | ? |
| 16 | — | — | Not used |
| 17 | 5 (`PmWledSetCtrl12`) | `0x265` bit 7 | ? |
| 18-1B | 5 | `0x265` bits 4:3 | ? |
| 1C-1F | 5 | `0x265` bits 2:1 | ? |
| 20 | 5 | `0x265` bit 0 | ? |
| 21-23 | — | — | Not used |
| 24-27 | 6 (`PmWledSetOvpBoost`) | `0x266` bits 5:4 (`0x30`) | OVP threshold ? |
| 28-2B | 6 | `0x267` bits 7:5 | Boost current limit ? |
| 2C-2F | 6 | `0x267` bits 4:2 | Feedback selection ? |
| 30-33 | 7 (`PmWledSetCompCap`) | `0x268` bits 7:4 (`0xF0`) | Resistor compensation ? |
| 34-37 | 7 | `0x269` bits 6:5 (`0x60`) | High-pole capacitor ? |

Steps 1–4 only touch the string selected by `04-07`, but steps 5–7 rewrite the shared registers `0x265`–`0x269` on every call.

#### WLED function table

`g_PmWledFuncTable` (0x43B560) holds one 0x70-byte entry per PMIC (index 0/1). For model 3 (PM8038) `PmicLibraryInit` fills it with `PmWledInitFuncTable` (0x416D1C), then immediately calls slot 0 (`PmWledResetDefaults`); for any other model the entry is zeroed and all WLED IOCTLs return PMIC error 19. `PmWledInitFuncTable` only stores constants (no register access) and always returns 0.

Layout of an entry:  
| Bytes | Content |
|-------|---------|
| 00-2B | 11 function pointers (slots 0–10, see below) |
| 2C-4B | 16 `u16` register addresses `0x25A`…`0x269` (in order) |
| 4C-6A | 31 bit masks, passed as the `mask` argument of `g_pfnPmicRegWrite`: `70 0F FF C0 08 10 20 9F 30 FC F0 60 01 04 02 01 01 1F 80 80 E0 60 C0 0E 03 0F 80 0C 03 12 24` |
| 6B-6F | Not used |

Slots:  
| Slot | Function | Used by | Comment |
|------|----------|---------|---------|
| 0 | `PmWledResetDefaults` 0x4206E4 | `PmicLibraryInit` | Writes the defaults of the fields also programmed by slot 10: `0x25A` bit 7 = 0, `0x25B`/`0x25C` bits 7:5 = 0, `0x25E` bits 6:4 = 7, `0x264` bits 7:6 = 0, `0x265` bits 6:5 = 0, `0x266` bits 7:6 = 1, bits 3:1 = 2, bit 0 = 1, `0x267` bits 1:0 = 3, `0x268` bits 3:0 = 0xF, `0x269` bit 7 = 0, bits 3:2 = 3, bits 1:0 = 0 |
| 1 | `PmWledSetModCtrl` 0x42080C | `IOCTL_PM_WLED_CONFIG` step 1 | `0x25A` (mask `0x12` or `0x24`) |
| 2 | `PmWledSetMaxCurrent` 0x420884 | step 2 | Full-scale current of a string + sync pulse |
| 3 | `PmWledConfigStringBrightness` 0x42097C | step 3 | Flag (bit 7) + 12-bit brightness of a string + sync pulse |
| 4 | `PmWledSetSyncCfg` 0x420AD8 | step 4 | `0x264` bit 3/4/5 |
| 5 | `PmWledSetCtrl12` 0x420B7C | step 5 | `0x265` (mask `0x9F`) |
| 6 | `PmWledSetOvpBoost` 0x420BC4 | step 6 | `0x266` (`0x30`), `0x267` (`0xFC`) |
| 7 | `PmWledSetCompCap` 0x420C20 | step 7 | `0x268` (`0xF0`), `0x269` (`0x60`) |
| 8 | `PmWledEnable` 0x420C74 | `IOCTL_PM_WLED_ENABLE` | Enable: sets `0x25A` bit 0. Disable: saves `0x25A`–`0x25D` and `0x267`, writes `0x267` = `0x20`, clears the low nibble of `0x25B`–`0x25D`, pulses the sync bits (`0x264` bits 2:0), writes `0x25A` bits 3:1 = 4, waits 1 ms, clears `0x25A` bit 0, then restores the saved values (uses hard-coded masks, and `g_pfnPmicRegRead`) |
| 9 | `PmWledSetBrightness` 0x420E60 | `IOCTL_PM_WLED_DIMMING_CONFIG` | 12-bit brightness of a string (0–2) + sync pulse, i.e. step 3 without the flag |
| 10 | `PmWledSetAdditionalParams` 0x420F8C | `IOCTL_PM_WLED_CONFIG_ADDITIONAL_PARAM` | Programs the fields reset by slot 0, plus `0x25B`/`0x25C` bits 7:5 for string 0/1 |

#### WLED consumers

On a Lumia 520 none of the WLED IOCTLs are sent: only `PmWledInitFuncTable` and `PmWledResetDefaults` run (at start-up), and changing the screen brightness doesn't reach qcpmic8930. The WLED modulator, string currents and brightness are left as configured before Windows starts (UEFI ?), since `PmWledResetDefaults` doesn't touch them.

The only client found is [oempanel.sys](./oempanel.md) (Nokia Panel Driver, service `NOKIA_PANEL`), through the interface `{5B9DF049-70D3-4698-8E48-85B26C1AA59F}` (#14 in [Interface GUID](#interface-guid)). It sends the WLED IOCTLs in two cases:  
| Case | Condition | IOCTLs |
|------|-----------|--------|
| Backlight current control (`sendIoctlQcpmic8930_LedCurrentMilliAmp`, oempanel 0x41789C) | Bit 2 of the registry value `Flags` is set | `IOCTL_PM_WLED_CONFIG` on panel on and on each brightness update (`UpdateWledCurrent`, oempanel 0x417BD0); `IOCTL_PM_WLED_ENABLE` with 1 at the end of the panel power-on sequence and with 0 at panel off |
| Panel power-on sequence (`_sub_417A8C`, oempanel 0x417A8C) | Panel model 198 (Jaywalk) or 204 (Barbie), **whatever `Flags`** | `IOCTL_PM_WLED_CONFIG` twice, then `IOCTL_PM_WLED_CONFIG_ADDITIONAL_PARAM` |

`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NOKIA_PANEL\Parameters\Settings`  
| Registry value | value | comment |
|----------------|-------|---------|
| Flags | 0 | REG_DWORD. Bit 2: drive the backlight current through the WLED IOCTLs. 0 on a Lumia 520 |

With `Flags` bit 2, `IOCTL_PM_WLED_CONFIG` is sent for string 0, then for the panel's string (each retried once on error), with a fixed configuration: `08`/`09` = 1/1, `0C` = current in mA (clamped to 1–25), `10` = `0xFFF` (brightness always maximum), `15` = 1, `24` = 1, `28` = 5, `30` = 3, `34` = 2, everything else 0. The backlight is then dimmed by changing the string current, not the WLED brightness. The buffers of the panel power-on sequence are similar (current from the panel configuration, `18` = 2, `1C` = 3, `28` = 4); see [oempanel.sys](./oempanel.md#ioctl-0x80140fa0--ioctl_pm_wled_config).

When `Flags` bit 2 is clear (Lumia 520), oempanel sets the brightness through the panel itself: `ComputeBacklightLevel` (oempanel 0x403098) computes a 0–255 level, `call_CreateDisplaySequence_18` turns it into MIPI DCS commands (`0x51` set display brightness, `0x53` = `0x24`/`0x2C` display control, `0x55` CABC mode, vendor `0xD7`) sent to the panel by the display driver `qcdxkm8930`. The panel controller probably dims the backlight with a PWM signal on the WLED external dimming input.

---

### IOCTL 0x8015xxxx — Hardware info

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Handled |
|-------|----|------|----|-----|---------|
| 0x80150FA0 | 1000 | IOCTL_PM_HARDWARE_REGISTER | 4 | 4 | — |
| 0x80150FA4 | 1001 | IOCTL_PM_HARDWARE_UNREGISTER | 0 | 4 | — |
| 0x80150FA8 | 1002 | IOCTL_PM_HARDWARE_GET_NUMBER_OF_PMICS | 0 | 4 | yes |
| 0x80150FAC | 1003 | IOCTL_PM_HARDWARE_GET_PMICS_INFO | 0 | 32 | yes |

`GET_NUMBER_OF_PMICS` Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `01 00 00 00` | Number of detected PMICs (no error field) |

`GET_PMICS_INFO` Outputbuffer (copy of `g_PmicsInfo`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Number of detected PMICs |
| 04-07 | ? | PMIC 0 index |
| 08-0B | ? | PMIC 0 model (see [PMIC detection](#pmic-detection)) |
| 0C-0F | ? | PMIC 0 revision |
| 10-1B | ? | Same for PMIC 1 (all zero when there's only one PMIC) |
| 1C-1F | ? | Error |

On a Lumia 520: `01 00 00 00 00 00 00 00 03 00 00 00 02 00 00 00` followed by zeros, i.e. 1 PMIC, model 3 (PM8038), revision 2.

---

### IOCTL 0x8019xxxx — BMS (fuel gauge)

This IOCTL is processed by Qcpmic8930.sys  
Function table: `g_PmBmsFuncTable` (29 entries per PMIC), only for models 1 and 3. The controls are sent by [qcbms8930.sys](./qcbms8930.md).

| IOCTL | Fn | Name | In | Out | Handled | Input (after PMIC index) | Output |
|-------|----|------|----|-----|---------|--------------------------|--------|
| 0x80190FA0 | 1000 | IOCTL_PM_GAUGE_BMS_OUTPUT_REG_STOP_UPDATE_BMS | 8 | 4 | yes | stop (byte) | error |
| 0x80190FA4 | 1001 | IOCTL_PM_GAUGE_READ_BMS_OUTPUT_REG_BMS | 8 | 8 | yes | register selector | `00-03` value, `04-07` error |
| 0x80190FA8 | 1002 | IOCTL_PM_GAUGE_CALIBRATE_BMS | 8 | 4 | yes | value | error |
| 0x80190FAC | 1003 | IOCTL_PM_GAUGE_ENABLE_BMS | 8 | 4 | yes | enable (byte) | error |
| 0x80190FB0 | 1004 | IOCTL_PM_GAUGE_BMS_OVERRIDE_TRIGGER_BMS | 4 | 4 | stub | — | always 19 → `STATUS_UNSUCCESSFUL` |
| 0x80190FB4 | 1005 | IOCTL_PM_GAUGE_BMS_OVERRIDE_READ_BMS | 4 | 4 | stub | — | always 19 → `STATUS_UNSUCCESSFUL` |
| 0x80190FB8 | 1006 | IOCTL_PM_GAUGE_BMS_SET_VSENSE_THR_BMS | 12 | 4 | yes | 2 values (state ?, threshold ?) | error |
| 0x80190FBC | 1007 | IOCTL_PM_GAUGE_BMS_SET_SAMPLE_AVG_BMS | 12 | 4 | yes | 2 values | error |
| 0x80190FC0 | 1008 | IOCTL_PM_GAUGE_BMS_GET_BMS_STATE | 8 | 32 | — | | |
| 0x80190FC4 | 1009 | IOCTL_PM_GAUGE_BMS_OVERRIDE_VBAT_MODE | 8 | 4 | yes | 2 bytes at `04`, `05` | error |
| 0x80190FC8 | 1010 | IOCTL_PM_GAUGE_BMS_SET_CHARGING_STATE | 8 | 4 | yes | state (byte) | error |
| 0x80190FCC | 1011 | IOCTL_PM_GAUGE_BMS_ENABLE_OCV_UPDATE | 8 | 4 | yes | enable (byte) | error |
| 0x80190FD0 | 1012 | IOCTL_PM_GAUGE_BMS_CONFIGURE | 36 | 4 | yes | 8 dwords (mode, 3 parameters, 4 thresholds, −1 = unchanged); handled by `PmicBmsConfigure` (0x4121C8) | error |

`READ_BMS_OUTPUT_REG_BMS` (library `sub_4183A4`, function-table entry 4) writes the selection into bits 4:2 (mask `0x1C`) of register `0x224` (BMS_CONTROL), then reads the 16-bit value from `0x230`/`0x231` (BMS_OUTPUT0/1). The IOCTL selector doesn't map one-to-one to the hardware selection; the hardware names are those of the Linux `pm8921-bms` driver:  
| Selector | Hardware selection | Value | Lumia 520 |
|----------|--------------------|-------|-----------|
| 0 | 0 OCV_FOR_RBATT | 16 bits | 0 |
| 1 | 1 VSENSE_FOR_RBATT | 16 bits | 0 |
| 2 | 2 VBATT_FOR_RBATT | 16 bits | 0 |
| 3 | 3 CC_MSB then 4 CC_LSB | 32 bits: `(MSB << 16) \| LSB`, coulomb counter (signed) | `0xFFAF6713` (−5 282 029) |
| 4 | 5 LAST_GOOD_OCV_VALUE | 16 bits | `0x96F0` |
| 5 | 6 VSENSE_AVG | 16 bits (signed) | `0xFF11` (−239) |
| 6 | 7 VBATT_AVG | 16 bits | `0x9814` |
| ≥ 7 | none (the selection isn't changed) | whatever is currently selected | `0x9814` (still VBATT_AVG) |

The values are raw ADC codes. `IOCTL_PM_ADC_READ_DATA` returned the same `0x9814` as VBATT_AVG.

---

### IOCTL 0x801Axxxx — Battery alarm

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x801A0FA0 | 1000 | IOCTL_PM_BATALRM_CONFIG_CONTROL_REGISTER | 16 | 4 | 3 values | error |
| 0x801A0FA4 | 1001 | IOCTL_PM_BATALRM_ENABLE_CONTROL_REGISTER | 16 | 4 | 3 values | error |
| 0x801A0FA8 | 1002 | IOCTL_PM_BATALRM_READ_ALARM_STATUS | 4 | 12 | — | 3 dwords (2 status values + error ?). All 0 on a Lumia 520 |

---

### IOCTL 0x801Bxxxx — Coin-cell charger

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x801B0FA0 | 1000 | IOCTL_PM_COIN_CHG_CONFIGURE | 16 | 4 | `04` enable (byte), `08` voltage ?, `0C` resistor ? | error |

---

### IOCTL 0x801Dxxxx — Vibrator

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x801D0FA0 | 1000 | IOCTL_PM_VIB_CONTROL_REGISTER | 8 | 4 | drive voltage in 100 mV units: 0 = off, 12–31 = 1.2 V–3.1 V | error |

Handler `PM_VIB_CONTROL_REGISTER` (0x410C94) → function table `dword_43B640` (5 dwords per PMIC, filled by `sub_414018` for models 1 and 3 only), entry 1 = `sub_42068C`. Any value other than 0 or 12–31 (`0x0C`–`0x1F`) returns PMIC error 10 → `STATUS_UNSUCCESSFUL`. Otherwise the value is written, shifted left by 3, into bits 7:3 (mask `0xF8`) of PMIC register `0x04A` (VIB_DRV in the Linux `pm8xxx-vibrator` driver, which uses the same 1.2–3.1 V range). There's no timer: the motor keeps running until 0 is sent. At start-up, entry 0 (`sub_420644`) clears the register under mask `0xFB` (motor off).

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | e.g. `1E 00 00 00` | Level: 0 = stop, 12–31 = 1.2–3.1 V (30 = 3.0 V) |

On a Lumia 520 a level of 10 fails with `STATUS_UNSUCCESSFUL` (out of range).

---

### IOCTL 0x801Exxxx — Clocks

This IOCTL is processed by Qcpmic8930.sys

| IOCTL | Fn | Name | In | Out | Input (after PMIC index) | Output |
|-------|----|------|----|-----|--------------------------|--------|
| 0x801E0FA0 | 1000 | IOCTL_PM_CLK_SET_MP3_1_GPIO_DIV_REGISTER | 8 | 4 | divider | error |
| 0x801E0FA4 | 1001 | IOCTL_PM_CLK_SET_MP3_2_GPIO_DIV_REGISTER | 8 | 4 | divider | error |

---

### Descriptors of IOCTLs not handled

Present only in the name table; sending them returns `STATUS_INVALID_DEVICE_REQUEST`. Useful as a code ↔ name reference for other Qualcomm PMIC drivers:  
| IOCTL | Name | In | Out |
|-------|------|----|-----|
| 0x80090FA0 | IOCTL_PM_3P_GAUGE_GET_BATT_PERC | 0 | 1 |
| 0x80090FA4 | IOCTL_PM_3P_GAUGE_GET_TEMP | 0 | 2 |
| 0x80090FA8 | IOCTL_PM_3P_GAUGE_GET_CAPACITY_PARAMETERS | 0 | 10 |
| 0x80090FAC | IOCTL_PM_3P_GAUGE_GET_CURRENT_PARAMETERS | 0 | 8 |
| 0x80090FB0 | IOCTL_PM_3P_GAUGE_GET_TIME_PARAMETERS | 0 | 8 |
| 0x80090FB4 | IOCTL_PM_3P_GAUGE_GET_POWER_PARAMETERS | 0 | 12 |
| 0x80090FB8 | IOCTL_PM_3P_GAUGE_GET_CONTROL_DATA | 0 | 16 |
| 0x800B0FA4 | IOCTL_BATT_MNGR_GET_BATTERY_ID | 0 | 4 |
| 0x800B0FA8 | IOCTL_BATT_MNGR_GET_CHARGER_STATUS | 4 | 16 |
| 0x800B0FAC | IOCTL_BATT_MNGR_GET_BATTERY_INFO | 12 | 512 |
| 0x800B0FB0 | IOCTL_BATT_MNGR_CONTROL_CHARGING | 16 | 0 |
| 0x800B0FB4 | IOCTL_BATT_MNGR_SET_STATUS_NOTIFICATION_CRITERIA | 16 | 0 |
| 0x800B0FB8 | IOCTL_BATT_MNGR_DISABLE_STATUS_NOTIFICATION | 0 | 0 |
| 0x800B0FBC | IOCTL_BATT_MNGR_SET_OPERATIONAL_MODE | 4 | 0 |
| 0x800B0FC0 | IOCTL_BATT_MNGR_GET_CURRENT_STATE | 0 | 4 |
| 0x800B0FC4 | IOCTL_BATT_MNGR_SET_CHARGE_RATE | 4 | 0 |
| 0x800B0FC8 | IOCTL_BATT_MNGR_NOTIFY_MINICLASS_REMOVAL | 0 | 0 |
| 0x800C0FA0 | IOCTL_PMIC_BATT_MINI_TEST / IOCTL_PMIC_BATT_MINI_NOTIFY_STATUS | 0 | 0 |
| 0x80100FA0 | IOCTL_PM_ABD_GET_PMIC_RTC_DATA | 4 | 16 |
| 0x80100FA4 | IOCTL_PM_ABD_SET_PMIC_RTC_DATA | 16 | 4 |
| 0x80160FA0 | IOCTL_PM_3P_CHG_CHARGE_BATTERY | 4 | 4 |
| 0x80160FA4 | IOCTL_PM_3P_CHG_STOP_CHARGING | 0 | 4 |
| 0x80160FA8 | IOCTL_PM_3P_CHG_GET_CHARGER_STATUS | 0 | 8 |

---

### Other remarks

* `EvtIoDefault` (`OnIoDefault`, 0x40F75C) only traces and never completes the request: a read or write sent to `\\.\QCOMPMIC` stays pending.
* The queue context holds a 10-second WDF timer (`TimerCreate` / `OnTimer`) that completes a stored request with a stored status; nothing in the driver stores a request there, so it looks unused.

---

### Interface GUID

The driver creates 22 device interfaces on the same device, in this order (`RegisterDeviceInterfaces`, 0x407F44), presumably one per PMIC block. Only the two used by [qcbms8930.sys](./qcbms8930.md) are identified:  
| # | GUID | Comment |
|---|------|---------|
| 1 | `{50EC8626-F080-48E2-9076-025BBB44A1A0}` | ? |
| 2 | `{F1EFB001-D615-4EEF-8B1E-E8C13C8DB12A}` | ? |
| 3 | `{D17B2593-7189-4E1E-91F1-00798E07B8AB}` | Used by qcbms8930 for the BMS (`0x8019`) and CCADC (`0x8002`) IOCTLs |
| 4 | `{5186FCEA-68FC-420A-9400-601A6D0CA988}` | ? |
| 5 | `{9A8FF884-5882-4B62-9E0F-172ACE2A9EC0}` | ? |
| 6 | `{A0A0CA65-C6CA-4215-B78B-5201087131BC}` | ? |
| 7 | `{D87538A4-32C4-46D8-985E-F7CA7731BA27}` | ? |
| 8 | `{7C81CACE-8BB1-4C28-ABCF-58C09672CE71}` | ? |
| 9 | `{2F706348-47C5-4873-A66C-6B6BC6B01698}` | ? |
| 10 | `{EF512E80-3E93-45D7-AF9D-D375D53596B8}` | ? |
| 11 | `{61630799-922A-4980-99D9-90C39084A979}` | Used by qcbms8930 for `IOCTL_PM_RTC_GET_TIME` (RTC) |
| 12 | `{248F196D-BB0A-4960-B11C-7EE9479B290F}` | ? |
| 13 | `{A5B9E9A8-EE02-46DC-B9EF-562A78C3E5C9}` | ? |
| 14 | `{5B9DF049-70D3-4698-8E48-85B26C1AA59F}` | Used by [oempanel.sys](./oempanel.md) for the `IOCTL_PM_WLED_*` controls (WLED) |
| 15 | `{1CF4643A-F9BF-42D3-88E8-F37EE6C0677C}` | ? |
| 16 | `{1408ACF4-24D1-43AB-8F80-2F7D8AEDD372}` | ? |
| 17 | `{F9938F2D-3756-4760-A044-CB29AFBA5A69}` | ? |
| 18 | `{CF19BFD2-31C2-47FC-A334-B78F00A8292D}` | ? |
| 19 | `{FF22FC8B-383D-40D3-AFC0-2C37A30D060A}` | ? |
| 20 | `{51840099-5AD1-48EE-9176-BEA2990D2758}` | ? |
| 21 | `{219397E7-B8D9-4DA6-AF0D-1733612E8299}` | ? |
| 22 | `{DB6DE05B-0144-4F22-A9E1-67C729658533}` | ? |

`UnregisterDeviceInterfaces` (0x408538) disables 21 of them: `{2F706348-47C5-4873-A66C-6B6BC6B01698}` is never disabled.

### Other GUID

`GUID_DEVINTERFACE_USB_DEVICE` (PnP notification target in USB simulation mode)  
`{A5DCBF10-6530-11D2-901F-00C04FB951ED}`

`GUID_DEVICE_INTERFACE_ARRIVAL`  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
