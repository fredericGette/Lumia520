## Genericusbfnclassipoverusb.sys

Generic USB function class driver (Microsoft, "GenericUsbFn") instance used for the *IP over USB* USB function interface.  
The binary is byte-identical to [genericusbfnclass.sys](./genericusbfnclass.md) (and to [genericusbfnclassmtp.sys](./genericusbfnclassmtp.md)): same size (36864 bytes), same MD5 `add2618c05260684daabc0e0b5792cc0`, same internal name `GenericUsbFnClass.sys`, same PDB `genericusbfnclass.pdb`, same build `Jan 23 2015 18:07:53`. It is only a copy under another file name, so that it can be installed as a separate service for another USB function interface.  
Everything documented in [genericusbfnclass.sys](./genericusbfnclass.md) applies unchanged: WDF configuration, `EvtDevicePrepareHardware`, `USBFN_CLASS_INFORMATION_PACKET`, the forwarding of the `IOCTL_GENERICUSBFN_*` requests to the lower driver as `IOCTL_INTERNAL_USBFN_*`, and the internal IOCTL 0x2AC022 `IOCTL_INTERNAL_USBFN_GET_CLASS_INFO` it sends.  
The traces still use the prefix `GenericUsbFnClass` (`DbgPrint`), there's no ETW / WPP provider.

