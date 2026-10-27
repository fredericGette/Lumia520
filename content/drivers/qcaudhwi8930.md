## Qcaudhwi8930.sys

Qualcomm Audio Hardware Interface (AHWI) driver.  
It starts and stops the QDSP6 AFE ports used by the audio driver [qc8x60aud.sys](./qc8x60aud.md). It receives an ACDB device id and a sample rate, reads the device description from the calibration database [qcacdb8930.sys](./qcacdb8930.md) (ACDB commands 0x11290 / 0x11291), builds the AFE port configuration, and sends it to the Q6 audio driver [qcq6ad8930.sys](./qcq6ad8930.md) (`\Device\Q6Audio`). It also registers 2 power framework (PoFx) components that are kept active while a port of a given type is running.  
It is a small KMDF driver with no hardware resources. PDB path `P:\audio\rel\8.3.1\arm\Release\qcaudhwi8930.pdb`. Pool tags `1haq`…`8haq`, `8daq`, `9daq`.

ACPI device `\_SB.AHWI` (`_HID` `QCOM0743`), with a `_DEP` on `\_SB.ACDB`. `\_SB.QCRT` (qc8x60aud.sys) has a `_DEP` on `\_SB.AHWI`.

There's no named `\Device\` object.  
Symbolic link : `\??\AHWIDrv`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0743\<instance>`  

There's no parameters in the registry.

GUID of the ETW provider (`EtwRegister`, text messages `AHWI: INFO: …` / `AHWI: ERROR: …`, event ids 0xC8–0xCB = levels 2–5):  
`{D8FDB661-0D42-4A89-810B-1D800CB32E2A}`

WPP control GUID:  
`{47EAD127-8B6B-4D3F-BA45-F16BB6764BB7}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| interface `{4EE2204F-14FF-4139-9853-0DA54D6849D5}` | [qcacdb8930.sys](./qcacdb8930.md) | ACDB. Found with `IoGetDeviceInterfaces`, opened with `WdfIoTargetOpen` (by name, `FILE_ALL_ACCESS`) only to get the `acdb_ioctl` entry point ([IOCTL 0x50022400](#ioctl-0x50022400)), then closed |
| \Device\Q6Audio | [qcq6ad8930.sys](./qcq6ad8930.md) | Q6 audio (AFE). Opened by name with `WdfIoTargetOpen` on the first port start, closed when the last port is stopped (reference count `word_407ED4`) |

### Start sequence

`DriverEntry` (`sub_40B008`): WPP init (`sub_40A2F0`), `EtwRegister` (`sub_402CA4`), `WdfDriverCreate`.  
`EvtDriverDeviceAdd` (`sub_40A3E8` → `sub_40A42C`):
1. Sets `EvtDevicePrepareHardware` = `sub_402DB8` and `EvtDeviceReleaseHardware` = `sub_402E9C`.
2. Creates the device (no name, context `DEVICE_CONTEXT`: `+0x00` physical device object, `+0x04` PoFx handle).
3. Creates the device interface [`{ABFE8B0D-…}`](#interface-guid).
4. Creates the default queue (sequential, not power-managed, context `QUEUE_CONTEXT`) with `EvtIoDeviceControl` = `sub_402F50`.
5. `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
6. Creates the symbolic link `\??\AHWIDrv`.

`EvtDevicePrepareHardware` (`sub_402DB8`): creates the two mutexes (port table and Q6 target, `sub_4011CC`) and registers the PoFx device (`sub_4026BC`, see [Power management](#power-management)).  
`EvtDeviceReleaseHardware` (`sub_402E9C`): disables the device interface, `PoFxUnregisterDevice`, frees the mutexes, unregisters ETW/WPP.

### Port start / stop

[IOCTL 0x50032000](#ioctl-0x50032000) (`sub_402F50`):
1. `sub_403630` builds the 100-byte AFE port structure (see [AFE port structure](#afe-port-structure)):
   1. `sub_403E40` → `sub_403F3C`: opens the ACDB interface `{4EE2204F-…}` and gets `acdb_ioctl` with [IOCTL 0x50022400](#ioctl-0x50022400) (done again for every request; the pointer is kept in `off_407EE8`).
   2. ACDB command 0x11290 (`sub_404434`), input `{device id, 8, pointer to an 8-byte buffer}`: the second dword of the buffer receives the device type (0x11296…).
   3. ACDB command 0x11291 (`sub_4044F8`), input `{device id, device type, 304, pointer to a 304-byte buffer}`: the buffer receives the device info structure (300 bytes kept).
   4. The sample rate is converted to the ACDB bit mask (8000 → 1, 11025 → 2, 12000 → 4, 16000 → 8, 22050 → 0x10, 24000 → 0x20, 32000 → 0x40, 44100 → 0x80, 48000 → 0x100, 96000 → 0x200, 192000 → 0x400). Another rate → `AHWI: ERROR:  Invalid frequency %d` and `STATUS_INVALID_PARAMETER`. If the rate is not in the mask of supported rates of the device info structure, only a trace is written.
   5. The fields of the device info structure are copied as 16-bit values according to the device type.
2. `sub_4016C0(…, 0)`: opens `\Device\Q6Audio` if not already open (`WdfIoTargetOpen`, `FILE_OPEN`, share read/write, `FILE_NON_DIRECTORY_FILE`, `EvtIoTargetRemoveComplete` = `sub_4019E4`), increments its reference count.
3. Device type 0x11296: activates PoFx component 1.
4. `sub_401AFC`: adds the port to the port table, then sends [IOCTL 0xADAD2B8D](#ioctl-0xadad2b8d--0xadad2b91--0xadad2b95) then [IOCTL 0xADAD2B91](#ioctl-0xadad2b8d--0xadad2b91--0xadad2b95) to Q6 audio with the AFE port structure.
5. Device type 0x11297: activates PoFx component 0.

On failure of step 4, the component is idled and the Q6 reference released.

[IOCTL 0x50032004](#ioctl-0x50032004) (`sub_402F50`): same steps 1 (ACDB lookup), then `sub_40206C` sends [IOCTL 0xADAD2B95](#ioctl-0xadad2b8d--0xadad2b91--0xadad2b95) and removes the port from the table, then `sub_4016C0(…, 1)` decrements the Q6 reference (closes the target at 0), then idles PoFx component 1 (type 0x11296) or 0 (type 0x11297).

The port table (`sub_40137C`, `unk_407F60`) has 100 entries `{in use, key, Q6 value}`. The key is the 16-bit value at offset 0x14 of the AFE port structure (AFE port id ?), the value is the ACDB device id.

> [!NOTE]
> The trace of the stop function is labelled `AFERMStopDevice … Q6AD_CMD_AFE_PORT_START fail`, but the command sent is 0xADAD2B95, a different code from the start commands: the "START" in that string is probably a copy/paste.

### AFE port structure

Built by `sub_403630`, sent as InputBuffer (100 bytes) of the 0xADAD2B8D / 0xADAD2B91 / 0xADAD2B95 IOCTLs. "info[n]" = dword n of the device info structure returned by ACDB command 0x11291, truncated to 16 bits.

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | ? (version) |
| 04-07 | ? | ACDB device id (from the input buffer) |
| 08-0B | 96 12 01 00 | ACDB device type (0x11296, 0x11297, 0x11299, 0x1129A or 0x1129C) |
| 0C-0F | 80 BB 00 00 | Sample rate, e.g. 48000 |
| 10-13 | 00 00 00 00 | Input buffer bytes 0C-0D of IOCTL 0x50032000 (always 0 from qc8x60aud.sys) |
| 14-63 | ? | Device type specific, see below. The remaining bytes are not initialised (stack) |

Device-type specific part (16-bit fields):  
| Device type | 14-15 | 16-17 | 18-19 | 1A-1B | 1C-1D | 1E-1F | 20-21 | 22-23 | Supported rates mask |
|-------------|-------|-------|-------|-------|-------|-------|-------|-------|----------------------|
| 0x11296 (I2S ?) | info[2] | 16 | info[3] | info[4] | info[5] | 0 | | | info[10] |
| 0x11297 (PCM ?) | info[0] | info[1] | info[2] | info[3] | info[4] | info[5] | info[6] | 0 | info[9] |
| 0x11299 | info[0] | 16 | info[1] | 0 | | | | | info[6] |
| 0x1129A | info[0] | 16 | info[1] | info[2] | | | | | info[5] |
| 0x1129C | info[0] | 0 | | | | | | | info[3] |

Any other device type → `STATUS_NOT_FOUND`.

### Power management

`sub_4026BC` registers the device with `PoFxRegisterDevice` (5 callbacks, 2 components) then `PoFxStartDevicePowerManagement`.

| Component | GUID | Activated for device type |
|-----------|------|---------------------------|
| 0 | `{6CE9D020-E123-4A56-9A4D-3F353D4098AA}` | 0x11297 |
| 1 | `{892B189A-FC39-462B-90DE-5C5FE185D768}` | 0x11296 |

Each component has 2 idle states: F0 (latency 0, residency 0, nominal power 500) and F1 (latency 2, residency 5, nominal power 50).  
Callbacks: `ComponentActiveConditionCallback` `sub_4023F8` (trace only), `ComponentIdleConditionCallback` `sub_40242C` (`PoFxCompleteIdleCondition`), `ComponentIdleStateCallback` `sub_4024C4` (`PoFxCompleteIdleState`), `DevicePowerRequiredCallback` `sub_40257C` (`PoFxReportDevicePoweredOn`), `DevicePowerNotRequiredCallback` `sub_4025F4` (`PoFxCompleteDevicePowerNotRequired`).  
The components are activated/idled with a reference count per component (`sub_402AD8` / `sub_4029D8`, `dword_407F58`). The driver has no hardware: the effect of the component states is left to the PEP (clocks of the audio interfaces ?).

---

### IOCTL 0x50032000

This IOCTL is processed by Qcaudhwi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x5003 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Start an AFE port | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not used |
| 04-07 | ? | ACDB device id |
| 08-09 | 80 BB | Sample rate (16 bits), e.g. 48000 |
| 0A-0B | ? | Not used |
| 0C-0D | 00 00 | Copied to bytes 10-13 of the AFE port structure. Always 0 when sent by qc8x60aud.sys |
| 0E-0F | 00 00 | Not used |

See [Port start / stop](#port-start--stop).  
NTSTATUS: `STATUS_INVALID_PARAMETER` (input length ≠ 16, unknown sample rate), `STATUS_NOT_FOUND` (ACDB interface or device not found, unknown device type), `STATUS_ACCESS_DENIED` (port already started or port table full), `STATUS_NO_SUCH_DEVICE` (`\Device\Q6Audio` not open), `0xC000022B` STATUS_DUPLICATE_OBJECTID (Q6 target object exists but its reference count is 0), or the status of the Q6 IOCTL.  
Sent by [qc8x60aud.sys](./qc8x60aud.md) (interface `{ABFE8B0D-…}`).

---

### IOCTL 0x50032004

This IOCTL is processed by Qcaudhwi8930.sys

| Property | Value |
|----------|-------|
| Device | 0x5003 |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Stop an AFE port | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not used |
| 04-07 | ? | ACDB device id |
| 08-09 | 80 BB | Sample rate (16 bits), e.g. 48000 |
| 0A-0F | ? | Not used |

See [Port start / stop](#port-start--stop).  
NTSTATUS: `STATUS_INVALID_PARAMETER`, `STATUS_NOT_FOUND` (port not started, or ACDB lookup failed), `STATUS_ACCESS_DENIED` (port table inconsistent), `STATUS_NO_SUCH_DEVICE` (`\Device\Q6Audio` not open), or the status of the Q6 IOCTL.  
Any other IOCTL code → `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x50022400

This IOCTL is sent by Qcaudhwi8930.sys to qcacdb8930.sys

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
| 00-03 | 04 00 00 00 | Length of the variable |
| 04-07 | ? | Pointer to a 4-byte variable (WDF memory, tag `8daq`) that receives the address of `acdb_ioctl` |

Sent by `sub_404164` with `WdfIoTargetSendIoctlSynchronously`. The function pointer is then called directly: `acdb_ioctl(0x11290, …)` and `acdb_ioctl(0x11291, …)`.  
See [IOCTL 0x50022400](./qcacdb8930.md#ioctl-0x50022400) of qcacdb8930.sys.

---

### IOCTL 0xADAD2B8D / 0xADAD2B91 / 0xADAD2B95

These IOCTLs are sent by Qcaudhwi8930.sys to [qcq6ad8930.sys](./qcq6ad8930.md)

| Property | Value |
|----------|-------|
| Device | 0xADAD |
| Function | 0xAE3 / 0xAE4 / 0xAE5 (2787 / 2788 / 2789) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0xADAD2B8D AFE port configure ? | \Device\Q6Audio | 100 | 0 |
| 0xADAD2B91 AFE port start ? | \Device\Q6Audio | 100 | 0 |
| 0xADAD2B95 AFE port stop ? | \Device\Q6Audio | 100 | 0 |

Inputbuffer: the [AFE port structure](#afe-port-structure) (copied into a WDF memory object, tags `5haq`, `6haq`, `7haq`).

0xADAD2B8D then 0xADAD2B91 are sent by `sub_401AFC` (port start), 0xADAD2B95 by `sub_40206C` (port stop), with `WdfIoTargetSendIoctlSynchronously` on a new request each time.

---

### Interface GUID

AHWI Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{ABFE8B0D-5D26-4C5A-B5F2-1F33E47A4F65}`
