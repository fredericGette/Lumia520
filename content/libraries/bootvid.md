## BOOTVID.DLL

Microsoft VGA boot video driver (PDB `bootvid.pdb`, 35 functions): text and bitmaps on the boot / crash screen before the display driver is loaded.  
It's the generic PC version: it programs a standard VGA adapter through its I/O ports (sequencer, graphics controller, attribute controller, DAC at 0x3C0…0x3DA) and writes the planar video memory at physical 0xA0000, in mode 12h (640 × 480, 16 colours). It contains an 8 × 13 font (256 characters), a 4 bpp / 1 bpp blitter, an RLE4 bitmap decoder and a text console with a scroll region. Nothing in it is ARM- or Qualcomm-specific.  
It's loaded by the boot loader with [NTOSKRNL.EXE](./ntoskrnl.md), whose `Bvga*` / `Inbv*` functions are its only callers. On this phone it can't work: the ARM [HAL.dll](./hal.md) bug-checks on every port access and doesn't fill the `HalPrivateDispatchTable` entries it uses (see [On the Lumia 520](#on-the-lumia-520)). The phone's boot screen comes from the kernel's `Bgk` graphics (firmware frame buffer) instead.

Location on the phone: `C:\Windows\System32\bootvid.dll` ? (the extracted file `BOOTVID.DLL` has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntoskrnl.exe | `MmMapIoSpace`, `MmUnmapIoSpace`, `HalPrivateDispatchTable` (data) |
| HAL.dll | `READ_PORT_UCHAR`, `READ_PORT_USHORT`, `WRITE_PORT_UCHAR`, `WRITE_PORT_USHORT`, `WRITE_PORT_BUFFER_USHORT` |

`memset` and `__security_init_cookie` / `__security_push_cookie` / `__security_pop_cookie` / `__security_check_cookie` / `__GSHandlerCheck` / `__report_gsfailure` are the statically linked CRT and `/GS` boilerplate.

`HalPrivateDispatchTable` entries called:

| Offset | Function | Use |
|--------|----------|-----|
| +0x28 | `HalFindBusAddressTranslation(BusAddress, &AddressSpace, &TranslatedAddress, &Context, NextBus)` | Find the bus of the VGA ports (bus address 0) and of the frame buffer (0xA0000), in `VidInitialize` |
| +0x2C | `HalResetDisplay()` | Ask the HAL / BIOS to reset the adapter, in `VidInitialize` and `VidResetDisplay` |
| +0xB4 | ? (display present query ?) | First check of `VgaIsPresent`; 0 → no VGA |

### Exports

The names are the public ones. The parameters come from the code (the kernel callers use the same order).

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `VidBitBlt` | 0x80012548 | `PUCHAR Buffer` (BMP without file header, see [VidBitBlt](#vidbitblt-0x80012548)), `ULONG Left`, `ULONG Top` |
| 2 | `VidBitBltEx` | 0x800123F4 | `ULONG Left`, `ULONG Top`, `ULONG Width`, `ULONG Height`, `PUCHAR Buffer`: packed 4 bpp, delta = (Width + 1) / 2 |
| 3 | `VidBufferToScreenBlt` | 0x80012418 | `PUCHAR Buffer`, `ULONG Left`, `ULONG Top`, `ULONG Width`, `ULONG Height`, `ULONG Delta`: packed 4 bpp; nothing if Width or Height is 0 |
| 4 | `VidCleanUp` | 0x80011858 | none: graphics controller bit mask (index 8) = 0xFF |
| 5 | `VidDisplayString` | 0x80012444 | `PUCHAR String` (ANSI, NUL-terminated), see [Text console](#text-console) |
| 6 | `VidDisplayStringXY` | 0x800125D8 | `PUCHAR String`, `ULONG Left`, `ULONG Top`, `BOOLEAN Transparent`: colour 12 on colour 14, or transparent background; doesn't move the cursor. Not imported by the kernel |
| 7 | `VidInitialize` | 0x80011634 | `ULONG Mode` (0xFFFFFFFF, 0 = phase 0, 1 = phase 1), `BOOLEAN SetMode`; returns TRUE if a VGA was found, see [VidInitialize](#vidinitialize-0x80011634) |
| 8 | `VidResetDisplay` | 0x800115D8 | `BOOLEAN HalReset` |
| 9 | `VidScreenToBufferBlt` | 0x80011A34 | `PUCHAR Buffer`, `ULONG Left`, `ULONG Top`, `ULONG Width`, `ULONG Height`, `ULONG Delta`: reads the 4 planes back into packed 4 bpp (buffer cleared with `memset` first) |
| 10 | `VidSetScrollRegion` | 0x8001182C | `ULONG Left`, `ULONG Top`, `ULONG Right`, `ULONG Bottom`; also moves the cursor to (Left, Top) |
| 11 | `VidSetTextColor` | 0x80011814 | `ULONG Color` (0–15); returns the previous colour |
| 12 | `VidSolidColorFill` | 0x80011BD0 | `ULONG Left`, `ULONG Top`, `ULONG Right`, `ULONG Bottom` (inclusive), `UCHAR Color` |

Kernel callers ([NTOSKRNL.EXE](./ntoskrnl.md), through import thunks `Vid*_0`): `VidInitialize` ← `BvgaDriverInitialize`; `VidResetDisplay` ← `BvgaResetDisplay`, `BgkpResetDisplay`; `VidCleanUp` ← `BvgaEnableBootDriver`, `BvgaNotifyDisplayOwnershipLost`; `VidDisplayString` ← `BvgaDisplayString`; `VidSetTextColor` ← `BvgaSetTextColor`; `VidSetScrollRegion` ← `BvgaSetScrollRegion`; `VidSolidColorFill` ← `BvgaSolidColorFill`, `BvgaUpdateProgressBar`, `FinalizeBootLogo`, `RotBarInit`, `RotBarUpdate`; `VidBitBlt` ← `BvgaBitBlt`, `RotBarUpdate`; `VidBitBltEx` ← `BgkpVgaBltRoutine`; `VidBufferToScreenBlt` ← `RotBarUpdate`; `VidScreenToBufferBlt` ← `RotBarInit`.

### Global state

| Address | Size | Comment |
|---------|------|---------|
| 0x80013E80 | 4 | `VgaBase`: virtual address of the frame buffer (0xA0000 mapped, or 0xA0000 itself in mode 0xFFFFFFFF) |
| 0x80013E90 | 4 | `VgaRegisterBase`: added to every port number (0, a translated I/O address, or a mapping of 0x400 bytes) |
| 0x80013E84 | 4 | `curr_x` (pixels) |
| 0x80013E88 | 4 | `curr_y` (pixels) |
| 0x80013E08 | 16 | `ScrollRegion`: left, top, right, bottom; initially 0, 0, 639, 479 |
| 0x80013E18 | 4 | `TextColor`, initially 15 |
| 0x80013E8C | 1 | Pending CR flag: the current row is cleared before the next character |
| 0x80013108 | 0xD00 | `FontData`: 256 characters × 13 bytes, 1 bit per pixel, 8 pixels wide |
| 0x80013000 | 0xCC | `VGA_640x480`: [command stream](#vga-command-streams) setting mode 12h |
| 0x800130CC | 0x3C | `AT_Initialization`: command stream loading the attribute controller palette 0…15 (identity) and enabling the display |
| 0x80013E1C / 0x80013E24 / 0x80013E2C | 8 each | `lMaskTable` (0xFF, 0x7F … 0x01), `rMaskTable` (0x80 … 0xFF), `PixelMask` (0x80 … 0x01): bit masks for x & 7 |
| 0x80013E38 | 0x40 | `lookup`: nibble → 4 bpp expansion used by `VidScreenToBufferBlt` |

### Startup

No `DllMain` and no initialisation code: the image entry point isn't used (export driver loaded by the boot loader). The `/GS` cookie is initialised by `VidInitialize` when `Mode` is 0 (first call, `__security_init_cookie` is in the discardable `INIT` section).

### VidInitialize (0x80011634)

1. `Mode` 0 or 0xFFFFFFFF (phase 0 / no memory manager): `VgaRegisterBase` = 0 (ports used as raw numbers), `VgaIsPresent`; on success `VgaBase` = 0xA0000 for 0xFFFFFFFF, or `MmMapIoSpace(0xA0000, 0x20000, MmNonCached)` for 0. `SetMode` is ignored.
2. Other `Mode` (1 in phase 1): unmaps a previous `VgaBase` (if not 0xA0000), returns FALSE if `HalPrivateDispatchTable` + 0x28 is NULL. Otherwise loops over the buses with `HalFindBusAddressTranslation(0, AddressSpace = 1 (I/O), …, NextBus = TRUE)`:
   - I/O space result → `VgaRegisterBase` = translated address; memory space → `MmMapIoSpace(translated, 0x400, MmNonCached)` (unmapped again if no VGA there);
   - `VgaIsPresent`; if found, `HalFindBusAddressTranslation(0xA0000, AddressSpace = 0, …, NextBus = FALSE)` and `VgaBase` = translated address or `MmMapIoSpace(…, 0x20000, MmNonCached)`;
   - if `SetMode`: cursor to (0, 0), then the `AT_Initialization` stream if `HalResetDisplay()` (+0x2C) succeeded, else the full `VGA_640x480` mode set.
   
   Returns FALSE when no bus has a VGA.

In [NTOSKRNL.EXE](./ntoskrnl.md), `InbvDriverInitialize(Mode, LoaderBlock, ResourceCount)` is called with `Mode` 0xFFFFFFFF by `KiInitializeBootStructures`, 0 by `InitBootProcessor` (after `MmInitSystem(0)`) and 1 by `Phase1InitializationDiscard`. It calls `BvgaDriverInitialize` (→ `VidInitialize(Mode, SetMode)`) unless the load options contain `NOVGA`; `SetMode` is 0 except in phase 1, where it's 1 unless the load options contain `BOOTLOGO`.

### VgaIsPresent (0x80011380)

1. `HalPrivateDispatchTable` + 0xB4 returns 0 → FALSE.
2. Graphics controller (0x3CE/0x3CF): selects index 4 (Read Map Select) and checks the index reads back; writes 3 into it and reads it back; then index 8 (Bit Mask): writes the walking pattern 0xBB, 0x5D, … 1 and checks each value. Any mismatch restores the registers and returns FALSE.
3. Sequencer (0x3C4/0x3C5): index 4 (Memory Mode), toggles bit 3 (chain 4) under a synchronous reset (0x0100 / 0x0300 written to index 0) and checks it reads back.
4. Restores every register; TRUE.

### VidResetDisplay (0x800115D8)

Cursor to (0, 0); if `HalReset` and `HalResetDisplay()` (+0x2C) fails, `VGA_640x480`. Then `AT_Initialization`, [InitializePalette](#palette) and `VidSolidColorFill(0, 0, 639, 479)` (colour 0 ?).

### VGA command streams

`VgaInterpretCmdStream` (0x800111D0) runs a table of 16-bit words, ended by 0. Ports are relative to `VgaRegisterBase`.

| Command | Operands | Action |
|---------|----------|--------|
| 0x10 \| 0x08 (\| 0x04) | port | Read byte (word) |
| 0x10 | port, value | Write byte |
| 0x14 | port, value | Write word |
| 0x12 | port, count, count values | Write count bytes |
| 0x16 | port, count, count values | `WRITE_PORT_BUFFER_USHORT` |
| 0x20 | port, count, first index, count values | Write word (index + value << 8) for consecutive indexes |
| 0x21 | port, count, first index, count values | Write byte index then byte value, consecutive indexes |
| 0x22 | port, AND mask, XOR mask | Read-modify-write byte |
| 0xF0 | none | No operation |

Other commands stop the stream (returns FALSE). `VGA_640x480` writes the sequencer (0x3C4), misc output 0x3C2 = 0xE3, the CRTC (0x3D4: 25 registers, 0x5F 0x4F 0x50 0x82 …, i.e. 640 × 480 at 60 Hz), resets the attribute flip-flop (read 0x3DA), loads the attribute controller (0x3C0), the graphics controller (0x3CE, 9 registers) and the DAC mask 0x3C6 = 0xFF.

### Palette

`InitializePalette` (0x8001198C) writes 16 DAC entries (6-bit R, G, B) through `SetPaletteEntry` (0x3C8 index, 3 × 0x3C9): 0 = black, 1 = (4, 28, 42), then a ramp of blue-greys up to 14 = (59, 61, 61) ?, 15 = (63, 63, 63) white. `VidBitBlt` replaces them with the bitmap's palette (`SetPaletteEntryRGB`: 8-bit `RGBQUAD` components shifted right by 2).

### Drawing

All writes use VGA write mode 2 (`ReadWriteMode(0x0A)`), map mask 0x0F (sequencer index 2 = 0x0F02), set/reset disabled (GC index 7), and the bit mask register (GC index 8) to select pixels; each byte of the frame buffer is read (to load the latches) then written with the colour. Lines are 80 bytes; `__dsb` surrounds each frame-buffer access. Rectangles are clipped to 640 × 480 by `ClipRect` (0x8001188C).

- `SetPixel` (0x80011B50), `DisplayCharacter` (0x8001221C): one pixel at a time; a background colour ≥ 16 means transparent.
- `BitBlt` (0x80011E44) `(Left, Top, Width, Height, Buffer, Bpp, Delta)`: Bpp 4 → packed 4 bpp source converted to planes, one plane per pass (map mask 1 << plane), with left / right edge masks; any other Bpp → 1 bpp source copied to the 4 planes with mask 0 except plane 3 (set bits drawn in colour 8, clear bits in colour 0 ?).
- `RleBitBlt` (0x80012280): BMP RLE4 decoder, bottom-up (encoded runs: same nibble pair → `VidSolidColorFill`, else alternate pixels; escapes 0 = end of line, 1 = end of bitmap, 2 = delta x, y, ≥ 3 = absolute run padded to 16 bits).
- `VgaScroll` (0x80011D18), `PreserveRow` (0x80011DC0): write mode 1 (latch copy) inside the scroll region; `PreserveRow` saves / restores 14 lines to the off-screen area at `VgaBase` + 38400 (line 480).

### VidBitBlt (0x80012548)

`Buffer` is a `BITMAPINFOHEADER` followed by its palette:

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `biSize`: the palette starts at `Buffer + biSize` |
| 0x04 | 4 | `biWidth` |
| 0x08 | 4 | `biHeight`: negative (top-down) → overwritten in the caller's buffer with its absolute value |
| 0x0C | 2 | `biPlanes` |
| 0x0E | 2 | `biBitCount`: `biPlanes × biBitCount` must be ≤ 4, else nothing is drawn |
| 0x10 | 4 | `biCompression`: 2 (`BI_RLE4`) → `RleBitBlt`, else `BitBlt` |
| 0x20 | 4 | `biClrUsed`: number of palette entries loaded, 0 → 16 |
| 0x68 | … | Pixels: always at 0x28 + 16 × 4, whatever `biClrUsed` |

Uncompressed bottom-up bitmaps start at the last row (stride = ((Width × Bpp + 31) / 8) & ~3). Nothing is drawn if width or height is 0.

### Text console

`VidDisplayString` draws at (`curr_x`, `curr_y`) in `TextColor` with a transparent background, 8 pixels per character and 14 pixels per line, inside the scroll region:

- `\n`: next line; past `Bottom` the region is scrolled up by 14 lines (`VgaScroll`, `PreserveRow`), and the new line is restored from the off-screen copy; the cursor goes back to `Left`;
- `\r`: back to `Left`; if not followed by `\n`, the row is cleared (restored) before the next character, so the kernel can rewrite a progress line;
- past `Right`: wraps to the next line, scrolling if needed.

### On the Lumia 520

- The ARM [HAL.dll](./hal.md) implements `READ_PORT_*` / `WRITE_PORT_*` as `KeBugCheckEx(0x4, port, 0 = read / 1 = write, 1, 0)`: the first port access of `VgaIsPresent` stops the system.
- HAL doesn't set `HalPrivateDispatchTable` + 0x28 (`HalFindBusAddressTranslation`) nor + 0x2C (`HalResetDisplay`); they stay NULL in the kernel's static table, so `VidInitialize(1, …)` returns FALSE without touching a port. The kernel's default for + 0xB4 (0x4F7138) returns TRUE, so the early calls `VidInitialize(0xFFFFFFFF, …)` and `VidInitialize(0, …)` would reach the port accesses.
- The phone boots, so these calls must be skipped: most likely the boot loader puts `NOVGA` in the load options ? (not proven, the boot loader wasn't analysed).
