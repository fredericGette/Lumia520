## Qcxoadc8930.sys

Qualcomm XO ADC driver (`qcxoadc8930.pdb`, built from `P:\ADC\rel\8.2.1.1\kmdf\XoAdc\arm\Release`).  
It's the ADC driver behind the interface `{10542F20-9718-452A-897A-45785468E57A}` that many drivers use to read named analog channels (`VBATT`, `BATT_THERM`, `PMIC_THERM`…). It drives the XOADC block of the PMIC (PM8038 on the Lumia 520) through the ADC/BTM/sequencer IOCTLs (`0x8002xxxx`) and the MPP IOCTLs (`0x8005xxxx`) of [qcpmic8930.sys](./qcpmic8930.md). It doesn't touch any hardware register itself.  
The whole channel list, the calibration channels, the conversion configurations and the scaling tables come from ACPI methods of its device `\_SB.ADC1` (`QCOM0C00`, `_DEP` `\_SB.PMIC`), read with `IOCTL_ACPI_EVAL_METHOD`. A raw reading is calibrated against the PMIC references, converted to µV, multiplied by the AMUX prescaler, then optionally converted by an ACPI function and/or a lookup table (e.g. mV → °C).  
It also implements the BTM (Battery Temperature Monitor): a request that stays pending until the battery temperature crosses a cool or warm threshold.  
KMDF driver, 141 functions.

There's no named `\Device\` object.  
Symbolic link : `\DosDevices\QCOM_XoAdc` (`\??\QCOM_XoAdc`, created on the PDO when the PMIC interface arrives)  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcxoadc8930` (service name ?)  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0C00\<instance>`  

There's no parameters in the registry.

GUID of the ETW provider:  
`{CE09949B-FC50-4E35-874D-20E4C64C685B}`  
Registered in `DriverEntry` (`McGenEventRegister`). The enabled keywords are cached in `dword_40DAE4`: bit 0 = errors, bit 1 = function trace, bit 2 = conversion results (channel, status and the 5 result values of every reading).  
Every message, error and reading is also kept in an in-memory ring of 100 entries of 40 bytes (`dword_40CB40`, index `dword_40DAE0`): type (0 = start of a reading with the channel, 2 = EOC, 3 = result, 4 = error), interrupt time in µs, channel, 5 result DWORDs, `STRING` message.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{50EC8626-F080-48E2-9076-025BBB44A1A0}` | [qcpmic8930.sys](./qcpmic8930.md#interface-guid) (interface 1) | Found with `IoRegisterPlugPlayNotification` (`EventCategoryDeviceInterfaceChange`, include existing interfaces, callback `AdcEvt_PnpNotifyInterfaceChange` sub_405588), opened with `WdfIoTargetOpen` by name (`DesiredAccess` 0x1F0000). Target of all the PMIC IOCTLs below (`PmicAdcInterface_IoControl` sub_40636C, synchronous, the returned length must equal the output size) |
| ACPI (own device `\_SB.ADC1`) | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) on the default I/O target, see [ACPI configuration](#acpi-configuration) |
| Power framework (PEP) | [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state) | `PoFxRegisterDevice` (1 component) + `PoFxPowerControl` `{3404DAAC-…}`: vote for the XO/CXO clock around every conversion, see [XO vote](#xo-vote) |

Clients of its interface `{10542F20-…}` (IOCTLs `0x8ADC2000` / `0x8ADC2004`): [NokiaEnergyDriver.sys](./nokiaenergydriver.md#adc-channels), [qcbattmngr8930.sys](./qcbattmngr8930.md), [qcepm8930.sys](./qcepm8930.md), [qcpep8930.sys](./qcpep8930.md#thermal-zones), [qcq6ad8930.sys](./qcq6ad8930.md#battery-temperature), [NokiaThermSensorDriver.sys](./nokiathermsensordriver.md), [NokiaDataLoggerDriver.sys](./nokiadataloggerdriver.md). No documented driver sends the BTM IOCTL `0x8ADC2008`.

### Startup

`EvtDriverDeviceAdd` (sub_40571C):
1. PnP/power callbacks: `EvtDevicePrepareHardware` (registers with PoFx once), `EvtDeviceD0Exit` (trace only), `EvtDeviceSelfManagedIoSuspend` / `Restart` (stop / start the BTM queue), `EvtDeviceSurpriseRemoval` (**`KeBugCheckEx(0x14E, 'Qxa0', 0, 0, 0)`**). `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped.
2. Default queue (sequential, power managed) with `EvtIoDeviceControl` and `EvtIoInternalDeviceControl` (same 3 codes, same handlers) and `EvtIoStop`. The queue is created **stopped**: requests wait until the PMIC interface is there.
3. `XoAdc_DeviceInitPrePmic` (sub_404C48): reads the ACPI configuration (sub_4028B8), allocates the calibration table (24 bytes per conversion configuration, tag `qxa1`), creates the EOC interrupt (GENP byte 0 = 1) or a polling timer (GENP byte 0 = 0), and the ADC work item.
4. If the BTM is supported (GENP byte 3 = 1): manual BTM queue (`EvtIoCanceledOnQueue`), `Btm_DeviceInitPrePmic` (sub_403648): reads `BTMP`, creates the cool and warm interrupts, a work item and a spin lock.
5. `IoRegisterPlugPlayNotification` on the PMIC interface `{50EC8626-…}`.

