## SynapticsTouch.sys

Driver of the **Synaptics S2202B** touch screen controller (RMI4 over I²C), see [components](../components/README.md#synaptics-s2202b-touchscreen-controller-genuine).  
It's a KMDF **HID minidriver** (PDB `E:\build_e\subtask\C5070352_69\output\touch\fre\SynapticsTouch.pdb`). It doesn't create a named device: it handles the HID class internal IOCTLs (`IOCTL_HID_*`) forwarded by the HID pass-through driver (mshidkmdf.sys ?) and reports a 2-finger multi-touch digitizer, plus the 3 capacitive buttons and the "double tap to wake" gesture as keyboard keys.  
The controller is found under ACPI `\_SB.TCH1` (`NOKIA_TOUCH`): I²C address 0x4B on `\_SB.I2C3` ([qci2c8930.sys](./qci2c8930.md)), one GPIO interrupt and one GPIO output (reset line).  
At start the driver scans the RMI4 Page Description Table, reads its configuration from `HKLM\SYSTEM\TOUCH`, **reflashes the controller firmware** from one of the 6 images embedded in the binary if the registry asks for it (RMI4 function F34), then writes the configuration registers (F01, F11/F12, F1A, F51, F54).  
It also creates two raw child PDOs: `NOKIA_TOUCH` (Nokia touch API) and `NOKIA_ENOTOUCHTEST` (production test access: raw register read/write, F54 tests).

There's no device name and no symbolic link created by the driver.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\SynapticsTouch` ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\NOKIA_TOUCH\1`  

GUID of the ETW provider:  
`{F09089A6-BCA1-49E8-B834-CBF04007416F}`

Pool tags: `Touc` (0x63756F54, `WDF_DRIVER_CONFIG.DriverPoolTag` and most allocations), `GenS` (0x536E6547, general settings query table), `KBLC` (0x434C424B).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\RESOURCE_HUB\<connection id>` | [acpiex.sys](./acpiex.md) → [qci2c8930.sys](./qci2c8930.md) | I²C connection (resource class SERIAL / type I2C) to `\_SB.I2C3`, address 0x4B, 400 kHz. Opened with `GENERIC_READ \| GENERIC_WRITE` (`sub_405250`). Register access with `WdfIoTargetSendWrite/ReadSynchronously` |
| `\Device\RESOURCE_HUB\<connection id>` | [acpiex.sys](./acpiex.md) → GPIO controller | GPIO output (resource class GPIO / type IO, GPIO 52 in the DSDT ?): controller reset line. Opened with `GENERIC_WRITE` (`sub_405488`). `IOCTL_GPIO_WRITE_PINS` |
| GPIO interrupt | — | `WdfInterruptCreate` (passive level, ISR `sub_4057EC`). GPIO 11, edge, active low, wake capable in the DSDT ? |
| HID class | mshidkmdf.sys ? / hidclass.sys | Sends the `IOCTL_HID_*` internal IOCTLs, see below |
| PnP manager | ntoskrnl | `IoReportTargetDeviceChangeAsynchronous` with the wake gesture notification, see [Wakeup gesture](#wakeup-gesture) |

### ACPI resources

`_CRS` of `\_SB.TCH1` in the DSDT ([dsdt.dsl](../acpi/dsdt.dsl)), `_DEP` on `\_SB.PEP0`, `\_SB.PRXY`, `\_SB.I2C3`, `\_SB.GIO0`:  
| Resource | Value |
|----------|-------|
| I2cSerialBus | `\_SB.I2C3`, address 0x4B, 400000 Hz |
| GpioInt | `\_SB.GIO0`, pin 0x0B, flags 0x13 (edge, active low, wake capable) |
| GpioIo | `\_SB.GIO0`, pin 0x34 |

`EvtWdfDevicePrepareHardware` (0x4059B0) keeps the connection resources (type 0x84) of class 2 / type 1 (I²C) at context `+0x50` and of class 1 / type 2 (GPIO I/O) at `+0x68`. The I²C connection is mandatory (`STATUS_INSUFFICIENT_RESOURCES` otherwise). The GPIO one is optional: without it the open fails with `STATUS_NOT_FOUND`, which is ignored, and the hardware reset is not available.

### I²C access

Every register access is a write of the 1-byte register address (+ data for a write), then for a read a separate I²C read (`sub_405140` read, `sub_40502C` write). Timeout 300 ms. A transfer is retried up to 10 times (3 times after `STATUS_IO_TIMEOUT`). When all retries fail the controller is reset (`sub_40542C`): reset GPIO = 0, wait 1 ms, reset GPIO = 1.  
RMI4 registers are paged: the page is selected by writing register 0xFF.

### Registry

All values are REG_DWORD, read with `RtlQueryRegistryValuesEx` (or `RtlQueryRegistryValues`) with `RTL_QUERY_REGISTRY_DIRECT`. When a key can't be read, the whole table falls back to defaults hardcoded in the driver.

#### `HKLM\SYSTEM\TOUCH\Settings`

General settings (`sub_402770`, table `.data:0x460B78`, 143 values, stored at controller context `+0x2CC`).  
The "value" column gives the driver default; the values observed on a Lumia 520 (`reg query HKLM\SYSTEM\TOUCH /s`) are in the comments.  
| Registry value | value | comment |
|----------------|-------|---------|
| DeviceId | 1 | Product variant: selects the row of known controller product IDs (see [Firmware update](#firmware-update)). Lumia 520: 4 |
| ControllerType | 0 | 3402, 3202 or 2202 (RMI4 controller family). Selects F12 (3402) or F11 (3202/2202) for the finger data and the F34 register layout. Any other value → `STATUS_NOT_IMPLEMENTED`. Lumia 520: 0x89A = 2202 (F11) |
| ImprovedTouchSupported | 0 | ≠ 0: creates `HKLM\SOFTWARE\OEM\Nokia\Touch\Improved` (glove / "high sensitivity" mode ?). Lumia 520: 1 |
| WakeupGestureSupported | 0 | Bit 0 = double tap, bit 1 = swipe. ≠ 0: creates `HKLM\SOFTWARE\OEM\Nokia\Touch\WakeupGesture` and the controller follows the display state instead of D0/D3. Lumia 520: 1 (double tap only) |
| DoubleTapMaxTapTime10ms | 60 | Unit 10 ms. Lumia 520: 0x23 (350 ms) |
| DoubleTapMaxTapDistance100um | 50 | Unit 100 µm. Lumia 520: 0x1E (3 mm) |
| DoubleTapDeadZoneWidth100um | 50 | Unit 100 µm. Lumia 520: 0x32 |
| DoubleTapDeadZoneHeight100um | 50 | Unit 100 µm. Lumia 520: 0x32 |
| VendorCount | 1 | Number of `VendorNN` slots used. Lumia 520: 3 |
| ResetControllerInWakeUp | 0 | ≠ 0: hardware reset of the controller each time the display turns on. Lumia 520: 1 |
| Vendor00 … Vendor03 | 255 | Column index (0–8) in the product ID table of the `DeviceId`. 255 = unused. Lumia 520: 4, 7, 8 (`PLG-00181`, `PLG-00182`, `Fame-Amp`) |
| Revision00 … Revision03 | 255 | Expected config ID byte 1, used to select `Settings\NN`. Lumia 520: 0xFF (00…02) |
| ReprogramFw00 … ReprogramFw03 | 255 | Firmware revision to flash. 255 = never flash. Lumia 520: 3 (00…02) |
| ForceFlash | 0 | 1 = flash if the revision is different, 10 = always flash. Not present on a Lumia 520 |
| Vendor00ProductId0 … Vendor03ProductId9 | 0 | ASCII bytes of the product ID of slot NN (the 40 values are written at consecutive *byte* offsets, so each REG_DWORD overwrites the 3 following ones; written in increasing order, the result is the string). Lumia 520: `PLG-00181`, `PLG-00182`, `Fame-Amp` |
| VendorNNIncludeHighResTest | 1 | Production test limits for the F54 tests (NN = 00…03). Lumia 520: 1 |
| VendorNNHighResMaxRxLimit / MaxTxLimit / MinImageLimit | 550 / 450 / -400 | Lumia 520: 550 / 450 / -1200 (slot 00), -600 (slots 01, 02) |
| VendorNNIncludeBaselineMinMaxTest | 1 | Lumia 520: 1 |
| VendorNNBaselineMinMaxMinPixelLimit / MaxPixelLimit | -500 / 3000 | Lumia 520: 500 / 5500 (slot 00), 1000 / 5500 (slots 01, 02) |
| VendorNNIncludeFullBaselineTest | 0 | |
| VendorNNRxAmount / TxAmount | 0 | Number of receiver / transmitter electrodes |
| VendorNNRxElectrodeMaskTouch2D / TxElectrodeMaskTouch2D | 0xFFFFFF / 0x3FFF | |
| VendorNNRxElectrodeMaskButtons / TxElectrodeMaskButtons | 0x7000000 / 0x4000 | |
| VendorNNFullBaselineButton0Min … Button2Min | 300 | |
| VendorNNFullBaselineButton0Max … Button2Max | 5500 | |

#### `HKLM\SYSTEM\TOUCH\Settings\NN`

Controller configuration (`sub_4028F4`, table `.data:0x460018`, 103 values, stored at controller context `+0x12C`).  
The key is chosen with the 2 config ID bytes read from F34 (`sub_4026D8`): `Settings\00`…`03` for the first slot whose `VendorNN` = byte 0 and `RevisionNN` = byte 1 (or byte 1 = 0xFF), `Settings\FF` otherwise. If the chosen key can't be opened, the whole table takes the defaults at `.data:0x45FE78`.  
A Lumia 520 only has `Settings\FF` (values in the comments below; the others are not present).  
| Registry value | value | comment |
|----------------|-------|---------|
| SleepMode | 0 | F01 device control |
| NoSleep | 1 | |
| ReportRate | 0 | |
| Configured | 1 | |
| InterruptEnable | 0x0F | F01 interrupt enable mask |
| DozeInterval | 2 | |
| DozeThreshold | 10 | Lumia 520: 0x19 |
| DozeHoldoff | 4 | |
| ReportingMode | 1 | F11 2D control |
| AbsPosFilt | 1 | |
| RelPosFilt, RelBallistics, Dribble | 0 | |
| PalmDetectThreshold | 11 | |
| MotionSensitivity | 3 | |
| ManTrackEn, ManTrackedFinger | 0 | |
| DeltaXPosThreshold, DeltaYPosThreshold | 0 | |
| Velocity, Acceleration | 0 | |
| SensorMaxXPos | 816 | |
| SensorMaxYPos | 1394 | |
| ZTouchThreshold | 30 | |
| ZHysteresis | 5 | |
| SmallZThreshold | 40 | |
| SmallZScaleFactor | 10485 | |
| LargeZScaleFactor | 1310 | |
| AlgorithmSelection | 1 | |
| WxScaleFactor, WyScaleFactor | 48 | |
| WxOffset, WyOffset | 0 | |
| XPitch, YPitch | 18432 | |
| FingerWidthX | 59983 | |
| FingerWidthY | 57196 | |
| ReportMeasuredSize | 0 | |
| SegmentationSensitivity | 112 | |
| XClipLo, XClipHi, YClipLo, YClipHi | 0 | |
| MinFingerSeparation | 10 | |
| MaxFingerMovement | 4 | |
| Threshold0 … Threshold2 | 0 | Capacitive button thresholds (F1A) ? |
| CustomControl0 … CustomControl12 | 0 | |
| F54_ANALOG_CTRL17_03 … F54_ANALOG_CTRL28_01 | 0 | 23 values: F54 analog control registers (CTRL17/18/19 bytes 03–06, CTRL23, CTRL42, CTRL75, CTRL27, CTRL28) |
| WriteF01FullConfig, WriteF11FullConfig, WriteClippingValues, WriteButtonThresholds, WriteF51Config, WriteButtonDozeThreshold, DisableDozeMode, EnableWakeupGesture, WriteF54Config | 0 | ≠ 0: write the corresponding group of registers to the controller. Lumia 520: `WriteButtonDozeThreshold` = 1, `EnableWakeupGesture` = 1, the others 0 |
| F54SensingFreqs, F54EnableNewSensingFreqs, F54ConfigureNewSensingFreqs, F54WriteMedNoiseThreshold, F54WriteVMThreshold, F54WriteFilterCoeff | 0 | Same, F54 |
| F54WriteFNMFreqShiftNoiseThres | 1 | |
| StartButton | 2 | Bit number in report 9 (see [HID report descriptor](#hid-report-descriptor)) for **F1A button 1**. Lumia 520: 0 |
| SearchButton | 0 | Same for **F1A button 0**. Lumia 520: 2 |
| BackButton | 0 | Same for **F1A button 2**. Lumia 520: 1 |

> [!NOTE]
> The names of the 3 button values don't match the buttons they control (see [Capacitive buttons](#capacitive-buttons)).

#### `HKLM\System\TOUCH\SCREENPROPERTIES`

Read by `sub_40391C` (table `.data:0x461BA0`). Used to map the controller coordinates to the display.  
| Registry value | value | comment |
|----------------|-------|---------|
| TouchSwapAxes, TouchInvertXAxis, TouchInvertYAxis | 0 | |
| TouchPhysicalWidth | 480 | Lumia 520: 0x1E0 (480) |
| TouchPhysicalHeight | 800 | Lumia 520: 0x375 (885 = 800 + 85) |
| TouchPhysicalButtonHeight | 0 | Height of the button area below the screen. Lumia 520: 0x55 (85) |
| TouchPillarBoxWidthLeft / Right, TouchLetterBoxHeightTop / Bottom | 0 | Reset to the defaults if they leave no area |
| DisplayPhysicalWidth / DisplayViewableWidth | 480 | Lumia 520: 480 |
| DisplayPhysicalHeight / DisplayViewableHeight | 800 | Lumia 520: 800 |
| DisplayPillarBoxWidthLeft / Right, DisplayLetterBoxHeightTop / Bottom | 0 | Lumia 520: 0 |
| DisplayHeight10um, DisplayWidth10um | 0 | Unit 10 µm. Lumia 520: 0x21CA (86.5 mm), 0x1450 (52 mm) |

The Lumia 520 key also has `TouchPillarBoxHeightTop` and `TouchPillarBoxHeightBottom` (0). The driver doesn't read these names (it reads `TouchLetterBoxHeight…`).  
The other subkeys of `HKLM\SYSTEM\TOUCH` are not read by this driver:  
| Registry key | Values (Lumia 520) |
|--------------|--------------------|
| `BUTTONS` | `Area` = `0,800 480,885`, `Count` = 3, `Duration` = 0x1E, `Intensity` = 0x63, `Vibrate` = 1 (vibration feedback ?) |
| `BUTTONS\0` | `Name` = `Back`, `Area` = `8,830 108,885`, `VKey` = 0x1B (VK_ESCAPE) |
| `BUTTONS\1` | `Name` = `Start`, `Area` = `197,830 297,885`, `VKey` = 0x71 (VK_F2) |
| `BUTTONS\2` | `Name` = `Search`, `Area` = `372,830 472,885`, `VKey` = 0x72 (VK_F3) |
| `BUTTONS\BACKLIGHT` | `InactivityTimeout` = 0, `IntensityMappings1` = `10`, `0`, `LedCount` = 0, `LedIndexList` = `1`, `MilliLuxRanges` = `100000`, `4294967295` |
| `DISPLAYPROPERTIES` | `DisplayHeight10um` = 0x21CA, `DisplayWidth10um` = 0x1450 |

#### `HKLM\SOFTWARE\OEM\Nokia\Touch`

Created by the driver (`sub_406888` / `sub_4066E4`) when `ImprovedTouchSupported` or `WakeupGestureSupported` is set, then watched with `ZwNotifyChangeKey` (whole tree, `REG_NOTIFY_CHANGE_LAST_SET`). If it can't be opened yet, the driver retries every second.  
| Registry key | Value | comment |
|--------------|-------|---------|
| `…\Touch` | APIVersion | REG_SZ `1.0`, written at each start |
| `…\Touch\Improved` | Enabled | Created with 1 if missing. Written to the controller on change (`sub_4037A8`). Also written by [oempanel.sys](./oempanel.md#key-lights-and-improved-touch): briefly set to 0 while the key lights are switched on (when its `Flags` bit 0 is set) |
| `…\Touch\WakeupGesture` | Enabled | Double tap to wake. Created with 1 if missing (if bit 0 of `WakeupGestureSupported`), removed otherwise |
| `…\Touch\WakeupGesture` | SwipeEnabled | Swipe to wake. Same, bit 1 (so removed on a Lumia 520) |
| `…\Touch\WakeupGesture` | ProxyDetected | Set to 0 by the driver at start and each time the display turns on. ≠ 0 (object near the proximity sensor) disables the wake gesture |

### Power

Without wakeup gesture, the controller is put to sleep in `EvtWdfDeviceD0Exit` (`sub_4022C4`) and woken up in `EvtWdfDeviceD0Entry` (`sub_402268`). The first D0 entry after the hardware preparation only starts a 2-second timer that does the late initialization.  
With `WakeupGestureSupported` ≠ 0, D0/D3 don't touch the controller. Instead the driver registers `PoRegisterPowerSettingCallback` for `GUID_CONSOLE_DISPLAY_STATE` `{6FE69556-704A-47A0-8F24-C28D936FDA47}` (`sub_4058F4`):  
* display off: the controller goes into its wake gesture mode (`sub_4022C4`);
* display on: wake-up (`sub_402268`), optional hardware reset (`ResetControllerInWakeUp`), `ProxyDetected` reset to 0.

### Wakeup gesture

When the controller reports a gesture while the display is off (`sub_402B8C`; F12 on a 3402, F11 on a 3202/2202):  
1. a custom PnP notification is sent with `IoReportTargetDeviceChangeAsynchronous` on the touch device: event GUID `{19CF83DB-B725-402B-BE0B-F51BED9FD984}`, 1 byte of custom data = gesture type (1 or 2: double tap / swipe ?);
2. a key press is reported in HID report 9: `09 08` (bit 3 = usage 0x68, F13), and a 100 ms timer is started (`sub_405734`, key release ?).

### Firmware update

The driver embeds 6 firmware + configuration images for F34 (RMI4 flash), table `.data:0x461DF0` (7 pointers per entry):  
| # | Product ID | Firmware image | Config image |
|---|------------|----------------|--------------|
| 0 | `Fame-Amp` | `.data:0x421B88` | `.data:0x42CB88` |
| 1 | `PLG-00181` | `.data:0x40BB70` | `.data:0x42CDF0` |
| 2 | `PLG-00182` | `.data:0x416B88` | `.data:0x42D040` |
| 3 | `PLG0271-01` | `.data:0x42D2A0` | `.data:0x443EA0` |
| 4 | `s3202_ver5` | `.data:0x4442B8` | `.data:0x44F2B8` |
| 5 | `TM2449-001` | `.data:0x44F510` | `.data:0x45A510` |

`Fame` is the code name of the Lumia 520.  
On a Lumia 520 (`DeviceId` = 4, `Vendor00/01/02` = 4/7/8, `ReprogramFw00…02` = 3, no `ForceFlash`), the 3 accepted controllers are `PLG-00181`, `PLG-00182` and `Fame-Amp`, and the embedded image is flashed when the controller's config ID byte 1 is below 3.

Known product IDs per `DeviceId` (`.data:0x461E98`, 8 rows × 9 columns, the other cells are `TMXXXX_XXX`):  
| DeviceId | Product IDs (column) |
|----------|----------------------|
| 0 | `TM2072-001` (1), `TM2143-001` (4) |
| 1 | `TM2100-001` (4) |
| 2 | `TM2099` (4) |
| 3 | `TM2449-001` (4) |
| 4 | `PLG-00181` (4), `PLG-00182` (7), `Fame-Amp` (8) |
| 5 | `PLG-00181` (4), `PLG-00182` (7), `Fame-Amp` (8) |
| 6 | `s3202_ver5` (8) |
| 7 | `PLG0271-01` (8) |

Selection (`sub_404A08`):  
1. read the 10-byte product ID (F01 query) and the 2 config ID bytes (F34);
2. find the column whose product ID matches, and the slot NN with `VendorNN` = this column;
3. flash if the controller is in bootloader mode (context `+0xB8` ?), or `ForceFlash` = 10, or `ReprogramFwNN` ≠ 255 and is higher than config ID byte 1 (values ≥ 100 are compared separately), or `ForceFlash` = 1 and they differ;
4. the image is the embedded one whose product ID matches the controller.

The flash runs block by block from the interrupt path (`sub_404B4C`: F34 command 2 "write firmware block", `sub_404CA8`: command 6 "write configuration block"). While it runs (`+0x8E` ≠ 0) the HID reads are queued and not served.

### HID report descriptor

Device descriptor (9 bytes, `.data:0x45A8D0`): `09 21 01 00 00 01 22 D0 00` (HID 1.00, 1 report descriptor of 208 bytes).  
Report descriptor (208 bytes, `.data:0x45A8E0`):  
| Report ID | Type | Collection | Content |
|-----------|------|------------|---------|
| 1 | Input | Digitizer / Touch Screen | 2 × Finger: Tip Switch (1 bit), In Range (1 bit), 6 bits padding, Contact Identifier (8 bits), X (16 bits, 0–4095, physical 0–1205), Y (16 bits, 0–4095, physical 0–906); unit exponent -2, unit 0x33. Then Contact Count (8 bits) |
| 8 | Feature | Digitizer / Touch Screen | Contact Count Maximum (8 bits, logical max 2) |
| 7 | Feature | Digitizer / Device Configuration | Device Mode, Device Identifier (2 × 8 bits, 0–10) |
| 9 | Input | Generic Desktop / usage 0xEE | Keyboard usages 0x3B (F2), 0x3C (F3), 0x29 (Escape), 0x68 (F13): 4 bits + 28 bits padding |

Report 1 is 14 bytes: report ID, 2 × 6 bytes per finger, contact count.  
Report 9 bit *n* is set by the capacitive button configured with value *n* (see below). Bit 3 is the wake gesture.

### Capacitive buttons

`sub_402D50` reads the F1A (0D capacitive buttons) data register and builds report 9. On a Lumia 520 (values of `Settings\FF`):  
| F1A bit | Registry value used | Lumia 520 value | Report 9 bit | HID usage | VKey in `TOUCH\BUTTONS` | Button |
|---------|---------------------|-----------------|--------------|-----------|-------------------------|--------|
| 0 | SearchButton | 2 | 2 | 0x29 Escape | 0x1B | Back |
| 1 | StartButton | 0 | 0 | 0x3B F2 | 0x71 | Start |
| 2 | BackButton | 1 | 1 | 0x3C F3 | 0x72 | Search |

So with left-to-right F1A buttons ? (Back, Start, Search), each key matches the `TOUCH\BUTTONS` mapping, but the registry value used for each button has the name of a different button.

---

### internal IOCTL 0xB0003 — IOCTL_HID_GET_DEVICE_DESCRIPTOR

This IOCTL is processed by SynapticsTouch.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x0 (0) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_GET_DEVICE_DESCRIPTOR | 0 | 9 |

Copies the 9-byte HID descriptor (see [HID report descriptor](#hid-report-descriptor)).

---

### internal IOCTL 0xB0007 — IOCTL_HID_GET_REPORT_DESCRIPTOR

This IOCTL is processed by SynapticsTouch.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_GET_REPORT_DESCRIPTOR | 0 | 208 |

Copies the 208-byte report descriptor.

---

### internal IOCTL 0xB000B — IOCTL_HID_READ_REPORT

This IOCTL is processed by SynapticsTouch.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x2 (2) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_READ_REPORT | 0 | ≥ 14 |

`sub_4073C4`: the request is forwarded to a manual queue (context `+0x0C`) and completed by the interrupt processing with report 1 or report 9. After a D0 entry, the first read also processes the pending controller interrupts (unless a firmware flash is running).

---

### internal IOCTL 0xB0013 — IOCTL_HID_GET_STRING

This IOCTL is processed by SynapticsTouch.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x4 (4) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_GET_STRING | 0 | string length |

The string ID is the low word of `Type3InputBuffer`:  
| String ID | String |
|-----------|--------|
| 14 (HID_STRING_ID_IMANUFACTURER) | `Synaptics` |
| 15 (HID_STRING_ID_IPRODUCT) | `3200` |
| 16 (HID_STRING_ID_ISERIALNUMBER) | `4` |

Other IDs: `STATUS_INVALID_PARAMETER`. Output buffer too small: `STATUS_BUFFER_TOO_SMALL`.

---

### internal IOCTL 0xB0027 — IOCTL_HID_GET_DEVICE_ATTRIBUTES

This IOCTL is processed by SynapticsTouch.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x9 (9) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_GET_DEVICE_ATTRIBUTES | 0 | 32 |

Outputbuffer (`HID_DEVICE_ATTRIBUTES`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 20 00 00 00 | Size = 32 |
| 04-05 | 79 73 | VendorID 0x7379 (`ys`) |
| 06-07 | 6D 72 | ProductID 0x726D (`mr`) |
| 08-09 | 80 0C | VersionNumber 3200 |
| 0A-1F | 00 | Reserved |

---

### internal IOCTL 0xB002B — IOCTL_HID_SEND_IDLE_NOTIFICATION_REQUEST

This IOCTL is processed by SynapticsTouch.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0xA (10) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_SEND_IDLE_NOTIFICATION_REQUEST | ≥ 8 | 0 |

`sub_406CBC`: `Type3InputBuffer` is a `HID_SUBMIT_IDLE_NOTIFICATION_CALLBACK_INFO`. Input length < 8: `STATUS_INVALID_BUFFER_SIZE`; no callback: `STATUS_NO_CALLBACK_ACTIVE`. Otherwise a work item (`sub_406DA4`) is queued with the request (calls the idle callback ?) and the request stays pending.

---

### internal IOCTL 0xB0191 — IOCTL_HID_SET_FEATURE

This IOCTL is processed by SynapticsTouch.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_SET_FEATURE | ≥ 12 | 0 |

`sub_40745C`. `Irp->UserBuffer` is a `HID_XFER_PACKET` (no packet: `STATUS_INVALID_DEVICE_REQUEST`). Only report 7 (device configuration) is accepted, with ≥ 3 bytes:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 07 | Report ID |
| 01 | 00 or 02 | Device Mode: 0 = mouse, 2 = multiple input. Stored at context `+0x00` (default 2) |
| 02 | | Device Identifier (ignored) |

Other reports or modes: `STATUS_INVALID_PARAMETER`.

---

### internal IOCTL 0xB0192 — IOCTL_HID_GET_FEATURE

This IOCTL is processed by SynapticsTouch.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_OUT_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_GET_FEATURE | 0 | ≥ 12 |

`sub_407504`, same `HID_XFER_PACKET` handling:  
| Report ID | Min length | Byte 1 returned |
|-----------|------------|-----------------|
| 7 | 3 | Current Device Mode |
| 8 | 2 | Contact Count Maximum = **10** |

> [!NOTE]
> The driver returns a maximum of 10 contacts although the report descriptor declares a logical maximum of 2 and report 1 only carries 2 fingers.

---

### Child device NOKIA_TOUCH

Raw PDO created by `sub_4642EC` (`WdfPdoInitAssignRawDevice` with the HIDClass setup class `{745A17A0-74D3-11D0-B6FE-00A0C90F57DA}`):  
| Property | Value |
|----------|-------|
| Device ID | `{3a0ac59a-4d8a-4875-b7ea-304771ff9b9a}\NokiaTouch` |
| Hardware ID | `NOKIA_TOUCH` |
| Instance ID | `0` |
| Interface | `{3A0AC59A-4D8A-4875-B7EA-304771FF9B9A}` |
| SDDL | `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GR;;;WD)` |

The open handles are counted at context `+0xAC`. Its queue (`sub_40720C`) only handles IOCTL 0x83222004; other codes complete with status 0x80. If the parent context is missing: `STATUS_INVALID_HANDLE`.

### IOCTL 0x83222004

This IOCTL is processed by SynapticsTouch.sys (`NOKIA_TOUCH` child)

| Property | Value |
|----------|-------|
| Device | 0x8322 |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get API version ? | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 01 00 | Major version ? |
| 02-03 | 00 00 | Minor version ? (= `APIVersion` `1.0` in the registry) |

---

### Child device NOKIA_ENOTOUCHTEST

Raw PDO created by `sub_406374`:  
| Property | Value |
|----------|-------|
| Device ID | `{1ED875DA-D851-42BE-9DFD-527D97178147}\Touch Test` |
| Hardware ID | `NOKIA_ENOTOUCHTEST` |
| Instance ID | `0` |
| Interface | `{1ED875DA-D851-42BE-9DFD-527D97178147}` |
| SDDL | `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GR;;;WD)` |

The open handles are counted at context `+0x80`. Its queue (`sub_405FB0`) gives direct access to the controller registers. Unknown codes: `STATUS_UNSUCCESSFUL`; bad parameters: `STATUS_INVALID_PARAMETER`.

> [!NOTE]
> These IOCTLs use device type 0xB (FILE_DEVICE_KEYBOARD) with functions 100–107, like the HID IOCTLs, but they are normal (not internal) IOCTLs sent to the test PDO.

### IOCTL 0xB0190

This IOCTL is processed by SynapticsTouch.sys (`NOKIA_ENOTOUCHTEST` child)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read registers | 8 | ≥ length |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Must be 1 |
| 01 | | Register address (in the current page) |
| 02-03 | | ? |
| 04-07 | | Length, ≠ 0 |

Outputbuffer: the register bytes. Returns *length* bytes.

---

### IOCTL 0xB0194

This IOCTL is processed by SynapticsTouch.sys (`NOKIA_ENOTOUCHTEST` child)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x65 (101) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write registers | 8 + length | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Must be 1 |
| 01 | | Register address (in the current page) |
| 02-03 | | ? |
| 04-07 | | Length |
| 08-… | | Data |

---

### IOCTL 0xB0198

This IOCTL is processed by SynapticsTouch.sys (`NOKIA_ENOTOUCHTEST` child)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x66 (102) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 1 | 0 |

Stores the byte at context `+0x84` (test mode flag ?).

---

### IOCTL 0xB019C

This IOCTL is processed by SynapticsTouch.sys (`NOKIA_ENOTOUCHTEST` child)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x67 (103) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Select RMI page | 1 | 0 |

Writes the byte to register 0xFF (RMI4 page select), unless it is already the current page.

---

### IOCTL 0xB01A0, 0xB01A8

This IOCTL is processed by SynapticsTouch.sys (`NOKIA_ENOTOUCHTEST` child)

| Property | 0xB01A0 | 0xB01A8 |
|----------|---------|---------|
| Device | 0xB | 0xB |
| Function | 0x68 (104) | 0x6A (106) |
| Access | FILE_ANY_ACCESS | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Controller sleep | 0 | 0 |

Calls `EvtWdfDeviceD0Exit` of the touch device: the controller is put to sleep.

---

### IOCTL 0xB01A4, 0xB01AC

This IOCTL is processed by SynapticsTouch.sys (`NOKIA_ENOTOUCHTEST` child)

| Property | 0xB01A4 | 0xB01AC |
|----------|---------|---------|
| Device | 0xB | 0xB |
| Function | 0x69 (105) | 0x6B (107) |
| Access | FILE_ANY_ACCESS | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Controller wake-up | 0 | 0 |

Calls `EvtWdfDeviceD0Entry` of the touch device: the controller is woken up.

---

### IOCTL 0x83203E84

This IOCTL is processed by SynapticsTouch.sys (`NOKIA_ENOTOUCHTEST` child)

| Property | Value |
|----------|-------|
| Device | 0x8320 |
| Function | 0xFA1 (4001) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| F54 test ? | ≥ 8 | ≥ 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 or 04 00 00 00 | Test: 3 = `sub_405C80`, 4 = `sub_405DB8`. Other values: 0xC0000011 |
| 04-07 | 00 00 00 00 | Must be 0 (`STATUS_UNSUCCESSFUL` otherwise) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | | Result ? |
| 08-0B | 02 00 00 00 | |
| 0C-0F | 00 00 00 00 | |
| 10-… | | Data, *OutputBufferLength* − 16 bytes |

Test 3 starts an F54 (analog / diagnostic) report capture from the interrupt path and waits for it, with a 500 ms timer. The `VendorNN…` limits of `HKLM\SYSTEM\TOUCH\Settings` are the pass/fail criteria (HighRes, Baseline min/max, full baseline of the buttons).  
Input < 8 or output < 20 bytes: `STATUS_UNSUCCESSFUL`. A null buffer: 0xC000090B.

---

### IOCTL 0x480004 — IOCTL_GPIO_WRITE_PINS

This IOCTL is sent by SynapticsTouch.sys to the GPIO controller (through `\Device\RESOURCE_HUB\…`)

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
| 00 | 00 or 01 | Level of the reset line |

`sub_405340`. Sent synchronously (`WdfRequestSend` with timeout). Used by the hardware reset (0, 1 ms, 1).

---

### Interface GUID

NOKIA_TOUCH child Interface Class GUID  
`{3A0AC59A-4D8A-4875-B7EA-304771FF9B9A}`

NOKIA_ENOTOUCHTEST child Interface Class GUID  
`{1ED875DA-D851-42BE-9DFD-527D97178147}`

### Other GUID

Wake gesture custom PnP notification  
`{19CF83DB-B725-402B-BE0B-F51BED9FD984}`

Power setting GUID_CONSOLE_DISPLAY_STATE  
`{6FE69556-704A-47A0-8F24-C28D936FDA47}`

HIDClass device setup class (raw children)  
`{745A17A0-74D3-11D0-B6FE-00A0C90F57DA}`
