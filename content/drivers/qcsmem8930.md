## Qcsmem8930.sys

Shared Memory Driver (SMEM).  
It maps the shared memory region used by the application processor, the MODEM, the RPM, the Q6 and the RIVA (WCNSS), and implements the Qualcomm "legacy" SMEM allocator on top of it (fixed buffers + allocation table + heap), the hardware spinlocks, the version check and the SMEM circular logs.  
It doesn't expose any user-mode interface: the other kernel drivers ([qcsmd8930.sys](./qcsmd8930.md), [qcsmsm8930.sys](./qcsmsm8930.md)) open `\Device\SMEM` and get a table of 13 function pointers with [internal IOCTL 0x42000](#internal-ioctl-0x42000), then call these functions directly. [internal IOCTL 0x42004](#internal-ioctl-0x42004) translates the physical address of a small register (outgoing interrupt) into a kernel virtual address.  
The code is a port of the Qualcomm `SmemLib` (`smem.c`, `smem_legacy.c`) and of `smem_log.c`. PDB path: `P:\SMEM\rel\8.2.1.1\arm\Release\qcsmem8930.pdb`.

Device name : `\Device\SMEM`  
There's no symbolic link.  

There's no parameters in the registry.  

GUID of the ETW provider (WPP):  
`{61085ed3-92fb-436b-b828-8a57815e1826}`  

It doesn't communicate with any other device. It only imports `ntoskrnl.exe` and `WDFLDR.SYS`.

