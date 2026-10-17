## Qcpmicgpio8930.sys

PMIC GPIO controller driver (GpioClx client).  
It makes the GPIOs, MPPs and interrupts of the PMIC (on the Lumia 520: a PM8038) available as a standard Windows GPIO controller. Other drivers reach them through `GpioIo` / `GpioInt` resources on `\_SB.PM01` (see [acpiex.sys](./acpiex.md)). The driver doesn't touch any hardware itself. It registers with the GPIO class extension (`msgpioclx.sys`, through `WdfVersionBindClass`) and turns each GpioClx callback into IOCTLs sent to [qcpmic8930.sys](./qcpmic8930.md): GPIO (`0x8003`), MPP (`0x8005`) and interrupt (`0x8007`) IOCTLs.  
The pin layout (number of pins, banks, where the GPIOs and MPPs are) is read from the ACPI method `PMIO`.  
PDB path: `P:\PmicGpio\rel\8.2.1.1\gpioclx\src\build\arm\Release\qcpmicgpio8930.pdb`. Pool tags `qpg0` (pin tables), `qpg1` (ACPI buffer), driver pool tag `0qpq`.

Hardware ID: `QCOM05C0` (ACPI node `\_SB.PM01`, which has a `_DEP` on `\_SB.PMIC`).  
There's no device name and no symbolic link (the device is created by GpioClx, `WdfDeviceCreate` without a name).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM05C0\<instance>`  

