## QcBluetooth8930.sys

This is the bus driver.  
It is started by the Qcwcn8930 driver.  
The _EvtDevicePrepareHardware_ of the driver reads the file C:\DPP\QCOM\BT.PROVISION  
This binary file contains the address of the bluetooth device.  
Example of content (the bluetooth address is 78-92-3E-C7-7B-53):
| BYTE 0 | BYTE 1 | BYTE 2 | BYTE 3 | BYTE 4 | BYTE 5 | BYTE 6 | BYTE 7 |
|--------|--------|--------|--------|--------|--------|--------|--------|
| 01 | 06 | 78 | 92 | 3E | C7 | 7B | 53 |

Then it sends the [HCI Vendor Specific command SET BR_ADDR](#hci-vs-set-bd-addr) to set the bluetooth address of the device.  

Registries of the bus driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcbluetooth`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM01E0\3&ddcf83e&0&1`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0093`  

| Registry value | value | comment |
|----------------|-------|---------|
| BtOnOff | 0x0=off or 0x1=on | Persists the state of the driver. |

GUID Bus type:  
`4D36E978-E325-11CE-BFC1-08002BE10318` (Serial Device)

GUID of the interface:  
`2388B968-8AC1-401F-9C4C-11713C110F39`  
`B53A9DB7-1343-4C7F-B7BC-251B03DD8E34`

GUID of the ETW provider:  
`C484A08D-41CE-4CD6-AF73-06F987827ACE`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | qcsmd8930.sys | Shared Memory Device |

The bus driver creates a child device _Physical Device Object (PDO)_ with the following properties:  
- CompatibleID : `MS_BTHX_BTHMINI`
- DeviceType : FILE_DEVICE_BUS_EXTENDER
- DeviceLocation : `Serial HCI Bus - Bluetooth Function`
- DeviceDescription : `SerialHciBus_01`
- HardwareID : `SystemBusQc\SMD_BT`
- ClassGUID : E0CBF06C-CD8B-4647-BB8A-263B43F0F974 (Bluetooth)

This child device forwards all the IOCTL_BTHX IoCtl requests to its parent device.

Registry of the child device:  
`HKLM\System\CurrentControlSet\Enum\SystemBusQc\SMD_BT\4&315a27b&0&4097`


### internal IOCTL 0x22003

This IOCTL is sent by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |



| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Link to a SMD channel ? | \Device\SMD | 28 | 0 |

Content of the input buffer:  
| Bytes 00-03 | Bytes 04-07 | Bytes 08-0B | Bytes 0C-0F | Bytes 10-13 | Bytes 14-17 | Bytes 18-1B |
|-------------|-------------|-------------|-------------|-------------|-------------|-------------|
| pointer to a string containing the name of the SMD channel | 06 00 00 00 | 11 00 00 00 | 00 20 00 00 | 00 00 00 00 | 00 00 00 00 | 00 00 00 00 |

SMD channels:  
- `APPS_RIVA_BT_CMD`  send HCI Command packets, receive HCI Event packets.  
- `APPS_RIVA_BT_ACL`  send/receive HCI ACL packets.  

### internal IOCTL 0x22007

This IOCTL is sent by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Release a SMD channel ? | \Device\SMD | 0 | 0 |

### IOCTL 0x2A8008

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x2 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| Query the "BtOnOff" state of the Bluetooth device | 0 | 1 |

Content of the output buffer:  
| Byte 00 |
|---------|
| 0=off 1=on | 

	
### IOCTL 0x2A8004

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x1 |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Switch BT on/off | 1 | 0 |

Content of the input buffer:  
| Byte 00 |
|---------|
| 0=off 1=on | 


### IOCTL 0x410403

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x100 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| IOCTL_BTHX_GET_VERSION | 0 | 4 |
	
### IOCTL 0x410407

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x101 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| IOCTL_BTHX_SET_VERSION | 4 | 0 |

Notes: do nothing  

### IOCTL 0x41040B	

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x102 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| IOCTL_BTHX_QUERY_CAPABILITIES | 0 | 16 |
	
### IOCTL 0x41040F	

This IOCTL is processed by QcBluetooth8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x103 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| IOCTL_BTHX_WRITE_HCI | >= 6 | 4 |

Send a HCI Command/ACL packet to the subsystem.  
		
### IOCTL 0x410413	

This IOCTL is processed by QcBluetooth8930.sys 

| Property | Value |
|----------|-------|
| Device | 0x41 |
| Function | 0x104 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| IOCTL_BTHX_READ_HCI | 4 | >= 6 |

Read a HCI Event/ACL packet from the subsystem.  

