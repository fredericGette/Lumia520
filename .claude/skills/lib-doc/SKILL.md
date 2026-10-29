---
name: lib-doc
description: Reverse-engineer a Lumia 520 / Windows Phone 8.1 library (.dll, e.g. `ReminderEvents.dll`, `AlarmsSettingHandler.dll`) open in IDA and write its reference page in content/libraries/<name>.md, matching the existing pages (role, imports, other files it depends on, exports with their parameters, global state, DllMain and initialisation path, callbacks, structures, RPC interfaces and opnums, WNF states, ETW, files/registry used), then add it to content/libraries/README.md and propagate new findings to the library, application and driver pages. Use when the user asks to document, describe, or write up a library / DLL, or names a .dll to add to the libraries folder.
---

# Document a Windows Phone library

Produce `content/libraries/<basename>.md` for a DLL, in the same style as the existing pages.
Read `content/libraries/reminderevents.md` first if you haven't in this session: it's the reference
example (exports, RPC client, WNF subscriptions, versioned structure). Also read the pages of the
applications and drivers the DLL talks to (grep `content` for its name): they often already describe
the other side of a structure or a WNF state.

The pages are reverse-engineering notes for the Lumia 520 (MSM8930, WP8.1). Their value is concrete,
verifiable facts: export signatures, structure layouts, strings passed to APIs, GUIDs, opnums, WNF
names, registry values, files. Prefer "?" over a guess; mark tentative interpretations with a
trailing "?", and say when something comes from a binary that wasn't analysed.

## 1. Locate the input

- File name of the page = lowercase basename + `.md` (`ReminderEvents.dll` → `reminderevents.md`).
- Binary: use the database the user has open (`mcp__ida__list_databases`; if it reports no current
  instance, call `mcp__ida__open_database` with the listed path — it attaches to the GUI). Load the
  `mcp__ida__*` tools with ToolSearch first.
- Keep the function names the user already set in IDA and cite them with their address. For the
  `sub_` functions you describe, give a descriptive name in the text *and* the `sub_` name
  (`AccessoryCallback` (`sub_10001D5C`)); don't rename in the database unless asked.
