## QcBluetooth8930.sys

Bluetooth "Serial HCI" bus driver.  
It is started by the Qcwcn8930 driver.  
It carries the HCI traffic between the Windows Bluetooth stack and the Bluetooth core of the WCNSS (RIVA) through two SMD channels of [qcsmd8930.sys](./qcsmd8930.md): `APPS_RIVA_BT_CMD` (HCI commands / events) and `APPS_RIVA_BT_ACL` (HCI ACL data).  
When Bluetooth is switched on it opens both channels, downloads the Bluetooth address (and optionally other NVM items) to the controller with Qualcomm vendor-specific HCI commands, then creates a child PDO (`SystemBusQc\SMD_BT`, compatible ID `MS_BTHX_BTHMINI`) on which the Microsoft `BthMini` driver loads. `BthMini` talks to this driver with the standard `IOCTL_BTHX_*` requests ([Transport Bus Driver for Bluetooth](https://learn.microsoft.com/en-us/windows-hardware/drivers/bluetooth/transport-bus-driver-for-bluetooth-power-handling-guidelines)).  
The Bluetooth address is read from the file `C:\DPP\QCOM\BT.PROVISION`.  
The PDB path embedded in the binary is `P:\Bluetooth\rel\8.2.1.1\arm\Release\qcbluetooth8930.pdb`.

There's no named device object and no symbolic link. The FDO has the device type `FILE_DEVICE_BUS_EXTENDER` (0x2A), and its default queue is parallel.

Registries of the bus driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcbluetooth`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM01E0\3&ddcf83e&0&1`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0093`  

Registry values read from the **service key** `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcbluetooth` (`WdfDriverGetRegistryPath`):  
| Registry value | value | comment |
|----------------|-------|---------|
| BtOnOff | 0x0=off or 0x1=on | REG_DWORD, default 1. Persists the state of the radio. Read in `EvtDriverDeviceAdd`; written by [IOCTL 0x2A8004](#ioctl-0x2a8004) and when the radio is switched on at boot. If 1, the radio is switched on by `EvtDevicePrepareHardware`. |
| DynamicSwitch | 0 | REG_DWORD, default 0. See [DynamicSwitch mode](#dynamicswitch-mode). |
| DownLoadNVMItems | 0 | 1 byte, default 0. Selects how the controller is configured, see [Controller initialization](#controller-initialization). |
| BtleRSSI | 0 | 1 byte, default 0. If not 0, the NVM tag 0x5A is written (only when `DownLoadNVMItems`=0). |
| BrEdrPowerClass | 0 | REG_DWORD, default 0, clamped to 2. Only used when `DownLoadNVMItems`≠0. |
| LePowerClass | 1 | REG_DWORD, default 1, clamped to 2. Selects the NVM tag 0x24 table (only used when `DownLoadNVMItems`≠0). |

Registry values read from the **Parameters** subkey `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcbluetooth\Parameters` (`WdfDriverOpenParametersRegistryKey`):  
| Registry value | value | comment |
|----------------|-------|---------|
| BTDStateEnabled | 0x01 | REG_BINARY, 1 byte, default 1 (written with the default value if missing). Forced to 0 when `DynamicSwitch`≠0. Sets `IsDeviceIdleCapable` / `IsDeviceWakeCapable` in the capabilities and selects the S0-idle settings (see below). |
| BDAddr | e.g. `53 7B C7 3E 92 78` | REG_BINARY, 6 bytes. Fallback for the Bluetooth address when `BT.PROVISION` can't be read. |

> [!NOTE]
> When the `Parameters` key can't be opened, `Read1ByteRegistryValue` (`sub_407540`) tries to create the key `Computer\HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\QcBluetooth`. This is the path as displayed by regedit, not a valid kernel path, so the creation fails.

GUID Bus type (`WdfDeviceSetBusInformationForChildren`, legacy bus type 15 `PNPBus`, bus number 0):  
`{4D36E978-E325-11CE-BFC1-08002BE10318}` (same GUID as the "Ports" device class)

GUID of the interfaces:  
`{B53A9DB7-1343-4C7F-B7BC-251B03DD8E34}` always created and enabled by `EvtDriverDeviceAdd`. It's the interface used to open the driver and send [IOCTL 0x2A8004](#ioctl-0x2a8004) / [IOCTL 0x2A8008](#ioctl-0x2a8008) ?  
`{2388B968-8AC1-401F-9C4C-11713C110F39}` only created when `DynamicSwitch`≠0, see [DynamicSwitch mode](#dynamicswitch-mode).

GUID of the ETW provider:  
`{C484A08D-41CE-4CD6-AF73-06F987827ACE}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Shared Memory Device. One WDF I/O target per channel (a `\Device\SMD` handle is bound to a single channel) |

### SMD channels

Each channel is opened with its own `WdfIoTargetOpen` on `\Device\SMD`, followed by [internal IOCTL 0x22003](#internal-ioctl-0x22003). The HCI packets are then exchanged with plain read/write requests (`WdfIoTargetFormatRequestForRead` with a 512-byte buffer, `WdfIoTargetFormatRequestForWrite`). The channels are closed with [internal IOCTL 0x22007](#internal-ioctl-0x22007) in `EvtDeviceReleaseHardware`.

| SMD channel | Direction | Content |
|-------------|-----------|---------|
| `APPS_RIVA_BT_CMD` | write | HCI Command packets |
| `APPS_RIVA_BT_CMD` | read | HCI Event packets |
| `APPS_RIVA_BT_ACL` | read/write | HCI ACL packets |

### Bluetooth address

`readBD_ADDR` (`sub_40686C`) reads the address in this order:
1. The file `BT.PROVISION`. When the `ProductSuite` value of `HKLM\System\CurrentControlSet\Control\ProductOptions` is `PhoneNT`, the file is `\DosDevices\C:\DPP\QCOM\BT.PROVISION` (DPP = Device Provisioning Partition). Otherwise it is looked for in the `DPP\QCOM\` folder of the EFI System Partition (`{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}`), or directly in the raw DPP partition.
2. If the file is missing, shorter than 8 bytes, or its first byte isn't 1: the `BDAddr` value of the `Parameters` key.

Content of `BT.PROVISION` (the bluetooth address is 78-92-3E-C7-7B-53):
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Must be 1 |
| 01 | 06 | Length of the address ? (not checked) |
| 02-07 | 78 92 3E C7 7B 53 | Bluetooth address, most significant byte first |

If no address is found, `00 00 00 00 00 00` is used (`dword_40D148`).

### Controller initialization

`InitializeBluetoothDeviceResources` (`sub_406E40`) runs when the radio is switched on:
1. Open `APPS_RIVA_BT_CMD` and `APPS_RIVA_BT_ACL` ([internal IOCTL 0x22003](#internal-ioctl-0x22003)), start both I/O targets, create the manual queues that hold the pending `IOCTL_BTHX_READ_HCI` requests (one for events, one for ACL).
2. Read `DownLoadNVMItems` and configure the controller (see below). Each command is written on `APPS_RIVA_BT_CMD`, and the driver waits for the HCI event before sending the next one.
3. Start the read loops on both channels (`processEvent`, `processACL`).
4. If `DynamicSwitch`=0: create the child PDO `SystemBusQc\SMD_BT` (serial number 4097), and set `BtOnOff`=1 in the registry.

The controller is configured with the Qualcomm vendor-specific HCI command **0xFC0B** (OGF 0x3F, OCF 0x00B, "NVM write"). Parameters: `01` (write) + NVM tag + length + data.

> [!NOTE]
> The function that sends the NVM items is named `WriteVendorSpecificCmdFC11` in the IDA database, but the opcode written on the wire is `0B FC` = 0xFC0B.

With `DownLoadNVMItems`=0 (default, `sub_406B34`):
| HCI Command (hex) | Comment |
|-------------------|---------|
| `0B FC 09 01 02 06 53 7B C7 3E 92 78` | NVM tag 0x02 = BD_ADDR (6 bytes, least significant byte first) |
| `0B FC 0B 01 5A 08 01 01 00 00 00 00 00 00` | NVM tag 0x5A, only if `BtleRSSI`≠0 |

With `DownLoadNVMItems`≠0 (`read_powerClass_from_registry`, `sub_4012FC`), the driver builds a list of NVM items (table 18 of `sub_40375C`) and sends each one with 0xFC0B:
| NVM item (hex) | Comment |
|----------------|---------|
| `01 02 06 <BD_ADDR>` | Tag 0x02 = BD_ADDR |
| `01 06 08 FF FE 8F FE 98 3F 59 87` | Tag 0x06 (8 bytes, LMP features ?) |
| `01 4E 02 05 05` | Tag 0x4E ? |
| `01 24 0C FF 00 07 07 07 07 00 00 07 07 02 00` | Tag 0x24 (power table ?), when `LePowerClass`=1 |
| `01 24 0C FF 03 07 09 09 09 00 00 09 07 04 00` | Tag 0x24, when `LePowerClass`=0 (nothing is sent for 2) |

When the radio is switched off (`switch_bt_off`, `sub_40724C`): the child PDO is removed, `BtOnOff`=0 is written, an **HCI_Reset** (`03 0C 00`) is sent and the driver waits for the Command Complete event `0E 04 01 03 0C 00`, then both SMD channels are closed.

### Power management

`WdfDeviceAssignS0IdleSettings` is called in `EvtDevicePrepareHardware`:
| BTDStateEnabled | IdleCaps | DxState | Enabled | UserControl | IdleTimeoutType |
|-----------------|----------|---------|---------|-------------|-----------------|
| ≠0 | IdleCanWakeFromS0 | D2 | True | IdleDoNotAllowUserControl | SystemManagedIdleTimeout |
| 0 | IdleCannotWakeFromS0 | D3 | False | IdleAllowUserControl | DriverManagedIdleTimeout |

### DynamicSwitch mode

When `DynamicSwitch`≠0:
- The radio is always started by `EvtDevicePrepareHardware`, but the child PDO is **not** created.
- A work item waits 5 seconds, then creates and enables the interface `{2388B968-8AC1-401F-9C4C-11713C110F39}`. The interface is disabled in `EvtDeviceReleaseHardware`.
- [IOCTL 0x2A8004](#ioctl-0x2a8004) doesn't switch anything: it only sets the in-memory on/off state to 0 and returns success.
- `IOCTL_BTHX_WRITE_HCI` / `IOCTL_BTHX_READ_HCI` are accepted even when the on/off state is 0.

### Child device

The bus driver creates a child device _Physical Device Object (PDO)_ (`EvtDriverDeviceAdd_BTHMINI`, `sub_408DE8`) with the following properties:  
- DeviceID / HardwareID : `SystemBusQc\SMD_BT`
- CompatibleID : `MS_BTHX_BTHMINI`
- InstanceID : `4097` (`%02d` of the serial number)
- DeviceType : FILE_DEVICE_BUS_EXTENDER
- DeviceDescription : `SerialHciBus_4097` (`SerialHciBus_%02d`), locale 0x409
- DeviceLocation : `Serial HCI Bus - Bluetooth Function`
- ContainerID : `{00000000-0000-0000-FFFF-FFFFFFFFFFFF}`
- ClassGUID : `{E0CBF06C-CD8B-4647-BB8A-263B43F0F974}` (Bluetooth)

This child device forwards the IOCTL_BTHX requests (0x410403 to 0x410413) to the default queue of its parent device (`WdfRequestForwardToParentDeviceIoQueue`). All other IOCTLs are completed with `STATUS_INVALID_PARAMETER`.  
On a transition to D3 (`EvtDeviceD0Exit`), if HCI packets are pending, a work item calls `WdfDeviceIndicateWakeStatus` on the PDO.

Registry of the child device:  
`HKLM\System\CurrentControlSet\Enum\SystemBusQc\SMD_BT\4&315a27b&0&4097`

---

### internal IOCTL 0x22003

This IOCTL is sent by QcBluetooth8930.sys to qcsmd8930.sys (`send_Ioctl_0x22003_to_SMD`, `sub_405780`).  
It's sent synchronously (60 seconds timeout), once per channel, on a new I/O target opened on `\Device\SMD`.

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
| 00-03 | ? | Pointer to the ANSI name of the SMD channel (`APPS_RIVA_BT_CMD` or `APPS_RIVA_BT_ACL`) |
| 04-07 | 06 00 00 00 | Edge: 6 = `SMD_APPS_RIVA` (APPS↔WCNSS) |
| 08-0B | 11 00 00 00 | Flags. 0x10 = wait until the RIVA has opened its side of the channel before completing. 0x01 is ignored by qcsmd8930.sys. 0x02 is not set, so the channel is in packet mode |
| 0C-0F | 00 20 00 00 | FIFO size: 0x2000 bytes (also the default) |
| 10-13 | 00 00 00 00 | No `PKEVENT` for "data received" |
| 14-17 | 00 00 00 00 | No `PKEVENT` for "channel opened" |
| 18-1B | 00 00 00 00 | No `PKEVENT` for "remote close ?" |

See [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) for the processing and the error codes. Because of flag 0x10, the request stays pending in qcsmd8930.sys until the WCNSS opens the channel, hence the 60-second timeout.

---

### internal IOCTL 0x22007

This IOCTL is sent by QcBluetooth8930.sys to qcsmd8930.sys (`send_Ioctl_0x22007_to_SMD`, `sub_405A24`), then the I/O target is closed.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Close a SMD channel | \Device\SMD | 0 | 0 |

qcsmd8930.sys completes it once the close is acknowledged, or returns `STATUS_INVALID_DEVICE_STATE` if no channel is open on the handle (see [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22007)).

---

### IOCTL 0x2A8004

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x1 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Switch BT on/off | >= 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | 0=off 1=on |

Switching on runs the [controller initialization](#controller-initialization); switching off runs `switch_bt_off`. Nothing is done if the radio is already in the requested state. Returns `STATUS_INVALID_PARAMETER` without input buffer. See [DynamicSwitch mode](#dynamicswitch-mode) for the behaviour when `DynamicSwitch`≠0.

---

### IOCTL 0x2A8008

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x2 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Query the "BtOnOff" state of the Bluetooth device | 0 | >= 1 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | 0=off 1=on |

---

### IOCTL 0x410403 — IOCTL_BTHX_GET_VERSION

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x100 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTHX_GET_VERSION | 0 | >= 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | BTHX version 1 |

---

### IOCTL 0x410407 — IOCTL_BTHX_SET_VERSION

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x101 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTHX_SET_VERSION | >= 4 | 0 |

The version is only logged; the IOCTL does nothing else.

---

### IOCTL 0x41040B — IOCTL_BTHX_QUERY_CAPABILITIES

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x102 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTHX_QUERY_CAPABILITIES | 0 | >= 16 |

Outputbuffer (`BTHX_CAPABILITIES`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 04 00 00 | MaxAclTransferInSize = 1025 |
| 04-07 | 02 00 00 00 | ScoSupport = ScoSupportHCIBypass |
| 08-0B | 01 00 00 00 | MaxScoChannels = 1 |
| 0C | 01 | IsDeviceIdleCapable = `BTDStateEnabled` |
| 0D | 01 | IsDeviceWakeCapable = `BTDStateEnabled` |
| 0E-0F | 00 00 | padding |

---

### IOCTL 0x41040F — IOCTL_BTHX_WRITE_HCI

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x103 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTHX_WRITE_HCI | >= 6 | 4 |

Send a HCI Command/ACL packet to the controller.  

Inputbuffer (`BTHX_HCI_READ_WRITE_CONTEXT`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 03 00 00 00 | DataLen. Command: 3 to 258. ACL: the ACL length at bytes 07-08 must be 1 to 1025 |
| 04 | 01 | Type: 1=Command (written on `APPS_RIVA_BT_CMD`), 2=ACL (written on `APPS_RIVA_BT_ACL`) |
| 05- | e.g. 03 0C 00 | HCI packet |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Number of bytes written ? |

Returns `STATUS_CANCELLED` when the radio is off (and `DynamicSwitch`=0), `STATUS_INVALID_PARAMETER` on wrong sizes/type. The write is asynchronous and cancelable.  
Special case: a Command with DataLen=4 and data `FF FF FF FF` isn't sent to the controller; the driver calls `WdfDeviceIndicateWakeStatus` on the child PDO instead.

---

### IOCTL 0x410413 — IOCTL_BTHX_READ_HCI

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x104 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_BTHX_READ_HCI | 4 | >= 6 |

Read a HCI Event/ACL packet from the controller.  

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 04 00 00 00 | Packet type: 4=Event, 2=ACL |

Outputbuffer (`BTHX_HCI_READ_WRITE_CONTEXT`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 06 00 00 00 | DataLen |
| 04 | 04 | Type: 4=Event, 2=ACL |
| 05- | e.g. 0E 04 01 03 0C 00 | HCI packet |

The request is put in the Event or ACL manual queue, and completed when a packet of this type is received from the SMD channel. Returns `STATUS_CANCELLED` when the radio is off (and `DynamicSwitch`=0), `STATUS_INVALID_PARAMETER` on wrong sizes/type.
