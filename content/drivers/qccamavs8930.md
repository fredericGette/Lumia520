## Qccamavs8930.sys

Qualcomm Camera AVStream Mini Driver.  
It's the camera driver of the phone: a KS/AVStream minidriver (`ks.sys`) that exposes one capture filter per camera sensor ("Back Sensor", "Front Sensor") and contains the whole Qualcomm camera stack in kernel mode: the ISP / VFE service, the 3A algorithms ("ELFS": AEC, AWB, AF, ASD, AFD, DIS, HJR, luma adaptation), the chromatix tuning data, the multipass snapshot (dark frame, ideal raw, BM3D) and the Nokia additions (`NokiaElfsPlugIn`, `NokiaMultiframeLogic`, Nokia custom properties, camera diagnostics).  
The device is a child of the display adapter: it's enumerated by [qcdxkm8930.sys](./qcdxkm8930.md#child-devices) (`VEN_QCOM&DEV__AVSTREAM`, ACPI node `\_SB.GPU0.AVS0`), and it gets the DirectX allocations of the adapter through a query interface. The camera sensors, the flash and the VFE are separate drivers reached through device interfaces, the post-processing engine (VPE) and the Nokia "ESP" driver too. The SMMU mappings go through qcvcm8930.sys (direct imports `VcmCreate`, `VcmReserve`, `VcmBack`, `VcmMapMdlToPhysmem`, `VcmGetDevAddr`, …).  
The camera code base is shared with other Nokia phones: the back filter class is `CaptureFilter13MP` and the front filter class is `CaptureFilter_MT9M114_720P_YUV` (Aptina MT9M114). The Lumia 520 has no front camera, so only the back filter is expected to be created.  
PDB path: `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\Driver\fre\qccamavs8930.pdb`.

There's no named device object and no symbolic link: the filters are reached through their KS device interfaces (see [Filters](#filters)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qccamavs`  

