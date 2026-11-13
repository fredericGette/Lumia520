# Physical Memory Mapping

Known regions of the physical address space of the Lumia 520 (Qualcomm MSM8227, MSM8930 family).

The values come from:
- the ACPI tables of the firmware ([DSDT and SSDT](../acpi/README.md): `Memory32Fixed` descriptors of the `_CRS` methods, `CONF`/`RMEM` packages; `FACP`, `APIC`, `WDAT`, `DBG2`, `FPDT`, `BGRT` and `CSRT` decoded in [HAL.dll](../libraries/hal.md#lumia-520-tables)),
- the addresses hardcoded in the Windows drivers and libraries (`MmMapIoSpace` of a constant address, DAL property tables),
- the crash dump memory layout of [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions).

"Length" is the size of the region in bytes, "End" is the first address after the region. `?` = not confirmed.

## Overview

| Start | End | Content |
|-------|-----|---------|
| 0x00000000 | 0x00100000 | Boot ROM, RPM code RAM |
| 0x00100000 | 0x01000000 | RPM message RAM, SSBI (PMIC), security controller, TLMM, clock controller |
| 0x01000000 | 0x03000000 | TCSR, QDSS, Krait subsystem (GIC, timers, SAW2, APCS) |
| 0x03000000 | 0x04000000 | WCNSS (RIVA: WLAN, Bluetooth, FM) |
| 0x04000000 | 0x08000000 | Multimedia subsystem: GPU, video codec, camera, display, IOMMUs |
| 0x09000000 | 0x0A000000 | Modem DSP RAM |
| 0x12000000 | 0x13000000 | Peripheral subsystem: SD controllers, BAMs, GSBI11/12, USB, crypto engine 2 |
| 0x16000000 | 0x1B000000 | GSBI1–10 (I²C / UART / SPI), ADM DMA, crypto engine, PRNG |
| 0x28000000 | 0x29000000 | Low power audio subsystem (LPASS): SLIMbus, ADSP |
| 0x2A000000 | 0x2F000000 | Internal memories (System IMEM, MM IMEM, GMEM) |
| 0x80000000 | 0xA0000000 | Main memory (SDRAM, EBI1), 512 MB |

## Internal memories

| Start | Length | End | Description | Source |
|-------|--------|-----|-------------|--------|
| 0x00000000 | ? | | Boot ROM. Contains the Primary Bootloader (PBL), see [Boot](../boot/README.md#notes) | |
| 0x00020000 | 0x24000 (144 KB) | 0x00044000 | RPM code RAM | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions), `CONF` of [`\_SB.AMSS`](../drivers/qcamss8930.md) |
| 0x00108000 | 0x6000 (24 KB) | 0x0010E000 | RPM message RAM. [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) maps the first 0x4000 bytes | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions), [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x2A000000 | 0x40000 (256 KB) | 0x2A040000 | System IMEM. SBL1 and TrustZone run here (the SDRAM isn't ready yet). The crash dump layout uses 0x2A000000–0x2A03F000 and 0x2A03F000–0x2A04F000 | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions) |
| 0x2A03FA94 | 4 | | MOR/PPI bytes of the TPM (`MORR`, `PCMD`, `CCMD`, `RCMD`): operation region `TPMR` of `\_SB.TPM0`, resource 0 of `\_SB.SCM0` | [qcscm8930.sys](../drivers/qcscm8930.md#acpi-memory-resources) |
| 0x2E000000 | 0x30000 (192 KB) | 0x2E030000 | Multimedia IMEM (MM IMEM). SBL2 runs here first ? | `CONF` of [`\_SB.AMSS`](../drivers/qcamss8930.md) |
| 0x2E030000 | 0x80000 (512 KB) | 0x2E0B0000 | Graphics internal memory (GMEM or GIMEM) | |

## Peripheral registers

### 0x00100000 – 0x01000000

| Start | Length | Description | Source |
|-------|--------|-------------|--------|
| 0x0010DB00 | 0x9C | ? (MPM ?) | [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x0010DD04 | 0x34 | RPM sleep statistics (in the RPM message RAM) | [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory), [qcsysdef8930.sys](../drivers/qcsysdef8930.md) |
| 0x00300000 | 0x200 | SSBI2 configuration registers of the PMIC (PM8038) | `PMCF` of [qcpmic8930.sys](../drivers/qcpmic8930.md#acpi-pmcf) |
| 0x00500000 | 0x40 | SSBI2 command registers of the PMIC (PM8038) | `PMCF` of [qcpmic8930.sys](../drivers/qcpmic8930.md#acpi-pmcf) |
| 0x00700000 | 0x8000 | Security controller / QFPROM (fuses, TSENS calibration ?). `SE_CTRL_REGS` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node), [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x00800000 | 0x2000 | TLMM (Top Level Mode Multiplexer): GPIO controller, 152 pins. `\_SB.GIO0`. [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) maps 0x4000 or 0x2154 bytes | [qcgpio.sys](../drivers/qcgpio.md), [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x00801284 | 4 | GPIO_40 ? Written 0 then 2 before each interrupt to the RIVA, on MSM8960 v1 only (never on the Lumia 520) | [qcsmd8930.sys](../drivers/qcsmd8930.md), [qcsmsm8930.sys](../drivers/qcsmsm8930.md) |
| 0x00802054 | 4 | TLMM JTAG id / hardware revision register. `\_SB.CIN0` | [qcchipinfo8930.sys](../drivers/qcchipinfo8930.md) |
| 0x0080207C | 4 | TLMM ? Written with 1 by the `EKOP` method of `\_SB.SLM1` | [qcslimbus8930.sys](../drivers/qcslimbus8930.md) |
| 0x008020B8 | 4 | TLMM ? Written with 2 at each init of the GSBI4 QUP. Resource 2 of `\_SB.CAMP` | [qccamplatform8930.sys](../drivers/qccamplatform8930.md) |
| 0x00900000 | 0x4000 | Clock controller (GCC), also contains the TSENS registers | [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory), [qcerng8930.sys](../drivers/qcerng8930.md#memory-resources), [qce2arm8930.sys](../drivers/qce2arm8930.md), [qcusbfnfilter8930.sys](../drivers/qcusbfnfilter8930.md#memory-resources), [dumpsd.sys](../drivers/dumpsd.md), [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md) |
| 0x009020B4 | 4 | Reset register of the `FACP` table (write 1 to reset the system) | [HAL.dll](../libraries/hal.md#lumia-520-tables) |

### 0x01000000 – 0x03000000

| Start | Length | Description | Source |
|-------|--------|-------------|--------|
| 0x01200604 | 0x80 | Hardware spinlocks (TCSR mutex registers), one DWORD per lock. Resource 1 of `\_SB.SMEM` | [qcsmem8930.sys](../drivers/qcsmem8930.md#memory-resources) |
| 0x01A01000 | 0x1000 | QDSS ETB (Embedded Trace Buffer of the Qualcomm Debug Subsystem) | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions) |
| 0x02000000 | 0x1000 | GIC distributor (GICD), GSI base 0 | `APIC` table of [HAL.dll](../libraries/hal.md#lumia-520-tables), [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory), [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x02002000 | ? | GIC CPU interface (GICC) | `APIC` table of [HAL.dll](../libraries/hal.md#lumia-520-tables) |
| 0x0200A000 | 0x1000 | Krait timer block (shared) ? First address of the shared info of the CSRT timer group | [HAL.dll](../libraries/hal.md#lumia-520-tables), [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x02011000 | ? | APCS global clock controller (APCS GCC) | [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x02011008 | 4 | Outgoing IPC interrupt register of the APPS processor: interrupts the modem, the QDSP6 and the WCNSS (one bit each). Resource 2 of `\_SB.SMEM` | [qcsmem8930.sys](../drivers/qcsmem8930.md#memory-resources), [qcsmd8930.sys](../drivers/qcsmd8930.md#lumia-520-acpi-node), [qcsmsm8930.sys](../drivers/qcsmsm8930.md#lumia-520-acpi-node) |
| 0x02012000 | 0x1000 | L2 SAW2 (SPM) | [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x02080000 | 0x1000 | GIC distributor in the DAL property table 0 of [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) (tables 1, 2 and 3 use 0x02000000) | [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x02089000 | 0x1000 | CPU0 SAW2 (SPM) | [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x0208A000 | 0x1000 | CPU0 Krait timers (DGT, GPT) and watchdog (`WDAT`) | [HalExtQ8660Timers.dll](../libraries/halextq8660timers.md), [HAL.dll](../libraries/hal.md#lumia-520-tables) |
| 0x02099000 | 0x1000 | CPU1 SAW2 (SPM) | [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x0209A000 | 0x1000 | CPU1 Krait timers | CSRT timer group of [HAL.dll](../libraries/hal.md#lumia-520-tables) |

### 0x03000000 – 0x04000000 (WCNSS)

| Start | Length | Description | Source |
|-------|--------|-------------|--------|
| 0x03000000 | 0x1000000 | WCNSS (RIVA) register space. `\_SB.RIVA.QWLN` | [qcwlan8930.sys](../drivers/qcwlan8930.md), [qcwcn8930.sys](../drivers/qcwcn8930.md#lumia-520-acpi-node) |
| 0x03200B10 | ? | Pointer computed by the WLAN driver in the WCNSS mapping ? | [qcwlan8930.sys](../drivers/qcwlan8930.md) |
| 0x03204028 | 4 | `PMU_CFG` (configuration of the IRIS XO clock) | [qcwcn8930.sys](../drivers/qcwcn8930.md#iris-xo-clock) |

### 0x04000000 – 0x08000000 (multimedia)

| Start | Length | Description | Source |
|-------|--------|-------------|--------|
| 0x04000008 | 4 | ? Bit 26 is set at start | [qcpep8930.sys](../drivers/qcpep8930.md#physical-memory) |
| 0x04300000 | 0x20000 | GPU (Adreno 3xx) registers, `GFX_REGS` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x04400000 | 0x100000 | Video codec (VIDC), `VIDEO_REGS` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x04500000 | 0x760 | Camera VFE (Video Front End), `\_SB.VFE0` | [qccamvfe8930.sys](../drivers/qccamvfe8930.md#hardware) |
| 0x04600000 | 0x200 | JPEG encoder (Gemini), `\_SB.CAMG` | [qccamgemini8930.sys](../drivers/qccamgemini8930.md) |
| 0x04700000 | 0x1000 | MIPI DSI (display), `MIPI_DSI_REGS` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x04800000 | 0x400 | Camera CSID 0 (MIPI CSI decoder), `\_SB.CAMS` | [qccamsensor8930.sys](../drivers/qccamsensor8930.md) |
| 0x04800800 | 0x400 | Camera ISPIF, `\_SB.VFE0` | [qccamvfe8930.sys](../drivers/qccamvfe8930.md#hardware) |
| 0x04800C00 | 0x400 | Camera CSIPHY 0 (MIPI CSI PHY), `\_SB.CAMS` | [qccamsensor8930.sys](../drivers/qccamsensor8930.md) |
| 0x04A00000 | 0x1000 | HDMI, `HDMI_REGS` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x04E00000 | 0x10000 | MDP rotator, `ROTATOR_REGS` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x04F00000 | 0x2000 | TV encoder, `TV_ENC_REGS` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x05100000 | 0x100000 | MDP (Mobile Display Processor), `MDP_REGS` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x05300000 | 0x100000 | VPE (Video Pre-processing Engine), `\_SB.VPE` | [qcvpe8930.sys](../drivers/qcvpe8930.md) |
| 0x05700058 | 4 | `MMSS_SFPB_GPREG` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x07400000 | 0x100000 | IOMMU 1: VPE. `\_SB.SMMU` resource 0 | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node) |
| 0x07500000 | 0x100000 | IOMMU 2: MDP0 ? | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node) |
| 0x07600000 | 0x100000 | IOMMU 3: MDP1 ? | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node) |
| 0x07700000 | 0x100000 | IOMMU 4: rotator ? | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node) |
| 0x07800000 | 0x100000 | IOMMU 5: IJPEG ? | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node) |
| 0x07900000 | 0x100000 | IOMMU 6: VFE ? | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node) |
| 0x07A00000 | 0x100000 | IOMMU 7: video codec A ? | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node) |
| 0x07B00000 | 0x100000 | IOMMU 8: video codec B ? | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node) |
| 0x07C00000 | 0x100000 | IOMMU 9: GFX3D ? Also mapped (hardcoded) by the display driver | [qcsmmu8930.sys](../drivers/qcsmmu8930.md#lumia-520-acpi-node), [qcdxkm8930.sys](../drivers/qcdxkm8930.md#resources) |
| 0x07D00000 | 0x100000 | GFX3D1 IOMMU ? (hardcoded in the display driver, not in the ACPI tables) | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#resources) |

### 0x09000000 – 0x0A000000 (modem DSP)

| Start | Length | Description | Source |
|-------|--------|-------------|--------|
| 0x09000000 | 0x8000 | MDSP RAM (modem DSP) | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions), `CONF` of [`\_SB.AMSS`](../drivers/qcamss8930.md) |
| 0x09200000 | 0x8000 | MDSP RAM | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions) |
| 0x09400000 | 0xF800 | MDSP RAM (0x10000 in the `CONF` of `\_SB.AMSS`) | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions) |

### 0x12000000 – 0x13000000 (peripheral subsystem)

| Start | Length | Description | Source |
|-------|--------|-------------|--------|
| 0x12104080 | 4 | Outgoing SMD interrupt to the DSPS. Resource 3 of `\_SB.SMEM` | [qcsmem8930.sys](../drivers/qcsmem8930.md#memory-resources) |
| 0x12104094 | 4 | Outgoing SMSM interrupt to the DSPS. Resource 4 of `\_SB.SMEM` | [qcsmem8930.sys](../drivers/qcsmem8930.md#memory-resources) |
| 0x12140000 | 0x800 ? | SDCC2 controller (not used) | [dumpsd.sys](../drivers/dumpsd.md) |
| 0x12140800 | 0x100 | SDCC2 DML | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x12142000 | 0x2000 | SDCC2 BAM | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x12180000 | 0x800 | SDCC3 controller: SD card. `\_SB.SDC3` | [dumpsd.sys](../drivers/dumpsd.md) |
| 0x12180800 | 0x100 | SDCC3 DML | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x12182000 | 0x2000 | SDCC3 BAM | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x121C0000 | 0x800 ? | SDCC4 controller (not used) | [dumpsd.sys](../drivers/dumpsd.md) |
| 0x121C0800 | 0x100 | SDCC4 DML | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x121C2000 | 0x2000 | SDCC4 BAM | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x12200000 | 0x800 ? | SDCC5 controller (not used) | [dumpsd.sys](../drivers/dumpsd.md) |
| 0x12200800 | 0x100 | SDCC5 DML | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x12202000 | 0x2000 | SDCC5 BAM | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x12244000 | 0x2000 | BAM DMA (`"BAMDMA"`), `\_SB.BAM0` | [qcbamdmux8930.sys](../drivers/qcbamdmux8930.md#lumia-520-acpi-nodes) |
| 0x12400000 | 0x800 | SDCC1 controller: eMMC. `\_SB.SDC1` | [dumpsd.sys](../drivers/dumpsd.md) |
| 0x12400800 | 0x100 | SDCC1 DML | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x12402000 | 0x2000 | SDCC1 BAM | CSRT of [QCHalExtQ8x60Bam.dll](../libraries/qchalextq8x60bam.md#lumia-520-csrt) |
| 0x12440000 | 0x20 | GSBI11 control (not configured) | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x12480000 | 0x20 | GSBI12 control (I²C) | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x124A0000 | 0x800 | GSBI12 QUP: I²C controller `\_SB.IC12` (accelerometer, proximity / light sensor) | [qci2c8930.sys](../drivers/qci2c8930.md), [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x124C2000 | 0x2000 | A2 BAM (`"DataBAM"`, modem data), `\_SB.BAM1` | [qcbamdmux8930.sys](../drivers/qcbamdmux8930.md#lumia-520-acpi-nodes) |
| 0x12500000 | 0x200 | USB HS1 controller registers (ChipIdea core, `USB1_HS_BASE`), `\_SB.UFN1`. Also debug device of the `DBG2` table. [qcusbfnfilter8930.sys](../drivers/qcusbfnfilter8930.md#memory-resources) maps 0x2000 bytes (hardcoded) | [usbfnchipidea.sys](../drivers/usbfnchipidea.md), [qcusbfnfilter8930.sys](../drivers/qcusbfnfilter8930.md#memory-resources) |
| 0x12560000 | 0x20000 | Crypto engine 2, `\_SB.QCE2` | [qce2arm8930.sys](../drivers/qce2arm8930.md) |

### 0x16000000 – 0x1B000000 (GSBI, DMA, crypto)

Each GSBI (General Serial Bus Interface) has a 0x20-byte control block at its base, and its QUP (I²C / SPI) or UART core at a fixed offset (QUP: +0x80000, UART: +0x40000).

| Start | Length | Description | Source |
|-------|--------|-------------|--------|
| 0x16000000 | 0x20 | GSBI1 control (not configured) | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x16100000 | 0x20 | GSBI2 control (not configured) | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x16200000 | 0x20 | GSBI3 control (I²C) | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x16280000 | 0x800 | GSBI3 QUP: I²C controller `\_SB.I2C3` (touch screen) | [qci2c8930.sys](../drivers/qci2c8930.md), [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x16300000 | 0x20 | GSBI4 control. Programmed by the camera platform driver (`\_SB.CAMP` resource 0) | [qccamplatform8930.sys](../drivers/qccamplatform8930.md) |
| 0x16380000 | 0x408 | GSBI4 QUP: I²C of the camera sensors (`\_SB.CAMP` resource 1) | [qccamplatform8930.sys](../drivers/qccamplatform8930.md) |
| 0x16400000 | 0x20 | GSBI5 control | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values), [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x16440000 | ? | GSBI5 UART: serial debug port `\_SB.UAR1` (`DBG2` table) | [qcuart8930.sys](../drivers/qcuart8930.md#property-tables), [HAL.dll](../libraries/hal.md#lumia-520-tables) |
| 0x16500000 | 0x20 | GSBI6 control | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values), [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x16540000 | ? | GSBI6 UART | [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x16600000 | 0x20 | GSBI7 control | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values), [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x16640000 | ? | GSBI7 UART | [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x18300000 | ? | ADM3 DMA controller (12 channels, GSIV 203), CSRT group 0x1002 | [QCHalExtQcAdm3Dma.dll](../libraries/qchalextqcadm3dma.md#lumia-520-csrt) |
| 0x18500000 | 0x20000 | Crypto engine, `\_SB.QQCE` | [qcearm8930.sys](../drivers/qcearm8930.md) |
| 0x19C00000 | ? | GSBI12 control in the DAL property table 0 of [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) (the ACPI tables use 0x12480000) | [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x19C40000 | ? | GSBI12 UART in the DAL property table 0 | [qcuart8930.sys](../drivers/qcuart8930.md#property-tables) |
| 0x1A000000 | 0x20 | GSBI8 control (not configured) | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x1A100000 | 0x20 | GSBI9 control (I²C) | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x1A180000 | 0x800 | GSBI9 QUP: I²C controller `\_SB.I2C9` (no device declared) | [qci2c8930.sys](../drivers/qci2c8930.md), [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x1A200000 | 0x20 | GSBI10 control (not configured) | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) |
| 0x1A500000 | 0x400 | PRNG (pseudo random number generator), `\_SB.QRNG` (`QCOM1110`) | [DSDT](../acpi/README.md), [qcerng8930.sys](../drivers/qcerng8930.md#memory-resources) ? |

### 0x28000000 – 0x29000000 (LPASS)

| Start | Length | Description | Source |
|-------|--------|-------------|--------|
| 0x28080000 | 0x4000 | SLIMbus controller, `\_SB.SLM1` | [qcslimbus8930.sys](../drivers/qcslimbus8930.md) |
| 0x28084000 | 0x2000 | LPASS BAM (`"LPASS_BAM"`, SLIMbus data ports), `\_SB.BAM2` | [qcbamdmux8930.sys](../drivers/qcbamdmux8930.md#lumia-520-acpi-nodes), [qcslimbus8930.sys](../drivers/qcslimbus8930.md) |
| 0x28400000 | 0x20000 | ADSP (LPASS QDSP6) memory, dumped on crash | `CONF` of `\_SB.ADSP` ([qcadsp8930.sys](../drivers/qcadsp8930.md)), [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions) |
| 0x28800010 | 4 | `LPASS_QDSP6SS_STOP`: writing 1 sends an NMI to the QDSP6 to stop it (hardcoded) | [qcadsp8930.sys](../drivers/qcadsp8930.md) |

## Main memory (SDRAM)

The main memory (EBI1) starts at 0x80000000 and is 512 MB long (0x20000000, up to 0xA0000000). It's initialised by SBL2: SBL3, UEFI and MainOS run in it.

| Start | Length | End | Description | Source |
|-------|--------|-----|-------------|--------|
| 0x80000000 | 0x200000 (2 MB) | 0x80200000 | Shared memory (SMEM), base of all the SMEM offsets. `\_SB.SMEM` resource 0. Also the `SMD (MODEM)` crash dump segment | [qcsmem8930.sys](../drivers/qcsmem8930.md#memory-resources), [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions) |
| 0x80200000 | 0x8400000 (132 MB) | 0x88600000 | Krait HLOS (memory of Windows). The following regions (up to 0x8143D000) are inside it | |
| 0x80301000 | ? | | Parked address of CPU 0 (multiprocessor parking protocol, `APIC` table) | [HAL.dll](../libraries/hal.md#lumia-520-tables) |
| 0x80302000 | ? | | Parked address of CPU 1 | [HAL.dll](../libraries/hal.md#lumia-520-tables) |
| 0x80380000 | ? | | Boot performance record (`FPDT` table) | [HAL.dll](../libraries/hal.md#lumia-520-tables) |
| 0x80385000 | 0x4400 | 0x80389400 | `MISC_REG` crash dump region ? | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions) |
| 0x80400000 | 0x400000 (4 MB) | 0x80800000 | UEFI frame buffer, `UEFI_FRAME_BUFFER` of `\_SB.GPU0` | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) |
| 0x80C00000 | ? | | Boot logo image (`BGRT` table) | [HAL.dll](../libraries/hal.md#lumia-520-tables) |
| 0x81400000 | 0x3D000 (244 KB) | 0x8143D000 | TrustZone variables buffer (parameters of the TZ requests and of the UEFI variable requests). `\_SB.SCM0` resource 1 | [qcscm8930.sys](../drivers/qcscm8930.md#acpi-memory-resources) |
| 0x8143D000 | 0x3000 (12 KB) | 0x81440000 | TrustZone TPM control area ? `\_SB.SCM0` resource 2 | [qcscm8930.sys](../drivers/qcscm8930.md#acpi-memory-resources) |
| 0x89000000 | 0x4400000 (68 MB) | 0x8D400000 | Modem software image (Q6SW, AMSS) | `CONF` of [`\_SB.AMSS`](../drivers/qcamss8930.md), [qccdi8930.sys](../drivers/qccdi8930.md#lumia-520-acpi-nodes) |
| 0x8D400000 | 0x600000 (6 MB) | 0x8DA00000 | Modem firmware image (Q6FW) | `CONF` of [`\_SB.AMSS`](../drivers/qcamss8930.md), [qccdi8930.sys](../drivers/qccdi8930.md#lumia-520-acpi-nodes) |
| 0x8DA00000 | 0x1800000 (24 MB) | 0x8F200000 | LPASS / ADSP image. The crash dump table of qccdi8930.sys only uses 0x8DA00000–0x8EC00000 | `CONF` of `\_SB.ADSP` ([qcadsp8930.sys](../drivers/qcadsp8930.md)), [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions) |
| 0x8F000000 | 0x700000 (7 MB) | 0x8F700000 | WCNSS (RIVA) image, entry point 0x8F001228 ([qcpil8930.sys](../drivers/qcpil8930.md)). The `CONF` of `\_SB.RIVA` only gives 0x8F200000–0x8F700000 (5 MB) | [qccdi8930.sys](../drivers/qccdi8930.md#example-of-memory-regions), [qcwcn8930.sys](../drivers/qcwcn8930.md#lumia-520-acpi-node) |
| 0x8FB00000 | 0x300000 (3 MB) | 0x8FE00000 | Remote file system (RMTFS) shared buffer of the modem EFS, `\_SB.RFS0` ? | [qcremotefs8930.sys](../drivers/qcremotefs8930.md#shared-memory-buffer) |
| 0x8FF00000 | 0x100000 (1 MB) | 0x90000000 | ? Dumped with the modem (`CONF` of `\_SB.AMSS`) | [qcamss8930.sys](../drivers/qcamss8930.md), [qccdi8930.sys](../drivers/qccdi8930.md#lumia-520-acpi-nodes) |

Some buffers are allocated at run time, so their address changes. Examples: the watchdog bark buffer of [qccdi8930.sys](../drivers/qccdi8930.md) (e.g. 0x9FEB6000), the shared memory of [qcq6ad8930.sys](../drivers/qcq6ad8930.md) (above 0x29000000), the buffers of [qcomavsdecoder.sys](../drivers/qcomavsdecoder.md) (0x80200000–0xC0000000) and [qcomavsencoder.sys](../drivers/qcomavsencoder.md) (above 0x29000000).
