## Qcvpe8930.sys

VPE Driver (Video Pre-processing Engine).  
It's the KMDF driver of the VPE block of the MSM8930 multimedia subsystem: a hardware engine that reads a YUV frame from memory, scales / crops / rotates / blends it, and writes it back to memory. On the Lumia 520 its client is the camera AVStream driver [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x900-0x950-0x9a0--vpe) (`VpeSession`), which sends the frames received from the VFE to the VPE (zoom, crop, rotation of the preview / video).  
The driver is built around the Qualcomm "PCD" layer (`PCD_Open`, `PCD_Start`, `PCD_ProcessFrame`, `PCD_FillOutputBuffer`, …) and a hardware layer `HAL_VPE_V1.0`. The buffers are mapped in the SMMU through [qcvcm8930.sys](./qcvcm8930.md) (static imports `VcmCreate`, `VcmAssoc`, `VcmActivate`, `VcmReserve`, `VcmBack`, `VcmMapMdlToPhysmem`, `VcmGetDevAddr`, …).  
Commands are KS-like property requests (a `KSIDENTIFIER` header: set GUID + Id + Flags) sent with 3 normal (not internal) IOCTLs.  
PDB path: `P:\Video\rel\8.2.1.1\arm\Release\qcvpe8930.pdb`.

There's no named device object and no symbolic link: the device is reached through its device interface (see [Interface GUID](#interface-guid)).

