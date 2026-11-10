## Dumpsd.sys

SD / eMMC crash dump port driver (Microsoft, `dumpsd.pdb`).  
It is the _dump port driver_ of the SD bus stack (`sdbus.sys`): it isn't started as a service, [crashdmp.sys](./crashdmp.md) loads a private copy of it in the dump stack (`dump_` prefix for the crash dump, `hiber_` for the hibernation ?) and calls its `DriverEntry` with a `DUMP_INITIALIZATION_CONTEXT`. After a bugcheck (or to write / read the hibernation file) it drives the SD host controller of the boot eMMC **directly**, by polling, without interrupts, DPCs or the normal `sdbus.sys` / `sdstor.sys` stack.  
It contains a stripped-down copy of the `sdbus.sys` code: the work packet engine (`SdbusXxxWorker`), the command engine, and two host controller back-ends: standard SDHCI (`SdhcXxx`) and the Qualcomm MSM SDCC controller (`PlXxx`, traces `QC_SDHC[...]`), which is the one used on the Lumia 520 (MSM8930).  
The state of the controller and of the card (`sdbus.sys` FDO/socket extension, 16704 bytes) is given by `sdbus.sys` through the `PortConfiguration` field of the dump context; dumpsd.sys only re-initialises the hardware with it.  

There's no device name and no symbolic link. It doesn't process any IOCTL and doesn't send any.  
There's no parameters in the registry (the timeouts are copied from the `sdbus.sys` context, see below).  
Imports: `ntoskrnl.exe` (`MmMapIoSpace`, `MmGetPhysicalAddress`, `PoSetHiberRange`, `KeBugCheckEx`, …), [HAL.dll](../libraries/hal.md) (`HalDmaAllocateCrashDumpRegistersEx`, `HalDmaFreeCrashDumpRegistersEx`, `KeStallExecutionProcessor`, `KeQueryPerformanceCounter`).  
No ETW provider is registered: the ETW templates inherited from `sdbus.sys` (`Template_xx`, …) call `EtwWrite` with a null `REGHANDLE`, so they do nothing.  
Debug output: `SdbusDebugPrint` (`DbgPrintEx`, component id 77 = `DPFLTR_SD_ID` ?) and `_SdDumpDebugPrint` (prefix `DUMPSD: `, only if `g_EnableDbgPrint` ≠ 0; it is 0 and never written).  
Some code paths of `sdbus.sys` are still present but not reachable in dump mode (PoFx, `IoInvalidateDeviceRelations`, `PdcScenarioClientRequest`).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| — (hardware) | | SD controller of the eMMC (`\_SB.SDC1`, `QCOM7002`, physical 0x12400000), registers mapped by `SdhcStartSocket` |
| — (hardware) | | Clock controller (GCC), physical 0x00900000 (hardcoded), mapped by `PlResetHost` |

### Initialisation

`DriverEntry` (0x119A8, via `GsDriverEntry`) is called by [crashdmp.sys](./crashdmp.md) with a `DUMP_INITIALIZATION_CONTEXT *` as second parameter.

`DUMP_INITIALIZATION_CONTEXT` (ARM 32-bit offsets used):  
| Offset | Direction | Comment |
|--------|-----------|---------|
| 0x00 | in | `Length` of the structure: ≥ 0xBC → `GetTransferSizesRoutine` filled, ≥ 0xC0 → `DumpNotifyRoutine` filled |
| 0x0C, 0x10 | in | `CommonBuffer[0..1]` (kept in `g_DumpExtension` + 4…) |
| 0x18-0x27 | in | `PhysicalAddress[0..1]` of the common buffers |
| 0x28 | in | `StallRoutine` |
| 0x2C | out | `OpenRoutine` = `SdDumpOpen` (0x11BA8) |
| 0x30 | out | `WriteRoutine` = `SdDumpWrite` (0x11CC8) |
| 0x34 | out | `FinishRoutine` = `SdDumpFinish` (0x11D48) |
| 0x40 | in | `PortConfiguration`: pointer to the `sdbus.sys` context (see below) |
| 0x44 | in | `CrashDump` (BOOLEAN): TRUE = crash dump, FALSE = hibernation |
| 0x45 | in | `MarkMemoryOnly` (BOOLEAN) |
| 0x48 | out | `MaximumTransferSize` = context + 0x1308 |
| 0x4C | in | `CommonBufferSize` |
| 0x54 | out | `WritePendingRoutine` = `SdDumpWritePending` (0x11CE0) |
| 0x6C | out | `ReadRoutine` = `SdDumpRead` (0x11C60) |
| 0xB8 | out | `GetTransferSizesRoutine` = `SdDumpGetTransferSizes` (0x11DA8) |
| 0xBC | out | `DumpNotifyRoutine` = `SdDumpNotify` (0x11DCC) |

