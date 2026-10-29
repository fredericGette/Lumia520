## ShellChrome.dll

The "chrome" of the Windows Phone 8.1 shell: system tray, application bar, lock screen, hardware buttons, volume, toasts, reminders, wallpaper, Kid's Corner and driving mode, and the RPC server behind [ShellChromeAPI.dll](./shellchromeapi.md).  
`ShellChrome.dll` is a big UIX library (1.5 MB, 4042 functions, 157 exports). Its exports are called by the shell process that hosts it. `LaunchShellChromeServer` starts the shell RPC server `{8B111127-818E-4AE5-9788-7396504EF98F}`: its 80 procedures implement the `Shell_*` exports of ShellChromeAPI.dll, and almost every one checks a capability of the caller first. It's also the shell side of the reminders. It imports [ReminderEvents.dll](./reminderevents.md), which calls back `ProcessReminder` and `ProcessAccessoryReminderRequest`. It shows the reminder, then snoozes / dismisses it, and starts the program stored in the reminder (for the alarms, [Alarms_NoUI.exe](../applications/alarms_noui.md)). It publishes and reads about 40 WNF states (owner `SHL` mostly), creates the `AlarmLockIconTask` scheduled task, and drives the vibrator ([hwnvibradime.sys](../drivers/hwnvibradime.md)) for the haptic feedback of the buttons.  
The process that loads it isn't known (the shell UI host, it exports `UIXGetSchemaFactory` / `UIXSchemaUnloaded`, the entry points of a UIX schema called by `UIXMobile.dll`, as in [DateTimeCPLdll.dll](./datetimecpldll.md#exports)). Only the parts used by the other documented binaries are described in detail here: the RPC server, the reminders, the WNF states and the alarm-related tasks. The UI code (application bar, system tray, context menus, lock screen UI…) isn't analysed.

Location on the phone: `C:\Windows\System32\ShellChrome.dll` ? (the analysed file was extracted to `C:\Users\Public\ShellChrome.dll`).  

### Imports

