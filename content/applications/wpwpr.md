## WpWpr.exe

"Windows Phone Performance Recorder" (version resource: `FileDescription`, product "Windows Phone Developer Tools", 8.1.9651.12308): the phone-side WPR front-end of the *Windows Phone Developer Power Tools*.  
`WpWpr.exe` is a small console program (58 328 bytes for ARM, 110 functions, most of them CRT / ATL `CString` / STL `std::vector` helpers; no UI, no exports). It doesn't record anything itself: it drives the Windows Performance Recorder control API of `WindowsPerformanceRecorderControl.dll` (COM objects created with `WPRCCreateInstanceUnderInstanceName` under the WPR instance name `DevWpr`) to start, save, cancel or query an ETW recording session, and it parses the active profiles with MSXML. Three WPR profiles are embedded as `RT_RCDATA` resources.  
It also coordinates with [BatteryLogger.exe](./batterylogger.md) through the WNF state 0x0D92063DA3BC2075: `-start` and `-stop` ask a running logger to stop and merge its power samples, `-cancel` asks it to discard them.  
It's started by [WpToolsSvc.exe](./wptoolssvc.md#startwpr) (`startWpr` command of the PC tool), with stdout / stderr redirected to `wpr_output.txt`.

Location on the phone: `\DATA\SharedData\PhoneTools\PwTools\bin\WpWpr.exe` (path used by [WpToolsSvc.exe](./wptoolssvc.md)).  

### Imports

| DLL | Functions |
|-----|-----------|
| WindowsPerformanceRecorderControl.dll | `WPRCCreateInstanceUnderInstanceName` |
| ntdll.dll | `RtlQueryWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, `RtlPublishWnfStateData`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoCreateInstance`, `CoUninitialize` |
| OLEAUT32.dll | `SysAllocString`, `SysAllocStringLen`, `SysFreeString`, `VariantInit`, `VariantClear` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `FindResourceExW`, `SizeofResource`, `LoadResource`, `LockResource`, `GetModuleHandleA` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `FindResourceW` |
| api-ms-win-core-string-l1-1-0.dll | `MultiByteToWideChar` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `Sleep`, `InitializeCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapReAlloc`, `HeapFree`, `HeapSize`, `HeapDestroy` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| msvcrt.dll | `wprintf`, `_wcsicmp`, `wcslen`, `memset`, `memcpy_s`, `memmove_s`, C++ runtime (`new` / `delete`, `exception`, `type_info`, `_CxxThrowException`, `__CxxFrameHandler3`) and the CRT startup functions |

