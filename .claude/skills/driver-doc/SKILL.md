---
name: driver-doc
description: Reverse-engineer a Lumia 520 / Windows Phone 8 driver (.sys, typically Qualcomm MSM8930 `qc*8930.sys`) and write its reference page in content/drivers/<name>.md, matching the existing pages (device name, registry, ETW/interface GUIDs, peer devices, one section per IOCTL with CTL_CODE breakdown and byte-level buffer tables), then add it to content/drivers/README.md. Use when the user asks to document, describe, or write up a driver, or names a .sys file to add to the drivers folder.
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
3. If a new GUID or IOCTL identifies something marked `?` / "Unknown" in another page, mention it to
   the user (don't silently edit other pages).
4. Tell the user what remains unknown. Commit only if asked (convention: `add <basename>`).
