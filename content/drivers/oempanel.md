## Oempanel.sys

Nokia Panel Driver (service `NOKIA_PANEL`, ACPI device `ACPI\NOKIA_PANEL\0`, KMDF, build `E:\build_e\subtask\BE09332C_98\output\display\fre\oempanel.pdb`, "Jan 28 2015").  
It is the display "brain" of the Nokia phones: it knows the panel models, builds the MIPI DCS command sequences (power on/off, brightness, CABC, gamma/colour) that the Qualcomm display driver `qcdxkm8930.sys` sends to the panel, and it computes the backlight level from the ambient light sensor (auto-brightness, Lux→Nit tables), the user settings and the battery/power-save state.  
It also drives a few GPIOs (through the resource hub), the capacitive key LEDs (through `hwnled`) and, on some panels only, the PMIC WLED backlight block of [qcpmic8930.sys](./qcpmic8930.md). The colour calibration is read from `C:\Windows\System32\DRIVERS\ColorData.bin`.  
Most of the work is done by a dedicated system thread: IOCTLs, timers, registry notifications and power events are posted to it as internal "messages" (`process_ioctl` → `process_type`, 0x416C14) and the caller waits for the result.

There's no named `\Device\` object and no symbolic link: the device is opened through its device interface, e.g. `\\?\ACPI#NOKIA_PANEL#0#{0d4a3f63-0d08-49a1-b91c-c60576894174}` (see [Interface GUID](#interface-guid)).

