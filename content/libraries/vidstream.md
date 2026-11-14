## VidStream.dll

USB video stream service: the phone-side sender of the WP8.1 screen projection over USB ("Project My Screen").  
The compositor ([CompServer.dll](./compserver.md#display-topology)) loads it and calls its only export `CreateUsbVidStreamService`; the returned service object receives the composed frames (`displayTopologyMirrorOverUsb`) and sends them to the PC through `\\.\UfnVidStream` ([Ufnvidstream.sys](../drivers/ufnvidstream.md)). A thread follows the state of the driver: when the PC asks for the projection (state 6) it shows a confirmation dialog (`Shl::ActionDialog`, strings of `MirrorUXres.dll`) and, once accepted, switches the display topology to USB mirroring with [CompClient.dll](./compclient.md#display-topology)`!SetDisplayTopology`. It optionally converts the frames from 32 to 16 bits per pixel (NEON), sends them with their orientation, and injects the touch / hardware button [input messages](../drivers/ufnvidstream.md#input-message) of the PC viewer into the phone with a statically linked copy of the input injection client of [InputInjection.dll](./inputinjection.md) (CoreMessaging endpoint `IRemoteInputInjectionApi`).  
The only documented user is [CompServer.dll](./compserver.md#display-topology) (`TopologyManager::InitializeVidStreamService`, `CreateUsbVidStreamService(k_cQueueSize = 3, displayWidth, displayHeight, &m_pVidStreamSvc)`); its `VidStream` frame listener renders the snapshots and submits them, see [Compositor side](#compositor-side). The settings page [MirrorUX.dll](./mirrorux.md#usb-agent) only watches the same driver state. PDB: `vidstream.pdb`.

Location on the phone: `C:\Windows\System32\VidStream.dll` (path loaded by CompServer.dll).  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-core-file-l1-2-1 | `CreateFileW` |
| api-ms-win-core-io-l1-1-1 | `DeviceIoControl`, `GetOverlappedResult`, `CancelIoEx` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegQueryValueExW`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `LoadStringW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep`, `InitializeCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection`, `DeleteCriticalSection` |
| api-ms-win-core-kernel32-legacy-l1-1-1 | `WaitForMultipleObjects` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateThread`, `TerminateThread`, `GetCurrentThread`, `GetThreadPriority`, `SetThreadPriority`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-sysinfo-l1-2-2 | `GetTickCount` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2 | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-debug-l1-1-1 | `DebugBreak` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-rtlsupport-l1-2-0 | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| CompClient | `SetDisplayTopology` |
| ShellChromeAPI | `Shl::ActionDialog::Create` (`ACTION_DIALOG_PARTIAL_SCREEN_CONFIG` overload) |
| CoreMessaging | `CoreUICreate` |
| CoreUIComponents | `CoreUIFactoryCreate` |
| msvcrt | `malloc`, `free`, `new`, `delete`, `new[]`, `delete[]`, `memcpy`, `memmove`, `memset`, `memcmp`, `wcslen`, `strlen`, `_initterm`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_amsg_exit`, `_XcptFilter`, `__C_specific_handler`, `__CxxFrameHandler3` |

`GetCurrentProcess`, `TerminateProcess`, the exception filter functions, `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind` and most of msvcrt are the CRT and `/GS` boilerplate (`__report_gsfailure`, DLL startup).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\\.\UfnVidStream` ([Ufnvidstream.sys](../drivers/ufnvidstream.md)) | `CreateFileW(GENERIC_READ \| GENERIC_WRITE, share read/write, OPEN_EXISTING, FILE_FLAG_OVERLAPPED)` | USB projection device, see [IOCTLs](#ioctls) |
| `MirrorUXres.dll` | `LoadLibraryExW(…, LOAD_LIBRARY_AS_DATAFILE)` (`sub_10004EA4`, loaded once) then `LoadStringW` | Strings 132-135 of the [confirmation dialog](#confirmation-dialog) (same resource DLL as [MirrorUX.dll](./mirrorux.md#string-ids)). Not available |
| Server of the CoreMessaging endpoint `IRemoteInputInjectionApi` | `CoreUIFactoryCreate`, interface `{9978C53C-56B6-4C55-BA5F-5495E889E2FE}` | Injects the PC input, see [Input injection](#input-injection); the hosting process isn't known |
| Server of `System\ActionDialogManagerEndpoint` | through [ShellChromeAPI.dll](./shellchromeapi.md#action-dialogs) `Shl::ActionDialog::Create` | Shows the confirmation dialog |
| Compositor ([CompServer.dll](./compserver.md#display-topology)) | [CompClient.dll](./compclient.md#display-topology) `SetDisplayTopology` (ALPC request 11) | Display topology 2 (`displayTopologyMirrorOverUsb`) when the projection is accepted |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `CreateUsbVidStreamService` | 0x10004D44 | `int bufferCount`, `int displayWidth`, `int displayHeight`, `IVidStreamService **service` (type name from the CompServer.dll PDB) |

### CreateUsbVidStreamService (0x10004D44)

1. `service` NULL → `E_POINTER`. Allocates the [service object](#service-object) (0x28 bytes, vtable `off_100018C0`), `E_OUTOFMEMORY` on failure.
2. Creates the [USB streamer](#usb-streamer) (`sub_10002FB8`, 0x258 bytes, vtable `off_10001740`) at +0x18.
3. `Initialize` (`sub_10004B48`):
   - stores the display size (+0x20, +0x24) and computes the capture size (`sub_10004760`, see below);
   - reads `HKLM\System\VidStream` `CaptureBpp` and `OutputBpp` (REG_DWORD, both default 16). A value present with another type or size → `E_UNEXPECTED`; the key may be missing. Both must be 16 or 32 with capture ≥ output (else `E_INVALIDARG`): conversion flag (+0x1C) = capture 32 and output 16; pixel code (+0x04) = 2 for a 32-bit capture, 1 for 16 bits;
   - creates the [frame pool](#frame-pool) with `bufferCount` buffers (`sub_10002948`), and the [converter](#converter) if the conversion flag is set (`sub_10001D94`, capture width must be a multiple of 4, else `E_NOTIMPL`);
   - calls the streamer's `Initialize` (vtable +0x00, `sub_100031DC`) with the pool, the output bpp, the display size and the capture size.
4. On success returns the object; on failure destroys it (`sub_10004828`).

Capture size (`sub_10004760`), the only resolutions the official PC viewer accepts (480×800, 480×854, 450×800):

| Display | Capture |
|---------|---------|
| 480×800 | 480×800 |
| 480×854 | 480×854 |
| 768×1280 | 480×800 |
| 540×960, 720×1280, 1080×1920, 1440×2560 | 450×800 |
| other | unchanged |

### Service object

0x28 bytes, vtable `off_100018C0`; the `IVidStreamService` given back to CompServer.dll. `SubmitSurface` is the real name (from an error string of CompServer.dll); the other names are descriptions:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | vtable `off_100018C0` |
| 0x04 | 4 | Pixel code: 1 = 16-bit capture, 2 = 32-bit capture |
| 0x08 | 4 | Capture width |
| 0x0C | 4 | Capture height |
| 0x10 | 4 | [Frame pool](#frame-pool) |
| 0x14 | 4 | [Converter](#converter) (only for 32 → 16 bits) |
| 0x18 | 4 | [USB streamer](#usb-streamer) |
| 0x1C | 1 | Conversion flag |
| 0x20 | 4 | Display width |
| 0x24 | 4 | Display height |

| Offset | Method | Function | Called by CompServer.dll |
|--------|--------|----------|--------------------------|
| +0x00 | `IsStreaming` | `sub_100048B4` → streamer +0x08 (`sub_100030E4`): streamer +0x254 ≠ 0 | `VidStream::OnFrameRenderStart`, `OnFrameRenderEnd`, `OnFramePresentCompleted`: no snapshot is rendered or submitted while it returns 0 |
| +0x04 | `GetCaptureFormat(DWORD out[3])` | `sub_100048C8`: copies +0x04, +0x08, +0x0C (pixel code, capture width, height) | `VidStream::UpdateOutputProfile`: pixel code 1 → DXGI format 0x55 (`DXGI_FORMAT_B5G6R5_UNORM`), 2 → 0x57 (`DXGI_FORMAT_B8G8R8A8_UNORM`), other → `E_NOTIMPL`; width / height = size of the snapshot |
| +0x08 | `SubmitSurface(const SURFACE_DESC *)` | `sub_10004910`, see [Frames](#frames) | `VidStream::OnFramePresentCompleted` |
| +0x0C | `GetLastReturnedSurface` | `sub_100048E0`: QWORD pool +0x58 (frame identifier of the last descriptor given back to the pool) | `VidStream::OnFrameRenderStart`: when it changes, unlocks and frees the snapshots up to that one |
| +0x10 | `Destroy` | `sub_10004AD0` → `sub_10004828`: releases the streamer, the converter and the pool, `EventUnregister` of the main provider, `delete` | not seen |
| +0x14 | `Stop` | `sub_10004B20` → streamer +0x14 (`sub_100031B0`): sets the stop event (+0x14) and waits for the "stopped" event (+0x18) | `VidStream::Uninitialize` (listener removed, topology left) |
| +0x18 | `Start` | `sub_10004B34` → streamer +0x10 (`sub_10003188`): [IOCTL 0x22C340](../drivers/ufnvidstream.md#ioctl-0x22c340) (format, requires state ≥ 5, else `E_UNEXPECTED`) and first input read, streaming flag +0x254 = 1; on failure calls `Stop` | `VidStream::OnInitialized` (listener registered) |
| +0x1C | `SetDisplaySize(width, height)` | `sub_10004CFC`: new capture size, streamer +0x04 (`sub_1000337C`: only if no frame is in the pool lists, else `E_INVALIDARG`; recomputes the format and sends IOCTL 0x22C340 again), then +0x20 / +0x24 | not seen |
| +0x20 / +0x24 | `GetDisplayWidth` / `GetDisplayHeight` | +0x20 / +0x24 | not seen |

### Startup

`DllEntryPoint` (`_DllMainCRTStartup`, 0x100067F8) → `dllmain_dispatch` (0x10006504) → `DllMain` (`sub_100045D4`): on `DLL_PROCESS_ATTACH`, `EventRegister` of the [main provider](#etw) and `DisableThreadLibraryCalls`; on detach, `EventUnregister`. A C++ initialiser (`sub_10001D68`) registers the second provider (the one of the input injection code).

### Frames

Surface descriptor (24 bytes, `surfDesc` in CompServer.dll) given to `SubmitSurface`:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 8 | Frame identifier: the first 8 bytes of the `COMPOSITOR_FRAME_DESC` of the snapshot. Not used here, copied to pool +0x58 when the buffer comes back (`GetLastReturnedSurface`) |
| 0x08 | 4 | Orientation (`VidStream::ComputeDisplayOrientation`, see [Compositor side](#compositor-side)), sent with [IOCTL 0x22C34C](../drivers/ufnvidstream.md#ioctl-0x22c34c) when it changes |
| 0x0C | 4 | `pBits`: pixels of the locked snapshot (must not be NULL, else `E_POINTER`) |
| 0x10 | 4 | `cbStride`: bytes per line returned by `LockBits` |
| 0x14 | 4 | 0 |

`SubmitSurface` (`sub_10004910`) takes a node from the free list of the pool and copies the descriptor into it. There's no check for an empty free list: the copy would go to a NULL pointer. CompServer.dll never has more than `k_cQueueSize` (3, the `bufferCount` it passed) snapshots in flight, so this doesn't happen. Then:
- without conversion: moves it to the ready list (`sub_10002B88`) and sets the "frame ready" event when the list was empty;
- with conversion: moves it to the converter queue and sets the converter event (`E_FAIL` if the pool has no converter).

The data isn't copied: the snapshot stays locked by the compositor until `GetLastReturnedSurface` reports its identifier (or a later one).

### Frame pool

`sub_10002948` (0x60 bytes, `bufferCount` nodes of 0x20 bytes = next pointer, 4 bytes, surface descriptor):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 0x18 | Critical section |
| 0x18 | 1 | Conversion flag |
| 0x1C / 0x20 | 8 | Free list (head, tail) |
| 0x24 / 0x28 | 8 | Submitted frames (no conversion) |
| 0x2C / 0x30 | 8 | Converter queue |
| 0x34 / 0x38 | 8 | Frames being converted |
| 0x3C / 0x40 | 8 | Ready list (to send) |
| 0x44 / 0x48 | 8 | Frames being sent |
| 0x4C | 4 | Converter event (auto-reset, only with conversion) |
| 0x50 | 4 | "Frame ready" event (auto-reset), waited by the [streamer thread](#streamer-thread) |
| 0x58 | 8 | First 8 bytes of the last descriptor given back (`sub_10002D20`) |

### Converter

`sub_10001D94` (24 bytes: pool, thread, result, stop event, capture width, capture height). Thread `sub_10001F74` → `sub_10001FC8` at priority 15 (`THREAD_PRIORITY_TIME_CRITICAL`): waits on the converter event and its stop event, takes the frames of the converter queue and converts each line in place from 32-bit pixels to RGB565 with NEON (4 pixels per step: R = bits 19-23, G = bits 10-15, B = bits 3-7), the 16-bit lines being packed one after the other (2 × width bytes per line). Bytes per line − 4 × width < 0 → `E_INVALIDARG`. Then the frame goes to the ready list.

With `CaptureBpp` = 32 the compositor renders its snapshot as `DXGI_FORMAT_B8G8R8A8_UNORM` (B in bits 0-7, G 8-15, R 16-23), so the result is a correct RGB565 image. With the default 16 the snapshot is already `DXGI_FORMAT_B5G6R5_UNORM` and the converter isn't used.

> [!NOTE]
> The descriptor isn't changed by the conversion: the streamer still sends height × the 32-bit `cbStride`, so with `CaptureBpp` = 32 / `OutputBpp` = 16 the driver computes a line pitch twice too large (?).

### USB streamer

`sub_10002FB8` (0x258 bytes, vtable `off_10001740`: +0x00 `Initialize` `sub_100031DC`, +0x04 `SetSize` `sub_1000337C`, +0x08 `IsStreaming` `sub_100030E4`, +0x0C `Destroy` `sub_10003124`, +0x10 `Start` `sub_10003188`, +0x14 `Stop` `sub_100031B0`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x04 | 4 | Frame pool |
| 0x08 / 0x0C | 8 | Streamer thread, its result |
| 0x10 | 4 | Quit event (manual reset) |
| 0x14 / 0x18 | 8 | Stop event, "stopped" event |
| 0x1C | 4 | Handle of `\\.\UfnVidStream` |
| 0x20-0x37 | 24 | Format of [IOCTL 0x22C340](../drivers/ufnvidstream.md#ioctl-0x22c340): 0x20 output bpp, 0x24 bytes per line = 0, 0x28/0x2A WORD display width/height, 0x2C/0x2E WORD capture width/height, 0x30 orientation = 0, 0x34 soft navigation bar flag = 0 |
| 0x38 | 4 | Image size = capture width × height × bpp / 8 (overflow → 0x80070216 `ERROR_ARITHMETIC_OVERFLOW`) |
| 0x3C / 0x40 | 8 | State known / new state (IOCTL 0x22C344) |
| 0x44 | 0x14 | `OVERLAPPED` of IOCTL 0x22C344, event 0x54 |
| 0x58 | 0x14 | `OVERLAPPED` of IOCTL 0x22C340, event 0x68 |
| 0x6C | 4 | `GetTickCount` when the state left 7 |
| 0x70, 0x8C | 2 × 28 | Two send slots: descriptor, `OVERLAPPED` (event at slot +0x14), BYTE done (+0x18) |
| 0xA8 / 0xAC | 8 | Next slot to fill / to complete |
| 0xB0 / 0xB4 | 8 | Orientation sent, IOCTL 0x22C34C pending |
| 0xB8 | 0x14 | `OVERLAPPED` of IOCTL 0x22C34C, event 0xC8 |
| 0xD0 | 192 | Input message buffer (IOCTL 0x22C354): 0xD4 type, 0xE8 event type, 0xEC contact count / button, 0xF0 contacts / pressed flag |
| 0x190 | 0x14 | `OVERLAPPED` of IOCTL 0x22C354, event 0x1A0 |
| 0x1A4 | 0xAC | [Input state](#input-injection): adapter, contacts, button held (WORD 0x24C, 16 = none) |
| 0x250 | 4 | Confirmation dialog (`Shl::ActionDialog`) |
| 0x254 | 4 | Streaming flag |

`Initialize` (`sub_100031DC`): checks the parameters (> 0, `E_INVALIDARG`), fills the format, creates the quit / stop / stopped events, opens `\\.\UfnVidStream`, connects the [input injection](#input-injection) (`sub_100023A4`) and starts the streamer thread (`sub_10003D50`). Any failure closes everything (`sub_1000345C`).

### Streamer thread

`sub_10003D50` → `sub_10003DA4`, priority 15. It creates its events, sends the first [IOCTL 0x22C344](../drivers/ufnvidstream.md#ioctl-0x22c344) (`sub_100036BC`, input = state known) and waits on up to 9 handles (timeout 1 s while a contact or a button is injected, otherwise infinite):

| Index | Handle | Action |
|-------|--------|--------|
| 0 | Quit event | Cleanup and end of the thread |
| 1 | Stop event | Cancels the transfers, gives back all frames, [IOCTL 0x22C3B8](../drivers/ufnvidstream.md#ioctl-0x22c3b8) (stop, `sub_10004210`), releases the injected input, streaming flag = 0, sets the "stopped" event |
| 2 | State IOCTL done | [State change](#state-change), then IOCTL 0x22C344 again |
| 3 | Format IOCTL done | Continues if it succeeded with 0 bytes, else reset |
| 4 | Event of the slot to complete | Marks the slot done, gives the frames back to the pool (`sub_10003CC4` → `sub_10002D20`), sends the next frame |
| 5 | "Frame ready" of the pool | Sends the next frame (`sub_10003B20`) |
| 6 | Orientation IOCTL done | Allows the next orientation change |
| 7 | Input IOCTL done | [Input message](#input-injection), then [IOCTL 0x22C354](../drivers/ufnvidstream.md#ioctl-0x22c354) again (`sub_10003738`, output 192 bytes) |
| 8 | Event of the confirmation dialog (only while one is shown) | [Dialog result](#confirmation-dialog) |
| timeout | | Releases the injected input (contacts and button) |

Any error: cancels all the I/O (`CancelIoEx` + `GetOverlappedResult` for each `OVERLAPPED`), gives back the frames, releases the input, `Sleep(1000)` and restarts with IOCTL 0x22C344.

Sending a frame (`sub_10003B20`): if the current slot is free, takes a frame from the ready list (`sub_10002C70`); a frame without pixels is given back at once. If its orientation (+0x08) differs from the last one sent and no orientation IOCTL is pending, sends [IOCTL 0x22C34C](../drivers/ufnvidstream.md#ioctl-0x22c34c) with it. Then [IOCTL 0x22C349](../drivers/ufnvidstream.md#ioctl-0x22c349) (overlapped, METHOD_IN_DIRECT) with the pixels and a size of capture height × bytes per line (+0x10); the driver adds the 512-byte header. Two slots alternate, so up to two frames are in flight.

### State change

`sub_10003538` (completion of IOCTL 0x22C344, output must be 4 bytes and non-zero, else `E_UNEXPECTED`):
1. Leaving state 7 (streaming): notes `GetTickCount` (+0x6C), sends IOCTL 0x22C3B8, releases the injected input, streaming flag = 0.
2. Leaving state 6: closes the confirmation dialog still shown (dialog method +0x18, `Release`).
3. Entering state 6 (the PC sent `NOTIFY` / `FORCE`): reads `HKLM\SOFTWARE\Microsoft\Shell\RetailDemo\OobeWrite` `Enabled`. If it is non-zero (retail demo), or if the projection stopped less than 1 s ago (the PC restarting it), calls `SetDisplayTopology({2, 0})` directly; otherwise shows the [confirmation dialog](#confirmation-dialog).

The compositor then switches to topology 2, registers its `VidStream` frame listener and calls `Start`, which sends the format (state 6 → 7 in the driver), then `SubmitSurface` for every composed frame ([Compositor side](#compositor-side)).

### Confirmation dialog

`sub_100037B4`: closes a previous dialog, loads the strings 132 and 133 of `MirrorUXres.dll` into the first two strings of an `ACTION_DIALOG_PARTIAL_SCREEN_CONFIG` (title and text ?) and 134, 135 into its vector of buttons (2 items), then `Shl::ActionDialog::Create(importance 0, config, &dialog)` and dialog method +0x10 (show, returns the event waited by the thread). The dialog is kept at +0x250.  
When the event is signalled (`sub_100039D4`): dialog method +0x14 gives an 8-byte result; {0, 0} (first button ?) → `SetDisplayTopology({2, 0})` (`DISPLAY_TOPOLOGY_DESC` mode 2 `displayTopologyMirrorOverUsb`, orientation 0). The dialog is released in every case. Refusing does nothing: the driver stays in state 6.

### Input injection

The code of [InputInjection.dll](./inputinjection.md) (`InputInjectionAdapter`, `InputInjectionAdapterWorker`, `CQueue<InputInjectionMessage>`, same function names in the ETW errors) is linked in this DLL: `sub_100023A4` (`InputInjectionAdapter::Connect`) creates the adapter (20 bytes) and its worker (72 bytes, `sub_1000573C` → thread `sub_10005A1C`, `CoreUICreate`, `DeferInitCallback` `sub_10005B14` connects to `IRemoteInputInjectionApi` and gets `{9978C53C-56B6-4C55-BA5F-5495E889E2FE}`), with the same 0x220-byte [messages](./inputinjection.md#messages) and message processor (`sub_10005E38`). The streamer calls `PutButtonEvent` (`sub_10005224`, message 2) and `PutTouchEvent` (`sub_1000564C`, message 6) directly.

Input message received (192 bytes, type 3 at +0x04, else ignored):
- **Touch** (event type 0, `sub_1000255C`): the input state keeps the active contacts (up to 10, the 16-byte contacts of the [PC message](../drivers/ufnvidstream.md#input-message)). Contacts no longer present are first released (`sub_10002774`); then each contact of the message (state > 2 → 0) updates or adds an entry, and a [touch structure](#touch-structure) with all the changed contacts is injected. Contacts going back to hover after a contact (flags & 0xC = 0xC) trigger a second structure with the remaining contacts. State 0 removes the contact.
- **Button** (event type 1): releases the button held (`PutButtonEvent(4, button)`), then if pressed (+0x20 ≠ 0) maps the PC button 0 (Back) → 5, 1 (Windows) → 1, 2 (Search) → 6 and calls `PutButtonEvent(1, button)`. InputInjection's message processor turns 5 / 1 / 6 into `VK_ESCAPE` / `VK_F2` / `VK_F3` ([Buttons](./inputinjection.md#buttons)): Back = `VK_ESCAPE`, Start = `VK_F2`, Search = `VK_F3`.

Releasing everything (`sub_10002520`, on timeout, stop and errors): injects a structure with every contact in state 0 (`sub_10002704`) and `PutButtonEvent(4, button)` if one is held. Button flags: 1 = pressed, 4 = released.

#### Touch structure

Built by `sub_1000288C` / `sub_100028C4` and passed to `PutTouchEvent` (fills in the [structure](./inputinjection.md#touch-structure) of InputInjection.dll):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 2 | Size = 0x14 + 0x34 × count (72 for 1 contact) |
| 0x04 | 4 | `GetTickCount()` |
| 0x13 | 1 | Number of contacts (1-10) |
| 0x14 | 0x34 × n | Contacts |

Contact (52 bytes, zeroed):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 2 | Contact id (from the PC) |
| 0x02 | 2 | Flags, from (current state, previous state) of the PC contact: in contact after contact → 0x0A, new contact → 0x09, hover after contact → 0x0C, hover → 0x08, removed after contact → 0x1004, removed → 0x1000 (bits: 1 = down ?, 2 = update ?, 4 = up ?, 8 = in range ?, 0x1000 = ?) |
| 0x04 | 2 | X (phone screen pixels) |
| 0x06 | 2 | Y |

### Compositor side

Read in [CompServer.dll](./compserver.md#display-topology) (names from its PDB and error strings):
1. `TopologyManager::OnInitialized` → `InitializeVidStreamService` (0x10018018): `LoadLibraryW(L"C:\\Windows\\System32\\VidStream.dll")`, `GetProcAddress("CreateUsbVidStreamService")`, then `CreateUsbVidStreamService(k_cQueueSize = 3, display->GetWidth(), display->GetHeight(), &m_pVidStreamSvc)` (TopologyManager +0x48). The service is created at startup, even without a projection: the VidStream.dll streamer thread follows the driver state from then on.
2. When the topology becomes 2 (`displayTopologyMirrorOverUsb`, set by this DLL after the dialog), `InitializeMirrorUsb` (0x10026EA8) creates the frame listener `VidStream::Create(m_pVidStreamSvc, k_cQueueSize)` (0x48 bytes, 3 `SnapshotTracker`s of 72 bytes) and `RegisterFrameListener`. `VidStream::Initialize` calls `UpdateOutputProfile` (`GetCaptureFormat` → snapshot format and size).
3. `VidStream::OnInitialized` → `Start`; `OnUninitialized` / `Uninitialize` → `Stop`, then unlocks and frees all snapshots.
4. Each composed frame:
   - `OnFrameRenderStart`: compares `GetLastReturnedSurface` with the last value seen; when it changed, unlocks (buffer method +0x44) and frees the snapshots up to that identifier. If a snapshot is free, the service is streaming and the frame isn't flagged (`COMPOSITOR_FRAME_DESC` +0x48C bit 2), asks for a render (flag 8).
   - `OnFrameRenderEnd`: `SnapshotTracker::StartSnapshot` with the profile (format, capture width / height): the frame is rendered into the snapshot buffer, and the touch points are drawn on it with the `TouchPointRenderer` (see [Touch points](./compserver.md#touch-points)) if enabled.
   - `OnFramePresentCompleted`: if the service isn't streaming, the snapshot is dropped. Otherwise `AcquireSnapshotBuffer`, `LockBits(&surfDesc.pBits, &surfDesc.cbStride)` (buffer method +0x40), orientation = `ComputeDisplayOrientation(display, COMPOSITOR_FRAME_DESC +0x490 present rotation)`, then `m_pVidStreamSvc->SubmitSurface(&surfDesc)`.
   - `OnFramePresented` / `OnFrameAborted`: advance / reset the snapshot of that frame.

`ComputeDisplayOrientation` (0x10022BD8), from the present rotation and the panel shape (portrait if width ≤ height), gives the [orientation of IOCTL 0x22C34C](../drivers/ufnvidstream.md#ioctl-0x22c34c):

| Present rotation | Portrait panel | Landscape panel |
|------------------|----------------|-----------------|
| 1 | 1 | 2 |
| 2 | 2 | 4 |
| 3 | 4 | 8 |
| 4 | 8 | 1 |
| other | 0 (assertion) | 0 |

### IOCTLs

All on `\\.\UfnVidStream`, overlapped ([Ufnvidstream.sys](../drivers/ufnvidstream.md)):

| IOCTL | Function | Input | Output | Use |
|-------|----------|-------|--------|-----|
| [0x22C340](../drivers/ufnvidstream.md#ioctl-0x22c340) | `sub_10003AA4` | 24-byte format (streamer +0x20) | – | `Start` / `SetSize`: format, the driver goes to state 7 |
| [0x22C344](../drivers/ufnvidstream.md#ioctl-0x22c344) | `sub_100036BC` | 4: state known | 4: new state | Follows the state, always pending |
| [0x22C349](../drivers/ufnvidstream.md#ioctl-0x22c349) | `sub_10003B20` | Pixels, capture height × bytes per line | – | Frame |
| [0x22C34C](../drivers/ufnvidstream.md#ioctl-0x22c34c) | `sub_10003B20` | 4: orientation of the frame | – | On orientation change |
| [0x22C354](../drivers/ufnvidstream.md#ioctl-0x22c354) | `sub_10003738` | – | 192 | Input messages of the PC, always pending |
| [0x22C3B8](../drivers/ufnvidstream.md#ioctl-0x22c3b8) | `sub_10004210` | 24 (format, ignored by the driver) | – | Stop streaming (own event, waits for completion) |

The raw send IOCTLs 0x22C3AC / 0x22C3B5 aren't used.

### Registry

| Key | Value | Type | Use |
|-----|-------|------|-----|
| `HKLM\System\VidStream` | `CaptureBpp` | REG_DWORD, 16 (default) or 32 | Pixel format of the compositor snapshot: 16 → `DXGI_FORMAT_B5G6R5_UNORM`, 32 → `DXGI_FORMAT_B8G8R8A8_UNORM` (then converted) |
| `HKLM\System\VidStream` | `OutputBpp` | REG_DWORD, 16 (default) or 32 | Bits per pixel sent to the PC (format of IOCTL 0x22C340; the official PC viewer requires 16) |
| `HKLM\SOFTWARE\Microsoft\Shell\RetailDemo\OobeWrite` | `Enabled` | DWORD | ≠ 0: projection accepted without the confirmation dialog |

### ETW

Main provider `{E1B302DD-D9BF-4F31-924D-03186A527ABE}`, registered in `DllMain` (context `dword_10007288`, enable callback `ETW_EnableCallback` 0x10004640, enable bits `dword_10007280`). Mostly start / stop events of each function (opcode 1 = start, 2 = stop with the HRESULT):

| Events | Level | Task | Keyword | Enable bit | Written in |
|--------|-------|------|---------|------------|------------|
| 272, 273 | 4 | 17 | 0x12 | 0x2 | Pool creation |
| 288, 289 | 5 | 18 | 0x12 | 0x4 | `SubmitSurface` |
| 304, 305, 306 (level 2, opcode 11: descriptor not at the head of the list) | 5 | 19 | 0x12 | 0x4 / 0x8 | Frame to the ready list |
| 320, 321 | 5 | 20 | 0x12 | 0x4 | Frame taken for sending |
| 336, 337, 338 (level 2, opcode 11) | 5 | 21 | 0x12 | 0x4 / 0x8 | Frame given back |
| 368, 369 | 4 | 23 | 0x12 | 0x2 | Pool destruction |
| 384, 385, 386 (level 2, opcode 11) | 5 | 24 | 0x12 | 0x4 / 0x8 | Frame to the converter |
| 400, 401 | 5 | 25 | 0x12 | 0x4 | Converter dequeue |
| 528, 529 | 4 | 33 | 0x22 | 0x10 | `CreateUsbVidStreamService` |
| 544, 545 | 4 | 34 | 0x22 | 0x10 | `Destroy` |
| 560 (6 DWORDs), 561 | 4 | 35 | 0x22 | 0x10 | `Initialize`: parameters, result |
| 1040, 1041 / 1056, 1057 / 1072, 1073 | 4 | 65 / 66 / 67 | 0x42 | 0x20 | Converter creation / destruction / thread |
| 1074, 1075, 1076 (opcode 51, padding) | 5 | 68 | 0x42 | 0x40 | Conversion of a frame |
| 8208, 8209 / 8240, 8241 | 4 | 513 / 515 | 0x202 | 0x200 | Streamer creation / destruction |
| 8224 | 5 | 514 | 0x202 | 0x400 | `IsStreaming` |
| 8256 | 4 | 516 | 0x202 | 0x200 | Streamer thread |
| 8288 | 4 | 518 | 0x204 | 0x800 | State change (old, new) |
| 8290 | 1 | 518 | 0x201 | 0x1000 | IOCTL 0x22C344 failed |
| 8306, 8307 | 1 | 519 | 0x201 | 0x1000 | Frame / orientation IOCTL failed, frame transfer failed |
| 8336 | 1 | 521 | 0x201 | 0x1000 | Confirmation dialog |

Second provider `{ED07CE1C-CEE3-41E0-93E2-EEB312301848}` (the one of [InputInjection.dll](./inputinjection.md#etw), same events 5 and 916-919), registered by the C++ initialiser `sub_10001D68` (context `dword_10007310`, enable bits `dword_10007300` / `dword_10007304`).
