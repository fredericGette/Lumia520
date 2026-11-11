## WININIT.EXE

The Windows start-up application of session 0: it starts the system processes of the phone (`services.exe`, `lsass.exe`) and handles the shutdown of the system.  
`WININIT.EXE` is the Windows 8.1 `wininit.exe` built for ARM (118 784 bytes, 332 functions, public symbols, PDB `wininit.pdb`). It's a critical process: if it ends, the system bug checks. At boot it builds the environment of the system processes and starts the service control manager (`services.exe`) and the LSA (`lsass.exe`), both as protected processes. It gives the LSA its SysKey boot key through an LPC port, watches the system processes, and reboots the phone if one of them dies. Then it waits for a shutdown request and runs the shutdown. Shutdown requests come through its RPC servers (`InitShutdown`, `WindowsShutdown`, WMsg) or from the kernel.  
Much of the code is for the desktop: setup, the LogonUI status screen, the `bootim.exe` boot options menu, remote shutdown over TCP, AppInit_DLLs, ntsd. Those parts call `ext-ms-win-*` API sets through delay-load and first check that the set exists (`ApiSetQueryApiSetPresence`: `IsSwitchDesktopPresent`, `IsStartLoadingFontsWorkerPresent`, `IsExitWindowsExPresent`…). Whether these sets exist on the phone isn't known. The processes it starts (`services.exe`, `lsass.exe`, `WerFault.exe`, `LogonUI.exe`, `bootim.exe`) aren't documented here. In the LSA process run [MSV1_0.DLL](../libraries/msv1_0.md) and [SSPISRV.DLL](../libraries/sspisrv.md).

