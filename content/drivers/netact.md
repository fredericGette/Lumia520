## Netact.sys

Network activity detector ("Af" WFP callouts).  
A small Windows Filtering Platform callout driver that watches the Layer-2 frames going in and out of the **Wi-Fi** and **mobile broadband** interfaces, and publishes two WNF states telling whether each radio is currently carrying traffic: `WNF_CNET_WIFI_ACTIVITY` and `WNF_CNET_RADIO_ACTIVITY`. A radio becomes "active" on the first frame, and "idle" again after 1 s (Wi-Fi) or 5 s (cellular) without any frame. The length of each activity period is also reported as an SQM data point.  
It never modifies, drops or delays a frame: its filters use the non-terminating action `FWP_ACTION_CALLOUT_INSPECTION`, and the classify function doesn't touch `classifyOut`.  
The states are consumed by [MobileUI.exe](../applications/mobileui.md) (`ShellEvents::Init`), probably for the data activity arrows of the status bar ?

PDB: `netact.pdb`. 54 functions, no symbols. Imports only `fwpkclnt.sys`, `ntoskrnl.exe` and `HAL.dll`. No pool allocation (everything is in `.data`), no hardware access.

Device : unnamed (`IoCreateDevice(DriverObject, 0, NULL, FILE_DEVICE_NETWORK (0x12), FILE_DEVICE_SECURE_OPEN (0x100), FALSE, &dword_10005034)`). It's only used for `FwpsCalloutRegister0`, `FwpmBfeStateSubscribeChanges0` and `IoAllocateWorkItem`.  
There's no symbolic link, no device interface, and no `MajorFunction` handler: no IOCTL.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\netact` ?  

There's no parameters in the registry. The idle timeouts are hardcoded.

