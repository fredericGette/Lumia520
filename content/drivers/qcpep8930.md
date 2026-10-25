## Qcpep8930.sys

Qualcomm Power Engine Plug-in (PEP) for MSM8930 and the thermal-zone driver.  
It registers with the Windows power framework (`PoFxRegisterPlugin`) and implements device power management (D-states, F-states, P-states of the devices described in ACPI) and processor power management (idle states, CPU frequency). It's a port of the Qualcomm MSM firmware frameworks to Windows: NPA resources, the RPM driver (message RAM + IPC), the clock regime (`ClockDriver.c`, BIST, AVS), the sleep solver (LPR/LPRM: SWFI, power collapse, L2 retention, PXO/CXO shutdown, VDD min), the ICB bus arbiter and an SSBI PMIC driver. PMIC requests ("PPP" requests) go either to the RPM or to [qcpmic8930.sys](./qcpmic8930.md).  
The same driver also serves the ACPI thermal zones: the TSENS on-die sensors are read directly, and the `PA_THERM` / `BATT_THERM` channels through the ADC driver.  
PDB path: `P:\PEP\rel\8.3.1\arm\Release\qcpep8930.pdb`. Pool tags `qpe*`.

Hardware IDs handled by `EvtDriverDeviceAdd` (sub_4D24C4):  
| Hardware ID | Lumia 520 node | Role |
|-------------|----------------|------|
| `QCOM0811` | `\_SB.PEP0` (`_CID` `PNP0D80`) | The PEP itself |
| `QCOM2400` … `QCOM2409` | `\_SB.TZ0` … (thermal zones) | TSENS sensors 0–9 (zone index 0–9) |
| `QCOM2152`, `QCOM2153` | thermal zones | ADC channel `PA_THERM` (zone index 10, 11) |
| `QCOM2154` | thermal zone | ADC channel `BATT_THERM` |

