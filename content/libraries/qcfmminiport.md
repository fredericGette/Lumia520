## qcfmminiport.dll

The Qualcomm FM radio receiver miniport of the MSM8930 (WCN3660 FM core), build `P:\fm\rel\8.2.1.1\arm\Release\qcfmminiport.pdb`.  
It's a small COM-style DLL (72 704 bytes, 115 functions) with one export, `CreateAdapterDriver`, that returns an *adapter driver* object; the adapter creates the *miniport tuner device* (`MiniportFmRxDevice`) that the FM radio stack of the phone drives (power, region, tune, seek, RDS, properties). Below it there is the "QFM" layer: it builds the FM HCI-like commands (opcode + parameter length + parameters), sends them as plain packets to [qcfmtransport8930.sys](../drivers/qcfmtransport8930.md) (`\\.\qcfmtransportdriver`), which forwards them on the SMD channel `APPS_FM` to the FM core of the WCNSS, and parses the events that come back. It reads the search tuning and the calibration data in the registry, and it watches the data calls of the modem through QMI ([qccium8930.dll](./qccium8930.md), services NAS and WDS) to set a notch filter on the FM receiver when a data call is up.  
The caller of `CreateAdapterDriver` (the FM radio "MDD" layer, whose interfaces are given to `CreateMiniportTunerDevice`) isn't known; the strings call it `pMddTunerDevice` / `pPortTunerDevice`.

Location on the phone: `C:\Windows\System32\qcfmminiport.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| [qccium8930.dll](./qccium8930.md) | `qmi_client_get_service_instance`, `qmi_client_init`, `qmi_client_send_msg_sync`, `qmi_client_message_decode`, `qmi_client_release` |
| api-ms-win-core-io-l1-1-1 | `DeviceIoControl`, `GetOverlappedResult`, `CancelIoEx` |
| api-ms-win-core-file-l1-2-0 | `CreateFileA` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExA`, `RegQueryValueExA`, `RegSetValueExA`, `RegCloseKey` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventA`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-processthreads-l1-1-1 | `CreateThread`, `GetCurrentThreadId` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-1 | `GetLastError` |
| api-ms-win-core-sysinfo-l1-2-0 | `GetTickCount64`, `GetSystemTimeAsFileTime` |
| api-ms-win-core-debug-l1-1-1 | `OutputDebugStringA` |
| api-ms-win-core-libraryloader-l1-1-1 | `DisableThreadLibraryCalls` |
| api-ms-win-core-util-l1-1-0 | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0 | `QueryPerformanceCounter` |
| MSVCR110 | `malloc`, `free`, `operator new`/`delete`, `memset`, `memcpy`, `memcmp`, `sprintf_s`, CRT startup (`_initterm`, `_initterm_e`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_malloc_crt`, `_calloc_crt`, `_amsg_exit`, `__C_specific_handler`, `__CppXcptFilter`, `__CxxFrameHandler3`, `__clean_type_info_names_internal`) |

