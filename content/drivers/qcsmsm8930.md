## Qcsmsm8930.sys

Shared Memory State Machine Driver  
Read, write and watch a memory region containing the state of the subsystems.  
It calls qcmem8930.sys to get the address of this memory region, and provides some IOCTL to read and write in it. Moreover, it sets a interrupt handler to be notified when a state is updated by a subsystem.  
When the state of a subsystem changes, it notifies the RPE client listening to this subsystem.  

It contains the same "hack" that the one indicated here: https://github.com/freexperia/android_kernel_semc_msm7x30/blob/03025f007e8f0ccdd51ea3bced3999c2d6249010/arch/arm/mach-msm/smd.c#L375  
So the address of the GPIO_40 is hardcoded in the driver : 0x801284  

There's no interresting parameters in the registry.  

GUID of the ETW provider:  
`{61485ed3-92fb-436b-b828-8a57815e1826}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMEM | qcsmem8930.sys | Shared Memory table driver |

### IOCTL 0x8C1F2004

This IOCTL is sent by Qcsmsm8930.sys to qcchipinfo8930.sys 

| Property | Value |
|----------|-------|
| Device | 0xc1f |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

### IOCTL 0x8C1F2008

This IOCTL is sent by Qcsmsm8930.sys to qcchipinfo8930.sys 

| Property | Value |
|----------|-------|
| Device | 0xc1f |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


