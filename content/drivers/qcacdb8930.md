## Qcacdb8930.sys

Qualcomm Audio Calibration DataBase (ACDB) driver.  
It's the kernel-mode port of the Qualcomm "AudCal" library: it holds the audio calibration tables (device list and capabilities, audio/voice post-processing (COPP/POPP/VOCPROC) tables, AFE, ADIE codec profiles, ANC, sidetone, …) and answers ACDB commands (`acdb_ioctl`) from the other audio drivers. A default database is built into the driver; it can be overridden by the file `C:\audio_cal.acdb`.  
It also implements ACPH (Audio Calibration Protocol Handler) over DIAG, so that QACT (Qualcomm Audio Calibration Tool) can read and change the calibration online through [qcdiagrouter8930.sys](./qcdiagrouter8930.md).  
KMDF driver. Source file names in the binary: `acdb_kmdf.c`, `actp\src\actp.c`. PDB path `E:\build_e\subtask\E05A4CC0_98\output\audio\fre\FAME_ROW\qcacdb8930.pdb`. Pool tags `qacA`…`qacF`, `qacM`, `qacN`, `qacQ`, `qaca`…`qace`, `qacp`.  

ACPI device `\_SB.ACDB` (`_HID` `QCOM0790`). Its method `INFO` returns `Package { 1 }`, but the driver never evaluates it and uses no hardware resource (`EvtWdfDevicePrepareHardware` only walks the resource list).  
`\_SB.ACHW` (audio codec), `\_SB.MBHC`, `\_SB.MBGP` (headset detection, [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md)), `\_SB.Q6AD` (Q6 audio) and `\_SB.AHWI` have a `_DEP` on `\_SB.ACDB`.

