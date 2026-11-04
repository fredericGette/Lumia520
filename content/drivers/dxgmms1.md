## Dxgmms1.sys

Microsoft DirectX graphics memory manager and GPU scheduler (WDDM 1.3, 1000 functions, symbols available, `dxgmms1.pdb`).  
It is the second half of [dxgkrnl.sys](./dxgkrnl.md): dxgkrnl loads it itself (`DXGMMS_EXPORT::Initialize`, `SystemLoadGdiDriverInSystemSpace`) and only uses it through two exported function tables, `VidMmInterface` (video memory manager, "VidMm") and `VidSchInterface` (GPU scheduler, "VidSch"). `DriverEntry` (0x5902C, INIT) does nothing and returns `STATUS_SUCCESS`.  
VidMm manages the segments reported by the display miniport [qcdxkm8930.sys](./qcdxkm8930.md) (`DXGK_SEGMENTDESCRIPTOR3`), allocations, aperture mappings, DMA buffers / paging buffers, residency, offer / reclaim and per-process working sets. VidSch manages the GPU nodes (engines), contexts, the DMA packet queues, flips / VSync, preemption, sync objects and TDR detection.  
It imports `ntoskrnl`, `HAL`, `watchdog.sys` (`WdLog*` diagnostics, `WdDiag*`) and `dxgkrnl.sys` (`DxgCoreInterface`, `Tdr*`, `DxgkSqm*`, `DpSynchronizeExecution`, `DpiGetDxgAdapter`, `DpiGetDriverVersion`, `DpiGet/SetSchedulerCallbackState`, `g_TdrConfig`, `g_TdrForceTimeout`, `g_bVSyncEnabledForLogging`, `DxgkVidMmAllowFailOnOfferReclaimErrors`). Every call to the miniport (`DxgkDdiBuildPagingBuffer`, `DxgkDdiPatch`, `DxgkDdiSubmitCommand` …) goes through dxgkrnl's `DxgCoreInterface` table (`ADAPTER_RENDER::Ddi*`, `DXGADAPTER::Ddi*` thunks).

There's no device object and no symbolic link.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\DxgMms1` ?  

