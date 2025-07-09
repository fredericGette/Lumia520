## Qccdi8930.sys

As indicated in the binary, this is the _Crash dump injectory driver that interfaces with the Windows crash dump driver and is responsible for generating crash dumps_

It maintains a list of memory regions to include in the memory dump in case of crash. The address of some of these memory regions are hardcoded in the driver, whereas some other memory regions are found by querying other drivers with their driver-defined interface. 

All the log messages a traced in a memory region named `TRACE_LOG`.

Registry driver's Parameters:  
| Registry value | value | comment |
|----------------|-------|---------|
|ExpectedCrashDumpSegmentSize | | ULong (default=0xA00000, 10MB) |
|UserDefinedCrashDumpSegmentSize | | ULong (default=0) |
|UserDefinedCrashDumpSegmentAddress | | ULong (default=0x00000000) |

Crash dump cookies used in Offline Dump:  
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CrashControl\SVVariables`  
| Registry value | value | comment |
|----------------|-------|---------|
| WpMemoryCaptureModeAddr | | ULong | 
| WpSvLegacyFlagAddr | | |

### internal IOCTL 0xC3514018

This IOCTL is sent by qccdi8930.sys to qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x351 |
| Function | 0x6 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device symbolic link name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Configure the watchdog bark FIQ | \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68} | 24 | 24 |

#### Command 0xC02 "Configure the watchdog bark FIQ"

InputBuffer:  
| Position | Value | Comment |
|----------|-------|---------|
| Bytes 00-03 | 18 00 00 00 | Packet size ? |
| Bytes 04-07 | 10 00 00 00 | Packet type ? |
| Bytes 08-0B | 00 00 00 00 | ? |
| Bytes 0C-0F | 02 0C 00 00 | Command |
| Bytes 10-13 | ?? ?? ?? ?? | physical address of the watchdog bark FIQ handler ? |
| Bytes 14-18 | 00 10 00 00 | ? |

OutputBuffer:  
| Position | Value | Comment |
|----------|-------|---------|
| Bytes 00-03 | 18 00 00 00 | Packet size ? |
| Bytes 04-07 | 10 00 00 00 | Packet type ? |
| Bytes 08-0B | 01 00 00 00 | 1 = success |
| Bytes 0C-0F | 02 0C 00 00 | Command |
| Bytes 10-13 | ?? ?? ?? ?? | physical address of the watchdog bark FIQ handler ? |
| Bytes 14-18 | 00 10 00 00 | ? |

### Interface GUID

CDDriver interface class   
`{933B95C6-F9CF-4424-A9F8-F497F760AEE5}`

RPENotifier interface class     
`{B28C6F-F696-4580-ACB5-BF16C614B1C2}`

PIL interface class     
`{20E0709D-AF59-4CE8-9D91-39E11B4C0231}`

SCM interface class     
`{41C66D2A-A9F1-40CA-A329-AE096C03EE68}`

CDI interface class  
`{6EA2C81E-AC5E-4583-8767-37D4DBFBD6AB}`

CDD driver-defined interface    
`{8BCB35C2-CB20-44E4-9A1E-33A016856CBF}`

Unknown   
`{93367D0F-35CE-4EC4-8E38-BB33030C58B2}`

### Memory region GUID

TRACE_LOG  
`{87d53509-c8cf-4528-b6e5-07839265cd61}`

AMSS (modem SW region)     
`{936dc601-5530-4b82-9d2a-72a488bec7c1}`

modem FW region  
`{BA58766D-ABF2-4402-88D7-90AB243F6C77}`

ADSP  
`{d58464d3-5b28-4ea6-a2e2-e8e57c5c69b8}`

RPM  
`{7f8e50dc-fad4-4a31-a243-3ab83708e49f}`

SYS_IMEM  
`{adf3b53c-6657-4d83-83da-a5f3b2544f3c}`

MDSP_RAM  
`{7d72d7e9-67df-48b3-8f07-be28c12009b5}`

QDSS_ETB_REG   
`{4f4f1970-8a20-40e2-b60b-99a52bb26700}`

MISC_REG   
`{d0be3202-f9fc-4c07-bf21-48799499a4d6}`

AP_REG   
`{ab3a051f-ef0b-4a5f-a79a-80c243ba0848}`

WCN   
`{93367d0f-35ce-4ec4-8e38-bb33030c58b2}`

BAMMUX   
`{cccb7664-4951-40c3-8eb1-fda3964a4479}`

SMD (MODEM)  
`{f9d15453-8335-434c-aa72-fcd925f135f3}`

SMD (RIVA)   
`{d30f94e9-9c90-4ed5-ae04-9266277c4721}`

SMSM (MODEM)   
`{1c90923a-df5c-4761-9fd0-835b80f5281d}`

SMSM (RIVA)   
`{3aabe343-4ea2-43f8-8404-8a4a01088dcf}`


### Example of memory regions 

| Start address | End address | xPU protection | Region name | Comment |
|---------------|-------------|:--------------:|-------------|---------|
| 0x00020000 | 0x00044000 | :white_circle: | RPM | Resource Power Manager |
| 0x00108000 | 0x0010E000 | :white_circle: | RPM | Resource Power Manager |
| 0x01A01000 | 0x01A02000 | :white_circle: | QDSS_ETB_REG | Register within the Qualcomm Debug Subsystem (QDSS) that controls or accesses the Embedded Trace Buffer (ETB) |
| 0x09000000 | 0x09008000 | :white_circle: | MDSP_RAM | Modem Digital Signal Processor |
| 0x09200000 | 0x09208000 | :white_circle: | MDSP_RAM | Modem Digital Signal Processor |
| 0x09400000 | 0x0940F800 | :white_circle: | MDSP_RAM | Modem Digital Signal Processor |
| 0x28400000 | 0x28420000 | :no_entry: | ADSP | Application Digital Signal Processor |
| 0x2A000000 | 0x2A03F000 | :white_circle: | SYS_IMEM | Internal Memory |
| 0x2A03F000 | 0x2A04F000 | :white_circle: | SYS_IMEM | Internal Memory |
| 0x80000000 | 0x80200000 | :white_circle: | SMD (MODEM) | Shared Memory Device of the Modem |
| 0x80385000 | 0x80389400 | :white_circle: | MISC_REG | Miscellaneous register ? |
| 0x89000000 | 0x8DA00000 | :no_entry: | AMSS | Advanced Mobile Subscriber Software |
| 0x8DA00000 | 0x8EC00000 | :no_entry: | ADSP | Application Digital Signal Processor |
| 0x8F000000 | 0x8F700000 | :no_entry: | WCN | Wireless Connectivity Network |
| 0x9fa35000 | 0x9FA55000 | :white_circle: | TRACE_LOG | Crash Dump Driver log buffer - memory allocated at the start of qccdi8930.sys |
| 0x9feb6000 | 0x9FEB7000 | :white_circle: | AP_REG | Application register ? |

