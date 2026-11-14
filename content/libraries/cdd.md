## cdd.dll

Canonical Display Driver: the GDI display driver of WDDM, which puts the GDI drawing of win32k on screen through DirectX.  
`cdd.dll` is a kernel-mode session image (ARM, 434 functions, full public symbols), not a user-mode DLL: it imports only `WIN32K.SYS`, `ntoskrnl.exe`, `HAL.dll` and `watchdog.sys`. win32k loads it as the display driver of every WDDM display and calls it through the GDI DDI (`DrvEnablePDEV`, `DrvBitBlt`, `DrvTextOut` …). CDD keeps a system-memory copy of the primary surface and of the redirection bitmaps. It draws in it with the `Eng*` functions of win32k or, when the adapter supports it, with GDI hardware acceleration commands (BitBlt, ColorFill, AlphaBlend, StretchBlt, TransparentBlt, ClearType blend). A worker thread then presents the dirty rectangles to the display.  
It talks to [dxgkrnl.sys](../drivers/dxgkrnl.md) through the CDD interface obtained with [internal IOCTL 0x23E05B](../drivers/dxgkrnl.md#internal-ioctl-0x22c00b-0x23003f-0x230043-0x230047-0x232063-0x23e057-0x23e05b-0x23e05f-0x23e067--devicedxgkrnl) on `\Device\DxgKrnl`, and to win32k through the interface returned by `EngQueryW32kCddInterface`. It also contains a pass-through layer for a remote display driver (Remote Desktop, `Rmt*` functions), which wraps a second DDI driver loaded with `ZwSetSystemInformation`.

Location on the phone: `C:\Windows\System32\cdd.dll` ? (path of the drivers loaded by win32k, as `\SystemRoot\System32\WORKERDD.dll`)  

### Imports

| DLL | Functions |
|-----|-----------|
| WIN32K.SYS | Surfaces: `EngCreateBitmap`, `EngCreateDeviceBitmap`, `EngCreateRedirectionDeviceBitmap`, `EngCreateDeviceSurface`, `EngAssociateSurface`, `EngModifySurface`, `EngUpdateDeviceSurface`, `EngLockSurface`, `EngUnlockSurface`, `EngDeleteSurface`, `EngIsCddDeviceBitmap`; drawing (fallback): `EngBitBlt`, `EngCopyBits`, `EngStretchBlt`, `EngStretchBltROP`, `EngPlgBlt`, `EngAlphaBlend`, `EngTransparentBlt`, `EngGradientFill`, `EngTextOut`, `EngLineTo`, `EngStrokePath`, `EngFillPath`, `EngStrokeAndFillPath`; regions and clipping: `EngCreateRectRgn`, `EngSetRectRgn`, `EngCombineRgn`, `EngCopyRgn`, `EngOffsetRgn`, `EngEqualRgn`, `EngRectInRgn`, `EngGetRgnBox`, `EngGetRgnData`, `EngDeleteRgn`, `CLIPOBJ_cEnumStart`, `CLIPOBJ_bEnum`, `PATHOBJ_vGetBounds`, `XLATEOBJ_iXlate`; palettes and gamma: `EngCreatePalette`, `EngDeletePalette`, `PALOBJ_cGetColors`, `EngCTGetGammaTable`, `EngCTGetCurrentGamma`; semaphores: `EngCreateSemaphore`, `EngDeleteSemaphore`, `EngAcquireSemaphore`, `EngAcquireSemaphoreNoWait`, `EngAcquireSemaphoreSharedNoWait`, `EngReleaseSemaphore`, `EngIsSemaphoreOwned`, `EngIsSemaphoreOwnedByCurrentThread`, `EngIsSemaphoreSharedByCurrentThread`; `EngAllocMem`, `EngFreeMem`, `EngQueryW32kCddInterface`, `__C_specific_handler` |
| ntoskrnl.exe | `IoGetDeviceObjectPointer`, `IoBuildDeviceIoControlRequest`, `IofCallDriver`, `PsCreateSystemThread`, `ObOpenObjectByPointer`, `ObDuplicateObject`, `ObCloseHandle`, `ZwClose`, `KeSetActualBasePriorityThread`, `KeWaitForSingleObject`, `KeWaitForMultipleObjects`, `KeInitializeEvent`, `KeSetEvent`, `KeClearEvent`, `KeReadStateEvent`, `KeInitializeTimer`, `KeSetTimer`, `KeCancelTimer`, `KeInitializeMutex`, `KeReleaseMutex`, `KeInitializeSemaphore`, `KeReleaseSemaphore`, fast mutexes / push locks / critical regions, `MmCreateSection`, `MmMapViewInSessionSpace`, `MmUnmapViewInSessionSpace`, `MmMapViewOfSection`, `MmUnmapViewOfSection`, `IoAllocateMdl`, `IoFreeMdl`, `MmSizeOfMdl`, `MmProbeAndLockPages`, `MmUnlockPages`, `KeFlushIoRectangle`, `KeStackAttachProcess`, `KeUnstackDetachProcess`, `PsGetCurrentProcess`, `PsGetProcessImageFileName`, `ExQueryWnfStateData`, `RtlQueryRegistryValuesEx`, `ZwQuerySystemInformation`, `ZwSetSystemInformation`, `RtlInitializeGenericTableAvl` (+ lookup / insert / enumerate), `ExAllocatePoolWithTag`, `ExFreePoolWithTag`, `ExIsProcessorFeaturePresent`, `KeGetRecommendedSharedDataAlignment`, `KeTickCount`, `KeQueryTimeIncrement`, `DbgPrintEx`, `vsprintf_s`, `wcslen`, `wcsncmp`, `_wcsnicmp`, `RtlFillMemoryUlong` |
| HAL.dll | `KeGetCurrentIrql`, `KeQueryPerformanceCounter` |
| watchdog.sys | `WdLogNewEntry5_*` / `WdLogEvent5_*` (`WdAssertion`, `WdError`, `WdWarning`, `WdLowResource`, `WdEvent`, `WdTrace`), `SMgrGdiCallout` |

There's no CRT import: the `/GS` cookie code (`__security_push_cookie` / `__security_pop_cookie`, `__GSHandlerCheck*`), `memcpy` / `memset` and the ARM division helpers are linked in.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [dxgkrnl.sys](../drivers/dxgkrnl.md) (`\Device\DxgKrnl`) | `IoGetDeviceObjectPointer` + [internal IOCTL 0x23E05B](#dxgkrnl-cdd-interface) | CDD interface: devices, allocations, mode list, present |
| Remote display driver (path given by win32k, extended `DRVENABLEDATA` +0x0C) | `ZwSetSystemInformation(SystemLoadGdiDriverInformation)` / `SystemUnloadGdiDriverInformation` ([remote mode](#remote-mode)) | DDI driver of a remote session, wrapped by the `Rmt*` functions |
| `\SystemRoot\System32\WORKERDD.dll` | Name compared with `_wcsnicmp` ([DrvEnableDriver](#drvenabledriver-0x20eb4)) | Remote driver treated in pass-through mode instead of full remote mode. Not in the extracted files |

### Exports

No export directory: the only entry is the image entry point `GsDrvEnableDriver` (0x20F90, `/GS` wrapper). It checks that the security cookie was initialised (not 0 nor the default 0xBB40E64E, otherwise `__fastfail(6)`), stores its complement, and jumps to `DrvEnableDriver(ULONG iEngineVersion, ULONG cj, DRVENABLEDATA *pded)`. win32k calls it as the entry of a display driver (`EngLoadImage` style).

### DrvEnableDriver (0x20EB4)

Called with `cj` = size of the `DRVENABLEDATA`:
- `cj` = 12: normal case, `CddEnableDriver` (0x20EF0).
- `cj` = 20: remote mode, see [Remote mode](#remote-mode). Fields +0x0C (`PWSTR` driver path) and +0x10 (non-zero = full remote) are an extension of the structure.
- Any other size returns `FALSE`. A size < 12 also writes a watchdog assertion.

`CddEnableDriver` returns `iDriverVersion` = 0x30000 (`DDI_DRIVER_VERSION_NT5`), 39 functions (table at 0x31028), and initialises the globals: `gCddImageInfo` (`InitCddImageInfo`, 0x20DDC: `ZwQuerySystemInformation(SystemModuleInformation)` then search of the module containing its own code, base and size kept to tag the watchdog log entries), `g_SSE2InstructionsAvailable` (`ExIsProcessorFeaturePresent(10)`) and the CPU cache line size (`KeGetRecommendedSharedDataAlignment`, in bytes and in 32-bit pixels, used by the cache flushes of the aperture bitmaps).

DDI functions (index = `INDEX_Drv*`):

| Index | Function | Index | Function |
|-------|----------|-------|----------|
| 0 | `DrvEnablePDEV` (0x1DC88) | 29 | `DrvSetPointerShape` |
| 1 | `DrvCompletePDEV` | 30 | `DrvMovePointer` |
| 2 | `DrvDisablePDEV` (0x2ADCC) | 31 | `DrvLineTo` |
| 3 | `DrvEnableSurface` (0x1B7F0) | 41 | `DrvGetModes` (0x19958) |
| 4 | `DrvDisableSurface` | 67 | `DrvIcmSetDeviceGammaRamp` |
| 5 | `DrvAssertMode` (0x16608) | 68 | `DrvGradientFill` |
| 8 | `DrvDisableDriver` (empty function, folded with `CDDSQM_ROPLOGGER::FreeRop`) | 69 | `DrvStretchBltROP` |
| 10 | `DrvCreateDeviceBitmap` | 70 | `DrvPlgBlt` |
| 11 | `DrvDeleteDeviceBitmap` | 71 | `DrvAlphaBlend` |
| 14 | `DrvStrokePath` | 74 | `DrvTransparentBlt` |
| 15 | `DrvFillPath` | 87 | `DrvNotify` |
| 16 | `DrvStrokeAndFillPath` | 88 | `DrvSynchronizeSurface` |
| 18 | `DrvBitBlt` | 92 | `DrvMovePointerEx` |
| 19 | `DrvCopyBits` | 94 / 95 | `DrvCreateDeviceBitmapEx` / `DrvDeleteDeviceBitmapEx` (redirection bitmaps of the DWM) |
| 20 | `DrvStretchBlt` | 96 | `DrvAssociateSharedSurface` |
| 22 | `DrvSetPalette` | 97 | `DrvSynchronizeRedirectionBitmaps` |
| 23 | `DrvTextOut` | 98 | `DrvAccumulateD3DDirtyRect` |
| | | 99 / 100 | `DrvStartDxInterop` / `DrvEndDxInterop` |
| | | 101 / 102 | `DrvLockDisplayArea` / `DrvUnlockDisplayArea` |

Indexes 94…102 are the private CDD DDI functions of win32k (no `INDEX_Drv*` in the public headers).

### Startup

No `DriverEntry` / `DllMain`: everything starts at `DrvEnableDriver`, then at `DrvEnablePDEV` for each display.

### DrvEnablePDEV (0x1DC88)

`DrvEnablePDEV` calls `DrvEnablePDEVInternal` (0x1E5C0) with the last flag 0 (the remote layer calls it with 1):
1. `EngAllocMem` of the PDEV (`CDDPDEV`, 0x27F0 bytes, tag `Dcdd`), default values (refresh period, `+0x94C` flags).
2. Prepares the [win32k interface](#win32k-interface) (`+0xDC`, size 0x68, version 2) with the CDD callbacks and calls `EngQueryW32kCddInterface(hDriver, hdev, &iface, &hAdapter (+0x8AC), &sourceId (+0x158), &process (+0x150))` through `CddEngQueryW32kCddInterface`. `hAdapter` and the process must be non-zero.
3. Creates 10 empty regions (`EngCreateRectRgn`), 9 synchronisation objects (non-paged pool, events and `CDDMUTEX`) and a semaphore.
4. Gets the current and requested modes from win32k (interface +0x14), then opens the [dxgkrnl CDD interface](#dxgkrnl-cdd-interface) (`OpenDxgkrnl`, 0x1D888, structure at PDEV +0x10).
5. Creates 5 more events (`+0x8EC…+0x8FC`), fills the `GDIINFO` / `DEVINFO` (`InitPDEV`, `PopulatePdevDevGdiInfo`), and queries the adapter capabilities (`DxgkCddGetDriverCaps`, interface +0x8C, result at PDEV +0x430 / +0x668). The GDI hardware acceleration is used only if the capability bits allow it (bit 2 of +0x45C, version ≥ 0x1200 at +0x578).
6. Palette (`bInitPaletteInfo`), copies the `DEVINFO` (≤ 0x12C bytes) and the `GDIINFO` (≤ 0x130 bytes) for win32k.
7. Reads the [registry](#registry) value `EnableScrollRect`.
8. Creates the semaphores, the SQM ROP loggers (`CddSqmStart`, 2 AVL tables of ROP counters), the 2 hardware command buffers of 64 KB (if acceleration), and 1 or 2 staging pools (system memory surfaces shared with the GPU).
9. Starts the [present worker thread](#present-worker-thread) (`WorkerThreadStartup`).
10. Subscribes to the [WNF state](#wnf-states) `WNF_PO_SCENARIO_CHANGE` through the dxgkrnl interface (`DxgkCddSubscribeWnfStateChange`, +0xC4), callback `CddWnfStateChangeCallback`, context = PDEV. The subscription is kept at +0x154 and removed in `DrvDisablePDEV` (interface +0xC8).

Any failure calls `DrvDisablePDEV` and returns NULL. `DrvDisablePDEV` stops the worker thread (command 13), frees everything in reverse order and releases the dxgkrnl interface (`DxgkCddInterfaceDereference`, +0x10).

### dxgkrnl CDD interface

`OpenDxgkrnl` (0x1D888) and `DrvGetModes` (0x19958) open `\Device\DxgKrnl` (`IoGetDeviceObjectPointer`, access 0xC0000000), and send the internal IOCTL **0x23E05B** (device 0x23, function 0x816, `METHOD_NEITHER`, `FILE_READ_DATA | FILE_WRITE_DATA`, `IoBuildDeviceIoControlRequest(…, InternalDeviceIoControl = TRUE)`). The input and output buffer is the same 204-byte structure, filled in by `DxgkCddQueryInterface` of [dxgkrnl.sys](../drivers/dxgkrnl.md#internal-ioctl-0x22c00b-0x23003f-0x230043-0x230047-0x232063-0x23e057-0x23e05b-0x23e05f-0x23e067--devicedxgkrnl):

`DxgkCddQueryInterface` (dxgkrnl 0x80530) checks the size (0xCC) and the version (3) and that +0x04 isn't NULL (otherwise `STATUS_INVALID_PARAMETER` 0xC000000D), gets the adapter pair of the source with `DxgkpGetPairingAdapters`, fills the function table and returns 0xCC in `Information`. Names from the dxgkrnl symbols:

| Offset | Size | Field (dxgkrnl function) | Used by cdd.dll |
|--------|------|--------------------------|-----------------|
| 0x00 | 2 | Size, 204 (0xCC) | |
| 0x02 | 2 | Version, 3 | |
| 0x04 | 4 | In: `DXGADAPTER *` given by win32k (`EngQueryW32kCddInterface`, PDEV +0x8AC); first parameter of most functions | |
| 0x08 | 4 | In: VidPN source id given by win32k (PDEV +0x158; 0xFFFFFFFF in `DrvGetModes` before the query) | |
| 0x0C | 4 | `DxgkCddInterfaceDereference` (also used as the reference function) | |
| 0x10 | 4 | `DxgkCddInterfaceDereference` | `DrvDisablePDEV`, `DrvGetModes` |
| 0x14 | 4 | `DxgkCddEtwLoggerEnabled` | ETW profiler, tested by the drawing functions |
| 0x18 | 4 | `DxgkCddCreate(adapter, …, &hDevice, …, CDDDXGK_DRIVERINFO *, CDDDXGK_DRIVERINFO *, …)` | `CreateAndEnableDevice` (results at PDEV +0x8B4, +0x8B8, +0x650, +0x888, +0x8B0) |
| 0x1C | 4 | `DxgkCddDestroy(hDevice, adapter)` | `CDDPDEV::DestroyDevice` |
| 0x20 | 4 | `DxgkCddEnable(hDevice, …, CDDDXGK_INTERFACE *, sourceId, D3DKMT_DISPLAYMODE *, CDD_DEVMODE_FLAGS, VIDPN_PATH_DATA *, scaling, pfnCreateSection, context, …)` | `CreateAndEnableDevice`, with the callback `CddDxgkCreateSection` that creates the section of the shadow surface (`MmCreateSection`, `SEC_COMMIT`, `PAGE_READWRITE`) |
| 0x24 | 4 | `DxgkCddEnableLite` (mode change without recreating the primary) | Worker thread ? |
| 0x28 | 4 | `DxgkCddDisable` | `CreateAndEnableDevice` (failure), `TryCreateDevice`, worker thread |
| 0x2C, 0x30 | 4 each | `DxgkCddLock`, `DxgkCddUnlock` (`D3DKMT_LOCK` / `D3DKMT_UNLOCK`) | `CDDPDEV::LockAllocation` / `UnlockAllocation` |
| 0x34 | 4 | `DxgkCddGetDisplayModeList(adapter, D3DKMT_GETDISPLAYMODELIST *)` | `GetDisplayModeList` |
| 0x38 | 4 | `DxgkCddPresent(D3DKMT_PRESENT *, …)` | `CddPresentBlt`, `CddPresentColorFill`, worker thread (`D3DKMT_PRESENT` at PDEV +0xC48, status at +0xB00) |
| 0x3C | 4 | `DxgkCddSetPalette(adapter, DXGKARG_SETPALETTE *)` | `SetPalette` |
| 0x40 | 4 | `DxgkCddSetPointerShape` | `bSetHardwarePointerShape` ? (called through the pointer structure, not found) |
| 0x44 | 4 | `DxgkCddSetPointerPosition` | `MovePointerInternal` ? (same) |
| 0x48 | 4 | `DxgkCddSetGammaRamp(adapter, sourceId, D3DDDI_GAMMA_RAMP_RGB256x3x16 *)` | `SetGammaRamp` |
| 0x4C | 4 | `DxgkCddSetOrigin(adapter, sourceId, POINT *)` | Worker thread after `DxgkCddEnable` and on command 8 (`DrvNotify`, origin at PDEV +0x15C) |
| 0x50 | 4 | `DxgkCddWaitForVerticalBlankEvent(adapter, sourceId, hDevice, KEVENT **)` | Worker thread: VSync event it waits on |
| 0x54 | 4 | `DxgkCddTerminateThread(KEVENT *)` | Worker thread |
| 0x58, 0x5C | 4 each | `DxgkCddCreateAllocation`, `DxgkCddDestroyAllocation` | `CDDPDEV::CreateAllocation` (system memory given by `CddDxgkAllocateSysMem`) / `DestroyAllocation` |
| 0x60 | 4 | `DxgkCddSyncGPUAccess` | `CDDPDEV::SyncGPUAccess`, `WaitForStartGdiAccessToFinish` |
| 0x64, 0x68 | 4 each | `DxgkCddQueryResourceInfo`, `…FromNtHandle` | `CDDPDEV::OpenResource` (shared surfaces of the DWM) |
| 0x6C, 0x70 | 4 each | `DxgkCddOpenResource`, `…FromNtHandle` | `CDDPDEV::OpenResource` ? (call not found) |
| 0x74 | 4 | `DxgkCddLogEvent(…, DXGKETW_PARAMS *)` | `CDDETWPROFILER`, `CDDSYNCOBJECT::Issue*` |
| 0x78 | 4 | `DxgkCddGetCurrentDxgProcess` | `CreateAndEnableDevice` (→ PDEV +0x11E8) |
| 0x7C | 4 | `DxgkCddGdiCommand(D3DKMT_RENDER *)` | `CHwCommandBuffer::FlushGdiCommands` (GDI hardware acceleration) |
| 0x80 | 4 | `DxgkCddSubmitPresentHistory` | `FlushGdiCommands`, `CDDPDEV::ProcessGDIDirtyList`, worker thread |
| 0x84, 0x88 | 4 each | `DxgkCddPushWorkerThreadOfOwner(adapter, adapter2, ETHREAD *)`, `DxgkCddPopWorkerThreadOfOwner` | `DrvAssertModeInternal`: when the exclusive owner check fails, the worker thread is declared as a thread of the exclusive owner for the mode change, then removed |
| 0x8C | 4 | `DxgkCddGetDriverCaps(adapter, DXGK_DRIVERCAPS *, DXGK_DRIVERCAPS *)` | `DrvEnablePDEVInternal` (PDEV +0x430, +0x668) |
| 0x90 | 4 | `DxgkCddVerifyCddDevMode` | `InitPDEV` |
| 0x94 | 4 | `DxgkWriteDiagEntry` | `TriggerGdiModeReset` |
| 0x98 | 4 | `DxgkCddReportSqmData(DXGK_CDD_SQM_DATA *)` | `CDDSQM_DDILOGGER` destructor |
| 0x9C, 0xA0 | 4 each | `DxgkCddAdapterReference`, `DxgkCddAdapterDereference` | End of `DrvEnablePDEVInternal` / `DrvDisablePDEV` |
| 0xA4…0xB4 | 4 each | `DxgkCddCreate/Destroy/Signal/WaitFor/OpenSynchronizationObject` | `CDDSYNCOBJECT` |
| 0xB8 | 4 | `DxgkCddNotifyGdiRendering` | `CddBitmapHw::SyncDXAccessInternal` |
| 0xBC | 4 | `DxgkCddIssueSyncObjectOpForDevice` | `CDDSYNCOBJECT::IssueOpForDevice` |
| 0xC0 | 4 | `DxgkCddPresentDisplayOnly`, only for a display-only adapter (KMDOD), else NULL | `CddPresentColorFill`; `CddDxgkCreateSection` and `CreateAndEnableDevice` test it: the shadow section in system memory (`CddAllocShadowSysMem`) is only created for a display-only adapter |
| 0xC4 | 4 | `DxgkCddSubscribeWnfStateChange(callback, EPROCESS *, &stateName, …, context)` | `DrvEnablePDEVInternal` (PDEV +0x154) |
| 0xC8 | 4 | `DxgkCddUnsubscribeWnfStateChange` | `DrvDisablePDEV` |

The "Used by" column comes from the calls through PDEV +0x10 + offset in cdd.dll; "?" when no such call was found.

`DrvGetModes` gets the mode list from dxgkrnl (`GetDisplayModeList`, 44-byte `D3DKMT_DISPLAYMODE`s) and returns `DEVMODEW`s of 548 bytes (`dmSize` 220, `dmDriverExtra` 328, device name `cdd`). It keeps only the formats `D3DDDIFMT_A8R8G8B8` (32 bpp), `R8G8B8` (24), `R5G6B5` (16) and `P8` (8), skips the modes with flag 0x10, converts the rotation (2, 3, 4 → `dmDisplayOrientation` 1, 2, 3; width and height swapped for 90° and 270°) and the scaling (→ `dmDisplayFixedOutput`). If dxgkrnl returns no mode, it returns 4 dummy modes 800×600, 32 bpp, 60 Hz.

### win32k interface

`EngQueryW32kCddInterface` (win32k) fills a `W32KCDD_INTERFACE` of 0x68 bytes (version 2), at PDEV +0xDC. CDD puts its own callbacks in it before the call:

| Offset | Callback |
|--------|----------|
| +0x34 | `CddAddD3DDirtyRgn` (0x2746C): adds a D3D dirty rectangle |
| +0x3C | `CddW32kCloseProcess` (0x1C9C8): calls `OnCloseProcess` of each bitmap of the process |
| +0x40 | `CddW32kUpdateSQMData` (0x20A94) → `CddSqmUpdate`: SQM data (ROP counters) |
| +0x44 | `CddDriverSupportsLiteModeChange` (0x211E0) |
| +0x48 | `CddUpdateDevMode` (0x205B0) |

In remote mode (`CddEngQueryW32kCddInterface` with the last parameter ≠ 0), +0x3C, +0x40, +0x34 and +0x4C are replaced by the `Rmt*` versions. The functions given by win32k in the interface (+0x08, +0x14, +0x5C …) are used for the mode queries and the GDI engine callbacks (`EngFillRectCallback`, `EngWritePixelCallback`).

### Present worker thread

`WorkerThreadStartup` (0x1D6CC) opens the process returned by win32k (`ObOpenObjectByPointer`, kernel handle) and creates `PresentWorkerThread` (0x169D8) in it with `PsCreateSystemThread`, then waits until the thread has signalled that it started. The thread:
1. Raises its priority to 14 (`KeSetActualBasePriorityThread`), reads the timer resolution (`ZwQuerySystemInformation(SystemBasicInformation)`) and computes the present period from the refresh rate of the mode.
2. Loops on `KeWaitForMultipleObjects`: the command event (+0x8EC), the dirty-region / present events and a periodic `KeSetTimer`.
3. On a present: takes the dirty region of the shadow surface (`CDirtyRegion`, scroll optimisation with `GetScrollData`), flushes the GDI hardware commands, and sends the rectangles to dxgkrnl (`CddPresentBlt`, `CddPresentColorFill`, `DxgkCddPresent` = interface +0x38). The VSync event it waits on comes from `DxgkCddWaitForVerticalBlankEvent` (+0x50). It skips the present while the display is off or in low-power mode (PDEV +0x940, see [WNF states](#wnf-states)) ?.
4. Runs the commands sent by `CddIssueCommand` (0x1DE98: stores the command at +0xAF8, signals the event, waits for the completion event, returns the status at +0xB00). Commands seen: 6 / 7 (mode change from `DrvAssertMode`, disable / enable), 8 (`DrvNotify`: new position of the display, from `DN_DEVICE_ORIGIN`), 4 (`SetPalette`), 5 (`SetGammaRamp`), 13 (stop using the device: sent by `DrvDisablePDEV`, and first by `CddTryTDRRecovery`), 12 (recreate the device after a TDR, `CddTryTDRRecovery`), 9 / 1 / 2 / 3 (device creation, `TryCreateDevice` / `CreateAndEnableDevice`) ?. `CddIssueCommand` refuses 0 and 16 (watchdog assertion).

`CDDPDEV::CheckDeviceRemoved` marks the device as lost on `STATUS_DEVICE_REMOVED` (0xC00002B6) or 0xC01E0200, and asks for a GDI mode reset. `TriggerGdiModeReset` (0x28E9C) sends a `DXGK_DIAG_CODE_POINT_PACKET` (code point 51, 52 or 53) to dxgkrnl, then `SMgrGdiCallout(8, …)` of watchdog.sys.

### DrvAssertMode (0x16608)

`DrvAssertModeInternal` (0x16660) runs under the device lock. It saves the image name of the calling process (`PsGetProcessImageFileName`, 16 bytes at PDEV +0x8DC, diagnostics only), updates the visible region of the shadow surface, and sends command 7 (enable) or 6 (disable) to the worker thread. When enabling fails with one of the mode errors 0xC01E0306, 0xC01E0333, 0xC01E0338, 0xC01E0301, 0xC01E0302, it triggers a GDI mode reset (code point 52).

### Remote mode

When `DrvEnableDriver` receives a 20-byte `DRVENABLEDATA`:
1. The 2 dispatch tables (`g_CddDispatchTbl`, `g_RdpDispatchTbl`, 103 entries each) are cleared. If the driver path (+0x0C) is not `\SystemRoot\System32\WORKERDD.dll` and +0x10 ≠ 0, the mode is 3 (full remote) and the semaphore `g_hsemRmt` is created; otherwise mode 2 (pass-through).
2. The remote driver is loaded with `ZwSetSystemInformation(26 = SystemLoadGdiDriverInformation, {path, …}, 28)`; its section pointer is kept (`g_RpdDriverSectionPointer`) and its `DrvEnableDriver` is called by `RmtpEnableAndVerifyDriver` (0x2797C), which copies its functions in `g_RdpDispatchTbl` (index < 103) and, in mode 3, checks that it doesn't export a function missing from `RdpAllowedDispatchTbl`.
3. Mode 3: CDD's own `CddEnableDriver` is also loaded in `g_CddDispatchTbl`, and win32k receives the 34 `Rmt*` functions (table at 0x314A0), which send each call to the remote driver and/or to CDD (`SURFACCESS`, `RemotePDevMgr`).
4. Mode 2: win32k receives the functions of the remote driver, with `DrvEnablePDEV`, `DrvDisablePDEV`, `DrvEnableSurface`, `DrvDisableSurface`, `DrvSetPointerShape`, `DrvMovePointer(Ex)` replaced by the `RmtPassThrough*` versions, and index 8 (`DrvDisableDriver`) by the function at `off_31320`.

`RmtDisableDriver` (0x29F38) calls `DrvDisableDriver` of both drivers, unloads the remote driver (`ZwSetSystemInformation(27 = SystemUnloadGdiDriverInformation)`) and frees the PDEV manager and the semaphore. This code is probably never used on the phone (no Remote Desktop).

### Registry

`DrvEnablePDEVInternal` reads one value with `RtlQueryRegistryValuesEx(RTL_REGISTRY_ABSOLUTE, …, RTL_QUERY_REGISTRY_DIRECT | RTL_QUERY_REGISTRY_TYPECHECK)`:

| Key | Value | Type | Default | Use |
|-----|-------|------|---------|-----|
| `\Registry\Machine\Software\Microsoft\Windows\Cdd` | `EnableScrollRect` | REG_DWORD | 0 | `g_EnableScrollRect`, tested by `BitBltBitmap`: scroll (screen-to-screen) optimisation of the BitBlts |

`g_DisableCacheCoherency` (0x31E50) is tested in `DrvEnablePDEVInternal` (sets bit 0x20000000 of the capabilities) but nothing writes it.

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x41C6013DA3BC0875 `WNF_PO_SCENARIO_CHANGE` (`.rdata:0x2F2DC`), published by [ntoskrnl](./ntoskrnl.md) (`PopDiagNextSleepStudySession`) | `PO`, 1 | 20 bytes, read with `ExQueryWnfStateData` in `CddWnfStateChangeCallback` (0x28CB0): GUID of the power scenario + DWORD | GUID = `GUID_SPM_LOW_POWER_CS` `{CC99192B-8B8E-44FD-B0A9-EF62141B4D29}` → PDEV +0x940 = 1 (low-power connected standby, tested by the worker thread), any other GUID → 0. Watchdog event 0x225 / 0x22E |

The subscription itself is made by dxgkrnl: `DxgkCddSubscribeWnfStateChange` (interface +0xC4) allocates a 16-byte context (tag `DxgK`: subscription, callback, context, process) and calls `ExSubscribeWnfStateChange`; cdd.dll doesn't import it.

### Diagnostics

No ETW provider. Errors, assertions and events go to the watchdog log of `watchdog.sys` (`WdLogNewEntry5_*` + `WdLogEvent5_*`); each failure writes a second entry with the image base and size (`gCddImageInfo`) and the marker 0x0CDDBA5E. `DbgLog` (0x2740C) prints the ASCII messages (`PresentWorkerThread: CDDDEVLOCK is not held`, `CddBitmap::Release m_hsemBmp is still owned!` …) with `DbgPrintEx(0x70, 0, …)`. Pool and `EngAllocMem` tag: `Dcdd`.
