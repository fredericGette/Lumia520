## Qcremotefs8930.sys

Qualcomm Remote File System driver (QMI RMTFS service, "remote storage" server of the modem EFS).  
The modem has no storage of its own: it keeps its file system (EFS) in the eMMC partitions `MODEM_FS1`, `MODEM_FS2` and `MODEM_FSG` and asks the application processor to read and write them. This driver is the application processor side: it registers the QMI service 0x0E (RMTFS) on the IPC Router ([qcipcrouter8930.sys](./qcipcrouter8930.md)) and handles the modem's requests. The data is exchanged through a shared memory buffer (the memory resource of the device): the modem writes the sectors to the buffer and sends their physical address, the driver copies them to or from the disk.  
Depending on the registry, the "partitions" are the GPT partitions of the eMMC (`\DosDevices\PhysicalDrive0` or `\Device\Harddisk0\Partition0`) or files in `C:\DPP\`.  
Built from `P:\RemoteFS\rel\8.3\arm\Release\qcremotefs8930.pdb`. The QMI service framework (QCSI) and its IPC Router transport are linked in the driver (`DbgPrintEx` strings of `event_peek_cb`).

ACPI node on the Lumia 520 (DSDT): probably `\_SB.RFS0` (`_HID` `QCOM0F20`, `Memory32Fixed` 0x8FB00000, 0x300000) ?. See [Shared memory buffer](#shared-memory-buffer).

There's no device name and no symbolic link. No device interface, no I/O queue: the driver receives no IOCTL and no read/write request.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcremotefs8930` ?

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>` (the service key itself, from `WdfDriverGetRegistryPath`, **not** `Parameters`; read in `EvtDriverDeviceAdd` sub_40D350):  
| Registry value | value | comment |
|----------------|-------|---------|
| FileBased | ? | REG_DWORD (`.data:0x00409138`). 0: the partitions of the eMMC are used. ≠ 0: the files `C:\DPP\<name>` are used, see [File mode](#file-mode). Required: if the value is missing, `EvtDriverDeviceAdd` fails |
| PartitionNum | ? | REG_DWORD (`.data:0x0040913C`). Only used when `FileBased` = 0. 0: the disk is opened with `ZwCreateFile` on `\DosDevices\PhysicalDrive0`. 4: the disk is opened as a WDF I/O target `\Device\Harddisk0\Partition0` and accessed with [IOCTL 0x71E8C](#ioctl-0x71e8c). Any other value: every OPEN request fails. Required |

GUID of the ETW (WPP) provider:  
`{583DA23E-3DA2-4DB2-8295-F8212C8C2511}`

Pool tags: `qrfd` (driver), `qrf0` (QMI client), `qrf1` (iovec copy), `qrf2`…`qrf5` (IOCTL 0x71E8C buffers), `qcs0` and `QCSI` (QMI framework).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\IPC` (interface `{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`) | [qcipcrouter8930.sys](./qcipcrouter8930.md) | QCSI "IPC router" transport (ops table `.data:0x0040916C`). Awaited with `IoRegisterPlugPlayNotification`, then opened **by name** (`WdfIoTargetOpen`, `DesiredAccess` 0x1F0000). [IOCTL 0x12200C](#ioctl-0x12200c), [IOCTL 0x12201B](#ioctl-0x12201b), [IOCTL 0x122000](#ioctl-0x122000), [IOCTL 0x122017](#ioctl-0x122017), read/write of QMI messages |
| `\DosDevices\PhysicalDrive0` | disk.sys | `PartitionNum` = 0. Opened with `ZwCreateFile` (access 0x100003, share read/write, `FILE_OPEN`, options 0x62 = non-directory, synchronous, write-through). Sectors read/written with `ZwReadFile`/`ZwWriteFile` at offset LBA × 512 (sub_4027B8) |
| `\Device\Harddisk0\Partition0` | SD storage driver ? (sdstor) | `PartitionNum` = 4. WDF I/O target opened by name (access 0xC0000000, share read/write, `FILE_OPEN`, options 0x40). [IOCTL 0x71E8C](#ioctl-0x71e8c) |
| `\DosDevices\C:\DPP\` | file system | `FileBased` ≠ 0. Files `\DosDevices\C:\DPP\bootmodem_fs1`, … (see [File mode](#file-mode)) |

### Start-up

`EvtDriverDeviceAdd` (sub_40D350):
1. Sets the PnP/power callbacks: `EvtDevicePrepareHardware` (sub_40382C), `EvtDeviceD0Entry` (sub_403924), `EvtDeviceD0Exit` (sub_403A40), `EvtDeviceSurpriseRemoval` (sub_403B48). Cleanup callback sub_40D628 (frees the clients table).
2. Creates the device (context type `DEVICE_CONTEXT`, 4 bytes, unused), `WdfDeviceSetStaticStopRemove(FALSE)`, creates the global wait lock `.data:0x00409ADC` and 2 events.
3. Reads `FileBased` and `PartitionNum` (see above).

`EvtDevicePrepareHardware` keeps the first resource if it's a memory resource (`CmResourceTypeMemory`): start → `.data:0x00409B48`, length → `.data:0x0040AF20`. A memory resource that isn't the first one is only logged. Missing descriptor: `STATUS_DEVICE_CONFIGURATION_ERROR` (0xC0000182).

`EvtDeviceD0Entry` (only once, flag `.data:0x0040B028`): adds the IPC Router transport to the QCSI transport list and starts the system thread sub_403540. The thread:
1. Registers the RMTFS service (`qmi_csi_register` sub_40447C, service object `.rdata:0x004082C0`: service 0x0E, IDL version 1, max message 3079 bytes ?, 5 requests, 5 responses, 1 indication.). For each transport, it opens `\Device\IPC` (sub_406290) and registers the server 0x0E:1 ([IOCTL 0x12200C](#ioctl-0x12200c)).
2. Waits for two events: the "message received" event set by the transport (then calls the event handler of the transport, sub_4069AC, which reads the QMI messages and dispatches them) or the stop event `.data:0x00409ACC`.
3. On the stop event: closes the transports and terminates.

`EvtDeviceD0Exit` only acts when the target state is `WdfPowerDeviceD3Final` (5): it sets the stop event, wakes the pending callers, and waits (with a `PsSetCreateThreadNotifyRoutine` callback sub_4037D8 that recognizes the thread id) until the thread has exited.

> [!NOTE]
> `EvtDeviceSurpriseRemoval` (sub_403B48) calls `KeBugCheckEx(0x14E, 0x51726630 ('Qrf0'), 0, 0, 0)`: a surprise removal of the device crashes the phone.

### QMI RMTFS service

Service 0x0E (`QMI_RMTFS`), instance 1. Up to 10 QMI clients (table `.data:0x00409AE8`, 10 × 8 bytes: in-use byte, client pointer). The requests are dispatched by msg id from the table `.rdata:0x00408178`. Each handler builds the C structure of the response and sends it with `qmi_csi_send_resp` (sub_404618). The table below gives the decoded C structures (TLV encoding done by the QMI IDL library):

| Msg id | Name | Handler | Request | Response |
|--------|------|---------|---------|----------|
| 0x0001 | RMTFS_OPEN | sub_402D44 | path (string, max 255) | result, `caller_id` (optional) |
| 0x0002 | RMTFS_CLOSE | sub_402E5C | `caller_id` | result |
| 0x0003 | RMTFS_RW_IOVEC | sub_4030B8 | `caller_id`, direction, iovec array, is_force_sync ? | result |
| 0x0004 | RMTFS_ALLOC_BUFF | sub_402F5C | `caller_id`, buffer size | result, buffer address (64 bits, optional) |
| 0x0005 | RMTFS_GET_DEV_ERROR | sub_403240 | `caller_id` | result, status (optional) |

"result" is the standard `qmi_response_type`: `result` (0 = success, 1 = failure) and `error`. The driver only uses the errors 1 (`QMI_ERR_MALFORMED_MSG`: bad `caller_id`, buffer out of range) and 3 (`QMI_ERR_INTERNAL`: open failed, I/O error).

> [!NOTE]
> `caller_id` is the **kernel address** of the file entry (`.data:0x00409B50 + 504 × n`). It's given to the modem and used as is by the other requests, without check other than ≠ 0.

#### RMTFS_OPEN

The path is copied and looked up in the file table (10 entries). An already open path returns the same entry. Otherwise:
* Partition mode (`FileBased` = 0, sub_4011E0). At the first open, the disk is opened (`PartitionNum` 0 or 4), and the GPT is read (sub_401E04) to find the first LBA of the 3 modem partitions. Then the path selects the partition:

| Path | Partition | Partition type GUID |
|------|-----------|---------------------|
| `/boot/modem_fs1` | MODEM_FS1 | `{EBBEADAF-22C9-E33B-8F5D-0E81686A68CB}` |
| `/boot/modem_fs2` | MODEM_FS2 | `{0A288B1F-22C9-E33B-8F5D-0E81686A68CB}` |
| `/boot/modem_fsg` | MODEM_FSG | `{638FF8E2-22C9-E33B-8F5D-0E81686A68CB}` |

Another path is only logged: the open "succeeds" and returns the address of the next free entry, which is not initialised and not marked used ?.
* File mode: see [File mode](#file-mode).

Failure: `result` 1, `error` 3, no `caller_id`.

#### RMTFS_CLOSE

sub_401A04: closes the file handle (file mode), deletes the wait lock and the event of the entry, frees the entry. When the last entry is closed, the disk is closed too (`ZwClose` or `WdfIoTargetClose`) and the table is cleared. `caller_id` = 0: error 1. Close failure: error 3.

#### RMTFS_RW_IOVEC

The iovec array is copied (12 bytes per entry):
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Sector address, relative to the start of the partition (in 512-byte sectors) |
| 04-07 | ? | **Physical** address of the data in the shared buffer |
| 08-0B | ? | Number of sectors |

Direction: 0 = read (disk → buffer), 1 = write (buffer → disk).  
sub_402BC4 takes the wait lock of the entry, queues a work item (sub_402A64) and waits for its event. For each iovec, the work item checks that `[address, address + 512 × sectors]` is inside the shared buffer (else status 1), maps it with `MmMapIoSpace`, and reads or writes the sectors at `partition start + sector address` (sub_402364 with `PartitionNum` = 4, sub_4027B8 otherwise). The first failing iovec stops the transfer. The status (0 OK, 1 bad parameter, 2 I/O error) is kept at entry +0x1F0 for [RMTFS_GET_DEV_ERROR](#rmtfs_get_dev_error).

#### RMTFS_ALLOC_BUFF

Returns the physical start of the shared buffer (entry +0x20, i.e. the memory resource), sign-extended to 64 bits. The requested size is **ignored**: every client gets the same whole buffer. Length 0 (no memory resource): error 3.

#### RMTFS_GET_DEV_ERROR

Always succeeds. Status = the result of the last `RMTFS_RW_IOVEC` of this entry (entry +0x1F0), or 1 if `caller_id` = 0.

### File entry

`.data:0x00409B50`, 10 entries of 504 bytes:  
| Offset | Comment |
|--------|---------|
| 0x00 | File handle (file mode) or handle of `\DosDevices\PhysicalDrive0` (`PartitionNum` = 0) |
| 0x08-0x0F | First LBA of the partition (0 in file mode) |
| 0x10 | Byte: entry used |
| 0x14 | WDF wait lock (serializes the transfers of the entry) |
| 0x18 | Event handle (end of the work item) |
| 0x1C | WDFDEVICE |
| 0x20 | Physical address of the shared buffer |
| 0x24 | Length of the shared buffer |
| 0x28-0xE7 | Current iovec array |
| 0xE8 | Number of iovecs |
| 0xEC | Direction |
| 0xF0-0x1EF | Path (string) |
| 0x1F0 | Status of the last transfer |

### GPT parsing

sub_401E04 (partition mode, at the first open):
1. Reads LBA 1 and checks the signature `EFI PART`. If it's wrong, reads the backup header at the LBA found at offset 0x20 of the sector read (alternate LBA) and checks it again.
2. Reads the partition entries sector by sector (up to 32 sectors): from LBA 2 for the primary header, from the 32 sectors before the backup header otherwise. The entry size is taken from offset 0x54 of the header.
3. Compares the type GUID (offset 0x00 of each entry) with the 3 GUIDs above and keeps the first LBA (offset 0x20). Stops when the 3 partitions are found.

With `PartitionNum` = 4, the target is first probed with [IOCTL 0x71E8C](#ioctl-0x71e8c) operation 0x10000 (sub_401B3C). If the probe returns 0, the open fails.

### File mode

`FileBased` ≠ 0 (sub_401630):
1. At the first open, waits until `\DosDevices\C:\DPP\` can be opened as a directory (`FILE_LIST_DIRECTORY`): up to 10 tries, 3 s apart (`KeDelayExecutionThread` −30,000,000).
2. The file name is `\DosDevices\C:\DPP\` + the path without its `/` characters, e.g. `/boot/modem_fs1` → `\DosDevices\C:\DPP\bootmodem_fs1`. Prefix + path of 255 characters or more: bug check 0xF7 `DRIVER_OVERRAN_STACK_BUFFER` (sub_406CF4).
3. The file is opened with `FILE_OPEN_IF` (created if missing), access read/write, write-through. The partition start is 0: sector *n* is at offset 512 × *n* in the file.

### Shared memory buffer

The buffer is the memory resource of the device (physical address and length from `EvtDevicePrepareHardware`). It's never mapped as a whole: each iovec is mapped with `MmMapIoSpace` (non-cached) for the duration of the transfer and copied byte by byte. On the Lumia 520 the ACPI node `\_SB.RFS0` declares 0x8FB00000, 0x300000 (3 MB) ?.

---

### IOCTL 0x71E8C

This IOCTL is sent by Qcremotefs8930.sys to `\Device\Harddisk0\Partition0` (only when `PartitionNum` = 4), synchronously (`WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`). Same IOCTL as the RPMB access of [qcscm8930.sys](./qcscm8930.md#ioctl-0x71e8c).

| Property | Value |
|----------|-------|
| Device | 0x7 (FILE_DEVICE_DISK) |
| Function | 0x7A3 (1955) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Probe (sub_401B3C) | `\Device\Harddisk0\Partition0` | 1056 | 1056 |
| Read / write sectors (sub_402364) | `\Device\Harddisk0\Partition0` | 1056 + data | 1056 + data |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 20 04 00 00 | Size of the header (1056) |
| 04-07 | 00 00 01 00 | Operation: 0x10000 = probe, 0x10001 = read, 0x10002 = write |
| 10-13 | 04 00 00 00 | Read/write: 4 (eMMC partition ?, same value as `PartitionNum`). Probe: not initialised |
| 14-17 | ? | Read/write: number of bytes (at most 0x3FE00 = 511 sectors per request) |
| 18-1F | ? | Read/write: first LBA (partition start + sector address) |
| 20-.. | ? | Write: data |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 10-17 | ? | Probe: must be ≠ 0, else the probe fails |
| 18-2F | ? | Probe: 3 more 64-bit values, only logged |
| 20-.. | ? | Read: data |

Larger transfers are split in requests of 511 sectors. The data is copied to/from the iovec mapped with `MmMapIoSpace`. Failures return status 2 (I/O error).

---

### IOCTL 0x12200C

This IOCTL is sent by Qcremotefs8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x12200c) (sub_406658, `register_server` of the transport), synchronously.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Register a server | \Device\IPC | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 0E 00 00 00 | Service 0x0E (RMTFS) |
| 04-07 | 01 00 00 00 | Instance (IDL version 1) |

---

### IOCTL 0x12201B

This IOCTL is sent by Qcremotefs8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x12201b) when the port is opened (sub_406290), then re-sent (`WdfRequestReuse`) at the end of its own completion routine `event_peek_cb` (sub_405F14). Asynchronous.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x806 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a server/client event | \Device\IPC | 0 | 0 (20-byte memory attached) |

When it completes with `Information` ≠ 0, `event_peek_cb` reads all the waiting events with [IOCTL 0x122000](#ioctl-0x122000).

---

### IOCTL 0x122000

This IOCTL is sent by Qcremotefs8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x122000) by `event_peek_cb` (sub_405F14), synchronously, in a loop until it returns 0 bytes. Named `IOCTL_IPC_READ_OOB` in the traces.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_IPC_READ_OOB | \Device\IPC | 0 | 20 |

Only 2 events are used:
* 0 `Resume_tx`: the queued responses for that node:port are written again.
* 3 `Rem_client`: the queue of that client is freed and the QMI client is disconnected (sub_4042A4).

A write that returns `STATUS_DEVICE_BUSY` (0x80000011) is queued per destination (sub_4067AC). When 10 messages are already queued, the client is disconnected.

---

### IOCTL 0x122017

This IOCTL is sent by Qcremotefs8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x122017) when the port is opened (sub_406290), then re-sent by the event handler sub_4069AC after each message. Asynchronous, no buffer.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x805 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a packet | \Device\IPC | 0 | 0 |

The completion routine (sub_405ECC) signals the thread, which reads the packet (`Information` bytes: 8-byte source address + QMI message) with a read request and gives it to the QCSI library (sub_403FC8).

---

### Interface GUID

IPC Router interface, awaited with `IoRegisterPlugPlayNotification`  
`{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`

### Other GUID

Partition type GUIDs looked for in the GPT (`.data:0x00409128`, `.data:0x00409140`, `.data:0x00409150`)  
`{EBBEADAF-22C9-E33B-8F5D-0E81686A68CB}` MODEM_FS1  
`{0A288B1F-22C9-E33B-8F5D-0E81686A68CB}` MODEM_FS2  
`{638FF8E2-22C9-E33B-8F5D-0E81686A68CB}` MODEM_FSG  
