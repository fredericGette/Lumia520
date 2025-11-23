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
