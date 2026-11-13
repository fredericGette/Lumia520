## BatteryLogger.exe

Battery power logger of the Windows Phone developer tools ("power on" of the phone-side power tools): it samples the battery every 100 ms while an ETW trace is being recorded, then merges the power samples into that trace.  
`BatteryLogger.exe` is a console program (45 056 bytes, 123 functions, about half of them CRT / STL helpers; no UI, no exports). It polls the battery class driver ([battc.sys](../drivers/battc.md)) with `IOCTL_BATTERY_QUERY_STATUS` from a thread-pool timer and writes the samples to a CSV file (`pwrlog.csv`). The start / stop is driven through a WNF state. At the stop it opens the ETL trace given on its command line with the ETW relogger (`ITraceRelogger`, COM) and injects the samples as events of its own provider.  
It's started by [WpToolsWrapper.exe](./wptoolswrapper.md) `-poweron`. The ETL trace it merges into (`wppr.etl`) is recorded by another tool ([WpWpr.exe](./wpwpr.md) `-stop` ?, the output file name comes from the PC).

Location on the phone: `C:\Windows\System32\BatteryLogger.exe` (path used by [WpToolsWrapper.exe](./wptoolswrapper.md)).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `RtlPublishWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `RtlRaiseException` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoCreateInstance`, `CoUninitialize` |
| api-ms-win-core-threadpool-l1-2-0.dll | `CreateThreadpool`, `SetThreadpoolThreadMaximum`, `SetThreadpoolThreadMinimum`, `CreateThreadpoolCleanupGroup`, `CreateThreadpoolTimer`, `SetThreadpoolTimer`, `CloseThreadpoolCleanupGroupMembers`, `CloseThreadpoolCleanupGroup`, `CloseThreadpool` |
| api-ms-win-devices-config-l1-1-1.dll | `CM_Get_Device_Interface_List_SizeW`, `CM_Get_Device_Interface_ListW` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `DeleteFileW` |
| api-ms-win-core-file-l2-1-1.dll | `MoveFileExW` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `Sleep` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter`, `QueryPerformanceFrequency` |
| api-ms-win-core-sysinfo-l1-2-2.dll | `GetSystemTime` |
| api-ms-win-core-timezone-l1-1-0.dll | `SystemTimeToFileTime` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleA` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| msvcrt.dll | `_wfopen`, `_wfopen_s`, `fgetws`, `fprintf`, `fflush`, `fclose`, `wprintf`, `printf`, `wcstok_s`, `_wtoi`, `_wtoi64`, `_wtof`, `_wsplitpath_s`, `wcslen`, `memcpy`, `memmove`, `memcmp`, `memset`, C++ runtime (`new` / `delete`, `exception`, `_CxxThrowException`, `__CxxFrameHandler3`, `_purecall`) and the CRT startup functions |

