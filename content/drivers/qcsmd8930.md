## Qcsmd8930.sys

Shared Memory Driver (SMD).  
It implements the Qualcomm SMD transport: byte-stream channels between the application processor and the other processors of the SoC (MODEM, QDSP6/LPASS, RIVA/WCNSS), using FIFOs located in the shared memory. Other drivers open a channel by name, then exchange data with plain read/write requests, see [SMD channels](#smd-channels).  
The shared memory is reached through [qcsmem8930.sys](./qcsmem8930.md) (function table + address translation). The outgoing interrupts to the other processors and the incoming interrupts are described by the ACPI method `INTR`. At start, the driver announces itself to the other processors with [qcsmsm8930.sys](./qcsmsm8930.md), and registers with the RPE notifier [qcrpen8930.sys](./qcrpen8930.md) so its channels are reset when the MODEM or the RIVA restarts.  
The code is a port of the Qualcomm "SMD Lite" library (`smdl_open`, `smdl_close`, … see e.g. [smd_lite_api.c](https://github.com/Rivko/android-firmware-qti-sdm670/blob/20bb8ae36c93fc16bbadda0e0a83f930c0c8a271/boot_images/QcomPkg/Library/SmdLib/smd_lite_api.c), [smd_main.c](https://github.com/Rivko/android-firmware-qti-sdm670/blob/20bb8ae36c93fc16bbadda0e0a83f930c0c8a271/boot_images/QcomPkg/Library/SmdLib/smd_main.c)), SMD protocol version 0x00020000.  
Built from `P:\SMD\rel\8.2.1.1\arm\Release\qcsmd8930.pdb` (build date "Mar 24 2014 19:49:47").

Device name : `\Device\SMD`  
There's no symbolic link: the device is only used by other kernel drivers.

There's no parameters in the registry.  

GUID of the ETW provider (manifest-based, `McGenEventRegister` in `DriverEntry`):  
`{11b77432-3f15-465e-9fe9-75e62ad513c6}`

GUID of the ETW provider of the RPE helper library (`McGenEventRegister` in `RpeInit`):  
`{57e95397-c84e-4f53-9473-56207aaa5938}`

GUID of the WPP control provider:  
`{2c5261dc-3e68-4919-98f9-aa5240a0f7f0}`  
WPP trace message GUIDs: `{70bc03be-d470-e804-e682-cddccc6414c5}`, `{eb699ad5-a337-1377-ad52-c384a8c2f4a4}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMEM | [qcsmem8930.sys](./qcsmem8930.md) | Shared Memory table driver. [internal IOCTL 0x42000](#internal-ioctl-0x42000) (function table) and [internal IOCTL 0x42004](#internal-ioctl-0x42004) (address translation) |
| \Device\SMSM | [qcsmsm8930.sys](./qcsmsm8930.md) | Shared Memory State Machine. [IOCTL 0x32000](#ioctl-0x32000), sent once by a work item at start |
| Interface `{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}` | [qcchipinfo8930.sys](./qcchipinfo8930.md) | Chip identification. [IOCTL 0x8C1F2008](#ioctl-0x8c1f2008) and [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004), for the RIVA interrupt workaround |
| Interface `{59752ed7-b9d5-4121-818d-c69f1e667015}` (\Device\RPEN) | [qcrpen8930.sys](./qcrpen8930.md) | RPE notifier, Helper query-interface. See [RPE clients](#rpe-clients) |
| ACPI node of the device | acpi.sys | [IOCTL 0x32C004](#ioctl-0x32c004) `IOCTL_ACPI_EVAL_METHOD`, method `INTR` |

### WDF setup

`SmdEvtDeviceAdd` (0x4173E8):
- IO type: `WdfDeviceIoBuffered`. Not the power policy owner.
- PnP/power callbacks: `EvtWdfDevicePrepareHardware`, `EvtWdfDeviceReleaseHardware` and the 5 `EvtWdfDeviceSelfManagedIo*` callbacks only write a trace and return `STATUS_SUCCESS`.
- `EvtWdfDeviceSurpriseRemoval` calls `KeBugCheckEx(0x14E, 0x51736430 'Qsd0', 0, 0, 0)`: removing the SMD device crashes the phone.
- `smd_init` (0x405810), see [Initialisation](#initialisation). If it fails, the device is not created.
- Two device interfaces: `{f9d15453-8335-434c-aa72-fcd925f135f3}` and `{07631ee5-21bd-455b-bd1f-f41b43f3a9bc}` (SMD Lite API).
- `WdfDeviceSetStaticStopRemove`.
- Default queue: sequential dispatch, passive level, only `EvtIoDefault` = `EvtWdfIoQueueIoDefault` (0x417BAC). It forwards **every** request to the per-handle queue of the file object (see below).
- A lookaside list of 12-byte entries, pool tag `iovc` (0x63766F69).
- The query-interface `{07631ee5-21bd-455b-bd1f-f41b43f3a9bc}`, see [SMD Lite API interface](#smd-lite-api-interface).
- `SetupRPE` (0x401460), see [RPE clients](#rpe-clients).

Each `CreateFile` / `WdfIoTargetOpen` on `\Device\SMD` gets its own `SMD_PORT_CONTEXT` (0xD4 bytes) on the WDF file object (`EvtWdfDeviceFileCreate`, 0x417D18). A handle is bound to at most one channel. The context contains 5 queues, 4 work items, 3 wait-locks and 1 spinlock:  
| Offset | Content |
|--------|---------|
| 0x60 | Sequential queue, not power-managed: `EvtIoRead` = `EvtWdfIoQueueIoRead`, `EvtIoWrite` = `EvtWdfIoQueueIoWrite`, `EvtIoInternalDeviceControl` = `EvtWdfIoQueueIoInternalDeviceControl`. Receives everything forwarded by the default queue |
| 0x64 | Manual queue: pending reads and [internal IOCTL 0x22013](#internal-ioctl-0x22013). Processed by work item `SmdProcessIoReadRequestsWorkItem` (+0x74) |
| 0x68 | Manual queue: pending writes and [internal IOCTL 0x22017](#internal-ioctl-0x22017). Processed by work item `SmdProcessIoRequestsWorkItem` (+0x78) |
| 0x6C | Manual queue: pending [internal IOCTL 0x22003](#internal-ioctl-0x22003) waiting for the remote side to open the channel. Completed by work item `SmdCompletePendingReadRequestsWorkItem` (+0x7C) |
| 0x70 | Manual queue: pending [internal IOCTL 0x22007](#internal-ioctl-0x22007) waiting for the close to complete. Completed by work item `SmdCompletePendingWriteRequestsWorkItem` (+0x80) |

`EvtWdfFileClose` closes the channel if it's still open (`smdl_close`), after purging the read and write queues.

Plain `ReadFile`/`WriteFile` (IRP_MJ_READ / IRP_MJ_WRITE) on a handle whose channel is open:
- Read: the request is put in the read queue (+0x64) and the read work item is queued. It's completed with the data copied from the receive FIFO (`InterfaceFunction_03`) when data is available.
- Write: the request is put in the write queue (+0x68) and the write work item copies the data into the transmit FIFO (`InterfaceFunction_05`).

Requests on a handle without a `SMD_PORT_CONTEXT` complete with `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

### Initialisation

`smd_init` (0x405810):
1. Opens `\Device\SMEM` and gets the function table of [qcsmem8930.sys](./qcsmem8930.md) with [internal IOCTL 0x42000](#internal-ioctl-0x42000) (`call_device_SMEM`).
2. `smem_version_set(SMEM_VERSION_SMD 0x6B, 0x00020000, 0xFFFFFFFF)`. A mismatch ends in `fatal_error01` ("smd_init: SMD protocol version (%d) does not match"), i.e. a bugcheck.
3. `SmdLoadInterruptConfiguration` (0x405E98): evaluates the ACPI method `INTR` ([IOCTL 0x32C004](#ioctl-0x32c004)) and creates one WDF interrupt per entry (`SmdInitializeInterruptsFromConfig`, `SmdCreateAndConfigureInterrupt`). The ISR only queues the DPC; the DPC (`EvtInterruptDpc`) runs the handlers of the SMD channels. Any malformed answer → `STATUS_DEVICE_CONFIGURATION_ERROR` (0xC0000182).
4. Creates the work item `SmdInitializeSmsmCommunication` (0x4052B8): opens `\Device\SMSM` and sends [IOCTL 0x32000](#ioctl-0x32000) with `SMSM_APPS_STATE`, clear 0, set `0x00800000` (`SMSM_SMD_LOOPBACK` in the Linux `smd_private.h`).
5. `IoRegisterPlugPlayNotification` on the qcchipinfo8930.sys interface `{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}` (`qcchipinfo8930_interface_changed`, 0x405674).

RIVA interrupt workaround (same as in [qcsmsm8930.sys](./qcsmsm8930.md)): when qcchipinfo8930.sys arrives, the driver sends [IOCTL 0x8C1F2008](#ioctl-0x8c1f2008) and [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004). If the chip id is 87 (0x57, MSM8960) and the chip version is lower than 0x20000 (2.0), i.e. on a MSM8960 v1 only (never on the Lumia 520, MSM8227), it maps the physical address `0x00801284` (GPIO_40 ?) with `MmMapIoSpace` and writes 0 then 2 to it. After that, every interrupt sent to the WCN (`smd_event_send`) is preceded by the same 0 / 2 write.

Format of the `INTR` package (ACPI_EVAL_OUTPUT_BUFFER, signature `BoeA`, all arguments must be integers, at least 4):  
| Argument | Comment |
|----------|---------|
| 0 | Must be 1 (version ?) |
| 1 | N = number of entries. The package must contain exactly 4×(N+1) integers |
| 2 | ? (not used) |
| 3 | ? (not used) |
| 4+4i | Remote processor of entry i (`smem_host_type`: 1 = MODEM, 2 = QDSP6, 4 = WCN/RIVA, …). Must be < 6 (`SMEM_RPM`) |
| 5+4i | Physical address of the outgoing interrupt register. Translated to a virtual address by [internal IOCTL 0x42004](#internal-ioctl-0x42004); it must be one of the memory resources of qcsmem8930.sys |
| 6+4i | Value written to that register to interrupt the remote processor (`irq_out_mask`) |
| 7+4i | ? (not used) |

The WDF interrupt objects themselves come from the interrupt resources of the ACPI device (one per entry, in the same order ?).

### Lumia 520 ACPI node

From the DSDT. The node is `\_SB.SMD0` (`_HID` `QCOM0F10`, `_UID` 0), with `_DEP` on `\_SB.SMEM` ([qcsmem8930.sys](./qcsmem8930.md)). It has a child device `\_SB.SMD0.GPS` (`_HID` `QCOM_GPS`, `_CID` `ACPIQCOM_GPS`, `_UID` 0), so the GPS driver is enumerated as a child of this driver's node.

`_CRS`: 4 interrupts `Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive)`, in the order of the `INTR` entries:  
| `INTR` entry | Remote processor (`smem_host_type`) | Outgoing register | Value | Incoming interrupt (GIC) |
|--------------|-------------------------------------|-------------------|-------|--------------------------|
| 0 | 1 MODEM | 0x02011008 | 0x00000008 (bit 3) | 69 |
| 1 | 2 QDSP6 (LPASS) | 0x02011008 | 0x00008000 (bit 15) | 122 |
| 2 | 3 DSPS | 0x12104080 | 0x00000001 | 170 |
| 3 | 4 WCNSS (RIVA) | 0x02011008 | 0x02000000 (bit 25) | 230 |

`INTR` returns `Package (0x14) { 1, 4, 0, 0, <the 4 entries above, each followed by 0> }`. Every outgoing register is one of the memory resources of [qcsmem8930.sys](./qcsmem8930.md#memory-resources). The order of the `_CRS` interrupts matches the order of the `INTR` entries, which supports the "same order" assumption above.

### SMD channels

A channel is identified by its name (at most 20 characters including the terminating zero) and its edge (`smd_channel_type`: 0 = APPS↔MODEM, 1 = APPS↔QDSP, 6 = APPS↔RIVA, …; must be < 15).  
Opening a channel from another kernel driver:
1. Open a handle (or a WDF I/O target) on `\Device\SMD`.
2. Send [internal IOCTL 0x22003](#internal-ioctl-0x22003) with a pointer to the channel name, the edge and the FIFO size.
3. Exchange data with read/write requests on the same handle.
4. Close with [internal IOCTL 0x22007](#internal-ioctl-0x22007), or just close the handle.

The special name `LOOPBACK` is only accepted on edge 0 (APPS↔MODEM) and opens the channel in loopback mode.

Channels opened by the other drivers (from their binaries):  
| Channel port name | Driver |
|-------------------|--------|
| RPCRPY_CNTL | qcipcrouter8930.sys |
| IPCRTR | qcipcrouter8930.sys |
| sys_mon | qcipcrouter8930.sys |
| DATA6_CNTL | [qcqmux8930.sys](./qcqmux8930.md#smd-channels) |
| DATA7_CNTL | [qcqmux8930.sys](./qcqmux8930.md#smd-channels) |
| DATA8_CNTL | [qcqmux8930.sys](./qcqmux8930.md#smd-channels) |
| DATA9_CNTL | [qcqmux8930.sys](./qcqmux8930.md#smd-channels) |
| DATA12_CNTL | [qcqmux8930.sys](./qcqmux8930.md#smd-channels) |
| SSM_RTR | qcssm8930.sys |
| DIAG | qcipcrouter8930.sys |
| DIAG_2 | qcdiagcsi8930.sys |
| DIAG_CNTL | qcipcrouter8930.sys |
| sys_mon | qcadsp8930.sys |
| DATA5_CNTL | [qcqmux8930.sys](./qcqmux8930.md#smd-channels) |
| DATA13_CNTL | [qcqmux8930.sys](./qcqmux8930.md#smd-channels) |
| DIAG | [qcdiagrouter8930.sys](./qcdiagrouter8930.md) |
| DIAG_CNTL | [qcdiagrouter8930.sys](./qcdiagrouter8930.md) |
| DATA14_CNTL | [qcqmux8930.sys](./qcqmux8930.md#smd-channels) |
| APPS_RIVA_DATA | [qcdiagrouter8930.sys](./qcdiagrouter8930.md) |
| APPS_RIVA_CTRL | [qcdiagrouter8930.sys](./qcdiagrouter8930.md) |
| apr_audio_svc | qcq6ad8930.sys |
| apr_apps2 | qcq6ad8930.sys |
| APPS_FM | [qcfmtransport8930.sys](./qcfmtransport8930.md) |
| APPS_RIVA_BT_CMD | [qcbluetooth8930.sys](./qcbluetooth8930.md) |
| APPS_RIVA_BT_ACL | [qcbluetooth8930.sys](./qcbluetooth8930.md) |
| WLAN_CTRL | qcwlan8930.sys |

Channel events (`SmdPortEventHandler`, 0x403BCC, the `notify` callback given to `smdl_open`). The names are those of the SMD Lite `smdl_event_type` and are tentative:  
| Event | Name | Action |
|-------|------|--------|
| 1 | OPEN ? | Sets the internal "open" event (completes a pending [0x22003](#internal-ioctl-0x22003)) and the client event given at 0x22003 offset `14` |
| 2 | READ ? | Sets the client event given at 0x22003 offset `10` (only when the context field +0xD0, written by the read handler, is 0), queues the read work item |
| 3 | WRITE ? | Queues the write work item (room available in the transmit FIFO) |
| 4 | CLOSE_COMPLETE ? | Sets the internal "closed" event (completes a pending [0x22007](#internal-ioctl-0x22007)) |
| 5 | DSR ? | Sets the client event given at [0x2200F](#internal-ioctl-0x2200f) offset `00` |
| 6 | CTS ? | Sets the client event given at [0x2200F](#internal-ioctl-0x2200f) offset `04` |
| 9 | REMOTE_CLOSE ? | Sets the client event given at 0x22003 offset `18` |

### RPE clients

`SetupRPE` (0x401460) initialises the RPE helper library (`RpeInit`: it waits for the Helper interface `{59752ed7-b9d5-4121-818d-c69f1e667015}` of [qcrpen8930.sys](./qcrpen8930.md)), then registers two clients:  
| Client name | Client GUID | Watches | Comment |
|-------------|-------------|---------|---------|
| SMD (MODEM) | `{f9d15453-8335-434c-aa72-fcd925f135f3}` | AMSS `{936dc601-5530-4b82-9d2a-72a488bec7c1}`, states 4 and 5 | "Apps-Modem edge". `RpeClientInit`, initial state 5. Same GUID as the first device interface |
| SMD (RIVA) | `{d30f94e9-9c90-4ed5-ae04-9266277c4721}` | WCN `{93367d0f-35ce-4ec4-8e38-bb33030c58b2}`, states 4 and 5 | "Apps-Riva edge". `RpeClientInitMultiSegment`, initial state 5 |

The memory segment of "SMD (MODEM)" (0x80000000–0x80200000) is the one listed by [qccdi8930.sys](./qccdi8930.md) for crash dumps.  
When the watched subsystem enters state 4 (subsystem down, see [qcrpen8930.sys](./qcrpen8930.md)), `SmdModemStateNotificationCallback` queues `SmdEvtWorkItemModemStateNotification`: the channels shared with that processor are reset (`SmdProcessChannelCleanup` → `SmdProcessRemoteHostEvents`), then SMD publishes its new state with `RpeSendState`.

### SMD Lite API interface

Query-interface `{07631ee5-21bd-455b-bd1f-f41b43f3a9bc}` (`WdfDeviceAddQueryInterface`), `INTERFACE` Size 0x38. It gives direct access to the SMD Lite functions, without the queues of `\Device\SMD`. The internal IOCTLs use the same functions.  
| Offset | Function | Comment |
|--------|----------|---------|
| 0x10 | `InterfaceFunction_00` = `smdl_open(char *name, smd_channel_type edge, ULONG flags, ULONG fsize, notify, cb_data)` | Returns a port handle, NULL on error. `fsize` 0 = 0x2000; otherwise a multiple of 32 between 0x400 and 0x20000. `flags` bit 2 = streaming mode (`SMD_STREAMING_TYPE`), otherwise packet mode (`SMD_PKTXFR_TYPE`). `notify(port, event, cb_data)` receives the [channel events](#smd-channels) |
| 0x14 | `InterfaceFunction_01` = `smdl_close(port)` | Asynchronous: the close completes with event 4 |
| 0x18 | `InterfaceFunction_02` | Read from the receive FIFO (`smdl_read` ?). Not called inside the driver |
| 0x1C | `InterfaceFunction_03` | Read from the receive FIFO, used by the read path (`smdl_readv` ?) |
| 0x20 | `InterfaceFunction_04` | Write to the transmit FIFO (`smdl_write` ?). Not called inside the driver |
| 0x24 | `InterfaceFunction_05` | Write to the transmit FIFO, used by the write path (`smdl_writev` ?) |
| 0x28 | `InterfaceFunction_06` = `smdl_tx_peek(port)` ? | Free space in the transmit FIFO, in bytes |
| 0x2C | `InterfaceFunction_07` = `smdl_rx_peek(port)` ? | Bytes available in the receive FIFO (size of the next packet in packet mode) |
| 0x30 | `InterfaceFunction_08` = `smdl_sig_set(port, sig, value)` | Sets an outgoing RS-232-like signal (0 = DTR/DSR, 1 = RTS/CTS, 2 = CD, 3 = RI; value 0 or 1) and interrupts the remote processor if it changed |
| 0x34 | `InterfaceFunction_09` = `smdl_sig_get(port, sig)` | Returns the signal `sig` (0–3) set by the remote side |

---

### internal IOCTL 0x22003

This IOCTL is processed by Qcsmd8930.sys (`EvtWdfIoQueueIoInternalDeviceControl`, 0x402AF0)  
Sent by [qcbluetooth8930.sys](./qcbluetooth8930.md#internal-ioctl-0x22003), [qcdiagrouter8930.sys](./qcdiagrouter8930.md), [qcqmux8930.sys](./qcqmux8930.md#internal-ioctl-0x22003) and the other SMD clients.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Open a SMD channel | 28 (minimum) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer (kernel address) to the ANSI name of the channel, e.g. `APPS_RIVA_BT_CMD`. Must not be NULL or empty. The first 20 bytes are copied |
| 04-07 | 06 00 00 00 | Edge (`smd_channel_type`), e.g. 6 = APPS↔RIVA |
| 08-0B | 11 00 00 00 | Flags, must be ≤ 0x1F. See below |
| 0C-0F | 00 20 00 00 | FIFO size in bytes (0 = 0x2000) |
| 10-13 | 00 00 00 00 | Optional `PKEVENT`, set when data is received (event 2) |
| 14-17 | 00 00 00 00 | Optional `PKEVENT`, set when the channel is opened (event 1) |
| 18-1B | 00 00 00 00 | Optional `PKEVENT`, set on event 9 (remote close ?) |

Flags:  
| Bit | Comment |
|-----|---------|
| 0x01 | Not used by qcsmd8930.sys (set by qcbluetooth8930.sys) |
| 0x02 | Streaming mode (`smdl_open` flags = 4). Otherwise packet mode |
| 0x04 | Deferred writes: written data is only queued; it's sent to the FIFO by [internal IOCTL 0x2201B](#internal-ioctl-0x2201b). [internal IOCTL 0x22017](#internal-ioctl-0x22017) is then refused |
| 0x08 | Requests use MDL chains (`Irp->MdlAddress`, lengths summed over the chain). Two collections are created to track them |
| 0x10 | Wait until the remote processor has opened the channel: if it's not open yet, the request is pended in the queue +0x6C and completed by event 1. Otherwise the IOCTL completes immediately |

Returns:
- `STATUS_INVALID_PARAMETER` (0xC000000D): InputBuffer missing/too small, NULL or empty name, flags > 0x1F.
- `STATUS_ACCESS_DENIED` (0xC0000022): a channel is already open on this handle, or `LOOPBACK` with an edge ≠ 0.
- `STATUS_IO_DEVICE_ERROR` (0xC0000185): `smdl_open` failed (bad edge, bad FIFO size, no room in the channel table…).

---

### internal IOCTL 0x22007

This IOCTL is processed by Qcsmd8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Close the SMD channel of the handle | 0 | 0 |

Calls `smdl_close`. If the close hasn't completed yet (event 4), the request is pended in the queue +0x70 until it does.  
Returns `STATUS_INVALID_DEVICE_STATE` (0xC0000184) when no channel is open on the handle, `STATUS_IO_DEVICE_ERROR` when `smdl_close` fails.

---

### internal IOCTL 0x2200B

This IOCTL is processed by Qcsmd8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the write watermarks | 16 (minimum) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Low watermark in bytes. Must not be 0 |
| 04-07 | ? | High watermark in bytes. Must be > low watermark and ≤ the FIFO size given at [0x22003](#internal-ioctl-0x22003) |
| 08-0B | ? | Optional `PKEVENT`, set when the number of queued write bytes drops to the low watermark |
| 0C-0F | ? | Optional `PKEVENT`, set when the number of queued write bytes reaches the high watermark |

Only used in deferred-write mode (flag 0x04 of 0x22003): `EvtWdfIoQueueIoWrite` counts the queued bytes (context +0x4C) and the write handler decrements it. A NULL event keeps the previous one.  
Returns `STATUS_INVALID_PARAMETER` when the watermarks are invalid.

---

### internal IOCTL 0x2200F

This IOCTL is processed by Qcsmd8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the signal events | 8 (minimum) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT`, set on channel event 5 (DSR change ?). Must not be NULL |
| 04-07 | ? | `PKEVENT`, set on channel event 6 (CTS change ?). Must not be NULL |

Returns `STATUS_INVALID_PARAMETER` if a pointer is NULL (the other one is still stored).

---

### internal IOCTL 0x22013

This IOCTL is processed by Qcsmd8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read status | 0 | 0 or n |

The request is put in the read queue (+0x64) and the read work item is queued, so it's processed in order with the read requests (`EvtWdfIoQueueIoControlStatus`, 0x40388C).  
With an OutputBuffer of 0 bytes, it completes with `Information` = number of bytes available in the receive FIFO (`smdl_rx_peek`). With an OutputBuffer, the code paths end in `STATUS_NOT_IMPLEMENTED` (0xC0000002) or `STATUS_IO_DEVICE_ERROR` (?).

---

### internal IOCTL 0x22017

This IOCTL is processed by Qcsmd8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x805 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write status | 0 | 0 |

The request is put in the write queue (+0x68) and the write work item is queued, so it's processed after the pending writes. It completes with `Information` = free space in the transmit FIFO (`smdl_tx_peek`).  
Returns `STATUS_NOT_SUPPORTED` (0xC00000BB) in deferred-write mode (flag 0x04 of 0x22003).

---

### internal IOCTL 0x2201B

This IOCTL is processed by Qcsmd8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x806 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Flush the deferred writes | 0 | 0 |

Queues the write work item, which sends the queued write requests to the FIFO, and completes with `STATUS_SUCCESS`.  
Returns `STATUS_INVALID_DEVICE_REQUEST` when the channel was not opened in deferred-write mode (flag 0x04 of 0x22003).

---

### internal IOCTL 0x2201F, 0x22023, 0x22027, 0x2202B

These IOCTLs are processed by Qcsmd8930.sys. They set an outgoing signal of the channel with `smdl_sig_set` (`InterfaceFunction_08`); the remote processor is interrupted if the value changed.

| IOCTL | Function | Signal | Value |
|-------|----------|--------|-------|
| 0x2201F | 0x807 | 0 (DTR/DSR) | 1 |
| 0x22023 | 0x808 | 1 (RTS/CTS) | 1 |
| 0x22027 | 0x809 | 0 (DTR/DSR) | 0 |
| 0x2202B | 0x80A | 1 (RTS/CTS) | 0 |

Device 0x2, FILE_ANY_ACCESS, METHOD_NEITHER. No buffers. Returns `STATUS_IO_DEVICE_ERROR` if `smdl_sig_set` fails.

---

### internal IOCTL 0x2202F, 0x22033

These IOCTLs are processed by Qcsmd8930.sys. They read a signal set by the remote processor with `smdl_sig_get` (`InterfaceFunction_09`). The value (0 or 1) is returned in `Information`, there's no OutputBuffer.

| IOCTL | Function | Signal |
|-------|----------|--------|
| 0x2202F | 0x80B | 0 (DTR/DSR) |
| 0x22033 | 0x80C | 1 (RTS/CTS) |

Device 0x2, FILE_ANY_ACCESS, METHOD_NEITHER.

---

### internal IOCTL 0x22053, 0x22057

Function 0x814 and 0x815. They are recognised (traced) but always return `STATUS_NOT_SUPPORTED` (0xC00000BB). Probably the CD and RI signals.  
Any other code returns `STATUS_NOT_SUPPORTED` too.

---

### internal IOCTL 0x42000

This IOCTL is sent by Qcsmd8930.sys to [qcsmem8930.sys](./qcsmem8930.md) (`call_device_SMEM`, 0x409C54), once in `smd_init`.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get the SMEM function table | \Device\SMEM | 0 | 52 |

The 13 function pointers are stored in the driver (`smem_version_set`, `smem_set_lock0`, …). `BytesReturned` ≠ 52 → `STATUS_IO_DEVICE_ERROR`, and `smd_init` fails.

### internal IOCTL 0x42004

This IOCTL is sent by Qcsmd8930.sys to [qcsmem8930.sys](./qcsmem8930.md) (`sub_409DA4`), once per `INTR` entry.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Translate a physical address | \Device\SMEM | 8 | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Physical address of the outgoing interrupt register (argument 5+4i of `INTR`) |
| 04-07 | 00 00 00 00 | |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | |
| 04-07 | ? | Virtual address. 0 = not found, the `INTR` configuration is rejected |

### IOCTL 0x32000

This IOCTL is sent by Qcsmd8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x32000) (`SmdInitializeSmsmCommunication`), once at start.

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| smsm_change_state | \Device\SMSM | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | smsm_state_item: SMSM_APPS_STATE |
| 04-07 | 00 00 00 00 | clear_mask |
| 08-0B | 00 00 80 00 | set_mask: 0x00800000 (SMSM_SMD_LOOPBACK) |

### IOCTL 0x32C004

This IOCTL (`IOCTL_ACPI_EVAL_METHOD`) is sent by Qcsmd8930.sys to its own ACPI node (`SmdLoadInterruptConfiguration`, 0x405E98).

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | default I/O target | 8 | 20, then the size returned |

Inputbuffer (ACPI_EVAL_INPUT_BUFFER):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `AeiB` |
| 04-07 | 49 4E 54 52 | Method name `INTR` |

It's first sent with a 20-byte OutputBuffer. On `STATUS_BUFFER_OVERFLOW` the required length is read from the output header, a buffer of that size is allocated (pool tag `bdsq`) and the IOCTL is sent again. See the [format of the package](#initialisation).

### IOCTL 0x8C1F2004

This IOCTL is sent by Qcsmd8930.sys to [qcchipinfo8930.sys](./qcchipinfo8930.md#ioctl-0x8c1f2004) (`qcchipinfo8930_interface_changed`). Same use as in [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x8c1f2004).

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get chip version | qcchipinfo8930.sys interface | 0 | 4 |

Returns the chip version as `major << 16 | minor`. The workaround is applied when the value is lower than 0x20000 (version < 2.0).

### IOCTL 0x8C1F2008

This IOCTL is sent by Qcsmd8930.sys to [qcchipinfo8930.sys](./qcchipinfo8930.md#ioctl-0x8c1f2008) (`qcchipinfo8930_interface_changed`). Same use as in [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x8c1f2008).

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get chip id | qcchipinfo8930.sys interface | 0 | 4 |

Returns the chip id, see [qcchipinfo8930.sys](./qcchipinfo8930.md#chip-ids). The workaround is applied when the value is 87 (0x57, MSM8960). The MSM8227 of the Lumia 520 should return 121 (0x79) ?

---

### Interface GUID

Device interface (also the RPE client GUID of "SMD (MODEM)"), opened by [qcdiagrouter8930.sys](./qcdiagrouter8930.md)  
`{f9d15453-8335-434c-aa72-fcd925f135f3}`

SMD Lite API interface (device interface + query-interface)  
`{07631ee5-21bd-455b-bd1f-f41b43f3a9bc}`

### Other GUID

RPE client "SMD (RIVA)"  
`{d30f94e9-9c90-4ed5-ae04-9266277c4721}`

Watched RPE clients: AMSS `{936dc601-5530-4b82-9d2a-72a488bec7c1}`, WCN `{93367d0f-35ce-4ec4-8e38-bb33030c58b2}`
