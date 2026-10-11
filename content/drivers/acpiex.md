## Acpiex.sys

Microsoft Resource Hub driver (`base\basedrv\reshub`, KMDF, PDB symbols available).  
It is the broker between the ACPI firmware description and the "simple peripheral" controllers: GPIO (GpioClx) and SPB (SpbCx: I²C, SPI, UART). It does three things:
1. It keeps a cache of the **connection resources** (`GpioIo`, `GpioInt`, `I2cSerialBus`, `SpiSerialBus`… in `_CRS`) translated by [acpi.sys](./acpi.md) into `CmResourceTypeConnection` (0x84) descriptors, each one with a 64-bit connection id.
2. It lets a peripheral driver open its connection with the path `\Device\RESOURCE_HUB\<16-hex-digit id>` (the `RESOURCE_HUB_CREATE_PATH_FROM_ID` path); the open is **reparsed** to the controller device.
3. It implements the ACPI `GeneralPurposeIO` (8) and `GenericSerialBus` (9) operation regions, so AML code (e.g. a `_PS0` toggling a GPIO, or a battery/PMIC method talking I²C) can access GPIO pins and SPB devices.

acpiex.sys is not a PnP driver: `DriverEntry` creates a single WDF control device. acpi.sys opens it (and loads the `acpiex` service with `ZwLoadDriver` if needed), sends IOCTL 0x2AC028 to exchange function tables, and acpiex.sys then registers its operation-region handlers on the ACPI root device.

