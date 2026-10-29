## qcdx9um8930.dll

The Qualcomm Direct3D user-mode display driver (UMD) of the Adreno GPU, build `P:\Direct3dUM\rel\8.3.1\direct3d\dx9\built\wp\arm\Release\dll\qcdx9um8930.pdb`.  
It is the user-mode half of the WDDM driver: the Direct3D runtime loads it and calls its only export `OpenAdapter`, which returns the D3DDDI adapter functions (`GetCaps`, `CreateDevice`, `CloseAdapter`). The device functions turn the D3D9-level DDI calls into Adreno command buffers (the strings `IB1`, `IB2`, `FSTC`, `RSTR`, `BLT`, `BEND`, the "viz stream" / software binning messages) and translate the shaders into an intermediate language that it compiles with the Qualcomm shader compiler. It has no direct contact with the kernel: everything goes through the runtime callbacks (`pfnQueryAdapterInfoCb` and the device callbacks), which end in [qcdxkm8930.sys](../drivers/qcdxkm8930.md).  
At run time it loads the shader compiler of the GPU family ([qca3xxcompiler8930.dll](./qca3xxcompiler8930.md) or `qca2xxcompiler8930.dll`) and, for the video capabilities, the video UMD [qcvidum8930.dll](./qcvidum8930.md). Its settings come from `HKLM\Software\QCOM\Drivers\DxUMD`, with obfuscated value names.

Quick analysis: 1985 functions, no symbols. Only the adapter layer, the loading of the other DLLs, the settings and the tracing were decompiled; the device functions (state, resources, command buffers, the D3D9 shader translator) were not.

