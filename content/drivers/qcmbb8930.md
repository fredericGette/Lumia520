## Qcmbb8930.sys

Qualcomm Mobile Broadband (MBB) miniport driver: the NDIS 6.30 WWAN miniport of the cellular modem (vendor description `QUALCOMM INC WWAN`, debug prefix `<qcnet>`).  
It implements the Windows Mobile Broadband interface (`OID_WWAN_*`) on top of the modem's QMI services, and carries the IP packets of the data calls. The control path is the QMI client library (QCCI) compiled into the driver, over [qcqmux8930.sys](./qcqmux8930.md) (`\Device\QMUX`) and [qcipcrouter8930.sys](./qcipcrouter8930.md) (`\Device\IPC`). The data path is a channel of [qcbamdmux8930.sys](./qcbamdmux8930.md) (`\Device\DMUX`): this driver is the BAM DMUX client the qcbamdmux page lists as unknown.  
It also exposes a small control device `\Device\MBB_<n>` with 2 IOCTLs, reads LTE attach settings from the Nokia OEM registry key, and can load CDMA ERI (Enhanced Roaming Indicator) files from `C:\Windows`.  
The PDB path is `E:\build_e\subtask\916A8CD7_98\output\mbb\fre\qcmbb8930.pdb`, build date `Jan 28 2015 15:58:15`.

Device name : `\Device\MBB_<n>` (n = adapter index + 1, i.e. `\Device\MBB_1` for the first adapter)  
Symbolic link : `\DosDevices\Global\MBB_<n>`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\<service>`  

Values read directly under the service key (not under `Parameters`), by `DriverEntry` (0x44A008). A value outside the range is ignored and the default is kept:  
| Registry value | value | comment |
|----------------|-------|---------|
| MTUDATASIZE | 1500 (0x5DC) | REG_DWORD, 68–1500. MTU of the data path |
| SuppressNwPSDetach | 0 | REG_DWORD, 0–1 |
| DormancyTimeout | 1750 (0x6D6) | REG_DWORD, 1750–5000 |
| OSVer | 0 | REG_DWORD, read with `WdfRegistryQueryULong`. Only the value 1 is used (`dword_446494` = 1) |
| IPV6EHRPDConfigAPN | ? | REG_SZ, at most 101 bytes (`sub_44A770`) |
| IPV6EHRPDConfigEnable | 1 | REG_DWORD (`sub_44A770`) |
| IPV6EHRPDMEDIANOTIFY | 0 | REG_DWORD (`sub_44A950`) |
| ERIAlgorithm | 0 | REG_DWORD, 1–2. 0 = no ERI file. See [ERI files](#eri-files) |
| ERIDataFileName | ? | REG_SZ, at most 512 bytes. File name under `C:\Windows\` |
| ERISprintIntlRoamDataFileName | ? | REG_SZ, at most 512 bytes. Only with `ERIAlgorithm` = 2 |
| QCDriverMBOff | 0 | REG_DWORD. 1 sets the adapter flag `+0x17D0` (`sub_42D118`) |
| eHRPDIPTypeCache | — | REG_DWORD, **written** by the driver (`sub_4118B0`) |

Adapter keywords, read with `NdisReadConfiguration` in `sub_42CCB0` (keyword table `.data:0x00444F00`). These are the values of the adapter's instance key (`…\Control\Class\{4D36E972-…}\<nnnn>`):  
| Registry value | value | comment |
|----------------|-------|---------|
| MaxRxNBLsPerIndication | 16 | 1–100 |
| MaxBufferedRxNBLs | 512 | 1–1024. Receive NBLs above this number are freed instead of being recycled |
| MPMaxCtrlSends | 20 | 1–100. Number of 208-byte transmit records |
| MPCtrlSendSize | 1024 | 1–65535 |
| MPMaxCtrlReceives | 5 | 1–100 |
| MPCtrlReceiveSize | 1024 | 1–65535 |
| MPLLHeaderBytes | — | In the table but not read |
| QcDriverDebugMask | 0x00410002 | Any value |
| MPNumClients | — | In the table but not read |
| MPReconfigDelay | 500 | 200–5000 |
| NetCfgInstanceId | ? | REG_SZ. Used to build `Tcpip\Parameters\Interfaces\<id>` and `Tcpip6\Parameters\Interfaces\<id>`, where the driver writes `NameServer` (DNS servers of the data call, `sub_430B7C` / `sub_430D90`) |
| VlanId | 0 | Any value |
| MPQosPendingPackets | 8 | 3–0x7FFFFFFF |
| NetLuidIndex | 0 | Any value |
| MPActivationDelay | 150000 | 120000–240000 |
| MPDeactivationDelay | 180000 | 120000–240000 |
| MPModelId | ? | REG_SZ |
| IsJCDMAEnabled | 0 | 0–1 |
| MPRegMaxPlaceHolder | — | End of the table |
| CDMAContext | ? | REG_BINARY, at most 1244 (0x4DC) bytes (`sub_42A894`). Default CDMA context. When missing, the driver uses user name `username`, password `password` and access string `#777` (`sub_4234F0`) |

