## Qcmbhcgpio8930.sys

Qualcomm GPIO-based MBHC (Multi-Button Headset Control) driver: headset jack detection by a GPIO interrupt, and headset type / button detection done by the WCD93xx audio codec.  
It is a variant of [qcmbhc8930.sys](./qcmbhc8930.md) with the same `mbhc_ioctl` entry point, the same state machine (`START`, `NO_PLUG`, `CHECK_PLUG`, `AV_PLUG`, `INVALID_PLUG`, `NBTN_PRESSED`, `BTN_PRESSED`, plus a factory test state `FTM`) and the same codec access over the **SLIMbus**. The difference is the plug insertion/removal detection: it comes from the jack-detect GPIO interrupt of `\_SB.MBGP` (pin 43), debounced by a timer, instead of the codec insertion interrupt. The GPIOs are described by the ACPI method `GPNF`.  
The audio driver [qc8x60aud.sys](./qc8x60aud.md) uses it when its registry value `GpioBasedHeadsetDetection` ≠ 0 (default 1, so this is the headset detection driver used on the Lumia 520). Jack and button events are reported to the client through a callback.  
It is a KMDF driver. PDB path `E:\build_e\subtask\E05A4CC0_98\output\audio\fre\qcmbhcgpio8930.pdb`. There are no log messages (no ETW, no `DbgPrint`). Pool tags `abmq`, `cbmq`, `dbmq`, `ebmq`, `ibmq`, `jbmq`, `kbmq`, `lbmq`, `mbmq`, WDF memory tags `Abmq`…`Nbmq`.

ACPI device `\_SB.MBGP` (`_HID` `QCOM2149`, `_UID` 1), with `_DEP` on `\_SB.PEP0`, `\_SB.PMIC`, `\_SB.ACDB`, `\_SB.SLM1`, `\_SB.TICO` and `\_SB.ACHW`. [qc8x60aud.sys](./qc8x60aud.md) (`\_SB.QCRT`) has a `_DEP` on `\_SB.MBGP`.