When the PMIC interface arrives, the notification opens it (`PmicAdcInterface_Open` sub_40643C) and queues the work item, which runs `XoAdc_DeviceInitPostPmic` (sub_404AA0):
1. configures each static MPP as analog input (`IOCTL_PM_MPP_CONFIG_ANALOG_INPUT`), if GENP byte 1 = 1;
2. disables then configures the conversion sequencer (`IOCTL_PM_ADC_ENABLE_CONVERSION_SEQUENCER`, `IOCTL_PM_ADC_CONFIG_CONVERSION_SEQUENCER` with the 3 `SEQP` values), if GENP byte 2 = 1;
3. creates and enables the interface `{10542F20-…}`, creates `\??\QCOM_XoAdc`, starts the default queue.

On removal of the PMIC interface the default queue is stopped and purged and the I/O target is deleted.

The calibration isn't done at startup: it runs at the first `IOCTL_ADC_READ` (or BTM request), once.

### Lumia 520 resources

`_CRS` of `\_SB.ADC1`: three `GpioInt` (edge, active high) on `\_SB.PM01`, i.e. PMIC interrupts. They are assigned to the interrupts in creation order:  
| Pin | Interrupt | ISR / DPC |
|-----|-----------|-----------|
| 78 (0x4E) | ADC end of conversion (EOC) | sub_40464C / sub_4046C0: sets the EOC event |
| 72 (0x48) | BTM cool threshold | sub_402FA0 / sub_403010 |
| 73 (0x49) | BTM warm threshold | sub_40312C / sub_40319C |

### ACPI configuration

