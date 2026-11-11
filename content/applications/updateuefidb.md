## UpdateUEFIDb.exe

One-shot system tool that updates the UEFI Secure Boot signature database (`db` variable). The user of the phone never sees it.  
`UpdateUEFIDb.exe` is a small console binary (40 960 bytes, 40 functions, most of them CRT and RPC stubs) with no UI. It reads the current `db`, and if it's byte for byte one of two known images, it replaces it with a signed image stored in the binary. The Microsoft Windows Phone PCA 2011 certificate is removed and the owner of the remaining certificates changes from Nokia to Microsoft. It then asks the Task Scheduler service (`ITaskSchedulerSvcRpc`, the interface of [ShellChromeAPI.dll](../libraries/shellchromeapi.md#task-scheduler-rpc-reminders)) to set the state of two tasks to 0.  
The UEFI side of the write and the code that verifies boot images aren't in this binary.

Location on the phone: `C:\Windows\System32\UpdateUEFIDb.exe` ? (no path in the binary or in the other extracted files).

### Imports

| DLL | Functions |
|-----|-----------|
| ntdll.dll | `NtQuerySystemEnvironmentValueEx`, `NtSetSystemEnvironmentValueEx`, `RtlInitUnicodeString`, `RtlNtStatusToDosError` |
| [SecRuntime.dll](../libraries/secruntime.md) | `QueryTransientObjectSecurityDescriptor`, `FreeTransientObjectSecurityDescriptor` |
| RPCRT4.dll | `RpcBindingCreateW`, `RpcBindingBind`, `RpcBindingFree`, `NdrClientCall2`, `I_RpcExceptionFilter` |
| api-ms-win-security-base-l1-2-0.dll | `AdjustTokenPrivileges` |
| api-ms-win-security-lsalookup-l2-1-1.dll | `LookupPrivilegeValueW` |
| api-ms-win-core-processthreads-l1-1-2.dll | `GetCurrentProcess`, `OpenProcessToken`, `TerminateProcess` |
| api-ms-win-core-heap-obsolete-l1-1-0.dll | `LocalAlloc`, `LocalFree` |
| api-ms-win-core-handle-l1-1-0.dll | `CloseHandle` |
| api-ms-win-core-errorhandling-l1-1-2.dll | `GetLastError`, `SetUnhandledExceptionFilter`, `UnhandledExceptionFilter` |
| api-ms-win-core-synch-l1-2-0.dll | `Sleep` |
| api-ms-win-core-libraryloader-l1-2-0.dll | `GetModuleHandleA` |
| api-ms-win-core-rtlsupport-l1-2-0.dll | `RtlCaptureContext`, `RtlLookupFunctionEntry`, `RtlVirtualUnwind` |
| msvcrt.dll | `memcmp`, `wcscmp`, `malloc`, `free`, `__wgetmainargs`, `_initterm`, `_amsg_exit`, `_exit`, `_cexit`, `exit`, `__set_app_type`, `__setusermatherr`, `_fmode`, `_commode`, `_XcptFilter`, `__C_specific_handler`, `?terminate@@YAXXZ` |

`malloc` and `free` are the MIDL allocators of the RPC stub. `TerminateProcess`, `GetModuleHandleA`, the rtlsupport imports, the unhandled exception functions and the other msvcrt imports (except `memcmp` and `wcscmp`) are the standard Visual C++ CRT startup and `/GS` security cookie code. There are no exports.

### Dependencies

Files used other than the static imports: none. There is no `LoadLibrary`, `CreateProcess`, `CoCreateInstance` or file API in the binary. It only uses two other components:

