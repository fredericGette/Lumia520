## Qcearm8930.sys

Driver of the first Qualcomm Crypto Engine (`\_SB.QQCE`, ACPI `QCOM1100`).  
It exposes the crypto engine (AES cipher and SHA-1/SHA-256 hash) through the device interface `{0923c751-56cd-4828-888b-80e586f7ec83}`. This interface is "hardware thread 1" of [qcbcryptcipherkm8930.sys](./qcbcryptcipherkm8930.md), which sends it [IOCTL 0x23C40C](#ioctl-0x23c40c) for AES operations of 64 bytes or more. The engine registers are programmed with DMA command lists (2 DMA adapters, ADM0) and the data goes through DMA too. The device is registered with the power framework (PoFx, 1 component); unlike [qce2arm8930.sys](./qce2arm8930.md), the driver doesn't touch the clock controller itself: the clocks are switched by the PEP ([qcpep8930.sys](./qcpep8930.md)) when the component goes F0/F1.  
The code is the same as [qce2arm8930.sys](./qce2arm8930.md) (same functions, same buffers, same IOCTLs), built for the other engine. The differences are listed in [Differences with qce2arm8930.sys](#differences-with-qce2arm8930sys).  
In the DSDT, `\_SB.QBCC` (`QCOM1000`, the CNG cipher provider) depends on `\_SB.QQCE` and `\_SB.QCE2`.  
PDB path: `P:\qsecuremsm\rel\8.3.1\arm\Release\qcearm8930.pdb`.

There's no device name and no symbolic link: the device is only reachable through its [interface](#interface-guid).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcearm8930` ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM1100\0` ?  

There's no parameters in the registry.  

GUID of the ETW provider (WPP):  
`{20c3f129-a4a9-432d-a5e9-bf074254e584}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| DMA adapter, `DmaRequestLine` 2 | HAL / DMA extension | Engine input: command lists and data in (`dword_406BA0`) |
| DMA adapter, `DmaRequestLine` 3 | HAL / DMA extension | Engine output: data out and register read-back (`dword_406B80`) |

### WDF configuration

`DriverEntry` (0x403658): `WdfDriverCreate` with pool tag `qce0`.

`EvtDriverDeviceAdd` (0x4095C4 → `sub_409184`):
- PnP callbacks: `EvtDevicePrepareHardware` (0x409008), `EvtDeviceReleaseHardware` (0x403554, returns `STATUS_SUCCESS` and does nothing), `EvtDeviceSelfManagedIoSuspend` (0x403598, `WdfIoQueuePurge`), `EvtDeviceSelfManagedIoRestart` (0x4035D0, `WdfIoQueueStart`), `EvtDeviceSurpriseRemoval` (0x403600).
- `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
- Device interface `{0923c751-56cd-4828-888b-80e586f7ec83}`.
- Default queue (`sub_403824`), `WdfIoQueueDispatchSequential`: only `EvtIoDeviceControl` (0x4038B8). Requests are processed one at a time.

`EvtDeviceSurpriseRemoval` calls `KeBugCheckEx(0x14E, 0x51636530 ("Qce0"), 0, 0, 0)`.

`EvtDevicePrepareHardware` (0x409008):
1. Registers with PoFx (`sub_403330`), see [Power management](#power-management).
2. Maps the clock controller: `MmMapIoSpace(0x00900000, 0x4000)` (hardcoded, `dword_406BE8`). The mapping is **never used**.
3. Reads the resources. The first descriptor must be the memory resource (type 3): it is mapped (`dword_406BD0`) and its physical address is kept (`dword_406BD8`). Any other memory resource, or an interrupt resource, is only traced. There's no interrupt: the driver waits on DMA completion events.
4. The first time only (`byte_406B4A`): engine initialisation `sub_402A6C` → `sub_4018B8`, see [DMA](#dma). Its result is ignored (`sub_402A6C` always returns 0).

Memory resource of `\_SB.QQCE` in the DSDT (`Memory32Fixed`):  
| Base | Length | Comment |
|------|--------|---------|
| 0x18500000 | 0x20000 | Crypto engine 1 registers |

### Power management

`PO_FX_DEVICE` (built in `sub_403330`, pool tag `qce5`), 1 component, Id `{0923c751-56cd-4828-888b-80e586f7ec83}` (same as the interface GUID):  
| Idle state | TransitionLatency | ResidencyRequirement | NominalPower |
|------------|-------------------|----------------------|--------------|
| F0 | 0 | 0 | 500 |
| F1 | 2 | 5 | 50 |

`DeepestWakeableIdleState` = 1. The idle states array uses pool tag `CESQ`.  
Callbacks: `ComponentActiveConditionCallback` `nullsub_1` (no-op), `ComponentIdleConditionCallback` `sub_403560` (`PoFxCompleteIdleCondition`), `ComponentIdleStateCallback` `sub_403514` (`PoFxCompleteIdleState`), `DevicePowerRequiredCallback` `sub_403538` (`PoFxReportDevicePoweredOn`), `DevicePowerNotRequiredCallback` `sub_40357C` (`PoFxCompleteDevicePowerNotRequired`), `PowerControlCallback` 0x403554 (returns 0).

Every operation starts with `sub_402B20` (`PoFxActivateComponent` + reset of the command list state) and ends with `PoFxIdleComponent`.

F-states of `\_SB.QQCE` in the PEP configuration of the DSDT (component 0):  
| F-state | Bus vote `ICBID_MASTER_CRYPTO` → `ICBID_SLAVE_EBI1` | Clocks |
|---------|-----------------------------------------------------|--------|
| F0 | 0x3C000000, 0x05000000 | `cc_ce1_hclk`, `cc_ce1_core_clk`, `cc_adm0_aclk`, `cc_adm0_pbus_hclk` on |
| F1 | 0x1F40, 0 | same clocks off |

### DMA

`sub_4018B8` (0x4018B8), called once by `EvtDevicePrepareHardware`:
1. Allocates 25 buffers of 16 bytes (`MmAllocateContiguousMemorySpecifyCache`, table at `.data:0x00406E80`): destinations of the register read-backs.
2. Allocates 4 contiguous pages of 4 KB: command lists (`dword_406BB0`, `dword_406B60`, `dword_406B54` input, `dword_406B98` output).
3. Gets 2 DMA adapters with `IoGetDmaAdapter` (`sub_40180C`), then `InitializeDmaTransferContext` and `AllocateAdapterChannelEx` (at `DISPATCH_LEVEL`).
4. Allocates a common buffer of 0x8000 bytes (`AllocateCommonBufferEx`, `dword_406BA4`).
5. Initialises the 2 completion events (`.data:0x00406D60` input, `.data:0x00407010` output).

`DEVICE_DESCRIPTION` passed to `IoGetDmaAdapter`:  
| Field | Input adapter | Output adapter |
|-------|---------------|----------------|
| Version | 3 | 3 |
| Dma32BitAddresses | TRUE | TRUE |
| DmaChannel | `dword_406BC0`: never written, so 0 ? | 1 |
| InterfaceType | 12 (ProcessorInternal) | 12 |
| DmaWidth | Width32Bits | Width32Bits |
| MaximumLength | 0xFFFF | 0xFFFF |
| DmaAddressWidth | 32 | 32 |
| DmaRequestLine | 2 | 3 |
| DeviceAddress | 0x18500000 + 0x8000 | 0x18500000 + 0x8000 |

Each transfer: `ConfigureAdapterChannel` (functions 2, 0 and 1: command list address, `{2 or 3, 0x8000}`, `3`), then `MapTransferEx` with a completion routine that sets the event (0x401C0C input, 0x401C28 output), then a wait of **300 ms** (`KeWaitForSingleObject`, timeout -3000000) and `FlushAdapterBuffersEx`.  
If a wait times out, `byte_40612E` is cleared **permanently**: every later operation fails (result 1) until reboot.

The command lists (`sub_401C44`) are made of 16-byte entries: flags, source physical address, destination address, length. A transfer is split at 4 KB page boundaries. At most 25 entries (`dword_406B50` < 0x19).  
Flags of the entries, read with the ADM command bits of the Linux `msm_dmov` driver:  
| Direction | Flags | Meaning ? |
|-----------|-------|-----------|
| Memory → engine | 0xC000, 0x100 | DST_SWAP_BYTES + DST_SWAP_SHORTS, DST_CRCI(2) |
| Engine → memory | 0x1800, 0x18 | SRC_SWAP_BYTES + SRC_SWAP_SHORTS, SRC_CRCI(3) |
| Last entry | 0x80000000 | CMD_LC (last command) |

Register writes and reads (`sub_40207C`, `sub_4024EC`) are done by DMA too, with the physical addresses given by `sub_401008`. The register table is the one of [qce2arm8930.sys](./qce2arm8930.md#dma) (offsets from the engine base 0x18500000), except the non-address entries: indexes 4 and 6 give 2 and index 7 gives 3 (4 and 5 in qce2arm8930.sys), i.e. the CRCI numbers ?.

There's also a PIO path through the mapped registers (`sub_40130C` / `sub_401498`, via `sub_402AD8`), but `sub_403048` always selects the DMA path (`sub_402A84`) and `sub_402AD8` has no caller: it is dead code.

> [!NOTE]
> `sub_401688` (DMA of the data) calls `KeBugCheckEx(0x5A, 0x51636530 ("Qce0"), 0, 0, 0)` when the length isn't a multiple of 64. A cipher request whose length isn't a multiple of 64 (CTR mode accepts any length) crashes the phone.

### Differences with qce2arm8930.sys

| | qcearm8930.sys | [qce2arm8930.sys](./qce2arm8930.md) |
|---|---|---|
| ACPI device | `\_SB.QQCE`, `QCOM1100`, registers at 0x18500000 | `\_SB.QCE2`, `QCOM1190`, registers at 0x12560000 |
| Interface / PoFx component | `{0923c751-56cd-4828-888b-80e586f7ec83}` | `{3453eddf-8fe0-4fd4-be0e-2c525a06e9b2}` |
| ETW provider | `{20c3f129-a4a9-432d-a5e9-bf074254e584}` | `{ef156da1-51ef-4eae-bad7-d14335f1af6a}` |
| Pool tags | `qce0`-`qce5` | `qc20`-`qc25` |
| Bugcheck parameter | 0x51636530 "Qce0" | 0x51633230 "Qc20" / 0x51636532 "Qce2" |
| DMA request lines (CRCI) | 2 in, 3 out | 4 in, 5 out |
| DMA channels | ? (0 ?) in, 1 out | 5 in, 6 out |
| Clocks | Left to PoFx / PEP; clock controller mapped but not used | Driver sets bit 4 of 0x00902740 / 0x00902744 itself |
| [IOCTL 0x23C404](#ioctl-0x23c404) | Only `PoFxIdleComponent` | Clocks off + last command list + `PoFxIdleComponent` |

---

### IOCTL 0x23C400

This IOCTL is processed by Qcearm8930.sys

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

This IOCTL is processed by Qcearm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x101 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Release the engine ? | — | — |

Only calls `PoFxIdleComponent` (one more idle reference: unbalanced if no operation left the component active). Always completed with `STATUS_SUCCESS`.

---

### IOCTL 0x23C40C

This IOCTL is processed by Qcearm8930.sys. It is sent by [qcbcryptcipherkm8930.sys](./qcbcryptcipherkm8930.md#ioctl-0x23c40c) ("hardware thread 1").

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

The handler (0x4038B8):
1. Input buffer < 56 bytes → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A); length ≠ `InputBufferLength` → `STATUS_UNSUCCESSFUL` (0xC0000001). Same for the output buffer (16 bytes).
2. Allocates a context of 160 bytes (tag `qce4`, in a 4-byte holder tag `qce3`). Algorithm = 0 (AES-128; 1 would be AES-256 with a 32-byte key).
3. `sub_402ED4` stores the parameters: 0 direction, 3 mode, 1 key, 2 IV. Key and IV are byte-swapped (`sub_40154C`). (With a NULL key the hardware key would be used, flag 0x2000; not reachable from this IOCTL.)
4. `sub_403048`: the data is processed in chunks of at most 0x8000 bytes. For each chunk: config (`sub_4013EC`), DMA in/out of the data (`sub_401688`), read back of the 4 IV registers (`sub_401268`).
5. Success → `STATUS_SUCCESS`, `Information` = 16. Any failure → `STATUS_UNSUCCESSFUL`, and the context is leaked.

When ECB/CBC is requested with a length that isn't a multiple of 16, or when mode 5 fails, `sub_403048` returns without `PoFxIdleComponent`: the component stays active (F0, clocks on).

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | ? | **Never written** |

> [!NOTE]
> With METHOD_BUFFERED the input and output share the system buffer. As the driver never writes the output, the caller gets back the first 16 bytes of its own input: `05 00 00 00` + the first 12 bytes of the key. The updated IV is not returned.

The data buffers are used by address (an MDL is built with `MmBuildMdlForNonPagedPool`): they must be in non-paged kernel memory.

---

### IOCTL 0x23C414

This IOCTL is processed by Qcearm8930.sys

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
| 1 | Init (`sub_402C64`) | Allocates a 188-byte context (tag `qce2`, in a 4-byte holder tag `qce1`), loads the initial hash values (`.data:0x0040613C` SHA-1, `.data:0x00406150` SHA-256). Returns the handle |
| 2 | Update (`sub_402D68`) | Data is buffered by 64-byte blocks; full blocks are sent to the engine in chunks of at most 0x8000 bytes (`sub_402B68`) |
| 3 | Final (`sub_402E54`) | Last (zero padded) block sent with the "last" flag: the engine does the padding. Returns the digest |
| 4 | Free (`sub_402D24`) | Frees the context |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Not written (input data) |
| 04-07 | ? | Handle (command 1) = kernel address of the context holder |
| 08-0B | 00 00 00 00 | Result: 0 = success, 1 = error, 2 = invalid parameter |
| 0C-2B | ? | Not written (input data) |
| 2C-4B | ? | Digest, 20 bytes (SHA-1) or 32 bytes (SHA-256), command 3 |
| 4C-AB | ? | Not written |
| AC-AF | ? | Digest length (command 3) |

Input < 24 bytes or output < 176 bytes → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A). Otherwise `STATUS_SUCCESS` with `Information` = 176; the result of the operation is at offset 08. An unknown command gives result 1. After a DMA timeout every operation gives result 1.

> [!NOTE]
> The handle is a kernel pointer and isn't validated: a wrong handle makes the driver use (and with command 4 free) arbitrary kernel memory.

Any other IoControlCode → `STATUS_NOT_IMPLEMENTED` (0xC0000002).

### Interface GUID

Interface Class GUID created by `WdfDeviceCreateDeviceInterface`:  
`{0923c751-56cd-4828-888b-80e586f7ec83}`

Pool tags: `qce0` (driver), `qce1`/`qce2` hash context, `qce3`/`qce4` cipher context, `qce5` PoFx device, `CESQ` PoFx idle states.
