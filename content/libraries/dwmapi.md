## DWMAPI.DLL

The Desktop Window Manager API of Windows Phone 8.1: a stub version of the desktop `dwmapi.dll`, kept so that code written for the desktop links and runs.  
`DWMAPI.DLL` is tiny (27 functions, 8 of them non-CRT). It holds no state and talks to no compositor: every export returns a constant, apart from the two private security descriptor functions. Composition is always reported as enabled, `DwmSetWindowAttribute` and `DwmTetherContact` succeed without doing anything, and the other exports return `E_NOTIMPL`. The only real code builds the security descriptor of the compositor surface object, read from the SecurityManager store of [SecRuntime.dll](./secruntime.md#querytransientobjectsecuritydescriptor-0x10003c20) (loaded at run time) or, if that DLL can't be loaded, from a built-in SDDL string.  
Its users weren't identified; the real compositor is in the sibling binaries [DWMCORE.DLL](./dwmcore.md) and `DWMMOBILE.DLL` (extracted with it, not analysed). DWMCORE.DLL loads it at run time only for `DwmIsCompositionEnabled` (and falls back to its own stub); it doesn't call `DwmpAllocateSecurityDescriptor`, so the caller of that one may be `DWMMOBILE.DLL`.

Location on the phone: `C:\Windows\System32\DWMAPI.DLL` ?  

### Imports

| DLL | Functions |
|-----|-----------|
| api-ms-win-core-libraryloader-l1-2-0.dll | `LoadLibraryExW`, `GetProcAddress`, `FreeLibrary` |
| api-ms-win-core-util-l1-1-0.dll | `EncodePointer`, `DecodePointer` |
| api-ms-win-security-sddl-l1-1-0.dll | `ConvertStringSecurityDescriptorToSecurityDescriptorW` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalFree` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `TerminateProcess` |
| ntdll.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `_initterm`, `_amsg_exit`, `__C_specific_handler`, `_XcptFilter` |

The msvcrt, ntdll, synch, processthreads imports and `SetUnhandledExceptionFilter` / `UnhandledExceptionFilter` are the Visual C++ DLL CRT startup and `/GS` security cookie code.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [SecRuntime.dll](./secruntime.md) | `LoadLibraryExW(L"SecRuntime.dll", NULL, 0)`, `GetProcAddress` of `QueryTransientObjectSecurityDescriptor` and `FreeTransientObjectSecurityDescriptor` ([TryLoadSecRuntime](#tryloadsecruntime-0x100012b4)) | Security descriptor of the compositor surface object |

No process or COM server is started and no file is opened.

### Exports

| Ordinal | Name | Address | Parameters | Result |
|---------|------|---------|------------|--------|
| 100 | `DwmpDxGetWindowSharedSurface` | 0x1000125C | ? (at least 4) | `E_NOTIMPL` (0x80004001) |
| 101 | `DwmpDxUpdateWindowSharedSurface` | 0x10001274 | ? | `E_NOTIMPL` |
| 102 | `DwmEnableMMCSS` | 0x10001274 | `BOOL fEnableMMCSS` | `E_NOTIMPL` |
| 103 | `DwmGetCompositionTimingInfo` | 0x10001274 | `HWND hwnd, DWM_TIMING_INFO *pTimingInfo` | `E_NOTIMPL` |
| 104 | `DwmIsCompositionEnabled` | 0x10001284 | `BOOL *pfEnabled` | `*pfEnabled` = TRUE, `S_OK` |
| 105 | `DwmRenderGesture` | 0x10001274 | `GESTURE_TYPE gt, UINT cContacts, const DWORD *pdwPointerID, const POINT *pPoints` | `E_NOTIMPL` |
| 106 | `DwmSetWindowAttribute` | 0x10001294 | `HWND hwnd, DWORD dwAttribute, LPCVOID pvAttribute, DWORD cbAttribute` | `S_OK`, nothing done |
| 107 | `DwmShowContact` | 0x10001274 | `DWORD dwPointerID, DWM_SHOWCONTACT eShowContact` | `E_NOTIMPL` |
| 108 | `DwmTetherContact` | 0x100012A0 | `DWORD dwPointerID, BOOL fEnable, POINT ptTether` | `S_OK`, nothing done |
| 128 | `DwmpDxgiIsThreadDesktopComposited` | 0x10001284 | `BOOL *` ? | `*arg` = TRUE, `S_OK` (same code as `DwmIsCompositionEnabled`) |
| 135 | `DwmpRenderFlick` | 0x1000125C | ? (at least 4) | `E_NOTIMPL` |
| 136 | `DwmpAllocateSecurityDescriptor` | 0x10001354 | `PSECURITY_DESCRIPTOR *sd` | HRESULT ([below](#dwmpallocatesecuritydescriptor-0x10001354)) |
| 137 | `DwmpFreeSecurityDescriptor` | 0x100013DC | `PSECURITY_DESCRIPTOR sd` | ([below](#dwmpfreesecuritydescriptor-0x100013dc)) |
| 156 | (no name) | 0x1000125C | ? (at least 4) | `E_NOTIMPL` (IDA names the function `DwmTetherTextContact` ?) |

The parameters of the public functions are those of the desktop SDK; the stubs don't read them, except the pointer written by `DwmIsCompositionEnabled`. The function at 0x1000125C saves R0–R3 on the stack and pops them on return (a 4-register frame), the one at 0x10001274 doesn't.

Global state (`.data`):

| Address | Size | Comment |
|---------|------|---------|
| `g_fLoadedSecRuntime` (0x10002224) | 4 | 1 once the load of SecRuntime.dll was attempted (even if it failed) |
| `g_hSecRuntime` (0x10002220) | 4 | Module handle of SecRuntime.dll, NULL if it couldn't be loaded |
| `g_pfnQueryTransientObjectSecurityDescriptor` (0x10002218) | 4 | `EncodePointer` of `SecRuntime!QueryTransientObjectSecurityDescriptor` |
| `g_pfnFreeTransientObjectSecurityDescriptor` (0x1000221C) | 4 | `EncodePointer` of `SecRuntime!FreeTransientObjectSecurityDescriptor` |

### Startup

`_DllMainCRTStartup` (0x1000194C): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then `__DllMainCRTStartup` (0x10001658: `_CRT_INIT`, then `DllMain`). `DllMain` (0x10001A74) only returns TRUE. There is no initialisation: SecRuntime.dll is loaded on the first call of the security descriptor functions.

### TryLoadSecRuntime (0x100012B4)

`?TryLoadSecRuntime@@YAHXZ`, called by both security descriptor exports:

1. If `g_fLoadedSecRuntime` is already set, returns `g_hSecRuntime != NULL`.
2. `LoadLibraryExW(L"SecRuntime.dll", NULL, 0)`. If it works, gets `QueryTransientObjectSecurityDescriptor` and `FreeTransientObjectSecurityDescriptor` with `GetProcAddress` (not checked for NULL) and stores them encoded (`EncodePointer`).
3. Stores the module handle in `g_hSecRuntime` with an interlocked compare-exchange; if another thread was first, `FreeLibrary` on its own handle.
4. Sets `g_fLoadedSecRuntime` = 1 (also when the load failed: it's never retried) and returns `g_hSecRuntime != NULL`.

### DwmpAllocateSecurityDescriptor (0x10001354)

Returns the security descriptor of the compositor surface object in `*sd`:

1. If SecRuntime.dll is loaded: `QueryTransientObjectSecurityDescriptor(1, L"WindowManager\Compositor.Surface", &psd)`. Type 1 is the `Event` prefix, so the descriptor comes from `HKLM\Software\Microsoft\SecurityManager\TransientObjects\%5C%5C.%5CEvent%5CWINDOWMANAGER%5CCOMPOSITOR.SURFACE` value `SecurityDescriptor`. An error is returned as `HRESULT_FROM_NT` (NTSTATUS | 0x10000000).
2. Otherwise: `ConvertStringSecurityDescriptorToSecurityDescriptorW(L"D:(A;;GA;;;SY)(A;;0x001F0003;;;WD)(A;;0x001F0003;;;AC)", SDDL_REVISION_1, &psd, NULL)`: `GENERIC_ALL` for LocalSystem, 0x1F0003 (`EVENT_ALL_ACCESS`) for Everyone and for ALL APPLICATION PACKAGES. An error is returned as `HRESULT_FROM_WIN32(GetLastError())`.
3. On success `*sd` = `psd` and `S_OK`; on failure `*sd` isn't written and a descriptor already allocated is freed with `DwmpFreeSecurityDescriptor`.

The caller must free the descriptor with `DwmpFreeSecurityDescriptor`.

### DwmpFreeSecurityDescriptor (0x100013DC)

`FreeTransientObjectSecurityDescriptor(sd)` (decoded pointer) if SecRuntime.dll is loaded, else `LocalFree(sd)` (the allocator of `ConvertStringSecurityDescriptorToSecurityDescriptorW`). The result of the call is returned as is.

### Registry

| Key | Value | Use |
|-----|-------|-----|
| `HKLM\Software\Microsoft\SecurityManager\TransientObjects\%5C%5C.%5CEvent%5CWINDOWMANAGER%5CCOMPOSITOR.SURFACE` | `SecurityDescriptor` | Read by SecRuntime.dll for [DwmpAllocateSecurityDescriptor](#dwmpallocatesecuritydescriptor-0x10001354) |
