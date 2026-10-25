## Qccamgemini8930.sys

Camera JPEG Encoder Driver ("GeminiKMD").  
It's the driver of the Gemini hardware JPEG encoder of the MSM8960/MSM8930 camera subsystem. It's a KMDF driver of the Nokia camera stack (same build as [qccamavs8930.sys](./qccamavs8930.md) and [qccamflash8930.sys](./qccamflash8930.md)) built around the Qualcomm Gemini DAL (`core\src\gemini_dal.c`, `gemini_device.c`, `scqueue.c`, `ea\src\gemini_platform.c`, `ea_8960\src\gemini_mmpm.c`).  
It's opened from user mode through a symbolic link: the client gives the encoder its configuration (input/output format, quantization and Huffman tables, rotation), its YCbCr input and JPEG output buffers (user-mode memory, locked and mapped into the SMMU with qcvcm8930.sys), and two events signalled by the interrupt DPC ("JpegDone", "InputReadDone").  
The client isn't identified (user-mode camera pipeline ?).  
PDB path: `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\Driver\fre\qccamgemini8930.pdb`.

There's no named device object.  
Symbolic link : `\??\QcCamGeminiDriver`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qccamgemini` ?  

The driver doesn't use its `Parameters` key. The value is read in `DriverEntry` (`sub_4051B8`) with `ZwOpenKey` + `ZwQueryValueKey` from an absolute path (raw data copied to `dword_40AB28`):  
| Registry key | Registry value | value | comment |
|--------------|----------------|-------|---------|
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | TraceEnable | 0 / 1 | 1 = register the ETW provider and send the log strings to ETW. Same value as [qccamavs8930.sys](./qccamavs8930.md) and [qccamflash8930.sys](./qccamflash8930.md) |

The `DbgPrintEx` output of the log function (`sub_4052F4`) is enabled by `dword_40AB2C`, which is never written: when `TraceEnable` ≠ 1 the log strings are dropped. Nothing is logged at DISPATCH_LEVEL.

GUID of the ETW provider (manifest based, only registered when `TraceEnable` = 1, shared with the other camera drivers):  
`{62774a98-5c63-43e1-8b13-3c5e8958e414}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| — | qcvcm8930.sys | SMMU, by direct imports (`VcmCreate`, `VcmAssoc`, `VcmActivate`, `VcmReserve`, `VcmMapMdlToPhysmem`, `VcmBack`, `VcmGetDevAddr`, `VcmUnback`, `VcmUnMapMdlFromPhysmem`, `VcmUnreserve`, `VcmDeactivate`, `VcmDeassoc`, `VcmFree`) |

### Driver initialisation

