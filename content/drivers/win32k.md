## Win32k.sys

Win32 kernel-mode subsystem of Windows Phone 8.1 ("MobileCore" / "Moderncore" build: 1720 functions, ARM, public symbols).  
It is a much reduced win32k: no window manager, no GDI drawing calls, no input stack. It keeps only what the phone shell and the compositor need in the kernel: process / thread callouts (Win32 process and thread structures, the session-shared section mapped by `NtModerncoreProcessConnect`), regions and display DCs for [GDI32.DLL](../libraries/gdi32.md), display configuration, monitors, DPI and power (`NtUser*`), the DirectComposition kernel objects (`NtDComposition*`, token manager, composition surfaces and input sinks), and the D3DKMT / OPM system calls, which it forwards to [dxgkrnl.sys](./dxgkrnl.md). It also hosts the GDI engine used by the WDDM display driver [cdd.dll](../libraries/cdd.md) (`Eng*` exports).  
User mode reaches it only through the 245 system calls of its shadow table (`SVC 1`, numbers 0x1000…0x10F4), whose stubs are in [GDI32.DLL](../libraries/gdi32.md#system-calls), [DCOMP.DLL](../libraries/dcomp.md#system-calls) and [MinUser.dll](../libraries/minuser.md#system-calls). It imports `ntoskrnl.exe` (283 functions), `watchdog.sys` (`WdLog*` diagnostics, `SMgrRegisterGdiCallout`, `SMgrNotifySessionChange`) and `HAL` (`KeQueryPerformanceCounter`).

Location on the phone: `\SystemRoot\System32\win32k.sys` (session image, loaded through `NtSetSystemInformation`, see [ntoskrnl](../libraries/ntoskrnl.md)).

There's no device object: win32k doesn't create any device or symbolic link (`IoCreateDevice` isn't imported) and has no IRP dispatch routine.  
Driver object : `\Driver\Win32k` (created in `DriverEntry` with `IoCreateDriver`, init routine `Win32kPnPDriverEntry` 0x5D9DC, which only stores it in `gpWin32kDriverObject`; it is used as the owner of the PnP notifications)  
Named objects created: events `\UniqueSessionIdEvent` and `\UniqueInteractiveSessionIdEvent` (`ZwCreateEvent`, access 0x1F0003; `STATUS_OBJECT_NAME_COLLISION` tells the driver that it isn't the first / first interactive session), directory `\Windows\WindowStations` / `\Sessions\<id>\Windows\WindowStations` (`UserInitialize`).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\win32k` ?  

Registry values read:  
| Registry value | value | comment |
|----------------|-------|---------|
| `HKLM\Software\Microsoft\win32k\MobileCore\BugCheckOnSessionProcReset` | ? | REG_DWORD (`MobileCoreSaveCallstack` 0x557F0, which also saves the current call stack in `gMobileCoreStackTrace`). When ≠ 0, `NtModerncoreRegisterCompositorProcess` calls `KeBugCheckEx(0x1000F008, pid, tid, gpepCSRSS, 0x2000)` if the caller isn't the session process (`gpepCSRSS`) or a compositor is already registered |
| `GraphicsDrivers\DisableLddmSpriteTearDown` | 0 | REG_DWORD (`InitializeGraphicsInfrastructure`, `RtlQueryRegistryValues(RTL_REGISTRY_CONTROL)`) → `gbDisableLddmSpriteTearDown` |
| `GraphicsDrivers\AllowAppLiteRotationModeChangeOverride` | 0 | REG_DWORD, re-read by the win32k escape 0x401 ([D3DKMT escapes](#d3dkmt-escapes-handled-by-win32k)) → `gAllowAppLiteRotationModeChange` |
| `HKLM\System\CurrentControlSet\Control\GraphicsDrivers\InvalidDisplay`, `GraphicsDrivers\PermanentSettingChanges`, `GraphicsDrivers\TemporarySettingChanges` | ? | Display-driver failure (`DrvDriverFailure`) and display settings |
| `HKLM\System\CurrentControlSet\Services\DXGKrnl` | — | Service key loaded with `ZwLoadDriver` ([dxgkrnl.sys](./dxgkrnl.md)) |
| `HKLM\Hardware\DeviceMap\Video` (`\Device\Video0` …) | — | `DrvGetRegistryHandleFromDeviceMap`: registry key of each display device |
| `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Windows`: `GDIProcessHandleQuota`, `USERProcessHandleQuota`, `USERPostMessageLimit`, `USERNestedWindowLimit`, `USERKCCTimeout`, `GDIEnableStackTrace`, `GDIEnableAltStackTrace`, `GDICaptureStackTraceForObjectType` | ? | Handle quotas, limits and debug options |
| `Session Manager\SubSystems\Windows` (`SharedSection`) | `SharedSection=,3072` (default) | `InitCreateUserSubsystem`: size of the desktop heaps |
| `MouseInPointerAutoOptIn` | ? | `UserInitialize` |
| `ThreadUnresponsiveLogTimeout` | ? | Read in the ETW enable callback (`McGenControlCallbackV2`) |
| `HKLM\Software\Microsoft\SQMClient\Windows\CEIPEnable`, `CEIPSampledIn`, the policy key `HKLM\Software\Policies\Microsoft\SQMClient\Windows\CEIPEnable`, `…\SQMClient\Windows\DisabledSessions\GlobalSession` | ? | SQM opt-in (`WinSqmIsOptedIn` 0x23964, after the WNF state `WNF_WSQM_IS_OPTED_IN`) |
| `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Scaling\Monitors\…\DesktopScaleFactor`, `ScaleFactor` | ? | DPI scale factor of a monitor |

GUID of the ETW provider:  
`{8C416C79-D49B-4F01-A467-E56D3AA8234C}` (Microsoft-Windows-Win32k, `W32kControlGuid`, registered by `McGenEventRegister` 0x5DCC0)  
`{A97524F6-064C-4C4E-B74B-1ACC87C3700D}` (`Microsoft_Windows_SQM_Provider`, `RegisterWinSqmProvider` 0x234F0, same provider as [dxgkrnl.sys](./dxgkrnl.md))

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\DxgKrnl` | [dxgkrnl.sys](./dxgkrnl.md) | Loaded by win32k itself (`DlpLoadDxgkrnl` 0x626A4: `ZwLoadDriver(\Registry\Machine\System\CurrentControlSet\Services\DXGKrnl)`, then `IoGetDeviceObjectPointer`, 10 tries 5 ms apart; `ZwUnloadDriver` on failure). [internal IOCTL 0x23E057 / 0x23E067](#internal-ioctl-0x23e057-0x23e067--devicedxgkrnl) give the `DXGKWIN32K_INTERFACE` (624 bytes, `gDxgkInterface` 0x6F048) used for all the D3DKMT system calls |
| `\Device\Video<n>` (GDO of each VidPn source) | [dxgkrnl.sys](./dxgkrnl.md#internal-ioctls-of-devicevideon) | `DrvUpdateGraphicsDeviceList` (`IoGetDeviceObjectPointer`, user-visible names `\\.\DISPLAY<n>`). [Video port IOCTLs](#internal-ioctls-sent-to-devicevideon) |
| Monitor PDO (child of the display adapter) | [dxgkrnl.sys](./dxgkrnl.md#internal-ioctls-of-the-monitor-pdo) | Found through the dxgkrnl interface (`gDxgkInterface` +0x1FC, from the adapter LUID and the target id). [OPM IOCTLs](#internal-ioctl-0x232483--0x2324a3--opm) (`CallMonitor` 0x63C4C). `CMonitorPDO` registers `EventCategoryTargetDeviceChange` on it and `EventCategoryDeviceInterfaceChange` on `GUID_DEVINTERFACE_MONITOR` |
| Top of the monitor stack | [monitor.sys](./monitor.md#internal-ioctl-0x232433--set-brightness) | [internal IOCTL 0x232433](#internal-ioctl-0x232433--set-brightness) (`IoGetAttachedDeviceReference` of the monitor PDO) |
| Compositor ALPC port | MobileUI.exe ([compserver.dll](../libraries/compserver.md)) | `gplpcCompositorApiPort`, given by `NtModerncoreRegisterCompositorPort`; `SendRequestToCompositorAndWaitForReply` (`LpcRequestWaitReplyPortEx`), used by `VideoPortCallout` |
| DWM session port | [dwmmobile.dll](../libraries/dwmmobile.md) ? | Given by `NtUserRegisterSessionPort` (`xxxDwmProcessStartup`); `DwmAsyncRequestEnableChange` sends a 32-byte message with `LpcRequestPort` (data size 8: `0x40000020`, enable flag) |

> [!NOTE]
> The strings `mouclass`, `kbdclass`, `\Device\PointerClass0`, `\Device\KeyboardClass0` (and their `Legacy0` variants), `\Device\Disc`, `TSDDD` and `\Device\Video0` are still in the binary, but the input-class names are not referenced by any code: this win32k doesn't open the mouse or keyboard class devices. Input reaches the shell through the composition input sinks (`NtCreateCompositionInputSink`, `NtModerncoreRegisterSharedInputGlobal`).

### Exports

| Export | Comment |
|--------|---------|
| `W32pServiceTable`, `W32pArgumentTable`, `W32pServiceLimit` | System service table (245 entries, `.data:0x6E000`), argument table (number of stack bytes per call, `.data:0x6E4D8`), limit = 245 (`.data:0x6E4D4`). Installed with `KeAddSystemServiceTable(W32pServiceTable, gpCountTable, W32pServiceLimit, W32pArgumentTable, 1)` |
| `EngAllocMem`, `EngFreeMem`, `EngBugCheckEx`, `Eng*Semaphore*` | Engine helpers |
| `EngCreateBitmap`, `EngCreateDeviceBitmap`, `EngCreateRedirectionDeviceBitmap`, `EngCreateDeviceSurface`, `EngAssociateSurface`, `EngModifySurface`, `EngUpdateDeviceSurface`, `EngLockSurface`, `EngUnlockSurface`, `EngDeleteSurface`, `EngIsCddDeviceBitmap` | Surfaces (used by [cdd.dll](../libraries/cdd.md)) |
| `EngBitBlt`, `EngCopyBits`, `EngStretchBlt`, `EngStretchBltROP`, `EngPlgBlt`, `EngAlphaBlend`, `EngTransparentBlt`, `EngGradientFill`, `EngTextOut`, `EngLineTo`, `EngFillPath`, `EngStrokePath`, `EngStrokeAndFillPath` | GDI engine drawing (fallbacks of the display driver) |
| `EngCreateRectRgn`, `EngSetRectRgn`, `EngCombineRgn`, `EngCopyRgn`, `EngOffsetRgn`, `EngEqualRgn`, `EngRectInRgn`, `EngGetRgnBox`, `EngGetRgnData`, `EngDeleteRgn`, `CLIPOBJ_bEnum`, `CLIPOBJ_cEnumStart`, `PATHOBJ_vGetBounds`, `PALOBJ_cGetColors`, `XLATEOBJ_iXlate`, `EngCreatePalette`, `EngDeletePalette`, `EngCTGetCurrentGamma`, `EngCTGetGammaTable` | Regions, clipping, palettes |
| `EngQueryW32kCddInterface` | Gives the [win32k interface](../libraries/cdd.md#win32k-interface) to cdd.dll |
| `RtlCopyMemoryNonTemporal`, `__C_specific_handler` | Runtime |
| `GsDriverEntry` | Entry point (security cookie, then `DriverEntry` 0x7CFEC, INIT) |

### Initialisation

`DriverEntry` (INIT):
1. `ZwQuerySystemInformation(SystemCodeIntegrityInformation)`: option value 0x2 (test signing) → `gbOSTestSigningEnabled`. `WdInitialize`.
2. `InitializeGraphicsInfrastructure` (0x3D8D4): loads [dxgkrnl.sys](./dxgkrnl.md) and opens `\Device\DxgKrnl` (`DlpLoadDxgkrnl`), sends [internal IOCTL 0x23E057](#internal-ioctl-0x23e057-0x23e067--devicedxgkrnl) (Win32k interface) then 0x23E067 with the value 1, reads `DisableLddmSpriteTearDown`. Any failure clears the interface and fails the driver.
3. Stores the image base, `W32UserProbeAddress`, initialises the timer and HID request lists, gets the session id and creates `\UniqueSessionIdEvent` (and, in session 1, `\UniqueInteractiveSessionIdEvent`).
4. `IoCreateDriver(\Driver\Win32k, Win32kPnPDriverEntry)`, `DriverObject->DriverUnload` = `Win32KDriverUnload`.
5. In the first session only: `KeAddSystemServiceTable` (shadow table index 1), `PsEstablishWin32Callouts(W32CalloutDispatch)` and `DbgkLkmdRegisterCallback(W32pLkmdDataCollectionCallback, 0, 5)` (live kernel dump data).
6. `McGenEventRegister` (ETW), `WinSqmStartSession`, `WinSqmIsOptedIn`, kernel events and semaphores, `MmPageEntireDriver`, `InitializeGre` (GDI engine), `Win32UserInitialize`.
7. `ZwPowerInformation(41, …)` (36-byte output: display timeouts ?) and `ZwPowerInformation(PlatformRole 75)` (→ `gPlatformRole`, default 1 = desktop on failure), `PowerUpdateBrightnessLevels`, `RetrieveCurrentDisplayState`.
8. Creates a 20-byte `CMutex` holder (`dword_72940`) and calls `DCompSessionInitialize` (DirectComposition).

### Win32 callouts

`W32CalloutDispatch` (0x21270), given to the kernel with `PsEstablishWin32Callouts`:  
| Code | Handler |
|------|---------|
| 0 | `W32pProcessCallout` (Win32 process create / delete) |
| 1 | `W32pThreadCallout` (Win32 thread) |
| 2 | `UserGlobalAtomTableCallout` |
| 3 | Power event → `QueuePowerRequest` (only once `gbPowerCalloutsReady` and `gbVideoInitialized`; handled by `xxxUserPowerEventCalloutWorker`: monitor on / off, dimming, brightness, resume / suspend) |
| 4 | `UserPowerStateCallout` |
| 5 | `UserPowerInfoCallout` (power settings: `GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS`, `GUID_DEVICE_POWER_POLICY_VIDEO_DIM_BRIGHTNESS`, `GUID_VIDEO_DIM_TIMEOUT`, `GUID_CONSOLE_VIDEO_TIMEOUT`, `GUID_VIDEO_ALS_OFFSET`, …) |
| 6, 7, 0x11 | Return STATUS_SUCCESS (no-op) |
| 8 … 0x10 | `STATUS_NOT_SUPPORTED` (0xC00000BB): the job / console / window station callouts of desktop Windows aren't implemented |
| 0x12 … 0x15 | Object type callbacks (open, delete, ok-to-close, parse) of the desktop / window station objects, forwarded to the vtable of the object (checks the session of the caller, `0xC0000022` STATUS_ACCESS_DENIED otherwise) |
| 0x16, 0x17 | Process freeze / thaw: calls the dxgkrnl interface (`gDxgkInterface` +0x14 / +0x18), then sets / clears bit 0x400 of the Win32 process flags (+0x1A8) |
| 0x18, 0x19 | Forwarded to the dxgkrnl interface (+0x25C, +0x260) |
| other | `STATUS_INVALID_PARAMETER` |

### Moderncore system calls

The phone-specific calls (`NtModerncore*`), stubs exported by [MinUser.dll](../libraries/minuser.md#exports) and [GDI32.DLL](../libraries/gdi32.md):
- `NtModerncoreProcessConnect` (0x54F2C): maps the shared section (`ghSectionShared`, read-only, `MEM_TOP_DOWN`) in the caller and fills a 288-byte structure: `+04` shared info, `+08`, `+0C`, `+10` other shared pointers, `+14` delta between the kernel and user mappings. The second output is TRUE when the caller is the session process (`gpepCSRSS`).
- `NtModerncoreRegisterCompositorProcess` (0x55260): only the session process may register itself as the compositor (`gpepCompositor`, also given to dxgkrnl through `gDxgkInterface` +0x210); see `BugCheckOnSessionProcReset` above.
- `NtModerncoreRegisterCompositorPort` (0x552F8): only from the compositor process; stores the ALPC port (`gplpcCompositorApiPort`).
- `ModerncorePreThreadCallout` (0x558AC): when the last GUI thread of the session process exits, releases the compositor port, the shared input and the compositor process, and disables the display (`DrvDisableMDEV`) unless the process image is `MobileUI.exe`.

### D3DKMT escapes handled by win32k

`DrvProcessWin32kEscape` (0x53DB0), private escape types of `D3DKMTEscape` (type at `+08`, private data `+10` / size `+14`):  
| Type | Size | Action |
|------|------|--------|
| 0x400 | ≥ 4, first dword = size | `STATUS_NOT_SUPPORTED` |
| 0x401 | any | Re-reads `AllowAppLiteRotationModeChangeOverride` |
| 0x402 | 104 | `DrvGetCurrentDpiInfoFromHDC(hdc +00, DPI_INFORMATION +08)` |
| 0x403 | ≥ 8 | `+00` = 1: `+04` = result of a dxgkrnl interface query (`+0x26C`); `+00` = 2: with test signing only, `+04` → `gbBypassPresenterViewProcessCheck` |
| 0x404 | 6 | Returns three WORDs: logical pixels (`gdmLogPixels`), system DPI, display DPI |

---

### internal IOCTL 0x23E057, 0x23E067 — `\Device\DxgKrnl`

These IOCTLs are sent by Win32k.sys to [dxgkrnl.sys](./dxgkrnl.md#internal-ioctl-0x22c00b-0x23003f-0x230043-0x230047-0x232063-0x23e057-0x23e05b-0x23e05f-0x23e067--devicedxgkrnl) (`InitializeGraphicsInfrastructure`, `IoBuildDeviceIoControlRequest` with `InternalDeviceIoControl` = TRUE)

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x815 / 0x819 |
| Access | READ_AND_WRITE |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x23E057 Win32k interface | `\Device\DxgKrnl` | 624 | 624 |
| 0x23E067 Win32k capabilities | `\Device\DxgKrnl` | 4 | 0 |

0x23E057 buffer (`gDxgkInterface`, same buffer for input and output):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 70 02 | Size = 624 |
| 02-03 | 01 00 | Version 1 |
| 04-26F | ? | Filled by `DxgkWin32kQueryInterface`: the dxgkrnl functions called by every `NtGdiDdDDI*` system call and by the display / monitor / power code of win32k |

0x23E067 input: `01 00 00 00` (bit 0: win32k supports path-independent rotation).

---

### internal IOCTLs sent to `\Device\Video<n>`

These IOCTLs are sent by Win32k.sys to the GDO of [dxgkrnl.sys](./dxgkrnl.md#internal-ioctls-of-devicevideon) through `GreDeviceIoControlEx` (0x627B4: synchronous, rejects sizes ≥ 0x2710000, sets the remote session flag in the stack location for a remote connection). Device 0x23, FILE_ANY_ACCESS, METHOD_NEITHER unless noted.

| IOCTL | Name | Sender | InputBuffer size | OutputBuffer Size | Comment |
|-------|------|--------|------------------|-------------------|---------|
| 0x23200F | IOCTL_VIDEO_SET_OUTPUT_DEVICE_POWER_STATE | `DrvSetMonitorPowerState` (`PowerOnMonitor`, `PowerOffMonitor`) | 4 | 0 | `VIDEO_POWER_STATE`, sent to every device of the MDEV that isn't a mirror / non-WDDM device, then to every WDDM device |
| 0x23201B | IOCTL_VIDEO_ENUM_MONITOR_PDO | `UpdateMonitorDevices`, `DrvUpdateGraphicsDeviceList` | 0 | 4 | Returns a pointer to the 12-byte entries (freed by win32k with `ExFreePoolWithTag`); win32k keeps a copy at `GRAPHICS_DEVICE` +0xBC (count +0xB8) |
| 0x23201F | IOCTL_VIDEO_INIT_WIN32K_CALLBACKS | `DrvUpdateGraphicsDeviceList` | 20 | 20 | `00-03` `GRAPHICS_DEVICE *` (PhysDisp), `04-07` callout = `VideoPortCallout` (0x55B80); returned `08-0B` bACPI, `0C-0F` physical device object, `10-13` dual-view flags (`0x20000000` → `GRAPHICS_DEVICE` flag 0x100000) |
| 0x23202B | IOCTL_VIDEO_USE_DEVICE_IN_SESSION | `bSetDeviceSessionUsage` | 8 | 8 | `00-03` bEnable, `04-07` bSuccess (0 → `DbgPrint` "Trying to enable physical device already in use." / "Trying to disable physical device not enabled in this session.") |
| 0x232033 | ? | `DrvUpdateGraphicsDeviceList` | 0 | 20 | Output `00-03` must be 2 (WdLog assertion otherwise) |
| 0x23203B | ? | `DrvGetDeviceConfigurationInformation` | 0 | 32 | Not handled by the dxgkrnl GDO (STATUS_NOT_SUPPORTED) |
| 0x23203F | ? | `DrvGetDeviceConfigurationInformation` | 32 | 0 | Not handled by the dxgkrnl GDO (STATUS_NOT_SUPPORTED) |
| 0x232043 | Get VSync ? | `DrvUpdatePDevForWDDMDevice` | 0 | 8 | `00-03` refresh rate → PDEV, byte `04` = 0 sets a "no VSync" flag ? |
| 0x230020 | IOCTL_VIDEO_HANDLE_VIDEOPARAMETERS | `DrvSetVideoParameters` | 356 | 356 | METHOD_BUFFERED, IRP_MJ_DEVICE_CONTROL, `VIDEOPARAMETERS` |
| 0x23048C | IOCTL_VIDEO_SWITCH_DUALVIEW | `CheckAndNotifyDualView` | 4 | 0 | METHOD_BUFFERED, IRP_MJ_DEVICE_CONTROL |

`VideoPortCallout` is the callback dxgkrnl calls on display events; it queues the request to the compositor (`SendRequestToCompositorAndWaitForReply`) and the work is done by `VideoPortCalloutThread` → `Win32kPnpNotify` (re-enumerates the graphics devices, display switch, mode changes, monitor events, `DrvUpdateDpiInfoAndNotifyMonitorChange`).

---

### internal IOCTL 0x232433 — set brightness

This IOCTL is sent by Win32k.sys to the top of the monitor stack, i.e. [monitor.sys](./monitor.md#internal-ioctl-0x232433--set-brightness) (`DrvSetMonitorBrightness` 0x469F0, called by `xxxUserPowerEventCalloutWorker` and `PowerOnMonitor`)

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x90C |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set brightness | Top of the monitor stack (`IoGetAttachedDeviceReference` of the monitor PDO) | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Brightness percentage |

Sent for every monitor of every display device of the MDEV that is active (entry flag bit 0) and is an internal panel (entry byte `08` ≠ 0, or id `04-07` = 0x110 ?). Not sent in a remote session. Afterwards, for the single internal WDDM display, win32k also calls the dxgkrnl interface (`+0x228`).

---

### internal IOCTL 0x232483 … 0x2324A3 — OPM

These IOCTLs are sent by Win32k.sys to the monitor PDO of [dxgkrnl.sys](./dxgkrnl.md#internal-ioctls-of-the-monitor-pdo) (`CallMonitor`, synchronous, `UserMode` wait) for the OPM / certificate system calls. Device 0x23, FILE_ANY_ACCESS, METHOD_NEITHER.

| IOCTL | Function | Name | Sender | InputBuffer size | OutputBuffer Size |
|-------|----------|------|--------|------------------|-------------------|
| 0x232483 | 0x920 | Get certificate length | `GetCertificateLengthAndMonitorPDO` | 4 | 4 |
| 0x232487 | 0x921 | Get certificate | `NtGdiGetCertificate` | 4 | certificate length |
| 0x23248B | 0x922 | Create protected output | `COPM::CreateProtectedOutput` | 4 | 4 (handle, then marked as created) |
| 0x23248F | 0x923 | Get random number | `NtGdiGetOPMRandomNumber` | 4 | 16 |
| 0x232493 | 0x924 | Set signing key and sequence numbers | `NtGdiSetOPMSigningKeyAndSequenceNumbers` | 8 | 0 |
| 0x232497 | 0x925 | Get information | `COPM::GetInformation` | 8 | 4096 |
| 0x23249B | 0x926 | Get COPP-compatible information | `COPM::GetCOPPCompatibleInformation` | 8 | 4096 |
| 0x23249F | 0x927 | Configure protected output | `COPM::ConfigureProtectedOutput` | 16 | 0 |
| 0x2324A3 | 0x928 | Destroy protected output | `COPMProtectedOutput::Destroy` | 4 | 0 |

The input starts with the OPM protected output handle of the miniport (4 bytes), followed by a pointer to the parameters for the 8- and 16-byte inputs ?

---

### Interface GUID

Monitor interface (`GUID_DEVINTERFACE_MONITOR`, `CMonitorPDO`: PnP notification and `IoGetDeviceInterfaces` on the monitor PDO)  
`{E6F07B5F-EE97-4A90-B076-33F57BF4EAA7}`

Display adapter interface (`GUID_DEVINTERFACE_DISPLAY_ADAPTER`, `DrvDisplayConfigGetDeviceInfo`)  
`{5B45201D-F2F2-4F3B-85BB-30FF1F953599}`

### Other GUID

Power settings (`UserPowerInfoCallout`): `GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS`, `GUID_DEVICE_POWER_POLICY_VIDEO_DIM_BRIGHTNESS`, `GUID_VIDEO_DIM_TIMEOUT`, `GUID_CONSOLE_VIDEO_TIMEOUT`, `GUID_VIDEO_ALS_OFFSET`  
`{ADED5E82-B909-4619-9949-F5D71DAC0BCB}`  
`{F1FBFDE2-A960-4165-9F88-50667911CE96}`  
`{17AAA29B-8B43-4B94-AAFE-35F64DAAF1EE}`  
`{6F5E16B8-8575-4014-B209-215FD159D7CD}`  
`{68204001-7A14-4F33-877D-346B20AE3016}`

Other power settings present in the binary: `GUID_CONSOLE_INPUT_TIMEOUT`, `GUID_TS_INPUT_TIMEOUT`, `GUID_SYSTEM_AWAYMODE`, `GUID_ACDC_POWER_SOURCE`, `GUID_BATTERY_COUNT`  
`{34A64C3B-8317-4171-ABD8-A3B1EE3E4331}`  
`{8592A7F6-022C-4F42-8C81-D7745F8CA920}`  
`{98A7F580-01F7-48AA-9C0F-44352C29E5C0}`  
`{5D3E9A59-E9D5-4B00-A6BD-FF34FF516548}`  
`{7D263F15-FCA4-49E5-854B-A9F2BFBD5C24}`

SQM global session  
`{95BABA28-ED26-49C9-B74F-93B170E1B849}`

WNF states:  
| State | Value | Use |
|-------|-------|-----|
| WNF_WSQM_IS_OPTED_IN | 0x0C971D3AA3BC0875 | Read by `WinSqmIsOptedIn` (`ZwQueryWnfStateData`, 4 bytes) |
| WNF_SPI_LOGICALDPIOVERRIDE | 0x418F1E3EA3BC0835 | Published by `DrvCreateMDEV` |
| WNF_DX_MONITOR_CHANGE_NOTIFICATION | 0x41C61629A3BC2835 | Published by `DrvUpdateDpiInfoAndNotifyMonitorChange` |
