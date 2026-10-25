## Qcbcryptcipherkm8930.sys

Kernel-mode CNG (BCrypt) cipher provider for AES, with hardware offload.  
The kernel CNG router finds this driver and gets a `BCRYPT_CIPHER_FUNCTION_TABLE` from it with [internal IOCTL 0x220007](#internal-ioctl-0x220007). Most functions of the table are thin wrappers around the "Microsoft Primitive Provider" (`BCrypt*` exported by `ksecdd.sys`). Only `Encrypt` and `Decrypt` are replaced: AES-128 in ECB or CBC mode. Small buffers (< 64 bytes) are processed in software (AES tables in `.rdata` from 0x406000). Larger ones are sent with [IOCTL 0x23C40C](#ioctl-0x23c40c) to one of 2 peer devices (2 "hardware threads"): the 2 Qualcomm Crypto Engines, [qcearm8930.sys](./qcearm8930.md) and [qce2arm8930.sys](./qce2arm8930.md).  
PDB path: `P:\qsecuremsm\rel\8.3.1\arm\Release\qcbcryptcipherkm8930.pdb`.

Device name : `\Device\qcBCryptCipher_KM`  
There's no symbolic link.  

There's no parameters in the registry.  

GUID of the ETW provider (WPP):  
`{106f3429-2453-425b-81ba-da8010bc3884}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Interface `{0923c751-56cd-4828-888b-80e586f7ec83}` | [qcearm8930.sys](./qcearm8930.md) | Hardware thread 1: Crypto Engine 1 (`\_SB.QQCE`). [IOCTL 0x23C40C](#ioctl-0x23c40c) |
| Interface `{3453eddf-8fe0-4fd4-be0e-2c525a06e9b2}` | [qce2arm8930.sys](./qce2arm8930.md) | Hardware thread 2: Crypto Engine 2 (`\_SB.QCE2`). [IOCTL 0x23C40C](#ioctl-0x23c40c) |
| — | ksecdd.sys | `BCryptOpenAlgorithmProvider`, `BCryptGenerateSymmetricKey`, `BCryptSetProperty`, `BCryptGetProperty`, `BCryptExportKey`, `BCryptDestroyKey` |

The interface `{0923c751-…}` is created by [qcearm8930.sys](./qcearm8930.md) (Crypto Engine 1, `\_SB.QQCE`, `QCOM1100`), the interface `{3453eddf-…}` by [qce2arm8930.sys](./qce2arm8930.md) (Crypto Engine 2, `\_SB.QCE2`, `QCOM1190`).

### WDF configuration

`DriverEntry` (0x40F008): `WdfDriverCreate` with pool tag `qbc0`, then it **overrides** the WDM dispatch routines of the driver object:
- `IRP_MJ_CREATE` and `IRP_MJ_CLOSE` → `sub_40E520`: completes with `STATUS_SUCCESS`.
- `IRP_MJ_INTERNAL_DEVICE_CONTROL` → `sub_403BBC` (see [internal IOCTL 0x220007](#internal-ioctl-0x220007)). The framework is bypassed: there's no WDF queue.

`EvtDriverDeviceAdd` (`sub_40E3B0`, 0x40E3B0):
- Name `\Device\qcBCryptCipher_KM`, characteristics `FILE_DEVICE_SECURE_OPEN`.
- PnP callbacks: `EvtDevicePrepareHardware` (`sub_403A84`), `EvtDeviceReleaseHardware` (`sub_403B08`), `EvtDeviceSelfManagedIoInit` (`sub_403A78`, no-op), `EvtDeviceSurpriseRemoval` (`sub_403B90`).
- `WdfDeviceSetStaticStopRemove(FALSE)`: the device can't be stopped or removed.
- 2 device interfaces, see [Interface GUIDs](#interface-guids).

`EvtDevicePrepareHardware` (0x403A84):
1. Opens the peer interface `{0923c751-…}` (first instance returned by `IoGetDeviceInterfaces`) as a WDF I/O target, and pre-allocates a request, a 56-byte input memory (tag `qbc5`) and a 16-byte output memory (tag `qbc6`).
2. Same for `{3453eddf-…}` (tags `qbc9`, `qbca`).
3. Allocates the global `KSPIN_LOCK` (tag `qbc7`).
4. **Disables** its own interface `{231a2081-…}` (`WdfDeviceSetDeviceInterfaceState(FALSE)`).

If a peer interface has no instance → `STATUS_INTERNAL_ERROR` (0xC00000E5, `sub_403D84` / `sub_403EB4`) and the device fails to start.  
`EvtDeviceReleaseHardware` closes both I/O targets and frees the spinlock.  
`EvtDeviceSurpriseRemoval` calls `KeBugCheckEx(0x14E, 0x51626330 ("Qbc0"), 0, 0, 0)`.

### Cipher function table

Returned by [internal IOCTL 0x220007](#internal-ioctl-0x220007) (`.data:0x0040C12C`). Layout of `BCRYPT_CIPHER_FUNCTION_TABLE` (`bcrypt_provider.h`):  
| Offset | Value | Field | Comment |
|--------|-------|-------|---------|
| 00 | 1 | Version | `BCRYPT_CIPHER_INTERFACE_VERSION_1` |
| 04 | 0x4025E4 | OpenAlgorithmProvider | `BCryptOpenAlgorithmProvider(phAlg, pszAlgId, L"Microsoft Primitive Provider", dwFlags)` |
| 08 | 0x402700 | GetProperty | See below |
| 0C | 0x402898 | SetProperty | Forwarded to `BCryptSetProperty` |
| 10 | 0x40268C | CloseAlgorithmProvider | Doesn't close anything: only returns `STATUS_UNSUCCESSFUL` (0xC0000001) |
| 14 | 0x4029A8 | GenerateKey | Forwarded to `BCryptGenerateSymmetricKey` |
| 18 | 0x402A64 | Encrypt | See [Encrypt](#encrypt) |
| 1C | 0x402E6C | Decrypt | See [Decrypt](#decrypt) |
| 20 | 0x40362C | ImportKey | Stub: `STATUS_UNSUCCESSFUL` |
| 24 | 0x40366C | ExportKey | Stub: `STATUS_UNSUCCESSFUL` |
| 28 | 0x4036AC | DuplicateKey | Stub: `STATUS_UNSUCCESSFUL` |
| 2C | 0x4036EC | DestroyKey | Forwarded to `BCryptDestroyKey` |

Every function (except the stubs and `DestroyKey`) first checks the global flag `byte_40C12A` ("provider enabled", initially 1). When it is 0, they return 0xC0000466. The flag is cleared, **permanently**, the first time a hardware request ([IOCTL 0x23C40C](#ioctl-0x23c40c)) fails.

`GetProperty` (0x402700):  
| Property | Size | Value | Comment |
|----------|------|-------|---------|
| `HardwareThreads` | 4 | 2 | Answered by the driver. Buffer < 4 → `STATUS_BUFFER_TOO_SMALL` |
| `CngChatConfiguration` | 128 | `.data:0x0040C160`, see below | Answered by the driver. Buffer < 128 → `STATUS_BUFFER_TOO_SMALL` |
| `ObjectLength` | | | Forwarded to `BCryptGetProperty` |
| any other | | | Forwarded to `BCryptGetProperty` (flag `byte_40CB08` = 0xFF) |

Content of `CngChatConfiguration`, 8 entries of 16 bytes (meaning unknown):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | FF FF FF FF 00 00 00 00 01 00 00 00 00 00 00 00 | 0xFFFFFFFF → 1 |
| 10-1F | 00 00 01 00 00 00 00 00 02 00 00 00 00 00 00 00 | 0x00010000 → 2 |
| 20-2F | 01 00 01 00 00 00 00 00 00 80 00 00 00 00 00 00 | 0x00010001 → 0x8000 |
| 30-3F | 02 00 01 00 00 00 00 00 00 40 00 00 00 00 00 00 | 0x00010002 → 0x4000 |
| 40-4F | 03 00 01 00 00 00 00 00 FF FF FF FF 00 00 00 00 | 0x00010003 → 0xFFFFFFFF |
| 50-5F | 00 00 02 00 00 00 00 00 01 00 00 00 00 00 00 00 | 0x00020000 → 1 |
| 60-6F | 01 00 02 00 00 00 00 00 00 04 00 00 00 00 00 00 | 0x00020001 → 0x400 |
| 70-7F | 03 00 02 00 00 00 00 00 1E 05 00 00 00 00 00 00 | 0x00020003 → 0x51E |

### Key extraction

`sub_403754` (0x403754) is called at the start of `Encrypt` and `Decrypt`:
1. `BCryptGetProperty(hKey, "ChainingMode")`: `ChainingModeECB` → mode 0, `ChainingModeCBC` → mode 1, anything else → failure.
2. `BCryptGetProperty(hKey, "KeyLength")`: must be 128 bits.
3. `BCryptExportKey(hKey, NULL, "KeyDataBlob", …)`: the blob must be 28 bytes (12-byte `BCRYPT_KEY_DATA_BLOB_HEADER` + 16). The **raw AES key** is copied out of it.

Any other algorithm, mode or key size → `Encrypt` / `Decrypt` return 0xC0000466 (no fallback to the Microsoft provider).

> [!NOTE]
> For the hardware path, the clear key is copied into the 56-byte buffer of [IOCTL 0x23C40C](#ioctl-0x23c40c) (zeroed after the request).

### Encrypt

`Encrypt` (0x402A64), parameters of `BCryptEncrypt`: `hKey, pbInput, cbInput, pPaddingInfo, pbIV, cbIV, pbOutput, cbOutput, pcbResult, dwFlags`.
- `pbOutput` = NULL: returns the needed size in `*pcbResult`: `cbInput`, or with `BCRYPT_BLOCK_PADDING` (dwFlags = 1) `floor16(cbInput) + 128`.
- Padding: the remaining `cbInput % 16` bytes are copied into a 128-byte stack block whose **last byte only** is set to `128 - (cbInput % 16)`; the other bytes of the block are not initialised. So the padding is not PKCS#7 with 16-byte blocks: the output is always 128 bytes longer than the 16-byte aligned input ?.
- ECB: < 64 bytes → software (`sub_401008` key expansion, `sub_401210` AES block encryption). ≥ 64 bytes → hardware, then the padding block in software.
- CBC: `pbIV` is required (NULL → failure). `cbIV` bytes are copied into a 16-byte stack buffer **without checking `cbIV`**. < 64 bytes → software (`sub_404738`). ≥ 64 bytes → hardware, then the padding block in software chained with the last ciphertext block. The final IV is written back to `pbIV`.
- Success → `STATUS_SUCCESS` and `*pcbResult` = output size. Any failure → 0xC0000466 and `*pcbResult` = 0.

### Decrypt

`Decrypt` (0x402E6C), same parameters.
- `pbOutput` = NULL: `*pcbResult` = `cbInput`.
- < 64 bytes → software (`sub_404850` ECB, `sub_4047AC` CBC). ≥ 64 bytes → the largest multiple of 64 goes to the hardware (direction byte = 1), the rest (`cbInput % 64`) in software.
- With `BCRYPT_BLOCK_PADDING`, the value of the last decrypted byte is subtracted from `*pcbResult` (if smaller). The padding bytes are not checked.
- In `sub_403268`, the IV for the next block is taken from the last 16 bytes of the **output** buffer. That's right for encryption, but for decryption it is plaintext, so a CBC decryption of ≥ 64 bytes with a remainder could chain the wrong IV ?.

### Hardware requests

`sub_403268` (0x403268) builds the 56-byte request (tag `qbc1`) and picks a free hardware thread under the global spinlock: thread 1 if `byte_40C128` = 1, else thread 2 if `byte_40C129` = 1. The flag is cleared while the request runs. When both threads are busy → `STATUS_INVALID_PARAMETER` (there's no wait or software fallback).  
Checks: `cbInput` > `cbOutput` → `STATUS_BUFFER_TOO_SMALL`; `pbInput` = NULL or `cbIV` ≠ 16 (when an IV is given) → `STATUS_INVALID_PARAMETER`.  
Thread 1 is sent by `sub_403FE8`, thread 2 by `sub_404220` (synchronous `WdfRequestSend`).

A debug history of the last 100 requests is kept at `.data:0x0040CBA0` (8 bytes each: `cbInput`, then 0 = encrypt / 1 = decrypt), index at `dword_40CB0C`.

---

### internal IOCTL 0x220007

This internal IOCTL is processed by Qcbcryptcipherkm8930.sys (`sub_403BBC`, WDM dispatch).  
Kernel-mode only: it must be sent as `IRP_MJ_INTERNAL_DEVICE_CONTROL`. It is probably sent by the kernel CNG router (`ksecdd.sys` / `cng.sys` ?) to get the cipher provider interface.

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x1 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the cipher function table | 24 | 4 |

Inputbuffer (`Parameters.DeviceIoControl.Type3InputBuffer`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | ? | ? |
| 10-17 | ? | Algorithm name, compared to `L"AES"` (case-insensitive) as a `UNICODE_STRING` |

Outputbuffer (`Irp->UserBuffer`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the [Cipher function table](#cipher-function-table) |

`InputBufferLength` must be exactly 24 and `OutputBufferLength` exactly 4, else `STATUS_INVALID_PARAMETER` (0xC000000D).

> [!NOTE]
> The test looks inverted: if the name **is** "AES", the request fails with `STATUS_NOT_SUPPORTED` (0xC00000BB). Otherwise the (dead) test `wcscmp(L"AES", L"AES")` always succeeds and the table is returned with `STATUS_SUCCESS`. If offset 0x10 actually holds a `PUNICODE_STRING` (pointer) and not an inline `UNICODE_STRING`, the comparison never matches and the table is always returned ?.

`IoStatus.Information` is always 0.

The other codes of the same family are recognised but refused with `STATUS_NOINTERFACE` (0xC00002B9):  
| IOCTL | Function |
|-------|----------|
| 0x22000B | 0x2 |
| 0x22000F | 0x3 |
| 0x220013 | 0x4 |
| 0x220017 | 0x5 |
| 0x22001B | 0x6 |
| 0x220023 | 0x8 |

(Device 0x22, FILE_ANY_ACCESS, METHOD_NEITHER. Probably the requests for the hash, asymmetric, RNG, … interfaces ?.) Any other IoControlCode → `STATUS_NOT_SUPPORTED`.

---

### IOCTL 0x23C40C

This IOCTL is sent by Qcbcryptcipherkm8930.sys to the devices of the interfaces `{0923c751-56cd-4828-888b-80e586f7ec83}` (`sub_403FE8`, [qcearm8930.sys](./qcearm8930.md#ioctl-0x23c40c)) and `{3453eddf-8fe0-4fd4-be0e-2c525a06e9b2}` (`sub_404220`, [qce2arm8930.sys](./qce2arm8930.md#ioctl-0x23c40c)).

| Property | Value |
|----------|-------|
| Device | 0x23 |
| Function | 0x103 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| AES-128 ECB/CBC operation | Interface `{0923c751-…}` or `{3453eddf-…}` | 56 | 16 |

Inputbuffer (packed):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 05 00 00 00 | Command ? |
| 04-13 | ? | AES-128 key, in clear |
| 14-17 | 00 00 00 00 | Mode: 0 = ECB, 1 = CBC |
| 18-27 | ? | IV (CBC), else 0 ? |
| 28 | 00 | Direction: 0 = encrypt, 1 = decrypt |
| 29-2C | ? | Kernel virtual address of the input data (unaligned DWORD) |
| 2D-30 | ? | Kernel virtual address of the output buffer (unaligned DWORD) |
| 31-33 | ? | Not set (pool content) |
| 34-37 | ? | Length in bytes (multiple of 16, ≥ 64) |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | ? | Copied into a 16-byte pool buffer (tag `qbc2`) that is never read. qce2arm8930.sys never writes it: it holds the first 16 bytes of the input (METHOD_BUFFERED shared buffer) |

The request fails (and disables the provider, see [Cipher function table](#cipher-function-table)) if the status is an error or if the output length isn't 16. The data buffers are passed by address, not copied: the peer driver must access the caller's memory directly.

### Interface GUIDs

Interface Class GUIDs created by `WdfDeviceCreateDeviceInterface`:  
`{231a2081-3cba-4158-827e-faaf3aef3735}` (disabled again in `EvtDevicePrepareHardware`)  
`{1a8f7505-0723-4455-a8e4-5608864e1122}`  

Pool tags: `qbc0` (driver), `qbc1` request, `qbc2` request output, `qbc3` chaining mode string, `qbc4` key blob, `qbc5`/`qbc6` and `qbc9`/`qbca` WDF memories of thread 1 / 2, `qbc7` spinlock.
