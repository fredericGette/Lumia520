## Qcuart8930.sys

UART driver for the UARTDM cores of the GSBI blocks (Qualcomm KMDF driver, PDB `P:\UART\rel\8.2.1\arm\Release\qcuart8930.pdb`).  
It exposes a classic serial port (`FILE_DEVICE_SERIAL_PORT`, `\DosDevices\COMn`) with the standard `IOCTL_SERIAL_*` interface. It's a port of the Qualcomm DAL UART driver (`Uart_Open`, `Uart_Read`, `Uart_SetRate`… in the traces): the UART registers, the GPIOs, the ADM data mover (DMOV) channels and the clocks are taken from property tables compiled into the binary, selected with the ACPI method `INFO` of the device node. Clocks and GPIOs are switched through the power framework (PEP) with `PoFxPowerControl`.  
Reads and writes are synchronous: each one is executed by a dedicated system thread, from a 2048-byte RX ring buffer filled by the interrupt / DMA path.  
It can be opened directly (`\DosDevices\COMn`), or through the resource hub (`\Device\RESOURCE_HUB\<id>`), in which case the port is configured from the `UartSerialBus` descriptor of the connection. [qcdiagrouter8930.sys](./qcdiagrouter8930.md) uses it this way for its UART transport.

> [!NOTE]
> There's no UART node in the Lumia 520 ACPI tables (no `_HID` for this driver, no `INFO` method returning a UART device, no `UartSerialBus` resource). So this driver isn't started on the retail Lumia 520, and the UART transport of qcdiagrouter8930.sys (`\DosDevices\COM5`) can't work.

