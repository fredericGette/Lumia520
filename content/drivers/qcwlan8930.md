## Qcwlan8930.sys

Wi-Fi miniport driver of the WCNSS (RIVA / WCN3660) WLAN core.  
It's an NDIS 6.30 Native 802.11 miniport (with Wi-Fi Direct ports) built from the Qualcomm "Prima" WLAN host stack: the layer names of the Linux driver are visible in the log strings (HDD, SME, CSR, PE/LIM, WDA, WDI, DXE, WPAL, VOS).  
The PDO is created by the WCN bus driver [qcwcn8930.sys](./qcwcn8930.md) (child 2, `ACPI\QCOM0E50` ?), which also loads and starts the WCNSS firmware. This driver only talks to the firmware:
- control path: the SMD channel `WLAN_CTRL` of [qcsmd8930.sys](./qcsmd8930.md) (WDI/HAL messages),
- data path: the DXE DMA engine of the WCNSS, through the memory and the two interrupts of its ACPI resources, and the `SMSM_APPS_STATE` bits of [qcsmsm8930.sys](./qcsmsm8930.md).

The MAC addresses are read from `C:\DPP\QCOM\WLAN.PROVISION`, the regulatory domain table from `REG_DOMAIN.PROVISION`, the CLPC calibration data from `WLAN_CLPC.PROVISION`, and the firmware configuration from `\SystemRoot\system32\cfg.dat`.  
It reads the LTE band from [qcltecoexmgr8930.sys](./qcltecoexmgr8930.md) to move a Wi-Fi Direct group owner away from the channels next to LTE bands 7, 40 and 41.  
A private control device `\Device\QcomWifi` gives access to factory test (FTM) commands, QoS, band, country code, tx power, versions, RSSI, rates and power save.  
The PDB path embedded in the binary is `E:\build_e\subtask\9BEBBF78_98\output\wlan\fre\qcwlan8930.pdb`.

Device name : `\Device\QcomWifi` (`NdisRegisterDeviceEx`, `sub_5ECD38`)  
Symbolic link : `\DosDevices\QcomWifi`  
SDDL : `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GRGWGX;;;WD)(A;;GRGWGX;;;RC)` (read/write for **Everyone**)  

