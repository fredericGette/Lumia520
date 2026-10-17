## Qcbamdmux8930.sys

BAM Data Multiplexer driver (BAM DMUX).  
It multiplexes up to 32 logical data channels per "stream" over pairs of BAM (Bus Access Manager) pipes of the A2 data mover, which carries the packet data between the application processor and the MODEM. It is the Windows Phone counterpart of the Linux `bam_dmux` driver (see [bam_dmux.c](https://github.com/android/kernel_msm/blob/android-msm-2.6.35/arch/arm/mach-msm/bam_dmux.c)): same 8-byte packet header (magic `0x33FC`), same OPEN/CLOSE/DATA commands, same `SMSM_A2_POWER_CONTROL` handshake with the MODEM through [qcsmsm8930.sys](./qcsmsm8930.md).  
The BAM itself is driven by [qckmbam8930.sys](./qckmbam8930.md) (interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}`), which gives this driver a transfer function. Clients (kernel drivers only) open `\Device\DMUX`, bind their file object to a channel with [internal IOCTL 0x82003](#internal-ioctl-0x82003), then use plain write requests / [internal IOCTL 0x82007](#internal-ioctl-0x82007) or read requests, or the direct-call [query-interface](#bam-dmux-interface).  
The driver is an RPE client of [qcrpen8930.sys](./qcrpen8930.md) ("BAMMUX"): the channels are torn down when the MODEM goes down and the pipes are reconnected when it comes back, see [Subsystem restart](#subsystem-restart).  
Built from `P:\bam_dmux\rel\8.3\arm\Release\qcbamdmux8930.pdb`.

Device name : `\Device\DMUX`  
There's no symbolic link: the device is only used by other kernel drivers.

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters` (`WdfDriverOpenParametersRegistryKey`, `BamMuxRegGetNumBuffers` 0x403D48):  
| Registry value | value | comment |
|----------------|-------|---------|
| NumOfBuffers | 10240 (0x2800) | REG_DWORD. Number of 2048-byte data buffers allocated at start (non-cached memory, 2 buffers per 4 KB page). A missing value or a value < 256 is replaced by 10240, i.e. 20 MB of non-cached memory. The value is also printed with `DbgPrintEx`: "DMUX::%s:%d: Number of buffers = %d" |

GUID of the WPP control provider:  
`{61085ED3-84FB-436B-B828-8A57815E1826}`  
WPP trace message GUIDs: `{D6FBA595-CD9D-ACAF-5DEC-039929920655}`, `{47956689-FD89-AA0C-688F-FDB225CB248B}`, `{BFB7B0E5-33A0-D2E6-7437-DD2C5ECDAAA6}`, `{CEEEE6D1-4BF4-9A62-9668-727390931B0B}`, `{32C69E31-26A8-CAC5-EB32-BD1255304871}`, `{2F5AFC61-DCEC-062E-DB80-C2986CEA6560}`

GUID of the ETW provider of the RPE helper library (`McGenEventRegister` in `RpeInit`, same as in [qcsmd8930.sys](./qcsmd8930.md)):  
`{57E95397-C84E-4F53-9473-56207AAA5938}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}` (`\Device\BAM<n>`) | [qckmbam8930.sys](./qckmbam8930.md) | A2 BAM. [IOCTL 0x42003](#ioctl-0x42003) (BAM physical address), [IOCTL 0x4202B](#ioctl-0x4202b) (transfer function), [IOCTL 0x4200B](#ioctl-0x4200b) (connect pipe), [IOCTL 0x4200F](#ioctl-0x4200f) (disconnect pipe), [IOCTL 0x42007](#ioctl-0x42007) |
| Interface `{1C90923A-DF5C-4761-9FD0-835B80F5281D}` (\Device\SMSM) | [qcsmsm8930.sys](./qcsmsm8930.md) | [IOCTL 0x32000](#ioctl-0x32000) and [IOCTL 0x3200C](#ioctl-0x3200c), for the [A2 power handshake](#a2-power-handshake) |
| Interface `{59752ED7-B9D5-4121-818D-C69F1E667015}` (\Device\RPEN) | [qcrpen8930.sys](./qcrpen8930.md) | RPE notifier, Helper query-interface. See [Subsystem restart](#subsystem-restart) |

Both peer interfaces are found with `IoRegisterPlugPlayNotification` (`BamMuxDriverNotify` 0x40218C, `BamMuxSmsmDriverNotify` 0x402470) and opened with `WdfIoTargetOpen` by symbolic link name. The notifications are unregistered once the targets are open.

### WDF setup

`EvtDriverDeviceAdd` (0x401718, Hex-Rays fails on it):
- `WdfDeviceInitSetExclusive(FALSE)`, IO type `WdfDeviceIoBuffered`.
- Name `\Device\DMUX`.
- File object: `BamMuxEvtDeviceFileCreate` (0x402D68), `BamMuxEvtFileClose` (0x403004), context `BAM_MUX_FILE_CONTEXT`, `WdfFileObjectWdfCannotUseFsContexts`. At create, each file object gets its own manual queue (pending reads), a spin lock and a collection (received packets waiting for a read), and is bound to no channel (stream = channel = −1).
- Device context `BAM_MUX_DEV_CONTEXT`, cleanup callback `BamMuxCleanupDevice` (0x401FF8: disconnects the pipes of every connected stream), execution level passive.
- Default queue, parallel dispatch: `EvtIoRead` = `sub_4054FC` (forwards the request to the file object's manual queue), `EvtIoWrite` = `BamMuxEvtIoWrite` (0x406188), `EvtIoInternalDeviceControl` = `BamMuxEvtIoInternalDeviceControl` (0x403120).
- Two wait locks, two spin locks ("recordLock", "freelistLock"), the buffer pool (`BamMuxRegGetNumBuffers`, `BamMuxBufQueueInit` 0x40389C), the pool of sub-requests, and one RX work item (`BamMuxEvtWorkItemRead` 0x4055E8) per stream.
- Device interface `{EA38864C-56D4-4426-B145-AC2E39C2BB72}`, and the [query-interface](#bam-dmux-interface) with the same GUID.
- `IoRegisterPlugPlayNotification` on the BAM interface, then on the SMSM interface.
- `BamMuxSetupRPE` (0x40434C), see [Subsystem restart](#subsystem-restart).

Pool tags: `qbd0` (driver), `qbd1` (SMSM wait buffer), `qbd3` (BAM callback pointer), `dmab` (pending-request records).

There's no `EvtDeviceSurpriseRemoval` and no `KeBugCheckEx` call outside the `/GS` failure handler.

### Lumia 520 ACPI nodes

From the DSDT. This driver's node is `\_SB.DMUX` (`_HID` `QCOM0F50`, `_UID` 0). It has no `_CRS`, no `_DEP` and no method, and the driver evaluates none.  
The BAM driver behind the `{3E77CCA9-…}` interface, [qckmbam8930.sys](./qckmbam8930.md#acpi), is the function driver of the 3 `QCOM0910` nodes. It evaluates `INFO` (name, execution environment), `PIPE` (pipes it connects itself: pipe, direction, system mode, IRQ mask, descriptor FIFO size, ?, ?) and `SECC` (pipe mask, VMID per execution environment).  
| Node | `_UID` | `INFO` | `_CRS` | Other methods |
|------|--------|--------|--------|---------------|
| `\_SB.BAM0` | 0 | `"BAMDMA"`, 0 | `Memory32Fixed` 0x12244000, 0x2000; interrupt 137 (edge) | `PIPE`: 2 packages `{0, 0, 1, 0x21, 0x100, 0, 0}`, `{1, 1, 1, 0x21, 0x100, 0, 0}` |
| `\_SB.BAM1` | 1 | `"DataBAM"`, 0 | `Memory32Fixed` 0x124C2000, 0x2000; interrupt 241 (edge) | — |
| `\_SB.BAM2` | 2 | `"LPASS_BAM"`, 1 | `Memory32Fixed` 0x28084000, 0x2000; interrupt 66 (edge) | `PIPE`: `{0x18, 0, 1, 0x21, 0x100, 0, 0}`, `{0x19, 1, 1, 0x21, 0x100, 0, 0}`; `SECC`: `{0x00FFFF98, 0}`, `{0xFF000007, 1}`, `{0x60, 2}`, `{0, 0}` |

`DataBAM` at 0x124C2000 is the A2 BAM of the MSM8960 family (`A2_BAM_PHYS_BASE` in Linux `bam_dmux.c`), i.e. the BAM that this driver multiplexes: it's the only instance kept, see [IOCTL 0x42003](#ioctl-0x42003).

### Streams, channels and pipes

The device context contains 5 streams of 404 (0x194) bytes at `+0x54`. Stream `s` uses BAM pipe `2s` for transmit and BAM pipe `2s+1` for receive, and carries 32 channels (12-byte records at stream `+0x14`).  
| Stream offset | Comment |
|---------------|---------|
| +0x00 (byte) | Pipes connected |
| +0x01 (byte) | RX starved: no free buffer when the RX work item ran; the work item is re-queued when a buffer is given back |
| +0x04 | Number of RX transfers submitted (max 16) |
| +0x08 (byte) | TX full flag |
| +0x0C | Number of TX transfers pending (max 32) |
| +0x10 | RX work item |
| +0x14 + 12 × channel | Channel record: `+0` (byte) remote side open, `+1` (byte) re-open after subsystem restart, `+2` (byte) local open pending, `+4` file context of the owner, `+8` pending open request |

A stream is connected on the first open of one of its channels (`sub_404DDC`: [IOCTL 0x4200B](#ioctl-0x4200b) for the TX pipe, then for the RX pipe, then the RX work item is queued). The RX work item keeps up to 16 receive transfers of 2048 bytes queued on the RX pipe.

Each transfer is submitted with the function obtained by [IOCTL 0x4202B](#ioctl-0x4202b):  
`NTSTATUS Transfer(WDFDEVICE Bam, PVOID ClientContext, ULONG Pipe, ULONG PhysicalAddress, USHORT Length, USHORT Flags)` (`sub_402AE8` of [qckmbam8930.sys](./qckmbam8930.md#ioctl-0x4202b)), with ClientContext = the WDFREQUEST SubRequest and Flags = 0x4000 (`SPS_IOVEC_FLAG_EOT` in Linux ?). Only bits 13-15 of Flags go into the BAM descriptor.  
The BAM driver calls back `sub_40215C(Pipe, WDFREQUEST SubRequest, ?, Event, DescAddress, DescSizeFlags, ?)` from its interrupt DPC when the descriptor is processed (Event = 2 because the EOT flag is set; the 3rd and 7th parameters are uninitialized, see [Descriptors and completion](./qckmbam8930.md#descriptors-and-completion)): odd pipe → `BamMuxRxComplete` (0x405918), even pipe → `BamMuxTxComplete` (0x4065D0).

### Packet format

Every packet on a pipe starts with an 8-byte header (`struct bam_mux_hdr` in Linux), followed by the payload. The data buffers are 2048 bytes, header included.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | FC 33 | Magic number 0x33FC |
| 02 | 00 | Reserved |
| 03 | 00 | Command, see below |
| 04 | 00 | Padding length (always 0 when sent by this driver) |
| 05 | e.g. 08 | Channel (0–31) |
| 06-07 | e.g. DC 05 | Payload length (0 for OPEN/CLOSE) |

Commands:  
| Value | Linux name | Sent | Received |
|-------|------------|------|----------|
| 0 | `BAM_MUX_HDR_CMD_DATA` | `BamMuxEvtIoWrite`, `BamMuxWrite` | Delivered to the owner of the channel (callback or read request), dropped if the channel is not open |
| 1 | `BAM_MUX_HDR_CMD_OPEN` | `BamMuxConnectChannel` (0x404FB4), 8-byte packet | The remote side opened the channel: `BamMuxRxOpen` (0x405E5C, work item) marks it open and sends the local OPEN for a pending open request |
| 2 | `BAM_MUX_HDR_CMD_CLOSE` | `BamMuxDisconnectChannel` (0x405110), at file close | The remote side closed the channel |
| 4 | `BAM_MUX_HDR_CMD_OPEN_NO_A2_PC` | — | Same as OPEN. The device context byte `+0x25` records whether the last open was a plain OPEN (A2 power collapse allowed ?) |

> [!NOTE]
> `BamMuxEvtIoWrite` and `BamMuxWrite` accept a payload of up to 2048 bytes, but they copy it after the 8-byte header into a 2048-byte buffer. A payload of 2041–2048 bytes is written up to 8 bytes past the end of the buffer (into the next buffer of the pool).

### A2 power handshake

The pipes can only be used once the MODEM has powered the A2 up. The handshake uses the `SMSM_APPS_STATE` (entry 0) and `SMSM_MODEM_STATE` (entry 1) states of [qcsmsm8930.sys](./qcsmsm8930.md); bit names are the Linux ones:
1. When the SMSM interface arrives, `BamMuxSmsmModify` (0x402690) sets `SMSM_A2_POWER_CONTROL` (0x2) in `SMSM_APPS_STATE` ([IOCTL 0x32000](#ioctl-0x32000)).
2. `BamMuxSmsmWait` (0x402738) sends the asynchronous [IOCTL 0x3200C](#ioctl-0x3200c): wait for `SMSM_A2_POWER_CONTROL` in `SMSM_MODEM_STATE`.
3. On completion (`BamMuxSmsmComplete` 0x402970), the "A2 powered" flag (context `+0x24`) is set and `BamMuxCheckA2` (0x402B20) runs in a work item.
4. `BamMuxCheckA2` (also called when the BAM interface arrives) waits until both targets are open and the A2 is powered, then: sends [IOCTL 0x42007](#ioctl-0x42007) to the BAM driver, sets the "ready" flag (`+0x26`), creates and enables the device interface `{CCCB7664-4951-40C3-8EB1-FDA3964A4479}` (the GUID of the RPE client), and sets `SMSM_A2_POWER_CONTROL_ACK` (0x800) in `SMSM_APPS_STATE`.

The driver never removes its A2 power vote, except at a MODEM restart.

### Subsystem restart

`BamMuxSetupRPE` (0x40434C) initialises the RPE helper library (`RpeInit`: it waits for the Helper interface `{59752ED7-B9D5-4121-818D-C69F1E667015}` of [qcrpen8930.sys](./qcrpen8930.md)) and registers one client:  
| Client name | Client GUID | Watches | Comment |
|-------------|-------------|---------|---------|
| BAMMUX | `{CCCB7664-4951-40C3-8EB1-FDA3964A4479}` | AMSS `{936DC601-5530-4B82-9D2A-72A488BEC7C1}`, states 4 and 5 | `RpeClientInitMultiSegment` without memory segment, version "1", initial state 5. Listed by [qccdi8930.sys](./qccdi8930.md#memory-region-guid) |

`BamMuxSubsystemStateNotificationCallback` (0x404034):
- AMSS state 4 (subsystem down): sets the "restart in progress" flag (`+0x27`), clears the "A2 powered" and "ready" flags, clears `SMSM_A2_POWER_CONTROL` and `SMSM_A2_POWER_CONTROL_ACK` in `SMSM_APPS_STATE`, and queues `BamMuxSSRShutdownWorkitem` (0x40465C): every open channel is marked for re-open, the RX/TX counters are reset and all the pending transfers are completed or recycled.
- AMSS state 5 (subsystem up), only after a state 4: sets `SMSM_A2_POWER_CONTROL` again, sends the A2 wait (steps 1–3 above), and queues `sub_404794`, which polls (re-queues itself) until the A2 is powered, then disconnects and reconnects the pipes of every stream that was connected, and clears the "restart in progress" flag. The channels marked for re-open send their OPEN when the remote side re-opens them.

While the restart is in progress, writes fail with `STATUS_DEVICE_OFF_LINE` (0x80000010) and the RX work item does nothing.

### BAM DMUX interface

Query-interface `{EA38864C-56D4-4426-B145-AC2E39C2BB72}` (`WdfDeviceAddQueryInterface`, same GUID as the device interface), `INTERFACE` Size 0x18, Version 1, Context = the WDFDEVICE, no reference/dereference functions.  
| Offset | Function | Comment |
|--------|----------|---------|
| 0x10 | `sub_403CDC(ULONG Stream, PVOID Buffer)` | Gives a receive buffer back to the pool (zeroed, 2048 bytes), and re-queues the RX work item of the stream if it was starved. For clients using an RX callback, which keep the buffer of a DATA packet (whether `Buffer` is the payload or the header address is ?) |
| 0x14 | `BamMuxWrite(ULONG Stream, ULONG Channel, PVOID Data, ULONG Length)` (0x406738) | Synchronous submission of a DATA packet, no request involved. Errors: `STATUS_DEVICE_OFF_LINE` (subsystem restart), `STATUS_INVALID_DEVICE_STATE` (channel not open by the remote side), `STATUS_INVALID_PARAMETER` (Length > 2048), `STATUS_INSUFFICIENT_RESOURCES` (32 TX pending), `STATUS_NO_MEMORY` (no sub-request), `STATUS_MEMORY_NOT_ALLOCATED` (no buffer) |

The client of this interface and of `\Device\DMUX` is not known (a network/RmNet driver ?).

### Write requests

`BamMuxEvtIoWrite` (0x406188): the file object must be bound to an open channel ([internal IOCTL 0x82003](#internal-ioctl-0x82003) done, and remote side open), otherwise `STATUS_INVALID_DEVICE_STATE`. Length > 2048 → `STATUS_INVALID_PARAMETER`. The data is copied after a DATA header into a pool buffer and submitted on the TX pipe of the stream. The request is completed with the written length when the BAM transfer completes. Same errors as `BamMuxWrite`.

### Read requests

A read request (or [internal IOCTL 0x82007](#internal-ioctl-0x82007)) is put in the manual queue of the file object. A received DATA packet for the channel completes the oldest pending request: the payload is copied into the output buffer (truncated to the buffer size) and `Information` = number of bytes copied. When no request is pending, the packet is kept in the file object's collection until the next read.  
If the client gave an RX callback at open time, the packets are not queued: `Callback(PVOID Payload, USHORT Length, PVOID CallbackContext)` is called from the completion path of the BAM driver.

---

### internal IOCTL 0x82003

This internal IOCTL is processed by Qcbamdmux8930.sys (`BamMuxEvtIoInternalDeviceControl` 0x403120)

| Property | Value |
|----------|-------|
| Device | 0x8 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Open channel | ≥ 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 00 00 00 00 | Stream (0–4) |
| 04-07 | e.g. 08 00 00 00 | Channel (0–31) |
| 08-0B | ? | RX callback (kernel address), or 0 to receive with read requests |
| 0C-0F | ? | Context passed to the RX callback (only used when the callback is not 0) |

Binds the file object to the channel and opens it:
1. Stream > 4 or channel > 31 → `STATUS_INVALID_PARAMETER`.
2. File object already bound, or channel already owned by another file object → `STATUS_INVALID_DEVICE_STATE`.
3. If the pipes of the stream are not connected yet, they are connected (see [Streams, channels and pipes](#streams-channels-and-pipes)); on error the request is completed with that status.
4. If the remote side has already opened the channel, an OPEN packet is sent at once; otherwise the request is kept as "open pending" and the OPEN is sent when the remote OPEN arrives.

The request stays pending until the TX of the OPEN packet completes, then it's completed with `STATUS_SUCCESS`. Closing the file object sends a CLOSE packet and releases the channel.

---

### internal IOCTL 0x82007

This internal IOCTL is processed by Qcbamdmux8930.sys (`BamMuxEvtIoInternalDeviceControl` 0x403120)

| Property | Value |
|----------|-------|
| Device | 0x8 |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read packet | 0 | any (payload is at most 2040 bytes) |

Same as a read request: forwarded to the manual queue of the file object, completed with the payload of the next DATA packet received on the channel, see [Read requests](#read-requests). Any other internal IOCTL code is left uncompleted (no default case).

---

### IOCTL 0x42003

This IOCTL is sent by Qcbamdmux8930.sys to the BAM driver (interface `{3E77CCA9-…}`), synchronously, in `BamMuxDriverNotify`.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get BAM physical address | Interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}` | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 20 4C 12 | Physical base address of the BAM. Must be 0x124C2000 (A2 BAM, `\_SB.BAM1`), otherwise the target is closed and that BAM is not used |

When the value matches, the driver keeps the target and sends [IOCTL 0x4202B](#ioctl-0x4202b). See [qckmbam8930.sys](./qckmbam8930.md#ioctl-0x42003).

---

### IOCTL 0x4202B

This IOCTL is sent by Qcbamdmux8930.sys to the BAM driver, synchronously, in `BamMuxGetBamVtable` (0x403EC4).

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x80A (2058) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get BAM function table | Interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}` | 4 | 12 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Address of the transfer-completion callback `sub_40215C`. Switches the BAM to callback mode, see [qckmbam8930.sys](./qckmbam8930.md#ioctl-0x4202b) |

Outputbuffer (written into the device context at `+0x04`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `WDFDEVICE` of the BAM, first parameter of the transfer function |
| 04-07 | ? | Address of the transfer function, see [Streams, channels and pipes](#streams-channels-and-pipes) |
| 08-0B | ? | Address of the poll function `NTSTATUS Poll(WDFDEVICE Bam, ULONG Pipe)`. Not used |

---

### IOCTL 0x4200B

This IOCTL is sent by Qcbamdmux8930.sys to the BAM driver, synchronously, in `BamMuxConnectPipe` (0x404AC4). Hex-Rays fails on this function.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x802 (2050) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Connect pipe | Interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}` | 52 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 01 00 00 00 | Pipe (2 × stream for TX, 2 × stream + 1 for RX) |
| 04-07 | e.g. 01 00 00 00 | Pipe number programmed in the hardware (same value) |
| 08-0B | 00 or 01 | Direction (`P_CTRL` bit 3): 0 = transmit, 1 = receive |
| 0C-0F | 01 00 00 00 | System mode (`P_CTRL` bit 5) |
| 10-13 | 21 00 00 00 | Pipe IRQ enable mask (`P_IRQ_EN`): `P_PRCSD_DESC_EN` \| `P_TRNSFR_END_EN` |
| 14-17 | ? | Physical address of the descriptor FIFO |
| 18-1B | ? | Virtual address of the descriptor FIFO |
| 1C-1F | 00 01 00 00 | Size of the descriptor FIFO: 256 bytes (32 descriptors of 8 bytes ?) |
| 20-33 | 0 | Not used by the BAM driver |

See [qckmbam8930.sys](./qckmbam8930.md#ioctl-0x4200b). The descriptor FIFO is allocated with `MmAllocateNonCachedMemory(256)` and kept in the device context (`+0x838 + 4 × pipe`). The BAM target must be open, otherwise `STATUS_INVALID_DEVICE_STATE`.

---

### IOCTL 0x4200F

This IOCTL is sent by Qcbamdmux8930.sys to the BAM driver, synchronously, in `sub_404CF4`.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x803 (2051) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Disconnect pipe | Interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}` | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 01 00 00 00 | Pipe |

The descriptor FIFO of the pipe is freed after the call, whatever the result. Sent for both pipes of a stream at device cleanup and before the reconnection after a MODEM restart.

---

### IOCTL 0x42007

This IOCTL is sent by Qcbamdmux8930.sys to the BAM driver, synchronously, in `BamMuxCheckA2`, once the A2 is powered.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Initialize / reset BAM | Interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}` | 0 | 0 |

The first one initializes the BAM hardware, the next ones reset it and reconnect the connected pipes, see [qckmbam8930.sys](./qckmbam8930.md#ioctl-0x42007). The BAM driver always completes it with `STATUS_SUCCESS`.  
On error, the driver stays "not ready": no device interface `{CCCB7664-…}` and no `SMSM_A2_POWER_CONTROL_ACK`.

---

### IOCTL 0x32000

This IOCTL is sent by Qcbamdmux8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x32000), synchronously.

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| smsm_change_state | Interface `{1C90923A-DF5C-4761-9FD0-835B80F5281D}` | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | `SMSM_APPS_STATE` |
| 04-07 | 00 00 00 00 | clear_mask |
| 08-0B | 02 00 00 00 | set_mask |

Values sent:  
| clear_mask | set_mask | When |
|------------|----------|------|
| 0 | 0x2 `SMSM_A2_POWER_CONTROL` | SMSM interface arrival, MODEM up after a restart |
| 0 | 0x800 `SMSM_A2_POWER_CONTROL_ACK` | `BamMuxCheckA2`, driver ready |
| 0x2 | 0 | MODEM down |
| 0x800 | 0 | MODEM down |

---

### IOCTL 0x3200C

This IOCTL is sent by Qcbamdmux8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x3200c), asynchronously (`WdfRequestSend` with the completion routine `BamMuxSmsmComplete`), in `BamMuxSmsmWait`.

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x803 (2051) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a state | Interface `{1C90923A-DF5C-4761-9FD0-835B80F5281D}` | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | `SMSM_MODEM_STATE` |
| 04-07 | 02 00 00 00 | state_mask `SMSM_A2_POWER_CONTROL` |
| 08-0B | 02 00 00 00 | expected_state `SMSM_A2_POWER_CONTROL` |

When the request completes with success and `Information` (the MODEM state) has bit 0x2 set, the A2 is considered powered and `BamMuxCheckA2` is queued.

---

### Interface GUID

BAM DMUX device interface and query-interface  
`{EA38864C-56D4-4426-B145-AC2E39C2BB72}`

BAM DMUX "ready" device interface, enabled by `BamMuxCheckA2` (same GUID as the RPE client)  
`{CCCB7664-4951-40C3-8EB1-FDA3964A4479}`

### Other GUID

Interface of the BAM driver [qckmbam8930.sys](./qckmbam8930.md#interface-guid)  
`{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}`
