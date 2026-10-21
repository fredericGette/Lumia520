## Wmilib.sys

Microsoft **WMI Library** (`wmilib.pdb`, 22 functions, ARM, image base 0x10000).  
It isn't a device driver but a kernel-mode **export library**: `DriverEntry` (0x1703C), `DllInitialize` (0x1702C) and `DllUnload` (0x154EC) only return 0 (after `__security_init_cookie` for the first two). A WDM driver that provides WMI data blocks links to it and calls its 3 helpers from its `IRP_MJ_SYSTEM_CONTROL` handler. It parses the `IRP_MN_*` WMI requests, finds the GUID in the driver's `WMILIB_CONTEXT`, checks the instance index and calls the driver's callbacks; the driver then completes the request with `WmiCompleteRequest`, which builds the returned `WNODE`.  
It has no state of its own (no global except the security cookie), no registry access and no ETW provider. It only imports 7 functions from ntoskrnl: `ExAllocatePoolWithTag`, `ExFreePoolWithTag`, `ExFreePool`, `IoWMIWriteEvent`, `KeQuerySystemTime`, `IofCompleteRequest`, `ObfReferenceObject`.  
On the Lumia 520 it's used by [battc.sys](./battc.md) (`WmiSystemControl`, `WmiCompleteRequest`), so indirectly by the battery miniclass drivers that call `BatteryClassSystemControl` (e.g. [qcbattminiclass8930.sys](./qcbattminiclass8930.md)).

There's no named device and no `\DosDevices` link.

There's no parameters in the registry (the binary has no registry access).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| Kernel WMI | ntoskrnl | `IoWMIWriteEvent` (in `WmiFireEvent`) |
| Caller's device | caller (e.g. [battc.sys](./battc.md)) | Direct calls to the `WMILIB_CONTEXT` callbacks, no IRP sent |

### Exports

