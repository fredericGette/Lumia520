## vfbasics.dll

Application Verifier "basics" provider: the DLL that contains most of the user-mode verifier checks (`Handles`, `Locks`, `Memory`, `TLS`, `Exceptions`, `Threadpool`, `Leak`, `SRWLock`, fault injection…).  
`vfbasics.dll` is a native DLL (361 400 bytes, 808 functions, full symbols, PDB `vfbasics.pdb`). It imports only `ntdll.dll` and [vrfcore.dll](./vrfcore.md). Its only export is the entry point. It has two uses, like vrfcore.dll. In a tool such as [AppVerif.exe](../applications/appverif.md), its `DllMain` registers 12 *layers* with `vrfcore!VerifierRegisterLayerEx`: name, GUID, stops, properties. vrfcore.dll then writes their settings in the IFEO key of the target. In a verified process, the loader loads it from `VerifierDlls` as a verifier provider (`DLL_PROCESS_VERIFIER`). It then hooks about 270 functions of `ntdll`, `kernel32`/`kernelbase`, `advapi32`, `msvcrt`, `ole32`/`combase`, `oleaut32`, `user32`, `setupapi` and `verifier.dll`, and reports the errors it finds through `vrfcore!VerifierStopMessageEx`.  
The layer settings are read by vrfcore.dll at registration directly into the property variables of vfbasics.dll (see [vrfcore.dll](./vrfcore.md#layer-descriptor)). The layers `-verify` of AppVerif.exe enables (`Handles`, `Locks`, `Exceptions`, `Memory`, `TLS`, `Threadpool`, `Leak`, `SRWLock`, and `LowRes` with `-faults`) are all registered here, except `Heaps` (vrfcore.dll). This DLL is never named by AppVerif.exe: it must be listed in `VerifierProviders` (not checked).

Location on the phone: `C:\Windows\System32\vfbasics.dll` ? (extracted next to `AppVerif.exe` and `vrfcore.dll`).  

### Imports

| DLL | Functions |
|-----|-----------|
| [vrfcore.dll](./vrfcore.md) | `VerifierRegisterProvider`, `VerifierRegisterLayerEx`, `VerifierUnregisterLayer`, `VerifierIsLayerEnabled`, `VerifierQueryGlobalProperties`, `VerifierStopMessageEx`, `VerifierIsInsideVerifierStop`, `VerifierHandleVerifierStopException`, `VerifierGetAppCallerAddress`, `VerifierRegisterFaultInjectProvider`, `VerifierShouldFaultInject`, `VerifierSetFaultInjectionProbability`, `VerifierSuspendFaultInjection`, `VerifierSetAPIClassName`, `VerifierEnable/DisableFaultInjectionTargetRange`, `VerifierEnable/DisableFaultInjectionExclusionRange` |
| ntdll.dll (loader) | `LdrLoadDll`, `LdrGetDllHandle`, `LdrGetProcedureAddress`, `LdrFindEntryForAddress`, `LdrQueryProcessModuleInformation`, `LdrLockLoaderLock`, `LdrUnlockLoaderLock`, `LdrDisableThreadCalloutsForDll`, `RtlImageNtHeader`, `RtlDllShutdownInProgress` |
| ntdll.dll (objects, threads, memory) | `NtQueryObject`, `NtClose`, `NtCreateEvent`, `NtSetEvent`, `NtClearEvent`, `NtWaitForSingleObject`, `NtWaitForMultipleObjects`, `NtOpenThread`, `NtSuspendThread`, `NtResumeThread`, `NtGetContextThread`, `NtQueryInformationThread`, `NtQueryInformationProcess`, `NtSetInformationProcess`, `NtTerminateProcess`, `NtQuerySystemInformation`, `NtAllocateVirtualMemory`, `NtFreeVirtualMemory`, `NtQueryVirtualMemory`, `NtReadVirtualMemory`, `NtCreateSection`, `NtOpenSection`, `NtMapViewOfSection`, `NtUnmapViewOfSection`, `NtOpenKey`, `NtCreateKey`, `NtDelayExecution`, `NtQueryPerformanceCounter` |
| ntdll.dll (verifier, debug, exceptions) | `RtlApplicationVerifierStop`, `RtlAddVectoredExceptionHandler`, `RtlRemoveVectoredExceptionHandler`, `RtlRaiseException`, `RtlRaiseStatus`, `RtlCaptureStackBackTrace`, `RtlWalkFrameChain`, `RtlRandom`, `DbgPrint`, `DbgPrintEx` |
| ntdll.dll (Rtl) | heaps (`RtlCreateHeap`, `RtlDestroyHeap`, `RtlAllocateHeap`, `RtlFreeHeap`, `RtlSizeHeap`), critical sections and resources (`RtlInitializeCriticalSection*`, `RtlEnter/Leave/TryEnterCriticalSection`, `RtlpWaitForCriticalSection`, `RtlInitializeResource`, `RtlAcquireResource*`…), AVL/splay tables, SLists, `RtlRegisterWait`, `RtlDeregisterWait(Ex)`, `RtlSetThreadPoolStartFunc`, `RtlSetEnvironmentVariable`, strings, `RtlAcquirePebLock`, `RtlFindClearBitsAndSet`, `RtlNtStatusToDosError` |
| ntdll.dll (CRT) | `memcpy`, `memset`, `wcslen`, `wcsstr`, `wcstoul`, `_wcsicmp`, `_wcsnicmp`, `_stricmp`, `iswspace`, `__chkstk`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `RtlUnhandledExceptionFilter`, `__C_specific_handler` |

The `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind` / `RtlUnhandledExceptionFilter` / `__C_specific_handler` imports are the `/GS` cookie and SEH code. No kernel32 or api-ms-win import: the original functions of the hooked DLLs are called through the thunk tables filled by the loader.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `verifier.dll` | `LdrLoadDll` + `LdrGetProcedureAddress` (`AVrfInitializeVerifierFunctionPointers`, 0x1000818C) | `VerifierCheckPageHeapAllocation` (optional) and `VerifierGetProviderHelper`, which fills a 124-byte table: stack trace functions (`RtlLogStackTrace`, release, `GetStackTraceAddressEx`) and the heap "path caller" function. Its 13 public functions are also hooked ([Hooks](#hooks)) |
| `ntdll.dll` | `LdrGetDllHandle` / `LdrLoadDll` + `LdrGetProcedureAddress` | `RtlReportException` (exception reporting), the SRW lock functions (`RtlInitializeSRWLock`, `RtlAcquire/ReleaseSRWLockExclusive/Shared`), `Rtl{Create,Extend,Allocate,Free}MemoryBlockLookaside` (Leak and SRWLock trackers), `RtlInitializeCriticalSection` (to find the ntdll range) |
| `user32.dll` | `LdrGetProcedureAddress` on its base, once it's loaded (`AVrfpInitialTPCheckForUser32`, 0x1000D1B8) | `EnumThreadWindows`, `RealGetWindowClassW`, `PeekMessageW`: Threadpool checks for windows and messages left by a callback (stops 0x702, 0x703) |
| `kernelbase.dll`, `kernel32.dll`, `combase.dll`, `nsi.dll`, `mfplat.dll`, `threadpoolwinrt.dll`, `rtworkq.dll` | Names compared in `AVrfpDllLoadCallback` (0x10006934) | Base and size saved (callbacks running from these DLLs are treated differently by the Threadpool checks ?) |
| `wudfhost.exe` | Compared with the process image (`AVrfpInitializeThreadPoolCheck`, 0x1000D3F4) | Base and size saved (UMDF host: special case of the Threadpool checks ?) |
| DLL name lists (below) | `AVrfpAddrRangeInitialize` (0x10008658), `AVrfpLeakDllInExcludeStaticList` (0x1000A7F4) | Ranges where some errors are ignored |

The four range collections built by `AVrfpAddrRangeInitialize` (the address range of each DLL is added when it's loaded):

| Collection | DLLs | Used by |
|------------|------|---------|
| `AVrfpIgnoreAvDlls` | `winlogon.exe`, `sppsvc.exe`, `OESpamFilter.dll`, `MSWSOCK.DLL`, `ntdll.dll`, `gdiplus.dll`, `user32.dll`, `TTTraceWriter.dll`; on builds < 5600 also `licwmi.dll`, `dpcdll.dll`, `licdll.dll`, `Sbscrdll.dll` | First-chance access violations ignored in these modules (`Exceptions`) |
| `AVrfpIgnoreOutbufDlls` | `USER32.DLL`, `DNSAPI.DLL`, `mswsock.dll`, `SPOOLSS.DLL`, `localspl.dll`, `NETAPI32.DLL`, `netlogon.dll`, `asfsipc.dll`, `framedyn.dll`, `iac25_32.ax`, `rpcss.dll`, `ODBC32.dll`, `catsrv.dll`, `GDI32.DLL`, `iuengine.dll` | Output buffer filling (`AVrfpInitOutputBuffer`) skipped for calls from these DLLs (`Memory`) |
| `AVrfpIgnoreVirtualSpaceDlls` | `UxTheme.dll`, `WINHTTP.DLL`; `kernel32.dll` on builds < 5027 | Virtual memory checks (`Memory`) |
| `AVrfpPrivateLocksDlls` | `ntdll.dll` | Critical sections private to a DLL (stop 0x215) |

The `Leak` layer also has a static, sorted list of 36 DLLs whose leaks are never reported (`adsldp.dll`, `detours.dll`, `deviceaccess.dll`, `esent.dll`, `jscript.dll`, `ShimEng.dll`, `taskschd.dll`, `Urlmon.dll`, `wintypes.dll`, `wmp.dll`…, table at 0x100011B0), in addition to the `ExcludeDlls` property.

### Exports

Only the entry point (`DllMain`, 0x10004C40). Functions named `Verifier*` in the binary (`VerifierSetRuntimeFlags`, `VerifierCreateRpcPageHeap`, `VerifierIsCurrentThreadHoldingLocks`…) aren't exported: they replace the `verifier.dll` exports with the same name ([Hooks](#hooks)).

### Startup

`DllMain` (0x10004C40) calls `_DllMainCRTStartupForGS2` (cookie) on reason 4, then `_DllMain` (0x10004C78):

- **`DLL_PROCESS_VERIFIER`** (4, only in a verified process): see [below](#dll_process_verifier).
- **`DLL_PROCESS_ATTACH`** (once): saves the module handle, prepares the heap walk (`AVrfInitializeHeapWalk`) and the [verifier.dll pointers](#dependencies), initialises the Leak and SRWLock trackers (`AVrfLeakInitialize`, `AVrfSRWLockCheckInitialize`: memory block lookasides of 1 MB, AVL tables; only in a verified process), then registers the layers (`VfRegisterBasicsLayers`, 0x10005A38). In a tool it stops there. In a verified process it continues:
  1. `VfSetVerifierBitsForBasicsLayers` (0x10005F6C): `VerifierIsLayerEnabled(NULL, layer)` for every layer into the `AVrf*CheckEnabled` flags, then sets or clears the matching bit (from `ViCoreLayerBitArray`, the same table as vrfcore.dll) in the verifier flags of the provider descriptor (+0x14). `Handles` enabled → `VfEnableHandleVerifier`: `NtSetInformationProcess(-1, ProcessHandleTracing (32), …)`, with the `Traces` property as number of entries if it's above 0x1000. `LowRes` with its `STACKS` property → `VfEnableStackVerifier`: with a debugger, sets bit 0x10000 of `PEB.NtGlobalFlag` (`FLG_DISABLE_STACK_EXTENSION`).
  2. `NtQuerySystemInformation(SystemBasicInformation)`; notes whether the image is large address aware.
  3. Sets the environment variable `OANOCACHE=1` (no BSTR cache in oleaut32, so that BSTR errors are visible).
  4. `AVrfpInitializeExceptionChecking`: vectored exception handler `AVrfpVectoredExceptionHandler` (first), exception log (9 472 bytes), `ntdll!RtlReportException`.
  5. Thread table, [fault injection](#lowres-fault-injection) (`AVrfpInitFaultInjectionSupport`), deadlock detection if the `DeadLock` bit (0x800) is set, Threadpool checks (`AVrfpInitializeThreadPoolCheck`).
- **`DLL_THREAD_ATTACH` / `DETACH`**: per-thread verifier data (`AvrfpThreadAttach` / `AvrfpThreadDetach`), in a verified process only.
- **`DLL_PROCESS_DETACH`**: unregisters every layer (`VfUnregisterBasicsLayers`); in a verified process also removes the exception handler and frees the critical section tree, the free memory callbacks and the Threadpool data.

Registration errors print `AVRF: Spy [VfRegisterBasicsLayers, <line>]: <status>` and fail the attach. If `Core.MinimumMemoryOverhead` is set (`VerifierQueryGlobalProperties`), the call trackers are destroyed.

### DLL_PROCESS_VERIFIER

The third argument receives `&AVrfpProvider`. `_DllMain`:

1. Saves `PEB.OSBuildNumber` and the service pack. On build 2600 (XP): descriptor length 0x1C and the `oleaut32.dll` entry removed. Otherwise `AVrfpCopyThunksToRelocatedDlls` (0x100067F0) builds the thunk tables for the API sets: the `advapi32` registry thunks are appended to the `kernel32` table, the whole `kernel32` table is copied for `kernelbase.dll` (with `CloseHandle`, `WaitFor*Object(s)(Ex)` and `CreateFileA/W` replaced by `AVrfpKernelbase*` versions), the `ole32` table is copied for `combase.dll`.
2. `VerifierRegisterProvider(module, &AVrfpProvider)` (vrfcore.dll), DLL load list, a private heap (`RtlCreateHeap(0x1002)`: `HEAP_GROWABLE | HEAP_CLASS_1`), the [range collections](#dependencies), the call trackers, the critical section tree, a verifier TLS slot (bit of `PEB.TlsBitmap`), the free memory callbacks.

On failure, with `OSBuildNumber` ≤ 3790 it prints "AVRF: Verifier Provider failed to initialized itself for DLL_PROCESS_VERIFIER. Process will be terminated." and calls `NtTerminateProcess(-1, STATUS_UNSUCCESSFUL)`; otherwise it returns FALSE. Same logic as [vrfcore.dll](./vrfcore.md#dll_process_verifier).

`AVrfpProvider` (`RTL_VERIFIER_PROVIDER_DESCRIPTOR`, 0x1001D3D4):

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 0x2C, Length |
| 0x04 | 4 | DLL descriptors (`AVrfpExportDlls`, 0x1001DAA0) |
| 0x08 | 4 | `AVrfpDllLoadCallback` (0x10006934) |
| 0x0C | 4 | `AVrfpDllUnloadCallback` (0x10006C7C) |
| 0x10 | 4 | Filled by ntdll: image name ? |
| 0x14 | 4 | Filled by ntdll: verifier flags (`VerifierFlags` of the IFEO key); rewritten by `VfSetVerifierBitsForBasicsLayers` |
| 0x18 | 4 | Filled by ntdll: debug flags. Bits tested: 0x1000 print the dirty stack ranges, 0x2000 print every exception, 0x4000 print `LdrLoadDll` calls, 0x10000 DLL entry point traces |
| 0x1C | 4 | Filled by ntdll: stack trace function (`AVrfpGetStackTraceAddress`, replaced by a fake one on XP) |
| 0x20–0x24 | 8 | Filled by ntdll |
| 0x28 | 4 | `AVrfpNtdllHeapFreeCallback` (0x100103B8): free memory notifications + removal from the Leak tracker |

Bits of the verifier flags (+0x14) tested by the hooks: 0x20 TLS (index scrambling), 0x40 DirtyStacks, 0x80 runtime flag of `VerifierSetRuntimeFlags`, 0x200 DangerousAPIs, 0x800 DeadLock, 0x1000 Exceptions, 0x2000 Memory, 0x40000 Locks (private locks).

### Hooks

DLL descriptors (16 bytes: name, flags, ?, thunk table) and thunks (12 bytes: ANSI function name, original filled by the loader, replacement):

| DLL | Count | Functions hooked |
|-----|-------|------------------|
| ntdll.dll | 152 | Virtual memory and sections (`NtAllocate/Free/Protect/Read/WriteVirtualMemory`, `NtMapViewOfSection`…), files and I/O (`NtCreateFile`, `NtReadFile`, `NtDeviceIoControlFile`, `NtFsControlFile`, `NtCancelIoFile`…), keys (`NtCreateKey`, `NtOpenKey`, `NtSetValueKey` and 25 others), events, threads and processes (`NtSuspendThread`, `NtTerminateThread`, `NtSetInformationProcess`…), `NtClose`, `NtDuplicateObject`, `NtWaitFor*`, critical sections, resources and SRW locks, heaps (`RtlAllocateHeap`, `RtlReAllocateHeap`, `RtlFreeHeap`, `RtlCreateHeap`, `RtlDestroyHeap`, `RtlFreeUnicodeString`, `RtlFreeSid`), thread pool (`TpAlloc*`, `TpSimpleTryPost`, `RtlQueueWorkItem`, `RtlRegisterWait`, timer queues, `RtlSetThreadPoolStartFunc`), `LdrLoadDll`, `LdrUnloadDll`, `LdrGetProcedureAddress`, `RtlExitUserThread`, `RtlExitUserProcess`, `_vsnprintf`… |
| kernel32.dll | 48 (+14 from advapi32) | `HeapCreate/Destroy/Alloc/ReAlloc/Free`, `Global*` / `Local*`, `VirtualAlloc/Free(Ex)`, `UnmapViewOfFile(Ex)`, `CloseHandle`, `CreateThread`, `ExitThread`, `TerminateThread`, `SuspendThread`, `FreeLibraryAndExitThread`, `Tls*`, `WaitFor*Object(s)(Ex)`, `CreateEventA/W`, `CreateFileA/W`, `GetTickCount`, `IsBad*Ptr`, `MultiByteToWideChar`, `WideCharToMultiByte`, `SetThreadAffinityMask`, `SetThreadPriority`, `SetProcessWorkingSetSize(Ex)` |
| kernelbase.dll | 62 | Copy of the kernel32 table at run time |
| advapi32.dll | 14 | `RegCreateKey(Ex)A/W`, `RegOpenKey(Ex)A/W`, `RegCloseKey`, `RegSetValue(Ex)A/W`, `RegNotifyChangeKeyValue` |
| msvcrt.dll | 15 | `malloc`, `calloc`, `realloc`, `free`, `operator new/delete` (and `[]`), `_strdup`, `_wcsdup`, `_mbsdup`, `_vsnprintf`, `_vsnwprintf`, `_snprintf`, `_snwprintf` |
| ole32.dll / combase.dll | 8 | `CoInitialize(Ex)`, `CoUninitialize`, `RoInitialize`, `RoUninitialize`, `CoTaskMemAlloc/Realloc/Free` |
| oleaut32.dll | 7 | `SysAllocString*`, `SysReAllocString*`, `SysFreeString`, `VariantClear` |
| user32.dll | 8 | `PostMessageA/W`, `PostThreadMessageA/W`, `PostQuitMessage`, `RegisterPowerSettingNotification`, `UnregisterPowerSettingNotification`, `SetClipboardData` |
| setupapi.dll | 3 | `SetupDiCreateDevRegKeyA/W`, `SetupDiOpenDevRegKey` |
| verifier.dll | 13 | `VerifierQueryRuntimeFlags`, `VerifierSetRuntimeFlags`, `VerifierCreate/DestroyRpcPageHeap`, `VerifierEnable/DisableFaultInjectionTarget/ExclusionRange`, `VerifierSetFaultInjectionProbability`, `VerifierIsDllEntryActive`, `VerifierIsCurrentThreadHoldingLocks`, `VerifierAdd/DeleteFreeMemoryCallback`: the verifier.dll API is served by vfbasics.dll (most of them return `STATUS_INVALID_PARAMETER` unless `PEB.NtGlobalFlag` has 0x100) |

Each replacement gets the original through `AVrfpGetThunkDescriptor(table, index)`. Most of them do three things: fault injection (`VerifierShouldFaultInject`, see [LowRes](#lowres-fault-injection)), a check of the arguments, and logging the resource created or freed in the Leak tracker (`AVrfpLeakLogResource` / `AVrfpLeakRemoveResource`).

`AVrfpDllLoadCallback` (0x10006934), for every DLL loaded:
1. Replaces its entry point with `AVrfpStandardDllEntryPointRoutine` (runs it under an exception filter: stop 0x60D). The original goes in a 40-byte record of `DllLoadListHead`.
2. Adds its range to the collections enabled by the verifier flags, and to the fault injection target / exclusion ranges if its name is in `Include` / `Exclude`.
3. `DangerousAPIs` with `DllMainCheck`: stop 0x103 if a `DllMain` is running (`VerifierIsDllEntryActive`).
4. Logs the load in the DLL tracker and the Leak tracker (`AVrfLeakDllLoad`).

`AVrfpDllUnloadCallback` does the reverse: free memory notifications for the range, leaked TLS slots (stop 0x350), fault ranges removed, stop 0x104 (FreeLibrary during DllMain), leak report of the DLL (`AVrfLeakDllUnload` → [Leak](#layers)).

### Layers

All are registered with `VerifierRegisterLayerEx(module, descriptor, 0)` (no TLS slot), so [VerifierEnableLayer](./vrfcore.md#verifierenablelayer-0x10006bcc) adds `vfbasics.dll` after the first name of `VerifierDlls`. Descriptor fields as in [vrfcore.dll](./vrfcore.md#layer-descriptor): +0x00 `&AVrfpProvider`, +0x0C 1, +0x18 group, +0x1C description (string resource of vfbasics.dll), +0x20 friendly name (`LowRes` only: "Low Resource Simulation"), +0x28 a bit mask.

| Layer | GUID | Group | Descriptor | +0x28 | Stops | Description (resource) |
|-------|------|-------|------------|-------|-------|------------------------|
| `Handles` | `{9760941A-8DA5-4dbe-843B-0EBD376CAB02}` | Basics | 0x1001CC40 | 0x4 | 0x300–0x305 | 0x196 "Checks for handle errors…" |
| `Locks` | `{159D60EC-F459-456b-A27B-1076AD59F8F4}` | Basics | 0x1001CBA8 | 0x2 | 0x200–0x215 | 0x190 "Checks for errors in lock usage…" |
| `Memory` | `{8A70B8A4-4FA6-41c3-85EE-595FCB3E1051}` | Basics | 0x1001CAD8 | 0x40 | 0x600–0x61E | 0x199 "Checks usage of virtual memory APIs…" |
| `TLS` | `{EDDA96DB-D216-467d-BE3C-8603745EDA43}` | Basics | 0x1001CB40 | 0x20 | 0x350–0x352 | 0x193 |
| `Exceptions` | `{F86B022F-E589-4e8f-B0DD-6B7AF9D71A59}` | Basics | 0x1001CA40 | 0x80 | 0x650 | 0x195 "Detects first chance access violation exceptions…" |
| `DirtyStacks` | `{970bd287-2e5a-4a06-9084-9e394d4c2697}` | Miscellaneous | 0x1001C9D8 | 0x400 | none | 0x194 "Helps catch uninitialized variables" |
| `LowRes` | `{d030d0fd-3cda-4435-8f62-c2690fdd948f}` | none | 0x1001C608 | 0x100 | none | 0x19D "Low Resource Simulation also known as Fault Injection…" |
| `DangerousAPIs` | `{02A5B40C-2F22-4409-BB37-7EF0D3F34A88}` | Miscellaneous | 0x1001C970 | 0x200 | 0x100–0x108 | 0x19A |
| `TimeRollOver` | `{de35a0c0-d3b8-11d9-8cd5-0800200c9a66}` | Miscellaneous | 0x1001C468 | 0 | none | 0x19B "Forces the GetTickCount API to roll over faster…" |
| `Threadpool` | `{F15FC24E-53A0-444D-8D28-F7697EDD9C83}` | Basics | 0x1001C8D8 | 0x800 | 0x700–0x70D | 0x19C "Checks for dirty threadpool thread…" |
| `Leak` | `{81EEC8DA-0E61-4942-8037-9A6C4A86510D}` | Basics | 0x1001C788 | 0x800000 | 0x900–0x906 | 0x19F "Checks that when a dll is unloaded there are no outstanding resources allocated by it." |
| `SRWLock` | `{6335D1CF-7955-414e-8C6A-1A40AC9357AC}` | Basics | 0x1001C6F0 | 0x10000000 | 0x250–0x257 | 0x1A0 |

`Leak` and `SRWLock` are only registered when their tracker could be initialised (always in a tool, where no lookaside is needed). A 13th descriptor, `InputOutput` (`{5FE32372-CE71-43f9-B75D-6AD4B1B08D6A}`, 0x1001C840, stops 0x800–0x804, properties `FillReadBuffer` and `ForcePendingIO`), is in the binary but never registered: its stops are only reached through the old-style `VerifierStopMessage` routing, and its enable flag (`AVrfIoCheckEnabled`) isn't set by `VfSetVerifierBitsForBasicsLayers`. vfbasics.dll doesn't register `COM` or `RPC` either (only their description strings 0x191 / 0x192 are in its resources).

Every stop has `ErrorReport` 0x1A1 and `Severity` 0x3F by default (0x181 / 0xF for SRWLock 0x255 and 0x257), `Flavor` 0x20, or 0x22 for the non-continuable ones (0x204–0x206, 0x351, 0x608, 0x61B, 0x61C, 0x650, 0x101).

#### Properties

Name and description are string resources replaced at registration, except for `LowRes` whose names are literal strings. Values are the defaults compiled in the binary (0xFFFFFFFF = unset / 0).

| Layer | Property | Type | Default | Meaning |
|-------|----------|------|---------|---------|
| `Handles` | `Traces` | REG_DWORD | 0x1000 | "Maximum number of traces in the handle history buffer" |
| `Memory` | `ExecWritePage` | boolean | 0 | Stops 0x61D (executable heap created) / 0x61E (executable memory allocated) |
| `DangerousAPIs` | `DllMainCheck` | boolean | 0 | "Check LoadLibrary/FreeLibrary calling when DllMain is active" (stops 0x103 / 0x104) |
| `TimeRollOver` | `Delay` | REG_DWORD | 300 | "Delay until rollover in (seconds)": the `GetTickCount` hook returns `tick − 1000 × Delay − 1` |
| `Threadpool` | `AsyncCheck` | REG_DWORD | 0 | "Check asynchronous calls that require a persistent thread" (stop 0x706) |
| `Leak` | `ExcludeDlls` | REG_SZ (0x1FE bytes) | empty | Comma separated DLLs excluded from leak detection (upper-cased at registration) |
| `LowRes` | `Include` / `Exclude` | REG_MULTI_SZ (0x400 bytes) | `*` / empty | DLLs whose calls are / aren't faulted |
| `LowRes` | `TimeOut` | REG_DWORD | 2000 | Grace period in ms (`VerifierSuspendFaultInjection`) |
| `LowRes` | `WAIT`, `HEAP_ALLOC`, `VIRTUAL_ALLOC`, `REGISTRY`, `FILE`, `EVENT`, `MAP_VIEW`, `OLE_ALLOC` | REG_DWORD | `HEAP_ALLOC` and `OLE_ALLOC` 20000, others 0 | Probability per 1 000 000 for each class |
| `LowRes` | `STACKS` | boolean | 0 | "Disable automatic stack expansion" |

#### LowRes (fault injection)

`AVrfpInitFaultInjectionSupport` (0x10005254), only if `LowRes` is enabled: reserves 8 fault classes from vrfcore.dll (`VerifierRegisterFaultInjectProvider(8, &BasicsApiClassBase)`), parses `Include` (a `*` entry → the whole address space is a target) and `Exclude`, applies `TimeOut`, sets the probability and the name of each class:

| Class | Name | Property | Example of hooks |
|-------|------|----------|------------------|
| base+0 | "Wait APIs" | `WAIT` | `WaitFor*Object(s)` |
| base+1 | "Heap allocations" | `HEAP_ALLOC` | `RtlAllocateHeap`, `malloc`, `new`, `HeapAlloc`, `LocalAlloc`… |
| base+2 | "Virtual space allocations" | `VIRTUAL_ALLOC` | `NtAllocateVirtualMemory`, `VirtualAlloc` |
| base+3 | "Registry APIs" | `REGISTRY` | `NtCreateKey`, `NtOpenKey`, `Reg*` |
| base+4 | "File APIs" | `FILE` | `NtCreateFile`, `NtOpenFile`, `CreateFileA/W` |
| base+5 | "Event APIs" | `EVENT` | `NtCreateEvent`, `CreateEventA/W` |
| base+6 | "Map view operations" | `MAP_VIEW` | `NtMapViewOfSection`, `NtCreateSection`, `NtOpenSection` |
| base+7 | "OLE string allocations" | `OLE_ALLOC` | `SysAllocString*`, `CoTaskMemAlloc` |

A faulted call doesn't call the original and returns a failure (`NtCreateFile`: 0xC0000017 `STATUS_NO_MEMORY`). With a conditional breakpoint set (debugger extension), it prints "AVRF: conditional breakpoint %X hit." and breaks.

#### Other checks

- **Exceptions**: `AVrfpVectoredExceptionHandler` logs every exception, then `AVrfpCheckFirstChanceException`: with the `Exceptions` bit, a first-chance access violation outside `AVrfpIgnoreAvDlls` (and not on an address of type `MEM_IMAGE`) is reported: execute access → stop 0x650 ("Attempt to execute code in non-executable memory (first chance)"); read / write → old-style stop 0x13 "first chance access violation for current stack trace", which vrfcore.dll routes to `Heaps`. `STATUS_INVALID_HANDLE` (0xC0000008) not raised by the verifier → stop 0x300 of `Handles`. `STATUS_VERIFIER_STOP` (0xC0000421) / breakpoint without debugger → `RtlReportException` (or `RtlUnhandledExceptionFilter`) then `NtTerminateProcess(-1, 0xC0000421)`.
- **TLS**: `TlsAlloc` returns `(index << 16) | 0xABBA` (`ScrambleTlsIndex`), records the caller; `TlsGetValue` / `TlsSetValue` / `TlsFree` check the scrambled form (stop 0x352); slots of an unloaded DLL → stop 0x350.
- **DirtyStacks**: each new thread (`CreateThread` → `AVrfpStandardThreadFunction`) and each thread pool callback fills up to 8 KB of unused stack with 0xBAD1BAD1.
- **DangerousAPIs**: `TerminateThread` → stop 0x100 (and 0x70D on a thread pool thread), `SetProcessWorkingSetSize(Ex)` with −1 → 0x105–0x108, `ExitProcess` with other threads → 0x102.
- **Leak**: 9 resource trackers per DLL (AVL tables keyed by the allocating DLL). At unload (`AVrfpCheckDllLeaks`, 0x1000A968) each remaining entry is a stop: trackers 0–2 → 0x900 (heap), 4 → 0x901 (handle), 5 → 0x902 (HKEY), 6 → 0x903 (virtual reservation), 7 → 0x905 (power notification), unless the DLL is the application itself (its name in the command line), in `ExcludeDlls` or in the static list.
- **Threadpool**: the thread pool callbacks are wrapped (`AVrfpTpWorkCallback`, `AVrfpTpTimerCallback`…) with a prolog and epilog that check priority, affinity, impersonation, transactions, loader lock, preferred languages, background priority, COM init balance, orphan windows and messages (stops 0x700–0x70C).
- **Locks / SRWLock**: every critical section is tracked in a splay tree (`AVrfpInsertCritSectInSplayTree`), SRW locks in an AVL table; freed memory, unloaded DLLs and exiting threads are checked for active locks. With `DeadLock` the lock order graph is analysed ("Potential deadlock detected! Type !avrf -dlck in the debugger").

### Verifier stops

Stops are sent with `vrfcore!VerifierStopMessageEx(layer, code, p1…p4)`. `VerifierStopMessage` (0x100063FC) routes old-style codes by range to the enabled layer: 0x100 DangerousAPIs, 0x200 Locks, 0x250 SRWLock, 0x300 Handles, 0x350 TLS, 0x600 Memory, 0x650 Exceptions, 0x700 Threadpool, 0x800 InputOutput, 0x900 Leak; others go to `RtlApplicationVerifierStop`.

| Codes | Layer | Messages (string resources, 10 per stop from 0xBB8) |
|-------|-------|------------------------------------------------------|
| 0x100–0x108 | DangerousAPIs | TerminateThread, potential stack overflow in low memory, ExitProcess with threads running, LoadLibrary / FreeLibrary during DllMain, `SetProcessWorkingSetSize(Ex)` with 0xFFFFFFFF |
| 0x200–0x215 | Locks | Exiting thread owns a critical section, unloading DLL / freeing heap / virtual memory / unmapping with an active critical section, double initialised, corrupted, invalid owner / recursion / lock count, over-released, not initialised, private to another DLL… |
| 0x250–0x257 | SRWLock | Not initialized, already initialized, mismatched acquire-release, recursive acquire, owned by an exiting thread, released by another thread, in freed memory, in an unloaded DLL |
| 0x300–0x305 | Handles | Invalid handle, invalid TLS index, invalid `WaitForMultipleObjects` parameters, NULL handle, waiting on a thread handle in DllMain, wrong object type (`AVrfpCheckObjectType`: Event, Thread, Process, Section, File…) |
| 0x350–0x352 | TLS | TLS index not freed by an unloaded DLL, corrupted verifier TLS structure, invalid TLS index |
| 0x600–0x61E | Memory | Bad `VirtualFree` / `VirtualAlloc` / map view, probing invalid / free / guard page / NULL memory (`IsBad*Ptr`), exceptions in DLL entry points, thread functions and thread pool callbacks, freeing inside the thread stack, executable heap / memory… |
| 0x650 | Exceptions | Execute access violation (first chance) |
| 0x700–0x70D | Threadpool | Priority / affinity changed, unprocessed messages, unclosed window, ExitThread / TerminateThread on a pool thread, impersonation, persistent thread function, dirty transaction, unbalanced CoInit, inconsistent timer, loader lock held, preferred language, background priority |
| 0x800–0x804 | InputOutput (not registered) | Stack unwound / corrupted or freed address with pending I/O, reused `OVERLAPPED`, `FILE_ATTRIBUTE_NOT_CONTENT_INDEXED` on `CreateFile` |
| 0x900–0x906 | Leak | Heap allocation, HANDLE, HKEY, virtual reservation, BSTR, power notification, COM allocation leaked |

The resources also hold the stop parameter descriptions and the layer / property strings (0x12C–0x1A0).
