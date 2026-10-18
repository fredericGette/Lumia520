## Qcgsbi8930.sys

GSBI (General Serial Bus Interface) configuration driver.  
On the MSM8930 each of the 12 GSBI blocks can be wired to an I2C, SPI, UART or UIM core. The protocol is chosen by the field `PROTOCOL_CODE` of the GSBI control register (`GSBI_CTRL_REG`, offset 0 of each GSBI block). This driver only sets that field: it reads the list of GSBI blocks to configure, with their physical address and protocol, from the ACPI method `CONF` of its device node. Then, at the first D0 entry after start, it writes the protocol code of each listed GSBI.  
It has no other function. It has no IOCTL interface, no device interface and no peer driver other than ACPI. It is needed before the drivers of the serial cores that use the GSBI blocks can work: on the Lumia 520, the I2C controller driver [qci2c8930.sys](./qci2c8930.md), whose 3 ACPI nodes depend on this one.  
Build path found in the binary: `P:\gsbi\rel\8.2.1.1\arm\Release\qcgsbi8930.pdb`.

ACPI node: `\_SB.GSBI`, `_HID` = `QCOM0145`, `_UID` = 1.  
On the Lumia 520 only GSBI3, GSBI9 and GSBI12 are configured, all as I2C (see [Lumia 520 values](#lumia-520-values)).

There's no named `\Device\` object and no symbolic link (the WDF device is unnamed).

There's no parameters in the registry.

GUID of the ETW provider (WPP control GUID, registered with `EtwRegisterClassicProvider`):  
`{3B8DEC2F-E285-4A0A-A3C0-2F1F792B7888}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of the device (default I/O target) | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` `CONF`, see below |
| `\_SB.I2C3`, `\_SB.I2C9`, `\_SB.IC12` (`QCOM0180`) | [qci2c8930.sys](./qci2c8930.md) | I2C controller driver. Not called by this driver. These 3 nodes declare `_DEP` on `\_SB.GSBI`, so Windows starts them only after this driver has started |

Pool tags: `qgs1` (driver, `WDF_DRIVER_CONFIG.DriverPoolTag`), `qgs2` (output buffer of the `CONF` evaluation).

### Device setup

`EvtDriverDeviceAdd` → `GsbiCreateDevice` (sub_4010AC):
- PnP/power callbacks: `EvtDevicePrepareHardware` (sub_401260), `EvtDeviceReleaseHardware` (sub_401374), `EvtDeviceD0Entry` (sub_40145C), `EvtDeviceD0Exit` (sub_401530), `EvtDeviceSurpriseRemoval` (sub_401424).
- Device context `GSBI_DEVICE` (0xC8 bytes, see below).
- `WdfDeviceSetStaticStopRemove(device, FALSE)`: the device can't be stopped or removed.
- A default sequential queue that isn't power-managed (`GsbiQueueInitialize`, sub_401CB0). It has only `EvtIoRead` and `EvtIoWrite`, and both complete the request with `STATUS_UNSUCCESSFUL` (0xC0000001). There's no `EvtIoDeviceControl`, so the framework rejects every IOCTL.
- `WdfDeviceAssignS0IdleSettings`: `IdleCannotWakeFromS0`, DxState = `PowerDeviceD3`, IdleTimeout = 50 ms, `IdleAllowUserControl`, Enabled = `WdfTrue`, IdleTimeoutType = `SystemManagedIdleTimeoutWithHint`.

PnP sequence:
1. `EvtDevicePrepareHardware` evaluates `CONF` (`GsbiEvalAcpiConf`, sub_40165C), then maps each declared GSBI block with `MmMapIoSpace(base, size, MmNonCached)`. If a mapping fails, the loop continues but the callback returns `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A). The WDF hardware resource lists are ignored: the addresses come only from `CONF`. It also clears the "configured" flag (`+0xC4`).
2. `EvtDeviceD0Entry` checks the "configured" flag. If it's clear, it calls `GsbiSetProtocolCode` (sub_401A18) for each declared GSBI and then sets the flag. An error is logged but doesn't fail D0 entry. The GSBIs are therefore programmed only once per start, not at each return from idle (D3).
3. `EvtDeviceD0Exit` does nothing.
4. `EvtDeviceReleaseHardware` unmaps the blocks and zeroes the 12 entries.

`GsbiSetProtocolCode(ctx, gsbiIndex, protocol)`:
1. Return without doing anything if `protocol` = 0. Return `STATUS_NO_SUCH_DEVICE` (0xC000000E) if the index isn't in 1–12.
2. Read `GSBI_CTRL_REG` (offset 0 of the mapped block).
3. If `(reg ^ (protocol << 4)) & 0x70` ≠ 0, write `protocol << 4` to `GSBI_CTRL_REG`. This is a write of the whole register, not a read-modify-write: the other bits (bits 3:0 = CRCI selection in Linux `qcom_gsbi.c`) are cleared. The value isn't masked, so a protocol > 7 would also set bits above bit 6.

`PROTOCOL_CODE` values (bits 6:4 of `GSBI_CTRL_REG`, from Linux `drivers/soc/qcom/qcom_gsbi.c`, not from this binary):  
| Value | Protocol |
|-------|----------|
| 0 | Idle (rejected by `CONF` parsing) |
| 1 | I2C + UIM |
| 2 | I2C |
| 3 | SPI |
| 4 | UART with flow control |
| 5 | UIM |
| 6 | I2C + UART |

> [!NOTE]
> The surprise-removal callback (sub_401424) calls `WdfVerifierKeBugCheck(0x14E, 0x51677330 'Qgs0', 0, 0, 0)`: removing the device crashes the phone (same behaviour as qcbms8930.sys, qcabd8930.sys, qcpmic8930.sys…).

### Device context `GSBI_DEVICE`

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | WDFDEVICE |
| 0x04 + 0x10·(n−1) | 16 | Entry of GSBI*n* (n = 1…12), see below |
| 0xC4 | 4 | "Configured" flag: 1 once the protocol codes have been written |

Entry of a GSBI:  
| Offset | Size | Comment |
|--------|------|---------|
| 0x0 | 4 | Physical base address (from `CONF`) |
| 0x4 | 4 | Size of the region (from `CONF`) |
| 0x8 | 4 | Virtual address returned by `MmMapIoSpace` |
| 0xC | 1 | Valid: 1 if `CONF` declared this GSBI |
| 0xD | 1 | Protocol code (from `CONF`) |

### ACPI CONF

The method `CONF` of the device node returns a list of packages, one per GSBI to configure. `GsbiEvalAcpiConf` loops over the `Count` arguments of the output buffer. It skips the arguments whose type isn't `ACPI_METHOD_ARGUMENT_PACKAGE` (3) and parses each package with `GsbiParseConfPackage` (sub_401590). A malformed package is logged (`STATUS_UNSUCCESSFUL`) and skipped; the next packages are still parsed.

Each package contains 4 integers (`ACPI_METHOD_ARGUMENT_INTEGER`, type 0). Each element is checked: its type must be 0 and its value ≠ 0:  
| Index | Comment |
|-------|---------|
| 0 | GSBI number, 1–12 |
| 1 | Physical base address of the GSBI block |
| 2 | Size of the region to map |
| 3 | Protocol code written in `GSBI_CTRL_REG[6:4]` (see the table above) |

Layout of one package argument in the output buffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 03 00 | Type = package |
| 02-03 | 20 00 | DataLength (32) |
| 04-05 | 00 00 | Element 0: type = integer |
| 06-07 | 04 00 | DataLength (4) |
| 08-0B | | GSBI number |
| 0C-0F | 00 00 04 00 | Element 1: integer, 4 bytes |
| 10-13 | | Physical base address |
| 14-17 | 00 00 04 00 | Element 2: integer, 4 bytes |
| 18-1B | | Size |
| 1C-1F | 00 00 04 00 | Element 3: integer, 4 bytes |
| 20-23 | | Protocol code |

### Lumia 520 values

From the DSDT (OEM ID `QCOMM `, table ID `MSM8930 `, OEM revision 4). `CONF` is `Method (CONF) { Return (GCNF) }`, and `GCNF` is a package of 12 packages:  
| GSBI | Physical base | Size | Protocol | Result |
|------|---------------|------|----------|--------|
| 1 | 0x16000000 | 0x20 | 0 | Rejected |
| 2 | 0x16100000 | 0x20 | 0 | Rejected |
| 3 | 0x16200000 | 0x20 | 2 (I2C) | Mapped and programmed |
| 4 | 0x16300000 | 0x20 | 0 | Rejected |
| 5 | 0x16400000 | 0x20 | 0 | Rejected |
| 6 | 0x16500000 | 0x20 | 0 | Rejected |
| 7 | 0x16600000 | 0x20 | 0 | Rejected |
| 8 | 0x1A000000 | 0x20 | 0 | Rejected |
| 9 | 0x1A100000 | 0x20 | 2 (I2C) | Mapped and programmed |
| 10 | 0x1A200000 | 0x20 | 0 | Rejected |
| 11 | 0x12440000 | 0x20 | 0 | Rejected |
| 12 | 0x12480000 | 0x20 | 2 (I2C) | Mapped and programmed |

The 9 entries with protocol 0 fail the "value ≠ 0" check of `GsbiParseConfPackage`. So each start logs 9 parse errors (`STATUS_UNSUCCESSFUL`), which are harmless: these GSBIs are neither mapped nor touched, and keep the configuration left by the boot loader.

The I2C controllers on these 3 GSBIs, driven by [qci2c8930.sys](./qci2c8930.md) (the QUP core sits at GSBI base + 0x80000 for GSBI3 and GSBI9, and at GSBI base + 0x20000 for GSBI12):  
| ACPI node | `_HID` | `_UID` | GSBI | Memory (`Memory32Fixed`) | Interrupt |
|-----------|--------|--------|------|--------------------------|-----------|
| `\_SB.I2C3` | QCOM0180 | 3 | 3 | 0x16280000, 0x800 | 183 (0xB7) |
| `\_SB.I2C9` | QCOM0180 | 9 | 9 | 0x1A180000, 0x800 | 222 (0xDE) |
| `\_SB.IC12` | QCOM0180 | 12 | 12 | 0x124A0000, 0x800 | 228 (0xE4) |

Devices declared on these buses (`I2cSerialBus` in their `_CRS`, all 400 kHz, 7-bit):  
| Bus | Address | Device | Table |
|-----|---------|--------|-------|
| `\_SB.I2C3` | 0x4B | `\_SB.TCH1` (`NOKIA_TOUCH`, touch screen) | DSDT |
| `\_SB.IC12` | 0x1E | `\_SB.ACC1` (`KXTNK`, Kionix accelerometer) | Nokia SSDT |
| `\_SB.IC12` | 0x39 | `\_SB.PRX1` / `\_SB.ALS1` (`QPDS_T900_PRX` / `_ALS`, proximity / light sensor; present only if register 0x92 reads 0x29) | Nokia SSDT |
| `\_SB.IC12` | 0x23 | `\_SB.PRX2` / `\_SB.ALS2` (`LTR_554ALS_02_PRX` / `_ALS`, LiteOn LTR-554 alternative, driven by [ltr554als02.sys](./ltr554als02.md)) | Nokia SSDT |
| `\_SB.I2C9` | — | none in the tables | |

`\_SB.IC12` also has a `_REG` method that sets `AVBL` when the `GenericSerialBus` (space 9) operation region becomes available.

The power framework description of `\_SB.GSBI` is in the PEP device `\_SB.PEP0` (`QCOM0811`), with one component F0:  
| D-state | Resources |
|---------|-----------|
| D0 | `CLOCK` `cc_gsbi3_hclk`, `cc_gsbi9_hclk`, `cc_gsbi12_hclk`: action 1 (enable ?), 60000000 Hz, 1 |
| D1, D2 | none |
| D3 | The same 3 clocks with action 2 (disable ?) |

Since the driver enables S0 idle (D3 after 50 ms), the GSBI AHB clocks are turned off when nothing uses the device. The protocol code is written only once, at the first D0 entry after start. This is presumably fine because `GSBI_CTRL_REG` keeps its value while the clock is off ?

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcgsbi8930.sys to the ACPI driver (lower device), once in `EvtDevicePrepareHardware` (`GsbiEvalAcpiConf`, sub_40165C), with `WdfIoTargetSendIoctlSynchronously`

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | default I/O target | 8 | 512 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `AeiB` (ACPI_EVAL_INPUT_BUFFER_SIGNATURE) |
| 04-07 | 43 4F 4E 46 | Method name `CONF` |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature `AeoB`, checked |
| 04-07 | | Length |
| 08-0B | | Count of arguments, must be ≠ 0 |
| 0C-.. | | Arguments: one package per GSBI, see [ACPI CONF](#acpi-conf) |

If the IOCTL fails, its status is returned. If the signature is wrong or the count is 0, `STATUS_ACPI_INVALID_DATA` (0xC014000F) is returned. In both cases `EvtDevicePrepareHardware` fails and the device doesn't start.