Device name : `\Device\RESOURCE_HUB`  
Symbolic link : `\DosDevices\RESOURCE_HUB` (`RhpInitialize`)  
Security descriptor : `D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;UD)` (System, Administrators, and UMDF drivers (`UD`))  
I/O type : buffered. The default queue is sequential; read and write requests fail with `STATUS_INVALID_DEVICE_REQUEST` (`RhEvtProcessReadRequest`).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\acpiex`

There's no parameters in the registry.

GUID of the ETW provider:  
`{9F068318-A1B6-4E76-8CFD-7F47886F8DE6}` (WPP control GUID `RhTraceGuid`, recorded with WppRecorder.sys / IFR)

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI root PDO (given by acpi.sys in IOCTL 0x2AC028) | [acpi.sys](./acpi.md) | `IOCTL_ACPI_REGISTER_OPREGION_HANDLER`, `IOCTL_ACPI_ASYNC_EVAL_METHOD_EX`, register device firmware lock (0x32C030) |
| Each GPIO / SPB controller PDO | acpi.sys | `IOCTL_ACPI_QUERY_DEVICE_BIOS_NAME` (0x32C024) to match the controller with the `ResourceSource` name of the descriptor |
| `<controller PDO name>\ACPI\<id>` | GPIO controller driver (GpioClx client) | `IOCTL_GPIO_READ_PINS` / `IOCTL_GPIO_WRITE_PINS` for the `GeneralPurposeIO` operation region |
| `<controller PDO name>\ACPI\<id>` | SPB controller driver (SpbCx client: I²C, SPI…) | SPB sequence IOCTL 0x41808 for the `GenericSerialBus` operation region |
| — | Peripheral drivers | Open `\Device\RESOURCE_HUB\<id>`; send `IOCTL_RH_QUERY_CONNECTION_PROPERTIES` |

### Opening a connection: `\Device\RESOURCE_HUB\<id>`

`RhWdmDeviceFileCreate` is a WDM pre-process callback on `IRP_MJ_CREATE`. When the file name is not empty, `RhpBuildReparseName`:
1. drops the leading `\`, and requires at least 16 hex digits followed by the end of the string or `\`. The first 8 digits are the high dword of the connection id, the next 8 the low dword (`%0*I64x` with width 16, i.e. `IdHighPart` then `IdLowPart` of the `CM_PARTIAL_RESOURCE_DESCRIPTOR` of type `CmResourceTypeConnection`);
2. looks the id up in `RhConnectionListHead` (`0xC0000225 STATUS_NOT_FOUND` otherwise), and connects the provider (controller) if it isn't yet (`RhpConnectProviderDevice`);
3. builds `<controller PDO name>\<original name>` (`"%s\\%s"`, e.g. `\Device\0000004a\00000000000000A1`) and calls `IoReplaceFileObjectName`, then completes the create with **`STATUS_REPARSE` (260)**.

The object manager then opens the controller directly: the I/O between a driver and its GPIO pin / I²C slave never goes through acpiex.sys. Opening `\Device\RESOURCE_HUB` without a file name succeeds and gives access to the IOCTLs below.

For its own accesses (operation regions), acpiex.sys opens the controller by name with `"%s\\%s\\%s"` = `<controller PDO name>\ACPI\<16 hex digits>`.

### Operation regions

Registered once by `RhpProcessTranslationInterfaceQueryIoctl` → `RhpRegisterOpRegionHandlers`:  
| RegionSpace | ACPI name | Handler | Backend |
|-------------|-----------|---------|---------|
| 8 | GeneralPurposeIO | `RhGpioOperationRegionHandler` | `RhpGpioRegionSpaceAccess`: `IOCTL_GPIO_WRITE_PINS` / `IOCTL_GPIO_READ_PINS` to the controller, bits shifted with `RhpCopyMemoryBitOffset` |
| 9 | GenericSerialBus | `RhSerialBusOperationRegionHandler` | `RhpSerialBusRegionSpaceAccess` → `RhpSendSpbIoctl` |

The connection used by a field (`Connection (I2cSerialBus(…))` / `Connection (GpioIo(…))` in ASL) is resolved by evaluating it with `IOCTL_ACPI_ASYNC_EVAL_METHOD_EX` (`RhpGetRegionConnectionData`, input signature `'AeiA'`, name of the connection object), then translated and cached (`RhpTranslateAndCacheConnection`). Accesses are queued and processed in a work item (`RhpEvtOpRegionProcessRegionSpaceWorkItem`).

GenericSerialBus access protocols (`AccessAs` attribute, byte `+0x0A` of the request), as handled by `RhpSerialBusRegionSpaceAccess`. The AML buffer is `00` status (0 = success, 1 = error), `01` length, `02-…` data:  
| Value | ACPI attribute | Transfer |
|-------|----------------|----------|
| 0x02 | AttribQuick | No data |
| 0x04 | AttribSendReceive | 1 byte, no command |
| 0x06 | AttribByte | Command + 1 byte |
| 0x08 | AttribWord | Command + 2 bytes |
| 0x0A | AttribBlock | Command + length from the buffer (`01`) |
| 0x0B | AttribBytes(n) | Command + n bytes (n from the field) |
| 0x0C | AttribProcessCall | Write 2 bytes then read 2 bytes |
| 0x0D | AttribBlockProcessCall | Write then read, length from the buffer |
| 0x0E | AttribRawBytes(n) | n bytes, no command |
| 0x0F | AttribRawProcessBytes(n) | Write then read, no command |

Other values → `STATUS_NOT_SUPPORTED`. The "command" is the field offset (+ region offset) in bytes, sent as the first write transfer.

### Device firmware lock

`RhpRegisterDeviceFirmwareLockHandler` registers `RhpDeviceFirmwareLockHandler` with acpi.sys (IOCTL 0x32C030, signature `'ADfR'`, version 1, `+08` = 0x84, handler at `+10`, context at `+14`). Operation 0 accepts only descriptors of type 0x84 (`CmResourceTypeConnection`) of class 2 (serial bus) and is processed asynchronously; 1 = delete, 2 = acquire, 3 = release. Purpose: let the firmware (AML) and the OS driver share an SPB controller ?

---

### IOCTL 0x2AC000 — IOCTL_RH_QUERY_CONNECTION_PROPERTIES

This IOCTL is processed by Acpiex.sys

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x0 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_RH_QUERY_CONNECTION_PROPERTIES | ≥ 16 | ≥ 12 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Version ? (not checked) |
| 04-07 | 00 00 00 00 / 01 00 00 00 | Query type: 0 = by connection id, 1 = by interrupt vector (GSIV of a `GpioInt`). Other → `0xC00000BB STATUS_NOT_SUPPORTED` |
| 08-0F | | Type 0: 64-bit connection id (`IdLowPart`, `IdHighPart`). Type 1: GSIV at 08-0B |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version |
| 04-07 | | Length of the properties |
| 08-… | | Connection properties: copy of the cached ACPI connection data (the raw `_CRS` descriptor, `RH_QUERY_CONNECTION_PROPERTIES_OUTPUT_BUFFER` ?) |

When the output is too small: `0xC0000023 STATUS_BUFFER_TOO_SMALL`, the length is still written at 04-07 and 8 bytes are returned. Unknown id → `0xC0000225 STATUS_NOT_FOUND`.  
SPB drivers (SpbCx) use this to get the I²C slave address, speed etc. of a connection opened through `\Device\RESOURCE_HUB\<id>`.

---

### IOCTL 0x2AC028 — query translator interface

This IOCTL is processed by Acpiex.sys (sent by [acpi.sys](./acpi.md#ioctl-0x2ac028--query-resource-hub-translator-interface) `QueryExternalTranslatorInterface`)

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0xA |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | ≥ 56 | ≥ 56 |

Inputbuffer (filled by acpi.sys):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 38 00 | Size (56) |
| 02-03 | 01 00 | Version |
| 10-11 | 28 00 | Offset of the ACPI block below (must be ≤ Size − 16) |
| 28-2B | | ACPI root PDO: acpiex.sys opens a WDF I/O target on it (`RhpConnectToAcpi`, kept in `AcpiConnection`) |
| 2C-2F | | `AcpiExternalInterfaceUnload` → `RHUnloadTranslationInterface` |
| 30-33 | | `AcpiGetFullyQualifiedBiosName` → `RHGetFullyQualifiedBiosName` |
| 34-37 | | `AcpiAllocateGsivForSecondaryInterrupt` → `RHAllocateNewSecondaryInterruptGsivImport` |

Outputbuffer (same buffer, zeroed then filled by `RhpProcessTranslationInterfaceQueryIoctl`; 56 bytes returned):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 38 00 | Size (56) |
| 02-03 | 01 00 | Version |
| 08-0B, 0C-0F | | InterfaceReference / InterfaceDereference = `WdfDeviceInterfaceDereferenceNoOp` |
| 10-11 | 28 00 | ? |
| 14-17 | | WDM device object of `\Device\RESOURCE_HUB` |
| 1C-1F | | `RhTranslateBiosToNtResources`: converts `_CRS` GPIO/serial-bus descriptors into connection resources (acpi.sys requires it non-zero) |
| 20-23 | | `RhBiosNameToDeviceCallback` (= `RhpConnectProviderDevice`): binds an ACPI name to a controller device |
| 24-27 | | `RhQueryTranslatedDescriptorForGsiv`: interrupt descriptor of a `GpioInt` from its secondary GSIV |

On the first call acpiex.sys also connects to the ACPI root PDO and registers its operation-region and firmware-lock handlers (see above).

---

### IOCTLs sent by acpiex.sys

| IOCTL | Name | Device name | InputBuffer size | OutputBuffer Size |
|-------|------|-------------|------------------|-------------------|
| 0x32C008 | IOCTL_ACPI_REGISTER_OPREGION_HANDLER | ACPI root PDO | 20 | 8 |
| 0x32C01C | IOCTL_ACPI_ASYNC_EVAL_METHOD_EX | ACPI root PDO, or the device of the operation region | 260 | ? |
| 0x32C024 | IOCTL_ACPI_QUERY_DEVICE_BIOS_NAME | Controller PDO | 0 | 128 bytes, retried once with the size returned |
| 0x32C030 | register device firmware lock | ACPI root PDO | 24 | 0 |
| 0x480000 | IOCTL_GPIO_READ_PINS | `<controller>\ACPI\<id>` | 0 | data |
| 0x480004 | IOCTL_GPIO_WRITE_PINS | `<controller>\ACPI\<id>` | data | 0 |
| 0x41808 | IOCTL_SPB_EXECUTE_SEQUENCE ? | `<controller>\ACPI\<id>` | 88 (`SPB_TRANSFER_LIST` ?, up to 3 transfers) | 0 |

`IOCTL_ACPI_REGISTER_OPREGION_HANDLER` input (`RhpRegisterOpRegionHandler`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 6F 48` 'AeoH' | Signature |
| 04-07 | 01 00 00 00 | AccessType |
| 08-0B | 08 00 00 00 / 09 00 00 00 | RegionSpace: GeneralPurposeIO / GenericSerialBus |
| 0C-0F | | Handler (`RhGpioOperationRegionHandler` / `RhSerialBusOperationRegionHandler`) |
| 10-13 | | Context (the WDM device object of the I/O target ?) |

The 8-byte output (`'AroH'` + handle) is kept in `RhpOpRegionGpioUnregistrationInfo` / `RhpOpRegionSpbUnregistrationInfo` for `IOCTL_ACPI_UNREGISTER_OPREGION_HANDLER` at unload.

SPB sequence (`RhpSendSpbIoctl`, the transfers are built from the access protocol above): an optional write transfer with the command byte(s), then a write or a read transfer with the data. The number of bytes actually read is returned to AML in byte `01` of its buffer (clamped to 255).
