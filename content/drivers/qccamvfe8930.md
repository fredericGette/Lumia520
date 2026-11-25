## Qccamvfe8930.sys

Camera VFE Driver ("VFEKMD").  
It's the driver of the VFE (Video Front End: the ISP of the MSM8960/MSM8930 camera subsystem) and of the ISPIF (the interface between the CSI receivers and the VFE). It's a KMDF driver of the Nokia camera stack (same build as [qccamavs8930.sys](./qccamavs8930.md), [qccamgemini8930.sys](./qccamgemini8930.md), …) built around the Qualcomm VFE DAL (`vfe_device.c`, `vfe_drv_core.c`, `vfe_hal.c`, `ispif_dal.c`, `CameraOSServices.c`).  
Its only client is the VFE service of [qccamavs8930.sys](./qccamavs8930.md#camera-device-manager) (device type 3), which opens the device interface and sends one internal IOCTL per VFE command: power, configuration of every block of the pipeline (CAMIF, demosaic, roll-off, white balance, color correction, gamma, scalers, …), output buffers, statistics (AF, AE, AWB, RS, CS, IHIST, BHIST, BF, BG, skin) and capture. The VFE sends back its messages (frame done, statistics, SOF, …) through a queue shared with the client.  
There's no SMMU code in the driver (no qcvcm8930 import): the buffer addresses given by the client are already device addresses.  
PDB path: `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\Driver\fre\qccamvfe8930.pdb`.

There's no named device object and no symbolic link: the device is reached through its device interface (see [Interface GUID](#interface-guid)).

ACPI node: `\_SB.VFE0`, `_HID` `QCOM0700`, `_UID` 0x16, `_DEP` on `\_SB.SMMU` and `\_SB.PEP0`.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qccamvfe` ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0700\22` ?  

The driver doesn't use its `Parameters` key. The values are read in `DriverEntry` (`sub_401E94`, `ZwOpenKey` + `ZwQueryValueKey`) from an absolute path:  
| Registry key | Registry value | value | comment |
|--------------|----------------|-------|---------|
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | TraceEnable | 0 / 1 | 1 = register the ETW provider (`sub_402368`, `dword_422B14`). Same value as [qccamavs8930.sys](./qccamavs8930.md) and the other camera drivers |
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | CoreDbgEnable | 0 / 1 | Only read when `TraceEnable` = 1 (`byte_429B20`). When set, the messages of the DAL ("(%s) - %s", `sub_402560`) are formatted even at DISPATCH_LEVEL and written as ETW events |

GUID of the ETW provider (manifest based, only registered when `TraceEnable` = 1, shared with the other camera drivers, module "VFEKMD", event id 3000):  
`{62774a98-5c63-43e1-8b13-3c5e8958e414}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{3e9c0fdb-cef9-4c4a-8e85-36e4a82eb80f}` (exposed) | [qccamavs8930.sys](./qccamavs8930.md) | Client: VFE service of the AVStream driver, [internal IOCTLs](#internal-ioctl-0x2324030x2326af--vfe-command) |
| Power framework (PEP) | [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state) | `PoFxPowerControl`, VFE clock P-state, see [Power management](#power-management) |

### Driver initialisation

| Callback | Function | Comment |
|----------|----------|---------|
| `EvtDriverDeviceAdd` | 0x42B008 → sub_42B038 | Device context `DEVICE_CONTEXT` (0x13028 bytes), request context `REQUEST_CONTEXT`, `WdfDeviceCreateDeviceInterface` `{3e9c0fdb-…}`, default queue (sub_42B40C), 2 interrupts (sub_40116C, sub_40126C) |
| `EvtDevicePrepareHardware` | 0x42B1F4 | Maps the 2 memory resources (`MmMapIoSpace`, see [Hardware](#hardware)), PoFx registration (sub_4013DC), `vfe_device_open` (sub_402A0C), registers the message callback (sub_401C20) and creates the [message queue](#message-queue) |
| `EvtDeviceReleaseHardware` | 0x42B3A0 | Unregisters the callback, `vfe_device_close` (sub_402850), destroys the message queue (sub_401008), unregisters from PoFx (sub_401754) |
| `EvtDeviceSelfManagedIoInit` | 0x401104 | Starts the default queue |
| `EvtDeviceSelfManagedIoSuspend` | 0x42B1A4 | Stops the default queue |
| `EvtInterruptIsr` | sub_40136C | Both interrupts: only queues the DPC |
| `EvtInterruptDpc` | sub_4013A0 / sub_4013B8 | VFE IST (`off_429BC0` = sub_40D810) / ISPIF IST (`off_429BE8` = sub_414280) |

Default queue: sequential, power managed (default), only `EvtIoInternalDeviceControl` (0x401B30), queue context `QUEUE_CONTEXT` (spinlock, device, client event).

`vfe_device_open` (sub_402A0C) returns a handle (`unk_429B2C`, 56 bytes) whose first 3 fields are the functions used by the KMD layer:  
| Offset | Function | Role |
|--------|----------|------|
| 0x00 | sub_402F08 | `VFE_DRV_IOCTL`: command dispatcher, see [VFE commands](#vfe-commands) |
| 0x04 | sub_402850 | `vfe_device_close` |
| 0x08 | sub_402838 | Register the message callback (handle `+0x2C` function, `+0x30` context) |

The device can be opened only once: a second open returns the same handle and increments a reference count (`dword_422B1C`). At open, the driver reads the VFE base, creates the "async event", starts the IST, creates the ISPIF instance (sub_410C88) and the buffer queues (sub_407368), then reads the hardware version (`VFE_BASE + 0x0` & 0xFFFFF → `dword_429BAC`).

### Hardware

ACPI resources of `\_SB.VFE0`, used in this order:  
| Resource | Value | Usage |
|----------|-------|-------|
| Memory 0 | 0x04500000, 0x760 bytes | VFE registers (`dword_429BE4` → `VFE_BASE` `dword_429BB4` and `VFE3_BASE` `dword_429BB0`, same address) |
| Memory 1 | 0x04800800, 0x400 bytes | ISPIF registers (`dword_429BE0`, used by the ISPIF functions sub_414088 … sub_4145EC) |
| Interrupt 0 | 0x50 (80) | VFE interrupt → VFE IST (sub_40D810) |
| Interrupt 1 | 0xC7 (199) | ISPIF interrupt → ISPIF IST (sub_414280) |

There's no hardcoded physical address: everything comes from the resources.  
Hardware versions known by the code: 0x3030B (mesh roll-off, ROLL_OFF_UPDATE and LENS_ROLL_OFF_TABLE_UPDATE only), 0x30408 and 0x3040F (RDI 1-2 interfaces and 3D roll-off only), otherwise "isn't supported in VFE HW Version". The version is read from register `0x00` (GET_HW_VERSION).

The VFE IST reads 2 status registers ("VFE Interrupt status0=0x%x, status1=0x%x") and handles: reset, CAMIF SOF / epoch 1 / epoch 2, reg update, output 1-3 / raw / ideal raw / RDI write masters (ping-pong), composite and individual statistics, AXI halt, lens roll-off table update (DMI), and the error interrupts (stats overflow, image master 0-6 bus overflow, AXI error, violation, realignment buffer overflow).  
The ISPIF IST handles reset, raw VC and SOF (RDI frame count, stop at frame boundary).

### Power management

The driver registers itself to PoFx (`PoFxRegisterDevice`, sub_4013DC) with the same values as [qccamflash8930.sys](./qccamflash8930.md#power-management): 1 component, GUID `{ffffffff-ffff-ffff-ffff-ffffffffffff}` (`dword_429BD0`, never written), 2 F-states (F0: latency 0, residency 0, power 500; F1: latency 2, residency 5, power 50), device idle state 1. The callbacks (sub_4015C4 … sub_401700) only log and complete the notifications.

The `VFE_PWRMGR` layer of the DAL is replaced by sub_413FAC:
- request 1 (`VFE_CMD_ID_POWER_ON`): `VFEDeviceActivate` → `PoFxActivateComponent(0, PO_FX_FLAG_BLOCKING)`,
- request 2 (clock): `CameraKMDVFE_PowerControl` (sub_40181C) → `PoFxPowerControl`, see below.

`VFEDeviceDeactivate` (sub_414024, power off, open failure) calls `PoFxIdleComponent(0, PO_FX_FLAG_ASYNC_ONLY)`.

The clock frequency is the highest of the rates requested with `VFE_CMD_ID_SET_INTERFACE_DATARATE` for the active interfaces (sub_41152C, minimum 13963636 Hz, forced to 320 MHz when interface 4 is active). It's sent when the VFE starts, at capture / precapture (sub_405248, sub_4068BC).  
PowerControlCode `{3404daac-8e2c-41e4-8458-3158e5ad442b}` (the same code as [qcuart8930.sys](./qcuart8930.md#power-management) and [qcwcn8930.sys](./qcwcn8930.md#power-management))

Inputbuffer (8 bytes, tag `qcve`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Component 0 |
| 04-07 | ? | P-state, see below (sub_401798) |

| Frequency | P-state |
|-----------|---------|
| > 266670000 Hz | 0 |
| > 200000000 Hz | 1 |
| > 153600000 Hz | 2 |
| > 96000000 Hz | 3 |
| > 48000000 Hz | 4 |
| > 13960000 Hz | 5 |
| ≤ 13960000 Hz | 6 |

Outputbuffer: 100 bytes (tag `qcvd`). `00-03` = 3 (`PEP_STATE_SYNC_PATH`): done synchronously; 1: the input buffer is freed by the `DevicePowerControlCallback` (sub_401700).

### Message queue

The VFE messages are not completed as IRPs: they are put in a queue shared with the client (kernel-mode pointers).  
The device context holds a queue header (`InterlockedQueue`, 20 bytes, tag `intQ`) and 512 pre-allocated entries:  
| Offset in header | Comment |
|------------------|---------|
| 0x00 | Spinlock |
| 0x04-0x0B | `LIST_ENTRY` of the pending messages |
| 0x0C | Number of entries (512) |
| 0x10 | Pointer to the entries (device context `+0x1C`) |

| Offset in entry (16 bytes) | Comment |
|----------------------------|---------|
| 0x00-0x07 | `LIST_ENTRY` |
| 0x08 | Pointer to the message (136 bytes, device context `+0x2020` + 136 × index) |
| 0x0C | 1 = free (taken with an interlocked exchange) |

Message (136 bytes):  
| Bytes | Comment |
|-------|---------|
| 00-03 | Message ID |
| 04-07 | Size of the payload (always 128) |
| 08-87 | Payload: the message structure of the DAL (buffer addresses, frame id, timestamps, statistics…) |

The callback (sub_401C20) takes a free entry, fills it, inserts it in the list (`ExInterlockedInsertTailList`) and sets the client event (`KeSetEvent`). When the queue is full: "VFE KMD failed to get an available queue entry! Event ID: %d" (the event is still set). Nothing is sent until the client registered its event ([internal IOCTL 0x232003](#internal-ioctl-0x232003--register-message-event)). The client removes the entries itself and must set their free flag back to 1.  
Message IDs sent by the DAL (sub_40F5CC): 0-2, 28-36, 41-47, 50-51, 55-61; their meaning isn't decoded (output 1/2/3, raw, ideal raw, RDI, composite / individual stats, SOF, capture complete, update ack, Gemini…).

---

### internal IOCTL 0x232003 — register message event

This IOCTL is processed by Qccamvfe8930.sys (`EvtWdfIoQueueIoInternalDeviceControl`, 0x401B30). It's sent by [qccamavs8930.sys](./qccamavs8930.md#internal-ioctl-0x2323ff0x232653--camera-device-control) (`sub_44296C`, VFE service).

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | variable | 16 |

Inputbuffer (`Type3InputBuffer`): the pointer itself is used, it's the `KEVENT *` of the client, stored in the queue context (`+0x8`) and set at each new message. The size isn't checked.

Outputbuffer (`Irp->UserBuffer`), same layout as the [VFE commands](#internal-ioctl-0x2324030x2326af--vfe-command):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to a `PVOID` receiving the address of the [message queue](#message-queue). NULL: the queue is flushed instead (all the entries are freed, sub_402460) |
| 04-07 | ? | Not used |
| 08-0B | ? | Not used |
| 0C-0F | 00 00 00 00 | Result, set to 0 |

---

### internal IOCTL 0x232403…0x2326AF — VFE command

These IOCTLs are processed by Qccamvfe8930.sys (`EvtWdfIoQueueIoInternalDeviceControl`, 0x401B30). They are sent by [qccamavs8930.sys](./qccamavs8930.md#internal-ioctl-0x2323ff0x232653--camera-device-control) (VFE service, `VFEService.cpp`).

The code is computed from the VFE command id `n` (`VFE_CMD_ID_*`, see [VFE commands](#vfe-commands)): `((0x8FF + n) << 2) | 0x230003`, n = 1 (0x232403) … 172 (0x2326AF).

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x8FF + n (0x900 … 0x9AB) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| `VFE_CMD_ID_*` | see [VFE commands](#vfe-commands) | 16 |

Inputbuffer (`Type3InputBuffer`): the command structure, passed as is to `VFE_DRV_IOCTL` with its length.

Outputbuffer (`Irp->UserBuffer`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the response buffer |
| 04-07 | ? | Size of the response buffer |
| 08-0B | ? | Pointer to a ULONG receiving the size of the response (set to 0 first) |
| 0C-0F | ? | Result of the command (written by the driver) |

The handler (0x401BA4) calls `VFE_DRV_IOCTL(handle, n, input, input size, response, response size, &response length)` and writes the result in `0C-0F`. The request is always completed with `STATUS_SUCCESS` (also when the buffers can't be retrieved: then the result isn't written). If `vfe_device_open` failed in `EvtDevicePrepareHardware` (handle = NULL), **the handler dereferences a NULL pointer**.

Results:  
| Value | Meaning |
|-------|---------|
| 0 | Success |
| 1 | Command rejected (wrong state, or during a state transition) |
| 14 (0xE) | Wrong input or response size |
| 20 (0x14) | Unexpected command ("VFE_DRV_IOCTL(%s)(%d): unexpect command(%d) arg") |
| 24 (0x18) | No Gemini handle (`VFE_CMD_ID_JPEG_ENCODE_CFG`) |
| 26 (0x1A) | Update command while another update is pending |
| 29 (0x1D) | NULL handle, or NULL buffer with a size > 0 |

State checks done before the switch (sub_402F08):
- During a state transition (`byte_421307` or `byte_422A1F`): only the commands 108-150 are accepted.
- ACTIVE state: the commands 1-43 (idle state commands) are rejected.
- Update pending (`byte_421D1F`): the commands 45-88 are rejected (26), the commands 152-173 (stats start/stop) too.
- IDLE state: the commands 44-91 (active state commands) are rejected.

#### VFE commands

Name = `VFE_CMD_ID_<name>` (table of names at `.data:0x0041D1F0`, 80 bytes per entry). Sizes in bytes, exact values checked by the dispatcher; "—" = not checked / not used. The handler addresses are the switch targets of the dispatcher (sub_402F08, jump table at 0x403062). The input structures are described in [Command structures](#command-structures).  
The registers are offsets in the VFE register block (`dword_429BB4` = mapped base of `\_SB.VFE0`, see [Hardware](#hardware)); they match the VFE 3.2 layout of the MSM8960 (`msm_vfe32.h` in the Linux MSM kernels): `0x04` global reset, `0x10` module config, `0x14` VFE config, `0x18` IRQ command, `0x1C`/`0x20` IRQ masks, `0x24`/`0x28` IRQ clears, `0x260` register update, `0x598`…`0x5A4` DMI (internal tables).  
| n | IOCTL | Name | Input size | Response size | Function |
|---|-------|------|------------|---------------|----------|
| 1 | 0x232403 | POWER_ON | — | — | `VFEDeviceActivate` (PoFx component 0 active), ISPIF power on |
| 2 | 0x232407 | POWER_OFF | — | — | ISPIF reset, ISPIF power off, `VFEDeviceDeactivate` (PoFx component 0 idle) |
| 3 | 0x23240B | RESET | — | — | ISPIF reset, buffer queues reset, IRQ masks cleared, VFE global reset (`0x04` = 0x3FF) (sub_406D08) |
| 4 | 0x23240F | START | 4 | — | Clock request, ISPIF start, programs the ping-pong buffers of the continuous outputs, CAMIF config (`0x1E4`), register update, CAMIF start (`0x1E0` = 1) (sub_40507C). See [START](#start) |
| 5 | 0x232413 | SEND_SMMU_IMEM_ADDR_INFO | 8 | — | IMEM addresses used by the in-line JPEG path. See [SEND_SMMU_IMEM_ADDR_INFO](#send_smmu_imem_addr_info) |
| 6 | 0x232417 | TEST_GEN_START | 56 | — | Test pattern generator, registers `0x5C8`…`0x5F4` (sub_408FA4). See [TEST_GEN_START](#test_gen_start) |
| 7 | 0x23241B | OPERATION_CONFIG | 60 | — | Input source, pixel pattern, path types, ISPIF mode (sub_404C74). See [OPERATION_CONFIG](#operation_config) |
| 8 | 0x23241F | AXI_OUTPUT_CONFIG | 260 | — | Write masters of the output paths, crossbar, statistics buffers (sub_40A1B8). See [AXI_OUTPUT_CONFIG](#axi_output_config) |
| 9 | 0x232423 | CAMIF_CONFIG | 60 | — | CAMIF registers `0x1E8`…`0x200`, `0x1E4` at START (sub_4091C4). See [CAMIF_CONFIG](#camif_config--camif3_2_config) |
| 10 | 0x232427 | CAMIF3_2_CONFIG | 64 | — | Same as CAMIF_CONFIG, with byte 60 (sub_4091C4) |
| 11 | 0x23242B | ISPIF_CONFIG | 48 | — | CIDs of the PIX / RDI interfaces (ISPIF registers), interface data rates (sub_40931C). See [ISPIF_CONFIG](#ispif_config) |
| 12 | 0x23242F | AXI_INPUT_CONFIG | 76 | — | Offline (memory) input: bus read master `0x158`…`0x178`, `0x72C`, `0x730` (sub_40AB04, sub_4126F4). See [AXI_INPUT_CONFIG](#axi_input_config) |
| 13 | 0x232433 | BLACK_LEVEL_CONFIG | 10 | — | Builds a linearization table from 4 black levels (sub_410E4C) and loads it (sub_413424). See [BLACK_LEVEL_CONFIG](#black_level_config) |
| 14 | 0x232437 | LINEARIZATION_CONFIG | 292 | — | Linearization knee points `0x268`…`0x6AC` and tables (DMI bank 1/2) (sub_413424). See [LINEARIZATION_CONFIG](#linearization_config) |
| 15 | 0x23243B | ROLL_OFF_CONFIG | 1788 | — | Mesh roll-off (lens shading) `0x274`…`0x280` + tables (DMI bank 3) (sub_40B190). HW 0x3030B only. See [ROLL_OFF_CONFIG](#roll_off_config) |
| 16 | 0x23243F | ROLL_OFF_3D_CONFIG | 2248 | — | 3D roll-off (sub_413C54). HW 0x30408 / 0x3040F only. See [ROLL_OFF_3D_CONFIG](#roll_off_3d_config) |
| 17 | 0x232443 | DEMUX_CHANNEL_GAIN_CONFIG | 8 | — | Demux channel gains `0x288`, `0x28C` (inline). See [DEMUX_CHANNEL_GAIN_CONFIG](#demux_channel_gain_config) |
| 18 | 0x232447 | DEMOSAIC_CONFIG | 2 | — | Demosaic v3 with the coefficients built in the driver (`byte_4208A0`) (sub_40B48C → sub_413664) |
| 19 | 0x23244B | DEMOSAIC_ABF_CONFIG | 178 | — | Adaptive Bayer filter `0x2A4`…`0x354` (sub_413770). See [DEMOSAIC_ABF_CONFIG](#demosaic_abf_config) |
| 20 | 0x23244F | DEMOSAIC_BPC_CONFIG | 18 | — | Bad pixel correction, converted to the DBPC layout (sub_40C5B0 → sub_40B5D0) |
| 21 | 0x232453 | DEMOSAICV3_CONFIG | 128 | — | Demosaic v3 `0x61C`…`0x670` (sub_413664). See [DEMOSAICV3_CONFIG](#demosaicv3_config) |
| 22 | 0x232457 | DEMOSAICV3_ABCC_CONFIG | 8200 | — | Adaptive bad cluster correction table, DMI bank 4/5 (sub_413708). See [DEMOSAICV3_ABCC_CONFIG](#demosaicv3_abcc_config) |
| 23 | 0x23245B | DEMOSAICV3_DBCC_CONFIG | 22 | — | Dynamic bad cluster correction `0x60C`…`0x618` (sub_40B558). See [DBCC / DBPC](#demosaicv3_dbcc_config--demosaicv3_dbpc_config) |
| 24 | 0x23245F | DEMOSAICV3_DBPC_CONFIG | 22 | — | Dynamic bad pixel correction `0x29C`, `0x2A0`, `0x604`, `0x608` (sub_40B5D0) |
| 25 | 0x232463 | FOV_CROP_CONFIG | 12 | — | Field of view crop `0x360`, `0x364` (inline). See [FOV_CROP_CONFIG](#fov_crop_config) |
| 26 | 0x232467 | MAIN_SCALER_CONFIG | 44 | — | Main scaler `0x368`…`0x380` (sub_40AFE4). See [Scalers](#main_scaler_config--scaler2y_config--scaler2cbcr_config) |
| 27 | 0x23246B | WHITE_BALANCE_CONFIG | 8 | — | White balance gains `0x384` (inline). See [WHITE_BALANCE_CONFIG](#white_balance_config) |
| 28 | 0x23246F | COLOR_CORRECTION_CONFIG | 32 | — | 3×3 matrix and offsets `0x388`…`0x3B8` (sub_40B648). See [COLOR_CORRECTION_CONFIG](#color_correction_config) |
| 29 | 0x232473 | RGB_GAMMA_CONFIG | 136 | — | Gamma tables, DMI banks 8-13, bank select `0x3BC` (sub_40BA30). See [RGB_GAMMA_CONFIG](#rgb_gamma_config) |
| 30 | 0x232477 | LA_CONFIG | 130 | — | Luma adaptation table, DMI bank 17/18, bank select `0x3C0`. See [LA_CONFIG](#la_config) |
| 31 | 0x23247B | CHROMA_ENHAN_CONFIG | 30 | — | Color conversion / chroma enhancement `0x3C4`…`0x3E4` (sub_40B6E8). See [CHROMA_ENHAN_CONFIG](#chroma_enhan_config) |
| 32 | 0x23247F | CHROMA_SUPPRESSION_CONFIG | 13 | — | Chroma suppression `0x3E8` (rest at UPDATE) (sub_40B334). See [CHROMA_SUPPRESSION_CONFIG](#chroma_suppression_config) |
| 33 | 0x232483 | CLF_CONFIG | 76 | — | Chroma / luma filter `0x6B0`…`0x6F4` (sub_412FB0). See [CLF_CONFIG](#clf_config) |
| 34 | 0x232487 | MCE_CONFIG | 50 | — | Memory color enhancement `0x3F4`…`0x414` (sub_4130CC). See [MCE_CONFIG](#mce_config) |
| 35 | 0x23248B | SKIN_ENHAN_CONFIG | 144 | — | Skin enhancement `0x418`…`0x49C` (sub_413B60). See [SKIN_ENHAN_CONFIG](#skin_enhan_config) |
| 36 | 0x23248F | ASF_CONFIG | 64 | — | Adaptive spatial filter `0x4A0`…`0x4CC`, special effects `0x5FC` (sub_40B3A4, sub_41324C). See [ASF_CONFIG](#asf_config--asf_update) |
| 37 | 0x232493 | SCALER2Y_CONFIG | 36 | — | Second scaler, Y `0x4D0`…`0x4E0` (sub_40B088) |
| 38 | 0x232497 | SCALER2CbCr_CONFIG | 36 | — | Second scaler, CbCr `0x4E4`…`0x4F4` (sub_40B10C) |
| 39 | 0x23249B | CHROMA_SUBSAMPLE_CONFIG | 16 | — | Chroma subsampling `0x4F8`…`0x500` (inline). See [CHROMA_SUBSAMPLE_CONFIG](#chroma_subsample_config) |
| 40 | 0x23249F | OUTPUT_CLAMP_CONFIG | 6 | — | Output clamp `0x524`, `0x528` (inline). See [OUTPUT_CLAMP_CONFIG](#output_clamp_config) |
| 41 | 0x2324A3 | FRAME_SKIP_CONFIG | 16 | — | Frame skip periods / patterns `0x504`…`0x520` (sub_40B78C). See [FRAME_SKIP_CONFIG](#frame_skip_config--frame_skip_update) |
| 42 | 0x2324A7 | RDI_CONFIG | 3 | — | RDI config `0x6FC` (sub_40B914). See [RDI_CONFIG](#rdi_config) |
| 46 | 0x2324B7 | UPDATE | — | — | Writes the module config (`0x10`, see [Module config](#module-config-register)), the demosaic config (`0x298`), the rest of chroma suppression / MCE (`0x3EC`, `0x3F0`), then register update (`0x260` = 1) (sub_40BF98) |
| 47 | 0x2324BB | BLACK_LEVEL_UPDATE | 10 | — | Same as BLACK_LEVEL_CONFIG, into the other linearization bank (`0x264` toggled) |
| 48 | 0x2324BF | LINEARIZATION_UPDATE | 292 | — | Same as LINEARIZATION_CONFIG, into the other bank |
| 49 | 0x2324C3 | ROLL_OFF_UPDATE | 4 | — | `0x280` (inline). HW 0x3030B only. See [ROLL_OFF_UPDATE](#roll_off_update) |
| 50 | 0x2324C7 | ROLL_OFF_3D_UPDATE | 2216 | — | 3D roll-off tables into the other bank (sub_411178 → sub_413D58). See [ROLL_OFF_3D_UPDATE](#roll_off_3d_update) |
| 51 | 0x2324CB | LENS_ROLL_OFF_TABLE_UPDATE | 1768 | — | Only the pointer to the input buffer is kept (`dword_4224D8`): the table is written by DMI at the next interrupt (sub_40B260) |
| 52-74 | 0x2324CF-0x232527 | `<block>_UPDATE` | same as the `_CONFIG` command, except: DEMOSAICV3_UPDATE 124, ASF_UPDATE 48, FRAME_SKIP_UPDATE 8, CAMIF_FRAME_UPDATE 4 | — | Same handler as the `_CONFIG` command. The table commands (RGB_GAMMA 63, LA 64, DEMOSAICV3_ABCC 56) write the unused bank and toggle the bank select. See [Update commands](#update-commands) |
| 76 | 0x23252F | ENABLE_OUTPUT | 36 | — | Turns the write masters of output 1-3 on, with an optional size change (sub_410B68, sub_4107C0). See [ENABLE_OUTPUT](#enable_output--disable_output) |
| 77 | 0x232533 | DISABLE_OUTPUT | 3 | — | Turns the write masters of output 1-3 off (sub_410ADC) |
| 78 | 0x232537 | STATS_AF_UPDATE | 24 | — | `0x53C`…`0x548` (sub_40C300). See [Statistics](#statistics-start--update) |
| 79 | 0x23253B | STATS_AE_UPDATE | 12 | — | `0x534`, `0x538` (inline) |
| 80 | 0x23253F | STATS_AWB_UPDATE | 32 | — | `0x54C`…`0x568` (sub_40C3BC) |
| 81 | 0x232543 | STATS_RS_UPDATE | 12 | — | `0x56C`, `0x570` (inline) |
| 82 | 0x232547 | STATS_CS_UPDATE | 12 | — | `0x574`, `0x578` (inline) |
| 83 | 0x23254B | STATS_SKIN_UPDATE | 18 | — | `0x584`…`0x590` (inline) |
| 84 | 0x23254F | STATS_IHIST_UPDATE | 12 | — | `0x57C`, `0x580` (inline) |
| 85 | 0x232553 | STATS_BF_UPDATE | 28 | — | `0x70C`…`0x720` (sub_40C488) |
| 86 | 0x232557 | STATS_BG_UPDATE | 18 | — | `0x700`…`0x708` (inline) |
| 87 | 0x23255B | STATS_BHIST_UPDATE | 8 | — | `0x724`, `0x728` (inline) |
| 92 | 0x23256F | SYNC_TIMER_SETTING | 20 | — | Sync timers 0-2 `0x20C`…`0x234` (sub_4115BC). See [SYNC_TIMER_SETTING](#sync_timer_setting) |
| 95 | 0x23257B | GET_AXI_OUTPUT_INFO | — | 8 | Always `10 00 00 00 01 00 00 00` |
| 96 | 0x23257F | GET_DROPPED_FRAME_COUNTS | — | 16 | 4 counters: `dword_421E5C`, then one per output path (`+0x1C` of the 3 output path entries) |
| 97 | 0x232583 | GET_DEMOSAIC_INFO | — | 8 | Always `00 00 00 00 01 00 00 00` |
| 98 | 0x232587 | GET_HW_VERSION | — | 12 | Reads `0x00` (sub_4090BC). Response: step (bits 0-7), minor (bits 8-15), major (bits 16-19), one DWORD each |
| 99 | 0x23258B | GET_SCALER_INFO | — | 48 | 12 constant DWORDs (sub_40911C): 80, 48, 2112, 1188, 512, 1024, 80, 48, 5376, 4096, 32, 32 (HW 0x3030B / 0x30408); 4288 and 3216 instead of 5376 and 4096 on HW 0x3040F; all 0 on other versions |
| 100 | 0x23258F | GET_NUM_OF_WM | 4 | 4 | Input: output format of a path. Response: number of write masters it needs (1 for formats 1-4 and 21-27, 2 for 7-10, 3 for 13-18) |
| 101 | 0x232593 | SET_BRACKETING_CALLBACK | 4 | — | The DWORD is stored as a callback pointer (`off_429BBC`) |
| 102 | 0x232597 | CAPTURE | 8 | — | ISPIF capture, then VFE capture (sub_405998, also ZSL / multishot). See [CAPTURE](#capture) |
| 103 | 0x23259B | START_OFFLINE_PROCESS | 8 | — | Offline (memory input) processing (sub_405E84). See [START_OFFLINE_PROCESS](#start_offline_process) |
| 104 | 0x23259F | START_PRECAPTURE | 4 | — | ZSL: starts filling the snapshot buffers (sub_405248). See [START_PRECAPTURE](#start_precapture) |
| 105 | 0x2325A3 | STOP_PRECAPTURE | — | — | ZSL stop (`vfeZslStatus` = 8), clears the ZSL frame table (sub_406108) |
| 107 | 0x2325AB | SET_INTERFACE_DATARATE | 12 | — | Clock of the PIX / RDI interface (sub_404B24). See [Power management](#power-management) and [SET_INTERFACE_DATARATE](#set_interface_datarate) |
| 109 | 0x2325B3 | STOP | — | — | Re-queues the buffers in the ping-pong registers (sub_410520), VFE stop (sub_408DB0: IRQs masked, CAMIF stop `0x1E0` = 2, AXI halt `0x1D8`), waits for the async event, ISPIF stop, ISPIF reset |
| 110-112 | 0x2325B7-0x2325BF | OUTPUT1/2/3_BUFFER_ENQUEUE | 12 | — | See [Buffer queues](#buffer-queues) |
| 113 | 0x2325C3 | INPUT_BUFFER_ENQUEUE | 4 | — | Offline input buffer; restarts the offline processing if it was waiting for a buffer |
| 114 | 0x2325C7 | JPEG_OUTPUT_BUFFER_ENQUEUE | 12 | — | See [Gemini](#gemini) |
| 115 | 0x2325CB | ZSL_JPEG_OUTPUT_BUFFER_ENQUEUE | 12 | — | See [Gemini](#gemini) |
| 116-120 | 0x2325CF-0x2325DF | RAW / IDEAL_RAW / RDI0-2 _BUFFER_ENQUEUE | 4 | — | See [Buffer queues](#buffer-queues) |
| 121-125 | 0x2325E3-0x2325F3 | OUTPUT1/2/3, INPUT, RAW_OUTPUT _BUFFER_DEQUEUE | — | 12 | See [Buffer queues](#buffer-queues) |
| 126-129 | 0x2325F7-0x232603 | IDEAL_RAW, RDI0-2 _OUTPUT_BUFFER_DEQUEUE | — | 4 | See [Buffer queues](#buffer-queues) |
| 130-138 | 0x232607-0x232627 | `<queue>_FLUSH_BUFFER_QUEUE` | — | — | Empties the queue (sub_4148F0) |
| 139-148 | 0x23262B-0x23264F | STATS_AF/AE/AWB/RS/CS/SKIN/IHIST/BF/BG/BHIST_ENQUEUE | 4 | — | Statistics buffer, see [Buffer queues](#buffer-queues) |
| 149 | 0x232653 | START_CAPTURE_ACK_REQUEST | — | — | Waits for the async event of the capture (sub_402D64) |
| 151 | 0x23265B | JPEG_ENCODE_CFG | 68 | — | Passed as is to the Gemini command 8. See [Gemini](#gemini) |
| 153-172 | 0x232663-0x2326AF | STATS_\<type\>_START / STOP | START: AF 24, AE 12, AWB 32, RS 12, CS 12, SKIN 20, IHIST 12, BF 30, BG 20, BHIST 10; STOP: — | — | START: takes 2 buffers from the statistics queue for the ping-pong addresses (sub_40BABC), unmasks the IRQ (`0x1C`, sub_411820) and configures the block. STOP: masks the IRQ, clears the enable. See [Statistics](#statistics-start--update) |

The "dummy" ids (0, 43-45, 88-91, 94, 108, 150, 152, 173) and 75 (`CAMIF3_2_FRAME_UPDATE`), 89 / 90 (`EPOCH1_ACK`, `EPOCH2_ACK`), 93 (`ASYNC_TIMER_SETTING`), 106 (`FAST_AF_FRAME_DROP`) return 20.

#### Command structures

Byte offsets in the input buffer. "→ `0xNNN` bits a-b" = register and bit field the value is written to (after masking to the field width). Most `_CONFIG` structures start with an enable byte: it isn't written to the block registers, but kept in a byte of `dword_4212E8`… and written to the [module config register](#module-config-register) at UPDATE.

##### Module config register

Built by sub_412B28 at UPDATE from the enable bytes, written to `0x10`:  
| Bit | Enable byte (command) |
|-----|------------------------|
| 0 | BLACK_LEVEL / LINEARIZATION |
| 1 | ROLL_OFF / ROLL_OFF_3D |
| 2 | ? (demux) |
| 3 | Set by OPERATION_CONFIG when the pixel pattern is ≥ 4 (YUV input) |
| 4 | DEMOSAIC / DEMOSAICV3 |
| 5 | STATS_AE or STATS_BG |
| 6 | STATS_AF or STATS_BF |
| 7 | STATS_AWB |
| 8 | STATS_RS |
| 9 | STATS_CS |
| 10 | FOV_CROP |
| 11 | MAIN_SCALER |
| 12 | WHITE_BALANCE |
| 13 | CLF |
| 14 | COLOR_CORRECTION |
| 15 | RGB_GAMMA |
| 16 | STATS_IHIST |
| 17 | LA |
| 18 | CHROMA_ENHAN |
| 19 | STATS_SKIN or STATS_BHIST |
| 20 | CHROMA_SUPPRESSION or MCE |
| 21 | SKIN_ENHAN |
| 22 | ASF |
| 23 | CHROMA_SUBSAMPLE |
| 24 | SCALER2Y |
| 25 | SCALER2CbCr |
| 26 | Set by AXI_OUTPUT_CONFIG when a path uses the realign buffer (`byte_421305`) |

The pairs that share a bit also share their IRQ bit: the STOP of one of them masks the IRQ of the other.

##### START

| Bytes | Comment |
|-------|---------|
| 00-03 | 0: the continuous outputs start with the next frame. N > 0: their write masters are only turned on at the N-th start of frame (`byte_421294`, `dword_421298`, counted in the SOF handler sub_40ED54) |

##### SEND_SMMU_IMEM_ADDR_INFO

| Bytes | Comment |
|-------|---------|
| 00-03 | Virtual address of the IMEM buffer (`dword_429B9C`). 0 → result 29 |
| 04-07 | Physical (device) address (`dword_429BA0`). 0 → result 29 |

Only used by the in-line JPEG path (Gemini input addresses, see [Gemini](#gemini)).

##### TEST_GEN_START

| Bytes | Comment |
|-------|---------|
| 00 | → `0x5C8` bit 12 |
| 01 | → `0x5C8` bit 13 |
| 04-07 | → `0x5C8` bit 18 |
| 08-0B | → `0x5C8` bit 19 |
| 0C-0D | → `0x5C8` bits 0-9 |
| 10-13 | → `0x5C8` bits 16-17 |
| 14-15 | → `0x5CC` bits 0-13 (width ?) |
| 16-17 | → `0x5CC` bits 16-29 (height ?) |
| 18-1B | → `0x5D0` bits 0-23 |
| 1C-1F | → `0x5D4` bits 0-23 |
| 20-21 | → `0x5D8` bits 0-8 |
| 22-23 | → `0x5DC` bits 0-8 |
| 24-25 | → `0x5E0` bits 0-13 |
| 26 | → `0x5E4` bit 16 |
| 28-29 | → `0x5E4` bits 0-13 |
| 2C | → `0x5F0` bit 4 |
| 2D | → `0x5F0` bit 5 |
| 2E | → `0x5F0` bits 0-2 |
| 30-33 | → `0x5F0` bits 6-7 |
| 34 | → `0x5F0` bits 8-13 |
| 36-37 | → `0x5F4` |

The generator is started (`0x5C4` = 1) at once if the VFE runs, otherwise at the next START.

##### OPERATION_CONFIG

| Bytes | Comment |
|-------|---------|
| 00-03 | RAW pixel data size: 0, 1, 2 (8, 10, 12 bits: 8, 6 or 5 pixels per 64-bit word for the raw write masters). Other values → "Invalid RAW pixel data size", result 1. Only checked when a raw path is used |
| 04-07 | Path type of output 1 |
| 08-0B | Path type of output 2 |
| 0C-0F | Path type of output 3 |
| 10-13 | Path type of the CAMIF raw path |
| 14-17 | Path type of the ideal raw path |
| 18-1B | Path type of RDI 0 |
| 1C-1F | Path type of RDI 1 |
| 20-23 | Path type of RDI 2 |
| 24-27 | Input source (`vfeInputSource`): 0 = CAMIF, 2 = memory (AXI read, offline processing). → `0x14` bits 16-17 |
| 28-2B | Pixel input pattern, 0-3 = Bayer, 4-7 = YUV. → `0x14` bits 0-2; also selects the demux settings (`0x284`, `0x290`, `0x294`). Other values → "Invalid pixel input pattern", result 1 |
| 2C-2F | ? (`dword_422AD4`) |
| 30-33 | Bit 0 → `0x35C` (YUV input only) |
| 34 | 1 = one composite interrupt for the statistics (`byte_421325`); 0 = one IRQ bit per statistic, unmasked by the STATS_*_START commands |
| 38-3B | ? (copied in the 7 path entries, `dword_421CF8`…) |

Path types: 0 = not used, 1 = continuous (its buffers are programmed by START), 2 = snapshot (programmed by CAPTURE / START_PRECAPTURE ?). The raw and RDI paths must be 1 or 2. From the path types the driver derives the ISPIF mode (`dword_421328`): 0 = RDI only, 1 = PIX only (outputs 1-3, CAMIF raw, ideal raw), 2 = PIX + RDI; no path at all → "Invalid ISPIF Mode", result 1.

##### AXI_OUTPUT_CONFIG

| Bytes | Comment |
|-------|---------|
| 00-03 | Output burst length (`byte_429B73`, write master config). Must be 1 for the in-line JPEG path |
| 04-07 | Statistics class: 0 or 1, selects the size of the statistics bus buffers (sub_40A060). Other values → result 14 |
| 08-0B | Frame rate for the Gemini path: the Gemini frame period is 1000000 / value |
| 0C-2F | Output 1 path, see [Pixel output path](#pixel-output-path) |
| 30-53 | Output 2 path |
| 54-77 | Output 3 path |
| 78-7B | Source of output 3 (`v1[30]`, first argument of sub_409818) |
| 7C-7D | Width of the in-line JPEG input (Gemini) |
| 7E-7F | Height of the in-line JPEG input |
| 80-83 | Source of the in-line JPEG path (same use as 0x78) |
| 84-87 | JPEG input format of the in-line JPEG path: 0-3 (stored as 7-10 in the path entry, and Gemini input format) |
| 88-8B | Not used |
| 8C-A3 | CAMIF raw path, see [Raw output path](#raw-output-path) |
| A4-BB | Ideal raw path. Its format (`+0x08`, offset 0xAC) must be 21-24 (→ 0, 4, 5, 1) |
| BC-D3 | RDI 0 path |
| D4-EB | RDI 1 path |
| EC-103 | RDI 2 path |

A path is only configured when its type in OPERATION_CONFIG is 1 or 2. For output 1 (type 2) and output 2 (type 2), byte `+0x01` of the path selects the in-line JPEG path instead of the write masters (see [Gemini](#gemini)). After the paths, the handler programs the bus buffers (sub_40A060), the write master IRQ mask (`0x18C`), `0x188` = 1, the realign buffer (`0x52C`, when a path has interleaved YUV) and the output crossbar (`0x40`, `0x44`, sub_411C38).

###### Pixel output path

36 bytes, for output 1, 2 and 3 (sub_409818):  
| Bytes | Comment |
|-------|---------|
| 00 | ? |
| 01 | Output 1 / 2 in snapshot mode: ≠ 0 = in-line JPEG (Gemini) path |
| 04-07 | Output format: 1-4 = 1 plane (one write master), 7-10 = 2 planes (Y + CbCr), 13-18 = 3 planes. Other values → result 1 |
| 08-0F | Plane 0, see below |
| 10-17 | Plane 1 |
| 18-1F | Plane 2 |
| 20-23 | Frame interval (`frameInterval`, in the write master entry `+0x14`). 0 → "Output Path %d frame interval invalid", result 14 |

Plane (8 bytes, one write master, sub_409474):  
| Bytes | Comment |
|-------|---------|
| 00-01 | Width (pixels) |
| 02-03 | Height (lines) |
| 04-05 | Buffer height ? (written minus 1) |
| 06-07 | Stride in bytes (written as (stride + 7) / 8) |

###### Raw output path

24 bytes, for the CAMIF raw, ideal raw and RDI paths (sub_409E28):  
| Bytes | Comment |
|-------|---------|
| 00-01 | Width |
| 02-03 | Height |
| 08-0B | Output format: 21, 22, 23, 24 or 27 (not read for the CAMIF raw path, which uses 21) |
| 0C-0F | Raw data size: 0, 1, 2. Allowed combinations: format 21 / 24 / 27 with any size, 22 with size 0, 23 with any size. Other → "invalid raw format", result 14 |
| 10-13 | Frame interval. 0 → "Raw Path frame interval invalid", result 14 |
| 14 | Copied in the path entry (`+0x09`), passed to the write master enable (sub_411DDC) |

##### CAMIF_CONFIG / CAMIF3_2_CONFIG

60 bytes (CAMIF_CONFIG; the dispatcher appends a byte 60 = 0) or 64 bytes (CAMIF3_2_CONFIG), sub_4091C4:  
| Bytes | Comment |
|-------|---------|
| 00-03 | → `0x1E4` bit 0 (written at START) |
| 04-07 | → `0x1E4` bit 1 |
| 08-0B | → `0x1E4` bits 2-3 |
| 0C | → `0x1E4` bit 4 |
| 0D | → `0x1E4` bit 5 |
| 0E | → `0x1E4` bit 8 |
| 0F | → `0x1E4` bit 9 |
| 10 | Bit 0 → `0x1E4` bit 31 |
| 14-17 | 4 bytes → `0x1E8` (byte 0x14 = bits 0-7 … byte 0x17 = bits 24-31) |
| 18-19 | → `0x1EC` bits 0-13 (pixels per line) |
| 1A-1B | → `0x1EC` bits 16-29 (lines per frame) |
| 1C-1D | → `0x1F0` bits 16-29 (window: first pixel) |
| 1E-1F | → `0x1F0` bits 0-13 (window: last pixel) |
| 20-21 | → `0x1F4` bits 16-29 (window: first line) |
| 22-23 | → `0x1F4` bits 0-13 (window: last line) |
| 24-25 | → `0x1F8` bits 0-15 |
| 26-27 | → `0x1F8` bits 16-31 |
| 28-2B | → `0x1FC` bits 0-3 |
| 2C | → `0x1FC` bit 4 |
| 2D | → `0x1FC` bit 5 |
| 30 | 1 = enable the epoch 1 interrupt (if `+0x32` ≤ lines per frame) |
| 32-33 | Epoch 1 line → `0x200` bits 0-13 |
| 34-35 | Stored (`word_422B04`) |
| 36 | 1 = enable the epoch 2 interrupt (if `+0x38` ≤ lines per frame) |
| 38-39 | Epoch 2 line → `0x200` bits 16-29 |
| 3A-3B | Stored (`word_422B08`) |
| 3C | CAMIF3_2 only. → `0x1E4` bit 10. When ≠ 0, the bytes 0x0C, 0x0D, 0x0F, 0x2D and the words 0x18-0x27 must be 0, otherwise result 14 |

##### CAMIF_FRAME_UPDATE

| Bytes | Comment |
|-------|---------|
| 00-01 | → `0x1EC` bits 0-13 (pixels per line) |
| 02-03 | → `0x1EC` bits 16-29 (lines per frame) |

##### ISPIF_CONFIG

48 bytes. The first 40 bytes are passed to the ISPIF command 3 (sub_414088, which writes the ISPIF registers, base `dword_429BE0`):  
| Bytes | Comment |
|-------|---------|
| 00-03 | → ISPIF `0x0C` bits 4-5 (RDI input select: CSID ?) |
| 04-07 | → ISPIF `0x0C` bits 0-1 (PIX input select: CSID ?) |
| 08-17 | `pixCID[16]`: byte i ≠ 0 → bit i of ISPIF `0x10`. At most 1 CID, otherwise result 14 |
| 18-27 | `rdiCID[16]`: byte i ≠ 0 → bit i of ISPIF `0x14`. At most 3 CIDs, otherwise result 14. The index of the last one is kept as `rdiCid` (`dword_42141C`, used by RDI_CONFIG) |
| 28-2B | PIX interface data rate (if a PIX CID is set), see [SET_INTERFACE_DATARATE](#set_interface_datarate) |
| 2C-2F | RDI 0 interface data rate (if a RDI CID is set) |

##### AXI_INPUT_CONFIG

76 bytes (sub_40AB04, sub_4126F4):  
| Bytes | Comment |
|-------|---------|
| 00-01 | Width → `0x158` bits 0-11 and `0x164` bits 0-11 |
| 04-05 | Height → `0x164` bits 12-24 (minus 1) |
| 06-07 | Stride ? → `0x160` bits 16-27 (written as (value + 7) / 8) |
| 08-09 | → `0x160` bits 4-15 |
| 0C-0F | → `0x160` bits 0-1 |
| 10-13 | `xSizeWord` → `0x15C` bits 16-26 |
| 14-17 | `readPixelFormat`: 0-5, selects the unpack pattern written to `0x168` |
| 18 | → `0x164` bits 28-30 |
| 1C-1F | → `0x164` bits 25-27 |
| 20-23 | Raw data size (format 0: 1 or 2 select the unpack pattern) |
| 24-27 | 4 × 7 bits → `0x16C` |
| 28-2F | 4 × 4 bits + 4 × 1 bit → `0x170` |
| 30-37 | 4 × 4 bits + 4 × 1 bit → `0x174` |
| 38, 39 | → `0x178` bits 0-3, 16-19 |
| 3C-3F | → `0x72C` bits 16-28 |
| 40-43 | → `0x72C` bits 0-12 |
| 44-47 | → `0x730` bits 12-23 |
| 48-4B | → `0x730` bits 0-11 |

##### BLACK_LEVEL_CONFIG

| Bytes | Comment |
|-------|---------|
| 00 | Enable ([module config](#module-config-register) bit 0) |
| 02-09 | 4 × WORD: black levels of the 4 Bayer channels, assigned to R / Gr / Gb / B according to the pixel pattern of OPERATION_CONFIG |

The driver builds a linearization table with the same layout as LINEARIZATION_CONFIG from the 4 black levels (sub_410E4C, 9 points per channel spaced by (4095 - black level) / 8) and loads it like LINEARIZATION_CONFIG. Then `0x264` = bank.

##### LINEARIZATION_CONFIG

292 bytes (sub_413424): byte 0 = enable (bit 0), then 4 channel blocks of 72 bytes at 0x04, 0x4C, 0x94, 0xDC:  
| Bytes in block | Comment |
|----------------|---------|
| 00-0F | 8 × WORD knee points, 12 bits, written 2 per register: block 0 → `0x268`, `0x26C`, `0x270`, `0x67C`; block 1 → `0x6A0`…`0x6AC`; block 2 → `0x690`…`0x69C`; block 3 → `0x680`…`0x68C` |
| 10-21 | 9 × WORD base values (12 bits) |
| 24-47 | 9 × DWORD slopes (18 bits) |

The 9 (base, slope) pairs of each block are written by DMI (bank 1, or 2 for the update), entry = base \| slope << 12, in the order block 0, 1, 3, 2.

##### ROLL_OFF_CONFIG

1788 bytes (sub_40B190, sub_413AA8). HW 0x3030B only, otherwise result 20:  
| Bytes | Comment |
|-------|---------|
| 00 | Enable ([module config](#module-config-register) bit 1) |
| 02-03 | → `0x274` bits 0-8 |
| 04-05 | → `0x274` bits 9-17 |
| 06-07 | → `0x274` bits 18-27 |
| 08 | → `0x278` bits 0-3 |
| 09 | → `0x278` bits 4-7 |
| 0A-0B | → `0x278` bits 8-16 |
| 0C-0D | → `0x278` bits 20-28 |
| 0E-0F | → `0x27C` bits 0-12 |
| 10-11 | → `0x280` bits 0-8 |
| 12 | → `0x280` bit 12 |
| 14-7B | 4 × 13 WORD: initial grid values of the 4 channels (DMI bank 3, address 0) |
| 7C-6FB | 4 × 208 WORD: delta tables of the 4 channels (DMI bank 3, address 32) |

The tables are written 2 channels per DMI entry (channel 0 \| channel 1 << 16, then channel 2 \| channel 3 << 16).

##### ROLL_OFF_UPDATE

HW 0x3030B only, otherwise result 20:  
| Bytes | Comment |
|-------|---------|
| 00-01 | → `0x280` bits 0-8 |
| 02-03 | Bit 0 → `0x280` bit 12 |

##### ROLL_OFF_3D_CONFIG

2248 bytes (sub_413C54). HW 0x30408 / 0x3040F only, otherwise result 20:  
| Bytes | Comment |
|-------|---------|
| 00-03 | Mode: 1 = one table, 3 = two tables. Other → result 1. Modes 1 and 3 also set the roll-off enable (bit 1) |
| 04-05 | → `0x274` bits 0-8 |
| 06 | → `0x7AC` bits 0-3 |
| 07 | → `0x7AC` bits 4-7 |
| 08-09 | → `0x7AC` bits 8-16 |
| 0A-0B | → `0x7AC` bits 20-28 |
| 0C-0D | → `0x7B0` bits 0-12 |
| 10-11 | → `0x278` bits 20-29 |
| 14-17 | → `0x278` bits 0-16 |
| 18-19 | → `0x27C` bits 0-8 |
| 1A-1B | → `0x27C` bits 9-17 |
| 1C-1D | Mode 3: → `0x280` bits 20-29 |
| 20-23 | Mode 3: → `0x280` bits 0-16 |
| 24-25 | Mode 3: → `0x7A8` bits 0-8 |
| 26-27 | Mode 3: → `0x7A8` bits 9-17 |
| 28-477 | Table 0 (1104 bytes), see below. DMI banks 3 and 19 |
| 478-8C7 | Table 1, mode 3 only. Same DMI banks, address 80 |

Table (1104 bytes = 69 entries of 16 bytes, sub_413DF4): one group of 17 entries, then 4 groups of 13 entries (at 0x110, 0x1E0, 0x2B0, 0x380). Each entry: `+0` DWORD (DMI low word) and `+4` bits 0-5 (DMI high word) written in the first bank, `+8` DWORD written in the second bank, `+C` not used.

##### ROLL_OFF_3D_UPDATE

2216 bytes (sub_413D58). HW 0x30408 / 0x3040F only:  
| Bytes | Comment |
|-------|---------|
| 00-03 | Mode: 1 or 3. Other → result 1 |
| 04-05 | → `0x274` bits 0-8; bit 16 = new bank |
| 08-457 | Table 0 |
| 458-8A7 | Table 1 (mode 3) |

The tables are written into the bank not in use (banks 20 / 21 instead of 3 / 19), then the bank bit of `0x274` is toggled.

The 3D roll-off registers `0x7A8`…`0x7B0` are beyond the 0x760 bytes of the VFE memory resource of the Lumia 520 (see [Hardware](#hardware)).

##### DEMUX_CHANNEL_GAIN_CONFIG

| Bytes | Comment |
|-------|---------|
| 00-01 | → `0x288` bits 0-9 |
| 02-03 | → `0x288` bits 16-25 |
| 04-05 | → `0x28C` bits 0-9 |
| 06-07 | → `0x28C` bits 16-25 |

No enable byte.

##### DEMOSAIC_CONFIG

| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 4) |
| 01 | Stored (`dword_421E14`), not used |

##### DEMOSAIC_ABF_CONFIG

178 bytes (sub_413770). The WORD values are 12 bits, written 2 per register (first one in bits 0-11, second one in bits 16-27):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (demosaic config `0x298` bit 3, written at UPDATE) |
| 01 | Stored (`byte_421E09`) |
| 02-05 | → `0x2A4` |
| 06-07 | → `0x2A8` bits 0-11 |
| 08 | → `0x2A8` bits 16-22 |
| 09 | → `0x2A8` bits 24-30 |
| 0A-0D | → `0x2AC` |
| 0E-2D | 8 × 2 WORD → `0x2B0`…`0x2CC` |
| 2E-3D | 4 × 2 WORD → `0x2D0`…`0x2DC` |
| 3E-41 | → `0x2E0` |
| 42-43 | → `0x2E4` bits 0-11 |
| 44-47 | → `0x2E8` |
| 48-67 | 8 × 2 WORD → `0x2EC`…`0x308` |
| 68-77 | 4 × 2 WORD → `0x30C`…`0x318` |
| 78-7B | → `0x31C` |
| 7C-7D | → `0x320` bits 0-11 |
| 7E-81 | → `0x324` |
| 82-A1 | 8 × 2 WORD → `0x328`…`0x344` |
| A2-B1 | 4 × 2 WORD → `0x348`…`0x354` |

The 3 groups (0x02, 0x3E, 0x78) are the 3 color channels.

##### DEMOSAICV3_CONFIG

128 bytes (sub_413664):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 4) |
| 01 | → `0x298` bit 31 (at UPDATE) |
| 02 | → `0x298` bit 30 (at UPDATE) |
| 04-05 | → `0x298` bits 16-28 (at UPDATE) |
| 06 | → `0x298` bit 4 (at UPDATE) |
| 08-09 | → `0x61C` bits 15-23 |
| 0A-0B | → `0x61C` bits 0-8 |
| 0C-0D | → `0x620` bits 15-23 |
| 0E-0F | → `0x620` bits 0-8 |
| 10-21 | 18 bytes → bits 31-… of `0x624`…`0x668` (one per register) |
| 22-33 | 18 bytes, 5 bits → bits 24-28 of `0x624`…`0x668` |
| 34-57 | 18 WORD, 10 bits → bits 12-21 of `0x624`…`0x668` |
| 58-7B | 18 WORD, 10 bits → bits 0-9 of `0x624`…`0x668` |
| 7C | → `0x66C` bits 8-15 |
| 7D | → `0x66C` bits 0-7 |
| 7E | → `0x670` bits 12-17 |
| 7F | → `0x670` bits 0-7 |

DEMOSAICV3_UPDATE (124 bytes) has no enable / byte 6: bytes 0, 1 and 2-3 are the bytes 1, 2 and 4-5 above, and the table starts at offset 4.

##### DEMOSAICV3_ABCC_CONFIG

8200 bytes (sub_413708):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (`0x298` bit 2, at UPDATE) |
| 04-07 | Number of entries (up to 1024) |
| 08-2007 | Entries of 8 bytes: DWORD low, DWORD high → DMI bank 4 (bank 5 for the update, which toggles the bank) |

##### DEMOSAICV3_DBCC_CONFIG / DEMOSAICV3_DBPC_CONFIG

22 bytes (DBCC sub_40B558, DBPC sub_40B5D0):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (`0x298` bit 1 for DBCC, bit 0 for DBPC, at UPDATE) |
| 02 | → 1st register bits 8-15 |
| 04 | → 1st register bits 0-7 |
| 06-07 | → 2nd register bits 10-19 |
| 08-09 | → 2nd register bits 0-9 |
| 0A-0B | → 3rd register bits 20-29 |
| 0C-0D | → 2nd register bits 20-29 |
| 0E-0F | → 3rd register bits 10-19 |
| 10-11 | → 3rd register bits 0-9 |
| 12-13 | → 4th register bits 10-19 |
| 14-15 | → 4th register bits 0-9 |

Registers: DBCC `0x60C`, `0x610`, `0x614`, `0x618`; DBPC `0x29C`, `0x2A0`, `0x604`, `0x608`.  
DEMOSAIC_BPC_CONFIG (18 bytes) is the older layout: byte 0 enable, WORDs at 2, 4, 6, 8 and 10, 12, 14 are copied into a DBPC structure (the WORD at 10 is used 3 times, the one at 14 twice) and written with sub_40B5D0.

##### FOV_CROP_CONFIG

| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 10) |
| 02-03 | First pixel → `0x360` bits 16-28 |
| 04-05 | Last pixel → `0x360` bits 0-12 |
| 06-07 | First line → `0x364` bits 16-27 |
| 08-09 | Last line → `0x364` bits 0-11 |
| 0A-0B | Stored (`word_422474`) |

##### MAIN_SCALER_CONFIG / SCALER2Y_CONFIG / SCALER2CbCr_CONFIG

44 bytes for the main scaler (registers `0x368`…`0x380`), 36 bytes for SCALER2Y (`0x4D0`…`0x4E0`) and SCALER2CbCr (`0x4E4`…`0x4F4`):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 11 main, bit 24 Y, bit 25 CbCr) |
| 04 | Horizontal enable → 1st register bit 0 |
| 06-07 | Horizontal input size → 2nd register bits 0-12 |
| 08-09 | Horizontal output size → 2nd register bits 16-28 |
| 0C-0F | Horizontal phase multiplication factor → 3rd register bits 0-18 |
| 10 | Horizontal interpolation resolution → 3rd register bits 20-21 |
| 14 | Vertical enable → 1st register bit 1 |
| 16-17 | Vertical input size → 4th register bits 0-12 |
| 18-19 | Vertical output size → 4th register bits 16-28 |
| 1C-1F | Vertical phase multiplication factor → 5th register bits 0-18 |
| 20 | Vertical interpolation resolution → 5th register bits 20-21 |
| 24-25 | Main scaler only: → `0x374` bits 0-12 |
| 26-27 | Main scaler only: → `0x374` bits 16-31 |
| 28-29 | Main scaler only: → `0x380` bits 0-12 |
| 2A-2B | Main scaler only: → `0x380` bits 16-31 |

Main scaler register order: `0x368` enables, `0x36C` H sizes, `0x370` H phase, `0x374`, `0x378` V sizes, `0x37C` V phase, `0x380`.

##### WHITE_BALANCE_CONFIG

| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 12) |
| 02-03 | Gain → `0x384` bits 18-26 |
| 04-05 | Gain → `0x384` bits 9-17 |
| 06-07 | Gain → `0x384` bits 0-8 |

##### COLOR_CORRECTION_CONFIG

| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 14) |
| 04-07 | Q factor → `0x3B8` bits 0-1 |
| 08-19 | 9 × WORD coefficients (12 bits) → `0x388`…`0x3A8` |
| 1A-1F | 3 × WORD offsets (11 bits) → `0x3AC`…`0x3B4` |

##### RGB_GAMMA_CONFIG

136 bytes (sub_40BA30; update sub_40C1FC):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 15) |
| 04-07 | Channels: 0 = table 0, 1 = table 1, 2 = table 2, 3 = tables 0 + 1, 4 = 0 + 2, 5 = 1 + 2, 6 = all 3. Other values: nothing written |
| 08-87 | 64 × WORD table, written by DMI to each selected channel (banks 8/9, 10/11, 12/13) |

The update writes the other bank of each selected channel and the 3 bank bits to `0x3BC`.

##### LA_CONFIG

130 bytes:  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 17) |
| 02-81 | 64 × WORD luma adaptation table → DMI bank 17 (or 18) |

The bank is selected by `0x3C0` (sub_41398C). LA_UPDATE toggles the bank before writing.

##### CHROMA_ENHAN_CONFIG

30 bytes (sub_40B6E8), color conversion coefficients:  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 18) |
| 02-03 / 04-05 | → `0x3D4` bits 16-27 / 0-11 |
| 06-07 / 08-09 | → `0x3D8` bits 16-27 / 0-11 |
| 0A-0B / 0C-0D | → `0x3DC` bits 16-27 / 0-11 |
| 0E-0F / 10-11 | → `0x3E0` bits 16-27 / 0-11 |
| 12-13 / 14-15 | → `0x3E4` bits 16-26 / 0-10 |
| 16-17 | → `0x3C4` bits 0-11 |
| 18-19 | → `0x3C8` bits 0-11 |
| 1A-1B | → `0x3CC` bits 0-11 |
| 1C | → `0x3D0` bits 0-7 |

##### CHROMA_SUPPRESSION_CONFIG

13 bytes (sub_40B334). Only `0x3E8` is written at once, `0x3EC` and `0x3F0` at UPDATE:  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 20, shared with MCE) and `0x3EC` bit 24 (the MCE enable is `0x3EC` bit 28) |
| 01 | → `0x3E8` bits 0-7 |
| 02 | → `0x3E8` bits 8-15 |
| 03 | → `0x3E8` bits 16-23 |
| 04 | → `0x3E8` bits 24-31 |
| 05 | → `0x3EC` bits 16-18 |
| 06 | → `0x3EC` bits 20-22 |
| 07 | → `0x3EC` bits 0-6 |
| 08 | → `0x3EC` bits 8-14 |
| 09 | → `0x3F0` bits 0-7 |
| 0A | → `0x3F0` bits 8-15 |
| 0B | → `0x3F0` bits 16-22 |
| 0C | → `0x3F0` bits 24-26 |

##### CLF_CONFIG

76 bytes (sub_412FB0):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 13) |
| 01 | → `0x6B0` bit 30 |
| 02 | → `0x6B0` bit 29 |
| 04-05 | → `0x6B0` bits 16-28 |
| 06-07 / 08-09 | → `0x6B4` bits 0-11 / 16-27 |
| 0A-0B | → `0x6B8` bits 0-11 |
| 0C-0D / 0E-0F | → `0x6BC` bits 16-27 / 0-11 |
| 10-2F | 8 × 2 WORD → `0x6C0`…`0x6DC` (bits 0-11, 16-27) |
| 30-3F | 4 × 2 WORD → `0x6E0`…`0x6EC` |
| 40-41 / 42-43 | → `0x6F0` bits 0-6 / 8-13 |
| 44-4B | 4 WORD → `0x6F4` bits 0-6, 8-13, 16-21, 24-29 |

##### MCE_CONFIG

50 bytes (sub_4130CC): byte 0 = enable (bit 20), byte 1 → `0x3F0` bits 28-… (at UPDATE), then 3 groups of 16 bytes for the 3 memory colors (red, green, blue ?) at 0x02 (`0x3F4`…`0x3FC`), 0x12 (`0x400`…`0x408`), 0x22 (`0x40C`…`0x414`):  
| Bytes in group | Comment |
|----------------|---------|
| 00-03 | 4 bytes → 1st register (bits 0-7, 8-15, 16-23, 24-31) |
| 04 | → 2nd register bits 0-6 |
| 05 | → 2nd register bits 8-14 |
| 06 | → 2nd register bits 15-18 |
| 07 | → 2nd register bits 19-22 |
| 08 | → 2nd register bits 23-27 |
| 09 | → 2nd register bits 28-31 |
| 0A-0B | → 3rd register bits 21-29 |
| 0C | → 3rd register bits 16-20 |
| 0D | → 3rd register bits 8-15 |
| 0E | → 3rd register bits 0-7 |

##### SKIN_ENHAN_CONFIG

144 bytes (sub_413B60):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 21) |
| 01-0F | 5 × 3 bytes → `0x418`…`0x428` (byte i, i+5, i+10 → bits 0-7, 8-15, 16-23) |
| 10-1E | 5 × 3 bytes → `0x42C`…`0x43C` |
| 20-2B / 2C-37 | 6 + 6 WORD → `0x440`…`0x454` (bits 0-11, 16-27) |
| 38-43 / 44-4F | 6 + 6 WORD → `0x458`…`0x46C` |
| 50-67 | 6 × DWORD (17 bits) → `0x470`…`0x484` bits 0-16 |
| 68-6D | 6 bytes (4 bits) → `0x470`…`0x484` bits 20-23 |
| 70-87 | 6 × DWORD (17 bits) → `0x488`…`0x49C` bits 0-16 |
| 88-8D | 6 bytes (4 bits) → `0x488`…`0x49C` bits 20-23 |

##### ASF_CONFIG / ASF_UPDATE

64 bytes (ASF_CONFIG, sub_40B3A4) or 48 bytes (ASF_UPDATE, sub_41324C only):  
| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 22) |
| 01 | → `0x4A4` bit 31 |
| 02 | → `0x4A0` bit 30 |
| 03 | → `0x4A0` bit 29 |
| 04-05 | → `0x4A0` bits 16-28 |
| 06 | → `0x4A0` bit 0 |
| 07 | → `0x4A0` bits 1-2 |
| 08 | → `0x4A0` bit 3 |
| 09 | → `0x4A0` bits 8-15 |
| 0A | → `0x4A0` bits 4-7 |
| 0B | → `0x4A4` bits 24-30 |
| 0C | → `0x4A4` bits 8-13 |
| 0D | → `0x4A4` bits 16-21 |
| 0E | → `0x4A4` bits 0-6 |
| 0F-12 | 4 bytes → `0x4A8` |
| 13-2D | 27 bytes, 6 or 7 bits each, 5 (or 4) per register → `0x4AC`…`0x4C0` |
| 2E | → `0x4A0` bit 31; ASF_CONFIG: also the crop enable |
| 30-31 | ASF_CONFIG, crop: → `0x4C8` bits 16-28 |
| 32-33 | ASF_CONFIG, crop: → `0x4C8` bits 0-12 |
| 34-35 | ASF_CONFIG, crop: → `0x4CC` bits 16-27 |
| 36-37 | ASF_CONFIG, crop: → `0x4CC` bits 0-11 |
| 38-3F | ASF_CONFIG: 8 × 2 bits → `0x5FC` (special effects) |

##### CHROMA_SUBSAMPLE_CONFIG

| Bytes | Comment |
|-------|---------|
| 00 | Enable (bit 23) |
| 01-07 | 7 flags (bit 0 of each byte) → `0x4F8` bits 6 (byte 1) … 0 (byte 7) |
| 08-09 | → `0x4FC` bits 16-28 |
| 0A-0B | → `0x4FC` bits 0-12 |
| 0C-0D | → `0x500` bits 16-27 |
| 0E-0F | → `0x500` bits 0-11 |

##### OUTPUT_CLAMP_CONFIG

| Bytes | Comment |
|-------|---------|
| 00-02 | 3 bytes → `0x528` bits 0-7, 8-15, 16-23 |
| 03-05 | 3 bytes → `0x524` bits 0-7, 8-15, 16-23 |

No enable byte.

##### FRAME_SKIP_CONFIG / FRAME_SKIP_UPDATE

FRAME_SKIP_CONFIG (16 bytes):  
| Bytes | Comment |
|-------|---------|
| 00 | Period 1 (5 bits) → `0x514`, `0x518` |
| 04-07 | Pattern 1 → `0x51C`, `0x520` |
| 08 | Period 2 (5 bits) → `0x504`, `0x508` |
| 0C-0F | Pattern 2 → `0x50C`, `0x510` |

FRAME_SKIP_UPDATE (8 bytes): pattern 1 (DWORD, → `0x51C`, `0x520`), pattern 2 (DWORD, → `0x50C`, `0x510`). The driver also keeps the patterns of output 3 and of the main output (`vfeMainFrameSkipPattern`) for the snapshot paths.

##### RDI_CONFIG

| Bytes | Comment |
|-------|---------|
| 00 | `frameSkipEnable` → `0x6FC` bit 24 |
| 01 | `frameSkipPattern` (4 bits) → `0x6FC` bits 20-23 |
| 02 | `frameBasedEnable` → `0x6FC` bit 16 |

`0x6FC` = 7 \| `rdiCid` << 4 \| … (`rdiCid` from ISPIF_CONFIG).

##### Update commands

The `_UPDATE` commands 52-74 use the same structure and handler as the `_CONFIG` command of the same block, with these differences:
- DEMOSAICV3_UPDATE: no enable byte, see [DEMOSAICV3_CONFIG](#demosaicv3_config).
- DEMOSAICV3_ABCC_UPDATE, RGB_GAMMA_UPDATE, LA_UPDATE: the table goes to the unused bank, then the bank is switched.
- ASF_UPDATE: 48 bytes, no crop / special effects.
- FRAME_SKIP_UPDATE, CAMIF_FRAME_UPDATE: see above.

They are rejected while an update is pending (result 26), and take effect with UPDATE (register update `0x260`).

##### ENABLE_OUTPUT / DISABLE_OUTPUT

ENABLE_OUTPUT: 3 entries of 12 bytes, for output 1, 2 and 3:  
| Bytes in entry | Comment |
|----------------|---------|
| 00 | ≠ 0 = turn the write masters of the output on |
| 01 | ≠ 0 = change the size first (sub_4107C0) |
| 04-07 | New width |
| 08-0B | New height |

DISABLE_OUTPUT: 3 bytes, ≠ 0 = turn the write masters of output 1 / 2 / 3 off.

##### SYNC_TIMER_SETTING

20 bytes (sub_4115BC):  
| Bytes | Comment |
|-------|---------|
| 00 | Timer: 0, 1 or 2. ≥ 3 → ignored |
| 01 | 1 = start (`0x20C` bit n), otherwise stop (`0x20C` bit 16 + n) |
| 02 | Updates bit n of `0x234` (polarity ?) |
| 06-07 | Stored (timer entry, `unk_421C08`) |
| 08-09 | Line → `0x210` / `0x21C` / `0x228` bits 0-11 |
| 0C-0F | Start delay → `0x214` / `0x220` / `0x22C` bits 0-26 |
| 10-13 | Duration → `0x218` / `0x224` / `0x230` bits 0-27 |

The timer is also added to the IRQ mask (`byte_421FB9` + n).

##### SET_INTERFACE_DATARATE

12 bytes (sub_404B24):  
| Bytes | Comment |
|-------|---------|
| 00-03 | Interface: 0 = PIX, 1 = RDI. Other → result 14 |
| 04-07 | RDI index: 0 (RDI 0), 1, 2 (RDI 1 and 2 only on HW 0x30408 / 0x3040F, otherwise result 20) |
| 08-0B | PIX: clock rate (Hz, 1 … 320000000). RDI: bit rate, the clock rate is 1000 × (value >> 5) |

The rate is stored in the clock table (`dword_421D5C`) and applied with the next clock request.

##### CAPTURE

| Bytes | Comment |
|-------|---------|
| 00-03 | Number of frames to capture (`vfeNumOfFramesToCapture`). With ZSL running, the frames are taken from the ZSL buffers (the frame table lags by the ZSL count of START_PRECAPTURE) |
| 04-07 | RDI paths only: number of frames to drop first (`rdiNumberOfFramesToDrop`, `dword_421E60`) |

##### START_OFFLINE_PROCESS

| Bytes | Comment |
|-------|---------|
| 00-03 | Number of frames to process (`dword_4224DC`). The input source must be 2. If the input queue is empty, the processing waits for INPUT_BUFFER_ENQUEUE |
| 04-07 | Not used |

##### START_PRECAPTURE

| Bytes | Comment |
|-------|---------|
| 00 | Number of frames kept by ZSL (`byte_421D1E`) |
| 02-03 | `zslCaptureLag` (`word_42296C`) |

##### Statistics: START / UPDATE

The START commands have an enable byte at 0, the UPDATE commands don't. For AE, AF, AWB, RS, CS, IHIST, the UPDATE structure has the same size with byte 0 holding the field of START byte 1. For SKIN, BF, BG, BHIST, the UPDATE structure is the START structure without its first 2 bytes. Coordinates and sizes are 13-bit (horizontal) and 12-bit (vertical) values.

| Statistic | Bytes (START) | Registers |
|-----------|---------------|-----------|
| AE (155 / 79) | 01 → `0x534` bits 28-31; 02-03 → `0x534` bits 0-12; 04-05 → bits 16-27; 06-07 → `0x538` bits 0-9; 08-09 → bits 12-20; 0A → bits 24-27; 0B → bits 28-31 | `0x534`, `0x538` |
| AF (153 / 78) | 01 → `0x53C` bits 28-30; 02-03 (+2) → bits 0-12; 04-05 (+1) → bits 16-27; 06-07 → `0x540` bits 0-11; 08-09 → bits 12-22; 0A → bits 24-27; 0B → bits 28-31; 0C → `0x544` bit 31; 0E-0F → bits 16-26; 10, 11, 12 → bits 0-4, 5-9, 10-14; 13-17 → `0x548` 5 × 5 bits | `0x53C`…`0x548` |
| AWB (157 / 80) | 01 → `0x54C` bit 28; 02-03 → `0x550` bits 0-8; 04-05 → bits 12-20; 06 → bits 24-27; 07 → bits 28-31; 08 → `0x554` bits 0-7 (8-15 for the update); 09 → bits 8-15 (0-7 for the update); 0A-0D → `0x560`; 0E-0F / 10-11 → `0x558`; 12-13 / 14-15 → `0x55C`; 16, 17, 18, 1D → `0x564`; 1A-1B → `0x568` bits 0-9; 1C → bits 24-31; 1E-1F → bits 12-20 | `0x54C`…`0x568` |
| RS (159 / 81) | 01 → `0x56C` bits 28-30; 02-03 → bits 0-12; 04-05 → bits 16-27; 06-07 → `0x570` bits 0-12; 08-09 → bits 13-14; 0A-0B → bits 16-25 | `0x56C`, `0x570` |
| CS (161 / 82) | 01 → `0x574` bits 28-30; 02-03 → bits 0-12; 04-05 → bits 16-27; 06-07 → `0x578` bits 0-1; 08-09 → bits 4-15; 0A-0B → bits 16-26 | `0x574`, `0x578` |
| IHIST (165 / 84) | 01 → `0x57C` bit 31; 02 → bits 13-15; 03 → bits 28-30; 04-05 → `0x580` bits 0-11; 06-07 → bits 12-22; 08-09 → `0x57C` bits 16-27; 0A-0B → bits 0-12. START also clears the histogram (DMI bank 16, 256 entries) | `0x57C`, `0x580` |
| SKIN (163 / 83) | 02-03 / 04-05 → `0x584`; 06, 07, 08, 09 → `0x588`; 0A, 0B, 0D → `0x58C`; 0C, 0E-0F → `0x590`; 10-13 → `0x588` again (overwrites the first value) | `0x584`…`0x590` |
| BF (167 / 85) | 02-03 / 04-05 → `0x70C` (the update adds 4 and 2); 06-07, 08-09, 0A, 0B → `0x710`; 0C-0D / 0E-0F → `0x714`; 10-11 / 12-13 → `0x718`; 14-18 → `0x71C` 5 × 5 bits; 19-1D → `0x720` | `0x70C`…`0x720` |
| BG (169 / 86) | 02-03 / 04-05 → `0x700`; 06-07 → `0x704` bits 0-8; 08 → bits 10-17; 0A → bits 19-25; 0B → bits 26-31; 0C-0D, 0E, 10, 12 → `0x708` | `0x700`…`0x708` |
| BHIST (171 / 87) | 02-03 / 04-05 → `0x724`; 06-07 / 08-09 → `0x728` | `0x724`, `0x728` |

##### Buffer queues

The buffers are kept in 16 queues (sub_41480C enqueue, sub_414880 dequeue, sub_4148F0 flush), protected by a spin lock. An entry is copied as is:
- output 1-3 (enqueue 110-112, dequeue 121-123): 12 bytes, one device address per write master (plane) of the path, in the order of the [planes](#pixel-output-path). The second buffer queued makes the driver program the ping-pong addresses of a running continuous path.
- input (113 / 124), raw (116 / 125): 4 bytes enqueue, 12 bytes dequeue; ideal raw (117 / 126), RDI 0-2 (118-120 / 127-129): 4 bytes, the buffer address.
- statistics (139-148): 4 bytes, the buffer address. STATS_*_START needs 2 buffers in the queue (result 35 otherwise).

The addresses are device addresses (SMMU): the driver writes them to the write masters without translation.

### Gemini

The DAL still contains the in-line JPEG path of the Qualcomm code (VFE output → Gemini encoder: `GEMINI_CMD_ID_RESET`, `INPUT_CFG`, `OUTPUT_CFG`, `OPERATION_CFG`, `FRAMERATE`, `ENCODE`, set clock), through a Gemini handle (`dword_429B64`). This handle is **never set** in the binary (only cleared, sub_408DB0): the Gemini encoder is a separate driver, [qccamgemini8930.sys](./qccamgemini8930.md), not called by this driver.
- `VFE_CMD_ID_JPEG_ENCODE_CFG` always returns 24.
- If `VFE_CMD_ID_AXI_OUTPUT_CONFIG` enables the JPEG path (output 1 type 2 and byte `0x0D` ≠ 0, `byte_42246A` = 1), sub_40A1B8 logs "gemini device open succeeded" and **calls through the NULL handle** (the "open" call of the original code was removed). The capture and precapture functions (sub_405998, sub_405248, sub_405E84) do the same when `byte_42246A` = 1.
- `VFE_CMD_ID_JPEG_OUTPUT_BUFFER_ENQUEUE` and `VFE_CMD_ID_ZSL_JPEG_OUTPUT_BUFFER_ENQUEUE` (sub_40ADB4, sub_40AE88) call through the NULL handle **unconditionally**: they can't be used.

---

### Interface GUID

Qccamvfe8930 Interface Class GUID (opened by [qccamavs8930.sys](./qccamavs8930.md#camera-device-manager), device ID 0x01091E5B)  
`{3e9c0fdb-cef9-4c4a-8e85-36e4a82eb80f}`

### Other GUID

PEP power control code (`PoFxPowerControl`)  
`{3404daac-8e2c-41e4-8458-3158e5ad442b}`
