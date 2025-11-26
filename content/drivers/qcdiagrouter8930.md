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

Example of Bluetooth logs (from the WCN SubSytem):
```
LOG          [0x1365]               BT HCI Command                          01:01:24.480        Length: 0003                                                      0x03 0C 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                PFAL_DBG.c  00272  MBAAAANAZW1150088                      0x79 00 00 00 00 1C 00 FA 2C 00 00 00 10 01 04 00 01 00 00 00 4D 42 41 41 41 41 4E 41 5A 57 31 31 35 30 30 38 38 00 50 46 41 4C 5F 44 42 47 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                PFAL_DBG.c  00272  LLM Pre Reset called                   0x79 00 00 00 00 5C 00 FA 2C 00 00 00 10 01 04 00 01 00 00 00 4C 4C 4D 20 50 72 65 20 52 65 73 65 74 20 63 61 6C 6C 65 64 00 50 46 41 4C 5F 44 42 47 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                PFAL_DBG.c  00272  HCI pre reset complete                 0x79 00 00 00 00 64 00 FA 2C 00 00 00 10 01 04 00 01 00 00 00 48 43 49 20 70 72 65 20 72 65 73 65 74 20 63 6F 6D 70 6C 65 74 65 00 50 46 41 4C 5F 44 42 47 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                 riva_pm.c  01399  PM_SetPowerMode Mode = 0x10 Override = 0x00x79 00 02 00 00 68 00 FA 2C 00 00 00 77 05 04 00 01 00 00 00 10 00 00 00 00 00 00 00 50 4D 5F 53 65 74 50 6F 77 65 72 4D 6F 64 65 20 4D 6F 64 65 20 3D 20 30 78 25 58 20 4F 76 65 72 72 69 64 65 20 3D 20 30 78 25 58 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                 riva_pm.c  01734  PM_resolveResources: WLAN:0xE0009 BT:0x1 FM:0x00x79 00 03 00 00 6C 00 FA 2C 00 00 00 C6 06 04 00 01 00 00 00 09 00 0E 00 01 00 00 00 00 00 00 00 50 4D 5F 72 65 73 6F 6C 76 65 52 65 73 6F 75 72 63 65 73 3A 20 57 4C 41 4E 3A 30 78 25 58 20 42 54 3A 30 78 25 58 20 46 4D 3A 30 78 25 58 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.480                 riva_pm.c  02733  PM_resolveResourceSleepEnable:Prev:0 Curr:00x79 00 02 00 00 70 00 FA 2C 00 00 00 AD 0A 04 00 01 00 00 00 00 00 00 00 00 00 00 00 50 4D 5F 72 65 73 6F 6C 76 65 52 65 73 6F 75 72 63 65 53 6C 65 65 70 45 6E 61 62 6C 65 3A 50 72 65 76 3A 25 64 20 43 75 72 72 3A 25 64 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.481                 riva_pm.c  02599  icbarb_issue_request Ab=491133600, Ib=8683350000x79 00 02 00 00 8C 00 FA 2C 00 00 00 27 0A 04 00 01 00 00 00 A0 1A 46 1D 98 BD C1 33 69 63 62 61 72 62 5F 69 73 73 75 65 5F 72 65 71 75 65 73 74 20 41 62 3D 25 64 2C 20 49 62 3D 25 64 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.505                PFAL_DBG.c  00272  LLM Reset called                       0x79 00 00 00 00 58 14 FA 2C 00 00 00 10 01 04 00 01 00 00 00 4C 4C 4D 20 52 65 73 65 74 20 63 61 6C 6C 65 64 00 50 46 41 4C 5F 44 42 47 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.505                 riva_pm.c  01399  PM_SetPowerMode Mode = 0xD Override = 0x00x79 00 02 00 00 6C 14 FA 2C 00 00 00 77 05 04 00 01 00 00 00 0D 00 00 00 00 00 00 00 50 4D 5F 53 65 74 50 6F 77 65 72 4D 6F 64 65 20 4D 6F 64 65 20 3D 20 30 78 25 58 20 4F 76 65 72 72 69 64 65 20 3D 20 30 78 25 58 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.505                 riva_pm.c  01734  PM_resolveResources: WLAN:0xE0009 BT:0x0 FM:0x00x79 00 03 00 00 70 14 FA 2C 00 00 00 C6 06 04 00 01 00 00 00 09 00 0E 00 00 00 00 00 00 00 00 00 50 4D 5F 72 65 73 6F 6C 76 65 52 65 73 6F 75 72 63 65 73 3A 20 57 4C 41 4E 3A 30 78 25 58 20 42 54 3A 30 78 25 58 20 46 4D 3A 30 78 25 58 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.505                 riva_pm.c  02733  PM_resolveResourceSleepEnable:Prev:0 Curr:00x79 00 02 00 00 70 14 FA 2C 00 00 00 AD 0A 04 00 01 00 00 00 00 00 00 00 00 00 00 00 50 4D 5F 72 65 73 6F 6C 76 65 52 65 73 6F 75 72 63 65 53 6C 65 65 70 45 6E 61 62 6C 65 3A 50 72 65 76 3A 25 64 20 43 75 72 72 3A 25 64 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.506                 riva_pm.c  02599  icbarb_issue_request Ab=489500000, Ib=8581250000x79 00 02 00 00 8C 14 FA 2C 00 00 00 27 0A 04 00 01 00 00 00 60 2D 2D 1D C8 F2 25 33 69 63 62 61 72 62 5F 69 73 73 75 65 5F 72 65 71 75 65 73 74 20 41 62 3D 25 64 2C 20 49 62 3D 25 64 00 72 69 76 61 5F 70 6D 2E 63 00
MSG          [00004/00]             Blue Tooth/Low                          01:01:24.506                PFAL_DBG.c  00272  HCI reset complete                     0x79 00 00 00 00 A8 14 FA 2C 00 00 00 10 01 04 00 01 00 00 00 48 43 49 20 72 65 73 65 74 20 63 6F 6D 70 6C 65 74 65 00 50 46 41 4C 5F 44 42 47 2E 63 00
LOG          [0x1366]               BT HCI Event                            01:01:24.506        Length: 0006                                                      0x0E 04 01 03 0C 00
```