The application imports are the WNF, COM, thread-pool, CfgMgr / `DeviceIoControl`, file, timing and stdio functions. `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind`, `Sleep`, `GetModuleHandleA`, the process and exception-filter functions are the Visual C++ CRT startup and `/GS` cookie code; the rest of msvcrt is STL (`std::wstring`, `std::vector`) and CRT startup. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `<temp-directory>\pwrlog.csv` | `_wfopen_s` (`"w"`), then `_wfopen` (`"r"`), `DeleteFileW` | [Power samples](#pwrlogcsv) written while logging and read back for the merge. Deleted after a successful merge or a cancel |
| `<output-merged-etl>` | `ITraceRelogger::AddLogfileTraceStream`, then `MoveFileExW` target | ETL trace (recorded by another tool) into which the power samples are merged; replaced by the merged trace |
| `<output-merged-etl>.temp` | `ITraceRelogger::SetOutputFilename`, `MoveFileExW` (`MOVEFILE_REPLACE_EXISTING`) | Merged trace written by the relogger, then renamed to `<output-merged-etl>` |
| Battery device (first `GUID_DEVICE_BATTERY` interface) | `CM_Get_Device_Interface_ListW`, `CreateFileW` | [battc.sys](../drivers/battc.md) on the battery device ([NokiaEnergyDriver.sys](../drivers/nokiaenergydriver.md) with the upper filter [battfltr.sys](../drivers/battfltr.md) on the Lumia 520) |
| ETW relogger, `CLSID_TraceRelogger` {7B40792D-05FF-44C4-9058-F440C71F17D4} | `CoCreateInstance` (`CLSCTX_INPROC_SERVER`), `IID_ITraceRelogger` {F754AD43-3BCC-4286-8009-9C5DA214E84E} | Reads the trace, injects the power events, writes the merged trace (in-process server, DLL not identified: `advapi32.dll` / `sechost.dll` ?) |

### Parameters

`wmain` (`sub_100313C`, 0x100313C); its return value (an HRESULT) is the exit code.

| Command line | Usage | Exit code | Started by |
|---|---|---|---|
| `BatteryLogger.exe` with fewer than 2 arguments | Prints `Arguments:` / `<temp-directory> <output-merged-etl>` | `E_FAIL` (0x80004005) | — |
| `BatteryLogger.exe <temp-directory> <output-merged-etl>` | [Logs the battery](#logging-sub_1002b7c-0x1002b7c) into `<temp-directory>\pwrlog.csv` until the WNF state asks to stop (or 24 h), then [merges](#merge-sub_1002eb4-0x1002eb4) it into `<output-merged-etl>`. Extra arguments are ignored | `E_FAIL` if the WNF subscription fails; HRESULT of the merge; 0 after a cancel or if the logger fails to start | [WpToolsWrapper.exe](./wptoolswrapper.md) `-poweron`, with `\data\shareddata\phonetools\pwtools\temp \data\shareddata\phonetools\pwtools\log\wppr.etl` |

Steps of `wmain`:

1. `sub_10030B8` (0x10030B8): creates a manual-reset event (`CreateEventW(NULL, TRUE, FALSE)`) and subscribes to the [WNF state](#wnf-states) 0x0D92063DA3BC2075 (`RtlSubscribeWnfStateChangeNotification`, change stamp 0, callback `sub_1003074`). Failure → `E_FAIL`.
2. Publishes the WNF state = **1** (`sub_1003024`, 0x1003024): logger started.
3. Copies `argv[1]` (at most 512 characters) and builds `<temp-directory>\pwrlog.csv` (`sub_1002F98`, 0x1002F98; a `\` is added if missing, `StringCchCat`-like helper `sub_1002A94`).
4. Runs the [logger](#logging-sub_1002b7c-0x1002b7c) until the stop.
5. If the stop value was 3 (cancel): `DeleteFileW(pwrlog.csv)`, no merge. Otherwise [merge](#merge-sub_1002eb4-0x1002eb4) into `argv[2]`.
6. Publishes the WNF state = **4**: logger finished (also after a failure).

### Logging (sub_1002B7C, 0x1002B7C)

1. Allocates a 0x18-byte logger: `+00` `FILE*`, `+04` battery context, `+08` QPC at start / of the last sample, `+10` QPC frequency.
2. `sub_1002D3C` (0x1002D3C): `QueryPerformanceCounter`, `QueryPerformanceFrequency`, `_wfopen_s(pwrlog.csv, "w")`, then allocates the 0x30-byte [battery context](#battery-context), opens the battery (`sub_10031E8`) and reads the status once (`sub_10032C0`). On success it writes the [header line](#pwrlogcsv) `1000,<QPC>,<QPF>,<FILETIME>,PhoneSystem` (`GetSystemTime` + `SystemTimeToFileTime`, UTC). Any failure → `Logger failed to initialize. LastError: %u`.
3. Thread pool: `CreateThreadpool`, maximum and minimum 1 thread, a cleanup group, and a `TP_CALLBACK_ENVIRON_V3` (version 3, priority normal, size 0x28).
4. `CreateThreadpoolTimer(sub_1002B08, logger)` and `SetThreadpoolTimer`: first due time −5 000 000 (500 ms relative), **period 100 ms**.
5. `WaitForSingleObject(stop event, 86 400 000)`: waits for the WNF stop, at most 24 h (the timeout is handled as a normal stop).
6. `CloseThreadpoolCleanupGroupMembers` (cancels the timer), closes the pool, flushes and closes the CSV and the battery handle (`sub_1002E48`). Returns 1 if the timer was running.

Each tick (`sub_1002B08`, 0x1002B08): `QueryPerformanceCounter`, `IOCTL_BATTERY_QUERY_STATUS`, and if it succeeds, one line `"%I64d,%d,%d,%d\n"` = QPC, Rate × Voltage / 1000, Rate, Voltage.

### Battery context

0x30 bytes allocated by `sub_1002D3C`.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | HRESULT | `E_FAIL` / `E_ABORT` (0x80004004, `CreateFileW` failed) on error |
| 0x04 | 4 | HANDLE | Battery device, −1 when closed |
| 0x08 | 4 | Battery tag | Output of `IOCTL_BATTERY_QUERY_TAG` |
| 0x0C | 20 | `BATTERY_WAIT_STATUS` | Input of `IOCTL_BATTERY_QUERY_STATUS` |
| 0x20 | 16 | `BATTERY_STATUS` | Output: PowerState (+20), Capacity (+24), Voltage (+28), Rate (+2C) |

### Battery device (sub_10031E8, 0x10031E8)

1. `CM_Get_Device_Interface_List_SizeW` / `CM_Get_Device_Interface_ListW` for `GUID_DEVICE_BATTERY` {72631E54-78A4-11D0-BCF7-00AA00B7B32A}, no device instance, flags 0 (present interfaces). The list must be at most 255 characters; only the first interface is used.
2. `CreateFileW(interface, GENERIC_READ | GENERIC_WRITE, share 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED)` (the IOCTLs are still sent with a NULL `OVERLAPPED`).
3. `IOCTL_BATTERY_QUERY_TAG`, see below. On failure the handle is closed.

### IOCTLs sent

To the battery device, processed by [battc.sys](../drivers/battc.md).

| IOCTL | Name | In | Out | Usage |
|-------|------|----|-----|-------|
| 0x294040 | IOCTL_BATTERY_QUERY_TAG | 4 | 4 | Input: timeout 0 (return at once). Output: battery tag, stored at context +08 |
| 0x29404C | IOCTL_BATTERY_QUERY_STATUS | 20 | 16 | Input: tag, timeout 0, PowerState 0, LowCapacity 0, HighCapacity 0xFFFFFFFF (return at once). Output: `BATTERY_STATUS`; Voltage (mV) and Rate (on the Lumia 520 the negated qcbms8930 current, see [NokiaEnergyDriver.sys](../drivers/nokiaenergydriver.md)) are logged. Fails if 0 bytes are returned |

### pwrlog.csv

ANSI text written with `fprintf`, read back with `fgetws` (lines of at most 0x400 characters, tokens separated by `;`, `,`, space, `\n` or `\t`).

Header line (written by `sub_1002D3C`, parsed by `sub_1004520`, 0x1004520):

| Field | Written | Read as |
|---|---|---|
| 1 | `1000` | Multiplier (kept as the default 1 000 000 if 0) |
| 2 | QPC at start | If ≥ 1.0: "performance counter sync" mode, the QPC origin of the samples. If 0 < value < 1: sampling period in s, samples/s = 1 / value (not written by BatteryLogger) |
| 3 | QPC frequency | Divisor to convert the QPC of the samples |
| 4 | `FILETIME` (UTC) of the start | Start time, compared with the trace events to find the "PowerMark" |
| 5… | `PhoneSystem` | Names of the power sources (one `std::wstring` each, `Source %ws`). BatteryLogger writes only one |

In sync mode the reader prints `PowerData: Performance counter sync: multiplier (%d) SamplingPeriod (%lf) %d Samples/Sec` with a fixed sampling period of 0.1 s (10 samples/s).

Sample lines: `<QPC>,<power>,<Rate>,<Voltage>` with power = Rate × Voltage / 1000 (mW if Rate is in mA). The reader (`sub_10043A8`, 0x10043A8) converts the QPC into milliseconds since the start ((QPC − QPC₀) × 1 000 000 / QPF / 1000) and each following field (at most 64) into `(UINT32)(field × −1000 + 0.5)`. Field *n* is the value of source *n*: with the single source `PhoneSystem` only the power column is used (positive while discharging; a negative result, while charging, converts to 0 ?). The reader resamples on a 100 ms grid, holding the value of the first line at or after each grid point.

### Merge (sub_1002EB4, 0x1002EB4)

1. Builds `<output-merged-etl>.temp` (512 characters max; `Failed to process file name` / `Failed to create temp file name for the output merged trace`).
2. `CoInitializeEx(NULL, COINIT_MULTITHREADED)`, prints `Merging power events`.
3. `sub_1003A70` (0x1003A70):
   1. `CoCreateInstance(CLSID_TraceRelogger, NULL, CLSCTX_INPROC_SERVER, IID_ITraceRelogger)`.
   2. `AddLogfileTraceStream(<output-merged-etl>, NULL, &handle)`, `SetOutputFilename(<output-merged-etl>.temp)`.
   3. Creates the 0x548-byte callback object (vtable 0x1001764, `ITraceEventCallback`) and opens `pwrlog.csv` in it (`sub_1003554`: 64 sample buffers, one per possible source; reader object of 0x160 bytes, vtable 0x10019A0).
   4. `RegisterCallback(callback)`, `ProcessTrace()`.
4. On success: `DeleteFileW(pwrlog.csv)` and `MoveFileExW(<output-merged-etl>.temp, <output-merged-etl>, MOVEFILE_REPLACE_EXISTING)`.
5. `CoUninitialize`. Returns the HRESULT.

Callback methods:

* `OnBeginProcessTrace` (0x10034DC): reads the `TRACE_LOGFILE_HEADER` (user data ≥ 0x110 bytes, else `E_FAIL`) and keeps ReservedFlags (+108, clock type), CpuSpeedInMHz (+34), PerfFreq (+F8), StartTime (+100) and the timestamp of the header event.
* `OnEvent` (0x10035F8): converts the event timestamp to a `FILETIME` (StartTime + (timestamp − header timestamp) × 10⁷ / PerfFreq for clock type 1 = QPC; × 10 / CpuSpeedInMHz for the other non-system-time clocks; unchanged for 0 / 2). For the first event later than the start time of the CSV it prints `PowerMark found, injecting power data` and [injects all the samples](#power-sample-event) at once. Every original event is then injected unchanged (`ITraceRelogger::Inject`).
* `OnFinalizeProcessTrace` (0x10038A8): injects one [source event](#power-source-event) per power source, then prints `Finalize callback: %I64d power samples`, or `ERROR: PowerMark was not found in the trace` if no event was later than the start of the CSV (then no sample was injected).

### Power sample event

Created by `ITraceRelogger::CreateEventInstance(0, EVENT_HEADER_FLAG_CLASSIC_HEADER (0x100))` for each batch of at most 1000 samples and each source, until the CSV is exhausted:

* Timestamp and processor index: those of the event where the PowerMark was found (all the batches have the same timestamp).
* Provider {159E9C45-E250-4419-918A-D83013844013} (name not in the binary).
* Event descriptor: all zero (Id 0, version 0, opcode 0).

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | Source index | 0 = `PhoneSystem` |
| 0x04 | 4 × n | Samples | One UINT32 per 100 ms (n ≤ 1000), CSV value × −1000 (µW ?) |

### Power source event

Injected at the end of the trace (timestamp = raw timestamp of the last event + 1, no processor index set), same provider, event descriptor Id 0, **opcode 1**, one per source:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | Source index | |
| 0x04 | 4 | 2 | Version / type ? |
| 0x08 | 4 | Multiplier | 1000 (field 1 of the CSV header) |
| 0x0C | 4 | 0 | |
| 0x10 | 8 | Sampling period | `double`, 0.1 s |
| 0x18 | | Source name | UTF-16, `PhoneSystem` |

The payload size passed to `SetPayload` is (name length + 0x40C) × 2 bytes, i.e. the 0x818-byte local structure plus twice the name length (larger than the structure: probably a bug).

### WNF states

| State name | Access | Value |
|---|---|---|
| 0x0D92063DA3BC2075 | Published (4 bytes) | 1 = logger started, 4 = logger finished |
| 0x0D92063DA3BC2075 | Subscribed (callback `sub_1003074`, 0x1003074, 4-byte data) | 2 = stop and merge, 3 = stop and discard (cancel). Other values are ignored |

Same tag (`PHTL`) and family as the states of [WpToolsWrapper.exe](./wptoolswrapper.md#wnf-states) (sequence number 4). The stop values are published by [WpWpr.exe](./wpwpr.md#wnf-state): 2 by `-start` and by `-stop` (only when the state is 1; it then waits for the value 4), 3 by `-cancel`.

### Console output

Only `wprintf` / `printf` messages (the standard handles are inherited from [WpToolsWrapper.exe](./wptoolswrapper.md)): the usage, `Merging power events`, the `PowerData:` / `Determining power sources` / `Source %ws` lines of the CSV reader, `PowerMark found…`, `Finalize callback…`, and the failure messages quoted above.
