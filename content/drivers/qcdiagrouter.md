## Qcdiagrouter8930.sys

Qualcomm DIAG router.  
Allows to send command to subsystems, received log messages or events from subsystems.  Usually used with QPST and QXDM applications.  


Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcdiagrouter`:  
| Registry value | value | comment |
|----------------|-------|---------|
| TransportType | 0 | Communication channel. 0=TCP, 1=UBS, 2=UART |
| ServerName | 1.2.3.4 | With TransportType TCP. IP address of the server (machine where QPST is running for example). |
| TCPPort | 2500 | With TransportType TCP. Port of the server. |
| HostAsName | 0 | Boolean. With TransportType TCP. When FALSE ServerName and TCPPort are used. |