The driver doesn't use its `Parameters` key. All the values are read with `ZwOpenKey` + `ZwQueryValueKey` (helper `sub_41960C`, raw data copied to the destination, max 256 bytes) from absolute paths:  
| Registry key | Registry value | value | comment |
|--------------|----------------|-------|---------|
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | TraceEnable | ? | Must be 1 to register the ETW provider (`sub_419AE0`) |
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | CoreDbgEnable | ? | Read at ISP creation (`sub_41A978`) into `byte_5F5830`: when set, the messages of the camera core (`sub_425638`, "(%s) - %s") are formatted even at DISPATCH_LEVEL and written as ETW events |
| `HKLM\Software\Microsoft\ManufacturingOS` | ManufacturingMode | ? | 1 = MMOS. Required by the diagnostic methods ("MMOS is not enabled!" → `STATUS_NOT_SUPPORTED` 0xC00000BB). When it's 1, the multipass snapshot is disabled ("Disabled Multipass for PT") |
| `HKLM\Software\Qualcomm\Camera\` | DumpFramesMask | ? | Read in `CaptureFilter::AcquireFilterResources` (`sub_407C80`), filter `+0x98`. Frame dump mask (debug) ? |
| `HKLM\Software\OEM\Nokia\Camera` | ExifModelName | ? | Model name for the EXIF data (`NokiaElfsPlugIn`, `sub_473C88`). Fallback: `PhoneModelName` |
| `HKLM\SYSTEM\Platform\DeviceTargetingInfo` | PhoneModelName | ? | Fallback of `ExifModelName` |

Capabilities of the back camera (`HKLM\Software\OEM\Nokia\Camera\RFC\…`, `sub_5FE578`) and of the front camera (`…\FFC\…`, `sub_60E4B0`), stored in the filter (`+0x580`…):  
| Registry key | Registry value | Default RFC | Default FFC | comment |
|--------------|----------------|-------------|-------------|---------|
| `…\Resolution` | StillResolution | — | — | No default |
| `…\Resolution` | VideoResolution | — | — | No default |
| `…\Resolution` | PreviewResolution | — | — | No default |
| `…\Caps` | MinIso | 100 | 100 | |
| `…\Caps` | MaxIso | 1600 | 800 | |
| `…\Caps` | MinET | 60 | 60 | Minimum exposure time (µs) |
| `…\Caps` | MaxET | 1000000 | 133000 | Maximum exposure time (µs) |
| `…\Caps` | FlashModes | 59 (0x3B) | — | Bit mask. Not read for the FFC |
| `…\Caps` | VideoLightModes | 2 | — | Not read for the FFC |
| `…\Caps` | MaxDigiZoom | 0x40000 (4.0 in 16.16) | — | Not read for the FFC |

GUID of the ETW provider (manifest based, only registered when `TraceEnable` = 1):  
`{e0141511-4523-463e-9709-b1a6fadbcbfb}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Parent PDO (display adapter) | [qcdxkm8930.sys](./qcdxkm8930.md#query-interfaces) | `IRP_MN_QUERY_INTERFACE` `{93042446-d274-44f5-a8cb-2a28263b6a48}`, see [DirectX allocations](#directx-allocations) |
| Interface `{d2ff3f74-880f-4858-841c-fb0bc634676c}` | [qccamflash8930.sys](./qccamflash8930.md) | Flash. [Camera device internal IOCTLs](#internal-ioctl-0x2323ff0x232653--camera-device-control), commands listed in [flash control](./qccamflash8930.md#internal-ioctl-0x2323ff0x232467--flash-control) |
| Interface `{5e34e1c5-c5bc-4c7f-b6fc-e2443e45be67}` | [qccamsensor8930.sys](./qccamsensor8930.md) | Back camera sensor (`\_SB.CAMS`). Commands listed in [sensor control](./qccamsensor8930.md#internal-ioctl-0x2323ff0x232523--sensor-control) |
| Interface `{f27170b8-7b88-4f4a-b505-1d065616aadc}` | [qccamfrontsensor8930.sys](./qccamfrontsensor8930.md) | Front camera sensor. Same IOCTLs and commands as the back sensor (same code base), listed in [sensor control](./qccamfrontsensor8930.md#internal-ioctl-0x2323ff0x232523--sensor-control) |
| Interface `{3e9c0fdb-cef9-4c4a-8e85-36e4a82eb80f}` | [qccamvfe8930.sys](./qccamvfe8930.md) | VFE (Video Front End: ISP) driver. Same IOCTLs, commands listed in [VFE commands](./qccamvfe8930.md#vfe-commands) |
| Interface `{95f66217-6158-4f46-a8c6-dfd0bfcf94f1}` | ? | VPE (Video Pre-processing Engine: scaling, crop, rotation). See [VPE IOCTLs](#ioctl-0x900-0x950-0x9a0--vpe) |
| Interface `{e5fde9d7-7a0e-4048-81bb-a77caf7b349f}` | ? | Nokia "ESP" driver. See [ESP IOCTLs](#ioctl-0x222410-0x222414-0x222424--esp) |
| — | qcvcm8930.sys | SMMU, by direct imports |
| — | ks.sys | AVStream class driver |

The ACPI node `\_SB.GPU0.AVS0` declares `_DEP` on `\_SB.VPE` and `\_SB.VFE0` (see [qcdxkm8930.sys](./qcdxkm8930.md)). The flash interface is exposed by [qccamflash8930.sys](./qccamflash8930.md) and the sensor interfaces by [qccamsensor8930.sys](./qccamsensor8930.md) (back) and [qccamfrontsensor8930.sys](./qccamfrontsensor8930.md) (front), and the VFE interface by [qccamvfe8930.sys](./qccamvfe8930.md); the VPE and ESP drivers are not identified yet.

### Driver initialisation

`DriverEntry` (`FxDriverEntry` 0x621044 → `FxDriverEntryWorker` 0x418310) only calls `KsInitializeDriver(DriverObject, RegistryPath, &DeviceDescriptor)` with the descriptor at `.rdata:0x53BC10`. There's no static filter descriptor: the filter factories are created at run time.  
`KSDEVICE_DISPATCH` (`.rdata:0x53BBD8`):  
| Callback | Function | Comment |
|----------|----------|---------|
| Add | sub_5FE008 | Allocates the `CaptureDevice` object (0x218 bytes, tag `KCNw`), `sub_617E68` + `sub_618008` |
| Start | sub_5FE11C | `CaptureDevice::OnPnpStartDevice` → `sub_617F18` |
| Stop | sub_5FE1C4 | `CaptureDevice::OnPnpStopDevice` → `sub_617F84` |
| others | 0 | Not handled |

At start, the device:
1. Attaches to the DirectX miniport (`CaptureDevice::AttachToDxMiniportDriver`, `sub_4063AC`), see [DirectX allocations](#directx-allocations).
2. Registers 2 PnP notifications (`EventCategoryDeviceInterfaceChange`, `CaptureDevice::RegisterSensorInterfaceChange` `sub_418B6C`, callback `sub_418A3C`):
   - arrival of `{5e34e1c5-…}` → `CaptureDevice::RegisterBackSensor` (`sub_4185CC`),
   - arrival of `{f27170b8-…}` → `CaptureDevice::RegisterFrontSensor` (`sub_418838`),
   - removal → `STATUS_NOT_IMPLEMENTED` (0xC0000002), other events → `STATUS_NOT_SUPPORTED`.
3. `RegisterBackSensor` / `RegisterFrontSensor` run the sensor detection of the camera core (`sub_422CA0`); if at least one sensor is detected, they create the filter factory (`KsCreateFilterFactory`, reference string `Back Sensor` / `Front Sensor`, flags `KSCREATE_ITEM_FREEONSTOP` (8)) and set a property of its device interface (`IoSetDeviceInterfacePropertyData`, see [Filters](#filters)). No sensor detected → `STATUS_UNSUCCESSFUL`.

### Filters

| Property | Back filter | Front filter |
|----------|-------------|--------------|
| `KSFILTER_DESCRIPTOR` | `.rdata:0x529D98` | `.rdata:0x529DF0` |
| Reference string | `Back Sensor` | `Front Sensor` |
| Class | `CaptureFilter13MP` | `CaptureFilter_MT9M114_720P_YUV` |
| Create / Close | sub_5FE248 / sub_5FE374 | sub_60E1C8 / sub_60E2F4 |
| Registry capabilities | `RFC` | `FFC` |
| Interface property data | `5e 0f 9a 9d e9 cd f5 49 b4 64 bf 13 42 9d de b5` | `4e 3c d5 75 3e 96 15 44 aa 88 89 10 7f 08 d1 ee` |

Reference GUID: `KSNAME_Filter` `{9b365890-165f-11d0-a195-0020afd156e4}`.  
Categories (both filters):  
| GUID | Category |
|------|----------|
| `{e5323777-f976-4f5b-9b55-b94699c46e44}` | `KSCATEGORY_VIDEO_CAMERA` |
| `{6994ad05-93ef-11d0-a3cc-00a0c9223196}` | `KSCATEGORY_VIDEO` |
| `{65e8773d-8f56-11d0-a3b9-00a0c9223196}` | `KSCATEGORY_CAPTURE` |

The interface property is set with the key `{540b947e-8b40-45bc-a8a2-6a0b894cbda2}`, 9 (`DEVPKEY_Device_PhysicalDeviceLocation` ?), type `DEVPROP_TYPE_BINARY` (0x1003), 16 bytes, persistent. The 16 bytes look like a GUID (`{9d9a0f5e-cde9-49f5-b464-bf13429ddeb5}` back, `{75d53c4e-963e-4415-aa88-89107f08d1ee}` front) rather than an ACPI `_PLD` buffer: panel identifier for the camera application ?

The descriptors have no static pin: the pins are created by the filter (`KsFilterCreatePinFactory`, `CreateImagePinFactory`, `CreateVideoCapturePinFactory`, `CreateVideoPreviewPinFactory`). Pin names: `Preview`, `Video`, `Still`, `Streaming Still`. The video capture pin has 3 variants: `NORMAL`, `HFR` (high frame rate) and `DIS` (digital image stabilisation). FourCCs found in the format tables: `NV12`, `NV21`, `YUY2`, `UYVY`, `YVYU`, `JPG`/`IJPG`/`FJPG`, `META`, and the raw Bayer formats `MIPI`, `QCOM`, `PL16`, `BA81`, `DPCM`.

#### Automation table

Filter automation table (`.rdata:0x529D2C`): 6 property sets, 2 method sets, 1 event set. All the property handlers are thunks to `CaptureFilter::PropertyAccessor` (`sub_409814`), except the 3 storyboard properties (`CaptureFilter::StoryBoardHandler` `sub_409BBC`) and the set `{2ed26bd2-…}` (`CameraDiagnostics::ControlCamera` `sub_4025A0`).  
| Set | Name | Ids (min property size / min data size) | Comment |
|-----|------|------------------------------------------|---------|
| `{b1052cd6-782a-48d9-bc03-400122266c1d}` | ? | 1–10 (24 / 4), except 3 (20 bytes), 6 (104), 8 (130), 10 (665604) | Custom. Id 10 has a 665604-byte buffer (0xA2804) |
| `{6a2e0670-28e4-11d0-a18c-00a0c9118956}` | `KSPROPSETID_Topology` | 3 `KSPROPERTY_TOPOLOGY_NAME` (24 / 32) | |
| `{c6e13360-30ac-11d0-a18c-00a0c9118956}` | `PROPSETID_VIDCAP_VIDEOPROCAMP` | 0 brightness, 1 contrast, 2 hue, 3 saturation, 4 sharpness (40 / 40) | |
| `{c6e13370-30ac-11d0-a18c-00a0c9118956}` | `PROPSETID_VIDCAP_CAMERACONTROL` | 1000–1028, 1030 (40 / 40; 1004: 72; 1024: 32; 1025: 176; 1028: 48) | Windows Phone extended camera controls (ids ≥ 1000). 1025–1028 = storyboard |
| `{2ed26bd2-811f-42e8-a81a-9199ace19d36}` | Camera diagnostics properties | 0–7, 9 (24 / 4 or 8) | `KSPROPERTY_CAMERA_DIAGNOSTIC_*` (`QUERY_SUPPORT`, `EXPOSURE_TIME`, `GAIN_AND_EXPOSURE`, `FOCUS_STATE`, `SHUTTER_STATE`, `OIS_MODE`, `BAYER_ORDER`) ?. MMOS only |
| `{80efc5a3-b993-4ae0-9fe3-393632a63750}` | Nokia custom properties ? | 0–24, 50–52, 100–105 (40 / 40) | `KSPROPERTY_NOKIA_CAMERACONTROL_*` (e.g. `MAX_EXPOSURE_TIME_PREVIEW`, `MAX_ISO_PREVIEW`), multiframe / `KeepStillStreaming` properties of `NokiaMultiframeLogic` ? |

| Method set | Handler | Ids | Comment |
|------------|---------|-----|---------|
| `{b8b55345-7a49-4dae-aecc-85bd5fd4853a}` | `CameraDiagnostics::PerformSelftest` (`sub_401ABC`) | 0, 2–9 (16 bytes) | Self tests: `KSMETHOD_CAMERA_SENSOR_IF_TEST`, `CAMERA_NVM_TEST`, `CAMERA_OIS_TEST`, `FLASH_IF_TEST`, `FLASH_LEDS_TEST`, `FLASH_STROBE_TEST`, `FLASH_TORCH_TEST`, `FLASH_POWER_LIMIT_TEST`, `RGBC_IF_TEST` ?. MMOS only |
| same | `CameraDiagnostics::DeviceInformation` (`sub_4020E4`) | 100 (32), 101 (4), 102 (12) | `KSMETHOD_CAMERA_INFORMATION`, `KSMETHOD_FLASH_INFORMATION`, `KSMETHOD_CDCC_DATA`. MMOS only |
| `{c8c0e115-5689-44b8-84df-861fa91f11e6}` | `ExecuteDriverUnitTest` (`sub_40DD54`) | 0 (4) | `KSMETHOD_EXECUTE_DRIVER_UNIT_TEST`. Writes `\??\C:\Data\Test\bin\CamDrvUnitTestLog.txt` |

| Event set | Ids | Comment |
|-----------|-----|---------|
| `{22a11754-9701-4088-b33f-6b9cbc52df5e}` | 0, 3, 4, 7 | Camera control events, e.g. `KSEVENT_CAMERACONTROL_FOCUS_COMPLETE` |

### Camera device manager

`CameraDeviceManager.c` keeps a table of up to 12 camera devices (`dword_5EC038`, 36 bytes per entry, count `dword_5EC1E8`), initialised from the static table at `.rdata:0x52BE80`:  
| Device ID | Type | Interface GUID | Device |
|-----------|------|----------------|--------|
| 0x0106C427 | 1 | `{d2ff3f74-880f-4858-841c-fb0bc634676c}` | Flash ([qccamflash8930.sys](./qccamflash8930.md)) |
| 0x5E34E1C5 | 2 | `{5e34e1c5-c5bc-4c7f-b6fc-e2443e45be67}` | Back sensor (`m_SensorId`, [qccamsensor8930.sys](./qccamsensor8930.md)) |
| 0xF27170B8 | 2 | `{f27170b8-7b88-4f4a-b505-1d065616aadc}` | Front sensor (`m_SensorId`, [qccamfrontsensor8930.sys](./qccamfrontsensor8930.md)) |
| 0x01091E5B | 3 | `{3e9c0fdb-cef9-4c4a-8e85-36e4a82eb80f}` | VFE (`VFEService.cpp`, "VFE driver loaded", [qccamvfe8930.sys](./qccamvfe8930.md)) |

A device is opened on its first use (`sub_419F80`): first instance returned by `IoGetDeviceInterfaces`, then `IoGetDeviceObjectPointer(GENERIC_ALL)`; failure → "CameraDeviceManager cannot retrieve KMDF driver pointer.". All the requests to these devices are internal IOCTLs built by `sub_41A0D0`.

---

### internal IOCTL 0x2323FF…0x232653 — camera device control

These IOCTLs are sent by Qccamavs8930.sys to the flash, sensor and VFE drivers (see [Camera device manager](#camera-device-manager)). The commands are listed in [flash control](./qccamflash8930.md#internal-ioctl-0x2323ff0x232467--flash-control) and [sensor control](./qccamsensor8930.md#internal-ioctl-0x2323ff0x232523--sensor-control): for the sensor, `n` is the same number, e.g. 0 = power on, 2 = start stream, 23 = get sensor modes, 54 = SetAECResults.

The code is computed from a control number `n`: `((0x8FF + n) << 2) | 0x230003`. `n` goes from 0 (0x2323FF) to at least 0x95 (0x232653); about 100 different values are used by the sensor, flash and VFE services. The special value 0x232003 (function 0x800) is passed as is (`sub_44296C`, VFE service): it registers the event of the VFE message queue, see [qccamvfe8930.sys](./qccamvfe8930.md#internal-ioctl-0x232003--register-message-event). The VFE commands are listed in [VFE commands](./qccamvfe8930.md#vfe-commands).

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x8FF + n (0x800 for 0x232003) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Camera device control `n` | Flash / sensor / VFE interface | variable | 16 |

Inputbuffer (`Type3InputBuffer`): the request structure of control `n`, passed as is.

Outputbuffer (`Irp->UserBuffer`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the response buffer |
| 04-07 | ? | Size of the response buffer |
| 08-0B | ? | Pointer to a ULONG receiving the size of the response (confirmed by [qccamflash8930.sys](./qccamflash8930.md#internal-ioctl-0x2323ff0x232467--flash-control)) |
| 0C-0F | 01 00 00 00 | Camera result, set to 1 (failure) before the call and updated by the target. 0 = success |

The request is synchronous (`KeWaitForSingleObject` on the device's event). If the IRP fails, the result is 1 ("IoCallDriver failed, NTStatus result = %d."). No device handle → 13, no device → 44.

---

### IOCTL 0x900, 0x950, 0x9A0 — VPE

These IOCTLs are sent by Qccamavs8930.sys to the VPE driver (interface `{95f66217-6158-4f46-a8c6-dfd0bfcf94f1}`, `VpeSession`, `sub_60EAD0`).

| IOCTL | Device | Function | Access | Method |
|-------|--------|----------|--------|--------|
| 0x900 | 0x0 | 0x240 | FILE_ANY_ACCESS | METHOD_BUFFERED |
| 0x950 | 0x0 | 0x254 | FILE_ANY_ACCESS | METHOD_BUFFERED |
| 0x9A0 | 0x0 | 0x268 | FILE_ANY_ACCESS | METHOD_BUFFERED |

They are sent by `VpeSession::IoControlCore` (`sub_60E9C4`) as normal (not internal) IOCTLs, with the file object of the VPE device in the IRP stack. **The call is retried in an endless loop** while it fails with a status other than `STATUS_UNSUCCESSFUL` (0xC0000001).  
The input buffer starts with a KS-like header (`KSIDENTIFIER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | GUID | Command set |
| 10-13 | ? | Command Id |
| 14-17 | ? | Flags (usually 2) |
| 18-… | ? | Parameters |

| IOCTL | Set | Id | InputBuffer size | OutputBuffer Size | Function |
|-------|-----|----|------------------|-------------------|----------|
| 0x9A0 | `{c8a7f717-a0fe-4bf4-b44e-0a27e9fa9562}` | 1 | 24 | 48 | Get message (`VpeSession::WorkerThreadProc`, `sub_60E624`): blocks until the VPE sends a message (input buffer done, output buffer done, buffers flushed, `VPE_MSG_RESP_STOP_DONE`, …) |
| 0x9A0 | same | 3 | 24 | 0 | Start (`StartCore`, `sub_60ECB8`) |
| 0x9A0 | same | 4 | 24 | 0 | Stop (`StopCore`, `sub_60EF10`) |
| 0x9A0 | same | 7 | 28 | 0 | Flush (`FlushCore`, `sub_60F0B4`) |
| 0x9A0 | same | 10 | 56 | 0 | Process frame (`ProcessFrame`, `sub_60F604`) |
| 0x900 | `{fcd1c5aa-85b7-45e7-9426-d6c31ee30130}` | 1 | 36 | 4 | Reserve allocation (`sub_60F1C0`) |
| 0x900 | same | 3 | 36 | 0 | Unreserve allocation (`sub_60F2D8`) |
| 0x900 | same | 2 | 44 | 0 | Map allocation (`sub_60F3D0`) |
| 0x900 | same | 4 | 44 | 0 | Unmap allocation (`sub_60F4E8`) |
| 0x900 | same | 6 | 56 | 0 | Provide buffer (`sub_60F714`, from `CapturePin::EnqueueBufferToVFE` / `VPEInputBufferDone`) |
| 0x950 | `{7307682b-adfe-40fa-b37d-be330a37d488}` | ? | 116 | 0 | Init session (`InitSession`, `sub_60F7F0`): formats `NV12` / `NV21` … |
| 0x950 | same | ? | 44 | 0 | Set zoom (`sub_60F9CC`) |
| 0x950 | same | 7 | 44 | 0 | Set crop (`sub_60FAEC`) |
| 0x950 | same | 6 | 28 | 0 | Set rotation (`sub_60FC00`) |

---

### IOCTL 0x222410, 0x222414, 0x222424 — ESP

These IOCTLs are sent by Qccamavs8930.sys (`NokiaElfsPlugIn`, `CameraESPDriverInterface.cpp`) to the Nokia ESP driver (interface `{e5fde9d7-7a0e-4048-81bb-a77caf7b349f}`, `sub_473F30`, `sub_473FFC`). Normal IOCTLs, no input buffer. If the ESP driver isn't found ("Cannot find ESP driver"), the plug-in continues without it.

| IOCTL | Device | Function | Access | Method | OutputBuffer Size | Function |
|-------|--------|----------|--------|--------|-------------------|----------|
| 0x222410 | 0x22 | 0x904 | FILE_ANY_ACCESS | METHOD_BUFFERED | 0 | Camera power ON notification (`NokiaElfsPlugIn: Init`, `sub_46E294`) |
| 0x222414 | 0x22 | 0x905 | FILE_ANY_ACCESS | METHOD_BUFFERED | 0 | Camera power OFF notification (`DestroyInstance`, `sub_46E100`) |
| 0x222424 | 0x22 | 0x909 | FILE_ANY_ACCESS | METHOD_BUFFERED | 20 | Read sensor data, in `RunNokiaComponents` / `RunViewFinderStats` (`sub_471FCC`) |

Outputbuffer of 0x222424:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | ≠ 0: data valid (plug-in `+0x18C`) |
| 04-0F | ? | 3 values stored in the plug-in (`+0x190`, `+0x194`, `+0x198`) |
| 10-13 | ? | Passed to the camera core (vtable `+0x454`). Light / RGBC measurement for the AWB ? |

---

### internal IOCTL 0x23200F — Mobicat register access

This IOCTL would be sent by Qccamavs8930.sys (`sub_4259DC`) for the `SetRegs` / `GetRegs` commands of the QMobiCaT tuning protocol (`sub_426E38`, `sub_426F98`: sensor register access over I2C).

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

The target device pointer (`dword_5F583C`) is **never written** in the binary: `sub_4259DC` always returns `STATUS_UNSUCCESSFUL` (0xC0000001). At DISPATCH_LEVEL it would have used an asynchronous `IRP_MJ_DEVICE_CONTROL` instead. QMobiCaT also needs to be enabled ("Mobicat is not Enabled"). On the flash side, 0x23200F is the I2C write IOCTL of the camera platform driver (interface `{8d73ce35-93cf-4795-8db9-40bbe130d859}`), see [qccamflash8930.sys](./qccamflash8930.md#internal-ioctl-0x2320030x23201f--camera-platform).

---

### DirectX allocations

`CaptureDevice::AttachToDxMiniportDriver` (`sub_4063AC`) sends `IRP_MN_QUERY_INTERFACE` to the parent ([qcdxkm8930.sys](./qcdxkm8930.md#query-interfaces), handled by `sub_4A4818`):  
| Field | Value |
|-------|-------|
| InterfaceType | `{93042446-d274-44f5-a8cb-2a28263b6a48}` |
| Size | 116 |
| Version | 0x100 |

The buffer (pool tag `qcab`) is filled by Qccamavs8930.sys with 4 callbacks before the call, then copied into the device object:  
| Offset | Function | Callback |
|--------|----------|----------|
| 0x54 | sub_406260 | `CaptureDevice::OnReserveDxAllocation` |
| 0x58 | sub_40635C | `CaptureDevice::OnUnreserveDxAllocation` |
| 0x5C | sub_4062B4 | `CaptureDevice::OnMapDxAllocation` |
| 0x60 | sub_406308 | `CaptureDevice::OnUnmapDxAllocation` |

So the display driver can ask the camera driver to map a DirectX allocation into the camera SMMU context (`MapDxAllocation`: "VCM device address (%#Ix) is now committed", qcvcm8930) and get it back with `ScbDxmGetStoredHandle` (`MapDxAllocationToAvsAllocation`): zero-copy buffers between the camera and the GPU/display.

### Files

| File | Access | Comment |
|------|--------|---------|
| `\DosDevices\C:\Windows\System32\Drivers\dfsmap.bin` | read / write (`sub_477974`, `sub_477C74`) | Nokia NIPS data store ? Keys like `CameraSensor.NVM`, `FlashSensor.DFC`, `FlashSensor.DFC.Date`, `FlashSensor.NVM`, `CameraSensor.Driver.Version`, `CameraSensor.Module.Version`, `NIPS3A.Generic` |
| `\DosDevices\C:\Data\Users\Public\Pictures\Camera Roll\` | write | Raw frame dumps (`NokiaElfsPlugIn::DumpRawFrame`, `sub_474180`) |
| `\??\C:\Data\Test\bin\CamDrvUnitTestLog.txt` | write | Log of `KSMETHOD_EXECUTE_DRIVER_UNIT_TEST` (`sub_41179C`) |

The sensor tuning (chromatix) and the module data (NVM, DCC/CDCC, flash DFC) are read from the sensor and flash drivers through the camera device control IOCTLs, not from files. The flash driver itself reads the flash DFC from `C:\DPP\Nokia\DFC\<id>.dfc` (or `C:\Windows\System32\<id>.dfc`), see [qccamflash8930.sys](./qccamflash8930.md#dfc-files).

### Interface GUIDs

Peer interfaces opened by Qccamavs8930.sys:  
Flash ([qccamflash8930.sys](./qccamflash8930.md)) `{d2ff3f74-880f-4858-841c-fb0bc634676c}`  
Back sensor ([qccamsensor8930.sys](./qccamsensor8930.md)) `{5e34e1c5-c5bc-4c7f-b6fc-e2443e45be67}`  
Front sensor ([qccamfrontsensor8930.sys](./qccamfrontsensor8930.md)) `{f27170b8-7b88-4f4a-b505-1d065616aadc}`  
VFE ([qccamvfe8930.sys](./qccamvfe8930.md)) `{3e9c0fdb-cef9-4c4a-8e85-36e4a82eb80f}`  
VPE `{95f66217-6158-4f46-a8c6-dfd0bfcf94f1}`  
ESP `{e5fde9d7-7a0e-4048-81bb-a77caf7b349f}`  

### Other GUID

Query interface to the display adapter  
`{93042446-d274-44f5-a8cb-2a28263b6a48}`

Device interface property key (`DEVPKEY_Device_PhysicalDeviceLocation` ?)  
`{540b947e-8b40-45bc-a8a2-6a0b894cbda2}`, 9
