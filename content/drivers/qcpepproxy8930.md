## Qcpepproxy8930.sys

PEP proxy driver: forwards the D-state changes of ACPI devices with no real driver-side power management to the PEP ([qcpep8930.sys](./qcpep8930.md)).  
It is the driver of `\_SB.PRXY` (`QCOM0812`). Devices such as `\_SB.TCH1` (touch) or `\_SB.NRSD` write their new D-state to the `GenericSerialBus` field `\_SB.PRXY.FLD0` in their `_PS0`…`_PS3` methods. [qcabd8930.sys](./qcabd8930.md) (software I²C target) forwards that write to this driver with [IOCTL 0x9C414004](#ioctl-0x9c414004), and this driver sends it to the PEP with `PoFxPowerControl` ("ExSocDStateChange").  
Qualcomm KMDF driver, PDB path: `P:\PEP\rel\8.3.1\arm\Release\qcpepproxy8930.pdb`. Source files `driver.cpp` and `device.cpp`. It only imports `ntoskrnl.exe` and `WDFLDR.SYS`.

There's no named device and no symbolic link.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0812\0` ?  

There's no parameters in the registry.

GUID of the ETW provider:  
None. The driver traces only errors with `DbgPrintEx` (`PEPProxy:ERROR:%s:%d%::` followed by a message).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of the device (default I/O target) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) on method `GEPT`, see [ACPI `GEPT`](#acpi-gept) |
| Interface `{2B0FDE10-DED1-40C1-AF2E-031836A066A8}` | [qcabd8930.sys](./qcabd8930.md) | ABD attach ([IOCTL 0xC3502FA4](#ioctl-0xc3502fa4)) / detach ([IOCTL 0xC3502FA8](#ioctl-0xc3502fa8)). In return, qcabd8930.sys sends [IOCTL 0x9C414000](#ioctl-0x9c414000) / [IOCTL 0x9C414004](#ioctl-0x9c414004) to this driver |
| Power framework (PoFx) | [qcpep8930.sys](./qcpep8930.md) | `PoFxPowerControl` with the control code `{5E7A62C2-1983-44C1-A399-5B8353A4A933}`, see [D-state change](#d-state-change) |

### Lumia 520 ACPI node

From the DSDT:
```
Device (PRXY) {
    Name (_HID, "QCOM0812")
    Name (_DEP, Package () { "\\_SB.ABD" })
    Field (\_SB.ABD.ROP1, BufferAcc, NoLock, Preserve) {
        Connection (I2cSerialBusV2 (0x0001, ControllerInitiated, 0, AddressingMode7Bit, "\\_SB.ABD", ...)),
        AccessAs (BufferAcc, AttribRawBytes (0x0B)),
        FLD0, 88
    }
    Method (GEPT) { ... DATA (WordField at offset 2) = One; Return (DATA) }
}
```
`\_SB.PEP0` `DCFG` describes `\_SB.PRXY` with one component (0) and a single `FSTATE` 0 without resources.

Writers of `FLD0` (see [qcabd8930.sys](./qcabd8930.md#lumia-520-acpi-node)): `_PS0`…`_PS3` of `\_SB.TCH1` and `\_SB.NRSD` in the DSDT, and of `\_SB.ACC1`, `\_SB.ALS1`/`\_SB.PRX1`, `\_SB.ALS2`/`\_SB.PRX2` in the Nokia SSDT. Each of them fills a 13-byte buffer `DBUF` (`STAT` byte 0, `DEID` = 10 bytes at offset 2 = the device path `PGID`, `DVAL` byte 12 = D-state 0–3) and writes it only when `\_SB.ABD.AVBL` is set. The 11 bytes `DEID` + `DVAL` reach this driver: see the [input buffer of IOCTL 0x9C414004](#ioctl-0x9c414004).

### WDF configuration

`DriverEntry` (0x408008): `WdfDriverCreate` with pool tag `'qpp0'` (0x30707071), `EvtDriverDeviceAdd` = `sub_401888`, driver cleanup callback = `sub_40187C` (no-op).

`EvtDriverDeviceAdd` (`sub_401888`):
- PnP/power callbacks: `EvtDeviceD0Exit` = `sub_407094`, `EvtDevicePrepareHardware` = `sub_402380`, `EvtDeviceReleaseHardware` = `sub_4024C8`, `EvtDeviceSurpriseRemoval` = `sub_407058`.
- `WdfDeviceCreate` with the context `PEPP_DEVICE` (60 bytes, see below). Its status isn't checked.
- `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
- `WdfDeviceCreateDeviceInterface` `{55BECA03-BA2C-4FBC-9EFC-EE8ECA56F0C7}`.
- `sub_407008`: default queue, parallel, `EvtIoDeviceControl` = `sub_401968`.

Device context `PEPP_DEVICE`:  
| Offset | Comment |
|--------|---------|
| 0x00 | WDFDEVICE |
| 0x04 | WDM device object (`WdfDeviceWdmGetDeviceObject`), given to `PoFxRegisterDevice` |
| 0x08 | PoFx handle |
| 0x0C | `FAST_MUTEX` protecting the device list |
| 0x2C | List head of the known devices, see [Device list](#device-list) |
| 0x34 | "Initialized" counter: 1 after `PrepareHardware`, decremented (interlocked) by `OnExitRelease` |
| 0x38 | Device object of qcabd8930.sys, cached by the first [IOCTL 0xC3502FA4](#ioctl-0xc3502fa4) |

> [!NOTE]
> The surprise-removal callback (`sub_407058`) calls `KeBugCheckEx(0x14E, 0x51707030 'Qpp0', 0, 0, 0)`: removing the device crashes the phone (same behaviour as qcabd8930.sys and qcpmicapps8930.sys).

### Start-up

`EvtDevicePrepareHardware` (`sub_402380`):
1. `sub_401B20` registers the device with PoFx (see [Power framework](#power-framework)). A failure → "PEP Registration Failed", the counter at `+0x34` stays 0 and the start fails.
2. Counter `+0x34` = 1.
3. `sub_402518` evaluates ACPI `GEPT`. 0 (or a failure) → `STATUS_UNSUCCESSFUL` (0xC0000001).
4. Sends [IOCTL 0xC3502FA4](#ioctl-0xc3502fa4) to qcabd8930.sys. A failure → "ABD Registration Failed", `PoFxUnregisterDevice` and counter = 0, and the start fails.

`OnExitRelease` (`sub_4025F0`), called by `EvtDeviceD0Exit` when the target state is ≥ `WdfPowerDeviceD3`, and by `EvtDeviceReleaseHardware` (after `PoFxUnregisterDevice`):
1. If the counter `+0x34` is 0 → "PEPProxy: OnExitRelease - not Initialized properly or resources already released", nothing else.
2. Decrements the counter.
3. Sends [IOCTL 0xC3502FA8](#ioctl-0xc3502fa8) to qcabd8930.sys.
4. Frees the [device list](#device-list).

`EvtDeviceReleaseHardware` returns `STATUS_UNSUCCESSFUL` without calling `PoFxUnregisterDevice` if the counter is already 0. So after a `D0Exit` to D3, the PoFx registration is never released ?. There is no `EvtDeviceD0Entry`: after a `D0Exit` to D3, the ABD registration isn't restored and every IOCTL fails until the next `PrepareHardware`.

### ACPI `GEPT`

`sub_402518` sends `IOCTL_ACPI_EVAL_METHOD` (0x32C004) to the default I/O target (`WdfIoTargetSendIoctlSynchronously`, no timeout). Input: 8-byte `ACPI_EVAL_INPUT_BUFFER` (`41 65 69 42` 'AeiB', method name `47 45 50 54` "GEPT"). Output: 20 bytes. If the output signature is 'AeoB' (0x426F6541) and the count is non-zero, the **low byte** of the first argument's data is returned as a WORD (same code as [qcpmicapps8930.sys](./qcpmicapps8930.md#acpi-gept)).  
On the Lumia 520 `GEPT` returns 1: the I²C slave address of the `\_SB.PRXY.FLD0` connection.

### Power framework

`sub_401B20` builds a `PO_FX_DEVICE` (version 1, 64 bytes, pool tag `'qpp2'`) and calls `PoFxRegisterDevice` on the WDM device object of the context (the FDO returned by `WdfDeviceWdmGetDeviceObject`), then `PoFxStartDevicePowerManagement`. The structure and the idle-state array are freed right after.  
| Field | Value |
|-------|-------|
| ComponentCount | 1 |
| ComponentActiveConditionCallback | `sub_40187C` (no-op) |
| ComponentIdleConditionCallback | `sub_401D84` → `PoFxCompleteIdleCondition` |
| ComponentIdleStateCallback | `sub_401D50` → `PoFxCompleteIdleState` |
| DevicePowerRequired / NotRequired / PowerControl callbacks | NULL |
| DeviceContext | `PEPP_DEVICE` |
| Component 0 Id | `{CD079E4F-33AE-48F6-9007-4F09EAB89464}` |
| IdleStateCount / DeepestWakeableIdleState | 1 / 1 |
| Idle state F0 | TransitionLatency 0, ResidencyRequirement 0, NominalPower 500 |

The driver never calls `PoFxActivateComponent` / `PoFxIdleComponent`. The registration is only needed to get a PoFx handle for `PoFxPowerControl`.

### Device list

Each device path received by [IOCTL 0x9C414004](#ioctl-0x9c414004) gets a record, kept in a linked list (list entries of 12 bytes, pool tag `'qpp4'`: Flink, Blink, record pointer). The records are never removed before `OnExitRelease`.

Record (28 bytes, pool tag `'qpp5'`, `sub_402154`), also the input buffer of `PoFxPowerControl`:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0B | e.g. `\_SB.TCH1` | Device path (1 to 9 characters), NUL padded |
| 0C-0F | 00 00 00 00 | Cached PEP device pointer: [qcpep8930.sys](./qcpep8930.md#5e7a62c2-set-d-state-by-name) looks the path up when it's 0 and writes the pointer here |
| 10-13 | 01 00 00 00 | Current D-state as `DEVICE_POWER_STATE`. Set to 1 (`PowerDeviceD0`) at creation, to 0 after a failure. This driver never sets it to the new state: the PEP copies `14-17` here on success |
| 14-17 | e.g. 04 00 00 00 | Requested D-state + 1 = `DEVICE_POWER_STATE` (1 = D0 … 4 = D3). Reset to 0 by the PEP on success |
| 18 | 01 | ? Reset to 0 by the PEP on success |
| 19-1B | 00 00 00 | |

### D-state change

`sub_401E84(device, buffer)`, called by both IOCTLs:
1. `buffer` NULL → "Memory Not Valid or Argument is not in range", failure.
2. `strlen(buffer)` must be 1–9 and the byte at offset 10 (D-state) must be 0–3, otherwise the same error.
3. Under the fast mutex, looks for the path in the [device list](#device-list) (`strcmp`), or creates a new record. The byte at offset 10 of the request buffer is **incremented in place**, and the new value (1–4) is stored at `+0x14` of the record.
4. If `+0x14` = `+0x10`, success without calling the PEP (a request for D0 while `+0x10` is still 1, or a repeated request for the state the PEP stored in `+0x10` after the previous success).
5. Otherwise (fails if there's no PoFx handle), `PoFxPowerControl(handle, {5E7A62C2-1983-44C1-A399-5B8353A4A933}, record, 28, output, 12, &returned)`. The mutex is released before the call.
   * failure → "ExSocDStateChange Failed", failure.
   * output `00-03` = 3 and output `04-07` ≠ 0 → "PoFxPowerControl Result Failed=0x%x" (value of `04-07`), `+0x10` and `+0x14` of the record are reset to 0, failure.
   * otherwise success.

Output of `PoFxPowerControl` (12 bytes, initialised to 0):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | 3 = `PEP_STATE_SYNC_PATH` ? (same layout as the P-state requests of [qcwcn8930.sys](./qcwcn8930.md#power-management)) |
| 04-07 | ? | Error code when ≠ 0 |
| 08-0B | ? | Not read |

The control code `{5E7A62C2-…}` is handled by sub_4098B0 of [qcpep8930.sys](./qcpep8930.md#5e7a62c2-set-d-state-by-name): it applies the `DSTATE` resources of the device described in `DCFG`/`ECFG`. Its result `04-07` is 0 or `STATUS_UNSUCCESSFUL` (0xC0000001), `08-0B` is 0.

---

### IOCTL 0x9C414004

This IOCTL is processed by Qcpepproxy8930.sys (`EvtIoDeviceControl` `sub_401968`), sent by [qcabd8930.sys](./qcabd8930.md#ioctl-0x41808--ioctl_spb_execute_sequence) when AML writes `\_SB.PRXY.FLD0`  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x1 (1) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the D-state of a device ("SET" IOCTL of the ABD registration) | ≥ 8 (11 from qcabd8930.sys) | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-09 | e.g. 5C 5F 53 42 2E 54 43 48 31 00 | Device path, NUL-terminated (`DEID` = `PGID`, e.g. `\_SB.TCH1`) |
| 0A | e.g. 03 | New D-state 0–3 (`DVAL`). Incremented in place by the handler |

See [D-state change](#d-state-change). Returns `STATUS_SUCCESS`, or `STATUS_UNSUCCESSFUL` (0xC0000001) when the change fails. Information = 0.  
The handler only checks 8 bytes, but reads byte 10.

---

### IOCTL 0x9C414000

This IOCTL is processed by Qcpepproxy8930.sys (`EvtIoDeviceControl` `sub_401968`), would be sent by [qcabd8930.sys](./qcabd8930.md#ioctl-0x41808--ioctl_spb_execute_sequence) if AML read `\_SB.PRXY.FLD0` (no method does it on the Lumia 520)  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x0 (0) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| "GET" IOCTL of the ABD registration | ≥ 4 | ≥ DWORD at 00-03 of the input |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 0B 00 00 00 | Output size. qcabd8930.sys sends the length of the read buffer here |

The handler reads the DWORD at `00-03`, then calls [D-state change](#d-state-change) on the **same** buffer, as if it held a device path (copy of the SET handler ?). With the input of qcabd8930.sys, the "path" is the single character 0x0B and the D-state is an uninitialized byte. If that fails → `STATUS_UNSUCCESSFUL`. Otherwise the output buffer must be at least that size, and the request completes with Information = that size. No data is produced: the output is just the system buffer.

---

Any other IoControlCode → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). If the counter `+0x34` is 0 (not started, or after `OnExitRelease`), every IOCTL is rejected the same way, after "Initialization is not done properly = 0x%x".

---

### IOCTL 0xC3502FA4

This IOCTL is sent by Qcpepproxy8930.sys to [qcabd8930.sys](./qcabd8930.md#ioctl-0xc3502fa4--attach) (`{2B0FDE10-DED1-40C1-AF2E-031836A066A8}` interface)  

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0xBE9 (3049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ABD attach | `{2B0FDE10-…}` interface | 32 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 03 CA BE 55 2C BA BC 4F 9E FC EE 8E CA 56 F0 C7 | `{55BECA03-BA2C-4FBC-9EFC-EE8ECA56F0C7}`, interface of this driver |
| 10-11 | 01 00 | Low byte of the ACPI `GEPT` result: I²C slave address 1 |
| 12-13 | ? | Not initialised (stack) |
| 14-17 | 00 40 41 9C | [IOCTL 0x9C414000](#ioctl-0x9c414000), sent for a read |
| 18-1B | 04 40 41 9C | [IOCTL 0x9C414004](#ioctl-0x9c414004), sent for a write |
| 1C-1F | 08 00 00 00 | 8 (data size; the AML field is actually 11 bytes. Unused by qcabd8930.sys) |

Sent by `sub_401008`: `IoGetDeviceInterfaces({2B0FDE10-…})`, `IoGetDeviceObjectPointer(FILE_ALL_ACCESS)` on the first symbolic link, then a synchronous `IoBuildDeviceIoControlRequest` (`IRP_MJ_DEVICE_CONTROL`). The device object is cached in the context at `+0x38` and reused when the interface lookup fails later; the file object is never dereferenced. The symbolic-link list is freed with the tag `'qpp0'`, not the tag of the I/O manager.

---

### IOCTL 0xC3502FA8

This IOCTL is sent by Qcpepproxy8930.sys to [qcabd8930.sys](./qcabd8930.md#ioctl-0xc3502fa8--detach) (`{2B0FDE10-DED1-40C1-AF2E-031836A066A8}` interface)  

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0xBEA (3050) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ABD detach | `{2B0FDE10-…}` interface | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 03 CA BE 55 2C BA BC 4F 9E FC EE 8E CA 56 F0 C7 | `{55BECA03-BA2C-4FBC-9EFC-EE8ECA56F0C7}` |

Sent by `OnExitRelease` (`sub_4025F0`), same path as the attach.

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcpepproxy8930.sys to [acpi.sys](./acpi.md) (default I/O target), see [ACPI `GEPT`](#acpi-gept)  

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI node `\_SB.PRXY` | 8 | 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | 'AeiB' `ACPI_EVAL_INPUT_BUFFER_SIGNATURE` |
| 04-07 | 47 45 50 54 | Method name "GEPT" |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | 'AeoB' `ACPI_EVAL_OUTPUT_BUFFER_SIGNATURE` |
| 04-07 | ? | Length |
| 08-0B | 01 00 00 00 | Count (must be ≠ 0) |
| 0C-0D | 00 00 | Argument type (integer, not checked) |
| 0E-0F | 04 00 | Data length |
| 10 | 01 | Low byte of the data, used as the I²C slave address |

---

### Interface GUID

Qcpepproxy8930 Interface Class GUID (`WdfDeviceCreateDeviceInterface`, registered in qcabd8930.sys)  
`{55BECA03-BA2C-4FBC-9EFC-EE8ECA56F0C7}`

### Other GUID

`PoFxPowerControl` control code (D-state change, "ExSocDStateChange")  
`{5E7A62C2-1983-44C1-A399-5B8353A4A933}`

PoFx component 0  
`{CD079E4F-33AE-48F6-9007-4F09EAB89464}`
