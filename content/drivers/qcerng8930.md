## Qcerng8930.sys

Hardware Random Number Generator driver (Qualcomm PRNG).  
It registers the PRNG of the SoC as an entropy source of the kernel CNG (`cng.sys`, `EntropyRegisterSource` / `EntropyRegisterCallback`). When CNG asks for entropy, the callback switches on the PRNG clock, reads 64 bytes from the PRNG data register and gives them to CNG with `EntropyProvideData`.  
It doesn't expose any IOCTL and doesn't communicate with any other driver. It imports `ntoskrnl.exe`, `cng.sys` and `WDFLDR.SYS`.  
PDB path: `P:\qsecuremsm\rel\8.3.1\arm\Release\qcerng8930.pdb`.

There's no device name and no symbolic link.  

There's no parameters in the registry.  

GUID of the ETW provider (WPP):  
`{71c8ccb6-70e5-45cc-bae6-36302800d448}`  

It doesn't communicate with any other device.

### WDF configuration

`DriverEntry` (0x406008): `WdfDriverCreate` with `EvtDriverDeviceAdd` = `sub_405350`, `EvtDriverUnload` = 0x4054C0 (WPP cleanup only), pool tag `qrn0`.

`EvtDriverDeviceAdd` (0x405350):
- PnP callbacks: `EvtDevicePrepareHardware` (`sub_401030`), `EvtDeviceReleaseHardware` (`sub_401154`), `EvtDeviceSurpriseRemoval` (`sub_401160`).
- Device context `DEVICE_CONTEXT` (one DWORD, set to 0, never used).
- `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
- No I/O queue: the device doesn't process any request.
- Creates the device interface (see [Interface GUID](#interface-guid)).

`EvtDeviceReleaseHardware` (0x401154) only returns `STATUS_SUCCESS`: the mappings are never released and the entropy source is never unregistered.  
`EvtDeviceSurpriseRemoval` (0x401160) calls `KeBugCheckEx(0x14E, 0x51726E30 ("Qrn0"), 0, 0, 0)`.

### Memory resources

`EvtDevicePrepareHardware` (0x401030):
1. Maps the clock controller: `MmMapIoSpace(0x00900000, 0x4000, MmNonCached)` (hardcoded, `dword_403A80`).
2. Walks the resource list. Only the descriptor at **index 0** is used, and only if it is `CmResourceTypeMemory`: it is mapped non-cached (`dword_403A78`, physical address in `dword_403A88`, length in `dword_403A8C`). A `CmResourceTypeInterrupt` descriptor only produces a warning trace; other descriptors are ignored. The result of `MmMapIoSpace` isn't checked.
3. `EntropyRegisterSource(&handle, 3, L"QCE_RNG")`, then `EntropyRegisterCallback(handle, sub_401238, 0)`. If one of them fails → `STATUS_DATA_ERROR` (0xC000003E). The second parameter (3) is the source type (undocumented ?).

| Index | Physical address | Length | Comment |
|-------|------------------|--------|---------|
| 0 | ? (ACPI `_CRS`) | ? | PRNG registers. Probably 0x1A500000 (`MSM_PRNG_PHYS` on MSM8960/8930 Linux kernels) ? |
| — | 0x00900000 (hardcoded) | 0x4000 | Clock controller (GCC), see [Clock](#clock) |

PRNG registers used (same layout as the Linux `msm_rng.c` driver):  
| Offset | Name | Comment |
|--------|------|---------|
| 0x0 | PRNG_DATA_OUT | 32-bit random value |
| 0x4 | PRNG_STATUS | Bit 0 = data available |

### Clock

| Address | Bit | Comment |
|---------|-----|---------|
| 0x00903080 | 10 (0x400) | Set before reading the PRNG, cleared after. `SC0_U_CLK_BRANCH_ENA_VOTE`, PRNG clock vote (`prng_clk`, BIT(10) in the Linux `clock-8960.c`) |

This is the enable register of `cc_prng_clk` in the [clock descriptors of qcpep8930.sys](./qcpep8930.md#clock-descriptors) (halt status 0x00902FD8 bit 10, which this driver doesn't poll).  
The bit is changed with a read-modify-write without any lock, so it may race with other drivers voting in the same register ?

### Entropy callback

`sub_401238` (0x401238), called by CNG with the entropy source handle:
1. Sets bit 10 of 0x00903080 (PRNG clock on).
2. Loops until 64 bytes are collected in a local buffer:
   - Reads `PRNG_STATUS`. If bit 0 is clear, it reads again: **there's no timeout** on this wait.
   - Reads `PRNG_DATA_OUT`. A value of 0 is discarded; after more than 512 (0x200) consecutive zeros the loop stops.
   - Otherwise the value is stored big-endian (most significant byte first).
3. Clears bit 10 of 0x00903080 (PRNG clock off).
4. If fewer than 64 bytes were collected (0x200 zeros) → `STATUS_DATA_ERROR` (0xC000003E).
5. Traces the 64 bytes one by one (WPP level verbose), so the random values end up in the ETW trace when the provider is enabled.
6. `EntropyProvideData(handle, buffer, 64, 100)`. The last parameter (100) is the entropy estimate ?. A failure → `STATUS_DATA_ERROR`.

> [!NOTE]
> Step 5 leaks the entropy given to CNG into the WPP trace when the ETW provider `{71c8ccb6-70e5-45cc-bae6-36302800d448}` is enabled with the verbose level.

### Interface GUID

Qcerng8930 Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{b28a70cb-b063-4a2c-b3e6-c41f5f560db9}`
