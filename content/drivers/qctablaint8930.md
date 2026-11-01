## Qctablaint8930.sys

Qualcomm WCD93xx ("Tabla" family) audio codec interrupt handler ("TIC", Tabla Interrupt Controller).  
It owns the interrupt line of the codec and dispatches the codec interrupts to up to three kernel clients. The interrupt status, mask and clear registers of the codec are read and written over the **SLIMbus** through [qcslimbus8930.sys](./qcslimbus8930.md). The clients register a callback with an IOCTL; the callback is called from a system thread with a summary of the interrupts that fired. The known clients are the headset detection drivers [qcmbhc8930.sys](./qcmbhc8930.md) and [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md) (client 1, MBHC interrupts).  
It is a KMDF driver. PDB path `P:\audio\rel\8.3.1\arm\Release\qctablaint8930.pdb`, source files `wcd_interrupt_handler.c` and `wcd_ih_internal.c`. There are almost no strings: all messages are WPP traces, except one `DbgPrintEx` (component 0x4F) `TIC:TICEvtRemoveComplete Called`. Driver pool tag `0itq`, pool tags `6itq`…`9itq`, `aitq`…`citq`, WDF memory tags `1itq`…`5itq`.

ACPI device `\_SB.TICO` (`_HID` `QCOM0742`), with `_DEP` on `\_SB.SLM1` ([qcslimbus8930.sys](./qcslimbus8930.md)). Its only resource is a `GpioInt` (Edge, ActiveHigh, Exclusive, PullUp) on pin 62 of `\_SB.GIO0` ([qcgpio.sys](./qcgpio.md)): the codec interrupt line. `\_SB.TICO` is in the `_DEP` of `\_SB.ACHW` ([qcsitarcodec8930.sys](./qcsitarcodec8930.md)), `\_SB.MBHC`, `\_SB.MBGP` and `\_SB.QCRT` ([qc8x60aud.sys](./qc8x60aud.md)). The link between QCOM0742 and this driver comes from the `TIC` prefix and from the interface GUID used by the MBHC drivers.

