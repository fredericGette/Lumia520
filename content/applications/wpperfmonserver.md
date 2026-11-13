## WpPerfMonServer.exe

Windows Phone performance monitor server: lets a development tool on the PC read the performance counters of the phone.  
It's a console program (log lines printed on `stderr`, prefixed with `PerfMon:`) that listens on TCP `127.0.0.1:8889`, accepts a single client, and answers requests that mirror the PerfLib V2 consumer API of desktop Windows (enumerate counter sets, query their registration information, enumerate instances, query counter data). The binary carries its own catalogue of 42 counter sets (names, help strings, GUIDs, counters), and collects the values itself through 4 internal providers: kernel PCW queries (`pcwum.dll` / the `pcw` service), PCW notifications to user-mode providers, `NtQuerySystemInformation` + WMI + Mount Point Manager for the classic objects (Processor, Memory, Process, disks…), and `HKEY_PERFORMANCE_DATA` for the ESE "Database" objects.  
293 functions, no exports. Hex-Rays fails on most functions that use `__security_push_cookie` (bad frame), so most of the analysis was done on the disassembly.

Location on the phone: `\Windows\System32\WpPerfMonServer.exe`, the only file of the `Microsoft.Tools.PerfMonExt` package (version 8.10.14234.375, ARM, `MainOS` partition), which also writes `HKLM\Software\Microsoft\Windows Phone\Power Tools\Packages\Microsoft.Tools.PerfMonExt.spkg` (`Contents` = `WpPerfMonServer.exe`, `Version` = `8.1.0.1`) and `…\Packages\WpPerfMonServer.exe` (`Version` = `8.1.0.1`).  
Started by: the on-device agent of the *Windows Phone Developer Power Tools* ([WpToolsSvc.exe](./wptoolssvc.md)). Its `startPerfmon` command publishes the 4-byte value 1 to the WNF state 0x0D92063DA3BC0875 (`PHTL`, sequence number 1, see [WpToolsWrapper.exe](./wptoolswrapper.md#wnf-states)) and answers `PerfMon triggered.`. That state is the trigger of the task `WpPerfMonServerImmediate` `{C4CAAC6C-D10E-48EF-8167-6EF820F3685D}` of [TaskSchedulerSvc.dll](../libraries/taskschedulersvc.md#tasks-of-a-phone) (stored under `HKLM\SOFTWARE\Microsoft\WPTaskScheduler`, created by `S-1-5-18`): [WNF trigger](../libraries/taskschedulersvc.md#wnf-trigger) condition 1 (equal) with the DWORD 1, [action](../libraries/taskschedulersvc.md#actions) 0 = start `%systemdrive%\windows\system32\WpPerfMonServer.exe` (no command line) with `CreateProcessInChamber`. So the process is a child of the service host `svchost.exe -k WPTCBCritical` (observed with `tlist -t`).  
Client: the PC tool `PwTools.exe`, through its own copy of `pdh.dll` ([below](#client-pc-side)).

### Imports

| DLL | Functions |
|-----|-----------|
| WS2_32.dll | `WSAStartup`, `WSACleanup`, `socket`, `bind`, `listen`, `accept`, `recv`, `send`, `closesocket`, `htons`, `inet_addr`, `WSAGetLastError`, `WSACreateEvent`, `WSACloseEvent`, `WSAResetEvent`, `WSAEventSelect`, `WSAWaitForMultipleEvents` |
| pcwum.dll | `PcwCreateQuery`, `PcwEnumerateInstances`, `PcwAddQueryItem`, `PcwRemoveQueryItem`, `PcwCollectData`, `PcwCreateNotifier`, `PcwSendNotification`, `PcwSendStatelessNotification` |
| WMICLNT.dll | `WmiOpenBlock`, `WmiCloseBlock`, `WmiQueryAllDataW`, `WmiExecuteMethodW` |
| ntdll.dll | `NtQuerySystemInformation`, `RtlNtStatusToDosError`, `RtlRaiseException`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-service-management-l1-1-0.dll | `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `CloseServiceHandle` |
| api-ms-win-service-winsvc-l1-2-0.dll | `QueryServiceStatus` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `GetDiskFreeSpaceW` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-registry-l1-1-0.dll | `RegQueryValueExW` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetComputerNameExW`, `GetSystemTimeAsFileTime`, `GetSystemInfo` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter`, `QueryPerformanceFrequency` |
| api-ms-win-core-timezone-l1-1-0.dll | `FileTimeToSystemTime` |
| api-ms-win-core-localization-l1-2-1.dll | `FormatMessageW` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapReAlloc`, `HeapFree` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleA` |
| msvcrt.dll | `fprintf_s`, `fflush`, `_iob`, `wcstol`, `wcscmp`, `_wcsicmp`, `wcsncmp`, `wcsnlen`, `wcslen`, `wcscpy_s`, `swprintf_s`, `_snwprintf_s`, `_itow_s`, `_ultow_s`, `iswspace`, `ldiv`, `memcpy`, `memmove`, `memset`, `memcmp`, C++ runtime (`operator new` / `delete`, `exception`, `_CxxThrowException`, `__CxxFrameHandler3`, `_purecall`) and CRT startup (`__wgetmainargs`, `_initterm`, `exit`, …) |

The `Sleep`, `GetCurrentProcess`, `TerminateProcess`, `GetModuleHandleA`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `Rtl*` unwind functions and the msvcrt startup functions are the standard Visual C++ CRT startup and `/GS` code. The program is written in C++ with the STL (`std::wstring`, `std::vector`, `std::list`, hash map) and `tlx::hr_error` exceptions.

### Dependencies

Files and devices used other than the static imports.

| File | How | Use |
|------|-----|-----|
| service `pcw` (`pcw.sys`) | `OpenSCManagerW` / `OpenServiceW` / `QueryServiceStatus` / `StartServiceW` | Performance Counters for Windows kernel component, started at launch if stopped (needed by the `PcwCreateQuery` providers) |
| `\\.\MountPointManager` | `CreateFileW` (access 0x80000000 `GENERIC_READ`, share 3, `OPEN_EXISTING`) + `DeviceIoControl` | Mount points of the volumes, for the LogicalDisk / PhysicalDisk instance names ([below](#ioctl_mountmgr_query_points-0x006d0008)) |
| `\\.\HarddiskVolume%u\` | `GetDiskFreeSpaceW` | Free space of each volume (LogicalDisk counters) |
| `HKEY_PERFORMANCE_DATA` | `RegQueryValueExW` | Legacy perflib data of the ESE "Database" objects ([below](#registry)) |
| WMI data blocks | `WmiOpenBlock` / `WmiQueryAllDataW` / `WmiExecuteMethodW` | Counters of the built-in objects ([below](#wmi-blocks)) |

No DLL is loaded at run time and no process is started.

### Parameters

The command line isn't used: `wmain` (0x102ADF4) ignores its arguments.  
It starts the `pcw` service (0x102A820), creates the listening socket and runs the connection loop (0x102AABC), then prints `PerfMon: Exiting with code 0x%x` and returns that code: the HRESULT that ended the session, normally 0x80070026 (`ERROR_HANDLE_EOF`, client closed the connection), or the HRESULT of the failing Winsock call (`WSAStartup`, `socket`, `bind`, `listen` are reported as `fatal`).

### Start of the pcw service

0x102A820, errors are printed and ignored (`** PerfMon: <api> returned HR = <hr> (<message>) ignoring`, message from `FormatMessageW`):

1. `OpenSCManagerW(NULL, NULL, SC_MANAGER_CONNECT)`.
2. `OpenServiceW(scm, L"pcw", SERVICE_QUERY_STATUS)`, `QueryServiceStatus`.
3. If `dwCurrentState` is `SERVICE_STOPPED` (1): `OpenServiceW(scm, L"pcw", SERVICE_START)` and `StartServiceW(svc, 0, NULL)`; `ERROR_SERVICE_ALREADY_RUNNING` (0x420) is silently ignored, success is printed as `StartServiceW returned HR = 0 success`.

### Socket

| Parameter | Value |
|---|---|
| Winsock version | 2.2 (`WSAStartup(0x202)`) |
| Socket | `socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)` |
| Address | `127.0.0.1`, port 8889 (0x22B9) |
| Backlog | `listen(s, 1)` |
| Log | `PerfMon: Listening for connections on address 127.0.0.1 and port 8889.` |

The connection loop (0x102AABC) waits with `WSAWaitForMultipleEvents` on 2 events: event 1 is selected on the listening socket for `FD_ACCEPT`, event 0 on the client socket for `FD_READ | FD_WRITE | FD_CLOSE` (0x23). There is a single client slot (0x218 bytes: server object, socket, send pointer/length, receive buffer of 512 bytes): a second connection is closed at once (`PerfMon: Connection rejected (no open slots).`). On accept: `PerfMon(0): Accepted connection from a.b.c.d:port.`, then the server object is created (`WpPerfServerOpen`, 0x102AF88, 0xD0 bytes). Data is read with `recv` (512 bytes at a time) and passed to `WpPerfServerProcessData` (0x102B02C); replies are sent in chunks of at most 0x10000 bytes. When the client closes the connection or an error occurs, the slot is freed (`PerfMon(0): Connection closed.`), the loop ends and the program exits: one process serves one session.

### Protocol

Each message, in both directions, is a 24-byte header, a payload, and a terminator byte 0x17. All values are little-endian.

#### Request

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0x314D501B | Magic (`1B 50 4D 31`, `"\x1bPM1"`); any other value: 0x8007000D (`ERROR_INVALID_DATA`), connection closed |
| 0x04 | 4 | command | 0 to 7, see [below](#commands) |
| 0x08 | 4 | payload size | At most 0x10000000, else 0x8007000D |
| 0x0C | 4 | max reply size | Largest reply payload the client accepts |
| 0x10 | 8 | cookie | Copied unchanged into the reply |
| 0x18 | n | payload | |
| 0x18+n | 1 | 0x17 | Terminator; another value: 0x8007000D, connection closed |

#### Reply

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0x314D501B | Magic |
| 0x04 | 4 | HRESULT | Result of the command; 0x80070008 when the payload is larger than the max reply size of the request |
| 0x08 | 4 | payload size | Size of the payload that follows (0 when it was too large) |
| 0x0C | 4 | full size | Size of the full result, lets the client retry with a larger max size |
| 0x10 | 8 | cookie | From the request |
| 0x18 | n | payload | |
| 0x18+n | 1 | 0x17 | Terminator |

#### Commands

Dispatcher 0x102BDCC. A wrong payload size returns 0x83760002, an unknown command 0x80004001 (`E_NOTIMPL`). Request codes 1 to 10 of command 5 are the `PERF_REG_INFO_TYPE` values of `PerfQueryCounterSetRegistrationInfo`, and the structures returned by commands 5 to 7 are the PerfLib V2 structures (`PERF_COUNTERSET_REG_INFO`, `PERF_COUNTER_REG_INFO`, `PERF_INSTANCE_HEADER`, `PERF_COUNTER_IDENTIFIER`, `PERF_DATA_HEADER`, `PERF_COUNTER_HEADER`).

| Command | Payload | Reply payload | Equivalent |
|---|---|---|---|
| 0 | any | empty, `S_OK` | Ping: sent by the client right after `connect` |
| 1 | none | 16 bytes {total size 0x14, number of languages 1, `1 + Σ 2 × (number of counters + 1)` over the 42 counter sets, 0} then one DWORD per language: 9 (English, perflib `009`) | Legacy name table header (the client checks total size = reply size and `16 + 4 × languages` ≤ size, and matches the languages with `GetThreadPreferredUILanguages`) |
| 2 | 8 bytes: language (4), 0 = counter names / 1 = help strings (4) (both ignored) | an empty wide string (2 bytes) | Legacy name table: the client expects a `REG_MULTI_SZ`-like list `index\0name\0…` (as `Perflib\009\Counter` / `Help`), so no legacy name is published |
| 3 | none | GUID (16 bytes) of `Processor Information` (b4fc721a-0378-476f-89ba-a5a79f810b36) when its query is available, else empty. The `Processor` and `Processor Information` counter sets (found by name, or by catalogue index when the name is a decimal number, 0x102E82C) are added to the query and collected | Which processor counter set to use (sent by the PDH path / wildcard code of the client, 0x1002E69F in `pdh.dll`) ? |
| 4 | none | GUIDs (16 bytes each) of all the counter sets whose provider is available: all 42 sets are added to the query, collected, and sorted (0x102DC00) | `PerfEnumerateCounterSet` |
| 5 | 0x18 bytes: counter set GUID (16), request code (4), request index (4) | depends on the request code, see [below](#command-5-registration-information); unknown GUID: 0x80071068 (`ERROR_WMI_GUID_NOT_FOUND`), other code: 0x80070057 | `PerfQueryCounterSetRegistrationInfo` |
| 6 | 0x10 bytes: counter set GUID | for a multi-instance set, one record per instance: {record size (header + name padded to 8), instance id} then the instance name (wide string, zero padding to 8 bytes); no instance: 0x80071069 (`ERROR_WMI_INSTANCE_NOT_FOUND`); single-instance set: empty | `PerfEnumerateCounterSetInstances` |
| 7 | array of `PERF_COUNTER_IDENTIFIER` records (0x28 bytes + instance name, size multiple of 8) | `PERF_DATA_HEADER` then one `PERF_COUNTER_HEADER` per requested counter, see [below](#command-7-counter-data) | `PerfAddCounters` + `PerfQueryCounterData` |

#### Command 5: registration information

| Request code | Reply payload |
|---|---|
| 1 (`PERF_REG_COUNTERSET_STRUCT`) | 32 bytes: counter set GUID, 0, detail level (100 novice / 200 advanced), number of counters + 2, instance type (0 single, 2 multiple, 4 single aggregate, 6 multiple aggregate), followed by one 48-byte counter record per counter (0x102BCDC, as for code 2) |
| 2 (`PERF_REG_COUNTER_STRUCT`) | One 48-byte record (`PERF_COUNTER_REG_INFO`) for the counter at the request index, if index < number of counters + 2: index, counter type, attributes, detail level, default scale, base counter (next index for a fraction counter), perf time / perf freq counters (the two pseudo-counters `ObjTime` and `ObjFreq` added after the last counter), multi counter, aggregate flag |
| 3, 9 (`PERF_REG_COUNTERSET_NAME_STRING`, `…_ENGLISH_NAME`) | Name of the counter set (wide string) |
| 4 (`PERF_REG_COUNTERSET_HELP_STRING`) | Help string (stored in UTF-8, converted to UTF-16) |
| 5, 10 (`PERF_REG_COUNTER_NAME_STRINGS`, `…_ENGLISH_NAMES`) | Block {total size, number of counters, then {id, offset} for each counter + 2} followed by the counter names, `ObjTime`, `ObjFreq` |
| 6 (`PERF_REG_COUNTER_HELP_STRINGS`) | Same layout with the help strings |
| 7 (`PERF_REG_PROVIDER_NAME`) | `Windows Phone Provider` |
| 8 (`PERF_REG_PROVIDER_GUID`) | 16 zero bytes |

#### Command 7: counter data

Each request record:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 16 | GUID | Counter set |
| 0x10 | 4 | status | Ignored |
| 0x14 | 4 | size | Size of the record (0x28 + name, multiple of 8) |
| 0x18 | 4 | counter id | Index of the counter (number of counters = perf time, + 1 = perf freq) |
| 0x1C | 4 | instance id | |
| 0x20 | 8 | | Index, reserved |
| 0x28 | size − 0x28 | instance name | Wide string, must be terminated in the record; empty = all / single instance |

The reply starts with a 48-byte header: total size, number of counters, perf time stamp (`QueryPerformanceCounter`), time in 100 ns (`GetSystemTimeAsFileTime`), perf frequency, `SYSTEMTIME` (`FileTimeToSystemTime`). Then for each requested counter a `PERF_COUNTER_HEADER` {status, type, size, reserved}:

- error: {0x1068 or 0x1069 (or the Win32 error of the provider), 0, 0x10, 0} when the counter set or the instance is unknown;
- value: {0, 1 (`PERF_SINGLE_COUNTER`), 0x20, 0} followed by {data size, 0x10} and the 8-byte value.

### Client (PC side)

The client is the *Windows Phone Developer Power Tools* (`PwTools.exe`, .NET / WPF, version 8.0, files `PowerTools\` of the same download). The chain is:

1. `PwTools.exe` (shell, MEF host) loads the component `Components\Microsoft.Phone.Tools.Power.PerfMonitor.dll` (the performance monitor window: CPU, memory, I/O charts, top 5 processes, CSV log `WpPerfMon_{0}.csv`).
2. When the user presses Start, `PerfMonController::SetUpPdhTimer` calls `VerifyPerfMonServerInstalledAndRunning`: through `Microsoft.Phone.Tools.Power.Connectivity.dll` (CoreCon / `Microsoft.SmartDevice.Connectivity`, remote agent `280D7035-D88D-47CF-A90C-2B19717B5C34`, packet stream `C48B1B43-A833-41F7-9E76-47AC1513E7F6`) it sends `getVersion WpPerfMonServer.exe` to [WpToolsSvc.exe](./wptoolssvc.md#commands) and checks the version, then sends `startPerfmon` ([above](#wpperfmonserverexe)).
3. The device address comes from `IPwConn::GetDeviceAddress` → CoreCon `IDevice::GetEndPoints(0x69C5, …)` (the second `out` string). The counter paths are built as `\\<address><counter>` (`PerfMonCounter::GetIpSplicedPath`, format `\\{0}{1}`), e.g. `\\<address>\Processor Information(_Total)\% Processor Time`, and used with `PdhOpenQuery`, `PdhEnumObjectItems("Process")`, `PdhAddCounter`, `PdhCollectQueryData` and `PdhGetFormattedCounterValue`, once a second.
4. These PDH calls go to `Support\pdh.dll` (loaded through `SetDllDirectory`), a modified x86 `pdh.dll`: for a machine name that isn't the local computer, instead of remote perflib (RPC) it opens a TCP connection and speaks the [protocol](#protocol) of this server. The connection reaches the phone loopback address through the IP-over-USB tunnel ([IpOverUsb.dll](../libraries/ipoverusb.md#tcp-forwarding)).

Transport in `pdh.dll` (object of 0x3C bytes created by 0x1002A4F9 for each remote machine, 0x1000BF08):

| Item | Value |
|---|---|
| Address | Machine name of the counter path, leading `\` / `/` removed, `host[:port]`; empty → `127.0.0.1`; default port 8889 (0x1002A8EE) |
| Connection | `WSAStartup(0x202)`, `GetAddrInfoW`, `socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)`, `connect`, then command 0 (0x1002AADC); after a failure, a new attempt only after the retry delay (`Remote Reconnection Retry Time` ?) |
| Request | `WSASend` of {header, payload buffers, terminator 0x17}; cookie = request counter (low DWORD, incremented for each request) and 0 (0x1002ABE0, serialised by a critical section, 0x1002AA76) |
| Reply check | Magic, payload size ≤ max size, full size = payload size (or > max size with 0x80070008), cookie, terminator 0x17; else error 13 and the socket is closed. HRESULTs `0x8007xxxx` are returned as Win32 codes |
| Retry | On error 8 (`ERROR_NOT_ENOUGH_MEMORY`) the caller re-sends with a buffer of the full size |

| Command | `pdh.dll` wrapper | Used by |
|---|---|---|
| 1 | 0x1002A5BD (max reply 0x18) | 0x10009D81: name table header, at the connection |
| 2 | 0x1002A600 | 0x10009C92: names and help strings by index |
| 3 | inline in 0x1002E69F (max reply 0x10) | PDH path / wildcard code |
| 4 | 0x1002A67E | 0x1000B56F: counter set GUIDs (`PerfEnumerateCounterSet`) |
| 5 | 0x1002A6CC | 0x1000B139: registration information |
| 6 | 0x1002A752 | 0x1000B9CC: instances |
| 7 | 0x1002A827 | 0x10010163: counter data |

### Counter sets

Catalogue at 0x1007B30: 42 entries of 0x20 bytes {name (wide), help (UTF-8), GUID, ?, provider factory, counters, number of counters (WORD), instance type (WORD), detail level (WORD)}. The provider factories create one object per provider type, shared by all the sets of that type.

| Provider | Factory | Implementation | Counter sets |
|---|---|---|---|
| Kernel PCW | 0x102F89C → 0x102EE88 (0x78 bytes) | `PcwCreateQuery`, `PcwEnumerateInstances`, `PcwAddQueryItem`, `PcwCollectData` | BitLocker, Event Tracing for Windows, Event Tracing for Windows Session, FileSystem Disk Activity, Microsoft Winsock BSP, Network QoS Policy, Pacer Flow, Pacer Pipe, Per Processor Network Activity Cycles, Per Processor Network Interface Card Activity, Physical Network Interface Card Activity, Processor Information, SMB Server Sessions, SMB Server Shares, Synchronization, SynchronizationNuma |
| User-mode PCW providers | 0x1034C24 → 0x1033FC8 (0x100 bytes) | `PcwCreateQuery` + `PcwCreateNotifier`; `PcwSendNotification` / `PcwSendStatelessNotification` (timeout 2 s) with the computer name (`GetComputerNameExW(ComputerNameNetBIOS)`) and the counter set GUID formatted as `{%08lx-…}`, to make the provider process publish its counters | Generic IKEv1, AuthIP, and IKEv2, IPsec AuthIP IPv4, IPsec AuthIP IPv6, IPsec Driver, IPsec IKEv1 IPv4, IPsec IKEv1 IPv6, Netlogon, Power Meter, WFP, WFPv4, WFPv6, SampleCounterSet |
| Built-in objects | 0x1033308 → 0x10301A0 (0x240 bytes) | `NtQuerySystemInformation`, WMI, Mount Point Manager, `GetDiskFreeSpaceW`, `GetSystemInfo` | Cache, LogicalDisk, Memory, Network Adapter, Paging File, PhysicalDisk, Process, Processor, System, Thread, USB (GUIDs `0000000N-0003-0000-0000-000000000000`, N = 1 to 0xB) |
| Legacy perflib | 0x1035DC0 → 0x1035DF4 (0x64 bytes) | `RegQueryValueExW(HKEY_PERFORMANCE_DATA)` | Database, Database ==> TableClasses, Database ==> Instances (GUIDs `00000918-…`, `00000c72-…`, `00000d8a-…`: the low DWORD is the perflib object index) |

| Counter set | GUID | Counters | Instances | Level |
|---|---|---|---|---|
| BitLocker | 35a002b8-38a7-41eb-bedd-6610bb93f046 | 8 | multiple | 100 |
| Cache | 00000001-0003-0000-0000-000000000000 | 34 | single | 200 |
| Event Tracing for Windows | 42cd0051-9dd9-4fe2-8db9-d37885d2d749 | 6 | single | 200 |
| Event Tracing for Windows Session | ed83b00b-6afd-4063-9420-16fe0fa3b36f | 5 | multiple | 200 |
| FileSystem Disk Activity | f596750d-b109-4247-a62f-dea47a46e505 | 2 | multiple aggregate | 200 |
| Generic IKEv1, AuthIP, and IKEv2 | e6e73867-856a-4574-a0ba-01c066d376f5 | 13 | single | 100 |
| IPsec AuthIP IPv4 | a30f983f-321a-48b0-85c3-cab02781dd02 | 29 | single | 100 |
| IPsec AuthIP IPv6 | 83a3746d-a9ec-47c0-830f-6dd440b07666 | 29 | single | 100 |
| IPsec Driver | 40990512-fb18-4bbd-95e2-f72e8cdae178 | 31 | single | 100 |
| IPsec IKEv1 IPv4 | 63c158d0-2a4c-4509-8d27-29e935b69e5f | 18 | single | 100 |
| IPsec IKEv1 IPv6 | 58276884-7f29-450d-bcfa-5be4b7266334 | 18 | single | 100 |
| LogicalDisk | 00000002-0003-0000-0000-000000000000 | 34 | multiple | 100 |
| Memory | 00000003-0003-0000-0000-000000000000 | 36 | single | 100 |
| Microsoft Winsock BSP | 22ca1519-4394-4a5f-be88-84a5c853a4aa | 4 | single | 100 |
| Netlogon | a44a45c2-664d-476c-b68c-6b123eccc31f | 6 | multiple | 100 |
| Network Adapter | 00000004-0003-0000-0000-000000000000 | 15 | multiple | 200 |
| Network QoS Policy | ef82017e-50e2-4ca2-b9ec-b9895ab70e08 | 6 | multiple | 100 |
| Pacer Flow | 811bbce5-7327-4ad9-ab62-a8b955f61eef | 20 | multiple | 100 |
| Pacer Pipe | 51bda498-67cb-479f-b898-57d2d73788f0 | 17 | multiple | 100 |
| Paging File | 00000005-0003-0000-0000-000000000000 | 4 | multiple | 200 |
| Per Processor Network Activity Cycles | 987a3601-c362-48e4-a856-e28f070efb07 | 13 | multiple | 200 |
| Per Processor Network Interface Card Activity | 9acaa205-c3ed-4acd-a911-6554d156b095 | 21 | multiple | 100 |
| Physical Network Interface Card Activity | 9acaa206-c3ed-4acd-a911-6554d156b095 | 5 | multiple | 100 |
| PhysicalDisk | 00000006-0003-0000-0000-000000000000 | 31 | multiple | 100 |
| Power Meter | ad8644c4-ae02-4b22-990d-52b491f91c26 | 2 | multiple aggregate | 100 |
| Process | 00000007-0003-0000-0000-000000000000 | 28 | multiple | 100 |
| Processor | 00000008-0003-0000-0000-000000000000 | 15 | multiple | 100 |
| Processor Information | b4fc721a-0378-476f-89ba-a5a79f810b36 | 32 | multiple | 100 |
| SMB Server Sessions | e6e560b2-062f-41ca-89ab-f6987f2b7a25 | 45 | multiple aggregate | 100 |
| SMB Server Shares | f4681672-32dc-41db-8669-fdf490345ba5 | 45 | multiple aggregate | 100 |
| Synchronization | 370e979a-377a-4f30-b2c4-9a0fd072890b | 42 | multiple aggregate | 200 |
| SynchronizationNuma | 2f66fd0a-9f6c-4d91-9f2f-2a1b5e41b7dc | 42 | multiple | 200 |
| System | 00000009-0003-0000-0000-000000000000 | 18 | single | 100 |
| Thread | 0000000a-0003-0000-0000-000000000000 | 12 | multiple | 100 |
| USB | 0000000b-0003-0000-0000-000000000000 | 19 | multiple | 100 |
| WFP | 28d00a68-8309-4a3e-bf1d-0ebd27c75787 | 1 | single | 100 |
| WFPv4 | 6b81611f-8998-47c2-9550-f7dc0324e620 | 13 | single | 100 |
| WFPv6 | 11ace151-4bac-44b0-8a82-0a859a5355d9 | 13 | single | 100 |
| Database | 00000918-0000-0000-0000-000000000000 | 428 | multiple | 100 |
| Database ==> TableClasses | 00000c72-0000-0000-0000-000000000000 | 139 | multiple | 100 |
| Database ==> Instances | 00000d8a-0000-0000-0000-000000000000 | 347 | multiple | 100 |
| SampleCounterSet | 00e226bd-b2d4-4f8d-b6f3-b387ac160a3b | 1 | multiple | 100 |

The instance names built by the provider of the built-in objects: `_Total`, `Idle` and process ids (Process), `%ls.%d` (Thread ?), `PhysicalDrive%u` / `HarddiskVolume%u` / `%ls (HardDiskVolume%u)` from the `\Device\` and `\DosDevices\` names of the mount points, `Partmgr ` / `PhysDisk` prefixes.

### NtQuerySystemInformation classes

Buffers prepared by the provider of the built-in objects (0x10301A0), each re-allocated on `STATUS_INFO_LENGTH_MISMATCH` / `STATUS_BUFFER_OVERFLOW`:

| Class | Name | Initial size |
|---|---|---|
| 2 | `SystemPerformanceInformation` | 0x158 |
| 3 | `SystemTimeOfDayInformation` | 0x30 |
| 5 | `SystemProcessInformation` | 0x2000 |
| 8 | `SystemProcessorPerformanceInformation` | 0x30 × processors |
| 0x12 | `SystemPageFileInformation` | 0x60 |
| 0x15 | `SystemFileCacheInformation` | 0x24 |
| 0x17 | `SystemInterruptInformation` | 0x18 × processors |
| 0x21 | `SystemExceptionInformation` | 0x10 |
| 0x25 | `SystemRegistryQuotaInformation` | 0xC |
| 0x2A | `SystemProcessorIdleInformation` | 0x30 × processors |
| 0x4F | `SystemSuperfetchInformation` | 0x80; input {version 0x2D, magic `Chuk`, info class 0x10 (`SuperfetchMemoryListQuery` ?), buffer, size} (0x103013C), for the standby / free page lists of the Memory counters ? |

The number of processors comes from `GetSystemInfo`.

### WMI blocks

Opened by `WmiOpenBlock` in the constructor of the provider of the built-in objects (a failure only disables the block):

| GUID | Access | Use |
|---|---|---|
| bdd865d1-d7c1-11d0-a501-00a0c9062910 | `GENERIC_READ`, `WmiQueryAllDataW` | `MSDiskDriver_Performance` (disk performance data, PhysicalDisk / LogicalDisk ?) |
| 16716917-4306-4be4-9b5a-3809ae44b125 | `GENERIC_READ`, `WmiQueryAllDataW` | ? |
| 66c1aa3c-499f-49a0-a9a5-61e2359f6407 | `GENERIC_READ`, `WmiQueryAllDataW` | ? |
| 368c45b5-c129-43c1-939e-7edc2d7fe621 | `GENERIC_EXECUTE`, `WmiExecuteMethodW` | ? |
| ba1f4c14-a945-4762-b916-0b5515b6f43a | `GENERIC_EXECUTE`, `WmiExecuteMethodW` | ? |

### IOCTL_MOUNTMGR_QUERY_POINTS (0x006D0008)

Sent to `\\.\MountPointManager` (0x102FDF0): device type 0x6D (`MOUNTMGRCONTROLTYPE`), function 2, `METHOD_BUFFERED`, `FILE_ANY_ACCESS`.

| Buffer | Size | Content |
|---|---|---|
| Input | 0x18 | `MOUNTMGR_MOUNT_POINT`, all zero (every mount point) |
| Output | 0x180 at first | `MOUNTMGR_MOUNT_POINTS`; `ERROR_MORE_DATA` (0xEA) makes the caller retry with the size returned in the first DWORD; the result is checked (size ≥ 8, `NumberOfMountPoints` consistent with the size, else 0x8007000D) |

### Registry

| Key | Value | Use |
|---|---|---|
| `HKEY_PERFORMANCE_DATA` | the perflib object indices in decimal, separated by spaces (e.g. `2328` for Database, built with `_ultow_s`, 0x10354C4) | `RegQueryValueExW` (0x10353EC), buffer of 0x1000 bytes grown on `ERROR_MORE_DATA`: `PERF_DATA_BLOCK` of the ESE database objects (`ESENT` perflib provider ?); the string `default` is used by the same function (instance name ?) |
