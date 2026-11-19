## Mshwnclx.sys

Microsoft Hardware Notification class extension (`HwNClx`).  
It is a KMDF class library (`WdfRegisterClassLibrary`), not a device driver: it has no `EvtDriverDeviceAdd`. Hardware-notification client drivers (the vibrator driver [hwnvibradime.sys](./hwnvibradime.md), [hwnled.sys](./hwnled.md) for the LEDs, [hwnhaptics.sys](./hwnhaptics.md)) bind to it with `WdfVersionBindClass` and call its 4 exported functions. The class extension then owns the FDO of each client: it names the device, creates its device interface, handles PnP / power and the file objects, and receives the 2 IOCTLs (set state / get state) that it forwards to the client's `ClientSetState` / `ClientGetState` callbacks after checking the `HWN_HEADER`.  
When a handle is closed, every notification that this handle had switched on (or set to blink) is switched off. The device is kept in D0 while at least one notification is on or blinking, and goes to D3 after 500 ms of idle otherwise.  
KMDF 1.11 (`KmdfLibrary`, 0x1B0 functions), PDB `mshwnclx.pdb`. Pool tag `HWN1`. Debug messages only (`vDbgPrintEx`, component id 101), no ETW provider.

Device names:  
| Device | Comment |
|--------|---------|
| `\Device\MSHwNClassExt0` | Control device of the class library (`WdfControlDeviceInitAllocate`, SDDL `D:P` = protected DACL with no ACE, so nobody can open it). The suffix is incremented while `WdfDeviceCreate` returns `STATUS_OBJECT_NAME_COLLISION`. Passed to `WdfRegisterClassLibrary` |
| `\Device\HWN1`, `\Device\HWN2`, … | Name given to the FDO of each client device (`HwNpAssignTargetName`, `sub_10005C10`, global counter at `.data:0x1000776C` incremented before use) |

There's no symbolic link: applications open the device through the interface GUID passed by the client.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\HwNClx0101` ?  