All values are REG_DWORD read with `RtlQueryRegistryValuesEx(RTL_REGISTRY_CONTROL, …)` (flags `RTL_QUERY_REGISTRY_DIRECT` \| `RTL_QUERY_REGISTRY_TYPECHECK`). The "value" column gives the default used when the value is absent.

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler` (`VidSchiReadGlobalConfiguration` 0x42E24, called by `VidSchInitializeAdapter`):  
| Registry value | value | comment |
|----------------|-------|---------|
| AutoSyncToCPUPriority | 0 | |
| QuantumUnit | 25000 | Scheduling quantum (100 ns units ?, = 2.5 ms) |
| PreemptionQuantumUnit | 50000 | |
| EnablePreemption | 1 | |
| HwQueuedRenderPacketGroupLimit | 2 | Render packets queued in the hardware per node |
| QueuedPresentLimit | 3 | Max queued presents per device |
| InitDriverFenceId | 0 | |
| CarryOverUsedQuantum | 0 | |
| EnableFlipOnVSyncHwFlipQueue | 1 | |
| EnableFlipOnVSyncSwFlipQueue | 1 | |
| EnableFlipImmediateSwFlipQueue | 1 | |
| AdjustWorkerThreadPriority | 1 | `VidSchiAdjustWorkerThreadPriority` |
| CountFlipTowardHwLimit | 0 | |
| AllowUserModeToSetFlipLimit | 1 | |
| NumberOfDmaPacketPool | 20 | |
| ProfileLevel | 2 | |
| VSyncIdleTimeout | 7 | VSync interrupt is disabled after this many idle VSyncs ? |
| EnableDirectSubmission | 1 | |
| CountPresentTowardHwLimit | 0 | |
| EnableContextDelay | 1 | |
| ForcePreemptionAware | 0 | |
| LogDriverVSyncCallback | 0 | |
| MaximumAllowedPreemptionDelay | 900 | ms ? |
| ContextSchedulingPenaltyDelay | 1000 | |
| BackgroundProcessMaximumAllowedPreemptionDelay | 8 | |
| ForceIndependentFlip | 0 | |
| FlipOverrideMode | 0 | Read per device (`VidSchiReadDeviceConfiguration` 0x35A28). 1 or 2 are kept, anything else → 0 |

Adapter PnP (software) key, `HwQueuedRenderPacketGroupLimitPerNode` (`VidSchiReadNodeConfiguration` 0x43540, through dxgkrnl's `DpiOpenPnpRegistryKey`): REG_BINARY, one **big-endian** dword per node, length a multiple of 4 and ≤ 4 × number of nodes, otherwise `0xC000000D` STATUS_INVALID_PARAMETER.  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\MemoryManager` (`VIDMM_GLOBAL::ReadConfiguration` 0x437A8, called once by `VIDMM_GLOBAL::InitGlobals`):  
| Registry value | value | comment |
|----------------|-------|---------|
| PinnedMemoryLimit | 25 | Percent ? Must be < 90 |
| PinnedApertureMemoryLimit | 40 | Percent ? Must be < 90 |
| FaultInjection | 0 | |
| PagesHistory | 0 | |
| IgnoreBankInformation | 0 | |
| IdleGPUOnApertureManipulation | 0 | |
| MemTransferThreshold | 10 | |
| ExcessiveMemTransferFlipThreshold | 15 | |
| ExcessiveMemTransferPenalty | 5 | |
| EventThrottleThreshold | 300 | |
| DisablePrefetching | 0 | |
| NbDmaBufferLimitPerDevice | 256 (RAM ≤ 512 MB) / 1024 | See below |
| NbCddDmaBufferLimitPerDevice | 4 | |
| DmaBufferBytesLimitAllDevices | 0x800000 (8 MB, RAM ≤ 512 MB) / 0x2000000 (32 MB) | |
| DmaBufferListBytesLimitAllDevices | 0x400000 (4 MB, RAM ≤ 512 MB) / 0x1000000 (16 MB) | |
| NbDmaBufferLimitCompareWatermark | 10 | |
| NbPagingHistoryRecords | 0 | `VIDMM_GLOBAL::InitializePagingHistory` |
| PinDWMAllocationBackingStore | 1 | |
| RemovePagesFromWorkingSetOnPagingForDwm | 1 | |
| UseUnreset | 1 | |
| PrivateHeapPackingThreshold | 0x100000 | |
| PrivateHeapPackingBlockSize | 0x800000 | |
| EvictTemporaryPeriod, EvictUnusedPeriod, EvictUnusedThreshold | 60 | |
| ProcessPendingOfferPeriod | 1 | |
| ProcessSysmemOfferPeriod | 8 | |
| SegmentBalancingPolicy | 2 | |
| UseSpecificPoolTags | 0 | When set, VidMm objects get specific pool tags (`Vi28`, `Vi39`, `Vi40` …) instead of `ViMm` |
| BugcheckOnApertureCorruption | 0 | |
| QuickApertureCorruptionCheck | 0 | |
| DirectFlipMemoryRequirement | 200 | |
| CommitProcessHeapOnDemand | 1 | |
| SegmentCleanupSizeThreshold | 0x5C0 | |
| SegmentCleanupCountThreshold | 6 | |
| SegmentCleanupTime | 20 | |
| MaxSegmentSize0 … MaxSegmentSize31 | ? | Name built as `MaxSegmentSize` + segment index (`RtlIntegerToUnicodeString`), one value per segment |
| SystemMemoryCommitLimit | 0 | MB (`ReadCommitLimitInformation` 0x448D8), see below |
| PinnedBackingStoreLimit | 0 | MB. 0 → RAM / 8 |
| MinimumSystemMemoryCommitLimit | 0 | MB, no default. Floor of the commit limit, at least 64 MB |
| SmallSystemMemorySize | 0 | MB, no default |
| WorkingSet.DefaultMaximumPercentile | 90 | `ReadWorkingSetConfiguration` |
| WorkingSet.DefaultMinimumPercentile | 65 | |
| PreparationPeriod | 1 | `ReadPreparationPeriodConfiguration` |
| Period.MinimumPolicyHeldPeriod | 4 | |
| Period.MaximumPolicyHeldPeriod | 64 | |
| Period.AlwaysForceMemReset | 1 | |
| Period.EvictionThresholdForMemReset | 32 | |
| Period.NbOfAllocationsThresholdToMRU | 0x7FFFFFFF | |
| Period.RenamingListTrimmingFrequency | 60 | |
| Migration.Period | 1 | `ReadMigrationConfiguration` |
| Migration.TableSize | 5 | |
| Migration.MaxBytesMigrated | 32 | |
| Migration.DisabledPeriodAfterFailure, Migration.DisabledPeriodAfterMemoryPressure, Migration.DisabledPeriodAfterTrashing | 2 | |
| UnusedTrimmingPeriod | 1 | `ReadUnusedAllocationConfiguration` |
| Unused.MinimumThreshold, Unused.LowThreshold, Unused.NormalThreshold, Unused.HighThreshold, Unused.MaximumThreshold | 0, 15, 45, 120, 1000000 | |
| Unused.SelfTrimMinimumThreshold, Unused.SelfTrimLowThreshold, Unused.SelfTrimNormalThreshold, Unused.SelfTrimHighThreshold, Unused.SelfTrimMaximumThreshold | 0, 1, 2, ?, ? | |
| Unused.EvictApertureOfferLowThreshold, …NormalThreshold, …HighThreshold, …MaximumThreshold | ? | |

