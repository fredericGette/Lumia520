## UIXMobile.dll

The application framework of the UIX markup applications of Windows Phone 8.1 (the shell, the settings pages, Alarms…): it starts the UIX engine, hosts the page stack and the navigation between pages and tasks, and owns the theme (light/dark, accent colour, font scale, high contrast).  
`UIXMobile.dll` is a large DLL (1 019 904 bytes, 1968 functions, public symbols available; about 740 KB of it are resources). It sits between the applications and the UIX engine `UIXn.dll` (not analysed), which really loads and runs the markup: [`RunApplication`](#runapplication-0x1003152c) reads the options of the caller and its command line, computes the screen resolution and scale factor, then calls `UIXn!UIXInitializeApplication` / `UIXRunApplication` / `UIXShutdownApplication` with the markup `res://UIXMobile!AppHost.uix`, whose frame loads the markup of the application. The DLL is itself a UIX schema (`dll://UIXMobile`, exports `UIXGetSchemaFactory` / `UIXSchemaUnloaded`): it gives the markup the page stack (`PageStackContainer`, `PageStack`, `PageState`, navigation, invocation of other tasks), the application bar and context menus, the theme colours, the environment (resolution, rotation, locale, product features) and helpers (asynchronous images, date/time formatting, XML escaping…). Its resources hold the compiled markup of the standard controls (`Button.uix`, `List.uix`, `Pivot.uix`, `Panorama.uix`, `DatePicker.uix`…).  
It imports `UIXn.dll` (engine), `CoreMessaging.dll` / `CoreUIComponents.dll` (connection to the execution manager and to the system endpoints), `EMCLIENT.dll` (property bags of the execution model), `AppChromeAPI.dll` (system tray, application bar, progress indicator of the shell chrome, served by [MobileUI.exe](../applications/mobileui.md#coremessaging-endpoints) ?) and [ShellChromeAPI.dll](./shellchromeapi.md) (`Shell_IsLocked`). `RunApplication` is called by [MobileUI.exe](../applications/mobileui.md#runapplication-parameter), [Alarms.exe](../applications/alarms.md#runapplication-parameter), [DateTimeCPL.exe](../applications/datetimecpl.md#runapplication-parameter) and [MirrorCPL.exe](../applications/mirrorcpl.md#runapplication-parameter); the `Theme*` exports are used by [MobileUI.exe](../applications/mobileui.md) and [ShellChrome.dll](./shellchrome.md).

Location on the phone: `C:\Windows\System32\UIXMobile.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| UIXn.dll | `UIXInitializeApplication`, `UIXRunApplication`, `UIXShutdownApplication`, `UIXGetServices`, `UIXSynchronizeView`, `UIXSetErrorReportHandler`, `UIXWatchDogFailFast` |
| CoreMessaging.dll | `CoreUICreate` |
| CoreUIComponents.dll | `CoreUIFactoryCreate`, `CoreUIClientCreate`, `MsgRelease` |
| EMCLIENT.dll | `CreatePropertyBagFromQuery`; C++ classes of `ExecutionModel`: `PropertyBag`, `Property` (get/set values), `ApplicationUri` (`Initialize`, `IsAppUri`, `GetPageName`, `GetTaskQueryParams`), `BufferReaderStream`, `FixedBufferWriterStream`, `CountingWriterStream`, `IStream` |
| AppChromeAPI.dll | `CreateAppChrome`, `GetAppLayerObscured`, `ShellSetClipboardControlsTextInfo` |
| [ShellChromeAPI.dll](./shellchromeapi.md) | `Shell_IsLocked`, `Shl::ActionDialog::Create` |
| TextInputFramework.dll | `TextInputClientCreate` |
| WindowsCodecs.dll | `WICCreateImagingFactory_Proxy` |
| WPGLOBUTIL.dll | `GetLocaleInfoExWP` |
| OLEAUT32.dll | `SysAllocString`, `SysFreeString` |
| ntdll.dll | `WinSqmStartSession`, `WinSqmSetDWORD`, `WinSqmEndSession` |
| api-ms-win-core-registry-l1-1-0 / l2-1-0 | `RegOpenKeyExW`, `RegCreateKeyExW`, `RegCreateKeyW`, `RegGetValueW`, `RegQueryValueExW`, `RegSetKeyValueW`, `RegEnumKeyExW`, `RegEnumValueW`, `RegQueryInfoKeyW`, `RegLoadMUIStringW`, `RegNotifyChangeKeyValue`, `RegCloseKey` |
| api-ms-win-core-libraryloader-l1-2-0 | `LoadLibraryExW`, `FreeLibrary`, `GetModuleHandleW`, `GetModuleHandleExW`, `GetProcAddress`, `GetModuleFileNameW`, `FindResourceW` (kernel32-legacy), `LoadResource`, `LockResource`, `SizeofResource`, `LoadStringW`, `DisableThreadLibraryCalls` |
| api-ms-win-core-file-l1-2-1 | `CreateFileW`, `GetFileSize`, `ReadFile`, `CompareFileTime` |
| api-ms-win-core-memory-l1-1-2 | `OpenFileMappingW`, `MapViewOfFile`, `UnmapViewOfFile` |
| api-ms-win-core-synch-l1-2-0, kernel32-legacy, threadpool-legacy | Critical sections, `CreateEventW`, `SetEvent`, `WaitForSingleObject`, `WaitForMultipleObjects`, `CreateWaitableTimerExW`, `SetWaitableTimer`, `CancelWaitableTimer`, `RegisterWaitForSingleObject`, `UnregisterWaitEx`, `Sleep` |
| api-ms-win-core-processthreads-l1-1-2 | `CreateThread`, `SetThreadPriority`, `GetCurrentThreadId`, `GetCurrentProcessId`, `GetCurrentProcess`, `TerminateProcess` |
| api-ms-win-core-localization-l1-2-1, datetime, timezone | `GetLocaleInfoW`, `GetUserDefaultLCID`, `GetUserDefaultLangID`, `LocaleNameToLCID`, `GetThreadUILanguage`, `SetThreadUILanguage`, `GetDateFormatW`, `GetTimeFormatW`, `FileTimeToSystemTime` |
| api-ms-win-core-url-l1-1-0, shlwapi-legacy, shlwapi-obsolete | `UrlEscapeW`, `UrlGetPartW`, `PathCreateFromUrlW`, `PathFindExtensionW`, `SHLoadIndirectString` |
| api-ms-win-core-com-l1-1-1 | `CoInitializeEx`, `CoUninitialize` |
| api-ms-win-core-sysinfo-l1-2-2 | `GetSystemDirectoryW` |
| api-ms-win-core-heap-obsolete-l1-1-0 | `LocalAlloc`, `LocalFree` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite` |
| api-ms-win-core-errorhandling-l1-1-2, debug | `GetLastError`, `SetLastError`, `RaiseException`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter`, `OutputDebugStringW` |
| Delay-load: ext-ms-win-rtcore-ntuser-dc-access-l1-1-0, ext-ms-win-rtcore-gdi-devcaps-l1-1-0, dsclient.dll | `GetDC`, `ReleaseDC`, `GetDeviceCaps`; `DSOpenSharedFile`, `DSCreateSharedFileToken`, `DSFreeString` |
| msvcrt.dll, api-ms-win-core-rtlsupport-l1-2-0 | CRT (`malloc`, `free`, `operator new`/`delete`, `mem*`, `wcs*`, `swscanf_s`, `_wtof`, `_initterm`, `__dllonexit`, C++ exceptions), `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |

The msvcrt, rtlsupport, `TerminateProcess`, `GetCurrentProcess`, `SetUnhandledExceptionFilter` and `UnhandledExceptionFilter` imports are the Visual C++ DLL CRT startup, C++ exception and `/GS` security cookie code. `api-ms-win-core-delayload-l1-1-1` (`ResolveDelayLoadedAPI`, `DelayLoadFailureHook`) resolves the three delay-loaded DLLs.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| UIX markup of the application (e.g. `res://AlarmsDll!Frame.uix`, `res://MobileUIRes!Main.uix`) | URI given in the [options](#runapplication_options) of `RunApplication`, loaded by `UIXn.dll` | Frame of the application (`FrameUI` property of `AppHost.uix`), or root markup |
| `UIXMobile.dll` resources (`res://UIXMobile!AppHost.uix`, `Frame.uix`, `Page.uix`…, `_DataTable.uib`) | `res://` URIs, loaded by `UIXn.dll` | Default root markup and the standard controls, see [Resources](#resources) |
| `UIXMobileRes.dll` | `LoadLibraryExW(…, LOAD_LIBRARY_AS_DATAFILE)` (`PageStack::LoadStringW`, 0x1002EEAC); `@UIXMobileRes.dll,-10015` / `-10016` (theme strings); `res://UIXMobileRes!SplashStrings.uix` (markup) | Localised strings of the framework |
| `UIXMobileAssets{ScreenResolution}` (e.g. `UIXMobileAssets480x800` ?) | `res://` URIs: `Constants.uix`, `SystemAssets.uix`, `ui.dark.*.png` / `ui.light.*.png` (borders, toggle switch, slider, edit box…), `common.*.error.png` | Resolution-dependent assets; `{ScreenResolution}` is a [markup substitution](#markup-substitutions-defines-and-redirects) set by `RunApplication` |
| Module named by a markup `Resources` object | `LoadLibraryExW(name, NULL, 0)` (`Resources::Resources`, 0x10020A90) | Strings loaded by the markup (`LoadString`, `LoadStringAsBool`…); "Failed to load resource module %s" |
| Module of a `res://module!name` image | `LoadLibraryExW` + `FindResourceW` / `LoadResource` (`AsyncImage::LoadFromResource`, 0x1002163C) | Images of `AsyncImage` / `AsyncImageGrid` |
| Image file (path) | `CreateFileW(GENERIC_READ, FILE_SHARE_READ \| FILE_SHARE_DELETE, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN)` (`AsyncImage::OpenFile`, 0x1001E63C) | Images, decoded with WIC on a worker thread |
| `dss://<token>` shared file | `dsclient!DSOpenSharedFile` (`AsyncImage::AsyncRead`, 0x1001E444) | Image shared by another application (data sharing service) |
| Shared file token | `dsclient!DSCreateSharedFileToken` (`PageStack::GenerateTokenLaunchUri`, 0x1002E804), capability `ID_CAP_APPRESOLVER` | Builds `token:<token>` to launch a file type association (`phone.fileTypeAssociation`) |
| File mapping of the task (name and maximum size given by the CoreUI task object) | `OpenFileMappingW` / `MapViewOfFile` (`FileMappingStreamBase::Initialize`, 0x10012E50) | Serialised page stack of a paused task (`PageStack::Serialize` / `Deserialize`, "Application task serialization data exceeded max size") |
| `emclient.dll` | `GetModuleHandleW` + `GetProcAddress("SHTerminateProcessForOOM")` (`UIXFailFastForOutOfMemory`) | Called if already loaded on out of memory, then exception 0xE055494D |
| Another copy of `UIXMobile.dll` | `GetModuleHandleExW(L"UIXMobile.dll")` + `GetProcAddress("ThemeGetThemeEngineInstance")` (`ThemeEngineWrapper::EnsureThemeEngine`, 0x1001CEE8) | If the module of that name isn't this image, its theme engine is shared instead of a private one |
| `svchost.exe`, `oobeeng` | `GetModuleFileNameW` / `GetModuleHandleW` ([DllMain](#startup)) | Refuses to be loaded in a service unless `oobeeng` is loaded |
| `starthost.exe` | `GetModuleHandleW` (`SetStartTileScaleFactor`, 0x10021D60) | Detects the Start screen host (tile scale factor) |
| `app://5B04B775-356B-4AA0-AAF8-6491FFEA568C/AssistHome?StartMode=Search&QuerySource=HardwareBtn`, `…/SearchResults?QuerySource=HardwareBtn&QueryString=` | `PageStack::LaunchSession` (`PageState::internal_LaunchOnlineSearch`, …) | Search (Cortana) started from a page (Search button, `JustType`) |
| `app://5B04B775-356B-4AA0-AAF8-6491FFEA5633/ExternalMarketplaceRequest?page=MarketplaceTagSearch&tag=%ls&title=%ls` | `EscapeTagOrExtensionAndBuildNavigationURI` (0x1002FC30) | Store search for an application handling a protocol (`phone.protocol.`) or file type |

No process is started directly: tasks and sessions are launched through the execution manager (CoreUI client of the `PageStackContainer`). No COM server is instantiated (only the WIC factory).

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 15 | `RunApplication` | 0x1003152C | `RUNAPPLICATION_OPTIONS *` ([layout](#runapplication_options)); returns void |
| 17 | `SetInitialNavigationRequest` | 0x10030968 | `LPCWSTR destination, UINT count, NAVIGATION_ARGUMENT *args` |
| 7 | `NavigateToDestinationInTask` | 0x100344E8 | `DWORD task, LPCWSTR destination, UINT count, NAVIGATION_ARGUMENT *args, void (*callback)(HRESULT), PAGETRANSITION from, PAGETRANSITION to` |
| 8 | `NavigateToDestinationWithObjectsInTask` | 0x10010824 | same with `NAVIGATION_OBJECTARGUMENT *` |
| 12 | `NavigationLaunchSession` | 0x10034A28 | `DWORD task, LPCWSTR uri, void *data, UINT size, LPCWSTR sessionInstance` |
| 13 | `NavigationLaunchSessionWithObjects` | 0x1001197C | `DWORD task, LPCWSTR uri, UINT count, NAVIGATION_OBJECTARGUMENT *args, LPCWSTR sessionInstance, PAGETRANSITION, PAGETRANSITION` |
| 9 | `NavigationCloseSessionInstance` | 0x10033258 | `DWORD task, LPCWSTR sessionInstance` |
| 10 | `NavigationLaunchChildTask` | 0x10033298 | `DWORD task, LPCWSTR uri, void *data, UINT size` |
| 11 | `NavigationLaunchChildTaskWithObjects` | 0x10034184 | `DWORD task, LPCWSTR uri, UINT count, NAVIGATION_OBJECTARGUMENT *args, PAGETRANSITION, PAGETRANSITION` |
| 14 | `PageStackRequestCloseInTask` | 0x100332E8 | `DWORD task` |
| 6 | `GetProgressIndicatorByTask` | 0x10013224 | `DWORD task, IProgressIndicator **out` |
| 16 | `SetClipboardControlsTextInfoByTask` | 0x100131C4 | `DWORD task, ClipboardControlsTextInfo *` |
| 5 | `ExecuteInUIThread` | 0x1002FEB8 | `void (*fn)(void *), void *context`; returns void |
| 18–44 | `Theme*` | | See [Theme engine](#theme-engine) |
| 47 | `GetResolutionWidth` | 0x10019D50 | none; returns the width in pixels (low word of `g_resolution`) |
| 46 | `GetResolutionHeight` | 0x10019EE4 | none; returns the height in pixels (high word of `g_resolution`) |
| 1 | `ApplyHighlightingToString` | 0x100233B0 | `LPCWSTR text, const HighlightBlock *blocks, DWORD count, LPWSTR *out` (adds `<hl>`…`</hl>` tags) |
| 45 | `XmlEscapeString` | 0x100145B0 | `LPCWSTR text, LPWSTR *out` (`&amp;`, `&quot;`, `&apos;`, …) |
| 2 | `CreateAsyncImage` | 0x10033C2C | `LPCWSTR source, IUIXObject **image` |
| 3 | `CreateAsyncImageFromLoader` | 0x10033B7C | `IAsyncImageLoader *loader, const UIXVariant *, UINT, IUIXObject **image` |
| 4 | `CreateUixListFilterer` | 0x10015C74 | `IUIXListFiltererSupport *, IUIXList **out` |
| 48 | `UIXGetSchemaFactory` | 0x10021F10 | `IUnknown **factory` (out), `IUIXServices *services` |
| 49 | `UIXSchemaUnloaded` | 0x100145F4 | `BOOL final` |

All the functions with an HRESULT return it (types from the decorated names). The `task` parameter is the task instance ID of a page stack (`PageStack` +0xC4): `GetPageStackFromTask` (0x10013280) looks it up in the page stack container and returns 0x80043014 if no page stack has this ID (or the ID is 0) and 0x80043015 if there is no container yet (`E_INVALIDARG` / `E_FAIL` instead for `GetProgressIndicatorByTask` and `SetClipboardControlsTextInfoByTask`, the first one turning `E_INVALIDARG` into 0x80044001). `PAGETRANSITION` 99 is used as "default" by `NavigationLaunchChildTask` ?.

- **Navigation**: `NavigateToDestination*InTask` → `PageStack::SetExternalNavigationRequest`; `NavigationLaunchSession*` → `PageStack::LaunchSession`; `NavigationLaunchChildTask*` → `PageStack::LaunchChildTaskWorker` / `PageStack::Invoke`; `NavigationCloseSessionInstance` → `PageStack::CloseSessionInstance`; `PageStackRequestCloseInTask` → `PageStack::RequestClose(TRUE)`. The `*WithObjects` variants first pack the arguments in a `PageStateProperties` object (0x28 bytes).
- **SetInitialNavigationRequest** stores the first page to show (`PageStackContainer::SetInitialNavigationRequestInternal`); returns 0x80043016 if the page stack container already exists. The markup type `NtHelpers` calls it from `PleaseNavigateToDestination`.
- **GetProgressIndicatorByTask** / **SetClipboardControlsTextInfoByTask** call the `IAppChrome` object of the page stack (vtable +24 / +44).
- **ExecuteInUIThread** posts `fn(context)` to the UI thread (`UIXDeferredInvoke`).

### Startup

`_DllMainCRTStartup` (0x10023C90): `__security_init_cookie` on `DLL_PROCESS_ATTACH`, then the CRT `_DllMainCRTStartup` (0x1002399C, `_initterm`: the static constructors register the ETW provider `Microsoft-WindowsPhone-Input`, see [ETW](#etw)) and `DllMain`.  
`DllMain` (0x1002B424), on `DLL_PROCESS_ATTACH`: `BlockLoadingInAService` (0x100228A0) gets the file name of the process; if it's `svchost.exe` and no module `oobeeng` is loaded, it writes to address 0 (crash). Then `DisableThreadLibraryCalls`.  
The UIXMobile ETW provider is only registered by `RunApplication` (`ETWRegistration::EnsureRegistered`). The theme engine is created on first use by any `Theme*` export.

### RunApplication (0x1003152C)

1. Can be called only once per process (second call: write to address 0). Registers the ETW provider.
2. Copies the [options](#runapplication_options): fail fast, registry redirects, theme and high contrast overrides, scale factor, allowed rotations (0 → 1; bit 2 set → crash). Saves the UI thread ID.
3. Watchdog, from `HKLM\Software\Microsoft\UIX`: `WatchDogTimeout` (ms), `WatchDogFailFast` (0 = no fail fast), `SecondaryWatchdogFailFastTimeout` (used as the timeout if there is none, or as a second, longer, limit). Option +0x1D disables the fail fast. The handler `OnWatchDogTimeout` (0x1002D964) logs an ETW event and, for the UI thread, arms a waitable timer for the rest of the secondary timeout; when it expires `OnSecondaryWatchdogTimeout` calls `UIXn!UIXWatchDogFailFast(uiThreadId)`.
4. Parses the [command line](#command-line): the string at +0x10 (split by `TokenizeCommandLine`), or `argc` / `argv` at +0x14 / +0x18. Then `LoadRegistryRedirects`.
5. Screen: `GetDeviceCaps(HORZRES)`, `GetDeviceCaps(VERTRES)`, `GetDeviceCaps(HORZSIZE)` on the screen DC; a 480-pixel-wide screen higher than 800 is treated as 480×800. Without a scale factor in the options or the command line, `Environment::CalculateScreenScaleFactor` (0x1002A1B8) uses the physical width in mm (`HORZSIZE`, or `UserPreferenceWidth` of the theme key if set): above 74 mm → 30 (if the resolution supports it), 62…74 mm → 20 (if supported), otherwise 10. Adds the substitutions `ScreenResolution` (`480x800`, `480x640`, `540x960`, `720x1280`, `768x1280`, `1080x1920`, `1440x2560`; anything else `480x800`), `ScreenScaleFactor` (`10`/`20`/`30`) and `StartTileScaleFactor`; `g_themeScreenSize` = 0/1/2 for 10/20/30.
6. Root markup: the URI at +0x34 if set; otherwise `res://UIXMobile!AppHost.uix` with the page property `FrameUI` = URI at +0x00.
7. Defines: `PLATFORM_MOBILE` if there are markup redirects or `/autoredirect`; `UIX_ENABLE_DEBUG_TRACE` and `UIX_ENABLE_DEBUG_ASSERT` if option +0x33 is set or there are redirects.
8. `UIXSetErrorReportHandler` (empty handler), `CoInitializeEx(NULL, COINIT_MULTITHREADED)`, `UIXInitializeApplication(&options)`; then, if the callback at +0x2C is set, calls it with the `IUIXServices` of `UIXGetServices`.
9. Initial navigation from +0x04 / +0x08 / +0x0C (`SetInitialNavigationRequestInternal`), then `UIXRunApplication` (runs until the application ends), `CleanupWatchdog`, `UIXShutdownApplication`, theme engine cleanup, frees the redirects / substitutions / defines, `CoUninitialize`.

Every failing HRESULT ends in `UIXFailFastForHRESULT`. ETW events 1…6 surround the three `UIXn` calls.

### RUNAPPLICATION_OPTIONS

The parameter of `RunApplication` (type name from the symbols), 0x3C bytes.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `LPCWSTR`: URI of the frame markup of the application (`FrameUI` of `AppHost.uix`), used only if +0x34 is NULL |
| 0x04 | 4 | `LPCWSTR`: destination (page) of the initial navigation |
| 0x08 | 4 | Number of `NAVIGATION_ARGUMENT`s of the initial navigation |
| 0x0C | 4 | `NAVIGATION_ARGUMENT *` |
| 0x10 | 4 | `LPCWSTR`: command line to parse (the launchers pass `lpCmdLine`), see [Command line](#command-line) |
| 0x14 | 4 | `argc`, used if +0x10 is NULL |
| 0x18 | 4 | `LPCWSTR *argv`, used if +0x10 is NULL |
| 0x1C | 1 | Copied to the UIXn options ? |
| 0x1D | 1 | Non-zero: the watchdog doesn't fail fast |
| 0x20 | 4 | Allowed rotations (bit mask, 0 → 1; bit 2 is refused): 1 = portrait, 2 and 8 = the two landscape orientations ? (DateTimeCPL.exe passes 11) |
| 0x24 | 4 | Theme override: 0 none, 1 light, 2 dark, 3 system |
| 0x28 | 4 | High contrast override: 0 off, 1 none, 2 system (MobileUI.exe and DateTimeCPL.exe pass 2) |
| 0x2C | 4 | `void (*)(IUIXServices *)`: called after `UIXInitializeApplication` |
| 0x30 | 1 | Copied to the UIXn options ? |
| 0x31 | 1 | No fail fast (same flag as `/nofailfast`) |
| 0x32 | 1 | Ignore the registry markup redirects (same as `/noregistryredirects`) |
| 0x33 | 1 | Enable the `UIX_ENABLE_DEBUG_TRACE` / `UIX_ENABLE_DEBUG_ASSERT` defines |
| 0x34 | 4 | `LPCWSTR`: root markup URI, replaces `res://UIXMobile!AppHost.uix` (MobileUI.exe: `res://MobileUIRes!Main.uix`) |
| 0x38 | 4 | Screen scale factor (10, 20 or 30; 0 = computed) |

The overrides are copied to `g_themeOverride` / `g_highContrastOverride` and become the overrides of the application (`ThemeEngineCM`), so a caller that zeroes the structure gets "high contrast off".

### Command line

`ParseCommandLine` (0x10021ABC). Arguments start with `/` or `-`; a value follows a `:` (`/locale:fr-FR`). Before a `/uix` switch only `/taskhandle:<hex>` is read and everything else is ignored, so an application can have its own arguments. After `/uix`, every argument must be one of these switches (otherwise "Unexpected command line switch /%s.", reported with `StringVPrintfWorkerW`):

| Switch | Value | Effect |
|--------|-------|--------|
| `/uix` | – | Starts the UIX switches |
| `/taskhandle` | hex | `g_taskHandle`: task of the page stack created when the application isn't execution-manager aware (read anywhere on the line) |
| `/markupredirect` | `from,to;from,to…` | Markup redirects (at most 50) |
| `/markupsubstitution` | `from,to;…` | Markup substitutions (`{name}` in URIs) |
| `/autoredirect` | – | Adds the `PLATFORM_MOBILE` define |
| `/animations` | `true` / `false` | Animations on / off |
| `/gdi`, `/dx9`, `/gl`, `/dx11`, `/dx11sw` | – | Rendering type 1, 2, 3, 4, 5 |
| `/locale` | locale name | `SetThreadUILanguage(LocaleNameToLCID(value))` |
| `/define`, `/d` | name | Markup define |
| `/failfast`, `/nofailfast` | – | Fail fast on / off |
| `/noregistryredirects` | – | Ignore `HKLM\SOFTWARE\Microsoft\UIX\MarkupRedirects` |
| `/themeoverride` | `light`, `dark`, `system`, `none` | Theme override 1, 2, 3, 0 |
| `/highcontrastoverride` | `off`, `none`, `system` | High contrast override 0, 1, 2 |
| `/resolution` | `WxH` (`,`, `x` or `X`) | Forces the resolution |
| `/screenscalefactor` | number | Forces the scale factor |
| `/windowsize`, `/windowscale` | `WxH`, float | Window size / scale (emulator ?) |

The launchers [DateTimeCPL.exe](../applications/datetimecpl.md#parameters) and [MirrorCPL.exe](../applications/mirrorcpl.md#parameters) pass their whole `lpCmdLine` here.

### Markup substitutions, defines and redirects

- **Redirects**: if `HKLM\SOFTWARE\Microsoft\UIX` `UIXOverride` (REG_DWORD) is non-zero and redirects aren't disabled, `LoadRegistryRedirects` (0x10022664) adds every REG_SZ value of `HKLM\SOFTWARE\Microsoft\UIX\MarkupRedirects` (name → data) as a redirect. More come from `/markupredirect`. The tables (`g_rgszRedirectFrom` / `To`), the substitutions and the defines are passed to `UIXInitializeApplication`.
- **Substitutions**: `ScreenResolution`, `ScreenScaleFactor`, `StartTileScaleFactor` (from `HKLM\SOFTWARE\Microsoft\Shell\Start` or `…\Shell\OEM\Start` `ScreenSize` when the process is `starthost.exe` or the define `IsStart` is set), plus `/markupsubstitution`.
- **Defines**: `PLATFORM_MOBILE`, `UIX_ENABLE_DEBUG_TRACE`, `UIX_ENABLE_DEBUG_ASSERT`, `/define`.

### Page stack and tasks

The schema type `PageStackContainer` (one per process, `PageStackContainer::GetInstance`, 0x1001A310) connects to the execution manager with `CoreUIClientCreate` and gets the application window handle. If the application isn't execution-manager aware it creates one `PageStack` for `g_taskHandle`. Each `PageStack` (`PageStack::Init`, 0x100190C4):
1. `CoreUICreate`, `CoreUIFactoryCreate`, then `AppChromeAPI!CreateAppChrome` (failure: `PageStackFailedToConnectToShellChrome`), whose `IAppChrome` object gives the system tray, the application bar, the progress indicator (`ProgressIndicatorWrapper`) and the wait cursor (`WaitCursorWrapper`).
2. Registers the task with the CoreUI client of the container (by task ID, or by name for a new task), keeps the task ID at +0xC4.
3. Starts the task state machine (`TaskStates`) and the navigation state machine.

Pages (`PageState`) are pushed and popped by `NavigateToPage` / `NavigateBack` (`NavigationResult`: `Success`, `Fail_InvalidTaskUri`, `Fail_NavigationInProgress`, `Fail_TaskInBackground`, …). On pause, `PageStack::Serialize` (0x1001271C) writes a property bag (`_TASK_INSTANCE_ID_`, `_INV_RET_CONTEXT`, `_RELAUNCH_INPUTS_`, `_IS_PARENT_TASK_`, `_RECEIVED_LAUNCH_PARAMS_`, `_PAGE_COUNT_`, `_PAGE_SERIALIZED_DATA_<n>_` with each page's `_PAGE_NAME_`, `_PAGE_UI_`, `_PAGE_PROPERTIES_`, transitions…) into the file mapping of the task; `Deserialize` rebuilds "dehydrated" pages from it. Launch parameters of an `app://` URI are added to the page inputs with `EMCLIENT!CreatePropertyBagFromQuery`. A page created while the phone is locked records it (`Shell_IsLocked`). Search requests start the search application (see [Dependencies](#dependencies)).

### Theme engine

One `ThemeEngine` object per process (static at 0x100388F0, or the one of another `UIXMobile.dll`, see [Dependencies](#dependencies)), returned by `ThemeGetThemeEngineInstance`. Settings are read again when the object is dirty (`EnsureThemeSettings`, 0x1001D0A4). Once a callback is registered, a thread (`ThemeChangeListenerThreadProc`, 0x100220E4) waits on `RegNotifyChangeKeyValue(REG_NOTIFY_CHANGE_LAST_SET)` on `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\Theme` and marks the object dirty, which calls every registered callback.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Theme override (`THEME_OVERRIDE`: 0 none, 1 light, 2 dark, 3 system) |
| 0x08 | 4 | Accent colour (ARGB) |
| 0x0C | 4 | Secondary accent colour |
| 0x10 | 4 | Complementary accent colour |
| 0x14 | 4 | Effective theme (0 light, 1 dark): system theme, or the override |
| 0x18 | 4 | Current accent ID |
| 0x1C | 4 | Font scale, 100…200 (%) |
| 0x20 | 4 | System theme (`CurrentTheme`, else `OEMDefaultTheme`, else `DefaultTheme`, else 1) |
| 0x24 | 4 | System high contrast (`HighContrast`) |
| 0x28 | 4 | High contrast override (`HIGH_CONTRAST_OVERRIDE`, 0…2) |
| 0x2C | 4 | Handle of the listener thread |
| 0x30 | 1 | Dirty |
| 0x34 | 0x18 | Critical section |
| 0x4C | 4 | List of `{callback, context, next, prev}` |

| Export | Address | Parameters | Action |
|--------|---------|------------|--------|
| `ThemeGetCurrentThemeAndAccent` | 0x10022D10 | `DWORD *theme, DWORD *accent` | `…ByTheme(0, …)` |
| `ThemeGetCurrentThemeAndAccentByTheme` | 0x10022D24 | `THEME_OVERRIDE, DWORD *, DWORD *` | Effective theme for that override, accent ID |
| `ThemeSetCurrentThemeAndAccent` | 0x10031E30 | `DWORD theme, DWORD accent` | Checks the pair, writes `CurrentTheme` / `CurrentAccent`, SQM data points 1205 / 1206 (`E_FAIL` if invalid) |
| `ThemeGetAccentColorProperty`, `ThemeGetSecondaryAccentColorProperty`, `ThemeGetComplementaryColorProperty` | 0x1001BC1C, 0x10020098, 0x1001FFBC | `DWORD *argb` | Object +0x08 / +0x0C / +0x10 (`E_FAIL` if 0) |
| `ThemeGetColorProperty` | 0x1001A5A4 | `LPCWSTR name, DWORD *argb` | Name → `ThemeColor` ID (table below), `E_INVALIDARG` if unknown |
| `ThemeGetColorPropertyById` | 0x10022F94 | `ThemeColor, DWORD *` | Colour of the current theme |
| `ThemeGetColorPropertyByTheme` | 0x1001724C | `ThemeColor, THEME_OVERRIDE, DWORD *` | Colour of the given theme (`LightThemeColors` / `DarkThemeColors` tables; 32 = accent; 37 = `PreviousPageBackgroundColor` if opaque, else 16) |
| `ThemeGetCurrentFontScale` / `ThemeSetCurrentFontScale` | 0x1001A18C / 0x100323C4 | `DWORD *` / `DWORD` | `FontScale` (100…200, else `E_FAIL`) |
| `ThemeGetFontScaleRange` | 0x1002CED4 | `DWORD *min, DWORD *max` | 100, 200 |
| `ThemeGetSystemHighContrast` / `ThemeSetSystemHighContrast` | 0x10021E6C / 0x1003239C | `BOOL *` / `BOOL` | `HighContrast` value |
| `ThemeGetCurrentHighContrast` | 0x10032404 | `BOOL *` | High contrast after the override |
| `ThemeSetThemeOverride` / `ThemeGetThemeOverride` | 0x1001F5D4 / 0x1002CEAC | `THEME_OVERRIDE` (≤ 3) | Object +0x00, marks dirty |
| `ThemeSetHighContrastOverride` | 0x1001FFFC | `HIGH_CONTRAST_OVERRIDE` (≤ 2) | Object +0x28, marks dirty |
| `ThemeGetRegisteredThemesAndAccentsCount` | 0x1002FEFC | `DWORD *themes, DWORD *accents` | Sub-keys of `…\Theme\Themes` and accent count (with the OEM accents) |
| `ThemeGetRegisteredThemesAndAccents` | 0x10032AE4 | `DWORD, THEME_INFO *, DWORD, THEMEACCENT_INFO *` | Fills 0x48-byte `THEME_INFO`s and 0x50-byte `THEMEACCENT_INFO`s (+0x00 ID, +0x04 display name from `DisplayName` with `RegLoadMUIStringW`, +0x44 colour, +0x48 secondary colour) |
| `ThemeRegisterThemeChangedCallback` / `ThemeUnregisterThemeChangedCallback` | 0x10020F68 / 0x10014A00 | `void (*)(void *), void *context` / callback | Callback list; the first one starts the listener thread |
| `ThemeGetSystemScreenSize` | 0x100175C8 | `THEME_SCREENSIZE *` | `g_themeScreenSize` (0/1/2 for scale factor 10/20/30) |
| `ThemeReadStartMenuScreenSize` / `ThemeSaveStartMenuScreenSize` | 0x100231E0 / 0x1002C6F0 | `THEME_SCREENSIZE *` / `THEME_SCREENSIZE` | `HKLM\SOFTWARE\Microsoft\Shell\Start` `ScreenSize` (read falls back to `…\Shell\OEM\Start`) |
| `ThemeSetSystemPhysicalScreenWidth` | 0x1002DABC | `THEME_SCREENSIZE` | Writes `UserPreferenceWidth` = 59, 64 or 75 (mm) for 0, 1, 2 |
| `ThemeGetThemeEngineInstance` | 0x10022FDC | `ThemeEngine **` | The engine object |

Accent colours (`GetThemeAccentColors`, 0x10021464): `…\Control Panel\Theme\Themes\<theme>\Accents\<accent>` values `Color`, `SecondaryColor`, `ComplementaryColor`. Accent IDs ≥ 100 are OEM accents: `HKLM\SOFTWARE\Microsoft\Shell\OEM\Theme\Accents\<id − 100>\Theme<theme>` (`Color`, `SecondaryColor`, `DisplayName`). Accent display names are under `…\Theme\AccentDisplayNames`. Current accent: `CurrentAccent`, else `OEMDefaultAccent`, else `DefaultAccent`, else 1.

`ThemeColor` IDs accepted by `ThemeGetColorProperty`:

| ID | Name | ID | Name |
|----|------|----|------|
| 0 | `BaseThemeColor` | 17 | `ChromeColor` |
| 1 | `TextHighContrast` | 18 | `TextHighColor` |
| 2 | `TextNeutralColor` | 19 | `TextHighColorHighContrast` |
| 3…7 | `TextNeutralColor20`, `30`, `60`, `75`, `80` | 20, 21 | `TextMidColor`, `TextLowColor` |
| 8 | `KeyPadBackground` | 22…28 | `BaseHighColor`, `BaseMediumHighColor`, `BaseMidColor`, `BaseMediumMidColor`, `BaseLowColor`, `BaseBlackColor`, `BaseWhiteColor` |
| 9 | `ContrastColor` | 29 | `ImagePlaceholderColor` |
| 10 | `SysTrayBackgroundColor` | 30, 31 | `SIPNormalBackground`, `SIPNormalBackgroundPressed` |
| 11, 12 | `ProgressBarBackground`, `ProgressBarDisabledBackground` | 32 | `TextAccentColor` (accent colour) |
| 13, 14 | `ListPickerBackgroundPressed`, `ListPickerBackground` | 37 | `PreviousPageBackgroundColor` (not by name) |
| 15 | `TransparentBackgroundColor` | | |
| 16 | `PageBackgroundColor` | | |

The markup type `NtHelpers` also writes `CurrentTheme` and `HighContrast` under `HKCU\UIXTheme` (`SetTheme` / `SetHighContrast`), and `ThemeEngine::SetPreviousPageBackgroundColor` the volatile `PreviousPageBackgroundColor`.

### UIX schema

`UIXGetSchemaFactory` creates (once; a second call writes to address 0) the schema object (0x1C bytes, `g_pSchema`, built from `g_NativeSchemaData`) and a `DefaultSchemaFactory` (0x10 bytes), saves `services` in `g_UIXServices` and returns the factory. `E_OUTOFMEMORY` if an allocation fails. `g_UIXServices` is used with vtable +12 (create a string object from a `WCHAR *`, e.g. `__NOOPNAVIGATE`) and +44 (report an error message), the same object as the host of [DateTimeCPLdll.dll](./datetimecpldll.md#exports).  
`UIXSchemaUnloaded(TRUE)` stops the image workers and the theme engine of the schema; `UIXSchemaUnloaded(FALSE)` releases the singletons (`ApplicationBarHelper`, `Environment`, `NtHelpers`, `PageStackContainer`), the schema and the factory, and resets every type ID to -1.

Types of `dll://UIXMobile` (from the `*Type::ID` reset list):

| Kind | Types |
|------|-------|
| Page stack | `PageStackContainer`, `PageStack`, `PageState`, `PageStateProperties`, `PageStateHelper`, `ExternalNavigationRequest`, `RequestInfo`, `InvocationContext`, `ChromeComponents`, `SystemTrayOptions`, `ProgressIndicatorWrapper`, `WaitCursorWrapper` |
| Menus | `Menu`, `MenuCommand`, `ContextMenu`, `ApplicationBarCommand`, `ApplicationBarTextCommand`, `ApplicationBarImageCommand`, `ApplicationBarToggleImageCommand`, `ApplicationBarTextImageCommand`, `ApplicationBarTwoLineTextCommand`, `ApplicationBarWrapper`, `ApplicationBarHelper` |
| Theme | `ThemeEngineCM` (`GetColor`, `GetString`, `GetAccentColor`, `GetFontScale`, `IsHighContrast`, `ThemeChanged`…), `SystemColorsCM` |
| Environment | `Environment` (resolution, scale factor, rotations, UI language and locale, `UseSIMUIM`, `UseWIFIWLAN`, `UseUIM1`, `WifiOnly`, `InitiateBackRequest`…), `NtHelpers` (screen and window size, `DeviceRotation`, `HighContrast`, `PleaseNavigateToDestination`), `Resources` (`LoadString`…), `ETWHelper` |
| Helpers | `DateTimeHelper`, `XMLEscaper`, `EditBoxHelper`, `SearchBarListHolder`, `ScrollbarInfo`, `VirtualItemAdapter`, `GroupSelectorOption`, `AsyncImage`, `AsyncImageGrid`, `DebugOutlines`, `Point`, `Rect` |
| Enumerations | `ApplicationBarMode`, `DateOrder`, `DateTimeFormat`, `ScreenScaleFactor`, `NavigationResult`, `NavBackProcessor`, `PageTransition` (`Slide`, `Swivel`, `Turnstile`, `Continuum`, `Readerboard`, …), `DeviceRotation`, `PageRotation`, `Resolution`, `ApplyProgrammaticCase`, `ThemeOverride`, `HighContrastOverride`, `ThemeColor`, `ThemeString`, `Theme`, `ScreenSize`, `MessageBoxDismissedReason`, `MessageBoxCategory`, `GroupSelectorStyle`, `GroupSelectorOptionStyle`, `Case`, `ListDeserializeState`, `AsyncImageStatus`, `ZoomerState`, `StretchingPolicy`, `StripAlignment`, `DebugOutlineMode` |

`Environment` reads the product features `SIMToSIMUIM`, `WiFiToWLAN`, `SIM1TOUIM1` (REG_DWORD, `HKLM\SOFTWARE\Microsoft\UIX\ProductFeatures`, `UseFeatureDependentString`, 0x10022EDC) and the feature pack `WifiOnly` (`HKLM\SOFTWARE\Microsoft\Windows Phone\FeaturePacks`, `IsFeaturePackInstalled`, 0x1002A100): the markup uses them to pick the strings (SIM/UIM, Wi-Fi/WLAN). The `TextInputStateAdapter` (0x10022AA0) connects to the CoreMessaging endpoint `System\RemoteTextInputState` (message type `{CF1538C5-01EF-4A39-ACB7-1B68F01B7EF4}`; error 0x87B2080A ignored) to follow the software keyboard state, also listed in [ShellChrome.dll](./shellchrome.md#named-objects-and-endpoints).

### Resources

`RCDATA` (type 10) resources, all compiled UIX (`UIB` header, referencing `res://UIXMobile!_DataTable.uib`): `ANIMATIONS.UIX`, `APPHOST.UIX`, `APPLICATIONBAR.UIX`, `AUTOSUGGEST.UIX`, `BUTTON.UIX`, `CARDHEADER.UIX`, `CHECKBOX.UIX`, `COLOREDGRAPHIC.UIX`, `CONSTANTSRULES.UIX`, `CONTROLS.UIX`, `DATEPICKER.UIX`, `EDITBOX.UIX`, `FRAME.UIX`, `LABEL.UIX`, `LABELEDFIELDSLIST.UIX`, `LINK.UIX`, `LIST.UIX` (64 861 bytes), `LISTPICKER.UIX`, `MESSAGEBOX.UIX`, `MESSAGEBOXBASE.UIX`, `PAGE.UIX`, `PAGESTACK.UIX`, `PANORAMA.UIX`, `PICKERBOX.UIX`, `PICKERBOXBASE.UIX`, `PIVOT.UIX`, `POPUPCONTROL.UIX`, `PROGRESSBAR.UIX`, `RADIOBUTTON.UIX`, `RATING.UIX`, `READERBOARD.UIX`, `SCROLLER.UIX`, `SEARCHBAR.UIX`, `SEARCHBARUI.UIX`, `SLIDER.UIX`, `SPACER.UIX`, `STYLES.UIX` (73 859 bytes), `THEMEDGRAPHIC.UIX`, `THEMEENGINE.UIX`, `TILTHELPER.UIX`, `TIMEPICKER.UIX`, `TOGGLEBUTTON.UIX`, `TOGGLESWITCH.UIX`, `WHEELSCROLLER.UIX`, `ZOOMER.UIX`, `_DATATABLE.UIB` (240 661 bytes, names and URIs), and four PNGs (`TEXTINPUT.CURSOR.OFF[.HC].PNG`, `TEXTINPUT.GRIPPER[.HIGHCONTRAST].PNG`). Type 11 (message table) and `WEVT_TEMPLATE` (ETW manifest) are also present. The data table also references `res://UIXMobile!DebugOutlines.uix` and `res://UIXMobile!Frame.uix#AppHost`, which aren't resources of this file.

### Registry

| Key | Value | Access | Use |
|-----|-------|--------|-----|
| `HKLM\Software\Microsoft\UIX` | `WatchDogTimeout`, `WatchDogFailFast`, `SecondaryWatchdogFailFastTimeout` | Read | [Watchdog](#runapplication-0x1003152c) |
| `HKLM\SOFTWARE\Microsoft\UIX` | `UIXOverride` | Read | Enables the registry markup redirects |
| `HKLM\SOFTWARE\Microsoft\UIX\MarkupRedirects` | any (REG_SZ) | Enumerated | Markup redirects |
| `HKLM\SOFTWARE\Microsoft\UIX\ProductFeatures` | `SIMToSIMUIM`, `WiFiToWLAN`, `SIM1TOUIM1` | Read | `Environment` strings |
| `HKLM\SOFTWARE\Microsoft\Windows Phone\FeaturePacks` | `WifiOnly` | Read | `Environment.WifiOnly` |
| `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\Theme` | `CurrentTheme`, `CurrentAccent`, `FontScale`, `HighContrast`, `UserPreferenceWidth` | Read / write, change notification | [Theme engine](#theme-engine), scale factor |
| same | `DefaultTheme`, `DefaultAccent`; sub-keys `Themes\<n>\Accents\<n>` (`Color`, `SecondaryColor`, `ComplementaryColor`, `DisplayName`), `AccentDisplayNames` | Read | Registered themes and accents |
| `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\ThemeVolatile` | `PreviousPageBackgroundColor` | Read / write | Background of the previous page (theme colour 37) |
| `HKLM\SOFTWARE\Microsoft\Shell\OEM\Theme` | `OEMDefaultTheme`, `OEMDefaultAccent`; `Accents\<n>\Theme<t>` | Read | OEM default and OEM accents |
| `HKLM\SOFTWARE\Microsoft\Shell\Start` | `ScreenSize` | Read / write | Start screen tile size |
| `HKLM\SOFTWARE\Microsoft\Shell\OEM\Start` | `ScreenSize` | Read | Default of the above |
| `HKCU\UIXTheme` | `CurrentTheme`, `HighContrast` | Write | `NtHelpers.SetTheme` / `SetHighContrast` |

### ETW

Two manifest providers:
- `Microsoft_WindowsMobile_UIXMobile` `{0C0FFEE0-F4B1-4F4D-B591-FB3175B13413}`, registered by `RunApplication` (`ETWRegistration::EnsureRegistered`, 0x10022364), about 120 events.
- `MICROSOFT_WINDOWSPHONE_INPUT` `{ED07CE1C-CEE3-41E0-93E2-EEB312301848}`, registered by the static constructor of `g_EtwLogger` (0x100294CC); one event, `_EhmMessage` (ID 5, level 2, task 1, keyword 0x1), written on the errors of `TextInputStateAdapter`.

UIXMobile events, by group (level 1 = critical, used as performance markers; 4 = information; 5 = verbose):

| IDs | Level | Task | Keyword | Enable bit | Written when |
|-----|-------|------|---------|------------|--------------|
| 1…6 | 1 | 1…3 | 0x2 | 0x1 | Start / stop of `UIXInitializeApplication`, `UIXRunApplication`, `UIXShutdownApplication` |
| 7…13, 20…22 | 1 | 4…10 | 0x2 | | Page navigate start / complete / away, popup show / hide (from the `ETWHelper` markup type), show / hide requests |
| 30, 31, 34…36 | 2, 4 | 11…14 | 0x1, 0x2 | 0x8 | Asynchronous image read, decode, failures |
| 200…299 | 3…5 | 0, 101…104, 112 | 0x4 | | `PageState`: created, loaded, ready, navigate to / away, back request, show / hide, close, rotation |
| 300…395 | 2…5 | 105…108 | 0x8 (0x1 for failures) | 0x100… | `PageStack`: created, process request, pause / resume, launch child task / session, close, navigation failures |
| 400…408 | 4, 5 | 109 | 0x10 | 0x1000, 0x2000 | `PageStackContainer`: instance, execution manager aware, launch task, close task host, page stack created / destroyed |
| 500 | 2 | 110 | 0x20 | | Page properties that can't be serialised |
| 600…602 | 5 | 111 | 0x40 | | Task, navigation and page state machine transitions |
| 650…656, 700, 701 | 4 | 103, 107 | 0x4, 0x8 | | Markup notifications `FrameUIOn*` and `PageUIOn*` (`ETWHelper`) |

`OnWatchDogTimeout` also writes an event (enable bit 0x4) with the process ID, the thread and the timeout.
