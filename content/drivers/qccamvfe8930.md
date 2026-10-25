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
| Power framework (PEP) | [qcpep8930.sys](./qcpep8930.md) ? | `PoFxPowerControl`, VFE clock P-state, see [Power management](#power-management) |

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
Hardware versions known by the code: 0x30408 and 0x3040F (RDI interfaces and 3D roll-off are only supported with these versions, otherwise "isn't supported in VFE HW Version").

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

Name = `VFE_CMD_ID_<name>` (table of names at `.data:0x0041D1F0`, 80 bytes per entry). Sizes in bytes, exact values checked by the dispatcher; "—" = not checked / not used.  
| n | IOCTL | Name | Input size | Response size | Function |
|---|-------|------|------------|---------------|----------|
| 1 | 0x232403 | POWER_ON | — | — | `VFEDeviceActivate`, ISPIF power on |
| 2 | 0x232407 | POWER_OFF | — | — | ISPIF reset, ISPIF power off, `VFEDeviceDeactivate` |
| 3 | 0x23240B | RESET | — | — | ISPIF reset, VFE reset (sub_406D08) |
| 4 | 0x23240F | START | 4 | — | Clock request, ISPIF start, VFE start (sub_40507C) |
| 5 | 0x232413 | SEND_SMMU_IMEM_ADDR_INFO | 8 | — | IMEM addresses: virtual, physical ("Invalid smmu imem address info") |
| 6 | 0x232417 | TEST_GEN_START | 56 | — | Test pattern generator (sub_408FA4) |
| 7 | 0x23241B | OPERATION_CONFIG | 60 | — | sub_404C74: output path types (output 1-3, CAMIF raw, ideal raw, RDI 0-2) |
| 8 | 0x23241F | AXI_OUTPUT_CONFIG | 260 | — | sub_40A1B8: write masters, output sizes. Byte `0x0D` ≠ 0 selects the in-line JPEG path, see [Gemini](#gemini) |
| 9 | 0x232423 | CAMIF_CONFIG | 60 | — | sub_4091C4 |
| 10 | 0x232427 | CAMIF3_2_CONFIG | 64 | — | sub_4091C4 |
| 11 | 0x23242B | ISPIF_CONFIG | 48 | — | sub_40931C: CIDs of the PIX / RDI interfaces |
| 12 | 0x23242F | AXI_INPUT_CONFIG | 76 | — | sub_40AB04: offline (memory) input |
| 13 | 0x232433 | BLACK_LEVEL_CONFIG | 10 | — | |
| 14 | 0x232437 | LINEARIZATION_CONFIG | 292 | — | |
| 15 | 0x23243B | ROLL_OFF_CONFIG | 1788 | — | sub_40B190 |
| 16 | 0x23243F | ROLL_OFF_3D_CONFIG | 2248 | — | HW 0x30408 only |
| 17 | 0x232443 | DEMUX_CHANNEL_GAIN_CONFIG | 8 | — | |
| 18 | 0x232447 | DEMOSAIC_CONFIG | 2 | — | |
| 19 | 0x23244B | DEMOSAIC_ABF_CONFIG | 178 | — | |
| 20 | 0x23244F | DEMOSAIC_BPC_CONFIG | 18 | — | |
| 21 | 0x232453 | DEMOSAICV3_CONFIG | 128 | — | |
| 22 | 0x232457 | DEMOSAICV3_ABCC_CONFIG | 8200 | — | |
| 23 | 0x23245B | DEMOSAICV3_DBCC_CONFIG | 22 | — | |
| 24 | 0x23245F | DEMOSAICV3_DBPC_CONFIG | 22 | — | |
| 25 | 0x232463 | FOV_CROP_CONFIG | 12 | — | |
| 26 | 0x232467 | MAIN_SCALER_CONFIG | 44 | — | |
| 27 | 0x23246B | WHITE_BALANCE_CONFIG | 8 | — | |
| 28 | 0x23246F | COLOR_CORRECTION_CONFIG | 32 | — | |
| 29 | 0x232473 | RGB_GAMMA_CONFIG | 136 | — | |
| 30 | 0x232477 | LA_CONFIG | 130 | — | Luma adaptation |
| 31 | 0x23247B | CHROMA_ENHAN_CONFIG | 30 | — | |
| 32 | 0x23247F | CHROMA_SUPPRESSION_CONFIG | 13 | — | |
| 33 | 0x232483 | CLF_CONFIG | 76 | — | |
| 34 | 0x232487 | MCE_CONFIG | 50 | — | |
| 35 | 0x23248B | SKIN_ENHAN_CONFIG | 144 | — | |
| 36 | 0x23248F | ASF_CONFIG | 64 | — | |
| 37 | 0x232493 | SCALER2Y_CONFIG | 36 | — | |
| 38 | 0x232497 | SCALER2CbCr_CONFIG | 36 | — | |
| 39 | 0x23249B | CHROMA_SUBSAMPLE_CONFIG | 16 | — | |
| 40 | 0x23249F | OUTPUT_CLAMP_CONFIG | 6 | — | |
| 41 | 0x2324A3 | FRAME_SKIP_CONFIG | 16 | — | |
| 42 | 0x2324A7 | RDI_CONFIG | 3 | — | |
| 46 | 0x2324B7 | UPDATE | — | — | Applies the pending updates (reg update) |
| 47 | 0x2324BB | BLACK_LEVEL_UPDATE | 10 | — | |
| 48 | 0x2324BF | LINEARIZATION_UPDATE | 292 | — | |
| 49 | 0x2324C3 | ROLL_OFF_UPDATE | 4 | — | |
| 50 | 0x2324C7 | ROLL_OFF_3D_UPDATE | 2216 | — | |
| 51 | 0x2324CB | LENS_ROLL_OFF_TABLE_UPDATE | 1768 | — | Table written by DMI at the next interrupt |
| 52-74 | 0x2324CF-0x232527 | `<block>_UPDATE` | same as the `_CONFIG` command, except: DEMOSAICV3_UPDATE 124, ASF_UPDATE 48, FRAME_SKIP_UPDATE 8, CAMIF_FRAME_UPDATE 4 | — | |
| 76 | 0x23252F | ENABLE_OUTPUT | 36 | — | sub_410B68 |
| 77 | 0x232533 | DISABLE_OUTPUT | 3 | — | sub_410ADC |
| 78 | 0x232537 | STATS_AF_UPDATE | 24 | — | |
| 79 | 0x23253B | STATS_AE_UPDATE | 12 | — | |
| 80 | 0x23253F | STATS_AWB_UPDATE | 32 | — | |
| 81 | 0x232543 | STATS_RS_UPDATE | 12 | — | |
| 82 | 0x232547 | STATS_CS_UPDATE | 12 | — | |
| 83 | 0x23254B | STATS_SKIN_UPDATE | 18 | — | |
| 84 | 0x23254F | STATS_IHIST_UPDATE | 12 | — | |
| 85 | 0x232553 | STATS_BF_UPDATE | 28 | — | |
| 86 | 0x232557 | STATS_BG_UPDATE | 18 | — | |
| 87 | 0x23255B | STATS_BHIST_UPDATE | 8 | — | |
| 92 | 0x23256F | SYNC_TIMER_SETTING | 20 | — | sub_4115BC |
| 95 | 0x23257B | GET_AXI_OUTPUT_INFO | — | 8 | Always `10 00 00 00 01 00 00 00` |
| 96 | 0x23257F | GET_DROPPED_FRAME_COUNTS | — | 16 | |
| 97 | 0x232583 | GET_DEMOSAIC_INFO | — | 8 | Always `00 00 00 00 01 00 00 00` |
| 98 | 0x232587 | GET_HW_VERSION | — | 12 | sub_4090BC |
| 99 | 0x23258B | GET_SCALER_INFO | — | 48 | sub_40911C |
| 100 | 0x23258F | GET_NUM_OF_WM | 4 | 4 | Number of write masters |
| 101 | 0x232593 | SET_BRACKETING_CALLBACK | 4 | — | |
| 102 | 0x232597 | CAPTURE | 8 | — | sub_405998 (also ZSL / multishot) |
| 103 | 0x23259B | START_OFFLINE_PROCESS | 8 | — | sub_405E84 |
| 104 | 0x23259F | START_PRECAPTURE | 4 | — | sub_405248 (ZSL) |
| 105 | 0x2325A3 | STOP_PRECAPTURE | — | — | sub_406108 |
| 107 | 0x2325AB | SET_INTERFACE_DATARATE | 12 | — | sub_404B24: interface (0 = PIX, 1 = RDI), RDI index (1-2), rate. See [Power management](#power-management) |
| 109 | 0x2325B3 | STOP | — | — | ISPIF stop, VFE stop, waits for the async event |
| 110-112 | 0x2325B7-0x2325BF | OUTPUT1/2/3_BUFFER_ENQUEUE | 12 | — | |
| 113 | 0x2325C3 | INPUT_BUFFER_ENQUEUE | 4 | — | |
| 114 | 0x2325C7 | JPEG_OUTPUT_BUFFER_ENQUEUE | 12 | — | See [Gemini](#gemini) |
| 115 | 0x2325CB | ZSL_JPEG_OUTPUT_BUFFER_ENQUEUE | 12 | — | See [Gemini](#gemini) |
| 116-120 | 0x2325CF-0x2325DF | RAW / IDEAL_RAW / RDI0-2 _BUFFER_ENQUEUE | 4 | — | |
| 121-125 | 0x2325E3-0x2325F3 | OUTPUT1/2/3, INPUT, RAW_OUTPUT _BUFFER_DEQUEUE | — | 12 | |
| 126-129 | 0x2325F7-0x232603 | IDEAL_RAW, RDI0-2 _OUTPUT_BUFFER_DEQUEUE | — | 4 | |
| 130-138 | 0x232607-0x232627 | `<queue>_FLUSH_BUFFER_QUEUE` | — | — | sub_4148F0 |
| 139-148 | 0x23262B-0x23264F | STATS_AF/AE/AWB/RS/CS/SKIN/IHIST/BF/BG/BHIST_ENQUEUE | 4 | — | Statistics buffer |
| 149 | 0x232653 | START_CAPTURE_ACK_REQUEST | — | — | sub_402D64 |
| 151 | 0x23265B | JPEG_ENCODE_CFG | 68 | — | See [Gemini](#gemini) |
| 153-172 | 0x232663-0x2326AF | STATS_\<type\>_START / STOP | START: AF 24, AE 12, AWB 32, RS 12, CS 12, SKIN 20, IHIST 12, BF 30, BG 20, BHIST 10; STOP: — | — | |

The "dummy" ids (0, 43-45, 88-91, 94, 108, 150, 152, 173) and 75 (`CAMIF3_2_FRAME_UPDATE`), 93 (`ASYNC_TIMER_SETTING`), 106 (`FAST_AF_FRAME_DROP`) return 20.

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
