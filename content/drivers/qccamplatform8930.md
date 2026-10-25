## Qccamplatform8930.sys

Camera Platform Driver ("PlatformKMD", "Camera Platform KMD").  
It's the platform driver of the Nokia camera stack: a KMDF driver for the ACPI device `\_SB.CAMP` (`QCOM0775`). It drives the camera control I2C bus directly (QUP of GSBI4, no I2C controller driver involved), switches 2 GPIO lines through the Resource Hub, and forwards the power requests of the camera modules to PoFx (and so to [qcpep8930.sys](./qcpep8930.md)).  
Its clients are [qccamflash8930.sys](./qccamflash8930.md#internal-ioctl-0x2320030x23201f--camera-platform) and [qccamfrontsensor8930.sys](./qccamfrontsensor8930.md#internal-ioctl-0x2320030x23201f--camera-platform). They open it through its device interface and send it internal IOCTLs (power, I2C read/write, I2C clock, GPIO).  
PDB path: `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\Driver\fre\qccamplatform8930.pdb`.

There's no named device object and no symbolic link: the device is reached through its device interface (see [Interface GUID](#interface-guid)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qccamplatform` ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0775\1B` ?  

The driver doesn't use its `Parameters` key. The value is read with `ZwOpenKey` + `ZwQueryValueKey` from an absolute path (`sub_401BD8`, raw data copied to the destination, max 256 bytes):  
| Registry key | Registry value | value | comment |
|--------------|----------------|-------|---------|
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | TraceEnable | 0 / 1 | Read in `DriverEntry`. 1 = register the ETW provider and send the log strings to ETW. Same value as [qccamavs8930.sys](./qccamavs8930.md) and [qccamflash8930.sys](./qccamflash8930.md) |

The `DbgPrintEx` output of the log function (`sub_401D18`) is enabled by `dword_406B0C`, which is never written: when `TraceEnable` ≠ 1 the log strings are dropped. Log levels 2, 4 and 5 are always dropped, and nothing is logged at DISPATCH_LEVEL.

GUID of the ETW provider (manifest based, only registered when `TraceEnable` = 1, shared with the other camera drivers):  
`{62774a98-5c63-43e1-8b13-3c5e8958e414}`  
The log function picks the event from the module name passed by the caller: this driver always uses "PlatformKMD", event id 3007 (0xBBF). The other ids of the shared table: 3000 VFEKMD, 3002 GeminiKMD, 3003 SensorKMD, 3004 MercuryKMD, 3005 FlashKMD, 3006 FrontSensorKMD.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\RESOURCE_HUB\<connection id>` | [acpiex.sys](./acpiex.md#opening-a-connection-deviceresource_hubid) → GPIO controller of `\_SB.GIO0` | GPIO writes (`IOCTL_GPIO_WRITE_PINS`), see [GPIO](#gpio) |
| PoFx | [qcpep8930.sys](./qcpep8930.md) | Component 0 of `\_SB.CAMP`: regulators and GSBI4 clocks, see [Power management](#power-management) |

### ACPI resources

`_CRS` of `\_SB.CAMP` in the DSDT ([dsdt.dsl](../acpi/dsdt.dsl)), `_DEP` on `\_SB.PEP0`, `\_SB.PMIC`:  
| # | Resource | Use |
|---|----------|-----|
| 0 | `Memory32Fixed` 0x16300000, 0x20 | GSBI4 control (`dword_406B10`) |
| 1 | `Memory32Fixed` 0x16380000, 0x408 | GSBI4 QUP (`dword_406B18`) |
| 2 | `Memory32Fixed` 0x008020B8, 0x4 | ? (`dword_406B14`), right after the TLMM range. Written with 2 at each QUP init |
| 3 | `GpioIo` (Exclusive, PullNone) `\_SB.GIO0` pin 107 (0x6B) | GPIO id 0 |
| 4 | `GpioIo` (Exclusive, PullNone) `\_SB.GIO0` pin 76 (0x4C) | GPIO id 1 |

The memory resources are recognised by their position in the list (0, 1, 2), not by their address, and mapped with `MmMapIoSpace(MmNonCached)`. They are never unmapped. Each `GpioIo` connection id (`CmResourceTypeConnection`, class GPIO, type IO) is stored in the device context in order: the first one is GPIO id 0.

### Driver initialisation

| Callback | Function | Comment |
|----------|----------|---------|
| `EvtDriverDeviceAdd` | sub_40F038 | Device context `DEVICE_CONTEXT`, request context `REQUEST_CONTEXT`, `WdfDeviceCreateDeviceInterface` `{8d73ce35-93cf-4795-8db9-40bbe130d859}`, default queue (`sub_40F5D0`, sequential, `QUEUE_CONTEXT` + spin lock) with only `EvtIoInternalDeviceControl` |
| `EvtDevicePrepareHardware` | 0x40F218 | Maps the memory resources, stores the GPIO connection ids, then PoFx registration (`sub_401158`) |
| `EvtDeviceReleaseHardware` | 0x40F358 | `PoFxUnregisterDevice` (`sub_4014D4`) |
| `EvtDeviceSelfManagedIoInit` / `Restart` | 0x401108 | Starts the default queue |
| `EvtDeviceSelfManagedIoSuspend` | 0x40F1C8 | Stops the default queue |

Device context:  
| Offset | Comment |
|--------|---------|
| 0x00-0x4F | GPIO connection ids (8 bytes each) |
| 0x50 | WDM device object |
| 0x54 | PoFx handle |
| 0x58 | Activation count (internal IOCTLs 0x23201B / 0x23201F) |

### Power management

The driver registers itself to PoFx (`PoFxRegisterDevice`, `sub_401158`) in `EvtDevicePrepareHardware`, waits 10 ms and calls `PoFxStartDevicePowerManagement`. 1 component:  
| Field | Value |
|-------|-------|
| Component GUID | `{ffffffff-ffff-ffff-ffff-ffffffffffff}` (`dword_40DB40`, never written) |
| IdleStateCount | 2 |
| DeviceIdleState | 1 |
| F0 | TransitionLatency 0, ResidencyRequirement 0, NominalPower 500 |
| F1 | TransitionLatency 2, ResidencyRequirement 5, NominalPower 50 |

| Callback | Function | Comment |
|----------|----------|---------|
| ComponentActiveCondition | sub_401404 | Log only |
| ComponentIdleCondition | sub_4013C4 | `PoFxCompleteIdleCondition` |
| ComponentIdleState | sub_401368 | `PoFxCompleteIdleState` |
| DevicePowerRequired | sub_401430 | `PoFxReportDevicePoweredOn` |
| DevicePowerNotRequired | sub_401470 | `PoFxCompleteDevicePowerNotRequired` |
| PowerControl | sub_4014AC | Returns 0 |

Internal IOCTL 0x23201B ("PlatformDeviceActivate", `sub_401510`) calls `PoFxActivateComponent(0, PO_FX_FLAG_BLOCKING)` when the activation count is 0, then increments it. Internal IOCTL 0x23201F ("PlatformDeviceDeactivate", `sub_401598`) decrements it and calls `PoFxIdleComponent(0, PO_FX_FLAG_ASYNC_ONLY)` when it reaches 0. The count isn't checked for underflow.

The F-state of `\_SB.CAMP` in the PEP configuration (DSDT) votes for the regulators `PM_VREG_RESOURCE_ID_SMPS2` and `PM_VREG_RESOURCE_ID_LDO2`, waits 10, enables `cc_gsbi4_qup_apps_clk` at 24 MHz (0x016E3600) and `cc_gsbi4_hclk`, and configures TLMM GPIOs (first one GPIO 20 ?, the GSBI4 I2C lines ?).

### I2C (QUP)

The camera control bus is the QUP of GSBI4, programmed directly through resource 1 (`sub_40213C`, `sub_4024F4`, `sub_40287C`, `sub_402278`). The register offsets and bits match the Linux `i2c-qup` driver (QUP v1, tags v1):  
| Offset | Register | Use |
|--------|----------|-----|
| 0x000 | QUP_CONFIG | `0x320F` (bits 6-7 kept): N = 15, mini core = I2C master (2), core and app clocks on |
| 0x004 | QUP_STATE | 0 = reset, 1 = run, 3 = pause; bit 2 = state valid |
| 0x008 | QUP_IO_MODES | Output FIFO mode, unpack on, pack off. Input block mode for reads > 16 bytes |
| 0x00C | QUP_SW_RESET | Written with 1 |
| 0x018 | QUP_OPERATIONAL | Bit 8 output service, bit 9 input service, bit 11 max input done, bit 13 input block request |
| 0x110 | QUP_OUT_FIFO | Tags: 0x100 \| address = START, 0x200 \| byte = DATA, 0x300 \| byte = DATA + STOP, 0x400 \| count = read |
| 0x200 | QUP_MX_INPUT_COUNT | Read size, block mode (> 16 bytes) |
| 0x208 | QUP_MX_READ_COUNT | Read size, FIFO mode (≤ 16 bytes) |
| 0x218 | QUP_IN_FIFO | Read data |
| 0x400 | I2C_MASTER_CLK_CTL | FS divider (bits 0-7) = 24000 / (2 × kHz) − 3: 27 at 400 kHz, 117 at 100 kHz |
| 0x404 | I2C_STATUS | Bit 3 = error (NACK ?), bit 8 = bus active |

QUP init (`sub_40213C`): GSBI4 control (resource 0) `= (value & 0xF8F) | 0x20` (protocol code 2 = I2C), QUP software reset, config, IO modes, state run, clock divider, then resource 2 `= 2`. It's called at the first power on and **at the end of every transfer** (success or failure): each transfer leaves the QUP reset with the current clock.

The I2C clock (`dword_4061C8`) is 400 kHz by default, set by internal IOCTL 0x232013, and reset to 400 kHz when the power count goes back to 0. The new value is only used at the next QUP init.

Transfers are polled (no interrupt): status loops of 1000 iterations of 5 µs (`sub_402A7C`, `KeQueryPerformanceCounter` + `KeStallExecutionProcessor`), and 100 iterations of 200 µs for the read data. A timeout or an error flag returns `STATUS_UNSUCCESSFUL`.

### GPIO

`sub_40161C` (internal IOCTL 0x232017) writes one GPIO:
1. Builds `\Device\RESOURCE_HUB\<connection id>` (`%0*I64x`, 16 hex digits) from the connection id of GPIO id `n` in the device context.
2. `WdfIoTargetCreate` + `WdfIoTargetOpen` (open by name, `FILE_GENERIC_WRITE`, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`).
3. Sends `IOCTL_GPIO_WRITE_PINS` (0x480004, Device 0x48, Function 0x1, METHOD_BUFFERED) with a 1-byte buffer (same memory as input and output): the value.
4. At DISPATCH_LEVEL the request is sent with `WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`. Otherwise it's sent without options (asynchronous), the status is read at once and the driver waits 10 ms.
5. Closes and deletes the target ("WRITE GPIO SUCCESSFUL" / "WRITE GPIO FAILED").

