## SOCProdTest.sys

SoC production test module: it checks that the device has been locked down in the factory.  
It reads 4 registers of the QFPROM (fuses) and reports whether the secure boot fuse and the JTAG fuses are blown, whether the SHK (Secondary Hardware Key ?) is provisioned and whether a JTAG override is present.  
This isn't a real device driver. It's a kernel-mode export driver (`IMAGE_FILE_DLL`, native subsystem, imports only `MmMapIoSpace` and `MmUnmapIoSpace`): it creates no device and installs no dispatch routine. The test can only run if another kernel-mode component imports `ProdTestDeviceControl` and calls it with an IRP.  
The PDB name is `socprodtest_8960.pdb`: the module was built for the MSM8960 family, and nothing in it is specific to the MSM8930.  

Device name : none  
Symbolic link : none  

There's no parameters in the registry.

There's no ETW provider, no interface GUID and no log output.

It doesn't communicate with any other device. It accesses the hardware directly.

> [!NOTE]
> No caller of `ProdTestDeviceControl` was found: no other binary in the analysed files references `SOCProdTest` or `ProdTestDeviceControl`, and no driver page mentions the IOCTL code. User mode can't reach this code directly, because the module has no device object.

### Exports

| Name | Ordinal | Address | Comment |
|------|---------|---------|---------|
| DllInitialize | 1 | 0x10003000 | Stub, returns `STATUS_SUCCESS` |
| DllUnload | 2 | 0x10003000 | Same stub as DllInitialize |
| ProdTestDeviceControl | 3 | 0x10003130 | See [IOCTL 0x22E014](#ioctl-0x22e014) |

The entry point `FxDriverEntry` (0x10001254) initialises the stack cookie, then calls the same stub at 0x10003000. `DriverObject` isn't modified.

### Physical memory

Region mapped with `MmMapIoSpace` (non-cached) for the duration of the test, then unmapped:  
| Address | Size | Function | Comment |
|---------|------|----------|---------|
| 0x00700000 | 0x8000 | sub_1000300C | QFPROM. Same region as [qcpep8930.sys](./qcpep8930.md), and as the ACPI resource `SE_CTRL_REGS` of [qcdxkm8930.sys](./qcdxkm8930.md) |

The module only reads these registers, it never writes to them:  
| Physical address | Offset | Test passes if | Failure message |
|------------------|--------|----------------|-----------------|
| 0x00706038 | 0x6038 | Bit 5 = 1 | `TEST FAIL: SOC Secure Boot Fuse has not been blown\n` |
| 0x00706024 | 0x6024 | Bits 18, 19, 20, 22, 23, 24, 27 and 28 = 1 (`value & 0x19DC0000 == 0x19DC0000`) | `TEST FAIL: JTAG Fuses have not been blown\n` |
| 0x00702050 | 0x2050 | Bit 0 = 1 | `TEST FAIL: SHK has not been provisioned\n` |
| 0x007060C0 | 0x60C0 | Whole register = 0 | `TEST FAIL: JTAG override is present\n` |

The role of each bit comes only from the failure messages. The binary gives no individual meaning for the 8 JTAG bits.

---

### IOCTL 0x22E014

This IOCTL is processed by SOCProdTest.sys, in the exported function `ProdTestDeviceControl`.  
It's the only code accepted. The sender is unknown.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x805 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SoC production test | ignored | 1028 minimum |

Prototype (tentative):  
`NTSTATUS ProdTestDeviceControl(PDEVICE_OBJECT DeviceObject ?, PIRP Irp)`  
The first parameter is never used.

The input buffer isn't read.

Outputbuffer (`Irp->AssociatedIrp.SystemBuffer`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | All the tests passed |
| 00-03 | 00 00 00 00 | At least one test failed |
| 04-403 | ? | NUL-terminated ASCII string: the failure messages concatenated in the order of the table above. Empty string if all the tests passed. |

Steps of the handler `sub_1000300C`:  
1. Rejects an `OutputBufferLength` lower than 1028.
2. Maps the QFPROM.
3. Reads the 4 registers.
4. Writes 1 to the result field and an empty string to the message field.
5. Evaluates all 4 tests, without stopping at the first failure. Each failure sets the result field to 0 and appends its message with `sub_100011E0`, an inlined `RtlStringCbCatA` with a fixed size of 1024 bytes.
6. Sets `Irp->IoStatus.Information` to 1028 and unmaps the QFPROM.

| NTSTATUS | Condition | `IoStatus.Information` |
|----------|-----------|------------------------|
| `STATUS_SUCCESS` | The tests ran, **even if some of them failed** | 1028 |
| `STATUS_INVALID_PARAMETER` (0xC000000D) | Other IOCTL code, or `OutputBufferLength` lower than 1028 | 0 |
| `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A) | `MmMapIoSpace` failed | 0 |

> [!NOTE]
> The caller must read the result field: the NTSTATUS doesn't tell whether the device passed the tests. The function only returns the NTSTATUS. It doesn't set `Irp->IoStatus.Status` and doesn't call `IoCompleteRequest`, so the caller has to complete the IRP itself.

On ARM the `Parameters` union of `IO_STACK_LOCATION` starts at offset 8, because it contains 64-bit members. So the handler's reads at offsets 0x08 and 0x10 are `OutputBufferLength` and `IoControlCode`.
