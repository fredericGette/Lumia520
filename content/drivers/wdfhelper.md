## WDFHelper.sys

Audio helper driver ("WDF helper" of the Qualcomm audio package, `P:\audio\rel\8.3.1\arm\Release\WDFHelper.pdb`).  
The audio driver [qc8x60aud.sys](./qc8x60aud.md) is a WDM PortCls miniport. It uses this small KMDF driver for two jobs it doesn't do itself:
* [IOCTL 0x50012004](#ioctl-0x50012004--set-tty-mode): sets the **TTY mode** of the modem. WDFHelper.sys is a **QMI client** of the modem Voice service (QMI service 0x09) and sends `QMI_VOICE_SET_CONFIG` (0x0040) with only the TTY mode. The client part is the Qualcomm Common Interface library (QCCI) compiled into the driver, the same code as in [qcepmadc8930.sys](./qcepmadc8930.md). The messages go through [qcipcrouter8930.sys](./qcipcrouter8930.md) (`\Device\IPC`) or [qcqmux8930.sys](./qcqmux8930.md) (`\Device\QMUX`).
* [IOCTL 0x50012008](#ioctl-0x50012008--inject-a-button-event): injects a **button event** (button 10, 2 or 3, pressed or released) into the GPIO buttons driver [msgpiowinphone.sys](./msgpiowinphone.md), by writing to its "TEST_PROXY" raw PDO.

There's no named `\Device\` object (the WDF device is unnamed).  
Symbolic link : `\??\wdfhlpdrv`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>` (service name ?)

There's no parameters in the registry.

GUID of the WPP provider:  
`{50D281BF-B799-456D-BE51-2B7D4C24C0B0}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\IPC` (interface `{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`) | [qcipcrouter8930.sys](./qcipcrouter8930.md) | QCCI "IPC router" transport (sub_4051A4, `IoRegisterPlugPlayNotification`). [IOCTL 0x122000](./qcipcrouter8930.md#ioctl-0x122000), [IOCTL 0x122008](./qcipcrouter8930.md#ioctl-0x122008), [IOCTL 0x122017](./qcipcrouter8930.md#ioctl-0x122017), [IOCTL 0x12201B](./qcipcrouter8930.md#ioctl-0x12201b), read/write of QMI messages (log strings of `qcci_xport_ipc_wdf_event_peek_cb_workitem`) |
| `\Device\QMUX` (interface `{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`) | [qcqmux8930.sys](./qcqmux8930.md) | QCCI "QMUX" transport (sub_405E58, `IoRegisterPlugPlayNotification`). Registered 6 times with the values 16…21 (QMUX ports 0 to 5 ?). [IOCTL 0x12410](./qcqmux8930.md#ioctl-0x12410), [IOCTL 0x12418](./qcqmux8930.md#ioctl-0x12418--ioctl-0x1241c), [IOCTL 0x12430](./qcqmux8930.md#ioctl-0x12430), read/write. The binary also holds the SMD channel names `DATA5_CNTL`…`DATA14_CNTL` and `SDIO0_CNTL`…`SDIO7_CNTL` (`.data:0x0040A190`) |
| Interface `{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}` | [msgpiowinphone.sys](./msgpiowinphone.md) | "GPIO Buttons" raw PDO. First interface returned by `IoGetDeviceInterfaces`, opened by name with `WdfIoTargetOpen` (sub_4011E8). 2-byte button events are written to it with `WdfIoTargetSendWriteSynchronously`, see [IOCTL 0x50012008](#ioctl-0x50012008--inject-a-button-event) |
| — | [qc8x60aud.sys](./qc8x60aud.md) | Client. Opens the interface `{6DB5B55F-…}` and sends [IOCTL 0x50012004](#ioctl-0x50012004--set-tty-mode) and [IOCTL 0x50012008](#ioctl-0x50012008--inject-a-button-event) |

### WDF setup

`DriverEntry` (0x40D008): WPP init, `WdfDriverCreate` with `EvtDriverDeviceAdd` (0x40C37C) only (no unload callback).  
`EvtDriverDeviceAdd` → sub_40C3DC:
1. PnP callbacks: `EvtDevicePrepareHardware` = sub_4013C8, `EvtDeviceReleaseHardware` = sub_40149C. No device name, no file object callbacks.
2. `WdfDeviceCreate` (context `DEVICE_CONTEXT`, 8 bytes: `+0x00` WDM device object, `+0x04` = 0), stored in the global `dword_40AE30`.
3. Default queue (sub_40C5E4): **sequential**, `EvtIoDeviceControl` = 0x40C768, `EvtIoStop` = 0x40C6F0. No `EvtIoInternalDeviceControl`.
4. `WdfDeviceCreateSymbolicLink` `\??\wdfhlpdrv`.

`EvtDevicePrepareHardware` creates the device interface `{6DB5B55F-B7D5-4D95-A0AE-40DD78A17817}` and enables it. `EvtDeviceReleaseHardware` disables it.  
The QMI client and the GPIO buttons I/O target are only created by the first IOCTL that needs them.

All the request state is kept in globals (`dword_40AE60` IoControlCode, `dword_40AE64`/`dword_40AE68` input length/pointer, `dword_40AE6C`/`dword_40AE70` output length/pointer, `dword_40AE74` pending WDFREQUEST): only one request at a time is possible, which the sequential queue guarantees.  
`EvtIoStop`: a cancelable request being suspended is completed with `STATUS_CANCELLED` (0xC0000120) if it can still be unmarked cancelable; on a purge, `WdfRequestCancelSentRequest`. The cancel routine (sub_401388) completes the request with `STATUS_CANCELLED`.

Pool tags: `WDFH` (work items), `qck0` (QCCI).

### QMI service

Service object (`qmi_idl_service_object`, `.rdata:0x00408ECC`):  
| Field | Value |
|-------|-------|
| Library version | 4 |
| IDL version | 2 |
| Service id | 0x09 (Voice) |
| Max message length | 0x1864 |
| Number of requests / responses / indications | 0x23 / 0x23 / 0x0C |

Only message **0x0040** (`QMI_VOICE_SET_CONFIG`) is sent. The request structure (`voice_set_config_req_msg_v02`, 60 bytes, zeroed) has only one field set:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 18 | 01 | `tty_mode_valid` |
| 1C-1F | 03 00 00 00 | `tty_mode`: last value received by [IOCTL 0x50012004](#ioctl-0x50012004--set-tty-mode) (`dword_40AE3C`, initial value 3). `tty_mode_enum_v02`: 0 = FULL, 1 = VCO, 2 = HCO, 3 = OFF |

It's sent with `qmi_client_send_msg_sync` (sub_402D5C, inlined message id 0x40, response timeout **2 s**). The 20-byte response (`qmi_response_type` result + error, then the `*_outcome_valid`/outcome bytes; `tty_mode_outcome_valid`/`tty_mode_outcome` at `0E`/`0F`) is only traced: `result`/`error` aren't checked. sub_40166C returns `STATUS_UNSUCCESSFUL` (0xC0000001) only when the QCCI call itself fails (no client, transport error, timeout).

Connection (sub_4019F8, when the global "connected" flag `dword_40AE38` = 0):
1. Registers the QCCI transports (sub_40329C): IPC router + QMUX ports 16…21. A transport already registered isn't added again.
2. `qmi_client_notifier_init` (sub_4027F4) on the service object, then waits **without timeout** (`KeWaitForSingleObject`, Timeout NULL) for the Voice service to be published. The IOCTL stays pending until then. The notifier handle is never released.
3. `qmi_client_get_service_list` (sub_40312C, 1 entry), `qmi_client_init` (sub_402A2C, client stored in `dword_40ADF4`, no indication callback).
4. `qmi_client_register_error_cb` (sub_403218) with sub_401E98.
5. Sets "connected" and sends the SET_CONFIG request.

Error callback (sub_401E98, e.g. modem restart ?): sets the error flag `dword_40AE34` and queues a work item (sub_4017E8) that releases the client (`qmi_client_release`, sub_4030BC), runs steps 2–4 again, and resends SET_CONFIG with the last TTY mode. On failure "connected" is cleared, so the next IOCTL 0x50012004 reconnects.

---

### IOCTL 0x50012004 — set TTY mode

This IOCTL is processed by WDFHelper.sys (`EvtIoDeviceControl` 0x40C768, then work item sub_401F90 → sub_401D98)  
This IOCTL is sent by [qc8x60aud.sys](./qc8x60aud.md) (interface `{6DB5B55F-B7D5-4D95-A0AE-40DD78A17817}`)  

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set TTY mode ? | 4 (exact) | 4 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | TTY mode (`tty_mode_enum_v02`): 0 = FULL, 1 = VCO, 2 = HCO, 3 = OFF. Not range checked |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Not written (with METHOD_BUFFERED it still contains the input) |

The request is marked cancelable and processed in a system work item (IoQueueWorkItemEx, `DelayedWorkQueue`): the value is stored in `dword_40AE3C`, the QMI client is created if needed (see [QMI service](#qmi-service)), and `QMI_VOICE_SET_CONFIG` is sent with this TTY mode.  
Completed with `STATUS_SUCCESS` or `STATUS_UNSUCCESSFUL` (0xC0000001), `Information` = 4. Wrong buffer sizes → `STATUS_INVALID_PARAMETER` (0xC000000D). Work item allocation failure → the request is completed with `STATUS_SUCCESS` without doing anything (status of `WdfRequestRetrieveOutputBuffer`).

> [!NOTE]
> As the connection waits without timeout for the Voice service, the first IOCTL 0x50012004 can stay pending (and block the sequential queue, so also IOCTL 0x50012008) until the modem publishes the service.

---

### IOCTL 0x50012008 — inject a button event

This IOCTL is processed by WDFHelper.sys (`EvtIoDeviceControl` 0x40C768 → sub_401D98, synchronous)  
This IOCTL is sent by [qc8x60aud.sys](./qc8x60aud.md) (interface `{6DB5B55F-B7D5-4D95-A0AE-40DD78A17817}`)  

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Inject a button event ? | 8 (exact) | 4 (exact) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Button: 1 → button 10, 2 → button 2, 3 → button 3 of [msgpiowinphone.sys](./msgpiowinphone.md) (sub_401134). Other values → `STATUS_INVALID_PARAMETER` (0xC000000D). The DWORD is **overwritten** with the button number |
| 04-07 | 01 00 00 00 | State: 1 = pressed, 0 = released (only the low byte is used) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | NTSTATUS of the write to the GPIO buttons PDO (`STATUS_UNSUCCESSFUL` 0xC0000001 if no I/O target) |

Handler:
1. sub_4011E8 (once): `IoGetDeviceInterfaces({30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A})`, `WdfIoTargetCreate`, `WdfIoTargetOpen` by name of the first interface (`DesiredAccess` 0x1F0000, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`). The I/O target is kept in `dword_40AE40` and never closed. The status of `IoGetDeviceInterfaces` isn't checked and its string list is never freed.
2. sub_401554: writes the 2 bytes `{button, state}` to the target (`WdfIoTargetSendWriteSynchronously`), the injection format of [msgpiowinphone.sys](./msgpiowinphone.md) (see "Writing 2 bytes injects a button event").

Completed with the status of the write, `Information` = 4. Wrong buffer sizes → `STATUS_INVALID_PARAMETER` (0xC000000D).  
On the Lumia 520 buttons 2 and 3 are the volume keys ? (PMIC GPIO3/GPIO8); button 10 (usage F11) has no physical key: probably the headset media button detected by the codec (MBHC) ?.

---

Any other IoControlCode → `STATUS_UNSUCCESSFUL` (0xC0000001).

### Interface GUID

WDFHelper Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{6DB5B55F-B7D5-4D95-A0AE-40DD78A17817}`

### Other GUID

GPIO Buttons raw PDO interface of [msgpiowinphone.sys](./msgpiowinphone.md) (consumed)  
`{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}`

IPC router interface (consumed)  
`{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`

QMUX interface (consumed)  
`{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`
