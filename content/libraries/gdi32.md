## GDI32.DLL

The GDI client library of Windows Phone 8.1, cut down to what the phone still needs: D3DKMT, OPM, regions, display DCs and device capabilities.  
`GDI32.DLL` is a small DLL (16 KB of code, 305 functions, named from the PDB `gdi32.pdb`, internal names `Moderncore*`). It has almost nothing left of the desktop GDI: no drawing, no fonts, no bitmaps, no brushes or pens, no printing. What remains:
- 245 win32k system call stubs (0x1000…0x10F4, the same table as [DCOMP.DLL](./dcomp.md#system-calls)). 114 of them are exported directly under their documented user-mode name: all the `D3DKMT*` functions (graphics kernel thunks, served by win32k → [dxgkrnl.sys](../drivers/dxgkrnl.md)) and the OPM / certificate functions.
- Thin wrappers for 8 D3DKMT functions whose user structure differs from the kernel one ([D3DKMT wrappers](#d3dkmt-wrappers)).
- The regions (`CreateRectRgn`, `CombineRgn`, …) with the usual user-mode fast path on the region attribute shared with win32k, display DCs (`CreateICW`, `DeleteDC`), `GetDeviceCaps` and `DeleteObject` ([GDI objects](#gdi-objects)).
- Stubs that fail with `ERROR_NOT_SUPPORTED` for the rest of the GDI API that is still exported (`GetStockObject`, `SelectObject`, `FillRgn`, `SelectClipRgn`, …).

It relies on the GDI shared memory mapped by win32k (handle table, device caps, uniqueness counters) and calls back into [MinUser.dll](./minuser.md) (`ModerncoreUserInit`) once GDI is initialised. Users found in the other pages: [MinUser.dll](./minuser.md) (static import: `GdiDllInitialize`, `ModerncoreGdiInit`, `CreateICW` / `DeleteDC` for `GetDC` / `ReleaseDC`, `GetDeviceCaps`, stock objects), [CompServer.dll](./compserver.md) (`D3DKMTSetProcessSchedulingPriorityClass`) and [MirrorUX.dll](./mirrorux.md) (`D3DKMTNetDisp*Miracast*`) load it with `LoadLibraryExW`. [DWMCORE.DLL](./dwmcore.md) imports `D3DKMTOpenAdapterFromGdiDisplayName`, `D3DKMTQueryAdapterInfo`, `D3DKMTCloseAdapter`, `GdiEntry13` and `DrvQueryAdapterPopulationUniqueness` from `api-ms-win-dx-d3dkmt-l1-1-0.dll`, and [CompClient.dll](./compclient.md), [ShellChromeAPI.dll](./shellchromeapi.md) and [UIXMobile.dll](./uixmobile.md) take `GetDeviceCaps` from `ext-ms-win-rtcore-gdi-devcaps-l1-1-0.dll`: those API sets probably resolve to this DLL (?, the API set schema wasn't analysed).

Location on the phone: `C:\Windows\System32\gdi32.dll` ?  

### Imports

| DLL | Functions |
|-----|-----------|
| MinUser.dll | `ModerncoreUserInit`, `UserClientDllInitialize` |
| ntdll.dll | `RtlInitUnicodeString`, `RtlFreeHeap`, `RtlDecodePointer`, `_wcsicmp`, `_wcsnicmp`, `memset`, `memcpy`, `RtlCaptureContext` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalAlloc`, `LocalFree` |
| api-ms-win-core-synch-l1-2-0.dll | `InitializeCriticalSectionEx`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `DisableThreadLibraryCalls` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |

`RtlCaptureContext`, processthreads and errorhandling are the `/GS` failure report (`__report_gsfailure`). `UserClientDllInitialize` is imported but its thunk (0x4D502E98) is never called. There is no CRT DLL (no msvcrt).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| win32k (GDI, D3DKMT, OPM, composition, Moderncore) | `SVC 1` system calls 0x1000…0x10F4 ([System calls](#system-calls)) | Every function ends in the kernel, apart from the region / devcaps fast paths |
| GDI shared memory (mapped by win32k, `PEB+0x94`) | read directly ([ModerncoreGdiInit](#moderncoregdiinit-0x4d502940)) | Handle table, device caps (+0x100000), uniqueness counters |

No DLL is loaded at run time, and no process, COM server or file is opened. `bCreateDCW` only accepts the display device (`DISPLAY`, `\\.\DISPLAY…`); the printer code left in `InternalDeleteDC` calls `fpClosePrinter` (0x4D50502C), a pointer that nothing in the DLL sets.

### Exports

152 exports, ordinals 1004…1154 plus `_DllMainCRTStartupForGS` (the entry point, exported with a garbage ordinal 1297100200).

**System call stubs** (`MOVW R12, #n; SVC 1; BX LR`, the export address *is* the stub):

| Exports | Numbers | Kernel names |
|---------|---------|--------------|
| `D3DKMT*`, except the 8 wrappers below and the two Miracast calls of the next row (102 exports, ordinals 1012…1123) | 0x1052…0x10B8 | `NtGdiDdDDI*` with the same suffix |
| `D3DKMTNetDispStartMiracastDisplayDevice2` (1065), `D3DKMTNetDispStopMiracastDisplayDevice` (1066) | 0x10C6, 0x10C7 | `NtModerncoreDdDDINetDispStartMiracastDisplayDevice`, `NtModerncoreDdDDINetDispStopMiracastDisplayDevice` |
| `ConfigureOPMProtectedOutput` (1006), `CreateOPMProtectedOutputs` (1008) | 0x1050, 0x1051 | `NtGdiConfigureOPMProtectedOutput`, `NtGdiCreateOPMProtectedOutputs` |
| `DestroyOPMProtectedOutput` (1126), `GetCOPPCompatibleOPMInformation` (1134), `GetCertificate` (1135), `GetCertificateSize` (1136) | 0x10B9…0x10BC | `NtGdi*` |
| `GetOPMInformation` (1139), `GetOPMRandomNumber` (1140), `GetSuggestedOPMProtectedOutputArraySize` (1144), `SetOPMSigningKeyAndSequenceNumbers` (1152) | 0x10C0, 0x10C1, 0x10C2, 0x10C4 | `NtGdi*` |

**Functions** (the internal name, from the PDB, in brackets when it differs):

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1023 | `D3DKMTCreateAllocation` | 0x4D501BD4 | `D3DKMT_CREATEALLOCATION *` ([wrappers](#d3dkmt-wrappers)) |
| 1032 | `D3DKMTCreateSynchronizationObject` | 0x4D501DC0 | `D3DKMT_CREATESYNCHRONIZATIONOBJECT *` |
| 1048 | `D3DKMTGetDeviceState` (`ModerncoreGetDeviceState`) | 0x4D502CC8 | `D3DKMT_GETDEVICESTATE *` |
| 1064 | `D3DKMTNetDispStartMiracastDisplayDevice` | 0x4D501EC8 | `a1, a2` → `NtModerncoreDdDDINetDispStartMiracastDisplayDevice(a1, 1, a2)` |
| 1069 | `D3DKMTOpenAdapterFromGdiDisplayName` (`ModerncoreOpenAdapterFromGdiDisplayName`) | 0x4D502CEC | `D3DKMT_OPENADAPTERFROMGDIDISPLAYNAME *` |
| 1075 | `D3DKMTOpenResource` | 0x4D501CE8 | `D3DKMT_OPENRESOURCE *` |
| 1114 | `D3DKMTSignalSynchronizationObject` | 0x4D501E6C | `D3DKMT_SIGNALSYNCHRONIZATIONOBJECT *` |
| 1120 | `D3DKMTWaitForSynchronizationObject` | 0x4D501E18 | `D3DKMT_WAITFORSYNCHRONIZATIONOBJECT *` |
| 1004 | `DrvQueryAdapterPopulationUniqueness` (`ModerncoreQueryAdapterPopulationUniqueness`) | 0x4D502D40 | none; returns the DWORD at shared memory +0x1000A0 |
| 1132 | `GdiEntry13` (`ModerncoreQueryDisplaySettingsUniqueness`) | 0x4D502D64 | none; returns the DWORD at shared memory +0x100090 |
| 1146 | `ModerncoreGdiInit` | 0x4D502940 | none; returns TRUE when GDI is initialised |
| 1131 | `GdiDllInitialize` (`ModerncoreGdiDllInitialize`) | 0x4D5029D0 | `HINSTANCE, DWORD reason, PVOID` |
| 1137 | `GetCurrentDpiInfo` | 0x4D501B98 | arguments passed through to `NtGdiGetCurrentDpiInfo` (0x10BD) |
| 1007 | `CreateICW` | 0x4D502130 | `LPCWSTR driver, LPCWSTR device, LPCWSTR port, const DEVMODEW *` |
| 1124 | `DeleteDC` (`ModerncoreDeleteDC`) | 0x4D502A04 | `HDC` |
| 1133 | `GdiReleaseDC` (`ModerncoreGdiReleaseDC`) | 0x4D502A24 | `HDC` |
| 1138 | `GetDeviceCaps` (`ModerncoreGetDeviceCaps`) | 0x4D502A58 | `HDC, int index` |
| 1125 | `DeleteObject` (`ModerncoreDeleteObject`) | 0x4D502A7C | `HGDIOBJ` |
| 1010 | `CreateRectRgn` | 0x4D502AC8 | `int l, int t, int r, int b` |
| 1011 | `CreateRectRgnIndirect` | 0x4D502AF4 | `const RECT *` |
| 1009 | `CreatePolygonRgn` | 0x4D5023AC | `const POINT *, int count, int mode` → `NtGdiPolyPolyDraw(mode, points, &count, 1, 6)` (6 = polygon region) |
| 1128 | `ExtCreateRegion` | 0x4D502B3C | `const XFORM *, DWORD, const RGNDATA *` |
| 1005 | `CombineRgn` | 0x4D502A9C | `HRGN dst, HRGN src1, HRGN src2, int mode` |
| 1127 | `EqualRgn` | 0x4D502B18 | `HRGN, HRGN` → `NtGdiEqualRgn` |
| 1141 | `GetRegionData` | 0x4D502BA0 | `HRGN, DWORD size, RGNDATA *` → `NtGdiGetRegionData` (size forced to 0 when the buffer is NULL) |
| 1142 | `GetRgnBox` | 0x4D502BCC | `HRGN, RECT *` |
| 1147 | `OffsetRgn` | 0x4D502C4C | `HRGN, int dx, int dy` |
| 1148 | `RectInRegion` | 0x4D502C74 | `HRGN, const RECT *` |
| 1154 | `SetRectRgn` | 0x4D502C98 | `HRGN, int l, int t, int r, int b` |
| 1129, 1145, 1149, 1151, 1153 | `FillRgn`, `IntersectClipRect`, `SelectClipRgn`, `SetMetaRgn`, `SetPolyFillMode` (`ModerncoreSelectClipRgn`) | 0x4D502B84 | any; after `ModerncoreGdiInit`, `SetLastError(ERROR_NOT_SUPPORTED)` and return 0 |
| 1143, 1150 | `GetStockObject`, `SelectObject` | 0x4D502D88 | any; `SetLastError(ERROR_NOT_SUPPORTED)`, return NULL (no init) |
| 1130 | `GdiClearStockObjectCache` | 0x4D502D9C | none; does nothing |

All the GDI exports (DC, objects, regions) start with `ModerncoreGdiInit` and return 0 if it fails. The D3DKMT and OPM functions don't, except `D3DKMTOpenAdapterFromGdiDisplayName`.

Global state (`.data`):

| Address | Name | Comment |
|---------|------|---------|
| 0x4D505230 | (`dword_4D505230`) | GDI initialised |
| 0x4D505240 | `gcsModerncoreGdiInit` | Critical section of `ModerncoreGdiInit` (created / deleted by `GdiDllInitialize`) |
| 0x4D505028 | `gW32PID` | `TEB.ClientId.UniqueProcess & ~3`, compared with the owner of each handle table entry |
| 0x4D505024, 0x4D505038 | `pGdiSharedMemory`, `pGdiSharedHandleTable` | `PEB+0x94` (`GdiSharedHandleTable`) |
| 0x4D505034 | `pGdiDevCaps` | shared memory +0x100000 |
| 0x4D505030 | `pGdiHandleCache` | `PEB+0xC4` (`GdiHandleBuffer`) |
| 0x4D505020 | `GdiBatchLimit` | 0 in the file and never written: every batched command is flushed at once ([DeleteObject](#deleteobject)) |
| 0x4D50502C | `fpClosePrinter` | Encoded pointer, never set |

### Startup

`_DllMainCRTStartupForGS` (0x4D502DA8, the PE entry point): on `DLL_PROCESS_ATTACH`, `DisableThreadLibraryCalls` and `__security_init_cookie` (which fast-fails with code 6 if the cookie wasn't randomised by the loader). Nothing else: there is no `DllMain`.  
`GdiDllInitialize` (0x4D5029D0) is the real attach / detach routine, but nobody in this DLL calls it: reason 1 creates `gcsModerncoreGdiInit` (`InitializeCriticalSectionEx`), reason 0 deletes it. It is called by [MinUser.dll](./minuser.md#startup): its `DllMain` calls `UserClientDllInitialize(hinst, reason)` on attach and detach, which ends with `GdiDllInitialize(hinst, reason)`, like `user32` on the desktop.

### ModerncoreGdiInit (0x4D502940)

Lazy, once per process, under `gcsModerncoreGdiInit`:

1. `ZwGdiInit` (0x10C3). If it fails, returns FALSE (and the next call tries again).
2. Reads the GDI pointers that win32k put in the PEB: `pGdiSharedMemory` = `pGdiSharedHandleTable` = `PEB+0x94`, `pGdiDevCaps` = that + 0x100000, `pGdiHandleCache` = `PEB+0xC4`; `gW32PID` from the TEB.
3. Marks GDI as initialised and calls `MinUser!ModerncoreUserInit` ([process connection](./minuser.md#moderncoreuserinit-0x10018134), which itself calls `ModerncoreGdiInit` again: the second call returns at once).

GDI shared memory, as used here:

| Offset | Size | Comment |
|--------|------|---------|
| 0x0 | 0x1000 × 16 | Handle table (handle index < 0x1000), see below |
| 0x100000 | ? | Device caps of the display (`GDIINFO`, read by `GetDeviceCaps`) |
| 0x100090 | 4 | Display settings uniqueness (`GdiEntry13`) |
| 0x1000A0 | 4 | Adapter population uniqueness (`DrvQueryAdapterPopulationUniqueness`) |

Handle table entry (`GDICELL`): a handle is valid in user mode when its low word is < 0x1000 and the entry matches:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Kernel object |
| 0x04 | 4 | Owner process id (bit 0 masked, compared with `gW32PID`; 0 = public for `DeleteObject`) |
| 0x08 | 2 | Upper word of the handle (uniqueness + type), must equal `HIWORD(handle)` |
| 0x0A | 1 | Type: 1 DC, 4 region, 0x10 brush / pen |
| 0x0C | 4 | User-mode attribute (DC: `DC_ATTR`, its first DWORD is the LDC; region: [region attribute](#regions)) |

### D3DKMT wrappers

The phone kernel takes newer structures than the public user-mode ones for a few calls; these wrappers convert them (`/GS` functions, read from the disassembly):

- **`D3DKMTCreateAllocation`**: the caller's `pAllocationInfo` (+0x20, `NumAllocations` at +0x1C) has 0x18-byte `D3DDDI_ALLOCATIONINFO` entries. Builds an array of 0x38-byte entries (on the stack for one allocation, `LocalAlloc(LMEM_FIXED, n × 0x38)` above, `STATUS_NO_MEMORY` if it fails): +0x00…+0x10 copied (`hAllocation`, `pSystemMem`, `pPrivateDriverData`, `PrivateDriverDataSize`, `VidPnSourceId`), flags +0x14 bits 0-1 (`Primary`, `Stereo`), +0x18, +0x1C and +0x20…+0x37 zero. Swaps the pointer in the caller's structure, calls `NtGdiDdDDICreateAllocation` (0x105D), and on success copies the 6 fields back (the returned `hAllocation`); restores the pointer and frees the array.
- **`D3DKMTOpenResource`**: `STATUS_INVALID_PARAMETER` on NULL. Same thing with `pOpenAllocationInfo` (+0x0C, count at +0x08): 12-byte entries (`hAllocation`, `pPrivateDriverData`, `PrivateDriverDataSize`) extended to 0x30 bytes (rest zero), `NtGdiDdDDIOpenResource` (0x108B), 12 bytes copied back.
- **`D3DKMTCreateSynchronizationObject`**: copies `hDevice` and `Info.Type` into a zeroed 0x60-byte `…2` structure; type 1 (mutex) copies `InitialState`, type 2 (semaphore) `MaxCount` and `InitialCount`, any other type gives `STATUS_INVALID_PARAMETER`. `ZwGdiDdDDICreateSynchronizationObject` (0x1065), then the handle (+0x58 of the new structure) goes to `hSyncObject` (+0x48).
- **`D3DKMTWaitForSynchronizationObject`**: 0xC8-byte structure: `hContext`, `ObjectCount` (kept), `ObjectHandleArray` (at most 32 handles copied), rest zero; `ZwGdiDdDDIWaitForSynchronizationObject` (0x10B6).
- **`D3DKMTSignalSynchronizationObject`**: same with a 0x1D0-byte structure, plus the flags (+0x88); `ZwGdiDdDDISignalSynchronizationObject` (0x10B1).
- **`D3DKMTGetDeviceState`**: `ZwGdiDdDDIGetDeviceState` (0x1074); on success, for `StateType` 3 (`D3DKMT_DEVICESTATE_RESET`), clears bit 0 of the result (+0x08).
- **`D3DKMTOpenAdapterFromGdiDisplayName`**: returns `STATUS_UNSUCCESSFUL` if `ModerncoreGdiInit` fails. Opens a direct DC on `DeviceName` (+0x00, 32 WCHARs) with `bCreateDCW(name, name, NULL, NULL, 0)`, `ZwGdiDdDDIOpenAdapterFromHdc` (0x1086), copies `hAdapter`, `AdapterLuid` and `VidPnSourceId` to +0x40…+0x4C, then `InternalDeleteDC`. A name that isn't `\\.\DISPLAY…` gives no DC and `STATUS_UNSUCCESSFUL`.
- **`D3DKMTNetDispStartMiracastDisplayDevice`** (the old 2-argument form): inserts 1 as the second argument of the 3-argument system call used by `…Device2` (that's how [MirrorUX.dll](./mirrorux.md#miracast-session) calls `…Device2(path, 1, hEvent)` directly).

`GetCurrentDpiInfo`: `NtGdiGetCurrentDpiInfo`; success → TRUE; `STATUS_UNSUCCESSFUL` → `ERROR_INVALID_PARAMETER`, `STATUS_INVALID_PARAMETER` → `ERROR_INVALID_HANDLE`, other errors → FALSE without last error.

### GDI objects

#### DCs

`bCreateDCW` (0x4D50207C, used by `CreateICW` with `bIC` = 1 and by `D3DKMTOpenAdapterFromGdiDisplayName`) only opens the display: the device must start with `\\.\DISPLAY`, or the driver must be `DISPLAY` (then no device name is passed) or start with `\\.\DISPLAY`; anything else returns NULL. Then `NtGdiOpenDCW(device, pdm, port, type, 1 (display), 0, 0, 0, 0)` with type 2 (information context) for `CreateICW`, 0 (direct DC) otherwise.

`DeleteDC` → `InternalDeleteDC` (0x4D502144): for an LDC-backed DC (handle type other than direct 0x01) frees the buffers of the LDC; for metafile DCs (type 0x66) fails with `ERROR_INVALID_HANDLE`. Then, if the handle is valid, clears the LDC pointer of the `DC_ATTR` (`vSetPldc`), `ZwGdiDeleteObjectApp` and frees the LDC (`bDeleteLDC`). `GdiReleaseDC` only frees the LDC. Nothing in this DLL creates an LDC: that code is a leftover of the desktop GDI.

`GetDeviceCaps` (`GetDeviceCaps_0`, 0x4D501944):
- Direct DC (type 0x01): if the `DC_ATTR` flag 0x10000 is set, the value comes from the shared display caps (`pGdiDevCaps`), else `NtGdiGetDeviceCaps`. Invalid handle: `ERROR_INVALID_PARAMETER`, 0.
- Metafile DC (0x66): `TECHNOLOGY` → 5 (`DT_METAFILE`), anything else 0.
- Other: the caps cached in the LDC (+0x50, filled once by `NtGdiGetDeviceCapsAll`, LDC flag 0x2000000).

`HORZSIZE`, `VERTSIZE`, `HORZRES`, `VERTRES`, `ASPECTX/Y/XY`, `LOGPIXELSX/Y` always go to `NtGdiGetDeviceCaps` (they depend on the DPI virtualisation of the caller). Constants: `NUMBRUSHES` -1, `CURVECAPS` 511, `LINECAPS` 254, `POLYGONALCAPS` 255, `CLIPCAPS` 1, `NUMRESERVED` 20. Unknown indexes return 0.

#### DeleteObject

`DeleteObject_0` (0x4D50225C) checks the handle table entry (type, uniqueness, owner = this process or public), then by type:

| Handle type (bits 16-22) | Action |
|--------------------------|--------|
| 0x01 DC | `InternalDeleteDC` |
| 0x04 region | `DeleteRegion` (batched) |
| 0x26 metafile, 0x46 enhanced metafile, 0x09 colour space | FALSE |
| stock object (bit 23) | TRUE, nothing deleted |
| 0x10 brush, 0x30 pen | batched if the brush is not in use (attribute flags & 0xB = 0), else system call |
| other | `ZwGdiDeleteObjectApp` (0x1005) |

Batching uses the GDI batch of the TEB (only when `TEB.Win32ThreadInfo` is set and there is room, offset + 8 ≤ 0x4D8): an 8-byte command (size 8, command 7 for a brush / pen, 8 for a region, then the handle) is appended at `TEB+0x1DC + offset`, `TEB+0x1D4` (offset) and `GdiBatchCount` (`TEB+0xF70`) are increased, and `NtGdiFlush` is called when the count reaches `GdiBatchLimit`, which is always 0 here, so each delete is sent at once.

#### Regions

Region attribute (user-mode, shared with win32k, entry +0x0C):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Flags: 0x10 valid, 0x20 dirty (set by every user-mode change) |
| 0x04 | 4 | Complexity: 1 `NULLREGION`, 2 `SIMPLEREGION`, else complex (kernel only) |
| 0x08 | 16 | Bounding `RECT` |

- `CreateRectRgn` (`CreateRectRgn_0`, 0x4D502444): orders the coordinates, rejects anything outside ±0x8000000 (`ERROR_INVALID_PARAMETER`). Takes a cached region handle from the PEB handle cache (`hGetPEBHandle`, 0x4D501FC8: lock = TEB pointer swapped in with `LDREX/STREX`, count at +0x0C, 8 slots at +0x5C…+0x78) or creates one with `NtGdiCreateRectRgn(0, 0, 1, 1)`, then writes the attribute directly (flags 0x30, null region for an empty rectangle).
- `ExtCreateRegion` with no `XFORM` and a single rectangle (`RGNDATA.rdh.nCount` = 1) → `CreateRectRgn` on the rectangle after the 32-byte header; otherwise `ZwGdiExtCreateRegion`. NULL data: `ERROR_INVALID_PARAMETER`.
- `SetRectRgn`, `OffsetRgn` (coordinates must stay within 28 bits, else 0), `GetRgnBox`, `RectInRegion` work on the attribute for null / simple regions, else `ZwGdiSetRectRgn` (0x10C5), `NtGdiOffsetRgn`, `NtGdiGetRgnBox`, `NtGdiRectInRegion`.
- `CombineRgn` (`CombineRgn_0`, 0x4D50259C) handles `RGN_COPY` (5) and `RGN_AND` / `RGN_OR` / `RGN_DIFF` of null and simple regions in user mode when the result is a rectangle (with `iRectRelation`, 0x4D5023D0: 1 = first inside second, 2 = second inside first, 3 = disjoint, 0 = overlap); the other cases and `RGN_XOR` go to `ZwGdiCombineRgn`.

### System calls

245 stubs from `NtUserGetThreadState` (0x1000) to `NtValidateCompositionSurfaceHandle` (0x10F4), the same names and numbers as the [DCOMP.DLL table](./dcomp.md#system-calls) (composition, token manager, input sinks, `NtUser*` display configuration, `NtModerncore*` included). Only the D3DKMT / OPM ones are exported; the others used internally are `NtGdiOpenDCW` (0x1011), `ZwGdiDeleteObjectApp` (0x1005), `NtGdiFlush` (0x1004), the region calls (0x1007, 0x1008, 0x100A, 0x100C…0x1010, 0x1013, 0x10C5), `NtGdiGetCurrentDpiInfo` (0x10BD), `NtGdiGetDeviceCaps` (0x10BE), `NtGdiGetDeviceCapsAll` (0x10BF) and `ZwGdiInit` (0x10C3). The remaining stubs (composition, `NtUser*`, `NtModerncore*` other than Miracast) are dead code in this DLL.

No RPC, WNF, ETW, registry or COM.
