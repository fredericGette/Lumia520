## Wpcrdmp.sys

Register callbacks in case of crash (bugcheck) to generate memory dumps.  
Requires qccdi8930.sys to know about the memory layout of the subsystems.  
Requires the UEFI boot application wpdmp.efi to generate a full physical memory dump.  

Registry parameters:  
`\Registry\Machine\System\CurrentControlSet\Control\CrashControl`  
| Registry value | value | comment |
|----------------|-------|---------|
| CrashDumpEnabled | 0 | Controls the dump type to be taken in the case of an unhandled fault in the kernel process. |
| WpDisablePrebootCrashDump | 0 | Boolean to disable the generation of the crash dump by _preboot_ (SBL or UEFI). |
| EnableOfflineDumps | 0 | Boolean to enable _offline dump_ : dump generated after the reboot of the phone. |
| WpDisableDebuggerCheck | 0 | Boolean to disable check of KdDebuggerNotPresent. For example: generation of offline dump is deactivate when a debugger is detected. |
| WpDisableSubSystemCallBacks | 0 | Boolean |
| DedicatedDumpFile | D:\DedicatedDump.sys | String to set the filepath of the offline dump. Set the UEFI variable DedicatedDumpFile of the GUID {853CE3A3-F693-4D9A-B95F-84E2105D13F2} |
| OfflineDumpBugCheckCodes | ? | MultiString containing base10 Integer values. |

The registry parameter `CrashDumpEnabled` accepts the following values:  
| Value | comment |
|-------|---------|
| 0 | Disabled. |
| 1 | Full physical memory dump. |
| 2 | Kernel memory dump. (Dumps only pages mapped into the kernel process address space; does not include user processes.) |
| 3 | Minidump (stack and registers). |

### GUID

WPCRDMP_InterfaceClassGUID  
`{933B95C6-F9CF-4424-A9F8-F497F760AEE5}`

WPCRDMP_exported_INTERFACE_GUID  
`{8BCB35C2-CB20-44E4-9A1E-33A016856CBF}`

Unknown_GUID_01  
`{8CC74056-428F-4A4A-A7EB-034E68FC2C2A}`

Unknown_UEFI_GUID_02  
`{853CE3A3-F693-4D9A-B95F-84E2105D13F2}`

Unknown_UEFI_GUID_03  
`{83E7A47A-4023-40D2-9852-05EC34CAAF87}`

SECUREBOOT_DEBUG_GUID  
`{0CDAD82E-D839-4754-89A1-844AB282312B}`

Unknown_interface_class_GUID  
`{A942B3D9-EC95-4754-AE45-49C48735B893}`  
could be qcbms8930.sys or qcpmicapps8930.sys or qcscm8930.sys ?