Each method is evaluated twice with `IOCTL_ACPI_EVAL_METHOD` (0x32C004, input `AeiB` + method name): first with a 20-byte output to get the size (`STATUS_BUFFER_OVERFLOW` expected), then with a buffer of that size. The output signature must be `AeoB` with a non-zero count, otherwise `STATUS_ACPI_INVALID_DATA` (0xC014000F). The parsed data is kept in a global configuration block (`unk_40CAD8`).  
| Method | Read by | Read when | Content |
|--------|---------|-----------|---------|
| `CHAN` | `XoAdcGetChannelConfigFromAcpi` sub_4014C4 | always | Channel list, 60 bytes per channel (tag `qxab`) |
| (tables named in `CHAN`) | `XoAdcPopulateScalingTable` sub_4018B8 | channel field 9 ≠ 0 | Lookup tables `{x, y}` (tag `qxae`) |
| `CBCH` | sub_4014C4 | always | The 4 calibration channels, same format as `CHAN` |
| `GENP` | `XoAdcGetPropsFromAcpi` sub_401C0C | always | General properties |
| `CFGS` | `XoAdcGetConfigsFromAcpi` sub_4021F8 | always | Conversion configurations |
| `MPPS` | `XoAdcGetStaticMppsFromAcpi` sub_401FB8 | GENP byte 1 = 1 | Static MPPs `{mpp, channel}` |
| `SEQP` | `XoAdcGetSequencerPropsFromAcpi` sub_401E10 | GENP byte 2 = 1 | 3 sequencer values |
| `BTMP` | `XoAdcGetBtmPropsFromAcpi` sub_402448 | GENP byte 3 = 1 | BTM properties |
| (functions named in `CHAN`) | `XoAdcEvalFuncFromAcpi` sub_401B1C | at each reading | Input `AeiI` (method + integer), returns an integer |

`GENP` on the Lumia 520 = `{1, 0, 0, 1, 1800, 625, 1250, 1, 0, 0, 0}`:  
| Element | Lumia 520 | Comment |
|---------|-----------|---------|
| 0 | 1 | 1 = EOC interrupt, 0 = poll the conversion status with a timer (1 ms period) |
| 1 | 0 | Static MPPs present (`MPPS`) |
| 2 | 0 | Conversion sequencer present (`SEQP`) |
| 3 | 1 | BTM supported (`BTMP`, IOCTL `0x8ADC2008`) |
| 4 | 1800 | Full-scale reference in mV (`mvVdd`), used by the ratiometric scaling |
| 5 | 625 | mV, used as the span between `vRef1` and `vRef2` by the absolute scaling |
| 6 | 1250 | `vRef2` in mV, used by the absolute scaling |
| 7 | 1 | Channel input (field 2) for which the AMUX prescaler is applied |
| 8 | 0 | PMIC index, first DWORD of every PMIC IOCTL |
| 9, 10 | 0, 0 | MPP parameters of `IOCTL_PM_MPP_CONFIG_I_SINK` when a dynamic MPP is released |

`CFGS` (12 bytes per entry, index = channel field 8):  
| Index | Decimation ratio | Conversion rate | Timeout | Used by |
|-------|------------------|-----------------|---------|---------|
| 0 | 1 | 0 | 1000 | all the other channels |
| 1 | 3 | 0 | 4000 | `XO_THERM_GPS` |
| 2 | 0 | 1 | 500 | `VBATT_GSM` |

The timeout is in ms for the EOC wait (`KeWaitForSingleObject`), and in µs for the first tick of the polling timer.

`BTMP` = `{6, 1, {1000000, 2000000, …, 15000000}}`: BTM channel index 6 (`BATT_THERM`), BTM parameter 1 (first byte of `IOCTL_PM_ADC_BTM_ENABLE`), and 15 measurement intervals (µs ?, 1 s … 15 s). The interval of a BTM request is the first one ≥ the requested value (the last one otherwise); its index is the second byte of `IOCTL_PM_ADC_BTM_ENABLE`.

#### Channel record

