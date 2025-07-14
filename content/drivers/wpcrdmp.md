## Wpcrdmp.sys

Register callbacks in case of crash (bugcheck) to generate memory dumps.  
Requires qccdi8930.sys to knows about the memory layout of the subsystems.  
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
| DedicatedDumpFile | c:\Data\SystemData\Telemetry\KernelDumps\DedicatedDump.sys | String to set the filepath of the offline dump. Set the UEFI variable DedicatedDumpFile of the GUID {853CE3A3-F693-4D9A-B95F-84E2105D13F2} |
| OfflineDumpBugCheckCodes | ? | MultiString containing base10 Integer values. |