> [!NOTE]
> Until the display driver has registered itself with [IOCTL 0x83214000](#ioctl-0x83214000--display-driver-registration), every other IOCTL fails with `0xC00000A3` STATUS_DEVICE_NOT_READY.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\NOKIA_PANEL`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\NOKIA_PANEL\0`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0081`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NOKIA_PANEL\Parameters\Settings` (opened by `settings` 0x417C34, read by `ReadPanelSettingsFromRegistry` 0x423AF4 and `RegReadAlcRegistries`). The first six values are written back with their default when they are missing (`WdfRegistryAssignULong`). Values observed on a Lumia 520 unless stated otherwise:  
| Registry value | value | comment |
|----------------|-------|---------|
| EsdEnabled | 1 | REG_DWORD, default 1. Periodic ESD check of the panel (reset/re-init when it fails) |
| EsdInterval | 0x1388 | REG_DWORD, default 3000. ESD check period in ms |
| EsdFailLimit | 3 | REG_DWORD, default 3 |
| IsUpsideDown | 0 | REG_DWORD, default 0 |
| HwPlatform | 1 | REG_DWORD, default 0. Device context `+0x38AC` |
| Flags | 0 | REG_DWORD, default 0. Device context `+0x38B0`. Bit 0: ? (tested in `_sub_402A2C`). Bit 1: ? (tested in `_sub_408DD0`). Bit 2: drive the backlight current through the PMIC WLED (`IOCTL_PM_WLED_*`, see [IOCTLs sent to qcpmic8930.sys](#ioctl-0x80140fa0--ioctl_pm_wled_config)) |
| LIGHT_SRELimitLow/Med/High_Vendor_0/1 | e.g. `0xE3004E20`, `0x88B8`, `0xC350` | Sunlight Readability Enhancement lux thresholds, per panel vendor ? |
| LIGHT_CAbcLevel_Vendor_0/1 | 0 | CABC level per panel vendor ? |
| LIGHT_GlassDampingCompensationFactor | 0x64 | Percent applied to the ALS reading ? |
| LIGHT_LedBoostBrightness_1 | 0x16D | ? |
| LIGHT_LedGroup0_Pct … LIGHT_LedGroup3_Pct | 0 | Intensity of the 4 key-LED groups. All 0 on a Lumia 520 (no lit keys), so nothing is sent to `hwnled` |
| LIGHT_LedBackButton, LIGHT_LedWinButton, LIGHT_LedSearchButton | 0xF | Key → LED group mapping ? |
| LIGHT_AssertiveDisplayEnabled | (absent) | Assertive Display ? |
| AD_RegsInUse, AD_MaxIterations, AD_TFilterControl, AD_StrengthLimit, AD_CalibrationA…D | e.g. 0, 0x40, 5, 0x80, 0x12, 0x5F, 0, 0 | Assertive Display parameters ? |
| LIGHT_LuxToNitD_LuxIn0…11, LIGHT_LuxToNitD_NitOut0…11 | 0 → 12 nit … 100000 lux → 800 nit | Auto-brightness curve ("D" = day ?), 12 points |
| LIGHT_LuxToNitK_LuxIn0…3, LIGHT_LuxToNitK_NitOut0…3 | 0 → 10 nit … | Second curve ("K" = ?), 4 points |
| DevicePanelCalibParam | 0xFFFFFF | Panel calibration ? |

Other registry keys read (and, for the first five, watched with `ZwNotifyChangeKey` by `sub_423D40`):  
| Key | Values | Comment |
|-----|--------|---------|
| `HKLM\System\ControlSet001\services\powernotif\Estimations` | ? | Battery estimations |
| `HKLM\Software\Microsoft\Autobrightness` | `ABSManualBrightness` (3 = low, 4 = medium, 5 = high), `ABSMonitorControl` (0 = manual, 1 = auto), `ABSAutoMaxBrightness` | Brightness setting of the Settings app |
| `HKLM\Software\OEM\Nokia\Display` | `PowerSaveState`, `BatteryChargePercent` | |
| `HKLM\Software\OEM\Nokia\BrightnessInterface` | `BrightnessPct` | |
| `HKLM\Software\OEM\Nokia\Display\ColorAndLight` | `UserSettingSreEnabled`, `UserSettingBsmDimmingEnabled`, `UserSettingKeyLightsEnabled`, `UserSettingFingerFilterEnabled`, `UserSettingDarkConditionBrightness`, `UserSettingWhitePoint`, `UserSettingColorSaturation` | Lumia "Display settings" |
| `HKLM\Software\OEM\Nokia\Display\MotionClarity` | `WindowSize`, `Framecount`, `Overdrive` ? | |
| `HKLM\Software\OEM\Nokia\Display\Lpm` | `OPR_Low`, `OPR_Med` | Low Power Mode (glance screen) |
| `HKLM\Software\OEM\Nokia\lpm` | `Mode` | |
| `HKLM\SOFTWARE\OEM\Nokia\Touch\Improved` | `Enabled` | |
| `HKLM\Software\Microsoft\ManufacturingOS` ? | `ManufacturingMode` | |
| `HKLM\System\ControlSet001\services\Sensors\ALS\TestInterface`, `…\Sensors\PS\TestInterface` | `Enable`, `Value` | Written by `IOCTL_SET_REGISTRY_VALUE2` |
| `HKLM\Software\OEM\Nokia\Display` ? | `AidRegistryExist`, `AidRegistry1_1` … `AidRegistry3_9` | ? |

There's no ETW provider: the driver only prints with `DbgPrint` (assertions are printed as `e_DISP_CRASH 1;Assert…` by `Nokia_Panel_Drv_Assert` 0x418C3C).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| — | qcdxkm8930.sys | Display miniport. Registers itself with [IOCTL 0x83214000](#ioctl-0x83214000--display-driver-registration) and exchanges function-pointer tables: oempanel sends its DCS command sequences through them (`call_qcdxkm8930` 0x405FAC) |
| Interface `{5B9DF049-70D3-4698-8E48-85B26C1AA59F}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC. `IOCTL_PM_WLED_CONFIG`, `IOCTL_PM_WLED_ENABLE`, `IOCTL_PM_WLED_CONFIG_ADDITIONAL_PARAM` (see below). Opened on interface arrival (`plugPlayCallbackDeviceInterfaceChange_qcpmic8930` 0x417828) |
| Interface `{6B2A25E2-AAF5-482C-99A5-6205CDCC176A}` (`ACPI\QCOM0D50\0`) | hwnled | Hardware-notification LED driver, used for the key LEDs (IOCTL 0x228000) |
| `\Device\RESOURCE_HUB\<connection id>` | GPIO controller | Two GPIO lines from the ACPI resources (IOCTL 0x480004 `IOCTL_GPIO_WRITE_PINS`) |
| Interface `{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}` | ? ("TEST_PROXY") | Opened with `ZwOpenFile`; 2-byte records are written to it with `ZwWriteFile` (see [Test proxy](#test-proxy)) |
| `\BaseNamedObjects\AlsListenerOnOffEvent` | — | Notification event set when the ALS listening starts/stops (`IoCreateNotificationEvent`) |

Power setting callback (`PoRegisterPowerSettingCallback`, `my_PowerSettingCallback` 0x41750C) on `GUID_CONSOLE_DISPLAY_STATE` `{6FE69556-704A-47A0-8F24-C28D936FDA47}`: the 4-byte value (0 = off, 1 = on, 2 = dimmed) is posted to the worker thread as message 0x2C.

### Start-up

1. `DriverEntry` (`sub_426000`) → `WdfDriverCreate` with `EvtDriverDeviceAdd` = `sub_423560` and `EvtDriverUnload` = `sub_423800`.
2. `sub_423570` (device add): PnP/power callbacks (`EvtDeviceD0Entry` 0x40650C, `EvtDeviceD0Exit` 0x406574, `EvtDevicePrepareHardware` = `sub_4237E0`, `EvtDeviceReleaseHardware` 0x405FA0), an in-caller-context callback (`receive_ioctl_from_wdf_DispathToInCallerContextCallback` 0x406724), `WdfDeviceCreate`, a 0x3938-byte device context, `ReadPanelSettingsFromRegistry`, the 3 device interfaces, the worker thread, timers and work items (`call_call_writeFile_processIoctl` 0x416854), the query interface (`sub_4234C0`), the power setting callback, power capabilities / S0 idle settings, and the default queue (`sub_423834`, `EvtIoDeviceControl` 0x406974).
3. `EvtDevicePrepareHardware` (`sub_423954`): walks the translated resources and keeps the connection resources (type 0x84) of class 1 / type 2 (GPIO I/O, up to 16) at device context `+0x08 + 8*n`. GPIO connection #1 is opened as I/O target `+0x88` and connection #2 as `+0x8C` (`IoRoutine` 0x4084F8 builds `\Device\RESOURCE_HUB\` + 16-digit hex connection id). Connection #0 is kept but not opened here.

### GPIO lines

Both are written with `GpioWritePin` (0x4238E8), which sends `IOCTL_GPIO_WRITE_PINS` (0x480004) with a 1-byte input buffer:  
| Context | Connection | Use |
|---------|------------|-----|
| `+0x88` | #1 | Panel power/reset sequence (`lcdPanelSwitch_OFF`, `type_0x01`), and `IOCTL_UNKNOWN_7` (`write_pins_IoTarget_GPIO2` 0x409180, the value is **inverted**) |
| `+0x8C` | #2 | Written by `ComputeBacklightLevel` (0x403098) with 1 when the brightness mode has bits `0xC0` set (High Brightness Mode ? `ConfHbmGpio`), cleared on panel off. Only used when `Flags` bit 2 is clear |

### Backlight

`ComputeBacklightLevel` (0x403098) computes a 0–255 level (ALS lux → nit curves, user settings, minimum `ctx+0xDFD`, dimming, LPM). Then:
* the level is sent to the panel by `call_CreateDisplaySequence_18` (0x41147C) as MIPI DCS commands: `0x51` (set display brightness), `0x53` = `0x24` or `0x2C` (display control: backlight control on, backlight on, + dimming), `0x55` (CABC mode) and the vendor command `0xD7`. The panel controller then dims the backlight (on a Lumia 520 the PM8038 WLED is never touched at run time);
* if `Flags` bit 2 is set, `UpdateWledCurrent` (0x417BD0) also sets the PMIC WLED string current through `sendIoctlQcpmic8930_LedCurrentMilliAmp` (0x41789C);
* otherwise the HBM GPIO (`+0x8C`) is updated.

### Panels

The panel model id is at device context `+0xD70`. `findDisplayCodeName` (0x4146CC) gives the code names; many functions (`call_CreateDisplaySequence_*`) switch on it:  
| Id | Code name |
|----|-----------|
| 176 (0xB0) | Jessica |
| 177 (0xB1) | Wendy |
| 179 (0xB3) | Teisko |
| 180 (0xB4) | Wavehouse |
| 182 (0xB6) | Herwood |
| 186 (0xBA) | Watson |
| 188 (0xBC) | Jasmine |
| 191 (0xBF) | Suvi |
| 192 (0xC0) | Race |
| 193 (0xC1) | Aurora |
| 194 (0xC2) | Tanya |
| 195 (0xC3) | Barclay |
| 196 (0xC4) | Smokey |
| 198 (0xC6) | Jaywalk |
| 202 (0xCA) | Tara |
| 204 (0xCC) | Barbie |
| other | "UNKNOWN display" |

Panel vendor (`find_vendor` 0x404734, byte at `+0x13C4`): `0xC1` = LgDisplay, `0xE3` = CMI, `0xFE` = Samsung, other = "Unkown vendor".  
On a Lumia 520 `IOCTL_DISPLAY_ID_QUERY` returns `C0 85 E3 00` (ID `0xE385C0`): model 0xC0 = 192 **Race**, vendor 0xE3 **CMI** (confirmed by `IOCTL_PRINT_PANEL_INFO`: `ID: 0xE385C0, CMI - Race`). Race is not one of the panels whose power-on sequence programs the PMIC WLED (198, 204).

### Panel info

Excerpt of the `IOCTL_PRINT_PANEL_INFO` report on a Lumia 520 (`wp81powertool -q oempanel`, auto-brightness off, brightness "high"):
```
Ver: Jan 28 2015, 15:58:07. Runtime 12 mins. Rel

DISPLAY:
 * ID: 0xE385C0, CMI - Race
 * Size: 480x800 pxl, 52x86 mm
 * ESD resets: 0, reasons 0x0, 146 cnt
 * Refresh avg:   16629 us & 1900 vsyncs
 * RRparam 0xffffff Updates 3057
 * Disp ON: 12 mins (=731 secs), 1 cnt
 * DSI errors: 0x0 (0x0 0x0), 0 cnt

LPM:
 * Settings: 0-0, 0lux, 0%, 0 sec
 * Backlight: 0/255, 0lux, 0 gets
 * Content: 0 OPR, 150 OPRlow 400 OPRmed

LIGHTS:
 * Illuminance: 1 lux, change cnt: 1, 1
 * Brightness: 255/255, 100% = 325 nits
 * SRE: param 0x0, 100% (setting ON)
 * HBM: param 0x0, GPIO 0x0
 * Keyleds: 0%, err 0x0, sett 1, 2 cnt
 * Proximity: Not detected
 * UseCases: 0x0, ABS cnt 1 5%, Man, 1 cnt
 * Reg IF scaler: 100%, 0 cnt
 * Dark end setting: 50
 * Transitions: Display ready, Keys ready
 * Service errs: 0x0, ret 0x0 0x0, 1 instance
 * Scalers: userS 120% glass 100%, disp 100%
 * Conf (nit): l/m/h=70/180/325, max 325
 * Conf HBM (nit): l/m/h=0/0/0 (GPIO=365)
 * Conf SRE (lux): l/m/h=20000/35000/50000 (20000/35000/50000)
 * Conf keys: 1=0%, 2=0%, 3=0%, 4=0%

COLOR MGMT:
 * Gfx: Sat 110% (110%), WP 100.00% (100.00%)
 * ADisp registry: Disabled
 * ADisp: Inactive, 0 luxes, 0 light-%
 * ADisp: Disp: streL 255, A:18, B:95, C:0, D:0
 * ILut: red[0] 0x0, green 0x0, blue 0x0
 * Matrix: [0][0] 0x0
 * OLut: red[0].start   0, offset 9056, gain 0 1
           green[0].start 0, offset 7195, gain 0 1
           blue[0].start  0, offset 8906, gain 0 1

MISC:
 * Thermal: 100 %, 0 cnt
 * BattSaver: Inactive (setting ON 0) 0 cnt
 * Batt: 100 %, charger is not attached, 0 cnt
 * AID: 0 Current Level 0
```
(followed by three 36-entry "AID curve" tables, all 0).

Notes on this output:
* "Conf (nit) l/m/h=70/180/325" are the nit targets of the low/medium/high manual brightness settings (`ABSManualBrightness` 3/4/5), max 325 nit (same value as `IOCTL_DISPLAY_SIZE_QUERY`).
* "Conf SRE (lux)" matches the `LIGHT_SRELimit*` registry values (0x4E20 = 20000, 0x88B8 = 35000, 0xC350 = 50000).
* "ADisp: … A:18, B:95, C:0, D:0" matches `AD_CalibrationA…D` (0x12, 0x5F, 0, 0); Assertive Display is disabled.
* "HBM … GPIO 0x0" and "Conf HBM (nit) 0/0/0": High Brightness Mode is not configured, so the GPIO `+0x8C` stays low.
* "Keyleds 0%", "Conf keys 0%": no key LEDs (`LIGHT_LedGroupN_Pct` = 0).

### ColorData.bin

`load_colordata_bin` (0x404D2C) opens `\??\C:\Windows\System32\DRIVERS\ColorData.bin`, reads a 20-byte header (magic `0x6E646264`, "dbdn" ?) then 12-byte records, and looks up the entry of the current panel (`+0xD70`, `+0xD74`). Format otherwise ?

### Test proxy

`writeFile` (0x4175E0), run from a work item (`EvtWdfWorkitem_calledBy_WorkItem1`), opens the first interface `{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}` (`TestGetDeviceName`; DbgPrint prefix `TEST_PROXY`) and writes the 2-byte records `00 01` then, 100 ms later, `00 00` (a pulse). It then waits up to 5 s on a semaphore, retries once, and pulses again. Purpose ?

### Query interface

`sub_4234C0` registers a query interface `{ECBE47A8-C498-4BB9-BD70-E867E0940D22}` (`WdfDeviceAddQueryInterface`, Size 0x1C, Version 1). Its only callback (`sub_4065E0`) posts message 0x1B with one value to the worker thread (display transition ?). Consumer ?

---

### IOCTL list

Every IOCTL is **METHOD_BUFFERED** / **FILE_ANY_ACCESS**, device type `0x8321` (except `0x83203E84`). They are processed by `call_HandleNokiaIoCtlRequest` (0x406A6C) → `HandleNokiaIoCtlRequest` (0x407730), which checks minimum lengths and posts a message to the worker thread. Names and buffer layouts come from the wp81powertool notes (`wp81powertool/src/oempanel.cpp`); `IOCTL_UNKNOWN_n` are placeholders.

NTSTATUS returned by `HandleNokiaIoCtlRequest`:  
| Value | Comment |
|-------|---------|
| 0xC0000010 STATUS_INVALID_DEVICE_REQUEST | Unknown code |
| 0xC00000A3 STATUS_DEVICE_NOT_READY | Display driver not registered, or LCD off (e.g. `IOCTL_DISPLAY_ID_QUERY` → Win32 error 21 `ERROR_NOT_READY`) |
| 0xC0000206 STATUS_INVALID_BUFFER_SIZE, 0xC0000023 STATUS_BUFFER_TOO_SMALL, 0xC000000D STATUS_INVALID_PARAMETER | Bad length / content |

| IOCTL | Fn | Name | In | Out | Message | Comment |
|-------|----|------|----|-----|---------|---------|
| 0x83203E84 | 0xFA1 | IOCTL_RESTART_DEVICE | ≥8 | ≥20 | 0x80000009 | LCD off then on |
| 0x83214000 | 0x000 | (display driver registration) | 32 | 0 | — | Kernel mode only, see below |
| 0x83212004 | 0x801 | IOCTL_UNKNOWN_6 | ≥1 | ≥4 | 0x81000001 | `00` stop / `01` start timer 1 (ESD check ?); output = input byte |
| 0x83212008 | 0x802 | IOCTL_SET_USECASES_0 | 4 | 0 | 0x80000005 | Brightness use case: 1 = one level darker, 3 = low, 4 = medium, 5 = high (re-read from the registry) |
| 0x8321200C | 0x803 | IOCTL_DISPLAY_ID_QUERY | 0 | 4 | 0x80000007 | Panel id, e.g. `C0 85 E3 00`. Fails when the LCD is off |
| 0x83212010 | 0x804 | IOCTL_UNKNOWN_12 | 28 | 0 | 0x80000003 / 0x80000004 | Byte 0 ≥ 1 → partial-display/LPM on (0x80000003), else off (0x80000004) ? |
| 0x83212014 | 0x805 | IOCTL_DISPLAY_SIZE_QUERY | 0 | 16 | 0x0C | e.g. `00 00 00 00 E0 01 20 03 34 00 56 00 45 01 00 00`: 480×800 px, 52×86 mm, max 325 nit |
| 0x83212018 | 0x806 | IOCTL_UNKNOWN_9 | 4 | 12 | 0x0E / 0x8000000D | |
| 0x8321201C | 0x807 | IOCTL_UNKNOWN_13 | 12 | 0 | 0x8000000F | Partial display area ? |
| 0x83212020 | 0x808 | IOCTL_LCD_POWER_ON_OFF | 4 | 4 | 0x01 / 0x02 | `01` on, `00` off. Output `01` if the state changed |
| 0x83212024 | 0x809 | IOCTL_UNKNOWN_4A | 2 | 0 | 0x81000004 | |
| 0x83212028 | 0x80A | IOCTL_UNKNOWN_5A | 2 | >0 | 0x81000005 | |
| 0x8321202C | 0x80B | IOCTL_ALS_ON_OFF_LISTENING | 1 | 0 | 0x18 | `01` start / `00` stop listening to the ALS |
| 0x83212030 | 0x80C | IOCTL_LCD_STATUS_QUERY_2 | 0 | 1 | 0x14 | `01` LCD on |
| 0x83212034 | 0x80D | IOCTL_AUTO_BRIGHTNESS_STATUS_QUERY | 0 | 1 | 0x14 | `01` when auto-brightness on and LCD on |
| 0x83212038 | 0x80E | IOCTL_LIGHT_ADAPTATION_CONTROL_SETTINGS_QUERY | 0 | 28 | 0x40000029 | `LightAdaptationControlSettings`, size checked by an assertion |
| 0x8321203C | 0x80F | IOCTL_SET_ALS_AND_PS | 24 | 0 | 0x16 | Lux ×1000 at `08` and `0C` (max 2000000), proximity at `10`. Only when auto-brightness is on |
| 0x83212040 | 0x810 | IOCTL_SET_AUTO_BRIGHTNESS | 1 | 0 | 0x19 | |
| 0x83212044 | 0x811 | IOCTL_ALS_ON_OFF_LISTENING_QUERY | 0 | 1 | 0x14 | |
| 0x83212048 | 0x812 | IOCTL_UNKNOWN_14 | 12 | 0 | 0x01000006 | |
| 0x8321204C | 0x813 | IOCTL_UNKNOWN_15 | 12 | ? | — | Service error flags (`ServiceErrs`) |
| 0x83212050 | 0x814 | IOCTL_GET_PANEL_INFO_SIZE | 0 | 4 | — | Size of the text below |
| 0x83212054 | 0x815 | IOCTL_PRINT_PANEL_INFO | 0 | n | — | Text report (`display_infos` 0x406BE8), see [Panel info](#panel-info) |
| 0x83212058 | 0x816 | IOCTL_RESET_REFRESH_AVG | 0 | 0 | 0x30 | |
| 0x8321205C | 0x817 | IOCTL_GET_FPS | 0 | 4 | — | Frames per 100 s, e.g. `71 17 00 00` = 6001 |
| 0x83212060 | 0x818 | IOCTL_LIGHT_STATUS_QUERY | 0 | 72 | 0x1D | `LightAdaptationStatusQuery` (lux, auto, proximity, brightness 0–255, nits, SRE, HBM, key LEDs…) |
| 0x83212064 | 0x819 | IOCTL_SET_REGISTRY_VALUE2 | 12 | 0 | — | Writes the ALS/PS `TestInterface` values |
| 0x83212068 | 0x81A | IOCTL_SET_REGISTRY_VALUE | 8 | 0 | — | `00-03` key index 0–0xB, `04-07` value (see below) |
| 0x8321206C | 0x81B | IOCTL_UNKNOWN_4C | 2 | 0 | 0x81000004 | |
| 0x83212070 | 0x81C | IOCTL_UNKNOWN_4B | 2 | 0 | 0x81000004 | |
| 0x83212074 | 0x81D | IOCTL_UNKNOWN_4D | 2 | 0 | 0x81000004 | |
| 0x83212078 | 0x81E | IOCTL_UNKNOWN_5B | 2 | >0 | 0x81000005 | |
| 0x8321207C | 0x81F | IOCTL_UNKNOWN_2 | 0 | 2080 | — | Calibration data ? (`copy_deviceContext_to_buffer2080`) |
| 0x83212080 | 0x820 | IOCTL_UNKNOWN_16 | 2080 | 0 | — | Calibration data ? |
| 0x83212084 | 0x821 | IOCTL_LCD_STATUS_QUERY | 0 | 2 | 0x1E | `01 00` LCD on |
| 0x83212088 | 0x822 | IOCTL_SET_BATTERY_CHARGER_ATTACHED | 1 | 0 | 0x1F | |
| 0x8321208C | 0x823 | IOCTL_SET_BATTERY_CHARGE | 4 | 0 | 0x15 | Battery charge percent |
| 0x83212094 | 0x825 | IOCTL_PIXEL_QUERY | 4 | 4 | 0x8100000C | `00-01` Y, `02-03` X → pixel colour ? (`0x0BADBAD0` on error) |
| 0x83212098 | 0x826 | IOCTL_UNKNOWN_7 | 4 | 0 | 0x8100000D | Writes GPIO `+0x88` (inverted) |
| 0x8321209C | 0x827 | IOCTL_LPM_STATUS_QUERY | 0 | 32 | 0x20 | Low Power Mode status |
| 0x832120A0 | 0x828 | IOCTL_UNKNOWN_10 | 8 | 0 | 0x26 | White point / saturation ? |
| 0x832120A4 | 0x829 | IOCTL_UNKNOWN_17 | 124 | 0 | 0x27 | |
| 0x832120A8 | 0x82A | IOCTL_UNKNOWN_8 | n×16 | 0 | 0x28 | |
| 0x832120AC | 0x82B | IOCTL_UNKNOWN_18 | 20 | 0 | 0x8100000E | Does nothing ? |
| 0x832120B0 | 0x82C | IOCTL_DO_NOTHING | 0 | 4 | — | Returns `00 00 00 00` |

Key index of `IOCTL_SET_REGISTRY_VALUE` (`set_registry_values` 0x418860):  
| Index | Key | Value |
|-------|-----|-------|
| 0x0 | `Software\OEM\Nokia\Display` | PowerSaveState |
| 0x1 | `Software\OEM\Nokia\Display` | BatteryChargePercent |
| 0x2 | `Software\OEM\Nokia\Display\ColorAndLight` | UserSettingSreEnabled |
| 0x3 | `Software\OEM\Nokia\Display\ColorAndLight` | UserSettingBsmDimmingEnabled |
| 0x4 | `Software\OEM\Nokia\Display\ColorAndLight` | UserSettingKeyLightsEnabled |
| 0x5 | `Software\OEM\Nokia\Display\ColorAndLight` | UserSettingFingerFilterEnabled |
| 0x6 | `Software\OEM\Nokia\BrightnessInterface` | BrightnessPct |
| 0x7 | `Software\OEM\Nokia\Display\ColorAndLight` | UserSettingDarkConditionBrightness |
| 0x8 | `Software\Microsoft\Autobrightness` | ABSManualBrightness, ABSMonitorControl |
| 0x9 | `Software\OEM\Nokia\Display\ColorAndLight` | UserSettingColorSaturation |
| 0xA | `Software\OEM\Nokia\Display\ColorAndLight` | UserSettingWhitePoint |
| 0xB | `Software\OEM\Nokia\lpm` | nokia_lpm_mode |

---

### IOCTL 0x83214000 — display driver registration

This IOCTL is processed by Oempanel.sys (presumably sent by qcdxkm8930.sys)

| Property | Value |
|----------|-------|
| Device | 0x8321 |
| Function | 0x0 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBufferLength | OutputBufferLength |
|------|-------------------|--------------------|
| ? | 32 | 0 |

`call_HandleNokiaIoCtlRequest` accepts it with code `0x83214000` or `0x4000`, before the device is ready. The input buffer is a table of 8 function pointers of the display driver, copied to device context `+0x94` (`init_deviceContext_32bytes` 0x405760; any other length → `0xC000000D`). Entry `+0x04` (`ctx+0x98`) sends a command sequence to the panel, entry `+0x0C` (`ctx+0xA0`) returns its status. oempanel then calls entry 0 with its own callback table (version `0x02010005`, 6 callbacks: `sub_408A44`, `sub_408D68`, `sub_408A64`, `sub_408AC8`, `sub_408D80`, `query_process_thread_interruptTime`) and fills a second table at `ctx+0xC8` (`call_qcdxkm8930`, `call_qcdxkm8930_2`, `sub_406184`, `sub_4061CC`, …).

> [!NOTE]
> The buffer contains kernel function pointers: this IOCTL can only come from a kernel-mode driver.

---

### IOCTL 0x83203E84 — IOCTL_RESTART_DEVICE

This IOCTL is processed by Oempanel.sys

| Property | Value |
|----------|-------|
| Device | 0x8320 |
| Function | 0xFA1 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBufferLength | OutputBufferLength |
|------|-------------------|--------------------|
| IOCTL_RESTART_DEVICE | 8 | 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 1 or 2, otherwise `0xC0000011` |
| 04-07 | 00 00 00 00 | Must be 0, otherwise `STATUS_UNSUCCESSFUL` |

Outputbuffer (examples):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | 00 00 00 00 00 00 00 00 | ? |
| 08-0B | 01 00 00 00 | ? |
| 0C-0F | 0C 00 00 00 | ? |
| 10-13 | 58 BA 17 00 | Duration ? |

Shorter buffers → `STATUS_UNSUCCESSFUL`; NULL buffers → `0xC000090B`. Message 0x80000009: the LCD is switched off then on.

---

### IOCTL 0x80140FA0 — IOCTL_PM_WLED_CONFIG

This IOCTL is sent by Oempanel.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8014xxxx--wled-display-backlight)

| Property | Value |
|----------|-------|
| Device | 0x8014 |
| Function | 0x3E8 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_WLED_CONFIG | interface `{5B9DF049-70D3-4698-8E48-85B26C1AA59F}` | 56 | 4 |

Sent only if the qcpmic8930 target is open (`ctx+0x12B4`), from two places:
* `sendIoctlQcpmic8930_LedCurrentMilliAmp` (0x41789C), when `Flags` bit 2 is set: on panel on (`type_0x80000003`, `type_0x80000004`) and on each backlight update (`UpdateWledCurrent`). Sent for string 0, then for the panel's string (`ctx+0xE07`), each retried once on failure.
* `_sub_417A8C`, from the panel power-on sequence (`call_CreateDisplaySequence_16`) of panels 198 (Jaywalk) and 204 (Barbie) only, **whatever `Flags`**, followed by `IOCTL_PM_WLED_CONFIG_ADDITIONAL_PARAM`.

Inputbuffer (field meanings from the qcpmic8930 page):  
| Bytes | `sendIoctl…` | `_sub_417A8C` | Comment |
|-------|--------------|---------------|---------|
| 00-03 | 00 00 00 00 | 00 00 00 00 | PMIC index |
| 04-07 | 0, then `ctx+0xE07` | 0, then `ctx+0xE07` | WLED string |
| 08 | 01 | 01 | `0x25A` flag |
| 09 | 01 | 01 | `0x25A` flag |
| 0C-0F | current, clamped to 1–25 | `ctx+0xE02` | Full-scale current in mA |
| 10-13 | FF 0F 00 00 | FF 0F 00 00 | Brightness, always maximum |
| 14 | 00 | 00 | |
| 15 | 01 | 01 | |
| 16 | 01 | 01 | Not used by qcpmic8930 |
| 17-23 | 0 | `18`=2, `1C`=3, others 0 | `0x265` fields |
| 24-27 | 01 00 00 00 | 01 00 00 00 | OVP ? |
| 28-2B | 05 00 00 00 | 04 00 00 00 | Boost current limit ? |
| 2C-2F | 00 00 00 00 | 00 00 00 00 | |
| 30-33 | 03 00 00 00 | 03 00 00 00 | |
| 34-37 | 02 00 00 00 | 02 00 00 00 | |

The backlight is then dimmed by changing the string current, not the WLED brightness.

### IOCTL 0x80140FA4 — IOCTL_PM_WLED_ENABLE

This IOCTL is sent by Oempanel.sys to [qcpmic8930.sys](./qcpmic8930.md)

8-byte input: `00-03` = 0 (PMIC index), `04` = enable. Sent with 1 at the end of the panel power-on sequence (`call_CreateDisplaySequence_16`) and with 0 in `lcdPanelSwitch_OFF`, both only when `Flags` bit 2 is set and the qcpmic8930 target is open.

### IOCTL 0x80140FAC — IOCTL_PM_WLED_CONFIG_ADDITIONAL_PARAM

This IOCTL is sent by Oempanel.sys to [qcpmic8930.sys](./qcpmic8930.md)

Sent by `_sub_417A8C` (panels 198 and 204). 56-byte input: `10` = 7, `1C` = 1, `20` = 2, `24` = 3, `28` = 0xF, `30` = 3, all other bytes 0.

---

### IOCTL 0x228000 — HWN set state ?

This IOCTL is sent by Oempanel.sys to hwnled

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x0 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

Sent by `EvtWdfWorkitem_sendHwnLedConfiguration` (0x4088FC) to the interface `{6B2A25E2-AAF5-482C-99A5-6205CDCC176A}`, only when at least one `LIGHT_LedGroupN_Pct` is not 0 (`create_IoTarget_hwnled` 0x4086D8). The buffer looks like `HWN_HEADER` / `HWN_SETTINGS` of `hwn.h` ?:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 12 + 36×n | Size |
| 04-07 | 01 00 00 00 | Version ? |
| 08-0B | n | Number of LED groups with a non-zero percentage |
| 0C + 36×i | | Group: `+00` LED group index (0–3), `+04` = 1 (type ?), `+08` = 100, `+10` = 100 when `ctx+0x38AC` (`HwPlatform`) = 1, other settings 0 |

---

### IOCTL 0x480004 — IOCTL_GPIO_WRITE_PINS

This IOCTL is sent by Oempanel.sys to the GPIO controller (through `\Device\RESOURCE_HUB\…`)

| Property | Value |
|----------|-------|
| Device | 0x48 |
| Function | 0x1 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

1-byte input buffer: pin value 0 or 1 (`GpioWritePin` 0x4238E8). See [GPIO lines](#gpio-lines).

---

### Interface GUID

Nokia panel interface (used by user-mode clients for the `0x8321xxxx` IOCTLs)  
`{0D4A3F63-0D08-49A1-B91C-C60576894174}`

Second device interface (purpose ?)  
`{6CEEEBB6-C8A9-484F-A4E2-64D7E01AA333}`

Third device interface, created after the power settings (purpose ?)  
`{CE15E056-96CB-4F7D-A6B0-8C485D29D84E}`

### Other GUID

Query interface (`WdfDeviceAddQueryInterface`)  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`

qcpmic8930 interface (target of the `IOCTL_PM_WLED_*` controls)  
`{5B9DF049-70D3-4698-8E48-85B26C1AA59F}`

hwnled interface  
`{6B2A25E2-AAF5-482C-99A5-6205CDCC176A}`

"TEST_PROXY" interface  
`{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}`

`GUID_DEVICE_INTERFACE_ARRIVAL` (PnP notifications)  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`

`GUID_CONSOLE_DISPLAY_STATE` (power setting callback)  
`{6FE69556-704A-47A0-8F24-C28D936FDA47}`
