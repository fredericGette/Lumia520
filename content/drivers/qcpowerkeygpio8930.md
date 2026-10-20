## Qcpowerkeygpio8930.sys

Power key GPIO controller driver (GpioClx client).  
It exposes the power key of the PMIC (on the Lumia 520: a PM8038) as a small "virtual" Windows GPIO controller, `\_SB.PWIO`. [msgpiowinphone.sys](./msgpiowinphone.md) connects to it with a `GpioInt` (pin 16) to get the power button. The driver doesn't touch any hardware itself. It registers with the GPIO class extension (`msgpioclx.sys`, through `WdfVersionBindClass`) and turns each GpioClx callback into IOCTLs sent to [qcpmic8930.sys](./qcpmic8930.md): interrupt (`0x8007`) and keypad / power key (`0x8004`) IOCTLs.  
Whatever pin is requested, every callback works on the **same single PMIC interrupt**, read from the ACPI method `PMIC`. At start-up the driver also configures the power key and the PMIC hard reset from the ACPI methods `PKEY` and `HRST`.  
PDB path: `P:\PowerKeyClient\rel\8.2.1.1\arm\Release\qcpowerkeygpio8930.pdb`. Pool tags `qpk1` (`PMIC` buffer), `qpk2` (`PKEY` buffer), `qpk3` (`HRST` buffer).

Hardware ID: `QCOM0D20` (ACPI node `\_SB.PWIO`).  
There's no device name and no symbolic link (the device is created by GpioClx, `WdfDeviceCreate` without a name).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0D20\<instance>`  

There's no parameters in the registry.