| Export | Ordinal | Address | Comment |
|--------|---------|---------|---------|
| DllInitialize | 1 | 0x1702C | `__security_init_cookie`, returns 0 |
| DllUnload | 2 | 0x154EC | Returns 0 |
| WmiCompleteRequest | 3 | 0x1149C | `NTSTATUS WmiCompleteRequest(PDEVICE_OBJECT, PIRP, NTSTATUS Status, ULONG BufferUsed, CCHAR PriorityBoost)` (see [WmiCompleteRequest](#wmicompleterequest)) |
| WmiFireEvent | 4 | 0x115E0 | `NTSTATUS WmiFireEvent(PDEVICE_OBJECT, LPCGUID Guid, ULONG InstanceIndex, ULONG EventDataSize, PVOID EventData)` (see [WmiFireEvent](#wmifireevent)) |
| WmiSystemControl | 5 | 0x15000 | `NTSTATUS WmiSystemControl(PWMILIB_CONTEXT, PDEVICE_OBJECT, PIRP, PSYSCTL_IRP_DISPOSITION)` (see [WmiSystemControl](#wmisystemcontrol)) |
| GsDriverEntry | — | 0x1157C | Entry point: `__security_init_cookie` then `DriverEntry` (returns 0) |

Internal function: `WmiLibpFindGuid` (0x153DC), linear search of the GUID (`memcmp` of 16 bytes) in `GuidList`; returns the index and the `InstanceCount` of the entry.

### WMILIB_CONTEXT

Structure given by the caller (32 bytes). Only `QueryWmiRegInfo` and `QueryWmiDataBlock` are mandatory: they are called **without a NULL check**.  
| Bytes | Comment |
|-------|---------|
| 00-03 | GuidCount |
| 04-07 | GuidList: array of `WMIGUIDREGINFO` (12 bytes: +0 pointer to the GUID, +4 InstanceCount, +8 Flags) |
| 08-0B | QueryWmiRegInfo(DeviceObject, &RegFlags, &InstanceName, &RegistryPath, &MofResourceName, &Pdo) |
| 0C-0F | QueryWmiDataBlock(DeviceObject, Irp, GuidIndex, InstanceIndex, InstanceCount, InstanceLengthArray, BufferAvail, Buffer) |
| 10-13 | SetWmiDataBlock(DeviceObject, Irp, GuidIndex, InstanceIndex, BufferSize, Buffer) (optional) |
| 14-17 | SetWmiDataItem(DeviceObject, Irp, GuidIndex, InstanceIndex, DataItemId, BufferSize, Buffer) (optional) |
| 18-1B | ExecuteWmiMethod(DeviceObject, Irp, GuidIndex, InstanceIndex, MethodId, InBufferSize, OutBufferSize, Buffer) (optional) |
| 1C-1F | WmiFunctionControl(DeviceObject, Irp, GuidIndex, Function, Enable) (optional) |

### WmiSystemControl

The `IO_STACK_LOCATION` fields used are `MinorFunction` (+01) and `Parameters.WMI` (ARM layout, the union starts at +08): ProviderId (+08), DataPath = GUID (+0C), BufferSize (+10), Buffer = `WNODE_*` (+14).

`IrpDisposition` values written: 0 `IrpProcessed`, 1 `IrpNotCompleted`, 2 `IrpNotWmi`, 3 `IrpForward`.

1. MinorFunction > 9 and ≠ 0xB (`IRP_MN_REGINFO_EX`), including 0xA → `IrpNotWmi`, returns `STATUS_SUCCESS` (0). The IRP isn't touched.
2. ProviderId ≠ DeviceObject, or `WmiLibInfo` NULL → `IrpForward`, returns `Irp->IoStatus.Status` (the request is for a lower driver).
3. Except for `IRP_MN_REGINFO`/`IRP_MN_REGINFO_EX`: GUID not in `GuidList` → `STATUS_WMI_GUID_NOT_FOUND` (0xC0000295).
4. For the single-instance requests (1, 2, 3, 9): `WNODE_HEADER.Flags` (+2C) must have `WNODE_FLAG_STATIC_INSTANCE_NAMES` (0x80) and `InstanceIndex` (+34) must be < `InstanceCount` of the GUID, otherwise `STATUS_WMI_INSTANCE_NOT_FOUND` (0xC0000296). **Dynamic instance names aren't supported.**
5. Otherwise the callback is called and its status is returned as is: `IrpProcessed`, and **the callback must call `WmiCompleteRequest`** (or return `STATUS_PENDING` and call it later).

The errors of steps 3–4 and the "callback missing" cases set `Irp->IoStatus` and return `IrpNotCompleted`: the caller must complete the IRP itself.

| Minor | Name | Callback | Arguments taken from the WNODE | Missing callback |
|-------|------|----------|--------------------------------|------------------|
| 0x0 | IRP_MN_QUERY_ALL_DATA | QueryWmiDataBlock | InstanceIndex 0, InstanceCount = count of the GUID, InstanceLengthArray = `WNODE_ALL_DATA` +3C, BufferAvail = BufferSize − DataBlockOffset, Buffer = WNODE + DataBlockOffset | — (not checked) |
| 0x1 | IRP_MN_QUERY_SINGLE_INSTANCE | QueryWmiDataBlock | InstanceCount 1, InstanceLengthArray = &SizeDataBlock (+3C), BufferAvail = BufferSize − DataBlockOffset (+38), Buffer = WNODE + DataBlockOffset | — (not checked) |
| 0x2 | IRP_MN_CHANGE_SINGLE_INSTANCE | SetWmiDataBlock | BufferSize = SizeDataBlock (+3C), Buffer = WNODE + DataBlockOffset (+38) | `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010) |
| 0x3 | IRP_MN_CHANGE_SINGLE_ITEM | SetWmiDataItem | DataItemId = ItemId (+38), BufferSize = SizeDataItem (+40), Buffer = WNODE + DataBlockOffset (+3C) | `STATUS_INVALID_DEVICE_REQUEST` |
| 0x4 | IRP_MN_ENABLE_EVENTS | WmiFunctionControl | Function 0 (`WmiEventControl`), Enable TRUE | `STATUS_SUCCESS`, 0 bytes |
| 0x5 | IRP_MN_DISABLE_EVENTS | WmiFunctionControl | Function 0, Enable FALSE | `STATUS_SUCCESS`, 0 bytes |
| 0x6 | IRP_MN_ENABLE_COLLECTION | WmiFunctionControl | Function 1 (`WmiDataBlockControl`), Enable TRUE | `STATUS_SUCCESS`, 0 bytes |
| 0x7 | IRP_MN_DISABLE_COLLECTION | WmiFunctionControl | Function 1, Enable FALSE | `STATUS_SUCCESS`, 0 bytes |
| 0x8 | IRP_MN_REGINFO | QueryWmiRegInfo | See [Registration](#registration-irp_mn_reginfo--irp_mn_reginfo_ex) | — (not checked) |
| 0x9 | IRP_MN_EXECUTE_METHOD | ExecuteWmiMethod | MethodId (+38), InBufferSize = SizeDataBlock (+40), OutBufferSize = BufferSize − DataBlockOffset (+3C), Buffer = WNODE + DataBlockOffset | `STATUS_INVALID_DEVICE_REQUEST` |
| 0xB | IRP_MN_REGINFO_EX | QueryWmiRegInfo | Same as 0x8, plus a reference on the PDO | — (not checked) |

`IRP_MN_QUERY_ALL_DATA` details:
* BufferSize < 72 (0x48, `sizeof(WNODE_ALL_DATA)` rounded to 8) → `STATUS_UNSUCCESSFUL` (0xC0000001), `IrpNotCompleted`.
* Before the call it writes in the WNODE: InstanceCount (+34) = count of the GUID, `WNODE_FLAG_FIXED_INSTANCE_SIZE` (0x10) cleared in Flags (+2C), DataBlockOffset (+30) = (0x3C + 8 × InstanceCount) rounded up to 8 (room for the `OFFSETINSTANCEDATAANDLENGTH` array).
* If that DataBlockOffset is > BufferSize, the callback gets InstanceLengthArray = NULL, BufferAvail = 0 and Buffer = NULL: it is expected to answer `STATUS_BUFFER_TOO_SMALL` with the needed size.

#### Registration (IRP_MN_REGINFO / IRP_MN_REGINFO_EX)

`QueryWmiRegInfo` is called with `InstanceName`, `MofResourceName` = empty `UNICODE_STRING` and `RegistryPath` = NULL. A failure is returned with 0 bytes (`IrpNotCompleted`).  
RegFlags without `WMIREG_FLAG_INSTANCE_PDO` (0x20) and no InstanceName buffer → `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010). Without `WMIREG_FLAG_INSTANCE_PDO` and `WMIREG_FLAG_INSTANCE_BASENAME` (0x8), `WMIREG_FLAG_INSTANCE_LIST` (0x4) is added. A NULL RegistryPath is replaced by an empty string. The InstanceName buffer is **freed with `ExFreePool`**: the callback must allocate it from pool.

`WMIREGINFOW` written in `Parameters.WMI.Buffer`:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | BufferSize: total size needed. When it's > `Parameters.WMI.BufferSize`, only this field is written and `IoStatus.Information` = 4 (the status is still the callback's, i.e. success) |
| 04-07 | 00 00 00 00 | NextWmiRegInfo |
| 08-0B | | RegistryPath offset |
| 0C-0F | | MofResourceName offset |
| 10-13 | | GuidCount = `WMILIB_CONTEXT.GuidCount` |
| 14- | | `WMIREGGUIDW` × GuidCount (28 bytes each, see below) |
| 14 + 28 × GuidCount | | InstanceName as a counted string (USHORT length in bytes + UTF-16), only when Flags has 0x4 or 0x8 |
| next | | MofResourceName as a counted string |
| next | | RegistryPath as a counted string (it comes **after** the MOF name) |

`WMIREGGUIDW`:  
| Bytes | Comment |
|-------|---------|
| 00-0F | GUID, copied from `GuidList[i].Guid` |
| 10-13 | Flags = `GuidList[i].Flags` \| RegFlags |
| 14-17 | InstanceCount = `GuidList[i].InstanceCount` |
| 18-1B | With `WMIREG_FLAG_INSTANCE_PDO`: the PDO (for `IRP_MN_REGINFO_EX`, `ObfReferenceObject(Pdo)` is called **once per GUID**, WMI releases it). Otherwise: offset of the InstanceName counted string (same for all the GUIDs) |

The strings aren't aligned. Status = the callback's, `IoStatus.Information` = BufferSize, `IrpNotCompleted`: the caller completes the IRP.

### WmiCompleteRequest

Called by the driver to finish a request given to one of its callbacks. `BufferUsed` is the number of bytes written at `WNODE + DataBlockOffset` (or the size needed when Status = `STATUS_BUFFER_TOO_SMALL`).  
| Minor | Success | Comment |
|-------|---------|---------|
| 0x0 QUERY_ALL_DATA | size = DataBlockOffset (+30) + BufferUsed. If size > `Parameters.WMI.BufferSize` → WNODE_TOO_SMALL. Otherwise `WNODE_HEADER.BufferSize` = size, `TimeStamp` (+10) = `KeQuerySystemTime`, and the `ULONG` lengths written by the driver at +3C are expanded **in place** into `OFFSETINSTANCEDATAANDLENGTH` {Offset, Length} pairs. The first offset is DataBlockOffset, then each instance starts on an 8-byte boundary | The driver must pack the instances with the same 8-byte alignment |
| 0x1 QUERY_SINGLE_INSTANCE | size = DataBlockOffset (+38) + BufferUsed; BufferSize = size, TimeStamp | `SizeDataBlock` (+3C) isn't written here: it is the InstanceLengthArray given to `QueryWmiDataBlock`. **No check** of size against the buffer size |
| 0x9 EXECUTE_METHOD | size = DataBlockOffset (+3C) + BufferUsed; BufferSize = size, TimeStamp, SizeDataBlock (+40) = BufferUsed | No check of size against the buffer size |
| other | `IoStatus.Information` = 0 | Status passed unchanged |

* Status < 0 and ≠ `STATUS_BUFFER_TOO_SMALL` (0xC0000023): `IoStatus.Information` = 0.
* `STATUS_BUFFER_TOO_SMALL` (minors 0, 1, 9 only), or QUERY_ALL_DATA too big: the WNODE is turned into a `WNODE_TOO_SMALL`: BufferSize (+00) = 56, Flags (+2C) = `WNODE_FLAG_TOO_SMALL` (0x20) (the other flags are **overwritten**, not OR-ed), SizeNeeded (+30) = DataBlockOffset + BufferUsed. `IoStatus.Information` = 56 and the status becomes `STATUS_SUCCESS`, as expected by WMI.

Then `Irp->IoStatus.Status` / `Information` are set, `IofCompleteRequest(Irp, PriorityBoost)`, and the final status is returned.

### WmiFireEvent

Builds a `WNODE_SINGLE_INSTANCE` event and gives it to `IoWMIWriteEvent`:  
1. EventData NULL → EventDataSize = 0.
2. Allocates 64 + EventDataSize bytes, `NonPagedPoolNx` (0x200), pool tag `WmiL` (0x4C696D57). Failure → `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A). The buffer isn't zeroed: the fields not listed below (+08-0F, +28, +30) are left uninitialised.
3. Fills it and calls `IoWMIWriteEvent`. On failure the WNODE is freed and the error returned; on success the kernel owns it and `STATUS_SUCCESS` is returned.
4. **EventData is always freed with `ExFreePool`**, even on failure: the caller must allocate it from pool and must not touch it afterwards.

| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | BufferSize = 64 + EventDataSize |
| 04-07 | | ProviderId = DeviceObject |
| 10-17 | | TimeStamp (`KeQuerySystemTime`) |
| 18-27 | | GUID of the event |
| 2C-2F | 8A 00 00 00 | Flags: `WNODE_FLAG_SINGLE_INSTANCE` (0x2) \| `WNODE_FLAG_EVENT_ITEM` (0x8) \| `WNODE_FLAG_STATIC_INSTANCE_NAMES` (0x80) |
| 34-37 | | InstanceIndex |
| 38-3B | 40 00 00 00 | DataBlockOffset |
| 3C-3F | | SizeDataBlock = EventDataSize |
| 40- | | EventData |

> [!NOTE]
> On the Lumia 520, [battc.sys](./battc.md) declares the event GUIDs `BATTERY_STATUS_CHANGE_WMI_GUID` and `BATTERY_TAG_CHANGE_WMI_GUID` but doesn't import `WmiFireEvent`, so they are never fired.
