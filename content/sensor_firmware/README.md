# Rear camera sensor firmware

The rear camera sensor (SMIA model `0x07A3`, revision 2, I2C address 0x20, see [qccamsensor8930.sys](../drivers/qccamsensor8930.md)) contains an 8051-compatible microcontroller. Its program is a mask ROM, plus a RAM patch that [qccamsensor8930.sys](../drivers/qccamsensor8930.md#cdcc-data-dcc-files) uploads from `0107A302.dcc` at every sensor power on (694 bytes of code at `0xF800–0xFAB5`).

The ROM was read with [wp81RawCamDump](https://github.com/fredericGette/wp81RawCamDump) (`tools/sensor_rom_dump`): a replacement for the patch routine `0xF90F` (run by the ROM at each stream start) copies 8 bytes of code memory (`MOVC A,@A+DPTR`) to the scratch registers `0x35F7–0x35FE`, which the phone reads back over I2C. The sensor is power cycled for each 8-byte chunk, so the 16 KB took about one hour.

Dump: `rom_0000_3FFF.bin`, 16384 bytes, md5 `9fbba61337189c444d267004daccbf6c` (see [Reliability of the dump](#reliability-of-the-dump)).  
Disassembly: IDA, raw binary, processor 8051. The function names (`sub_xxxx`) and addresses below are ROM addresses.

### Reliability of the dump

The first version of the dump (md5 `bf9e19d7a1dd03b07dd10622208820b6`) had **23 chunks of 8 bytes containing `55 1D 4C 16 C7 1A A0 18`**. That is the stock value of `0x35F7–0x35FE` written by the `.dcc` (seen in the ETW traces of the Camera app: `reg=0x35F5 data=22 19 55 1D 4C 16 C7 1A`, `reg=0x35FD data=A0 18…`). For these chunks the dumper didn't run, and the tool took the stale scratch content as ROM. 13 of them were in the code (`0x0150`, `0x01C0`, `0x03E8`, `0x09E8`, `0x0B78`, `0x0BB8`, `0x0E98`, `0x1850`, `0x1CB8`, `0x1CD8`, `0x1F80`, `0x2060`, `0x22A0`), 10 in the filler.

The tool now rejects stale read-backs, and its pass 2 read these chunks again on the phone (2026-11-25), with 5 other suspicious chunks and a chunk found afterwards:

| Chunk | First dump | Read again | |
|-------|------------|------------|-|
| 23 stale chunks | `55 1D 4C 16 C7 1A A0 18` | Code, or the filler pattern | Fixed |
| `0x24C0` | `FB` × 8 | `FB` × 8 | Confirmed (two reads agree) |
| `0x3200` | `33 04 49 9F 3C FF 00 33` | Filler pattern | Fixed |
| `0x35E0` | `11` × 8 | Filler pattern | Fixed |
| `0x3A20` | `00 01 02 03 04 05 06 07` | Filler pattern | Fixed |
| `0x3AF8` | `03` × 8 | Filler pattern | Fixed |
| `0x28F8` | `20` × 8 | Filler pattern (`00 20 00 20 00 20 20 00`) | Fixed |

Current dump: md5 `9fbba61337189c444d267004daccbf6c`. The filler `0x2800–0x3FFF` is now the same 32-byte pattern everywhere.

`0x28F8` was a wrong read that wasn't the stale pattern, so pass 1 can also return wrong bytes that the stale check doesn't detect. The rest of the code has been read only once: a full second read compared with this one would be needed to trust every byte.

## Memory map

The 8051 has separate code and data spaces, but the code RAM of the patch is written with I2C data writes and then executed, so the two spaces share at least `0xF800–0xFBFF`.

### Code space (`MOVC`, instruction fetch)

| Address | Size | Content |
|---------|------|---------|
| `0x0000–0x0065` | 102 | Reset and interrupt vectors, see [Vectors](#vectors) |
| `0x0066–0x27FE` | ~10 KB | Code (162 functions found by IDA, ~3550 instructions) and constant tables |
| `0x2800–0x3FFF` | 6 KB | No code: a 32-byte pattern repeated (`20 20 20 20 00 20…`, `00` at offsets 4, 0x12, 0x18, 0x1A, 0x1C, 0x1F). Not referenced by the code. Unprogrammed area, or a read of an unmapped area ? |
| `0x4000–0xFFFF` | | The 16 KB are mirrored 4 times according to the dump tool (A14/A15 not decoded). Not for `0xF800…`, where the patch code is executed |
| `0xF800–0xFAB5` | 694 | Patch code from the `.dcc` (RAM), see [Patch](#patch-from-the-dcc-file) |

The code space is read only over I2C: reading `0xF800…` or a ROM address with an I2C read returns zeros.

### Data space (`MOVX @DPTR`)

The data space *is* the sensor register map seen over I2C: the code reads and writes the SMIA registers and the manufacturer registers directly.

| Address | Content | Examples in the ROM |
|---------|---------|---------------------|
| `0x0000–0x0FFF` | SMIA registers | `0x0104` (grouped parameter hold), `0x0107`, `0x0110`, `0x0900–0x0901`, `0x0A02`, `0x0B04–0x0B05`, `0x0C12`, `0x0C1A–0x0C1B`, `0x0D18`, `0x0D83`, `0x0D88` |
| `0x3000–0x3FFF` | Manufacturer registers | `0x300E`, `0x3025`, `0x3047`, `0x3088–0x3089`, `0x30A0`, `0x30A4`, `0x30F0–0x30FB`, `0x31A2`, `0x3200`, `0x3239`, `0x3240`, `0x324C`, `0x3250`, `0x3368`, `0x3442`, `0x3445`, `0x344C`, `0x3502`, `0x3530`, `0x3538`, `0x3581–0x3589`, `0x359D`, `0x35A4–0x35A5`, `0x35B4–0x35B5`, `0x35BE–0x35C7`, `0x3618–0x362B`, `0x3630`, `0x3640`, `0x3650`, `0x3E44` |
| `0x4340–0x434F` | ? | `0x434A–0x434B` (used to compute `0x30F8–0x30F9`), `0x4347` |
| `0x6000–0x60FF` | ? | `0x6002–0x6004`, `0x6011`, `0x60A0–0x60A1`. The `.dcc` writes `0x6006–0x6008` = `02 02 02` (they read back `00`) |
| `0xF800–0xFBFF` | Patch RAM (code + variables) | `0xFADF–0xFAFF`, `0xFB00`, `0xFB21–0xFB86`, `0xFBD7–0xFBFE` |
| `0xFC00–0xFFFF` | RAM ? | Tested by the self-test `sub_19C3`. `0xFF86–0xFF92`: read at init (`sub_244F`) and copied to `0x3620–0x3630` |

### Internal RAM and SFRs

- The reset code clears the internal RAM `0x01–0x7F` and sets the stack at `0x5F` (`SP = 0x5E`). The C compiler (Keil style: `R7`/`R6:R7` for parameters and return values) uses `0x10–0x5E` for global variables.
- Main loop event flags: `RAM_46` (one bit per interrupt, see [Main loop](#main-loop)), and `RAM_47–RAM_49` for the events of other modules.
- Standard SFRs: `SP`, `DPL/DPH`, `PSW`, `ACC`, `B`, `PCON`, `IE` (`0xA8`).
- Non-standard SFRs: `0xA2` (saved with `DPL/DPH` by the interrupt handlers and cleared at their start: data pointer select, like `AUXR1` of the Philips/Atmel parts ?), `0xB8`, `0xB9` (enable and priority of the extended interrupts ?: `0xB8 = 0x20`, `0xB9 = 0x20` at init), `0xE8 = 0x3F`, `0xF8 = 0x0F`, `0xF9 = 0x0F`.
- `PCON = 1` (idle) in the main loop when there is nothing to do: the CPU sleeps until the next interrupt.

## Vectors

13 interrupt vectors, 8 bytes apart (the 8051 has 5, the 8052 has 6: the sensor adds 7 more). Each vector is a `LJMP`.

| Vector | Handler | Registers used by the handler | Main loop flag |
|--------|---------|-------------------------------|----------------|
| `0x0000` reset | `0x0AB7` | Clears the internal RAM, `SP = 0x5E`, `LJMP 0x0E51` | |
| `0x0003` (INT0) | `0x075C` | `0x3584`, `0x3581` | bit 0 → `sub_165B` |
| `0x000B` (Timer 0) | `0x08D7` | `0x30FA`, `0x30FB` | bit 1 → `sub_1E3F` |
| `0x0013` (INT1) | `0x09C8` | `0x3025` | bit 2 → `sub_1871` |
| `0x001B` (Timer 1) | `0x09E5` | `0x35A5` | bit 4 → `sub_0F8E` |
| `0x0023` (serial port) | `0x0969` | `0x3239` | bit 3 → `sub_050D` |
| `0x002B` (Timer 2) | `0x0646` | `0x35BE`, `0x35C0`, `0x35C4`, `0x3650`, `0xFAF0` | — |
| `0x0033` | `0x071B` | `0x35BE`, `0x35C3`, `0x35C6`, `0xFAF0` | — |
| `0x003B` | `0x07FC` | `0x35C5` | — |
| `0x0043` | `0x05F3` | `0x35BE`, `0x35C3`, `0x35C7`, `0x0A02` | — |
| `0x004B` | `0x09A9` | `0x35BF`, `0x0D18` | — |
| `0x0053` | `0x0A02` | `0x35B5` | bit 5 → `sub_1F5F` (hooked by the patch, see below) |
| `0x005B` | `0x08FD` | `0x3586`, `0x3589` | bit 6 → `sub_14A5` |
| `0x0063` | `0x0A1F` | `0x344C` | — |

The names of the first 6 vectors are the standard 8051/8052 ones: the sensor certainly uses them for its own sources (frame events, I2C slave…), not for timers or a UART. The vectors `0x0003`, `0x000B`, `0x0013` and `0x001B` are followed by a second `LJMP` (`0x14DC`, `0x181E`, `0x1832`, `0x25EB`) that the vector itself never reaches.

Each handler only acknowledges its source (register access) and sets a flag; the work is done in the main loop.

## Initialisation

`0x0E51` → `sub_0EB5`:
1. Interrupts off, `0x3530` bits 1 and 2 set, `0x3368 = 0`, `0x3588` bits 0 and 2 cleared, `0x3502 = FF`, `0x3240 = 04`, `0x324C = 10`, `0x3250 = 01`, `0x3627 = 11`.
2. `0x3E44 = 01`, then patch RAM variables initialised: `0xFB21–0xFB30` and `0xFB35–0xFB7A` cleared, `0xFADF–0xFAE1 = 03 01 01`, `0xFAF0 = 0`, `0xFAFF–0xFB00 = 03 78`, `0xFB31 = FF`, `0xFB32–0xFB34 = 0`, `0xFB7B–0xFB7E = 01 01 12 34`, `0xFB7F–0xFB81 = 0`, `0xFB83–0xFB86 = 0`.
3. `sub_244F`: copies `0xFF86–0xFF92` to `0x3620–0x3630` (packed fields split in nibbles / bit fields), then `CJNE A,#0xF0` on `0xFF92`, followed by 8 bytes `FB` (confirmed by a second read; the `CJNE` offset `FB` points into the middle of an instruction: not understood). Identification / trimming data ?
4. `0x3E44 = 00`, `sub_015D` (loop on a table of `0x30A4` entries of 4 bytes at `0xF0C0`), `0x0107 = 0x20` or `0x36` (depends on `RAM_44`), `0x3445 = 01`.
5. Extended interrupt SFRs, `IE = 0xBF`, `0x31A2 = 0`, `0x3368 = 1`.

The `.dcc` overwrites some of these values just after the power on: `0xFADF = 00` (`03` by the ROM), `0xFB00 = 0x51` (`0x78` by the ROM), `0x3E44 = 01`. `0xFB00` isn't a patch control: it's a number used by the computation in `sub_175F` (with the SMIA register `0x0C12`).

## Main loop

`0x0E53`: a loop on the flags of `RAM_46`. For each bit set: clear it and call its handler (table in [Vectors](#vectors)). When `RAM_46` is 0, `PCON = 1` (idle) until the next interrupt.

The handlers use the same scheme with their own flag byte, e.g. `sub_165B` dispatches on `RAM_48`.

## Self-test

`sub_19C3` is a memory test: it reads a pattern from `0x361D–0x361E`, checks the RAM `0xFC00–0xFFFF` (`0x3FF` or `0x3F7` bytes depending on bit 7 of `0x361E`), stores the failing addresses at `0xF802…`, counts the wrong bits with a table of bit counts per nibble at `0x0E41` (`00 01 01 02 01 02 02 03…`), writes the result to `0xF800–0xF801` and sets bit 2 of `0x361F`. A second routine around `0x1BEB` does the same with its result in `RAM_28:29` and bit 0 of `0x361F`. Production test, started by a host write to `0x361D…` ?

## Patch (from the .dcc file)

The `.dcc` patch has about 15 routines (see [qccamsensor8930.sys](../drivers/qccamsensor8930.md#cdcc-data-dcc-files) for the upload). Most of them end with a `LJMP` back into the ROM: they replace a few instructions of a ROM function, then continue in the ROM.

### Hook points

At 8 places the ROM dump reads `02` (`LJMP`) where the surrounding code needs another instruction. The two following bytes are the operands of the original instruction, and a patch routine replays (or drops) that instruction and returns just after it:

| ROM address | Bytes read | Original instruction (from the context and the patch) | Patch routine | Returns to |
|-------------|------------|-------------------------------------------------------|---------------|-----------|
| `0x03D4` | `02 10 60` | `MOV A,RAM_10` / `JZ` … `LCALL 0x16A0` | `0xFA08` (`0x30F8–F9 = 0`, bit 3 of `0x30F1` and `0x30F0` set) | `0x03DE` |
| `0x0A0D` | `02 46 20` | `ORL RAM_46,#0x20` (flag for `sub_1F5F`) in the vector `0x0053` handler | `0xFA76` (`0x35B5` low bits = 01, calls `sub_1F5F` directly) | `0x0A16` |
| `0x11BF` | `02 58` | 2-byte instruction, dropped | `0xFA44` (only `LJMP 0x11C1`) | `0x11C1` |
| `0x188A` | `02 43 4B` | `MOV DPTR,#0x434B` (start of the computation of `0x30F8` from `0x434A–0x434B`) | `0xFA48` | `0x18AC` |
| `0x1907` | `02 22 FB 7F` | `MOVX @DPTR,A` / `MOV DPTR,#0xFB7F` | `0xF9DF` (writes `04` to `0xF62C/34/3C` or `0xF5C0/C8/D0`, then the 2 instructions) | `0x190B` |
| `0x18D6` | `02 FB 84` | `MOV DPTR,#0xFB84` | `0xFAAB` (the same instruction) | `0x18D9` |
| `0x1E8D` | `02 10` | `MOV A,RAM_10` | `0xFA8A` | `0x1E8F` |
| `0x1FAD` | `02 FB 85 F0` | `MOV DPTR,#0xFB85` / `MOVX @DPTR,A` | `0xFAB2` (only `LJMP 0x1FB1`: the write `0xFB85 = 0` is dropped) | `0x1FB1` |

The `LJMP` read in the dump can't be the real jump: its target is the original operands (`0x1060`, `0x4620`, `0x22FB`… are in the middle of instructions, `0xFB84/0xFB85` are variables). So the sensor has a ROM patch mechanism that replaces the opcode at the hooked addresses (seen by `MOVC` as `02`) and redirects the execution to the patch routine (not seen by `MOVC`). How it is configured isn't known: the `.dcc` only writes the patch code, `0xFB00`, the table `0xFBD7–0xFBFE`, and `0x6006–0x6008 = 02 02 02` (write-only; `02` is the `LJMP` opcode). At `0x1907`, the second byte reads `22` instead of the expected `90`: not explained.

The patch routines `0xF90F` (stream start, returns to `0x1D4F`), `0xF972` (returns to `0x16E1`), `0xF9B4` (power on, returns to `0x167E`) and `0xFA9D` (returns to `0x1747`) have no visible hook point before their return address: the dump reads the original instruction there (e.g. `0x1D4C` = `90 30 88`, the `MOV DPTR,#0x3088` that `0xF90F` replays). They are reached in another way (the 3 entries of `0x6006–0x6008` ?).

### 0xA5 opcode

The patch contains 3 times `90 FB 85 74 00 A5` (`MOV DPTR,#0xFB85` / `MOV A,#0` / `A5`). `0xA5` isn't an 8051 instruction, and the ROM never uses it as an opcode. Given the context (the ROM writes `0xFB85 = 0` with `MOVX @DPTR,A`), it's a vendor instruction that writes A to `@DPTR` ? (On the Infineon XC800 and Mentor M8051EW cores, `0xA5` is the debugger `TRAP` / a prefix of extended instructions.)

### ROM routines called by the patch

| Address | Use |
|---------|-----|
| `sub_0947` | Copy ? (called with `R4:R5 = 0xFBC7`, `R6:R7 = 0x3072`, `R3 = 0x10`) |
| `sub_12A4` | Called at power on by `0xF9B4` after `0x3E44 = 00` |
| `sub_16A0` | Called by `0xFA48` |
| `sub_17D8`, `sub_1B9B`, `sub_2122`, `sub_224F`, `sub_225E`, `sub_2293` | 16/32-bit arithmetic (multiply, divide, compare) of the C runtime ? |
| `sub_1F5F` | Handler of the flag bit 5 of `RAM_46` (vector `0x0053`) |

## Not known

- The vendor of the sensor and of the microcontroller core.
- The real sources of the 13 interrupts, and the I2C slave interface (how a host write reaches the firmware: the handlers `0x002B`, `0x0033`, `0x0043` that use `0x35BE–0x35C7` and `0xFAF0` are candidates).
- How the hook points are configured (see [Hook points](#hook-points)).
- Whether every byte of the code is right: it was read only once (see [Reliability of the dump](#reliability-of-the-dump)).
