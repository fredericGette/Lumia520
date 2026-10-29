## qccium8930.dll

The Qualcomm QMI client library for user mode: the QCCI ("Qualcomm Common Client Interface") of the MSM8930, build `P:\QMI\rel\8.2.1\qcci\um\arm\Release_WP\qccium8930.pdb`, source file `qmi_cci_common.c`.  
It gives user-mode processes the standard QCCI API (`qmi_client_init`, `qmi_client_send_msg_sync`…) and the QMI IDL encoder / decoder (`qmi_idl_message_encode` / `_decode`), the same library the kernel drivers [qcamss8930.sys](../drivers/qcamss8930.md), [qcepmadc8930.sys](../drivers/qcepmadc8930.md), [qcltecoexmgr8930.sys](../drivers/qcltecoexmgr8930.md) and [qcmbb8930.sys](../drivers/qcmbb8930.md) have compiled in. A client is built from the IDL service object of a QMI service (generated code, in the caller); requests are C structures encoded into TLVs, sent with a 7-byte QMI header, and responses / indications are decoded back into C structures. There are two kinds of transport, registered when the DLL is loaded: the IPC router [qcipcrouter8930.sys](../drivers/qcipcrouter8930.md) (`\\.\IPC`) and six QMUX ports of [qcqmux8930.sys](../drivers/qcqmux8930.md) (`\\.\QMUX\QmuxDevice`). Each transport has its own reader threads that dispatch the received messages.  
It's imported by `QcShutdownSvc8930.exe` (`qmi_client_notifier_init`, `qmi_client_get_service_list`, `qmi_client_init`, `qmi_client_send_msg_sync`, `qmi_client_release`) and `qcfmminiport.dll` (`qmi_client_get_service_instance`, `qmi_client_init`, `qmi_client_send_msg_sync`, `qmi_client_message_decode`, `qmi_client_release`), not analysed. The stream-driver style exports `QCCI_Init`, `QCCI_Open`… do nothing.

