---
name: driver-doc
description: Reverse-engineer a Lumia 520 / Windows Phone 8 driver (.sys, typically Qualcomm MSM8930 `qc*8930.sys`) and write its reference page in content/drivers/<name>.md, matching the existing pages (device name, registry, ETW/interface GUIDs, peer devices, one section per IOCTL with CTL_CODE breakdown and byte-level buffer tables), then add it to content/drivers/README.md and propagate any new findings (GUID owners, IOCTL senders/receivers, corrections) to the other existing driver pages. Use when the user asks to document, describe, or write up a driver, or names a .sys file to add to the drivers folder.
---

# Document a Windows Phone driver

Produce `content/drivers/<basename>.md` for a driver binary, in the same style as the existing pages
(`qcsmem8930.md`, `qcbms8930.md`, `qcsmsm8930.md`, `acpitime.md`, …). Read one or two of them first
if you have not already in this session — `qcbms8930.md` is the most complete recent example,
`qcsmem8930.md` the shortest.

The pages are reverse-engineering notes for the Lumia 520 (MSM8930 SoC, WP8.x). Their value is
concrete, verifiable facts: exact IOCTL codes, buffer sizes, byte layouts, GUIDs, registry values,
hardcoded physical addresses. Prefer "?" over a guess; mark tentative interpretations with a trailing "?".

## 1. Locate the input

- Driver name from the user (e.g. `qcscm8930.sys`). File name of the page = lowercase basename + `.md`
  (`qcscm8930.md`). Check `content/drivers/README.md`: it may already list the driver as `TODO`.
- Binary: ask for the path if not given, or use an IDA database the user already has open
  (`mcp__ida__list_databases`). Analyse it with the `mcp__ida__*` tools (decompile, xrefs, strings,
  imports) — load them with ToolSearch first.
- Hex-Rays often fails on functions protected by a stack cookie (they call `__security_push_cookie` /
  `__security_pop_cookie`) with "function frame is wrong" (`decompile` returns None). Read those
  functions from the disassembly instead (e.g. dump `idautils.FuncItems` + `idc.generate_disasm_line`
  to a file in the scratchpad). Don't try to fix the decompilation error (frame size, reanalysis, …).
- The user may also supply runtime evidence (ETW traces, QXDM logs, hex dumps of buffers, registry
  exports). Use it for the "Value" / example columns; label values as observed ("e.g.").

## 2. What to extract (in this order of priority)

1. **Role** — `DriverEntry`, `EvtDriverDeviceAdd`, `EvtDevicePrepareHardware`, embedded description strings.
2. **Device name / symbolic link** — `WdfDeviceInitAssignName`, `IoCreateDevice`, `WdfDeviceCreateSymbolicLink`
   (`\Device\X`, `\DosDevices\X`).
3. **Registry** — `WdfDriverOpenParametersRegistryKey`, `RtlQueryRegistryValues`, `WdfRegistryQuery*`:
   value names, types, defaults.
4. **GUIDs** — ETW provider (`EtwRegister` / WPP control GUID), `WdfDeviceCreateDeviceInterface`,
   `IoRegisterPlugPlayNotification` / `IoGetDeviceInterfaces` targets (= peer drivers), `WdfDeviceAddQueryInterface`,
   UEFI variable GUIDs. Always write GUIDs in braces inside backticks. Cross-reference GUIDs already
   named in other pages (grep `content/drivers`) to identify peer drivers.
5. **Peer devices** — every `IoGetDeviceObjectPointer`, `WdfIoTargetOpen`, `ZwCreateFile` target → the
   "It communicates with the following devices" table.
6. **IOCTLs received** — the `EvtIoDeviceControl` / `EvtIoInternalDeviceControl` switch; for each code:
   length checks (min/exact/max), buffer parsing, what the handler does, NTSTATUS returned.
7. **IOCTLs sent** — `WdfIoTargetSendIoctlSynchronously`, `IoBuildDeviceIoControlRequest`, `WdfIoTargetFormatRequestForIoctl`:
   code, target, buffer contents.
8. **Anything specific**: hardcoded physical addresses (`MmMapIoSpace`), register write sequences,
   memory resources, SMD channel names, files read (`.PROVISION`, `.mbn`), function-pointer tables
   returned through IOCTLs or query-interfaces, log strings.

Decode each IOCTL with the bundled script (never by hand):

```
python .claude/skills/driver-doc/scripts/ioctl.py 0x80180FA0 0x22003
```

