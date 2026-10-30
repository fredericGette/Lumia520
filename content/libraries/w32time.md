## w32time.dll

The Windows Time service (`W32Time`): the NTP client that sets the phone's clock from the time servers configured by [WPTimeSvc.dll](./wptimesvc.md).  
`w32time.dll` is the desktop Windows Time service built for the phone (352 256 bytes, 606 functions, public symbols). The code is the same: a svchost service DLL that hosts two internal time providers, `NtpClient` and `NtpServer`, and can load more providers from the registry. A clock-discipline thread applies the time samples of the input providers to the system clock (`SetSystemTimeAdjustment` to slew it, `NtSetSystemTime` to step it). The service runs the `W32Time` RPC server (MS-W32T interface, opnums 0…7) on `ncalrpc:[W32TIME_ALT]` and `ncacn_np:[\PIPE\W32TIME_ALT]`, and exports the client side of this interface (`W32TimeSyncNow`, `W32TimeQueryStatus`…). It also has the domain code (domain hierarchy, Netlogon signatures, RODC chaining), which is useless on a phone. The only phone-specific code is `IsMobileCore`. It checks a licence value and, when the value is set, loads SecRuntime.dll, so that the RPC endpoint and the interface are protected by the security descriptors of the phone's security model instead of the desktop security callback.  
On the phone the service is driven by [WPTimeSvc.dll](./wptimesvc.md#ntp-ntpsync). Before each NTP sync, WPTimeSvc.dll writes `Parameters\NTPServer` (and the `Config\FileLog*` values when logging is on), starts the `W32Time` service, and calls opnum 0 (`W32TimeSync`) over `ncalrpc:[W32TIME_ALT]`. It stops the service again afterwards. The time providers, the event log and the file log are configured under `HKLM\System\CurrentControlSet\Services\W32Time`.

Location on the phone: `C:\Windows\System32\w32time.dll` (`ServiceDll` of the `W32Time` service, hosted by `svchost.exe -k LocalService`, demand start).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `NtSetSystemTime`, `NtSetSystemInformation`, `EtwEventRegister`, `EtwEventUnregister`, `EtwEventWrite`, `RtlInitializeGenericTableAvl`, `RtlInsertElementGenericTableAvl`, `RtlLookupElementGenericTableAvl`, `RtlDeleteElementGenericTableAvl`, `RtlInitializeCriticalSection`, `RtlEnterCriticalSection`, `RtlLeaveCriticalSection`, `RtlDeleteCriticalSection`, `RtlInitializeResource`, `RtlAcquireResourceShared`, `RtlAcquireResourceExclusive`, `RtlConvertSharedToExclusive`, `RtlConvertExclusiveToShared`, `RtlReleaseResource`, `RtlDeleteResource`, `RtlImageNtHeader`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlInitUnicodeString`, `RtlNtStatusToDosError`, `RtlRaiseException`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| RPCRT4.dll | `RpcServerUseProtseqEpW`, `RpcServerRegisterIf3`, `RpcServerRegisterIfEx`, `RpcServerUnregisterIf`, `RpcServerInqDefaultPrincNameW`, `RpcServerRegisterAuthInfoW`, `RpcServerInqCallAttributesW`, `RpcImpersonateClient`, `RpcRevertToSelf`, `NdrServerCall2`, `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoW`, `RpcMgmtInqServerPrincNameW`, `RpcBindingFree`, `RpcStringFreeW`, `NdrClientCall2` |
| logoncli.dll | `DsGetDcNameW`, `DsGetSiteNameW`, `NetLogonGetTimeServiceParentDomain`, `NetLogonSetServiceBits`, `I_NetlogonGetTrustRid`, `I_NetlogonComputeServerDigest`, `I_NetlogonComputeClientDigest`, `I_NetlogonComputeServerSignature`, `I_NetlogonComputeClientSignature` |
| cryptdll.dll | `MD5Init`, `MD5Update`, `MD5Final` |
| WS2_32.dll (delay-load) | `WSAStartup`, `WSACleanup`, `socket`, `WSASocketW`, `bind`, `setsockopt`, `WSAIoctl`, `WSAEventSelect`, `sendto`, `closesocket`, `WSAGetLastError`, `GetAddrInfoW`, `FreeAddrInfoW`, `WSAAddressToStringW` |
| DSROLE.dll (delay-load) | `DsRoleGetPrimaryDomainInformation`, `DsRoleFreeMemory` |
| netutils.dll (delay-load) | `NetApiBufferFree` |
| SspiCli.dll (delay-load) | `LsaRegisterPolicyChangeNotification`, `LsaUnregisterPolicyChangeNotification` |
| USERENV.dll (delay-load) | `RegisterGPNotification`, `UnregisterGPNotification` |
| api-ms-win-security-sddl-l1-1-0.dll (delay-load) | `ConvertStringSecurityDescriptorToSecurityDescriptorW`, `ConvertSidToStringSidW` |
| api-ms-win-security-lsalookup-l1-1-1.dll (delay-load) | `LookupAccountSidLocalW` |
| api-ms-win-security-provider-l1-1-0.dll (delay-load) | `SetSecurityInfo` |
| api-ms-win-service-core-l1-1-1.dll | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` |
| api-ms-win-service-private-l1-1-1.dll | `I_ScSetServiceBitsW` |
| api-ms-win-service-management-l1-1-0.dll / l2-1-0.dll | `OpenSCManagerW`, `OpenServiceW`, `CreateServiceW`, `DeleteService`, `CloseServiceHandle`, `ChangeServiceConfigW`, `ChangeServiceConfig2W`, `QueryServiceConfigW` |
| api-ms-win-service-winsvc-l1-2-0.dll | `QueryServiceStatus` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetSystemTime`, `SetSystemTime`, `GetSystemTimeAsFileTime`, `GetSystemTimeAdjustment`, `SetSystemTimeAdjustment`, `GetTickCount`, `GetSystemInfo` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter`, `QueryPerformanceFrequency` |
| api-ms-win-core-timezone-l1-1-0.dll | `FileTimeToSystemTime` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegOpenKeyExA`, `RegCreateKeyExW`, `RegGetValueW`, `RegGetValueA`, `RegSetValueExW`, `RegDeleteValueW`, `RegEnumKeyExW`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleHandleExW`, `GetModuleFileNameW` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `WriteFile`, `GetFileSizeEx`, `FileTimeToLocalFileTime` |
| api-ms-win-core-processenvironment-l1-2-0.dll | `ExpandEnvironmentStringsW` |
| api-ms-win-core-threadpool-legacy-l1-1-0.dll, …-threadpool-private-l1-1-0.dll | `CreateTimerQueueTimer`, `ChangeTimerQueueTimer`, `DeleteTimerQueueTimer`, `QueueUserWorkItem`, `UnregisterWaitEx`, `RegisterWaitForSingleObjectEx` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `WaitForMultipleObjectsEx`, `Sleep`, critical sections |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `GetExitCodeThread`, `SetThreadPriority`, `SetThreadStackGuarantee`, `GetCurrentThread`, `GetCurrentThreadId`, `OpenThreadToken`, `OpenProcessToken`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-security-base-l1-2-0.dll | `PrivilegeCheck`, `AdjustTokenPrivileges`, `GetTokenInformation`, `GetSecurityDescriptorDacl` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventWrite` |
| api-ms-win-core-localization-l1-2-1.dll | `FormatMessageW` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle`, `GetHandleInformation`, `SetHandleInformation` |
| api-ms-win-core-heap-l1-2-0.dll, …-heap-obsolete-l1-1-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapFree`, `LocalAlloc`, `LocalFree` |
| api-ms-win-core-memory-l1-1-2.dll | `VirtualAlloc`, `VirtualProtect`, `VirtualQuery` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| msvcrt.dll | `malloc`, `free`, `memcpy`, `memset`, `memcmp`, `memmove`, `wcslen`, `wcscmp`, `_wcsicmp`, `_wcsnicmp`, `wcschr`, `wcsstr`, `wcscspn`, `wcstoul`, `_ultow`, `_vsnwprintf`, `qsort`, `log`, `floor`, `ceil`, `_set_se_translator`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

The msvcrt, rtlsupport, memory (`VirtualProtect`/`VirtualQuery`, stack guarantee), errorhandling (except `GetLastError`/`SetLastError`), `TerminateProcess` and delayload imports are the Visual C++ DLL CRT startup, C++/SEH exception, `/GS` cookie and delay-load helper code. The logoncli, DSROLE, SspiCli, USERENV, cryptdll and service-management imports are used only by the domain code and by `DllRegisterServer` / `DllInstall`.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| SecRuntime.dll | `LoadLibraryExW` + `GetProcAddress("QueryTransientObjectSecurityDescriptor" / "FreeTransientObjectSecurityDescriptor")` ([IsMobileCore](#ismobilecore-0x64ba6610)) | Security descriptors of the RPC endpoint and interface, only when the licence value `Microsoft-Windows-W32Time-License-SecurityRuntime` is set |
| ntdll.dll | `GetModuleHandleExW` + `GetProcAddress("NtQuerySystemInformation")` ([IsMobileCore](#ismobilecore-0x64ba6610)) | Licence value query (`SystemPolicyInformation`, class 0x86) |
| Time provider DLLs | `LoadLibraryExW(DllName)` + `GetProcAddress("TimeProvOpen" / "TimeProvCommand" / "TimeProvClose")` (`StartProvider`, 0x64BB4080) | Every enabled provider of `W32Time\TimeProviders\<name>` (`DllName`, `Enabled`, `InputProvider`). On the phone both `NtpClient` and `NtpServer` have `DllName` = `%systemroot%\system32\w32time.dll` (this DLL, [TimeProvOpen](#time-provider-interface)), and only `NtpClient` is enabled ([values on the phone](#values-on-the-phone)): no other DLL is loaded |
| File log (`Config\FileLogName`) | `CreateFileW` / `WriteFile` (`FileLog*`) | Debug log, written only when `FileLogName` is set. On the phone this is `<known folder {8C19F0BC-…}>\NonEtwLogs\w32time.log`, written by [WPTimeSvc.dll](./wptimesvc.md#ntp-ntpsync) |
| Netlogon service | logoncli.dll calls | Domain hierarchy and signed NTP; not used on a phone (not a domain member) |
| `ncacn_np:<server>[\PIPE\W32TIME]`, then `[\PIPE\W32TIME_ALT]` | `RpcStringBindingComposeW` (client exports) | W32Time RPC server of a local or remote machine ([RPC client](#rpc-client-exports)) |

No process is started and no COM object is created.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `fnW32TmI_ScSetServiceBits` | 0x64BC81E8 | Data: pointer to `I_ScSetServiceBitsW`, set by `SvchostEntry_W32Time` |
| 2 | `fnW32TmRegisterServiceCtrlHandlerEx` | 0x64BC81F0 | Data: pointer to `RegisterServiceCtrlHandlerExW` |
| 3 | `fnW32TmSetServiceStatus` | 0x64BC81EC | Data: pointer to `SetServiceStatus` |
| 4 | `DllInstall` | 0x64BA38A0 | `BOOL install` (ignored), `LPCWSTR cmdLine`, see [Registration](#registration) |
| 5 | `DllRegisterServer` | 0x64BA3964 | none |
| 6 | `DllUnregisterServer` | 0x64BA2A64 | none: `UnregisterService` |
| 7 | `SvchostEntry_W32Time` | 0x64BC2700 | `DWORD argc, LPWSTR *argv`: service entry point ([Service](#service)) |
| 8 | `SvchostPushServiceGlobals` | 0x64B9CFDC | `SVCHOST_GLOBAL_DATA *`, stored in `g_pSvcsGlobalData` |
| 9 | `TimeProvClose` | 0x64B9FDF0 | `TimeProvHandle` |
| 10 | `TimeProvCommand` | 0x64B9FE2C | `TimeProvHandle, TimeProvCmd, void *args` |
| 11 | `TimeProvOpen` | 0x64B9FE64 | `LPCWSTR name, TimeProvSysCallbacks *, TimeProvHandle *` |
| 12 | `W32TimeBufferFree` | 0x64B9DEC4 | `void *`: `LocalFree` of a buffer returned by the query exports |
| 13 | `W32TimeDcPromo` | 0x64BA2A78 | `DWORD flags` (domain controller promotion / demotion) |
| 14 | `W32TimeDeleteConfig` | 0x64BA2954 | `DWORD property`: deletes the registry value of a configuration property |
| 15 | `W32TimeGetNetlogonServiceBits` | 0x64B9E62C | `LPCWSTR server, DWORD *bits` (opnum 1) |
| 16 | `W32TimeLog` | 0x64B9E07C | `LPCWSTR server`, … (opnum 7) |
| 17 | `W32TimeQueryConfig` | 0x64BA29E0 | `DWORD property, DWORD *type, BYTE *data, DWORD *size`: reads a configuration value from the registry |
| 18 | `W32TimeQueryConfiguration` | 0x64B9E290 | `LPCWSTR server, W32TIME_CONFIGURATION_INFO **` (opnum 5) |
| 19 | `W32TimeQueryHardwareProviderStatus` | 0x64BA1834 | `LPCWSTR server, DWORD flags, LPWSTR provider, void **info`: `W32TimeQueryProviderStatus(…, 1, …)` (opnum 2) |
| 20 | `W32TimeQueryNTPProviderStatus` | 0x64BA1820 | Same, with type 0 (opnum 2) |
| 21 | `W32TimeQueryNtpProviderConfiguration` | 0x64B9E3BC | `LPCWSTR server, DWORD flags, LPWSTR provider, W32TIME_PROVIDER_CONFIG **` (opnum 4) |
| 22 | `W32TimeQuerySource` | 0x64B9E500 | `LPCWSTR server, LPWSTR *source` (opnum 3) |
| 23 | `W32TimeQueryStatus` | 0x64B9E164 | `LPCWSTR server, W32TIME_STATUS_INFO **` (opnum 6) |
| 24 | `W32TimeSetConfig` | 0x64BA2994 | `DWORD property, DWORD type, BYTE *data, DWORD size`: writes a configuration value to the registry |
| 25 | `W32TimeSyncNow` | 0x64B9E720 | `LPCWSTR server, ULONG wait, ULONG flags` (opnum 0) |
| 26 | `W32TimeVerifyJoinConfig` | 0x64BA2D34 | none (after a domain join) |
| 27 | `W32TimeVerifyUnjoinConfig` | 0x64BA2C84 | none (after leaving a domain) |
| 28 | `W32TmServiceMain` | 0x64BBDC0C | `DWORD argc, LPWSTR *argv` |

The query exports return HRESULT / Win32 errors, and their buffers (allocated by `MIDL_user_allocate`, `LocalAlloc`) are freed with `W32TimeBufferFree`. The configuration exports work on the registry directly (`myRegOpenKeyForProperty` and the `myReg*ValueForProperty` helpers), not over RPC.

There is no global object: the state is in `g_state` (`StateInfo`, around 0x64BC7620), `g_pnpstate` (NTP provider state) and `g_rgpiDispatchTable`.

### Startup

`_DllMainCRTStartup` (0x64B9B8AC): CRT initialisation; `DllMain` (0x64B9BC58) only returns TRUE. The ETW provider is registered by the service, not at load time.

### Service

**SvchostEntry_W32Time** (0x64BC2700) copies `RegisterServiceCtrlHandlerExW`, `SetServiceStatus` and `I_ScSetServiceBitsW` into the three exported pointers, then jumps to `W32TmServiceMain` with the same arguments.

**W32TmServiceMain** (0x64BBDC0C, disassembly only):
1. `RegisterServiceCtrlHandlerExW(L"w32time", W32TimeServiceCtrlHandler)`.
2. `InitShutdownState`, `InitGlobalState` (0x64BA40A8: events, the named event `W32TIME_NAMED_EVENT_SYSTIME_NOT_CORRECT` with the DACL `D:(A;;GA;;;LS)(A;;GA;;;SY)(A;;GA;;;BA)`, the privilege set used by the [security callback](#rpc-server)), `FileLogBegin`, `W32TimeInitializeEvents` (ETW).
3. If `argc > 1` and `argv[1]` is `task_started` (`_wcsicmp`), `bStartedAsTask` = 1: the service stops by itself once the clock has been synchronised ("Service was started as a task. Synchronization complete, shutting down now.").
4. Reads the configuration (`RefreshConfig`, `ReadConfig`), then `StartOrStopTimeSlipNotification`, `OpenSocketLayer` (`WSAStartup`), `RequestNetTopoChangeNotification`, the domain role (`HandleDomHierRoleChangeEvent`, `LsaRegisterPolicyChangeNotification`), the Netlogon service bits.
5. `StartClockDiscipline` (the `ClockDisciplineThread`, 0x64BB42FC), two timer-queue timers, `StartAllProviders`, `W32TmStartRpcServer` ([RPC server](#rpc-server)), `SERVICE_RUNNING`.
6. On failure: "Failed in initialization, w/o restart service", `SendServiceShutdown`, `FreeGlobalState`, `SERVICE_STOPPED` with the error.

**W32TimeServiceCtrlHandler** (0x64BC2038):

| Control | Action |
|---------|--------|
| `SERVICE_CONTROL_STOP` (1) | `SERVICE_STOP_PENDING`, `NotifyShutdown(0)` |
| `SERVICE_CONTROL_SHUTDOWN` (5) | `HandleManagerSystemShutdown` |
| `SERVICE_CONTROL_PARAMCHANGE` (6) | Sets the parameter-change event: configuration reloaded |
| `SERVICE_CONTROL_POWEREVENT` (13) | `PBT_APMSUSPEND` (4) → `HandleManagerApmSuspend`; resume events (6, 7, 18) → `HandleManagerApmResumeSuspend` |
| Others (pause, continue, interrogate, netbind…, device, hardware profile) | Only logged |

The service also uses `NtSetSystemInformation(46, &event, 4)` (`SetTimeSlipEvent`, 0x64B9CD68): `SystemTimeSlipNotification`, which signals an event when the kernel loses clock interrupts ("Time Slip Notification").

### IsMobileCore (0x64BA6610)

`IsMobileCore` is the only phone-specific function. It has no decompilation: it's large and obfuscated (0xF80 bytes of stack, inlined string and buffer helpers, a table of font names `Segoe UI Light`, `Segoe UI SemiBold`, `Meiryo UI`, `Malgun Gothic`… referenced only here, whose role isn't understood). It runs once; the result is cached in `dword_64BC8154`:
1. Reads the licence value `Microsoft-Windows-W32Time-License-SecurityRuntime` (string at 0x64B818C0) with `NtQuerySystemInformation(0x86 = SystemPolicyInformation, …)`, taken from ntdll.dll with `GetModuleHandleExW` + `GetProcAddress`. This is an inlined `SLGetWindowsInformationDWORD` ?: the result must be of type 4 (REG_DWORD); `0xD0000023` (buffer too small) is turned into `HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER)`, and some NTSTATUS values into 0xC004F027 ?
2. If the DWORD isn't 0: `LoadLibraryExW(L"SecRuntime.dll")`, then `g_pfnQueryTransientObjectSecurityDescriptor` and `g_pfnFreeTransientObjectSecurityDescriptor` = `GetProcAddress` of the two functions. The module handle is kept in `dword_64BC8180` (the library is freed if another thread stored one first).
3. Returns TRUE only if the module and both pointers are set.

In the phone image the licence value is 1 (entry of `HKLM\SYSTEM\ControlSet001\Control\ProductOptions\ProductPolicy`, type REG_DWORD). So on the phone, the RPC server uses the SecRuntime security descriptors and not `W32TimeSecurityCallback`.

### RPC server

`W32TmStartRpcServer` (0x64BAEC94):
1. If `IsMobileCore()`: `QueryTransientObjectSecurityDescriptor(8, L"DefaultRpcAccess", &epSd)` and `(9, L"W32Time\\Interface", &ifSd)` (SecRuntime). If either fails, the error is 0x8007053A (`ERROR_INVALID_SECURITY_DESCR`) and the server isn't started.
2. `RpcServerUseProtseqEpW(L"ncalrpc", 10, L"W32TIME_ALT", epSd)` (`epSd` is NULL on the desktop), then `RpcServerUseProtseqEpW(L"ncacn_np", 10, L"\\PIPE\\W32TIME_ALT", NULL)`; 1740 (`RPC_S_DUPLICATE_ENDPOINT`) is accepted.
3. Registration of the interface (`0x64B81378`):
   - with `ifSd`: `RpcServerRegisterIf3(if, NULL, NULL, 0x29 = RPC_IF_AUTOLISTEN | RPC_IF_ALLOW_SECURE_ONLY | RPC_IF_ALLOW_LOCAL_ONLY, 1234 = RPC_C_LISTEN_MAX_CALLS_DEFAULT, 0, NULL, ifSd)`: no security callback, the access check is the interface security descriptor;
   - without: `RpcServerRegisterIfEx(if, NULL, NULL, 0x89 = RPC_IF_AUTOLISTEN | RPC_IF_ALLOW_SECURE_ONLY | RPC_IF_SEC_CACHE_PER_PROC, 10, W32TimeSecurityCallback)`.
4. `RpcServerInqDefaultPrincNameW(9 = RPC_C_AUTHN_GSS_NEGOTIATE)` and `RpcServerRegisterAuthInfoW(name, 9)`. Win32 errors are returned as `HRESULT_FROM_WIN32`.

`W32TmStopRpcServer` (0x64B9F53C) sets the [resync result](#w32timesync-opnum-0) to 3 (shutdown), signals the two resync events so that waiting callers return, and calls `RpcServerUnregisterIf(if, NULL, TRUE)`.

**W32TimeSecurityCallback** (0x64BB5AFC, disassembly only, desktop case): `RpcImpersonateClient`, `OpenThreadToken`. Then `RpcServerInqCallAttributesW` (version 2, flag 0x20 `RPC_QUERY_IS_CLIENT_LOCAL`) is called. Opnums 2 and 6 (provider status, status) are allowed to any local client. Every other call needs `SeSystemtimePrivilege` (LUID 12, `PrivilegeCheck` with the privilege set built by `InitGlobalState`), else `E_ACCESSDENIED`. Then `RpcRevertToSelf`.

Interface `{8FB6D884-2388-11D0-8C35-00C04FDA2795}` version 4.1 (MS-W32T, `W32Time`), 8 procedures, server stub descriptor at 0x64B81700, all with an explicit binding handle and returning a `long`:

| Opnum | Server routine | Parameters | Use |
|-------|----------------|------------|-----|
| 0 | `s_W32TimeSync` (0x64BC249C) | `[in] ULONG wait`, `[in] ULONG flags` | Resync ([below](#w32timesync-opnum-0)); called by [WPTimeSvc.dll](./wptimesvc.md#w32time-rpc) |
| 1 | `s_W32TimeGetNetlogonServiceBits` (0x64BB021C) | none | Returns the Netlogon service bits (`dword_64BC811C`) |
| 2 | `s_W32TimeQueryProviderStatus` (0x64BB8148) | `[in] DWORD flags`, `[in, string] provider`, `[out]` provider info | Status of a provider |
| 3 | `s_W32TimeQuerySource` (0x64BB006C) | `[out, string]` source | Name of the current time source |
| 4 | `s_W32TimeQueryProviderConfiguration` (0x64BB7E44) | `[in] DWORD flags`, `[in, string] provider`, `[out]` config | Configuration of `NtpClient` / `NtpServer` |
| 5 | `s_W32TimeQueryConfiguration` (0x64BBB1C4) | `[out]` configuration | Service configuration |
| 6 | `s_W32TimeQueryStatus` (0x64BAFDEC) | `[out]` status | Status: [W32TIME_STATUS_INFO](#status-opnum-6) |
| 7 | `s_W32TimeLog` (0x64BBA55C) | none | Reloads the file log configuration (`UpdateFileLogConfig`) |

#### W32TimeSync (opnum 0)

`s_W32TimeSync(h, wait, flags)` (0x64BC249C) tests the flags in this order:

| Flag | Name (file log) | Action |
|------|-----------------|--------|
| 0x04 | `Rediscover` | `HandleManagerNetTopoChange(NULL, TRUE)`: the time sources are resolved again, then a resync |
| 0x01 | `HardResync` | Resync (`HandleManagerTimeSlip`) |
| 0x08 | `UpdateAndResync` | `HandleManagerParamChange` (configuration reloaded), then a resync |
| 0x10 | `ForceResync` | Resync and sets the force flag (`byte_64BC80BC`): the next correction is applied even if it's beyond `MaxPosPhaseCorrection` / `MaxNegPhaseCorrection` ("… beyond boundary. Syncing anyway") |
| none of these | `SoftResync` | Only sets the resync event (`dword_64BC7674`) |
| 0x02 | (`ReturnResult`) | With `wait`: returns the resync result instead of 0 |

Each resync sets the "resync in progress" flag (`byte_64BC8128`). With `wait` ≠ 0, the call waits (`WaitForSingleObject(INFINITE)`) on the current resync event (`dword_64BC8124`). That event alternates between two events (`dword_64BC765C` / `dword_64BC7660`), which are signalled at the end of each sample-processing round (`HandleManagerGetTimeSamples`, 0x64BB9640). The result (`dword_64BC8120`) is:

| Value | Meaning | Set by |
|-------|---------|--------|
| 0 | Success | `HandleManagerGetTimeSamples` |
| 1 | No data (no usable sample) | `HandleManagerGetTimeSamples` |
| 2 | Stale data | `HandleManagerGetTimeSamples` (`byte_64BC7981`) |
| 3 | Shutdown | `W32TmStopRpcServer` |
| 4 | Change too big (beyond the max phase correction, not forced) | Clock discipline (`byte_64BC7982`, " *TOO BIG*") |

These are the `ResyncResult_*` values that [WPTimeSvc.dll](./wptimesvc.md#ntp-ntpsync) turns into 0x83130001…0x83130004. WPTimeSvc retries a "change too big" result with flags 0x12 (`ForceResync | ReturnResult`).

#### Status (opnum 6)

`s_W32TimeQueryStatus` returns a `MIDL_user_allocate` buffer of 0x68 bytes followed by the source name:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Size, 0x68 |
| 0x04…0x10 | 4 each | Leap indicator, stratum, poll interval, precision (`dword_64BC76E4`, `…E8`, `…F0`, `…EC`) ? |
| 0x18, 0x1C | 4 each | Root delay, root dispersion ? |
| 0x20 | 8 | `dword_64BC770C` (64-bit) ? |
| 0x28 | 8 | `dword_64BC7718` (64-bit) ? |
| 0x30 | 4 | Clock precision (`dword_64BC8088`) |
| 0x34 | 4 | Pointer to the source name (copy of the source up to the first `(`) |
| 0x38 | 8 | Time of the last successful sync ? |
| 0x40…0x50 | 4 each | Phase offset, `dword_64BC7724`, `dword_64BC7BB0`, Netlogon service bits, last resync result (`dword_64BC80A4`) |
| 0x58 | 8 | Current time from the service's point of view ? |
| 0x60 | 8 | 0 |

Only the size, the source name and the last result are certain; the other fields are given in the order of the MS-W32T status structure ?

### RPC client (exports)

Every client export (`W32TimeSyncNow`, `W32TimeQueryStatus`, …) works the same way:
1. `RpcStringBindingComposeW(NULL, L"ncacn_np", server, L"\\PIPE\\W32TIME", NULL)`, `RpcBindingFromStringBindingW`.
2. `SetMyRpcSecurity` (0x64B9CF68): `RpcMgmtInqServerPrincNameW(h, 9)`, then `RpcBindingSetAuthInfoW(h, principal, 6 = RPC_C_AUTHN_LEVEL_PKT_PRIVACY, 9 = RPC_C_AUTHN_GSS_NEGOTIATE, NULL, 0)`.
3. Calls the stub (`c_W32Time*`, client stub descriptor `off_64B9A560`, same interface and version).
4. On 1717 (`RPC_S_UNKNOWN_IF`) or 1722 (`RPC_S_SERVER_UNAVAILABLE`), the same again with `\PIPE\W32TIME_ALT`.

The server of this DLL doesn't listen on `\PIPE\W32TIME`, only on `W32TIME_ALT`. [WPTimeSvc.dll](./wptimesvc.md#w32time-rpc) doesn't use these exports: it has its own stub and binds directly to `ncalrpc:[W32TIME_ALT]` with `RPC_C_AUTHN_WINNT`.

### Time provider interface

`g_rgpiDispatchTable` (0x64BC7280) has two entries of 0x18 bytes: name, then open / command / close functions. The two entries are `NtpClient` and `NtpServer`, and both use `NtpTimeProvOpen` (0x64BC2888), `NtpTimeProvCommand` (0x64BC2730) and `NtpTimeProvClose` (0x64BBE3D8).
- `TimeProvOpen(name, callbacks, &handle)`: finds the name (`wcscmp`), fails with 0x800704DF (`ERROR_ALREADY_INITIALIZED`) if this provider is already open, otherwise calls its open function. The handle is the index + 1; an unknown name gives 0x80070490.
- `TimeProvCommand(handle, cmd, args)`, `TimeProvClose(handle)`: check the handle (1 or 2, open) and forward. Commands: `TPC_TimeJumped`, `TPC_UpdateConfig`, `TPC_PollIntervalChanged`, `TPC_NetTopoChange`, `TPC_Query`, `TPC_Shutdown` (names of the file log).

`StartProvider` (0x64BB4080) loads the provider DLL (`LoadLibraryExW(DllName)`) and gets the three functions. It then calls `TimeProvOpen(name, &{ 0x14, MyGetTimeSysInfo, MyLogTimeProvEvent, MyAlertSamplesAvail, MySetProviderStatus }, &handle)`.

**NtpClient**: the manual peers come from `Parameters\NtpServer` (`ManualPeerList` in the policy key), separated by spaces, each `<name>[,<flags>]`. The flags are read with `wcstoul(…, 0)` after the comma (`AddNewPendingManualPeer`, 0x64BB394C). Flag 0x1 makes the peer use the special poll interval (`SpecialPollInterval`), which is the `,0x1` written by [WPTimeSvc.dll](./wptimesvc.md#ntp-ntpsync). The peers are polled by the `PeerPollingThread`, and the answers are received by the `ListeningThread` on UDP sockets (port 123 ?, `0x7B00` = `htons(123)` in the socket code).

### Registration

`DllInstall(_, cmdLine)` reads one-letter commands separated by spaces:
- `i` + `f`/`d`/`m`/`s`: `RegisterService(role 0…3)`, `CreateRegValues`, `CreateRoleSpecificRegValues`;
- `d` + `p`/`d`/`f`/`l`: `W32TimeDcPromo(1 / 2 / 4 / 8)`;
- `nj` / `nu`: `W32TimeVerifyJoinConfig` / `W32TimeVerifyUnjoinConfig`.

`DllRegisterServer`: `GetRole`, `RegisterService`, `RefreshRegValues`. `RegisterService` (0x64BA00E4) creates the service (`CreateServiceW`, `ServiceDll`, `ServiceMain` = `SvchostEntry_W32Time`, `ServiceDllUnloadOnStop`, `NT AUTHORITY\LocalService`, required privileges `SeAuditPrivilege`, `SeChangeNotifyPrivilege`, `SeCreateGlobalPrivilege`, `SeSystemTimePrivilege`). It also registers the event log source (`Eventlog\System\W32Time`: `EventMessageFile`, `ProviderGuid` = `{06EDCFEB-0FD0-4E53-ACCA-A6F8BBF81BCB}`, `TypesSupported`). The default values written include `Parameters\Type` = `NT5DS` and `Parameters\NtpServer` = `time.windows.com,0x9`, and the keys are given SDDL DACLs (`D:P(A;CI;GR;;;BU)(A;CI;GA;;;BA)(A;CI;GA;;;SY)…`). On the phone the registry comes with the image and differs from these defaults (`Type` = `NTP`, `NtpServer` = `time.windows.com,0x1`, no event log or policy keys, see [values on the phone](#values-on-the-phone)). It's not known whether these functions are ever called there.

### Registry

Under `HKLM`. Paths in the binary use `System\CurrentControlSet`; [WPTimeSvc.dll](./wptimesvc.md#registry) writes the same keys through `ControlSet001`.

| Key | Values | Use |
|-----|--------|-----|
| `System\CurrentControlSet\Services\W32Time\Parameters` | `Type`, `NtpServer`, `ServiceDll`, `ServiceMain`, `ServiceDllUnloadOnStop` | Sync type and manual peer list |
| `System\CurrentControlSet\Services\W32Time\Config` | `PhaseCorrectRate`, `MinPollInterval`, `MaxPollInterval`, `MaxNegPhaseCorrection`, `MaxPosPhaseCorrection`, `UpdateInterval`, `FrequencyCorrectRate`, `PollAdjustFactor`, `LargePhaseOffset`, `SpikeWatchPeriod`, `HoldPeriod`, `LocalClockDispersion`, `EventLogFlags`, `TimeJumpAuditOffset`, `AnnounceFlags`, `MaxAllowedPhaseOffset`, `RequireSecureTimeSyncRequests`, `LastClockRate`, `FileLogName`, `FileLogSize`, `FileLogEntries`, `FileLogFlags` | Clock discipline, announcement and file log. `FileLogEntries` is a list of ranges `a-b` (`ReadFileLogConfig`, 0x64BA24D8) |
| `System\CurrentControlSet\Services\W32Time\TimeProviders\<name>` | `Enabled`, `DllName`, `InputProvider`, `RunOnVirtualOnly` | Providers to load |
| `…\TimeProviders\NtpClient` | `SpecialPollInterval`, `SpecialPollTimeRemaining`, `CrossSiteSyncFlags`, `ResolvePeerBackoffMinutes`, `ResolvePeerBackoffMaxTimes`, `CompatibilityFlags`, `LargeSampleSkew`, `SignatureAuthAllowed`, `AllowNonstandardModeCombinations`, `EventLogFlags` | NTP client |
| `…\TimeProviders\NtpServer` | `Enabled`, `AllowNonstandardModeCombinations`, `ChainEntryTimeout`, `ChainMaxEntries`, `ChainMaxHostEntries`, `ChainDisable`, `ChainLoggingRate`, `RequireSecureTimeSyncRequests` | NTP server (RODC chaining) |
| `…\TimeProviders\VMICTimeProvider` (`\Parameters`) | | Hyper-V provider, only DACLs set at registration |
| `Software\Policies\Microsoft\W32Time\Parameters`, `\Config`, `\TimeProviders\NtpClient`, `\TimeProviders\NtpServer` | Same names, plus `ManualPeerList` | Group policy overrides |
| `System\CurrentControlSet\Services\Eventlog\System\W32Time` | `EventMessageFile`, `ProviderGuid`, `TypesSupported` | Event log source |
| `SYSTEM\Setup` | `SystemSetupInProgress` | Read by the service |

Not every value of the strings has been checked against the code that reads it (`ReadConfig`, `ReadNtpClientConfig`, `ReadNtpServerConfig` have no decompilation); the values above come from the strings of those functions.

#### Values on the phone

From the `SYSTEM` hive of the phone image (`ControlSet001`). `Software\Policies\Microsoft\W32Time` doesn't exist, so there are no policy overrides.

| Key | Value | Data | Comment |
|-----|-------|------|---------|
| `Services\W32Time` | `ImagePath` | `%SystemRoot%\system32\svchost.exe -k LocalService` | svchost group `LocalService` |
| `Services\W32Time` | `ObjectName` | `NT AUTHORITY\LocalService` | |
| `Services\W32Time` | `Start` / `Type` / `ErrorControl` | 3 (demand) / 0x20 (shared process) / 1 | Started by [WPTimeSvc.dll](./wptimesvc.md#ntp-ntpsync) |
| `Services\W32Time` | `RequiredPrivileges` | `SeAuditPrivilege`, `SeChangeNotifyPrivilege`, `SeCreateGlobalPrivilege`, `SeSystemTimePrivilege` | Same as `RegisterService` |
| `Services\W32Time` | `ServiceSidType` | 1 (unrestricted) | |
| `Services\W32Time` | `FailureActions` | Reset 86 400 s; restart after 60 s, restart after 120 s, then none | |
| `Services\W32Time\Security` | `Security` | `O:SYG:SYD:(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCLCSWRPWPLOCRRC;;;LS)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;LCRPWP;;;S-1-15-3-1024-1419002827-…-616546729)(A;;LCRPWP;;;S-1-5-21-2702878673-795188819-444038987-1030)(A;;LCRPWP;;;S-1-5-21-…-1656)…` | Service DACL: start / stop (`RPWP`) for LocalService, a capability SID (`S-1-15-3-1024-…`) and two phone accounts (RIDs 1030 and 1656, owners unknown) |
| `Services\W32Time\TriggerInfo\0` | `Type` 3, `Action` 1, `GUID` `{1CE20ABA-9851-4421-9430-1DDEB766E809}` | | Start on domain join (`DOMAIN_JOIN_GUID`) |
| `Services\W32Time\TriggerInfo\1` | `Type` 3, `Action` 2, `GUID` `{DDAF516E-58C2-4866-9574-C3B615D42EA1}` | | Stop on domain leave (`DOMAIN_LEAVE_GUID`) |
| `Services\W32Time\Parameters` | `Type` | `NTP` | Manual peers only, no domain hierarchy |
| `Services\W32Time\Parameters` | `NtpServer` | `time.windows.com,0x1` | Same format as the list written by WPTimeSvc.dll (`NTPServer`, same value: names are case-insensitive) |
| `Services\W32Time\Parameters` | `ServiceDll` / `ServiceMain` / `ServiceDllUnloadOnStop` | `%systemroot%\system32\w32time.dll` / `SvchostEntry_W32Time` / 1 | |
| `Services\W32Time\Config` | `MaxPosPhaseCorrection`, `MaxNegPhaseCorrection` | 0xD2F0 = 54 000 s (15 h) | Beyond this, the resync result is "change too big" (4) unless forced (flag 0x10) |
| `Services\W32Time\Config` | `MinPollInterval` / `MaxPollInterval` | 10 (1 024 s) / 15 (32 768 s), log2 seconds | |
| `Services\W32Time\Config` | `UpdateInterval` | 0x57E40 = 360 000 (in 1/100 s ?: 1 h) | |
| `Services\W32Time\Config` | `AnnounceFlags` | 0xA | |
| `Services\W32Time\Config` | `EventLogFlags` | 2 | |
| `Services\W32Time\Config` | `FrequencyCorrectRate` 4, `HoldPeriod` 5, `LargePhaseOffset` 0x2FAF080 (50 000 000 × 100 ns = 5 s), `LocalClockDispersion` 10, `MaxAllowedPhaseOffset` 1, `PhaseCorrectRate` 1, `PollAdjustFactor` 5, `SpikeWatchPeriod` 900, `TimeJumpAuditOffset` 28 800 | | Desktop defaults |
| `Services\W32Time\Config` | `FileLog*`, `LastClockRate` | absent | `FileLog*` written by WPTimeSvc.dll only when logging is enabled |
| `…\TimeProviders\NtpClient` | `Enabled` / `InputProvider` / `DllName` | 1 / 1 / `%systemroot%\system32\w32time.dll` | The only time provider |
| `…\TimeProviders\NtpClient` | `SpecialPollInterval` | 0x93A80 = 604 800 s (7 days) | Poll interval of the `,0x1` peers |
| `…\TimeProviders\NtpClient` | `SpecialPollTimeRemaining` | `time.windows.com,8027499` | Saved by the service: time left before the next poll of each peer |
| `…\TimeProviders\NtpClient` | `CompatibilityFlags` 0x80000000, `CrossSiteSyncFlags` 2, `LargeSampleSkew` 3, `ResolvePeerBackoffMaxTimes` 7, `ResolvePeerBackoffMinutes` 15, `SignatureAuthAllowed` 1, `AllowNonstandardModeCombinations` 1, `EventLogFlags` 1, `RunOnVirtualOnly` 0 | | |
| `…\TimeProviders\NtpServer` | `Enabled` / `InputProvider` | 0 / 0 | The NTP server isn't started (other values: desktop defaults) |
| `Control\ProductOptions` | `ProductPolicy` entry `Microsoft-Windows-W32Time-License-SecurityRuntime` | 1 (REG_DWORD) | [IsMobileCore](#ismobilecore-0x64ba6610) returns TRUE |

The `Eventlog\System\W32Time` key wasn't part of the dump. The 7-day special poll interval matters little, because WPTimeSvc.dll stops the service after each sync. WPTimeSvc.dll forces the resyncs it needs (opnum 0), and it schedules them every `NTP Regular Sync Interval` hours.

### ETW

Provider `Microsoft-Windows-Time-Service` (`S_MICROSOFT_WINDOWS_TIME_SERVICE`) `{06EDCFEB-0FD0-4E53-ACCA-A6F8BBF81BCB}`, registered by `W32TimeInitializeEvents` (0x64BA08A8, `CEventRegister` → `EtwEventRegister`). The events are the event log messages (`MyLogEvent`, `MyLogThrottledEvent`), version 0, channel 8, opcode 0, task 0, keyword 0x8000000000000000; the packet test events (147…154) have no channel, level or keyword.

| Event | Symbol (`W32TIME_EVENT_…`) | Level |
|-------|----------------------------|-------|
| 1 | `TIMEPROV_ERROR` | error |
| 2 | `TIMEPROV_WARNING` | warning |
| 3 | `TIMEPROV_INFORMATIONAL` | info |
| 4 | `TIMEPROV_FAILED_START` | error |
| 5 | `TIMEPROV_FAILED_STOP` | error |
| 6 | `CONFIG_READ_FAILED_WARNING` | warning |
| 7 | `TIMEPROV_FAILED_UPDATE` | warning |
| 8 | `TIMEPROV_FAILED_POLLUPDATE` | warning |
| 9 | `TIMEPROV_FAILED_TIMEJUMP` | warning |
| 10 | `TIMEPROV_FAILED_GETSAMPLES` | warning |
| 11 | `NOT_DOMAIN_MEMBER` | warning |
| 12 | `DOMAIN_HIERARCHY_ROOT` | warning |
| 13 | `NT4_DOMAIN` | warning |
| 19 | `FILELOG_FAILED` | error |
| 20 | `FILELOG_WRITE_FAILED` | error |
| 21 | `NO_INPUT_PROVIDERS_STARTED` | error |
| 22 | `CLIENT_COMPUTE_SERVER_DIGEST_FAILED` | warning |
| 23 | `SYMMETRIC_COMPUTE_SERVER_DIGEST_FAILED` | warning |
| 24 | `DOMHIER_PEER_TIMEOUT` | warning |
| 25 | `COMPUTE_CLIENT_DIGEST_FAILED` | warning |
| 26 | `BAD_SIGNATURE` | warning |
| 27 | `MISSING_SIGNATURE` | warning |
| 30 | `CONFIG_READ_FAILED` | warning |
| 33 | `TIME_JUMPED` | warning |
| 34 | `TIME_CHANGE_TOO_BIG` | error |
| 35 | `TIME_SOURCE_CHOSEN` | info |
| 36 | `TIME_SOURCE_NONE` | warning |
| 37 | `TIME_SOURCE_REACHABLE` | info |
| 38 | `TIME_SOURCE_UNREACHABLE` | warning |
| 39 | `TCP_NOT_INSTALLED` | warning |
| 42 | `NAMED_EVENT_ALREADY_OPEN` | error |
| 43 | `TIMEPROV_FAILED_NETTOPOCHANGE` | warning |
| 44 | `NTPCLIENT_ERROR_SHUTDOWN` | error |
| 45 | `NTPSERVER_ERROR_SHUTDOWN` | error |
| 46 | `ERROR_SHUTDOWN` | error |
| 47 | `MANUAL_PEER_TIMEOUT` | warning |
| 50 | `LOCALCLOCK_UNSET` | warning |
| 51 | `SAMPLE_HAS_LARGE_SKEW` | warning |
| 52 | `TIME_JUMP_AUDIT` | warning |
| 53 | `TIME_SOURCE_UNREACHABLE_SENDTO` | warning |
| 54 | `CONFIG_REFRESH_FAILED` | error |
| 129…133 | `DOMAIN_PEER_DISCOVERY_ERROR`, `…_AUTHENTICATION_ERROR`, `…_DNS_ERROR`, `…_DUPLICATE_ERROR`, `…_UNEXPECTED_ERROR` | warning |
| 134…136 | `MANUAL_PEER_DNS_ERROR`, `…_DUPLICATE_ERROR`, `…_UNEXPECTED_ERROR` | warning |
| 137, 138 | `MANUAL_PEER_SUCCESS_ERROR`, `DOMAIN_PEER_SUCCESS_ERROR` | info |
| 139, 143 | `START_ADVERTISING`, `START_ADVERTISING_GT` | info |
| 140…142, 144, 145 | `STOP_ADVERTISING_NOTADC`, `…_NOPROVIDERS`, `…_NOTSYNCED`, `…_GT`, `…_GENERIC` | warning |
| 146 | `INFO_CHAINING` | info |
| 147…154 | `ERROR_PACKETTEST1`…`8` | - |
| 156 | `RODCUNABLETOFWDREQUEST` | warning |
| 157 | `DOWNLEVELSYNCREQUESTIGNORED` | warning |

### Named objects

| Name | Type | Use |
|------|------|-----|
| `W32Time` / `w32time` | Service | Name given to `RegisterServiceCtrlHandlerExW` |
| `W32TIME_ALT` | LRPC endpoint | RPC server, used by [WPTimeSvc.dll](./wptimesvc.md#w32time-rpc) |
| `\PIPE\W32TIME_ALT` | Named pipe endpoint | RPC server |
| `\PIPE\W32TIME` | Named pipe endpoint | Tried first by the client exports (not registered by this server) |
| `DefaultRpcAccess` | Transient object security descriptor (type 8) | Security of the LRPC endpoint (phone only) |
| `W32Time\Interface` | Transient object security descriptor (type 9) | Security of the RPC interface (phone only) |
| `W32TIME_NAMED_EVENT_SYSTIME_NOT_CORRECT` | Event, DACL `D:(A;;GA;;;LS)(A;;GA;;;SY)(A;;GA;;;BA)` | Named event created at startup (set while the clock isn't synchronised ?) |
| `Microsoft-Windows-W32Time-License-SecurityRuntime` | Licence value (DWORD) | Enables the SecRuntime security ([IsMobileCore](#ismobilecore-0x64ba6610)) |
