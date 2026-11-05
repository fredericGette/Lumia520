## Nokia_cam_esp.sys

Nokia camera "ESP" driver: a small mailbox between the camera driver and the rest of the system.  
It controls no hardware: no resources, no peer device, no PnP or power callback. It only keeps a few global variables, written and read through IOCTLs:
* [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x222410-0x222414-0x222424--esp) tells it when the camera is powered on or off, and reads the last orientation and the thermal limit while the viewfinder runs.
* An unidentified client (see [Clients](#clients)) gets a named event when the camera state changes, and writes the device orientation.
* The Windows thermal framework can set a thermal limit through `GUID_THERMAL_COOLING_INTERFACE`.

KMDF 1.11, PDB path `e:\build_e\trwnwp045\workspace\Camera_to_8227\output\camera\ESP\fre\nokia_cam_esp.pdb`. Pool tag `0rcq`. The meaning of "ESP" isn't given in the binary.

ACPI node: `\_SB.CESP`, `_HID` `CESP0001`, `_UID` 1, with no `_CRS` ([DSDT](../acpi/dsdt.dsl)).

There's no device name and no symbolic link: the device is reached through its [device interface](#interface-guid).  

There's no parameters in the registry.

There's no ETW provider.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{E5FDE9D7-7A0E-4048-81BB-A77CAF7B349F}` (exposed) | [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x222410-0x222414-0x222424--esp) | Client, opened with `IoGetDeviceObjectPointer` (`GENERIC_READ` \| `GENERIC_WRITE`). Sends 0x222410, 0x222414 and 0x222424 |
| Interface `{E5FDE9D7-7A0E-4048-81BB-A77CAF7B349F}` (exposed) | ? | Client of 0x222400, 0x222408, 0x22240C, 0x222418 and 0x22241C, see [Clients](#clients) |
| Query interface `{ECBE47A8-C498-4BB9-BD70-E867E0940D22}` (exposed) | thermal manager ? | See [Thermal limit](#thermal-limit) |

### Initialization

`DriverEntry` (0x406008) only calls `WdfDriverCreate`, with `EvtDriverDeviceAdd` (0x405020) and no unload callback.  
`sub_40502C`, called by `EvtDriverDeviceAdd`:
1. Sets the request context (`REQUEST_CONTEXT`, 4 bytes, unused).
2. Creates the device: `DEVICE_CONTEXT` (4 bytes, unused), `WdfSynchronizationScopeQueue`, `WdfExecutionLevelPassive`. The WDFDEVICE is kept in `dword_403AB8`.
3. Creates the device interface.
4. Creates the default queue (`sub_405140`): `WdfIoQueueDispatchSequential`, `EvtIoDeviceControl` = `EvtWdfIoQueueIoDeviceControl` (0x401678), `QUEUE_CONTEXT` of 4 bytes (holds the WDFDEVICE ?), no-op destroy callback `sub_40164C`. The requests are processed one at a time.
5. Enables the device interface.
6. Registers the [thermal query interface](#thermal-limit) (`sub_401568`). The status of this call is ignored.

### Global state

All the state is in global variables, not in the device context. `byte_403AB0` says if they are initialized: every function tests it and, if it's 0, sets everything to 0 except the thermal limit (100) before going on.

| Address | Size | Comment |
|---------|------|---------|
| `.data:0x403A88` | 4 | Status flags. Only bit 0 is used: 1 = camera powered on |
| `.data:0x403A8C` | 4 | Orientation record: "data valid" |
| `.data:0x403A90` | 4 | Orientation record: float X |
| `.data:0x403A94` | 4 | Orientation record: float Y |
| `.data:0x403A98` | 4 | Orientation record: float Z |
| `.data:0x403A9C` | 4 | `PKEVENT` of the [named event](#named-event) |
| `.data:0x403AA0` | 4 | Handle of the named event. Never closed |
| `.data:0x403AA4` | 1 | Camera powered on (same information as bit 0 of `0x403A88`) |
| `.data:0x403AA8` | 4 | [Reader timeout](#reader-timeout) counter |
| `.data:0x403AAC` | 4 | [Thermal limit](#thermal-limit) in percent, default 100 |
| `.data:0x403AB0` | 1 | Globals initialized |
| `.data:0x403AB8` | 4 | WDFDEVICE |

The orientation record isn't cleared when the camera is powered off, and the driver doesn't tell if it's recent: a reader can get old values.

### Named event

Name: `\BaseNamedObjects\CamDrvOrientationInterfaceUpdate`  
It's a notification event, created or opened by `IoCreateNotificationEvent` when [IOCTL 0x222400](#ioctl-0x222400) is received.  
`sub_40108C` signals it with `KeSetEvent` each time the camera state changes (IOCTL 0x222410, IOCTL 0x222414, reader timeout).  
> [!NOTE]
> The driver never resets the event: the client has to do it. Before IOCTL 0x222400 is received there's nothing to signal: `sub_40108C` returns `STATUS_INVALID_SERVER_STATE` (0xC00000DC), which all its callers ignore. Each additional IOCTL 0x222400 opens the event again and leaks the previous handle.

### Reader timeout

The driver marks the camera as powered off by itself if the orientation is written but no longer read:
1. Each [IOCTL 0x22240C](#ioctl-0x22240c) increments the counter `dword_403AA8`, before checking its parameters.
2. IOCTL 0x222410, 0x222414, 0x222418 and 0x222424 reset the counter to 0, the last two before checking their parameters.
3. When the counter goes above 1800, `sub_4011D4` calls the same function as [IOCTL 0x222414](#ioctl-0x222414): the camera is marked as powered off, the counter returns to 0 and the event is signaled. The record of the current IOCTL is still stored.

### Thermal limit

`sub_401568` registers `GUID_THERMAL_COOLING_INTERFACE` `{ECBE47A8-C498-4BB9-BD70-E867E0940D22}` with `WdfDeviceAddQueryInterface` (`SendQueryToParentStack` = FALSE, no import, no request callback):  
| Field | Value |
|-------|-------|
| Size | 0x1C |
| Version | 1 |
| Context | Device context |
| InterfaceReference / InterfaceDereference | `nullsub_1` (no-op) |
| Flags | 0 |
| ActiveCooling | NULL |
| PassiveCooling | `sub_401608` |

`PassiveCooling(Context, Percentage)` stores the percentage in `dword_403AAC`, without any check. The value is returned at offset 0x10 of [IOCTL 0x222424](#ioctl-0x222424).

> [!NOTE]
> `Flags` is 0, while [qcamss8930.sys](./qcamss8930.md#passive-cooling) sets `ThermalDeviceFlagPassiveCooling` (2). `\_SB.CESP` is also in no `_TZD` of the DSDT or SSDT. So the Lumia 520 thermal zones don't seem to use this interface, and the limit should stay at 100 ?

### Clients

qccamavs8930.sys is the only known client, and it sends 3 of the 8 IOCTLs. Among the binaries examined so far, none other contains the interface GUID or the event name, so the client that writes the orientation isn't identified. Its expected sequence is ?:
1. IOCTL 0x222400 to create the event.
2. Wait for the event, then IOCTL 0x22241C or 0x222408 to get the camera state.
3. While the camera is on: IOCTL 0x22240C with the orientation.

---

### IOCTL 0x222400

This IOCTL is processed by Nokia_cam_esp.sys  
Client unknown, see [Clients](#clients).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x900 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Create the [named event](#named-event) | 0 | 0 |

`sub_401008`. Any buffer: `STATUS_INVALID_PARAMETER` (0xC000000D). Otherwise `STATUS_SUCCESS`, even if the event can't be created (the return value of `sub_401008` is ignored).

---

### IOCTL 0x222408

This IOCTL is processed by Nokia_cam_esp.sys  
Client unknown, see [Clients](#clients).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x902 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the status flags | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 / 01 00 00 00 | Status flags (`dword_403A88`). Bit 0: camera powered on |

`sub_401154`. Returns `STATUS_SUCCESS` with 4 bytes of information, or `STATUS_INVALID_PARAMETER` (0xC000000D) if there's an input buffer or the output buffer is too small.

---

### IOCTL 0x22240C

This IOCTL is processed by Nokia_cam_esp.sys  
Client unknown, see [Clients](#clients).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x903 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Write the orientation | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | "Data valid": ≠ 0 means that the 3 floats can be used |
| 04-07 | ? | X (float) |
| 08-0B | ? | Y (float) |
| 0C-0F | ? | Z (float) |

`sub_4011D4`. Stores the record whatever the state of the camera. Returns `STATUS_SUCCESS`, or `STATUS_INVALID_PARAMETER` (0xC000000D) if the input size isn't 16 or there's an output buffer. See also [Reader timeout](#reader-timeout).

The name X, Y, Z is an interpretation ?, from the event name and the way qccamavs8930.sys uses the values, see [IOCTL 0x222424](#ioctl-0x222424).

---

### IOCTL 0x222410

This IOCTL is processed by Nokia_cam_esp.sys  
It's sent by [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x222410-0x222414-0x222424--esp) ("Sending poweron notification to ESP driver", `sub_46E294`).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Camera power ON notification | 0 | 0 |

`sub_4012AC`. Resets the timeout counter, sets the "camera powered on" byte and bit 0 of the flags, signals the [named event](#named-event). The buffer sizes aren't checked. Always returns `STATUS_SUCCESS`.

---

### IOCTL 0x222414

This IOCTL is processed by Nokia_cam_esp.sys  
It's sent by [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x222410-0x222414-0x222424--esp) (`sub_46E100`).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x905 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Camera power OFF notification | 0 | 0 |

`sub_401358`. Resets the timeout counter, clears the "camera powered on" byte and bit 0 of the flags, signals the [named event](#named-event). The buffer sizes aren't checked. Always returns `STATUS_SUCCESS`.

---

### IOCTL 0x222418

This IOCTL is processed by Nokia_cam_esp.sys  
Client unknown, see [Clients](#clients).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x906 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read the orientation | 0 | 16 |

Outputbuffer: the record of [IOCTL 0x22240C](#ioctl-0x22240c).

Handled in `EvtWdfIoQueueIoDeviceControl` with `sub_401100`. Returns `STATUS_SUCCESS` with 16 bytes of information, or `STATUS_INVALID_PARAMETER` (0xC000000D) if there's an input buffer or the output size isn't 16.

---

### IOCTL 0x22241C

This IOCTL is processed by Nokia_cam_esp.sys  
Client unknown, see [Clients](#clients).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x907 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the camera state | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 / 01 00 00 00 | 1 = camera powered on (`byte_403AA4`) |

`sub_4014CC`. Returns `STATUS_SUCCESS` with 4 bytes of information, or `STATUS_INVALID_PARAMETER` (0xC000000D) if there's an input buffer or the output size isn't 4.  
Because only bit 0 of the flags is used, it returns the same value as [IOCTL 0x222408](#ioctl-0x222408).

---

### IOCTL 0x222424

This IOCTL is processed by Nokia_cam_esp.sys  
It's sent by [qccamavs8930.sys](./qccamavs8930.md#ioctl-0x222410-0x222414-0x222424--esp) (`RunNokiaComponents`, `sub_471FCC`).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x909 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read the orientation and the thermal limit | 0 | 20 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | "Data valid", see [IOCTL 0x22240C](#ioctl-0x22240c) |
| 04-07 | ? | X (float) |
| 08-0B | ? | Y (float) |
| 0C-0F | ? | Z (float) |
| 10-13 | 64 00 00 00 | [Thermal limit](#thermal-limit) in percent, default 100 |

`sub_401404`. Returns `STATUS_SUCCESS` with 20 bytes of information, or `STATUS_INVALID_PARAMETER` (0xC000000D) if there's an input buffer or the output size isn't 20.

---

### Other codes

Any other code, including 0x222404 and 0x222420, returns `STATUS_NOT_SUPPORTED` (0xC00000BB).  
For all codes, a request whose input or output buffer can't be retrieved completes with the error of `WdfRequestRetrieve*Memory`, or `STATUS_UNSUCCESSFUL` (0xC0000001) if the buffer pointer is NULL.

---

### Interface GUID

Nokia_cam_esp Interface Class GUID  
`{E5FDE9D7-7A0E-4048-81BB-A77CAF7B349F}`

### Other GUID

Thermal cooling interface exposed (`GUID_THERMAL_COOLING_INTERFACE`, `WdfDeviceAddQueryInterface`)  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`
