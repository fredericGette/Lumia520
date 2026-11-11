## HalExtQ8x60Bam.dll

HAL extension that exposes a Qualcomm BAM (Bus Access Manager, "SPS" DMA engine) as a system DMA controller to the Windows HAL. This is an older build of [QCHalExtQ8x60Bam.dll](./qchalextq8x60bam.md): build `P:\BAM\Rel\5.0\Output\arm\Release\HalExtQ8x60Bam.wa\HalExtQ8x60Bam.pdb`, version 1.0.1146.2400 (timestamp November 2012), where `QCHalExtQ8x60Bam.dll` is BAM release 8.2.1.1, version 1.0.3058.0000 (March 2014). Both have the same `OriginalFilename` (`HalExtQ8x60Bam.dll`) and file description ("QUALCOMM Bus Access Modules HAL Extension").  
The code is the same as the newer build, function by function: same entry point, same [HAL services](./qchalextq8x60bam.md#hal-services), same `AddResourceGroup`, same CSRT descriptor formats, initialization blocks, controller context and [DMA function table](./qchalextq8x60bam.md#dma-function-table). The **only behavioural difference** is the width of three register reads ([see below](#differences-with-qchalextq8x60bamdll)). Everything described in the [QCHalExtQ8x60Bam.dll](./qchalextq8x60bam.md) page applies here; this page only gives the addresses of this build and the differences.  
It's loaded by [HAL.dll](./hal.md#hal-extensions) when the boot loader lists it as a HAL extension, for the CSRT resource group `QCOM` 0x1005 (the BAMs of the 5 SD controllers on the Lumia 520, see [Lumia 520 CSRT](./qchalextq8x60bam.md#lumia-520-csrt)). Which of the two builds the phone actually loads isn't known (both were extracted; the boot loader's list isn't in the analysed binaries).  
Sibling binaries (same folder): [HalExtQcAdm3Dma.dll](./halextqcadm3dma.md) (older build of [QCHalExtQcAdm3Dma.dll](./qchalextqcadm3dma.md)) and [HalExtQ8660Timers.dll](./halextq8660timers.md) (timers).

Location on the phone: `C:\Windows\System32\HalExtQ8x60Bam.dll` ? (the extracted file has no notes).  

### Imports

None. The image has no import directory and doesn't link a CRT: `memset` and `memcpy` (`_memcpy_forward_new`…) are statically linked, `__security_init_cookie` (`sub_406008`, in the `INIT` section) and `_GSHandlerCheck` / `__security_push_cookie` / `__security_pop_cookie` / `_gsfailure` are the `/GS` boilerplate.  
Everything else goes through the [HAL services table](./qchalextq8x60bam.md#hal-services) received at the entry point. No trace (no ETW, no WPP, no debug print), no string other than the PDB path.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| HAL ([HAL.dll](./hal.md)) | Entry point `start`, [HAL services table](./qchalextq8x60bam.md#hal-services) | The HAL loads the extension, enumerates the CSRT for it and calls the DMA function table |

No DLL is loaded at run time, no file or registry key is used.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| — | `start` (entry point) | 0x401C38 | `ULONG Reserved`, `PVOID *ExportTable` (out), `PVOID HalServices` (in) |

There's no export directory. `start` is identical to the newer build: `Reserved` ≠ 0 → 0xC00002B9; `__security_init_cookie`; HAL services table kept in `dword_404A0C`; `*ExportTable` = `off_404100` (a single pointer to `AddResourceGroup`, `sub_40194C`); `dword_404A10` = 0; `STATUS_SUCCESS`.

### Functions

Same layout as the newer build, mostly shifted by 4 bytes. Global data is at the same addresses (`off_404100`, `/GS` cookie 0xBB40E64E / 0x44BF19B1, function table `off_40410C`, controller context being built `unk_404140` (0x8C8 bytes), controller table `dword_404A20`, clock controller mapping `dword_404A08`).

| Function | This build | QCHalExtQ8x60Bam.dll |
|----------|------------|----------------------|
| [AddResourceGroup](./qchalextq8x60bam.md#addresourcegroup-sub_401944-0x401944) | `sub_40194C` | `sub_401944` |
| `RegisterResourceDescriptor` wrapper (services +0x00) | `sub_401C18` | `sub_401C10` |
| `GetNextResourceDescriptor` wrapper (services +0x04) | `sub_401BEC` | `sub_401BE4` |
| `HalMapIoSpace` wrapper (services +0x0C) | `sub_401BC0` | `sub_401BB8` |
| Apply a security entry (`P_TRUST_REG` / `BAM_TRUST_REG`) | `sub_401008` | `sub_401008` |
| Read `BAM_NUM_PIPES` / `BAM_REVISION` | `sub_4010C0` | `sub_4010C0` |
| Pipe connection (`P_RST`, `P_IRQ_EN`, `P_CTRL`, descriptor FIFO) | `sub_401130` | `sub_401134` |
| Channel function 0x10051000 of ConfigureChannel | `sub_401630` | `sub_40162C` |

[DMA function table](./qchalextq8x60bam.md#dma-function-table) `off_40410C`:

| Index | Function | This build | QCHalExtQ8x60Bam.dll |
|-------|----------|------------|----------------------|
| 0 | [InitializeController](./qchalextq8x60bam.md#initializecontroller-sub_401230-0x401230) | `sub_40122C` | `sub_401230` |
| 1 | [ValidateRequestLineBinding](./qchalextq8x60bam.md#validaterequestlinebinding-sub_401408-0x401408) | `sub_401404` | `sub_401408` |
| 2 | [QueryMaxFragments](./qchalextq8x60bam.md#querymaxfragments-0x401444) | `sub_401440` | 0x401444 |
| 3 | [ProgramChannel](./qchalextq8x60bam.md#programchannel-sub_401488-0x401488) | `sub_401484` | `sub_401488` |
| 4 | [ConfigureChannel](./qchalextq8x60bam.md#configurechannel-sub_40170c-0x40170c) | `sub_401710` | `sub_40170C` |
| 5 | [FlushChannel](./qchalextq8x60bam.md#flushchannel-sub_40174c-0x40174c) | `sub_401750` | `sub_40174C` |
| 6 | [HandleInterrupt](./qchalextq8x60bam.md#handleinterrupt-sub_4017a8-0x4017a8) | `sub_4017AC` | `sub_4017A8` |
| 7 | ReadDmaCounter (returns 0) | 0x4018C8 (not a function in the database) | `sub_4018C0` |
| 8 | [ReportCommonBuffer](./qchalextq8x60bam.md#reportcommonbuffer-sub_4018cc-0x4018cc) | `sub_4018D4` | `sub_4018CC` |
| 9 | [CancelTransfer](./qchalextq8x60bam.md#canceltransfer-sub_401598-0x401598) | `sub_401594` | `sub_401598` |

### Differences with QCHalExtQ8x60Bam.dll

The two `.text` sections have the same size (0x1458 bytes). A comparison of the decompilation and disassembly of every function shows only instruction scheduling / register allocation changes, branch offsets, and these three register reads, done with a narrow load in this build and with a 32-bit load followed by a zero-extension in the newer one:

| Register | Offset | Read by | This build | QCHalExtQ8x60Bam.dll |
|----------|--------|---------|------------|----------------------|
| `BAM_NUM_PIPES` | 0xFBC | `sub_4010C0` (number of pipes → context +0x7C) | `LDRB` (8-bit) | `LDR` + `UXTB` |
| `BAM_REVISION` | 0xF84 | `sub_4010C0` (revision bits 0-7 → context +0x80) | `LDRB` (8-bit) | `LDR` + `UXTB` |
| `P_SW_OFSTS` | 0x1000 + 0x40 × n | HandleInterrupt (offset of the last descriptor processed) | `LDRH` (16-bit) | `LDR` + `UXTH` |

The values obtained are the same; the newer build only avoids sub-word accesses to the BAM registers (which the BAM bus may not support, or not on every SoC ?). The other fields of `BAM_REVISION` were already read with 32-bit loads in both builds.

The version resource also differs: product name "QUALCOMM Windows on Snapdragon" here, "Qualcomm Snapdragon" in the newer build; copyright without year here, "Copyright (C) 2013" in the newer one.
