## WlanProxyDriver.sys

WLAN proxy driver: validates a country code (or a tx power cap) and forwards it to the Wi-Fi miniport.  
It's a tiny KMDF driver (5 functions of its own) with a single device interface and the symbolic link `\DosDevices\WlanProxy`. It accepts 2 IOCTLs, checks their buffer, then opens `\??\QcomWifi` ([qcwlan8930.sys](./qcwlan8930.md)) and sends it [IOCTL 0x122058](#ioctl-0x122058) with the same buffer.  
It doesn't keep any state and doesn't read any file. The build path of the PDB (`E:\build_e\subtask\4B9F4CFE_98\output\wlancountry\fre\WlanProxyDriver.pdb`) shows it belongs to the Microsoft "wlancountry" component (setting the Wi-Fi regulatory domain from the country the phone is in ?).  
Its user-mode client is unknown.

Device name : none (unnamed FDO, no `WdfDeviceInitAssignName`)  
Symbolic link : `\DosDevices\WlanProxy`  

There's no parameters in the registry.  

GUID of the ETW provider (manifest-based, `McGenEventRegister`):  
`{8e8ec24e-5b62-481f-aa10-7919cbb0719d}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \??\QcomWifi | [qcwlan8930.sys](./qcwlan8930.md) | [IOCTL 0x122058](#ioctl-0x122058) "Set the country code" |

It only imports `ntoskrnl.exe` (`ZwOpenFile`, `ZwDeviceIoControlFile`, `ZwClose`, ETW) and `WDFLDR.SYS`.

### WDF configuration

`DriverEntry` (0x406008) registers the ETW provider and calls `WdfDriverCreate` with `EvtDriverDeviceAdd` (0x405494) and `EvtDriverUnload` = `WlanProxyUnload` (0x4054A0, only unregisters the ETW provider).  
`EvtDriverDeviceAdd` jumps to `WlanProxyDeviceCreate` (0x405008):
- `WdfDeviceCreate` with a context `DEVICE_CONTEXT` (holds only the queue handle).
- `WdfDeviceCreateDeviceInterface` with the [interface GUID](#interface-guid).
- `WdfDeviceCreateSymbolicLink` `\DosDevices\WlanProxy`.
- One default **sequential** queue with only `EvtIoDeviceControl` (`EvtWdfIoQueueIoDeviceControl`, 0x405168).

No security descriptor is set by the driver (no `WdfDeviceInitAssignSDDLString`): the access rights come from the INF / device class.

### Processing of a request

`EvtWdfIoQueueIoDeviceControl` (0x405168):
1. `WdfRequestRetrieveInputBuffer(MinimumRequiredSize = InputBufferLength)`. Failure (e.g. empty input buffer) → the request is completed with that status.
2. Validation of the buffer depending on the IoControlCode (see below). Any other code → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).
3. `WlanProxySendToQcomWifi` (0x405384): `ZwOpenFile("\??\QcomWifi", GENERIC_READ | GENERIC_WRITE, OBJ_CASE_INSENSITIVE | OBJ_KERNEL_HANDLE, ShareAccess = FILE_SHARE_READ | FILE_SHARE_WRITE, OpenOptions = 0)`, then `ZwDeviceIoControlFile(0x122058, InputBuffer = request buffer, InputBufferLength = request OutputBufferLength, no OutputBuffer)`, then `ZwClose`.
4. The request is completed with the status of `ZwOpenFile` / `ZwDeviceIoControlFile`, with `BytesReturned` = 0.

> [!NOTE]
> The length of the data is taken from the **OutputBufferLength** of the request, not from its InputBufferLength. With METHOD_BUFFERED the system buffer has max(InputBufferLength, OutputBufferLength) bytes, but only InputBufferLength bytes are copied from the caller: a caller must give the same value for both lengths (e.g. `DeviceIoControl(h, 0x122058, buf, 3, buf, 3, …)`).

A `ZwOpenFile` failure is traced (an extra event "STATUS_ACCESS_DENIED" for 0xC0000022). The handle is opened without `FILE_SYNCHRONOUS_IO_*` and without event: the driver relies on qcwlan8930.sys completing the IOCTL synchronously.

---

### IOCTL 0x122054

This IOCTL is processed by WlanProxyDriver.sys (`EvtWdfIoQueueIoDeviceControl`, 0x405168)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x815 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the maximum tx power (TxPowerCap) | 1 | 1 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | e.g. 0F | Maximum tx power (signed byte), must be > 0 |

OutputBufferLength ≠ 1 → `STATUS_INVALID_PARAMETER` (0xC000000D), event with the length. Value ≤ 0 → `STATUS_INVALID_PARAMETER` ("Non-positive TxPowerCap"). Otherwise the value is traced and the buffer is forwarded.

> [!NOTE]
> `WlanProxySendToQcomWifi` always sends **0x122058** (set the country code): the 1-byte tx power cap is forwarded to `hdd_setCountryCode` of qcwlan8930.sys instead of its [IOCTL 0x122054](./qcwlan8930.md#ioctl-0x122054) (`set_tx_power_cap`). This IOCTL therefore doesn't set the tx power (bug ?).

---

### IOCTL 0x122058

This IOCTL is processed by WlanProxyDriver.sys (`EvtWdfIoQueueIoDeviceControl`, 0x405168), and also sent by WlanProxyDriver.sys to [qcwlan8930.sys](./qcwlan8930.md#ioctl-0x122058)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x816 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

Received:  
| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the country code | 2 to 4 | 2 to 4 (same as InputBuffer) |

Sent:  
| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Set the country code | \??\QcomWifi | OutputBufferLength of the received request (2 to 4; 1 for [IOCTL 0x122054](#ioctl-0x122054)) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | e.g. `46 52` | Country code, 2 ANSI upper-case letters `A`–`Z` (`FR`) |
| 02 | `49`, `4F` or `00` | Optional: `I` (indoor), `O` (outdoor) or 0 |
| 03 | ? | Optional, not checked |

`WlanProxyValidateCountryCode` (0x4052A4):
- OutputBufferLength not in 2..4 → `STATUS_INVALID_PARAMETER` (0xC000000D), event with the length.
- Byte 0 or 1 not in `A`–`Z` → `STATUS_INVALID_PARAMETER` ("Invalid characters in country code").
- Byte 2 present and not `I`, `O` or 0 → `STATUS_INVALID_PARAMETER` ("Country code not Indoor/Outdoor").

The format is the 3-character country string of IEEE 802.11d (`dot11CountryString`).

---

### Interface GUID

WlanProxy Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{f42db1a0-fc1b-4438-b6e9-be17d9bb34b4}`
