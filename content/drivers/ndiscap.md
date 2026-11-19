## Ndiscap.sys

Microsoft NDIS packet capture driver (`Microsoft NDIS Capture`, NDIS 6.40 lightweight filter, version string `6.1.0000`).  
It's the kernel part of `netsh trace start capture=yes`: a monitoring filter that attaches above every network miniport (Wi-Fi [qcwlan8930.sys](./qcwlan8930.md), cellular [qcmbb8930.sys](./qcmbb8930.md), USB networking, …) and copies the frames it sees, sent and received, into **ETW events** of the `Microsoft-Windows-NDIS-PacketCapture` provider. It never changes, drops or delays a packet: every NBL list is passed on unchanged with `NdisFSendNetBufferLists` / `NdisFIndicateReceiveNetBufferLists`.  
Nothing is captured until an ETW session enables the provider. The capture filters (interface, MAC / IP addresses, EtherType, protocol, custom byte patterns, truncation length) come from the [ETW enable filter data](#capture-rules) of the session.  
The filter only attaches when the registry value `RefCount` is non-zero (see [Registry](#registry)).  

PDB: `ndiscap.pdb`. Image base 0x10000, 72 functions, symbols present. Imports only `ntoskrnl.exe`, `HAL.dll` and `NDIS.SYS`. Pool tag `Filt` (0x746C6946). No hardware access.

There's no `\Device\` object, no symbolic link, no device interface and no IOCTL. The only inputs are the NDIS filter callbacks and the ETW enable callback.

Filter identification (`NDIS_FILTER_DRIVER_CHARACTERISTICS`):  
| Property | Value |
|----------|-------|
| FriendlyName | `Microsoft NDIS Capture` |
| UniqueName | `{EA24CD6C-D17A-4348-9190-09F0D5BE83DD}` |
| ServiceName | `NDISCAP` |
| NDIS version | 6.40 (0x06, 0x28) |
| Driver version | 1.0 |
| Flags | 0 |

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\NDISCAP`  

### Registry

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NDISCAP\Parameters` (opened with `ZwOpenKey` on the `RegistryPath` given to `DriverEntry` + `Parameters`, `OBJ_KERNEL_HANDLE | OBJ_CASE_INSENSITIVE`):  
| Registry value | value | comment |
|----------------|-------|---------|
| PersistentRefCount | ? | REG_DWORD. Read once in `DriverEntry` (`FxDriverEntryWorker`, `INIT:0x00017000`) and **copied into `RefCount`** (`ZwSetValueKey`, REG_DWORD), when it exists |
| RefCount | ? | REG_DWORD. Read in `FilterAttach` for each miniport. 0 → the filter refuses to attach (NDIS status 0x00010003, `LayerLoadError` event); missing → the error of `ZwQueryValueKey` is returned. `netsh trace` sets it (and rebinds the stack) to turn capture on ? |
| CaptureMode | ? | REG_DWORD. Read in `FilterAttach`, **value never used** |

`RegUtilQueryULONGValue` (sub_134A8) uses `KeyValuePartialInformation` with a 20-byte buffer and accepts the value if the type **or** the data length is 4.  
So at boot `RefCount` = `PersistentRefCount`: a persistent capture (`netsh trace … persistent=yes` ?) survives a reboot, a normal one ends with it.

GUID of the ETW provider (`Microsoft-Windows-NDIS-PacketCapture`):  
`{2ED6006E-4729-4609-B423-3EE7BCD678EF}`  
Registered in `DriverEntry` (`McGenEventRegister`, enable callback `McGenControlCallbackV2` → [EtwEnableCallback](#capture-rules)), unregistered in `FilterUnload`.

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Every NDIS miniport below the filter | e.g. [qcwlan8930.sys](./qcwlan8930.md) (Native 802.11), [qcmbb8930.sys](./qcmbb8930.md) (WWAN), … | Monitoring filter: `FilterAttach` per binding. Only media 0 (802.3) and 16 (Native 802.11) are parsed for the rules; other media are captured without inspection |
| ETW | `ntoskrnl.exe` | All captured data leaves the driver as ETW events |

### Driver entry and unload

`FxDriverEntry` (0x13740) → `__security_init_cookie` → `FxDriverEntryWorker` (`INIT:0x00017000`):
1. Copies the registry path into `DriverRegistryPath` (`.data:0x000150F0`, pool `Filt`). Allocation failure → `DriverLoadError` (line 107), returns STATUS_INSUFFICIENT_RESOURCES (0xC000009A).
2. Copies `PersistentRefCount` into `RefCount` (see [Registry](#registry)).
3. Fills `NDIS_FILTER_DRIVER_CHARACTERISTICS` (header type 0x8B, revision 1, size 0x74), initialises `FilterListLock` and the filter module list, registers the ETW provider, writes `DriverLoad`.
4. `NdisFRegisterFilterDriver`. Failure → `DriverLoadError` (line 195), returns the NDIS status.

Filter callbacks:  
| Handler | Function | Comment |
|---------|----------|---------|
| SetOptions | `FilterRegisterOptions` (0x11920) | Only checks the handles, returns 0 |
| SetFilterModuleOptions | `FilterSetModuleOptions` (0x1242C) | Returns 0 |
| Attach | `FilterAttach` (0x1194C) | See [Filter module](#filter-module) |
| Detach | `FilterDetach` (0x11D58) | Unlinks and frees the module, `LayerUnload` event |
| Restart | `FilterRestart` (0x11D00) | Opens and closes the filter configuration (nothing read), **overwrites** `MacOptions` of the restart general attributes with 0x80 (`NDIS_MAC_OPTION_SUPPORTS_MAC_ADDRESS_OVERWRITE`), state → 4 (running) |
| Pause | `FilterPause` (0x11CC8) | State → 2 then 3 (paused); nothing to drain |
| SendNetBufferLists | `FilterSendNetBufferLists` (0x11EA0) | See [Capture path](#capture-path) |
| ReceiveNetBufferLists | `FilterReceiveNetBufferLists` (0x120D0) | See [Capture path](#capture-path) |
| Status | `FilterStatus` (0x11E90) | Forwards with `NdisFIndicateStatus` |
| Others (send complete, return, OID, PnP, cancel) | NULL | Bypassed by NDIS |

`FilterUnload` (0x11DF8, `DriverUnload`): `NdisFDeregisterFilterDriver`, `DriverUnload` event (with the friendly name, unique name, service name and version), ETW unregistration, frees the coalescing buffer and the registry path copy.

### Filter module

`FilterAttach` allocates one context per binding (`NdisAllocateMemoryWithTagPriority`, 0x84 bytes + the 3 strings, tag `Filt`), `NdisFSetAttributes` (header type 0x8D, revision 1, size 8), and links it in `FilterModuleList` (`.data:0x000150E8`) under `FilterListLock`. Events: `StartLayerLoad`, `LayerLoad`, `EndLayerLoad` (or `LayerLoadError` with the status and a source line number).

Filter module context:  
| Offset | Comment |
|--------|---------|
| 0x00 / 0x04 | List links (`FilterModuleList`) |
| 0x0C | NDIS filter handle |
| 0x10 | `UNICODE_STRING` FilterModuleGuidName (copied after the context, at 0x84) |
| 0x18 | `UNICODE_STRING` BaseMiniportInstanceName (friendly name of the adapter) |
| 0x20 | `UNICODE_STRING` BaseMiniportName |
| 0x28 | BaseMiniportIfIndex ("MiniportIfIndex" of the events) |
| 0x2C | LowerIfIndex, **replaced by BaseMiniportIfIndex** when BaseMiniportIfIndex differs from the one of the previous attach (global `LastIfIndex`) |
| 0x30 | IfIndex of the filter module |
| 0x34 | MiniportMediaType (0 = 802.3, 16 = Native 802.11, …) |
| 0x50 | Spinlock (protects the PHY table) |
| 0x54 | Old IRQL |
| 0x58 | State: 2 pausing, 3 paused, 4 running |
| 0x74 | Freed by `FilterDetach` if non-zero; never set in this binary |
| 0x78 | Native 802.11 only: PHY table (see below) |
| 0x7C | Byte: Hyper-V switch module (VMSwitch keyword, 0x54-byte switch metadata from NBL+0x50). Never set in this binary: always 0 |
| 0x80 | Bypass flag: non-zero → no capture. Set to 0 at attach, never changed |

PHY table (media 16 only, `NDIS_MINIPORT_ADAPTER_NATIVE_802_11_ATTRIBUTES`, at most 64 PHYs, else no table):  
| Bytes | Comment |
|-------|---------|
| 00-03 | NumSupportedPhys |
| 04-07 | NumSupportedPhys |
| 08-… | One DWORD per PHY: `PhyType` of each `DOT11_PHY_ATTRIBUTES` (1092-byte entries), with `dot11_phy_type_dsss` (2) changed to `dot11_phy_type_hrdsss` (5) |

### Capture path

`FilterSendNetBufferLists` and `FilterReceiveNetBufferLists` are protected by stack cookies: Hex-Rays fails, read them from the disassembly. For each call:
1. Skip everything if the bypass flag (`+0x80`) is set, or if `EtwProviderEnabled` is false for the keyword `0x8000060000000000 | (1 << MediaType) | Direction` (Direction 0x100000000 send, 0x200000000 receive).
2. [Rule](#capture-rules) 4 must accept BaseMiniportIfIndex.
3. If `BaseMiniportIfIndex != LowerIfIndex` (the filter isn't right above the miniport), the packets are captured only if rule 3 exists and **rejects** the value 0. So by default only the bottom of the filter stack is captured, once per packet.
4. For each NBL, at DISPATCH_LEVEL (`KfRaiseIrql(2)`), for its first NET_BUFFER only:
   - `TxPacketStart` / `RxPacketStart` event (enable bit 0x80);
   - if `g_PacketInspectionRequired`, `InspectPacketMdl` (0x12F6C) applies the address / protocol rules, stops here on a reject;
   - receive on Native 802.11 only: the 48-byte `DOT11_EXTSTA_RECV_CONTEXT` of the NBL (`NetBufferListInfo` at NBL+0x68, checked with `MmIsAddressValid`) is copied, its `uPhyId` (offset 8) replaced by the PHY type from the PHY table, and written as a `PacketMetadata` event;
   - `TraceMdl` (0x12438) writes the frame as one `PacketFragment` event per MDL, up to the truncation length (rule 17, else the whole packet);
   - `TxPacketComplete` / `RxPacketComplete` event.
5. Pass the whole list to NDIS unchanged.

The 16-byte ETW activity ID of all these events is `{DWORD at NBL+0x84 with bit 31 cleared, 0, 0, 0}` (an NBL identifier ?), which links the fragments of one packet.  
`TraceMdl` maps each MDL (`MmMapLockedPagesSpecifyCache`, priority 0x40000000 = `LowPagePriority | MdlMappingNoExecute`) and fails with NDIS_STATUS_RESOURCES (0xC000009A) if it can't. The flags OR'ed into the keyword of each `PacketFragment` event:  
| Bit | Comment |
|-----|---------|
| 0x0000000040000000 | First fragment of the packet |
| 0x0000000080000000 | Last fragment of the packet |
| 0x0000000002000000 | Packet truncated (last fragment, truncation length < data length) |
| 0x0000000100000000 / 0x0000000200000000 | Send / receive |
| 1 << MediaType | Media (0x1 = 802.3, 0x10000 = Native 802.11, …) |

`InspectPacketMdl` needs the first `g_MaxRuleInspectionOffset + 54` bytes (802.3) or `+ 82` bytes (802.11) contiguous. When the first MDL is shorter, the bytes are copied into a global coalescing buffer `g_CoalescedBuffer` (NonPagedPoolNx, tag `Filt`, grown on demand). This buffer has **no lock** although send and receive can run at the same time on several processors.

### Capture rules

The rules come from the `EVENT_FILTER_DESCRIPTOR` passed by the ETW session to the enable callback (`EtwEnableCallback`, 0x131A8, which prints `*** EtwEnableCallback called (IsEnabled=%d)` with `DbgPrint`). The descriptor must be of type **0x30AD** (12461); its data is a sequence of rules:  
| Bytes | Comment |
|-------|---------|
| 00 | Rule id (0-26) |
| 01 | Operator (see below); 0 = rule ignored |
| 02-03 | Length n of the data |
| 04-… | Data (n bytes) |

Each valid rule (`TraceFilterEngineValidateRule`, 0x136E4) replaces the previous rule with the same id in `g_Rules[27]` (one pool copy each). An invalid rule writes `RuleLoadError` and stops the parsing. Then one `CaptureRule` event per rule and a `CaptureRules` event are written. Disabling the provider frees all the rules.

Operators (`EvaluateBinaryRuleEx`, 0x13550; bit 0x80 = negation):  
| Operator | Comment |
|----------|---------|
| 0x03 / 0x83 | Equal / not equal: data length must equal the field size, `RtlCompareMemory` |
| 0x04 / 0x84 | Mask: `(field & data) == data`, fields of 1, 2 or 4 bytes |
| 0x05 / 0x85 | In list / not in list: data = WORD count + count values of the field size |
| 0x06 / 0x86 | In range / not in range: data = 8 bytes, DWORD min + DWORD max (inclusive) |
| 0x01, 0x02 | Accepted by the validation, always "allowed" |

Rule ids:  
| Id | Field | Size | Comment |
|----|-------|------|---------|
| 2 | 802.11 Frame Control | 2 | Native 802.11 only |
| 3 | Multi-layer | 4 | Compared with 0; see [Capture path](#capture-path) step 3 |
| 4 | BaseMiniportIfIndex | 4 | Interface filter |
| 6 | EtherType | 2 | Network byte order. 802.11: from the 8-byte LLC/SNAP header |
| 7 | Source MAC | 6 | 802.3, 802.11 data frames (address chosen with ToDS / FromDS; WDS frames not filtered) |
| 8 | Destination MAC | 6 | Idem |
| 9 | Any MAC | 6 | Source or destination (both, if the operator is negated) |
| 10 / 11 / 12 | IPv4 source / destination / any | 4 | When EtherType is 0x0800 |
| 13 / 14 / 15 | IPv6 source / destination / any | 16 | When EtherType is 0x86DD |
| 16 | IP protocol | 1 | IPv4 Protocol / IPv6 Next Header |
| 17 | Truncation length | 4 | Operator 0x03: maximum number of bytes captured per packet |
| 18 | Custom MAC pattern | ≥5 | DWORD offset from the start of the frame + bytes to compare |
| 19 | Custom IP pattern | ≥5 | DWORD offset from the IP header + bytes to compare |
| 0, 1, 5, 20-26 | ? | | Accepted, but never evaluated by this binary |

`g_PacketInspectionRequired` is set when a rule other than 3, 4, 5, 17 or 26 exists. `g_MaxRuleInspectionOffset` = the largest `offset + pattern length` of rules 18 and 19.  
A packet too short for a header is accepted (not rejected) by the rules of that header.

### ETW events

Provider `{2ED6006E-4729-4609-B423-3EE7BCD678EF}`, channel 0x10 for all events:  
| Event | Id | Level | Opcode | Task | Keyword | Payload |
|-------|----|-------|--------|------|---------|---------|
| PacketFragment | 1001 | 4 | 0 | 0 | 0x8000060000000000 (+ flags) | MiniportIfIndex (4), LowerIfIndex (4), FragmentSize (4), Fragment (FragmentSize bytes) |
| PacketMetadata | 1002 | 4 | 0 | 0 | 0x8000040000000000 (+ 0x200000000, media) | MiniportIfIndex (4), LowerIfIndex (4), MetadataSize = 48 (4), `DOT11_EXTSTA_RECV_CONTEXT` (48) |
| VMSwitchPacketFragment | 1003 | 4 | 0 | 0 | 0x8000040001000000 | Not reachable here |
| CaptureRules | 1011 | 4 | 0 | 5 | 0x800000C000000000 | Number of rules (4) |
| DriverLoad | 1012 | 5 | 0 | 0 | 0x8000008000000000 | FriendlyName, UniqueName, ServiceName, version (4 strings) |
| DriverUnload | 1013 | 5 | 0 | 0 | 0x8000008000000000 | Idem |
| LayerLoad | 1014 | 5 | 0 | 0 | 0x8000008000000000 | BaseMiniportIfIndex, LowerIfIndex, MediaType, LowerIfIndex (4 DWORDs) |
| LayerUnload | 1015 | 5 | 0 | 0 | 0x8000008000000000 | Idem (from the module context) |
| CaptureRule | 1016 | 4 | 0 | 5 | 0x800000C000000000 | Id, Id, operator, length, data |
| DriverLoadError | 2001 | 2 | 21 | 1 | 0x8000008000000000 | status, source line, 0 |
| LayerLoadError | 2002 | 2 | 21 | 3 | 0x8000008000000000 | status, source line, LowerIfIndex |
| RuleLoadError | 2003 | 2 | 21 | 5 | 0x8000008000000000 | Id, Id, operator, length, data |
| StartLayerLoad | 3001 | 5 | 21 | 3 | 0x8000208000000000 | 1 (1), 21 (1), 1929 (4), LowerIfIndex (4) |
| EndLayerLoad | 3002 | 5 | 21 | 3 | 0x8000208000000000 | 21 (1), 2 (1), 2255 (4), LowerIfIndex (4) |
| RxPacketStart / RxPacketComplete | 5000 / 5001 | 5 | 1 / 2 | 0 | 0x8001200000000000 | None (activity ID only) |
| TxPacketStart / TxPacketComplete | 5002 / 5003 | 5 | 1 / 2 | 0 | 0x8001200000000000 | None (activity ID only) |

`Microsoft_Windows_NDIS_PacketCaptureEnableBits` (`.data:0x000150F8`, set by `McGenControlCallbackV2`): bit 0 PacketFragment, 1 PacketMetadata, 2 VMSwitch, 3 rules, 4 load / unload, 5 errors, 6 start / end layer load, 7 Tx / Rx start / complete.

> [!NOTE]
> Capture can be started only by an ETW session on the phone (e.g. `netsh trace`, or `xperf` / WPR with the filter descriptor), with `RefCount` non-zero in the registry before the network adapters bind. The fragments are the raw frames: 802.3, Native 802.11 (with the 802.11 header) or the raw IP packets of the WWAN miniport.
