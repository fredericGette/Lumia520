## HidMessageBroker_G2.sys

Nokia "HID message broker" driver, second instance.  
HidMessageBroker_G2.sys is a copy of [HidMessageBroker_G1.sys](./hidmessagebroker_g1.md) installed under another service name: the two files have the same size (39840 bytes), and their code, data, resources and relocations are byte-identical. The only differences are the PE checksum (0x12084 for G1, 0x17F48 for G2) and the Authenticode signature (offsets 0x7800-0x9B9F of the file): the timestamp countersignatures differ (signing times `20140406124720.949Z` for G1 and `20140406124721.125Z` for G2), and so do the serial numbers of the time-stamping certificates.  
Even the PDB path is the same: `C:\CI\M\14993\bldBLUE_GROUP1\bldl2hidmessagebroker\Hidmessagebroker\Solution\ARM\Release\HidMessageBrokerDriver.pdb`. So the build path `bldBLUE_GROUP1` doesn't mean "G1".

Everything documented in [HidMessageBroker_G1.sys](./hidmessagebroker_g1.md) applies to this driver, at the same addresses: WDF configuration, services, HID descriptors and report formats, control device IOCTLs 0x222004 / 0x222008 / 0x22200C / 0x222010, and HID internal IOCTLs.  
The two instances differ only in the registry configuration they select. `LoadConfig` (0x402220) enumerates the subkeys of `HKEY_LOCAL_MACHINE\SYSTEM\OEM\Nokia\HidMessageBroker` and uses the first one whose `DriverServiceName` equals the driver's service key name. Each instance therefore gets its own VID/PID, control device name and symbolic link, and creates its own root-enumerated HID device. Its services and messages are separate from those of the other instance.

Device name : from the registry value `DriverDeviceName` of the matching subkey (control device)  
Symbolic link : from the registry value `DriverSymbolicName` of the matching subkey (control device)  
Security descriptor of the control device: `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GRGW;;;WD)(A;;GR;;;RC)` (Everyone can read/write).  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\OEM\Nokia\HidMessageBroker\<subkey>`:  
| Registry value | value | comment |
|----------------|-------|---------|
| DriverServiceName | ? | REG_SZ. Must be equal (case-insensitive) to the service name of this driver (probably `HidMessageBroker_G2` ?) |
| VID | ? | REG_DWORD. Vendor id of the HID device (truncated to 16 bits). Must not be 0 |
| PID | ? | REG_DWORD. Product id of the HID device (truncated to 16 bits). Must not be 0 |
| DriverDeviceName | ? | REG_SZ, max 128 bytes. Name of the control device. Must not be empty |
| DriverSymbolicName | ? | REG_SZ, max 128 bytes. Symbolic link of the control device. Must not be empty |

GUID of the ETW provider (same as G1):  
`{eb02a8f2-bd77-434a-b5a5-875398ff4265}`  

GUID of the WPP control provider (same as G1):  
`{76198e11-adb2-46d7-9845-2e9848310762}`  

> [!NOTE]
> Both instances register the same ETW and WPP providers and log the same messages. Only the device pointers (`Created device: 0x%p`) and the configuration line (`Loaded configuration: <vid: ... pid: ... deviceName: ... symbolicName: ...>`) show which instance wrote a trace.

Pool allocations use the same tag as G1, `HMBT` (0x54424D48).

It doesn't communicate with any other device.
