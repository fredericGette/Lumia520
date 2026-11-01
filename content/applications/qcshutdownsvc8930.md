## QcShutdownSvc8930.exe

Qualcomm Shutdown Service (`QcShutdownSvc`): a Win32 service that lets a host DIAG tool (QPST, QXDM) change the operating mode of the modem, or reset / power off the phone, with the DIAG command `0x29` (`DIAG_CONTROL_F`, "mode change").  
It's a local DIAG client of [qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md#local-diag-clients): it registers the command code `0x29` on `\\.\DiagRouter` and waits for the requests. Mode changes are sent to every DMS (Device Management Service, QMI service 2) server of the modem with [qccium8930.dll](../libraries/qccium8930.md) (`QMI_DMS_SET_OPERATING_MODE`); reset and power off are done with `InitiateSystemShutdownExW`.  
The same binary also installs (`-i`) and deletes (`-d`) the service. The PDB path is `P:\ShutdownSvc\rel\8.3\QcShutdownSvc\arm\Release_WP\qcshutdownsvc8930.pdb`.

Location on the phone: `C:\Windows\System32\QcShutdownSvc8930.exe` ? (the extracted file has no notes; `-i` registers the path returned by `GetModuleFileNameW`).  

### Imports

| DLL | Functions |
|-----|-----------|
| qccium8930.dll | `qmi_client_init`, `qmi_client_notifier_init`, `qmi_client_get_service_list`, `qmi_client_send_msg_sync`, `qmi_client_release` |
| api-ms-win-service-core-l1-1-1.dll | `RegisterServiceCtrlHandlerExW`, `StartServiceCtrlDispatcherW`, `SetServiceStatus` |
| api-ms-win-service-management-l1-1-0.dll | `CreateServiceW`, `CloseServiceHandle`, `StartServiceW`, `OpenServiceW`, `OpenSCManagerW`, `DeleteService` |
| api-ms-win-service-management-l2-1-0.dll | `QueryServiceStatusEx` |
| api-ms-win-core-file-l1-2-0.dll | `ReadFile`, `WriteFile`, `CreateFileW` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-devices-config-l1-1-0.dll | `CM_Register_Notification`, `CM_Unregister_Notification` |
| api-ms-win-core-registry-l1-1-0.dll | `RegCloseKey`, `RegQueryValueExW`, `RegOpenKeyExW` |
| api-ms-win-core-shutdown-l1-1-0.dll | `InitiateSystemShutdownExW` |
| api-ms-win-security-lsalookup-l2-1-0.dll | `LookupPrivilegeValueW` |
| api-ms-win-security-base-l1-2-0.dll | `AdjustTokenPrivileges` |
| api-ms-win-core-processthreads-l1-1-1.dll | `TerminateThread`, `GetCurrentProcess`, `OpenProcessToken`, `GetCurrentThreadId`, `CreateThread` |
| api-ms-win-core-synch-l1-2-0.dll | `WaitForSingleObject`, `ResetEvent`, `CreateEventW`, `SetEvent` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventUnregister`, `EventRegister`, `EventWrite` |
| api-ms-win-core-debug-l1-1-1.dll | `OutputDebugStringW` |
| api-ms-win-core-libraryloader-l1-1-1.dll | `GetModuleFileNameW` |
| api-ms-win-core-errorhandling-l1-1-1.dll | `GetLastError` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| MSVCR110.dll | `printf`, `_vsnwprintf`, `malloc`, `free`, `memcpy`, `memcpy_s`, `memset`, `__wgetmainargs`, `_initterm`, `_initterm_e`, `_amsg_exit`, `_exit`, `_cexit`, `exit`, … |
| api-ms-win-core-util-l1-1-0.dll | `DecodePointer`, `EncodePointer` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter` |
| api-ms-win-core-sysinfo-l1-2-0.dll | `GetSystemTimeAsFileTime`, `GetTickCount64` |

