## Qcssm8930.sys

Secure Services Module (SSM) driver.  
It relays a small text protocol between the MODEM and the TrustZone: the MODEM sends a key exchange request over the SMD channel `SSM_RTR` ([qcsmd8930.sys](./qcsmd8930.md)), the driver forwards it to the TrustZone with a TZ syscall through [qcscm8930.sys](./qcscm8930.md), and returns the status to the MODEM. In the other direction, a client of `\DosDevices\SSM` can ask a QSEE trustlet (name read from the registry value `TzappName`) for a "mode update" message and send it to the MODEM (see [IOCTL 0x80092410](#ioctl-0x80092410)).  
The protocol looks like the one of the Qualcomm Linux driver `ssm.c` (same message header `%10u|%10u|%10u|%10u|`), the message names below are tentative.  
Built from `P:\SSM\rel\8.2.1\arm\Release\qcssm8930.pdb` (build date "Mar 24 2014 19:50:41").

Device name : `\Device\SSM`  
Symbolic link : `\DosDevices\SSM`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM2123\0` ?  

Registry value read from the driver's **service key** (`WdfDriverGetRegistryPath` + `WdfRegistryOpenKey` with KEY_READ, not the `Parameters` subkey) by `sub_40279C`:  
| Registry value | value | comment |
|----------------|-------|---------|
| TzappName | ? | REG_SZ. Name of the QSEE trustlet used by [IOCTL 0x80092410](#ioctl-0x80092410), converted to ANSI (max 32 bytes). Read the first time the trustlet is needed |

GUID of the WPP control provider:  
`{d807c0c6-fb57-4bd5-94f1-6b1b1abaaef3}`  
WPP trace message GUIDs: `{da4b372f-fc02-84f0-f058-e3893e433736}`, `{aabbe608-3343-983c-0474-5a409d764bd1}`, `{f9361e43-7d54-1096-998a-a3a411b71de2}`, `{5d0665a5-487d-e8ef-7242-a325ff38cd72}`, `{e78e63f3-1ff1-c1b8-d546-b352d57cb900}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Shared Memory Driver. Opened by name once the interface `{f9d15453-8335-434c-aa72-fcd925f135f3}` has arrived. Channel `SSM_RTR` opened with [internal IOCTL 0x22003](#internal-ioctl-0x22003), then plain read/write requests |
| Interface `{41c66d2a-a9f1-40ca-a329-ae096c03ee68}` | [qcscm8930.sys](./qcscm8930.md) | Secure Channel Manager. Found with `IoRegisterPlugPlayNotification`, opened with `WdfIoTargetOpen` on the symbolic link. TZ syscalls with [internal IOCTL 0xC3514004](#internal-ioctl-0xc3514004) |

### WDF setup

`EvtDriverDeviceAdd` (0x40948C):
- IO type: `WdfDeviceIoBuffered`. Name `\Device\SSM`, file object config with no callbacks.
- Device interface `{cb14e201-cda4-4175-bed9-c8f2a76796d6}` (`WdfDeviceCreateDeviceInterface`).
- Starts the two system threads described below (`sub_40333C` → SMD thread, `sub_40424C` → SCM thread).
- Symbolic link `\DosDevices\SSM`.
- Default queue: sequential dispatch, only `EvtIoDeviceControl` = `sub_40113C`. There's no internal IOCTL.
- A WDF timer (`sub_401BC0` sets an event). `sub_401C08` starts it for 100 ms and waits: it's the delay between two write retries.

Device context (`SSM_DEVICE_CONTEXT`):  
| Offset | Content |
|--------|---------|
| 0x00 | WDFDEVICE |
| 0x08 | Key exchange done: 1 after a successful TZ command 0x2C01, 0 when the MODEM closes the channel. Returned by [IOCTL 0x80092408](#ioctl-0x80092408) |
| 0x0C | Mode update status, returned by [IOCTL 0x80092418](#ioctl-0x80092418): 0 = success (or nothing done), 1 = failure, 2 = in progress, 3 = sent, waiting for the MODEM |
| 0x10 | `SSM_RTR` opened by the MODEM |
| 0x14 | `SSM_RTR` closed by the MODEM (cleared when it's opened again) |
| 0x18 | Application ID of the `TzappName` trustlet. Returned by [IOCTL 0x8009240C](#ioctl-0x8009240c) |
| 0x1C | Application ID valid |
| 0x20 | WDFTIMER |

Pool tags: `qsn0` (driver), `qsna` (SSM messages), `qsn1`, `qsn2`, `qsn3`, `qsn4`, `qsn5`, `qsno`.

### Start-up

SCM thread (`sub_4042D0`): registers a notification for the interface `{41c66d2a-a9f1-40ca-a329-ae096c03ee68}` of [qcscm8930.sys](./qcscm8930.md) (`sub_404170` copies the symbolic link and sets an event on arrival), waits for it, then opens it as a remote I/O target (global `dword_407B38`).

SMD thread (`sub_4033C0`):
1. Registers a notification for the interface `{f9d15453-8335-434c-aa72-fcd925f135f3}` of [qcsmd8930.sys](./qcsmd8930.md) (`sub_40328C`) and waits for it.
2. Opens `\Device\SMD` as a remote I/O target (global `dword_407B34`), and opens the channel `SSM_RTR` with [internal IOCTL 0x22003](#internal-ioctl-0x22003) (edge 0 = APPS↔MODEM, flags 1, default FIFO size).
3. Starts the read loop (`sub_409AA4`): one read request of 4096 bytes is always pending. Its completion (`sub_403BD4`) queues a work item (`sub_403D60`) that parses the received data (`sub_402204`, see [SSM messages](#ssm-messages)) when 0 < length < 4096, and sends the read again.
4. Sends `ATOM_SET_DEFAULT_MODE` with the data `0` (`sub_401E04`).
5. Loops forever on `KeWaitForMultipleObjects` (WaitAny) on the 3 events given to 0x22003:
   - data received: the event is only cleared;
   - channel opened by the MODEM: context +0x10 = 1, +0x14 = 0;
   - channel closed by the MODEM (e.g. MODEM restart): context +0x08 = 0, +0x10 = 0, +0x14 = 1, sends the TZ command 0x2C02 (`sub_4020D4`, see [TrustZone requests](#trustzone-requests)) and resets the MODEM→APPS message counter (`sub_404BDC`).

The writes (`sub_409E30`) are asynchronous write requests on the SMD target; the completion routine (`sub_403F54`) frees the message buffer.

### SSM messages

Each message is ASCII text: a 44-byte header made of 4 decimal numbers formatted with `%10u|`, then the data, then `|`.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0A | `        46\|` | Total length of the message (= data length + 45) |
| 0B-15 | `         0\|` | Counter. One counter per direction, incremented after each message |
| 16-20 | `     43696\|` | Message ID (see below) |
| 21-2B | `         1\|` | Data length, at most 104 (0x68) |
| 2C-.. | `0` | Data |
| .. | `\|` | End |

Example: `ATOM_SET_DEFAULT_MODE` sent at start is `        46|         0|     43696|         1|0|`.

The parser (`sub_404C3C`) checks that the total length matches and the data length is ≤ 104; several messages can be in the same read.  
The driver keeps the last message sent (ID, data and length at `.data:0x00407ABC`) to resend it.

| ID | Name ? | Direction | Counter | Processing |
|----|--------|-----------|---------|------------|
| 0xAAAA (43690) | MTOA_KEY_EXCHANGE | MODEM → APPS | MODEM | Data = 2 decimal numbers separated by `@` (at least 3 bytes). Sends the TZ command 0x2C01 with them, then answers `ATOM_KEY_STATUS` |
| 0xAAAB (43691) | ATOM_KEY_STATUS | APPS → MODEM | APPS | Data = `%10u` status: 0 = success, 5 = the TZ returned 0x36 (already done ?), 1 = other error. Up to 6 tries (100 ms apart). On status 0 or 5, once sent, context +0x08 = 1 |
| 0xAAAC (43692) | ATOM_MODE_UPDATE | APPS → MODEM | APPS | Data = mode update message (1–104 bytes), from [IOCTL 0x80092410](#ioctl-0x80092410) or [IOCTL 0x80092414](#ioctl-0x80092414). Sent up to 3 times |
| 0xAAAD (43693) | MTOA_MODE_UPDATE_STATUS | MODEM → APPS | MODEM | Last character of the data `0` → context +0x0C = 0 (success), otherwise 1 |
| 0xAAAE (43694) | MTOA_PREV_INVALID | MODEM → APPS | MODEM | Resends the last message, at most 3 times in a row |
| 0xAAAF (43695) | ATOM_PREV_INVALID | APPS → MODEM | APPS | Sent with the data `%10u` = 2 when a received message can't be parsed, or when a key exchange has less than 3 bytes of data or a mode update status has no data |
| 0xAAB0 (43696) | ATOM_SET_DEFAULT_MODE | APPS → MODEM | APPS | Data `0`. Sent at start and by [IOCTL 0x8009241C](#ioctl-0x8009241c) |

A received message whose counter is lower than the expected one is ignored. The IDs sent by the APPS side are only logged when they're received.

### TrustZone requests

All the requests are sent with [internal IOCTL 0xC3514004](#internal-ioctl-0xc3514004) (`sub_404600`), using the legacy `tzbsp_syscall_req_t` format described in [qcscm8930.sys](./qcscm8930.md#trustzone-syscalls). The cells passed by physical address are allocated with `MmAllocatePagesForMdlEx` + `MmMapLockedPagesSpecifyCache` (non cached, below 4 GB).

| command_id | Service / command | Function | Request |
|------------|-------------------|----------|---------|
| 0x2C01 | 0xB / 1 | `sub_401F9C` | 32 bytes: `len` 0x20, `command_start_off` 0x10, `response_write_off` 0, args: `10-13` 0, `14-17` second number of `MTOA_KEY_EXCHANGE`, `18-1B` first number, `1C-1F` physical address of a 4-byte status cell (initialised to 1). The value of the cell is the result (0 = success) |
| 0x2C02 | 0xB / 2 | `sub_4020D4` | 24 bytes: `len` 0x18, `command_start_off` 0x10, `response_write_off` 0, args: `10-13` 0, `14-17` physical address of a 4-byte status cell. Sent when the MODEM closes `SSM_RTR` (reset of the key ?) |
| 0x3F001 | 0xFC / 1 | `sub_40279C` | QSEE application lookup, 56 bytes: sub-command 0xFF03, physical address of the ANSI `TzappName` (32 bytes), physical address of a 4-byte cell receiving the application ID. Success when the status at offset 0x28 is 0 and the value at 0x2C is 0xEE01 |
| 0x3F401 | 0xFD / 1 | `sub_402CD4` | Send a request to the `TzappName` trustlet, 160 bytes: application ID at 0x10, request code 1 at 0x14. The response gives a status at 0x98 (must be 0), a length at 0x94 (must be ≤ 104) and the mode update message at 0x2C |

---

### IOCTL 0x80092404

This IOCTL is processed by Qcssm8930.sys (`sub_40113C`)

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x901 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 0 | 0 |

Does nothing and returns `STATUS_SUCCESS`.  
Any unknown code returns `STATUS_UNSUCCESSFUL` (0xC0000001).

---

### IOCTL 0x80092408

This IOCTL is processed by Qcssm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x902 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the key exchange state | 0 | > 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Context +0x08: 1 = the MODEM key exchange succeeded |

Information = 4. The OutputBuffer must be **bigger** than 4 bytes (test `> 4`), else `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0x8009240C

This IOCTL is processed by Qcssm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x903 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the trustlet application ID | 0 | > 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Application ID of the `TzappName` trustlet (context +0x18) |

If the ID isn't known yet, `sub_40279C` looks it up first (TZ command 0x3F001). Information = 4. Same `> 4` length test as 0x80092408.

---

### IOCTL 0x80092410

This IOCTL is processed by Qcssm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Mode update from the trustlet | 0 | 0 |

Sets the mode update status to 2, gets a mode update message from the `TzappName` trustlet (`sub_402CD4`, TZ command 0x3F401, request code 1) and sends it to the MODEM as `ATOM_MODE_UPDATE` (`sub_402EE0`, up to 3 tries). The status becomes 3 when the message is sent, 1 on any error. The final result arrives later with `MTOA_MODE_UPDATE_STATUS`, see [IOCTL 0x80092418](#ioctl-0x80092418).  
Returns `STATUS_UNSUCCESSFUL` if the trustlet can't be found or its answer is invalid.

---

### IOCTL 0x80092414

This IOCTL is processed by Qcssm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x905 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Mode update from the caller | 1 to 104 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | Mode update message, sent as is to the MODEM in `ATOM_MODE_UPDATE` |

Same as [IOCTL 0x80092410](#ioctl-0x80092410), but the message comes from the caller instead of the trustlet. Status 2 → 3 when sent, 1 on error. A size of 0 or > 104 returns `STATUS_UNSUCCESSFUL`.

> [!NOTE]
> The data isn't checked by the driver: any process that can open `\DosDevices\SSM` can send a mode update message to the MODEM.

---

### IOCTL 0x80092418

This IOCTL is processed by Qcssm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x906 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the mode update status | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Context +0x0C: 0 = success (MODEM answered `0`) or nothing done yet, 1 = failure, 2 = in progress, 3 = sent, waiting for `MTOA_MODE_UPDATE_STATUS` |

Information = 4.

---

### IOCTL 0x8009241C

This IOCTL is processed by Qcssm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x907 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the default mode | 0 | 0 |

Sends `ATOM_SET_DEFAULT_MODE` with the data `0` to the MODEM, like at start. Up to 6 tries, 100 ms apart. Returns the status of the last write.

---

### IOCTL 0x80092420

This IOCTL is processed by Qcssm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x908 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Test ? | ≥ 30 | ≥ 30 |

Copies the input bytes 0–19 into the output bytes 19–0 (reversed order), and completes with Information = 30. As input and output are the same system buffer, the copy overwrites its own source: the result is bytes 0–9 unchanged and bytes 10–19 = bytes 9–0. Looks like a test stub.

---

### IOCTL 0x80092424

This IOCTL is processed by Qcssm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x8009 |
| Function | 0x909 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Test ? | ≥ 30 | 30 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-13 | | Input, unchanged |
| 14-17 | 78 56 34 12 | 0x12345678 written in the system buffer |
| 18-1D | | Input, unchanged |

Writes 0x12345678 at offset 0x14 of the system buffer, copies the first 30 bytes into a pool buffer (allocated with the InputBuffer size), writes a counter at its offset 0x0A and frees it. Information = 30. Looks like a test stub too.

---

### internal IOCTL 0x22003

This IOCTL is sent by Qcssm8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) (`sub_4030B0`), synchronously, once by the SMD thread.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Open a SMD channel | \Device\SMD | 28 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to `SSM_RTR` |
| 04-07 | 00 00 00 00 | Edge 0 = APPS↔MODEM |
| 08-0B | 01 00 00 00 | Flags: 0x01 (not used by qcsmd8930.sys), packet mode |
| 0C-0F | 00 00 00 00 | FIFO size 0 = 0x2000 |
| 10-13 | ? | `PKEVENT` data received (context of the SMD target +0x0C) |
| 14-17 | ? | `PKEVENT` channel opened (+0x1C) |
| 18-1B | ? | `PKEVENT` remote close (+0x2C) |

---

### internal IOCTL 0xC3514004

This IOCTL is sent by Qcssm8930.sys to [qcscm8930.sys](./qcscm8930.md#internal-ioctl-0xc3514004--ioctl_internal_scm_control_class_syscall) (`sub_404600`), synchronously.

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x1 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_SCM_CONTROL_CLASS_SYSCALL | interface `{41c66d2a-a9f1-40ca-a329-ae096c03ee68}` | 24, 32, 56 or 160 | same as InputBuffer (same buffer) |

See [TrustZone requests](#trustzone-requests) for the requests.

---

### Interface GUID

SSM device interface (`WdfDeviceCreateDeviceInterface`)  
`{cb14e201-cda4-4175-bed9-c8f2a76796d6}`

### Other GUID

Awaited interfaces: SMD `{f9d15453-8335-434c-aa72-fcd925f135f3}` ([qcsmd8930.sys](./qcsmd8930.md)), SCM `{41c66d2a-a9f1-40ca-a329-ae096c03ee68}` ([qcscm8930.sys](./qcscm8930.md))