Each `CHAN` / `CBCH` entry is a package of 13 elements, stored in a 60-byte record:  
| Element | Offset | Comment |
|---------|--------|---------|
| 0 | +0x00 | Name (`STRING`), compared **case-sensitively** by `IOCTL_ADC_GET_CHANNEL` |
| 1 | +0x08 | AMUX channel (`IOCTL_PM_ADC_CONFIG_MUX`, `IOCTL_PM_ADC_GET_PRESCALAR`). AMUX 15: 0.5 ms delay before the conversion |
| 2 | +0x0C | XOADC input (`IOCTL_PM_ADC_SET_INPUT`): 0 = XO_THERM, 1 = normal (prescaled), 2 = ratiometric, 3 = ground, 4 = VDD reference (like `amux_ip_rsv` of the Linux `pm8xxx-adc` driver ?) |
| 3 | +0x10 | Premux output (`IOCTL_PM_ADC_SET_PREMUX_OUTPUT`) |
| 4 | +0x14 | Premux channel (`IOCTL_PM_ADC_CONFIG_PREMUX`), 0xFFFF = use the AMUX channel instead |
| 5, 6 | +0x18, +0x1C | Dynamic MPP and its analog channel (`IOCTL_PM_MPP_CONFIG_ANALOG_INPUT` before, `IOCTL_PM_MPP_CONFIG_I_SINK` after the conversion), 0xFFFF = none |
| 7 | +0x20 | 1 = use the conversion sequencer |
| 8 | +0x24 | Conversion configuration (`CFGS` index) |
| 9 | +0x28 | Name of the lookup table method (4CC), 0 = none. The table pointer is stored at +0x2C |
| 10 | +0x30 | Name of the conversion function method (4CC), 0 = none |
| 11 | +0x34 | Argument of the function: 0 = mV, 1 = ratio, 2 = µV, 3 = raw code |
| 12 | +0x38 | Scaling: 0 = ratiometric (to `mvVdd`), 1 = absolute (two-point, `vRef1` / `vRef2`) |

#### Lumia 520 channels

`CHAN` of `\_SB.ADC1`. The channel id returned by `IOCTL_ADC_GET_CHANNEL` is the index:  
| Id | Name | AMUX | Input | Premux / MPP | Cfg | Conversion | Scaling | Unit of `04-07` |
|----|------|------|-------|--------------|-----|------------|---------|-----------------|
| 0 | `VCOIN` | 0 | 1 | — | 0 | — | absolute | mV |
| 1 | `VBATT` | 1 | 1 | — | 0 | — | absolute | mV (×3 prescaler) |
| 2 | `VCHG` | 2 | 1 | — | 0 | — | absolute | mV |
| 3 | `ICHG` | 3 | 1 | — | 0 | — | absolute | mV |
| 4 | `VPH_PWR` | 4 | 1 | — | 0 | — | absolute | mV |
| 5 | (empty) | 5 | 1 | — | 0 | — | absolute | Can't be found by name |
| 6 | `BATT_THERM` | 8 | 2 | — | 0 | table `BTTB` | ratiometric | °C |
| 7 | `BATT_THERM2` | 6 | 1 | premux 6, output 1, MPP 3 / 1 | 0 | table `BTTB` | absolute | °C |
| 8 | `BATT_ID` | 9 | 2 | — | 0 | — | ratiometric | mV |
| 9 | `BATT_RID` | 9 | 2 | — | 0 | `BRID` (µV) | ratiometric | kΩ (100 kΩ pull-up to 1.8 V) |
| 10 | `USB_IN` | 10 | 1 | — | 0 | — | absolute | mV |
| 11 | `PMIC_THERM` | 11 | 1 | — | 0 | `PTCF` (µV) | absolute | m°C (µV / 2 − 273160) |
| 12 | `CHG_TEMP` | 14 | 1 | — | 0 | `PTCF` (µV) | absolute | m°C |
| 13 | `PA_THERM` | 6 | 1 | premux 3, output 1 | 0 | table `PATB` | ratiometric | °C |
| 14 | `PA_THERM1` | 6 | 1 | premux 4, output 1 | 0 | table `PATB` | absolute | °C |
| 15 | `XO_THERM` | 15 | 0 | — | 0 | `XOCF` (ratio) + table `XTTB` | ratiometric | °C × 1024 ? |
| 16 | `XO_THERM_GPS` | 15 | 0 | — | 1 | `XOCF` (ratio) + table `XTTB` | ratiometric | °C × 1024 ? |
| 17 | `VBATT_GSM` | 1 | 1 | — | 2 | — | absolute | mV |
| 18 | `VREF` | 15 | 4 | — | 0 | — | ratiometric | mV |
| 19 | `VGND` | 15 | 3 | — | 0 | — | ratiometric | mV |
| 20 | `V0P625` | 12 | 1 | — | 0 | — | absolute | mV |
| 21 | `V1P25` | 13 | 1 | — | 0 | — | absolute | mV |
| 22 | `BOM_DET` | 6 | 1 | premux 6, output 1, MPP 2 / 1 | 0 | `BDCF` (mV) | absolute | BOM id (1–9) |

