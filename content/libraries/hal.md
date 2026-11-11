## HAL.dll

Microsoft hardware abstraction layer for ARM ("ARM HAL", ACPI/UEFI SoC HAL, PDB `hal.pdb`, public symbols available, 875 functions).  
It's a kernel-mode image loaded with `ntoskrnl.exe` by the boot loader. It hides the SoC from the kernel: interrupt controller (ARM GIC described by the MADT), timers (ARM generic timer of the GTDT, processor cycle counter, WDAT watchdog, and the timers of the HAL extensions), system DMA (controllers registered by the HAL extensions), processor start / idle / reset, real-time clock and wake alarm (through [acpitime.sys](../drivers/acpitime.md)), UEFI runtime services (variables, reset, capsules), ACPI table cache and performance counters (ARM PMU, with the Qualcomm Krait events). It contains no Qualcomm code: everything SoC-specific comes from the firmware ACPI tables and from the [HAL extensions](#hal-extensions) listed in the CSRT.  
Its exports are used by every kernel driver (e.g. `KeStallExecutionProcessor` in [qcsysdef8930.sys](../drivers/qcsysdef8930.md), the crash dump DMA functions in [dumpsd.sys](../drivers/dumpsd.md), [crashdmp.sys](../drivers/crashdmp.md)). It loads and drives the HAL extensions [QCHalExtQ8x60Bam.dll](./qchalextq8x60bam.md) and [QCHalExtQcAdm3Dma.dll](./qchalextqcadm3dma.md) (DMA), and probably [HalExtQ8660Timers.dll](./halextq8660timers.md) (timers). It creates the `ACPI_HAL\PNP0C08` root device on which [acpi.sys](../drivers/acpi.md) loads.

