## NokiaFirewall.sys

Nokia "stealth mode" firewall (anti port scan).  
A tiny KMDF driver that adds six static **Windows Filtering Platform** filters (no callout of its own) so that the phone doesn't reveal itself to port scans: it stops sending ICMP "Destination Unreachable" errors, ignores incoming ICMP echo requests ("ping") on every interface except Wi-Fi, and silently drops the packets sent to closed ports instead of answering with a TCP RST / ICMP Port Unreachable.  
The filters are added each time the Base Filtering Engine (BFE) enters the running state; they aren't persistent and are never deleted by the driver.

PDB: `E:\build_e\subtask\D094AFB6_98\output\firewall\fre\NokiaFirewall.pdb`. 58 functions. Imports only `ntoskrnl.exe` (WPP support), `fwpkclnt.sys` (`Fwpm*` management API only, no `Fwps*`) and `WDFLDR.SYS`. No hardware access, no registry access.

Device name : `\Device\NOKIAFIREWALL`  
Symbolic link : `\DosDevices\NOKIAFIREWALL`  

It's a KMDF **control device** (no `EvtDriverDeviceAdd`, `WdfDriverInitNonPnpDriver`), created in `DriverEntry` by `sub_406008`:  
- `WdfControlDeviceInitAllocate` with the SDDL `D:P(A;;GA;;;SY)(A;;GRGWGX;;;BA)(A;;GRGW;;;WD)(A;;GR;;;RC)` (`SDDL_DEVOBJ_SYS_ALL_ADM_RWX_WORLD_RW_RES_R`).  
- Exclusive, `WdfDeviceIoDirect`, device type `FILE_DEVICE_NETWORK` (0x12).  
- Device context `DEVICE_CONTEXT` (4 bytes) = the BFE state-change subscription handle. Its cleanup callback `sub_401068` calls `FwpmBfeStateUnsubscribeChanges0`.  
- One parallel default queue (`sub_4066D0`) with `EvtWdfIoQueueIoDeviceControl` and `EvtWdfIoQueueIoStop`.  
- `sub_401138`: `FwpmBfeStateSubscribeChanges0(WDM device, loc_4011A0, NULL, &context)`, then `WdfControlFinishInitializing`.

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\NokiaFirewall` ?  

There's no parameters in the registry. All the filter definitions are hardcoded.

GUID of the WPP control (ETW provider):  
`{C4288976-F094-41BC-97E5-778C2115B8EF}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Base Filtering Engine (WFP) | `fwpkclnt.sys` | Provider, sublayer and filters added with the `Fwpm*` API |
| TCP/IP stack | `tcpip.sys` | Owner of the built-in `FWPM_CALLOUT_WFP_TRANSPORT_LAYER_V4/V6_SILENT_DROP` callouts used by two filters |

### IOCTL

`EvtWdfIoQueueIoDeviceControl` (0x40167C) only writes a WPP trace (queue, request, buffer lengths, IOCTL code) and completes **any** IOCTL with `STATUS_SUCCESS` and no data. The driver has no real IOCTL: the device exists only to subscribe to the BFE state changes.

### Driver entry and unload

`FxDriverEntry` → `DriverEntry` (0x407008):
1. WPP initialisation (`WppLoadTracingSupport`, `WppInitKm`).
2. `WdfDriverCreate` with `DriverInitFlags` = 1 (`WdfDriverInitNonPnpDriver`), `EvtDriverUnload` (0x401100, trace only), cleanup callback `sub_406670` (`WppCleanupKm`).
3. `WdfControlDeviceInitAllocate` (fails → 0xC000009A `STATUS_INSUFFICIENT_RESOURCES`), then `sub_406008` (see above).