Location on the phone: `C:\Windows\System32\wininit.exe` ? (the binary names itself `wininit.exe` and starts its peers from `%SystemRoot%\system32`).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `RtlSetProcessIsCritical`, `RtlSetThreadIsCritical`, `NtSetInformationProcess`, `NtQuerySystemInformation`, `NtQueryInformationProcess`, `NtQueryInformationToken`, `NtOpenProcessToken`, `NtOpenThreadToken`, `RtlRemovePrivileges`, `RtlAdjustPrivilege`, `NtPrivilegeCheck`, `NtPrivilegeObjectAuditAlarm`, `RtlAllocateAndInitializeSid`, `NtShutdownSystem`, `NtSetThreadExecutionState`, `NtPowerInformation`, `NtSystemDebugControl`, `NtCreateKey`, `NtSetValueKey`, `NtCreateEvent`, `NtDelayExecution`, `NtCreatePort`, `NtAcceptConnectPort`, `NtCompleteConnectPort`, `NtReplyWaitReceivePort`, `NtReplyPort`, `NtAllocateLocallyUniqueId`, `NtClose`, `RtlConnectToSm`, `RtlSendMsgToSm`, `CsrClientCallServer`, `RtlCreateEnvironment`, `RtlDestroyEnvironment`, `RtlSetEnvironmentVariable`, `RtlQueryEnvironmentVariable_U`, `RtlRegisterWait`, `RtlDeregisterWait`, `RtlDeregisterWaitEx`, `RtlInitUnicodeString`, `RtlInitUnicodeStringEx`, `RtlCompareUnicodeString`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlInitializeCriticalSection`, `RtlEnterCriticalSection`, `RtlLeaveCriticalSection`, `RtlNtStatusToDosError`, `RtlUnhandledExceptionFilter`, `EtwEventRegister`, `EtwEventUnregister`, `EtwEventEnabled`, `EtwEventWrite`, `EtwEventWriteStartScenario`, `EtwEventActivityIdControl`, `EtwRegisterTraceGuidsW`, `EtwUnregisterTraceGuids`, `EtwGetTraceLoggerHandle`, `EtwGetTraceEnableLevel`, `EtwGetTraceEnableFlags`, `EtwTraceMessage`, `WinSqmIsOptedIn`, `WinSqmAddToStream`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| RPCRT4.dll | `RpcServerUseProtseqW`, `RpcServerUseProtseqEpW`, `RpcServerRegisterIfEx`, `RpcServerUnregisterIf`, `RpcServerListen`, `RpcServerRegisterAuthInfoW`, `RpcServerInqDefaultPrincNameW`, `RpcServerInqBindings`, `RpcServerInqCallAttributesW`, `RpcServerTestCancel`, `RpcEpRegisterW`, `RpcEpUnregister`, `RpcBindingVectorFree`, `RpcImpersonateClient`, `RpcRevertToSelf`, `RpcBindingServerFromClient`, `RpcBindingToStringBindingW`, `RpcStringBindingParseW`, `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcStringFreeW`, `RpcBindingSetAuthInfoExW`, `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingUnbind`, `RpcBindingCopy`, `RpcBindingFree`, `RpcMgmtIsServerListening`, `UuidFromStringW`, `RpcAsyncInitializeHandle`, `RpcAsyncCompleteCall`, `RpcAsyncAbortCall`, `RpcAsyncCancelCall`, `NdrClientCall2`, `NdrAsyncClientCall`, `NdrServerCall2`, `NdrAsyncServerCall`, `I_RpcBindingIsClientLocal`, `I_RpcExceptionFilter`, `RpcExceptionFilter` |
| profapi.dll | `CreateEnvBlock`, `DestroyEnvBlock`, `GetBasicProfileFolderPath` |
| msvcrt.dll | `_vsnwprintf`, `wcsstr`, `wcschr`, `wcslen`, `_wcsicmp`, `strlen`, `memcpy`, `memmove`, `memset`, `_ismbblead` + CRT startup (`__getmainargs`, `_acmdln`, `_initterm`, `_amsg_exit`, `_exit`, `_cexit`, `exit`, `__set_app_type`, `__setusermatherr`, `_fmode`, `_commode`, `_XcptFilter`, `__C_specific_handler`, `?terminate@@YAXXZ`) |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegCloseKey`, `RegGetValueW`, `RegQueryValueExW`, `RegQueryValueExA`, `RegQueryInfoKeyW`, `RegQueryInfoKeyA`, `RegEnumValueW`, `RegSetValueExW`, `RegDeleteValueW`, `RegDeleteTreeW` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateProcessW`, `CreateProcessAsUserW`, `InitializeProcThreadAttributeList`, `UpdateProcThreadAttribute`, `DeleteProcThreadAttributeList`, `OpenProcess`, `OpenProcessToken`, `GetExitCodeProcess`, `TerminateProcess`, `CreateThread`, `CreateRemoteThread`, `ResumeThread`, `SetThreadPriority`, `SetPriorityClass`, `GetCurrentProcess`, `GetCurrentProcessId`, `GetCurrentThread` |
| api-ms-win-core-file-l1-2-1.dll / -l2-1-1.dll | `CreateFileW`, `ReadFile`, `DeleteFileW`, `CreateDirectoryW`, `GetFileAttributesW`, `FindFirstFileW`, `FindClose`, `FindFirstVolumeW`, `FindNextVolumeW`, `FindVolumeClose`, `GetDriveTypeW`, `GetShortPathNameW`, `MoveFileExW` |
| api-ms-win-security-base-l1-2-0.dll | `CheckTokenMembership`, `GetTokenInformation`, `SetTokenInformation`, `DuplicateTokenEx`, `ImpersonateLoggedOnUser`, `RevertToSelf`, `CreateWellKnownSid`, `EqualSid`, `SetFileSecurityW`, `GetSecurityDescriptorControl`, `GetSecurityDescriptorOwner`, `GetSecurityDescriptorGroup`, `GetSecurityDescriptorDacl`, `GetSecurityDescriptorSacl` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `WaitForSingleObjectEx`, `WaitForMultipleObjectsEx`, `Sleep`, `SleepEx`, `InitializeCriticalSection`, `EnterCriticalSection`, `TryEnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleHandleA`, `FindResourceExW`, `LoadResource`, `LockResource` |
| api-ms-win-core-heap-l1-2-0.dll / heap-obsolete | `HeapCreate`, `HeapDestroy`, `HeapAlloc`, `HeapFree`, `GetProcessHeap`, `HeapSetInformation`, `LocalAlloc`, `LocalReAlloc`, `LocalSize`, `LocalFree` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetComputerNameExW`, `GetWindowsDirectoryW`, `GetVersionExW`, `GetTickCount`, `GetLocalTime` |
| api-ms-win-eventing-controller-l1-1-0.dll | `StartTraceW`, `ControlTraceW`, `EnableTraceEx2` |
| api-ms-win-core-threadpool-legacy-l1-1-0.dll | `QueueUserWorkItem`, `CreateTimerQueueTimer`, `DeleteTimerQueueTimer` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `WTSGetActiveConsoleSessionId`, `GetStartupInfoA` |
| other api-ms-win-core-* | `CloseHandle`; `GetLastError`, `SetLastError`, `SetErrorMode`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`; `SetEnvironmentVariableW`, `ExpandEnvironmentStringsW`; `GetDateFormatW`, `GetTimeFormatW`; `SystemTimeToFileTime`, `FileTimeToSystemTime`; `GetFileVersionInfoSizeExW`, `GetFileVersionInfoExW`, `VerQueryValueW`; `lstrlenW`, `lstrcmpiW`; `K32GetModuleFileNameExW`; `ResolveDelayLoadedAPI`, `DelayLoadFailureHook`; `ApiSetQueryApiSetPresence` |
| api-ms-win-security-sddl-l1-1-0.dll (delay-load) | `ConvertStringSecurityDescriptorToSecurityDescriptorW` |
| api-ms-win-security-lsalookup-l1-1-1.dll (delay-load) | `LookupAccountSidLocalW` |
| api-ms-win-service-management-l1-1-0.dll / -l2-1-0.dll, api-ms-win-service-winsvc-l1-2-0.dll (delay-load) | `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `CloseServiceHandle`, `NotifyServiceStatusChangeW`, `QueryServiceStatus` |
| api-ms-win-service-private-l1-1-1.dll (delay-load) | `I_ScSendTSMessage` |
| api-ms-win-eventlog-legacy-l1-1-0.dll (delay-load) | `RegisterEventSourceW`, `ReportEventW`, `DeregisterEventSource` |
| api-ms-win-base-bootconfig-l1-1-0.dll (delay-load) | `NotifyBootConfigStatus` |
| ext-ms-win-ntuser-keyboard-l1-1-1.dll (delay-load) | `GetAsyncKeyState` |
| ext-ms-win-ntuser-misc-l1-3-0.dll (delay-load) | `ExitWindowsEx` |
| ext-ms-win-ntuser-private-l1-1-1.dll (delay-load) | `RecordShutdownReason`, `RegisterLogonProcess` |
| ext-ms-win-ntuser-windowstation-l1-1-1.dll (delay-load) | `SwitchDesktop` |
| ext-ms-win-session-wtsapi32-l1-1-0.dll (delay-load) | `WTSEnumerateSessionsW`, `WTSQueryUserToken`, `WTSDisconnectSession`, `WTSFreeMemory` |
| ext-ms-win-session-wininit-l1-1-0.dll (delay-load) | `PrimaryTerminalAndHookWorker`, `StartLoadingFontsWorker`, `WaitForWinstationShutdown`, `WinStationSystemShutdownStartedWorker`, `GetLoggedOnUserCount`, `UnregisterSession0ViewerWindowHookDll` |