Location on the phone: `C:\Windows\System32\hal.dll` ? (the extracted file `HAL.DLL` has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntoskrnl.exe | 197 functions. Memory: `MmMapIoSpace`, `MmUnmapIoSpace`, `MmAllocateContiguousNodeMemory`, `MmAllocatePagesForMdl`, `MmMapLockedPagesSpecifyCache`, `MmAllocateMappingAddress`, `MmGetPhysicalAddress`, `PoSetHiberRange`, … Kernel: `KeBugCheckEx`, `KeRegisterBugCheckCallback`, `KiIpiServiceRoutine`, `KiDispatchInterrupt`, `KiDeliverApc`, `KiReplayInterrupt`, `KiConnectHalInterrupt`, `KeInitializeSecondaryInterruptServices`, `KeDispatchSecondaryInterrupt`, `KeClockInterruptNotify`, `KeGetNextClockTickDuration`, `KeClockTimerPowerChange`, `KeProfileInterruptWithSource`, `KeSaveStateForHibernate`, `KeRestoreProcessorState`, the affinity / processor enumeration functions, … Data: `HalDispatchTable`, `HalPrivateDispatchTable`, `IoAdapterObjectType`. I/O and PnP: `IoCreateDriver`, `IoCreateDevice`, `IoReportDetectedDevice`, `IoRegisterPlugPlayNotification`, `IoGetDeviceObjectPointer`, `IoBuildDeviceIoControlRequest`, `IofCallDriver`, `IoConnectInterruptEx`, `IoReportHalResourceUsage`, `IoSetDevicePropertyData`. Power: `PoFxRegisterCoreDevice`, `PoFxStartDevicePowerManagement`, `PoFxActivateComponent`, `PoFxCompleteIdleCondition`, `PoInitiateProcessorWake`, `PoSetFixedWakeSource`, `PoGetProcessorIdleAccounting`, `ZwPowerInformation`. Registry / files: `ZwOpenKey`, `ZwCreateKey`, `ZwSetValueKey`, `ZwOpenFile`, `ZwQueryLicenseValue`. Callbacks: `ExCreateCallback`, `ExRegisterCallback`. Errata manager: `EmpProviderRegister`, `EmClientQueryRuleState`. ETW: `EtwRegister`, `EtwEventEnabled`, `EtwWrite`. Debug: `DbgPrint`, `DbgPrintEx`, `KdPowerTransition`. CRT: `strstr`, `atoi`, `qsort`, `swprintf_s`, `wcs*`, `str*`, `__chkstk` |
| kdcom.dll | `KdRestore` |
| PSHED.dll | `PshedMarkHiberPhase` |

`memset`, `memcmp`, `memmove`, the `__rt_*div*` helpers and `__security_init_cookie` / `__security_push_cookie` / `__security_pop_cookie` / `__GSHandlerCheck` are the statically linked CRT and `/GS` boilerplate.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| HAL extensions: [QCHalExtQ8x60Bam.dll](./qchalextq8x60bam.md) (or its older build [HalExtQ8x60Bam.dll](./halextq8x60bam.md) ?), [QCHalExtQcAdm3Dma.dll](./qchalextqcadm3dma.md) (or its older build [HalExtQcAdm3Dma.dll](./halextqcadm3dma.md) ?), [HalExtQ8660Timers.dll](./halextq8660timers.md) ? | Loaded by the boot loader (list in the loader parameter block), entry point called by [HalpExtInitExtensions](#hal-extensions) | SoC DMA controllers, timers and cache controllers described in the CSRT |
| [acpitime.sys](../drivers/acpitime.md) | Device interface `GUID_DEVICE_ACPI_TIME`, `IoBuildDeviceIoControlRequest` | [Real-time clock and wake alarm](#real-time-clock-and-wake-alarm) |
| [acpi.sys](../drivers/acpi.md) | `ZwOpenFile("\DosDevices\ACPI_ROOT_OBJECT")`, `IRP_MN_QUERY_INTERFACE` `GUID_PCC_INTERFACE_STANDARD` | Platform Communication Channel interface (`HalpAcquirePccInterface`, for the PCC commands of `HalpSendPccCommand`) |
| UEFI firmware | Runtime services (`HalEfi*`) | Variables, `ResetSystem`, capsules, see [Firmware](#firmware) |
| ACPI tables | Loader block / `HalAcpiGetTable` | See [ACPI tables](#acpi-tables) |

### Exports

70 exports, all with public names. The parameters are those of the documented / public Windows prototypes when the code agrees with them.

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `HalAcpiGetTableEx` | 0x8001D858 | 4 parameters passed unchanged to `HalpAcpiGetTable` (loader block, signature, …) |
| 2 | `HalAllProcessorsStarted` | 0x8003E3AC | none: runs [init phases](#startup) 17–18, returns TRUE if they succeed |
| 3 | `HalAllocateCrashDumpRegisters` | 0x80027F38 | `PADAPTER_OBJECT Adapter`, `PULONG NumberOfMapRegisters` |
| 4 | `HalAllocateHardwareCounters` | 0x80039094 | `PGROUP_AFFINITY`, `ULONG`, `PPHYSICAL_COUNTER_RESOURCE_LIST`, `PHANDLE CounterSetHandle`: a single owner at a time (`HalpPmuInUse`), else `STATUS_INSUFFICIENT_RESOURCES` |
| 5 | `HalBeginSystemInterruptUnspecified` | 0x80017420 | ? (GIC acknowledge, `HalpGicAcceptAndGetSource`) |
| 6 | `HalBugCheckSystem` | 0x80022B3C | none used: `__debugbreak` |
| 7 | `HalCalibratePerformanceCounter` | 0x80019BC0 | `volatile LONG *Number`, `ULONGLONG NewCount` |
| 8 | `HalConvertDeviceIdtToIrql` | 0x80037748 | `ULONG Vector`: IRQL = bits 8–11 of the vector clamped to 8…11; 8 if the vector is ≥ 0x1000 |
| 9 | `HalDisableInterrupt` | 0x80016C38 | ? |
| 10 | `HalDmaAllocateCrashDumpRegistersEx` | 0x80027FEC | `PADAPTER_OBJECT`, `ULONG NumberOfMapRegisters`, `HAL_DMA_CRASH_DUMP_REGISTER_TYPE`, `PVOID *MapRegisterBase`, `PULONG MapRegistersAvailable` |
| 11 | `HalDmaFreeCrashDumpRegistersEx` | 0x80027E80 | `PADAPTER_OBJECT`, `HAL_DMA_CRASH_DUMP_REGISTER_TYPE` (< 2) |
| 12 | `HalEnableInterrupt` | 0x8001C730 | ? |
| 13 | `HalEndSystemInterrupt` | 0x80015978 | ? (GIC end of interrupt, `HalpGicWriteEndOfInterrupt`) |
| 14 | `HalEnumerateEnvironmentVariablesEx` | 0x80025410 | `ULONG InformationClass`, `PVOID Buffer`, `PULONG BufferLength`: UEFI `GetNextVariableName` |
| 15 | `HalEnumerateProcessors` | 0x8001A020 | `ULONG`: number of processors, limited by `ONECPU` and the `Kernel-RegisteredProcessors` license value |
| 16 | `HalFreeHardwareCounters` | 0x8003904C | `HANDLE CounterSetHandle` |
| 17 | `HalGetBusDataByOffset` | 0x8001E1EC | stub returning 0 (same code as `HalSetBusDataByOffset`, no bus handler) |
| 18 | `HalGetEnvironmentVariable` | 0x8002327C | stub returning 7 (`ENOMEM` ? same code as `HalSetEnvironmentVariable`): the legacy CMOS variables don't exist |
| 19 | `HalGetEnvironmentVariableEx` | 0x80026360 | `PWSTR VariableName`, `LPGUID VendorGuid`, `PVOID Value`, `PULONG ValueLength`, `PULONG Attributes`: UEFI `GetVariable` |
| 20 | `HalGetInterruptTargetInformation` | 0x8001DC78 | `KINTERRUPT_POLARITY`/type ? (0 or 2), …, out |
| 21 | `HalGetMemoryCachingRequirements` | 0x8001C038 | `PHYSICAL_ADDRESS`, …, out cache type (table built at phase 13 from the loader block) |
| 22 | `HalGetMessageRoutingInfo` | 0x80023EA0 | MSI routing (`HalpInterruptGenerateMessage`); unused without PCI |
| 23 | `HalGetProcessorIdByNtNumber` | 0x8001D914 | `ULONG NtNumber`, `PULONG ProcessorId` |
| 24 | `HalGetVectorInput` | 0x8001E1D0 | forwarded to `HalPrivateDispatchTable` + 0x5C |
| 25 | `HalInitSystem` | 0x8003B038 | `ULONG Phase` (0 or 1), `PLOADER_PARAMETER_BLOCK`, see [Startup](#startup) |
| 26 | `HalInitializeOnResume` | 0x80028DF0 | UEFI resume (`HalpEfiInitializeOnResume`) |
| 27 | `HalInitializeProcessor` | 0x8001A90C | `ULONG Number`, `PLOADER_PARAMETER_BLOCK`: phases 0–3 on the boot processor, 4–5 on the others |
| 28 | `HalProcessorIdle` | 0x80019C90 | none: `DSB` + `WFI` |
| 29 | `HalQueryEnvironmentVariableInfoEx` | 0x800261C4 | UEFI `QueryVariableInfo` |
| 30 | `HalQueryMaximumProcessorCount` | 0x8001B2C0 | none: bug check 0x5C (0x8000) if called before the interrupt controller / NUMA initialisation |
| 31 | `HalQueryRealTimeClock` | 0x80018318 | `PTIME_FIELDS`, see [Real-time clock](#real-time-clock-and-wake-alarm) |
| 32 | `HalRegisterDynamicProcessor` | 0x80025BC8 | processor hot-add (`HalpInterruptRegisterDynamicProcessor`) |
| 33 | `HalRegisterErrataCallbacks` | 0x8003F774 | registers the [errata manager](#errata-manager) provider |
| 34 | `HalReportResourceUsage` | 0x8003E7CC | phase 0: init phases 21–22 then `IoReportHalResourceUsage("ARM HAL", …)`; phase 1: phases 23–24 |
| 35 | `HalRequestClockInterrupt` | 0x80014B88 | IPI vector 0xD02; bug check 0x5C (0x201) on failure |
| 36 | `HalRequestIpi` | 0x80014BA4 | `KAFFINITY_EX` targets |
| 37 | `HalRequestIpiSpecifyVector` | 0x80014C5C | targets, vector |
| 38 | `HalRequestSoftwareInterrupt` | 0x80012878 | `KIRQL` (APC / DPC level) |
| 39 | `HalReturnToFirmware` | 0x80027604 | `FIRMWARE_REENTRY`: 1 = power off (`HalpShutdown`), 0/2/3 = reboot (`HalpReboot`), other = "HalReturnToFirmware called" + break |
| 40 | `HalSendSoftwareInterrupt` | 0x80014DE4 | processor, `KIRQL` |
| 41 | `HalSetBusDataByOffset` | 0x8001E1EC | stub returning 0 |
| 42 | `HalSetEnvironmentVariable` | 0x8002327C | stub returning 7 |
| 43 | `HalSetEnvironmentVariableEx` | 0x8002625C | `PWSTR`, `LPGUID`, `PVOID Value`, `ULONG ValueLength`, `ULONG Attributes`: UEFI `SetVariable` |
| 44 | `HalSetProfileInterval` | 0x80023220 | `ULONG Interval`: through the profile interface (`HalpProfileInterface[3]`) |
| 45 | `HalSetRealTimeClock` | 0x8002790C | `PTIME_FIELDS` |
| 46 | `HalStartDynamicProcessor` | 0x80028648 | processor hot-add |
| 47 | `HalStartNextProcessor` | 0x8001ACF4 | `PLOADER_PARAMETER_BLOCK`, `PKPROCESSOR_STATE` |
| 48 | `HalStartProfileInterrupt` | 0x80017EA4 | `KPROFILE_SOURCE` |
| 49 | `HalStopProfileInterrupt` | 0x80017DF0 | `KPROFILE_SOURCE` |
| 50 | `HalTranslateBusAddress` | 0x8001D9E8 | `INTERFACE_TYPE`, `ULONG BusNumber`, `PHYSICAL_ADDRESS BusAddress`, `PULONG AddressSpace`, `PPHYSICAL_ADDRESS TranslatedAddress`: identity for memory space, FALSE for I/O space (`*AddressSpace` = 1) |
| 51 | `KdComPortInUse` | 0x80030300 | data (pointer) |
| 52 | `KdHvComPortInUse` | 0x800302FC | data (pointer) |
| 53 | `KeFlushWriteBuffer` | 0x80024064 | none: `DMB SY` |
| 54 | `KeGetCurrentIrql` | 0x8001740C | none |
| 55 | `KeQueryPerformanceCounter` | 0x80017124 | `PLARGE_INTEGER Frequency` |
| 56 | `KeStallExecutionProcessor` | 0x800172B0 | `ULONG Microseconds` |
| 57 | `KfLowerIrql` | 0x80015090 | `KIRQL` |
| 58 | `KfRaiseIrql` | 0x800173E8 | `KIRQL` |
| 59–64 | `READ_PORT_BUFFER_UCHAR/ULONG/USHORT`, `READ_PORT_UCHAR/ULONG/USHORT` | 0x80022F08–0x80022FA8 | there's no I/O port space on ARM: `KeBugCheckEx(0x04 INVALID_DATA_ACCESS_TRAP, Port, 0 (read), size, …)` |
| 65–70 | `WRITE_PORT_BUFFER_UCHAR/ULONG/USHORT`, `WRITE_PORT_UCHAR/ULONG/USHORT` | 0x80022E48–0x80022EE8 | same, with parameter 2 = 1 (write) |

The rest of the HAL interface isn't exported: it's given to the kernel by filling `HalDispatchTable` and `HalPrivateDispatchTable` during the init phases (e.g. `HalDispatchTable` + 0x30 = `HaliInitPnpDriver`; `HalPrivateDispatchTable` + 0x18 = `HaliSetWakeAlarm`, + 0x100/+0x104 = interrupt remapping, + 0x120…+0x128 = PMC counter sets, + 0x170…+0x184 = clock timer functions, + 0x130 = `HalpTimerQueryCycleCounter`, + 0xD4 = `HalpTimerNotifyProcessorFreeze`).

### Startup

`HalInitSystem` (0x8003B038): phase 0 initialises the `/GS` cookie and calls `HalpInitSystemPhase0`, phase 1 calls `HalpInitSystemPhase1`; any other phase is a bug check 0x5C.

The HAL is made of 19 subcomponents, listed with their name in `HalSubComponents`. `HalpInitSystemHelper(first, last, LoaderBlock)` (0x8003B098) calls, for each internal phase from `first` to `last`, the `InitSystem` function of every subcomponent with `(phase, current processor, LoaderBlock)`. A negative status is a `KeBugCheckEx(0x5C HAL_INITIALIZATION_FAILED, 0x8200, status, phase, subcomponent name)`.

| Subcomponent | Function | Phases with work |
|--------------|----------|------------------|
| Acpi | `HalpAcpiInitSystem` | 6 (`HalpAcpiInitDiscard`: RSDP / RSDT / XSDT, table cache), 13 (audit: SLIC, RSDT/XSDT choice) |
| Dbg | `HalpDbgInitSystem` | 1 (debug device descriptor of the loader block, `HalpRegisterKdSupportFunctions`, `DBGP` table) |
| Dma | `HalpDmaInitSystem` | 4/8 (cache, `HalpCacheInitializeProcessor`), 6 (controller lists), 7 (`HalpDmaInitDiscard`), 19 (`HalpDmaInit`: master adapter, map buffers), 23 (power management) |
| Dp | `HalpDpInitSystem` | 6 (dynamic partitioning, only for interrupt model 2) |
| Errata, Hv, Whea | `HalpHvInitSystem` | none (returns 0) |
| Firmware | `HalpFirmwareInitSystem` | 6 (`HalpFirmwareInitDiscard`: UEFI runtime services) |
| HalExt | `HalpHalExtInitSystem` | 7 ([HalpExtInitExtensions](#hal-extensions)) |
| HwPerfCnt | `HalpHwPerfCntInitSystem` | 10, 15 (profiling, PMC counter sets) |
| Interrupt | `HalpInterruptInitSystem` | 0 (dispatch table), 4/6/8 (controllers, MADT), 12 (end of controller registration), 13/15 (startup stub, NMI, performance interrupt), 17 (bug check 0x5C (0x203) if the controller reported a problem), 23 (power management) |
| Iommu | `HalpIommuInitSystem` | — |
| Misc | `HalpMiscInitSystem` | 0 ([boot options](#boot-options)), 6 |
| Mm | `HalpMmInitSystem` | 0, 12, 13 (memory caching requirements table) |
| Pci | `HalpIommuSupportEnabled` (stub) | none |
| Pnp | `HalpPnpInitSystem` | 6 (`HalDispatchTable` + 0x30 = `HaliInitPnpDriver`) |
| Power | `HalpPowerInitSystem` | 7, 13 (FPDT mappings, sleep code lock) |
| Proc | `HalpProcInitSystem` | 9, 15 (feature bits) |
| Timer | `HalpTimerInitSystem` | 1 (early stall source), 11 (timer selection, clock, profiling; bug check 0x5C (0x110) on failure), 13, 15 (other processors), 17 (periodic queries, QPC bypass), 19 (system watchdog), 23 (power management, watchdog reset log) |

Phase order: 0–3 `HalInitializeProcessor` on the boot processor (4–5 on the others), 6–12 `HalInitSystem(0)`, 13–14 `HalInitSystem(1)` on the boot processor (15–16 on the others), 17–18 `HalAllProcessorsStarted`, 19–20 at the start of the `ACPI_HAL\PNP0C08` PDO (`HalpDispatchPnp`), 21–24 `HalReportResourceUsage`.

### HAL extensions

`HalpExtInitExtensions` (0x8003F144, phase 7):
1. Counts the HAL extension modules of the list at +0x858 of the loader parameter block extension (+0x74 of the loader block), filled by the boot loader. If there's none it returns.
2. Allocates one 32-byte [handle](#extension-handle) per module (`HalpExtHandleArray`, `HalpExtHandleCount`), and gets the `CSRT` table with `HalAcpiGetTable`. Without CSRT nothing is called.
3. For each module, in list order (the index is the handle):
   - if its load status (+0x14) is negative: `DbgPrintEx(101, 0, "HAL Extension %s failed load, status=0x%x\n", name (+0x18), status)`;
   - otherwise it calls the entry point of the image (`LDR_DATA_TABLE_ENTRY` at +0x08, `EntryPoint` at +0x1C) with `(0, &ExportTable, HalExtensionServices)`. This is the `start (Reserved, ExportTable, HalServices)` of the extension pages;
   - if the call succeeds and `ExportTable` isn't NULL: the handle is filled, its "active" flag set, then the first function of the export table (`AddResourceGroup`) is called once per resource group of the module (list at +0x0C, each entry holds at +0x08 the offset of the resource group in the CSRT) as `AddResourceGroup(Handle, CSRT + offset)`. The flag is cleared at the end: an extension can only register resources from its `AddResourceGroup`.
4. Always returns `STATUS_SUCCESS`.

Which CSRT resource group goes to which extension is decided by the boot loader (not in this binary).

#### Extension handle

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 1 | Active: 1 while `AddResourceGroup` runs |
| 0x04 | 4 | Entry point |
| 0x08 | 4 | Export table returned by the extension |
| 0x0C | 4 | 0 |
| 0x10 | 8 | List of the registered descriptors (24-byte entries: link, status at +0x08, descriptor at +0x0C, `Type`/`Subtype`/`Uid` of the CSRT descriptor at +0x10/+0x12/+0x14) |
| 0x18 | 4 | `DllBase` |
| 0x1C | 4 | `SizeOfImage` |

#### HAL extension services

`HalExtensionServices`, 0x8002E0E4, passed to the entry point of each extension. The extension pages call it the [HAL services table](./qchalextq8x60bam.md#hal-services).

| Offset | Function | Parameters |
|--------|----------|------------|
| +0x00 | `HalpExtRegisterResourceDescriptor` (0x8001AF9C) | `(Handle, ResourceGroup, ResourceDescriptor, InitializationBlock)`, see [below](#registerresourcedescriptor) |
| +0x04 | `HalpExtGetNextResourceDescriptor` (0x8001D980) | `(Handle, ResourceGroup, Previous, USHORT Type, USHORT Subtype, ULONG Uid)`: walks the descriptors of the group, starting after the group header and its shared info (group +0x14 + 0x18) when `Previous` is NULL; 0xFFFF matches anything. Stops at a descriptor shorter than 12 bytes or at the end of the group (group +0x00 `Length`). Returns the descriptor or NULL |
| +0x08 | `HalpExtGetAcpiTable` (0x8002B568) | `HalpAcpiGetTable` with the HAL's loader block |
| +0x0C | `HalMapIoSpace` (0x8001B378) | `(PHYSICAL_ADDRESS, Size, MEMORY_CACHING_TYPE)` |
| +0x10 | `HalUnmapIoSpace` (0x80025BD8) | `(VirtualAddress, Size)` |
| +0x14 | `HalRegisterPermanentAddressUsage` (0x8001AD30) | `(PHYSICAL_ADDRESS, Size)` |
| +0x18 | `HalSetTimerProblem` (0x80022E18) | `(Timer, Problem, Status)`: stored in the registered timer whose identifier matches |
| +0x1C | `HalUpdateTimerCapabilities` (0x80023D38) | `(Timer, SetCapabilities, ClearCapabilities)`: only bits 13–14 (0x6000) may change, else `STATUS_INVALID_PARAMETER` |
| +0x20 | 0x8001E240 (shared stub, named `RtlRaiseException_0` by IDA) | ? |

The table is followed by the default profiling interface (`DefaultInitializeProfiling`, `DefaultEnableMonitoring`, `DefaultDisableMonitoring`, `DefaultSetInterval`, `DefaultQueryInformation`, `DefaultOverflowHandler`, `DefaultRestartProfiling`).

#### RegisterResourceDescriptor

`HalpExtRegisterResourceDescriptor` (0x8001AF9C, `/GS`, no decompilation):
1. `STATUS_INVALID_PARAMETER`-like failure if a pointer is NULL, the handle is out of range or not active.
2. If the same resource (same group `VendorId`, `SubvendorId`, `DeviceId`, `SubdeviceId`, `Revision` and same descriptor `Uid`) was already registered by this extension, the previous status is returned.
3. Otherwise a record is added to the handle list, and a resource id string is built from the group header and the descriptor: `VEN_%.4S&DEV_%04x&SUBVEN_%.4S&SUBDEV_%04x&REV_%04x&%sUID_%08x` ("Unknown Resource" on failure).
4. Dispatch on the descriptor `Type` (+0x04) and `Subtype` (+0x06):

| Type, subtype | Function | Initialization block |
|---------------|----------|----------------------|
| 2, 0 (timer) | `HalpTimerRegister` | [Timer initialization block](#timer-initialization-block) |
| 3, 0 (DMA channel) | `HalpRegisterDmaChannel` | [DMA channel initialization block](#dma-channel-initialization-block) |
| 3, 1 (DMA controller) | `HalpRegisterDmaController` | [DMA controller initialization block](#dma-controller-initialization-block) |
| 4, 0 (cache) | `HalpRegisterCache` | [Cache initialization block](#cache-initialization-block) |
| other | — | `STATUS_NOT_IMPLEMENTED` (0xC0000002) |

The status is kept in the record and returned.

#### DMA controller initialization block

Checks made by `HalpRegisterDmaController` (0x8001D36C). Layout as built by the extensions: [BAM](./qchalextq8x60bam.md#dma-controller-initialization-block), [ADM3](./qchalextqcadm3dma.md#dma-controller-initialization-block).

| Offset | Size | Use by the HAL |
|--------|------|----------------|
| 0x00 | 4 | Version: must be 1 |
| 0x04 | 4 | Size: must be 0x44 (else `STATUS_INVALID_PARAMETER`) |
| 0x08 | 4 | **Written by the HAL**: the controller id, `++HalpDmaLastControllerId` (initial value −1, so 0, 1, 2… in registration order). The value set by the extension is ignored; both Qualcomm extensions read it back after the call and use it in their channel blocks |
| 0x0C | 4 | Number of channels: one 0x60-byte channel record each |
| 0x10 | 1 | Copied (controller +0x2C) |
| 0x14 | 4 | Copied (+0x30) |
| 0x18, 0x1C | 4, 4 | Copied (+0x5C, +0x60) |
| 0x20, 0x24 | 4, 4 | Minimum / maximum request line (+0x14, +0x18), used to find the controller of a request line (`HalpFindDmaControllerByRequestLine`) |
| 0x28 | 1 | Generates interrupt; if set, +0x2C GSIV, +0x30 polarity ?, +0x34 mode ? are kept |
| 0x38, 0x3C | 4, 4 | Internal data and its size: **copied** into the HAL's own controller allocation; the HAL then passes its copy to the DMA functions |
| 0x40 | 4 | DMA function table: its 10 pointers are copied (controller +0x34…+0x58) |

The controller is inserted in `HalpDmaControllers`; its name is the resource id string.

#### DMA channel initialization block

`HalpRegisterDmaChannel` (0x8001B214):

| Offset | Size | Use by the HAL |
|--------|------|----------------|
| 0x00 | 4 | Version: must be 1 |
| 0x04 | 4 | Size: must be 0x24 |
| 0x08 | 4 | Controller id: must be the id of a registered controller (the HAL-assigned one), else `STATUS_INVALID_PARAMETER` |
| 0x0C | 1 | Channel generates its own interrupt; if set, +0x10, +0x14, +0x18 (GSIV, polarity ?, mode ?) are kept |
| 0x1C | 4 | Common buffer length. When not 0 the controller must implement `ReportCommonBuffer` (function table index 8), else `STATUS_INVALID_PARAMETER` |
| 0x20 | 4 | Channel number: index of the channel record (no range check) |

Each channel gets a DPC (`HalpDmaControllerDpcRoutine`) and a request queue.

#### Timer initialization block

`HalpTimerRegister` (0x8001AD94, `/GS`) only accepts registrations while `HalpTimerRegistrationAllowed` is set. Fields from the checks and from the HAL's own registrations (cycle counter, WDAT watchdog):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Version: 1 |
| 0x04 | 4 | Size: 0x68 |
| 0x08 | 0x28 | Function table (10 pointers: +0x08 initialize, +0x0C query counter, +0x14 arm timer, +0x18 stop, …) |
| 0x30, 0x34 | 4, 4 | Internal data and size (copied, once per instance) |
| 0x38 | 4 | Counter bit width (64 for the cycle counter) |
| 0x40 | 8 | Frequency (0 = to be measured) |
| 0x48 | 4 | ? (1 for the cycle counter) |
| 0x4C | 4 | Capabilities. Bits 20–31 must be 0; several combinations are checked (0x400, 0x800, 0x1000, 0xA00 needs +0x18; 0x10000 = per-processor) |
| 0x60 | 4 | Known type, must not be 0 (10 = cycle counter, 13 = WDAT watchdog) |
| 0x64 | 4 | Copied |

Registered timers are in `HalpRegisteredTimers`; the HAL then picks the clock, performance counter, stall, profiling, always-on and watchdog sources (`HalpTimerSelectRoles`, `HalpTimerFindIdeal*`). `USEPLATFORMCLOCK` / `USEPLATFORMTICK` force the platform sources.

#### Cache initialization block

`HalpRegisterCache` (0x8001D4F8): only accepted when `MIDR` is an ARM Ltd core (implementer 0x41) with part 0xC09 (Cortex-A9) or 0xC05 (Cortex-A5), otherwise `STATUS_NOT_SUPPORTED`. The Krait cores of the MSM8930 (implementer 0x51, Qualcomm) can't register an outer cache extension. A second registration returns 0x80000011 (`STATUS_DEVICE_BUSY`). Block: version 1, size 0x30, +0x08 copied, +0x0C/+0x10 internal data and size, +0x14…+0x2C function pointers ?.

### Interrupts

- The interrupt controller is the ARM GIC of the MADT (`APIC` signature, `HalpGicDiscover`): local unit address at MADT +0x24, GIC distributor entries (type 0x0C, ≥ 0x18 bytes) registered as I/O units, and the per-processor GIC CPU interface entries (type 0x0B, ≥ 0x28 bytes, enabled) reserved with `HalRegisterPermanentAddressUsage` (4 KB).
- Processors are started with the parking protocol of the MADT: `HalpInterruptSetProcessorStartContext` copies the processor state (928 bytes) into the parking page of the processor, writes the address of the startup stub and the mailbox, then `HalpGicStartProcessor` sends the wake-up IPI.
- Secondary interrupt controllers (GPIO controllers, e.g. through GpioClx) register with `HalpRegisterSecondaryIcInterface`. `HalpInitializeSecondaryInterruptServices` gives them 512 GSIVs starting at max(highest GSIV + 1, 1024), and `HalpRecordSecondaryGsivRange` writes the range to the [registry](#registry).
- MSI is disabled by `MSIPOLICY=FORCEDISABLE` or the errata rule `GUID_EM_DISABLE_MSI_RULE` `{CBC747F0-F1D8-4C8A-AAA7-0CAE4F4AE246}`; there's no PCI on this SoC.

### Timers

`HalpTimerRegisterBuiltinPluginsCommon` registers the HAL's own timers: the processor cycle counter (phase 0, `HalpCycleCounterDiscover`, known type 10, resource id `VEN_vvvv&DEV_dddd&…`), then the ARM generic timer of the `GTDT` (`HalpGitDiscover`) and the watchdog of the `WDAT` (or `WDRT`) table (`HalpWdatDiscover`, known type 13, `HalpWdatArmTimer` / `HalpWdatStop`). The timers of the CSRT come from the extensions. On the Lumia 520 there's no GTDT: the timers are the cycle counter, the WDAT watchdog (Krait timer block 0x0208A000) and the 5 timers of the [CSRT](#lumia-520-tables). The system watchdog is started at phase 19 unless `SYSTEMWATCHDOGPOLICY=DISABLED`; when the last reset came from it, phase 23 writes the [ETW event](#etw) and "System was rebooted due to system watchdog timeout.".

### Real-time clock and wake alarm

There's no CMOS: the real-time clock is the ACPI time device of [acpitime.sys](../drivers/acpitime.md).
- When the `ACPI_HAL` PDOs are created, `HalpPostPnpInitialize` registers `IoRegisterPlugPlayNotification(EventCategoryDeviceInterfaceChange, GUID_DEVICE_ACPI_TIME)`. `HalpDynamicDeviceInterfaceNotification` keeps the device object of the interface (`IoGetDeviceObjectPointer`) and drops it on `GUID_DEVICE_INTERFACE_REMOVAL`.
- `HalQueryRealTimeClock`: while the system isn't in a late power phase, `HalpQueryAcpiRealTimeClock` sends `IOCTL_ACPI_GET_REAL_TIME` (0x294210, 16-byte output) to that device, converts the ACPI time to UTC and checks it's not older than a minimum date; then local time unless `ExRealTimeIsUniversal`. On failure (no device yet, early boot), it falls back to a software clock (`HalpQueryVirtualRtc`).
- `HalSetRealTimeClock`: `IOCTL_ACPI_SET_REAL_TIME` (0x298214, 16-byte input) then updates the software clock (`HalpSetVirtualRtc`).
- `HaliSetWakeAlarm` (`HalPrivateDispatchTable` + 0x18): prints "HAL: Wake in %lu seconds on AC and in %lu seconds on DC", then `HalpArmAcpiWakeAlarm` sends four synchronous IOCTLs with an 8-byte buffer `{TimerIdentifier, Value}`: `IOCTL_SET_WAKE_ALARM_VALUE` (0x298200) for timer 0 (AC) with the AC delay, `IOCTL_SET_WAKE_ALARM_POLICY` (0x298204) timer 0 = 1, then the same for timer 1 (DC). On the Lumia 520 the firmware has no `_STV`/`_STP`, so these fail; the legacy path `HalpSetWakeAlarm` is a stub returning `STATUS_NOT_SUPPORTED`.

### Plug and Play

`HaliInitPnpDriver` creates the driver `\Driver\ARM_HAL` (`IoCreateDriver`). `HalpDriverEntry` reports a detected device and adds:
- the FDO, hardware / compatible id `ACPIARM`;
- the PDO `ACPI_HAL\PNP0C08` (instance `0`), the ACPI root device where [acpi.sys](../drivers/acpi.md) loads. Its start runs `EtwRegister` and init phases 19–20. It answers `GUID_BUS_INTERFACE_STANDARD` with `HaliGetDmaAdapter` (system DMA adapters of the extensions' controllers);
- the PDO `ACPI_HAL\UEFI`, only when `\REGISTRY\MACHINE\HARDWARE\UEFI` exists (UEFI firmware resource table).

### Firmware

UEFI only (`HalFirmwareTypeEfi`): `HalGet/SetEnvironmentVariableEx`, `HalEnumerateEnvironmentVariablesEx`, `HalQueryEnvironmentVariableInfoEx`, capsules (`HalEfiQueryCapsuleCapabilities`, `HalEfiUpdateCapsule`) and `HalEfiResetSystem`. A reboot (`HalpReboot`) disables the interrupts, calls the reset function of every timer that has one (capability bit 1), then `HalpPowerWriteResetCommand`: optional reboot handler, then UEFI `ResetSystem(EfiResetWarm)`, then `EfiResetCold`.

### Boot options

Searched in the loader options string (`strstr`) by `HalpMiscGetParameters` and `HalpSetPlatformFlags`:

| Option | Variable |
|--------|----------|
| `SAFEBOOT:` | `HalpSafeBootMode` |
| `ONECPU` | `HalpInterruptProcessorCap` |
| `USEPHYSICALAPIC` | `HalpInterruptPhysicalModeOnly` |
| `BREAK` | `HalpMiscDebugBreakRequested` |
| `MAXPROCSPERCLUSTER=n` | `HalpInterruptForceClusterMode(n)` |
| `MAXAPICCLUSTER=n` | `HalpInterruptMaxCluster` |
| `SYSTEMWATCHDOGPOLICY=DISABLED` | `HalpTimerWatchdogDisable` |
| `CONFIGACCESSPOLICY=DISALLOWMMCONFIG` | `HalpAvoidMmConfigAccessMethod` |
| `MSIPOLICY=FORCEDISABLE` / `FORCEMSI` | `HalpInterruptSetMsiOverride(0 / 1)` |
| `FIRSTMEGABYTEPOLICY=USEALL` | `HalpMiscDiscardLowMemory` = 0 |
| `USEPLATFORMCLOCK` | `HalpTimerPlatformSourceForced` |
| `USEPLATFORMTICK` | `HalpTimerPlatformClockSourceForced` |
| `DISABLEEXTCACHE` | `HalpCacheDisabled` |
| `PROFILEACROSSHALTOVERRIDE` | `HalpHwPerfCntProfileAcrossHaltOverride` |
| `FORCELEGACYPLATFORM` | skips the FADT ≥ 5 platform flags |

### ACPI tables

Looked up by the HAL: RSDP / `RSDT` / `XSDT`, `FACP` (FADT), `FACS`, `DSDT`, `APIC` (MADT, GIC), `GTDT` (generic timer), `CSRT` ([HAL extensions](#hal-extensions)), `WDAT` / `WDRT` (watchdog), `DBGP` (debug port), `FPDT`, `WAET`, `SLIC` (audit), `SRAT`, `SLIT`, `MSCT`, `MPST` (NUMA), `DMAR`. Error messages: "HalpAcpiFindRsdp: Could not find RSDP", "HalpAcpiTableCacheInit: Unable to map RSDT", …

### Lumia 520 tables

The UEFI driver `AcpiPlatform` (in the `UEFI` partition) loads the tables as files from the `ACPI` folder of the `PLAT` partition (GUID `543C031A-4CB6-4897-BFFE-4B485768A8AD`, "ACPI: Loading table: %a."). The folder holds `bgrt.acp`, `csrt.acp`, `dbg2.acp`, `dsdt.aml`, `facp.acp`, `facs.acp`, `fpdt.acp`, `madt.acp`, `ssdt.aml`, `tpm2.acp` and `wdat.acp`. The DSDT and SSDT are the ones of [content/acpi](../acpi/README.md). OEM ID `QCOM`, table ID `QCOMEDK2`; the checksums are left at 0 (patched at load ?).

There's **no GTDT**: the ARM generic timer isn't used (the Krait timers come from the CSRT), and there's no SRAT/SLIT, DMAR or DBGP.

| Table | Content used by the HAL |
|-------|-------------------------|
| `FACP` (rev 5, 0xF4 bytes) | PM profile 8 (tablet); flags 0x00300000 = `HW_REDUCED_ACPI` + `LOW_POWER_S0_IDLE_CAPABLE`; reset register: space 3, address 0x009020B4, value 1; no PM1/GPE blocks |
| `APIC` (MADT rev 3) | GIC CPU interface 0x02002000; 2 GICC entries (40 bytes, old format): CPU interface 0 and 1, enabled, parking protocol version 1, parked address 0x80301000 / 0x80302000, performance interrupt GSIV 26; GIC distributor (GICD) 0x02000000, GSI base 0 |
| `WDAT` | Watchdog of the Krait per-CPU timer block at 0x0208A000: 1 ms period, count 1…300000 (5 minutes), enabled. 14 instructions on +0x38 (reset), +0x40 (enable), +0x44, +0x4C, +0x5C (counts, 0x1B77400 = 28800000), +0x88 bit 24 (state) |
| `CSRT` | 4 resource groups, see below |
| `DBG2` | 3 debug devices: `\_SB.UAR1` serial (type 0x8000, subtype 4) at 0x16440000; `\_SB.UFN1` at 0x12500000 as type 0x8003 (subtype 0x5143) and type 0x8002 (subtype 4) |
| `FPDT` | boot performance record at 0x80380000 |
| `BGRT` | boot logo image at 0x80C00000 |
| `TPM2` | start method 5 |
| `FACS` | 64 bytes, all zero |

CSRT resource groups (vendor `QCOM`). The extension that takes each group is chosen by the boot loader; the match below comes from the descriptor formats each extension parses.

| Group (device id) | Descriptors | Extension |
|-------------------|-------------|-----------|
| 0x1001 | 4 timers (type 2), UID 1, 2, 4, 5; shared info (0x20 bytes) 0x0200A000, 0, 0x1000, 2, 0x0208A000, 0, 0x0209A000, 0 | [HalExtQ8660Timers.dll](./halextq8660timers.md#addresourcegroup-sub_100013cc-0x100013cc) ? (the only analysed extension that parses timer descriptors): maps the block at shared info +0x10 (0x0208A000, size +0x08), registers the DGT and the GPT |
| 0x1002 | 1 DMA controller + 12 channels | [QCHalExtQcAdm3Dma.dll](./qchalextqcadm3dma.md#lumia-520-csrt): the ADM at 0x18300000 |
| 0x1003 | 1 timer (type 2), UID 1 | ? ([HalExtQ8660Timers.dll](./halextq8660timers.md#addresourcegroup-sub_100013cc-0x100013cc) accepts this group explicitly but registers nothing for it) |
| 0x1005 | 5 DMA controllers × 2 channels | [QCHalExtQ8x60Bam.dll](./qchalextq8x60bam.md#lumia-520-csrt): the BAMs of the 5 SD controllers |

Timer descriptors (bytes after the 12-byte header, as dwords; format of [HalExtQ8660Timers.dll](./halextq8660timers.md#timer-descriptor): +0x0C kind (1 = GPT, 2 = DGT, others ignored), +0x10 dword index of the `MATCH_VAL` register in the 0x0208A000 block, +0x14 frequency, +0x18 GSIV):

| Group, UID | +0x0C | +0x10 | +0x14 | +0x18 |
|------------|-------|-------|-------|-------|
| 0x1001, 1 | 2 | 9 | 0x0066FF30 (6750000: frequency of the DGT, 27 MHz / 4, `DGT_CLK_CTL` = 3) | 0x11 (GSIV 17 = PPI 1 ?) |
| 0x1001, 2 | 1 | 1 | 0x8000 (32768: frequency of the GPT, sleep clock ?) | 0x12 (GSIV 18 = PPI 2 ?) |
| 0x1001, 4 | 3 | 0x0E | 0 | 0x14 (GSIV 20 = PPI 4 ?) |
| 0x1001, 5 | 3 | 0x18 | 0 | 0x15 (GSIV 21 = PPI 5 ?) |
| 0x1003, 1 | 0x00200024 | 0 | 4 | 0 |

### Performance counters

ARM PMU through `HalAllocateHardwareCounters` and the profile sources of `ArmGetProfileDescriptor`: the generic sources (`TotalCycles`, `TotalIssues`, `BranchMispredictions`, `DcacheMisses`, `IcacheMisses`, …), the ARMv7 events (`SoftwareIncrement`, `ICacheRefill`, `InstructionTLBRefill`, `DCacheRefill`, `InstructionRetired`, `ExceptionTaken`, `BranchMisprediction`, `CycleCount`, `L2DCacheRefill`, …) and the Krait events `QualcommGroup0Event0`…`QualcommGroup2Event3`, `QualcommVenumEvent0`…`3`.

### Errata manager

`HalRegisterErrataCallbacks` registers an `EmpProviderRegister` provider with 6 callbacks used to match firmware errata rules: `GUID_HAL_CALLBACK_ACPI_OEM_ID` `{2960716F-B0D8-41C9-9BB4-EE8BA248F86E}` (`HalMatchAcpiOemId`), `_OEM_TABLE_ID` `{E0E45284-F266-4048-9A5E-7D4007C9C5AB}`, `_OEM_REVISION` `{7E8FAE0F-7591-4EB6-9554-1D0699873111}`, `_REVISION` `{BF51DEF4-AC9C-44F3-ADE7-26DD13E756D3}`, `_CREATOR_REVISION` `{BEAE4D5F-2203-4856-94BB-C772A2C7624A}`, `_FADT_BOOTARCH` `{7CD2B230-6CEA-4957-B5D7-CFA977C22B18}`.

### Registry

| Key | Value | Access |
|-----|-------|--------|
| `HKLM\SYSTEM\CurrentControlSet\Control\HAL\SecondaryInterrupts` | `SecondaryGsivBase`, `SecondaryGsivSize` (REG_DWORD) | Written (key created if needed): GSIV range of the secondary interrupt controllers |
| `HKLM\HARDWARE\UEFI` | — | Existence tested: creates the `ACPI_HAL\UEFI` PDO |

License value `Kernel-RegisteredProcessors` (`ZwQueryLicenseValue`, DWORD): maximum number of processors (× processors per group).

### Devices and IOCTLs

| Device | Driver | Use |
|--------|--------|-----|
| Interface `GUID_DEVICE_ACPI_TIME` `{97F99BF6-4497-4F18-BB22-4B9FB2FBEF9C}` | [acpitime.sys](../drivers/acpitime.md) | `IOCTL_ACPI_GET_REAL_TIME` 0x294210, `IOCTL_ACPI_SET_REAL_TIME` 0x298214, `IOCTL_SET_WAKE_ALARM_VALUE` 0x298200, `IOCTL_SET_WAKE_ALARM_POLICY` 0x298204 |
| `\DosDevices\ACPI_ROOT_OBJECT` | [acpi.sys](../drivers/acpi.md) | `GUID_PCC_INTERFACE_STANDARD` `{3EE8BA63-0F59-4A24-8A45-35808BDD1249}` |
| Callback `\Callback\PowerState` | ntoskrnl | `HalpPowerStateCallback` |

### ETW

Provider `HAL_ETW_PROVIDER` `{63D1E632-95CC-4443-9312-AF927761D52A}`, registered at the start of the `ACPI_HAL\PNP0C08` PDO (`HalpProcessAcpiStartDevice`).

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 13 (`HAL_ETW_EVENT_WATCHDOG_TRIGGERED`), channel 8 | 2 (error) | 0, 0 | 0x8000000000000000 | — | Phase 23, when the system watchdog caused the last reset (`HalpTimerWatchdogLogReset`) |
