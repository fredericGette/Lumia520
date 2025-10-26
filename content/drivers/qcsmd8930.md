## Qcsmd8930.sys

Shared Memory Driver  
Manage the SMD channels of other drivers. These channels read and write data of the subsystems.  

There's no parameters in the registry.  

GUID of the ETW provider:  
`{2c5261dc-3e68-4919-98f9-aa5240a0f7f0}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMEM | qcsmem8930.sys | Shared Memory table driver |
| ? | qchipinfo8930.sys | Get components versions. Interface Class GUID : `{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}` |

GUID of the device interfaces:  
InterfaceClassGUID_00       : `{f9d15453-8335-434c-aa72-fcd925f135f3}`  
GUID_SMD_Lite_API_interface : `{07631ee5-21bd-455b-bd1f-f41b43f3a9bc}`   

Description of the functions exposed in the interface:
   * `InterfaceFunction_00` : Initializes SMD channels, including validation, smd_info_struct setup, flow control, callbacks, and smd_cmd calls, with "LOOPBACK" handling.
   * `InterfaceFunction_01` : Closes or deactivates SMD channels after lock operations and flag settings.
   * `InterfaceFunction_02` : Reads data from an SMD stream's receive buffer, managing synchronization, state, buffer, data copying, and event signaling.
   * `InterfaceFunction_03` : Writes data to an SMD stream's transmit buffer, handling synchronization, state, buffer, data copying, and event signaling; potentially for specialized writes.
   * `InterfaceFunction_04` : Primary function for writing data to an SMD stream's transmit buffer, similar to InterfaceFunction_03, managing synchronization, state, buffer, data copying, and event signaling.
   * `InterfaceFunction_05` : Another write function for an SMD stream's transmit buffer, similar to InterfaceFunction_04, but likely for larger or fragmented data, handling synchronization, state, buffer, data copying, and event signaling.
   * `InterfaceFunction_06` : Calculates available write buffer space in an SMD port's transmit buffer, performing state checks and pointer difference calculations.
   * `InterfaceFunction_07` : Determines available data for reading in an SMD stream's receive buffer by checking state, acquiring a lock, and comparing FIFO indices.
   * `InterfaceFunction_08` : Sets specific signal flags (e.g., DTR, CTS, CD, RI) within an SMD stream's transmit shared information structure, signaling changes to the remote processor via smd_event_send.
   * `InterfaceFunction_09` : Handles state changes, similar to InterfaceFunction_08, but for a different set of IOCTLs, using a parameter to indicate the specific state or action.

First, open a handle to the driver's device using CreateFile. Then, use DeviceIoControl to send IOCTL 0x22003. This IOCTL's input buffer should contain the desired SMD channel name (e.g., "SMD (MODEM)"). The driver's InterfaceFunction_00 will process this, associating the opened device handle with that specific SMD channel. Subsequent ReadFile and WriteFile calls on that same device handle will then operate on the configured SMD channel.  

You can read and write data from/to this driver using ReadFile and WriteFile after obtaining a device handle via CreateFile.  

For ReadFile, the OS sends a read IRP to the driver's EvtWdfIoQueueIoRead callback. This function retrieves the request, fetches data from the SMD FIFO, copies it to your provided buffer, and completes the IRP.  

For WriteFile, the OS sends a write IRP to the driver's EvtWdfIoQueueIoWrite callback. This function retrieves the request, copies your data from the input buffer to the SMD FIFO, and then completes the IRP.  

| Channel port name | Driver |
|-------------------|--------|
| RPCRPY_CNTL | qcipcrouter8930.sys |
| IPCRTR | qcipcrouter8930.sys |
| sys_mon | qcipcrouter8930.sys |
| DATA6_CNTL | qcipcrouter8930.sys |
| DATA7_CNTL | qcipcrouter8930.sys |
| DATA8_CNTL | qcipcrouter8930.sys |
| DATA9_CNTL | qcipcrouter8930.sys |
| DATA12_CNTL | qcipcrouter8930.sys |
| SSM_RTR | qcipcrouter8930.sys |
| DIAG | qcipcrouter8930.sys |
| DIAG_2 | qcipcrouter8930.sys |
| DIAG_CNTL | qcipcrouter8930.sys |
| sys_mon | qcadsp8930.sys |
| DATA5_CNTL | qcqmux8930.sys |
| DATA13_CNTL | qcqmux8930.sys |
| DIAG | qcdiagrouter8930.sys |
| DIAG_CNTL | qcdiagrouter8930.sys |
| DATA14_CNTL | qcdiagrouter8930.sys |
| APPS_RIVA_DATA | qcdiagrouter8930.sys |
| APPS_RIVA_CTRL | qcdiagrouter8930.sys |
| apr_audio_svc | qcq6ad8930.sys |
| apr_apps2 | qcq6ad8930.sys |
| APPS_FM | qcfmtransport8930.sys |
| APPS_RIVA_BT_CMD | qcbluetooth8930.sys |
| APPS_RIVA_BT_ACL | qcbluetooth8930.sys |
| WLAN_CTRL | qcwlan8930.sys |

Internal Ioctl:  
    - **`0x22003`**: Initializes/configures a communication channel, performs input validation (including a "LOOPBACK" string check), acquires a lock, and calls `InterfaceFunction_00`. Input buffer size 28  
    - **`0x22007`**: Appears to be a close/deactivation operation, acquiring/releasing locks and calling `InterfaceFunction_01`.  
    - **`0x2200B`**: Sets port/channel parameters, retrieves input buffer, validates, acquires a lock, and updates `SMD_PORT_CONTEXT` fields. Input buffer size 16  
    - **`0x2200F`**: Configures an SMD port by setting two 4-byte values within the SMD_PORT_CONTEXT structure at field_10 and field_14. It requires an 8-byte input buffer    
    - **`0x22013`, `0x22017`, `0x2201B`**: Involve forwarding requests to I/O queues and enqueuing work items for asynchronous operations.  
    - **`0x2201F`, `0x22023`, `0x2202B`**: Related to setting modem states, calling `InterfaceFunction_08`.  
    - **`0x2202F` (and related `0x2202F`, `0x22033`, `0x22053`, `0x22057`)**: Related to state changes, calling `InterfaceFunction_09`.  

