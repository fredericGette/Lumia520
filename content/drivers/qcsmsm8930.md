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
| ? | qchipinfo8930.sys | ? |

### IOCTL 0x8C1F2004

This IOCTL is sent by Qcsmsm8930.sys to qcchipinfo8930.sys 

| Property | Value |
|----------|-------|
| Device | 0xc1f |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| ? | ? | 0 | 4 |

Seems to return a part of the version of the RIVA hardware.  

### IOCTL 0x8C1F2008

This IOCTL is sent by Qcsmsm8930.sys to qcchipinfo8930.sys 

| Property | Value |
|----------|-------|
| Device | 0xc1f |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| ? | ? | 0 | 4 |

Seems to return a part of the version of the RIVA hardware.  

### IOCTL 0x32000

This IOCTL is received by qcsmsm8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name |  InputBuffer size | OutputBuffer Size |
|------|-------------------|--------------------|
| ? | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | smsm_state_item (example SMSM_STATE_WCN) |
| 04-07 | 40 00 00 00 | clear_mask (example: SMSM_RESET) |
| 08-0B | 40 00 00 00 | set_mask (example: SMSM_RESET) |

This IOCTL calls the function `smsm_change_state(enum smsm_state_item item, uint32_t clear_mask, uint32_t set_mask)` with the 3 DWORD of the Inputbuffer as parameters.

### IOCTL 0x32004

This IOCTL is received by qcsmsm8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name |  InputBuffer size | OutputBuffer Size |
|------|-------------------|--------------------|
| ? | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | smsm_state_item (example SMSM_STATE_WCN) |

This IOCTL calls the function `smsm_state_get(enum smsm_state_item item)` and the Inputbuffer is the parameter of the function.  
The state is returned in the `information` returned by the IOCTL.


### Internal IOCTL 0x32008

This IOCTL is received internally by qcsmsm8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name |  InputBuffer size | OutputBuffer Size |
|------|-------------------|--------------------|
| ? | 0 | 4 |

The Outputbuffer contains the address of the function `FuncSmsmReset(uint32_t clear_mask)`.   
This function cleasr some bits of the state of a subsystem (which one ?) with the parameter `clear_mask`, then it sets the bits corresponding to SMSM_RESET.  

### IOCTL 0x3200C

This IOCTL is received by qcsmsm8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name |  InputBuffer size | OutputBuffer Size |
|------|-------------------|--------------------|
| ? | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | smsm_state_item (example SMSM_STATE_WCN) |
| 04-07 | 40 00 00 00 | state_mask (example: SMSM_RESET) |
| 08-0B | 40 00 00 00 | expected_state (example: SMSM_RESET) |

This IOCTL calls the function `smsm_state_get(enum smsm_state_item item)` and apply the `state_mask` on the state obtained.  
While the difference is different from the `expected_state`, the IOTCL won' return but is marked as _cancelable_. 


### Internal IOCTL 0x32010

This IOCTL is received internally by qcsmsm8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

### IOCTL 0x32C004

This IOCTL is sent by qcsmsm8930.sys to ?

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

### IOCTL 0x42000

This IOCTL is sent by qcsmsm8930.sys to qcsmem8930.sys

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| ? | \Device\SMEM | 0 | 4 |

The expected value contained in the outputbuffer is 0x00000034  

