## Qcadsp8930.sys

ADSP (LPASS / QDSP6 audio DSP) subsystem driver.  
It loads the ADSP image through [qcpil8930.sys](./qcpil8930.md), releases the QDSP6 from reset, waits for it to come up through [qcsmsm8930.sys](./qcsmsm8930.md), then publishes its device interface. It doesn't talk to the audio firmware itself: that's done by [qcq6ad8930.sys](./qcq6ad8930.md) (APR over SMD), which this driver feeds with the Dolby/third-party audio license (`AUDIO.PROVISION`).  
It also handles the ADSP crashes: there's no SubSystem Restart, every crash (watchdog bite or fatal error) bug checks the phone.  
It's a client of the RPE notifier [qcrpen8930.sys](./qcrpen8930.md) (client name `ADSP`), and it sends the SSR notifications of the WCN subsystem to the ADSP through the SMD channel `sys_mon`. Its RPE state 5 is a prerequisite of the modem driver [qcamss8930.sys](./qcamss8930.md#rpe): the modem is never loaded before the ADSP.  
The PDB path embedded in the binary is `E:\build_e\subtask\E05A4CC0_98\output\audio\fre\qcadsp8930.pdb`.

There's no named device object and no symbolic link.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0E10\<instance>`

Registry value read from the **driver (software) key** of the device (`WdfDeviceOpenRegistryKey(PLUGPLAY_REGKEY_DRIVER, KEY_READ)` in `EvtDriverDeviceAdd`, `sub_414F94`):  
| Registry value | value | comment |
|----------------|-------|---------|
| AdspImagePath | `\SystemRoot\system32\qcadsp8930.mbn` | REG_SZ. Filename of the ADSP image (value seen by [qcpil8930.sys](./qcpil8930.md)). Default is `C:\Windows\System32\ADSP.MBN`, with the warning "we will load the subsystem image from the default path" in the logs |

