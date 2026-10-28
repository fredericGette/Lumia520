## Qcsysdef8930.sys

System definition device driver (PoFx client of the PEP).  
A very small KMDF driver from the PEP package (PDB path: `P:\PEP\rel\8.3.1\arm\Release\qcsysdef8930.pdb`). It registers one PoFx component for its device, so that [qcpep8930.sys](./qcpep8930.md) applies the resources described for `\_SB.SDF1` in the PEP configuration (`DCFG`), and it exposes two test IOCTLs that forward requests to the PEP with `PoFxPowerControl`. One of them is an "XO shutdown" test that reports `PASS` / `FAIL` as text.  
It doesn't touch any hardware itself (no memory or interrupt resource is used) and it only imports `ntoskrnl.exe`, `HAL.dll` (`KeStallExecutionProcessor`) and `WDFLDR.SYS`.

Device name : `\Device\SYSTEMDEF`  
Symbolic link : `\DosDevices\SYSTEMDEF`  

There's no parameters in the registry.  

There's no ETW provider.  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| PoFx | [qcpep8930.sys](./qcpep8930.md) | Component 0 of the device, see [Power management](#power-management). `PoFxPowerControl` codes `{9e50a259-fb71-400b-975a-4680f895a04e}` and `{f1923a9a-d5fd-4c29-a72e-abc9f2f8a3b9}`, see [IOCTL 0x88880000](#ioctl-0x88880000) and [IOCTL 0x88880004](#ioctl-0x88880004) |

### Lumia 520 ACPI node

