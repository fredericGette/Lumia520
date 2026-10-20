## Qcfmtransport8930.sys

FM radio transport driver.  
It's a thin pipe between user mode and the FM radio core of the WCNSS (RIVA): it opens the SMD channel `APPS_FM` of [qcsmd8930.sys](./qcsmd8930.md) and forwards the content of 2 IOCTLs as plain SMD reads and writes. It doesn't know anything about the FM protocol (no registers, no frequencies, no RDS parsing): the FM commands are built by the user-mode FM stack.  
Its PDO (`QWCN\QCOM2150`, ACPI node `\_SB.RIVA.FMT0`) is created by the WCN bus driver [qcwcn8930.sys](./qcwcn8930.md#child-devices). The SMD channel is only opened once the WCN device interface of qcwcn8930.sys is published (i.e. once the WCNSS is running).  
Build path found in the binary: `P:\fm\rel\8.2.1.1\arm\Release\qcfmtransport8930.pdb`.

Symbolic link : `\DosDevices\qcfmtransportdriver`  
There's no named `\Device\` object (the WDF device is unnamed; only the symbolic link is created).

There's no parameters in the registry.

GUID of the ETW provider:  
None. The only trace is a `DbgPrint` ("FM: transport:READ IOCTL :WdfMemoryGetBuffer of Output buffer returned NULL").

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `{917DF3C3-4938-4056-8F74-D3501BCD51EA}` | [qcwcn8930.sys](./qcwcn8930.md#interface-guid) | WCN device interface. Waited for with `IoRegisterPlugPlayNotification` (`PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`). No IOCTL is sent to it |
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | SMD channel `APPS_FM`, see [SMD channel](#smd-channel) |

### Initialisation

`EvtDriverDeviceAdd` (0x4012A0):
1. Creates the device (context `FM_TRANSPORT_DEVICE_CONTEXT`) with the PnP callbacks `EvtDevicePrepareHardware` (does nothing), `EvtDeviceReleaseHardware` and `EvtDeviceSurpriseRemoval`.
2. Creates the symbolic link `\DosDevices\qcfmtransportdriver`.
3. Creates the default queue (parallel, `EvtIoDeviceControl` = `EvtWdfIoQueueIoDeviceControl`, `EvtIoStop` = `EvtWdfIoQueueIoStop`, execution level passive) and a wait-lock.
4. Registers the PnP notification on the WCN interface `{917DF3C3-…}` (callback `sub_401584`).
5. Creates and enables its own [device interface](#interface-guid) `{BF6A982B-2096-4E02-A0F5-B052D009FA7F}`. It's enabled immediately, before the SMD channel is open.

The notification callback (`sub_401584`) copies the whole `DEVICE_INTERFACE_CHANGE_NOTIFICATION` into the device context and queues a work item (`sub_4014CC`). The work item only acts when the event is `GUID_DEVICE_INTERFACE_ARRIVAL` `{CB3A4004-46F0-11D0-B08F-00609713053F}` and the class is the WCN interface: if the SMD I/O target doesn't exist yet it's created by `OpenSmdChannel` (`sub_401D54`), then it's started (`WdfIoTargetStart`) and the byte "channel open" (+0x1DA) is set. This byte is never read.  
Removal events of the WCN interface are ignored: the channel stays open when the WCNSS restarts (SSR).

`EvtDeviceReleaseHardware` and `EvtDeviceSurpriseRemoval` close the channel (`CloseSmdChannel`, `sub_401F6C`: [internal IOCTL 0x22007](#internal-ioctl-0x22007), `WdfIoTargetClose`, delete the I/O target). `EvtDeviceSurpriseRemoval` also completes the pending [IOCTL 0x99002654](#ioctl-0x99002654) with `STATUS_SUCCESS`.  
The cleanup callback of the device unregisters the PnP notification.  
Unlike most of the Qualcomm drivers, there's no `KeBugCheckEx` on surprise removal (the only `KeBugCheckEx` calls are in the `/GS` failure handler).

Device context `FM_TRANSPORT_DEVICE_CONTEXT` (packed, hence the unaligned offsets):  
| Offset | Comment |
|--------|---------|
| 0x000 | WDFDEVICE |
| 0x004 | PnP notification entry (`IoRegisterPlugPlayNotification`) |
| 0x008 | WDFWAITLOCK |
| 0x1A6 | Copy of the last `DEVICE_INTERFACE_CHANGE_NOTIFICATION` (40 bytes): +0x1AA event GUID, +0x1BA interface class GUID, +0x1CA symbolic link pointer |
| 0x1CE | WDFIOTARGET on `\Device\SMD` (channel `APPS_FM`) |
| 0x1D2 | Write context, compared in the cancel routine but never written (always 0) |
| 0x1D6 | Read context, compared in the cancel routine but never written (always 0) |
| 0x1DA | "Channel open" byte, written but never read |
| 0x1DB | WDFREQUEST of the pending [IOCTL 0x99002654](#ioctl-0x99002654) |

### SMD channel

`OpenSmdChannel` (`sub_401D54`):
1. `WdfIoTargetCreate` + `WdfIoTargetOpen` on `\Device\SMD` (open by name, `DesiredAccess` 0x1F0000 = `STANDARD_RIGHTS_ALL`, `ShareAccess` 3, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`).
2. Sends [internal IOCTL 0x22003](#internal-ioctl-0x22003) synchronously **without timeout**: the work item blocks until the WCNSS opens its side of `APPS_FM`.

| SMD channel | Edge | Mode | FIFO size |
|-------------|------|------|-----------|
| `APPS_FM` | 6 = APPS↔RIVA | packet | 0x2000 |

Data path: one IOCTL = one SMD request, no buffering in the driver.  
- [IOCTL 0x9900264C](#ioctl-0x9900264c) → `WdfIoTargetFormatRequestForRead` on the channel (`SmdRead`, `sub_4018E8`).
- [IOCTL 0x99002650](#ioctl-0x99002650) → `WdfIoTargetFormatRequestForWrite` on the channel (`SmdWrite`, `sub_401C00`).

The user buffer is wrapped with `WdfMemoryCreatePreallocated` (no copy), the IOCTL request is marked cancelable and the SMD request is sent asynchronously. The completion routine (`loc_40182C`) dispatches on the request type: `sub_401848` for a read, `sub_401AE4` for a write. It completes the IOCTL with the status of the SMD request.

> [!NOTE]
> The cancel routine (`sub_4016EC`) compares the request with the read and write contexts at +0x1D6 and +0x1D2, which are never set. So cancelling a pending read or write does nothing: the request stays pending until qcsmd8930.sys completes it (e.g. until a packet arrives from the FM core).

---

### IOCTL 0x9900264C

This IOCTL is processed by Qcfmtransport8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9900 |
| Function | 0x993 (2451) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read a packet from the FM core | 0 | ≥ 1 (any) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | Packet received on the SMD channel `APPS_FM` (FM HCI event ?) |

Sends an SMD read of `OutputBufferLength` bytes into the output buffer and pends the IOCTL until qcsmd8930.sys completes the read.  
`BytesReturned` = `Parameters.Read.Length` of the completed SMD request.  
Returns `STATUS_DEVICE_NOT_READY` (0xC00000A3) when the SMD channel isn't open yet (WCNSS not started).

---

### IOCTL 0x99002650

This IOCTL is processed by Qcfmtransport8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9900 |
| Function | 0x994 (2452) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write a packet to the FM core | ≥ 1 (any) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | Packet sent as is on the SMD channel `APPS_FM` (FM HCI command ?) |

Sends an SMD write of `InputBufferLength` bytes and pends the IOCTL until qcsmd8930.sys completes the write.  
`BytesReturned` is always 0.  
Returns `STATUS_DEVICE_NOT_READY` (0xC00000A3) when the SMD channel isn't open yet.

---

### IOCTL 0x99002654

This IOCTL is processed by Qcfmtransport8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x9900 |
| Function | 0x995 (2453) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Wait for the removal of the device ? | 0 | 0 |

The buffers are ignored. The request is stored in the device context (+0x1DB) and marked cancelable; the driver never completes it by itself. It's completed:
- with `STATUS_SUCCESS` by `EvtDeviceSurpriseRemoval`,
- with `STATUS_CANCELLED` (0xC0000120) by the cancel routine or by `EvtIoStop` (queue stopped or purged, e.g. on power down).

Only one request is tracked: a second one overwrites the first (the first then can only be completed by its cancellation).

Any other IOCTL code is completed with `STATUS_SUCCESS` and 0 bytes.

---

### internal IOCTL 0x22003

This IOCTL is sent by Qcfmtransport8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) (`OpenSmdChannel`, `sub_401D54`).  
It's sent synchronously, without timeout, on the I/O target opened on `\Device\SMD`.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Open a SMD channel | \Device\SMD | 28 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the ANSI name of the SMD channel: `APPS_FM` |
| 04-07 | 06 00 00 00 | Edge: 6 = APPS↔RIVA (WCNSS) |
| 08-0B | 11 00 00 00 | Flags. 0x10 = wait until the RIVA has opened its side of the channel before completing. 0x01 is ignored by qcsmd8930.sys. 0x02 is not set, so the channel is in packet mode |
| 0C-0F | 00 20 00 00 | FIFO size: 0x2000 bytes |
| 10-13 | 00 00 00 00 | No `PKEVENT` for "data received" |
| 14-17 | 00 00 00 00 | No `PKEVENT` for "channel opened" |
| 18-1B | 00 00 00 00 | No `PKEVENT` for "remote close ?" |

Same values as [qcbluetooth8930.sys](./qcbluetooth8930.md#internal-ioctl-0x22003) for its channels. If the IOCTL fails, the I/O target is deleted and the channel will only be opened again on the next arrival of the WCN interface.

---

### internal IOCTL 0x22007

This IOCTL is sent by Qcfmtransport8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22007) (`CloseSmdChannel`, `sub_401F6C`) in `EvtDeviceReleaseHardware` and `EvtDeviceSurpriseRemoval`, synchronously and without timeout. The I/O target is then closed and deleted.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Close a SMD channel | \Device\SMD | 0 | 0 |

---

### Interface GUID

Qcfmtransport8930 device interface (`WdfDeviceCreateDeviceInterface` + `WdfDeviceSetDeviceInterfaceState` in `EvtDriverDeviceAdd`), presumably used by the user-mode FM radio stack to find the driver:  
`{BF6A982B-2096-4E02-A0F5-B052D009FA7F}`

### Other GUID

WCN device interface of [qcwcn8930.sys](./qcwcn8930.md#interface-guid) (PnP notification target)  
`{917DF3C3-4938-4056-8F74-D3501BCD51EA}`

`GUID_DEVICE_INTERFACE_ARRIVAL`  
`{CB3A4004-46F0-11D0-B08F-00609713053F}`