ACPI node on the Lumia 520: `\_SB.RIVA.QWLN` ([qcwcn8930.sys](./qcwcn8930.md#lumia-520-acpi-node)). `wpalDeviceInit` (`sub_5367C8`) requires exactly 3 resources, which matches its `_CRS` (see [Hardware resources](#hardware-resources)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcwlan`  ?  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\<instance>` (network adapter key, read with `NdisReadConfiguration`)  

### Binary size

The file is 1,923,464 bytes, much bigger than the other drivers, but it does **not** embed the WCNSS firmware: the largest data item of the image is 0xC98 bytes, and no string names a firmware image (`.mdt`, `.mbn`, `.bin`). The firmware is loaded by [qcwcn8930.sys](./qcwcn8930.md); this driver only checks the version reported by the running firmware (`WCNSS WLAN version mismatch\nWCNSS reported %u.%u.%u.%u, but expected %u.%u.%u.%u`).

| Section | Size | Content |
|---------|------|---------|
| .text | 0x193000 | 4210 functions (0x139058 bytes of ARM code) + 0x4D6D4 bytes at 0x0054692C–0x00594000 which are mostly (0x49AF6 bytes) the 7058 log strings (4176 `printf` formats, `%s: %d: ...`) |
| .rdata | 0x1EDE0 | Constant data |
| .data | 0x29000 | Global state (partly uninitialized) |
| .pdata | 0x9000 | Exception unwind data |
| PAGE_FTM / PAGE / PAGE_DAT / INIT | 0x5000 / 0x9000 / 0x2000 / 0x2000 | Pageable factory test code, pageable code, configuration table, initialisation code |

The size comes from the full Prima 802.11 host stack running on the application processor (HDD, SME/CSR roaming and connection management, PE/LIM MAC state machine, WDA/WDI messaging, DXE data path, VOS abstraction) and from its verbose logging.  
The only "download" to the WCNSS is the NV calibration data, which is data and not code (`WDA_NVDownload_Start` / `WDI_NV_DOWNLOAD_REQ`): NV tables rate power settings, regulatory domains, default country, TPC power table, TPC PDADC offsets, RSSI channel offsets, RF calibration values, antenna path loss, packet type power limits, virtual rate (`get_nv_table` / `set_nv_table`), filled from the [provisioning files](#provisioning-files).

### Registry

All the values are read from the **adapter key** (`NdisOpenConfigurationEx`).

Values read by `hdd_ReadConfig` (`sub_5EDF6C`) from the table at `.rdata:0x005F3000` (185 entries of 36 bytes, called from `sub_5ED89C` during `MiniportInitializeEx`). Flags: 1 = required, 2 = clamp to min/max, 4 = use the default when out of range. All are REG_DWORD unless noted:  
| Registry value | Default | Min | Max | Comment |
|----------------|---------|-----|-----|---------|
| ftmMode | 0 | 0 | 2 | 1 = factory test mode (FTM, `.data:0x005DB960`), 2 = other test mode ? (`.data:0x005DB964`). When 0, the FTM code section is unlocked (`MmUnlockPagableImageSection`) |
| LogEnabledModule | 0x60 | 0 | 0xFFFFFFFF | Debug log modules mask (`.data:0x005B31C8`) |
| LogLevelMask | 0x106 | 0 | 0xFFFFFFFF | Debug log levels mask (`.data:0x005B31CC`) |
| gRTSThreshold | 2347 | 0 | 2347 | |
| gFragmentationThreshold | 8000 | 256 | 8000 | |
| CheckForHangTime | 5 | 0 | 5 | |
| gCalibration | 1 | 0 | 1 | |
| gCalibrationPeriod | 5 | 2 | 10 | |
| gOperatingChannel | 1 | 0 | 252 | |
| gShortSlotTimeEnabled | 1 | 0 | 1 | |
| g11dSupportEnabled | 1 | 0 | 1 | |
| gEnforce11dChannel | 0 | 0 | 1 | |
| gEnforceCountryCodeMatch | 0 | 0 | 1 | |
| gEnforceDefaultDomain | 0 | 0 | 1 | |
| gHeartbeat24 | 10 | 0 | 65535 | |
| gPowerUsage | `Mod` | | | REG_SZ (`Min`, `Mod`, `Max` ?) |
| gEnableImps | 1 | 0 | 1 | Idle mode power save |
| gImpsMinSleepTime / gImpsMaxSleepTime / gImpsModSleepTime | 5 / 0 / 0 | 1 / 10 / 5 | 65535 | |
| gEnableBmps | 1 | 0 | 1 | Beacon mode power save. See [IOCTL 0x122084](#ioctl-0x122084) |
| gBmpsMinListenInterval / gBmpsMaxListenInterval / gBmpsModListenInterval | 1 | 1 | 65535 | |
| gEnableAutoBmpsTimer_INTERNAL | 1 | 0 | 1 | |
| gAutoBmpsTimerValue | 3000 | 1000 | 0xFFFFFFFF | ms |
| gDot11Mode | 0 | 0 | 7 | |
| gChannelBondingMode24GHz / gChannelBondingMode5GHz | 0 | 0 | 4 | |
| gMaxRxAmpduFactor | 3 | 0 | 3 | |
| gFixedRate | 0 | 0 | 31 | |
| gShortGI20Mhz / gShortGI40Mhz | 1 | 0 | 1 | |
| g11bNicState / g11gNicState / g11aNicState / g11nNicState | 1 | 0 | 1 | Also written back by the driver (`sub_427F60`) |
| gBlockAckAutoSetup | 1 | 0 | 1 | |
| gScanResultAgeCount | 3 | 2 | 100 | |
| gScanResultAgeNCNPS / gScanResultAgeNCPS / gScanResultAgeCNPS / gScanResultAgeCPS | 600 / 600 / 750 / 3000 | 10 | 10000 | |
| gRssiCatGap | 30 | 10 | 100 | |
| gStatTimerInterval | 500 | 50 | 10000 | |
| gShortPreamble | 1 | 0 | 1 | |
| gAutoIbssBssid | 1 | 0 | 1 | |
| gIbssBssid | `000AF5040506` | | | REG_SZ, MAC address |
| gEnableApProt / gApProtection / gEnableApOBSSProt | 1 / – / 0 | | | |
| gEnableWlanLteCoex | 1 | 0 | 1 | See [LTE coexistence](#lte-coexistence) |
| coexBand2370-2350-2300 | 0x003F000F | 0 | 0xFFFFFFFF | Channel masks avoided for the LTE band 40 sub-bands ? |
| coexBand2690-2400-2370 | 0x3E0001FF | 0 | 0xFFFFFFFF | Idem for 2370–2690 MHz ? |
| gBeaconInterval | 100 | 0 | 65535 | |
| gEnableHandoff | 1 | 0 | 1 | |
| gRssi… / gNumCandidateSet… / gBgScan… / gPer… / gPmk… (Nt, Nrt, Rt) | | | | 46 roaming / handoff parameters, see the table in the binary |
| gEnableIdleScan | 0 | 0 | 1 | |
| gRoamingTime | 10 | 0 | 4294967 | |
| gPassive/ActiveMin/MaxChannelTime (and …Btc, …Conc) | | 0 | 10000 | Scan dwell times (ms): passive 60–110, active 40–60, active with BT 60–120 |
| gMaxPsPoll | 0 | 0 | 255 | |
| gTxPowerCap | 128 | 0 | 128 | |
| gNumRxAnt | 2 | 1 | 2 | |
| gEnableFWHeartBeatMonitoring / gEnableFWBeaconFiltering | 1 | 0 | 1 | |
| gBuiltinWlanSlotNum | 255 | 0 | 255 | |
| b19p2MhzPmicClkEnabled | 0 | 0 | 1 | |
| btcStaticLenLeWlan / btcStaticLenLeBt | 0 / 10000 | 0 / 5000 | 500000 | Bluetooth coexistence |
| \*PacketCoalescing | 0 | 0 | 1 | Standard keyword |
| gFtEnabled, gNeighbor… | | | | 802.11r / 802.11k neighbour roaming. `gNeighborScanChannelList` REG_SZ `1,6` |
| gP2POperatingChannel / gP2PListenChannel | 6 / 6 | 1 | 252 / 11 | Wi-Fi Direct |
| gP2PPSSelection, gP2PPSCTWindow, gP2PNoA… | 0 | | | Wi-Fi Direct power save |
| gEnableLTECoex | 0 | 0 | 1 | Firmware LTE coexistence (`WNI_CFG_ENABLE_LTE_COEX`) |
| BandCapability | 0 | 0 | 2 | 0 = 2.4 + 5 GHz, 1 = 2.4 GHz, 2 = 5 GHz. See [IOCTL 0x12208C](#ioctl-0x12208c) |
| McastBcastFilter | 0 | 0 | 3 | |
| hostArpOffload | 0 | 0 | 1 | Uses `GetUnicastIpAddressTable` (NETIO) |
| gEnableDFSChnlScan | 1 | 0 | 1 | |
| gCountryCode | `FFF` | | | REG_SZ |
| FastRoamEnabled, FastTransitionEnabled, RoamRssiDiff, … | 0 | | | |
| gNumBuffAdvert | 64 | 0 | 128 | |

Other values:  
| Registry value | value | comment |
|----------------|-------|---------|
| ConfigFileName | e.g. `cfg.dat` | REG_SZ. File name, in `\SystemRoot\system32\`, of the firmware configuration (`hdd_getCfgFileName`, `sub_5EE2EC`). Default `\SystemRoot\system32\cfg.dat` |
| RegDomainFileName | | REG_SZ. Optional file replacing `REG_DOMAIN.PROVISION` (`vos_nv_readRegDomain`, `sub_5077E0`) |
| CLPCFileName | | REG_SZ. Optional file receiving the CLPC data instead of `WLAN_CLPC.PROVISION` (`sub_507F70`) |
| NetworkAddress | | Standard MAC address override (`NdisReadNetworkAddress`), used when it's a valid unicast address |
| WmmIsEnabled, 80211eEnabled, UapsdMask, MaxSpLength, InfraUapsd…, Infra…Ac… | | WMM / U-APSD / TSPEC parameters (`sub_411550`) |
| WfqBkWeight, WfqBeWeight, WfqViWeight, WfqVoWeight | 1, 2, 3, 4 | Weighted fair queuing weights (`sub_505B70`) |
| DelayedTriggerFrmInt | 3000 | (`sub_505B70`) |
| gWlanVersion, gSoftwareVersion, gHardwareVersion | e.g. `1.2.3.4` | REG_SZ, **written** by the driver (`VersionRegKeyWorkItem`, `sub_406628`): WCNSS versions, same strings as [IOCTL 0x122064](#ioctl-0x122064), [IOCTL 0x12205C](#ioctl-0x12205c), [IOCTL 0x122060](#ioctl-0x122060) |

`HKLM\System\CurrentControlSet\Control\ProductOptions` `ProductSuite` is read (`RtlQueryRegistryValuesEx`, `sub_53CC34`) to locate the DPP, see [Provisioning files](#provisioning-files).

GUID of the ETW provider (`EtwRegister` in `DriverEntry`):  
`{BB6F5B93-635C-47BE-816F-E895E77064A8}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Channel `WLAN_CTRL` (WDI control messages with the firmware), [internal IOCTL 0x22003](#internal-ioctl-0x22003) / [internal IOCTL 0x22007](#internal-ioctl-0x22007) |
| \Device\SMSM | [qcsmsm8930.sys](./qcsmsm8930.md) | [IOCTL 0x32000](#ioctl-0x32000): DXE bits of `SMSM_APPS_STATE` |
| Interface `{FDAE87E4-EB5F-48A9-ACF8-735C9C8DBD2E}`, reference string `WLAN` | [qcltecoexmgr8930.sys](./qcltecoexmgr8930.md) | `ReadFile` of the 24-byte LTE state, see [LTE coexistence](#lte-coexistence) |
| `\DosDevices\C:\DPP\` or `\Device\Harddisk%u\Partition%u\` | file system | Provisioning files, see [Provisioning files](#provisioning-files) |

### NDIS miniport

`DriverEntry` (`sub_5F5150` → `NdisMRegisterMiniportDriver`) registers an NDIS 6.30 miniport, driver version 0.2, with the characteristics built by `sub_5F5008`. The KMDF library is also bound (WDF I/O targets for SMD, SMSM and the LTE coexistence manager).  
| Handler | Function |
|---------|----------|
| SetOptionsHandler | `sub_409238` |
| InitializeHandlerEx | `sub_5ED120` |
| HaltHandlerEx | `sub_401D98` |
| UnloadHandler | `sub_5ED810` |
| PauseHandler / RestartHandler | `sub_407268` / `sub_40AAA8` |
| OidRequestHandler | `sub_4079DC` |
| SendNetBufferListsHandler | `sub_409E78` |
| ReturnNetBufferListsHandler | `sub_406F2C` |
| CancelSendHandler | `sub_40AA58` |
| DevicePnPEventNotifyHandler | `sub_40A8DC` (`WM_HDD_DevicePnPEventNotify`) |
| ShutdownHandlerEx | `sub_407054` |
| CancelOidRequestHandler | `sub_406EAC` |
| DirectOidRequestHandler / CancelDirectOidRequestHandler | `sub_4076BC` / `sub_406E44` |
| CheckForHangHandlerEx, ResetHandlerEx | none |

Besides the standard `OID_DOT11_*` / Wi-Fi Direct OIDs, the driver handles private OIDs whose names are in the log strings: `OID_WLAN_CUST_PNP_SET_POWER` (redirected to `OID_PNP_SET_POWER`), `OID_WLAN_CUST_WCM_ADAPTER_INFO`, `OID_WLAN_CUST_WPS_PROBE_REQUEST`, `OID_WLAN_CUST_WPS_ASSOCIATE`, and `OidWlanQctCustAddTspec`, `…DelTspec`, `…MdfyTspec`, `…LinkStatus`, `…SignalBtEvent`, `…WpsClearEnrollment` (OID values not extracted).

### Hardware resources

`wpalDeviceInit` (`sub_5367C8`) reads the translated resources (`NdisMGetDeviceProperty`) and fails if there aren't exactly 3:  
| Resource | Lumia 520 (`\_SB.RIVA.QWLN._CRS`) | Use |
|----------|-----------------------------------|-----|
| Memory | 0x03000000, 0x1000000 | WCNSS register space, mapped with `NdisMMapIoSpace`. A pointer to the physical address **0x03200B10** is computed in the mapping (kept at `+0xC` of the WPAL context `.data:0x005CBEA4`) ? |
| Interrupt 1 | 234 (Shared, Wake) | ISR `sub_535FD0`, DPC `sub_535F0C` (DXE TX/RX ?) |
| Interrupt 2 | 235 (Exclusive) | ISR `sub_535E54`, DPC `sub_536060` (DXE TX/RX ?) |

The interrupts are connected with `IoConnectInterruptEx` (`CONNECT_FULLY_SPECIFIED`, the lowest of the two IRQLs as synchronize IRQL, latched when the resource flag bit 0 is set). The same function opens the WDF I/O target on `\Device\SMSM`. Everything is released by `wpalDeviceClose` (`sub_536E04`).

### SMD channel

`WDI_Init` (`sub_51F3B0`) opens the control transport with `WCTS_OpenTransport("WLAN_CTRL", 0x1000, callbacks)` (`sub_5341D4`): a WDF I/O target on `\Device\SMD`, then [internal IOCTL 0x22003](#internal-ioctl-0x22003) sent asynchronously.  
| SMD channel | Edge | FIFO size | Flags | Content |
|-------------|------|-----------|-------|---------|
| `WLAN_CTRL` | 6 (APPS↔RIVA) | 4096 | 0x11 | WDI (HAL) request/response/indication messages with the WLAN firmware |

The data frames don't use SMD: they go through the DXE DMA rings of the WCNSS (`WLANDXE_*`).

### SMSM

`wpalNotifySmsm(clear, set)` (`sub_536F40`) sends [IOCTL 0x32000](#ioctl-0x32000) on `SMSM_APPS_STATE` (entry 0):  
| Caller | Clear mask | Set mask | Comment |
|--------|-----------|----------|---------|
| `WLANDXE_Open` (`sub_53B174`) | 0x400 | 0x200 | Clear `SMSM_WLAN_TX_ENABLE`, set `SMSM_WLAN_TX_RINGS_EMPTY` |
| `sub_539B24` (DXE TX ring state) | 0x400 and/or 0x200 | 0x400 and/or 0x200 | Toggles `SMSM_WLAN_TX_ENABLE` (0x400) to kick the RIVA, sets/clears `SMSM_WLAN_TX_RINGS_EMPTY` (0x200) ("SMSM Tx Ring Empty" / "Not Empty") |

### Provisioning files

The DPP is accessed by `sub_53CDB4` / `sub_53CE80` (size) / `sub_53D100` (read) / `sub_53D3A4` (write), like [qcbluetooth8930.sys](./qcbluetooth8930.md#bluetooth-address): when `ProductSuite` is `PhoneNT` the path is `\DosDevices\C:\DPP\QCOM\<file>`, otherwise the `DPP\` folder of a `\Device\Harddisk%u\Partition%u\` volume. Writes check a `FACTORY.FLG` file first ?  
| File | Use |
|------|-----|
| `QCOM\WLAN.PROVISION` | MAC addresses (`sub_5076D0`, `vos_nv_readMultiMacAddress`), must be ≥ 9 bytes. See below |
| `QCOM\REG_DOMAIN.PROVISION` | Country code → regulatory domain table (`vos_nv_readRegDomain`), ≤ 903 bytes: byte 0 = 1, u16 count, then `count` entries of 3 bytes (domain, 2-char country code). Replaced by the `RegDomainFileName` file when present. The built-in table (`.rdata:0x005F4A08`) is used otherwise |
| `QCOM\WLAN_CLPC.PROVISION` | Closed-loop power control NV data (28456 bytes), **written** by `sub_507F70` when the firmware updates the NV items (unless `CLPCFileName` redirects it) |
| `\SystemRoot\system32\wlanfw_macfw.bin` | Firmware file 0 of `vos_get_binary_blob` (`sub_50E980`) |
| `\SystemRoot\system32\cfg.dat` (`ConfigFileName`) | Firmware file 1: STA configuration downloaded to the firmware by `WDA_WniCfgDnld` (`sub_5107D4`) |
| `\SystemRoot\system32\wlan_country_info.dat` | Firmware file 2 |
| `\SystemRoot\system32\wlan_ho_config` | Firmware file 3 (handoff configuration ?) |

Content of `WLAN.PROVISION` (`sub_5ED89C`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Not checked |
| 02 | e.g. 01 | Number of MAC addresses |
| 03-08 | e.g. 00 1E 3A xx xx xx | First MAC address = adapter address |
| 09-… | | Up to 4 more MAC addresses (Wi-Fi Direct / session addresses). Missing ones are derived from the first one |

If the file is missing or too short, the `NetworkAddress` override is used, otherwise an error is logged ("No valid DPP or NetworkAddress key Override").

### LTE coexistence

At initialisation, `RegisterWlanLcmdInterface` (`sub_404274`) calls `IoRegisterPlugPlayNotification` on the interface class `{FDAE87E4-EB5F-48A9-ACF8-735C9C8DBD2E}`. The callback (`sub_40440C`) only accepts the interface whose reference string is `WLAN` and queues a work item (`sub_4047F8`) that opens a WDF I/O target on it and sends a read request (`sub_404954`, "Read Request sent to lcmd"). Each completed read (`sub_404BA8`) is re-sent, so the driver always waits for the next LTE state of [qcltecoexmgr8930.sys](./qcltecoexmgr8930.md#read).

The 24-byte state is interpreted with frequencies in **MHz**:  
| LTE frequency (UL or DL) | Band |
|--------------------------|------|
| 2300–2400 | 40 (2300–2350 → sub-band 0, 2350–2370 → sub-band 1, otherwise 2) |
| 2500–2570 | 41 |
| ≥ 2570 (minus half the bandwidth) | 41 |
| DL 2500–2570 | 7 |

Offset 0x14 (`connected_flag`) = 0 means "Lte is off". Then `WlanLteCoexInterfaceChangeChannel` (`sub_4050C0`) checks the operating channel of a Wi-Fi Direct group owner and, if it conflicts with the band, disconnects the peers, stops the BSS and restarts it on another channel.

### Control device

The dispatch routine `hdd_NICDispatch` (`sub_5EBB88`) is used for `IRP_MJ_CREATE`, `IRP_MJ_CLOSE`, `IRP_MJ_CLEANUP` (completed with `STATUS_SUCCESS`) and `IRP_MJ_DEVICE_CONTROL`.  
All IOCTLs are `METHOD_BUFFERED`: the same system buffer is used for input and output, and most handlers don't check its size. `Information` = InputBufferLength for 0x122050, 0x12205C, 0x122060, 0x122064 and 0x122080, the response length for 0x122040, 84 for 0x122090, the channel count for 0x122094, and 0 for the others. An unknown code returns `STATUS_UNSUCCESSFUL` (0xC0000001).

> [!NOTE]
> In FTM mode (`ftmMode`=1), only [IOCTL 0x122040](#ioctl-0x122040) is processed until the FTM state (`+0x54D0` of the adapter) is 3; the other IOCTLs are completed with `STATUS_SUCCESS` without doing anything.

> [!NOTE]
> The SDDL gives read/write access to everyone, and several handlers write a fixed amount of data without checking the buffer size ([IOCTL 0x122090](#ioctl-0x122090): 84 bytes, [IOCTL 0x122094](#ioctl-0x122094): up to 100 bytes).

---

### IOCTL 0x122040

This IOCTL is processed by Qcwlan8930.sys (`ftm_wlan_diag`, `sub_5E5008`)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x810 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| FTM diag command | n | n |

The buffer is a factory test (PTT) message, passed to `sub_5E7164` with its length; the response is written back in the same buffer and `Information` = response length.  
Not in FTM mode → `STATUS_NOT_SUPPORTED` (0xC00000BB) "Device not in FTM Mode". No FTM adapter → `STATUS_SUCCESS` with nothing done.

---

### IOCTL 0x122044

This IOCTL is processed by Qcwlan8930.sys (`HddWmmSetupQos`, `sub_410CE4`)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x811 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Add a TSPEC (WMM QoS flow) | ? | ? |

Allocates a QoS flow context, adds the TSPEC through SME (`sme_QosSetupReq`, `sub_4B64C4`) and inserts it into the flow list. The layout of the buffer wasn't analysed ?. The NTSTATUS stays `STATUS_SUCCESS`; the result is returned in the buffer.

---

### IOCTL 0x122048

This IOCTL is processed by Qcwlan8930.sys (`HddWmmDeleteQos`, `sub_411248`)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x812 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Delete a TSPEC | 8 | 8 |

Inputbuffer / Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Flow handle. It is dereferenced as a **kernel pointer** to the flow context (checked against the flow list by `sub_410AD0`) |
| 04-07 | e.g. 0D 00 00 00 | Output: 13 = deleted, 14/15/16 = SME failure or bad input |

---

### IOCTL 0x12204C

This IOCTL is processed by Qcwlan8930.sys (`HddWmmMdfyQos`, `sub_4113CC`)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x813 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Modify a TSPEC | ? | ? |

Same handle as [IOCTL 0x122048](#ioctl-0x122048) at offset 0, calls `sme_QosModifyReq` (`sub_4B6688`).

---

### IOCTL 0x122050

This IOCTL is processed by Qcwlan8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x814 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Manufacturing self test | ≥ 24 | ≥ 24 |

Inputbuffer / Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 or 02 00 00 00 | 1 = run the self test (`ftm_wlan_DoSelfTest`, `sub_5E7BC4`), 2 = query the result (`ftm_wlan_Query_SelfTest`, `sub_5E7AA8`). Other values → `STATUS_NOT_SUPPORTED` |
| 04-07 | ? | |
| 08-0B | 01 00 00 00 or 02 00 00 00 | Self test type |
| 0C-0F | ? | |
| 10 | 01 | Output of the query: 1 = passed |
| 14-17 | ? | Output of the query: type 1 → 0; type 2 → result >> 1 |

"Run" sends the PTT message 0x32CC (12 bytes) to the firmware (`sub_5E6C64`) and waits for the answer; the 16-bit result is kept at `+0x5508` of the adapter. "Query" with type 1 returns `(result & 1) == 0`, with type 2 `(result & 0x1FE) == 0`. Another self test type → `STATUS_NOT_SUPPORTED` (0xC00000BB).

---

### IOCTL 0x122054

This IOCTL is processed by Qcwlan8930.sys (`set_tx_power_cap`, `sub_403764`)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x815 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the maximum tx power | 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | e.g. 0F | Maximum tx power in dBm (signed) |

Calls `sme_SetMaxTxPower` (`sub_4C4D44`) with BSSID and self MAC `FF:FF:FF:FF:FF:FF` (all), which posts `WDA_SET_MAX_TX_POWER_REQ`. Failure → `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0x122058

This IOCTL is processed by Qcwlan8930.sys (`hdd_setCountryCode`, `sub_403838`)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x816 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the country code | 3 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-02 | e.g. `46 52 00` | Country code, ANSI (`FR`) |

Calls `sme_ChangeCountryCode` (`sub_4C3474`). On success, the country code is looked up in the regulatory domain table (`sub_506E4C`, world domain 3 when not found) and the domain is sent to the firmware with the PTT message 0x3023 (`hdd_PttSetRegDomain`, `sub_409418`). SME failure → `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0x12205C

This IOCTL is processed by Qcwlan8930.sys (`wlan_getRivaVersion`, `sub_4069B8`, type 1)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x817 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| WCNSS software version | ≥ 64 | ≥ 64 |

The buffer (InputBufferLength bytes) is zeroed, then receives the WCNSS software version string (`sub_4C374C`, ANSI, ≤ 64 bytes). InputBufferLength < 64, NULL buffer or SME error → `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0x122060

This IOCTL is processed by Qcwlan8930.sys (`wlan_getRivaVersion`, `sub_4069B8`, type 2)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x818 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| WCNSS hardware version | ≥ 64 | ≥ 64 |

Same as [IOCTL 0x12205C](#ioctl-0x12205c) with the WCNSS hardware version string (`sub_4C37C0`).

---

### IOCTL 0x122064

This IOCTL is processed by Qcwlan8930.sys (`wlan_getRivaVersion`, `sub_4069B8`, type 0)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x819 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| WCNSS WLAN version | ≥ 64 | ≥ 64 |

Same as [IOCTL 0x12205C](#ioctl-0x12205c). The "compiled" (`sub_4C366C`) and "reported" (`sub_4C36DC`) WCNSS WLAN versions (4 bytes each) are compared; if they match, the buffer receives `"%u.%u.%u.%u"` (major, minor, version, revision). A mismatch is only logged and the buffer stays zeroed (`STATUS_SUCCESS`).

---

### IOCTL 0x122080

This IOCTL is processed by Qcwlan8930.sys (`sub_406C8C`)

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x820 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get RSSI | 4 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 3C 00 00 00 | RSSI of the station of the default session (one byte from `sub_4FA2B8`, zero-extended; absolute value in dBm ?) |

No session, no station or no connection → `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0x122084

This IOCTL is processed by Qcwlan8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x821 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Enable / disable BMPS | 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | 00 or 01 | 0 = disable beacon mode power save (`sme_DisablePowerSave` then full power), 1 = enable it (`sme_EnablePowerSave` then BMPS), only if `gEnableBmps` is set |

Failures → `STATUS_UNSUCCESSFUL`.

---

### IOCTL 0x122088

This IOCTL is processed by Qcwlan8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x822 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the maximum packets indicated per RX loop | 1 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | e.g. 14 | Max packets indicated at once by the RX thread, clamped to 20 (`.data:0x005B31B0`) |

---

### IOCTL 0x12208C

This IOCTL is processed by Qcwlan8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x823 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Set the band | 4 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | 0 = 2.4 + 5 GHz, 1 = 2.4 GHz only, 2 = 5 GHz only. > 2 → `STATUS_UNSUCCESSFUL` |

If the value differs from the current band (`sub_4C4C34`): the running scan is aborted, every session is torn down (infrastructure: disconnect; group owner / AP: stop BSS; P2P device port: close session), then `sme_SetFreqBand` (`sub_4C4BD8`) applies the band.

---

### IOCTL 0x122090

This IOCTL is processed by Qcwlan8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x824 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Query the TX/RX rates | 0 | 84 (not checked) |

Outputbuffer (filled for the infrastructure session, after a statistics request to the firmware, 100 ms timeout):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00 | ? | RX rate index |
| 01 | ? | |
| 02-03 | ? | TX rate (internal value / 2, Mbps ?) |
| 04-53 | e.g. `802.11b 1Mbps Long preamble` | Name of the RX rate (table of 80-byte strings at `.rdata:0x005943C0`) |

`Information` = 84.

---

### IOCTL 0x122094

This IOCTL is processed by Qcwlan8930.sys

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x825 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get the valid channels | 0 | ≤ 100 (not checked) |

Outputbuffer: one byte per channel number (e.g. `01 02 03 … 0D`), from `sme_GetCfgValidChannels` (`sub_4C41A0`), filtered by `BandCapability` (1: 2.4 GHz channels only, 2: 5 GHz channels only). `Information` = number of channels.

---

### internal IOCTL 0x22003

This IOCTL is sent by Qcwlan8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) (`WCTS_OpenTransport`, `sub_5341D4`), asynchronously (`WdfRequestSend`).

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Open a SMD channel | \Device\SMD | 28 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to `"WLAN_CTRL"` |
| 04-07 | 06 00 00 00 | Edge APPS↔RIVA |
| 08-0B | 11 00 00 00 | Flags: 0x10 wait for the remote side + 0x01 |
| 0C-0F | 00 10 00 00 | FIFO size 4096 |
| 10-13 | 00 00 00 00 | No "data received" event |
| 14-17 | ? | `PKEVENT` set when the channel is opened (transport context +0x150) |
| 18-1B | ? | `PKEVENT` set on remote close (transport context +0x160) |

---

### internal IOCTL 0x22007

This IOCTL is sent by Qcwlan8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22007) (`sub_5346E0`) to close `WLAN_CTRL`.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Close a SMD channel | \Device\SMD | 0 | 0 |

---

### IOCTL 0x32000

This IOCTL is sent by Qcwlan8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x32000) (`wpalNotifySmsm`, `sub_536F40`), synchronously.

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| smsm_change_state | \Device\SMSM | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | `SMSM_APPS_STATE` |
| 04-07 | 00 04 00 00 | Clear mask (e.g. `SMSM_WLAN_TX_ENABLE`) |
| 08-0B | 00 02 00 00 | Set mask (e.g. `SMSM_WLAN_TX_RINGS_EMPTY`) |

See [SMSM](#smsm).

---

### Other GUID

LTE coexistence manager interface class, watched with `IoRegisterPlugPlayNotification` (reference string `WLAN`)  
`{FDAE87E4-EB5F-48A9-ACF8-735C9C8DBD2E}`
