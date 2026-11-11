## HalExtQ8660Timers.dll

HAL extension that gives the Windows HAL the timers of the Qualcomm Krait/Scorpion "KPSS" timer block: the GPT (general purpose timer, 32768 Hz sleep clock) and the DGT (debug timer, 27 MHz / 4).  
It reads the CSRT resource group of the timers (`QCOM` 0x1001 on the Lumia 520), reserves and maps the timer registers of CPU 0 (0x0208A000), and registers each timer descriptor with the HAL as a 32-bit up-counter, the GPT also as an interrupt-capable timer (periodic and one-shot ?). On early Krait revisions it reads the counter until two consecutive values agree (hardware erratum workaround). Unlike the BAM and ADM3 extensions, it's a Microsoft binary: file description "HAL Extension for Qualcomm 8660 Timers", version 6.2.9200.16396 (`win8_gdr.120814-1419`), PDB `HalExtQ8660Timers.pdb`.  
It's loaded by [HAL.dll](./hal.md#hal-extensions) when the boot loader lists it as a HAL extension; it's the only analysed extension that handles timer descriptors (type 2), so it's very probably the one used for group 0x1001 (and group 0x1003, which it explicitly accepts and ignores, see [AddResourceGroup](#addresourcegroup-sub_100013cc-0x100013cc)). Siblings in the same folder: [HalExtQ8x60Bam.dll](./halextq8x60bam.md), [HalExtQcAdm3Dma.dll](./halextqcadm3dma.md) (older build of [QCHalExtQcAdm3Dma.dll](./qchalextqcadm3dma.md)).  
The register layout it uses is the one of the Linux `msm_timer` driver for MSM8960 (GPT at +0x04, DGT at +0x24, `DGT_CLK_CTL` at +0x34).

Location on the phone: `C:\Windows\System32\HalExtQ8660Timers.dll` ? (the extracted file has no notes).  

### Imports

