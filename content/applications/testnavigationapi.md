## TestNavigationApi.exe

Test tool for the navigation server (CoreUI session manager): launches sessions and AppX applications, sends system keys, closes sessions, prints the sessions / tasks / windows and changes the navigation timeouts, all from the command line.  
`TestNavigationApi.exe` is a Microsoft internal console tool (64 functions, PDB `testnavigationapi.pdb`, no symbols). It isn't part of the phone image. Almost every command is a call to the session manager of the navigation server through the CoreMessaging endpoint `System\NavigationServer_TestSessionManager`. `LaunchModernApplication` goes through the application activation COM object, the auto dehydrate commands through the foreground task manager of [EMSVCS.dll](../libraries/emsvcs.md), and the timeout commands only write the registry.  
[TH.exe](./th.md) starts it to launch AppX applications (`TH <pkg> -r`).

Location on the phone: not in the phone image. [TH.exe](./th.md#dependencies) expects it in `\data\test\bin\` (`C:\Data\Test\bin\TestNavigationApi.exe`), the folder returned by [TestDeploymentInfo.dll](../libraries/testdeploymentinfo.md)`!GetTestDeployBinPath`.  

### Imports

| DLL | Functions |
|-----|-----------|
| CoreMessaging | `CoreUICreate` |
| CoreUIComponents | `CoreUIFactoryCreate`, `CoreUIClientCreate`, `MsgRelease` |
| [EMSVCS.dll](../libraries/emsvcs.md) | `CreateForegroundTaskManager` |
| api-ms-win-core-com-l1-1-1 | `CoInitializeEx`, `CoCreateInstance`, `CoUninitialize` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegQueryValueExW`, `RegSetValueExW`, `RegCloseKey` |
| api-ms-win-core-processthreads-l1-1-2 | `OpenProcess`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-psapi-l1-1-0 | `QueryFullProcessImageNameW` |
| api-ms-win-core-processenvironment-l1-2-0 | `GetStdHandle` |
| api-ms-win-core-handle-l1-1-0 | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2 | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-synch-l1-2-0 | `Sleep` |
| api-ms-win-core-rtlsupport-l1-2-0 | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| api-ms-win-core-libraryloader-l1-2-0 | `GetModuleHandleA` |
| msvcrt | `wprintf`, `printf`, `swprintf_s`, `swscanf`, `swscanf_s`, `_wcsicmp`, `operator new` / `delete`, `memset`, `memcmp`, CRT startup (`__wgetmainargs`, `_initterm`, `exit`, …) |

The exception filters, `RtlCaptureContext` / `RtlLookupFunctionEntry` / `RtlVirtualUnwind`, `GetModuleHandleA`, `GetCurrentProcess` / `TerminateProcess`, `Sleep` and the msvcrt startup functions are the Visual C++ CRT startup and `/GS` security cookie code. `OpenProcess` / `QueryFullProcessImageNameW` give the image name of each task's process in the status output. There are no exports.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| Navigation server, CoreMessaging endpoint `System\NavigationServer_TestSessionManager` | `CoreUIFactoryCreate`, factory method 3 with `{E6822F5C-E764-4BD6-8EDF-58B471FFA4DE}`, factory method 5 opens the message proxy ([Connection](#connection)) | Every command except `LaunchModernApplication`, the auto dehydrate and the timeout commands. The process serving the endpoint isn't known (the shell uses `System\NavigationServer_ShellSessionManager`, see [MobileUI.exe](./mobileui.md#coremessaging-endpoints)) |
| `ApplicationActivationClient` CLSID `{79CEEEBE-BDE0-4C05-9D92-155F78BB7D2B}` (see [MobileUI.exe](./mobileui.md)) | `CoCreateInstance(CLSCTX_INPROC_SERVER)` with `IApplicationActivationManager` `{2E941141-7F97-4756-BA1D-9DECDE894A3D}` | `LaunchModernApplication`: method 3 `ActivateApplication` |
| Foreground task manager of [EMSVCS.dll](../libraries/emsvcs.md#createforegroundtaskmanager-0x100044a8) | `CreateForegroundTaskManager(<CoreUICreate object>, &p)`, QueryInterface `{23B500C2-5623-4428-9DB4-A4803B62E684}`, method 6 | `EnableAutoDehydrate` / `DisableAutoDehydrate` (resource manager opnum 6) |

### Parameters

`wmain` (`sub_10045B0`) compares `argv[1]` case-insensitively (`_wcsicmp`) with the commands below. With no command, an unknown command or a missing / invalid argument it prints the usage. The exit code is always 0: read the output (`** SUCCESS: Sent request to Session Manager`, `** FAILED: …`).  
For the session manager commands it creates a 0x44-byte [command object](#command-object) and runs `sub_10041C0`, which connects to the navigation server and runs the command when the connection is up ([Connection](#connection)).

| Command line | Usage |
|---|---|
| `TestNavigationApi LaunchSession <Uri>` | Session manager method 46 (+0xB8) with the URI as a CoreMessaging string and three zero arguments; e.g. `app://5B04B775-356B-4AA0-AAF8-6491FFEA5603/Default` (Calculator, the example of the usage text). `LaunchNewSession` is an alias not listed in the usage |
| `TestNavigationApi LaunchModernApplication <AUMID> <TileID> [<Args>]` | `IApplicationActivationManager::ActivateApplication(AUMID, Args or L"", 0, &pid)`; prints `hr` and `pid`. `TileID` is required but only printed. Example AUMID of the usage: `Fabrikam.DirectXApplication.FrameworkView_rw7e02r5ytftm!AppId`. The session manager connection is opened anyway. [TH.exe](./th.md) runs it as `TestNavigationAPI.exe LaunchModernApplication <AUMID>` (command line as written on its page): with only the AUMID, this build prints the usage |
| `TestNavigationApi SystemKeyPressed Back\|Start\|Search\|FocusCamera\|CaptureCamera` | Session manager method 52 (+0xD0) with the key 1…5 (in this order) |
| `TestNavigationApi CloseSession <SID>` | Session manager method 50 (+0xC8) with the session instance ID (hexadecimal, `%x`, must not be 0; see `Status`) |
| `TestNavigationApi RemoveDeactivatedSessionFromBackstack <SID>` | Session manager method 51 (+0xCC), same argument |
| `TestNavigationApi EnableAutoDehydrate` / `DisableAutoDehydrate` | `sub_1004514(1 / 0)`: foreground task manager ([Dependencies](#dependencies)), `{23B500C2-…}` method 6 with TRUE / FALSE. No session manager connection |
| `TestNavigationApi Status` | Prints the [navigation server state](#status-output) |
| `TestNavigationApi Watch` | Prints the state, then registers the object as listener on the normal sessions list (list method 8) and keeps running: every change prints `*** Added / Removed / Replaced item %d ***` or `*** Cleared list ***` and the whole state again. Ends when the standard input is signalled (a key): the stdin handle is registered on the CoreMessaging dispatcher (`CoreUICreate` object method 35, callback `sub_100416C`), which unregisters the listener (list method 9) and leaves the loop |
| `TestNavigationApi SessionLists` | Prints the normal (method 3), restricted (5), orphan (4) and closing (8) sessions lists |
| `TestNavigationApi MRUSessionList` | Prints the MRU sessions list (method 7) |
| `TestNavigationApi ChangeBackstackSize <Size>` / `ChangeOrphanListSize <Size>` | Method 31 (+0x7C) / 33 (+0x84) with the size (decimal) |
| `TestNavigationApi ChangeLockVisible true\|false` | Method 22 (+0x58) with the BOOLEAN |
| `TestNavigationApi ChangeMonitorOn true\|false` | Method 24 (+0x60) |
| `TestNavigationApi ChangeDisplayObscured true\|false` | Method 26 (+0x68) |
| `TestNavigationApi EnterRestrictedMode <Mask> <Flags> <DefaultSessionUri> <BackstackSize>` | Method 53 (+0xD4) with `(Mask, Flags, Uri, BackstackSize)`. `Mask`: hexadecimal DWORD, "mask of allowed restricted task types". `Flags`: `none` 0, `ClientLaunchChildTaskAllowed` 1, `ClientLaunchSessionAllowed` 2, `All` 3. `BackstackSize` decimal |
| `TestNavigationApi ExitRestrictedMode true\|false` | Method 55 (+0xDC) with `(1, KeepTopSession)` |
| `TestNavigationApi EnableOverlayMode <DefaultSessionAUMID> <BackstackSize>` | Method 56 (+0xE0) with the AUMID as a CoreMessaging string and the size (exactly 2 arguments) |
| `TestNavigationApi DisableOverlayMode` | Method 57 (+0xE4) |
| `TestNavigationApi InitiateShutdown` | Method 58 (+0xE8), then registers the [session events listener](#command-object) on the proxy (proxy method 9) and waits for `OnShutdownComplete`, which unregisters it (proxy method 10) and leaves the loop |
| `TestNavigationApi CancelShutdown` | Method 59 (+0xEC) |
| `TestNavigationApi DumpNavTimeoutRegValues` | `sub_10042E4`: prints the [timeout values](#registry) that exist as `REG_DWORD` (`\t<name> = <value>`) |
| `TestNavigationApi EnableNavTimeouts on\|off` | `Enabled` = 1 / 0 |
| `TestNavigationApi EnableNavTimeoutsOnDebuggerAttached on\|off` | `EnabledOnDebuggerAttached` = 1 / 0 |
| `TestNavigationApi SetDebugMultiplier <n>` | `DebugMultiplier` = n (decimal, `swscanf_s`; the "positive" of the usage isn't checked) |
| `TestNavigationApi SetFirstPartyTargetStateTimeout <ms>` | `FirstPartyTargetState` |
| `TestNavigationApi SetFirstPartyQuickSwitchingTimeout <ms>` | `FirstPartyQuickSwitching` |
| `TestNavigationApi SetFirstPartyAnimationTimeout <ms>` | `FirstPartyAnimation` |
| `TestNavigationApi SetFirstPartySystemKeyPressedTimeout <ms>` | `FirstPartySystemKeyPressed` |
| `TestNavigationApi SetThirdPartyTargetStateTimeout <ms>` | `ThirdPartyTargetState` |
| `TestNavigationApi SetThirdPartyQuickSwitchingTimeout <ms>` | `ThirdPartyQuickSwitching` |
| `TestNavigationApi SetThirdPartySystemKeyPressedTimeout <ms>` | `ThirdPartySystemKeyPressed` |

Method numbers are vtable indexes of the session manager interface `{E6822F5C-…}` (byte offset in parentheses). The names of the methods come from the command names; their exact parameters come from the calls only. Strings are passed as CoreMessaging strings: a pointer to `{ DWORD length | 0x80000000, WCHAR *text }` (0x80000000 = text by pointer; the strings received from the server can also be inline, flag 0x40000000, text at +8, released with `MsgRelease`).  
The timeout commands (`sub_1004454` → `sub_10043A8`) print "Navigation timeout updates will be applied for cross page navigations in any new app launches. Device reboot is needed for navigation server to apply changes to cross task navigations." and don't connect to the server.

### Connection

`wmain` calls `CoreUICreate`, `CoreUIFactoryCreate` and `CoreUIClientCreate` (objects kept in globals, released at the end), then `CoInitializeEx(NULL, COINIT_MULTITHREADED)`. `sub_10041C0`:

1. `GetStdHandle(STD_INPUT_HANDLE)` (kept at +0x40) is registered on the `CoreUICreate` object (method 35, callback `sub_100416C`), for `Watch`.
2. Factory method 3 with `{E6822F5C-…}` (description of the interface ?), then factory method 5 opens the message proxy `L"System\\NavigationServer_TestSessionManager"` (+0x10).
3. Proxy method 7 registers the command object as connection listener; QueryInterface `{E6822F5C-…}` on the proxy gives the session manager (+0x14).
4. `CoreUICreate` object method 30 runs the CoreMessaging loop. The loop ends when a handler calls method 31.

The listener's `OnConnected` (`sub_10034A8`, slot 3) prints `** Connected to CoreUI Session Manager`, runs the command (switch on +0x18), prints `** SUCCESS: Sent request to Session Manager` (also when the call failed: the HRESULT isn't checked) and leaves the loop, except for `Watch` and `InitiateShutdown`. Slot 4 (`sub_10038E0`) prints `Proxy Disconnected!`. At the end the listener is unregistered (proxy method 8) and everything is released.

### Command object

0x44 bytes, `operator new`, three interfaces (`QueryInterface` = `sub_1003424`):

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | vtable 0x1003220 | `IUnknown`, connection listener `{01863EA3-981D-4590-9F5D-4D4A6A42E6B5}`: `OnConnected`, `OnDisconnected` |
| 0x04 | 4 | vtable 0x10031E4 | `{5E54D0D7-FB96-4F22-B700-D9318781BF57}`, list listener (`Watch`): item added / removed / replaced, list cleared (`sub_1003908` … `sub_10039A4`) |
| 0x08 | 4 | vtable 0x1003248 | `{D23027BA-C663-497A-BDBE-FAF14AD7D947}`, session events (`InitiateShutdown`): `OnSessionLaunched` (`sub_10039D8`), `OnSessionClosed` (`sub_10039F4`), `OnShutdownComplete` (`sub_1003A10`) |
| 0x0C | 4 | 1 | References |
| 0x10 | 4 | | Message proxy |
| 0x14 | 4 | | Session manager `{E6822F5C-…}` |
| 0x18 | 4 | 0…21 | Command, in the order of `wmain` (0 `LaunchSession`, 1 `LaunchModernApplication`, …, 21 `CancelShutdown`) |
| 0x1C | 4 | `WCHAR *` | URI / AUMID (`argv[2]`, `argv[4]` for `EnterRestrictedMode`) |
| 0x20 | 4 | 1…5 | System key |
| 0x24 | 4 | | Session instance ID |
| 0x28 | 4 | 0…3 | Restricted mode flags |
| 0x2C | 4 | | Restricted mode mask |
| 0x30 | 4 | | Size (backstack, orphan list) |
| 0x34 | 1 | | BOOLEAN argument |
| 0x38 | 4 | `WCHAR *` | Tile ID |
| 0x3C | 4 | `WCHAR *` | Arguments of `LaunchModernApplication` (`L""` by default) |
| 0x40 | 4 | | Standard input handle |

### Status output

`sub_100400C` prints, from the session manager:

- `SessionManagerActivationLevel` (method 27): `None`, `Active`, `Obscured`, `Locked`, `LockedObscured`, `LockedOff` (0…5).
- `VisibleSession` / `CurrentSession` (methods 9 / 10, `sub_1003B2C`): `SessionInstanceId`, `Uri`, `DisplayName`, `CurrentPageName`, and the session's tasks list.
- `VisibleTask` / `CurrentTask` (methods 11 / 12, `sub_1003D0C`): `TaskInstanceId`, `WindowInstanceId`, `ProcessId` and the image name (`OpenProcess(PROCESS_QUERY_INFORMATION)`, `QueryFullProcessImageNameW`), `Uri`, `DisplayName`, `CurrentState`, `TargetState`, `CurrentPageName`, `FirstActivation`, `LoadingScreenFileName`, `PauseOnLock`, `ResumeOnPowerOn`. The task states are `Inactive`, `Resuming`, `NavigatingTo`, `RequestingVisibility`, `Showing`, `Active`, `Hiding`, `RequestingInvisibility`, `NavigatingAway`, `Pausing`, `Closed`, `Obscured` (0…11).
- `VisibleWindow` / `CurrentWindow` (methods 13 / 14, `sub_1003F94`): `WindowInstanceId`, `TouchInputEndpoint`, `TextInputEndpoint`.
- The normal sessions list (method 3, `sub_1003A58`).

Lists are QueryInterface'd for `{17D276D3-F5AD-4668-9D53-1EF0996B8363}` (method 6 count, method 10 item at index). Session items are QueryInterface'd for `{8C38AD55-8547-4A93-9236-55C9A78805E6}`, task items for `{BB9A9399-AD60-43B9-BF3F-E5B2CA5F049E}`.

### Registry

Key `HKLM\System\ControlSet001\Services\CoreUI\Navigation\Timeouts`, all values `REG_DWORD`. `DumpNavTimeoutRegValues` opens it with `RegOpenKeyExW(KEY_READ)`, the other commands with `RegCreateKeyExW` + `RegSetValueExW` (`** FAILED: Unable to open navigation registry key` / `… set navigation registry value`).

| Value | Command | Use |
|-------|---------|-----|
| `Enabled` | `EnableNavTimeouts` | Navigation timeouts on / off |
| `EnabledOnDebuggerAttached` | `EnableNavTimeoutsOnDebuggerAttached` | Timeouts also when a debugger is attached |
| `DebugMultiplier` | `SetDebugMultiplier` | Multiplier of the timeouts ? |
| `FirstPartyTargetState`, `FirstPartyQuickSwitching`, `FirstPartyAnimation`, `FirstPartySystemKeyPressed` | `SetFirstParty…Timeout` | Timeouts (ms) for first-party applications |
| `ThirdPartyTargetState`, `ThirdPartyQuickSwitching`, `ThirdPartySystemKeyPressed` | `SetThirdParty…Timeout` | Timeouts (ms) for third-party applications |
