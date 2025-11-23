## Qcdiagrouter8930.sys

Qualcomm DIAG protocol router.  
Allows to send command to subsystems, received log messages or events from subsystems.  Usually used with QPST and QXDM applications.  

Device name : `\Device\DiagRouter`  
Symbolic link : `\DosDevices\DiagRouter`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcdiagrouter`:  
| Registry value | value | comment |
|----------------|-------|---------|
| TransportType | 0 | Communication channel. 0=TCP, 1=USB, 2=UART |
| ServerName | 1.2.3.4 | With TransportType TCP. IP address of the server (machine where QPST is running for example). |
| TCPPort | 2500 | With TransportType TCP. Port of the server. |
| HostAsName | 0 | Boolean. With TransportType TCP. When FALSE ServerName and TCPPort are used. |

Interface Class GUID:
`{5ff73d59-fab7-456e-884e-d5386cd5f581}`

GUID of the ETW provider:  
`{9cba380d-42ba-45db-94f0-ac310885ce4e}`

It communicates with the following devices:  
| Device | Driver | Interface GUID | Comment |
|--------|--------|----------------|---------|
| `\Device\DiagCSI` | ? | `{23ccade6-34e8-42e4-8845-99411146dc22}` | ? |
| `\Device\USB_DIAG` | ? | `{39ab5403-6551-4dfe-a22c-6cc6f4ed2fd0}` | ? |
| | qcsmd8930.sys | `{f9d15453-8335-434c-aa72-fcd925f135f3}` | Shared Memory Driver |
| `\??\QCOM_ChipInfo` | qchipinfo8930.sys | `{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}` | ? |
| `\Device\RESOURCE_HUB\%08X%08X` or `\DosDevices\COM5` | | `{86e0d1e0-8089-11d0-9ce4-08003e301f73}` | UART Driver |

SMD channel names:  
| Name | Channel ID |
|------|------------|
| `DIAG` | 1 |
| `APPS_RIVA_DATA` | 6 |
| `DIAG_CNTL` | 1 |
| `APPS_RIVA_CTRL` | 6 |

IOCTL sent to `\??\QCOM_ChipInfo`:  
- **`0x8C1F2014`**  
  - inputbuffer length 0
  - outputbuffer length 4 (contains one of these values: 0x16, 0x1A, 0x1E, 0x20, 0x22)  

IOCTL sent to `\Device\USB_DIAG`:  
- **`0x808520C0`**  
  - inputbuffer length 8

 IOCTL sent to UART device:  
- **`0x1B0064`**  
  -	inputbuffer length 16 :	0xFFFFFFF7 0xFFFFFF7F	0x00000000 0x00000000
	- outputbuffer length 0	
- **`0x1B000C`**  
  -	inputbuffer length 3 : 0x00 0x00 0x08
- **`0x1B0004`**  
  -	inputbuffer length 4 : 0x1C200 // 115200 bauds ?
- **`0x1B001C`**  
  -	inputbuffer length 20 : 0x00000005 0x00000000	0x00000000 0x00000000	0x000000C8

Received IOCTL:  
- **`0x80082400`**  
  -	InputBufferLength = 4. Allocate 3 Requests
- **`0x80082404`**  
  -	InputBufferLength = min 16. The size must be equals to 3 + the 16bits value at index 4 
  -	OutputBufferLength = 0
  -	Calls called_by_ioctl_0x80082404. Add an object in the linked list memoryPool_24bytes.
- **`0x80082408`**  
  -	OutputBufferLength = 2.	Contains DIAGROUTER_DEVICE_CONTEXT->field_168 + 1
- **`0x8008240C`**  DIAGCMD_CLNT_DCIRSPSEND ?
  -	InputBufferLength = max 4096. 00 = 0x93. Calls called_by_ioctl_0x8008240C_and_0x80082410 with third parameter = 21.  
- **`0x80082410`**  DIAGCMD_CLNT_DCIRSPSEND ?
  -	InputBufferLength = max 4096. Calls called_by_ioctl_0x8008240C_and_0x80082410 with third parameter = 20.

Received internal IOCTL:
- **`0x80082450`**  
  -	InputBufferLength = 4. 00 = 0x4B or 0x80.
  -	OutputBufferLength = 4.	00 = 0 or 1 or 2 or 3.
- **`0x80082454`**  
  -	InputBufferLength = min 8. 00 = 0x4B or 0x80 or 0x93 
  -	OutputBufferLength = 0
- **`0x80082458`**  
  -	InputBufferLength = 0. Create and enqueue a workitem DIAGCMD_DIAGCSI ?
  -	OutputBufferLength = 0
- **`0x8008245D`**  
  -	DIAGCMD_DIAGCSI_MSKCFG_WRK_CONTEXT->field_0 = 0. Create and enqueue a workitem DIAGCMD_DIAGCSI_MSKCFG ?
- **`0x80082461`**  
  -	DIAGCMD_DIAGCSI_MSKCFG_WRK_CONTEXT->field_0 = 1. Create and enqueue a workitem DIAGCMD_DIAGCSI_MSKCFG ?
