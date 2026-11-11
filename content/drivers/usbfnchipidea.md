## Usbfnchipidea.sys

USB function controller driver for the ChipIdea HS core (USB device mode).  
It is the function driver (FDO) of the USB function controller `ACPI\QCOM01C0\1` (`\_SB.UFN1`). It is a client of the Microsoft USB function class extension `UsbFnClx`, [usbfnclx.sys](./usbfnclx.md) (version 1, bound with `WdfVersionBindClass`). The class extension enumerates the `USBFN\<interface>` child devices and gives their requests to this driver. Usbfnchipidea.sys only drives the hardware: device controller registers, endpoint queue heads/transfer descriptors (DMA), the bus events (attach, reset, suspend, setup packet, …) and BC1.2 charger detection through the ULPI PHY.  
It handles the `IOCTL_INTERNAL_USBFN_TRANSFER_*` / `CONTROL_STATUS_HANDSHAKE_*` requests that the function drivers ([genericusbfnclass.sys](./genericusbfnclass.md), [ufnserialclass.sys](./ufnserialclass.md), [ufnvidstream.sys](./ufnvidstream.md), …) send to their `USBFN\<interface>` PDO, one WDF queue per endpoint.  
[qcusbfnfilter8930.sys](./qcusbfnfilter8930.md) is a filter in the same stack, between this driver and the ACPI PDO: the ACPI method evaluations sent by this driver go through it.  
PDB: `usbfnchipidea.pdb`. Pool tag `Chip`.

There's no device name and no symbolic link (the class extension creates the child devices).  

There's no parameters in the registry.  

GUID of the ETW provider (manifest, `EtwRegister`):  
`{3e542731-dbcf-47b3-aed9-c2bee11a5497}`  