The CRT startup functions, `EncodePointer`/`DecodePointer`, `GetSystemTimeAsFileTime`, `GetCurrentThreadId`, `QueryPerformanceCounter` (`/GS` cookie) are the Visual C++ 2012 DLL boilerplate. `GetTickCount64` is only used for time stamps in the traces.  
The only trace is `OutputDebugStringA` of `sprintf_s` strings ("FM: QFM: +%s" / "-%s" on entry / exit of almost every function, "FM: Miniport: …"); there's no ETW and no WPP.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\\.\qcfmtransportdriver` ([qcfmtransport8930.sys](../drivers/qcfmtransport8930.md)) | `CreateFileA` (`GENERIC_READ \| GENERIC_WRITE`, share 3, `OPEN_EXISTING`, `FILE_FLAG_OVERLAPPED`), `DeviceIoControl` | FM commands and events, SSR notification, see [Transport](#transport) |
| QMI services NAS and WDS of the modem, through [qccium8930.dll](./qccium8930.md) (QMUX transport) | `qmi_client_get_service_instance` / `qmi_client_init` | Data calls and RF band, see [WAN concurrency](#wan-concurrency) |

No DLL is loaded at run time, and no process or COM server is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `CreateAdapterDriver` | 0x100010A4 | `IAdapterDriver **ppAdapter` ? |

`CreateAdapterDriver` only calls `AdapterDriver::CreateInstance` (`sub_10001134`): `E_POINTER` (0x80004003) if the pointer is NULL; otherwise `new` of 12 bytes, and `QueryInterface` of the interface `{7B227537-AE3F-4B57-87BA-9FB32D5FE3F8}` into `*ppAdapter`. If that fails, the object is deleted and `E_OUTOFMEMORY` (0x8007000E) is returned.

### AdapterDriver

12-byte object, vtable `off_1000929C`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 4 | Reference count, starts at 1 |
| 0x08 | 4 | The [MiniportFmRxDevice](#miniportfmrxdevice) it created |

| Index | Function | Comment |
|-------|----------|---------|
| 0 | `QueryInterface` (`sub_1000145C`) | `IUnknown` and `{7B227537-AE3F-4B57-87BA-9FB32D5FE3F8}`, without `AddRef`; `E_NOINTERFACE` (0x80004002) otherwise |
| 1 | `AddRef` (`sub_10001314`) | |
| 2 | `Release` (`sub_100013B0`) | Destructor when the count reaches 0 |
| 3 | `sub_10001528` | `(DWORD *pCount)`: `*pCount` = 1. Number of tuner devices ? |
| 4 | `sub_10001544` | `(DWORD index, DWORD out[2])`: index must be 0 (`E_INVALIDARG` 0x80070057), `out` = {0, 1}. Description of the tuner device ? |
| 5 | `CreateMiniportTunerDevice` (`sub_10001580`) | `(DWORD index, ?, pMddTunerDevice, IMiniportTunerDevice **pp)`: index must be 0 and `pMddTunerDevice` not NULL (`E_INVALIDARG`), `pp` not NULL (`E_POINTER`). Calls [MiniportFmRxDevice::CreateInstance](#createinstance-and-initialize) and keeps the result at +0x08 |
| 6 | destructor (`sub_10001248` → `sub_10001274`) | Forces the reference count of the miniport to 1 and releases it |

### Startup

`start` (`_DllMainCRTStartup`, 0x100087F4): `__security_init_cookie`, then the usual CRT `dllmain_dispatch`.  
`DllMain` (`sub_10001008`) only calls `DisableThreadLibraryCalls` on `DLL_PROCESS_ATTACH` and returns TRUE. Everything else is done when the miniport tuner device is created.

### MiniportFmRxDevice

0x98-byte object (`new` in `MiniportFmRxDevice::CreateInstance`), with two vtables. The constructor (`sub_1000231C`) sets everything to 0, the reference count and the byte +0x0C to 1.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable 1 (`off_1000E2CC`), interface `{07A351D7-6452-4824-A4A1-E30D5C680A8A}` |
| 0x04 | 4 | vtable 2 (`off_1000E2F4`), interface `{1F607EA4-214E-4B05-AF96-A8619084F7F9}` |
| 0x08 | 4 | Reference count |
| 0x0C | 1 | Set to 1 by the constructor and by `cleanup` (`sub_1000163C`, no caller) |
| 0x0D | 1 | ? (cleared) |
| 0x10 | 4 | 1 = a user-defined band was set ([property](#setproperty) `{9B74A1DD-…}`) |
| 0x14 | 4 | `pMddTunerDevice` (given to `Initialize`, `AddRef`). Method 4 (vtable +0x10) = `AsyncComplete(context, HRESULT)` ? |
| 0x18 | 4 | Interface `{64CBAA33-446F-43C0-9041-696006386500}` queried from `pMddTunerDevice`. Method 3 (vtable +0x0C) receives the RDS groups |
| 0x1C | 4 | Power state (1 = on) |
| 0x20 | 16 | [Region parameters](#region-parameters) |
| 0x30 | 4 | Volume (only stored) |
| 0x34 | 4 | Current frequency (kHz) |
| 0x38 | 4 | Start frequency of the seek |
| 0x3C | 4 | Frequency asked by `Tune` |
| 0x40 | 4 | RDS capture started |
| 0x44 | 4 | Context of the pending `SetPowerState` |
| 0x48 | 4 | Context of the pending `Tune` / `Seek` |
| 0x4C | 4 | Context of the pending `SetRegionParams` |
| 0x50 | 0x18 | Critical section |
| 0x68 | 4 | Handle of the [read thread](#read-thread) |
| 0x6C | 4 | ? (cleared by `CancelSeek`) |
| 0x74 | 4 | `m_fSeek` (seek in progress) |
| 0x78 | 4 | Seek direction |
| 0x7C | 4 | `m_fTune` (tune in progress) |
| 0x80 | 4 | Event "power" (`CreateEventA`, auto-reset), set when the enable / disable is complete |
| 0x84 | 4 | Event "tune" (auto-reset), set when a tune is complete |
| 0x88 | 4 | Event "cancel seek" (auto-reset), set when a seek is complete or cancelled |
| 0x8C | 4 | Stereo (1 = stereo, from the stereo status event) |
| 0x90 | 4 | RSSI in % (see [Tune status](#read-thread)) |
| 0x94 | 4 | Antenna type: never written, the property always returns 0 |

The methods of vtable 2 are called with `this` + 4. In the tables below the offsets are always from the start of the object.

Vtable 1 (`{07A351D7-…}`):

| Index | Method | Address |
|-------|--------|---------|
| 0 | `QueryInterface`: `IUnknown`, `{07A351D7-…}` → this; `{1F607EA4-…}` → this + 4; otherwise `E_NOINTERFACE` | `sub_100026C8` |
| 1 | `AddRef` | `sub_10002578` |
| 2 | `Release` | `sub_10002618` |
| 3 | [GetPowerState](#getpowerstate--setpowerstate)`(DWORD *)` | `sub_10002B48` |
| 4 | [SetPowerState](#getpowerstate--setpowerstate)`(DWORD state, context)` | `sub_10002C0C` |
| 5 | `GetVolume(DWORD *)`: +0x30, 0x80040407 if the FM is off | `sub_10002EEC` |
| 6 | `SetVolume(DWORD)`: stores +0x30, 0x80040407 if the FM is off. Nothing is sent to the FM core | `sub_10002FF0` |
| 7 | [GetProperty](#getproperty)`(REFGUID, void *, DWORD cb, DWORD *pcbReturned)` | `sub_1000410C` |
| 8 | [SetProperty](#setproperty)`(REFGUID, void *, DWORD cb)` | `sub_10004418` |
| 9 | destructor | `sub_100023FC` → `sub_10002428` |

Vtable 2 (`{1F607EA4-…}`):

| Index | Method | Address |
|-------|--------|---------|
| 0–2 | `QueryInterface`, `AddRef`, `Release` (thunks to this − 4) | `sub_1000475C`, `sub_10004748`, `sub_10004770` |
| 3 | [SetRegionParams](#setregionparams)`(const REGION *, context)` | `sub_100030C4` |
| 4 | [Tune](#tune)`(DWORD frequency, context)` | `sub_10003450` |
| 5 | `GetTunedFrequency(DWORD *)` | `sub_100037EC` |
| 6 | [Seek](#seek--cancelseek)`(DWORD direction, context)` | `sub_10003990` |
| 7 | [CancelSeek](#seek--cancelseek)`()` | `sub_10003CFC` |
| 8 | `RdsStartCapture()` | `sub_10003EDC` |
| 9 | `RdsStopCapture()` | `sub_10003FF4` |

Error codes returned (custom HRESULTs of the FM framework ?): 0x80040402 property not supported, 0x80040405 tune / seek failed or cancelled (given to `AsyncComplete`), 0x80040407 FM is not turned on, 0x80040409 busy (a region change or a power change is pending). Several methods return 1 (`S_FALSE`) when the context is NULL or a wait times out.  
The asynchronous methods (`SetPowerState`, `SetRegionParams`, `Tune`, `Seek`) keep the context and return; the [read thread](#read-thread) calls `pMddTunerDevice->AsyncComplete(context, hr)` when the matching event arrives. A request that can't be started is completed at once with an error.

### CreateInstance and Initialize

`MiniportFmRxDevice::CreateInstance` (`sub_10002100`): `new` 0x98 + constructor, `Initialize(pMddTunerDevice)`, then `QueryInterface({07A351D7-…})` into the output pointer.

`Initialize` (`sub_10002818`):
1. `pMddTunerDevice->QueryInterface({64CBAA33-…}, this+0x18)`; returns its error if it fails.
2. [QFM Init](#qfm-init-and-deinit) (`sub_10005154`); on failure returns `E_FAIL` (0x80004005).
3. `CreateThread(read_thread, this)` ([read thread](#read-thread), `sub_1000170C`), handle at +0x68.
4. `InitializeCriticalSection(+0x50)`, creates the 3 events +0x80, +0x84, +0x88 (`CreateEventA(NULL, FALSE, FALSE, NULL)`).
5. Stores `pMddTunerDevice` at +0x14 and `AddRef`s it.

On failure everything already created is closed and `E_FAIL` is returned.

The destructor (`sub_10002428`) sets the QFM state (`dword_10011369`) to 7, which stops the read thread and the [WAN thread](#wan-concurrency), signals the WAN event, sends `SetAntennaType(0)`, calls [QFM DeInit](#qfm-init-and-deinit), closes the 3 events, waits 100 ms for the read thread, deletes the critical section and releases the two MDD interfaces.

### GetPowerState / SetPowerState

`GetPowerState` returns +0x1C (`E_POINTER` if the pointer is NULL).

`SetPowerState(state, context)` (`sub_10002C0C`):
1. Context NULL: returns 1. Same state as +0x1C: completes the context at once with `S_OK`.
2. If a power change is pending (+0x44), waits for the power event (3 s; returns 1 on timeout). Otherwise, if a tune or a region change is pending, waits for the tune event (2 s); if a seek is in progress, calls `CancelSeek`.
3. Stores the context at +0x44 (power event reset).
4. state 1: QFM [Enable](#enable-and-disable); state 0: QFM Disable. If it fails the context is cleared and 1 is returned.

The context is completed by the read thread on the command complete of `0x4C01` / `0x4C02`: +0x1C = 1 / 0, power event set, `AsyncComplete(context, 0)` if the status is 0, `AsyncComplete(context, 1)` otherwise.

### SetRegionParams

`SetRegionParams(region, context)` (`sub_100030C4`):
1. 0x80040407 if the FM is off, 1 if the context is NULL, `E_INVALIDARG` if `region` is NULL.
2. Same 16 bytes as +0x20: completes at once with `S_OK`.
3. A region change or a power change pending: `AsyncComplete(context, 0x80040409)`.
4. Waits for a pending tune (2 s), or cancels a seek.
5. Saves the old values, copies the region to +0x20 and its first dword to the current frequency +0x34, stores the context at +0x4C, and calls QFM [ConfigRegion](#commands) (`sub_100067FC`). On failure the old values are restored.

ConfigRegion tunes to the lowest frequency of the band after the configuration: the context is completed by the read thread on the next [tune status event](#read-thread).

### Region parameters

The 16-byte structure given to `SetRegionParams` (kept at +0x20):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Lowest frequency (kHz) |
| 0x04 | 4 | Highest frequency (kHz) |
| 0x08 | 4 | Channel spacing in kHz: 200, 100 or 50 (anything else is traced as an error and sent as 200) |
| 0x0C | 4 | Emphasis ? : 0 → byte 1 in the command, otherwise byte 0 |

### Tune

`Tune(frequency, context)` (`sub_10003450`):
1. 0x80040407 if the FM is off, 1 if the context is NULL, `E_INVALIDARG` if the frequency is outside [+0x20, +0x24] ("Tune - Frequency out of band").
2. A region change or a power change pending: `AsyncComplete(context, 0x80040409)`. A seek in progress is cancelled.
3. A previous tune context still pending is completed with 0x80040405.
4. `m_fTune` = 1, stores the frequency at +0x34 and +0x3C and the context at +0x48, resets the tune event, and calls QFM `SetStation(frequency)` (`sub_10006690`). On failure the old values are restored and the context cleared.

`GetTunedFrequency` (`sub_100037EC`) calls QFM `GetStationParams` and returns its frequency, clamped to the band; it also updates the RSSI +0x90.

### Seek / CancelSeek

`Seek(direction, context)` (`sub_10003990`): same checks as `Tune` (FM on, context, region / power busy → 0x80040409); waits for a pending tune (2 s) or cancels a running seek; then `m_fSeek` = 1, +0x38 = current frequency, +0x78 = direction, context at +0x48, and QFM `Search(direction)` (`sub_10006AF0`).

`CancelSeek` (`sub_10003CFC`): 0x80040407 if the FM is off; returns 0 if no seek is running ("No seek active"). Clears +0x6C, resets the cancel-seek event, sends QFM `CancelSearch` (`sub_10006C2C`, opcode 0x4C11) and waits up to 2 s for the cancel-seek event (returns 1 on timeout).

`RdsStartCapture` / `RdsStopCapture`: if the state of +0x40 changes, QFM `SetRdsGroupOptions(0xFFFFFFFF, 1, 0)` / `SetRdsGroupOptions(0, 1, 0)` (`sub_10006D44`).

### GetProperty

`GetProperty(guid, pData, cbData, pcbReturned)` (`sub_1000410C`): `E_POINTER` if `pData` or `pcbReturned` is NULL, 0x80040407 if the FM is off, 0x80040402 for an unknown GUID. `E_INVALIDARG` when the size is too small or the QFM call fails.

| GUID | Size | Value |
|------|------|-------|
| `{597995DF-C843-41E4-AD45-C27EA4699E3F}` | 4 | RSSI in %: QFM `GetStationParams`, (signed byte +5 of the station parameters + 120) × 2.55 |
| `{C9851417-2B06-4E0A-A54F-AB633D0FD762}` | 4 | Stereo: +0x8C |
| `{6FAFEB91-60EA-48E1-87F3-4712590E325A}` | 4 | Antenna type: +0x94 (always 0) |
| `{901A0F1C-26AE-449D-916C-9CE196316824}` | 11 | The raw [station parameters](#events) (`GetStationParams`); the size isn't checked |
| `{ED95205E-595F-47AC-B311-50EF4BD481EF}` | 1 | Signal threshold (`GetSignalThreshold`, opcode 0x4C09); the size isn't checked |
| `{43B56F83-4C43-45F3-A0E1-B83424E972C5}` | 36 | RDS group counters (`GetRDSGrpCounters`, opcode 0x5801): the first byte of `pData` is sent as parameter, the 36 bytes of the answer are written after it |
| `{5E230F08-C6AB-4F7B-9C5F-1D9E4EAF90F4}` | 9 × n | Program service names (`GetPS`): the n 9-byte entries of the last PS event, without any command |
| `{3324DD38-91E3-4085-BD2B-4BB64FC314D8}` | 4 | Pin connectivity test (`GetPinConnResult`, opcode 0xFC09): two 16-bit results. `*pcbReturned` isn't written |

### SetProperty

`SetProperty(guid, pData, cbData)` (`sub_10004418`): 0x80040407 if the FM is off, `E_INVALIDARG` if `pData` is NULL, `cbData` is 0 or the QFM call fails, 0x80040402 for an unknown GUID. The first byte (or dword) of `pData` is used:

| GUID | QFM call |
|------|----------|
| `{AD048333-0A1F-4071-80AE-AE95BE33A552}` | `SetAntennaType(byte)` |
| `{20669426-A79F-4065-8639-34E2A075F201}` | `SetMuteMode(byte, 0)` |
| `{FF1DE3C6-0001-457D-B0E4-F272C424B592}` | `SetMuteMode(1, byte)` |
| `{592BFAD6-2AF4-421A-AE72-E5CEEE71927A}` | `SetHlsi(byte)` |
| `{2C464A1E-28F1-4D40-8462-448676E8C54F}` | `SetNotchControl(byte)` |
| `{EB231917-E3CF-4AAC-AB1E-A2B4C978B190}` | `SetStereoMode(byte)` |
| `{4452CEE4-272D-45F2-A007-7D826754F288}` | `SetSignalThreshold(byte)` |
| `{5ACE609D-3AFF-408A-8D4A-EB3D39EF41A8}` | `SetRdsGroupProcessing(dword)` |
| `{5D3A5E47-A728-4EF5-8F82-B3786EA6ED75}` | `SetRdsGroupProcessing(byte == 1 ? 2 : 0)` |
| `{9B74A1DD-A9FE-47BE-AEF4-F77EE61828F3}` | User-defined band: clears the region +0x20, sets +0x10 = 1, `ConfigUserDefinedRegion(pData)` (12 bytes sent as is) |
| `{1234B27B-E2EF-41DB-86B8-7EE1B1CBA0C7}` | `Search(dword)` directly, without context ("Sending seek command down") |
| `{D135A60D-FD6D-4FA6-AA04-CD87D29DF119}` | `CancelSearch()` |
| `{30451F01-92C0-41E3-BD81-64FD65EF221B}` | `SetStation(dword)` directly, without context |

### Read thread

`read_thread` (`sub_1000170C`, started by `Initialize`) loops until the QFM state is 7 with a 0x101-byte buffer: QFM [Read](#transport) (`sub_10004868`) waits for one event, then the thread dispatches it on its first byte (see [Events](#events)). If the read has failed with `ERROR_OPERATION_ABORTED` (SSR flag `dword_1001136D`), it traces "SSR is happening" and the thread ends.

| Event | Action |
|-------|--------|
| 0x0F command complete, opcode 0x4C01 | `FM_RX_EV_ENABLE_RECEIVER`: power on (+0x1C = 1) if the status is 0, power event, completes the power context |
| 0x0F, opcode 0x4C02 | `FM_RX_EV_DISABLE_RECEIVER`: power off, clears the region, power event, completes the power context |
| 0x0F, opcode 0x4C11 | `FM_RX_CANCEL_SEARCH_CMD` |
| 0x0F, other | Ignored (0x4C04…0x4C10, 0x4C14…0x4C17, 0x5402…0x5407, 0xFC09) or traced "cmd complete received for command %u" |
| 0x01 tune status | `FM_RX_TUNE_STATUS_EVT`. User-defined band (+0x10 = 1): only traced. Otherwise RSSI +0x90 = (signed byte [8] + 120) × 2.55, frequency = dword [3]; then, in this order: a pending region change is completed with `S_OK`; a tune (`m_fTune`) at the frequency asked sets the tune event and completes the tune context with `S_OK` ("tune at cancelled frequency" otherwise); a seek sets the cancel-seek event and completes the seek context, with `S_OK` or with 0x80040405 when it was cancelled. The current frequency +0x34 is updated |
| 0x10 command status | Status byte [2] ≠ 0 for the tune or the search command: completes the pending tune / seek context with 1 or 0x80040405 ("cmd status event for Tune / Search received") |
| 0x08 RDS group | The four 16-bit blocks at [3], [5], [7], [9] are given to method 3 of the MDD interface +0x18 ("ProcessRdsGroup failed" if it fails) |
| 0x03 stereo status | +0x8C = 1 if byte [2] is 1, else 0 |
| 0x05, 0x12 | `FM_RX_SEARCH_IN_PROGRESS_EVT`, `FM_RX_SEARCH_COMPLETE_EVT`: only traced |
| 0x09, 0x0A | Nothing (the PS event 0x09 is kept by QFM Read for `GetPS`) |
| other | "unknown event with opcode %x" |

### QFM Init and DeInit

The QFM layer works on a global structure at `byte_10011328` (0x653 bytes, cleared by `Init`), with the current QFM state at `dword_10011310`.

`Init` (`sub_10005154`):
1. `Reset` (`sub_10004784`): clears the state and the station data, default region {0, 87 500, 108 000} kHz (`dword_1000ABD4`), frequency 87 500 kHz (0x155CC).
2. Creates the WAN event (manual reset) and starts the [WAN thread](#wan-concurrency) `wan_conc_thread` (`sub_10007D64`) and the [SSR thread](#transport) `ssr_thread` (`sub_100081F0`).
3. Creates the manual-reset events: response (`dword_1001139C`), write, read and SSR notification (hEvent of the three `OVERLAPPED`).
4. Opens `\\.\qcfmtransportdriver` (`CreateFileA`, overlapped). On failure every handle is closed.
5. `InitializeCriticalSection`.

Returns 0, or 0x68 on failure.  
`DeInit` (`sub_1000556C`) deletes the critical section, closes the events, `CancelIoEx` of the pending [IOCTL 0x99002654](../drivers/qcfmtransport8930.md#ioctl-0x99002654), waits 1 s for the SSR thread and 100 ms for the WAN thread, and closes the transport handle.

### Transport

All the I/O is overlapped on the handle of `\\.\qcfmtransportdriver`; each call waits for its own completion with `GetOverlappedResult(…, TRUE)`.

| IOCTL | Function | Buffers | Use |
|-------|----------|---------|-----|
| [0x9900264C](../drivers/qcfmtransport8930.md#ioctl-0x9900264c) | `Read` (`sub_10004868`) | output 0x101 bytes | Waits for one [event](#events) of the FM core |
| [0x99002650](../drivers/qcfmtransport8930.md#ioctl-0x99002650) | `Write` (`sub_10004F34`) | input: the [command](#commands) | Sends one command |
| [0x99002654](../drivers/qcfmtransport8930.md#ioctl-0x99002654) | `ssr_thread` (`sub_100081F0`) | none | Pending until the transport device is removed or the request is cancelled |

`Write` returns 0x1F (`ERROR_GEN_FAILURE`) when the SSR flag is set or the IOCTL fails. Then it waits up to 1 s for the response event, which `Read` sets when the command complete of the command arrives, and returns the status byte of the answer (`byte_10011328`), or 0x1F on timeout.  
`Read` sets the SSR flag `dword_1001136D` when the read fails with `ERROR_OPERATION_ABORTED` (995).  
`ssr_thread` only traces the completion of its IOCTL and ends; it doesn't set the SSR flag.

### Commands

Every command is a packet `opcode` (2 bytes, little endian), parameter length (1 byte), parameters. The OGF (opcode >> 10) gives the group: 0x13 (0x4Cxx) FM receive, 0x15 (0x54xx) FM common, 0x16 (0x58xx), 0x3F (0xFCxx) vendor / test.  
Most commands are refused with 0xC (`ERROR_INVALID_ACCESS`) when the table `unk_10009458` doesn't allow them in the current QFM state.

| Opcode | Function | Parameters | Comment |
|--------|----------|------------|---------|
| 0x4C01 | `Enable` (`sub_100062D0`) | none | Only in state 0 → state 1. See [Enable](#enable-and-disable) |
| 0x4C02 | `Disable` (`sub_1000642C`) | none | States 1–6 → state 0, then `Reset` |
| 0x4C04 | `ConfigRegion` (`sub_100067FC`) | 12: emphasis ? (byte), spacing (0 = 200, 1 = 100, 2 = 50 kHz), 0, HLSI (0), lowest frequency (dword), highest frequency (dword) | States 1–3. The 12 bytes are kept (`dword_1001138C`), then `SetStation(lowest frequency)` |
| 0x4C04 | `ConfigUserDefinedRegion` (`sub_100069A4`) | 12: the 3 dwords of the property | Same, then `SetStation` |
| 0x4C04 | `SetHlsi` (`sub_10007110`) | 12: the kept region with byte 3 = HLSI | States 1–3 |
| 0x4C05 | `SetMuteMode(a, b)` (`sub_10006FF0`) | 2: b, a | States 1–3, 5 |
| 0x4C06 | `SetStereoMode` (`sub_10007248`) | 4: mode, 1, 1, 1 | States 1–3, 5 |
| 0x4C07 | `SetAntennaType` (`sub_10006EF8`) | 1 | Any state |
| 0x4C08 | `SetSignalThreshold` (`sub_1000746C`) | 1 | States 1–3, 5 |
| 0x4C09 | `GetSignalThreshold` (`sub_10007584`) | none | States 2, 3, 5. Answer: byte [6] |
| 0x4C0A | `GetStationParams` (`sub_10006560`) | none | States 2–6. Answer: 11 bytes from [6] |
| 0x4C0E | `Search` (`sub_10006AF0`) | 3: 0, 1, direction | Only in state 2 → state 4 |
| 0x4C11 | `CancelSearch` (`sub_10006C2C`) | none | States 4, 5 |
| 0x4C12 | `SetRdsGroupOptions` (`sub_10006D44`) | 9: mask (dword), dword, byte | States 1–6. If the mask isn't 0, followed by 0x4C13 with 0 |
| 0x4C13 | `SetRdsGroupProcessing` (`sub_100077AC`) | 4: dword | States 1–6 |
| 0x4C15 | `SetNotchControl` (`sub_10007374`) | 1: 0 none, 1 low pass, 2 high pass (see [WAN concurrency](#wan-concurrency)) | Any state |
| 0x5401 | `SetStation` (`sub_10006690`) | 4: frequency (kHz) | States 1, 2, 6 → state 6. Clears the PS data |
| 0x5402 | `GetDefaultRxConfig` (`sub_1000606C`) | 3: 0x15, 0x20, 0 | Reads 32 bytes of [receiver configuration](#receiver-configuration) |
| 0x5403 | `SetDefaultRxConfig` (`sub_10006174`) | "2", then 0x15, 0x20 and the 32 bytes (packet of 0xFE bytes) | Writes the receiver configuration |
| 0x5406 | `DoCalibration` (`sub_10005EB0`) | 1: 1 | Only if `bIsFmCalibrationDone` is 0 |
| 0x5407 | (`DoCalibration`) | 0x18: 1, the 23 bytes of calibration data | Always sent after the calibration check |
| 0x5801 | `GetRDSGrpCounters` (`sub_100076A4`) | 1: byte | Answer: 36 bytes from [6] |
| 0xFC09 | `GetPinConnResult` (`sub_10007978`) | none | Answer: `bt_test_id` [7], `bt_test_result` [8], `fm_test_id` [0xD], `fm_test_result` [0xE] |

QFM states (`dword_10011310`), as changed by this DLL: 0 off, 1 enabled, 2 tuned (tune status in state 6), 4 searching (`Search` in state 2), 5 (tune status in state 4), 6 tuning (`SetStation`, or search complete in states 4–5). State 3 is never set.

### Enable and disable

`Enable` (`sub_100062D0`) sends 0x4C01; if it succeeds: state 0 → 1, "FM enabled" flag `dword_1001137D` = 1, then
1. `GetDefaultRxConfig` (32 bytes),
2. [ReadRegistryKeys](#registry) (`sub_10005748`) patches them,
3. `SetDefaultRxConfig` writes them back,
4. `DoCalibration` (`sub_10005EB0`): if `bIsFmCalibrationDone` is 0, opcode 0x5406; its answer (23 bytes from [7]) is kept, the flag set, and both are written to the registry (`WriteRegKeys`, `sub_10005CF8`). Then opcode 0x5407 sends the calibration data to the FM core,
5. `SetStereoMode(0)`, `SetMuteMode(1, 0)`,
6. if at least one data call is up, `SetNotchControl(notch)`.

`Disable` (`sub_1000642C`) sends 0x4C02, state → 0, clears the "FM enabled" flag and calls `Reset`.

### Events

Packets read from the transport: event code (1 byte), parameter length (1 byte), parameters. `Read` (`sub_10004868`) keeps the data the QFM functions need and sets the response event:

| Code | Name (traces) | Content |
|------|---------------|---------|
| 0x01 | `FM_RX_TUNE_STATUS_EVT` | [Station parameters](#events) from [3]: frequency (dword [3]), RSSI [8]… QFM state 6 → 2, 4 → 5 |
| 0x03 | `FM_RX_STEREO_STATUS_EVT` | [2]: 1 = stereo |
| 0x05 | `FM_RX_SEARCH_IN_PROGRESS_EVT` | |
| 0x08 | RDS group | 4 blocks of 16 bits at [3], [5], [7], [9] |
| 0x09 | `FM_RX_PROGRAM_SERVICE_EVT` | 0x7C bytes from [2] kept (`unk_10011806`): [9] number of PS names, [10] the 9-byte entries (PS name, 8 characters ?) |
| 0x0F | Command complete | [2] number of commands ?, [3] opcode (16 bits), [5] status, [6] return parameters |
| 0x10 | Command status | [2] status, [4] opcode (16 bits). Only 0x4C0E (search) and 0x5401 (tune) are expected |
| 0x12 | `FM_RX_SEARCH_COMPLETE_EVT` | QFM state 4, 5 → 6 |

Station parameters (answer of `GetStationParams`, 11 bytes): +0 frequency (dword, kHz), +5 RSSI (signed, dBm ?), the other fields are unknown.

### Receiver configuration

The 32 bytes read with opcode 0x5402 (offset 0x15 of the default data ?) and written back with 0x5403 (`dword_10011345`). The DLL changes these bytes:

| Offset | Value | Source |
|--------|-------|--------|
| 0x08–0x0B | `CFOTH12` (4 bytes, little endian) | New algorithm only |
| 0x13 | `SiNRTH` (old algorithm) / `SiNRFinalStage` (new algorithm) | Registry |
| 0x14 | `NoOfSiNRSamples` | Old algorithm only |
| 0x15 | `IntDetTHLow` | Old algorithm only |
| 0x16 | `IntDetTHHigh` | Old algorithm only |
| 0x19 | 1 = old search algorithm (`newSearchAlgorithm` = 0), 0 = new | Set by `SetDefaultRxConfig` |
| 0x1A | `SiNRFirstStage` | New algorithm only |
| 0x1B | `RMSSIFirstStage` | New algorithm only |

### Registry

Key `HKLM\SYSTEM\ControlSet001\Control\Tuner\Audio\FmRadio`, opened by `ReadRegistryKeys` (`sub_10005748`, `KEY_READ`) at each `Enable`, and by `WriteRegKeys` (`sub_10005CF8`, `KEY_SET_VALUE`) after a calibration:

| Value | Type | Use |
|-------|------|-----|
| `newSearchAlgorithm` | DWORD | 0 = old search algorithm, otherwise the new one |
| `NoOfSiNRSamples` | DWORD | Old algorithm: byte 0x14 of the [receiver configuration](#receiver-configuration) |
| `IntDetTHLow` | DWORD | Old algorithm: byte 0x15 |
| `IntDetTHHigh` | DWORD | Old algorithm: byte 0x16 |
| `SiNRTH` | DWORD | Old algorithm: byte 0x13 |
| `CFOTH12` | DWORD | New algorithm: bytes 0x08–0x0B (default 15 000 = 0x3A98 if the value is missing) |
| `RMSSIFirstStage` | DWORD | New algorithm: byte 0x1B (signed) |
| `SiNRFirstStage` | DWORD | New algorithm: byte 0x1A (signed) |
| `SiNRFinalStage` | DWORD | New algorithm: byte 0x13 |
| `bIsFmCalibrationDone` | DWORD | Read if not already set; written to 1 after a successful calibration (opcode 0x5406) |
| `procCalData` | REG_BINARY, 23 bytes | Calibration data, read with the flag, written after the calibration, sent with opcode 0x5407 |

A value that can't be read is traced and the byte keeps the value read from the FM core.

### WAN concurrency

`wan_conc_thread` (`sub_10007D64`, started by QFM `Init`) avoids the interference of the modem with the FM receiver by setting a notch filter while a data call is up:

1. NAS client: `qmi_client_get_service_instance(NAS service object, 16, …)` then `qmi_client_init` without indication callback (handle `dword_10011A50`). Service object `unk_1000AF40` (library version 4, IDL version 1, service 3 = NAS).
2. WDS clients: for the instances 16 to 19 (QMUX ports 0 to 3 of [qccium8930.dll](./qccium8930.md#service-info), table `unk_1001101C`), `qmi_client_get_service_instance` and `qmi_client_init` with the indication callback `wan_cb` (`sub_10007C7C`). Service object `unk_1000C814` (service 1 = WDS).
3. For each WDS client, message 0x22 (`QMI_WDS_GET_PKT_SRVC_STATUS`, no request, 12-byte response, 500 ms): a status of 2 (connected) counts one data call (`byte_100117A9`). If there is at least one, `query_rf_band_info_and_set_notch_filter`.
4. Loop, until the QFM state is 7: waits for the WAN event, decodes the indication kept by `wan_cb` (`qmi_client_message_decode`, indication 0x22, with the client of instance 16, 0x2C bytes): connection status 2 → one more data call and `query_rf_band_info_and_set_notch_filter`; 1 (disconnected) → one less, and at 0 the notch is set back to 0 (`SetNotchControl(0)` if the FM is enabled).
5. At the end, `qmi_client_release` of the 5 clients.

`wan_cb` only handles the indication 0x22 (`QMI_WDS_PKT_SRVC_STATUS_IND_V01`): copies it into a 0x400-byte buffer (the length isn't checked) and sets the WAN event.

`query_rf_band_info_and_set_notch_filter` (`sub_10007B44`): NAS message 0x31 (`QMI_NAS_GET_RF_BAND_INFO`, 0xCC-byte response, 500 ms); the dword +8 of the response is the active band. `sub_10007A88` returns 1 ("band is above 1 GHz") for the band values 4, 6, 8, 14–17, 47, 48, 80–83, 88, 90, 110–123, 126, 128–130, 135–142: notch 2 (high pass); any other band: notch 1 (low pass). The notch is sent at once with `SetNotchControl` if the FM is enabled, otherwise at the next `Enable`.  
The mapping of these values to the QMI NAS band names isn't checked here.
