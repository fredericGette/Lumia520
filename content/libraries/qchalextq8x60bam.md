## QCHalExtQ8x60Bam.dll

HAL extension that exposes a Qualcomm BAM (Bus Access Manager, "SPS" DMA engine) as a system DMA controller to the Windows HAL, build `P:\BAM\rel\8.2.1.1\Output\arm\Release\HalExtQ8x60Bam.wp\HalExtQ8x60Bam.pdb`.  
It's a tiny kernel-mode image (33 functions, no import at all): the HAL gives it a table of services (CSRT enumeration, resource registration, I/O space mapping) at its entry point, and the extension returns its `AddResourceGroup` function. For each CSRT resource group it's matched with, `AddResourceGroup` reads the DMA controller and DMA channel descriptors and registers them with the HAL; the HAL then drives the BAM through the 10 functions of a [DMA function table](#dma-function-table) (initialize the controller, program a channel with a scatter/gather list, handle the interrupt, cancel…). Each DMA channel is a BAM pipe in system mode whose descriptor FIFO is the common buffer allocated by the HAL.  
It's the HAL-side counterpart of [qckmbam8930.sys](../drivers/qckmbam8930.md), which drives the BAMs of the ACPI namespace for kernel clients: the register programming is the same (reset, `BAM_CNFG_BITS`, pipe trust, pipe connect). Which BAM it drives depends on the CSRT of the firmware, which isn't in [content/acpi](../acpi/README.md); the 0x00900000 clock controller writes of the "type 2" controller suggest the BAM-DMA engine (`BAMDMA`, 0x12244000) ?. Its users are the drivers that get a system DMA adapter (`IoGetDmaAdapter`) for a request line served by this controller: unknown.  
Sibling binary: [QCHalExtQcAdm3Dma.dll](./qchalextqcadm3dma.md), the HAL extension of the ADM3 data mover, built from the same code (same entry point and HAL services).

Location on the phone: `C:\Windows\System32\QCHalExtQ8x60Bam.dll` ? (the extracted file has no notes).  

### Imports

None. The image has no import directory and doesn't even link a CRT: `memset` and `memcpy` are statically linked, `__security_init_cookie` (`sub_406008`, in the `INIT` section) and `_GSHandlerCheck` / `__security_push_cookie` / `__security_pop_cookie` are the `/GS` boilerplate (`__fastfail` on a cookie failure).  
Everything else goes through the [HAL services table](#hal-services) received at the entry point. There's no trace (no ETW, no WPP, no debug print).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| HAL ([HAL.dll](./hal.md)) | Entry point `start`, [HAL services table](#hal-services) | The HAL loads the extension, enumerates the CSRT for it and calls the [DMA function table](#dma-function-table) |

No DLL is loaded at run time, no file or registry key is used.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| — | `start` (entry point) | 0x401C30 | `ULONG Reserved` ?, `PVOID *ExportTable` (out), `PVOID HalServices` (in) |

There's no export directory: the only entry is the image entry point.

### Startup

`start` (0x401C30):
1. `Reserved` must be 0, otherwise it returns 0xC00002B9 (version check ?).
2. `__security_init_cookie` (`sub_406008`).
3. Keeps the HAL services table in `dword_404A0C`, sets `*ExportTable` = `off_404100`, clears `dword_404A10`, returns `STATUS_SUCCESS`.

`off_404100` holds a single function pointer, [AddResourceGroup](#addresourcegroup-sub_401944-0x401944) (`sub_401944`); the two following dwords are the `/GS` cookie and its complement (0xBB40E64E, 0x44BF19B1), and the [DMA function table](#dma-function-table) starts at `off_40410C`.

### HAL services

Table passed by the HAL to `start` (`dword_404A0C`): `HalExtensionServices` of [HAL.dll](./hal.md#hal-extension-services), where the whole table is described. Only the entries used here are listed.

| Offset | Wrapper | Function | Use |
|--------|---------|----------|-----|
| +0x00 | `sub_401C10` | `RegisterResourceDescriptor(Handle, ResourceGroup, ResourceDescriptor, Info)` | Registers a DMA controller (with its [initialization block](#dma-controller-initialization-block)) or a DMA channel (with its [initialization block](#dma-channel-initialization-block)) |
| +0x04 | `sub_401BE4` | `GetNextResourceDescriptor(Handle, ResourceGroup, Previous, Type, Subtype, Uid)` | Enumerates the descriptors of the resource group; always called with type, subtype and UID = 0xFFFF (any) |
| +0x0C | `sub_401BB8` | `HalMapIoSpace(PHYSICAL_ADDRESS, Size, MEMORY_CACHING_TYPE)` | Maps the BAM registers, the second register block of the controller and the clock controller, always `MmNonCached` (0) |
| +0x20 | (stub at 0x401BA4) | ? (a shared stub in the HAL) | Not called |

### AddResourceGroup (sub_401944, 0x401944)

Called by the HAL with `(Handle, ResourceGroup)` for each CSRT resource group handled by the extension. The controller being built is the global [controller context](#controller-context) `unk_404140` (0x8C8 bytes), cleared at the start.

1. Enumerates every descriptor of the group with `GetNextResourceDescriptor` (previous = NULL first, then the last one returned) and looks at the `Subtype` (USHORT at +0x06 of the CSRT descriptor header); the `Type` isn't checked.
2. Subtype 1 (DMA controller):
   - if a controller is already being built (its BAM physical address at +0x1C is not 0), it's registered first (step 4) and the context is cleared;
   - the descriptor is copied at the start of the context: 0x38 bytes if its `Length` is 0x38 (then the security entry count at +0x38 is set to 0), 0x5C bytes if it's 0x5C; other lengths aren't copied;
   - the [controller initialization block](#dma-controller-initialization-block) is filled. The controller id put in it starts at 3 and is incremented after each controller registered, but the HAL ignores it and writes its own id there (see the block below).
3. Subtype 0 (DMA channel): needs a controller (BAM address not 0) and a pipe number (+0x0C) < 32, otherwise `STATUS_INVALID_PARAMETER` (0xC000000D) is returned at once. The first 0x28 bytes of the descriptor are copied into the [channel slot](#channel-slot) of the pipe, its busy flag is cleared and its bit is cleared in the active mask (+0x8C0).
4. Other subtypes are ignored. At the end of the enumeration the last controller is registered: `RegisterResourceDescriptor` of the context (the descriptor copy) with the controller initialization block, then, for every channel slot whose `Length` isn't 0, `RegisterResourceDescriptor` of the slot with a [channel initialization block](#dma-channel-initialization-block). The results are ignored; the HAL keeps its own copy of the context (it's the `InternalData` of the controller) since the global one is cleared afterwards.

Returns `STATUS_SUCCESS`, or `STATUS_INVALID_PARAMETER` as above.

### CSRT descriptors

Format expected by `AddResourceGroup`. The first 12 bytes are the standard CSRT resource descriptor header.

DMA controller (subtype 1), 0x38 or 0x5C bytes:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `Length`: 0x38 (no security entries) or 0x5C |
| 0x04 | 2 | `Type` (not checked) |
| 0x06 | 2 | `Subtype`: 1 |
| 0x08 | 4 | `Uid` |
| 0x0C | 4 | Variant: 2 = clock and control block set up at [initialization](#initializecontroller-sub_401230-0x401230); 1 = channel function 0x10051000 of [ConfigureChannel](#configurechannel-sub_40170c-0x40170c) allowed. Other values: plain BAM ? |
| 0x10 | 8 | Physical address of a second register block (control block of the DMA engine ?), 0 if none |
| 0x18 | 4 | Size of the second register block |
| 0x1C | 8 | Physical address of the BAM registers |
| 0x24 | 4 | Size of the BAM registers |
| 0x28 | 4 | GSIV of the BAM interrupt |
| 0x2C | 4 | Execution environment (EE) of the application processor on the BAM |
| 0x30 | 4 | Minimum request line |
| 0x34 | 4 | Maximum request line |
| 0x38 | 4 | Number of security entries (0x5C format only) |
| 0x3C | 4 × 8 | Security entries `{PipeMask, Vmid}`, entry `i` for EE `i` (same as the ACPI method `SECC` of [qckmbam8930.sys](../drivers/qckmbam8930.md#acpi)) |

DMA channel (subtype 0), 0x28 bytes used:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `Length` |
| 0x04 | 2 | `Type` (not checked) |
| 0x06 | 2 | `Subtype`: 0 |
| 0x08 | 4 | `Uid` |
| 0x0C | 4 | Pipe number (< 32) |
| 0x10 | 4 | Direction, `P_CTRL` bit 3 |
| 0x14 | 4 | System mode, `P_CTRL` bit 5 |
| 0x18 | 4 | ? (not used) |
| 0x1C | 4 | Size of the descriptor FIFO in bytes (`P_FIFO_SIZES`), also the common buffer length asked to the HAL ? |
| 0x20 | 8 | ? (not used) |

A channel's request line is its pipe number plus the minimum request line of the controller (see [ValidateRequestLineBinding](#validaterequestlinebinding-sub_401408-0x401408)).

### DMA controller initialization block

0x44 bytes, built on the stack by `AddResourceGroup` and passed to `RegisterResourceDescriptor` with the controller descriptor. Field names with "?" follow the public `DMA_INITIALIZATION_BLOCK` of the Windows HAL extensions.

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 1 (version) |
| 0x04 | 4 | 0x44 (size) |
| 0x08 | 4 | Controller id: 3, 4, … set by the extension, overwritten by the HAL with its own sequential id (0, 1, 2… in registration order, [HalpRegisterDmaController](./hal.md#dma-controller-initialization-block)). The extension reads it back after `RegisterResourceDescriptor` for the channel blocks |
| 0x0C | 4 | 32: number of channels |
| 0x10 | 1 | 0: cache coherent ? |
| 0x14 | 4 | 32: DMA address width ? |
| 0x18 | 4 | 0x1F: supported port widths ? |
| 0x1C | 4 | 1 ? |
| 0x20 | 4 | Minimum request line (descriptor +0x30) |
| 0x24 | 4 | Maximum request line (descriptor +0x34) |
| 0x28 | 1 | 1: generates interrupt |
| 0x2C | 4 | GSIV (descriptor +0x28) |
| 0x30 | 4 | 0: interrupt polarity ? |
| 0x34 | 4 | 0: interrupt mode ? |
| 0x38 | 4 | Internal data: the [controller context](#controller-context) |
| 0x3C | 4 | 0x8C8: size of the internal data |
| 0x40 | 4 | `off_40410C`: [DMA function table](#dma-function-table) |

### DMA channel initialization block

0x24 bytes, passed with the channel slot (the copy of the channel descriptor).

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 1 (version) |
| 0x04 | 4 | 0x24 (size) |
| 0x08 | 4 | Controller id: the one written by the HAL in the controller block |
| 0x0C | 1 | 0: generates interrupt ? |
| 0x10 | 4 | 0: GSIV ? |
| 0x14 | 8 | 0 ? |
| 0x1C | 4 | Descriptor FIFO size (channel descriptor +0x1C): common buffer length ? |
| 0x20 | 4 | Channel number (= pipe slot index) |

### Controller context

0x8C8 bytes (`unk_404140` while it's built, then the HAL's copy, passed as first parameter of every function of the DMA function table).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 0x5C | Copy of the [controller descriptor](#csrt-descriptors) |
| 0x60 | 4 | Virtual address of the BAM registers (mapped at the first initialization) |
| 0x70 | 4 | Virtual address of the second register block |
| 0x7C | 4 | `BAM_NUM_PIPES` bits 0-7: number of pipes |
| 0x80 | 4 | `BAM_REVISION` bits 0-7: revision |
| 0x84 | 4 | `BAM_REVISION` bits 8-11: number of EEs |
| 0x88 | 4 | `BAM_REVISION` bit 16 |
| 0x8C | 4 | `BAM_REVISION` bits 24-31 |
| 0x90 | 4 | `BAM_REVISION` bit 19 |
| 0x94 | 4 | `BAM_REVISION` bit 18 |
| 0x98 | 4 | `BAM_REVISION` bit 17 |
| 0x9C | 4 | IRQ sources read and not handled yet (one bit per pipe) |
| 0xA0 | 32 × 65 | [Channel slots](#channel-slot), one per pipe, packed (65-byte stride) |
| 0x8C0 | 4 | Active channels: a transfer is programmed and not completed |

The layout of +0x7C … +0x98 is the BAM configuration table of [qckmbam8930.sys](../drivers/qckmbam8930.md) (+0x14 … +0x30 of its device context).

### Channel slot

65 bytes per pipe at +0xA0 + 65 × pipe of the controller context (unaligned fields).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 0x28 | Copy of the [channel descriptor](#csrt-descriptors); `Length` ≠ 0 = channel present. +0x10 direction, +0x14 system mode, +0x1C descriptor FIFO size |
| 0x28 | 8 | Physical address of the descriptor FIFO (from [ReportCommonBuffer](#reportcommonbuffer-sub_4018cc-0x4018cc)) |
| 0x30 | 1 | Busy: a transfer was programmed |
| 0x31 | 4 | Virtual address of the descriptor FIFO |
| 0x35 | 4 | Write offset in the descriptor FIFO |
| 0x39 | 4 | Last `P_SW_OFSTS` read at the interrupt: offset of the last descriptor processed by the BAM |
| 0x3D | 4 | Bytes remaining (set by [ConfigureChannel](#configurechannel-sub_40170c-0x40170c) 0x10051000, decremented by each descriptor queued) |

### DMA function table

`off_40410C`, given to the HAL in the controller initialization block. The order is the one of the Windows `DMA_FUNCTION_TABLE`.

| Index | Function | Address |
|-------|----------|---------|
| 0 | [InitializeController](#initializecontroller-sub_401230-0x401230) | `sub_401230` |
| 1 | [ValidateRequestLineBinding](#validaterequestlinebinding-sub_401408-0x401408) | `sub_401408` |
| 2 | [QueryMaxFragments](#querymaxfragments-0x401444) | 0x401444 (not a function in the database) |
| 3 | [ProgramChannel](#programchannel-sub_401488-0x401488) | `sub_401488` |
| 4 | [ConfigureChannel](#configurechannel-sub_40170c-0x40170c) | `sub_40170C` |
| 5 | [FlushChannel](#flushchannel-sub_40174c-0x40174c) | `sub_40174C` |
| 6 | [HandleInterrupt](#handleinterrupt-sub_4017a8-0x4017a8) | `sub_4017A8` |
| 7 | ReadDmaCounter | `sub_4018C0`: always returns 0 |
| 8 | [ReportCommonBuffer](#reportcommonbuffer-sub_4018cc-0x4018cc) | `sub_4018CC` |
| 9 | [CancelTransfer](#canceltransfer-sub_401598-0x401598) | `sub_401598` |

All the register accesses are surrounded by `DSB` barriers. Most functions first test `BAM_EN` (`BAM_CTRL` bit 1) and call `InitializeController` again when it's clear (the BAM lost its state, e.g. after a power collapse ?).

### InitializeController (sub_401230, 0x401230)

`(PVOID ControllerContext)`:

1. Adds the context to the table `dword_404A20` (8 entries, first free slot; not read anywhere else).
2. Maps the BAM registers (+0x1C, size +0x24) into +0x60 and, if its address isn't 0, the second register block (+0x10, size +0x18) into +0x70, the first time only.
3. Variant 2 (+0x0C): maps the clock controller at 0x00900000 (0x3000 bytes, once, `dword_404A08`) and writes 0x10 (branch clock enable ?) at its offsets 0x25C0, 0x25A0 and 0x2564; then writes 1 at +0x00 and 0x131 at +0x04 of the second register block.
4. BAM reset, same values as [qckmbam8930.sys](../drivers/qckmbam8930.md):

   | Register | Offset | Write |
   |----------|--------|-------|
   | `BAM_CTRL` | 0xF80 | Set `BAM_SW_RST` (bit 0), clear it, then set `BAM_EN` (bit 1) |
   | `BAM_DESC_CNT_TRSHLD` | 0xF88 | 0x2000 |
   | `BAM_CNFG_BITS` | 0xFFC | 0x07FFF004 |
   | `BAM_IRQ_SRCS_MSK` (EE 0) or `BAM_IRQ_SRCS_MSK_EE(n)` (0x1804 + 0x80 × n) | 0xF90 | Set bit 31 (BAM interrupt) |
   | `BAM_IRQ_EN` | 0xF9C | 6 |

5. If `BAM_EN` reads back as set: reads `BAM_NUM_PIPES` and `BAM_REVISION` into +0x7C (`sub_4010C0`); if the BAM has EEs and the descriptor has security entries, applies each entry `i` (`sub_401008`): if the revision is 3…31, every pipe of `PipeMask` gets `P_TRUST_REG` EE = `i` (bits 0-1) and VMID (bits 8-12), and if bit 31 of the mask is set `BAM_TRUST_REG` (0xFF0) gets them too and its bit 7 cleared. Unlike the driver, this is done at every initialization.
6. Connects again every present channel (`sub_401134`, see below).

Pipe connection `sub_401134(ControllerContext, Pipe)`:
1. `P_RST` (0x04 + 0x80 × n) = 1 then 0.
2. Sets the pipe bit in `BAM_IRQ_SRCS_MSK` or `BAM_IRQ_SRCS_MSK_EE(n)`.
3. `P_IRQ_EN` (0x18 + 0x80 × n) = 0x31 (bits 0, 4 and 5).
4. `P_CTRL` bit 3 = direction, bit 5 = system mode.
5. If the descriptor FIFO is known: `P_DESC_FIFO_ADDR` (0x101C + 0x40 × n) and `P_FIFO_SIZES` bits 0-15 (0x1020 + 0x40 × n).
6. Sets `P_EN` (`P_CTRL` bit 1), and clears the write offset, the last processed offset, the remaining bytes and the busy flag.

### ValidateRequestLineBinding (sub_401408, 0x401408)

`(ControllerContext, {RequestLine, ChannelNumber})`: TRUE if the request line is between the minimum and maximum of the controller, `RequestLine - Minimum == ChannelNumber` and the channel is present. A device can only use the channel whose pipe number is its request line minus the minimum.

### QueryMaxFragments (0x401444)

`(ControllerContext, ChannelNumber, …)`: 1 if the channel is active; otherwise the number of free descriptors (8 bytes each) between the write offset and the last processed offset, modulo the FIFO size.

### ProgramChannel (sub_401488, 0x401488)

`(ControllerContext, ChannelNumber, RequestLine, PDMA_SCATTER_GATHER_LIST, DeviceAddress, WriteToDevice, LoopTransfer)`; only the channel and the list are used (the direction is fixed by the pipe):

1. Initializes the controller again if `BAM_EN` is clear.
2. Marks the channel busy and active.
3. For each element of the list (16 bytes: 32-bit address at +0x00, length at +0x08), writes 8-byte BAM descriptors into the descriptor FIFO, at most 0x6000 bytes each:

   | Offset | Size | Comment |
   |--------|------|---------|
   | 0x00 | 4 | Physical address |
   | 0x04 | 2 | Size in bytes |
   | 0x06 | 2 | Flags: 0, except the last descriptor: 0xC000 (`INT` \| `EOT`) if no byte count was set with ConfigureChannel or it has reached 0, else 0x8000 (`INT`) |

   The write offset wraps at the FIFO size; the remaining-bytes count (if not 0) is decremented by each descriptor.
4. `DMB`, then writes the new write offset into `P_EVNT_REG` bits 0-15 (0x1018 + 0x40 × n).

### ConfigureChannel (sub_40170C, 0x40170C)

`(ControllerContext, ChannelNumber, FunctionNumber, Context)`:

| Function | Action |
|----------|--------|
| 0x10011000 | `InitializeController`, returns `STATUS_SUCCESS` |
| 0x10051000 | `sub_40162C`, see below |
| other | `STATUS_NOT_IMPLEMENTED` (0xC0000002) |

`sub_40162C` initializes the controller if needed, then returns `STATUS_INVALID_PARAMETER` (0xC000000D) unless the controller variant is 1, the first dword of the context is 16 and not (byte +0x0C = 1 and the pipe direction ≠ 0). Context (16 bytes):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | 16 (size) |
| 0x04 | 4 | Value written at +0x24 of the second register block (receive direction) |
| 0x08 | 4 | Total byte count: kept as the channel's remaining bytes, written at +0x28 of the second block (receive direction) |
| 0x0C | 1 | 1 = only allowed on a direction-0 pipe |

Then it writes 1 at +0x08 of the second register block and:
- direction 1: +0x1C = pipe & 0xF, +0x00 = 0x31, +0x14 = 0x1000, +0x24 and +0x28 from the context, +0x0C = 1;
- direction 0: +0x1C = (pipe & 0xF) << 16, +0x00 = 0x14, +0x18 = 0x1000, +0x10 = 1.

The meaning of these registers (the peripheral at the other end of the pipe) is unknown.

### FlushChannel (sub_40174C, 0x40174C)

`(ControllerContext, ChannelNumber)`: initializes the controller again if `BAM_EN` is clear; otherwise, for a present channel, connects the pipe again (`sub_401134`: `P_RST`, which drops the queued descriptors) and clears its active bit.

### HandleInterrupt (sub_4017A8, 0x4017A8)

`(ControllerContext, PULONG ChannelNumber, PDMA_INTERRUPT_TYPE InterruptType)`, returns a BOOLEAN:

1. `*ChannelNumber` = 0, `*InterruptType` = 1; FALSE if `BAM_EN` is clear.
2. If no source is pending in +0x9C, reads `BAM_IRQ_SRCS_EE(n)` (0x1800 + 0x80 × n) or, for EE 0, `BAM_IRQ_SRCS` (0xF8C) masked with the active channels and written to `BAM_IRQ_CLR` (0xF98); FALSE if nothing.
3. Takes the lowest pending pipe, removes it from +0x9C, reads `P_IRQ_STTS` (0x10 + 0x80 × n) and writes it to `P_IRQ_CLR` (0x14 + 0x80 × n). Bit 0 or 5 (descriptor processed / transfer end) → type 0 (completion); bit 4 → type 1 (error); in both cases `P_SW_OFSTS` bits 0-15 (0x1000 + 0x40 × n) is read.
4. If the channel is busy and active, keeps the processed offset, clears busy and active, and returns TRUE with the channel number. Otherwise it goes on with the next pending pipe, and returns FALSE at the end.

### ReportCommonBuffer (sub_4018CC, 0x4018CC)

`(ControllerContext, ChannelNumber, PVOID VirtualAddress, PHYSICAL_ADDRESS LogicalAddress)`: the common buffer allocated by the HAL becomes the descriptor FIFO of the pipe. Keeps both addresses in the channel slot, then (or after a new initialization if `BAM_EN` is clear) writes `P_DESC_FIFO_ADDR` and `P_FIFO_SIZES`.

### CancelTransfer (sub_401598, 0x401598)

`(ControllerContext, ChannelNumber)`: for a busy channel that is no longer in the active mask, reads the IRQ sources into +0x9C (`BAM_IRQ_SRCS_EE(n)`, or for EE 0 `BAM_IRQ_SRCS` & 6 written to `BAM_IRQ_CLR`); if the pipe has a pending interrupt it returns FALSE (the completion will be reported by HandleInterrupt), otherwise it resets the pipe (`sub_401134`) and clears its active bit. If `BAM_EN` is clear, the controller is initialized again. Returns TRUE in the other cases.