Registry values, read from the driver's **service key** (`WdfDriverGetRegistryPath`, opened with `KEY_READ`, not the `Parameters` subkey) by `PmicGpioClxUpdatePmPlatConfigFromRegistry` (sub_401E70), when the controller is prepared. Both are REG_DWORD. Any other type gives `STATUS_INVALID_PARAMETER`:  
| Registry value | value | comment |
|----------------|-------|---------|
| ActiveBothEmulation | 1 | Value of the `EmulateActiveBoth` flag reported to GpioClx (see [QueryControllerBasicInformation](#gpioclx-callbacks)) |
| TestTriggerInterrupt | 0 | Must be exactly `0x1CDD` (7389) to enable the [trigger-interrupt function](#controller-specific-function). This value also forces `ActiveBothEmulation` to 0 |

GUID of the ETW provider (`PMIC_GPIO_CLX`):  
`{720101D6-8233-4892-A82C-FDCFCD2B4A9A}`

A second set of trace calls (`PmicDriverRequest.c`, handle `qword_413AF0`) is never registered, so those events are never written.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{5186FCEA-68FC-420A-9400-601A6D0CA988}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC GPIO interface (#4). GPIO and MPP IOCTLs (`0x8003xxxx`, `0x8005xxxx`) |
| Interface `{9A8FF884-5882-4B62-9E0F-172ACE2A9EC0}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC interrupt interface (#5). IRQ IOCTLs (`0x8007xxxx`) |
| Lower device (ACPI PDO of `\_SB.PM01`) | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` on `PMIO` |

Both qcpmic8930 interfaces are found with `IoRegisterPlugPlayNotification(EventCategoryDeviceInterfaceChange, PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES)`. On arrival, the callback (`PmicGpioInterfaceNotficationCallback` sub_4015AC, `PmicIrqInterfaceNotficationCallback` sub_401748) opens the device with `IoGetDeviceObjectPointer(FILE_ALL_ACCESS)` and sets an event that nothing waits on. On removal, it releases the file object and clears the pointer. Until the interfaces have arrived, every callback that needs the PMIC fails with `STATUS_INVALID_PARAMETER_1` (0xC00000EF, "Invalid GPIO device context").  
The IOCTLs are built with `IoBuildDeviceIoControlRequest` (regular IOCTL, not internal) and sent synchronously (`PmicSendDriverRequestWithTimeout` sub_404E48). Despite the name, there's no timeout: `KeWaitForSingleObject` is called without one.

### Start-up

1. `DriverEntry` (0x402388): registers the ETW provider, `WdfDriverCreate` (`EvtDriverDeviceAdd`, `EvtDriverUnload`), then `GPIO_CLX_RegisterClient` with the registration packet built by `PmicGpioClxRegisterAsGpioClient` (sub_401314): version 1, size 0x70, controller context size 124 bytes.
2. `EvtDriverDeviceAdd` (`OnPmicGpioDeviceAdd` 0x4022C4 → `PmicGpioClxDeviceCreate` sub_415008): `GPIO_CLX_ProcessAddDevicePreDeviceCreate`, `WdfDeviceCreate` (context `PMIC_GPIO_DEVICE_CONTEXT`, passive execution level), `GPIO_CLX_ProcessAddDevicePostDeviceCreate`.
3. `PrepareController` (`PmicGpioClxInitializeController` sub_415170):
   * counts the resources: `CmResourceTypePort` and `CmResourceTypeInterrupt` are only traced. `CmResourceTypeMemory` → `STATUS_INVALID_PARAMETER`. On the Lumia 520, `_CRS` has 5 interrupts (5 identical `GpioInt` on `\_SB.GIO0` pin 104, the PMIC interrupt line), one per bank.
   * registers the two PnP notifications (see above);
   * evaluates `PMIO` and fills the pin layout (see [ACPI PMIO](#acpi-pmio));
   * reads the registry values;
   * allocates three byte arrays of flags: one per pin (`+0x70`, "emulated ActiveBoth", TotalPins bytes), one per GPIO (`+0x74`, "inverted", GPIO-count bytes) and one per MPP (`+0x78`, "inverted", MPP-count bytes).
4. `StartController` / `StopController` (sub_415700 / sub_415784) do nothing (return `STATUS_SUCCESS`).
5. `ReleaseController` (sub_4154A0) unregisters the PnP notifications and frees the three arrays. It doesn't release the device objects that were opened.

### ACPI PMIO

`ParsePmicGpioAcpiConfig` (sub_401D14) sends `IOCTL_ACPI_EVAL_METHOD` (0x32C004) to the lower device. The input is `ACPI_EVAL_INPUT_BUFFER` (`'AeiB'`, method `PMIO`) and the output buffer is 1024 bytes. The output must have signature `'AeoB'` and exactly **17** arguments (otherwise `0xC0040C0F`). `AssignGpioAcpiValue` (sub_401A54) only uses the integer arguments (type 0). Values of the Lumia 520 DSDT:  
| Index | Lumia 520 | Context offset | Meaning |
|-------|-----------|----------------|---------|
| 0 | 0 | +0x40 | PMIC index, put in the first dword of every IOCTL sent to qcpmic8930 |
| 1 | 0x1F66 | +0x44 | Stored, never used ? |
| 2 | 0x0C (12) | +0x48 | Number of GPIOs |
| 3 | 0xC0 (192) | +0x4A | Pin number of GPIO 0 |
| 4, 5 | 0, 0 | — | Ignored |
| 6 | 0x110 (272) | +0x4E | Total number of pins |
| 7 | 0x40 (64) | +0x50 | Pins per bank |
| 8 | 0 | — | Ignored |
| 9 | 0x100 (256) | +0x54 | Number of physical interrupts |
| 10–12 | 0, 0, 0 | — | Ignored |
| 13 | 6 | +0x5A | Number of MPPs |
| 14 | 0x80 (128) | +0x5C | Pin number of MPP 1 |
| 15, 16 | 0, 0 | — | Ignored |

Derived values: last GPIO pin (+0x4C) = 192 + 12 − 1 = 203, number of banks (+0x52) = ⌈272 / 64⌉ = 5, last physical interrupt (+0x56) = 255, number of interrupt banks (+0x58) = ⌈256 / 64⌉ = 4, last MPP pin (+0x5E) = 128 + 6 − 1 = 133.

### Pin numbering

A GpioClx pin is (bank, pin in bank) with 64 pins per bank, so the absolute pin number = bank × 64 + pin. **This is the PMIC interrupt number** (block × 64 + bit in [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8007xxxx--interrupts)). On the Lumia 520:  
| Absolute pin | Bank / pin | Kind | Checks (`PmicGpioClxHw.c`) |
|--------------|------------|------|----------------------------|
| 0–255 | 0–3 / 0–63 | Physical PMIC interrupt | `PmicGpioClxIsPhysicalIRQ` (sub_402678) |
| 128–133 | 2 / 0–5 | Also MPP 1–6 (PMIC MPP index = pin − 128) | `PmicGpioClxIsPhysicalMPP` (sub_402808), `AdjustMppPinForIoctl` (sub_402A20) |
| 192–203 | 3 / 0–11 | Also GPIO 1–12 (PMIC GPIO index 0–11 = pin − 192) | `PmicGpioClxIsPhysicalGPIO` (sub_40273C), `AdjustGpioPinForIoctl` (sub_402978) |
| 256–271 | 4 / 0–15 | "Virtual" pins: accepted, but nothing is sent to the PMIC | `PmicGpioClxIsPinValid` (sub_4025B4) |

This matches qcpmic8930: the GPIO interrupts are 192 + n and the MPP interrupts are 128 + n.

In ASL, `GpioInt(…){195}` on `\_SB.PM01` therefore means the interrupt of PMIC GPIO index 3 (GPIO4). The pins used on `\_SB.PM01` by [NokiaEnergyDriver.sys](./nokiaenergydriver.md#lumia-520-acpi-node) and by `\_SB.PWIO` (pin 51, see [acpiex.sys](./acpiex.md)) are PMIC interrupt numbers.

### Vendor data

`ConnectIoPins` and `EnableInterrupt` accept an optional 1-byte vendor data (`VendorData` in the `GpioIo` / `GpioInt` descriptor). A length > 1, or a NULL pointer with a non-zero length, is rejected with `STATUS_INVALID_PARAMETER_2` (0xC00000F0, "Invalid vendor data").  
| Bits | Meaning |
|------|---------|
| 0–2 | GPIO voltage source (default 2) |
| 4–5 | GPIO output drive strength (0 → 3; default 3) |
| 6 | Inverted: the value read is inverted (GPIO and MPP) |
| 7 | `GpioInt` only: always program the interrupt as trigger 1 (the ActiveBoth trigger) |

### GpioClx callbacks

Registration packet (`GPIO_CLIENT_REGISTRATION_PACKET`, sub_401314):  
| Callback | Function | Comment |
|----------|----------|---------|
| PrepareController | sub_415170 `PmicGpioClxInitializeController` | see [Start-up](#start-up) |
| ReleaseController | sub_4154A0 `PmicGpioClxUnInitializeController` | |
| StartController | sub_415700 `PmicGpioClxStartController` | no-op |
| StopController | sub_415784 `PmicGpioClxStopController` | no-op |
| QueryControllerBasicInformation | sub_4155FC | Version 1, size 16, TotalPins = 272, NumberOfPinsPerBank = 64. Flags: `MemoryMappedController`, `ActiveInterruptsAutoClearOnRead`, `FormatIoRequestsAsMasks` cleared, `EmulateDebouncing` = 1, `EmulateActiveBoth` = registry `ActiveBothEmulation` |
| QuerySetControllerInformation | — | |
| EnableInterrupt | sub_403608 `PmicGpioClxEnableInterrupt` | |
| DisableInterrupt | sub_4038F4 `PmicGpioClxDisableInterrupt` | |
| UnmaskInterrupt | sub_404080 `PmicGpioClxUnmaskInterrupt` | |
| MaskInterrupts | sub_403EB4 `PmicGpioClxMaskInterrupts` | |
| QueryActiveInterrupts | sub_403B14 `PmicGpioClxQueryActiveInterrupts` | |
| ClearActiveInterrupts | sub_403CE8 `PmicGpioClxClearActiveInterrupts` | |
| ConnectIoPins | sub_404644 `PmicGpioClxConnectIoPins` | |
| DisconnectIoPins | sub_4047A4 `PmicGpioClxDisconnectIoPins` | only checks the pins, sends nothing |
| ReadGpioPins | sub_404878 `PmicGpioClxReadPins` | |
| WriteGpioPins | sub_404A5C `PmicGpioClxWritePins` | |
| Save/RestoreBankHardwareContext, PreProcessControllerInterrupt | — | |
| ControllerSpecificFunction | sub_4044B4 `PmicGpioClxTriggerInterrupt` | see [below](#controller-specific-function) |
| ReconfigureInterrupt | sub_4042B0 `PmicGpioClxReconfigureInterrupt` | |
| QueryEnabledInterrupts | — | |

#### I/O pins

* **ConnectIoPins**: `ConnectMode` must be input (1) or output (2), otherwise `STATUS_INVALID_PARAMETER`. Each pin must be a GPIO or an MPP. A pin that is only a physical interrupt is accepted for input, and nothing is sent for it.
  * GPIO (`PmicGpioClxConfigureGPIOPin` sub_402AC8): output → `IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT`, input → `IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT` with the pull mapped as in the table below.
  * MPP (`PmicGpioClxConfigureMPPPin` sub_402F78): output → `IOCTL_PM_MPP_CONFIG_DIGITAL_OUTPUT`, input → `IOCTL_PM_MPP_CONFIG_DIGITAL_INPUT`. The level is always 1, and the pull and vendor voltage are ignored. On failure, the input case logs "Configuring MPP digital output failed" (copy-paste).
  * The errors of these IOCTLs are only traced: `ConnectIoPins` always returns `STATUS_SUCCESS` once the pins are valid.
* **ReadGpioPins**: every pin must be a physical interrupt (0–255), otherwise `STATUS_INVALID_PARAMETER`. Each pin is read with the first matching IOCTL below. Bit 0 of the request `Flags` is passed as the "source" argument. The values are packed into the output buffer, 1 bit per pin.
  * GPIO: `IOCTL_PM_GPIO_GET_GPIO_STATE` (`PmicGpioClxReadWriteGPIOPin` sub_402DB0). With source 0, qcpmic8930 returns the real-time status of interrupt 192 + n instead of the GPIO input.
  * MPP: `IOCTL_PM_MPP_GET_INPUT_STATE` (`PmicGpioClxReadWriteMPPPin` sub_4031C0).
  * Anything else: real-time status of the interrupt (`IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS`, type 1, `PmicGpioClxReadIRQPin` sub_4033E8).
  * GPIOs and MPPs flagged "inverted" (vendor data bit 6) return the inverted value.
* **WritePins**: every pin must be a GPIO or an MPP, otherwise `STATUS_INVALID_PARAMETER`. Pin count 0 → `STATUS_INVALID_PARAMETER_2` (0xC00000F0); for ReadGpioPins it's `STATUS_INVALID_PARAMETER`. GPIO → **`IOCTL_PM_GPIO_SET_INVERSION_CONFIGURATION`** with the bit value. MPP → `IOCTL_PM_MPP_SET_OUTPUT_STATE`.

> [!NOTE]
> A GPIO output is driven by changing its **inversion** setting, not by writing a level. This only works because `ConnectIoPins` sets the output source to 0 (constant low ?). Writing 1 inverts it to high.

`ConnectIoPins` GPIO pull mapping (`PullConfiguration` → `pull` argument of `IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT`). The PMIC names are those of the Qualcomm `pm_gpio_current_src_pulls` enum (?):  
| PullConfiguration | Value sent | PMIC pull |
|-------------------|------------|-----------|
| 0x80 (vendor) | 0 | pull-up 30 µA |
| 0x81 (vendor) | 1 | pull-up 1.5 µA |
| 1 `PullUp`, 0x82 | 2 | pull-up 31.5 µA |
| 0x83 (vendor) | 3 | pull-up 1.5 µA + 30 µA boost |
| 2 `PullDown`, 0x84 | 4 | pull-down 10 µA |
| other (0 `Default`, 3 `None`, …) | 5 | no pull |

#### Interrupts

Pins 256–271 are "virtual interrupts": enable, disable, unmask and reconfigure return `STATUS_SUCCESS` and send nothing. A pin ≥ 272 gives `STATUS_INVALID_PARAMETER` (0xC000000D).

* **EnableInterrupt**: if the pin is a GPIO, it's first configured as a digital input (as `ConnectIoPins`, with the pull and vendor data of the `GpioInt`). If it's an MPP, it's configured as a digital input. Then `IOCTL_PM_IRQ_CONFIG_INTERRUPT` is sent with enable = 1 and the trigger computed by `GetPmIrqTrig` (sub_403550). Vendor data bit 7 (or the pin's "emulated ActiveBoth" flag) forces trigger 1.
* **DisableInterrupt**: `IOCTL_PM_IRQ_CONFIG_INTERRUPT` with enable = 0 and trigger 7.
* **ReconfigureInterrupt**: `IOCTL_PM_IRQ_CONFIG_INTERRUPT` with enable = 1 and the new trigger.
* **UnmaskInterrupt**: `IOCTL_PM_IRQ_UNMASK_INTERRUPT` with the trigger.
* **MaskInterrupts**: `IOCTL_PM_IRQ_MASK_INTERRUPTS` (bank, 64-bit mask). Bank ≥ 4 → `STATUS_INVALID_PARAMETER_2`.
* **QueryActiveInterrupts**: if the enabled mask is 0 it returns 0. Otherwise `IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS` with the enabled mask and type 0 (latched status). The 64-bit status becomes the active mask. Bank ≥ 4 → active mask 0.
* **ClearActiveInterrupts**: `IOCTL_PM_IRQ_CLEAR_ACTIVE_INTERRUPTS` (bank, 64-bit mask). Bank ≥ 4 → `STATUS_SUCCESS`, nothing sent.

`GetPmIrqTrig` (`InterruptMode`, `Polarity`) → trigger value sent to qcpmic8930 (PMIC trigger names not identified ?):  
| Polarity | Latched (edge) | LevelSensitive |
|----------|----------------|----------------|
| `InterruptActiveHigh` (1) | 2 | 3 |
| `InterruptActiveLow` (2) | 4 | 5 |
| `InterruptActiveBoth` (3) | 1 | 1 |
| other | 9 | 9 |

#### Controller-specific function

`PmicGpioClxTriggerInterrupt` (sub_4044B4) is registered as `CLIENT_ControllerSpecificFunction`, so it's reached with `IOCTL_GPIO_CONTROLLER_SPECIFIC_FUNCTION` sent to the controller through GpioClx. It only works when the registry value `TestTriggerInterrupt` = `0x1CDD`. Otherwise it returns `STATUS_UNSUCCESSFUL` (0xC0000001).  
Input buffer `00-03` = absolute pin number (bank = bits 6+, pin = bits 0–5). For a physical interrupt it sends `IOCTL_PM_IRQ_TRIGGER_INTERRUPT`. A virtual pin returns `STATUS_SUCCESS`, and an invalid pin returns `STATUS_INVALID_PARAMETER`. The input/output sizes aren't checked.

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcpmicgpio8930.sys to acpi.sys (`WdfIoTargetSendIoctlSynchronously` on the default I/O target)

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI PDO of `\_SB.PM01` | 8 | 1024 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `'AeiB'` (ACPI_EVAL_INPUT_BUFFER_SIGNATURE) |
| 04-07 | 50 4D 49 4F | Method name `PMIO` |

Outputbuffer: `ACPI_EVAL_OUTPUT_BUFFER`, signature `'AeoB'`, 17 arguments (see [ACPI PMIO](#acpi-pmio)).

---

### IOCTLs sent to qcpmic8930.sys

These IOCTLs are sent by Qcpmicgpio8930.sys to [qcpmic8930.sys](./qcpmic8930.md). They are all `METHOD_BUFFERED`, `FILE_ANY_ACCESS`, device type `0x8003` / `0x8005` / `0x8007`, function 1000 + n. The first dword of every input buffer is the PMIC index (`PMIO[0]`, 0 on the Lumia 520). The output starts with the PMIC library error code. GPIO and MPP numbers are PMIC indexes (pin − 192 / pin − 128).

| IOCTL | Name | Device | InputBuffer size | OutputBuffer Size | Used by |
|-------|------|--------|------------------|-------------------|---------|
| 0x80030FA4 | IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT | GPIO interface | 20 | 4 | ConnectIoPins (input), EnableInterrupt |
| 0x80030FA8 | IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT | GPIO interface | 24 | 4 | ConnectIoPins (output) |
| 0x80030FAC | IOCTL_PM_GPIO_SET_INVERSION_CONFIGURATION | GPIO interface | 12 | 4 | WritePins |
| 0x80030FB4 | IOCTL_PM_GPIO_GET_GPIO_STATE | GPIO interface | 12 | 8 | ReadGpioPins |
| 0x80050FA0 | IOCTL_PM_MPP_CONFIG_DIGITAL_INPUT | GPIO interface | 16 | 4 | ConnectIoPins (input), EnableInterrupt |
| 0x80050FA4 | IOCTL_PM_MPP_CONFIG_DIGITAL_OUTPUT | GPIO interface | 12 | 4 | ConnectIoPins (output) |
| 0x80050FBC | IOCTL_PM_MPP_GET_INPUT_STATE | GPIO interface | 12 | 8 | ReadGpioPins |
| 0x80050FC0 | IOCTL_PM_MPP_SET_OUTPUT_STATE | GPIO interface | 12 | 4 | WritePins |
| 0x80070FA0 | IOCTL_PM_IRQ_CONFIG_INTERRUPT | IRQ interface | 24 | 4 | Enable/Disable/ReconfigureInterrupt |
| 0x80070FA4 | IOCTL_PM_IRQ_CLEAR_ACTIVE_INTERRUPTS | IRQ interface | 16 | 4 | ClearActiveInterrupts |
| 0x80070FA8 | IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS | IRQ interface | 24 | 16 | QueryActiveInterrupts, ReadGpioPins |
| 0x80070FAC | IOCTL_PM_IRQ_MASK_INTERRUPTS | IRQ interface | 16 | 4 | MaskInterrupts |
| 0x80070FB0 | IOCTL_PM_IRQ_UNMASK_INTERRUPT | IRQ interface | 24 | 4 | UnmaskInterrupt |
| 0x80070FB4 | IOCTL_PM_IRQ_TRIGGER_INTERRUPT | IRQ interface | 8 | 4 | ControllerSpecificFunction |

> [!NOTE]
> The GPIO **and MPP** IOCTLs are both sent to the GPIO interface `{5186FCEA-…}` (#4), not to the MPP interface (#10). This works because qcpmic8930 dispatches on the IOCTL code, not on the interface.

#### IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT (0x80030FA4)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | GPIO index (pin − 192) |
| 08-0B | 02/04/05 … | Pull (see the pull table) |
| 0C-0F | 02 00 00 00 | Voltage source = vendor data bits 0–2 (default 2) |
| 10-13 | 00 00 00 00 | Source |

#### IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT (0x80030FA8)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | GPIO index |
| 08-0B | 00 00 00 00 | Output buffer type (0 = CMOS ?) |
| 0C-0F | 02 00 00 00 | Voltage source = vendor data bits 0–2 (default 2) |
| 10-13 | 00 00 00 00 | Source (0 = constant low ?) |
| 14-17 | 03 00 00 00 | Drive strength = vendor data bits 4–5, 0 → 3 (default 3) |

#### IOCTL_PM_GPIO_SET_INVERSION_CONFIGURATION (0x80030FAC) / IOCTL_PM_MPP_SET_OUTPUT_STATE (0x80050FC0)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | GPIO / MPP index |
| 08-0B | 00 or 01 | Value to write |

#### IOCTL_PM_GPIO_GET_GPIO_STATE (0x80030FB4) / IOCTL_PM_MPP_GET_INPUT_STATE (0x80050FBC)

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | GPIO / MPP index |
| 08-0B | 00 or 01 | Source = bit 0 of the GpioClx read `Flags` (0 = real-time status of the pin interrupt) |

Outputbuffer: `00-03` error, `04-07` state (inverted by the driver if the pin has vendor data bit 6).

#### IOCTL_PM_MPP_CONFIG_DIGITAL_INPUT (0x80050FA0) / IOCTL_PM_MPP_CONFIG_DIGITAL_OUTPUT (0x80050FA4)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | MPP index (pin − 128) |
| 08-0B | 01 00 00 00 | Level |
| 0C-0F | 00 00 00 00 | Input only: detection ? |

#### IOCTL_PM_IRQ_CONFIG_INTERRUPT (0x80070FA0)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | Bank (block) |
| 08-0B | | Pin in bank (bit) |
| 0C-0F | 00 00 00 00 | |
| 10-13 | 01 / 00 | 1 = enable / reconfigure, 0 = disable |
| 14-17 | | Trigger (`GetPmIrqTrig`; 7 when disabling) |

#### IOCTL_PM_IRQ_UNMASK_INTERRUPT (0x80070FB0)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | Bank |
| 08-0B | | Pin in bank |
| 0C-0F | 00 00 00 00 | |
| 10-13 | | Trigger |
| 14-17 | 00 00 00 00 | |

#### IOCTL_PM_IRQ_MASK_INTERRUPTS (0x80070FAC) / IOCTL_PM_IRQ_CLEAR_ACTIVE_INTERRUPTS (0x80070FA4)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | Bank (0–3) |
| 08-0F | | 64-bit pin mask |

#### IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS (0x80070FA8)

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | Bank |
| 08-0F | | 64-bit mask: the enabled mask (QueryActiveInterrupts) or `1 << pin` (ReadGpioPins) |
| 10-13 | 00 / 01 | 0 = latched status (QueryActiveInterrupts), 1 = real-time status (ReadGpioPins) |
| 14-17 | 00 00 00 00 | |

Outputbuffer: `00-07` 64-bit status, `08-0B` error.

#### IOCTL_PM_IRQ_TRIGGER_INTERRUPT (0x80070FB4)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | | Absolute pin number = interrupt id (bank × 64 + pin) |

### Interface GUID

The driver doesn't create any interface. It waits for these two interfaces of [qcpmic8930.sys](./qcpmic8930.md):  
`{5186FCEA-68FC-420A-9400-601A6D0CA988}` (PMIC GPIO, also used for MPP)  
`{9A8FF884-5882-4B62-9E0F-172ACE2A9EC0}` (PMIC interrupts)

### Other GUID

`GUID_DEVICE_INTERFACE_ARRIVAL`  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`

`GUID_DEVICE_INTERFACE_REMOVAL`  
`{CB3A4005-46F0-11D0-B08F-00609713053F}`
