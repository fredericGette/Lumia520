## Qcwcn8930.sys

WCN subsystem (WCNSS / RIVA: Wi-Fi, Bluetooth, FM) driver.  
It loads the WCN image through [qcpil8930.sys](./qcpil8930.md), configures the `IRIS XO` clock, releases the WCNSS from reset, waits for it to come up through [qcsmsm8930.sys](./qcsmsm8930.md), then creates the PDOs of the Bluetooth, the Wi-Fi and the FM radio (it's the bus driver of [qcbluetooth8930.sys](./qcbluetooth8930.md), qcwlan8930.sys and qcfmtransport8930.sys).  
It also handles the WCN crashes: SubSystem Restart (SSR) when it's enabled, bug check otherwise.  
It's a client of the RPE notifier [qcrpen8930.sys](./qcrpen8930.md) (client name `WCN`).  
The PDB path embedded in the binary is `E:\build_e\subtask\916AB28C_98\output\wcn\fre\FAME\qcwcn8930.pdb`.

There's no named device object and no symbolic link.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcwcn`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0E20\2&daba3ff&0`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0079`

Registry value read from the **driver (software) key** of the device `HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0079` (`WdfDeviceOpenRegistryKey(PLUGPLAY_REGKEY_DRIVER)`, in `EvtDriverDeviceAdd`):  
| Registry value | value | comment |
|----------------|-------|---------|
| WcnImagePath | `\SystemRoot\system32\qcwcnss8930.mbn` | REG_SZ. Filename of the WCN image. Default is `C:\Windows\System32\WCNSS.MBN` (with a warning in the logs) |

Registry values read from `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcwcn\Parameters` (`WdfDriverOpenParametersRegistryKey`, `LoadDriverParameters` = `sub_40B67C`):  
| Registry value | value | comment |
|----------------|-------|---------|
| RestartEnabled | 0x00=SSR(SubSystem Restart) disabled, 0x01=SSR enabled, 0x02=WCN_RESTART_SURPRISE_REMOVE_ONLY | REG_DWORD. Default 1 when the value is missing, 0 when the Parameters key can't be opened. Any other value → 0. With 0, a crash of the WCNSS bug checks the phone; with 2, there's no bug check and no restart: the children are surprise removed and the device is failed |
| MaxRestartCount | 30 | REG_DWORD, default 30. Read only if RestartEnabled=1. Maximum number of loads of the image before the restart is abandoned |
| RestartTimer | 60 | REG_DWORD, default 60, in minutes. Read only if RestartEnabled=1. Period of the timer `WcnEvtClearRestartCount` (`sub_402070`) that resets the restart count to 1 |

GUID of the WPP control provider:  
`{98D8E493-33D4-4802-AD80-4DD111760D19}`  
WPP trace message GUIDs: `{a9cea867-33fb-d585-3562-c86cdf67dc8e}`, `{c1cbcc0f-8890-ecb9-5236-20d1c4d45820}`

GUID of the ETW provider of the RPE helper library (`McGenEventRegister` in `RpeInit`):  
`{57e95397-c84e-4f53-9473-56207aaa5938}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\RPEN | [qcrpen8930.sys](./qcrpen8930.md) | RPE Notifier. See [RPE](#rpe) |
| \Device\SMSM | [qcsmsm8930.sys](./qcsmsm8930.md) | Shared Memory State Machine. [internal IOCTL 0x32008](#internal-ioctl-0x32008), [internal IOCTL 0x32010](#internal-ioctl-0x32010), [IOCTL 0x3200C](#ioctl-0x3200c) |
| \Device\PIL | [qcpil8930.sys](./qcpil8930.md) | Peripheral Image Loader. [IOCTL 0x9C41241C](#ioctl-0x9c41241c), [IOCTL 0x9C412420](#ioctl-0x9c412420), [IOCTL 0x9C412410](#ioctl-0x9c412410) |
| ACPI node of the device (default I/O target) | [acpi.sys](./acpi.md) | [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method) `IOCTL_ACPI_EVAL_METHOD`, method `CONF` |
| Power framework (PEP) | ? | `PoFxPowerControl`, see [Power management](#power-management) |

### WDF setup

`EvtDriverDeviceAdd` (0x40C120):
- Default child list (bus driver), `WdfDeviceSetStaticStopRemove(FALSE)`.
- The device context is also saved in the global `gpDeviceContext` (`.data:0x00408BC0`), used by the crash path.
- Parallel default queue with `EvtIoDeviceControl` (`sub_40CBA0`). It completes **every** request without looking at the code: `STATUS_INVALID_DEVICE_REQUEST` when the WCN interface is published, 0xA0008100 otherwise. The driver has no IOCTL of its own.
- 2 I/O targets (SMSM, PIL), 4 work items, 2 timers (see [State machine](#state-machine)).
- Reads the registry (see above).
- `SetupInterrupt` (`sub_40A008`): one interrupt, ISR `sub_40139C` (queues the DPC), DPC `sub_4013C8` = WCN watchdog bite, see [Crash handling](#crash-handling).
- `SetupRpe` (`sub_40A0C0`), see [RPE](#rpe).
- `WdfDeviceAssignS0IdleSettings` (IdleCannotWakeFromS0, D3) and `WdfDeviceWdmAssignPowerFrameworkSettings` (`sub_40D3F4`), see [Power management](#power-management).
- `WdfDeviceSetBusInformationForChildren`: bus type GUID `{7CE30957-F54B-45BF-AA20-C1F5677D5F48}`, legacy bus type 15 (PNPBus), bus number 0.
- If RestartEnabled=1, starts the periodic timer `WcnEvtClearRestartCount` (period = RestartTimer minutes).

`EvtDeviceSelfManagedIoInit` (`OnSelfManagedIoInit` = `sub_40CD5C`): opens `\Device\SMSM`, gets the 2 function pointers of qcsmsm8930.sys ([0x32008](#internal-ioctl-0x32008) and [0x32010](#internal-ioctl-0x32010)), creates the 2 requests and the 12-byte buffers of the [0x3200C](#ioctl-0x3200c) waits (pool tags `qrs9`, `qrsa`), then opens `\Device\PIL` (`OpenPublisherDevice` = `sub_40B114`).  
`EvtDeviceSelfManagedIoCleanup` (`sub_40D258`): cancels the pending 0x3200C requests, closes the I/O targets, deinitialises RPE.  
`EvtDeviceSurpriseRemoval` (`OnSurpriseRemoval` = `sub_40D344`): revokes the WCN interface.

### Child devices

After the WCNSS is up, state 0 of the [state machine](#state-machine) (`sub_40DC34`) adds 3 children with `WdfChildListAddOrUpdateChildDescriptionAsPresent`. `EvtChildListCreateDevice` (`sub_40DE08`) creates their PDOs:  
| Child | Device ID / Hardware ID | Driver | Log name |
|-------|-------------------------|--------|----------|
| 1 | `ACPI\QCOM01E0` | [qcbluetooth8930.sys](./qcbluetooth8930.md) | bth |
| 2 | `ACPI\QCOM0E50` | qcwlan8930.sys ? | wlan |
| 3 | `QWCN\QCOM2150` | qcfmtransport8930.sys ? | fmt |

Common properties of the PDOs: device type `FILE_DEVICE_BUS_EXTENDER` (0x2A), instance ID `1`, device description `WCN_Child%02d` (e.g. `WCN_Child01`) and location `WCN Bus 0` (locale 0x409), PnP capabilities `Address` and `UINumber` = child number.  
Each PDO exposes the query-interface `GUID_BUS_INTERFACE_STANDARD` `{496B8280-6F25-11D0-BEAF-08002BE2092F}`.  
A counter of children (+ an event, `sub_40E31C` = `EvtCleanupCallback` of the PDO) tracks when all the PDOs are deleted.  
The children are removed (rescan of an empty child list) when the WCNSS crashes.

### Lumia 520 ACPI node

From the DSDT. The node is `\_SB.RIVA` (`_HID` `QCOM0E20`, no `_UID`). It declares `_DEP` on `\_SB.PEP0`, `\_SB.PMIC` ([qcpmic8930.sys](./qcpmic8930.md)), `\_SB.SMSM` ([qcsmsm8930.sys](./qcsmsm8930.md)), `\_SB.PILC` ([qcpil8930.sys](./qcpil8930.md)) and `\_SB.SMD0` ([qcsmd8930.sys](./qcsmd8930.md)).

- `_CRS`: one interrupt, `Interrupt (Edge, ActiveHigh, Exclusive)` 231. It's the WCNSS watchdog bite handled by `SetupInterrupt` (see [Crash handling](#crash-handling)).
- `CONF` returns `Package (1) { Package (2) { 0x8F200000, 0x0500 } }`. The second integer is a number of 4 KB pages, not bytes: 0x500 pages = 5 MB (0x8F200000–0x8F6FFFFF). With this unit the `CONF` regions of the subsystems are contiguous: AMSS 0x89000000 + 0x4400 pages = 0x8D400000, … ADSP 0x8DA00000 + 0x1800 pages = 0x8F200000 = WCNSS. This matches the RPE segment format (physical address, number of pages, see [qccdi8930.sys](./qccdi8930.md#memory-layout-of-a-subsystem)).
- Child nodes, matching the 3 children created by the driver (`_ADR` = child number):  

| Node | `_ADR` / `_HID` | Child | Content |
|------|-----------------|-------|---------|
| `\_SB.RIVA.BTH0` | `_ADR` 1 | Bluetooth (`ACPI\QCOM01E0`, [qcbluetooth8930.sys](./qcbluetooth8930.md)) | Nothing else |
| `\_SB.RIVA.QWLN` | `_ADR` 2 | WLAN (`ACPI\QCOM0E50`) | `_CRS`: `Memory32Fixed` 0x03000000, 0x1000000 (WCNSS register space), `Interrupt (Level, ActiveHigh, Shared, Wake)` 234, `Interrupt (Level, ActiveHigh, Exclusive)` 235. `_PRW` {0, 0}, `_S0W` = `_S4W` = 2 (D2). Empty `_DIS`, `_PS0`…`_PS3` |
| `\_SB.RIVA.FMT0` | `_ADR` 3 | FM transport (`QWCN\QCOM2150`) | Nothing else |
| `\_SB.RIVA.WPXY` | `_HID` `NOKIA_WLAN_PROXY` | — | Enumerated by acpi.sys, not by this driver |

acpi.sys presumably attaches these `_ADR` nodes to the PDOs created by the driver (matched by `Address`), which gives the WLAN child its memory and interrupt resources ?  
A separate top-level node `\_SB.FTM0` (`_HID` `QCOM01E1`, no resources) also exists (factory test mode ?).

### Interface GUID

WCN device interface, published (`WdfDeviceCreateDeviceInterface` + `WdfDeviceSetDeviceInterfaceState`, `PublishDeviceInterfaceClass` = `sub_40B47C`) when the WCNSS is ready and revoked when it crashes or the device is removed:  
`{917DF3C3-4938-4056-8F74-D3501BCD51EA}`

### RPE

`SetupRpe` (`sub_40A0C0`):
1. Evaluates the ACPI method `CONF` of the device ([IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method), output buffer of 512 bytes). The result is a package of integer pairs (base address, size in 4 KB pages, see [Lumia 520 ACPI node](#lumia-520-acpi-node)) = memory regions of the WCNSS added to the crash dump. If the method doesn't exist (`STATUS_OBJECT_NAME_NOT_FOUND`), the log says "No memory region data in the ACPI, the modem RAM will not be included in the crash dump files" and the client is registered without memory segment.
2. `RpeInit` (waits for the Helper interface `{59752ed7-b9d5-4121-818d-c69f1e667015}` of [qcrpen8930.sys](./qcrpen8930.md)), then `RpeClientInitMultiSegment` with the client GUID `{93367D0F-35CE-4EC4-8E38-BB33030C58B2}`, the name `WCN`, the memory segments and the callback table `{16 (size of the table), sub_401938, sub_4019C8, sub_401A48}` (see the [RPE client record](./qcrpen8930.md#rpe-client-record)).
3. `RegisterRPEStateNotification` on the RPE clients SMD (RIVA) `{D30F94E9-9C90-4ED5-AE04-9266277C4721}` of [qcsmd8930.sys](./qcsmd8930.md) and SMSM (RIVA) `{3AABE343-4EA2-43F8-8404-8A4A01088DCF}` of [qcsmsm8930.sys](./qcsmsm8930.md), callback `WcnStateNotificationCallback` (`sub_40A830`). When one of them reaches state 4, a work item (`sub_40EE8C`) sends event 2 (SMD) or event 3 (SMSM) to the [state machine](#state-machine).

States sent by the driver (`RpeSendState`):  
| State | Name in the logs | When |
|-------|------------------|------|
| 4 | `RPE_STATE_ID_RESTARTING` | State 9, the WCNSS is going to be restarted |
| 5 | `RPE_STATE_ID_READY_FOR_COMMANDS` | State 20, after the WCN interface is published |
| 7 | `RPE_STATE_ID_ERROR` | States 2 and 3, the WCNSS crashed |

Callback [1] `sub_401938` ("apps state" callback): 7 = fatal error of the HLOS, sent by [qccdi8930.sys](./qccdi8930.md) before it dumps the subsystem memory. `sub_401188` calls `FuncSmsmReset(0)` (sets `SMSM_RESET` in `SMSM_APPS_STATE`, asks the WCNSS to halt and flush its caches), then polls `smsm_state_get(SMSM_WCNSS_STATE)` up to 1,600,000 times until the WCNSS sets its own `SMSM_RESET` bit (0x40). Other values are ignored. Callbacks [2] (`sub_4019C8`) and [3] (`sub_401A48`, command callback) are no-ops.

### Crash handling

A crash of the WCNSS is detected in 2 ways:
- Watchdog bite: the interrupt of the device (ISR `sub_40139C`, DPC `sub_4013C8`). Log: "Detected watch dog bite from the WCN subsystem!".
- Fatal error: the WCNSS sets `SMSM_RESET` in its SMSM state, which completes the pending [IOCTL 0x3200C](#ioctl-0x3200c) (completion routine `EvtSSError` = `sub_40150C`). Log: "Detected fatal error from the WCN subsystem!".

In both cases, if RestartEnabled=0, the driver calls `KeBugCheckEx(0x14B, &{2, …})`: bug check `SOC_SUBSYSTEM_FAILURE`, parameter 1 points to a structure whose first DWORD is 2 (`SOC_SUBSYS_WIRELESS_CONNECTIVITY`).  
Otherwise, it queues the work item that sends event 5 to the [state machine](#state-machine).

### Power management

`WdfDeviceWdmAssignPowerFrameworkSettings` (`sub_40D3F4`): one component with one idle state (nominal power 5), `EvtDeviceWdmPostPoFxRegisterDevice` = `sub_40D368` (stops the idle tracking and sends event 1 to the state machine), `EvtDeviceWdmPrePoFxUnregisterDevice` = `sub_40D3BC`, power control callback `PEPPowerControlCallback` = `sub_401C50`.

The P-states of the WCN are changed by `TransitionPState` (`sub_40D9D0`) with `PoFxPowerControl`:  
PowerControlCode `{3404DAAC-8E2C-41E4-8458-3158E5AD442B}`  

Inputbuffer (8 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Component index ? (the WCN has only component 0) |
| 04-07 | 00 00 00 00 | P-state: 0 = P0 (WCNSS powered, before the image is loaded), 1 = P1 (after the children are created) |

Outputbuffer (12 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | 3 = `PEP_STATE_SYNC_PATH` (done), 1 = `PEP_STATE_ASYNC_PATH_IN_PROGRESS` (the PEP calls `PEPPowerControlCallback` with code 2 when the transition is done, which sends event 4) |
| 04-0B | ? | ? |

The same PowerControlCode is used by [qcdxkm8930.sys](./qcdxkm8930.md#other-guid) to change the P-state of its engines (`sub_4A2E68`), through `DxgkCbPowerRuntimeControlRequest` with a 16-byte input: `00-03` component index, `04-07` P-state (clamped to the component's limits), `08-0B` signature `4D 50 50 52` ("MPPR"), `0C-0F` pointer to an event (or 0). Same 12-byte output: when `00-03` is not 3, qcdxkm8930 waits up to 1 s for the event. This supports reading `00-03` above as the component index.

### State machine

`sub_40E3C4(deviceContext, event)` (the logs print the event as "2nd parameter value" and the new state as "switch value").  
The transitions on events are in a table at `.data:0x00408168` (state, event, new state); the states with an action go on directly to the next state. An event that isn't in the table is dropped ("dropping unexpected event").

Events:  
| Event | Source |
|-------|--------|
| 1 | PoFx registration of the device (`sub_40D368`) |
| 2 | SMD (RIVA) RPE client reached state 4 |
| 3 | SMSM (RIVA) RPE client reached state 4 |
| 4 | WCNSS up (`EvtSSUp`, [IOCTL 0x3200C](#ioctl-0x3200c) wait on `SMSM_INIT`) or end of an asynchronous P-state transition |
| 5 | WCNSS crashed (watchdog bite, `SMSM_RESET`, or failure of the `SMSM_INIT` wait) |
| 6 | 17-second timer started in state 18 |

States:  
| State | Action | Next state |
|-------|--------|------------|
| 6 | Initial state | event 1 → 19 |
| 19 | P0 | sync → 7, async → 10, error → 4 |
| 10 | Wait for P0 | event 4 → 7 |
| 7 | Arm the 2 [0x3200C](#ioctl-0x3200c) waits, increment the restart count, load the image ([0x9C41241C](#ioctl-0x9c41241c)), configure IRIS XO, auth and reset ([0x9C412410](#ioctl-0x9c412410)) | OK → 21, error → 3 |
| 21 | Wait for the WCNSS | event 4 → 18, event 5 → 3 |
| 18 | Start a 17-second one-shot timer | event 6 → 0, event 5 → 1 |
| 0 | Create the [child devices](#child-devices) | OK → 20, error → 4 |
| 20 | P1, publish the [WCN interface](#interface-guid), `RpeSendState(5)` | sync → 8, async → 11, error → 4 |
| 11 | Wait for P1 | event 4 → 8, event 5 → 12 |
| 12 | | event 4 → 2 |
| 8 | Running | event 5 → 2 |
| 1 | Revoke the WCN interface | event 6 → 3 |
| 2 | Cancel the `SMSM_RESET` wait, remove the children, revoke the interface, `RpeSendState(7)` | RestartEnabled=2 or restart count > MaxRestartCount → 4, otherwise → 14 |
| 14 | P0 | sync → 9, async → 15 (no transition from 15 ?), error → 4 |
| 3 | Cancel both waits, remove the children, `RpeSendState(7)` | RestartEnabled=1 and restart count ≤ MaxRestartCount → 9, otherwise → 5 |
| 9 | `RpeSendState(4)` | event 2 → 16, event 3 → 17, event 5 → 3 |
| 16 | Wait for SMSM (RIVA) | event 3 → 13, event 5 → 3 |
| 17 | Wait for SMD (RIVA) | event 2 → 13, event 5 → 3 |
| 13 | Same as 7 but reloads the image ([0x9C412420](#ioctl-0x9c412420)) | OK → 21, error → 3 |
| 5 | P1 (`WCN_STATE_IMAGE_LOAD_FAILED` in the logs) | → 4 |
| 4 | Final (`WCN_STATE_FINAL`): stop the restart timer, `WdfDeviceSetFailed(WdfDeviceFailedNoRestart)` | |

The normal start in the logs below is: event 1 → 19 → 7 → 21, event 4 → 18, event 6 → 0 → 20 → 8.

### IRIS XO clock

Qcwcn8930.sys configures the `IRIS XO` clock of the WCN subsystem by updating the `PMU_CFG` register (Power Management Unit configuration register), `sub_40D864`, between the load of the image and the auth and reset.  
The physical address of this register is hardcoded in the driver: 0x03204028  

The configuration of the `IRIS XO` clock is done by the following algorithm:

1. Write 0x00000000
2. Delay for 500 microseconds
3. Set bits 4 (IRIS_XO_EN) and 5 (GC_BUS_MUX_SEL)
4. Delay for 500 microseconds
5. Clear bits 1 and 2 (IRIS_XO_MODE = 2'b00: 19.2MHz TCXO)
6. Delay for 500 microseconds
7. Set bit 3 (IRIS_XO_CFG)
8. Delay for 500 microseconds
9. Loop while bit 6 (IRIS_XO_CFG_STS) is set, delay for 600 microseconds in each iteration.
10. Clear bits 3 (IRIS_XO_CFG) and 5 (GC_BUS_MUX_SEL)
11. Delay for 500 microseconds
12. Delay for 200 milliseconds

| Bit | Name | Comment |
|-----|------|---------|
| 0 | WARM_BOOT | warm/cold boot indication. |
| 2,1 | IRIS_XO_MODE | IRIS XO mode. 2'b11 : 48MHz XO 2'b01 : 38.4MHz TCXO 2'b00 :19.2MHz TCXO |
| 3 | IRIS_XO_CFG | start IRIS XO configuration |
| 4 | IRIS_XO_EN | 0x1: enable XO during configuration 0x0: disable XO during configuration |
| 5 | GC_BUS_MUX_SEL | 0x1: GC bus is controlled by riva_top 0x0: GC bus is controlled by WLAN PHY |
| 6 | IRIS_XO_CFG_STS | IRIS XO configuration status. 0x1: in progress 0x0: done or idle |

Example of WPP logs at the start of the phone:
```
[1]0004.0084::06/06/2025-12:19:03.186 [qcwcn8930_guid01]!EvtDriverDeviceAdd[58]!Enter
[1]0004.0084::06/06/2025-12:19:03.187 [qcwcn8930_guid01]!EvtDriverDeviceAdd[60]!WdfDeviceCreate succeeded, hDevice=7417FC10
[1]0004.0084::06/06/2025-12:19:03.188 [qcwcn8930_guid01]!DriverEntry[28]!Enter
[1]0004.0084::06/06/2025-12:19:03.189 [qcwcn8930_guid01]!read_Registry[29]!Will load the subsystem image from the path obtained from registry: \SystemRoot\system32\qcwcnss8930.mbn
[1]0004.0084::06/06/2025-12:19:03.190 [qcwcn8930_guid01]!read_Registry[35]!RestartEnabled=1, WCN SSR will be enabled
[1]0004.0084::06/06/2025-12:19:03.191 [qcwcn8930_guid01]!read_Registry[36]!MaxRestartCount, WdfRegistryQueryULong returned 0xc0000034(STATUS_OBJECT_NAME_NOT_FOUND)
[1]0004.0084::06/06/2025-12:19:03.191 [qcwcn8930_guid01]!read_Registry[37]!Default value will be used for MaxRestartCount
[1]0004.0084::06/06/2025-12:19:03.193 [qcwcn8930_guid01]!read_Registry[38]!MaxRestartCount=30
[1]0004.0084::06/06/2025-12:19:03.200 [qcwcn8930_guid01]!read_Registry[39]!RestartTimer, WdfRegistryQueryULong returned 0xc0000034(STATUS_OBJECT_NAME_NOT_FOUND)
[1]0004.0084::06/06/2025-12:19:03.201 [qcwcn8930_guid01]!read_Registry[40]!Default value will be used for RestartTimer
[1]0004.0084::06/06/2025-12:19:03.201 [qcwcn8930_guid01]!read_Registry[41]!RestartTimer=60
[1]0004.0084::06/06/2025-12:19:03.203 [qcwcn8930_guid04]!RpeInit[36]!RpeInit OK
[1]0004.0084::06/06/2025-12:19:03.203 [qcwcn8930_guid04]!RpeInit[37]!Guid is 93367d0f-35ce-4ec4-8e38-bb33030c58b2
[1]0004.0084::06/06/2025-12:19:03.204 [qcwcn8930_guid04]!RpeInit[38]!Driver name is WCN
[1]0004.0084::06/06/2025-12:19:03.205 [qcwcn8930_guid04]!RpeInit[39]!Version is 0
[1]0004.0084::06/06/2025-12:19:03.206 [qcwcn8930_guid04]!RpeInit[40]!Size is 16
[0]0004.0084::06/06/2025-12:19:03.208 [qcwcn8930_guid04]!RpeInit[41]!RpeClientInitMultiSegment returned STATUS_SUCCESS. RpeClientInitMultiSegment OK or RPE driver not avail. Continue
[0]0004.0084::06/06/2025-12:19:03.217 [qcwcn8930_guid04]!RegisterRPEStateNotification[51]!Waiting for readiness of WCN subsystem
[0]0004.0084::06/06/2025-12:19:03.222 [qcwcn8930_guid04]!RpeInit[43]!RegisterRPEStateNotification with GUID_05 returned STATUS_SUCCESS. RegisterRPEStateNotification OK or RPE driver not avail. Continue
[0]0004.0084::06/06/2025-12:19:03.224 [qcwcn8930_guid04]!RegisterRPEStateNotification[51]!Waiting for readiness of WCN subsystem
[0]0004.0084::06/06/2025-12:19:03.230 [qcwcn8930_guid04]!RpeInit[45]!RegisterRPEStateNotification with GUID_06 returned STATUS_SUCCESS. RegisterRPEStateNotification OK or RPE driver not avail. Continue
[1]0004.01B4::06/06/2025-12:19:04.079 [qcwcn8930_guid01]!OpenIOTargetByName[103]!Target Device PDEVICE_OBJECT=8BDFB030
[1]0004.01B4::06/06/2025-12:19:04.081 [qcwcn8930_guid01]!OpenIOTargetByName[104]!PDO PDEVICE_OBJECT=88958A90
[1]0004.01B4::06/06/2025-12:19:04.082 [qcwcn8930_guid01]!OpenIOTargetByName[105]!File Object PFILE_OBJECT=8BFCBBD8
[1]0004.01B4::06/06/2025-12:19:04.083 [qcwcn8930_guid01]!OpenIOTargetByName[106]!File Handle HANDLE=800004D4
[1]0004.01B4::06/06/2025-12:19:04.084 [qcwcn8930_guid01]!SendInternalIoctlSynchronously[107]!Enter
[1]0004.01B4::06/06/2025-12:19:04.084 [qcwcn8930_guid01]!SendInternalIoctlSynchronously[107]!Enter
[1]0004.01B4::06/06/2025-12:19:04.085 [qcwcn8930_guid01]!OpenIOTarget_PIL[12]!Enter
[1]0004.01B4::06/06/2025-12:19:04.086 [qcwcn8930_guid01]!OpenIOTarget_PIL[16]!Target Device PDEVICE_OBJECT=8BC9BD98
[1]0004.01B4::06/06/2025-12:19:04.087 [qcwcn8930_guid01]!OpenIOTarget_PIL[17]!PDO PDEVICE_OBJECT=8895B850
[1]0004.01B4::06/06/2025-12:19:04.088 [qcwcn8930_guid01]!OpenIOTarget_PIL[18]!File Object PFILE_OBJECT=8BFCFA28
[1]0004.01B4::06/06/2025-12:19:04.089 [qcwcn8930_guid01]!OpenIOTarget_PIL[19]!File Handle HANDLE=800004B8
[1]0004.01B4::06/06/2025-12:19:04.089 [qcwcn8930_guid01]!OpenIOTarget_PIL[20]!Succeeded in opening IOTarget on PIL driver, saved IOTarget to device context
[1]0004.01B4::06/06/2025-12:19:04.091 [qcwcn8930_guid01]!sub_40E3C4[133]!2nd parameter value=1
[1]0004.01B4::06/06/2025-12:19:04.092 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=19
[1]0004.01B4::06/06/2025-12:19:04.092 [qcwcn8930_guid01]!call_PoFxPowerControl[109]!Enter
[0]0004.01B4::06/06/2025-12:19:04.114 [qcwcn8930_guid01]!call_PoFxPowerControl[110]!PoFxPowerControl returns STATUS_SUCCESS
[0]0004.01B4::06/06/2025-12:19:04.115 [qcwcn8930_guid01]!call_PoFxPowerControl[111]!PoFxPowerControl output status PEP_STATE_SYNC_PATH
[0]0004.01B4::06/06/2025-12:19:04.119 [qcwcn8930_guid01]!call_PoFxPowerControl[112]!exit 2nd parameter value=0x00000000(FALSE)
[0]0004.01B4::06/06/2025-12:19:04.120 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=7
[0]0004.01B4::06/06/2025-12:19:04.120 [qcwcn8930_guid04]!send_IoCtl_0x3200C_Request_01[52]!Enter
[0]0004.01B4::06/06/2025-12:19:04.121 [qcwcn8930_guid04]!send_IoCtl_0x3200C_Request_02[52]!Enter
[0]0004.01B4::06/06/2025-12:19:04.122 [qcwcn8930_guid01]!sub_40E3C4[150]!Performing Load image and reset hardware for WCNSS...
[0]0004.01B4::06/06/2025-12:19:04.123 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[44]!Enter
[0]0004.01B4::06/06/2025-12:19:04.124 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[46]!Requesting PIL driver to load WCN image
[0]0004.01B4::06/06/2025-12:19:04.126 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[47]!Request to load WCN image created, sending to PIL driver
[1]0004.01B4::06/06/2025-12:19:04.190 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[52]!WCN image loaded, Physical address returned from PIL driver: 8F001228
[1]0004.01B4::06/06/2025-12:19:04.192 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[53]!Loaded WCN subsystem hardware with image: \SystemRoot\system32\qcwcnss8930.mbn
[1]0004.01B4::06/06/2025-12:19:04.193 [qcwcn8930_guid01]!sub_40E3C4[152]!Loading image for WCN subsystem through PIL succeeded
[1]0004.01B4::06/06/2025-12:19:04.494 [qcwcn8930_guid01]!sub_40E3C4[153]!IRIS XO clock is configured
[1]0004.01B4::06/06/2025-12:19:04.495 [qcwcn8930_guid01]!AuthAndRelease[54]!Enter
[1]0004.01B4::06/06/2025-12:19:04.496 [qcwcn8930_guid01]!AuthAndRelease[55]!Requesting PIL driver to reset WCN hardware after the image is loaded
[1]0004.01B4::06/06/2025-12:19:04.936 [qcwcn8930_guid01]!AuthAndRelease[118]!AuthAndRelease value=10
[1]0004.01B4::06/06/2025-12:19:04.938 [qcwcn8930_guid01]!sub_40E3C4[155]!Authorize and Reset for WCN subsystem through PIL succeeded
[1]0004.01B4::06/06/2025-12:19:04.939 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=21
[0]0004.015C::06/06/2025-12:19:05.018 [qcwcn8930_guid04]!EvtSSUp[53]!Enter
[0]0004.015C::06/06/2025-12:19:05.020 [qcwcn8930_guid04]!EvtSSUp[54]!WCN subsystem is up and running
[1]0004.0178::06/06/2025-12:19:05.021 [qcwcn8930_guid01]!sub_40E3C4[133]!2nd parameter value=4
[1]0004.0178::06/06/2025-12:19:05.022 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=18
[0]0004.0178::06/06/2025-12:19:22.278 [qcwcn8930_guid01]!sub_40E3C4[133]!2nd parameter value=6
[0]0004.0178::06/06/2025-12:19:22.280 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=0
[0]0004.0178::06/06/2025-12:19:22.281 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=20
[0]0004.0178::06/06/2025-12:19:22.282 [qcwcn8930_guid01]!call_PoFxPowerControl[109]!Enter
[1]0004.0198::06/06/2025-12:19:22.283 [qcwcn8930_guid01]!call_PoFxPowerControl[123]!Enter
[1]0004.0198::06/06/2025-12:19:22.284 [qcwcn8930_guid01]!call_PoFxPowerControl[123]!Enter
[1]0004.0198::06/06/2025-12:19:22.285 [qcwcn8930_guid01]!call_PoFxPowerControl[123]!Enter
[0]0004.0178::06/06/2025-12:19:22.291 [qcwcn8930_guid01]!call_PoFxPowerControl[110]!PoFxPowerControl returns STATUS_SUCCESS
[0]0004.0178::06/06/2025-12:19:22.292 [qcwcn8930_guid01]!call_PoFxPowerControl[111]!PoFxPowerControl output status PEP_STATE_SYNC_PATH
[0]0004.0178::06/06/2025-12:19:22.295 [qcwcn8930_guid01]!call_PoFxPowerControl[112]!exit 2nd parameter value=0x00000001(TRUE)
[0]0004.0178::06/06/2025-12:19:22.296 [qcwcn8930_guid01]!change_InterfaceClassGUID_state[23]!Enter
[1]0004.0178::06/06/2025-12:19:22.298 [qcwcn8930_guid01]!change_InterfaceClassGUID_state[26]!WCN device interface is published
[1]0004.0178::06/06/2025-12:19:22.298 [qcwcn8930_guid01]!setField30[22]!Enter
[1]0004.0178::06/06/2025-12:19:22.299 [qcwcn8930_guid01]!sub_40E3C4[147]!published interface successfully
[1]0004.0178::06/06/2025-12:19:22.301 [qcwcn8930_guid01]!sub_40E3C4[149]!RPE_STATE_ID_READY_FOR_COMMANDS
[1]0004.0178::06/06/2025-12:19:22.302 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=8
```

---

### internal IOCTL 0x32008

This IOCTL is sent by Qcwcn8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#internal-ioctl-0x32008) in `OnSelfManagedIoInit`.  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_INTERNAL_SMSM_RESET | \Device\SMSM | 4 | 4 |

Content of the input buffer (ignored by qcsmsm8930.sys):  
| Bytes 00-03 | 
|-------------|
| 01 00 00 00 | 

The output buffer contains a pointer to the function `FuncSmsmReset`. It's called with 0 when the HLOS crashes (apps state 7 from qccdi8930.sys, see [RPE](#rpe)).

---

### internal IOCTL 0x32010

This IOCTL is sent by Qcwcn8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#internal-ioctl-0x32010) in `OnSelfManagedIoInit`.  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_INTERNAL_SMSM_STATE_GET | \Device\SMSM | 0 | 4 |

The output buffer contains a pointer to the function `smsm_state_get`. It's called with `SMSM_WCNSS_STATE` (3) when the HLOS crashes (apps state 7 from qccdi8930.sys, see [RPE](#rpe)).

---

### IOCTL 0x3200C

This IOCTL is sent by Qcwcn8930.sys to [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x3200c) (`WdfIoTargetFormatRequestForIoctl` + `WdfRequestSend`, asynchronous).  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Wait for a state | \Device\SMSM | 12 | 0 |

The request stays pending in qcsmsm8930.sys until `(state & state_mask) == expected_state`; then its completion routine is called. 2 requests are sent before each load of the image (states 7 and 13 of the [state machine](#state-machine)):

Wait for the start of the WCNSS (`sub_40AC3C`, completion routine `EvtSSUp` = `sub_401750`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | SMSM_WCNSS_STATE |
| 04-07 | 01 00 00 00 | state_mask: SMSM_INIT |
| 08-0B | 01 00 00 00 | expected_state: SMSM_INIT |

On success, the log says "WCN subsystem is up and running" and event 4 is sent to the state machine. On error (except `STATUS_CANCELLED`), event 5.

Wait for a crash of the WCNSS (`sub_40AB44`, completion routine `EvtSSError` = `sub_40150C`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 03 00 00 00 | SMSM_WCNSS_STATE |
| 04-07 | 40 00 00 00 | state_mask: SMSM_RESET |
| 08-0B | 40 00 00 00 | expected_state: SMSM_RESET |

On success, see [Crash handling](#crash-handling) (bug check 0x14B if RestartEnabled=0).

---

### IOCTL 0x9C41241C

This IOCTL is sent by Qcwcn8930.sys to [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c41241c--ioctl_pil_tz_load_image) (`LoadImage` = `sub_40BBB4`, first load)  

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
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | 06 00 00 00 | Null terminated WCHAR string `\SystemRoot\system32\qcwcnss8930.mbn` |

The first 16 bytes of the input buffer is the GUID of the RPE client:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

The bytes 10-13 are the secured channel ID (PAS peripheral ID 6 = WCNSS).

The output buffer contains the physical address of the entry point (`e_entry`) of the image (e.g. 0x8F001228, see the logs above).  
qcpil8930.sys parses the file, maps its segments at their physical addresses and sends the SCM command 0x801 "Init image". The WCNSS is started later by IOCTL 0x9C412410.

---

### IOCTL 0x9C412420

This IOCTL is sent by Qcwcn8930.sys to [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c412420--ioctl_pil_tz_reload_image) (`LoadImage` = `sub_40BBB4`, restart of the WCNSS)  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x908 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_RELOAD_IMAGE | \Device\PIL | 20 | 4 |

Content of the input buffer:  
| Bytes 00-0F | Bytes 10-13 |
|-------------|-------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | 06 00 00 00 |

The first 16 bytes of the input buffer is the GUID of the RPE client:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

The bytes 10-13 are the secured channel ID (PAS peripheral ID 6 = WCNSS).

The output buffer contains the physical address of the entry point (`e_entry`) of the image.  
Used to restart the WCNSS: qcpil8930.sys sends the SCM command 0x806 "Shutdown", loads the image saved at the previous load again and sends 0x801 "Init image". It fails with 0xE0008000 if no image was loaded and authenticated before.

---

### IOCTL 0x9C412410

This IOCTL is sent by Qcwcn8930.sys to [qcpil8930.sys](./qcpil8930.md#ioctl-0x9c412410--ioctl_pil_tz_auth_image_and_reset) (`AuthAndRelease` = `sub_40BF80`)  

| Property | Value |
|----------|-------|
| Device | 0x9C41 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_AUTH_IMAGE_AND_RESET | \Device\PIL | 0 | 0 |

There is no input buffer: qcpil8930.sys applies the command to the image loaded (0x9C41241C or 0x9C412420) through the same handle. It sends the SCM command 0x805 "Auth and reset" with the channel ID given at the load: the TrustZone authenticates the image and takes the WCNSS out of reset.

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcwcn8930.sys to [acpi.sys](./acpi.md#ioctl-0x32c004--ioctl_acpi_eval_method) (default I/O target, `WdfIoTargetSendIoctlSynchronously`) in `SetupRpe`.

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI node of the device | 8 | 512 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature 'AeiB' (`ACPI_EVAL_INPUT_BUFFER_SIGNATURE`) |
| 04-07 | 43 4F 4E 46 | Method name `CONF` |

The output buffer (signature 'AeoB') contains a package of integer pairs: the memory regions of the WCNSS given to `RpeClientInitMultiSegment` (pool tags `qrs7`, `qrs8`), see [RPE](#rpe).