The CRT functions of MSVCR110.dll (except `printf`, `_vsnwprintf`, `malloc`, `free`, `memcpy`, `memcpy_s`) and the last three DLLs are the standard Visual C++ startup and `/GS` security cookie code.  
Exports: `ServiceMain` (0x4015C8) and `HandlerEx` (0x40184C), besides the entry point.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\\.\DiagRouter` ([qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md)) | `CreateFileW`, `DeviceIoControl`, `ReadFile`, `WriteFile` | Receives the DIAG requests `0x29` from the host and sends the answers, see [DIAG client](#diag-client) |
| `\\.\IPC` / `\\.\QMUX\QmuxDevice` | through [qccium8930.dll](../libraries/qccium8930.md) | QMI transports used to reach the DMS servers of the modem |
| Its own executable | `GetModuleFileNameW` | Binary path given to `CreateServiceW` by `-i` |

No other file, process or COM server is used: there is no `LoadLibrary`, `CreateProcess` or `CoCreateInstance` in the binary.

### Parameters

`wmain` is `sub_403D4C` (0x403D4C). Only `argv[1][0]` and `argv[1][1]` are tested. It always returns 0.

| Command line | Usage | Exit code | Started by |
|---|---|---|---|
| `QcShutdownSvc8930.exe` | No argument: calls `StartServiceCtrlDispatcherW` with the table {`L"QcShutdownSvc"`, `ServiceMain`}, see [Service](#service). Logs `QcShutdownSvc, Service stopped` if the dispatcher fails (process not started by the SCM) | 0 | Service Control Manager |
| `QcShutdownSvc8930.exe -i` | Installs and starts the service (`sub_403A24`, 0x403A24), see [Installation](#installation). Messages written with `printf` | 0 | By hand / setup ? |
| `QcShutdownSvc8930.exe -d` | Deletes the service (`sub_403BDC`, 0x403BDC), see [Installation](#installation). The service must be stopped first (`net stop QcShutdownSvc`) | 0 | By hand ? |
| `QcShutdownSvc8930.exe -<other>` | Nothing done | 0 | |
| `QcShutdownSvc8930.exe <other>` | Prints the usage (`'qcshutdownsvc$(QCPLATFORM) -i' : installs the service`, `-d`, `net start` / `net stop QcShutdownSvc`) | 0 | |

### Installation

`-i` (`sub_403A24`):
1. `GetModuleFileNameW(NULL, path, 260)`.
2. `OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS 0xF003F)`.
3. `CreateServiceW(scm, L"QcShutdownSvc", L"QcShutdownSvc", SERVICE_ALL_ACCESS 0xF01FF, SERVICE_WIN32_OWN_PROCESS 0x10, SERVICE_AUTO_START 2, SERVICE_ERROR_NORMAL 1, path, NULL, NULL, NULL, NULL, NULL)`.
4. `QueryServiceStatusEx(SC_STATUS_PROCESS_INFO)`; if the state isn't `SERVICE_RUNNING`, `StartServiceW(svc, 0, NULL)`.

`-d` (`sub_403BDC`): `OpenSCManagerW(SC_MANAGER_ALL_ACCESS)`, `OpenServiceW(L"QcShutdownSvc", DELETE | SERVICE_QUERY_STATUS 0x10004)`, `QueryServiceStatusEx`; `DeleteService` only if the state is `SERVICE_STOPPED`.

### Service

`ServiceMain` (0x4015C8):
1. Registers the [ETW provider](#etw) (`McGenEventRegister`).
2. `RegisterServiceCtrlHandlerExW(L"Qualcomm Shutdown Service", HandlerEx, NULL)` (not the service name `QcShutdownSvc`).
3. Service status (global `dword_40B2A4`): type `SERVICE_WIN32_OWN_PROCESS` (0x10), controls accepted 0x105 (`STOP | SHUTDOWN | PRESHUTDOWN`), wait hint 300 000 ms. Reports `SERVICE_START_PENDING`.
4. Creates the stop event (manual reset) and the service thread `sub_402DF4` (0x402DF4), then reports `SERVICE_RUNNING`.
5. Waits for the stop event, reports `SERVICE_STOPPED`.

`HandlerEx` (0x40184C):  
| Control | Action |
|---------|--------|
| 1 `SERVICE_CONTROL_STOP` | `sub_401A4C` (StopService) |
| 15 `SERVICE_CONTROL_PRESHUTDOWN` | Reports `SERVICE_STOP_PENDING`, then `sub_401A4C` |
| other (5 `SERVICE_CONTROL_SHUTDOWN` included) | Ignored (`value unhandled`) |

StopService (`sub_401A4C`, 0x401A4C): reports `SERVICE_STOP_PENDING`, sets the DIAG event to wake the service thread (or the stop event directly when the DIAG event doesn't exist), waits 5 s for the thread to set the stop event, otherwise `TerminateThread` and sets it itself.

Service thread (`sub_402DF4`):
1. `sub_4037D0`: resets the state flags and reads [`DiagWaitTimeout`](#registry) (`sub_403864`).
2. Creates an auto-reset event and calls `CM_Register_Notification` with a `CM_NOTIFY_FILTER` of 0x1A0 bytes: `FilterType` = `CM_NOTIFY_FILTER_TYPE_DEVICEINTERFACE` (0), `ClassGuid` = `{5ff73d59-fab7-456e-884e-d5386cd5f581}` (DIAG router interface), callback `sub_401908`. The callback sets the event on `CM_NOTIFY_ACTION_DEVICEINTERFACEARRIVAL` (0) and only logs a removal.
3. Up to 3 tries: `WaitForSingleObject(event, DiagWaitTimeout)` (a timeout is logged but doesn't stop the try), then SetupDiag (`sub_402324`, see [DIAG client](#diag-client)). Gives up if the 3 tries fail.
4. SetupQmi (`sub_401BE8`, see [QMI](#qmi)). Gives up if it fails.
5. MonitorDiag (`sub_402750`): loop on the DIAG requests while the service is `SERVICE_RUNNING`, see [DIAG client](#diag-client).
6. Releases the QMI notifier, closes `\\.\DiagRouter` and the DIAG event (`sub_4026E8`), `CM_Unregister_Notification`, sets the stop event.

### DIAG client

SetupDiag (`sub_402324`) follows the [local client sequence](../drivers/qcdiagrouter8930.md#local-diag-clients) of the router:
1. `CreateFileW(L"\\\\.\\DiagRouter", GENERIC_ALL 0x10000000, FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL)`.
2. Creates an auto-reset event and gives it with [IOCTL 0x80082400](#ioctl-0x80082400) (`IOCTL_DIAGROUTER_CMD_INIT`).
3. Registers the command code `0x29` with [IOCTL 0x80082404](#ioctl-0x80082404) (`IOCTL_DIAGROUTER_CMD_REG`).

MonitorDiag (`sub_402750`) allocates a 4096-byte receive buffer (`DIAG_MAX_RX_PKT_SIZ`) and a 4096-byte answer buffer (`DIAG_MAX_RSP_SIZ`), then for each request:
1. Waits for the event, then `ReadFile(4096)`.
2. Header size: 4 if byte 0 is `0x4B` / `0x80` (subsystem command); if byte 0 is `0x93` (DCI): 12 when byte 8 is `0x4B` / `0x80`, otherwise 9; 1 for any other command.
3. The payload (size − header) must be 2 bytes. Otherwise the request is sent back with [IOCTL 0x8008240C](#ioctl-0x8008240c) (bad length).
4. The command code (byte 0, byte 8 after `0x93`) must be `0x29`. Otherwise the request is sent back with [IOCTL 0x80082410](#ioctl-0x80082410) (bad parameter).
5. The request is copied unchanged to the answer buffer and sent with `WriteFile`: the answer to `0x29` is the request itself, sent **before** the mode change.
6. The 16-bit payload selects the action:

| Payload | DIAG mode | Action |
|---------|-----------|--------|
| 0 | Offline analog | QMI mode 3 (offline) |
| 1 | Offline digital | QMI mode 3 (offline) |
| 2 | Reset | Shutdown with reboot |
| 3 | Factory test mode | QMI mode 2 (factory test) |
| 4 | Online | QMI mode 0 (online) |
| 5 | Low power | QMI mode 1 (low power) |
| 6 | Power off | Shutdown without reboot |
| other | | Nothing (the request was already echoed) |

After a reset or power off whose `InitiateSystemShutdownExW` succeeded, the loop ends.

Request `0x29` (as received by `ReadFile`, plain command):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 29 | `DIAG_CONTROL_F` |
| 01-02 | 00 00 … 06 00 | Mode, see table above |

Shutdown (`sub_4035A0`, 0x4035A0, parameter = reboot): done only once per service run. It contains a `SendModemShutdown` path (QMI mode 5 "shutting down" to the modem), but its enabling flag `dword_40B2DC` is set to 0 by `sub_4037D0` and never set elsewhere: it's dead code. Then SendWindowsShutdown (`sub_403234`, 0x403234):
1. `OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY 0x28)`.
2. `LookupPrivilegeValueW(NULL, L"SeShutdownPrivilege")`, `AdjustTokenPrivileges` with 1 privilege, `SE_PRIVILEGE_ENABLED` (2).
3. `InitiateSystemShutdownExW(NULL, NULL, 0, TRUE /*force apps closed*/, reboot, SHTDN_REASON_FLAG_PLANNED 0x80000000)`.

### QMI

SetupQmi (`sub_401BE8`) uses the DMS IDL service object of the binary (0x409C60): library version 2, IDL version 1, service id 2 (DMS), 31 requests / 31 responses / 1 indication.
1. `qmi_client_notifier_init(service_obj, &os_params, &notifier)`, then `WaitForSingleObject(os_params.event, 5000)` and `ResetEvent`.
2. `qmi_client_get_service_list` once to get the number of DMS servers, `malloc(20 × n)` for the `qmi_service_info` array, a second `qmi_client_notifier_init` (the first notifier isn't released) and a second `qmi_client_get_service_list` to fill the array. A different count is only logged (`Not all instances of DMS service…`).

SetMode (`sub_401F94`, parameter = DMS operating mode), for each DMS server:
1. `qmi_client_init(&info[i], service_obj, nullsub_1, NULL, NULL, &client)` (no indications).
2. Current mode with [QMI_DMS_GET_OPERATING_MODE](#qmi_dms_get_operating_mode-0x002d) (`sub_401EA8`).
3. If the current mode is 2 (factory test) and the requested mode 3 (offline), first [QMI_DMS_SET_OPERATING_MODE](#qmi_dms_set_operating_mode-0x002e) with mode 0 (online).
4. `QMI_DMS_SET_OPERATING_MODE` with the requested mode.
5. `QMI_DMS_GET_OPERATING_MODE` again; the change failed if it isn't the requested mode.
6. `qmi_client_release(client)`.

Returns 1 only if all servers changed mode. The result isn't reported to the host (the request was already echoed).

DMS operating modes used: 0 online, 1 low power, 2 factory test, 3 offline, 5 shutting down (dead code).

#### QMI_DMS_GET_OPERATING_MODE (0x002D)

`qmi_client_send_msg_sync(client, 0x2D, NULL, 0, resp, 12, 2500)`.  
Response (C structure decoded by qccium8930.dll):  
| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 1 | Operating mode (returned by `sub_401EA8`) |
| 0x04 | 4 | Result: ≠0 = failure ? |
| 0x08 | 4 | QMI error code (logged with ETW event 21) |

The fields are read at these offsets by the binary; that the mode comes before the result is unusual for a QMI response structure ?. `sub_401EA8` returns −1 on error.

#### QMI_DMS_SET_OPERATING_MODE (0x002E)

`qmi_client_send_msg_sync(client, 0x2E, req, 1, resp, 8, 2500)`.  
Request:  
| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 1 | Operating mode |

Response:  
| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Result: 0 = success |
| 0x04 | 4 | QMI error code |

### Registry

Key `HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\QcShutdownSvc\` (`ControlSet001` hard-coded), opened with `KEY_READ`:  
| Registry value | value | comment |
|----------------|-------|---------|
| DiagWaitTimeout | 10000 | DWORD. Timeout of each wait for the DIAG router interface, in ms (the debug message says "seconds"). Default 10000 when the value is missing |

### IOCTLs sent

All are sent to `\\.\DiagRouter` ([qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md)).

#### IOCTL 0x80082400

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x900 (2304) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_DIAGROUTER_CMD_INIT | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | HANDLE of an auto-reset event (`CreateEventW(NULL, FALSE, FALSE, NULL)`) |

See [qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md#ioctl-0x80082400).

#### IOCTL 0x80082404

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x901 (2305) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_DIAGROUTER_CMD_REG | 16 | 0 |

Inputbuffer (`DIAGCMD_REG`, `malloc(16)`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 01 00 | Command type 1: plain command code |
| 02-03 | 00 00 | Subsystem id (unused for type 1) |
| 04-05 | 01 00 | 1 range |
| 06-07 | 00 00 | |
| 08-0B | 00 00 00 00 | |
| 0C-0D | 29 00 | First command code |
| 0E-0F | 29 00 | Last command code |

See [qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md#ioctl-0x80082404).

#### IOCTL 0x8008240C

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x903 (2307) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_DIAGROUTER_CMD_ERRRSP_BAD_LEN | size of the request | 0 |

Inputbuffer: the received request, unchanged. Sent when its payload isn't 2 bytes. See [qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md#ioctl-0x8008240c).

#### IOCTL 0x80082410

| Property | Value |
|----------|-------|
| Device | 0x8008 |
| Function | 0x904 (2308) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_DIAGROUTER_CMD_ERRRSP_BAD_PARAM | size of the request | 0 |

Inputbuffer: the received request, unchanged. Sent when the command code isn't `0x29`. See [qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md#ioctl-0x80082410).

### GUIDs

| GUID | Use |
|------|-----|
| `{5ff73d59-fab7-456e-884e-d5386cd5f581}` | Device interface of [qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md), waited for with `CM_Register_Notification` |
| `{213e175e-9bda-483e-9881-069807a93991}` | ETW provider (manifest-based, `McGenEventRegister`) |

### ETW

Provider `{213e175e-9bda-483e-9881-069807a93991}`. The events are written only when enabled (global `dword_40B304`, one bit per event group, updated by the enable callback 0x40108C). Event descriptors (id / level) and use:  
| Id | Level | Data | Use |
|----|-------|------|-----|
| 0 | 2 error | step name | Service setup, thread, exit and DIAG notification failures |
| 1 | 4 info | control code | `HandlerEx` call |
| 2 | 4 info | ? | Service status change (`sub_401B7C`) |
| 3 | 5 verbose | string | Shutdown to subsystems (`SendSubSystemShutdown`) ? |
| 4 | 3 warning | `Key` / `DWORD Value` | Registry read failure |
| 10 | 2 error | step, function, `GetLastError` | DIAG failure (`CreateFile()`, `DeviceIoControl(…)`, `ReadFile()`, `WriteFile()`…) |
| 11 | 3 warning | size, 2 | Invalid DIAG request |
| 12 | 4 info | 41 | DIAG command `0x29` received |
| 13 | 4 info | payload | Mode requested |
| 20 | 2 error | step, function, status | QMI call failure |
| 21 | 2 error | QMI error | Modem rejected a QMI request |
| 22 | 2 error | current, requested mode | Mode change failed |
| 23 | 4 info | ? | Start of a QMI mode change |
| 30 | 2 error | `Modem` / `Windows`, function, error | Shutdown failure |
| 0xFFFF | 5 verbose | string | Trace messages (`QcShutdownSvc::SetupDiag`, `MonitorDiag() Entry!`…) |

Every step is also logged with `OutputDebugStringW` (`QcShutdownSvc, …`).
