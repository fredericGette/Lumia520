## Qcslimbus8930.sys

Qualcomm **SLIMbus** controller driver of the MSM8930 (`\_SB.SLM1`, `QCOM0190`).  
It drives the SLIMbus core of the LPASS (registers at 0x28080000) as the active manager of the bus: it enumerates the devices on the bus (the WCD9304 "Sitar" codec), gives their logical addresses to the clients, sends value / information element messages, allocates the data ports and channels of the audio streams, connects the ports to the BAM pipes of the `LPASS_BAM` ([qckmbam8930.sys](./qckmbam8930.md)), and pauses the bus clock when nobody votes for it. The clients reach it through the device interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}` (IOCTL codes `0x85B5xxxx`).  
It is a KMDF driver. PDB path `P:\slimbus\rel\8.2.1\arm\Release\qcslimbus8930.pdb`, source file `src\SlimBusBamKmd.c` (BAM part). There are almost no strings: all messages are WPP traces. The structure of the IOCTLs follows the Qualcomm `DalSlimBus` API (logical address, value / information elements, master ports, data channels, resource groups, BAM transfers); the names below come from that API and from the behaviour, not from the binary.

ACPI device `\_SB.SLM1` (`_HID` `QCOM0190`, `_UID` 1). Resources (`_CRS`): `Memory32Fixed` 0x28080000, length 0x4000 (SLIMbus core); `Interrupt` 65 (0x41).

There's no named `\Device\` object (the PDO name is used).  
Symbolic link : `\Device\Slimbus` (created with `WdfDeviceCreateSymbolicLink`, once the BAM is found)  
The driver registers the device interface `{88EEFAB5-35A8-42FF-80DB-00D97137608D}` (see [Interface GUID](#interface-guid)) at the same time.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0190\1`  

There's no parameters in the registry.

