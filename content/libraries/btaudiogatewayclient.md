## BTAudioGatewayClient.dll

The client library of the Bluetooth audio gateway (HFP AG) of Windows Phone 8.1: a COM in-process server that hides the pipe protocol of the `BTAGService` service behind the `IBTAG…` interfaces.  
`BTAudioGatewayClient.dll` is a C++ DLL (45 056 bytes, 144 functions, the database has its full symbols, a large part of the code is STL). It has a single COM class, `CClient`, which connects to the named pipe `\\.\Pipe\BTAudioGateway`, sends the audio and speech recognition requests of its user, completes them with the answers of the service, and forwards the speech recognition requests of the hands-free device to the registered speech responders. When the service isn't there, it waits for it with the WNF state `WNF_BLTH_BLUETOOTH_AUDIO_GATEWAY_STATUS`.  
The server is [BTAGService.dll](./btagservice.md#pipe-btaudiogateway). It shares the `AsyncPipe` / `Synchronizer` code (`src\net\bluetooth\product\services\servicelib\`) with [BtConnectionManagerClient.dll](./btconnectionmanagerclient.md). No other binary extracted from the phone contains its CLSID or IIDs, so its users (speech / audio components) aren't known.

Location on the phone: `C:\Windows\System32\BTAudioGatewayClient.dll` ? (the extracted file has no notes).  
CLSID: `{EDFC5E7D-115E-4939-BFE9-59F275F2B230}`.  
Source folder: `src\net\bluetooth\product\services\hfp\client\`, `src\net\bluetooth\product\services\servicelib\` (strings).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion` |
| api-ms-win-core-namedpipe-l1-2-0 | `ConnectNamedPipe`, `SetNamedPipeHandleState` |
| api-ms-win-core-file-l1-2-1, api-ms-win-core-io-l1-1-1 | `CreateFileW`, `ReadFile`, `WriteFile`, `GetOverlappedResult` |
| api-ms-win-core-threadpool-l1-2-0 | `CreateThreadpoolWait`, `SetThreadpoolWait`, `CloseThreadpoolWait`, `CreateThreadpoolCleanupGroup`, `CloseThreadpoolCleanupGroup` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `Sleep`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-registry-l1-1-0 | `RegCreateKeyExW`, `RegSetValueExW`, `RegDeleteKeyExW`, `RegCloseKey` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-libraryloader-l1-2-0 | `DisableThreadLibraryCalls`, `GetModuleFileNameW` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-processthreads-l1-1-2 | `GetCurrentProcess`, `TerminateProcess`, `GetCurrentThreadId` |
| api-ms-win-core-errorhandling-l1-1-2 | `GetLastError`, `UnhandledExceptionFilter`, `SetUnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1 | `DebugBreak`, `IsDebuggerPresent` |
| api-ms-win-core-rtlsupport-l1-2-0 | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | C and C++ runtime (`malloc`, `free`, `operator new`/`delete`, `_CxxThrowException`, `__CxxFrameHandler3`, `_initterm`, `_vsnwprintf`, `memcpy`, …) |

The msvcrt, rtlsupport, and part of the debug, errorhandling and processthreads imports are the Visual C++ CRT startup, C++ exception and `/GS` security cookie code. `ConnectNamedPipe`, the threadpool cleanup group and `Sleep` come from the shared `AsyncPipe` / `Synchronizer` code; the server side of `AsyncPipe` isn't used here.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\\.\Pipe\BTAudioGateway` | `CreateFileW` ([Pipe connection](#pipe-connection)) | Protocol of [BTAGService.dll](./btagservice.md#pipe-btaudiogateway) |

No DLL is loaded at run time, and no process or COM server is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllRegisterServer` | 0x10004160 | none |
| 2 | `DllUnregisterServer` | 0x10004248 | none |
| 3 | `DllCanUnloadNow` | 0x10004034 | none |
| 4 | `DllGetClassObject` | 0x10004050 | `REFCLSID rclsid, REFIID riid, void **ppv` |

`DllGetClassObject` answers `CLASS_E_CLASSNOTAVAILABLE` (0x80040111) for any other CLSID, otherwise it creates a `CClientFactory` (8 bytes: vtable, reference count) and calls its `QueryInterface` (`IUnknown` or `IClassFactory`). `CClientFactory::CreateInstance` (0x10003598) refuses aggregation (`CLASS_E_NOAGGREGATION`), allocates a `CClient` (0x60 bytes) and calls `QueryInterface`. Each instance has its own pipe connection. `DllCanUnloadNow` returns `S_FALSE` while the module counter `g_lcModuleRef` (incremented by every `CClient`, `CClientFactory` and `LockServer(TRUE)`) isn't 0.

`DllRegisterServer` writes under `HKLM\SOFTWARE\Classes\CLSID\{EDFC5E7D-115E-4939-BFE9-59F275F2B230}`: the default value `Client interface to Bluetooth Audio Gateway`, then in `InProcServer32` the path of the DLL (`GetModuleFileNameW`) and `ThreadingModel` = `Both` (`CreateRegValue`, 0x10004438: `RegCreateKeyExW(KEY_ALL_ACCESS)`, `REG_SZ`). `DllUnregisterServer` deletes the two keys (`ERROR_FILE_NOT_FOUND` is ignored). Every error is a [fatal error](#etw).

### Startup

`_DllMainCRTStartup` (0x10005F44): CRT. `DllMain` (0x100040F4), on `DLL_PROCESS_ATTACH`: stores the module handle in `g_hModule`, calls `DisableThreadLibraryCalls` and sets `BtagClOutOfMemory` (0x100040C8, a fatal error "Out of Memory") as `new` handler. A reason above 3 is a fatal error. There is no ETW registration and no other initialisation.

### COM interfaces

| Interface | IID | Implemented by | Methods after `IUnknown` |
|-----------|-----|----------------|--------------------------|
| `IBTAGObserver` | `{E183DE5E-A27A-4B04-9A81-33F11F43E6CD}` | `CClient`+0x00, also the `IUnknown` | `RegisterCallback(IBTAGObserverCallback *, int *cookie)`, `UnregisterCallback(int cookie)`, `Shutdown()` |
| `IBTAGSpeechResponder` | `{3874742D-C567-47D4-A2BE-5D860D0AECD2}` | `CClient`+0x04 | `RegisterCallback(IBTAGSpeechResponderCallback *, int *cookie)`, `UnregisterCallback(int cookie)`, `Shutdown()` |
| `IBTAGController` | `{EE806DA3-0A90-4C6C-BEF2-C286E4DA7DCB}` | `CClient`+0x08 | `OpenAudioChannel(IBTAGCommandCallback *, void *context)`, `ReleaseAudioChannel(…)`, `StartSpeechRecognition(…)`, `StopSpeechRecognition(…)`, `Shutdown()` |
| `IAsyncPipeCallback` | not accepted by `QueryInterface` | `CClient`+0x0C | `IncomingMessage(const BYTE *, DWORD)`, `PipeBroken()` (internal, called by `AsyncPipe`) |

The callback interfaces are implemented by the user; their IIDs aren't in the binary. The methods called:

| Interface | Offset | Called when |
|-----------|--------|-------------|
| `IBTAGCommandCallback` | +0x0C | `(void *context, HRESULT hr)`: completion of a command ([Commands](#commands)) |
| `IBTAGSpeechResponderCallback` | +0x0C, +0x10 | Message -2 with byte 1 (start speech recognition) / byte 0 (stop) |
| `IBTAGObserverCallback` | +0x18 | At registration, before the callback is stored (no argument seen) |
| `IBTAGObserverCallback` | +0x0C | Message -3: `(BYTE, DWORD, DWORD)` |
| `IBTAGObserverCallback` | +0x10 | Message -4: `(BYTE)` |
| `IBTAGObserverCallback` | +0x14 | Message -5: `(DWORD, DWORD)` |

[BTAGService.dll](./btagservice.md#pipe-btaudiogateway) only sends the messages -1 and -2 (the four callers of `PipeClient::WritePipe` were checked), so the three observer notifications are never raised on this build, and their meaning is unknown.

### CClient

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Vtable `IBTAGObserver` |
| 0x04 | 4 | Vtable `IBTAGSpeechResponder` |
| 0x08 | 4 | Vtable `IBTAGController` |
| 0x0C | 4 | Vtable `IAsyncPipeCallback` |
| 0x10 | 4 | Vtable `SynchronizedObject` (`Dispatch`, 0x10002AC8) |
| 0x14 | 4 | `Synchronizer *` |
| 0x18 | 4 | Reference count, 1 at creation |
| 0x1C | 4 | Last id: cookies of the callbacks and request ids of the commands come from this one counter (`InterlockedIncrement`, first value 1) |
| 0x20 | 1 | Shut down |
| 0x24 | 4 | Manual-reset event, set at the end of the shutdown |
| 0x28 | 4 | `AsyncPipe *` (0x580 bytes) |
| 0x2C | 4 | WNF subscription |
| 0x30 | 0x10 | `CommandCallbackSet`: map request id → `CommandCallback *` |
| 0x40 | 0x10 | `ObserverSet`: map cookie → `IBTAGObserverCallback *` |
| 0x50 | 0x10 | `SpeechResponderSet`: map cookie → `IBTAGSpeechResponderCallback *` |

The constructor (0x1000227C) creates the event and the `AsyncPipe`, increments `g_lcModuleRef` and queues event 1 (connect).

Each `SynchronizedObject` (the `CClient` and its `AsyncPipe`) creates its own `Synchronizer` (0x3C bytes: reference count, critical section, running flag, deque of 20-byte records object / event / 3 arguments, running thread id). `Synchronizer::EnqueueEvent` (0x1000461C) runs the event at once on the calling thread when no event of this object is running, otherwise it queues it, and the running thread drains the queue. The DLL has no thread of its own: the calls on the callbacks come from the thread of a method call, of the threadpool waits of the pipe, or of the WNF notification.

Events of `CClient::Dispatch`:

| Event | Queued by | Action |
|-------|-----------|--------|
| 0 | `Shutdown` | `DispatchShutdown` |
| 1 | Constructor | `DispatchTryConnectPipe` |
| 2 | `WNFNotificationCallback` | `DispatchTryConnectPipe` if bit 0x01 of the WNF data is set |
| 3 | `IncomingMessage` | `DispatchIncomingMessage` (copy of the message) |
| 4 | `PipeBroken` | Closes the pipe (event 3 of `AsyncPipe`) and subscribes to the WNF state |
| 5 | The four `IBTAGController` commands | `DispatchSendCommand` |
| 6 | `RegisterCallback(IBTAGObserverCallback)` | Calls the callback at +0x18, then stores it in `ObserverSet` (unless shut down) |
| 7 | `UnregisterCallback` | `DispatchUnregisterCallback` |
| 8 | `RegisterCallback(IBTAGSpeechResponderCallback)` | `DispatchRegisterSpeechResponder` |

### Pipe connection

`DispatchTryConnectPipe` (0x10002D5C) does nothing if the pipe is already open. Otherwise `AsyncPipe::Connect` (0x10004E08):

1. `CreateFileW(L"\\\\.\\Pipe\\BTAudioGateway", GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, FILE_FLAG_OVERLAPPED | 0x10000, NULL)` (0x10000 is `SECURITY_IDENTIFICATION`, without `SECURITY_SQOS_PRESENT`). `ERROR_FILE_NOT_FOUND`, `ERROR_PIPE_BUSY` and `ERROR_ACCESS_DENIED` are returned as HRESULT, other errors are fatal.
2. `SetNamedPipeHandleState(PIPE_READMODE_MESSAGE)`; `ERROR_PIPE_NOT_CONNECTED` closes the handle and returns 0x800700E9.
3. Queues the start of the reads: `ReadFile` of up to 1200 bytes, overlapped, completed by a threadpool wait (`ReadCompletedStatic`, 0x10005360), then `IncomingMessage` and the next read. `ERROR_BROKEN_PIPE`, `ERROR_NO_DATA`, `ERROR_PIPE_NOT_CONNECTED` and `ERROR_CANCELLED` call `PipeBroken`, `ERROR_OPERATION_ABORTED` restarts the read; other errors are fatal.

If the connection fails, `WNFSubscribe` (0x10002D00) subscribes to `WNF_BLTH_BLUETOOTH_AUDIO_GATEWAY_STATUS` (if not already done) with `WNFNotificationCallback` (0x10002CB4), which checks the state name and queues event 2 with the first DWORD of the data. The service sets bit 0x01 when it runs, which triggers a new attempt. If the connection succeeds and speech responders are registered, the client sends message 2 with byte 1 again. The writes are queued and sent one by one (`WriteFile`, overlapped).

A broken pipe closes the handle and subscribes to the WNF state again; the pending commands are not completed until the next answer or the destruction.

### Commands

`OpenAudioChannel` (0x1000285C), `ReleaseAudioChannel` (0x100028F8), `StartSpeechRecognition` (0x10002994) and `StopSpeechRecognition` (0x10002A2C) take a new request id, build the 12-byte message below and a `CommandCallback` (12 bytes: +0 request id, +4 `IBTAGCommandCallback *` (AddRef'd, may be NULL), +8 context), queue event 5 and return `S_OK` at once.

| Method | Type | Byte at +8 |
|--------|------|------------|
| `StartSpeechRecognition` | 1 | 1 |
| `StopSpeechRecognition` | 1 | 0 |
| `OpenAudioChannel` | 3 | 1 |
| `ReleaseAudioChannel` | 3 | 0 |

`DispatchSendCommand` (0x10002FF8) completes the callback at once with 0x8007139F (`ERROR_INVALID_STATE`) after a shutdown, or 0x80070015 (`ERROR_NOT_READY`) when the pipe isn't open. Otherwise it stores the `CommandCallback` in `CommandCallbackSet` and writes the message. The answer -1 with the same request id calls `IBTAGCommandCallback` +0x0C with the context and the HRESULT of the service, then releases the callback (`CommandCallbackSet::ProcessResponse`, 0x100037AC). The `CommandCallbackSet` destructor completes the remaining commands with 0x8007139F.

The service answers type 1 by opening (after a delay) or closing the SCO audio for a voice command, type 3 by opening or closing it, and completes them when SCO reaches the requested state ([BTAGService](./btagservice.md#pipe-btaudiogateway)).

### Callbacks

`RegisterCallback` returns a new cookie in `*cookie`, AddRefs the callback and queues event 6 or 8; after a shutdown it returns 0x8007139F and cookie 0.

`DispatchRegisterSpeechResponder` (0x100027B0) stores the callback, and if it's the first speech responder sends message 2 with byte 1 (the client becomes a speech responder of the service).

`DispatchUnregisterCallback` (0x10002670) removes the cookie from `ObserverSet` and from `SpeechResponderSet` (releasing the callback), and sends message 2 with byte 0 when no speech responder is left. This message is also sent when the cookie was an observer's.

### Pipe messages

All the messages start with a DWORD type (`BTAG_MESSAGE_TYPE`).

Messages sent:

| Type | Size | Fields |
|------|------|--------|
| 1 | 12 | +4 request id, +8 byte: start (1) / stop (0) speech recognition |
| 2 | 8 | +4 byte: register (1) / unregister (0) as speech responder |
| 3 | 12 | +4 request id, +8 byte: open (1) / release (0) audio channel |

Messages received (`DispatchIncomingMessage`, 0x10002E28):

| Type | Fields | Action |
|------|--------|--------|
| -1 | +4 request id, +8 HRESULT | Completion of a command |
| -2 | +4 byte | Every speech responder: +0x0C (byte 1) or +0x10 (byte 0) |
| -3 | +4 byte, +8 DWORD, +0xC DWORD | Every observer: +0x0C |
| -4 | +4 byte | Every observer: +0x10 |
| -5 | +4 DWORD, +8 DWORD | Every observer: +0x14 |

Any other type is a fatal error "Unknown BTAG_MESSAGE_TYPE". The sizes of the received messages aren't checked.

### Shutdown

`Shutdown` (0x10002BD0, the same method in the three interfaces) queues event 0 unless already shut down, then waits for the event at +0x24 without timeout. `DispatchShutdown` (0x10002C2C) unsubscribes the WNF state (`RtlUnsubscribeWnfNotificationWaitForCompletion`), releases the speech responders, closes and releases the pipe, sets the event and the shut down flag. The observers and the pending commands are only released by the destructor (0x1000244C).

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x0992022FA3BC1075 `WNF_BLTH_BLUETOOTH_AUDIO_GATEWAY_STATUS` (`.text:0x1000113C`) | `BLTH`, 2 | 4 bytes: [status bits of BTAGService](./btagservice.md#wnf-states) | Subscribed while the pipe can't be opened; bit 0x01 (service running) triggers a connection |

Version 1, well-known, system scope, not permanent. The symbolic name comes from the binary.

### ETW

The DLL registers no provider of its own. `__FatalError` (0x100033B4), called on every unexpected failure with the source file, line, function name and error, registers the provider `{3BBAB918-1710-4768-82B6-A2DC58D3D1EA}` (`Microsoft-WindowsPhone-Net-Debug`), writes `NET_FATAL_ERROR` (event 100, version 0, level 2, opcode 0, task 1, keyword 0x1) and unregisters it. Then `TerminateProcess(GetCurrentProcess(), 3)` if the test hook variable is set, `DebugBreak` under a debugger (or when the kernel debugger flags of `SharedUserData`+0x2D4 are set), otherwise `__fastfail(7)`.
