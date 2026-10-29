## <Name>.dll

<One line: what the library is for, in the system.>  
<What the DLL really does (RPC client, WNF listener, settings handler, …) and what it relies on.>  
<Who loads / calls it, and the related binaries documented elsewhere (links).>

Location on the phone: `C:\<Folder>\<Name>.dll`  

### Imports

| DLL | Functions |
|-----|-----------|
| <dll> | `<function>`, `<function>` |

<Which imports are the standard CRT / `/GS` boilerplate.>

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| <[x.dll](link) / `x.exe` / `<folder>\<file>`> | <`LoadLibraryExW` (data file) / `CreateProcessInChamber` / `CoCreateInstance` {CLSID} / `CreateFileW` / delay-load / `res://`> | <what for> |

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `<Export>` | 0x<addr> | `<type> <name>`, … |

<Global object used by the exports, if any.>

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | <meaning> |

### Startup

`start` (`_DllMainCRTStartup`, 0x<addr>): <CRT>. `DllMain` (`<ida name>`, 0x<addr>) <what it does>.

### <Export or function> (<ida name>, 0x<addr>)

1. <what it does first: call, important arguments, result handling>
2. <next step / branch>

<Return values, error codes.>

### <Structure> 

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | <meaning> |

### RPC

<Binding: protocol sequence, endpoint, security, retries.>

Interface `{<GUID>}` version <x.y>.

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| <n> | `sub_<addr>` | <function> | `[in] <type>`, … | <meaning> |

### WNF states

| Name | Owner, sequence | Data | Action |
|------|-----------------|------|--------|
| 0x<name> (`.text:0x<addr>`) | `<tag>`, <seq> | <size: content> | <subscribed / published, callback> |

### ETW

Provider `{<GUID>}`, registered in <function>.

| Event | Level | Opcode, task | Keyword | Enable bit | Written when |
|-------|-------|--------------|---------|------------|--------------|
| <id> | <level> | <opcode>, <task> | 0x<kw> | 0x<bit> | <when> |

<Optional sections, only when present: Registry, Files, COM, Devices and IOCTLs (driver-doc style tables), Named objects.>