ACPI node: `\_SB.VPE`, `_HID` `QCOM0770`, `_UID` 0, `_DEP` on `\_SB.SMMU` and `\_SB.PEP0`.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0770\0` ?  

There's no parameters in the registry.

GUID of the ETW provider (manifest based, registered in `EvtDevicePrepareHardware`, `McGenEventRegister` sub_401CC4):  
`{d68787b2-89b1-4af1-917b-3049ea90e5d5}`  
The driver also contains WPP trace calls (`DoTraceMessage`, `WPP_GLOBAL_Control` at `off_40F7A0`), but WPP is never initialised: `off_40F7A0` points to itself, so these traces are dead code.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{95f66217-6158-4f46-a8c6-dfd0bfcf94f1}` (exposed) | [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x900-0x950-0x9a0--vpe) | Client (`VpeSession`), see [IOCTLs](#ioctl-0x900--vpe-buffer-commands) |
| — | [qcvcm8930.sys](./qcvcm8930.md) | SMMU address space of the VPE buffers, by direct imports. See [SMMU](#smmu-vcm) |
| Power framework (PEP) | [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state) | `PoFxPowerControl`, VPE clock P-state, see [Power management](#power-management) |

### Driver initialisation

| Callback | Function | Comment |
|----------|----------|---------|
| `DriverEntry` | 0x401E70 | Clears the global context (`unk_4100C0`, 0x894 bytes), `WdfDriverCreate` (pool tag `qvp0`) |
| `EvtDriverDeviceAdd` | 0x412008 → sub_41205C | File object callbacks (`EvtDeviceFileCreate` 0x401198, `EvtFileClose` 0x401B24), `WdfDeviceCreateDeviceInterface` `{95f66217-…}`, default queue (sub_412200), 1 interrupt (ISR sub_401D48, DPC sub_401DB4) |
| `EvtDevicePrepareHardware` | 0x401F2C | Registers the ETW provider, maps the first memory resource (`MmMapIoSpace`, non-cached, `dword_4100E8`), PoFx registration (sub_4024B8), creates the VCM (sub_404790), initialises the PCD / HAL layer with the register base (sub_404FD4) |
| `EvtDeviceReleaseHardware` | 0x4020A4 | Closes every client, idles the component, `VcmDeactivate` / `VcmDeassoc` / `VcmFree`, deinitialises the PCD layer, `PoFxUnregisterDevice`, unmaps the registers, unregisters ETW |
| `EvtDeviceSelfManagedIoInit` / `Restart` | 0x402248 | Starts the default queue |
| `EvtDeviceSelfManagedIoSuspend` | 0x4122A4 | Stops the default queue |
| `EvtInterruptIsr` | sub_401D48 | "Received interrupt", sets flags in the HAL context (`dword_41095C`), queues the DPC |
| `EvtInterruptDpc` | sub_401DB4 | Calls the HAL interrupt handling, then completes the frame (event 0x100A to the [message callback](#messages)) |

Default queue: sequential, power managed (default), only `EvtIoDeviceControl` (0x4013BC). The device is not stoppable (`WdfDeviceSetStaticStopRemove(FALSE)`).

Every open of the device (`EvtDeviceFileCreate`) creates a **client** (48 bytes, pool tag `qvpe`), opened in the PCD layer with `PCD_Open` (sub_405080, callback sub_402F10). Up to 512 clients (`dword_4108F0`, "VPEDriver - Max Client Limit" → `STATUS_UNSUCCESSFUL`). The first open activates the PoFx component (`PoFxActivateComponent`), the close of the last client idles it (sub_4022C8). The IOCTLs find their client by the WDF file object of the request; a request on an unknown file object fails with `STATUS_UNSUCCESSFUL`.

Client context:  
| Offset | Comment |
|--------|---------|
| 0x00 | PCD handle (magic 0x75017591 at its offset 0) |
| 0x04 | Status of the last pause |
| 0x08 | 1 = kernel-mode client (byte 0x6C of the [session](#property-4--session-116-bytes)) |
| 0x0C | Message list (`LIST_ENTRY`) |
| 0x14 | Spinlock of the message list |
| 0x18 | `KEVENT` signalled by the PCD event 0x1002 (end of [pause](#ioctl-0x9a0--vpe-stream-commands)) |
| 0x28 | WDF file object |
| 0x2C | Notification event of the client (from the [session](#property-4--session-116-bytes)), set each time a message is queued (sub_402868) |

### Hardware

ACPI resources of `\_SB.VPE`:  
| Resource | Value | Usage |
|----------|-------|-------|
| Memory 0 | 0x05300000, 0x100000 bytes | VPE registers (`dword_4100E8`, size `dword_4100EC`) |
| Interrupt 0 | 0x4F (79) | VPE interrupt |

There's no hardcoded physical address. The HAL init (`sub_40ACB4`, "HAL_VPE_V1.0") clears a set of registers around offsets 0x10108–0x10250, 0x50400–0x504FC and 0xC0004–0xC001C, then writes 0x3E0, 0x360, 0x120, 0x140 at 0xC0010–0xC001C and 0x4000F at 0xC0004 (meaning ?).

### SMMU (VCM)

At `EvtDevicePrepareHardware` (sub_404790): `VcmCreate(0x4000, 0x80000000)`, then `VcmAssoc(vcm, ctx_id, 4)` + `VcmActivate` for the **context IDs 3 and 4** (table at `.rdata:0x0040E1D0`). They are the 2 context banks of the first IOMMU (0x07400000, see [qcsmmu8930.sys](./qcsmmu8930.md#lumia-520-acpi-node)); in the names used by [qcdxkm8930.sys](./qcdxkm8930.md) probably `VCM_VPE_SRC` / `VCM_VPE_DST`.  
Each buffer is an "allocation entry" (36 bytes, pool tag `qvpl`, list at `unk_4100C0` + 0x85C) holding the `VcmReserve` handle (`VcmReserve(vcm, size, 0x3E0)`), the MDL, the device address (`VcmGetDevAddr`) and the size. The **address of this entry is the buffer handle** returned to the client by [Reserve](#command-1-reserve-allocation) and passed back in every other command.

### Power management

The driver registers itself to PoFx (`PoFxRegisterDevice`, sub_4024B8) with the same values as [qccamvfe8930.sys](./qccamvfe8930.md#power-management): 1 component (GUID from `dword_410970`, never written), 2 F-states (F0: latency 0, residency 0, power 500; F1: latency 2, residency 5, power 50), device idle state 1. The idle / active callbacks only log and complete the notifications.

P-state (sub_404D38 → sub_402350 "VPE_PowerControl"): at each [Start](#ioctl-0x9a0--vpe-stream-commands) / [Stop](#ioctl-0x9a0--vpe-stream-commands), the driver computes the load of the session in macroblocks per second: max over the input, output and background buffers of `ceil(width/16) * ceil(height/16) * rate[1] / rate[0]` (PCD properties 2–4 and 5, see [Properties](#ioctl-0x950--vpe-properties)). The load is added (start) or subtracted (stop) to a global load (`dword_410938`) and converted to a level:  
| Load (MB/s) | Level |
|-------------|-------|
| ≤ 36000 (0x8CA0) | 0 |
| ≤ 108000 (0x1A5E0) | 1 |
| ≤ 245760 (0x3BC40) | 2 |
| more | 2 |

The level is sent with `PoFxPowerControl(handle, {3404daac-8e2c-41e4-8458-3158e5ad442b}, {0, level} (8 bytes), output 100 bytes)` (see [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state)). If the first DWORD of the output is 1 (pending), the driver waits up to 50 ms for the `PowerControlCallback` (sub_402634, status 2) ("VPE Error: Change P state time out").

### Messages

The PCD layer reports its events to sub_402F10 (`VPE_PCDCallBackFn`). Except 0x1002, each event is turned into a 56-byte message (pool tag `qvpf`…`qvpj`) queued in the client's list, and the client's notification event is set. The client reads them with [Get message](#command-1-get-message).  
| Event | Message type | Function | Comment |
|-------|--------------|----------|---------|
| 0x1001 | 5 | sub_4029C4 | `VPE_StopDone` |
| 0x1002 | — | — | End of pause: sets the client `KEVENT` (+0x18) |
| 0x1003 / 0x1004 / 0x1005 | 4 | sub_4028B8 | `VPE_FlushDone`, buffer type 1 / 2 / 3 (input / output / background) |
| 0x1006 / 0x1009 | 1 | sub_402A90 | `VPE_InputFrameDone` |
| 0x1007 / 0x100A | 2 | sub_402C3C | `VPE_OutputFrameDone` |
| 0x1008 / 0x100B | 3 | sub_402DE8 | `VPE_BackgroundDone` |

### Debug dump of the frames

sub_404E8C writes the input buffers (in [Process frame](#command-8-process-frame)) and the output buffers (in [Get message](#command-1-get-message)) to `\DosDevices\C:\Users\VPE_Input_%x.YUV` / `\DosDevices\C:\Users\VPE_Output_%x.YUV` when the bits 0 / 1 of `dword_410954` are set. This variable is never written (BSS, 0): the dump is disabled.

---

All the IOCTLs share the same structure: a 24-byte header followed by the parameters.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | GUID | Command set, must match the IOCTL code (memcmp) |
| 10-13 | ? | Command Id |
| 14-17 | 01 00 00 00 / 02 00 00 00 | Flags (`KSPROPERTY_TYPE_GET` = 1 / `KSPROPERTY_TYPE_SET` = 2). Only checked by 0x950 and by command 7 of 0x900 |
| 18-… | ? | Parameters |

Completion: success → `STATUS_SUCCESS` with `Information` = number of bytes returned (0 for the commands without output); any failure (wrong GUID, unknown Id, wrong size, error of the PCD layer) → `STATUS_UNSUCCESSFUL` (0xC0000001).  
**If the input buffer is shorter than 24 bytes, the request is completed with `STATUS_SUCCESS`** without doing anything.  
Most sizes are exact: the buffer must have exactly the size given below.

---

### IOCTL 0x900 — VPE buffer commands

This IOCTL is processed by Qcvpe8930.sys  
It's sent by [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x900-0x950-0x9a0--vpe).

| Property | Value |
|----------|-------|
| Device | 0x0 |
| Function | 0x240 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

Command set (`.rdata:0x0040E190`): `{fcd1c5aa-85b7-45e7-9426-d6c31ee30130}` ("VPE_BUFFER_COMMANDS")

| Id | Name | InputBuffer size | OutputBuffer Size | Function |
|----|------|------------------|-------------------|----------|
| 1 | Reserve allocation | 36 | ≥ 4 | sub_4034F0 case 1 |
| 2 | Map allocation | 44 | 0 | sub_403090 |
| 3 | Unreserve allocation | 36 | 0 | sub_402FF8 |
| 4 | Unmap allocation | 44 | 0 | sub_403160 |
| 6 | Provide output buffer | 56 | 0 | sub_4032E0 |
| 7 | Set / get buffer requirements | 44 | 0 / 44 | sub_403424 / `PCD` |

sub_4034F0 also implements an Id 0 "Allocate buffer" (`MmAllocatePagesForMdlEx` + `VcmReserve` + `VcmBack`, mapped in the **user** address space, "Allocate Buffer can only be called in user mode") and an Id 5 "Free buffer", but the IOCTL dispatcher never calls them (Ids 0 and 5 fail).

#### Command 1 "Reserve allocation"

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | | Header, Id = 1 |
| 18-1B | ? | Size in bytes |
| 1C-23 | ? | ? |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Buffer handle (kernel address of the allocation entry) |

Creates an allocation entry and reserves `size` bytes in the VCM (`VcmReserve(vcm, size, 0x3E0)`). No memory is backed yet.

#### Command 2 "Map allocation" / Command 4 "Unmap allocation"

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | | Header, Id = 2 or 4 |
| 18-23 | ? | ? |
| 24-27 | ? | MDL of the buffer (kernel pointer) |
| 28-2B | ? | Buffer handle |

Map: `VcmMapMdlToPhysmem(mdl)` + `VcmBack(reservation, physmem)`, stores the MDL and the device address (`VcmGetDevAddr`) in the entry. Unmap: the MDL must be the mapped one; `VcmUnback` + `VcmUnMapMdlFromPhysmem`.

> [!NOTE]
> The MDL is a kernel pointer taken from the buffer: these commands are only usable by a kernel-mode client.

#### Command 3 "Unreserve allocation"

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | | Header, Id = 3 |
| 18-1F | ? | ? |
| 20-23 | ? | Buffer handle |

`VcmUnreserve`, then frees the allocation entry.

#### Command 6 "Provide output buffer"

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | | Header, Id = 6 |
| 18-1B | ? | Buffer handle |
| 1C-1F | ? | ? (passed to the PCD) |
| 20-23 | ? | Length used (must be ≤ the reserved size, "Buffer length is wrong") |
| 24-33 | ? | ? |
| 34-37 | ? | ? (passed to the PCD) |

Gives an output buffer to the VPE (`PCD_FillOutputBuffer`, PCD function +0x40, with the device address of the buffer) and marks the entry "in process by HW". It comes back as an "output frame done" [message](#messages).

#### Command 7 "Buffer requirements"

Inputbuffer (flags = 2, set) / Outputbuffer (flags = 1, get):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | | Header, Id = 7 |
| 18-1B | 01 00 00 00 | Buffer type: 1 = input, 2 = output, 3 = background |
| 1C-1F | ? | Requirement 1 ? |
| 20-23 | ? | ? |
| 24-27 | ? | Requirement 2 ? |
| 28-2B | ? | ? |

Set: `PCD_SetBufferRequirements` (PCD function +0x2C). Get: the type is read from the output buffer (the system buffer is shared), the PCD function +0x30 fills the bytes 1C-1F and 24-27, `Information` = 44.

---

### IOCTL 0x950 — VPE properties

This IOCTL is processed by Qcvpe8930.sys  
It's sent by [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x900-0x950-0x9a0--vpe).

| Property | Value |
|----------|-------|
| Device | 0x0 |
| Function | 0x254 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

Property set (`.rdata:0x0040E180`): `{7307682b-adfe-40fa-b37d-be330a37d488}`  
Flags = 2 (set): the input buffer is passed to sub_403918. Flags = 1 (get): the output buffer (same layout, header included) is filled by sub_403CC8 and `Information` = its size. Other flags fail.

| Id | Name | Set: InputBuffer size | Get: OutputBuffer Size | PCD property | Comment |
|----|------|-----------------------|------------------------|--------------|---------|
| 0, 2 | — | any | any | — | Succeed without doing anything |
| 1 | Live mode | 28 | 28 | 1 | Byte at 0x18 |
| 3 | Frame rate | 32 | 32 | 5 (8 bytes) | DWORDs at 0x18 and 0x1C. The [P-state](#power-management) uses rate = DWORD[0x1C] / DWORD[0x18] |
| 4 | Session | 116 | fails | 2, 3, 4, 7, 8, 9 | See below |
| 5 | ? | 28 | 28 | — | Set: succeeds only if DWORD[0x18] = 1, nothing else. Get: returns 1 |
| 6 | Rotation | 28 | 28 | 0xF2 (4 bytes) | DWORD at 0x18 in degrees: 0, 90, 180, 270 → 0, 2, 4, 8 |
| 7 | Crop | 44 | 44 | 0xF1 (20 bytes) | Byte at 0x18 (enable) + 4 DWORDs at 0x1C–0x28 (rectangle ?) |
| 8 | Zoom | 44 | 44 | 0xF3 (20 bytes) | Byte at 0x18 (enable), then 2 fractions: qccamavs8930 sends 1000, zoom × 1000, 1000, zoom × 1000 |
| 9 | ? | 28 | 28 | 0xF4 (1 byte) | Byte at 0x18 |
| 10 | Blend (`VPE_PROPERTY_BLEND`) | 80 | 80 | 0xF5 (64 bytes) | Background buffer handle at 0x30 (set: the entry is marked in use and given to the PCD with `PCD_SetBuffer`, PCD function +0x34). Bytes 0x18–0x1A, DWORDs 0x1C–0x28 and 0x38–0x4C copied to the PCD |
| 11 | ? | 28 | 28 | 0xF6 (4 bytes) | DWORD at 0x18 |
| 12 | ? | 32 | fails | 0xA (8 bytes) | DWORD at 0x18, DWORD at 0x1C ∈ {1, 2, 3} |
| 13 | ? | 32 | fails | 0xB (8 bytes) | DWORD at 0x18, DWORD at 0x1C ∈ {1, 2} |
| 14 | ? | 32 | fails | 0xC (8 bytes) | DWORD at 0x18, DWORD at 0x1C ∈ {0, 1, 2} → 0, 2, 4 |

#### Property 4 "Session" (116 bytes)

Set only (`InitSession` of the client, sub_4037E8).  
Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | | Header, Id = 4, flags = 2 |
| 18-1B | 01 00 00 00 | Input buffer descriptor: type (must be 1, else skipped) |
| 1C-2B | ? | Input buffer size: 4 DWORDs (width, height, ?, ?) → PCD property 2 |
| 2C-2F | 02 00 00 00 | Output buffer descriptor: type (must be 2, else skipped) |
| 30-3F | ? | Output buffer size → PCD property 3 |
| 40-43 | 03 00 00 00 | Background buffer descriptor: type (must be 3, else skipped) |
| 44-53 | ? | Background buffer size → PCD property 4 |
| 54-57 | 01 00 00 00 | Input color format: buffer type (1 / 2 / 3 → PCD property 7 / 8 / 9) |
| 58-5B | ? | Input color format: format 1–9 (→ PCD value 2–10) |
| 5C-63 | ? | Output color format (same layout) |
| 64-6B | ? | Background color format (same layout) |
| 6C | 00 / 01 | 1 = kernel-mode client |
| 6D-6F | ? | ? |
| 70-73 | ? | Notification event: user-mode handle (`ObReferenceObjectByHandle(ExEventObjectType, UserMode)`) if byte 0x6C = 0, `PKEVENT` if byte 0x6C = 1 |

For each descriptor present: set the size, set the color format, then `PCD_GetBufferRequirements` (PCD function +0x30). The event is set each time a [message](#messages) is queued.

---

### IOCTL 0x9A0 — VPE stream commands

This IOCTL is processed by Qcvpe8930.sys  
It's sent by [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x900-0x950-0x9a0--vpe).

| Property | Value |
|----------|-------|
| Device | 0x0 |
| Function | 0x268 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

Command set (`.rdata:0x0040E1A0`): `{c8a7f717-a0fe-4bf4-b44e-0a27e9fa9562}`

| Id | Name | InputBuffer size | OutputBuffer Size | Function | Comment |
|----|------|------------------|-------------------|----------|---------|
| 1 | Get message | ≥ 24 | 48 | sub_404268 | See below |
| 3 | Start | ≥ 24 | 0 | sub_403F84 | Adds the session load to the [P-state](#power-management), `PCD_Start` (PCD function +0x04) |
| 4 | Stop | ≥ 24 | 0 | sub_404334 | Removes the session load, `PCD_Stop` (PCD function +0x18). Completion reported by a type 5 message |
| 5 | Pause | ≥ 24 | 0 | sub_4044D0 | `PCD_Pause` (driver function 4), then **waits without timeout** for the PCD event 0x1002 |
| 6 | Resume | ≥ 24 | 0 | `PCD_Resume` (driver function 5) | Only if the PCD session is in state 5 (paused), else success |
| 7 | Flush | 28 | 0 | sub_40440C | DWORD at 0x18: 1 = input, 2 = output, 3 = background, 4 = all (→ mask 1, 2, 4, 7), `PCD_Flush` (PCD function +0x14) |
| 8 | Process frame | 56 | 0 | sub_404054 | See below |

#### Command 1 "Get message"

Doesn't wait: removes the first message of the client's queue, or fails with `STATUS_UNSUCCESSFUL` when the queue is empty ("VPE_GetextMsg message queue is empty"). The client waits on its notification event first.  
Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Status: 0 = OK, 2 = buffer not found, 3 = invalid event |
| 04-07 | 02 00 00 00 | Type: 1 = input frame done, 2 = output frame done, 3 = background done, 4 = flush done, 5 = stop done |
| 08-0B | ? | Types 1–3: buffer handle. Type 4: flushed buffer type (1 / 2 / 3) |
| 0C-0F | ? | ? |
| 10-27 | ? | Types 1–3: frame information from the PCD (6 DWORDs) |
| 28-2B | 20 00 00 00 | 32 |
| 2C-2F | ? | ? |

#### Command 8 "Process frame"

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-17 | | Header, Id = 8 |
| 18-1B | ? | Buffer handle of the input frame |
| 1C-1F | ? | Length (same value as 20-23 in qccamavs8930) |
| 20-23 | ? | Length used (must be ≤ the reserved size) |
| 24-27 | 00 00 00 00 | ? |
| 28-2F | ? | Timestamp ÷ 10 (64 bits), set by qccamavs8930 |
| 30-37 | 00 … | ? |

Gives an input frame to the VPE (`PCD_ProcessFrame`, PCD function +0x08, with the device address of the buffer). It comes back as an "input frame done" [message](#messages); the result is written in a buffer given with [Provide output buffer](#command-6-provide-output-buffer).

---

### PCD interface

PCD session (per client, magic 0x75017591), function table at handle +0x04:  
| Offset | Function |
|--------|----------|
| 0x04 | Start |
| 0x08 | ProcessFrame |
| 0x14 | Flush |
| 0x18 | Stop |
| 0x1C | SetProperty (`sub_4052B8`) |
| 0x20 | GetProperty (`sub_405338`) |
| 0x24 | SetExtProperty (`sub_4053B8`, Ids ≥ 0xF1) |
| 0x28 | GetExtProperty (`sub_405438`) |
| 0x2C | SetBufferRequirements |
| 0x30 | GetBufferRequirements (`sub_4054B8`) |
| 0x34 | SetBuffer |
| 0x40 | FillOutputBuffer |
| 0x44 | Interrupt event ? (called by the DPC with event 0x100A, through the session at `off_40F24C`) |

Driver-level table (`off_40F228`): 0 = init (register base), 1 = deinit, 2 = open (callback), 3 = close, 4 = pause, 5 = resume. All the calls are made under a spinlock (`dword_40F348`, pool tag `qvpq`).

---

### Interface GUID

VPE Interface Class GUID (`.rdata:0x0040E1B0`)  
`{95f66217-6158-4f46-a8c6-dfd0bfcf94f1}`

### Other GUID

VPE buffer commands (IOCTL 0x900)  
`{fcd1c5aa-85b7-45e7-9426-d6c31ee30130}`

VPE properties (IOCTL 0x950)  
`{7307682b-adfe-40fa-b37d-be330a37d488}`

VPE stream commands (IOCTL 0x9A0)  
`{c8a7f717-a0fe-4bf4-b44e-0a27e9fa9562}`

PoFx power control: set P-state ([qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state))  
`{3404daac-8e2c-41e4-8458-3158e5ad442b}`
