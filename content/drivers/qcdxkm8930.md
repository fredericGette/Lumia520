## Qcdxkm8930.sys

Qualcomm WDDM display miniport driver (DirectX kernel-mode driver, build `P:\direct3d_kmd\rel\8.3.1\miniport\arm\Release\qcdxkm8930.pdb`).  
It is the "graphics adapter" of the Lumia 520: it drives the MDP display controller and the MIPI DSI panel, the Adreno 305 GPU, the 2D blitter, the rotator and the video codec core (VIDC, "VED"), and it creates the child devices of the adapter (the panel monitor and the camera AVStream device).  
It registers with dxgkrnl through `DxgkInitialize` (DDI interface version `0x300E` = `DXGKDDI_INTERFACE_VERSION_WIN8`); KMDF is only used as a library (`WdfDriverCreate` with `WdfDriverInitNoDispatchOverride`, no WDF device).  
The GPU/MDP/video memory goes through the SMMU driver qcvcm8930.sys (imports `Vcm*`). The panel description comes from the ACPI method `_ROM`, the panel command sequences and the backlight are delegated to [oempanel.sys](./oempanel.md), the OPM keys are read from `C:\DPP\QCOM\OPM_PUB.PROVISION` / `OPM_PRIV.PROVISION` and kept in the TrustZone trustlet `qcom.tz.winsecapp` through [qcscm8930.sys](./qcscm8930.md).

There's no named `\Device\` object and no symbolic link created by the driver: the device objects belong to dxgkrnl (`\Device\Video0`…), and user mode reaches the driver only through D3DKMT calls (escapes, allocations, …).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcdxkm8930` ?  
`HKEY_LOCAL_MACHINE\SOFTWARE\QCOM\Drivers\DxKMD`  

Registry key `HKEY_LOCAL_MACHINE\SOFTWARE\QCOM\Drivers\DxKMD` (read by `sub_4A3D3C` with root 0, or by the components through the services table, `sub_49E7A4`). All values are REG_DWORD:  
| Registry value | value | comment |
|----------------|-------|---------|
| `Miniport\EvtLogFlags` | ? | Read in `DriverEntry`, flags of the internal event log (`sub_4058D0`) |
| `Miniport\BltLibFlags` | default 2, or 3 when the GPU (engine 0) is of generation ≤ 2 (Adreno 2xx / 3xx) | Adapter `+0x16CC`. Bit 0: use the 2D blitter for … ? (`sub_4A71F8`) |
| `Miniport\{9572E219-4CA5-421A-A1EB-967BCA3042D6}` | ? | When present, its value is given to `sub_4A0694` (power configuration) and `PowerOverrides` is not read |
| `Miniport\Engine\<n>\PowerOverrides`, `Miniport\Display\PowerOverrides` | ? | Per engine `n` = 0…7, and for the display. Bit 0, 1, 2 = three power flags (adapter `+0x374` + 0x258×n, display `+0x160C`). Names of the flags ? (`sub_4A0854`) |
| `Miniport\DisableThermalMitigation`, `Miniport\Engine\<n>\DisableThermalMitigation` | 0 | ≠ 0: the thermal cooling interface is ignored for all engines / for engine `n` (`sub_4A5018`) |
| `Miniport\PanelOverride\Width`, `…\Height` | ? | Forced panel resolution. Accepted only if 480–768 × 640–1280 (portrait) or 1024–1920 × 768–1080 (landscape) (`sub_4B3B9C`) |
| `Miniport\BACKLIGHT\DisableSBC` | 0 | ≠ 0: clears bit 3 of the backlight features (SBC = ?) (`sub_435F98`) |
| `Miniport\BACKLIGHT\DisableCABL` | 0 | ≠ 0: clears bit 1 of the backlight features (CABL = Content Adaptive BackLight) |
| `Miniport\BACKLIGHT\DbgMsgs` | 0 | Debug messages of the backlight ramp (`sub_4388AC`) |
| `Miniport\BACKLIGHT\MaxRampTime` | default 500 | Backlight ramp time (ms ?) |
| `Miniport\DISPLAY\Engine{D1,D2,Blt,Rot}{Core,BW}{Scale,Min}` | ? | 16 values: core-clock and bus-bandwidth scale / minimum of the display pipes D1 and D2, the blitter and the rotator (`sub_441EE0`) |
| `Miniport\DISPLAY\DisableAviInfoFramePacket` | ? | HDMI (`sub_4441A0`) |
| `Miniport\DISPLAY\EnableHDCPInQDI` | ? | HDMI HDCP |
| `Miniport\DISPLAY\MaxNumReAuthentication` | ? | HDMI HDCP |

