## Qcchipinfo8930.sys

Chip Information Driver (ChipInfo).  
At start it reads the JTAG ID register of the SoC once, decodes it into a chip id, a chip family and a chip version with tables embedded in the driver (port of the Qualcomm DAL `ChipInfo`, list of 158 chip names from `UNKNOWN` to `APQ8030AB`), then answers 5 IOCTLs that each return one of these values as a DWORD.  
It's used by [qcsmd8930.sys](./qcsmd8930.md) and [qcsmsm8930.sys](./qcsmsm8930.md) (RIVA interrupt workaround for the MSM8960 v1) and by [qcdiagrouter8930.sys](./qcdiagrouter8930.md) (Build-ID answer of the DIAG command `0x7C`).  
PDB path: `P:\ChipInfo\rel\8.2.1.1\kmdf\ChipInfo\arm\Release\qcchipinfo8930.pdb`.

The driver doesn't assign a device name (no `WdfDeviceInitAssignName`): the symbolic link points to the name of the PDO.  
Symbolic link : `\??\QCOM_ChipInfo`  

There's no parameters in the registry.  

GUID of the ETW provider (WPP):  
`{cc9682a6-d94e-45d2-8ae3-19cbfa24acfd}`  

It doesn't communicate with any other device. It only imports `ntoskrnl.exe` and `WDFLDR.SYS`.  
`IoUnregisterPlugPlayNotification` is imported and called by the device cleanup callback (`sub_401648`), but the handle in the device context is never set (no `IoRegisterPlugPlayNotification`): dead code.

