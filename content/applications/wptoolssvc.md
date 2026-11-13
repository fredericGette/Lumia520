## WpToolsSvc.exe

On-device agent of the *Windows Phone Developer Power Tools* (`PwTools.exe` on the PC): it receives text commands from the PC over the Visual Studio device connectivity (CoreCon) and starts the phone-side tools.  
`WpToolsSvc.exe` is a small console program (30 168 bytes for ARM, 63 functions, about half of them CRT / STL `std::wstring` / `std::vector` helpers; no UI, no exports). It doesn't open any socket itself: it loads the CoreCon device agent transport DLL named on its command line, opens the packet stream of the service `C48B1B43-A833-41F7-9E76-47AC1513E7F6`, and answers commands until the PC disconnects. Most commands only publish a `PHTL` WNF state; the tools themselves are [WpToolsWrapper.exe](./wptoolswrapper.md), [BatteryLogger.exe](./batterylogger.md), [WpPerfMonServer.exe](./wpperfmonserver.md), `AppVerif.exe` and `WpWpr.exe` (not analysed).  
An x86 build for the emulator sits next to it in the PC tool (`PowerTools\Support\x86\WpToolsSvc.exe`, 28 120 bytes, not analysed).

Location on the phone: `C:\Data\SharedData\PhoneTools\PwTools\bin\WpToolsSvc.exe` (observed with `tlist`). It isn't part of the phone packages: the PC copies it from `PowerTools\Support\ARM\` with CoreCon (`IFileDeployer::DownloadPackage` of the packages `37211F72-FDB4-431B-AAAA-EBAC8F5C6BCB` and `280D7035-D88D-47CF-A90C-2B19717B5C34`, see [PC side](#pc-side)), together with the transport `DeviceAgentTransport3.dll` in the same folder.  
Started by: the CoreCon client `C:\Data\SharedData\PhoneTools\11.0\CoreCon\bin\ConManClient3.exe` (itself a child of a `svchost.exe`, started with `/transport:%FOLDERID_SharedData%\PhoneTools\11.0\CoreCon\lib\tcpconnectiona3.dll`), when the PC calls `IRemoteAgent::Start("")` on the agent `280D7035-…`. Observed command line: `"C:\Data\SharedData\PhoneTools\PwTools\bin\WpToolsSvc.exe" /cclib \Data\SharedData\phonetools\pwtools\bin\DeviceAgentTransport3.dll`.

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `RtlPublishWnfStateData`, `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `GetModuleHandleA` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegGetValueW`, `RegCloseKey` |
| api-ms-win-core-file-l1-2-1.dll | `CreateFileW`, `WriteFile`, `DeleteFileW`, `CreateDirectoryW`, `GetFileAttributesW` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateProcessW`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-processenvironment-l1-2-0.dll | `GetStdHandle` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoCreateInstance`, `StringFromCLSID`, `CoTaskMemFree` |
| OLEAUT32.dll | `SysFreeString` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| msvcrt.dll | `malloc`, `free`, `_vsnwprintf`, `wcslen`, `wcsrchr`, `memcpy`, `memmove`, `memcmp`, `memset`, `operator new` / `delete`, `_purecall`, `__CxxFrameHandler3` and the CRT startup functions (`__wgetmainargs`, `_initterm`, `exit`, …) |

