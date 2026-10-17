## Qccdi8930.sys

Crash Dump Injector (CDI) driver. As indicated in the binary, this is the _Crash dump injectory driver that interfaces with the Windows crash dump driver and is responsible for generating crash dumps_.  
It maintains a list of physical memory regions ("subsystems") to include in the memory dump in case of crash. The address of some of these memory regions are hardcoded in the driver, the others are found by querying other drivers with their driver-defined interface ([qcrpen8930.sys](./qcrpen8930.md) for the RPE clients, [qcpil8930.sys](./qcpil8930.md) for the loaded images).  
Each region is cut into dump segments that are added to the Windows crash dump with `KeRegisterBugCheckReasonCallback(KbCallbackSecondaryDumpData)`, and is also announced to the Windows Phone crash dump driver [wpcrdmp.sys](./wpcrdmp.md) (CDD) for the offline dump.  
At startup it also gives a 4 KB buffer to the TrustZone (through [qcscm8930.sys](./qcscm8930.md)) to receive the _watchdog bark_ context.  
PDB path: `P:\RPE\rel\8.3\arm\Release\qccdi8930.pdb`.

There's no device name and no symbolic link. The device only registers the device interface `{6EA2C81E-AC5E-4583-8767-37D4DBFBD6AB}` (see [IOCTL](#ioctl)).  

Registry driver's Parameters:  
| Registry value | value | comment |
|----------------|-------|---------|
| ExpectedCrashDumpSegmentSize | | ULong (default=0xA00000, 10MB). Maximum size of a dump segment: each memory run is cut into segments of this size |
| UserDefinedCrashDumpSegmentSize | | ULong (default=0). Size in bytes of the `TZ_LOG` region |
| UserDefinedCrashDumpSegmentAddress | | ULong (default=0x00000000). Physical address of the `TZ_LOG` region. `TZ_LOG` is registered only when both values are not 0 |

Crash dump cookies used in Offline Dump:  
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CrashControl\SVVariables`  
| Registry value | value | comment |
|----------------|-------|---------|
| WpMemoryCaptureModeAddr | | ULong. Physical address of the `WpMemoryCaptureMode` cookie. The driver maps 4 bytes at this address and only logs its value (e.g. 0xFFFFFFFF) |
| WpSvLegacyFlagAddr | | ULong. Physical address of the `WpSvLegacyFlag` cookie. Same processing |

The CDD is used only if the key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WpCrDmp` exists.

There's no ETW provider: the driver writes its logs as text in a 128 KB buffer, the `TRACE_LOG` region (see [Example of startup logs](#example-of-startup-logs)). When the buffer is full, a single warning is printed with `DbgPrintEx(DPFLTR_IHVDRIVER_ID, …)` ("qccdi: WARNING: Crash dump trace log bu…") and the next logs are lost.

