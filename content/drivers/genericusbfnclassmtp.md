## Genericusbfnclassmtp.sys

Generic USB function class driver (Microsoft, "GenericUsbFn") instance used for the *MTP* (Media Transfer Protocol) USB function interface.  
The binary is byte-identical to [genericusbfnclass.sys](./genericusbfnclass.md) and [genericusbfnclassipoverusb.sys](./genericusbfnclassipoverusb.md): same size (36864 bytes), same MD5 `add2618c05260684daabc0e0b5792cc0`, same internal name `GenericUsbFnClass.sys`, same PDB `genericusbfnclass.pdb`. It is only a copy under another file name, so that it can be installed as a separate service for another USB function interface. It contains no MTP logic and no MTP string: the MTP protocol is implemented by a user-mode client ?  
Everything documented in [genericusbfnclass.sys](./genericusbfnclass.md) applies unchanged: WDF configuration, `EvtDevicePrepareHardware`, `USBFN_CLASS_INFORMATION_PACKET`, the forwarding of the `IOCTL_GENERICUSBFN_*` requests to the lower driver as `IOCTL_INTERNAL_USBFN_*`, and the internal IOCTL 0x2AC022 `IOCTL_INTERNAL_USBFN_GET_CLASS_INFO` it sends.  
The traces still use the prefix `GenericUsbFnClass` (`DbgPrint`), there's no ETW / WPP provider.

There's no device name.  
Symbolic link : `\DosDevices\GenericUsbFn_{61fd7822-e8d4-44c4-9065-aaad0a3beff0}` (GUID = `InterfaceGuid` of the MTP interface returned by `IOCTL_INTERNAL_USBFN_GET_CLASS_INFO`, configured in `HKLM\SYSTEM\CurrentControlSet\Control\USBFN\Interfaces\MTP`; not in the binary)  

