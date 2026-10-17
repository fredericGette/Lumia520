## Qcsmsm8930.sys

Shared Memory State Machine Driver (SMSM).  
Read, write and watch a memory region containing the state of the subsystems.  
It calls [qcsmem8930.sys](./qcsmem8930.md) to get the address of this memory region, and provides some IOCTL to read and write in it. Moreover, it sets an interrupt handler to be notified when a state is updated by a subsystem, and it interrupts the other processors when the state of the application processor changes.  
It's also an RPE client of [qcrpen8930.sys](./qcrpen8930.md): when the MODEM or the RIVA (WCN) subsystem goes down, the state of this subsystem is cleared.  
The signification of each bits of a state is indicated here: https://github.com/drakaz/cm-kernel/blob/f1215cb1e5e7090e9688ae8d1ce7eb1c5ed1c7ce/drivers/dpram/smd_private.h#L98  
Built from `P:\SMSM\rel\8.2.1.1\arm\Release\qcsmsm8930.pdb`.

It contains the same "hack" that the one indicated here: https://github.com/freexperia/android_kernel_semc_msm7x30/blob/03025f007e8f0ccdd51ea3bced3999c2d6249010/arch/arm/mach-msm/smd.c#L375  
So the address of the GPIO_40 is hardcoded in the driver : 0x801284  
This hack is applied when the chip id ([IOCTL 0x8C1F2008](#ioctl-0x8c1f2008)) is 0x57 (MSM8960) and the chip version ([IOCTL 0x8C1F2004](#ioctl-0x8c1f2004)) is less than 0x20000 (2.0), so never on the Lumia 520 (MSM8227). See [RIVA interrupt workaround](#riva-interrupt-workaround).  

Device name : `\Device\SMSM`  
Symbolic link : `\DosDevices\SMSM`  

There's no parameters in the registry.  

GUID of the WPP control provider:  
`{61485ed3-92fb-436b-b828-8a57815e1826}`  
WPP trace message GUIDs: `{f9785383-5786-06f4-7fb0-e876dddea8e3}`, `{1100cd08-743b-bd4d-aa99-216a3d9cb9a5}`, `{0226263b-b999-ee5c-5dff-a16eb7238cbe}`, `{05248109-5109-4e2f-e4e1-c121a8038ad0}`

GUID of the ETW provider of the RPE helper library (`McGenEventRegister` in `RpeInit`, same as in [qcsmd8930.sys](./qcsmd8930.md)):  
`{57e95397-c84e-4f53-9473-56207aaa5938}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMEM | [qcsmem8930.sys](./qcsmem8930.md) | Shared Memory table driver. [internal IOCTL 0x42000](#internal-ioctl-0x42000) (function table) and [internal IOCTL 0x42004](#internal-ioctl-0x42004) (address translation) |
| Interface `{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}` | [qcchipinfo8930.sys](./qcchipinfo8930.md) | Chip identification. [IOCTL 0x8C1F2008](#ioctl-0x8c1f2008) and [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004), for the [RIVA interrupt workaround](#riva-interrupt-workaround) |
| Interface `{59752ed7-b9d5-4121-818d-c69f1e667015}` (\Device\RPEN) | [qcrpen8930.sys](./qcrpen8930.md) | RPE notifier, Helper query-interface. See [RPE clients](#rpe-clients) |
| ACPI node of the device | acpi.sys | [IOCTL 0x32C004](#ioctl-0x32c004) `IOCTL_ACPI_EVAL_METHOD`, method `INTR` |

Drivers using `\Device\SMSM`:  
| Driver | IOCTL |
|--------|-------|
| [qcsmd8930.sys](./qcsmd8930.md) | [IOCTL 0x32000](#ioctl-0x32000) (`SMSM_APPS_STATE`, set `SMSM_SMD_LOOPBACK`) |
| [qcwcn8930.sys](./qcwcn8930.md) | [internal IOCTL 0x32008](#internal-ioctl-0x32008), [IOCTL 0x3200C](#ioctl-0x3200c), [internal IOCTL 0x32010](#internal-ioctl-0x32010) |
| [qcbamdmux8930.sys](./qcbamdmux8930.md) | [IOCTL 0x32000](#ioctl-0x32000) (`SMSM_APPS_STATE`, set/clear `SMSM_A2_POWER_CONTROL` 0x2 and `SMSM_A2_POWER_CONTROL_ACK` 0x800), [IOCTL 0x3200C](#ioctl-0x3200c) (wait for `SMSM_A2_POWER_CONTROL` in `SMSM_MODEM_STATE`). See [A2 power handshake](./qcbamdmux8930.md#a2-power-handshake) |

### WDF setup

`EvtDriverDeviceAdd` (0x40241C):
- `WdfDeviceInitSetExclusive(FALSE)`, IO type `WdfDeviceIoBuffered`.
- Name `\Device\SMSM`, symbolic link `\DosDevices\SMSM`.
- PnP/power callbacks: only `EvtDeviceSurpriseRemoval` (`sub_4033A8`), which calls `KeBugCheckEx(0x14E, 0x306D7371 'qsm0', 0, 0, 0)`: removing the SMSM device crashes the phone.
- File object: `EvtDeviceFileCreate` (`sub_402974`) completes with `STATUS_SUCCESS`.
- `WdfDeviceSetStaticStopRemove`.
- Device interface `{1c90923a-df5c-4761-9fd0-835b80f5281d}`.
- Default queue, parallel dispatch: `EvtIoDeviceControl` = `sub_402BD0`, `EvtIoInternalDeviceControl` = `sub_4029D0`, `EvtIoStop` = `sub_4032DC` (cancels the pending [IOCTL 0x3200C](#ioctl-0x3200c)).
- `IoRegisterPlugPlayNotification` on the qcchipinfo8930.sys interface `{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}` (`sub_4018C8`), see [RIVA interrupt workaround](#riva-interrupt-workaround).
- `sub_403CF8`: opens `\Device\SMEM` and gets the function table of qcsmem8930.sys with [internal IOCTL 0x42000](#internal-ioctl-0x42000).
- `sub_40361C`: SMSM initialisation, see [Shared memory](#shared-memory).
- `sub_40150C`: evaluates the ACPI method `INTR` ([IOCTL 0x32C004](#ioctl-0x32c004)) and creates the interrupts, see [Interrupts](#interrupts).
- `sub_401E38`: registers the [RPE clients](#rpe-clients).

If one of these steps fails, the device is not created.  
Pool tags: `qsm0` (driver), `qsm1` (`INTR` buffer), `qsm2` (pending [0x3200C](#ioctl-0x3200c) requests), `qsm3` (state callbacks), `ahrq` (RPE memory segments).

### Shared memory

`sub_40361C` uses the [function table of qcsmem8930.sys](./qcsmem8930.md#function-table):  
| SMEM item | Size | Name in Linux | Content |
|-----------|------|---------------|---------|
| 419 (0x1A3) | 16 | `SMEM_SMSM_SIZE_INFO` | DWORD 0 = number of hosts, DWORD 1 = number of entries. If DWORD 0 is 0, the defaults are used: 5 hosts, 8 entries |
| 85 (0x55) | 4 × entries | `SMEM_SMSM_SHARED_STATE` | One state DWORD per entry |
| 333 (0x14D) | 4 × entries × hosts | `SMEM_SMSM_CPU_INTR_MASK` | DWORD `[entry × hosts + host]`: the bits of `entry` whose change must interrupt `host` |

> [!NOTE]
> If `smem_alloc` of item 419 returns NULL, the driver writes a trace then dereferences the NULL pointer anyway.

Initialisation:
1. The interrupt mask of the local host (0 = APPS) is cleared for every entry.
2. The state of `SMSM_APPS_STATE` is set to `0x08000001` (`SMSM_INIT` | `SMSM_MODEM_CONTINUE` ? in the Linux names), the other hosts are interrupted and the local callbacks are called.
3. `smem_version_set(109 (0x6D), 1, 0xFFFFFFFF)` (SMSM version ?). A mismatch only writes a trace.

Entries (hardcoded table at `.data:0x00409130`, entry → owner host). The names are those of the Linux 8960 kernel and are tentative:  
| Entry | Name | Owner host | Comment |
|-------|------|------------|---------|
| 0 | SMSM_APPS_STATE | 0 (APPS) | Local state, written by this driver |
| 1 | SMSM_MODEM_STATE | 1 (MODEM) | Cleared when the RPE client AMSS goes down |
| 2 | SMSM_Q6_STATE | 2 (Q6) | |
| 3 | SMSM_WCNSS_STATE | 3 (WCNSS/RIVA) | Cleared when the RPE client WCN goes down. Used by [qcwcn8930.sys](./qcwcn8930.md) |
| 4 | SMSM_DSPS_STATE | 4 (DSPS) | |
| 5 | SMSM_Q6_DEM ? | 6 (none) | |
| 6 | SMSM_POWER_MASTER_DEM ? | 6 (none) | |
| 7 | SMSM_TIME_MASTER_DEM ? | 6 (none) | |

All the IOCTLs reject an entry ≥ 8.

### Interrupts

`sub_40150C` evaluates the ACPI method `INTR` of the device ([IOCTL 0x32C004](#ioctl-0x32c004)), then `sub_4013DC` / `sub_401210` parse the package.  
Format of the `INTR` package (ACPI_EVAL_OUTPUT_BUFFER, signature `BoeA`, all arguments must be integers). It's the same layout as for [qcsmd8930.sys](./qcsmd8930.md#initialisation), but the host numbers are SMSM host indexes:  
| Argument | Comment |
|----------|---------|
| 0 | Must be 1 (version ?) |
| 1 | N = number of entries. The package must contain exactly 4×(N+1) integers |
| 2 | ? (not used) |
| 3 | ? (not used) |
| 4+4i | Remote host of entry i (1 = MODEM, 2 = Q6, 3 = WCNSS/RIVA, 4 = DSPS). Must be < 5 |
| 5+4i | Physical address of the outgoing interrupt register. Translated to a virtual address by [internal IOCTL 0x42004](#internal-ioctl-0x42004); it must be one of the memory resources of qcsmem8930.sys |
| 6+4i | Value written to that register to interrupt the remote host |
| 7+4i | ? (not used) |

Any malformed answer → `STATUS_DEVICE_CONFIGURATION_ERROR` (0xC0000182).  
For each entry, `sub_4027F0` creates a WDF interrupt (from the interrupt resources of the ACPI device, in order ?) whose context is the host index.

Incoming interrupt: the ISR (`sub_40290C`) only queues the DPC. The DPC (`sub_402938` → `sub_403940`) compares the state of every entry owned by this host with its last known value, and calls the state callbacks of the entries that changed.  
Outgoing interrupt: when an entry changes from `old` to `new` (`sub_4034F8`), every host (except APPS) that has an `INTR` entry and whose `SMEM_SMSM_CPU_INTR_MASK` cell for this entry has a bit in `old ^ new` is interrupted: the value of argument 6+4i is written to the register (`sub_403404`).

State callbacks (`sub_403474`): a list per entry of 16-byte records `{mask, callback, context, next}`. A callback is called as `callback(entry, old, new, context)` when `(old ^ new) & mask` ≠ 0. The only callback in the driver is `sub_4017A0`, which completes the pending [IOCTL 0x3200C](#ioctl-0x3200c).

### Lumia 520 ACPI node

From the DSDT. The node is `\_SB.SMSM` (`_HID` `QCOM0F30`, `_UID` 0), with `_DEP` on `\_SB.SMEM` ([qcsmem8930.sys](./qcsmem8930.md)).

`_CRS`: 4 interrupts `Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive)`, in the order of the `INTR` entries:  
| `INTR` entry | Remote host (SMSM index) | Outgoing register | Value | Incoming interrupt (GIC) |
|--------------|--------------------------|-------------------|-------|--------------------------|
| 0 | 1 MODEM | 0x02011008 | 0x00000010 (bit 4) | 70 |
| 1 | 2 Q6 | 0x02011008 | 0x00004000 (bit 14) | 121 |
| 2 | 3 WCNSS/RIVA | 0x02011008 | 0x00800000 (bit 23) | 236 |
| 3 | 4 DSPS | 0x12104094 | 0x00000001 | 169 |

`INTR` returns `Package (0x14) { 1, 4, 0, 0, <the 4 entries above, each followed by 0> }`.

### RIVA interrupt workaround

When the qcchipinfo8930.sys interface arrives (`sub_4018C8`), the driver opens it, sends [IOCTL 0x8C1F2008](#ioctl-0x8c1f2008) and [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004), then closes it.  
If the first returns 87 (0x57, chip id of the MSM8960) and the second is lower than 0x20000 (chip version < 2.0), it maps the physical address `0x00801284` (GPIO_40 ?) with `MmMapIoSpace` and writes 0 then 2 to it. After that, every outgoing interrupt to the host 3 (WCNSS/RIVA) is preceded by the same 0 / 2 write.  
The same workaround exists in [qcsmd8930.sys](./qcsmd8930.md#initialisation).

### RPE clients

`sub_401E38` initialises the RPE helper library (`RpeInit`: it waits for the Helper interface `{59752ed7-b9d5-4121-818d-c69f1e667015}` of [qcrpen8930.sys](./qcrpen8930.md)), then registers two clients (version string "1"):  
| Client name | Client GUID | Watches | Comment |
|-------------|-------------|---------|---------|
| SMSM (MODEM) | `{1c90923a-df5c-4761-9fd0-835b80f5281d}` | AMSS `{936dc601-5530-4b82-9d2a-72a488bec7c1}`, states 4 and 5 | `RpeClientInit`, initial state 5. Same GUID as the device interface |
| SMSM (RIVA) | `{3aabe343-4ea2-43f8-8404-8a4a01088dcf}` | WCN `{93367d0f-35ce-4ec4-8e38-bb33030c58b2}`, states 4 and 5 | `RpeClientInitMultiSegment` without memory segment, initial state 5 |

The state callback (`sub_401BC8`, `cb(Context, RPE_STATE *State, ULONG *NewState)`):
- state 4 (subsystem down ?): the entry of this subsystem is set to 0 (`sub_403C3C`: entry 1 for AMSS, entry 3 for WCN), and the state callbacks are called. `*NewState` = 4.
- state 5: `*NewState` = 5.
- other states: `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x32000

This IOCTL is processed by Qcsmsm8930.sys (`sub_402BD0`). Sent by [qcsmd8930.sys](./qcsmd8930.md#ioctl-0x32000) and [qcbamdmux8930.sys](./qcbamdmux8930.md#ioctl-0x32000).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| smsm_change_state | ≥ 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | smsm_state_item (e.g. SMSM_WCNSS_STATE) |
| 04-07 | 40 00 00 00 | clear_mask (e.g. SMSM_RESET) |
| 08-0B | 40 00 00 00 | set_mask (e.g. SMSM_RESET) |

This IOCTL calls the function `smsm_change_state(enum smsm_state_item item, uint32_t clear_mask, uint32_t set_mask)` (`sub_403590`) with the 3 DWORD of the Inputbuffer as parameters: `new = (old & ~clear_mask) | set_mask`. Then the other hosts are interrupted and the local state callbacks are called (see [Interrupts](#interrupts)).  
Any entry can be written, not only `SMSM_APPS_STATE`.  
Empty InputBuffer or entry ≥ 8 → `STATUS_INVALID_PARAMETER`.

### IOCTL 0x32004

This IOCTL is processed by Qcsmsm8930.sys (`sub_402BD0`).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| smsm_get_state | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | smsm_state_item (e.g. SMSM_WCNSS_STATE) |

This IOCTL calls the function `smsm_get_state(enum smsm_state_item item)` (`sub_40355C`) and the Inputbuffer is the parameter of the function.  
The state is returned in the `Information` field of the IO_STATUS_BLOCK, not in a buffer.  
Entry ≥ 8 → `STATUS_INVALID_PARAMETER` with `Information` = 0x80000000.

### internal IOCTL 0x32008

This internal IOCTL is processed by Qcsmsm8930.sys (`sub_4029D0`). Sent by [qcwcn8930.sys](./qcwcn8930.md).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_SMSM_RESET | ignored | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Address of `FuncSmsmReset` (`sub_403BF8`) |

`void FuncSmsmReset(uint32_t clear_mask)`: `SMSM_APPS_STATE = (old & ~clear_mask) | SMSM_RESET (0x40)`, then the other hosts are interrupted. It takes no lock and doesn't call the local state callbacks (usable from a crash path ?).  
Empty OutputBuffer → `STATUS_INVALID_PARAMETER`.

### IOCTL 0x3200C

This IOCTL is processed by Qcsmsm8930.sys (`sub_402BD0`, `EvtIoDeviceControl`). Sent by [qcwcn8930.sys](./qcwcn8930.md) and [qcbamdmux8930.sys](./qcbamdmux8930.md#ioctl-0x3200c) (asynchronously, entry `SMSM_MODEM_STATE`, mask and expected state `SMSM_A2_POWER_CONTROL` 0x2).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Wait for a state | ≥ 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | smsm_state_item (e.g. SMSM_WCNSS_STATE) |
| 04-07 | 40 00 00 00 | state_mask (e.g. SMSM_RESET) |
| 08-0B | 40 00 00 00 | expected_state (e.g. SMSM_RESET) |

The driver registers its state callback `sub_4017A0` on the entry with `state_mask` (`sub_4039F8`), and ORs `state_mask` into the `SMEM_SMSM_CPU_INTR_MASK` cell (entry, APPS) so the owner of the entry interrupts the APPS when these bits change.  
Then, if `(state & state_mask) == expected_state`, the request is completed at once. Otherwise it's marked cancelable and kept in a list (12-byte record, pool tag `qsm2`) until a state change satisfies the condition.  
The request is completed with `STATUS_SUCCESS` and `Information` = the state of the entry.  
Errors: empty InputBuffer or entry ≥ 8 → `STATUS_INVALID_PARAMETER`; out of memory → `STATUS_INSUFFICIENT_RESOURCES`; cancelled → `STATUS_CANCELLED`. If the callback registration fails, the request is completed with `STATUS_SUCCESS` and `Information` = 0.

### internal IOCTL 0x32010

This internal IOCTL is processed by Qcsmsm8930.sys (`sub_4029D0`). Sent by [qcwcn8930.sys](./qcwcn8930.md).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_INTERNAL_SMSM_STATE_GET | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Address of `uint32_t smsm_get_state(enum smsm_state_item item)` (`sub_40355C`) |

The function returns `SMEM_SMSM_SHARED_STATE[item]`, without bound check and without lock.  
Empty OutputBuffer → `STATUS_INVALID_PARAMETER`. Any other internal IOCTL → `STATUS_NOT_SUPPORTED` (0xC00000BB).

### internal IOCTL 0x42000

This internal IOCTL is sent by Qcsmsm8930.sys to [qcsmem8930.sys](./qcsmem8930.md#internal-ioctl-0x42000) (`sub_403CF8`), once at start.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Get the SMEM function table | \Device\SMEM | 0 | 52 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-33 | ? | 13 function pointers (`smem_alloc`, `smem_get_addr`, …), see the [function table of qcsmem8930.sys](./qcsmem8930.md#function-table) |

The table is stored at `.data:0x00409B24`. `BytesReturned` ≠ 52 → `STATUS_IO_DEVICE_ERROR` (0xC0000185), and the device is not created.  
The I/O target on `\Device\SMEM` stays open (`.data:0x00409B20`) for [internal IOCTL 0x42004](#internal-ioctl-0x42004).

### internal IOCTL 0x42004

This internal IOCTL is sent by Qcsmsm8930.sys to [qcsmem8930.sys](./qcsmem8930.md#internal-ioctl-0x42004) (`sub_403E48`), once per `INTR` entry.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Translate a physical address | \Device\SMEM | 8 | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Physical address of the outgoing interrupt register (argument 5+4i of `INTR`) |
| 04-07 | 00 00 00 00 | |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | |
| 04-07 | ? | Virtual address. 0 = not found, the `INTR` configuration is rejected |

### IOCTL 0x32C004

This IOCTL (`IOCTL_ACPI_EVAL_METHOD`) is sent by Qcsmsm8930.sys to its own ACPI node (`sub_40150C`, through `WdfDeviceGetIoTarget`).

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | default I/O target | 8 | 20, then the size returned |

Inputbuffer (ACPI_EVAL_INPUT_BUFFER):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `AeiB` |
| 04-07 | 49 4E 54 52 | Method name `INTR` |

Outputbuffer (ACPI_EVAL_OUTPUT_BUFFER):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature `BoeA` |
| 04-07 | ? | Length: required size of the Outputbuffer |
| 08-0B | ? | Count: number of arguments, must be ≥ 1 |
| 0C-0F | 00 00 04 00 | Argument 0: Type 0 (integer), DataLength 4 |
| 10-13 | 01 00 00 00 | Argument 0: value, must be 1 |
| ... | ... | 8 bytes per argument, see the [format of the package](#interrupts) |

It's first sent with a 20-byte OutputBuffer. On `STATUS_BUFFER_OVERFLOW` (0x80000005) a buffer of `Length` bytes is allocated (NonPagedPoolNx, pool tag `qsm1`) and the IOCTL is sent again.

### IOCTL 0x8C1F2004

This IOCTL is sent by Qcsmsm8930.sys to [qcchipinfo8930.sys](./qcchipinfo8930.md#ioctl-0x8c1f2004) (`sub_4018C8`), when its interface arrives. Same use as in [qcsmd8930.sys](./qcsmd8930.md#ioctl-0x8c1f2004).

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get chip version | qcchipinfo8930.sys interface | 0 | 4 |

Returns the chip version as `major << 16 | minor`. The [workaround](#riva-interrupt-workaround) is applied when the value is lower than 0x20000 (version < 2.0).

### IOCTL 0x8C1F2008

This IOCTL is sent by Qcsmsm8930.sys to [qcchipinfo8930.sys](./qcchipinfo8930.md#ioctl-0x8c1f2008) (`sub_4018C8`), when its interface arrives. Same use as in [qcsmd8930.sys](./qcsmd8930.md#ioctl-0x8c1f2008).

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get chip id | qcchipinfo8930.sys interface | 0 | 4 |

Returns the chip id, see [qcchipinfo8930.sys](./qcchipinfo8930.md#chip-ids). The [workaround](#riva-interrupt-workaround) is applied when the value is 87 (0x57, MSM8960). The MSM8227 of the Lumia 520 should return 121 (0x79) ?

---

### Interface GUID

qcsmsm8930 Interface Class GUID (also the RPE client GUID of "SMSM (MODEM)")  
`{1c90923a-df5c-4761-9fd0-835b80f5281d}`

qcchipinfo8930 Interface Class GUID  
`{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}`

RPE (Helper) Interface Class GUID  
`{59752ed7-b9d5-4121-818d-c69f1e667015}`

### Other GUID

RPE client "SMSM (MODEM)"  
`{1C90923A-DF5C-4761-9FD0-835B80F5281D}`

RPE client "SMSM (RIVA)"  
`{3AABE343-4EA2-43F8-8404-8A4A01088DCF}`

Watched RPE client AMSS (MODEM)  
`{936DC601-5530-4B82-9D2A-72A488BEC7C1}`

Watched RPE client WCN ([qcwcn8930.sys](./qcwcn8930.md))  
`{93367D0F-35CE-4EC4-8E38-BB33030C58B2}`
