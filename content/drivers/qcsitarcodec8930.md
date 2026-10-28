## Qcsitarcodec8930.sys

Qualcomm audio codec driver for the **WCD9304 "Sitar"** codec (ADIE) of the Lumia 520.  
It is the "audio codec driver" of `\_SB.ACHW` that the other audio drivers reach through the interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` (`ADIE_CODEC_DRIVER_IOCTL_*`, codes `0x5001xxxx`). For each audio device (ACDB device id) it acquires, activates, deactivates and releases the codec path: it reads the codec profile from the calibration database [qcacdb8930.sys](./qcacdb8930.md), writes the codec registers over the **SLIMbus**, configures and starts the matching AFE port of the ADSP through [qcq6ad8930.sys](./qcq6ad8930.md) (`\Device\Q6Audio`), and switches the per-device resources (power framework component, GPIO, PMIC loudspeaker amplifier of [qcpmic8930.sys](./qcpmic8930.md)) described by the ACPI methods of `\_SB.ACHW`. It also hosts the audio "shared resource manager" used by [qcmbhc8930.sys](./qcmbhc8930.md) / [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md) (codec clock), and registers an ACPH handler in the ACDB so that QACT can access the codec online.  
It is a KMDF driver. PDB path `E:\build_e\subtask\E05A4CC0_98\output\audio\fre\qcsitarcodec8930.pdb`. Pool tags `?ctq` (`!ctq`, `1ctq`…`9ctq`, `actq`…), WDF memory tags `Nctq`…`rctq`. There are almost no strings: all messages are WPP traces.

ACPI device `\_SB.ACHW` (`_HID` `QCOM0741`), with `_DEP` on `\_SB.PEP0`, `\_SB.PMIC`, `\_SB.Q6AD`, `\_SB.ACDB`, `\_SB.SLM1` and `\_SB.TICO`. Resource: one `GpioIo` (pin 42) of `\_SB.GIO0`.

There's no named `\Device\` object (the PDO name is used).  
Symbolic link : `\DosDevices\sitardrv`  
The driver registers the device interface `{3FE58EBD-6A7D-4760-A01F-66369C501AB0}` (see [Interface GUID](#interface-guid)) once its initialisation is complete.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0741\1`  

There's no parameters in the registry.

GUID of the ETW provider (`EtwRegister`, `McGenEventRegister`):  
`{597928F9-37CE-4BAD-BBA4-AE1A12CBDD12}`