`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ProductOptions`:  
| Registry value | value | comment |
|----------------|-------|---------|
| ProductSuite | `PhoneNT` | REG_MULTI_SZ. Selects how `AUDIO.PROVISION` is read, see [Audio license](#audio-license). Same DPP library as [qcbms8930.sys](./qcbms8930.md#battery-provisioning) |

GUID of the ETW provider of the driver (`McGenEventRegister` in `DriverEntry`):  
`{7CD6B6CC-69C9-46FC-B075-3C71BFA885DF}`

GUID of the ETW provider of the RPE helper library (`McGenEventRegister` in `RpeInit`, same as in [qcwcn8930.sys](./qcwcn8930.md)):  
`{57E95397-C84E-4F53-9473-56207AAA5938}`

GUID of the ETW provider of the Sysmon library (`McGenEventRegister` in `SysmonInit`, `sub_4083A4`):  
`{F6B68689-94AD-45B9-8160-3BCDEFFD6A3F}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\PIL | [qcpil8930.sys](./qcpil8930.md) | Peripheral Image Loader. [IOCTL 0x9C41241C](#ioctl-0x9c41241c), [IOCTL 0x9C412410](#ioctl-0x9c412410). Also waited for (and kept open) through its second interface `{E2EB84C1-…}` |
| \Device\SMSM | [qcsmsm8930.sys](./qcsmsm8930.md) | Shared Memory State Machine. [internal IOCTL 0x32008](#internal-ioctl-0x32008), [internal IOCTL 0x32010](#internal-ioctl-0x32010), [IOCTL 0x3200C](#ioctl-0x3200c) |
| \Device\SMEM | [qcsmem8930.sys](./qcsmem8930.md) | [internal IOCTL 0x42000](#internal-ioctl-0x42000): function table, used to read the crash reason `SMEM_SSR_REASON_LPASS0` |
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Channel `sys_mon` ([internal IOCTL 0x22003](#internal-ioctl-0x22003)), see [Sysmon](#sysmon) |
| \Device\RPEN, Helper interface | [qcrpen8930.sys](./qcrpen8930.md) | See [RPE](#rpe) |
| Interface `{5F51A34C-6834-479D-9EA2-EAFA622524BA}` | [qcq6ad8930.sys](./qcq6ad8930.md) (`\_SB.Q6AD`) | Q6 audio. [IOCTL 0xADAD2F41](#ioctl-0xadad2f41): audio license |
| ACPI node of the device (default I/O target) | [acpi.sys](./acpi.md) | [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method) `IOCTL_ACPI_EVAL_METHOD`, methods `CONF` and `MANU` |
| `\Device\Harddisk0`… | disk.sys | `IOCTL_DISK_GET_DRIVE_LAYOUT_EX` (0x70050) to find the EFI system partition, only when `PhoneNT` is absent |
| Power framework (PEP) | [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state) | `PoFxPowerControl`, see [Power management](#power-management) |

Hardcoded physical address: `MmMapIoSpace(0x28800010, 4, MmNonCached)` in `EvtDriverDeviceAdd`, named `LPASS_QDSP6SS_STOP` in the logs. Writing 1 to it sends an NMI to the QDSP6 to stop it ([RPE](#rpe) callback [1]). If the mapping fails, the log says "Will not be able to send NMI to ADSP to stop subsystem" and the driver goes on.

### WDF setup

`EvtDriverDeviceAdd` (0x412494):
- PnP callbacks: `EvtDevicePrepareHardware` (`sub_412D48`), `EvtDeviceReleaseHardware` (`sub_412ED4`), `EvtDeviceD0Exit` (`sub_414E28`), `EvtDeviceSurpriseRemoval` (`sub_402E64`, revokes the ADSP interface). `EvtCleanupCallback` of the device: `sub_414CAC` (revokes the interface, unregisters the 3 PnP notifications, frees the crash reason).
- The device context (`ADSP_DEVICE_CONTEXT`) is also saved in the global `gpDeviceContext` (`.data:0x0040EBC8`), used by the NMI path.
- `WdfDeviceSetStaticStopRemove(FALSE)` and `WdfDeviceSetDeviceState(NotDisableable = TRUE)`.
- Default sequential queue, not power managed, with `EvtIoDeviceControl` (`sub_412FF8`). It completes **every** request without looking at the code: `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) when the ADSP interface is published, 0xA0008100 otherwise. The driver has no IOCTL of its own.
- 2 wait-locks (`InterfaceAccessLock`, `StartSubSystemLock`) and a spinlock.
- Reads `AdspImagePath` (see above).
- `SetupInterrupt` (`sub_401A34`): one interrupt, ISR `sub_4014FC` (queues the DPC), DPC `sub_401528` = ADSP watchdog bite, see [Crash handling](#crash-handling).
- `AllocMemAuthCmd` (`sub_410008`), see [Audio license](#audio-license). A failure is only logged ("Unable to allocate memory for audio third patry authentication").
- `SetupRpe` (`sub_401AF4`), see [RPE](#rpe).
- `SysmonInit` (`sub_4082A0`), see [Sysmon](#sysmon).
- `IoRegisterPlugPlayNotification` on 3 interfaces, all with the callback `sub_4149D4` (it queues the work item `sub_413490`): PIL `{E2EB84C1-4068-4994-A48F-F3AC0D38DC29}`, SMSM `{1C90923A-DF5C-4761-9FD0-835B80F5281D}` and SMEM `{54415E20-5FC4-4938-8958-31966F441C63}`. A 4th one, Q6AD `{5F51A34C-…}`, is registered once the ADSP is up.

`EvtDevicePrepareHardware` (`sub_412D48`): registers the device with the power framework (`RegisterPowerManager` = `sub_415290`, once) and queues a work item that tries to start the subsystem (`sub_4037BC`).  
`EvtDeviceReleaseHardware` (`sub_412ED4`): `RpeClientDeinit` of the ADSP client, `RpeDeinit`, `PoFxUnregisterDevice`.  
`EvtDeviceD0Exit` (`sub_414E28`): when the target state is `WdfPowerDeviceD3Final`, cancels the pending `SMSM_RESET` wait ([IOCTL 0x3200C](#ioctl-0x3200c)).

### Start of the subsystem

Prerequisites, each set by an interface arrival (work item `sub_413490`):  
| Flag | Set by | Action on arrival |
|------|--------|-------------------|
| PIL up (+0x04) | PIL interface `{E2EB84C1-…}` (`sub_413E3C`) | Saves the symbolic link of the interface. A removal revokes the ADSP interface |
| SMSM up (+0x08) | SMSM interface `{1C90923A-…}` (`sub_413734`) | Opens `\Device\SMSM`, gets the 2 function pointers ([0x32008](#internal-ioctl-0x32008), [0x32010](#internal-ioctl-0x32010), stored at +0x490/+0x494 but **never called**), arms the 2 [0x3200C](#ioctl-0x3200c) waits (`SetupSSErrorNotification` = `sub_410AC8`, `SetupSSUpNotification` = `sub_4110F4`) |
| SMEM up (+0x0C) | SMEM interface `{54415E20-…}` (`smem_init_driver` = `sub_4094A8`) | Opens `\Device\SMEM` and gets its function table ([internal IOCTL 0x42000](#internal-ioctl-0x42000)) |
| Power managed (+0x18), F0 (+0x4A4) | `RegisterPowerManager`, `ComponentIdleStateCallback` | See [Power management](#power-management) |

After each arrival, `sub_4037BC` ("Attempting to start subsystem") checks the flags. When they are all set and the subsystem isn't started yet (+0x14, `sub_403578`), `sub_411370` runs once:
1. Opens an I/O target on the PIL interface by its symbolic link (`sub_41212C`, "OPEN_PUBLISHER_DEVICE"). Its query-remove callback (`sub_4145B8`) revokes the ADSP interface and closes the target; remove-canceled (`sub_414698`) reopens it.
2. P0 (`TransitionPState(0)` = `sub_403ADC`).
3. `LoadImageAndReleaseFromReset` (`sub_411540`): opens `\Device\PIL`, sends [IOCTL 0x9C41241C](#ioctl-0x9c41241c) (load) then [IOCTL 0x9C412410](#ioctl-0x9c412410) (auth and reset). Any failure: "ADSP subsystem will not be released from reset!".
4. On failure, P1 and idle the component (`sub_402920`).

When the QDSP6 sets `SMSM_INIT` in `SMSM_Q6_STATE` ([IOCTL 0x3200C](#ioctl-0x3200c), completion `sub_402430`), the work item `sub_410D74` ("Subsystem is up and running. Will publish ADSP interface and change RPE state..."):
1. publishes the [ADSP interface](#interface-guid),
2. sends the RPE state 5 `RPE_STATE_ID_READY_FOR_COMMANDS`,
3. registers for the arrival of the Q6AD interface `{5F51A34C-…}` ("Waiting for readiness of Q6AD interface..."). On arrival (`sub_414138`), if the ADSP is up and the license buffer is ready, it sends [IOCTL 0xADAD2F41](#ioctl-0xadad2f41) once (`SendQ6AudioAuthentication` = `sub_4104A4`), then frees the buffer.

### Lumia 520 ACPI node

From the DSDT. The node is `\_SB.ADSP` (`_HID` `QCOM0E10`, no `_UID`), with `_DEP` on `\_SB.PMIC` only.
- `_CRS`: one interrupt, `Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive)` 119 (0x77). It's the ADSP watchdog bite handled by `SetupInterrupt`.
- `MANU` returns `Package (1) { 0x3551ED9D }`: manufacturer ID, copied in front of the audio license (see [Audio license](#audio-license)).
- `CONF` returns `Package (2) { Package (2) { 0x8DA00000, 0x1800 }, Package (2) { 0x28400000, 0x20 } }`: memory regions of the ADSP (base, number of 4 KB pages) given to `RpeClientInitMultiSegment` for the crash dump. 0x1800 pages = 24 MB (0x8DA00000–0x8F1FFFFF), 0x20 pages = 128 KB (0x28400000–0x2841FFFF). See [qccdi8930.sys](./qccdi8930.md#memory-layout-of-a-subsystem), which uses a smaller hard-coded range.

### Interface GUID

ADSP device interface, published (`WdfDeviceCreateDeviceInterface` + `WdfDeviceSetDeviceInterfaceState`, `sub_411DCC`) when the ADSP is up, revoked on surprise removal, when the PIL interface goes away, or when the subsystem fails to start:  
`{2D332EF9-18B0-4615-B47B-6C2F745F9CE6}`  
Consumer: [qcq6ad8930.sys](./qcq6ad8930.md#start-sequence), which waits for it at start and opens it only to be notified of its removal.

### RPE

`SetupRpe` (`sub_401AF4`):
1. Evaluates the ACPI method `CONF` ([IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method), output buffer of 512 bytes). If the method doesn't exist (`STATUS_OBJECT_NAME_NOT_FOUND`), the log says "No memory region data in the ACPI, the modem RAM will not be included in the crash dump files" (copied from the modem driver [qcamss8930.sys](./qcamss8930.md#rpe)) and the client is registered without memory segment.
2. `RpeInit` (waits for the Helper interface `{59752ED7-B9D5-4121-818D-C69F1E667015}` of [qcrpen8930.sys](./qcrpen8930.md)), then `RpeClientInitMultiSegment` with the client GUID `{D58464D3-5B28-4EA6-A2E2-E8E57C5C69B8}`, the name `ADSP`, the second string `1`, the memory segments and the callback table `{16 (size of the table), sub_402604, sub_4026B0, sub_402788}` (see the [RPE client record](./qcrpen8930.md#rpe-client-record)).
3. `RegisterRPEStateNotification` (`sub_402114`) twice, on the WCN client `{93367D0F-35CE-4EC4-8E38-BB33030C58B2}` of [qcwcn8930.sys](./qcwcn8930.md) with the states 4 and 5. The callback `sub_4021F0` sends the matching [Sysmon](#sysmon) message to the ADSP.

The client GUID is also the GUID given to [qcpil8930.sys](./qcpil8930.md) and the one [qccdi8930.sys](./qccdi8930.md) uses for the ADSP.

State sent by the driver (`RpeSendState`):  
| State | Name in the logs | When |
|-------|------------------|------|
| 5 | `RPE_STATE_ID_READY_FOR_COMMANDS` | The ADSP is up and its interface is published. Watched by [qcamss8930.sys](./qcamss8930.md#rpe), which starts the modem only after it |

Callbacks:  
| Index | Function | Comment |
|-------|----------|---------|
| [1] | `sub_402604` | "Apps state" callback. 7 = fatal error of the HLOS, sent by [qccdi8930.sys](./qccdi8930.md) before the crash dump (log: "Detected HLOS fatal error! Will halt subsystem and flush cache in preparation for crash dump..."): `sub_401444` writes 1 to the `LPASS_QDSP6SS_STOP` register (NMI to the QDSP6). There's no wait for an acknowledgment. Other values are ignored. Always returns 1. qccdi8930.sys actually skips the halt of the ADSP ("Bypassing halt for this subsystem (ADSP) due to a known issue") |
| [2] | `sub_4026B0` | Copies the last crash reason string (see [Crash handling](#crash-handling)) to the buffer given by the caller (`+0x10` size, `+0x14` string) |
| [3] | `sub_402788` | Command callback. Only logs |

### Crash handling

A crash of the ADSP is detected in 2 ways:
- Watchdog bite: the interrupt of the device (ISR `sub_4014FC`, DPC `sub_401528`). The crash reason is "ADSP firmware watch dog bite". Log: "Detected watch dog bite from the ADSP subsystem!".
- Fatal error: the QDSP6 sets `SMSM_RESET` in `SMSM_Q6_STATE`, which completes the pending [IOCTL 0x3200C](#ioctl-0x3200c) (completion routine `sub_4016E0`). The crash reason is read from the SMEM item 423 `SMEM_SSR_REASON_LPASS0` (`smem_get_addr`). If the item doesn't exist or is empty, the driver **creates it** (`smem_alloc(423, 64)`) and writes the test string `TESTADSPErrorReason` into it, then reads it back. The item is zeroed after the copy. Log: "Detected fatal error from the ADSP subsystem!".

The crash reason is saved in a pool buffer (tag `qds9`, pointer at context +0x4E4):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | ? |
| 04-17 | 00 … | ? |
| 18-1B | e.g. 80 00 00 00 | Length of the string (128 for the watchdog bite, size of the SMEM item otherwise) |
| 1C-… | e.g. `ADSP firmware watch dog bite` | Crash reason, ANSI |

Then, in both cases, after the logs "The ADSP subsystem has crashed, please work with the ADSP triage team to continue debugging", "First please collect memory dump: http://dmermprd01.qualcomm.com/eRoom/QCT-MM/8KCoreFW/0_2ce21" and "Will bug check the HLOS on behalf of the ADSP subsystem (this is NOT an issue in the ADSP driver)", the driver calls `KeBugCheckEx(0x14B, &{1}, reason, 0, 0)`: bug check `SOC_SUBSYSTEM_FAILURE`, parameter 1 points to a DWORD 1 (`SOC_SUBSYS_AUDIO_DSP`). Parameter 2 is the crash reason buffer for the watchdog bite, but the **address of the pointer** to it (context +0x4E4) for the fatal error ?

> [!NOTE]
> There's no SubSystem Restart in this driver (no `RestartEnabled` value, no reload IOCTL): any ADSP crash bug checks the phone.

### Power management

`RegisterPowerManager` (`sub_415290`) calls `PoFxRegisterDevice` directly (it's not done by KMDF), then `PoFxActivateComponent(0)` and `PoFxStartDevicePowerManagement`. `PO_FX_DEVICE`:  
| Field | Value |
|-------|-------|
| Version | 1 |
| ComponentCount | 1 |
| ComponentActiveConditionCallback | `sub_403128` (only logs) |
| ComponentIdleConditionCallback | `sub_403404` (`PoFxCompleteIdleCondition`) |
| ComponentIdleStateCallback | `sub_402EC8`: F0 → flag +0x4A4 = 1 and queue a work item that retries the start of the subsystem; F1 → flag = 0. Then `PoFxCompleteIdleState` |
| DevicePowerRequiredCallback | `sub_40316C` (`PoFxReportDevicePoweredOn`) |
| DevicePowerNotRequiredCallback | `sub_4034C4` (`PoFxCompleteDevicePowerNotRequired`) |
| PowerControlCallback | `sub_403230`, see below |
| Component 0 Id | `{220EE709-992C-4933-978B-04C451B6DE50}` |
| Component 0 idle states | 2. F0: latency 0, residency 0, nominal power 500. F1: latency 2, residency 5, nominal power 50. DeepestWakeableIdleState = 1 |

The P-states of the ADSP are changed by `TransitionPState` (`sub_403ADC`) with `PoFxPowerControl`, same PowerControlCode and buffers as [qcwcn8930.sys](./qcwcn8930.md#power-management):  
PowerControlCode `{3404DAAC-8E2C-41E4-8458-3158E5AD442B}`  
Input (8 bytes, pool tag `qds4`): `00 00 00 00` (component 0 ?), then the P-state (0 = P0 before the image is loaded, 1 = P1). Output (12 bytes, pool tag `qds3`): `00-03` = 3 `PEP_STATE_SYNC_PATH` (done) or 1 `PEP_STATE_ASYNC_PATH_IN_PROGRESS` (the driver waits up to 50 ms for an event, then returns). Any other value: "Change P state failed". A P-state ≥ 2 is refused, and nothing is sent while the component isn't in F0.  
For an asynchronous transition, the PEP calls `PowerControlCallback` with an output buffer whose first DWORD is 2: the driver sets the event and queues the work item `sub_402A50` ("Transitioned to P0. Since SS is up, start a WI to transition to P1."), which goes on with the start of the subsystem or idles the component.

### Sysmon

The Sysmon library (`SysmonInit` = `sub_4083A4`) sends SSR (SubSystem Restart) notifications of the other subsystems to the ADSP.  
It waits for the SMD interface `{F9D15453-8335-434C-AA72-FCD925F135F3}` of [qcsmd8930.sys](./qcsmd8930.md) (`SysmonEvtNotifyInterfaceChange` = `sub_408DFC`), then opens `\Device\SMD` and the channel `sys_mon` on edge 1 (APPS↔QDSP), see [internal IOCTL 0x22003](#internal-ioctl-0x22003).

`SysmonSendMsg` (`sub_4082AC`):
1. Checks the message against the list allowed for the edge (for edge 1: `ssr:modem:before_shutdown`, `ssr:wcnss:before_shutdown`, `ssr:dsps:before_shutdown`, `ssr:modem:after_powerup`, `ssr:wcnss:after_powerup`, `ssr:dsps:after_powerup`).
2. Waits for the channel to be open, writes the message (`WdfIoTargetFormatRequestForWrite`, timeout 30 s).
3. Reads the answer (timeout 30 s) and checks that it's `ssr:ack`.

Messages actually sent (table at `.data:0x0040E1B0`, used by the RPE state callback `sub_4021F0`):  
| RPE client | State | Message |
|------------|-------|---------|
| WCN `{93367D0F-…}` ([qcwcn8930.sys](./qcwcn8930.md#rpe)) | 4 `RPE_STATE_ID_RESTARTING` | `ssr:wcnss:before_shutdown` |
| WCN `{93367D0F-…}` | 5 `RPE_STATE_ID_READY_FOR_COMMANDS` | `ssr:wcnss:after_powerup` |

The modem and DSPS messages (and `info:version`, `ssr:lpass:*`) are in the library but not used.

### Audio license

`AllocMemAuthCmd` (`sub_410008`, called from `EvtDriverDeviceAdd`) prepares the third-party audio license (Dolby, "LFX" in the logs) for the Q6 audio firmware:
1. `GetDPPItemSize` (`sub_407288`): size of the DPP item `QCOM` / `AUDIO.PROVISION`.
2. If it's 0, the alternative file `\DosDevices\C:\PROGRAMS\CommonFiles\OEM\Public\AUDIO.PROVISION` is opened instead ("[LFX] License file opened successfully from alternative location"). A size ≥ 4 GB is refused ("Too big license file").
3. Allocates `size + 4` bytes of physically contiguous, non cached memory (`MmAllocateContiguousMemorySpecifyCache`, between 0x40200000 and 0xC0000000, boundary 0x1000), pointer at context +0x450, size at +0x454.
4. Writes the manufacturer ID (ACPI `MANU`, `sub_401170`, see [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method)) in the first 4 bytes.
5. Copies the license after it: `GetDPP_KMDF` (`sub_407510`), or `ZwReadFile` of the alternative file.

On any error the buffer is freed, and the log says "Audio media requiring 3rd party license may not play!".

Where the DPP item is read from (`sub_4071B8` / `sub_407510`), depending on `ProductSuite`:
* `PhoneNT` present (Windows Phone): the file `\DosDevices\C:\DPP\QCOM\AUDIO.PROVISION` (each directory is checked with `ZwCreateFile`, up to 10 tries 500 ms apart while the path isn't found).
* Otherwise: `DPP\QCOM\AUDIO.PROVISION` on the EFI system partition (`{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}`, found with `IOCTL_DISK_GET_DRIVE_LAYOUT_EX` on `\Device\Harddisk%u\Partition0`), or a record `QCOM` / `AUDIO.PROVISION` (type 1) of a raw DPP directory. Same code as in [qcbms8930.sys](./qcbms8930.md#battery-provisioning).

Content of the buffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 9D ED 51 35 | Manufacturer ID, from the ACPI method `MANU` (0x3551ED9D on the Lumia 520) |
| 04-… | ? | Content of `AUDIO.PROVISION` |

The physical address of this buffer is sent to [qcq6ad8930.sys](./qcq6ad8930.md) with [IOCTL 0xADAD2F41](#ioctl-0xadad2f41) when its interface arrives, then the buffer is freed.

---

### IOCTL 0xADAD2F41

This IOCTL is sent by Qcadsp8930.sys to [qcq6ad8930.sys](./qcq6ad8930.md) (interface `{5F51A34C-6834-479D-9EA2-EAFA622524BA}`, opened by its symbolic link) in `SendQ6AudioAuthentication` (`sub_4104A4`). Synchronous (`WdfRequestSend` with `WDF_REQUEST_SEND_OPTION_SYNCHRONOUS`).

| Property | Value |
|----------|-------|
| Device | 0xADAD |
| Function | 0xBD0 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_IN_DIRECT |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Audio authentication | interface `{5F51A34C-…}` | 12 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Physical address (low part, `MmGetPhysicalAddress`) of the license buffer, see [Audio license](#audio-license) |
| 04-07 | 01 00 00 00 | ? |
| 08-0B | ? | Size of `AUDIO.PROVISION` (without the 4-byte manufacturer ID) |

The ADSP core receives the 12 bytes as an APR packet, opcode 0x11285 (see [qcq6ad8930.sys](./qcq6ad8930.md#ioctl-0xadad2f41--audio-license)).  
Logs: "Sending audio authentication request to Q6AD", "Audio authentication request sent to Q6AD successfully".  
The IOCTL is formatted with `WdfIoTargetFormatRequestForIoctl` although a log string says "WdfIoTargetFormatRequestForInternalIoctl".

---

### IOCTL 0x9C41241C

This IOCTL is sent by Qcadsp8930.sys to [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c41241c--ioctl_pil_tz_load_image) (`LoadImageAndReleaseFromReset` = `sub_411540`). Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x907 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_LOAD_IMAGE | \Device\PIL | 540 | 4 |

Content of the input buffer:  
| Bytes 00-0F | Bytes 10-13 | Bytes 14-21B |
|-------------|-------------|--------------|
| d3 64 84 d5 28 5b a6 4e a2 e2 e8 e5 7c 5c 69 b8 | 01 00 00 00 | Null terminated WCHAR string `AdspImagePath`, e.g. `\SystemRoot\system32\qcadsp8930.mbn` |

The first 16 bytes are the GUID of the RPE client:  
`{D58464D3-5B28-4EA6-A2E2-E8E57C5C69B8}`

The bytes 10-13 are the secured channel ID (PAS peripheral ID 1 = Q6/ADSP).

The output buffer contains the physical address of the entry point of the image ("Physical address of ADSP image after IOCtl" in the logs).

---

### IOCTL 0x9C412410

This IOCTL is sent by Qcadsp8930.sys to [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c412410--ioctl_pil_tz_auth_image_and_reset) (`LoadImageAndReleaseFromReset` = `sub_411540`), after 0x9C41241C on the same handle. Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_AUTH_IMAGE_AND_RESET | \Device\PIL | 0 | 0 |

The TrustZone authenticates the image and takes the QDSP6 out of reset. Log: "Succeeded in resetting ADSP subsystem hardware with image: …".

---

### IOCTL 0x3200C

This IOCTL is sent by Qcadsp8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x3200c) (`WdfIoTargetFormatRequestForIoctl` + `WdfRequestSend`, asynchronous), when the SMSM interface arrives.

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Wait for a state | \Device\SMSM | 12 | 0 |

Wait for the start of the QDSP6 (`SetupSSUpNotification` = `sub_4110F4`, completion routine `sub_402430`, buffer pool tag `qds8`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | SMSM_Q6_STATE |
| 04-07 | 01 00 00 00 | state_mask: SMSM_INIT |
| 08-0B | 01 00 00 00 | expected_state: SMSM_INIT |

On success, the work item `sub_410D74` publishes the interface (see [Start of the subsystem](#start-of-the-subsystem)).

Wait for a crash of the QDSP6 (`SetupSSErrorNotification` = `sub_410AC8`, completion routine `sub_4016E0`, buffer pool tag `qds7`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 | SMSM_Q6_STATE |
| 04-07 | 40 00 00 00 | state_mask: SMSM_RESET |
| 08-0B | 40 00 00 00 | expected_state: SMSM_RESET |

On success, see [Crash handling](#crash-handling) (bug check 0x14B).

---

### internal IOCTL 0x32008

This IOCTL is sent by Qcadsp8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#internal-ioctl-0x32008) when the SMSM interface arrives (`sub_413734`).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_INTERNAL_SMSM_RESET | \Device\SMSM | 4 | 4 |

Input `01 00 00 00`. The output buffer contains a pointer to the function `FuncSmsmReset`. It's stored (context +0x490) but never called: unlike [qcwcn8930.sys](./qcwcn8930.md#rpe), the HLOS crash path uses the NMI register.

---

### internal IOCTL 0x32010

This IOCTL is sent by Qcadsp8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#internal-ioctl-0x32010) when the SMSM interface arrives (`sub_413734`).

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_INTERNAL_SMSM_STATE_GET | \Device\SMSM | 0 | 4 |

The output buffer contains a pointer to the function `smsm_state_get`. It's stored (context +0x494) but never called.

---

### internal IOCTL 0x42000

This IOCTL is sent by Qcadsp8930.sys to [qcsmem8930.sys](./qcsmem8930.md#internal-ioctl-0x42000) when the SMEM interface arrives (`smem_init_driver` = `sub_4094A8`).

| Property | Value |
|----------|-------|
| Device | 0x4 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Get the SMEM function table | \Device\SMEM | 0 | 52 |

The 13 function pointers are copied to `.data:0x0040EB94`. Only `smem_alloc` (position 00) and `smem_get_addr` (position 01) are used, for the crash reason. If less than 52 bytes are returned, the driver fails with `STATUS_DEVICE_PROTOCOL_ERROR` (0xC0000185).

---

### internal IOCTL 0x22003

This IOCTL is sent by Qcadsp8930.sys to [qcsmd8930.sys](./qcsmd8930.md#internal-ioctl-0x22003) (`SysmonOpenTargetToSMD` = `sub_4090B8`). Synchronous.

| Property | Value |
|----------|-------|
| Device | 0x2 |
| Function | 0x800 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_NEITHER |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Open a SMD channel | \Device\SMD | 28 | 0 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Pointer to the ANSI string `sys_mon` |
| 04-07 | 01 00 00 00 | Edge 1 = APPS↔QDSP |
| 08-0B | 01 00 00 00 | Flags |
| 0C-0F | 00 04 00 00 | FIFO size 0x400 |
| 10-13 | 00 00 00 00 | No "data received" event |
| 14-17 | ? | Pointer to the "channel opened" event (`.data:0x0040EC70`), waited for before each message |
| 18-1B | 00 00 00 00 | No event 9 |

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcadsp8930.sys to [acpi.sys](./acpi.md#ioctl-0x32c004--ioctl_acpi_eval_method) (default I/O target, `WdfIoTargetSendIoctlSynchronously`).

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD (`CONF`) | ACPI node of the device | 8 | 512 |
| IOCTL_ACPI_EVAL_METHOD (`MANU`) | ACPI node of the device | 8 | 20 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature 'AeiB' (`ACPI_EVAL_INPUT_BUFFER_SIGNATURE`) |
| 04-07 | 43 4F 4E 46 or 4D 41 4E 55 | Method name `CONF` (in `SetupRpe`) or `MANU` (in `sub_401170`) |

`CONF`: the output buffer (signature 'AeoB') contains a package of integer pairs, the memory regions of the ADSP given to `RpeClientInitMultiSegment` (pool tags `qds5`, `qds6`), see [RPE](#rpe).  
`MANU`: the output must have the signature 'AeoB', exactly 1 argument, of type integer (0) and length 4; otherwise `STATUS_ACPI_INVALID_DATA` (0xC014000F). The integer is the manufacturer ID, see [Audio license](#audio-license).
