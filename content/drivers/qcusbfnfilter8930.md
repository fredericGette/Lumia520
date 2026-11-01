## Qcusbfnfilter8930.sys

USB function controller filter driver (low-power / PHY control of the USB HS controller).  
It is a KMDF filter (`WdfFdoInitSetFilter`) installed in the stack of the USB function controller (ACPI `\_SB.UFN1`, `_HID` `QCOM01C0` ?). It doesn't drive the USB function itself: it only handles 2 internal IOCTLs used by the controller driver above it to put the USB HS controller and its ULPI PHY into low-power mode and to wake them up ([internal IOCTL 0x2AC03A](#internal-ioctl-0x2ac03a) and [internal IOCTL 0x2AC03E](#internal-ioctl-0x2ac03e)). Every other request is forwarded unchanged to the lower driver.  
It accesses the hardware directly: the registers of the USB HS controller (ChipIdea core, same offsets as the Linux `msm_otg.c` driver) at the hardcoded address 0x12500000, the ULPI PHY through the ULPI viewport, and the clock controller at the hardcoded address 0x00900000.  
PDB path: `P:\QcUsbFnFilter\rel\8.2.1\arm\Release\qcusbfnfilter8930.pdb`.

There's no device name and no symbolic link.  

There's no parameters in the registry.  

GUID of the ETW provider (WPP):  
`{0babbed4-ac56-4723-a5d0-13c10a2ed043}`  

It doesn't open any other device. It only imports `ntoskrnl.exe` and `WDFLDR.SYS`.

### WDF configuration

`DriverEntry` (0x408008) registers WPP, then `WdfDriverCreate` with `EvtDriverDeviceAdd` and `EvtDriverUnload` (0x407570, unregisters WPP).

`EvtDriverDeviceAdd` (`sub_4075E0`):
- `WdfFdoInitSetFilter`.
- PnP/power callbacks: `EvtDeviceD0Entry` (`sub_40168C`) and `EvtDeviceD0Exit` (`sub_401744`) only trace and return `STATUS_SUCCESS`; `EvtDevicePrepareHardware` (`sub_407754`), `EvtDeviceReleaseHardware` (`sub_407860`).
- Device context `FILTER_EXTENSION` (28 bytes), a `KSPIN_LOCK` is initialized at offset 0x08 (never used ?).
- One default parallel queue, `ExecutionLevel` = `WdfExecutionLevelPassive`, with only `EvtIoInternalDeviceControl` (`sub_4017FC`).

Device context `FILTER_EXTENSION`:  
| Offset | Comment |
|--------|---------|
| 0x08 | `KSPIN_LOCK` |
| 0x0C | Virtual address of the USB HS controller registers (also copied in the global `dword_405A80`) |
| 0x10 | Virtual address of the clock controller |
| 0x14 | BYTE, 1 = controller/PHY in low-power mode |

### Memory resources

The resources of the device (ACPI `_CRS`) are not used. `EvtDevicePrepareHardware` maps 2 hardcoded regions:  
| Physical address | Length | Mapping | Comment |
|------------------|--------|---------|---------|
| 0x12500000 | 0x2000 | MmNonCached | USB HS1 controller (`USB1_HS_BASE`). Same base as the memory resource of `\_SB.UFN1` |
| 0x00900000 | 0x4000 | MmNonCached | Clock controller (GCC) |