`CBCH` (calibration channels, in this order): `mvVdd` (AMUX 15, input 4), `Ground` (AMUX 15, input 3), `vRef1` (AMUX 12 = 0.625 V), `vRef2` (AMUX 13 = 1.25 V).  
`BTTB`: 12 points `{mV, °C}` from {1680, −30} to {331, 80}. `PATB`: 34 points from {1760, −40} to {44, 125}.

### Conversion

`XoAdc_AdcConversion` (sub_404584) → `XoAdc_PerformConversionScaledResult` (sub_404460) → `XoAdc_PerformConversionRawResult` (sub_4042AC):
1. If not done yet, `XoAdc_Calibrate` (sub_404868): for each `CFGS` configuration, converts the 4 `CBCH` channels and stores their raw codes (`Ground`, `mvVdd`, `vRef1`, `vRef2`) and the ratios of `vRef1` / `vRef2`. Any failure fails the reading.
2. [XO vote](#xo-vote) on.
3. `XoAdc_StartConversion` (sub_403E1C): dynamic MPP (+1 ms), `ADC_SET_ENABLE(1)`, mux or premux + premux output, `ADC_SET_INPUT`, `ADC_SET_DECIMATION_RATIO`, `ADC_SET_CONVERSION_RATE`, sequencer enable if needed, `ADC_REQUEST_CONVERSION`.
4. Waits for the EOC event (timeout of the configuration). If `ADC_GET_CONVERSION_STATUS` isn't 1 yet, waits once more ("Warning: conversion is still pending").
5. `XoAdc_ReadAdc` (sub_404038): `ADC_READ_DATA` (raw code), sequencer flags, `ADC_SET_ENABLE(0)`, releases the dynamic MPP.
6. XO vote off.
7. `XoAdc_ProcessConversionResult` (sub_404FDC):
   * ratio = 0xFFFF × (raw − `Ground`) / (`mvVdd` − `Ground`) (`XoAdc_ScaleResult` sub_403F8C), clamped to 0 / 0xFFFF;
   * ratiometric: µV = 1000 × (1800 × ratio / 0xFFFF);  
     absolute: µV = (100000 × 1250 + (ratio − ratio(`vRef2`)) × (100000 × 625 / (ratio(`vRef2`) − ratio(`vRef1`)))) / 100, negative → 0;
   * if the channel input = GENP element 7 (1): µV × denominator / numerator of `IOCTL_PM_ADC_GET_PRESCALAR` (e.g. ×3 for `VBATT`);
   * mV = µV / 1000;
   * conversion function: the ACPI method is evaluated with the value selected by element 11, the result replaces the mV value;
   * lookup table: linear interpolation (`AdcMapLinearInt32toInt32` sub_406214), clamped to the first / last point, replaces the value.

#### XO vote

sub_402740: `PoFxPowerControl(handle, {3404DAAC-8E2C-41E4-8458-3158E5AD442B}, {0, P-state} (8 bytes), output 12 bytes)`, i.e. [Set P-state](./qcpep8930.md#3404daac-set-p-state) of component 0: P-state 0 before the conversion ("Voting for xo/cxo"), P-state 1 after. In the DSDT, P-state 0 of `\_SB.ADC1` votes for `PM_VREG_RESOURCE_ID_CXO_CLOCK`. If the result `04-07` isn't 0 it's returned; if `00-03` isn't 3 (synchronous), the driver waits up to 5 s for its `PowerControlCallback` (sub_4026D0, same GUID, 12-byte result with `00-03` = 2).

---

### IOCTL 0x8ADC2000 — IOCTL_ADC_GET_CHANNEL

This IOCTL is processed by Qcxoadc8930.sys (also as internal IOCTL)

| Property | Value |
|----------|-------|
| Device | 0x8ADC |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ADC_GET_CHANNEL | strlen + 1 (any size with a NUL) | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | e.g. `VBATT\0` | ASCII channel name, must contain a NUL within the input length |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 1 = found, 0 = unknown name |
| 04-07 | e.g. 01 00 00 00 | Channel id (index in `CHAN`, see [Lumia 520 channels](#lumia-520-channels)), FF FF FF FF when not found |

Handlers: sub_405F68 → `XoAdc_GetChannel` (sub_404E94). The name is compared case-sensitively (`RtlEqualString`) with the non-empty `CHAN` names.  
No NUL in the input → `STATUS_INVALID_PARAMETER` (0xC000000D); output length ≠ 8 → `STATUS_INVALID_PARAMETER`. An **unknown name still returns `STATUS_SUCCESS`** with `00-03` = 0 and `04-07` = −1 (callers that don't check `00-03`, like [qcepm8930.sys](./qcepm8930.md), would then read channel 0xFFFFFFFF, which fails).

---

### IOCTL 0x8ADC2004 — IOCTL_ADC_READ

This IOCTL is processed by Qcxoadc8930.sys (also as internal IOCTL)

| Property | Value |
|----------|-------|
| Device | 0x8ADC |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ADC_READ | 4 | 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 01 00 00 00 | Channel id from `IOCTL_ADC_GET_CHANNEL` |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Status: 1 = valid, 0 = invalid (read failed, bad scaling or conversion function), 2 = sequencer timeout, 3 = sequencer FIFO not empty |
| 04-07 | ? | Physical value: mV, or the result of the conversion function / lookup table (°C, m°C, kΩ…, see [Lumia 520 channels](#lumia-520-channels)). Signed |
| 08-0B | ? | Calibrated ratio 0…0xFFFF between `Ground` and `mvVdd` |
| 0C-0F | ? | µV after the prescaler (before the conversion function) |
| 10-13 | e.g. `48 79 00 00` | Raw ADC code (`IOCTL_PM_ADC_READ_DATA`), used by [NokiaEnergyDriver.sys](./nokiaenergydriver.md#capacity) and [qcbattmngr8930.sys](./qcbattmngr8930.md) for `V0P625` / `V1P25` |

Handlers: sub_405E08 → `XoAdc_AdcConversion` (sub_404584), see [Conversion](#conversion). The reading is synchronous (the request waits for the end of the conversion).  
Input length ≠ 4 or output length ≠ 20 → `STATUS_INVALID_PARAMETER` (0xC000000D). Channel id ≥ number of channels, PMIC not open, XO vote or conversion failure → `STATUS_UNSUCCESSFUL` (0xC0000001). `BytesReturned` = 20.

---

### IOCTL 0x8ADC2008 — IOCTL_ADC_BTM_MONITOR

This IOCTL is processed by Qcxoadc8930.sys (also as internal IOCTL)

| Property | Value |
|----------|-------|
| Device | 0x8ADC |
| Function | 0x802 (2050) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_ADC_BTM_MONITOR (`ADC_BTM_MONITOR` in the trace strings) | 16 | 24 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Cool threshold, in the unit of the BTM channel (°C for `BATT_THERM`), converted back to a raw code through the lookup table (`AdcMapY2XLinearInt32toInt32` sub_4062C0) |
| 04-07 | ? | Warm threshold, same unit. Must be > cool threshold when both are monitored |
| 08-0B | e.g. 40 42 0F 00 | Measurement interval (µs ?), rounded up to a `BTMP` interval |
| 0C-0F | 00 00 00 00 | Monitor: 0 = cool and warm, 1 = cool only (warm threshold set to 0), 2 = warm only (cool threshold set to 0xFFFF). Other → invalid |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-13 | ? | When a threshold is crossed: the BTM reading, same 5 fields as `IOCTL_ADC_READ` (status, value, ratio, µV, raw code from `IOCTL_PM_ADC_BTM_READ_DATA`) |
| 14-17 | 00 00 00 00 | 0 = threshold crossed, 1 = a BTM request is already pending, 2 = invalid request, 3 = BTM not supported |

Handlers: sub_405BC0 → `Btm_StartMonitoring` (sub_4032B8). Input length ≠ 16 or output length ≠ 24 → `STATUS_INVALID_PARAMETER`. The errors of `14-17` (1, 2, 3) complete the request at once with `STATUS_SUCCESS` and 24 bytes.  
Otherwise the driver calibrates if needed, disables the BTM, waits (up to 50 × 1 ms) for `IOCTL_PM_ADC_BTM_GET_CONVERSION_STATUS` = 1 (`STATUS_INVALID_DEVICE_STATE` 0xC0000184 if it never comes), programs the thresholds, the mux / premux and the input of the BTM channel, enables the BTM with the interval index and requests a conversion. The request is then **pending** in the manual BTM queue.  
The cool or warm PMIC interrupt (DPC sub_403010 / sub_40319C) retrieves it and the work item (sub_402C28) reads `IOCTL_PM_ADC_BTM_READ_DATA`, disables the BTM, scales the result and completes it with `STATUS_SUCCESS` and 24 bytes. The output doesn't say which threshold was crossed (compare `04-07` with the thresholds).  
Cancelling the request disables the BTM and completes it with `STATUS_CANCELLED` (0xC0000120).

Any other code → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### PMIC IOCTLs

All are sent to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8002xxxx--adc--btm--ccadc) (interface `{50EC8626-…}`). The input always starts with the PMIC index (GENP element 8, 0); the output ends with the PMIC error code, which must be 0. The PMIC library names come from the error strings of the driver.  
| IOCTL | Name (qcpmic8930) | PMIC library name | In | Out |
|-------|-------------------|-------------------|----|-----|
| 0x80020FA0 | IOCTL_PM_ADC_READ_DATA | pm_xoadc_read_data | 4 | 8 |
| 0x80020FA4 | IOCTL_PM_ADC_CONFIG_MUX | pm_xoadc_config_mux | 8 | 4 |
| 0x80020FA8 | IOCTL_PM_ADC_SET_ENABLE | pm_xoadc_set_enable | 8 | 4 |
| 0x80020FAC | IOCTL_PM_ADC_REQUEST_CONVERSION | pm_xoadc_request_conversion | 4 | 4 |
| 0x80020FB0 | IOCTL_PM_ADC_GET_CONVERSION_STATUS | pm_xoadc_get_conversion_status | 4 | 8 |
| 0x80020FB4 | IOCTL_PM_ADC_SET_INPUT | pm_xoadc_set_input | 8 | 4 |
| 0x80020FB8 | IOCTL_PM_ADC_SET_DECIMATION_RATIO | pm_xoadc_set_decimation_ratio | 8 | 4 |
| 0x80020FBC | IOCTL_PM_ADC_SET_CONVERSION_RATE | pm_xoadc_set_conversion_rate | 8 | 4 |
| 0x80020FC0 | IOCTL_PM_ADC_GET_PRESCALAR | pm_adc_get_prescalar | 8 | 12 |
| 0x80020FC4 | IOCTL_PM_ADC_CONFIG_PREMUX | pm_xoadc_config_premux | 8 | 4 |
| 0x80020FC8 | IOCTL_PM_ADC_CONFIG_CONVERSION_SEQUENCER | pm_seq_config | 16 | 4 |
| 0x80020FCC | IOCTL_PM_ADC_ENABLE_CONVERSION_SEQUENCER | pm_seq_enable | 8 | 4 |
| 0x80020FD0 | IOCTL_PM_ADC_BTM_ENABLE | pm_xoadc_btm_enable | 8 | 4 |
| 0x80020FD4 | IOCTL_PM_ADC_BTM_DISABLE | pm_xoadc_btm_disable | 4 | 4 |
| 0x80020FD8 | IOCTL_PM_ADC_BTM_READ_DATA | pm_xoadc_btm_read_data | 4 | 8 |
| 0x80020FDC | IOCTL_PM_ADC_BTM_SET_WARM_THRESHOLD | pm_xoadc_btm_set_warm_threshold | 8 | 4 |
| 0x80020FE0 | IOCTL_PM_ADC_BTM_SET_COOL_THRESHOLD | pm_xoadc_btm_set_cool_threshold | 8 | 4 |
| 0x80020FE4 | IOCTL_PM_ADC_BTM_GET_CONVERSION_STATUS | (error string says `pm_xoadc_btm_read_data`) | 4 | 8 |
| 0x80020FE8 | IOCTL_PM_ADC_BTM_REQUEST_CONVERSION | pm_xoadc_btm_request_conversion | 4 | 4 |
| 0x80020FEC | IOCTL_PM_ADC_SET_PREMUX_OUTPUT | pm_xoadc_config_premux_output | 8 | 4 |
| 0x80020FF0 | IOCTL_PM_ADC_BTM_CONFIG_MUX | pm_xoadc_btm_config_mux | 8 | 4 |
| 0x80020FF4 | IOCTL_PM_ADC_BTM_SET_INPUT | pm_xoadc_btm_set_input | 8 | 4 |
| 0x80020FF8 | IOCTL_PM_READ_SEQUENCER_TIMEOUT_FLAG | pm_seq_status_timeout | 4 | 8 |
| 0x80020FFC | IOCTL_PM_READ_SEQUENCER_FIFO_FLAG | pm_seq_status_fifo_not_empty | 4 | 8 |
| 0x80021028 | IOCTL_PM_BTM_CONFIG_PREMUX | pm_xoadc_btm_config_premux | 8 | 4 |
| 0x8002102C | IOCTL_PM_BTM_SET_PREMUX_OUTPUT | pm_xoadc_btm_config_premux_output | 8 | 4 |
| 0x80050FAC | IOCTL_PM_MPP_CONFIG_ANALOG_INPUT | pm_mpp_config_analog_input | 12 | 4 |
| 0x80050FB4 | IOCTL_PM_MPP_CONFIG_I_SINK | pm_mpp_config_i_sink | 16 | 4 |

The CCADC IOCTLs (`0x80021000`…) aren't used: the coulomb counter belongs to [qcbms8930.sys](./qcbms8930.md).

---

### Interface GUID

ADC interface (created by qcxoadc8930.sys when the PMIC interface arrives)  
`{10542F20-9718-452A-897A-45785468E57A}`

### Other GUID

PMIC ADC interface of [qcpmic8930.sys](./qcpmic8930.md#interface-guid) (consumed)  
`{50EC8626-F080-48E2-9076-025BBB44A1A0}`

PoFx power control: set P-state ([qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state))  
`{3404DAAC-8E2C-41E4-8458-3158E5AD442B}`

### Other remarks

* Pool tags: `qxa0` (driver), `qxa1` (calibration table), `qxaa`…`qxam` (ACPI buffers and parsed tables).
* The output of the PMIC IOCTLs is never checked beyond the error code and the returned length.
* The custom conversion functions run an ACPI method at every reading (`PMIC_THERM`, `BATT_RID`, `XO_THERM`, `BOM_DET`).