Device interface : `\\?\USBFN#MTP#3&1d123fc3&0&00#{61fd7822-e8d4-44c4-9065-aaad0a3beff0}` ? (built from the instance ID below, same form as [genericusbfnclassipoverusb.sys](./genericusbfnclassipoverusb.md))  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\GenericUsbFnClassMtp`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\USBFN\MTP\3&1d123fc3&0&00`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\GenericUsbFnClassMtp` (e.g. observed on the phone):  
| Registry value | value | comment |
|----------------|-------|---------|
| DisplayName | `@UsbFnMtpIfc.inf,%WDFSIMPLE.SVCDESC%;Microsoft Windows Phone USB Device Driver` | REG_SZ |
| ErrorControl | 0x1 | REG_DWORD, SERVICE_ERROR_NORMAL |
| Group | `Extended Base` | REG_SZ |
| ImagePath | `\SystemRoot\System32\drivers\GenericUsbFnClassMtp.sys` | REG_EXPAND_SZ |
| Owners | `UsbFnMtpIfc.inf` | REG_MULTI_SZ, installed by the INF of the MTP USB function interface |
| Start | 0x3 | REG_DWORD, SERVICE_DEMAND_START (loaded by PnP) |
| Tag | 0xf | REG_DWORD |
| Type | 0x1 | REG_DWORD, SERVICE_KERNEL_DRIVER |
| Parameters\Wdf\WdfMajorVersion | 0x1 | REG_DWORD, KMDF 1.11 |
| Parameters\Wdf\WdfMinorVersion | 0xb | REG_DWORD |
| Parameters\Wdf\TimeOfLastSqmLog | e.g. 0x1dd6d68094d65e0 | REG_QWORD, FILETIME written by WDF |
| Enum\0 | `USBFN\MTP\3&1d123fc3&0&00` | REG_SZ, the single device instance (`Count` = 1, `NextInstance` = 1) |

Device instance `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USBFN\MTP\3&1d123fc3&0&00` (e.g. observed on the phone, UTF-16 / FILETIME values decoded):  
| Registry value / property | value | comment |
|---------------------------|-------|---------|
| DeviceDesc | `@UsbFnMtpIfc.inf,%wdfsimpledevice.devicedesc%;Microsoft Windows Phone USB Device Driver` | |
| HardwareID | `USBFN\MTP` | CompatibleIDs is empty |
| LocationInformation | `USBFN` | |
| ClassGUID | `{4d36e97d-e325-11ce-bfc1-08002be10318}` | Setup class "System" |
| Driver | `{4d36e97d-e325-11ce-bfc1-08002be10318}\0071` | |
| Service | `GenericUsbFnClassMtp` | |
| Mfg | `@UsbFnMtpIfc.inf,%stdmfg%;(Standard system devices)` | |
| ContainerID | e.g. `{27794f65-c4c1-11f0-84da-806e6f6e6963}` | |
| Capabilities | 0x86 | CM_DEVCAP_REMOVABLE \| CM_DEVCAP_SILENTINSTALL \| CM_DEVCAP_SURPRISEREMOVALOK |
| UINumber | 0x0 | |
| DeviceCharacteristics | 0x100 | FILE_DEVICE_SECURE_OPEN |
| ConfigFlags | 0x0 | |
| Security | REG_BINARY | Security descriptor of the device |
| Device Parameters\WDF\IdleInWorkingState | 0x1 | Written by WDF (S0 idle enabled, see `AssignS0IdleSettings` in [genericusbfnclass.sys](./genericusbfnclass.md#wdf-configuration)) |
| `{540b947e-8b40-45bc-a8a2-6a0b894cbda2}`,4 | `MTP` | Bus reported device description ? |
| `{540b947e-8b40-45bc-a8a2-6a0b894cbda2}`,7 | `UsbFnMtpIfc.inf:USBFN\MTP,UfnBus_Child_00.NT` | Configuration ID ? |
| `{83da6326-97a6-4088-9453-a1923f573b29}`,3 | `UsbFnMtpIfc.inf:741f41b5817172ec:UfnBus_Child_00.NT:1.1.0.0:USBFN\MTP` | Driver node strong name ? |
| `{83da6326-97a6-4088-9453-a1923f573b29}`,0xA | `ACPI\QCOM01C0\1` | Parent device: the USB function controller |
| `{83da6326-97a6-4088-9453-a1923f573b29}`,0x64 / 0x65 / 0x66 | e.g. 2025-11-18 20:57:21 / 2025-11-18 20:57:21 / 2026-11-05 20:55:48 | Install date / first install date / last arrival date |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,2 | 2011-05-19 | DriverDate |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,3 | `1.1.0.0` | DriverVersion |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,4 | `Microsoft Windows Phone USB Device Driver` | DriverDesc |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,5 | `UsbFnMtpIfc.inf` | DriverInfPath |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,6 | `UfnBus_Child_00.NT` | DriverInfSection |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,8 | `USBFN\MTP` | MatchingDeviceId |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,9 | `Microsoft` | DriverProvider |
| `{a8b865dd-2e3d-4094-ad97-e593a70c75d6}`,0xE | 0x00FF0000 | DriverRank |
| `{80497100-8c73-48b9-aad9-ce387e19c56e}`,6 | 0 | ? |

The device is a child (`USBFN\MTP`) enumerated by the USB function stack of the controller `ACPI\QCOM01C0\1`, one child per configured USB function interface. The instance ID ends in `00` and `UINumber` is 0 here, against `01` and 1 for `USBFN\IpOverUsb`, matching the order of the `InterfaceList` of the `Default` configuration ?  
The INF section name `UfnBus_Child_00` is the same for both interfaces (only the INF differs, the driver node hash `741f41b5817172ec` too is the same), so it is not an interface index.  
There's no parameters read by the driver in the registry (the `Parameters` key only holds the WDF values).  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Lower device of its stack (`WdfDeviceGetIoTarget`) = PDO `USBFN\MTP\3&1d123fc3&0&00`, child of `ACPI\QCOM01C0\1` | USB function class extension [usbfnclx.sys](./usbfnclx.md) / controller driver [usbfnchipidea.sys](./usbfnchipidea.md) | Receives the forwarded `IOCTL_INTERNAL_USBFN_*`, see [genericusbfnclass.sys](./genericusbfnclass.md#ioctl-forwarding) |

### USB function configuration

The MTP interface is declared in `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\USBFN` (e.g. observed on the phone, see [the IP over USB page](./genericusbfnclassipoverusb.md#usb-function-configuration)).

| Item | Value | Comment |
|------|-------|---------|
| Key | `Control\USBFN\Interfaces\MTP` | |
| InterfaceGuid | `{61fd7822-e8d4-44c4-9065-aaad0a3beff0}` | Device-side GUID: `InterfaceGuid` of the class information, used for the symbolic link and the device interface |
| InterfaceDescriptor | `09 04 00 00 03 06 01 01 00 07 05 81 02 00 02 00 07 05 02 02 00 02 00 07 05 83 03 40 00 04` | REG_BINARY, 30 bytes, see below |
| Configuration | `Default` | `Control\USBFN\Configurations\Default`, `InterfaceList` = `MTP`, `IpOverUsb`, `VidStream` |
| Compatible ID | `MTP` | From the `MSOSCompatIdDescriptor` of the `Default` configuration, interface 0: on the PC, the interface is bound to the MTP class and not to WinUSB |

The key only holds `InterfaceDescriptor` and `InterfaceGuid`: unlike IP over USB, there's no `MSOSExtendedPropertyDescriptor`.

InterfaceDescriptor:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-08 | 09 04 00 00 03 06 01 01 00 | `USB_INTERFACE_DESCRIPTOR`: bInterfaceNumber 0, bAlternateSetting 0, bNumEndpoints 3, class/subclass/protocol 0x06/0x01/0x01 (Still Imaging, the PTP class also used by MTP), iInterface 0 |
| 09-0F | 07 05 81 02 00 02 00 | `USB_ENDPOINT_DESCRIPTOR`: endpoint 0x81 (IN 1), bulk, wMaxPacketSize 512, bInterval 0 |
| 10-16 | 07 05 02 02 00 02 00 | `USB_ENDPOINT_DESCRIPTOR`: endpoint 0x02 (OUT 2), bulk, wMaxPacketSize 512, bInterval 0 |
| 17-1D | 07 05 83 03 40 00 04 | `USB_ENDPOINT_DESCRIPTOR`: endpoint 0x83 (IN 3), interrupt, wMaxPacketSize 64, bInterval 4. MTP event pipe ? |

So the interface has 3 pipes (bulk IN, bulk OUT and interrupt IN, the third one being the difference with IP over USB), whose `PipeId`s are then used in the `IOCTL_GENERICUSBFN_TRANSFER_IN` / `_OUT` requests.

On the observed phone `CurrentConfiguration` = `RetailConfig` (`InterfaceList` = `NCSd`) with `IncludeDefaultCfg` = 1, which probably means the `Default` configuration, and so MTP, is offered too ?

### IOCTLs

Processed (user mode → forwarded): 0x22C00D, 0x22C011, 0x22C016, 0x22C018, 0x22C01C, 0x22C022, 0x22C026, 0x22C029, 0x22C02C, 0x22C030, 0x22C036, see [IOCTL forwarding](./genericusbfnclass.md#ioctl-forwarding).  
Sent: internal IOCTL 0x2AC022, see [IOCTL_INTERNAL_USBFN_GET_CLASS_INFO](./genericusbfnclass.md#internal-ioctl-0x2ac022--ioctl_internal_usbfn_get_class_info).  

The user-mode client of this instance (MTP responder ?) opens `\.\GenericUsbFn_{61fd7822-e8d4-44c4-9065-aaad0a3beff0}` or enumerates the device interface `{61fd7822-e8d4-44c4-9065-aaad0a3beff0}` ?

### Interface GUID

MTP device interface class GUID (`InterfaceGuid` returned by the lower driver, registered with `WdfDeviceCreateDeviceInterface`)  
`{61fd7822-e8d4-44c4-9065-aaad0a3beff0}`
