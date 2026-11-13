## tracelog.exe

The ETW trace session controller ("TraceLog") of Windows, built for the phone.  
`tracelog.exe` (90 112 bytes, 70 functions, PDB `mintracelog.pdb`, the "min" OneCore build of the WDK `tracelog` tool) is a console program: it starts, updates, stops, flushes and queries ETW sessions (including the `NT Kernel Logger`), enables or disables providers in them, lists the registered providers, and writes the registry configuration of the `GlobalLogger` and of AutoLogger sessions. It has no UI and no service part. Everything goes through the ETW controller API (`StartTraceW`, `ControlTraceW`, `QueryAllTracesW`, `EnableTrace`, plus `EnableTraceEx2` / `TraceSetInformation`… taken from `advapi32.dll` at run time) and, for kernel profiling settings, `NtSetSystemInformation` / `NtQuerySystemInformation`.  
It doesn't log events itself; the `.etl` files are written by the kernel.

Location on the phone: `C:\Windows\System32\tracelog.exe` ? (no path in the binary, no notes next to the extracted file).  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-eventing-controller-l1-1-0 | `StartTraceW`, `ControlTraceW`, `QueryAllTracesW` |
| api-ms-win-eventing-legacy-l1-1-0 | `EnableTrace` |
| ntdll | `NtSetSystemInformation`, `NtQuerySystemInformation`, `RtlAdjustPrivilege`, `RtlGetVersion`, `RtlInitUnicodeString`, `RtlNtStatusToDosError`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-registry-l1-1-0 | `RegCreateKeyExW`, `RegOpenKeyExW`, `RegSetValueExW`, `RegEnumValueW`, `RegDeleteValueW`, `RegDeleteKeyExW`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleA` |
| api-ms-win-security-sddl-l1-1-0 | `ConvertSecurityDescriptorToStringSecurityDescriptorW` |
| api-ms-win-core-heap-obsolete-l1-1-0 | `LocalFree` |
| api-ms-win-core-processenvironment-l1-2-0 | `GetCurrentDirectoryW` |
| api-ms-win-core-localization-l1-2-1 | `FormatMessageW` |
| api-ms-win-core-synch-l1-2-0 | `Sleep` |
| api-ms-win-core-errorhandling-l1-1-2 | `GetLastError`, `SetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-processthreads-l1-1-2 | `GetCurrentProcess`, `TerminateProcess` |
| msvcrt | `wprintf`, `printf`, `wscanf_s`, `swprintf_s`, `_wfopen`, `fgetws`, `fgetc`, `fscanf`, `fclose`, `_wfullpath`, `_wcsicmp`, `wcscmp`, `wcslen`, `wcschr`, `wcsrchr`, `wcsstr`, `wcstok_s`, `wcscpy_s`, `wcsncpy_s`, `towupper`, `iswctype`, `_wtoi`, `_wtol`, `_wtoi64`, `malloc`, `free`, `memcpy`, `memset`, `memcmp`, CRT startup (`__wgetmainargs`, `_initterm`, `_amsg_exit`, `_exit`, `_cexit`, `exit`, `__set_app_type`, `__setusermatherr`, `_fmode`, `_commode`, `_XcptFilter`, `__C_specific_handler`, `?terminate@@YAXXZ`) |

