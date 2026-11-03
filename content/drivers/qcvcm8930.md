## Qcvcm8930.sys

Virtual Contiguous Memory (VCM) library: the client API of the SMMU.  
It's a kernel-mode **export driver** (a DLL loaded by the kernel when a driver that imports it is loaded: `DllInitialize` / `DllUnload`, no `DriverEntry` work, no device object). It exports 43 `Vcm*` functions and `SmmuPrefetchTLB`, a port of the Qualcomm/Linux "VCM" API (`include/linux/vcm.h` of the MSM kernels): a client creates a VCM (a device virtual address space), associates it with one or more SMMU context banks, reserves ranges in it, and backs the reservations with physical pages (MDLs). The VCM only manages the address space (a sorted list of free/used regions); every page-table and context-bank operation is delegated to [qcsmmu8930.sys](./qcsmmu8930.md) through the function table that driver returns with [IOCTL 0xC3502004](#ioctl-0xc3502004).  
Users (static imports): [qcdxkm8930.sys](./qcdxkm8930.md) (GPU, MDP, rotator, video codec), [qccamavs8930.sys](./qccamavs8930.md), [qccamgemini8930.sys](./qccamgemini8930.md) and [qcvpe8930.sys](./qcvpe8930.md).  
Source files (from the trace strings): `driver.cpp`, `interface.cpp`, `Vcm.cpp`, `VcmManagement.cpp`. PDB path: `P:\SMMU\rel\8.2.1\arm\Release\qcvcm8930.pdb`.

There's no device name and no symbolic link.  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcsmmu` (the **service key of qcsmmu8930.sys**, hardcoded as `\Registry\Machine\System\CurrentControlSet\Services\qcsmmu`; read once by `DllInitialize` with `ZwOpenKey` / `ZwQueryValueKey`, `sub_100014D0`). Both are REG_DWORD; a missing value = 0:  
| Registry value | value | comment |
|----------------|-------|---------|
| EnablePtCaching | ? | 1 = create the page tables with the caching type given to `VcmCreateExtended` (only if the ACPI method `PTCA` of qcsmmu8930 also returns 1). Otherwise the page tables are always non-cached (`MmNonCached`) |
| EnableGuardPages | ? | 1 = a reservation with the attribute bit 0x400 gets one more 4 KB page at its end (guard page; only if the ACPI method `AGPA` of qcsmmu8930 also returns 1) |

