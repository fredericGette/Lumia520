# ACPI tables

ACPI tables of the Lumia 520 firmware (Windows Phone 8.1), disassembled with the ACPICA `iasl` compiler (version 20260408):  
| File | Signature | OEM ID | OEM table ID | OEM revision | Length |
|------|-----------|--------|--------------|--------------|--------|
| [dsdt.dsl](./dsdt.dsl) | DSDT (revision 2) | `QCOMM ` | `MSM8930 ` | 4 | 70813 bytes |
| [ssdt.dsl](./ssdt.dsl) | SSDT (revision 1) | `NOKIA ` | `MSM8930 ` | 4 | 3364 bytes |

The DSDT is the Qualcomm platform table: SoC blocks, subsystems, PMIC, display, audio, etc. The SSDT is the Nokia table: sensors, the battery/charger device and some Nokia devices. All the devices are in the `\_SB` scope.

`iasl` doesn't decode the resource buffers returned by the `_CRS` methods (they're shown as raw bytes). The decoded values are given in the driver pages. The format of the descriptors is in the ACPI specification, §6.4 "Resource Data Types for ACPI".

The ACPI methods that a Windows driver evaluates are sent through [acpi.sys](../drivers/acpi.md) with `IOCTL_ACPI_EVAL_METHOD`. The `GenericSerialBus` operation regions are handled by [acpiex.sys](../drivers/acpiex.md#operation-regions).

## Devices

Driver: the Windows driver that loads on the node, when it's documented in [drivers](../drivers/README.md) (`?` = not confirmed).

### DSDT

| Node | `_HID` / `_ADR` | Driver | Comment |
|------|-----------------|--------|---------|
| `\_SB.ABD` | QCOM1200 | [qcabd8930.sys](../drivers/qcabd8930.md#lumia-520-acpi-node) | Software I²C target (`GenericSerialBus` region `ROP1`) |
| `\_SB.PMIC` | QCOM0A00 | [qcpmic8930.sys](../drivers/qcpmic8930.md#acpi-pmcf) | PM8038 PMIC, method `PMCF` |
| `\_SB.PM01` | QCOM05C0 | | PMIC GPIO controller |
| `\_SB.PBMS` | QCOM0A02 | [qcbms8930.sys](../drivers/qcbms8930.md) | Battery monitoring (fuel gauge), method `PMCF` |
| `\_SB.PMAP` | QCOM0B20 | [qcpmicapps8930.sys](../drivers/qcpmicapps8930.md#lumia-520-acpi-node) | PMIC RTC, method `GEPT` |
| `\_SB.PRTC` | ACPI000E | [acpitime.sys](../drivers/acpitime.md#lumia-520-acpi-node) | Time and alarm device (`_GCP`, `_GRT`, `_SRT`) |
| `\_SB.PEP0` | QCOM0811 | | Power engine plug-in (`_CID` `PNP0D80`); power-framework description of the devices (`DCFG`) |
| `\_SB.PRXY` | QCOM0812 | | Power proxy, see [qcabd8930.sys](../drivers/qcabd8930.md#lumia-520-acpi-node) |
| `\_SB.SDF1` | QCOM2134 | | |
| `\_SB.AGR0` | ACPI000C | [acpipagr.sys](../drivers/acpipagr.md#lumia-520-acpi-definition) | Processor aggregator |
| `\_SB.TZ0` … `\_SB.TZ11` | QCOM2400 … QCOM2409, NOKIA_THERMAL, QCOM2154 | | Thermal zones, see [acpipagr.sys](../drivers/acpipagr.md#lumia-520-acpi-definition) |
| `\_SB.SMMU` | QCOM0200 | qcvcm8930.sys ? | System MMU |
| `\_SB.GPU0` | QCOM0300 | [qcdxkm8930.sys](../drivers/qcdxkm8930.md#lumia-520-acpi-node) | Display/graphics adapter (`_ROM` panel XML, `RESI`, `ENGS`, `PMCL`) |
| `\_SB.GPU0.MON0` | `_ADR` 0 | [monitor.sys](../drivers/monitor.md#lumia-520-acpi-node) | Monitor |
| `\_SB.GPU0.AVS0` | `_ADR` 0x00024321 | | AVStream child ? |
| `\_SB.SGPU` | QCOM_GPU | | |
| `\_SB.AMSS` | QCOM0E80 | | Modem subsystem (`CONF`, `VLMT`), see [qccdi8930.sys](../drivers/qccdi8930.md#lumia-520-acpi-nodes) |
| `\_SB.ADSP` | QCOM0E10 | | LPASS/ADSP subsystem (`CONF`, `MANU`) |
| `\_SB.CAMP`, `CAMS`, `AVS0`, `CAMG`, `VFE0`, `VPE` | QCOM0775, 0710, 0720, 0730, 0700, 0770 | | Camera and video pre-processing blocks |
| `\_SB.CESP` | CESP0001 | | |
| `\_SB.GIO0` | QCOM0500 | | MSM TLMM GPIO controller, see [acpiex.sys](../drivers/acpiex.md#operation-regions) |
| `\_SB.PWIO` | QCOM0D20 | | Power key / PMIC IO ? |
| `\_SB.BTN0` | QCOM0D60 | | Buttons (`_CID` `PNP0C40`) |
| `\_SB.GSBI` | QCOM0145 | [qcgsbi8930.sys](../drivers/qcgsbi8930.md#lumia-520-values) | GSBI configuration (`CONF`) |
| `\_SB.I2C3`, `I2C9`, `IC12` | QCOM0180 | | I²C controllers of GSBI3, 9 and 12 |
| `\_SB.SMEM` | QCOM0F00 | [qcsmem8930.sys](../drivers/qcsmem8930.md#memory-resources) | Shared memory |
| `\_SB.SMD0` | QCOM0F10 | [qcsmd8930.sys](../drivers/qcsmd8930.md#lumia-520-acpi-node) | Shared memory driver (`INTR`) |
| `\_SB.SMD0.GPS` | QCOM_GPS | | GPS |
| `\_SB.SMSM` | QCOM0F30 | [qcsmsm8930.sys](../drivers/qcsmsm8930.md#lumia-520-acpi-node) | Shared memory state machine (`INTR`) |
| `\_SB.DMUX` | QCOM0F50 | [qcbamdmux8930.sys](../drivers/qcbamdmux8930.md#lumia-520-acpi-nodes) | BAM data multiplexer |
| `\_SB.RIVA` | QCOM0E20 | [qcwcn8930.sys](../drivers/qcwcn8930.md#lumia-520-acpi-node) | WCNSS (`CONF`) |
| `\_SB.RIVA.BTH0` | `_ADR` 1 | [qcbluetooth8930.sys](../drivers/qcbluetooth8930.md) | Bluetooth |
| `\_SB.RIVA.QWLN` | `_ADR` 2 | | WLAN |
| `\_SB.RIVA.FMT0` | `_ADR` 3 | | FM transport |
| `\_SB.RIVA.WPXY` | NOKIA_WLAN_PROXY | | |
| `\_SB.FTM0` | QCOM01E1 | | |
| `\_SB.RFS0` | QCOM0F20 | | Remote file system ? (`Memory32Fixed` 0x8FB00000, 0x300000) |
| `\_SB.IPC0` | QCOM0F40 | | |
| `\_SB.SLM1` | QCOM0190 | | |
| `\_SB.QQCE`, `QCE2` | QCOM1100, QCOM1190 | | Crypto engines |
| `\_SB.QRNG` | QCOM1110 | | Random number generator |
| `\_SB.QBCC` | QCOM1000 | | |
| `\_SB.TPM0` | MSFT0101 | | TPM 2.0 (PPI and memory-clear `_DSM`), see [qcscm8930.sys](../drivers/qcscm8930.md#acpi-memory-resources) |
| `\_SB.SCM0` | QCOM0E90 | [qcscm8930.sys](../drivers/qcscm8930.md#acpi-memory-resources) | Secure channel manager (`GCFG`) |
| `\_SB.SDC1`, `SDC3` | QCOM7002 | | SD controllers (eMMC, SD card) |
| `\_SB.ACHW`, `TICO`, `MBHC`, `MBGP` | QCOM0741, 0742, 0746, 2149 | | Audio |
| `\_SB.UFN1` | QCOM01C0 | | USB function controller |
| `\_SB.QDIG` | QCOM0F80 | [qcdiagrouter8930.sys](../drivers/qcdiagrouter8930.md) ? | DIAG router |
| `\_SB.QDCI` | QCOM0F81 | [qcdiagcsi8930.sys](../drivers/qcdiagcsi8930.md) ? | DIAG consumer interface |
| `\_SB.QCDB` | QCOM1204 | | |
| `\_SB.ADC1` | QCOM0C00 | | PMIC ADC (channel list `CHAN`) |
| `\_SB.BAM0`, `BAM1`, `BAM2` | QCOM0910 | | BAM DMA engines, see [qcbamdmux8930.sys](../drivers/qcbamdmux8930.md#lumia-520-acpi-nodes) |
| `\_SB.HAL1`, `HAL2`, `HAL3`, `HAL5` | QCOM1001, 1002, 1003, 1005 | | |
| `\_SB.QMUX` | QCOM0FA0 | | |
| `\_SB.PILC` | QCOM0E00 | [qcpil8930.sys](../drivers/qcpil8930.md) | Peripheral image loader |
| `\_SB.CDI` | QCOM0E31 | [qccdi8930.sys](../drivers/qccdi8930.md#lumia-520-acpi-nodes) | Crash dump injector |
| `\_SB.RPEN` | QCOM0E30 | [qcrpen8930.sys](../drivers/qcrpen8930.md) | RPE notifier |
| `\_SB.Q6AD`, `Q6VP`, `ACDB`, `AHWI`, `QCRT`, `AVSD`, `AVSE` | QCOM0750, 0760, 0790, 0743, 0744, 0745, 0747 | | Audio (QDSP6) |
| `\_SB.WDFH` | QCOM2146 | | |
| `\_SB.CPU0`, `CPU1` | ACPI0007 | | Processors |
| `\_SB.CIN0` | QCOM1201 | [qcchipinfo8930.sys](../drivers/qcchipinfo8930.md) | Chip information (TLMM register 0x00802054) |
| `\_SB.MBB0` … `MBB3` | QCOM0EA0 | | Mobile broadband |
| `\_SB.HWN0` | QCOM0D50 | hwnled ? | Hardware notification LEDs (`HWNL`), see [oempanel.sys](../drivers/oempanel.md) |
| `\_SB.VIB1` | NOKIA_VIBRA_DIME | | Vibrator |
| `\_SB.SSM`, `MBRG`, `RMNT`, `RMAT` | QCOM2123, 2145, 2148, 2155 | | |
| `\_SB.TCH1` | NOKIA_TOUCH | | Touch screen, I²C 0x4B on `\_SB.I2C3` |
| `\_SB.ATTS` | NOKIA_ATTS | | |
| `\_SB.EGP0` | ENOGPIO | | |
| `\_SB.DISP` | NOKIA_PANEL | [oempanel.sys](../drivers/oempanel.md) | Panel (`DPID`) |
| `\_SB.NRSD` | NRSD0001 | | |

### SSDT

| Node | `_HID` | Driver | Comment |
|------|--------|--------|---------|
| `\_SB.ACC1` | KXTNK | | Kionix accelerometer, I²C 0x1E on `\_SB.IC12` (`ROTM` rotation matrix) |
| `\_SB.ALS1`, `\_SB.PRX1` | QPDS_T900_ALS, QPDS_T900_PRX | | Light / proximity sensor, I²C 0x39 on `\_SB.IC12`; present only if register 0x92 reads 0x29 |
| `\_SB.ALS2`, `\_SB.PRX2` | LTR_554ALS_02_ALS, LTR_554ALS_02_PRX | | LiteOn LTR-554 light / proximity sensor, I²C 0x23 on `\_SB.IC12` |
| `\_SB.NDLD` | DATA_LOGGER | | |
| `\_SB.NREG` | ODDT_REG | | |
| `\_SB.VIB2` | ODDT_VIB | | |
| `\_SB.NCPU` | ODDT_CPU | | |
| `\_SB.NEDD` | NOKI0B00 | [NokiaEnergyDriver.sys](../drivers/nokiaenergydriver.md#lumia-520-acpi-node) | Battery / charger (`CONF`, `CUTF`, `CHGR`) |