| GPIO id | Pin | Comment |
|---------|-----|---------|
| 0 | `\_SB.GIO0` 107 | ? (camera reset / standby ?) |
| 1 | `\_SB.GIO0` 76 | ? |

The GPIO id isn't checked: an id ≥ 2 reads an empty slot (connection id 0) or goes past the 10 slots of the context. The result of the write is ignored: the IOCTL is always completed with `STATUS_SUCCESS`.

---

### internal IOCTL 0x232003…0x232023 — camera platform

These internal IOCTLs are processed by Qccamplatform8930.sys (`EvtWdfIoQueueIoInternalDeviceControl`, 0x40176C). They are sent by [qccamflash8930.sys](./qccamflash8930.md#internal-ioctl-0x2320030x23201f--camera-platform) and [qccamfrontsensor8930.sys](./qccamfrontsensor8930.md#internal-ioctl-0x2320030x23201f--camera-platform).

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x800…0x808 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

The input buffer (`WdfRequestRetrieveInputBuffer`) is used by all the codes except 0x23200B, which uses the output buffer (`WdfRequestRetrieveOutputBuffer`). The minimum length requested is the length of the request: the sizes aren't checked. A failure to get a buffer completes the request with that status.

| IOCTL | Function | Name | InputBuffer size | OutputBuffer Size | Status | Comment |
|-------|----------|------|------------------|-------------------|--------|---------|
| 0x232003 | 0x800 | Power on | 0 | 0 | `STATUS_UNSUCCESSFUL` if a memory resource isn't mapped or the QUP init fails | Power count +1. QUP init when the count was 0 (the count is incremented even when the init fails) |
| 0x232007 | 0x801 | Power off | 0 | 0 | Success | Power count −1. At 0: I2C clock back to 400 kHz. No hardware access |
| 0x23200B | 0x802 | I2C read | 0 | 36 | `STATUS_UNSUCCESSFUL` on error | [I2C transfer](#i2c-transfer) in the **output** buffer (`sub_40287C`) |
| 0x23200F | 0x803 | I2C write | 36 | 0 | `STATUS_UNSUCCESSFUL` on error | [I2C transfer](#i2c-transfer) (`sub_4024F4`). Max 255 data bytes |
| 0x232013 | 0x804 | Set I2C clock | 4 | 0 | Success | ULONG: 100 or 400 (kHz). Other values and NULL buffer: ignored |
| 0x232017 | 0x805 | GPIO write | 8 | 0 | Success | See [GPIO](#gpio) and below |
| 0x23201B | 0x806 | Activate | 0 | 0 | Success | PoFx component active, see [Power management](#power-management) |
| 0x23201F | 0x807 | Deactivate | 0 | 0 | Success | PoFx component idle |
| 0x232023 | 0x808 | I2C sequential write | 36 | 0 | `STATUS_UNSUCCESSFUL` on error | See [0x232023](#internal-ioctl-0x232023--i2c-sequential-write) (`sub_402278`). Not sent by the flash and front sensor drivers |
| other | | | | | Success | Ignored |

> [!NOTE]
> The flash and front sensor drivers send the I2C write as an `IRP_MJ_DEVICE_CONTROL` (not internal) when they run at DISPATCH_LEVEL. This driver has no `EvtIoDeviceControl`: KMDF fails these requests (`STATUS_INVALID_DEVICE_REQUEST`).

> [!NOTE]
> METHOD_NEITHER, and the data pointer inside the I2C transfer is used as is: kernel-mode callers only.

Inputbuffer of 0x232017:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | GPIO id (index of the `GpioIo` resource: 0 = pin 107, 1 = pin 76) |
| 04 | 01 | Value written to the pin (only the low byte is used) |

#### I2C transfer

Input of 0x23200F and 0x232023, output of 0x23200B (36 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Not used |
| 04 | 50 | 8-bit slave address (bit 0 = R/W: the driver ORs 1 for the read phase), e.g. 0x50 / 0x60 flash, 0x52 RGBC, 0x20 front sensor |
| 08-0B | 02 00 00 00 | Flags, see below |
| 0C-0F | ? | Not used |
| 10-13 | ? | Pointer to the data |
| 14-15 | 00 00 | Register address (not used by 0x232023) |
| 16-17 | 01 00 | Number of data bytes |
| 18-19 | 01 00 | 0x232023 only: number of writes |
| 1A-23 | ? | Not used |

Flags:  
| Bit | Mask | Meaning |
|-----|------|---------|
| 1 | 0x002 | 16-bit register address (sent high byte first). Else 8-bit |
| 6 | 0x040 | Read: STOP after the register address (instead of a repeated START) |
| 8 | 0x100 | Write: no STOP at the end of the transfer (and no wait for the bus to be idle). Not used by the read |
| 9 | 0x200 | Read: no register address phase |

Bus sequence:
- Write (0x23200F): START + address, register (1 or 2 bytes), data, STOP. The QUP is paused while the FIFO is filled, then run.
- Read (0x23200B): START + address, register, START + (address \| 1), read `count` bytes into the data pointer.

### internal IOCTL 0x232023 — I2C sequential write

This IOCTL is processed by Qccamplatform8930.sys (`sub_402278`).

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x808 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| I2C sequential write | 36 | 0 |

Inputbuffer: an [I2C transfer](#i2c-transfer). It performs `count` (bytes 18-19) I2C writes to the same slave, each one with its own START and STOP. Write `i` sends `r + len` bytes from `data + i × (r + len)`, where `r` = 2 when the flags are exactly 2 and 1 otherwise, and `len` = bytes 16-17. The register address is inside the data: the data buffer is a table of `[register, value…]` entries. The register field (bytes 14-15) isn't used. The writes stop at the first error (`STATUS_UNSUCCESSFUL`).

---

### Interface GUID

Camera platform interface (opened by qccamflash8930.sys and qccamfrontsensor8930.sys)  
`{8d73ce35-93cf-4795-8db9-40bbe130d859}`