BFE state callback `loc_4011A0`: if the new state is 3 (`FWPM_SERVICE_RUNNING`) → `sub_4011B0` ([WFP objects](#wfp-objects)). Any other state is ignored.

> [!NOTE]
> The driver doesn't import `FwpmBfeStateGet0`: the filters are only added on a state **change** to running. If the driver were loaded while the BFE is already running, nothing would be added until the BFE restarts. It's presumably loaded at boot, before the BFE starts.

Nothing is removed at unload: the filters stay in the BFE until it stops.

### WFP objects

`sub_4011B0`:
1. `FwpmEngineOpen0(NULL, RPC_C_AUTHN_DEFAULT (0xFFFFFFFF), NULL, &session, &engine)`; session name `NokiaFirewall`, flags 0 (not dynamic, so the objects survive the closing of the session), `txnWaitTimeoutInMSec` = `INFINITE`.
2. In one transaction: `FwpmProviderAdd0` then `FwpmSubLayerAdd0`. 0x80320009 `FWP_E_ALREADY_EXISTS` and 0xC0220009 `STATUS_FWP_ALREADY_EXISTS` are ignored. `FwpmTransactionCommit0`.
3. `sub_4012E8`: the 6 filters in a second transaction (`STATUS_FWP_ALREADY_EXISTS` is ignored for each filter; any other error → `FwpmTransactionAbort0`).
4. `FwpmEngineClose0`.

No object has a flag (not persistent, not boot-time).

Provider "Nokia":  
`{0FC28DBB-7E40-4F93-844B-51742A9A6DC8}`

Sublayer "Port scan filters" (provider "Nokia", weight 0x8000):  
`{7744DE3D-4DD2-426B-9A96-A295203F1723}`

All the filters are named `Port blocker` (no description), belong to the provider "Nokia" and to the sublayer above, and have the weight `FWP_EMPTY` (automatic).

| # | Filter key | Layer | Conditions | Action |
|---|------------|-------|------------|--------|
| 1 | `{54E34A17-270B-4858-A753-A843CC74B70A}` | `FWPM_LAYER_OUTBOUND_ICMP_ERROR_V4` `{41390100-564C-4B32-BC1D-718048354D7C}` | `FWPM_CONDITION_IP_LOCAL_PORT` (= ICMP type) == 3 (`FWP_UINT16`) | 0x1001 `FWP_ACTION_BLOCK` |
| 2 | `{B25B8F08-8213-4ABE-895A-EBE6965C99CB}` | `FWPM_LAYER_OUTBOUND_ICMP_ERROR_V6` `{7FB03B60-7B8D-4DFA-BADD-980176FC4E12}` | `FWPM_CONDITION_IP_LOCAL_PORT` (= ICMP type) == 3 (`FWP_UINT16`) | 0x1001 `FWP_ACTION_BLOCK` |
| 3 | `{0A9F33DA-1518-4F01-8D66-14F3EDC70714}` | `FWPM_LAYER_INBOUND_TRANSPORT_V4` `{5926DFC8-E3CF-4426-A283-DC393F5D0F9D}` | `FWPM_CONDITION_IP_LOCAL_PORT` == 8 (`FWP_UINT16`) **and** `FWPM_CONDITION_INTERFACE_TYPE` `{DAF8CD14-E09E-4C93-A5AE-C5C13B73FFCA}` `FWP_MATCH_NOT_EQUAL` 0x47 (`FWP_UINT32`, 71 = `IF_TYPE_IEEE80211`) | 0x1001 `FWP_ACTION_BLOCK` |
| 4 | `{619DE142-D717-43D4-B121-3FCDCB75E8EF}` | `FWPM_LAYER_INBOUND_TRANSPORT_V6` `{634A869F-FC23-4B90-B0C1-BF620A36AE6F}` | same as #3 | 0x1001 `FWP_ACTION_BLOCK` |
| 5 | `{4F669AE2-738E-47AF-86D0-3921779E2FCE}` | `FWPM_LAYER_INBOUND_TRANSPORT_V4_DISCARD` `{AC4A9833-F69D-4648-B261-6DC84835EF39}` | `FWPM_CONDITION_FLAGS` `{632CE23B-5167-435C-86D7-E903684AA80C}` `FWP_MATCH_FLAGS_NONE_SET` 1 (`FWP_CONDITION_FLAG_IS_LOOPBACK`) | 0x5003 `FWP_ACTION_CALLOUT_TERMINATING`, callout `FWPM_CALLOUT_WFP_TRANSPORT_LAYER_V4_SILENT_DROP` `{EDA08606-2494-4D78-89BC-67837C03B969}` |
| 6 | `{32DD0E3D-F4CB-4C1C-99EE-AF387D116764}` | `FWPM_LAYER_INBOUND_TRANSPORT_V6_DISCARD` `{2A6FF955-3B2B-49D2-9848-AD9D72DCAAB7}` | same as #5 | 0x5003 `FWP_ACTION_CALLOUT_TERMINATING`, callout `FWPM_CALLOUT_WFP_TRANSPORT_LAYER_V6_SILENT_DROP` `{8693CC74-A075-4156-B476-9286EECE814E}` |

`FWPM_CONDITION_IP_LOCAL_PORT` = `{0C1BA1AF-5765-453F-AF22-A8F791AC775B}`. For ICMP, WFP puts the ICMP type in the local port field (and the code in the remote port field).

Meaning:
- #1: no ICMPv4 type 3 "Destination Unreachable" is sent (e.g. Port Unreachable after a UDP probe on a closed port).
- #2: the same type value is used for ICMPv6, where type 3 is "Time Exceeded" (Destination Unreachable is type 1). Probably a copy-paste mistake ?
- #3: inbound ICMPv4 type 8 "Echo Request" is blocked unless it arrives on the Wi-Fi interface (so pings over the cellular data connection are not answered). There's no `FWPM_CONDITION_IP_PROTOCOL` condition: TCP/UDP packets to local port 8 on non-Wi-Fi interfaces are blocked too.
- #4: same for IPv6, but ICMPv6 Echo Request is type 128, so this filter only catches TCP/UDP packets to local port 8 ?
- #5, #6: packets that the stack would discard (no listener, i.e. closed port) on a non-loopback interface are silently dropped by tcpip.sys instead of producing a TCP RST or ICMP error ("stealth mode").

The keys are stored in `.rdata` from 0x403358 (condition, layer and callout GUIDs) and 0x403438 (sublayer, filter and provider keys); the `FWPM_FILTER0` structures are built on the stack by `sub_4012E8`.

### Other GUID

WPP message GUIDs (trace format):  
`{46A5F8DA-A19C-FA97-72DD-7C6699348F52}`  
`{030F3953-8246-E61F-834C-CF90701F772C}`
