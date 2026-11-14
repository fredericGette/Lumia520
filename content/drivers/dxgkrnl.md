## Dxgkrnl.sys

Microsoft DirectX graphics kernel subsystem (WDDM 1.3 "port" driver, 3206 functions, symbols available).  
It is the display port driver of the WDDM stack: the display miniport [qcdxkm8930.sys](./qcdxkm8930.md) registers with it through `\Device\DxgKrnl`, and dxgkrnl then owns every device object of the graphics adapter (adapter FDO, `\Device\VideoN` "GDO", child PDOs for the panel and the camera device). It implements the D3DKMT kernel thunks, the display mode manager (DMM / VidPN), the monitor manager (EDID, WMI data for [monitor.sys](./monitor.md)), OPM, brightness, Miracast, TDR (timeout detection and recovery), SQM and ETW.  
The video memory manager and the GPU scheduler live in [dxgmms1.sys](./dxgmms1.md) (`\SystemRoot\System32\drivers\dxgmms1.sys`), which dxgkrnl loads itself with `ZwSetSystemInformation(SystemLoadGdiDriverInSystemSpace)` (`DXGMMS_EXPORT::Initialize`, exports `VidMmInterface` and `VidSchInterface`). It imports `ntoskrnl`, `HAL`, `WMILIB` and `watchdog.sys` (`WdLog*` diagnostics, `SMgr*` session callouts, `DMgr*` GDI view ids).

Device name : `\Device\DxgKrnl`  
There's no symbolic link for `\Device\DxgKrnl`. It's created in `DriverEntry` with `IoCreateDeviceSecure` (`FILE_DEVICE_UNKNOWN`, `FILE_DEVICE_SECURE_OPEN`, SDDL `D:P` = `SDDL_DEVOBJ_KERNEL_ONLY`, class GUID `GUID_SD_DXGKRNL_DRIVER_OBJECT`) and `DxgkCreateClose` rejects any open whose requestor mode isn't kernel (`0xC0000022` STATUS_ACCESS_DENIED).

Per adapter (`DpiGdoCreateGdiObjects` 0x6A5C0), for each VidPn source *n*:  
Device name : `\Device\Video<n>` (`FILE_DEVICE_VIDEO`, kernel-only SDDL, class GUID `GUID_SD_GDO`, view id from `DMgrAcquireGdiViewId`)  
Symbolic link : `\DosDevices\DISPLAY<n+1>`  

> [!NOTE]
> Every device object of dxgkrnl is kernel-only. User mode never opens them: it goes through the `D3DKMT*` system calls (win32k → dxgkrnl), and the miniport only through the `DXGKRNL_INTERFACE` callbacks.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\DXGKrnl`  
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` (and its subkeys `Power`, `DMM`, `Connectivity`, `Configuration`, `AdditionalModeLists`, `MonitorPersistency`)  
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Video\{GUID}\0000` (`DpiGdoSetupGdiParameters`: value `SymbolicLinkValue`, subkey `VolatileSettings`, and the `VIDEO` device map entry `\Device\Video<n>`)  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`:  
| Registry value | value | comment |
|----------------|-------|---------|
| TdrLevel | 3 | REG_DWORD (`TdrInit` 0x61930). 0 = TDR off … 3 = recover on timeout |
| TdrDelay | 2 | REG_DWORD, seconds before a GPU timeout is declared |
| TdrDdiDelay | 5 | REG_DWORD, seconds allowed to a DDI call |
| TdrDodPresentDelay | 2 | REG_DWORD, display-only driver present timeout |
| TdrDodVSyncDelay | 2 | REG_DWORD, display-only driver VSync timeout |
| TdrLimitCount | 5 | REG_DWORD, TDRs allowed within `TdrLimitTime` before bug check |
| TdrLimitTime | 60 | REG_DWORD, seconds |
| TdrDebugMode | 2 | REG_DWORD |
| TdrTestMode | ? | Read by `_TdrIsTestMode` |
| TerminationListCountLimit, TerminationListSizeLimit, ValidateWDDMCaps | ? | `DXGGLOBAL::Initialize` |
| TerminationListTimerPeriod | ? | `ADAPTER_RENDER::Initialize` |
| ForceDirectFlip, DisableOverlays, EnableOfferReclaimOnDriver, EnableOfferReclaimFailOnDwm, LeanMemoryLimit | ? | `DXGADAPTER::Initialize` |
| MiracastDefaultRtspPort, PlatformSupportMiracast, SuspendAdapterTimerPeriod, EnableMiracastPerfTrack | ? | REG_DWORD, `DpiInitializeGlobalState` (0xF019C, INIT) |
| DxgKrnlVersion | 0x4002 | REG_DWORD **written** by `DpiInitializeGlobalState` |
| DisableUSWC (subkey) | — | Only the existence of the key `GraphicsDrivers\DisableUSWC` is checked (`RtlCheckRegistryKey`). When present, `DxgkCbMapMemory` (`DpMapMemory`) ignores the requested cache type (no write-combined mappings) |
| DisableDMD (subkey) | — | Existence checked. When present, the monitor I²C and OPM internal IOCTLs of the child PDOs return `STATUS_NOT_SUPPORTED` |
| HybridInternalPanelOverrideEnable | ? | `DpiHybridInternalPanelOverride` |
| EnableManualBrightnessMode | ? | REG_DWORD, read by `DpiBrightnessEscape` (escape 8) |
| UnsupportedMonitorModesAllowed | ? | `CCD_BTL` |
| UseSelfRefreshVRAMInS3 | ? | `DXGADAPTER::InitializePowerManagement` |
| DRTTestEnable | ? | `DxgkDrtTestEscape`, test escapes |
| DxgEnableDesktopDuplicationDiagnostics, OutputDuplicationSessionApplicationLimit | ? | Desktop duplication |
| BreakOnBadEDID (subkey) | — | `MonitorInitializeGlobal` |

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power` (`DXGADAPTER::InitializePowerManagement`, runtime power management with PoFx):  
| Registry value | value | comment |
|----------------|-------|---------|
| EnableRuntimePowerManagement | ? | |
| DisableDevicePowerRequired | ? | |
| DefaultLatencyToleranceOther, DefaultExpectedResidency, DefaultLatencyToleranceIdle0, DefaultLatencyToleranceIdle1, DefaultLatencyToleranceNoContext, DefaultLatencyToleranceIdle0MonitorOff, DefaultLatencyToleranceIdle1MonitorOff, DefaultLatencyToleranceNoContextMonitorOff, DefaultLatencyToleranceTimerPeriod | ? | F-state latencies / residency given to `PoFxSetComponentLatency` / `PoFxSetComponentResidency` |
| DefaultIdleThresholdIdle0, DefaultIdleThresholdIdle0MonitorOff, DefaultPowerNotRequiredTimeout, DefaultActiveIdleThreshold | ? | |
| MonitorLatencyTolerance, MonitorRefreshLatencyTolerance | ? | |
| DefaultD3TransitionLatencyActivelyUsed, DefaultD3TransitionLatencyIdleShortTime, DefaultD3TransitionLatencyIdleNoContext, DefaultD3TransitionLatencyIdleMonitorOff, DefaultD3TransitionIdleShortTimeThreshold, DefaultD3TransitionIdleLongTimeThreshold | ? | |
| DefaultLatencyToleranceMemory, DefaultLatencyToleranceMemoryNoContext, DefaultMemoryRefreshLatencyToleranceActivelyUsed, DefaultMemoryRefreshLatencyToleranceIdleShortTime, DefaultMemoryRefreshLatencyToleranceNoContext, DefaultMemoryRefreshLatencyToleranceMonitorOff | ? | |
| uhigh, uglitch, uideal, lowdebounce | ? | Parameters of the latency/idle heuristics ? |

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\DMM` (`ADAPTER_DISPLAY::Initialize`, `VIDPN_MGR::_ReadConfiguration`, `VIDPN_MGR` constructor): `ModeListCaching`, `DODPreferredPresentMoveRegeionsOverride`, `BadMonitorModeDiag`, `AllowUnspecifiedVSync`, `AllowUnspecifiedHSync`, `AllowUnspecifiedPixelRate`, `RapidHPDTime`, `RapidHPDThresholdCount`, `TargetPriorityList`, `TargetForcePriorityList`, `DefaultSimulatedTarget`, `VidPnLkgTopology`.  

