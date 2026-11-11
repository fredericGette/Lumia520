## Usbfnclx.sys

USB function class extension (`UsbFnClx`, Microsoft, WP8.1).  
It is a KMDF class library (`WdfRegisterClassLibrary`, control device `\Device\UsbFn`) loaded in the stack of the USB function controller `ACPI\QCOM01C0\1` (`\_SB.UFN1`). The controller driver [usbfnchipidea.sys](./usbfnchipidea.md) binds to it with `WdfVersionBindClass` and gets its [6 exported functions](#exported-functions). UsbFnClx is the hardware-independent part of the USB device stack: it reads the USB configuration from the registry (`HKLM\SYSTEM\CurrentControlSet\Control\USBFN`), builds the device/configuration/string/MS OS descriptors, answers the standard requests on EP0, owns the USB device state machine, enumerates one child PDO `USBFN\<interface>` per interface of the active configuration (function drivers [genericusbfnclass.sys](./genericusbfnclass.md), [ufnserialclass.sys](./ufnserialclass.md), [ufnvidstream.sys](./ufnvidstream.md), …), dispatches bus events to them, and forwards their transfers to the endpoint queues of the controller driver.  
It also tells the charging arbitration driver how much current can be drawn ([IOCTL 0x29C4C0](#ioctl-0x29c4c0--charging-notification)), drives the low-power filter [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md) and sets the P-state of the controller through the PEP.  
PDB: `usbfnclx.pdb`. Pool tags `Uclx`, `UBus`. Full symbols (function names below are those of the binary).

Device name : `\Device\UsbFn` (control device of the class library, SDDL `D:P`, kernel only)  
The controller FDO has an auto-generated name, device type 0x2A, SDDL `D:P(A;;GA;;;SY)` (SYSTEM only), and registers the device interface [`{cec7d47f-a1e1-4607-a693-9a0061465db7}`](#interface-guid).  

GUID of the ETW provider (manifest `Microsoft-WindowsPhone-UsbFnClx`, `EtwRegister`):  
`{dd4ac270-4867-49a1-b6cc-fa2e39325865}`  

GUID of the WPP provider:  
`{ca9b0dbf-ca95-4a2c-91b6-7e0c1b9b024b}`  

### Registry

Key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\USBFN` (opened with `WdfRegistryOpenKey`, `KEY_ALL_ACCESS`):  
| Registry value | value | comment |
|----------------|-------|---------|
| CurrentConfiguration | e.g. `Default` | REG_SZ, name of the subkey of `Configurations` loaded at start. Missing → `Default`. Rewritten by [IOCTL 0x2AC409](#ioctl-0x2ac409--set-active-configuration) when its persist flag is set |
| IncludeDefaultCfg | 0/1 | DWORD. 1 = the parameters of `Configurations\DEFAULT` are loaded first and the selected configuration overrides them (MS OS compat-ID descriptors are merged) |
| bDeviceClass, bDeviceSubClass, bDeviceProtocol | | Device descriptor. Read first from the subkey `DEFAULT`, then from the key itself (overrides) |
| idVendor, idProduct | | Device descriptor, required |
| iManufacturer, ManufacturerString | | String index (required) and REG_SZ |
| iProduct, ProductString | | String index (required) and REG_SZ |
| iSerialNumber | | String index (required). The serial number string is the SMBIOS system UUID (type 1, `ZwQuerySystemInformation(SystemFirmwareTableInformation, 'RSMB')`) as 32 hex digits |

Subkey `Configurations\<name>` (12 configurations max, name ≤ 39 characters):  
| Registry value | value | comment |
|----------------|-------|---------|
| bmAttributes | 0x80 | Configuration descriptor (default 0x80) |
| bMaxPower | 50 | Configuration descriptor, units of 2 mA (default 50 = 100 mA). Reported to the charger when configured |
| InterfaceList | | REG_MULTI_SZ, names of the subkeys of `Interfaces` used by this configuration, in interface order |
| MSOSCompatIdDescriptor | | REG_BINARY, MS OS extended compat ID descriptor (version 0x0100, index 4) |

Subkey `Interfaces\<name>`:  
| Registry value | value | comment |
|----------------|-------|---------|
| InterfaceDescriptor | | REG_BINARY, interface descriptor followed by its endpoint descriptors. Interface numbers and endpoint addresses are renumbered by UsbFnClx. 15 endpoints max for the whole configuration; bulk ≤ 64 (full speed) / 512 (high speed), interrupt ≤ 64 / 1024; no isochronous |
| InterfaceGuid | `{…}` | REG_SZ, optional. Returned in `USBFN_CLASS_INFORMATION_PACKET` (device interface of the function driver, e.g. [genericusbfnclass.sys](./genericusbfnclass.md#interface-guid)) |
| MSOSExtendedPropertyDescriptor | | REG_BINARY, optional, MS OS extended property descriptor (version 0x0100, index 5) |

Device key of the controller (`WdfDeviceOpenRegistryKey`, `PLUGPLAY_REGKEY_DEVICE`):  
| Registry value | value | comment |
|----------------|-------|---------|
| SoftwareOnlyDriver | 0 | DWORD. ≠ 0: no P-state requests to the PEP and S0 idle disabled |

The child PDOs are `USBFN\<interface name>` (DeviceID = HardwareID), InstanceID = interface number `%02d` (e.g. `USBFN\MTP\3&1d123fc3&0&00`, `USBFN\IpOverUsb\3&1d123fc3&0&01`), device text = interface name (0x409). Bus type GUID `GUID_DEVCLASS_USBFNBUS` `{17f99fe7-5ebe-49fe-a348-05be51fe7f08}`.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Controller driver (same FDO, function table given at registration) | [usbfnchipidea.sys](./usbfnchipidea.md) | [Client callbacks](#client-callbacks); transfers are forwarded (`WdfRequestForwardToIoQueue`) to its endpoint queues |
| Lower device of the controller stack (`WdfDeviceGetIoTarget`) | [qcusbfnfilter8930.sys](./qcusbfnfilter8930.md) | [internal IOCTL 0x2AC03A](#internal-ioctl-0x2ac03a--ioctl_internal_usbfn_set_power_filter_state), [internal IOCTL 0x2AC03E](#internal-ioctl-0x2ac03e--exit-low-power-mode) |
| Interface `{ec0a1cc9-4294-43fb-bf37-b850ce95f337}` (`GUID_DEVINTERFACE_CHARGING_ARBITRATION`, `IoRegisterPlugPlayNotification`) | ? (charging arbitration driver) | [IOCTL 0x29C4C0](#ioctl-0x29c4c0--charging-notification) |
| Power framework (`PoFxPowerControl`) | [qcpep8930.sys](./qcpep8930.md) | `{3404daac-8e2c-41e4-8458-3158e5ad442b}` set P-state, see [Power management](#power-management) |
| Interface `{a437e7be-7175-4d69-9d30-f82efd144b5a}` (`GUID_DEVINTERFACE_USBFNTEST_POWER_TEST`) | test driver ? | Query interface `{688e49d4-1563-446b-838b-11287a4d0445}` (`GUID_USBFN_INTERFACE_POWER_TEST`, 20 bytes) |

### Exported functions

Table `UsbFnClxExports` (`.text:0x10001080`, 6 entries, copied by `UsbFnClxClassLibraryBindClient`, which requires a count of 6). It is the "UsbFnClx interface" seen by [usbfnchipidea.sys](./usbfnchipidea.md#usbfnclx-interface):  
| Entry | Function | Comment |
|-------|----------|---------|
| 0 | `UsbFnClxRegisterClient(WDFDRIVER, config)` | Validates the 80-byte [registration packet](#client-callbacks) (`Version` 0x10, `Size` 80, entries 0x08-0x48 non-NULL) and keeps a copy. Only one client |
| 1 | `UsbFnClxUnRegisterClient` | Frees the copy |
| 2 | `UsbFnClxProcessAddDevicePreDeviceCreate` | Device type 0x2A, PnP/power callbacks of UsbFnClx, context `USBFN_CLX_DEVICE_DATA` (768 bytes + client context, min 896), SDDL, file object callbacks |
| 3 | `UsbFnClxProcessAddDevicePostDeviceCreate` | Device queue, CAD notification, registry, loads the current configuration, creates the child PDOs, 5 preallocated EP0 requests/buffers, device interface `{cec7d47f-…}` |
| 4 | `UsbFnClxNotificationCallback(WDFDEVICE, event)` | Bus events from the controller, see [Bus events](#bus-events) |
| 5 | `UsbFnClxGetClientContext(WDFDEVICE)` | Returns the client context (offset 768 of the device context) |

### Client callbacks

Offsets in the registration packet of the controller driver and their use by UsbFnClx (implementations: [usbfnchipidea.sys](./usbfnchipidea.md#usbfnclx-interface)):  
| Offset | Called from | Use |
|--------|-------------|-----|
| 0x08 / 0x0C | `EvtDevicePrepareHardware` / `EvtDeviceReleaseHardware` | Prepare / release hardware |
| 0x10 | [internal IOCTL 0x2AC02C](#internal-ioctl-0x2ac02c--ioctl_internal_usbfn_activate_usb_bus), when the last child activates the bus | Start the controller (attach) |
| 0x14 | [internal IOCTL 0x2AC030](#internal-ioctl-0x2ac030--ioctl_internal_usbfn_deactivate_usb_bus), configuration unload | Stop the controller |
| 0x18 | not called | (`WdfInterruptReportActive` in usbfnchipidea.sys) |
| 0x1C | `UsbFnPowerFilterSetState`, before internal IOCTL 0x2AC03A | (`WdfInterruptReportInactive`) |
| 0x20 | `UsbFnBusConnectToClient` | Check the full-speed and high-speed descriptor sets |
| 0x24 / 0x28 | `UsbFnBusCreateEndpoints` / `UsbFnBusDestroyLists` | Endpoint add (returns the `WDFQUEUE` of the pipe) / remove |
| 0x2C / 0x30 / 0x34 | Enable/disable pipes (reset, `SET_CONFIGURATION`, detach, suspend) | Endpoint enable / disable / configure |
| 0x38 | `SET_ADDRESS`, before the status stage | Set address |
| 0x3C | `SetAddressHandshakeCompletionRoutine` | Address committed (status stage done) |
| 0x40 / 0x44 | Stall requests, `SET/CLEAR_FEATURE(ENDPOINT_HALT)`, `GET_STATUS`, unsupported setup packet (stall EP0) | Set/clear stall, get stall |
| 0x48 | `SetTestModeHandshakeCompletionRoutine` | Test mode (selector from `SET_FEATURE(TEST_MODE)`) |
| 0x4C | [internal IOCTL 0x2AC108](#internal-ioctl-0x2ac108--test-hook) | Optional test hook |

### State machine

Device state (context +0x04, `USBFN_DEVICE_STATE`): 1 Attached, 2 Default, 3 Detached, 4 Addressed, 5 Configured, 6 Suspended.  
Port type (+0x0C, `USBFN_PORT_TYPE` from the controller): 0 unknown, 1 SDP, 2 CDP, 3 DCP, 4 invalid DCP. Bus speed (+0x10): 1 full, 2 high.

### Bus events

`UsbFnClxNotificationCallback` receives `{event, data}` from the controller: 1 Attach, 2 Reset (+speed), 3 Detach, 4 Suspend, 5 Resume, 6 SetupPacket (+8 bytes), 9 PortType. Other values → `STATUS_INVALID_PARAMETER`.  
- Standard setup packets, and vendor requests `bRequest` 0x42 (`MSFT100` vendor code) with `wIndex` 4/5 (MS OS compat ID / extended property), are answered by UsbFnClx on EP0 using its preallocated requests and the controller's EP0 queue (internal IOCTLs 0x2AC00D/0x2AC011, 0x2AC018/0x2AC01C). Unsupported standard requests stall EP0. Other class/vendor setup packets are queued to the child whose interface number is the low byte of `wIndex` (or EP0 is stalled).
- Events 1-5 are queued to every child; UsbFnClx also generates 7 Configured (+configuration value) / 8 Unconfigured on `SET_CONFIGURATION`, 3 Detach on bus deactivation and 10 BusTearDown when a configuration is unloaded.
- Attach and Resume call `WdfDeviceStopIdle`; Detach and Suspend (unless DCP/invalid DCP), and PortType DCP/invalid DCP call `WdfDeviceResumeIdle`.

Charger current reported with [IOCTL 0x29C4C0](#ioctl-0x29c4c0--charging-notification): Detach → 0 mA, not connected; Attach, Reset, Suspend, `SET_CONFIGURATION(0)` → 0 mA (unless CDP); `SET_CONFIGURATION(n)` and Resume to Configured → 2 × `bMaxPower` mA, port type forced to SDP (unless CDP); PortType CDP or DCP → 1500 mA, invalid DCP → 500 mA. Non-zero values below 500 are raised to 500.

### Power management

- `EvtDeviceD0Entry`: first time `UsbFnPowerInitialize` (PoFx registration through `WdfDeviceWdmAssignPowerFrameworkSettings`, S0 idle settings, test interface notification, one preallocated request), then P-state 0, then [internal IOCTL 0x2AC03E](#internal-ioctl-0x2ac03e--exit-low-power-mode). Failures are only traced.
- `EvtDeviceArmWakeFromS0`: [internal IOCTL 0x2AC03A](#internal-ioctl-0x2ac03a--ioctl_internal_usbfn_set_power_filter_state) with the device state, then P-state from the state.
- S0 idle (`WdfDeviceAssignS0IdleSettings`): `IdleCanWakeFromS0`, D3, 100 ms; with `SoftwareOnlyDriver` ≠ 0: `IdleCannotWakeFromS0`, idle disabled.

P-state (`PoFxPowerControl(handle, {3404daac-…}, {component 0, P-state}, 8, output, 12)`). Output `00-03` = 3 → done; 1 → waits up to 2 s for `PowerControlCallback`, else `STATUS_IO_TIMEOUT`:  
| Device state | Port type | P-state |
|--------------|-----------|---------|
| Attached | SDP / CDP / DCP / invalid DCP | 0 / 1 / 2 / 3 |
| Suspended | | 4 |
| Detached | | 5 |
| D0 entry, other states | | 0 |

---

### IOCTL 0x2AC402 — Enumerate configuration

This IOCTL is processed by Usbfnclx.sys (controller FDO, `UsbFnClxEvtDeviceIoControl`, interface `{cec7d47f-…}`).

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x100 (256) |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Enumerate configuration | ≥ 4 | ≥ 82 |

Inputbuffer: `00-03` index of the configuration. Index ≥ count → `STATUS_NO_MORE_ENTRIES` (0x8000001A).  
Outputbuffer (configuration entry, 82 bytes, Information = 82):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-4F | | Name, WCHAR[40] (subkey of `Configurations`) |
| 50 | 00/01 | 1 = it is `CurrentConfiguration` in the registry |
| 51 | 00/01 | 1 = loaded (active) |

---

### IOCTL 0x2AC406 — Get active configuration

Processed by Usbfnclx.sys (`UsbFnClxEvtDeviceIoControl`). Device 0x2A, Function 0x101, READ_AND_WRITE, METHOD_OUT_DIRECT. No input, output ≥ 82 bytes: the configuration entry of `CurrentConfiguration` (registry index, not necessarily the loaded one ?).

---

### IOCTL 0x2AC409 — Set active configuration

Processed by Usbfnclx.sys (`UsbFnClxEvtDeviceIoControl`). Device 0x2A, Function 0x102, READ_AND_WRITE, METHOD_IN_DIRECT.  
Input ≥ 82 bytes: configuration entry; name compared case-insensitively (40 characters), unknown → `STATUS_INVALID_PARAMETER`; byte `50` ≠ 0 → also written as `CurrentConfiguration`. Already loaded → success, nothing done. Otherwise the old configuration is torn down (BusTearDown event, controller stopped, PDOs removed, pipes destroyed), the new descriptors are built, new PDOs are enumerated and the endpoints are created in the controller.

Any other IOCTL → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### Internal IOCTLs on the child PDOs

Function drivers send these to their `USBFN\<interface>` PDO (`UsbFnBusPdoEvtDeviceIoControl`, parallel queue). Codes from `usbfnioctl.h`, see [genericusbfnclass.sys](./genericusbfnclass.md#ioctl-forwarding). InputBuffer `00-03` = `USBFNPIPEID` where needed: index in the pipe table (0 = EP0, then the endpoints of the configuration in descriptor order, max 16 entries). A non-zero pipe of another interface → `STATUS_INVALID_PARAMETER`.  
| Code | Name | Handling |
|------|------|----------|
| 0x2AC00D, 0x2AC011, 0x2AC016 | TRANSFER_IN, TRANSFER_IN_APPEND_ZERO_PKT, TRANSFER_OUT | PipeId ≤ 16 checked, forwarded to the controller FDO (below) |
| 0x2AC018, 0x2AC01C | CONTROL_STATUS_HANDSHAKE_IN/OUT | Forwarded to the controller FDO |
| 0x2AC022 | GET_CLASS_INFO | Output ≥ 552: `USBFN_CLASS_INFORMATION_PACKET` without the super-speed part (full-speed and high-speed interfaces, PipeArr[0] = EP0 with PipeId 0, interface name, `InterfaceGuid`, `HasInterfaceGuid`). Completed with Information 0 |
| 0x2AC026 | GET_PIPE_STATE | Input PipeId, output 1 byte: stalled. Pipe not enabled → `STATUS_PIPE_NOT_AVAILABLE`? (0xC00000AC) |
| 0x2AC029 | SET_PIPE_STATE | Input PipeId, data 1 byte: stall/clear through client callback 0x40 (the cached stall flag isn't updated ?) |
| 0x2AC02C | ACTIVATE_USB_BUS | Marks the child active; when all children are active, calls client 0x10 (controller start) |
| 0x2AC030 | DEACTIVATE_USB_BUS | Marks the child inactive; if all were active, calls client 0x14 and sends Detach to the active children |
| 0x2AC036 | BUS_EVENT_NOTIFICATION | Output 12 bytes `{event, data[8]}`. Completed at once if an event is queued, else sent (input = interface number) to the controller FDO and parked in the child's manual queue. Cancelled with `STATUS_CANCELLED` |
| 0x2AC108 | Test hook | Passed to client callback 0x4C if present, else `STATUS_NOT_SUPPORTED` |

Any other code → `STATUS_NOT_SUPPORTED` (0xC00000BB).

### Internal IOCTLs on the controller FDO

`UsbFnClxEvtDeviceInternalIoControl` (sequential default queue). Also reachable directly through the interface `{cec7d47f-…}`, which [qcrmnetbridge8930.sys](./qcrmnetbridge8930.md) uses for its bulk pipes 8 and 9.  
- 0x2AC00D / 0x2AC011 / 0x2AC016: the endpoint direction must match (IN for 0x2AC00D/0x2AC011, OUT for 0x2AC016, any for EP0), else `STATUS_INVALID_PARAMETER`. 0x2AC011 is rewritten into 0x2AC00D when no zero-length packet is needed (length 0 or not a multiple of `wMaxPacketSize`), which is why [usbfnchipidea.sys](./usbfnchipidea.md#internal-ioctl-0x2ac011--ioctl_internal_usbfn_transfer_in_append_zero_pkt) never sees invalid lengths. Then `WdfRequestForwardToIoQueue` to the pipe's queue; `STATUS_WDF_BUSY` → 0xC00000AC.
- 0x2AC018 / 0x2AC01C: forwarded to the EP0 queue.
- 0x2AC036: forwarded to the event queue of the child.
- Any other code → `__debugbreak()`.

---

### internal IOCTL 0x2AC03A — IOCTL_INTERNAL_USBFN_SET_POWER_FILTER_STATE

This internal IOCTL is sent by Usbfnclx.sys to the lower device of the controller stack ([qcusbfnfilter8930.sys](./qcusbfnfilter8930.md#internal-ioctl-0x2ac03a--ioctl_internal_usbfn_set_power_filter_state)) in `UsbFnPowerFilterSetState`, from `EvtDeviceArmWakeFromS0`. Preallocated request, synchronous `WdfRequestSend` with a 2 s relative timeout.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0xE (14) |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_INTERNAL_USBFN_SET_POWER_FILTER_STATE | lower device | 8 | 0 |

Inputbuffer (context +0x274):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 03 00 00 00 | Device state (`USBFN_DEVICE_STATE`, see [State machine](#state-machine)) |
| 04-07 | 00 00 00 00 | |

---

### internal IOCTL 0x2AC03E — Exit low-power mode

This internal IOCTL is sent by Usbfnclx.sys to the lower device of the controller stack ([qcusbfnfilter8930.sys](./qcusbfnfilter8930.md#internal-ioctl-0x2ac03e)) in `UsbFnPowerFilterExitLPM`, from `EvtDeviceD0Entry`. No buffers, synchronous, 2 s timeout.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0xF (15) |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

---

### IOCTL 0x29C4C0 — Charging notification

This IOCTL is sent by Usbfnclx.sys (`NotifyCad`) to the device that registered `GUID_DEVINTERFACE_CHARGING_ARBITRATION` (target opened on interface arrival). Asynchronous, no output.

| Property | Value |
|----------|-------|
| Device | 0x29 |
| Function | 0x130 (304) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Charging notification ? | `{ec0a1cc9-…}` | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | Version / type ? |
| 04-07 | e.g. DC 05 00 00 | Current in mA (0, or ≥ 500) |
| 08 | 00/01 | 1 = USB connected |
| 0C-0F | e.g. 02 00 00 00 | Port type |

---

### Interface GUID

Device interface of the controller FDO (configuration IOCTLs, direct transfers), `USBFN_CLX_DEVICE_INTERFACE`  
`{cec7d47f-a1e1-4607-a693-9a0061465db7}`

### Other GUID

`GUID_DEVINTERFACE_CHARGING_ARBITRATION`  
`{ec0a1cc9-4294-43fb-bf37-b850ce95f337}`

`GUID_DEVCLASS_USBFNBUS` (bus type of the children)  
`{17f99fe7-5ebe-49fe-a348-05be51fe7f08}`

`GUID_DEVINTERFACE_USBFNTEST_POWER_TEST`  
`{a437e7be-7175-4d69-9d30-f82efd144b5a}`

`GUID_USBFN_INTERFACE_POWER_TEST`  
`{688e49d4-1563-446b-838b-11287a4d0445}`
