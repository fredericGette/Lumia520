## InputInjection.dll

Client library to inject hardware button, keyboard and touch events into the Windows Phone 8.1 input stack.  
`InputInjection.dll` is a small DLL (32 768 bytes, 82 functions, a third of them CRT and ETW boilerplate). It doesn't inject anything itself: `ApiInjectInitialize` starts a worker thread that opens a CoreMessaging context (`CoreUICreate`) and connects to the endpoint `L"IRemoteInputInjectionApi"` (`CoreUIFactoryCreate`), then every `ApiInject*` call is copied into a 0x220-byte message, queued, and forwarded by the worker thread to a method of the remote interface `{9978C53C-56B6-4C55-BA5F-5495E889E2FE}`. The process that implements the endpoint isn't known (no documented binary names it).  
It's imported by [qcremoteatsrvc8930.dll](./qcremoteatsrvc8930.md) (`AT+CKPD` and `AT+CTSA`), which uses `ApiInjectInitialize`, `ApiInjectUninitialize`, `ApiInjectButtonEvent` and `ApiInjectTouchEvent`. `ApiInjectEnableExclusive` isn't used by the documented binaries.

Location on the phone: `C:\Windows\System32\InputInjection.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| CoreMessaging | `CoreUICreate` |
| CoreUIComponents | `CoreUIFactoryCreate` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `InitializeCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateThread`, `GetCurrentThread`, `GetThreadPriority`, `SetThreadPriority`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-errorhandling-l1-1-2 | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1 | `DebugBreak` |
| api-ms-win-core-rtlsupport-l1-2-0 | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt | `malloc`, `free`, `operator new`/`delete` (`[]`), `memcpy`, `memset`, `memcmp`, `strlen`, CRT startup (`_initterm`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_amsg_exit`, `_XcptFilter`, `__C_specific_handler`) |

The msvcrt startup functions, rtlsupport, `GetCurrentProcess`/`TerminateProcess`, `SetUnhandledExceptionFilter`/`UnhandledExceptionFilter` and `Sleep` are the Visual C++ DLL CRT startup and `/GS` security cookie code. `DebugBreak` is called when a message can't be queued ([EnqueueMessage](#message-queue)).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| Server of the CoreMessaging endpoint `IRemoteInputInjectionApi` | `CoreUIFactoryCreate`, factory methods +0x0C / +0x14 ([worker thread](#worker-thread)) | Receives the injected events (interface `{9978C53C-56B6-4C55-BA5F-5495E889E2FE}`); the hosting process isn't known |

