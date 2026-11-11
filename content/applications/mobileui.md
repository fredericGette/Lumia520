## MobileUI.exe

The shell process of Windows Phone 8.1: it hosts the Start screen / system UI, the system tray, the application bar, the hardware buttons and the system dialogs (low battery, weak charger, USB data, volume limit, SD card).  
`MobileUI.exe` is a large program (~190 KB of code, 1171 functions, public symbols available). The UI itself is the UIX markup `res://MobileUIRes!Main.uix` run by [UIXMobile!RunApplication](../libraries/uixmobile.md#runapplication-0x1003152c); most of the chrome logic is in [ShellChrome.dll](../libraries/shellchrome.md), which MobileUI.exe loads (it's the "shell UI host" that the ShellChrome page couldn't identify) and starts with `LaunchShellChromeServer`. MobileUI.exe itself contains the glue: the navigation proxies (session manager, rotation manager), the **hardware button router** (raw button input → Start/Back/Search/Camera/Power/Volume actions, combos, OEM remapping, connected standby), the **shell events** thread (42 WNF states, phone, storage, battery → system tray data model and dialogs), the `AppChromeServer` endpoint and the COM security of the shell.  
Related binaries not analysed here: `MobileUIRes.dll` (markup and `ApiSetSystemUiLoadedCallback`), `ShellFrameRes.dll` (strings), `CompServer.dll`, `CoreMessaging.dll` / `CoreUIComponents.dll`, `phoneom.dll`, `WPCOREUTIL.dll`, `EMSVCS.dll`.

Location on the phone: `C:\Windows\System32\MobileUI.exe` ?  

### Imports

| DLL | Functions |
|-----|-----------|
| [UIXMobile.dll](../libraries/uixmobile.md) | `RunApplication`, `ThemeGetSystemHighContrast`, `ThemeSetSystemHighContrast`, `ThemeGetCurrentThemeAndAccent`, `ThemeRegisterThemeChangedCallback`, `ThemeUnregisterThemeChangedCallback` |
| CompServer.dll | `InitializeCompositor` |
| MobileUIRes.dll | `ApiSetSystemUiLoadedCallback` |
| CoreMessaging.dll | `CoreUICreate`, `CoreUIFailFastOOM` |
| CoreUIComponents.dll | `CoreUIFactoryCreate`, `CoreUIClientCreate`, `MsgRelease` |
| [ShellChrome.dll](../libraries/shellchrome.md) | 136 functions: `LaunchShellChromeServer`, `StopShellChromeServer`, `SetMobileUICallback`, `SetChromeListener`, the button actions (`InvokeBack`, `InvokeStartPress`, `InvokeSearch`, `InvokeSearchPressAndHold`, `InvokeCamera`, `InvokePower`, `InvokePowerHeld`, `InvokeVolumeUp/Down[PressAndHoldPulse/Release]`, `InvokeHeadset[Tap/DoubleTap/TripleTap/PressAndHold]`, `InvokeRingerChanged`, `InvokeTaskSwitcher`, `InvokeScreenCapture`, `InvokeWrongScreenCaptureKeyCombo`, `InvokeOEMCustomButton[App]`, `HandleLensPickerForButtonPress`, `LaunchUif`), state notifications (`TurnScreenOn`, `NotifyScreenPowerState`, `NotifyEnteringUserIdle`, `NotifyMonitorStateChange`, `RingerVibrateChanged`, `SystemTimeChanged`, `SystemTimeFormatChanged`, `UserLocaleChanged`, `KidZoneEnabledChanged`, `DrivingModeActiveChanged`, `DoNotDisturbModeActiveChanged`, `ShellStartReadyEvent`), `RequestApplicationLaunch`, `RequestModernApplicationLaunch`, and the `SetSystemTray*`, `*ApplicationBar*`, `*ContextMenu*`, `SetProgIndicator*`, `SetWaitCursor*` … setters/getters forwarded from the application chrome proxies |
| [ShellChromeAPI.dll](../libraries/shellchromeapi.md) | `Shell_IsLocked`, `Shl::ActionDialog::ActionDialog::Create` (full-screen and partial-screen config overloads) |
| [ReminderEvents.dll](../libraries/reminderevents.md) | `InitializeReminderEvents`, `UninitializeReminderEvents` |
| [SecRuntime.dll](../libraries/secruntime.md) | `CreateProcessInChamber`, `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor` |
| eventsnd.dll | `PlayEventSound`, `StopEventSounds` |
| WPCOREUTIL.dll | `GetStorageInstanceCount`, `GetStorageStateName`, `GetStorageDeviceInfo`, `GetStorageSettings`, `SetStorageSettings`, `FinalizeVolume`, `ScanVolume`, `RecursiveRemoveDirectoryEx` |
| phoneom.dll | `PhoneAPIInitialize`, `PhoneAPIUninitialize`, `PhoneWaitForAPIReady`, `PhoneAddListener`, `PhoneRemoveListener`, `PhoneGetState`, `PhoneGetCallCounts`, `PhoneFreeCallInfo`, `PhoneGetLines`, `PhoneGetLinesEx`, `PhoneGetProviderLineInfo`, `PhoneGetBrandingText`, `PhoneGetAggregateBranding` |
| wpSensors.dll | `SensorOpen`, `SensorEnableIdleOperation`, `SensorGetData`, `SensorClose` |
| EMSVCS.dll | `CreateExecutionManager` |
| WerApiExtHost.dll | `TelGetProcessFlags`, `TelSetProcessFlags` |
| ntdll.dll | `RtlSubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfStateChangeNotification`, `RtlUnsubscribeWnfNotificationWaitForCompletion`, `NtQueryWnfStateData`, `RtlPublishWnfStateData` |
| RPCRT4.dll | `RpcStringBindingComposeW`, `RpcBindingFromStringBindingW`, `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingSetAuthInfoExW`, `RpcBindingFree`, `RpcStringFreeW`, `NdrClientCall2`, `NdrRpcSmClientAllocate`, `NdrRpcSmClientFree`, `I_RpcExceptionFilter` |
| OLEAUT32.dll | `SysAllocString`, `SysStringByteLen`, `VariantInit`, `VariantClear`, `VariantCopy` |
| api-ms-win-core-com-l1-1-1.dll | `CoInitializeEx`, `CoInitializeSecurity`, `CoCreateInstance`, `CoUninitialize` |
| api-ms-win-core-winrt-l1-1-0.dll | `RoInitialize`, `RoUninitialize` |
| api-ms-win-core-registry-l1-1-0.dll | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegGetValueW`, `RegSetValueExW`, `RegCloseKey` |
| api-ms-win-core-file-l1-2-1.dll / api-ms-win-core-io-l1-1-1.dll | `CreateFileW` / `DeviceIoControl` |
| api-ms-win-devices-config-l1-1-1.dll | `CM_Get_Device_Interface_ListW`, `CM_Get_Device_Interface_List_SizeW` |
| api-ms-win-service-management-l1-1-0.dll / api-ms-win-service-private-l1-1-1.dll | `OpenSCManagerW`, `OpenServiceW`, `StartServiceW`, `CloseServiceHandle` / `WaitServiceState` |
| api-ms-win-security-base-l1-2-0.dll, api-ms-win-security-lsalookup-l2-1-1.dll, api-ms-win-security-sddl-l1-1-0.dll | `InitializeSecurityDescriptor`, `InitializeAcl`, `AddAce`, `GetAce`, `IsValidSid`, `GetSecurityDescriptorDacl`, `SetSecurityDescriptorDacl`, `GetSecurityDescriptorLength`, `MakeAbsoluteSD`, `CreatePrivateObjectSecurity`, `DestroyPrivateObjectSecurity`, `AdjustTokenPrivileges`, `LookupPrivilegeValueW`, `ConvertSidToStringSidW` |
| api-ms-win-core-libraryloader-l1-2-0.dll, api-ms-win-core-kernel32-legacy-l1-1-1.dll | `LoadLibraryW`, `FreeLibrary`, `GetProcAddress`, `GetModuleHandleW`, `GetModuleHandleExW`, `GetModuleFileNameA`, `GetModuleHandleA`, `LoadStringW` |
| api-ms-win-eventing-provider-l1-1-0.dll | `EventRegister`, `EventUnregister`, `EventWrite` |
| other api-ms-win-core-* | threads, events, critical sections, heap, `QueueUserWorkItem`, `PathCchCombine`, `PathFileExistsW`, `CompareStringOrdinal`, `GetSystemTimeAsFileTime`, `OutputDebugStringW` … |
| msvcrt.dll | CRT (`__wgetmainargs`, `_initterm`, `malloc`, `free`, `memcpy`, `_vsnwprintf`, `wcscpy_s`, C++ exceptions …) |

The msvcrt imports, `GetStartupInfoW`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `TerminateProcess`, `Rtl*` unwind functions and `RaiseFailFastException` are the CRT / `/GS` / fail-fast boilerplate. The only export is the entry point `wWinMainCRTStartup`.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| `MobileUIRes.dll` | `res://MobileUIRes!Main.uix`, passed to `RunApplication` | Root UIX markup of the shell |
| `ShellFrameRes.dll` | `LoadLibraryW` + `LoadStringW` (`ShellFrameResHelper::LoadStringReadOnly`, 0x1008234; also the system tray accessible names) | Strings of the dialogs and of the system tray (ids 0x2C24–0x2C37 battery / USB, 0x2E7C… SD card, 0x2F44–0x2F46 volume limit, 0x36B0–0x36B1 post-update SMS) |
| `UIXMobileAssets{ScreenResolution}` | `res://%s!#%d` built by `SystemTrayDataModel::BuildIconResource` (0x100D394) | System tray icons (resolution-dependent asset module; `{ScreenResolution}` is a markup substitution set by [UIXMobile.dll](../libraries/uixmobile.md#markup-substitutions-defines-and-redirects)) |
| DLL named by `HKLM\System\Features\ButtonRemapping` | `RegGetValueW` (REG_SZ) + `LoadLibraryW` + `GetProcAddress("GetOEMButtonActionFromRegistry")` (`ShellButtonRouter::LoadOEMButtonAction`, 0x1018200) | OEM button remapping: `bool GetOEMButtonActionFromRegistry(OEMButtonAction *)`; when loaded, `DoOEMButtonAction` runs before the default button handling |
| `BaseDll` value of `HKLM\Software\Microsoft\Shell\OEM\SystemTray\CustomIcons` | read by `SystemTrayDataModel::LoadCustomSettings` (0x1015454), used as module of `res://%s!#%d` | OEM system tray icons (`BaseId`, `RoamingIconId`, `DomesticRoamingIconId`, `CallForwardingIconId`) |
| `emclient.dll` | `GetModuleHandleW` + `GetProcAddress("SHTerminateProcessForOOM")` (`UIXFailFastForOutOfMemory`, 0x102033C) | Called if already loaded, before raising exception 0xE054004D on out of memory |
| `c:\Programs\WPNarrator\WPNarrator.exe` | `CreateProcessInChamber(NULL, NULL, L"c:\\Programs\\WPNarrator\\WPNarrator.exe", L"/hardwarebuttonlaunch", 0, 0, NULL, &si, &pi)` (`ShellButtonRouter::HandleNarratorLaunch`, 0x1021794) | Narrator quick launch from a button combination (only if OOBE isn't finished or `HKLM\SYSTEM\Accessibility\MobileAccessibility` = 1); publishes `WNF_ESB_NARRATOR_WANT_TO_RUN` = 1 first |
| `Microsoft.MSBatterySense_8wekyb3d8bbwe!xC551F76Fy3368y42BBy92DFy7BFBB9265636x` | `RequestModernApplicationLaunch(aumid, L"Windows.Launch", L"-settings", …)` (`LowBatteryAlertDialog::WaitForBatteryLowDialog`, 0x102B3F8) | Battery Saver settings, opened from the low battery dialog |
| `app://5B04B775-356B-4AA0-AAF8-6491FFEA568C/AssistHome?StartMode=Search&QuerySource=HardwareBtn` | `RequestApplicationLaunch` (`AppChromeServer::OnSearchButtonPress`, 0x100D02C) | Search (Cortana) started by the Search button when no application handles it |
| `app://5B04B775-356B-4AA0-AAF8-6491FFEA5630/StorageSettings` | `RequestApplicationLaunch` (SD card dialogs, low storage dialog) | Storage Sense settings |
| `<SD card>\FOUND.000` … `FOUND.999` | `PathFileExistsW` + `RecursiveRemoveDirectoryEx` (`StorageStateHandler::DeleteFilesRecoveredFromScan`, 0x1021888) | Deletes the folders created by `ScanVolume` (chkdsk) on the SD card |
| `ApplicationActivationClient` CLSID `{79CEEEBE-BDE0-4C05-9D92-155F78BB7D2B}`, IID `{DFCAACC1-90D6-4B33-B437-E29D4CFAD8A6}` (`IApplicationActivationPhone`) | `CoCreateInstance(CLSCTX_INPROC_SERVER)` (`Mediator::RequestModernApplicationLaunch`, 0x10239CC) | Activation of modern (AppX) applications: method +0x10 (arguments) then +0x1C (AUMID, contract) |
| CLSID `{FB4D76FE-8863-4027-9D8A-4A00BEDF74D7}` / IID `{75B53853-1060-4C3B-921D-0D71EC07ED3C}`, CLSID `{630BB917-AA3B-4CF5-9D24-AAD1F7D4297A}` / IID `{7FE02DBD-7D62-419F-9E37-87C89B8799E6}` | `CoCreateInstance(CLSCTX_ALL)` (`SendPostUpdateSms`, 0x102374C, from `ShellEventsWNFCallback`) | Creates a local message with the strings 0x36B0 / 0x36B1 after an OS update (messaging store ?; servers unknown) |
| `StdGlobalInterfaceTable` | `CoCreateInstance` (ATL `GetGITPtr`) | ATL boilerplate |
| `powernotif` service | `OpenSCManagerW` + `OpenServiceW(L"powernotif", SERVICE_START \| SERVICE_QUERY_STATUS)` + `StartServiceW` + `WaitServiceState(…, 30000)` (`StartServiceW`, 0x10220A4) | Started if the `PowerNotifApi` RPC binding fails (see [RPC clients](#rpc-clients)) |

### Parameters

The command line isn't used: `wWinMain` (0x1027A30) ignores its parameters and always returns 0.

### Startup

`wWinMain`:
1. `TelSetProcessFlags(TelGetProcessFlags() | 1)`, registers the ETW provider `Microsoft-WindowsPhone-MobileUI` `{F243DC34-205E-4D34-94CA-36E8C0859787}`.
2. `CompServer!InitializeCompositor()`.
3. `CreateRawShellButtonRouter` (0x100F078): creates the `RawShellButtonRouter` singleton and its thread (`RawShellButtonRouterThreadProc`), see [Hardware buttons](#hardware-buttons).
4. `MobileUIRes!ApiSetSystemUiLoadedCallback(OnSystemUiLoaded)` and `ShellChrome!SetMobileUICallback(OnShellLoaded)`.
5. `CoInitializeEx(NULL, COINIT_MULTITHREADED)`, `InitializeComSecurity` (0x1024D68), `RoInitialize(RO_INIT_MULTITHREADED)`; a failure ends in `UIXFailFastForHRESULT`.
6. `RunApplication(&options)` with the [structure below](#runapplication-parameter): runs the shell until it exits.
7. Cleanup: `RoUninitialize`, `CoUninitialize`, `ShellChrome!StopShellChromeServer`.

`InitializeComSecurity` merges the DACLs of the transient objects `ContentSharingInterfaceAccess` and `VideoTelephonyInterfaceAccess` (`QueryTransientObjectSecurityDescriptor(12, name)`, access-allowed ACEs with a valid SID, duplicates skipped), builds a security descriptor with `CreatePrivateObjectSecurity` (process token) and `MakeAbsoluteSD`, and calls `CoInitializeSecurity(sd, -1, NULL, NULL, RPC_C_AUTHN_LEVEL_CONNECT, RPC_C_IMP_LEVEL_IDENTIFY, NULL, EOAC_NONE, NULL)`.

`OnSystemUiLoaded(ISystemUiServices *)` (0x1016DE0), called by MobileUIRes:
1. `WaitForProvisioning` (0x10176E8): subscribes to `WNF_DEVM_PROVISIONING_COMPLETE` and waits (infinite) on an event set by `ProvisioningCompleteWNFCallback`.
2. `CoreUICreate` (message session), `CoreUIClientCreate`.
3. Creates `SessionManagerProxy` (endpoint `System\NavigationServer_ShellSessionManager`), `RotationManagerProxy` (endpoint `System\RotationManager`) and the `Mediator`, and registers the mediator and the session with the system UI services.

`OnShellLoaded(IShellChromeNavigationHandler *)` (0x10131E0), called back by ShellChrome:
1. Gives the handler to the system UI services, `CreateAppChromeServer` + its initialisation, see [CoreMessaging endpoints](#coremessaging-endpoints).
2. `ShellChrome!LaunchShellChromeServer()`: starts the shell RPC server `{8B111127-…}` of [ShellChrome.dll](../libraries/shellchrome.md#rpc-server).
3. `LaunchShellEvents` (0x10132F8): registers the ETW provider `{10E4F0E0-9686-4E62-B2D6-FD010EB976D3}` and starts `ShellEventsThread`.

`ShellEventsThread` (0x1013634) creates the `ShellEvents` object (`ShellEvents::Init`, 0x1014110), `SetupStatusMonitoring` (status state monitor + `SystemTrayDataModel`), calls `ReminderEvents!InitializeReminderEvents()` (the unknown caller of the [ReminderEvents.dll](../libraries/reminderevents.md) page), sets the ready event and runs the CoreMessaging loop; at exit it calls `UninitializeReminderEvents`.

`ShellEvents::Init`:
- Endpoint `System\ShellEventsEndpoint` (security descriptor of the transient object of the same name), message procedure `ShellEventsMsgEndpointProc`.
- Creates the `ShellButtonRouter` from a wait callback (`CreateShellButtonRouterMsgWaitProc`).
- `SubscribeToWnfs` with the [42 states](#wnf-states) of `gc_rgEventInfo`, all handled by `ShellEventsWNFCallback`, which queues a `StatusStateEventData` to the shell events thread.
- If OOBE is done (`IsOobeDone`, see [Registry](#registry)), `RegisterStorageEvents` (WNF states returned by `StorageStateHandler::GetEvents`, callback `OnStorageStateChanged`); otherwise waits for `WNF_SHL_START_READY` (`OnStartMenu`).
- Subscribes to `WNF_CELL_SYSTEM_CONFIG` (`OnCellConfigChanged`, re-subscribes the per-CAN cellular states).
- `PhoneAPIInitialize()`; a delayed init timer (1 s, then every 5 s ?) runs `ShellEventsDelayedInitProc`: `PhoneAddListener` and the `IndicateConditionalCallForwarding` registry value.

### RunApplication parameter

`UIXMobile!RunApplication` receives a pointer to a 0x3C-byte structure on the stack (type `RUNAPPLICATION_OPTIONS` in the symbols, see [UIXMobile.dll](../libraries/uixmobile.md#runapplication_options)): the first DWORD is set to 0 and the next 0x38 bytes are zeroed by `memset`, then two fields are set. Unlike the launchers ([Alarms.exe](./alarms.md#runapplication-parameter), [DateTimeCPL.exe](./datetimecpl.md#runapplication-parameter), [MirrorCPL.exe](./mirrorcpl.md#runapplication-parameter)), the fields 0x00 / 0x04 (URI and page) are left at 0 and the URI is given at 0x34.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0 | (frame markup of the application for the other callers, unused when 0x34 is set) |
| 0x04 | 0x24 | 0 | No initial navigation, no command line, default rotation (portrait), no theme override |
| 0x28 | 4 | 2 | High contrast override: system (also 2 in DateTimeCPL.exe) |
| 0x2C | 8 | 0 | No services callback, default flags |
| 0x34 | 4 | `L"res://MobileUIRes!Main.uix"` | Root markup, replaces the default `res://UIXMobile!AppHost.uix` |
| 0x38 | 4 | 0 | Scale factor computed from the screen |

### Hardware buttons

**RawShellButtonRouter** (thread `RawShellButtonRouterThreadProc`, `RawShellButtonRouter::Initialize` 0x1014DB0):
- `GetCustomTimeouts` (0x1015A84) reads the hold delays (ms, REG_DWORD) from `HKLM\Software\Microsoft\Shell\CustomHoldDelays`: `SearchTapTimeout` and one value per button (table `c_rgButtonRouterButtons`, below).
- Input endpoint `System\RawShellButtonRouterInput` (security descriptor of the transient object of the same name; [ShellChrome.dll](../libraries/shellchrome.md) lists it among its endpoints), callback `RawShellButtonRouterEndpointCallback`; output connection `RawShellButtonRouterOutput` (message type `{A3AD131E-5DFC-4018-B2C7-187808BCB9A8}`).
- `HandleKeyEvent` (0x100B090): turns key down/up/cancel events into button notifications (press, hold, hold pulses, release, combos); after each event it sets the named event `Keyboard_Test_Sync_Event` if it exists (test synchronisation).

| Button | Name (hold-delay value) | Default hold delay | Pulses ? |
|---|---|---|---|
| 0 | Headset (`HeadSetHoldTimeout`) | 850 ms | yes |
| 1 | Start (`StartHoldTimeout`) | 850 ms | |
| 2 | Back (`BackHoldTimeout`) | 300 ms | |
| 3 | Search (`SearchHoldTimeout`) | 850 ms | |
| 4 | Volume up (`VolumeUpHoldTimeout`) | 300 ms | yes |
| 5 | Volume down (`VolumeDownHoldTimeout`) | 300 ms | yes |
| 6 | Camera (`CameraHoldTimeout`) | 850 ms | |
| 7 | Camera focus (`FocusHoldTimeout`) | 300 ms | |
| 8 | Power (`PowerHoldTimeout`) | 1500 ms | |
| 9 | Ringer switch (`RingerHoldTimeout`) | 850 ms | |
| 10 | OEM custom (`OEMCustomHoldTimeout`) | 850 ms | yes |
| 11 | OEM custom 2 (`OEMCustom2HoldTimeout`) | 300 ms | |
| 12 | OEM custom 3 (`OEMCustom3HoldTimeout`) | 300 ms | |

The third field of the table (1 for headset, volume and OEM custom) is probably the repeat (hold pulse) flag ?. `c_rgButtonCombos` holds 3 combinations: Power + Start, Power + Volume up (screenshot ?) and Volume down + Start ? (`{8,1,8,1}`, `{8,4,8,4}`, `{5,1,5,1}`; the meaning of the 2nd/4th fields isn't known).

**ShellButtonRouter** (`ShellButtonRouter::Initialize`, 0x1015140), created by the shell events thread:
- Connects to `RawShellButtonRouterOutput` and to `System\NavigationServer_ShellSessionManager`; output endpoint `System\ShellButtonRouterOutputEndpoint` (the endpoint [ShellChromeAPI.dll](../libraries/shellchromeapi.md) connects to for `Shell_RegisterButtonPressCallback`).
- `CreateExecutionManager`, enables `SeShutdownPrivilege` (`SetPrivileges`), `InitConnectedStandbyControl` (see [RPC clients](#rpc-clients)).
- Reads `WNF_OS_USER_PRESENCE`, opens `HKLM\Software\DeviceFeedback` and `HKLM\Software\Microsoft\Photos\Shared\CameraSettings`.
- Opens the GPIO buttons device (`OpenDriverByInterface` 0x1015544 → `GetDevicePath` 0x10155A8, first interface `{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}`, `CreateFileW(GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, OPEN_EXISTING)`), see [IOCTL 0xB02A8](#ioctl-0xb02a8--set-button-enabled-on-idle).
- `LoadOEMButtonAction` (see [Dependencies](#dependencies)).

`ShellButtonRouter::OnButtonPressEvent(button, event)` (0x100A788):
- Start pressed (event ≠ 0 / 7) while the screen is in connected standby → `SetConnectedStandbyMode` (RPC opnum 1). Power pressed (event 1) → `NotifyEnteringUserIdle` (if the screen is on) and `ToggleConnectedStandbyMode` (RPC opnum 2).
- If an OEM action DLL is loaded, `DoOEMButtonAction` first; if it doesn't handle the button:
  - 0 Headset → `HandleHeadset` (`InvokeHeadset*`); 1 Start → `HandleStart`; 2 Back → `InvokeBack` (press) or `InvokeTaskSwitcher` (hold, not locked, no incoming call); 3 Search → `HandleSearch`; 4 Volume up → `HandleVolumeUp`; 5 Volume down → `InvokeVolumeDown` (after `StopEventSounds`) / `…PressAndHoldPulse` / `…PressAndHoldRelease`; 6 Camera → `HandleCamera`; 7 Focus → `HandleLensPickerForButtonPress`; 8 Power → `InvokePower` (press) / `InvokePowerHeld` (hold); 9 Ringer → `InvokeRingerChanged`; 10 OEM custom → `HandleOEMCustom`.
  - Then `CheckActiveListener` forwards the event to the applications registered on the output endpoint.
- `UserInitiatedFeedback` (0x1020644): `LaunchUif(1, <UIFLaunchString>)` with the value `UIFLaunchString` of `HKLM\Software\DeviceFeedback`.

`HandleCamera` (0x1026430): press or hold of the camera button, when no lens picker / listener / incoming call takes it → `InvokeCamera(1)` if unlocked. When locked, if `ProximityAboveLock` = 1 (`CameraSettings` key) and the proximity sensor (`wpSensors!SensorOpen` …, `ProximityObjectDetected`) sees an object, the camera isn't launched; otherwise a hold vibrates (`QueueUserWorkItem(Vibrate)`, [IOCTL 0x228000](#ioctl-0x228000--vibrate)) and launches the camera.

`UpdateVolumeEnabledWhileIdleState` (0x100D014): when the screen is off (`OnPowerStateChange`, from `WNF_OS_USER_PRESENCE`), the volume buttons stay enabled during idle only while music is playing (`OnMusicPlayingStateChange`, from `WNF_MS_PLAYING_COUNT`) or another condition (+0x50, ?) is true.

### Shell events

`ShellEventsWNFCallback` and the other callbacks turn the WNF states, phone events (`PhoneEventNotificationHandler`) and storage states into `STATUS_ITEM` events queued (`MsgQueue<StatusStateEventData*>`) to the `StatusStateMonitor`, which feeds `SystemTrayDataModel` (signal bars, data connection type, Wi-Fi, Bluetooth, battery, location, roaming / call forwarding icons, clock, branding with `PhoneGetBrandingText`) and the ShellChrome notifications. Other actions:
- Battery (`ShellEvents::CheckBatteryStatus`, 0x100EED8): charger plugged → `PlayEventSound(L"BatteryCharging")` (if the event sound isn't disabled, see [Registry](#registry)) and `TurnScreenOn(1)`; low battery → low battery dialog.
- Theme: `MRTNotify_OnThemingEngineChange` (0x100CD90) publishes `WNF_MRT_QUALIFIER_CONTRAST_CHANGED` when the high contrast setting changes and `WNF_MRT_QUALIFIER_THEME_CHANGED` when the theme changes (no data).
- Storage (`StorageStateHandler`): `DoStorageStatusCheck` (0x102C1C0) reads `GetStorageDeviceInfo(STORAGE_DEVICE_SD = 2, 0)` and shows the matching dialog (bit 3 disabled, bit 1 unformatted, bit 0 dirty bit → `ScanVolume`, bit 2 new card), then `FinalizeVolume(2, 0)`. The new card dialog (unless `NewSDCardDialog\Disabled`) stores the choice with `SetStorageSettings(2, 0, 2, 71 or 87)` and opens Storage Sense. Other dialogs: low storage, unrecoverable errors, I/O failure, surprise removal (unless `SurpriseRemovalSDCardDialog\Disabled`), SD card used by apps of another device.
- Dialogs: `Shl::ActionDialog::Create` of ShellChromeAPI.dll, title / text / buttons from `ShellFrameRes.dll`, sound `SystemAsterisk`:

| Dialog | Trigger | Choices |
|---|---|---|
| Low battery (`LowBatteryAlertDialog`, partial screen, id `lowbattery`) | battery low | Battery Saver settings ([Dependencies](#dependencies)), or redisplay after a timeout (`RedisplayAlertAfterTimeout`) |
| Weak charger (`WeakChargerAlertDialog`) | `WNF_OS_USB_CHARGER_WEAK_SHOW` | "don't show again" stored in `NotifyOnWeakCharger` |
| USB data (`UsbDataAlertDialog`) | USB state 1 or 2 (`WNF_OS_USB_DEVICE_STATE` ?), when `PromptForDataConnection` ≠ 0 | allow / refuse the USB data connection, sent to the USB function stack ([IOCTL 0x2AC110](#ioctl-0x2ac110--usb-data-connection-allowed-)) |
| Volume limit (`VolumeLimitWarningDialog`) | `WNF_SHL_SHOW_VOLUMELIMITWARNING` | accepted → `VolumeLimitWarningAccepted` = 1; publishes `WNF_SHL_VOLUMELIMITWARNING_ARD_UP` (DWORD 1 when shown, 0 when closed) |

### CoreMessaging endpoints

| Endpoint | Side | Use |
|---|---|---|
| `System\RawShellButtonRouterInput` | server | Raw button events (from the input stack / ShellChrome ?) |
| `RawShellButtonRouterOutput` | server / client | RawShellButtonRouter → ShellButtonRouter |
| `System\ShellButtonRouterOutputEndpoint` | server | Button events for the applications ([ShellChromeAPI.dll](../libraries/shellchromeapi.md)) |
| `System\ShellEventsEndpoint` | server | Shell events messages |
| `System\AppChromeServerEndpoint` | server | Application chrome (system tray, application bar, context menu, progress indicator) of the applications: `AppChromeServer::OnAppChromeData`, forwarded to ShellChrome.dll |
| `System\ShellChrome_ClipboardServer` | client | Clipboard data (`AppChromeServer::OnShellChromeClipboardData`) |
| `System\NavigationServer_ShellSessionManager` | client | Navigation server (session manager proxy, task info, launches, OS shutdown) |
| `System\RotationManager` | client | Rotation manager proxy |

The server endpoints are protected by the security descriptor of the SecRuntime transient object of the same name (`TransientObjectSecurityDescriptor::Initialize`).

### RPC clients

| Interface | Binding | Opnums used | Use |
|-----------|---------|-------------|-----|
| `{85F9809B-3B25-4EEB-8160-FA4A60B80746}` v0.0 (stub descriptor 0x1001CE0), the connected standby interface also used by [ShellChrome.dll](../libraries/shellchrome.md#rpc-clients) | `InitConnectedStandbyControl` (0x1015744): `SeShutdownPrivilege` enabled during the connection, `RpcStringBindingComposeW(NULL, L"ncalrpc", …)`, `RpcBindingFromStringBindingW`, `RpcBindingSetAuthInfoExW(level 6 PKT_PRIVACY, service 10 WINNT, QoS v5, impersonation 3)`, then registers the ETW provider `Microsoft-WindowsPhone-Power` `{5C103042-7E75-4629-A748-BDFA67607FAC}` | 0 `SvcInitConnectedStandbyControl` (binding → context handle), 1 `SetConnectedStandbyMode` (context, 0), 2 `ToggleConnectedStandbyMode` (context, `[out]`), 4 `DeinitConnectedStandbyControl` (close context, from the `ShellButtonRouter` destructor). Opnums 1 and 2 are retried once after `ReestablishConnection` on RPC_E_DISCONNECTED (0x80010006) | Screen on / off by the Power and Start buttons |
| `PowerNotifApi` `{66D0D864-5D1E-11E1-9900-317C4824019B}` v0.0 (stub descriptor 0x1006370) | `PowerNotifSvcInit` (0x10212A0, from `PowerNotifRPCHandle::Open`): `RpcBindingCreateW` (LRPC, endpoint `PowerNotifApi\Server`, level 6, service 10, server security descriptor `QueryTransientObjectSecurityDescriptor(9, L"PowerNotifApi\\Server")`), `RpcBindingBind` | 3 `ProxyInitiateSystemShutdownExW` (0x1022914) | OS shutdown / restart (`SessionManagerProxy::ProceedWithOSShutdown`). If the binding fails, starts the `powernotif` service and retries once |

### Devices and IOCTLs

| Device | Opened by | IOCTL |
|---|---|---|
| GPIO buttons `{30EBFBF8-DF5F-4D4D-9FC5-A26C7FD1DF4A}` ([msgpiowinphone.sys](../drivers/msgpiowinphone.md)) | `OpenDriverByInterface` (kept open in the `ShellButtonRouter`, +0x68) | 0xB02A8 |
| Vibrator `{825E8FD3-6467-4A5B-ABFB-BB010734FF4D}` ([hwnvibradime.sys](../drivers/hwnvibradime.md)) | `ShellButtonRouter::Vibrate` (0x10249C8), first interface, `CreateFileW(GENERIC_READ \| GENERIC_WRITE, share 3, OPEN_EXISTING)` | 0x228000 |
| USB function `{1B0444ED-41E4-4900-8136-72AF43109A37}` (`UFX_DEVICE_INTERFACE`; owner not identified, it isn't the `{cec7d47f-…}` interface of [usbfnclx.sys](../drivers/usbfnclx.md), and no documented driver handles 0x2AC110) | `UsbDataAlertDialog::NotifyUsb` (0x10201F0), first interface, `CreateFileW(GENERIC_ALL, share 3, OPEN_EXISTING)`, kept open | 0x2AC110 |

#### IOCTL 0xB02A8 — Set button enabled on idle

Sent by `ApiButtonSetEnabledOnIdleOnDriver` (0x1021238) from `UpdateVolumeEnabledWhileIdleState`, for buttons 2 (volume up) and 3 (volume down) in the driver's numbering.

| Property | Value |
|----------|-------|
| Device | 0xB (FILE_DEVICE_KEYBOARD) |
| Function | 0xAA (170) |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

Inputbuffer (8 bytes, no output):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 02 00 00 00 / 03 00 00 00 | Button number (driver numbering) |
| 04 | 01 / 00 | 1 = enabled on idle, 0 = disabled |
| 05-07 | | Not initialised |

#### IOCTL 0x228000 — Vibrate

Sent twice by `ShellButtonRouter::Vibrate`: on, `Sleep(50)`, off (a 50 ms pulse at 100 %).

| Property | Value |
|----------|-------|
| Device | 0x22 |
| Function | 0x0 (0) |
| Access | FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

Inputbuffer (48 bytes, `malloc` + `memset`; same layout as [hwnvibradime.sys](../drivers/hwnvibradime.md#set-state)):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 30 00 00 00 | Payload size (48) |
| 04-07 | 01 00 00 00 | Version ? |
| 08-0B | 01 00 00 00 | Number of settings |
| 0C-0F | 00 00 00 00 | HwN Id |
| 10-13 | 02 00 00 00 | HwN type: vibrator |
| 14-17 | 64 00 00 00 | Intensity 100 % |
| 18-2B | 0 | Period, duty cycle, cycle count, settings 4–5 |
| 2C-2F | 01 00 00 00, then 00 00 00 00 | Mode: 1 = on, then 0 = off |

#### IOCTL 0x2AC110 — USB data connection allowed ?

Sent by `UsbDataAlertDialog::NotifyUsb(allow)`: with 1 when `PromptForDataConnection` is 0 (no dialog), otherwise with the choice of the USB data dialog. The result (`GetLastError` or 0) is kept but not used.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x44 (68) |
| Access | FILE_READ_ACCESS \| FILE_WRITE_ACCESS |
| Method | METHOD_BUFFERED |

Inputbuffer (8 bytes, no output):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 08 00 00 00 | Size of the structure |
| 04 | 01 / 00 | 1 = data connection allowed ?, 0 = refused (charge only ?) |
| 05-07 | 00 00 00 | |

### Registry

All keys are under `HKLM`.

| Key | Value | Access | Use |
|-----|-------|--------|-----|
| `Software\Microsoft\Shell\Oobe` | `Done`, `OobeHeadless`, `NextSection` (DWORD) | read (`GetOobeState`, 0x10167E0) | OOBE finished if `Done` ≠ 0 or `OobeHeadless` ≠ 0 (`IsOobeDone`) |
| `Software\Microsoft\Shell\CustomHoldDelays` | `SearchTapTimeout`, `<Button>HoldTimeout` (DWORD, ms) | read | Button timings ([table](#hardware-buttons)) |
| `System\Features` | `ButtonRemapping` (REG_SZ) | read | OEM button action DLL |
| `Software\DeviceFeedback` | `UIFLaunchString` | read | User-initiated feedback launch string |
| `Software\Microsoft\Photos\Shared\CameraSettings` | `ProximityAboveLock` (DWORD) | read | Proximity check before launching the camera from the lock screen |
| `SYSTEM\Accessibility` | `MobileAccessibility` (DWORD) | read | 1 = Narrator quick launch enabled |
| `Software\Microsoft\Shell\OEM\SystemTray` | `IndicateConditionalCallForwarding` (DWORD) and other DWORDs (`GetMultivariantRegValue`, 0x1012D7C) | read | System tray options |
| `Software\Microsoft\Shell\OEM\SystemTray\DataConnectionStrings` | 26 values `1XRTT_DEFAULT`, `1XRTT`, `EVDO_*`, `GSM_*`, `UMTS_*`, `LTE_DEFAULT`, `LTE_FDD`, `LTE_TDD`, `TDSCDMA_*` | read | Text shown for each data connection type (default 4 characters ?, `c_rgszDataConnectionTypeDefault`) |
| `Software\Microsoft\Shell\OEM\SystemTray\CustomIcons` | `BaseDll`, `BaseId`, `RoamingIconId`, `DomesticRoamingIconId`, `CallForwardingIconId` | read | OEM system tray icons |
| `System\CurrentControlSet\Control\Usbfn\Settings` | `PromptForDataConnection` (DWORD) | read | 0 = allow the USB data connection without asking |
| `Software\Microsoft\Shell\USB` | `DisableUSBControlPanel` (DWORD) | write | 1 at startup, 0 at the first USB state event |
| `Software\Microsoft\Shell\USB` | `NotifyOnWeakCharger` (DWORD) | read / write | Weak charger dialog enabled |
| `SOFTWARE\Microsoft\Shell\VolumeLimit\` | `VolumeLimitWarningAccepted` (DWORD) | write (created) | Volume limit warning accepted |
| `Software\Microsoft\Shell\NewSDCardDialog` | `Disabled` | read | Suppresses the new SD card dialog |
| `Software\Microsoft\Shell\SurpriseRemovalSDCardDialog` | `Disabled` | read | Suppresses the SD card surprise removal dialog |
| `Software\Microsoft\EventSounds\Sounds\<sound>` (e.g. `SystemAsterisk`) | `Disabled` | read | Event sound enabled (`SoundHelpers_GetSoundEnabled`) |
| `System\DevPlat` | `ShouldFailFast` (DWORD, default 1) | read | Fail-fast on errors (`DevPlat::Shared::ShouldRaiseFailFast`) |

### WNF states

Subscribed by `ShellEvents::Init` (`gc_rgEventInfo`, callback `ShellEventsWNFCallback`):

| Owner | States |
|---|---|
| SHL | `WNF_SHL_SYSTRAY_CLOCKINVISIBLE` (0x418A063EA3BC1075), `WNF_SHL_HARDWARE_BUTTON_STATE` (…4875, also read by `QueryWNFHardwareButtonStateInfo`), `WNF_SHL_SYSTEM_CLOCK_CHANGED` (…5875), `WNF_SHL_RINGER_VIBRATE_CHANGED` (…6C75), `WNF_SHL_SYSTRAY_TEST_EVENT` (…1875), `WNF_SHL_KIDZONE_ENABLED` (…9875), `WNF_SHL_SHOW_VOLUMELIMITWARNING` (…C875), `WNF_SHL_DRIVING_MODE_ACTIVE` (0x418A063EA3BD2075), `WNF_SHL_NOTIFICATIONS` (0x418A063EA3BD0875), `WNF_SHL_START_READY` (0x418A063EA3BC3875) |
| NLS / TZ | `WNF_NLS_LOCALE_INFO_CHANGED` (0x41950223A3BC2875), `WNF_NLS_USER_DEFAULT_LOCALE_CHANGED` (0x41950223A3BC1875), `WNF_TZ_TIMEZONE_CHANGED` (0x41C61439A3BC0875) |
| CELL | `WNF_CELL_SIGNAL_STRENGTH_BARS_CAN0/1` (0x0D8A0B2EA3BC1075 / …A3BD1075), `WNF_CELL_UICC_STATUS_SLOT0/1` (…A3BC2875 / …A3BD2875), `WNF_CELL_REGISTRATION_STATUS_CAN0/1` (…A3BC2075 / …A3BD2075), `WNF_CELL_POWER_STATE_MODEM0` (…A3BC0875), `WNF_CELL_CONFIGURED_LINES_CAN0/1` (…A3BDF475 / …A3BDFC75), `WNF_CELL_AIRPLANEMODE` (…A3BC3075), `WNF_CELL_RADIO_TYPE_MODEM0` (…A3BD0C75), `WNF_CELL_DATA_ENABLED_BY_USER_MODEM0` (…A3BC6475) |
| CNET | `WNF_CNET_CELLULAR_CONNECTIONS_AVAILABLE` (0x1583002EA3BC4875), `WNF_CNET_WIFI_ACTIVITY` (…9075), `WNF_CNET_VPN_STATUS` (…7875) |
| OS | `WNF_OS_BATTERY_PERCENTAGE_REMAINING` (0x41C61D22A3BC1875), `WNF_OS_BATTERY_STATE` (…2075), `WNF_OS_BATTERY_STRENGTH` (…1075), `WNF_OS_BATTERY_AC_ONLINE` (…2875), `WNF_OS_USER_PRESENCE` (…3075), `WNF_OS_MONITOR_ON` (…3875), `WNF_OS_BATTERY_SAVINGS_STATE` (…4075), `WNF_OS_USB_CHARGER_WEAK_SHOW` (…B075), `WNF_OS_USB_DEVICE_STATE` (…C075) |
| Others | `WNF_BLTH_BLUETOOTH_STATUS` (0x0992022FA3BC0875), `WNF_LFS_STATE` (0x41950821A3BC0875, location), `WNF_MS_PLAYING_COUNT` (0x41C61D20A3BC2075), `WNF_RW_DO_NOT_DISTURB_MODE` (0x41C6193FA3B96875), `WNF_DU_FEATUREDISCOVERY_COMPLETE` (0x41C61B29A3BC7875) |

`gc_rgEventInfoAwakeOnlySubscribe` (only while the screen is on ?): `WNF_WIFI_CONNECTION_STATUS` (0x0880073AA3BC0875), `WNF_CNET_RADIO_ACTIVITY` (0x1583002EA3BC0875).

Also subscribed: `WNF_DEVM_PROVISIONING_COMPLETE` (0x0C900B29A3BC0875, `WaitForProvisioning`), `WNF_CELL_SYSTEM_CONFIG` (0x0D8A0B2EA3BCA475), the storage states of `StorageStateHandler::GetEvents` (built at run time).

Published:

| State | By | Data |
|---|---|---|
| `WNF_MRT_QUALIFIER_CONTRAST_CHANGED` (0x41921C20A3BC0875) | `MRTNotify_OnThemingEngineChange` | none |
| `WNF_MRT_QUALIFIER_THEME_CHANGED` (0x41921C20A3BC1075) | `MRTNotify_OnThemingEngineChange` | none |
| `WNF_SHL_VOLUMELIMITWARNING_ARD_UP` (0x418A063EA3BCD075) | `SendWarningARDWNFNotify` (0x10202AC) | DWORD 1 / 0 |
| `WNF_ESB_NARRATOR_WANT_TO_RUN` (0x41841D28A3BCBC75) | `HandleNarratorLaunch` | DWORD 1 |

### ETW

| Provider GUID | Name | Registered by |
|---------------|------|---------------|
| `{F243DC34-205E-4D34-94CA-36E8C0859787}` | Microsoft-WindowsPhone-MobileUI | `wWinMain` (startup milestones, button router, errors `FEHM failure:hr=…`) |
| `{10E4F0E0-9686-4E62-B2D6-FD010EB976D3}` | Microsoft-WindowsPhone-Shell-Events | `LaunchShellEvents` |
| `{5C103042-7E75-4629-A748-BDFA67607FAC}` | Microsoft-WindowsPhone-Power | `InitConnectedStandbyControl` (the provider registered by [ShellChrome.dll](../libraries/shellchrome.md#etw) after the same binding) |
| `{057E13D9-E9CF-4258-BAC1-213C6AD2F680}` | Microsoft-WindowsPhone-Shell-AppChrome-Server | used by `AppChromeServer` (errors) |

### Named objects

| Name | Type | Use |
|---|---|---|
| `Keyboard_Test_Sync_Event` | event (opened with `EVENT_MODIFY_STATE`) | Set after each raw button event, when it exists (test tools) |
