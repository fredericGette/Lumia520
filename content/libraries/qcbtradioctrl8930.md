## QcBtradioctrl8930.dll

The Qualcomm Bluetooth radio control DLL: switches the Bluetooth radio of the MSM8930 on/off and reads its state, build `P:\Bluetooth\rel\8.2.1.1\arm\Release\qcbtradioctrl8930.pdb`.  
It is a very small DLL (29 functions, mostly CRT): its two exports open the device interface `{B53A9DB7-1343-4C7F-B7BC-251B03DD8E34}` of [QcBluetooth8930.sys](../drivers/qcbluetooth8930.md) and send it [IOCTL 0x2A8004](../drivers/qcbluetooth8930.md#ioctl-0x2a8004) (switch on/off) or [IOCTL 0x2A8008](../drivers/qcbluetooth8930.md#ioctl-0x2a8008) (query the state). There is no global state: each call enumerates the interface, opens it, sends one IOCTL and closes it.  
According to the [Bluetooth stack](../bluetooth/README.md) diagram it is the `supportDLL` of the BtConnectionManagerService (not analysed), which calls `BluetoothEnableRadio` and `IsBluetoothRadioEnabled`.

Location on the phone: `C:\Windows\System32\QcBtradioctrl8930.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-devices-config-l1-1-0 | `CM_Get_Device_Interface_List_SizeW`, `CM_Get_Device_Interface_ListW` |
| api-ms-win-core-file-l1-2-0 | `CreateFileW` |
| api-ms-win-core-io-l1-1-1 | `DeviceIoControl` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-synch-l1-2-0 | `Sleep` |
| MSVCR110 | `malloc`, `free`, CRT startup (`_initterm`, `_initterm_e`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_malloc_crt`, `_calloc_crt`, `_amsg_exit`, `__C_specific_handler`, `__CppXcptFilter`, `__clean_type_info_names_internal`) |
| api-ms-win-core-util-l1-1-0 | `EncodePointer`, `DecodePointer` |
| api-ms-win-core-profile-l1-1-0 | `QueryPerformanceCounter` |
| api-ms-win-core-processthreads-l1-1-1 | `GetCurrentThreadId` |
| api-ms-win-core-sysinfo-l1-2-0 | `GetTickCount64`, `GetSystemTimeAsFileTime` |

The CRT startup functions, `EncodePointer`/`DecodePointer`, `QueryPerformanceCounter`, `GetCurrentThreadId`, `GetTickCount64` and `GetSystemTimeAsFileTime` (`/GS` cookie) are the Visual C++ 2012 DLL boilerplate.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| Device interface `{B53A9DB7-1343-4C7F-B7BC-251B03DD8E34}` of [QcBluetooth8930.sys](../drivers/qcbluetooth8930.md) | `CM_Get_Device_Interface_ListW` + `CreateFileW` | Target of the IOCTLs, see [Devices and IOCTLs](#devices-and-ioctls) |

No DLL is loaded at run time, no process or COM server is started, and there is no registry or file access.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `BluetoothEnableRadio` | 0x10001158 | `BOOL enable` (0=off, 1=on) |
| 2 | `IsBluetoothRadioEnabled` | 0x10001130 | `BOOL *enabled` (out, 4 bytes) |

Both return a `DWORD` error code: 0 on success, 2 (`ERROR_FILE_NOT_FOUND`) when `CreateFileW` fails, 8 (`ERROR_NOT_ENOUGH_MEMORY`) when `malloc` fails, or the non-zero `CONFIGRET` of a failed `CM_Get_Device_Interface_List*W` call (these values overlap the Win32 codes). The result of `DeviceIoControl` is ignored: a rejected IOCTL still returns 0.

### Startup

`start` (`_DllMainCRTStartup`, 0x1000173C) → `dllmain_dispatch` (`sub_10001640`, CRT init with `_initterm_e`/`_initterm` in `sub_100013E4`). `DllMain` (`sub_10001020`) only returns TRUE.

### Opening the driver

`SendBtRadioIoctl` (`sub_1000102C`, used by `IsBluetoothRadioEnabled`) and the inlined copy in `BluetoothEnableRadio` do the same thing:

1. `CM_Get_Device_Interface_List_SizeW` for the interface class `{B53A9DB7-1343-4C7F-B7BC-251B03DD8E34}` (`.rdata:0x10002110`), no device ID, flags 0 (`CM_GET_DEVICE_INTERFACE_LIST_PRESENT`). If it fails, its `CONFIGRET` is returned; if the size is 0, 0 is returned without sending anything.
2. `malloc(2 * size)` and `CM_Get_Device_Interface_ListW` into it (on failure the `CONFIGRET` is returned and the buffer is leaked).
3. `CreateFileW` on the first path of the list: `GENERIC_READ | GENERIC_WRITE`, `FILE_SHARE_READ | FILE_SHARE_WRITE`, `OPEN_EXISTING`, no flags. On failure: error 2.
4. `DeviceIoControl` (synchronous), `CloseHandle`, `free`, return 0.

### BluetoothEnableRadio (0x10001158)

Sends [IOCTL 0x2A8004](../drivers/qcbluetooth8930.md#ioctl-0x2a8004) with the 4-byte `enable` argument as input buffer (the driver reads its first byte: 0=off, 1=on), no output buffer.  
Unlike `IsBluetoothRadioEnabled` it retries: when any step before the IOCTL fails (interface not yet present, `CreateFileW` or `malloc` failure), it waits 2 seconds (`Sleep(2000)`) and starts again, up to 13 attempts (about 26 s, enough for the driver to start at boot), then returns the last error.

### IsBluetoothRadioEnabled (0x10001130)

Calls `SendBtRadioIoctl` (`sub_1000102C`) with [IOCTL 0x2A8008](../drivers/qcbluetooth8930.md#ioctl-0x2a8008), no input buffer and `enabled` as 4-byte output buffer. The driver writes the `BtOnOff` state (0=off, 1=on) in the first byte; the 3 other bytes are not written by the DLL, so the caller must initialise the `BOOL`. No retry.

### Devices and IOCTLs

| IOCTL | Device | Function | Access | Method | Sent by | Input | Output |
|-------|--------|----------|--------|--------|---------|-------|--------|
| [0x2A8004](../drivers/qcbluetooth8930.md#ioctl-0x2a8004) | 0x2A | 0x1 | FILE_WRITE_ACCESS | METHOD_BUFFERED | `BluetoothEnableRadio` | 4 bytes: `BOOL enable` | none |
| [0x2A8008](../drivers/qcbluetooth8930.md#ioctl-0x2a8008) | 0x2A | 0x2 | FILE_WRITE_ACCESS | METHOD_BUFFERED | `IsBluetoothRadioEnabled` | none | 4 bytes: `BOOL enabled` (first byte written by the driver) |

Both are processed by [QcBluetooth8930.sys](../drivers/qcbluetooth8930.md), opened through its interface `{B53A9DB7-1343-4C7F-B7BC-251B03DD8E34}`.