Pool tags: `qcd0` (driver), `qcda` (dump segment directory), `qcdb` (dump segments of a subsystem), `qcdc` (bugcheck callback records), `qcdd` (segment names), `qcde` (memory runs), `qcdf` (subsystem map entry), `qcdg` (subsystem descriptors).

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68} | [qcscm8930.sys](./qcscm8930.md) | Secure Channel Manager. [internal IOCTL 0xC3514018](#internal-ioctl-0xc3514018) |
| \??\ACPI#QCOM0E30#2&daba3ff&0#{0b28c6f2-f696-4580-acb5-bf16c614b1c2} | [qcrpen8930.sys](./qcrpen8930.md) | RPE Notifier. [WPCD query-interface](./qcrpen8930.md#wpcd-interface) |
| \??\ACPI#QCOM0E00#2&daba3ff&0#{20e0709d-af59-4ce8-9d91-39e11b4c0231} | [qcpil8930.sys](./qcpil8930.md) | Peripheral Image Loader. [PIL query-interface](#pil-interface) |
| \??\Root#wpcrdmp#0000#{933b95c6-f9cf-4424-a9f8-f497f760aee5} | [wpcrdmp.sys](./wpcrdmp.md) | Crash Dump Driver (CDD). [CDD query-interface](#cdd-interface) |

The 4 targets are found with `IoRegisterPlugPlayNotification(EventCategoryDeviceInterfaceChange)` on their interface class GUID; on arrival a work item opens the target with `WdfIoTargetOpen` (with query-remove / remove-cancel / remove-complete callbacks) and gets the interface with `WdfIoTargetQueryForInterface`.

### Lumia 520 ACPI nodes

From the DSDT. This driver's node is `\_SB.CDI` (`_HID` `QCOM0E31`, no `_UID`, no resources, no method). The peer nodes are `\_SB.PILC` (`QCOM0E00`), `\_SB.RPEN` (`QCOM0E30`) and `\_SB.SCM0` (`QCOM0E90`).

The subsystem nodes have a `CONF` method that returns their memory regions as `{physical address, number of 4 KB pages}` pairs (the RPE segment format). Comparison with the hard-coded table of [Memory layout of a subsystem](#memory-layout-of-a-subsystem):  
| Node | `_HID` | `CONF` regions | Hard-coded entry |
|------|--------|----------------|------------------|
| `\_SB.AMSS` | QCOM0E80 | 0x89000000–0x8D400000 (0x4400 pages), 0x8D400000–0x8DA00000 (0x600) | AMSS 0x89000000–0x8DA00000 (same) |
| | | 0x00020000–0x00044000 (0x24), 0x00108000–0x0010E000 (6) | RPM (same) |
| | | 0x2A000000–0x2A010000 (0x10), 0x2A03F000–0x2A040000 (1) | SYS_IMEM 0x2A000000–0x2A03F000, 0x2A03F000–0x2A04F000 (larger) |
| | | 0x09000000 (8), 0x09200000 (8), 0x09400000–0x09410000 (0x10) | MDSP_RAM (the last one is 0x0940F800 in the table) |
| | | 0x01A01000 (1) | QDSS_ETB_REG (same) |
| | | 0x2E000000–0x2E030000 (0x30), 0x8FF00000–0x90000000 (0x100) | — (not in the table) |
| `\_SB.ADSP` | QCOM0E10 | 0x8DA00000–0x8F200000 (0x1800), 0x28400000–0x28420000 (0x20) | ADSP 0x8DA00000–0x8EC00000 (smaller), 0x28400000–0x28420000 (same) |
| `\_SB.RIVA` | QCOM0E20 | 0x8F200000–0x8F700000 (0x500) | WCN 0x8F000000–0x8F700000 (larger) |

The AMSS/ADSP `CONF` methods are evaluated by the modem/ADSP drivers (not documented yet), and the RIVA one by [qcwcn8930.sys](./qcwcn8930.md#rpe). The AMSS `CONF` also lists RPM, IMEM, MDSP and QDSS regions, not just the modem memory: probably everything that's dumped with the modem ?

### Initialisation

`DriverEntry` (0x410008) creates the WDF driver (pool tag `qcd0`), allocates the `TRACE_LOG` buffer (128 KB, non cached MDL pages) and initialises the subsystem list.  
`qccdiEvtDeviceAdd` (0x40E9FC → 0x40E8A8):
1. `WdfDeviceCreate`, `WdfDeviceSetDeviceState` (not disableable), `WdfDeviceCreateDeviceInterface({6EA2C81E-…})`, default parallel queue.
2. Reads `UserDefinedCrashDumpSegmentSize` / `UserDefinedCrashDumpSegmentAddress` (0x403CA8).
3. Reads `ExpectedCrashDumpSegmentSize` and registers the bugcheck callback of the [Dump Segment Directory](#dump-segment-directory) (0x402008).
4. Allocates the TZ buffers and waits for the SCM interface (0x4054B4), see [internal IOCTL 0xC3514018](#internal-ioctl-0xc3514018).
5. Registers the non-RPE subsystems (0x404878): `TRACE_LOG`, `AMSS`, `ADSP`, `RPM`, `SYS_IMEM`, `MDSP_RAM`, `QDSS_ETB_REG`, `MISC_REG` (registered twice: the second call only logs "Bugcheck registration already performed"), `AP_REG`, `WCN` and `TZ_LOG` (only if user defined). `AMSS`, `ADSP` and `WCN` are flagged as xPU protected.
6. Reads the crash dump cookies, and waits for the CDD interface (0x402E1C).
7. Waits for the PIL interface (0x403620) and the Notifier interface (0x4032D4).

When the Notifier interface arrives, qccdi8930.sys calls `Notifier_WpcdClientInit(RpeClientAdd, RpeClientRemove)`, then gets all the already registered RPE clients with `Notifier_WpcdGetAllSubsystemDescriptors` (228-byte descriptors, see [qcrpen8930.sys](./qcrpen8930.md#wpcd-interface)) and registers each of them. Later clients arrive through `RpeClientAdd` (0x403530) / `RpeClientRemove` (0x4035B0).  
When the CDD interface arrives, every known subsystem is registered with the CDD.

### Memory layout of a subsystem

`GetMemoryLayout` (0x4045B8) tries, in this order:
1. Hard coded entries (0x4040A0), by subsystem name:

| Subsystem | Physical ranges | xPU protected |
|-----------|-----------------|:-------------:|
| AMSS | 0x89000000–0x8DA00000 | yes |
| WCN | 0x8F000000–0x8F700000 | yes |
| RPM | 0x00020000–0x00044000, 0x00108000–0x0010E000 | |
| ADSP | 0x28400000–0x28420000, 0x8DA00000–0x8EC00000 | yes |
| SYS_IMEM | 0x2A000000–0x2A03F000, 0x2A03F000–0x2A04F000 | |
| MDSP_RAM | 0x09000000–0x09008000, 0x09200000–0x09208000, 0x09400000–0x0940F800 | |
| QDSS_ETB_REG | 0x01A01000–0x01A02000 | |
| MISC_REG | 0x80385000–0x80389400 | |

2. Internal memory regions (0x40449C): `AP_REG` = the 4 KB watchdog bark buffer given to TZ, `TRACE_LOG` = the 128 KB log buffer.
3. User defined region (0x403DB8): `TZ_LOG` = `UserDefinedCrashDumpSegmentAddress` / `UserDefinedCrashDumpSegmentSize`.
4. Memory segments given by the RPE client in its descriptor (0x403EB4), e.g. `SMD (MODEM)` = 0x80000000–0x80200000. Each segment is 16 bytes: physical address (8 bytes), number of pages (8 bytes).
5. Memory runs given by the [PIL interface](#pil-interface) (0x4037F8).

Every range is mapped with `MmMapIoSpace(MmNonCached)`. If nothing is found ("The crash dump memory layout is not defined for subsystem"), the registration fails with 0xE0148107. That's the case for `BAMMUX`, `SMD (RIVA)`, `SMSM (MODEM)` and `SMSM (RIVA)` on the Lumia 520. For `BAMMUX` it's expected: [qcbamdmux8930.sys](./qcbamdmux8930.md#subsystem-restart) calls `RpeClientInitMultiSegment` without any memory segment.

### Dump segments

`RegisterBugCheckCallbacks` (0x40E008) cuts each memory run into segments of at most `ExpectedCrashDumpSegmentSize` bytes (AMSS: 0x4A00 pages = 74 MB → 8 segments). For each segment it calls `KeRegisterBugCheckReasonCallback(KbCallbackSecondaryDumpData)` with the callback `BcSecondaryDumpDataCallback` (0x402698) and the component name `<subsystem>-<index>` (e.g. `AMSS-3`).  
The GUID of the secondary dump data of a segment is the GUID of the subsystem whose last byte is incremented by the index of the segment.

`BcSecondaryDumpDataCallback`:
- First call (size query, `OutBuffer` = NULL): returns the size of the segment. If the subsystem has not been halted yet, it sends the AP error state 7 to the subsystem through callback [1] of its RPE descriptor (`PerformHalt`, 0x4029C0). The halt is skipped for `ADSP` ("Bypassing halt for this subsystem (ADSP) due to a known issue").
- Second call: if the subsystem is xPU protected, unlocks the memory with the PIL `SetMemoryProtection` function (protection 0x20 `PAGE_EXECUTE_READ`), which actually sends the PAS "Shutdown" command to the TrustZone. When `AMSS` (modem SW region) is unlocked, the modem FW region `{BA58766D-…}` is unlocked too. Then it returns the virtual address and the size of the segment.

If the maximum size allowed by the kernel is smaller than `ExpectedCrashDumpSegmentSize`, the segment is skipped.

### Dump Segment Directory

A table describing all the registered segments, added to the dump by a separate bugcheck callback (`BcSecondaryDumpDataDirectoryCallback`, 0x4025EC, component `Crash Dump Directory`) with the GUID `{ADCDC296-12B8-44C0-B61F-2CDD7CE10377}`. Total size = 64 + 184 × number of segments. It is rebuilt each time a subsystem is registered ("Repopulating the Dump Segment Directory").

Header:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-0F | 18 54 CC A4 63 E6 9A 46 BD 10 10 02 71 5F 4A E5 | Signature `{A4CC5418-E663-469A-BD10-1002715F4AE5}` |
| 10-13 | 2C 00 00 00 | Offset of the first entry (44) |
| 14-17 | 00 00 00 00 | Is online dump. Set to 1 by the bugcheck callback |
| 18-1B | ?? ?? ?? ?? | Number of segments |
| 1C-2B | 18 54 CC A4 … | Signature again |

Then one 184-byte entry per segment:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | B8 00 00 00 | Entry size (184) |
| 04-13 | ? | GUID of the secondary dump data of the segment |
| 14-17 | ? | Index of the segment in the run |
| 18-1B | ? | Index of the run |
| 20-27 | ? | Physical address of the segment |
| 28-2B | ? | Virtual address of the segment |
| 30-37 | ? | Size in bytes of the segment |
| 38-B7 | ? | Subsystem name (128 chars, ANSI) |

After the last entry: the signature GUID followed by `14 00 00 00` (20) ?

---

### IOCTL

The device interface `{6EA2C81E-AC5E-4583-8767-37D4DBFBD6AB}` has a default queue with only `EvtIoDeviceControl` (`qccdiEvtIoDeviceControl`, 0x403914). It logs the request and completes **every** IOCTL code with `STATUS_SUCCESS` without reading or writing the buffers. There's no `EvtIoInternalDeviceControl`.

---

### internal IOCTL 0xC3514018

This IOCTL is sent by qccdi8930.sys to [qcscm8930.sys](./qcscm8930.md)

| Property | Value |
|----------|-------|
| Device | 0xC351 |
| Function | 0x6 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| Configure the watchdog bark FIQ | \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68} | 24 | 24 |

Sent once by `TzAssignDogBarkToFIQ` (0x4056DC), when the SCM interface arrives, with `WdfIoTargetSendInternalIoctlSynchronously`. The same 24-byte buffer is used as input and output.

#### Command 0xC02 "Configure the watchdog bark FIQ"

InputBuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 18 00 00 00 | Packet size ? |
| 04-07 | 10 00 00 00 | Packet type ? |
| 08-0B | 00 00 00 00 | Status |
| 0C-0F | 02 0C 00 00 | Command |
| 10-13 | ?? ?? ?? ?? | Physical address of the watchdog bark buffer (e.g. 0x9FEB6000). 4 KB of non cached pages allocated by qccdi8930.sys, then dumped as the `AP_REG` subsystem |
| 14-17 | 00 10 00 00 | Size of the buffer (0x1000) |

OutputBuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 18 00 00 00 | Packet size ? |
| 04-07 | 10 00 00 00 | Packet type ? |
| 08-0B | 01 00 00 00 | 1 = success |
| 0C-0F | 02 0C 00 00 | Command |
| 10-13 | ?? ?? ?? ?? | Physical address of the watchdog bark buffer |
| 14-17 | 00 10 00 00 | Size of the buffer |

If no byte is returned: "SCM return value not available", 0xC0000190 (`STATUS_TRUST_FAILURE`). If the status isn't 1: "Returning error from call to assign wdog…".

### Direct TZ call

> [!NOTE]
> `PerformControlClassSysCallFuncPtr` (0x405620) bypasses qcscm8930.sys: it writes a 20-byte command (`14 00 00 00`, `10 00 00 00`, status, command 0x806 "Reload image", secured channel ID) in a 32-byte non cached buffer and executes `SMC #0` with its physical address in R0.  
> It's only called by `sub_4036A8`, which looks for the `AMSS`, modem FW and `WCN` subsystems, sends the AP state 7 to one of them, reloads the images 4 (AMSS), 5 (modem FW), 1 (ADSP) and 6 (WCN), then executes the undefined instruction `UDF #0xFE` (crash). `sub_4036A8` is called by the PIL arrival work item only if `dword_40CB1C` ≠ 0, but this variable is only written by `sub_4036A8` itself: it's dead (debug ?) code.

---

### Interface GUID

CDI interface class (device interface of qccdi8930.sys)  
`{6EA2C81E-AC5E-4583-8767-37D4DBFBD6AB}`

CDD interface class ([wpcrdmp.sys](./wpcrdmp.md))  
`{933B95C6-F9CF-4424-A9F8-F497F760AEE5}`

RPE Notifier (WPCD) interface class and query-interface ([qcrpen8930.sys](./qcrpen8930.md))  
`{0B28C6F2-F696-4580-ACB5-BF16C614B1C2}`

PIL interface class ([qcpil8930.sys](./qcpil8930.md))  
`{20E0709D-AF59-4CE8-9D91-39E11B4C0231}`

SCM interface class ([qcscm8930.sys](./qcscm8930.md))  
`{41C66D2A-A9F1-40CA-A329-AE096C03EE68}`

#### CDD interface

Query-interface `{8BCB35C2-CB20-44E4-9A1E-33A016856CBF}`, size 24, version 1.  
| Offset | Function | Comment |
|--------|----------|---------|
| 0x10 | `RegisterSubsystem(Descriptor, Callbacks, *Context, *NotificationTable)` | Descriptor: version 1, subsystem GUID, name (64 chars), second string (128 chars). Callbacks: `GetFailureRecordCallback` (0x4028A0), `PerformHaltCallback` (0x402954), `SetMemoryProtectionCallback` (0x402AA0). Returns a context (2, 3, 4…) and a function used to send the memory layout |
| 0x14 | `DeregisterSubsystem(Context)` | |

The memory layout sent to the CDD (`SUBSYSTEM_PHYSICAL_MEMORY_DESCRIPTOR`) is built in MDL pages: number of runs (8 bytes), total number of pages (8 bytes), then 16 bytes per run (physical address, number of pages).

#### PIL interface

Query-interface `{2872B2FA-2469-4862-BAB8-FB47D7A12EF9}`, size 24, version 1.  
| Offset | Function | Comment |
|--------|----------|---------|
| 0x10 | `SetMemoryProtection(GUID *Subsystem, ULONG Protection)` | Unlocks the xPU protected memory of the image. In qcpil8930.sys (`sub_404448`) the value of `Protection` is only checked (1 → 0xC000000D): the function sends the SCM command 0x806 "Shutdown" (PAS_SHUTDOWN) for the channel of the image, and the TrustZone stops the subsystem and unlocks its memory. Returns 0xE0008000 if no image is known for this GUID, 0xE0008008 if the image has no channel ID |
| 0x14 | `GetMemoryRuns(GUID *Subsystem, RUNS *Runs)` | Called once with no buffer to get the number of runs, then with a buffer of 24 bytes per run. qcpil8930.sys (`sub_4045DC`) always returns a single run covering the segments of the image, already mapped with `MmMapIoSpace` |

Only the images authenticated by the TrustZone (IOCTL 0x9C412410 of qcpil8930.sys) are known by this interface. See [qcpil8930.sys](./qcpil8930.md#query-interface).

### Other GUID

Signature of the Dump Segment Directory  
`{A4CC5418-E663-469A-BD10-1002715F4AE5}`

Secondary dump data of the Dump Segment Directory  
`{ADCDC296-12B8-44C0-B61F-2CDD7CE10377}`

### Memory region GUID

| Region | GUID | Origin |
|--------|------|--------|
| TRACE_LOG | `{87D53509-C8CF-4528-B6E5-07839265CD61}` | qccdi8930.sys |
| AMSS (modem SW region) | `{936DC601-5530-4B82-9D2A-72A488BEC7C1}` | hard coded |
| modem FW region | `{BA58766D-ABF2-4402-88D7-90AB243F6C77}` | unlocked with AMSS |
| ADSP | `{D58464D3-5B28-4EA6-A2E2-E8E57C5C69B8}` | hard coded |
| RPM | `{7F8E50DC-FAD4-4A31-A243-3AB83708E49F}` | hard coded |
| SYS_IMEM | `{ADF3B53C-6657-4D83-83DA-A5F3B2544F3C}` | hard coded |
| MDSP_RAM | `{7D72D7E9-67DF-48B3-8F07-BE28C12009B5}` | hard coded |
| QDSS_ETB_REG | `{4F4F1970-8A20-40E2-B60B-99A52BB26700}` | hard coded |
| MISC_REG | `{D0BE3202-F9FC-4C07-BF21-48799499A4D6}` | hard coded |
| AP_REG | `{AB3A051F-EF0B-4A5F-A79A-80C243BA0848}` | qccdi8930.sys |
| WCN | `{93367D0F-35CE-4EC4-8E38-BB33030C58B2}` | hard coded |
| TZ_LOG | `{AA795F4D-3B0A-44A4-BB84-B7ECF3EE056A}` | registry |
| BAMMUX | `{CCCB7664-4951-40C3-8EB1-FDA3964A4479}` | RPE client of [qcbamdmux8930.sys](./qcbamdmux8930.md#subsystem-restart), registered without memory segment. Also enabled by that driver as a device interface once the A2 is ready |
| SMD (MODEM) | `{F9D15453-8335-434C-AA72-FCD925F135F3}` | RPE client |
| SMD (RIVA) | `{D30F94E9-9C90-4ED5-AE04-9266277C4721}` | RPE client |
| SMSM (MODEM) | `{1C90923A-DF5C-4761-9FD0-835B80F5281D}` | RPE client |
| SMSM (RIVA) | `{3AABE343-4EA2-43F8-8404-8A4A01088DCF}` | RPE client |

### Example of memory regions 

| Start address | End address | xPU protection | Region name | Comment |
|---------------|-------------|:--------------:|-------------|---------|
| 0x00020000 | 0x00044000 | :white_circle: | RPM | Resource Power Manager |
| 0x00108000 | 0x0010E000 | :white_circle: | RPM | Resource Power Manager |
| 0x01A01000 | 0x01A02000 | :white_circle: | QDSS_ETB_REG | Register within the Qualcomm Debug Subsystem (QDSS) that controls or accesses the Embedded Trace Buffer (ETB) |
| 0x09000000 | 0x09008000 | :white_circle: | MDSP_RAM | Modem Digital Signal Processor |
| 0x09200000 | 0x09208000 | :white_circle: | MDSP_RAM | Modem Digital Signal Processor |
| 0x09400000 | 0x0940F800 | :white_circle: | MDSP_RAM | Modem Digital Signal Processor |
| 0x28400000 | 0x28420000 | :no_entry: | ADSP | Application Digital Signal Processor |
| 0x2A000000 | 0x2A03F000 | :white_circle: | SYS_IMEM | Internal Memory |
| 0x2A03F000 | 0x2A04F000 | :white_circle: | SYS_IMEM | Internal Memory |
| 0x80000000 | 0x80200000 | :white_circle: | SMD (MODEM) | Shared Memory Device of the Modem. Given by the RPE client |
| 0x80385000 | 0x80389400 | :white_circle: | MISC_REG | Miscellaneous register ? |
| 0x89000000 | 0x8DA00000 | :no_entry: | AMSS | Advanced Mobile Subscriber Software |
| 0x8DA00000 | 0x8EC00000 | :no_entry: | ADSP | Application Digital Signal Processor |
| 0x8F000000 | 0x8F700000 | :no_entry: | WCN | Wireless Connectivity Network |
| 0x9FA35000 | 0x9FA55000 | :white_circle: | TRACE_LOG | Crash Dump Driver log buffer - memory allocated at the start of qccdi8930.sys (e.g.) |
| 0x9FEB6000 | 0x9FEB7000 | :white_circle: | AP_REG | Watchdog bark buffer given to TZ - memory allocated by qccdi8930.sys (e.g.) |

### Example of startup logs

Notes: these logs are stored in the `TRACE_LOG` memory region.

```
Successfully completed allocation of the trace log buffer.
InitSubsystemDescriptor: Initializing descriptor list resources.
DriverEntry Exit
qccdiEvtDeviceAdd Entry
No user defined crash dump segment size.
No user defined crash dump segment address.
Unable to locate driver parameters key: ExpectedCrashDumpSegmentSize. Assigned default value of: 10485760 bytes (10 MB).
SCM interface arrival notification.
Target Symbolic Link: \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68}, Device 0x88A80248, PDO 0x8895ADF0, File Object 0x8BC9E878, File Handle 0x80000244
Entering TzAssignDogBarkToFIQ.
Calling TZ via synchronous IOCTL to configure the watchdog bark FIQ.
Successfully configured watchdog bark timeout handler in TZ with physical buffer address of: 0x9FEB6000, and virtual buffer address of: 0x8B5E8000
Successfully processed the interface change notification from the TZ (SCM) driver.
IoRegisterPlugPlayNotification successfully registered for SCM interface notification.
Registering memory region for dump, halt not yet indicated for subsystem: TRACE_LOG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: TRACE_LOG
Attempting bugcheck registration for subsystem: TRACE_LOG
Starting ProcessTraceMemoryMapEntries
Crash dump memory map determined for an internal memory region, subsystem: TRACE_LOG, number of runs: 1, total number of pages: 0x20
Resized the Dump Segment Directory for 1 entries.
Bugcheck registration succeeded for subsystem: TRACE_LOG
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 1
Registering memory region for dump, xPU protection indicated, halt not yet indicated for subsystem: AMSS
Memory protection status being changed to 1 for subsystem: AMSS
Attempting bugcheck registration for subsystem: AMSS
Crash dump memory map determined by hard coded entries, subsystem: AMSS, number of runs: 1, total number of pages: 0x4A00
Resized the Dump Segment Directory for 9 entries.
Bugcheck registration succeeded for subsystem: AMSS
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 9
Registering memory region for dump, xPU protection indicated, halt not yet indicated for subsystem: ADSP
Memory protection status being changed to 1 for subsystem: ADSP
Attempting bugcheck registration for subsystem: ADSP
Crash dump memory map determined by hard coded entries, subsystem: ADSP, number of runs: 2, total number of pages: 0x1220
Resized the Dump Segment Directory for 12 entries.
Bugcheck registration succeeded for subsystem: ADSP
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 12
Registering memory region for dump, halt not yet indicated for subsystem: RPM, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: RPM
Attempting bugcheck registration for subsystem: RPM
Crash dump memory map determined by hard coded entries, subsystem: RPM, number of runs: 2, total number of pages: 0x2A
Resized the Dump Segment Directory for 14 entries.
Bugcheck registration succeeded for subsystem: RPM
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 14
Registering memory region for dump, halt not yet indicated for subsystem: SYS_IMEM, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: SYS_IMEM
Attempting bugcheck registration for subsystem: SYS_IMEM
Crash dump memory map determined by hard coded entries, subsystem: SYS_IMEM, number of runs: 2, total number of pages: 0x4F
Resized the Dump Segment Directory for 16 entries.
Bugcheck registration succeeded for subsystem: SYS_IMEM
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 16
Registering memory region for dump, halt not yet indicated for subsystem: MDSP_RAM, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: MDSP_RAM
Attempting bugcheck registration for subsystem: MDSP_RAM
Crash dump memory map determined by hard coded entries, subsystem: MDSP_RAM, number of runs: 3, total number of pages: 0x20
Resized the Dump Segment Directory for 19 entries.
Bugcheck registration succeeded for subsystem: MDSP_RAM
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 19
Registering memory region for dump, halt not yet indicated for subsystem: QDSS_ETB_REG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: QDSS_ETB_REG
Attempting bugcheck registration for subsystem: QDSS_ETB_REG
Crash dump memory map determined by hard coded entries, subsystem: QDSS_ETB_REG, number of runs: 1, total number of pages: 0x1
Resized the Dump Segment Directory for 20 entries.
Bugcheck registration succeeded for subsystem: QDSS_ETB_REG
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 20
Registering memory region for dump, halt not yet indicated for subsystem: MISC_REG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: MISC_REG
Attempting bugcheck registration for subsystem: MISC_REG
Crash dump memory map determined by hard coded entries, subsystem: MISC_REG, number of runs: 1, total number of pages: 0x5
Resized the Dump Segment Directory for 21 entries.
Bugcheck registration succeeded for subsystem: MISC_REG
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: MISC_REG.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 21
Registering memory region for dump, halt not yet indicated for subsystem: MISC_REG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: MISC_REG
Attempting bugcheck registration for subsystem: MISC_REG
Bugcheck registration already performed for: MISC_REG
Registering memory region for dump, halt not yet indicated for subsystem: AP_REG, current memory protection status: 0.
Memory protection status being changed to 0 for subsystem: AP_REG
Attempting bugcheck registration for subsystem: AP_REG
Crash dump memory map determined for an internal memory region, subsystem: AP_REG, number of runs: 1, total number of pages: 0x1
Resized the Dump Segment Directory for 22 entries.
Bugcheck registration succeeded for subsystem: AP_REG
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: MISC_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AP_REG.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 22
Registering memory region for dump, xPU protection indicated, halt not yet indicated for subsystem: WCN
Memory protection status being changed to 1 for subsystem: WCN
Attempting bugcheck registration for subsystem: WCN
Crash dump memory map determined by hard coded entries, subsystem: WCN, number of runs: 1, total number of pages: 0x700
Resized the Dump Segment Directory for 23 entries.
Bugcheck registration succeeded for subsystem: WCN
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: MISC_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AP_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: WCN.
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 23
The WpMemoryCaptureMode cookie has a value of: 0xFFFFFFFF
The WpSvLegacyFlag cookie has a value of: 0xFFFFFFFF
qccdiEvtDeviceAdd Exit
Entered EvtNotifyPilInterfaceChange.
PIL interface arrival notification.
Entered EvtNotifyNotifierInterfaceChange.
Target Symbolic Link: \??\ACPI#QCOM0E00#2&daba3ff&0#{20e0709d-af59-4ce8-9d91-39e11b4c0231}, Device 0x8BC63CC0, PDO 0x88959850, File Object 0x8BE21D48, File Handle 0x8000037C
Retrieving the PIL driver standard interface.
Notifier interface arrival notification.
Target Symbolic Link: \??\ACPI#QCOM0E30#2&daba3ff&0#{0b28c6f2-f696-4580-acb5-bf16c614b1c2}, Device 0x8BC59648, PDO 0x88959610, File Object 0x8BE22A88, File Handle 0x80000388
Retrieving the Notifier crash dump interface.
Registering all known RPE subsystems for crash dump since connection to the dependent RPEN interface was detected.
No new RPE clients need to be registered for crash dump services.
Registration of subsystem ID AMSS (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: AMSS.
Memory layout already defined for subsystem: AMSS.
Unable to determine the memory layout for subsystem: AMSS, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: AMSS
Memory protection status unchanged from it's current value of 1 for subsystem: AMSS
Attempting bugcheck registration for subsystem: AMSS
Bugcheck registration already performed for: AMSS
CDD (WpCrDmp) interface not yet available: AMSS, !STATUS!.
Registration of subsystem ID AMSS (GUID: !GUID!) completed successfully.
Registration of subsystem ID ADSP (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: ADSP.
Memory layout already defined for subsystem: ADSP.
Unable to determine the memory layout for subsystem: ADSP, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: ADSP
Memory protection status unchanged from it's current value of 1 for subsystem: ADSP
Attempting bugcheck registration for subsystem: ADSP
Bugcheck registration already performed for: ADSP
CDD (WpCrDmp) interface not yet available: ADSP, !STATUS!.
Registration of subsystem ID ADSP (GUID: !GUID!) completed successfully.
Registration of subsystem ID BAMMUX (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: BAMMUX
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to determine the memory layout for subsystem: BAMMUX, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: BAMMUX
Memory protection status unchanged from it's current value of 0 for subsystem: BAMMUX
Attempting bugcheck registration for subsystem: BAMMUX
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to retrieve the memory layout for subsystem: BAMMUX
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: BAMMUX, !STATUS!
CDD (WpCrDmp) interface not yet available: BAMMUX, !STATUS!.
Registration of subsystem ID BAMMUX (GUID: !GUID!) completed successfully.
Registration of subsystem ID BAMMUX (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: BAMMUX.
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to determine the memory layout for subsystem: BAMMUX, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: BAMMUX
Memory protection status unchanged from it's current value of 0 for subsystem: BAMMUX
Attempting bugcheck registration for subsystem: BAMMUX
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to retrieve the memory layout for subsystem: BAMMUX
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: BAMMUX, !STATUS!
CDD (WpCrDmp) interface not yet available: BAMMUX, !STATUS!.
Registration of subsystem ID BAMMUX (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMD (MODEM) (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: SMD (MODEM)
Crash dump memory map provided by the RPE client, subsystem: SMD (MODEM), number of runs: 1, total number of pages: 0x200
Registering memory region for dump, halt is indicated for subsystem: SMD (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (MODEM)
Attempting bugcheck registration for subsystem: SMD (MODEM)
Resized the Dump Segment Directory for 24 entries.
Bugcheck registration succeeded for subsystem: SMD (MODEM)
Repopulating the Dump Segment Directory.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: TRACE_LOG.
Added 8 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AMSS.
Added 3 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: ADSP.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: RPM.
Added 2 dump segments in 2 memory runs to the Dump Segment Directory for Subsystem: SYS_IMEM.
Added 3 dump segments in 3 memory runs to the Dump Segment Directory for Subsystem: MDSP_RAM.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: QDSS_ETB_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: MISC_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: AP_REG.
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: WCN.
No dump segments added to the directory for subsystem: BAMMUX
Added 1 dump segments in 1 memory runs to the Dump Segment Directory for Subsystem: SMD (MODEM).
Dump Segment Directory fully populated, Is Online Dump: No, total number of segments listed in the directory: 24
CDD (WpCrDmp) interface not yet available: SMD (MODEM), !STATUS!.
Registration of subsystem ID SMD (MODEM) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMD (MODEM) (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: SMD (MODEM).
Memory layout already defined for subsystem: SMD (MODEM).
Unable to determine the memory layout for subsystem: SMD (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (MODEM)
Attempting bugcheck registration for subsystem: SMD (MODEM)
Bugcheck registration already performed for: SMD (MODEM)
CDD (WpCrDmp) interface not yet available: SMD (MODEM), !STATUS!.
Registration of subsystem ID SMD (MODEM) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMD (RIVA) (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: SMD (RIVA)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to determine the memory layout for subsystem: SMD (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (RIVA)
Attempting bugcheck registration for subsystem: SMD (RIVA)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to retrieve the memory layout for subsystem: SMD (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMD (RIVA),!STATUS!
CDD (WpCrDmp) interface not yet available: SMD (RIVA), !STATUS!.
Registration of subsystem ID SMD (RIVA) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMD (RIVA) (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: SMD (RIVA).
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to determine the memory layout for subsystem: SMD (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (RIVA)
Attempting bugcheck registration for subsystem: SMD (RIVA)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to retrieve the memory layout for subsystem: SMD (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMD (RIVA), !STATUS!
CDD (WpCrDmp) interface not yet available: SMD (RIVA), !STATUS!.
Registration of subsystem ID SMD (RIVA) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMSM (MODEM) (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to determine the memory layout for subsystem: SMSM (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (MODEM)
Attempting bugcheck registration for subsystem: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to retrieve the memory layout for subsystem: SMSM (MODEM)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (MODEM), !STATUS!
CDD (WpCrDmp) interface not yet available: SMSM (MODEM), !STATUS!.
Registration of subsystem ID SMSM (MODEM) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMSM (MODEM) (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: SMSM (MODEM).
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to determine the memory layout for subsystem: SMSM (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (MODEM)
Attempting bugcheck registration for subsystem: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to retrieve the memory layout for subsystem: SMSM (MODEM)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (MODEM), !STATUS!
CDD (WpCrDmp) interface not yet available: SMSM (MODEM), !STATUS!.
Registration of subsystem ID SMSM (MODEM) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMSM (RIVA) (GUID: !GUID!) requested by notifier.
Creating the subsystem map entry for: SMSM (RIVA)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to determine the memory layout for subsystem: SMSM (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (RIVA)
Attempting bugcheck registration for subsystem: SMSM (RIVA)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to retrieve the memory layout for subsystem: SMSM (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (RIVA), !STATUS!
CDD (WpCrDmp) interface not yet available: SMSM (RIVA), !STATUS!.
Registration of subsystem ID SMSM (RIVA) (GUID: !GUID!) completed successfully.
Registration of subsystem ID SMSM (RIVA) (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: SMSM (RIVA).
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to determine the memory layout for subsystem: SMSM (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (RIVA)
Attempting bugcheck registration for subsystem: SMSM (RIVA)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to retrieve the memory layout for subsystem: SMSM (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (RIVA), !STATUS!
CDD (WpCrDmp) interface not yet available: SMSM (RIVA), !STATUS!.
Registration of subsystem ID SMSM (RIVA) (GUID: !GUID!) completed successfully.
Entered CddEvtNotifyScmInterfaceChange.
CDD interface arrival notification.
Target Symbolic Link: \??\Root#wpcrdmp#0000#{933b95c6-f9cf-4424-a9f8-f497f760aee5}, Device 0x8BC8E5A0, PDO 0x83B72A40, File Object 0x8BE36520, File Handle 0x80000400
Retrieving the crash dump driver standard interface.
Registering all known RPE subsystems for crash dump since connection to the dependent CDD interface was detected.
Memory layout already defined for subsystem: TRACE_LOG.
Unable to determine the memory layout for subsystem: TRACE_LOG, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: TRACE_LOG, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: TRACE_LOG
Attempting bugcheck registration for subsystem: TRACE_LOG
Bugcheck registration already performed for: TRACE_LOG
Updating the CDD Context with a value of 2 for the Map Entry used by: TRACE_LOG.
Updating the CDD notification function table for the Map Entry used by: TRACE_LOG.
Setting CDD subsystem memory layout, subsystem: TRACE_LOG (GUID: !GUID!) number of runs: 10935199152, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15563182080
Successfully registered with CDD: TRACE_LOG
Memory layout already defined for subsystem: AMSS.
Unable to determine the memory layout for subsystem: AMSS, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: AMSS
Memory protection status unchanged from it's current value of 1 for subsystem: AMSS
Attempting bugcheck registration for subsystem: AMSS
Bugcheck registration already performed for: AMSS
Updating the CDD Context with a value of 3 for the Map Entry used by: AMSS.
Updating the CDD notification function table for the Map Entry used by: AMSS.
Setting CDD subsystem memory layout, subsystem: AMSS (GUID: !GUID!) number of runs: 15230165512, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15183380480
Successfully registered with CDD: AMSS
Memory layout already defined for subsystem: ADSP.
Unable to determine the memory layout for subsystem: ADSP, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: ADSP
Memory protection status unchanged from it's current value of 1 for subsystem: ADSP
Attempting bugcheck registration for subsystem: ADSP
Bugcheck registration already performed for: ADSP
Updating the CDD Context with a value of 4 for the Map Entry used by: ADSP.
Updating the CDD notification function table for the Map Entry used by: ADSP.
Setting CDD subsystem memory layout, subsystem: ADSP (GUID: !GUID!) number of runs: 19525221032, size in bytes of memory run structures: 2 address of memory in first run: 0x30 size in bytes of memory in first run: 13560184832
Successfully registered with CDD: ADSP
Memory layout already defined for subsystem: RPM.
Unable to determine the memory layout for subsystem: RPM, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: RPM, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: RPM
Attempting bugcheck registration for subsystem: RPM
Bugcheck registration already performed for: RPM
Updating the CDD Context with a value of 5 for the Map Entry used by: RPM.
Updating the CDD notification function table for the Map Entry used by: RPM.
Setting CDD subsystem memory layout, subsystem: RPM (GUID: !GUID!) number of runs: 23820080744, size in bytes of memory run structures: 2 address of memory in first run: 0x30 size in bytes of memory in first run: 12885032960
Successfully registered with CDD: RPM
Memory layout already defined for subsystem: SYS_IMEM.
Unable to determine the memory layout for subsystem: SYS_IMEM, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: SYS_IMEM, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: SYS_IMEM
Attempting bugcheck registration for subsystem: SYS_IMEM
Bugcheck registration already performed for: SYS_IMEM
Updating the CDD Context with a value of 6 for the Map Entry used by: SYS_IMEM.
Updating the CDD notification function table for the Map Entry used by: SYS_IMEM.
Setting CDD subsystem memory layout, subsystem: SYS_IMEM (GUID: !GUID!) number of runs: 28115046064, size in bytes of memory run structures: 2 address of memory in first run: 0x30 size in bytes of memory in first run: 13589544960
Successfully registered with CDD: SYS_IMEM
Memory layout already defined for subsystem: MDSP_RAM.
Unable to determine the memory layout for subsystem: MDSP_RAM, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: MDSP_RAM, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: MDSP_RAM
Attempting bugcheck registration for subsystem: MDSP_RAM
Bugcheck registration already performed for: MDSP_RAM
Updating the CDD Context with a value of 7 for the Map Entry used by: MDSP_RAM.
Updating the CDD notification function table for the Map Entry used by: MDSP_RAM.
Setting CDD subsystem memory layout, subsystem: MDSP_RAM (GUID: !GUID!) number of runs: 32409755312, size in bytes of memory run structures: 3 address of memory in first run: 0x40 size in bytes of memory in first run: 13035896832
Successfully registered with CDD: MDSP_RAM
Memory layout already defined for subsystem: QDSS_ETB_REG.
Unable to determine the memory layout for subsystem: QDSS_ETB_REG, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: QDSS_ETB_REG, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: QDSS_ETB_REG
Attempting bugcheck registration for subsystem: QDSS_ETB_REG
Bugcheck registration already performed for: QDSS_ETB_REG
Updating the CDD Context with a value of 8 for the Map Entry used by: QDSS_ETB_REG.
Updating the CDD notification function table for the Map Entry used by: QDSS_ETB_REG.
Setting CDD subsystem memory layout, subsystem: QDSS_ETB_REG (GUID: !GUID!) number of runs: 36705029808, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 12912168960
Successfully registered with CDD: QDSS_ETB_REG
Memory layout already defined for subsystem: MISC_REG.
Unable to determine the memory layout for subsystem: MISC_REG, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: MISC_REG, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: MISC_REG
Attempting bugcheck registration for subsystem: MISC_REG
Bugcheck registration already performed for: MISC_REG
Updating the CDD Context with a value of 9 for the Map Entry used by: MISC_REG.
Updating the CDD notification function table for the Map Entry used by: MISC_REG.
Setting CDD subsystem memory layout, subsystem: MISC_REG (GUID: !GUID!) number of runs: 40999950768, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15036076032
Successfully registered with CDD: MISC_REG
Memory layout already defined for subsystem: AP_REG.
Unable to determine the memory layout for subsystem: AP_REG, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: AP_REG, current memory protection status: 0.
Memory protection status unchanged from it's current value of 0 for subsystem: AP_REG
Attempting bugcheck registration for subsystem: AP_REG
Bugcheck registration already performed for: AP_REG
Updating the CDD Context with a value of 10 for the Map Entry used by: AP_REG.
Updating the CDD notification function table for the Map Entry used by: AP_REG.
Setting CDD subsystem memory layout, subsystem: AP_REG (GUID: !GUID!) number of runs: 45294934976, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15567904768
Successfully registered with CDD: AP_REG
Memory layout already defined for subsystem: WCN.
Unable to determine the memory layout for subsystem: WCN, !STATUS!
Registering memory region for dump, halt not yet indicated for subsystem: WCN, current memory protection status: 1.
Memory protection status unchanged from it's current value of 1 for subsystem: WCN
Attempting bugcheck registration for subsystem: WCN
Bugcheck registration already performed for: WCN
Updating the CDD Context with a value of 11 for the Map Entry used by: WCN.
Updating the CDD notification function table for the Map Entry used by: WCN.
Setting CDD subsystem memory layout, subsystem: WCN (GUID: !GUID!) number of runs: 49589901592, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15284043776
Successfully registered with CDD: WCN
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to determine the memory layout for subsystem: BAMMUX, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: BAMMUX
Memory protection status unchanged from it's current value of 0 for subsystem: BAMMUX
Attempting bugcheck registration for subsystem: BAMMUX
No memory runs were detected for the subsystem: BAMMUX
Memory runs for this subsystem are not available: BAMMUX
The crash dump memory layout is not defined for subsystem: BAMMUX
Unable to retrieve the memory layout for subsystem: BAMMUX
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: BAMMUX, !STATUS!
Updating the CDD Context with a value of 12 for the Map Entry used by: BAMMUX.
Updating the CDD notification function table for the Map Entry used by: BAMMUX.
No memory runs available for this subsystem: BAMMUX.
Successfully registered with CDD: BAMMUX
Memory layout already defined for subsystem: SMD (MODEM).
Unable to determine the memory layout for subsystem: SMD (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (MODEM)
Attempting bugcheck registration for subsystem: SMD (MODEM)
Bugcheck registration already performed for: SMD (MODEM)
Updating the CDD Context with a value of 13 for the Map Entry used by: SMD (MODEM).
Updating the CDD notification function table for the Map Entry used by: SMD (MODEM).
Setting CDD subsystem memory layout, subsystem: SMD (MODEM) (GUID: !GUID!) number of runs: 58181451440, size in bytes of memory run structures: 1 address of memory in first run: 0x20 size in bytes of memory in first run: 15032385536
Successfully registered with CDD: SMD (MODEM)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to determine the memory layout for subsystem: SMD (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMD (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMD (RIVA)
Attempting bugcheck registration for subsystem: SMD (RIVA)
No memory runs were detected for the subsystem: SMD (RIVA)
Memory runs for this subsystem are not available: SMD (RIVA)
The crash dump memory layout is not defined for subsystem: SMD (RIVA)
Unable to retrieve the memory layout for subsystem: SMD (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMD (RIVA), !STATUS!
Updating the CDD Context with a value of 14 for the Map Entry used by: SMD (RIVA).
Updating the CDD notification function table for the Map Entry used by: SMD (RIVA).
No memory runs available for this subsystem: SMD (RIVA).
Successfully registered with CDD: SMD (RIVA)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to determine the memory layout for subsystem: SMSM (MODEM), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (MODEM)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (MODEM)
Attempting bugcheck registration for subsystem: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (MODEM)
Memory runs for this subsystem are not available: SMSM (MODEM)
The crash dump memory layout is not defined for subsystem: SMSM (MODEM)
Unable to retrieve the memory layout for subsystem: SMSM (MODEM)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (MODEM), !STATUS!
Updating the CDD Context with a value of 15 for the Map Entry used by: SMSM (MODEM).
Updating the CDD notification function table for the Map Entry used by: SMSM (MODEM).
No memory runs available for this subsystem: SMSM (MODEM).
Successfully registered with CDD: SMSM (MODEM)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to determine the memory layout for subsystem: SMSM (RIVA), !STATUS!
Registering memory region for dump, halt is indicated for subsystem: SMSM (RIVA)
Memory protection status unchanged from it's current value of 0 for subsystem: SMSM (RIVA)
Attempting bugcheck registration for subsystem: SMSM (RIVA)
No memory runs were detected for the subsystem: SMSM (RIVA)
Memory runs for this subsystem are not available: SMSM (RIVA)
The crash dump memory layout is not defined for subsystem: SMSM (RIVA)
Unable to retrieve the memory layout for subsystem: SMSM (RIVA)
Unable to register for callbacks by the Windows bugcheck handler: 0xE0148107.
Unable to register the memory region for subsystem: SMSM (RIVA), !STATUS!
Updating the CDD Context with a value of 16 for the Map Entry used by: SMSM (RIVA).
Updating the CDD notification function table for the Map Entry used by: SMSM (RIVA).
No memory runs available for this subsystem: SMSM (RIVA).
Successfully registered with CDD: SMSM (RIVA)
Registration of subsystem ID WCN (GUID: !GUID!) requested by notifier.
Updating the Descriptor for the Map Entry used by: WCN.
Memory layout already defined for subsystem: WCN.
Unable to determine the memory layout for subsystem: WCN, !STATUS!
Registering memory region for dump, halt is indicated for subsystem: WCN
Memory protection status unchanged from it's current value of 1 for subsystem: WCN
Attempting bugcheck registration for subsystem: WCN
Bugcheck registration already performed for: WCN
CDD (WpCrDmp) registration has already occurred for subsystem: WCN
Registration of subsystem ID WCN (GUID: !GUID!) completed successfully.
```