On the Lumia 520 `PTCA` = 0 and `AGPA` = 1 (see [qcsmmu8930.sys](./qcsmmu8930.md#lumia-520-acpi-node)): `EnablePtCaching` has no effect, `EnableGuardPages` does.

GUID of the ETW provider (manifest-based, `EtwRegister`). It's the **same GUID as [qcsmmu8930.sys](./qcsmmu8930.md)**: the two drivers write to the same provider:  
`{1a64bee1-de91-4a1e-bafc-c461666f1daa}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Device interface `{78a1c341-4539-11d3-b88d-00c04fad5171}` (first instance) | [qcsmmu8930.sys](./qcsmmu8930.md) | [IOCTL 0xC3502004](#ioctl-0xc3502004), once in `DllInitialize`, then direct calls through the returned function table |

Imports: only `ntoskrnl.exe` (no WDF).

### Initialisation

`DllInitialize` (0x10001250), called when the first importing driver is loaded:
1. `EtwRegister` of the provider.
2. `sub_10001438`: allocates the SMMU function table (84 bytes, pool tag `qvc8`, `off_10009184`) and sends [IOCTL 0xC3502004](#ioctl-0xc3502004) to qcsmmu8930.sys to fill it (`sub_100018A0`). `IoGetDeviceInterfaces` on `{78a1c341-4539-11d3-b88d-00c04fad5171}`, `IoGetDeviceObjectPointer` on the first symbolic link (access 0x1F01FF), then `IoBuildDeviceIoControlRequest` + `IofCallDriver`. A failure is only traced.
3. Allocates one 4 KB page (`MmAllocatePagesForMdlEx`: any physical address, 4096 bytes, CacheType 5 = `MmUSWCCached` ?, the Flags argument isn't set; `dword_10009188`): the **fill page** of `VcmBackFill`.
4. Allocates the settings (16 bytes, pool tag `qvc9`, `dword_1000918C`): `EnablePtCaching`, `EnableGuardPages`, then the values returned by the SMMU functions 19 (`PTCA`) and 20 (`AGPA`).

`DllInitialize` always returns `STATUS_SUCCESS`.

> [!NOTE]
> The SMMU device must already be started when the first client is loaded: if the IOCTL fails, the function table (not zeroed) is called anyway in step 4. The ACPI `_DEP` on `\_SB.SMMU` of `\_SB.GPU0`, `\_SB.GPU0.AVS0`, `\_SB.CAMG`, `\_SB.VFE0` and `\_SB.VPE` ensures this order. The file object returned by `IoGetDeviceObjectPointer` is never dereferenced.

`DllUnload` (0x100013A4) frees the fill page, the function table and the settings, and unregisters the ETW provider.

### Objects

All the objects are allocated from `NonPagedPoolNx`. Each one has a magic value, checked by every function (a wrong magic → trace and error):  
| Object | Size | Pool tag | Magic (offset) | Created by |
|--------|------|----------|----------------|------------|
| VCM | 0x28 | `qvc1` | 0x01020304 (+0x24) | `VcmCreate`, `VcmCreateExtended` |
| Guarded mutex of a VCM | 0x20 | `qvc2` | | `VcmCreateExtended` |
| Reservation | 0x28 | `qvc3` | 0x04030201 (+0x24) | `VcmReserve*` |
| Association | 0x14 | `qvc4` | 0x05060708 (+0x10) | `VcmAssoc` |
| Bound | 0x1C | `qvc5` | 0x02040608 (+0x18) | `VcmCreateBound` |
| Physmem (fake MDL) | 0x1C + 4 × pages | `qvc6` | | `VcmMapPhysicalMemory` |
| Region (list node) | 0x1C | `qvc7` | | Region list management (`VcmManagement.cpp`) |
| SMMU function table | 0x54 | `qvc8` | | `DllInitialize` |
| Settings | 0x10 | `qvc9` | | `DllInitialize` |

VCM (0x28 bytes):  
| Offset | Comment |
|--------|---------|
| 0x00 | Region list (first node) |
| 0x04 | 1 = associated with at least one context bank. Required by `VcmReserve*` and `VcmCreateBound` |
| 0x08 | 1 = the SMMU domain isn't created yet |
| 0x0C | Number of associations |
| 0x10 | SMMU domain (page table, function 1 of qcsmmu8930) |
| 0x14 | Start of the device address range |
| 0x18 | Size of the range |
| 0x1C | Guarded mutex (protects the region list and the SMMU calls) |
| 0x20 | Caching type of the page tables (`VcmCreateExtended` argument if `EnablePtCaching` = 1 and `PTCA` = 1, else 0 = `MmNonCached`) |
| 0x24 | Magic 0x01020304 |

Reservation (0x28 bytes):  
| Offset | Comment |
|--------|---------|
| 0x00 | VCM |
| 0x04 | Bound (reservations made in a bound), or 0 |
| 0x08 | Device address (returned by `VcmGetDevAddr`) |
| 0x0C | Number of backed pages |
| 0x10 | Physmem (MDL) given to `VcmBack` |
| 0x14 | 1 = backed |
| 0x18 | Byte: 1 = the end of the reservation is filled with the fill page (`VcmBackFill`) |
| 0x1C | Attributes (see [Attributes](#attributes)) |
| 0x20 | Size, rounded up to 4 KB (+ 4 KB guard page) |
| 0x24 | Magic 0x04030201 |

Association (0x14 bytes): +0x00 VCM, +0x04 SMMU context ID, +0x08 association attribute (2, 4 or 8), +0x0C 1 = not active, +0x10 magic 0x05060708.  
Bound (0x1C bytes): +0x00 region list of the bound, +0x04 parent VCM, +0x08 flags, +0x0C 0, +0x10 start address, +0x14 size, +0x18 magic 0x02040608.  
Region (0x1C bytes): +0x00 start, +0x04 size, +0x08 state (3 = free, 0 = reserved, 1 = backed), +0x0C byte: 1 = the region is a bound, +0x10 reservation or bound, +0x14 next, +0x18 previous.

A new VCM has one free region covering its whole range. A reservation takes the first free region that can hold it with the requested alignment (`sub_10001D58`) and splits it; freeing merges the neighbouring free regions (`sub_10001EC4`).

### Lifecycle

Typical use ([qccamgemini8930.sys](./qccamgemini8930.md#smmu-vcm)):
1. `vcm = VcmCreate(start, size)`.
2. `assoc = VcmAssoc(vcm, ctx_id, 4)` for each context bank, then `VcmActivate(assoc)`. The **first** `VcmAssoc` creates the SMMU domain (function 1 `CreateDomain(start, size, type, cache)`), shared by all the context banks of the VCM; `VcmActivate` attaches it to the context bank (function 11).
3. For each buffer: `res = VcmReserve(vcm, size, attr)`, `physmem = VcmMapMdlToPhysmem(mdl)`, `VcmBack(res, physmem)`, `devaddr = VcmGetDevAddr(res)`.
4. Release in the reverse order: `VcmUnback`, `VcmUnMapMdlFromPhysmem`, `VcmUnreserve`, `VcmDeactivate`, `VcmDeassoc`, `VcmFree`.

### Exported functions

Signatures reconstructed from the code (names of the exports; argument names are tentative). Unless noted, a function returning a handle returns NULL on error, and a function returning NTSTATUS returns `STATUS_INVALID_PARAMETER` (0xC000000D) on a NULL handle or a wrong magic, and `STATUS_UNSUCCESSFUL` (0xC0000001) when the SMMU call fails. The "SMMU" column is the position in the [qcsmmu8930 function table](./qcsmmu8930.md#function-table).  
| Ordinal | Address | Function signature | SMMU | Comment |
|---------|---------|--------------------|------|---------|
| 11 | 0x10006880 | `VCM *VcmCreate(ULONG start, ULONG size)` | | `VcmCreateExtended(start, size, 0)` |
| 13 | 0x100025E8 | `VCM *VcmCreateExtended(ULONG start, ULONG size, MEMORY_CACHING_TYPE pt_cache)` | | `size` ≠ 0 and `start + size` ≤ 4 GB. Doesn't call the SMMU |
| 16 | 0x100028BC | `NTSTATUS VcmFree(VCM *vcm)` | 2 | `STATUS_DEVICE_BUSY` (0x80000011) if still associated or if a reservation/bound remains. Destroys the domain if it was created |
| 30 | 0x100068C0 | `RES *VcmReserve(VCM *vcm, ULONG size, ULONG attr)` | 5 | `VcmReserveAligned(vcm, size, attr, 2)` (4 KB alignment) |
| 31 | 0x10002B1C | `RES *VcmReserveAligned(VCM *vcm, ULONG size, ULONG attr, ULONG align)` | 5 | Alignment = 1 KB << `align` (at least 4 KB), `align` ≤ 21. The VCM must be associated. Size rounded up to 4 KB, + 4 KB with a guard page. Then `Reserve(domain, devaddr, size)` |
| 33 | 0x10002EC8 | `RES *VcmReserveAt(ULONG devaddr, VCM *vcm, ULONG size, ULONG attr)` | 5 | Reserves at a fixed address (must be 1 KB aligned and inside a free region). Note the argument order |
| 44 | 0x100032A4 | `NTSTATUS VcmUnreserve(RES *res)` | 6 | `STATUS_DEVICE_BUSY` if still backed. `Unreserve` isn't called for a reservation in a bound with flag 2 |
| 37 | 0x10003580 | `NTSTATUS VcmSetReservationAttr(RES *res, ULONG attr)` | 9 | Stores the attributes; if backed, `Protect(domain, devaddr, size, attr)` |
| 26 | 0x1000371C | `ULONG VcmGetReservationAttr(RES *res)` | | 0 on error |
| 6 | 0x1000380C | `NTSTATUS VcmBack(RES *res, PMDL physmem)` | 7 | Maps the pages of the MDL (PFN array at +0x1C, `ByteCount` at +0x14) at the start of the reservation: `Map(domain, {devaddr, {PFN array, pages, 4096}}, attr)`. Fails if already backed or if the MDL is larger than the reservation. The MDL may be smaller (see `VcmBackFill`) |
| 41 | 0x10003A88 | `NTSTATUS VcmUnback(RES *res)` | 8 | `Unmap(domain, devaddr, pages × 4096)`. Fails if not backed or still filled (`VcmBackUnfill` first) |
| 7 | 0x10005C28 | `NTSTATUS VcmBackFill(RES *res)` | 7 | Maps the **fill page** (`DllInitialize`, step 3) on every page of the reservation after the backed pages, one by one. On error the pages already filled are unmapped. Returns `STATUS_UNSUCCESSFUL` if the reservation isn't backed or is already full |
| 9 | 0x10005F10 | `NTSTATUS VcmBackUnfill(RES *res)` | 8 | Unmaps the filled part |
| 5 | 0x100069C0 | `ASSOC *VcmAssoc(VCM *vcm, ULONG ctx_id, ULONG attr)` | 1 | `attr` must be 8, 4 or 2 → domain type 0, 1 or 2 (TTBR0 / TTBR1 selection, see [qcsmmu8930 page tables](./qcsmmu8930.md#page-tables)). Only the first association creates the domain, with its `attr` |
| 15 | 0x100069E0 | `NTSTATUS VcmDeassoc(ASSOC *assoc)` | | `STATUS_DEVICE_BUSY` if still active |
| 18 | 0x10006A00 | `ULONG VcmGetAssocAttr(ASSOC *assoc)` | | |
| 4 | 0x10006A20 | `NTSTATUS VcmActivate(ASSOC *assoc)` | 11 | `Attach(ctx_id, domain)` |
| 14 | 0x10006A40 | `NTSTATUS VcmDeactivate(ASSOC *assoc)` | 12 | `Detach(ctx_id, domain)`. Already inactive → `DbgPrint` " VcmDeativate failed: already deactive" and 0x80000010 (`STATUS_DEVICE_OFF_LINE`) |
| 38 | 0x10006A60 | `ULONG VcmTranslate(ULONG devaddr, VCM *src, VCM *dst)` | | Address in `dst` of the same physical memory: finds the backed reservation of `src` containing `devaddr`, then a backed reservation of `dst` with the same physmem, and returns `dst_res.devaddr + (devaddr − src_res.devaddr)`. Errors are printed with `DbgPrint` ("VcmTranslate: …") and return 1 |
| 21 | 0x10006A80 | `ULONG VcmGetDevAddr(RES *res)` | | Device address of the reservation, 1 on error |
| 25 | 0x10006AA0 | `RES *VcmGetReservation(ULONG devaddr, VCM *vcm)` | | Reservation containing `devaddr` (searched recursively in the bounds) |
| 24 | 0x10006AC0 | `PMDL VcmGetPhysmemFromReservation(RES *res)` | | NULL if not backed |
| 27 | 0x10006B00 | `PMDL VcmMapMdlToPhysmem(PMDL mdl)` | | `BX LR`: returns its argument. A physmem **is** an MDL |
| 39 | 0x10006B20 | `NTSTATUS VcmUnMapMdlFromPhysmem(PMDL physmem)` | | No-op, returns 0 |
| 28 | 0x10006D00 | `PMDL VcmMapPhysicalMemory(ULONG physical, ULONG size)` | | Builds a physmem (fake MDL, pool tag `qvc6`) for a contiguous physical range. **Buggy**: the page count is read from the uninitialised `ByteCount` field before it's written, and every PFN is written in the same slot (`PFN[0]`), so only a 1-page range can work ? |
| 40 | 0x10006D20 | `NTSTATUS VcmUnMapPhysicalMemory(PMDL physmem)` | | Frees a physmem of `VcmMapPhysicalMemory` |
| 23 | 0x10006AD0 | `ULONG VcmGetPageOnePhysicalAddress(PMDL physmem)` | | `PFN[0] << 12`: physical address of the first page |
| 12 | 0x10006B40 | `BOUND *VcmCreateBound(VCM *vcm, ULONG size, ULONG flags)` | 5 | Reserves a 1 MB aligned sub-range (size rounded up to 4 KB) with its own region list. `flags`: bit 1 (2) = reserve the SMMU tables of the whole bound now; bit 2 (4) = bound managed by the caller with `VcmBackInBound` (requires bit 1). The VCM must be associated |
| 17 | 0x10006BC0 | `NTSTATUS VcmFreeBound(BOUND *bound)` | 6 | `STATUS_DEVICE_BUSY` if a reservation remains |
| 20 | 0x10006BE0 | `ULONG VcmGetBoundStartAddr(BOUND *bound)` | | 1 on error |
| 19 | 0x10006C00 | `ULONG VcmGetBoundSize(BOUND *bound)` | | 0 on error |
| 35 | 0x10006B60 | `RES *VcmReserveInBound(BOUND *bound, ULONG size, ULONG attr)` | 5 | `VcmReserveAlignedInBound(bound, size, attr, 2)` |
| 32 | 0x10006B80 | `RES *VcmReserveAlignedInBound(BOUND *bound, ULONG size, ULONG attr, ULONG align)` | 5 | Same as `VcmReserveAligned` inside the bound. Rejected for a bound with flag 4. `Reserve` not called when the bound has flag 2 |
| 34 | 0x10006BA0 | `RES *VcmReserveAtInBound(ULONG devaddr, BOUND *bound, ULONG size, ULONG attr)` | 5 | Same as `VcmReserveAt` inside the bound. Rejected for a bound with flag 4 |
| 8 | 0x10006D8C | `NTSTATUS VcmBackInBound(BOUND *bound, ULONG devaddr, ULONG size, PMDL physmem, USHORT attr)` | 7 | Bound with flag 4 only. `size` must equal the MDL size rounded up to 4 KB. Maps directly, without reservation object (`sub_100063C8`) |
| 42 | 0x10006DC0 | `NTSTATUS VcmUnbackInBound(BOUND *bound, ULONG devaddr, ULONG size)` | 8 | Bound with flag 4 only |
| 29 | 0x10006CA0 | `NTSTATUS VcmRegisterIsr(ULONG ctx_id, void (*callback)(PVOID), PVOID context)` | 15 | Fault callback, called by the SMMU DPC. `callback` NULL → `STATUS_UNSUCCESSFUL` |
| 43 | 0x10006CB0 | `NTSTATUS VcmUnregisterIsr(ULONG ctx_id)` | 16 | |
| 10 | 0x10006C50 | `NTSTATUS VcmClearFault(ULONG ctx_id)` | 14 | |
| 22 | 0x10006E00 | `NTSTATUS VcmGetFaultInfo(ULONG ctx_id, ULONG info[22])` | 18 | `info` NULL → `STATUS_UNSUCCESSFUL` |
| 36 | 0x10006D30 | `NTSTATUS VcmSetContextState(ULONG ctx_id, ULONG on)` | 17 | Context bank power state |
| 3 | 0x10006E10 | `NTSTATUS SmmuPrefetchTLB(ULONG ctx_id, ULONG va, ULONG op, ULONG *par, ULONG *status)` | 13 | Direct call of `Translate` (hardware address translation, which loads the TLB) |

Ordinals 1 and 2 are `DllInitialize` and `DllUnload`. The SMMU functions 3 (`GetDomainTable`), 4 (`GetRegisters`) and 10 (`SetAsid`) are never used.

### Attributes

The reservation attributes are the Linux VCM attributes (`vcm_types.h`: `VCM_READ`, `VCM_WRITE`…; names tentative). They are converted to the attribute word of the SMMU `Map` / `Protect` functions by `sub_10002534`:  
| VCM bit | Name | SMMU bits |
|---------|------|-----------|
| 0x200 + 0x40 | Supervisor + write | 0x40 |
| 0x200 + 0x20 | Supervisor + read | 0x10 |
| 0x100 + 0x40 | User + write | 0x80 |
| 0x100 + 0x20 | User + read | 0x20 |
| 0x80 clear | Not executable | 0x01 (XN) |
| 0x10 | Shared | 0x02 |
| 0x0F ≠ 0 | Cache policy | 0x200 (normal memory) \| cache bits 0xF000 (0xD000 for policies 4 and 6) |
| 0x400 | Guard page | — (see `EnableGuardPages`) |

The cache-policy conversion tests `(attr & n) != 0` instead of `(attr & 0xF) == n`, so all the non-zero policies give (almost) the same cache bits. A policy of 0 gives memory type 0 (strongly-ordered).  
E.g. [qccamgemini8930.sys](./qccamgemini8930.md#smmu-vcm) reserves with 0x3E0 (read/write for user and supervisor, executable, policy 0) → SMMU attribute 0xF0.

---

### IOCTL 0xC3502004

This IOCTL is sent by Qcvcm8930.sys to [qcsmmu8930.sys](./qcsmmu8930.md#ioctl-0xc3502004) (`sub_100018A0`, `IoBuildDeviceIoControlRequest` with `InternalDeviceIoControl` = FALSE, synchronous)

| Property | Value |
|----------|-------|
| Device | 0xC350 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get the SMMU function table | First instance of the interface `{78a1c341-4539-11d3-b88d-00c04fad5171}` | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Kernel address of the 84-byte table (`off_10009184`). qcsmmu8930.sys writes the 20 function pointers at offsets 0x04–0x53 |

The status of the request is returned to `DllInitialize`, which only traces a failure. No interface found → `STATUS_UNSUCCESSFUL` (0xC0000001), without sending the IOCTL.