There's no device name.  
Symbolic link : `\DosDevices\GenericUsbFn_{30613563-7df3-4afb-80e0-e8c427c7e9bf}` (GUID = `InterfaceGuid` of the IP over USB interface returned by `IOCTL_INTERNAL_USBFN_GET_CLASS_INFO`, configured in `HKLM\SYSTEM\CurrentControlSet\Control\USBFN\Interfaces\IpOverUsb`, see [USB function configuration](#usb-function-configuration); not in the binary)  
Device interface : `\\?\USBFN#IpOverUsb#3&1d123fc3&0&01#{30613563-7df3-4afb-80e0-e8c427c7e9bf}`  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\GenericUsbFnClassIpOverUsb`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\USBFN\IpOverUsb\3&1d123fc3&0&01`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\GenericUsbFnClassIpOverUsb` (e.g. observed on the phone):  
| Registry value | value | comment |
|----------------|-------|---------|
| DisplayName | `@UsbFnIpOverUsbIfc.inf,%WDFSIMPLE.SVCDESC%;Microsoft Windows Phone USB Device Driver` | REG_SZ |
| ErrorControl | 0x1 | REG_DWORD, SERVICE_ERROR_NORMAL |
| Group | `Extended Base` | REG_SZ |
| ImagePath | `\SystemRoot\System32\drivers\GenericUsbFnClassIpOverUsb.sys` | REG_EXPAND_SZ |
| Owners | `UsbFnIpOverUsbIfc.inf` | REG_MULTI_SZ, installed by the INF of the IP over USB USB function interface |
| Start | 0x3 | REG_DWORD, SERVICE_DEMAND_START (loaded by PnP) |
| Tag | 0xf | REG_DWORD |
| Type | 0x1 | REG_DWORD, SERVICE_KERNEL_DRIVER |
| Parameters\Wdf\WdfMajorVersion | 0x1 | REG_DWORD, KMDF 1.11 |
| Parameters\Wdf\WdfMinorVersion | 0xb | REG_DWORD |
| Parameters\Wdf\TimeOfLastSqmLog | e.g. 0x1dd6c8dcd9330a2 | REG_QWORD, FILETIME written by WDF |
| Enum\0 | `USBFN\IpOverUsb\3&1d123fc3&0&01` | REG_SZ, the single device instance (`Count` = 1, `NextInstance` = 1) |

Device instance `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USBFN\IpOverUsb\3&1d123fc3&0&01` (e.g. observed on the phone, UTF-16 / FILETIME values decoded):  
| Registry value / property | value | comment |
|---------------------------|-------|---------|
| DeviceDesc | `@UsbFnIpOverUsbIfc.inf,%wdfsimpledevice.devicedesc%;Microsoft Windows Phone USB Device Driver` | |
| HardwareID | `USBFN\IpOverUsb` | No CompatibleIDs |
| LocationInformation | `USBFN` | |
| ClassGUID | `{4d36e97d-e325-11ce-bfc1-08002be10318}` | Setup class "System" |
| Driver | `{4d36e97d-e325-11ce-bfc1-08002be10318}\0072` | |
| Service | `GenericUsbFnClassIpOverUsb` | |
| Mfg | `@UsbFnIpOverUsbIfc.inf,%stdmfg%;(Standard system devices)` | |
| ContainerID | e.g. `{27794f66-c4c1-11f0-84da-806e6f6e6963}` | |
| Capabilities | 0x86 | CM_DEVCAP_REMOVABLE \| CM_DEVCAP_SILENTINSTALL \| CM_DEVCAP_SURPRISEREMOVALOK |
| UINumber | 0x1 | |
| DeviceCharacteristics | 0x100 | FILE_DEVICE_SECURE_OPEN |
| ConfigFlags | 0x0 | |
| Security | REG_BINARY | Security descriptor of the device |
| Device Parameters\WDF\IdleInWorkingState | 0x1 | Written by WDF (S0 idle enabled, see `AssignS0IdleSettings` in [genericusbfnclass.sys](./genericusbfnclass.md#wdf-configuration)) |
| `{540b947e-8b40-45bc-a8a2-6a0b894cbda2}`,4 | `IpOverUsb` | Bus reported device description ? |
| `{540b947e-8b40-45bc-a8a2-6a0b894cbda2}`,7 | `UsbFnIpOverUsbIfc.inf:USBFN\IpOverUsb,UfnBus_Child_00.NT` | Configuration ID ? |
| `{83da6326-97a6-4088-9453-a1923f573b29}`,3 | `UsbFnIpOverUsbIfc.inf:741f41b5817172ec:UfnBus_Child_00.NT:1.1.0.0:USBFN\IpOverUsb` | Driver node strong name ? |
| `{83da6326-97a6-4088-9453-a1923f573b29}`,0xA | `ACPI\QCOM01C0\1` | Parent device: the USB function controller |
| `{83da6326-97a6-4088-9453-a1923f573b29}`,0x64 / 0x65 / 0x66 | e.g. 2025-11-18 20:57:21 / 2025-11-18 20:57:21 / 2026-11-04 20:27:41 | Install date / first install date / last arrival date |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,2 | 2011-05-19 | DriverDate |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,3 | `1.1.0.0` | DriverVersion |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,4 | `Microsoft Windows Phone USB Device Driver` | DriverDesc |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,5 | `UsbFnIpOverUsbIfc.inf` | DriverInfPath |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,6 | `UfnBus_Child_00.NT` | DriverInfSection |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,8 | `USBFN\IpOverUsb` | MatchingDeviceId |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,9 | `Microsoft` | DriverProvider |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,0xE | 0x00FF0000 | DriverRank |
| `{80497100-8c73-48b9-aad9-ce387e19c56e}`,6 | 0 | ? |

The device is a child (`USBFN\IpOverUsb`) enumerated by the USB function stack of the controller `ACPI\QCOM01C0\1`, one child per configured USB function interface. The INF section name `UfnBus_Child_00` is not an interface index: [genericusbfnclassmtp.sys](./genericusbfnclassmtp.md) uses the same section, the index is in the instance ID (`00` for MTP, `01` here) ?  
There's no parameters read by the driver in the registry (the `Parameters` key only holds the WDF values).  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device of its stack (`WdfDeviceGetIoTarget`) = PDO `USBFN\IpOverUsb\3&1d123fc3&0&01`, child of `ACPI\QCOM01C0\1` | USB function class extension (UFX) / controller driver ? | Receives the forwarded `IOCTL_INTERNAL_USBFN_*`, see [genericusbfnclass.sys](./genericusbfnclass.md#ioctl-forwarding) |

### USB function configuration

The IP over USB interface is declared in `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\USBFN` (e.g. observed on the phone). This is where the lower driver takes the `USBFN_CLASS_INFORMATION_PACKET` returned by [internal IOCTL 0x2AC022](./genericusbfnclass.md#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info) ?

Key `Control\USBFN\Interfaces\IpOverUsb`:  
| Registry value | value | comment |
|----------------|-------|---------|
| InterfaceGuid | `{30613563-7df3-4afb-80e0-e8c427c7e9bf}` | REG_SZ. Device-side GUID: `InterfaceGuid` of the class information, used for the symbolic link and the device interface |
| InterfaceDescriptor | `09 04 00 00 02 FF FF FF 00 07 05 81 02 00 02 00 07 05 02 02 00 02 00` | REG_BINARY, see below |
| MSOSExtendedPropertyDescriptor | 372 bytes | REG_BINARY, sent to the host, see below |

InterfaceDescriptor:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-08 | 09 04 00 00 02 FF FF FF 00 | `USB_INTERFACE_DESCRIPTOR`: bInterfaceNumber 0 (renumbered by UFX in a composite configuration ?), bAlternateSetting 0, bNumEndpoints 2, class/subclass/protocol 0xFF/0xFF/0xFF (vendor specific), iInterface 0 |
| 09-0F | 07 05 81 02 00 02 00 | `USB_ENDPOINT_DESCRIPTOR`: endpoint 0x81 (IN 1), bulk, wMaxPacketSize 512, bInterval 0 |
| 10-16 | 07 05 02 02 00 02 00 | `USB_ENDPOINT_DESCRIPTOR`: endpoint 0x02 (OUT 2), bulk, wMaxPacketSize 512, bInterval 0 |

So the interface has 2 pipes (one bulk IN, one bulk OUT), whose `PipeId`s are then used in the `IOCTL_GENERICUSBFN_TRANSFER_IN` / `_OUT` requests.

MSOSExtendedPropertyDescriptor (Microsoft OS 1.0 extended properties, `wIndex` 5, version 0x0100, 5 properties, decoded):  
| Property | Type | Value | Comment |
|----------|------|-------|---------|
| DeviceInterfaceGUID | REG_SZ | `{26fedc4e-6ac3-4241-9e4d-e3d4b2c5c534}` | Host-side (PC) WinUSB device interface GUID of IP over USB, used by the PC tools to find the phone |
| DeviceIdleEnabled | REG_DWORD | 1 | WinUSB selective suspend on the host |
| DefaultIdleState | REG_DWORD | 1 | |
| DefaultIdleTimeout | REG_DWORD | 10000 | ms |
| UserSetDeviceIdleEnabled | REG_DWORD | 1 | |

The interface is part of the `Default` configuration (`Control\USBFN\Configurations\Default`, `InterfaceList` = `MTP`, `IpOverUsb`, `VidStream`). Its `MSOSCompatIdDescriptor` gives the compatible ID `MTP` to interface 0 and `WINUSB` to interfaces 1 (IpOverUsb) and 2 (VidStream): on the PC, IP over USB is bound to WinUSB.  
On the observed phone `CurrentConfiguration` = `RetailConfig` (`InterfaceList` = `NCSd`) with `IncludeDefaultCfg` = 1, which probably means the `Default` configuration is offered too ?

Other interfaces declared in `Control\USBFN\Interfaces` (each is a `USBFN\<name>` child handled by its own function driver):  
| Interface | InterfaceGuid | Configuration |
|-----------|---------------|---------------|
| [MTP](./genericusbfnclassmtp.md) | `{61fd7822-e8d4-44c4-9065-aaad0a3beff0}` | Default |
| IpOverUsb | `{30613563-7df3-4afb-80e0-e8c427c7e9bf}` | Default |
| VidStream | `{31648E59-6FCB-4D81-9C97-D00999B0459A}` | Default, VidStream |
| NCSd | `{7eaff726-34cc-4204-b09d-f95471b873cf}` | RetailConfig |
| DIAG | `{3641691D-B4BD-4715-BB46-641FD214E147}` | RmNetCompositeConfig, SerialCompositeConfig |
| NMEA_NET | `{AA557611-9DB7-4810-88E6-DD03614D1003}` | RmNetCompositeConfig |
| MODEM_NET | `{22D4FC94-E43E-4FED-8057-729191CE71D5}` | RmNetCompositeConfig |
| RMNET | `{26884C7E-E24A-4FB6-8C75-00F8CD924A3D}` | RmNetCompositeConfig |
| MODEM_SER | `{A01FDE7F-640E-4981-BB7C-58FC4860896B}` | SerialCompositeConfig |
| NMEA_SER | `{A15D6AFA-C85D-426F-A79A-1DBBF17CFD2F}` | SerialCompositeConfig |
| TRACE | `{23238082-6DB8-4A76-8693-635F0093282A}` | SerialCompositeConfig |

USB device identity: `Control\USBFN` (retail) VID 0x0421 / PID 0x0661, "Nokia" / "Nokia Lumia 520 (RM-914)"; `Control\USBFN\Default` VID 0x045E / PID 0xF0CA, "Microsoft" / "Windows Phone 8", bcdDevice 0x0001.

### IOCTLs

Processed (user mode → forwarded): 0x22C00D, 0x22C011, 0x22C016, 0x22C018, 0x22C01C, 0x22C022, 0x22C026, 0x22C029, 0x22C02C, 0x22C030, 0x22C036, see [IOCTL forwarding](./genericusbfnclass.md#ioctl-forwarding).  
Sent: internal IOCTL 0x2AC022, see [IOCTL_INTERNAL_USBFN_GET_CLASS_INFO](./genericusbfnclass.md#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info).  

The user-mode client of this instance is the IP over USB service (`IpOverUsbSvc` ?), which opens `\\.\GenericUsbFn_{30613563-7df3-4afb-80e0-e8c427c7e9bf}` or enumerates the device interface `{30613563-7df3-4afb-80e0-e8c427c7e9bf}` ?

### Interface GUID

IP over USB device interface class GUID (`InterfaceGuid` returned by the lower driver, registered with `WdfDeviceCreateDeviceInterface`; observed in `HKLM\SYSTEM\CurrentControlSet\Control\DeviceClasses`)  
`{30613563-7df3-4afb-80e0-e8c427c7e9bf}`

IP over USB host-side (PC, WinUSB) device interface GUID, from the MS OS extended property descriptor  
`{26fedc4e-6ac3-4241-9e4d-e3d4b2c5c534}`
