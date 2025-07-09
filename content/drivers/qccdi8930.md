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
| 0x9feb6000 | 0x9FEB7000 | :white_circle: | AP_REG | Application register ? Contains the _watchdog bark timeout handler_ |

### Example of startup logs

Notes: these logs are stored in the `TRACE_LOG` memory region.

```
Successfully completed allocation of the trace log buffer.
InitSubsystemDescriptor: Initializing descriptor list resources.
DriverEntry Exit
qccdiEvtDeviceAdd Entry
No user defined crash dump segment size.
No user defined crash dump segment address.
Unable to locate driver parameters key: ExpectedCrashDumpSegmentSize. Assigned default value of: 10485760 bytes (10 MB).
SCM interface arrival notification.
Target Symbolic Link: \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68}, Device 0x88A80248, PDO 0x8895ADF0, File Object 0x8BC9E878, File Handle 0x80000244
Entering TzAssignDogBarkToFIQ.
Calling TZ via synchronous IOCTL to configure the watchdog bark FIQ.
Successfully configured watchdog bark timeout handler in TZ with physical buffer address of: 0x9FEB6000, and virtual buffer address of: 0x8B5E8000
Successfully processed the interface change notification from the TZ (SCM) driver.
IoRegisterPlugPlayNotification successfully registered for SCM interface notification.
Registering memory region for dump, halt not yet indicated for subsystem: TRACE_LOG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: TRACE_LOG
Attempting bugcheck registration for subsystem: TRACE_LOG
Starting ProcessTraceMemoryMapEntries
Crash dump memory map determined for an internal memory region, subsystem: TRACE_LOG, number of runs: 1, total number of pages: 0x20
Resized the Dump Segment Directory for 1 entries.
Bugcheck registration succeeded for subsystem: TRACE_LOG
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 1
Registering memory region for dump, xPU protection indicated, halt not yet indicated for subsystem: AMSS
Memory protection status being changed to 1 for subsystem: AMSS
Attempting bugcheck registration for subsystem: AMSS
Crash dump memory map determined by hard coded entries, subsystem: AMSS, number of runs: 1, total number of pages: 0x4A00
Resized the Dump Segment Directory for 9 entries.
Bugcheck registration succeeded for subsystem: AMSS
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 9
Registering memory region for dump, xPU protection indicated, halt not yet indicated for subsystem: ADSP
Memory protection status being changed to 1 for subsystem: ADSP
Attempting bugcheck registration for subsystem: ADSP
Crash dump memory map determined by hard coded entries, subsystem: ADSP, number of runs: 2, total number of pages: 0x1220
Resized the Dump Segment Directory for 12 entries.
Bugcheck registration succeeded for subsystem: ADSP
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 12
Registering memory region for dump, halt not yet indicated for subsystem: RPM, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: RPM
Attempting bugcheck registration for subsystem: RPM
Crash dump memory map determined by hard coded entries, subsystem: RPM, number of runs: 2, total number of pages: 0x2A
Resized the Dump Segment Directory for 14 entries.
Bugcheck registration succeeded for subsystem: RPM
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 14
Registering memory region for dump, halt not yet indicated for subsystem: SYS_IMEM, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: SYS_IMEM
Attempting bugcheck registration for subsystem: SYS_IMEM
Crash dump memory map determined by hard coded entries, subsystem: SYS_IMEM, number of runs: 2, total number of pages: 0x4F
Resized the Dump Segment Directory for 16 entries.
Bugcheck registration succeeded for subsystem: SYS_IMEM
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 16
Registering memory region for dump, halt not yet indicated for subsystem: MDSP_RAM, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: MDSP_RAM
Attempting bugcheck registration for subsystem: MDSP_RAM
Crash dump memory map determined by hard coded entries, subsystem: MDSP_RAM, number of runs: 3, total number of pages: 0x20
Resized the Dump Segment Directory for 19 entries.
Bugcheck registration succeeded for subsystem: MDSP_RAM
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 19
Registering memory region for dump, halt not yet indicated for subsystem: QDSS_ETB_REG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: QDSS_ETB_REG
Attempting bugcheck registration for subsystem: QDSS_ETB_REG
Crash dump memory map determined by hard coded entries, subsystem: QDSS_ETB_REG, number of runs: 1, total number of pages: 0x1
Resized the Dump Segment Directory for 20 entries.
Bugcheck registration succeeded for subsystem: QDSS_ETB_REG
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 20
Registering memory region for dump, halt not yet indicated for subsystem: MISC_REG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: MISC_REG
Attempting bugcheck registration for subsystem: MISC_REG
Crash dump memory map determined by hard coded entries, subsystem: MISC_REG, number of runs: 1, total number of pages: 0x5
Resized the Dump Segment Directory for 21 entries.
Bugcheck registration succeeded for subsystem: MISC_REG
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: MISC_REG.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 21
Registering memory region for dump, halt not yet indicated for subsystem: MISC_REG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: MISC_REG
Attempting bugcheck registration for subsystem: MISC_REG
Bugcheck registration already performed for: MISC_REG
Registering memory region for dump, halt not yet indicated for subsystem: AP_REG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: AP_REG
Attempting bugcheck registration for subsystem: AP_REG
Crash dump memory map determined for an internal memory region, subsystem: AP_REG, number of runs: 1, total number of pages: 0x1
Resized the Dump Segment Directory for 22 entries.
Bugcheck registration succeeded for subsystem: AP_REG
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: MISC_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AP_REG.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 22
Registering memory region for dump, xPU protection indicated, halt not yet indicated for subsystem: WCN
Memory protection status being changed to 1 for subsystem: WCN
Attempting bugcheck registration for subsystem: WCN
Crash dump memory map determined by hard coded entries, subsystem: WCN, number of runs: 1, total number of pages: 0x700
Resized the Dump Segment Directory for 23 entries.
Bugcheck registration succeeded for subsystem: WCN
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: MISC_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AP_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: WCN.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 23
The WpMemoryCaptureMode cookie has a value of: 0xFFFFFFFF
The WpSvLegacyFlag cookie has a value of: 0xFFFFFFFF
qccdiEvtDeviceAdd Exit
Entered EvtNotifyPilInterfaceChange.
PIL interface arrival notification.
Entered EvtNotifyNotifierInterfaceChange.
Target Symbolic Link: \??\ACPI#QCOM0E00#2&daba3ff&0#{20e0709d-af59-4ce8-9d91-39e11b4c0231}, Device 0x8BC63CC0, PDO 0x88959850, File Object 0x8BE21D48, File Handle 0x8000037C
Retrieving the PIL driver standard interface.
Notifier interface arrival notification.
Target Symbolic Link: \??\ACPI#QCOM0E30#2&daba3ff&0#{0b28c6f2-f696-4580-acb5-bf16c614b1c2}, Device 0x8BC59648, PDO 0x88959610, File Object 0x8BE22A88, File Handle 0x80000388
Retrieving the Notifier crash dump interface.
Registering all known RPE subsystems for crash dump since connection to the dependent RPEN interface was detected.
No new RPE clients need to be registered for crash dump services.
Registration of subsystem ID AMSS (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: AMSS.
Memory layout already defined for subsystem: AMSS.
Unable to determine the memory layout for subsystem: AMSS, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: AMSS
Memory protection status unchanged from it's current value of 1 for subsystem: AMSS
Attempting bugcheck registration for subsystem: AMSS
Bugcheck registration already performed for: AMSS
CDD (WpCrDmp) interface not yet available: AMSS, !STATUS!.
Registration of subsystem ID AMSS (GUID: !GUID!) completed successfully.
Registration of subsystem ID ADSP (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: ADSP.
Memory layout already defined for subsystem: ADSP.
Unable to determine the memory layout for subsystem: ADSP, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: ADSP
Memory protection status unchanged from it's current value of 1 for subsystem: ADSP
Attempting bugcheck registration for subsystem: ADSP
Bugcheck registration already performed for: ADSP
CDD (WpCrDmp) interface not yet available: ADSP, !STATUS!.
Registration of subsystem ID ADSP (GUID: !GUID!) completed successfully.
Registration of subsystem ID BAMMUX (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: BAMMUX
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to determine the memory layout for subsystem: BAMMUX, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: BAMMUX
Memory protection status unchanged from it's current value of 0 for subsystem: BAMMUX
Attempting bugcheck registration for subsystem: BAMMUX
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to retrieve the memory layout for subsystem: BAMMUX
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: BAMMUX, !STATUS!
CDD (WpCrDmp) interface not yet available: BAMMUX, !STATUS!.
Registration of subsystem ID BAMMUX (GUID: !GUID!) completed successfully.
Registration of subsystem ID BAMMUX (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: BAMMUX.
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to determine the memory layout for subsystem: BAMMUX, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: BAMMUX
Memory protection status unchanged from it's current value of 0 for subsystem: BAMMUX
Attempting bugcheck registration for subsystem: BAMMUX
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to retrieve the memory layout for subsystem: BAMMUX
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: BAMMUX, !STATUS!
CDD (WpCrDmp) interface not yet available: BAMMUX, !STATUS!.
Registration of subsystem ID BAMMUX (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMD (MODEM) (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: SMD (MODEM)
Crash dump memory map provided by the RPE client, subsystem: SMD (MODEM), number of runs: 1, total number of pages: 0x200
Registering memory region for dump, halt is indicated for subsystem: SMD (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (MODEM)
Attempting bugcheck registration for subsystem: SMD (MODEM)
Resized the Dump Segment Directory for 24 entries.
Bugcheck registration succeeded for subsystem: SMD (MODEM)
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: MISC_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AP_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: WCN.
No dump segments added to the directory for subsystem: BAMMUX
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: SMD (MODEM).
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 24
CDD (WpCrDmp) interface not yet available: SMD (MODEM), !STATUS!.
Registration of subsystem ID SMD (MODEM) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMD (MODEM) (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: SMD (MODEM).
Memory layout already defined for subsystem: SMD (MODEM).
Unable to determine the memory layout for subsystem: SMD (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (MODEM)
Attempting bugcheck registration for subsystem: SMD (MODEM)
Bugcheck registration already performed for: SMD (MODEM)
CDD (WpCrDmp) interface not yet available: SMD (MODEM), !STATUS!.
Registration of subsystem ID SMD (MODEM) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMD (RIVA) (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: SMD (RIVA)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to determine the memory layout for subsystem: SMD (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (RIVA)
Attempting bugcheck registration for subsystem: SMD (RIVA)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to retrieve the memory layout for subsystem: SMD (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMD (RIVA),!STATUS!
CDD (WpCrDmp) interface not yet available: SMD (RIVA), !STATUS!.
Registration of subsystem ID SMD (RIVA) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMD (RIVA) (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: SMD (RIVA).
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to determine the memory layout for subsystem: SMD (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (RIVA)
Attempting bugcheck registration for subsystem: SMD (RIVA)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to retrieve the memory layout for subsystem: SMD (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMD (RIVA), !STATUS!
CDD (WpCrDmp) interface not yet available: SMD (RIVA), !STATUS!.
Registration of subsystem ID SMD (RIVA) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMSM (MODEM) (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to determine the memory layout for subsystem: SMSM (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (MODEM)
Attempting bugcheck registration for subsystem: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to retrieve the memory layout for subsystem: SMSM (MODEM)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (MODEM), !STATUS!
CDD (WpCrDmp) interface not yet available: SMSM (MODEM), !STATUS!.
Registration of subsystem ID SMSM (MODEM) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMSM (MODEM) (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: SMSM (MODEM).
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to determine the memory layout for subsystem: SMSM (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (MODEM)
Attempting bugcheck registration for subsystem: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to retrieve the memory layout for subsystem: SMSM (MODEM)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (MODEM), !STATUS!
CDD (WpCrDmp) interface not yet available: SMSM (MODEM), !STATUS!.
Registration of subsystem ID SMSM (MODEM) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMSM (RIVA) (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: SMSM (RIVA)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to determine the memory layout for subsystem: SMSM (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (RIVA)
Attempting bugcheck registration for subsystem: SMSM (RIVA)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to retrieve the memory layout for subsystem: SMSM (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (RIVA), !STATUS!
CDD (WpCrDmp) interface not yet available: SMSM (RIVA), !STATUS!.
Registration of subsystem ID SMSM (RIVA) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMSM (RIVA) (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: SMSM (RIVA).
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to determine the memory layout for subsystem: SMSM (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (RIVA)
Attempting bugcheck registration for subsystem: SMSM (RIVA)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to retrieve the memory layout for subsystem: SMSM (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (RIVA), !STATUS!
CDD (WpCrDmp) interface not yet available: SMSM (RIVA), !STATUS!.
Registration of subsystem ID SMSM (RIVA) (GUID: !GUID!) completed successfully.
Entered CddEvtNotifyScmInterfaceChange.
CDD interface arrival notification.
Target Symbolic Link: \??\Root#wpcrdmp#0000#{933b95c6-f9cf-4424-a9f8-f497f760aee5}, Device 0x8BC8E5A0, PDO 0x83B72A40, File Object 0x8BE36520, File Handle 0x80000400
Retrieving the crash dump driver standard interface.
Registering all known RPE subsystems for crash dump since connection to the dependent CDD interface was detected.
Memory layout already defined for subsystem: TRACE_LOG.
Unable to determine the memory layout for subsystem: TRACE_LOG, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: TRACE_LOG, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: TRACE_LOG
Attempting bugcheck registration for subsystem: TRACE_LOG
Bugcheck registration already performed for: TRACE_LOG
Updating the CDD Context with a value of 2 for the Map Entry used by: TRACE_LOG.
Updating the CDD notification function table for the Map Entry used by: TRACE_LOG.
Setting CDD subsystem memory layout, subsystem: TRACE_LOG (GUID: !GUID!) number of runs: 10935199152, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15563182080
Successfully registered with CDD: TRACE_LOG
Memory layout already defined for subsystem: AMSS.
Unable to determine the memory layout for subsystem: AMSS, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: AMSS
Memory protection status unchanged from it's current value of 1 for subsystem: AMSS
Attempting bugcheck registration for subsystem: AMSS
Bugcheck registration already performed for: AMSS
Updating the CDD Context with a value of 3 for the Map Entry used by: AMSS.
Updating the CDD notification function table for the Map Entry used by: AMSS.
Setting CDD subsystem memory layout, subsystem: AMSS (GUID: !GUID!) number of runs: 15230165512, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15183380480
Successfully registered with CDD: AMSS
Memory layout already defined for subsystem: ADSP.
Unable to determine the memory layout for subsystem: ADSP, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: ADSP
Memory protection status unchanged from it's current value of 1 for subsystem: ADSP
Attempting bugcheck registration for subsystem: ADSP
Bugcheck registration already performed for: ADSP
Updating the CDD Context with a value of 4 for the Map Entry used by: ADSP.
Updating the CDD notification function table for the Map Entry used by: ADSP.
Setting CDD subsystem memory layout, subsystem: ADSP (GUID: !GUID!) number of runs: 19525221032, size in bytes of memory run structures: 2 address of memory in first run: 0x30 size in bytes of memory in first run: 13560184832
Successfully registered with CDD: ADSP
Memory layout already defined for subsystem: RPM.
Unable to determine the memory layout for subsystem: RPM, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: RPM, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: RPM
Attempting bugcheck registration for subsystem: RPM
Bugcheck registration already performed for: RPM
Updating the CDD Context with a value of 5 for the Map Entry used by: RPM.
Updating the CDD notification function table for the Map Entry used by: RPM.
Setting CDD subsystem memory layout, subsystem: RPM (GUID: !GUID!) number of runs: 23820080744, size in bytes of memory run structures: 2 address of memory in first run: 0x30 size in bytes of memory in first run: 12885032960
Successfully registered with CDD: RPM
Memory layout already defined for subsystem: SYS_IMEM.
Unable to determine the memory layout for subsystem: SYS_IMEM, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: SYS_IMEM, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: SYS_IMEM
Attempting bugcheck registration for subsystem: SYS_IMEM
Bugcheck registration already performed for: SYS_IMEM
Updating the CDD Context with a value of 6 for the Map Entry used by: SYS_IMEM.
Updating the CDD notification function table for the Map Entry used by: SYS_IMEM.
Setting CDD subsystem memory layout, subsystem: SYS_IMEM (GUID: !GUID!) number of runs: 28115046064, size in bytes of memory run structures: 2 address of memory in first run: 0x30 size in bytes of memory in first run: 13589544960
Successfully registered with CDD: SYS_IMEM
Memory layout already defined for subsystem: MDSP_RAM.
Unable to determine the memory layout for subsystem: MDSP_RAM, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: MDSP_RAM, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: MDSP_RAM
Attempting bugcheck registration for subsystem: MDSP_RAM
Bugcheck registration already performed for: MDSP_RAM
Updating the CDD Context with a value of 7 for the Map Entry used by: MDSP_RAM.
Updating the CDD notification function table for the Map Entry used by: MDSP_RAM.
Setting CDD subsystem memory layout, subsystem: MDSP_RAM (GUID: !GUID!) number of runs: 32409755312, size in bytes of memory run structures: 3 address of memory in first run: 0x40 size in bytes of memory in first run: 13035896832
Successfully registered with CDD: MDSP_RAM
Memory layout already defined for subsystem: QDSS_ETB_REG.
Unable to determine the memory layout for subsystem: QDSS_ETB_REG, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: QDSS_ETB_REG, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: QDSS_ETB_REG
Attempting bugcheck registration for subsystem: QDSS_ETB_REG
Bugcheck registration already performed for: QDSS_ETB_REG
Updating the CDD Context with a value of 8 for the Map Entry used by: QDSS_ETB_REG.
Updating the CDD notification function table for the Map Entry used by: QDSS_ETB_REG.
Setting CDD subsystem memory layout, subsystem: QDSS_ETB_REG (GUID: !GUID!) number of runs: 36705029808, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 12912168960
Successfully registered with CDD: QDSS_ETB_REG
Memory layout already defined for subsystem: MISC_REG.
Unable to determine the memory layout for subsystem: MISC_REG, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: MISC_REG, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: MISC_REG
Attempting bugcheck registration for subsystem: MISC_REG
Bugcheck registration already performed for: MISC_REG
Updating the CDD Context with a value of 9 for the Map Entry used by: MISC_REG.
Updating the CDD notification function table for the Map Entry used by: MISC_REG.
Setting CDD subsystem memory layout, subsystem: MISC_REG (GUID: !GUID!) number of runs: 40999950768, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15036076032
Successfully registered with CDD: MISC_REG
Memory layout already defined for subsystem: AP_REG.
Unable to determine the memory layout for subsystem: AP_REG, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: AP_REG, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: AP_REG
Attempting bugcheck registration for subsystem: AP_REG
Bugcheck registration already performed for: AP_REG
Updating the CDD Context with a value of 10 for the Map Entry used by: AP_REG.
Updating the CDD notification function table for the Map Entry used by: AP_REG.
Setting CDD subsystem memory layout, subsystem: AP_REG (GUID: !GUID!) number of runs: 45294934976, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15567904768
Successfully registered with CDD: AP_REG
Memory layout already defined for subsystem: WCN.
Unable to determine the memory layout for subsystem: WCN, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: WCN, current memory protection status: 1.
Memory protection status unchanged from it's current value of 1 for subsystem: WCN
Attempting bugcheck registration for subsystem: WCN
Bugcheck registration already performed for: WCN
Updating the CDD Context with a value of 11 for the Map Entry used by: WCN.
Updating the CDD notification function table for the Map Entry used by: WCN.
Setting CDD subsystem memory layout, subsystem: WCN (GUID: !GUID!) number of runs: 49589901592, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15284043776
Successfully registered with CDD: WCN
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to determine the memory layout for subsystem: BAMMUX, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: BAMMUX
Memory protection status unchanged from it's current value of 0 for subsystem: BAMMUX
Attempting bugcheck registration for subsystem: BAMMUX
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to retrieve the memory layout for subsystem: BAMMUX
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: BAMMUX, !STATUS!
Updating the CDD Context with a value of 12 for the Map Entry used by: BAMMUX.
Updating the CDD notification function table for the Map Entry used by: BAMMUX.
No memory runs available for this subsystem: BAMMUX.
Successfully registered with CDD: BAMMUX
Memory layout already defined for subsystem: SMD (MODEM).
Unable to determine the memory layout for subsystem: SMD (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (MODEM)
Attempting bugcheck registration for subsystem: SMD (MODEM)
Bugcheck registration already performed for: SMD (MODEM)
Updating the CDD Context with a value of 13 for the Map Entry used by: SMD (MODEM).
Updating the CDD notification function table for the Map Entry used by: SMD (MODEM).
Setting CDD subsystem memory layout, subsystem: SMD (MODEM) (GUID: !GUID!) number of runs: 58181451440, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15032385536
Successfully registered with CDD: SMD (MODEM)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to determine the memory layout for subsystem: SMD (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (RIVA)
Attempting bugcheck registration for subsystem: SMD (RIVA)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to retrieve the memory layout for subsystem: SMD (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMD (RIVA), !STATUS!
Updating the CDD Context with a value of 14 for the Map Entry used by: SMD (RIVA).
Updating the CDD notification function table for the Map Entry used by: SMD (RIVA).
No memory runs available for this subsystem: SMD (RIVA).
Successfully registered with CDD: SMD (RIVA)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to determine the memory layout for subsystem: SMSM (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (MODEM)
Attempting bugcheck registration for subsystem: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to retrieve the memory layout for subsystem: SMSM (MODEM)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (MODEM), !STATUS!
Updating the CDD Context with a value of 15 for the Map Entry used by: SMSM (MODEM).
Updating the CDD notification function table for the Map Entry used by: SMSM (MODEM).
No memory runs available for this subsystem: SMSM (MODEM).
Successfully registered with CDD: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to determine the memory layout for subsystem: SMSM (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (RIVA)
Attempting bugcheck registration for subsystem: SMSM (RIVA)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to retrieve the memory layout for subsystem: SMSM (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (RIVA), !STATUS!
Updating the CDD Context with a value of 16 for the Map Entry used by: SMSM (RIVA).
Updating the CDD notification function table for the Map Entry used by: SMSM (RIVA).
No memory runs available for this subsystem: SMSM (RIVA).
Successfully registered with CDD: SMSM (RIVA)
Registration of subsystem ID WCN (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: WCN.
Memory layout already defined for subsystem: WCN.
Unable to determine the memory layout for subsystem: WCN, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: WCN
Memory protection status unchanged from it's current value of 1 for subsystem: WCN
Attempting bugcheck registration for subsystem: WCN
Bugcheck registration already performed for: WCN
CDD (WpCrDmp) registration has already occurred for subsystem: WCN
Registration of subsystem ID WCN (GUID: !GUID!) completed successfully.
```