`Sleep`, `GetModuleHandleA`, `GetCurrentProcess`, `TerminateProcess`, the exception-filter and `Rtl*` unwind functions and the msvcrt startup functions are the Visual C++ CRT startup and `/GS` cookie code. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| CoreCon device agent transport, path in `argv[2]`: `\Data\SharedData\phonetools\pwtools\bin\DeviceAgentTransport3.dll` | `LoadLibraryExW(path, NULL, 0)`; `GetProcAddress` `GetDeviceAgentTransport`, `GetNewPacket` | Transport and packets of the [service](#protocol). At run time it also loads `C:\Data\SharedData\PhoneTools\11.0\CoreCon\lib\edbgtl3.dll` and `tcpconnectiona3.dll` (TCP connection of CoreCon) (observed with `tlist`) |
| `\DATA\SharedData\PhoneTools\PwTools\bin\WpWpr.exe` | `CreateProcessW` (`startWpr`) | Windows Performance Recorder front-end of the Power Tools (deployed from `PowerTools\Support\ARM\WpWpr.exe`, see [WpWpr.exe](./wpwpr.md)) |
| `\DATA\SharedData\PhoneTools\PwTools\log\wpr_output.txt` | `CreateFileW` (`GENERIC_WRITE`, `CREATE_ALWAYS`, inheritable) | stdout / stderr of `WpWpr.exe`; its path is returned to the PC |
| `\DATA\SharedData\PhoneTools\PwTools\log\appverif_input.txt` | `CreateFileW` (`GENERIC_WRITE`, `CREATE_ALWAYS`) + `WriteFile` | Command line of [AppVerif.exe](./appverif.md), read by [WpToolsWrapper.exe](./wptoolswrapper.md) `-appverif` |
| `\DATA\SharedData\PhoneTools\PwTools\log\appverif_output.txt` | `CreateFileW` (`GENERIC_READ`, `OPEN_EXISTING`), closed at once | Existence check of the output of `AppVerif.exe` (written by WpToolsWrapper.exe); its path is returned to the PC |
| `\data\shareddata\phonetools\pwtools\temp`, `\data\shareddata\phonetools\pwtools\log` | `GetFileAttributesW` / `CreateDirectoryW` | Created if missing by `startWpr` and `startAppVerifier` |
| any file | `DeleteFileW` (`cleanup`) | Path given by the PC |
| Application management COM server, CLSID b9e511fc-e364-497a-a121-b7b3612cedce (DLL ?) | `CoCreateInstance(CLSCTX_ALL)`, IID 698d57c2-292d-4cf3-b73c-d95a6922ed9a | Enumeration of the installed applications (`appMetadata`) |
| COM server CLSID b1aec16f-2383-4852-b0e9-8f0b1dc66b4d (DLL ?) | `CoCreateInstance(CLSCTX_INPROC_SERVER)`, IID f27c3930-8029-4ad1-94e3-3dba417810c1, then `QueryInterface` 43cb4ab1-a732-46af-b3b0-c0df4328e35a | Extensions (`Windows.Launch`, `Windows.BackgroundTasks`) of the packaged applications (`appMetadata`) |

The other tools ([WpToolsWrapper.exe](./wptoolswrapper.md), [BatteryLogger.exe](./batterylogger.md), [WpPerfMonServer.exe](./wpperfmonserver.md)) aren't started directly: they are triggered through [WNF states](#wnf-states).

### Parameters

`wmain` (`sub_10019F4`, 0x10019F4) builds the [command table](#commands), then:

| Command line | Usage | Exit code | Started by |
|---|---|---|---|
| `WpToolsSvc.exe /cclib <transport.dll>` | `argv[1]` must be exactly `/cclib` (case-sensitive); `argv[2]` is loaded with `LoadLibraryExW`, `GetDeviceAgentTransport` and `GetNewPacket` are resolved and `GetDeviceAgentTransport(&transport)` is called. Then the [service loop](#protocol) runs (`sub_1001F5C`, 0x1001F5C) until the PC disconnects | HRESULT of the load or of the service loop | `ConManClient3.exe` (CoreCon), with `/cclib \Data\SharedData\phonetools\pwtools\bin\DeviceAgentTransport3.dll`, when the PC calls `IRemoteAgent::Start` |
| fewer than 2 arguments | — | `E_FAIL` (0x80004005) | |
| `argv[1]` ≠ `/cclib` | — | `E_INVALIDARG` (0x80070057) | |

The service object (0x24 bytes) holds the service id `C48B1B43-A833-41F7-9E76-47AC1513E7F6` (`std::wstring` at +0x00), the command table (+0x10), the DLL handle (+0x14), `GetNewPacket` (+0x18), `GetDeviceAgentTransport` (+0x1C) and the transport (+0x20).

### Protocol

`sub_1001F5C` uses the transport and packet objects of the DLL (interfaces without names in the binary; the PC side is `Microsoft.SmartDevice.Connectivity.Interface.IDevicePacketStream` / `IPacket`):

1. Transport method 3 (vtable +0x0C) with (1, service id), then method 4 (+0x10) with (service id, &stream): opens the packet stream of the service (accepts the connection of the PC ?).
2. Sends a first packet (`GetNewPacket`, then packet method 9 `WriteString`): `"8.1.0.1"`, `"Ready."`. The PC (`CoreConCom::ConnectService`) checks this version (`IsCompatibleVersion`, else "Incompatible version of on-device service agent.").
3. Loop while stream method 8 (+0x20, "is connected" ?) returns TRUE: stream method 3 (+0x0C) reads a packet; 0x8000000A (`E_PENDING`, nothing yet) or another success code → next turn; an error ends the loop. The packet starts with the command name (packet method 10 `ReadString`); for the commands that take an argument, a second string is read. The handler fills a list of strings.
4. Reply packet: `WriteInt32(HRESULT)`, `WriteInt32(number of strings)`, then each string. When the handler returns no string, the single string `See HResult code.` is added. Unknown command: HRESULT `E_INVALIDARG` (0x80070057), no string.
5. At the end: stream method 9 (+0x24, close).

The PC (`CoreConCom::SendServiceCommand`) writes the command and all its arguments as strings in one packet, and reads back the code and the list of strings (`RemoteServiceResult.Code`, `MultilinePayload`; `Payload` = first string).

### Commands

Table built by `wmain`: 7 entries of 0x18 bytes {vtable whose only method is the handler, name (`std::wstring`), takes an argument (DWORD at +0x14)}.

| Command | Argument | Handler | Action | Reply strings |
|---|---|---|---|---|
| `getVersion` | package name | `sub_10025E4` (0x10025E4) | `RegOpenKeyExW(HKLM, L"SOFTWARE\\Microsoft\\Windows Phone\\Power Tools\\Packages", KEY_READ)`, `RegGetValueW(key, <argument>, L"Version", RRF_RT_REG_SZ)`. Missing key → `E_FAIL`; missing subkey or value → `E_INVALIDARG` | The version, e.g. `8.1.0.1` |
| `cleanup` | file path | `sub_1002E3C` (0x1002E3C) | `DeleteFileW(<argument>)`, error → `HRESULT` of `GetLastError` (as returned, without `HRESULT_FROM_WIN32`). No check on the path | `Cleanup triggered.` |
| `startAppVerifier` | `AppVerif.exe` arguments | `sub_1002784` (0x1002784) | See [below](#startappverifier) | `\DATA\SharedData\PhoneTools\PwTools\log\appverif_output.txt` |
| `startWpr` | `WpWpr.exe` arguments | `sub_1002AB0` (0x1002AB0) | See [below](#startwpr) | `\DATA\SharedData\PhoneTools\PwTools\log\wpr_output.txt` |
| `startPerfmon` | none | `sub_1002B60` (0x1002B60) | Publishes the 4-byte value 1 to the WNF state 0x0D92063DA3BC0875, no wait (starts [WpPerfMonServer.exe](./wpperfmonserver.md)) | `PerfMon triggered.` |
| `startBatteryLogger` | none | `sub_1002CC0` (0x1002CC0) | [Trigger](#wnf-trigger-sub_1003448-0x1003448) of the WNF state 0x0D92063DA3BC1075 (the state of [WpToolsWrapper.exe](./wptoolswrapper.md) `-poweron`, which starts [BatteryLogger.exe](./batterylogger.md)) | `Battery Logger Start triggered.` |
| `appMetadata` | none | `sub_1002F90` (0x1002F90) | See [below](#appmetadata) | Installed applications and their tasks |

Users on the PC side, in the components of the same download: `Microsoft.Phone.Tools.Power.PerfMonitor.dll` (`getVersion WpPerfMonServer.exe`, `startPerfmon`), `Microsoft.Phone.Tools.Power.AppVerifier.dll` (`getVersion WpToolsWrapper.exe` / `AppVerif.exe`, `appMetadata`, `startAppVerifier` with ` -query * -for *`, ` -enable {0} -for {1}`, ` -disable * -for {0}`). `cleanup`, `startWpr` and `startBatteryLogger` aren't named in those components (`PerfRecorder.dll` refers to `Wpr.exe`, `WprWrapperC.exe`, `wppr.etl` instead ?).

#### startAppVerifier

1. `CreateEventW(NULL, TRUE, FALSE, NULL)` for the WNF trigger.
2. Creates `\data\shareddata\phonetools\pwtools\temp` and `…\log` if they aren't directories (`sub_1002730`, 0x1002730).
3. Writes `appverif_input.txt` (`CREATE_ALWAYS`): the UTF-16 BOM `FF FE`, then the argument (UTF-16LE, without terminator).
4. [Trigger](#wnf-trigger-sub_1003448-0x1003448) of the WNF state 0x0D92063DA3BC1875, the state published by [WpToolsWrapper.exe](./wptoolswrapper.md) `-appverif` when `AppVerif.exe` has finished.
5. Checks that `appverif_output.txt` exists (`CreateFileW(GENERIC_READ, 0, NULL, OPEN_EXISTING)`); a failure is returned as the HRESULT, but the path is returned in all cases.

#### startWpr

1. Creates the `temp` and `log` folders as above.
2. `sub_100295C` (0x100295C): command line `"%s %s"` (`\DATA\SharedData\PhoneTools\PwTools\bin\WpWpr.exe`, argument); opens `wpr_output.txt` (`GENERIC_WRITE`, no sharing, `SECURITY_ATTRIBUTES{bInheritHandle = TRUE}`, `CREATE_ALWAYS`); `STARTUPINFOW` (cb 0x44, `STARTF_USESTDHANDLES`, stdin = `GetStdHandle(STD_INPUT_HANDLE)`, stdout / stderr = the file); `CreateProcessW(NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)`; `WaitForSingleObject(INFINITE)`. The exit code of `WpWpr.exe` isn't read.

#### appMetadata

1. `CoInitializeEx(NULL, COINIT_MULTITHREADED)`, `CoCreateInstance({b9e511fc-e364-497a-a121-b7b3612cedce}, NULL, CLSCTX_ALL, {698d57c2-292d-4cf3-b73c-d95a6922ed9a})` (Windows Phone package manager ?).
2. `sub_10035F8` (0x10035F8): manager method 3 (+0x0C) with a filter structure whose first DWORD is 6 → enumerator; enumerator method 3 (+0x0C) returns the next application object until `S_FALSE`. For each application:
   - `QueryInterface({2925390a-d947-4062-9dad-cf6f60e6a707})`: supported → packaged (AppX) application, else classic application;
   - method 10 (+0x28) must return 3, else the application is skipped (install state ?);
   - method 3 (+0x0C): product id (GUID); method 7 (+0x1C): name (`BSTR`, title ?);
   - classic application, `sub_1003854`: manager method 5 (+0x14) with (12, product id) → task enumerator; for each task, method 11 (+0x2C) `BSTR` (task name / id ?) and method 9 (+0x24) DWORD (task type ?, 5 by default);
   - packaged application, `sub_1003B84`: method 3 (+0x0C) of the second interface returns the package full name; `CoCreateInstance({b1aec16f-2383-4852-b0e9-8f0b1dc66b4d}, NULL, CLSCTX_INPROC_SERVER, {f27c3930-8029-4ad1-94e3-3dba417810c1})`, `QueryInterface({43cb4ab1-a732-46af-b3b0-c0df4328e35a})`, then `sub_1003A84` calls its method 3 (+0x0C)(package full name, extension point, &array, &count) for `Windows.Launch` (type 1) and `Windows.BackgroundTasks` (type 4); each returned string is kept from its last `\` (application id).
3. Reply strings: the number of applications (`%d`), then for each application: name, product id (`StringFromCLSID`, `{…}`), number of tasks (`%d`), then for each task its name and its type (`%d`). The PC tool shows the types as `TaskTypeLaunch`, `TaskTypeBackground`, `TaskTypeUnknown` and adds `taskhost.exe` / `aghost.exe` as the processes to verify.

Records built in memory: application 0x2C bytes {name `std::wstring` (0x10), product id GUID (+0x10), vector of tasks (+0x20)}; task 0x14 bytes {name `std::wstring` (0x10), type DWORD (+0x10)}.

### WNF trigger (sub_1003448, 0x1003448)

Used by `startAppVerifier` and `startBatteryLogger`, with a structure {event, state name low, state name high, subscription, expected value = 2}:

1. `RtlSubscribeWnfStateChangeNotification(&sub, state, 0, sub_1003524, &context)`; the callback checks the state name and a 4-byte value, and sets the event when the value is 2.
2. `RtlPublishWnfStateData(state, NULL, &1, 4, NULL)`: value 1 = start request.
3. `WaitForSingleObject(event, 1000)`: timeout → `E_ABORT` (0x80004004); otherwise `ResetEvent` and `RtlUnsubscribeWnfNotificationWaitForCompletion`.

The value 2 is the completion value published by [WpToolsWrapper.exe](./wptoolswrapper.md#runtool-0x10040d8) on the same states. The value 1 fires the tasks `AppVerifWrapperImmediate` and `BatteryLoggerStartImmediate` of [TaskSchedulerSvc.dll](../libraries/taskschedulersvc.md#tasks-of-a-phone) (WNF trigger condition 1, value 1), which start `WpToolsWrapper.exe -appverif` / `-poweron`; the task `WpPerfMonServerImmediate` does the same for `startPerfmon`.

### WNF states

All `PHTL`, version 1, well-known lifetime, system scope (same family as [WpToolsWrapper.exe](./wptoolswrapper.md#wnf-states) and [BatteryLogger.exe](./batterylogger.md#wnf-states)).

| State name | Sequence | Command | Published | Waited for |
|---|---|---|---|---|
| 0x0D92063DA3BC0875 | 1 | `startPerfmon` | 1 | — |
| 0x0D92063DA3BC1075 | 2 | `startBatteryLogger` | 1 | 2, 1 s |
| 0x0D92063DA3BC1875 | 3 | `startAppVerifier` | 1 | 2, 1 s |

### Registry

| Key | Value | Type | Access |
|---|---|---|---|
| `HKLM\SOFTWARE\Microsoft\Windows Phone\Power Tools\Packages\<name>` | `Version` | REG_SZ | Read by `getVersion`; written by the phone packages, e.g. `Microsoft.Tools.PerfMonExt` ([WpPerfMonServer.exe](./wpperfmonserver.md)) and `Microsoft.Tools.DevToolSupport` (`BatteryLogger.exe`, `WpToolsWrapper.exe`), all `8.1.0.1` |

### PC side

`Microsoft.Phone.Tools.Power.Connectivity.dll` (`CoreConCom::ConnectService`):

1. `IDevice::GetFileDeployer()`, `DownloadPackage("37211F72-FDB4-431B-AAAA-EBAC8F5C6BCB")` and `DownloadPackage("280D7035-D88D-47CF-A90C-2B19717B5C34")` (constants `CoreConPacketTransportGuid`, `WpToolsSvcPackageGuid`, `WpToolsSvcServiceGuid` in the assembly). `37211F72-…` is also downloaded by `UpdatePack.exe` before its own agent `769BAC05-…` (`DuTrigger.exe`, same `/cclib` framework), so it is the transport `DeviceAgentTransport3.dll`, and `280D7035-…` is `WpToolsSvc.exe` ?
2. `IDevice::GetRemoteAgent("280D7035-…")`, `IRemoteAgent::Start("")`.
3. `IRemoteAgent::CreatePacketStream("C48B1B43-A833-41F7-9E76-47AC1513E7F6")`, reads the version / `Ready.` packet, checks the version.
4. Commands with `SendServiceCommand(command, args[])` as described in [Protocol](#protocol).