WPP control GUID:  
`{C951B320-B923-4F26-A9BA-DA30550F2136}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of the device (default I/O target) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) `FNOC` and `EKOP`, see [ACPI methods](#acpi-methods) |
| interface `{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}` (`\Device\BAM<n>`) | [qckmbam8930.sys](./qckmbam8930.md) | Waited for with `IoRegisterPlugPlayNotification`. Keeps the BAM whose [IOCTL 0x42003](#ioctl-0x42003--0x42007) returns 0x28084000 (`LPASS_BAM`, `\_SB.BAM2`), then [0x42007](#ioctl-0x42003--0x42007), [0x4200B / 0x4200F](#ioctl-0x4200b--0x4200f) and [0x4201B](#ioctl-0x4201b). See [BAM](#bam) |

Drivers using qcslimbus8930.sys (interface `{88EEFAB5-…}`):  
| Driver | IOCTLs |
|--------|--------|
| [qcmbhc8930.sys](./qcmbhc8930.md) | 0x85B52000, 0x85B52400, 0x85B52404 |
| [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md) | 0x85B52000, 0x85B52400, 0x85B52404, 0x85B5240C, 0x85B52410 |
| [qcsitarcodec8930.sys](./qcsitarcodec8930.md) | 0x85B52000, 0x85B52400, 0x85B52404, 0x85B5240C, 0x85B52410 |

The clients of the port, channel and BAM IOCTLs (`0x85B528xx`, `0x85B52Cxx`, `0x85B534xx`) are unknown.

> [!NOTE]
> 0x85B52C23 is `METHOD_NEITHER` and the transfer IOCTLs carry physical addresses: the interface is meant for kernel-mode clients.

### Start sequence

1. `DriverEntry` (0x413008): WPP, `WdfDriverCreate` (`EvtDriverDeviceAdd` = `sub_412350`).
2. `EvtDriverDeviceAdd` (`sub_412718`):
   - file object callbacks: `EvtDeviceFileCreate` = `sub_40D0CC`, `EvtFileClose` = `sub_40D160`;
   - PnP/power callbacks: `EvtDeviceD0Entry` = `sub_40D324`, `EvtDeviceD0Exit` = `sub_40D7A4`, `EvtDevicePrepareHardware` = `sub_40D4A4`, `EvtDeviceReleaseHardware` = `sub_40D6F8`, `EvtDeviceSurpriseRemoval` = `sub_40D850`;
   - `WdfDeviceCreate` (context `SLIMBUS_DEVICE_CONTEXT`, cleanup `sub_40D8B4`), spin lock;
   - `sub_40353C`: reads `FNOC`, initialises the bus state (7 master ports, 32 data channels, 32 shared channels, 8 resource groups, see [Handles](#handles));
   - `sub_41240C`: worker thread `sub_40C11C` (priority 16) and the default queue (sequential, `EvtIoDeviceControl` = `sub_40B4B4`, `EvtIoInternalDeviceControl` = `sub_40C100` → same function, `EvtIoStop` = `sub_40B258`). The queue is stopped until the BAM is found;
   - timer (`sub_40D050`), interrupt (`SLIMBUS_ISR_CONTEXT`, ISR `sub_40CF28`, DPC `sub_40CF9C`, enable `sub_40D254`, disable `sub_40D2BC`), wait lock;
   - `WdfDeviceAssignS0IdleSettings`: idle in D3, system-managed idle timeout. The driver uses `WdfDeviceStopIdle` / `WdfDeviceResumeIdle` while the bus is active.
3. `EvtDevicePrepareHardware` (`sub_40D4A4`): maps the memory resource (`MmMapIoSpace`, context `+0x08`), keeps the end of the resource (base + length = 0x28084000, the address of the BAM of the SLIMbus) in the configuration block, then evaluates `EKOP` and writes its register values.
4. `EvtDeviceD0Entry` (`sub_40D324`): registers `IoRegisterPlugPlayNotification` on the BAM interface `{3E77CCA9-…}` (callback `sub_4125AC`, which queues the work item `sub_40CB64` with the symbolic link name); if the BAM is already known, re-initialises the hardware (`sub_40CA98`).
5. Work item `sub_40CB64` (for each BAM instance): opens the BAM, sends [IOCTL 0x42003](#ioctl-0x42003--0x42007) and keeps it only if the address is 0x28084000. For the first matching BAM: [IOCTL 0x42007](#ioctl-0x42003--0x42007), `WdfDeviceCreateDeviceInterface({88EEFAB5-…})`, `WdfDeviceCreateSymbolicLink(\Device\Slimbus)`, hardware initialisation (`sub_40CA98`: bus enumeration start, port registers), the interface is enabled, `WdfDeviceSetStaticStopRemove(FALSE)` and the queue is started.

Each client must open a handle on the interface: `EvtDeviceFileCreate` allocates a `SLIMBUS_CLIENT_CONTEXT` and attaches the client to the bus (`sub_4039E4`, flag at `+0x14`). Almost every IOCTL fails if the client isn't attached. `EvtFileClose` releases the client's vote ([0x85B52410](#ioctl-0x85b5240c--0x85b52410--bus-vote)), detaches it and frees its ports and channels (`sub_406760`).

### ACPI methods

Both methods are evaluated with `IOCTL_ACPI_EVAL_METHOD` (input signature `AeiB`, output signature `AeoB`) on the ACPI node.

`FNOC` (`sub_401008`, called from `EvtDriverDeviceAdd`): buffer of at least 15 bytes. Lumia 520: `00 00 40 00 17 02 01 00 02 03 01 01 FE FE FE`.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-05 | 00 00 40 00 17 02 | Enumeration address of the SLIMbus device of the controller itself (manufacturer 0x0217 Qualcomm, product 0x0040 ?) → `byte_410CB4` |
| 06-09 | 01 00 02 03 | ? → `byte_410CAC` |
| 0A | 01 | Execution environment of the processor (`dword_410CCC`): selects the port ownership register written at init (0 → +0x1020, 1 → +0x1024, 2 → +0x1028) |
| 0B | 01 | ≠ 0: flag 0x1000 added to the 3 next values (port ownership registers are written at init) |
| 0C | FE | Flags (`dword_410CDC`, context `+0x1C`). Bit 0 = ? (when 0, `sub_40B120` is called after each port allocation / release) |
| 0D | FE | ? (`dword_410CE0`) |
| 0E | FE | ? (`dword_410CE4`) |

`EKOP` (`POKE`, in `EvtDevicePrepareHardware`): list of 8-byte entries `{physical address, value}`; each value is written with `MmMapIoSpace` / `MmUnmapIoSpace`. Lumia 520: `7C 20 80 00 01 00 00 00` → writes 1 at 0x0080207C (TLMM ?).

### Bus management

- The SLIMbus messages are built in the controller's TX queue (`sub_4022DC`); the answers (`REPLY_VALUE`, `REPLY_INFORMATION`) are matched with the request by the transaction id (TID, 8 per device) and wake the waiting thread. The wait times out after 500 ms.
- The 3 user-defined messages of the Qualcomm SLIMbus satellite protocol (manager address 0xFF) are also built: `DEFINE_CHAN` / `DEF_ACT_CHAN` (0x20 / 0x21, [0x85B52C08](#ioctl-0x85b52c08--define-data-channel)), `CHAN_CTRL` (0x23, [0x85B52C0C](#ioctl-0x85b52c0c--data-channel-control)) and `REQ_BW` (0x28, [0x85B52C10](#ioctl-0x85b52c10--reserve-message-bandwidth)). Context `+0x04` looks like a "satellite" flag: it's cleared at init (`sub_40353C`), and only then is the manager state allocated (`+0x1C24`), so on the Lumia 520 the driver seems to be the manager itself ?
- Clock pause: when the last vote is released ([0x85B52410](#ioctl-0x85b5240c--0x85b52410--bus-vote)) and nothing is pending (`sub_40A7B8`), the driver broadcasts the core messages `BEGIN_RECONFIGURATION` (0x40), `NEXT_PAUSE_CLOCK` (0x4A, restart time 2) and `RECONFIGURE_NOW` (0x5F), and the bus goes to the "paused" state. The next vote ([0x85B5240C](#ioctl-0x85b5240c--0x85b52410--bus-vote)) wakes it (`sub_40A760`: `WdfDeviceStopIdle`, bit 0 of the register +0x41C).

### Handles

The port, channel and group handles returned by the IOCTLs are 32-bit values `0x00TTSSNN`: `TT` = type, `SS` = rolling 8-bit counter (context `+0x14`), `NN` = index.  
| Type | Handle | Count | Comment |
|------|--------|-------|---------|
| 1 | `0x0001SSNN` | 7 | Master port of the controller (hardware port numbers 17-23), [0x85B52800](#ioctl-0x85b52800--allocate-master-ports) |
| 2 | `0x0002LLPP` | - | Port `PP` of the device at logical address `LL`, [0x85B52808](#ioctl-0x85b52808--get-slave-port-handle) |
| 3 | `0x0003SSNN` | 32 | Data channel (channel numbers 65-96), [0x85B52C00](#ioctl-0x85b52c00--allocate-data-channel) |
| 5 | `0x0005SSNN` | 8 | Resource group, [0x85B53400](#ioctl-0x85b53400--allocate-resource-group) |
| 6 | `0x0006SSNN` | 32 | Shared data channel (channel numbers 128-159), [0x85B52C04](#ioctl-0x85b52c04--allocate-shared-data-channel) |

### BAM

The data ports of the SLIMbus core are connected to the pipes of the `LPASS_BAM` (`\_SB.BAM2`, 0x28084000), right after the SLIMbus registers. The driver opens every instance of the BAM interface and keeps the one whose [IOCTL 0x42003](#ioctl-0x42003--0x42007) returns base + length of its own memory resource.  
For each master port configured with [0x85B52810](#ioctl-0x85b52810--configure-master-pipe), it connects a BAM pipe ([IOCTL 0x4200B](#ioctl-0x4200b--0x4200f)): the pipe number is read from the port register (+0x1084 + 0x20 × port, bits 4-11), the descriptor FIFO is a 256-byte slice (32 descriptors) of a contiguous buffer (context `+0x1C7C`, `sub_40114C`). It then preallocates 32 requests for [IOCTL 0x4201B](#ioctl-0x4201b) (`sub_407AC8`, 12-byte input / 20-byte output memory) and a manual queue for the client requests ([0x85B52C23](#ioctl-0x85b52c23--submit-bam-transfer)).

---

### IOCTL 0x85B52xxx — summary

These IOCTLs are processed by Qcslimbus8930.sys. They can be sent as IOCTL or internal IOCTL (both callbacks are the same function `sub_40B4B4`).

| Property | Value |
|----------|-------|
| Device | 0x85B5 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED (0x85B52C23: METHOD_NEITHER) |

| Code | Function | Name | InputBuffer size | OutputBuffer Size | Handler |
|------|----------|------|------------------|-------------------|---------|
| 0x85B52000 | 0x800 | [Get logical address](#ioctl-0x85b52000--get-logical-address) | 6 | 1 | `sub_403C18` |
| 0x85B52004 | 0x801 | [Check root frequency ?](#ioctl-0x85b52004--check-root-frequency-) | 4 | 0 | inline |
| 0x85B52400 | 0x900 | [Read value element](#ioctl-0x85b52400--0x85b52404--0x85b52408--value-elements) | ≥ 12 | size | `sub_404794` (MC 0x60) |
| 0x85B52404 | 0x901 | [Write value element](#ioctl-0x85b52400--0x85b52404--0x85b52408--value-elements) | ≥ 12 + size | 0 | `sub_404AF4` (MC 0x68) |
| 0x85B52408 | 0x902 | [Read and change value element](#ioctl-0x85b52400--0x85b52404--0x85b52408--value-elements) | ≥ 12 + size | size | `sub_404794` (MC 0x61) |
| 0x85B5240C | 0x903 | [Acquire bus (vote)](#ioctl-0x85b5240c--0x85b52410--bus-vote) | 0 | 0 | inline |
| 0x85B52410 | 0x904 | [Release bus (vote)](#ioctl-0x85b5240c--0x85b52410--bus-vote) | 0 | 0 | inline |
| 0x85B52414 | 0x905 | [Read information element](#ioctl-0x85b52414--0x85b52418--0x85b5241c--information-elements) | ≥ 12 | size | `sub_404794` (MC 0x20) |
| 0x85B52418 | 0x906 | [Clear information element](#ioctl-0x85b52414--0x85b52418--0x85b5241c--information-elements) | ≥ 12 + size | 0 | `sub_404BB0` (MC 0x28) |
| 0x85B5241C | 0x907 | [Read and clear information element](#ioctl-0x85b52414--0x85b52418--0x85b5241c--information-elements) | ≥ 12 + size | size | `sub_404C90` (MC 0x21) |
| 0x85B52800 | 0xA00 | [Allocate master ports](#ioctl-0x85b52800--allocate-master-ports) | 12 | 4 × n | `sub_404040` |
| 0x85B52804 | 0xA01 | [Free master ports](#ioctl-0x85b52804--free-master-ports) | 4 × n | 0 | `sub_403F14` |
| 0x85B52808 | 0xA02 | [Get slave port handle](#ioctl-0x85b52808--get-slave-port-handle) | 8 | 4 | inline |
| 0x85B5280C | 0xA03 | [Configure master port](#ioctl-0x85b5280c--configure-master-port) | 20 | 0 | `sub_404320` |
| 0x85B52810 | 0xA04 | [Configure master pipe](#ioctl-0x85b52810--configure-master-pipe) | 16 | 0 | `sub_4083B4` |
| 0x85B52814 | 0xA05 | [Get port FIFO status](#ioctl-0x85b52814--get-port-fifo-status) | 8 | 8 | `sub_406250` |
| 0x85B52818 | 0xA06 | [Register port event](#ioctl-0x85b52818--0x85b5281c--port-events) | 16 | 0 | `sub_406364` |
| 0x85B5281C | 0xA07 | [Get port event](#ioctl-0x85b52818--0x85b5281c--port-events) | 4 | 12 | `sub_406410` |
| 0x85B52820 | 0xA08 | [Connect port to channel](#ioctl-0x85b52820--0x85b52824--port-connection) | 12 | 0 | `sub_40557C` |
| 0x85B52824 | 0xA09 | [Disconnect port](#ioctl-0x85b52820--0x85b52824--port-connection) | 4 | 0 | `sub_405838` |
| 0x85B52C00 | 0xB00 | [Allocate data channel](#ioctl-0x85b52c00--allocate-data-channel) | 0 | 4 | `sub_404D78` |
| 0x85B52C04 | 0xB01 | [Allocate shared data channel](#ioctl-0x85b52c04--allocate-shared-data-channel) | 4 | 4 | `sub_404E4C` |
| 0x85B52C08 | 0xB02 | [Define data channel](#ioctl-0x85b52c08--define-data-channel) | 32 | 0 | `sub_404FF0` |
| 0x85B52C0C | 0xB03 | [Data channel control](#ioctl-0x85b52c0c--data-channel-control) | 8 | 0 | `sub_405AA8` |
| 0x85B52C10 | 0xB04 | [Reserve message bandwidth](#ioctl-0x85b52c10--reserve-message-bandwidth) | 4 | 0 | `sub_404654` |
| 0x85B52C14 | 0xB05 | [Reconfigure now](#ioctl-0x85b52c14--reconfigure-now) | 0 | 0 | `sub_405F84` |
| 0x85B52C18 | 0xB06 | [Get data channel status](#ioctl-0x85b52c18--0x85b52c1c--data-channel-status--free) | 4 | 4 | `sub_4017D4` |
| 0x85B52C1C | 0xB07 | [Free data channel](#ioctl-0x85b52c18--0x85b52c1c--data-channel-status--free) | 4 | 0 | `sub_406154` |
| 0x85B52C23 | 0xB08 | [Submit BAM transfer](#ioctl-0x85b52c23--submit-bam-transfer) | 16 | 12 | `sub_408794` |
| 0x85B53400 | 0xD00 | [Allocate resource group](#ioctl-0x85b53400--allocate-resource-group) | 0 | 4 | `sub_406508` |
| 0x85B53404 | 0xD01 | [Free resource group](#ioctl-0x85b53404--0x85b53408--resource-groups) | 4 | 0 | `sub_4065C8` |
| 0x85B53408 | 0xD02 | [Add channel to group](#ioctl-0x85b53404--0x85b53408--resource-groups) | 8 | 0 | `sub_406690` |

The sizes are minimum sizes (`WdfRequestRetrieveInputBuffer` / `WdfRequestRetrieveOutputBuffer`).  
The IOCTLs that send bus messages or reconfigure the bus (0x85B52400-0x85B5241C except 0x85B5240C / 0x85B52410, 0x85B52804, 0x85B5280C, 0x85B52810, 0x85B52820, 0x85B52824, 0x85B52C0C, 0x85B52C14, 0x85B52C1C) are marked cancelable and handed to the worker thread `sub_40C11C`; the others are processed in the dispatcher.  
Errors: most failures → `STATUS_UNSUCCESSFUL` (0xC0000001); device being removed (context `+0x1C6C`) → `STATUS_INVALID_DEVICE_STATE` (0xC0000184); cancelled → `STATUS_CANCELLED`. Unknown codes are completed with `STATUS_SUCCESS`.

---

### IOCTL 0x85B52000 — Get logical address

This IOCTL is processed by Qcslimbus8930.sys (`sub_403C18`). Sent by [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus), [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus) and [qcsitarcodec8930.sys](./qcsitarcodec8930.md#slimbus).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get logical address | 6 (exact) | 1 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-05 | e.g. 00 01 00 00 17 02 | Enumeration address of the device (device index, instance, product id, manufacturer id 0x0217) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Logical address assigned by the controller |

Looks up the enumeration address in the table of the devices that reported present (`sub_403AB8`). Fails (`STATUS_UNSUCCESSFUL`) if the device hasn't been enumerated (yet): the clients retry.

---

### IOCTL 0x85B52004 — Check root frequency ?

This IOCTL is processed by Qcslimbus8930.sys

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 77 01 | Frequency in Hz: succeeds only for 24 576 000 (0x01770000) |

Nothing is changed: any other value → `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0x85B52400 / 0x85B52404 / 0x85B52408 — value elements