There's no named `\Device\` object (the WDF device is unnamed).  
Symbolic link : `\DosDevices\COM1` … `\DosDevices\COM12`  
The number is the last character of the device instance id (`DEVPKEY_Device_InstanceId` `{78c34fc8-104a-4aca-9ea4-524d52996e57}`, 256), read as a hexadecimal digit: instance `…\5` → `COM5`, `…\C` → `COM12`. Any other value (0, or more than 12) → no symbolic link and the device add fails. The instance id is normally the ACPI `_UID`, which is the GSBI number (see [Property tables](#property-tables)).

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcuart8930`  

There's no parameters in the registry.

GUID of the ETW provider (WPP control GUID, registered with `EtwRegisterClassicProvider`):  
`{ce22e47e-2675-49c8-9d20-790bdaca429b}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| ACPI node of the device (attached device) | acpi.sys | [IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method) `INFO` |
| `\Device\RESOURCE_HUB` | [acpiex.sys](./acpiex.md) | [IOCTL 0x2AC000](#ioctl-0x2ac000--ioctl_rh_query_connection_properties), only when the port is opened through the resource hub |
| Power framework (PEP) | [qcpep8930.sys](./qcpep8930.md#3404daac-set-p-state) | `PoFxRegisterDevice` + `PoFxPowerControl`, see [Power management](#power-management) |
| UART / GSBI / TCSR / ADM / GIC / clock controller registers | — | Mapped directly with `MmMapIoSpace`, addresses from the [property tables](#property-tables) |

Pool tags: `qua0` (driver, `WDF_DRIVER_CONFIG.DriverPoolTag`), `qua1` (`\DosDevices\COMn` string), `qua2` (resource hub connection properties), `quaa` (UART context, 512 bytes), `quab` (RX ring buffer, 2048 bytes), `quaC` (interrupt context, 76 bytes).

### Device setup

`EvtDriverDeviceAdd` (0x401668):
- PnP callbacks: `EvtDevicePrepareHardware` (0x402F20) and `EvtDeviceReleaseHardware` (0x4033E4) only. No D0 entry/exit, no idle settings.
- `WdfDeviceInitAssignWdmIrpPreprocessCallback` for every major function, so most IRPs never reach WDF:

| Major function | Handler | Behaviour |
|----------------|---------|-----------|
| `IRP_MJ_CREATE` | sub_401A88 | See [Open](#open) |
| `IRP_MJ_CLOSE` | sub_4019E4 | Decrements the open count, calls `Uart_Close` |
| `IRP_MJ_READ`, `IRP_MJ_WRITE` | WDF | Two sequential queues (`EvtIoRead` 0x401F04, `EvtIoWrite` 0x401F94), see [Read and write](#read-and-write) |
| `IRP_MJ_DEVICE_CONTROL` | sub_401DD0 | `IOCTL_SERIAL_*` dispatcher sub_405510, completed synchronously in the caller's thread, see [IOCTLs](#ioctls) |
| `IRP_MJ_CLEANUP` | sub_401964 | Completed with `STATUS_SUCCESS`, nothing else (pending reads/writes aren't cancelled) |
| `IRP_MJ_POWER`, `IRP_MJ_SYSTEM_CONTROL`, `IRP_MJ_PNP` | WDF | |
| Any other (including `IRP_MJ_INTERNAL_DEVICE_CONTROL`) | sub_401BC4 | `STATUS_NOT_IMPLEMENTED` (0xC0000002) |

- `WdfDeviceInitSetExclusive(FALSE)`, `WdfDeviceInitSetDeviceType(FILE_DEVICE_SERIAL_PORT)`, `WdfDeviceIoBuffered`.
- 2 system threads (sub_403060 for the reads, sub_40314C for the writes), see [Read and write](#read-and-write).
- `IoRegisterDeviceInterface` with `GUID_DEVINTERFACE_COMPORT`, then the `\DosDevices\COMn` symbolic link (sub_402024), then `IoSetDeviceInterfaceState(TRUE)`.

`EvtDevicePrepareHardware`:
1. sub_402498 reads the resources. Exactly one `CmResourceTypeMemory` and one `CmResourceTypeInterrupt` are required, otherwise `STATUS_INSUFFICIENT_RESOURCES` (0xC000009A). The interrupt (level, vector, affinity, latched/level-sensitive, shared) is connected later with `IoConnectInterrupt` (sub_408210). The UART registers are mapped from the `UartBase` property, not from the memory resource.
2. sub_402210 evaluates the ACPI method `INFO` ([IOCTL 0x32C004](#ioctl-0x32c004--ioctl_acpi_eval_method)): table index, DAL device id, and an optional third value.
3. sub_409754 selects the [property table](#property-tables) with the table index, and records which DAL device owns the DMOV CRCIs.
4. Reads the `Irq` property of the DAL device.
5. sub_40913C registers the DAL device with the power framework (see [Power management](#power-management)).
6. sub_4051B4 allocates the UART context and the RX buffer, sets the default timeouts and properties, then:
   - sub_403F10 (table 0 only): writes `UART_SEL` and the `GPIO_CONFIG` registers of GPIO 41/42 (GSBI6) or 117/118 (GSBI12) in the block at 0x1D000000.
   - sub_4037F8: routes the CRCIs of the UART to the ADM in the TCSR (`TCSR_ADM_x_y_CRCI_MUX_SEL`) and sets the ADM `HI_CRCIn_CTL` registers (see [DMA](#dma)).
   - `dal_uart_attach` (sub_407EDC) and `Uart_DeviceInit`.

### Open

`IRP_MJ_CREATE` (sub_401A88):
1. If the `FILE_OBJECT` has a file name, the open comes from the resource hub (acpiex.sys reopens the controller with the connection id as file name, see [acpiex.sys](./acpiex.md#opening-a-connection-deviceresource_hubid)):
   1. sub_402980 parses the name (leading `\` skipped, at most 16 hexadecimal digits) into a 64-bit connection id. Invalid → `STATUS_UNSUCCESSFUL` (0xC0000001).
   2. sub_403238 gets the connection properties from `\Device\RESOURCE_HUB` ([IOCTL 0x2AC000](#ioctl-0x2ac000--ioctl_rh_query_connection_properties)).
   3. sub_402A5C converts the `UartSerialBus` descriptor into an initial configuration, see [UartSerialBus descriptor](#uartserialbus-descriptor).
2. sub_406378 opens the port with `Uart_OpenEx` (→ `mu_open`, sub_40AA48). The port is exclusive: if it's already open → `STATUS_UNSUCCESSFUL`. Without a configuration from the resource hub, the defaults are used:

| Setting | Default | Comment |
|---------|---------|---------|
| Baud rate | 115200 | |
| Line control | 8 data bits, no parity, 1 stop bit | |
| `SERIAL_HANDFLOW.ControlHandShake` | 0x08 | `SERIAL_CTS_HANDSHAKE`: TX waits for CTS |
| `SERIAL_HANDFLOW.FlowReplace` | 0x80 | `SERIAL_RTS_HANDSHAKE`: RFR driven by the hardware |
| XonLimit, XoffLimit | 0 | |

This configuration is also saved, and restored by [IOCTL_SERIAL_APPLY_DEFAULT_CONFIGURATION](#ioctls).  
sub_406378 converts it to the DAL values below. A value that can't be converted gives 0x7FFFFFFF and the open fails:

| Field | Windows value → DAL value |
|-------|---------------------------|
| Parity | `NO_PARITY` 0 → 1, `ODD_PARITY` 1 → 2, `EVEN_PARITY` 2 → 4, `MARK_PARITY` 3 → invalid, `SPACE_PARITY` 4 → 8 |
| Word length | 5 → 1, 6 → 2, 7 → 4, 8 → 8 |
| Stop bits | `STOP_BIT_1` 0 → 2, `STOP_BITS_1_5` 1 → 4, `STOP_BITS_2` 2 → 8 |
| RFR | 2 (automatic) if `FlowReplace` & `SERIAL_RTS_HANDSHAKE`, else 0 |
| CTS | 1 (TX flow control) if `ControlHandShake` & `SERIAL_CTS_HANDSHAKE`, else 0 |

### UartSerialBus descriptor

Output of [IOCTL 0x2AC000](#ioctl-0x2ac000--ioctl_rh_query_connection_properties), parsed by sub_402A5C. Offsets are in the output buffer (the ACPI descriptor starts at 08). A mismatch on a checked field → `STATUS_UNSUCCESSFUL`.  
| Bytes | Value | Comment |
|-------|-------|---------|
| 04-07 | ≥ 22 | Length of the properties. More than 22: the resource source name at 1E is only traced |
| 08 | 8E | Serial Bus Connection descriptor |
| 09-0A | | Descriptor length, must be (length of the properties − 3) |
| 0B | 01 | Revision |
| 0C | 00 | Resource source index |
| 0D | 03 | Serial bus type: UART |
| 0F-10 | | Type-specific flags. Bits 1:0 flow control: 0 = none, 1 = hardware (CTS/RTS, see byte 1D), 2 = XON/XOFF → rejected. Bits 3:2 stop bits: 1 = 1, 2 = 1.5, 3 = 2, 0 = none → rejected. Bits 6:4 data bits: 0 = 5 … 3 = 8, 4 = 9 |
| 11 | 01 | Type-specific revision |
| 12-13 | 0A 00 | Type data length: 10 |
| 14-17 | | Baud rate |
| 1C | | Parity: 0 none, 1 even, 2 odd, 3 mark, 4 space |
| 1D | | Serial lines enabled, used only with hardware flow control: bit 6 (CTS) → `SERIAL_CTS_HANDSHAKE`, bit 7 (RTS) → `SERIAL_RTS_HANDSHAKE` |

The receive / transmit FIFO sizes of the descriptor are ignored.

### Read and write

`EvtIoRead` / `EvtIoWrite` store the request in the context of the read or write thread (only one at a time: the queues are sequential), mark it cancelable and signal the thread. The thread calls sub_406634 (read) or sub_4069F4 (write) on the IRP's system buffer, then completes the request with the number of bytes transferred.

Read (sub_406634): copies data from the 2048-byte RX ring buffer, and waits for more data according to the `SERIAL_TIMEOUTS` (standard semantics: `ReadIntervalTimeout` = MAXULONG with total timeouts 0 returns immediately). An `IOCTL_SERIAL_PURGE` `SERIAL_PURGE_RXABORT` ends the read: `STATUS_CANCELLED` (0xC0000120) if no byte was read, otherwise success.

Write (sub_4069F4): starts the transmission (`transmit_chunk`, sub_40BD20) and waits for the "TX complete" event with a timeout of `WriteTotalTimeoutMultiplier` × length + `WriteTotalTimeoutConstant` (no timeout when both are 0, then it also polls `Uart_TxComplete` every 1 ms). `SERIAL_PURGE_TXABORT` → `STATUS_CANCELLED`. While a break is set (`IOCTL_SERIAL_SET_BREAK_ON`) → 0xC0000433.

Both return `STATUS_INVALID_HANDLE` (0xC0000008) if the port isn't open, and `STATUS_INVALID_PARAMETER` (0xC000000D) for a 0-byte buffer.

Default timeouts (milliseconds):  
| Field | Value |
|-------|-------|
| ReadIntervalTimeout | 250 |
| ReadTotalTimeoutMultiplier | 10 |
| ReadTotalTimeoutConstant | 100 |
| WriteTotalTimeoutMultiplier | 0 |
| WriteTotalTimeoutConstant | 0 |

### Property tables

The DAL properties are compiled into the binary: 4 tables (`.data:0x0041356C`, `0x0041373C`, `0x00413654`, `0x004133EC`), selected by the first value returned by `INFO` (0, 1, 2, 3). Each table lists DAL devices; the second value of `INFO` is the DAL device id of the UART.  
DAL device ids of the UARTs (from sub_409310): 0x02000086 … 0x0200008A = GSBI1 … GSBI5, 0x02000132 … 0x02000138 = GSBI6 … GSBI12. The PoFx table also has 0x020000BF (?).

Common entries:  
| DAL device | Table 0 | Tables 1, 2, 3 | Comment |
|------------|---------|----------------|---------|
| 0x02000020 | 0x00800000, 0x2000 | 0x00800000, 0x2000 | `Base`, `Length`. TLMM (GPIO) |
| 0x02000004 | 0x02080000, 0x1000 | 0x02000000, 0x1000 | `Base`, `Length`. GIC distributor: sub_407BF4 reads the enable bit of the UART interrupt (`GICD_ISENABLER`, +0x100), for the traces only |
| 0x02000145 | 0x00900000, 0x3000 | 0x00900000, 0x3000 | `Base`, `Length`. Clock controller: `GSBI_HCLK_CTL`, `GSBI_UART_APPS_MD` / `NS` are read for the traces only |

UART devices:  
| Table | DAL device | GSBI | Irq | GsbiBase | UartBase | TxData | RxData | CtsN | RfrN | DMOV_DEV | CHAN RX/TX | CRCI RX/TX |
|-------|------------|------|-----|----------|----------|--------|--------|------|------|----------|------------|------------|
| 0 | 0x02000132 | 6 | 188 | 0x16500000 | 0x16540000 | 0x3501 | 0x23601 | 0x23701 | 0x3801 | 0x02000052 | 0 / 7 | 9 / 8 |
| 0 | 0x02000138 | 12 | 227 | 0x19C00000 | 0x19C40000 | 0x7602 | 0x27502 | — | — | 0x02000051 | 3 / 2 | 5 / 4 |
| 1, 3 | 0x0200008A | 5 | 186 | 0x16400000 | 0x16440000 | 0x1601 | 0x21701 | 0x21801 | 0x1901 | 0x02000051 | 3 / 4 | 9 / 10 |
| 1 | 0x02000132 | 6 | 188 | 0x16500000 | 0x16540000 | 0x1A02 | 0x21B02 | 0x21C02 | 0x1D02 | 0x02000051 | 7 / 8 | 11 / 6 |
| 2 | 0x02000132 | 6 | 188 | 0x16500000 | 0x16540000 | 0x0E02 | 0x20F02 | 0x21002 | 0x1102 | 0x02000051 | 8 / 9 | 11 / 6 |
| 2 | 0x02000133 | 7 | 190 | 0x16600000 | 0x16640000 | 0x5202 | 0x25301 | 0x25402 | 0x5503 | 0x02000051 | 10 / 11 | 7 / 8 |

All UART devices also have `GsbiControl` = 0x40 (protocol code 4, "UART with flow control", see [qcgsbi8930.sys](./qcgsbi8930.md)) and `ManagePCLK` = 1. The optional property `DetectBrk` is in none of the tables (default 0). `UartBase` is required; `GsbiBase` is required when `GsbiControl` ≠ 0.  
GPIO values: bits 15:8 = GPIO number, bits 7:0 = function ?, 0x20000 set on the input pins ? (e.g. table 1, GSBI5: TX = GPIO 22, RX = 23, CTS = 24, RFR = 25).  
`DMOV_DEV` 0x02000051 / 0x02000052 / 0x0200007C = ADM 0 / 1 / 2 ?

On the MSM8930 the GSBI bases match the [Lumia 520 GSBI list](./qcgsbi8930.md#lumia-520-values) (GSBI5 = 0x16400000, GSBI6 = 0x16500000, GSBI7 = 0x16600000), with the UARTDM core at GSBI base + 0x40000. Which table is the MSM8930 one isn't known: table 0 (two ADMs, GSBI12 at 0x19C00000) is for another SoC.

### DMA

The UART data is moved by the ADM data mover (DAL `DalDmov`, `IoGetDmaAdapter` in sub_407848), with the channels and CRCIs of the property tables. sub_4037F8 configures the CRCI routing, per table:  
| Table | DAL device | TCSR (base) | ADM registers |
|-------|------------|-------------|---------------|
| 0 | 0x02000132 | 0x16B00000: `TCSR_ADM_1_A_CRCI_MUX_SEL` (+0x78) \|= 0xC00 | ADM 0x18400000 `HI_CRCI8_CTL` / `HI_CRCI9_CTL` (+0x420 / +0x424): bit 18 cleared; ADM 0x18300000 same registers: bits 2:0 cleared |
| 0 | 0x02000138 | 0x16B00000: `TCSR_ADM_0_B_CRCI_MUX_SEL` (+0x74) \|= 0xC00000 | ADM 0x18300000 `HI_CRCI4_CTL` / `HI_CRCI5_CTL` (+0x410 / +0x414): bit 18 set, bits 2:0 cleared |
| 1, 2 | 0x02000132 | 0x1A400000: `TCSR_ADM_0_A_CRCI_MUX_SEL` (+0x70) \|= 0x400, `TCSR_ADM_0_B_CRCI_MUX_SEL` (+0x74) \|= 0x20 | ADM 0x18300000 `HI_CRCI11_CTL` (+0x42C): bit 18 cleared; `HI_CRCI6_CTL` (+0x418): bit 18 set; bits 2:0 cleared |
| 2 | 0x02000133 | 0x1A400000: `TCSR_ADM_0_B_CRCI_MUX_SEL` \|= 0xC0 | ADM 0x18300000 `HI_CRCI7_CTL`, `HI_CRCI8_CTL`: bit 18 set, bits 2:0 cleared |
| 1, 3 | 0x0200008A | 0x1A400000: `TCSR_ADM_0_A_CRCI_MUX_SEL` \|= 0x300 | ADM 0x18300000 `HI_CRCI9_CTL`, `HI_CRCI10_CTL`: bit 18 cleared, bits 2:0 cleared |

### Power management

sub_40913C calls `PoFxRegisterDevice` for the PDO, with one component and one idle state (`NominalPower` 0xFFFFFFFF), and no callbacks. The handle is stored in a table of 13 entries (`.data:0x004131B0`), one per DAL device (0x020000BF, then GSBI1 … GSBI12). The device is never put idle (no `PoFxActivateComponent` / `PoFxIdleComponent`): the handle is only used for `PoFxPowerControl`.

The clocks and the GPIOs are controlled through the PEP by sub_408E80, with:  
PowerControlCode `{3404DAAC-8E2C-41E4-8458-3158E5AD442B}`  
(the same code as the P-state requests of [qcwcn8930.sys](./qcwcn8930.md#power-management) and [qcdxkm8930.sys](./qcdxkm8930.md))

Inputbuffer (8 bytes):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 00 00 00 00 | Component 0 |
| 04-07 | ? | Request, see below |

Outputbuffer (12 bytes): the request succeeds if `PoFxPowerControl` returns `STATUS_SUCCESS`, `00-03` = 3 (`PEP_STATE_SYNC_PATH`), `04-07` = 0 and `08-0B` = the request value.

| Request | Sent by | Meaning |
|---------|---------|---------|
| 0 | `gpio_enable` (sub_40A308) | UART GPIOs to their UART function |
| 1 | `gpio_disable` (sub_4098A4) | UART GPIOs released |
| 2 / 4 | power on (sub_40AFB4, sub_409BF0) | Enable the GSBI bus clock (PCLK, if `ManagePCLK`) / the UART core clock |
| 3 / 5 | power off (sub_40AE04, sub_40A6B8) | Disable the GSBI bus clock / the UART core clock |
| 6 … 16 | `set_input_freq` (sub_40BB7C → sub_4095D4), called by `Uart_SetRate` | Set the UART core clock: 6 = 7.3728 MHz, 7 = 14.7456 MHz, 8 = 16 MHz, 9 = 24 MHz, 10 = 32 MHz, 11 = 40 MHz, 12 = 48 MHz, 13 = 51.2 MHz, 14 = 56 MHz, 15 = 58.9824 MHz, 16 = 64 MHz. Any other frequency → "set_input_freq: unsupported freq" |

The GPIO requests are sent to the PoFx handle of the device that owns the GPIO in the property table (sub_409670).

---

### IOCTLs

The IOCTLs are processed by Qcuart8930.sys (sub_405510), synchronously, in the thread of the caller. They are the standard `IOCTL_SERIAL_*` codes:  
| Property | Value |
|----------|-------|
| Device | 0x1B (`FILE_DEVICE_SERIAL_PORT`) |
| Function | 0x1 … 0x28 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

If the port isn't open → `STATUS_INVALID_HANDLE` (0xC0000008). A buffer smaller than the size below, or an unknown code → `STATUS_INVALID_PARAMETER` (0xC000000D). A DAL error → `STATUS_UNSUCCESSFUL` (0xC0000001). "Not implemented" = `STATUS_NOT_IMPLEMENTED` (0xC0000002).

| IOCTL | Name | InputBuffer size | OutputBuffer Size | Behaviour |
|-------|------|------------------|-------------------|-----------|
| 0x1B0004 | IOCTL_SERIAL_SET_BAUD_RATE | ≥ 4 | 0 | `Uart_SetRate` if the rate changes (sub_4047C0). `Uart_SetRate` also selects the UART input clock (`set_input_freq`, see [Power management](#power-management)) |
| 0x1B0008 | IOCTL_SERIAL_SET_QUEUE_SIZE | ≥ 8 | 0 | Traced only (the RX buffer stays 2048 bytes) |
| 0x1B000C | IOCTL_SERIAL_SET_LINE_CONTROL | ≥ 3 | 0 | `Uart_SetCharFormat` (sub_40497C), same conversion as [Open](#open) |
| 0x1B0010 | IOCTL_SERIAL_SET_BREAK_ON | 0 | 0 | `Uart_SetBreak`; writes fail until break off |
| 0x1B0014 | IOCTL_SERIAL_SET_BREAK_OFF | 0 | 0 | `Uart_ClearBreak` |
| 0x1B0018 | IOCTL_SERIAL_IMMEDIATE_CHAR | | | Not implemented |
| 0x1B001C | IOCTL_SERIAL_SET_TIMEOUTS | ≥ 20 | 0 | Stored (`SERIAL_TIMEOUTS`) |
| 0x1B0020 | IOCTL_SERIAL_GET_TIMEOUTS | | ≥ 20 | |
| 0x1B0024 | IOCTL_SERIAL_SET_DTR | 0 | 0 | Success, nothing done (no DTR line) |
| 0x1B0028 | IOCTL_SERIAL_CLR_DTR | 0 | 0 | Success, nothing done |
| 0x1B002C | IOCTL_SERIAL_RESET_DEVICE | | | Not implemented |
| 0x1B0030 | IOCTL_SERIAL_SET_RTS | 0 | 0 | `Uart_SetRtsControl(1)` (RFR asserted), clears `SERIAL_RTS_HANDSHAKE` in the stored handflow |
| 0x1B0034 | IOCTL_SERIAL_CLR_RTS | 0 | 0 | `Uart_SetRtsControl(0)`, clears `SERIAL_RTS_HANDSHAKE` |
| 0x1B0038 | IOCTL_SERIAL_SET_XOFF | | | Not implemented |
| 0x1B003C | IOCTL_SERIAL_SET_XON | | | Not implemented |
| 0x1B0040 | IOCTL_SERIAL_GET_WAIT_MASK | | ≥ 4 | |
| 0x1B0044 | IOCTL_SERIAL_SET_WAIT_MASK | ≥ 4 | 0 | Stores the mask, keeps only the pending events of the new mask, and wakes up a waiting `WAIT_ON_MASK` |
| 0x1B0048 | IOCTL_SERIAL_WAIT_ON_MASK | | ≥ 4 | See below |
| 0x1B004C | IOCTL_SERIAL_PURGE | ≥ 4 | 0 | See below |
| 0x1B0050 | IOCTL_SERIAL_GET_BAUD_RATE | | ≥ 4 | |
| 0x1B0054 | IOCTL_SERIAL_GET_LINE_CONTROL | | ≥ 3 | |
| 0x1B0058 | IOCTL_SERIAL_GET_CHARS | | ≥ 6 | Stored `SERIAL_CHARS` (default all 0) |
| 0x1B005C | IOCTL_SERIAL_SET_CHARS | ≥ 6 | 0 | Stored only, not used |
| 0x1B0060 | IOCTL_SERIAL_GET_HANDFLOW | | ≥ 16 | |
| 0x1B0064 | IOCTL_SERIAL_SET_HANDFLOW | ≥ 16 | 0 | See below |
| 0x1B0068 | IOCTL_SERIAL_GET_MODEMSTATUS | | | Not implemented |
| 0x1B006C | IOCTL_SERIAL_GET_COMMSTATUS | | ≥ 20 | See below |
| 0x1B0070 | IOCTL_SERIAL_XOFF_COUNTER | | | Not implemented |
| 0x1B0074 | IOCTL_SERIAL_GET_PROPERTIES | | ≥ 64 | See below |
| 0x1B0078 | IOCTL_SERIAL_GET_DTRRTS | | | Not implemented |
| 0x1B007C | IOCTL_SERIAL_LSRMST_INSERT | | | Not implemented |
| 0x1B0080 | IOCTL_SERIAL_CONFIG_SIZE | | ≥ 4 | Returns 0 |
| 0x1B0084 | IOCTL_SERIAL_GET_COMMCONFIG | | | Not implemented |
| 0x1B0088 | IOCTL_SERIAL_SET_COMMCONFIG | | | Not implemented |
| 0x1B008C | IOCTL_SERIAL_GET_STATS | | ≥ 24 | `SERIALPERF_STATS` |
| 0x1B0090 | IOCTL_SERIAL_CLEAR_STATS | 0 | 0 | Zeroes the statistics |
| 0x1B0094 | IOCTL_SERIAL_GET_MODEM_CONTROL | | ≥ 4 | Only bit 0x10 (`SERIAL_MCR_LOOP`) can be set |
| 0x1B0098 | IOCTL_SERIAL_SET_MODEM_CONTROL | ≥ 4 | 0 | Only bit 0x10 is used: internal loopback (`Uart_LoopbackSet`) |
| 0x1B009C | IOCTL_SERIAL_SET_FIFO_CONTROL | | | Not implemented |
| 0x1B00A0 | IOCTL_SERIAL_APPLY_DEFAULT_CONFIGURATION | 0 | 0 | Reapplies the baud rate, line control and handflow saved at [Open](#open) |

`IOCTL_SERIAL_WAIT_ON_MASK` (sub_404B70): returns `STATUS_INVALID_PARAMETER` if the wait mask is 0. If an event of the mask is already pending, returns it at once. Otherwise **it blocks the calling thread** (the IRP isn't pended: the dispatcher is synchronous) until an event, or until a `SET_WAIT_MASK` from another thread, which returns 0. The pending events are cleared.

`IOCTL_SERIAL_PURGE` (sub_404674), `SERIAL_PURGE_*` bits:  
| Bit | Name | Action |
|-----|------|--------|
| 0x1 | TXABORT | Ends the current write (`STATUS_CANCELLED`) |
| 0x2 | RXABORT | Ends the current read |
| 0x4 | TXCLEAR | `Uart_PurgeTx` |
| 0x8 | RXCLEAR | `Uart_PurgeRx` and empties the RX ring buffer |

`IOCTL_SERIAL_SET_HANDFLOW` (sub_40483C) only uses 2 bits:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | | ControlHandShake. Bit 0x08 `SERIAL_CTS_HANDSHAKE`: `Uart_SetCtsControl(1)` (TX flow control) / `(0)` when it changes |
| 04-07 | | FlowReplace. Bit 0x80 `SERIAL_RTS_HANDSHAKE`: when it's set and wasn't, `Uart_SetRtsControl(2)` (automatic RFR). Clearing it does nothing |
| 08-0B | | XonLimit, stored only |
| 0C-0F | | XoffLimit, stored only |

So the handflow sent by [qcdiagrouter8930.sys](./qcdiagrouter8930.md#ioctls-sent-to-the-uart) (0xFFFFFFF7, 0xFFFFFF7F) disables the CTS flow control and leaves the RFR setting unchanged.

`IOCTL_SERIAL_GET_COMMSTATUS` (sub_4045A4), `SERIAL_STATUS`:  
| Bytes | Comment |
|-------|---------|
| 00-03 | Errors, from `Uart_GetStatus`: status bit 0 → `SERIAL_ERROR_PARITY` (0x10), bit 1 → `SERIAL_ERROR_FRAMING` (0x02), bit 2 → `SERIAL_ERROR_OVERRUN` (0x04), bit 3 → `SERIAL_ERROR_BREAK` (0x01) |
| 04-07 | HoldReasons: `SERIAL_TX_WAITING_FOR_CTS` (1) when CTS isn't asserted (status bits 0x80 and 0x80000 both clear) |
| 08-0B | AmountInInQueue: bytes in the RX ring buffer |
| 0C-0F | AmountInOutQueue: bytes of the write in progress |
| 10 | EofReceived = 0 |
| 11 | WaitForImmediate = 0 |

`IOCTL_SERIAL_GET_PROPERTIES`, `SERIAL_COMMPROP` (fixed values set by sub_4051B4):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-01 | FF FF | PacketLength |
| 02-03 | FF FF | PacketVersion |
| 04-07 | 01 00 00 00 | ServiceMask: `SERIAL_SP_SERIALCOMM` |
| 08-0B | 00 00 00 00 | Reserved1 |
| 0C-0F | 10 00 00 00 | MaxTxQueue: 16 |
| 10-13 | 10 00 00 00 | MaxRxQueue: 16 |
| 14-17 | 00 00 02 00 | MaxBaud: `SERIAL_BAUD_115200` |
| 18-1B | 01 00 00 00 | ProvSubType: `SERIAL_SP_RS232` |
| 1C-1F | CA 00 00 00 | ProvCapabilities: RTS/CTS, parity check, special chars, 16-bit mode ? |
| 20-23 | 3F 00 00 00 | SettableParams: parity, baud, data bits, stop bits, handshaking, parity check |
| 24-27 | 70 7B 06 10 | SettableBaud: 0x10067B70 (1200 … 115200 except 1800 and 7200, 57600, `SERIAL_BAUD_USER`) |
| 28-29 | 0F 00 | SettableData: 5, 6, 7, 8 bits |
| 2A-2B | 05 17 | SettableStopParity: 1 and 2 stop bits, none / odd / even / space parity |
| 2C-3F | 00 … | CurrentTxQueue, CurrentRxQueue, ProvSpec1, ProvSpec2, ProvChar |

---

### IOCTL 0x32C004 — IOCTL_ACPI_EVAL_METHOD

This IOCTL is sent by Qcuart8930.sys to acpi.sys (sub_402210, `IoBuildDeviceIoControlRequest` to the attached device, during `EvtDevicePrepareHardware`).

| Property | Value |
|----------|-------|
| Device | 0x32 |
| Function | 0x1 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_ACPI_EVAL_METHOD | ACPI node of the device | 8 | 36 |

Inputbuffer (`ACPI_EVAL_INPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 69 42 | Signature `AeiB` |
| 04-07 | 49 4E 46 4F | Method name `INFO` |

Outputbuffer (`ACPI_EVAL_OUTPUT_BUFFER`):  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 41 65 6F 42 | Signature `AeoB`, else `STATUS_ACPI_INVALID_DATA` (0xC014000F) |
| 04-07 | | Length |
| 08-0B | 02 or 03 | Count: at least 2 arguments, else `STATUS_ACPI_INVALID_DATA` |
| 0C-13 | 00 00 04 00 … | Argument 0: integer (type 0, 4 bytes): index of the [property table](#property-tables) (0–3) |
| 14-1B | 00 00 04 00 … | Argument 1: integer: DAL device id of the UART (e.g. 0x0200008A) |
| 1C-23 | 00 00 04 00 … | Argument 2 (optional, default 0): integer, passed to `Uart_DeviceInit` ? |

Every argument must be an integer of 4 bytes, else `STATUS_ACPI_INVALID_DATA`. A failed request → `STATUS_INSUFFICIENT_RESOURCES`.

---

### IOCTL 0x2AC000 — IOCTL_RH_QUERY_CONNECTION_PROPERTIES

This IOCTL is sent by Qcuart8930.sys to [acpiex.sys](./acpiex.md#ioctl-0x2ac000--ioctl_rh_query_connection_properties) (sub_403238, `ZwOpenFile` of `\Device\RESOURCE_HUB` + `ZwDeviceIoControlFile`), at each open through the resource hub.

| Property | Value |
|----------|-------|
| Device | 0x2A |
| Function | 0x0 |
| Access | READ_AND_WRITE |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|-------------------|
| IOCTL_RH_QUERY_CONNECTION_PROPERTIES | \Device\RESOURCE_HUB | 16 | 76 |

Inputbuffer:  
| Bytes | Value | Comment |
|-------|-------|---------|
| 00-03 | 01 00 00 00 | Version |
| 04-07 | 00 00 00 00 | Query by connection id |
| 08-0F | | Connection id, from the file name of the open |

Outputbuffer: version 1, length, `UartSerialBus` descriptor, see [UartSerialBus descriptor](#uartserialbus-descriptor). The driver checks that at least 8 bytes are returned, version = 1 and length = returned bytes − 8, then copies the buffer to pool (tag `qua2`).

---

### Interface GUID

`GUID_DEVINTERFACE_COMPORT` (`IoRegisterDeviceInterface`)  
`{86e0d1e0-8089-11d0-9ce4-08003e301f73}`

### Other GUID

PEP power control code (`PoFxPowerControl`)  
`{3404daac-8e2c-41e4-8458-3158e5ad442b}`
