---
name: app-doc
description: Reverse-engineer a Lumia 520 / Windows Phone 8.1 application (.exe, e.g. `Alarms.exe`, `Alarms_NoUI.exe`) open in IDA and write its reference page in content/applications/<name>.md, matching the existing pages (role, imports, other files it depends on, command-line parameters and their usage, structures passed to framework calls, files/registry/devices/IOCTLs used), then add it to content/applications/README.md and propagate new findings to the driver and application pages. Use when the user asks to document, describe, or write up an application, or names a .exe to add to the applications folder.
---

# Document a Windows Phone application

Produce `content/applications/<basename>.md` for an executable, in the same style as the existing
pages. Read `content/applications/alarms.md` first if you haven't in this session: it's the reference
example (a small launcher). For larger programs, also borrow conventions from the driver pages
(`content/drivers/qcbms8930.md`) and from `.claude/skills/driver-doc/SKILL.md` §3 for IOCTL and
buffer tables.

The pages are reverse-engineering notes for the Lumia 520 (MSM8930, WP8.1). Their value is concrete,
verifiable facts: strings passed to APIs, structure layouts, registry values, files, IOCTL codes,
GUIDs. Prefer "?" over a guess; mark tentative interpretations with a trailing "?", and say when
something comes from a binary that wasn't analysed.

## 1. Locate the input

- File name of the page = lowercase basename + `.md` (`Alarms.exe` → `alarms.md`).
- Binary: use the database the user has open (`mcp__ida__list_databases`; if it reports no current
  instance, call `mcp__ida__open_database` with the listed path — it attaches to the GUI). Load the
  `mcp__ida__*` tools with ToolSearch first.
- Keep the function names the user already set in IDA (e.g. `call_RunApplication`) and cite them with
  their address.
- Install path on the phone: look for it in the user's notes next to the binary (e.g. a `.txt` in the
  same folder) or in strings; otherwise write it with "?".
- Sibling binaries (same folder, related DLLs) are only mentioned, not analysed, unless the user asks.

## 2. What to extract

1. **Size of the job** — function count, segments, imports, exports, strings
   (`idautils.Functions`, `ida_nalt.enum_import_names`, `idautils.Strings`). A handful of functions
   with one non-CRT import means a launcher: say so in the intro and keep the page short.
2. **Role** — the imports that aren't CRT / `api-ms-win-core-*` boilerplate, and the strings.
3. **Parameters** — find `wWinMain` / `wmain` (`start` → CRT startup) only to reach the command-line
   parsing; don't document the startup functions (CRT, `/GS`, exception filters, the entry point
   itself). List every command-line parameter the application accepts: syntax, arguments with their
   format and checks, what it makes the application do (function called, with IDA name and address),
   exit code, and who starts it with that parameter when known. If the command line is ignored, say
   so in one sentence.
4. **The real work** — decompile what the parameters lead to. For every call into a framework or
   OS DLL (UIX `RunApplication`, COM, `CreateFile`, `DeviceIoControl`, `Reg*`, ETW, RPC/ALPC…):
   the argument values, and the layout of any structure built on the stack (`| Offset | Size | Value | Comment |`).
5. **Other files it depends on** — every file other than the static imports: delay-load
   imports, DLLs loaded at run time (`LoadLibrary*`, `LoadPackagedLibrary`, also as data files for
   resources / strings, with the functions taken by `GetProcAddress`), `res://` and other resource
   modules, executables it starts (`CreateProcess*`, `CreateProcessInChamber`, `ShellExecute*`, task
   or reminder command lines), COM servers it instantiates (CLSID → DLL when known, from another
   page or the registry), data / configuration / media files it opens, and files named in registry
   values it reads. Find them through the xrefs of those APIs and the path / `.dll` / `.exe` strings.
   For each: name, how it's used (API), what for, and a link if the page exists; "?" when the
   file name is built at run time and can't be resolved.
6. **Interfaces with the rest of the system** — registry keys/values, files and `res://` resources,
   device paths and IOCTLs sent (decode codes with `python .claude/skills/driver-doc/scripts/ioctl.py`),
   GUIDs (CLSIDs, interface, ETW), named objects (events, ALPC ports), exit codes.

Don't include a PE header section (machine, timestamp, linker version, subsystem, PDB GUID…): the
user doesn't find it useful.

## 3. Page structure

Follow `template.md` (next to this file):

- H2 title `## <Name>.exe` keeping the binary's own capitalisation; H3 sections.
- Intro: one line role, then what the binary really does and which other binaries carry the logic.
- Single-line facts end with **two trailing spaces**.
- Imports table `| DLL | Functions |`, followed by one sentence on what is CRT boilerplate.
- `### Dependencies` right after the imports: `| File | How | Use |` with every other file the
  binary depends on (not the static imports). Omit the section only if there is none.
- No startup section: a `### Parameters` table `| Command line | Usage | Exit code | Started by |`
  (drop the columns that have no content), or one sentence when the command line isn't used.
- Functions reached from the parameters described in prose / numbered lists (calls made, with real
  API and type names, arguments that matter, branches, return value). **Never print decompiled or
  pseudocode functions** (no Hex-Rays output, cleaned up or not, no C blocks rebuilt from it);
  decompile only to understand, then describe.
- Include only sections that have content.
- Link driver pages as `[x.sys](../drivers/x.md)` and other application pages as `[x.exe](./x.md)`.

## 4. Finish

1. Write `content/applications/<basename>.md`.
2. Add `[Name.exe](./<basename>.md)  ` to `content/applications/README.md` (keep the file's line
   endings, each line ends with two spaces; replace a `TODO` entry if there is one). The root
   `README.md` already links that index.
3. Propagate findings: grep `content/drivers` and `content/applications` for the IOCTL codes, GUIDs,
   device names and registry values the application uses, and add the reverse view where the page
   has a matching section (e.g. `This IOCTL is also sent by Alarms_NoUI.exe`). Same rules as
   `.claude/skills/driver-doc/SKILL.md` §5: edit only the concerned lines, don't upgrade a "?" without
   proof, list ambiguous matches for the user instead of editing.
4. Tell the user what remains unknown (and which unanalysed binary would answer it) and every other
   page you changed. Commit only if asked (convention: `add <basename>`).
