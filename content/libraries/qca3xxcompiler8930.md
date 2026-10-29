## qca3xxcompiler8930.dll

The Qualcomm shader compiler for the Adreno 3xx GPU ("Oxili", Adreno 305 in the MSM8930).  
The DLL is the Qualcomm `libscdll` shader compiler, release 8.3.1 (source paths `P:\libscdll\rel\8.3.1\llvm\…`). It is built on LLVM with a Qualcomm back end named `QGPU` / `Oxili` (target triple `oxili-mobile-win32`, files `lib\Target\Oxili\QGPU*.cpp`, intrinsics `llvm.qgpu.*` and `llvm.qcom.*`). It takes a shader that the driver has already translated into its own input format, runs the LLVM passes (scalarization, literal lowering, the QGPU register allocators, scheduler…) and writes Adreno machine code into an output structure. It has no Windows-specific functionality: apart from the CRT it imports only TLS, critical sections, timers and a few file functions, all used by the LLVM support library. Memory comes from callbacks that the caller supplies.  
It is loaded by the Direct3D user-mode driver [qcdx9um8930.dll](./qcdx9um8930.md#shader-compiler-sub_10012e0c) when a device is created: GPU family 1 loads `qca2xxcompiler8930.dll` (API 4), families 2 and 3 load this DLL (API 15 and 16); the UMD gets the only export with `GetProcAddress` and requires an interface version `0x0007xxxx`. The kernel side of the GPU is [qcdxkm8930.sys](../drivers/qcdxkm8930.md).

Quick analysis only: 14228 functions, almost all LLVM code with no names; only the API layer (`SCQueryInterface` and the functions it returns) was decompiled.

Location on the phone: `C:\Windows\System32\qca3xxcompiler8930.dll` ? (next to the UMD; the extracted file has no notes).  

### Imports

| DLL | Functions |
|-----|-----------|
| MSVCR110 | memory (`malloc`, `calloc`, `realloc`, `free`, `new`/`delete`), strings (`strlen`, `strcmp`, `strncmp`, `memcmp`, `memcpy`, `memmove`, `memset`, `_snprintf`, `vsprintf_s`, `atoi`, `atof`, `is*`, `tolower`), maths (`sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`, `exp`, `log`, `log10`, `pow`, `sqrt`, `floor`, `ceil`, `fmod`, `fabs`, `modf`, `sinf`, `cosf`, `powf`, `logf`, `floorf`, `ceilf`, `_fpclass`, `_HUGE`), `setjmp`, `longjmp`, `qsort`, `getenv`, `printf`, `fprintf`, `__iob_func`, `_open`, `_close`, `_write`, `_get_osfhandle`, `_errno`, `_heapwalk`, `exit`, `abort`, C++ EH and CRT startup |
| MSVCP110 | `std::_Xbad_alloc`, `std::_Xout_of_range`, `std::_Xlength_error`, `std::_Lockit`, `std::_Winerror_map`, `std::_Syserror_map` |
| api-ms-win-core-file-l1-2-0 | `GetFileType`, `FindFirstFileA`, `FindNextFileA`, `FindClose`, `GetFileAttributesA`, `GetFileAttributesExA`, `SetFileAttributesA`, `DeleteFileA`, `RemoveDirectoryA` |
| api-ms-win-core-processthreads-l1-1-1 | `TlsAlloc`, `TlsFree`, `TlsGetValue`, `TlsSetValue`, `GetCurrentThreadId`, `GetCurrentProcess`, `GetProcessTimes`, `IsProcessorFeaturePresent` |
| api-ms-win-core-synch-l1-2-0 | `InitializeCriticalSection`, `DeleteCriticalSection`, `EnterCriticalSection`, `LeaveCriticalSection` |
| api-ms-win-core-console-l2-1-0 | `SetConsoleTextAttribute`, `GetConsoleScreenBufferInfo` |
| api-ms-win-core-processenvironment-l1-2-0 | `GetStdHandle` |
| api-ms-win-core-profile-l1-1-0 | `QueryPerformanceCounter`, `QueryPerformanceFrequency` |
| api-ms-win-core-sysinfo-l1-2-0 | `GetSystemTimeAsFileTime`, `GetTickCount64` |
| api-ms-win-core-libraryloader-l1-1-1 | `DisableThreadLibraryCalls` |
| api-ms-win-core-errorhandling-l1-1-1 | `GetLastError`, `SetLastError`, `RaiseException` |
| api-ms-win-core-util-l1-1-0, api-ms-win-core-debug-l1-1-1 | `EncodePointer`, `DecodePointer`, `IsDebuggerPresent` |

`_initterm*`, `_onexit`, `__dllonexit`, `_lock`/`_unlock`, `_amsg_exit`, `EncodePointer`/`DecodePointer`, `IsProcessorFeaturePresent` and the `/GS` cookie code are the Visual C++ 2012 DLL CRT boilerplate. The file, console, TLS, timer and `getenv` imports are the LLVM `Support` library (paths, `raw_fd_ostream` to stdout/stderr with colours, timers, `-version`, stack dump on crash); nothing shows that the driver uses them.

### Exports

| Ordinal | Name | Address | Parameters |
|---------|------|---------|------------|
| 1 | `SCQueryInterface` | 0x1000124C | `SC_INTERFACE *Interface` (out, 36 bytes) |

`SCQueryInterface` only fills the function table below and returns its argument. The names of the entries are descriptive; the DLL doesn't name them.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x00 | 4 | 0x00070002 | Interface version (7.2 ?) |
| 0x04 | 4 | `sub_10001028` | [Create](#create-sub_10001028) |
| 0x08 | 4 | `sub_10001098` | [Destroy](#destroy-sub_10001098) |
| 0x0C | 4 | `sub_100010F4` | [Compile](#compile-sub_100010f4) |
| 0x10 | 4 | `sub_10001148` | [CompilePair](#compilepair-sub_10001148) |
| 0x14 | 4 | `nullsub_1` | Does nothing. The UMD calls it with the generated IL shader when its `ShaderDump` setting is on (IL dump hook) |
| 0x18 | 4 | `nullsub_2` | Does nothing |
| 0x1C | 4 | `sub_10001208` | [SetOption](#setoption-sub_10001208) |
| 0x20 | 4 | `nullsub_3` | Does nothing |

### Startup

`start` (`_DllMainCRTStartup`, 0x10395990): CRT initialisation (`__security_init_cookie`, `_initterm` of the LLVM static constructors: pass and `cl::opt` registrations). There's no ETW, no registry and no thread: everything happens in the calls of the caller.

### Create (sub_10001028)

Parameters: `SC_CREATE_PARAMS *Params`, `void *Unused` (must be non-NULL). Returns the handle, or NULL.

1. Fails if `Params` is NULL, if one of the pointers at 0x30, 0x34, 0x38, 0x40, 0x44, 0x48, 0x4C is NULL, or if the second argument is NULL.
2. Allocates the 80-byte [handle](#handle) with `Params->Alloc(Params->Context, 0x50)`.
3. `sub_100015C0` allocates the 1000-byte compiler context with `Alloc(Context, 1000)` and initialises it (`sub_10001ED8`: keeps `Alloc`/`Free`/`Context`, allocates a 13380-byte LLVM context, sets the `setjmp` buffer used to unwind on fatal errors).
4. Reads `Params->Api` (0x08): only 15 and 16 are accepted, and they select the internal target 16 or 17 (`sub_10001FE4`); any other value sets the internal error 12. The two limits at 0x0C and 0x10 are clamped to 1..1024 (1024 when 0 or larger) and stored in the two sub-contexts at offset 5808 (maximum number of registers / constants ?).
5. On an error (context missing, or internal status 2 = out of memory) everything is freed with `Free` and NULL is returned.

### SC_CREATE_PARAMS

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | Copied to handle 0x10 (?). 0xFFFFFFFF from the UMD |
| 0x04 | 4 | Copied to handle 0x18 (?) |
| 0x08 | 4 | API / input kind: 15 or 16, else error (D3D feature levels ?) |
| 0x0C | 4 | Limit for sub-context 1, 1..1024 (0 = 1024) |
| 0x10 | 4 | Limit for sub-context 2, 1..1024 (0 = 1024) |
| 0x2C | 4 | Context passed to the callbacks |
| 0x30 | 4 | `void *Alloc(Context, Size)`, required |
| 0x34 | 4 | `void Free(Context, Ptr)`, required |
| 0x38 | 4 | Callback, required: `(Context, ?, *Out)`, the UMD's writes 0 to `*Out` |
| 0x40–0x4C | 16 | File callbacks, required: `Open(Context, Name, Mode)` (UMD: `fopen_s`, mode 1 `r`, 2 `w`, 3 `r+`), `Close` (`fclose`), `Write` (`fwrite`), `Read` (`fread`) |
| 0x50 | 4 | Copied to handle 0x14. In the UMD: `(Context, Size, void **Out)` allocation callback (`malloc` + zero, stored in `*Out`) |

### Handle

| Offset | Size | Comment |
|--------|------|---------|
| 0x00 | 4 | `Free` callback |
| 0x04 | 4 | Callback context |
| 0x08 | 4 | Compiler context (1000 bytes); status at +0x7C (124) |
| 0x0C | 4 | Object deleted by `Destroy` (`sub_1012BCE0` + `delete`) |
| 0x10 | 4 | `Params+0x00` |
| 0x14 | 4 | `Params+0x50` |
| 0x18 | 4 | `Params+0x04` |
| 0x28 | 4 | `Params->Api` (15 / 16) |
| 0x2C–0x4C | 36 | Arguments of the last `Compile` / `CompilePair` call (written, never read here) |

### Destroy (sub_10001098)

Parameter: the handle. Returns 3 if it is NULL, else 0. Frees the compiler context (`sub_10002288`, which releases the LLVM context and the three allocation pools at +260), the object at 0x0C, then the handle itself with `Free`.

### Compile (sub_100010F4)

Parameters: handle, `SC_INPUT *Input`, `SC_OUTPUT *Output`. Returns an [API error code](#error-codes).

1. Returns 3 if the handle is NULL, 2 if it has no compiler context.
2. `sub_10002338(Context, Output, Input->Shader (0x74), &Input->Options (0x7C))`, under `setjmp` (a fatal error inside LLVM `longjmp`s back and the call returns the status):
   - `sub_10002818` turns the [option bits](#setoption-sub_10001208) into the compiler flags (context bytes 644–666);
   - `sub_1005A2D8` reads the shader header: byte 6 is the program type and byte 0 a variant (1, 4 or 5 set extra flags 0x400, 0x800, 0x1000);
   - the stage is written to `Output+0x144`, and `Handle->Api` to `Output+0x148`;
   - `sub_10002DB0` runs the compilation.
3. Internal statuses above 21 give 5; the others are translated by `sub_100016E0`.

| Byte 6 of the shader | Internal flag | `Output+0x144` | Stage (D3D10 program-type order ?) |
|----------------------|---------------|----------------|-------|
| 0 | 0x002 | 0 | Pixel ? |
| 1 | 0x004 | 1 | Vertex ? |
| 2 | 0x010 | 2 | Geometry ? |
| 3 | 0x040 | 3 | Hull ? |
| 4 | 0x100 | 4 | Domain ? |
| 5 | 0x080 | 5 | Compute ? |

The input layout outside 0x74 and 0x7C, and the output layout outside 0x144 / 0x148, were not analysed.

### CompilePair (sub_10001148)

Parameters: handle, `SC_INPUT *Input`, `ULONG Mode`, `SC_OUTPUT *Output1`, `SC_OUTPUT *Output2` (5th on the stack). Same return codes as `Compile`, plus 4 when `Handle->Api` isn't 15 or 16.

Like `Compile`, but the shader must be of type 0 (else 4) and two outputs are produced from it (both get stage 0 at 0x144). `Mode` above 2 is treated as 0; it is stored in the context (offset 668) as `Mode + 1`. What the two outputs and the three modes are (e.g. normal and binning-pass variants) is not known: `?`.

### SetOption (sub_10001208)

Parameters: `ULONG *Bits`, `ULONG Bit`, `BOOL Enable`. Sets or clears bit `Bit` of the bit array (no return value). The caller uses it on `Input+0x7C` (3 dwords): `Compile` reads bits 5–83 (`sub_10002818`); each one sets or clears a compiler flag. Their meaning isn't named in the binary.

### Error codes

`sub_100016E0` translates the internal status of the compiler into the code returned by `Compile` / `CompilePair` (any other value calls `abort`).

| Internal | Returned | Internal | Returned |
|----------|----------|----------|----------|
| 0 | 0 (success) | 11 | 11 |
| 1 | 1 | 12 (bad API) | 12 |
| 2 (out of memory) | 2 | 13 | 4 |
| 3 | 20 | 14 | 13 |
| 4, 10 | 5 | 15 | 14 |
| 5 | 6 | 16 | 15 |
| 6 | 7 | 17 | 16 |
| 7 | 8 | 18 | 17 |
| 8 | 9 | 19 | 18 |
| 9 | 10 | 20 | 19 |
| | | 21 | 21 |

The API layer itself also returns 2 (no compiler context), 3 (NULL handle), 4 (wrong API or shader type for `CompilePair`) and 5 (unknown status).

### Strings

Notable strings of the compiler (`.rdata`):

- Driver constants it can add to a shader: `tex_width_inv`, `tex_height_inv`, `viewport_scale_width_half`, `viewport_scale_height_half`, `viewport_z_far_minus_near`, `viewport_z_far_plus_near`, `viewport_bias_x/y`, `border_color_x/y/z/w`, `vertex fog factor adj`, `vertex_freq_div`, `lod_bias`, `loop_bound255`, `loop_bound65k`, `shadow_fail`.
- Hidden globals: `__qcom_gShaderLang`, `__qcom_BARY_Coordinate_%d`, `__qcom_DX11ICBInfo`, `__qcom_PSMetaInfo`, `__qcom_HSMetaInfo`, `__qcom_DSMetaInfo`, `__qcom_preallocRegisterFunc`, `__qcom_rs_globals` / `__qcom_rs_local_rand_seed` (RenderScript pass), `$DX_empty_vec4`.
- DX11 support: `SupportsDX11` (`Supports DX11 specific features`), `Above DX 11 intrinsic yet to support`, `unexpected DX11 CS global used`; also OpenCL intrinsics (`llvm.opencl.*`).
- `tmp.vert`, `tmp.frag`: file names of a debug dump ? (not followed in this quick pass). Files are opened through the `Open` callback of the UMD (`fopen_s`).
- LLVM debugging options (`-version`, `*** IR Dump Before/After`, `LLVM_VERIFY_MACHINEINSTRS`, `Stack dump:`…): the usual LLVM `cl::opt` options; whether the driver can set any of them wasn't checked.