| DLL | Functions |
|-----|-----------|
| RPCRT4.dll | Server: `RpcServerUseProtseqW`, `RpcServerInqBindings`, `RpcServerRegisterIf3`, `RpcEpRegisterW`, `RpcServerListen`, `RpcMgmtStopServerListening`, `RpcServerInqCallAttributesW`, `I_RpcBindingInqLocalClientPID`, `NdrServerCall2`. Client: `RpcBindingCreateW`, `RpcBindingBind`, `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW`, `RpcBindingFree`, `NdrClientCall2`, `NdrRpcSmClientAllocate/Free` |
| SecRuntime.dll | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor`, `RpcClientCapabilityCheck`, `CapabilityCheck`, `CreateProcessInChamber`, `OpenProcessForQuery`, `OpenProcessTokenForQuery`, `IsProductionConfiguration` |
| ReminderEvents.dll | `AddReminderPublishStateName`, `RemoveReminderPublishStateName`, `ShellSnoozeReminder`, `ShellDismissReminder` |
| ShellChromeAPI.dll | `Shell_IsDrivingModeActive`, `Shell_GetCurrentMode`, `Shell_GetCurrentLockState`, `Shell_IsLocked`, `Shell_IsDoNotDisturbModeActive`, `Shell_IsKidZoneEnabled`, `Shell_SetKidZoneEnabled`, `Shl::ActionDialog::Create` (partial screen) |
| BNSClient.dll | `BNSCNotifyDismiss`, `BNSCNotifySnooze`, `BNSCNotifyOpenApp` |
| ntdll.dll | WNF (`RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `RtlQueryWnfStateData`, `NtQueryWnfStateData`, `RtlPublishWnfStateData`), ALPC (`ZwAlpcConnectPort`, `ZwAlpcSendWaitReceivePort`, …), `WinSqm*`, `RtlNtStatusToDosError` |
| UIXn.dll, UIXMobile.dll | `UIXGetServices`; themes (`ThemeSetThemeOverride`, `ThemeSetHighContrastOverride`, `ThemeGetSystemScreenSize`, …), `GetResolutionWidth/Height` |
| CoreMessaging.dll, CoreUIComponents.dll | `CoreUICreate`, `CoreUIClientCreate`, `CoreUIFactoryCreate`, `MsgStringCreateShared`, `MsgRelease` |
| EMCLIENT.dll, EMSVCS.dll | `ExecutionModel::ApplicationUri`, `Rm*` resource manager, `CreateExecutionManager`, `CreateBackgroundWorkerManager` |
| NotificationQueueManager.dll | `NQM_Create`, `NQM_SendTileNotificationRequest`, `NQM_RemoveTile`, … |
| LASS_PROXY.dll | `LASSGetLockSettings`, `LASSProcessUserAuthentication`, `LASSProcessChangeCredential`, … (PIN / password of the lock screen) |
| policymanager.dll | `PolicyManager_GetDeviceLockPolicy_*`, `PolicyManager_GetExperiencePolicy_AllowScreenCapture`, `…_AllowCopyPaste` |
| PhoneAudio.dll, phoneom.dll | Volume and mute, call state |
| eventsnd.dll, WINMMBASE.dll | `PlayEventSound`, `PlayEventSoundWithEventSettings`, `StopEventSounds`, `PlaySoundExW` |
| wpSensors.dll | `SensorOpen`, `SensorStart`, `SensorGetData`, … (proximity ?) |
| CompClient.dll | `CaptureScreen`, `CreateCaptureScreenEvent` (screenshots) |
| ZMediaqueueClient.dll, zmedialib_client.dll, MediaService.dll | Media queue and library |
| ARLens.dll, SpeechUXStub.dll, ChamberProf.dll, dsclient.dll, XmlLite.dll | Lens picker, Cortana toasts, chamber paths, shared files, toast XML |
| WPCOREUTIL.dll | `SHGetKnownFolderPath`, `SHGetSpecialFolderPathW`, `ResetPhone` |
| POWRPROF.dll, api-ms-win-power-setting | Power settings (screen timeouts) |
| api-ms-win-devices-config, api-ms-win-core-io | `CM_Get_Device_Interface_ListW`, `DeviceIoControl` (vibrator) |
| api-ms-win-core-registry-l1/l2 | `RegOpenKeyExW`, `RegGetValueW`, `RegSetValueExW`, `RegNotifyChangeKeyValue`, … |
| api-ms-win-service-* | `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `QueryServiceStatus`, `NotifyServiceStatusChangeW`, `SubscribeServiceChangeNotifications` |
| api-ms-win-security-* | `LookupPrivilegeValueW`, `AdjustTokenPrivileges` (`SeShutdownPrivilege`) |
| Other api-ms-win-core-* | Threads, thread pool, synchronisation, heap, files, paths, time, locale, COM, OLE automation strings, ETW |
| msvcrt.dll | CRT, C++ exceptions, `_initterm`, `__dllonexit` |

The msvcrt, rtlsupport, errorhandling, debug and libraryloader imports are the Visual C++ DLL CRT, C++ exception and `/GS` security cookie code. Most DLLs except ntdll, RPCRT4 and the API sets are delay-loaded (`ResolveDelayLoadedAPI`; the thunks are at 0x10057210…0x10058620).

### Dependencies

Files used other than the static imports (the delay-loaded DLLs are in the [Imports](#imports) table).

| File | How | Use |
|------|-----|-----|
| `ShellControls.dll` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)` (`sub_1006E34C`, name set by `sub_1007F34C`) | Resource DLL of the localized strings (`StringRes::LoadStringW`, `sub_10077AAC`) |
| `ShellFrameRes.dll` | `LoadLibraryW` (`sub_1005DCF8`) | Resources of the shell frame ? |
| DLL named by `HKLM\System\Features\OverrideUI` | `LoadLibraryExW(LOAD_LIBRARY_AS_DATAFILE)` (`sub_1005ECB8`, object built by `sub_1006BE8C`) | Override of the UI strings (`LoadStringW` in `sub_1006692C`) ? |
| DLL named by `HKLM\System\Features\Lockdown` | `LoadLibraryW` (`sub_1005F390`) + `GetProcAddress` | Lockdown manager: `LockDownMgrIsActionCenterEnabled` (`sub_10060D2C`), `LockDownMgrLaunchAutoRunSession`, `LockDownMgrGetStartSessionUri`, `LockDownMgrSynchronizeWithService`, `LockDownMgrGetCurrentLockdownProfile` (`sub_1006139C`) |
| `<known folder {7CF8AD76-641E-4B26-B5B5-A978094810CA}>\appcorner\appcorner.dll` | `SHGetKnownFolderPath` + `LoadLibraryW` (`sub_100677DC`) + `GetProcAddress` | App Corner: `LaunchOriginalMode` (`sub_1007B914`) |
| `Capture.dll` | `LoadLibraryW` + `GetProcAddress` (`sub_10082C34`) | Screenshots: `WriteScreenshotToFile`, `ResolveResourceName`, `EncodeUrlString` |
| `PacManMock.dll` | `LoadLibraryExW` + `GetProcAddress` (`sub_100708AC`) | Test replacement of the PacMan COM client (same exports as in [Alarms_NoUI.exe](../applications/alarms_noui.md#com); `EnablePacManMock` registry value ?) |
| `emclient.dll` | `GetModuleHandleW` + `GetProcAddress` (`sub_1005E4F8`) | `SHTerminateProcessForOOM` |
| `<MobileUI chamber folder>\SendToMediaLib.exe` | `GetChamberFolderPath(L"MobileUI")` + `CreateProcessW` (`sub_10071E48`, called by the screenshot code `sub_10084A00`) | Adds the new screenshot to the media library ? |
| `c:\Programs\Alarms\Alarms_NoUI.exe` | `CreateProcessInChamber` (`sub_100720B4`) | `TimeChanged` command, see [Alarms_NoUI command lines](#alarms_noui-command-lines) |
| Program stored in a reminder | `CreateProcessInChamber` (`DismissReminder`, `sub_10065884`) | See [Reminders](#reminders) |
| `<CSIDL_MYPICTURES>\Screenshots\wp_ss_<YYYYMMDD>_<NNNN>.png` | `SHGetSpecialFolderPathW(39)`, `CreateDirectoryW`, `CreateFileW` (`sub_10083004`, `sub_1007F49C`) | Screenshots |
| `<CSIDL_SYSTEM>\shutter.wav` | `SHGetSpecialFolderPathW(37)` + `PlaySoundExW` (`sub_1007F280`) | Sound of a screenshot |
| `C:\Programs\CommonFiles\Sounds\Alarm-01.wma`, `Alert_calendar.wma`, `Ring01.wma`, `Alert-08.wma`, … | `GetFileAttributesExW` (`sub_10052CCC`) | Default sounds when the file of `Software\Microsoft\EventSounds\Sounds\<category>` is missing |
| Sound files of `Software\Microsoft\EventSounds\Sounds` / `Shell\SoundsSettings` | `PlayEventSound*` (eventsnd.dll), toast XML `<audio src="file:///…">` (`sub_10084828`) | Alarm, reminder, notification, key press, screen on / off sounds |
| `<known folder {F1B32785-6FBA-4FCF-9D55-7B8E7F157091}>\Wallpapers\cwp….cwp` | `CreateDirectoryW` (`sub_10086D6C`), `DSMoveFromSharedFile` (`sub_1008D62C`, name from `sub_10071768`), `FindFirstFileW("cwp*")` (`sub_10092214`), `DeleteFileW` (`sub_1009B81C`) | Wallpapers set through the RPC server; the old ones are deleted. See [Wallpaper](#wallpaper) |
| `<known folder {F1B32785-…}>\KidZoneWallpapers` | `CreateDirectoryW` (`sub_10072B48`), `DeleteFileW` of `Family\KidZone\Customization\WallpaperPath` (`sub_10080A5C`) | Kid's Corner wallpaper |
| `DefaultLockScreen.jpg` | `sub_10086478` | Default lock screen image |
| Lock screen extension XML of an application | `SHCreateStreamOnFileW` + XmlLite (`sub_10086A60`) | `x:Extension` with `AppID`, `Args`, `DisplayName`, `IconPath`, `TaskSwitcherResume` (lock screen apps) |
| Vibrator device interface `{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}` | `CreateFileW` (`sub_1005164C`) | [hwnvibradime.sys](../drivers/hwnvibradime.md), see [Haptic feedback](#haptic-feedback) |
| PacMan server, CLSID `{B9E511FC-E364-497A-A121-B7B3612CEDCE}` | `CoCreateInstance` (`sub_10065EE4`, `sub_1007008C`…`sub_100707F8`, …) | `IPMEnumerationManager`, `IPMApplicationInfo` (installed applications, tiles) |
| MMDevAPI, CLSID `{BCDE0395-E52F-467C-8E3D-C4579291692E}` (`MMDeviceEnumerator`) | `CoCreateInstance` (`sub_10053F44`) | Audio endpoints (volume limit warning) |
| COM servers `{317D06E8-5F24-433D-BDF7-79CE68D8ABC2}`, `{228826AF-02E1-4226-A9E0-99A855E455A6}`, `{D0DF0C7D-33BF-4E04-9B11-B1D7AE572EED}`, `{27949969-876A-41D7-9447-568F6A35A4DC}`, `{E8D66722-1CBB-4605-9638-B248A200CC2F}` | `CoCreateInstance` (`sub_10039B18`, `sub_100534A4`, `sub_10054894`, `sub_10084A00`, `sub_10070BD8`) | ? (server DLLs unknown; `{D0DF0C7D-…}` is also created by the PacMan client library of [Alarms_NoUI.exe](../applications/alarms_noui.md#dependencies)) |

### Exports

The decompiled prototypes of the exports are of little use (`__fastcall` with 1 to 4 integer arguments), so the parameters are given only when they were checked. Most UI exports take the global shell chrome object (`GetShellChrome`, `sub_10045AAC`: built on first use under the critical section `unk_100AD52C`, 416 bytes, `sub_10056798`; reference counted, released by `sub_10044604`) and post the request to the UI thread (`sub_10049884` / `sub_100436E0`).

| Ordinal | Name | Address | Comment |
|---------|------|---------|---------|
| 65 | `LaunchShellChromeServer` | 0x1004DD84 | Starts the [RPC server](#rpc-server) |
| 139 | `StopShellChromeServer` | 0x1005E684 | `RpcMgmtStopServerListening(NULL)` |
| 73 | `ProcessReminder` | 0x1009A39C | `(REMINDER *r, DWORD flags, const WNF_STATE_NAME *name)`, called by ReminderEvents.dll, see [Reminders](#reminders) |
| 72 | `ProcessAccessoryReminderRequest` | 0x10092704 | `(const GUID *id, BOOL snooze, DWORD minutes)`, called by ReminderEvents.dll, see [Reminders](#reminders) |
| 26 | `CreateNewReminder` | 0x100965E4 | `(REMINDER *r, DWORD flags, const WNF_STATE_NAME *name)`: shows the reminder |
| 25 | `CreateNewMessageToast` | 0x100887FC | Toast, used by RPC opnum 10 |
| 140, 141 | `SystemTimeChanged`, `SystemTimeFormatChanged` | 0x10093770, 0x1009372C | Clock update, then starts `Alarms_NoUI.exe TimeChanged` (see [Alarms](#alarms_noui-command-lines)) |
| 157 | `UserLocaleChanged` | 0x100936F4 | Date / time formats (`dd MMMM`, `MM/dd`, `dddd, MMMM dd`, `H:mm:ss`) |
| 21 | `ShellStartReadyEvent` | 0x10054720 | Shell started (`sub_10054754`) |
| 15 | `PromptUnlock` | 0x10077580 | Also RPC opnum 1 |
| 4, 5, 11, 82 | `DoNotDisturbModeActiveChanged`, `DrivingModeActiveChanged`, `KidZoneEnabledChanged`, `RingerVibrateChanged` | | Notifications of a state change, no parameter |
| 13, 14, 70 | `NotifyEnteringUserIdle`, `NotifyScreenPowerState`, `NotifyMonitorStateChange` | | Screen / idle notifications |
| 43…64, 9 | `InvokeBack`, `InvokeStartPress`, `InvokeSearch`, `InvokeSearchPressAndHold`, `InvokeCamera`, `InvokePower`, `InvokePowerHeld`, `InvokeVolumeUp/Down`, `InvokeVolumeUp/DownPressAndHoldPulse/Release`, `InvokeHeadsetTap/DoubleTap/TripleTap/PressAndHold`, `InvokeOEMCustomButton`, `InvokeOEMCustomButtonApp`, `InvokeRingerChanged`, `InvokeScreenCapture`, `InvokeWrongScreenCaptureKeyCombo`, `InvokeTaskSwitcher` | | Hardware buttons. 62 and 63 (`…UpPressAndHoldPulse` / `…UpPressAndHoldRelease`) have the same address 0x10093B18 |
| 2 | `ChangeVolumeRelative` | 0x1009C0DC | Also RPC opnum 35 (`sub_1009B25C`) |
| 7, 8 | `HandleLensPickerForButtonPress`, `InvokeLensPicker` | 0x10085958, 0x100859AC | Lens picker (RPC opnum 2) |
| 142 | `TurnScreenOn` | 0x1003BD80 | |
| 12 | `LockScreen_GetNotificationsSnapshot` | 0x100942C8 | RPC opnum 11; adds the icons `lock.alarmset.png`, `lock.drivemode.png`, `systray.donotdisturb.png` |
| 6, 18 | `GetNotificationsAboveLock`, `SetNotificationsAboveLock` | 0x1003CFE4, 0x100933FC | Registry `ActionCenter\AllowNocenterAboveLock` (RPC opnums 70, 71) |
| 23, 77, 97, 134 | `AddOverlay`, `RemoveOverlay`, `SetDebugOverlay`, `SetTestScene` | | Test overlays (RPC opnums 31…34) |
| 40, 138 | `HideHighlightCursor`, `ShowHighlightCursor` | 0x10077160, 0x1007717C | Accessibility (RPC opnums 63, 64) |
| 3, 22 | `DiagnosticHook_GetShellState`, `TestHook_GetCurrentDeviceLockTypesFromChrome` | 0x1007E55C, 0x1007E990 | RPC opnums 62, 61 |
| 1 | `AutomationCallShellFrame` | 0x1007702C | |
| 66 | `LaunchUif` | 0x1008E6BC | |
| 78…81 | `RequestApplicationLaunch`, `RequestApplicationLaunchGeneric`, `RequestModernApplicationLaunch`, `RequestChaseUriFromNocenter` | | Application launch (RPC opnums 38…44) |
| 27…30, 39, 41, 42, 24, 75, 76, 85…95, 145…151, 153, 154 | `DisplayApplicationBar`, `InsertApplicationBarItem`, `SetApplicationBar*`, `UpdateApplicationBarItem*`, `DisplayContextMenu`, `InsertContextMenuItem`, `UpdateContextMenuItem*`, … | | Application bar and context menus of the applications |
| 112…133, 155, 156, 71 | `SetSystemTray*`, `SetSystemTrayIcon*`, `UpdateSystemTrayLeftStack*`, `PerformSystemTrayIconColorOverlayAnimation` | | System tray |
| 105…108, 136, 137, 38 | `SetProgIndicator*`, `SetWaitCursorText`, `SetWaitCursorVisible`, `GetWaitCursorVisible` | | Progress indicator, wait cursor |
| 16, 19, 20 | `SystemWaitCursorAPI::SetDismissConditions`, `::SetText`, `::SetVisible` | 0x10096138, 0x10096174, 0x100961E4 | Server side of the system wait cursor of ShellChromeAPI.dll ? |
| 31…37, 84, 103, 109, 110, 152 | `GetChromeVisibleRegion`, `GetNavigationBarHeight`, `Get/SetIsNavigationBarVisible`, `GetLockScreenVisible`, `GetShellObscurity`, `GetSipVisbilityChange*`, `SetAdjustVisibleRegionForCallProgress`, `SetLetterboxHeight`, `SetShowingProtectedContent`, `SetSuppressMediaControls`, `UpdateClipboardControls` | | Layout of the chrome |
| 98, 99, 135, 100, 102, 104 | `SetHardwareButtonsDisabled`, `SetHighContrastOverride`, `SetThemeOverride`, `SetIsMangoOrEarlierApp`, `SetIsSilverlight8_0OrEarlierApp`, `SetOverlayIsMaximized` | | |
| 10, 67, 68, 69, 74, 83, 96, 17, 111 | `IsQuickSettingsUp`, `NotifyApplicationConnectedStateChanged`, `NotifyApplicationPrepareForCoordinatedAnimation`, `NotifyDismissed`, `RegisterDataModel`, `SaveApplicationScreenShot`, `SetChromeListener`, `SetMobileUICallback`, `SetSystemClockReady` | | |
| 143, 144 | `UIXGetSchemaFactory`, `UIXSchemaUnloaded` | 0x1005096C, 0x1005FD80 | UIX schema of the library |

### Startup

`start` (`_DllMainCRTStartup`, 0x10058288): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then the usual `dllmain_dispatch` (`sub_10057F94`: CRT init with `_initterm`, then `DllMain`).  
`DllMain` (`sub_100646BC`) only registers the main ETW provider `{9F79511C-06AD-4812-B18B-90006088D2CA}` on `DLL_PROCESS_ATTACH` (`McGenEventRegister`, `sub_1005383C`) and unregisters it on `DLL_PROCESS_DETACH` (`sub_1005F4A0`). The rest is started by the host through the exports (`LaunchShellChromeServer`, the shell chrome object, `sub_1009E0B8` at shell start-up).

### RPC server

`LaunchShellChromeServer` (0x1004DD84):

1. `sub_1004DF90` (unknown initialisation).
2. `RpcServerUseProtseqW(L"ncalrpc")` with the transient security descriptor `DefaultRpcAccess` (`QueryTransientObjectSecurityDescriptor(8, …)`), then `RpcServerInqBindings`.
3. `RpcServerRegisterIf3` of the interface at 0x10008BC8, flags 0x29 (`AUTOLISTEN | ALLOW_SECURE_ONLY | ALLOW_LOCAL_ONLY`), max calls 1234, with the security descriptor `RPCShellChrome\Interface` (`QueryTransientObjectSecurityDescriptor(9, …)`).
4. `RpcEpRegisterW` with the bindings (dynamic endpoint).
5. `RpcServerListen(1, 1234, TRUE)`; error 1713 (already listening) is ignored.

RPC errors are returned as `0x80010000 | code`, SecRuntime errors as `NTSTATUS | 0x10000000`.

The clients ([ShellChromeAPI.dll](./shellchromeapi.md#shell-rpc-interface)) find it with the endpoint mapper and require the server security descriptor `RPCShellChrome\Server`.

Interface `{8B111127-818E-4AE5-9788-7396504EF98F}` version 0.0 (`RPC_SERVER_INTERFACE` at 0x10008BC8, `MIDL_SERVER_INFO` at 0x10008BA8, server routines at 0x10007AF0, proc format string at 0x10007C32). The parameters are the ones of the [client table](./shellchromeapi.md#shell-rpc-interface); the first parameter of every routine is the binding handle. Each routine checks the capability with `RpcClientCapabilityCheck` (or its wrapper `sub_1005E644`) and returns its HRESULT if it's missing. "Wait init" = `WaitShellFrameInitialized` (`sub_1003B4E8`: waits on the named event `ShellFrame_Framework_Initialized`). "Caller product ID" = `GetCallerProductId` (`sub_10070E40` / `sub_10078BB4`: `RpcServerInqCallAttributesW` → client PID → `CreateExecutionManager` → product ID of the calling application).

| Opnum | Routine | Capability | ShellChromeAPI export | Implementation |
|-------|---------|------------|-----------------------|----------------|
| 0 | `sub_100807BC` | `ID_CAP_DEVICE_LOCK` | `Shell_Lock` | `sub_10049B88(0, 8)` (RPC to `{85F9809B-…}`, see [RPC clients](#rpc-clients)), then `sub_1006DD10(0)` |
| 1 | `sub_1007EAEC` | `ID_CAP_DEVICE_LOCK`, or allowed by `sub_10070FC8` | `Shell_Unlock` | `PromptUnlock()` |
| 2 | `sub_1008818C` | – | `Shell_InvokeLensPicker` | `InvokeLensPicker(guid)` |
| 3 | `sub_10082768` | – | `Shell_IsLockPasswordSet` | `sub_100774EC`; E_POINTER (0x80004003) for a NULL pointer |
| 4 | `sub_1007EA98` | `ID_CAP_DEVICE_LOCK` | `Shell_LockAndShowKidZoneLock` | `sub_1006DBFC(0)` |
| 5 | `sub_1007E5C8` | `ID_CAP_DEVICE_LOCK` | `Shell_LoadLockdownResources` | `sub_1006D3CC(0)` |
| 6 | `sub_10097DF8` | – | `Shell_GetCurrentLockdownProfile` | `sub_1005F064` |
| 7 | `sub_100970B4` | `ID_CAP_DRIVE_MODE_ADMIN` | `Shell_StartDrivingMode` | Waits on the WNF state `OS` 7 and shows a confirmation [action dialog](./shellchromeapi.md#action-dialogs) (strings 12200…12203) unless already in driving mode; publishes `SHL` 36 (`sub_10070F78`) |
| 8 | `sub_10070F14` | `ID_CAP_DRIVE_MODE_ADMIN` | `Shell_EndDrivingMode` | Publishes `SHL` 36 |
| 9 | `sub_10055970` | `ID_CAP_DEVICE_LOCK` | `Shell_SetLockScreenAlarmIndication` | Posted to the UI thread (`sub_10049884`): alarm icon of the lock screen |
| 10 | `sub_1008E9D8` | `ID_CAP_SHELL_NOTIFICATION_CLIENT` or `ID_CAP_INTEROPSERVICES` | `Shell_PostMessageToast*` | Builds a `ToastText02` XML (`<toast launch="%s"><visual><binding template="ToastText02">…`, `<audio src="file:///%s" />` or `ms-winsoundevent:legacy-notification.%s`) for the caller product ID, `CreateNewMessageToast` |
| 11 | `sub_100995C8` | `ID_CAP_SHELL_DEVICE_LOCK_UI_API` | `Shell_LockScreen_GetNotificationsSnapshot` | `LockScreen_GetNotificationsSnapshot` |
| 12 | `sub_10098644` | `ID_CAP_DEVICE_LOCK_ADMIN` | `Shell_UpdateAuthenticationData` | |
| 13 | `sub_1007EB3C` | `ID_CAP_DEVICE_LOCK_ADMIN` | `Shell_RefreshLockLASSData` | `sub_10048408` |
| 14 | `sub_1009A688` | – (caller product ID) | `Shell_SetCurrentWallpaper` | Wait init, then [wallpaper](#wallpaper) |
| 15 | `sub_1009A5C0` | `ID_CAP_DEVICE_LOCK` | `Shell_SetCurrentWallpaperAndProvider` | |
| 16, 17 | `sub_100800C0`, `sub_10080074` | – (caller product ID) | `Shell_GetCurrentWallpaper`, `Shell_IsActiveWallpaperProvider` | |
| 18 | `sub_1009B4F4` | – (caller product ID) | `Shell_SetAsActiveWallpaperProvider` | Confirmation action dialog, `DefaultLockScreen.jpg` |
| 19 | `sub_10049B88` | – | `Shell_IdleTimerReset` | |
| 20 | `sub_1007EA5C` | `ID_CAP_DEVICE_LOCK` | `Shell_SetShowNowPlayingMediaArt` | |
| 21, 22 | `sub_100809FC`, `sub_1007B794` | `ID_CAP_SHELL_OEM_ADMIN`, – | `Shell_SetCoverAutoUnlock`, `Shell_GetCoverAutoUnlock` | Registry `OEM\SmartCoverSettings\AutoUnlock` |
| 23 | `sub_1009AF04` | `ID_CAP_BUILTIN_TCB` | `TestHook_InitializeSmartCover` | `sub_1009A330`: reads and subscribes to `SHL` 52 |
| 24, 25, 26 | `sub_10097FAC`, `sub_10097F64`, `sub_10091CB4` | `ID_CAP_SHELL_DEVICE_LOCK_UI_API` | `Shell_RegisterLockApp`, `Shell_UnregisterLockApp`, `Shell_IsLockAppRegistered` | Registry `LockAppSettings` (`LockAppAumId`, `ProductId`), confirmation action dialog, task `LockScreen_Application` |
| 27, 28, 29 | `sub_1009834C`, `sub_10098304`, `sub_10091C44` | `ID_CAP_SHELL_DEVICE_LOCK_UI_API` | `Shell_RegisterSystemOverlayApp`, `…Unregister…`, `…IsSystemOverlayAppRegistered` | Registry `OverlayAppSettings` (`OverlayAppAumId`, `ProductId`, `DisplayName`, `IconPath`, `OverlayTaskSwitcherResumeAppArgs`), task `SystemOverlay_Application` |
| 30 | `sub_1009E088` | `ID_CAP_DEVICE_LOCK` | `Shell_RefreshLockScreenNotifications` | |
| 31…34 | `sub_10085208`, `sub_100851C0`, `sub_10085178`, `sub_10085130` | `ID_CAP_SHELL_TEST_CLIENT` | `Shell_SetTestScene`, `Shell_SetDebugOverlay`, `Shell_AddOverlay`, `Shell_RemoveOverlay` | Wait init, then the export of the same name |
| 35 | `sub_1009D158` | `ID_CAP_BLUETOOTH_ADMIN` | `Shell_AdjustVolume` | `sub_1009B25C` (also `ChangeVolumeRelative`) |
| 36, 37 | `sub_1007FA90`, `sub_10083D04` | `ID_CAP_KIDZONE_CUSTOMIZATION` | `Shell_SetKidZoneDisplayName`, `Shell_SetCurrentKidZoneWallpaper` | Registry `KidZone\Customization` (`DisplayName`, `WallpaperPath`) |
| 38, 39 | `sub_1007FD00`, `sub_1007FCB4` | – (only if `Shell_IsKidZoneEnabled`) | `Shell_NavigateToErrorPageOn…InKidZone` | `RequestApplicationLaunch(L"app://5B04B775-356B-4AA0-AAF8-6491FFEA5803/ErrorOnBlockedLaunchInKidZone")` / `…/ErrorPageOnPinShellTileFailureInKidZone` |
| 40 | `sub_10038B40` | `ID_CAP_ACCESSIBILITY_CLIENT` | `Shell_CreateAutomation` | |
| 41, 42 | `sub_100834F8` → `sub_1007FC68` | `ID_CAP_SHELL_LAUNCH_SESSION` | `Shell_LaunchSessionByUri`, `…Ex` | Wait init, `RequestApplicationLaunch` |
| 43 | `sub_1007FF40` | `ID_CAP_SHELL_LAUNCH_SESSION` + `ID_CAP_SHELL_RESET_NAVIGATION` | `Shell_LaunchSessionByUriReset` | |
| 44 | `sub_1007FBF4` | same | `Shell_LaunchSessionGeneric` | `RequestApplicationLaunchGeneric` |
| 45 | `sub_1007E7B4` | `ID_CAP_SHELL_RESET_NAVIGATION` | `Shell_RequestBackstackReset` | |
| 46 | `sub_1007E764` | `ID_CAP_PUBLISH_OOBE_STATE` | `Shell_ExitOobeStateAndContinueRunningApp` | |
| 47, 48, 49 | `sub_1007FB98`, `sub_1007FB50`, `sub_1003B388` | `ID_CAP_SHELL_LAUNCH_SESSION` | `Shell_LaunchModernNfcEventSession`, `Shell_LaunchWalletSessionByUri`, `Shell_LaunchSpeechSessionByUri` | |
| 50…53 | `sub_1008DD30`, `sub_1008DCD8`, `sub_1008DBF8`, `sub_1008DBA0` | `ID_CAP_DEVICE_LOCK` | `Shell_Get/SetLockGraceTime`, `Shell_Get/SetScreenIdleTime` | Registry `Shell\Timeouts` (`sub_1004D738`) |
| 54, 55 | `sub_1008DC54`, `sub_1008DB1C` | `ID_CAP_DEVICE_LOCK` | `Shell_GetLockGraceTimeWValidList`, `Shell_GetScreenIdleTimeWValidList` | |
| 56 | `sub_100985D8` | `ID_CAP_DEVICE_LOCK` | `Shell_EnableUserIdleTimeouts` | |
| 57 | `sub_10070D0C` | `ID_CAP_SHELL_NOTIFICATION_CLIENT` | `Shell_CreateReminder` | [ReminderEvents.dll](./reminderevents.md#addreminderpublishstatename--removereminderpublishstatename)`!AddReminderPublishStateName(&name)` |
| 58 | `sub_10070CC8` | `ID_CAP_SHELL_NOTIFICATION_CLIENT` | `Shell_DeleteReminder` | `ReminderEvents!RemoveReminderPublishStateName(&name)` |
| 59 | `sub_1007E9E0` | – | `Shell_TurnScreenOn` | Wait init, posted to the UI thread |
| 60 | `sub_1007E600` | `ID_CAP_BUILTIN_SHUTDOWN` | `Shell_RequestShutdownEx` | Wait init, `sub_1006D480` |
| 61, 62 | `sub_10082720`, `sub_10082688` | `ID_CAP_BUILTIN_TCB` | `TestHook_GetCurrentDeviceLockTypes`, `DiagnosticHook_GetCurrentShellState` | Exports 22 and 3 |
| 63, 64 | `sub_1007E718`, `sub_1007E6D8` | `ID_CAP_ACCESSIBILITY_CLIENT` | `Shell_ShowHighlightCursor`, `Shell_HideHighlightCursor` | Exports 138 and 40 |
| 65, 66, 67 | `sub_10082630`, `sub_100825B8`, `sub_10082574` | `ID_CAP_NAVIGATIONBAR_ADMIN` | `Shell_Set/GetNavigationBarVisible`, `Shell_UpdateNavigationBarSettings` | Registry `Shell\NavigationBar` |
| 68, 69 | `sub_1007E684`, `sub_1007E64C` | `ID_CAP_QUICK_SETTINGS` | `Shell_UpdateQuickSettingsPluginInfo`, `Shell_LaunchQuickSettingsPluginCPL` | |
| 70, 71 | `sub_1007BD50`, `sub_10098594` | `ID_CAP_DEVICE_LOCK_ADMIN` | `Shell_Get/SetNotificationsAboveLock` | Exports 6 and 18 |
| 72 | `sub_10097E34` | `ID_CAP_ORIENTATION_LOCK` | `Shell_LockOrientation` | Publishes `SHL` 42 (`sub_10071D8C`) |
| 73, 74, 75 | `sub_1009ACD0`, `sub_1009A4A8`, `sub_1009A454` | `ID_CAP_SHELL_DEVICE_LOCK_UI_API` | `Shell_GetLockPinpadHeight`, `Shell_BeginUnlock`, `Shell_EndUnlock` | |
| 76, 77, 78 | `sub_10097F4C`, `sub_100982EC`, `sub_1009A8D0` | – | `Shell_EnableLockApp`, `TestHook_EnableOverlayApp`, `Shell_RaiseToastNotifications` | `sub_10093358`, `sub_1009338C`, `sub_10092FE8` |
| 79 | `sub_10070C98` | – | `Shell_GetSystemScreenSize` | `UIXMobile!ThemeGetSystemScreenSize` |

"–" means that no capability check was found in the routine (it may be done by a callee). The errors are logged with the source line number (`sub_1004F3E0`, ETW).

### RPC clients

| Interface | Binding | Opnums used | Use |
|-----------|---------|-------------|-----|
| `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` v2.0 `ITaskSchedulerSvcRpc` (stub descriptor 0x10009418) | `sub_1003D138`: the same code as [ReminderEvents.dll](./reminderevents.md#rpc) (`ITaskSchedulerSvcRpc\Server`, LRPC, packet privacy, 3 tries) | 0 (`sub_100559E8`, create task), 4 (`sub_10060F34`, close an enumeration context ?) | [AlarmLockIconTask](#alarmlockicontask) |
| `{85F9809B-3B25-4EEB-8160-FA4A60B80746}` v0.0 (stub descriptor 0x100094F8) | `sub_10053694`: `RpcStringBindingComposeW(NULL, L"ncalrpc", NULL, NULL…)`, `RpcBindingSetAuthInfoExW(level 6, service 10, QoS identify)`, with `SeShutdownPrivilege` enabled during the connection (`sub_10060FA0`); then registers the ETW provider `{5C103042-…}`. Binding in `dword_100AD41C`, context handle `dword_100AD428` | 1 (`sub_10049BC0`: `[in]` context handle, `[in] small`; retried once after reconnecting on 0x80010106), 4 (`sub_10060F34`: close the context handle) | Called by `Shell_Lock` (opnum 0) and `Shell_IdleTimerReset` (opnum 19) via `sub_10049B88` when the WNF state `OS` 7 says so. The server isn't known (power manager ?) |
| `{A33A5C51-D8DC-4F1E-8B55-D5B5D00BF2F1}` v0.0 (stub descriptor 0x10008D68) | `sub_1006FB6C`: `RpcBindingCreateW` (LRPC, no endpoint), packet privacy, `ServerSecurityDescriptor` from `QuickSettingsSvcRpc\Interface`; rebinds once on 0x800106BF / 0x800106BE | 0 (`sub_10065BD0`, no parameter), 1 (`sub_10065B68`, 3 × `[in] long`) | Quick settings service |

There is also an ALPC client of `\PdcPort` (`sub_10065FD0`, `ZwAlpcConnectPort`): the power dependency coordinator.

### Reminders

ReminderEvents.dll (loaded through the imports) gives every reminder that must be shown to `ProcessReminder`, and the accessory requests to `ProcessAccessoryReminderRequest`. The reminder structure is the version 5 structure of [ReminderEvents.dll](./reminderevents.md#reminder-data). The flags are `reminder+0x10 | reminder+0x14`, plus 0x800 set by ReminderEvents.dll.

**ProcessReminder(r, flags, name)** (0x1009A39C):

1. Unless flag 0x800 is set, checks the two times of the reminder (+0x18 and +0x28, local if flag 0x1000) with `CheckReminderTimes` (`sub_1007B958`); if it returns 0, calls `DismissReminder(program (+0xA8), cmdLine (+0xAC), flags, r, name)` (`sub_10065884`) and returns its result.
2. Otherwise calls `CreateNewReminder(r, flags, name)`.
3. If that succeeds and flag 0x1 isn't set, publishes the GUID of the reminder (16 bytes) in the WNF state `WNF_SHL_49` (0x418A063EA3BD8875).

`CheckReminderTimes` (`sub_1007B958`, disassembly only) compares the two `SYSTEMTIME`s with the current time: when it returns 0 (reminder too old ?) the reminder is dismissed without being shown.

**DismissReminder(program, cmdLine, flags, id, name)** (`sub_10065884`):

- Flag 0x2: notifies the dismissal to BNSClient.dll (`BNSCNotifyDismiss(id)`, accessory ?), then calls `ShellDismissReminder(id, name)` of ReminderEvents.dll (flag 0x1 isn't checked).
- Else flag 0x1: starts the program of the reminder with its command line (`CreateProcessInChamber`, `STARTUPINFOW` of 0x44 bytes), closes the handles and returns the HRESULT (no `ShellDismissReminder`).
- Neither flag: calls `ShellDismissReminder(id, name)`.

For an alarm, [Alarms_NoUI.exe](../applications/alarms_noui.md#shell_createreminder-parameters) sets +0x14 = 1, and the program / command line are `c:\Programs\Alarms\Alarms_NoUI.exe ReminderDismissed <index>`: that's how the alarm is reprogrammed after it rang.

**CreateNewReminder(r, flags, name)** (0x100965E4, disassembly only):
- If the shell object +0x124 is set (another reminder / call in progress ?): `ShellSnoozeReminder(r, 1)` and nothing is shown.
- Otherwise it creates the reminder UI object (`sub_10080500`, 0xC8 bytes) and copies into it the strings of the reminder: +0x40 (text), +0x44 (sound), +0x54 (image), +0x58…+0x6C, +0x7C, +0x80, +0x90, +0x94, +0xA4, and the 5 launch fields +0xA8…+0xB8.
- The ring time is reminder +0x28 (`SystemTimeToFileTime`, converted to local time if flags & 0x1000; current local time if invalid), stored at UI object +0x88.
- Flag 1 (alarms): title = resource string 10014 (0x271E, "Alarm" ?), type 0, no timeout; snooze time = DWORD at +4 of the custom data (+0x48) if its size (+0x4C) is ≥ 8, else 10 (minutes ?, the default snooze of Alarms_NoUI.exe is 10).
- Otherwise: title = reminder +0x3C; flag 4 → type 2, flag 8 → type 3 (`sub_1007CBB4`), else type 1. Without flag 0x800 and with a ring time in the future, the reminder times out after 0x3840 (14400, seconds ?); else it has no timeout (-1).
- Flag 2 → `sub_10074310(1)`.

| Bit | Meaning (from the code) |
|-----|-------------------------|
| 0x0001 | Start the program of the reminder when it's dismissed; "alarm" UI (title string 10014, snooze time from the custom data, no timeout); don't publish `SHL` 49; `SHL` 47 / 48 instead of 45 / 46 on snooze / dismiss |
| 0x0002 | Notify `BNSClient` on dismiss (`BNSCNotifyDismiss`) and snooze (`BNSCNotifySnooze`) |
| 0x0004, 0x0008 | Type of the reminder UI (2, 3) ? |
| 0x0800 | Set by ReminderEvents.dll (Task Scheduler opnum 5 info bit 0x10): show without time check, no timeout |
| 0x1000 | The times of the reminder are local times |

**Snooze / dismiss from the UI**: `sub_10097A78` (snooze): if flags & 2, `BNSCNotifySnooze(&id, minutes)`; then publishes the 16-byte GUID of the reminder (UI object +0xAC) in `SHL` 47 (flags & 1) or `SHL` 45. `sub_10097B50` / `sub_10097C60` (dismiss): `DismissReminder` (above), then the GUID in `SHL` 48 (flags & 1) or `SHL` 46.

**ProcessAccessoryReminderRequest(id, snooze, minutes)** (0x10092704, disassembly only): looks for the reminder being shown whose GUID (UI object +0xAC…+0xBB) is `id`. If found: snooze → UI object +0x84 = minutes, action `dword_100AB7FC`; dismiss → action `dword_100AB800` (`sub_100436E0`, posted to the UI). Otherwise only an ETW event with the GUID.

### AlarmLockIconTask

At shell start-up (`sub_1009E0B8`), `sub_1003CE50` creates a Task Scheduler task (opnum 0) that starts `Alarms_NoUI.exe UpdateLockAndStartInfo` when the shell is ready:

| Task item offset | Value |
|------------------|-------|
| 0x00 | → GUID `{2826F461-6F2C-4BD0-9BC4-0BC1A0908033}` (`unk_100ACE80`) |
| 0x04 | 0 (flags) |
| 0x08 | `L"AlarmLockIconTask"` |
| 0x2C | 1 |
| 0x30 | → `{ 1, → WNF state 0x418A063EA3BC3875 }` (`SHL` 7, `WNF_SHL_START_READY`, see [wpcrdmp.sys](../drivers/wpcrdmp.md)): trigger ? |
| 0x34 | → `{ 0, → { L"c:\Programs\Alarms\Alarms_NoUI.exe", L"c:\Programs\Alarms\Alarms_NoUI.exe UpdateLockAndStartInfo" } }`: action = start a program ? |

In the reminder tasks of [ShellChromeAPI.dll](./shellchromeapi.md#reminders) +0x30 is 0 and +0x34 points to `{ 4, data }`: the first DWORD of +0x34 looks like the action type (0 = program, 4 = data ?) and +0x30 a list of WNF triggers ?

#### Alarms_NoUI command lines

| Command line | Started by |
|--------------|------------|
| `Alarms_NoUI.exe UpdateLockAndStartInfo` | The `AlarmLockIconTask` task (above), on `WNF_SHL_START_READY` |
| `Alarms_NoUI.exe TimeChanged` | `sub_100720B4`, called by the exports `SystemTimeChanged` and `SystemTimeFormatChanged`: `CreateProcessInChamber(NULL, NULL, L"c:\Programs\Alarms\Alarms_NoUI.exe", L"c:\Programs\Alarms\Alarms_NoUI.exe TimeChanged", …)` |
| `Alarms_NoUI.exe ReminderDismissed <index>` | `DismissReminder` (above), command line read from the reminder |

### Wallpaper

The current wallpaper is in `HKLM\Software\Microsoft\Shell\Wallpaper` (`CurrentWallpaper`, `CurrentWallpaperOwner`, `CurrentWallpaperProvider`, backup in `Wallpaper\Backup`; OEM defaults in `Shell\OEM\Wallpaper`, `WallpaperSet`, `BackgroundSet`). The wallpaper RPC routines compare the caller product ID with the owner / provider (`sub_10078B68`, `sub_1006FF14`). Files: known folder + `Wallpapers` (`sub_10086D6C`), `KidZoneWallpapers` (`sub_10072B48`), `DefaultLockScreen.jpg`; the shared file tokens of ShellChromeAPI.dll are opened with `dsclient!DSOpenSharedFile` / `DSMoveFromSharedFile`.

### Haptic feedback

`sub_1004E9C8` reads `HKLM\SYSTEM\TOUCH\BUTTONS` (`Vibrate`, `Intensity`, `Duration`) and opens the vibrator: `CM_Get_Device_Interface_ListW({825E8FD3-6467-4A5B-ABFB-BB010734FF4D})` and `CreateFileW(GENERIC_READ | GENERIC_WRITE, shared, OPEN_EXISTING)` (`sub_1005164C`). A thread at priority 2 (`sub_10051738`) waits for an event, then sends the Set state request of [hwnvibradime.sys](../drivers/hwnvibradime.md#set-state) twice: on with the intensity, `Sleep(duration)`, off (`sub_1003B604` → `sub_1003B630`).

| Property | Value |
|----------|-------|
| IOCTL | 0x228000 (device 0x22, function 0, `FILE_WRITE_ACCESS`, `METHOD_BUFFERED`) |
| Input | 48 bytes at `dword_100AB0C4`: `30 00 00 00`, version 1, 1 setting, id 0, type 2 (vibrator), +0x14 intensity, +0x18…+0x28 = 0 (no blink), +0x2C mode (1 = on, 0 = off; > 2 rejected with E_INVALIDARG by `sub_1003B604`) |
| Output | none |

### WNF states

Decoded with `wnf.py`. All are well-known, system scope, version 1. `SHL` is the shell, the other owners are the media (`ZMQ`), device management (`DEVM`), audio (`AUD`), `ESB`, `ENTR`, `RW` and `OS`.

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x418A063EA3BC0875 | `SHL`, 1 | 4 bytes: lock state | Published by `sub_1004BDA0`, read by [ShellChromeAPI.dll](./shellchromeapi.md#wnf-states); subscribed by `sub_1009DBB8` |
| 0x418A063EA3BC1075 (`.text:0x100105B0`) | `SHL`, 2 | | Published by `sub_10095228` |
| 0x418A063EA3BC3875 (`.text:0x100312B8`) | `SHL`, 7 (`WNF_SHL_START_READY`) | | Read by `sub_1004C3C0` and `sub_10071B90`; trigger of [AlarmLockIconTask](#alarmlockicontask); also read by [wppower.sys](../drivers/wppower.md#wnf-states) and [wpcrdmp.sys](../drivers/wpcrdmp.md) |
| 0x418A063EA3BC6075 | `SHL`, 12 | | Published by `sub_1004B7D4` |
| 0x418A063EA3BC6C75 | `SHL`, 13 (permanent) | | Published by `sub_1003CA80` (ringer / vibrate state ?, registry `RingerVibrateState`), subscribed by `sub_1004B4CC` |
| 0x418A063EA3BC7875 (`.text:0x100324A8`) | `SHL`, 15 | | Read by `sub_1005F0FC`, published by `sub_1005F154` |
| 0x418A063EA3BC8075 | `SHL`, 16 | | Subscribed by `sub_1003BDB0` (callback `sub_10096A08`, settings), `sub_1003BFB4`, `sub_10091544` |
| 0x418A063EA3BCA875 | `SHL`, 21 | | Subscribed by `sub_1003BFB4` |
| 0x418A063EA3BCB075 | `SHL`, 22 | | Published by `sub_10049DEC` |
| 0x418A063EA3BCB875 | `SHL`, 23 | 4 bytes: shell mode | Published by `sub_1004BDA0`, read by ShellChromeAPI.dll (`Shell_GetCurrentMode`) |
| 0x418A063EA3BCC075 (`.text:0x1000A2EC`) | `SHL`, 24 | | Published by `sub_1005EE44` (volume limit, `sub_10053F44`, `sub_1009C05C`, …), published by `sub_1009CEE8` |
| 0x418A063EA3BCC875 | `SHL`, 25 | | Published by `sub_1005EE44` (`sub_10060728`), subscribed by `sub_1004B4CC` |
| 0x418A063EA3BCD075 | `SHL`, 26 | | Queried by `sub_1004BE88` (`InvokeLensPicker` path) |
| 0x418A063EA3BCD875 (`.text:0x100324A0`) | `SHL`, 27 | | Published by `sub_1009EAF4` |
| 0x418A063EA3BCE875 (`.text:0x10033518`) | `SHL`, 29 | | Read by `sub_1005E5E0` (driving mode, RPC opnum 7) |
| 0x418A063EA3BD0075 | `SHL`, 32 | | Published by `sub_10049CF4` |
| 0x418A063EA3BD2075 | `SHL`, 36 | 4 bytes: driving mode | Published by RPC opnums 7 and 8 (`sub_10070F78`, `sub_10070F14`), read by ShellChromeAPI.dll (`Shell_IsDrivingModeActive`) |
| 0x418A063EA3BD3875 | `SHL`, 39 | | Subscribed by `sub_1004B4CC` |
| 0x418A063EA3BD4075 | `SHL`, 40 | | Published by `sub_10072CEC` (Kid's Corner theme) |
| 0x418A063EA3BD4875 | `SHL`, 41 | | Subscribed by `sub_1003BFB4` |
| 0x418A063EA3BD5475 (`.text:0x1000B018`) | `SHL`, 42 (permanent) | 4 bytes: locked orientation | Published by RPC opnum 72 (`sub_10071D8C`), read by `sub_100553D0` and by ShellChromeAPI.dll |
| 0x418A063EA3BD6875 (`.text:0x1000AD20`) | `SHL`, 45 | 16 bytes: GUID | Reminder snoozed |
| 0x418A063EA3BD7075 (`.text:0x1000AD30`) | `SHL`, 46 | 16 bytes: GUID | Reminder dismissed |
| 0x418A063EA3BD7875 (`.text:0x1000AD18`) | `SHL`, 47 | 16 bytes: GUID | Reminder snoozed (flag 1) |
| 0x418A063EA3BD8075 (`.text:0x1000AD28`) | `SHL`, 48 | 16 bytes: GUID | Reminder dismissed (flag 1) |
| 0x418A063EA3BD8875 (`.text:0x1000AD38`) | `SHL`, 49 | 16 bytes: GUID | Reminder shown (`ProcessReminder`, without flag 1) |
| 0x418A063EA3BDA075 | `SHL`, 52 | | Read and subscribed by `sub_1009A330` (smart cover, RPC opnum 23) |
| 0x41970337A3BC1075 | `ZMQ`, 2 | 4 bytes | Read by `sub_1007C5CC` (`MyQueryWnfStateDword`) |
| 0x0C900B29A3BC0875, 0x0C900B29A3BC1075, 0x0C900B29A3BC3075 | `DEVM`, 1, 2, 6 | | Subscribed by `sub_100611D0`, `sub_1003BED0`, `sub_1003BDB0` |
| 0x41821B2CA3BF4875, 0x41821B2CA3BFE075 | `AUD`, 105, 124 | | Subscribed by `sub_1004B4CC` (audio) |
| 0x41841D28A3BC9075 | `ESB`, 18 | | Subscribed by `sub_1003BFB4` and `sub_1004B4CC` |
| 0x13920028A3BC0875 | `ENTR`, 1 | | Subscribed by `sub_1004D7C8` (with `RegNotifyChangeKeyValue` on `Settings\Lock`) |
| 0x41C6193FA3B96875 | `RW`, 173 | 8 bytes: do not disturb | Queried by `sub_10061238`, as in ShellChromeAPI.dll |
| 0x41C61D22A3BC3875 (`.text:0x100104B0`) | `OS`, 7 | 1 byte ? | Read by `sub_10049C80` (before the `{85F9809B-…}` RPC) and subscribed by RPC opnum 7 |

The `SHL` 6 and 30 states of the alarms and the `SHL` 50 / 51 accessory states of ReminderEvents.dll aren't referenced here. The symbolic names (`WNF_SHL_…`) are unknown except `WNF_SHL_START_READY`; empty cells weren't checked.

### Registry

Main keys, all under `HKEY_LOCAL_MACHINE` (strings of the binary, not all followed):

| Key | Values |
|-----|--------|
| `Software\Microsoft\Shell\LockAppSettings`, `…\OverlayAppSettings` | `LockAppAumId`, `OverlayAppAumId`, `ProductId`, `DisplayName`, `IconPath`, `OverlayTaskSwitcherResumeApp(Args)` |
| `Software\Microsoft\Shell\Timeouts` | `ACUserIdle`, `DCUserIdle`, `LockUserIdle`, `PasswordTimeout`, `DisableNever`, `TestScreenTimeoutOverride`, `TestInLockTimeoutOverride` |
| `Software\Microsoft\Shell\Lock`, `Software\Microsoft\Settings\Lock` | `EnablePacManMock`, `UnlockTickCount`, `PasswordInputLang`, … (watched with `RegNotifyChangeKeyValue`) |
| `Software\Microsoft\Shell\Wallpaper` (+ `\Backup`), `…\OEM\Wallpaper` | See [Wallpaper](#wallpaper) |
| `Software\Microsoft\Shell\OEM\SmartCoverSettings` | `AutoUnlock` |
| `Software\Microsoft\Shell\NavigationBar` | `SoftwareModeEnabled`, `IsUserManaged`, `IsDoubleTapOffEnabled`, `IsBurnInProtection*`, `Color`, `IsAutoHideEnabled`, `IsSwipeUpToHideEnabled`, `IsHintEnabled` |
| `SYSTEM\TOUCH\BUTTONS` | `Count`, `<n>\VKey`, `Vibrate`, `Intensity`, `Duration` |
| `SYSTEM\TOUCH\DISPLAYPROPERTIES`, `Software\Microsoft\Shell\Input` | Display size, gesture thresholds (`DoubleTapTimeThreshold`, `Flick*`, `Drag*`, `Crane*`, …) |
| `Software\Microsoft\Shell\SoundsSettings`, `Software\Microsoft\EventSounds\Sounds\*`, `…\SoundCategories\*` | `RingerOn`, `MuteOn`, `MediaMuteOn`, `RingerVibrateState`, `Sound`, `DefaultSound` (defaults `C:\Programs\CommonFiles\Sounds\Alarm-01.wma`, `Ring01.wma`, `Alert_calendar.wma`, …) |
| `Software\Microsoft\Shell\ActionCenter` (+ `\Sounds`, `\Vibrations`, `\DefaultSounds\`) | `AllowNocenterAboveLock`, `MinVerAboveLock`, `AppID`, `Param` |
| `Software\Microsoft\Shell\LockNotifications` | `NotificationSlot1…5`, `TextNotificationSlot`, `TileID`, `ProductID` |
| `Software\Microsoft\Family\KidZone\Configuration`, `…\Customization` | `Enabled`; `DisplayName`, `WallpaperPath`, `KidZoneThemeId`, `KidZoneAccentColorId`, `NormalThemeId`, `NormalAccentColorId` |
| `Software\Microsoft\Family\DrivingMode\Settings` | `PromptTimeOut` |
| `Software\Microsoft\Shell\Disturb` | `Enabled` |
| `SOFTWARE\OEM\VolumeLimit\`, `SOFTWARE\Microsoft\Shell\VolumeLimit\` | `EnableVolumeLimit`, `VolumeLimit`, `VolumeLimitWarningAccepted` |
| `Software\Microsoft\Shell\Oobe` | `OobeHeadless`, `NextSection`, `Done` |
| `SOFTWARE\Microsoft\Shell\RetailDemo\OobeWrite`, `…\RdmActive` | `Enabled`, `ProvisioningActive` |
| `Software\Microsoft\Shell\LogicalResolution` | `Width`, `Height` |
| `Software\Microsoft\Settings\QuickSettingElements\Pinned`, `Software\Microsoft\Shell\OEM\QuickSettings` | `AllowedQuickSettingsElements`, `Slot<n>`, `OEMEntriesProcessed` |
| `System\Shell\BootScreens`, `System\Shell\OEM\BootScreens` | `WPBootScreenOverride`, `WPShutdownScreenOverride` |
| `Software\Microsoft\Phone\ShellUI` | `EnableSoftwareProximitySensorMitigation` |
| `Software\Microsoft\Shell\OEM\Buttons\Custom`, `Software\Microsoft\Photos\OEM\DefaultLens`, `…\Photos\Shared\CameraSettings` | Camera / custom button application |
| `SYSTEM\CurrentControlSet\Services\telrepsvc\Parameters\SqmData` | `ShutdownTime`, `RebootReason` |

### Named objects and endpoints

| Name | Use |
|------|-----|
| `ShellFrame_Framework_Initialized` | Manual-reset event; most RPC routines wait on it before calling the UI (`sub_1003B4E8`) |
| `ShellFrame_Framework_ShutdownAnimationComplete` | Event (`sub_1005F1EC`) |
| `Global\SharedObjectDirectory\ContentSharing.ProgressAvailable` | `sub_1004DD20` |
| `AppContainerNamedObjects`, `UIA_NOBODY_THERE_EVENT` | `sub_10064F74` (accessibility) |
| `System\ActionDialogManagerEndpoint`, `ActionDialogManagerTestHook_Endpoint`, `System\SystemWaitCursorEndpoint` | CoreMessaging endpoints also used by [ShellChromeAPI.dll](./shellchromeapi.md#action-dialogs): server side ? |
| `System\RawShellButtonRouterInput`, `System\PickerContractUIEndpoint`, `System\RemoteInputLocaleManager`, `System\RemoteTextInputState`, `System\RemoteTextInputProcessor`, `System\NavigationServer_ShellSessionManager`, `System\SearchMaps\Assist\Persona` | Other CoreMessaging endpoints |
| `\PdcPort` | ALPC port of the power dependency coordinator |

### ETW

| Provider GUID | Registered by |
|---------------|---------------|
| `{9F79511C-06AD-4812-B18B-90006088D2CA}` | `DllMain` (context `dword_100AD400`, enable bits in `dword_100B2280`): main provider, used by the error logger `sub_1004F3E0` (bit 0x02) and the reminder events (bit 0x01, 0x04000000) |
| `{5C103042-7E75-4629-A748-BDFA67607FAC}` | `sub_10053694`, after the `{85F9809B-…}` binding (context `dword_100ADAB8`) |
| `{B55B0DE9-E22B-4201-ACF8-974585BE7935}` | `sub_100537D0`: PacMan client library (as in [Alarms_NoUI.exe](../applications/alarms_noui.md#etw)) |
| `{A6270E87-076E-4B23-B2B5-B11B5A377007}` | `sub_1004C130` (COM / `CoInitializeSecurity` init, `sub_100533F4`) |

The event descriptors weren't listed.