GUID of the WPP provider:  
`{b83729f3-8d84-4bea-897b-cd9fd667ba01}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device of its stack (`WdfDeviceGetIoTarget`) = PDO `ACPI\QCOM01C0\1` (through the filter [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md)) | [acpi.sys](./acpi.md) | [internal IOCTL 0x32C004](#internal-ioctl-0x32c004--ioctl_acpi_eval_method): evaluation of the methods `_UBF`, `_EY1`, `_EY2` of `\_SB.UFN1` |
| Class extension `UsbFnClx` (same device stack, function table of 6 entries) | [usbfnclx.sys](./usbfnclx.md) | Driver/device registration, endpoint callbacks, bus event notifications, see [UsbFnClx interface](#usbfnclx-interface) |

### Resources

Only the resources of the device (ACPI `_CRS` of `\_SB.UFN1`) are used, there's no hardcoded address:  
| Resource | Value | Comment |
|----------|-------|---------|
| Memory | 0x12500000, length 0x200 | USB HS1 controller registers (`USB1_HS_BASE`), mapped with `MmMapIoSpace(MmNonCached)` in `EvtDevicePrepareHardware`. The whole block is copied into a debug buffer on the 10th interrupt |
| Interrupt | GSIV 0x84 (132), twice in `_CRS` (flags 0x09 and 0x19 = wake capable) | `WdfInterruptCreate` with the interrupt configuration given by the class extension: ISR `sub_100029FC`, DPC `sub_1000247C` |

DMA (`EvtDevicePrepareHardware` → `sub_100043BC`):
- `WdfDeviceSetAlignmentRequirement(4096)`, `WdfDmaEnablerCreate` with profile 5 (`WdfDmaProfileScatterGatherDuplex`), maximum length 0x10000.
- Common buffer of 2048 bytes: the endpoint queue heads (dQH), 16 endpoints × 2 directions × 64 bytes (OUT at `ep * 128`, IN at `ep * 128 + 64`). Its physical address goes into `ENDPOINTLISTADDR`.
- Common buffer of 1024 bytes, 32-byte aligned: pool of 32 transfer descriptors (dTD) of 32 bytes.
- One `WDFDMATRANSACTION` per endpoint queue. A dTD has up to 5 page pointers (20 KB max).

### ChipIdea registers

Offsets from the memory resource (names from the ChipIdea / Linux `ci13xxx_udc` drivers):  
| Offset | Name | Use |
|--------|------|-----|
| 0x080 | GPTIMER0LD | Loaded with 1000000 (1 s) after each batch of bus events, 1000 (1 ms) by the endpoint timeout handler |
| 0x084 | GPTIMER0CTRL | Written 0xC0000000 (`GPTRUN` \| `GPTRST`): starts general purpose timer 0. Its interrupt (`TIE0`) wakes the ISR/DPC up again (catches missed interrupts ?) |
| 0x090 / 0x098 / 0x09C | AHBBURST / AHBMODE / GENCONFIG | Written by the ACPI method `_UBF` only (0, 8, 0xCB0) |
| 0x140 | USBCMD | bit 0 = RS (Run/Stop), bit 1 = RST, bits 23-16 = ITC (set to 8), bit 13 = SUTW (setup tripwire) |
| 0x144 | USBSTS | bit 2 = PCI (port change), bit 6 = URI (bus reset), bit 8 = SLI (suspend) |
| 0x148 | USBINTR | `0x03000144` \| UE: PCE, URE, SLE, TIE0, TIE1 + UE (bit 0, set in D0 entry) |
| 0x154 | DEVICEADDR | `address << 25 \| USBADRA` (bit 24, address takes effect after the status stage) |
| 0x158 | ENDPOINTLISTADDR | Physical address of the dQH buffer |
| 0x170 | ULPI_VIEWPORT | See [ULPI access](#ulpi-access) |
| 0x184 | PORTSC1 | bit 7 = SUSP, bit 8 = PR (port reset), bits 19-16 = PTC (test mode), bits 27-26 = PSPD (speed) |
| 0x1A4 | OTGSC | bit 3 = OT, bit 11 = BSV (VBUS / B-session valid), bit 19 = BSVIS, bit 27 = BSVIE |
| 0x1A8 | USBMODE | `(v & ~0xB) \| 0xA`: CM = 10 (device controller), SLOM = 1 (setup lockout off) |
| 0x1AC | ENDPTSETUPSTAT | bit 0 = setup packet received on EP0 |
| 0x1B0 | ENDPTPRIME | bit `ep` (OUT) / `ep + 16` (IN) |
| 0x1B4 | ENDPTFLUSH | Written 0xFFFFFFFF on bus reset, per-endpoint bit on cancellation (200 tries) |
| 0x1B8 | ENDPTSTAT | Endpoint primed |
| 0x1BC | ENDPTCOMPLETE | Transfer complete, bit per endpoint/direction |
| 0x1C0 + 4 × ep | ENDPTCTRLn | bit 0/16 = RXS/TXS (stall), bits 3-2/19-18 = type, bit 6/22 = data toggle reset, bit 7/23 = RXE/TXE |

### Controller initialisation

`sub_1000460C`, called by `EvtDevicePrepareHardware` (and again on detach after a failed endpoint flush, context +0xE4 < 0):
1. USBCMD.RS = 0, USBCMD.RST = 1, waits until RST reads 0 (no timeout). USBCMD.ITC = 8.
2. [ACPI methods](#acpi-methods) `_UBF`, `_EY1`, `_EY2`.
3. USBMODE = device mode, setup lockout off.
4. Clears the dQH and dTD buffers, writes ENDPOINTLISTADDR, clears ENDPTSETUPSTAT and USBSTS.
5. OTGSC |= BSVIE, USBINTR |= 0x03000144.
6. ENDPTCTRL0: RXE/TXE = 0. ENDPTCTRL1-15: RXE/TXE = 0, type bit 3 set on both directions (bulk, unused endpoints must not stay "control").
7. Pulses OTGSC.OT (clear, 10 µs, set).

D0 entry (`sub_10003370`): OTGSC |= BSVIE, USBINTR |= UE, OTGSC.OT cleared then set after `KeStallExecutionProcessor(10000)` (10 ms), then `KeDelayExecutionThread` with an interval of +10000. The value is positive, so it's an *absolute* time (already in the past) and the call doesn't wait. Then if OTGSC.BSV = 1 (VBUS present) it sends the event `UsbfnEventAttach` to the class extension (which starts the [charger detection](#charger-detection)); otherwise it sets USBCMD.RS. Context +0x00 = 1 (in D0).  
D0 exit (`sub_1000350C`): context +0x00 = 0, USBCMD.RS = 0, and if VBUS is present it sends `UsbfnEventDetach`.  
The callbacks at offsets 0x18 / 0x1C only call `WdfInterruptReportActive` / `WdfInterruptReportInactive`.

### ACPI methods

`sub_100095E0` evaluates 3 methods of the device with [internal IOCTL 0x32C004](#internal-ioctl-0x32c004--ioctl_acpi_eval_method). It always returns `STATUS_SUCCESS`: failures are only traced.  
| Method | Exists in the Lumia 520 DSDT | After a successful call |
|--------|------------------------------|-------------------------|
| `_UBF` | Yes: USBMODE = 2, PORTSC \|= 2, AHBMODE = 8, AHBBURST = 0, GENCONFIG = 0xCB0 | - |
| `_EY1` | No | Reads ULPI register 0x81, expects 0x38 |
| `_EY2` | No (only evaluated if 0x81 = 0x38) | Reads ULPI register 0x82, expects 0x14 |

The expected values are those returned by the method `PHYC` of `\_SB.UFN1` (`{0x81, 0x38}, {0x82, 0x14}`), which this driver never evaluates. [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md#hardware-initialisation) writes ULPI 0x81 itself.

### ULPI access

`ulpi_read(reg)` (`sub_10004198`): ULPI_VIEWPORT = `(reg | 0x4000) << 16` (`ULPI_RUN`), polls `ULPI_RUN` up to 1000 times with a 10 µs stall. Returns bits 15-8.  
`ulpi_write(reg, mask, value)` (`sub_10004274`): read, then ULPI_VIEWPORT = `(reg | 0x6000) << 16 | ((old & ~mask) | (value & mask))` (`ULPI_RUN | ULPI_WRITE`), same polling.  
A timeout → `STATUS_IO_TIMEOUT` (0xC00000B5).

### Interrupt and bus events

ISR (`sub_100029FC`): reads USBSTS, OTGSC, ENDPTSETUPSTAT and ENDPTCOMPLETE, ORs them into the interrupt context, acknowledges them (writes back ENDPTCOMPLETE, USBSTS, `OTGSC & 0x7F7F7FFF`), queues the DPC.  
DPC (`sub_1000247C`), only when the device is in D0 and not in test mode:
1. ENDPTCOMPLETE ≠ 0 → `sub_10002E08`: for each bit (0-15 OUT, 16-31 IN) completes the transfer of the endpoint queue (`sub_10006950`).
2. ENDPTSETUPSTAT ≠ 0 → `sub_10002CE0`: copies the 8-byte setup packet from the EP0 OUT dQH (offset 0x28) under the setup tripwire (USBCMD.SUTW), writes 1 in ENDPTSETUPSTAT and waits until it is cleared, then sends `UsbfnEventSetupPacket`.
3. OTGSC.BSVIS: OTGSC.BSV = 1 → `UsbfnEventAttach`; 0 → `UsbfnEventDetach` (primed mask +0xE8 cleared).
4. Else USBSTS.SLI or PCI: PORTSC.SUSP = 1 → `UsbfnEventSuspend`, 0 → `UsbfnEventResume`.
5. USBSTS.URI → bus reset (`sub_10002EE4`): waits until PORTSC.PR = 0 (1000 × 100 µs; on timeout nothing is sent), DEVICEADDR = 0, clears ENDPTSETUPSTAT and ENDPTCOMPLETE, waits until ENDPTPRIME = 0, ENDPTFLUSH = 0xFFFFFFFF, un-stalls EP0, then `UsbfnEventReset` with the speed from PORTSC.PSPD (0 → 1 full, 1 → 0 low, 2 → 2 high).

The events are queued (28-byte records from a lookaside list) to a work item (`sub_10002830`) that passes them at PASSIVE_LEVEL to the class extension (function table entry 4, `off_1000CC30`), then to the charger state machine (`sub_10007448`). Before `UsbfnEventSetupPacket` it aborts the pending request of the EP0 queue. At the end of each batch it starts GP timer 0 (1 s).  
Event codes (`USBFN_EVENT`): 1 Attach, 2 Reset (+ speed), 3 Detach, 4 Suspend, 5 Resume, 6 SetupPacket (+ 8 bytes), 9 PortType (+ [port type](#charger-detection)).

### Charger detection

BC1.2 detection through ULPI vendor registers 0x84 (control) and 0x87 (status), same sequence as the `SNPS_28NM` PHY of the Linux `msm_otg.c` driver. State in context +0x04, abort event at +0x08 (set by detach/reset), result in +0x20.  
- `UsbfnEventAttach` → work item `sub_1000A3E0` → `sub_10009FAC(device, 1)`. If the result is "unknown" or SDP, a 5 s timer (`sub_1000A394`) runs the detection again with reason 2.
- `UsbfnEventReset` and `UsbfnEventSetupPacket` stop the timer (the host enumerates). A reset after an "invalid DCP" result runs the detection again.
- `UsbfnEventDetach` sets the abort event, USBCMD.RS = 0, port type = 0.

`sub_10009FAC`: `WdfDeviceStopIdleNoTrack`, USBCMD.RS = 0, then:
1. Data contact detect (`sub_1000995C`): needs OTGSC.BSV. ULPI 0x04 (Function Control) OpMode = 01 (non-driving), 0x84 bit 4 = 1 (DCD source on), then up to 10 × 50 ms until 0x87 bit 1 = 1. Ends with 0x84 bit 4 = 0.
2. Primary detection (`sub_10009BD0`): 0x84 bits 3-2 = 0, bits 1-0 = 11, 40 ms, 0x87 bit 0 = 0 → SDP (port type 1). Ends with 0x84 bits 1-0 = 0.
3. If not SDP, secondary detection (`sub_10009DD4`): 0x84 bits 0, 1, 3 = 1, 40 ms, 0x87 bit 0 = 1 → DCP (3), 0 → CDP (2). Ends with 0x84 bits 0, 1, 3 = 0.
4. Sends `UsbfnEventPortType` to the class extension. When run by the 5 s timer (reason 2), an SDP or a failed detection is reported as 4 (invalid dedicated charging port).
5. Except for DCP and "unknown": OpMode = 00 (normal) and USBCMD.RS = 1, so the host can enumerate the phone.
6. `WdfDeviceResumeIdleNoTrack`.

| Port type (`USBFN_PORT_TYPE`) | Meaning |
|-------------------------------|---------|
| 0 | Unknown |
| 1 | Standard downstream port (SDP) |
| 2 | Charging downstream port (CDP) |
| 3 | Dedicated charging port (DCP): the controller stays stopped |
| 4 | Invalid dedicated charging port: SDP that didn't reset/enumerate within 5 s |

ETW strings of the detection: "Charger Detection Abandoned", "USBCMD", "PORTSC1", "OTGSC", "UsbfnEventAttach", "UsbfnEventReset", "UsbfnEventDetach".

### UsbFnClx interface

Function table of the class extension (`.data:0x1000CC20`, 6 entries, filled by `WdfVersionBindClass`; it is `UsbFnClxExports` of [usbfnclx.sys](./usbfnclx.md#exported-functions), names in the last column):  
| Entry | Address | Called from | Use |
|-------|---------|-------------|-----|
| 0 | `off_1000CC20` | `DriverEntry` | Driver registration: `(WDFDRIVER, &config, RegistryPath)`, `UsbFnClxRegisterClient` |
| 1 | `off_1000CC24` | `EvtDriverUnload` | Driver cleanup, `UsbFnClxUnRegisterClient` |
| 2 | `off_1000CC28` | `EvtDriverDeviceAdd` | Device init: `(WDFDRIVER, DeviceInit, &DeviceAttributes, &InterruptConfig)`, `UsbFnClxProcessAddDevicePreDeviceCreate` |
| 3 | `off_1000CC2C` | `EvtDriverDeviceAdd` | Device registration after `WdfDeviceCreate`, `UsbFnClxProcessAddDevicePostDeviceCreate` |
| 4 | `off_1000CC30` | Event work item, D0 entry/exit, charger detection | Bus event notification `(WDFDEVICE, &{event, data})`, `UsbFnClxNotificationCallback` |
| 5 | `off_1000CC34` | Everywhere | Returns the controller context (244 bytes) of a `WDFDEVICE`, `UsbFnClxGetClientContext` |

Configuration given to entry 0 (80 bytes, version 0x10, controller context size 244):  
| Offset | Callback | Use |
|--------|----------|-----|
| 0x08 | `sub_100092E0` | `EvtDevicePrepareHardware`: spinlocks, map the memory resource, DMA, [initialisation](#controller-initialisation), debug buffers |
| 0x0C | `sub_10009474` (named `WppCleanupKm` in IDA) | `EvtDeviceReleaseHardware`: frees everything, unregisters WPP and ETW |
| 0x10 | `sub_10003370` | Start the controller (described below as "D0 entry"): called by UsbFnClx on `IOCTL_INTERNAL_USBFN_ACTIVATE_USB_BUS`, not by the framework |
| 0x14 | `sub_1000350C` | Stop the controller ("D0 exit"): called by UsbFnClx on `IOCTL_INTERNAL_USBFN_DEACTIVATE_USB_BUS` and when a configuration is unloaded |
| 0x18 | `sub_10003620` | `WdfInterruptReportActive`. Never called by UsbFnClx |
| 0x1C | `sub_100036E4` | `WdfInterruptReportInactive`. Called by UsbFnClx in `EvtDeviceArmWakeFromS0`, before the filter low-power IOCTL |
| 0x20 | `sub_100037A8` | Checks the 2 descriptor sets: device descriptor (bLength 18, type 1, bMaxPacketSize0 64, bNumConfigurations 1) and configuration descriptor (bLength 9, type 2), else `STATUS_NOT_SUPPORTED` |
| 0x24 | `sub_10003A34` | Endpoint add `(device, endpoint descriptor, WDFQUEUE*)`: creates the endpoint queue (see below) and configures the endpoint |
| 0x28 | `sub_10003B28` | Endpoint remove: deletes the DMA transaction and the queue |
| 0x2C | `sub_10003E20` | Endpoint enable: clears stall, resets data toggle, RXE/TXE = 1, `WdfIoQueueStart` (EP0: both directions) |
| 0x30 | `sub_10003EBC` | Endpoint disable: aborts the current transfer, `WdfIoQueuePurge`, RXE/TXE = 0 |
| 0x34 | `sub_100038C8` | Endpoint configure: dQH capabilities = `wMaxPacketSize << 16 \| ZLT` (+ IOS for EP0), ENDPTCTRLn type = bulk (8) or interrupt (12). Isochronous → `STATUS_NOT_SUPPORTED`, control on EP ≠ 0 → `STATUS_UNSUCCESSFUL` |
| 0x38 | `sub_100039EC` | Set address: DEVICEADDR = `address << 25 \| USBADRA` |
| 0x3C | `sub_10003A28` | Stub, returns `STATUS_SUCCESS`. Called by UsbFnClx after the status stage of `SET_ADDRESS` (address committed) |
| 0x40 | `sub_10003C6C` | Set/clear stall `(device, bEndpointAddress, BOOLEAN)`. Stall on EP0 is abandoned (`STATUS_UNSUCCESSFUL`) if a new setup packet arrived. Clear also resets the data toggle |
| 0x44 | `sub_10003CF8` | Get stall state from ENDPTCTRLn |
| 0x48 | `sub_10003F5C` | Test mode 1-5 (`TEST_J`, `TEST_K`, `TEST_SE0_NAK`, `TEST_PACKET`, `TEST_FORCE_ENABLE`), else `STATUS_INVALID_PARAMETER`. A DPC (`sub_10002BD8`) clears USBCMD.RS and sets PORTSC.PTC; context +0x01 = 1 stops the event processing |

Endpoint queues (`sub_10006388`): sequential, power managed by default, `EvtIoInternalDeviceControl` and `EvtIoStop`, context `EPQUEUEDATA` (the endpoint descriptor at +0x00, dQH address at +0x08, DMA transaction at +0x0C, current request at +0x10, 2 spinlocks, timer at +0x28). The queue of EP0 is stored for both directions in the controller context (+0x50 / +0x54); the other ones at `+0x50 + 8 × ep + 4 × dir`.

Per-endpoint timeout (`sub_10006E80`): started for 1 s when a transfer is primed on an endpoint ≠ 0. If the device power state machine is in `WdfDevStatePowerD0` (775) and the endpoint is still primed (ENDPTSTAT), the timer is renewed for 60 s. If the completion bit is set but wasn't processed, GP timer 0 is loaded with 1 ms to raise a new interrupt.

---

### internal IOCTL 0x2AC00D — IOCTL_INTERNAL_USBFN_TRANSFER_IN

This internal IOCTL is processed by Usbfnchipidea.sys (endpoint queue, `EvtWdfIoQueueIoInternalDeviceControl` 0x100061C0). It is sent by the function drivers to their `USBFN\<interface>` PDO and given by the class extension to the queue of the endpoint (according to the `PipeId` ?), see [genericusbfnclass.sys](./genericusbfnclass.md#ioctl-forwarding), [ufnserialclass.sys](./ufnserialclass.md#ioctls-sent), [ufnvidstream.sys](./ufnvidstream.md#ioctls-sent).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x3 (3) |
| Access | READ_AND_WRITE |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_TRANSFER_IN | not used | any (0 = zero-length packet) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | Data sent to the host (device → host) |

Common processing of the transfers (`sub_10005370(length, direction, request, queue, appendZlp)`):
1. The endpoint must be IN (or EP0) for IN transfers, OUT (or EP0) for OUT transfers, else `STATUS_INVALID_PARAMETER` (0xC000000D).
2. Length 0: one empty dTD, no DMA. Else `WdfDmaTransactionInitializeUsingRequest` + `WdfDmaTransactionExecute`: the scatter/gather list becomes a chain of dTDs (`sub_10004CF8`, max 5 pages each, length truncated to a multiple of `wMaxPacketSize` when the list is split).
3. The dTD chain is linked to the dQH and the endpoint is primed (ENDPTPRIME, waits up to 1000 µs for ENDPTPRIME/ENDPTSTAT/completion). Failure → `STATUS_UNSUCCESSFUL`.
4. The request is marked cancelable. It is completed by the DPC (ENDPTCOMPLETE) with the number of bytes transferred. A dTD with an error (halted / data buffer / transaction error) → `STATUS_DEVICE_DATA_ERROR` (0xC000009C), and a halted endpoint is stalled.
5. Cancellation / `EvtIoStop` / EP0 abort: flushes the endpoint (ENDPTFLUSH, 200 tries), completes with `STATUS_CANCELLED` (0xC0000120) and the bytes already transferred.

Only one transfer per endpoint at a time (sequential queue).  
Any other IoControlCode → `STATUS_NOT_SUPPORTED` (0xC00000BB). The other `IOCTL_INTERNAL_USBFN_*` codes (`GET_CLASS_INFO`, `GET/SET_PIPE_STATE`, `ACTIVATE_USB_BUS`, `BUS_EVENT_NOTIFICATION`, …) never reach this driver: they are handled by the class extension [usbfnclx.sys](./usbfnclx.md#internal-ioctls-on-the-child-pdos), which calls the [callbacks](#usbfnclx-interface) (e.g. stall).

---

### internal IOCTL 0x2AC011 — IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT

This internal IOCTL is processed by Usbfnchipidea.sys (endpoint queue, `EvtWdfIoQueueIoInternalDeviceControl` 0x100061C0).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x4 (4) |
| Access | READ_AND_WRITE |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT | not used | > 0, multiple of `wMaxPacketSize` |

Same as [internal IOCTL 0x2AC00D](#internal-ioctl-0x2ac00d--ioctl_internal_usbfn_transfer_in), plus an empty dTD after the data, so the host sees the end of the transfer.  
An OutputBuffer of length 0 or not a multiple of the `wMaxPacketSize` of the endpoint → `STATUS_INVALID_BUFFER_SIZE` (0xC0000206).

> [!NOTE]
> [ufnserialclass.sys](./ufnserialclass.md) and [ufnvidstream.sys](./ufnvidstream.md) send this IOCTL with any length: the class extension [usbfnclx.sys](./usbfnclx.md#internal-ioctls-on-the-controller-fdo) changes it into 0x2AC00D when no zero-length packet is needed (length 0 or not a multiple of `wMaxPacketSize`), so this driver never sees an invalid length.

---

### internal IOCTL 0x2AC016 — IOCTL_INTERNAL_USBFN_TRANSFER_OUT

This internal IOCTL is processed by Usbfnchipidea.sys (endpoint queue, `EvtWdfIoQueueIoInternalDeviceControl` 0x100061C0).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x5 (5) |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_TRANSFER_OUT | not used | any (0 = zero-length packet) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | Data received from the host, length in `Information` |

Same processing as [internal IOCTL 0x2AC00D](#internal-ioctl-0x2ac00d--ioctl_internal_usbfn_transfer_in), direction OUT.

---

### internal IOCTL 0x2AC018 — IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_IN

This internal IOCTL is processed by Usbfnchipidea.sys (endpoint queue, `EvtWdfIoQueueIoInternalDeviceControl` 0x100061C0).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x6 (6) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_IN | not used | not used |

Status stage of a control transfer: zero-length IN transfer on the endpoint of the queue (EP0).

---

### internal IOCTL 0x2AC01C — IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_OUT

This internal IOCTL is processed by Usbfnchipidea.sys (endpoint queue, `EvtWdfIoQueueIoInternalDeviceControl` 0x100061C0).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x7 (7) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_OUT | not used | not used |

Status stage of a control transfer: zero-length OUT transfer on the endpoint of the queue (EP0).

---

### internal IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This internal IOCTL is sent by Usbfnchipidea.sys to the lower device of its stack (ACPI PDO of `\_SB.UFN1`, through [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md) which forwards it) in `sub_100096F8`, during the [controller initialisation](#controller-initialisation).  
It is sent with `WdfIoTargetSendInternalIoctlSynchronously`, `WDF_REQUEST_SEND_OPTION_TIMEOUT | WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`, relative timeout of 500 ms (-5000000), no output buffer.

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | lower device (ACPI) | 8 | 0 |

Inputbuffer (`ACPI_EVAL_INPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `ACPI_EVAL_INPUT_BUFFER_SIGNATURE` ('BieA') |
| 04-07 | 5F 55 42 46 | Method name: `_UBF`, `_EY1` (5F 45 59 31) or `_EY2` (5F 45 59 32) |