Registry key `HKEY_LOCAL_MACHINE\SOFTWARE\OEM\Nokia\Cellular` (`sub_4318A0`, `RtlQueryRegistryValuesEx` with type check, REG_SZ only):  
| Registry value | value | comment |
|----------------|-------|---------|
| LTEAttachAuthType | ? | REG_SZ. Authentication of the LTE attach (initial bearer) profile (`sub_41F0AC`) |
| LTEAttachUsername | ? | REG_SZ |
| LTEAttachPassword | ? | REG_SZ |

GUID of the ETW provider (`McGenEventRegister`):  
`{F7B7C8E4-A5B1-4955-B927-248DDDC028C7}`

GUID of the WPP control provider:  
`{36797C31-A122-43DB-B296-36AB887335C3}`  
WPP trace message GUIDs (some of them): `{1769A282-2BFF-EA6C-9F11-4048A99980E5}`, `{6EC8E416-A54F-4ABC-AAF8-D7A6DE0B1473}`, `{67B70E02-A92C-6405-992B-828896856D9D}`, `{A02AD404-487E-E2FC-1ED3-22E490DDAFCB}`, `{EEEF7BB8-E744-BBDF-A6EA-F2E475D76397}`, `{AE374FC5-29F9-345C-872B-CF92F1E107AC}`, `{5AF7E397-3454-591A-ECF9-63F486DBABAD}`, `{32644F15-2768-9712-DCF9-E14B518EE07A}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| `\Device\QMUX` (interface `{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`) | [qcqmux8930.sys](./qcqmux8930.md) | QCCI "QMUX" transport: [IOCTL 0x12410](./qcqmux8930.md#ioctl-0x12410), [IOCTL 0x12418](./qcqmux8930.md#ioctl-0x12418--ioctl-0x1241c), [IOCTL 0x12430](./qcqmux8930.md#ioctl-0x12430), read/write. Also opened directly with `ZwCreateFile` for [IOCTL 0x1242C](#ioctl-0x1242c) |
| `\Device\IPC` (interface `{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`) | [qcipcrouter8930.sys](./qcipcrouter8930.md) | QCCI "IPC router" transport: [IOCTL 0x122000](./qcipcrouter8930.md#ioctl-0x122000), [IOCTL 0x122008](./qcipcrouter8930.md#ioctl-0x122008), [IOCTL 0x122017](./qcipcrouter8930.md#ioctl-0x122017), [IOCTL 0x12201B](./qcipcrouter8930.md#ioctl-0x12201b), read/write |
| `\Device\DMUX` | [qcbamdmux8930.sys](./qcbamdmux8930.md) | Data path: stream 2, channel = adapter index. [internal IOCTL 0x82003](#internal-ioctl-0x82003), [query-interface](#irp_mn_query_interface), write and cleanup IRPs. Opened when the interface `{CCCB7664-4951-40C3-8EB1-FDA3964A4479}` arrives |
| TCP/IP stack (WSK) | tcpip.sys | 16 sockets on ports 32000–32007, see [WSK sockets](#wsk-sockets) |

### DriverEntry

`DriverEntry` (0x44A008, Hex-Rays fails on it):
1. WPP and ETW registration, `WdfDriverCreate` (flag `WdfDriverInitNoDispatchOverride`, KMDF is only used for the registry functions and `WdfDeviceMiniportCreate`).
2. Fails with `STATUS_UNSUCCESSFUL` if `RtlIsNtDdiVersionAvailable(0x06020000)` (Windows 8) fails (`sub_44A6E4`).
3. Copies the registry path and reads the service key values (see above).
4. `NdisMRegisterMiniportDriver`: NDIS 6.30, driver version 2.2, flag `NDIS_WDM_DRIVER`.  
| Handler | Function |
|---------|----------|
| SetOptions | sub_410E88 |
| InitializeEx | sub_413588 |
| HaltEx | sub_40DBA4 |
| Unload | sub_40E51C |
| Pause / Restart | sub_410A7C / sub_410B88 |
| OidRequest | sub_42DD6C |
| SendNetBufferLists | sub_40BB44 |
| ReturnNetBufferLists | sub_404CE4 |
| CancelSend | sub_410C3C |
| ResetEx | sub_40DF0C |
| DevicePnPEventNotify | sub_410DC0 |
| ShutdownEx | sub_40E5B0 |
| CancelOidRequest / DirectOidRequest / CancelDirectOidRequest | sub_42E6E0 / sub_42E79C / sub_42E810 |
5. Reads the ERI settings and files.

Pool tags: `MBBu`, `MBBq`, `MBBd` (DMUX), `QCDM` (control device), `litu`.

### InitializeEx

`MiniportInitializeEx` (sub_413588):
1. Starts the WSK client and its worker thread (`sub_40A138`), and queues the creation of the [WSK sockets](#wsk-sockets) (`sub_409F4C`).
2. `NdisMGetDeviceProperty`, `WdfDeviceMiniportCreate`, reads `QCDriverMBOff` and the adapter keywords (`sub_42CCB0`).
3. `NdisMSetMiniportAttributes` (registration attributes, flags 0x26 = `NDIS_WDM`, `SURPRISE_REMOVE_OK`, `NO_HALT_ON_SUSPEND`).
4. Takes a free adapter index 0–3 (`sub_40838C`, adapter `+0x8870`). More than 4 adapters fail.
5. Creates the [control device](#control-device) (`sub_414BB8`) and makes it accessible to everybody (`sub_4153BC`).
6. `IoRegisterPlugPlayNotification` on `{CCCB7664-4951-40C3-8EB1-FDA3964A4479}` (the "ready" interface of [qcbamdmux8930.sys](./qcbamdmux8930.md#a2-power-handshake)): the callback `sub_4084CC` only sets an event (adapter `+0x8D64`) on arrival.
7. Indicates `NDIS_STATUS_LINK_STATE` (0x40010017) "disconnected", sets the context activation state (`+0x380`) to 3, and starts the adapter thread (`sub_40F89C` → `sub_40FD20`).

The adapter thread `sub_40FD20` starts a second thread, `sub_40CD0C` (`sub_40C8A0`), and opens the DMUX channel (`sub_408BB8`, see [Data path](#data-path)). `sub_40CD0C` waits on a set of events; one of them (case 4) runs `sub_40ECB4`, which opens one QCCI client per QMI service (`sub_406A88`, see below) and then sends [IOCTL 0x1242C](#ioctl-0x1242c) (QMI_CTL SET_DATA_FORMAT) to QMUX.

### QMI services

`sub_406A88` creates the clients with the QCCI library (`sub_432D78` = service lookup, `sub_4323A0` = client init ?), from these IDL service objects:  
| Index | Service object | QMI service | Comment |
|-------|----------------|-------------|---------|
| 0 | `.rdata:0x0043E0DC` | 0x01 WDS | Data calls, IPv4 |
| 1 | `.rdata:0x0043A328` | 0x02 DMS | Device management (IMEI, operating mode…) |
| 2 | `.rdata:0x0043C9D0` | 0x03 NAS | Network access (registration, signal…) |
| 3 | `.rdata:0x0043AC68` | 0x05 WMS | SMS |
| 4 | `.rdata:0x0043E0DC` | 0x01 WDS | Second WDS client, IPv6 |
| 5 | `.rdata:0x0043EE20` | 0x0B UIM | SIM card, PIN |
| 6 | `.rdata:0x0043FB94` | 0x09 VOICE | |

The client handles are kept at adapter `+0x8C34` + 4 × index. Requests are built by `sub_40765C(adapter, index, message id, …)` (buffer sizes and response callbacks per service: `sub_40612C`) and sent by `sub_407448` (QCCI `sub_4328A0` or `sub_4326D0`: asynchronous / synchronous send ?).  
QMI messages used by the control device:  
| Service | Message | Comment |
|---------|---------|---------|
| WDS (0 and 4) | 0x0021 | STOP_NETWORK_INTERFACE: end of the data call ([IOCTL 0x82000](#ioctl-0x82000)) |
| DMS | 0x002E | SET_OPERATING_MODE, mode 0 (online). Sent by `sub_42ADEC` when the stored state is 3 |
| NAS | 0x0070 | ? 8-byte request `{x, 0}`, x = 1 or 0 ([IOCTL 0x82004](#ioctl-0x82004)) |
| NAS | 0x004D | GET_SYS_INFO ? |
| WDS (0) | 0x006B | ? |

The binary contains test/default strings: IMSI `440100123456789`, provider `DoCoMo` (NTT DoCoMo gets special device caps), `profile1`, `TDSCDMAservice`, and a provider table (`Verizon Wireless`, `Sprint`, `Vodafone`, `TMobile`, … at `.data:0x00443678`). It also holds 4 copies of the QMUX SMD channel table (`DATA5_CNTL`…`SDIO7`), apparently unused (same as [qcqmux8930.sys](./qcqmux8930.md#smd-channels)).

### Data path

The IP packets go through channel `<adapter index>` of stream 2 of [qcbamdmux8930.sys](./qcbamdmux8930.md) (`sub_408884`):
1. `ZwOpenFile("\Device\DMUX")`, then `IoGetRelatedDeviceObject` on the file object.
2. [internal IOCTL 0x82003](#internal-ioctl-0x82003): bind the file object to stream 2 / channel n, with the RX callback `sub_404E24`.
3. [IRP_MN_QUERY_INTERFACE](#irp_mn_query_interface) for the BAM DMUX interface.

Transmit (`SendNetBufferLists` → `sub_40BE38` → `sub_408DA4`): one `IRP_MJ_WRITE` per packet, `UserBuffer` = the IP packet, completion `sub_409694`.  
Receive: the DMUX driver calls `sub_404E24(Payload, Length, Adapter)` for each DATA packet; the payload is wrapped in an MDL/NBL and indicated with `NdisMIndicateReceiveNetBufferLists`. When the NBL comes back (`sub_40547C`), the buffer is returned to DMUX with the interface function at offset 0x10, called with `Stream = 2` and `Buffer = Payload − 8` (the address of the BAM DMUX header).  
At close, an `IRP_MJ_CLEANUP` is sent on the DMUX file object (`sub_408CB4`).

### WSK sockets

`sub_40A138` registers a WSK client and prepares 8 entries with the ports 32000 to 32007. `sub_409F4C` queues 16 jobs (2 per port) to a system thread (`sub_409FE4`), which runs `sub_4098EC`:
- `sub_409968`: TCP socket (`AF_INET6`, `SOCK_STREAM`, `IPPROTO_TCP`, `WSK_FLAG_LISTEN_SOCKET`), `IPV6_V6ONLY` = 0 (dual stack), bound to `[::]:<port>`.
- `sub_409C60`: UDP socket (`AF_INET6`, `SOCK_DGRAM`, `IPPROTO_UDP`, `WSK_FLAG_DATAGRAM_SOCKET`), bound to `[::]:<port>`.

No receive or accept callback is given: the sockets probably only reserve the ports 32000–32007 on the application processor (?), e.g. because the modem's own IP stack uses them.

### Control device

`sub_414BB8` creates `\Device\MBB_<n>` / `\DosDevices\Global\MBB_<n>` with `NdisRegisterDeviceEx`. The same dispatch routine (`sub_41457C`) handles `IRP_MJ_CREATE`, `IRP_MJ_CLOSE`, `IRP_MJ_DEVICE_CONTROL` and `IRP_MJ_CLEANUP`. The adapter is found from the device object (`sub_41532C`); without one the IRP fails with `STATUS_UNSUCCESSFUL` (0xC0000001).  
After the creation, `sub_4153BC` opens the device and sets a security descriptor without DACL (`RtlCreateSecurityDescriptor` + `ZwSetSecurityObject(DACL_SECURITY_INFORMATION)`), then sets the "ready" flag of the control device context.
- Create: counts the open handles. Once the device is "ready", it fails with `STATUS_UNSUCCESSFUL` unless the adapter is initialised (flags `+0x8878`: bit 0x10 set, bits 0–3 clear).
- Device control: `STATUS_UNSUCCESSFUL` until the device is "ready". Only [IOCTL 0x82000](#ioctl-0x82000) and [IOCTL 0x82004](#ioctl-0x82004) are known, other codes fail with `STATUS_UNSUCCESSFUL`. The requests are completed with `Information` = 0.

> [!NOTE]
> The NULL DACL means any user-mode process can open `\\.\MBB_1` and send both IOCTLs (end the data call, change the NAS setting).

### Supported OIDs

`SupportedOidList` (`.data:0x00444F98`, 70 entries, also returned by `OID_GEN_SUPPORTED_LIST`). Names from `sub_413E70`, which maps an OID to its name for the traces.  
| OIDs | Comment |
|------|---------|
| 0x00010101–0x00010117, 0x00010202, 0x00010207–0x00010209 | `OID_GEN_*` (supported list, hardware status, media, link speed, vendor id/description, packet filter, statistics, `OID_GEN_LINK_STATE`, `OID_GEN_LINK_PARAMETERS`, `OID_GEN_STATISTICS`…) |
| 0x00020101–0x00020106, 0x00020206, 0x0002020C | `OID_GEN_XMIT_OK`, `OID_GEN_RCV_OK`… counters |
| 0x01010101–0x01010105, 0x01020101–0x01020103 | `OID_802_3_*` |
| 0xFD010100–0xFD010102 | `OID_PNP_CAPABILITIES`, `OID_PNP_SET_POWER`, `OID_PNP_QUERY_POWER` |
| 0x0E010100–0x0E010106 | `OID_WWAN_DRIVER_CAPS`, `DEVICE_CAPS`, `READY_INFO`, `RADIO_STATE`, `PIN`, `PIN_LIST`, `HOME_PROVIDER` |
| 0x0E010108–0x0E01010D | `OID_WWAN_VISIBLE_PROVIDERS`, `REGISTER_STATE`, `PACKET_SERVICE`, `SIGNAL_STATE`, `CONNECT`, `PROVISIONED_CONTEXTS` |
| 0x0E01010F–0x0E010113 | `OID_WWAN_SMS_CONFIGURATION`, `SMS_READ`, `SMS_SEND`, `SMS_DELETE`, `SMS_STATUS` |
| 0x0E010115–0x0E010118 | `OID_WWAN_AUTH_CHALLENGE`, `ENUMERATE_DEVICE_SERVICES`, `SUBSCRIBE_DEVICE_SERVICE_EVENTS`, `DEVICE_SERVICE_COMMAND` |
| 0x0E010121 | No name in the driver (`OID_WWAN_PIN_EX` ?) |
| 0x0E010122 | `OID_WWAN_ENUMERATE_DEVICE_SERVICE_COMMANDS` |

`OID_WWAN_PREFERRED_PROVIDERS` (0x0E010107), `OID_WWAN_SERVICE_ACTIVATION` (0x0E01010E) and `OID_WWAN_VENDOR_SPECIFIC` (0x0E010114) are not in the list. The name table also knows a private `OID_GOBI_DEVICE_INFO` (0xF0000001), which is not in the list either.

### ERI files

With `ERIAlgorithm` = 1 or 2, `DriverEntry` (`sub_44AB20`) reads `\DosDevices\C:\WINDOWS\<ERIDataFileName>` (whole file, `ZwOpenFile` + `ZwReadFile`, `sub_411B74`) and parses it (`sub_411D84` for algorithm 1, `sub_412178` for algorithm 2). Algorithm 2 (Sprint ?) also loads `ERISprintIntlRoamDataFileName` (`sub_41254C`). If loading fails, `ERIAlgorithm` is reset to 0.

---

### IOCTL 0x82000

This IOCTL is processed by Qcmbb8930.sys (`sub_41457C`)

| Property | Value |
|----------|-------|
| Device | 0x8 |
| Function | 0x800 (2048) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (set state, end the data call) | ≥ 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 01 or 03 | New state. Other values → `STATUS_INVALID_PARAMETER` (0xC000000D) |
| 01-03 | ? | Not used |

1. Stores the byte at `+0x9000` of **every** adapter (`sub_414FD4`). The driver itself writes 2 there when DMS reports the operating mode "online" and 3 for the modes 2–5 (factory test, offline, resetting, shutting down); with 3 it later sends DMS SET_OPERATING_MODE "online" (`sub_42ADEC`). The meaning of 1 is unknown.
2. If the context activation state of this adapter (`+0x380`) is 2, ends the data call (`sub_42B06C`): WDS STOP_NETWORK_INTERFACE (0x0021) on the IPv4 client when the IP type (`+0x9058`) is 1 (or 3 with IPv4 state `+0x9048` = 2), and on the IPv6 client when the IP type is 2 (or 3 with IPv6 state `+0x9050` = 2).

Returns `STATUS_SUCCESS`, or `STATUS_INVALID_PARAMETER` (0xC000000D) when the InputBuffer is shorter than 4 bytes or the value is wrong.  
The same code exists in `sub_402880` (called from `sub_40228C`, path ?).

---

### IOCTL 0x82004

This IOCTL is processed by Qcmbb8930.sys (`sub_41457C`)

| Property | Value |
|----------|-------|
| Device | 0x8 |
| Function | 0x801 (2049) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (set flags) | ≥ 8 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 02 00 00 00 | Mask, only bits 0–1 allowed |
| 04-07 | e.g. 02 00 00 00 | Value, only bits 0–1 allowed |

Updates the adapter flags `+0x9004` = (flags & ~mask) | (mask & value) (`sub_41502C`). Bit 0 is only stored. Bit 1 (0x2):
- 1 → 0: sends NAS 0x0070 with `{1, 0}`.
- 0 → 1: sends NAS 0x0070 with `{0, 0}`, then NAS 0x004D (GET_SYS_INFO ?) and WDS 0x006B (no TLV).

While bit 1 is clear, `sub_426B74` reports some NAS indications as matching (filter ?). The meaning of the bits (screen / idle state ?) is not known.  
Returns `STATUS_SUCCESS`, or `STATUS_INVALID_PARAMETER` (0xC000000D) for a short buffer or bits above bit 1.

---

### IOCTL 0x1242C

This IOCTL is sent by Qcmbb8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x1242c) (QMI_CTL SET_DATA_FORMAT), synchronously, once per adapter at initialisation (`sub_4063BC`). The handle is opened with `ZwCreateFile("\Device\QMUX")` and the IRP is built by hand (`IoAllocateIrp`).

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| QMI_CTL SET_DATA_FORMAT | \Device\QMUX | 12 | 2 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | QoS header flag: no QoS header |
| 04-05 | 03 00 | Link protocol: 3 = 802.3 and IP |
| 06-07 | ? | Not initialised (stack) |
| 08-0B | e.g. 00 00 00 00 | QMUX port = adapter index |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Link protocol returned by the modem. Not read |

---

### internal IOCTL 0x82003

This internal IOCTL is sent by Qcmbb8930.sys to [qcbamdmux8930.sys](./qcbamdmux8930.md#internal-ioctl-0x82003) (open channel), synchronously (`sub_408618`, IRP built by hand, `Type3InputBuffer` = 16-byte pool copy).

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Open channel | \Device\DMUX | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | Stream 2 |
| 04-07 | e.g. 00 00 00 00 | Channel = adapter index (0–3) |
| 08-0B | ? | RX callback `sub_404E24` (kernel address) |
| 0C-0F | ? | Callback context: the adapter context |

### IRP_MN_QUERY_INTERFACE

Sent by Qcmbb8930.sys to [qcbamdmux8930.sys](./qcbamdmux8930.md#bam-dmux-interface) right after the channel is open (`sub_408740`, `IRP_MJ_PNP`, initial status `STATUS_NOT_SUPPORTED`): `InterfaceType` = `{EA38864C-56D4-4426-B145-AC2E39C2BB72}`, Size 24, Version 1. The 24-byte `INTERFACE` is copied to the DMUX context (`+0x2C`); only the function at offset 0x10 (give back a receive buffer) is used.

---

### Other GUID

Interface waited for before the DMUX channel is opened (`IoRegisterPlugPlayNotification`, the "ready" interface / RPE client GUID of qcbamdmux8930.sys)  
`{CCCB7664-4951-40C3-8EB1-FDA3964A4479}`

BAM DMUX query-interface  
`{EA38864C-56D4-4426-B145-AC2E39C2BB72}`

QMUX interface (qcqmux8930.sys), waited for by the QCCI QMUX transport  
`{7DCB3244-C836-4A0C-A1E9-BD68D385AA2B}`

IPC router interface (qcipcrouter8930.sys), waited for by the QCCI IPC transport  
`{58354DB3-F2A3-406A-A5FD-3EA0D99DDCDB}`
