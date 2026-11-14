## ncsdsvc.exe

Nokia Care Suite daemon service (service `ncsd`): the USB endpoint of the JSON-RPC channel that the PC care / recovery tools use to talk to the phone.  
`ncsdsvc.exe` is a small Win32 service (31 112 bytes, 152 functions, most of them CRT and `std::string` code). It doesn't understand the protocol: it opens the NCSd USB function interface of [genericusbfnclass.sys](../drivers/genericusbfnclass.md#ncsd-instance), reads one request per bulk OUT transfer, hands it as a string to [Ncsd.dll](../libraries/ncsd.md) and writes the JSON response back on the bulk IN pipe. All the methods (phone identity, NV items, EFS files, security mode, reboot to flash mode, factory reset…) are in [Ncsd.dll](../libraries/ncsd.md#methods).  
PDB: `E:\build_e\subtask\9BE7887C_98\output\ncsd\fre\ncsdsvc.pdb` (same build tree as Ncsd.dll).

Location on the phone: ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-service-core-l1-1-1.dll | `StartServiceCtrlDispatcherW`, `SetServiceStatus` |
| api-ms-win-service-winsvc-l1-2-0.dll | `RegisterServiceCtrlHandlerW` |
| api-ms-win-core-libraryloader-l1-1-1.dll | `LoadLibraryExW`, `FreeLibrary`, `GetProcAddress` |
| api-ms-win-core-file-l1-2-0.dll | `CreateFileW` |
| api-ms-win-core-io-l1-1-1.dll | `DeviceIoControl` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-1.dll | `ResumeThread`, `TerminateThread`, `SetThreadPriority`, `GetCurrentThreadId` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| MSVCR110.dll | `_beginthreadex`, `strcmp`, `strlen`, `memcpy`, `memset`, `memmove`, `operator new` / `delete`, C++ exceptions, CRT startup (`__getmainargs`, `_initterm`, `exit`…) |
| MSVCP110.dll | `std::_Xlength_error`, `std::_Xout_of_range`, `std::_Xbad_alloc`, `std::_Winerror_map`, `std::_Syserror_map`, `std::locale::id` |
| api-ms-win-core-util-l1-1-0.dll, profile, sysinfo | `EncodePointer`, `DecodePointer`, `QueryPerformanceCounter`, `GetSystemTimeAsFileTime`, `GetTickCount64` |

