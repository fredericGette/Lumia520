## Ufxsynopsys.sys

USB function controller driver for the Synopsys DesignWare USB 3.0 core (DWC3, version string `2.03a`, USB device mode), client of the USB function class extension `UFX`.  
It plays the same role as [ufxchipidea.sys](./ufxchipidea.md) for a different controller: it binds the KMDF class library `UFX` version 1 (19 functions, `WdfVersionBindClass`, table `UfxClassFunctions` at `.data:0x10012FE0`) and gives [ufx01000.sys](./ufx01000.md) the callbacks of a `UFXDEVICE` (see [UFX interface](#ufx-interface)). UFX enumerates the function drivers and runs the USB state machine; this driver drives the hardware: DWC3 global/device registers, event buffer, endpoint commands (`DEPCMD`), TRB rings for the transfers, and BC1.2 charger detection through the Qualcomm `QSCRATCH` registers of the wrapper (as in the Linux `dwc3-msm` driver).  
It supports SuperSpeed (DCFG.DEVSPD = SuperSpeed, U1/U2, `UfxDeviceNotifyReset` speed 3) unless the ACPI method `_HSP` exists. The Lumia 520 (MSM8930) has a ChipIdea HS controller only, so this driver is probably unused on it (it targets SoCs with a DWC3 core, such as the MSM8974 ?).  
Source paths in the binary: `src\drivers\product\drivers\usbfn\client\ufxsynopsys\{defaultqueue,device,driver,interrupt,proprietarycharger,registers,ufxdevice,ufxendpoint,transfer,portdetection}.c`. PDB: `ufxsynopsys.pdb`. Pool tags `Synf` (0x666E7953, WDF driver / detector), `Tmf1` (0x31666D54, state machine framework). The function names below are those of the IDA database.

There's no device name and no symbolic link. The FDO is initialised by `UfxFdoInit` (auto-generated name, SYSTEM only, see [ufx01000.sys](./ufx01000.md#exported-functions)); the device interface `{1b0444ed-…}` is registered by UFX.  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters\Smf` (`WdfDriverOpenParametersRegistryKey` + `WdfRegistryOpenKey`, `KEY_READ`; `SmfReadRegistry` 0x1000B260), debug options of the port detection state machine, all optional:  
| Registry value | value | comment |
|----------------|-------|---------|
| VerifyEventHandlers | 0 | REG_DWORD (`WdfRegistryQueryULong`), state machine verifier option ? |
| VerifyEventQueueSize | 0 | REG_DWORD, idem |
| VerifyEventInstances | 0 | REG_DWORD, idem |

GUID of the ETW provider (manifest `Microsoft-WindowsPhone-UfxSynopsys`, `EtwRegister`; events `RegisterRead` / `RegisterWrite` for every register access):  
`{49b12c7c-4bd5-4f93-bb75-30fce739600b}`  

GUID of the ETW provider used by the embedded state machine framework (`Microsoft-WindowsPhone-Ufx`, the same as [ufx01000.sys](./ufx01000.md)):  
`{e98ebdbf-3058-4784-8521-47860b1d2b8e}`  

GUID of the WPP provider (`WPP_ThisDir_CTLGUID_SynopsysWPPGuid`):  
`{8650230d-68b0-476e-93ed-634490dce145}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Class extension `UFX` (same device stack, function table of 19 entries) | [ufx01000.sys](./ufx01000.md) | `UfxFdoInit`, `UfxDeviceCreate`, `UfxDeviceNotify*`, `UfxEndpointCreate`, …, see [UFX interface](#ufx-interface) |
| Lower device of its stack (`WdfDeviceGetIoTarget`, ACPI PDO) | [acpi.sys](./acpi.md) | [internal IOCTL 0x32C004](#internal-ioctl-0x32c004--ioctl_acpi_eval_method) `_HSP` |
| Query interface `USBFN_FILTER_INTERFACE_CONTROLLER_RESET` `{e5680f62-3d02-4112-ade6-796371080cf7}` (`WdfFdoQueryForInterface` down its own stack, 16 bytes, version 0) | lower filter ? | `SynopsysDeviceVendorReset` (0x10002B24), at each D0 entry while VBUS is absent. The interface is only queried: none of its functions is called and it is not dereferenced |
| Query interface `GUID_UFX_INTERFACE_PROPRIETARY_CHARGER` `{d3d11a34-aba6-40d6-b81e-99d0f6662df2}` (`WdfFdoQueryForInterface` down its own stack, 32 bytes, version 1) | ? | [Proprietary charger](#proprietary-charger), same layout as in [ufxchipidea.sys](./ufxchipidea.md#proprietary-charger) |

### Resources

`EvtDevicePrepareHardware` (0x1000F3D0):  
| Resource | Use |
|----------|-----|
| Memory (`CmResourceTypeMemory`) | `SynopsysRegistersCreate` (0x1001032C): length must be ≥ 0xB20, else `STATUS_INVALID_PARAMETER` (0xC000000D); `MmMapIoSpace(MmNonCached)` of the whole resource. Global registers at base + 0xC100, device registers at base + 0xC700, QSCRATCH at base + 0xF8800 |
| 1st interrupt | Controller interrupt: ISR `DeviceInterrupt_EvtInterruptIsr`, DPC `DeviceInterrupt_EvtInterruptDpc` (context +0x04) |
| 2nd interrupt | Ignored (only a flag at context +0x08) |
| 3rd interrupt | VBUS attach: `DeviceInterrupt_EvtAttachInterruptIsr`, passive-level, `CanWakeDevice`. Sets "VBUS present" (+0x21) and "changed" (+0x22), queues the DPC (context +0x0C) |
| 4th interrupt | VBUS detach: `DeviceInterrupt_EvtDetachInterruptIsr`, same with "VBUS present" = 0 (context +0x10) |

> [!NOTE]
> The length check (0xB20) is smaller than the registers used (up to 0xF8830): a memory resource of less than 0xF8834 bytes is accepted and then accessed out of range.

Without the attach/detach interrupts the driver never reports an attach to UFX (VBUS is only sensed through these interrupts).

DMA: `WdfDeviceSetAlignmentRequirement(128)`, `WdfDmaEnablerCreate` profile 5 (`WdfDmaProfileScatterGatherDuplex`), maximum length 0x1CFFFFFF (context +0x14). Common buffers (`WdfCommonBufferCreateWithConfig`):  
| Buffer | Size | Alignment | Use |
|--------|------|-----------|-----|
| Event buffer | 4096 | 4096 | Event buffer 0 of the controller (1024 events of 4 bytes) |
| TRB ring, one per endpoint | 512 | 16 | 32 TRBs of 16 bytes; TRB 29 (offset 0x1D0) is a link TRB (TRBCTL = 8, HWO) back to the start |
| Extra buffer, one per endpoint | 1024 | 64 | Bounce buffer ? |
| Setup buffer (control endpoints) | 8 | 64 | Setup packet |

### DWC3 registers

Offsets from the start of the memory resource:  
| Offset | Name | Use |
|--------|------|-----|
| 0xC110 | GCTL | Soft reset: `(v & 0x6CFFF) \| 0x112000` (PRTCAPDIR = device, …). Connection done: bit 6 = 1 for a SuperSpeed connection, else 0 |
| 0xC200 | GUSB2PHYCFG(0) | bit 6 (SUSPHY) set on a SuperSpeed connection |
| 0xC2C0 | GUSB3PIPECTL(0) | Soft reset: bit 6 and bit 17 (SUSPENDENABLE) cleared; bit 17 set on a non-SuperSpeed connection |
| 0xC400 / 0xC404 | GEVNTADRLO(0) / GEVNTADRHI(0) | Physical address of the event buffer |
| 0xC408 | GEVNTSIZ(0) | `(v & 0x7FFF0000) \| 0x1000`; bit 31 (interrupt mask) set by the ISR, cleared at the end of the DPC |
| 0xC40C | GEVNTCOUNT(0) | Number of event bytes pending; the DPC writes back the bytes consumed. Cleared (`& 0xFFFF0000`) at programming |
| 0xC700 | DCFG | Soft reset: `(v & 0xFFBFFFF8) \| 0x400004` (DEVSPD = 4 SuperSpeed, LPMCAP). DEVADDR (bits 9:3) = address on *addressed*, 0 on bus reset |
| 0xC704 | DCTL | bit 30 CSFTRST (soft reset, polled without timeout), bit 31 RUN_STOP + bit 23 (*host connect* / *disconnect*), bits 4:1 TSTCTL (test mode), bits 8:5 ULSTCHNGREQ (5 = Rx.Detect on disconnect, 8 = Recovery for remote wakeup), bits 9 / 11 (INITU1ENA / INITU2ENA) set when Configured, bits 10 / 12 (ACCEPTU1ENA / ACCEPTU2ENA) from `SET/CLEAR_FEATURE(U1/U2_ENABLE)` |
| 0xC708 | DEVTEN | `\|= 0x25F` (disconnect, reset, connect done, link state change, wakeup, bit 6, bit 9) |
| 0xC70C | DSTS | bits 2:0 connected speed, bit 22 DEVCTRLHLT |
| 0xC720 | DALEPENA | 3 (EP0 OUT/IN) after a reset; bit of each physical endpoint set when it is configured |
| 0xC800 + 0x10 × n | DEPCMDPAR2 / PAR1 / PAR0 / DEPCMD of physical endpoint n | See [Endpoints](#endpoints) |
| 0xCC08 | ? | Address kept in the detector context (+0x1C), not used |
| 0xF8818 | QSCRATCH `CHARGING_DET_CTRL` | [Charger detection](#charger-detection) |
| 0xF881C | QSCRATCH `CHARGING_DET_OUTPUT` | idem |
| 0xF8820 / 0xF8824 | QSCRATCH `ALT_INTERRUPT_EN` / `HS_PHY_IRQ_STAT` | Addresses kept in the detector context, not used |
| 0xF8830 | QSCRATCH `SS_PHY_CTRL` | bit 24 cleared on each connection done (`LANE0_PWR_PRESENT` ?) |

### Controller initialisation

`EvtDeviceD0Entry` (0x10002A34): when VBUS is not present (+0x21 = 0), `SynopsysDeviceVendorReset` (interface query, see above) then `SynopsysDevicePerformSoftReset` (0x10002BF0):
1. DCTL.CSFTRST = 1, waits until it is 0 (no timeout).
2. GCTL = `(v & 0x6CFFF) | 0x112000`.
3. GUSB3PIPECTL = GUSB2PHYCFG & ~0x40, then GUSB3PIPECTL &= ~0x20000.
4. Event buffer programming (`SynopsysInterruptProgramEventBuffers` 0x10003F74): GEVNTADRHI/LO, GEVNTSIZ = 4096, GEVNTCOUNT cleared, read index = 0.
5. DCFG = SuperSpeed + LPMCAP, DEVTEN |= 0x25F.

When the previous power state is `WdfPowerDeviceD3Final` (first start): `UfxDeviceNotifyHardwareReady`. `EvtDeviceD0Exit`, `EvtDeviceReleaseHardware` and `EvtDeviceSurpriseRemoval` only trace.

> [!NOTE]
> Step 3 writes the value read from GUSB2PHYCFG (0xC200) into GUSB3PIPECTL (0xC2C0): probably a bug (clearing GUSB2PHYCFG.SUSPHY was intended ?).

`SynopsysDeviceInitializeDefaultEndpoint` (0x10002EE4), on the USB state Attached coming from Detached: resets the EP0 transfer, `DEPSTARTCFG` (XferRscIdx 0), configures EP0 OUT and IN, starts the setup stage, waits until DEPCMD0.CMDACT = 0 (no timeout), DALEPENA = 3.

### Interrupt and events

ISR (`DeviceInterrupt_EvtInterruptIsr` 0x100039A0): GEVNTCOUNT & 0xFFFF ≠ 0 → GEVNTSIZ bit 31 = 1 (mask), `WdfInterruptQueueDpcForIsr`. Always returns TRUE.  
DPC (`DeviceInterrupt_EvtInterruptDpc` 0x10003AB4), under the device spin lock (+0x24):
1. VBUS change from the attach/detach interrupts: attach → (detach first if it was attached) `UfxDeviceNotifyAttach`.
2. Up to 16 events from the event buffer (read index +0x10, wraps at 1024): bit 0 = 1 → device event (`HandleDeviceEvent`), else endpoint event (`HandleEndpointEvent`); GEVNTCOUNT = 4 per event consumed.
3. Disconnect pending (+0x29) and DSTS.DEVCTRLHLT = 1 → stops the 2 s timer and completes the UFX event (`UfxDeviceEventComplete`).
4. VBUS gone → stops the [charger detection](#charger-detection) (event Reset), queues the proprietary charger abort, `UfxDeviceNotifyDetach`.
5. GEVNTSIZ bit 31 = 0 (unmask).

Device events (bits 11:8):  
| Event | Name | Handling |
|-------|------|----------|
| 0 | Disconnect | DCTL.ULSTCHNGREQ = 5 (Rx.Detect) |
| 1 | USB reset | `UfxDevice_Reset` (DALEPENA = 3, all transfers reset), DCFG.DEVADDR = 0 |
| 2 | Connection done | DSTS speed: 4 → SuperSpeed (3), 0 → high (2), 1 / 3 → full (1), 2 → low (0); GCTL bit 6, PHY suspend bits, QSCRATCH 0xF8830 bit 24 = 0, then `UfxDeviceNotifyReset(speed)` |
| 3 | Link state change | Link state (bits 19:16) = 0 (U0) and suspended → `UfxDeviceNotifyResume` |
| 4 | Wakeup | Suspended → `UfxDeviceNotifyResume` |
| 6 | Suspend | `UfxDeviceNotifySuspend` |
| 10, 11 | Command complete / overflow | Traced only |

Endpoint events: physical endpoint in bits 5:1, event in bits 9:6: 1 / 2 (XferComplete / XferInProgress) → `SynopsysTransferComplete`, 3 (XferNotReady) → `SynopsysTransferNotReady`, 7 (EPCmdCmplt, command in bits 27:24) → Start Transfer (6), End Transfer (8), Set Stall (4), Clear Stall (5) completions.

### Charger detection

BC1.2 detection through the QSCRATCH registers, run by a small state machine (framework `Smf*`, declaration `DriverDecl_PortDetector`, states `EnablingDcd`, `CheckDcd`, `DisablingDcd`, `Detecting`, `CheckCharging`, `DcpOrCdp`, `DcpOrCdp2`, `Aca`, `Stopping`, `Stopped`; events 0 Reset, 1 Start (UFX callback *port detect*), 2 Timeout (`DetectorTimer`)). Variables `DcdChecks`, `PortType`, `Check`.
1. Data contact detect: `CHARGING_DET_CTRL` bit 1 = 0, then bits 1-0 = 11; up to 10 × 50 ms until `CHARGING_DET_OUTPUT` bit 1 = 1; then bits 1-0 = 0.
2. Primary detection: `CHARGING_DET_CTRL` bits 3-2 = 0, bits 5-4 = 11, 40 ms. `CHARGING_DET_OUTPUT` bit 0 (charger detected) = 0 → port type 0; 1 → `CHARGING_DET_CTRL = (v & ~0x34) | 0x10`, then `CHARGING_DET_OUTPUT` bit 2 (RID_A ?) = 1 → port type 0.
3. Secondary detection: `CHARGING_DET_CTRL |= 0x34`, 40 ms, `CHARGING_DET_OUTPUT` bit 0 = 1 → DCP (3), 0 → CDP (2).
4. `UfxDevicePortDetectComplete(port type)`. For DCP the detection bits stay set until the detach (flag +0x20), else `CHARGING_DET_CTRL &= ~0x30`.

The ACA state does nothing. As in [ufxchipidea.sys](./ufxchipidea.md#charger-detection), the result is never 1 (SDP): a standard host port is reported as 0 (`UsbfnUnknownPort`).

### Power management

- S0 idle (`WdfDeviceAssignS0IdleSettings`, settings kept at context +0x30): `IdleCanWakeFromS0`, D3, 100 ms, user control allowed, `Enabled` = default, idle timeout type 2 (system managed with hint ?). No PoFx P-states, no wake interrupt handling.
- `UfxDeviceStopOrResumeIdle` (0x10010B98, from the callbacks *USB state change* / *port change*): `WdfDeviceStopIdle` in Attached/Default with an unknown, SDP or CDP port, Addressed, Configured, Suspended; DCP: idle state D2, stop idle only while a proprietary charger detection is pending (UFX context +0x111); proprietary charger (port 5): idle state from context +0x94 ?, resume idle; `WdfDeviceResumeIdle` otherwise. The new Dx state is applied with `WdfDeviceAssignS0IdleSettings`. Device state and port type kept at UFX context +0x108 / +0x10C.

### UFX interface

`SynopsysUfxDeviceCreate` (0x100104C0) first evaluates `_HSP` with [internal IOCTL 0x32C004](#internal-ioctl-0x32c004--ioctl_acpi_eval_method), then queries the [proprietary charger](#proprietary-charger) interface and calls `UfxDeviceCreate` with this callback structure (68 bytes, see [ufx01000.sys](./ufx01000.md#client-callbacks)):  
| Offset | UFX offset | Callback | Use |
|--------|------------|----------|-----|
| 0x04 | 0x2C | `UfxDevice_EvtDeviceHostConnect` | `UfxDeviceSetRunStop(1)`: DCTL.RUN_STOP = 1, then `UfxDeviceEventComplete` |
| 0x08 | 0x30 | `UfxDevice_EvtDeviceHostDisconnect` | `UfxDevice_Reset`, DCTL.RUN_STOP = 0; if DSTS.DEVCTRLHLT is not set yet, the event is completed by the DPC when the controller halts or by `EvtDisconnectTimer` after 2 s |
| 0x0C | 0x34 | `UfxDevice_EvtDeviceAddressed` | DCFG.DEVADDR = address |
| 0x10 | 0x38 | `UfxDevice_EvtDeviceEndpointAdd` | `UfxEndpointAdd`, see [Endpoints](#endpoints) |
| 0x14 | 0x3C | `UfxDevice_EvtDeviceDefaultEndpointAdd` | EP0 with descriptor `07 05 00 00 <wMaxPacketSize> 00` |
| 0x18 | 0x40 | `UfxDevice_EvtDeviceUsbStateChange` | Attached after Detached → [default endpoint initialisation](#controller-initialisation); Configured (not after Suspended) → configures all endpoints, DCTL \|= 0xA00; [idle](#power-management) |
| 0x1C | 0x44 | `UfxDevice_EvtDevicePortChange` | [idle](#power-management) |
| 0x20 | 0x48 | `UfxDevice_EvtDevicePortDetect` | Event Start of the [charger detection](#charger-detection) |
| 0x24 | 0x4C | `UfxDevice_EvtDeviceRemoteWakeupSignal` | `WdfDeviceStopIdle`, DCTL.ULSTCHNGREQ = 8 (Recovery), `WdfDeviceResumeIdle` |
| 0x28 | 0x50 | - | Controller reset: not provided |
| 0x2C | 0x54 | `UfxDevice_EvtDeviceTestModeSet` | Test mode ≤ 5 → DCTL.TSTCTL = mode, else `STATUS_UNSUCCESSFUL` (0xC0000001) |
| 0x30 | 0x58 | - | Test hook: not provided |
| 0x34 | 0x5C | `UfxDevice_EvtDeviceSuperSpeedPowerFeature` | Feature 48 (U1_ENABLE) → DCTL bit 10, 49 (U2_ENABLE) → DCTL bit 12 |
| 0x38 | 0x60 | `UfxDevice_EvtDeviceProprietaryChargerDetect` | [Proprietary charger](#proprietary-charger) |
| 0x3C | 0x64 | `UfxDevice_EvtDeviceProprietaryChargerSetProperty` | idem |
| 0x40 | 0x68 | `UfxDevice_EvtDeviceProprietaryChargerReset` | idem |

Capabilities (16 bytes): Size 16, maximum speed 2 (high speed) if `_HSP` succeeded, else 3 (SuperSpeed), offset 8 = 1, `PdcpSupported` = result of the proprietary charger query.  
`EvtIoDeviceControl` / `EvtIoInternalDeviceControl` of the default queue (sequential) only call `UfxDeviceIoControl` / `UfxDeviceIoInternalControl` (UFX's [IOCTL 0x2AC110](./ufx01000.md#ioctl-0x2ac110--enable-data-connection), [0x2AC114](./ufx01000.md#ioctl-0x2ac114--update-wait-for-user-prompt), [internal IOCTL 0x29C500](./ufx01000.md#internal-ioctl-0x29c500--proprietary-charger-set-property)); not handled by UFX → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

### Proprietary charger

Same interface and same behaviour as [ufxchipidea.sys](./ufxchipidea.md#proprietary-charger) (`ProprietaryChargerQuerySupport` 0x1000FC78, interface at controller context +0x54, DetectCharger / SetProperty / AbortOperation required, ResetOperation optional, 4 work items, 20-byte detection output at +0x84, 24-byte set property input, `STATUS_DEVICE_NOT_CONNECTED` (0xC000009D) while VBUS is absent).

### Endpoints

`UfxEndpointAdd` (0x10004F04) → `UfxEndpointCreate` with 2 queues:
- Transfer queue: manual dispatch, `EvtIoStop` = `EndpointQueue_EvtIoStop`, ready notification `SynopsysTransferReadyNotify`; `TransferNextRequest` (0x10009C04) retrieves the requests: [internal IOCTLs 0x2AC00D, 0x2AC011, 0x2AC016](#internal-ioctls-of-the-transfer-queue) → `TransferBegin` (DMA transaction, TRBs), 0x2AC018 / 0x2AC01C → `TransferHandshake`, other codes → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).
- Command queue: sequential, `EvtIoInternalDeviceControl` = `EvtEndpointCommandQueue` (0x10005830), see [Command queue](#internal-ioctls-of-the-command-queue).

Physical endpoint number = 2 × endpoint number + 1 for IN (EP0: 0 and 1). Endpoint commands (`UfxEndpointCommand` 0x100051C0): waits until DEPCMD.CMDACT = 0 (no timeout), writes PAR0 (+0x08), PAR1 (+0x04), PAR2 (+0x00) = 0, then DEPCMD = command | 0x500 (CMDACT + CMDIOC):  
| Command | Name | Use |
|---------|------|-----|
| 1 | Set Endpoint Configuration | PAR0 = type, max packet size, FIFO number (IN), action (0 init, 2 modify for EP0); PAR1 = event enables (XferCmpl, XferNRdy, XferInProgress for non-control), interval, endpoint number/direction |
| 2 | Set Transfer Resource Configuration | PAR0 = 1 |
| 3 | Get Endpoint State | |
| 4 / 5 | Set Stall / Clear Stall | |
| 6 / 7 / 8 | Start / Update / End Transfer | TRB ring address |
| 9 | Start New Configuration | Sent to DEPCMD0, XferRscIdx 0 (default endpoint) or 2 (when an endpoint is configured) |

---

### Internal IOCTLs of the transfer queue

Processed by Ufxsynopsys.sys (transfer queue of the endpoint, `TransferNextRequest` 0x10009C04). Sent by the function drivers to their `USBFN\<interface>` PDO and forwarded by [ufx01000.sys](./ufx01000.md#internal-ioctls-on-the-child-pdos), or sent by UFX itself for the standard requests. Same codes and buffers as [ufxchipidea.sys](./ufxchipidea.md#internal-ioctl-0x2ac00d--ioctl_internal_usbfn_transfer_in):  
| Code | Name | Device / Function / Method |
|------|------|----------------------------|
| 0x2AC00D | IOCTL_INTERNAL_USBFN_TRANSFER_IN | 0x2A / 0x3 / METHOD_IN_DIRECT |
| 0x2AC011 | IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT | 0x2A / 0x4 / METHOD_IN_DIRECT |
| 0x2AC016 | IOCTL_INTERNAL_USBFN_TRANSFER_OUT | 0x2A / 0x5 / METHOD_OUT_DIRECT |
| 0x2AC018 | IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_IN | 0x2A / 0x6 / METHOD_BUFFERED |
| 0x2AC01C | IOCTL_INTERNAL_USBFN_CONTROL_STATUS_HANDSHAKE_OUT | 0x2A / 0x7 / METHOD_BUFFERED |

---

### Internal IOCTLs of the command queue

Sent by [ufx01000.sys](./ufx01000.md#internal-ioctls-sent-to-the-client-endpoint-queues) to the command queue of an endpoint (`EvtEndpointCommandQueue` 0x10005830, input buffer retrieved first):  
| Code | Name | Device / Function / Method | Handling |
|------|------|----------------------------|----------|
| 0x2AC026 | IOCTL_INTERNAL_USBFN_GET_PIPE_STATE | 0x2A / 0x9 / METHOD_OUT_DIRECT | BOOLEAN: stalled (transfer context +0x3C) |
| 0x2AC029 | IOCTL_INTERNAL_USBFN_SET_PIPE_STATE | 0x2A / 0xA / METHOD_IN_DIRECT | BOOLEAN ≠ 0 → Set Stall, 0 → Clear Stall; the request is completed by the command complete event |
| 0x2AC401 | Descriptor update ? | 0x2A / 0x100 / METHOD_IN_DIRECT | New endpoint descriptor (7 bytes) copied into the endpoint context; the endpoint is reconfigured only when its number is 0 ? |

Any other code → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### internal IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This internal IOCTL is sent by Ufxsynopsys.sys to the lower device of its stack (ACPI PDO) in `SynopsysUfxDeviceCreate` (0x100104C0), `WdfIoTargetSendInternalIoctlSynchronously` without timeout, input in a preallocated WDF memory object.

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
| 04-07 | 5F 48 53 50 | Method name `_HSP` (high-speed only platform ?) |

Success → maximum speed high speed; failure (method absent) → SuperSpeed.

---

### Other GUID

Controller reset query interface (`USBFN_FILTER_INTERFACE_CONTROLLER_RESET`)  
`{e5680f62-3d02-4112-ade6-796371080cf7}`

Proprietary charger query interface (`GUID_UFX_INTERFACE_PROPRIETARY_CHARGER`)  
`{d3d11a34-aba6-40d6-b81e-99d0f6662df2}`