These IOCTLs are processed by Qcslimbus8930.sys (worker thread). 0x85B52400 and 0x85B52404 are sent by [qcmbhc8930.sys](./qcmbhc8930.md#ioctl-0x85b52000--0x85b52400--0x85b52404--slimbus), [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus) and [qcsitarcodec8930.sys](./qcsitarcodec8930.md#slimbus) to access the codec registers.

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x85B52400 Read value element (`REQUEST_VALUE`, MC 0x60) | ≥ 12 | size |
| 0x85B52404 Write value element (`CHANGE_VALUE`, MC 0x68) | ≥ 12 + size | 0 |
| 0x85B52408 Read and change value element (`REQUEST_CHANGE_VALUE`, MC 0x61) | ≥ 12 + size | size |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Logical address of the destination device |
| 01-03 | ? | Ignored |
| 04-07 | ? | Element address (12 bits). The codec drivers use register address + 0x800 |
| 08-0B | 01 00 00 00 | Size in bytes: 1, 2, 3, 4, 6, 8, 12 or 16 (a SLIMbus slice size); element address + size ≤ 0xC00 |
| 0C-… | ? | 0x85B52404 / 0x85B52408: value to write (size bytes) |

Outputbuffer (0x85B52400 / 0x85B52408):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | ? | Value read (size bytes) |

The message uses byte-based element addressing: element code = `(address << 4) | 0x8 | slice size code`. On a write, the trailing zero bytes of the value are not sent. The thread waits for the reply (`REPLY_VALUE`) for 500 ms.

---

### IOCTL 0x85B5240C / 0x85B52410 — bus vote

These IOCTLs are processed by Qcslimbus8930.sys. They are sent by [qcmbhcgpio8930.sys](./qcmbhcgpio8930.md#ioctl-0x85b52000--0x85b52400--0x85b52404--0x85b5240c--0x85b52410--slimbus) and [qcsitarcodec8930.sys](./qcsitarcodec8930.md#slimbus) around their bursts of register accesses.

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x85B5240C Acquire (vote for an active bus) | 0 | 0 |
| 0x85B52410 Release | 0 | 0 |

One vote per open handle (client context `+0x1B8`); the votes are counted in the device context (`+0x1C84`).  
0x85B5240C: when the count goes from 0 to 1 and the bus clock is paused, the bus is woken up (`sub_40A760`); if the pause is being entered (state 1), it's cancelled (state 2).  
0x85B52410 (and closing the handle): when the count goes back to 0, the bus clock is paused if the bus is idle (`sub_40A7B8`, see [Bus management](#bus-management)).

---

### IOCTL 0x85B52414 / 0x85B52418 / 0x85B5241C — information elements

These IOCTLs are processed by Qcslimbus8930.sys (worker thread).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x85B52414 Read information element (`REQUEST_INFORMATION`, MC 0x20) | ≥ 12 | size |
| 0x85B52418 Clear information element (`CLEAR_INFORMATION`, MC 0x28) | ≥ 12 + size | 0 |
| 0x85B5241C Read and clear information element (`REQUEST_CLEAR_INFORMATION`, MC 0x21) | ≥ 12 + size | size |

Inputbuffer: same layout as the [value elements](#ioctl-0x85b52400--0x85b52404--0x85b52408--value-elements); for 0x85B52418 / 0x85B5241C the bytes from 0x0C are the clear mask (copied into a buffer filled with 0xFF).

---

### IOCTL 0x85B52800 — Allocate master ports

This IOCTL is processed by Qcslimbus8930.sys (`sub_404040`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Allocate master ports | 12 | 4 × n |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Flags: bit 0 = allocate pairs of ports (even port + next odd port, e.g. half-duplex ?), bit 1 = contiguous ports. Bits 0 and 1 together → error |
| 04-07 | ? | Not used ? |
| 08-0B | ? | n = number of ports (the output buffer must be 4 × n bytes) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 00 SS 01 00 | Handle of the first port `0x0001SSNN`, see [Handles](#handles) |
| … | | One handle per port |

If not enough free ports are found, the allocated ones are freed and the IOCTL fails.

---

### IOCTL 0x85B52804 — Free master ports

This IOCTL is processed by Qcslimbus8930.sys (worker thread, `sub_403F14`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Free master ports | 4 × n (multiple of 4) | 0 |

Inputbuffer: the port handles. Each port is disconnected (and its pair), its registers are reset and the handle is set to 0xFFFFFFFF in the buffer.

---

### IOCTL 0x85B52808 — Get slave port handle

This IOCTL is processed by Qcslimbus8930.sys

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get slave port handle | 8 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Logical address of the device |
| 01-03 | ? | Ignored |
| 04 | ? | Port number on the device |
| 05-07 | ? | Ignored |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | PP LL 02 00 | Handle `0x0002LLPP` (computed, nothing is checked) |

---

### IOCTL 0x85B5280C — Configure master port

This IOCTL is processed by Qcslimbus8930.sys (worker thread, `sub_404320`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Configure master port | 20 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Master port handle |
| 04-07 | ? | Watermark (≤ 8, 16 or 32 depending on the port FIFO size) → bits 1-5 of the port configuration register (+0x1080 + 0x20 × port) |
| 08-0B | ? | Options: bit 0 → bit 6 of the register, bit 1 → bit 7 (packed / aligned ?) |
| 0C-0F | ? | → register +0x108C + 0x20 × port |
| 10-13 | ? | → register +0x1090 + 0x20 × port |

The register is then enabled (bit 0). For a pair of ports, the second port gets the same configuration. If the port is being disconnected, waits (500 ms) first.

---

### IOCTL 0x85B52810 — Configure master pipe

This IOCTL is processed by Qcslimbus8930.sys (worker thread, `sub_4083B4`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Configure master pipe | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Master port handle |
| 04-07 | 00 or 01 | Flow: 0 / 1 (direction of the BAM pipe, second port of a pair for 1) |
| 08-0F | ? | ? (descriptor FIFO size ≤ 0x100 ?) |

Connects the BAM pipe of the port ([IOCTL 0x4200B](#ioctl-0x4200b--0x4200f)), prepares the 32 transfer requests and the queue of the port, then enables the port (bit 0 of +0x1080 + 0x20 × port). See [BAM](#bam).

---

### IOCTL 0x85B52814 — Get port FIFO status

This IOCTL is processed by Qcslimbus8930.sys (`sub_406250`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get port FIFO status | 8 | 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Master port handle |
| 04-07 | 00, 01 or 02 | Flow (port of the pair) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | FIFO word count: bits 12-17 of the port status register (+0x1084 + 0x20 × port) |
| 04 | 00 or 01 | Bit 18 of the same register (watermark reached ?) |
| 05-07 | ? | Not written |

---

### IOCTL 0x85B52818 / 0x85B5281C — port events

These IOCTLs are processed by Qcslimbus8930.sys (`sub_406364`, `sub_406410`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x85B52818 Register port event | 16 | 0 |
| 0x85B5281C Get port event | 4 | 12 |

Inputbuffer (0x85B52818):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Master port handle |
| 04-07 | ? | ? (port entry `+0x5C`) |
| 08-0B | ? | User data, returned by 0x85B5281C |
| 0C-0F | ? | ? (≠ 0, event object / mask ?) |

Inputbuffer (0x85B5281C):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Master port handle, or 0 = first port of this client with a pending event |

Outputbuffer (0x85B5281C):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | User data given to 0x85B52818 |
| 04-07 | ? | Pending event flags (cleared by the read), 0 if none |
| 08-0B | ? | Port handle |

---

### IOCTL 0x85B52820 / 0x85B52824 — port connection

These IOCTLs are processed by Qcslimbus8930.sys (worker thread, `sub_40557C`, `sub_405838`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x85B52820 Connect port to channel | 12 | 0 |
| 0x85B52824 Disconnect port | 4 | 0 |

Inputbuffer (0x85B52820):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Data channel handle (type 3 or 6) |
| 04-07 | ? | Flow (source / sink ?) |
| 08-0B | ? | Port handle: master port (type 1) or slave port (type 2) |

Inputbuffer (0x85B52824):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Port handle (type 1 or 2) |

---

### IOCTL 0x85B52C00 — Allocate data channel

This IOCTL is processed by Qcslimbus8930.sys (`sub_404D78`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Allocate data channel | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | NN SS 03 00 | Handle of the first free channel (channel number 65 + NN) |

---

### IOCTL 0x85B52C04 — Allocate shared data channel

This IOCTL is processed by Qcslimbus8930.sys (`sub_404E4C`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Allocate shared data channel | 4 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 80 00 00 00 | Channel number, 128-159; fails if already allocated |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | NN SS 06 00 | Channel handle |

---

### IOCTL 0x85B52C08 — Define data channel

This IOCTL is processed by Qcslimbus8930.sys (`sub_404FF0`). Defines the parameters of a channel (or of all the channels of a resource group) for the next reconfiguration.

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Define data channel | 32 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Channel handle (type 3 / 6) or resource group handle (type 5) |
| 04-07 | e.g. 10 00 00 00 | Sample size in bits: multiple of 4, ≤ 32 (sent in units of 4 bits) |
| 08-0B | 00, 01 or 02 | Rate family: 0 = 4 kHz, 1 = 11.025 kHz, 2 = given in Hz |
| 0C-0F | ? | Rate: multiplier of the family (0 / 1), or rate in Hz (2). ≠ 0, ≤ 3 600 000 |
| 10-13 | 00-07 | Transport protocol (isochronous, pushed, pulled, locked, …) |
| 14-17 | ? | Options: bit 0 = ? |
| 18-1B | 00-03 | Data type (not indicated, LPCM, IEC 61937, …) |
| 1C-1F | 00 or 01 | Auxiliary bits format ? |

The segment distribution is computed from the root frequency and the rate (`sub_404F38`).

---

### IOCTL 0x85B52C0C — Data channel control

This IOCTL is processed by Qcslimbus8930.sys (worker thread, `sub_405AA8`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Data channel control | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Channel or resource group handle |
| 04-07 | 00, 01 or 02 | Operation for the next reconfiguration: activate, deactivate, remove ? |

---

### IOCTL 0x85B52C10 — Reserve message bandwidth

This IOCTL is processed by Qcslimbus8930.sys (`sub_404654`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Reserve message bandwidth | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Requested control bandwidth; converted to a number of slots (max 1536) |

Builds the `REQ_BW` message for the next reconfiguration (only if the number of slots changes).

---

### IOCTL 0x85B52C14 — Reconfigure now

This IOCTL is processed by Qcslimbus8930.sys (worker thread, `sub_405F84`). No buffer.

Applies the pending channel definitions / controls of the client (`RECONFIGURE_NOW`) and updates the state of its channels.

---

### IOCTL 0x85B52C18 / 0x85B52C1C — data channel status / free

These IOCTLs are processed by Qcslimbus8930.sys

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x85B52C18 Get data channel status | 4 | 4 |
| 0x85B52C1C Free data channel (worker thread, `sub_406154`) | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Channel handle |

Outputbuffer (0x85B52C18):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Channel state (channel entry `+0x20`, 0 = inactive ?) |

0x85B52C1C fails if the channel is still active.

---

### IOCTL 0x85B52C23 — Submit BAM transfer

This IOCTL is processed by Qcslimbus8930.sys (`sub_408794`).

| Property | Value |
|----------|-------|
| Device | 0x85B5 |
| Function | 0xB08 (2824) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Submit BAM transfer | 16 | 12 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Master port handle (pipe configured with [0x85B52810](#ioctl-0x85b52810--configure-master-pipe)) |
| 04-07 | 00, 01 or 02 | Flow |
| 08-0B | ? | Physical address of the buffer |
| 0C-0D | ? | Size in bytes |
| 0E-0F | ? | Ignored |

Outputbuffer (written at completion):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not written |
| 04-07 | ? | Physical address of the completed descriptor |
| 08-09 | ? | Size |
| 0A-0B | ? | Flags |

One preallocated request is sent to the BAM ([IOCTL 0x4201B](#ioctl-0x4201b), descriptor flags 0x8000), and the client request is forwarded to the queue of the port. It's completed by `sub_407234` when the BAM completes the descriptor. Fails if the 32 requests of the port are in use.

---

### IOCTL 0x85B53400 — Allocate resource group

This IOCTL is processed by Qcslimbus8930.sys (`sub_406508`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Allocate resource group | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | NN SS 05 00 | Group handle |

---

### IOCTL 0x85B53404 / 0x85B53408 — resource groups

These IOCTLs are processed by Qcslimbus8930.sys (`sub_4065C8`, `sub_406690`).

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| 0x85B53404 Free resource group | 4 | 0 |
| 0x85B53408 Add channel to group | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Group handle |
| 04-07 | ? | 0x85B53408: channel handle (not already in a group) |

A group lets a client define / control several channels with one [0x85B52C08](#ioctl-0x85b52c08--define-data-channel) / [0x85B52C0C](#ioctl-0x85b52c0c--data-channel-control).

---

### IOCTL 0x42003 / 0x42007

These IOCTLs are sent by Qcslimbus8930.sys to [qckmbam8930.sys](./qckmbam8930.md#ioctl-0x42003) (work item `sub_40CB64`).

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x800 / 0x801 (2048 / 2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x42003 Get BAM physical address | interface `{3E77CCA9-…}` | 0 | 4 |
| 0x42007 Initialize / reset BAM | interface `{3E77CCA9-…}` | 0 | 0 |

Outputbuffer (0x42003):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 40 08 28 | 0x28084000 expected (`LPASS_BAM`); other BAMs are closed |

0x42007 is only sent for the first matching BAM.

---

### IOCTL 0x4200B / 0x4200F

These IOCTLs are sent by Qcslimbus8930.sys to [qckmbam8930.sys](./qckmbam8930.md#ioctl-0x4200b) (`LPASS_BAM`).

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x802 / 0x803 (2050 / 2051) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| 0x4200B Connect pipe (`sub_4083B4`, also `sub_407E60`) | interface `{3E77CCA9-…}` | 52 | 0 |
| 0x4200F Disconnect pipe (`sub_407D18`) | interface `{3E77CCA9-…}` | 4 | 0 |

Inputbuffer (0x4200B, from `sub_4083B4`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pipe: from the port register (+0x1084 + 0x20 × port, bits 4-11) |
| 04-07 | ? | Same pipe number |
| 08-0B | 00 or 01 | Direction (flow ≠ 0) |
| 0C-0F | 01 00 00 00 | System mode |
| 10-13 | 01 00 00 00 | IRQ enable mask |
| 14-17 | ? | Physical address of the descriptor FIFO (buffer + 0x100 × port) |
| 18-1B | ? | Virtual address of the descriptor FIFO |
| 1C-1F | 00 01 00 00 | FIFO size 256 bytes |
| 20-33 | 0 | |

---

### IOCTL 0x4201B

This IOCTL is sent by Qcslimbus8930.sys to [qckmbam8930.sys](./qckmbam8930.md#ioctl-0x4201b) (asynchronously, `WdfRequestSend` of a preallocated request, completion `sub_407234`).

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x806 (2054) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Transfer | interface `{3E77CCA9-…}` | 12 | 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pipe |
| 04-07 | ? | Physical address of the client buffer |
| 08-09 | ? | Size |
| 0A-0B | 00 80 | Flags 0x8000 |

The output buffer (completed descriptor) is copied into the output buffer of [0x85B52C23](#ioctl-0x85b52c23--submit-bam-transfer).

---

### Interface GUID

Qcslimbus8930 Interface Class GUID  
`{88EEFAB5-35A8-42FF-80DB-00D97137608D}`

### Other GUID

BAM interface (target of `IoRegisterPlugPlayNotification`, [qckmbam8930.sys](./qckmbam8930.md#interface-guid))  
`{3E77CCA9-FC24-4F4B-8D97-D0F3937F5B22}`