There's no ETW provider.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{9A8FF884-5882-4B62-9E0F-172ACE2A9EC0}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC interrupt interface (#5). IRQ IOCTLs (`0x8007xxxx`) **and** power key IOCTLs (`0x8004xxxx`) |
| Lower device (ACPI PDO of `\_SB.PWIO`) | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` on `PMIC`, `PKEY`, `HRST` |

The qcpmic8930 interface is found with `IoRegisterPlugPlayNotification(EventCategoryDeviceInterfaceChange, PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES)`. On arrival, the callback (sub_401118) opens the device with `IoGetDeviceObjectPointer(GENERIC_ALL)`, stores the device object at context `+0x0C` and sets an event (context `+0x1C`) that nothing waits on. The file object isn't kept, so it's never released. On removal, it clears the device pointer. Until the interface has arrived, every callback that needs the PMIC fails with `STATUS_INVALID_PARAMETER` (0xC000000D).  
The IOCTLs are built with `IoBuildDeviceIoControlRequest` (regular IOCTL, not internal) and sent synchronously, without timeout (sub_401254).

> [!NOTE]
> The keypad IOCTLs (`0x8004xxxx`) are sent to the PMIC **interrupt** interface. This works because qcpmic8930 dispatches on the IOCTL code, not on the interface (same as the MPP IOCTLs of [qcpmicgpio8930.sys](./qcpmicgpio8930.md)).

### Start-up

1. `DriverEntry` (0x406000): `WdfDriverCreate` (`EvtDriverDeviceAdd`, `EvtDriverUnload` = `GPIO_CLX_UnregisterClient`), then `GPIO_CLX_RegisterClient` with the registration packet: version 1, size 0x70, controller context size 52 bytes.
2. `EvtDriverDeviceAdd` (0x401308): sets the PnP/power callbacks `EvtDeviceSurpriseRemoval` (nullsub_1, no-op), `EvtDeviceQueryRemove` (sub_401400, `STATUS_SUCCESS`) and `EvtDeviceQueryStop` (sub_401420, `STATUS_UNSUCCESSFUL`: the device can't be stopped for rebalancing). Then `GPIO_CLX_ProcessAddDevicePreDeviceCreate`, `WdfDeviceCreate`, `GPIO_CLX_ProcessAddDevicePostDeviceCreate` and `WdfDeviceSetDeviceState` with `NotDisableable` = `WdfFalse` (everything else `WdfUseDefault`).
3. `PrepareController` (sub_405000):
   * sets TotalPins (context `+0x04`) to 32;
   * checks the resources: a `CmResourceTypePort` or `CmResourceTypeMemory` → `STATUS_UNSUCCESSFUL`. At least one `CmResourceTypeInterrupt` is required, otherwise `STATUS_UNSUCCESSFUL`. On the Lumia 520, `_CRS` has one `GpioInt` on `\_SB.PM01` pin 51 (Edge, ActiveBoth, Shared, PullDown), i.e. PMIC interrupt 51 (block 0, bit 51);
   * registers the PnP notification (see above);
   * evaluates `PMIC` (sub_401960), then `PKEY` (sub_4010A0) and sends [`IOCTL_PM_KEYPAD_CONFIG_POWER_KEY`](#ioctl-0x80040fb4--ioctl_pm_keypad_config_power_key), then `HRST` (sub_401870) and sends [`IOCTL_PM_KEYPAD_CONFIG_HARD_RESET`](#ioctl-0x80040fb8--ioctl_pm_keypad_config_hard_reset). Any error stops the start-up. Since the PKEY step needs the qcpmic8930 device, the controller only starts if qcpmic8930's interface already exists when the notification is registered.
4. `StartController` / `StopController` (sub_405160) do nothing (return `STATUS_SUCCESS`).
5. `ReleaseController` (sub_405120) only unregisters the PnP notification. It doesn't release the device object that was opened.

### ACPI methods

The three methods are evaluated with `IOCTL_ACPI_EVAL_METHOD` (sub_4011C0). The output must have signature `'AeoB'`, the exact number of arguments below, a first argument of type integer (0) and a first-argument length ≤ 256. Otherwise `STATUS_ACPI_INVALID_DATA` (0xC014000F). Values of the Lumia 520 DSDT:  

`PMIC` (4 arguments, parsed by sub_4018E8, stored in the device context):  
| Index | Lumia 520 | Context offset | Meaning |
|-------|-----------|----------------|---------|
| 0 | 0 | +0x06 (byte) | PMIC index, put in the first dword of every IOCTL sent to qcpmic8930 |
| 1 | 0 | +0x10 (word) | PMIC interrupt block (bank) |
| 2 | 0x33 (51) | +0x12 (word) | PMIC interrupt bit in the block |
| 3 | 1 | +0x14 (byte) | Pin value returned by ReadGpioPins when the interrupt status is set (active level) |

So the power key is PMIC interrupt 51, the same interrupt as the `GpioInt` of `\_SB.PWIO`. In the Linux PM8038 numbering (8 interrupts per block), 51 = block 6 bit 3 = `PM8038_PWRKEY_PRESS_IRQ` ?.

`PKEY` (2 arguments, sub_401000): `1, 1`. Sent as is in [`IOCTL_PM_KEYPAD_CONFIG_POWER_KEY`](#ioctl-0x80040fb4--ioctl_pm_keypad_config_power_key).  
`HRST` (5 arguments, sub_4017B0): `0x2810, 0x64, 1, 1, 1`. Sent as is in [`IOCTL_PM_KEYPAD_CONFIG_HARD_RESET`](#ioctl-0x80040fb8--ioctl_pm_keypad_config_hard_reset).

### GpioClx callbacks

Registration packet (`GPIO_CLIENT_REGISTRATION_PACKET`, built in `DriverEntry`):  
| Callback | Function | Comment |
|----------|----------|---------|
| PrepareController | sub_405000 | see [Start-up](#start-up) |
| ReleaseController | sub_405120 | unregisters the PnP notification |
| StartController | sub_405160 | no-op |
| StopController | sub_405160 | no-op |
| QueryControllerBasicInformation | sub_405130 | Version 1, size 16, TotalPins = 32, NumberOfPinsPerBank = 32 (one bank). Flags dword (`+0x0C`): bits 0–2 and 5 cleared (`MemoryMappedController`, `ActiveInterruptsAutoClearOnRead`, `FormatIoRequestsAsMasks`, `EmulateDebouncing` ?), bit 6 set (`EmulateActiveBoth` ?) |
| QuerySetControllerInformation | — | |
| EnableInterrupt | sub_401444 | `IOCTL_PM_IRQ_CONFIG_INTERRUPT`, enable = 1 |
| DisableInterrupt | sub_4014E4 | `IOCTL_PM_IRQ_CONFIG_INTERRUPT`, enable = 0, trigger 7 |
| UnmaskInterrupt | sub_4015CC | `IOCTL_PM_IRQ_UNMASK_INTERRUPT` |
| MaskInterrupts | sub_401558 | `IOCTL_PM_IRQ_MASK_INTERRUPTS` |
| QueryActiveInterrupts | sub_401664 | sends nothing, see below |
| ClearActiveInterrupts | sub_40169C | `IOCTL_PM_IRQ_CLEAR_ACTIVE_INTERRUPTS` |
| ConnectIoPins | sub_405160 | no-op |
| DisconnectIoPins | sub_405160 | no-op |
| ReadGpioPins | sub_4019CC | `IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS`, real-time status |
| WriteGpioPins | sub_4051A0 | always `STATUS_UNSUCCESSFUL` (0xC0000001) |
| Save/RestoreBankHardwareContext, PreProcessControllerInterrupt, ControllerSpecificFunction | — | |
| ReconfigureInterrupt | sub_401710 | `IOCTL_PM_IRQ_CONFIG_INTERRUPT`, enable = 1, new trigger |
| QueryEnabledInterrupts | — | |

> [!NOTE]
> The pin number and the masks passed by GpioClx are **ignored**: every callback uses the PMIC block / bit from `PMIC` (block 0, bit 51 on the Lumia 520). Any of the 32 pins of `\_SB.PWIO` is the power key. The masks sent to qcpmic8930 are always `1 << bit` (64-bit).

* **EnableInterrupt / ReconfigureInterrupt / UnmaskInterrupt**: the trigger is computed from `InterruptMode` and `Polarity` with the same table as `GetPmIrqTrig` of [qcpmicgpio8930.sys](./qcpmicgpio8930.md#interrupts):  

  | Polarity | Latched (edge) | LevelSensitive |
  |----------|----------------|----------------|
  | `InterruptActiveHigh` (1) | 2 | 3 |
  | `InterruptActiveLow` (2) | 4 | 5 |
  | `InterruptActiveBoth` (3) | 1 | 1 |
  | other | 9 | 9 |

* **QueryActiveInterrupts**: doesn't read the PMIC. If the enabled mask is not 0, the active mask = the enabled mask; otherwise 0. Every interrupt of the controller (= PMIC interrupt 51 on `\_SB.PM01`) is therefore reported on all the enabled pins. NULL context → `STATUS_INVALID_HANDLE` (0xC0000008).
* **ReadGpioPins**: pin count 0 → `STATUS_INVALID_PARAMETER`. Reads the real-time status (type 1) of the interrupt. If the 64-bit status equals `1 << bit`, the first **byte** of the output buffer gets `PMIC[3]` (1), otherwise `!PMIC[3]` (0). So the pin reads 1 while the power key is pressed (?).

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcpowerkeygpio8930.sys to acpi.sys (`WdfIoTargetSendIoctlSynchronously` on the default I/O target)

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI PDO of `\_SB.PWIO` | 8 | 256 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `'AeiB'` (ACPI_EVAL_INPUT_BUFFER_SIGNATURE) |
| 04-07 | 50 4D 49 43 / 50 4B 45 59 / 48 52 53 54 | Method name `PMIC` / `PKEY` / `HRST` |

Outputbuffer: `ACPI_EVAL_OUTPUT_BUFFER`, signature `'AeoB'` (see [ACPI methods](#acpi-methods)).

---

### IOCTL 0x80040FB4 — IOCTL_PM_KEYPAD_CONFIG_POWER_KEY

This IOCTL is sent by Qcpowerkeygpio8930.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8004xxxx--keypad--power-key) (sub_401000), once, in `PrepareController`.

| Property | Value |
|----------|-------|
| Device | 0x8004 |
| Function | 0x3ED (1005) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_KEYPAD_CONFIG_POWER_KEY | Interface `{9A8FF884-…}` | 12 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index (`PMIC[0]`) |
| 04-07 | 01 00 00 00 | `PKEY[0]` (meaning ?) |
| 08-0B | 01 00 00 00 | `PKEY[1]` (meaning ?) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | PMIC library error code (not checked) |

---

### IOCTL 0x80040FB8 — IOCTL_PM_KEYPAD_CONFIG_HARD_RESET

This IOCTL is sent by Qcpowerkeygpio8930.sys to [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8004xxxx--keypad--power-key) (sub_4017B0), once, in `PrepareController`. qcpmic8930 applies it as 3 calls: `(in[1])`, `(in[2])`, `(in[4], in[5], in[3])`.

| Property | Value |
|----------|-------|
| Device | 0x8004 |
| Function | 0x3EE (1006) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_KEYPAD_CONFIG_HARD_RESET | Interface `{9A8FF884-…}` | 24 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index (`PMIC[0]`) |
| 04-07 | 10 28 00 00 | `HRST[0]` = 10256. Hard reset delay in ms (S1 timer) ? 10256 ms is the largest S1 timer value of the Qualcomm PMICs |
| 08-0B | 64 00 00 00 | `HRST[1]` = 100. S2 timer in ms ? |
| 0C-0F | 01 00 00 00 | `HRST[2]` (meaning ?) |
| 10-13 | 01 00 00 00 | `HRST[3]` (enable ?) |
| 14-17 | 01 00 00 00 | `HRST[4]` (reset type ?) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | PMIC library error code (not checked) |

---

### IOCTLs sent to qcpmic8930.sys (interrupts)

These IOCTLs are sent by Qcpowerkeygpio8930.sys to the interrupt interface of [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x8007xxxx--interrupts). They are all `METHOD_BUFFERED`, `FILE_ANY_ACCESS`, device type `0x8007`, function 1000 + n. Block and bit always come from `PMIC` (0 and 51 on the Lumia 520). The buffers are the same as those of [qcpmicgpio8930.sys](./qcpmicgpio8930.md#ioctls-sent-to-qcpmic8930sys).

| IOCTL | Name | InputBuffer size | OutputBuffer Size | Used by |
|-------|------|------------------|-------------------|---------|
| 0x80070FA0 | IOCTL_PM_IRQ_CONFIG_INTERRUPT | 24 | 4 | Enable/Disable/ReconfigureInterrupt |
| 0x80070FA4 | IOCTL_PM_IRQ_CLEAR_ACTIVE_INTERRUPTS | 16 | 4 | ClearActiveInterrupts |
| 0x80070FA8 | IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS | 24 | 16 | ReadGpioPins |
| 0x80070FAC | IOCTL_PM_IRQ_MASK_INTERRUPTS | 16 | 4 | MaskInterrupts |
| 0x80070FB0 | IOCTL_PM_IRQ_UNMASK_INTERRUPT | 24 | 4 | UnmaskInterrupt |

#### IOCTL_PM_IRQ_CONFIG_INTERRUPT (0x80070FA0)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | 00 00 00 00 | Block (`PMIC[1]`) |
| 08-0B | 33 00 00 00 | Bit (`PMIC[2]`) |
| 0C-0F | 00 00 00 00 | |
| 10-13 | 01 / 00 | 1 = enable / reconfigure, 0 = disable |
| 14-17 | | Trigger (see the table above; 7 when disabling) |

#### IOCTL_PM_IRQ_UNMASK_INTERRUPT (0x80070FB0)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | 00 00 00 00 | Block |
| 08-0B | 33 00 00 00 | Bit |
| 0C-0F | 00 00 00 00 | |
| 10-13 | | Trigger |
| 14-17 | 00 00 00 00 | |

#### IOCTL_PM_IRQ_MASK_INTERRUPTS (0x80070FAC) / IOCTL_PM_IRQ_CLEAR_ACTIVE_INTERRUPTS (0x80070FA4)

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | 00 00 00 00 | Block |
| 08-0F | 00 00 00 00 00 00 08 00 | 64-bit mask `1 << 51` |

#### IOCTL_PM_IRQ_GET_INTERRUPTS_STATUS (0x80070FA8)

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | 00 00 00 00 | Block |
| 08-0F | 00 00 00 00 00 00 08 00 | 64-bit mask `1 << 51` |
| 10-13 | 01 00 00 00 | Type 1 = real-time status |
| 14-17 | 00 00 00 00 | |

Outputbuffer: `00-07` 64-bit status, `08-0B` error.

### Interface GUID

The driver doesn't create any interface. It waits for this interface of [qcpmic8930.sys](./qcpmic8930.md):  
`{9A8FF884-5882-4B62-9E0F-172ACE2A9EC0}` (PMIC interrupts)

### Other GUID

`GUID_DEVICE_INTERFACE_ARRIVAL`  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`

`GUID_DEVICE_INTERFACE_REMOVAL`  
`{CB3A4005-46F0-11D0-B08F-00609713053F}`
