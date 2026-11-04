## Dumpfve.sys

BitLocker Drive Encryption crash dump filter (Microsoft, `dumpfve.pdb`).  
It is a _dump filter driver_: it isn't started as a service, [crashdmp.sys](./crashdmp.md) loads a private copy of it (`dump_dumpfve.sys` for the crash dump stack, `hiber_dumpfve.sys` for the hibernation stack ?) because it is listed in the registry value `DumpFilters` of `CrashControl`. It sits between the kernel and the dump port driver and encrypts, with the BitLocker key of the volume, the data written in the dump/hibernation file, so the file stays readable through the BitLocker volume filter (`fvevol.sys`) after the reboot. It also decrypts the data read back from the hibernation file (`DumpRead`).  
The key material and the layout of the encrypted volume are obtained at initialisation from `fvevol.sys` with [IOCTL 0x4556D0C3](#ioctl-0x4556d0c3). If the volume isn't encrypted (`fvevol.sys` returns `STATUS_NOT_IMPLEMENTED`), the filter loads anyway and lets all the writes pass unchanged.  
It embeds its own crypto code (SymCrypt: AES, AES-CBC, AES-CCM, SHA-1, SHA-256, HMAC, PBKDF2, plus the BitLocker _Elephant_ diffuser) and runs the FIPS known-answer self-tests at load time (`FveLibFipsKat`). A fatal SymCrypt error calls `KeBugCheck`.  
Pool tag: `dFVE`.

There's no device name and no symbolic link. It doesn't process any IOCTL.  
There's no parameters in the registry.  
Imports: `ntoskrnl.exe` only (`IoBuildDeviceIoControlRequest`, `IofCallDriver`, `MmAllocateContiguousNodeMemory`, `MmGetPhysicalAddress`, `PoSetHiberRange`, `KeInvalidateRangeAllCaches`, `KeBugCheck`, …).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Volume of the dump file (`FILTER_EXTENSION.DeviceObject`) | fvevol.sys ? | BitLocker volume filter. Receives [IOCTL 0x4556D0C3](#ioctl-0x4556d0c3) and [IOCTL 0x4556D0C7](#ioctl-0x4556d0c7) |

### Initialisation

`DriverEntry` (0x12458) is called by [crashdmp.sys](./crashdmp.md) with the 2 parameters of a dump filter: `FILTER_EXTENSION *` and `FILTER_INITIALIZATION_DATA *`.

`FILTER_EXTENSION` (offsets used):  
| Offset | Comment |
|--------|---------|
| 0x00 | Dump type: 1 = crash dump, other = hibernation (2 ?) |
| 0x04 | Device object of the volume, target of the IOCTLs |
| 0x1C | Bytes per sector (`Geometry.BytesPerSector`), kept at offset 0x04 of the context |
| 0x40 | `DumpData` = context of dumpfve.sys (see below) |
| 0x44 | ? Must be ≥ 0x50 for the test of offset 0x48 |
| 0x48 | ? Flags, bit 0 used by `DumpWrite` |

`FILTER_INITIALIZATION_DATA` filled by `DriverEntry`:  
| Offset | Value | Comment |
|--------|-------|---------|
| 0x00 | 2 | Version (written only when flag 1 is set, which `DriverEntry` always sets) |
| 0x08 | `DumpStart` (0x1798C) | |
| 0x0C | `DumpWrite` (0x17908) | |
| 0x10 | `DumpFinish` (0x156DC) | No-op, returns 0 |
| 0x14 | `DumpUnload` (0x16F44) | |
| 0x18 | context | `DumpData`, 16384 bytes of NonPagedPoolNx, tag `dFVE` |
| 0x1C | (input) | Maximum number of pages per write. More than 0x10000 → `STATUS_INVALID_PARAMETER` (0xC000000D) |
| 0x20 | \|= 1 | Flags. Bit 0 set by the driver (support of `DumpRead`). Bit 1 is tested by `DumpWrite` |
| 0x24 | `DumpRead` (0x1747C) | |

`GetFveContext` (0x12514):
1. `FveLibInitEx`: initialises AES and runs the self-tests (AES-CCM, AES-CBC, HMAC-SHA256, HMAC-SHA1, PBKDF2).
2. Crash dump only: allocates a physically contiguous buffer of `MaxPagesPerWrite` × 4096 bytes (`MmAllocateContiguousNodeMemory`, below 4 GB, PAGE_READWRITE) used to double-buffer the writes.
3. Sends [IOCTL 0x4556D0C3](#ioctl-0x4556d0c3) to the volume: `fvevol.sys` fills the 136-byte FVE context (offset 0x10 of the context).
4. If the buffer registered by `fvevol.sys` is too small: [IOCTL 0x4556D0C7](#ioctl-0x4556d0c7), reallocation, [IOCTL 0x4556D0C3](#ioctl-0x4556d0c3) again.
5. `FveInitCrypto` (0x155A8): copies the key datum and builds the AES key schedule.

On error the key material is wiped and the buffer freed. If the IOCTL returns `STATUS_NOT_IMPLEMENTED` (0xC0000002), `DriverEntry` succeeds but the context offset 0x18 is 0: the filter does nothing (volume not protected by BitLocker).

### Context (`DumpData`, 16384 bytes)

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Size of the context (0x4000) |
| 0x04 | 4 | Bytes per sector |
| 0x08 | 4 | Flags of `FILTER_INITIALIZATION_DATA` |
| 0x10-0x97 | 136 | FVE context exchanged with `fvevol.sys` ([IOCTL 0x4556D0C3](#ioctl-0x4556d0c3)) |
| 0x98-0xE4 | 77 | Copy of the key datum in use (to detect a change of key at `DumpStart`) |
| 0xE8 | 4 | Encrypt function (`FveCryptAesEncrypt` or `FveCryptElephantEncrypt`) |
| 0xEC | 4 | Decrypt function |
| 0xF0 | 4 | Pointer to the key schedule (0xFC) |
| 0xF4 | 4 | Size of the key schedule area (0x4000 − 0xFC) |
| 0xF8 | 2 | Encryption method |
| 0xFC-0x3FFF | | AES key schedule(s) |

Encryption methods (`FveInitializeCrypto`, 0x17700; word at offset 8 of the key datum):  
| Value | Method |
|-------|--------|
| 0x8000 | AES-128-CBC + Elephant diffuser (key 16 bytes + sector key 16 bytes) |
| 0x8001 | AES-256-CBC + Elephant diffuser (32 + 32 bytes) |
| 0x8002 | AES-128-CBC |
| 0x8003 | AES-256-CBC |
| other | 0xC00000E4 |

A key datum with a version ≥ 0x15 → 0xC021002A; a version ≠ 1 → `STATUS_INVALID_PARAMETER`.

### Dump callbacks

- `DumpStart` (0x1798C): marks the context and the contiguous buffer with `PoSetHiberRange(PO_MEM_BOOT_PHASE)` (like `MarkHiberBootPhase` in crashdmp.sys), re-initialises the crypto if the key has changed. For the crash dump it clears the 2 callbacks at offsets 0x50/0x54 of the encrypt-on-write structure given by `fvevol.sys` (lock / unlock of the conversion bitmap ?), as they can't be called at crash time. If the volume isn't encrypted the key copy is wiped.
- `DumpWrite` (0x17908) (`FILTER_EXTENSION`, disk byte offset, MDL): if the volume is encrypted, copies the data of the MDL in the contiguous buffer (`DoubleBufferMdl`, which also rewrites the PFN array of the MDL), then `FveEncryptWrite` (0x177A0) encrypts it in place, region by region. If the flag 1 of the context, the flag bit 0 of `FILTER_EXTENSION`+0x48 and the bit 0 of the FVE context offset 0x84 are all set, the data is replaced by zeros instead (?). Always returns 0.
- `DumpRead` (0x1747C): calls `FveEncryptRead` (0x16E58), which — despite its name — **decrypts** the data read (sectors below the encrypted limit). On a decryption error the buffer is zeroed.
- `DumpFinish`: no-op.
- `DumpUnload` (0x16F44): sends [IOCTL 0x4556D0C7](#ioctl-0x4556d0c7), wipes and frees the contiguous buffer and the context (`KeInvalidateRangeAllCaches` after the wipe).

`FveEncryptWrite` translates the offset with `FveGetRedirectedBlockOffset` / `FveGetRedirectedBlockSize` (BitLocker relocates the first sectors of the volume), then classifies each part of the write (`FvepParseBlockAndFilter`, or `FvepParseBlockAndFilterLegacy`) and calls `FveFilteredWrite` (0x174A0):  
| Type | Action |
|------|--------|
| 0 | Not encrypted: plain copy |
| 1 | Volume boot sector: must be a recognised boot sector (NTFS / ReFS / exFAT / FAT) with the same sector fields, then the OEM ID is replaced by `-FVE-FS-` and the fields at 0x38-0x3F by the BitLocker values. Else `STATUS_MEDIA_WRITE_PROTECTED` (0xC00000A2) |
| 2 | BitLocker metadata region: only zeros allowed (→ 0xC021000A), else 0xC00000A2 |
| 3 | Encrypted region: `FveEncryptRegion` with the key of the context |

For the hibernation dump, or when there's no encrypt-on-write information, everything below the encrypted limit (FVE context offset 0x18) is encrypted.

BitLocker volume recognition (`FveCheckVolumeTypeEx`, 0x167D8): OEM ID `-FVE-FS-` at offset 3 of the boot sector, or the information GUIDs below.

---

### IOCTL 0x4556D0C3

This IOCTL is sent by Dumpfve.sys to the volume of the dump file (`GetFveContext`, `FveRegisterDynamicContext`, 0x169F8)

| Property | Value |
|----------|-------|
| Device | 0x4556 ("EV", FVE ?) |
| Function | 0x430 |
| Access | READ_AND_WRITE |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Register the dump filter / get the FVE dynamic context ? | volume (fvevol.sys ?) | 0 | 136 |

Outputbuffer (in/out, `Irp->UserBuffer` = context + 0x10):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-07 | ? | |
| 08-0B | ? | ≠ 0: volume encrypted, the filter is active |
| 0C-0F | ? | Size of the double buffer (set by dumpfve.sys for a crash dump) |
| 10-13 | ? | Address of the double buffer |
| 18-1F | ? | Encrypted limit (bytes, 64-bit): data below is encrypted |
| 20-6C | ? | Key datum (77 bytes): header, encryption method (bytes 28-29), key (2C-4B), sector key for the diffuser (4C-6B) |
| 70-7F | ? | Parameters of the redirection of the first sectors (`FveGetRedirectedBlockOffset`) |
| 80-83 | ? | Pointer to the encrypt-on-write information (conversion bitmap…) |
| 84-87 | ? | Flags. Bit 0: `DumpWrite` writes zeros (?) |

`STATUS_NOT_IMPLEMENTED` (0xC0000002) → volume without BitLocker, the filter is passive.

---

### IOCTL 0x4556D0C7

This IOCTL is sent by Dumpfve.sys to the volume of the dump file (`FveUnregisterDynamicContext`, 0x169D8; called by `GetFveContext` and `DumpUnload`)

| Property | Value |
|----------|-------|
| Device | 0x4556 |
| Function | 0x431 |
| Access | READ_AND_WRITE |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Unregister the dump filter context ? | volume (fvevol.sys ?) | 0 | 136 |

The output buffer is the same FVE context as [IOCTL 0x4556D0C3](#ioctl-0x4556d0c3).

### GUID

BitLocker information offset GUID (`INFORMATION_OFFSET_GUID`, searched in the boot sector)  
`{4967d63b-2e29-4ad8-8399-f6a339e3d001}`

BitLocker encrypt-on-write information offset GUID (`EOW_INFORMATION_OFFSET_GUID`)  
`{92a84d3b-dd80-4d0e-9e4e-b1e3284eaed8}`
