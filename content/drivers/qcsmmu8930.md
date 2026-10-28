## Qcsmmu8930.sys

System MMU (SMMU / IOMMU) driver.  
It is the function driver of the ACPI node `\_SB.SMMU` (`QCOM0200`). It programs the context banks of the 9 multimedia IOMMUs of the MSM8930 (Qualcomm "MSM IOMMU v0", the same hardware as the Linux `msm_iommu` driver): VPE, MDP, rotator, JPEG, VFE, video codec and 3D GPU. It builds the ARMv7 short-descriptor page tables (1 MB sections, 64 KB large pages, 4 KB small pages) in contiguous memory, attaches them to the context banks (TTBR0/TTBR1), invalidates the TLBs and handles the translation faults.  
It has no user-mode API: a client gets a table of 20 function pointers with [IOCTL 0xC3500004](#ioctl-0xc3500004) and calls them directly. The VCM layer qcvcm8930.sys (used by [qcdxkm8930.sys](./qcdxkm8930.md), [qccamavs8930.sys](./qccamavs8930.md), [qccamgemini8930.sys](./qccamgemini8930.md)…) is probably its client ?.  
The configuration (number of IOMMUs, context banks, context IDs) comes from the ACPI methods `BCDE`, `CORE`, `PTCA` and `AGPA`. Source files (from the trace strings): `Driver.cpp`, `Device.cpp`, `SmmuInit.cpp`, `PageTableLibrary.cpp`, `PageTableInterface.cpp`, `SmmuApi.cpp`, `SmmuReservationManagement.cpp`. PDB path: `P:\SMMU\rel\8.2.1\arm\Release\qcsmmu8930.pdb`.

There's no device name and no symbolic link: the device is only reachable through its [device interface](#interface-guid).  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcsmmu`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0200\0`

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcsmmu` (the service key itself, not `Parameters`; read by `sub_402F6C` with `ZwOpenKey` / `ZwQueryValueKey`):  
| Registry value | value | comment |
|----------------|-------|---------|
| PowerManaged | ? | REG_DWORD. 1 = register the device with the power framework (PoFx, see [Power management](#power-management)). Missing or any other value = no PoFx, and the clock register 0x04000080 is forced on during the initialisation instead |

GUID of the ETW provider (manifest-based, `EtwRegister`):  
`{1a64bee1-de91-4a1e-bafc-c461666f1daa}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI PDO of `QCOM0200` (default I/O target) | [acpi.sys](./acpi.md) | [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method) on `BCDE`, `PTCA`, `AGPA`, `CORE` |
| Kernel power manager | ntoskrnl | `PoFxRegisterDevice`, only when `PowerManaged` = 1 |

### WDF configuration

`EvtDriverDeviceAdd` (0x401418):
- PnP callbacks: `EvtWdfDevicePrepareHardware`, `EvtWdfDeviceReleaseHardware`, `EvtWdfDeviceSurpriseRemoval`. Device context `SMMU_CONFIG`.
- `WdfDeviceCreateDeviceInterface` with the [interface GUID](#interface-guid), then `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
- Creates **15** `WDFINTERRUPT` objects (ISR `sub_401818`, DPC `sub_401874`), stored in `SMMU_CONFIG + 0x0C`. Interrupt *i* belongs to the IOMMU of memory resource *i*. The Lumia 520 only has 9 interrupt resources, the other objects are never connected ?.
- One sequential queue with only `EvtIoDeviceControl` (0x401734).

`EvtWdfDeviceSurpriseRemoval` (0x401A00) calls `KeBugCheckEx(0x14E, 0x516D7530 ("0umQ"), 0, 0, 0)`.

### Initialisation

`EvtWdfDevicePrepareHardware` (0x401B88):
1. Allocates the global IOMMU table (0xB10 bytes, pool tag `qmu1`, `dword_40BB2C`, see [Data structures](#data-structures)).
2. Evaluates `BCDE` (fails the start if it fails), `PTCA`, `AGPA`, and `CORE` when byte 3 of `BCDE` is not 0. Without `CORE` the defaults are: 10 IOMMUs (ids 0–9), 2 context banks each, context IDs 1–17, 19, 20.
3. Reads the registry value `PowerManaged`.
4. If `BCDE` byte 0 is 1, 2 or 3 and `PowerManaged` ≠ 1: maps the physical register **0x04000080** (MMSS clock controller ?) and sets bits 0 and 2 (`|= 5`).
5. For each resource: a `CmResourceTypeMemory` resource is one IOMMU. It is mapped (`MmMapIoSpace`, `MmNonCached`), and gets the next IOMMU id and context-bank count of `CORE`, and the next context IDs. `CmResourceTypeInterrupt` resources are only counted. A different number of memory and interrupt resources is only traced.
6. `sub_402350`: creates the **default page table** (16 KB first-level table, all entries invalid, so every access faults; `dword_40BB34`), then resets every context bank (`sub_4024C0`):
   - `SCTLR &= ~0x3F` (translation disabled), `FSRRESTORE` cleared, `CONTEXTIDR` ASID = 0, `TTBCR` N = 0;
   - `TTBR0` and `TTBR1` = physical address of the default page table (`TTBR0` attribute bits = 2);
   - `TLBLCKR` and `ACTLR` set to fixed values (`ACTLR |= 0x53B07F`), then `TLBIALL`.
7. If `PowerManaged` = 1: `PoFxRegisterDevice` + `PoFxStartDevicePowerManagement`.
8. If `BCDE` byte 0 is 1 and `PowerManaged` ≠ 1: clears bits 0 and 2 of 0x04000080 again (`&= ~5`).

`EvtWdfDeviceReleaseHardware` (0x402070) resets every context bank again (`sub_4031BC`), frees the default page table and the global table. The register mappings are not unmapped.

The global registers of the IOMMUs (offset 0xFF000 and above in the Linux `msm_iommu_hw-8xxx.h`: `M2VCBR_N`, `CBACR_N`, `CR`…) are never accessed: the stream → context-bank mapping is probably done by the boot loader or TrustZone ?.

### Lumia 520 ACPI node

`\_SB.SMMU`, `_HID` `QCOM0200`, `_UID` 0. It's a `_DEP` of `\_SB.GPU0`, `\_SB.GPU0.AVS0`, `\_SB.CAMG`, `\_SB.VFE0` and `\_SB.VPE`. `\_SB.PEP0` declares its clocks (component 0: `cc_gfx3d_axi_clk`, `cc_vcodec_axi_clk`, …).

`_CRS`: 9 memory regions of 1 MB and 9 interrupts. The IOMMU names come from the Linux `msm8960` `devices-iommu.c` (same addresses and same context-bank counts):  
| Resource | Physical address | Interrupt (GSI) | IOMMU id (`CORE`) | Context banks | Context IDs (`CORE`) | IOMMU |
|----------|------------------|-----------------|-------------------|---------------|----------------------|-------|
| 0 | 0x07400000 | 0x54 | 1 | 2 | 1, 2 | VPE ? |
| 1 | 0x07500000 | 0x60 | 2 | 2 | 3, 4 | MDP0 ? |
| 2 | 0x07600000 | 0x5E | 3 | 2 | 5, 6 | MDP1 ? |
| 3 | 0x07700000 | 0x5C | 4 | 2 | 7, 8 | Rotator ? |
| 4 | 0x07800000 | 0x64 | 5 | 2 | 9, 10 | IJPEG ? |
| 5 | 0x07900000 | 0x56 | 6 | 2 | 11, 12 | VFE ? |
| 6 | 0x07A00000 | 0x5A | 7 | 2 | 13, 14 | Video codec A ? |
| 7 | 0x07B00000 | 0x58 | 8 | 1 | 15 | Video codec B ? |
| 8 | 0x07C00000 | 0x66 | 9 | 2 | 16, 17 | GFX3D (user, priv) ? |

[qccamgemini8930.sys](./qccamgemini8930.md#smmu-vcm) uses contexts 11 and 12 (6th IOMMU, VFE ?).

ACPI methods (buffers), evaluated with [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method):  
| Method | Lumia 520 value | Comment |
|--------|-----------------|---------|
| `BCDE` | `03 00 01 10` | Byte 0: clock workaround mode (1–3 = force 0x04000080 bits 0 and 2, 1 = clear them again at the end). Bytes 1 and 2: stored in `SMMU_CONFIG + 0x4C` / `+ 0x50`, never used. Byte 3: ≠ 0 = read `CORE` |
| `CORE` | `09`, `01`…`09`, `02 02 02 02 02 02 02 01 02`, `01`…`11 13 14` | Number of IOMMUs *n*, then *n* IOMMU ids, then *n* context-bank counts, then one context ID per context bank (sum of the counts, 17) |
| `PTCA` | `00` | Stored in `SMMU_CONFIG + 0x54`, returned by function 19 |
| `AGPA` | `01` | Stored in `SMMU_CONFIG + 0x58`, returned by function 20 |

The context ID is the handle used by the clients to designate a context bank (functions 4, 10–18).

### Context bank registers

Context bank *n* of an IOMMU is the 4 KB page at offset `n × 0x1000` of its register region. Registers used by the driver (names from the Linux `msm_iommu_hw-8xxx.h`):  
| Offset | Register | Use |
|--------|----------|-----|
| 0x000 | SCTLR | Bit 0 (M) = translation enabled. Bits 0–5 cleared at reset |
| 0x004 | ACTLR | Fixed value at reset |
| 0x008 | CONTEXTIDR | Bits 0–7 = ASID (function 10) |
| 0x010 | TTBR0 | First-level table of the low domain. Attribute bits 0x6A (cached table walk) or 2 |
| 0x014 | TTBR1 | First-level table of the high domain. Attribute bits 0x2B or 2 |
| 0x018 | TTBCR | Bits 0–2 = N (split between TTBR0 and TTBR1) |
| 0x01C | PAR | Result of an address translation (function 13) |
| 0x020 | FSR | Fault status. Read by the DPC and by function 18 |
| 0x024 | FSRRESTORE | Written to clear the fault (`FSR & 0x3FFEFF01`, or 0) |
| 0x028 | FAR | Faulting address |
| 0x03C | TLBLCKR | Fixed value at reset |
| 0x040 | V2PSR | Status of the address translation (function 13) |
| 0x800 | TLBIALL | Written with 0 to invalidate the whole TLB of the context |
| 0x810 / 0x814 / 0x818 / 0x81C | V2PPR / V2PPW / V2PUR / V2PUW | Start an address translation: privileged read / write, user read / write |

### Fault handling

The ISR (`sub_401818`) only queues the DPC. The DPC (`sub_401874`) finds the IOMMU of the interrupt, then the first context bank whose `FSR` ≠ 0 (`sub_405D24`), traces `FSR` and `FAR`, and calls the fault callback registered with function 15 (`callback(context)`). Without callback it only traces. The fault isn't cleared by the driver: the client must call function 14. If `FSR` is still ≠ 0 after the callback, a trace is written.

### Page tables

A "domain" is a page table created by function 1 (pool tag `qmu3`, 0x50 bytes):
- first-level table in contiguous memory (`MmAllocateContiguousMemorySpecifyCache`, twice the size, then aligned on its size; caching type given by the caller);
- second-level tables of 1 KB, allocated 4 per contiguous page (pool tag `qmuc` for the free ones) and indexed per 1 MB section in a 10-bucket hash table (pool tag `qmu4`);
- a reservation count per 1 MB section (functions 5 and 6): pages can only be mapped in a reserved range;
- a WDF collection of the attached context banks, a guarded mutex for the tables, a spinlock for the TLB maintenance.

The address range of the domain selects the translation table base register and TTBCR.N (`sub_405278`): a domain whose range ends below 2^(32−N) uses **TTBR0** with N = 1…7 (first-level table of 16 KB >> N); a domain starting above 32 MB with type 2 uses **TTBR1**; otherwise TTBR0 with N = 0 (4 GB). A context bank can have one TTBR0 domain and one TTBR1 domain, with compatible N.

Mappings use 4 KB small pages, merged into 64 KB large pages and 1 MB sections when possible. The attribute word given by the caller (functions 7 and 9) is converted by `sub_403910`: bits 0–3 = flags (XN, nG, shareable… ?), bits 4–7 = access permissions, bits 8–11 = memory type (0 strongly-ordered, 1 device, 2 normal), bits 12–15 = cache policy (normal memory) ?.

When a context bank is "off" (function 17 with 0), the TLB invalidations of the domains attached to it are deferred, and done when it's switched on again.

### Power management

Only when the registry value `PowerManaged` = 1 (`sub_402CF8`). One component, id `{ffffffff-ffff-ffff-ffff-ffffffffffff}`, 2 idle states, deepest wakeable state 1:  
| F-state | Transition latency | Residency requirement | Nominal power |
|---------|--------------------|-----------------------|---------------|
| F0 | 0 | 0 | 500 |
| F1 | 2 | 5 | 50 |

The callbacks only acknowledge the power framework (`PoFxCompleteIdleCondition`, `PoFxCompleteIdleState`, `PoFxReportDevicePoweredOn`, `PoFxCompleteDevicePowerNotRequired`); the active-condition callback is empty and the power-control callback returns 0. The hardware is never saved or restored: the clocks are handled by the PEP (`\_SB.PEP0`).

### Function table

Returned by [IOCTL 0xC3500004](#ioctl-0xc3500004) (`sub_407CFC`). Signatures reconstructed from the code (names are tentative, they follow the qcvcm8930 exports `VcmCreate`, `VcmReserve`, `VcmBack`, `VcmAssoc`, `VcmActivate`…):  
| Position | Address | Function signature | Comment |
|----------|---------|--------------------|---------|
| 00 | — | | Not written |
| 01 | 0x40629C | `NTSTATUS CreateDomain(ULONG va_start, ULONG size, ULONG type, MEMORY_CACHING_TYPE cache, DOMAIN **domain)` | Allocates a page table. Type 0/1/2 selects TTBR0/TTBR1 (see [Page tables](#page-tables)). Type 2 with `va_start` < 0x2000000 is rejected |
| 02 | 0x406674 | `NTSTATUS DestroyDomain(DOMAIN *domain)` | Frees the tables. Only traces if context banks are still attached |
| 03 | 0x406888 | `NTSTATUS GetDomainTable(DOMAIN *domain, ?, ULONG *physical)` | Physical address of the first-level table |
| 04 | 0x4068A8 | `NTSTATUS GetRegisters(ULONG ctx_id, ULONG which, PVOID *address, ULONG *size)` | `which` = 0: **kernel virtual address** of the register region of the IOMMU, size 4. `which` = 1: 0 |
| 05 | 0x40690C | `NTSTATUS Reserve(DOMAIN *domain, ULONG va, ULONG size)` | Allocates the second-level tables of the range. 4 KB aligned |
| 06 | 0x406A10 | `NTSTATUS Unreserve(DOMAIN *domain, ULONG va, ULONG size)` | |
| 07 | 0x406B14 | `NTSTATUS Map(DOMAIN *domain, MAP_DESC *desc, ULONG attributes)` | `desc` = { VA, pointer to { PFN array, page count } }. Maps the pages one by one |
| 08 | 0x406D40 | `NTSTATUS Unmap(DOMAIN *domain, ULONG va, ULONG size)` | Then `TLBIALL` on every attached context bank |
| 09 | 0x406EB0 | `NTSTATUS Protect(DOMAIN *domain, ULONG va, ULONG size, ULONG attributes)` | Changes the attributes of mapped pages, then `TLBIALL` |
| 10 | 0x40709C | `NTSTATUS SetAsid(ULONG ctx_id, ULONG asid)` | `asid` ≤ 0xFF, written in CONTEXTIDR |
| 11 | 0x407330 | `NTSTATUS Attach(ULONG ctx_id, DOMAIN *domain)` | Context bank must be on. Sets TTBCR.N and TTBR0 or TTBR1, enables the translation, `TLBIALL` |
| 12 | 0x40767C | `NTSTATUS Detach(ULONG ctx_id, DOMAIN *domain)` | Puts the default table back; disables the translation when both TTBRs are back to default |
| 13 | 0x405AE0 | `NTSTATUS Translate(ULONG ctx_id, ULONG va, ULONG op, ULONG *par, ULONG *status)` | Hardware address translation. `op`: 0 = user read, 1 = user write, 2 = privileged read, 3 = privileged write. Returns PAR and V2PSR |
| 14 | 0x4078F8 | `NTSTATUS ClearFault(ULONG ctx_id)` | Writes 0 to FSRRESTORE; fails if FSR is still ≠ 0 |
| 15 | 0x4079EC | `NTSTATUS RegisterFaultHandler(ULONG ctx_id, void (*callback)(PVOID), PVOID context)` | Called by the DPC, see [Fault handling](#fault-handling) |
| 16 | 0x407AF8 | `NTSTATUS UnregisterFaultHandler(ULONG ctx_id)` | |
| 17 | 0x4071E8 | `NTSTATUS SetContextPower(ULONG ctx_id, ULONG on)` | 1 = on (`TLBIALL`, pending invalidation cleared), 0 = off |
| 18 | 0x407B98 | `NTSTATUS GetFaultInfo(ULONG ctx_id, ULONG info[22])` | See below. `STATUS_INVALID_DEVICE_STATE` (0xC00000A3) if the context bank is off |
| 19 | 0x407CC4 | `ULONG GetPTCA()` | Value of the ACPI method `PTCA` (0) |
| 20 | 0x407CE0 | `ULONG GetAGPA()` | Value of the ACPI method `AGPA` (1) |

Every function returns `STATUS_UNSUCCESSFUL` (0xC0000001) on an unknown context ID or a bad parameter.

Fault information (function 18, 88 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 0 / 1 | FSR bit 1: translation fault (TF) |
| 04-07 | 0 / 1 | FSR bit 2: access flag fault (AFF) |
| 08-0B | 0 / 1 | FSR bit 3: permission fault (APF) |
| 0C-0F | 0 / 1 | FSR bit 4: TLB miss (TLBMF) |
| 10-13 | 0 / 1 | FSR bit 5: table walk external error (HTWDEEF) |
| 14-17 | 0 / 1 | FSR bit 6: table walk slave error (HTWSEEF) |
| 18-1B | 0 / 1 | FSR bit 7: multi-hit (MHF) |
| 1C-1F | 0 / 1 | FSR bit 16: SL |
| 20-23 | 0 / 1 | FSR bit 30: SS (stalled) |
| 24-27 | 0 / 1 | FSR bit 31: multiple faults |
| 28-4F | | Not written |
| 50-53 | | FSR |
| 54-57 | | FAR |

### Data structures

Global IOMMU table (`dword_40BB2C`, 0xB10 bytes):  
| Offset | Comment |
|--------|---------|
| 0x000 | Number of memory resources (IOMMUs) |
| 0x004 | Number of interrupt resources |
| 0x008 | 15 IOMMU entries of 188 bytes |
| 0xB0C | Default page table |

IOMMU entry (188 bytes): +0x00 IOMMU id, +0x04 number of context banks, +0x08 4 context banks of 44 bytes, +0xB8 virtual address of the registers.  
Context bank (44 bytes): +0x00 context ID, +0x04 IOMMU entry, +0x08 index in the IOMMU, +0x10 translation disabled flag, +0x14 TTBR0 domain, +0x18 TTBR1 domain, +0x1C fault callback, +0x20 callback context, +0x24 on, +0x28 TLB invalidation pending.

---

### IOCTL 0xC3500004

This IOCTL is processed by Qcsmmu8930.sys (`EvtWdfIoQueueIoDeviceControl`, 0x401734)  

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0x1 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the SMMU function table | ≥ 4 | ≥ 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Kernel address of the caller's function table (at least 84 bytes) |

The handler writes the 20 function pointers at offsets 0x04–0x53 of the table pointed to by the InputBuffer (see [Function table](#function-table)); offset 0x00 isn't written. Nothing is written in the OutputBuffer, but it must be at least 4 bytes.  
Completed with `STATUS_SUCCESS` and `BytesReturned` = 0. InputBuffer < 4 bytes, OutputBuffer < 4 bytes or a NULL pointer → `STATUS_UNSUCCESSFUL` (0xC0000001).

> [!NOTE]
> The request is handled by `EvtIoDeviceControl`, not `EvtIoInternalDeviceControl`, and the pointer isn't validated: any caller able to open the device interface can make the driver write 80 bytes of kernel pointers at an arbitrary address. In practice the device can only be used by a kernel-mode client (the functions run in kernel mode).

---

### IOCTL 0xC3500008

This IOCTL is processed by Qcsmmu8930.sys (`EvtWdfIoQueueIoDeviceControl`, 0x401734)  

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0x2 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? | — | — |

Not implemented: always completed with `STATUS_UNSUCCESSFUL` (0xC0000001).

---

Any other IoControlCode → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcsmmu8930.sys to [acpi.sys](./acpi.md#ioctl-0x32c004--ioctl_acpi_eval_method) (`sub_402728`, `WdfIoTargetSendIoctlSynchronously` on the default I/O target)

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI PDO of `QCOM0200` | 8 | 20 (`BCDE`, `PTCA`, `AGPA`) or 80 (`CORE`) |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 69 42` 'AeiB' | Signature |
| 04-07 | `42 43 44 45` "BCDE" | Method name: "BCDE", "PTCA", "AGPA" or "CORE" |

Outputbuffer (e.g. `BCDE`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | `41 65 6F 42` 'AeoB' | Signature: must be 'AeoB' |
| 04-07 | | Length |
| 08-0B | 01 00 00 00 | Count: must be ≠ 0 |
| 0C-0D | 02 00 | Type: buffer (not checked) |
| 0E-0F | 04 00 | DataLength (not checked) |
| 10-… | `03 00 01 10` | Buffer content, see [Lumia 520 ACPI node](#lumia-520-acpi-node) |

A bad signature or Count = 0 → `STATUS_ACPI_INVALID_DATA` (0xC014000F). Only a failure of `BCDE` stops the start of the device.

---

### Interface GUID

Qcsmmu8930 Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{78a1c341-4539-11d3-b88d-00c04fad5171}`
