## Qcmbhc8930.sys

Qualcomm MBHC (Multi-Button Headset Control) driver: headset jack detection and headset button detection done by the WCD93xx audio codec.  
It runs the MBHC state machine of the codec (states `START`, `NO_PLUG`, `CHECK_PLUG`, `AV_PLUG`, `INVALID_PLUG`, `NBTN_PRESSED`, `BTN_PRESSED`): it detects plug insertion/removal, tells a headphone from a headset with a microphone, detects a US/EU (CTIA/OMTP) plug mismatch, and polls the headset buttons. It reads/writes the codec registers directly over the **SLIMbus**, receives the codec interrupts through a WCD interrupt-handler driver, reads its thresholds from the calibration database [qcacdb8930.sys](./qcacdb8930.md), and drives 3 GPIOs through the GPIO resource hub.  
It has no IOCTL interface of its own beyond one IOCTL that returns a kernel entry point `mbhc_ioctl`. The audio driver [qc8x60aud.sys](./qc8x60aud.md) uses that entry point when its registry value `GpioBasedHeadsetDetection` = 0 (otherwise it uses the GPIO-based driver of `\_SB.MBGP`, [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md)). Jack and button events are reported to the client through a callback.  
It is a KMDF driver. PDB path `P:\audio\rel\8.3.1\arm\Release\qcmbhc8930.pdb`. The log messages contain `Legacy mbhc_init …, 08/02 0930`. Pool tags `abmq`, `cbmq`, `ebmq`, `gbmq`, `hbmq`, WDF memory tags `Abmq`…`Lbmq`.

ACPI device `\_SB.MBHC` (`_HID` `QCOM0746`), with `_DEP` on `\_SB.PEP0`, `\_SB.PMIC`, `\_SB.ACDB`, `\_SB.SLM1`, `\_SB.TICO` and `\_SB.ACHW`.