"internal IOCTL" = handled by `EvtIoInternalDeviceControl` / `IRP_MJ_INTERNAL_DEVICE_CONTROL`, "IOCTL" otherwise.

## 3. Page structure

Follow `template.md` (next to this file). Rules taken from the existing pages:

- H2 title `## <Name>.sys` (first letter capitalised, e.g. `## Qcsmsm8930.sys`); H3 per IOCTL / GUID
  section; H4 for sub-commands (e.g. `#### Command 0x801 "Load image"`).
- Short intro: one-line role, then a few lines on behaviour and dependencies.
- Single-line facts end with **two trailing spaces** (markdown line break), e.g. `Device name : \`\Device\SMEM\`  `.
- Include only sections that have content; for registry write "There's no parameters in the registry." when true.
- Tables: `| Registry value | value | comment |`, `| Device | Driver | Comment |`,
  `| Property | Value |` (Device/Function/Access/Method), `| Name | [Device name |] InputBuffer size | OutputBuffer Size |`
  (Device name column only for IOCTLs this driver sends), buffers as `| Bytes | Value | Comment |` with
  ranges `00-03`, little-endian hex bytes `01 00 00 00`.
- IOCTL heading: `### IOCTL 0x<UPPERHEX>` or `### internal IOCTL 0x<UPPERHEX>`, optionally `— <SYMBOLIC_NAME>`;
  first line says `This IOCTL is processed by X.sys` or `This IOCTL is sent by X.sys to Y.sys`.
  Separate IOCTL sections with `---` when there are many.
- Sizes in decimal bytes; codes, addresses and offsets in hex.
- Name functions with the names found in the binary / IDA (renamed ones), and give the IDA address
  (`sub_42E040`, `.data:0x004191A8`) when it helps someone reopen the analysis.
- Call out misleading names, no-op stubs, or dangerous side effects explicitly (see `qcbms8930.md`).
- Use `> [!NOTE]` for important caveats (e.g. kernel-mode only).
- Tables listing Lumia-specific facts (channel names, memory regions, file lists) are welcome.
- Link other driver pages relatively (`[qcsmd8930.sys](./qcsmd8930.md)`) and external references by URL.

## 4. Finish

1. Write `content/drivers/<basename>.md`.
2. Update `content/drivers/README.md` (CRLF line endings, each line ends with two spaces):
   replace an existing `[name.sys TODO](./name.md)` entry with `[name.sys](./name.md)`, or append
   `[name.sys](./name.md)  ` at the end.
3. Propagate the new findings to the other existing pages (see §5).
4. Tell the user what remains unknown, and list every other page you changed in §5 with a one-line
   summary of each change. Commit only if asked (convention: `add <basename>`; include the
   propagated edits in the same commit).

## 5. Propagate new information to existing pages

Whenever the analysis reveals something about a driver that other pages already mention, update
those pages automatically — don't just report it. This applies both when writing a new page and
when new information about an already documented driver turns up (e.g. while analysing a peer).

1. For each fact found, grep `content/drivers` for it: GUIDs (with and without braces, any case),
   IOCTL codes (`0x` + upper and lower hex), device names / symbolic links (`\Device\X`), driver
   names, SMD channel names, physical addresses, registry value names, exported/query-interface
   function names.
2. In every matching page, update the related entry when the new fact adds to or corrects it:
   - fill in a `?` / "Unknown" / empty cell (e.g. a GUID's owner in a peer-devices table, the
     driver that processes an IOCTL, a buffer field's meaning);
   - turn a plain driver name into a relative link to its page (`[qcsmd8930.sys](./qcsmd8930.md)`);
   - add the reverse view where the page has a matching section: an IOCTL sent by the new driver
     to a documented driver goes into the receiver's page as `This IOCTL is also sent by X.sys`
     (or as a row in its peer table), and an IOCTL the new driver processes that another page
     sends gets its "Device name" / target filled in;
   - correct a statement the binary contradicts, keeping the page's style, and tell the user what
     was wrong.
3. Edit only the specific lines/cells concerned: keep each page's structure, wording, line endings
   and trailing double spaces. Don't add whole new sections to another page beyond the reverse-view
   entries above, and don't upgrade a tentative "?" to a certainty unless the binary proves it.
4. If the new fact only partially matches (ambiguous GUID owner, conflicting buffer sizes, …),
   don't edit — list it for the user instead.
5. If the new driver is listed as `TODO` in `README.md` and referenced by other pages as plain text,
   link those references too.
