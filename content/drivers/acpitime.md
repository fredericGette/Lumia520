## acpitime.sys

`acpitime.sys` is a Windows kernel-mode driver that provides user-mode access
to the ACPI Real-Time Clock (RTC) and ACPI wake alarm hardware on UEFI/ACPI
platforms. It is implemented as a WDF (Windows Driver Framework) FDO
(Function Driver Object) that sits on top of `acpi.sys` in the device stack.

The driver exposes a device interface identified by `GUID_DEVICE_ACPI_TIME`
and services four DeviceIoControl codes. Internally it
communicates downward to the ACPI driver via `IOCTL_ACPI_EVAL_METHOD`
to evaluate ACPI control methods on the firmware device node.

> [!NOTE]
> DeviceIoControl can only be called from kernel mode.  
> On Lumia 520, the capabilities reported only get/set RTC. There's no wake alarm support.

Capabilities flag: `0x4 Get/Set real time supported (_GRT/_SRT)`

GUID_DEVICE_ACPI_TIME	`{97f99bf6-4497-4f18-bb22-4b9fb2fbef9c}`

Symbolic link on Lumia 520: `\GLOBAL??\ACPI#ACPI000E#2&daba3ff&0#{97f99bf6-4497-4f18-bb22-4b9fb2fbef9c}`
