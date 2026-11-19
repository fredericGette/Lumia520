## HidMessageBroker_G1.sys

Nokia "HID message broker" driver.  
It exposes a virtual HID device (vendor usage page 0xFFEE) and relays messages in both directions between user-mode "services" and the HID clients of that device:
- a service opens the control device, registers a service id and an event with [IOCTL 0x222004](#ioctl-0x222004--register-service), then sends messages with [IOCTL 0x222010](#ioctl-0x222010--write-message). Each message is delivered to the HID client as an **input report** (answer to `IOCTL_HID_READ_REPORT`);
- a HID client sends a **feature report** (`IOCTL_HID_SET_FEATURE`) whose second byte is a service id. The message is queued for that service, its event is signalled, and the service fetches it with [IOCTL 0x22200C](#ioctl-0x22200c--read-message);
- a HID client can list the registered service ids with `IOCTL_HID_GET_FEATURE` (report id 0x14).

The driver is a KMDF HID minidriver: it doesn't call `HidRegisterMinidriver`, and it calls `WdfDeviceInitSetPowerPolicyOwnership(FALSE)`, so it runs under the pass-through driver `mshidkmdf.sys` (? the INF isn't available). `DriverEntry` (0x40A000) calls `IoReportRootDevice`: the driver creates its own root-enumerated device.  
The VID/PID of the HID device and the names of the control device are read from the registry. Several copies of the driver are installed under different service names, and each copy uses its own registry subkey: [HidMessageBroker_G2.sys](./hidmessagebroker_g2.md) is byte-identical to this driver except for the signature. The build path `bldBLUE_GROUP1` is found in both copies.  
PDB path: `C:\CI\M\14993\bldBLUE_GROUP1\bldl2hidmessagebroker\Hidmessagebroker\Solution\ARM\Release\HidMessageBrokerDriver.pdb`. It only imports `ntoskrnl.exe` and `WDFLDR.SYS`.

Device name : from the registry value `DriverDeviceName` (control device)  
Symbolic link : from the registry value `DriverSymbolicName` (control device)  
Security descriptor of the control device: `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GRGW;;;WD)(A;;GR;;;RC)` (Everyone can read/write).  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\OEM\Nokia\HidMessageBroker\<subkey>`:  
| Registry value | value | comment |
|----------------|-------|---------|
| DriverServiceName | ? | REG_SZ. Compared (case-insensitive) with the service key name of the driver (`DriverObject->DriverExtension->ServiceKeyName`). The first subkey that matches is used |
| VID | ? | REG_DWORD. Vendor id of the HID device (truncated to 16 bits). Must not be 0 |
| PID | ? | REG_DWORD. Product id of the HID device (truncated to 16 bits). Must not be 0 |
| DriverDeviceName | ? | REG_SZ, max 128 bytes. Name of the control device (`WdfDeviceInitAssignName`), e.g. `\Device\...`. Must not be empty |
| DriverSymbolicName | ? | REG_SZ, max 128 bytes. Symbolic link of the control device (`WdfDeviceCreateSymbolicLink`), e.g. `\DosDevices\...`. Must not be empty |

`LoadConfig` (0x402220) opens `\Registry\Machine\SYSTEM\OEM\Nokia\HidMessageBroker` (KEY_READ) and enumerates its subkeys with `ZwEnumerateKey`. If no subkey matches, or if VID, PID or one of the names is missing, `OnDeviceAdd` fails with `STATUS_INVALID_PARAMETER` (0xC000000D).  
The configuration is traced as `Loaded configuration: <vid: 0x%x pid: 0x%x deviceName: %wZ symbolicName: %wZ>`.

GUID of the ETW provider (`EtwRegister`, events 1 = error / 2 = info, payload = one ANSI string):  
`{eb02a8f2-bd77-434a-b5a5-875398ff4265}`  

GUID of the WPP control provider:  
`{76198e11-adb2-46d7-9845-2e9848310762}`  

It doesn't communicate with any other device.

### WDF configuration

Two WDF devices are created by `OnDeviceAdd` (0x409328):

1. The **HID device** (PnP, root-enumerated). Context `DEVICE_EXTENSION` (20 bytes):  
| Offset | Comment |
|--------|---------|
| 0x00 | VID (16 bits) |
| 0x02 | PID (16 bits) |
| 0x04 | WDFDEVICE of the HID device |
| 0x08 | WDFDEVICE of the control device |
| 0x0C | Default queue (parallel, `EvtIoInternalDeviceControl` = `OnInternalDeviceControl` 0x40379C) |
| 0x10 | Manual queue holding the pending `IOCTL_HID_READ_REPORT` requests |

   Its destroy callback `OnDestroy` (0x4027D0) deletes the control device.

2. The **control device** (`CreateControlObject` 0x402ADC, `WdfControlDeviceInitAllocate`). File object callbacks `OnDeviceFileCreate` (always `STATUS_SUCCESS`) and `OnFileClose` (removes all the services registered with this file object). One default parallel queue, not power-managed, with only `EvtIoDeviceControl` = `OnDeviceControl` (0x4038A4). Context `CONTROL_DEVICE_EXTENSION` (52 bytes):  
| Offset | Comment |
|--------|---------|
| 0x00 | WDFDEVICE of the control device |
| 0x04 | WDFDEVICE of the HID device |
| 0x08 | Default queue |
| 0x0C | KSPIN_LOCK of the service list |
| 0x14 | Service list (LIST_ENTRY) |
| 0x1C | KSPIN_LOCK of the input report list |
| 0x24 | Input report list (LIST_ENTRY): messages written by the services, waiting for an `IOCTL_HID_READ_REPORT` |
| 0x2C | Number of input reports in the list (max 64) |
| 0x30 | WDFWORKITEM `ProcessServiceMessageWorkItem` (0x403940) |

Pool allocations use the tag `HMBT` (0x54424D48), `NonPagedPoolNx`.

### Services

A service entry (44 bytes) is allocated by [IOCTL 0x222004](#ioctl-0x222004--register-service):  
| Offset | Comment |
|--------|---------|
| 0x00 | LIST_ENTRY in the service list |
| 0x08 | Service id (1 byte, ≠ 0, unique) |
| 0x09 | KEVENT object referenced from the handle given at registration (unaligned pointer) |
| 0x14 | KSPIN_LOCK of the message list |
| 0x1C | Message list (LIST_ENTRY): feature reports received for this service |
| 0x24 | Number of messages in the list (max 64) |
| 0x28 | Owner: WDFFILEOBJECT of the registration request |

Only the owner (same file handle) can read, write or remove the service. Closing the handle removes all its services; their pending messages are freed and the event is dereferenced.

### HID descriptors

HID descriptor (9 bytes, `.rdata:0x004062F0`): `09 21 01 00 00 01 22 78 00` (bcdHID 0x0001, 1 report descriptor of 120 bytes).

Report descriptor (120 bytes, `.rdata:0x00406300`): usage page 0xFFEE (vendor defined), 4 application collections (usages 1 to 4), 8-bit fields:  
| Report id | Type | Data size (bytes, after the report id) | Comment |
|-----------|------|----------------------------------------|---------|
| 0x01 | Feature | 64 | HID client → service (`IOCTL_HID_SET_FEATURE`) |
| 0x02 | Input | 64 | Service → HID client |
| 0x03 | Feature | 256 | HID client → service |
| 0x04 | Input | 256 | Service → HID client |
| 0x05 | Feature | 1024 | HID client → service |
| 0x06 | Input | 1024 | Service → HID client |
| 0x14 | Feature | 257 | List of the registered services (`IOCTL_HID_GET_FEATURE`) |
| 0x07 | Feature | 4096 | HID client → service |
| 0x08 | Input | 4096 | Service → HID client |

Strings (`IOCTL_HID_GET_STRING`): manufacturer (14) `Nokia`, product (15) `HidMessageBroker`, serial number (16) `1`.  
Attributes (`IOCTL_HID_GET_DEVICE_ATTRIBUTES`): VID and PID from the registry, version 1.

Format of the messages carried by the input and feature reports:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Report id |
| 01 | ? | Service id |
| 02-03 | ? | Length `n` of the data |
| 04-.. | ? | `n` bytes of data, the rest of the report is padded with 0 |

---

### IOCTL 0x222004 — Register service

This IOCTL is processed by HidMessageBroker_G1.sys (`RegisterService`, 0x4018D8) on the control device.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Register service | ≥ 9 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Service id (≠ 0) |
| 01-08 | ? | Handle of an event (64-bit field, unaligned; only the low 32 bits are used as the handle) |

The handle is referenced with `ObReferenceObjectByHandle(EVENT_MODIFY_STATE, ExEventObjectType, UserMode)`. The event is set (`KeSetEvent`) each time a feature report is queued for the service.  
Status:
- InputBuffer < 9 bytes → `STATUS_BUFFER_TOO_SMALL` (0xC0000023);
- service id 0 or handle 0, invalid handle, or service id already registered (by any file object) → `STATUS_INVALID_PARAMETER` (0xC000000D);
- allocation failure → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A).

> [!NOTE]
> When the service id is already registered, the reference taken on the event is never released.

---

### IOCTL 0x222008 — Remove service

This IOCTL is processed by HidMessageBroker_G1.sys (`RemoveService`, 0x401B58) on the control device.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Remove service | ≥ 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Service id |

Frees the service entry, its pending messages, and dereferences its event.  
InputBuffer empty → `STATUS_BUFFER_TOO_SMALL`. Unknown service, or service registered through another file handle → `STATUS_INVALID_PARAMETER`.

---

### IOCTL 0x22200C — Read message

This IOCTL is processed by HidMessageBroker_G1.sys (`ReadMessage`, 0x401CF8) on the control device.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Read the next message of a service | ≥ 1 | ≥ message length |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Service id |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-.. | ? | Data of the oldest feature report queued for the service (bytes 04-.. of the report, without the report id, service id and length) |

`BytesReturned` = length of the data.  
Status:
- InputBuffer empty → `STATUS_BUFFER_TOO_SMALL`;
- unknown service or not owned by the caller → `STATUS_INVALID_PARAMETER`;
- no message → `STATUS_NO_MORE_ENTRIES` (0x8000001A);
- OutputBuffer smaller than the message → `STATUS_BUFFER_TOO_SMALL`.

> [!NOTE]
> The message is removed from the queue before the size of the OutputBuffer is checked: with a too small OutputBuffer the message is lost.

---

### IOCTL 0x222010 — Write message

This IOCTL is processed by HidMessageBroker_G1.sys (`WriteMessage`, 0x401F6C) on the control device.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Send a message to the HID client | ≥ 3 + n | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Service id (must be registered by the caller) |
| 01-02 | ? | Length `n` of the data. `n + 4` must be ≤ 4097 |
| 03-.. | ? | `n` bytes of data |

The message is queued in the input report list of the control device and the work item `ProcessServiceMessageWorkItem` is enqueued. The report id is chosen from `n + 11`: ≤ 64 → 0x02, ≤ 256 → 0x04, ≤ 1024 → 0x06, else 0x08 (the thresholds are 8 bytes stricter than needed).  
The work item takes one pending `IOCTL_HID_READ_REPORT` from the manual queue, copies `[report id][service id][n][data]` (`n + 4` bytes) into its buffer and completes it with `Information` = full report size (65, 257, 1025 or 4097). If no read request is pending, the message stays in the list until the next `IOCTL_HID_READ_REPORT`.  
Status:
- InputBuffer < 3 bytes, or < `n + 3` → `STATUS_BUFFER_TOO_SMALL`;
- unknown service or not owned by the caller → `STATUS_INVALID_PARAMETER`;
- already 64 messages waiting → 0xC000020E (`STATUS_TOO_MANY_NODES` ?);
- `n + 4` > 4097 → `STATUS_BUFFER_OVERFLOW` (0x80000005);
- allocation failure → `STATUS_INSUFFICIENT_RESOURCES`.

Any other IoControlCode on the control device → `STATUS_NOT_SUPPORTED` (0xC00000BB).

---

### HID internal IOCTLs

The HID device processes the standard HID minidriver internal IOCTLs in `OnInternalDeviceControl` (0x40379C):  
| Code | Name | Handler | Comment |
|------|------|---------|---------|
| 0xB0003 | IOCTL_HID_GET_DEVICE_DESCRIPTOR | `DhGetHidDescriptor` 0x402F2C | Returns the 9-byte HID descriptor |
| 0xB0007 | IOCTL_HID_GET_REPORT_DESCRIPTOR | `DhGetReportDescriptor` 0x402FC0 | Returns the 120-byte report descriptor |
| 0xB000B | IOCTL_HID_READ_REPORT | `DhReadReport` 0x402DC0 | Forwarded to the manual queue; if input reports are waiting, enqueues the work item |
| 0xB000F | IOCTL_HID_WRITE_REPORT | `DhSetFeatureReport` 0x4032F8 | Handled like a set feature |
| 0xB0013 | IOCTL_HID_GET_STRING | `DhGetString` 0x402E80 | String ids 14, 15, 16 only, else `STATUS_INVALID_PARAMETER`. Too small buffer → `STATUS_BUFFER_TOO_SMALL` |
| 0xB0027 | IOCTL_HID_GET_DEVICE_ATTRIBUTES | `DhGetDeviceAttributes` 0x403058 | 32-byte `HID_DEVICE_ATTRIBUTES` |
| 0xB0053 | IOCTL_UMDF_HID_SET_FEATURE | `DhSetFeatureReport` 0x4032F8 | |
| 0xB0057 | IOCTL_UMDF_HID_GET_FEATURE | `DhGetFeatureReport` 0x403130 | |
| 0xB0191 | IOCTL_HID_SET_FEATURE | `DhSetFeatureReport` 0x4032F8 | |
| 0xB0192 | IOCTL_HID_GET_FEATURE | `DhGetFeatureReport` 0x403130 | |

`IOCTL_HID_SEND_IDLE_NOTIFICATION_REQUEST` (0xB002B) and any other code → `STATUS_NOT_SUPPORTED`.

#### Set feature

`DhSetFeatureReport` reads the `HID_XFER_PACKET` from `Irp->UserBuffer` (the request's OutputBufferLength must be ≥ 12, else `STATUS_BUFFER_TOO_SMALL`; no packet → `STATUS_INVALID_DEVICE_REQUEST` 0xC0000010).  
The report buffer must be ≥ 5 bytes and ≥ `n + 4` (else `STATUS_BUFFER_TOO_SMALL` / `STATUS_BUFFER_OVERFLOW`), and its report id must be 0x01, 0x03, 0x05 or 0x07 (else `STATUS_NOT_SUPPORTED`). The report (`n + 4` bytes) is then queued for the service of byte 01 and the service's event is set; the request completes with `STATUS_SUCCESS` even if the service doesn't exist or already has 64 messages (the report is then dropped).

#### Get feature

`DhGetFeatureReport` only supports report id 0x14 (else `STATUS_NOT_SUPPORTED`). The report buffer must be ≥ 258 bytes (else `STATUS_BUFFER_TOO_SMALL`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 14 | Report id |
| 01-02 | ? | Counter incremented at each get feature (1 to 0xFFFF, global `.data:0x004079A8`) |
| 03-.. | ? | Ids of the registered services, one byte each (max 255), followed by zeros |

`Information` = 258.