There's no named `\Device\` object and no symbolic link.  
The driver registers the device interface `{790370AE-6E34-4800-8927-351A338FB740}` (see [Interface GUID](#interface-guid)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0746\<instance>`  

There's no parameters in the registry.

GUID of the ETW provider (`EtwRegister`, text messages `mbhc:…`; event ids 0xC8 = errors, 0xC9 = info, 0xCA = codec register traces):  
`{AB98B75D-A541-49A9-8B8B-C469366AB837}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}` | [qcslimbus8930.sys](./qcslimbus8930.md) (`\_SB.SLM1`, QCOM0190) | Codec register read/write and codec logical address. Opened at the first IOCTL (`EA_KMDF_mbhc_slimbus_start`). See [IOCTL 0x85B52000 / 0x85B52400 / 0x85B52404](#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus) |
| interface `{C383F1A1-0E73-47D9-A5B2-214CEC4EE713}` | WCD codec interrupt handler (`\_SB.TICO` ?) | Register / enable / disable / clear the codec interrupts. See [IOCTL 0x5001200C…0x5001201C](#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts) |
| interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` | [qcsitarcodec8930.sys](./qcsitarcodec8930.md) (`\_SB.ACHW`) | Same interface as the ADIE codec of [qc8x60aud.sys](./qc8x60aud.md). Used as the audio "resource manager" (`rm_audio_sr_ioctl`). See [IOCTL 0x50012048](#ioctl-0x50012048--rm_audio_sr_ioctl) |
| interface `{4EE2204F-14FF-4139-9853-0DA54D6849D5}` | [qcacdb8930.sys](./qcacdb8930.md) | ACDB. Opened for each read only to get the `acdb_ioctl` entry point ([IOCTL 0x50022400](#ioctl-0x50022400)), then closed |
| `\Device\RESOURCE_HUB\<connection id>` | GPIO controller ([qcgpio.sys](./qcgpio.md)) | The 3 GpioIo resources. `IOCTL_GPIO_WRITE_PINS` / `IOCTL_GPIO_READ_PINS`. See [GPIO](#gpio) |

All interfaces are found with `IoGetDeviceInterfaces` (first symbolic link) and opened with `WdfIoTargetOpen` by name with `FILE_ALL_ACCESS`. The open of the codec and interrupt-handler targets registers a `EvtIoTargetRemoveComplete` callback that closes the target.

### Start sequence

1. `DriverEntry`: `WdfDriverCreate`, ETW registration.
2. `EvtDriverDeviceAdd` (`sub_416070`): PnP callbacks (`EvtDevicePrepareHardware`, `EvtDeviceReleaseHardware`, `EvtDeviceSurpriseRemoval`), `WdfDeviceCreate`, device interface `{790370AE-…}`, one sequential default queue with `EvtIoDeviceControl`, then `WdfDeviceSetStaticStopRemove(FALSE)`.
3. `EvtDevicePrepareHardware`: stores the connection id of every `CmResourceTypeConnection` resource of class GPIO / type IO in a table (`dword_414220` + 16·i: `+8` connection id low, `+0xC` connection id high, `+0x10` valid flag), then registers the power framework component (see [Power framework](#power-framework)).
4. The real initialisation (`mbhc_init`, `sub_404048`) is **lazy**: it runs on the first `IOCTL 0x500A2800` (or on `MBHC_CMD_FTM_INTR`):
   1. Allocates the context (0x7C bytes) and 3 mutexes (`mbhcLock`, `lock`, `mbhcRMLock`).
   2. SLIMbus: creates the I/O target and opens the interface `{88EEFAB5-…}`.
   3. Gets the codec logical address from its enumeration address with [IOCTL 0x85B52000](#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus): first `00 01 10 00 17 02` ("V1"), then `00 01 60 00 17 02` ("V2") if the first fails or returns 0. Manufacturer id 0x0217 = Qualcomm; the two part ids (0x0010 / 0x0060) are probably two WCD93xx codec variants ?
   4. `mbhc_state_init`, then opens the interrupt handler interface `{C383F1A1-…}` and registers the interrupt callback `sub_4078E8` with [IOCTL 0x5001200C](#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts).
   
   On failure the deinit sequence runs and the IOCTL completes with `STATUS_DEVICE_NOT_READY` (0xC00000A3).

### Codec registers

The codec registers are accessed as SLIMbus value elements: element address = register address + 0x800, 1 byte, at the logical address of the codec (`mbhc_codec_get_register_value` `sub_40847C`, `mbhc_codec_set_bit` / `mbhc_codec_set_value`, `mbhc_codec_compare_bit` `sub_4085BC`). A read or write is retried up to 5 times (10 ms apart) on failure.

### ACDB

The thresholds are read from the ACDB with `acdb_ioctl(0x1126B, in, 16, out, 4)` (the generic "get" command, see [qcacdb8930.sys](./qcacdb8930.md)). If the ACDB can't be read, default values hard-coded in the driver are used.  
Input buffer of command 0x1126B:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | E5 12 01 00 | Module id 0x112E5 (MBHC) |
| 04-07 | ? | Parameter id (see below) |
| 08-0B | ? | Size of the result in bytes |
| 0C-0F | ? | Kernel pointer to the result buffer |

| Parameter id | Size | Function | Logged fields |
|--------------|------|----------|---------------|
| 0x112E6 | 16 | `mbhc_ea_acdb_get_gen_config` (`sub_401F14`) | `MBHC_VmicBias` (byte at +6) |
| 0x112E7 | 20 | `mbhc_acdb_get_rem_config` (`sub_401FA8`) | `MBHC_TinsCompl` (word at +0x0A) |
| 0x112E8 | 16 | `mbhc_acdb_get_type_config` (`sub_40203C`) | `MBHC_VnoMic` (+4), `MBHC_VHSMin` (+0x0A), `MBHC_VHSMax` (+0x0C) |
| 0x112E9 | 84 | `mbhc_acdb_get_press_config` (`sub_4020DC`) | `MBHC_NumBut` (byte at +0x0D), `MBHC_Tpoll` (+0x10), `MBHC_TBounceWait` (+0x12), then the low/high voltage of each button |
| 0x112EA | 48 | `mbhc_acdb_get_impedance_config` (`sub_402178`) | `MBHC_HeadSetImpDet` (byte at +0) |

### GPIO

The 3 GpioIo resources of `\_SB.MBHC._CRS` are opened through `\Device\RESOURCE_HUB\<connection id as 16 hex digits>` for each access (`MBHCSwitchGpio` `sub_403248` → `WriteToDevice` `sub_403494`, `MBHCReadGpio` `sub_403378` → `ReadFromDevice` `sub_4036F4`). Write: `FILE_GENERIC_WRITE`, `IOCTL_GPIO_WRITE_PINS` (0x480004) with 1 byte. Read: `FILE_GENERIC_READ`, `IOCTL_GPIO_READ_PINS` (0x480000) with 1 byte.  
| Resource index | Name in the driver | Lumia 520 pin (`\_SB.GIO0`) | Use |
|----------------|--------------------|-----------------------------|-----|
| 0 | GPIO_AUDIO_VID_SEL | 43 | Written 0 at `MBHC_CMD_START` |
| 1 | GPIO_ANC_HEADSET_DET | 51 | Read 100 ms after a headset with microphone is detected; selects the accessory type 2 or 6 |
| 2 | GPIO_US_EURO_SEL | 43 | Written 0 at `MBHC_CMD_START` and when waiting for an insertion, 1 when a US/EU plug mismatch is detected (swaps the MIC/GND contacts) |

All three are declared with PullDown, IoRestrictionNone. Note: resources 0 and 2 use the same pin 43 in the Lumia 520 DSDT.

### Power framework

`MBHCPowerManagerRegister` (`sub_402F38`) registers 1 PoFx component with `PoFxRegisterDevice` and starts the power management at `EvtDevicePrepareHardware`. The component is activated (`PoFxActivateComponent`) at `MBHC_CMD_START` and set idle (`PoFxIdleComponent`) at `MBHC_CMD_STOP` (`MBHCSwitchCommonPower` `sub_403918`).  
| Property | Value |
|----------|-------|
| Component id | `{C7071231-FBF6-2376-A6E1-9B86E0DA2363}` |
| F0 | latency 0, residency 0, nominal power 500 |
| F1 | latency 2, residency 5, nominal power 50 |

The PoFx callbacks only complete the requests (`PEPTest…Callback` messages).

---

### IOCTL 0x500A2800 — get the `mbhc_ioctl` entry point

This IOCTL is processed by Qcmbhc8930.sys (`EvtIoDeviceControl` `sub_4019B0`). It is sent by [qc8x60aud.sys](./qc8x60aud.md#ioctl-0x500a2800--get-headset-detection-entry-point) to the interface `{790370AE-…}`.

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
| 00-03 | 04 00 00 00 | Size of the result (only logged) |
| 04-07 | ? | Kernel pointer to a dword that receives the address of `mbhc_ioctl` (`sub_404620`) |

The first IOCTL received (any code) runs `mbhc_init` first.  
NTSTATUS returned:  
| Value | Comment |
|-------|---------|
| 0x00000000 | Entry point written |
| 0xC00000A3 STATUS_DEVICE_NOT_READY | `mbhc_init` failed |
| 0xC000000D STATUS_INVALID_PARAMETER | Other IOCTL code, no input buffer, or input size ≠ 8 |
| 0xC022001C | The pointer at offset 04 is NULL |

> [!NOTE]
> The input carries a raw kernel pointer that is written without validation: the IOCTL is only usable from kernel mode.

#### `mbhc_ioctl(command, buffer, size)`

Entry point returned by IOCTL 0x500A2800. Returns 0 on success, 1 on failure, 0x100 if the mutexes don't exist, 0x1000 for an unknown command (0 or ≥ 0x10).  
| Command | Name | Buffer | Action |
|---------|------|--------|--------|
| 1 | MBHC_CMD_START | - | Activates the PoFx component, sends `rm_audio_sr_init` and `SHARED_RESOURCE_CLOCK_BLOCK` to the codec ([IOCTL 0x50012048](#ioctl-0x50012048--rm_audio_sr_ioctl)), writes 0 to GPIO_AUDIO_VID_SEL and GPIO_US_EURO_SEL, runs the codec init sequence and the boot-up ADC calibration (DCE/STA zero and mic-bias values), reads the ACDB thresholds, programs the button and insertion thresholds, then starts the state machine in state `START` (sets up the insertion detection) |
| 2 | MBHC_CMD_STOP | - | Sends `rm_audio_sr_deinit` (cmd 0x10), sets the PoFx component idle, and resets the state to `START` |
| 3 | MBHC_CMD_SET_CB | 8 bytes `{ callback, context }` | Registers the client callback. Fails if MBHC is not initialised |
| 4 | MBHC_CMD_FTM_INTR | - | Factory test mode: initialises MBHC if needed and triggers a plug insertion interrupt (`mbhc_state_FTM_test_INTR`) |

Note: [qc8x60aud.sys](./qc8x60aud.md) also sends a command 5 ("set mode"). This driver doesn't handle it and returns 0x1000. The GPIO-based variant [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#mbhc_ioctlcommand-buffer-size) handles it as a factory test sub-command (and uses command 4 to enter its `FTM` state).

Callback: `callback(event, payload, 32, context)`:  
| Event | Name | Sent by |
|-------|------|---------|
| 1 | MBHC_PLUG_INSERT | `mbhc_state_check_plug_reset` |
| 2 | MBHC_PLUG_REMOVE | `mbhc_state_nbp_removal`, `mbhc_state_headphone_lp_removal` |
| 3 | MBHC_BUTTON_PRESS | button held down (`mbhc_state_nbp_handle`) |
| 4 | MBHC_BUTTON_RELEASE | release after a reported press |
| 6 | MBHC_BUTTON_PRESS_RELEASE | short press (press and release seen in the same measurement) |

Payload (32 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Accessory type: 2 = headset with microphone (GPIO_ANC_HEADSET_DET ≠ 0), 4 = headphone without or with floating microphone, 6 = headset with microphone and GPIO_ANC_HEADSET_DET = 0 (ANC headset ?) |
| 04-07 | FF FF 00 00 | Button id (0xFFFF for plug events) |
| 08-0B | FF FF 00 00 | Press duration (0xFFFF for plug events) |
| 0C-1F | ? | ? |

---

### IOCTL 0x85B52000 / 0x85B52400 / 0x85B52404 — SLIMbus

These IOCTLs are sent by Qcmbhc8930.sys to the SLIMbus driver [qcslimbus8930.sys](./qcslimbus8930.md) (interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}`).

| Property | Value |
|----------|-------|
| Device | 0x85B5 |
| Function | 0x800 / 0x900 / 0x901 (2048 / 2304 / 2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x85B52000 Get logical address (`sub_4028E8`) | interface `{88EEFAB5-…}` | 6 | 1 |
| 0x85B52400 Read value element (`sub_4026E0`) | interface `{88EEFAB5-…}` | 12 | 1 |
| 0x85B52404 Write value element (`sub_402508`) | interface `{88EEFAB5-…}` | 16 | 0 |

Inputbuffer (0x85B52000):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-05 | 00 01 10 00 17 02 | Enumeration address of the codec (or `00 01 60 00 17 02`) |

Outputbuffer (0x85B52000):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Logical address of the codec |

Inputbuffer (0x85B52400):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Logical address of the codec |
| 01-03 | ? | Padding |
| 04-07 | ? | Element address = register + 0x800 |
| 08-0B | 01 00 00 00 | Number of bytes |

Outputbuffer (0x85B52400):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Register value |

Inputbuffer (0x85B52404):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Logical address of the codec |
| 01-03 | ? | Padding |
| 04-07 | ? | Element address = register + 0x800 |
| 08-0B | 01 00 00 00 | Number of bytes |
| 0C | ? | Register value |
| 0D-0F | ? | Padding |

Reads and writes are retried up to 5 times, 10 ms apart. A successful write is followed by a 1 ms delay.

---

### IOCTL 0x5001200C / 0x50012010 / 0x50012014 / 0x50012018 / 0x5001201C — codec interrupts

These IOCTLs are sent by Qcmbhc8930.sys to the WCD interrupt handler (interface `{C383F1A1-0E73-47D9-A5B2-214CEC4EE713}`), through `SendIOCTLToDevice` (`sub_403CFC`).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x803–0x807 (2051–2055) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x5001200C wcd_register_for_interrupt (`sub_403B80`) | interface `{C383F1A1-…}` | 8 | 4 |
| 0x50012010 wcd_deregister_interrupt (`sub_403BEC`) | interface `{C383F1A1-…}` | 4 | 0 |
| 0x50012014 wcd_enable_interruption (`sub_403C28`) | interface `{C383F1A1-…}` | 8 | 0 |
| 0x50012018 wcd_disable_interruption (`sub_403C74`) | interface `{C383F1A1-…}` | 8 | 0 |
| 0x5001201C wcd_clear_interrupt (`sub_403CC0`) | interface `{C383F1A1-…}` | 4 | 0 |

Inputbuffer (0x5001200C):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Client id ? |
| 04-07 | ? | Kernel address of the interrupt callback `mbhc_codec_interrupt_handler_callback` (`sub_4078E8`) |

Outputbuffer (0x5001200C):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle (0 = failure) |

Inputbuffer (0x50012014 / 0x50012018):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle |
| 04-07 | ? | Interrupt mask |

Inputbuffer (0x50012010 / 0x5001201C):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle |

The callback receives an interrupt summary. The interrupts handled are `WCD_INT_DIG_NONLP_REMOVAL`, `WCD_INT_DIG_DC_EST`, `WCD_INT_BUTTON_RELEASE`, `WCD_INT_ANA_LP_INSREM`, `WCD_INT_STA_COMPLETE` and `WCD_INT_POTENTIAL_PRESS`. The bit values are ?.  
Note: 0x5001200C and 0x50012010 have the same codes as `ADIE_CODEC_DRIVER_IOCTL_ACTIVATE_DEVICE` / `DEACTIVATE_DEVICE` of [qc8x60aud.sys](./qc8x60aud.md), but they're sent to a different interface.

---

### IOCTL 0x50012048 — rm_audio_sr_ioctl

This IOCTL is sent by Qcmbhc8930.sys to the audio codec driver [qcsitarcodec8930.sys](./qcsitarcodec8930.md#ioctl-0x50012048--rm_audio_sr_ioctl) (interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}`) (`rm_audio_sr_ioctl` `sub_401008` → `sub_401208`). The target is opened at the first call (`ConnectToRM` `sub_4010AC`).

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
| 0x01 | `00 00 00 00 01 00 00 00 00 00 00 00` | `MBHC_CMD_START` | `rm_audio_sr_init` |
| 0x02 | `02 00 00 00 01 00 00 00 00 00 00 00` | `MBHC_CMD_START` | `SHARED_RESOURCE_CLOCK_BLOCK` (request the codec clock ?) |
| 0x10 | `00 00 00 00 00 00 00 00 00 00 00 00` | `MBHC_CMD_STOP` | `rm_audio_sr_deinit` |

The state machine also reacts to `MBHC_RM_AUDIO_START` / `MBHC_RM_AUDIO_COMPLETE` (button polling paused / resumed while the audio path is reconfigured), but the way these notifications arrive is ?.

---

### IOCTL 0x50022400

This IOCTL is sent by Qcmbhc8930.sys to [qcacdb8930.sys](./qcacdb8930.md) (`ConnectToACDB` `sub_401B7C` → `sub_401D18`) to get the `acdb_ioctl` entry point.

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

Qcmbhc8930 Interface Class GUID  
`{790370AE-6E34-4800-8927-351A338FB740}`
