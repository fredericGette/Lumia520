## Qcepmadc8930.sys

Qualcomm EPM ADC driver: "Reads the current and voltage EPM channels" (version resource, 1.0.3058.0000, `P:\EpmAdc\rel\8.2.1.1\arm\Release\qcepmadc8930.pdb`).  
It's a KMDF driver with a single IOCTL, `0x9ADC2400`, that returns one voltage or current reading. The reading doesn't come from local hardware: the driver is a **QMI client** of a modem service (QMI service 0x13). The client part is the Qualcomm Common Interface library (QCCI) compiled into the driver. The messages travel over [qcipcrouter8930.sys](./qcipcrouter8930.md) (`\Device\IPC`) or [qcqmux8930.sys](./qcqmux8930.md) (`\Device\QMUX`).  
Its only known client is the power meter driver [qcepm8930.sys](./qcepm8930.md), which reads the battery current with it.  
This isn't the ADC driver of interface `{10542F20-…}` (`IOCTL_ADC_GET_CHANNEL` / `IOCTL_ADC_READ`, device type `0x8ADC`) used by [NokiaEnergyDriver.sys](./nokiaenergydriver.md), [qcpep8930.sys](./qcpep8930.md), [qcbattmngr8930.sys](./qcbattmngr8930.md) and [qcepm8930.sys](./qcepm8930.md); that driver is still undocumented.

There's no named `\Device\` object (the WDF device is unnamed).  
Symbolic link : `\??\QCOM_EPM_ADC`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>` (service name ?)

There's no parameters in the registry.

GUID of the WPP provider:  
`{D50FBFFA-8C91-4367-A196-1D29E94D7B12}`

It communicates with the following devices. Both transports are registered at device creation (sub_401F54). Each one waits for its interface with `IoRegisterPlugPlayNotification`, then opens the device by name:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\IPC` (interface `{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`) | [qcipcrouter8930.sys](./qcipcrouter8930.md) | QCCI "IPC router" transport (sub_4039D8). Uses `IOCTL_IPC_READ_OOB` and read requests (log strings of `qcci_xport_ipc_wdf_event_peek_cb_workitem`) |
| `\Device\QMUX` (interface `{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`) | [qcqmux8930.sys](./qcqmux8930.md) | QCCI "QMUX" transport (sub_404678). Registered 6 times with the values 16…21 (instance / port ?). The binary also holds the SMD channel names `DATA5_CNTL`…`DATA14_CNTL` and `SDIO0_CNTL`…`SDIO7_CNTL` (`.data:0x00409178`) |
| — | [qcepm8930.sys](./qcepm8930.md) | Client. Opens the interface `{75EC568A-…}` and sends `0x9ADC2400` with `{1, 7}` (battery current) |

### Startup

`EvtDriverDeviceAdd` (sub_40B008):
1. Empty PnP/power callbacks. File object callbacks: `EvtDeviceFileCreate` = sub_4019D4, `EvtFileClose` = sub_401A48 (passive level, no synchronization).
2. `WdfDeviceCreate` (context `EPM_ADC_DEVICE_CONTEXT`, cleanup sub_401AB8), symbolic link `\??\QCOM_EPM_ADC`, device interface `{75EC568A-D2EA-48FE-AE3D-395A7B45E65F}`.
3. Default queue (sub_40B58C, sequential): `EvtIoDeviceControl` = sub_401D7C, `EvtIoInternalDeviceControl` = sub_401E30 (both accept only `0x9ADC2400`, otherwise `STATUS_INVALID_DEVICE_REQUEST` 0xC0000010), `EvtIoStop` = sub_401EE4.
4. sub_401300: creates the wait lock of the context (`+0x1C`) and registers the two QCCI transports (sub_401F54).

The QMI client isn't created at startup:
* **First open** (sub_4019D4 → sub_4013DC): sets the "opened" flag (`+0x20`) and increments the open count (`+0x24`).
* **First IOCTL** after an open: `qmi_client_notifier_init` (sub_4028F0) on the service object `.rdata:0x004082B4`. It waits **up to 10 s** for the service to be published, then `qmi_client_get_service_list` (sub_403218) and `qmi_client_init` (sub_402B28). The indication callback is sub_401574. On success the flag `+0x21` is set.
* **Last close** (sub_401A48): clears the flags `+0x20`, `+0x21`, `+0x28` and releases the QMI client (`qmi_client_release`, sub_4031A8).