No DLL is loaded at run time and no process or COM server is started.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 3 | `ApiInjectInitialize` | 0x10001998 | none |
| 5 | `ApiInjectUninitialize` | 0x10001A8C | none |
| 2 | `ApiInjectEnableExclusive` | 0x10001B5C | `WORD flags` (one of the bits 0x7), `BYTE value` |
| 1 | `ApiInjectButtonEvent` | 0x10001BC8 | `DWORD flags` (bit 0x1 = down, 0x4 = up), `DWORD button` (< 16, see [buttons](#buttons)) |
| 4 | `ApiInjectTouchEvent` | 0x10001C30 | `const void *touch` ([touch structure](#touch-structure)) |

They all return an HRESULT. Except `ApiInjectInitialize`, they return 0x80070426 (`HRESULT_FROM_WIN32(ERROR_SERVICE_NOT_ACTIVE)`) when the library isn't initialised. A failure is traced with [ETW event 5](#etw).

Global object (pointer at 0x10004298, 20 bytes, created by `ApiInjectInitialize`, released by `ApiInjectUninitialize` and by an `atexit` handler, `sub_10003C04`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `off_100013C8` (`QueryInterface` `sub_100020C4`, `AddRef`, `Release`, destructor) |
| 0x04 | 4 | Reference count |
| 0x08 | 4 | Weak reference ? (cleared by `Release` when it points back to the object) |
| 0x0C | 4 | vtable `off_10001388`: local implementation of the interface `{9978C53C-56B6-4C55-BA5F-5495E889E2FE}` (`QueryInterface` returns this +0x0C for this IID), see [interface](#interface-9978c53c-56b6-4c55-ba5f-5495e889e2fe) |
| 0x10 | 4 | Worker object (`InputInjectionAdapterWorker`), see [below](#worker-object) |

The class names come from the ETW traces: `InputInjectionAdapter` (the global object), `InputInjectionAdapterWorker`, `CQueue<struct InputInjectionMessage>`, `RefCountedObject`.

### Startup

`DllEntryPoint` (0x1000388C): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then `dllmain_dispatch` (0x10003598, CRT init `sub_10003388`). `DllMain` (`unknown_libname_2`, 0x10003B74) only returns TRUE.  
The C++ initialisers (`_initterm`, 0x10001004…0x10001010) register the ETW provider (`sub_100018D8` → `McGenEventRegister`, `atexit` unregister) and the `atexit` handler that releases the global object (`sub_100018C4`). Everything else is done by `ApiInjectInitialize`.

### ApiInjectInitialize (0x10001998)

1. If the global object already exists: returns 0x80070420 (`HRESULT_FROM_WIN32(ERROR_SERVICE_ALREADY_RUNNING)`) and **releases the existing object** (the error path always clears the global pointer).
2. Creates the global object (`malloc(20)`); `E_OUTOFMEMORY` on failure.
3. `InputInjectionAdapter::Connect` (`sub_10001F8C`): `E_UNEXPECTED` if a worker exists; creates the 72-byte worker object (vtable `off_1000178C`) and starts it (`InputInjectionAdapterWorker::Start`, `sub_100026F4`):
   1. `CreateEventW(NULL, FALSE, FALSE, NULL)`: initialisation event (+0x0C).
   2. `CreateThread(…, ThreadProc, worker)` (`sub_10002A9C`, handle at +0x10). 0x8004131F if the thread already exists.
   3. `WaitForSingleObject(init event, 30000)`: returns the initialisation HRESULT stored by the thread (+0x14); 0x800705B4 (`HRESULT_FROM_WIN32(ERROR_TIMEOUT)`) after 30 s, `E_UNEXPECTED` if abandoned. On failure both handles are closed.
4. On any failure the global object is released and the error returned; otherwise `S_OK`.

### ApiInjectUninitialize (0x10001A8C)

`InputInjectionAdapter::Disconnect`: `E_UNEXPECTED` if there is no worker; otherwise `InputInjectionAdapterWorker::Stop` (`sub_10002884`) queues a message of type 7 ([messages](#messages)), waits for the end of the worker thread (`INFINITE`) and closes the event and the thread handles (`E_FAIL` if abandoned, `E_PENDING` 0x8000000A on timeout). Then the worker is released, and the global object is released in every case.

### ApiInjectEnableExclusive (0x10001B5C)

Calls method 3 of the local interface (`InputInjectionAdapter::EnableInputInjection`, `sub_10002148`) with its two parameters: 0x80070015 (`HRESULT_FROM_WIN32(ERROR_NOT_READY)`) without worker, `E_INVALIDARG` if `flags & 7` is 0, otherwise queues a message of type 1 {flags, value}. The meaning of the flags (exclusive injection for one input type ?) isn't known.

### ApiInjectButtonEvent (0x10001BC8)

`InputInjectionAdapter::PutButtonEvent` (`sub_100021DC`): 0x80070015 without worker, `E_INVALIDARG` if `flags & 5` is 0 or `button` ≥ 16, otherwise queues a message of type 2 {button, flags}. [qcremoteatsrvc8930.dll](./qcremoteatsrvc8930.md#keypad-thread-sub_1000139c) calls it with flags 1 (down) then 4 (up).

#### Buttons

The worker thread turns the button code into a virtual key and calls the remote method 4 with (flags, 0, virtual key):

| Button | Virtual key | Button of [qcremoteatsrvc8930.dll](./qcremoteatsrvc8930.md#ckpd-sub_1000108c) |
|--------|-------------|---------------|
| 0 | 0x7C (`VK_F13`) | `P` (power ?) |
| 1, 7 | 0x71 (`VK_F2`) | |
| 2 | 0x78 (`VK_F9`) | `U` (volume up ?) |
| 3 | 0x79 (`VK_F10`) | `D` (volume down ?) |
| 5 | 0x1B (`VK_ESCAPE`) | |
| 6 | 0x72 (`VK_F3`) | |
| 8 | 0x76 (`VK_F7`) | |
| 9 | 0x77 (`VK_F8`) | |
| 10 | 0x7A (`VK_F11`) | |
| 12 | 0x86 (`VK_F23`) | |
| 13 | 0x87 (`VK_F24`) | |
| 4, 11, 14, 15 | 0 | |

The physical buttons behind the codes aren't named in the binary (5 → `VK_ESCAPE` is probably Back ?).

### ApiInjectTouchEvent (0x10001C30)

`InputInjectionAdapter::PutTouchEvent` (`sub_10002604`): 0x80070015 without worker; `E_INVALIDARG` if the WORD at +0x00 (size) isn't in 0x48…0x21C, or if the byte at +0x13 isn't in 1…10; otherwise copies `size` bytes of the structure into a message of type 6.

#### Touch structure

Only these fields are checked by the DLL; the rest is passed unchanged to the remote method 6:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 2 | Size of the structure, 0x48 (72) to 0x21C (540) |
| 0x04 | 4 | Logged by ETW events 916 / 917 (time stamp ?, [qcremoteatsrvc8930.dll](./qcremoteatsrvc8930.md#touch-thread-sub_10001c34) puts `GetTickCount()` there) |
| 0x13 | 1 | 1 to 10 (number of contacts ?) |

With 0x14 bytes of header, 0x48 and 0x21C are exactly 1 and 10 contacts of 0x34 bytes (?).

> [!NOTE]
> [qcremoteatsrvc8930.dll](./qcremoteatsrvc8930.md#touch-thread-sub_10001c34) (`EmulateTouch`, `sub_10001638`) writes a DWORD 1 at +0x10 (`STR`, 4 bytes), so the byte at +0x13 is 0 and every `ApiInjectTouchEvent` call of that service fails here with `E_INVALIDARG` (0x80070057). Its 0x8C-byte structure was probably written for another version of this API (at least the count field has moved).

### Interface {9978C53C-56B6-4C55-BA5F-5495E889E2FE}

The same interface is implemented locally (vtable `off_10001388`, at +0x0C of the global object) and requested from the remote endpoint (`IRemoteInputInjectionApi`). Each local method validates its arguments and queues a message; the worker thread calls the remote method of the same index:

| Index | Local method | Parameters | Message |
|-------|--------------|------------|---------|
| 0…2 | `IUnknown` (adjustor thunks) | | |
| 3 | `EnableInputInjection` (`sub_10002148`) | `WORD flags` (& 7 ≠ 0), `BYTE` | 1 |
| 4 | `PutKeyboardEvent` (`sub_10002288`) | `WORD flags` (& 5 ≠ 0), `WORD` ?, `WORD` virtual key ? | 3 (2 for the buttons) |
| 5 | `PutKeyboardEvent` with text (`sub_10002348`) | `WORD flags` (& 5 ≠ 0), `WORD` ?, string reference | 4 (< 16 characters) or 5 |
| 6 | `PutTouchEvent` (`sub_100024E4`) | [touch structure](#touch-structure) passed by value | 6 |

Methods 4, 5 and 6 aren't reachable from the exports (they'd be used through `QueryInterface`, but nothing gives the object away). For method 4 the button path passes (flags, 0, virtual key), and ETW event 918 logs the first and the third parameter.  
The string reference of method 5 starts with a DWORD: bits 0…28 = length in characters (> 0), bits 29…31 = kind, 0x40000000 = characters inline at +8, 0x80000000 = pointer at +4 (any other kind executes `UDF`, a crash). The worker passes a reference {length | 0x80000000, pointer} to the remote method.

### Worker object

72 bytes, vtable `off_1000178C`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable |
| 0x04 | 4 | Reference count |
| 0x0C | 4 | Initialisation event |
| 0x10 | 4 | Worker thread handle |
| 0x14 | 4 | Initialisation HRESULT |
| 0x18 | 4 | CoreMessaging context (`CoreUICreate`) |
| 0x1C | 4 | Remote interface `{9978C53C-…}` |
| 0x20 | 0x18 | Critical section of the queue |
| 0x38 | 4 | Queue head |
| 0x3C | 4 | Queue tail |
| 0x40 | 4 | Number of queued messages |
| 0x44 | 4 | "Data ready" event (auto-reset) |

### Worker thread

`ThreadProc` (`sub_10002A9C`):
1. `CoreUICreate(&worker+0x18)`, then method +0x48 of the context (`sub_10002B94` deferred with the worker, value 3) and method +0x78 (message loop, until the stop message). On return the context and the worker are released.
2. `DeferInitCallback` (`sub_10002B94`), on the CoreMessaging thread: `CoreUIFactoryCreate(&factory)`; factory method +0x0C with the IID `{9978C53C-…}`; factory method +0x14 with `L"IRemoteInputInjectionApi"` and its result (connection to the endpoint); `QueryInterface({9978C53C-…})` of the object received → +0x1C. Then `InitializeCriticalSection` (+0x20), `CreateEventW(NULL, FALSE, FALSE, NULL)` (+0x44), and context method +0x8C registers `DataReadyEventCallback` (`sub_10002DA4`) on that event. The HRESULT is stored at +0x14 and the initialisation event set, which unblocks `ApiInjectInitialize`.
3. `DataReadyEventCallback`: checks that the signalled handle is the event +0x44 (otherwise writes 981 to address 0: deliberate crash), raises the thread priority to 15 (`THREAD_PRIORITY_TIME_CRITICAL`), runs the message processor (`sub_10002EB8`) and restores the priority.

The message processor dequeues the messages one by one (critical section held only while dequeuing) and calls the remote interface ([messages](#messages)); it stops at the first error. A message of an unknown type, or a type 4 / 5 message with a bad length, writes the source line number (0x508, 0x49F…) to address 0 (deliberate crash).

### Message queue

`InputInjectionAdapterWorker::EnqueueMessage` (`sub_1000294C`): type must be 1…7 (`E_INVALIDARG`), allocates a 0x228-byte node (next pointer, 4 bytes, then the 0x220-byte message), appends it to the list under the critical section and sets the event +0x44. On failure it calls `DebugBreak`.

#### Messages

0x220 bytes, type at +0x00:

| Type | Built by | Content | Done by the worker thread |
|------|----------|---------|---------------------------|
| 1 | `ApiInjectEnableExclusive` | +0x04 WORD flags, +0x06 BYTE | Remote method 3 (flags, byte) |
| 2 | `ApiInjectButtonEvent` | +0x04 button, +0x08 flags | Remote method 4 (flags, 0, [virtual key](#buttons)) |
| 3 | Method 4 | +0x04 flags, +0x06 WORD, +0x08 WORD (all 16 bits) | Remote method 4 (+0x04, +0x06, +0x08); ETW event 919 |
| 4 | Method 5, < 16 characters | +0x04 flags, +0x08 WORD, +0x0A length, +0x0C characters | Length must be 1…15 (else deliberate crash, like a length 0 in type 5); remote method 5 (flags, +0x08, {length \| 0x80000000, +0x0C}) |
| 5 | Method 5, ≥ 16 characters | +0x04 flags, +0x06 WORD, +0x08 length, +0x0C pointer to a `new[]` copy | Remote method 5 (flags, +0x06, {wcslen \| 0x80000000, pointer}), then `delete[]` of the copy |
| 6 | `ApiInjectTouchEvent`, method 6 | +0x04 [touch structure](#touch-structure) (0x21C bytes max.) | Remote method 6 with the structure by value; ETW event 917 |
| 7 | `ApiInjectUninitialize` | none | Releases the remote interface, empties the queue, `DeleteCriticalSection`, context method +0x94 (unregisters the event), `CloseHandle(event)`, context method +0x7C (ends the message loop) |

### ETW

Provider `{ED07CE1C-CEE3-41E0-93E2-EEB312301848}`, registered by a C++ initialiser (`McGenEventRegister`, context `unk_10004010`, enable callback `ETW_EnableCallback` 0x10001CB8, enable bits in `dword_10004280`).

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| 5 | 2 (error) | 0, 1 | 0x1 | `dword_10004280` 0x1 | Failed HRESULT: function name (ANSI, e.g. `"InputInjectionAdapter::PutTouchEvent"`), source line, HRESULT (`sub_100018F0`) |
| 916 | 4 (info) | 0, 910 | 0x100000000040 | `dword_10004284` 0x20000 | Method 6 called: touch +0x04 |
| 917 | 4 (info) | 0, 911 | 0x100000000040 | `dword_10004284` 0x20000 | Touch message sent to the remote interface: touch +0x04 |
| 918 | 4 (info) | 0, 909 | 0x100000000050 | `dword_10004284` 0x80000 | Method 4 called: flags, virtual key (2 × 16 bits) |
| 919 | 4 (info) | 0, 909 | 0x100000000050 | `dword_10004284` 0x80000 | Keyboard message sent: flags, virtual key |