Other registry keys:  
| Key | Values | Comment |
|-----|--------|---------|
| `HKLM\System\CurrentControlSet\Control\GraphicsDrivers\MemoryManager` | `SystemMemoryCommitLimit`, `SmallSystemMemorySize`, `MinimumSystemMemoryCommitLimit` (MB) | GPU system-memory commit limit (`sub_4ABABC`): `SystemMemoryCommitLimit` if set, otherwise max(`MinimumSystemMemoryCommitLimit` (default 64 MB), (RAM − `SmallSystemMemorySize` (default 512 MB)) / 2) |
| `HKLM\System\CurrentControlSet\Control\ProductOptions` | `ProductSuite` | `PhoneNT` → the provisioning files are read from `\DosDevices\C:\DPP\QCOM\` (same DPP library as [qcbluetooth8930.sys](./qcbluetooth8930.md)) |
| Adapter software key (dxgkrnl) | `HardwareInformation.ChipType`, `HardwareInformation.AdapterString` (`Adreno %i`), `HardwareInformation.DacType` (`InternalDAC`), `HardwareInformation.BiosString` (`Version %2.2i.%2.2i`) | Written by `sub_4AB1F4`. The Adreno number comes from the GPU core id: 225, 305 (`0x200131`), 320 (`0x200140`), 330 (`0x20014A`), 420 (`0x3001A4`) |

GUIDs of the ETW providers (`McGenEventRegister`):  
`{BE491BBA-E5B9-4EC1-BBC3-D439DEB7DF48}` (main provider, `sub_4058D0`)  
`{310A912A-008E-4148-BB92-3DB5037B8CA5}` (video engine "VED", `sub_4B97E4`)

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\DxgKrnl` | dxgkrnl.sys | Loaded with `ZwLoadDriver(\Registry\Machine\System\CurrentControlSet\Services\DXGKrnl)`. [internal IOCTL 0x230047](#internal-ioctl-0x230047--ioctl_video_ddi_func_register) / [internal IOCTL 0x23003F](#internal-ioctl-0x230047--ioctl_video_ddi_func_register) |
| Interface `{FB4F07CD-8D4C-4413-92C2-E2C9CAED9F43}` | [qcchipinfo8930.sys](./qcchipinfo8930.md) | Chip family / id / version: [IOCTL 0x8C1F2014, 0x8C1F2008, 0x8C1F2004](#ioctl-0x8c1f2014--0x8c1f2008--0x8c1f2004) |
| Interface `{0D4A3F63-0D08-49A1-B91C-C60576894174}` | [oempanel.sys](./oempanel.md) | Nokia panel driver. [IOCTL 0x4000](#ioctl-0x4000--panel-driver-registration): exchange of function-pointer tables |
| Interface `{41C66D2A-A9F1-40CA-A329-AE096C03EE68}` | [qcscm8930.sys](./qcscm8930.md) | TrustZone, trustlet `qcom.tz.winsecapp`: [internal IOCTL 0xC3514004](#internal-ioctl-0xc3514004--opm-keys-in-trustzone) for the OPM keys |
| — | qcvcm8930.sys | SMMU / virtual memory contexts, by direct imports (`VcmCreateExtended`, `VcmReserve*`, `VcmBack*`, `VcmRegisterIsr`, …) |
| — | ksecdd.sys | `BCrypt*` (OPM: AES-CBC, hashes, random numbers) |
| ACPI node of the adapter | [acpi.sys](./acpi.md) | Methods `_ROM`, `BLCP`, `PPCC`, `PGCT`, `PIGC`, `PGRT`, `PBRT`, `PCSC` (see [ACPI methods](#acpi-methods)) |

### Start-up

1. `DriverEntry` (0x406D84): reads `EvtLogFlags`, initialises the event log and the main ETW provider (`sub_4058D0`), fills the `DRIVER_INITIALIZATION_DATA` (see [DDI functions](#ddi-functions)) and calls `DxgkInitialize` (`sub_451754`), then `WdfDriverCreate` (no device add callback).
2. `DxgkInitialize` (displib, `sub_451754`): accepts the DDI versions `0x1052`, `0x1053`, `0x2005` and ≥ `0x300E`, loads dxgkrnl, opens `\Device\DxgKrnl` (10 retries, 5 ms apart) and gets the dxgkrnl entry point with [internal IOCTL 0x230047](#internal-ioctl-0x230047--ioctl_video_ddi_func_register). It wraps `DxgkDdiUnload` with `sub_4BEAE4`.
3. `DxgkDdiStartDevice` (`sub_4A71F8`): copies the dxgkrnl callbacks, maps the memory resources of the device (`sub_4A4434`, see [Resources](#resources)), parses the configuration (`sub_49C168`), creates the threads (`sub_4A0A00`), reads the power / thermal / memory registry values, starts the engines and the display (`sub_4AA808`), opens the qcscm8930 interface for OPM (`sub_4AABC0` → `sub_4AD348`), writes the `HardwareInformation.*` values, declares the AVStream child (`sub_4AB4A8`) and reads `BltLibFlags`.

### DDI functions

`DRIVER_INITIALIZATION_DATA` built by `DriverEntry` (Version `0x300E`). Entries not listed are NULL. `sub_49DD80` is an empty function that returns `STATUS_SUCCESS`:  
| DDI | Function | Comment |
|-----|----------|---------|
| DxgkDdiAddDevice | sub_4A7188 | |
| DxgkDdiStartDevice | sub_4A71F8 | See [Start-up](#start-up) |
| DxgkDdiStopDevice | sub_4A7A8C | |
| DxgkDdiRemoveDevice | sub_4A7AD0 | |
| DxgkDdiDispatchIoRequest | sub_49DD80 | **No-op**: the IOCTLs sent to the video device are not processed by the driver |
| DxgkDdiInterruptRoutine / DxgkDdiDpcRoutine | sub_4071A8 / sub_407680 | |
| DxgkDdiQueryChildRelations / QueryChildStatus / QueryDeviceDescriptor | sub_4A7C30 / sub_4A7E14 / sub_4A7FB4 | Children: the display outputs and the camera (`QCOM_AVStream`, see [Child devices](#child-devices)) |
| DxgkDdiSetPowerState | sub_4A0788 | |
| DxgkDdiNotifyAcpiEvent | sub_49DD80 | No-op |
| DxgkDdiUnload | sub_4A8160 | |
| DxgkDdiQueryInterface | sub_4A816C | See [Query interfaces](#query-interfaces) |
| DxgkDdiQueryAdapterInfo | sub_4A8408 | |
| DxgkDdiCreateDevice / DestroyDevice | sub_4A4380 / sub_4A4404 | |
| DxgkDdiCreateAllocation / DestroyAllocation / DescribeAllocation | sub_49D56C / sub_49D9F0 / sub_49DAE8 | |
| DxgkDdiOpenAllocation / CloseAllocation | sub_49DCD8 / sub_49DD80 (no-op) | |
| DxgkDdiGetStandardAllocationDriverData | sub_49DB80 | |
| DxgkDdiPatch / SubmitCommand / PreemptCommand / BuildPagingBuffer | sub_4A8B4C / sub_407830 / sub_407B38 / sub_4A8C94 | |
| DxgkDdiSetPointerPosition / SetPointerShape | sub_4A9278 / sub_4A92D8 | |
| DxgkDdiResetFromTimeout / RestartFromTimeout | sub_4A9388 / sub_49DD80 (no-op) | |
| DxgkDdiEscape | sub_4A95C4 | See [Escapes](#escapes) |
| DxgkDdiCollectDbgInfo | sub_407BFC | |
| DxgkDdiQueryCurrentFence | sub_4A96E8 | |
| DxgkDdiIsSupportedVidPn / RecommendFunctionalVidPn / EnumVidPnCofuncModality | sub_4A5414 / sub_4A5550 / sub_4A5B3C | |
| DxgkDdiSetVidPnSourceAddress / SetVidPnSourceVisibility / CommitVidPn | sub_403F9C / sub_4A65A8 / sub_4A6608 | |
| DxgkDdiUpdateActiveVidPnPresentPath / RecommendMonitorModes / RecommendVidPnTopology | sub_4A6E08 / sub_4A6E94 / sub_4A70C0 | |
| DxgkDdiGetScanLine / StopCapture / ControlInterrupt | sub_4A97F8 / sub_4A9784 / sub_4A7B0C | |
| DxgkDdiRender / Present | sub_4A9818 / sub_4A9EB4 | |
| DxgkDdiCreateContext / DestroyContext | sub_49F278 / sub_49F4AC | |
| DxgkDdiRenderKm | sub_4A01A4 | |
| DxgkDdiQueryVidPnHWCapability | sub_4A70D0 | |
| DxgkDdiSetPowerComponentFState | sub_403334 | |
| DxgkDdiQueryDependentEngineGroup / QueryEngineStatus / ResetEngine | sub_4AA4A8 / sub_4AA51C / sub_4AA584 | |
| DxgkDdiStopDeviceAndReleasePostDisplayOwnership | sub_4AA7B8 | |
| DxgkDdiSystemDisplayEnable / SystemDisplayWrite | sub_407DDC / sub_407F08 | Bugcheck screen |
| DxgkDdiGetChildContainerId | sub_4A7ED8 | |
| DxgkDdiPowerRuntimeControlRequest | sub_402B44 | |
| DxgkDdiSetVidPnSourceAddressWithMultiPlaneOverlay | sub_4040B0 | |

### Engines

The adapter has up to 8 engines (0x258-byte blocks from adapter `+0x190`). They are started by `sub_4AA808`, which gives each one a table of driver services (version `0xA2250001`; the display gets version `0xA2250002`): registry reads (`sub_49E7A4` DWORD, `sub_49E844` string), chip info, I/O targets (`sub_49EBC4` / `sub_49ECEC`), memory, events…  
| Index | Name | Init function | Comment |
|-------|------|---------------|---------|
| 0 | GRAPHICS | sub_4099C8 | Adreno 3D GPU (strings `LoadMicrocode`, `GmemSize`, `GmemBaseAddr`, `SMMUCount`) |
| 1 | MDPBLT | sub_41504C | MDP 2D blitter |
| 2 | ROTATOR | sub_4B9074 | MDP rotator |
| 3 | VIDEO | sub_4BAB08 | Video codec core "VED" (VIDC registers `VIDC_*`, decode/encode sessions, second ETW provider) |

The video core firmware is **embedded in the driver**: `sub_41CC98` copies 605428 bytes (0x93CF4) from `PAGEDATA:0x4C0000` to the firmware buffer ("Copying FW image"). The strings of this firmware appear byte-swapped by 32-bit words in IDA (e.g. `_GER_CED462H…` at 0x54C000).

### Resources

`sub_4A4434` copies the translated resources of the device (memory resources are mapped with `DxgkCbMapMemory`, connection resources of type 0x84 are kept). The configuration parser (`sub_49C4F0`, tags `RESOURCE`, `SMI_MEMORY`, `UEFI_FRAME_BUFFER`, `DISPLAY`, `ENGINE`…) gives a name to each of them. Names found in the driver: `MDP_REGS`, `MIPI_DSI_REGS`, `HDMI_REGS`, `TV_ENC_REGS`, `SE_CTRL_REGS`, `UEFI_FRAME_BUFFER`, `ROTATOR_REGS`, `SMI_MEMORY`. The source of this configuration text (ACPI ?) is not identified.

Hardcoded physical addresses (`sub_4A71F8`, `MmMapIoSpace`, non-cached), mapped for the components of type 19 and 25 of the list at adapter `+0x268`:  
| Type | Physical address | Size | Comment |
|------|------------------|------|---------|
| 19 | `0x07C00000` | 0x100000 | GFX3D IOMMU ? (same address as `MSM_IOMMU_GFX3D_PHYS` of the MSM8960) |
| 25 | `0x07D00000` | 0x100000 | GFX3D1 IOMMU ? |

SMMU contexts used with qcvcm8930 (names in `.rdata` 0x45553C): `VCM_MDP_VG1`, `VCM_MDP_RGB1`, `VCM_MDP_VG2`, `VCM_MDP_RGB2`, `VCM_ROT_SRC`, `VCM_ROT_DST`, `VCM_GFX_3D_USER`, `VCM_GFX_3D_PRIV`, `VCM_GFX_3D1_USER`, `VCM_GFX_3D1_PRIV`, `VCM_VCODEC_STREAM`, `VCM_VCODEC_MM1`, `VCM_VCODEC_MM2`, `VCM_JPEGD_SRC/DST`, `VCM_VPE_SRC/DST`, `VCM_IJPEG_SRC/DST`, `VCM_VFE_IMG_WR`, `VCM_VFE_MISC`, `VCM_2D0_PIX_V1`, `VCM_VCAP_VC`, `VCM_VCAP_VP`.

Clocks named by the DSI/HDMI layer (`HAL_DSI_WAVERIDER_V2.0`): `cc_dsi1_clk`, `cc_dsi1_pixel_clk`, `cc_dsi1_byte_clk`, `cc_dsi2_*`, `cc_mdp_tv_clk`, `cc_hdmi_tv_clk`.

### ACPI methods

Evaluated on the adapter by `sub_4413F4` (input `ACPI_EVAL_INPUT_BUFFER_COMPLEX`, signature `BoeA` `0x426F6541`), dispatched by `sub_4415BC`:  
| Method | Arguments | Comment |
|--------|-----------|---------|
| `_ROM` | offset, length (≤ 4096 per call) | Panel configuration (read in 4 KB chunks; the copy used by the parsers is at `+0x19EC` / size `+0x19F0` of the context `dword_498EF0`). Parsed by `sub_44BAC8` with the tag list at 0x474F50: `PanelName`, `ManufactureID`, EDID fields, `HorizontalActive`… `VerticalBottomBorder`, `InterfaceType`, `DSI*` (lanes, refresh rate, bit clock, timings, `DSIInitSequence`, `DSITermSequence`…), `Backlight*`, `LVDS*`, `Display1Reset1Info`, `CABL*`, `DynamicEDID*`, `DisplayPrimaryIdlePowerMode`. The driver builds an EDID from these values (`sub_44C14C`, checksum computed over the 127 first bytes). The HDMI part (`HDMIDisable`, `HDMIHDCPEnable`, …) is parsed by `sub_4442EC` |
| `BLCP` | 1 integer | Backlight control ? (256-byte result) |
| `PPCC` | 1 integer | Panel colour correction (PCC) table ? |
| `PGCT` | 1 integer | Gamma correction table ? |
| `PIGC` | 1 integer | Inverse gamma correction table ? |
| `PGRT` | — | ? |
| `PBRT` | — | Brightness table ? Read with a 512-byte buffer by the oempanel service (`sub_44A794` case 7) |
| `PCSC` | — | Colour space conversion ? |

Width / height of the panel can be forced with the `PanelOverride` registry values.

UEFI variable `UEFIDisplayInfo` (vendor `{9042A9DE-23DC-4A38-96FB-7ADED080516A}` = `EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID`, 36 bytes) is read by `sub_441508` (`ExGetFirmwareEnvironmentVariable`): display state left by the UEFI (mode, frame buffer ?), used to take over the boot screen.

### Child devices

`DxgkDdiQueryChildRelations` reports the display outputs and one "other" child for the camera, described by `sub_4AB4A8` (adapter `+0xE4`):  
| Field | Value |
|-------|-------|
| Child UID ? | `0x24321` |
| Device ID | `QCOM_AVStream` |
| Hardware ID | `VEN_QCOM&DEV__AVSTREAM` |
| Compatible ID | `QCOM_AVSTREAM` |
| Description | `Qualcomm Camera AVStream Mini Driver` |

So the camera driver is enumerated as a child of the display adapter.

### Query interfaces

`DxgkDdiQueryInterface` (`sub_4A816C`):  
| GUID | Interface | Function | Comment |
|------|-----------|----------|---------|
| `{FDE5BBA4-B3F9-46FB-BDAA-0728CE3100B4}` | `GUID_DEVINTERFACE_BRIGHTNESS`, version 1, 28 bytes | sub_49E4C4 | Only if the panel has a backlight (adapter `+0x14A4` bit 0). GetPossibleBrightness `sub_49DE00` (list in the ACPI `_BCL` layout: 100, the level closest to 60, then the other levels of the panel; `0xC00000BB` if the last panel level is not 100), SetBrightness `sub_49E07C` (0–100 %), GetBrightness `sub_49DFFC`. Used by [monitor.sys](./monitor.md#brightness) |
| `{148A3C98-0ECD-465A-B634-B05F195F7739}` | `GUID_DEVINTERFACE_BRIGHTNESS_2`, version 2, 44 bytes | sub_49E3C8 | Same + GetBrightnessCaps `sub_49E140`, SetBrightnessState `sub_49E198`, SetBacklightOptimization `sub_49E240`, GetBacklightReduction `sub_49E2EC` |
| `{BF4672DE-6B4E-4BE4-A325-68A91EA49C09}` | OPM interface ?, version 1, 52 bytes | sub_4AD194 | 9 functions: `sub_4ABE7C` (GetCertificateSize ?, loads the OPM keys), `sub_4ABF30`, `sub_4AC188`, `sub_4ABFF8`, `sub_4AC074` (decrypts 256 bytes in TrustZone: SetSigningKeyAndSequenceNumbers ?), `sub_4AC2D8`, `sub_4AC8B8`, `sub_4ACD78`, `sub_4AD05C`. See [OPM](#opm) |
| `{ECBE47A8-C498-4BB9-BD70-E867E0940D22}` | `GUID_THERMAL_COOLING_INTERFACE`, version 1 | sub_4A51B0 | Per engine (`DisableThermalMitigation`). `PassiveCooling` = `sub_4A5264` |
| `{2564AA4F-DDDB-4495-B497-6AD4A84163D7}`, `{496B8280-6F25-11D0-BEAF-08002BE2092F}` (`GUID_BUS_INTERFACE_STANDARD`), `{1A6A460B-194F-455D-B34B-B84C5B05712B}`, `{70211B0E-0AFB-47DB-AFC1-410BF842497A}` (`GUID_PNP_LOCATION_INTERFACE`), `{2AEB0243-6A6E-486B-82FC-D815F6B97006}` (`GUID_D3COLD_SUPPORT_INTERFACE`), `{B38290E5-3CD0-4F9D-9937-F5FE2B44D47A}` (`GUID_REENUMERATE_SELF_INTERFACE_STANDARD`), `{E8695F63-1831-4870-A8CF-9C2F03F9DCB5}` (`GUID_ACPI_INTERFACE_STANDARD2`), null GUID | — | — | Refused with `0xC00000BB` STATUS_NOT_SUPPORTED |
| other | — | sub_4A4818 | ? |

### Escapes

`DxgkDdiEscape` (`sub_4A95C4`), `DXGKARG_ESCAPE`:
* with a context (`hContext`): forwarded to the escape function of the context's engine (engine block `+0x34`, i.e. adapter `+0x1C4` + 0x258 × engine).
* without context: the private data must be ≥ 64 bytes and its dword at `+0x0C` (escape code) must be `0x2xxxxxxx`; handled by `sub_4B682C`:

| Code | Size | Comment |
|------|------|---------|
| 0x20000000, 0x20000001 | ≥ 64 | Accepted but nothing done: result `1` |
| 0x20000100 | 1544 | Calls `sub_4019A0`, an empty stub: result `0` |
| other | | Result `1` |

The result is written in the dword at `+0x14` of the private data (0 = success, 1 = invalid parameter, 2 = failure); the escape itself always returns `STATUS_SUCCESS`.

### Panel driver interface

At display init (`sub_446970`), the "OEM extension" layer (`sub_44A6EC` init, `sub_44A794` control) registers with [oempanel.sys](./oempanel.md) by sending it [IOCTL 0x4000](#ioctl-0x4000--panel-driver-registration). The 32-byte input buffer is this table of qcdxkm8930 functions (built by `sub_44A794` case 0); oempanel stores it at its device context `+0x94`:  
| Offset | Function | Comment |
|--------|----------|---------|
| 00 | sub_44AD38 | `Register(display < 8, context, table)`: stores oempanel's context and the 6 callbacks `table[1..6]` (oempanel table version `0x02010005`). PASSIVE_LEVEL only |
| 04 | sub_44ADB4 | `(display, a2, buffer, a3)`: sends a command sequence to the panel through the display's panel function (`+0x5C` of the per-display block); `sub_4373A0(display, 2)` / `(display, 1)` around the call (resource vote ?) |
| 08 | sub_44AE40 | Same with 7 arguments and two output pointers: panel read ? (block `+0x60`) |
| 0C | sub_44AEE8 | Panel status ? (block `+0x64`) |
| 10 | sub_44AF38 | `(1, out)`: copies 80 bytes of display information (`dword_498F00`: `[0]` = 6, then width ?, height ?, …) |
| 14 | sub_44AF7C | ? |
| 18 | sub_44B2C0 | `(display, t1, t2, t3)`: colour tables of 272, 776 and 3080 bytes (`sub_43CDDC`, `sub_43CC9C`, `sub_43CBCC`). PCC / gamma LUTs ? |
| 1C | sub_44B3D4 | `(1, flags)`: if bit 0 is set, `sub_435950(1, 1, mode)` with the mode of `dword_48C7A8` |

After the registration, `sub_44A794` calls a callback of each registered display (types 1 and 4) to get its configuration.

### OPM

Output Protection Manager keys (`sub_4AD870`, called by the first function of the OPM interface):
1. `IoGetDeviceProperty(DevicePropertyPhysicalDeviceObjectName)` of the adapter, used by the DPP library.
2. Reads `OPM_PUB.PROVISION` (certificate, kept at adapter `+0x17A0`, size `+0x17A4`) and `OPM_PRIV.PROVISION` (private key) from `C:\DPP\QCOM\` (`sub_42EBC4` size, `sub_42EE48` read).
3. Sends the private key to the trustlet (`sub_4AD6E8`, request `0x20002`) and frees it: the private key does not stay in the kernel memory.
4. State `2` at adapter `+0x179C`.

The trustlet then decrypts the 256-byte (RSA-2048) blocks of the OPM protocol (`sub_4ADC34`, request `0x20003`).

---

### IOCTL 0x4000 — panel driver registration

This IOCTL is sent by Qcdxkm8930.sys to [oempanel.sys](./oempanel.md#ioctl-0x83214000--display-driver-registration)

| Property | Value |
|----------|-------|
| Device | 0x0 |
| Function | 0x0 (0) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ? | First interface `{0D4A3F63-0D08-49A1-B91C-C60576894174}` | 32 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-1F | 8 kernel function pointers | See [Panel driver interface](#panel-driver-interface) |

Sent by `sub_4417F0` (PASSIVE_LEVEL only): `IoGetDeviceInterfaces`, `IoGetDeviceObjectPointer` (GENERIC_WRITE), `IoBuildDeviceIoControlRequest` (not internal), wait 100 ms at most. oempanel accepts this code as well as `0x83214000`. The file object returned by `IoGetDeviceObjectPointer` is never dereferenced.

---

### IOCTL 0x8C1F2014 / 0x8C1F2008 / 0x8C1F2004

These IOCTLs are sent by Qcdxkm8930.sys to [qcchipinfo8930.sys](./qcchipinfo8930.md#ioctl-0x8c1f2014)

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x805 / 0x802 / 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Chip family / chip id / chip version | interface `{FB4F07CD-8D4C-4413-92C2-E2C9CAED9F43}` | 0 | 4 |

Sent by `sub_4ABC5C` (from `sub_4AA808`, at start): registers a PnP notification on the interface (`sub_403618`, `sub_403710`), waits up to 500 ms for its arrival, opens it, then sends the three IOCTLs (`sub_403748`). The results are stored at adapter `+0x17CC` (family), `+0x17D0` (id), `+0x17D4` (version) and given to the display component.

---

### internal IOCTL 0xC3514004 — OPM keys in TrustZone

This IOCTL is sent by Qcdxkm8930.sys to [qcscm8930.sys](./qcscm8930.md#internal-ioctl-0xc3514004--ioctl_internal_scm_control_class_syscall)

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x1 (1) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_SCM_CONTROL_CLASS_SYSCALL | interface `{41C66D2A-A9F1-40CA-A329-AE096C03EE68}` | 96, 52 + n or 321 | same as InputBuffer (same buffer) |

The interface is watched with a PnP notification (`sub_4AD348`, at start). Three requests (`tzbsp_syscall_req_t` header, see qcscm8930):

#### QSEE application lookup (`sub_4AD4D8`)

96-byte buffer, done once (application ID cached at adapter `+0x17AC`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 40 00 00 00 | `len` |
| 04-07 | 10 00 00 00 | `command_start_off` |
| 08-0B | 20 00 00 00 | `response_write_off` |
| 0C-0F | 01 F0 03 00 | `command_id` 0x3F001 |
| 10-13 | 03 FF 00 00 | Sub-command 0xFF03 |
| 14-17 | | Physical address of the name `qcom.tz.winsecapp` (in a page allocated with `MmAllocatePagesForMdlEx`) |
| 18-1B | 00 00 00 00 | |
| 1C-1F | 0C 00 00 00 | ? |
| 20-23 | 20 00 00 00 | Size of the name buffer ? |
| 24-27 | 0C 00 00 00 | ? |
| 2C-2F | 01 00 00 00 | Must be 0 after the call (status ?) |
| 30-33 | | Must be `0xEE01` after the call |
| 34-37 | | Physical address of the result (name + 0x20) |
| 3C-3F | 10 00 00 00 | ? |

The application ID is read at name + 0x20.

#### Request 0x20002: import the OPM private key (`sub_4AD6E8`)

52 + n bytes (n = size of `OPM_PRIV.PROVISION`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 52 + n | `len` |
| 04-07 | 10 00 00 00 | `command_start_off` |
| 08-0B | 36 + n | `response_write_off` |
| 0C-0F | 01 F4 03 00 | `command_id` 0x3F401 (send to trustlet) |
| 10-13 | | Application ID |
| 14-17 | 02 00 02 00 | Request code 0x20002 |
| 18-1B | 16 + n | Request length |
| 1C-1F | 10 00 00 00 | ? |
| 20-23 | n | Key size |
| 24-.. | | Content of `OPM_PRIV.PROVISION` |
| response +08 | AA AA 00 00 → 01 00 00 00 | Status (must be 1) |
| response +0C | 55 55 00 00 → 00 00 00 00 | Result (must be 0) |

#### Request 0x20003: RSA decryption (`sub_4ADC34`)

321-byte buffer: `command_id` 0x3F401, request code `0x20003`, `+0x18` = 285, `+0x1C` = 29, `+0x20` = 256, `+0x24` = `02 00 05 00`, `+0x28` = 28, `+0x2C` = 1, 256 bytes of data at `+0x31`, response at `+0x131` (status = 1, result = 0). The 256 bytes are replaced in place by the decrypted data, which is copied to a new buffer for the caller (`sub_4AC074`).

---

### internal IOCTL 0x230047 — IOCTL_VIDEO_DDI_FUNC_REGISTER

This IOCTL is sent by Qcdxkm8930.sys to dxgkrnl.sys (`\Device\DxgKrnl`)

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x11 (17) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_VIDEO_DDI_FUNC_REGISTER | `\Device\DxgKrnl` | 0 | 4 |

Internal IOCTL sent by `DxgkInitialize` (displib, `sub_451754` → `sub_4BEB24`) when the OS version is > 6.1. If dxgkrnl answers `0xC0000010` STATUS_INVALID_DEVICE_REQUEST, or on Windows ≤ 6.1, the old code `0x23003F` (function 0xF) is used. The output is the address of the dxgkrnl initialization function, which is then called with the `DRIVER_INITIALIZATION_DATA`.

---

### Interface GUID

The driver creates no device interface itself (the display adapter interfaces belong to dxgkrnl).

### Other GUID

Main ETW provider  
`{BE491BBA-E5B9-4EC1-BBC3-D439DEB7DF48}`

Video engine (VED) ETW provider  
`{310A912A-008E-4148-BB92-3DB5037B8CA5}`

oempanel interface (target of IOCTL 0x4000)  
`{0D4A3F63-0D08-49A1-B91C-C60576894174}`

qcchipinfo8930 interface  
`{FB4F07CD-8D4C-4413-92C2-E2C9CAED9F43}`

qcscm8930 interface (GUID_SCM_DEVINTERFACE)  
`{41C66D2A-A9F1-40CA-A329-AE096C03EE68}`

`GUID_DEVINTERFACE_BRIGHTNESS` / `GUID_DEVINTERFACE_BRIGHTNESS_2` (query interfaces)  
`{FDE5BBA4-B3F9-46FB-BDAA-0728CE3100B4}`  
`{148A3C98-0ECD-465A-B634-B05F195F7739}`

OPM query interface ?  
`{BF4672DE-6B4E-4BE4-A325-68A91EA49C09}`

`GUID_THERMAL_COOLING_INTERFACE`  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`

Registry value name in `DxKMD\Miniport` (power configuration ?)  
`{9572E219-4CA5-421A-A1EB-967BCA3042D6}`

PEP power control code "change P-state", sent by `sub_4A2E68` through `DxgkCbPowerRuntimeControlRequest` (adapter `+0x74`). 16-byte input: component index, P-state (clamped to the component's limits), signature `MPPR` (`0x5250504D`), event pointer or 0. 12-byte output: if the dword at `00` is not 3 (`PEP_STATE_SYNC_PATH` ?), the driver waits up to 1 s for the event. Same code as the `PoFxPowerControl` of [qcwcn8930.sys](./qcwcn8930.md#power-management)  
`{3404DAAC-8E2C-41E4-8458-3158E5AD442B}`

`EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID` (vendor of the UEFI variable `UEFIDisplayInfo`)  
`{9042A9DE-23DC-4A38-96FB-7ADED080516A}`