GUID of the ETW provider:  
`{A97524F6-064C-4C4E-B74B-1ACC87C3700D}`  
Only used to write the [SQM data points](#sqm-data-points).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Base Filtering Engine (WFP) | `fwpkclnt.sys` | Provider, callouts and filters added with the `Fwpm*` API; callouts registered with `FwpsCalloutRegister0` |
| Wi-Fi miniport | [qcwlan8930.sys](./qcwlan8930.md) | Frames seen at the MAC frame native layers with the L2 flag `FWP_CONDITION_L2_IS_WIFI` (0x2) |
| Mobile broadband miniport | [qcmbb8930.sys](./qcmbb8930.md) | Frames seen with the L2 flag `FWP_CONDITION_L2_IS_MOBILE_BROADBAND` (0x4) |
| WNF | `ntoskrnl.exe` | `ZwUpdateWnfStateData`, see [WNF states](#wnf-states) |

### Driver entry and unload

`FxDriverEntry` (0x10002194) → `__security_init_cookie` → `FxDriverEntryWorker` (0x10003000):
1. `DriverUnload` = `sub_10004000`, creates the unnamed device.
2. `sub_10003258`: initialises the two [activity trackers](#activity-detection) and publishes 0 in both WNF states.
3. `sub_10003340`: `EtwRegister({A97524F6-…}, NULL, NULL)`. If the provider, or the SQM event, isn't enabled **at this moment** (`EtwProviderEnabled` / `EtwEventEnabled`), it unregisters the provider immediately (status 0xC00000BB STATUS_NOT_SUPPORTED, ignored by the caller). So the SQM data points are only written when an ETW session already listened to the provider when the driver loaded.
4. `sub_100030AC`: fills the two [callout/filter descriptions](#wfp-objects).
5. `sub_100031B4`: `FwpsCalloutRegister0` for both callouts, then `sub_10004110` (adds the WFP objects if the BFE is running), then `FwpmBfeStateSubscribeChanges0(device, sub_10001DF4, NULL, &dword_10005100)`. `sub_10001DF4` calls `sub_10004110` again when the BFE state becomes 3 (`FWPM_SERVICE_RUNNING`), so the objects are (re)added when the BFE starts later or restarts.  
   On error: `sub_100042B4` (cleanup) and the status is returned; the device object isn't deleted in that case.

`sub_10004000` (unload): `sub_100042B4` (`FwpmBfeStateUnsubscribeChanges0`, then `sub_1000424C`: opens an engine session and deletes both filters by ID, both callouts by key and the provider; then `FwpsCalloutUnregisterByKey0` for the registered callouts), `IoDeleteDevice`, cancels both timers, `KeFlushQueuedDpcs`, `EtwUnregister`.

### WFP objects

`sub_10004110` (only if `FwpmBfeStateGet0` = 3): `FwpmEngineOpen0(NULL, RPC_C_AUTHN_WINNT, NULL, NULL, &engine)`, `FwpmProviderAdd0`, then in one transaction for each of the two entries: `FwpmCalloutAdd0` and `FwpmFilterAdd0` (`sub_10004068`). Any failure aborts the transaction and calls `sub_1000424C`. No flag is set on the objects (not persistent, not boot-time). No sublayer is created: the filters go into an existing one.

Provider "Af WFP Callout Provider":  
`{9670D547-DEDF-49F7-A0F8-D1A4394C2ABB}`

| | Inbound | Outbound |
|---|---------|----------|
| Layer | `FWPM_LAYER_INBOUND_MAC_FRAME_NATIVE` `{D4220BD3-62CE-4F08-AE88-B56E8526DF50}` | `FWPM_LAYER_OUTBOUND_MAC_FRAME_NATIVE` `{94C44912-9D6F-4EBF-B995-05AB8A088D1B}` |
| Callout key | `{63139FB6-D5D5-4EB7-9F64-989040F1CC2E}` | `{7C0644CE-6AD7-437C-8DE4-B60B672ABAB1}` |
| Callout name / description | `Af Inbound Mac Frame Native Callout` | `Af Outbound Mac Frame Native Callout` |
| Filter key | `{984382C0-C34D-44C6-9F65-90EC590CBE1A}` | `{9E271631-764B-4E5D-88D9-3B5BA6D5E6A7}` |
| Filter name / description | `Af Inbound Mac Frame Native SubLayer Filter` | `Af Outbound Mac Frame Native SubLayer Filter` |
| Sublayer | `{877519E1-E6A9-41A5-81B4-8C4F118E4A60}` (?, not created by netact.sys) | same |
| Weight | `FWP_EMPTY` (automatic) | same |
| Action | 0x6004 `FWP_ACTION_CALLOUT_INSPECTION` | same |
| Condition | `FWPM_CONDITION_L2_FLAGS` `{7BC43CBF-37BA-45F1-B74A-82FF518EEB10}`, `FWP_MATCH_FLAGS_ANY_SET` (7), `FWP_UINT32` 6 (`IS_WIFI` \| `IS_MOBILE_BROADBAND`) | same |

`FwpsCalloutRegister0` (table at `.data:0x10005038`, 2 × 0x1C bytes: registered flag, callout ID, key, classifyFn, notifyFn, flowDeleteFn, flags): classifyFn = `sub_10001DC0`, notifyFn = `sub_10001DE8` (returns 0), no flowDeleteFn, flags 0x62 (`FWP_CALLOUT_FLAG_ALLOW_OFFLOAD` \| 0x20 \| 0x40 ?).

Filter/callout description (`.data:0x10005070`, 2 × 0x48 bytes):  
| Offset | Comment |
|--------|---------|
| 0x00 | UINT64 filter ID (output of `FwpmFilterAdd0`) |
| 0x08 | Pointer to the filter key |
| 0x0C | Pointer to the callout key |
| 0x10 | Pointer to the layer key |
| 0x14 / 0x18 | Callout name / description |
| 0x1C / 0x20 | Filter name / description |
| 0x24 | Number of filter conditions (1) |
| 0x28 | `FWPM_FILTER_CONDITION0` (field key, match type, value) |

### Activity detection

Classify (`sub_10001DC0`): reads the L2 flags value (incoming value index 6 at both MAC frame native layers: `inFixedValues->incomingValue[6].value.uint32`). Bit 0x2 (Wi-Fi) → `sub_10001E0C(1)`, else bit 0x4 (MBB) → `sub_10001E0C(0)`.

Each radio has a tracker:  
| | Cellular (index 0) | Wi-Fi (index 1) |
|---|------|-------|
| Idle timeout | 5000 ms (`dword_10005108`) | 1000 ms (`dword_10005180`) |
| Timeout in ticks | `dword_10005110` | `dword_10005188` |
| Last frame tick count | `dword_10005138` | `dword_100051B0` |
| KDPC / KTIMER | 0x10005118 / 0x10005140 | 0x10005190 / 0x100051B8 |
| Active flag | `byte_10005170` | `byte_100051E8` |
| Period start | `dword_10005178` | `dword_100051F0` |
| WNF state | `WNF_CNET_RADIO_ACTIVITY` | `WNF_CNET_WIFI_ACTIVITY` |
| SQM data ID | 1734 | 1743 |

1. On every frame (`sub_10001E0C`): stores the current `KeTickCount` as the last frame time, and atomically sets the active flag. If it was clear (idle → active), starts the periodic timer (`KeSetTimerEx`, due time and period = idle timeout), and runs `sub_100042F4(index | 2)` directly at PASSIVE_LEVEL, or from a work item (`IoQueueWorkItemEx`, `DelayedWorkQueue`) otherwise.
2. Timer DPC (`sub_10001EFC`, context = index): if `now - last frame` ≥ the idle timeout, cancels the timer and queues `sub_100042F4(index)`. So "idle" is detected between 1× and 2× the timeout after the last frame.
3. `sub_100042F4(flags)`: publishes the WNF state of `flags & 1` with the DWORD value `(flags & 2) != 0`. When becoming active, saves the first frame time as the period start. When becoming idle, computes the duration of the period in ms (`(now - start) × KeQueryTimeIncrement() / 10000`, so it includes the idle tail), writes it as an [SQM data point](#sqm-data-points), and clears the start and the active flag.

### WNF states

Written with `ZwUpdateWnfStateData(state, &value, 4, NULL, NULL, 0, 0)` (`sub_1000209C`); both are set to 0 when the driver loads.

| State name | Value | Data |
|------------|-------|------|
| `WNF_CNET_RADIO_ACTIVITY` | 0x1583002EA3BC0875 (`.rdata:0x100013F0`) | DWORD: 1 = traffic on the mobile broadband interface, 0 = idle for 5 s |
| `WNF_CNET_WIFI_ACTIVITY` | 0x1583002EA3BC9075 (`.rdata:0x100013E8`) | DWORD: 1 = traffic on the Wi-Fi interface, 0 = idle for 1 s |

The names come from [MobileUI.exe](../applications/mobileui.md), which subscribes to both.

### SQM data points

`sub_10001F98(dataId, value)`: only if the ETW provider is still registered (see [Driver entry](#driver-entry-and-unload)). `EtwWrite` of the event descriptor at `.rdata:0x10001368` (ID 17, version 0, channel 0, level 4, opcode 0, task 0, keyword 0x0008000000000000) with 7 data descriptors:

| # | Size | Value | Comment |
|---|------|-------|---------|
| 1 | 16 | `{C6CF0920-A353-48C5-82D0-0640C6F09D94}` | SQM session (`.data:0x10005008`), the same session as [MirrorUX.dll](../libraries/mirrorux.md#sqm) |
| 2 | 4 | 1734 / 1743 | SQM data ID: cellular / Wi-Fi activity period |
| 3 | 4 | 0x18494865 | ? |
| 4 | 4 | 1 | ? |
| 5 | 4 | 16 | Size of descriptor 6 ? |
| 6 | 16 | `01 00 00 00` `10 00 00 00` duration `00 00 00 00` | Bytes 08-0B: length of the activity period in ms |
| 7 | 4 | 0 | ? |
