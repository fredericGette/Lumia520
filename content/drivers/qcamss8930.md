## Qcamss8930.sys

AMSS (modem / MSS, QDSP6 "Q6FW" + "Q6SW") subsystem driver.  
It loads the two modem images (firmware, then software) through [qcpil8930.sys](./qcpil8930.md), waits for the modem to come up through [qcsmsm8930.sys](./qcsmsm8930.md), then publishes its device interface. It doesn't talk to the modem firmware itself, except for the thermal mitigation (QMI TMD, see [Passive cooling](#passive-cooling)).  
It handles the modem crashes (watchdog bites of the firmware and the software, fatal error signalled through SMSM): SubSystem Restart (SSR) when `RestartEnabled`=1, bug check otherwise.  
It's a client of the RPE notifier [qcrpen8930.sys](./qcrpen8930.md) (client name `AMSS`), and it doesn't load the modem before the ADSP is ready (RPE state of [qcadsp8930.sys](./qcadsp8930.md#rpe)).  
The PDB path embedded in the binary is `P:\AMSS\rel\8.2.1.1\arm\Release\qcamss8930.pdb`. Build date in the SSR log: `Mar 24 2014`.

There's no named device object and no symbolic link.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0E80\<instance>`

Registry values read from the **driver (software) key** of the device (`WdfDeviceOpenRegistryKey(PLUGPLAY_REGKEY_DRIVER, KEY_READ)` in `EvtDriverDeviceAdd`, `sub_416728`):  
| Registry value | value | comment |
|----------------|-------|---------|
| AmssFwImagePath | e.g. `\SystemRoot\system32\qcdsp1v18930.mbn` | REG_SZ. Modem **firmware** image (Q6FW), used when the chip version is lower than 2.0. Default `C:\Windows\System32\dsp1_v1.mbn`, with the warning "we will load the subsystem firmware image from the default path" in the logs. Context +0x4C |
| AmssFwImagePathV2 | ? | REG_SZ. Modem firmware image used when the chip version is 2.0 or higher. Default `C:\Windows\System32\dsp1_v2.mbn`. Context +0x50 |
| AmssSwImagePath | e.g. `\SystemRoot\system32\qcdsp28930.mbn` | REG_SZ. Modem **software** image (Q6SW). Default `C:\Windows\System32\dsp2.mbn`. Context +0x54 |

The example values are the files seen by [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c41241c--ioctl_pil_tz_load_image) on a Lumia 520.

Registry values read from `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters` (`WdfDriverOpenParametersRegistryKey`, desired access 0x1F0000, `sub_416728`):  
| Registry value | value | comment |
|----------------|-------|---------|
| RestartEnabled | 0x00=SSR disabled, 0x01=SSR enabled | REG_DWORD. 0 when the value is missing or the key can't be opened. Only the value 1 enables the SSR: with any other value, a modem crash bug checks the phone. Context +0xA0 |
| MaxRestartCount | 30 | REG_DWORD, default 30. Read only if RestartEnabled=1. Number of restarts allowed during one `RestartTimer` period. Context +0xA8 |
| RestartTimer | 300 | REG_DWORD, default 300 (5 hours), in minutes. Read only if RestartEnabled=1. Period of the timer `sub_405B94` that resets the restart count to 0. Context +0xAC |
| SSRLogFileEnabled | 0 or 1 | REG_DWORD, default 0. Read only if RestartEnabled=1. 1 = SSR events written to `C:\Data\SystemData\MPSS_SSR.log`, see [SSR log file](#ssr-log-file). Context +0x118 |

GUID of the ETW provider of the driver (`McGenEventRegister` in `DriverEntry`):  
`{732F0D3A-A9AE-4323-B4C7-5048FCB7E62C}`

GUID of the ETW provider of the RPE helper library (`McGenEventRegister` in `RpeInit`, same as in [qcadsp8930.sys](./qcadsp8930.md) and [qcwcn8930.sys](./qcwcn8930.md)):  
`{57E95397-C84E-4F53-9473-56207AAA5938}`

GUID of the ETW provider of the Sysmon library (`McGenEventRegister` in `SysmonInit`, `sub_40D7EC`, same as in [qcadsp8930.sys](./qcadsp8930.md#sysmon)):  
`{F6B68689-94AD-45B9-8160-3BCDEFFD6A3F}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| PIL interface `{E2EB84C1-4068-4994-A48F-F3AC0D38DC29}` | [qcpil8930.sys](./qcpil8930.md) | Peripheral Image Loader. Two I/O targets opened by the symbolic link of the interface: firmware (+0x1C) and software (+0x20). [IOCTL 0x9C41241C](#ioctl-0x9c41241c), [IOCTL 0x9C412410](#ioctl-0x9c412410), [IOCTL 0x9C412408](#ioctl-0x9c412408) |
| SMSM interface `{1C90923A-DF5C-4761-9FD0-835B80F5281D}` | [qcsmsm8930.sys](./qcsmsm8930.md) | Shared Memory State Machine. [internal IOCTL 0x32008](#internal-ioctl-0x32008), [internal IOCTL 0x32010](#internal-ioctl-0x32010), [IOCTL 0x3200C](#ioctl-0x3200c) |
| ChipInfo interface `{FB4F07CD-8D4C-4413-92C2-E2C9CAED9F43}` | [qcchipinfo8930.sys](./qcchipinfo8930.md) | [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004): chip version, selects the firmware image |
| \Device\SMEM | [qcsmem8930.sys](./qcsmem8930.md) | [internal IOCTL 0x42000](#internal-ioctl-0x42000): function table, used to read the crash reason `SMEM_SSR_REASON_MSS0` |
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Channel `sys_mon` on edge 0 ([internal IOCTL 0x22003](#internal-ioctl-0x22003)), see [Sysmon](#sysmon) |
| \Device\RPEN, Helper interface | [qcrpen8930.sys](./qcrpen8930.md) | See [RPE](#rpe) |
| \Device\IPC | [qcipcrouter8930.sys](./qcipcrouter8930.md) | QMI transport of the QMI client library: [IOCTL 0x122008](#ioctl-0x122008), [IOCTL 0x122017](#ioctl-0x122017), [IOCTL 0x12201B](#ioctl-0x12201b), read/write. Used for the QMI TMD service, see [Passive cooling](#passive-cooling) |
| \Device\QMUX | [qcqmux8930.sys](./qcqmux8930.md) | Second QMI transport of the library: [IOCTL 0x12418](#ioctl-0x12418), [IOCTL 0x12410](#ioctl-0x12410), [IOCTL 0x12430](#ioctl-0x12430) |
| ACPI node of the device (default I/O target) | [acpi.sys](./acpi.md) | [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method) `IOCTL_ACPI_EVAL_METHOD`, methods `CONF` and `VLMT` |
| Power framework (PEP) | [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state) | `PoFxPowerControl`, see [Power management](#power-management) |
| Thermal framework | ? | Query interface `GUID_THERMAL_COOLING_INTERFACE`, see [Passive cooling](#passive-cooling) |

There's no hardcoded physical address (no `MmMapIoSpace`).

### WDF setup

`EvtDriverDeviceAdd` (0x417874):
- PnP callbacks: `EvtDeviceD0Exit` (`sub_417448`), `EvtDevicePrepareHardware` (`sub_4175E0`), `EvtDeviceReleaseHardware` (`sub_417750`), `EvtDeviceSurpriseRemoval` (`sub_402484`, revokes the AMSS interface). `EvtCleanupCallback` of the device: `sub_41A9A4` (revokes the interface, unregisters the 4 PnP notifications, frees the crash reason, writes `AMSS_DEVICE_REMOVED` to the SSR log and closes it).
- Device context `AMSS_DEVICE_CONTEXT` (0x120 bytes), also saved in the global `gpDeviceContext` (`.data:0x00413FBC`), used by the RPE callbacks.
- `WdfDeviceSetStaticStopRemove(FALSE)` and `WdfDeviceSetDeviceState(NotDisableable = TRUE)`.
- Default sequential queue, not power managed, with `EvtIoDeviceControl` (`sub_4183D4`). It completes **every** request without looking at the code: `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) when the AMSS interface is published, 0xA0008100 otherwise. The driver has no IOCTL of its own.
- 3 wait-locks (`QmiInitLock` +0xF8, `InterfaceAccessLock` +0x2C, `StartSubSystemLock` +0x30), a spinlock (+0x34) and 2 notification events (+0xD4 SMD cleaned up, +0xE4 SMSM cleaned up, see [SubSystem Restart](#subsystem-restart)).
- Reads the registry (see above).
- `SetupInterrupt` (`sub_4036C0`) twice: interrupt context 1 (Q6FW) then 0 (Q6SW). ISR `sub_403FE0` (queues the DPC), DPC `sub_40405C` = watchdog bite, see [Crash handling](#crash-handling).
- `SetupRpe` (`sub_402F30`), see [RPE](#rpe).
- Reads the thermal levels (`sub_402BDC`, ACPI `VLMT`), see [Passive cooling](#passive-cooling).
- `RegisterRPEStateNotification` (`sub_4050E8`) on 3 RPE clients, see [RPE](#rpe).
- `SysmonInit` (`sub_40D7E0`), see [Sysmon](#sysmon).
- `SubscribeDeviceInterfaceClass` (`sub_416008`): `IoRegisterPlugPlayNotification` on 4 interfaces, all with the callback `sub_41A4F4` (it queues the work item `sub_418B74`): ChipInfo `{FB4F07CD-…}`, PIL `{E2EB84C1-…}`, SMSM `{1C90923A-…}` and SMEM `{54415E20-5FC4-4938-8958-31966F441C63}`.
- If `VLMT` was read: `WdfDeviceAddQueryInterface` `GUID_THERMAL_COOLING_INTERFACE`, see [Passive cooling](#passive-cooling). A failure is only logged.
- If RestartEnabled=1: opens the [SSR log file](#ssr-log-file) (when enabled) and creates the periodic WDF timer `sub_405B94` (period `RestartTimer` × 60000 ms), which sets the restart count back to 0 ("Resetting the restart count value from value = …"). If the timer can't be created or started: "Restart Timer is not running; the modem can be restarted unlimited times".

Any other failure of `EvtDriverDeviceAdd` is logged as "Failure in DeviceAdd will cause the AMSS subsystem to not be loaded and released from reset!" (and "… the ADSP subsystem …" after `SysmonInit`, copied from the ADSP driver).

`EvtDevicePrepareHardware` (`sub_4175E0`): registers the device with the power framework (`AmssRegisterPowerManager` = `sub_401FA0`, once) and queues a work item that tries to start the subsystem (`sub_40503C`).  
`EvtDeviceReleaseHardware` (`sub_417750`): `RpeClientDeinit` of the AMSS client, `RpeDeinit`, `PoFxUnregisterDevice`.  
`EvtDeviceD0Exit` (`sub_417448`): when the target state is `WdfPowerDeviceD3Final`, cancels the pending `SMSM_RESET` wait ([IOCTL 0x3200C](#ioctl-0x3200c)).

### Start of the subsystem

Prerequisites (flags of the device context):  
| Flag | Bit in "AMSS Bring up status flag" | Set by | Action |
|------|-----------------------------------|--------|--------|
| ChipInfo up (+0x08) | 0x200 | ChipInfo interface | Opens it, sends [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004), saves the chip version (+0x04) |
| PIL up (+0x0C) | 0x100 | PIL interface | Opens 2 I/O targets on it (firmware +0x1C, software +0x20). Query-remove callback `sub_4193C8`, remove-canceled `sub_419618` (reopen work item `sub_4185C0`), remove-complete `sub_41983C` |
| ADSP ready (+0x10) | 0x20 | RPE state 5 of the ADSP client (`sub_405208`) | "ADSP subsystem is up": queues the start work item |
| SMSM up (+0x14) | 0x80 | SMSM interface | Opens it (+0x60), gets the 2 function pointers ([0x32008](#internal-ioctl-0x32008) → +0x64, [0x32010](#internal-ioctl-0x32010) → +0x68), arms the 2 [0x3200C](#ioctl-0x3200c) waits (`SetupModemErrorNotification` = `sub_419A8C`, `SetupModemUpNotification` = `sub_419DDC`) |
| SMEM up (+0x18) | 0x40 | SMEM interface | `smem_init_driver` (`sub_40D68C`): opens `\Device\SMEM` and gets its function table ([internal IOCTL 0x42000](#internal-ioctl-0x42000)) |
| Power managed (+0x84), PoFx handle (+0x74), F0 (+0x78) | 0x10, 0x08, 0x04 | `AmssRegisterPowerManager`, `ComponentIdleStateCallback` | See [Power management](#power-management) |
| Images loaded (+0x80) | 0x02 | `LoadImageAndReleaseFromReset` | |
| Modem up (+0x88) | 0x01 | Modem up work item | |

A removal of one of these interfaces clears its flag and revokes the AMSS interface. A query-remove of the PIL or SMSM target does the same.

After each event, `sub_4048E0` ("Attempting to start subsystem") checks the flags. When the 5 interfaces are up but the component isn't in F0, it calls `PoFxActivateComponent` ("AMSS requested a transition to F0 state using PoFxActivateComponent"); the start goes on when F0 is reached. When all the prerequisites are set and the subsystem isn't started yet (+0x7C, `sub_404774`), `LoadImageAndReleaseFromReset` (`sub_416E7C`) runs once:
1. P0 (`TransitionPState(0)` = `sub_401814`).
2. Firmware: [IOCTL 0x9C41241C](#ioctl-0x9c41241c) with the client GUID `{BA58766D-…}`, the channel 5 and `AmssFwImagePath` (chip version < 2.0) or `AmssFwImagePathV2` (≥ 2.0) on the firmware target, then [IOCTL 0x9C412410](#ioctl-0x9c412410) on the same target. Logs "Loading FW image", "Successfully loaded AMSS firmware image".
3. Software: the same with the client GUID `{936DC601-…}`, the channel 4 and `AmssSwImagePath` on the software target. Logs "Loading SW image", "Successfully loaded AMSS software image".
4. Sets "images loaded" (+0x80). On any failure ("Unable to load the AMSS firmware image, subsystem will not be released from reset!", "Unable to reset the AMSS software hardware, …"), P1 and idle the component (`sub_405A6C`).

When the modem sets `SMSM_INIT` in `SMSM_MODEM_STATE` ([IOCTL 0x3200C](#ioctl-0x3200c), completion `sub_403D9C`), the work item `sub_4188F4` ("AMSS is up and running"):
1. writes `MODEM_UP` in the [SSR log file](#ssr-log-file), clears the "restart in progress" flag (+0x9C), sets "modem up" (+0x88),
2. publishes the [AMSS interface](#interface-guid),
3. sends the RPE state 5 `RPE_STATE_ID_READY_FOR_COMMANDS`,
4. goes to P1 and idles the component (`sub_405A6C`).

### Lumia 520 ACPI node

From the DSDT. The node is `\_SB.AMSS` (`_HID` `QCOM0E80`, no `_UID`), with `_DEP` on `\_SB.PMIC` only.
- `_CRS`: 2 interrupts `Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive)`, 67 (0x43) and 68 (0x44). The first created WDF interrupt (context 1) gets 67, the second (context 0) gets 68: 67 = Q6FW watchdog bite, 68 = Q6SW watchdog bite (same numbers as `Q6FW_WDOG_EXPIRED_IRQ` and `Q6SW_WDOG_EXPIRED_IRQ` of the Linux 8960 kernel).
- `CONF` returns `RMEM`, a package of 12 `{base, number of 4 KB pages}` pairs given to `RpeClientInitMultiSegment` for the crash dump (see also [qccdi8930.sys](./qccdi8930.md#lumia-520-acpi-nodes)):

| Base | Pages | Size | Comment |
|------|-------|------|---------|
| 0x89000000 | 0x4400 | 68 MB | Modem SW |
| 0x8D400000 | 0x600 | 6 MB | Modem FW |
| 0x2A000000 | 0x10 | 64 KB | ? |
| 0x2A03F000 | 0x1 | 4 KB | ? |
| 0x2E000000 | 0x30 | 192 KB | ? |
| 0x09000000 | 0x8 | 32 KB | ? |
| 0x09200000 | 0x8 | 32 KB | ? |
| 0x09400000 | 0x10 | 64 KB | ? |
| 0x00020000 | 0x24 | 144 KB | RPM ? |
| 0x00108000 | 0x6 | 24 KB | ? |
| 0x8FF00000 | 0x100 | 1 MB | ? |
| 0x01A01000 | 0x1 | 4 KB | ? |

- `VLMT` returns `Package (4) { {0x21, 3}, {0x42, 2}, {0x63, 1}, {0x64, 0} }`: thermal mitigation levels, see [Passive cooling](#passive-cooling).

### Interface GUID

AMSS device interface, published (`WdfDeviceCreateDeviceInterface` + `WdfDeviceSetDeviceInterfaceState`, `sub_416504`) when the modem is up, revoked on surprise removal, when the PIL or SMSM target goes away, and at cleanup:  
`{F2D900FD-4D9F-49A4-A025-6758D858CFD6}`  
Consumer: ? (not found in the other pages yet).

### RPE

`SetupRpe` (`sub_402F30`):
1. Evaluates the ACPI method `CONF` ([IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method), output buffer of 512 bytes, pool tag `qms5`). Each package argument (type 3) must contain 2 non-zero integers; they are copied into 16-byte segments `{base (8 bytes), pages (8 bytes)}` (pool tag `qms6`). If the method doesn't exist (`STATUS_OBJECT_NAME_NOT_FOUND`), the log says "No memory region data in the ACPI, the modem RAM will not be included in the crash dump files" and the client is registered without memory segment. A malformed package → `STATUS_ACPI_INVALID_DATA` (0xC014000F).
2. `RpeInit` (waits for the Helper interface `{59752ED7-B9D5-4121-818D-C69F1E667015}` of [qcrpen8930.sys](./qcrpen8930.md)), then `RpeClientInitMultiSegment` (`sub_40AFCC`) with the client GUID `{936DC601-5530-4B82-9D2A-72A488BEC7C1}` (hardcoded in the library), the name `AMSS`, the second string `1`, the memory segments and the callback table `{16 (size of the table), sub_4024E0, sub_4027CC, sub_4028D8}` (see the [RPE client record](./qcrpen8930.md#rpe-client-record)). Sets the "RPE client" flag (+0xF4).

The client GUID is also the GUID of the software image given to [qcpil8930.sys](./qcpil8930.md). The firmware image uses `{BA58766D-ABF2-4402-88D7-90AB243F6C77}`, which isn't an RPE client.

`RegisterRPEStateNotification` (`sub_4050E8`), all with the callback `sub_405208`:  
| Watched client | State | Action |
|----------------|-------|--------|
| ADSP `{D58464D3-5B28-4EA6-A2E2-E8E57C5C69B8}` ([qcadsp8930.sys](./qcadsp8930.md#rpe)) | 5 `RPE_STATE_ID_READY_FOR_COMMANDS` | Sets "ADSP ready" (+0x10) and queues the start work item. Log "Waiting for readiness of ADSP subsystem" at registration |
| SMD `{F9D15453-8335-434C-AA72-FCD925F135F3}` ([qcsmd8930.sys](./qcsmd8930.md)) | 4 `RPE_STATE_ID_RESTARTING` | `AmssSmdStateNotificationCallback` (`sub_40554C`): if an SSR is in progress (+0xD0 = 4), sets the event +0xD4 |
| SMSM `{1C90923A-DF5C-4761-9FD0-835B80F5281D}` ([qcsmsm8930.sys](./qcsmsm8930.md#rpe-clients)) | 4 `RPE_STATE_ID_RESTARTING` | `AmssSmsmStateNotificationCallback` (`sub_40570C`): if an SSR is in progress, sets the event +0xE4 |

States sent by the driver (`AmssRpeSendState` = `sub_4033F0`, record of 24 bytes: size, client GUID, state):  
| State | Name in the logs | When |
|-------|------------------|------|
| 4 | `RPE_STATE_ID_RESTARTING` | Start of an SSR (`sub_404424`) |
| 5 | `RPE_STATE_ID_READY_FOR_COMMANDS` | The modem is up and its interface is published |

These are the states watched by [qcbamdmux8930.sys](./qcbamdmux8930.md), qcsmd8930.sys and qcsmsm8930.sys to clean up their side of the shared memory.

Callbacks:  
| Index | Function | Comment |
|-------|----------|---------|
| [1] | `sub_4024E0` | "Apps state" callback. If the driver isn't an RPE client: "AMSS not a client of RPE, returning..." and returns 0. 7 = fatal error of the HLOS, sent by [qccdi8930.sys](./qccdi8930.md) before the crash dump ("Detected HLOS fatal error! Will halt subsystem and flush cache in preparation for crash dump..."): calls `FuncSmsmReset(0)` (sets `SMSM_RESET` in `SMSM_APPS_STATE`), then polls `smsm_state_get(SMSM_MODEM_STATE)` up to 1 600 000 times until the modem sets its own `SMSM_RESET` (0x40). Returns 1 when it does ("Detected AMSS assertion of the SMSM_RESET bit, will assume subsystem is halted and caches are flushed"), 0 on timeout ("WARNING: Timed out waiting for AMSS to assert its SMSM_RESET bit; subsystem may not have properly halted and flushed cache!"). Other states return 1 |
| [2] | `sub_4027CC` | Copies the last crash reason string (see [Crash handling](#crash-handling)) to the buffer given by the caller (`+0x10` size, `+0x14` string). "Crash reason: unknown" if there's none |
| [3] | `sub_4028D8` | Command callback. Only logs |

### Crash handling

A crash of the modem is detected in 2 ways:
- Watchdog bite: one of the 2 interrupts of the device (ISR `sub_403FE0`, DPC `sub_40405C`). The crash reason is "Q6FW (Modem Firmware) watch dog bite" (context 1, log "Detected Q6FW watch dog bite from the AMSS subsystem!") or "Q6SW (Modem Software) watch dog bite" (context 0).
- Fatal error: the modem sets `SMSM_RESET` in `SMSM_MODEM_STATE`, which completes the pending [IOCTL 0x3200C](#ioctl-0x3200c) (completion routine `sub_4038C4`). The driver reads `SMSM_MODEM_STATE` again (`smsm_state_get(1)`):
  - bit 0x40000000 (`SMSM_SYSTEM_PWRDWN_USR` in the Linux names) set: "Detected user initiated modem shutdown", nothing else is done (no restart, no bug check).
  - otherwise "Detected modem fatal error". The crash reason is read from the SMEM item 421 `SMEM_SSR_REASON_MSS0` (`smem_get_addr`). If the item doesn't exist or is empty, the driver **creates it** (`smem_alloc(421, 64)`) and writes the test string `TESTAMSSErrorReason` into it, then reads it back. The item is zeroed after the copy. Log "Error crash log (SMEM_SSR_REASON_MSS0): …".

In both cases the "modem up" flag (+0x88) is cleared.

The crash reason is saved in a pool buffer (tag `qmsc`, pointer at context +0x110):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | ? |
| 04-17 | 00 … | ? |
| 18-1B | e.g. 80 00 00 00 | Length of the string (128 for a watchdog bite, size of the SMEM item otherwise) |
| 1C-… | e.g. `Q6SW (Modem Software) watch dog bite` | Crash reason, ANSI |

Then:
- If RestartEnabled=1 and the restart count (+0xA4) is lower than MaxRestartCount: "Modem SSR enabled, restarting modem now", see [SubSystem Restart](#subsystem-restart).
- Otherwise, after the logs "The AMSS subsystem has crashed, please work with the AMSS triage team to continue debugging" and "Will bug check the HLOS on behalf of the AMSS subsystem (this is NOT an issue in the AMSS driver)", the SSR log file is closed and the driver calls `KeBugCheckEx(0x14B, &{0}, reason, 0, 0)`: bug check `SOC_SUBSYSTEM_FAILURE`, parameter 1 points to a DWORD 0 (`SOC_SUBSYS_WIRELESS_MODEM`), parameter 2 is the crash reason buffer.

### SubSystem Restart

Only with RestartEnabled=1. `sub_404310` queues the work item `AmssEvtProcessScheduleModemRestart` (`sub_404424`). If the images are loaded (+0x7C) and no restart is in progress ("AMSS is already in restarting..." otherwise):
1. Sets "restart in progress" (+0x9C), writes `MODEM_RESTARTING` and the crash reason in the [SSR log file](#ssr-log-file).
2. Increments the restart count (+0xA4) and the total number of restarts (+0xB4, shown in the bug check log), clears "images loaded" (+0x80), sets the SSR state +0xD0 = 4, clears the 2 cleanup events.
3. Sends the RPE state 4 `RPE_STATE_ID_RESTARTING`.
4. Queues `AmssEvtProcessModemRestart` (`sub_41A6F4`): waits up to 300 s for both events (SMD and SMSM in state 4, see [RPE](#rpe)): "Modem is waiting for SMD and SMSM to cleanup the shared memory". Then `PoFxActivateComponent` ("Component 0 being activated in preparation for AMSS restart...").
5. When the component reaches F0, the work item `sub_404EDC` sees the restart flag and calls `sub_404BCC` ("Attempting to restart subsystem"), which checks the same prerequisites as the start and calls `ReloadAmssAndReleaseFromReset` (`sub_41AB40`):
   1. P0,
   2. unloads the software image then the firmware image ([IOCTL 0x9C412408](#ioctl-0x9c412408), "Unloading SW image", "Unloading FW image"),
   3. re-arms the 2 SMSM waits ([IOCTL 0x3200C](#ioctl-0x3200c)),
   4. loads, authenticates and resets the firmware then the software image, exactly like at start ([IOCTL 0x9C41241C](#ioctl-0x9c41241c) + [IOCTL 0x9C412410](#ioctl-0x9c412410), not the reload IOCTL of the PIL): "Modem SW and HW images loaded".
6. The modem up notification then publishes the interface and sends the RPE state 5 again.

Any failure during the SSR (work item creation, RPE state, timeout of the cleanup, P0, unload, load, auth/reset, SMSM waits) goes to `AmssSSRFailBugcheck` (`sub_406054`): "AmssSSRFailBugcheck! Detected failure during Modem SSR", the crash reason becomes `"<failure>; status:0x<status>"` (e.g. `Timeout waiting for SMD and SMSM SSR cleanup; status:0x     102`), "Will bug check the HLOS on behalf of the AMSS subsystem; This is an issue during Modem SSR #<total restarts>", then the same bug check 0x14B with `SOC_SUBSYS_WIRELESS_MODEM`.

### SSR log file

When RestartEnabled=1 and SSRLogFileEnabled=1, `sub_405C94` opens `\DosDevices\C:\Data\SystemData\MPSS_SSR.log` (`ZwCreateFile`, `FILE_APPEND_DATA`, `FILE_OPEN_IF`, no sharing), handle at context +0x114. `sub_405D98` appends one line per event (at most 200 bytes):  
| Event | Line |
|-------|------|
| 0 | `Mar 24 2014 HH:MM:SS.0000mmm, MODEM_UP` |
| 1 | `Mar 24 2014 HH:MM:SS.0000mmm, MODEM_RESTARTING, Crash reason:<crash reason>` |
| 2 | `Mar 24 2014 HH:MM:SS.0000mmm, AMSS_DEVICE_REMOVED` |
| other | `… UNKNOWN_EVENT` |

The date is the **build date** of the driver (`__DATE__`), not the current date. The time comes from `KeQuerySystemTime` (UTC) and the milliseconds are printed with `%06d`. The file is closed before every bug check and at device cleanup.

### Power management

`AmssRegisterPowerManager` (`sub_401FA0`) calls `PoFxRegisterDevice` directly (it's not done by KMDF), then `PoFxActivateComponent(0)` and `PoFxStartDevicePowerManagement`. If it fails: "Registering AMSS for power management under PEP failed. AMSS is not power managed (subsystem won't be released from reset)!". `PO_FX_DEVICE` (pool tags `qms3`, `qms4`):  
| Field | Value |
|-------|-------|
| Version | 1 |
| ComponentCount | 1 |
| ComponentActiveConditionCallback | `sub_4016F8` (only logs) |
| ComponentIdleConditionCallback | `sub_401E28` (`PoFxCompleteIdleCondition`) |
| ComponentIdleStateCallback | `sub_401440`: F0 → flag +0x78 = 1 and queue the work item `sub_404EDC` (start, restart, or go to P1); F1 → flag = 0. Then `PoFxCompleteIdleState` |
| DevicePowerRequiredCallback | `sub_40173C` (`PoFxReportDevicePoweredOn`) |
| DevicePowerNotRequiredCallback | `sub_401E84` (`PoFxCompleteDevicePowerNotRequired`) |
| PowerControlCallback | `sub_401C4C`, see below |
| Component 0 Id | `{4355EB71-49E9-462D-9BD8-56E57FBE186D}` |
| Component 0 idle states | 2. F0: latency 0, residency 0, nominal power 500. F1: latency 2, residency 5, nominal power 50. DeepestWakeableIdleState = 1 |

The P-states of the modem are changed by `TransitionPState` (`sub_401814`) with `PoFxPowerControl`, same PowerControlCode and buffers as [qcadsp8930.sys](./qcadsp8930.md#power-management):  
PowerControlCode `{3404DAAC-8E2C-41E4-8458-3158E5AD442B}`  
Input (8 bytes, pool tag `qms2`): `00 00 00 00` (component 0 ?), then the P-state (0 = P0 before the images are loaded, 1 = P1 once the modem is up). Output (12 bytes, pool tag `qms1`): `00-03` = 3 `PEP_STATE_SYNC_PATH` (done) or 1 `PEP_STATE_ASYNC_PATH_IN_PROGRESS` (the driver waits up to 50 ms for an event, then returns). Any other value: "Change P state failed". A P-state ≥ 2 is refused, and nothing is sent while the component isn't in F0.  
For an asynchronous transition, the PEP calls `PowerControlCallback` with an output buffer whose first DWORD is 2: the driver sets the event and queues the work item `sub_41B530` ("Transitioned to P0. Since SS is up, start a WI to transition to P1."), which goes on with the start of the subsystem, or idles the component after a transition to P1.

### Passive cooling

`sub_402BDC` (called from `EvtDriverDeviceAdd`) evaluates the ACPI method `VLMT` ([IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method), output buffer of 512 bytes, pool tag `qms9`). Each argument must be a package of 2 integers: the first ones are copied into a byte array (WDFMEMORY, tag `qmsa`, context +0x104), the second ones into another (tag `qmsb`, +0x108), the count at +0x100. If the method doesn't exist: "No thermal mitigation level data found in ACPI, PassiveCooling requests will be ignored" (and the interface below isn't registered). Malformed package: "Error parsing ACPI data", `STATUS_ACPI_INVALID_DATA` (0xC014000F).

When `VLMT` was read, the driver registers a query interface for the thermal framework (`WdfDeviceAddQueryInterface`):  
`GUID_THERMAL_COOLING_INTERFACE` `{ECBE47A8-C498-4BB9-BD70-E867E0940D22}`  
| Field | Value |
|-------|-------|
| Size | 0x1C |
| Version | 1 |
| Context | WDFDEVICE |
| InterfaceReference / InterfaceDereference | `nullsub_1` (no-op) |
| Flags | 2 (`ThermalDeviceFlagPassiveCooling`) |
| ActiveCooling | NULL |
| PassiveCooling | `sub_40348C` |

`PassiveCooling(Context, Percentage)` (`sub_40348C`):
1. On the first call, initialises the QMI client (`AmssQmiInit` = `sub_402954`, under `QmiInitLock`): `qmi_client_notifier_init` for the service object at `.rdata:0x004113A8` (QMI service 0x18 = TMD, version 1, max message length 0x44B), waits up to 15 s for the service ("Timed out waiting for QMI_TMD"), `qmi_client_get_any_service`, `qmi_client_init`. The client handle is stored at context +0x10C. A failure is only logged ("AmssQmiInit failed").
2. Converts the percentage into a mitigation level: the first `VLMT` entry whose threshold is ≥ `Percentage` gives the level; above the last threshold, the level is 0. On the Lumia 520: ≤ 33 % → 3, ≤ 66 % → 2, ≤ 99 % → 1, 100 % → 0.
3. Sends `QMI_TMD_GET_MITIGATION_DEVICE_LIST` (0x0020, empty request, 0x450-byte response).
4. For every mitigation device whose name is exactly `pa` (power amplifier), sends `QMI_TMD_SET_MITIGATION_LEVEL` (0x0021) with the level, capped to the maximum level of the device.

Errors are only logged ("qmi_client_send_msg_sync unsuccessful", "QMI_TMD_GET_MITIGATION_DEVICE_LIST_REQ_V01 retured error code"). The function returns nothing to the thermal framework.

Decoded `QMI_TMD_GET_MITIGATION_DEVICE_LIST` response (C structure given to `qmi_client_send_msg_sync`, not the TLV encoding):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Result (0 = success) |
| 04-07 | 00 00 00 00 | Error |
| 08 | ? | List valid |
| 0C-0F | ? | Number of devices N |
| 10-30 | e.g. `pa` | Device 0: name (33 bytes, NUL terminated) |
| 31 | ? | Device 0: maximum mitigation level |
| 32-… | | Next devices, 34 bytes each (32 max) |

Decoded `QMI_TMD_SET_MITIGATION_LEVEL` request (34 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-20 | `pa` | Device name (33 bytes) |
| 21 | e.g. 03 | Mitigation level |

The response (8 bytes) is result + error.

The QMI client library (QCCI, functions `0x4061EC`–`0x40A5A4`) has two transports (`sub_4073E8`): one on the IPC router (ops table `.data:0x0041321C`) and six on QMUX (ops table `.data:0x00413230`, with the parameters 16 to 21, i.e. QMUX ports 0 to 5, see [IOCTL 0x12418](#ioctl-0x12418)). `qmi_client_get_any_service` asks all of them. The TMD service is looked up on the IPC router with [IOCTL 0x122008](#ioctl-0x122008).

### Sysmon

The Sysmon library (`SysmonInit` = `sub_40D7EC`) is the same as in [qcadsp8930.sys](./qcadsp8930.md#sysmon). It waits for the SMD interface `{F9D15453-8335-434C-AA72-FCD925F135F3}` (`sub_40DAD4`), then opens `\Device\SMD` and the channel `sys_mon` on edge 0 (APPS↔MODEM), see [internal IOCTL 0x22003](#internal-ioctl-0x22003).  
There's no Sysmon send function in the binary (only the allowed-message tables of the library are left): the channel is opened but never used.

---

### IOCTL 0x9C41241C

This IOCTL is sent by Qcamss8930.sys to [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c41241c--ioctl_pil_tz_load_image) (`LoadImageAndReleaseFromReset` = `sub_416E7C`, `ReloadAmssAndReleaseFromReset` = `sub_41AB40`), twice: on the firmware target, then on the software target. Synchronous (`sub_41A3CC`).

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x907 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_LOAD_IMAGE | PIL interface `{E2EB84C1-…}` | 540 | 4 |

Content of the input buffer for the firmware:  
| Bytes 00-0F | Bytes 10-13 | Bytes 14-21B |
|-------------|-------------|--------------|
| 6d 76 58 ba f2 ab 02 44 88 d7 90 ab 24 3f 6c 77 | 05 00 00 00 | Null terminated WCHAR string `AmssFwImagePath` or `AmssFwImagePathV2`, e.g. `\SystemRoot\system32\qcdsp1v18930.mbn` |

Content of the input buffer for the software:  
| Bytes 00-0F | Bytes 10-13 | Bytes 14-21B |
|-------------|-------------|--------------|
| 01 c6 6d 93 30 55 82 4b 9d 2a 72 a4 88 be c7 c1 | 04 00 00 00 | Null terminated WCHAR string `AmssSwImagePath`, e.g. `\SystemRoot\system32\qcdsp28930.mbn` |

The first 16 bytes are the GUID of the image: `{BA58766D-ABF2-4402-88D7-90AB243F6C77}` (firmware) and `{936DC601-5530-4B82-9D2A-72A488BEC7C1}` (software, = RPE client).  
The bytes 10-13 are the secured channel ID (PAS peripheral ID 5 = modem FW, 4 = modem SW).

The output buffer contains the physical address of the entry point of the image (firmware at context +0x58, software at +0x5C).

---

### IOCTL 0x9C412410

This IOCTL is sent by Qcamss8930.sys to [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c412410--ioctl_pil_tz_auth_image_and_reset), after each 0x9C41241C on the same target. Synchronous (`WdfIoTargetSendIoctlSynchronously`).

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_AUTH_IMAGE_AND_RESET | PIL interface `{E2EB84C1-…}` | 0 | 0 |

The TrustZone authenticates the image and takes the processor out of reset. Errors: "Unable to reset the AMSS firmware hardware, subsystem will not be released from reset!" (resp. software).

---

### IOCTL 0x9C412408

This IOCTL is sent by Qcamss8930.sys to [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c412408) during an SSR (`ReloadAmssAndReleaseFromReset` = `sub_41AB40`): software image first, then firmware image, each on its own target. Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x902 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Unload image | PIL interface `{E2EB84C1-…}` | 16 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 01 c6 6d 93 30 55 82 4b 9d 2a 72 a4 88 be c7 c1 | GUID of the software image (then `6d 76 58 ba …` for the firmware) |

Failure: "Failed to unload AMSS software image" (resp. firmware), bug check through `AmssSSRFailBugcheck`.

---

### IOCTL 0x8C1F2004

This IOCTL is sent by Qcamss8930.sys to [qcchipinfo8930.sys](./qcchipinfo8930.md#ioctl-0x8c1f2004) when its interface arrives (`sub_418B74`). Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Get chip version | ChipInfo interface `{FB4F07CD-…}` | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 00 00 01 00 | Chip version `major << 16 \| minor` (log "Chip version - "), stored at context +0x04. < 0x20000 → `AmssFwImagePath`, otherwise `AmssFwImagePathV2` |

---

### IOCTL 0x3200C

This IOCTL is sent by Qcamss8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x3200c) (`WdfIoTargetFormatRequestForIoctl` + `WdfRequestSend`, asynchronous), when the SMSM interface arrives and again during an SSR.

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Wait for a state | SMSM interface `{1C90923A-…}` | 12 | 0 |

Wait for the start of the modem (`SetupModemUpNotification` = `sub_419DDC`, completion routine `sub_403D9C`, buffer pool tag `qms8`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | SMSM_MODEM_STATE |
| 04-07 | 01 00 00 00 | state_mask: SMSM_INIT |
| 08-0B | 01 00 00 00 | expected_state: SMSM_INIT |

On success, the work item `sub_4188F4` publishes the interface (see [Start of the subsystem](#start-of-the-subsystem)).

Wait for a crash of the modem (`SetupModemErrorNotification` = `sub_419A8C`, completion routine `sub_4038C4`, buffer pool tag `qms7`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | SMSM_MODEM_STATE |
| 04-07 | 40 00 00 00 | state_mask: SMSM_RESET |
| 08-0B | 40 00 00 00 | expected_state: SMSM_RESET |

The request is kept at context +0x6C (cancelled by `EvtDeviceD0Exit`). On success, see [Crash handling](#crash-handling).

---

### internal IOCTL 0x32008

This IOCTL is sent by Qcamss8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#internal-ioctl-0x32008) when the SMSM interface arrives (`sub_418B74`).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_INTERNAL_SMSM_RESET | SMSM interface `{1C90923A-…}` | 4 | 4 |

Input `01 00 00 00`. The output buffer contains a pointer to the function `FuncSmsmReset`, stored at context +0x64 and called by the RPE "apps state" callback (state 7, see [RPE](#rpe)).

---

### internal IOCTL 0x32010

This IOCTL is sent by Qcamss8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#internal-ioctl-0x32010) when the SMSM interface arrives (`sub_418B74`).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_INTERNAL_SMSM_STATE_GET | SMSM interface `{1C90923A-…}` | 0 | 4 |

The output buffer contains a pointer to the function `smsm_state_get`, stored at context +0x68. It's used to read `SMSM_MODEM_STATE` after a fatal error (user shutdown bit) and in the RPE "apps state" callback.

---

### internal IOCTL 0x42000

This IOCTL is sent by Qcamss8930.sys to [qcsmem8930.sys](./qcsmem8930.md#internal-ioctl-0x42000) when the SMEM interface arrives (`smem_init_driver` = `sub_40D68C`).

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Get the SMEM function table | \Device\SMEM | 0 | 52 |

The 13 function pointers are written to `.data:0x00413F88` (the I/O target is kept at `.data:0x00413F84`). Only `smem_alloc` (position 00, `.data:0x00413F88`) and `smem_get_addr` (position 01, `.data:0x00413F8C`) are used, for the crash reason. If `BytesReturned` isn't 52, the target is closed and the driver returns `STATUS_IO_DEVICE_ERROR` (0xC0000185): the SMEM flag stays cleared and the modem is never started.

---

### internal IOCTL 0x22003

This IOCTL is sent by Qcamss8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) (`SysmonOpenTargetToSMD` = `sub_40DD94`, `WdfIoTargetFormatRequestForInternalIoctl`). Synchronous.

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
| 00-03 | ? | Pointer to the ANSI string `sys_mon` |
| 04-07 | 00 00 00 00 | Edge 0 = APPS↔MODEM |
| 08-0B | 01 00 00 00 | Flags |
| 0C-0F | 00 04 00 00 | FIFO size 0x400 |
| 10-13 | 00 00 00 00 | No "data received" event |
| 14-17 | ? | Pointer to the "channel opened" event (`.data:0x00414060`) |
| 18-1B | 00 00 00 00 | No "channel closed" event |

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcamss8930.sys to [acpi.sys](./acpi.md#ioctl-0x32c004--ioctl_acpi_eval_method) (default I/O target, `WdfIoTargetSendIoctlSynchronously`) in `EvtDriverDeviceAdd`.

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD (`CONF`) | ACPI node of the device | 8 | 512 |
| IOCTL_ACPI_EVAL_METHOD (`VLMT`) | ACPI node of the device | 8 | 512 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature 'AeiB' (`ACPI_EVAL_INPUT_BUFFER_SIGNATURE`) |
| 04-07 | 43 4F 4E 46 or 56 4C 4D 54 | Method name `CONF` (in `SetupRpe`) or `VLMT` (in `sub_402BDC`) |

The output buffer must have the signature 'AeoB' and at least one argument. `CONF`: see [RPE](#rpe). `VLMT`: see [Passive cooling](#passive-cooling). `STATUS_OBJECT_NAME_NOT_FOUND` (method missing) isn't an error.

---

### IOCTL 0x122008

This IOCTL is sent by Qcamss8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x122008) by the IPC transport of the QMI client library (`sub_4097C0`, lookup of a service), on a target opened on `\Device\IPC` for the request. Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Lookup servers | \Device\IPC | 16 | 8 + 16 × MaxEntries |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 18 00 00 00 | Service (0x18 = TMD) |
| 04-07 | e.g. 01 00 00 00 | Instance (version of the service object ?) |
| 08-0B | FF 00 00 00 | Instance mask |
| 0C-0F | ? | MaxEntries |

The node and port of each server found are copied into the service info records of the library (20 bytes each).

---

### IOCTL 0x122017

This IOCTL is sent by Qcamss8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x122017) by the IPC transport of the QMI client library (`sub_409158` when the port is opened, then re-sent by the completion work item `sub_408AB4`). Asynchronous, no buffer.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x805 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a packet | \Device\IPC | 0 | 0 |

When it completes, `Information` - 8 is the size of the next packet, which is then read and given to the library (`sub_406724`).

---

### IOCTL 0x12201B

This IOCTL is sent by Qcamss8930.sys to [qcipcrouter8930.sys](./qcipcrouter8930.md#ioctl-0x12201b) by the IPC transport of the QMI client library (`sub_409158`, then re-sent by the work item `sub_408C8C`, "qcci_xport_ipc_wdf_event_peek_cb_workitem"). Asynchronous.

| Property | Value |
|----------|-------|
| Device | 0x12 |
| Function | 0x806 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a server/client event | \Device\IPC | 0 | 0 (20-byte memory attached) |

Used to be told about new or removed servers ("IOCTL_IPC_READ_OOB returned status" in the `DbgPrintEx` traces).

---

### IOCTL 0x12418

This IOCTL is sent by Qcamss8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x12418--ioctl-0x1241c) by the QMUX transport of the QMI client library (`sub_40A5A4`, lookup of a service), on a target opened on `\Device\QMUX` for the request. Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x906 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Bind the handle to a QMI service | \Device\QMUX | 8 | 4 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | e.g. 18 00 00 00 | QMI service type (service id of the service object, 0x18 = TMD) |
| 04-07 | 00 00 00 00 … 05 00 00 00 | QMUX port: transport parameter (16 to 21) − 16 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | ? | Major version of the service. The service is "found" only when it's equal to the IDL version of the service object |
| 02-03 | ? | Minor version (not used) |

When the versions match, one service info record (20 bytes) is filled: byte 0 = index of the transport, byte 1 = version, byte 2 = transport parameter (16 to 21), the rest 0. The same code is in [qcltecoexmgr8930.sys](./qcltecoexmgr8930.md#ioctl-0x12418) (`sub_405B88`).

---

### IOCTL 0x12410

This IOCTL is sent by Qcamss8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x12410) by the QMUX transport of the QMI client library (`sub_409E18`, open of a client). Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Get a QMI client id | \Device\QMUX | ? | 1 |

---

### IOCTL 0x12430

This IOCTL is sent by Qcamss8930.sys to [qcqmux8930.sys](./qcqmux8930.md#ioctl-0x12430) by the QMUX transport of the QMI client library (`sub_409E18`, then re-sent by the completion routine `sub_409C5C`). Asynchronous.

| Property | Value |
|----------|-------|
| Device | 0x1 |
| Function | 0x90C |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Wait for a service state notification | \Device\QMUX | 0 | 8 |

When the notification state is 1 (channel closed by the modem) for the service of the handle, the library is told that the server is gone (`sub_406580`).
