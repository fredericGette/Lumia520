## Qcgpio.sys

MSM TLMM (Top Level Mode Multiplexer) GPIO controller driver (GpioClx client).  
It makes the GPIOs of the MSM8930 SoC available as a standard Windows GPIO controller, `\_SB.GIO0`. Other drivers reach them through `GpioIo` / `GpioInt` resources on `\_SB.GIO0` (see [acpiex.sys](./acpiex.md)). Unlike [qcpmicgpio8930.sys](./qcpmicgpio8930.md) and [qcpowerkeygpio8930.sys](./qcpowerkeygpio8930.md), this driver programs the hardware itself: it maps the TLMM registers (`MmMapIoSpace`) and reads and writes them directly. It registers with the GPIO class extension (`msgpioclx.sys`, through `WdfVersionBindClass` on class `GPIOClx` version 1), and GpioClx does all the IOCTL handling and connects the TLMM summary interrupt.  
The number of pins is read from the ACPI method `OFNI` (152 on the Lumia 520).  
PDB path: `E:\build_e\subtask\9BE48985_98\output\gpio\fre\qcgpio.pdb`. Pool tag `tlmm` (per-pin flag array, `NonPagedPoolNx`).

Hardware ID: `QCOM0500` (ACPI node `\_SB.GIO0`, `_UID` 0).  
There's no device name and no symbolic link (the device is created by GpioClx, `WdfDeviceCreate` without a name).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0500\0`  

There's no parameters in the registry.

GUID of the ETW provider (WPP control GUID, registered with `EtwRegisterClassicProvider`):  
`{302C57A4-26D4-4EC3-B754-29025DCD164B}`

