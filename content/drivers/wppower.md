## Wppower.sys

Windows Phone power helper driver.  
It's a small root-enumerated KMDF driver (`IoReportRootDevice` in `DriverEntry`) with no hardware resource. It registers itself as a client of the Power Dependency Coordinator (PDC, through `ZwPowerInformation(PdcInvocation)`), keeps a small state machine driven by the PDC notifications and by 4 IOCTLs, and publishes the result in a WNF state. When it needs to wake the screen / keep the system awake it calls `PoSetSystemState(ES_USER_PRESENT)`.  
It also holds a PDC activation reference on component 0x411 from `EvtDriverDeviceAdd` until another WNF state becomes 1 (end of boot ?).  
PDB name: `wppower.pdb`. Driver pool tag `wpwr`.

There's no device name and no symbolic link: the device is only reachable through its [device interface](#interface-guid).  

There's no parameters in the registry.  

There's no ETW provider.  

It doesn't communicate with any other device. It only imports `ntoskrnl.exe` and `WDFLDR.SYS`.

### WDF configuration

`DriverEntry` (0x10003000):
- `WdfDriverCreate` with `EvtDriverDeviceAdd` = `sub_10001800`, `EvtDriverUnload` = `sub_100019A0`, and a driver context `GLOBAL_DATA` (60 bytes, see [Global context](#global-context)).
- `IoReportRootDevice`: the PnP manager creates a root-enumerated device for the driver.
- Initializes the global context, publishes 0 in the [WNF state](#wnf-states) `{75 30 bc a3 22 1d c6 41}`, then registers the main PDC client (`sub_10001E9C`).

`EvtDriverDeviceAdd` (0x10001800):
1. `WdfDeviceCreate` with a device context `FDO_DATA` (8 bytes).
2. `WdfDeviceCreateDeviceInterface` with the [interface GUID](#interface-guid).
3. Creates the PDC client of component 0x411 and takes an activation reference on it (`sub_10001F2C`).
4. `ExSubscribeWnfStateChange` on the WNF state `{75 38 bc a3 3e 06 8a 41}` (callback `sub_1000175C`), then queries it immediately: if its value is already 1, the activation reference is released and the subscription is cancelled.
5. Default parallel queue, `PowerManaged` = `WdfFalse`, `ExecutionLevel` = `WdfExecutionLevelPassive`, `SynchronizationScope` = `WdfSynchronizationScopeNone`, with only `EvtIoDeviceControl` (`sub_100019E8`).
6. A second, manual queue whose handle is stored in `FDO_DATA` +4. It's never used.

`EvtDriverUnload` (0x100019A0): releases and unregisters the component 0x411 client, unsubscribes the WNF state, unregisters the main PDC client.

### Global context

`GLOBAL_DATA` (driver object context, protected by the fast mutex at +0x04):  
| Offset | Init | Comment |
|--------|------|---------|
| 0x00 | 0 | Main PDC client (`PdcN` object) |
| 0x04 | | `FAST_MUTEX` |
| 0x24 | 1 | Byte. 1 = a PDC "enter" notification is accepted immediately. 0 = it's pended |
| 0x25 | 1 | Byte. 0 = a PDC "exit" notification would be pended. Never set to 0 by the code |
| 0x26 | 0 | Byte. Unused |
| 0x27 | 0 | Byte. A PDC "enter" notification is pending |
| 0x28 | 0 | Byte. A PDC "exit" notification is pending |
| 0x29 | 0 | Byte. Value last sent with `ZwPowerInformation(57, &byte, 1)` (`UserPresence` ?) |
| 0x2C | 0 | State of the [state machine](#state-machine) (0 to 4) |
| 0x30 | 0 | Last value published in the WNF state `{75 30 bc a3 22 1d c6 41}` |
| 0x34 | 0 | PDC client of component 0x411 (`Pdcs` object) |
| 0x38 | 0 | WNF subscription to `{75 38 bc a3 3e 06 8a 41}` |

### PDC clients

All the PDC calls go through `ZwPowerInformation(67 = PdcInvocation, buffer, 52)` (`sub_100014B8`). The client object (pool tag `PdcP`, 200 bytes) keeps the component id, the client type and a callback; it is protected by a rundown reference.  
Message types seen (DWORD 6 of the 48-byte message):  
| Type | Direction | Comment |
|------|-----------|---------|
| 0 | → PDC | Register (DWORD 8 = component id, DWORD 9 = client type) |
| 1 | → PDC | Unregister |
| 2 | → PDC | Response to a notification (DWORD 8 = NTSTATUS, DWORD 9 = cookie) |
| 2 | ← PDC | Notification (DWORD 8 = argument, DWORD 9 = cookie). Calls the client callback; if it returns `STATUS_PENDING` (0x103), the response is sent later by `sub_100010D0` |
| 3 | ← PDC | Completion. Calls the second client callback with DWORD 8 |
| 8 | → PDC | Activate (byte at +0x20 = 1) / deactivate (0) |

The clients:  
| Component id | Client type | Pool tag | Function | Comment |
|--------------|-------------|----------|----------|---------|
| 4 | 0 | `PdcN` | `sub_10001000` | Notification client, registered in `DriverEntry`. Callbacks `sub_1000161C` (notification) and `sub_100016E4` (completion: if the status is negative, completes the pending notification with `STATUS_SUCCESS`) |
| 0x411 | 5 | `Pdcs` | `sub_10001350` | Activation reference, taken in `EvtDriverDeviceAdd` and released when the WNF state `{75 38 bc a3 3e 06 8a 41}` becomes 1 |

The meaning of component 4 and 0x411 is unknown. The notification argument is 1 ("enter") or 0 ("exit") (screen off / screen on ?).

`sub_1000161C` (notification callback):
- argument 1: pended (`STATUS_PENDING`, +0x27 = 1) if +0x24 = 0. Otherwise event 0 of the state machine, and publishes 2 in the WNF state.
- argument 0: pended (+0x28 = 1) if +0x25 = 0 (never). Otherwise, if the state is neither 0 nor 2, event 1 of the state machine.

### WNF states

| State name (bytes) | State name (QWORD) | Decoded | Usage |
|--------------------|--------------------|---------|-------|
| `75 30 bc a3 22 1d c6 41` (`.text:0x10004048`) | 0x41C61D22A3BC3075 | Well-known, owner tag `OS`, sequence 6 | Written (`ZwUpdateWnfStateData`, 4 bytes): 0 or 2. Written only when the value changes (cache `dword_10006014`, initial value 3). Read by [ShellChromeAPI.dll](../libraries/shellchromeapi.md#wnf-states) before showing an action dialog during do not disturb |
| `75 38 bc a3 3e 06 8a 41` (`.text:0x10004050`) | 0x418A063EA3BC3875 | Well-known, owner tag `SHL`, sequence 7 | Read (4 bytes). Value 1 → release the activation of the PDC component 0x411. Shell ready ? (`WNF_SHL_START_READY` in [wpcrdmp.sys](./wpcrdmp.md); also read by [ShellChrome.dll](../libraries/shellchrome.md#wnf-states)) |

The names were decoded by XOR with 0x41C64E6DA3BC0074 (version 1, well-known lifetime, system scope, not permanent). Their symbolic names (`WNF_...`) are unknown.

Values of the published state, as written by the code: 0 = normal / user present ?, 2 = "entered" (after a PDC notification with argument 1, or after event 0 in states 2 and 3).

### State machine

`sub_10001C58` / `sub_10001F84`, called with the fast mutex held. Events:  
| Event | Source |
|-------|--------|
| 0 | PDC notification with argument 1. [IOCTL 0x22A000](#ioctl-0x22a000) with a non-zero byte. [IOCTL 0x22A004](#ioctl-0x22a004) when the published value is 0 |
| 1 | PDC notification with argument 0. [IOCTL 0x22A000](#ioctl-0x22a000) with a zero byte. [IOCTL 0x22A004](#ioctl-0x22a004) when the published value isn't 0 |
| 2 | [IOCTL 0x22A008](#ioctl-0x22a008) with a non-zero byte |
| 3 | [IOCTL 0x22A008](#ioctl-0x22a008) with a zero byte |
| 4 | [IOCTL 0x22A00C](#ioctl-0x22a00c) with a non-zero byte |
| 5 | [IOCTL 0x22A00C](#ioctl-0x22a00c) with a zero byte |

"Complete pending" = respond `STATUS_SUCCESS` to the pending PDC notification (+0x27 or +0x28) and clear its flag. "User present" = `PoSetSystemState(ES_USER_PRESENT)`. "Publish n" = write n in the WNF state `{75 30 bc a3 22 1d c6 41}`. "Presence n" = if +0x29 ≠ n, +0x29 = n and `ZwPowerInformation(57, &+0x29, 1)`.  
| State | Event | Action | New state |
|-------|-------|--------|-----------|
| 0 | 0 | | 1 |
| 0 | 1 | User present | 0 |
| 0 | 4 | | 2 |
| 1 | 1 | User present, publish 0 | 0 |
| 1 | 4 | | 4 |
| 2 | 0 | +0x24 = 1, complete pending, publish 2 | 4 |
| 2 | 1 | User present | 2 |
| 2 | 2 | +0x24 = 0 (the next PDC "enter" notifications are pended), presence 1 | 3 |
| 3 | 0 | +0x24 = 1, complete pending, presence 0, publish 2 | 4 |
| 3 | 3 | Complete the pending "exit" if any, else user present; presence 0, publish 0, +0x24 = 1 | 2 |
| 4 | 1 | User present, publish 0 | 2 |
| 4 | 2, 3 | Returns `STATUS_NOT_SUPPORTED` (0xC00000BB) | 4 |
| 2, 3, 4 | 5 | Complete the pending "exit" (and publish 0) if any, else user present; +0x24 = 1, presence 0, publish 0 | 0 |

Any other combination does nothing. So [IOCTL 0x22A00C](#ioctl-0x22a00c) enables (states 2–4) or disables (states 0–1) a mode, and [IOCTL 0x22A008](#ioctl-0x22a008) blocks the PDC "enter" notifications while this mode is enabled (state 3).

---

### IOCTL 0x22A000

This IOCTL is processed by Wppower.sys (`EvtIoDeviceControl`, `sub_100019E8`).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x800 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | 0 → event 1, other → event 0 of the [state machine](#state-machine) |

Completed with the status of the state machine.

---

### IOCTL 0x22A004

This IOCTL is processed by Wppower.sys (`EvtIoDeviceControl`, `sub_100019E8`).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x801 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Toggle ? | 0 | ≥ 1 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | 1 if the published WNF value was 0, else 0 |

Then the byte returned is used like the input of [IOCTL 0x22A000](#ioctl-0x22a000): 1 → event 0, 0 → event 1. So it toggles between the two.  
Completed with `BytesReturned` = 1 (0 if the output buffer is too small).

---

### IOCTL 0x22A008

This IOCTL is processed by Wppower.sys (`EvtIoDeviceControl`, `sub_100019E8`).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x802 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Other than 0 → event 2, 0 → event 3 of the [state machine](#state-machine) |

---

### IOCTL 0x22A00C

This IOCTL is processed by Wppower.sys (`EvtIoDeviceControl`, `sub_100019E8`).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x803 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Other than 0 → event 4, 0 → event 5 of the [state machine](#state-machine) |

---

All the IOCTLs first check `SeSinglePrivilegeCheck(SeShutdownPrivilege (19), PreviousMode)`: without the privilege → `STATUS_PRIVILEGE_NOT_HELD` (0xC0000061).  
A buffer smaller than 1 byte → `STATUS_BUFFER_TOO_SMALL` (from `WdfRequestRetrieveInputBuffer` / `WdfRequestRetrieveOutputBuffer`).  
Any other IoControlCode → `STATUS_NOT_SUPPORTED` (0xC00000BB).

### Interface GUID

Wppower Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{e7897923-66a3-46b2-bdff-da7e4098e55b}`