Steps:
1. `PoSetHiberRange(PO_MEM_BOOT_PHASE)` on the `sdbus.sys` context (16704 bytes) and on its DMA buffer (pointer at context + 0x1DC, size at + 0x1D8), so they are kept in the hibernation image.
2. Copies the timeouts of the context in its globals: `PollTimerInterval` (+0x4108), `SdMemCardInitTimeout` (+0x410C), `SdIoCardInitTimeout` (+0x4110), `SdCommandTimeout` (+0x4114), `SdTransferTimeout` (+0x4118).
3. If the DMA mode of the socket (+0x174) is 3 or 4 (system DMA ?), allocates the crash dump map registers with `HalDmaAllocateCrashDumpRegistersEx` (number of pages of `MaximumTransferSize`). A failure → `KeBugCheckEx(0x2C PORT_DRIVER_INTERNAL, 0x80000002, status, pages, 0)`.

`sdbus.sys` context (`g_DumpExtension`, offsets used by dumpsd.sys):  
| Offset | Comment |
|--------|---------|
| 0x0008 | Socket extension (`v2` in the code) |
| 0x000C | → FDO extension: +0x10 index in `SocFunctionBlocks`, +0x14 host function table, +0x2D controller vendor/type (byte), +0x2E sub-type |
| 0x0114 | (socket + 0x10C) virtual address of the host registers |
| 0x0174 | DMA mode (3, 4 → crash dump map registers) |
| 0x0178, 0x0180 | DMA adapter |
| 0x01D8, 0x01DC | Size and address of the DMA buffer |
| 0x01F8 | Work packet engine state |
| 0x0DC8 | (socket + 0xDC0) Card is block addressed (high capacity): the byte offset is divided by 512 |
| 0x1308 | Maximum transfer size |
| 0x40B0 | Work packet used by the dump |
| 0x4108-0x4118 | Timeouts (see above) |

### Dump callbacks

- `SdDumpOpen` (0x11BA8) (`LARGE_INTEGER PartitionOffset`): keeps the partition offset (`qword_2A728`, added to every offset), selects the host function table `SocFunctionBlocks[type]` (0 = `SdhcSupportFns`, 1 = `QcSupportFns`), patches its retuning callback (type 10 → `SdhcQcExecuteRetuning`, type 6/1 → `SdhcNvT40ExecuteRetuning`), calls `InitializeSocket` then `_SdDumpResetHostAndCard`. Returns TRUE on success.
- `SdDumpWrite` (0x11CC8) (offset, MDL) = `SdDumpWritePending(0, offset, MDL)`.
- `SdDumpWritePending` (0x11CE0) / `SdDumpRead` (0x11C60) (action, offset, MDL): action 0 = synchronous (`_SdDumpReadWriteRequestSync`), 1 = start, 2 = poll (returns `STATUS_PENDING` 0x103 while the transfer runs), 3 = finish of an asynchronous request (`_SdDumpReadWriteRequestAsync`).
- `SdDumpFinish` (0x11D48): waits 2 s (`KeStallExecutionProcessor(2000000)`), frees the crash dump map registers (crash dump only).
- `SdDumpGetTransferSizes` (0x11DA8): minimum 512 bytes, maximum = context + 0x1308.
- `SdDumpNotify` (0x11DCC): notification 2 → frees the crash dump map registers (hibernation, or `MarkMemoryOnly`).

