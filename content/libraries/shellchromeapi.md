## ShellChromeAPI.dll

The public API of the Windows Phone 8.1 shell: applications and system components use it to lock / unlock the phone, change the shell settings (screen timeout, wallpaper, Kid's Corner, driving mode…), launch sessions, post toasts, show action dialogs, listen to the hardware buttons, and create the shell reminders (alarms).  
`ShellChromeAPI.dll` is a client library (133 KB of code, 667 functions, 112 exports). Almost every export is a thin wrapper around one procedure of the shell's RPC interface `{8B111127-818E-4AE5-9788-7396504EF98F}` (80 procedures, server security descriptor `RPCShellChrome\Server`). The reminder exports are a client of the Task Scheduler service (interface `ITaskSchedulerSvcRpc`, the same one as [ReminderEvents.dll](./reminderevents.md)): a reminder is a task named `_Reminder_` whose data is the reminder structure. A few exports only read WNF states or the registry, and three subsystems (hardware button listener, action dialogs, system wait cursor) talk to the shell through CoreMessaging endpoints instead of RPC.  
Callers documented here: [Alarms_NoUI.exe](../applications/alarms_noui.md) and [AlarmsSettingHandler.dll](./alarmssettinghandler.md) (reminders, lock screen alarm indicator). The RPC server is [ShellChrome.dll](./shellchrome.md#rpc-server), which checks a capability of the caller in most procedures.

Location on the phone: `C:\Windows\System32\ShellChromeAPI.dll` ?  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4.dll | `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingFree`, `NdrClientCall2`, `I_RpcExceptionFilter` |
| SecRuntime.dll | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor` |
| ntdll.dll | `NtQueryWnfStateData`, `RtlQueryWnfStateData`, `RtlPublishWnfStateData`, `RtlNtStatusToDosError` |
| CoreMessaging.dll | `CoreUICreate`, `CoreUIOpenExisting` |
| CoreUIComponents.dll | `CoreUIFactoryCreate`, `MsgBlobCreateShared`, `MsgStringCreateShared`, `MsgRelease` |
| dsclient.dll | `DSCreateSharedFileToken`, `DSFreeString` |
| WPCOREUTIL.dll | `SHGetKnownFolderPath` |
| ext-ms-win-rtcore-gdi-devcaps-l1-1-0.dll | `GetDeviceCaps` |
| ext-ms-win-rtcore-ntuser-dc-access-l1-1-0.dll | `GetDC`, `ReleaseDC` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegGetValueW`, `RegQueryValueExW`, `RegSetValueExW`, `RegCloseKey` |
| api-ms-win-core-file-l1-2-1.dll | `DeleteFileW` |
| api-ms-win-core-kernel32-legacy-l1-1-1.dll | `CopyFileW`, `WaitForMultipleObjects` |
| api-ms-win-core-shlwapi-legacy-l1-1-0.dll | `PathFileExistsW` |
| api-ms-win-core-com-l1-1-1.dll | `StringFromGUID2`, `CoCreateGuid`, `CoCreateInstance`, `CoTaskMemFree` |
| api-ms-win-core-synch-l1-2-0.dll | `CreateEventW`, `SetEvent`, `ResetEvent`, `WaitForSingleObject`, `Sleep`, critical sections, `InitOnceBeginInitialize`, `InitOnceComplete` |
| api-ms-win-core-processthreads-l1-1-2.dll | `CreateThread`, `GetCurrentThreadId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-heap-l1-2-0.dll | `GetProcessHeap`, `HeapAlloc`, `HeapFree` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `RaiseException`, `RaiseFailFastException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleExW`, `GetModuleFileNameA` |
| api-ms-win-core-delayload-l1-1-1.dll | `ResolveDelayLoadedAPI`, `DelayLoadFailureHook` |
| api-ms-win-core-debug-l1-1-1.dll | `DebugBreak` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `malloc`, `free`, `operator new`/`delete`, `memcpy`, `memmove`, `memset`, `memcmp`, `wcslen`, `_wcsnicmp`, `_vsnwprintf`, `strncpy_s`, … (CRT, `_initterm`, `__dllonexit`, C++ exceptions) |

`dsclient`, `SHGetKnownFolderPath`, `GetDeviceCaps`, `GetDC`/`ReleaseDC`, CoreMessaging and CoreUIComponents are delay-loaded. The msvcrt, rtlsupport, errorhandling, libraryloader, debug and processthreads (`GetCurrentProcess`, `TerminateProcess`) imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code.

### Dependencies

Files used other than the static imports (the delay-loaded DLLs are in the [Imports](#imports) table).

| File | How | Use |
|------|-----|-----|
| Image file of a reminder (reminder +0x54, given by the caller) → `<known folder {2856B913-7185-4C9D-9ACC-981269A83C14}>\Reminders\Images\{GUID}.png` | `CopyFileW` (`PackReminder`, `sub_10016994`), `DeleteFileW` on failure and in `Shell_DeleteReminder` | See [Files](#files) |
| Wallpaper file given to `Shell_SetCurrentWallpaper*` / `Shell_SetCurrentKidZoneWallpaper` | `PathFileExistsW` + `DSCreateSharedFileToken(…, L"MobileUI", …)` (`sub_1000D8A4`) | Shared with the shell, which moves it into its wallpaper folder ([ShellChrome.dll](./shellchrome.md#dependencies)); see [Wallpaper](#wallpaper) |
| [ShellChrome.dll](./shellchrome.md#rpc-server) (shell RPC server `{8B111127-818E-4AE5-9788-7396504EF98F}`, dynamic LRPC endpoint) | `RpcBindingCreateW` / `RpcBindingBind` | Every `Shell_*` export, see [Shell RPC interface](#shell-rpc-interface) |
| RPC server of the Task Scheduler service (`ITaskSchedulerSvcRpc`, dynamic LRPC endpoint) | `RpcBindingCreateW` / `RpcBindingBind` | Reminders, see [Task Scheduler RPC](#task-scheduler-rpc-reminders); the hosting service binary isn't known |

No DLL is loaded with `LoadLibrary` and no process is started. The only `CoCreateInstance` is the standard COM global interface table (`{00000323-0000-0000-C000-000000000046}`, `sub_1000B36C`).

### Exports

Every export returns an HRESULT unless stated otherwise. "RPC n" is the opnum of the [shell RPC interface](#shell-rpc-interface), "TS n" of the [Task Scheduler interface](#task-scheduler-rpc-reminders). Parameter names come from the decorated C++ names when there is one, otherwise from the RPC format strings ("?" = not checked).

| Ordinal | Name | Address | Parameters | Implementation |
|---------|------|---------|------------|----------------|
| 1 | `Shl::ActionDialog::Create` (`ACTION_DIALOG_FULL_SCREEN_CONFIG`) | 0x10018B40 | `Importance imp, const ACTION_DIALOG_FULL_SCREEN_CONFIG &, ActionDialog *&` | [Action dialogs](#action-dialogs) |
| 2 | `Shl::ActionDialog::Create` (`ACTION_DIALOG_PARTIAL_SCREEN_CONFIG`) | 0x10018D30 | `Importance, const ACTION_DIALOG_PARTIAL_SCREEN_CONFIG &, ActionDialog *&` | [Action dialogs](#action-dialogs) |
| 3 | `Shl::ActionDialog::Create` (`ACTION_DIALOG_PICKER_CONFIG`) | 0x10018994 | `Importance, const ACTION_DIALOG_PICKER_CONFIG &, ActionDialog *&` | [Action dialogs](#action-dialogs) |
| 4 | `DiagnosticHook_GetCurrentShellState` | 0x100153F0 | `DWORD *` | RPC 62 |
| 5 | `GetApplicationResolutionHeight` | 0x10007AB8 | `DWORD *` | Registry `LogicalResolution\Height`, else `GetDeviceCaps(VERTRES)` |
| 6 | `GetApplicationResolutionWidth` | 0x10007A98 | `DWORD *` | Registry `LogicalResolution\Width`, else `GetDeviceCaps(HORZRES)` |
| 7 | `SystemWaitCursorAPI::GetSystemWaitCursor` | 0x100165C4 | `ISystemWaitCursor **` | [System wait cursor](#system-wait-cursor) |
| 8 | `Shell_AddOverlay` | 0x10015854 | `PCWSTR` (not NULL) | RPC 33 |
| 9 | `Shell_AdjustVolume` | 0x100157C0 | `DWORD` | RPC 35 |
| 10 | `Shell_BeginUnlock` (C++) | 0x100154A0 | none | RPC 74 |
| 11 | `Shell_CreateAutomation` | 0x10006694 | `DWORD, PCWSTR` | RPC 40 |
| 12 | `Shell_CreateReminder` | 0x10017860 | `HANDLE hReminders, const REMINDER *, const REMINDER_LAUNCH *` | [Reminders](#reminders) |
| 13 | `Shell_DeInitReminders` | 0x100099FC | `HANDLE` | `RpcBindingFree` |
| 14 | `Shell_DeleteReminder` | 0x10016FE0 | `HANDLE, const GUID *` | [Reminders](#reminders) |
| 15 | `Shell_EnableLockApp` (C++) | 0x10015348 | `BOOL` | RPC 76 |
| 16 | `Shell_EnableUserIdleTimeouts` | 0x10015C10 | `BOOL` | RPC 56 |
| 17 | `Shell_EndDrivingMode` | 0x1001634C | none | RPC 8 |
| 18 | `Shell_EndUnlock` (C++) | 0x10015460 | none | RPC 75 |
| 19 | `Shell_ExitOobeStateAndContinueRunningApp` (C++) | 0x100159D0 | none | RPC 46 |
| 20 | `Shell_FindFirstReminder` | 0x10007E30 | `HANDLE, DWORD filter, HANDLE *phFind, ?, REMINDER **` | [Reminders](#reminders) |
| 21 | `Shell_FindNextReminder` | 0x10017208 | `HANDLE, ?, HANDLE hFind, ?` | TS 3 |
| 22 | `Shell_FindReminderClose` | 0x1000D804 | `HANDLE, HANDLE *phFind` | TS 4 |
| 23 | `Shell_GetCoverAutoUnlock` | 0x10015228 | `DWORD *` | RPC 22 |
| 24 | `Shell_GetCurrentLockState` | 0x10008C88 | none; returns the state (0…2) | [WNF](#wnf-states) `SHL` 1 |
| 25 | `Shell_GetCurrentLockdownProfile` | 0x100163CC | `DWORD, GUID *` | RPC 6 |
| 26 | `Shell_GetCurrentMode` | 0x10007A2C | none; returns the mode (0…6) | [WNF](#wnf-states) `SHL` 23 |
| 27 | `Shell_GetCurrentWallpaper` | 0x100161B8 | `PWSTR *` | RPC 16 |
| 28 | `Shell_GetLockGraceTime` | 0x10015E58 | `DWORD *` | RPC 50 |
| 29 | `Shell_GetLockGraceTimeWValidList` | 0x10015CFC | `DWORD *, DWORD *, list *` | RPC 54 |
| 30 | `Shell_GetLockPinpadHeight` (C++) | 0x100154E0 | `DWORD *` | RPC 73 |
| 31 | `Shell_GetLockedOrientation` | 0x10007D98 | `DWORD *` | [WNF](#wnf-states) `SHL` 42 |
| 32 | `Shell_GetNavigationBarVisible` | 0x10015178 | `BOOL *` | RPC 66 |
| 33 | `Shell_GetNotificationsAboveLock` (C++) | 0x100153B8 | `BOOL *` | RPC 70 |
| 34 | `Shell_GetReminderData` | 0x100089B0 | `HANDLE, const GUID *, REMINDER **` | [Reminders](#reminders) |
| 35 | `Shell_GetScreenIdleTime` | 0x10015DE8 | `DWORD *` | RPC 52 |
| 36 | `Shell_GetScreenIdleTimeWValidList` | 0x10015C48 | `DWORD *, DWORD *, list *` | RPC 55 |
| 37 | `Shell_GetSystemScreenSize` | 0x10015100 | `DWORD *` | RPC 79 |
| 38 | `Shell_GetValidLockGraceTimesList` | 0x1001710C | as 29 | `Shell_GetLockGraceTimeWValidList` |
| 39 | `Shell_GetValidScreenIdleList` | 0x100170F0 | as 36 | `Shell_GetScreenIdleTimeWValidList` |
| 40 | `Shell_HideHighlightCursor` | 0x10015600 | none | RPC 64 |
| 41 | `Shell_IdleTimerReset` | 0x100086F0 | `DWORD` | RPC 19 |
| 42 | `Shell_InitReminders` | 0x10008CF4 | `HANDLE *` | [Task Scheduler binding](#task-scheduler-rpc-reminders) |
| 43 | `Shell_InvokeLensPicker` | 0x10016484 | `const GUID *` ? | RPC 2 |
| 44 | `Shell_IsActiveWallpaperProvider` | 0x10016180 | `BOOL *` | RPC 17 |
| 45 | `Shell_IsDoNotDisturbModeActive` | 0x10008FCC | none; returns a BOOL | [WNF](#wnf-states) `RW` 173, then registry `Disturb\Enabled` |
| 46 | `Shell_IsDrivingModeActive` | 0x10008F40 | none; returns a BOOL | [WNF](#wnf-states) `SHL` 36 |
| 47 | `Shell_IsKidZoneActive` | 0x10008A84 | none; returns a BOOL | [WNF](#wnf-states) `SHL` 23 = 1 |
| 48 | `Shell_IsKidZoneEnabled` | 0x10008B88 | none; returns a BOOL | Registry `KidZone\Configuration\Enabled` |
| 49 | `Shell_IsLockAppRegistered` | 0x10016058 | `BOOL *` | RPC 26 |
| 50 | `Shell_IsLockPasswordSet` | 0x100164D0 | none; returns a BOOL | RPC 3 |
| 51 | `Shell_IsLocked` | 0x10008644 | none; returns a BOOL | [WNF](#wnf-states) `SHL` 1 ≠ 0 |
| 52 | `Shell_IsSystemOverlayAppRegistered` | 0x10015FA0 | `BOOL *` | RPC 29 |
| 53 | `Shell_IsUnlockedNormal` | 0x10016598 | none; returns a BOOL | `Shell_GetCurrentLockState() == 0 && Shell_GetCurrentMode() == 0` |
| 54 | `Shell_LaunchModernNfcEventSession` | 0x10015990 | `PCWSTR, PCWSTR, PCWSTR, DWORD` | RPC 47 |
| 55 | `Shell_LaunchQuickSettingsPluginCPL` | 0x1001557C | `DWORD, DWORD` | RPC 69 |
| 56 | `Shell_LaunchSessionByUri` | 0x10015B28 | `PCWSTR uri` | RPC 41 |
| 57 | `Shell_LaunchSessionByUriEx` | 0x10015AF0 | `PCWSTR uri` | RPC 42 |
| 58 | `Shell_LaunchSessionByUriReset` | 0x10015A90 | `PCWSTR uri` | RPC 43 |
| 59 | `Shell_LaunchSessionGeneric` (C++) | 0x10015A50 | `const WCHAR *, const WCHAR *, const WCHAR *, UINT` | RPC 44 |
| 60 | `Shell_LaunchSpeechSessionByUri` | 0x10007C28 | `PCWSTR uri` | RPC 49 |
| 61 | `Shell_LaunchWalletSessionByUri` | 0x10015958 | `PCWSTR uri` | RPC 48 |
| 62 | `Shell_LoadLockdownResources` | 0x10016404 | none | RPC 5 |
| 63 | `Shell_Lock` | 0x10016558 | none | RPC 0 |
| 64 | `Shell_LockAndShowKidZoneLock` | 0x10016444 | none | RPC 4 |
| 65 | `Shell_LockOrientation` | 0x100152D0 | `DWORD` | RPC 72 |
| 66 | `Shell_LockScreen_GetNotificationsSnapshot` | 0x10015E90 | `SNAPSHOT *` (0x1F6C bytes ?) | RPC 11 |
| 67 | `Shell_NavigateToErrorPageOnGenericActionBlockedInKidZone` (C++) | 0x100156CC | none | RPC 38 |
| 68 | `Shell_NavigateToErrorPageOnPinShellTileFailureInKidZone` | 0x1001568C | none | RPC 39 |
| 69 | `Shell_PostMessageToast2` | 0x10017144 | `const TOAST *, ?, ?, ?` | [Toasts](#toasts), RPC 10 |
| 70 | `Shell_PostMessageToast` | 0x10017158 | `const TOAST *` | [Toasts](#toasts), RPC 10 |
| 71 | `Shell_RaiseGameAchievementMessageToast` | 0x10017128 | `const TOAST *` | [Toasts](#toasts), RPC 10 |
| 72 | `Shell_RaiseToastNotifications` (C++) | 0x10015308 | none | RPC 78 |
| 73 | `Shell_RefreshLockLASSData` | 0x10015B60 | none | RPC 13 |
| 74 | `Shell_RefreshLockScreenNotifications` | 0x10015F60 | none | RPC 30 |
| 75 | `Shell_RegisterButtonPressCallback` | 0x10006DD0 | `DWORD button, IButtonCallback *` ? | [Hardware buttons](#hardware-buttons) |
| 76 | `Shell_RegisterLockApp` | 0x100160D0 | none | RPC 24 |
| 77 | `Shell_RegisterSystemOverlayApp` | 0x10016018 | none | RPC 27 |
| 78 | `Shell_ReleaseReminderData` | 0x1000B2FC | `HANDLE, REMINDER *` | `HeapFree(GetProcessHeap(), 0, p)`; always S_OK |
| 79 | `Shell_RemoveOverlay` | 0x100157F8 | `PCWSTR` (not NULL) | RPC 34 |
| 80 | `Shell_RequestBackstackReset` | 0x10015A10 | none | RPC 45 |
| 81 | `Shell_RequestShutdown` | 0x100170E0 | `DWORD` | `Shell_RequestShutdownEx(x, 5)` |
| 82 | `Shell_RequestShutdownEx` | 0x10015518 | `DWORD, DWORD` | RPC 60 |
| 83 | `Shell_SetAsActiveWallpaperProvider` | 0x10016148 | `DWORD *` | RPC 18 |
| 84 | `Shell_SetCoverAutoUnlock` | 0x10015260 | `DWORD` | RPC 21 |
| 85 | `Shell_SetCurrentKidZoneWallpaper` | 0x1001570C | `PCWSTR path` | [Wallpaper](#wallpaper), RPC 37 |
| 86 | `Shell_SetCurrentWallpaper` | 0x100162A0 | `PCWSTR path, BOOL isFile` | [Wallpaper](#wallpaper), RPC 14 |
| 87 | `Shell_SetCurrentWallpaperAndProvider` | 0x100161F0 | `PCWSTR path, ?, BOOL isFile, ?` | [Wallpaper](#wallpaper), RPC 15 |
| 88 | `Shell_SetDebugOverlay` | 0x100158B0 | `PCWSTR` (may be NULL) | RPC 32 |
| 89 | `Shell_SetHardwareButtonRestrictedState` | 0x1000C6F0 | `DWORD` | Publishes [WNF](#wnf-states) `SHL` 9 |
| 90 | `Shell_SetKidZoneDisplayName` | 0x10015788 | `PCWSTR` (may be NULL) | RPC 36 |
| 91 | `Shell_SetKidZoneEnabled` | 0x1000D920 | `BOOL` | Registry + [WNF](#wnf-states) `SHL` 19 |
| 92 | `Shell_SetLockGraceTime` | 0x10015E20 | `DWORD` | RPC 51 |
| 93 | `Shell_SetLockScreenAlarmIndication` | 0x10009874 | `BOOL` | RPC 9 |
| 94 | `Shell_SetNavigationBarVisible` | 0x100151B0 | `BOOL` | RPC 65 |
| 95 | `Shell_SetNotificationsAboveLock` (C++) | 0x10015380 | `BOOL` | RPC 71 |
| 96 | `Shell_SetReminderState` | 0x1000D83C | `HANDLE, const GUID *, DWORD` | TS 6 |
| 97 | `Shell_SetScreenIdleTime` | 0x10015DB0 | `DWORD` | RPC 53 |
| 98 | `Shell_SetShowNowPlayingMediaArt` | 0x10016110 | `BOOL` | RPC 20 |
| 99 | `Shell_SetTestScene` | 0x100158E8 | `PCWSTR` (may be NULL) | RPC 31 |
| 100 | `Shell_ShowHighlightCursor` | 0x10015640 | 4 × `DWORD` (rectangle ?) | RPC 63 |
| 101 | `Shell_StartDrivingMode` | 0x1001638C | `DWORD` | RPC 7 |
| 102 | `Shell_TurnScreenOn` | 0x10015920 | `DWORD` | RPC 59 |
| 103 | `Shell_Unlock` | 0x10016518 | none | RPC 1 |
| 104 | `Shell_UnregisterButtonPressCallback` | 0x10006B30 | `DWORD button, IButtonCallback *` ? | [Hardware buttons](#hardware-buttons) |
| 105 | `Shell_UnregisterLockApp` | 0x10016090 | none | RPC 25 |
| 106 | `Shell_UnregisterSystemOverlayApp` | 0x10015FD8 | none | RPC 28 |
| 107 | `Shell_UpdateAuthenticationData` | 0x10015BA0 | 4 parameters, 1st and 4th not NULL | RPC 12 |
| 108 | `Shell_UpdateNavigationBarSettings` | 0x10015138 | none | RPC 67 |
| 109 | `Shell_UpdateQuickSettingsPluginInfo` | 0x100155B4 | `DWORD, PCWSTR, PCWSTR, PCWSTR, PCWSTR, DWORD` | RPC 68 |
| 110 | `TestHook_EnableOverlayApp` (C++) | 0x10015298 | `BOOL` | RPC 77 |
| 111 | `TestHook_GetCurrentDeviceLockTypes` | 0x10015428 | `DWORD *, DWORD *` | RPC 61 |
| 112 | `TestHook_InitializeSmartCover` | 0x100151E8 | none | RPC 23 |

The decorated names: `?Shell_BeginUnlock@@YAJXZ`, `?Shell_EnableLockApp@@YAJH@Z`, `?Shell_GetLockPinpadHeight@@YAJPAK@Z`, `?Shell_LaunchSessionGeneric@@YAJPBG00I@Z`, `?Create@ActionDialog@1Shl@@SAJW4Importance@312@ABUACTION_DIALOG_FULL_SCREEN_CONFIG@12@AAPAV112@@Z`, `?GetSystemWaitCursor@SystemWaitCursorAPI@@YAJPAPAUISystemWaitCursor@@@Z`, etc.

There is no global object: each RPC export builds its binding on the stack and frees it before returning (see [below](#shell-rpc-interface)).

### Startup

`start` (`_DllMainCRTStartup`, 0x1000A320): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then the usual `dllmain_dispatch` (`sub_1000A02C`: CRT init with `_initterm`, then `DllMain`).  
`DllMain` (`sub_1000C26C`) registers the ETW provider on `DLL_PROCESS_ATTACH` (`sub_10008C08`) and unregisters it on `DLL_PROCESS_DETACH` (`sub_10008C50`). A CRT initialiser (`sub_1000667C` → `sub_10008BDC`) creates the critical section of the button listener (`unk_1001E558`). Nothing else is done at load time.

### Shell RPC interface

Interface `{8B111127-818E-4AE5-9788-7396504EF98F}` version 0.0 (MIDL stub descriptor at 0x10001310, proc format string from 0x10001362, type format string at 0x100011FA). All procedures take the binding as explicit primitive handle and return a `long` (HRESULT).

**Binding** (`ConnectShell`, `sub_10008E1C`; an inlined copy in `sub_100066DC`):
1. `QueryTransientObjectSecurityDescriptor(9, L"RPCShellChrome\\Server", &sd)` (SecRuntime): security descriptor the server must have. On failure the NTSTATUS with bit 28 set is returned.
2. `RpcBindingCreateW(&template, &security, NULL, &h)`:
   - template: version 1, flags 0, protocol sequence 3 (`RPC_PROTSEQ_LRPC`), no address, no endpoint (resolved by the endpoint mapper);
   - security: version 1, authentication level 6 (`RPC_C_AUTHN_LEVEL_PKT_PRIVACY`), service 10 (`RPC_C_AUTHN_WINNT`), QoS version 5 with `RPC_C_QOS_IDENTITY_DYNAMIC`, `RPC_C_IMP_LEVEL_IDENTIFY` and `ServerSecurityDescriptor = sd`.
3. `RpcBindingBind(NULL, h, interface)`; the binding is marked as bound (byte +0 of the stack structure `{ BYTE bound; RPC_BINDING_HANDLE h; … }`).

Each wrapper (`sub_10014294` for opnum 0, etc.) binds if needed, calls the stub, and if the call fails with one of 0x800706A6 (`RPC_S_INVALID_BINDING`), 0x800706B5 (`RPC_S_UNKNOWN_IF`), 0x800706BA (`RPC_S_SERVER_UNAVAILABLE`), 0x800706BB (`RPC_S_SERVER_TOO_BUSY`), 0x800706BE (`RPC_S_CALL_FAILED`), 0x800706BF (`RPC_S_CALL_FAILED_DNE`), 0x800706D3, 0x800706D9 (`EPT_S_NOT_REGISTERED`), 0x800706EF, 0x80070721, it frees the binding, binds again and retries once (the shell may have restarted). RPC exceptions are turned into `0x80010000 | code`.

Types in the format string: `string` = `[string] wchar_t *` (FC_C_WSTRING, type 34), `string*` = same, full pointer (may be NULL, type 36), `GUID` = 16-byte structure (type 12).

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `sub_10014294` | `Shell_Lock` | – | Lock |
| 1 | `sub_1001416C` | `Shell_Unlock` | – | Unlock |
| 2 | `sub_10013F0C` | `Shell_InvokeLensPicker` | `[in] GUID *` | Lens picker |
| 3 | `sub_1001403C` | `Shell_IsLockPasswordSet` | `[out] long` | |
| 4 | `sub_10013DE4` | `Shell_LockAndShowKidZoneLock` | – | |
| 5 | `sub_1000C1D0` | `Shell_LoadLockdownResources` | – | |
| 6 | `sub_1000C1AC` | `Shell_GetCurrentLockdownProfile` | `[in] long`, `[out] GUID` | |
| 7 | `sub_10013A8C` | `Shell_StartDrivingMode` | `[in] long` | |
| 8 | `sub_10013964` | `Shell_EndDrivingMode` | – | |
| 9 | `sub_100098CC` | `Shell_SetLockScreenAlarmIndication` | `[in] long` | Alarm icon of the lock screen |
| 10 | `sub_1000C154` | [Toasts](#toasts) | `[in] GUID` (by value), `string`, `string`, `string*`, `string*`, `[in] long`, `[in] long`, `string*`, `[in] long` | Post a toast |
| 11 | `sub_100125D4` | `Shell_LockScreen_GetNotificationsSnapshot` | `[in,out]` structure of 0x1F6C bytes ? | |
| 12 | `sub_1000C108` | `Shell_UpdateAuthenticationData` | `[in] long`, `[in]` 8-byte structure (by value), 5 × `[in] long`, `string*`, `string*` | |
| 13 | `sub_10011B74` | `Shell_RefreshLockLASSData` | – | |
| 14 | `sub_1000B59C` | `Shell_SetCurrentWallpaper` | `string*`, `[in] long` | |
| 15 | `sub_1000B55C` | `Shell_SetCurrentWallpaperAndProvider` | `string*`, `[in] GUID` (by value), `[in] long` | |
| 16 | `sub_100133D4` | `Shell_GetCurrentWallpaper` | `[out]` string | |
| 17 | `sub_100132A4` | `Shell_IsActiveWallpaperProvider` | `[out] long` | |
| 18 | `sub_10013174` | `Shell_SetAsActiveWallpaperProvider` | `[out] long` | |
| 19 | `sub_10008764` | `Shell_IdleTimerReset` | `[in] long` | |
| 20 | `sub_10013044` | `Shell_SetShowNowPlayingMediaArt` | `[in] long` | |
| 21 | `sub_1000C054` | `Shell_SetCoverAutoUnlock` | `[in] long` | |
| 22 | `sub_1000C038` | `Shell_GetCoverAutoUnlock` | `[out] long` | |
| 23 | `sub_1000C01C` | `TestHook_InitializeSmartCover` | – | |
| 24, 25, 26 | `sub_10012F1C`, `sub_10012DF4`, `sub_10012CC4` | `Shell_RegisterLockApp`, `Shell_UnregisterLockApp`, `Shell_IsLockAppRegistered` | –, –, `[out] long` | |
| 27, 28, 29 | `sub_10012B9C`, `sub_10012A74`, `sub_10012944` | `Shell_RegisterSystemOverlayApp`, `Shell_UnregisterSystemOverlayApp`, `Shell_IsSystemOverlayAppRegistered` | –, –, `[out] long` | |
| 30 | `sub_1001281C` | `Shell_RefreshLockScreenNotifications` | – | |
| 31 | `sub_10010FD4` | `Shell_SetTestScene` | `string*` | |
| 32 | `sub_10010EA4` | `Shell_SetDebugOverlay` | `string*` | |
| 33, 34 | `sub_10010D74`, `sub_10010C44` | `Shell_AddOverlay`, `Shell_RemoveOverlay` | `string` | |
| 35 | `sub_10010B14` | `Shell_AdjustVolume` | `[in] long` | |
| 36 | `sub_100109E4` | `Shell_SetKidZoneDisplayName` | `string*` | |
| 37 | `sub_1000BFFC` | `Shell_SetCurrentKidZoneWallpaper` | `string*` | |
| 38, 39 | `sub_100107A4`, `sub_1001067C` | `Shell_NavigateToErrorPageOn…InKidZone` | – | |
| 40 | `sub_1000BFD8` | `Shell_CreateAutomation` | `[in] long`, `string` | |
| 41, 42, 43 | `sub_10011A44`, `sub_10011914`, `sub_100117E4` | `Shell_LaunchSessionByUri`, `…Ex`, `…Reset` | `string` | |
| 44 | `sub_1000BFAC` | `Shell_LaunchSessionGeneric` | `string`, `string`, `string`, `[in] long` | |
| 45 | `sub_100115A4` | `Shell_RequestBackstackReset` | – | |
| 46 | `sub_1001147C` | `Shell_ExitOobeStateAndContinueRunningApp` | – | |
| 47 | `sub_1000BF80` | `Shell_LaunchModernNfcEventSession` | `string`, `string`, `string`, `[in] long` | |
| 48 | `sub_10011234` | `Shell_LaunchWalletSessionByUri` | `string` | |
| 49 | `sub_10007C68` | `Shell_LaunchSpeechSessionByUri` | `string` | |
| 50, 51 | `sub_100124A4`, `sub_10012374` | `Shell_GetLockGraceTime`, `Shell_SetLockGraceTime` | `[out] long`, `[in] long` | |
| 52, 53 | `sub_10012244`, `sub_10012114` | `Shell_GetScreenIdleTime`, `Shell_SetScreenIdleTime` | `[out] long`, `[in] long` | |
| 54 | `sub_1000BF58` | `Shell_GetLockGraceTimeWValidList` | `[out] long`, `[out] long`, `[out]` 0x20-byte structure | Current value + valid values ? |
| 55 | `sub_1000BF30` | `Shell_GetScreenIdleTimeWValidList` | same | |
| 56 | `sub_10011DB4` | `Shell_EnableUserIdleTimeouts` | `[in] long` | |
| 57 | `sub_1000EB04` | `Shell_CreateReminder` | `[in]` 8-byte structure (WNF state name) | New reminder state, see [Reminders](#reminders) |
| 58 | `sub_1000E9D4` | `Shell_DeleteReminder` | `[in]` 8-byte structure (WNF state name) | Deleted reminder state |
| 59 | `sub_10011104` | `Shell_TurnScreenOn` | `[in] long` | |
| 60 | `sub_1000BF0C` | `Shell_RequestShutdownEx` | `[in] long`, `[in] long` | |
| 61 | `sub_1000BEE8` | `TestHook_GetCurrentDeviceLockTypes` | `[out] long`, `[out] long` | |
| 62 | `sub_1000FB2C` | `DiagnosticHook_GetCurrentShellState` | `[out] long` | |
| 63 | `sub_1000BEBC` | `Shell_ShowHighlightCursor` | 4 × `[in] long` | |
| 64 | `sub_1001043C` | `Shell_HideHighlightCursor` | – | |
| 65, 66 | `sub_1000EFA4`, `sub_1000EE74` | `Shell_SetNavigationBarVisible`, `Shell_GetNavigationBarVisible` | `[in] long`, `[out] long` | |
| 67 | `sub_1000ED4C` | `Shell_UpdateNavigationBarSettings` | – | |
| 68 | `sub_1000BE88` | `Shell_UpdateQuickSettingsPluginInfo` | `[in] long`, `string*`, `string*`, `string*`, `string`, `[in] long` | |
| 69 | `sub_1000BE64` | `Shell_LaunchQuickSettingsPluginCPL` | `[in] long`, `[in] long` | |
| 70, 71 | `sub_1000F9FC`, `sub_1000F8CC` | `Shell_GetNotificationsAboveLock`, `Shell_SetNotificationsAboveLock` | `[out] long`, `[in] long` | |
| 72 | `sub_1000F544` | `Shell_LockOrientation` | `[in] long` | |
| 73 | `sub_1000FFC4` | `Shell_GetLockPinpadHeight` | `[out] long` | |
| 74, 75 | `sub_1000FE9C`, `sub_1000FD74` | `Shell_BeginUnlock`, `Shell_EndUnlock` | – | |
| 76 | `sub_1000F79C` | `Shell_EnableLockApp` | `[in] long` | |
| 77 | `sub_1000F414` | `TestHook_EnableOverlayApp` | `[in] long` | |
| 78 | `sub_1000F674` | `Shell_RaiseToastNotifications` | – | |
| 79 | `sub_1000BE48` | `Shell_GetSystemScreenSize` | `[out] long` | |

All 80 opnums (0…79) are used. The server routines and the capability each one requires are listed in [ShellChrome.dll](./shellchrome.md#rpc-server); the meaning of the values (lock state, modes, idle times…) is decided by its UI code, which isn't analysed.

### Task Scheduler RPC (reminders)

`Shell_InitReminders(HANDLE *ph)` (0x10008CF4) returns E_INVALIDARG for a NULL pointer, does nothing if `*ph` is already set, else `ConnectTaskScheduler` (`sub_10008D24`) — the same code as `sub_10003848` of [ReminderEvents.dll](./reminderevents.md#rpc):
1. `QueryTransientObjectSecurityDescriptor(9, L"ITaskSchedulerSvcRpc\\Server", &sd)`; 0xC0000109 → 0x8007013D, other NTSTATUS → Win32 error of `RtlNtStatusToDosError` (or NTSTATUS | 0x10000000).
2. `RpcBindingCreateW`: LRPC, no endpoint, `RPC_C_AUTHN_LEVEL_PKT_PRIVACY`, `RPC_C_AUTHN_WINNT`, QoS version 5 identify / dynamic, `ServerSecurityDescriptor = sd`.
3. `RpcBindingBind`, up to 3 times, 500 ms apart, while it fails with 1722, 1708, 1717 or 1753.

The handle given to the other reminder exports is this RPC binding handle. `Shell_DeInitReminders(h)` (`sub_10009A2C`) calls `RpcBindingFree` (E_UNEXPECTED if the handle is NULL).

Interface `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` version 2.0 (stub descriptor at 0x10002830):

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 0 | `sub_1000B8B8` | `Shell_CreateReminder` | `[in]` task item (0x3C bytes), `[in] long` | Create the task |
| 1 | `sub_1000B858` | `Shell_DeleteReminder` | `[in] GUID *` | Delete the task |
| 2 | `sub_100083DC` | `Shell_FindFirstReminder` | `[out]` context handle, 3 × `[in,out]` | Start an enumeration |
| 3 | `sub_10007F50` | `Shell_FindFirstReminder`, `Shell_FindNextReminder` | `[in]` context handle, 3 × `[in,out]` (the last one is the item) | Next task |
| 4 | `sub_10008340` | `Shell_FindFirstReminder`, `Shell_FindReminderClose` | `[in,out]` context handle | End of the enumeration |
| 5 | `sub_10008A18` | `Shell_GetReminderData` | `[in] GUID *`, `[in,out]`, `[in,out]` item | Get one task |
| 6 | `sub_1000B7F4` | `Shell_SetReminderState` | `[in] GUID *`, `[in] long` | Enable / disable ? |
| 11 | `sub_1000B790` | `Shell_CreateReminder`, `Shell_DeleteReminder` | `[in] GUID *`, `[in,out]` 8 bytes | WNF state name of the task |

Opnums 1, 2, 3, 4, 5 and 11 are also used by [ReminderEvents.dll](./reminderevents.md#rpc) (which adds 10, snooze); 0 and 6 are only used here among the reminder clients. [WPTimeSvc.dll](./wptimesvc.md#task-scheduler-rpc) uses opnums 0, 1 and 5 for its `NTP Time Sync Schedule` task, whose action (type 3) publishes a WNF state instead of carrying data. The errors 0x82CF010D and 0x82CF010E (end of enumeration / not found ?) are returned as 0x80070490 (`ERROR_NOT_FOUND`) by the find functions; `Shell_GetReminderData` returns S_OK with `*ppData = NULL` for 0x82CF010E.

### Reminders

**Task item** (built by `Shell_CreateReminder` for opnum 0, returned by opnums 3 and 5):

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Pointer to the GUID of the reminder (the reminder structure, whose first field is the GUID) |
| 0x04 | 4 | Flags: 1; + 2 if the reminder is disabled (reminder +0x10 & 0x200); + 8 if reminder +0x10 & 0x1000 |
| 0x08 | 4 | `L"_Reminder_"`: the find functions skip the tasks with another name (`_wcsnicmp`, 11 characters) |
| 0x0C | 16 | Reminder +0x18…+0x27 (`SYSTEMTIME`). In a returned item: next ring time, copied to reminder +0xC0 |
| 0x1C | 16 | Same copy |
| 0x2C | 4 | 1 |
| 0x30 | 4 | 0 ? |
| 0x34 | 4 | Pointer to `{ DWORD 4; DATA *p }`, `DATA = { 0, 0, DWORD size, BYTE *data }`: the [packed reminder](#packed-reminder) |
| 0x38 | 4 | 0 ? |

**Shell_CreateReminder(h, reminder, launch)** (0x10017860, disassembly only):
1. `PackReminder` (`sub_10016994`) builds the packed data (`HeapAlloc`). If the size is 0xD0 and the version (reminder +0x50) is 0, E_INVALIDARG.
2. TS opnum 0 with the task item above.
3. TS opnum 11: WNF state name of the new task.
4. Shell RPC opnum 57 with that state name (`sub_100150C8`): the shell starts watching the state ([ShellChrome.dll](./shellchrome.md#rpc-server) calls [ReminderEvents.dll](./reminderevents.md#addreminderpublishstatename--removereminderpublishstatename)`!AddReminderPublishStateName`; opnum 58 calls `RemoveReminderPublishStateName`).
5. Frees the packed data.

**Shell_DeleteReminder(h, guid)** (0x10016FE0): deletes `<FOLDERID {2856B913-7185-4C9D-9ACC-981269A83C14}>\Reminders\Images\{GUID}.png` (`sub_10014E7C`, `ERROR_FILE_NOT_FOUND` ignored), TS opnum 11 (state name), shell RPC opnum 58 with the state name, then TS opnum 1.

**Shell_GetReminderData(h, guid, &p)** (0x100089B0): TS opnum 5, then `ItemToReminder` (`sub_1001501C`): `UnpackReminder` (`sub_1000E890`, the same conversion as [ReminderEvents.dll](./reminderevents.md#reminder-data): version 4/5 or 92-byte headers → version 5) into a heap block, then +0xBC = !(item flags & 2) (enabled), +0xC0 = item +0x0C…+0x1B (`SYSTEMTIME`). Release with `Shell_ReleaseReminderData`.

**Shell_FindFirstReminder(h, filter, &hFind, x, &p)** (0x10007E30): TS opnum 2, then TS opnum 3 until an item named `_Reminder_` whose DWORD at +0x18 of the packed data (the reminder field +0x14 ?) equals `filter` or shares a bit with it. If `p` isn't NULL, the item is converted like `Shell_GetReminderData`. On failure the enumeration is closed (TS opnum 4). `Shell_FindNextReminder` continues with TS opnum 3, `Shell_FindReminderClose(h, &hFind)` closes it.

**Shell_SetReminderState(h, guid, state)**: TS opnum 6. [Alarms_NoUI.exe](../applications/alarms_noui.md) calls it with 0 for a one-time alarm that has rung.

#### Packed reminder

`PackReminder(reminder, launch, &data, &size)` (`sub_10016994`) requires reminder != NULL, +0x3C and +0x40 not NULL, and launch[0] != NULL or (launch[2] and launch[3] != NULL); otherwise E_INVALIDARG. If reminder +0x54 (image file) isn't NULL, the file is copied (`CopyFileW`) to `<FOLDERID {2856B913-…}>\Reminders\Images\{GUID}.png` and that path replaces it (the copy is deleted if the packing fails).

The data is `DWORD 0xD0` followed by a 0xD0-byte header (the format read by [ReminderEvents.dll](./reminderevents.md#reminder-data)), then the strings, then the custom data. The header is the 0xA8 bytes of the reminder structure followed by the 5 DWORDs of the launch structure (0xA8…0xBB); every string pointer is replaced by its offset from the start of the header (`sub_100143BC`), the custom data (+0x48, size +0x4C) is appended and +0x48 becomes its offset.

String fields: 0x38, 0x3C, 0x40, 0x44, 0x54 (image), 0x58, 0x5C, 0x60, 0x64, 0x68, 0x6C, 0x7C, 0x80, 0x90, 0x94, 0xA4, and the launch fields 0xA8 (program), 0xAC (command line), 0xB0, 0xB4, 0xB8. The meaning of the other strings is unknown. The reminder structure filled by Alarms_NoUI.exe is in [Shell_CreateReminder parameters](../applications/alarms_noui.md#shell_createreminder-parameters).

### WNF states

Decoded with `wnf.py`. They are read with `NtQueryWnfStateData` (4 bytes expected, any other size or error → ETW event 10001) or `RtlQueryWnfStateData`.

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x418A063EA3BC0875 (`.text:0x100028F4`) | `SHL`, 1 | 4 bytes: lock state (0…2) | Read by `Shell_GetCurrentLockState` (0x7FFFFFFF on error) and `Shell_IsLocked` (≠ 0, or error → TRUE) |
| 0x418A063EA3BCB875 (`.text:0x100028EC`) | `SHL`, 23 | 4 bytes: shell mode (0…6), 1 = Kid's Corner | Read by `Shell_GetCurrentMode` (0 on error) and `Shell_IsKidZoneActive` |
| 0x418A063EA3BD2075 (`.text:0x100028E4`) | `SHL`, 36 | 4 bytes: ≠ 0 = driving mode | Read by `Shell_IsDrivingModeActive` |
| 0x418A063EA3BD5475 (`.text:0x100028DC`) | `SHL`, 42 (permanent) | 4 bytes: locked orientation | Read by `Shell_GetLockedOrientation` (0 if the size isn't 4) |
| 0x41C6193FA3B96875 (`.text:0x100028D4`) | `RW`, 173 | 8 bytes: bit 0 of the first DWORD = do not disturb (quiet hours ?) | Read by `Shell_IsDoNotDisturbModeActive` and `IsQuietMode` (`sub_1000BA58`); if not set, registry `Disturb\Enabled` |
| 0x41C61D22A3BC3075 | `OS`, 6 | 4 bytes, published by [wppower.sys](../drivers/wppower.md#wnf-states) (0 or 2) | Read by `sub_1000C644` (action dialogs): during do not disturb, a dialog is shown only if the value is 0 or the config flag +0x11C is set |
| 0x418A063EA3BC4875 (`.text:0x10005A20`) | `SHL`, 9 | 4 bytes: the parameter | Published by `Shell_SetHardwareButtonRestrictedState` |
| 0x418A063EA3BC9875 (`.text:0x10005A18`) | `SHL`, 19 | 4 bytes: enabled | Published by `Shell_SetKidZoneEnabled` |

The `SHL` 6 and 30 states published by the alarm code (0x418A063EA3BC3075, 0x418A063EA3BCF075) aren't used here. `SHL` 1, 23, 36 and 42 are published by [ShellChrome.dll](./shellchrome.md#wnf-states).

### Registry

All under `HKEY_LOCAL_MACHINE`:

| Key | Value | Use |
|-----|-------|-----|
| `Software\Microsoft\Shell\LogicalResolution` | `Width`, `Height` (`REG_DWORD`) | `GetApplicationResolutionWidth` / `Height` (`sub_10007AD8`); if missing, `GetDeviceCaps(GetDC(NULL), HORZRES / VERTRES)` (`sub_1000B91C`) |
| `Software\Microsoft\Shell\Disturb` | `Enabled` | Do not disturb (`sub_10009828`) |
| `Software\Microsoft\Family\KidZone\Configuration` | `Enabled` (`REG_DWORD`) | Read by `Shell_IsKidZoneEnabled`; written by `Shell_SetKidZoneEnabled` (`RegCreateKeyExW`, `KEY_WRITE`, with a security descriptor built by `sub_1000C9DC`) when the value changes, then WNF `SHL` 19 |
| `SOFTWARE\Microsoft\Shell\RetailDemo\OobeWrite` | `Enabled` | Retail demo (`sub_1000B4A8`) |
| `SOFTWARE\Microsoft\Shell\RetailDemo\RdmActive` | `ProvisioningActive` | Read if `OobeWrite\Enabled` ≠ 0 (`sub_1000B9D8`): when set, the action dialogs fail with 0x86606012 |
| `System\DevPlat` | `ShouldFailFast` (default 1) | `sub_1000C6A4`: on a fatal error of the button listener (ETW event 200), fail fast or not |

### Files

`<FOLDERID {2856B913-7185-4C9D-9ACC-981269A83C14}>\Reminders\Images\{GUID}.png`: image of a reminder (copied by `Shell_CreateReminder`, deleted by `Shell_DeleteReminder`; `SHGetKnownFolderPath` flag 0x4000, token -1). The same file is deleted by [ReminderEvents.dll](./reminderevents.md#shelldismissreminder-sub_100025ac).

### Wallpaper

`Shell_SetCurrentWallpaper(path, isFile)`, `Shell_SetCurrentWallpaperAndProvider(path, x, isFile, y)` and `Shell_SetCurrentKidZoneWallpaper(path)`: when the path is a file (`isFile` ≠ 0, always for Kid's Corner), `sub_1000D8A4` checks it exists (`PathFileExistsW`, else E_INVALIDARG) and turns it into a shared file token: `DSCreateSharedFileToken(path, &params, 0, 0, &token)` with `params = { 2, 7, 1, 1, L"MobileUI", 0… }` (0xAC bytes). The token string (freed with `DSFreeString`) is sent instead of the path (RPC 14, 15 or 37). Otherwise the string is sent as is.

### Toasts

`Shell_PostMessageToast(t)`, `Shell_PostMessageToast2(t, a, b, c)` and `Shell_RaiseGameAchievementMessageToast(t)` call `sub_10015EC8(t, a, b, c, isAchievement)` (E_INVALIDARG if `t` is NULL), which sends the fields of the toast structure in RPC opnum 10 (`sub_10012704`): a GUID, two strings, two optional strings, two DWORDs, an optional string and a DWORD. The layout of the structure (+0x18 is logged by ETW) isn't decoded.

### Hardware buttons

`Shell_RegisterButtonPressCallback(button, callback)` and `Shell_UnregisterButtonPressCallback(button, callback)` (critical section `unk_1001E558`) use a process-wide listener (`GetButtonListener`, `sub_10007094`, object in `dword_1001E52C`):
- At first use, if the calling thread already has a CoreMessaging context (`CoreUIOpenExisting`), the listener connects on this thread (`sub_10007470`); otherwise it starts its own thread (`sub_10018FC8`) and +0x44 = 1.
- Connection: `CoreUICreate`, `CoreUIFactoryCreate`, then the endpoint `L"System\\ShellButtonRouterOutputEndpoint"` (router object at +0x18). With its own thread, it also creates the named events `ButtonHandler_Register_Proceed` and `ButtonHandler_Unregister_Proceed` and waits on them.
- Register: the callbacks are kept in a hash map button → list of callbacks (`AddRef` on the callback). The first callback of a button calls the router method +0x0C (subscribe). With the listener thread, the request is posted to it (`sub_100171B0` / `sub_10017170`) and the caller waits for the `…_Proceed` event.
- Unregister: `Release` and removal; the last callback of a button calls the router method +0x10; when the map is empty, the listener is stopped.

Errors: E_OUTOFMEMORY if the listener can't be created, E_INVALIDARG for a NULL callback, E_UNEXPECTED for an unknown button. The source file is `src\media\shell\product\shellchromeapi\dll\shellbuttonlistener.cpp`.

### Action dialogs

`Shl::ActionDialog::Create(importance, config, &dialog)` (3 overloads, one per config type):
1. `importance` > 2 → E_INVALIDARG.
2. Retail demo provisioning active (`sub_1000B9D8`) → 0x86606012.
3. Config checks (E_INVALIDARG): DWORD offsets 0x00/0x04 (title string, not empty), 0xBC/0xC0 (vector of 1 or 2 16-byte items: buttons ?), 0x44/0x48 (at most 128 16-byte items), 0x58 requires 0x54, 0xE8/0xEC (only with importance 2 and 0xF8/0xFC not empty).
4. Creates the dialog object (`sub_100165D4`: 0x7C bytes, `sub_10014AB8`, two events; fails with 0x800704D6 if the global state `dword_1001E780` is 5), copies the config (`sub_1001860C`: 0x120-byte copy, `sub_10018270`).
5. If `sub_1000C644(config +0x11C)` (not in do not disturb, or allowed, see [WNF](#wnf-states)): starts the dialog thread (`sub_1000E59C` → `sub_10017408`); otherwise calls the dialog method +0x18 (cancel ?) without showing it.

The dialog thread connects to the CoreMessaging endpoint `L"System\\ActionDialogManagerEndpoint"` and sends the dialog (type 0/1/2 at +0x6C selects the message builder: full screen, partial screen, picker). The returned object is a COM-like interface (vtable `+4` AddRef, `+8` Release); its other methods aren't analysed.

### System wait cursor

`SystemWaitCursorAPI::GetSystemWaitCursor(&p)` (`sub_100146C4`) creates a 0x54-byte object (vtable `off_10005CFC`) implementing `ISystemWaitCursor`; its thread (`sub_1001443C`) connects to the CoreMessaging endpoint `L"System\\SystemWaitCursorEndpoint"` (ETW events 40 / 41).

### ETW

Provider `{6A31956A-501D-4BFF-86C4-73013F2AB0A5}`, registered in `DllMain` (`EventRegister(…, sub_1000844C, &unk_1001E010, &qword_1001E4F0)`; enable bits in `dword_1001E600`, `dword_1001E680`, `dword_1001E700`).

| Event | Level | Opcode, task | Keyword | Written when |
|-------|-------|--------------|---------|--------------|
| 2, 3 | 5 | 1 / 2 (start / stop), 2 | 0x43 | Action dialog thread |
| 4, 5 | 5 | 1 / 2, 3 | 0x43 | `sub_10017364` (action dialog) |
| 6, 7 | 5 | 1 / 2, 3 | 0x43 | `sub_1000E418` (action dialog) |
| 9, 10 | 5 | 13, 14; 1 | 0x41 | `sub_1000C784`, `sub_1000C74C` |
| 12 | 3 | 0, 6 | 0x1 | `Shell_SetHardwareButtonRestrictedState` |
| 21 | 3 | 0, 7 | 0x1 | `Shell_RequestShutdownEx` |
| 30 | 4 | 0, 8 | 0x1 | `Shell_LaunchSessionByUriReset` |
| 40, 41 | 5 | 1 / 2, 9 | 0x20003 | System wait cursor thread |
| 45 | 4 | 0, 10 | 0x3 | `Shell_IdleTimerReset` |
| 63, 64 | 4 | 11, 12; 17 | 0x1 | `Shell_RegisterButtonPressCallback`, `Shell_UnregisterButtonPressCallback` |
| 65, 66, 67 | 4 | 13, 14, 15; 17 | 0x1 | Button listener register / unregister / `sub_10014B9C` |
| 200 | 1 (critical) | 0, 10 | 0x40000 | Fatal error of the button listener (`sub_1000C6A4`) |
| 10000 | 4 | 0, 10000 | 0x200000 | Action dialog objects (`sub_10014AB8`, `sub_100180C4`) |
| 10001 | 2 (error) | 0, 10000 | 0x400000 | Failed HRESULT with the source line (`sub_1000D01C`, `sub_1000CF28`, …), WNF read errors, reminder init errors |
| 10002 | 3 | 0, 10000 | 0x100000 | `sub_1000CF78` |