See [acpipagr.sys](./acpipagr.md#lumia-520-acpi-definition) for the thermal-zone definitions.

Symbolic link : `\??\QCOM_PEPDriver` (on the `QCOM0811` device)  
The thermal-zone devices have no name.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcpep`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0811\0`  

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcpep\Parameters` (all REG_DWORD, read by sub_412838 with an index, or by sub_402EBC for the first two). A missing value keeps the default:  
| Registry value | value | comment |
|----------------|-------|---------|
| DisablePCE | 0 | 1 = disable PCE (processor performance-state control ?). Overrides `EnablePCE` from ACPI `PGPC`. When PCE is enabled, the PEP reports P-state support to the kernel and starts the CPU clock thread |
| DisableAVS | 0 | 1 = disable AVS (adaptive voltage scaling). Overrides `EnableAVS` from ACPI `PGPC` |
| DisablePXO | 0 | 1 = permanent NPA request on the PXO resource (no PXO shutdown in idle) |
| DisableCpuVdd | 0 | Bit mask of CPUs (bit 0 = CPU0, bit 1 = CPU1) whose `/core%d/cpu/vdd` power collapse is disabled |
| DisableVddMin | 0 | 1 = permanent request of 1100 on `/rail/vdd_dig` (no VDD minimisation) |
| DisableL2Collapse | 0 | 1 = permanent request on `/core/l2cache` (no L2 power collapse) |
| EnableProcessorManagement | 1 | 0 = the processor notification callback isn't registered (no processor idle/perf management by the PEP) |
| EnableThermalMonitor | ? | Name present, never read |
| EnableVPPM | ? | Name present, never read |
| SkipGraphicsSetLatencyWorkAround | 0 | Read at start, never used |
| DisableRpmHalt | 0 | 1 = sets bit 0 of a mask sent to the RPM (sub_42D724) |
| ReadCPUPerfClock | 0 | Used by the processor perf code (sub_40FD30) |
| PxoPowerCollapseLedEnable | 0 | 1 = evaluate ACPI `PPLG` (not present in the Lumia 520 DSDT) |
| SystemLatencyFlags | 1 | Bits 0–3 → `dword_486C6C`, bit 31 → `byte_4CD277` (sleep latency options ?) |
| Saw2SpmPmicDly | −1 | When not −1, the 4 bytes are written into the SAW2/SPM PMIC delay configuration of the current CPU (sub_43B390) |
| DisablePxoCxoSplit | 1 | **Read from `Services\qcpmicapps\Parameters`**, not from `qcpep`. Sets bit 4 of the RPM mask (sub_42D724) |
| CxoD1VoteViaRPM | ? | Name present, never read |
| VoteUSBHS1Clk | 0 | 1 = permanently enable `cc_usb_hs1_hclk` at 60 MHz |
| VoteCFPBBusClk | 0 | 1 = permanent request of 130000 on `/clk/bus/cfpb` (client `Debugger_client2`) |
| EnableVrefBattTherm | 0 | 1 = sets bit 7 of PMIC register 0x204 (see [PMIC workarounds](#pmic-workarounds)) |
| DisableGPUDebouncing | 0 | Used when `\_SB.GPU0` registers (sub_40DCEC) |
| DisableSmbcWorkaround | 0 | 1 = skip the writes to PMIC register 0x206 |
| DisableBattIdThermalWorkaround | 0 | 1 = skip the writes to PMIC register 0x204 |

`DisablePXO`, `DisableCpuVdd`, `DisableVddMin`, `DisableL2Collapse`, `DisableRpmHalt` and `SystemLatencyFlags` are packed into a 16-byte block (mask `0x3F`, CPU mask, flags, latency flags) and applied by sub_40A2E4 as NPA requests, at passive level or through a work item.

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcpep\PowerSettings`: opened by sub_410358 (processor notification 17) and handed to the kernel; the driver itself reads no value from it.

The driver writes `~MHz` (REG_DWORD) in `HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System\CentralProcessor\<n>` (sub_412C08), with the CPU frequency computed from the `cc_apcs_c%d_clk` clock configuration.

GUID of the ETW providers (`EtwRegister`):  
`{878B6F92-11BE-472A-9CE4-022003CD8B2D}` (PEP)  
`{2010E0B6-79DB-4C4A-9CCE-7AB31EFBCA97}`  
`{C2EF64A6-79C9-462E-849F-33C76FAC759B}` PEP_PPP (registered when the first VREG PPP client registers)  
`{1A01E46E-E48A-4C7E-908C-E84F193B44CE}` PMIC_KMDF, the same GUID as the provider of [qcpmic8930.sys](./qcpmic8930.md) (shared source code)

WPP control GUIDs (5 control blocks, sub_407F74):  
`{A577097E-09A7-43CA-A409-685F78C4EFB7}`  
`{C691B07D-95D1-490A-8F1B-E097009C3A92}`  
`{81A1D6F4-09EE-4E92-BD91-909811AAB5FA}`  
`{2509A187-E1F4-44B4-B622-4B91A433EA7F}`  
`{31C52625-F3DA-48EE-9735-25B85B06516F}`  

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of `\_SB.PEP0` | acpi.sys | `IOCTL_ACPI_EVAL_METHOD` (0x32C004) on `DVMM`, `PGEC`, `PGDC`, `PGCC`, `PGDS`, `PGPC`, `PPLG`, `NPUR`, see [ACPI](#acpi) |
| Interface `{10542F20-9718-452A-897A-45785468E57A}` | ADC driver ? (not documented yet) | ADC channels `BATT_THERM` and `PA_THERM`, IOCTLs `IOCTL_ADC_GET_CHANNEL` (0x8ADC2000) / `IOCTL_ADC_READ` (0x8ADC2004) (same as [NokiaEnergyDriver.sys](./nokiaenergydriver.md#adc-channels)) |
| Interface `{A5B9E9A8-EE02-46DC-B9EF-562A78C3E5C9}` | [qcpmic8930.sys](./qcpmic8930.md) | VREG (`0x8006xxxx`) |
| Interface `{5186FCEA-68FC-420A-9400-601A6D0CA988}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC GPIO (`0x8003xxxx`) |
| Interface `{EF512E80-3E93-45D7-AF9D-D375D53596B8}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC MPP (`0x8005xxxx`) |
| Interface `{D87538A4-32C4-46D8-985E-F7CA7731BA27}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC LED (`0x800Fxxxx`) |
| Interface `{CF19BFD2-31C2-47FC-A334-B78F00A8292D}` | [qcpmic8930.sys](./qcpmic8930.md) | PMIC hardware (`0x8015xxxx`) |
| RPM | RPM firmware | Message RAM at physical `0x00108000`, see [Physical memory](#physical-memory) |

The PMIC interfaces are found with `IoRegisterPlugPlayNotification`, then opened with `IoGetDeviceObjectPointer` on the symbolic link of the arrived interface (`PmicGetDeviceObjectByName`). The requests are sent with `IoBuildDeviceIoControlRequest` and a timeout (`PmicSendDriverRequestWithTimeout`).

> [!NOTE]
> The surprise-removal callbacks of the PEP and thermal-zone devices (sub_4D2DD0, sub_407A8C) call `KeBugCheckEx(0x14E, 0x51706530 'Qpe0', 0, 0, 0)`.

---

### PoFx registration

At start (sub_40D958, called from the `QCOM0811` device add) the driver:
1. Registers the ETW providers, reads the registry, maps the hardware, initialises the clock regime, NPA, RPM, sleep, ICB.
2. Evaluates the ACPI configuration methods (sub_402F84).
3. Calls `PoFxRegisterPlugin` with `PEP_INFORMATION` version 2:
   * `AcceptDeviceNotification` = sub_40DBC8. Dispatch table at `.data:0x0049ECA8` (pairs id/handler, ids 0–23).
   * `AcceptProcessorNotification` = sub_40F860 (only when `EnableProcessorManagement` = 1). Dispatch table at `.data:0x004A20B0` (ids 0–17).
4. Stores the kernel callbacks returned in `PEP_KERNEL_INFORMATION` (version 1, 28 bytes); all six must be non-NULL, otherwise `STATUS_INVALID_PARAMETER`.

Device notifications handled:  
| Id | Handler | Comment |
|----|---------|---------|
| 1 | sub_40DC40 | Prepare device ? |
| 2 | sub_40DCA0 | Abandon device ? |
| 3 | sub_40DCEC | Register device. Special cases `\_SB.SDC1`, `\_SB.SDC3` and `\_SB.GPU0` (`DisableGPUDebouncing`) |
| 4 | sub_40DFBC | Unregister device ? |
| 5 | sub_40835C | Device power state (`PepDevicePowerStateWork`, `PEP_DState_Mgmt.c`) |
| 7 | — | Accepted, nothing done |
| 13 | sub_40DFD4 | Component state change, applies the `DCFG` resources (clock regime) |
| 14 | sub_40ECB4 | Component state change, applies the `DCFG` resources (clock regime) |
| 15 | sub_40EE94 | ? |
| 16 | sub_40E340 | ? |
| 19 | sub_409C48 | ? |
| 21 | sub_40E288 | Register debugger: NPA clients `Debugger_client` on `/clk/bus/dfab` and `Debugger_client2` on `/clk/bus/cfpb`, clock `cc_usb_hs1_hclk` |

Processor notifications handled:  
| Id | Handler | Comment |
|----|---------|---------|
| 1 | sub_40F8D4 | Query capabilities: 2 feedback counters ?, 6 idle states ?, performance states supported = PCE enabled. Applies `Saw2SpmPmicDly`, starts the PCE clock thread |
| 2 | sub_40A6E0 | Query idle states |
| 3 | sub_40A924 | Idle select (`PepIdleSelect`, sleep solver) |
| 4 | sub_40B218 | Idle cancel |
| 5 | sub_40B320 | Idle execute (enter/exit the LPRMs) |
| 6, 7, 8 | sub_40B4CC, sub_40B4D8, sub_40B558 | ? |
| 9, 10 | sub_40F9C4, sub_40FAC0 | Feedback counters ? |
| 11 | sub_40FB54 | Query perf capabilities (`PepQueryPerfCapabilities`) |
| 12 | sub_4103D4 | Perf constraints / set ? (`cc_apcs_c%d_clk`, `cc_apcs_l2_clk`) |
| 13 | sub_410180 | ? |
| 16 | sub_40A6C8 | ? |
| 17 | sub_410358 | Opens `Services\qcpep\PowerSettings` |

The ids follow `pepfx.h`; the names with "?" are guesses.

Low power modes (LPRM) defined for the sleep solver (strings at `.rdata:0x0044DF10`…): `rpm.handshake`, `cpu_vdd0/1.power_collapse`, `cpu_vdd0.power_collapse_rpmhs`, `cpu_vdd1.power_collapse_ni`, `swfi_core0/1.clk_gate_with_ramp`, `l2_cache.retention/no_retention`, `pxo.shutdown`, `cxo.shutdown`, `vdd_dig.min_level_0`, `vdd_dig_svs.svs_min_level/svs_nom_level`, `mpm_warmup`, `mpm_rampup`, `rpm_batch.send_handshake`. The solver also contains a path to a `sleep_config.ini` (`/nv/item_files/sleep/core%d/sleep_config.ini`) inherited from the modem code.

---

### ACPI

The methods are evaluated on the `\_SB.PEP0` node with `IOCTL_ACPI_EVAL_METHOD` (sub_405CC0) into a 10 MB (0xA00000) pool buffer. The results are packages of strings/integers/sub-packages, parsed recursively.  
| Method | Lumia 520 | Comment |
|--------|-----------|---------|
| `DVMM` | absent | Parsed by sub_4028C4. Failure is ignored. The DSDT defines `FPMD` (empty package `FPDP`), which the driver never evaluates |
| `PGEC` | `ECFG` | Device configuration, same format as `DCFG`. Optional |
| `PGDC` | `DCFG` | Device power configuration (28 devices), sub_4031A8 |
| `PGCC` | `CCFG` | Processor list: device path or ID → id `0x10` (CPU0), `0x11` (CPU1), `1` (`VEN_QCOM&DEV_1001…`) |
| `PGDS` | `DCVS` | DCVS per CPU/L2: `CPU0` 0, `CPU1` 0, `L2` 0 |
| `PGPC` | `PPPC` | PEP options: `EnablePCE` 1, `EnableAVS` 0. The registry values `DisablePCE` / `DisableAVS` are applied afterwards and win |
| `PPLG` | absent | Only when `PxoPowerCollapseLedEnable` ≠ 0 |
| `NPUR` | present | Evaluated by the passive cooling callback, see [Thermal cooling interface](#thermal-cooling-interface) |

`DCFG` entries are `"DEVICE"`, path, then `"COMPONENT"` packages (`"FSTATE"`, `"PSTATE"`, `"PSTATE_SET"`) and `"DSTATE"` packages. Each state lists resources to apply. Resource keywords recognised by the driver (`.rdata:0x004481E8`…): `TLMMGPIO`, `PMICGPIO`, `PMICMPP`, `PMICVREGVOTE`, `BUSARB`, `BUSCONF`, `REQUIRED_RESOURCE`, `INTLATENCY`, `WAKEUPREQ`, `AXICONFIG`, `AXICHALT`, `FOOTSWITCH`, `EXECUTE_FUNCTION`, `TLMMPORT`, `DISCRETE_VREGVOTE`, plus `CLOCK`. Example from the DSDT (`\_SB.ADC1`, component 0):
```
Package { "PSTATE", 0, Package { "PMICVREGVOTE", Package { "PM_VREG_RESOURCE_ID_CXO_CLOCK", 7, 1 } } }
```
Devices described in `DCFG` on the Lumia 520: `ADC1`, `PRXY`, `SDF1`, `SDC1`, `SDC3`, `GSBI`, `I2C3`, `I2C9`, `IC12`, `CAMS`, `CAMP`, `CAMG`, `VFE0`, `VPE`, `TCH1`, `ACHW`, `MBHC`, `MBGP`, `ADSP`, `RIVA`, `AMSS`, `QQCE`, `QCE2`, `SLM1`, `SMMU`, `GPU0` (+ `ECFG`: `ACC1`, `ALS1`, `PRX1`, `ALS2`, `PRX2`, `NRSD`).

`\_SB.PEP0` `_CRS` declares 5 interrupts: 51, 52, 53, 54 and 210 (0x33–0x36, 0xD2). Their use by the driver is not identified.

---

### PMIC requests

`PMICVREGVOTE`, `PMICGPIO`, `PMICMPP` … resources are turned into PMIC IOCTL codes and dispatched internally by `pm_send_msg` (sub_42EA68) → `HandleIoCtlRequest` (sub_42F53C) on the device type:  
| Device type | Handler | Interface |
|-------------|---------|-----------|
| 0x8003 | `HandlePmicGpioRequest` (sub_430930) | GPIO `{5186FCEA-…}` |
| 0x8005 | `HandlePmicMppRequest` (sub_430C54) | MPP `{EF512E80-…}` |
| 0x8006 | `HandlePmicVregRequest` (sub_42FDC4) | VREG `{A5B9E9A8-…}` |
| 0x800F | `HandlePmicLedRequest` (sub_430F78) | LED `{D87538A4-…}` |
| 0x8015 | `HandlePmicHardwareRequest` (sub_43113C) | Hardware `{CF19BFD2-…}` |
| other | — | `STATUS_INVALID_DEVICE_REQUEST` |

The `*_REGISTER` code of a block (0x80030FB8, 0x80050FC4, 0x80060FD8, 0x800F0FC8, 0x80150FA0) only registers the PnP notification for its interface. The `*_UNREGISTER` code (0x80030FBC, 0x80050FC8, 0x80060FDC, 0x800F0FCC, 0x80150FA4) removes it. Every other code is forwarded to [qcpmic8930.sys](./qcpmic8930.md); the buffer layouts are in that page. When the interface hasn't arrived yet: `STATUS_INVALID_HANDLE` (0xC0000008, "Not a registered … PPP client").

VREG specifics (`HandlePmicVregRequest`):
* `IOCTL_PM_BEGIN_SEQUENCE` (0x80060FA0) / `IOCTL_PM_END_SEQUENCE` (0x80060FA4) are handled locally (sub_4303D8 / sub_430490): they bracket a batch of votes.
* `IOCTL_PM_VREG_VOTE_FOR_POWER_SETTINGS` (0x80060FD4): the resource id is input dword `04-07`. LDO16, LDO19, LDO26 and LDO27 (ids 23, 26, 33, 34) are routed to qcpmic8930. Id 0x7FFFFFFF is ignored. All other resources are sent **to the RPM** (sub_430548, `MapVRegPppToRpmResourceId_Pm8038_01` / `_Pm8921_01`).

Names of the VREG resources (`PM_VREG_RESOURCE_ID_*`, table at `.rdata:0x00452770`, 0x38 bytes per entry, id at `+0x34`): SMPS1–8 (0–7), LDO1–29 (8–36), LVS1–7, MVS1–2, NCP, CXO_BUFFERS, CXO_CLOCK, VDDCX_CORNER, DV1–5.

#### PMIC workarounds

sub_42EEC4 writes PMIC registers directly through the driver's own SSBI code (sub_42F8EC: read-modify-write with a mask, PMIC 0 or 1):  
| Register | Mask | Values | Condition |
|----------|------|--------|-----------|
| 0x206 | 0xFF | 0xD1, 0xD0 (on) / 0xD1, 0xD3, 0xD1, 0xD5, 200 µs, 0xD1, 0xD0, 40 µs, 0xD1, 0xD3 (off) | Skipped when `DisableSmbcWorkaround` = 1 (SMBC = charger block) |
| 0x204 | 0x80 | 0x80 when `EnableVrefBattTherm` = 1, else 0 (on); 0x80 (off) | Skipped when `DisableBattIdThermalWorkaround` = 1 |

---

### Physical memory

Regions mapped with `MmMapIoSpace` (non-cached):  
| Address | Size | Function | Comment |
|---------|------|----------|---------|
| 0x00108000 | 0x4000 | sub_42CD4C | RPM message RAM |
| 0x0010DB00 | 0x9C | sub_4361C4 | ? (MPM ?) |
| 0x0010DD04 | 0x34 | sub_4361C4 | ? |
| 0x00700000 | 0x8000 | sub_4D3F30 | QFPROM (TSENS calibration fuses ?) |
| 0x00800000 | 0x4000 / 0x2154 | sub_4289C4, sub_42E7B4 | TLMM (GPIO) |
| 0x00900000 | 0x4000 | sub_4D3F30 | Clock controller (GCC), TSENS registers |
| 0x02000000 | 0x1000 | sub_41342C | QGIC distributor ? |
| 0x0200A000 | 0x1000 | sub_43AE8C | ? |
| 0x02011000 | ? | sub_42CD4C | APCS GCC (IPC interrupt to the RPM ?) |
| 0x02012000 | 0x1000 | sub_43AE8C | L2 SAW2 (SPM) |
| 0x02089000, 0x02099000 | 0x1000 each | sub_43AE8C | CPU0 / CPU1 SAW2 (SPM) |
| 0x04000008 | 4 | sub_40D7E0 | One register, bit 26 is set at start ? |

Others come from the clock/AVS property tables (sub_433DDC, sub_414C0C, sub_41272C).

### Clock descriptors

Each clock of the clock regime has a descriptor (name, function table, register table, id). The register table gives offsets in the clock controller (physical base 0x00900000) as (offset, mask) pairs: branch enable, branch enable (repeated, vote ?), halt status, then two pairs in the clock control register (reset ? / hardware control ?).  
Clocks also driven directly by other drivers:  
| Clock | Descriptor | Register table | Enable | Halt status | Other pairs | Also written by |
|-------|------------|----------------|--------|-------------|-------------|-----------------|
| `cc_ce1_hclk` | 0x4B1B10 | 0x4B1910 | 0x2720, 0x10 | 0x2FD4, 0x2 | 0x2720 0x20, 0x2720 0x80 | — ([qcearm8930.sys](./qcearm8930.md) maps the clock controller but never uses it) |
| `cc_ce1_core_clk` | 0x4B17D0 | 0x4B17A8 | 0x2724, 0x10 | 0x2FD4, 0x08000000 | 0x2724 0x20, 0x2724 0x80 | — |
| `cc_ce2_hclk` | 0x4B2190 | 0x4B20F8 | 0x2740, 0x10 | 0x2FD4, 0x1 | 0x2740 0x20, 0x2740 0x80 | [qce2arm8930.sys](./qce2arm8930.md#clocks) |
| `cc_ce2_core_clk` | 0x4B2350 | 0x4B22F8 | 0x2744, 0x10 | 0x2FD0, 0x10000000 | 0x2744 0x20, 0x2744 0x80 | [qce2arm8930.sys](./qce2arm8930.md#clocks) |
| `cc_prng_clk` | 0x4B28C0 | 0x4B2898 | 0x3080, 0x400 | 0x2FD8, 0x400 | 0x2E80 0x400, 0x2E80 0x1000 | [qcerng8930.sys](./qcerng8930.md#clock) |

The enable register of `cc_prng_clk` (0x3080, `SC0_U_CLK_BRANCH_ENA_VOTE` in the Linux `clock-8960.c`) is shared with other clock votes. qcerng8930.sys changes its bit with a read-modify-write that isn't synchronised with the PEP ?

---

### Thermal zones

All thermal-zone devices (and `QCOM0811`) have a device context with the zone index. The temperature is read with sub_4D3380:
* zones 0–9 (`QCOM2400`…`QCOM2409`): TSENS sensor `index` (sub_43C588, retried while `STATUS_PENDING`, with a 0.5 ms delay when the conversion isn't ready);
* zones 10–11 (`QCOM2152`, `QCOM2153`): ADC channel `PA_THERM` for both;
* `QCOM2154`: ADC channel `BATT_THERM`, polled by a WDF timer (its own code path, sub_4079FC / sub_407850).

The ADC readings use the interface `{10542F20-…}`: `IOCTL_ADC_GET_CHANNEL` (0x8ADC2000) with the name returns `00-03` = 1 when found, `04-07` = channel id. `IOCTL_ADC_READ` (0x8ADC2004) with the channel id returns 20 bytes, `00-03` = 1 when valid, `04-07` = temperature in °C.

The last temperature of each zone is cached in `dword_4CCBD0[2 × index]` (°C).

---

### IOCTL 0x294090 — IOCTL_THERMAL_READ_TEMPERATURE

This IOCTL is processed by Qcpep8930.sys (thermal-zone devices)

| Property | Value |
|----------|-------|
| Device | 0x29 (FILE_DEVICE_BATTERY) |
| Function | 0x24 (36) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| IOCTL_THERMAL_READ_TEMPERATURE | ≥ 12 | 4 |

Inputbuffer (`THERMAL_WAIT_READ`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `FF FF FF FF` | Timeout in ms, −1 = infinite |
| 04-07 | ? | LowTemperature, tenths of K |
| 08-0B | ? | HighTemperature, tenths of K |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. `62 0C 00 00` | Temperature in tenths of K, computed as 10 × (°C + 273) (3170 = 44 °C) |

Zones 0–11 (sub_4D3A80 → sub_4D38B4): if the temperature is outside [Low, High] the request completes at once. Otherwise it's kept pending with its deadline (`KeQuerySystemTime` + 10000 × Timeout) and completed by the TSENS threshold logic. A second pending request on the same zone gets `STATUS_INVALID_PARAMETER`. TSENS not initialised: `STATUS_IO_DEVICE_ERROR` (0xC0000185); sensor not enabled: `STATUS_DEVICE_DATA_ERROR` (0xC000009C).  
`QCOM2154` (sub_407580 → sub_4073FC): Timeout 0 = immediate read of `BATT_THERM`. Otherwise the request is pended until the polled temperature leaves the [Low, High] window (in °C). Low = −1 or High = −1 makes a one-sided wait; both −1 = `STATUS_INVALID_PARAMETER`. The Timeout value itself is ignored.

The other IOCTLs received by the thermal-zone devices are forwarded to the lower device (ACPI) with `WDF_REQUEST_SEND_OPTION_SEND_AND_FORGET`.

---

### IOCTL 0x2A4010

This IOCTL is processed by Qcpep8930.sys (thermal-zone devices `QCOM2400`…`QCOM2409`, `QCOM2152`, `QCOM2153`)

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x4 (4) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (read all TSENS temperatures) | 0 | ≥ 22 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | 0A 00 | Number of sensors (10) |
| 02-15 | e.g. `2C 00` × 10 | Temperature of TSENS 0–9 in °C, one WORD each |

Handler sub_4122A0: refreshes the 10 sensors, then copies the cache. Output buffer smaller than 22: `STATUS_BUFFER_OVERFLOW` (0x80000005). `BytesReturned` = 22.

---

### IOCTL 0x2A400C

This IOCTL is processed by Qcpep8930.sys (`\??\QCOM_PEPDriver`)

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x3 (3) |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| ? (hide device) | ≥ 1 | ≥ 1 |

Handler sub_4D2EA4: both buffers must be present (content ignored), otherwise `STATUS_INVALID_PARAMETER`. It calls `WdfDeviceSetDeviceState` with `DontDisplayInUI` = TRUE and completes with 0 bytes. Any other code: `STATUS_INVALID_DEVICE_REQUEST`.  
Reads on `\??\QCOM_PEPDriver` complete with no data. Writes complete successfully with all bytes "written", and the data is discarded.

---

### Thermal cooling interface

The `QCOM0811` device publishes `GUID_THERMAL_COOLING_INTERFACE` with `WdfDeviceAddQueryInterface` (sub_4D3C68): version 1, 28 bytes, no active cooling, passive cooling = sub_412534.  
`PassiveCooling(Context, Percentage)`: with 2 processors, Percentage = 100 → 0 processors to idle, otherwise 1. The value is stored in `dword_4CDFFC`, each processor is updated (sub_409FD8 / sub_40EB50), then `\_SB.PEP0.NPUR` is evaluated with the number as integer argument (`ACPI_EVAL_INPUT_BUFFER_SIMPLE_INTEGER`). `NPUR` stores it in `\_SB.AGR0._PUR` and notifies [acpipagr.sys](./acpipagr.md).  
No `_TZD` of the Lumia 520 lists `\_SB.PEP0`, so the thermal framework probably never calls this interface. `\_SB.PEP0.ROST` (written by `AGR0._OST`) is never read by the driver.

---

### Interface GUID

qcpep8930 device interface, `QCOM0811` device  
`{C3628C79-B891-413C-982F-D433E5215AD8}`

Device interface created by the first TSENS thermal zone (index 0)  
`{C5A3F341-E8A3-4579-9E09-DB61B3A39C1E}`

`GUID_THERMAL_COOLING_INTERFACE` (query interface of the `QCOM0811` device)  
`{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`

### Other GUID

ADC interface (awaited by `QCOM2154` and zones 10–11, see [NokiaEnergyDriver.sys](./nokiaenergydriver.md))  
`{10542F20-9718-452A-897A-45785468E57A}`

Interfaces of [qcpmic8930.sys](./qcpmic8930.md) used for the PPP requests: VREG `{A5B9E9A8-EE02-46DC-B9EF-562A78C3E5C9}`, GPIO `{5186FCEA-68FC-420A-9400-601A6D0CA988}`, MPP `{EF512E80-3E93-45D7-AF9D-D375D53596B8}`, LED `{D87538A4-32C4-46D8-985E-F7CA7731BA27}`, hardware `{CF19BFD2-31C2-47FC-A334-B78F00A8292D}`
