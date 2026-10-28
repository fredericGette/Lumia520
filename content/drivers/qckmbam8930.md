## Qckmbam8930.sys

BAM (Bus Access Manager, Qualcomm "SPS" DMA engine) driver.  
KMDF function driver of the 3 `QCOM0910` ACPI nodes (`\_SB.BAM0`, `\_SB.BAM1`, `\_SB.BAM2`). For each BAM it resets the block, programs the pipe security (trust) registers, allocates the descriptor FIFOs of the pipes declared in ACPI, and gives kernel clients pipe connect / disconnect, descriptor submission and completion (callback or pended request) through `METHOD_NEITHER` IOCTLs (device type 4).  
The known client is [qcbamdmux8930.sys](./qcbamdmux8930.md), which uses the A2 BAM (`DataBAM`, 0x124C2000). [qcslimbus8930.sys](./qcslimbus8930.md) uses the `LPASS_BAM` (0x28084000) for the SLIMbus data ports. The clients of `BAMDMA` are unknown.  
PDB path: `P:\BAM\rel\8.2.1.1\arm\Release\qckmbam8930.pdb`. The driver does nothing at `EvtDevicePrepareHardware` besides reading resources and ACPI: the hardware is only initialized at the first [IOCTL 0x42007](#ioctl-0x42007).

Device name : `\Device\BAM<n>` (`"%ws%d"`, `n` = global counter starting at 0, incremented at each `EvtDriverDeviceAdd`: the order of enumeration, not the `_UID`)  
There's no symbolic link; clients find the devices through the device interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}`.

There's no parameters in the registry.

GUID of the ETW provider (WPP control GUID):  
`{5C443E1C-6949-4E39-A898-2020331C8F90}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of the device (default I/O target) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD` 0x32C004 for the methods `INFO`, `PIPE` and `SECC` |

Peer drivers (clients):  
| Driver | Comment |
|--------|---------|
| [qcbamdmux8930.sys](./qcbamdmux8930.md) | Opens every `{3E77CCA9-…}` instance, keeps the one whose [IOCTL 0x42003](#ioctl-0x42003) returns 0x124C2000 (A2 BAM), then uses IOCTLs 0x4202B, 0x4200B, 0x4200F and 0x42007 |
| [qcslimbus8930.sys](./qcslimbus8930.md) | Opens every `{3E77CCA9-…}` instance, keeps the one whose [IOCTL 0x42003](#ioctl-0x42003) returns 0x28084000 (`LPASS_BAM`), then uses IOCTLs 0x42007, 0x4200B, 0x4200F and 0x4201B (asynchronous, preallocated requests) |

WDF objects:
- `DriverEntry` (0x409008) → `WdfDriverCreate`, `EvtDriverDeviceAdd` = `sub_40855C` → `sub_4083F8`.
- `EvtDevicePrepareHardware` = `sub_4037B8`, `EvtDeviceReleaseHardware` = `sub_403A50`, which only returns `STATUS_SUCCESS` (nothing is unmapped, the descriptor FIFOs and the interrupt are never released). No D0Entry / D0Exit callbacks.
- Device context `DEVICE_CONTEXT` (136 bytes). `WdfDeviceSetStaticStopRemove(FALSE)`.
- Default queue: sequential, not power managed, `EvtIoDeviceControl` (0x403320). One extra manual queue per pipe (pended transfers, `EvtIoCanceledOnQueue` completes with `STATUS_CANCELLED`).
- Interrupt: `WdfInterruptCreate` with the interrupt resource; the ISR `sub_401878` only queues the DPC `sub_401D94`.

Pool tags: `qkb0` (`PIPE` output), `qkb1` (pipe configuration array), `qkb2` (`SECC` output), `qkb3` (`SECC` array), `qkb4` (pipe contexts), `qkb5` (per-descriptor client contexts).

### ACPI

At `EvtDevicePrepareHardware` the driver takes the first `CmResourceTypeMemory` (physical base → context `+0x00`, length → `+0x34`) and the `CmResourceTypeInterrupt` resource, creates the device interface, then evaluates 3 methods of its ACPI node with `IOCTL_ACPI_EVAL_METHOD` (`sub_401068`, input signature `AeiB`, output signature `AeoB` checked):  
| Method | Content | Use |
|--------|---------|-----|
| `INFO` | Package: string, integer | String → `UNICODE_STRING` at context `+0x38` (BAM name, only used in traces). Integer → context `+0x40`: execution environment (EE) of the application processor on this BAM |
| `PIPE` | Package of packages of 7 integers | Pipes pre-configured by this driver, see below. Optional (not present on `BAM1`) |
| `SECC` | Package of packages of 2 integers `{PipeMask, Vmid}` | Pipe security, entry `i` is for EE `i`. Optional |

`PIPE` and `SECC` are evaluated twice: once with a 20-byte output to get the size (`STATUS_BUFFER_OVERFLOW` expected), then with a buffer of the right size. A wrong output signature or an empty package → `STATUS_ACPI_INVALID_DATA` (0xC014000F), but the error is ignored by `EvtDevicePrepareHardware`.

Lumia 520 nodes (from the DSDT, see also [qcbamdmux8930.sys](./qcbamdmux8930.md#lumia-520-acpi-nodes)):  
| Node | `INFO` | Memory | Interrupt | `PIPE` | `SECC` |
|------|--------|--------|-----------|--------|--------|
| `\_SB.BAM0` | `"BAMDMA"`, EE 0 | 0x12244000, 0x2000 | 137 | `{0, 0, 1, 0x21, 0x100, 0, 0}`, `{1, 1, 1, 0x21, 0x100, 0, 0}` | — |
| `\_SB.BAM1` | `"DataBAM"`, EE 0 | 0x124C2000, 0x2000 | 241 | — | — |
| `\_SB.BAM2` | `"LPASS_BAM"`, EE 1 | 0x28084000, 0x2000 | 66 | `{0x18, 0, 1, 0x21, 0x100, 0, 0}`, `{0x19, 1, 1, 0x21, 0x100, 0, 0}` | `{0x00FFFF98, 0}`, `{0xFF000007, 1}`, `{0x60, 2}`, `{0, 0}` |

A `PIPE` entry is copied into a 48-byte pipe configuration (same layout as the input of [IOCTL 0x4200B](#ioctl-0x4200b)):  
| Index | Configuration offset | Comment |
|-------|----------------------|---------|
| 0 | +0x00 | Pipe number |
| 1 | +0x04 | Direction (`P_CTRL` bit 3): 0 = transmit, 1 = receive (as used by [qcbamdmux8930.sys](./qcbamdmux8930.md#ioctl-0x4200b)) |
| 2 | +0x08 | System mode (`P_CTRL` bit 5) |
| 3 | +0x0C | Pipe IRQ enable mask (`P_IRQ_EN`), 0x21 = `P_PRCSD_DESC_EN` \| `P_TRNSFR_END_EN` |
| 4 | +0x18 | Size of the descriptor FIFO in bytes (0x100 = 32 descriptors) |
| 5 | +0x28 | ? (not used by the driver) |
| 6 | +0x2C | ? (not used by the driver) |

### Hardware initialization

Done by `sub_401F3C` at the first [IOCTL 0x42007](#ioctl-0x42007):
1. `sub_402124`: if the BAM physical base is 0x12240000 or 0x12242000, map 0x3000 bytes at 0x00900000 (clock controller) and write 0x10 at offsets 0x25C0, 0x25A0 and 0x2564 (clock branch enables ?). None of the Lumia 520 BAMs has one of these bases, so this is never done.
2. Map the BAM (`MmMapIoSpace`, non cached, length of the memory resource) → context `+0x10`.
3. Reset the BAM (`sub_4014B4`), read the BAM configuration (`sub_401608`, see the table below). Fails with `STATUS_DEVICE_CONFIGURATION_ERROR` (0xC0000182) if `BAM_EN` is not set after the reset, if the number of pipes is 0 or ≥ 32, or if `SECC` has more entries than the BAM has EEs.
4. Apply `SECC` (`sub_401550`): for entry `i`, every pipe whose bit is set in `PipeMask` gets `P_TRUST_REG` EE = `i` and VMID = `Vmid`; if bit 31 is set, `BAM_TRUST_REG` gets the same EE and VMID and its bit 7 (`BAM_RST_BLOCK` ?) is cleared. Applied only once (not at a re-initialization).
5. Allocate the pipe contexts (80 bytes × number of pipes).
6. Allocate one physically contiguous buffer (`MmAllocateContiguousMemorySpecifyCache`) of the sum of the descriptor FIFO sizes of the `PIPE` entries, split it between the pipes in order, and connect each pipe ([pipe connection](#ioctl-0x4200b)).
7. Mark the BAM as initialized (context `+0x48`).

BAM reset sequence (`sub_4014B4`), names from Linux `drivers/platform/msm/sps/bam.c`:  
| Register | Offset | Value |
|----------|--------|-------|
| `BAM_CTRL` | 0xF80 | Set `BAM_SW_RST` (bit 0), clear it, then set `BAM_EN` (bit 1) |
| `BAM_DESC_CNT_TRSHLD` | 0xF88 | 0x2000 |
| `BAM_CNFG_BITS` | 0xFFC | 0x7FFFF004 |
| `BAM_IRQ_SRCS_MSK` (EE 0) or `BAM_IRQ_SRCS_MSK_EE(n)` (0x1804 + 0x80 × n) | 0xF90 | Set bit 31 (BAM interrupt) |
| `BAM_IRQ_EN` | 0xF9C | 6 (`BAM_ERROR_EN` \| `BAM_HRESP_ERR_EN`) |

BAM configuration read by `sub_401608` into the context:  
| Context | Register | Field |
|---------|----------|-------|
| +0x14 | `BAM_NUM_PIPES` 0xFBC | bits 0-7: number of pipes |
| +0x18 | `BAM_REVISION` 0xF84 | bits 0-7: revision (must be 3..31 for `SECC`) |
| +0x1C | `BAM_REVISION` | bits 8-11: number of EEs |
| +0x20 | `BAM_REVISION` | bit 16: secured |
| +0x24 | `BAM_REVISION` | bits 24-31: inactivity timer base |
| +0x28 | `BAM_REVISION` | bit 19: inactivity timers exist |
| +0x2C | `BAM_REVISION` | bit 18: high frequency BAM |
| +0x30 | `BAM_REVISION` | bit 17: BAM has no bypass |

Pipe registers used (pipe `n`):  
| Register | Offset | Use |
|----------|--------|-----|
| `P_CTRL` | 0x0000 + 0x80 × n | bit 1 `P_EN`, bit 3 direction, bit 5 system mode |
| `P_RST` | 0x0004 + 0x80 × n | Written 1 then 0 at every connect / disconnect |
| `P_IRQ_STTS` | 0x0010 + 0x80 × n | Read by the DPC |
| `P_IRQ_CLR` | 0x0014 + 0x80 × n | Written with the status read |
| `P_IRQ_EN` | 0x0018 + 0x80 × n | IRQ enable mask |
| `P_TRUST_REG` | 0x0030 + 0x80 × n | bits 0-1 EE, bits 8-12 VMID |
| `P_SW_OFSTS` | 0x1000 + 0x40 × n | bits 0-15: offset of the last descriptor processed by the BAM |
| `P_EVNT_REG` | 0x1018 + 0x40 × n | bits 0-15: write offset (doorbell) |
| `P_DESC_FIFO_ADDR` | 0x101C + 0x40 × n | Physical address of the descriptor FIFO |
| `P_FIFO_SIZES` | 0x1020 + 0x40 × n | bits 0-15: size of the descriptor FIFO |

The bit of the pipe in `BAM_IRQ_SRCS_MSK` (0xF90, EE 0) or `BAM_IRQ_SRCS_MSK_EE(n)` is set with the IRQ enable mask (`sub_40167C`).

### Descriptors and completion

Descriptor (8 bytes, in the descriptor FIFO):  
| Bytes | Comment |
|-------|---------|
| 00-03 | Physical address of the buffer |
| 04-05 | Size in bytes |
| 06-07 | Flags: only bits 13-15 of the caller's flags are kept (0x8000 `INT`, 0x4000 `EOT`, 0x2000 `EOB` in Linux ?) |

Interrupt DPC `sub_401D94`: reads `BAM_IRQ_SRCS` (0xF8C) masked with the connected pipes (and writes it to `BAM_IRQ_CLR` 0xF98) for EE 0, or `BAM_IRQ_SRCS_EE(n)` (0x1800 + 0x80 × n) otherwise, then for each pipe bit `sub_401C94` reads and clears `P_IRQ_STTS`. If bit 0 or 5 (descriptor processed / transfer end) is set, `sub_401AA4` walks the descriptors from the pipe read offset up to `P_SW_OFSTS`. For each descriptor: event = 2 if one of the flags 0xE000 is set, otherwise 7; then
- callback mode (after [IOCTL 0x4202B](#ioctl-0x4202b)): `Callback(ULONG Pipe, PVOID ClientContext, ?, ULONG Event, ULONG DescAddress, ULONG DescSizeFlags, ?)`, called with the pipe spin lock released. The 3rd and 7th parameters are uninitialized stack values.
- otherwise (`sub_4018A4`): the next request of the pipe's manual queue (pended by [IOCTL 0x4201B](#ioctl-0x4201b)) is completed with the 20-byte event below. If its output buffer is not 20 bytes, it's completed with `STATUS_INSUFFICIENT_RESOURCES`.

Bit 31 of the IRQ sources (BAM-level interrupt: error) is only traced; `BAM_IRQ_STTS` is never read.

---

### IOCTL 0x42003

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get BAM physical address | any | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 00 20 4C 12 | Physical base address of the BAM (low 32 bits of the memory resource) |

Used by [qcbamdmux8930.sys](./qcbamdmux8930.md#ioctl-0x42003) to find the A2 BAM. OutputBufferLength ≠ 4 → `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x42007

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Initialize / reset BAM | 0 | 0 |

`sub_4023A0`: the first time, full [hardware initialization](#hardware-initialization). The next times, the BAM is reset again (`sub_4014B4`) and every connected pipe is reconnected with its saved configuration (the descriptor FIFO content and offsets are lost). The request is always completed with `STATUS_SUCCESS`, even if the initialization failed. Non-zero buffer lengths → `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x4200B

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x802 (2050) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Connect pipe | 52 (exact) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 01 00 00 00 | Pipe (index of the pipe context) |
| 04-07 | e.g. 01 00 00 00 | Pipe number programmed in the hardware (same value) |
| 08-0B | 00 or 01 | Direction, `P_CTRL` bit 3 |
| 0C-0F | 01 00 00 00 | System mode, `P_CTRL` bit 5 |
| 10-13 | 21 00 00 00 | IRQ enable mask (`P_IRQ_EN`) |
| 14-17 | ? | Physical address of the descriptor FIFO (`P_DESC_FIFO_ADDR`). When 0, the FIFO registers are not written |
| 18-1B | ? | Virtual address of the descriptor FIFO |
| 1C-1F | 00 01 00 00 | Size of the descriptor FIFO in bytes (`P_FIFO_SIZES`) |
| 20-33 | 0 | ? (copied, not used) |

`sub_402560`: pipe ≥ number of pipes → `STATUS_INVALID_PARAMETER_2`. The 48-byte configuration is copied into the pipe context, the pipe is reset (`P_RST`), the IRQ mask, `P_CTRL`, descriptor FIFO address and size are programmed, `P_EN` is set and the pipe is marked connected. Read/write offsets are reset to 0. In callback mode a client-context array (4 bytes per descriptor) and a spin lock are allocated; otherwise the manual queue of the pipe is created, or purged and restarted.

---

### IOCTL 0x4200F

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x803 (2051) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Disconnect pipe | 4 (exact) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 01 00 00 00 | Pipe |

`sub_402560` without configuration: the pipe is reset (`P_RST`) and marked disconnected. Pended requests are purged (completed with `STATUS_CANCELLED`) in queue mode. `P_EN` and the IRQ mask are not cleared explicitly.

---

### IOCTL 0x42013

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x804 (2052) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get pipe configuration | 4 (exact) | 48 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pipe |

Outputbuffer: the 48-byte configuration of the pipe (bytes 04-33 of the input of [IOCTL 0x4200B](#ioctl-0x4200b)).  
`sub_4029FC`: pipe not connected → `STATUS_DEVICE_NOT_READY` (0xC00000A3).

---

### IOCTL 0x42017

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x805 (2053) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set pipe IRQ mask | 12 (exact) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pipe |
| 04 | 00 or 01 | 1 = enable the IRQs of the mask, otherwise disable all the IRQs of the pipe |
| 05-07 | ? | Not used |
| 08-0B | e.g. 21 00 00 00 | IRQ mask, only bits 0-5 are kept |

`sub_4028A0`: writes `P_IRQ_EN` and the pipe bit of `BAM_IRQ_SRCS_MSK`. Pipe not connected → `STATUS_DEVICE_NOT_READY`.

---

### IOCTL 0x4201B

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x806 (2054) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Transfer (queue mode) | 12 (exact) | 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pipe |
| 04-07 | ? | Physical address of the buffer |
| 08-09 | ? | Size in bytes |
| 0A-0B | ? | Flags: bits 13-15 go into the descriptor; bit 8 (0x100) = don't write `P_EVNT_REG` (descriptor queued but not submitted to the BAM yet ?) |

Outputbuffer (written at completion):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Uninitialized |
| 04-07 | 02 or 07 | Event: 2 if one of the flags 0xE000 was set in the descriptor, 7 otherwise |
| 08-0B | ? | Physical address of the completed descriptor |
| 0C-0F | ? | Size (bits 0-15) and flags (bits 29-31) of the completed descriptor |
| 10-13 | ? | Uninitialized |

`sub_402AE8` writes the descriptor at the write offset and forwards the request to the manual queue of the pipe; it's completed later by the DPC, in order (see [Descriptors and completion](#descriptors-and-completion)). The request is not completed by the dispatcher on success. Errors: pipe not connected → `STATUS_DEVICE_NOT_READY`, descriptor FIFO full → `STATUS_INSUFFICIENT_RESOURCES`.

> [!NOTE]
> If the BAM is in callback mode ([IOCTL 0x4202B](#ioctl-0x4202b) was sent), this IOCTL executes `__debugbreak()`.

---

### IOCTL 0x4201F

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x807 (2055) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Is pipe empty | 4 (exact) | 1 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pipe |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 or 01 | 1 if the write offset equals the read offset (no descriptor pending) |

---

### IOCTL 0x42023

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x808 (2056) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Poll pipe | 4 (exact) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pipe |

`sub_402D90`: runs the interrupt processing of the pipe (`sub_401C94`) without an interrupt. Returns `STATUS_SUCCESS` if at least one descriptor completed, otherwise the custom status 0x60050001 (informational). Pipe not connected → `STATUS_DEVICE_NOT_READY`. Also given as a function pointer by [IOCTL 0x4202B](#ioctl-0x4202b).

---

### IOCTL 0x42027

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x809 (2057) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get free descriptors | 4 (exact) | 4 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pipe |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Number of descriptors that can still be queued (`sub_402FB4`) |

---

### IOCTL 0x4202B

This IOCTL is processed by Qckmbam8930.sys

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x80A (2058) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Register callback / get function table | 4 (exact) | 12 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Address of the completion callback, see [Descriptors and completion](#descriptors-and-completion) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `WDFDEVICE` of the BAM, first parameter of both functions |
| 04-07 | ? | `NTSTATUS Transfer(WDFDEVICE Bam, PVOID ClientContext, ULONG Pipe, ULONG PhysicalAddress, USHORT Size, USHORT Flags)` (`sub_402AE8`). `ClientContext` is given back to the callback |
| 08-0B | ? | `NTSTATUS Poll(WDFDEVICE Bam, ULONG Pipe)` (`sub_402D90`, same as [IOCTL 0x42023](#ioctl-0x42023)) |

Switches the whole BAM (all its pipes) to callback mode (context `+0x7C` = 1, callback at `+0x80`); it can't be switched back. The callback must be registered before the pipes are connected, because the client-context arrays and spin locks are only allocated at connection. The pipes connected from `PIPE` at the first [IOCTL 0x42007](#ioctl-0x42007) are in queue mode unless this IOCTL was sent before.

> [!NOTE]
> All the IOCTLs are `METHOD_NEITHER`: the buffers are only accessible to kernel-mode callers.

Other IOCTL codes complete with `STATUS_SUCCESS` and 0 bytes. A wrong buffer length → `STATUS_INVALID_PARAMETER` (0xC000000D); a pipe ≥ number of pipes → `STATUS_INVALID_PARAMETER_2` (0xC00000F0).

---

### Interface GUID

Qckmbam8930 Interface Class GUID (one instance per BAM)  
`{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}`