The physical memory size is the sum of the ranges returned by `MmGetPhysicalMemoryRanges` (`VIDMM_GLOBAL::QuerySystemMemorySize`; 512 MB if the call fails). When it is ≤ 0x20000000 (512 MB), which is the case on the Lumia 520, the smaller DMA buffer defaults apply.  
GPU system-memory commit limit (`VIDMM_GLOBAL::ReadCommitLimitInformation`): `SystemMemoryCommitLimit` if it's at least the minimum; otherwise max(minimum, (RAM − `SmallSystemMemorySize`) / 2), where minimum = max(`MinimumSystemMemoryCommitLimit`, 64 MB). It's the same formula as in [qcdxkm8930.sys](./qcdxkm8930.md), but here `SmallSystemMemorySize` defaults to 0, not 512 MB.

GUID of the ETW provider:  
`{802EC45A-1E99-4B83-9920-87C98277BA9D}` (Microsoft-Windows-DxgKrnl, same provider as dxgkrnl, `DxgkControlGuid` at `.rdata:0x29730`, registered by `McGenEventRegister` from `VIDMM_GLOBAL::InitGlobals`, enable callback `DxgkEtwEnableCallback`)  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| — | [dxgkrnl.sys](./dxgkrnl.md) | Only caller (`VidMmInterface` / `VidSchInterface`). dxgmms1 calls back through the dxgkrnl exports and `DxgCoreInterface` |
| Display miniport (through dxgkrnl) | [qcdxkm8930.sys](./qcdxkm8930.md) | `DxgkDdi*` render / paging / flip DDIs. The miniport's `DxgkCbNotifyInterrupt` / `DxgkCbNotifyDpc` end up in `VidSchDdiNotifyInterrupt` / `VidSchDdiNotifyDpc` |
| `\Device\PhysicalMemory` | ntoskrnl | `ZwOpenSection(SECTION_ALL_ACCESS, OBJ_KERNEL_HANDLE \| OBJ_CASE_INSENSITIVE)` in `VIDMM_GLOBAL::Init` (0x5478C), handle kept at `VIDMM_GLOBAL+0x1490`, used for mappings of aperture / physical segments |

