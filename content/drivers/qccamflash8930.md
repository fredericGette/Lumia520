## Qccamflash8930.sys

Camera Flash Driver ("FlashKMD", "camflashdrv" version 1.1.2.21).  
It's the flash driver of the Nokia camera stack. It's a KMDF driver that exposes the flash device interface used by [qccamavs8930.sys](./qccamavs8930.md#camera-device-manager), and it drives the flash hardware over I2C and GPIO through the camera platform driver [qccamplatform8930.sys](./qccamplatform8930.md) (interface `{8d73ce35-93cf-4795-8db9-40bbe130d859}`, "CameraPlatformInit").  
The code base is shared with other Nokia phones and supports 3 flash modules, detected at run time: "Hakkinen" and "Prost" (white LED flash) and "Mansell" (xenon flash: capacitor charging, "Mansell TOF"). It also reads an RGBC (ambient light colour) sensor, keeps a flash heat-load counter with forced cooldown, and reads the module calibration ("DFC") files.  
The Lumia 520 has no camera flash, so on this phone the I2C identification is expected to fail ("I2C identification of flash HW failed at 0x%x") and the flash commands to return "not supported".  
PDB path: `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\Driver\fre\qccamflash8930.pdb`.

There's no named device object and no symbolic link: the device is reached through its device interface (see [Interface GUID](#interface-guid)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qccamflash` ?  

The driver doesn't use its `Parameters` key. The values are read with `ZwOpenKey` + `ZwQueryValueKey` from absolute paths (raw data copied to the destination, max 256 bytes):  
| Registry key | Registry value | value | comment |
|--------------|----------------|-------|---------|
| `HKLM\System\CurrentControlSet\Services\qccamavs\Tracing` | TraceEnable | 0 / 1 | Read in `DriverEntry` (`sub_407764`). 1 = register the ETW provider and send the log strings to ETW. Same value as [qccamavs8930.sys](./qccamavs8930.md) |
| `HKLM\Software\OEM\Nokia\Camera\Flash` | Module | 1 or 2 | LED module id, read only by the Hakkinen code (`sub_4026EC` → `sub_406C24` → `sub_40816C`). Any other value → 3. Not found → default kept |

> [!NOTE]
> `Module` is copied into an 8-byte stack variable with the length returned by the registry (up to 256 bytes): a value longer than 8 bytes overwrites the stack of `sub_4026EC`.

The `DbgPrintEx` output of the log function (`sub_4078A0`) is enabled by `dword_415C88`, which is never written: when `TraceEnable` ≠ 1 the log strings are dropped.

GUID of the ETW provider (manifest based, only registered when `TraceEnable` = 1):  
`{62774a98-5c63-43e1-8b13-3c5e8958e414}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{8d73ce35-93cf-4795-8db9-40bbe130d859}` | [qccamplatform8930.sys](./qccamplatform8930.md) | Camera platform driver: power, I2C clock, I2C (QUP of GSBI4) and GPIO. See [Platform IOCTLs](#internal-ioctl-0x2320030x23201f--camera-platform) |

The device is opened in `EvtDevicePrepareHardware` (`sub_407DC4`): first instance returned by `IoGetDeviceInterfaces`, then `IoGetDeviceObjectPointer(GENERIC_READ | GENERIC_WRITE)`. If no instance is found the function still returns success, and every request to the platform driver then fails with `STATUS_UNSUCCESSFUL`.

### Driver initialisation

| Callback | Function | Comment |
|----------|----------|---------|
| `EvtDriverDeviceAdd` | sub_417008 | Device context `DEVICE_CONTEXT`, request context `REQUEST_CONTEXT`, `WdfDeviceCreateDeviceInterface` `{d2ff3f74-880f-4858-841c-fb0bc634676c}`, default queue (`sub_41736C`, sequential, `QUEUE_CONTEXT`) with only `EvtIoInternalDeviceControl` |
| `EvtDevicePrepareHardware` | 0x4171D0 | Only counts the resources (none used). PoFx registration (`sub_401058`), opens the platform driver, then `CameraFlashDevice_WhiteLED_Open` (`sub_40153C`) |
| `EvtDeviceReleaseHardware` | 0x4172DC | Shutdown of the flash object (`sub_401A8C`), dereferences the platform driver, `PoFxUnregisterDevice` |
| `EvtDeviceSelfManagedIoInit` / `Restart` | 0x401008 | Starts the default queue |
| `EvtDeviceSelfManagedIoSuspend` | 0x417180 | Stops the default queue |

`CameraFlashDevice_WhiteLED_Open` allocates the flash object (40 bytes, tag `qcc `): `+0x00` dispatch function (`sub_4015BC`), `+0x04` close (`sub_401A8C`), `+0x08` stub returning 20 (`sub_401B14`). Then `CameraFlashDriver_WhiteLED_Initialize` (`sub_401B20`):
1. Powers the flash on through the platform driver (IOCTL 0x23201B then 0x232003), sends IOCTL 0x232013 with 400.
2. Reads register 0x00 of the I2C device 0x50, then of 0x60 (2 attempts each).
3. The low nibble of the value selects the module and its function table:

| Id | Module | Source | Code | DFC default id |
|----|--------|--------|------|----------------|
| 2 | Mansell (xenon) | `mansell.c` | 0x4035BC–0x4045F0 | `12042D01` |
| 4 | Prost (LED, sub-modules "Mayfly" and "Sunkka") | `prost.c` | 0x4045F4–0x405C30 | `04000F00` |
| 5 | Hakkinen (LED) | `hakkinen.c` | 0x4026EC–0x4035B8 | `15010100` |
| other / no answer | — | — | — | — |

4. Calls the init function of the module, then powers the flash off (IOCTL 0x232007 then 0x23201F).

The flash object is created even when the identification fails: it returns success in all the cases.

### Power management

The driver registers itself to PoFx (`PoFxRegisterDevice`, `sub_401058`), 1 component:  
| Field | Value |
|-------|-------|
| Component GUID | `{ffffffff-ffff-ffff-ffff-ffffffffffff}` (`dword_415CE0`, never written) |
| IdleStateCount | 2 |
| DeviceIdleState | 1 |
| F0 | TransitionLatency 0, ResidencyRequirement 0, NominalPower 500 |
| F1 | TransitionLatency 2, ResidencyRequirement 5, NominalPower 50 |

The callbacks (`sub_40123C`, `sub_401280`, `sub_4012B8`, `sub_4012E4`, `sub_40131C`, `sub_401358`) only log and complete the PoFx notification. Despite the log strings ("Called due to IOCTL"), registration is done in `EvtDevicePrepareHardware`.

### Heat load

`sub_40680C` keeps a flash heat-load counter (100 ns units, decreasing with the elapsed time read by `sub_4074AC`):
- Each flash adds its duration ("load"): Hakkinen 1000 or 420 ms, Prost 420 ms with a 3500 ms "limit".
- Load > limit + 800 ms → "Cooldown safety mechanism triggered": 1600 ms are added and the flash is blocked.
- After a main flash, load > limit → "Flash will be blocked after main flash".
- While the cooldown is active, the flash requests fail ("Forced cooldown is active", "cooldown is active").

### DFC files

The DFC (module calibration data) is read by the "Get DFC" command (`sub_406A30`, `sub_407528`). The file name is an id built from the NVM / LED info of the module (`populate_id_string`), or the module's default id when that fails:  
| Order | Path |
|-------|------|
| 1 | `\DosDevices\C:\DPP\Nokia\DFC\<id>.dfc` |
| 2 | `\DosDevices\C:\Windows\System32\<id>.dfc` |

Each file is read with a single 4096-byte `ZwReadFile`. File 2 is read when file 1 fails or is too big, and the dates of the 2 files are compared to keep the newest one ?. Header:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 01-02 | ? | Size, must be ≤ 4096 |
| 08-0B | ? | Date ("DFC 1, date: %d/%d/%d") |

[qccamavs8930.sys](./qccamavs8930.md#files) stores the result as `FlashSensor.DFC` in `dfsmap.bin`.

### RGBC sensor

The RGBC sensor is read at I2C address 0x52 (`rgbc.c`, 0x405C38–0x406500): register 0x92 must return 0x1D (self test, command 26). The status has clear, red, green, blue (16 bits each), exposure, gain, gain/exposure level and thresholds, adjusted automatically ("+++ exposure & gain level +++"). It's returned with the [SetFlashResults](#command-16-setflashresults) command.

---

### internal IOCTL 0x2323FF…0x232467 — flash control

These internal IOCTLs are processed by Qccamflash8930.sys (`EvtWdfIoQueueIoInternalDeviceControl`, 0x401410). They are sent by [qccamavs8930.sys](./qccamavs8930.md#internal-ioctl-0x2323ff0x232653--camera-device-control).

The command number is `n = Function - 0x8FF`, IOCTL = `((0x8FF + n) << 2) | 0x230003`. The code isn't checked: any internal IOCTL is decoded this way.

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x8FF + n |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Flash command `n` | depends on `n` | 16 |

Inputbuffer: the parameters of command `n`, passed as is with its length.

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the response buffer |
| 04-07 | ? | Size of the response buffer |
| 08-0B | ? | Pointer to a ULONG receiving the size of the response |
| 0C-0F | 00 00 00 00 | Camera result written by the driver |

The request is always completed with `STATUS_SUCCESS`; the result of the command is in bytes 0C-0F.  
**The request is never completed** when the output buffer is missing or when the flash object doesn't exist (`CameraFlashDevice_WhiteLED_Open` failed).

Camera results:  
| Value | Meaning |
|-------|---------|
| 0 | Success |
| 1 | Failure |
| 2 | Memory allocation failed |
| 14 | Wrong buffer size |
| 20 | Not supported (unknown command, or no function for the detected module) |
| 29 | Invalid parameter (NULL buffer, input length without buffer, response size without size pointer…) |
| 39 | No flash device identified |

Commands (`sub_4015BC`):  
| n | IOCTL | Function | Input | Response | Comment |
|---|-------|----------|-------|----------|---------|
| 0 | 0x2323FF | Power_On | — | — | Platform power on (0x23201B, 0x232003) if not on, IOCTL 0x232013 (400), module event 1 |
| 1 | 0x232403 | Power_Off | — | — | Module event 2, platform power off (0x232007, 0x23201F), frees the DFC buffer |
| 2 | 0x232407 | LightOutputStart | — | — | Video light (torch) at 100 % |
| 3 | 0x23240B | LightOutputStop | — | — | Video light at 0 % |
| 4 | 0x23240F | Reset | — | — | Same as Power_Off |
| 5 | 0x232413 | Get_Info_DeviceType | — | 4 | 2 if a module was identified. Else 1 and result 39 |
| 6, 8 | 0x232417, 0x23241F | ? | — | 4 | Always 3 |
| 10 | 0x232427 | Config_LEDOutputMode | 4 | 4 | Only checks the sizes: no-op |
| 14 | 0x232437 | GetDFCData | — | 8 | See [Command 14](#command-14-15-getdfcdata-getnvm) |
| 15 | 0x23243B | GetNvm | — | 8 | Prost only. See [Command 15](#command-14-15-getdfcdata-getnvm) |
| 16 | 0x23243F | SetFlashResults | 15 | 25 | See [Command 16](#command-16-setflashresults) |
| 17 | 0x232443 | GetFlashDriverInfo | — | 8 | 2 ULONGs from the module "get status" function (type 0) |
| 18 | 0x232447 | EnterTestMode | yes | yes | Module test mode (e.g. torch) |
| 19 | 0x23244B | GetTestResults | — | ≥ 7 | hw_fault_1 (byte 2), hw_fault_2 (byte 3), misc_fault (byte 6) |
| 20 | 0x23244F | SelftestIF | — | ≥ 7 | hw_design_info (byte 0), hw_version (byte 1), misc_fault (byte 6) |
| 22 | 0x232457 | SelftestLEDFlash | — | yes | Mansell: charge test ("Mansell selftest passed") |
| 24 | 0x23245F | SelftestTorch | — | yes | |
| 25 | 0x232463 | SelftestTxMask | — | yes | Hakkinen and Prost only |
| 26 | 0x232467 | SelftestRgbcIf | — | ≥ 2 | Byte 0: RGBC id (0x1D expected), byte 1: 2 = I2C failed, 1 = wrong id. Then the RGBC misc data (`sub_4060D0`) |
| other | | | | | Result 20 |

These match the camera diagnostics of qccamavs8930.sys (`KSMETHOD_FLASH_INFORMATION`, `FLASH_IF_TEST`, `FLASH_LEDS_TEST`, `FLASH_TORCH_TEST`, …).

#### Command 14, 15 GetDFCData, GetNvm

Response:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to a kernel buffer (NonPagedPoolNx, tag `qcc `) holding the data |
| 04-07 | ? | Size of the data |

The driver returns a pointer to its own pool buffer (4096 bytes for the DFC). The DFC buffer is freed on power off, the NVM buffer is cached until the shutdown: kernel-mode callers only.

#### Command 16 SetFlashResults

Sets the flash state for the next frame (`sub_4020EC`).

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | State: 0 = off, 1 = flash prewarning, 2 = preflash, 3 = main flash |
| 04 | ? | Power (%), signed. Must be ≤ 100 |
| 08-0B | ? | Length (flash duration) |
| 0C | ? | Mode (1 = ?) |
| 0D | ? | AF assist light: 1 = on (100 %), 0 = off |
| 0E | ? | Preflash type: 1 or other |

Outputbuffer (response):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | State applied |
| 04 | ? | Power applied (updated from the module status for states 0 and 1) |
| 08-0B | ? | Length |
| 0C-0E | ? | Mode, AF, preflash type |
| 10-11 | ? | RGBC clear |
| 12-13 | ? | RGBC red |
| 14-15 | ? | RGBC green |
| 16-17 | ? | RGBC blue |
| 18 | ? | RGBC data available |

---

### internal IOCTL 0x232003…0x23201F — camera platform

These internal IOCTLs are sent by Qccamflash8930.sys (`sub_407F8C`) to the camera platform driver [qccamplatform8930.sys](./qccamplatform8930.md) (interface `{8d73ce35-93cf-4795-8db9-40bbe130d859}`). Synchronous `IoBuildDeviceIoControlRequest(InternalDeviceIoControl = TRUE)`, except the I2C write at DISPATCH_LEVEL which is sent as an asynchronous `IRP_MJ_DEVICE_CONTROL` (`IoBuildAsynchronousFsdRequest`, completion `sub_407F10`). At that level the write fails: qccamplatform8930.sys only handles internal IOCTLs, so KMDF completes the `IRP_MJ_DEVICE_CONTROL` with `STATUS_INVALID_DEVICE_REQUEST`. See [the platform side](./qccamplatform8930.md#internal-ioctl-0x2320030x232023--camera-platform) for the handling of each code.

| IOCTL | Device | Function | Access | Method | InputBuffer size | OutputBuffer Size | Function |
|-------|--------|----------|--------|--------|------------------|-------------------|----------|
| 0x232003 | 0x23 | 0x800 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 0 | Power on (power count +1, QUP init at the first one), after 0x23201B (`sub_4080A4`) |
| 0x232007 | 0x23 | 0x801 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 0 | Power off (power count −1), before 0x23201F (`sub_4080F4`) |
| 0x23200B | 0x23 | 0x802 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 36 | I2C read (`sub_408138`) |
| 0x23200F | 0x23 | 0x803 | FILE_ANY_ACCESS | METHOD_NEITHER | 36 | 0 | I2C write (`sub_4071FC`) |
| 0x232013 | 0x23 | 0x804 | FILE_ANY_ACCESS | METHOD_NEITHER | 4 | 0 | I2C clock in kHz, sent at power on with 400. Only 100 and 400 are accepted |
| 0x232017 | 0x23 | 0x805 | FILE_ANY_ACCESS | METHOD_NEITHER | 8 | 0 | GPIO (`sub_407034`) |
| 0x23201B | 0x23 | 0x806 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 0 | Power on, step 1: PoFx component of `\_SB.CAMP` active |
| 0x23201F | 0x23 | 0x807 | FILE_ANY_ACCESS | METHOD_NEITHER | 0 | 0 | Power off, step 2: PoFx component idle |

0x23200F is the code that qccamavs8930.sys would use for [Mobicat register access](./qccamavs8930.md#internal-ioctl-0x23200f--mobicat-register-access).

I2C transfer (input of 0x23200F, output of 0x23200B):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Not used |
| 04 | 50 | 8-bit I2C slave address (e.g. 0x50 / 0x60 flash, 0x52 RGBC) |
| 08-0B | 04 00 00 00 | Flags: bit 1 clear = 8-bit register (bit 2 isn't used by the platform driver). See [flags](./qccamplatform8930.md#i2c-transfer) |
| 0C-0F | ? | Not used |
| 10-13 | ? | Pointer to the data byte |
| 14-15 | 00 00 | Register |
| 16-17 | 01 00 | Number of bytes |
| 18-23 | 00 … | Not used by 0x23200B / 0x23200F |

GPIO (input of 0x232017):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | GPIO id: index of the `GpioIo` resource of `\_SB.CAMP` |
| 04 | 00 / 01 | State (inverted: request 0 → 1, 1 → 0), written to the pin as is |

`\_SB.CAMP` has only 2 `GpioIo` resources: id 0 = GPIO 107, id 1 = GPIO 76. With id 2 the platform driver opens the Resource Hub with an empty connection id: the write fails, and the IOCTL still returns `STATUS_SUCCESS` (see [GPIO](./qccamplatform8930.md#gpio)).

---

### Interface GUID

Flash interface (opened by qccamavs8930.sys)  
`{d2ff3f74-880f-4858-841c-fb0bc634676c}`

### Other GUID

Camera platform interface (I2C / GPIO / power), [qccamplatform8930.sys](./qccamplatform8930.md)  
`{8d73ce35-93cf-4795-8db9-40bbe130d859}`
