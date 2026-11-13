## vrfcore.dll

Application Verifier core library ("AVRF 3.0", source `base\avrf\avrf30\vrfcore`): the layer registry and the shared run-time of every user-mode verifier check.  
`vrfcore.dll` is a native DLL (only `ntdll.dll` imports, 323 functions, full symbols). It has two uses. In a tool such as [AppVerif.exe](../applications/appverif.md), it keeps the list of the *layers* (tests) registered by the providers and writes their settings in the `Image File Execution Options` (IFEO) key of the target image. Each layer has a name, a GUID, properties and stop codes. In a verified process, the loader loads it from `VerifierDlls` as the first verifier provider (`DLL_PROCESS_VERIFIER`). It then reads the settings of each layer, hooks a few `ntdll` / `kernel32` functions, and offers the other providers verifier stops (debug break / log / exception), the log file `<image>.<n>.dat`, fault injection and a TLS slot.  
It contains three layers itself: `Core`, `Heaps` (page heap settings) and the descriptors of `COM` and `RPC`, which are registered by another provider. The other checks (`Handles`, `Locks`, `Leak`…) are in providers such as `vfbasics.dll` (next to it in the same folder, not analysed) and `vfgcleak.dll`, which import it. [AppVerif.exe](../applications/appverif.md) imports 14 of its exports.

Location on the phone: `C:\Windows\System32\vrfcore.dll` ? (extracted next to `AppVerif.exe` and `vfbasics.dll`).  

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll (loader) | `LdrLoadDll`, `LdrUnloadDll`, `LdrGetDllHandle`, `LdrGetProcedureAddress`, `LdrFindEntryForAddress`, `LdrEnumerateLoadedModules`, `LdrLockLoaderLock`, `LdrUnlockLoaderLock`, `LdrFindResource_U`, `LdrAccessResource`, `LdrDisableThreadCalloutsForDll`, `RtlImageNtHeader`, `RtlImageDirectoryEntryToData`, `RtlDllShutdownInProgress` |
| ntdll.dll (registry) | `NtOpenKey`, `NtCreateKey`, `NtQueryKey`, `NtDeleteKey`, `NtQueryValueKey`, `NtSetValueKey`, `NtDeleteValueKey` |
| ntdll.dll (files, memory, process) | `NtCreateFile`, `NtWriteFile`, `NtWaitForSingleObject`, `NtDelayExecution`, `NtClose`, `RtlDoesFileExists_U`, `RtlDosPathNameToNtPathName_U`, `RtlQueryEnvironmentVariable_U`, `NtAllocateVirtualMemory`, `NtFreeVirtualMemory`, `NtProtectVirtualMemory`, `NtQueryVirtualMemory`, `NtReadVirtualMemory`, `NtQueryInformationProcess`, `NtResumeThread`, `NtTerminateProcess`, `NtQuerySystemTime`, `NtQueryPerformanceCounter` |
| ntdll.dll (verifier, debug) | `RtlApplicationVerifierStop`, `RtlRaiseException`, `RtlCaptureStackBackTrace`, `RtlRandom`, `DbgPrint`, `DbgPrintEx`, `RtlAcquirePebLock`, `RtlReleasePebLock`, `RtlFindClearBitsAndSet` |
| ntdll.dll (Rtl, CRT) | `RtlAllocateHeap`, `RtlFreeHeap`, critical sections, Unicode/ANSI strings, `RtlCompareMemory`, `_vsnwprintf`, `_vsnprintf`, `_wcsicmp`, `_wcsnicmp`, `_stricmp`, `wcslen`, `wcsrchr`, `wcsstr`, `wcstoul`, `memset`, `memcpy`, `memmove`, `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind`, `RtlUnhandledExceptionFilter`, `__C_specific_handler` |