There's no named `\Device\` object and no symbolic link.  
The driver registers the device interface `{C383F1A1-0E73-47D9-A5B2-214CEC4EE713}` (see [Interface GUID](#interface-guid)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0742\<instance>`  

There's no parameters in the registry.

GUID of the ETW provider (WPP control GUID):  
`{D3D7C968-4842-4C61-994E-2AAD4DBA2C18}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}` | [qcslimbus8930.sys](./qcslimbus8930.md) (`\_SB.SLM1`, QCOM0190) | Codec logical addresses and codec register read/write. Found with `IoGetDeviceInterfaces` (first symbolic link), opened with `WdfIoTargetOpen` by name, `FILE_ALL_ACCESS`, with a `EvtIoTargetRemoveComplete` callback (`sub_403134`) that closes the target. See [IOCTL 0x85B52000 / 0x85B52400 / 0x85B52404](#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus) |
| GPIO interrupt (pin 62) | [qcgpio.sys](./qcgpio.md) | `WdfInterruptCreate`: the ISR (`sub_403E74`) only queues the DPC; the DPC (`sub_403EFC`) sets a "pending" flag and signals the handler thread |
| — | [qcmbhc8930.sys](./qcmbhc8930.md), [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md) | Clients of the interface `{C383F1A1-…}`: [IOCTL 0x5001200C…0x5001201C](#ioctl-0x5001200c--register-for-interrupts) with client id 1 |

### Start sequence

1. `DriverEntry`: WPP registration, `WdfDriverCreate`.
2. `EvtDriverDeviceAdd` (`sub_4095C0`): PnP callbacks (`EvtDevicePrepareHardware`, `EvtDeviceReleaseHardware`), `WdfDeviceCreate`, device interface `{C383F1A1-…}`, one sequential default queue, **not power-managed**, with `EvtIoDeviceControl` (`sub_409834`), `WdfDeviceSetStaticStopRemove(FALSE)`, then the interrupt object (`sub_409754`).
3. `EvtDevicePrepareHardware` only walks the resource list; it does nothing with it.
4. The real initialisation is **lazy**: it runs on the first IOCTL received, whatever its code (`sub_4036A0` → `sub_40373C`). If it fails, the IOCTL completes with the error and the next IOCTL tries again.
   1. Allocates the context (0x90 bytes, `dword_407B1C`) and a mutex.
   2. SLIMbus (`sub_4012A4`): creates the I/O target, opens the interface `{88EEFAB5-…}` and gets the logical addresses of the codec (see [SLIMbus](#slimbus)).
   3. Disables the interrupts of the 3 clients (`sub_402200(client, 0, -1)`).
   4. Creates the handler thread (`PsCreateSystemThread`, `sub_4033DC`) and waits until it has started.
5. `EvtDeviceReleaseHardware`: disables the device interface, stops the handler thread (stop flag + event, waits 100 ms for the exit event). The thread calls every registered callback with event 1, closes the SLIMbus target and frees the context.

### SLIMbus

The codec has two SLIMbus devices. The driver tries up to 4 enumeration addresses (table `off_407180`) with [IOCTL 0x85B52000](#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus) until one succeeds, then gets the logical address of the second device from the table `off_407170` at the same index:  
| Index | Device 0 (`off_407180`) | Device 1 (`off_407170`) | Comment |
|-------|-------------------------|-------------------------|---------|
| 0 | `00 01 10 00 17 02` | `00 00 10 00 17 02` | Part id 0x0010 (Tabla 1.x ?) |
| 1 | `00 01 60 00 17 02` | `00 00 60 00 17 02` | Part id 0x0060 (Tabla 2.x ?) |
| 2 | `00 01 00 00 17 02` | `00 01 00 00 17 02` | Part id 0x0000, same address for both (Sitar ?, see [qcsitarcodec8930.sys](./qcsitarcodec8930.md#slimbus)) |
| 3 | `00 01 70 00 17 02` | `00 01 70 00 17 02` | Part id 0x0070, same address for both (Sitar ?) |

Manufacturer id 0x0217 = Qualcomm. The first three bytes are the instance and the device index: device index 1 is the codec device (codec registers), device index 0 is probably the SLIMbus interface device ("PGD" in the Linux `wcd9xxx` driver). The 4 addresses are the same as those of [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md); [qcmbhc8930.sys](./qcmbhc8930.md) only tries the first two.

The logical addresses are stored in the SLIMbus context (16 bytes, `dword_407B00`): `+0x0` mutex, `+0x4` mode (always 0; mode 1 is rejected), `+0x8` I/O target, `+0xC` logical address of device 0, `+0xE` logical address of device 1.

A register is read (`sub_401CB4`) with [IOCTL 0x85B52400](#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus) (element address = register + 0x800, 1 byte), and written (`sub_401834`) as a read-modify-write: read the register, then [IOCTL 0x85B52404](#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus) with `(value & mask) | (old & ~mask)`. There's no retry.

### Codec interrupt registers

The interrupt registers are described by a table of 6 entries of 12 bytes (`unk_407128`):  
| Bytes | Comment |
|-------|---------|
| 00-01 | SLIMbus device: 0 = codec device, 1 = interface device (see [SLIMbus](#slimbus)) |
| 02-03 | Mask / enable register |
| 04-05 | Status register |
| 06-07 | Clear register |
| 08 | Valid bits |
| 09 | 1 = the register at `+02` is a mask (1 = masked), it's inverted when read and written; 0 = enable register |
| 0A-0B | 0xFFFF, or dependency `(index << 8) \| bit`: the status register is only read when this bit of the status of register `index` is set |

| Index | Device | Mask / enable | Status | Clear | Valid bits | Inverted | Dependency | Comment (register names of the Linux `wcd9310` driver) |
|-------|--------|---------------|--------|-------|------------|----------|------------|---------|
| 0 | 0 | 0x94 | 0x98 | 0x9C | 0xFF | 1 | — | `TABLA_A_INTR_MASK0` / `STATUS0` / `CLEAR0` ? |
| 1 | 0 | 0x95 | 0x99 | 0x9D | 0xFF | 1 | — | `…1` ? |
| 2 | 0 | 0x96 | 0x9A | 0x9E | 0x3F | 1 | — | `…2` ? |
| 3 | 1 | 0x30 | 0x34 | 0x38 | 0xFF | 0 | register 0 bit 0x01 | `TABLA_SLIM_PGD_PORT_INT_EN0` / `STATUS0` / `CLR0` ? |
| 4 | 1 | 0x31 | 0x35 | 0x39 | 0xFF | 0 | register 0 bit 0x01 | Port interrupts 8–15 ? |
| 5 | 1 | 0x32 | 0x36 | 0x3A | 0x01 | 0 | register 0 bit 0x01 | Port interrupt 16 ? |

Bit 0x01 of register 0 is the summary of the SLIMbus port interrupts (`TABLA_IRQ_SLIMBUS` ?). The driver sets or clears it by itself when the port interrupts (client 2) are enabled or disabled.

After the status registers are read, every handled bit is cleared, and bit 1 of register 0x90 (`TABLA_A_INTR_MODE` ?) is set (`sub_401834(ctx, 0, 0x90, 2, 2)`).

### Clients

There are 3 clients, each one owns a fixed set of interrupt bits (tables `unk_406248`, `unk_406200`, `unk_406128`):  
| Client id | Interrupts | Flag bits in the summary | Known user |
|-----------|------------|--------------------------|------------|
| 0 | Register 0 bit 7, register 1 bits 0–7, register 2 bits 0–5 (15 interrupts; `BG_PRECHARGE`, `PA*_STARTUP`, `MICBIAS*_PRECHARGE`, `*_PA_OCP*_FAULT`, `*_PA_STARTUP` ?) | 0x0001…0x4000 | ? |
| 1 | Register 0 bits 1–6 (6 interrupts, MBHC: `REMOVAL`, `SHORT_TERM`, `PRESS`, `RELEASE`, `POTENTIAL`, `INSERTION` ?) | 0x02…0x40 (= the status bits) | [qcmbhc8930.sys](./qcmbhc8930.md), [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md) |
| 2 | Registers 3 and 4 bits 0–7, register 5 bit 0 (17 SLIMbus ports) | Ports 0–9 → word `+04` bits 0x001…0x200 (TX ports ?), ports 10–16 → word `+06` bits 0x01…0x40 (RX ports ?) | ? |

Only one registration per client id is accepted at a time.

Callback summary (24 bytes, in the client slot; the callback is called with the 6 dwords as arguments, i.e. the structure by value):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Event: 0 = interrupts, 1 = handler stopped, 2 = handler started |
| 04-07 | ? | Clients 0 and 1: flag bits of the interrupts that fired (OR-ed until cleared). Client 2: two words, see above |
| 08-17 | ? | Clients 0 and 1: one 8-bit counter per interrupt (byte `+08` = first interrupt of the table) |

Events 1 and 2 use a global summary (`dword_407B80`, first dword = event). A client that registers while the handler thread is running immediately receives event 2.

### Handler thread

`sub_4033DC` waits for the event signalled by the DPC. For each interrupt (`sub_4028DC`):
1. Reads the 6 status registers (respecting the dependency), masked by the valid bits.
2. For each register with bits set, writes the clear register with the valid bits except the "held" bits (`byte_407B98`, see [IOCTL 0x50012020 / 0x50012024](#ioctl-0x50012020--0x50012024--hold-interrupts-)).
3. Sets bit 1 of register 0x90.
4. Builds the summary of client 1, then client 0, then client 2 (`sub_402AE4`) and calls the callback of each client that has a registration and at least one of its interrupts set.

The callbacks run in the context of the thread, at PASSIVE_LEVEL.

> [!NOTE]
> The handles returned by [IOCTL 0x5001200C](#ioctl-0x5001200c--register-for-interrupts) are kernel addresses, and the callback is a kernel address given by the client. The interface is only usable from kernel mode.

All the IOCTLs below are processed by `EvtWdfIoQueueIoDeviceControl` (`sub_403F4C`). The input/output buffers are taken with `WdfRequestRetrieveInputBuffer` / `WdfRequestRetrieveOutputBuffer` with a **minimum** size. An unknown code completes with `STATUS_SUCCESS`. 0xC00000E5 (`STATUS_INTERNAL_ERROR`) is returned by most of the internal failures.

---

### IOCTL 0x5001200C — register for interrupts

This IOCTL is processed by Qctablaint8930.sys (`sub_4039B0`). Sent by [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts) (`wcd_register_for_interrupt`) and [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x803 (2051) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| wcd_register_for_interrupt | ≥ 8 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Client id 0, 1 or 2 (see [Clients](#clients)) |
| 04-07 | ? | Kernel address of the callback (must not be NULL) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle = kernel address of the client slot. 0 = failure (bad client id, NULL callback, or client id already registered) |

The slot (40 bytes) is: `+0x00` in-use byte, `+0x04` client id, `+0x08` summary (24 bytes), `+0x20` callback, `+0x24` pointer to the registration counter of the client. The IOCTL always returns `STATUS_SUCCESS` with 4 bytes, even when the handle is 0. Registering doesn't enable any interrupt: use [0x50012014](#ioctl-0x50012014--0x50012018--enable--disable-interrupts).

---

### IOCTL 0x50012010 — deregister

This IOCTL is processed by Qctablaint8930.sys. Sent by [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts) (`wcd_deregister_interrupt`) and [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x804 (2052) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| wcd_deregister_interrupt | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle |

If the handle is not NULL and the slot is in use: decrements the registration counter of the client, disables all the interrupts of the client when it reaches 0 (`sub_402200(client, 0, -1)`), then zeroes the slot.

---

### IOCTL 0x50012014 / 0x50012018 — enable / disable interrupts

These IOCTLs are processed by Qctablaint8930.sys (`sub_403C18` / `sub_403D5C` → `sub_402200`). Sent by [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts) (`wcd_enable_interruption` / `wcd_disable_interruption`) and [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x805 / 0x806 (2053 / 2054) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x50012014 wcd_enable_interruption | ≥ 8 | 0 |
| 0x50012018 wcd_disable_interruption | ≥ 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle |
| 04-07 | e.g. FF FF FF FF | Mask of the interrupts, in the flag bits of the client (see [Clients](#clients)); −1 = all |

`sub_402200` updates a cache of the 6 mask / enable registers (`dword_407BA8`) and writes the registers that changed (read-modify-write over the SLIMbus, restricted to the valid bits). On enable, the 6 registers are first read back from the codec. For client 2, bit 0x01 of register 0 (SLIMbus summary) follows the port interrupts.  
Returns 0xC00000E5 if the handler thread is not running or the handle is NULL / not in use.

---

### IOCTL 0x5001201C — clear interrupts

This IOCTL is processed by Qctablaint8930.sys (`sub_402C3C`). Sent by [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts) (`wcd_clear_interrupt`) and [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x5001200c--0x50012010--0x50012014--0x50012018--0x5001201c--codec-interrupts).

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x807 (2055) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| wcd_clear_interrupt | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle |

If the slot is in use: writes the 6 clear registers (valid bits except the held bits, for **all** the clients), sets bit 1 of register 0x90, then zeroes the summary of the slot (flags and counters).

---

### IOCTL 0x50012020 / 0x50012024 — hold interrupts ?

These IOCTLs are processed by Qctablaint8930.sys (`sub_402740`). No sender is known.

| Property | Value |
|----------|-------|
| Device | 0x5001 |
| Function | 0x808 / 0x809 (2056 / 2057) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x50012020 release ? | ≥ 4 | 0 |
| 0x50012024 hold ? | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Handle |

0x50012024 sets, and 0x50012020 clears, all the interrupt bits of the client in the "held" table `byte_407B98` (6 bytes, one per register, zeroed at initialisation). A held bit is never written to the clear register, neither by the handler thread nor by [0x5001201C](#ioctl-0x5001201c--clear-interrupts), so the interrupt stays pending in the codec. The purpose is ?  
Note: the same codes are used by [qcsitarcodec8930.sys](./qcsitarcodec8930.md#ioctl-0x50012020--0x50012024--codec-registers) on another interface, with another meaning.

---

### IOCTL 0x85B52000 / 0x85B52400 / 0x85B52404 — SLIMbus

These IOCTLs are sent by Qctablaint8930.sys to the SLIMbus driver [qcslimbus8930.sys](./qcslimbus8930.md) (interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}`), with `WdfIoTargetSendIoctlSynchronously`.

| Property | Value |
|----------|-------|
| Device | 0x85B5 |
| Function | 0x800 / 0x900 / 0x901 (2048 / 2304 / 2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x85B52000 Get logical address (`sub_402D2C`) | interface `{88EEFAB5-…}` | 6 | 1 |
| 0x85B52400 Read value element (`sub_401CB4`) | interface `{88EEFAB5-…}` | 16 | 1 |
| 0x85B52404 Write value element (`sub_401834`) | interface `{88EEFAB5-…}` | 16 | 0 |

Inputbuffer (0x85B52000):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-05 | e.g. 00 01 10 00 17 02 | Enumeration address (see [SLIMbus](#slimbus)) |

Outputbuffer (0x85B52000):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Logical address |

Inputbuffer (0x85B52400 / 0x85B52404):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Logical address (`+0xC` for device 0, `+0xE` for device 1 of the SLIMbus context) |
| 01-03 | 00 00 00 | |
| 04-07 | e.g. 98 08 00 00 | Element address = register + 0x800 |
| 08-0B | 01 00 00 00 | Size: 1 byte |
| 0C | ? | 0x85B52404 only: value to write |
| 0D-0F | 00 00 00 | |

Outputbuffer (0x85B52400):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Register value (masked by the caller's mask) |

Note: for 0x85B52400 the WDF memory object is 12 bytes but the memory descriptor gives a length of 16, so 4 bytes beyond the buffer are sent (ignored by the SLIMbus driver, which only needs 12).

---

### Interface GUID

Qctablaint8930 Interface Class GUID  
`{C383F1A1-0E73-47D9-A5B2-214CEC4EE713}`
