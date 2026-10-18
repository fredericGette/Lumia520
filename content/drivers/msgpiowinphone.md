## Msgpiowinphone.sys

GPIO hardware buttons driver ("GPIO Windows Phone Button Driver", Microsoft, version "1.0").  
It is a KMDF HID minidriver. It calls `WdfFdoInitSetFilter`, so it runs below the HID class driver (probably `mshidkmdf.sys`, the usual pattern for KMDF HID minidrivers ?) and processes its internal HID IOCTLs. Each button is a GPIO interrupt (`GpioInt`) of the ACPI node `\_SB.BTN0`. Every interrupt toggles the state of the button: the GPIO level is never read. The driver reports the buttons in a HID input report with 14 bits.  
It also creates a raw child PDO, "GPIO Buttons", where user mode can inject button events and choose which buttons stay enabled during the "low power epoch" (screen off). It implements two key combinations ("key dances") on buttons 2 and 3: one triggers a crash dump (bugcheck `0xE2` or a live kernel dump), the other asks StorageSvc for a power log through ALPC.  
PDB: `msgpiowinphone.pdb`. Driver pool tag `GBut`. Other pool tags: `Itf1` (registry query table), `Secr` (security), `UnI\0` (ACPI output buffer).

Hardware ID: `QCOM0D60`, compatible ID `PNP0C40` (Standard Button Controller), ACPI node `\_SB.BTN0` ([DSDT](../acpi/README.md)).  
There's no device name and no symbolic link. The FDO is created without a name. The child PDO is reached through its [device interface](#interface-guid).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0D60\<instance>`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\Input\Buttons` (read and written in `EvtWdfDevicePrepareHardware` 0x100032CC):  
| Registry value | value | comment |
|----------------|-------|---------|
| Existing | e.g. `0x0000018D` | REG_DWORD. Only written when the key doesn't exist yet: the key is created and this value is set to the bitmask of the buttons found in ACPI (driver context `+8`, bit n = button n). On the Lumia 520: 0x18D = buttons 0, 2, 3, 7, 8 |
| EnabledOnIdleBitMask | 0x3F03 | REG_DWORD, read with `RTL_QUERY_REGISTRY_DIRECT` (no type check), masked with `0x3FFF`. Default `0x3F03` (`word_10007040`) if missing. Bit n = button n stays active (and can wake the phone) during the low power epoch. Written back (2 bytes only) by [IOCTL 0xB02A8](#ioctl-0xb02a8--set-button-enabled-on-idle). Only read when the key already exists, otherwise the default is used |

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\Input\FingerKB` (read by sub_10002DBC, at each `PrepareHardware` and before each crash dump):  
| Registry value | value | comment |
|----------------|-------|---------|
| EnableTestFeatures | 0 | REG_DWORD (type checked), default 0. If not 0, the [key dances](#key-dances) are enabled (driver context `+0xA`) |
| KernelDumpMode | 0 | REG_DWORD, only read if `EnableTestFeatures` ≠ 0. 0 = the crash key dance calls `KeBugCheckEx(0xE2)`. Other values = live kernel dump instead (driver context `+0xD`) |

Registry key `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\qcpep\Parameters` (sub_10002C5C, only read if `EnableTestFeatures` ≠ 0):  
| Registry value | value | comment |
|----------------|-------|---------|
| PxoPowerCollapseLedEnable | ? | REG_DWORD. If exactly 1 (driver context `+0xC`): buttons 2 and 3 are forced "enabled on idle" at `PrepareHardware` (and can't be disabled), and the [power log key dance](#key-dances) is enabled. The value belongs to [qcpep8930.sys](./qcpep8930.md) |

GUID of the ETW provider:  
`{64AB66B7-82D7-433B-98E9-45D642F7EEE4}`

| Event Id | Level | Keyword | When |
|----------|-------|---------|------|
| 100 (0x64) | 4 | 0x2 | Button interrupt (ISR sub_10003614) |
| 110 (0x6E) | 4 | 0x2 | Write to the PDO (injection, sub_10002614) |
| 120 (0x78) | 4 | 0x2 | Input report completed (sub_1000210C) |
| 200 (0xC8) | 4 | 0x8 | Crash key dance detected |
| 201 (0xC9) | 4 | 0x8 | Crash dump work item started |
| 202 (0xCA) | 2 | 0x1 | `DbgkWerCaptureLiveKernelDump` failed |

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device (ACPI PDO of `\_SB.BTN0`) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_EVAL_METHOD_EX` on `BNWP` |
| `\BaseNamedObjects\StorageSvcAdminPort` (ALPC port) | StorageSvc (user mode service ?) | Power log request, see [key dances](#key-dances) |
| HID class driver (upper device) | mshidkmdf.sys / hidclass.sys ? | Internal HID IOCTLs (see below) |

### Lumia 520 ACPI node

`\_SB.BTN0` `_CRS` has 10 resources: one `GpioInt` + `GpioIo` pair per button, on the same pin. `BNWP` returns `00 02 03 07 08`, the button number of each interrupt (in resource order). `BNAS` (`01 00 00 00 00`) isn't used by this driver.  
| Interrupt index | Button (`BNWP`) | GPIO controller | Pin | `GpioInt` flags | Pull | Debounce | Physical button |
|-----------------|-----------------|-----------------|-----|-----------------|------|----------|-----------------|
| 0 | 0 | `\_SB.PWIO` | 16 | Edge, ActiveBoth, Shared | PullDown | 0 | Power |
| 1 | 2 | `\_SB.PM01` | 194 (PMIC GPIO3) | Edge, ActiveBoth, Shared, Wake | PullUp | 62 ms | Volume up/down ? |
| 2 | 3 | `\_SB.PM01` | 199 (PMIC GPIO8) | Edge, ActiveBoth, Shared, Wake | PullUp | 62 ms | Volume up/down ? |
| 3 | 7 | `\_SB.PM01` | 202 (PMIC GPIO11) | Edge, ActiveBoth, Shared (no wake) | PullUp | 62 ms | Camera half press (focus) ? |
| 4 | 8 | `\_SB.PM01` | 201 (PMIC GPIO10) | Edge, ActiveBoth, Shared, Wake | PullUp | 62 ms | Camera full press ? |

The `\_SB.PM01` pins are PMIC interrupt numbers (see [qcpmicgpio8930.sys](./qcpmicgpio8930.md#pin-numbering)).  

### Start-up

1. `DriverEntry` (0x10006000): registers the ETW provider and calls `WdfDriverCreate` (pool tag `GBut`, driver context `DRIVER_CONTEXT`).
2. `EvtDriverDeviceAdd` (0x10003000):
   * `WdfFdoInitSetFilter`, PnP callbacks `EvtDevicePrepareHardware` / `EvtDeviceReleaseHardware`, `WdfDeviceCreate` (context `DEVICE_EXTENSION`);
   * default parallel queue with `EvtIoInternalDeviceControl` (0x1000377C), plus a manual queue (`+0x4`) for pending `IOCTL_HID_READ_REPORT` requests;
   * initialises the two event ring buffers (64 bytes each: GPIO events at `+0x8`, injected events at `+0x54`) and `EnabledOnIdleBitMask` = 0x3F03;
   * for the first device only: saves the extension in a global (`WdfDriverStubDisplacedDriverUnload`, misnamed by IDA) and creates the [raw PDO](#raw-pdo-gpio-buttons) (sub_10002730);
   * `KeInitializeDpc` (DPC sub_1000369C, completes the pending reads), `PoRegisterPowerSettingCallback` on [`{E1233993-…}`](#low-power-epoch);
   * two work items in the driver context: `+0x0` power log (sub_10002EFC) and `+0x4` crash dump (sub_10002F28).
3. `EvtDevicePrepareHardware` (0x100032CC):
   * fewer than 5 resources → `STATUS_DEVICE_CONFIGURATION_ERROR` (0xC0000182);
   * evaluates `BNWP` (sub_10003B24, see [IOCTL 0x32C018](#ioctl-0x32c018--ioctl_acpi_eval_method_ex)). If it fails: DbgPrint "Missing ACPI Button Config - Using Default" and the default map `00 02 03 07 08` (5 buttons) is used, the same as the Lumia 520 DSDT;
   * the number of resources must be equal to the number of buttons or 2 × the number (`GpioInt` + `GpioIo` pairs), otherwise 0xC0000182;
   * for each `CmResourceTypeInterrupt` descriptor: button = map[interrupt index] (≥ 16 → 0xC0000182). Fills the 8-byte pin context (`+0x100 + 8 × index`: button, index, "two events" flag, toggle, extension pointer). Sets the button bit in the driver context `+8` and calls `IoConnectInterruptEx` (`CONNECT_FULLY_SPECIFIED`, ISR sub_10003614, spin lock = the GPIO ring lock `+0x10`). **The status of `IoConnectInterruptEx` isn't checked**;
   * the `SYSTEM\Input\Buttons` key (see the registry tables above), then the `FingerKB` values. If `PxoPowerCollapseLedEnable` = 1, buttons 2 and 3 are set "enabled on idle".
4. `EvtDeviceReleaseHardware` (0x100035C8) disconnects the 16 interrupt slots.

### Button events

* **ISR** (sub_10003614): pushes the button number into the GPIO ring (twice for buttons 9, 11 and 12: these buttons only give one interrupt per press, so a press and a release are queued), then queues the DPC. The DPC takes the requests waiting in the manual queue and completes them.
* **Read** (sub_1000210C, called for each `IOCTL_HID_READ_REPORT`): takes one event from the GPIO ring, otherwise from the injection ring, and toggles the button bit in the GPIO state (`+0xA0`) or in the injected state (`+0xA6`). The reported state (`+0xA8`) = GPIO state OR injected state. If it doesn't change (e.g. the same button is pressed for real and injected), nothing is reported and the request goes back to the manual queue. Button numbers ≥ 16 are dropped ("Invalid pin index").

Because each interrupt only toggles a bit, a missed edge inverts the button state until the next edge.

### Key dances

Only active if `FingerKB\EnableTestFeatures` ≠ 0. State machine in sub_1000210C (state at `+0x18C`, time at `+0x190`):  
1. Buttons 2 and 3 are both pressed → the time is saved, state 1.
2. Button 2 or 3 is released more than 3 s later (30,000,000 × 100 ns): if button 3 is still held → state 2; if button 2 is still held → state 3. Any other release → state 0.
3. Next button press:
   * state 2 → ETW event 200, then work item sub_10002F28: if `KernelDumpMode` = 0, `KeBugCheckEx(0xE2 MANUALLY_INITIATED_CRASH, 0, 0, 0, 0)`. Otherwise `DbgkWerCaptureLiveKernelDump(L"GPIOButtons", 0xE2, …)` (event 202 on failure).
   * state 3 → only if `PxoPowerCollapseLedEnable` = 1: work item sub_10002EFC (`DumpPowerLogKeyDanceDetected`, sub_10003D38). It connects to the ALPC port `\BaseNamedObjects\StorageSvcAdminPort` (`ZwAlpcConnectPortEx`, flag `ALPC_MSGFLG_SYNC_REQUEST`, timeout 30 s) and sends a synchronous message with a 4-byte payload `01 00 00 00` (`DataLength` 8, `TotalLength` 0x20). The required server security descriptor is read from the `SecurityDescriptor` value of `HKLM\Software\Microsoft\SecurityManager\TransientObjects\%5C%5C.%5CAlpcPort%5C%5CBASENAMEDOBJECTS%5CSTORAGESVCADMINPORT%5CSERVER`.
   * then state 4, back to 0 at the next release.

### Low power epoch

`PoRegisterPowerSettingCallback` with GUID `{E1233993-EAA4-470F-9DE7-A351C1B6FB71}` (the "LowPowerEpoch" of the debug strings, probably screen-off idle ?). Callback sub_10002AC0, value = DWORD (state at `+0x188`):  
* **1 (enter)**: `IoReportInterruptInactive` on every button interrupt whose button isn't in `EnabledOnIdleBitMask`. Then `GPIOButtonsInvalidateButtons` (sub_100028F8) queues a release event for each of these buttons that is currently pressed, and saves it (`+0x198`, count `+0x1D8`).
* **0 (exit)**: queues the saved events again (the buttons appear pressed again), then `IoReportInterruptActive` on the same interrupts.

With the default mask 0x3F03, on the Lumia 520 only buttons 0 (power) and 8 stay active.

### HID descriptors

HID descriptor (`IOCTL_HID_GET_DEVICE_DESCRIPTOR`, `.data:0x1000707C`): `09 21 01 01 00 01 22 5B 00` (HID 1.01, one report descriptor of 91 bytes).  
Device attributes (`IOCTL_HID_GET_DEVICE_ATTRIBUTES`): Size 32, VendorID 0, ProductID 0, VersionNumber 0.  
Strings (`IOCTL_HID_GET_STRING`): 14 (manufacturer) `Microsoft`, 15 (product) `GPIO Windows Phone Button Driver`, 16 (serial number) `1.0`. Any other id → `STATUS_INVALID_PARAMETER`, buffer too small → `STATUS_BUFFER_TOO_SMALL`.

Report descriptor (91 bytes, `.rdata:0x10001598`): Usage Page Generic Desktop, Usage 0xEE, Application collection with:  
* Report ID 1, **input**: 14 one-bit buttons (Keyboard usage page) + 18 padding bits → 5-byte report.
* Report ID 2, **feature**: the same 14 usages in another order + 2 padding bits → 3-byte report (the [EnabledOnIdle mask](#ioctl-0xb0191--ioctl_hid_set_feature)).

| Input bit = button | Keyboard usage | Lumia 520 |
|--------------------|----------------|-----------|
| 0 | 0x68 F13 | Power |
| 1 | 0x3B F2 | — |
| 2 | 0x42 F9 | Volume ? |
| 3 | 0x43 F10 | Volume ? |
| 4 | 0x03 (ErrorUndefined) | — |
| 5 | 0x29 Escape | — |
| 6 | 0x3C F3 | — |
| 7 | 0x3F F6 | Camera focus ? |
| 8 | 0x40 F7 | Camera ? |
| 9 | 0xF7 (reserved) | — (two events per interrupt) |
| 10 | 0x44 F11 | — |
| 11 | 0xF6 (reserved) | — (two events per interrupt) |
| 12 | 0x72 F23 | — (two events per interrupt) |
| 13 | 0x73 F24 | — |

Feature report usage order: 68 3B 3F 40 03 29 3C 42 43 F7 44 F6 72 73. It doesn't match the input order (bits 2/3 vs 7/8 are swapped), although the driver uses the same bit = button mapping for both (?).

### Raw PDO "GPIO Buttons"

Created by sub_10002730 (`WdfPdoInitAllocate`, then `WdfFdoAddStaticChild`):  
| Property | Value |
|----------|-------|
| Device ID / Hardware ID | `{30ebfbf8-df5f-4d4d-9fc5-a26c7fd1df4a}\GPIO Buttons` |
| Instance ID | `0` |
| Raw device class | `{4D36E96B-E325-11CE-BFC1-08002BE10318}` (Keyboard) |
| SDDL | `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GRGWGX;;;AU)(A;;GRGWGX;;;AC)` |
| Device interface | `{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}` |
| Queue | parallel default queue: `EvtIoWrite` sub_10002614, `EvtIoDeviceControl` sub_100024A8 |

**Opening** the PDO (`EvtDeviceFileCreate` sub_100026F0 → sub_100060A4) requires the capability `ID_CAP_BUTTONS`, otherwise `STATUS_ACCESS_DENIED`:  
* for an AppContainer token (`TokenIsAppContainer`): `RtlCheckTokenCapability` with the `ApplicationCapabilitySID` of `HKLM\Software\Microsoft\SecurityManager\Capabilities\ID_CAP_BUTTONS`;
* otherwise: LocalSystem is allowed. Else `RtlCheckTokenMembership` with the `ServiceCapabilitySID` of the same key. Else, membership of `S-1-5-21-2702878673-795188819-444038987-1030` (a check against an `ID_CAP_BUILTIN_TCB` list follows, but it never matches `ID_CAP_BUTTONS`).

**Writing** 2 bytes injects a button event:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 | Button number (< 16, otherwise `STATUS_INVALID_PARAMETER`) |
| 01 | 01 / 00 | New state: 1 = pressed, 0 = released |

Other lengths → `STATUS_INVALID_BUFFER_SIZE` (0xC0000206). If the state differs from the injected state (`+0xA4`), the event is pushed into the injection ring (twice for buttons 9, 11, 12) and one pending read is completed. Any value other than 0 or 1 is always "different", so it's injected every time. The write always goes to the first device (global pointer).  

> [!NOTE]
> This is the "TEST_PROXY" interface used by [oempanel.sys](./oempanel.md#test-proxy). Its records `00 01` then `00 00` are a press and release of button 0, i.e. a simulated **power key** press.

---

### IOCTL 0xB02A8 — Set button enabled on idle

This IOCTL is processed by Msgpiowinphone.sys (raw PDO, `EvtIoDeviceControl` sub_100024A8)

| Property | Value |
|----------|-------|
| Device | 0xB (FILE_DEVICE_KEYBOARD) |
| Function | 0xAA (170) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SetButtonEnabledOnIdle | 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 08 00 00 00 | Button number, 1–15 (0, the power button, is refused) |
| 04 | 01 / 00 | 1 = enabled on idle, 0 = disabled |
| 05-07 | | Ignored |

Wrong sizes or button → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). `SetButtonEnabledOnIdle` (sub_100023AC) changes bit n of `EnabledOnIdleBitMask` (`+0xA2`) and, if it changed, writes it to `HKLM\SYSTEM\Input\Buttons\EnabledOnIdleBitMask` (REG_DWORD, length 2). During the low power epoch nothing is changed ("Can't change button EnabledOnIdle state during LowPowerEpoch"), but `STATUS_SUCCESS` is returned. Disabling buttons 2 or 3 is ignored when `PxoPowerCollapseLedEnable` = 1. The change only takes effect at the next low power epoch.

---

### IOCTL 0xB02AC — Get button enabled on idle

This IOCTL is processed by Msgpiowinphone.sys (raw PDO, `EvtIoDeviceControl` sub_100024A8)

| Property | Value |
|----------|-------|
| Device | 0xB (FILE_DEVICE_KEYBOARD) |
| Function | 0xAB (171) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| GetButtonEnabledOnIdle | 4 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Button number (< 16) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | 1 if the button is enabled on idle, otherwise 0 |

Wrong sizes or button → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### internal IOCTL 0xB0003 — IOCTL_HID_GET_DEVICE_DESCRIPTOR

This IOCTL is processed by Msgpiowinphone.sys (`EvtIoInternalDeviceControl` 0x1000377C)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x0 (0) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

Copies the 9-byte [HID descriptor](#hid-descriptors) to the output memory.

---

### internal IOCTL 0xB0007 — IOCTL_HID_GET_REPORT_DESCRIPTOR

This IOCTL is processed by Msgpiowinphone.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x1 (1) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

Copies the 91-byte [report descriptor](#hid-descriptors) to the output memory.

---

### internal IOCTL 0xB000B — IOCTL_HID_READ_REPORT

This IOCTL is processed by Msgpiowinphone.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x2 (2) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_READ_REPORT | 0 | ≥ 5 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 | Report ID 1 |
| 01-02 | 01 00 | Button state, bit n = button n (e.g. power pressed) |
| 03-04 | | Not written by the driver (padding) |

Completed with Information = 5 as soon as a [button event](#button-events) changes the state. Otherwise the request waits in the manual queue.

---

### internal IOCTL 0xB0013 — IOCTL_HID_GET_STRING

This IOCTL is processed by Msgpiowinphone.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x4 (4) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

The string id is the low word of `Parameters.DeviceIoControl.Type3InputBuffer`. The Unicode string (with its NUL) is copied to `Irp->UserBuffer`, see [HID descriptors](#hid-descriptors).

---

### internal IOCTL 0xB0027 — IOCTL_HID_GET_DEVICE_ATTRIBUTES

This IOCTL is processed by Msgpiowinphone.sys

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x9 (9) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_HID_GET_DEVICE_ATTRIBUTES | 0 | 32 |

Outputbuffer (`HID_DEVICE_ATTRIBUTES`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 20 00 00 00 | Size |
| 04-05 | 00 00 | VendorID |
| 06-07 | 00 00 | ProductID |
| 08-09 | 00 00 | VersionNumber |

---

### internal IOCTL 0xB0191 — IOCTL_HID_SET_FEATURE

This IOCTL is processed by Msgpiowinphone.sys (sub_100039E0)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

The input length must be ≥ 12 (`HID_XFER_PACKET`), otherwise `STATUS_BUFFER_TOO_SMALL`. `Irp->UserBuffer` = `HID_XFER_PACKET` (NULL → `STATUS_INVALID_DEVICE_REQUEST`).  
Report buffer (`reportBufferLen` ≥ 5, otherwise `STATUS_BUFFER_TOO_SMALL`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 02 | Report ID 2 (otherwise `STATUS_INVALID_PARAMETER`) |
| 01-02 | 03 3F | New `EnabledOnIdleBitMask`. Bits 14–15 must be 0 (otherwise `STATUS_INVALID_PARAMETER`) |

Unlike [IOCTL 0xB02A8](#ioctl-0xb02a8--set-button-enabled-on-idle), the mask isn't written to the registry, isn't refused during the low power epoch, and ignores the `PxoPowerCollapseLedEnable` rule. During the low power epoch it calls `IoReportInterruptActive/Inactive` immediately. It loops over the interrupt index i = 1…n−1 and tests bit i of the mask, not bit (button of interrupt i): the interrupt 0 (power) is never changed, and on the Lumia 520 the bits tested (1–4) aren't the right buttons (2, 3, 7, 8). This looks like a bug.

---

### internal IOCTL 0xB0192 — IOCTL_HID_GET_FEATURE

This IOCTL is processed by Msgpiowinphone.sys (sub_10003944)

| Property | Value |
|----------|-------|
| Device | 0xB |
| Function | 0x64 (100) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_OUT_DIRECT |

Same checks as `IOCTL_HID_SET_FEATURE` (output length ≥ 12, report ID 2, `reportBufferLen` ≥ 5). Writes `EnabledOnIdleBitMask` at bytes `01-02` of the report buffer.

Any other internal IOCTL → `STATUS_NOT_SUPPORTED` (0xC00000BB).

---

### IOCTL 0x32C018 — IOCTL_ACPI_EVAL_METHOD_EX

This IOCTL is sent by Msgpiowinphone.sys to acpi.sys (`WdfIoTargetSendIoctlSynchronously` on the default I/O target, sub_10003B24)

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x6 (6) |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD_EX | ACPI PDO of `\_SB.BTN0` | 260 | 36 |

Inputbuffer (`ACPI_EVAL_INPUT_BUFFER_EX`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 41 | Signature `'AeiA'` (ACPI_EVAL_INPUT_BUFFER_SIGNATURE_EX) |
| 04-103 | 42 4E 57 50 00 … | Method name `BNWP` |

Outputbuffer (`ACPI_EVAL_OUTPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature `'AeoB'` |
| 04-07 | | Length |
| 08-0B | 01 00 00 00 | Count, must be 1 |
| 0C-0D | 02 00 | Argument type, must be 2 (buffer) |
| 0E-0F | 05 00 | Data length, ≤ 16 = number of buttons |
| 10-1F | 00 02 03 07 08 | Button number of each interrupt (Lumia 520) |

Any other content → `0xC014000F`. The buffer is copied to `+0xAA`, and the length to `+0xBA`.

### Interface GUID

GPIO Buttons raw PDO interface (`WdfDeviceCreateDeviceInterface`)  
`{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}`

### Other GUID

Low power epoch power setting (`PoRegisterPowerSettingCallback`)  
`{E1233993-EAA4-470F-9DE7-A351C1B6FB71}`

Raw PDO device class (`GUID_DEVCLASS_KEYBOARD`)  
`{4D36E96B-E325-11CE-BFC1-08002BE10318}`