There's no named `\Device\` object and no symbolic link.  
The driver registers the device interface `{093C3754-B2D1-4AC7-B93E-A8FD62FDF7C3}` (see [Interface GUID](#interface-guid)). It is enabled only once the 4 peer interfaces below are present.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM2149\1`  

There's no parameters in the registry.

GUID of the ETW provider:  
None.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}` | SLIMbus driver (`\_SB.SLM1`, QCOM0190) ? | Codec register read/write, codec logical address, and a "keep awake" vote ?. See [IOCTL 0x85B52xxx](#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus) |
| interface `{C383F1A1-0E73-47D9-A5B2-214CEC4EE713}` | WCD codec interrupt handler (`\_SB.TICO` ?) | Register / enable / disable / clear the codec interrupts. See [IOCTL 0x5001200C…0x5001201C](#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts) |
| interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` | audio codec driver (`\_SB.ACHW` ?) | Audio "resource manager" (`rm_audio_sr_ioctl`). See [IOCTL 0x50012048](#ioctl-0x50012048--rm_audio_sr_ioctl) |
| interface `{4EE2204F-14FF-4139-9853-0DA54D6849D5}` | [qcacdb8930.sys](./qcacdb8930.md) | ACDB. Opened for each read only to get the `acdb_ioctl` entry point ([IOCTL 0x50022400](#ioctl-0x50022400)), then closed |
| ACPI node of the device | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) of `BFSZ` and `GPNF`, sent to the device's own I/O target. See [ACPI](#acpi-bfsz-and-gpnf) |
| `\Device\RESOURCE_HUB\<connection id>` | GPIO controller ([qcgpio.sys](./qcgpio.md)) | The `GpioIo` resources. `IOCTL_GPIO_WRITE_PINS` / `IOCTL_GPIO_READ_PINS`. See [GPIO](#gpio) |
| GPIO interrupt | GPIO controller ([qcgpio.sys](./qcgpio.md)) | The `GpioInt` resource (pin 43): jack detection. See [Jack detection](#jack-detection) |

The 4 interfaces are watched with `IoRegisterPlugPlayNotification` (`EvtWdfDevicePrepareHardware` `sub_401920` → `sub_401C70`, callback `sub_401D34`), then found with `IoGetDeviceInterfaces` (first symbolic link) and opened with `WdfIoTargetOpen` by name with `FILE_ALL_ACCESS` when needed. The removal of any of them stops MBHC (`mbhc_ioctl(2)`), unregisters the power framework device, frees everything and disables the device interface (`sub_401A80`).

### Start sequence

1. `DriverEntry`: `WdfDriverCreate` only.
2. `EvtDriverDeviceAdd` (`sub_412054`): PnP callbacks (`EvtDevicePrepareHardware`, `EvtDeviceReleaseHardware`), `WdfDeviceCreate`, device interface `{093C3754-…}`, one sequential default queue (not power managed) with `EvtIoDeviceControl`, `WdfInterruptCreate` for the GPIO interrupt (`sub_401768`), then `WdfDeviceSetStaticStopRemove(FALSE)`.
3. `EvtDevicePrepareHardware` (`sub_401920`): stores every `CmResourceTypeInterrupt` resource and every `CmResourceTypeConnection` resource of class GPIO / type IO in a table, in resource order (`dword_410200` + 16·i: `+8` connection id low, `+0xC` connection id high, `+0x10` valid flag), then registers the 4 interface notifications.
4. When the 4 interfaces are present (`sub_4019FC`): registers the power framework component (see [Power framework](#power-framework)) and enables the device interface.
5. The real initialisation (`sub_403D0C`) is **lazy**: it runs on the first IOCTL received:
   1. Allocates the context (0xC0 bytes) and 2 mutexes.
   2. SLIMbus: creates the I/O target and opens the interface `{88EEFAB5-…}`.
   3. Gets the codec logical address from its enumeration address with [IOCTL 0x85B52000](#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus). It tries up to 4 addresses (table `off_40F264`): `00 01 10 00 17 02`, `00 01 60 00 17 02`, `00 01 00 00 17 02`, `00 01 70 00 17 02` (manufacturer id 0x0217 = Qualcomm, 4 WCD93xx part ids ?).
   4. Initialises the 9 states (`sub_404608`).
   5. Opens the interrupt handler interface `{C383F1A1-…}` and registers the codec interrupt callback `sub_4063D4` with [IOCTL 0x5001200C](#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts).
   6. Sets the GPIO interrupt callback (`sub_406DEC`) and creates the debounce timer (`sub_402DD4`: `KTIMER` + DPC + work item, callback `sub_406ED0`).
   7. Evaluates `BFSZ` and `GPNF` ([ACPI](#acpi-bfsz-and-gpnf)) and builds the GPIO function table (`sub_4079BC`).

   On failure the deinit sequence runs (`sub_403FE4`) and the IOCTL completes with `STATUS_DEVICE_NOT_READY` (0xC00000A3).

### Jack detection

The `GpioInt` of `\_SB.MBGP` (pin 43, Edge, ActiveBoth, Shared, Wake, debounce 500 ms) is the jack detection. ISR `sub_4017E8` → DPC `sub_401808` → work item → `sub_406DEC`. If the detection state (`byte_41007E`) is 1, 2 or 3, it (re)starts the debounce timer and sets the detection state to 2. The delay is `MBHC_TinsCompl` from the ACDB (`rem` config at +0x0A), 300 ms by default.  
When the timer expires (`sub_406ED0`), the detection state becomes 3, and the current state of the state machine receives the internal event 0x1B (plug change) between the SLIMbus votes [0x85B5240C / 0x85B52410](#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus). The states read the jack-detect GPIO (function 3, see [GPIO](#gpio)) to tell an insertion from a removal. The value read is compared with the level given in `GPNF` (1 on the Lumia 520): equal seems to mean "no plug" ?, e.g. in `FTM` a value of 0 starts the plug classification and any other value reports a removal. `sub_406FB4` repeats the read (100 ms apart, up to 5 s) while the codec measures the microphone line, and stops when the value becomes equal to the level.

Then, like [qcmbhc8930.sys](./qcmbhc8930.md), the codec MBHC block (registers accessed over the SLIMbus) is used to measure the microphone line, classify the accessory (`CHECK_PLUG`, `sub_40C8B4`), optionally measure the headset impedance (`sub_408A48`, when `MBHC_HeadSetImpDet` = 1 in the ACDB), and poll the headset buttons.

### Codec registers

Same access as [qcmbhc8930.sys](./qcmbhc8930.md#codec-registers): SLIMbus value elements, element address = register address + 0x800, 1 byte, at the logical address of the codec (`sub_40AAC4` read, `sub_40AB1C` set/clear bits, `sub_40AC60` write a field, `sub_40ABC8` test bits). A read or write is retried up to 5 times (10 ms apart) on failure.  
At `MBHC_CMD_START` the ADC is calibrated (`sub_406714`): the zero and mic-bias readings are stored in `word_4102B0`/`word_4102B2` (DCE) and `word_4102B4`/`word_4102B6` (STA), and all the thresholds are scaled in mV against them with a full scale of 2100.

### ACDB

The thresholds are read from the ACDB with `acdb_ioctl(0x1126B, in, 16, out, 4)` (the generic "get" command, see [qcacdb8930.sys](./qcacdb8930.md)). Input: module id 0x112E5 (MBHC), parameter id, size, kernel pointer to the result (same layout as [qcmbhc8930.sys](./qcmbhc8930.md#acdb)).  
| Parameter id | Size | Function | Use |
|--------------|------|----------|-----|
| 0x112E6 | 16 | `sub_402130` (via `sub_40BC1C`) | General config |
| 0x112E7 | 20 | `sub_402190` (via `sub_40BC4C`) | Removal config. The word at +0x0A (`MBHC_TinsCompl`) is the jack debounce delay in ms |
| 0x112E8 | 16 | `sub_4021F0` (via `sub_40BC7C`) | Plug type config (no-mic / headset voltage limits) |
| 0x112E9 | 98 | `sub_402250` (via `sub_40BCAC`) | Button config: number of buttons (byte at +0x0D), poll and bounce times (+0x10, +0x12), then the low/high voltage of each button |
| 0x112EA | 56 | `sub_402338` (via `sub_40BCDC`) | Impedance config. Byte at +0: impedance detection enable (`MBHC_HeadSetImpDet`) |

Note: the button and impedance configs are larger than the ones read by [qcmbhc8930.sys](./qcmbhc8930.md#acdb) (84 and 48 bytes).  
If the ACDB can't be read, hard-coded defaults are used (`sub_408150`): 3 buttons, debounce 300 ms, and fixed thresholds.

### ACPI BFSZ and GPNF

At the initialisation (`sub_401398`), the driver evaluates two methods of its ACPI node with `IOCTL_ACPI_EVAL_METHOD` (0x32C004, input `ACPI_EVAL_INPUT_BUFFER` signature `AeiB`, output signature `AeoB`):
* `BFSZ` (`sub_4010EC`): returns the size of the output buffer to use for `GPNF`. Lumia 520: 0x800. If the call fails, 2048 is used.
* `GPNF` (`sub_401240` → `sub_40119C`): returns a package of packages of 3 integers `{ resource index, function, level }`, stored in a table (`dword_410370`, 24 bytes per entry).

The driver accesses its GPIOs by **function** (`sub_401008`: function → resource index of the table built at `EvtDevicePrepareHardware`). An access to a function not listed in `GPNF` fails with 0xE3 and is ignored.  
`GPNF` on the Lumia 520:  
| Resource index | Function | Level | `_CRS` resource (in resource order ?) | Use in the driver |
|----------------|----------|-------|---------------------------------------|-------------------|
| 1 | 2 | 1 | `GpioInt` pin 43 | Not accessed by function (the interrupt is handled by WDF) |
| 2 | 3 | 1 | `GpioIo` pin 43, Shared, PullNone | Jack detect: read, compared with the level (equal = no plug ?) |
| 3 | 4 | 0 | `GpioIo` pin 43, PullDown | Read in `CHECK_PLUG` when the microphone line is not classified: value = level → accessory type 5/6 instead of 1/2 (ANC headset detection, like `GPIO_ANC_HEADSET_DET` of qcmbhc8930 ?) |

The first `_CRS` resource (`GpioIo` pin 51, PullDown, resource index 0) isn't listed in `GPNF` and is never used.  
Functions 0 and 1 are used by the driver but not defined on the Lumia 520, so these writes always fail:
* function 0: written at `MBHC_CMD_START` (`sub_407F64`), like `GPIO_AUDIO_VID_SEL` of qcmbhc8930 ?
* function 1: written at `MBHC_CMD_START`, toggled in `CHECK_PLUG` when a headset with microphone is detected (US/EU plug swap, like `GPIO_US_EURO_SEL` of qcmbhc8930 ?), and set by the FTM commands 2 and 3.

### GPIO

Each access opens `\Device\RESOURCE_HUB\<connection id as 16 hex digits>` (`sub_403334` → `sub_4034C4` write, `sub_403408` → `sub_40365C` read), sends one synchronous request and closes the target. Write: `FILE_GENERIC_WRITE`, `IOCTL_GPIO_WRITE_PINS` (0x480004) with 1 byte. Read: `FILE_GENERIC_READ`, `IOCTL_GPIO_READ_PINS` (0x480000) with 1 byte.

### Power framework

`sub_403154` registers 1 PoFx component with `PoFxRegisterDevice` and starts the power management when the 4 peer interfaces are present. The component is activated (`PoFxActivateComponent`) at `MBHC_CMD_START` and set idle (`PoFxIdleComponent`) at `MBHC_CMD_STOP` (`sub_403804`).  
| Property | Value |
|----------|-------|
| Component id | `{C7071231-FBF6-2376-A6E1-9B86E0DA2363}` (same as [qcmbhc8930.sys](./qcmbhc8930.md#power-framework)) |
| F0 | latency 0, residency 0, nominal power 500 |
| F1 | latency 2, residency 5, nominal power 50 |

The PoFx callbacks only complete the requests.

---

### IOCTL 0x500A2800 — get the `mbhc_ioctl` entry point

This IOCTL is processed by Qcmbhcgpio8930.sys (`EvtWdfIoQueueIoDeviceControl` `sub_401B98`). It is sent by [qc8x60aud.sys](./qc8x60aud.md#ioctl-0x500a2800--get-headset-detection-entry-point) to the interface `{093C3754-…}`.

| Property | Value |
|----------|-------|
| Device | 0x500A |
| Function | 0xA00 (2560) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get `mbhc_ioctl` entry point | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 04 00 00 00 | Size of the result (not checked) |
| 04-07 | ? | Kernel pointer to a dword that receives the address of `mbhc_ioctl` (`sub_4040D4`) |

The first IOCTL received (any code) runs the [lazy initialisation](#start-sequence) first.  
NTSTATUS returned:  
| Value | Comment |
|-------|---------|
| 0x00000000 | Entry point written |
| 0xC00000A3 STATUS_DEVICE_NOT_READY | The initialisation failed |
| 0xC000000D STATUS_INVALID_PARAMETER | Other IOCTL code, no input buffer, or input size ≠ 8 |
| 0xC022001C | The pointer at offset 04 is NULL |

> [!NOTE]
> The input carries a raw kernel pointer that is written without validation: the IOCTL is only usable from kernel mode.

#### `mbhc_ioctl(command, buffer, size)`

Entry point returned by IOCTL 0x500A2800 (`sub_4040D4`). Returns 0 on success, 1 on failure, 0x100 if the mutexes don't exist, 0x1000 for an unknown command (0 or ≥ 0x10). Same commands 1–4 as [qcmbhc8930.sys](./qcmbhc8930.md#mbhc_ioctlcommand-buffer-size), plus command 5.  
| Command | Name | Buffer | Action |
|---------|------|--------|--------|
| 1 | MBHC_CMD_START | - | Fails if not initialised. Activates the PoFx component, sends `rm_audio_sr_init` (cmd 0x01) and the clock request (cmd 0x02) to the codec ([IOCTL 0x50012048](#ioctl-0x50012048--rm_audio_sr_ioctl)), writes the GPIO functions 0 and 1, then with the SLIMbus vote held: ADC calibration, ACDB thresholds, codec init and threshold programming, and the current state handler is called with the command. If the handler returns 3, a jack debounce is started as if the GPIO interrupt had fired; otherwise the clock is released (cmd 0x02 with 0) |
| 2 | MBHC_CMD_STOP | - | Releases the codec clock (cmd 0x02 with 0), sends `rm_audio_sr_deinit` (cmd 0x10), sets the PoFx component idle, and resets the state to `START` |
| 3 | MBHC_CMD_SET_CB | 8 bytes `{ callback, context }` | Registers the client callback. Fails if not initialised or size ≠ 8 |
| 4 | MBHC_CMD_FTM | - | Factory test mode: switches to the `FTM` state (only once started). The `FTM` handler then disables all the codec interrupts |
| 5 | FTM sub-command | 4 bytes: value 0–3 | The value is passed to the current state handler. In the `FTM` state (`sub_40C460`): see below. Fails if the buffer is NULL |

FTM sub-commands (command 5, state `FTM`):  
| Value | Action | Event sent |
|-------|--------|------------|
| 0 | Enables the codec interrupt 0x40 and sets bit 6 of the codec registers 164 and 168 (`sub_406600`) | 7 when that interrupt arrives |
| 1 | Takes the clock, measures the microphone line twice (`sub_407ADC`), releases the clock | 8, result 1 if a reading deviates by 233 or more from 2100 mV-scale |
| 2 | Writes 0 to GPIO function 1 | 9, result 1 if the write failed |
| 3 | Writes 1 to GPIO function 1 | 10, result 1 if the write failed |

[qc8x60aud.sys](./qc8x60aud.md#ioctl-0x900030000x90003048--headset--voice-test-controls) sends command 4 for IOCTL 0x90003000 and command 5 with value 0–3 for IOCTLs 0x90003008–0x90003018.  
In the `FTM` state the jack event 0x1B still works: it reads the jack GPIO twice (100 ms apart), waits 1 s, then either (value 0) takes the clock, runs `CHECK_PLUG` and comes back to `FTM`, or (other value) releases the clock, resets the codec MBHC block and sends event 2.

Callback: `callback(event, payload, 32, context)`:  
| Event | Name | Sent by |
|-------|------|---------|
| 1 | MBHC_PLUG_INSERT | `CHECK_PLUG` (`sub_40C8B4`) |
| 2 | MBHC_PLUG_REMOVE | `sub_40AD38`, `sub_40BD0C`, `FTM` |
| 3 | MBHC_BUTTON_PRESS | `NBTN_PRESSED` (`sub_40AE20`) |
| 4 | MBHC_BUTTON_RELEASE | `NBTN_PRESSED` |
| 6 | MBHC_BUTTON_PRESS_RELEASE | `NBTN_PRESSED` |
| 7 | FTM: test interrupt received | `FTM` |
| 8 | FTM: microphone line check | `FTM` |
| 9 / 10 | FTM: GPIO function 1 written 0 / 1 | `FTM` |
| 11 / 12 | Sent just before event 1 when the classification is 2: 12 when the US/EU swap GPIO was written (or isn't defined, as on the Lumia 520), 11 when the write failed | `CHECK_PLUG` |

Payload of events 1, 11 and 12 (32 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Accessory type, 1 to 6 (see below) |
| 04-07 | FF FF 00 00 | Button id (0xFFFF for plug events) |
| 08-0B | FF FF 00 00 | Press duration (0xFFFF for plug events) |
| 0C-0F | ? | 1 = ?, 0 otherwise |
| 10-13 | ? | Impedance value 1 (`dword_4102D0`) ? |
| 14-17 | ? | Impedance value 2 (`dword_4102D4`) ? |
| 18-1B | ? | Impedance class (`dword_4102DC`, 1 or 2) ? |
| 1C-1F | ? | ? |

Accessory type, from the microphone line classification (`sub_40510C`, result 0, 1 or 2) and the impedance class:  
| Classification | Impedance class 1 | Otherwise |
|----------------|-------------------|-----------|
| 2 | 1, then the US/EU swap GPIO is toggled. When GPIO function 1 isn't defined (Lumia 520) the type becomes **4** | 2 (same) |
| 0 | 3 | 4 |
| 1, GPIO function 4 = its `GPNF` level | 5 | 6 |
| 1, otherwise | 1 | 2 |

Payload of events 7–10: `00-03` = 9, `04-07` = `FF FF 00 00`, `08-0B` = `FF FF 00 00`, `0C-0F` = 1, `1C-1F` = result (0 = OK).

---

### IOCTL 0x85B52000 / 0x85B52400 / 0x85B52404 / 0x85B5240C / 0x85B52410 — SLIMbus

These IOCTLs are sent by Qcmbhcgpio8930.sys to the SLIMbus driver (interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}`). The first three are the same as for [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus).

| Property | Value |
|----------|-------|
| Device | 0x85B5 |
| Function | 0x800 / 0x900 / 0x901 / 0x903 / 0x904 (2048 / 2304 / 2305 / 2307 / 2308) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x85B52000 Get logical address (`sub_402940`) | interface `{88EEFAB5-…}` | 6 | 1 |
| 0x85B52400 Read value element (`sub_40276C`) | interface `{88EEFAB5-…}` | 12 | 1 |
| 0x85B52404 Write value element (`sub_4025F0`) | interface `{88EEFAB5-…}` | 16 | 0 |
| 0x85B5240C Acquire (`sub_402AE8`) | interface `{88EEFAB5-…}` | 0 | 0 |
| 0x85B52410 Release (`sub_402BA4`) | interface `{88EEFAB5-…}` | 0 | 0 |

The buffers of 0x85B52000, 0x85B52400 and 0x85B52404 are the same as for [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus).  
0x85B5240C and 0x85B52410 have no buffer. The driver keeps a counter (`dword_41005C`): 0x85B5240C is only sent when it is 0, 0x85B52410 only when it is 1. They surround each burst of codec register accesses (`MBHC_CMD_START`, jack event): probably a vote that keeps the SLIMbus / codec awake ?.  
Reads are retried up to 5 times (10 ms apart), writes up to 5 times (10 ms apart).

---

### IOCTL 0x5001200C / 0x50012010 / 0x50012014 / 0x50012018 / 0x5001201C — codec interrupts

These IOCTLs are sent by Qcmbhcgpio8930.sys to the WCD interrupt handler (interface `{C383F1A1-0E73-47D9-A5B2-214CEC4EE713}`), through `sub_403AE8`. Same codes and buffers as for [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x803–0x807 (2051–2055) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x5001200C register for interrupt (`sub_4039FC`) | interface `{C383F1A1-…}` | 8 | 4 |
| 0x50012010 deregister (`sub_403A40`) | interface `{C383F1A1-…}` | 4 | 0 |
| 0x50012014 enable interrupts (`sub_403A68`) | interface `{C383F1A1-…}` | 8 | 0 |
| 0x50012018 disable interrupts (`sub_403A94`) | interface `{C383F1A1-…}` | 8 | 0 |
| 0x5001201C clear interrupts (`sub_403AC0`) | interface `{C383F1A1-…}` | 4 | 0 |

Inputbuffer (0x5001200C):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Client id ? |
| 04-07 | ? | Kernel address of the interrupt callback `sub_4063D4` |

Outputbuffer (0x5001200C): `00-03` = handle (0 = failure). Inputbuffer of the others: `00-03` = handle, `04-07` = interrupt mask (0x50012014 / 0x50012018; −1 = all).

The callback `sub_4063D4` receives the interrupt status in the first dword of a 12-byte block. The bits are tested in this order (the first match wins); each one disables and clears the interrupts, then:  
| Bit | Action |
|-----|--------|
| 0x02 | internal event 0x13 to the current state |
| 0x20 with 0x10 | internal event 0x17 |
| 0x20 | (only 0x22 disabled) internal event 0x18, unless a jack debounce is running |
| 0x10 | internal event 0x12 |
| 0x40 | internal event 0x10; when armed by FTM sub-command 0: event 0x1D (→ client event 7) |
| 0x04 | re-enables all the interrupts |
| 0x08 | re-enables the interrupts 0x22 |

The codec interrupt names (see [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts)) are not in this binary.

---

### IOCTL 0x50012048 — rm_audio_sr_ioctl

This IOCTL is sent by Qcmbhcgpio8930.sys to the audio codec driver (interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}`) (`sub_401410` → `sub_40156C`). The target is opened at the first call (`sub_40145C`).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x812 (2066) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Audio shared resource request | interface `{3FE58EBD-…}` | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Client id (MBHC) |
| 04-07 | ? | Command |
| 08-0B | ? | Kernel pointer to a 12-byte parameter block |

| Command | Parameter block | Sent at | Meaning |
|---------|-----------------|---------|---------|
| 0x01 | `00 00 00 00 01 00 00 00 01 00 00 00` | `MBHC_CMD_START` | `rm_audio_sr_init` |
| 0x02 | `02 00 00 00 01 00 00 00 ?` / `02 00 00 00 00 00 00 00 ?` | `MBHC_CMD_START`, FTM, jack events / `MBHC_CMD_STOP`, no plug | Request / release the codec clock (`SHARED_RESOURCE_CLOCK_BLOCK`, `sub_40A690`). The third dword isn't initialised |
| 0x10 | `00 00 00 00 00 00 00 00 01 00 00 00` | `MBHC_CMD_STOP` | `rm_audio_sr_deinit` |
| 0x20 | `01 00 00 00 ?`, `00 00 00 00 ?` or `FF FF FF FF ?` | End of `CHECK_PLUG`: 1 for classification 1, 0 for classification 0 (or 2 without swap GPIO, as on the Lumia 520), −1 for classification 2 with swap GPIO. Removal: −1 | Plug state notification ? Only the first dword is set |

Not sent by [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x50012048--rm_audio_sr_ioctl): the clock release and command 0x20.

---

### IOCTL 0x50022400

This IOCTL is sent by Qcmbhcgpio8930.sys to [qcacdb8930.sys](./qcacdb8930.md) (`sub_401E9C` → `sub_401FC0`) to get the `acdb_ioctl` entry point, before each ACDB read.

| Property | Value |
|----------|-------|
| Device | 0x5002 |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get the `acdb_ioctl` entry point | interface `{4EE2204F-14FF-4139-9853-0DA54D6849D5}` | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 04 00 00 00 | Size of the result |
| 04-07 | ? | Kernel pointer to a dword that receives `acdb_ioctl` |

---

### Interface GUID

Qcmbhcgpio8930 Interface Class GUID  
`{093C3754-B2D1-4AC7-B93E-A8FD62FDF7C3}`

### Other GUID

PoFx component id  
`{C7071231-FBF6-2376-A6E1-9B86E0DA2363}`