### Exports

| Export | Address | Comment |
|--------|---------|---------|
| `VidMmInterface` | `.rdata:0x29938` | Size 0x17C, version 1, 93 function pointers, see [VidMmInterface](#vidmminterface) |
| `VidSchInterface` | `.rdata:0x29AB8` | Size 0x178, version 1, 92 function pointers, see [VidSchInterface](#vidschinterface) |
| `GsDriverEntry` | 0x1E454 | Entry point: `__security_init_cookie`, then the empty `DriverEntry` |

### VidMmInterface

The table starts with a dword size (`0x17C`) and a dword version (`1`), then:  
| Offset | Function |
|--------|----------|
| +008 | VidMmInitGlobals |
| +00C | VidMmDeInitGlobals |
| +010 | VidMmInitializeAdapter |
| +014 | VidMmTerminateAdapter |
| +018 | VidMmEscape |
| +01C | VidMmReportVidMmState |
| +020 | VidMmFreeDeferredDmaBufferMapping |
| +024 | VidMmNbSegment |
| +028 | VidMmGetTotalSegmentSize |
| +02C | VidMmPurgeAllSegments |
| +030 | VidMmRestoreFromPurge |
| +034 | VidMmSuspendMemorySegmentAccess |
| +038 | VidMmResumeMemorySegmentAccess |
| +03C | VidMmInvalidateAllVirtualAddresses |
| +040 | VidMmCreateAllocation |
| +044 | VidMmDestroyAllocation |
| +048 | VidMmOpenAllocation |
| +04C | VidMmTerminateAllocation |
| +050 | VidMmIsAllocationTerminated |
| +054 | VidMmCloseAllocation |
| +058 | VidMmTryCloseAllocation |
| +05C | VidMmQueryAllocationResidency |
| +060 | VidMmIsAllocationCPUVisible |
| +064 | VidMmInvalidateAllocation |
| +068 | VidMmSetAllocationPriority |
| +06C | VidMmGetPinnedAllocationInfo |
| +070 | VidMmPinAllocation |
| +074 | VidMmUnpinAllocation |
| +078 | VidMmGetAllocationGpuVirtualAddress |
| +07C | VidMmBeginCPUAccess |
| +080 | VidMmEndCPUAccess |
| +084 | VidMmGetAllocationInstance |
| +088 | VidMmFreeDeferredMapping |
| +08C | VidMmQueryAdapterStatistics |
| +090 | VidMmQueryProcessStatistics |
| +094 | VidMmQueryProcessAdapterStatistics |
| +098 | VidMmQuerySegmentStatistics |
| +09C | VidMmQueryProcessSegmentStatistics |
| +0A0 | VidMmETWAllocationHandle |
| +0A4 | VidMmLogInformationToMinidump |
| +0A8 | VidMmCreateProcess |
| +0AC | VidMmTerminateProcess |
| +0B0 | VidMmSetWorkingSetInformation |
| +0B4 | VidMmGetProcessAdapterInfo |
| +0B8 | VidMmCreateDevice |
| +0BC | VidMmInitDevice |
| +0C0 | VidMmTerminateDevice |
| +0C4 | VidMmFreeDeferredDmaBufferMapping (again) |
| +0C8 | VidMmReferencePrimaryAllocationForSubmission |
| +0CC | VidMmReferenceAllocationForTokenSubmission |
| +0D0 | VidMmUnreferencePrimaryAllocation |
| +0D4 | VidMmCreateDmaPool |
| +0D8 | VidMmInitDmaPool |
| +0DC | VidMmDestoryDmaPool (sic) |
| +0E0 | VidMmReportDmaPoolState |
| +0E4 | VidMmTrimDmaPoolToMinimum |
| +0E8 | VidMmResizeBuffersInPool |
| +0EC | VidMmGetNextBuffersContractedSize |
| +0F0 | VidMmAcquireDmaBuffer |
| +0F4 | VidMmReleaseDmaBuffer |
| +0F8 | VidMmBeginDmaBufferCPUAccess |
| +0FC | VidMmEndDmaBufferCPUAccess |
| +100 | VidMmGetDmaGpuVirtualAddress |
| +104 | VidMmGetDmaBufferLength |
| +108 | VidMmGetDmaPatchLocationListLength |
| +10C | VidMmGetDmaPatchLocationList |
| +110 | VidMmGetDmaAllocationList |
| +114 | VidMmGetDmaPrivateData |
| +118 | VidMmReferenceDmaBuffer |
| +11C | VidMmUnreferenceDmaBuffer |
| +120 | VidMmReportMultiGlobalAlloc |
| +124 | VidMmReportMultiAlloc |
| +128 | VidMmIsAllocationAccessPending |
| +12C | VidMmIsSharedAllocationAccessPending |
| +130 | VidMmWaitOnAllocationDmaReferences |
| +134 | VidMmFreeDeferredDmaBufferMapping (again) |
| +138 | VidMmNotifyFullscreen |
| +13C | VidMmQueryAllocationSizeInSystemMemory |
| +140 | VidMmCreateContextAllocation |
| +144 | VidMmDestroyContextAllocation |
| +148 | VidMmOfferAllocation |
| +14C | VidMmReclaimAllocation |
| +150 | VidMmGetAllocationSection |
| +154 | VidMmIsAllocationInPresentQueue |
| +158 | VidMmWaitOnAllocationPresentQueue |
| +15C | VidMmUseDirectFlip |
| +160 | VidMmReportContextAllocList |
| +164 | VidMmEvictAllocation |
| +168 | VidMmInitializeAdapterPowerManagement |
| +16C | VidMmInitializeSegmentPowerManagement |
| +170 | VidMmSetSegmentPowerState |
| +174 | VidMmGetAllocationFlipQueueReferencesPointer |
| +178 | VidMmSetAllocationFlipQueueReferencesPointer |

> [!NOTE]
> The repeated `VidMmFreeDeferredDmaBufferMapping` entries (+020, +0C4, +134) are probably placeholder no-op slots: the linker folded identical stub functions into one ?.

### VidSchInterface

Size `0x178`, version `1`, then:  
| Offset | Function |
|--------|----------|
| +008 | VidSchDdiNotifyInterrupt (`DxgkCbNotifyInterrupt` of the miniport, at ISR level) |
| +00C | VidSchDdiNotifyDpc (`DxgkCbNotifyDpc`) |
| +010 | VidSchQueryRequiredDmaQueueEntry |
| +014 | VidSchInitializeAdapter |
| +018 | VidSchTerminateAdapter |
| +01C | VidSchFlushAdapter |
| +020 | VidSchReportAdapter |
| +024 | VidSchEscape |
| +028 | VidSchIsWorkerThread |
| +02C | VidSchCreateProcess |
| +030 | VidSchTerminateProcess |
| +034 | VidSchSetPriorityClassProcess |
| +038 | VidSchGetPriorityClassProcess |
| +03C | VidSchCreateDevice |
| +040 | VidSchTerminateDevice |
| +044 | VidSchFlushDevice |
| +048 | VidSchSwitchFromDevice |
| +04C | VidSchSyncPriorityDevice |
| +050 | VidSchSetQueuedPresentLimit |
| +054 | VidSchGetQueuedPresentLimit |
| +058 | VidSchWaitForQueuedPresentLimit |
| +05C | VidSchGetDeviceError |
| +060 | VidSchCreateContext |
| +064 | VidSchTerminateContext |
| +068 | VidSchReportContext |
| +06C | VidSchFlushContext |
| +070 | VidSchSwitchFromContext |
| +074 | VidSchSetPriorityContext |
| +078 | VidSchGetPriorityContext |
| +07C | VidSchSetInProcessPriorityContext |
| +080 | VidSchGetInProcessPriorityContext |
| +084 | VidSchRegisterAsDwm |
| +088 | VidSchConfirmToken |
| +08C | VidSchEnterIndependentFlip |
| +090 | VidSchExitIndependentFlip |
| +094 | VidSchCheckSurfaceIndependentFlipAssignment |
| +098 | VidSchOverlayPlaneAttributes |
| +09C | VidSchUpdateOverlayPlaneAttributes |
| +0A0 | VidSchSubmitCommand |
| +0A4 | VidSchFlushPendingCommand |
| +0A8 | VidSchGetQueuedPacketCount |
| +0AC | VidSchGetDxgContext |
| +0B0 | VidSchiIncrementContextReference |
| +0B4 | VidSchiDecrementContextReference |
| +0B8 | VidSchQueryLastCompletedPresentId |
| +0BC | VidSchQueryLastCompletedPresentIdDWM |
| +0C0 | VidSchQueryLastCompletedVidPnSourcePresentIdDWM |
| +0C4 | VidSchQueryFlipQueueInfo |
| +0C8 | VidSchGetDeviceFlipMode |
| +0CC | VidSchSetMonitorPowerState |
| +0D0 | VidSchGetMonitorPowerState |
| +0D4 | VidSchIsVSyncAvailable |
| +0D8 | VidSchIsVSyncEnabled |
| +0DC | VidSchControlVSyncAdapter |
| +0E0 | VidSchControlVSyncDevice |
| +0E4 | VidSchIsTDRPending |
| +0E8 | VidSchIsTDRFaultingDevice |
| +0EC | VidSchPrepareForRecovery |
| +0F0 | VidSchCollectDbgInfo |
| +0F4 | VidSchCreateSyncObject |
| +0F8 | VidSchDestroySyncObject |
| +0FC | VidSchWaitForSingleSyncObject |
| +100 | VidSchSignalSyncObjects |
| +104 | VidSchQueryAdapterStatistics |
| +108 | VidSchQueryNodeStatistics |
| +10C | VidSchQueryVidPnSourceStatistics |
| +110 | VidSchQueryProcessStatistics |
| +114 | VidSchQueryProcessAdapterStatistics |
| +118 | VidSchQueryProcessNodeStatistics |
| +11C | VidSchQueryProcessVidPnSourceStatistics |
| +120 | VidMmFreeDeferredDmaBufferMapping (stub ?) |
| +124 | VidMmGetAllocationGpuVirtualAddress (stub ?) |
| +128 | VidSchSuspendAdapter |
| +12C | VidSchResumeAdapter |
| +130 | VidSchFlushQueuePackets |
| +134 | VidSchIsContextFlushable |
| +138 | VidSchInitializeAdapterPowerManagement |
| +13C | VidSchInitializeComponentPowerManagement |
| +140 | VidSchSetNodePowerState |
| +144 | VidSchSetVidPnSourceAddress |
| +148 | VidSchEnqueueCpuEvent |
| +14C | VidSchIsGpuAccessBlocked |
| +150 | VidSchIsSyncObjectWaitUnordered |
| +154 | VidSchBlockUntilNoUnorderedWaitsInContext |
| +158 | VidSchEnableLatencyToleranceTimer |
| +15C | VidSchIsSyncObjectSignaled |
| +160 | VidSchCancelDeferredVidPnSourceVisibility |
| +164 | VidSchRequestDeferredVidPnSourceVisibility |
| +168 | VidSchGetProcessInterferenceCount |
| +16C | VidSchGetRunEvent |
| +170 | VidSchSetCrossAdapterData |
| +174 | VidSchUnreferenceDisplayingAllocationInternal |

### Initialisation

1. `VidMmInitGlobals` → `VIDMM_GLOBAL::InitGlobals` (0x435CC): ETW registration, `ReadConfiguration` (the `MemoryManager` values above), 64 KB rotation history (tag `ViMm`), `VIDMM_DMA_POOL::InitGlobals`.
2. `VidMmInitializeAdapter` → `VidMmiInit` (0x44F68): `ZwQuerySystemInformation(SystemBasicInformation)` (44 bytes) to compare the highest physical page with the highest address the adapter can reach, then `VIDMM_GLOBAL::Init` (0x5478C) with the segment descriptors of the miniport: opens `\Device\PhysicalMemory`, creates the segments (memory / aperture), the paging history and the fast mutexes.
3. `VidSchInitializeAdapter` (0x427FC): allocates the `VIDSCH_GLOBAL` (4432 bytes, tag `ViSh`), copies the scheduling caps of the adapter (number of nodes ≤ 30, preemption granularity, …), `VidSchiReadGlobalConfiguration`, creates one node per engine (`VidSchiCreateNode`), an internal device and one system context per node, then the scheduler thread `VidSchiWorkerThread` (`PsCreateSystemThread`, `OBJ_KERNEL_HANDLE`). The VSync control thread (`VidSchiControlVSyncThread`) and the deferred visibility thread (`VidSchiDeferredVisibilityThread`) are prepared in the same structure (`+0x504`, `+0x528`).

Pool tags: `ViSh` (0x68536956, scheduler), `ViMm` (0x6D4D6956, memory manager); with `UseSpecificPoolTags`, `Vi28`, `Vi39`, `Vi40`, … per object type.  
Privilege checks: `SeSinglePrivilegeCheck(SE_INC_BASE_PRIORITY_PRIVILEGE = 14)` is required to set a process GPU priority class ≥ 5 (`D3DKMT_SCHEDULINGPRIORITYCLASS_REALTIME`, `VidSchSetPriorityClassProcess`, `0xC0000022` otherwise, except for the DWM), to raise a context priority (`VidSchiComputePriority`), an allocation priority (`VIDMM_GLOBAL::SetOneAllocationPriority`) and the working set (`VIDMM_PROCESS::SetWorkingSetInformation`).

### Escapes

`D3DKMTEscape` with `D3DKMT_ESCAPE_VIDMM` / `D3DKMT_ESCAPE_VIDSCH` reach these handlers through dxgkrnl.

`VidMmEscape` → `VIDMM_GLOBAL::Escape` (0x53B58), `D3DKMT_VIDMM_ESCAPE`:  
| Type | Name | Action |
|------|------|--------|
| 0 | SETFAULT | Writes the dword at `+08` to `VIDMM_GLOBAL::_Config` (first dword) and `gVidMmGlobalFault` |
| 1 | RUNCOHERENCYTEST | System command 107, waits for completion |
| 2 | RUNUNMAPTODUMMYPAGETEST | System command 108 |
| 3 | APERTURECORRUPTIONCHECK | `VIDMM_GLOBAL::ApertureCorruptionCheck` |
| 4 | SUSPENDCPUACCESSTEST | Suspend then resume the CPU access to the memory segments. Refused with `0xC0000022` if the last argument is 0 |
| other | — | `0xC000000D` STATUS_INVALID_PARAMETER |

`VidSchEscape` (0x48E14), `D3DKMT_VIDSCH_ESCAPE`:  
| Type | Name | Action |
|------|------|--------|
| 0 | PREEMPTIONCONTROL | `+04` ≠ 0 sets bit 0 of `VIDSCH_GLOBAL+0x578` (preemption disabled ?) |
| 2 | TDRCONTROL | `+04` = 4 clears bit 4 of `VIDSCH_GLOBAL+0x18`; 5 clears bits 0-2; 8 (ENGINETDR) sets bit `+08` (node index, must be < number of nodes) in the 64-bit mask at `VIDSCH_GLOBAL+0xB0` (forced engine timeout ?). Other sub-types: `0xC000000D` |
| 4 | ENABLECONTEXTDELAY | `+04` ≠ 0 sets bit 16 of `VIDSCH_GLOBAL+0x578` |
| other (1 SUSPENDSCHEDULER, 3 SUSPENDRESUME) | — | `0xC000000D` STATUS_INVALID_PARAMETER |