Read / write (`_SdDumpInitializeReadWriteRequest`, 0x125D4): builds a `SDWP_DATA_COMMAND` (19) work packet with the command descriptor:  
| Command | Size | Comment |
|---------|------|---------|
| CMD17 READ_SINGLE_BLOCK | 512 bytes | descriptor `unk_281C0` |
| CMD18 READ_MULTIPLE_BLOCK | other | `unk_281D4` |
| CMD24 WRITE_BLOCK | 512 bytes | `unk_28198` |
| CMD25 WRITE_MULTIPLE_BLOCK | other | `unk_281AC` |

The argument is the byte offset, or the sector number for a block-addressed card. The work packet is run by polling (`_SdDumpProcessBusRequest`, `_SdDumpBusWorker`, `_SdDumpPollEventUntilChange…`).  
Up to 3 tries per request; after the 2nd failure the host and the card are reset (`_SdDumpResetHostAndCard`). Statistics counters: reads failed `dword_2A74C`, writes failed `dword_2A750`, resets `dword_2A754`, failed resets `dword_2A758`.

### Reset of the host and of the card

`_SdDumpResetHostAndCard` (0x12A04) runs the work packet sequences below, up to 5 times (50 ms between tries). Phase 2 uses the HS200 list if the card is in HS200 mode (socket + 0x12AD).  

| Step | `g_wfBringHardwareUp` | `g_wfBringHardwareUpPhase2_Default` | `g_wfBringHardwareUpPhase2_HS200` |
|------|-----------------------|-------------------------------------|-----------------------------------|
| 1 | SDWP_SOCKET_RESET | SDWP_SOCKET_RESET | SDWP_SOCKET_RESET |
| 2 | SDWP_POWER_ON_AND_VERIFY | SDWP_POWER_ON | SDWP_POWER_ON |
| 3 | SDWP_INIT_BUS_CLOCK | SDWP_INIT_BUS_CLOCK | SDWP_INIT_BUS_CLOCK |
| 4 | SDWP_INITIALIZE_CARD_AND_VERIFY | SDWP_INITIALIZE_CARD | SDWP_INITIALIZE_CARD |
| 5 | SDWP_SELECT_CARD | SDWP_SELECT_CARD | SDWP_SELECT_CARD |
| 6 | 51 (`SdbusMmcSetWriteGroupDef`) | 51 | 51 |
| 7 | SDWP_DETECT_BUS_WIDTH | SDWP_REFLECT_HIGH_SPEED | SDWP_REFLECT_BUS_WIDTH |
| 8 | SDWP_DETECT_HIGH_SPEED | SDWP_REFLECT_BUS_CLOCK | SDWP_REFLECT_HIGH_SPEED |
| 9 | SDWP_REFLECT_HIGH_SPEED | SDWP_REFLECT_BUS_WIDTH | SDWP_REFLECT_BUS_CLOCK |
| 10 | SDWP_INIT_BUS_CLOCK | SDWP_REFLECT_FUNCTION_BLOCKLEN | SDWP_REFLECT_FUNCTION_BLOCKLEN |
| 11 | SDWP_DESELECT_CARD | SDWP_START_FUNCTION | SDWP_START_FUNCTION |
| 12 | SDWP_DETECT_FRENQUENCY | SDWP_ENABLE_FUNCTION_INT | SDWP_ENABLE_FUNCTION_INT |
| 13 | SDWP_POWER_OFF | | |

Work packet types (`SdbusGetMiniprocRoutine`, 0x18A94, names from `SdbusDbgWPFunctionStringMap`): 1 stop socket, 2 socket reset, 3-5 power, 6 activate socket, 7-8 card data, 9 read device config (CID/CSD), 10 detect frequency, 11 detect bus width, 12-13 initialize card, 14-15 select/deselect, 16-17 start/stop function, 18 basic command, 19 data command, 20 erase, 21 card interrupts, 22-27 bus clock, 28-30 bus width, 31-32 high speed, 33-36 function interrupt, 37-42 block length, 43-44 bus interface control, 45 SDIO reset, 46 MMC sleep, 47 MMC wake, 48-49 arm wake interrupt, 50 MMC soft reset, 51 MMC set write group (?), 52-53 check / enable the write cache, 54 `PlArmWakeInterrupt`.

### Qualcomm SDCC controller (`QcSupportFns`)

