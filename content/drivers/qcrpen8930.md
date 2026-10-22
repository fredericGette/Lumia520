## Qcrpen8930.sys

RPE Notifier (RPEN = Reset Power and Error Notifier).  
It's a registry/broker for the "RPE clients": the drivers that own a subsystem of the SoC (MODEM/AMSS, WCN, …), like [qcsmsm8930.sys](./qcsmsm8930.md) and [qcwcn8930.sys](./qcwcn8930.md). Each client registers with its GUID, a name, a callback table and the list of its memory segments. After that, clients can publish their state, wait for the state of another client, and send commands to each other.  
It also forwards the list of registered clients to the crash dump driver [qccdi8930.sys](./qccdi8930.md) (the "WPCD" client), so that their memory segments are included in a crash dump.  
Everything is exposed through two WDF query-interfaces (function tables). There's no hardware access. The only IOCTL broadcasts an "apps state" notification to the clients. The driver does the same thing when the system is about to enter a sleep state (`\Callback\PowerState`).  
Built from `P:\RPE\rel\8.3\arm\Release\qcrpen8930.pdb` (build date "Mar 24 2014 19:49:15").

Device name : `\Device\RPEN`  
Symbolic link : `\DosDevices\RPEN`  

Registry of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0E30\2&daba3ff&0` (ACPI node `\_SB.RPEN`, `_HID` `QCOM0E30`, no resources and no method in the DSDT)

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\<service>\Parameters` (`WdfDriverOpenParametersRegistryKey`, read by `RPEReadRegistry`):  
| Registry value | value | comment |
|----------------|-------|---------|
| SubsystemNotificationTimeout | 0 | REG_DWORD, in milliseconds. Read each time the system is about to enter a sleep state, after the "apps state" notification has been sent to the clients. When it's not 0, the power callback waits for this long (`KeDelayExecutionThread`) so the subsystems have time to react. Missing value = 0 = no delay |

GUID of the ETW provider (manifest-based, `EtwRegister` in `McGenEventRegister`):  
`{84CD9D5E-9773-4BA7-A709-72F079E81CDE}`

GUID of the WPP control provider:  
`{7311D40C-CE4F-496F-A563-F72D7BC9D92F}`  
WPP trace message GUID: `{F3C908C4-4C1D-BDBB-A4BC-5D98F5838B86}`