Registry values:  
| Registry key | Registry value | comment |
|--------------|----------------|---------|
| `\REGISTRY\MACHINE\SYSTEM\ControlSet001\Services\HwNClx0101` (hardcoded) | WpSecurity | Binary self-relative security descriptor. Its DACL is applied to the FDO of a client whose interface GUID is `{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}` (vibrator), see [Security](#security) |
| Service key of the **client** driver (`WdfDriverGetRegistryPath`) | EnableOemSecurity | REG_DWORD. When present (type REG_DWORD, size ≥ 4; the value itself isn't read), `WpSecurity` is not applied |

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| (client FDO) | [hwnvibradime.sys](./hwnvibradime.md) | Vibrator of the Lumia 520, interface `{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}` |
| (client FDO) | [hwnled.sys](./hwnled.md) | Key LEDs (`\_SB.HWN0`, `QCOM0D50`), interface `{6B2A25E2-AAF5-482C-99A5-6205CDCC176A}` (the interface opened by [oempanel.sys](./oempanel.md)) |
| (client FDO) | [hwnhaptics.sys](./hwnhaptics.md) | Not used on the Lumia 520, interface `{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}` |

The class extension doesn't open any device itself: it only calls the client callbacks.

### Class library

`DriverEntry` (0x10004000) initialises the client list (`sub_10005DBC`: list head `.data:0x10007990`, fast mutex `.data:0x100079A0`), creates the WDF driver (no `EvtDriverDeviceAdd`, `EvtDriverUnload` = 0x10005D78, `WdfDriverInitNonPnpDriver`) and calls `HwNClassLibraryCreate` (`sub_10005478`), which creates the control device and calls `WdfRegisterClassLibrary` with `WDF_CLASS_LIBRARY_INFO` at `.data:0x10007030`:  
| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| ClassLibraryInitialize | `sub_10005580` (returns 0) |
| ClassLibraryDeinitialize | `sub_1000558C` (empty) |
| ClassLibraryBindClient | `sub_10005598` (`HwNClxClassLibraryBindClient`): the client must ask for exactly 4 functions (`STATUS_INVALID_PARAMETER` otherwise), the table `.data:0x10001480` is copied to the client |
| ClassLibraryUnbindClient | `sub_1000558C` (empty) |

Functions exported to the clients (in this order):  
| # | Name (client side) | Function | Parameters | Comment |
|---|--------------------|----------|------------|---------|
| 0 | HwNRegisterClientDriver | `sub_1000584C` (`HwNClxRegisterClient`) | WDFDRIVER, `HWN_CLIENT_REGISTRATION_PACKET *`, registry path ? | The 3 parameters must not be NULL (`STATUS_INVALID_PARAMETER`). Validates the packet and appends a client entry (56 bytes, `NonPagedPoolNx`) to the list: +0x08 WDFDRIVER, +0x0C device name buffer, +0x10 copy of the packet |
| 1 | HwNUnregisterClientDriver | `sub_10005888` (`HwNpDeleteClient`) | WDFDRIVER | Removes the entry. `STATUS_NOT_FOUND` (0xC0000225) if the driver isn't registered |
| 2 | HwNProcessAddDevicePreDeviceCreate | `sub_10005918` | WDFDRIVER, `WDFDEVICE_INIT *`, `WDF_OBJECT_ATTRIBUTES *` (out) | Sets the PnP/power callbacks, the file object callbacks (context `HWN_FILE_OBJECT_CONTEXT`), the device name `\Device\HWN<n>`, `WdfDeviceIoBuffered`, and returns the attributes to use for `WdfDeviceCreate`: context `DEVICE_EXTENSION` with size = client context size + 76 (at least 80), cleanup callback `sub_10005384` (frees the name) |
| 3 | HwNProcessAddDevicePostDeviceCreate | `sub_10005A54` | WDFDRIVER, WDFDEVICE, interface GUID | [Security](#security), power capabilities, S0 idle settings, `WdfDeviceCreateDeviceInterface(device, guid, NULL)`, device extension, default queue |

Registration packet (`HWN_CLIENT_REGISTRATION_PACKET`, checked by `HwNpValidateRegistrationPacket` in `sub_10005DF0`):  
| Offset | Size | Field | Comment |
|--------|------|-------|---------|
| 0x00 | 2 | Version | Must be 1 |
| 0x02 | 2 | Size | Must be ≥ 40 (0x28). This many bytes are copied |
| 0x04 | 4 | Client context size | Added to the 76 bytes of the class extension context |
| 0x08 | 4 | ? | Not used |
| 0x0C | 4 | ClientInitializeDevice | `(WDFDEVICE, ctx, ResourcesRaw, ResourcesTranslated)`, from `EvtDevicePrepareHardware` |
| 0x10 | 4 | ClientUnInitializeDevice | `(WDFDEVICE, ctx)`, from `EvtDeviceReleaseHardware` |
| 0x14 | 4 | ClientQueryDeviceInformation | `(ctx, info *)`, after a successful initialization |
| 0x18 | 4 | ClientStartDevice | `(ctx)`, from `EvtDeviceD0Entry` |
| 0x1C | 4 | ClientStopDevice | `(ctx)`, from `EvtDeviceD0Exit` |
| 0x20 | 4 | ClientSetState | `(ctx, HWN_HEADER *in, inLength, &information)` |
| 0x24 | 4 | ClientGetState | `(ctx, HWN_HEADER *out, outLength, HWN_HEADER *in, inLength, &information)` |

All 7 callbacks are mandatory ("Client did not provide all required handlers" → `STATUS_UNSUCCESSFUL`). A wrong version or size also gives `STATUS_UNSUCCESSFUL` (0xC0000001).

Device information returned by ClientQueryDeviceInformation (`HwNpInitializeControllerInformation`, `sub_10006074`), 3 USHORTs:  
| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 2 | Version, must be 1 |
| 0x02 | 2 | Size, must be ≥ 6 |
| 0x04 | 2 | Total number of hardware notifications (N), must not be 0 |

Otherwise `EvtDevicePrepareHardware` fails with `STATUS_UNSUCCESSFUL`.

### Device extension

`DEVICE_EXTENSION` (context of the FDO, `sub_10005F48` `HwNpBuildDeviceExtension`):  
| Offset | Size | Comment |
|--------|------|---------|
| +0x00 | 4 | Signature `HWNN` |
| +0x04 | 4 | WDFDEVICE |
| +0x08 | 4 | Power state: 1 after D0 entry, the target D-state after D0 exit |
| +0x0C | 4 | Version and size from ClientQueryDeviceInformation |
| +0x10 | 2 | N = number of hardware notifications |
| +0x12 | 1 | 1 while idle is stopped (`WdfDeviceStopIdleNoTrack`) |
| +0x14 | 4 | Last error NTSTATUS of a client callback |
| +0x18 | 4 | State, see below |
| +0x1C | 8 | `UNICODE_STRING` device name (`WdfDeviceRetrieveDeviceName`, `PagedPool`) |
| +0x24 | 40 | Copy of the registration packet (callbacks at +0x30 … +0x48) |
| +0x4C | | Client context (the `ctx` parameter of every callback) |

States (+0x18):  
| State | Meaning |
|-------|---------|
| 0 | Releasing hardware |
| 1 | ClientUnInitializeDevice failed |
| 2 | Hardware released |
| 3 | Preparing hardware |
| 4 | ClientInitializeDevice / ClientQueryDeviceInformation failed |
| 5 | Hardware prepared |
| 6 | Entering D0 |
| 7 | ClientStartDevice failed |
| 8 | Started (D0) |
| 9 | Leaving D0 |
| 0xA | ClientStopDevice failed |
| 0xB | Stopped |

ClientStopDevice is called only if the state was 8; ClientUnInitializeDevice only if the state was ≥ 5. `EvtDeviceD0Exit` returns `STATUS_NOT_SUPPORTED` (0xC00000BB) for a target state other than D3 / D3Final.

### Power

`HwNProcessAddDevicePostDeviceCreate` sets:
- power capabilities: S0 → D0, S1–S5 → D3, ideal D-state for Sx = D3, no wake;
- S0 idle settings: `IdleCannotWakeFromS0`, D3, idle timeout 500 ms, user control not allowed.

Before each IOCTL, `HwNClnUpdatePowerStatePreClient` (`sub_100063D0`) calls `WdfDeviceStopIdleNoTrack(device, TRUE)` once. After it, `HwNClnUpdatePowerStatePostClient` (`sub_10006418`) reads the state of all N notifications with ClientGetState (buffer of 12 + 36 × N bytes, no input) and calls `WdfDeviceResumeIdleNoTrack` only if none is on (1) or blinking (2).  
The I/O queue itself is not power managed (default queue, sequential).

### Security

`HwnClxApplySecurity` (`sub_100055E0`), called with the interface GUID by `HwNProcessAddDevicePostDeviceCreate`:
1. Opens the service key of the client (`WdfDriverGetRegistryPath`). Failure → the device isn't created.
2. If `EnableOemSecurity` exists as a REG_DWORD → nothing else is done.
3. If the interface GUID is not `{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}` (`.rdata:0x10001BD8`) → nothing else is done.
4. Reads `WpSecurity` from `\REGISTRY\MACHINE\SYSTEM\ControlSet001\Services\HwNClx0101`, opens the FDO with `ObOpenObjectByPointer(OBJ_KERNEL_HANDLE, WRITE_DAC)` and applies the descriptor with `ZwSetSecurityObject(DACL_SECURITY_INFORMATION)`.

So the vibrator interface gets the Windows Phone security descriptor, while the other clients (e.g. the LEDs) keep the default security of the device.

### File objects

`EvtDeviceFileCreate` (0x10005168):
- The `DesiredAccess` of the create must contain the bits common to `FILE_GENERIC_READ` and `FILE_GENERIC_WRITE` (`READ_CONTROL | SYNCHRONIZE`), otherwise `STATUS_INVALID_PARAMETER` (0xC000000D, "Invalid access mode"). `CreateFile(GENERIC_READ | GENERIC_WRITE)` passes.
- Allocates a buffer of 12 + 36 × N bytes (`NonPagedPoolNx`), stored in the `HWN_FILE_OBJECT_CONTEXT`. Each successful [set state](#ioctl-0x228000--hwn-set-state) copies its input buffer there.

`EvtFileClose` (0x10005260): in the saved buffer, every setting with mode 1 (on) or 2 (blink) is set to mode 0 (off) and kept, the others are removed; if at least one remains, the header is rewritten (size = 12 + 36 × n, count = n) and sent to ClientSetState, so the notifications started by a process are switched off when its handle is closed. Then the buffer is freed.

Read and write requests are completed with `STATUS_NOT_IMPLEMENTED` (0xC0000002); any other IOCTL with `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### IOCTL 0x228000 — HWN set state

This IOCTL is processed by Mshwnclx.sys (`HwNpProcessHwNSetState`, `sub_10006288`), then by the ClientSetState callback of the client driver

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x0 (0) |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| HWN set state | ≥ 48 | 0 |

Inputbuffer (`HWN_HEADER` followed by n `HWN_SETTINGS` of 36 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 30 00 00 00 | Payload size (12 + 36 × n). Not checked by the class extension |
| 04-07 | 01 00 00 00 | Version ?. Not checked by the class extension |
| 08-0B | 01 00 00 00 | n = number of settings. Must be ≤ N |
| 0C + 36×i, 4 bytes | 00 00 00 00 | HwN Id. Must be < N |
| 10 + 36×i, 4 bytes | e.g. `02 00 00 00` | HwN type. Not checked by the class extension (2 = vibrator, see [hwnvibradime.sys](./hwnvibradime.md#set-state)) |
| 14 + 36×i, 24 bytes | | Settings, passed to the client |
| 2C + 36×i, 4 bytes | 00/01/02 00 00 00 | Mode: 0 = off, 1 = on, 2 = blink. Used by the class extension for the idle management and the cleanup on close |

An input buffer shorter than 48 bytes fails in `WdfRequestRetrieveInputBuffer` (`STATUS_BUFFER_TOO_SMALL`); n > N or an Id ≥ N returns `STATUS_UNSUCCESSFUL` (0xC0000001). The request is completed with the status and information returned by ClientSetState.

> [!NOTE]
> After a successful ClientSetState, the whole input buffer (`InputBufferLength` bytes) is copied into the per-handle buffer, which is only 12 + 36 × N bytes long. Only n is checked against N, not the buffer length, so a longer input buffer overflows that `NonPagedPoolNx` allocation.

Sent by [ShellChrome.dll](../libraries/shellchrome.md#haptic-feedback) and [MobileUI.exe](../applications/mobileui.md#ioctl-0x228000--vibrate) to the vibrator, and by [oempanel.sys](./oempanel.md#ioctl-0x228000--hwn-set-state-) to [hwnled.sys](./hwnled.md#set-state).

---

### IOCTL 0x22C004 — HWN get state

This IOCTL is processed by Mshwnclx.sys (`HwNpProcessHwNGetState`, `sub_10006118`), then by the ClientGetState callback of the client driver

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x1 (1) |
| Access | FILE_READ_ACCESS \| FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| HWN get state | 0 or ≥ 48 | 0 or ≥ 48 |

Three cases:
- **Output length 0**: nothing is called; the request succeeds with information = the input length, or 12 + 36 × N when there's no input buffer (size query).
- **No input buffer**: the output buffer (≥ 48 bytes) is zeroed and ClientGetState is called without input: state of all the notifications.
- **Input buffer** (≥ 48 bytes, same layout and checks as [set state](#ioctl-0x228000--hwn-set-state): n ≤ N, Ids < N): the output buffer must be at least as long as the input; ClientGetState is called with both buffers (the state of the listed Ids).

Outputbuffer: `HWN_HEADER` + `HWN_SETTINGS`, filled by the client (see [hwnvibradime.sys](./hwnvibradime.md#get-state)). Information = value returned by ClientGetState.

---

### Interface GUID

The device interface is the one given by the client to `HwNProcessAddDevicePostDeviceCreate`, created with `WdfDeviceCreateDeviceInterface` (no reference string).  

Vibrator interface (hardcoded in mshwnclx.sys for the `WpSecurity` check; passed by [hwnvibradime.sys](./hwnvibradime.md) and [hwnhaptics.sys](./hwnhaptics.md))  
`{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}`
