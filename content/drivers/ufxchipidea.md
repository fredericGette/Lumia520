## Ufxchipidea.sys

USB function controller driver for the ChipIdea HS core (USB device mode), client of the USB function class extension `UFX`.  
It is the same controller driver as [usbfnchipidea.sys](./usbfnchipidea.md) (same register usage, dQH/dTD DMA, ULPI access, BC1.2 charger detection, same WPP control GUID `UsbFnChipidea`), ported to the newer class extension [ufx01000.sys](./ufx01000.md) instead of [usbfnclx.sys](./usbfnclx.md): it binds the KMDF class library `UFX` version 1 (19 functions, `WdfVersionBindClass`) and gives UFX the 16 callbacks of a `UFXDEVICE` (host connect/disconnect, endpoint add, port detection, proprietary charger, …), see [UFX interface](#ufx-interface). UFX enumerates the `USBFN\<interface>` children, answers the standard requests and runs the USB state machine; this driver only drives the hardware: controller registers, endpoint queues, bus events (attach, reset, suspend, setup packet, …) and charger detection through the ULPI PHY.  
The power management that was in usbfnclx.sys is now in this driver: PoFx registration with one component, P-states through [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state), and the low-power internal IOCTLs 0x2AC03A / 0x2AC03E sent to the filter [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md) below it.  
It handles the transfers (`IOCTL_INTERNAL_USBFN_TRANSFER_*`, `CONTROL_STATUS_HANDSHAKE_*`) that the function drivers send to their `USBFN\<interface>` PDO and that UFX forwards to the transfer queue of the endpoint, and the pipe commands that UFX sends to the command queue of the endpoint.  
PDB: `ufxchipidea.pdb`. Pool tag `Chip` (0x70696843). The function names below are those of the IDA database.

There's no device name and no symbolic link. The FDO is initialised by `UfxFdoInit` (auto-generated name, SYSTEM only, see [ufx01000.sys](./ufx01000.md#exported-functions)); the device interface `{1b0444ed-…}` is registered by UFX.  

There's no parameters in the registry.  

GUID of the ETW provider (manifest `Microsoft-WindowsPhone-UfxChipidea`, `EtwRegister`):  
`{366370bb-e0f9-4a5f-9f74-804566ff4a96}`  

GUID of the WPP provider (`WPP_ThisDir_CTLGUID_UsbFnChipidea`, the same as [usbfnchipidea.sys](./usbfnchipidea.md)):  
`{b83729f3-8d84-4bea-897b-cd9fd667ba01}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Class extension `UFX` (same device stack, function table of 19 entries `UfxClassFunctions`, `.data:0x10010CA0`) | [ufx01000.sys](./ufx01000.md) | `UfxFdoInit`, `UfxDeviceCreate`, `UfxDeviceNotify*`, `UfxEndpointCreate`, …, see [UFX interface](#ufx-interface) |
| Lower device of its stack (`WdfDeviceGetIoTarget`) = filter [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md), then the ACPI PDO `ACPI\QCOM01C0\1` (`\_SB.UFN1`) | [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md) / [acpi.sys](./acpi.md) | [internal IOCTL 0x2AC03A](#internal-ioctl-0x2ac03a--ioctl_internal_usbfn_set_power_filter_state), [internal IOCTL 0x2AC03E](#internal-ioctl-0x2ac03e--exit-low-power-mode) (filter); [internal IOCTL 0x32C004](#internal-ioctl-0x32c004--ioctl_acpi_eval_method) `_UBF`, `VBUS`, `_EY1`, `_EY2` (ACPI) |
| Query interface `GUID_UFX_INTERFACE_PROPRIETARY_CHARGER` `{d3d11a34-aba6-40d6-b81e-99d0f6662df2}` (`WdfFdoQueryForInterface` down its own stack, 32 bytes, version 1) | ? (no driver of the stack exposes it ?) | [Proprietary charger](#proprietary-charger) |
| Power framework (`PoFxPowerControl`) | [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state) | `{3404daac-8e2c-41e4-8458-3158e5ad442b}` set P-state, see [Power management](#power-management) |
| Interface `{a437e7be-7175-4d69-9d30-f82efd144b5a}` (`GUID_DEVINTERFACE_USBFNTEST_POWER_TEST`, `IoRegisterPlugPlayNotification`) | test driver ? | Query interface `{688e49d4-1563-446b-838b-11287a4d0445}` (`GUID_USBFN_INTERFACE_POWER_TEST`, 20 bytes, version 1) on arrival, then the notification is unregistered. Same as [usbfnclx.sys](./usbfnclx.md) |

### Resources

Only the resources of the device are used, there's no hardcoded address (`ChipideaInitializeDevice` 0x1000CF94, called by `EvtDevicePrepareHardware`):  
| Resource | Use |
|----------|-----|
| Memory (on the Lumia 520: 0x12500000, length 0x200, `USB1_HS_BASE`) | `MmMapIoSpace(MmNonCached)` (context +0x40/+0x44), then DMA initialisation |
| 1st interrupt (on the Lumia 520: GSIV 0x84) | Controller interrupt: ISR `ChipideaIsr`, DPC `ChipideaDpc` (context +0x54) |
| 2nd interrupt (on the Lumia 520: GSIV 0x84 again, wake capable) | `ChipideaControllerWakeIsr`, passive-level, `CanWakeDevice`: only traces and returns FALSE (context +0x58) |
| 3rd interrupt (none on the Lumia 520) | VBUS attach: `ChipideaAttachIsr`, passive-level, `CanWakeDevice`. Simulates OTGSC.BSVIS + BSV (0x80800) and queues the DPC (context +0x5C) |
| 4th interrupt (none on the Lumia 520) | VBUS detach: `ChipideaDetachIsr`, same, simulates BSVIS with BSV = 0 (context +0x60) |

The 3rd/4th interrupts are for platforms where VBUS is sensed outside the controller (PMIC/GPIO). When the attach interrupt exists, attach/detach also drive the PHY "session valid" override (as `HS_PHY_SESS_VLD_CTRL` in the Linux `ci_hdrc_msm` driver): ULPI register 0x96 (`MISC_A`) = 3 (`VBUSVLDEXTSEL | VBUSVLDEXT`), register 0x0A0 (`GENCONFIG_2`) bit 7 (`SESS_VLD_CTRL_EN`) and USBCMD bit 25 (`SESS_VLD_CTRL`) set on attach, cleared on detach. Without it (Lumia 520) S0 idle is disabled, see [Power management](#power-management).

DMA (`InitializeDma` 0x10002968), identical to [usbfnchipidea.sys](./usbfnchipidea.md#resources):
- `WdfDeviceSetAlignmentRequirement(4096)`, `WdfDmaEnablerCreate` profile 5 (`WdfDmaProfileScatterGatherDuplex`), maximum length 0x10000.
- Common buffer of 2048 bytes: endpoint queue heads (dQH), 16 endpoints × 2 directions × 64 bytes (OUT at `ep * 128`, IN at `ep * 128 + 64`), physical address in `ENDPOINTLISTADDR`.
- Common buffer of 1024 bytes, 32-byte aligned: pool of 32 transfer descriptors (dTD) of 32 bytes.
- One `WDFDMATRANSACTION` per endpoint.

### ChipIdea registers

Same offsets and use as [usbfnchipidea.sys](./usbfnchipidea.md#chipidea-registers) (USBCMD 0x140, USBSTS 0x144, USBINTR 0x148, DEVICEADDR 0x154, ENDPOINTLISTADDR 0x158, ULPI_VIEWPORT 0x170, PORTSC1 0x184, OTGSC 0x1A4, USBMODE 0x1A8, ENDPTSETUPSTAT 0x1AC, ENDPTPRIME 0x1B0, ENDPTFLUSH 0x1B4, ENDPTSTAT 0x1B8, ENDPTCOMPLETE 0x1BC, ENDPTCTRLn 0x1C0 + 4 × ep). Differences:  
| Offset | Name | Use |
|--------|------|-----|
| 0x080 / 0x084 | GPTIMER0LD / GPTIMER0CTRL | Only written by the endpoint watchdog (1000 = 1 ms, then 0xC0000000 `GPTRUN \| GPTRST`) to raise a new interrupt. No periodic 1 s timer after each batch of events |
| 0x0A0 | GENCONFIG_2 | bit 7, see [Resources](#resources) |
| 0x140 | USBCMD | RS set by the UFX callback *host connect*, cleared by *host disconnect*; bit 19 (ITC = 8) at initialisation |
| 0x184 | PORTSC1 | bit 6 = FPR (force port resume) for remote wakeup |

### Controller initialisation

`InitializeController` (0x10002D9C), called from `EvtDeviceWdmPostPoFxRegisterDevice` (first D0 entry) and again on detach after a failed endpoint flush (context +0xF8 < 0):
1. USBCMD.RS = 0, USBCMD.RST = 1, waits until RST = 0 (no timeout), USBCMD.ITC = 8.
2. [ACPI methods](#acpi-methods) (`ChipIdeaDoVendorInitialization`).
3. USBMODE = device mode, setup lockout off (`(v & ~0xB) | 0xA`).
4. Clears the dQH and dTD buffers, writes ENDPOINTLISTADDR, clears ENDPTSETUPSTAT and USBSTS.
5. OTGSC |= BSVIE, USBINTR |= 0x03000144 (PCE, URE, SLE, TIE0, TIE1).
6. Pulses OTGSC.OT (clear, 10 µs, set), writes 0 to ENDPTSETUPSTAT and acknowledges USBSTS again.

Unlike usbfnchipidea.sys, ENDPTCTRL1-15 are not preset to bulk. After the initialisation: [internal IOCTL 0x2AC03E](#internal-ioctl-0x2ac03e--exit-low-power-mode), `UfxDeviceNotifyHardwareReady`, interrupts enabled (OTGSC = `(v & 0x77007FFF) | BSVIE`, USBINTR.UE; if VBUS is already present the attach is simulated), `WdfInterruptQueueDpcForIsr`, `WdfDeviceResumeIdle`.

### ACPI methods

`ChipIdeaDoVendorInitialization` (0x10002C24) evaluates 4 methods of `\_SB.UFN1` with [internal IOCTL 0x32C004](#internal-ioctl-0x32c004--ioctl_acpi_eval_method) (`ChipIdeaAcpiInvokeMethod` 0x1000CB7C). It always returns `STATUS_SUCCESS`: failures are only traced.  
| Method | Exists in the Lumia 520 DSDT | Output | After a successful call |
|--------|------------------------------|--------|-------------------------|
| `_UBF` | Yes: USBMODE = 2, PORTSC \|= 2, AHBMODE = 8, AHBBURST = 0, GENCONFIG = 0xCB0 | - | - |
| `VBUS` | No | 20 bytes `ACPI_EVAL_OUTPUT_BUFFER`, signature `AeoB` and count ≠ 0 required | Integer argument (type 0) ≠ 0 → context +0x16E = 1: VBUS is considered present (OTGSC.BSV forced) when the interrupts are enabled |
| `_EY1` | No | - | Reads ULPI register 0x81, expects 0x38 |
| `_EY2` | No (only evaluated if 0x81 = 0x38) | - | Reads ULPI register 0x82, expects 0x14 |

`VBUS` is new compared with [usbfnchipidea.sys](./usbfnchipidea.md#acpi-methods).

### ULPI access

Same as [usbfnchipidea.sys](./usbfnchipidea.md#ulpi-access): `ReadULPIReg` (0x10002744) / `WriteULPIReg(reg, mask, value)` (0x10002820) through ULPI_VIEWPORT, `ULPI_RUN` polled up to 1000 × 10 µs, timeout → `STATUS_IO_TIMEOUT` (0xC00000B5).

### Interrupt and bus events

ISR (`ChipideaIsr` 0x10006EC0): reads USBSTS (acknowledged), OTGSC, ENDPTSETUPSTAT and ENDPTCOMPLETE, ORs them into the interrupt context (`CHIPIDEAINTERRUPTDATA`), acknowledges ENDPTCOMPLETE and `OTGSC & 0x7F7F7FFF`, copies the whole register block into a flight recorder on the 10th interrupt, queues the DPC.  
DPC (`ChipideaDpc` 0x10006554), only when the hardware is ready (+0x17C): VBUS attach (BSVIS with BSV = 1) → `ChipIdeaInterruptHandleAttach`; ENDPTCOMPLETE → `ChipIdeaInterruptHandleEndpointCompletion`; URI → bus reset (`ChipIdeaInterruptHandleReset`: DEVICEADDR = 0, clears ENDPTSETUPSTAT/ENDPTCOMPLETE, waits until ENDPTPRIME = 0 (no timeout), ENDPTFLUSH = 0xFFFFFFFF, un-stalls EP0) and, once PORTSC.PR = 0, reset complete with the speed (PORTSC.PSPD 0 → 1 full, 1 → 0 low, 2 → 2 high); ENDPTSETUPSTAT → setup packet (copied from the EP0 OUT dQH under the setup tripwire); SLI / PCI → suspend / resume (PORTSC.SUSP); VBUS detach → `ChipIdeaInterruptHandleDetach`. ETW events `DpcAttachEvent`, `DpcResetBeginEvent`, `DpcResetEndEvent`, `DpcSetupEvent`, `DpcSuspendEvent`, `DpcResumeEvent`, `DpcDetachEvent`, `DpcNoneEvent`.

The DPC doesn't call UFX: it queues 28-byte notifications (lookaside, `ChipIdeaInterruptAddNotification`) to 2 work items (`ChipideaDpcNotificationsWorkItem`), one for request completions (type 1, context +0xF0) and one for bus events (type 2, context +0xEC), which call at PASSIVE_LEVEL (`ChipIdeaInterruptProcessNotification` 0x10007894):  
| Bus event | UFX call |
|-----------|----------|
| 1 Attach | `UfxDeviceNotifyAttach` |
| 2 Reset (+ speed) | `UfxDeviceNotifyReset(speed)` |
| 3 Detach | Stops the [charger detection](#charger-detection), aborts the proprietary charger operation, `UfxDeviceNotifyDetach`, re-initialises the controller if an endpoint flush failed |
| 4 Suspend | `UfxDeviceNotifySuspend` |
| 5 Resume | `UfxDeviceNotifyResume` |
| 6 Setup packet (+ 8 bytes) | Cancels the active request of the EP0 queue, then `UfxEndpointNotifySetup(EP0, packet)` |

After *host disconnect*, the bus event work item completes the UFX event (`UfxDeviceEventComplete`) once the queued notifications are drained (flag +0x17D).

### Charger detection

BC1.2 detection through the ULPI vendor registers 0x84 (control) and 0x87 (status), same sequence as [usbfnchipidea.sys](./usbfnchipidea.md#charger-detection), but started by UFX (callback *port detect*, `ChargerDetectionStart` → work item `ChargerDetectionWorkItem` → `PerformChargerDetection` 0x100022DC) and without the 5 s retry timer (the 5 s charge timer is in UFX). Phase in context +0x08 (1-11), abort event +0x0C (set on detach by `ChargerDetectionStop`, reset when UFX reports the Detached state; while it is set a new detection is refused with `STATUS_UNSUCCESSFUL`), result +0x24.
1. Data contact detect (`PerformDataContactDetection`): ULPI 0x04 OpMode = 01 (non-driving), 0x84 bit 4 = 0 then 1, up to 10 × 50 ms until 0x87 bit 1 = 1, then 0x84 bit 4 = 0. No contact → result 0.
2. Primary detection (`PerformPrimaryPortDetection`): 0x84 bits 3-2 = 0, bits 1-0 = 11, 40 ms, 0x87 bit 0, then bits 1-0 = 0. Bit 0 = 0 → result 0.
3. Secondary detection (`PerformSecondaryPortDetection`): 0x84 bits 0, 1, 3 = 1, 40 ms, 0x87 bit 0 = 1 → DCP (3, the bits stay set until the detach), 0 → CDP (2, bits cleared).
4. Except for DCP: ULPI 0x04 OpMode = 00 (normal). The controller is not started here (USBCMD.RS is set by *host connect*).
5. `UfxDevicePortDetectComplete(result)`.

> [!NOTE]
> The result is never 1 (SDP): a standard host port (primary detection negative), a missing data contact and any error are all reported as 0 (`UsbfnUnknownPort`), which UFX maps to `DevicePortUnknown`. usbfnchipidea.sys reports SDP as 1.

### Power management

- PoFx (`ChipideaPowerAssignPowerFrameworkSettings`, `WdfDeviceWdmAssignPowerFrameworkSettings`): 1 component with 1 F-state, `EvtDeviceWdmPostPoFxRegisterDevice` (stores the PoFx handle at +0x110, then runs the [controller initialisation](#controller-initialisation) on the first registration), `PowerControlCallback` (`GUID_POWER_CHANGE_P_STATE` completion, else `STATUS_NOT_IMPLEMENTED`).
- S0 idle (`ChipideaPowerAssignS0IdleSettings`): `IdleCanWakeFromS0`, D3, 100 ms, user control allowed, idle timeout type 2 (system managed with hint ?). `Enabled` = `WdfFalse` when there's no VBUS attach interrupt (Lumia 520), else default.
- `UfxDeviceStopOrResumeIdle` (from the callbacks *USB state change* / *port change*): `WdfDeviceStopIdle` in Attached/Default with an unknown, SDP or CDP port (DCP: only while a proprietary charger detection is pending), Addressed, Configured, Suspended (unless it was Configured); `WdfDeviceResumeIdle` otherwise (Detached, DCP, invalid DCP, …). Device state and port type kept at +0x164 / +0x168.
- `EvtDeviceD0Entry`: first time `ChipideaPowerInitialize` (PoFx, S0 idle, test interface notification, preallocated request). Later, when the hardware is ready: P-state 0, then [internal IOCTL 0x2AC03E](#internal-ioctl-0x2ac03e--exit-low-power-mode). Hardware not ready → `STATUS_INVALID_DEVICE_STATE`.
- `EvtDeviceD0Exit`: P-state from the device state.
- `EvtDeviceArmWakeFromS0`: `WdfInterruptReportInactive` on the controller interrupt, then [internal IOCTL 0x2AC03A](#internal-ioctl-0x2ac03a--ioctl_internal_usbfn_set_power_filter_state); on failure `WdfInterruptReportActive` again (ETW `EnterLPM` / `LPMEntryFailed`).

P-state (`ChipideaPowerPepSetPState` 0x10003620): `PoFxPowerControl(handle, {3404daac-…}, {component 0, P-state}, 8, output, 12)`. Output `00-03` = 3 → done; 1 → waits up to 2 s for `PowerControlCallback`, else `STATUS_IO_TIMEOUT`. P-states 0/1 are not sent again while the "on" flag (+0x160) is set. No PoFx handle → `STATUS_INVALID_DEVICE_STATE`.  
| Device state (+0x164) | Port type (+0x168) | P-state |
|-----------------------|--------------------|---------|
| Attached | SDP / CDP / DCP or proprietary / invalid DCP | 0 / 1 / 2 / 3 |
| Suspended | | 4 |
| Detached | | 5 |
| D0 entry, other states | | 0 |

> [!NOTE]
> A P-state failure in D0 entry/exit is fatal: `WdfVerifierKeBugCheck(0xFE BUGCODE_USB_DRIVER, 1, WDFDEVICE, status, P-state)` (WDF function table entry 0x170).

### UFX interface

`UfxDevice_CreateDevice` (0x1000DD74) calls `UfxDeviceCreate` with this callback structure (68 bytes, copied by UFX at `UFXDEVICE_CONTEXT` +0x28, see [ufx01000.sys](./ufx01000.md#client-callbacks)):  
| Offset | UFX offset | Callback | Use |
|--------|------------|----------|-----|
| 0x04 | 0x2C | `UfxDevice_EvtDeviceHostConnect` | USBCMD.RS = 1, then `UfxDeviceEventComplete` |
| 0x08 | 0x30 | `UfxDevice_EvtDeviceHostDisconnect` | USBCMD.RS = 0; event completed later by the bus event work item |
| 0x0C | 0x34 | `UfxDevice_EvtDeviceAddressed` | DEVICEADDR = `address << 25 \| USBADRA` |
| 0x10 | 0x38 | `UfxDevice_EvtDeviceEndpointAdd` | `UfxEndpoint_CreateEndpoint`, see [Endpoints](#endpoints) |
| 0x14 | 0x3C | `UfxDevice_EvtDeviceDefaultEndpointAdd` | EP0 with descriptor `07 05 00 00 <wMaxPacketSize>` |
| 0x18 | 0x40 | `UfxDevice_EvtDeviceUsbStateChange` | Detached → resets the charger detection abort; [idle](#power-management) |
| 0x1C | 0x44 | `UfxDevice_EvtDevicePortChange` | [idle](#power-management) |
| 0x20 | 0x48 | `UfxDevice_EvtDevicePortDetect` | [Charger detection](#charger-detection); start failure → `UfxDevicePortDetectComplete(0)` |
| 0x24 | 0x4C | `UfxDevice_EvtDeviceRemoteWakeupSignal` | `WdfDeviceStopIdle`, PORTSC.FPR = 1, `WdfDeviceResumeIdle` |
| 0x28 | 0x50 | - | Controller reset: not provided |
| 0x2C | 0x54 | `UfxDevice_EvtDeviceTestModeSet` | Test mode 1-5 (`TEST_J` … `TEST_FORCE_ENABLE`), else `STATUS_INVALID_PARAMETER`; DPC `EvtTestModeDpc`: USBINTR.UE = 0, PORTSC.PTC = mode |
| 0x30 / 0x34 | 0x58 / 0x5C | - | Test hook, SuperSpeed power feature: not provided |
| 0x38 | 0x60 | `UfxDevice_EvtDeviceProprietaryChargerDetect` | [Proprietary charger](#proprietary-charger) |
| 0x3C | 0x64 | `UfxDevice_EvtDeviceProprietaryChargerSetProperty` | idem |
| 0x40 | 0x68 | `UfxDevice_EvtDeviceProprietaryChargerReset` | idem |

Capabilities (16 bytes): Size 16, maximum speed 2 (high speed), remote wake signal delay 5 ms ?, `PdcpSupported` = result of the proprietary charger query.  
Contexts: `UFXDEVICE_PRIVCONTEXT` (16 bytes, signature `Ufxd` 0x64786655, WDFDEVICE at +0x04, UFXDEVICE at +0x08, byte +0x0C), `UFXENDPOINT_PRIVCONTEXT` (20 bytes, signature `Ufxe` 0x65786655, endpoint descriptor at +0x0C).  
`EvtIoDeviceControl` / `EvtIoInternalDeviceControl` of the default queue (sequential) only call `UfxDeviceIoControl` / `UfxDeviceIoInternalControl` (UFX's [IOCTL 0x2AC110](./ufx01000.md#ioctl-0x2ac110--enable-data-connection), [0x2AC114](./ufx01000.md#ioctl-0x2ac114--update-wait-for-user-prompt), [internal IOCTL 0x29C500](./ufx01000.md#internal-ioctl-0x29c500--proprietary-charger-set-property)); not handled by UFX → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

### Proprietary charger

At device creation (`ProprietaryChargerQuerySupport` 0x1000D704) the driver queries `GUID_UFX_INTERFACE_PROPRIETARY_CHARGER` from its stack (stored at context +0x1A4):  
| Offset | Field |
|--------|-------|
| 0x00 | Size / Version (`INTERFACE`) |
| 0x04 | Context |
| 0x08 / 0x0C | InterfaceReference / InterfaceDereference |
| 0x10 | DetectCharger(Context, output 20 bytes: charger GUID + ?), required |
| 0x14 | SetProperty(Context, input), required |
| 0x18 | AbortOperation(Context), required |
| 0x1C | ResetOperation(Context), optional |

If the query fails or one of the 3 required functions is missing, `PdcpSupported` = 0 and UFX never calls the proprietary callbacks. Otherwise 4 work items forward the UFX callbacks to the interface: detect → `UfxDeviceProprietaryChargerDetectComplete(output)` (zero GUID on failure); set property (24 bytes retrieved from the request) → request completed with the status; abort (queued on detach while an operation runs); reset → `UfxDeviceEventComplete`. An operation while VBUS isn't present → `STATUS_DEVICE_NOT_CONNECTED` (0xC000009D).

### Endpoints

`UfxEndpoint_CreateEndpoint` (0x1000E6D8) → `UfxEndpointCreate` with 2 queues:
- Transfer queue (`ChipIdeaEndpointGetQueueProperties`): sequential, `EvtIoInternalDeviceControl` = `ChipideaEndpointDeviceIoControl` (0x1000504C), `EvtIoStop` = `ChipIdeaEndpointIoStop`, context `EPQUEUEDATA` (descriptor +0x00, dQH +0x08, DMA transaction +0x0C, active request +0x10, watchdog timer +0x28, UFXENDPOINT +0x2C). Stored at context `+0x64 + 8 × ep + 4 × dir` (EP0: both).
- Command queue: sequential, `EvtIoInternalDeviceControl` = `EvtEndpointCommandQueue` (0x10009D1C), see [Command queue](#internal-ioctls-of-the-command-queue).

Endpoint configuration (`ChipIdeaEndpointConfigure`): dQH capabilities = `wMaxPacketSize << 16 | ZLT` (+ IOS for EP0), ENDPTCTRLn type bulk (8) or interrupt (12), isochronous → `STATUS_NOT_SUPPORTED`, control on EP ≠ 0 → `STATUS_UNSUCCESSFUL`. Then the endpoint is enabled (RXE/TXE).  
Watchdog (`ChipIdeaEndPointWatchdog`): while the device is in `WdfDevStatePowerD0` (775) and the endpoint is still primed (ENDPTSTAT), renewed for 60 s; if the completion bit is set but wasn't processed, GP timer 0 = 1 ms to raise a new interrupt (ETW `EpWatchdogTimerStart` "Renewing timer").

ETW events of the provider: `PortDetection`, `Register` (USBCMD/PORTSC1/OTGSC dumps after a detection error), `DetectionPhase`, `EnterLPM`, `ExitLPM`, `LPMEntryFailed`, `LPMExitFailed`, `PStateTransitionFailed`, `EpWatchdogWorkItemBegin/End`, `EpWatchdogTimerStart`, `Dpc*Event`.

---

### internal IOCTL 0x2AC00D — IOCTL_INTERNAL_USBFN_TRANSFER_IN

This internal IOCTL is processed by Ufxchipidea.sys (transfer queue of the endpoint, `ChipideaEndpointDeviceIoControl` 0x1000504C). It is sent by the function drivers to their `USBFN\<interface>` PDO and forwarded by [ufx01000.sys](./ufx01000.md#internal-ioctls-on-the-child-pdos) (`WdfRequestForwardToParentDeviceIoQueue`), or sent by UFX itself for the data stage of the standard requests.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x3 (3) |
| Access | READ_AND_WRITE |
| Method | METHOD_IN_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_TRANSFER_IN | not used | any (0 = zero-length packet) |

Outputbuffer: data sent to the host (device → host).

Same transfer processing as [usbfnchipidea.sys](./usbfnchipidea.md#internal-ioctl-0x2ac00d--ioctl_internal_usbfn_transfer_in) (`ChipIdeaTransactionBegin` 0x10008954): DMA scatter/gather list → chain of dTDs, endpoint primed, request cancelable, completed by the DPC with the number of bytes transferred, `STATUS_DEVICE_DATA_ERROR` on a dTD error, `STATUS_CANCELLED` on cancellation / `EvtIoStop`.  
Any other IoControlCode on the transfer queue → `STATUS_NOT_SUPPORTED` (0xC00000BB).

---

### internal IOCTL 0x2AC011 — IOCTL_INTERNAL_USBFN_TRANSFER_IN_APPEND_ZERO_PKT

Processed by Ufxchipidea.sys (transfer queue). Device 0x2A, Function 0x4, READ_AND_WRITE, METHOD_IN_DIRECT.  
Same as [internal IOCTL 0x2AC00D](#internal-ioctl-0x2ac00d--ioctl_internal_usbfn_transfer_in) plus a zero-length dTD. OutputBuffer of length 0 or not a multiple of `wMaxPacketSize` → `STATUS_INVALID_BUFFER_SIZE` (0xC0000206) (UFX rewrites such requests into 0x2AC00D first).

---

### internal IOCTL 0x2AC016 — IOCTL_INTERNAL_USBFN_TRANSFER_OUT

Processed by Ufxchipidea.sys (transfer queue). Device 0x2A, Function 0x5, READ_AND_WRITE, METHOD_OUT_DIRECT.  
Same as [internal IOCTL 0x2AC00D](#internal-ioctl-0x2ac00d--ioctl_internal_usbfn_transfer_in), direction OUT: OutputBuffer = data received from the host, length in `Information`.

---

### internal IOCTL 0x2AC018 / 0x2AC01C — CONTROL_STATUS_HANDSHAKE_IN / OUT

Processed by Ufxchipidea.sys (transfer queue of EP0). Device 0x2A, Function 0x6 / 0x7, READ_AND_WRITE, METHOD_BUFFERED. No buffers: zero-length IN / OUT transfer (status stage of a control transfer).

---

### Internal IOCTLs of the command queue

Sent by [ufx01000.sys](./ufx01000.md#internal-ioctls-sent-to-the-client-endpoint-queues) to the command queue of an endpoint (`EvtEndpointCommandQueue` 0x10009D1C, buffer retrieved first):  
| Code | Name | Device / Function / Method | Handling |
|------|------|----------------------------|----------|
| 0x2AC026 | IOCTL_INTERNAL_USBFN_GET_PIPE_STATE | 0x2A / 0x9 / METHOD_OUT_DIRECT | Output BOOLEAN: stalled (ENDPTCTRLn RXS/TXS; EP0: either) |
| 0x2AC029 | IOCTL_INTERNAL_USBFN_SET_PIPE_STATE | 0x2A / 0xA / METHOD_IN_DIRECT | BOOLEAN ≠ 0 → stall (EP0: abandoned with `STATUS_UNSUCCESSFUL` if a new setup packet arrived), 0 → clear stall + data toggle reset |
| 0x2AC401 | Descriptor update ? | 0x2A / 0x100 / METHOD_IN_DIRECT | New endpoint descriptor copied into the endpoint context (length not checked ?), endpoint disabled, reconfigured, enabled |

Any other code → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### internal IOCTL 0x2AC03A — IOCTL_INTERNAL_USBFN_SET_POWER_FILTER_STATE

This internal IOCTL is sent by Ufxchipidea.sys to the lower device of its stack, [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md#internal-ioctl-0x2ac03a--ioctl_internal_usbfn_set_power_filter_state), in `ChipideaPowerFilterSetState` (0x1000CCAC), from `EvtDeviceArmWakeFromS0`. Preallocated request (+0x11C), `WdfRequestSend` synchronous with a 2 s relative timeout, then `WdfRequestReuse`. No lower target → `STATUS_DEVICE_DOES_NOT_EXIST` (0xC00000C0).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0xE (14) |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_SET_POWER_FILTER_STATE | lower device | 8 | 0 |

Inputbuffer (context +0x114):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 03 00 00 00 | Device state (`USBFN_DEVICE_STATE`, context +0x164) |
| 04-07 | e.g. 05 00 00 00 | P-state from the device state (see [Power management](#power-management)); [usbfnclx.sys](./usbfnclx.md#internal-ioctl-0x2ac03a--ioctl_internal_usbfn_set_power_filter_state) sends 0 |

Context +0x140 = 1 when the request succeeded (low-power mode entered).

---

### internal IOCTL 0x2AC03E — Exit low-power mode

This internal IOCTL is sent by Ufxchipidea.sys to the lower device of its stack, [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md#internal-ioctl-0x2ac03e), in `ChipideaPowerFilterExitLPM` (0x10003410), from `EvtDeviceD0Entry` and after the first controller initialisation. No buffers, preallocated request, synchronous, 2 s timeout. Context +0x140 = 0 afterwards; failure → ETW `LPMExitFailed`, only traced.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0xF (15) |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

---

### internal IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This internal IOCTL is sent by Ufxchipidea.sys (`ChipIdeaSendSynchronousIoctlToPdo` 0x1000CAA8) to the lower device of its stack (ACPI PDO of `\_SB.UFN1`, through [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md) which forwards it), during the [controller initialisation](#controller-initialisation). `WdfIoTargetSendInternalIoctlSynchronously`, relative timeout 500 ms.

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | lower device (ACPI) | 8 | 0, or 20 for `VBUS` |

Inputbuffer (`ACPI_EVAL_INPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `ACPI_EVAL_INPUT_BUFFER_SIGNATURE` ('BieA') |
| 04-07 | 5F 55 42 46 | Method name: `_UBF`, `VBUS` (56 42 55 53), `_EY1` (5F 45 59 31) or `_EY2` (5F 45 59 32) |

Outputbuffer (`VBUS` only, `ACPI_EVAL_OUTPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature 'BoeA', else `STATUS_INVALID_DEVICE_REQUEST` |
| 04-07 | | Length |
| 08-0B | ≠ 0 | Count, else `STATUS_INVALID_DEVICE_REQUEST` |
| 0C-0D | 00 00 | Argument type: integer |
| 0E-0F | | Data length |
| 10-13 | | Integer: ≠ 0 = VBUS present |

---

### Other GUID

Proprietary charger query interface (`GUID_UFX_INTERFACE_PROPRIETARY_CHARGER`)  
`{d3d11a34-aba6-40d6-b81e-99d0f6662df2}`

`GUID_DEVINTERFACE_USBFNTEST_POWER_TEST`  
`{a437e7be-7175-4d69-9d30-f82efd144b5a}`

`GUID_USBFN_INTERFACE_POWER_TEST`  
`{688e49d4-1563-446b-838b-11287a4d0445}`

PoFx power control: set P-state ([qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state))  
`{3404daac-8e2c-41e4-8458-3158e5ad442b}`