Drivers using `\Device\SMEM`:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | [internal IOCTL 0x42000](#internal-ioctl-0x42000) and [internal IOCTL 0x42004](#internal-ioctl-0x42004) |
| \Device\SMSM | [qcsmsm8930.sys](./qcsmsm8930.md) | [internal IOCTL 0x42000](#internal-ioctl-0x42000) and [internal IOCTL 0x42004](#internal-ioctl-0x42004) |

### WDF configuration

`EvtDriverDeviceAdd` (0x4012C4):
- `WdfDeviceInitSetExclusive(FALSE)`, `WdfDeviceInitSetIoType(WdfDeviceIoBuffered)`, name `\Device\SMEM`.
- PnP callbacks: `EvtWdfDevicePrepareHardware`, `EvtWdfDeviceReleaseHardware`, `EvtWdfDeviceSurpriseRemoval`.
- File object: `EvtWdfDeviceFileCreate` completes every create with `STATUS_SUCCESS`.
- `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
- One default parallel queue with only `EvtIoInternalDeviceControl`. There's no `EvtIoDeviceControl`: a regular `DeviceIoControl` from user mode is rejected by the framework.

`EvtWdfDeviceSurpriseRemoval` (0x401CE8) calls `KeBugCheckEx(0x14E, 0x30657371 ("qse0"), 0, 0, 0)`.

### Memory resources

`EvtWdfDevicePrepareHardware` (0x401548) only accepts `CmResourceTypeMemory` resources (any other type → `STATUS_DEVICE_CONFIGURATION_ERROR` 0xC0000182). The values are those of the Lumia 520 (ACPI `_CRS` of the device):  
| Index | Physical address | Length | Mapping | Comment |
|-------|------------------|--------|---------|---------|
| 0 | 0x80000000 | 0x200000 | MmWriteCombined | Shared memory (SMEM) region. Its base is the base of all SMEM offsets |
| 1 | 0x01200604 | 0x80 | MmNonCached | Hardware spinlocks (mutex registers), one DWORD per lock. Must be at least 32 bytes (8 locks), else `STATUS_DEVICE_CONFIGURATION_ERROR` |
| 2 | 0x02011008 | 4 | MmNonCached | Additional resource #0. Outgoing interrupt register used by qcsmd8930.sys ? |
| 3 | 0x12104080 | 4 | MmNonCached | Additional resource #1. Outgoing interrupt register used by qcsmd8930.sys ? |
| 4 | 0x12104094 | 4 | MmNonCached | Additional resource #2. Outgoing interrupt register used by qcsmd8930.sys ? |

The additional resources (index ≥ 2) must have a length of exactly 4 bytes. Their physical and virtual addresses are stored in `arrayAdditionalMemoryResources` (pool tag `qse1`, 8 bytes per entry: physical address, then virtual address), which is searched by [internal IOCTL 0x42004](#internal-ioctl-0x42004).  
Then `PrepareHardware` calls `smem_init` and allocates the main SMEM log (see [SMEM logs](#smem-logs)). `EvtWdfDeviceReleaseHardware` unmaps everything.

### SMEM layout

The beginning of the SMEM region contains fixed buffers, at consecutive offsets given by the table `smem_legacy_buf_data_tbl` (`.rdata:0x004040D0`):  
| Offset | Size | Item (`smem_mem_type`) | Comment |
|--------|------|------------------------|---------|
| 0x0000 | 64 | 0 SMEM_MEM_FIRST | Proc comm |
| 0x0040 | 128 | 3 SMEM_VERSION_INFO | 32 DWORDs, one per processor/protocol |
| 0x00C0 | 16 | 1 SMEM_HEAP_INFO | `initialized`, `free_offset`, `heap_remaining`, reserved |
| 0x00D0 | 8192 | 2 SMEM_ALLOCATION_TABLE | 512 entries of 16 bytes: `allocated`, `offset`, `size`, reserved |
| 0x20D0 | 8 | 4 SMEM_HW_RESET_DETECT | |
| 0x20D8 | 4 | 5 SMEM_RESERVED_AARM_WARM_BOOT | |
| 0x20DC | 200 | 6 SMEM_DIAG_ERR_MESSAGE | |
| 0x21A4 | 32 | 7 SMEM_SPINLOCK_ARRAY | |
| 0x21C4 | 4 | 8 SMEM_MEMORY_BARRIER_LOCATION | Last fixed buffer |

`smem_init` (0x401FCC):
1. Sets the base address to the virtual address of the memory resource 0.
2. If `SMEM_HEAP_INFO.initialized` ≠ 1 (the heap is initialized by the boot loader), it only traces an error: the state stays `UNINITIALIZED` and the number of usable spinlocks stays 0.
3. Otherwise: number of spinlocks = 8, state = `INITIALIZED`, and `SMEM_VERSION_INFO[8] |= 0xB0000` (`SMEM_LEGACY_VERSION_ID`). The upper 16 bits of the 32 entries must be 0 or 0xB0000; a mismatch is only traced.

Dynamic items allocated by [qcsmsm8930.sys](./qcsmsm8930.md#shared-memory) with `smem_alloc` (names from the Linux kernel):  
| Item (`smem_mem_type`) | Size | Comment |
|------------------------|------|---------|
| 85 (0x55) SMEM_SMSM_SHARED_STATE | 4 × entries | One state DWORD per SMSM entry |
| 333 (0x14D) SMEM_SMSM_CPU_INTR_MASK | 4 × entries × hosts | Interrupt masks of the SMSM entries |
| 419 (0x1A3) SMEM_SMSM_SIZE_INFO | 16 | Number of SMSM hosts and entries (0 = defaults: 5 hosts, 8 entries) |

qcsmsm8930.sys also calls `smem_version_set(109 (0x6D), 1, 0xFFFFFFFF)` (SMSM version ?), and [qcsmd8930.sys](./qcsmd8930.md#initialisation) calls `smem_version_set(SMEM_VERSION_SMD 0x6B, 0x00020000, 0xFFFFFFFF)`.

### Function table

Returned by [internal IOCTL 0x42000](#internal-ioctl-0x42000). All functions can be called at IRQL ≤ DISPATCH_LEVEL.  
| Position | Address | Function signature | Comment |
|----------|---------|--------------------|---------|
| 00 | 0x402130 | `void *smem_alloc(smem_mem_type smem_type, ULONG buf_size)` | Returns the existing buffer, or allocates it in the heap. Returns NULL if the size doesn't match an existing allocation, if the heap is full, or if `smem_type` ≥ 426 (`SMEM_INVALID`). The size is rounded up to a multiple of 8 |
| 01 | 0x402308 | `void *smem_get_addr(smem_mem_type smem_type, ULONG *size)` | Returns an already allocated buffer and its size, or NULL / size 0. A buffer outside the SMEM region is rejected |
| 02 | 0x4024A0 | `void nullsub_1()` | No-op stub (`smem_free` in the original table ?) |
| 03 | 0x4024A8 | `BOOLEAN smem_version_set(smem_mem_type type, ULONG version, ULONG mask)` | `type` must be `SMEM_VERSION_INFO` or in `SMEM_VERSION_FIRST`(0x6B)..`SMEM_VERSION_LAST`. ORs `version & mask` into entry 8 of the 32-DWORD version array, then returns FALSE if another entry has a different non-zero `value & mask` |
| 04 | 0x402994 | `void smem_spin_lock(int lock)` | See [Spinlocks](#spinlocks) |
| 05 | 0x402A10 | `void smem_spin_unlock(int lock)` | See [Spinlocks](#spinlocks) |
| 06 | 0x4027A8 | `ULONG smem_read_log_events(ULONG log, ULONG max_entries, void *buffer, ULONG *lost, ULONG *remaining)` | Copies up to `max_entries` unread 20-byte entries of log 0 or 1. Returns the number of entries copied, or 0xFFFFFFFF |
| 07 | 0x40253C | `int smem_init_log_buffer(ULONG log)` | Allocates the SMEM buffers of log 0 or 1. Returns 0 or -1 |
| 08 | 0x4025D0 | `void smem_write_log_event3(ULONG log, ULONG event_id, ULONG unused, ULONG data1, ULONG data2, ULONG data3)` | Writes 1 entry |
| 09 | 0x402698 | `void smem_write_log_event6(ULONG log, ULONG event_id, ULONG unused, ULONG data1, … ULONG data6)` | Writes 2 consecutive entries; the second has the continuation bits 0x10000000 |
| 10 | 0x402A74 | `void smem_set_lock0(ULONG pid)` | Misleading name: releases (writes 0 to) every hardware spinlock whose value is `pid`, i.e. frees the locks held by a processor that has restarted |
| 11 | 0x401D8C | `ULONG smem_get_firstMemoryResourcePhysicalStart()` | Physical address of the SMEM region (0x80000000) |
| 12 | 0x401D3C | `ULONG smem_get_firstMemoryResourceLength()` | Length of the SMEM region (0x200000) |

`smem_alloc` and `smem_get_addr` serve the fixed buffers (types 0–8) directly from the table above (no lock). For dynamic items they take the spinlock 3 (`SMEM_SPINLOCK_SMEM_ALLOC`) and use the allocation table / heap info. If `smem_init` hasn't completed, `smem_alloc` returns NULL for dynamic items.

### Spinlocks

A spinlock `lock` (0 ≤ `lock` < 8) is the DWORD at `0x01200604 + 4*lock` (memory resource 1). Lock numbers used: 2 = `SMEM_SPINLOCK_SMEM_LOG`, 3 = `SMEM_SPINLOCK_SMEM_ALLOC`.  
`smem_spin_lock` acquires a single global `KSPIN_LOCK` (`KeAcquireSpinLockRaiseToDpc`), then writes **0** to the register and loops until it reads back 0. `smem_spin_unlock` writes 0 and releases the `KSPIN_LOCK`.

> [!NOTE]
> The value written to acquire a lock is 0, the same value as the release. On other Qualcomm kernels, the application processor writes its processor id (1) and waits until it reads it back. So the hardware lock is probably never really taken by Windows ?, and the only exclusion is the local `KSPIN_LOCK` (shared by all lock numbers, and not reentrant: nested locks would deadlock).

A lock number out of range only produces a trace (no lock is taken).

### SMEM logs

Two circular logs are described by 2 structures of 12 DWORDs (`.data:0x00405150` and `.data:0x00405180`):  
| Index | Log 0 | Log 1 | Comment |
|-------|-------|-------|---------|
| 0 | 0 | 0 | ? |
| 1 | 1 | 1 | When 1, the spinlock is kept while the entry is written. Must be 1 to read the log |
| 2 | 2000 | 2000 | Number of entries |
| 3 | 79 SMEM_SMEM_LOG_EVENTS | 407 SMEM_SMEM_LOG_POWER_EVENTS | Entries (2000 × 20 bytes) |
| 4 | 78 SMEM_SMEM_LOG_IDX | 405 SMEM_SMEM_LOG_POWER_IDX | Write index (4 bytes) |
| 5 | 417 SMEM_SMEM_LOG_MPROC_WRAP | 406 SMEM_SMEM_LOG_POWER_WRAP | Wrap counter (4 bytes) |
| 6 | 2 | 2 | Spinlock number |
| 7–9 | | | Virtual addresses of the 3 items above (filled by `smem_alloc`) |
| 10–11 | | | Read index and read wrap counter (local, used by `smem_read_log_events`) |

Log 0 is allocated by `EvtWdfDevicePrepareHardware`; log 1 only when a client calls `smem_init_log_buffer(1)`.

Format of a log entry:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Event id \| 0x80000000. Bits 31-30 = processor (10 = apps), bits 29-28 = continuation, bits 27-16 = subsystem, bits 15-0 = event |
| 04-07 | ? | Timestamp in 32768 Hz ticks (`KeQueryInterruptTime` × 32768 / 10000000) |
| 08-0B | ? | data1 |
| 0C-0F | ? | data2 |
| 10-13 | ? | data3 |

See [smem_log.h](https://github.com/nobodyAtall/msm7x30-3.0.x-nAa/blob/9a90723d58fd4e97cdf6498f2f9654b9cb6775ef/arch/arm/mach-msm/include/mach/smem_log.h).

---

### internal IOCTL 0x42000

This internal IOCTL is processed by Qcsmem8930.sys (`EvtWdfIoQueueIoInternalDeviceControl`, 0x401A4C).  
Kernel-mode only: it must be sent as `IRP_MJ_INTERNAL_DEVICE_CONTROL`.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the SMEM function table | 0 | ≥ 52 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-33 | ? | 13 function pointers, see [Function table](#function-table) |

Completed with `BytesReturned` = 52. An OutputBuffer smaller than 52 bytes → `STATUS_BUFFER_TOO_SMALL` (from `WdfRequestRetrieveOutputBuffer`).
[qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x42000) and [qcsmsm8930.sys](./qcsmsm8930.md#internal-ioctl-0x42000) send it once at start with a 52-byte OutputBuffer, and fail to start (`STATUS_IO_DEVICE_ERROR`) if `BytesReturned` ≠ 52.

---

### internal IOCTL 0x42004

This internal IOCTL is processed by Qcsmem8930.sys (`EvtWdfIoQueueIoInternalDeviceControl`, 0x401A4C).  
Kernel-mode only: it must be sent as `IRP_MJ_INTERNAL_DEVICE_CONTROL`.

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Translate the physical address of an additional memory resource | ≥ 8 | ≥ 8 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 08 10 01 02 | Physical address (e.g. 0x02011008) |
| 04-07 | 00 00 00 00 | Ignored (upper part of the physical address ?) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | Not written. With METHOD_BUFFERED the input and output share the same buffer, so it still contains the physical address |
| 04-07 | ? | Kernel virtual address of the 4-byte mapping |

The handler looks for the physical address in `arrayAdditionalMemoryResources` (memory resources 2, 3, 4 only: the SMEM region and the spinlocks can't be translated).  
Found → `STATUS_SUCCESS`. Not found (or no additional resource) → `STATUS_NOT_FOUND` (0xC0000225). In both cases `BytesReturned` = 8.  
A buffer smaller than 8 bytes → `STATUS_BUFFER_TOO_SMALL`.
Sent by [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x42004) and [qcsmsm8930.sys](./qcsmsm8930.md#internal-ioctl-0x42004), once per entry of their ACPI method `INTR`, to get the virtual address of the outgoing interrupt registers. A virtual address of 0 makes them reject the `INTR` configuration.

---

Any other IoControlCode → `STATUS_NOT_SUPPORTED` (0xC00000BB).

### Interface GUID

Qcsmem8930 Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{54415e20-5fc4-4938-8958-31966f441c63}`