`GetModuleHandleA`, the `Rtl*Unwind`/`RtlCaptureContext` functions, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `GetCurrentProcess`, `TerminateProcess` and the CRT startup functions of msvcrt are the standard Visual C++ CRT and `/GS` boilerplate. The only export is the entry point `wmainCRTStartup`.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `advapi32.dll` | `LoadLibraryExW` (0x40A464), kept until exit | `GetProcAddress` of `EnumerateTraceGuids` (always), `EnableTraceEx`, `EnumerateTraceGuidsEx` (Vista and later), `EnableTraceEx2`, `TraceSetInformation` (Win7 and later), `TraceQueryInformation` (Win8 and later). Stored in `FuncArray` (0x4123A0) |
| `api-ms-win-eventing-controller-l1-1-0` | `LoadLibraryExW` (0x40A484), only if `advapi32.dll` can't be loaded and the OS is Win8 or later | Same `GetProcAddress` calls as `advapi32.dll` |
| `kernel32.dll` | `LoadLibraryExW` (0x40A4B8), never freed | Only checked to exist: if it loads, `kernelbase.dll` is loaded |
| `kernelbase.dll` | `LoadLibraryExW` (0x40A4CA), freed right after | `GetProcAddress("HeapSetInformation")`, called as `HeapSetInformation(NULL, HeapEnableTerminationOnCorruption, NULL, 0)` |
| GUID file (`-guid <file>`) | `_wfullpath`, `_wfopen(…, "r")`, `fgetws` (`GetGuids`, 0x40D934) | List of providers to enable, see [GUID file](#guid-file) |
| Stack walk parameter file (`-stackwalk <file>`) | `_wfullpath`, `_wfopen(…, "r")`, `fgetc` / `fscanf` (`GetStackWalkFilter`, 0x40EDD8) | Kernel hooks to collect stacks on, see [Stack walk parameter file](#stack-walk-parameter-file) |
| `<current directory>\LogFile.Etl` | `GetCurrentDirectoryW` (0x40BFDC), name passed to `StartTraceW` | Default log file of `-start` when neither `-f`, `-rt` (`EVENT_TRACE_REAL_TIME_MODE` 0x100) nor `-buffering` (0x400) is given and the logger isn't the `GlobalLogger` |
| `-f <name>` | `_wfullpath`, name passed to `StartTraceW` / `ControlTraceW` or written in the registry `FileName` | Log file of the session (opened by the kernel, not by tracelog.exe) |

No process is started, no COM server and no device is opened.

### Parameters

`wmain` (0x40A320) first calls `RtlGetVersion` to set the globals `XP` (> 5.0), `LH` (≥ 6), `WIN7` (> 6.0), `WIN8` (> 6.1), `WINBLUE` (> 6.2), which hide options of the help text and functions that the OS doesn't have; on WP8.1 (6.3) they are all set. It then allocates the session properties (see [EVENT_TRACE_PROPERTIES](#event_trace_properties)) with the logger name `NT Kernel Logger`, and parses the command line in one loop. Options may start with `-`, `/` or a Unicode dash (U+2010, U+2011, U+2013, U+2014, U+2212; `IsOption`, 0x40A2D8), are compared without case, and the first one is rewritten to `-`. Unknown options print `Invalid option given: %s` and the help (`PrintHelpMessage`, 0x40DC54, also for `-h`, `-help`, `-?`).

The exit code is the Win32 error of the last operation (0 on success, 87 for a bad parameter, 14 when out of memory, 123 for a name that is too long; also passed to `SetLastError`). After the start, stop, update, flush, query and enable/disable actions, the session properties returned by the kernel are printed by `PrintLoggerStatus` (0x40D31C). There is no caller on the phone in the analysed binaries; it's a developer tool started from a shell.

#### Actions

Only one action is executed. `[LoggerName]` is optional and defaults to `NT Kernel Logger`; the names `GlobalLogger` and `WMI Event Logger` select the `GlobalLoggerGuid` / `WmiEventLoggerGuid` session GUIDs.

| Command line | Usage |
|---|---|
| `tracelog -start [LoggerName] [options]` | `StartTraceW` (0x40C1D0) with the properties built from the options, then PMC configuration (`ConfigurePmcCollection`, 0x40A1C0), object type filter, stack caching (`EnableStackCaching`, 0x40A288) and the provider enables of `-guid`. For `GlobalLogger` nothing is started: `SetGlobalLoggerSettings` (0x40E230) writes the settings and `Start` = 1 in the [registry](#registry). A private logger (`-um`, `EVENT_TRACE_PRIVATE_LOGGER_MODE` 0x800) needs exactly one GUID. With `-newfile` the file name must contain `%d`; with `-prealloc` a size is required. Error 32 (sharing violation) prints `This error is most commonly caused when file '%s'is in use by another logger.` |
| `tracelog -stop [LoggerName]` | Disables the `-guid` providers (`EnableTrace(FALSE, …)`), then `ControlTraceW(EVENT_TRACE_CONTROL_STOP)` |
| `tracelog -update [LoggerName] [options]` | `ControlTraceW(EVENT_TRACE_CONTROL_UPDATE)` with the new buffers / flush timer / file / flags |
| `tracelog -flush [LoggerName]` | `ControlTraceW(EVENT_TRACE_CONTROL_FLUSH)` |
| `tracelog -q [LoggerName]` | `ControlTraceW(EVENT_TRACE_CONTROL_QUERY)`; for `GlobalLogger`, the registry settings are read by `GetGlobalLoggerSettings` (0x40E5EC, `Registry set to start` / `Registry set to stop`; `GlobalLogger is not running`). Also prints the session security descriptor and the stack-traced hooks (`PrintSessionSecurityInfo` 0x40F29C, `PrintSessionStackTracingInfo` 0x40F360, see [Kernel calls](#kernel-calls)). This is also the default action when none is given |
| `tracelog -l [-lp]` | `QueryAllTracesW` for 64 sessions (32 before XP) and prints each one. `-lp` also lists the providers enabled in each session (`PrintProvidersForSessionId` 0x40F468, `EnumerateTraceGuidsEx(TraceGuidQueryList)` then `TraceGuidQueryInfo` per GUID) |
| `tracelog -x` / `tracelog -xf` | Stops all the sessions returned by `QueryAllTracesW`: for each one, asks `Do you want to stop the "%s" session (Y or N)?` (read with `wscanf_s`); `-xf` (not in the help) stops without asking. Before `ControlTraceW(…, EVENT_TRACE_CONTROL_STOP)`, sessions other than the kernel logger (`SystemTraceControlGuid`) get `EnableTrace(FALSE, …, &Wnode.Guid, handle)` |
| `tracelog -enable [LoggerName] -guid …` / `-disable` | `EnableTrace` (TRUE/FALSE) for each GUID with `-flag` and `-level`. Kernel logger: `System Logger does not accept application guids` |
| `tracelog -enableex [LoggerName] -guid …` / `-disableex` | `EnableTraceEx2` with `-matchanykw`, `-matchallkw`, `-level`, `-enableproperty`, `-sourceguid`, `-timeout` and the event filters (see [Enable filters](#enable-filters)) |
| `tracelog -capturestate [LoggerName] -guid …` | `EnableTraceEx2(EVENT_CONTROL_CODE_CAPTURE_STATE)`: `CaptureState request for logger %I64d` |
| `tracelog -systemrundown [LoggerName]` | `EnableTraceEx2` of the system trace provider with an `EVENT_FILTER_TYPE_SYSTEM_FLAGS` (0x80000001) filter holding the 0x20-byte kernel group mask: `System Rundown request for logger 0x%I64x` |
| `tracelog -enumguid` | `EnumerateTraceGuids`: GUID, enabled, logger id, level, flags of every registered provider |
| `tracelog -enumguidex [#<guid>]` | `EnumerateTraceGuidsEx`: the instances of each provider (user mode with PID, pre-enabled, driver) and the sessions they are enabled in (`PrintEnableInfo`, 0x40F040) |
| `tracelog -addautologger <LoggerName> -sessionguid #<guid> [options] [-guid …]` | Writes `…\WMI\AutoLogger\<LoggerName>` (`SetGlobalLoggerSettings`) and one subkey per provider (`AddAutoLoggerProvider` 0x40EB18, `AddAutoLoggerProviderFilters` 0x40E86C), see [Registry](#registry). The `missing the session GUID` check (error 87) only runs when `WIN7` is clear, so not on the phone |
| `tracelog -remove GlobalLogger` | `SetGlobalLoggerSettings(0, …)` (0x40CA7A) with the logger name: deletes the values of the `GlobalLogger` key (or `AutoLogger\<LoggerName>` for another name), writes `Start` = 0 (and `ClockType` if a clock option is given), then prints the settings left (`GetGlobalLoggerSettings`) |

#### Options

| Option | Effect |
|---|---|
| `-b <n>` | `BufferSize` (KB). Before Win8, limited to 3 KB when the kernel debugger is on |
| `-min <n>`, `-max <n>` | `MinimumBuffers`, `MaximumBuffers` |
| `-f <name>` | Log file (full path from `_wfullpath`) |
| `-kb` | `MaximumFileSize` in KB (`EVENT_TRACE_USE_KBYTES_FOR_SIZE` 0x2000) |
| `-seq <n>`, `-cir <n>`, `-newfile <n>` | Sequential (0x1), circular (0x2), new file (0x8) log file of n MB |
| `-append`, `-prealloc`, `-delaycreate` | `EVENT_TRACE_FILE_MODE_APPEND` (0x4), `EVENT_TRACE_FILE_MODE_PREALLOCATE` (0x20), delay open (0x1200, not in the help) |
| `-rt`, `-buffering`, `-kd` | Real-time (0x100), buffering-only (0x400), kernel debugger (`EVENT_TRACE_KD_FILTER_MODE` 0x80000). `-rt b` is refused: `has been replaced by -buffering` |
| `-UseSystemTime`, `-UsePerfCounter`, `-UseCPUCycle` | `Wnode.ClientContext` 2, 1, 3 (also `ClockType` in the registry) |
| `-ft <n>`, `-bt <n>`, `-age <n>` | `FlushTimer` (s), `FlushThreshold` (buffers, `AgeLimit` field; not with `-age`), `AgeLimit` (min) |
| `-paged`, `-secure`, `-um`, `-ls`, `-gs`, `-lowcapacity`, `-independent`, `-systemlogger`, `-addtotriagedump` | `EVENT_TRACE_USE_PAGED_MEMORY` (0x1000000), `EVENT_TRACE_SECURE_MODE` (0x80), private logger (0x800), local (0x8000) / global (0x4000) sequence numbers, no per-processor buffering (0x10000000), independent session (0x8000000), `EVENT_TRACE_SYSTEM_LOGGER_MODE` (0x2000000), triage dump (0x80000000) |
| `-hybridshutdown stop\|persist` | 0x400000 / 0x800000 |
| `-LoggerMode <n>`, `-LogFileMode <n>` | ORs a raw value (decimal or `0x…`) into `LogFileMode` (not in the help) |
| `-noprocess`, `-nothread`, `-nodisk`, `-nonet`, `-fio`, `-pf`, `-hf`, `-img`, `-cm` | Kernel logger `EnableFlags` (process, thread, disk I/O, TCP/IP off; file I/O, page faults, hard faults, image load, registry on). The last five are ignored with `-eflag` |
| `-flag <n>` / `-flags`, `-level <n>`, `-matchanykw <n>`, `-matchallkw <n>`, `-enableproperty <n>`, `-sourceguid #<guid>` | Enable parameters of the providers |
| `-eflag <n> <groups…>` / `-eflags` | Kernel group mask (`PERFINFO_GROUPMASK`, 8 DWORDs, `GroupMask` 0x4124F0) as a `+` list of group names (`ParseKernelFlags`, 0x40F104; `Help` lists 81 names: `PROC_THREAD`, `LOADER`, `DISK_IO`, `HARD_FAULTS`, `CSWITCH`, `DPC`, `INTERRUPT`, `PROFILE`, `PMC_PROFILE`, `POWER`, `ALPC`, `POOL`, `TIMER`, `IDLE_STATES`, `WAKE_COUNTER`, `WDF_DPC`, …, with the aliases `Base`, `Diag`, `Delay`), or as n hex numbers. Enables `SeSystemProfilePrivilege` when the profile groups are selected |
| `-dpcisr` | Group mask for DPC/ISR analysis (not with `-eflag`) |
| `-guid <file>` / `-guid #<guid>` | Providers to enable (up to 128, from a [GUID file](#guid-file)) |
| `-heap`, `-critsec`, `-pids <n> <pid…>` | `HeapGuid` / `CritSecGuid` as the GUID of a private logger (`-critsec` sets 0x800); PIDs extension item. A session with these GUIDs and the extension flag gets `Wnode.HistoricalContext` = 0x1000001 |
| `-batched` | ORs 0x40000 into `LogFileMode` (not in the help) |
| `-sessionguid #<guid>` | `Wnode.Guid` of the session (AutoLogger `Guid` value) |
| `-stackwalk <Events>` | Stack collection on kernel hooks: a [parameter file](#stack-walk-parameter-file), or a `+` list of hook names (`ParseEventHooks` 0x40ED24; `Help` lists 128 hooks: `ProcessCreate`, `ImageLoad`, `CSwitch`, `Profile`, `DiskRead`, `AlpcSendMessage`, `HeapAlloc`, `PoolAllocation`, `WakeChargeUser`, …). Maximum 64 |
| `-StackCache` / `-StackCaching` | After the start, `EnableStackCaching` (not in the help) |
| `-ObjectTypeFilter <types>` | Up to 4 object type tags (4 ASCII characters, padded with spaces) for the handle trace (not in the help) |
| `-ProfileSource <src>` / `-ProfileSources` | Profile sources by name (`+` or `,` separated, max 4; `Help` lists id, name, interval, min, max), applied with `TraceSetInformation(TraceProfileSourceConfigInfo)` |
| `-SetProfInt <n> <src>` | `SetProfileInterval` (0x40F810): `TraceSetInformation(TraceSampledProfileIntervalInfo)` |
| `-Pmc <Ctrs>:<Events>` | PMC counters (profile source names) sampled on kernel hooks, applied after the start |
| `-ExeFilter`, `-PkgIdFilter`, `-PkgAppIdFilter <names>` | `;`-separated filters (max 511 characters) |
| `-PidFilter <n> <pid…>` | Max 8 PIDs |
| `-EventIdFilter -in\|-out <n> <id…>`, `-StackWalkFilter -in\|-out <n> <id…>` | Max 64 event ids |
| `-timeout <n>` | Enable timeout (ms), makes `-enableex` synchronous |
| `-delay <n>` | `Sleep(n)` after the action, before printing the status (not in the help) |
| `-filter <hex>` | 4-byte `EVENT_FILTER_DESCRIPTOR` of type 0 sent with the enable (not in the help) |

### EVENT_TRACE_PROPERTIES

Block of 0x11B0 bytes allocated by `wmain` (0x40A572) and passed to `StartTraceW` / `ControlTraceW`.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0x11B0 | `Wnode.BufferSize` |
| 0x08 | 8 | 0 or 0x1000001 | `Wnode.HistoricalContext`, 0x1000001 for the heap / critsec sessions with extension items |
| 0x18 | 16 | session GUID | `Wnode.Guid`: `-sessionguid`, `GlobalLoggerGuid`, `WmiEventLoggerGuid`, `HeapGuid`, `CritSecGuid`, or the provider GUID of a private logger |
| 0x28 | 4 | 0–3 | `Wnode.ClientContext` (clock type) |
| 0x2C | 4 | 0x20000 | `Wnode.Flags` = `WNODE_FLAG_TRACED_GUID` |
| 0x30–0x4C | | options | `BufferSize`, `MinimumBuffers`, `MaximumBuffers`, `MaximumFileSize`, `LogFileMode`, `FlushTimer`, `EnableFlags`, `AgeLimit` |
| 0x48 | 4 | 0x80FF1078 | `EnableFlags` when there are extension items (`InitializeExtItems`, 0x40EF78): `TRACE_ENABLE_FLAG_EXTENSION` with offset 0x1078 (word), length 0xFF (byte), flag 0x80 (`EVENT_TRACE_FLAG_EXTENSION`). Otherwise the kernel flags; default for `NT Kernel Logger`: process, thread, disk I/O (0x100), TCP/IP (0x10000) |
| 0x6C | 4 | 0x878 | `LogFileNameOffset` |
| 0x70 | 4 | 0x78 | `LoggerNameOffset` |
| 0x78 | 0x800 | `L"NT Kernel Logger"` | Logger name (1024 characters) |
| 0x878 | 0x800 | | Log file name |
| 0x1078 | 0x138 | | Extension items (`AddExtFlagEntry`, 0x40EF18): header (word total size in DWORDs, word count), then items (word size in DWORDs, word type, data) of type 1 group mask (0x20 bytes), 2 PIDs, 3 stack walk hook ids |

### Enable filters

`EVENT_FILTER_DESCRIPTOR` entries built for `EnableTraceEx2` (0x40C660–0x40C7A0):

| Type | Option |
|------|--------|
| 0 | `-filter` |
| 0x80000001 `EVENT_FILTER_TYPE_SYSTEM_FLAGS` | group mask of `-systemrundown` |
| 0x80000004 `EVENT_FILTER_TYPE_PID` | `-PidFilter` |
| 0x80000008 `EVENT_FILTER_TYPE_EXECUTABLE_NAME` | `-ExeFilter` |
| 0x80000010 `EVENT_FILTER_TYPE_PACKAGE_ID` | `-PkgIdFilter` |
| 0x80000020 `EVENT_FILTER_TYPE_PACKAGE_APP_ID` | `-PkgAppIdFilter` |
| 0x80000200 `EVENT_FILTER_TYPE_EVENT_ID` | `-EventIdFilter` |
| 0x80001000 `EVENT_FILTER_TYPE_STACKWALK` | `-StackWalkFilter` |

### GUID file

Read by `GetGuids` (0x40D934), one provider per line, up to 128 lines of up to 1024 characters. Lines starting with `;`, `#` or `/`, and lines shorter than 36 characters, are skipped. Fields, separated by spaces, tabs, `,` or `;` (braces allowed around the GUID): `<guid> [flags] [level]`; flags and level are decimal or `0x` hex. Each entry is 0x1C bytes: GUID, "level given" flag (+0x10), flags (+0x14), level (+0x18).

### Stack walk parameter file

Read by `GetStackWalkFilter` (0x40EDD8): `!` starts a comment line; `% <group> <type>` (two hex bytes, ≤ 0xFF) adds the hook id `group << 8 | type`; `#` lines print `StackWalinging is only supported for HookId`; any other character stops the parsing. Maximum 64 hooks. If the argument can't be opened, it's parsed as a `+` list of hook names.

### Registry

Root `HKLM\SYSTEM\CurrentControlSet\Control\WMI\`, opened with `RegCreateKeyExW(…, KEY_QUERY_VALUE | KEY_SET_VALUE)`.

| Key | Value | Type | Content |
|-----|-------|------|---------|
| `GlobalLogger` or `AutoLogger\<LoggerName>` | `Start` | REG_DWORD | 1 (start at boot) / 0 (`-remove`) |
| | `BufferSize`, `MaximumBuffers`, `MinimumBuffers`, `FlushTimer`, `LogFileMode`, `MaxFileSize`, `FlushThreshold`, `ClockType` | REG_DWORD | From the options (only the non-zero ones) |
| | `EnableKernelFlags` | REG_BINARY | 0x20-byte group mask (`-eflag`), for the `GlobalLogger` or a `-systemlogger` AutoLogger |
| | `FileName` | REG_SZ | `-f` |
| | `Guid` | REG_SZ | `{session GUID}`, AutoLogger only |
| `AutoLogger\<LoggerName>\{provider GUID}` | `Enabled` | REG_DWORD | 1 |
| | `EnableProperty`, `EnableLevel` | REG_DWORD | `-enableproperty`, level (from the GUID file or `-level`) |
| | `MatchAnyKeyword`, `MatchAllKeyword` | REG_QWORD | flags from the GUID file, or `-matchanykw` / `-matchallkw` |
| `AutoLogger\<LoggerName>\{provider GUID}\Filters` (deleted with `RegDeleteKeyExW`, then recreated) | `ExeFilter`, `PackageIdFilter`, `PackageRelativeAppIdFilter` | REG_SZ | `-ExeFilter`, `-PkgIdFilter`, `-PkgAppIdFilter` |
| | `EventIdFilterIn`, `EventIds` | REG_DWORD, REG_BINARY | `-EventIdFilter` (1 = `-in`) and the ids |
| | `StackWalkFilterIn`, `StackWalkIds` | REG_DWORD, REG_BINARY | `-StackWalkFilter` |
| | `Enabled` | REG_DWORD | 1 |

`GetGlobalLoggerSettings` (0x40E5EC) reads the same values back with `RegOpenKeyExW` / `RegEnumValueW` and prints `Warning: Unidentified Key in the trace registry: %s` for unknown ones.

### Kernel calls

| Call | Class / arguments | Used by |
|------|-------------------|---------|
| `RtlAdjustPrivilege(11, TRUE, FALSE, …)` | `SeSystemProfilePrivilege`, restored after the call | `-ProfileSource`, `-SetProfInt`, profile groups of `-eflag` |
| `NtSetSystemInformation(31, …)` | `SystemPerformanceTraceInformation`, sub-class 14 (PMC event list ?): logger handle + hook ids | `ConfigurePmcCollection`, after `TraceSetInformation(handle, 9 TracePmcCounterListInfo, PmcSettings)` |
| `NtSetSystemInformation(31, …)` | sub-class 16 (stack caching ?), 0x20 bytes: logger handle, enable = 1 | `EnableStackCaching` (0x40A288) |
| `NtSetSystemInformation(31, …)` | sub-class 17 (object type filter ?): logger handle + up to 4 type tags | `-ObjectTypeFilter` (0x40C2A2, `Failed to configure handle trace filter`) |
| `NtQuerySystemInformation(31, …)` | sub-class 4 (session security): security descriptor of the logger, printed with `ConvertSecurityDescriptorToStringSecurityDescriptorW` (SDDL, owner/group/DACL/SACL) | `PrintSessionSecurityInfo` |
| `NtQuerySystemInformation(31, …)` | sub-class 6 (stack tracing): list of hook ids | `PrintSessionStackTracingInfo` |
| `TraceQueryInformation(0, 7, …)` / `(0, 5, …)` | `TraceProfileSourceListInfo`, `TraceSampledProfileIntervalInfo` | `GetProfileSources` (0x40F65C) |
| `TraceSetInformation(handle, 6 / 5, …)` | `TraceProfileSourceConfigInfo`, `TraceSampledProfileIntervalInfo` | `-ProfileSource`, `-SetProfInt` |

### GUIDs

| GUID | Name | Use |
|------|------|-----|
| `{9e814aad-3204-11d2-9a82-006008a86939}` | `SystemTraceControlGuid` | Kernel logger; not disabled by `-x` |
| `{e8908abc-aa84-11d2-9a93-00805f85d7c6}` | `GlobalLoggerGuid` | `GlobalLogger` session |
| `{44608a51-1851-4456-98b2-b300e931ee41}` | `WmiEventLoggerGuid` | `WMI Event Logger` session |
| `{222962ab-6180-4b88-a825-346b75f2a24a}` | `HeapGuid` | `-heap` |
| `{3ac66736-cc59-4cff-8115-8df50e39816b}` | `CritSecGuid` | `-critsec` |