The driver doesn't open any other device. The other drivers call into it:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\RPEN, Helper interface | [qcsmsm8930.sys](./qcsmsm8930.md) | RPE client. Publishes the state of the MODEM and RIVA subsystems |
| \Device\RPEN, Helper interface | [qcwcn8930.sys](./qcwcn8930.md) | RPE client "WCN", GUID `{93367D0F-35CE-4EC4-8E38-BB33030C58B2}` (`RpeClientInitMultiSegment`, `RegisterRPEStateNotification` in its traces). Sends the states 4, 5 and 7; watches the SMD (RIVA) and SMSM (RIVA) clients for state 4. See [qcwcn8930.sys RPE](./qcwcn8930.md#rpe) |
| \Device\RPEN, Helper interface | [qcadsp8930.sys](./qcadsp8930.md) | RPE client "ADSP", GUID `{D58464D3-5B28-4EA6-A2E2-E8E57C5C69B8}` (`RpeClientInitMultiSegment`, second string `1`, segments from the ACPI method `CONF`). Sends the state 5; watches the WCN client for the states 4 and 5 and forwards them to the ADSP as SSR messages. See [qcadsp8930.sys RPE](./qcadsp8930.md#rpe) |
| WPCD interface | [qccdi8930.sys](./qccdi8930.md) | Crash dump interface. Registers the `RpeClientAdd` / `RpeClientRemove` callbacks and reads the subsystem descriptors |

### WDF setup

`NotifierEvtDeviceAdd` (0x40E3E8):
- IO type: `WdfDeviceIoBuffered`.
- PnP/power callbacks: `NotifierEvtDevicePrepareHardware`, `NotifierEvtDeviceReleaseHardware`, `NotifierEvtDeviceD0Entry`, `NotifierEvtDeviceD0Exit` only write a trace and return `STATUS_SUCCESS`. `EvtWdfDeviceSurpriseRemoval` disables both device interfaces.
- File object callbacks: `NotifierEvtDeviceFileCreate` gives each handle an `RPE_NOTIFIER_CLIENT_CONTEXT` (248 bytes) that is never used afterwards. `NotifierEvtDeviceFileClose` only traces.
- `WdfDeviceSetStaticStopRemove`, so the device can't be stopped or removed while it's in use.
- One default queue, sequential dispatch, not power-managed, passive level, `EvtIoDeviceControl` = `NotifierEvtIoDeviceControl`.
- 5 collections (WPCD client-add queue, WPCD client-remove queue, RPE clients, pending states, pending commands), 4 work items (`NotifierEvtWorkItemWpcdClientAdd`, `NotifierEvtWorkItemWpcdClientRemove`, `NotifierEvtWorkItemNotifyStates`, `NotifierEvtWorkItemNotifyCommands`) and 7 wait-locks.
- Two device interfaces + query-interfaces, WPCD and Helper (see below).
- `ExCreateCallback(\Callback\PowerState)` + `ExRegisterCallback(sub_4086A4)`. Unregistered in `NotifierEvtDriverUnload`.

Pool tag of the allocations: `aprq` (0x71727061).

Power callback `sub_4086A4`: only handles `Argument1` = 3 (`PO_CB_SYSTEM_STATE_LOCK`).  
- `Argument2` = 0 (system about to leave S0): calls `Notifier_NotifyAppsState` (same as [IOCTL 0x1002044](#ioctl-0x1002044)), then waits `SubsystemNotificationTimeout` ms.  
- `Argument2` = 1 (back to S0): only a trace.

### RPE client record

Each client registered through `Notifier_HelperInit` is stored as an `RPE_NOTIFIER_CLIENT_CONTEXT` (248 bytes) in the "RPE clients" collection. Clients are looked up by GUID (`_getClientContextByGUID`).  
| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 16 | Client GUID |
| 0x10 | 64 | Client name, ANSI, zero-terminated (e.g. `WCN`) |
| 0x50 | 128 | Second string, ANSI, zero-terminated (description ?) |
| 0xD0 | 4 | Callback table [0]. Never called by qcrpen8930.sys. It's not a function: [qcwcn8930.sys](./qcwcn8930.md#rpe) puts the size of the table there (16, logged as "Size is 16") |
| 0xD4 | 4 | Callback table [1]: "apps state" callback `void cb(Context, ULONG ApState, ULONG *State)`. Called by qcrpen8930.sys with 2. Also given to the WPCD client: [qccdi8930.sys](./qccdi8930.md) calls it with 7 (AP error) to halt the subsystem before the crash dump. In qcwcn8930.sys (`sub_401938`), 7 sets `SMSM_RESET` in `SMSM_APPS_STATE` and waits until the WCNSS sets its own `SMSM_RESET` bit (subsystem halted, caches flushed); any other value is ignored. In [qcadsp8930.sys](./qcadsp8930.md#rpe) (`sub_402604`), 7 sends an NMI to the QDSP6 |
| 0xD8 | 4 | Callback table [2]. Not called by qcrpen8930.sys, only given to the WPCD client (crash dump callback ?). No-op in qcwcn8930.sys (`sub_4019C8`). In [qcadsp8930.sys](./qcadsp8930.md#rpe) (`sub_4026B0`) it copies the last crash reason string of the subsystem into a caller buffer (`+0x10` size, `+0x14` string): probably "get crash reason" |
| 0xDC | 4 | Callback table [3]: command callback `cb(Context, RPE_COMMAND *Command, ULONG *State)`. No-op in qcwcn8930.sys (`sub_401A48`) and in [qcadsp8930.sys](./qcadsp8930.md#rpe) (`sub_402788`) |
| 0xE0 | 4 | Pointer to a pool copy of the memory segment array (16 bytes per segment: 64-bit base address, 64-bit size; qcwcn8930.sys builds it from the ACPI method `CONF`. On the Lumia 520 the `CONF` sizes are in 4 KB pages, see [qcwcn8930.sys](./qcwcn8930.md#lumia-520-acpi-node)) |
| 0xE4 | 1 | Number of memory segments |
| 0xE8 | 4 | Client context, passed as the first argument of every callback |
| 0xEC | 4 | 1 = registered with the WPCD (crash dump) client |
| 0xF0 | 4 | Current state of the client |
| 0xF4 | 4 | WDFCOLLECTION of this client's state-notification registrations |

### RPE_STATE structure

Used by `Notifier_HelperSendState`, `Notifier_HelperRegisterForStateNotification` and the state callbacks (24 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 18 00 00 00 | Size (24) |
| 04-13 | ? | GUID of the client whose state it is |
| 14-17 | ? | State, see the table below |

States:  
| State | Name | Comment |
|-------|------|---------|
| 0 | ? | Initial state set by `Notifier_HelperInit` |
| 4 | `RPE_STATE_ID_RESTARTING` | Name from the logs of [qcwcn8930.sys](./qcwcn8930.md#rpe), sent before the WCNSS is reloaded. The client is removed from the crash dump (see below) |
| 5 | `RPE_STATE_ID_READY_FOR_COMMANDS` | Name from the logs of qcwcn8930.sys, sent when the WCNSS is up and its children are created. Also sent by [qcadsp8930.sys](./qcadsp8930.md#rpe) when the ADSP is up |
| 7 | `RPE_STATE_ID_ERROR` | Name from the logs of qcwcn8930.sys, sent when the WCNSS crashed. Same value as the "AP error" state that [qccdi8930.sys](./qccdi8930.md) sends to callback [1] |
| 9 | ? | "Any state" when it's used as a registration filter |

The names of the other states are unknown.

### RPE_COMMAND structure

Used by `Notifier_HelperSendcommand` (44 bytes, copied whole into an `RPE_NOTIFIER_COMMAND_CONTEXT`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Size ? |
| 04-07 | ? | ? |
| 08-17 | ? | GUID of the sender. Must be a registered client |
| 18-27 | ? | GUID of the target. Must be a registered client with a command callback |
| 28-2B | ? | Command ? |

### Interface GUID

WPCD interface class GUID (device interface + query-interface)  
`{0B28C6F2-F696-4580-ACB5-BF16C614B1C2}`

Helper (RPE) interface class GUID (device interface + query-interface)  
`{59752ED7-B9D5-4121-818D-C69F1E667015}`

Both query-interfaces are registered with `WdfDeviceAddQueryInterface`. The standard `INTERFACE` header has `InterfaceReference` / `InterfaceDereference` = `nullsub_1` (no reference counting) and `Context` = the WDFDEVICE.

#### WPCD interface

Size 0x20 (32), Version 1. Used by the crash dump driver [qccdi8930.sys](./qccdi8930.md).  
| Offset | Function | Comment |
|--------|----------|---------|
| 0x10 | `Notifier_WpcdClientInit(RpeClientAdd, RpeClientRemove)` | Saves the two callbacks. Only one WPCD client: returns `STATUS_OBJECT_NAME_EXISTS` (0x40000000) if one is already registered, `STATUS_INVALID_PARAMETER` if a pointer is NULL |
| 0x14 | `Notifier_WpcdClientDeInit` | Forgets the WPCD client |
| 0x18 | `Notifier_WpcdGetNumSubsystemDescriptors(ULONG *Count)` | Number of registered RPE clients |
| 0x1C | `Notifier_WpcdGetAllSubsystemDescriptors(DESCRIPTOR *Array, ULONG *Count)` | Fills one 228-byte descriptor per client and marks each client as registered with WPCD (+0xEC = 1). Returns `STATUS_BUFFER_TOO_SMALL` (0xC0000023) with the required count in `*Count` if `*Count` is too small |

Subsystem descriptor (228 bytes = 0xE4). Also the argument of `RpeClientAdd`, built in a global buffer at `.data:0x0040CAD0`:  
| Bytes | Comment |
|-------|---------|
| 00-0F | Client GUID |
| 10-4F | Client name (64 chars, ANSI) |
| 50-CF | Second string (128 chars, ANSI) |
| D0-D3 | Callback table [1] |
| D4-D7 | Callback table [2] |
| D8-DB | Pointer to the memory segment array |
| DC | Number of memory segments |
| E0-E3 | Client context |

Clients that register later are passed to the WPCD client asynchronously: the first `Notifier_HelperSendState` of a client not yet registered with WPCD puts it in the client-add queue. Then `NotifierEvtWorkItemWpcdClientAdd` calls `RpeClientAdd(descriptor)`. If no WPCD client is registered yet, the queue is dropped (log: "Will register client with CDI later, Connection to CDI driver"). In that case qccdi8930.sys gets the clients with `Notifier_WpcdGetAllSubsystemDescriptors` when it connects (its log: "Registering all known RPE subsystems for crash dump since connection to the dependent RPEN interface was detected").  
When a client sends state 4, or calls `Notifier_HelperClientDeinit`, a copy of its record is queued and `NotifierEvtWorkItemWpcdClientRemove` calls `RpeClientRemove(record)`. The first 16 bytes of the record are the client GUID.

#### Helper interface

Size 0x28 (40), Version 1. Used by the subsystem drivers (RPE clients).  
| Offset | Function | Comment |
|--------|----------|---------|
| 0x10 | `Notifier_HelperInit(GUID *ClientGuid, CHAR *Name, CHAR *String2, PVOID CallbackTable[4], PVOID Segments, UCHAR SegmentCount, PVOID Context)` | Registers a client (see [RPE client record](#rpe-client-record)). The segment array (`SegmentCount` × 16 bytes) is copied to pool. Fails if the GUID is already registered. Ends by sending the initial state 0 with `Notifier_HelperSendState` |
| 0x14 | `Notifier_HelperClientDeinit(GUID *ClientGuid)` | Removes the client, frees its segment copy and unregisters it from WPCD if needed |
| 0x18 | `Notifier_HelperSendState(RPE_STATE *State)` | Sets the client's current state (+0xF0) and queues the state for `NotifierEvtWorkItemNotifyStates`. Unknown client → `STATUS_INVALID_DEVICE_REQUEST` |
| 0x1C | `Notifier_HelperSendcommand(RPE_COMMAND *Command)` | Queues the command for `NotifierEvtWorkItemNotifyCommands`. Unknown sender/target, or target without a command callback → 0xC0000010 `STATUS_INVALID_DEVICE_REQUEST` |
| 0x20 | `Notifier_HelperRegisterForStateNotification(GUID *Subscriber, RPE_STATE *Filter, Callback)` | Adds a 44-byte `RPE_NOTIFIER_STATE_NOTIFICATION_CONTEXT` to the subscriber's registrations. If the target client already exists and its current state matches `Filter->State` (or the filter state is 9), the callback is called right away |
| 0x24 | `Notifier_HelperDeregisterForStateNotification(GUID *Subscriber, RPE_STATE *Filter)` | Removes the matching registration |

State callback: `cb(SubscriberContext, RPE_STATE *State, ULONG *NewState)`. `NotifierEvtWorkItemNotifyStates` calls it for every registration whose target GUID matches and whose filter state equals the new state or is 9. If the callback writes a non-zero `*NewState`, the subscriber's own state becomes `*NewState` and is broadcast in turn. This allows chained reactions, e.g. a subsystem going down → its dependents change state.  
Command callback: `cb(TargetContext, RPE_COMMAND *Command, ULONG *State)`, called by `NotifierEvtWorkItemNotifyCommands` with the target's current state. If the callback changes `*State`, the new state is sent with `Notifier_HelperSendState`.

---

### IOCTL 0x1002044

This IOCTL is processed by Qcrpen8930.sys

| Property | Value |
|----------|-------|
| Device | 0x100 |
| Function | 0x811 (2065) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Notify apps state ? | 0 | 0 |

The buffers are ignored and nothing is returned (`Information` = 0).  
The handler calls `Notifier_NotifyAppsState`, which calls the callback table [1] of every client that has one, as `cb(Context, 2, &State)` with the client's current state. If a client changes `State`, the new state is sent with `Notifier_HelperSendState`. Same action as the power callback when the system goes to sleep. The meaning of the value 2 is unknown (apps going to sleep ?).  
Returns `STATUS_SUCCESS`, or `STATUS_UNSUCCESSFUL` (0xC0000001) if `Notifier_NotifyAppsState` fails.  
The request must have a file object (`STATUS_INVALID_DEVICE_REQUEST` otherwise). Any other IOCTL code completes with `STATUS_NOT_SUPPORTED` (0xC00000BB).  
The caller of this IOCTL is unknown.