None. The image has no import directory and doesn't link a CRT: `memset` is statically linked, `__security_init_cookie` (`sub_10002000`, in the `INIT` section) and `_GSHandlerCheck` / `__security_push_cookie` / `__security_pop_cookie` / `__security_check_cookie` (`sub_10001504`, `sub_1000157C`) / `_gsfailure` are the `/GS` boilerplate.  
Everything else goes through the [HAL services table](./hal.md#hal-extension-services) received at the entry point. No trace (no ETW, no debug print); the only strings are the PDB and DLL names and the version resource.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| HAL ([HAL.dll](./hal.md)) | Entry point `start`, [HAL services table](./hal.md#hal-extension-services) | The HAL loads the extension, calls `AddResourceGroup` for its CSRT groups, then calls the timer functions |

No DLL is loaded at run time, no file or registry key is used.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| — | `start` (entry point) | 0x100014BC | `ULONG Reserved`, `PVOID *ExportTable` (out), `PVOID HalServices` (in) |

The export directory names the DLL but has no function. Same entry point contract as the [BAM extension](./qchalextq8x60bam.md): `Reserved` ≠ 0 → 0xC00002B9; `__security_init_cookie`; HAL services table kept in `off_10003124`; `*ExportTable` = `off_10003118` (a single pointer to [AddResourceGroup](#addresourcegroup-sub_100013cc-0x100013cc), `sub_100013CC`, followed by 0); `dword_10003128` = 0; `STATUS_SUCCESS`.

Global data:

| Address | Size | Comment |
|---------|------|---------|
| 0x10003100 | 4 | `/GS` cookie (default 0xBB40E64E, complement in 0x10003104) |
| 0x10003108 | 12 | Erratum flag per timer kind: [0] = 0, [1] = 1 (GPT), [2] = 1 (DGT) |
| 0x10003118 | 8 | Export table: `sub_100013CC`, 0 |
| 0x10003120 | 4 | Virtual address of the timer registers (mapped on the first Initialize) |
| 0x10003124 | 4 | HAL services table |
| 0x10003128 | 4 | Set to 0 by `start`, not used otherwise |
| 0x1000312C | 4 | Size of the timer register block (shared info +0x08: 0x1000) |
| 0x10003130 | 8 | Physical address of the timer register block (shared info +0x10: 0x0208A000) |

### AddResourceGroup (sub_100013CC, 0x100013CC)

`(Handle, ResourceGroup)`, `/GS`, no decompilation.
1. If the group `DeviceId` (group +0x0C) isn't 0x1003: reads the shared info of the group (it starts at group +0x18): physical address at shared info +0x10 (64-bit) → 0x10003130, size at +0x08 → 0x1000312C, and calls `HalRegisterPermanentAddressUsage` (services +0x14) with them. A failure is returned. The other shared-info fields (0x0200A000 at +0x00, 2 at +0x0C, 0x0209A000 at +0x18 on the Lumia 520) aren't used.
2. Walks the timer descriptors with `GetNextResourceDescriptor` (services +0x04): `Type` 2, `Subtype` 0, `Uid` 0xFFFF (any).
3. For each descriptor, nothing is done when the group is 0x1003. Otherwise, by the [timer kind](#timer-descriptor) at descriptor +0x0C:
   - 2 (DGT): one registration, capabilities 0x2 (counter only).
   - 1 (GPT), unless the descriptor `Uid` is 3: first a counter-only registration (capabilities 0x8002) with a copy of the descriptor header built on the stack whose `Uid` is ORed with 0x80000000 (so the HAL, which returns the previous status for a resource already registered with the same `Uid`, accepts a second registration of the same hardware), then the real descriptor with capabilities 0x8230 (interrupt-capable timer).
   - other kinds (3 on the Lumia 520: UIDs 4 and 5): ignored.
4. Returns `STATUS_SUCCESS`, or the first failure of a registration.

On the Lumia 520 ([CSRT](./hal.md#lumia-520-tables)) this gives three HAL timers: the DGT (UID 1, 6.75 MHz, counter only), the GPT counter (UID 0x80000002, 32768 Hz) and the GPT timer (UID 2, 32768 Hz, GSIV 18).

### RegisterTimer (sub_100012CC, 0x100012CC)

`(Handle, ResourceGroup, Descriptor, TimerDescriptor, Capabilities)`, `/GS`, no decompilation. `Descriptor` is the descriptor given to the HAL (the real one or the copy with the modified `Uid`), `TimerDescriptor` is always the real one.
1. Builds the 0x1C-byte [internal data](#internal-data): kind (descriptor +0x0C), register index (+0x10), the rest 0.
2. Builds a 0x68-byte [timer initialization block](#timer-initialization-block). The interrupt functions (+0x10, +0x14, +0x18) are only set when `Capabilities` has bit 0x200.
3. Reads `MIDR`: for a Qualcomm core (implementer 0x51) with bits 10–15 = 1 (part 0x04x–0x07x, Krait) and variant 0, or variant 1 with revision 0 or 2, ORs the erratum flag of the kind (0x10003108) into the internal data +0x04: the counter is then read [twice](#querycounter-sub_100011c8-0x100011c8). The MSM8930 Krait 200 revision isn't known here, so whether the workaround is active on the Lumia 520 is "?".
4. Calls `RegisterResourceDescriptor` (services +0x00) with the block and returns its status.

### Timer initialization block

Built by `RegisterTimer`, checked by `HalpTimerRegister` (see the [HAL side](./hal.md#timer-initialization-block)).

| Offset | Size | Value/Comment |
|--------|------|---------------|
| 0x00 | 4 | 1 (version) |
| 0x04 | 4 | 0x68 (size) |
| 0x08 | 4 | [Initialize](#initialize-sub_10001110-0x10001110) (`sub_10001110`) |
| 0x0C | 4 | [QueryCounter](#querycounter-sub_100011c8-0x100011c8) (`sub_100011C8`) |
| 0x10 | 4 | [AcknowledgeInterrupt](#acknowledgeinterrupt-sub_1000121c-0x1000121c) ? (`sub_1000121C`), only with capability 0x200 |
| 0x14 | 4 | [ArmTimer](#armtimer-sub_1000125c-0x1000125c) (`sub_1000125C`), only with capability 0x200 |
| 0x18 | 4 | [Stop](#stop-sub_100012a0-0x100012a0) (`sub_100012A0`), only with capability 0x200 |
| 0x1C…0x2C | 20 | 0 (other functions of the table not implemented) |
| 0x30 | 4 | Pointer to the [internal data](#internal-data) (the HAL copies it) |
| 0x34 | 4 | 0x1C (size of the internal data) |
| 0x38 | 4 | 0x20: counter width 32 bits |
| 0x40 | 8 | Frequency: descriptor +0x14 (high dword 0) |
| 0x48 | 4 | 1 |
| 0x4C | 4 | Capabilities: 0x2, 0x8002 or 0x8230 (0x200 = has an interrupt and the arm/stop functions; 0x10 and 0x20 = periodic and one-shot ?; 0x2 = readable counter ?; 0x8000 = ?) |
| 0x54 | 4 | GSIV: descriptor +0x18 |
| 0x58 | 4 | 1 (interrupt mode / polarity ?) |
| 0x5C | 4 | 1 (interrupt mode / polarity ?) |
| 0x60 | 4 | 0x1000 (known type, see [HAL.dll](./hal.md#timer-initialization-block)) |
| 0x64 | 4 | `Uid` of the registered descriptor (+0x08) |

Other fields 0.

### Timer descriptor

CSRT descriptor of `Type` 2, `Subtype` 0 (12-byte header: `Length`, `Type`, `Subtype`, `Uid`), as parsed by this extension:

| Offset | Size | Comment |
|--------|------|---------|
| 0x0C | 4 | Kind: 1 = GPT, 2 = DGT, other = ignored |
| 0x10 | 4 | Index, in dwords, of the timer's `MATCH_VAL` register in the register block (1 → +0x04, 9 → +0x24) |
| 0x14 | 4 | Counter frequency in Hz |
| 0x18 | 4 | GSIV of the timer interrupt |

Lumia 520 (group 0x1001): UID 1 = DGT (index 9, 6750000 Hz, GSIV 17), UID 2 = GPT (index 1, 32768 Hz, GSIV 18), UIDs 4 and 5 = kind 3 (index 0x0E and 0x18, frequency 0, GSIV 20 and 21), not used by this extension.

### Internal data

0x1C bytes, built by `RegisterTimer`; the HAL passes its own copy to each timer function.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Kind (1 = GPT, 2 = DGT) |
| 0x04 | 4 | Bit 0: read the counter until stable (Krait erratum) |
| 0x08 | 4 | Register index *n* of `MATCH_VAL` |
| 0x0C | 4 | Mode given to ArmTimer (1 = periodic ?, 3 = one-shot ?) |
| 0x10 | 4 | Interval in ticks |
| 0x14 | 4 | Last programmed match value |
| 0x18 | 1 | Armed |

### Timer registers

Register block mapped from 0x0208A000 (0x1000 bytes, `MmNonCached`), the per-CPU timer block of CPU 0 that the HAL also uses for the [WDAT](./hal.md#lumia-520-tables) watchdog (+0x38…). Every write is preceded by a `DSB`. With *n* the register index of the descriptor:

| Register | Offset | GPT | DGT | Use |
|----------|--------|-----|-----|-----|
| `MATCH_VAL` | 4 × *n* | 0x04 | 0x24 | Compare value |
| `COUNT_VAL` | 4 × (*n* + 1) | 0x08 | 0x28 | Counter |
| `ENABLE` | 4 × (*n* + 2) | 0x0C | 0x2C | 1 = enabled (bit 1, clear on match, never set) |
| `CLEAR` | 4 × (*n* + 3) | 0x10 | 0x30 | Written 0 for the DGT |
| `DGT_CLK_CTL` | 4 × (*n* + 4) | — | 0x34 | 3 = divide by 4 (27 MHz → 6.75 MHz) |

### Initialize (sub_10001110, 0x10001110)

1. On the first call, maps the register block with `HalMapIoSpace` (services +0x0C); NULL → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A).
2. DGT: `ENABLE` = 0, `DGT_CLK_CTL` = 3, `CLEAR` = 0, `MATCH_VAL` = 0xFFFFFFFF.
3. GPT: `MATCH_VAL` = counter − 1 (as far as possible in the future), armed = 0.
4. `ENABLE` = 1. Returns `STATUS_SUCCESS`.

### QueryCounter (sub_100011C8, 0x100011C8)

Returns `COUNT_VAL` as a 64-bit value (high part 0). With the erratum flag, reads it twice in a loop until the second read minus the first is ≤ 1.

### ArmTimer (sub_1000125C, 0x1000125C)

`(InternalData, Mode, ULONGLONG Ticks)`: `Mode` must be 1 or 3 and `Ticks` ≤ 0x7FFFFFFF, else `STATUS_INVALID_PARAMETER`. Sets armed = 1, mode and interval, then programs the match from the current counter (`sub_100010C0`): match = base + interval; it reads the counter back and accepts the match only if it's still between 3 and *interval* ticks ahead, otherwise it retries from the new counter value with a delay of 4, 8, 16… ticks (up to 2³¹). The match value is kept in +0x14.

### AcknowledgeInterrupt (sub_1000121C, 0x1000121C)

Function +0x10 of the block, so probably called by the HAL on each timer interrupt. Mode 1: programs the next match from the previous match value (periodic, no drift). Mode 3: `MATCH_VAL` = counter − 1 and armed = 0 (one-shot). Other modes: nothing.

### Stop (sub_100012A0, 0x100012A0)

`MATCH_VAL` = counter − 1, armed = 0. The timer stays enabled (the counter keeps running).
