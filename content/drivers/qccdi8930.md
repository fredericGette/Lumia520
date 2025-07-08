## Qccdi8930.sys

As indicated in the binary, this is the _Crash dump injectory driver that interfaces with the Windows crash dump driver and is responsible for generating crash dumps_

It maintains a list of memory regions to include in the memory dump in case of crash. The address of some of these memory regions are hardcoded in the driver, whereas some other memory regions are found by querying other drivers with their driver-defined interface. 

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