Drivers using qcchipinfo8930.sys:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\SMD | [qcsmd8930.sys](./qcsmd8930.md) | Through the interface. [IOCTL 0x8C1F2008](#ioctl-0x8c1f2008) and [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004) |
| \Device\SMSM | [qcsmsm8930.sys](./qcsmsm8930.md) | Through the interface. [IOCTL 0x8C1F2008](#ioctl-0x8c1f2008) and [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004) |
| ? | [qcdiagrouter8930.sys](./qcdiagrouter8930.md) | Through `\??\QCOM_ChipInfo`. [IOCTL 0x8C1F2014](#ioctl-0x8c1f2014) |

### WDF configuration

`EvtDriverDeviceAdd` (0x4083E8) sets a no-op `EvtDeviceSurpriseRemoval` (`nullsub_1`), then calls `sub_401508` which calls `WdfDeviceInitSetPnpPowerEventCallbacks` again and so replaces it:
- `EvtDevicePrepareHardware` = `sub_401278`, see [JTAG ID register](#jtag-id-register).
- `EvtDeviceReleaseHardware` = `sub_401384`: unmaps the register.
- `EvtDeviceD0Entry` = `sub_401418`, `EvtDeviceD0Exit` = `sub_401490`: do nothing (`STATUS_SUCCESS`).
- `WdfDeviceCreateDeviceInterface` with `{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}`, then `WdfDeviceCreateSymbolicLink` `\??\QCOM_ChipInfo`.
- One default sequential queue (`sub_4018EC`), not power managed, with `EvtIoDeviceControl` (0x4017BC) and `EvtIoInternalDeviceControl` (0x401880). Both accept the same 5 codes and call the same handler (`sub_4016A8`), so the IOCTLs can be sent from user mode or kernel mode.

### JTAG ID register

`EvtDevicePrepareHardware` (`sub_401278`, 0x401278):
1. Takes the translated resource descriptor 0. If it's a `CmResourceTypeMemory`, maps it with `MmMapIoSpace(MmNonCached)`. A mapping failure â†’ `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A).
2. Reads the first DWORD (after a `DSB`). It has the layout of a JTAG IDCODE:

| Bits | Comment |
|------|---------|
| 31-28 | Version (hardware revision). Stored as raw value, see [IOCTL 0x8C1F200C](#ioctl-0x8c1f200c) |
| 27-12 | Part number = JTAG id. Stored as raw value, see [IOCTL 0x8C1F2010](#ioctl-0x8c1f2010) |
| 11-0 | Manufacturer (0x0E1 for Qualcomm ?). Ignored |

3. Looks for the JTAG id in the table `dword_405128` (272 pairs {JTAG id, chip id}) â†’ chip id (0 = `UNKNOWN` if not found).
4. Chip id â†’ chip family with the table `off_403690` (182 entries of 12 bytes: name, family, ? ; only 158 are filled). A chip id â‰¥ 182 or not found â†’ family 0.
5. Family + version bits â†’ chip version (`sub_401084`, see [Chip version](#chip-version)).

The physical address of the register isn't in the binary: it comes from the ACPI `_CRS` of the device (?).

> [!NOTE]
> If the resource descriptor 0 isn't a memory resource, the mapping is skipped but the register is still read through a NULL pointer: the system crashes.

Device context (`DEVICE_CONTEXT`):  
| Offset | Comment |
|--------|---------|
| 0x00 | PnP notification handle (always NULL) |
| 0x04 | Default queue |
| 0x0C | Virtual address of the register |
| 0x10 | Length of the mapping |
| 0x14 | Chip version, [IOCTL 0x8C1F2004](#ioctl-0x8c1f2004) |
| 0x18 | Raw version bits 31-28, [IOCTL 0x8C1F200C](#ioctl-0x8c1f200c) |
| 0x20 | Chip id, [IOCTL 0x8C1F2008](#ioctl-0x8c1f2008) |
| 0x24 | Raw JTAG id bits 27-12, [IOCTL 0x8C1F2010](#ioctl-0x8c1f2010) |
| 0x28 | Chip family, [IOCTL 0x8C1F2014](#ioctl-0x8c1f2014) |

### Chip ids

Extract of the tables for the chips close to the MSM8930/MSM8227 (the Lumia 520 SoC is a MSM8227):  
| Chip id | Name | JTAG ids | Family | 3rd field ? |
|---------|------|----------|--------|-------------|
| 87 (0x57) | MSM8960 | 0x6B0-0x6BF | 22 (0x16) | 255 |
| 116 (0x74) | MSM8930 | 0x720-0x729 | 26 (0x1A) | 255 |
| 117 (0x75) | MSM8630 | 0x730, 0x731 | 26 (0x1A) | 255 |
| 118 (0x76) | MSM8230 | 0x750-0x755 | 26 (0x1A) | 255 |
| 119 (0x77) | APQ8030 | 0x760, 0x761 | 26 (0x1A) | 0 |
| 120 (0x78) | MSM8627 | 0x7C0, 0x7C1 | 30 (0x1E) | 255 |
| 121 (0x79) | MSM8227 | 0x7D0, 0x7D1 | 30 (0x1E) | 255 |
| 122 (0x7A) | MSM8660A | 0x7A0-0x7A3 | 22 (0x16) | 255 |
| 123 (0x7B) | MSM8260A | 0x790-0x79B | 22 (0x16) | 255 |
| 124 (0x7C) | APQ8060A | 0x780-0x783 | 22 (0x16) | 0 |
| 126 (0x7E) | MSM8974 | ? | 32 (0x20) | 255 |
| 130 (0x82) | MPQ8064 | ? | 34 (0x22) | 0 |
| 142 (0x8E) | MSM8930AA | 0x72A-0x72F | 26 (0x1A) | 495 |
| 143 (0x8F) | MSM8630AA | 0x73A, 0x73B | 26 (0x1A) | 367 |
| 144 (0x90) | MSM8230AA | 0x75A-0x75F | 26 (0x1A) | 268 |
| 154 (0x9A) | MSM8930AB | 0x890-0x897 | 37 (0x25) | 495 |
| 155 (0x9B) | MSM8630AB | 0x732, 0x733 | 37 (0x25) | 367 |
| 156 (0x9C) | MSM8230AB | 0x8A0-0x8A5 | 37 (0x25) | 268 |
| 157 (0x9D) | APQ8030AB | 0x762, 0x763 | 37 (0x25) | 0 |

The names of the families aren't in the binary; the family is named after its first chip here: 22 = MSM8960, 26 = MSM8930, 30 = MSM8627, 32 = MSM8974, 34 = APQ8064, 37 = MSM8930AB.  
The 3rd field looks like a bit mask (modem / features ?); it isn't used by the driver.  
So the Lumia 520 should return chip id 121 (0x79) and family 30 (0x1E) ?

### Chip version

`sub_401084` converts the version bits 31-28 (`v`) into a version `major << 16 | minor`. The conversion depends on the family:  
| Family | v=0 | v=1 | v=2 | v=3 | v=4 | v=5 | v=6 | v=7 | v â‰¥ 8 |
|--------|-----|-----|-----|-----|-----|-----|-----|-----|-------|
| 10, 18 (MSM7630, MSM8260) | 1.0 | 2.0 | 2.1 | 2.2 | â€¦ | | | | 2.(v-1) |
| 13, 34 (QSD8650, APQ8064) | 1.0 | 1.2 | 2.0 | 2.1 | â€¦ | | | | 2.(v-2) |
| 16 (MDM8220) | 1.0 | 1.1 | 2.0 | 2.2 | â€¦ | | | | 2.(v-1) |
| 22 (MSM8960) | 1.0 | 1.1 | 2.0 | 2.1 | 3.1 | 4.0 | 3.2 | 4.1 | 4.(v-6) |
| 25 (MDM9615) | 1.0 | 1.1 | 2.0 | 2.1 | 2.2 | 2.3 | 2.4 | 3.0 | 2.(v-2) |
| 26, 37 (MSM8930, MSM8930AB) | 1.0 | 0xFFFFFFFF | 1.2 | 2.0 | 2.2 | 2.3 | â€¦ | | 2.(v-2) |
| other (including 30, MSM8627) | 1.v | | | | | | | | 1.v |

For the families 26 and 37, `v`=1 falls into the generic case `(v-2) | 0x20000`, which gives 0xFFFFFFFF (bug ?).

---

### IOCTL 0x8C1F2004

This IOCTL is processed by Qcchipinfo8930.sys (`sub_4016A8`, 0x4016A8)

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x801 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get chip version | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 01 00 | Chip version, `major << 16 \| minor` (e.g. 1.0), see [Chip version](#chip-version) |

Sent by [qcsmd8930.sys](./qcsmd8930.md#ioctl-0x8c1f2004) and [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x8c1f2004): the RIVA workaround is applied when the version is lower than 2.0.

Common behaviour of the 5 IOCTLs:
- The InputBuffer is ignored.
- The handler calls `WdfRequestRetrieveOutputBuffer` with a minimum size of 0, then writes 4 bytes **without checking the length**: an OutputBuffer of 1 to 3 bytes is overflowed.
- No OutputBuffer â†’ `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A), not `STATUS_BUFFER_TOO_SMALL`.
- Success â†’ `STATUS_SUCCESS`, `BytesReturned` = 4.
- Any other IoControlCode â†’ `STATUS_INVALID_DEVICE_REQUEST` (0xC0000010).

---

### IOCTL 0x8C1F2008

This IOCTL is processed by Qcchipinfo8930.sys (`sub_4016A8`, 0x4016A8)

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get chip id | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 79 00 00 00 | Chip id (e.g. 121 = MSM8227 ?), see [Chip ids](#chip-ids). 0 = `UNKNOWN` |

Sent by [qcsmd8930.sys](./qcsmd8930.md#ioctl-0x8c1f2008) and [qcsmsm8930.sys](./qcsmsm8930.md#ioctl-0x8c1f2008): the RIVA workaround is applied when the chip id is 87 (MSM8960), so never on the Lumia 520.

---

### IOCTL 0x8C1F200C

This IOCTL is processed by Qcchipinfo8930.sys (`sub_4016A8`, 0x4016A8)

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get raw version | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | ? | Bits 31-28 of the JTAG ID register (0 to 15) |

No caller found.

---

### IOCTL 0x8C1F2010

This IOCTL is processed by Qcchipinfo8930.sys (`sub_4016A8`, 0x4016A8)

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get raw JTAG id | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | D0 07 00 00 | Bits 27-12 of the JTAG ID register (e.g. 0x7D0 for a MSM8227 ?) |

No caller found.

---

### IOCTL 0x8C1F2014

This IOCTL is processed by Qcchipinfo8930.sys (`sub_4016A8`, 0x4016A8)

| Property | Value |
|----------|-------|
| Device | 0x8C1F |
| Function | 0x805 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|-------------------|
| Get chip family | 0 | 4 |

Outputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 1E 00 00 00 | Chip family (e.g. 30 = MSM8627 family ?), see [Chip ids](#chip-ids). 0 if the chip is unknown |

Sent by [qcdiagrouter8930.sys](./qcdiagrouter8930.md#ioctl-0x8c1f2014) through `\??\QCOM_ChipInfo`, which converts the family into the MSM "tools ID" of the DIAG command `0x7C`.

---

### Interface GUID

Qcchipinfo8930 Interface Class GUID (`WdfDeviceCreateDeviceInterface`)  
`{fb4f07cd-8d4c-4413-92c2-e2c9caed9f43}`
