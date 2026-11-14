## mwdbgsrv.exe

User-mode debugging process server of Windows Phone 8.1: it lets a debugger running on the PC (WinDbg / dbgeng with `-premote`) list, start, attach to and debug the processes of the phone over the network.  
`mwdbgsrv.exe` is the native-NT port of `dbgsrv.exe` (its own usage text and `DbgPrint` calls still call it `ntdbgsrv`): 102 400 bytes for ARM, 396 functions, full symbols (`mwdbgsrv.pdb`). It's a native application (entry point `NtProcessStartupW`, imports only `ntdll.dll` and `WS2_32.dll`): it has no console, so every message (usage, errors) goes to `DbgPrint`, visible only with a kernel debugger. The Win32 functions it needs (`CreateFileW`, `DeviceIoControl`, `ReadFile`, named pipes, COM ports, events…) are re-implemented in the binary on top of the `Nt*` calls.  
It serves the dbgeng interface `IUserDebugServices` (class `LiveUserDebugServices`) through the debugger RPC (`DbgRpc*`, the private RPC of dbgeng, not MS-RPC) over one transport chosen on the command line.

Location on the phone: ?  
Started by: ? (no caller found among the analysed binaries; it's meant to be started by hand or by the PC tools).

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | Process / thread / memory: `NtOpenProcess`, `NtOpenThread`, `NtSuspendThread`, `NtResumeThread`, `NtGetContextThread`, `NtSetContextThread`, `NtReadVirtualMemory`, `NtWriteVirtualMemory`, `NtProtectVirtualMemory`, `NtQueryVirtualMemory`, `NtAllocateVirtualMemory`, `NtFreeVirtualMemory`, `NtFlushInstructionCache`, `NtDuplicateObject`, `NtQueryInformationProcess`, `NtSetInformationProcess`, `NtQueryInformationThread`, `NtQuerySystemInformation`, `NtQueryObject`, `NtQueryMutant`, `NtQueryEvent`, `NtQuerySection`, `NtTerminateProcess`, `RtlCreateProcessParameters`, `RtlCreateUserProcess`, `RtlDestroyProcessParameters`, `RtlCreateUserThread`, `RtlExitUserThread`, `CsrGetProcessId`<br>Debugging: `NtCreateDebugObject`, `NtDebugActiveProcess`, `NtRemoveProcessDebug`, `NtDebugContinue`, `NtWaitForDebugEvent`, `NtSetInformationDebugObject`, `NtSystemDebugControl`, `DbgUiConvertStateChangeStructure`, `DbgUiGetThreadDebugObject`, `DbgUiSetThreadDebugObject`, `DbgUiIssueRemoteBreakin`, `DbgBreakPoint`, `DbgPrint`, `DbgPrompt`, `RtlGetFunctionTableListHead`, `RtlGetUnloadEventTrace`, `LdrLoadDll`, `LdrGetProcedureAddress`, `LdrUnloadDll`<br>Files / devices / objects: `NtCreateFile`, `NtOpenFile`, `NtReadFile`, `NtWriteFile`, `NtSetInformationFile`, `NtDeviceIoControlFile`, `NtFsControlFile`, `NtCreateNamedPipeFile`, `NtCancelIoFile`, `NtCreateSection`, `NtOpenSection`, `NtMapViewOfSection`, `NtUnmapViewOfSection`, `NtCreateEvent`, `NtOpenEvent`, `NtSetEvent`, `NtResetEvent`, `NtClearEvent`, `NtWaitForSingleObject`, `NtWaitForMultipleObjects`, `NtDelayExecution`, `NtClose`<br>Registry: `NtOpenKey`, `NtQueryValueKey`, `NtSetValueKey`, `NtDeleteValueKey`<br>Security: `NtOpenProcessToken`, `NtOpenThreadToken`, `NtQueryInformationToken`, `NtAdjustPrivilegesToken`, `RtlCreateSecurityDescriptor`, `RtlSetDaclSecurityDescriptor`, `RtlDefaultNpAcl`, `RtlCreateAcl`, `RtlAddAccessAllowedAce`, `RtlAddAccessDeniedAce`, `RtlAllocateAndInitializeSid`, `RtlLengthSid`, `RtlFreeSid`<br>Runtime: `RtlNormalizeProcessParams`, `RtlAllocateHeap`, `RtlReAllocateHeap`, `RtlFreeHeap`, `Rtl*String*`, `RtlDosPathNameToNtPathName_U`, `RtlDetermineDosPathNameType_U`, `RtlSetEnvironmentVariable`, `RtlNtStatusToDosError`, `RtlFindMessage`, `RtlGetVersion`, `Rtl*CriticalSection`, `RtlDeactivateActivationContextUnsafeFast`, `RtlFlushSecureMemoryCache`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `RtlUnhandledExceptionFilter`, `__C_specific_handler`, C runtime (`_vsnprintf`, `_vsnwprintf`, `vswprintf_s`, `swscanf_s`, `wcstoul`, `_wtol`, `wcs*`, `_wcsicmp`, `_wcsnicmp`, `_memicmp`, `iswspace`, `mem*`) |
| WS2_32.dll | `WSAStartup`, `WSASocketW`, `socket`, `bind`, `listen`, `accept`, `connect`, `getsockname`, `setsockopt`, `ioctlsocket`, `shutdown`, `closesocket`, `htons`, `ntohs`, `WSAAddressToStringW`, `WSACreateEvent`, `WSAResetEvent`, `WSACloseEvent`, `WSASend`, `WSARecv`, `WSAGetOverlappedResult`, `WSAGetLastError` (TCP transport) |

The `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind` / `RtlUnhandledExceptionFilter` / `__C_specific_handler` imports are the `/GS` and exception boilerplate. There's no export other than the entry point `NtProcessStartupW` (0x411868).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| DLL named by the debugger | `LdrLoadDll`, then `LdrGetProcedureAddress("OutOfProcessFunctionTableCallback")`, `LdrUnloadDll` (`LiveUserDebugServices::GetOutOfProcessFunctionTableW`, 0x410034) | Out-of-process function table callback of a dynamic function table of the target (JIT code), loaded on request of the debugger |
| Process started by `-c` / `-cs`, or by the debugger | `RtlCreateUserProcess` (`NtSimpleCreateProcess`, 0x40E8B4) | Target process, image path = first token of its command line |
| `ole32.dll`, `oleaut32.dll`, `powrprof.dll`, `verifier.dll`, `wldp.dll` | Named in `DYNAMIC_CALLS_DESC` tables (`g_Ole32CallsDesc`, `g_OleAut32CallsDesc`, `g_PowrProfCallsDesc`, `g_VerifierCallsDesc`, `g_WldpCallsDesc`) but **never loaded**: `InitDynamicCalls` (0x4064F0) only fills the ntdll table (statically bound) and returns `E_NOTIMPL` (0x80004001) for the others | The features that need them are dead in this build: firewall port mappings of `ICFEnable` (`CoCreateInstance` of `HNetCfg.FwPolicy2` {E2B3C97F-6AE1-41AC-817A-F6F92166D7DD}, `HNetCfg.FwMgr` {304CE942-6E39-40D8-943A-B913C40C9CD4}, `HNetCfg.HNetShare` {5C63C1AD-3956-4FF8-8486-40034758315B}), `GetProcessorPowerInfo` (`CallNtPowerInformation`), application verifier handle traces (`VerifierEnumerateResource`), and the WLDP lockdown check (`WldpGetLockdownPolicy`, `WldpIsDebugAllowed`: debugging is always allowed) |

### Parameters

`wmain` (0x404520) is reached through `NtProcessStartupW` → `NtProcessStartupW_AfterSecurityCookieInitialized` (0x41167C), which splits `ProcessParameters->CommandLine` on white space (no quote handling) and exits with `NtTerminateProcess(-1, <return value of wmain>)`.

Syntax (usage text at 0x4013B0): `mwdbgsrv.exe -t <transport> [-sifeo <image.ext>] [-x] [-c[s] <args...>] [-pc <args...>]`. The options are read from left to right:

| Command line | Usage | Exit code |
|---|---|---|
| `-t <transport>` | Transport of the server, mandatory, format `<name>:<param>=<value>,<param>=<value>…`, see [transports](#transports). A last argument that doesn't start with `-` or `/` is also taken as the transport (`mwdbgsrv.exe tcp:port=5005`). Without a transport: usage. | |
| `-sifeo <image.ext>` | Image name whose `Image File Execution Options` `Debugger` value is suspended while the process of `-c` / `-cs` is created (see [registry](#registry)). Ignored without `-c` / `-cs`. | |
| `-x` | Ends the parsing: the rest of the command line is ignored. | |
| `-c <command line>` | Ends the parsing. The rest of the **raw** command line (searched in `CommandLine` for ` -c ` after the arguments already read, then white space skipped) is the command line of a process started at once by `LiveUserDebugServices::CreateProcessW` (0x40EA58) with `DEBUG_CREATE_PROCESS_OPTIONS` = { `CreateFlags` 0, `EngCreateFlags` 1 (`DEBUG_ECREATE_PROCESS_INHERIT_HANDLES`), 0, 0 }: the process isn't debugged, it runs until a debugger attaches to it through the server. Its process and thread handles are closed. | |
| `-cs <command line>` | Same as `-c` with `CreateFlags` = 4 (`CREATE_SUSPENDED`): the process is left suspended (no `NtResumeThread`). | |
| `-pc <command line>` | Ends the parsing. The rest of the command line is kept in `g_UserServicesCreateCommandLine` and no process is started: it's the command line used when the debugger asks to create a process with `DEBUG_ECREATE_PROCESS_USE_IMPLICIT_COMMAND_LINE` (`EngCreateFlags` bit 4; without `-pc` that request fails with `E_INVALIDARG`). | |
| any other argument starting with `-` or `/`, or a bad command line | `PanicExit("Invalid Command Line", <usage>)` (0x403FB4), or `"Unable to locate start of command"` when ` -c ` / ` -cs ` / ` -pc ` isn't found in the raw command line | 1 |

Then `Run` (0x4043B0):

1. `DbgPrint("Running %s with '%s'\n", L"ntdbgsrv", transport)`.
2. `InitDynamicCalls(&g_NtDllCallsDesc)` (fills the ntdll call table) and `LiveUserDebugServices::Initialize` (0x40CE40): creates the unnamed event `g_UserServicesUninitializedEvent` (`NtCreateEvent`, manual reset), reads the OS version and returns the flags 7 (debug object supported, WLDP check skipped).
3. `DbgRpcCreateServer(transport)` (0x4077B8): `DbgRpcInitializeTransport` builds the transport object and parses its parameters (`ParameterStringParser::ParseParameters`, 0x411880), `CreateServer` opens the listening endpoint, then a thread `DbgRpcServerThread` (0x40759C) accepts the connections. For each client: handshake, identity, password check (the `Password` parameter is hashed by `Base64HashPassword`, 0x407A08; errors such as `"%X: Client sent incorrect password"` go to `DbgPrint`), then `LiveUserDebugServicesFactory::CreateInstance` (0x404300) creates a `LiveUserDebugServices` object (only for `IID_IUserDebugServices` {A7BA24C4-E4FB-4625-A8FC-B1CB1FD51F53}, otherwise `E_NOINTERFACE`) and a `DbgRpcClientThread` serves the calls.
4. With `-c` / `-cs`: `SuspendIfeoDebugger`, `CreateProcessW`, restore of the `Debugger` value, close of the handles.
5. Waits forever on `g_UserServicesUninitializedEvent`, which `UserDebugServices::Uninitialize(Global = TRUE)` (0x40CCFC) sets when a client closes the server, deregisters the servers and returns 0.

Every failure of steps 2–4 ends in `PanicStatus` (`DbgPrint("Error 0x%08X: <step>")`, steps named `InitDynamicCalls`, `LiveUserDebugServices::Initialize`, `StartProcessServer`, `Suspend Image File Execution Options`, `CreateProcessW`) and exit code 1; a bad transport parameter ends in `LnkOut` (0x4042AC) with the message and exit code 1.

| Exit code | Meaning |
|---|---|
| 0 | The server was closed by a client (`Uninitialize` with `Global` = TRUE) |
| 1 | Bad command line, bad transport parameter, or failure of the start-up (message on `DbgPrint`) |
| NTSTATUS | The startup code couldn't allocate the `argv` array (`STATUS_NO_MEMORY`) |

### Transports

Names in `g_DbgRpcTransportNames` (0x4132E0), compared without case. Parameters accepted by every transport (`DbgRpcTransport::SetParameter`, 0x407CB4): `Password=<text>`, `Hidden`, `CRetries=<n>`, `CRetryDelay=<n>`; any other name ends in `"%s parameters: %s is not a valid parameter"`.

| Index | Name | Class | Parameters | Server endpoint |
|---|---|---|---|---|
| 0 | `tcp` | `DbgRpcTcpTransport` | `port=<n>` or `port=<first>:<last>` (16 bits; the range is tried until a `bind` works), `ipversion=4\|6`, `cliconlim=<n>`, `ICFEnable`, `sock=<socket>[,<socket>…]` (up to 4 already-open sockets), `server=<name>`; `clicon=` and `ReqHost=` always fail ("the specified server (%s) does not exist": no name resolution in this build) | `WSASocketW`, `bind`, `getsockname`, `setsockopt(SOL_SOCKET)`, `listen` (`CreateServerSocket`, 0x408C64); with `ICFEnable`, `AddBestPortMapping(port)`, which always fails here (`"%X: Unable to add ICF port mapping, %ws"`) |
| 1 | `npipe` | `DbgRpcNamedPipeTransport` | `pipe=<name>` (printf format, `%d` = PID of the server), `server=<name>`, `ICFEnable` (tries to open the ports 139 and 445, fails the same way) | `\Device\NamedPipe\<name>`: first opened with `CreateFileW` to fail with `"%X: Pipe %ws is already in use"` (0x800700B7) if it exists; each connection creates a pipe instance (`NtCreateNamedPipeFile`) and waits on `ConnectNamedPipe` |
| 2 | `ssl` | — | — | Recognised but no class is built: `DbgRpcInitializeTransport` returns `E_OUTOFMEMORY` (0x8007000E) → `"Error 0x8007000E: StartProcessServer"` |
| 3 | `spipe` | — | — | Same as `ssl` |
| 4 | `1394` | `DbgRpc1394Transport` | `Channel=<n>` | `\\.\Dbg1394_User`, after `Load1394HostDebugger`, see [devices](#devices-and-ioctls-sent) |
| 5 | `com` | `DbgRpcComTransport` | `Port=<n>` (→ `\Device\Serial<n>`), `Port=COM<n>` (→ `\\.\COM<n>`) or any device name, `Baud=<rate>`, `Channel=<0..254>` | `NtCreateFile` (`GENERIC_READ \| GENERIC_WRITE`), `SetupComm`, baud rate, `SetCommTimeouts` (`OpenComPort`, 0x40C420); the COM functions are `IOCTL_SERIAL_*` sent with `NtDeviceIoControlFile` |
| 6 | `section` | `DbgRpcSectionTransport` | `Name=<NT object name>` (≤ 64 characters) | Shared memory: section `<Name>_Mem` (`NtCreateSection`, 0x8000 bytes, `OBJ_OPENIF`, name used as-is, so it must be a full NT path) and events with the suffixes `_Read`, `_Write`, `_SrvRead`, `_SrvWrite`, `_Conn` (exact roles ?) |

Example from the usage text: `ntdbgsrv -t npipe:pipe=foobar`. The client side is a dbgeng debugger started with `-premote <same transport>,server=<phone>`.

### IUserDebugServices

Methods of `LiveUserDebugServices` reachable remotely through the `SFN_IUserDebugServicesN_*` stubs (0x410488–0x41167C, listed in address order): `QueryInterface`, `Release`, `Initialize`, `Uninitialize`, `GetTargetInfo`, `GetConnectionInfo`, `GetProcessorId`, `GetProcessorPowerInfo`, `GetGenericProcessorFeatures`, `GetSpecificProcessorFeatures`, `GetFileVersionInformationW`, `GetProcessIds`, `GetProcessIdByExecutableNameW`, `GetProcessDescriptionW`, `GetProcessInfo`, `AttachProcess`, `DetachProcess`, `CreateProcessW`, `TerminateProcess`, `AbandonProcess`, `GetProcessExitCode`, `CloseHandle`, `SetProcessOptions`, `SetDebugObjectOptions`, `GetProcessDebugObject`, `DuplicateHandle`, `ReadVirtual`, `WriteVirtual`, `QueryVirtual`, `ProtectVirtual`, `AllocVirtual`, `FreeVirtual`, `ReadHandleData`, `SuspendThreads`, `ResumeThreads`, `GetThreadBasicInfo`, `GetContext`, `SetContext`, `GetProcessDataOffset`, `GetThreadDataOffset`, `GetProcessWowDataOffset`, `GetProcessCookie`, `DescribeSelector`, `GetCurrentTimeDateN`, `GetCurrentSystemUpTimeN`, `GetProcessUpTimeN`, `GetProcessTimes`, `RequestBreakIn`, `WaitForEvent`, `ContinueEvent`, `InsertCodeBreakpoint`, `RemoveCodeBreakpoint`, `InsertDataBreakpoint`, `RemoveDataBreakpoint`, `GetLastDataBreakpointHit`, `GetFunctionTableListHead`, `GetOutOfProcessFunctionTableW`, `GetUnloadedModuleListInfo`, `LoadLibrary`, `FreeLibrary`, `CreateDirectoryW`, `CreateFileW`, `ReadFile`, `WriteFile`, `CloseFile`, `GetProcessDescriptors`, `GetProcessMiscInformation`, `DbgOpenToken`, `DbgDuplicateToken`, `DbgQueryTokenInfo`, `DbgCloseToken`, `DbgIsProcess32`, `DbgIsModule32`.

Notes:

- `AttachProcess` uses `NtCreateDebugObject` + `NtDebugActiveProcess`; `WaitForEvent` / `ContinueEvent` use `NtWaitForDebugEvent` / `NtDebugContinue`; `RequestBreakIn` uses `DbgUiIssueRemoteBreakin`. `CreateProcessW` and the attach first enable `SeDebugPrivilege` (privilege 20, `EnableDebugPrivilege`, 0x406898).
- `CreateProcessW` (0x40EA58): the initial directory must be NULL (`E_NOTIMPL`); `CreateFlags & 0x400` (`DEBUG_CREATE_PROCESS_NO_DEBUG_HEAP`) sets `_NO_DEBUG_HEAP=1`, `EngCreateFlags & 2` (`DEBUG_ECREATE_PROCESS_USE_VERIFIER_FLAGS`) sets `_VERIFIER_SETTING=0x<VerifierFlags>` in the environment of the server, inherited by the child, and both are removed afterwards. With `CreateFlags & 3` (`DEBUG_PROCESS` / `DEBUG_ONLY_THIS_PROCESS`) the debug object is passed to `RtlCreateUserProcess`.
- `RemoveCodeBreakpoint` returns `E_UNEXPECTED` (0x8000FFFF), `CreateDirectoryW` `E_NOTIMPL`, `GetSpecificProcessorFeatures` `E_NOINTERFACE`: the debugger handles software breakpoints itself with `WriteVirtual`.
- `GetProcessDescriptionW` builds lines with `"System Process"`, `"  Command Line: "`, `"%sSession: %d"`, `"  User: "` (command line read from the PEB of the target, user from its token).

### Registry

| Key | Value | Use |
|---|---|---|
| `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<image.ext>` (opened as `\Registry\Machine\…` with `NtOpenKey`, `KEY_ALL_ACCESS`) | `Debugger` (REG_SZ or REG_EXPAND_SZ, ≤ 1056 bytes) | With `-sifeo <image.ext>`: `SuspendIfeoDebugger` (0x404180) reads the value (`NtQueryValueKey`, `KeyValuePartialInformation`) and deletes it, so that the process of `-c` isn't started under the IFEO debugger; `Run` writes it back after `CreateProcessW` (`"Error: Unable to set the ifeo debugger key value"` on failure). A missing key or value isn't an error (`-sifeo` is then ignored); another value type gives `0xD000000D`. |

### Devices and IOCTLs sent

Only by the `1394` transport (IEEE 1394 host debugging, no such hardware on the Lumia 520).

| Device | IOCTL | CTL_CODE | Use |
|---|---|---|---|
| `\\.\1394BUS0` | 0x220400 | `FILE_DEVICE_UNKNOWN`, function 0x100, `METHOD_BUFFERED`, `FILE_ANY_ACCESS` | `Load1394HostDebugger` (0x40C4EC): input = a heap block holding the device ID `"USER_HOST_DEBUGGER"`, adds the virtual 1394 device whose driver creates `Dbg1394_User` ? |
| `\\.\Dbg1394_User` | 0x220804 | `FILE_DEVICE_UNKNOWN`, function 0x201, `METHOD_BUFFERED`, `FILE_ANY_ACCESS` | `DbgRpc1394Transport::Setup` (0x409D78) with this code for the server (`CreateServer`), input/output `_DBGUSER_IOCTL_INPUT_OUTPUT` with the channel ? |
| `\\.\Dbg1394_User` | 0x220808 | function 0x202 | Used by `Setup` / `Read` ? |
| `\\.\Dbg1394_User` | 0x22080C | function 0x203 | Used by `Setup` / `Write` ? |

These codes have nothing to do with the identical codes of [qcgnss.sys](../drivers/qcgnss.md) (different device, generic `FILE_DEVICE_UNKNOWN` numbering).

### GUIDs

| GUID | Meaning |
|---|---|
| {A7BA24C4-E4FB-4625-A8FC-B1CB1FD51F53} | `IID_IUserDebugServices`, the only interface the factory creates |
| {E2B3C97F-6AE1-41AC-817A-F6F92166D7DD} / {98325047-C671-4174-8D81-DEFCD3F03186} | `CLSID_NetFwPolicy2` / `IID_INetFwPolicy2` (dead code, ole32 not loaded) |
| {304CE942-6E39-40D8-943A-B913C40C9CD4} / {F7898AF5-CAC4-4632-A2EC-DA06E5111AF2} | `CLSID_NetFwMgr` / `IID_INetFwMgr` (dead code) |
| {5C63C1AD-3956-4FF8-8486-40034758315B} / {C08956B7-1CD3-11D1-B1C5-00805FC1270E} | `CLSID_NetSharingManager` / `IID_INetSharingManager` (dead code) |