The `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind` / `RtlUnhandledExceptionFilter` / `__C_specific_handler` imports are the `/GS` cookie and SEH code. No kernel32 or api-ms-win import: kernel32 functions are found at run time (below).

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `verifier.dll` | Found in the loader list (`VfCoreModuleInfo`, 0x10004A20), `LdrGetDllHandle`, `LdrLoadDll` | The system verifier provider. vrfcore.dll scans its image for its `RTL_VERIFIER_PROVIDER_DESCRIPTOR` (see [DLL_PROCESS_VERIFIER](#dll_process_verifier)), redirects its stop functions (`VerifierRedirectStopFunctions`, else `VerifierStopMessage` patched), hooks its `VerifierGetPropertyValueByName`, and calls its `VerifierIsAddressInAnyPageHeap` in `VerifierGetInfoForException` |
| `kernel32.dll` | `LdrGetDllHandle` + `LdrGetProcedureAddress` (`ViInitDelayLoad`, 0x10008744) | `TlsAlloc`, `TlsFree`, `TlsGetValue`, `TlsSetValue` (TLS slots of the layers, `VerifierTlsGetValue` / `VerifierTlsSetValue`) |
| `ntdll.dll` | `LdrLoadDll` + `LdrGetProcedureAddress("LdrGetProcedureAddressForCaller")` | Present → the `LdrGetProcedureAddress*` and `GetProcAddress` hooks aren't installed (`AVrfAPILookupCallback` is used instead) |
| `SHSMP.DLL`, `smartcpu.dll`, `TTTraceWriter.dll`, `vfbasics.dll` | Names compared in `VfCoreDllLoadCallback` (0x100088C8) | SmartHeap → stop 0x100B "SmartHeap (shsmp.dll) is not supported" ; smartcpu / TTTraceWriter (Time Travel tracing) → their calls get the original exports; `vfbasics.dll` loaded → the heap tracker of vrfcore.dll is destroyed |
| Provider DLLs (`VerifierDlls`) | Loaded by `ntdll` | Each provider calls `VerifierRegisterLayer` from its `DllMain`; its file name (loader `BaseDllName`) is what [VerifierEnableLayer](#verifierenablelayer-0x10006bcc) adds to `VerifierDlls` |
| `<log directory>\<image>.<n>.dat` | `NtCreateFile` / `NtWriteFile` | Verifier log of the process, see [Log file](#log-file) |
| `<log directory>` = `%VERIFIER_LOG_PATH%`, else `%USERPROFILE%`, else `%TEMP%`, + `\AppVerifierLogs` | `NtCreateFile(FILE_CREATE, FILE_DIRECTORY_FILE)` | Created if missing; `ProtectedProcessLogPath` of the global settings when it can't be created |

### Exports

All the `Verifier*` layer functions return an `_AVRF_STATUS` (0 = success, 9 = invalid parameter, 15 = layer not registered, 18 = no image name, 22 = no memory, 23 = value not found, 24 = wrong value type…), unless noted. `image` NULL = current process (`PEB.Ldr` first entry `BaseDllName`).

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 31 | `VerifierRegisterLayer` | 0x10006674 | `HMODULE provider, AVRF_LAYER_DESCRIPTOR *layer` (= `ViRegisterLayer(…, 1)`: with a TLS slot) |
| 32 | `VerifierRegisterLayerEx` | 0x10006684 | `HMODULE, AVRF_LAYER_DESCRIPTOR *, DWORD flags` (bit 0: allocate a TLS slot) |
| 44 | `VerifierUnregisterLayer` | 0x10006694 | `HMODULE, AVRF_LAYER_DESCRIPTOR *` |
| 29 | `VerifierQueryRegisteredLayers` | 0x10006A6C | `AVRF_LAYER_DESCRIPTOR **array` (NULL = count only), `DWORD *count` (in/out; 35 if too small) |
| 14 | `VerifierEnableLayer` | 0x10006BCC | `WCHAR *image, WCHAR *layerName`, see [below](#verifierenablelayer-0x10006bcc) |
| 10 | `VerifierDisableLayer` | 0x10006FFC | `WCHAR *image, WCHAR *layerName`, see [below](#verifierdisablelayer-0x10006ffc) |
| 11 | `VerifierDisableVerifier` | 0x100073E0 | `WCHAR *image, BOOL deleteImageKey`, see [below](#verifierdisableverifier-0x100073e0) |
| 21 | `VerifierIsLayerEnabled` | 0x10003F50 | `WCHAR *image, AVRF_LAYER_DESCRIPTOR *, BOOL *enabled`: with an image, enabled = the layer key exists; without, the state read at registration (+0x64) |
| 23 | `VerifierOpenLayerProperties` | 0x10003B34 | `WCHAR *image, AVRF_LAYER_DESCRIPTOR *layer, HANDLE *key`: opens the [layer key](#registry) (`KEY_READ`); `layer` = 1 opens `IFEO\<image>` itself |
| 7 | `VerifierCreateLayerProperties` | 0x10003B94 | Same, created if missing (`NtCreateKey`, access 0xC0010000 = `GENERIC_READ \| GENERIC_WRITE \| DELETE`) |
| 5 | `VerifierCloseLayerProperties` | 0x10003BF4 | `HANDLE key` (`NtClose`) |
| 28 | `VerifierQueryLayerProperty` | 0x10003D14 | `HANDLE key, AVRF_PROPERTY_DESCRIPTOR *` ([structure](#avrf_property_descriptor)) |
| 38 | `VerifierSetLayerProperty` | 0x10004020 | `HANDLE key, AVRF_PROPERTY_DESCRIPTOR *` |
| 27 | `VerifierQueryLayerProperties` | 0x10003C10 | `HANDLE key, AVRF_LAYER_DESCRIPTOR *`: queries every property of the layer into its value buffers |
| 25 | `VerifierQueryLayerBreak` | 0x10003D9C | `HANDLE key, AVRF_BREAK_DESCRIPTOR *` (reads `Stop-%08X-ErrorReport` / `-Severity` / `-Flavor` into +4 / +8 / +0xC) |
| 26 | `VerifierQueryLayerBreaks` | 0x10003D68 | `HANDLE key, AVRF_LAYER_DESCRIPTOR *`: all the stops of the layer |
| 37 | `VerifierSetLayerBreak` | 0x10003E58 | `HANDLE key, AVRF_BREAK_DESCRIPTOR *`: writes the three values (REG_DWORD); -1 = leave unchanged, -2 = delete the value |
| 16 | `VerifierGetLoggingDirectory` | 0x10004090 | `WCHAR *buffer, DWORD cch`: [log directory](#log-file), created if missing (42 on failure; no `ProtectedProcessLogPath` fallback here) |
| 24 | `VerifierQueryGlobalProperties` | 0x100043B4 | `DWORD *value, DWORD size` (must be 4): returns `Core.MinimumMemoryOverhead` |
| 40 | `VerifierStopMessageEx` | 0x10003520 | `AVRF_LAYER_DESCRIPTOR *layer, DWORD stopCode, ULONG_PTR p1, p2, p3, p4, ?`: see [Verifier stops](#verifier-stops) |
| 6 | `VerifierConfigureStopOptions` | 0x10004364 | `DWORD options`: bit 0 required (else `ERROR_INVALID_PARAMETER`, returns FALSE): raise an exception on stop; 0x10000 = "handle" it (`VerifierHandleVerifierStopException`); 0x20000 = no `DbgPrint` of the stop |
| 18 | `VerifierHandleVerifierStopException` | 0x100043A0 | none, returns the 0x10000 option |
| 20 | `VerifierIsInsideVerifierStop` | 0x10004344 | none: flag 2 of the thread verifier TLS data |
| 19 | `VerifierIsDllEntryActive` | 0x1000431C | none: `PEB.NtGlobalFlag & 0x100` and the thread is inside a hooked DLL entry point |
| 3 | `VerifierAreStaticDllsInitialized` | 0x100040AC | none: last provider initialised and all its delay-loaded DLLs initialised |
| 2 | `VerifierGetInfoForException` | 0x10004570 | `HANDLE process, ?, EXCEPTION_RECORD *, BYTE *isVerifier, DWORD *kind` (debugger side: reads the target memory; access violation in a page heap → kind 2) |
| 15 | `VerifierGetAppCallerAddress` | 0x100064F0 | `void *address`: if inside a provider, first return address of the stack outside all the providers |
| 22 | `VerifierLdrGetProcedureAddress` | 0x10004304 | `LdrGetProcedureAddress` arguments, returns the last hook of the chain (30 on error) |
| 4 | `VerifierChainDuplicateHooks` | 0x10004198 | `RTL_VERIFIER_PROVIDER_DESCRIPTOR *`: when several providers hook the same `dll!function`, links each thunk "original" to the previous provider's thunk |
| 1 | `AVrfAPILookupCallback` | 0x1000332C | `module, ?, address, RTL_VERIFIER_REDIRECT_TYPE` (< 3): callback for the loader's caller-aware lookup, returns the most recent hook of `address` (none for smartcpu / TTTraceWriter) |
| 17 | `VerifierGetRecursionTlsSlot` | 0x10004124 | none, TLS index |
| 42 / 43 | `VerifierTlsGetValue` / `VerifierTlsSetValue` | 0x10008874 / 0x1000889C | kernel32 `TlsGetValue` / `TlsSetValue` |
| 30 | `VerifierRegisterFaultInjectProvider` | 0x10009A54 | `DWORD classCount, DWORD *firstClass`: reserves fault classes (64 in all, class 0 unused) |
| 39 | `VerifierShouldFaultInject` | 0x10009ABC | `DWORD class, void *caller`: TRUE if the call must fail, see [Fault injection](#fault-injection) |
| 36 | `VerifierSetFaultInjectionProbability` | 0x10009BF4 | `DWORD class, DWORD probability` (out of 1 000 000) |
| 41 | `VerifierSuspendFaultInjection` | 0x10009C80 | `DWORD ms` (≤ 600 000) |
| 13 / 9 | `VerifierEnable/DisableFaultInjectionTargetRange` | 0x10009CE8 / 0x10009DB4 | `DWORD class, start, end` (128 ranges) |
| 12 / 8 | `VerifierEnable/DisableFaultInjectionExclusionRange` | 0x10009E60 / 0x10009F2C | `DWORD class, start, end` (128 ranges) |
| 34 | `VerifierResetFaultInjectionAddressRanges` | 0x10009FD8 | `DWORD class` |
| 35 | `VerifierSetAPIClassName` | 0x1000A0AC | `DWORD class, WCHAR *name` (31 characters) |
| 33 | `VerifierRegisterProvider` | 0x10009000 | `HMODULE, RTL_VERIFIER_PROVIDER_DESCRIPTOR *`: adds a provider (range of its image, delay-loaded DLLs) |

`VerifierSetFaultInjectionProbability`, `Set/Enable/Disable/Reset…Range` and `VerifierSetAPIClassName` do nothing unless `PEB.NtGlobalFlag` has `FLG_APPLICATION_VERIFIER` (0x100), i.e. in a verified process.

### Startup

`DllMain` (0x10002C48) calls `_DllMainCRTStartupForGS2` (cookie) on reason 4, then `_DllMain` (0x10002C74):

- `DLL_PROCESS_ATTACH` (once): saves the module base and size, loads the [essential strings](#strings) (`VfCoreLoadEssentialStrings`), initialises the layer list. Then, in a verified process (after `DLL_PROCESS_VERIFIER`): `VfCoreRedirectOldStopFunctions`, creates the [log file](#log-file) and logs every module already loaded (`LdrEnumerateLoadedModules`). In a tool: initialises the stop list only. Finally registers the `Core` layer (`ViRegisterLayer(…, 0)`) and the base layers (`VfRegisterBaseLayers`: `Heaps`). If `Core.MinimumMemoryOverhead` is set, the heap tracker is destroyed.
- `DLL_THREAD_ATTACH` / `DETACH`: per-thread verifier TLS data (`AvrfpThreadAttach` / `Detach`), in a verified process only.
- `DLL_PROCESS_DETACH`: unregisters `Core` and `Heaps`, frees the stop list.

Failures are recorded in a ring of 4 `PointOfFailure{File,Line,Function,Error}` entries (`base\avrf\avrf30\vrfcore\vrfcore.cpp`, line).

### DLL_PROCESS_VERIFIER

Reason 4, sent by the loader to the providers listed in `VerifierDlls`; the third argument is where the provider stores its `RTL_VERIFIER_PROVIDER_DESCRIPTOR *` (NULL → failure). `_DllMain`:

1. Sets `VfCoreLoadedAsProvider`, saves `PEB.OSBuildNumber`.
2. Finds `verifier.dll` in the loader list (`VfCoreModuleInfo`). `VfCoreGetProviderDescriptor4VerifierDotDll` (0x100033EC) scans its image (`NtQueryVirtualMemory`, writable pages) for a pointer to its provider descriptor: a structure of length 0x2C (0x1C on build 2600) whose first DLL name starts with `ntdll.dll`. Stores it (`AVrfpProvider`) and clears its first DLL descriptor (16 bytes), so the ntdll hooks of verifier.dll aren't installed ?.
3. If `ntdll!LdrGetProcedureAddressForCaller` exists, ends the ntdll thunk list before `LdrGetProcedureAddress` and the kernel32 list before `GetProcAddress` (the lookups go through `AVrfAPILookupCallback` instead).
4. Returns `&VfCoreProvider` (Length 0x2C, 0x1C on XP) and calls `VfCoreProviderInitialize`, `VfCoreInitializeVerifierStops`, `VfCoreDllLoadCallback` for itself, `VerifierRegisterProvider`, `AVrfCreateTrackers` (heap tracker, 0x2000 entries), `AVrfpAllocateVerifierTlsSlot` (a free bit of `PEB.TlsBitmap`), `AVrfpInitializeFaultInjectionSupport`.

On failure, with `OSBuildNumber` ≤ 3790 it prints "AVRF: Verifier Provider failed to initialized itself for DLL_PROCESS_VERIFIER. Process will be terminated." and calls `NtTerminateProcess(-1, STATUS_UNSUCCESSFUL)`; otherwise it returns FALSE.

`VfCoreProvider` (`RTL_VERIFIER_PROVIDER_DESCRIPTOR`, 0x1000C0F8):

| Offset | Size | Value |
|--------|------|-------|
| 0x00 | 4 | 0x2C, Length |
| 0x04 | 4 | DLL descriptors (below) |
| 0x08 | 4 | `VfCoreDllLoadCallback` (0x100088C8) |
| 0x0C | 4 | `VfCoreDllUnloadCallback` (0x10008AC8) |
| 0x10–0x24 | 24 | Filled by ntdll (image name, verifier flags, debug flags at +0x18 – bit 0x10000 = entry point traces –, stack trace and page heap functions) |
| 0x28 | 4 | `VfCoreHeapFreeCallback` (0x10002C3C, does nothing) |

Hooks (thunks `{name, original, new}`):

| DLL | Function | Replacement | What it does |
|-----|----------|-------------|--------------|
| ntdll.dll | `RtlAllocateHeap`, `RtlReAllocateHeap`, `RtlFreeHeap` | `VfCoreRtl*Heap` (0x1000A114…) | Calls the original, then records the operation (1 alloc, 2 realloc, 3 free; address, size, heap, thread, 32-frame stack) in a circular tracker of 0x2000 entries of 148 bytes |
| ntdll.dll | `LdrGetProcedureAddress`, `LdrGetProcedureAddressEx` | `VfCoreLdrGetProcedureAddress(Ex)` (0x10003360, 0x100033A4) | Replace the result by the most recent provider hook of that function |
| kernel32.dll | `CreateProcessW`, `CreateProcessA`, `CreateProcessInternalW`, `CreateProcessInternalA` | `VfCoreCreateProcess*` (0x100084E4…) | With `Core.Propagate`: create the process suspended (`CREATE_SUSPENDED` added), [propagate the settings](#propagation), then `NtResumeThread` unless the caller asked for suspended |
| kernel32.dll | `GetProcAddress` | `VfCoreGetProcAddress` (0x10009778) | Calls the original |
| verifier.dll | `VerifierGetPropertyValueByName` | `VfCoreGetPropertyValueByName` (0x10008288) | Calls the original; on `STATUS_NOT_FOUND`, looks in the properties of vrfcore's `COM` layer |

`VfCoreDllLoadCallback` also replaces the entry point of every loaded DLL (except vrfcore.dll) with `VfCoreStandardDllEntryPointRoutine` (0x10008B98), which runs it under an exception filter (`VerifierIsDllEntryActive`), and with `LoggingWithLocksHeld` logs the load (and the unload) in the log file.

### Layer descriptor

`AVRF_LAYER_DESCRIPTOR` given to `VerifierRegisterLayer` (as read by vrfcore.dll):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `&VfCoreProvider` for `Core`, else 0 ? |
| 0x04 | 4 | GUID string, e.g. `{E5DCDFAA-3B35-46A8-B370-9D3575A68E53}` (converted to binary at +0x50) |
| 0x08 | 4 | Layer name (`Core`, `Heaps`…) |
| 0x0C | 4 | 1 (version ?) |
| 0x10 | 4 | Stop table (`AVRF_BREAK_DESCRIPTOR[]`, 76-byte entries, ends with stop code 0) |
| 0x14 | 4 | Property table (`AVRF_PROPERTY_DESCRIPTOR[]`, 24-byte entries, ends with type 0) |
| 0x18 | 4 | `L"Basics"` for Heaps/COM/RPC (group ?) |
| 0x1C | 4 | Description: string resource ID of the provider, replaced by the string (0x197 "Checks the heap errors…") |
| 0x24 | 4 | Flags: bit 0 = the layer is propagated to child processes and cleared by `AutoClr` |
| 0x28 | 4 | 1 (Heaps), 8 (RPC), 0x10 (COM): ? |
| 0x3C | 8 | `LIST_ENTRY` in the registered layers |
| 0x44 | 8 | Lowest and highest stop code (checked for overlap with the other layers: stop 0x1004) |
| 0x4C | 4 | File name of the provider DLL (loader `BaseDllName`) |
| 0x50 | 16 | GUID |
| 0x60 | 4 | TLS index, or -1 |
| 0x64 | 4 | Enabled for the current process (the layer key existed at registration) |

At registration, `ViRegisterLayer` (0x10006540) loads the strings of the stops and properties from the provider's string table (`ResourceString`, `LdrFindResource_U`), checks the stop range, links the layer, opens its key for the current image and, if it exists, reads the stop settings and **all the properties into the provider's variables** (`VerifierQueryLayerBreaks` + `VerifierQueryLayerProperties`). That's how the settings written by [AppVerif.exe](../applications/appverif.md) reach the checks. With `Core.AutoClr` and flag 1 it then disables the layer for this image.

### AVRF_PROPERTY_DESCRIPTOR

Its first 16 bytes are the structure [AppVerif.exe passes](../applications/appverif.md#layer-property-parameter).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Type: 1 REG_SZ, 3 REG_BINARY, 4 REG_DWORD, 7 REG_MULTI_SZ, 11 REG_QWORD, 0x100 = boolean (stored as REG_DWORD), 0x101 = delete the value (`NtDeleteValueKey`) |
| 0x04 | 4 | Name (registry value name); in the descriptor tables a string resource ID, replaced at registration |
| 0x08 | 4 | Value buffer |
| 0x0C | 4 | Size of the buffer |
| 0x10 | 4 | Description (resource ID → string) |
| 0x14 | 4 | Layer-private (Heaps: {registry value, `PageHeapFlags` bit, case}) |

A query reads the value (`NtQueryValueKey`, `KeyValuePartialInformation`) and copies it only if its registry type matches (24 otherwise; a REG_DWORD fits types 4 and 0x100).

### Built-in layers

| Layer | GUID | Stops | Properties (default) |
|-------|------|-------|----------------------|
| `Core` | `{E5DCDFAA-3B35-46A8-B370-9D3575A68E53}` | 0x1000–0x100B: misuse of the layer API (0x1000 bad `VerifierRegisterLayer` parameter, 0x1003 unknown stop code, 0x1004 stop code used by another layer, 0x1005 more than 128 layers, 0x100B SmartHeap…) | `Propagate` (0) "Propagate verifier settings from parent process to child process", `AutoClr` (0) "After specified image starts to run, the verified image will clear the settings for itself", `AutoDisableStop` (1) "complain once for the same issue", `LoggingWithLocksHeld` (1) "dll load/unload event will be logged", `ExceptionOnStop` (0) "exception will be raised instead of debug break", `MinimumMemoryOverhead` (0); all booleans |
| `Heaps` | `{4D056CEB-D8E3-4b85-B148-B543D56D9BDE}` | 1–0x14 (heap corruption, double free, wrong heap, AV…) | see [Heaps](#heaps-properties) |
| `COM` | `{91067D4F-67E6-4768-BEA4-2565236FDCBE}` | 0x400–0x423 | `ForceDllUnload` (1), `UnloadPeriodMs` (1000), `SecuritySettings` (0), `EventRemoveCheck` (1), `AgressiveMTATesting` (0) |
| `RPC` | `{7CF16601-5646-4ecf-ACAF-D8B5872A0291}` | 0x500 (call without mutual authentication) | none |

Only `Core` and `Heaps` are registered by vrfcore.dll; the `COM` and `RPC` descriptors are only used to route old-style stops (codes 0x400–0x4FF and 0x500–0x5FF) and by the `VerifierGetPropertyValueByName` hook. The provider that registers them isn't known (`vfbasics.dll` ?).

#### Heaps properties

The Heaps properties aren't stored in the layer key but as values of `IFEO\<image>` read by the ntdll page heap (`VfHeapSetLayerProperty`, 0x10007F1C). Booleans set or clear a bit of `PageHeapFlags` (REG_SZ `0x%x`); every change rewrites `PageHeapFlags` and deletes the range values whose bit is clear (`VfResetHeapRegistryValues`).

| Property | Type | Storage |
|----------|------|---------|
| `Full` (default TRUE) | boolean | `PageHeapFlags` bit 0x1; also `VerifierFlags` bit 0x1 (full) or 0x8000 (light; `PageHeapFlags &= 0x26802`) |
| `Traces` (default TRUE) | boolean | bit 0x2 |
| `Backward` / `Unalign` | boolean | bits 0x10 / 0x20 |
| `Size` + `SizeStart` / `SizeEnd` | boolean + DWORD | bit 0x80; `PageHeapSizeRangeStart` / `End` |
| `Addr` + `AddrStart` / `AddrEnd` | boolean + DWORD | bit 0x100; `PageHeapDllRangeStart` / `End` |
| `Random` + `RandRate` | boolean + DWORD (0–100) | bit 0x200; `PageHeapRandomProbability` |
| `Dlls` | REG_SZ | bit 0x400 (+ 0x1); `PageHeapTargetDlls` |
| `Faults` + `FaultRate` / `TimeOut` | boolean + DWORD | bit 0x800; `PageHeapFaultProbability` (1–10000), `PageHeapFaultTimeOut` (ms) |
| `Protect` / `NoLock` / `UseLFHGuardPages` | boolean | bits 0x1000 / 0x4000 / 0x20000 |

### Registry

All under `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\` (`\Registry\Machine\…`, `NtOpenKey` / `NtCreateKey`):

| Key | Value | Written by | Meaning |
|-----|-------|------------|---------|
| `<image>` | `GlobalFlag` (REG_DWORD, or REG_SZ `0x%X` if it was a string) | `VerifierEnableLayer` (bit 0x100 set), `VerifierDisableVerifier` (cleared, value deleted at 0) | `FLG_APPLICATION_VERIFIER`: the loader loads the verifier for this image |
| `<image>` | `VerifierFlags` (REG_DWORD) | Enable: 0x80000000 + the bit of the layer; Disable: bit cleared | Bits per layer name: `Heaps` 0x1, `Locks` 0x40002, `Handles` 0x4, `Stacks` 0x8, `LowRes` 0x10, `TLS` 0x20, `DirtyStacks` 0x40, `RPC` 0x80, `COM` 0x100, `DangerousAPIs` 0x200, `Race` 0x400, `DeadLock` 0x800, `Exceptions` 0x1000, `Memory` 0x2000, `Leak` 0x200000, `Threadpool` 0x400000, `InputOutput` 0x800000, `SRWLock` 0x1000000 (`ViCoreLayerBitArray`) |
| `<image>` | `VerifierDlls` (REG_SZ, space separated) | Enable / Disable | Providers to load. The `Core` DLL (vrfcore.dll) is put first; layers with a TLS slot append their DLL at the end, the others after the first name. A DLL is removed when no other enabled layer belongs to it |
| `<image>` | `PageHeapFlags`, `PageHeap*` | `Heaps` properties | Page heap |
| `<image>\<Layer>-<GUID>` (e.g. `Core-{E5DCDFAA-3B35-46A8-B370-9D3575A68E53}`) | properties of the layer | `VerifierCreateLayerProperties` + `VerifierSetLayerProperty` | The key's existence = layer enabled |
| same | `Stop-%08X-ErrorReport`, `Stop-%08X-Severity`, `Stop-%08X-Flavor` (REG_DWORD) | `VerifierSetLayerBreak` | Per-stop settings (`-configure` of AppVerif.exe) |
| `{ApplicationVerifierGlobalSettings}` | `LogToFile` (REG_DWORD), `ProtectedProcessLogPath` (REG_SZ), `VerifierProviders` (REG_SZ, used by AppVerif.exe) | [AppVerif.exe](../applications/appverif.md) | Global settings: an IFEO "image" key, opened with `layer` = 1. `LogToFile` = 0 disables the log file (default 1) |

### VerifierEnableLayer (0x10006BCC)

1. Finds the layer by name (`_wcsicmp`) in the registered list (15 if absent). If it isn't `Core`, enables `Core` first (37 on failure).
2. Opens/creates `IFEO\<image>`; reads `GlobalFlag` (DWORD, or REG_SZ parsed in hex), `VerifierFlags`, `VerifierDlls`.
3. Adds the provider DLL to `VerifierDlls` if missing (see the [table](#registry)) and writes it.
4. Writes `GlobalFlag | 0x100` in its original type, `VerifierFlags | 0x80000000 | bit(layer)`.
5. Creates the layer key `<Layer>-<GUID>`.

### VerifierDisableLayer (0x10006FFC)

Disabling `Core` itself does nothing (returns 0: `Core` is only removed by `VerifierDisableVerifier`). Otherwise: if `GlobalFlag` has 0x100, removes the provider DLL from `VerifierDlls` (when no other layer of that DLL is enabled), clears the layer bit of `VerifierFlags` (for `Heaps` 0x8001, and deletes the page heap values), deletes the layer key (`NtDeleteKey`). When `VerifierDlls` is left empty or with only vrfcore.dll and `VerifierFlags` is 0 or 0x80000000, calls `VerifierDisableVerifier(image, FALSE)`.

### VerifierDisableVerifier (0x100073E0)

With `deleteImageKey`: deletes the whole `IFEO\<image>` key. Otherwise deletes the `Core` layer key, `VerifierFlags`, `VerifierDlls`, and clears bit 0x100 of `GlobalFlag` (value deleted when 0).

### Propagation

`VfCorePropagateSettings` (0x1000848C), called by the `CreateProcess*` hooks with `Core.Propagate` set: gets the child image (`NtQueryInformationProcess(ProcessImageFileName)`, file name part). If `Core` isn't already enabled for it, enables every layer enabled in the parent with flag 1, then sets `Propagate` = 1 and `AutoClr` = 1 in the child's `Core` key. The child therefore clears these settings for itself at start (`AutoClr`).

### Verifier stops

`VerifierStopMessageEx(layer, code, p1…p4, ?)` (0x10003520), under `AVrfpStopDataLock`:

1. Checks the layer and the stop code (stops 0x1002 / 0x1003 otherwise); returns at once if the process is being terminated.
2. Formats the message with the layer's strings (resource 0x41/0x42: `VERIFIER STOP %p: pid 0x%X: <message>`, the four parameters with their descriptions, then "This verifier stop is (not) continuable…").
3. If the stop was already reported (`AutoDisableStop`: same layer, code and parameters, list `VerifierStops`), skips it.
4. If the stop's `ErrorReport` has bit 0x80 and the log file exists, writes a [stop record](#log-file) (bit 0x100: with a stack trace of up to 64 frames).
5. Prints the message (`DbgPrintEx`, unless option 0x20000), then either raises `STATUS_VERIFIER_STOP` (0xC0000421, parameters `'AVrf'` 0x66725641, 0, pointer to the stop data) with `ExceptionOnStop` / `VerifierConfigureStopOptions`, or breaks into the debugger. A non-continuable stop terminates the process (`NtTerminateProcess(-1, 0xC0000421)`).

Old-style stops (`RtlApplicationVerifierStop` on builds 2600/3790, `verifier.dll!VerifierStopMessage` patched with a jump to `VfCoreRedirectedStopMessage`, 0x100079B0) are routed by code: 1–0x1FF → `Heaps`, 0x400–0x4FF → `COM`, 0x500–0x5FF → `RPC`; others are printed and break if a debugger is present (`PEB.BeingDebugged` or `KUSER_SHARED_DATA+0x2D4`).

Stop entry (`AVRF_BREAK_DESCRIPTOR`, 76 bytes): +0 stop code, +4 `ErrorReport` (default 0x1A1), +8 `Severity` (0x3F), +0xC `Flavor` (2, or 0 for COM), then resource IDs of the message (+0x14) and of the parameter descriptions (+0x1C, +0x24, +0x2C, +0x34, +0x3C, +0x44), each followed by the loaded string, +0x48 back-pointer to the layer.

### Log file

Created at `DLL_PROCESS_ATTACH` in a verified process, unless `LogToFile` = 0. Directory: `%VERIFIER_LOG_PATH%`, `%USERPROFILE%` or `%TEMP%` (first defined) + `\AppVerifierLogs`, created if missing (`NtCreateFile`, access 0x100181, `FILE_ATTRIBUTE_DIRECTORY`, `FILE_CREATE`, options 0x204021); if that fails, `ProtectedProcessLogPath` of the global settings. File: `<dir>\<image>.<n>.dat`, first `n` from 0 that doesn't exist (`FILE_CREATE`, retried on `STATUS_OBJECT_NAME_COLLISION`). These are the files that [AppVerif.exe](../applications/appverif.md#stamp-record) lists, deletes and stamps.

Each record is appended by `VfCoreWriteLogEntry` (0x10005630): `NtCreateFile(FILE_APPEND_DATA | SYNCHRONIZE, share 0, FILE_OPEN_IF)`, retried 5 times one second apart on `STATUS_SHARING_VIOLATION`, `NtWriteFile`, close.

| Record | Size | Layout |
|--------|------|--------|
| Header | 0x18 | +0 `'Vrf '` (0x20667256), +4 2 (version), +8 process ID, +0x10 `NtQuerySystemTime` |
| Module load / unload | 0x21C | +0 0x21C, +4 0, +8 base, +0xC size of image, +0x10 1 = load (or already loaded at start), 2 = unload, +0x14 `UNICODE_STRING` (max 0x200), +0x1C full DLL path |
| Verifier stop | ? | +4 3, +8 stop code, +0xC layer GUID (16), +0x1C severity, +0x20 ErrorReport, +0x24 frame count, +0x28 stack (64 pointers), +0x128 time, +0x130 p1…p4 (8 bytes each), then the message |
| Stamp | | type 4, written by [AppVerif.exe](../applications/appverif.md#stamp-record) |

### Fault injection

Classes are reserved by the providers (`VerifierRegisterFaultInjectProvider`, ≤ 64). `VerifierShouldFaultInject(class, caller)` returns TRUE when: injection is ready, the class has a probability, the suspension delay is over, `caller` isn't in an exclusion range and is in a target range of the class, and `RtlRandom() % 1 000 000` < probability. With the "break" setting of the class it prints "AVRF: fault injecting call made from %p" and breaks; each injected fault is recorded (32-frame stack, ring of 128). The `LowRes` properties written by `AppVerif.exe -verify -faults` (`HEAP_ALLOC`, `OLE_ALLOC`, `TimeOut`) are read by the provider of that layer, not here.

### Strings

String resources of vrfcore.dll: 0x3C–0x42 stop texts (loaded at attach and converted to ANSI), 0x46–0x49 and 0x50–0x55 `Core` property names / descriptions, 0x64–0x77 and 0xC8–0xDB `Heaps` properties, 0x191 / 0x192 / 0x197 RPC / COM / Heaps descriptions, 0x384–0x38D COM properties, 0x3E8+ (10 per stop) stop messages.
