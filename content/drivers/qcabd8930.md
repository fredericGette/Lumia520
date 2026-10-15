## Qcabd8930.sys

ABD driver: a software I²C (SPB) target that lets ACPI code reach kernel drivers (Qualcomm KMDF driver, PDB `P:\ABD\rel\8.2.1.1\arm\Release\qcabd8930.pdb`, 47 functions).  
It acts as the SPB controller of an `I2cSerialBus` connection. When AML code accesses a `GenericSerialBus` operation region on that connection, [acpiex.sys](./acpiex.md) sends `IOCTL_SPB_EXECUTE_SEQUENCE` (0x41808) to this driver. The driver then forwards a read or a write to a kernel driver that has registered itself for the I²C slave address of the connection.  
The only known client is [qcpmicapps8930.sys](./qcpmicapps8930.md). It registers `IOCTL_PM_ABD_GET_PMIC_RTC_DATA` / `IOCTL_PM_ABD_SET_PMIC_RTC_DATA`, so ACPI `_GRT` / `_SRT` (see [acpitime.sys](./acpitime.md)) can read and write the PMIC real-time clock through an I²C operation region.  
The driver keeps up to 10 clients in a global table, with no locking.

There's no named device and no `\DosDevices` link. The driver registers a device interface (`WdfDeviceCreateDeviceInterface`):  
Interface : `{2B0FDE10-DED1-40C1-AF2E-031836A066A8}`

`WdfDeviceSetStaticStopRemove(FALSE)` is called: the device can't be stopped or removed.

> [!NOTE]
> The surprise-removal callback (`EvtWdfDeviceSurpriseRemoval`, 0x4010B4) calls `KeBugCheckEx(0x14E, 0x516F7030 'Qop0', 0, 0, 0)`: removing the device crashes the phone (same behaviour as qcpmic8930.sys and qcpmicapps8930.sys).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcabd8930`  

There's no parameters in the registry.

GUID of the ETW provider:  
None. The driver traces only with `DbgPrint` (`ABD: ERROR: %s:%d - %s` / `ABD: LOG: %s:%d - %s`, source files `Handler.c`, `Interface.c`, `Queue.c`).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\RESOURCE_HUB` | [acpiex.sys](./acpiex.md) | Opened without a file name at device creation. `IOCTL_RH_QUERY_CONNECTION_PROPERTIES` (0x2AC000) on each file open |
| Interface GUID given by the client at registration | e.g. [qcpmicapps8930.sys](./qcpmicapps8930.md) (`{CA95CEB1-A382-4F06-B65E-0A90115609A5}`) | The client's GET / SET IOCTLs (0x80100FA0 / 0x80100FA4 for qcpmicapps8930) |

It is called by:  
| Caller | IOCTL | Comment |
|--------|-------|---------|
| [qcpmicapps8930.sys](./qcpmicapps8930.md) | 0xC3502FA4 / 0xC3502FA8 | Registers / unregisters itself as the handler of an I²C slave address |
| [acpiex.sys](./acpiex.md) | 0x41808 | `GenericSerialBus` operation region accesses (`RhpSendSpbIoctl`) |

### Start-up

1. `DriverEntry` (0x407008): `WdfDriverCreate`. Pool tag `'ABD'` (0x444241).
2. `EvtDriverDeviceAdd` → `sub_406008`:
   * surprise-removal callback only (no PrepareHardware, no D0 callbacks),
   * file object config with `EvtDeviceFileCreate` = `EvtWdfDeviceFileCreate` (0x406170) and context `ABD_FILEOBJECT_CONTEXT`,
   * `WdfDeviceCreate`, with context `ABD_DEVICE_EXTENSION`: `+00` WDFDEVICE, `+04` WDM device object, `+08` PDO, `+0C` I/O target,
   * `sub_406344`: `WdfIoTargetCreate` + `WdfIoTargetOpen` by name on `\Device\RESOURCE_HUB` (DesiredAccess `0x1F0000`, `FILE_OPEN`, `FILE_NON_DIRECTORY_FILE`),
   * creates the `{2B0FDE10-…}` interface,
   * creates the default queue: sequential, **not power-managed**, `EvtIoDeviceControl` = `EvtWdfIoQueueIoDeviceControl` (0x406608),
   * `sub_401090` clears the client table.

### Client table

The table is a global array of 10 entries of 44 bytes at `.data:0x404A80`. It's filled by [IOCTL 0xC3502FA4](#ioctl-0xc3502fa4--attach):  
| Bytes | Comment |
|-------|---------|
| 00-0F | Interface GUID of the client (bytes 00-0F of the registration) |
| 10-11 | I²C slave address handled by the client (bytes 10-11 of the registration). 0 = free entry |
| 12-13 | Bytes 12-13 of the registration, unused |
| 14-17 | IOCTL code sent for a read ("GET") |
| 18-1B | IOCTL code sent for a write ("SET") |
| 1C-1F | Bytes 1C-1F of the registration (16 for qcpmicapps8930), unused |
| 20-23 | Handle of the `IoRegisterPlugPlayNotification` on the client's interface |
| 24 | 1 = the client's device object is known (interface arrived) |
| 28-2B | Client's device object (`IoGetDeviceObjectPointer`) |