- Install path on the phone: from the user's notes next to the binary, strings, or the folder it was
  extracted with (siblings of the same folder in the user's Documents); otherwise "?".
- Sibling binaries are only mentioned, not analysed, unless the user asks.
- Hex-Rays fails (`decompile` returns None, no exception) on most functions with a `/GS` cookie
  (`__security_push_cookie` / `__security_pop_cookie`). Dump their disassembly
  (`idautils.Heads` + `idc.generate_disasm_line`) to a file in the scratchpad and read it; don't try
  to fix the decompilation. Decompile everything else in one pass into a scratchpad file
  (skip the CRT range) rather than function by function.

## 2. What to extract

1. **Size of the job** — function count, segments, exports (`ida_entry`), imports
   (`ida_nalt.enum_import_names`), strings. `idautils.Strings()` misses most UTF-16 strings of the
   phone binaries: also scan the read-only data of `.text` for UTF-16LE runs.
2. **Role** — the non-CRT imports (what it calls *back* into, e.g. `ShellChrome!ProcessReminder`,
   says who loads it), the strings, the exports.
3. **Exports** — for each one: ordinal, address, parameters (from the decompilation and from how the
   arguments are used), return value. Most phone DLLs forward every export to a method of a global
   singleton: document that object (`| Offset | Size | Comment |`) once, with its constructor
   (lazy init, `atexit` destructor).
4. **Startup** — `_DllMainCRTStartup` → `dllmain_dispatch` → `DllMain`: one or two lines
   (usually only ETW registration). The real initialisation is often an exported `Initialize*`:
   decompile it, and every thread / timer / callback it starts.
5. **Callbacks** — WNF (`RtlSubscribeWnfStateChangeNotification`: `StateName` in R0:R1, `ChangeStamp`,
   `TypeId`, then `Context`, `Buffer`, `Length` on the stack), thread procs, COM/RPC callbacks:
   checks on size and name, what they call.
6. **Structures** — every structure built, parsed or passed to another DLL, as
   `| Offset | Size | Value/Comment |`. Look for versioned formats (header size + version checks,
   offsets turned into pointers) and give the conversion table. Compare with the same structure in
   the pages of the other side (e.g. `Shell_CreateReminder` in `alarms_noui.md`).
7. **Other files it depends on** — every file other than the static imports: delay-load
   imports, DLLs loaded at run time (`LoadLibrary*`, `LoadPackagedLibrary`, also as data files for
   resources / strings, with the functions taken by `GetProcAddress`), `res://` and other resource
   modules, executables it starts (`CreateProcess*`, `CreateProcessInChamber`, `ShellExecute*`, task
   or reminder command lines), COM servers it instantiates (CLSID → DLL when known, from another
   page or the registry), data / configuration / media files it opens, and files named in registry
   values it reads. Find them through the xrefs of those APIs and the path / `.dll` / `.exe` strings.
   For each: name, how it's used (API), what for, and a link if the page exists; "?" when the
   file name is built at run time and can't be resolved.
8. **Interfaces with the rest of the system**:
   - **RPC client**: run `scripts/ida_rpc.py` (paste it as `code` of `mcp__ida__execute_python`;
     it defines `run(db)`). It prints the interface GUID/version from the MIDL stub descriptor and,
     for every `NdrClientCall2` stub, its opnum, caller and parameters ([in]/[out], base type or
     type-format offset, return). Then the binding: `RpcBindingCreateW` template (protocol
     sequence, endpoint) and security (authn level/service, QoS, `ServerSecurityDescriptor`, often
     from `SecRuntime!QueryTransientObjectSecurityDescriptor(<name>)`), and the retry loop of
     `RpcBindingBind`. Give one row per opnum used: `| Opnum | Stub | Called by | Parameters | Use |`.
   - **WNF**: decode every state name with `python .claude/skills/lib-doc/scripts/wnf.py <name>`
     (or `low:high` when the two dwords are separate constants in ARM code) — never by hand. The
     names subscribed, queried (`RtlQueryWnfStateData`) or published, with the data size expected.
   - **ETW**: provider GUID (first argument of `EventRegister`), and the `EVENT_DESCRIPTOR`s passed to
     `EventWrite` (`struct.unpack('<HBBBBHQ')`: Id, Version, Channel, Level, Opcode, Task, Keyword)
     with the enable bit tested before each write.
   - COM (CLSID/IID), registry keys/values, files and known folders (`SHGetKnownFolderPath` GUIDs),
     device paths and IOCTLs (decode with `python .claude/skills/driver-doc/scripts/ioctl.py`),
     named objects.

Don't include a PE header section (machine, timestamp, linker, PDB…): the user doesn't find it useful.

## 3. Page structure

Follow `template.md` (next to this file):

- H2 title `## <Name>.dll` keeping the binary's own capitalisation; H3 sections.
- Intro: one line role, then what the DLL really does, then who uses it / what it relies on.
- Single-line facts end with **two trailing spaces**.
- Imports table `| DLL | Functions |`, followed by one sentence on what is CRT boilerplate.
- `### Dependencies` right after the imports: `| File | How | Use |` with every other file the
  binary depends on (not the static imports). Omit the section only if there is none.
- Exports table, then the global object.
- Main functions described in prose / numbered lists of what they do (calls made, with real API and
  type names, arguments that matter, branches, return values). **Never print decompiled or
  pseudocode functions** (no Hex-Rays output, cleaned up or not, no C blocks rebuilt from it or
  from the disassembly); decompile only to understand, then describe.
- Include only sections that have content. Link sections of the same page as `[x](#anchor)`.
- Link library pages as `[x.dll](./x.md)`, applications as `[x.exe](../applications/x.md)`, drivers
  as `[x.sys](../drivers/x.md)`.

## 4. Finish

1. Write `content/libraries/<basename>.md`.
2. Add `[Name.dll](./<basename>.md)  ` to `content/libraries/README.md` (CRLF line endings, each line
   ends with two spaces; replace a `TODO` entry if there is one). Check that the root `README.md` has
   the `## [Windows libraries](content/libraries/README.md)` section (CRLF), add it after
   "Windows applications" if not.
3. Propagate findings: grep `content` for the DLL name, its exports, GUIDs (any case, with and without
   braces), WNF names, opnums/interface, structure fields and registry values, and:
   - turn mentions like "`X.dll` (not documented here)" into links to the new page;
   - fill in "?" cells that the DLL proves (e.g. a structure field's meaning), and add the reverse
     view (`This WNF state is consumed by X.dll`).
   Same rules as `.claude/skills/driver-doc/SKILL.md` §5: edit only the concerned lines, keep each
   page's line endings, don't upgrade a "?" without proof, list ambiguous matches for the user
   instead of editing.
4. Tell the user what remains unknown (and which unanalysed binary would answer it, e.g. the RPC
   server or the DLL called back) and every other page you changed. Commit only if asked
   (convention: `add <basename>`).