Other registry values:  
| Registry value | value | comment |
|----------------|-------|---------|
| `HKLM\System\Platform\DeviceTargetingInfo\PhoneManufacturerModelName` | e.g. `RM-914_eu_euro1_276` ? | REG_SZ. Looked up in a hardcoded table to get the panel diagonal, see [Display diagonal table](#display-diagonal-table) |
| `HKLM\System\CurrentControlSet\Services\PhysicalDisplaySizeOverride\Width`, `Height` | ? | REG_DWORD, both required (`GetPhysicalDisplaySizeOverride` 0x681F8, `RtlQueryRegistryValuesEx(RTL_REGISTRY_SERVICES, "PhysicalDisplaySizeOverride")`). Physical size of the panel, overrides the EDID size and the diagonal table |
| `ViewDistanceOverride` (adapter device key) | ? | REG_DWORD, accepted only if it is one of the values of `ViewDistanceArray` (`OemSpecifiedViewDist` 0x683B4) |
| `HardwareInformation.AdapterString`, `.BiosString`, `.DacType`, `.ChipType` (adapter key) | e.g. `Adreno 305` | Read by `DpiQueryAdapterRegistryInfo`; written by [qcdxkm8930.sys](./qcdxkm8930.md) |
| `UserModeDriverName`, `UserModeDriverNameWow`, `UserModeDListDriverName`, `OpenGLDriverName`, `OpenGLVersion`, `OpenGLFlags` (+`Wow`) (adapter key) | e.g. `qcdx9um8930.dll` ? | `DpiGetAdapterInfo`: user-mode driver of the adapter ([qcdx9um8930.dll](../libraries/qcdx9um8930.md)); `d3d10warp.dll` for the WARP / basic render adapters |
| `MiracastDriverName` (adapter key) | ? | `DpiFdoStartAdapter` |
| `TestBrightnessLevels` (adapter key) | ? | `DpiTestProcessRegKey`, test brightness interface |
| `ExposeDmmTestInterface` (`Services\dxgkrnl`) | ? | Must be set for [internal IOCTL 0x22C00B](#internal-ioctl-0x22c00b-0x23003f-0x230043-0x230047-0x232063-0x23e057-0x23e05b-0x23e05f-0x23e067--devicedxgkrnl) |
| `MultiMonSupport`, `DisableNonPOSTDevice`, `DisableAutoAcpiPostDeivce` | ? | Adapter start (`DpiFdoHandleStartDevice`, `DpiFdoDetectPostDevice`) |
| `HKLM\Software\Microsoft\SQMClient\Windows\CEIPEnable` / `CEIPSampledIn` (and the policy key) | ? | SQM opt-in (`DxgkSqmOptedIn`) |
| `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Scaling\Monitors\…\DesktopScaleFactor`, `ScaleFactor` | ? | Test hook for the DPI scale factor (`ScaleOverrideTestHookCore`) |

GUID of the ETW provider:  
`{802EC45A-1E99-4B83-9920-87C98277BA9D}` (Microsoft-Windows-DxgKrnl, `DxgkControlGuid`, registered by `McGenEventRegister`)  
`{A97524F6-064C-4C4E-B74B-1ACC87C3700D}` (`Microsoft_Windows_SQM_Provider`, `DxgkSqmInit`)  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Display miniport (the adapter FDO's driver) | [qcdxkm8930.sys](./qcdxkm8930.md) | Registers through [internal IOCTL 0x230047](#internal-ioctl-0x22c00b-0x23003f-0x230043-0x230047-0x232063-0x23e057-0x23e05b-0x23e05f-0x23e067--devicedxgkrnl); then called through its `DxgkDdi*` functions (stored in the `DRIVER_INITIALIZATION_DATA`) |
| `\SystemRoot\System32\drivers\dxgmms1.sys` | [dxgmms1.sys](./dxgmms1.md) | Video memory manager / scheduler, loaded in session space, interfaces `VidMmInterface` / `VidSchInterface` |
| Lower device of the adapter (ACPI PDO) | [acpi.sys](./acpi.md) | Query interface `GUID_ACPI_INTERFACE_STANDARD` (`DpiAddDevice`). [IOCTL 0x32C004 / 0x32C018 / 0x32C020](#ioctl-0x32c004-0x32c018-0x32c020--acpi): `DxgkCbEvalAcpiMethod` (`DpEvalAcpiMethod`) of the miniport and the ACPI child list |
| Monitor stack, interface `GUID_DEVINTERFACE_MONITOR_DRIVER` `{866519B5-3F07-4C97-B7DF-24C5D8A8CCB8}` | [monitor.sys](./monitor.md) | Arrival notification (`MONITOR_MGR::_HandleMonitorPnPNotification`), [internal IOCTL 0x232407](#internal-ioctl-0x232407--get-monitor-adapter-info) sent to identify the monitor; [internal IOCTL 0x23242F](#internal-ioctl-0x23242f--set-monitor-power-state) sent to the top of each monitor stack on output power changes |
| `\Device\RESOURCE_HUB\<16 hex digits>` | [acpiex.sys](./acpiex.md#opening-a-connection-deviceresource_hubid) → SPB / GPIO controller | `DpOpenSpbResource` / `DpSpbResourceIoControl` (0xACBC4): opens a connection resource (type 0x84) of the adapter for the miniport and forwards its IOCTLs with `ZwDeviceIoControlFile` |
| `\Device\PhysicalMemory` | ntoskrnl | `DpMapMemory` (`DxgkCbMapMemory`): user-mode mappings of physical memory use `ZwOpenSection` + `ZwMapViewOfSection`; kernel mappings use `MmMapIoSpace` |
| UMDF Miracast device, interface `GUID_DEVINTERFACE_UMDF_MIRACAST_DIVICE_ARRIVAL` `{A6CB8452-09C2-46CB-A752-415392B3213B}` | ? | [IOCTL 0x230800…0x23080C](#ioctl-0x230800-0x230804-0x230808-0x23080c--miracast-user-mode-requests). Only with `PlatformSupportMiracast` ? |
| `\Callback\PowerState` | ntoskrnl | `ExCreateCallback` + `ExRegisterCallback` (`DpiAcpiRegisterAcpiCallbacks`) |
| win32k ? / [cdd.dll](../libraries/cdd.md#dxgkrnl-cdd-interface) (0x23E05B) | ? | [internal IOCTLs 0x23E057, 0x23E05B, 0x23E05F, 0x23E067](#internal-ioctl-0x22c00b-0x23003f-0x230043-0x230047-0x232063-0x23e057-0x23e05b-0x23e05f-0x23e067--devicedxgkrnl), [GDO IOCTLs](#internal-ioctls-of-devicevideon) |

### Device objects

| Object | Extension type (`+0x0C`, tag `'Dxgk'`) | Created by | Dispatch (`+0x40` create, `+0x44` internal IOCTL, `+0x48` IOCTL) |
|--------|------------------------------------|------------|-----------|
| `\Device\DxgKrnl` | — | `DriverEntry` | `DxgkCreateClose` (create/close), `DxgkInternalDeviceIoctl` (0x61718), `DxgkUnload` |
| Adapter FDO (unnamed, on the ACPI PDO of the GPU) | 2 | `DpiAddDevice` | `DpiFdoDispatchInternalIoctl` (0x77194); IOCTLs are forwarded to the lower device |
| Child PDOs (monitor, other children of the miniport) | 3 ? | `DpiPdoAddPdo` | `DpiPdoDispatchInternalIoctl` (0x75414) |
| `\Device\Video<n>` ("GDO", one per VidPn source) | 6 | `DpiGdoCreateGdiObjects` (0x6A5C0) | `DpiGdoDispatchCreate`, `DpiGdoDispatchInternalIoctl` (0x75140), `DpiGdoDispatchIoctl` (0x6B778) |

`DpiInitializeInternal` (reached through [internal IOCTL 0x230047](#internal-ioctl-0x22c00b-0x23003f-0x230043-0x230047-0x232063-0x23e057-0x23e05b-0x23e05f-0x23e067--devicedxgkrnl)) installs the `Dpi*` dispatch routines in the **miniport's** `DRIVER_OBJECT` (`DpiDispatchCreate`, `DpiDispatchClose`, `DpiDispatchIoctl` 0x6B6A0, `DpiDispatchInternalIoctl` 0x7508C, `DpiDispatchPnp`, `DpiDispatchPower`, `DpiDispatchSystemControl`, `DpiAddDevice`): the generic dispatchers call the per-object handler of the extension, or forward the IRP to the lower device for an FDO, or fail with `0xC00000BB` STATUS_NOT_SUPPORTED.  
The child PDO hardware ids are built from the child descriptor: `DISPLAY\<EDID id>` / `MONITOR\<EDID id>`, `DISPLAY\Default_Monitor` / `MONITOR\Default_Monitor` (no EDID), compatible id `*PNP09FF`; device text `Generic Monitor`, `Unknown Video Device`. The adapter's GDO registers `GUID_DEVINTERFACE_DISPLAY_ADAPTER`.

### Exports

| Export | Comment |
|--------|---------|
| `DxgCoreInterface` | Data: core interface table, used by [dxgmms1.sys](./dxgmms1.md) to call the miniport DDIs (`ADAPTER_RENDER::Ddi*` thunks) |
| `DpSynchronizeExecution`, `DpiGetDxgAdapter`, `DpiGetDriverVersion`, `DpiGetSchedulerCallbackState`, `DpiSetSchedulerCallbackState` | Port helpers |
| `TdrIsEnabled`, `TdrIsRecoveryRequired`, `TdrIsTimeoutForcedFlip`, `TdrAllowToDebugEngineTimeout`, `TdrCreateRecoveryContext`, `TdrCompleteRecoveryContext`, `TdrResetFromTimeout`, `TdrCollectDbgInfoStage1`, `TdrCollectDbgInfoStage2`, `TdrUpdateDbgReport`, `TdrHistoryInit`, `TdrHistoryIsLimitExhausted`, `TdrHistoryUpdate`, `g_TdrConfig`, `g_TdrForceTimeout`, `g_TdrForceDodPresentTimeout`, `g_TdrForceDodVSyncTimeout` | TDR, for the scheduler in [dxgmms1.sys](./dxgmms1.md) |
| `DxgkVidMmAllowFailOnOfferReclaimErrors` | |
| `DxgkSqm*` (`AddToStream`, `CommonGeneric`, `CreateDwordStreamEntry`, `CreateStringStreamEntry`, `GenericDword`, `GenericDword64`, `GenericString`, `OptedIn`, `SetDword`) | SQM telemetry |
| `TraceDxgkBlockThread`, `TraceDxgkContext`, `TraceDxgkDevice`, `TraceDxgkFunctionProfiler`, `TraceDxgkPerformanceWarning`, `g_bVSyncEnabledForLogging` | ETW helpers |
| `GsDriverEntry` | Entry point (security cookie, then `DriverEntry` 0xF002C, INIT) |

### Initialisation

`DriverEntry` (INIT):
1. Stores the driver object, reads the code-integrity options (`ZwQuerySystemInformation(SystemCodeIntegrityInformation)`, answered by [ci.dll](../libraries/ci.md#ciqueryinformation-0x258a0); bit 2 = test signing → `g_OSTestSigningEnabled`), `WdInitialize`.
2. `DpiInitializeGlobalState`: registry values of `GraphicsDrivers` (see above), Miracast interface notification, writes `DxgKrnlVersion`.
3. `DXGGLOBAL::CreateGlobal` (which loads [dxgmms1.sys](./dxgmms1.md)), `CCD_BTL::CreateGlobal` (connected display configuration database), ETW registration, `DxgkDiagInit`.
4. Creates `\Device\DxgKrnl`, then `DxgkInitialPower` (power setting callbacks `GUID_MONITOR_POWER_ON`, `GUID_LOW_POWER_EPOCH`), `MonitorInitializeGlobal` (PnP notification on `GUID_DEVINTERFACE_MONITOR_DRIVER`), `DxgDbgInit` (bug check reason callback), `DxgkSqmInit`, `TdrInit`, and the session-change callout `DxgkNotifySessionStateChange` (`SMgrRegisterSessionChangeCallout`).

### Display diagonal table

`UpdateGdiInfoForVidPnSource` (0x68990) computes the DPI / scale factor of each source (`FillDpiInfo`). The physical size comes from the EDID (`GetPhysicalSizeFromEDID`); it is replaced by `PhysicalDisplaySizeOverride` when present, otherwise, for an **internal** output, by the diagonal looked up from `PhoneManufacturerModelName` (`LookupDisplayDiagonal` 0x70EB0, table `.rdata:0x31710`, 82 entries of 16 bytes: name pointer, prefix flag, `double` diagonal in inches). Entries with the prefix flag set match any model name that starts with the entry.

| Model name | Prefix | Diagonal (") |
|------------|--------|--------------|
| RM-820, RM-821, RM-822 | yes | 4.5 |
| RM-824, RM-825, RM-826, RM-845 | yes | 4.3 |
| RM-846 | yes | 3.8 |
| RM-860, RM-867, RM-875, RM-876, RM-877 | yes | 4.5 |
| RM-878 | yes | 4.3 |
| RM-880 | yes | 3.8 |
| RM-885, RM-887 | yes | 4.3 |
| RM-892, RM-893, RM-910 | yes | 4.5 |
| **RM-913, RM-914, RM-915, RM-917** (Lumia 520 / 525 family) | yes | **4.0** |
| RM-937, RM-938, RM-939, RM-940 | yes | 6.0 |
| RM-941, RM-942, RM-943 | yes | 4.7 |
| RM-955 | yes | 4.5 |
| A620b/d/e/m/t, C8833L, C8835 [1]/[2], HUAWEI (Ascend W1 U8835, H883G, W1-C00, W1-U00), RIO_CR/CU/TD/U, SCH-I930, SCH-R860U, T8835, U8835-1/-51/-92, U8835N-1, Windows Phone 8S by HTC, Yogurt (ATT/Sprint/Verizon) | no | 4.0 |
| ACCORD_TD/U/UL/WL/WR, C620d/e/t, C625a/b, HTC6990LVW, PM23300, TIARA_CL, W2-T00, W2-U00, Windows Phone 8X by HTC | no | 4.3 |
| GT-I8675, GT-I8750, I8750DDALL1, I8750DXALL1, SGH-I187, SGH-T899M, SPH-I800 | no | 4.8 |

### Brightness

dxgkrnl answers the query interfaces `GUID_DEVINTERFACE_BRIGHTNESS` `{FDE5BBA4-B3F9-46FB-BDAA-0728CE3100B4}` and `GUID_DEVINTERFACE_BRIGHTNESS_2` `{148A3C98-0ECD-465A-B634-B05F195F7739}` on the monitor PDO (`DpiBrightnessQueryInterface`), with the interface obtained from the miniport's `DxgkDdiQueryInterface` (qcdxkm8930 `sub_49E4C4`). `DpiBrightnessStartDevice` registers the power settings `GUID_VIDEO_FULLSCREEN_PLAYBACK` and `GUID_ACDC_POWER_SOURCE` (backlight optimisation level).  
`DpiBrightnessEscape` (0xC7098, `D3DKMT_BRIGHTNESS_INFO` escape): type 1 get possible levels, 2 get, 3 set, 4 get caps ?, 5 set state ?, 6 set backlight optimisation (0-3), 7 get backlight reduction ?, 8 enter manual mode (reads `EnableManualBrightnessMode`), 9 leave manual mode (restores the saved level), 10 toggle a flag. Types 1-7 require manual mode, otherwise `0xC000042A`.

---

### internal IOCTL 0x22C00B, 0x23003F, 0x230043, 0x230047, 0x232063, 0x23E057, 0x23E05B, 0x23E05F, 0x23E067 — `\Device\DxgKrnl`

These IOCTLs are processed by Dxgkrnl.sys (`DxgkInternalDeviceIoctl` 0x61718)

All are `METHOD_NEITHER`: the buffer is `Irp->UserBuffer` (same buffer for input and output), except for 0x23E067 which reads `Type3InputBuffer`. Kernel-mode callers only.

| IOCTL | Device / Function / Access | Name | InputBuffer size | OutputBuffer Size | Result |
|-------|----------------------------|------|------------------|-------------------|--------|
| 0x22C00B | 0x22 / 0x2 / READ_AND_WRITE | DMM test interface | ≥ 28 | ≥ 28 | `DmmQueryDmmTestInterface`, needs `ExposeDmmTestInterface` |
| 0x23003F | 0x23 / 0xF / ANY | IOCTL_VIDEO_DDI_FUNC_REGISTER (pre-Win8) | — | ≥ 4 | Writes the address of `DpiInitialize` (0x2A0F0) |
| 0x230043 | 0x23 / 0x10 / ANY | KMDOD initialize | — | ≥ 4 | Writes the address of `DpiKmdDodInitialize` (0x28DDC), for display-only drivers |
| 0x230047 | 0x23 / 0x11 / ANY | IOCTL_VIDEO_DDI_FUNC_REGISTER (Win8) | — | ≥ 4 | Writes the address of `DpiInitializeWin8` (0x1B074 → `DpiInitializeInternal(…, 1)`) |
| 0x232063 | 0x23 / 0x818 / ANY | Report software device | — | ≥ 4 | Writes the address of `DpiReportSoftwareDevice` (0xAAE70) |
| 0x23E057 | 0x23 / 0x815 / READ_AND_WRITE | Win32k interface | ≥ 624 | ≥ 624 | `DxgkWin32kQueryInterface` fills `DXGKWIN32K_INTERFACE` |
| 0x23E05B | 0x23 / 0x816 / READ_AND_WRITE | CDD interface | ≥ 204 | ≥ 204 | `DxgkCddQueryInterface` (0x80530): checks size 0xCC / version 3 / adapter (+0x04), fills the 48 function pointers +0x0C…+0xC8 ([table](../libraries/cdd.md#dxgkrnl-cdd-interface)); sent by [cdd.dll](../libraries/cdd.md#dxgkrnl-cdd-interface) |
| 0x23E05F | 0x23 / 0x817 / READ_AND_WRITE | Capture interface | ≥ 24 | ≥ 24 | `DxgkCaptureQueryInterface` |
| 0x23E067 | 0x23 / 0x819 / READ_AND_WRITE | Win32k capabilities | ≥ 4 | — | Bit 0 of the input dword → `g_Win32kSupportsPathIndependentRotation` |

Errors: `0xC0000023` STATUS_BUFFER_TOO_SMALL (output < 4 or no buffer), `0xC0000206` STATUS_INVALID_BUFFER_SIZE (interface IOCTLs), `0xC0000010` STATUS_INVALID_DEVICE_REQUEST (unknown code). `Irp->IoStatus.Information` = 4 for the function-pointer IOCTLs.  
[qcdxkm8930.sys](./qcdxkm8930.md#internal-ioctl-0x230047--ioctl_video_ddi_func_register) sends 0x230047 and calls the returned function with its `DRIVER_INITIALIZATION_DATA` (`DxgkInitialize`).

---

### Internal IOCTLs of `\Device\Video<n>`

These IOCTLs are processed by Dxgkrnl.sys (`DpiGdoDispatchInternalIoctl` 0x75140), all Device 0x23, FILE_ANY_ACCESS, METHOD_NEITHER. They are the WDDM versions of the legacy video port IOCTLs (function `0x800 + n`), sent by win32k ?

| IOCTL | Function | Name | Buffer | Comment |
|-------|----------|------|--------|---------|
| 0x23200F | 0x803 | IOCTL_VIDEO_SET_OUTPUT_DEVICE_POWER_STATE | Type3Input: ULONG `VIDEO_POWER_STATE` | For a state > 1 calls `MonitorEnableDisableMonitor` first. For each monitor child: sends [internal IOCTL 0x23242F](#internal-ioctl-0x23242f--set-monitor-power-state) (4 bytes = state) to the top of the child's stack (`IoGetAttachedDeviceReference`); if that fails, sets the PDO power directly (`DpiPdoSetDevicePower`). Then waits for the power IRPs (10 tries, 1 s × number of children). For state 1 (on) calls `MonitorEnableDisableMonitor` at the end |
| 0x232013 | 0x804 | IOCTL_VIDEO_GET_OUTPUT_DEVICE_POWER_STATE | — | Returns STATUS_SUCCESS, does nothing |
| 0x23201B | 0x806 | IOCTL_VIDEO_ENUM_MONITOR_PDO | UserBuffer: pointer | Allocates (tag `'Dxgk'`) an array of 12-byte entries terminated by a zero entry and returns its address: `00-03` flags (`0x20000000` \| 1 if the path is in the client VidPn), `04-07` monitor PDO, `08` 1 = internal output |
| 0x23201F | 0x807 | IOCTL_VIDEO_INIT_WIN32K_CALLBACKS | Type3Input: `VIDEO_WIN32K_CALLBACKS` (20 bytes) | Stores the callback (`+00`), returns `+08` bACPI, `+0C` physical device object, `+10` dual-view flags (`0x20000000` added for the primary view) |
| 0x23202B | 0x80A | IOCTL_VIDEO_USE_DEVICE_IN_SESSION | Type3Input ≥ 8: `bEnable`, `bSuccess` | Binds the GDO to the caller's session id (enable) or releases it (disable); `bSuccess` = 0 if another session owns it |
| 0x232033 | 0x80C | ? | UserBuffer ≥ 20 | `00-03` device object of the adapter ?, `04-07` VidPn source id, `08-0B` `DXGADAPTER` pointer, `0C-13` adapter LUID ? |
| 0x232037 | 0x80D | ? | — | Returns STATUS_SUCCESS |
| 0x232043 | 0x810 | Get VSync ? | UserBuffer ≥ 8 | `00-03` current integer refresh rate of the source (`DmmGetCurrentIntegerVSyncFromClientVidPnSource`), `04` 1 if ? = 1 |

Other codes: STATUS_NOT_SUPPORTED (0xC00000BB).  
IOCTLs (`IRP_MJ_DEVICE_CONTROL`, `DpiGdoDispatchIoctl`): `0x230020` IOCTL_VIDEO_HANDLE_VIDEOPARAMETERS (`DpiGdoHandleVideoParameters`, TV-out `VIDEOPARAMETERS`) and `0x23048C` IOCTL_VIDEO_SWITCH_DUALVIEW (function 0x123, METHOD_BUFFERED, 1-byte input: view enabled → `DmmSetViewState`, then child relations are invalidated). Anything else: STATUS_NOT_SUPPORTED.

---

### internal IOCTL 0x23204F, 0x232053 — enumerate children / sources

These IOCTLs are processed by Dxgkrnl.sys (`DpiFdoDispatchInternalIoctl` 0x77194, adapter FDO). They are also sent by dxgkrnl itself (`VIDPN_MGR` constructor).

| Name | Function | InputBuffer size | OutputBuffer Size |
|------|----------|------------------|-------------------|
| Enumerate children | 0x813 | ≥ 8 | 0 |
| Enumerate video present sources | 0x814 | ≥ 8 | 0 |

Device 0x23, FILE_ANY_ACCESS, METHOD_NEITHER. Inputbuffer (Type3Input):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Caller context |
| 04-07 | ? | Pointer to 3 callbacks: create entry `(ctx, &entry, 0)`, add entry `(ctx, entry)`, free entry `(ctx, entry)` |

0x23204F creates one entry per child of type 1 (video output): `+00` child UID, `+04` child type, `+08` HPD awareness (1, 3 or 4, else logged as invalid), `+0C` ?, `+10` byte ?. 0x232053 creates one entry per VidPn source: `+00` source id, `+04` 0.

---

### Internal IOCTLs of the monitor PDO

These IOCTLs are processed by Dxgkrnl.sys (`DpiPdoDispatchInternalIoctl` 0x75414) on the child PDO of a video output (the PDO [monitor.sys](./monitor.md) is loaded on). All Device 0x23, FILE_ANY_ACCESS, METHOD_NEITHER; input = `Type3InputBuffer`, output = `Irp->UserBuffer`. A PDO whose child type isn't 1 answers STATUS_NOT_SUPPORTED to everything.

| IOCTL | Function | Name | InputBuffer size | OutputBuffer Size | Handler |
|-------|----------|------|------------------|-------------------|---------|
| 0x232403 | 0x900 | Read raw EDID bytes | ≥ 12 | 0 | `DXGMONITOR::_DispatchInternalIOCtrl` (0x75BA0) |
| 0x232407 | 0x901 | [Get monitor adapter info](#internal-ioctl-0x232407--get-monitor-adapter-info) | 0 | ≥ 16 | `DpiPdoDispatchInternalIoctl` |
| 0x23240F | 0x903 | WmiMonitorListedSupportedSourceModes | ≥ 8 | ≥ 8 | DXGMONITOR, size 60 + 56 × (modes − 1) |
| 0x232413 | 0x904 | Monitor frequency ranges (WmiMonitorListedFrequencyRanges ?) | ≥ 8 | ≥ 8 | DXGMONITOR |
| 0x232417 | 0x905 | Get EDID block | ≥ 136 | ≥ 136 | DXGMONITOR |
| 0x23241B | 0x906 | WmiMonitorID | ≥ 8 | ≥ 8 | DXGMONITOR, size 130 (product code, serial number, manufacturer, date, user-friendly name converted to UTF-16) |
| 0x23241F | 0x907 | WmiMonitorColorCharacteristics | ≥ 8 | ≥ 8 | DXGMONITOR, size 16 |
| 0x232423 | 0x908 | WmiMonitorBasicDisplayParams | ≥ 8 | ≥ 8 | DXGMONITOR, size 11 |
| 0x232427 | 0x909 | WmiMonitorAnalogVideoInputParams | ≥ 8 | ≥ 8 | DXGMONITOR, size 6 |
| 0x23242B | 0x90A | WmiMonitorDigitalVideoInputParams | ≥ 8 | ≥ 8 | DXGMONITOR, size 1 |
| 0x23242F | 0x90B | [Set monitor power state](#internal-ioctl-0x23242f--set-monitor-power-state) | ≥ 4 | 0 | `DpiPdoSetDevicePower` |
| 0x232443 | 0x910 | I²C transmit to display | ≥ 12 | 0 | Miniport `DxgkDdiI2CTransmitDataToDisplay` (adapter `+0x39C`) |
| 0x232447 | 0x911 | I²C receive from display | ≥ 8 | 1-64 | Miniport `DxgkDdiI2CReceiveDataFromDisplay` (adapter `+0x3A0`) |
| 0x232483 … 0x2324A3 | 0x920 … 0x928 | OPM (9 codes) | | | `DpiPdoHandleOpmIoctls` (0xD3420) → miniport `DxgkDdiOPM*` |

Other codes go to `MonitorHandleInternalIOCtrl` → `DXGMONITOR::_DispatchInternalIOCtrl`, which returns STATUS_NOT_SUPPORTED for unknown codes (the [monitor.sys](./monitor.md) private IOCTLs such as `0x232433` never reach the PDO with a meaning).

WMI data blocks (0x23240F, 0x232413, 0x23241B … 0x23242B), same 8-byte input as described in [monitor.sys](./monitor.md#internal-ioctl-0x23240f-0x23241b-0x23241f-0x232423-0x232427-0x23242b--monitor-wmi-data):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size of the WMI buffer |
| 04-07 | ? | Pointer to the WMI buffer |

If the size is too small, the required size is written to the output dword and the status is `0x80000005` STATUS_BUFFER_OVERFLOW (`Information` = 8). If the monitor has no EDID, the status is `0xC01D0001` (STATUS_GRAPHICS_… "no descriptor" ?).

0x232403 input (12 bytes): `00-03` byte offset in the EDID, `04-07` length, `08-0B` destination pointer. The bytes are copied from the 128-byte EDID blocks; `0xC01D0008` if the range goes past the last block, `0xC01D0001` if there is no block.

0x232417: input byte `00` = block index (must be < number of blocks); output `00` = index, `01` = ?, `02-81` = the 128 bytes of the block.

I²C 0x232443 input: `00-03` 7-bit I²C address ?, `04-07` length (1-64), `08-0B` data pointer. 0x232447 input: `00-03` address ?, `04-07` flags ?; the output buffer receives the data (1-64 bytes). Both are refused (STATUS_NOT_SUPPORTED) when the miniport has no I²C DDI or when `GraphicsDrivers\DisableDMD` exists.

---

### internal IOCTL 0x232407 — get monitor adapter info

This IOCTL is processed by Dxgkrnl.sys (monitor PDO). It is sent by [monitor.sys](./monitor.md#internal-ioctl-0x232407--get-monitor-adapter-info), and by Dxgkrnl.sys itself (`MONITOR_MGR::_HandleMonitorPnPNotification`) to the top of a monitor stack when its `GUID_DEVINTERFACE_MONITOR_DRIVER` interface arrives, to find which adapter / target it belongs to.

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x901 (2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get monitor adapter info | 0 | ≥ 16 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `DXGADAPTER` pointer of the adapter |
| 04-07 | ? | Child UID (= VidPn target id) of the monitor |
| 08-0B | e.g. `00 00 00 80` | `D3DKMDT_VIDEO_OUTPUT_TECHNOLOGY` (`DmmGetVideoOutputTechnology`), 0x80000000 = internal |
| 0C-0F | e.g. `01 00 00 00` | Current output power state of the child (last state of IOCTL_VIDEO_SET_OUTPUT_DEVICE_POWER_STATE) |

---

### internal IOCTL 0x23242F — set monitor power state

This IOCTL is sent by Dxgkrnl.sys (GDO, [IOCTL_VIDEO_SET_OUTPUT_DEVICE_POWER_STATE](#internal-ioctls-of-devicevideon)) to the top of each monitor stack, i.e. [monitor.sys](./monitor.md#internal-ioctl-0x23242f--set-monitor-power-state-), and processed by Dxgkrnl.sys on the monitor PDO when it is forwarded.

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x90B (2315) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set monitor power state | monitor stack (`IoGetAttachedDeviceReference` of the child PDO) | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `01 00 00 00` | `VIDEO_POWER_STATE` (1 = on, 2 = standby, 3 = suspend, 4 = off …) |

Built with `IoBuildDeviceIoControlRequest(…, InternalDeviceIoControl = TRUE)`. On the PDO, `DpiPdoSetDevicePower` requests the matching device power state of the child.

---

### IOCTL 0x32C004, 0x32C018, 0x32C020 — ACPI

These IOCTLs are sent by Dxgkrnl.sys to [acpi.sys](./acpi.md) (top of the adapter's lower stack, `IoGetAttachedDeviceReference`)

| Name | Device name | Function | Comment |
|------|-------------|----------|---------|
| IOCTL_ACPI_EVAL_METHOD (0x32C004) | ACPI PDO of the adapter | 0x1 | `DpEvalAcpiMethod` (0x7F11C) = `DxgkCbEvalAcpiMethod` of the miniport, for methods of the adapter itself (child UID = −1) |
| IOCTL_ACPI_EVAL_METHOD_EX (0x32C018) | ACPI PDO of the adapter | 0x6 | `DpiAcpiEvalAcpiMethodEx` (0x7DF30): methods of an ACPI child of the adapter, by name (child list built at start) |
| IOCTL_ACPI_ENUM_CHILDREN (0x32C020) | ACPI PDO of the adapter | 0x8 | `DpiAcpiPrepareAcpiChildNameList`: names of the ACPI children of the adapter |

Device 0x32, READ_AND_WRITE, METHOD_BUFFERED. The input is the `ACPI_EVAL_INPUT_BUFFER*` given by the miniport; an output without the `'BoeA'` signature (`ACPI_EVAL_OUTPUT_BUFFER_SIGNATURE`, 0x426F6541) or with no argument is rejected with `0xC014000F`. Only at `PASSIVE_LEVEL`, and only when the adapter has an ACPI interface (`+0x240`), otherwise STATUS_NOT_SUPPORTED. The qcdxkm8930 methods (`_ROM`, `BLCP`, …) go through this path.

---

### IOCTL 0x230800, 0x230804, 0x230808, 0x23080C — Miracast user-mode requests

These IOCTLs are sent by Dxgkrnl.sys to the UMDF Miracast driver (`DpiMiracastSendAsyncUserModeRequest`, asynchronous `IRP_MJ_DEVICE_CONTROL`, buffer = 32-byte header + data)

| Name | Device name | Function | Sender |
|------|-------------|----------|--------|
| ? | UMDF Miracast device | 0x200 | `DpiMiracastInterfaceChange` |
| Start Miracast session ? | UMDF Miracast device | 0x201 | `DxgkMiracastStartMiracastSession` |
| Stop Miracast session ? | UMDF Miracast device | 0x202 | `DpiMiracastStopMiracastSessionSync` |
| Send user-mode message | UMDF Miracast device | 0x203 | `DpiMiracastCbSendUserModeMessage` (`DxgkCbSendUserModeMessage` of the miniport) |

Device 0x23, FILE_ANY_ACCESS, METHOD_BUFFERED. No Miracast device is known on the Lumia 520 ?.

---

### Interface GUID

Display adapter interface (`GUID_DEVINTERFACE_DISPLAY_ADAPTER`, registered by `DpiGdoCreateGdiObjects`)  
`{5B45201D-F2F2-4F3B-85BB-30FF1F953599}`

Monitor interface (`GUID_DEVINTERFACE_MONITOR`, on the monitor PDO)  
`{E6F07B5F-EE97-4A90-B076-33F57BF4EAA7}`

Interfaces referenced by `DpiFdoInitializeFdo` (adapter FDO)  
`{1CA05180-A699-450A-9A0C-DE4FBE3DDD89}` (`GUID_DISPLAY_DEVICE_ARRIVAL`)  
`{BF4672DE-6B4E-4BE4-A325-68A91EA49C09}` (`GUID_DEVINTERFACE_OPM`)  
`{2564AA4F-DDDB-4495-B497-6AD4A84163D7}` (`GUID_DEVINTERFACE_I2C`)  
`{AF03F190-22AF-48CB-94BB-B78E76A25107}` (`GUID_DEVINTERFACE_MIRACAST_DISPLAY`)  
`{2BEABE2B-5A09-4864-BFED-4CC3896E04A0}` (`GUID_DEVINTERFACE_MSBDD_FALLBACK`)

### Other GUID

Monitor function driver interface (`GUID_DEVINTERFACE_MONITOR_DRIVER`, created by [monitor.sys](./monitor.md), PnP notification target)  
`{866519B5-3F07-4C97-B7DF-24C5D8A8CCB8}`

UMDF Miracast device arrival / Miracast display arrival (PnP notification targets)  
`{A6CB8452-09C2-46CB-A752-415392B3213B}`  
`{64F1F453-D465-4097-B8F8-CDFF171FC335}`

Query interfaces answered: brightness (`GUID_DEVINTERFACE_BRIGHTNESS`, `GUID_DEVINTERFACE_BRIGHTNESS_2`), thermal cooling (`GUID_THERMAL_COOLING_INTERFACE`, `DpiFdoHandleQueryThermalInterface`)  
`{FDE5BBA4-B3F9-46FB-BDAA-0728CE3100B4}`  
`{148A3C98-0ECD-465A-B634-B05F195F7739}`  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`

Query interface requested from acpi.sys (`GUID_ACPI_INTERFACE_STANDARD`)  
`{B091A08A-BA97-11D0-BD14-00AA00B7B32A}`

Power settings registered (`PoRegisterPowerSettingCallback`): `GUID_MONITOR_POWER_ON`, `GUID_LOW_POWER_EPOCH`, `GUID_VIDEO_FULLSCREEN_PLAYBACK`, `GUID_ACDC_POWER_SOURCE`  
`{02731015-4510-4526-99E6-E5A17EBD1AEA}`  
`{E1233993-EAA4-470F-9DE7-A351C1B6FB71}`  
`{3D5938F0-FF20-41EF-AE9F-EEA006F422E1}`  
`{5D3E9A59-E9D5-4B00-A6BD-FF34FF516548}`

PoFx power-control codes sent to the miniport (`DxgkDdiPowerRuntimeControlRequest`): `GUID_DXGKDDI_POWER_MANAGEMENT_PREPARE_TO_START`, `GUID_DXGKDDI_POWER_MANAGEMENT_STARTED`, `GUID_DXGKDDI_POWER_MANAGEMENT_STOPPED`  
`{CBA549D4-CF3A-445C-9468-2383FD523116}`  
`{6C929C1D-7D76-4538-93AD-449DC9FDC239}`  
`{0A9D9621-BC21-4DD4-A0FC-D976E428F738}`

Device object security classes (`IoCreateDeviceSecure`): `GUID_SD_DXGKRNL_DRIVER_OBJECT`, `GUID_SD_GDO`, `GUID_SD_PDO`  
`{1264760F-A5C8-4BFE-B314-D56A7B44A362}`  
`{6FAE73B7-B735-4B50-A0DA-0DC2484B1F1A}`  
`{0475BB51-5A02-4EE0-B36C-29040FAD2650}`

Bus type of the child PDOs (`GUID_BUS_TYPE_DISPLAY`), container id namespace (`GUID_DISPLAY_CONTAINER_ID_NAMESPACE`), watchdog secondary dump data (`WdDxgkSecondaryDataGUID`)  
`{C6CA0D74-E43B-4ABD-A63A-4BD2AD319D60}`  
`{511C3855-579B-4A07-9A2F-72DE7263528A}`  
`{270A33FD-3DA6-460D-BA89-3C1BAE21E39B}`

WNF states published (`ZwUpdateWnfStateData`):  
| State | Value | Publisher |
|-------|-------|-----------|
| WNF_DX_MODE_CHANGE_NOTIFICATION | 0x41C61629A3BC1035 | `DxgkStatusChangeNotify` ? |
| WNF_DX_OCCLUSION_CHANGE_NOTIFICATION | 0x41C61629A3BC1835 | `DxgkStatusChangeNotify` ? |
| WNF_DX_STEREO_CONFIG | 0x41C61629A3BC0C75 | `DxgkSetStereoEnabled` |
| WNF_DX_NETWORK_DISPLAY_STATE_CHANGE_NOTIFICATION | 0x41C61629A3BC2035 | `DpiMiracastBroadcastDeviceStateChange` (consumed by [MirrorUX.dll](../libraries/mirrorux.md#wnf-states), data ≥ 0x214 bytes) |
