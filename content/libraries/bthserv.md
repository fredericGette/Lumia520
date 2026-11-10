## BTHSERV.DLL

The Bluetooth Support Service of Windows Phone 8.1: the `BthServ` service, hosted by `svchost.exe`, which offers the local RPC interface `BthServRPCService` to the user-mode Bluetooth code (device list and cache, SDP records, discoverable/connectable mode, pairing requests).  
`BTHSERV.DLL` is a C DLL (90 112 bytes, 304 functions, the database has its full symbols). It opens the radio of the Microsoft stack (`GUID_BTHPORT_DEVICE_INTERFACE`) and sends it the `BthPort` IOCTLs; it keeps a cache of the remote devices and of their SDP records in memory (red-black trees) and on disk (`bthservsdp.dat`); it forwards the pairing requests of the stack (`GUID_BLUETOOTH_AUTHENTICATION_REQUEST`, `GUID_BLUETOOTH_LE_AUTHENTICATION_REQUEST`) to the clients that registered an event; it counts the clients that want the radio discoverable or connectable; it keeps the Device Association Framework store (offline association endpoints) in sync with the paired devices of the stack; and it removes from the Bluetooth hopping (AFH) the frequencies of the current Wi-Fi channel. Most of its RPC methods take a context handle opened with `BthServOpen`.  
The RPC interface `{2ACB9D68-B434-4B3E-B966-E06B4B3A84CB}` and the endpoint `BthServEp` are also present in `WSHBTH.DLL` (the Winsock helper of Bluetooth, not analysed), its probable client. The same notifications and IOCTLs are used by [BtConnectionManagerService.dll](./btconnectionmanagerservice.md#devices-and-notifications), the other user of the radio handle.

Location on the phone: `C:\Windows\System32\bthserv.dll` ? (the extracted file has no notes).  
Service name: `BthServ` (`RegisterServiceCtrlHandlerExW`); PDB `bthserv.pdb`.  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4 | `RpcServerUseProtseqEpW`, `RpcServerRegisterIfEx`, `RpcServerUnregisterIfEx`, `RpcServerInqDefaultPrincNameW`, `RpcServerRegisterAuthInfoW`, `RpcStringFreeW`, `RpcBindingInqAuthClientW`, `RpcImpersonateClient`, `RpcRevertToSelf`, `NdrServerCall2`, `RpcRaiseException` |
| api-ms-win-core-io-l1-1-1, api-ms-win-core-file-l1-2-1 | `DeviceIoControl`, `GetOverlappedResult`, `CancelIoEx`, `CreateFileW`, `CreateDirectoryW`, `ReadFile`, `WriteFile` |
| api-ms-win-devices-config-l1-1-1 | `CM_Register_Notification`, `CM_Unregister_Notification` |
| api-ms-win-devices-query-l1-1-1 | `DevCreateObjectQuery`, `DevCloseObjectQuery` |
| DEVOBJ | `DevObjCreateDeviceInfoList`, `DevObjGetClassDevs`, `DevObjEnumDeviceInterfaces`, `DevObjGetDeviceInterfaceDetail`, `DevObjDestroyDeviceInfoList` |
| ext-ms-win-bluetooth-deviceassociation-l1-1-0 (delay-load) | `DafCreateAssociationContext`, `DafCreateAssociationContextFromOobBlob`, `DafCloseAssociationContext`, `DafStartRemoveAssociation`, `DafStartEnumCeremonies`, `DafSelectCeremony`, `DafStartFinalize`, `DafMemFree` |
| wlanapi (delay-load) | `WlanOpenHandle`, `WlanCloseHandle`, `WlanEnumInterfaces`, `WlanQueryInterface`, `WlanRegisterNotification`, `WlanFreeMemory` |
| api-ms-win-core-com-l1-1-1, OLEAUT32 | `CoInitializeEx`, `CoInitializeSecurity`, `CoCreateInstance`, `CoUninitialize`, `SysAllocString`, `SysFreeString`, `VariantInit`, `VariantClear` |
| api-ms-win-service-core-l1-1-1, api-ms-win-service-management-l1-1-0, -l2-1-0 | `RegisterServiceCtrlHandlerExW`, `SetServiceStatus`, `OpenSCManagerW`, `OpenServiceW`, `CloseServiceHandle`, `QueryServiceStatusEx`, `NotifyServiceStatusChangeW` |
| profapi | `GetBasicProfileFolderPath` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegCloseKey` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `CreateEventExW`, `SetEvent`, `ResetEvent`, `CreateMutexW`, `ReleaseMutex`, `WaitForSingleObject`, `WaitForSingleObjectEx`, `WaitForMultipleObjectsEx`, `CreateWaitableTimerExW`, `SetWaitableTimer`, `CancelWaitableTimer`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2, api-ms-win-core-handle-l1-1-0 | `OpenProcess`, `GetCurrentProcess`, `CreateThread`, `TerminateProcess`, `DuplicateHandle`, `CloseHandle` |
| api-ms-win-core-sysinfo-l1-2-2, api-ms-win-core-timezone-l1-1-0 | `GetSystemTime`, `GetSystemTimeAsFileTime`, `SystemTimeToFileTime` |
| api-ms-win-core-heap-l1-2-0, -heap-obsolete-l1-1-0, -string-l1-1-0 | `GetProcessHeap`, `HeapAlloc`, `HeapFree`, `LocalAlloc`, `LocalFree`, `MultiByteToWideChar` |
| api-ms-win-core-apiquery-l1-1-0, -delayload-l1-1-1 | `ApiSetQueryApiSetPresence`, `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| ntdll | `EtwRegisterTraceGuidsW`, `EtwUnregisterTraceGuids`, `EtwTraceMessage`, `EtwGetTraceLoggerHandle`, `EtwGetTraceEnableLevel`, `EtwGetTraceEnableFlags`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt, api-ms-win-core-errorhandling-l1-1-2 | C runtime (`malloc`, `free`, `memcpy`, `memset`, `swscanf`, `_vsnwprintf`, `_initterm`, `_CxxThrowException`, …), `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |

The msvcrt, `Rtl*` unwind, `TerminateProcess`, `GetCurrentProcess` (partly) and exception filter imports are the CRT startup and `/GS` code. The `Etw*` imports are the WPP tracing ([ETW](#etw)). The two delay-load modules are resolved by `__delayLoadHelper2`; the device association one is first tested with `ApiSetQueryApiSetPresence` (`IsDafCreateAssociationContextPresent`, 0x10004E88).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `wlanapi.dll` | Delay-load | Current Wi-Fi channel ([Wi-Fi coexistence](#wi-fi-coexistence)) |
| `ext-ms-win-bluetooth-deviceassociation-l1-1-0.dll` (API set, host not known) | Delay-load, presence tested first | Association endpoints of the paired devices ([Device association store](#device-association-store)) |
| Radio of the Bluetooth stack (`BthPort`, interface `GUID_BTHPORT_DEVICE_INTERFACE`) | `CreateFileW` (path from `DevCreateObjectQuery` / CM notification, or `DevObj*` for the overlapped handle), `DeviceIoControl` | All the [IOCTLs](#ioctls), notifications |
| `<profile folder 6>\Microsoft\Windows\Bluetooth\bthservsdp.dat` | `GetBasicProfileFolderPath(6)`, `CreateDirectoryW` of each level, `CreateFileW` / `ReadFile` / `WriteFile` | Device and SDP cache ([Device database](#device-database)) |
| Task `Microsoft\Windows\Bluetooth\UninstallDeviceTask` | `CoCreateInstance(CLSID_TaskScheduler {0F87369F-A4E5-4CFC-BD3E-73E6154572DD}, IID_ITaskService {2FABA4C7-4DA9-4013-9697-20CC3FD40F85})`, `IRegisteredTask::Run` | Uninstalls a device ([BthServUninstallDevice](#bthservuninstalldevice)); the program of the task isn't known |
| `wlansvc` service | `OpenServiceW`, `QueryServiceStatusEx`, `NotifyServiceStatusChangeW` | Opens the WLAN API when the service runs |

No process is started directly.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `ServiceMain` | 0x10002B68 | `DWORD argc, LPWSTR *argv` |

There is no `SvchostPushServiceGlobals`: the svchost group isn't in the binary.

### Startup

`_DllMainCRTStartup` (0x100049B0): CRT. `DllMain` (0x10009C6C) only starts (`WppInitUm`, control GUID `BthServTraceGuid`) and stops (`WppCleanupUm`) the WPP tracing.

`ServiceMain` (0x10002B68):
1. `InitializeGlobals` (0x10004198): the stop event (`Globals`, manual reset), the two client trees ([authentication clients](#pairing-requests), [devices](#device-database)), the discovery mutex, and from `HKLM\SYSTEM\CurrentControlSet\Services\BthServ\Parameters`: `CacheTimeout` (seconds, default 86 400) and `ChannelAvoidanceRange` (`REG_DWORD`, ignored if above 59, default 0).
2. `BthServRegister` (0x10004134): `RegisterServiceCtrlHandlerExW(L"BthServ", ServiceHandlerEx)`, `SERVICE_WIN32_SHARE_PROCESS` (0x20), accepts stop and shutdown (5); `SERVICE_START_PENDING`.
3. `BthServInit` (0x1000335C): `BthServReadDb`, removes the expired devices (`BthServExpireDbNode` on the tree, the age is compared with `CacheTimeout`), `BthServUpdateDeviceInfo`, then `BthServStartRPC` ([RPC](#rpc)).
4. `BthServEnumerateRadios` (0x10003264): `DevCreateObjectQuery` of the device interfaces with `DEVPKEY_DeviceInterface_ClassGuid` = `GUID_BTHPORT_DEVICE_INTERFACE` and `DEVPKEY_DeviceInterface_Enabled` = TRUE; the callback `BthServInterfaceEnumCallback` (0x10003454) opens the first radio ([Radio](#radio)) and sets an event at the end of the enumeration.
5. `BthServRegisterInterfaceNotifications` (0x100031E4): `CM_Register_Notification` (interface class `GUID_BTHPORT_DEVICE_INTERFACE`) → `BthServProcessDeviceChange`.
6. `SERVICE_RUNNING`, `DafBthSynchronize` ([Device association store](#device-association-store)), then waits for the stop event and calls `BthServExit` (0x1000D628).

`ServiceHandlerEx` (0x10009E5C): stop (1) and shutdown (5) set `SERVICE_STOP_PENDING` and the stop event; interrogate (4) reports the status; other codes answer `ERROR_CALL_NOT_IMPLEMENTED` (120). `BthServStop` (0x1000D4D0): `RpcServerUnregisterIfEx`, closes the radio, writes the database, frees the client lists and the discovery state, `SERVICE_STOPPED`.

### Radio

`BthServOpenLocalRadio(path)` (0x10003D98):
1. `CreateFileW(path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, OPEN_EXISTING)`; the handle is kept in `dword_10010298`.
2. `CM_Register_Notification` with a filter of type `CM_NOTIFY_FILTER_TYPE_DEVICEHANDLE` (1) on this handle → `BthServProcessDeviceChange`.
3. `BthServListenForAsyncEvents` (0x10003F48): creates the stop event of the thread and starts `BthServAsyncEventsThread` (below), waiting for it to be ready.
4. `BthServBluetoothControlPanelTasksSetState(1)` (0x10003E84): `State` = 1 in `HKLM\SYSTEM\CurrentControlSet\Services\BthServ\Parameters\BluetoothControlPanelTasks` (0 when the radio is closed).

After it, `BthServUpdateDeviceInfo` and `BthServRestoreTemporaryScanState` (0x10003530: makes the radio discoverable or connectable again if some client still asks for it). The radio arrival from the CM notification (`BthServLocalRadioInsertion`, 0x1000C500) does the same and calls `DafBthSynchronize`.

`BthServProcessDeviceChange` (0x1000D678), by `CM_NOTIFY_ACTION`:

| Action | Filter type | Handling |
|--------|-------------|----------|
| 0 `DEVICEINTERFACEARRIVAL` | 0 (interface class) | `BthServLocalRadioInsertion(symbolic link, 1)` |
| 1 `DEVICEINTERFACEREMOVAL` | 0 | `BthServLocalRadioRemoval`: closes the radio and writes the database |
| 2 `DEVICEQUERYREMOVE` | 1 (handle) | `BthServCloseDevice`: closes the radio handle |
| 3 `DEVICEQUERYREMOVEFAILED` | 1 | `BthServLocalRadioQueryRemovedFailed`: reopens the radio |
| 4 `DEVICEREMOVEPENDING` | | Nothing |
| 6 `DEVICECUSTOMEVENT` | 1 | By event GUID, the data at +0x20 of the event data (below) |

| Custom event | Handler |
|--------------|---------|
| `GUID_BLUETOOTH_L2CAP_EVENT` `{7EAE4030-B709-4AA8-AC55-E953829C9DAA}` | `BthServHandleL2capEvent`: last used time of the device ([Device database](#device-database)) |
| `GUID_BLUETOOTH_HCI_EVENT` `{FC240062-1541-49BE-B463-84C4DCD7BF7F}` | `BthServHandleHciEvent`: last seen / used time |
| `GUID_BLUETOOTH_RADIO_IN_RANGE` `{EA3B5B82-26EE-450E-B0D8-D26FE30A3869}` | `BthServUpdateDevInfo` |
| `GUID_BLUETOOTH_RADIO_OUT_OF_RANGE` `{E28867C9-C2AA-4CED-B969-4570866037C4}` | `BthServRemoveInfoEntry` |
| `GUID_BLUETOOTH_AUTHENTICATION_REQUEST` `{5DC9136D-996C-46DB-84F5-32C0A3F47352}` | `BthServHandleBRAuthenticationRequestEvent` ([Pairing requests](#pairing-requests)) |
| `GUID_BLUETOOTH_LE_AUTHENTICATION_REQUEST` `{97F4D9A8-9C77-485F-9A21-F7BBE709CAE3}` | `BthServHandleLEAuthenticationRequestEvent` |
| `GUID_BLUETOOTH_MUST_SYNCHRONIZE_STORE` `{69F95E75-EB00-485B-9E61-34A330BAFBF2}` | `DafBthSynchronize` |

`BthServAsyncEventsThread` (0x10003754, `/GS`):
1. `CreateWaitableTimerExW` and `SetWaitableTimer` with a relative due time and a period of `CacheTimeout` seconds, and the APC `BthServExpireRecords` (0x1000C018: frees the expired devices and SDP records).
2. Expires the database once, `BthServUpdateDeviceInfo`, `BthServStartAutoConfigServiceMonitor` ([Wi-Fi coexistence](#wi-fi-coexistence)), sets the "ready" event.
3. Waits (alertable) for its stop event, then cancels the timer, stops the Wi-Fi monitor, `CancelIoEx` on the radio and `CM_Unregister_Notification`.

### RPC

`BthServStartRPC` (0x10004040): `RpcServerUseProtseqEpW(L"ncalrpc", 3, L"BthServEp", …)` (`RPC_S_DUPLICATE_ENDPOINT` accepted), `RpcServerRegisterIfEx(BthServRPCService, flags RPC_IF_AUTOLISTEN, 1234 calls, no callback)`, `RpcServerInqDefaultPrincNameW(RPC_C_AUTHN_WINNT)` and `RpcServerRegisterAuthInfoW(name, RPC_C_AUTHN_WINNT)`.  
Each method first calls `BthServRpcAuthenticate` (0x10009860) or does the same check: `RpcBindingInqAuthClientW` must give an authentication level of at least 6 (`RPC_C_AUTHN_LEVEL_PKT_PRIVACY`), otherwise `RpcRaiseException(ERROR_ACCESS_DENIED)`; a NULL context handle raises `ERROR_INVALID_PARAMETER`. The methods return 0 and give their status in the second parameter (`[out] long *`), as an `HRESULT` (Win32 codes become `0x8007xxxx`). The context handle rundown `PCONTEXT_HANDLE_TYPE_rundown` (0x1000CC08) calls `BthServDoClose`.

Interface `{2ACB9D68-B434-4B3E-B966-E06B4B3A84CB}` version 1.0, 22 procedures (NDR `-Oif`, the parameters below are the stack offsets of the format string and the manager routines).

| Opnum | Routine | Parameters (after `handle_t` or the context handle) | Use |
|-------|---------|------------------------------------------------------|-----|
| 0 | `BthServOpen` (0x10002A80) | `[out] context`, `[out] status`, `[in]` struct of 2 DWORDs: client process id, ? | Creates the [client context](#client-context); `OpenProcess(PROCESS_DUP_HANDLE)` of the process id while impersonating the client |
| 1 | `BthServClose` (0x100023EC) | `[in, out] context`, `[out] status` | Releases the discovery / connectable requests, the authentication registrations and the SDP records (`IOCTL_BTH_SDP_REMOVE_RECORD`) of the client |
| 2 | `BthServRegisterAuthenticationEvent` (0x100027F0) | `[out] status`, `[in] BTH_ADDR *`, `[in] hyper` event handle in the client process, `[in] long` ?, `[in] long` flags | [Pairing requests](#pairing-requests): `BthServAddAuthenticationClient` |
| 3 | `BthServDeregisterAuthenticationEvent` (0x1000B650) | `[out] status`, `[in] BTH_ADDR *`, `[in] hyper` event handle | `BthServRemoveAuthenticationClientByEventHandle` |
| 4 | `BthServGetAuthRequest` (0x1000B594) | `[out] status`, `[out] BTHSERV_AUTHENTICATION_REQUEST *` | Next queued request of the client; `ERROR_NOT_FOUND` (1168) if none |
| 5 | `BthServGetDeviceInfo` (0x1000CF7C) | `[out] status`, `[in]` source (enum), `[in] BTH_ADDR *`, `[in, out] BLUETOOTH_DEVICE_INFO *` | Device from the cache or the stack (`BthServClientGetDeviceInfo`, 0x1000C2C8) |
| 6 | `BthServSetDeviceName` (0x1000B278) | `[out] status`, `[in] BTH_ADDR *`, `[in, string] wchar_t *` | Local name of a device in the cache (up to 248 characters) |
| 7 | `BthServGetDeviceList` (0x1000CEFC) | `[out] status`, `[in] long` inquiry, `[in] byte`, `[in] long` size, `[out, size_is] BLUETOOTH_DEVICE_INFO[]`, `[out] long *` size | [Device list](#device-list) |
| 8 | `BthServActivateService` (0x1000D498) | `[out] status`, `[in] BTH_ADDR *`, `[in] long` size, `[in, size_is] byte[]` SDP record | Stores a remote service record in `CachedServices` ([below](#activateservice)) |
| 9 | `BthServUpdateService` (0x1000A40C) | `[out] status`, `[in] long` size, `[in, size_is] byte[]`, `[in] long` wait | `IOCTL_BTH_UPDATE_DEVICE` (0x411030) with the buffer (at least 0x524 bytes); if the last parameter is non-zero, `Sleep(3000)` after it |
| 10 | `BthServGetSdpRecord` (0x1000D5C4) | `[out] status`, `[in] BTH_ADDR *`, `[in]` kind (enum: 0 L2CAP, 1 PnP), `[in]` source (enum), `[in] long` size, `[out, size_is] byte[]`, `[out] long *` size | [SDP cache](#sdp-cache) |
| 11 | `BthServSetSdpRecord` (0x1000B70C) | `[out] status`, `[in] long` size, `[in, size_is] byte[]`, `[out] hyper *` handle | `IOCTL_BTH_SDP_SUBMIT_RECORD` (0x410214); the record is remembered in the context, the handle is a counter of the service |
| 12 | `BthServSetSdpRecordWithInfo` (0x1000B678) | `[out] status`, `[in] long` ×3 (the first three DWORDs of the 16-byte header, the fourth is the size), `[in] long` size, `[in, size_is] byte[]`, `[out] hyper *` handle | Builds a `BTH_SET_SERVICE` (16-byte header + record) and sends `IOCTL_BTH_SDP_SUBMIT_RECORD_WITH_INFO` (0x41021C) |
| 13 | `BthServRemoveSdpRecord` (0x1000B5C8) | `[out] status`, `[in] hyper` handle | `IOCTL_BTH_SDP_REMOVE_RECORD` (0x410218) of a record of this client |
| 14 | `BthServEnableDiscovery` (0x1000A268) | `[out] status`, `[in] long` enable | [Discoverable and connectable](#discoverable-and-connectable) |
| 15 | `BthServEnableIncomingConnections` (0x1000A234) | `[out] status`, `[in] long` enable | Same, connectable |
| 16 | `BthServUninstallDevice` (0x1000CED8) | `[out] status`, `[in, string] wchar_t *` device | [BthServUninstallDevice](#bthservuninstalldevice) |
| 17 | `BthServEirGetRecords` (0x1000A3B0) | `[out] status`, … | Not implemented: `HRESULT_FROM_WIN32(ERROR_CALL_NOT_IMPLEMENTED)` (0x80070078) |
| 18 | `BthServEirSetRecord` (0x1000A354) | `[out] status`, … | Not implemented |
| 19 | `BthServEirUpdateRecord` (0x1000A2F8) | `[out] status`, … | Not implemented |
| 20 | `BthServEirRemoveRecord` (0x1000A29C) | `[out] status`, `[in] hyper` | Not implemented |
| 21 | `BthServTestRegisterAuthenticationEvent` (0x1000504C) | as opnum 3 | Returns 0, does nothing |

The two MIDL enums are named `__MIDL_BthServRPCService_0002` (record kind: 0 L2CAP, 1 PnP) and `__MIDL_BthServRPCService_0003` (source; the trace strings give `FromCache`, `FromDevice`, `FromCacheOrDevice`, `FromDeviceOrCache`, `Unknown`, in this order: 0…3 ?).

### Client context

Allocated by `BthServOpen` (60 bytes, `HeapAlloc`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Process id of the client (first DWORD of the input structure) |
| 0x04 | 4 | Second DWORD of the input structure (?) |
| 0x08 | 4 | Handle of the client process (`PROCESS_DUP_HANDLE`), used to duplicate its events |
| 0x0C | 8 | List of the authentication registrations of the client |
| 0x14 | 8 | Queue of the pairing requests waiting for `BthServGetAuthRequest` |
| 0x1C | 4 | Number of queued requests |
| 0x20 | 8 | List of the SDP records published by the client (handle at +0x10 of each 24-byte entry) |
| 0x28 | 8 | List (?) |
| 0x30 | 4 | Valid (1; 0 when closing) |
| 0x34 | 4 | Discoverable requests of the client |
| 0x38 | 4 | Connectable requests of the client |

### Pairing requests

A client registers an event of its own process for a device address (0 = all the devices), with a flags DWORD where 0x4000 means BR/EDR and 0x8000 LE (`BthServAuthenticationClientCompare`, 0x10002764, sorts on the address, then the second DWORD, then these bits). `BthServAddAuthenticationClient` (0x10002858) duplicates the event (`DuplicateHandle` from the client process, `DUPLICATE_SAME_ACCESS`) and adds it to the tree `dword_100102DC` (one node per key, 24 bytes; one 40-byte entry per client and event); a second registration of the same client fails.

When the stack sends `GUID_BLUETOOTH_AUTHENTICATION_REQUEST` (or the LE one), the handler clears bit 0x8000 of the first DWORD of the request, copies it (560 bytes for BR/EDR, 548 for LE) into a 576-byte queue entry (+0x00: 0 BR/EDR, 1 LE; +0x08: the request) and calls `BthServNotifyAuthenticationClients` (0x1000B74C): it looks for the registrations of the device address (for BR/EDR, also of a second address of the request when its DWORD at +0x220 is 1 ?), else for the address 0 with the bit 0x4000 / 0x8000, and `BthServWalkAuthenticationClientList` (0x1000AEF0) queues a copy for each client and sets its event.

`BthServGetAuthRequestForClient` (0x1000A6B4) takes the first queued entry: copies 272 bytes of the request, ORs 0x4000 (BR/EDR) or 0x8000 (LE) into its first DWORD, and copies three DWORDs of the request to +0x110…+0x118 of the output (and a fourth to +0x11C when the one at +0x110 is 3 or 4: the authentication method and the numeric value ?). The answer to the stack isn't sent by this DLL (the client sends `IOCTL_BTH_AUTH_RESPONSE` itself, as [BtConnectionManagerService.dll](./btconnectionmanagerservice.md) does ?).

### Discoverable and connectable

`BthServEnableDiscoveryForClient` (0x1000943C) and `BthServEnableIncomingConnectionsForClient` (0x10009340) keep a count per client (context +0x34 / +0x38) and a global count (`dword_10010334` / `dword_10010338`), under the mutex `dword_10010330`. The radio is changed only when the global count goes from 0 to 1 or from 1 to 0, with `IOCTL_BTH_SCAN_ENABLE` (0x411020, 4 bytes, no output):

| Function | Byte 0 | Byte 1 | Byte 2 |
|----------|--------|--------|--------|
| `BthServSetConnectable` (0x10007AE4) | 2 | connectable | 0 |
| `BthServSetDiscoverable` (0x10007B58) | 3 | discoverable | discoverable (also connectable) |

Disabling a mode that the client hasn't enabled answers `ERROR_INVALID_PARAMETER`.

### Device list

`BthServClientGetDeviceList(inquiry, byte, size, buffer, &size)` (0x1000C120):
1. If `inquiry` is non-zero (the byte must be non-zero, else `ERROR_BAD_ARGUMENTS`), starts an inquiry: `IOCTL_BTH_INQUIRY_DEVICE` (0x411000) with 6 bytes: the DWORD 0x009E8B33 (LAP of the general inquiry), then a WORD 0.
2. `BthServUpdateDeviceInfo` (0x100038F0, `/GS`): reads the devices of the stack with `IOCTL_BTH_GET_DEVICE_INFO_EX` (0x411058; a first call for the count, `ERROR_MORE_DATA`, entries of 0x218 bytes) and adds or updates them in the cache (address, flags, class, name converted from UTF-8 with `BthServConvertNameToWChar`).
3. Copies the cached devices as `BLUETOOTH_DEVICE_INFO` (560 bytes each, `BthServFillDevInfo`); if the buffer is too small, answers `ERROR_INSUFFICIENT_BUFFER` (122) with the size needed.

### Device database

The cache is a red-black tree (`dword_100102F8`, compare `BthServDbClientCompare` on the address) of 1088-byte entries (`_BTHSERV_DBCLIENT_ENTRY`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 8 | Bluetooth address |
| 0x008 | 4 | Cached L2CAP SDP response (`BTH_SDP_STREAM_RESPONSE *`) |
| 0x00C | 4 | Cached PnP SDP response |
| 0x010 | 0x128 | Device information (flags at +0x10; the bits 0x08 and 0x10 keep the entry from expiring, 0x20 and 0x08 aren't saved) |
| 0x138 | 0xF0 | ? |
| 0x228 | 0x1F0 | Name, 248 `WCHAR`s |
| 0x418 | 0x10 | `SYSTEMTIME` last seen |
| 0x428 | 0x10 | `SYSTEMTIME` last used / connected |
| 0x438 | 8 | Link of the expiry list |

`BthServReadDb` (0x100035D8) and `BthServWriteDb` (0x1000B45C) use the file returned by `BthServGetStaticStoreName` (0x10003B0C): `GetBasicProfileFolderPath(6)` + `\Microsoft\Windows\Bluetooth\bthservsdp.dat` (the folders are created if needed). The file is a sequence of records (`_BTHSERV_DBCLIENT_DISK_ENTRY_V2`, `BthServReadDbNodeV2` 0x10003A98, `BthServWriteDbNode` 0x1000A09C):

| Offset | Size | Comment |
|--------|------|---------|
| 0x000 | 4 | 0x42445342 (`BSDB`) |
| 0x004 | 4 | Size of the record: 0x441 when there is no SDP data, else 0x440 + data |
| 0x008 | 8 | Address |
| 0x010 | 0x128 | Device information (entry +0x010) |
| 0x138 | 0x1F0 | Name (entry +0x228) |
| 0x328 | 0xF0 | Entry +0x138 |
| 0x418 | 0x20 | Last seen, last used |
| 0x438 | 4 | Size of the L2CAP SDP response (`responseSize` + 9, 0 if none) |
| 0x43C | 4 | Size of the PnP SDP response |
| 0x440 | n | The two responses |

A wrong magic or size stops the reading (`ERROR_INVALID_DATA`, 13, or 1117). The database is written when the radio goes away and when the service stops. `BthServExpireDbNode` (0x1000ADB0) drops an entry whose last seen time is older than `CacheTimeout` and whose flags have neither 0x08 nor 0x10: an entry with a name only loses its SDP data and device information, the others are deleted.

### SDP cache

`BthServGetSdpRecord` calls `BthServClientGetSdpL2cap` (0x1000CFF4) or `BthServClientGetSdpPnp` (0x1000D0D0); any other kind answers `ERROR_BAD_ARGUMENTS`. They use `BthServGetL2CapSdpRecords` (0x1000C6C0) / `BthServGetPnpSdpRecords` (0x1000C968):
1. Depending on the source, copy the cached response of the device (`ERROR_INSUFFICIENT_BUFFER` with the size needed if the buffer is too small).
2. Otherwise `BthServConnectSdp`: `IOCTL_BTH_SDP_CONNECT` (0x410200, 21 bytes: address, then the SDP connection handle out).
3. `BthServGetSdpRecords` (0x10009D70): `IOCTL_BTH_SDP_SERVICE_ATTRIBUTE_SEARCH` (0x410210) with one UUID16 (type 0x130) — 0x0100 (L2CAP) or 0x1200 (PnP Information) — and the attribute range 0…0xFFFF; the output starts at 4 KB and is grown to `requiredSize + 9` until `responseSize == requiredSize`. The L2CAP function also asks the PnP records.
4. `BthServPutSdpRecordInCache` (0x1000B3BC) replaces the cached response, `IOCTL_BTH_SDP_DISCONNECT` (0x410204).

### ActivateService

`BthServClientActivateService(address, size, record)` (0x1000D1AC) checks the record (`SdpValidateStream`, `SdpIsStreamRecord`, `SdpVerifyServiceRecord`: protocol descriptor lists, profile descriptors, language ids), creates `HKLM\System\CurrentControlSet\Services\BTHPORT\Parameters\Devices\%04x%08x\CachedServices` (address as NAP, then SAP) and writes the record as a binary value named `%08x` from the service record handle (attribute 0x0000, byte swapped). An invalid record answers `ERROR_INVALID_PARAMETER`.

### BthServUninstallDevice

`BthServClientUninstallDevice(device)` (0x1000BAC8, `/GS`):
1. Copies the device string (up to 61 characters) and creates the manual-reset event `Global\BTH_UNINSTALL_DEVICE_<device>`.
2. `CoInitializeEx`, `CoInitializeSecurity` (authentication level 6, impersonation 3), `CoCreateInstance(CLSID_TaskScheduler, IID_ITaskService)`, `ITaskService::Connect` with empty variants, `GetFolder("\")`, `GetTask("Microsoft\Windows\Bluetooth\UninstallDeviceTask")`.
3. `IRegisteredTask::Run` with a `VT_BSTR` variant holding the device string, then waits up to 15 s (0x3A98 ms) for the event, which the task is expected to set when the device is removed.

### Device association store

`DafBthSynchronize` (0x10002C3C, `/GS`), at start, at each radio arrival and on `GUID_BLUETOOTH_MUST_SYNCHRONIZE_STORE`, when the API set `ext-ms-win-bluetooth-deviceassociation-l1-1-0` is present:
1. Opens its own overlapped radio handle (`DafBthOpenOverlappedRadioHandle`, 0x100030AC: `DevObjGetClassDevs` / `DevObjEnumDeviceInterfaces` of `GUID_BTHPORT_DEVICE_INTERFACE`, `CreateFileW`), reads the local radio (`DafBthGetLocalDeviceInfo`, 0x10002FD8: `IOCTL_BTH_GET_LOCAL_INFO` 0x410000, 292 bytes).
2. `DevCreateObjectQuery` of the association endpoints with `DEVPKEY_Aep_IsAssociated` = TRUE and `DEVPKEY_Aep_ProtocolId` = `DAF_ProtocolId_Bluetooth` or `DAF_ProtocolId_BluetoothLE` (callback `DafBthSyncAepQueryCallback`, 10 s wait), and the paired devices of the stack (`DafBthGetDeviceInfoList`, 0x10002F18: `IOCTL_BTH_GET_DEVICE_INFO_EX`).
3. An endpoint whose device isn't paired any more is removed (`DafBthSyncRemoveAep`, 0x10009B3C: `DafCreateAssociationContext(aep id)`, `DafStartRemoveAssociation`, wait for the completion callback).
4. A paired device without endpoint gets an offline one (`DafBthSyncCreateOfflineAep`, 0x10009968: `DafCreateAssociationContextFromOobBlob` with the `BTH_DEVICE_INFO_V3`, `DafStartEnumCeremonies`, `DafSelectCeremony`, `DafStartFinalize`), with the BR/EDR protocol if its flags have 0x4000, the LE one if 0x8000.

### Wi-Fi coexistence

`BthServStartAutoConfigServiceMonitor` (0x10003A4C) allocates the state (`dword_10010344`) and calls `MonitorAutoConfigService` (0x1000D36C): `OpenServiceW("wlansvc", SERVICE_QUERY_STATUS)`, `QueryServiceStatusEx`, then `AutoConfigServiceStatusChangeCallback` (0x1000CDA4), which opens the WLAN API (`OpenWlanApi`: `WlanOpenHandle`, `WlanEnumInterfaces`, `WlanRegisterNotification` → `AutoConfigNotificationCallback`) when the service is running and closes it when it stops, and re-arms `NotifyServiceStatusChangeW` (running / stopped).

`AutoConfigNotificationCallback` (0x1000AFC4) updates the current channel on the ACM notifications 10 (connection complete), 13/14 (interface arrival / removal: re-enumerates the interfaces; only one interface is followed), 21 (disconnected: channel 0) and MSM notification 6 (roaming end) (`QueryCurrent80211Channel`, 0x10009268: `WlanQueryInterface(wlan_intf_opcode_channel_number)`, values above 100 ignored), then `ProcessNotification` (0x10009F78): if the channel changed, it builds a 10-byte AFH channel map with all bits set except bit 79, clears the Bluetooth channels from `2412 + 5 × (channel − 1)` MHz minus/plus half of `ChannelAvoidanceRange` (`ComputeAfhChannelMap`, 0x10008D44, limited to 2402…2480 MHz), and sends it with `IOCTL` 0x4110C0 (10 bytes, name not known: host channel classification ?). With `ChannelAvoidanceRange` = 0 (default) only the center frequency is removed.

### IOCTLs

All are sent to the radio of the Microsoft stack (`BthPort`, not analysed); names as in [BtConnectionManagerService.dll](./btconnectionmanagerservice.md#devices-and-notifications) and the public `bthioctl.h`.

| IOCTL | Name | Sent by |
|-------|------|---------|
| 0x410000 | `IOCTL_BTH_GET_LOCAL_INFO` | `DafBthGetLocalDeviceInfo` |
| 0x410200 | `IOCTL_BTH_SDP_CONNECT` | `BthServConnectSdp` |
| 0x410204 | `IOCTL_BTH_SDP_DISCONNECT` | `BthServDisconnectSdp` |
| 0x410210 | `IOCTL_BTH_SDP_SERVICE_ATTRIBUTE_SEARCH` | `BthServGetSdpRecords` |
| 0x410214 | `IOCTL_BTH_SDP_SUBMIT_RECORD` | `BthServClientSetSdpRecord` |
| 0x410218 | `IOCTL_BTH_SDP_REMOVE_RECORD` | `BthServClientRemoveSdpRecord`, `BthServRemoveSdpRecords`, `BthServClose` |
| 0x41021C | `IOCTL_BTH_SDP_SUBMIT_RECORD_WITH_INFO` | `BthServClientSetSdpRecord` |
| 0x411000 | `IOCTL_BTH_INQUIRY_DEVICE` | `BthServClientGetDeviceList` |
| 0x411020 | `IOCTL_BTH_SCAN_ENABLE` | `BthServSetConnectable`, `BthServSetDiscoverable` |
| 0x411030 | `IOCTL_BTH_UPDATE_DEVICE` | `BthServClientUpdateService` |
| 0x411058 | `IOCTL_BTH_GET_DEVICE_INFO_EX` | `BthServUpdateDeviceInfo`, `DafBthGetDeviceInfoList`, `DafBthGetDeviceInfo` |
| 0x4110C0 | ? (AFH channel map) | `ProcessNotification` |

`BthServOverlappedIoctl` (0x10007E8C) sends them with an `OVERLAPPED` and an event and waits for `GetOverlappedResult`.

### Registry

| Key | Values |
|-----|--------|
| `HKLM\SYSTEM\CurrentControlSet\Services\BthServ\Parameters` | `CacheTimeout` (seconds, default 86 400), `ChannelAvoidanceRange` (MHz, 0…59, default 0) |
| `HKLM\SYSTEM\CurrentControlSet\Services\BthServ\Parameters\BluetoothControlPanelTasks` | `State` (`REG_DWORD`): 1 while the radio is open, 0 otherwise |
| `HKLM\System\CurrentControlSet\Services\BTHPORT\Parameters\Devices\%04x%08x\CachedServices` | One binary value per remote service record, named by its handle (`%08x`) |

### Named objects

`Global\BTH_UNINSTALL_DEVICE_<device>` (event, [BthServUninstallDevice](#bthservuninstalldevice)).

### ETW

WPP tracing only: control GUID `BthServTraceGuid` `{CA95AC21-E6FD-4A1B-81BE-ACF16FCFC0FC}`, registered by `WppInitUm` (0x100043F8, `EtwRegisterTraceGuidsW`) in `DllMain`; the messages go through `EtwTraceMessage` (functions `WPP_SF_*`) with the level tested before each one.