The util, profile and sysinfo imports, `GetCurrentThreadId` and most of MSVCR110 / MSVCP110 are the Visual C++ CRT startup, `/GS` security cookie and `std::string` / `std::error_category` code. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [Ncsd.dll](../libraries/ncsd.md) | `LoadLibraryExW(L"Ncsd.dll", NULL, 0)`, `GetProcAddress("Ncsd2_CreateInstance")` / `GetProcAddress("Ncsd2_DeleteInstance")`, then vtable slot +0xFC (`ProcessRequest`) of the returned object | JSON-RPC request handler, see [Ncsd.dll](#ncsddll) |
| `\\.\GenericUsbFn_{7eaff726-34cc-4204-b09d-f95471b873cf}` ([genericusbfnclass.sys](../drivers/genericusbfnclass.md#ncsd-instance)) | `CreateFileW`, opened twice, IOCTLs 0x22C022, 0x22C02C, 0x22C036, 0x22C016, 0x22C00D | The NCSd USB function interface (two bulk pipes), see [USB interface](#usb-interface) |

No other file, process, COM server or registry value is used.

### Parameters

`main` (`sub_401798`) parses `argv` with `strcmp`; the last argument wins.

| Command line | Usage | Exit code |
|---|---|---|
| `ncsdsvc.exe` or `ncsdsvc.exe -s` | Service mode (default): `StartServiceCtrlDispatcherW` with one entry `{L"ncsd", ServiceMain}` (`sub_4016C8`), see [Service](#service) | 0 when the dispatcher returns normally, −2 when `StartServiceCtrlDispatcherW` fails (e.g. not started by the SCM) |
| `ncsdsvc.exe -n` | Console mode: runs the [main loop](#main-loop) (`sub_401A24`) directly, without the SCM | −1 |
| any other argument | Nothing is done | −1 |

`main` also zeroes a 68-byte `STARTUPINFOW` and a 16-byte `PROCESS_INFORMATION` that are never used (`ServiceMain` does the same), leftovers of a removed `CreateProcess` ?

The service is installed by the Nokia packages (not by this binary: there's no `CreateService`); the service key wasn't looked at.

### Service

`ServiceMain` (`sub_4016C8`) fills the global `SERVICE_STATUS` (`dword_40623C`): `dwServiceType` = 0x30 (`SERVICE_WIN32_OWN_PROCESS | SERVICE_WIN32_SHARE_PROCESS`), `dwCurrentState` = `SERVICE_START_PENDING`, `dwWaitHint` = 5000. Then:

1. `RegisterServiceCtrlHandlerW(L"ncsd", Handler)` (`sub_401670`). Failure → returns at once.
2. `SetServiceStatus`: `SERVICE_RUNNING`, `dwControlsAccepted` = `SERVICE_ACCEPT_STOP`.
3. Runs the [main loop](#main-loop) in the service thread.
4. When the loop returns: `SetServiceStatus` `SERVICE_STOPPED`, exit code 0.

`Handler` (`sub_401670`): `SERVICE_CONTROL_STOP` (1) or `SERVICE_CONTROL_SHUTDOWN` (5) → `SERVICE_STOP_PENDING` and sets the stop flag `byte_40625C`; every control ends with `SetServiceStatus`. The flag is only checked at the top of the main loop, which blocks in `WaitForSingleObject(INFINITE)` and in a synchronous `TRANSFER_OUT`, so the stop is seen only after the next request or attach ?

### Main loop

`sub_401A24` (16 KB buffer on the stack, `__security_push_cookie`):

1. Creates the "configured" event `dword_406014`: `CreateEventW(NULL, bManualReset = TRUE, bInitialState = FALSE, NULL)`.
2. Builds the USB object (`sub_402680`, [layout](#usb-object)) and registers the bus callback `sub_40189C` (`sub_402B78`). The callback sets `dword_406258` = 1 and `SetEvent` on configuration, or `dword_406258` = 0 and `ResetEvent` on detach.
3. Opens the interface (`sub_402738`, see [USB interface](#usb-interface)). Failure → the loop returns at once (the service then reports `SERVICE_STOPPED`).
4. Loop, while the stop flag is clear:
   1. If detached (`dword_406258` = 0): deletes the `CNcsd` object and frees Ncsd.dll (`sub_4018EC`: `GetProcAddress("Ncsd2_DeleteInstance")`, call, `FreeLibrary`). So each USB session gets a fresh object.
   2. Reads a request (`sub_4019E0`): `WaitForSingleObject(event, INFINITE)`, then [IOCTL 0x22C016](#ioctl-0x22c016--ioctl_genericusbfn_transfer_out) on the OUT pipe into the 0x4000-byte buffer. Nothing read (or IOCTL failure) → `Sleep(100)` and retry.
   3. A request whose first byte is `-` sets the stop flag and ends the loop (a way for the PC to stop the service).
   4. Loads Ncsd.dll and creates the object if needed (`sub_401954`, see [Ncsd.dll](#ncsddll)). If that fails, it writes the constant answer `{"error":{"code":-4294966182,"message":"Unable to load libraries"},"id":0,"jsonrpc":"2.0"}` with [IOCTL 0x22C00D](#ioctl-0x22c00d--ioctl_genericusbfn_transfer_in) and loops.
   5. Builds a `std::string` from the buffer (up to the first NUL, so the request must be NUL-terminated within the 16 KB, i.e. at most 16 383 characters ?) and calls `ProcessRequest(request, &response)`, vtable +0xFC of the `CNcsd` object ([Ncsd.dll](../libraries/ncsd.md#processrequest-sub_1000d974-vtable-0xfc)).
   6. A response longer than 0x4000 bytes ends the loop (and so the service). Otherwise it's copied into the buffer and written on the IN pipe with [IOCTL 0x22C00D](#ioctl-0x22c00d--ioctl_genericusbfn_transfer_in), length = string length (no NUL). The result of the write isn't checked. The buffer is cleared before and after.
5. Cleanup: closes the interface (`sub_4028F4`), `CloseHandle` on the event, deletes the object and frees the DLL.

One bulk transfer is therefore one JSON-RPC message, at most 16 KB each way; there's no framing, length header or fragmentation.

### Ncsd.dll

`sub_401954`, called before each request while the DLL isn't loaded: `LoadLibraryExW(L"Ncsd.dll", NULL, 0)`, `GetProcAddress(h, "Ncsd2_CreateInstance")` and calls it (no parameter, returns the `CNcsd *`). If the export is missing, `FreeLibrary`. The DLL handle and the object pointer are locals of the main loop.  
`sub_4018EC`: `GetProcAddress(h, "Ncsd2_DeleteInstance")`, calls it with the object, `FreeLibrary`.  
See [Ncsd.dll exports](../libraries/ncsd.md#exports).

### USB interface

`sub_402738` (USB object `this`):

1. `CreateFileW(L"\\\\.\\GenericUsbFn_{7eaff726-34cc-4204-b09d-f95471b873cf}", GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL)` → handle +0x00 (transfers). The same call again → handle +0x04 (bus events). Synchronous handles.
2. [IOCTL 0x22C022](#ioctl-0x22c022--ioctl_genericusbfn_get_class_info) on handle +0x00, 552-byte output. In the **high-speed** interface (offset 0xC4) it walks `PipeArr[1]` … `PipeArr[PipeCount−1]` (`PipeArr[0]` is EP0, see [usbfnclx.sys](../drivers/usbfnclx.md)): `bEndpointAddress` with bit 0x80 → its `PipeId` is the IN pipe (+0x28), otherwise the OUT pipe (+0x24). With the [NCSd interface descriptor](../drivers/genericusbfnclass.md#ncsd-instance) these are endpoints 0x81 (IN) and 0x02 (OUT). The full-speed interface isn't used.
3. [IOCTL 0x22C02C](#ioctl-0x22c02c--ioctl_genericusbfn_activate_usb_bus) on handle +0x00.
4. Starts the bus event thread (`sub_402C04`: `_beginthreadex` suspended, `SetThreadPriority(THREAD_PRIORITY_NORMAL)`, `ResumeThread`; thread `sub_402D84` → `sub_402A94`), then `Sleep(500)`.

Any failure returns −1 (handles already opened stay open until the cleanup).

Bus event thread (`sub_402A94`), while its run flag (+0x18) is set: [IOCTL 0x22C036](#ioctl-0x22c036--ioctl_genericusbfn_bus_event_notification) on handle +0x04 (blocking). On `UsbfnEventConfigured` (7) when not yet configured → callback(1), configured = 1; on `UsbfnEventDetach` (3) when configured → callback(0), configured = 0. Other events (attach, reset, suspend…) are ignored, as are IOCTL failures (it just loops).

Close (`sub_4028F4`): `CloseHandle` of handle +0x00, then stops the thread (`sub_402CC8`: clears the run flag, priority 15, waits 3 s, else `TerminateThread(…, 31)`), then `CloseHandle` of handle +0x04.

#### USB object

Built on the stack of the main loop by `sub_402680`.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Interface handle for the transfers, class info and bus activation (−1 = closed) |
| 0x04 | 4 | Interface handle for the bus event notifications (−1 = closed) |
| 0x08 | 4 | Thread parameter: USB object |
| 0x0C | 4 | Thread routine `sub_402A94` |
| 0x10 | 4 | Thread handle |
| 0x14 | 4 | Thread id |
| 0x18 | 1 | Thread run flag |
| 0x1C | 4 | Bus callback (`sub_40189C`) |
| 0x20 | 1 | Configured flag of the thread |
| 0x24 | 4 | `PipeId` of the bulk OUT pipe (requests) |
| 0x28 | 4 | `PipeId` of the bulk IN pipe (responses) |

### IOCTLs sent

All go to `\\.\GenericUsbFn_{7eaff726-34cc-4204-b09d-f95471b873cf}` and are forwarded unchanged by [genericusbfnclass.sys](../drivers/genericusbfnclass.md#ioctl-forwarding) to [usbfnclx.sys](../drivers/usbfnclx.md) as the internal IOCTL with the same function number. They are sent synchronously (no `OVERLAPPED`).

#### IOCTL 0x22C022 — IOCTL_GENERICUSBFN_GET_CLASS_INFO

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x8 |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| InputBuffer size | OutputBuffer size |
|------------------|-------------------|
| 0 | 552 (0x228) |

Outputbuffer: [USBFN_CLASS_INFORMATION_PACKET](../drivers/genericusbfnclass.md#usbfn_class_information_packet) without `SuperSpeedClassInterface`. Only the high-speed `PipeCount` and `PipeArr` are read. Failure → the interface isn't opened and the service stops.

#### IOCTL 0x22C02C — IOCTL_GENERICUSBFN_ACTIVATE_USB_BUS

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xB |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

No buffers. Failure → the service stops. `IOCTL_GENERICUSBFN_DEACTIVATE_USB_BUS` is never sent: the bus is released by closing the handles.

#### IOCTL 0x22C036 — IOCTL_GENERICUSBFN_BUS_EVENT_NOTIFICATION

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0xD |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| InputBuffer size | OutputBuffer size |
|------------------|-------------------|
| 4 | 12 |

Inputbuffer: DWORD 2 (meaning ?; the public IOCTL has no input buffer, and [IpOverUsb.dll](../libraries/ipoverusb.md) sends none).  
Outputbuffer: `USBFN_NOTIFICATION`; only the first DWORD (`USBFN_EVENT`) is read: 7 Configured, 3 Detach.

#### IOCTL 0x22C016 — IOCTL_GENERICUSBFN_TRANSFER_OUT

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x5 |
| Access | READ_AND_WRITE |
| Method | METHOD_OUT_DIRECT |

| InputBuffer size | OutputBuffer size |
|------------------|-------------------|
| 4 | 16384 (0x4000) |

Inputbuffer: `PipeId` of the bulk OUT pipe (USB object +0x24).  
Outputbuffer: the JSON-RPC request; the returned byte count is its length (0 → retry after 100 ms).

#### IOCTL 0x22C00D — IOCTL_GENERICUSBFN_TRANSFER_IN

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x3 |
| Access | READ_AND_WRITE |
| Method | METHOD_IN_DIRECT |

| InputBuffer size | OutputBuffer size |
|------------------|-------------------|
| 4 | response length (≤ 16384) |

Inputbuffer: `PipeId` of the bulk IN pipe (USB object +0x28).  
Outputbuffer (data sent to the host): the JSON-RPC response, without terminating NUL. No zero-length packet is appended (`TRANSFER_IN_APPEND_ZERO_PKT` isn't used), so the PC side presumably reads with a buffer larger than the response ?

### Named objects

| Object | Comment |
|--------|---------|
| Event `dword_406014` (unnamed, manual reset) | Set while the USB function is configured by the host; the main loop waits on it before each read |
| Service `ncsd` | Name passed to `StartServiceCtrlDispatcherW` and `RegisterServiceCtrlHandlerW` |
