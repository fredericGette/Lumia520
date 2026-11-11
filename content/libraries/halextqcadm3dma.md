## HalExtQcAdm3Dma.dll

HAL extension that exposes the Qualcomm ADM3 data mover ("DMOV") as a system DMA controller to the Windows HAL. This is an older build of [QCHalExtQcAdm3Dma.dll](./qchalextqcadm3dma.md): build `P:\ADM\Rel\5.0\Output\arm\Release\HalExtQcAdm3Dma.pdb`, version 1.0.1146.0000 (August 2012), where `QCHalExtQcAdm3Dma.dll` is ADM release 8.2.1.1, version 1.0.3058.0000 (March 2014). Both have the same `OriginalFilename` / `InternalName` (`HalExtQcAdm3Dma.dll`) and file description ("QUALCOMM ADM3 HAL Extension").  
The code is the same as the newer build, function by function: same entry point, same [HAL services](./qchalextq8x60bam.md#hal-services), same [AddResourceGroup](./qchalextqcadm3dma.md#addresourcegroup-sub_401770-0x401770), same [CSRT descriptor formats](./qchalextqcadm3dma.md#csrt-descriptors), initialization blocks, [controller context](./qchalextqcadm3dma.md#controller-context) and [DMA function table](./qchalextqcadm3dma.md#dma-function-table). The **only behavioural difference** is a dummy read of the channel's `STATUS` register that the newer build added at the start of ProgramChannel ([see below](#differences-with-qchalextqcadm3dmadll)). Everything described in the [QCHalExtQcAdm3Dma.dll](./qchalextqcadm3dma.md) page applies here; this page only gives the addresses of this build and the differences.  
It's loaded by [HAL.dll](./hal.md#hal-extensions) when the boot loader lists it as a HAL extension, for the CSRT resource group `QCOM` 0x1002 (the ADM at 0x18300000 on the Lumia 520, see [Lumia 520 CSRT](./qchalextqcadm3dma.md#lumia-520-csrt)), used by [qcearm8930.sys](../drivers/qcearm8930.md#dma), [qce2arm8930.sys](../drivers/qce2arm8930.md#dma) and [Qcuart8930.sys](../drivers/qcuart8930.md#dma). Which of the two builds the phone actually loads isn't known (both were extracted; the boot loader's list isn't in the analysed binaries).  
Sibling binaries (same folder): [HalExtQ8x60Bam.dll](./halextq8x60bam.md) (older build of [QCHalExtQ8x60Bam.dll](./qchalextq8x60bam.md)) and [HalExtQ8660Timers.dll](./halextq8660timers.md) (timers).

Location on the phone: `C:\Windows\System32\HalExtQcAdm3Dma.dll` ? (the extracted file has no notes).  

### Imports

None. The image has no import directory and doesn't link a CRT: `memcpy` (`_memcpy_decide` and its variants) and the `__rt_udiv` / `__rt_udiv64` / `__rt_sdiv64` helpers are statically linked, `__security_init_cookie` (`sub_409008`, in the `INIT` section) and `_GSHandlerCheck` / `__security_push_cookie` / `__security_pop_cookie` / `_gsfailure` are the `/GS` boilerplate.  
Everything else goes through the [HAL services table](./qchalextq8x60bam.md#hal-services) received at the entry point (entries +0x00, +0x04 and +0x0C, as in the newer build). No trace (no ETW, no WPP, no debug print), no string other than the PDB path.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| HAL ([HAL.dll](./hal.md)) | Entry point `start`, [HAL services table](./qchalextq8x60bam.md#hal-services) | The HAL loads the extension, enumerates the CSRT for it and calls the DMA function table |

No DLL is loaded at run time, no file or registry key is used.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| — | `start` (entry point) | 0x401A4C | `ULONG Reserved`, `PVOID *ExportTable` (out), `PVOID HalServices` (in) |

There's no export directory. `start` is identical to the newer build: `Reserved` ≠ 0 → 0xC00002B9; `__security_init_cookie`; HAL services table kept in `dword_407138`; `*ExportTable` = `off_404100` (a single pointer to `AddResourceGroup`, `sub_401764`); `dword_40713C` = 0; `STATUS_SUCCESS`.

### Functions

Same layout as the newer build: the functions before ProgramChannel are at the same addresses, the ones after it are 0xC bytes lower (ProgramChannel is 0x23E bytes here, 0x24C in the newer build). Global data is at the same addresses and has the same layout (`off_404100`, `/GS` cookie 0xBB40E64E / 0x44BF19B1, function table `off_40410C`, call counters `dword_404140`…`dword_40415C` and `dword_407120`…`dword_407128`, controller contexts being built `unk_404160` (2 × 0x17E0 bytes), descriptor copies `unk_407160`, controller table `dword_407140`).

| Function | This build | QCHalExtQcAdm3Dma.dll |
|----------|------------|-----------------------|
| [AddResourceGroup](./qchalextqcadm3dma.md#addresourcegroup-sub_401770-0x401770) | `sub_401764` | `sub_401770` |
| `RegisterResourceDescriptor` wrapper (services +0x00) | `sub_401A2C` | `sub_401A38` |
| `GetNextResourceDescriptor` wrapper (services +0x04) | `sub_401A00` | `sub_401A0C` |
| `HalMapIoSpace` wrapper (services +0x0C) | `sub_4019D4` | `sub_4019E0` |
| Flush a channel (`STATUS` bit 26 → write `FLUSH0`) | `sub_401334` | `sub_401340` |

[DMA function table](./qchalextqcadm3dma.md#dma-function-table) `off_40410C`:

| Index | Function | This build | QCHalExtQcAdm3Dma.dll |
|-------|----------|------------|-----------------------|
| 0 | [InitializeController](./qchalextqcadm3dma.md#initializecontroller-sub_401008-0x401008) | `sub_401008` | `sub_401008` |
| 1 | [ValidateRequestLineBinding](./qchalextqcadm3dma.md#validaterequestlinebinding-sub_401080-0x401080) | `sub_401080` | `sub_401080` |
| 2 | QueryMaxFragments (returns 20) | 0x4010D8 (not a function in the database) | 0x4010D8 |
| 3 | [ProgramChannel](./qchalextqcadm3dma.md#programchannel-sub_4010e4-0x4010e4) | `sub_4010E4` | `sub_4010E4` |
| 4 | [ConfigureChannel](./qchalextqcadm3dma.md#configurechannel-sub_4013f8-0x4013f8) | `sub_4013EC` | `sub_4013F8` |
| 5 | [FlushChannel](./qchalextqcadm3dma.md#flushchannel-sub_4014dc-0x4014dc) | `sub_4014D0` | `sub_4014DC` |
| 6 | [HandleInterrupt](./qchalextqcadm3dma.md#handleinterrupt-sub_401514-0x401514) | `sub_401508` | `sub_401514` |
| 7 | ReadDmaCounter | `sub_4016D0` | `sub_4016DC` |
| 8 | [ReportCommonBuffer](./qchalextqcadm3dma.md#reportcommonbuffer-sub_401728-0x401728) | `sub_40171C` | `sub_401728` |
| 9 | [CancelTransfer](./qchalextqcadm3dma.md#canceltransfer-sub_4013a0-0x4013a0) | `sub_401394` | `sub_4013A0` |

### Differences with QCHalExtQcAdm3Dma.dll

A comparison of the disassembly of every function (addresses of code and data normalised) shows only register allocation / instruction scheduling changes, and one added instruction sequence in ProgramChannel. Right after incrementing its call counter, the newer build does a `DSB` then reads `STATUS(ch)` (mapped base + 0x20A00 + 4 × channel, [ADM registers](./qchalextqcadm3dma.md#adm-registers)) and discards the value, before setting the channel state to 2 and building the commands. This build has the same `DSB` but no read.

The read has no effect on the extension's own state; reading the channel status before programming a new command pointer may be a workaround for the ADM hardware (making sure the previous result has been taken into account ?). In both builds `STATUS` is otherwise only read by the flush function, ReadDmaCounter and HandleInterrupt.

The version resource also differs: company "QUALCOMM Incorporated", product name "Snapdragon S4 Processor APQ8060A", "Copyright (C) 2012" here; "Qualcomm Technologies, Inc.", "Qualcomm Snapdragon", "Copyright (C) 2013" in the newer build.
