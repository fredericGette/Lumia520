## NTOSKRNL.EXE

Windows NT kernel and executive of Windows Phone 8.1 for ARM (build `9651.0.armfre.winbluephone_gdr1.150113-1731`, `.text:0x4019B0`).  
It's the kernel image loaded first by the boot loader, with [HAL.dll](./hal.md), `kdcom.dll`, [bootvid.dll](./bootvid.md), `PSHED.dll`, [ci.dll](./ci.md) and the boot drivers. It contains every executive component of desktop Windows 8.1 (Ke scheduler / interrupts / IPIs, Mm memory manager, Ob object manager, Ps processes and threads, Se security, Io I/O manager and Plug and Play, Cm registry, Cc cache manager, Fs runtime, Po power manager with PoFx / PEP / PDC, Ex executive services with WNF and licensing, ETW / WMI, Kd debugger, Verifier, WHEA, Em errata manager, ALPC / LPC, Superfetch store manager). It's huge (15 697 functions, public symbols: 15 337 named), so this page only describes the main features, the boot sequence and what the drivers and libraries documented here get from it. The phone-specific parts are small: the `PhoneNT` product suite, the license "fast cache", the HW policy driver `hwpolicy.sys`, and the check of the Qualcomm processor.  
Every kernel-mode binary documented here imports it (e.g. [HAL.dll](./hal.md), [ci.dll](./ci.md), the `qc*8930.sys` drivers). It calls [HAL.dll](./hal.md) for everything hardware-specific, [ci.dll](./ci.md) to check image signatures, and starts `smss.exe`, the first user-mode process.

