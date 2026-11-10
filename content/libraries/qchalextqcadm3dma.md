## QCHalExtQcAdm3Dma.dll

HAL extension that exposes the Qualcomm ADM3 data mover ("DMOV") as a system DMA controller to the Windows HAL, build `P:\ADM\rel\8.2.1.1\Output\arm\Release\HalExtQcAdm3Dma.pdb`.  
It's a tiny kernel-mode image (32 functions, no import at all), built like its sibling [QCHalExtQ8x60Bam.dll](./qchalextq8x60bam.md): the HAL gives it a table of services at its entry point and the extension returns its `AddResourceGroup` function. `AddResourceGroup` reads the CSRT DMA controller and channel descriptors of up to 2 ADMs, and registers for each one a controller and its channels (at most 16) with the HAL; the HAL then drives the ADM through the 10 functions of a [DMA function table](#dma-function-table). A transfer is a list of ADM "box" commands built from the scatter/gather list, or a command list given by the driver itself ([ConfigureChannel](#configurechannel-sub_4013f8-0x4013f8) function 2). A DMA request line is turned into an ADM CRCI (flow-control line) number: request line − minimum request line of the controller.  
Its known users are the crypto engine drivers [qcearm8930.sys](../drivers/qcearm8930.md#dma) (request lines 2 and 3) and [qce2arm8930.sys](../drivers/qce2arm8930.md#dma) (request lines 4 and 5), which build their own command lists and use exactly the `ConfigureAdapterChannel` functions 0, 1 and 2 of this extension; [Qcuart8930.sys](../drivers/qcuart8930.md#dma) also gets ADM channels with `IoGetDmaAdapter`. Which ADM(s) it drives depends on the CSRT of the firmware, which isn't in [content/acpi](../acpi/README.md); the register offsets (0x20000 + 0x800 × security domain 1) match an ADM block at 0x18300000 ([Qcuart8930.sys](../drivers/qcuart8930.md#dma) programs the CRCIs of the ADM at 0x18300000) ?.

Location on the phone: `C:\Windows\System32\QCHalExtQcAdm3Dma.dll` ? (the extracted file has no notes).  

### Imports

None. The image has no import directory and doesn't link a CRT: `memcpy` (`_memcpy_decide` and its variants) and the `__rt_udiv` / `__rt_udiv64` / `__rt_sdiv64` helpers are statically linked, `__security_init_cookie` (`sub_409008`, in the `INIT` section) and `_GSHandlerCheck` / `__security_push_cookie` / `__security_pop_cookie` / `_gsfailure` are the `/GS` boilerplate.  
Everything else goes through the [HAL services table](./qchalextq8x60bam.md#hal-services) received at the entry point (same table as the BAM extension; only the entries +0x00 `RegisterResourceDescriptor`, +0x04 `GetNextResourceDescriptor` and +0x0C `HalMapIoSpace` are used, through the wrappers `sub_401A38`, `sub_401A0C` and `sub_4019E0`). There's no trace (no ETW, no WPP, no debug print).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| HAL ([HAL.dll](./hal.md)) | Entry point `start`, [HAL services table](./qchalextq8x60bam.md#hal-services) | The HAL loads the extension, enumerates the CSRT for it and calls the [DMA function table](#dma-function-table) |

No DLL is loaded at run time, no file or registry key is used.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| — | `start` (entry point) | 0x401A58 | `ULONG Reserved` ?, `PVOID *ExportTable` (out), `PVOID HalServices` (in) |

There's no export directory: the only entry is the image entry point.

### Startup

`start` (0x401A58), same code as the BAM extension:
1. `Reserved` must be 0, otherwise it returns 0xC00002B9.
2. `__security_init_cookie` (`sub_409008`).
3. Keeps the HAL services table in `dword_407138`, sets `*ExportTable` = `off_404100`, clears `dword_40713C`, returns `STATUS_SUCCESS`.

`off_404100` holds a single function pointer, [AddResourceGroup](#addresourcegroup-sub_401770-0x401770) (`sub_401770`); it's followed by the `/GS` cookie and its complement (0xBB40E64E, 0x44BF19B1), then the [DMA function table](#dma-function-table) at `off_40410C`.

### AddResourceGroup (sub_401770, 0x401770)

Called by the HAL with `(Handle, ResourceGroup)`. The two [controller contexts](#controller-context) are a global array `unk_404160` (2 × 0x17E0 bytes). The function uses `/GS` (no decompilation).

1. Clears the state of the 16 channels of both controllers and sets the 16 burst lengths of each to 0xFFF0. Then, for controller 1 only, sets the burst lengths of CRCIs 1, 2, 4 and 5 to 0x20, 0x10, 0x20 and 0x20.
2. Enumerates the DMA controller descriptors: `GetNextResourceDescriptor(Handle, ResourceGroup, Previous, Type 3, Subtype 1, Uid 0xFFFF)`. For each one, `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A) is returned at once if the controller index (+0x0C) is ≥ 2, the channel count (+0x1C) is > 16, or max − min request line (+0x24 − +0x20) is ≥ 16. Otherwise the fields are copied into the context of that index, and the first 0x28 bytes of the descriptor into a table of 2 entries `unk_407160` (never read).
3. Enumerates the DMA channel descriptors (`Type 3, Subtype 0`): controller index (+0x0C) < 2 and channel number (+0x10) < 16, else 0xC000009A. The channel gets its CRCI mask (+0x14) and the state "idle" (1).
4. For each controller whose register address isn't 0, it doesn't pass the firmware descriptors to the HAL but builds its own 12-byte CSRT descriptors on the stack: `Length` 0x0C, `Type` 3, `Subtype` 1 (controller) or 0 (channel), `Uid` 0x80000000, 0x80000001, … (incremented after each registration, across both controllers). It calls `RegisterResourceDescriptor` with the [controller initialization block](#dma-controller-initialization-block), then once per present channel (state ≠ 0) with a [channel initialization block](#dma-channel-initialization-block). A negative status is returned at once.

Returns `STATUS_SUCCESS`, or one of the errors above.

### CSRT descriptors

Format expected by `AddResourceGroup`. The first 12 bytes are the standard CSRT resource descriptor header.

DMA controller (type 3, subtype 1):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `Length` (not checked) |
| 0x04 | 2 | `Type`: 3 (DMA) |
| 0x06 | 2 | `Subtype`: 1 |
| 0x08 | 4 | `Uid` |
| 0x0C | 4 | Controller index: 0 or 1 |
| 0x10 | 8 | Physical address of the ADM registers (0xE8000 bytes are mapped) |
| 0x18 | 4 | GSIV of the ADM interrupt |
| 0x1C | 4 | Number of channels (≤ 16) |
| 0x20 | 4 | Minimum request line (CRCI 0) |
| 0x24 | 4 | Maximum request line (≤ minimum + 15) |

DMA channel (type 3, subtype 0):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `Length` (not checked) |
| 0x04 | 2 | `Type`: 3 |
| 0x06 | 2 | `Subtype`: 0 |
| 0x08 | 4 | `Uid` |
| 0x0C | 4 | Controller index (< 2) |
| 0x10 | 4 | Channel number (< 16) |
| 0x14 | 4 | CRCI mask: bit `n` set = the channel may be used with CRCI `n` (request line minimum + `n`). CRCI 0 is always allowed |

### DMA controller initialization block

0x44 bytes, built on the stack by `AddResourceGroup`; same layout as in the [BAM extension](./qchalextq8x60bam.md#dma-controller-initialization-block).

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 1 (version) |
| 0x04 | 4 | 0x44 (size) |
| 0x08 | 4 | Controller id: index + 2, i.e. 2 or 3, overwritten by the HAL with its own sequential id (0, 1, 2… in registration order, [HalpRegisterDmaController](./hal.md#dma-controller-initialization-block)), so the ids of the two extensions don't clash. The extension reads it back after `RegisterResourceDescriptor` for the channel blocks |
| 0x0C | 4 | Number of channels (descriptor +0x1C) |
| 0x10 | 1 | 0: cache coherent ? |
| 0x14 | 4 | 32: DMA address width ? |
| 0x18 | 4 | 0x1F: supported port widths ? |
| 0x1C | 4 | 1 ? |
| 0x20 | 4 | Minimum request line |
| 0x24 | 4 | Maximum request line |
| 0x28 | 1 | 1: generates interrupt |
| 0x2C | 4 | GSIV (descriptor +0x18) |
| 0x30 | 4 | 0: interrupt polarity ? |
| 0x34 | 4 | 0: interrupt mode ? |
| 0x38 | 4 | Internal data: the [controller context](#controller-context) |
| 0x3C | 4 | 0x17E0: size of the internal data |
| 0x40 | 4 | `off_40410C`: [DMA function table](#dma-function-table) |

### DMA channel initialization block

0x24 bytes.

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 1 (version) |
| 0x04 | 4 | 0x24 (size) |
| 0x08 | 4 | Controller id: the one written by the HAL in the controller block |
| 0x0C | 1 | 0: generates interrupt ? |
| 0x10 | 0x0C | Not written (stack content) |
| 0x1C | 4 | 0x1000: common buffer length (4 KB, holds the [command list](#programchannel-sub_4010e4-0x4010e4)) |
| 0x20 | 4 | Channel number |

### Controller context

0x17E0 bytes, `unk_404160` + 0x17E0 × index while it's built, then the HAL's copy, passed as first parameter of every function of the DMA function table. The 16 channels have 0x178-byte records that start at the beginning of the context (channel `n` field at +0x178 × `n` + offset); their first field is at +0x58, so the controller fields below +0x58 only exist once.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | Physical address of the ADM registers |
| 0x08 | 4 | Virtual address of the registers (mapped at the first initialization) |
| 0x0C | 4 | Number of channels |
| 0x10 | 4 | Minimum request line |
| 0x14 | 4 | Maximum request line |
| 0x18 | 16 × 4 | Burst (row) length in bytes per CRCI, 0xFFF0 by default; set by [ConfigureChannel](#configurechannel-sub_4013f8-0x4013f8) function 0 |
| 0x28 | 4 | Pointer to the real context, used by [CancelTransfer](#canceltransfer-sub_4013a0-0x4013a0) when called with an unknown context ? (never written) |
| 0x17D8 | 4 | GSIV while the context is built, then the pending interrupt sources (one bit per channel) |
| 0x17DC | 4 | Active channels: a transfer is programmed and its result not read |

Channel record (+0x178 × channel):

| Offset | Size | Comment |
|--------|------|---------|
| 0x58 | 4 | State: 0 = not present, 1 = idle, 2 = transfer programmed, 3 = flushing, 4 = completed with error |
| 0x60 | 8 | Physical address of the common buffer |
| 0x68 | 4 | Virtual address of the common buffer |
| 0x70 | 4 | Virtual address of the command list (common buffer + 8) |
| 0x74 | 4 | Common buffer physical address >> 3: value written to `CMD_PTR` |
| 0x78 | 4 | Destination swap bits (ConfigureChannel function 1), bits 0-2 → command bits 14-16 |
| 0x7C | 4 | CRCI mask (channel descriptor +0x14) |
| 0x80 | 8 | Physical address of a command list given by the driver (ConfigureChannel function 2), 0 = build box commands |
| 0x88 | 4 | Number of transfers programmed |
| 0x8C | 4 | Last `RSLT` register read |
| 0x90 / 0x98 / 0xA0 | 8 each | Start / end / flush time of the last transfer, copied from `dword_407130` which is never written (always 0) |
| 0xA8 | 4 | Index in the two 16-entry history rings below |
| 0xB0 | 16 × 8 | Duration of the transfers (end − start, so always 0) |
| 0x130 | 16 × 8 | Bytes programmed per transfer |
| 0x1B0 | 4 | Flush mode written to `FLUSH0`: 0 or 0x80000000 (ConfigureChannel function 3) |
| 0x1B4 | 6 × 4 | `FLUSH0` … `FLUSH5` read after an error or a flush (command state, for debugging ?) |

### ADM registers

Offsets from the mapped base used by the extension. They are those of the ADM3 of the Linux `msm_dmov` driver (`arch/arm/mach-msm/dma.c`), in security domain 1 (base + 0x20000 + 0x800 × 1); names from Linux.

| Register | Offset | Use |
|----------|--------|-----|
| `CMD_PTR(ch)` | 0x20800 + 4 × ch | Start a transfer: address >> 3 of a command pointer list |
| `RSLT(ch)` | 0x20840 + 4 × ch | Result: bit 3 error, bit 2 flush |
| `FLUSH0(ch)` … `FLUSH5(ch)` | 0x20880 … 0x20980 + 4 × ch | `FLUSH0` written to flush the channel (bit 31 = flush type); all 6 read back after an error or a flush |
| `STATUS(ch)` | 0x20A00 + 4 × ch | Bit 1 result valid; bit 26 tested before a flush or a counter read: command in progress ? |
| `CONF(ch)` | 0x20B00 + 4 × ch | 3 at initialization (interrupt and result enables ?) |
| `ISR` | 0x20B80 | Channels with an interrupt pending |

The CRCI control registers (`HI_CRCIn_CTL`) aren't touched: the drivers do it themselves ([Qcuart8930.sys](../drivers/qcuart8930.md#dma)).

### DMA function table

`off_40410C`, given to the HAL in the controller initialization block, in the order of the Windows `DMA_FUNCTION_TABLE`. Most functions increment a call counter (`dword_404140`…`dword_40415C`, `dword_407120`…`dword_407128`), never read.

| Index | Function | Address |
|-------|----------|---------|
| 0 | [InitializeController](#initializecontroller-sub_401008-0x401008) | `sub_401008` |
| 1 | [ValidateRequestLineBinding](#validaterequestlinebinding-sub_401080-0x401080) | `sub_401080` |
| 2 | QueryMaxFragments | 0x4010D8 (not a function in the database): always returns 20 |
| 3 | [ProgramChannel](#programchannel-sub_4010e4-0x4010e4) | `sub_4010E4` |
| 4 | [ConfigureChannel](#configurechannel-sub_4013f8-0x4013f8) | `sub_4013F8` |
| 5 | [FlushChannel](#flushchannel-sub_4014dc-0x4014dc) | `sub_4014DC` |
| 6 | [HandleInterrupt](#handleinterrupt-sub_401514-0x401514) | `sub_401514` |
| 7 | ReadDmaCounter | `sub_4016DC`: if `STATUS` bit 26 is set, the number of bytes programmed for the current transfer (not the bytes remaining), else 0 |
| 8 | [ReportCommonBuffer](#reportcommonbuffer-sub_401728-0x401728) | `sub_401728` |
| 9 | [CancelTransfer](#canceltransfer-sub_4013a0-0x4013a0) | `sub_4013A0` |

All the register accesses are preceded by a `DSB` barrier. Unlike the BAM extension, nothing re-initializes the controller after a power loss.

### InitializeController (sub_401008, 0x401008)

`(PVOID ControllerContext)`:
1. Keeps the context in the table `dword_407140` (2 entries, filled in call order, used by [CancelTransfer](#canceltransfer-sub_4013a0-0x4013a0)).
2. The first time: `HalMapIoSpace(physical address, 0xE8000, MmNonCached)` into +0x08.
3. Clears the active channels; for each present channel: state 1 (idle), transfer count 0, `CONF(ch)` = 3.

### ValidateRequestLineBinding (sub_401080, 0x401080)

`(ControllerContext, {RequestLine, ChannelNumber})`: CRCI = `RequestLine` − minimum. TRUE if the request line is between the minimum and the maximum, the channel number is lower than the channel count, and the CRCI is 0 or its bit is set in the CRCI mask of the channel. Unlike the BAM extension, any channel can serve any request line its mask allows.

### ProgramChannel (sub_4010E4, 0x4010E4)

`(ControllerContext, ChannelNumber, RequestLine, PDMA_SCATTER_GATHER_LIST, PHYSICAL_ADDRESS DeviceAddress, BOOLEAN WriteToDevice, BOOLEAN LoopTransfer)`; `LoopTransfer` is ignored.

1. State = 2 (programmed).
2. If the driver gave a command list (+0x80, ConfigureChannel function 2): the dword at common buffer + 8 = (address >> 3) | 0x80000000 (last pointer), and `CMD_PTR` gets (common buffer physical >> 3) | 1, i.e. it points at that entry. The request line, the scatter/gather list and the device address aren't used: the driver's command list does everything. This is the path of [qcearm8930.sys](../drivers/qcearm8930.md#dma) and [qce2arm8930.sys](../drivers/qce2arm8930.md#dma).
3. Otherwise box commands (24 bytes each) are written from common buffer + 8:
   - CRCI = request line − minimum (16 if not valid, which reads a wrong burst length); burst = burst length of the CRCI;
   - command word = 3 (box mode) | source CRCI << 3 | destination CRCI << 7 | swap bits << 14: the CRCI goes in the destination field when `WriteToDevice`, in the source field otherwise;
   - each element of the list (16 bytes: address at +0x00, length at +0x08) is cut into commands of up to 0xFFFF rows of `burst` bytes; a length shorter than the burst gives one row of that length, and the remainder of a length that isn't a multiple of the burst goes into a next command:

     | Offset | Size | Comment |
     |--------|------|---------|
     | 0x00 | 4 | Command word; bit 31 (`CMD_LC`, last command) set on the last one |
     | 0x04 | 4 | Source row address: element address (`WriteToDevice`) or `DeviceAddress` |
     | 0x08 | 4 | Destination row address: `DeviceAddress` (`WriteToDevice`) or element address |
     | 0x0C | 4 | Source row length << 16 \| destination row length (both the row length) |
     | 0x10 | 4 | Source rows << 16 \| destination rows |
     | 0x14 | 4 | Row offsets: the memory side advances by the row length, the device side by 0 when a CRCI is used (FIFO), by the burst length of CRCI 0 otherwise |

     Without CRCI (memory to memory), `DeviceAddress` also advances after each command.
   - The common buffer starts with the pointer list entry written by [ReportCommonBuffer](#reportcommonbuffer-sub_401728-0x401728), and `CMD_PTR` gets the common buffer physical address >> 3. The command list isn't bounded by the 4 KB buffer (≈ 170 commands).
4. `DMB`, write of `CMD_PTR(ch)`, start time, transfer count + 1, channel marked active.

### ConfigureChannel (sub_4013F8, 0x4013F8)

`(ControllerContext, ChannelNumber, FunctionNumber, PVOID Context)`:

| Function | Context | Action |
|----------|---------|--------|
| 0 | `{ULONG RequestLine, ULONG BurstLength}` | Burst length of the request line's CRCI (≤ 0xFFF0, else `STATUS_INSUFFICIENT_RESOURCES`); the request line must be valid for the channel (as in ValidateRequestLineBinding), else `STATUS_INVALID_PARAMETER_MIX` (0xC0000030). Shared by every channel of the controller |
| 1 | `ULONG` | Destination swap bits of the box commands (bits 0-2: bytes, shorts, words) |
| 2 | `PHYSICAL_ADDRESS` | Command list given by the driver, 8-byte aligned (else `STATUS_INVALID_PARAMETER`); 0 goes back to box commands |
| 3 | `ULONG` | ≠ 0: flushes write 0x80000000 to `FLUSH0`, 0: they write 0 |
| other | | `STATUS_NOT_IMPLEMENTED` (0xC0000002) |

A NULL context gives `STATUS_INVALID_PARAMETER` (0xC000000D). The crypto drivers call functions 2, 0 (`{request line, 0x8000}`) and 1 (`3`): with a command list set, the burst length and the swap bits aren't used, their command entries carry their own swap and CRCI bits.

### FlushChannel (sub_4014DC, 0x4014DC)

`(ControllerContext, ChannelNumber)`: if a transfer is programmed (state 2), flush (`sub_401340`: if `STATUS(ch)` bit 26 is set, write the flush mode to `FLUSH0(ch)` and keep the flush time) and state 3. The result comes later through HandleInterrupt.

### HandleInterrupt (sub_401514, 0x401514)

`(ControllerContext, PULONG ChannelNumber, PDMA_INTERRUPT_TYPE InterruptType)`, returns a BOOLEAN:

1. `*ChannelNumber` = 0, `*InterruptType` = 1; FALSE if no channel is active.
2. If no source is pending (+0x17D8), reads `ISR` masked with the active channels; FALSE if nothing.
3. For each pending channel (lowest first), removed from the pending mask: skipped unless `STATUS(ch)` bit 1 (result valid) is set. Reads `RSLT(ch)`: bit 3 → type 1 (error), else bit 2 → type 2 (cancelled / flushed), else type 0 (completion). Keeps the result, the end time and the duration, advances the history index; for a type other than 0, reads `FLUSH0` … `FLUSH5` into the channel record.
4. State 2: state becomes 4 (error) or 1, the channel is no longer active, returns TRUE with the channel number. State 3 (flushing): state 1, no longer active, and it goes on with the next channel. Returns FALSE when no channel was in state 2.

### ReportCommonBuffer (sub_401728, 0x401728)

`(ControllerContext, ChannelNumber, PVOID VirtualAddress, PHYSICAL_ADDRESS LogicalAddress)`: the 4 KB common buffer allocated by the HAL holds the commands of the channel. Keeps both addresses, the command list address (virtual + 8) and the `CMD_PTR` value (physical >> 3), and writes the command pointer list entry at the start of the buffer: ((physical + 8) >> 3) | 0x80000000 (last pointer).

### CancelTransfer (sub_4013A0, 0x4013A0)

`(ControllerContext, ChannelNumber)`: if the context isn't one of the 2 kept by InitializeController, it uses the pointer at +0x28 instead (never written: the HAL always passes its own context ?). If a transfer is programmed (state 2): flush (as FlushChannel, but the state stays 2) and FALSE, the completion (type 2) being reported by HandleInterrupt; otherwise TRUE.
