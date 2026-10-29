## <Name>.exe

<One line: what the application is, for the user of the phone.>  
<What the binary really does (launcher, background task, …) and which framework/DLL it relies on.>  
<Related binaries of the same folder that carry the rest of the logic (not documented here).>

Location on the phone: `C:\Programs\<Folder>\<Name>.exe`  

### Imports

| DLL | Functions |
|-----|-----------|
| <dll> | `<function>`, `<function>` |

<Which imports are the standard CRT / `/GS` boilerplate. Exports, if any.>

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| <[x.dll](link) / `x.exe` / `<folder>\<file>`> | <`LoadLibraryExW` (data file) / `CreateProcessInChamber` / `CoCreateInstance` {CLSID} / `CreateFileW` / delay-load / `res://`> | <what for> |

### Parameters

| Command line | Usage | Exit code | Started by |
|---|---|---|---|
| `<Name>.exe <Command> <arg>` | <arguments (format, checks) and what it does: function called (`<ida name>`, 0x<addr>)> | <code> | <caller, if known> |

<Or, when the command line is ignored: one sentence saying so.>

### <Structure or call> parameter

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | <value> | <meaning> |

<Optional sections, only when present: Registry, Files, Devices and IOCTLs sent (driver-doc style tables), GUIDs, Named objects.>
