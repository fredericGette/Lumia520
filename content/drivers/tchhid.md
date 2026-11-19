## TchHID.sys

Windows Phone touch class driver (Microsoft).  
It is a KMDF **upper filter** on HID touch-screen collections (`WdfFdoInitSetFilter`, not power policy owner). For each filtered collection it reads the HID input reports, gathers the contacts of a frame (a frame can be spread over several reports: the Contact Count of the first report gives the total), tracks each contact (down / move / up) and delivers the frame as a [touch report](#touch-report) to the reader of `\Device\TouchClass0` (the shell, see [UIXRender.dll](../libraries/uixrender.md)) and to the test readers of `\Device\TouchRaw0`. A third control device, `\Device\TouchUsages0`, describes the axes of the primary touch screen.  
On the Lumia 520 the filtered collection is the touch screen of [synapticstouch.sys](./synapticstouch.md) (Usage Page Digitizer, Usage Touch Screen). While the display is off (`GUID_MONITOR_POWER_ON`) the contacts are cancelled and no frame reaches `TouchClass0`.  
Build path `src\uxplat\input\dev\drivers\tchhid\tchhid.c` (build date `Jan 23 2015 18:16:17`), PDB `tchhid.pdb`. It imports `ntoskrnl.exe`, `HAL.dll` (`KeQueryPerformanceCounter`), `HIDPARSE.SYS` and `WDFLDR.SYS`.

Device name : `\Device\TouchClass0` (control device, exclusive: one handle at a time, no symbolic link)  
Security descriptor : `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GRGWGX;;;AU)(A;;GRGWGX;;;AC)`, and opening it requires the capability `ID_CAP_TOUCH` (see [Access check](#access-check))  

Device name : `\Device\TouchRaw0` (control device)  
Symbolic link : `\DosDevices\TouchRaw0`  
Security descriptor : same as `TouchClass0`, and opening it requires `ID_CAP_TOUCH_TEST`  

Device name : `\Device\TouchUsages0` (control device)  
Symbolic link : `\DosDevices\TouchUsages0`  
Security descriptor : same as `TouchClass0`. There's no file-create callback, so no capability check.  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\TOUCH\SAMPLINGPROPERTIES` (read once in `DriverEntry` by `TchReadRegistryConfig`, 0x10003BD0):  
| Registry value | value | comment |
|----------------|-------|---------|
| RepeatIntervalMSec | 50 | REG_DWORD (only used if the type is REG_DWORD and the size is 4), default 50. Period of the [auto-repeat timer](#auto-repeat). 0 disables the timer |

Registry key `HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\Tablet PC` (created if needed, written by `TchAddRemovePointerDeviceSystemMetricKey`, 0x10003C78):  
| Registry value | value | comment |
|----------------|-------|---------|
| IsTabletPC | e.g. 0x00000A00 | REG_DWORD = Contact Count Maximum of the touch screen `<< 8`. Read by [minuser.dll](../libraries/minuser.md) (`SM_MAXIMUMTOUCHES` = bits 8…23). Written by a work item (`TchUpdateRegistryWorkItem`, 0x10003D6C) queued on a read of `TouchClass0` when a device with a higher maximum than the last written value has started |

GUID of the ETW provider (manifest-based, `Microsoft_WindowsPhone_TchHID`, registered in `EvtDevicePrepareHardware`):  
`{d205e05a-9904-4b1c-b068-b5d8725639a3}`  

| Event id | Name | Written by |
|----------|------|------------|
| 1 | EvtIoRead | `TchHIDEvtIoRead` (read of `TouchClass0`) |
| 2 | CompletionRoutine | `TchFingerDataAvailable` (HID read completed) |
| 3 | HIDReadRequest | `TchGetFingerData` (HID read sent) |
| 4 | MonitorChange | `TchOnMonitorStateChange` |
| 5 | CompleteClassReadRequests | `TchCompleteClassReadRequests` (frame delivered) |

All events are level 4, keyword 0x4.

GUID of the WPP control provider (`TouchClassTraceGuid`; flags INIT, REGISTRY, HID, PNP, POWER, REPORTING, TEST, SAMPLES, OTHER):  
`{745f7bdc-b9a4-4999-8ac7-4bd73766ac29}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Local I/O target (HID collection PDO below the filter) | HID class (`hidclass.sys`), on the Lumia 520 over [synapticstouch.sys](./synapticstouch.md) | [IOCTL 0xB01A8](#ioctl-0xb01a8--ioctl_hid_get_collection_information), [IOCTL 0xB0193](#ioctl-0xb0193--ioctl_hid_get_collection_descriptor), [IOCTL 0xB01BE](#ioctl-0xb01be--ioctl_hid_get_product_string) |
| HID collection opened by name (`GUID_DEVINTERFACE_HID` `{4D1E55B2-F16F-11CF-88CB-001111000030}` of its own PDO) | HID class | [IOCTL 0xB0192](#ioctl-0xb0192--ioctl_hid_get_feature), continuous `IRP_MJ_READ` of the input reports |

Pool tag: `iHcT` (0x54634869, `NonPagedPoolNx`). The capability check uses the tag `Secr` (0x72636553).

### Initialisation

`DriverEntry` (0x10007000; Hex-Rays fails on it, read it from the disassembly):
1. WPP registration, `WdfDriverCreate` (context `DRIVER_CONTEXT`, `EvtDriverDeviceAdd` = `TchHIDEvtDeviceAdd`, pool tag `iHcT`), spin lock, `TchReadRegistryConfig`.
2. Control device `\Device\TouchClass0` (`WdfControlDeviceInitAllocate` with the SDDL above, `WdfDeviceInitSetExclusive(TRUE)`, file-create callback `TchHIDFileCreate` 0x10003FDC), default parallel queue with `EvtIoRead` = `TchHIDEvtIoRead` (0x100042EC).
3. Work items `TchBoostCpuWorkItem` (0x10005F38: `PoLatencySensitivityHint(2)`) and `TchUpdateRegistryWorkItem`; the timer `TchAutoRepeatTimerFunc` (0x10005F50) if `RepeatIntervalMSec` ≠ 0.
4. `PoRegisterPowerSettingCallback(GUID_MONITOR_POWER_ON {02731015-4510-4526-99e6-e5a17ebd1aea})`, callback `TchOnMonitorStateChange` (0x10002744), then `WdfControlFinishInitializing`.
5. The device collection, the report buffer of `TouchClass0` (`TchBufferInitializeReaderContext`: a manual queue + a list of pending reports), `TchBroadcastRawSamplesInit` (0x1000537C, `\Device\TouchRaw0`) and `TchDeviceUsageInit` (0x100058E0, `\Device\TouchUsages0`).

`TchHIDEvtDeviceAdd` (0x10004020): no limit on the number of devices. Filter device (context `DEVICE_CONTEXT`, 0x850 bytes) with `EvtDevicePrepareHardware` / `ReleaseHardware` / `D0Entry` / `D0Exit`. The device index (byte, context `+0x14`) goes in the [touch report](#touch-report) header. Registers for the arrival of `GUID_DEVINTERFACE_HID` on its own PDO (`IoRegisterPlugPlayNotification`, callback `HidDeviceStartReadLoopOnReady` 0x10002A64: `IoGetDeviceInterfaces`, `WdfIoTargetOpen` read/write, [Contact Count Maximum](#ioctl-0xb0192--ioctl_hid_get_feature), then the first read), creates and enables the device interface `GUID_WP_DEVINTERFACE_TCH` `{2C05CE1A-75E8-4EA7-A70A-E323B072258C}` (the interface [UIXRender.dll](../libraries/uixrender.md) waits for before opening `\Device\TouchClass0`).

`TchHIDPrepareHardware` (0x100043A0; read it from the disassembly):
1. [IOCTL 0xB01A8](#ioctl-0xb01a8--ioctl_hid_get_collection_information) and [IOCTL 0xB0193](#ioctl-0xb0193--ioctl_hid_get_collection_descriptor) to the local I/O target, then `HidP_GetCaps`.
2. The top-level collection must be Usage Page 0x0D (Digitizer), **Usage 0x04 (Touch Screen)**, otherwise `STATUS_UNSUCCESSFUL`.
3. Walks the link collections (`HidP_GetLinkCollectionNodes`) and keeps, for each, the input value / button caps it finds: Contact Count (0x0D/0x54), Scan Time (0x0D/0x56), and the finger collections that have Contact Identifier (0x0D/0x51), Tip Switch (0x0D/0x42 button) and X (0x01/0x30). Optional: Confidence (0x0D/0x47 button), Z (0x01/0x32), Width / Height (0x0D/0x48, 0x49), X / Y Tilt (0x0D/0x3D, 0x3E). The axes are stored in the [usage description](#usage-description) (device context `+0x780`). X and Y are taken from the first finger collection with a valid logical range (min ≥ 0 and max > min); a different range in another finger collection is only traced.
4. Creates the HID read request and its buffer (input report length).
5. [IOCTL 0xB01BE](#ioctl-0xb01be--ioctl_hid_get_product_string): if the product string is **not** `VHidPen`, the device is the **primary** touch screen (device context `+0x13`). `TouchUsages0` and [IOCTL 0xB02C0](#ioctl-0xb02c0--ignore-the-primary-touch-screen) only concern the primary device.

### Report processing

`TchFingerDataAvailable` (0x10003A70, completion routine of the HID read):
1. Drops the report if [IOCTL 0xB02C0](#ioctl-0xb02c0--ignore-the-primary-touch-screen) is set and the device is primary.
2. If the previous frame ended (all contacts up), queues `TchBoostCpuWorkItem` (`PoLatencySensitivityHint(2)`).
3. `TchAddFingerData` (0x100037F8): reads the Contact Count of the first report of a frame (0 → error 0xC000090B), then, for each finger collection of the report, `TchGetFingerUsageValues` (Contact Identifier, X, Y, Z, Width, Height, Tilt; each value is checked against its logical range, otherwise 0xC000090B) and `TchGetFingerUsageFlags` (contact state, flags below). When all the contacts of the frame are read, `TchReportAllFingers` (0x10002ED0) builds the touch report and delivers it.
4. On an error all the contacts are cancelled (`TchInvalidateAllFingers`, 0x10002E00).
5. `TchAutoRepeatHandler` starts or stops the [auto-repeat timer](#auto-repeat), and the next HID read is sent (`TchGetFingerData`, 0x1000526C).

`TchCompleteClassReadRequests` (0x10002D7C) delivers a frame:
- to the readers of `TouchRaw0` (only while at least one handle is open);
- to the reader of `TouchClass0`, unless the device is not in D0 or the display is off (device context `+0x1C`), or [IOCTL 0xB02BC](#ioctl-0xb02bc--suppress-touchclass0-delivery) is set. Only after the first read of `TouchClass0`. When the device is in D0 and the display is on, the frame is also kept as the last delivered frame (used to cancel the contacts).

If no read is pending the frame is copied in a list, without limit, and returned by the next read (`TchBufferOnReadRequest`, 0x10002354). Every read returns **one frame**: the read buffer must be ≥ 72 bytes (otherwise `STATUS_INVALID_PARAMETER`) and ≥ the frame size. On the last close of `TouchRaw0` the pending frames are dropped.

Display off (`TchOnMonitorStateChange`, value 0 for `GUID_MONITOR_POWER_ON`): the auto-repeat timer is stopped and, on every device in D0, the contacts are cancelled and the device stops delivering to `TouchClass0` until the display is back on. `EvtDeviceD0Exit` also cancels the contacts.

### Touch report

Size = 72 bytes for 1 contact, + 52 bytes per additional contact, at most **10** contacts (with 0 or more than 10 contacts the size field is 0). [UIXRender.dll](../libraries/uixrender.md) reads it with a 0xA8C-byte buffer.

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 48 00 | Size of the report |
| 02-03 | 00 00 | |
| 04-07 | ? | Timestamp in ms (`KeQueryPerformanceCounter` × 1000 / frequency). A frame of cancelled contacts uses the timestamp of the last frame + 1 |
| 08-0B | 00 00 00 EF | `0xEF000000` \| device index |
| 0C-0F | 00 00 00 00 | |
| 10-12 | ? | |
| 13 | 01 | Number of contacts |
| 14-47 | | Contact 0 (52 bytes, below) |
| 48-… | | Contacts 1…9 |

Contact (52 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Contact number assigned by the driver (increments for each new contact, reset when all contacts are up), not the HID Contact Identifier |
| 02-03 | ? | Flags, below |
| 04-05 | ? | X (logical value of the HID report) |
| 06-07 | ? | Y |
| 08-0B | ? | |
| 0C-0D | ? | Width (0 if not supported) |
| 0E-0F | ? | Height |
| 10-11 | ? | Z |
| 12-13 | ? | |
| 14-15 | ? | X Tilt |
| 16-17 | ? | Y Tilt |
| 18-33 | ? | |

Flags (`TchGetFingerUsageFlags`, 0x100034E0, from the contact state of the previous frames: new, hovering, touching):  
| Bit | Meaning |
|-----|---------|
| 0x0001 | Tip Switch, contact new or was hovering (down) |
| 0x0002 | Tip Switch, contact was already touching (move) |
| 0x0004 | Contact was touching and is now only In Range, or no longer reported (up) |
| 0x0008 | Tip Switch or In Range (0x0D/0x32) set |
| 0x1000 | Last frame of the gesture: no contact of the frame has 0x0008. Also set by the cancellation |
| 0x2000 | The device reports Confidence (0x0D/0x47) and it isn't set in this contact. Also set by the cancellation (0x3000, or 0x3004 for a contact that was down / moving) |
| 0x4000 | Digitizer usage 0xFF set ? |
| 0x8000 | Digitizer usage 0xFE set ? |

A contact that is neither touching nor in range, and was only hovering, gets bits 0…3 cleared. A contact that is not in range and wasn't known → error.

### Auto-repeat

When a frame has a contact with flag 0x0008 and the display is on, the timer (`RepeatIntervalMSec`) is started. Each expiry (`TchAutoRepeatTimerFunc`), for each device whose last frame is older than the interval, the frame is sent again with a new timestamp: the contacts without 0x0008 are removed and flag 0x0001 (down) becomes 0x0002 (move). The timer stops when no contact has 0x0008.

### Usage description

Device context `+0x780`, 0xD0 bytes, built by `TchHIDPrepareHardware`:

| Bytes | Comment |
|-------|---------|
| 00-03 | Size, 0xD0 |
| 04-07 | Optional axes: bit 0 = Z, bit 1 = Width / Height, bit 2 = X / Y Tilt |
| 08 | Contact Count Maximum ([IOCTL 0xB0192](#ioctl-0xb0192--ioctl_hid_get_feature)) |
| 09 | Byte 2 of the same feature report (read only if Z is supported, must then be ≠ 0) ? |
| 0C-27 | X |
| 28-43 | Y |
| 44-5F | Z |
| 60-7B | Width |
| 7C-97 | Height |
| 98-B3 | X Tilt |
| B4-CF | Y Tilt |

Axis entry (28 bytes, from `HIDP_VALUE_CAPS`):  
| Bytes | Comment |
|-------|---------|
| 00-03 | LogicalMin |
| 04-07 | LogicalMax |
| 08-0B | PhysicalMin |
| 0C-0F | PhysicalMax |
| 10-13 | Units |
| 14-17 | UnitsExp |
| 18-19 | Usage Page (0x01 or 0x0D) |
| 1A-1B | Usage |

On the Lumia 520 ([synapticstouch.sys](./synapticstouch.md)) only X and Y exist: X 0…4095 (physical 0…1205), Y 0…4095 (physical 0…906), unit 0x33, exponent -2.

### Access check

`CapabilityCheck` (0x10008328) is the kernel copy of the SecRuntime check (see [SecRuntime.dll](../libraries/secruntime.md#capabilitycheck-0x10002d30)): it takes the effective token of the caller, reads `ApplicationCapabilitySID` or `ServiceCapabilitySID` of `HKLM\Software\Microsoft\SecurityManager\Capabilities\<capability>` and calls `RtlCheckTokenCapability`; SYSTEM (`IsSystem`) and the holders of `ID_CAP_BUILTIN_TCB` pass. A caller without the capability gets `STATUS_ACCESS_DENIED` (0xC0000022) on `IRP_MJ_CREATE`.

| Device | Capability |
|--------|------------|
| `\Device\TouchClass0` | `ID_CAP_TOUCH` |
| `\Device\TouchRaw0` | `ID_CAP_TOUCH_TEST` |
| `\Device\TouchUsages0` | none |

---

### IOCTL 0xB02BC — Suppress TouchClass0 delivery

This IOCTL is processed by TchHID.sys (`\Device\TouchRaw0`, `TchBroadcastRawSamplesOnListenerIOCTL` 0x10005760)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0xAF (175) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Suppress TouchClass0 delivery ? | 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Stored in the driver context `+0xA`. Non-zero: the frames only go to `TouchRaw0`, no longer to `TouchClass0` |

Same code and behaviour as [IOCTL 0xB02BC of kbdclasswp.sys](./kbdclasswp.md#ioctl-0xb02bc--suppress-wpkeyboardclass-delivery). Other sizes (or an output buffer) → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). Any other IOCTL code on `TouchRaw0` → `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0xB02C0 — Ignore the primary touch screen

This IOCTL is processed by TchHID.sys (`\Device\TouchRaw0`, `TchBroadcastRawSamplesOnListenerIOCTL` 0x10005760)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0xB0 (176) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Ignore the primary touch screen ? | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Non-zero → driver context `+0xB` = 1: the HID reports of the primary device (product string ≠ `VHidPen`) are dropped, and its current contacts are cancelled. 0 → reports processed again |

Other sizes → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### IOCTL 0x220004 — Get usage count

This IOCTL is processed by TchHID.sys (`\Device\TouchUsages0`, `TchHIDGetPrimaryDeviceUsageCount` 0x10005B80)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get usage count | 0 | ≥ 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | Number of axes of the primary touch screen: 2 (X, Y) + 1 if Z + 2 if Tilt + 2 if Width / Height. Lumia 520: 2 |

No primary device → `STATUS_UNSUCCESSFUL`. Any other IOCTL code on `TouchUsages0` → `STATUS_NOT_SUPPORTED` (0xC00000BB).

---

### IOCTL 0x220008 — Get usages

This IOCTL is processed by TchHID.sys (`\Device\TouchUsages0`, `TchHIDGetPrimaryDeviceUsages` 0x10005C6C)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x2 (2) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get usages | 0 | ≥ 28 × usage count |

Outputbuffer: one 28-byte [axis entry](#usage-description) per axis, in this order: X, Y, [Z], [X Tilt, Y Tilt], [Width, Height].

---

### IOCTL 0x22000C — Get maximum contacts

This IOCTL is processed by TchHID.sys (`\Device\TouchUsages0`, `TchHIDGetPrimaryDeviceMaxInputs` 0x10005DE0)

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x3 (3) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get maximum contacts | 0 | ≥ 2 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 0A | Contact Count Maximum of the primary touch screen (Lumia 520: 10, see [synapticstouch.sys](./synapticstouch.md#internal-ioctl-0xb0192--ioctl_hid_get_feature)) |
| 01 | 00 | Byte `+0x789` of the device context (second byte of the feature report, see [Usage description](#usage-description)) |

---

### IOCTL 0xB01A8 — IOCTL_HID_GET_COLLECTION_INFORMATION

This IOCTL is sent by TchHID.sys to the HID class driver (local I/O target), in `EvtDevicePrepareHardware`.

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x6A (106) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_HID_GET_COLLECTION_INFORMATION | HID collection PDO | 0 | 12 |

Outputbuffer (`HID_COLLECTION_INFORMATION`): only `DescriptorSize` (bytes 00-03) is used, as the size of the preparsed data.

---

### IOCTL 0xB0193 — IOCTL_HID_GET_COLLECTION_DESCRIPTOR

This IOCTL is sent by TchHID.sys to the HID class driver (local I/O target), in `EvtDevicePrepareHardware`.

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_HID_GET_COLLECTION_DESCRIPTOR | HID collection PDO | 0 | `DescriptorSize` |

Returns the preparsed data, used with the `HidP_*` functions.

---

### IOCTL 0xB01BE — IOCTL_HID_GET_PRODUCT_STRING

This IOCTL is sent by TchHID.sys to the HID class driver (local I/O target), at the end of `EvtDevicePrepareHardware`.

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x6F (111) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_OUT_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_HID_GET_PRODUCT_STRING | HID collection PDO | 0 | 514 |

The string is compared with `VHidPen` (`wcscmp`): any other product (Lumia 520: `3200`, see [synapticstouch.sys](./synapticstouch.md#internal-ioctl-0xb0013--ioctl_hid_get_string)) makes the device primary.

---

### IOCTL 0xB0192 — IOCTL_HID_GET_FEATURE

This IOCTL is sent by TchHID.sys to the HID collection (I/O target opened through `GUID_DEVINTERFACE_HID`), in `HidDeviceReadMaxContacts` (0x1000293C).

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_OUT_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_HID_GET_FEATURE | HID collection | 0 | 8 |

The report is the one of the feature value cap Contact Count Maximum (0x0D/0x55).

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 08 | Report ID (set by the driver before the call; Lumia 520: 8) |
| 01 | 0A | Contact Count Maximum → usage description `+0x08` |
| 02 | ? | → usage description `+0x09`, only if Z is supported; 0 is then an error |
| 03-07 | ? | |

---

### Interface GUID

Touch device interface, created and enabled for each filtered collection  
`GUID_WP_DEVINTERFACE_TCH` `{2C05CE1A-75E8-4EA7-A70A-E323B072258C}`

### Other GUID

HID device interface (arrival notification, `IoGetDeviceInterfaces`)  
`GUID_DEVINTERFACE_HID` `{4D1E55B2-F16F-11CF-88CB-001111000030}`

Display state (power setting)  
`GUID_MONITOR_POWER_ON` `{02731015-4510-4526-99e6-e5a17ebd1aea}`