WPP trace flags: 0x01 driver (`DriverEntry`, `EvtDriverDeviceAdd`, unload), 0x02 controller (prepare/release/start/stop/basic information), 0x04 I/O pins, 0x08 interrupts, 0x10 register access.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device (ACPI PDO of `\_SB.GIO0`) | acpi.sys | `IOCTL_ACPI_EVAL_METHOD_EX` on `OFNI` (see [ACPI OFNI](#acpi-ofni)) |
| — | msgpioclx.sys | GPIO class extension. Function table at `.data:0x00405AA0` (6 entries): `GPIO_CLX_RegisterClient`, `GPIO_CLX_UnregisterClient`, `GPIO_CLX_ProcessAddDevicePreDeviceCreate`, `GPIO_CLX_ProcessAddDevicePostDeviceCreate`, `GPIO_CLX_AcquireInterruptLock`, `GPIO_CLX_ReleaseInterruptLock` |
| TLMM registers (physical 0x00800000) | — | Mapped from the `_CRS` memory resource, see [Registers](#registers) |

### Lumia 520 ACPI node

`_CRS` of `\_SB.GIO0` (DSDT):  
| Resource | Value | Comment |
|----------|-------|---------|
| `Memory32Fixed` (ReadWrite) | 0x00800000, 0x2000 | TLMM registers. The only memory resource allowed |
| `Interrupt` (Level, ActiveHigh, Shared) | 48 (0x30) | Three times. TLMM summary interrupt (SPI 16 ?). Only counted by the driver: GpioClx connects it |

`OFNI` returns `Buffer { 0x98, 0x00 }`: TotalPins = 152 (GPIO 0–151).

Other drivers that program the same block: [qcpep8930.sys](./qcpep8930.md) writes the TLMM directly (0x00800000) for the `TLMMGPIO` / `TLMMPORT` resources of the PEP device states, and [qcchipinfo8930.sys](./qcchipinfo8930.md) reads the TLMM hardware revision register at 0x00802054.

GPIO connections on `\_SB.GIO0` in the DSDT/SSDT (decoded from the raw `_CRS` buffers; the debounce is in units of 10 µs):  
| Pin | Node (`_HID`) | Resource | Driver / comment |
|-----|---------------|----------|------------------|
| 0, 100, 101, 102 | `\_SB.DISP` (`NOKIA_PANEL`) | `GpioIo` Exclusive, PullNone | [oempanel.sys](./oempanel.md) |
| 1 | `\_SB.DISP` | `GpioIo` Shared, PullDown | [oempanel.sys](./oempanel.md) |
| 11 | `\_SB.TCH1` (`NOKIA_TOUCH`) | `GpioInt` Edge, ActiveLow, Exclusive, Wake, PullUp | [SynapticsTouch.sys](./synapticstouch.md) interrupt |
| 42 | `\_SB.ACHW` (`QCOM0741`) | `GpioIo` Exclusive, PullDown | Audio codec hardware ([qcsitarcodec8930.sys](./qcsitarcodec8930.md#gpio)) |
| 43 | `\_SB.MBGP` (`QCOM2149`) | `GpioInt` Edge, ActiveBoth, Shared, Wake, PullNone, debounce 500 ms + 2 × `GpioIo` | [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#acpi-bfsz-and-gpnf): jack detection interrupt, the 2 `GpioIo` are read as the jack detect and ANC detect ? inputs |
| 43, 51 | `\_SB.MBHC` (`QCOM0746`) | `GpioIo` Exclusive, PullDown | ? |
| 46, 67 | `\_SB.ACC1` (`KXTNK`, SSDT) | `GpioInt` Edge, ActiveLow, Exclusive, PullDown | Accelerometer |
| 49 | `\_SB.ALS1`, `ALS2`, `PRX1`, `PRX2` (SSDT) | `GpioInt` Edge, ActiveLow, Shared, PullUp | [ltr554als02.sys](./ltr554als02.md) |
| 51 | `\_SB.MBGP` | `GpioIo` Exclusive, PullDown | Not listed in `GPNF`: unused by [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#acpi-bfsz-and-gpnf) |
| 52 | `\_SB.TCH1` | `GpioIo` Exclusive, PullNone | [SynapticsTouch.sys](./synapticstouch.md) reset line |
| 58 | `\_SB.DISP`, `MON0` (child of the display adapter) | `GpioIo` Shared, PullUp | `DSI_PANEL_RESET`, [oempanel.sys](./oempanel.md) / [qcdxkm8930.sys](./qcdxkm8930.md) |
| 62 | `\_SB.TICO` (`QCOM0742`) | `GpioInt` Edge, ActiveHigh, Exclusive, PullUp | Audio ? |
| 76, 107 | `\_SB.CAMP` (`QCOM0775`) | `GpioIo` Exclusive, PullNone | [qccamplatform8930.sys](./qccamplatform8930.md) |
| 91 | `\_SB.NEDD` (`NOKI0B00`, SSDT) | `GpioInt` Edge, ActiveHigh, Shared, Wake, PullNone, debounce 200 ms | [NokiaEnergyDriver.sys](./nokiaenergydriver.md) |
| 94 | `\_SB.SDC3` (`QCOM7002`) | `GpioInt` Edge, ActiveBoth, Shared, Wake, PullDown, debounce 300 ms + `GpioIo` | SD card detect ? |
| 98 | `\_SB.EGP0` (`ENOGPIO`) | `GpioIo` Shared, PullUp | ? |
| 104 | `\_SB.PM01` (`QCOM05C0`) | 5 × `GpioInt` Level, ActiveLow, Shared, PullUp | PMIC interrupt line, [qcpmicgpio8930.sys](./qcpmicgpio8930.md) |

The two `ActiveBoth` interrupts (43, 94) and all debounce timeouts only work because GpioClx emulates them (see [QueryControllerBasicInformation](#gpioclx-callbacks)). The hardware only has an active-high/active-low polarity bit.

### Start-up

1. `DriverEntry` (0x408000): registers the WPP provider, `WdfDriverCreate` (`EvtDriverDeviceAdd`, `EvtDriverUnload`), then `GPIO_CLX_RegisterClient` with the registration packet at `.data:0x00405B00`: version 1, size 0x70, controller context size 24 bytes.
2. `EvtDriverDeviceAdd` (0x401AF4): `GPIO_CLX_ProcessAddDevicePreDeviceCreate`, `WdfDeviceCreate`, `GPIO_CLX_ProcessAddDevicePostDeviceCreate`. No PnP/power callbacks of its own.
3. `PrepareController` (sub_40108C) goes through the translated resources:
   * `CmResourceTypeInterrupt`: counted only;
   * `CmResourceTypeMemory`: start and length are saved in the context and the range is mapped with `MmMapIoSpace(MmNonCached)`. A second memory resource → `STATUS_UNSUCCESSFUL` (0xC0000001);
   * any other type: traced and ignored.
   
   No memory resource → `STATUS_UNSUCCESSFUL`. Then `sub_407000` evaluates `OFNI` (see [ACPI OFNI](#acpi-ofni)) and allocates the per-pin flag array (TotalPins bytes, zeroed). On failure, the range is unmapped.
4. `StartController` (sub_401358) does nothing.
5. `StopController` (sub_401398 → sub_401A6C): for every pin routed to the application processor (`GPIO_INTR_CFG_SU` bit 2) with its interrupt enabled, it clears the enable bit and the status. `StartController` doesn't re-enable them.
6. `ReleaseController` (sub_4012BC) unmaps the registers and frees the flag array.
7. `EvtDriverUnload` (0x407640): stops WPP, then `GPIO_CLX_UnregisterClient`.

Controller context (24 bytes):  
| Offset | Comment |
|--------|---------|
| +0x00 | Physical start of the TLMM range (64-bit) |
| +0x08 | Mapped virtual address |
| +0x0C | Length of the range |
| +0x10 | TotalPins (USHORT, from `OFNI`) |
| +0x14 | Per-pin flag array (pool tag `tlmm`), 1 byte per pin = first byte of the `GpioIo` vendor data |

### ACPI OFNI

`sub_407000` sends `IOCTL_ACPI_EVAL_METHOD_EX` (0x32C018) to the default I/O target (`WdfIoTargetSendIoctlSynchronously`), with a 260-byte input and a 22-byte output. The output must have signature `'AeoB'`, exactly 1 argument, of type buffer (2), with a length ≤ 2. Otherwise it returns `STATUS_ACPI_INVALID_DATA` (0xC014000F) and `PrepareController` fails. The buffer is copied into TotalPins (context +0x10).

The name is "INFO" reversed. It's the only ACPI method used.

### Registers

All accesses are 32-bit, at offsets from the mapped TLMM base, each one preceded by a `DSB`. Pin `n` is the TLMM GPIO number. The names come from the Linux `gpio-msm-v2.c` driver (MSM8960 family), which uses the same layout:  
| Offset | Name | Bits used by the driver |
|--------|------|-------------------------|
| 0x0400 + 4·n | `GPIO_INTR_CFG_SU(n)` | Written with 4 when an interrupt is enabled: route the interrupt to the application processor (`TARGET_PROC_SCORPION` in Linux ?). Bit 2 is tested to know if the pin interrupt belongs to this processor |
| 0x1000 + 0x10·n | `GPIO_CFG(n)` | 0–1 pull (0 none, 1 pull-down, 2 keeper, 3 pull-up), 2–5 function select, 6–8 drive strength, 9 output enable. 12–14 cleared when the `GpioIo` has a non-zero drive strength (meaning ?) |
| 0x1004 + 0x10·n | `GPIO_IN_OUT(n)` | 0 input level (read), 1 output level (written) |
| 0x1008 + 0x10·n | `GPIO_INTR_CFG(n)` | 0 enable, 1 polarity (1 = active high / rising), 2 detection (1 = edge, 0 = level), 3 raw status enable |
| 0x100C + 0x10·n | `GPIO_INTR_STATUS(n)` | 0 status. Write 1 to clear |

Pin configuration (sub_401494): the function select and the drive strength already in `GPIO_CFG` are kept. Output → output enable = 1, pull = none. Input → output enable = 0, pull = the requested one.

> [!NOTE]
> The driver never writes the function select. If the boot loader or [qcpep8930.sys](./qcpep8930.md) left a pin muxed to another function (I²C, UART, …), `ConnectIoPins` and `EnableInterrupt` don't switch it back to GPIO (function 0).

### GpioClx callbacks

Registration packet (`GPIO_CLIENT_REGISTRATION_PACKET`, `.data:0x00405B00`):  
| Callback | Function | Comment |
|----------|----------|---------|
| PrepareController | sub_40108C | see [Start-up](#start-up) |
| ReleaseController | sub_4012BC | |
| StartController | sub_401358 | no-op |
| StopController | sub_401398 | disables the enabled interrupts |
| QueryControllerBasicInformation | sub_4071F0 | Version 1, size 16, TotalPins = `OFNI` (152), NumberOfPinsPerBank = 64 (3 banks: 0–63, 64–127, 128–151). Flags 0x61: `MemoryMappedController`, `EmulateDebouncing`, `EmulateActiveBoth`. `ActiveInterruptsAutoClearOnRead`, `FormatIoRequestsAsMasks` and the idle power management flags are cleared |
| QuerySetControllerInformation | — | |
| EnableInterrupt | sub_401C08 → sub_4015EC | |
| DisableInterrupt | sub_401CC0 | |
| UnmaskInterrupt | sub_402078 | |
| MaskInterrupts | sub_401FB4 | |
| QueryActiveInterrupts | sub_401D84 | |
| ClearActiveInterrupts | sub_401EF0 | |
| ConnectIoPins | sub_402160 | |
| DisconnectIoPins | sub_402300 | only checks the pins, writes nothing |
| ReadGpioPins | sub_402424 | |
| WriteGpioPins | sub_40261C | |
| Save/RestoreBankHardwareContext, PreProcessControllerInterrupt | — | |
| ControllerSpecificFunction | sub_402118 | see [below](#controller-specific-function) |
| ReconfigureInterrupt | sub_4020F8 → sub_401894 | |
| QueryEnabledInterrupts | — | |

A GpioClx pin is (bank, pin in bank) with 64 pins per bank, so the absolute pin number = bank × 64 + pin = TLMM GPIO number. Every callback checks that it's < TotalPins (sub_40141C), otherwise `STATUS_INVALID_PARAMETER` (0xC000000D).

#### I/O pins

* **ConnectIoPins**: `ConnectMode` must be input (1) or output (2), otherwise `STATUS_INVALID_PARAMETER`. For each pin:
  * if `VendorDataLength` ≠ 0, the first vendor data byte is stored in the pin's flag byte. It is never cleared, not even by `DisconnectIoPins`;
  * `GPIO_CFG` is configured as above, with the pull mapped as in the table below;
  * if `DriveStrength` ≠ 0, bits 12–14 of `GPIO_CFG` are cleared (sub_401570). The requested strength isn't written to bits 6–8.
* **ReadGpioPins**: reads bit 0 of `GPIO_IN_OUT` for each pin and packs the values into the output buffer, 1 bit per pin (LSB first). If bit 0 of the pin's flag byte is set, the value is inverted.
* **WriteGpioPins**: sets or clears bit 1 of `GPIO_IN_OUT` for each pin, using 1 bit per pin from the input buffer. The vendor "inverted" flag is ignored.

`PullConfiguration` → `GPIO_CFG` pull bits:  
| PullConfiguration | Value written | TLMM pull |
|-------------------|---------------|-----------|
| 1 `PullUp` | 3 | pull-up |
| 2 `PullDown` | 1 | pull-down |
| other (0 `Default`, 3 `None`, vendor values) | 0 | no pull |

The keeper (2) is never used. `PullDefault` also removes the pull.

Vendor data of a `GpioIo` on `\_SB.GIO0` (1 byte used):  
| Bits | Meaning |
|------|---------|
| 0 | Inverted: `ReadGpioPins` returns the inverted level |
| 1–7 | Stored, unused |

#### Interrupts

* **EnableInterrupt** (sub_4015EC):
  1. `GPIO_INTR_CFG_SU` = 4 (route to the application processor);
  2. computes `GPIO_INTR_CFG`: `InterruptMode` `Latched` → 0x0C (edge + raw status), `LevelSensitive` → 0x08 (level + raw status). `Polarity` `InterruptActiveLow` → bit 1 cleared, anything else (`ActiveHigh`, `ActiveBoth`) → bit 1 set;
  3. configures the pin as an input with the `PullConfiguration` of the `GpioInt` (same mapping as above);
  4. writes `GPIO_INTR_CFG` (still disabled), clears the status, then clears the status again and sets the enable bit. The two last steps run under the GpioClx interrupt lock of the bank (`GPIO_CLX_AcquireInterruptLock`).
  
  The vendor data of a `GpioInt` is ignored.
* **DisableInterrupt**: clears the enable bit, then clears the status (under the interrupt lock).
* **MaskInterrupts**: clears the enable bit of each pin in `PinMask`. The status isn't touched.
* **UnmaskInterrupt**: clears the status, then sets the enable bit. An edge latched while the pin was masked is lost.
* **QueryActiveInterrupts**: for each pin in `EnabledMask`, bit set in `ActiveMask` if `GPIO_INTR_STATUS` ≠ 0.
* **ClearActiveInterrupts**: writes 1 to `GPIO_INTR_STATUS` of each pin in the mask (no lock: GpioClx already holds it).
* **ReconfigureInterrupt** (sub_401894): if bit 2 of `GPIO_INTR_CFG_SU` is clear, writes 4 to it. If the interrupt is enabled, it's disabled first. The new mode/polarity are computed as in `EnableInterrupt` from the current `GPIO_INTR_CFG`, the pin is reconfigured as an input keeping its current pull, the status is cleared, and the interrupt is re-enabled if it was enabled. GpioClx uses this to emulate `ActiveBoth` by flipping the polarity after each edge.

#### Controller-specific function

`sub_402118` is registered as `CLIENT_ControllerSpecificFunction`, so it's reached with `IOCTL_GPIO_CONTROLLER_SPECIFIC_FUNCTION` sent to the controller through GpioClx. It **triggers an interrupt in software**. Unlike [qcpmicgpio8930.sys](./qcpmicgpio8930.md#controller-specific-function), there's no registry value to enable it.  
Input buffer `00-01` = absolute pin number (pin 0 if the input buffer is NULL). The buffer sizes aren't checked. The dwords at `+08` and `+0C` of the GpioClx parameters (output length / bytes returned ?) are set to 0.

`sub_4019E0` for a valid pin:
1. if bit 2 of `GPIO_INTR_CFG_SU` is clear (interrupt not routed to this processor) → `STATUS_UNSUCCESSFUL` (0xC0000001);
2. clears a pending status;
3. `GPIO_INTR_CFG` |= 0x09 (enable + raw status);
4. flips the polarity bit (detection bit unchanged), which makes a level interrupt fire from the current pad level;
5. restores the original `GPIO_INTR_CFG`, then returns `STATUS_SUCCESS`.

An invalid pin returns `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x32C018 — IOCTL_ACPI_EVAL_METHOD_EX

This IOCTL is sent by Qcgpio.sys to acpi.sys (`WdfIoTargetSendIoctlSynchronously` on the default I/O target, in `PrepareController`)

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x6 (6) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD_EX | ACPI PDO of `\_SB.GIO0` | 260 | 22 |

Inputbuffer (`ACPI_EVAL_INPUT_BUFFER_EX`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 41 | Signature `'AeiA'` (ACPI_EVAL_INPUT_BUFFER_SIGNATURE_EX) |
| 04-07 | 4F 46 4E 49 | Method name `OFNI` (relative to the device node) |
| 08-103 | 00 … | Rest of the 256-byte method name, zero |

Outputbuffer (`ACPI_EVAL_OUTPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature `'AeoB'`, checked |
| 04-07 | ? | Length |
| 08-0B | 01 00 00 00 | Count, must be 1 |
| 0C-0D | 02 00 | Argument type, must be 2 (`ACPI_METHOD_ARGUMENT_BUFFER`) |
| 0E-0F | 02 00 | DataLength, must be ≤ 2 |
| 10-11 | 98 00 | TotalPins (152 on the Lumia 520) |
| 12-15 | | Unused |

---

### Interface GUID

The driver doesn't create or open any device interface. Its I/O (`IOCTL_GPIO_READ_PINS` 0x480000, `IOCTL_GPIO_WRITE_PINS` 0x480004, `IOCTL_GPIO_CONTROLLER_SPECIFIC_FUNCTION`) is received by GpioClx, from the drivers that open `\Device\RESOURCE_HUB\<connection id>` ([acpiex.sys](./acpiex.md)).

### Other GUID

WPP message GUIDs (one per source file):  
`{CDE1B7AB-03E9-9ACA-44BE-43D4E867C39C}` (controller)  
`{C0D59FB4-9F13-2B40-8002-BD182B37B146}` (driver)  
`{B4B02906-0513-2DD4-B6F4-24B3B9B07033}` (interrupts)  
`{DE2BF8A9-0E07-79AE-95AC-4A3A5D8A9CBA}` (I/O pins)  
`{D36A09BA-9733-6541-C8E1-5CD9C08C35E9}` (register access, `WPP_Traceguids_01`)