Location on the phone: `C:\Windows\System32\qccium8930.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| MSVCR110 | `malloc`, `free`, `memset`, `memcpy`, `memcmp`, `strlen`, `sprintf_s`, `printf`, `setjmp`, `longjmp`, `_wassert`, CRT startup (`_initterm`, `_initterm_e`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_malloc_crt`, `_calloc_crt`, `_amsg_exit`, `__C_specific_handler`, `__CppXcptFilter`, `__clean_type_info_names_internal`) |
| api-ms-win-core-file-l1-2-0 | `CreateFileW`, `CreateFileA`, `ReadFile`, `WriteFile` |
| api-ms-win-core-io-l1-1-1 | `DeviceIoControl`, `GetOverlappedResult`, `CancelIoEx` |
| api-ms-win-core-synch-l1-2-0 | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `WaitForMultipleObjectsEx`, `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-processthreads-l1-1-1 | `CreateThread`, `GetCurrentThreadId` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-1 | `GetLastError` |
| api-ms-win-core-debug-l1-1-1 | `OutputDebugStringA` |
| api-ms-win-eventing-classicprovider-l1-1-0 | `RegisterTraceGuidsW`, `UnregisterTraceGuids`, `GetTraceLoggerHandle`, `GetTraceEnableLevel`, `GetTraceEnableFlags`, `TraceMessage` |
| api-ms-win-core-util-l1-1-0 | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0 | `QueryPerformanceCounter` |
| api-ms-win-core-sysinfo-l1-2-0 | `GetSystemTimeAsFileTime`, `GetTickCount64` |

The CRT startup functions, `EncodePointer`/`DecodePointer`, `GetSystemTimeAsFileTime`, `GetCurrentThreadId`, `GetTickCount64`, `QueryPerformanceCounter` (`/GS` cookie) are the Visual C++ 2012 DLL boilerplate. The classic-provider functions are the WPP tracing. `setjmp`/`longjmp` are the error handling of the IDL encoder / decoder.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `\\.\IPC` ([qcipcrouter8930.sys](../drivers/qcipcrouter8930.md)) | `CreateFileW` (overlapped), `ReadFile`, `WriteFile`, `DeviceIoControl` | [IPC router transport](#ipc-router-transport): one handle (= one router port) per client, plus a temporary one for each service lookup |
| `\\.\QMUX\QmuxDevice` ([qcqmux8930.sys](../drivers/qcqmux8930.md)) | `CreateFileA` (overlapped), `ReadFile`, `WriteFile`, `DeviceIoControl` | [QMUX transport](#qmux-transport): one handle per client, plus a temporary one for each service lookup |

There is no `LoadLibrary`, no registry access and no other file.

### Exports

The QCCI functions have the parameters of the public Qualcomm QCCI API (`qmi_client_api.h`, `qmi_idl_lib.h`), which their use of the arguments confirms. Return values: 0 `QMI_NO_ERR`, −1 internal error / bad parameter, −2 service error (no server, server gone), −3 timeout, −5 error callback already registered by the notifier, −14 unknown transaction; the IDL functions return the IDL errors listed in [IDL engine](#idl-engine).

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `DllMain` | 0x10006C14 | See [Startup](#startup) |
| 2 | `QCCI_Close` | 0x10006B8C | None used. WPP trace, returns 1 |
| 3 | `QCCI_Deinit` | 0x10006B04 | None used. WPP trace, returns 1 |
| 4 | `QCCI_IOControl` | 0x10006BD0 | None used. WPP trace, returns 0 |
| 5 | `QCCI_Init` | 0x10006AC0 | None used. WPP trace, returns 1 |
| 6 | `QCCI_Open` | 0x10006B48 | None used. WPP trace, returns 1 |
| 7 | `qmi_client_delete_async_txn` | 0x100020C4 | `client`, `txn`: removes the [transaction](#transaction) from the list and clears its callback / response buffer, so a late response is dropped. −14 if not found |
| 8 | `qmi_client_get_any_service` | 0x10002A20 | `service_obj`, `qmi_service_info *info`: first server found, `qmi_client_get_service_list` with 1 entry |
| 9 | `qmi_client_get_async_txn_id` | 0x10002BA4 | `client`, `txn`, `unsigned int *txn_id`: transaction id (16-bit, `+0x0C` of the transaction) |
| 10 | `qmi_client_get_instance_id` | 0x10002B18 | `qmi_service_info *info`, `unsigned int *instance_id`: byte `+2` of the [service info](#service-info) |
| 11 | `qmi_client_get_service_instance` | 0x10002A48 | `service_obj`, `instance_id`, `qmi_service_info *info`: lists all servers and returns the one whose instance (byte `+2`) matches; 0xFFFF = any |
| 12 | `qmi_client_get_service_list` | 0x10002934 | `service_obj`, `qmi_service_info *array`, `unsigned int *num_entries` (in: size of the array, out: entries written), `unsigned int *num_services` (out: servers found). Calls the lookup of every transport, see [Service lookup](#service-lookup). −2 if no server |
| 13 | `qmi_client_init` | 0x10001B74 | `qmi_service_info *info`, `service_obj`, `ind_cb`, `ind_cb_data`, `os_params`, `qmi_client_type *client`. See [qmi_client_init](#qmi_client_init-0x10001b74) |
| 14 | `qmi_client_message_decode` | 0x100028F8 | `client`, `req_resp_ind`, `msg_id`, `src`, `src_len`, `dst`, `dst_len`: `qmi_idl_message_decode` with the service object of the client |
| 15 | `qmi_client_message_encode` | 0x100028B8 | `client`, `req_resp_ind`, `msg_id`, `src`, `src_len`, `dst`, `dst_len`, `*encoded_len`: `qmi_idl_message_encode` with the service object of the client |
| 16 | `qmi_client_notifier_init` | 0x10001960 | `service_obj`, `qmi_client_os_params *os_params`, `qmi_client_type *notifier`. See [Notifier](#qmi_client_notifier_init-0x10001960) |
| 17 | `qmi_client_register_error_cb` | 0x10002B30 | `client`, `err_cb(client, error, data)`, `data`. Called with −2 when the server goes away (`sub_100014B4`); called at once (and −2 returned) if the server was already gone. −5 on a notifier |
| 18 | `qmi_client_release` | 0x10002834 | `client`. See [Release](#release) |
| 19 | `qmi_client_send_msg_async` | 0x10001FDC | `client`, `msg_id`, `req` (C struct), `req_len`, `resp` (C struct), `resp_len`, `resp_cb`, `resp_cb_data`, `qmi_txn_handle *txn` |
| 20 | `qmi_client_send_msg_sync` | 0x10002498 | `client`, `msg_id`, `req`, `req_len`, `resp`, `resp_len`, `timeout_ms` (0 = infinite) |
| 21 | `qmi_client_send_raw_msg_async` | 0x10001E4C | `client`, `msg_id`, `req_buf` (encoded TLVs), `req_len`, `resp_buf`, `resp_buf_len`, `raw_resp_cb`, `resp_cb_data`, `qmi_txn_handle *txn` |
| 22 | `qmi_client_send_raw_msg_sync` | 0x100021BC | `client`, `msg_id`, `req_buf`, `req_len`, `resp_buf`, `resp_buf_len`, `unsigned int *resp_len`, `timeout_ms` (0 = infinite) |
| 23 | `qmi_idl_get_message_c_struct_len` | 0x10002CF8 | `service_obj`, `req_resp_ind` (0 request, 1 response, 2 indication), `msg_id`, `uint32 *c_struct_len` |
| 24 | `qmi_idl_message_decode` | 0x10004028 | `service_obj`, `req_resp_ind`, `msg_id`, `src` (TLVs), `src_len`, `dst` (C struct), `dst_len` |
| 25 | `qmi_idl_message_encode` | 0x100040CC | `service_obj`, `req_resp_ind`, `msg_id`, `src` (C struct), `src_len`, `dst` (TLVs), `dst_len`, `*encoded_len` |

### Startup

`start` (`_DllMainCRTStartup`, 0x100076C4): CRT initialisation, then `DllMain` (0x10006C14):
- `DLL_PROCESS_ATTACH`: initialises the WPP control block (`dword_1000C6C0`) and registers the WPP provider (`sub_10005AA0`, `RegisterTraceGuidsW`, callback `sub_10005A28`), then `sub_10005B10`:
  1. `sub_1000706C` (`printf("Framework init\n")`) fills the [transport table](#transports) (`dword_1000A580` count, `dword_1000A584` entries, at most 7): the IPC router transport with no parameter, and the QMUX transport six times with the parameters 16 to 21 (`dword_1000C618`…`dword_1000C62C`). An entry already present is not added twice.
  2. sets the QMUX receive buffer size `dword_1000A5BC` to 0x2000, and `dword_1000A614` = `&unk_1000A618` (not used elsewhere).
- `DLL_PROCESS_DETACH`: `UnregisterTraceGuids`.
- Other reasons: only a trace.

Nothing is opened at load time: the devices are opened by `qmi_client_init`, `qmi_client_notifier_init` and the service lookups.

### Transports

Each transport is a table of 5 functions (`.data`), stored with its parameter in the transport table. The index of the transport in that table (0 = IPC, 1–6 = QMUX ports 0–5) is the `xport` byte of the [service info](#service-info).

| Offset | Function | IPC router (`off_1000A010`) | QMUX (`off_1000A024`) |
|--------|----------|-----------------------------|-----------------------|
| 0x00 | `open(param, client, service_id, idl_version, addr, max_rx_len)` | `sub_10004F18` | `sub_10006E00` |
| 0x04 | `send(handle, addr, msg, len)` | `sub_1000501C` | `sub_10006E78` |
| 0x08 | `close(handle)` | `sub_10005338` | `sub_10006FA4` |
| 0x0C | `lookup(param, xport, service_id, idl_version, *num_entries, info)` | `sub_100055D4` | `sub_10006FD0` |
| 0x10 | `addr_len()` | `sub_10005920`: 8 | `sub_10007060`: 0 |

The address length is the number of bytes of the server address kept by the client (`+0xA8`) and compared when a server goes away: 8 (`node id`, `port id`) on the IPC router, 0 on QMUX (any "server gone" notification of the service matches).

The `.data` section also holds two copies of the SMD channel table of qcqmux8930.sys (`DATA5_CNTL`/`DATA5` … `SDIO7_CNTL`/`SDIO7`, 0x1000A038 and 0x1000A1D0), without any reference.

### Service info

`qmi_service_info`, 20 bytes, filled by the lookups (`qmi_client_get_service_list`):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 1 | Transport index (0 IPC, 1–6 QMUX) |
| 0x01 | 1 | Version: low byte of the IPC router instance / `idl_version` of the service object for QMUX |
| 0x02 | 1 | Instance: second byte of the IPC router instance / the QMUX parameter (16–21) |
| 0x03 | 1 | 0 |
| 0x04 | 16 | Server address. IPC: node id, port id (8 bytes). QMUX: two dwords copied from an uninitialised `malloc` buffer (`sub_10006FD0`), never used since the QMUX address length is 0 |

### Service object

The IDL service object (generated code, passed by the caller) as read by the library:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Library version. Must be 1–6, otherwise error −48 |
| 0x04 | 4 | IDL version: instance asked to the IPC router (mask 0xFF), version byte of the QMUX service info |
| 0x08 | 4 | QMI service id |
| 0x0C | 4 | Max message length |
| 0x10 | 6 | Number of messages, 16-bit, for requests / responses / indications |
| 0x18 | 12 | Message tables (6-byte entries sorted by message id: `msg_id`, (type table << 12 \| type index), …) |
| 0x24 | 4 | Type table object (`+0x10`: list of the type tables, the referenced ones included) |
| 0x2C | 4 | Parent service object (library version ≥ 5): searched when the message id isn't in this one |

### qmi_client_init (0x10001B74)

1. Checks the service object (library version 1–6) and the transport index of the service info (< number of transports), then allocates the 264-byte [client](#client) (`+0xF8` next transaction id = 1, `+0xFC` response event, 4 critical sections).
2. Copies the server address (address length of the transport) from the service info to `+0xA8`, and calls the `open` of the transport with (service id, IDL version, address, max message length). The handle is kept at `+0x08`, the transport at `+0x04`.
3. Checks with `qmi_client_get_service_list` that the server of the address is still listed; otherwise the transport is closed and −2 returned.

The indication callback and its data are kept at `+0x7C` / `+0x80`.

### qmi_client_notifier_init (0x10001960)

Builds a client that only waits for servers. It opens **every** transport with no address (IPC: a router port and its two threads; QMUX: no device), and calls their `lookup`. `os_params` is a caller structure {`HANDLE` event, `BYTE` timed out}: the library creates the event (manual reset) and signals it when a server of the service already exists or when a `New_server` event arrives on the IPC router. The caller then uses `qmi_client_get_service_list` and `qmi_client_init`.

### Sending

`qmi_client_send_msg_sync` / `_async` (`sub_10001234`):
1. creates a [transaction](#transaction) (`sub_10001168`) with the next non-zero 16-bit transaction id;
2. encodes the request: `qmi_idl_get_message_c_struct_len` must equal `req_len`, then `qmi_idl_message_encode` into a `malloc(max_len + 7)` buffer, after a 7-byte header (`req_len` 0 or `req` NULL: header only);
3. prints `QCCI TX: %s txn: 0x%x msg_id: 0x%x len: %d` with `OutputDebugStringA` (always, not gated by WPP);
4. calls the `send` of the transport with the server address.

QMI header (7 bytes, before the TLVs, sent as is on both transports):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 1 | Control flags: 0 request, 2 response, 4 indication |
| 0x01 | 2 | Transaction id |
| 0x03 | 2 | Message id |
| 0x05 | 2 | Length of the TLVs |

The raw functions copy the caller's TLVs after the header instead of encoding. The synchronous ones reset the response event (`+0xFC`), set the result to −3 and wait on it (`timeout_ms`, 0 = infinite): timeout → −3, otherwise the result of the decode (or the length received for raw). The event is shared by the whole client, so two synchronous calls on the same client at the same time wake each other up (?).

### Receiving

The reader threads of the transports call `sub_10001660(client, msg, len)`:
1. prints `QCCI RX: %s txn: 0x%x msg_id: 0x%x len: %d` with `OutputDebugStringA`, and asserts (`_wassert("msg_len == len", "qmi_cci_common.c", 530)`) that the header length matches;
2. indication (4): `ind_cb(client, msg_id, TLVs, len, ind_cb_data)` (TLVs NULL when the length is 0); the caller decodes it with `qmi_client_message_decode`;
3. response (2): looks up the transaction by id. If the message id differs, the transaction completes with −14. Otherwise, by type: sync → `qmi_idl_message_decode` into the response structure, then `SetEvent`; raw sync → copy (truncated to the buffer), then `SetEvent`; async → decode, then `resp_cb(client, msg_id, resp, resp_len, cb_data, result)`; raw async → copy, then `raw_resp_cb(client, msg_id, buf, len, cb_data, 0)`;
4. other control flags: dropped (−1).

When a server goes away (`sub_100014B4`, called by the transports): signals the notifier event, and if the address matches the client's, clears it, completes every pending transaction with −2 and calls the error callback with −2 (or remembers it, `+0xA4`, for a later `qmi_client_register_error_cb`).

### Release

`qmi_client_release` (0x10002834) creates an event and calls `sub_100026D0`: every pending transaction completes with −1, the release callback (`+0x74` = `loc_1000281C`, data `+0x78` = the event) is set, and the `close` of each open transport is called. Each close drops a reference (`sub_100013FC`, `+0x70`); the last one closes the events, deletes the critical sections, calls the release callback and frees the client. `qmi_client_release` waits for it (infinite).

### Client

264 bytes (`malloc` in `qmi_client_init` / `qmi_client_notifier_init`).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Service object |
| 0x04 | 84 | 7 × {transport functions, transport handle, address length}. `qmi_client_init` uses only the first entry |
| 0x58 | 24 | Critical section of the reference count |
| 0x70 | 4 | Reference count (one per open transport) |
| 0x74, 0x78 | 8 | Release callback and data |
| 0x7C, 0x80 | 8 | Indication callback and data |
| 0x84 | 24 | Critical section of the error callback |
| 0x9C, 0xA0 | 8 | Error callback and data |
| 0xA4 | 4 | 1 when the server went away before an error callback was registered |
| 0xA8 | 16 | Server address |
| 0xB8 | 1 | 1 when the address is valid |
| 0xBC | 24 | Critical section of the address |
| 0xD4 | 24 | Critical section of the transaction list |
| 0xEC, 0xF0, 0xF4 | 12 | Transaction list: head, tail, count |
| 0xF8 | 2 | Next transaction id |
| 0xFC | 4 | Response event (manual reset), also the "resume tx" event of the IPC transport |
| 0x100 | 1 | 1 when the last wait timed out |
| 0x104 | 4 | `os_params` of the notifier |

### Transaction

80 bytes (`sub_10001168`), in the list of the client.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00, 0x04 | 8 | Previous, next |
| 0x08 | 4 | Type: 0 sync, 1 raw sync, 2 async, 3 raw async |
| 0x0C | 4 | Transaction id |
| 0x10 | 4 | Message id |
| 0x14 | 4 | Raw response callback |
| 0x18 | 4 | Response callback |
| 0x1C | 4 | Callback data |
| 0x20 | 4 | Response buffer / structure |
| 0x24 | 4 | Its size |
| 0x28 | 4 | Length received (raw) |
| 0x2C | 4 | Result |
| 0x30 | 4 | Reference count |
| 0x34 | 24 | Critical section |
| 0x4C | 4 | Client |

### IPC router transport

`open` (`sub_10004F18`) allocates a 48-byte handle {`+0x00` client, `+0x04` → client response event, `+0x08` service id, `+0x0C` IDL version, `+0x10` device handle, `+0x14`/`+0x1C` thread handles, `+0x24` stop event, `+0x28`/`+0x2C` thread-exit events}, opens `\\.\IPC` (`sub_10004298`, `GENERIC_READ | GENERIC_WRITE`, share read / write, `OPEN_EXISTING`, `FILE_FLAG_OVERLAPPED`) and starts two threads. The address is not used by `open`: it's given to each `send`.

- Receive thread (`sub_10004698`): waits for a packet with [IOCTL 0x122017](../drivers/qcipcrouter8930.md#ioctl-0x122017) (overlapped, wait together with the stop event), allocates the size it returns, `ReadFile`s the packet ({source node, source port, payload}) and gives the payload to `sub_10001660`. Loops until the stop event or an error.
- Control thread (`sub_10004B38`): waits for the router events with [IOCTL 0x122000](../drivers/qcipcrouter8930.md#ioctl-0x122000) (20-byte output): `Resume_tx` (0) → signals the client's event; `New_server` (1) of the same service and instance → signals the notifier event; `Rem_server` (2) of the same service and instance → server gone, with the node / port of the event as address. `Rem_client` (3) is ignored.
- `send` (`sub_1000501C`): `WriteFile` of {destination node id, destination port id, message} (`len + 8` bytes), overlapped, then `GetOverlappedResult`. A retry loop (wait on the response event, then write again) runs while `WriteFile` returns 170: since `WriteFile` returns a `BOOL`, it's never taken (an `ERROR_BUSY` test on the wrong value ?).
- `close` (`sub_10005338`): sets the stop event, waits for both threads (`WaitForMultipleObjectsEx`), closes the handles, drops the client reference.

#### Service lookup

`lookup` (`sub_100055D4`) opens a temporary `\\.\IPC` handle and sends [IOCTL 0x122008](../drivers/qcipcrouter8930.md#ioctl-0x122008):

| Input | Value |
|-------|-------|
| 0x00 | Service id |
| 0x04 | IDL version of the service object (instance) |
| 0x08 | 0xFF (instance mask: only the version byte is compared) |
| 0x0C | Entries wanted |

The output (8 + 16 × entries) gives the number of matching servers (returned) and, for each entry {service, instance, node, port}, a [service info](#service-info) {transport index, instance byte 0, instance byte 1, 0, node, port}.

### QMUX transport

The QMUX transport is registered six times with the parameters 16 to 21, i.e. QMUX ports 0 to 5 (parameter − 16, see [IOCTL 0x12410](../drivers/qcqmux8930.md#ioctl-0x12410)).

- `open` (`sub_10006E00`) allocates a 72-byte handle {`+0x00` client, `+0x08` → client response event, `+0x0C` service id, `+0x10` parameter, `+0x14` device handle, `+0x18` receive callback `sub_10006D34`, `+0x1C` address, `+0x24` thread, `+0x2C` thread-exit event, `+0x30` stop event, `+0x40` 0x2000-byte receive buffer}. Without an address (notifier) nothing else is done. Otherwise `sub_10005C90` opens `\\.\QMUX\QmuxDevice` (`CreateFileA`, `GENERIC_READ | GENERIC_WRITE`, `FILE_FLAG_OVERLAPPED`) and starts the thread `sub_1000675C`, then `sub_10005E38` gets a client id with [IOCTL 0x12410](../drivers/qcqmux8930.md#ioctl-0x12410) (input {service id, port}, 1-byte output): 0 or 0xFF (or a failed overlapped wait) → `open` fails.
- `send` (`sub_10006E78` → `sub_10006390`): `WriteFile` of the message as is (QMI header + TLVs = the QMI SDU the driver expects), overlapped.
- Thread (`sub_1000675C`): keeps an overlapped `ReadFile` (0x2000 bytes) and an overlapped [IOCTL 0x12430](../drivers/qcqmux8930.md#ioctl-0x12430) (8-byte output {state, service}) pending, and waits on them and the stop event. A read completes → `sub_10006D34` → `sub_10001660`, and a new read. A notification with state 1 (modem reset) for the service of the handle → server gone. Then a new IOCTL 0x12430.
- `close` (`sub_10006FA4`, `sub_10005B90`): sets the stop event, waits for the thread, closes the handles, frees the buffer, drops the client reference.
- `lookup` (`sub_10006FD0` → `sub_100060D8`): opens a temporary `\\.\QMUX\QmuxDevice` and sends [IOCTL 0x12418](../drivers/qcqmux8930.md#ioctl-0x12418--ioctl-0x1241c) (input {service id, port}, 4-byte output = major, minor version): one server when the major version isn't 0, none otherwise. That IOCTL is sent on its own handle, so the client handle of `open` is only bound by IOCTL 0x12410.

### IDL engine

`qmi_idl_message_encode` / `qmi_idl_message_decode` / `qmi_idl_get_message_c_struct_len` (`sub_10002D8C` message lookup, `sub_10003098` encode, `sub_100037A4` / `sub_10003964` decode, `sub_10002C10` max message length) walk the type tables of the [service object](#service-object) and convert between C structures and TLVs. Errors are raised with `longjmp` from the inner functions and returned by the export: −43 message id not found, −45 buffer too short, −46 missing mandatory TLV, −47 NULL service object or bad parameter (e.g. `req_resp_ind` ≥ 3), −48 unsupported library version. −41, −42, −44, −49 and −51 are also used, not identified.

### ETW

WPP provider `{FFC49484-393B-4AF2-92C4-ABEEA6B95322}` (`RegisterTraceGuidsW` in `DllMain`, `TraceMessage`): levels ≥ 2 errors, ≥ 4 information, ≥ 5 verbose, all under flag bit 0. Message GUIDs: `{8843896D-D3B1-89AC-FA1F-292FAF972964}` (IPC transport), `{F21EA9B3-98F7-3FAD-DB2C-09C8AA83CC43}` (QMUX transport), `{7D0360FB-B51C-5B07-63D2-8F2FA62BC53F}` (QMUX send / receive).

The `QCCI TX` / `QCCI RX` lines of every message go to `OutputDebugStringA` independently of WPP.