The device is probably `\_SB.SDF1` (`_HID` `QCOM2134`, `_DEP` on `\_SB.PMIC`) ?: the node has no resource and no method, and its only description is in the `DCFG` package of `\_SB.PEP0` (see [qcpep8930.sys](./qcpep8930.md#acpi)). It has 1 component with 2 F-states:  
| F-state | Resources |
|---------|-----------|
| F0 | `TLMMGPIO` for 94 TLMM GPIOs (0, 2, 3, 4, 6 … 0x97), all with the values (0, 0, 0, 1, 0). `PMICGPIO` 0, 1, 4, 5, 6, 11 configured as digital output (`IOCTL_PM_GPIO_CONFIG_DIGITAL_OUTPUT`), then the same 6 GPIOs as digital input (`IOCTL_PM_GPIO_CONFIG_DIGITAL_INPUT`, pull 4). `PMICMPP` 4 and 5 `IOCTL_PM_MPP_CONFIG_I_SINK`. `PMICVREGVOTE`: `VDDCX_CORNER` (8, 2), `SMPS2` 1.2875 V, `SMPS4` 1.8 V, `LDO4` 1.8 V, `LDO11` 1.8 V, `LDO14` 1.8 V, `LDO20` 1.225 V, `LDO23` 1.8 V |
| F1 | Nothing |

So F0 looks like the default (low power ?) configuration of the unused pins and of the always-on regulators of the board, applied by the PEP when the component becomes active ?

### WDF configuration

`EvtDriverDeviceAdd` (`sub_406048`):
- `WdfDeviceInitSetExclusive(TRUE)`: only one handle can be open at a time. `WdfDeviceInitSetIoType(WdfDeviceIoBuffered)`, name `\Device\SYSTEMDEF`, file object config without callbacks.
- PnP/power callbacks: `EvtDeviceD0Entry` and `EvtDeviceSelfManagedIoInit` `sub_401A00` (return `STATUS_SUCCESS`), `EvtDeviceD0Exit` `sub_406368` (returns `STATUS_SUCCESS`), `EvtDevicePrepareHardware` `sub_40628C`, `EvtDeviceReleaseHardware` `sub_4062FC`, `EvtDeviceSurpriseRemoval` `sub_40632C`.
- Context `CONTROL_DEVICE_EXTENSION` (36 bytes, pointer kept in `dword_404A94`), `EvtCleanupCallback` `sub_406008` (frees the event).
- `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
- One default sequential queue with only `EvtIoDeviceControl` (`sub_4061F0`).
- Then `sub_401878` creates the [activation thread](#activation-thread).

Driver pool tag `qde0`.  
`EvtDeviceSurpriseRemoval` calls `KeBugCheckEx(0x14E, 0x51646530 'Qde0', 0, 0, 0)`.

`CONTROL_DEVICE_EXTENSION`:  
| Offset | Comment |
|--------|---------|
| 0x08 | WDFDEVICE |
| 0x10 | WDM `DEVICE_OBJECT` |
| 0x14 | PoFx handle (`POHANDLE`) |
| 0x18 | Thread object of the activation thread |
| 0x1C | `KEVENT` (16 bytes, pool tag `qde1`) |
| 0x20 | Delay of the activation thread, 200 µs |

### Power management

`EvtDevicePrepareHardware` calls `sub_401B30`, which builds a `PO_FX_DEVICE` (version 1, pool tag `BEPQ`), calls `PoFxRegisterDevice` and `PoFxStartDevicePowerManagement`. It then enumerates the resource list without using it. `EvtDeviceReleaseHardware` calls `PoFxUnregisterDevice`.

1 component, Id `{ffffffff-ffff-ffff-ffff-ffffffffffff}`, `DeepestWakeableIdleState` = 1:  
| Idle state | TransitionLatency | ResidencyRequirement | NominalPower |
|------------|-------------------|----------------------|--------------|
| F0 | 0 | 0 | 500 |
| F1 | 2 | 5 | 50 |

Same idle states as [qce2arm8930.sys](./qce2arm8930.md#power-management) and [qcearm8930.sys](./qcearm8930.md).  
Callbacks: `ComponentActiveConditionCallback` `sub_401A9C` (no-op), `ComponentIdleConditionCallback` `sub_401A68` (`PoFxCompleteIdleCondition`), `ComponentIdleStateCallback` `sub_401A14` (`PoFxCompleteIdleState`), `DevicePowerRequiredCallback` `sub_401AA8` (`PoFxReportDevicePoweredOn`), `DevicePowerNotRequiredCallback` `sub_401AD8` (`PoFxCompleteDevicePowerNotRequired`; the first time only, it also sets the event of the activation thread), `PowerControlCallback` `sub_401A48` (returns 0).

### Activation thread

`sub_401988`, created by `PsCreateSystemThread` at device add:
1. Waits for the event, set by the first `DevicePowerNotRequiredCallback` (flag `byte_404144`, initially 1).
2. `KeStallExecutionProcessor(200)`.
3. `PoFxActivateComponent(handle, 0, PO_FX_FLAG_BLOCKING)`, then terminates.

The driver never calls `PoFxIdleComponent`: after this, component 0 stays active (F0) as long as the device exists, so the F0 resources of the PEP configuration stay applied ?

---

### IOCTL 0x88880000

This IOCTL is processed by Qcsysdef8930.sys (`sub_401698`)

| Property | Value |
|----------|-------|
| Device | 0x8888 |
| Function | 0x0 (0) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| XO shutdown test | ≥ 1 | ≥ 1 (8192 expected) |

Inputbuffer: forwarded as-is (InputBufferLength bytes) to the PEP as the input of `PoFxPowerControl(handle, {9e50a259-fb71-400b-975a-4680f895a04e}, …)`. The PEP doesn't read it ([qcpep8930.sys](./qcpep8930.md#9e50a259--f1923a9a-xo-statistics-and-debug-control)). Because of METHOD_BUFFERED it's also the beginning of the output string (see below), so it should start with a 0 byte.

Output of `PoFxPowerControl` (48 bytes, local buffer):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | Must be 3 (done synchronously). The PEP returns 1 when called above PASSIVE_LEVEL, which makes the test fail |
| 04-07 | 00 00 00 00 | Must be 0 (status). 0xC023001C when the PEP hasn't mapped the RPM statistics |
| 08-0B | | Not written by the PEP |
| 0C-0F | ? | Number of entries `n`, copied by the PEP from the RPM sleep statistics (physical 0x0010DD04) |
| 10-2F | ? | Up to 4 entries of 8 bytes: `00-03` ? (id ?), `04-07` value. Entries: XO shutdown count, XO shutdown time (32768 Hz ticks), VDD min count, VDD min time ? |

Outputbuffer: a text, `BytesReturned` = its `strlen`:  
```
<input string>
TEST:  XO Shutdown
RESULT: PASS
```

The handler keeps a copy of the previous PEP output (`unk_404A54`, zeroed at the first call). It subtracts the previous counters from the new ones, then appends `"\nTEST:  XO Shutdown\n"` and `"RESULT: PASS\n"` if the counter of entry 0 (XO shutdown count) or of entry 2 (VDD min count ?) has increased since the last call, `"RESULT: FAIL\n"` otherwise. So the test checks that the RPM shut down the crystal oscillator (or reached VDD min) at least once between two calls.  
The request is completed with the status of `PoFxPowerControl`.

Errors:
- InputBufferLength or OutputBufferLength = 0 → `STATUS_INVALID_PARAMETER` (0xC000000D).
- `PoFxPowerControl` fails, or the output isn't (3, 0, …), or OutputBufferLength = 0 → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

> [!NOTE]
> The text is appended with `strcat_s(buffer, 0x2000, …)` whatever the real OutputBufferLength: an output buffer smaller than the resulting string overflows the system buffer. The number of entries `n` returned by the PEP isn't checked either (the PEP itself copies it from the RPM without bound): `n` > 4 makes the loop read and write past the 48-byte buffer on the stack.

---

### IOCTL 0x88880004

This IOCTL is processed by Qcsysdef8930.sys (`sub_4015DC`)

| Property | Value |
|----------|-------|
| Device | 0x8888 |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| PEP debug / logging control | ≥ 1 | ≥ 1 (not used) |

Inputbuffer: forwarded as-is (InputBufferLength bytes) to the PEP as the input of `PoFxPowerControl(handle, {f1923a9a-d5fd-4c29-a72e-abc9f2f8a3b9}, …)`. Only the DWORD at `00-03` is read by the PEP: a bit mask that starts/stops the PEP logging and sends clock debug commands (`setflags top ff`, `info --enabled --on --xovote`), see [qcpep8930.sys](./qcpep8930.md#9e50a259--f1923a9a-xo-statistics-and-debug-control). E.g. `01 00 00 00` = start, `02 00 00 00` = stop.  
The 12-byte output of `PoFxPowerControl` is a local buffer and is discarded; nothing is returned to the caller (`BytesReturned` = 0).

The request is completed with the status of `PoFxPowerControl` when it succeeds.  
InputBufferLength or OutputBufferLength = 0 → `STATUS_INVALID_PARAMETER` (0xC000000D). If the input buffer can't be retrieved or `PoFxPowerControl` fails, the request is completed with `STATUS_SUCCESS` (the error is lost).

---

Any other IoControlCode → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

### Other GUID

PEP power control code "read the RPM sleep statistics" (`PoFxPowerControl`, [IOCTL 0x88880000](#ioctl-0x88880000))  
`{9e50a259-fb71-400b-975a-4680f895a04e}`

PEP power control code "debug / logging control" (`PoFxPowerControl`, [IOCTL 0x88880004](#ioctl-0x88880004))  
`{f1923a9a-d5fd-4c29-a72e-abc9f2f8a3b9}`