The application imports are `WPRCCreateInstanceUnderInstanceName`, the WNF functions, COM / `BSTR` / `VARIANT`, the resource functions, `MultiByteToWideChar`, the event functions and `wprintf` / `_wcsicmp`. `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind`, `Sleep`, `GetModuleHandleA`, the process and exception-filter functions are the Visual C++ CRT startup and `/GS` cookie code; the heap, critical-section and `FindResourceExW` imports come from the ATL string manager. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| WindowsPerformanceRecorderControl.dll (static import) | `WPRCCreateInstanceUnderInstanceName("DevWpr", CLSID, NULL, CLSCTX_INPROC_SERVER, IID)` | WPR control objects, see [COM objects](#com-objects) |
| MSXML (`msxml3.dll` ?) | `CoCreateInstance({2933BF90-7B36-11D2-B20E-00C04F983E60}` `CLSID_DOMDocument`, `CLSCTX_ALL`, `IID_IXMLDOMDocument`) | Parses the XML of the active profiles (`-status`) |
| WPR profile file (`<WPR-Profile>` argument) | `IProfile` method 0x64 (`LoadFromFile` ?) | Profile to record (`-start`) |
| `DEFAULTDEV.XML`, `NOTIFICATIONS.XML`, `ENTERPRISEMGMT.XML` | `FindResourceW(NULL, <WPR-Profile>, RT_RCDATA)` in WpWpr.exe | [Embedded profiles](#embedded-profiles), used when the argument isn't a loadable file |
| `<output-merged-etl>` | `IControlManager` method 0x30 (`Save` ?) | Trace file written by `-stop` |

### Parameters

Parsed by `wmain` (`sub_10024F4`, 0x10024F4); the command is compared case-insensitively (`_wcsicmp`). Fewer than 2 arguments, an unknown command or `-stop` with fewer than 2 arguments print the usage (`sub_1002354`, 0x1002354) and return `E_FAIL` (0x80004005). Every command first creates the [context](#context-sub_1002b78-0x1002b78) (`CoInitializeEx`) and releases it at the end.

| Command line | Usage | Exit code |
|---|---|---|
| `WpWpr.exe -start [-temppath <temp-directory>] <WPR-Profile1> [<WPR-Profile2> …]` | [Starts a recording](#-start) with every profile given. `-temppath` may appear anywhere among the profiles; its value is copied into a 512-character global (0x1005360) that is never read | 0 (also when the start itself fails); HRESULT of a profile that can't be added (`Failed to add profile: 0x%08x`); `E_FAIL` if `-temppath` has no value |
| `WpWpr.exe -stop <output-merged-etl> <temp-directory>` | [Saves the recording](#-stop) to `<output-merged-etl>`, then waits for [BatteryLogger.exe](./batterylogger.md) to merge its power samples. `<temp-directory>` is copied into the same unused global | 0; HRESULT of the save (`Failed to stop profiler: 0x%08x`) |
| `WpWpr.exe -cancel` | [Cancels the recording](#-cancel) and tells BatteryLogger.exe to discard its samples | 0; HRESULT (`Failed to cancel profiler: 0x%08x`) |
| `WpWpr.exe -status` | [Prints the active profiles](#-status) | 0; HRESULT (`Failed to query active profiles`) |

The usage text is `Usage:` followed by `-start <-temppath <temp-directory>> <WPR-Profile1> [<WPR-Profile2>]`, `-stop <output-merged-etl> <temp-directory>`, `-cancel`, `-status` (printed without line breaks).

### Context (sub_1002B78, 0x1002B78)

12-byte structure on the stack of `wmain`:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | `SysAllocString(L"DevWpr")` | WPR instance name passed to every `WPRCCreateInstanceUnderInstanceName` |
| 0x04 | 4 | `IProfileCollection *` | Created by the first profile added (`-start`) or returned by `Query` (`-stop`, `-cancel`, `-status`) |
| 0x08 | 4 | `IControlManager *` | Control manager |

`CoInitializeEx(NULL, COINIT_MULTITHREADED)` is called at creation; `sub_1002BBC` (0x1002BBC) calls `CoUninitialize`, releases both interfaces and frees the name.

### -start

1. Publishes the value **2** to the [WNF state](#wnf-state) 0x0D92063DA3BC2075 (`sub_10024A4`, 0x10024A4): a running [BatteryLogger.exe](./batterylogger.md#wnf-states) stops logging and merges its samples.
2. For each argument that isn't `-temppath`, `sub_1002BF8` (0x1002BF8) adds the profile:
   1. On the first call, creates the control manager and the profile collection.
   2. Creates an `IProfile` object; calls its method 0x64 (`LoadFromFile` ?) with (`<WPR-Profile>`, `L""`).
   3. If that fails, `sub_1002AA0` (0x1002AA0) looks for a resource of the same name: `FindResourceW(NULL, <WPR-Profile>, RT_RCDATA)`, `SizeofResource`, `LoadResource`, `LockResource`, converts the UTF-8 text to a wide `BSTR` (`MultiByteToWideChar`, `sub_10032D0`) and passes it to the profile method 0x68 (`LoadFromString` ?). The names `DefaultDev.xml`, `Notifications.xml` or `EnterpriseMgmt.xml` (case-insensitive) therefore select the [embedded profiles](#embedded-profiles).
   4. Adds the profile to the collection (collection method 0x1C (`Add` ?) with `VARIANT_TRUE`).
3. Calls the control manager method 0x24 (`Start` ?) with the collection; its result isn't checked. If no profile was given, nothing is started.

### -stop

1. Creates the control manager, then calls its method 0x3C (`Query` ?) with (`&collection`, `VARIANT_TRUE`): profiles of the current session.
2. Creates an `ITraceMergeProperties` object and calls its method 0x1C with (`L"TraceMerge_Default"`, `L""`): the merge settings `TraceMerge_Default` (the merge property defined in every embedded profile: custom event `EventMetadata`).
3. Control manager method 0x30 (`Save` ?) with (`<output-merged-etl>`, collection, merge properties), then method 0x2C (`Cancel` ?) with the collection: ends the session. Failure → `Failed to stop profiler: 0x%08x`.
4. Synchronisation with [BatteryLogger.exe](./batterylogger.md):
   1. `RtlQueryWnfStateData(&stamp, 0x0D92063DA3BC2075, sub_10023A0, &value, NULL)`; the callback copies the 4-byte data (other sizes: `Insufficient Buffer Length value: %lu`, no data: `Invalid Notification Buffer result`). Failure prints `Failed to publish WNF event state: 0x%08x`.
   2. `sub_1002420` (0x1002420): manual-reset event (`CreateEventW(NULL, TRUE, FALSE, NULL)`, global 0x1005B60) and `RtlSubscribeWnfStateChangeNotification` on the same state, change stamp 0, callback `sub_10023EC` (0x10023EC), which sets the event when the 4-byte value is **4**.
   3. Only if the queried value is **1** (logger started): publishes **2** (stop and merge) and `WaitForSingleObject(event, INFINITE)` until the logger publishes 4 (merge finished). Otherwise returns at once.

The output file given by the PC tool is probably `\data\shareddata\phonetools\pwtools\log\wppr.etl`, the trace into which BatteryLogger.exe merges its samples (not verified: the argument comes from the PC).

### -cancel

Creates the control manager, method 0x3C (`Query` ?) for the current session, method 0x2C (`Cancel` ?) with the collection, then publishes the value **3** to the WNF state (BatteryLogger.exe stops and discards its samples), whatever the result of the cancel.

### -status

`sub_1002EB0` (0x1002EB0):

1. Control manager method 0x3C (`Query` ?) for the current session, then collection method 0x2C: XML text of the active profiles (`BSTR`).
2. `CoCreateInstance(CLSID_DOMDocument, NULL, CLSCTX_ALL, IID_IXMLDOMDocument)`; `put_async(VARIANT_FALSE)`, `put_validateOnParse(VARIANT_FALSE)`, `loadXML(xml)`; not loaded → `E_UNEXPECTED`.
3. `selectNodes(L"WindowsPerformanceRecorder//Profiles//Profile")`; for each node, `get_attributes` → `getNamedItem(L"Name")` → `get_nodeValue`; the names are collected in a `std::vector<CString>`.

`wmain` then prints `Logging is active` and one profile name per line (`%ws\r\n`). If the query fails (no session), it prints `Failed to query active profiles` and returns the HRESULT.

### COM objects

All created by `WPRCCreateInstanceUnderInstanceName(L"DevWpr", CLSID, NULL, 1 = CLSCTX_INPROC_SERVER, IID, &p)`. Method names are tentative, from the use made of them.

| Object | CLSID | IID | Methods used (vtable offset) |
|--------|-------|-----|------------------------------|
| Control manager | `{971A7808-88BE-4AAD-9E1E-7C7E258512E3}` | `{C66BC1C2-D913-4BF0-9E08-014523E4A205}` | 0x24 `Start` ?(collection), 0x2C `Cancel` ?(collection), 0x30 `Save` ?(file, collection, merge properties), 0x3C `Query` ?(&collection, `VARIANT_TRUE`) |
| Profile collection | `{B98B53F3-83BA-4837-8946-E886BE8D4003}` | `{BB5ED25C-A7A8-4CEF-BFFD-2D9C64CB457A}` | 0x1C `Add` ?(profile, `VARIANT_TRUE`), 0x2C (→ XML `BSTR`) |
| Profile | `{D66D26BF-6098-4B78-9D94-7BC219612AE4}` | `{71E0563A-BCBC-4784-933A-735A2EF4FB8A}` | 0x64 `LoadFromFile` ?(name, `L""`), 0x68 `LoadFromString` ?(XML) |
| Trace merge properties | `{CAB2BDD5-5B3B-40AC-985F-2EA49E430FE4}` | `{629E2BBB-9629-45D8-8314-5D72324AE33F}` | 0x1C (`L"TraceMerge_Default"`, `L""`) |

### Embedded profiles

`RT_RCDATA` resources (language 1033), UTF-8 WPR profile XML. Each defines one event collector (128 KB buffers × 32), one profile in `Memory` logging mode, and the merge property `TraceMerge_Default` (custom event `EventMetadata`).

| Resource | Profile (Id) | Event providers |
|----------|--------------|-----------------|
| `DEFAULTDEV.XML` (2 935 bytes) | `CreateTrace` (`CreateTrace.Verbose.File`, "Test Profile") | `A0931276-3B7D-47B0-ABD9-37A494783CAF` (`EventProvider_XPerfCoreTest`, strict) |
| `NOTIFICATIONS.XML` (2 935 bytes) | same content as `DEFAULTDEV.XML` | same |
| `ENTERPRISEMGMT.XML` (4 735 bytes) | `EnterpriseMgmt` (`EnterpriseMgmt.Verbose.Memory`) | `Microsoft-WindowsPhone-EnrollmentClient-Provider` (level 4), `Microsoft-WindowsPhone-Enrollment-API-Provider` (4), `Microsoft-WindowsPhone-EnrollmentUX-Provider` (5, keywords 0x7), `Microsoft-WindowsPhone-SCEP-Provider` (4), `Microsoft-WindowsPhone-OmaDm-Client-Provider` (4), `Microsoft-WindowsPhone-CmCspVpnPlus` (4), `Microsoft-WindowsPhone-CmCspVpn` (5, keywords 0x3F) |

### WNF state

0x0D92063DA3BC2075 (`PHTL`, sequence number 4, the start / stop state of [BatteryLogger.exe](./batterylogger.md#wnf-states)); 4-byte values.

| Access | Command | Value |
|--------|---------|-------|
| Published (`sub_10024A4`, 0x10024A4, `RtlPublishWnfStateData(state, NULL, &value, 4, NULL)`) | `-start` | 2 = stop and merge |
| Published | `-stop`, only when the state is 1 | 2 = stop and merge |
| Published | `-cancel` | 3 = stop and discard |
| Queried (`RtlQueryWnfStateData`) | `-stop` | 1 = logger started |
| Subscribed (callback `sub_10023EC`) | `-stop` | 4 = logger finished: ends the wait |

### Console output

Only `wprintf`: the usage, `Logging is active` and the profile names, and the failure messages quoted above. The standard handles are those given by [WpToolsSvc.exe](./wptoolssvc.md#startwpr): stdout / stderr go to the file `\DATA\SharedData\PhoneTools\PwTools\log\wpr_output.txt`, whose path is returned to the PC.