A failed mapping → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A). Then it runs the [hardware initialisation](#hardware-initialisation).  
`EvtDeviceReleaseHardware` unmaps both regions.

USB HS controller registers used (names from the Linux `msm_otg` / ChipIdea drivers):  
| Offset | Name | Bits used |
|--------|------|-----------|
| 0x140 | USBCMD | bit 0 = Run/Stop; bit 29 = `ASYNC_INTR_CTRL`, bit 30 = `ULPI_STP_CTRL` |
| 0x170 | ULPI_VIEWPORT | bit 30 = `ULPI_RUN`, bit 29 = `ULPI_WRITE`, bits 23-16 = ULPI register address, bits 15-8 = read data, bits 7-0 = write data |
| 0x184 | PORTSC | bit 0 = CCS (connected), bit 7 = SUSP (port suspended), bit 23 = PHCD (PHY low-power clock disable), bits 31-30 = PTS (10 = ULPI) |
| 0x240 | USB_PHY_CTRL | bit 0 = `PHY_POR_ASSERT` ?, bit 1 = `PHY_RETEN` (0 = retention) ?, bit 9 = ? |

Clock controller register used:  
| Offset | Name | Comment |
|--------|------|---------|
| 0x290C | USB_HS1_XCVR_FS_CLK_NS ? | Bit 9 = branch enable of the USB HS1 transceiver clock. Cleared during the initialisation |

> [!NOTE]
> `sub_402164`, `sub_402188` and `sub_402224` are dead code (not called). They write the clock controller: 0x2900 (USB_HS1_HCLK_CTL ?) = 0x10 to enable the AHB clock, 0x2900 = 0xFFFFFFEF to disable it (writes every bit except bit 4: probably a bug for `&= ~0x10`), and program the transceiver clock: clear bit 9 of 0x290C, wait until bit 9 reads 0, set bit 7, MD (0x2908) = 0x000500DF, NS (0x290C) = 0x00E40A43 (PLL8 × 5/32 = 60 MHz ?).

### ULPI access

`ulpi_read(reg)` (`sub_401F64`): writes `ULPI_RUN | reg << 16` to ULPI_VIEWPORT, then polls `ULPI_RUN` up to 200 times with a 1 ms delay (`KeDelayExecutionThread`). Returns bits 15-8.  
`ulpi_write(reg, value, mask)` (`sub_402058`): if `mask` = 0xFF, writes `value`; else read-modify-write `(old & ~mask) | (value & mask)`. Writes `ULPI_RUN | ULPI_WRITE | reg << 16 | data`, then polls `ULPI_RUN` like `ulpi_read`.  
A timeout → `STATUS_DEVICE_BUSY` (0x80000011).

### Hardware initialisation

`sub_4022E8`, called by `EvtDevicePrepareHardware`:
1. PORTSC = 0x80000000 (PTS = ULPI).
2. Clears bit 9 of the clock register 0x290C (transceiver clock off).
3. Sets the low-power flag (context 0x14 = 1), then calls the [resume sequence](#resume-sequence).
4. ULPI writes:

| ULPI register | Value | Mask | Comment |
|---------------|-------|------|---------|
| 0x0D | 0x04 | 0xFF | USB Interrupt Enable Rising: SessValid |
| 0x10 | 0x04 | 0xFF | USB Interrupt Enable Falling: SessValid |
| 0x30 | 0x01 | 0x03 | Vendor specific ? |
| 0x81 | 0x30 | 0x70 | Vendor specific ? (the method `PHYC` of `\_SB.UFN1` also writes 0x38 in this register) |

Any failure is returned by `EvtDevicePrepareHardware` (the device doesn't start).

### Suspend sequence

`sub_4025B0(device, keepPhy)`:
1. The controller can enter low-power mode only if PORTSC.SUSP = 1, or PORTSC.CCS = 0 (nothing connected), or USBCMD.RS = 0 (controller stopped). Otherwise → `STATUS_DEVICE_NOT_READY` (0xC00000A3).
2. `ulpi_read(0x14)` (USB Interrupt Latch: clears the pending PHY interrupts).
3. If `keepPhy` = 0: `ulpi_write(0x88, 1, 1)`, `ulpi_write(0x84, 0, 0x3B)` (vendor specific ?), `ulpi_write(0x04, 0x08, 0x18)` (Function Control: OpMode = 01 non-driving). The results are ignored.
4. PORTSC |= PHCD, 1 ms delay, then waits until PHCD reads 1 (200 reads without delay). Timeout → `STATUS_DEVICE_BUSY` (0x80000011).
5. USBCMD |= `ASYNC_INTR_CTRL | ULPI_STP_CTRL` (0x60000000).
6. If `keepPhy` = 0: USB_PHY_CTRL &= ~0x202 (PHY retention ?).
7. Low-power flag = 1, returns `STATUS_SUCCESS`.

### Resume sequence

`sub_402854(device)`. If the low-power flag is 0 it returns `STATUS_SUCCESS` immediately. Otherwise:
1. If PORTSC.SUSP = 0: USB_PHY_CTRL = `(USB_PHY_CTRL & ~0x202) | 2` (exit retention ?).
2. USBCMD &= ~0x60000000.
3. PORTSC &= ~PHCD, then waits until PHCD reads 0 (200 reads). Timeout → `STATUS_DEVICE_BUSY` (0x80000011).
4. If PORTSC.SUSP was 0: pulses bit 0 of USB_PHY_CTRL (set, 1 ms delay, clear): PHY reset ?.
5. Low-power flag = 0, returns `STATUS_SUCCESS`.

---

### internal IOCTL 0x2AC03A

This internal IOCTL is processed by Qcusbfnfilter8930.sys (`EvtIoInternalDeviceControl`, `sub_4017FC`).  
Kernel-mode only: it must be sent as `IRP_MJ_INTERNAL_DEVICE_CONTROL`. Probably sent by the USB function controller driver above the filter ?.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0xE |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Low-power command ? | ≥ 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Command, see below |
| 04-07 | ? | Not used |

| Command | Action | Information |
|---------|--------|-------------|
| 1 | [Suspend](#suspend-sequence) with `keepPhy` = PORTSC.SUSP: full PHY power-down (non-driving + retention) when the port isn't suspended by the host, only PHCD when it is | 1 |
| 2, 4, 5 | Nothing (only traced). `STATUS_SUCCESS` | 0 |
| 3 | [Suspend](#suspend-sequence) with `keepPhy` = 0 | 1 |
| 6 | [Suspend](#suspend-sequence) with `keepPhy` = 1 | 1 |
| other | `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) | 0 |

The request is completed with `WdfRequestCompleteWithInformation`; the Information field is 1 when a suspend sequence was run (whatever its status), 0 otherwise.  
An InputBuffer smaller than 8 bytes → the status of `WdfRequestRetrieveInputBuffer` (`STATUS_BUFFER_TOO_SMALL`).

---

### internal IOCTL 0x2AC03E

This internal IOCTL is processed by Qcusbfnfilter8930.sys (`EvtIoInternalDeviceControl`, `sub_4017FC`).  
Kernel-mode only: it must be sent as `IRP_MJ_INTERNAL_DEVICE_CONTROL`. Probably sent by the USB function controller driver above the filter ?.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0xF |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Exit low-power mode ? | 0 | 0 |

The buffers are not used. Runs the [resume sequence](#resume-sequence) and completes the request with its status (`STATUS_SUCCESS` or `STATUS_DEVICE_BUSY`).

---

Any other internal IoControlCode is forwarded to the lower driver (`WdfRequestFormatRequestUsingCurrentType`, `WdfRequestSend` with `WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET`). If the send fails, the request is completed with `WdfRequestGetStatus`.  
There's no `EvtIoDeviceControl`: the other requests (IOCTL, read, write, …) are passed down by the framework automatically (filter device).