Location on the phone: `C:\Windows\System32\qcdx9um8930.dll` ? (the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| MSVCR110 | `malloc`, `free`, `memcpy`, `memset`, `memcmp`, `strcmp`, `strlen`, `_stricmp`, `strcpy_s`, `strcat_s`, `_itoa_s`, `atoi`, `atof`, `isdigit`, `vsprintf_s`, `fopen_s`, `fread`, `fwrite`, `fclose`, `powf`, `fmodf`, `modff`, `_purecall`, CRT startup (`_initterm`, `_initterm_e`, `_onexit`, `__dllonexit`, `_lock`, `_unlock`, `_malloc_crt`, `_calloc_crt`, `_amsg_exit`, `__C_specific_handler`, `__CppXcptFilter`, `__clean_type_info_names_internal`) |
| api-ms-win-core-libraryloader-l1-1-1 | `LoadLibraryExA`, `GetProcAddress`, `FreeLibrary`, `GetModuleHandleExA`, `GetModuleFileNameA` |
| api-ms-win-core-registry-l1-1-0 | `RegOpenKeyExA`, `RegQueryValueExA`, `RegEnumValueA`, `RegCloseKey` |
| api-ms-win-eventing-provider-l1-1-0 | `EventRegister`, `EventUnregister`, `EventWrite`, `EventWriteString` |
| api-ms-win-eventing-classicprovider-l1-1-0 | `RegisterTraceGuidsW`, `UnregisterTraceGuids`, `GetTraceLoggerHandle`, `GetTraceEnableLevel`, `GetTraceEnableFlags`, `TraceMessage` |
| api-ms-win-core-synch-l1-2-0 | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-profile-l1-1-0 | `QueryPerformanceCounter` |
| api-ms-win-core-processthreads-l1-1-1 | `GetCurrentThreadId` |
| api-ms-win-core-sysinfo-l1-2-0 | `GetSystemTimeAsFileTime`, `GetTickCount64` |
| api-ms-win-core-util-l1-1-0 | `EncodePointer`, `DecodePointer` |

The CRT startup functions, `EncodePointer`/`DecodePointer`, `GetSystemTimeAsFileTime`, `GetCurrentThreadId`, `GetTickCount64`, `QueryPerformanceCounter` (`/GS` cookie) are the Visual C++ 2012 DLL boilerplate. The classic-provider functions are the WPP tracing. The `f*` file functions are only used by the callbacks given to the shader compiler.

### Dependencies

Files used other than the static imports.

| File | How | Use |
|------|-----|-----|
| [qcvidum8930.dll](./qcvidum8930.md) | `LoadLibraryExA`, `GetProcAddress("DxVidCreateAdapter")` | Video UMD (DXVA decode / video processing caps and devices). Loaded the first time a video caps type is asked for (`sub_10001720`) |
| [qca3xxcompiler8930.dll](./qca3xxcompiler8930.md) | `LoadLibraryExA`, `GetProcAddress("SCQueryInterface")` | Shader compiler for GPU families 2 and 3 (Adreno 3xx), see [Shader compiler](#shader-compiler-sub_10012e0c) |
| `qca2xxcompiler8930.dll` | `LoadLibraryExA`, `GetProcAddress("SCQueryInterface")` | Shader compiler for GPU family 1 (Adreno 2xx). Not on the Lumia 520 ? |
| any file | `fopen_s` (`r`, `w`, `r+`), `fread`, `fwrite`, `fclose` | Opened on behalf of the shader compiler through its file callbacks; the names come from the compiler (e.g. its `tmp.vert`, `tmp.frag` debug dumps ?) |

The DLL names are built at run time by `sub_10026880`: the base name (`qcvidum`, `qca2xxcompiler`, `qca3xxcompiler`) + the number at the end of the UMD's own file name (`sub_1002690C`: `GetModuleHandleExA(FROM_ADDRESS)`, `GetModuleFileNameA`, digits before `.dll`, here `8930`) + `.dll`. So the 8930 UMD always loads the 8930 helpers, from the default search path.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `OpenAdapter` | 0x10001290 | `D3DDDIARG_OPENADAPTER *pOpenData` |

### Startup

`start` (`_DllMainCRTStartup`, 0x10078AB8): CRT initialisation, then `DllMain` (`sub_10001170`):
- `DLL_PROCESS_ATTACH`: registers the WPP provider `{9D58D4BD-E598-4BD6-B4D0-6C1F80964F74}` (`sub_10001100`, `RegisterTraceGuidsW`, control callback `sub_10001088`), then creates the allocation tracker (`sub_100261D4`): a 40-byte object with a critical section, the manifest provider `{B840958E-7645-4281-AA14-611B3598640F}` (`McGenEventRegister`) and the provider `{A688EE40-D8D9-4736-B6F9-6B74935BA3B1}` (`EventRegister`, callback `sub_10026A20`). See [ETW](#etw).
- `DLL_PROCESS_DETACH`: frees the tracker (`sub_1002636C`) and unregisters WPP.

### OpenAdapter (0x10001290)

1. Allocates and zeroes the 1628-byte [adapter object](#adapter-object) (`E_OUTOFMEMORY` and ETW event 207 when `malloc` fails).
2. `sub_100013EC`:
   1. copies `hAdapter`, `Interface`, `Version` and the two `D3DDDI_ADAPTERCALLBACKS` (`pfnQueryAdapterInfoCb`, `pfnGetMultisampleMethodListCb`) into the object, and writes the object as the new `hAdapter`;
   2. fills `pAdapterFuncs`: `pfnGetCaps` = `sub_10001320`, `pfnCreateDevice` = `sub_1000132C`, `pfnCloseAdapter` = `sub_100013A4`;
   3. [reads the adapter information of the KMD](#adapter-information-sub_10001660) (`sub_10001660`);
   4. creates the family object of the GPU (`sub_1000B268`), chosen by the family dword of the adapter information (`+0x0C`): 1, 2 or 3 → vtables `off_1007EF18`, `off_1007FA1C`, `off_100805B0` (Adreno 2xx, 3xx, 3xx-newer ?); anything else gives `E_OUTOFMEMORY`;
   5. enumerates all the values of the [registry key](#registry) into a list (`sub_10026638`);
   6. creates the settings object with the family's factory and initialises it (`sub_1000C344`: hard-coded defaults `sub_10078158`, then the registry overrides `sub_10076E84` and the family-specific values, e.g. `sub_100347AC`, `sub_100500CC`, `sub_1006524C`);
   7. creates two more family objects (one with the FourCC `0x31455451` `QTE1` when a settings flag and adapter-information bits allow it, else 506: ?) and the caps object (`sub_1000287C`);
   8. if the setting at `+0x14` is set, allocates `setting(+0x18)` MB (`<< 20`) at adapter `+0x658` (?).
3. `pOpenData->DriverVersion` = the `Version` given by the runtime. On failure the object is freed (`sub_100015A8`).

`CloseAdapter` (`sub_100013A4`) calls `sub_100015A8`: destroys the video adapter (function at `+0x5DC`), the objects, the registry list, `FreeLibrary` of `qcvidum8930.dll` and frees the object.

`CreateDevice` (`sub_1000132C`): the family object creates the device object (vtable `+0`), then `sub_10003C8C` copies the `D3DDDIARG_CREATEDEVICE` (`hDevice`, `Interface`, `Version`, the 0x70-byte device callbacks, flags), writes the device as the new `hDevice` and fills the 0x20C-byte device function table from one of two templates (`off_1007A6A8` or `off_1007A498`, chosen by a setting). The device keeps the adapter object at `+0x2D3C`.

### GetCaps (sub_10002960)

`sub_10001320` forwards `D3DDDIARG_GETCAPS` to the caps object. By `Type` (`D3DDDICAPS_TYPE`):

| Type | Answer |
|------|--------|
| 1 (`DDRAW`) | Copy of the caps object `+0x04` |
| 2 (`DDRAW_MODE_SPECIFIC`) | `+0x18` |
| 3 (`GETFORMATCOUNT`) | `+0x34` |
| 4 (`GETFORMATDATA`) | Table pointed by `+0x18C` |
| 5 (`GETMULTISAMPLEQUALITYLEVELS`) | Virtual function `+0x3C` of the caps object |
| 6 (`GETD3DQUERYCOUNT`) | `+0x38` |
| 7 (`GETD3DQUERYDATA`) | `+0x3C` |
| 8 (`GETD3D3CAPS`) | Empty `D3DHAL_GLOBALDRIVERDATA` (192 bytes, only `dwSize`) |
| 9, 10 (`GETD3D5CAPS`, `GETD3D6CAPS`) | `E_FAIL` |
| 11 (`GETD3D7CAPS`) | Empty 116-byte structure (only the size) |
| 12 (`GETD3D8CAPS`) | Zeroed `D3DCAPS8` (212 bytes) |
| 13 (`GETD3D9CAPS`) | `D3DCAPS9` (304 bytes) from `+0x44` |
| 14–33, 35–44 | Video / DXVA types: forwarded to [qcvidum8930.dll](./qcvidum8930.md#getcaps-sub_10001778) (its function at `Out+0x48`, adapter `+0x618`), loaded on first use |
| 34 | Success, no data |
| 45 | 4 bytes from `+0x174` (?) |
| 46 | 8 bytes from `+0x178` (?) |
| 47 | 12 bytes from `+0x180` (?) |
| other | `E_FAIL` |

The names of the types above 13 depend on the `d3dumddi.h` version and are not checked here.

### Adapter information (sub_10001660)

Calls `pfnQueryAdapterInfoCb(hAdapter, {pPrivateDriverData = adapter + 0x28, PrivateDriverDataSize = 1424})`: dxgkrnl passes the request to `DxgkDdiQueryAdapterInfo` of [qcdxkm8930.sys](../drivers/qcdxkm8930.md#ddi-functions) (`DXGKQAITYPE_UMDRIVERPRIVATE`). The buffer is zeroed and its first dword set to 1424 before the call.

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | 1424, size, set by the UMD |
| 0x04 | 4 | Must be 2, else `E_INVALIDARG` (interface version ?) |
| 0x08 | 4 | Expected 17, only a WPP warning otherwise (KMD version ?) |
| 0x0C | 4 | GPU family: 1, 2 or 3 (selects the family object and the [compiler](#shader-compiler-sub_10012e0c)). Also copied to adapter `+0x5B8` |
| 0x10 | 4 | Copied to adapter `+0x5BC` (?) |
| 0x14 | 4 | Copied to adapter `+0x5C0` (?) |
| … | | Not analysed. Byte `+0x78` bit 1 and `+0xF0` bit 0 are tested when creating the second family object (`QTE1`) |

### Adapter object

1628 bytes (`OpenAdapter`).

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Runtime `hAdapter` |
| 0x04 | 4 | `Interface` |
| 0x08 | 4 | `Version` |
| 0x0C | 4 | `pfnQueryAdapterInfoCb` |
| 0x10 | 4 | `pfnGetMultisampleMethodListCb` |
| 0x18 | 4 | GPU family object (factory) |
| 0x1C | 4 | Caps object |
| 0x20 | 4 | Settings object (its `+8` is the [settings](#settings) structure) |
| 0x24 | 4 | List of the registry values (24 bytes) |
| 0x28 | 1424 | [Adapter information](#adapter-information-sub_10001660) from the KMD |
| 0x5B8–0x5C0 | 12 | Adapter information `+0x0C`, `+0x10`, `+0x14` |
| 0x5C4 | 4 | Family object (506 / `QTE1`) |
| 0x5C8 | 4 | `qcvidum8930.dll` module |
| 0x5CC | 4 | Video adapter handle returned by `DxVidCreateAdapter` |
| 0x5D0–0x654 | 136 | Video adapter functions returned by `DxVidCreateAdapter` (`+0x5DC` destroy, `+0x618` GetCaps) |
| 0x658 | 4 | Buffer of `setting(+0x18)` MB (?) |

### qcvidum8930.dll (sub_10001720)

[`DxVidCreateAdapter`](./qcvidum8930.md#dxvidcreateadapter-0x10001118)`(IN *In, OUT *Out)`, `In` is 0xBC bytes: `+0x00` 0xBC (size), `+0x04` 4, `+0x08` 6 (versions ?), `+0x10` the adapter object, `+0x54` adapter `+0x28` (the KMD adapter information). `Out` is 0x100 bytes: `+0x04` video adapter handle (adapter `+0x5CC`), `+0x08`…`+0x84` 32 function pointers (adapter `+0x5D8`…`+0x654`; `+0x08` `CreateDevice`, `+0x0C` destroy, called by `CloseAdapter`; `+0x48` GetCaps), `+0x88`, `+0x8C` (adapter `+0x5D0`, `+0x5D4`). A failure of `LoadLibraryExA` gives `E_FAIL`, a missing export gives 0 with no video adapter.

### Shader compiler (sub_10012E0C)

Called when a device is created (`sub_10003C8C`). The family is the dword `+0x0C` of the [adapter information](#adapter-information-sub_10001660) (adapter `+0x34`):

| Family | DLL | `Api` given to `Create` |
|--------|-----|-------------------------|
| 1 | `qca2xxcompiler8930.dll` | 4 |
| 2 | [qca3xxcompiler8930.dll](./qca3xxcompiler8930.md) | 15 |
| 3 | [qca3xxcompiler8930.dll](./qca3xxcompiler8930.md) | 16 |

1. Loads the DLL, calls `SCQueryInterface(&Ctx->Interface)` (36 bytes at `+0x1C` of the compiler context) and checks that the high word of the interface version is 7 (`0x0007xxxx`), else `E_FAIL`.
2. Fills the 0x7C-byte `SC_CREATE_PARAMS` and calls `Interface.Create(&Params, &Out)` (`Out`: 12 zeroed bytes). The handle is kept at `+0x18`:

| Offset | Value | Comment |
|--------|-------|---------|
| 0x00 | 0xFFFFFFFF | ? |
| 0x08 | 4 / 15 / 16 | API, see the table above |
| 0x28 | 1 | ? |
| 0x2C | compiler context | Context of the callbacks |
| 0x30 | `sub_10013080` | `Alloc(Context, Size)`: `malloc` + zero |
| 0x34 | `sub_100130C0` | `Free(Context, Ptr)` |
| 0x38 | `sub_10013100` | `(Context, a2, *Out)`: writes 0 to `*Out`, returns 0 |
| 0x3C | `sub_10013110` | ? (also passed to the IL dump function below) |
| 0x40 | `sub_10013140` | `Open(Context, Name, Mode)`: `fopen_s` with mode 1 `r`, 2 `w`, 3 `r+` |
| 0x44 | `sub_100131B4` | `Close(Context, File)`: `fclose`, TRUE on success |
| 0x48 | `sub_100131DC` | `Write`: `fwrite` |
| 0x4C | `sub_10013214` | `Read`: `fread` |
| 0x50 | `sub_1001303C` | `(Context, Size, void **Out)`: `malloc` + zero, stored in `*Out` |

3. `sub_10012F40` (IL dump): when the setting `+0x00` (`ShaderDump`, see [Settings](#settings)) is set, the generated IL shader (after the WPP message `************** GENERATED IL SHADER **************`) is given to `Interface+0x14(Handle, Il, 4 × Count, sub_10013110)`. In `qca3xxcompiler8930.dll` that entry is a `nullsub`.

The `D3D9` shader translator (`sub_10017494`: `DX Shader Version %d.%d`, `Passthru VS` in `sub_10013600`) wasn't analysed; the calls to `Compile` / `CompilePair` weren't located.

### Settings

`sub_10078158` fills the settings structure (199 dwords) with defaults, then `sub_10076E84` and the family functions (`sub_100347AC` for family 1, `sub_100500CC` / `sub_10050104` for family 2, `sub_1006524C` for family 3) override them from the registry. A few fields:

| Offset | Default | Comment |
|--------|---------|---------|
| 0x00 | 0 | Shader dump: copied to the global next to the string `ShaderDump` (`0x10085108`), enables the IL dump to the compiler |
| 0x14 | 0 | ≠ 0: allocate the buffer at adapter `+0x658` |
| 0x18 | 10 | Size of that buffer, in MB |
| 0x58 | `DefaultDxString` | 256-character string, registry value `1A2SVvXDSVz0` (REG_SZ) |
| 0x29C | 1.0 | Float, registry value `dVK3lUBzlD6W` (REG_SZ, `atof`) |
| 0x2A0 | 64.0 | Float, registry value `Y0WQ1Q2T46+e` (REG_SZ, `atof`) |

The meaning of the other fields (memory sizes 4096, 0x8000, 0x100000…, booleans) isn't named in the binary.

### Registry

Key `HKEY_LOCAL_MACHINE\Software\QCOM\Drivers\DxUMD`.  
The 347 value names are 12-character base64-looking strings (`+XvAlgIEBTPb`, `1tui1YgBVvO0`, `iMq5EkOmvo9P`…), i.e. hashed or encrypted names: the real setting names are not in the binary. All are REG_DWORD except the string and the two floats above.

- `sub_10026638` (`OpenAdapter`): `RegEnumValueA` of the whole key into a list of 520-byte entries (name 256, REG_SZ data 256, REG_DWORD data at `+0x200`, type at `+0x204`), then sets the "cached" flag.
- `sub_10026594`: lookup of a name in that list (DWORD or string). This is the path used when the list exists.
- `sub_10026448` (REG_DWORD, size 4) / `sub_100264D4` (REG_SZ, ≤ 256) / `sub_100263D0` (REG_SZ → float): direct `RegOpenKeyExA` + `RegQueryValueExA`, used when the list wasn't built.

A value that is absent leaves the default.

### ETW

WPP provider `{9D58D4BD-E598-4BD6-B4D0-6C1F80964F74}` (`TraceMessage`, control block `0x10087A00`): trace messages of the adapter (flag 0x200), caps (0x10), shader (0x08), binning (0x01) functions, level ≥ 4 for most of them.

Provider `{B840958E-7645-4281-AA14-611B3598640F}` (`McGenEventRegister`), written by `sub_10076CEC(code, …)`. The enable bit is `dword_10087A80` bit 0:

| Event | Level | Opcode, task | Keyword | Written when |
|-------|-------|--------------|---------|--------------|
| 201 | 4 | 0, 1 | 0x8000000000000000 | code 1 |
| 206 | 4 | 0, 6 | 0x8000000000000000 | code 6 |
| 207 | 4 | 0, 7 | 0x8000000000000000 | code 7: allocation failure (every `malloc` failure of the driver) |
| string | | | | code 0: `EventWriteString` |

Codes 3, 4, 5, 8 call `EventWrite` without a fixed descriptor (`sub_10076CC8`).

Provider `{A688EE40-D8D9-4736-B6F9-6B74935BA3B1}` (`sub_100261D4`), written by `sub_10026A78` when it is enabled (6 fields of 8, 8, 8, 8, 4, 4 bytes), from the allocation tracker (`sub_1002AAC8`, `sub_1002AC20`, `sub_10020D88`, rundown `sub_10025FE8`):

| Event | Level | Opcode, task | Keyword |
|-------|-------|--------------|---------|
| 1 | 0 | 1, 1 | 0x8000000000000001 |
| 2 | 0 | 3, 1 | 0x8000000000000001 |
| 3 | 0 | 2, 1 | 0x8000000000000001 |

Event 3 is written when the first argument is 0, 1 when no tracker list exists, otherwise 2 (allocation create / rundown / destroy ?).

### Strings

- Command-stream markers: `IB1`, `IB2P`, `IB2T`, `IB2D`, `IB2B`, `IB2A`, `IB2R`, `IB2L`, `IB2S`, `IB2W`, `FSTC`, `RSTR`, `BLT`, `BEND` (`sub_10034270`, `sub_1004909C`): names of the indirect buffers / passes in the debug output ?
- `Cannot use viz stream, switch to sw binning`, `Viz stream in use, no switch` (`sub_10035984`, `sub_100642AC`): the Adreno hardware binning ("visibility stream") or software binning choice.
- `VSFloat`, `PSFloat`, `VSInt`, `PSInt`: shader constant types.