Location on the phone: `C:\Windows\System32\ntoskrnl.exe` ? (the extracted file `NTOSKRNL.EXE` has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| HAL | 50 of the 70 [HAL.dll](./hal.md) exports: `HalInitSystem`, `HalInitializeProcessor`, `HalStartNextProcessor`, `HalAllProcessorsStarted`, `HalReportResourceUsage`, interrupts (`HalBeginSystemInterruptUnspecified`, `HalEndSystemInterrupt`, `HalEnable/DisableInterrupt`, `HalRequestIpi`, `HalRequestSoftwareInterrupt`, `HalRequestClockInterrupt`), `KfRaiseIrql`, `KfLowerIrql`, `KeGetCurrentIrql`, `KeQueryPerformanceCounter`, `KeStallExecutionProcessor`, UEFI variables (`Hal*EnvironmentVariable*`), `HalQuery/SetRealTimeClock`, `HalReturnToFirmware`, `HalProcessorIdle`, `HalAcpiGetTableEx`, `READ_PORT_UCHAR`, `WRITE_PORT_UCHAR`, … The rest of the HAL is reached through `HalDispatchTable` / `HalPrivateDispatchTable` |
| kdcom | `KdDebuggerInitialize0`, `KdDebuggerInitialize1`, `KdSendPacket`, `KdReceivePacket`, `KdD0Transition`, `KdD3Transition`, `KdSave`, `KdRestore`, `KdSetHiberRange`: the kernel debugger transport |
| [BOOTVID](./bootvid.md) | `VidInitialize`, `VidResetDisplay`, `VidCleanUp`, `VidDisplayString`, `VidSetTextColor`, `VidSetScrollRegion`, `VidSolidColorFill`, `VidBitBlt`, `VidBitBltEx`, `VidBufferToScreenBlt`, `VidScreenToBufferBlt`: VGA boot screen (`Bvga*` / Inbv), unusable on this phone |
| PSHED | 18 functions (`PshedInitialize`, `PshedGetAllErrorSources`, `PshedReadErrorRecord`, `PshedWriteErrorRecord`, `PshedBugCheckSystem`, …): WHEA platform-specific hardware error driver |
| CI | `CiInitialize`, see [Code integrity](#code-integrity) |
| msrpc | `NdrMesTypeEncode2`, `NdrMesTypeDecode2`, `MesEncodeIncrementalHandleCreate`, `MesDecodeBufferHandleCreate`, `MesIncrementalHandleReset`, `MesHandleFree`, `RpcExceptionFilter`: RPC serialisation |
| ext-ms-win-fs-clfs-l1-1-0 | 23 `Clfs*` functions (common log file system, used by the transaction manager / registry) |
| ext-ms-win-ntos-tm-l1-1-0 | 76 functions: the kernel transaction manager (`Tm*`, and the `Nt*Transaction*`, `Nt*Enlistment*`, `Nt*ResourceManager*` system calls are forwarded to it) |
| ext-ms-win-ntos-werkernel-l1-1-0 | `WerLiveKernelInitSystem`, `WerLiveKernelCreateReport`, `WerLiveKernelSubmitReport`, `WerLiveKernelCancelReport`, `WerLiveKernelOpenDumpFile`, `WerLiveKernelCloseHandle`: live kernel dumps |
| ext-ms-win-ntos-kcminitcfg-l1-1-0 | `CmSetInitMachineConfig`, `CmCompleteInitMachineConfig` |
| ext-ms-win-ntos-ksr-l1-1-0 | `KsrInitPageDatabase`, `KsrCleanupPageDatabase` (kernel soft restart) |
| ext-ms-win-ntos-ksecurity-l1-1-1 | `AppContainerPrivilegesEnabledExt`, `QueryUpdateFileEaAllowedExt` |
| ext-ms-win-ntos-ksigningpolicy-l1-1-0 | `SeQuerySigningPolicyExt` |

The `ext-ms-win-*` names are API sets resolved by the boot loader; the module that implements each one on the phone isn't known from this binary (`tm.sys` and `clfs.sys` are in the list of [boot images](#dependencies)). The kernel has no CRT import: `memcpy`, `str*`, `wcs*`, `sprintf`… are part of it and exported.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\SystemRoot\System32\smss.exe` | `RtlCreateUserProcess` in [StartFirstUserProcess](#startfirstuserprocess-0x8ba09c) | First user-mode process (session manager) |
| `\SystemRoot\System32\ntdll.dll` | `PsLocateSystemDlls` (`IoInitSystemPreDrivers`) | Mapped in every process: user-mode entry points of the system calls, APC / exception dispatchers |
| `\SystemRoot\System32\win32k.sys` | Name checked by `NtSetSystemInformation` (load of the session driver) | Win32 kernel driver, loaded on request of `smss.exe` ? |
| `\SystemRoot\System32\Drivers\crashdmp.sys` | `IoInitializeCrashDump` | [crashdmp.sys](../drivers/crashdmp.md): crash dump stack (with [dumpsd.sys](../drivers/dumpsd.md), [dumpfve.sys](../drivers/dumpfve.md)) |
| `hwpolicy.sys` | `KiHwPolicyFindDriverImage` (0x8C3CE0): looked up in the list of loaded boot images (`KeHwPolicyLocateResource`) | HW policy driver ? (not analysed) |
| `ntoskrnl.exe`, `ndis.sys`, `ci.dll`, `pshed.dll`, `clfs.sys`, `kdcom.dll`, `hal.dll`, `bootvid.dll`, `tm.sys`, `msrpc.sys`, `ntfs.sys`, `fltmgr.sys`, `tcpip.sys`, … | Table of `UNICODE_STRING`s at `PAGEVRFY:0x82A000`, used by `ViInitSystemPhase0`, `ViDriverReApplyVerifierForAll`, `VfInitSystemNoRebootNeeded` | Core images handled specially by the driver verifier |
| `\Boot\BCD`, `\EFI\Microsoft\Boot\BCD` | `BcdInitializeBcdSyncMutant`, `\KernelObjects\BcdSyncMutant`, `HKLM\SYSTEM\CurrentControlSet\Control\BCD` | Boot configuration database |
| `C:\pagefile.sys`, `\hiberfil.sys` | Memory manager, power manager | Paging file, hibernation file |
| Registry hives `SYSTEM`, `SOFTWARE`, `SAM`, `SECURITY`, `ELAM`, `HARDWARE` | Configuration manager (`CmInitSystem1`) | Registry |

### Exports

2 432 exports, all with their public names, grouped by prefix:

| Prefix | Count | Component |
|--------|-------|-----------|
| `Rtl` | 377 | Run-time library (strings, bitmaps, AVL tables, compression, SIDs / ACLs, `RtlIsPackageSid`…) |
| `Io`, `Iof` | 294 | I/O manager: driver / device objects, IRPs, PnP, interfaces, WMI (`IoWMI*`), work items, crash dump |
| `Ke`, `Ki`, `Kse` | 246 | Kernel: dispatcher objects, DPCs, timers, spin locks, IRQL, affinity, bug check callbacks; shim engine |
| `Zw`, `Nt` | 322 | System services callable from kernel mode (`Zw*`) and a subset of the system calls (`Nt*`) |
| `Fs`, `Cc` | 270 | File system run-time library, cache manager |
| `Ex`, `Exf`, `Exp` | 167 | Executive: pool, lookaside lists, resources, push locks, callbacks, WNF (`ExSubscribeWnfStateChange`, `ExQueryWnfStateData`…), licensing |
| `Ps` | 118 | Processes, threads, notify routines, jobs |
| `Mm` | 96 | Memory manager: MDLs, I/O space mappings, contiguous memory, sections, system images |
| `Se` | 92 | Security reference monitor, tokens, access checks, audits, code integrity / signing level |
| `Po`, `PoFx`, `Pdc` | 60 | Power manager: power IRPs, power settings, [PoFx](#power-framework) |
| `Ob`, `Obf` | 47 | Object manager |
| `Tm` | 39 | Transaction manager (forwarded to the `tm` API set) |
| `Etw`, `Wmi`, `Pcw` | 23 | Event tracing, WMI, performance counters |
| others | | `Kd` (debugger), `Inbv` (boot video), `Hvl` (hypervisor, unused), `Dbg`, `Vf` (verifier), `Cm`, `Em` (errata), `Ldr`, `Lpc` / `Alpc`, `Lsa`, `Nls`, `Whea`, `Bgk`, `Hal` (`HalDispatchTable`, `HalPrivateDispatchTable`), CRT functions |

The parameters are those of the public WDK prototypes. The exports used by the documented drivers are mostly the usual WDM ones (`ExAllocatePoolWithTag`, `IoCreateDevice`, `IofCompleteRequest`, `KeWaitForSingleObject`, `MmMapIoSpace`, `PoFx*`, `EtwRegister`…); [HAL.dll](./hal.md) imports 197 of them (list in its page), [ci.dll](./ci.md) about 200.

There are 433 system calls (`KiServiceLimit`, table `KiServiceTable` / `KiArgumentTable`, entry `KiSystemService` 0x420500, descriptor `KeServiceDescriptorTable` 0x624400).

### Startup

The boot loader calls `KiSystemStartup` (0x626000, entry point of the image) on each processor with the `LOADER_PARAMETER_BLOCK`. The kernel initialisation runs in three steps: the kernel itself, phase 0 of the executive on the boot processor (interrupts disabled, single thread), then phase 1 in the `Phase1Initialization` system thread.

#### KiSystemStartup (0x626000)

1. Saves the loader block in `KeLoaderBlock`, sets up the processor control region (`TPIDRPRW`, CP15 c13) and the stacks of the FIQ / IRQ / undefined / abort / supervisor modes (`CPS`).
2. `KiInitializeBootStructures`, then `KdInitSystem(0)` on the boot processor (debugger initialisation through [kdcom](#imports)).
3. `KiInitializeKernel`, then waits for `KiBarrierWait` and enters `KiIdleLoop`: the boot thread becomes the idle thread.

#### KiInitializeKernel (0x627FE4)

1. If the processor has no VFP / NEON (feature bit 0x80): `KeBugCheckEx(0x5D UNSUPPORTED_PROCESSOR, 9, MVFR0, MVFR1)`.
2. Boot processor: initialises node 0 and the processor groups, compacts the system call table (`KeCompactServiceTable(KiServiceTable, KiArgumentTable, 433)`), sets `KeProcessorArchitecture` = 5 (ARM), `KeProcessorLevel` / `KeProcessorRevision` from the PRCB. If the CPU isn't a Qualcomm Scorpion (`MIDR` implementer 0x51, part 0x02D) it sets `KiCP14DebugEnabled` = 1: on the Krait of the MSM8930 the CP14 debug registers are used. Then `KiInitSystem`, initial process (`KeInitializeProcess`), wait-list keys `KiWaitNever` / `KiWaitAlways`.
3. Other processors: `KeBugCheckEx(0x3E MULTIPROCESSOR_CONFIGURATION_NOT_SUPPORTED, …)` if their feature bits or cache information differ from the boot processor's.
4. `KiInitializeIdleThread`, then `InitBootProcessor` (boot processor) or `InitOtherProcessors`, and `KiCompleteKernelInit`.

#### InitBootProcessor (0x8AFB8C)

Phase 0 of the executive: checks the loader block (`ExpValidateLoader`), boot options `BURNMEMORY` and `FORCEGROUPAWARE`, NLS tables, WHEA defaults, `KeInitializeClock`, `CmGetSystemControlValues` (values of `HKLM\SYSTEM\CurrentControlSet\Control` read from the loader's copy of the SYSTEM hive), timer table, then `ExInitSystem`, `KeNumaInitialize`, `VerifierInitSystem`, `MmInitSystem`, `InbvDriverInitialize`, `ObInitSystem`, `SeInitSystem`, `PsInitSystem` (creates the System process and the `Phase1Initialization` thread), `DbgkInitialize`, `PpInitSystem`.

#### Phase1Initialization (0x813494)

1. `Phase1InitializationDiscard` (below).
2. Boot progress bar 25…75 %, `IoInitSystem`: a failure is `KeBugCheck(0x69 IO1_INITIALIZATION_FAILED)`.
3. `Phase1InitializationIoReady` (below).
4. The thread then becomes the zero page thread (`MmZeroPageThread`).

`Phase1InitializationDiscard` (0x8C7C14, `INIT`), in order: group configuration, `KeInitializeClock`, boot video (`NOGUIBOOT`, `BgkDisplayProgressIndicator`, `InbvDriverInitialize`, `DisplayBootBitmap`), version banner "MICROSOFT (R) WINDOWS (TM)", `PoInitSystem(0)`, system time from the RTC (`YEAR=`, `KeSetSystemTime`), processor count (`Kernel-RegisteredProcessors` license value, `BOOTPROC=`, `NUMPROC=`, `MAXPROC`), `KeStartAllProcessors` (starts the other Krait core through [HalStartNextProcessor](./hal.md#exports)), `ObInitSystem`, `ExInitSystem`, `IoCreateObjectTypes`, cache flush thresholds, `KdInitSystem`, `TmInitSystem`, `DbgkInitialize`, `BcdInitializeBcdSyncMutant`, `VerifierInitSystem`, `SeInitSystem`, `ExInitLicenseCallback`, `CreateSystemRootLink`, `MmInitSystem`, NLS section, `CcInitializeCacheManager`, `CmInitSystem1` (registry), `EmInitSystem`, `PfInitializeSuperfetch`, `SmInitSystem`, `FORCETIMESYNC` / time zone (WNF `WNF_BOOT_INVALID_TIME_SOURCE`), `FsRtlInitSystem`, `KdDebuggerInitialize1`, `PpInitSystem`, `LpcInitSystem`, `SAFEBOOT:` options, `BOOTLOG`, `ExInitSystemPhase2`, `SeCodeIntegrityInitializePolicy`, `ExInitializeNls`, `KeArmDiscoverCacheTopology`, `PoInitSystem(1)`.

`IoInitSystem` (0x8C94D4): `IoInitSystemPreDrivers` (lookaside lists, `\Security\TRKWKS_EVENT`, root directories, PnP manager, `PnpMarkHalDeviceNode`, WMI / ETW, WHEA, `IopInitializeBootDrivers` (calls the `DriverEntry` of the boot drivers already loaded by the boot loader), `IoInitializeLiveDump`, `IopInitCrashDumpDuringSysInit`, `PsLocateSystemDlls`, `IopReassignSystemRoot`, `IopProtectSystemPartition`), then `IopInitializeSystemDrivers` (loads the `Start` = 1 services: `IopLoadDriver` → `MmLoadSystemImage`).

`Phase1InitializationIoReady` (0x8C7AB8): `EmInitSystem`, `TmInitSystemPhase2`, `InitSafeBoot`, `MmInitSystem`, `PoInitSystem`, `PsInitSystem`, `MmInitSystemDll`, `SeRmInitPhase1`, [StartFirstUserProcess](#startfirstuserprocess-0x8ba09c), `WerLiveKernelInitSystem`, `MmFreeLoaderBlock`.

#### StartFirstUserProcess (0x8BA09C)

1. Builds a process parameter block (`ExAllocatePoolWithQuotaTag`, 3272 bytes + environment) with the image `\SystemRoot\System32\smss.exe` (bug check 0x6D `SESSION1_INITIALIZATION_FAILED` if the allocation fails, 0x6E `SESSION2_INITIALIZATION_FAILED` if the session settings are invalid).
2. `RtlCreateUserProcess`, then `FinalizeBootLogo` if a boot video driver is installed. Failure: `KeBugCheckEx(0x6F SESSION3_INITIALIZATION_FAILED, status)`.
3. `ZwSetInformationProcess(ProcessBreakOnTermination (29), 1)` (0x70 on failure): if `smss.exe` ends, the system bug checks (0xEF `CRITICAL_PROCESS_DIED`).
4. `ZwResumeThread` (0x71 on failure), short delay, closes the handles.

### Boot options

Strings searched in the loader options (`LoaderBlock->LoadOptions`, upper case):

| Option | Read by | Effect |
|--------|---------|--------|
| `NOGUIBOOT` | `Phase1InitializationDiscard` | No boot graphics |
| `MININT`, `INRAM` | `Phase1InitializationDiscard`, `CreateMiniNtBootKey` | WinPE boot |
| `YEAR=` | `Phase1InitializationDiscard` | Overrides the year of the RTC time |
| `BOOTPROC=`, `NUMPROC=`, `MAXPROC`, `HYPERVISORNUMPROC=`, `HYPERVISORROOTPROC=`, `HYPERVISORROOTPROCPERNODE=` | `Phase1InitializationDiscard` | Processors started |
| `SAFEBOOT:MINIMAL` / `NETWORK` / `DSREPAIR` / `(ALTERNATESHELL)` | `Phase1InitializationDiscard` | Safe mode |
| `BOOTLOG` | `Phase1InitializationDiscard` | `IopInitializeBootLogging` |
| `FORCETIMESYNC` | `Phase1InitializationDiscard` | Time synchronisation at boot |
| `BURNMEMORY=`, `FORCEGROUPAWARE` | `InitBootProcessor` | Debug options |
| `DISABLE_INTEGRITY_CHECKS`, `TESTSIGNING`, `MINTCBIGNOREKD` | [SepInitializeCodeIntegrity](#code-integrity) | Code integrity options |

### Code integrity

`SepInitializeCodeIntegrity` (0x6E061C) clears the 52-byte callback table `SeCiCallbacks` (size 52 at +0, then 12 function pointers), computes the CI options from the boot options — 6 by default, 0 with `DISABLE_INTEGRITY_CHECKS`, bit 0x8 added with `TESTSIGNING`; `MINTCBIGNOREKD` sets bit 0x1 of a kernel global (0x5D8A5C) — and calls [CiInitialize](./ci.md#exports)`(CiOptions, &LoaderBlock->BootDriverListHead (+0x20), KernelApis (0x41C438), &SeCiCallbacks)`.

`SeValidateImageHeader` (0x6A1438), called for each image section, returns `STATUS_INVALID_IMAGE_HASH` (0xC0000428) if CI didn't fill the table, otherwise forwards to the CI callback at +0x10 (`off_5BD730`, [CiValidateImageHeader](./ci.md#civalidateimageheader-0x273fc)) and schedules the image verification callbacks. The table is described in [CipInitialize](./ci.md#cipinitialize-0x2563c).

### Product suite and licensing

`ExpUpdateProductSuiteTypeInRegistry` (0x8BA7BC) writes the product suite names as a `REG_MULTI_SZ` (`NtSetValueKey`, type 7); when `ExVerifySuite(16)` is TRUE it adds `PhoneNT` (the other names of the table are the desktop / server ones: "Embedded(Restricted)", "Blade", "Security Appliance", "Storage Server", "Compute Server", "WH Server"…). The key and value name aren't resolved here (`ProductOptions\ProductSuite` ?).

Licensing (`ZwQueryLicenseValue`, `ExFetchLicenseData`, `ExUpdateLicenseRegistry`, license tamper state) uses a phone "fast cache" of the licenses in the registry, created with a restricted DACL by `ExpCreateRestrictedFastCacheRegistryKey`:

| Key (`HKLM\System\CurrentControlSet\…`) | Use |
|------------------------------------------|-----|
| `Control\FastCache` (`Data`, `Limits`) | Root of the cache (`ExpParseFastCache`, `ExReArmFastCache`) |
| `Control\FastCache\ProductLicenses` | Product licenses (`ProductLicenseCacheMaxSize`) |
| `Control\FastCache\FeatureLicenses` | Feature licenses (`FeatureLicenseCacheMaxSize`) |
| `Control\FastCache\DevLicenses` | Developer licenses (`ExQueryFastCacheDevLicense`) |
| `Services\LicenseInfoSuites` | Suites of the license info |

License value used by the kernel: `Kernel-RegisteredProcessors` (processor count, also read by [HAL.dll](./hal.md#registry)).

### Power framework

The power manager includes the Windows 8 runtime power framework used by all the SoC drivers: `PoFxRegisterDevice`, `PoFxStartDevicePowerManagement`, `PoFxActivateComponent` / `PoFxIdleComponent`, `PoFxCompleteIdleState`, `PoFxPowerControl`… (see e.g. [qcpep8930.sys](../drivers/qcpep8930.md), [qcpepproxy8930.sys](../drivers/qcpepproxy8930.md), [wppower.sys](../drivers/wppower.md)), the processor power manager (`Ppm*`: idle states, performance states, core parking) and the PDC (power dependency coordinator, `Pdc*`: connected standby, screen off, buttons).

`PoFxRegisterPlugin(PEP_INFORMATION *, PEP_KERNEL_INFORMATION *)` (0x74A344) → `PopFxRegisterPluginEx` registers a platform extension plug-in (PEP), i.e. [qcpep8930.sys](../drivers/qcpep8930.md#pofx-registration):

1. `PEP_KERNEL_INFORMATION.Version` must be 1 or 2 (else 0xC000A004), `Size` ≥ 28 (≥ 44 for version 2); `PEP_INFORMATION.Version` ≤ 2 (else 0xC000A005) and, for version 2, `Size` = 12 and `AcceptDeviceNotification` ≠ NULL; otherwise `STATUS_INVALID_PARAMETER`.
2. Allocates the plug-in (pool tag `PFXM`) with one work order (timer + `PopFxWorkOrderWatchdog`, `PopFxPluginWork`), a queue and an emergency worker thread, and inserts it in the plug-in list.
3. Fills the kernel information:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 2 | Version (1 or 2) |
| 0x02 | 2 | Size |
| 0x04 | 4 | Plug-in handle |
| 0x08 | 4 | `PopFxRequestWorker` |
| 0x0C | 4 | `PopFxEnumerateUnmaskedInterrupts` |
| 0x10 | 4 | `PopFxProcessorHalt` |
| 0x14 | 4 | `PopFxRequestInterrupt` |
| 0x18 | 4 | `PopFxTransitionCriticalResource` |
| 0x1C | 4 | Version 2: `PopFxProcessorIdleVeto` |
| 0x20 | 4 | Version 2: `PopFxPlatformIdleVeto` |
| 0x24 | 4 | Version 2: `PopFxUpdateProcessorIdleState` |
| 0x28 | 4 | Version 2: `PopFxUpdatePlatformIdleState` |

### WNF states

The kernel implements WNF (`Nt*WnfState*` system calls, `ExpWnf*`, kernel subscriptions `ExSubscribeWnfStateChange` / `ExQueryWnfStateData` as used by [wppower.sys](../drivers/wppower.md)). States it publishes itself (`ZwUpdateWnfStateData`), all well-known, version 1, not permanent:

| Name | Owner, sequence | Scope | Published by |
|------|-----------------|-------|--------------|
| 0x1589012FA3BC0875 `WNF_BOOT_DIRTY_SHUTDOWN` | `BOOT`, 1 | system | `BapdWriteEtwEvents` |
| 0x1589012FA3BC1075 `WNF_BOOT_INVALID_TIME_SOURCE` | `BOOT`, 2 | system | `Phase1InitializationDiscard` |
| 0x0D941D2BA3BC0875 `WNF_FSRL_TIERED_VOLUME_DETECTED` | `FSRL`, 1 | system | `FsRtlpHeatRegisterVolume` |
| 0x0D941D2BA3BC1075 `WNF_FSRL_OPLOCK_BREAK` | `FSRL`, 2 | system | `FsRtlSendModernAppTermination` |
| 0x4192022BA3BC0875 `WNF_FLT_RUNDOWN_WAIT` | `FLT`, 1 | system | `FsRtlSendModernAppTermination` |
| 0x0096003DA3BC0875 `WNF_PNPA_DEVNODES_CHANGED` | `PNPA`, 1 | system | `PiUEventBroadcastDevnodesChangedEvent` (also subscribed by `PiUEventInit`) |
| 0x0096003DA3BC1035 `WNF_PNPA_DEVNODES_CHANGED_SESSION` | `PNPA`, 2 | session | `PiUEventBroadcastDevnodesChangedEvent` |
| 0x0096003DA3BC1875 `WNF_PNPA_VOLUMES_CHANGED` | `PNPA`, 3 | system | `PiUEventBroadcastVolumesChangedEvent` |
| 0x0096003DA3BC2035 `WNF_PNPA_VOLUMES_CHANGED_SESSION` | `PNPA`, 4 | session | `PiUEventBroadcastVolumesChangedEvent` |
| 0x0096003DA3BC2875 `WNF_PNPA_HARDWAREPROFILES_CHANGED` | `PNPA`, 5 | system | `PiUEventBroadcastHardwareProfilesChangedEvent` |
| 0x0096003DA3BC3035 `WNF_PNPA_HARDWAREPROFILES_CHANGED_SESSION` | `PNPA`, 6 | session | `PiUEventBroadcastHardwareProfilesChangedEvent` |
| 0x0096003DA3BC3875 `WNF_PNPA_PORTS_CHANGED` | `PNPA`, 7 | system | `PiUEventBroadcastPortsChangedEvent` |
| 0x0096003DA3BC4035 `WNF_PNPA_PORTS_CHANGED_SESSION` | `PNPA`, 8 | session | `PiUEventBroadcastPortsChangedEvent` |
| 0x0396003DA3BC0875 `WNF_PNPB_AWAITING_RESPONSE` | `PNPB`, 1 | system | `PiUEventBroadcastAwaitingResponseEvent` |
| 0x0296003DA3BC1075 `WNF_PNPC_DEVICE_INSTALL_REQUESTED` | `PNPC`, 2 | system | `PiUEventSendDeviceInstallNotification` |
| 0x0296003DA3BC1875 `WNF_PNPC_CONTAINER_CONFIG_REQUESTED` | `PNPC`, 3 | system | `PiDcGenerateContainerConfigRequiredNotification` |
| 0x41C61D3DA3BC0875 `WNF_PS_WAKE_CHARGE_RESOURCE_POLICY` | `PS`, 1 | system | `PspSendNoWakeChargeLimitNotification`, `PspClearNoWakeChargeLimitNotification` |
| 0x41C60320A3BC0875 `WNF_MM_BAD_MEMORY_PENDING_REMOVAL` | `MM`, 1 | system | `MmMarkPhysicalMemoryAsBad` |
| 0x41C6013DA3BC0875 `WNF_PO_SCENARIO_CHANGE` | `PO`, 1 | system | `PopDiagNextSleepStudySession` (read by [cdd.dll](./cdd.md#wnf-states): GUID `GUID_SPM_LOW_POWER_CS` = low-power connected standby) |
| 0x0C960C38A3BC1075 `WNF_UBPM_CONSOLE_MONITOR` | `UBPM`, 2 | system | `PopUpdateConsoleDisplayState` |
| 0x41950C3EA3BC0875 `WNF_SBS_UPDATE_AVAILABLE` | `SBS`, 1 | system | `SepSecureBootCheckForUpdates` |
| 0x41940B3AA3BC0875 `WNF_WER_SERVICE_START` | `WER`, 1 | system | `DbgkpStartSystemErrorHandler` |
| 0x41840B3EA3BC3875 `WNF_SEB_TIME_ZONE_CHANGE` | `SEB`, 7 | system | `ExpRefreshTimeZoneInformation` |

The power manager also publishes the power setting states (`PopSetPowerSettingValue`, `PopDispatchNotificationsToList`) and the job notifications (`PspJobNotificationWorker`) with names taken at run time. The permanent / persistent WNF data are kept in the registry (`HKLM\Software\Microsoft\Windows NT\CurrentVersion\Notifications` and `…\VolatileNotifications` ?).

### Crash dump and bug checks

`KeBugCheck2` (0x56D1D4) runs the bug check callbacks registered with `KeRegisterBugCheckCallback` / `KeRegisterBugCheckReasonCallback` (used by [crashdmp.sys](../drivers/crashdmp.md), [qccdi8930.sys](../drivers/qccdi8930.md), [wpprecorder.sys](../drivers/wpprecorder.md), [HAL.dll](./hal.md)) and writes the dump through the crash dump stack loaded by `IoInitializeCrashDump` (0x6E14F0, `\SystemRoot\System32\Drivers\crashdmp.sys`, configuration `HKLM\System\CurrentControlSet\Control\CrashControl`).

### Registry

Main keys found in the kernel strings (most are the desktop ones):

| Key | Use |
|-----|-----|
| `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management` | Memory manager settings |
| `HKLM\SYSTEM\CurrentControlSet\Control\CrashControl` | Crash dump |
| `HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot`, `…\Control\BootLog` | Safe mode, boot log |
| `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot`, `HKLM\HARDWARE\UEFI` | Secure Boot policy (`SepSecureBoot*`) |
| `HKLM\System\CurrentControlSet\Control\CI` | Code integrity ([ci.dll](./ci.md)) |
| `HKLM\SYSTEM\CurrentControlSet\Control\BCD` | Boot configuration |
| `HKLM\System\CurrentControlSet\Control\FastCache\…` | [Licenses](#product-suite-and-licensing) |
| `HKLM\System\CurrentControlSet\Control\Errata\Dynamic` | Errata manager (with [HAL.dll](./hal.md)) |
| `HKLM\System\CurrentControlSet\Control\EarlyLaunch`, `HKLM\ELAM` | Early-launch anti-malware |
| `HKLM\SYSTEM\CurrentControlSet\Services` | Drivers and services (`Start`, `ImagePath`…) |
