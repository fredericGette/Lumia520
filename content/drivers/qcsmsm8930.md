## Qcsmsm8930.sys

Shared Memory State Machine Driver  
Read, write and watch a memory region containing the state of the subsystems.  
It calls qcsmem8930.sys to get the address of this memory region, and provides some IOCTL to read and write in it. Moreover, it sets an interrupt handler to be notified when a state is updated by a subsystem.  
When the state of a subsystem changes, it notifies the RPE client listening to this subsystem.  
The signification of each bits of a state is indicated here: https://github.com/drakaz/cm-kernel/blob/f1215cb1e5e7090e9688ae8d1ce7eb1c5ed1c7ce/drivers/dpram/smd_private.h#L98

It contains the same "hack" that the one indicated here: https://github.com/freexperia/android_kernel_semc_msm7x30/blob/03025f007e8f0ccdd51ea3bced3999c2d6249010/arch/arm/mach-msm/smd.c#L375  
So the address of the GPIO_40 is hardcoded in the driver : 0x801284  
This hack is applied when the OutputBuffer of IOCTL 0x8C1F2008 is 0x57 and OutputBuffer of IOCTL 0x8C1F2004 is less than 0x20000.  

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
|------|-------------|------------------|-------------------|
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
|------|-------------|------------------|-------------------|
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
|------|-------------------|-------------------|
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
|------|-------------------|-------------------|
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
|------|-------------------|-------------------|
| ? | 0 | 4 |

The Outputbuffer contains the address of the function `FuncSmsmReset(uint32_t clear_mask)`.   
This function clears some bits of the state of a subsystem (which one ?) with the parameter `clear_mask`, then it sets the bits corresponding to SMSM_RESET.  

### IOCTL 0x3200C

This IOCTL is received by qcsmsm8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name |  InputBuffer size | OutputBuffer Size |
|------|-------------------|-------------------|
| ? | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | smsm_state_item (example SMSM_STATE_WCN) |
| 04-07 | 40 00 00 00 | state_mask (example: SMSM_RESET) |
| 08-0B | 40 00 00 00 | expected_state (example: SMSM_RESET) |

This IOCTL calls the function `smsm_state_get(enum smsm_state_item item)` and apply the `state_mask` on the state obtained.  
While the difference is different from the `expected_state`, the IOTCL won't return but is marked as _cancelable_. 


### Internal IOCTL 0x32010

This IOCTL is received internally by qcsmsm8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name |  InputBuffer size | OutputBuffer Size |
|------|-------------------|-------------------|
| ? | 0 | 4 |

The Outputbuffer contains the address of the function `uint32_t smsm_get_state(enum smsm_state_item item)`. 

### IOCTL 0x32C004

This IOCTL is sent by qcsmsm8930.sys to ?

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name |  InputBuffer size | OutputBuffer Size |
|------|-------------------|-------------------|
| ? | 8 | 20 or more when the return status is STATUS_BUFFER_OVERFLOW |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | AeiBINTR | ? |

Ouputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | BoeA | ? |
| 04-07 | ? | ? |
| 08-0B | ? | A size which must be >=4 |
| 0C-0F | ? | Required size of the Outputbuffer |
| 10-13 | 01 00 00 00 | A Boolean |
| ... | ... | ... |

Unknown function.

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

Unknown function.  
The expected value contained in the outputbuffer is 0x00000034  

### Interface GUID

qcsmsm8930 Interface Class GUID  
`{1c90923a-df5c-4761-9fd0-835b80f5281d}`

qcchipinfo8930 Interface Class GUID    
`{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}`

RPE Interface Class GUID  
`{59752ed7-b9d5-4121-818d-c69f1e667015}`

### Other GUID

SMSM (MODEM)   
`{1C90923A-DF5C-4761-9FD0-835B80F5281D}`

SMSM (RIVA)  
`{3AABE343-4EA2-43F8-8404-8A4A01088DCF}`

Unknown RPE client GUID  
`{936DC601-5530-4B82-9D2A-72A488BEC7C1}`

Unkown RPE client GUID  
`{93367D0F-35CE-4EC4-8E38-BB33030C58B2}`