| Callback | Function | Comment |
|----------|----------|---------|
| `EvtDriverDeviceAdd` | 0x40C480 → sub_40C008 | Device context `DEVICE_CONTEXT`, request context `REQUEST_CONTEXT`, file object config (only `EvtFileCleanup`), `EvtIoInCallerContext` (sub_4019AC), `WdfDeviceCreateDeviceInterface` `{eb07bf78-c156-44cc-a97f-b73dd1d61537}`, default queue (sub_40C4B0), symbolic link, interrupt (sub_401070) |
| `EvtDevicePrepareHardware` | sub_40C294 | Maps the first resource if it's a memory resource (`MmMapIoSpace` → `dword_40AB58`, never used), PoFx registration (sub_401504), creates the VCM (sub_4012E8) |
| `EvtDeviceReleaseHardware` | sub_40C384 | `PoFxUnregisterDevice`, releases the VCM (sub_401404) |
| `EvtDeviceSelfManagedIoInit` / `Restart` | sub_401008 | Starts the default queue |
| `EvtDeviceSelfManagedIoSuspend` | sub_40C22C | Stops the default queue |
| `EvtFileCleanup` | sub_40C414 | Same as [IOCTL 0x23200F](#ioctl-0x23200f--ioctl_kmd_gemini_device_close) |
| `EvtInterruptIsr` | sub_40118C | Only queues the DPC: the interrupt isn't acknowledged in the ISR |
| `EvtInterruptDpc` | sub_4011AC | Gemini interrupt handler of the DAL (sub_403F24), see [Interrupt](#interrupt) |

Default queue: sequential, power managed (default), only `EvtIoDeviceControl` (0x401CB8), queue context `QUEUE_CONTEXT` with `EvtCleanupCallback` sub_4019A0 (same as the close IOCTL).

`EvtIoInCallerContext` (sub_4019AC): for `IRP_MJ_DEVICE_CONTROL` requests with METHOD_NEITHER, the input buffer is probed and locked for read and the output buffer for write (`WdfRequestProbeAndLockUserBufferForRead/Write`), the `WDFMEMORY` handles are kept in the request context, then the request is put in the queue (`WdfDeviceEnqueueRequest`). The structures pointed to by these buffers aren't probed (see the commands).

### SMMU (VCM)

The VCM is created in `EvtDevicePrepareHardware` (sub_4012E8):
1. `VcmCreate(0x4000, 0x80000000)`.
2. `VcmAssoc(vcm, ctx, 4)` then `VcmActivate` for the SMMU contexts 11 and 12 (JPEG read and write ports ?).

Each user buffer given to the driver (input YCbCr buffer, JPEG output buffer) is:
1. Locked: `IoAllocateMdl` from the start of the page, length rounded to `KeGetRecommendedSharedDataAlignment`, `MmProbeAndLockPages` (sub_402358).
2. Mapped: `VcmReserve(vcm, MDL.ByteCount, 0x3E0)`, `VcmMapMdlToPhysmem`, `VcmBack`, `VcmGetDevAddr` (sub_40221C).
3. The user address in the command is replaced by the device address + the offset in the page, then the command is sent to the hardware.

Only one input buffer and one output buffer are mapped at a time (queue context). They are unmapped and unlocked by the close IOCTL, the file cleanup and the queue cleanup (sub_401B8C), not when a new buffer is enqueued.

### Hardware

The Gemini registers are mapped by `gemini_device_open` (sub_404DF4): `MmMapIoSpace(0x04600000, 4)` → `dword_40AB20` (only 4 bytes are requested but the registers up to 0x12C are used: it works because a whole page is mapped). The address is hardcoded: the memory resource of the device isn't used.

| Offset | Usage |
|--------|-------|
| 0x00 | Hardware version (bits 0-19: major, minor, step) |
| 0x04 | Reset (0xCFFF) |
| 0x08 | Core configuration (written at encode start) |
| 0x0C | Realtime start / stop ? |
| 0x14 | Interrupt mask |
| 0x18 | Interrupt clear |
| 0x1C | Interrupt status |
| 0x24 | Written 1 at stop |
| 0x28 | Bit 1 polled after frame done |
| 0x34 | Encoded size ? (bits 0-27, returned at frame done) |
| 0x38, 0x3C, 0x40 | Fetch engine configuration: byte ordering / burst / CbCr order, frame size in MCUs, format |
| 0x80-0x94 | Fetch engine buffers: MCU rows, Y address, CbCr address (0x84/0x8C, ping-pong 0x84-0x90), command 0x94 (1 = load, 3 = start) |
| 0x98 | Write engine configuration |
| 0xD8, 0xDC | Output ping / pong address |
| 0xF0 | Write engine enable |
| 0xF4 | Restart interval ? (bits 0-15), bit 16 Huffman table write |
| 0xF8-0x10C | Status words returned at frame done |
| 0x124-0x12C | Table access (0x124 = 0 at end, 0x128 address/index, 0x12C data): quantization tables (type 5) and Huffman tables (type 6) |

### Power management

The driver registers itself to PoFx (`PoFxRegisterDevice`, sub_401504), with exactly the same values as [qccamflash8930.sys](./qccamflash8930.md#power-management): 1 component, GUID `{ffffffff-ffff-ffff-ffff-ffffffffffff}` (`dword_40AB40`, never written), 2 F-states (F0: latency 0, residency 0, power 500; F1: latency 2, residency 5, power 50). The callbacks (sub_401704 … sub_401820) only log and complete the notifications.

The "mmpm" layer of the DAL is replaced by PoFx: `GeminiDeviceActivate` (sub_404F24) calls `PoFxActivateComponent(0, PO_FX_FLAG_BLOCKING)` at device open, at encode start and when the clock frequency is set (only once, flag `byte_40AB24`), and `GeminiDeviceDeactivate` (sub_404F8C) calls `PoFxIdleComponent(0, PO_FX_FLAG_ASYNC_ONLY)` at device close. No clock is set by the driver: the frequency (default 266666666 Hz) is only stored.

### Interrupt

The interrupt comes from the ACPI resources (`WdfInterruptCreate`, sub_401070). The DPC reads the status (0x1C) and writes it back to 0x18:  
| Bit | Interrupt | Action |
|-----|-----------|--------|
| 0 | Frame done | Callback event 0, with the encode result (0x34, 0xF8-0x10C, output address) |
| 1 | FE read done | Callback event 1, next input buffer of the fetch engine queue |
| 2 | FE realtime overflow | Callback event 3 |
| 3 | FE VFE overflow | Callback event 4 |
| 4 | WE Y ping-pong | Next output buffer of the write engine queue |
| 6 | WE Y buffer overflow | Callback event 5 |
| 7 | WE CbCr buffer overflow | Callback event 6 |
| 10 | Reset ack | |
| 11 | Bus error | Callback event 7 |
| 12 | Violation | Callback event 8 |

The callback of the driver (sub_401218):
- Event 0 "encode done": status = 0, JPEG size = word 1 of the result, sets the JpegDone event then dereferences it, and dereferences the InputReadDone event: **the events must be registered again before each frame** ([IOCTL 0x232007](#ioctl-0x232007--set-events)).
- Event 1: sets the InputReadDone event.
- Other events (errors): only logged ("Received unknown event uidEvent = %d"). The client isn't told about the errors.

---

### IOCTL 0x232007 — set events

This IOCTL is processed by Qccamgemini8930.sys (`EvtWdfIoQueueIoDeviceControl`, 0x401CB8)

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle of the "JpegDone" event, mandatory |
| 04-07 | ? | Handle of the "InputReadDone" event, optional (0) |

The handles are referenced with `ObReferenceObjectByHandle(EVENT_MODIFY_STATE, ExEventObjectType, UserMode)`; a previously registered event is dereferenced first.  
Returns `STATUS_INVALID_PARAMETER` (0xC000000D) when there's no input buffer or the first handle is 0. The size of the input buffer isn't checked.

---

### IOCTL 0x23200B — IOCTL_KMD_GEMINI_DEVICE_OPEN

This IOCTL is processed by Qccamgemini8930.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_KMD_GEMINI_DEVICE_OPEN | 0 | 0 |

`gemini_device_open` (sub_404178): allocates the device object (16 bytes, tag `qcc\x03`: control function sub_4042F4, close sub_4044AC, register callback sub_404534) and the Gemini context (512 bytes, tag `qcc\x04`, frame rate 15), creates the fetch engine (12 entries) and write engine (8 entries) queues, maps the registers, activates the PoFx component, then registers the callback of the driver.  
Returns `STATUS_UNSUCCESSFUL` (0xC0000001) on error.

> [!NOTE]
> Opening twice leaks the first device object: the pointer in the device context is overwritten.

---

### IOCTL 0x23200F — IOCTL_KMD_GEMINI_DEVICE_CLOSE

This IOCTL is processed by Qccamgemini8930.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_KMD_GEMINI_DEVICE_CLOSE | 0 | 0 |

`CameraKMDGeminiQueueCleanup` (sub_401B8C): dereferences the events, unmaps the input and output buffers from the SMMU and unlocks them, then closes the device (PoFx idle, registers unmapped, queues and context freed).  
Returns `STATUS_UNSUCCESSFUL` when the device isn't open.

---

### IOCTL 0x232013 — get result

This IOCTL is processed by Qccamgemini8930.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | 12 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Status. Only ever written 0 (frame done) |
| 04-07 | ? | User address of the output buffer (from [command 12](#command-12-jpeg-output-buffer-enqueue)) |
| 08-0B | ? | JPEG size ? (register 0x34 at frame done) |

The output buffer is flushed (`KeFlushIoBuffers`, read) before the result is returned. Returns `STATUS_INVALID_PARAMETER` when there's no output buffer; its size isn't checked.

---

### IOCTL 0x2323FF…0x232437 — Gemini commands

These IOCTLs are processed by Qccamgemini8930.sys. Every IOCTL other than the 4 above is decoded as a command of the Gemini DAL: `n = Function - 0x8FF`, IOCTL = `((0x8FF + n) << 2) | 0x230003`. The device type and the access aren't checked.

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x8FF + n |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Gemini command `n` | depends on `n` | 0 |

The input buffer is passed as is to the control function of the DAL (`sub_4042F4(device, n, input, length, NULL, 0, 0)`); its length isn't checked. The DAL result (0 = success, 13 = bad state, 14 = invalid parameter, 17 = invalid format, 20 = not supported, 29 = bad pointer, 32 = busy) becomes `STATUS_SUCCESS` or `STATUS_UNSUCCESSFUL`.

> [!NOTE]
> When the device isn't open (no [IOCTL_KMD_GEMINI_DEVICE_OPEN](#ioctl-0x23200b--ioctl_kmd_gemini_device_open)), these requests are completed with `STATUS_SUCCESS` and nothing is done.

Several commands contain pointers (byte 04) to other structures. These are user-mode addresses that are read and written by the driver without probe or exception handler.

| n | IOCTL | Function | Input | Comment |
|---|-------|----------|-------|---------|
| 0 | 0x2323FF | Get hardware version | — | **Always fails** through the IOCTL: the DAL needs an output pointer and the driver passes NULL (result 29) |
| 1 | 0x232403 | Reset | — | Clears and masks the interrupts, writes 0xCFFF to the reset register, waits for the reset ack and resets the fetch / write engine queues |
| 2 | 0x232407 | Stop ? | 4 | ULONG. Operation mode 1: 0 → register 0x0C = 3, 1 → register 0x0C = 0. Other modes: only 0. Then register 0x24 = 1, state = idle |
| 3 | 0x23240B | Encode ("GEMINI_CMD_ID_ENCODE") | 8 | Byte 0: numberOfFramesToEncode, byte 1 and bytes 04-07: ? (frame skip pattern ?). Result 32 when busy. Starts the core (register 0x08), activates PoFx, then mode 1: register 0x0C = 1, else fetch engine start (0x94 = 3) |
| 4 | 0x23240F | Continue ("GEMINI_CMD_ID_CONTINUE") | 8 | Same input as [command 10](#command-10-input-buffer-enqueue). The Y address must be the one of the last enqueued input buffer: it's replaced by its device address. Then the fetch engine is loaded with the buffer and started |
| 5 | 0x232413 | Operation configuration | 8 | 00-03 useMode (0 or 1), 04-07 rotation (0-3 = 0°/90°/180°/270° ?). Rotation needs mode 0 (result 20) |
| 6 | 0x232417 | Input configuration | 16 | See [command 6](#command-6-input-configuration) |
| 7 | 0x23241B | Output configuration | 2 | 00 we_burst_length (1 or 2), 01 byte ordering (0-7) |
| 8 | 0x23241F | Encode configuration | 64 | See [command 8](#command-8-encode-configuration) |
| 9 | 0x232423 | Input IMEM configuration | 24 | 00-03 pingY, 04-07 pongY, 08-0B pingCbcr, 0C-0F pongCbcr (multiples of 8), 10-13 ?, 14 ?. Written to 0x84-0x90 |
| 10 | 0x232427 | Input buffer enqueue | 8 | See [command 10](#command-10-input-buffer-enqueue) |
| 11 | 0x23242B | Output buffer configuration | 8 | 00 number of buffers (must be 1), 04-07 pointer to an output buffer (same layout as command 12, length ≤ 0x77FFC40). A buffer ≤ 0x7FFFC0 bytes is queued twice (ping and pong). Then register 0xF0 = 1. The addresses aren't mapped by the driver |
| 12 | 0x23242F | JPEG output buffer enqueue | 8 | See [command 12](#command-12-jpeg-output-buffer-enqueue) |
| 13 | 0x232433 | Set frame rate | 4 | ULONG 1-30 (default 15) |
| 14 | 0x232437 | Set clock frequency | 4 | ULONG in Hz, 1-266666666 (default 266666666). Only stored, see [Power management](#power-management) |
| other | | | | Result 20 |

#### Command 6 Input configuration

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | inputFormat: 0, 1 or 2 (4:2:0 / 4:2:2 ?) |
| 04 | 00 | input_cbcr_order (0 or 1) |
| 05 | 01 | fe_burst_length (1 or 2) |
| 06 | 00 | byte_ordering (0-7) |
| 08-0B | ? | frame_height_mcus |
| 0C-0F | ? | frame_width_mcus |

Size limits in MCUs: format 0 width ≤ 512 and height ≤ 1024, format 1 both ≤ 512, format 2 width ≤ 1024 and height ≤ 512. The state must be idle (result 13).

#### Command 8 Encode configuration

Inputbuffer (sub_402B28):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Written to register 0xF4 bits 0-15 (restart interval ?) |
| 04 | 00 / 01 | 1 = custom Huffman tables |
| 08-17 | ? | 4 pointers to the Huffman tables (all mandatory when byte 04 = 1) |
| 18-1B | ? | Pointer to the luma quantization table (64 bytes) |
| 1C-1F | ? | Pointer to the chroma quantization table (64 bytes) |
| 20 | 00 / 01 | 1 = file size control |
| 24-2F | ? | File size control: region size (mandatory) and 2 more parameters |
| 38-3F | ? | When not 0, the tables are scaled by a quality factor (1-98, "nQfDefault") instead of being written as is |

#### Command 10 Input buffer enqueue

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Number of buffers (the DAL accepts up to 16 in its queue, the driver only maps the first one) |
| 04-07 | ? | Pointer to an array of input buffers |

Input buffer (24 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ? |
| 04-07 | ? | yBufferAddr: user address, multiple of 8. Replaced by the device address |
| 08-0B | ? | cbcrBufferAddr: user address, multiple of 8, after the luma. Replaced by the device address |
| 0C-0F | ? | numberOfMCURows (not 0) |
| 10-13 | ? | Luma length |
| 14-17 | ? | Chroma length |

The luma and chroma planes must be in a single allocation: the gap between the end of the luma and the start of the chroma must be ≤ 16 bytes. The range from yBufferAddr to cbcrBufferAddr + chroma length is locked and mapped as one buffer.

#### Command 12 JPEG output buffer enqueue

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Number of buffers |
| 04-07 | ? | Pointer to an output buffer |

Output buffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | bufferAddr: user address, multiple of 8. Replaced by the device address |
| 04-07 | ? | Written by the driver: device address |
| 08-0B | ? | bufferLength |

The buffer is locked and mapped into the SMMU, then flushed in both directions before the command is sent.

---

### Interface GUID

Gemini interface (not used to open the device ?)  
`{eb07bf78-c156-44cc-a97f-b73dd1d61537}`