WPP control GUID:  
`{D3D7C968-4842-4C61-994E-2AAD4DBA2C18}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of the device (default I/O target) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) `BFSZ`, `GPNF`, `PPNF` (and `HPAM`), see [ACPI methods](#acpi-methods) |
| interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}` | [qcslimbus8930.sys](./qcslimbus8930.md) (`\_SB.SLM1`, QCOM0190) | Waited for with `IoRegisterPlugPlayNotification`. Codec logical address, register read/write and votes. See [IOCTL 0x85B52xxx](#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus) |
| interface `{4EE2204F-14FF-4139-9853-0DA54D6849D5}` | [qcacdb8930.sys](./qcacdb8930.md) | ACDB. Waited for with `IoRegisterPlugPlayNotification`. Opened to get the `acdb_ioctl` entry point ([IOCTL 0x50022400](#ioctl-0x50022400)). See [ACDB](#acdb) |
| interface `{FB4F07CD-8D4C-4413-92C2-E2C9CAED9F43}` | [qcchipinfo8930.sys](./qcchipinfo8930.md) | [IOCTL 0x8C1F2008](#ioctl-0x8c1f2008) (chip id) once at init, then closed |
| `\Device\Q6Audio` | [qcq6ad8930.sys](./qcq6ad8930.md) | AFE port configure / start / stop and loopback. Opened at the first acquire (`sub_40866C`, `EvtIoTargetRemoveComplete` = `sub_408948`). See [IOCTL 0xADAD2Bxx](#ioctl-0xadad2b89--0xadad2b8d--0xadad2b91--0xadad2b95--0xadad2b99--0xadad2bd5) |
| interface `{1408ACF4-24D1-43AB-8F80-2F7D8AEDD372}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC loudspeaker amplifier. See [IOCTL 0x8012xxxx](#ioctl-0x80120fa0--0x80120fa4--0x80120fb0--pmic-loudspeaker) |
| `\Device\RESOURCE_HUB\<connection id>` | GPIO controller ([qcgpio.sys](./qcgpio.md)) | The `GpioIo` resource (pin 42). `IOCTL_GPIO_WRITE_PINS` (0x480004), see [GPIO](#gpio) |

All interfaces are found with `IoGetDeviceInterfaces` (first symbolic link) and opened with `WdfIoTargetOpen` by name with `FILE_ALL_ACCESS`.

Drivers using qcsitarcodec8930.sys (interface `{3FE58EBD-…}`):  
| Driver | IOCTLs |
|--------|--------|
| [qc8x60aud.sys](./qc8x60aud.md) | 0x50012004, 0x50012008, 0x5001200C, 0x50012010, 0x50012020, 0x50012040, 0x50012044 |
| [qcmbhc8930.sys](./qcmbhc8930.md) | 0x50012048 |
| [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md) | 0x50012048 |

> [!NOTE]
> The input buffers of the device IOCTLs contain **kernel pointers** (device descriptor, device id, parameter block): the interface can only be used from kernel mode.

### Start sequence

1. `DriverEntry`: WPP, ETW registration, `WdfDriverCreate`.
2. `EvtDriverDeviceAdd` (`sub_43D40C`): `EvtDevicePrepareHardware` = `sub_406544`, `EvtDeviceReleaseHardware` = `sub_406838`, `WdfDeviceCreate` (context `DEVICE_CONTEXT`, 8 bytes: WDM device object, PoFx handle), one sequential, non power-managed default queue with `EvtIoDeviceControl` (`sub_43D5E0`), `WdfDeviceSetStaticStopRemove(FALSE)`, `WdfDeviceCreateSymbolicLink(\??\sitardrv)`.
3. `EvtDevicePrepareHardware` (`sub_406544`):
   1. Stores the connection id of the `CmResourceTypeConnection` resources: class GPIO / type IO (pin 42) and class serial / type I2C (none on the Lumia 520).
   2. Registers the power framework device (see [Power framework](#power-framework)).
   3. `IoRegisterPlugPlayNotification` on the SLIMbus `{88EEFAB5-…}` and ACDB `{4EE2204F-…}` interfaces (callback `sub_406238`).
4. When both interfaces have arrived (counter `dword_43B9EC` from 2 to 0), the callback starts the system thread `sub_406010` which runs `sub_402348`:
   1. Creates the IOCTL mutex and clears the [device table](#device-table).
   2. `sub_401F48`: reads the ACPI methods `BFSZ`, `GPNF` and `PPNF` ([ACPI methods](#acpi-methods)).
   3. `sub_402178`: gets the chip id from [qcchipinfo8930.sys](./qcchipinfo8930.md) ([IOCTL 0x8C1F2008](#ioctl-0x8c1f2008)), kept in `dword_43BADC` (use ?).
   4. `sub_410334`: opens the GPIO resource hub, applies the resources of the default `PPNF` entry, opens the SLIMbus and the PMIC interfaces and drives the GPIO function 0 to its active level (codec reset / enable ?).
   5. `sub_40CE2C` → `sub_41A6A4`: codec bring-up over the SLIMbus: logical addresses ([IOCTL 0x85B52000](#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus)), codec register initialisation.
   6. `sub_40B868`: builds the codec register default tables and registers the [ACPH handler](#acdb) in the ACDB.
   7. `sub_406F64`: allocates the AFE port table (10 entries).
   
   Then the "initialised" flag `byte_43BAD8` is set and `WdfDeviceCreateDeviceInterface` / `WdfDeviceSetDeviceInterfaceState(TRUE)` publish the interface `{3FE58EBD-…}`. On a failure the steps already done are undone (`sub_4024FC`).
5. `EvtDeviceReleaseHardware` (`sub_406838`): disables the interface, unregisters the PnP notifications, runs the deinit (`sub_402600`) and `PoFxUnregisterDevice`.

### ACPI methods

Evaluated on the device's own stack with `IOCTL_ACPI_EVAL_METHOD` (0x32C004) (`sub_4012B0`, signature `AeiB`, no argument; output signature `AeoB` checked):  
| Method | Lumia 520 | Use |
|--------|-----------|-----|
| `BFSZ` | 0x800 | Size of the output buffer used for `GPNF` and `PPNF` (`dword_421180`, default 2048) |
| `GPNF` | `{ {0, 0, 1} }` | GPIO functions: `{function, index of the GpioIo resource, active level}` (`sub_401694` → `sub_40151C`, table `dword_43BDA0`, 28 bytes per entry) |
| `PPNF` | see below | Per-device resources (`sub_401CB0` → `sub_401910`, table `dword_43BD90`, 16 bytes per entry) |

`PPNF` returns one package per ACDB device id: `{device id, {type, id, phase}, …}`. Entry 0 is the default, used for every device id that has no entry of its own (`sub_40EEA0`). The phase tells when the resource is switched on: 1 = at [acquire](#ioctl-0x50012004--0x50012008--0x5001200c--0x50012010--0x50012018--0x5001201c--adie-codec-device) (off at release), 2 = at activate (off at deactivate) (`sub_4107B4` on / `sub_410A24` off, device id 1–200).  
| Type | Resource | Handler |
|------|----------|---------|
| 0 | Power framework component `id` (reference counted, `sub_40EEE8`) | `PoFxActivateComponent` / `PoFxIdleComponent` |
| 1 | GPIO function `id` of `GPNF` (reference counted, `sub_40F300`) | [IOCTL_GPIO_WRITE_PINS](#gpio) |
| 2 | ACPI method `HPAM` (`sub_4010A8`, signature `AeiC`, 2 integer arguments: device id, 1 = on / 0 = off) | Not present in the Lumia 520 DSDT |
| 3 | PMIC loudspeaker `id` | On: speaker enable, unmute, CD gain 13. Off: speaker disable. See [IOCTL 0x8012xxxx](#ioctl-0x80120fa0--0x80120fa4--0x80120fb0--pmic-loudspeaker) |

`PPNF` of the Lumia 520:  
| Device id | Resources | Meaning |
|-----------|-----------|---------|
| 0 (default) | `{0, 0, 1}` | PoFx component 0 at acquire |
| 0x0E (14) | `{0, 0, 1}`, `{3, 0, 2}` | PoFx component 0 at acquire, loudspeaker 0 at activate |
| 0x44 (68) | `{0, 0, 1}`, `{3, 0, 2}` | Same |
| 0xC8 (200) | `{0, 0, 1}`, `{3, 0, 2}` | Same |

So the ACDB devices 14, 68 and 200 are the loudspeaker devices (compare with the values 14, 15 and 200 tested by [qcq6ad8930.sys](./qcq6ad8930.md) for the speaker ports).

### Device table

`dword_43BB00`: 17 entries of 24 bytes, one per ACDB device in use:  
| Offset | Comment |
|--------|---------|
| 00-03 | ACDB device id |
| 04-07 | State: 0 = free, 1 = acquired, 2 = active |
| 08-0B | Connected Rx device id (set by [0x50012040](#ioctl-0x50012040--0x50012044--connect--disconnect)) |
| 0C-0F | Connected Tx device id |
| 10-13 | Connection value from the ACDB (`dword_43BD8C`) |
| 14-17 | Connection type: 0 = none, 1 = AFE loopback sent to Q6, 2 = codec internal ? |

### Power framework

`sub_40A100` registers the device with `PoFxRegisterDevice` (one component, callbacks `sub_409E14`, `sub_409E48`, `sub_409F08`, `sub_409FC0`, `sub_40A038`) and calls `PoFxStartDevicePowerManagement`. The component has 2 idle states: F0 (latency 0, residency 0, nominal power 500) and F1 (latency 2, residency 5, nominal power 50), like the components of [qcaudhwi8930.sys](./qcaudhwi8930.md#power-management). It is activated by the `PPNF` resources of type 0 (`sub_40A478` / `sub_40A3D8`); the clocks behind it are given to the PEP by the `\_SB.ACHW` entry of `DCFG` (`lcc_cdc_i2s_spkr_osr_clk`…).

### GPIO

`sub_40FC7C` builds `\Device\RESOURCE_HUB\<connection id>` (`%0*I64x`) from the `GpioIo` resource and opens it. `sub_40F08C` writes one pin with `IOCTL_GPIO_WRITE_PINS` (0x480004, 1 byte, `WdfRequestSend`). The value written is the `GPNF` active level when switched on, its inverse when switched off (reference counted per function).

### ACDB

`sub_40BD8C` opens the ACDB interface, gets `acdb_ioctl` with [IOCTL 0x50022400](#ioctl-0x50022400) (`sub_40BF5C`) and calls it. Commands used:  
| Command | Function | Use |
|---------|----------|-----|
| 0x11290 / 0x11291 | `sub_40A518` / `sub_40A5D8` | Device type and device info of the ACDB device (AFE port parameters) |
| 0x11298 | `sub_40A5D8`, `sub_40AC88`, `sub_40B26C` | Codec (ADIE) profile of the device, at acquire (`sub_40B5C8` mode 0) and activate (mode 2) |
| 0x111F2, 0x11313 | `sub_40A76C` | ? |
| 0x111DE | `sub_40AF28` | ? |
| 0x111F5, 0x112A0 | `sub_40AFEC` | ? |
| 0x1124E, 0x1270E, 0x1270F | `sub_40B1A8` | Connection of an Rx / Tx device pair, for [0x50012040](#ioctl-0x50012040--0x50012044--connect--disconnect) (mode 4) |
| 0x50022404 | `sub_40CC48` | Registers the ACPH handler 2 (`sub_40CBDC`, 9479-byte answer buffer), so that QACT can reach the codec through [ACPH over DIAG](./qcacdb8930.md#acph-over-diag) |
| 0x50022408 | `sub_40CD6C` | Removes the ACPH handler 2 (deinit) |

### SLIMbus

The codec is reached over the SLIMbus (`\_SB.SLM1`) like in [qcmbhc8930.sys](./qcmbhc8930.md#codec-registers): register address + 0x800 as value element. The logical addresses of 2 SLIMbus devices are requested (`sub_41294C` → `sub_41A52C`), each with 2 possible enumeration addresses tried alternately, up to 10 times:  
| Device | Enumeration addresses | Comment |
|--------|-----------------------|---------|
| 0 | `00 01 00 00 17 02` / `00 01 70 00 17 02` | Codec (manufacturer 0x0217 Qualcomm, part id 0x0000 or 0x0070: two Sitar versions ?) |
| 1 | `00 00 00 00 17 02` / `00 00 70 00 17 02` | Second SLIMbus device of the codec (interface device ?) |

Register accesses are bracketed by the SLIMbus votes 0x85B5240C / 0x85B52410 (`sub_412C10` / `sub_412E60`).

---

### IOCTL 0x50012004 / 0x50012008 / 0x5001200C / 0x50012010 / 0x50012018 / 0x5001201C — ADIE codec device

These IOCTLs are processed by Qcsitarcodec8930.sys (`EvtIoDeviceControl` `sub_406A2C` → `sub_402BC8`). 0x50012004…0x50012010 are sent by [qc8x60aud.sys](./qc8x60aud.md#ioctl-0x50012004--0x50012008--0x5001200c--0x50012010--adie-codec).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x801 / 0x802 / 0x803 / 0x804 / 0x806 / 0x807 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x50012004 ADIE_CODEC_DRIVER_IOCTL_ACQUIRE_DEVICE (`sub_4038F0`) | 12 | 0 or 8 |
| 0x50012008 ADIE_CODEC_DRIVER_IOCTL_RELEASE_DEVICE (`sub_4045E8`) | 12 | 0 or 4 |
| 0x5001200C ADIE_CODEC_DRIVER_IOCTL_ACTIVATE_DEVICE (`sub_403F94`) | 12 | 0 or 4 |
| 0x50012010 ADIE_CODEC_DRIVER_IOCTL_DEACTIVATE_DEVICE (`sub_4042F0`) | 12 | 0 or 4 |
| 0x50012018 ? (`sub_4048F0`) | 12 | 0 or 4 |
| 0x5001201C ? (`sub_404B70`) | 12 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | ? (not read) |
| 04-07 | 01 00 00 00 | ? (not read) |
| 08-0B | ? | Kernel pointer. 0x50012004: to a 16-byte descriptor `{device id, ?, ?, ?}` (the last value is kept as 16 bits). Other codes: to the ACDB device id (first dword) |

Outputbuffer (optional: when there's no output buffer a local one is used; when there is one, its size must be exactly 8 for 0x50012004, 4 otherwise):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | 0x50012004 only: a 16-bit value of the codec profile (`sub_40CF6C`), and the information length is set to 2 ?. Other codes: the status below |
| 04-07 | ? | 0x50012004 only: status |

Status (`dword_43BAE0`, also returned by [0x50012020](#ioctl-0x50012020--0x50012024--codec-registers)): 0 = OK, -1 = driver not initialised yet, -2 = bad output buffer, -3 = bad input buffer, -4 = unknown IOCTL, -5 = unknown device or wrong state, -6 = device table full / no memory, -7 = per-device resources ([PPNF](#acpi-methods)), -8 = codec, -9 = ACDB, -10 = Q6 (AFE).

What they do (all calls are serialised by a mutex, and run only once the driver is initialised):  
| Code | Required state | Steps | New state |
|------|----------------|-------|-----------|
| 0x50012004 acquire | not in the table (else -5), a free entry (else -6) | `PPNF` resources phase 1, ACDB codec profile (mode 0), parse it (`sub_40CF6C`), add the AFE port to the port table (`sub_4070C0`, opens `\Device\Q6Audio`) | 1 |
| 0x50012008 release | 1 | Codec path off (`sub_40D9B4`), remove the AFE port (`sub_407590`), ACDB release (mode 1), `PPNF` resources phase 1 off | 0 (free) |
| 0x5001200C activate | 1 | Codec path on (`sub_40DC10`), AFE port configure + 0xADAD2B89 + start (`sub_4076EC`, [IOCTL 0xADAD2B8D / 0xADAD2B89 / 0xADAD2B91](#ioctl-0xadad2b89--0xadad2b8d--0xadad2b91--0xadad2b95--0xadad2b99--0xadad2bd5)), `PPNF` resources phase 2 (loudspeaker) | 2 |
| 0x50012010 deactivate | 2 | `PPNF` resources phase 2 off, disconnect if connected (as [0x50012044](#ioctl-0x50012040--0x50012044--connect--disconnect)), AFE port stop (`sub_407F14`, [0xADAD2B95](#ioctl-0xadad2b89--0xadad2b8d--0xadad2b91--0xadad2b95--0xadad2b99--0xadad2bd5)), codec path off (`sub_40DE04`) | 1 |
| 0x50012018 ? | 2 | ACDB profile again (mode 2) and apply it to the codec (`sub_40DFF8` → `sub_4170EC`); on failure the profile buffers are freed (mode 3) | 2 |
| 0x5001201C ? | 2 | Codec step `sub_40E178` (→ `sub_416354`), then frees the ACDB profile buffers (mode 3) | 2 |

NTSTATUS: `STATUS_NO_SUCH_DEVICE` (0xC000000E) for an unknown device, `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) for a wrong state, `STATUS_INVALID_HANDLE` (0xC0000008) for a null descriptor pointer, `STATUS_INVALID_PARAMETER` (0xC000000D) for a bad buffer size, otherwise the status of the failing step.

---

### IOCTL 0x50012014

This IOCTL is processed by Qcsitarcodec8930.sys (`sub_403858`).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x805 (2053) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get version ? | 0 | 8 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 03 00 00 | Constant 0x300 (interface version ?) |
| 04-07 | 00 00 00 00 | Status |

---

### IOCTL 0x50012020 / 0x50012024 — codec registers

These IOCTLs are processed by Qcsitarcodec8930.sys. 0x50012020 is sent by [qc8x60aud.sys](./qc8x60aud.md#ioctl-0x50012004--0x50012008--0x5001200c--0x50012010--adie-codec).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x808 / 0x809 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x50012020 Read codec registers (`sub_404E38` → `sub_415CCC`) | 4 + 20·n (exactly) | 4 + 4·n (exactly) |
| 0x50012024 Write codec registers (`sub_404FC0` → `sub_416010`) | 4 + 20·n (exactly) | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Number of entries n |
| 04-… | ? | n entries of 20 bytes, see below |

Entry:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Access type: 0 = codec register over the SLIMbus; other values: write through another path (`sub_4123D8` with flag 1), read not supported (-4) |
| 04-07 | ? | Register address (16 bits) |
| 08-0B | ? | Read: mask. Write: mask (8 bits) |
| 0C-0F | ? | Read: shift. Write: value (8 bits) |
| 10-13 | ? | Read: receives `(register & mask) >> shift` |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Status (see [status](#ioctl-0x50012004--0x50012008--0x5001200c--0x50012010--0x50012018--0x5001201c--adie-codec-device)) |
| 04-… | ? | 0x50012020 only: the value read for each entry (dword) |

The accesses are done with the SLIMbus vote held ([0x85B5240C / 0x85B52410](#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus)).

---

### IOCTL 0x50012040 / 0x50012044 — connect / disconnect

These IOCTLs are processed by Qcsitarcodec8930.sys (`sub_4050E0` / `sub_40569C`). Sent by [qc8x60aud.sys](./qc8x60aud.md#ioctl-0x50012004--0x50012008--0x5001200c--0x50012010--adie-codec). 0x50012044 is also called internally by the deactivate.

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x810 / 0x811 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x50012040 Connect a device pair (sidetone / loopback ?) | 16 | 4 |
| 0x50012044 Disconnect a device pair | 16 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ACDB device id A |
| 04-07 | 00 00 00 00 or 01 00 00 00 | Direction of A |
| 08-0B | ? | ACDB device id B |
| 0C-0F | 01 00 00 00 or 00 00 00 00 | Direction of B: must be the opposite of A (else status -3, `STATUS_INTERNAL_ERROR` 0xC00000E5). The device with direction 0 is kept as Rx, the other as Tx ? |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Status |

Both devices must be active (state 2). Connect: both must be unconnected; the ACDB is asked for the connection (`sub_40B5C8` mode 4, commands 0x1124E / 0x1270E / 0x1270F); if it returns type 1, [IOCTL 0xADAD2BD5](#ioctl-0xadad2b89--0xadad2b8d--0xadad2b91--0xadad2b95--0xadad2b99--0xadad2bd5) is sent to Q6 with enable = 1. The pair is stored in both [device table](#device-table) entries. Disconnect: the pair must match; type 1 → 0xADAD2BD5 with enable = 0, type 2 → `sub_40E4A0` (codec); then both entries are cleared.

---

### IOCTL 0x50012048 — rm_audio_sr_ioctl

This IOCTL is processed by Qcsitarcodec8930.sys (`sub_405D4C` → `sub_408D90`). Sent by [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x50012048--rm_audio_sr_ioctl) and [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x50012048--rm_audio_sr_ioctl).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x812 (2066) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Audio shared resource request | 12 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Client id (1 = MBHC, 2 = ?) |
| 04-07 | ? | Command (1–0x3F) |
| 08-0B | ? | Kernel pointer to the parameter block |

| Command | Parameter block | Action |
|---------|-----------------|--------|
| 0x01 | – | Init (`sub_408B3C`), once |
| 0x02 | `{resource, enable}` | Shared resource request, reference counted. Resource 1–10 except 3 and 4 (else returns 32); client must be 1 or 2 (else 16). Resource 2 = clock (`SHARED_RESOURCE_CLOCK_BLOCK`), with an arbitration between the clients (`sub_4094F4`); the other resources write codec registers (`sub_4123D8`) |
| 0x04 | `{state}` | Audio state notification (0–7): updates counters, and on some states `sub_409A5C` / `sub_409AB4` ? |
| 0x08 | `{?, ?}` | Client 1 only: stores 2 values (`dword_43B6D8`, `dword_43B6DC`) |
| 0x10 | – | Deinit |
| 0x20 | `{value}` | Stores a value (`dword_421184`) |

The status written to the output buffer is always 0. The NTSTATUS is the return value of `sub_408D90`, i.e. 0 or one of the positive codes 16 / 32 / 64, which are success codes for `NT_SUCCESS`.

---

### IOCTL 0x5001204C

This IOCTL is processed by Qcsitarcodec8930.sys (`sub_405C78` → `sub_407344`).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x813 (2067) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 6 | 0 or 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | a |
| 02-03 | ? | b |
| 04-05 | ? | c |

Forwarded to Q6 as [IOCTL 0xADAD2B99](#ioctl-0xadad2b89--0xadad2b8d--0xadad2b91--0xadad2b95--0xadad2b99--0xadad2bd5) with the 8 bytes `{c, b, 1, a}` (16-bit values). The output status is always 0. Senders: ?

---

### IOCTL 0xADAD2B89 / 0xADAD2B8D / 0xADAD2B91 / 0xADAD2B95 / 0xADAD2B99 / 0xADAD2BD5

These IOCTLs are sent by Qcsitarcodec8930.sys to [qcq6ad8930.sys](./qcq6ad8930.md#ioctl-0xadad2b89--0xadad2b8d--0xadad2b91--0xadad2b95--0xadad2b99--0xadad2bd5) (`\Device\Q6Audio`), protected by a mutex (500 ms timeout).

| Property | Value |
|----------|-------|
| Device | 0xADAD |
| Function | 0xAE2 / 0xAE3 / 0xAE4 / 0xAE5 / 0xAE6 / 0xAF5 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0xADAD2B8D AFE port configure (`sub_4076EC`, activate) | \Device\Q6Audio | 100 | 0 |
| 0xADAD2B89 ? (`sub_4076EC`, activate) | \Device\Q6Audio | 76 | 0 |
| 0xADAD2B91 AFE port start (`sub_4076EC`, activate) | \Device\Q6Audio | 100 | 0 |
| 0xADAD2B95 AFE port stop (`sub_407F14`, deactivate) | \Device\Q6Audio | 100 | 0 |
| 0xADAD2B99 ? (`sub_407344`, [0x5001204C](#ioctl-0x5001204c)) | \Device\Q6Audio | 8 | 0 |
| 0xADAD2BD5 AFE loopback ? (`sub_4082A8`, [connect / disconnect](#ioctl-0x50012040--0x50012044--connect--disconnect)) | \Device\Q6Audio | 8 | 0 |

Inputbuffer of 0xADAD2B8D / 0xADAD2B91 / 0xADAD2B95: the [AFE port structure](./qcaudhwi8930.md#afe-port-structure), with the SLIMbus device type:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | ? (version) |
| 04-07 | ? | ACDB device id |
| 08-0B | 98 12 01 00 | ACDB device type 0x11298 (SLIMbus) |
| 0C-0F | ? | Sample rate |
| 10-13 | ? | 16-bit value from the port table (+4) |
| 14-15 | ? | Port table +0x1A |
| 16-17 | ? | Port table +0x18 |
| 18-19 | ? | Port table +0x16 |
| 1A-1B | 00 00 | |
| 1C-1D | ? | Number of channels n (port table +0x1C) |
| 1E-… | ? | n 16-bit values (SLIMbus channel numbers ?), then 0 at 0x32 |

Inputbuffer of 0xADAD2B89:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 35 98 12 01 | 0x01129835 ? |
| 04-07 | ? | ACDB device id |
| 08-0B | ? | Sample rate (port table +0x10) |
| 0C-4B | ? | Not initialised |

Inputbuffer of 0xADAD2BD5:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | AFE port of the first device (port table +4) |
| 02-03 | ? | AFE port of the second device |
| 04-05 | ? | Connection value from the ACDB |
| 06-07 | 01 00 or 00 00 | Enable |

The AFE port table (`dword_43B7E0`, 10 entries of 52 bytes) is filled at acquire from the ACDB device info (`sub_4070C0`). Byte +6 of an entry is set to 1 when the port is started and back to 0 when it's stopped.

---

### IOCTL 0x80120FA0 / 0x80120FA4 / 0x80120FB0 — PMIC loudspeaker

These IOCTLs are sent by Qcsitarcodec8930.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8012xxxx--loudspeaker) (interface `{1408ACF4-24D1-43AB-8F80-2F7D8AEDD372}`, opened by `sub_40E8C8`), for the `PPNF` resources of type 3.

| Property | Value |
|----------|-------|
| Device | 0x8012 |
| Function | 0x3E8 / 0x3E9 / 0x3EC |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x80120FA0 IOCTL_PM_SPEAKER_ENABLE (`sub_40E9CC`) | interface `{1408ACF4-…}` | 8 | 4 |
| 0x80120FA4 IOCTL_PM_SPEAKER_MUTE (`sub_40ED08`) | interface `{1408ACF4-…}` | 8 | 4 |
| 0x80120FB0 IOCTL_PM_SPEAKER_CD_GAIN (`sub_40EB64`) | interface `{1408ACF4-…}` | 12 | 4 |

Inputbuffer of 0x80120FA0 / 0x80120FA4:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Speaker id (`PPNF` id) |
| 04 | 01 / 00 | Enable / mute flag |

Inputbuffer of 0x80120FB0:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Speaker id |
| 04-07 | 0D 00 00 00 | Gain 13 |
| 08 | 00 | ? |

At activate (`sub_4107B4` type 3): enable (1), mute (0), CD gain 13. At deactivate (`sub_410A24`): enable (0), then the target is closed (`sub_40E990`).

---

### IOCTL 0x85B52000 / 0x85B52400 / 0x85B52404 / 0x85B5240C / 0x85B52410 — SLIMbus

These IOCTLs are sent by Qcsitarcodec8930.sys to the SLIMbus driver [qcslimbus8930.sys](./qcslimbus8930.md) (interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}`). Same codes as [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus).

| Property | Value |
|----------|-------|
| Device | 0x85B5 |
| Function | 0x800 / 0x900 / 0x901 / 0x903 / 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x85B52000 Get logical address (`sub_412510`) | interface `{88EEFAB5-…}` | 6 | 1 |
| 0x85B52400 Read value element (`sub_411760`) | interface `{88EEFAB5-…}` | ? | ? |
| 0x85B52404 Write value element (`sub_41148C`) | interface `{88EEFAB5-…}` | ? | 0 |
| 0x85B5240C Acquire (`sub_40F82C`, `sub_412C10`) | interface `{88EEFAB5-…}` | 0 | 0 |
| 0x85B52410 Release (`sub_40F9EC`, `sub_412E60`) | interface `{88EEFAB5-…}` | 0 | 0 |

Inputbuffer of 0x85B52000: the 6-byte enumeration address, see [SLIMbus](#slimbus).

---

### IOCTL 0x50022400

This IOCTL is sent by Qcsitarcodec8930.sys to [qcacdb8930.sys](./qcacdb8930.md#ioctl-0x50022400) (`sub_40BF5C`) to get the `acdb_ioctl` entry point.

| Property | Value |
|----------|-------|
| Device | 0x5002 |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get the `acdb_ioctl` entry point | interface `{4EE2204F-14FF-4139-9853-0DA54D6849D5}` | 8 | 0 |

---

### IOCTL 0x8C1F2008

This IOCTL is sent by Qcsitarcodec8930.sys to [qcchipinfo8930.sys](./qcchipinfo8930.md#ioctl-0x8c1f2008) (`sub_402178`), once at init.

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x802 (2050) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get chip id | interface `{FB4F07CD-8D4C-4413-92C2-E2C9CAED9F43}` | 0 | 4 |

---

### Interface GUID

Qcsitarcodec8930 (ADIE codec) Interface Class GUID  
`{3FE58EBD-6A7D-4760-A01F-66369C501AB0}`

### Other GUID

ETW provider  
`{597928F9-37CE-4BAD-BBA4-AE1A12CBDD12}`

WPP control GUID  
`{D3D7C968-4842-4C61-994E-2AAD4DBA2C18}`