| Component | How | Use |
|-----------|-----|-----|
| UEFI variable `db` | `NtQuerySystemEnvironmentValueEx`, `NtSetSystemEnvironmentValueEx` | Read and replaced, see [Update of db](#update-of-db) |
| RPC server of the Task Scheduler service (`ITaskSchedulerSvcRpc`, dynamic LRPC endpoint) | `RpcBindingCreateW` / `RpcBindingBind` | Opnum 6 for two tasks, see [Task Scheduler RPC](#task-scheduler-rpc); the hosting service binary isn't known |

### Parameters

The command line isn't used: `wmain` (`sub_1003A60`, 0x1003A60) ignores its parameters and always exits with code 0, even when a step fails. The real result is only visible in the `db` variable.

Who starts it isn't known: no other extracted binary contains its name or the two task GUIDs. The two tasks of the [last step](#task-scheduler-rpc) may be the ones that start it, so that it doesn't run again ?

### Update of db

`sub_1003A60` runs these steps. A failure in steps 1, 2 or 4 ends the program without calling the Task Scheduler. If the write fails, the tasks keep their state, so a new run could retry ?

1. **Privilege.** `OpenProcessToken(GetCurrentProcess(), 0x38, …)` (`TOKEN_QUERY | TOKEN_QUERY_SOURCE | TOKEN_ADJUST_PRIVILEGES`), `LookupPrivilegeValueW(NULL, L"SeSystemEnvironmentPrivilege", …)`, then `AdjustTokenPrivileges` with `SE_PRIVILEGE_ENABLED` (2). The previous state goes to 0x1006DF4 and the flag 0x1006DF0 is set to 1, but neither is read again: the privilege isn't restored.
2. **Read.** `sub_1003874` (0x1003874) calls `NtQuerySystemEnvironmentValueEx(L"db", {D719B2CB-3D3A-4596-A3BC-DAD00E67656F}, …)` with a NULL buffer to get the size. On `STATUS_BUFFER_TOO_SMALL` (0xC0000023) it allocates the buffer with `LocalAlloc` and reads the value. The variable name is a constant and the first parameter of the function isn't used. The code that selects `{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}` (at 0x1005030) for a name other than `db` / `dbx` is dead.
3. **Compare.** The value is compared with `memcmp` with the two [known images](#signature-lists): 0xC84 bytes at 0x1002438, then 0x1385 bytes at 0x10010B0. The size must match first.
4. **Write.** Only if one image matches, `sub_10039B0` (0x10039B0) calls `NtSetSystemEnvironmentValueEx(L"db", {D719B2CB-…}, 0x1005040, 0x1B52, 0x27)`. If `db` is anything else, nothing is written and the program goes on to step 5.
5. **Tasks.** See [Task Scheduler RPC](#task-scheduler-rpc).
6. `LocalFree` of the buffer, return 0.

Errors of the system environment functions are turned into HRESULTs in the same way as in [ReminderEvents.dll](../libraries/reminderevents.md#rpc): 0xC0000109 gives 0x8007013D, other NTSTATUS give the Win32 error of `RtlNtStatusToDosError`, or the NTSTATUS with bit 28 set. They're only used for the branches above: nothing is logged.

The attributes 0x27 are `EFI_VARIABLE_NON_VOLATILE` (1), `BOOTSERVICE_ACCESS` (2), `RUNTIME_ACCESS` (4) and `TIME_BASED_AUTHENTICATED_WRITE_ACCESS` (0x20). `APPEND_WRITE` (0x40) isn't set, so the data replaces the whole variable.

GUIDs:

| GUID | Name | Use |
|------|------|-----|
| `{D719B2CB-3D3A-4596-A3BC-DAD00E67656F}` | `EFI_IMAGE_SECURITY_DATABASE_GUID` | Namespace of `db` (0x1005020) |
| `{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}` | `EFI_GLOBAL_VARIABLE` | Dead code (0x1005030) |
| `{4AAFD29D-68DF-49EE-8AA9-347D375665A7}` | `EFI_CERT_TYPE_PKCS7_GUID` | Certificate type of the [written data](#data-written) |
| `{A5C059A1-94E4-4AA7-87B5-AB155C2BF072}` | `EFI_CERT_X509_GUID` | Type of every [signature list](#signature-lists) |

### Data written

The 0x1B52 bytes at 0x1005040 are an `EFI_VARIABLE_AUTHENTICATION_2` header followed by the new `db`.

| Offset | Size | Value | Comment |
|--------|------|-------|---------|
| 0x000 | 16 | 2013-07-20 15:31:00 | `EFI_TIME` of the signature. The firmware should refuse a timestamp that isn't newer than the stored one (UEFI specification) ? |
| 0x010 | 4 | 0xEBE | `WIN_CERTIFICATE.dwLength` |
| 0x014 | 2 | 0x0200 | `wRevision` |
| 0x016 | 2 | 0x0EF1 | `wCertificateType` (`WIN_CERT_TYPE_EFI_GUID`) |
| 0x018 | 16 | `{4AAFD29D-68DF-49EE-8AA9-347D375665A7}` | `CertType` |
| 0x028 | 0xEA6 | PKCS#7 `SignedData` | Without `ContentInfo` wrapper, SHA-256 / RSA, detached (no `eContent`), no signed attributes |
| 0xECE | 0x716 | Signature list | Windows Phone Production PCA 2012 |
| 0x15E4 | 0x56E | Signature list | Nokia Software Signing CA |

Certificates in the `SignedData`:

| Subject | Issuer | Validity |
|---------|--------|----------|
| Windows Phone UEFI Key Exchange Key (signer) | Windows Phone KEK CA 2012 | 2012-10-10 → 2014-01-10 |
| Windows Phone KEK CA 2012 | Microsoft Corporation Third Party Marketplace Root | 2012-07-06 → 2027-07-06 |

Both organisation fields of the KEK CA are spelled `Microsoft Coporation` in the certificates. The firmware needs the matching key in `KEK` to accept the write; the phone's `KEK` isn't known.

### Signature lists

Each list is an `EFI_SIGNATURE_LIST` of type `EFI_CERT_X509_GUID` with one DER certificate. All three `db` images use these certificates, in different orders:

| Image | Address | Size | Certificates, in order | `SignatureOwner` |
|-------|---------|------|------------------------|------------------|
| Known image 1 | 0x1002438 | 0xC84 | PCA 2012, Nokia | `{4E6F6B69-6147-5549-4447-656E65726963}` |
| Known image 2 | 0x10010B0 | 0x1385 | PCA 2011, Nokia, PCA 2012 | `{4E6F6B69-6147-5549-4447-656E65726963}` |
| New image | 0x1005F0E | 0xC84 | PCA 2012, Nokia | `{77FA9ABD-0359-4D32-BD60-28F4E78F784B}` |

| Certificate | Issuer | Validity | Serial | SHA-256 |
|-------------|--------|----------|--------|---------|
| PCA 2011: Microsoft Windows Phone PCA 2011 | Microsoft Root Certificate Authority 2010 | 2011-02-28 → 2035-06-23 | `610B5C91000000000005` | `AE378D79D44CC75CEE8BAE50DD8BCBF2D4FF7C598B62FE75C3CE234C4001AFD9` |
| PCA 2012: Microsoft Windows Phone Production PCA 2012 | Microsoft Root Certificate Authority 2010 | 2012-07-24 → 2027-07-24 | `330000000BFCF98E584C1550BF00000000000B` | `E6A9B56A89AA3B191D23A6FB7FECB1F09DED4552A682FCF72B1D479C3B23C9BA` |
| Nokia Software Signing CA | Nokia Root CA | 2012-05-23 → 2029-08-27 | `025B` | `0EBB4B204EFD7FA5547A84F653CE41C7046246565068A8A19B5D8657DC79F2DB` |

- The old owner `{4E6F6B69-…}` isn't a random GUID: its value is the ASCII text `NokiaGUIDGeneric`. The new owner `{77FA9ABD-…}` is the value Microsoft uses in its own UEFI signature lists (not stated in the binary).
- From image 1, the update only changes the owner of the two certificates, so the trust doesn't change.
- From image 2, it also removes PCA 2011. Anything signed only through that certificate should stop being accepted by `db` ? (the firmware's verification isn't analysed).

### Task Scheduler RPC

After the `db` step, `sub_1003BCC` (0x1003BCC) connects to the service with the same code as [ReminderEvents.dll](../libraries/reminderevents.md#rpc): `QueryTransientObjectSecurityDescriptor(9, L"ITaskSchedulerSvcRpc\\Server", &sd)`, `RpcBindingCreateW` (LRPC, no endpoint, `RPC_C_AUTHN_LEVEL_PKT_PRIVACY`, `RPC_C_AUTHN_WINNT`, QoS version 5 identify / dynamic, `ServerSecurityDescriptor = sd`), and `RpcBindingBind` up to 3 times, 500 ms apart, while it fails with 1722, 1708, 1717 or 1753.

Interface `{33D84484-3626-47EE-8C6F-E7E98B113BE1}` version 2.0 (client interface at 0x10030C0, stub descriptor at 0x10036C8).

| Opnum | Stub | Called by | Parameters | Use |
|-------|------|-----------|------------|-----|
| 6 | `sub_1003CF0` | `sub_1003A60` | `[in] GUID *`, `[in] long` (0), returns `long` | Set the state of a task (same call as [`Shell_SetReminderState`](../libraries/shellchromeapi.md#task-scheduler-rpc-reminders), disable ?) |

It's called twice, with these GUIDs:

| Address | GUID |
|---------|------|
| 0x1005010 | `{F9EC1267-D85B-49E6-864D-EE8C0709C338}` |
| 0x1006B94 | `{3081686A-4C38-468B-83B9-AA6AEA939D4C}` |

The second call is made even if the first one fails: the result is ignored. `sub_1003CF0` catches RPC exceptions (`I_RpcExceptionFilter`) and turns them into an HRESULT. If the connection fails, opnum 6 isn't called. `RpcBindingFree` then frees the binding.

These tasks are probably not reminders, but what they run isn't known: the task definitions aren't in this binary.