Host function table at `.data:0x2A3C8` (`SdhcStartController`, `SdhcStartSocket`, `PlInitializeSocket`, `PlResetHost`, `PlSetClock`, `PlSendCommand`, `PlStartTransfer`, `PlGetPendingEvents`, …). The interrupt mask isn't changed in crash dump mode (`PlSetEventMask: ignored in crash dump mode`).

`SdhcStartSocket` (0x13418) maps the memory resource of the controller (the 1st `CmResourceTypeMemory` of the socket) with `MmMapIoSpace`. On the Lumia 520 the eMMC is on `\_SB.SDC1` (0x12400000); the SD card controller `\_SB.SDC3` is at 0x12180000.

`PlResetHost` (0x1A54C) maps the clock controller `MmMapIoSpace(0x00900000, 0x4000)` (hardcoded, context socket + 0x1358) and finds the SDC number from the physical address of the controller registers:  
| Physical address | SDC | SoC |
|------------------|-----|-----|
| 0x12400000 | 1 | MSM8960 / MSM8930 (Lumia 520 eMMC) |
| 0x12140000 | 2 | |
| 0x12180000 | 3 | (Lumia 520 SD card) |
| 0x121C0000 | 4 | |
| 0x12200000 | 5 | |
| 0xF9824000 | 1 | MSM8974 ? |
| 0xF9864000 | 2 | |
| 0xF98A4000 | 3 | |
| 0xF98E4000 | 4 | |
| other | — | `STATUS_INTERNAL_ERROR` (0xC00000E5) |

Clock controller registers used (n = SDC number; same as the MSM8960 Linux clock driver):  
| Offset | Name | Use |
|--------|------|-----|
| 0x2800 + 0x20 × n | SDCn_HCLK_CTL | bit 4 set (AHB clock enable) by `PlSetClock` |
| 0x2808 + 0x20 × n | SDCn_APPS_CLK_MD | M/D value |
| 0x280C + 0x20 × n | SDCn_APPS_CLK_NS | N, source, pre-divider, MN enable, branch enable |
| 0x2810 + 0x20 × n | SDCn_RESET | bit 0 set, wait 10 ms, cleared (reset of the controller) |

Clock table of `PlSetClock` (0x1A864, `dword_28E38`):  
| Requested frequency | Frequency (kHz) | Source | Pre-div | MD | N | MN |
|---------------------|-----------------|--------|---------|----|---|----|
| < 10000 kHz | 144 | 0 (PXO ?) | 2 | 0x00020082 | 0x83 | 1 |
| < 40000 kHz | 25000 | 3 (PLL8 ?) | 1 | 0x0019009F | 0xB8 | 1 |
| ≥ 40000 kHz | 48000 | 3 | 1 | 0x000100FD | 0xFE | 1 |

When the dump isn't active (normal `sdbus.sys` code path) the frequency is requested with `PoFxPowerControl(GUID_POWER_CHANGE_P_STATE)` instead.

Controller (MCI) registers used, offsets from the controller base:  
| Offset | Name | Use |
|--------|------|-----|
| 0x00 | MCI_POWER | 3 = power on |
| 0x04 | MCI_CLK | 0x9300 at reset; bit 8 = clock enable |
| 0x0C | MCI_CMD | |
| 0x2C | MCI_DATA_CTL | cleared at reset |
| 0x38 | MCI_CLEAR | 0x7FFFFFF |
| 0x3C, 0x40 | MCI_INT_MASK0 / 1 | 0 |
| 0x6C | MCI_STATUS2 | bit 0: register write in progress (polled before each write) |
| 0x70 | MCI_VERSION ? | Read for the controller type 9 (8-bit bus / DDR support ?) |
| 0x100-0x10C | | Calibration of the SDCDC (`SdhcQcInitializeSdcdc`, HS200 ≥ 100 MHz only) |

`PlInitializeSocket` sets the capabilities: block length 512, max 2048 blocks (?), maximum transfer 0x80000 bytes (?), high speed disabled.

> [!NOTE]
> A timeout while waiting for the SDCDC calibration bits calls `KeBugCheckEx(0x15A SDBUS_INTERNAL_ERROR, …)`.
