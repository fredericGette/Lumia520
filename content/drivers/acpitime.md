## acpitime.sys

`acpitime.sys` provides access
to the ACPI Real-Time Clock (RTC) and ACPI wake alarm hardware on UEFI/ACPI
platforms. It is implemented as a WDF (Windows Driver Framework) FDO
(Function Driver Object) that sits on top of `acpi.sys` in the device stack.

The driver exposes a device interface identified by `GUID_DEVICE_ACPI_TIME`
and services four DeviceIoControl codes. Internally it
communicates downward to the ACPI driver via `IOCTL_ACPI_EVAL_METHOD`
to evaluate ACPI control methods on the firmware device node.

> [!NOTE]
> DeviceIoControl can only be called from kernel mode.  
> On Lumia 520, the capabilities indicate get/set RTC only. **There's no wake alarm support.**

ACPI time capabilities flag of Lumia 520: `0x4 Get/Set real time supported (_GRT/_SRT)` (see [ACPI _GCP](https://uefi.org/htmlspecs/ACPI_Spec_6_4_html/09_ACPI-Defined_Devices_and_Device-Specific_Objects/ACPIdefined_Devices_and_DeviceSpecificObjects.html#gcp-get-capability))

GUID_DEVICE_ACPI_TIME	`{97f99bf6-4497-4f18-bb22-4b9fb2fbef9c}`

Symbolic link: `\GLOBAL??\ACPI#ACPI000E#2&daba3ff&0#{97f99bf6-4497-4f18-bb22-4b9fb2fbef9c}`

---

### IOCTL_ACPITIME_GET_REALTIME — `0x294210`

| Property   | Value                                             |
|------------|---------------------------------------------------|
| DeviceType | `0xA5`                                            |
| Function   | `0x84`                                            |
| Method     | `METHOD_BUFFERED`                                 |
| Access     | `FILE_READ_ACCESS`                                |
| Input      | None                                              |
| Output     | `TIME_FIELDS` (16 bytes)                          |
| Handler    | `WaHandleAcpiGetRealTime`                         |
| ACPI method| `_GRT` (Get Real Time)                           |

Reads the current RTC time from the ACPI firmware. Output is a standard
WDM `TIME_FIELDS` structure (8 × USHORT: Year, Month, Day, Hour, Minute,
Second, Milliseconds, Weekday).

---

### IOCTL_ACPITIME_SET_REALTIME — `0x298214`

| Property   | Value                                             |
|------------|---------------------------------------------------|
| DeviceType | `0xA6`                                            |
| Function   | `0x85`                                            |
| Method     | `METHOD_BUFFERED`                                 |
| Access     | `FILE_READ_ACCESS`                                |
| Input      | `TIME_FIELDS` (16 bytes)                          |
| Output     | None                                              |
| Handler    | `WaHandleAcpiSetRealTime`                         |
| ACPI method| `_SRT` (Set Real Time)                           |

Writes a new time to the RTC via the ACPI firmware.

---

### IOCTL_ACPITIME_WAKE_ALARM_0 — `0x29C208`
### IOCTL_ACPITIME_WAKE_ALARM_1 — `0x29C20C`

| Property   | Value                                             |
|------------|---------------------------------------------------|
| DeviceType | `0xA7`                                            |
| Function   | `0x82` / `0x83`                                   |
| Method     | `METHOD_BUFFERED`                                 |
| Access     | `FILE_ANY_ACCESS`                                 |
| Input      | `WA_ALARM_INPUT` (8 bytes, see below)             |
| Output     | `WA_ALARM_OUTPUT` (8 bytes, see below)            |
| Handler    | `WaHandleWakeAlarmControl`                        |
| ACPI method| `_TIV` / `_TIP` (Timer Interrupt Value/Period)   |

Query the current state of a wake alarm. Two alarm indices are supported:

| Index | IOCTL      | ACPI Method | Description                        |
|-------|------------|-------------|------------------------------------|
| 0     | `0x29C208` | `_TIV`      | Classic RTC alarm / ACPI RTC wake  |
| 1     | `0x29C20C` | `_TIP`      | UEFI/secondary periodic alarm      |

```c
// Input buffer (8 bytes)
typedef struct _WA_ALARM_INPUT {
    ULONG timer_index;  // 0 or 1 — alarm index
    ULONG status;       // for set ops: -1 = disarm, 0+ = arm/value
                        // for query:   pass 0
} WA_ALARM_INPUT;

// Output buffer (8 bytes)
typedef struct _WA_ALARM_OUTPUT {
    ULONG timer_index;  // echoed from input
    ULONG alarm_state;  // 0xFFFFFFFF = alarm has fired / interrupt pending
                        // other      = alarm not expired or not armed
} WA_ALARM_OUTPUT;
```
