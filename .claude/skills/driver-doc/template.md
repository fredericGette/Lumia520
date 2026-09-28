## <Drivername>.sys

<One-line role of the driver (e.g. "Shared Memory Driver").>  
<2–5 lines: what it does, who starts/uses it, which subsystem it serves, notable files it reads (e.g. `C:\DPP\QCOM\BT.PROVISION`).>  

Device name : `\Device\<NAME>`  
Symbolic link : `\DosDevices\<NAME>`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\<QCOMxxxx>\<instance>`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters`:  
| Registry value | value | comment |
|----------------|-------|---------|
| <ValueName> | <default/example> | <meaning, type, default> |

<or: "There's no parameters in the registry.">

GUID of the ETW provider:  
`{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMEM | qcsmem8930.sys | Shared Memory table driver |
| ? | qcchipinfo8930.sys | ? |

<Free-form sections as needed: hardware registers + algorithm (numbered steps), memory resources, SMD channels table, provisioning file format, internal function table, etc.>

---

### IOCTL 0x<CODE> — <IOCTL_NAME if known>

This IOCTL is processed by <Drivername>.sys  
<or: This IOCTL is sent by <Drivername>.sys to <target>.sys>

| Property | Value |
|----------|-------|
| Device | 0x<dev> |
| Function | 0x<fn> |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| <IOCTL_NAME or purpose or ?> | <\Device\X — only for sent IOCTLs> | <n> | <n> |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | <meaning> |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | <meaning> |

<Prose: what the handler does, side effects, NTSTATUS values, observed callers.>

---

### Interface GUID

<Drivername> Interface Class GUID  
`{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}`

### Other GUID

<Label>  
`{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}`
