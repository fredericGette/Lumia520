## audiodg.exe

The Windows Audio Device Graph process: it runs the software part of the audio engine of Windows Phone 8.1, outside the `AudioSrv` service.  
`audiodg.exe` (211 728 bytes, 935 functions, public symbols available) is an ATL out-of-process COM server with no window. It registers 8 COM classes and an RPC interface, then waits for its stop event or the end of `AudioSrv`. The device graph classes build a pipeline of APOs (Audio Processing Objects) for each audio endpoint and exchange the samples with the client processes through shared memory. The mixing engine and the pump aren't in this binary: they come from two COM classes created at run time (see [Dependencies](#dependencies)).  
It opens no device and sends no IOCTL: the audio hardware is reached through the endpoint objects activated by `MMDevAPI.dll`, so the link with [qc8x60aud.sys](../drivers/qc8x60aud.md) isn't visible here.

Location on the phone: `C:\Windows\System32\audiodg.exe` ?  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `NtAlpcCreatePort`, `NtAlpcConnectPort`, `NtAlpcAcceptConnectPort`, `NtAlpcSendWaitReceivePort`, `AlpcInitializeMessageAttribute`, `AlpcGetMessageAttribute`, `NtClose`, `NtQueryInformationProcess`, `RtlCreateMemoryBlockLookaside`, `RtlAllocateMemoryBlockLookaside`, `RtlFreeMemoryBlockLookaside`, `RtlExtendMemoryBlockLookaside`, `RtlDestroyMemoryBlockLookaside`, `RtlCreateMemoryZone`, `RtlAllocateMemoryZone`, `RtlLockMemoryZone`, `RtlUnlockMemoryZone`, `RtlDestroyMemoryZone`, `RtlRandomEx`, `RtlInitUnicodeStringEx`, `RtlNtStatusToDosError`, `RtlSetLastWin32ErrorAndNtStatusFromNtStatus`, `RtlRaiseException`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `ShipAssert`, `ShipAssertMsgW`, `WinSqmIncrementDWORD`, `EtwEventRegister`, `EtwEventWrite`, `EtwRegisterTraceGuidsW`, `EtwUnregisterTraceGuids`, `EtwLogTraceEvent`, `EtwTraceMessage`, `EtwGetTraceEnableFlags`, `EtwGetTraceEnableLevel`, `EtwGetTraceLoggerHandle` |
| RPCRT4.dll | `RpcServerUseProtseqEpW`, `RpcServerRegisterIf3`, `RpcServerUnregisterIfEx`, `NdrServerCall2`, `I_RpcBindingInqTransportType`, `I_RpcBindingInqLocalClientPID`, `RpcImpersonateClient`, `RpcRevertToSelf` |
| MMDevAPI.dll | `CleanupDeviceAPI`, `GetEndpointGuidFromEndpointId`, `GetSessionIdFromEndpointId` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoUninitialize`, `CoInitializeSecurity`, `CoCreateInstance`, `CoRegisterClassObject`, `CoRevokeClassObject`, `CoResumeClassObjects`, `CoImpersonateClient`, `CoRevertToSelf`, `CoTaskMemAlloc`, `CoTaskMemRealloc`, `CoTaskMemFree`, `CLSIDFromString`, `StringFromCLSID`, `PropVariantClear` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegCloseKey`, `RegEnumKeyExW`, `RegQueryInfoKeyW`, `RegQueryValueExW`, `RegSetValueExW`, `RegDeleteValueW` |
| api-ms-win-core-memory-l1-1-2.dll | `CreateFileMappingW`, `MapViewOfFile`, `UnmapViewOfFile`, `VirtualLock`, `VirtualUnlock`, `GetProcessWorkingSetSizeEx`, `SetProcessWorkingSetSizeEx` |
| api-ms-win-core-processthreads-l1-1-2.dll | `OpenProcess`, `CreateThread`, `GetCurrentProcess`, `GetCurrentThreadId`, `GetStartupInfoW`, `TerminateProcess` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `WaitForSingleObjectEx`, `WaitForMultipleObjectsEx`, `InitOnceBeginInitialize`, `InitOnceExecuteOnce`, `Sleep`, critical sections |
| api-ms-win-core-handle-l1-1-0.dll | `DuplicateHandle`, `CloseHandle`, `GetHandleInformation` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary`, `GetModuleFileNameW`, `GetModuleHandleA`, `GetModuleHandleW`, `FindResourceExW`, `LoadResource`, `LockResource`, `SizeofResource` |
| api-ms-win-core-heap-l1-2-0.dll | `HeapSetInformation`, `GetProcessHeap`, `HeapAlloc`, `HeapReAlloc`, `HeapFree`, `HeapSize`, `HeapDestroy` |
| api-ms-win-security-base-l1-2-0.dll | `MakeAbsoluteSD` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventWrite` |
| api-ms-win-eventing-classicprovider-l1-1-0.dll | `TraceEvent`, `TraceMessage` |
| api-ms-win-core-windowserrorreporting-l1-1-0.dll | `WerRegisterMemoryBlock` |
| api-ms-win-core-profile-l1-1-0.dll | `QueryPerformanceCounter`, `QueryPerformanceFrequency` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-processenvironment-l1-2-0.dll | `GetCommandLineW` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalAlloc`, `LocalFree` |
| api-ms-win-core-string-l1-1-0.dll, -l2-1-0.dll, -obsolete-l1-1-0.dll | `MultiByteToWideChar`, `CharNextW`, `lstrcmpiW` |
| api-ms-win-core-debug-l1-1-1.dll | `OutputDebugStringA` |
| api-ms-win-core-delayload-l1-1-1.dll | `DelayLoadFailureHook`, `ResolveDelayLoadedAPI` |
| msvcrt.dll | CRT startup and C++ runtime (`__wgetmainargs`, `_wcmdln`, `_initterm`, `wcstoul`, `_vsnwprintf`, `malloc`, `realloc`, `free`, `memcpy`, `_CxxThrowException`, `__CxxFrameHandler3`, …) |

Delay-loaded: `api-ms-win-security-sddl-l1-1-0.dll` (`ConvertStringSecurityDescriptorToSecurityDescriptorW`), `api-ms-win-service-management-l1-1-0.dll` (`OpenSCManagerW`, `OpenServiceW`, `CloseServiceHandle`), `api-ms-win-service-management-l2-1-0.dll` (`QueryServiceStatusEx`) and `OLEAUT32.dll` (`VarUI4FromStr`).  
`msvcrt.dll`, the exception and unwinding functions, and `LoadLibraryExW` / `GetProcAddress` / the resource functions are CRT, `/GS` or ATL boilerplate. There are no exports.

### Dependencies

Files used other than the static imports. No file is opened: the only `LoadLibraryExW` and `GetProcAddress` calls are in the ATL registry helpers, which the startup path doesn't reach.

| File | How | Use |
|------|-----|-----|
| Audio processor class, `AudioEng.dll` ? | `CoCreateInstance` CLSID `{E1150CE9-5BD4-4044-8FE9-98CF40137A41}`, IID `{39298A5B-389B-4B0A-B1DF-25F002B85AD8}` (`IAudioProcessor`), in `CAudioDeviceGraph::Initialize` (0x40A340) | Audio engine: receives the pipeline, activates the APOs |
| Pump class, `AudioEng.dll` ? | `CoCreateInstance` CLSID `{948CFD8C-1888-4E52-8703-99610347EBB6}`, IID `{B028B3E3-DC05-43CF-B458-AB69048B5673}`, in `CAudioDeviceGraph::Initialize` | Timing of the pipeline (`InitializePump`, 0x40ADAC) |
| `MMDevAPI.dll` | `CoCreateInstance` CLSID `{BCDE0395-E52F-467C-8E3D-C4579291692E}` (`MMDeviceEnumerator`), IID `{A95664D2-9614-4F35-A746-DE8DB63617E6}` (`IMMDeviceEnumerator`) | Finds the `IMMDevice` from the endpoint id string, also used by [ShellChrome.dll](../libraries/shellchrome.md) |
| Audio policy class ? | `CoCreateInstance` CLSID `{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}`, IID `{F8679F50-850A-41CF-9C72-430F290290C8}`, in `FillAPOInitSystemEffectsStructure` (0x40E3F8) | Gets the device format when the endpoint has no `PKEY_AudioEngine_DeviceFormat` |
| APO DLLs | CLSIDs read from the pipe descriptor; properties in the registry (see [Registry](#registry)) | System effects and engine APOs, activated through `IAudioProcessor` |
| `AudioDeviceGraph` itself | `CoCreateInstance` CLSID `{ADD18BF7-AB60-4283-A580-D7544DD255D2}`, IID `{141AD42E-FC56-4D14-952D-3D3FF9AA97FB}`, in `CSystemAudioDeviceShared::Initialize` (0x40A258) | The shared device object creates its own graph |

### Parameters

| Command line | Usage | Exit code | Started by |
|---|---|---|---|
| `audiodg.exe <handle>` | `wWinMain` (0x4085B4) reads the whole command line with `wcstoul(…, 16)` and checks the value with `GetHandleInformation`. The handle is stored at offset 0x54 of the ATL module. `PreMessageLoop` (0x408C7C) calls `SetEvent` on it when the RPC interface is registered | `GetLastError()` if the handle is invalid, otherwise the HRESULT of the ATL module (`WinMain`, 0x4086C8) | `AudioSrv` ?: the process checks this service and exits with it, and logs `EVT_AUDIOSRV_AUDIODG_READY` |

The handle must therefore be an event inherited or duplicated by the parent process. There is no other parameter.

### Startup and shutdown

`wWinMain` starts WPP, calls `HeapSetInformation` and `McGenEventRegister`, then `AERTMemoryInitialize` (0x409430), which creates the real-time heap with `RtlCreateMemoryBlockLookaside` (initial size 0x200000, min 4, max 0x8000).

`CAudioDGModule::PreMessageLoop` (0x408C7C) then does these steps:

1. Reads the QPC frequency into `g_u64QPCFrequency`, and calls `CoInitializeEx(NULL, 4)` (multithreaded, `COINIT_DISABLE_OLE1DDE`).
2. Creates two unnamed manual-reset events: stop (module offset 0x44) and startup done (offset 0x48).
3. Opens the RPC endpoint with `RpcServerUseProtseqEpW("ncalrpc", 10, "AudioDeviceGraph", SD)`.
4. Registers the [RPC interface](#rpc-interface) with `RpcServerRegisterIf3`: flags 0x21 (`RPC_IF_AUTOLISTEN | RPC_IF_ALLOW_LOCAL_ONLY`), 1234 calls, callback `AudioDGRpcIfCallback` (0x409790), same security descriptor.
5. Signals the command-line event.
6. Opens the `AUDIOSRV` service (`SERVICE_QUERY_STATUS`) and calls `QueryServiceStatusEx`. If it's stopped or stopping (state 1 or 3), the result is `E_FAIL`. Otherwise it opens the service process with `OpenProcess(SYNCHRONIZE, FALSE, dwProcessId)` and stores the handle at offset 0x4C.
7. Calls `InitializeSecurity` (0x408880), resets `g_EndpointStatistics`, and registers the [COM classes](#com-classes).
8. Stores the result at offset 0x40 and signals the startup event. RPC opnum 1 returns this value.

`InitializeSecurity` calls `CoInitializeSecurity` with these arguments, then `IGlobalOptions::Set(COMGLB_EXCEPTION_HANDLING, COMGLB_EXCEPTION_DONOT_HANDLE)`:

| Argument | Value |
|----------|-------|
| Security descriptor | `O:LSG:LSD:(A;;0x1;;;RC)(A;;0x1;;;AU)(A;;0x1;;;IU)(A;;0x1;;;AC)` |
| Authentication level | 4 (`RPC_C_AUTHN_LEVEL_PKT`) |
| Impersonation level | 2 (`RPC_C_IMP_LEVEL_IDENTIFY`) |
| Capabilities | 0x3020 (`EOAC_STATIC_CLOAKING`, `EOAC_DISABLE_AAA`, `EOAC_NO_CUSTOM_MARSHAL`) |

`RunMessageLoop` (0x408BC4) waits on the stop event and the `AudioSrv` process. When `AudioSrv` ends, it sets the stop event itself (`InitiateShutdownW`, 0x4084DC) and the loop stops.

`PostMessageLoop` (0x408AD0) unregisters the RPC interface and calls `CleanupDeviceAPI`. It sends the 3 counters of `g_EndpointStatistics` to SQM (datapoints 5470, 5951, 5933). If the first counter is above 50, it calls `ShipAssert(47106, …)` and logs `EVT_AUDIODG_GLITCH_THRESHOLD_EXCEEDED`.

### COM classes

`CAtlExeModuleT::PreMessageLoop` (0x40907C) registers all of them with `CoRegisterClassObject(…, CLSCTX_LOCAL_SERVER, REGCLS_MULTIPLEUSE | REGCLS_SUSPENDED)`, then calls `CoResumeClassObjects`.

| CLSID | Class | Interfaces |
|-------|-------|------------|
| `{ADD18BF7-AB60-4283-A580-D7544DD255D2}` | `CAudioDeviceGraph` | `{141AD42E-FC56-4D14-952D-3D3FF9AA97FB}`, `{69A95A38-C637-46A0-9FB2-1C939AEBF2E8}` |
| `{89115307-8248-448F-ADA0-F3F3718A9B2A}` | `CSystemAudioDeviceShared` | `{141AD42E-…}`, `{2F732065-EFF0-4C7C-8FC1-363851B1F1D7}`, `{F611F516-4F04-4F1F-B833-623B47AF2A12}` |
| `{75269C13-41E1-4D0E-B8A0-9F8F22E246C9}` | `CSystemAudioDeviceExclusive` | `{141AD42E-…}`, `{2F732065-…}` |
| `{4654B883-10C0-4524-96B6-7D997104DCF0}` | `CSystemAudioDeviceOffload` | `{141AD42E-…}`, `{2F732065-…}`, `{D81229B1-5A43-480C-92F7-BE0F7F4EAB60}` (volume ?), `{885C7B80-3FA2-4E5A-BE07-CF01E1D6E2CD}` (mute ?), `{419B26E3-FA99-4408-83DE-CC1276EFA489}` (meter ?) |
| `{9DBA709C-B3E1-4013-95B7-5ED33A2E8561}` | `CCrossProcessServerInputEndpoint` | `IAudioEndpoint`, `IAudioEndpointRT`, `IAudioInputEndpointRT`, `IAudioCrossProcessServerEndpoint` |
| `{5BFD515E-4ABA-4483-A1C5-6651B7110AB6}` | `CCrossProcessServerOutputEndpoint` | `IAudioEndpoint`, `IAudioEndpointRT`, `IAudioOutputEndpointRT`, `IAudioCrossProcessServerEndpoint` |
| `{F64A6DA6-E8AF-4B7B-BCA8-847AE765D538}` | `CCrossProcessClientInputEndpoint` | `{CD63314F-3FBA-4A1B-812C-EF96358728E7}`, `{6F49FF73-6727-49AC-A008-D98CF5E70048}`, `IAudioEndpoint`, `IAudioEndpointRT`, `IAudioInputEndpointRT`, `{848C76EA-9EA4-4BC0-A1AC-BBEA17EE55C8}`, `IAudioEndpointControl` |
| `{CD773740-B187-4974-A1D5-E0FF91372277}` | `CCrossProcessClientOutputEndpoint` | Same as the client input endpoint, with `IAudioOutputEndpointRT` |

The clients of these classes aren't known from this binary (`AudioSrv` ?).

The three `CSystemAudioDevice*` classes differ like this:

- `Shared` creates a `CAudioDeviceGraph` and forwards the calls to it (`Initialize`, `CreateStream`, `Start`, …), so it runs the APO pipeline.
- `Exclusive` and `Offload` only activate the endpoint (`ActivateEndpoint`, 0x41E6BC) and give it directly to the stream. `Offload` also queries `{64F1DD49-71CA-4281-8672-3A9EDDD1D0B6}`, `{DFE21355-5EC2-40E0-8D6B-710AC3C00249}`, `{E1546DCE-9DD1-418B-9AB2-348CED161C86}` and `{076A6922-D802-4F83-BAF6-409D9CA11BFE}` on the endpoint.

### Device graph

`CAudioDeviceGraph::Initialize` (0x40A340) validates the descriptor and refuses a period above 10 000 000 (1 s, in 100 ns units). It creates the audio processor and the pump, then builds the device pipe:

1. `CPipeInstance::CreateDevicePipeInstance` (0x40ED20) builds the node list: an optional dummy node, one `CAPOProcessNode` per CLSID of the descriptor, the limiter APO `{D69E0717-DD4B-4B25-997A-DA813833B8AC}` when the audio is float, and the `CDeviceProcessNode`.
2. `CPipeInstance::Initialize`, `ConnectAPOs` and `AddConnectionsAndActivateAPOs` resolve the formats between nodes, connect them and activate the APOs. Matrix, rate converter, meter, volume and limiter have their own `Initialize…Interface` functions.
3. `InitializePump` first tries the mode with flag 0x10, then without it.

`CAudioDeviceGraph::Start` (0x40BEB8) starts the pump, then every pipe. `CreateStream` (0x40B84C) builds a stream pipe in the same way, on top of the device pipe or of a mode pipe (`CreateMode`, 0x42352C). It uses the APO `{12DD4DBB-532B-4FCE-8653-74CDB9C8FE5A}` for some nodes and refuses the stream with 0x887C0050 if method 8 of the pump returns a positive 64-bit value.

An APO node is only accepted if `MaxInputConnections` and `MaxOutputConnections` are both 1 (`CAPOProcessNode::CreateAPOProcessNode`, 0x40F8F0), otherwise the error is 0x887C0037.

System effects are initialised by `InitializeSystemEffectsInterface` (0x40DCE4), through `IAudioSystemEffects2` `{BAFE99D2-7436-44CE-9E0E-4D89AFBFFF56}` or else `IAudioSystemEffects` `{5FA00F27-ADD6-499A-8A9D-6B98521FA75B}`. An empty processing mode is replaced by the default mode `{C18E2F7E-933D-4965-B7D1-1EEF228D2AF3}`.

`TrackSystemEffectBehavior` (0x40E294) keeps a failure counter in the endpoint properties, `PKEY_Endpoint_LFX_FailCount` or `PKEY_Endpoint_GFX_FailCount`. A success resets it. At 10 failures it calls `ShipAssert` with the CLSID of the APO.

### AUDIO_DEVICE_PIPE_DESCRIPTOR parameter

Passed to `Initialize` of the graph and of the `CSystemAudioDevice*` classes. Only the fields read by audiodg.exe are listed.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x04 | 4 | `WAVEFORMATEX *` | Device format, validated by `ValidateWaveFormatEx` |
| 0x0C | 4 | `WAVEFORMATEX *` | If not NULL, adds a dummy node with this format |
| 0x10 | 8 | Period | In 100 ns units, at most 10 000 000 |
| 0x20 | 4 | ? | Passed to the endpoint initialisation |
| 0x24 | 4 | `wchar_t *` | Endpoint id, required |
| 0x28 | 4 | 0 or 1 | Direction: 0 activates `IAudioOutputEndpointRT`, 1 `IAudioInputEndpointRT` |
| 0x2C | 4 | ? | Only logged |
| 0x30 | 4 | Bit mask | Bit `i`: the APO `i` is a system effect |
| 0x34 | 4 | Index | Position of the limiter APO |
| 0x38 | 4 | Index | APO that uses the default mode |
| 0x3C | 4 | Count | Number of APOs |
| 0x40 | 4 | ? | Copied to the endpoint activation parameter |
| 0x44 | 0x10 | ? | Copied to the activation parameter, unless method 6 of `IMMEndpointInternal` returns non-zero |
| 0x54 | 0x10 | GUID | Processing mode of the system effects |
| 0x64 | 4 | ? | Non-zero enables `ApplyFxStateSettings` in the shared device |
| 0x68 | 4 | ? | Stored in the graph at offset 0xA8 |
| 0x6C | 4 | ? | Effects state, read by `ApplyFxStateSettings` (0x40B018) |
| 0x70 | 0x10 × n | GUID array | CLSID of each APO |

### Streams and shared memory

`CEndpointInstance::CreateStreamEndpointInstance` (0x4136F4) creates a server endpoint for each stream.

`SYSTEM_AUDIO_STREAM_DESCRIPTOR`, as read by audiodg.exe:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0, 1 or 2 | Stream type. A capture graph accepts only 1, a render graph 0 and 2 (loopback ?) |
| 0x08 | 4 | 0 or 1 | Set to 1 by audiodg.exe if the client can't be opened: named objects are then used |
| 0x0C | 4 | PID | Client process, opened with `PROCESS_DUP_HANDLE` while impersonating it |
| 0x10 | 4 | `wchar_t *` | SID of the client, used in the ACL of the named objects |
| 0x18 | 8 | Id | Set to the `CPipeInstance` address, used in the object names |
| 0x38 | 4 | Size | Size of the format, at least 0x12 (0x28 for `WAVE_FORMAT_EXTENSIBLE`) |
| 0x3C | 4 | `WAVEFORMATEX *` | Stream format |
| 0x40 | 4 | Flags | 0x40000: starts the ALPC handle server |
| 0x44 | 4 | `wchar_t *` | Output: name of the ALPC port |

`CCrossProcessBaseServerEndpoint::Initialize` (0x412D78) creates these objects. Both fail with 0x800700B7 if they already exist:

- A section with `CreateFileMappingW(INVALID_HANDLE_VALUE, …, PAGE_READWRITE, …)`, mapped and locked in memory (`AERTLockMemory`).
- A manual-reset event, initially signaled.

If the client can't be opened, they have the names below and an ACL `D:(A;OICI;0x%08I32X;;;<SID>)` (0xF001F for the section, 0x1F0003 for the event). Otherwise they are unnamed and their handles are duplicated into the client.

Layout of the section:

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 0xA0 | Control block | Zeroed at creation, registered with `WerRegisterMemoryBlock` |
| 0xA0 | 4 | 0x45504344 | Magic |
| 0xA8 | 0x10 | Header | 0xA8: header size (`cbSize` + 184), 0xB0: 64-bit parameter of `Initialize` (?) |
| 0xB8 | 0x80 | `wchar_t[]` | Name of the ALPC port, if any |
| 0x138 | 4 | Count | Queue entries: frames of the buffer / frames per packet + 3, at least 25 |
| 0x13C | 4 | Offset | Queue, aligned on 0x80 |
| 0x140 | 4 | Offset | Audio data, aligned on 0x400 |
| 0x144 | 4 | Size | Total size of the section |
| 0x148 | 18 + `cbSize` | `WAVEFORMATEX` | Stream format |
| Queue offset | 64 × count | Messages | `SharedMessageQueueItem`, timestamps of the packets |
| Data offset | Buffer size | Samples | Rounded up to a whole number of frames |

### ALPC port

With the flag 0x40000, `HandleSendReceiveServer::Initialize` (0x4144A0) creates a port and a thread (`AeServerApiProc`, 0x4147FC). It lets a client give a handle to audiodg.exe when audiodg.exe can't open that client.

- Name: `\BaseNamedObjects\AudioEngineDuplicateHandleApiPort<n>`, with `n` from `RtlRandomEx`. There are 3 attempts when the name is already used.
- Security descriptor: `D:(A;;0x1;;;WD)(A;;0x1;;;S-1-15-2-1)` (everyone and all application packages).
- A message must have a total length of 32 bytes and carry the handle attribute (0x10000000). `AeServerProcessClientRequest` (0x4149AC) writes the received handle into the event field of the server endpoint, which then signals it when packets are ready ?. A message without the attribute or with another length gets 0xC00000AF.

The client side is `HandleSendReceiveClient::SendHandle` (0x41B9E0), which uses `NtAlpcConnectPort`.

### RPC interface

Interface `{DE3B9BC8-BEF7-4578-A0DE-F089048442DB}` version 1.0, on `ncalrpc:[AudioDeviceGraph]`. The endpoint security descriptor is `D:(A;;GRGWGX;;;WD)(A;;GRGWGX;;;RC)(A;;GA;;;BA)(A;;GA;;;OW)(A;;GR;;;AC)`. `AudioDGRpcIfCallback` returns access denied unless the transport type is 4 (`TRANSPORT_TYPE_LPC`).

| Opnum | Function | Parameters | Action |
|-------|----------|------------|--------|
| 0 | `AudioDGShutdownADG` (0x414AE0) | Binding | Sets the stop event |
| 1 | `AudioDGGetStartupStatus` (0x409768) | Binding | Waits for the startup event and returns the startup HRESULT |
| 2 | `AudioDGChallenge` (0x419EC0) | Binding, section handle, 2 DWORDs | See below |
| 3 | `AudioDGGetEndpointStreamVpo` (0x423504) | Binding, endpoint id, stream id (64 bits), type, out VPO handle | `CSystemAudioDeviceCollection::GetEndpointStreamOta` (0x422DBC). Type 1 or 4, otherwise `E_NOTIMPL` |
| 4 | `AudioDGGetStreamVpoDescription` (0x41A068) | VPO handle, … | Description of the virtual protected output ? |
| 5 | `AudioDGSetStreamVpoPolicySchemas` (0x419280) | VPO handle, 3 parameters | `CVirtualProtectedOutput::SetPolicySchemas` (0x41BE7C) |
| 6 | `AudioDGCloseStreamVpo` (0x419260) | VPO handle | Releases the object. `VPOHANDLE_rundown` (0x41924C) does the same if the client dies |

`AudioDGChallenge` probably lets a protected client check that audiodg.exe is the real process ?:

1. Gets the client PID with `I_RpcBindingInqLocalClientPID`, and opens the client with access 0x440 while impersonating it.
2. Calls `NtQueryInformationProcess(ProcessBasicInformation)` with the extended structure (size 0x20). If bit 0 of the flags (`IsProtectedProcess`) isn't set, it returns access denied.
3. Duplicates the section handle of the client with `FILE_MAP_WRITE` and writes the 2 DWORDs at the start of the section.

The VPO objects (`CVirtualProtectedOutput`, `CProtectedOutputController`) apply content protection policies to a stream, and `SetLoopbackConstriction` limits the loopback capture accordingly ?.

### Registry

`GetAPOProperties` (0x40F9F4) and `InnerGetCommon` (0x40FBAC) read the key below. It enumerates the subkeys and compares each name with the CLSID as a string.

`HKEY_CLASSES_ROOT\AudioEngine\AudioProcessingObjects\<CLSID>`

| Value | Offset in `APO_REG_PROPERTIES` | Comment |
|-------|--------------------------------|---------|
| `Flags` | 0x10 | |
| `FriendlyName` | 0x14 | 256 characters |
| `Copyright` | 0x214 | 256 characters |
| `MajorVersion`, `MinorVersion` | 0x414, 0x418 | |
| `MinInputConnections`, `MaxInputConnections` | 0x41C, 0x420 | Maximum must be 1 |
| `MinOutputConnections`, `MaxOutputConnections` | 0x424, 0x428 | Maximum must be 1 |
| `MaxInstances` | 0x42C | |
| `APOInterface0` | 0x434 | String converted with `CLSIDFromString` |

Endpoint properties, read and written through `IPropertyStore`:

| Property | Use |
|----------|-----|
| `PKEY_AudioEngine_DeviceFormat` `{F19F064D-082C-4E27-BC73-6882A1BB8E4C}` | Format given to the system effects |
| `PKEY_Endpoint_GFX_FailCount` `{B3F8FA53-0004-438E-9003-51A46E139BFC},8` | `VT_UI4` failure counter |
| `PKEY_Endpoint_LFX_FailCount` `{B3F8FA53-0004-438E-9003-51A46E139BFC},9` | `VT_UI4` failure counter |

### APOInitSystemEffects2 parameter

Built by `FillAPOInitSystemEffectsStructure` (0x40E3F8) and passed to the system effects APO. Total size 0x40.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0x40 | `cbSize` |
| 0x04 | 0x10 | CLSID | Class of the APO |
| 0x14 | 4 | `IPropertyStore *` | Endpoint properties |
| 0x18 | 4 | `IPropertyStore *` | System effects properties |
| 0x1C | 4 | 0 | Reserved |
| 0x20 | 4 | `IMMDeviceCollection *` | Result of method 11 of the object activated with `{14A59ECA-820B-4A15-A70C-974EEDEEA097}` |
| 0x24 | 4 | Index | Device in the collection |
| 0x28 | 4 | Index | Connector |
| 0x2C | 0x10 | GUID | Processing mode |
| 0x3C | 4 | 0 | `InitializeForDiscoveryOnly` |

### Named objects

| Name | Type | Created by |
|------|------|------------|
| `AudioDeviceGraph` | `ncalrpc` endpoint | `PreMessageLoop` |
| `Global\SYSTEM_AUDIO_STREAM_MAPPING_%I64X` | Section | Stream of a client that can't be opened |
| `Global\SYSTEM_AUDIO_STREAM_EVENT_%I64X` | Event | Same |
| `\BaseNamedObjects\AudioEngineDuplicateHandleApiPort<n>` | ALPC port | Stream with the flag 0x40000 |

`%I64X` is the id at offset 0x18 of the stream descriptor.

### GUIDs

Interface names that aren't in the symbols of the binary come from the Windows SDK headers.  
Manifest events: `EVT_AUDIOSRV_AUDIODG_READY`, `EVT_AUDIODG_GLITCH_THRESHOLD_EXCEEDED`, `EVT_SYSTEM_EFFECT_APO_INITIALIZED` and the `EVT_GLITCH_CP_*` events for the cross-process endpoints (overwritten read pointer, full queue, starvation, …).

| GUID | Name | Use |
|------|------|-----|
| `{AE4BD3BE-F36F-45B6-8D21-BDD6FB832853}` | `AUDIO_EVENT_PROVIDER` | ETW manifest provider Microsoft-Windows-Audio (`EVT_*` events) |
| `{E27950EB-1768-451F-96AC-CC4E14F6D3D0}` | `WPP_ThisDir_CTLGUID_AudioTrace` | WPP control GUID |
| `{A6A00EFD-21F2-4A99-807E-9B3BF1D90285}` | `AEWMIGUID` | Classic ETW provider (`AeWmiInitialize`, 0x408740) |
| `{0F14B37B-5195-44DF-A1D9-BBA90B5135D2}` | `AEWMIGUID_AUDIODG` | Classic ETW event |
| `{64849457-134A-4F3A-8E35-93E91A61212B}` | `AEWMIGUID_ENDPOINT_ACTIVATION` | Classic ETW event |
| `{30A99515-1527-4451-AF9F-00C5F0234DAF}` | `IAudioEndpoint` | Endpoint |
| `{DFD2005F-A6E5-4D39-A265-939ADA9FBB4D}` | `IAudioEndpointRT` | Endpoint, real-time calls |
| `{8FA906E4-C31C-4E31-932E-19A66385E9AA}` | `IAudioOutputEndpointRT` | Render endpoint |
| `{8026AB61-92B2-43C1-A1DF-5C37EBD08D82}` | `IAudioInputEndpointRT` | Capture endpoint |
| `{C684B72A-6DF4-4774-BDF9-76B77509B653}` | `IAudioEndpointControl` | Start, stop, reset |
| `{D4952F5A-A0B2-4CC4-8B82-9358488DD8AC}` | `IAudioDeviceEndpoint` | Hardware endpoint |
| `{FD70EB2D-F0FA-4979-941F-7DBD8B5AB605}` | `IAudioCrossProcessServerEndpoint` | Server endpoint of a stream |
| `{ED899CBB-5613-4541-A78F-66302F0CE211}` | `IMMEndpointInternal` | Tells which activation parameter to build |
| `{4E997F73-B71F-4798-873B-ED7DFCF15B4D}` | `IAudioMediaType` | Implemented by `CAudioMediaType` |
| `{FD7F2B29-24D0-4B5C-B177-592C39F9CA10}` | `IAudioProcessingObject` | APO |
| `{FC7DFF56-6B8D-45A9-B4CA-266F9AC21693}` | Format converter APO ? | `GetFormatConverterAPONode` |
| `{541987EE-0E02-411E-9A85-1FC6156E7F4B}` | Matrix APO ? | `FindConverter`, `InitializeMatrixInterface` |
| `{27C98999-2895-4829-B080-5A8B65BD3DB0}` | Rate converter APO ? | `FindConverter`, `InitializeRateConverterInterface` |
| `{3FD7F233-A716-472E-8F2F-C25954F34E96}` | ? | `FindConverter` |
