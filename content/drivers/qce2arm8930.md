## Qce2arm8930.sys

Driver of the second Qualcomm Crypto Engine (`\_SB.QCE2`, ACPI `QCOM1190`).  
It exposes the crypto engine (AES cipher and SHA-1/SHA-256 hash) through the device interface `{3453eddf-8fe0-4fd4-be0e-2c525a06e9b2}`. This interface is "hardware thread 2" of [qcbcryptcipherkm8930.sys](./qcbcryptcipherkm8930.md), which sends it [IOCTL 0x23C40C](#ioctl-0x23c40c) for AES operations of 64 bytes or more. The engine registers are programmed with DMA command lists (2 DMA adapters, ADM ?) and the data goes through DMA too. The engine clocks are switched on and off around each operation through the clock controller at 0x00900000. The device is registered with the power framework (PoFx, 1 component).  
In the DSDT, `\_SB.QBCC` (`QCOM1000`, the CNG cipher provider) depends on `\_SB.QQCE` and `\_SB.QCE2`.  
PDB path: `P:\qsecuremsm\rel\8.3.1\arm\Release\qce2arm8930.pdb`.

There's no device name and no symbolic link: the device is only reachable through its [interface](#interface-guid).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qce2arm8930` ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM1190\0` ?  

There's no parameters in the registry.  

GUID of the ETW provider (WPP):  
`{ef156da1-51ef-4eae-bad7-d14335f1af6a}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| DMA adapter, `DmaRequestLine` 4 | HAL / DMA extension | Engine input: command lists and data in (`dword_406BAC`) |
| DMA adapter, `DmaRequestLine` 5 | HAL / DMA extension | Engine output: data out and register read-back (`dword_406B7C`) |

### WDF configuration

`DriverEntry` (0x403A90): `WdfDriverCreate` with pool tag `qc20`.

`EvtDriverDeviceAdd` (0x4095C4 → `sub_409184`):
- PnP callbacks: `EvtDevicePrepareHardware` (0x409008), `EvtDeviceReleaseHardware` (0x40398C, returns `STATUS_SUCCESS` and does nothing), `EvtDeviceSelfManagedIoSuspend` (0x4039D0, `WdfIoQueuePurge`), `EvtDeviceSelfManagedIoRestart` (0x403A08, `WdfIoQueueStart`), `EvtDeviceSurpriseRemoval` (0x403A38).
- `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
- Device interface `{3453eddf-8fe0-4fd4-be0e-2c525a06e9b2}`.
- Default queue (`sub_403C5C`), `WdfIoQueueDispatchSequential`: only `EvtIoDeviceControl` (0x403CF0). Requests are processed one at a time.

`EvtDeviceSurpriseRemoval` calls `KeBugCheckEx(0x14E, 0x51633230 ("Qc20"), 0, 0, 0)`.

`EvtDevicePrepareHardware` (0x409008):
1. Registers with PoFx (`sub_403750`), see [Power management](#power-management).
2. Maps the clock controller: `MmMapIoSpace(0x00900000, 0x4000)` (hardcoded, `dword_406C00`).
3. Reads the resources. The first descriptor must be the memory resource (type 3): it is mapped (`dword_406BE8`) and its physical address is kept (`dword_406BF0`). Any other memory resource, or an interrupt resource, is only traced as an error. There's no interrupt: the driver waits on DMA completion events.
4. The first time only (`byte_406B4A`): engine initialisation `sub_4018F4`, see [DMA](#dma).

Memory resource of `\_SB.QCE2` in the DSDT (`Memory32Fixed`):  
| Base | Length | Comment |
|------|--------|---------|
| 0x12560000 | 0x20000 | Crypto engine 2 registers |

### Power management

`PO_FX_DEVICE` (built in `sub_403750`, pool tag `qc25`), 1 component, Id `{3453eddf-8fe0-4fd4-be0e-2c525a06e9b2}` (same as the interface GUID):  
| Idle state | TransitionLatency | ResidencyRequirement | NominalPower |
|------------|-------------------|----------------------|--------------|
| F0 | 0 | 0 | 500 |
| F1 | 2 | 5 | 50 |

`DeepestWakeableIdleState` = 1. The idle states array uses pool tag `CESQ`.  
Callbacks: `ComponentActiveConditionCallback` `nullsub_1` (no-op), `ComponentIdleConditionCallback` `sub_403998` (`PoFxCompleteIdleCondition`), `ComponentIdleStateCallback` `sub_40394C` (`PoFxCompleteIdleState`), `DevicePowerRequiredCallback` `sub_403970` (`PoFxReportDevicePoweredOn`), `DevicePowerNotRequiredCallback` `sub_4039B4` (`PoFxCompleteDevicePowerNotRequired`), `PowerControlCallback` 0x40398C (returns 0).

Every operation starts with `sub_402DC8` (`PoFxActivateComponent`, clocks on) and ends with `sub_402F28` (clocks off, `PoFxIdleComponent`).

### Clocks

Registers of the clock controller (physical base 0x00900000) used around every operation:  
| Address | Bit | Comment |
|---------|-----|---------|
| 0x00902740 | 4 | Set by `sub_402DC8`, cleared by `sub_402F28`. Branch enable of `cc_ce2_hclk` (CE2 AHB clock) |
| 0x00902744 | 4 | Set by `sub_402DC8`, cleared by `sub_402F28`. Branch enable of `cc_ce2_core_clk` |
| 0x00902FD4 | 0 | Polled after enabling, until 0 (no timeout). Halt status of `cc_ce2_hclk` (0 = running) |

The names come from the clock descriptors of [qcpep8930.sys](./qcpep8930.md#clock-descriptors). The halt status of `cc_ce2_core_clk` (0x00902FD0 bit 28) isn't polled. The driver writes these registers directly, without going through the PEP clock regime, so the PEP doesn't know the state of these clocks ?

### DMA

`sub_4018F4` (0x4018F4), called once by `EvtDevicePrepareHardware`:
1. Allocates 25 buffers of 16 bytes (`MmAllocateContiguousMemorySpecifyCache`, table at `.data:0x00406EA0`): destinations of the register read-backs.
2. Allocates 4 contiguous pages of 4 KB: command lists (`dword_406BB4`, `dword_406B60`, `dword_406B54`, `dword_406B9C`).
3. Gets 2 DMA adapters with `IoGetDmaAdapter` (`sub_401848`), then `InitializeDmaTransferContext` and `AllocateAdapterChannelEx` (at `DISPATCH_LEVEL`).
4. Allocates 3 common buffers of 0x8000 bytes (`AllocateCommonBufferEx`).
5. Initialises the 2 completion events (`.data:0x00407030` output, `.data:0x00406D80` input).

`DEVICE_DESCRIPTION` passed to `IoGetDmaAdapter`:  
| Field | Input adapter | Output adapter |
|-------|---------------|----------------|
| Version | 3 | 3 |
| Dma32BitAddresses | TRUE | TRUE |
| DmaChannel | 5 | 6 |
| InterfaceType | 12 (ProcessorInternal) | 12 |
| DmaWidth | Width32Bits | Width32Bits |
| MaximumLength | 0xFFFF | 0xFFFF |
| DmaAddressWidth | 32 | 32 |
| DmaRequestLine | 4 | 5 |
| DeviceAddress | 0x12560000 + 0x8000 | 0x12560000 + 0x8000 |

Each transfer: `ConfigureAdapterChannel` (functions 2, 0 and 1: command list address, `{4 or 5, 0x8000}`, `3`), then `MapTransferEx` with a completion routine that sets the event (0x401C9C input, 0x401CB8 output), then a wait of **300 ms** (`KeWaitForSingleObject`, timeout -3000000) and `FlushAdapterBuffersEx`.  
If a wait times out, `byte_40612E` is cleared **permanently**: every later operation fails (result 3) until reboot.

The command lists (`sub_401DBC`) are made of 16-byte entries: flags (0xC000, 0x200), source physical address, destination address, length. A transfer is split at 4 KB page boundaries. At most 25 entries (`dword_406B50` < 0x19).  
Register writes and reads (`sub_40220C`) are done by DMA too, with the physical addresses given by `sub_401008`. Offsets from the engine base (names guessed from the Qualcomm CE 4.x register map):  
| Index | Offset | Register ? |
|-------|--------|------------|
| 2 | 0x8000 | Data FIFO (DMA) |
| 3 | 0x0450 | AUTH_IV0 (digest / MAC result) |
| 8 | 0x0500 | CONFIG |
| 9 | 0x0400 | AUTH_SEG_CFG |
| 10 | 0x0404 | AUTH_SEG_SIZE |
| 11 | 0x0408 | AUTH_SEG_START |
| 12 | 0x0200 | SEG_SIZE |
| 13 | 0x0300 | ENCR_SEG_CFG |
| 14 | 0x0304 | ENCR_SEG_SIZE |
| 15 | 0x04A0 | AUTH_BYTECNT0 |
| 16 | 0x04A4 | AUTH_BYTECNT1 |
| 17 | 0x0410 | AUTH_KEY ? |
| 18 | 0x0204 | GOPROC |
| 19 | 0x0100 | STATUS |
| 20 | 0x0308 | ENCR_SEG_START |
| 21-25 | 0x0350-0x0360 | ? |
| 26 | 0x0310 | CNTR0_IV0 |
| 27 | 0x0364 | ? |
| 28 | 0x0330 | CNTR_MASK |
| 29 | 0x0490 | AUTH_INFO_NONCE0 |
| 0, 1, 5 | 0 | — |
| 4, 6 | 4 | — |
| 7 | 5 | — |

There's also a PIO path through the mapped registers (STATUS at +0x100: bit 2 data-in ready, bit 3 data-out ready, bit 1 done, bit 0 error; DATA_IN at +0x08, DATA_OUT at +0x10) in `sub_401310` / `sub_4014B0` (`sub_402D80`), but `sub_403474` always selects the DMA path (`sub_402D2C`): it is dead code.

> [!NOTE]
> `sub_4016B0` (DMA of the data) calls `KeBugCheckEx(0x5A, 0x51636532 ("Qce2"), 0, 0, 0)` when the length isn't a multiple of 64. A cipher request whose length isn't a multiple of 64 (CTR mode accepts any length) crashes the phone.

---

### IOCTL 0x23C400

This IOCTL is processed by Qce2arm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x100 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | — | — |

No-op: only traced, completed with `STATUS_SUCCESS`.

---

### IOCTL 0x23C404

This IOCTL is processed by Qce2arm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x101 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Release the engine ? | — | — |

Calls `sub_402F28(0)`: clocks off (see [Clocks](#clocks)), sends a last command list (`sub_401CD4`, header 0x80200000) and `PoFxIdleComponent`. Always completed with `STATUS_SUCCESS` (a failure is only traced).

---

### IOCTL 0x23C40C

This IOCTL is processed by Qce2arm8930.sys. It is sent by [qcbcryptcipherkm8930.sys](./qcbcryptcipherkm8930.md#ioctl-0x23c40c).

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x103 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| AES-128 cipher operation | 56 | 16 |

Inputbuffer (packed):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 05 00 00 00 | Not read |
| 04-13 | ? | AES-128 key, in clear |
| 14-17 | 00 00 00 00 | Mode, see below |
| 18-27 | ? | IV / counter |
| 28 | 00 | Direction: 0 = encrypt, ≠ 0 = decrypt |
| 29-2C | ? | Kernel virtual address of the input data (unaligned DWORD) |
| 2D-30 | ? | Kernel virtual address of the output buffer (unaligned DWORD) |
| 31-33 | ? | Not read |
| 34-37 | ? | Length in bytes |

Mode (`ENCR_SEG_CFG` bits 6-8 = mode, bit 10 = encode):  
| Value | Mode ? | Comment |
|-------|--------|---------|
| 0 | ECB | Length must be a multiple of 16 |
| 1 | CBC | Length must be a multiple of 16 |
| 2 | CTR | Any length (but see the bugcheck [above](#dma)). Always "encode" |
| 3 | XTS | Always "encode" |
| 4 | CCM | Always "encode". The 16-byte result is read back from AUTH_IV0 |
| 5 | CMAC ? | Single operation; the 16-byte result (AUTH_IV0, byte-swapped) is written at the output data address |

The handler (0x403CF0):
1. Input buffer < 56 bytes → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A); length ≠ `InputBufferLength` → `STATUS_UNSUCCESSFUL` (0xC0000001). Same for the output buffer (16 bytes).
2. Allocates a context of 160 bytes (tag `qc24`, in a 4-byte holder tag `qc23`). Algorithm = 0 (AES-128; 1 would be AES-256 with a 32-byte key).
3. `sub_403300` stores the parameters: 0 direction, 3 mode, 1 key, 2 IV. Key and IV are byte-swapped (`sub_401570`). (With a NULL key the hardware key would be used, flag 0x2000; not reachable from this IOCTL.)
4. `sub_403474`: the data is processed in chunks of at most 0x8000 bytes. For each chunk: config (`sub_401404`), DMA in/out of the data (`sub_4016B0`), read back of the 4 IV registers (`sub_40126C`).
5. Success → `STATUS_SUCCESS`, `Information` = 16. Any failure → `STATUS_UNSUCCESSFUL`, and the context is leaked.

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | ? | **Never written** |

> [!NOTE]
> With METHOD_BUFFERED the input and output share the system buffer. As the driver never writes the output, the caller gets back the first 16 bytes of its own input: `05 00 00 00` + the first 12 bytes of the key. The updated IV is not returned.

The data buffers are used by address (an MDL is built with `MmBuildMdlForNonPagedPool`): they must be in non-paged kernel memory.

---

### IOCTL 0x23C414

This IOCTL is processed by Qce2arm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x105 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| SHA-1 / SHA-256 hash | ≥ 24 | ≥ 176 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not read |
| 04-07 | ? | Handle (commands 2, 3, 4) |
| 08-0B | 01 00 00 00 | Algorithm (command 1): 1 = SHA-1, 2 = SHA-256 |
| 0C-0F | 01 00 00 00 | Command, see below |
| 10-13 | ? | Kernel virtual address of the data (command 2) |
| 14-17 | ? | Length of the data (command 2) |

Commands:  
| Value | Function | Comment |
|-------|----------|---------|
| 1 | Init (`sub_403090`) | Allocates a 188-byte context (tag `qc22`, in a 4-byte holder tag `qc21`), loads the initial hash values (`.data:0x00406144` SHA-1, `.data:0x00406158` SHA-256). Returns the handle |
| 2 | Update (`sub_403194`) | Data is buffered by 64-byte blocks; full blocks are sent to the engine in chunks of at most 0x8000 bytes (`sub_402F9C`) |
| 3 | Final (`sub_403280`) | Last (zero padded) block sent with the "last" flag: the engine does the padding. Returns the digest |
| 4 | Free (`sub_403150`) | Frees the context |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not written (input data) |
| 04-07 | ? | Handle (command 1) = kernel address of the context holder |
| 08-0B | 00 00 00 00 | Result: 0 = success, 1 = error, 2 = invalid parameter, 3 = engine disabled (DMA timeout) |
| 0C-2B | ? | Not written (input data) |
| 2C-4B | ? | Digest, 20 bytes (SHA-1) or 32 bytes (SHA-256), command 3 |
| 4C-AB | ? | Not written |
| AC-AF | ? | Digest length (command 3) |

Input < 24 bytes or output < 176 bytes → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A). Otherwise `STATUS_SUCCESS` with `Information` = 176; the result of the operation is at offset 08. An unknown command gives result 1.

> [!NOTE]
> The handle is a kernel pointer and isn't validated: a wrong handle makes the driver use (and with command 4 free) arbitrary kernel memory.

Any other IoControlCode → `STATUS_NOT_IMPLEMENTED` (0xC0000002).

### Interface GUID

Interface Class GUID created by `WdfDeviceCreateDeviceInterface`:  
`{3453eddf-8fe0-4fd4-be0e-2c525a06e9b2}`

Pool tags: `qc20` (driver), `qc21`/`qc22` hash context, `qc23`/`qc24` cipher context, `qc25` PoFx device, `CESQ` PoFx idle states.
