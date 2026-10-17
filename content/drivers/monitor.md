## Monitor.sys

Microsoft generic monitor class function driver (KMDF, `monitor.pdb`).  
It is loaded on the monitor child device that the display stack (dxgkrnl, on top of `qcdxkm8930.sys`) creates for the panel. It owns the **brightness** of an internal panel: it reads the list of supported levels, applies a requested percentage (clamped by thermal throttling), and reports every change to the user-mode power manager through the ALPC port `\PowerMonitorPort`. It also exposes the standard `WmiMonitor*` WMI classes (EDID, display parameters, brightness) by forwarding internal IOCTLs to the monitor PDO.  
It links against `watchdog.sys` (`VpInitialize`). It does not touch any hardware register itself: brightness goes either through the display miniport's brightness interface or through the ACPI methods `_BCL`/`_BCM`/`_BQC` of the device.

Symbolic link : `\DosDevices\LCD`  
There's no named `\Device\` object (the WDF device is unnamed). The symbolic link points to the **PDO name** (`IoGetDeviceProperty(DevicePropertyPhysicalDeviceObjectName)`), and is only created for the first monitor that has brightness levels (global `LCDDevice`). It is deleted in `EvtDeviceContextCleanup` (0x17260).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\Monitor`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Monitor\Parameters` (hardcoded path, opened with `ZwCreateKey`, so it's created when missing; read with `RtlQueryRegistryValuesEx`, `RTL_QUERY_REGISTRY_DIRECT`), in `GetRegistryParameters` (0x17328):  
| Registry value | value | comment |
|----------------|-------|---------|
| MinimumStepPercentage | 5 | REG_DWORD. Converted to a minimum step in level units (`10 × maxLevel × value / 1000`, at least 1, context `+0x14C`), but this value is never read afterwards |
| ThermalDisable | 0 | REG_DWORD. When 0, the driver exposes the passive-cooling interface `GUID_THERMAL_COOLING_INTERFACE` (see [Thermal throttling](#thermal-throttling)) |

GUID of the ETW provider:  
`{58C83E82-BABB-4B14-AA65-2AC73525FD3A}` (WPP control GUID `MonitorTraceGuid`)  
`{CEB93324-0DC4-4D12-A466-9926716F2B2A}` (`VP_ETW_MONITOR_CONTROL_GUID`, classic WMI/ETW provider registered with `IoWMIRegistrationControl`). Its events:  
| Event GUID | Comment |
|------------|---------|
| `{F0D7CC84-A780-4711-BA01-5A46FF7940F1}` | `VP_ETW_MONITOR_VERSION_DATA_GUID`. Written when a logger enables the provider, data = 1 (version) |
| `{5F505EB1-6F2B-43EC-86F5-55419C61CFA2}` | `VP_ETW_MONITOR_ACPI_EVENT_DATA_GUID`. Written for every ACPI notification received, data = notify code |

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Monitor PDO (lower device) | dxgkrnl.sys ? | Internal IOCTLs `0x232407`…`0x23242B` (adapter info, EDID and WMI data), see [IOCTLs sent](#internal-ioctl-0x232407--get-monitor-adapter-info) |
| Lower device, query-interface `GUID_DEVINTERFACE_BRIGHTNESS` | [qcdxkm8930.sys](./qcdxkm8930.md#query-interfaces) (display miniport, `DxgkDdiQueryInterface` through dxgkrnl) | Brightness interface version 1 (`sub_49E4C4` in qcdxkm8930): GetPossibleBrightness `sub_49DE00` / SetBrightness `sub_49E07C` / GetBrightness `sub_49DFFC`. Only exposed when the panel has a backlight |
| ACPI node of the device | [acpi.sys](./acpi.md) | Fallback brightness through `IOCTL_ACPI_EVAL_METHOD` (`_BCL`, `_BCM`, `_BQC`); notifications through `GUID_ACPI_INTERFACE_STANDARD2` |
| `\PowerMonitorPort` (ALPC) | user-mode power manager (UMPO ?) | Brightness messages, see [ALPC messages](#alpc-messages-to-powermonitorport) |
| — | thermal manager ? | Consumer of `GUID_THERMAL_COOLING_INTERFACE` |

### Initialisation

`EvtDriverDeviceAdd` (0x16860):
1. `GetMonitorAdapterInfo` (0x177D4) sends internal IOCTL `0x232407` to the PDO. `STATUS_NOT_SUPPORTED` means "no adapter info" (context `+0x150` = 0, the output technology is then `0xFFFFFFFE` = uninitialized); any other error fails the device.
2. `WdfDeviceInitSetPowerPageable`, PnP/power callbacks `EvtDeviceSelfManagedIoInit/Cleanup/Restart`, and `WdfDeviceInitSetPowerPolicyOwnership(adapter info present)`.
3. Reads the registry, creates the device interface `GUID_DEVINTERFACE_MONITOR_DRIVER` `{866519B5-3F07-4C97-B7DF-24C5D8A8CCB8}` and a parallel queue (`EvtIoDefault`, `EvtIoDeviceControl`, `EvtIoInternalDeviceControl`).
4. With adapter info, assigns the S0-idle settings: `IdleCannotWakeFromS0`, D3, timeout 1 ms, `IdleDoNotAllowUserControl`, **Enabled = FALSE** (enabled later by internal IOCTL `0x23242F`).
5. If the video output technology (`D3DKMDT_VIDEO_OUTPUT_TECHNOLOGY`, adapter info `+08`) is an internal panel — `0x80000000` (INTERNAL), `0x0B` (DISPLAYPORT_EMBEDDED) or `0x0D` (UDI_EMBEDDED) — and no other monitor owns `\DosDevices\LCD`: `BrightnessInit` (0x1641C) queries the brightness interface.
6. `AcpiInit` (0x16000): when no brightness interface was obtained, uses ACPI `_BCL` for the levels, `_BCM` to set and `_BQC` to get. `STATUS_NOT_FOUND` (no `_BCL`) is tolerated: the monitor then has no brightness control.
7. When brightness is available: connects to the ALPC port `\PowerMonitorPort` (`MonitorAlpcInit` 0x1218C, `ZwAlpcConnectPort` flags `0x20000`). **A connection failure fails the device add.** Then `MonitorThermalInit` (0x17D30).
8. Thermal limit and ALS value set to 100, `ZwPowerInformation(MonitorCapabilities (0x28), TRUE)` tells the power manager the monitor supports brightness.
9. Creates the `\DosDevices\LCD` link, a 1-second timer and a work item (`BrightnessTimerWorker` → `ProcessBrightness`), then registers WMI (`WmiInitialize`, MOF resource name `MonitorWMI`).

`EvtDeviceSelfManagedIoInit` (0x16F78), only when a brightness setter exists:  
| Power setting / notification | Comment |
|------------------------------|---------|
| `GUID_DEVICE_POWER_POLICY_VIDEO_BRIGHTNESS` `{ADED5E82-B909-4619-9949-F5D71DAC0BCB}` | 4-byte value = brightness percentage → context `+0x10`, work item queued. The callback **unregisters itself** after the first (initial) value |
| `GUID_ACDC_POWER_SOURCE` `{5D3E9A59-E9D5-4B00-A6BD-FF34FF516548}` | Sets the "power source changed" flag (`+0xFA`): the next brightness change is delayed by 1 s |
| `GUID_CONSOLE_DISPLAY_STATE` `{6FE69556-704A-47A0-8F24-C28D936FDA47}` | Display state (`+0xFC`, 1 = on), used by the ACPI notification handler |
| ACPI device notifications (`RegisterForDeviceNotifications` of `GUID_ACPI_INTERFACE_STANDARD2`) | `AcpiNotifyCallback` (0x11A74) → work item `AcpiNotificationWorker` (0x1636C) |

### Brightness

Levels (from `GetPossibleBrightness` or from the ACPI `_BCL` package, max 103 entries) are kept raw at `+0x28` (count) / `+0x29`, and a sorted, de-duplicated copy at `+0x90` / `+0x91` (`BrightnessSortStates` 0x164E0). At least 2 levels are needed. As in the ACPI spec, the first two raw entries are taken as the AC/DC default levels (`+0x1C`/`+0x1D`, never read afterwards).  
qcdxkm8930's `GetPossibleBrightness` (`sub_49DE00`) builds its list in this `_BCL` layout from the panel's level table: `100` first, then the level closest to 60, then the other levels. It fails with `0xC00000BB` STATUS_NOT_SUPPORTED when the last level of the panel table is not 100.

Conversions (maxLevel = highest sorted level):  
* level → percentage: `100 × level / maxLevel` (`BrightnessTargetToPercentage` 0x16744)
* percentage → level: `ceil(maxLevel × pct / 100)`, then the nearest supported level, ties going to the higher one (`BrightnessTargetPercentageToPossible` 0x1678C)

`ProcessBrightness` (0x16604), under the fast mutex `BrightnessMutexLock`:
1. If the power source just changed, clear the flag and (re)start the 1-second timer; nothing else.
2. Otherwise take the requested percentage (`+0x10`), clamp it to the thermal limit (`+0x24`), convert it to a level and call SetBrightness / `_BCM`.
3. On success, send ALPC message type 3 with the level, and fire the WMI event `WmiMonitorBrightnessEvent` (1 byte = level).

ACPI notification codes handled by `AcpiNotificationWorker` (other codes are ignored):  
| Notify code | ACPI meaning | Action when the display is on | Action when the display is off |
|-------------|--------------|-------------------------------|--------------------------------|
| 0x85 | Cycle brightness | ALPC type 2, value 2 | `PoSetSystemState(ES_USER_PRESENT)` |
| 0x86 | Increase brightness | ALPC type 2, value 0 | same |
| 0x87 | Decrease brightness | ALPC type 2, value 1 | same |
| 0x88 | Zero brightness | ALPC type 2, value 3 | same |

### ALPC messages to `\PowerMonitorPort`

`MonitorAlpcSendPoMessage` (0x121FC) sends a 32-byte message with `ZwAlpcSendWaitReceivePort` (flags `0x10000`, no reply). It returns `STATUS_INVALID_HANDLE` (0xC0000008) when the port isn't connected.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 08 00 | `PORT_MESSAGE.DataLength` |
| 02-03 | 20 00 | `PORT_MESSAGE.TotalLength` |
| 04-17 | 00 … | Rest of the `PORT_MESSAGE` header |
| 18-1B | ? | Message type (see below) |
| 1C-1F | ? | Value |

| Type | Value | Sent by |
|------|-------|---------|
| 0 | Requested brightness percentage | `IOCTL_VIDEO_SET_DISPLAY_BRIGHTNESS`, `WmiSetBrightness`, `WmiSetALSBrightness` |
| 1 | Always 100 | `WmiSetALSBrightnessState` (the ALS on/off state itself is not sent) |
| 2 | 0 = increase, 1 = decrease, 2 = cycle, 3 = zero | ACPI brightness hotkey notifications |
| 3 | Level actually applied | `ProcessBrightness` |

> [!NOTE]
> The user-mode requests (`IOCTL_VIDEO_SET_DISPLAY_BRIGHTNESS`, WMI methods) **do not change the brightness**: they only forward the request to the power manager through ALPC. The hardware is changed only by `ProcessBrightness`, i.e. by internal IOCTL `0x232433`, the brightness power setting, or thermal throttling.

### Thermal throttling

With `ThermalDisable` = 0 and brightness available, `MonitorThermalInit` registers the query interface `GUID_THERMAL_COOLING_INTERFACE` `{ECBE47A8-C498-4BB9-BD70-E867E0940D22}` (`WdfDeviceAddQueryInterface`, Size 0x1C, Version 1, Flags 0, reference/dereference = no-op `WdfDeviceInterfaceDereferenceNoOp`, no ActiveCooling).  
`PassiveCooling(Context, Percentage)` (`MonitorPassiveCoolingNotification` 0x17DC4) stores the percentage (0 → 1) as the brightness limit `+0x24` and calls `ProcessBrightness`. While the limit is below 100, the query handlers report the cached value instead of reading the hardware.

### WMI

Data blocks and methods registered by `WmiRegisterDataBlocks` (0x17EA4), `WmiRegisterMethods` (0x1828C) and `WmiRegisterEvents` (0x1836C). The monitor-data blocks are only registered if the PDO answers the size probe (8-byte buffer) with `STATUS_BUFFER_OVERFLOW` and a non-zero size. Registration failure of the last block returns `STATUS_MONITOR_WMI_DATABLOCK_REGISTRATION_FAILED` (0xC01D0005).  
| WMI class | GUID | Source |
|-----------|------|--------|
| WmiMonitorBrightness | `{D43412AC-67F9-4FBB-A081-1752A2C33E84}` | Driver: current level (00), level count (04-07), sorted levels (08…). Only with brightness |
| WmiMonitorBrightnessMethods | `{479B20B4-5559-46FE-BE97-7D222154421F}` | Driver, see below. Only with brightness |
| WmiMonitorBrightnessEvent | `{123C80D2-937F-4CFE-80F4-C40D596E48B7}` | Driver, fired by `ProcessBrightness`. Only with brightness |
| WmiMonitorID | `{671A8285-4EDB-4CAE-99FE-69A15C48C0BC}` | internal IOCTL `0x23241B` |
| WmiMonitorBasicDisplayParams | `{9831B7E6-09AC-491F-8D07-3C3D649D8240}` | internal IOCTL `0x232423` |
| WmiMonitorConnectionParams | `{2E2D2463-B537-4DA7-8EEE-51306F1F482F}` | Driver: 4 bytes = video output technology (`+0x154`) |
| WmiMonitorAnalogVideoInputParams | `{A56DBCF9-C4F0-44A8-9C1B-BB3B3F774B4D}` | internal IOCTL `0x232427` |
| WmiMonitorDigitalVideoInputParams | `{51565945-498A-4A77-ACC6-151BECC805CA}` | internal IOCTL `0x23242B` |
| WmiMonitorColorCharacteristics | `{EA324793-51BB-486A-AA9D-0F5552353413}` | internal IOCTL `0x23241F` |
| WmiMonitorListedSupportedSourceModes | `{6DC76655-063C-4524-A862-B8410C26281B}` | internal IOCTL `0x23240F` |
| WmiMonitorDescriptorMethods | `{5341576E-75C4-4AEB-A82B-873CD3C6B384}` | internal IOCTL `0x232417` (only if its probe returns `STATUS_BUFFER_TOO_SMALL`) |

`WmiMonitorBrightnessMethods` (`EvtWmiBrightnessExecuteMethod` 0x185C8):  
| Method id | Name | Behaviour |
|-----------|------|-----------|
| 1 | WmiSetBrightness(Timeout, Brightness) | Byte `04` is treated as a **level** and converted to a percentage (the same only when maxLevel = 100), then ALPC type 0 |
| 2 | WmiRevertToPolicyBrightness | No-op, returns `STATUS_SUCCESS` |
| 3 | WmiSetALSBrightnessState(Active) | Stores the ALS flag (`+0xF8`), sends ALPC type 1 value 100 |
| 4 | WmiSetALSBrightness(Brightness) | Brightness ≤ 100: ALPC type 0, only when the ALS flag is set (otherwise ignored) |
| other | | `STATUS_WMI_ITEMID_NOT_FOUND` (0xC0000297) |

### Device context

Offsets in the WDF device context, for reopening the analysis:  
| Offset | Comment |
|--------|---------|
| 0x00 / 0x04 / 0x08 | Power-setting callback handles (brightness, display state, AC/DC) |
| 0x0C | WMI instance of `WmiMonitorBrightnessEvent` |
| 0x10 | Requested brightness percentage |
| 0x14 / 0x18 | Work item / 1-second timer |
| 0x1C / 0x1D | First two `_BCL` entries (AC/DC default), unused |
| 0x20 | ALS value, always 100 |
| 0x24 | Thermal brightness limit in % (100 = none) |
| 0x28 / 0x29 | Raw level count / levels (103 bytes) |
| 0x90 / 0x91 | Sorted level count / levels |
| 0xF8 | ALS active flag |
| 0xF9 | Thermal interface enabled (= !ThermalDisable) |
| 0xFA | Power source changed flag |
| 0xFC | Console display state |
| 0x100 | `ACPI_INTERFACE_STANDARD2` (44 bytes) |
| 0x12C | Brightness interface (28 bytes): `+0x130` context, `+0x13C` GetPossibleBrightness, `+0x140` SetBrightness (or `AcpiEvaluateBcm`), `+0x144` GetBrightness (or `AcpiEvaluateBqc`) |
| 0x148 / 0x14C | MinimumStepPercentage / minimum step in levels |
| 0x150 | Adapter info present |
| 0x154 | Video output technology |
| 0x158 | `WDF_DEVICE_POWER_POLICY_IDLE_SETTINGS` (`+0x16C` = Enabled) |
| 0x17C | ALPC port handle |

---

All non-IOCTL requests (create, close, read, write) are completed with `STATUS_SUCCESS` by `EvtIoDefault` (0x17918).

### IOCTL 0x230494 — IOCTL_VIDEO_QUERY_SUPPORTED_BRIGHTNESS

This IOCTL is processed by Monitor.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x125 (293) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_VIDEO_QUERY_SUPPORTED_BRIGHTNESS | 0 | ≥ raw level count − 2 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-… | ? | Raw levels **without the first two entries** (`+0x2B`…), unsorted, one byte each |

Fails with `STATUS_NOT_FOUND` (0xC0000225) when there are fewer than 3 raw levels. The first two entries are skipped even when the levels come from the brightness interface rather than from `_BCL`.

---

### IOCTL 0x230498 — IOCTL_VIDEO_QUERY_DISPLAY_BRIGHTNESS

This IOCTL is processed by Monitor.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x126 (294) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_VIDEO_QUERY_DISPLAY_BRIGHTNESS | 0 | ≥ 3 |

Outputbuffer (`DISPLAY_BRIGHTNESS`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 02 | ucDisplayPolicy, always `DISPLAYPOLICY_DC` |
| 01 | ? | ucACBrightness = current level |
| 02 | ? | ucDCBrightness = current level |

The current level is the requested percentage converted to a level; when GetBrightness / `_BQC` exists and there's no thermal limit, the hardware value is read instead and the cached percentage is updated.

---

### IOCTL 0x23049C — IOCTL_VIDEO_SET_DISPLAY_BRIGHTNESS

This IOCTL is processed by Monitor.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x127 (295) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_VIDEO_SET_DISPLAY_BRIGHTNESS | ≥ 3 | 0 |

Inputbuffer (`DISPLAY_BRIGHTNESS`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | ucDisplayPolicy, ignored |
| 01 | ? | ucACBrightness, ignored |
| 02 | ? | ucDCBrightness, level |

The level is converted to a percentage and sent as ALPC message type 0. Nothing is applied to the panel (see the note above).

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is processed by Monitor.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 (1) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

Forwarded unchanged (send-and-forget) to the lower driver when the requestor is kernel mode (`WdfRequestGetRequestorMode`); from user mode it's rejected with `STATUS_NOT_SUPPORTED`. Every other IOCTL code also gets `STATUS_NOT_SUPPORTED` (0xC00000BB).

---

### internal IOCTL 0x23242F — set monitor power state ?

This IOCTL is processed by Monitor.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x90B (2315) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `01 00 00 00` | State. 1 (D0 / active ?) disables S0-idle, any other value enables it |

Handled only when the adapter info is present, otherwise forwarded to the lower driver. When the state changes, the S0-idle settings are re-assigned with `Enabled` = (value ≠ 1): the monitor device then idles to D3 after 1 ms. The same rule is applied at start-up with adapter info `+0C`.

---

### internal IOCTL 0x232433 — set brightness

This IOCTL is processed by Monitor.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x90C (2316) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | Brightness percentage |
| 01-03 | ? | Ignored |

Handled only when a brightness interface or ACPI brightness is present, otherwise forwarded to the lower driver. Stores the percentage and runs `ProcessBrightness` — this is the path that actually changes the panel brightness. Caller ? (presumably the power manager, in response to the ALPC messages).

---

### internal IOCTL 0x232407 — get monitor adapter info

This IOCTL is sent by Monitor.sys to the monitor PDO

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x901 (2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| ? | monitor PDO | 0 | 16 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | ? |
| 08-0B | ? | `D3DKMDT_VIDEO_OUTPUT_TECHNOLOGY` (0x80000000 = internal) |
| 0C-0F | ? | Initial state, same meaning as internal IOCTL `0x23242F` |

Sent at `EvtDriverDeviceAdd` and again at `EvtDeviceSelfManagedIoInit`. `STATUS_NOT_SUPPORTED` = no adapter info.

---

### internal IOCTL 0x23240F, 0x23241B, 0x23241F, 0x232423, 0x232427, 0x23242B — monitor WMI data

These IOCTLs are sent by Monitor.sys to the monitor PDO (`WmiCallPhysicalDevice` 0x120C8), to fill a WMI data block.

| Name | Function | Device name | InputBuffer size | OutputBuffer Size |
|------|----------|-------------|------------------|-------------------|
| WmiMonitorListedSupportedSourceModes | 0x903 | monitor PDO | 8 | 8 |
| WmiMonitorID | 0x906 | monitor PDO | 8 | 8 |
| WmiMonitorColorCharacteristics | 0x907 | monitor PDO | 8 | 8 |
| WmiMonitorBasicDisplayParams | 0x908 | monitor PDO | 8 | 8 |
| WmiMonitorAnalogVideoInputParams | 0x909 | monitor PDO | 8 | 8 |
| WmiMonitorDigitalVideoInputParams | 0x90A | monitor PDO | 8 | 8 |

Device 0x23, FILE_ANY_ACCESS, METHOD_NEITHER. The same 8-byte buffer is used as input and output:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | In: size of the WMI buffer (0 for the probe). Out: size required / written |
| 04-07 | ? | In: pointer to the WMI buffer (0 for the probe) |

At registration a probe with a zero size must return `STATUS_BUFFER_OVERFLOW` (0x80000005) and a non-zero size, otherwise the WMI block isn't registered.

---

### internal IOCTL 0x232417 — get EDID block

This IOCTL is sent by Monitor.sys to the monitor PDO

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x905 (2309) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| WmiGetMonitorRawEEdidV1Block | monitor PDO | 136 | 136 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | EDID block index |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 01 | ? | Block type |
| 02-81 | ? | Block content (128 bytes) |

Bytes `01-81` (129 bytes) are returned as the WMI method output. The probe (no buffers) must return `STATUS_BUFFER_TOO_SMALL` for `WmiMonitorDescriptorMethods` to be registered.

---

### Interface GUID

Monitor driver interface class GUID (`GUID_DEVINTERFACE_MONITOR_DRIVER`)  
`{866519B5-3F07-4C97-B7DF-24C5D8A8CCB8}`

### Other GUID

Brightness interface queried from the lower driver (`GUID_DEVINTERFACE_BRIGHTNESS`), provided by [qcdxkm8930.sys](./qcdxkm8930.md#query-interfaces)  
`{FDE5BBA4-B3F9-46FB-BDAA-0728CE3100B4}`

ACPI interface (`GUID_ACPI_INTERFACE_STANDARD2`)  
`{E8695F63-1831-4870-A8CF-9C2F03F9DCB5}`

Thermal cooling interface exposed (`GUID_THERMAL_COOLING_INTERFACE`)  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`