There's no named `\Device\` object and no symbolic link: the driver is reached through its device interface (see [Interface GUID](#interface-guid)).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0790\<instance>`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcacdb` (read with `ZwOpenKey` + `ZwQueryValueKey` in `sub_4209C4`, the "ACDBReadRegistry" function):  
| Registry value | value | comment |
|----------------|-------|---------|
| ACDBFilePath | e.g. `C:\audio_cal.acdb` | REG_SZ. Path of the calibration file. `\DosDevices\` is prepended when not present. The directory part gives the path of the "invalid" file (`<dir>\audio_cal_invalid.acdb`). Without this value: `\DosDevices\C:\audio_cal.acdb` and `\DosDevices\C:\audio_cal_invalid.acdb` |

GUID of the ETW provider (manifest, `EtwRegister`):  
`{92C732A8-A93D-4F5F-87F3-505876201774}`

GUID of the WPP provider:  
`{F85F431E-93CF-40F4-A1B1-E81F6E5442B8}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\DiagRouter` | [qcdiagrouter8930.sys](./qcdiagrouter8930.md) | DIAG. Waited for with `IoRegisterPlugPlayNotification` on `{5FF73D59-FAB7-456E-884E-D5386CD5F581}`, opened with `WdfIoTargetOpen`. Used for ACPH (see [ACPH over DIAG](#acph-over-diag)) |

### Start sequence

`EvtDriverDeviceAdd` (`sub_420570` → `sub_4206D8`):
1. Creates the device (no name), takes an extra reference on it and calls `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
2. Creates a sequential, non power-managed queue with `EvtWdfIoQueueIoDeviceControl`.
3. Reads the registry (`sub_4209C4`).
4. Runs the ACDB command [0x1112F](#acdb-commands) "initialize" (`sub_4037A8`):
   1. Checks the consistency of the built-in database (internal values `0xACDB0001` = `0xACDB0034` and `0xACDB0000` = `0xACDB0036`), otherwise returns -15 / -16 and stops here.
   2. `sub_40B184`: opens the calibration file (`ZwOpenFile`, read access).
      - The file can't be opened: the directory of the file is created (`ZwCreateFile`, `FILE_OPEN_IF` + `FILE_DIRECTORY_FILE`, `sub_40A4C0`), and the built-in database is used.
      - The file is opened: its header is parsed (`sub_40FB28`) and its version is compared with the value returned by ACDB command 0x11110 (internal value `0xACDB0034`). Then the file is checked (`sub_40FBA4`) and loaded (`sub_40FAAC`). If one of these steps fails, the file is **renamed** to `audio_cal_invalid.acdb` (`ZwSetInformationFile(FileRenameInformation)`, ReplaceIfExists = TRUE, `sub_40A2A8`) and the database is reset with ACDB command 0x11111.
   3. Starts ACPH (`sub_4101B4`): allocates a 9479-byte response buffer and a 4732-byte buffer, registers the ACPH command handler 1 (`acph_online_ioctl`, `sub_416854`) and creates the system thread `DiagAcphThread` (`sub_4112DC`).
5. Creates and enables the device interface `{4EE2204F-…}` and the query interface with the same GUID.

On unload / cleanup (`EvtWdfObjectContextCleanup`), ACPH is stopped (`sub_4103CC`) and ACDB command 0x11111 resets the database.

> [!NOTE]
> The built-in database is a large data block in the driver image (around 0x422000–0x475B74), followed by the strings `2013-6-18 10:57:41` and `OEM Version Information Not Set`. The internal values are read by id (`0xACDB0000`, `0xACDB0001`, `0xACDB0002`, `0xACDB0021`, `0xACDB0029`, `0xACDB0034`…) with `sub_401D64`.

---

### IOCTL 0x50022400

This IOCTL is processed by Qcacdb8930.sys

| Property | Value |
|----------|-------|
| Device | 0x5002 |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the `acdb_ioctl` entry point | ≥ 8 | 0 or ≥ 8 (not used) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 04 00 00 00 | Buffer length (only traced) |
| 04-07 | ? | Pointer to a 4-byte variable that receives the address of `acdb_ioctl` (`sub_40275C`) |

The handler writes the address of `acdb_ioctl` at the given pointer. The caller can then call it directly: `int acdb_ioctl(uint32 command, void *in, uint32 inLen, void *out, uint32 outLen)`, see [ACDB commands](#acdb-commands).  
NULL pointer (or input buffer smaller than 8 bytes) → `0xC022001C`. A missing output buffer is ignored.  
Sent by [qcaudhwi8930.sys](./qcaudhwi8930.md#ioctl-0x50022400) with a 4-byte length and no output buffer.  

> [!NOTE]
> The input buffer contains kernel pointers that are used directly: only kernel-mode callers can use the IOCTLs of this driver.

---

### IOCTL 0x5002240C

This IOCTL is processed by Qcacdb8930.sys

| Property | Value |
|----------|-------|
| Device | 0x5002 |
| Function | 0x903 (2307) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Execute an ACDB command | ≥ 20 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | nCommandId: ACDB command (see [ACDB commands](#acdb-commands)) |
| 04-07 | ? | nCommandStructLength |
| 08-0B | ? | pCommandStruct (pointer) |
| 0C-0F | ? | nResponseStructLength |
| 10-13 | ? | pResponseStruct (pointer) |

Calls `acdb_ioctl(nCommandId, pCommandStruct, nCommandStructLength, pResponseStruct, nResponseStructLength)`.  
The request is always completed with `STATUS_SUCCESS` (unless the input buffer is too small) and the **ACDB result code** (0 = success, negative = error) is returned in `IoStatus.Information`.

---

### Other IOCTL codes

Any other IOCTL code is used directly as the ACDB command id (e.g. IOCTL code `0x0001110F`).  

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Execute ACDB command = IoControlCode | ≥ 8 | ≥ 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Length of the command structure |
| 04-07 | ? | Pointer to the command structure |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Length of the response structure |
| 04-07 | ? | Pointer to the response structure |

Calls `acdb_ioctl(IoControlCode, in[04-07], in[00-03], out[04-07], out[00-03])`. As for 0x5002240C, the ACDB result is returned in `IoStatus.Information`. A missing input or output buffer is replaced by `{0, NULL}`.

---

### ACDB commands

`acdb_ioctl` (`sub_40275C`) checks the lengths exactly (otherwise it returns -2) then calls the handler. Return codes seen in the handlers: 0 success, -2 bad parameters (length or NULL check of `acdb_ioctl`), -3 NULL pointer, -8 unknown sample rate, -12 buffer too small, -13 command not supported, -14 empty buffer, -15/-16 inconsistent built-in database.  
"var" = any non-zero length. Pairs of commands with the same input size and no output are the "Set" version of the previous "Get" command; for most "Get" commands the 4-byte output receives the number of bytes written in the buffer described by the input structure ?  
The ACPH column is the command id used by QACT (see [ACPH over DIAG](#acph-over-diag)).

| Command | Handler | Input size | Output size | ACPH | Comment |
|---------|---------|-----------|-------------|------|---------|
| 0x1110F | `sub_403894` | 0 | 4 | 2 | Returns internal value `0xACDB0035` (ACDB version ?) |
| 0x11110 | `sub_401D64` | 0 | 4 | 1 | Returns internal value `0xACDB0034` (target version ?). Compared with the version in the `.acdb` file |
| 0x11111 | `sub_40DDF8` | 0 | 0 | 4 | Reset: drops the data loaded from the file / set by QACT (`0xACDBD000`) |
| 0x11112 | `sub_406734` | 0 | 16 | 5 | 8 bytes internal value `0xACDB0002` + 8 bytes from `sub_40D670` (software versions ?) |
| 0x11113 | – | | | 6 | Not implemented: -13 |
| 0x11114 | `sub_408F90` | 12 | 4 | 7 | Device capabilities ?: input `{?, buffer size, buffer}`; the buffer receives the number of devices then 12 bytes per device (device id + 2 values taken from the device info structure, whose type is 0x11296–0x1129D or 0x11328) |
| 0x11115 | `sub_403900` | 8 | 4 | 8 | Is device pair: input `{Rx device id, Tx device id}`, output 1 if the pair is in the pair list (`0xACDB0021`), else 0 |
| 0x11116 / 0x11117 | `sub_404AA8` / `sub_404D4C` | 40 | 4 / 0 | 9 / 10 | Get / Set |
| 0x11118 / 0x11119 | `sub_404724` / `sub_4048F0` | 32 | 4 / 0 | 11 / 12 | Get / Set |
| 0x1111A / 0x1111B | `sub_405150` / `sub_40539C` | 24 | 4 / 0 | 13 / 14 | Get / Set |
| 0x1111C / 0x1111D | `sub_404F10` / `sub_405034` | 16 | 4 / 0 | 15 / 16 | Get / Set |
| 0x1111E / 0x1111F | `sub_403D90` / `sub_403FFC` | 28 | 4 / 0 | 17 / 18 | Get / Set |
| 0x11120 / 0x11121 | `sub_403A90` / `sub_403C18` | 20 | 4 / 0 | 19 / 20 | Get / Set |
| 0x11122 / 0x11123 | `sub_4043B8` / `sub_404604` | 24 | 4 / 0 | 21 / 22 | Get / Set |
| 0x11124 / 0x11125 | `sub_40417C` / `sub_40429C` | 16 | 4 / 0 | 23 / 24 | Get / Set |
| 0x1112C | `sub_4066C8` | 0 | 8 | 33 | Returns internal value `0xACDB0029` |
| 0x1112F | `sub_4037A8` | 0 | 0 | 3 | Initialize: loads `audio_cal.acdb`, starts ACPH (see [Start sequence](#start-sequence)) |
| 0x111B1 | `sub_4054BC` | 24 | 4 | 25 | |
| 0x111B5 / 0x111B6 | `sub_4059D0` / `sub_405834` | 36 | 4 / 0 | 26 / 27 | Get / Set |
| 0x111B7 | – | | | 28 | Not implemented: -13 |
| 0x111B9 | `sub_4060D8` | 20 | 4 | 30 | |
| 0x111BA | `sub_4063D0` | 20 | 4 | 29 | |
| 0x111BC / 0x111BD | `sub_405E1C` / `sub_405C50` | 28 | 4 / 0 | 31 / 32 | Get / Set |
| 0x111DB | `sub_403994` | 8 | 4 | 34 | |
| 0x111DC | `sub_4067B0` | var | 4 | 36 | |
| 0x111DD | `sub_4069C4` | var | 4 | 35 | |
| 0x111DE | `sub_406BE4` | 4 | 4 | 37 | |
| 0x111DF | `sub_406CC0` | 8 | 4 | 38 | |
| 0x111F2 / 0x111F3 | `sub_406FD0` / `sub_406DF0` | 24 | 4 / 0 | 39 / 40 | Get / Set |
| 0x111F5 / 0x111F6 | `sub_407420` / `sub_407240` | 24 | var / 0 | 41 / 42 | Get / Set |
| 0x11210 | `sub_407664` | var | var | 49 | |
| 0x11211 | `sub_407750` | var | var | 50 | |
| 0x1122D…0x11230 | `sub_407AA8`, `sub_407C08`, `sub_407CB0`, `sub_407E84` | var | var | 51…54 | |
| 0x1124E / 0x1124F | `sub_40801C` / `sub_408268` | 24 | 4 / 0 | 55 / 56 | Get / Set |
| 0x1126B / 0x1126C | `sub_408AF8` / `sub_408388` | 16 | 4 / 0 | 57 / 58 | Get / Set |
| 0x11290 | `sub_408CC0` | 12 | 4 | 59 | |
| 0x11291 | `sub_408E28` | 16 | 4 | 60 | |
| 0x11292 | `sub_4091A4` | var | var | 61 | |
| 0x112B6 | `sub_4092F4` | var | var | 62 | |
| 0x112B7 | `sub_409494` | var | var | 63 | |
| 0x112EF / 0x112F0 | `sub_4098F4` / `sub_409B04` | 16 | 4 / 0 | 86 / 87 | Get / Set |
| 0x112FD / 0x112FE | `sub_4095CC` / `sub_4097DC` | 24 | 4 / 0 | 84 / 85 | Get / Set |
| 0x11300 | `sub_409C00` | 8 | 4 | 88 | |
| 0x1132A | `sub_4084E8` | 12 | 0 | – | |
| 0x1132B | `sub_409D74` | 8 | 4 | 89 | |
| 0x11331 | `sub_409A14` | var | var | – | |
| 0x11338 | `sub_409CE0` | 8 | 4 | – | |
| 0x12A0B | `sub_409E54` | 16 | 4 | 81 | |
| 0x12A11 / 0x12A12 | `sub_409F28` / `sub_40A180` | 24 | 4 / 0 | 82 / 83 | Get / Set. Input: 2 ids (converted with internal values `0xACDB0038` / `0xACDB0039`), 2 more ids, data length (+0x10), data pointer (+0x14) |
| 0x50022404 | `sub_4106AC` | var | – | – | Registers an ACPH command handler: input `{uint16 handler id, 2 bytes padding, function pointer}` |
| 0x50022408 | `sub_4108DC` | var | – | – | Removes an ACPH command handler: input `{uint16 handler id}` |

Sample rates are converted to/from a bit mask by `sub_40FC24` (rate → mask when internal value `0xACDB0001` = 0x11185, mask → rate otherwise): 1 = 8000, 2 = 11025, 4 = 12000, 8 = 16000, 0x10 = 22050, 0x20 = 24000, 0x40 = 32000, 0x80 = 44100, 0x100 = 48000.

---

### ACPH over DIAG

`DiagAcphThread` (`sub_4112DC`):
1. Registers a PnP notification on the interface `{5FF73D59-FAB7-456E-884E-D5386CD5F581}` of [qcdiagrouter8930.sys](./qcdiagrouter8930.md) and waits for its first arrival (`sub_4126C4`).
2. Opens `\Device\DiagRouter` as WDF I/O target.
3. Sends [IOCTL 0x80082400](#ioctl-0x80082400) with a kernel event, then [IOCTL 0x80082404](#ioctl-0x80082404) to receive the DIAG subsystem commands `0x4B 0x11 0x0803…0x0834`.
4. Loop: waits for the event, reads one request (`WdfIoTargetFormatRequestForRead`), processes it in a work item (`sub_412320`) and writes the answer (`WdfIoTargetFormatRequestForWrite`).

Request received from the router (a DCI request starting with `0x93` is accepted too, with 8 more bytes in front):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 4B | DIAG subsystem command (or `0x80`) |
| 01 | 11 | Subsystem id |
| 02-03 | 03 08 … 34 08 | Subsystem command, 0x0803–0x0834. Outside of this range, the request is sent back with [IOCTL 0x80082410](./qcdiagrouter8930.md#ioctl-0x80082410) (error answer) |
| 04-05 | ? | ACPH command id (see column ACPH of [ACDB commands](#acdb-commands)) |
| 06-09 | ? | Length of the data that follows; must be equal to (packet length − 4) − 6 |
| 0A-… | ? | Data (the ACDB command structure). The request is at most 2016 bytes after the DIAG header |

The ACPH command is given to every registered handler until one accepts it (`sub_41054C`). Handler 1 is `acph_online_ioctl` (`sub_416854`), which maps the ACPH id to the ACDB command. Other drivers can add handlers with ACDB command 0x50022404: [qcq6ad8930.sys](./qcq6ad8930.md#acdb) registers handler 3 (`sub_412814`) and removes it with 0x50022408 at cleanup.  
ACPH ids without an ACDB command: 48 (`sub_415900`, empty answer) and 208 (`sub_415D1C`, answers the 4-byte value 9465: maximum data size ?).

Answer (written to `\Device\DiagRouter`, 4-byte DIAG header + 2016 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 4B 11 xx 08 | Copy of the DIAG header of the request |
| 04-05 | ? | ACPH command id |
| 06-09 | ? | Length of the data that follows |
| 0A | 00 | Status ? |
| 0B-… | ? | Error answer (`sub_40FFF0`, length 5): 4-byte error code, e.g. 2 = command unknown to `acph_online_ioctl`, 4 = bad length (bytes 06-09 of the request). The handlers also use 1 and 15 (meaning ?). Success (`sub_4100D8`): the data of the answer |

---

### IOCTL 0x80082400

This IOCTL is sent by Qcacdb8930.sys to [qcdiagrouter8930.sys](./qcdiagrouter8930.md#ioctl-0x80082400)

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_DIAGROUTER_CMD_INIT | \Device\DiagRouter | 4 ? (512-byte memory object) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | `PKEVENT` (synchronization event allocated in non-paged pool, tag `qacp`) |

---

### IOCTL 0x80082404

This IOCTL is sent by Qcacdb8930.sys to [qcdiagrouter8930.sys](./qcdiagrouter8930.md#ioctl-0x80082404)

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x901 (2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Register command codes | \Device\DiagRouter | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 02 00 | Type 2: subsystem command `0x4B` |
| 02-03 | 11 00 | Subsystem id 0x11 |
| 04-05 | 01 00 | 1 range |
| 06-0B | 00 00 00 00 00 00 | |
| 0C-0D | 03 08 | First subsystem command 0x0803 |
| 0E-0F | 34 08 | Last subsystem command 0x0834 |

---

### Interface GUID

ACDB Interface Class GUID (`WdfDeviceCreateDeviceInterface`), also used as query interface (`WdfDeviceAddQueryInterface`)  
`{4EE2204F-14FF-4139-9853-0DA54D6849D5}`

Query interface returned for this GUID (Size 20, Version 1):  
| Offset | Value | Comment |
|--------|-------|---------|
| 0x00 | 0x0014 | Size |
| 0x02 | 0x0001 | Version |
| 0x04 | WDFDEVICE | Context |
| 0x08 | `sub_40B9BC` | InterfaceReference (`WdfObjectReference` on the device) |
| 0x0C | `sub_40BA24` | InterfaceDereference |
| 0x10 | `sub_40275C` | `acdb_ioctl`, see [ACDB commands](#acdb-commands) |