PnP callback `sub_4010E0` (`EventCategoryDeviceInterfaceChange`, `PNPNOTIFY_DEVICE_INTERFACE_INCLUDE_EXISTING_INTERFACES`, context NULL): it looks up the entry by `InterfaceClassGuid`.
* On `GUID_DEVICE_INTERFACE_ARRIVAL`, it opens the symbolic link with `IoGetDeviceObjectPointer(FILE_ALL_ACCESS)`, then stores the device object and sets `+24` = 1. The file object is never dereferenced.
* On any other event, it clears `+24` and `+28`.

### Opening a connection

An SPB connection is opened as `<this device>\<16 hex digits>` (the name a `\Device\RESOURCE_HUB\<id>` open is reparsed to, see [acpiex.sys](./acpiex.md#opening-a-connection-deviceresource_hubid)). `EvtWdfDeviceFileCreate`:
1. Drops the leading `\` of the file name. If it starts with 16 hex digits followed by `\` or the end of the string, the first 8 digits become `IdHighPart` and the next ones `IdLowPart` (`RtlUnicodeStringToInteger`, base 16). Otherwise the connection id stays 0.
2. `sub_406408` sends [`IOCTL_RH_QUERY_CONNECTION_PROPERTIES`](#ioctl-0x2ac000--ioctl_rh_query_connection_properties) for this id. It's sent twice: once with a 12-byte buffer to get the size, then with the full size.
3. `sub_401008` checks the descriptor. The first byte must be `0x8E` (ACPI Serial Bus Connection descriptor), and the lengths must be consistent; otherwise `STATUS_INVALID_PARAMETER` (0xC000000D), or `STATUS_BUFFER_TOO_SMALL` (0xC0000023) if it's under 12 bytes. The serial bus type (byte 5) must be 1 = I²C, otherwise `STATUS_UNSUCCESSFUL` (0xC0000001).
4. `sub_401068` reads the **slave address** (word at offset 4 of the type-specific data) into the file context: `+00` = device extension, `+04` = slave address.

> [!NOTE]
> acpiex.sys is documented as opening its operation-region connections as `<controller>\ACPI\<16 hex digits>`. With this parser, the name `ACPI\…` fails the hex check, so connection id 0 is queried. It's not known how the two fit together (maybe the name or the open path differs on this build).

### Remarks

* The table isn't protected by a lock. Registration, unregistration and PnP callbacks can run concurrently with the sequential queue.
* On registration, `IoRegisterPlugPlayNotification` is called **before** the 32 bytes are copied into the entry. If the include-existing callback runs synchronously, it can't find the entry by GUID yet, and the device object would never be set ?
* The execute handler reads `TransferCount` and the last transfer entry without checking them against the buffer length (only ≥ 32 bytes is required). `TransferCount` = 0 makes it read 8 bytes before the transfer array.
* The device has no access restriction beyond the default WDF security, and no requestor-mode check is made.

---

### IOCTL 0xC3502FA4 — Attach

This IOCTL is processed by Qcabd8930.sys (sent by [qcpmicapps8930.sys](./qcpmicapps8930.md#ioctl-0xc3502fa4))  

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0xBE9 (3049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Attach (register a client) | ≥ 32 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | e.g. B1 CE 95 CA 82 A3 06 4F B6 5E 0A 90 11 56 09 A5 | Interface GUID of the client (`{CA95CEB1-…}` for qcpmicapps8930) |
| 10-11 | ? | I²C slave address served by the client (qcpmicapps8930: low byte of ACPI `GEPT`) |
| 12-13 | 00 00 | Unused |
| 14-17 | e.g. A0 0F 10 80 | IOCTL sent for a read (0x80100FA0 `IOCTL_PM_ABD_GET_PMIC_RTC_DATA`) |
| 18-1B | e.g. A4 0F 10 80 | IOCTL sent for a write (0x80100FA4 `IOCTL_PM_ABD_SET_PMIC_RTC_DATA`) |
| 1C-1F | e.g. 10 00 00 00 | Data size (16). Stored but unused |

Handler `sub_4011C0`:
1. Input under 32 bytes or NULL → failure.
2. If an entry has the same GUID, a non-zero address and a notification handle, the request fails with "The client attempting registration is already registered with the ABD driver".
3. It takes the first free entry (address, handle and flag all 0) and registers a PnP notification on the client's interface GUID (callback `sub_4010E0`). Then it copies the 32 bytes into the entry. If the registration fails, it tries the next free entry.

Returns `STATUS_SUCCESS`, or `STATUS_UNSUCCESSFUL` (0xC0000001) for any failure ("Attach request FAILED"). Information = 0.

---

### IOCTL 0xC3502FA8 — Detach

This IOCTL is processed by Qcabd8930.sys (sent by [qcpmicapps8930.sys](./qcpmicapps8930.md#ioctl-0xc3502fa8))  

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0xBEA (3050) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Detach (unregister a client) | ≥ 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | e.g. B1 CE 95 CA 82 A3 06 4F B6 5E 0A 90 11 56 09 A5 | Interface GUID of the client |

Handler `sub_401338`: the first entry with this GUID is released. It calls `IoUnregisterPlugPlayNotification`, then clears the address, the handle and the flag. The GUID and the device object are left in the entry. Returns `STATUS_SUCCESS`, or `STATUS_UNSUCCESSFUL` if no entry matches ("Detatch request FAILED").

---

### IOCTL 0x41808 — IOCTL_SPB_EXECUTE_SEQUENCE

This IOCTL is processed by Qcabd8930.sys, on a file opened on an I²C connection (sent by [acpiex.sys](./acpiex.md) for `GenericSerialBus` operation regions)  

| Property | Value |
|----------|-------|
| Device | 0x4 (FILE_DEVICE_CONTROLLER) |
| Function | 0x602 (1538) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_SPB_EXECUTE_SEQUENCE | ≥ 32 | 0 |

Inputbuffer (`SPB_TRANSFER_LIST`, 32-bit layout):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Size |
| 04-07 | | Reserved |
| 08-0B | | TransferCount (n) |
| 0C-1F | | Transfer 0 (20 bytes) |
| … | | Transfers 1 … n-1 |

Transfer entry (`SPB_TRANSFER_LIST_ENTRY`):  
| Bytes | Comment |
|-------|---------|
| 00-03 | Direction: 1 = from device (read), 2 = to device (write) |
| 04-07 | DelayInUs (ignored) |
| 08-0B | Buffer format (ignored, simple buffer assumed) |
| 0C-0F | Buffer pointer |
| 10-13 | Buffer length |

Handler `sub_401440`: only the **last** transfer is used. Earlier transfers, such as the command or register byte written first by acpiex.sys, are ignored. The I²C slave address of the file context is compared with every active entry of the [client table](#client-table), and each match gets a synchronous `IoBuildDeviceIoControlRequest` (`sub_40159C`):
* last transfer = write (2): the entry's SET IOCTL, input = the transfer buffer and length, no output.
* last transfer = read: the entry's GET IOCTL, input = 4 bytes holding the buffer length, output = the transfer buffer and length.

For qcpmicapps8930 the buffer must be exactly 16 bytes (the ACPI `_GRT` / `_SRT` time structure, see [Time format](./qcpmicapps8930.md#time-format)).

Returns the status of the last forwarded IOCTL. If no entry matches, it returns `STATUS_UNSUCCESSFUL` (0xC0000001, "Found no device to communicate with"). Information is always 0, so the caller isn't told how many bytes were read.

> [!NOTE]
> Any other IOCTL code → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010, "Invalid communication").

---

### IOCTL 0x2AC000 — IOCTL_RH_QUERY_CONNECTION_PROPERTIES

This IOCTL is sent by Qcabd8930.sys to [acpiex.sys](./acpiex.md#ioctl-0x2ac000--ioctl_rh_query_connection_properties) on each file open  

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x0 (0) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_RH_QUERY_CONNECTION_PROPERTIES | `\Device\RESOURCE_HUB` | 16 | 12, then 12 + length |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version |
| 04-07 | 00 00 00 00 | Query type 0: connection id |
| 08-0B | | IdLowPart (digits 9-16 of the file name) |
| 0C-0F | | IdHighPart (digits 1-8 of the file name) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version (not checked) |
| 04-07 | | Length of the properties |
| 08-… | 8E … | ACPI I²C Serial Bus Connection descriptor. Byte 05 = 1 (I²C), bytes 0A-0B = type data length, bytes 0C-0F = connection speed, bytes 10-11 = slave address |

The first call (12-byte output) must fail with `STATUS_BUFFER_TOO_SMALL`. The second call uses 12 + length bytes, and the properties are copied to a non-paged WDF memory object.

---

### Interface GUID

qcabd8930 device interface (registration target of [qcpmicapps8930.sys](./qcpmicapps8930.md))  
`{2B0FDE10-DED1-40C1-AF2E-031836A066A8}`

### Other GUID

PnP notification event GUIDs  
`{CB3A4004-46F0-11D0-B08F-00609713053F}` (GUID_DEVICE_INTERFACE_ARRIVAL)  
`{CB3A4005-46F0-11D0-B08F-00609713053F}` (GUID_DEVICE_INTERFACE_REMOVAL)