The `msvcrt` startup functions, `_initterm`, the `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind` / `UnhandledExceptionFilter` group and `GetStartupInfoA` are the standard CRT startup and `/GS` code. The only export is the entry point `WinMainCRTStartup`.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `%SystemRoot%\system32\services.exe` | `CreateProcessW` ([ExecSystemProcesses](#execsystemprocesses)) | Service control manager. Started as a protected process and watched |
| `%SystemRoot%\system32\lsass.exe` | `CreateProcessW` ([ExecSystemProcesses](#execsystemprocesses)) | LSA, loads [MSV1_0.DLL](../libraries/msv1_0.md) and [SSPISRV.DLL](../libraries/sspisrv.md). Started as a protected process (LSA level) and watched |
| `%SystemRoot%\system32\WerFault.exe` (or the value `Winlogon\SaveDumpStart`) | `CreateProcessW`, command line + ` -k -c ` | Reports the previous crash / failed shutdown ([ExecSystemProcesses](#execsystemprocesses)) |
| `LogonUI.exe` | `CreateProcessW` / `CreateProcessAsUserW`, `"LogonUI.exe" /flags:0x<n>` on `Winsta0\Winlogon` | Status screen during shutdown (`WluiiStartupImpl`, 0x40F18C) |
| `bootim.exe` | `CreateProcessAsUserW` in the console session (`LaunchProcessInSession`), `bootim.exe /startpage:1` on `Winsta0\Winlogon` | Boot options menu, on shutdown flag 0x400 ([Shutdown](#shutdown)) |
| setup program (`HKLM\SYSTEM\Setup` `Cmdline` or `RespecializeCmdLine`) | `CreateProcessW` on `winsta0\Default`, prefixed with `ntsd -d` / `ntsd` when debugging setup | Only when setup runs (`ExecuteSetup`, 0x410F6C) |
| `ntsd.exe` (`AeDebug\BpidDebugger`, `%SystemRoot%\Debuggers\`, `%SystemDrive%\Debuggers\`, `C:\Debuggers\`, `%SystemRoot%\System32\`) | `CreateProcessAsUserW`, `<ntsd> -d -p <pid> [-pv]` | Debugger attached to the system processes when a kernel debugger is present (`Attach`, 0x40F624) |
| `fmifs.dll` | `LoadLibraryExW(LOAD_LIBRARY_SEARCH_SYSTEM32)`, `GetProcAddress("QueryIsDiskCheckScheduledForNextBoot")` | Hybrid shutdown is turned off when chkdsk is scheduled (`OverrideHybridShutdown`, 0x40BC1C) |
| module named by `HKLM\SYSTEM\CurrentControlSet\Control\Wininit` `RestoreModule` | `LoadLibraryExW`, `GetProcAddress(<RestoreFunction>)` | System restore during shutdown, when `RestoreInProgress` is set (`PerformSystemRestore`, 0x4103B8) |
| `bootex.log` (root of every fixed volume) | `CreateFileW` / `ReadFile` / `DeleteFileW` | Autochk log, copied into the event log (event 0x400003E9) then deleted (`DealWithAutochkLogs`, 0x405370), 30 s after start once `EventLog` runs |
| `%SystemRoot%\MEMORY.DMP` | `FindFirstFileW` | Existing crash dump after a display watchdog event ([ExecSystemProcesses](#execsystemprocesses)) |
| `%SystemRoot%\temp` | `CreateDirectoryW`, `SetFileSecurityW` | Created at boot with `O:BAG:BAD:PAI(A;;FA;;;SY)(A;IOCIOI;GA;;;SY)(A;;FA;;;BA)(A;OICIIO;GA;;;BA)(A;CI;0x100026;;;BU)(A;OICIIO;GA;;;CO)` (`CreateWindirTemp`, 0x405768) |
| `umstartup.etl` (previous copy renamed `umstartup000.etl`) | `MoveFileExW`, `StartTraceW` session `umstartup` | WPP trace of the start-up, level from `Control\WinInit` `TracingControlLevel` (`WppStart`, 0x407C8C) |
| `ntdll.dll` | `GetModuleHandleW`, `GetProcAddress("DbgBreakPoint")` | Breaks into a system process (`Breakin`, 0x40BF7C) |

### Parameters

The command line isn't used: `WinMain` (0x404424) never reads its parameters. Its exit code is 0 or a Win32 error code from the start-up. In normal operation it doesn't return: it ends in `NtShutdownSystem`. It's started by `smss.exe` ? (not analysed; [NTOSKRNL.EXE](../libraries/ntoskrnl.md#startfirstuserprocess-0x8ba09c) only shows that `smss.exe` is the first user-mode process).

### WinMain

`WinMain` (0x404424) can't be decompiled (Hex-Rays error -13, bad stack frame), so this comes from the disassembly. It keeps a progress counter `g_usState` (1 … 0x11).

1. `RtlSetProcessIsCritical(TRUE)` and `RtlSetThreadIsCritical(TRUE)`: if the process or its main thread ends, the system bug checks. `NtSetInformationProcess(class 0x36, 1)` ?, `HeapSetInformation(HeapEnableTerminationOnCorruption)`.
2. Tracing: `WppInitUm` (control GUID `{C2BA06E2-F7CE-44AA-9E7E-62652CDEFE97}`), `WppStart` (`umstartup` session) and `EtwEventRegister` of the provider `{206F6DEA-D3C5-4D10-BC72-989F03C8B84B}` (`MS_Wininit_Provider`).
3. Creates the events `Global\FirstWinlogonCheck` and `Global\WinlogonLogoff` (manual reset), `UmsHlprInit` (well-known SIDs), `SetProcessPriority` (`HIGH_PRIORITY_CLASS`, `THREAD_PRIORITY_HIGHEST`), `InitDebugHelpers` (see [Debugger](#debugger)).
4. `GetComputerNameExW(ComputerNameNetBIOS)` into the variable `COMPUTERNAME`.
5. `WinInitBoot` (0x407118): private heap; copies the TCP/IP `NV Hostname` / `NV Domain` values to `Hostname` / `Domain`, and `NV PrimaryDnsSuffix` to `PrimaryDnsSuffix` (`UpdateTcpIpParameters`); reads the setup type (`HKLM\SYSTEM\Setup` `SetupType`, `Respecialize`; setup runs when `SetupType` is 1 or 4); sets MiniNT mode if `HKLM\System\CurrentControlSet\Control\MiniNT` exists; resets `Winlogon\DisableLockWorkstation` from 2 to 0 (`CleanupLeftovers`).
6. `SetProfilesLocation` (0x40706C): `USERPROFILE`, `PUBLIC`, `ProgramData` and `ALLUSERSPROFILE` from `profapi!GetBasicProfileFolderPath` (folders 5, 3, 4).
7. `CreateWindirTemp`, then `WMsgClntInitialize(ctx, TRUE)`: registers the [WMsg](#rpc-servers) handlers and starts the WMsgK server.
8. If `ext-ms-win-session-wininit` exists: `PrimaryTerminalAndHookWorker` (window station and the `Winlogon` / application desktops of session 0).
9. `WinInitStartUp` (0x4056A4):
   1. `WinInitWaitForBootShell` ([below](#bootshell)).
   2. `SbBootPrompt` ([SysKey](#syskey)). If it fails, the start-up stops.
   3. `ExecSystemProcesses` ([below](#execsystemprocesses)), `SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOOPENFILEERRORBOX)`, then waits for the SysKey thread to end (`SbSyncWithKeyThread`).
10. If `HKLM\SYSTEM\CurrentControlSet\Control\WinInit` `Headless` isn't 0: sets the event `Global\UMSServicesStarted`.
11. `RemoveTokenPrivileges` (0x4055C8): `RtlRemovePrivileges` keeps only 20 privileges in the token of the process: 3, 5, 7, 8, 9, 10, 14, 16, 17, 18, 19, 20, 21, 22, 23, 25, 28, 29, 30, 35 (AssignPrimaryToken, IncreaseQuota, Tcb, Security, TakeOwnership, LoadDriver, IncreaseBasePriority, CreatePermanent, Backup, Restore, Shutdown, Debug, Audit, SystemEnvironment, ChangeNotify, Undock, ManageVolume, Impersonate, CreateGlobal, CreateSymbolicLink).
12. `StartLoadingFontsWorker` (if present), `WMsgClntInitialize(ctx, FALSE)` (starts the WMsg server in a work item), `WsdpStartRemoteShutdown` ([RPC](#rpc-servers)).
13. Timers: `AutoCheckLogsCallback` after 30 s (waits for the `EventLog` service, then `DealWithAutochkLogs`). `LogAppInitDllsCallback` after 10 s writes the ETW event `WIEvt_AppInit_DLLs_Enabled` if `Windows\LoadAppInit_DLLs` is non-zero and `AppInit_DLLs` isn't empty.
14. Waits (`INFINITE`) on the shutdown event of the shutdown module (`dword_41552C`, created in `InitializeShutdownModule`), then reports the boot as good if `Winlogon\ReportBootOk` isn't `"0"` (`UHReportBootGood` → `NotifyBootConfigStatus(TRUE)` in a low-priority thread). If setup must run: `WinInitSetup`.
15. Shutdown: `WaitForWinstationShutdown` (if present), `WluiStartup` (LogonUI, if present and not headless), status message, `WinInitNotifyShutdown`, `WMsgClntTerminate`, the RPC servers are stopped, then [WinInitShutdown](#shutdown).

### BootShell

`WinInitWaitForBootShell` (0x407018): `NtQuerySystemInformation(SystemBootEnvironmentInformation (0x5A))`. If bit 0 of the boot flags (offset 0x18) is set and `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager` has a string value `BootShell` (`RegGetValueW`, `REG_SZ` / `REG_EXPAND_SZ`), wininit creates `Global\BootShellComplete` and waits on it with no timeout before starting anything. The program that sets this event isn't in the binary.

### SysKey

`SbBootPrompt` (0x406B34) reads `HKLM\System\CurrentControlSet\Control\Lsa` `SecureBoot` (DWORD):

* 1 (boot key stored on the device): `SbGetKeyData` → `DeobfuscateKey` (0x406C80) rebuilds the 16-byte boot key from the class names of the subkeys `JD`, `Skew1`, `GBG` and `Data` of the `Lsa` key (`RegQueryInfoKeyA`, 8 hex digits each) and a permutation table (`dword_401F70`). If that fails, wininit enables `SeShutdownPrivilege` and calls `NtShutdownSystem(ShutdownReboot)`. Then the thread `SbKeyData` → `WxServerThread` (0x407DF8) creates the LPC port `\Security\WxApiPort` (`NtCreatePort`). It accepts the connection of the LSA and answers its request with the 16 bytes of `KeyDataBuffer`, which are then cleared.
* other values: nothing; on a headless system the start-up fails with 0xC0000360.

### ExecSystemProcesses

`ExecSystemProcesses` (0x4057C8):

1. If `HKLM\system\currentcontrolset\control\stagedboot` exists: creates the event `StagedBootCompletionEvent` and writes `GetTickCount()` to its value `Session0Time`.
2. `InitializeShutdownModule` ([RPC servers](#rpc-servers), run levels).
3. Environment block: `RtlCreateEnvironment`, `UpdateUserEnvironment` (variables of `Session Manager\Environment`), `SetupBasicEnvironment` (`ProgramFiles`, `CommonProgramFiles` from `Software\Microsoft\Windows\CurrentVersion` `ProgramFilesDir` / `CommonFilesDir`, `TEMP`…).
4. `Winlogon\DontWatchSysProcs`: when non-zero, `IgnoreSystemProcessDeath` is set and the death of a system process doesn't reboot the phone.
5. `services.exe`: [StartSystemProcess](#startsystemprocess) with type 0, creation flags `CREATE_PROTECTED_PROCESS | DETACHED_PROCESS` (0x40008), protection level 0 (`PROTECTION_LEVEL_WINTCB_LIGHT` ?), watched.
6. On a clean setup install: creates the event `\INSTALLATION_SECURITY_HOLD` (`CreateLsaStallEvent`), which holds the LSA.
7. Crash reporting (skipped during setup):
   * if `SYSTEM\CurrentControlSet\Control\Watchdog\Display` `EventFlag` is a non-zero DWORD and `%SystemRoot%\MEMORY.DMP` exists, writes `DumpFile` = the dump path and `TempDestination` = 1 in `\Registry\Machine\System\CurrentControlSet\Control\CrashControl\MachineCrash`, then sets `EventFlag` back to 0;
   * if `CrashControl\MachineCrash` exists, or `SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability` has `ShutdownEventPending` or `ShutdownStateSnapshot`, starts `WerFault.exe -k -c ` (type 3, not watched).
8. `lsass.exe`: ETW event `WIEvt_Wininit_Lsa_Ppl` (protection level), then [StartSystemProcess](#startsystemprocess) with type 1, `CREATE_PROTECTED_PROCESS` (0x40000), protection level 4 (`PROTECTION_LEVEL_LSA_LIGHT` ?), watched.
9. `RtlDestroyEnvironment`. In staged boot, waits for `StagedBootCompletionEvent`.

The path of `services.exe` and `lsass.exe` gets ` -setup` when setup runs (`GetExePathAndOptions`, 0x405CD8, flag table `SystemProcessFlags` = {1, 1, 0, 0}); a type with flag 2 would get ` -winlogon <wininit pid>` (none here).

### StartSystemProcess

`StartSystemProcess` (0x405B14) calls `CreateProcessW(NULL, <command line>, …, creation flags | EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT, <environment>, NULL, &si, &pi)`. With `CREATE_PROTECTED_PROCESS`, the attribute list has `PROC_THREAD_ATTRIBUTE_PROTECTION_LEVEL` (0x2000B) = the protection level.

`STARTUPINFOEXW` (0x48 bytes):

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0x48 | `cb` |
| 0x08 | 4 | `L""` | `lpDesktop` |
| 0x0C | 4 | command line | `lpTitle` |
| 0x2C | 4 | 0x81 | `dwFlags` = `STARTF_FORCEOFFFEEDBACK` (0x80, from the caller) \| `STARTF_USESHOWWINDOW` |
| 0x30 | 2 | 5 | `wShowWindow` = `SW_SHOW` |
| 0x44 | 4 | attribute list | `lpAttributeList`, only for a protected process |

Watch flags (5th stack parameter, 2 for `services.exe` / `lsass.exe`): bit 0 adds the handle to `hSystemProcesses` (up to 64, waited for at shutdown by `WaitForSystemProcesses`). Bit 1 registers `SystemProcessDeath` on the process handle (`RtlRegisterWait`, `WT_EXECUTEONLYONCE`). When a watched process ends (and neither `IgnoreSystemProcessDeath` nor setup applies), `SystemProcessDeathWorker` (0x4113B4) writes event 0xC00003F7 (process name, exit code). It then calls `InitiatePanicSystemShutdown` with the message "The system process '%s' terminated unexpectedly with status code %d. The system will shut down and restart." (string resource 0xBB8 / 0xBB9 when present), and the phone reboots.

### RPC servers

| Interface | Version | Endpoint | Opnums | Started by |
|-----------|---------|----------|--------|------------|
| `{894DE0C0-0D55-11D3-A322-00C04FA321A1}` (InitShutdown) | 1.0 | `ncacn_np:[\PIPE\InitShutdown]`, flags 0x90 | 0 `s_BaseInitiateShutdown`, 1 `s_BaseAbortShutdown`, 2 `s_BaseInitiateShutdownEx` | `MyRpcpStartRpcServer` (0x40688C), unless `Policies\System` `DisableShutdownNamedPipe` is set |
| `{D95AFE70-A6D5-4259-822E-2C84DA1DDB0D}` (WindowsShutdown) | 1.0 | `ncalrpc:[WindowsShutdown]`, flags 8; also `ncacn_ip_tcp` (dynamic port, `RPC_C_AUTHN_GSS_NEGOTIATE`, object UUID `{765294BA-60BC-48B8-92E9-89FD77769D91}` registered in the endpoint mapper) | 0 `s_WsdrInitiateShutdown`, 1 `s_WsdrAbortShutdown`, 2 `s_WsdrCheckForHiberboot` | `WsdpStartShutdownServer` (0x4067F8); TCP in `WsdpInitializeRemoteShutdown` (0x404A34), after `RPCSS` runs, unless `Policies\System` `DisableRemoteShutdownRPCInterface` is set. Security callback `WsdpRpcSecurityCallback` |
| `{76F226C3-EC14-4325-8A99-6A46348418AF}` (WMsg) | 1.0 | `ncalrpc` dynamic, object UUID `b08669ee-8cb5-43a5-a017-84fe<session id>` in the endpoint mapper, flags `RPC_IF_ALLOW_LOCAL_ONLY \| RPC_IF_ALLOW_SECURE_ONLY` | 0 `I_WMsgSendMessage`, 1 `I_WMsgkSendPSPMessage`, 2 `I_WMsgSendNotifyMessage`, 3 `I_WMsgSendReconnectionUpdateMessage` | `StartWMsgServer` (0x404B5C) in a work item, after `RPCSS` runs. Security callback `WmsgRpcSecurityCallback` |
| `{76F226C3-EC14-4325-8A99-6A46348418AE}` (WMsgK) | 1.0 | `ncalrpc:[WMsgKRpc<LUID><session id>]` | 0 `I_WMsgkSendMessage`, 1 `I_WMsgkSendPSPMessage` | `StartWMsgKServer` (0x405188). Security callback `WmsgkRpcSecurityCallback` |

The WMsg calls go to the handlers registered by `WMsgClntInitialize`: `WMsgMessageHandler` (0x4129A0), `WMsgPSPHandler` (power state), `WMsgNotifyHandler`, `WMsgBroadcastMessageHandler`, `WMsgBroadcastNotifyHandler`.

RPC clients: `{76F226C3-EC14-4325-8A99-6A46348418AF}` (WMsg of another session, `WmsgpConnect` 0x40E6C4, same object UUID scheme) and `{B2507C30-B126-494A-92AC-EE32B6EEB039}` (LogonUI, `ncalrpc` with object UUID `3BDB59A0-D736-4D44-9074-C1EE<session id>`, used by `WluiDisplayStatus`, `WluiSignalShutdown`, `WluiAbort`).

`InitializeRunLevelHandling` (0x4069CC) connects to the session manager (`RtlConnectToSm`), sends it a message (`RtlSendMsgToSm`, API 10) with the name `Wininit`, and registers `RunLevelSwitchCb` on an event.

### Shutdown

`WinInitShutdown` (0x412288, shutdown action, flags):

1. `NtSetThreadExecutionState`, `SeShutdownPrivilege`, status message, `ExitWindowsEx` (if present; otherwise `CallUserExitWindowsEx` through `CsrClientCallServer`).
2. Waits for the system processes (`WaitForSystemProcesses`), then `PerformSystemRestore`.
3. With flag 0x400: signals LogonUI and waits up to 10 s for `Global\LogonUIExitEvent`, then starts `bootim.exe /startpage:1` in the console session (`LaunchBootShell`, 0x40F52C, initial exit code 0xBC2) and waits for it. If its exit code is 0x281, the shutdown action becomes 2.
4. `HeapDestroy`, `WppCleanupUm`, `NtShutdownSystem(action)`.

`SbGetKeyData`, `WxServerThread` and `InitiatePanicSystemShutdown` also call `NtShutdownSystem`.

### Debugger

`InitDebugHelpers` (0x4075E0) acts only when a kernel debugger is present (`SystemKernelDebuggerInformation`) or the process is being debugged. It installs `MyUnhandledExceptionFilter`. Unless `Winlogon\NoDebugThread` is non-zero, a 60 s timer (`WlpPeriodicBreak`) lets the debugger break into wininit or a system process (`Breakin`: remote thread on `ntdll!DbgBreakPoint`) or attach `ntsd` (`Attach`).

### Registry

All keys are under `HKLM`.

| Key | Value | Access | Use |
|-----|-------|--------|-----|
| `SYSTEM\CurrentControlSet\Control\WinInit` | `Headless` | R | Headless system |
| `SYSTEM\CurrentControlSet\Control\WinInit` | `TracingControlLevel` | R | WPP `umstartup` session |
| `SYSTEM\CurrentControlSet\Control\Wininit` | `RestoreInProgress`, `RestoreModule`, `RestoreFunction` | R, D | System restore at shutdown |
| `SYSTEM\CurrentControlSet\Control\Session Manager` | `BootShell` | R | [BootShell](#bootshell) |
| `SYSTEM\CurrentControlSet\Control\Session Manager\Environment` | all | R | Environment of the system processes |
| `System\CurrentControlSet\Control\Lsa` | `SecureBoot`; subkeys `JD`, `Skew1`, `GBG`, `Data` (class names) | R | [SysKey](#syskey) |
| `System\CurrentControlSet\Control\MiniNT` | (key) | R | WinPE mode |
| `system\currentcontrolset\control\stagedboot` | `Session0Time` | W | Staged boot |
| `SYSTEM\CurrentControlSet\Control\Watchdog\Display` | `EventFlag` | R, W | Display watchdog crash |
| `SYSTEM\CurrentControlSet\Control\CrashControl\MachineCrash` | `DumpFile`, `TempDestination` | W | Dump to report |
| `SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability` | `ShutdownEventPending`, `ShutdownStateSnapshot` | R | Failed shutdown to report |
| `Software\Microsoft\Windows NT\CurrentVersion\Winlogon` | `DontWatchSysProcs`, `SaveDumpStart`, `DisableLockWorkstation`, `NoDebugThread`, `ReportBootOk`, `AutoAdminLogon` (deleted on a clean install), `ShutdownFlags` | R / W | See above |
| `Software\Microsoft\Windows NT\CurrentVersion\Windows` | `LoadAppInit_DLLs`, `AppInit_DLLs` | R | ETW report only |
| `Software\Microsoft\Windows NT\CurrentVersion\AeDebug` | `BpidDebugger` | R | ntsd path |
| `Software\Microsoft\Windows\CurrentVersion\Policies\System` | `DisableShutdownNamedPipe`, `DisableRemoteShutdownRPCInterface` | R | RPC servers |
| `Software\Microsoft\Windows\CurrentVersion` | `ProgramFilesDir`, `CommonFilesDir` | R | Environment |
| `System\CurrentControlSet\Services\Tcpip\Parameters` | `NV Hostname` → `Hostname`, `NV Domain` → `Domain` | R, W | Host name |
| `Software\Policies\Microsoft\System\DNSclient` | `NV PrimaryDnsSuffix` → `PrimaryDnsSuffix` | R, W | DNS suffix |
| `SYSTEM\Setup` | `SetupType`, `Respecialize`, `Cmdline`, `RespecializeCmdLine`, `RespecializeFailures`, `SystemSetupInProgress`, `SetupShutdownRequired` | R, W | Setup |
| `Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData` | (tree) | D | Deleted by `WluiStartup` |

### Named objects

| Name | Type | Use |
|------|------|-----|
| `Global\FirstWinlogonCheck`, `Global\WinlogonLogoff` | Event | Created at start |
| `Global\BootShellComplete` | Event | Waited for before the start-up ([BootShell](#bootshell)) |
| `Global\UMSServicesStarted` | Event | Set after the start-up on a headless system |
| `StagedBootCompletionEvent` | Event | Staged boot |
| `\INSTALLATION_SECURITY_HOLD` | Event | Holds the LSA during a clean install |
| `Global\LogonUIExitEvent` | Event | End of LogonUI at shutdown |
| `\Security\WxApiPort` | LPC port | Boot key for the LSA ([SysKey](#syskey)) |
| `\PIPE\InitShutdown`, `WindowsShutdown`, `WMsgKRpc…` | RPC endpoints | [RPC servers](#rpc-servers) |

### Events

* ETW provider `{206F6DEA-D3C5-4D10-BC72-989F03C8B84B}` (`MS_Wininit_Provider`): `WIEvt_Wininit_Lsa_Ppl`, `WIEvt_AppInit_DLLs_Enabled`, `WIEvt_WaitForWinstationShutdown_Start/Stop`, `WIEvt_PreShutdownNotification_Start/Stop`, `WLEvt_WluiServerStartup_*`…
* WPP control GUID `{C2BA06E2-F7CE-44AA-9E7E-62652CDEFE97}`.
* Event log source `Wininit` (`ReportWininitEvent`, 0x40D6E8): 0x400003E9 (autochk log), 0xC00003F7 (system process died), 0xC0000BBA, 0x80000BBB (remote shutdown not available), 0x80000BBC (`\INSTALLATION_SECURITY_HOLD` not created).