[qcepm8930.sys](./qcepm8930.md) keeps its handle open for `ActivityTimeout` seconds after the last measurement, so the QMI client lives as long as that handle.

`EPM_ADC_DEVICE_CONTEXT` (partial):  
| Offset | Comment |
|--------|---------|
| +0x00 | Pointer to the QCCI OS parameters (`.data:0x00409C60`) |
| +0x04 | WDFDEVICE |
| +0x08 | Current WDFREQUEST |
| +0x0C | Input `00-03` of the current request (type ?) |
| +0x10 | Input `04-07` of the current request (channel ?) |
| +0x1C | WDFWAITLOCK |
| +0x20 | BYTE: at least one handle opened |
| +0x21 | BYTE: QMI client initialised |
| +0x24 | Open count |
| +0x28 | BYTE: battery voltage check passed (see the IOCTL) |

### QMI service

Service object (`qmi_idl_service_object`, `.rdata:0x004082B4`):  
| Field | Value |
|-------|-------|
| Library version | 2 |
| IDL version | 1 |
| Service id | 0x13 (EPM ?) |
| Max message length | 0x800D |
| Number of requests / responses / indications | 5 / 5 / 2 |
| IDL minor version | 2 ? |

Only message **0x21** is used:
1. Request 0x21 with the 8 bytes of the IOCTL input (type ?, channel ?), sent synchronously (sub_402E48, `qmi_client_send_msg_sync`, response timeout 0.5 s). The response (8 bytes, `qmi_response_type`) must have result 0.
2. The value comes back in indication 0x21. The indication callback (sub_401574) decodes it into a 28-byte structure. `+0x00` = 1 means valid (stored in `byte_409C78`); the reading is at `+0x10` (stored in `dword_409C7C`). The callback then sets the event `unk_409C68`.
3. sub_401068 waits **0.5 s** for that event.

The reading is a global variable, not stored per request: concurrent requests are serialized only by the sequential queue.

---

### IOCTL 0x9ADC2400

This IOCTL is processed by Qcepmadc8930.sys (`EvtIoDeviceControl` and `EvtIoInternalDeviceControl`)

| Property | Value |
|----------|-------|
| Device | 0x9ADC |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (read EPM channel) | 8 (exact) | 12 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 01 00 00 00 | Measurement type ? 0 = voltage, ≠ 0 = current ? |
| 04-07 | e.g. 07 00 00 00 | Channel ? (1 = battery voltage ?, 7 = battery current ?) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | 0 = success, 1 = failure |
| 04-07 | ? | Reading (`+0x10` of indication 0x21): mV for type 0, µA ? for the current |
| 08-0B | FF FF 00 00 | Always 0xFFFF (unused ?) |

Handler `sub_401BF0` → `sub_401144`:
1. Input length ≠ 8 or output length ≠ 12 → `STATUS_UNSUCCESSFUL` (0xC0000001). The output is zeroed, then `00-03` = 1 and `08-0B` = 0xFFFF.
2. No handle opened (`+0x20` = 0) → failure.
3. Creates the QMI client if needed (see [Startup](#startup)).
4. First request with a type ≠ 0 since the last close: reads type 0 / channel 1 once. If the value is < 3200 (mV, battery voltage ?), the request fails. Otherwise the flag `+0x28` is set and the check isn't repeated.
5. Sends QMI request 0x21 with the input and waits for the indication. On success `00-03` = 0 and `04-07` = value.

The request is completed with `STATUS_SUCCESS` and 12 bytes on success, otherwise `STATUS_UNSUCCESSFUL` (0xC0000001) and 0 bytes, so the `00-03` field is never seen as 1.

---

### Interface GUID

EPM ADC device interface (created by qcepmadc8930.sys)  
`{75EC568A-D2EA-48FE-AE3D-395A7B45E65F}`

### Other GUID

IPC router interface (consumed)  
`{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`

QMUX interface (consumed)  
`{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`

WPP control GUID  
`{D50FBFFA-8C91-4367-A196-1D29E94D7B12}`
