## Crashdmp.sys

Crash Dump Driver (Microsoft, `crashdmp.pdb`).  
It is the kernel side of the Windows crash dump and of the hibernation file: the kernel loads it as a library (it isn't a PnP/WDF driver and has no service of its own), gets a table of 12 functions from its `DriverEntry`, and calls them to prepare the _dump stack_ and, after a bugcheck, to write the memory dump to disk.  
At initialisation it queries the storage stack of the boot/dump volume, loads a private copy of the storage port driver and of the dump filter drivers (prefix `dump_`), and records the disk location (retrieval pointers) of the dump file. At crash time it writes the dump through this private stack, without using the normal file system / storage drivers.  
With `CrashDumpEnabled` = 0 (default on the Lumia 520, see [wpcrdmp.sys](./wpcrdmp.md)) the dump stack is not initialised (`ReadRegistrySettings` returns `STATUS_UNSUCCESSFUL`).  
Debug messages are written in the log file `DumpStack.log.tmp` and shown on the bugcheck screen (`CrashdmpDisplayString`). Pool tag: `CDmp`.

There's no device name and no symbolic link. It doesn't process any IOCTL.  
Imports: `ntoskrnl.exe`, `HAL.dll`.

GUID of the ETW provider (`Microsoft-Windows-Crashdump`):  
`{ecdaacfa-6fe9-477c-b5f0-85b76f8f50aa}`  

### Registry

Registry key `\Registry\Machine\System\CurrentControlSet\Control\CrashControl` (`ReadRegistrySettings`, 0x1B9FC):  
| Registry value | value | comment |
|----------------|-------|---------|
| CrashDumpEnabled | 0 | ULong. Type of dump, see below. 0 → no dump stack |
| LogEvent | ? | ULong (Boolean). If ≠ 0 and the dump type is "none", the dump type becomes minidump |
| SendAlert | ? | ULong (Boolean). Same as `LogEvent` |
| ResumeCapable | -1 | ULong. -1 = not configured, 1 = resume capable, else not resume capable. Returned by `CrashdmpResumeCapable` |
| EnableLogFile | 0 | ULong (Boolean). Enables the log file `DumpStack.log.tmp` |
| DumpLogLevel | 0 | ULong. 0 or 1 (other values are ignored) |
| SimulateError | 0 | ULong. Failure injection: 0x1001–0x1009 make `CrashdmpInitialize` fail at a given step, 0x2001–0x2007 make `CrashdmpLoadDumpStack` fail at a given step. Also stored in the dump context (used at crash time) |
| SimulateNotReady | 0 | ULong (Boolean). Sets flag 0x10 of the dump context |
| Flags | 0 | ULong. Bit 0: allocate a buffer for the log data of the port driver ? |
| DedicatedDumpFile | ? | String. Path of a dedicated dump file used instead of the page file (`InitDedicatedDump`, 0x12090). Must be shorter than 75 characters (else `STATUS_INVALID_PARAMETER`). On the Lumia 520 the value is `D:\DedicatedDump.sys` ([wpcrdmp.sys](./wpcrdmp.md)) |
| DumpFileSize | ? | ULong, MB. Size of the dedicated dump file. 0 or absent → computed from the physical memory size + the secondary dump data |
| DumpFilters | ? | MultiString. Names of the dump filter drivers loaded in the dump stack (`LoadFilterDrivers`, 0x11C54), e.g. [dumpfve.sys](./dumpfve.md) (BitLocker) |

Value of `CrashDumpEnabled` → dump type used by the driver:  
| CrashDumpEnabled | Dump type | comment |
|------------------|-----------|---------|
| 0 | 0 | None |
| 1 | 5 DUMP_TYPE_BITMAP_FULL | Full physical memory dump |
| 2 | 6 DUMP_TYPE_BITMAP_KERNEL | Kernel memory dump |
| 3 | 4 DUMP_TYPE_TRIAGE | Minidump |
| 4 | 4 DUMP_TYPE_TRIAGE | |
| 7 | 6 DUMP_TYPE_BITMAP_KERNEL | Automatic memory dump |
| other | 0 | None |

Registry key `\Registry\Machine\System\CurrentControlSet\Control\CrashControl\StorageTelemetry`:  
| Registry value | value | comment |
|----------------|-------|---------|
| DeviceDumpEnabled | 1 | ULong (Boolean). Enables the storage telemetry secondary dump data (`CrashdmpDriveTelemetryCallback`) |
| StorageTCCode_0 … StorageTCCode_7 | ? | ULong. Bugcheck codes considered as "storage related" (`IsStorageRelatedCrash`) |

Registry key `\Registry\Machine\System\CurrentControlSet\Control\CrashControl\Promotion` (read only with a dedicated dump file):  
| Registry value | value | comment |
|----------------|-------|---------|
| KernelDumpPromotionEnabled | 1 | ULong (Boolean) |
| KernelDumpPromotionCode_0 … KernelDumpPromotionCode_7 | ? | ULong. Bugcheck codes for which a minidump is promoted to a kernel dump ? |

Registry key `\Registry\Machine\System\CurrentControlSet\Control\CrashControl\MachineCrash` (written by `CheckForCrashDump`, 0x14CE8, when the dedicated dump file already contains a dump, signature `PAGEDUMP`):  
| Registry value | comment |
|----------------|---------|
| DumpFile | Path of the dump file |
| TempDestination | Path of the temporary copy `\DUMPxxxx.tmp` |

`CrashdmpDumpNotification` (0x12FE8) writes `CrashDumpEnabled` = 0 (see [IOCTL 0x2D5644](#ioctl-0x2d5644)).

### Initialisation by the kernel

`DriverEntry` (`FxDriverEntryWorker`, 0x1C46C) is called with 2 parameters (not a `DRIVER_OBJECT`):
1. A structure of 16 bytes, copied in the global context (`Context`, `.data:0x19238`):  
| Bytes | Comment |
|-------|---------|
| 00-03 | Name of the boot/dump device (`UNICODE_STRING *`), opened with `ZwOpenFile` |
| 04-07 | `PHYSICAL_MEMORY_DESCRIPTOR *` (number of runs, number of pages, runs) |
| 08-0B | Function used to load the drivers of the dump stack (`CrashdmpLoadDriver`) |
| 0C-0F | ? |
2. The function table to fill (56 bytes). Its version (offset 0) must be 1, or its offset 4 must be 5, else `STATUS_REVISION_MISMATCH` (0xC0000059). A NULL parameter → `STATUS_INVALID_PARAMETER` (0xC000000D).

Function table returned to the kernel:  
| Offset | Value / Function | Comment |
|--------|------------------|---------|
| 0x00 | 1 | Version |
| 0x04 | 5 | ? |
| 0x08 | `CrashdmpInitialize` (0x1B258) | Reads the registry, opens the dump file, gets its disk runs, loads the crash dump stack (`dump_` prefix, usage type 3 "dump file") |
| 0x0C | `CrashdmpLoadDumpStack` (0x1B508) | Loads a dump stack: usage type 2 = hibernation, 3 = dump file |
| 0x10 | `CrashdmpInitDumpStack` (0x16184) | Initialises the dump port/filter drivers at crash (or hibernation) time |
| 0x14 | `CrashdmpFreeDumpStack` (0x1B000) | |
| 0x18 | `CrashdmpDisable` (0x1B1B4) | Frees the crash dump stack |
| 0x1C | `CrashdmpNotify` (0x1663C) | Notifications from the kernel (start of the dump, hibernation phases…) |
| 0x20 | `CrashdmpWrite` (0x1683C) | Writes the dump |
| 0x24 | `CrashdmpUpdatePhysicalRange` (0x146F0) | |
| 0x28 | `CrashdmpResumeCapable` (0x14C84) | |
| 0x2C | `CrashdmpGetTransferSizes` (0x14C20) | |
| 0x30 | `CrashdmpLogStatusData` (0x15114) | |
| 0x34 | `CrashdmpReady` (0x1514C) | |

`DriverEntry` also calls `NtQuerySystemInformation(SystemBootEnvironmentInformation)` to keep the firmware type (0 unknown, 1 BIOS, 2 UEFI), and `ZwPowerInformation(0x42, …)` for a boolean flag (?).  
The global context starts with the signature `CDmp` (0x706D4443) and has a copy (`ContextCopy`, 0x358 bytes): `CheckContextIntegrity` verifies them before each operation.

### Dump stack

`CrashdmpLoadDumpStack`:
1. Opens the boot device, gets the top of its device stack (`IoGetAttachedDeviceReference`).
2. `QueryPortDriver` (0x1BCD4) sends to it [IOCTL 0x560000](#ioctl-0x560000), [IOCTL 0x41020](#ioctl-0x41020), [IOCTL 0x41018](#ioctl-0x41018), [IOCTL 0x70048](#ioctl-0x70048), [IOCTL 0x700A0](#ioctl-0x700a0) and, with a dedicated dump file, [IOCTL 0x2D0C14](#ioctl-0x2d0c14) / [IOCTL 0x2D5644](#ioctl-0x2d5644).
3. `LoadPortDriver` (0x1B7AC) loads `\SystemRoot\System32\Drivers\<prefix><port>.sys`. The port name is the name of the driver of `\Device\ScsiPort<n>` (n = port number of [IOCTL 0x41018](#ioctl-0x41018)). For a legacy port driver it loads `diskdump.sys` plus `storport.sys` or `scsiport.sys`.
4. `LoadFilterDrivers` loads the drivers of `DumpFilters` with the same prefix, and `InitializeFilterDrivers` calls their `DumpStart`/initialisation callbacks.
5. `SendUsageNotification` (0x1B6D0) sends `IRP_MJ_PNP` / `IRP_MN_DEVICE_USAGE_NOTIFICATION` (type 2 hibernation or 3 dump file, `InPath` = TRUE) to the device of the dump file.

The prefix is `dump_` for the crash dump (e.g. `dump_storport.sys` ?; on the Lumia 520 the dump port driver of the eMMC is probably [dumpsd.sys](./dumpsd.md)); the kernel passes `hiber_` for the hibernation stack (?).  
`MarkHiberBootPhase` (0x12DA4) marks the dump stack structures with `PoSetHiberRange` so they are kept in the hibernation file.

### Dump file

- Page file (default): the kernel gives the handle of the file to `CrashdmpInitialize`.
- Dedicated dump file (`DedicatedDumpFile`): created by `CreateDumpFile` (0x14ACC) with `IoCreateFile` (`\??\<DedicatedDumpFile>`), with a restricted security descriptor. If it already contains a dump (`PAGEDUMP`), `CheckForCrashDump` renames it to `\DUMPxxxx.tmp` (?) and writes the `MachineCrash` key.

The disk runs of the file are obtained with [FSCTL 0x9003B](#fsctl-0x9003b), then the file is no longer accessed through the file system.

Log file: `<drive>:\DumpStack.log.tmp` (drive of the dump volume, or of the dedicated dump file), created by `CreateLogFile` (0x12EBC) when `EnableLogFile` ≠ 0. Its header has the signature `DLOGFILE` + version `0001`.

### Bugcheck callbacks

Registered with `KeRegisterBugCheckReasonCallback(KbCallbackSecondaryDumpData)`, component `CRASHDUMP`:  
| Callback | GUID of the secondary data | Comment |
|----------|----------------------------|---------|
| `CrashdmpDumpCallback` (0x12D44) | `{65755a40-f146-43ea-8c91-36b85728fd35}` | 8 bytes (?). Registered by `InitDumpContext` for the bitmap dumps (types 5 and 6) |
| `CrashdmpDriveTelemetryCallback` (0x12B8C) | `{d8e2592f-1aab-4d56-a746-1f7585df40f4}` (`GUID_DEVICEDUMP_CRASHSTORAGE_DEVICE`) | Storage device telemetry collected from the port driver. Registered only if `DeviceDumpEnabled` ≠ 0 and the port driver supports it (dump pointers version ≥ 3) |

---

### IOCTL 0x560000 — IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS

This IOCTL is sent by Crashdmp.sys to the boot/dump volume (`IsVolumeSupported`, 0x1BFA0)

| Property | Value |
|----------|-------|
| Device | 0x56 |
| Function | 0x0 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS | boot device | 0 | 32 |

A volume with more than one disk extent is rejected with `STATUS_NOT_SUPPORTED` (0xC00000BB), unless the volume device has the flag 0x100 in its characteristics. `STATUS_BUFFER_OVERFLOW` / `STATUS_BUFFER_TOO_SMALL` are accepted.

---

### IOCTL 0x41020 — IOCTL_SCSI_GET_DUMP_POINTERS

This IOCTL is sent by Crashdmp.sys to the boot/dump device (`QueryPortDriver`, and `GetMpioPathInfo` for each MPIO path)

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x408 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SCSI_GET_DUMP_POINTERS | boot device | 8 | 68 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 02 00 | Version (`DUMP_POINTERS_VERSION_2`) |
| 02-03 | 00 00 | |
| 04-07 | 20 00 00 00 | Size |

Outputbuffer: `DUMP_POINTERS_EX`. Accepted if version 2–4 and size 32–68 bytes; otherwise the old `DUMP_POINTERS` (40 bytes) is assumed. Version ≥ 3: the maximum transfer size is limited to 0x40000 and the flag 4 tells if the port driver supports the device telemetry.

---

### IOCTL 0x41024 — IOCTL_SCSI_FREE_DUMP_POINTERS

This IOCTL is sent by Crashdmp.sys to each MPIO path (`SendFreeDumpPointers`, 0x11A4C)

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x409 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SCSI_FREE_DUMP_POINTERS | MPIO path device | 68 (or 40 for the old format) | 0 |

The input is the buffer returned by [IOCTL 0x41020](#ioctl-0x41020).

---

### IOCTL 0x41018 — IOCTL_SCSI_GET_ADDRESS

This IOCTL is sent by Crashdmp.sys to the boot/dump device (`QueryPortDriver`, `GetMpioPathInfo`)

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x406 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_SCSI_GET_ADDRESS | boot device | 0 | 8 |

Outputbuffer: `SCSI_ADDRESS`. The `PortNumber` (byte 04) gives the port device `\Device\ScsiPort<n>`, whose driver name is used to load the dump port driver.

---

### IOCTL 0x70048 — IOCTL_DISK_GET_PARTITION_INFO_EX

This IOCTL is sent by Crashdmp.sys to the boot/dump device (`QueryPortDriver`)

| Property | Value |
|----------|-------|
| Device | 0x7 |
| Function | 0x12 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_DISK_GET_PARTITION_INFO_EX | boot device | 0 | 144 |

Only `StartingOffset` (bytes 08-0F) is kept.

---

### IOCTL 0x700A0 — IOCTL_DISK_GET_DRIVE_GEOMETRY_EX

This IOCTL is sent by Crashdmp.sys to the boot/dump device (`QueryPortDriver`)

| Property | Value |
|----------|-------|
| Device | 0x7 |
| Function | 0x28 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_DISK_GET_DRIVE_GEOMETRY_EX | boot device | 0 | 56 |

The geometry is passed to the dump port driver in the dump init context (`FillDumpInitContext`) and to the filter drivers.

---

### IOCTL 0x2D0C14 — IOCTL_STORAGE_GET_HOTPLUG_INFO

This IOCTL is sent by Crashdmp.sys to the boot/dump device (`QueryPortDriver`), only with a dedicated dump file

| Property | Value |
|----------|-------|
| Device | 0x2D |
| Function | 0x305 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_STORAGE_GET_HOTPLUG_INFO | boot device | 0 | 8 |

If `MediaRemovable`, `MediaHotplug` or `DeviceHotplug` (bytes 04-06) is set, the driver sends [IOCTL 0x2D5644](#ioctl-0x2d5644).

---

### IOCTL 0x2D5644

This IOCTL is sent by Crashdmp.sys to the boot/dump device (`QueryPortDriver`), when the device is removable / hot-pluggable

| Property | Value |
|----------|-------|
| Device | 0x2D (IOCTL_STORAGE_BASE) |
| Function | 0x591 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Register a dump notification callback ? | boot device | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version |
| 04-07 | 0C 00 00 00 | Size |
| 08-0B | ? | `CrashdmpDumpNotification` (0x12FE8) |

When the storage driver calls `CrashdmpDumpNotification(0)` (at PASSIVE_LEVEL), the crash dump is disabled: `ZwSetSystemInformation(SystemCrashDumpStateInformation, 0)`, `CrashDumpEnabled` = 0 in the registry, and an event 0x8004009C is written in the system log. An error of this IOCTL is ignored.

---

### IOCTL 0x6D70C050

This IOCTL is sent by Crashdmp.sys to the boot/dump device (`InitMpioDevice`, 0x11EDC; `FreeMpioResources`, 0x151DC)

| Property | Value |
|----------|-------|
| Device | 0x6D70 ("pm", MPIO ?) |
| Function | 0x14 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Register / unregister the MPIO path notification ? | boot device | 16 | 16 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0B | 00 … | |
| 0C-0F | ? | `MpioPathChangeNotification` (0x1565C), 0 to unregister |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | |
| 04-07 | ? | MPIO device object |
| 08-0B | ? | Pointer to the list of path devices (count, then one device object per path) |

Fails on a device without MPIO (the error is ignored). The MPIO paths are probably not used on the Lumia 520.

---

### FSCTL 0x9003B — FSCTL_QUERY_RETRIEVAL_POINTERS

This FSCTL is sent by Crashdmp.sys with `ZwFsControlFile` on the dump file and on the log file (`GetDumpFileDiskRuns`, 0x1C044; `GetFileDiskRuns`, 0x1CEA8)

| Property | Value |
|----------|-------|
| Device | 0x9 (FILE_DEVICE_FILE_SYSTEM) |
| Function | 0xE |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| FSCTL_QUERY_RETRIEVAL_POINTERS | dump file / `DumpStack.log.tmp` | 8 (size of the file in bytes) | 4 (receives a pointer to the array of runs, allocated by the file system) |

Each run (16 bytes: sector, number of sectors) is copied in a list ended by a zero run. No run → `STATUS_FILE_INVALID` (0xC0000098).

### GUID

ETW provider Microsoft-Windows-Crashdump  
`{ecdaacfa-6fe9-477c-b5f0-85b76f8f50aa}`

Secondary dump data of crashdmp.sys (`CRASHDUMP_GUID_ID`)  
`{65755a40-f146-43ea-8c91-36b85728fd35}`

Secondary dump data of the storage device telemetry (`GUID_DEVICEDUMP_CRASHSTORAGE_DEVICE`)  
`{d8e2592f-1aab-4d56-a746-1f7585df40f4}`
