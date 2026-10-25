## Qccamfrontsensor8930.sys

Camera Front Sensor Driver ("FrontSensorKMD").  
It's the front camera (FFC) sensor driver of the Nokia camera stack. It's a KMDF driver that exposes the front sensor device interface used by [qccamavs8930.sys](./qccamavs8930.md#camera-device-manager), and it contains a generic SMIA++ sensor driver ("SMIApp_Ver13", sources `CameraSensorDriver_SMIApp.c`, `SMIApp.c`, `SensorPlatform.c`, `CameraOSServices.c`): power, I2C and clocks go through the camera platform driver (interface `{8d73ce35-93cf-4795-8db9-40bbe130d859}`, "CameraPlatformInit"), and the MIPI CSI receiver (CSID + CSIPHY) is programmed directly through 2 memory resources.  
The code base is shared with the back sensor driver: the same binary code handles the RFC (CSI 0) and the FFC (CSI 1). This driver selects CSI 1 at start ("Config Interface" = 1).  
The Lumia 520 has no front camera, so on this phone the SMIA++ detection is expected to fail ("cam_drv_on CSID = %u failed") and the power on command to return 1.  
PDB path: `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\Driver\fre\qccamfrontsensor8930.pdb`.

There's no named device object and no symbolic link: the device is reached through its device interface (see [Interface GUID](#interface-guid)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qccamfrontsensor` ?  

The driver doesn't use its `Parameters` key. The values are read with `ZwOpenKey` + `ZwQueryValueKey` from absolute paths (helpers `sub_401920` and `sub_4151A0`, raw data copied to the destination, max 256 bytes):  
| Registry key | Registry value | value | comment |
|--------------|----------------|-------|---------|
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | TraceEnable | 0 / 1 | Read in `DriverEntry` (`sub_401DF4`). 1 = register the ETW provider and send the log strings to ETW. Same value as [qccamavs8930.sys](./qccamavs8930.md) |
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | CoreDbgEnable | ? | Only read when `TraceEnable` = 1 (`byte_44AFC0`) |
| `HKLM\Software\OEM\Nokia\Camera\FFC\CameraClocks` | CamExtClkHz | 9600000 (default) | Sensor external clock (Hz). Stored as `ext_clock_freq_x100` = value / 10000 (default 960) |
| `HKLM\Software\OEM\Nokia\Camera\FFC\CameraClocks` | MaxCsiFreqMhz | 650 (default) | Stored as `requested_link_bit_rate_mbps` = 2 × value (default 1300) |
| `HKLM\Software\OEM\Nokia\Camera\FFC\Rotation` | FlipMirror | 0 (default) | 1 = rotation flag 3 (flip + mirror) |
| `HKLM\Software\OEM\Nokia\Camera\RFC\…` | same values | | Read instead of the `FFC` ones when the CSI interface is 0 (never the case in this driver) |
| `HKLM\Software\Microsoft\ManufacturingOS` | ManufacturingMode | ? | Read in `sub_4086EC`, but the variable is cleared just after the read: no effect ? |

The rotation flag is also XOR-ed with 3 for the sensor models 0x03BB and 0x07A3 when the revision byte is 1 ("camera model specific rotation applied").  
The `DbgPrintEx` output of the log function (`sub_401A48`) is enabled by `dword_443FBC`, which is never written: when `TraceEnable` ≠ 1 the log strings are dropped.

GUID of the ETW provider (manifest based, only registered when `TraceEnable` = 1, same provider as [qccamflash8930.sys](./qccamflash8930.md)):  
`{62774a98-5c63-43e1-8b13-3c5e8958e414}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{8d73ce35-93cf-4795-8db9-40bbe130d859}` | [qccamplatform8930.sys](./qccamplatform8930.md) | Camera platform driver: power, I2C clock, I2C (QUP of GSBI4). See [Platform IOCTLs](#internal-ioctl-0x2320030x23201f--camera-platform) |

The device is opened in `EvtDevicePrepareHardware` (`sub_4023F0`): first instance returned by `IoGetDeviceInterfaces`, then `IoGetDeviceObjectPointer(GENERIC_READ | GENERIC_WRITE)`. If no instance is found the function still returns success, and every request to the platform driver then fails with `STATUS_UNSUCCESSFUL`.

### Driver initialisation

| Callback | Function | Comment |
|----------|----------|---------|
| `EvtDriverDeviceAdd` | 0x44D008 → sub_44D038 | Device context `DEVICE_CONTEXT`, request context `REQUEST_CONTEXT`, `WdfDeviceCreateDeviceInterface` `{f27170b8-7b88-4f4a-b505-1d065616aadc}`, default queue (`sub_44D460`, sequential, `QUEUE_CONTEXT`) with `EvtIoDeviceControl` and `EvtIoInternalDeviceControl` |
| `EvtDevicePrepareHardware` | 0x44D234 | Maps the 2 memory resources, PoFx registration (`sub_401058`), opens the platform driver, opens the sensor object (`sub_4033D8`), then sends the commands 62 "Config Interface" (1) and 63 "Config Orientation" (0) to it |
| `EvtDeviceReleaseHardware` | 0x44D3F4 | Closes the sensor object, dereferences the platform driver, `PoFxUnregisterDevice` |
| `EvtDeviceSelfManagedIoInit` / `Restart` | 0x401008 | Starts the default queue |
| `EvtDeviceSelfManagedIoSuspend` | 0x44D1E4 | Stops the default queue |

`EvtDevicePrepareHardware` always returns `STATUS_SUCCESS`, except when the PoFx registration fails.

The sensor object (1364 bytes, tag `qcc0`, `sub_403430`): `+0x00` dispatch function (`sub_403504`), `+0x04` close (`sub_403EC4`), `+0x08` set 2 values (`sub_403EF0`), then the sensor information returned by the commands. A second block of 0x2A9F8 bytes (`dword_42A744`) holds the SMIA++ context (sensor modes, NVM, CDCC, function table at `+0x2A968`). Only one sensor object can be open ("already open" → 5).

### Memory resources

| Index | Variable | Block | Comment |
|-------|----------|-------|---------|
| 0 | `dword_44AFD8` | CSID 1 ? | MIPI CSI decoder. `0x04800400` in the Linux MSM8960 / MSM8930 sources ? |
| 1 | `dword_44AFD4` | CSIPHY 1 ? | MIPI CSI PHY. `0x04801000` in the Linux sources ? |

Both are mapped with `MmMapIoSpace(MmNonCached)`. The variables of CSI 0 (`dword_44AFDC`, `dword_44AFE0`) are never written: only CSI 1 works.  
Registers used:  
| Block | Offset | Access | Comment |
|-------|--------|--------|---------|
| CSID | 0x08 | write 0xFFFFFFFF, wait 1 µs, write 1 | Reset, at stream stop (`sub_4026D0`). 0x7001 written by command 64 |
| CSID | 0x5C | write 0xFFFFFFFF | IRQ clear ?, at stream start (`sub_4031DC`) |
| CSID | 0x64–0x94 | read | Status saved at stream start. 0x8C, 0x90, 0x94 returned by command 64 |
| CSIPHY | 0x140 | write 1, wait 1 µs, write 0 | Global reset ?, at stream stop (`sub_402788`) |
| CSIPHY | 0x164 | write 1 | At stream start |
| CSIPHY | 0x180–0x19C | read | Status saved at stream start |

The CSI configuration (lanes, settle count, DDR clock, virtual channels: "MIPICsiProp…") is computed by command 45 and written by `sub_402974`.

### Power management

The driver registers itself to PoFx (`PoFxRegisterDevice`, `sub_401058`), 1 component, then waits 10 ms before `PoFxStartDevicePowerManagement`:  
| Field | Value |
|-------|-------|
| Component GUID | `{ffffffff-ffff-ffff-ffff-ffffffffffff}` (`dword_44B200`, never written) |
| IdleStateCount | 2 |
| DeviceIdleState | 1 |
| F0 | TransitionLatency 0, ResidencyRequirement 0, NominalPower 500 |
| F1 | TransitionLatency 0, ResidencyRequirement 0, NominalPower 50 |

The component is activated at power on (`SensorDeviceActivate`, `sub_415064`: IOCTL 0x23201B then `PoFxActivateComponent`) and idled at power off (`SensorDeviceDeactivate`, `sub_4150DC`: `PoFxIdleComponent`, wait up to 2.5 s for the idle state callback F1 ("FFC power down callback wasn't received"), then IOCTL 0x23201F). The other callbacks only log and complete the notification.

### Sensor detection

`cam_drv_on` (`sub_408170`) reads the registry values above and runs the SMIA++ detection. On success it logs "cam_drv_on found SMIA++ CSID = %u, Camera ID = %s, Serial Number = %s, SensorModel = %04x".  
The sensor is read at the I2C address 0x20 (8-bit, = 0x10 in 7-bit: SMIA default address). Command 68 reads the SMIA registers 0x0000 (model id, 16 bits), 0x0002, 0x0010 and 0x0003.  
Then `sub_4086EC` reads the CDCC data (sensor configuration) from a file, applies it (`cam_drv_config_set`), reads the camera details and the sensor modes (max 80, "Published modes"), and the NVM (`cam_drv_get_parsed_nvm`).

### Files

| Path | Max size | Comment |
|------|----------|---------|
| `\DosDevices\C:\Windows\System32\Drivers\<Camera ID>.dcc` | 51200 bytes | CDCC data, single `ZwReadFile` (`sub_40210C`). `<Camera ID>` = 8-character id returned by the sensor. Cached for 2 sensors (model + revision) |

### Chromatix data

The driver contains a 53816-byte tuning table at `.data:0x41C1D0` (version word 0x0207, then floats: color correction matrix …), returned by commands 5 and 6.

---

### internal IOCTL 0x2323FF…0x232523 — sensor control

These IOCTLs are processed by Qccamfrontsensor8930.sys (`EvtWdfIoQueueIoInternalDeviceControl`, 0x401650). They are sent by [qccamavs8930.sys](./qccamavs8930.md#internal-ioctl-0x2323ff0x232653--camera-device-control).

The command number is `n = Function - 0x8FF` ("SENSOR_CTL_CODE"), IOCTL = `((0x8FF + n) << 2) | 0x230003`. The code isn't checked: any IOCTL is decoded this way.

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x8FF + n |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Sensor command `n` | depends on `n` | 16 |

Inputbuffer: the parameters of command `n`, passed as is with its length.

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the response buffer |
| 04-07 | ? | Size of the response buffer |
| 08-0B | ? | Pointer to a ULONG receiving the size of the response |
| 0C-0F | 00 00 00 00 | Camera result written by the driver |

The request is always completed with `STATUS_SUCCESS`; the result of the command is in bytes 0C-0F. If the sensor object doesn't exist (open failed), the result is 0 (success) and nothing is done.

Camera results:  
| Value | Meaning |
|-------|---------|
| 0 | Success |
| 1 | Failure |
| 2 | Memory allocation failed |
| 5 | Sensor object already open |
| 14 | Wrong buffer size |
| 20 | Not supported (unknown command, cam_drv init failed) |
| 29 | Invalid parameter (NULL buffer, input length without buffer, response buffer without size pointer…) |

Commands (`sub_403504`):  
| n | IOCTL | Function | Input | Response | Comment |
|---|-------|----------|-------|----------|---------|
| 0 | 0x2323FF | Power on | — | — | cam_drv init, `SensorDeviceActivate`, platform power on (0x23201B, 0x232003), IOCTL 0x232013 (400), `cam_drv_on` (detection), CDCC + modes + NVM, CSI context. State 1 |
| 1 | 0x232403 | Power off | — | — | cam_drv off, `SensorDeviceDeactivate`, platform power off (0x232007, 0x23201F). State 4 |
| 2 | 0x232407 | Start stream | — | — | CSI configuration, `CAM_DRV_MODE_STREAMING` (`sub_408DA8`). State 3 |
| 3 | 0x23240B | Stop stream | — | — | `CAM_DRV_MODE_SW_STANDBY` + OIS off (`sub_408E68`), CSID / CSIPHY reset. State 2 |
| 4 | 0x23240F | Reset | — | — | Power off then power on |
| 5 | 0x232413 | Get chromatix | 12 | 53816 | Input `+08` (16 bits) must be 0x0207 |
| 6 | 0x232417 | Get chromatix | 16 | 55000 | Same, but copies 55000 bytes: 1184 bytes after the end of the table |
| 7 | 0x23241B | ? | — | 8 | Object `+0x14`, `+0x18` |
| 8 | 0x23241F | ? | 4 | 4 | 0, 1 → 0; 2 → 1; other → result 20 |
| 10 | 0x232427 | Get sensor capabilities ? | — | 44 | Object `+0x1C` |
| 11 | 0x23242B | Query config | 20 | 56 | "Future Config Desired Resolution width, height, Max frame interval, op mode" (`sub_404664`) |
| 12 | 0x23242F | ? | — | 44 | |
| 13 | 0x232433 | ? | — | 8 | CSI state, CSI interface |
| 14 | 0x232437 | ? | — | 576 | Object `+0x7C` |
| 15–20, 22 | 0x23243B–0x232457 | Get info blocks | — | 32, 12, 12, 16, 76, 56, 24 | Copies of the sensor object (`+0x2BC` … `+0x388`) |
| 23 | 0x23245B | Get sensor modes | 4 | 27124 | Input: op mode mask (1, 2, 4, 8). Up to 20 modes of 1356 bytes (`sub_404178`) |
| 24 | 0x23245F | Find sensor mode | 24 | 1 | `FindSensorMode` (`sub_405394`): HS video (> 32 fps), HQ video (≥ 720p), HS still |
| 25 | 0x232463 | — | 8 | 8 | Only checks the sizes and the value (1, 2, 3): no-op |
| 28 | 0x23246F | Send embedded data | yes | — | `SMIApp_SendEmbeddedData` (`sub_4066A4`) |
| 29 | 0x232473 | Exposure config | 8 | 8 | Gain (8.8 register value), line count (`sub_404768`) |
| 34 | 0x232487 | ? | 16 | 16 | Calls a stub (`sub_4093AC`) and stores the values |
| 45 | 0x2324B3 | Config resolution | yes | yes | `ConfigResolution` and MIPI CSI parameters (`sub_4049B0`) |
| 50 | 0x2324C7 | ? | yes | yes | `sub_4050A4` |
| 51 | 0x2324CB | GetCDCCData | — | 8 | See [Commands 51–53](#commands-5153-getcdccdata-getinfonvmdata-getinforawnvmdata) |
| 52 | 0x2324CF | GetInfoNVMData | — | 8 | |
| 53 | 0x2324D3 | GetInfoRawNVMData | — | 8 | |
| 54 | 0x2324D7 | SetAECResults | 56 | 56 | `SMIApp_UpdateAECResults` (`sub_4060D0`): gains, exposure time, frame rate override for AF, flash (OF / HP / LP) |
| 55 | 0x2324DB | GetLensPosition | — | 4 | `cam_drv_lens_measure_pos` |
| 56 | 0x2324DF | SetLensPosition | 4 | — | `cam_drv_lens_move_to_pos` |
| 57 | 0x2324E3 | GetLensDetails | — | 36 | rest, far end, infinity, hyperfocal, macro, near end |
| 58 | 0x2324E7 | GetSensorSettings | — | 28 | |
| 59 | 0x2324EB | GetSensorDetails | — | 20 | |
| 60 | 0x2324EF | ? | 1 | — | Flag `byte_41C1A9` |
| 61 | 0x2324F3 | ? | 1 | — | Flag in the SMIA++ context |
| 62 | 0x2324F7 | Config interface | 4 | 4 | CSI index, 0 or 1. Set to 1 at start |
| 63 | 0x2324FB | Config orientation | 4 | 4 | 0 to 3. Set to 0 at start |
| 64 | 0x2324FF | Get CSI status | — | 16 | CSID 0x8C, 0x94 (16 bits), 0x90. Byte 12 ≠ 0 → writes 0x7001 to CSID 0x08 |
| 65 | 0x232503 | NVM info / OutputStopPrepare ? | — | 24 | NVM size, checksum (`sub_405594`) |
| 66 | 0x232507 | ? | 8 | 8 | Mode 4–7 + 2 bytes (`sub_405744`) |
| 67 | 0x23250B | Manual exposure ? | 12 | 12 | `+04` exposure time, `+08` gain (8.8) |
| 68 | 0x23250F | Get sensor identity | — | 32 | SMIA registers 0x0000, 0x0002, 0x0010, 0x0003, 16-character serial number, 8-character camera id (`sub_405914`) |
| 69 | 0x232513 | Flash strobe config | 4 | — | "Selected flash strobe length %d us" (`sub_408F88`) |
| 70 | 0x232517 | ? | 8 | 8 | |
| 71 | 0x23251B | CalculateNvmChecksum | — | yes | `sub_4059F4` |
| 72 | 0x23251F | ? | 1 | 1 | Get / set flag `byte_443F23` |
| 73 | 0x232523 | GetExpStartTimeStamp | — | 4 | |
| other | | | | | Result 20 |

#### Commands 51–53 GetCDCCData, GetInfoNVMData, GetInfoRawNVMData

Response:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to a kernel buffer (NonPagedPoolNx) holding the data |
| 04-07 | ? | Size of the data |

The driver returns a pointer to its own pool buffer: kernel-mode callers only. Result 29 when the data isn't available.

---

### IOCTL 0x2323FF…0x232523 — sensor control

The same commands are also accepted as normal IOCTLs (`EvtWdfIoQueueIoDeviceControl`, 0x401478), with the same buffers. The input and output buffers are user buffers (`WdfRequestRetrieveUnsafeUserInputBuffer`, `WdfRequestProbeAndLockUserBufferForRead/Write`). The request is always completed with `STATUS_SUCCESS`.

> [!NOTE]
> Only the 16-byte output buffer is probed: the response pointer and the size pointer inside it are passed to the command as is. A caller that can open the interface can make the driver write to any kernel address.

---

### internal IOCTL 0x232003…0x23201F — camera platform

These internal IOCTLs are sent by Qccamfrontsensor8930.sys (`sub_4025B8`) to the camera platform driver [qccamplatform8930.sys](./qccamplatform8930.md) (interface `{8d73ce35-93cf-4795-8db9-40bbe130d859}`). Synchronous `IoBuildDeviceIoControlRequest(InternalDeviceIoControl = TRUE)`, except the I2C write at DISPATCH_LEVEL which is sent as an asynchronous `IRP_MJ_DEVICE_CONTROL` (`IoBuildAsynchronousFsdRequest`, completion `sub_40253C`). At that level the write fails: qccamplatform8930.sys only handles internal IOCTLs, so KMDF completes the `IRP_MJ_DEVICE_CONTROL` with `STATUS_INVALID_DEVICE_REQUEST`. Same IOCTLs as [qccamflash8930.sys](./qccamflash8930.md#internal-ioctl-0x2320030x23201f--camera-platform), without the GPIO one. See [the platform side](./qccamplatform8930.md#internal-ioctl-0x2320030x232023--camera-platform) for the handling of each code.

| IOCTL | Device | Function | Access | Method | InputBuffer size | OutputBuffer Size | Function |
|-------|--------|----------|--------|--------|------------------|-------------------|----------|
| 0x232003 | 0x23 | 0x800 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 0 | Power on (power count +1, QUP init at the first one), after 0x23201B |
| 0x232007 | 0x23 | 0x801 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 0 | Power off (power count −1), before 0x23201F |
| 0x23200B | 0x23 | 0x802 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 36 | I2C read (`sub_415030`) |
| 0x23200F | 0x23 | 0x803 | FILE_ANY_ACCESS | METHOD_NEITHER | 36 | 0 | I2C write (`sub_415000`) |
| 0x232013 | 0x23 | 0x804 | FILE_ANY_ACCESS | METHOD_NEITHER | 4 | 0 | I2C clock in kHz, sent at power on with 400. Only 100 and 400 are accepted |
| 0x23201B | 0x23 | 0x806 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 0 | Power on, step 1: PoFx component of `\_SB.CAMP` active (also sent by `SensorDeviceActivate`) |
| 0x23201F | 0x23 | 0x807 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 0 | Power off, step 2: PoFx component idle (also sent by `SensorDeviceDeactivate`) |

I2C transfer (input of 0x23200F, output of 0x23200B, `dword_443F70`), retried 3 times:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Not used |
| 04 | 20 | I2C slave address (8-bit, `byte_44B0AE`) |
| 08-0B | 02 00 00 00 | Flags: bit 1 (2) = 16-bit register address. With 4, bit 1 is clear: 8-bit register (bit 2 isn't used). See [flags](./qccamplatform8930.md#i2c-transfer) |
| 0C-0F | ? | Not used |
| 10-13 | ? | Pointer to the data (big-endian 16-bit values are byte-swapped) |
| 14-15 | 00 00 | Register |
| 16-17 | 02 00 | Number of bytes (1 or 2) |
| 18-19 | 01 00 | Not used by 0x23200B / 0x23200F (number of writes for 0x232023) |
| 1A-23 | 00 … | Not used |

---

### Interface GUID

Front sensor interface (opened by qccamavs8930.sys)  
`{f27170b8-7b88-4f4a-b505-1d065616aadc}`

### Other GUID

Camera platform interface (I2C / power), [qccamplatform8930.sys](./qccamplatform8930.md)  
`{8d73ce35-93cf-4795-8db9-40bbe130d859}`
