## Hwnvibradime.sys

Nokia vibrator driver ("Vibra Dime"). It's the vibrator of the Lumia 520.  
It is a client of the Microsoft Hardware Notification class extension `HwNClx` (`hwnclx.sys`, the same framework as `hwnled` for the LEDs): it has no IOCTL of its own. Requests come in as `HWN_HEADER` / `HWN_SETTINGS` buffers through the `ClientSetState` / `ClientGetState` callbacks, and the driver converts them into a drive voltage that it sends to the PMIC vibrator block of [qcpmic8930.sys](./qcpmic8930.md#ioctl-0x801dxxxx--vibrator) with `IOCTL_PM_VIB_CONTROL_REGISTER`. It handles the blink mode (period / duty cycle / cycle count) itself with a WDF timer.  
ACPI device `\_SB.VIB1` (`_HID` `NOKIA_VIBRA_DIME`, `_CID` `ACPINOKIA_VIBRA_DIME`). Its `_CRS` is empty (End tag only): no hardware resource.  
KMDF, PDB path `E:\build_e\subtask\E05A4CC0_98\output\audio\fre\hwnvibradime.pdb`. Pool tag `BIVA`.

There's no device name and no symbolic link created by the driver itself (the device object and interface are managed by `HwNClx`).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\hwnvibradime`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\NOKIA_VIBRA_DIME\0`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\hwnvibradime` (the service key itself, not `Parameters`), read once when the device is initialized (`sub_401594`):  
| Registry value | value | comment |
|----------------|-------|---------|
| AccelerationVoltage | 31 | REG_DWORD, clamped to 31. Stored at `ctx+0xB8` but **never used** |
| DriveVoltage | 24 | REG_DWORD, clamped to 24. Maximum PMIC level (100 mV units, 24 = 2.4 V) used for an intensity of 100% |
| AccelerationLength | 50 | REG_DWORD, clamped to 50. Stored at `ctx+0xBC` but **never used** |

Other registry keys:  
| Registry key | Value | comment |
|--------------|-------|---------|
| `HKLM\Software\Microsoft\ManufacturingOS` | (key existence) | If the key exists, `DriveVoltage` is forced to 31 (3.1 V), overriding the value above (`sub_401670`) |
| `HKLM\Software\OEM\Nokia\Audio\EnhancedRecording\Vibra` | Disable | REG_DWORD. When not 0, requests with an intensity of 100% are refused (`STATUS_UNSUCCESSFUL`) and a running vibration is stopped. The key is watched with `ZwNotifyChangeKey` (work item `sub_4018D8`), so the change is applied immediately. Probably used to avoid vibration noise during audio recording ? |

There's no ETW provider.  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{219397E7-B8D9-4DA6-AF0D-1733612E8299}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC vibrator (`0x801D`). Opened on first use with `IoGetDeviceInterfaces` (`DEVICE_INTERFACE_INCLUDE_NONACTIVE`) + `IoGetDeviceObjectPointer` (`sub_401344`), first symbolic link only |

### HwNClx client

`DriverEntry` (0x407008) creates the WDF driver and calls `HwNRegisterClientDriver` (class `HwNClx` version 1, bound through `WdfVersionBindClass`, 4 imported functions at `.data:0x00404A90`). Registration packet (`HWN_CLIENT_REGISTRATION_PACKET`, Version 1, Size 40, client context size 200 bytes):  
| Callback | Function | Comment |
|----------|----------|---------|
| ClientInitializeDevice | `sub_406078` | Initializes the context, reads the registry, creates the timer (passive level, one-shot) and the wait lock, starts the watch of the `Vibra\Disable` key. State = 1 |
| ClientUnInitializeDevice | `sub_401034` | Closes the `Vibra` key, frees the work item and the IO status block. State = 0 |
| ClientQueryDeviceInformation | `sub_4010C0` | Returns 3 USHORTs `1, 6, 1` (version, size, number of HwN = 1 ?) |
| ClientStartDevice | `sub_4010E0` | State = 2 |
| ClientStopDevice | `sub_401100` | State = 6. The motor is not switched off |
| ClientSetState | `sub_401198` | See [Set state](#set-state) |
| ClientGetState | `sub_401114` | See [Get state](#get-state) |

`EvtDriverDeviceAdd` (0x406008) only calls `HwNProcessAddDevicePreDeviceCreate`, `WdfDeviceCreate` and `HwNProcessAddDevicePostDeviceCreate` with the GUID `{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}` (device interface of the vibrator created by HwNClx ?).  
`EvtDriverUnload` calls `HwNUnregisterClientDriver`.

States (`ctx+0x04`, previous state at `ctx+0x08`):  
| State | Meaning |
|-------|---------|
| 0 | Uninitialized |
| 1 | Initialized |
| 2 | Started |
| 3 | Off |
| 4 | On (continuous) |
| 5 | Blinking |
| 6 | Stopped |

### Set state

Input buffer (`HWN_HEADER` with one `HWN_SETTINGS`, same layout as the buffer sent by [oempanel.sys](./oempanel.md#ioctl-0x228000--hwn-set-state-) to `hwnled`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 30 00 00 00 | Payload size (48) |
| 04-07 | 01 00 00 00 | Version ? |
| 08-0B | 01 00 00 00 | Number of settings. Must be ≤ 1 |
| 0C-0F | 00 00 00 00 | HwN Id |
| 10-13 | 02 00 00 00 | HwN type. Must be 2 (vibrator) |
| 14-17 | e.g. `64 00 00 00` | Intensity in %, 0–100. 99 is rounded up to 100 |
| 18-1B | e.g. `E8 03 00 00` | Period in ms (blink mode) |
| 1C-1F | e.g. `32 00 00 00` | Duty cycle in % (blink mode) |
| 20-23 | e.g. `03 00 00 00` | Cycle count (blink mode). 0 = practically infinite (the counter wraps) |
| 24-27 | | Setting 4, stored only |
| 28-2B | | Setting 5, stored only |
| 2C-2F | 00/01/02 00 00 00 | Mode: 0 = off, 1 = on, 2 = blink |

Any other type, a mode > 2, an intensity > 100 or more than one setting returns `STATUS_UNSUCCESSFUL` (0xC0000001).  
The buffer-length check is inverted: `(length − 12) % (36 × count)` is only tested when the length is 0, so the length is in practice never validated (and a length of 0 with a count of 0 divides by zero).  

Processing:
1. If the watch of the `Vibra` key is not armed yet, arm it and read `Disable`.
2. If the mode is not 0, `Disable` ≠ 0 and the intensity is 100 → `STATUS_UNSUCCESSFUL`.
3. If the current state is 5 (blinking), stop the timer and send level 0.
4. Mode 0: send level 0, state 3.  
   Mode 1: send the level computed from the intensity, state 4. There's no timeout: the motor runs until the next request.  
   Mode 2 (`sub_40171C`): on time = period × duty / 100, off time = period − on time, send the level, start the timer with the on time, state 5. The timer callback (`sub_401498`) alternates level 0 / level, restarting itself with the off / on time, and decrements the cycle count at the end of each on phase; at 0 the motor stays off (state 3).

Level sent to the PMIC (`sub_40186C`): `level = (DriveVoltage − 12) × intensity / 100 + 12`, or 0 when the intensity is 0. With the defaults: 1% → 12 (1.2 V), 50% → 18 (1.8 V), 100% → 24 (2.4 V); 31 (3.1 V) at 100% in the manufacturing OS.

### Get state

The output buffer must be larger than 12 bytes and `(length − 12)` a multiple of 36, otherwise `STATUS_INVALID_BUFFER_SIZE` (0xC0000206). It returns 48 bytes: the same layout as [Set state](#set-state), with the last accepted settings. Before the first request: size 48, version 1, count 1, id 0, type 2, settings `0, 0, 0, 0, 0x5555, 0xFFFFFFFF, 0`.

---

### IOCTL 0x801D0FA0 — IOCTL_PM_VIB_CONTROL_REGISTER

This IOCTL is sent by Hwnvibradime.sys to qcpmic8930.sys

| Property | Value |
|----------|-------|
| Device | 0x801D |
| Function | 0x3E8 (1000) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_PM_VIB_CONTROL_REGISTER | Interface `{219397E7-B8D9-4DA6-AF0D-1733612E8299}` | 8 | 4 |

Sent by `sub_4013D0` with `IoBuildDeviceIoControlRequest`; it waits 500 ms at most for the completion (`STATUS_IO_TIMEOUT` otherwise).  

Inputbuffer (`ctx+0xC0`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | PMIC index |
| 04-07 | e.g. `18 00 00 00` | Level in 100 mV units: 0 = stop, 12–31 = 1.2–3.1 V |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | PMIC error code |

If the IOCTL fails while switching the motor on, the reference on the PMIC device is released (`ObfDereferenceObject`) and the interface is opened again on the next request.

### Other GUID

HwNClx device interface ? (passed to `HwNProcessAddDevicePostDeviceCreate`)  
`{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}`

qcpmic8930 vibrator interface  
`{219397E7-B8D9-4DA6-AF0D-1733612E8299}`
