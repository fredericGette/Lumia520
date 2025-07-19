## Qcwcn8930.sys

Manage the loading of the WCN image and the reset of the subsystem.  
After the reset of the WCN subsystem, it creates the PDO for the Wifi, the Bluetooth and the FM radio.  

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcwcn`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0E20\2&daba3ff&0`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0079`

| Registry value | value | comment |
|----------------|-------|---------|
| WcnImagePath | `\SystemRoot\system32\qcwcnss8930.mbn` | Filename of the WCN image. Default is `C:\Windows\System32\WCNSS.MBN` |
| RestartEnabled | 0x00=SSR(SubSystem Restart) disabled, 0x01=SSR(SubSystem Restart) enabled, 0x02=WCN_RESTART_SURPRISE_REMOVE_ONLY | ? |
| MaxRestartCount | ? | ? |
| RestartTimer | ? | ? |

GUID of the ETW provider:  
`{98D8E493-33D4-4802-AD80-4DD111760D19}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \Device\RPEN | qcrpen8930.sys | RPE Notifier |
| \Device\SMSM | qcsmsm8930.sys | Shared Memory State Machine |
| \Device\PIL | qcpil8930.sys | Peripheral Image Loader |

Qcwcn8930.sys also configures the `IRIS XO` clock of the WCN subsystem by updating the `PMU_CFG` register (Power Management Unit configuration register).  
The physical address of this register is hardcoded in the driver: 0x03204028  

The configuration of the `IRIS XO` clock is done by the following algorithm:

1. Write 0x00000000
2. Delay for 500 microseconds
3. Set bits 4 (IRIS_XO_EN) and 5 (GC_BUS_MUX_SEL)
4. Delay for 500 microseconds
5. Clear bits 0 (WARM_BOOT) and 2 (IRIS_XO_MODE)
6. Delay for 500 microseconds	
7. Set bit 3 (IRIS_XO_CFG)
8. Loop while bit 6 (IRIS_XO_CFG_STS) is set, delay for 600 microseconds in each iteration.	
9. Clear bits 3 (IRIS_XO_CFG) and 5 (GC_BUS_MUX_SEL)
10. Delay for 500 microseconds
11. Delay for 200 milliseconds

| Bit | Name | Comment |
|-----|------|---------|
| 0 |	WARM_BOOT |	warm/cold boot indication. |
| 2,1	| IRIS_XO_MODE |IRIS XO mode. 2'b11 : 48MHz XO 2'b01 : 38.4MHz TCXO 2'b00 :19.2MHz TCXO |
| 3	| IRIS_XO_CFG	| start IRIS XO configuration |
| 4	| IRIS_XO_EN | 0x1: enable XO during configuration 0x0: disable XO during configuration |
| 5	| GC_BUS_MUX_SEL | 0x1: GC bus is controlled by riva_top 0x0: GC bus is controlled by WLAN PHY |
| 6	| IRIS_XO_CFG_STS	| IRIS XO configuration status. 0x1: in progress 0x0: done or idle |

Example of WPP logs at the start of the phone:
```
[1]0004.0084::06/06/2025-12:19:03.186 [qcwcn8930_guid01]!EvtDriverDeviceAdd[58]!Enter
[1]0004.0084::06/06/2025-12:19:03.187 [qcwcn8930_guid01]!EvtDriverDeviceAdd[60]!WdfDeviceCreate succeeded, hDevice=7417FC10
[1]0004.0084::06/06/2025-12:19:03.188 [qcwcn8930_guid01]!DriverEntry[28]!Enter
[1]0004.0084::06/06/2025-12:19:03.189 [qcwcn8930_guid01]!read_Registry[29]!Will load the subsystem image from the path obtained from registry: \SystemRoot\system32\qcwcnss8930.mbn
[1]0004.0084::06/06/2025-12:19:03.190 [qcwcn8930_guid01]!read_Registry[35]!RestartEnabled=1, WCN SSR will be enabled
[1]0004.0084::06/06/2025-12:19:03.191 [qcwcn8930_guid01]!read_Registry[36]!MaxRestartCount, WdfRegistryQueryULong returned 0xc0000034(STATUS_OBJECT_NAME_NOT_FOUND)
[1]0004.0084::06/06/2025-12:19:03.191 [qcwcn8930_guid01]!read_Registry[37]!Default value will be used for MaxRestartCount
[1]0004.0084::06/06/2025-12:19:03.193 [qcwcn8930_guid01]!read_Registry[38]!MaxRestartCount=30
[1]0004.0084::06/06/2025-12:19:03.200 [qcwcn8930_guid01]!read_Registry[39]!RestartTimer, WdfRegistryQueryULong returned 0xc0000034(STATUS_OBJECT_NAME_NOT_FOUND)
[1]0004.0084::06/06/2025-12:19:03.201 [qcwcn8930_guid01]!read_Registry[40]!Default value will be used for RestartTimer
[1]0004.0084::06/06/2025-12:19:03.201 [qcwcn8930_guid01]!read_Registry[41]!RestartTimer=60
[1]0004.0084::06/06/2025-12:19:03.203 [qcwcn8930_guid04]!RpeInit[36]!RpeInit OK
[1]0004.0084::06/06/2025-12:19:03.203 [qcwcn8930_guid04]!RpeInit[37]!Guid is 93367d0f-35ce-4ec4-8e38-bb33030c58b2
[1]0004.0084::06/06/2025-12:19:03.204 [qcwcn8930_guid04]!RpeInit[38]!Driver name is WCN
[1]0004.0084::06/06/2025-12:19:03.205 [qcwcn8930_guid04]!RpeInit[39]!Version is 0
[1]0004.0084::06/06/2025-12:19:03.206 [qcwcn8930_guid04]!RpeInit[40]!Size is 16
[0]0004.0084::06/06/2025-12:19:03.208 [qcwcn8930_guid04]!RpeInit[41]!RpeClientInitMultiSegment returned STATUS_SUCCESS. RpeClientInitMultiSegment OK or RPE driver not avail. Continue
[0]0004.0084::06/06/2025-12:19:03.217 [qcwcn8930_guid04]!RegisterRPEStateNotification[51]!Waiting for readiness of WCN subsystem
[0]0004.0084::06/06/2025-12:19:03.222 [qcwcn8930_guid04]!RpeInit[43]!RegisterRPEStateNotification with GUID_05 returned STATUS_SUCCESS. RegisterRPEStateNotification OK or RPE driver not avail. Continue
[0]0004.0084::06/06/2025-12:19:03.224 [qcwcn8930_guid04]!RegisterRPEStateNotification[51]!Waiting for readiness of WCN subsystem
[0]0004.0084::06/06/2025-12:19:03.230 [qcwcn8930_guid04]!RpeInit[45]!RegisterRPEStateNotification with GUID_06 returned STATUS_SUCCESS. RegisterRPEStateNotification OK or RPE driver not avail. Continue
[1]0004.01B4::06/06/2025-12:19:04.079 [qcwcn8930_guid01]!OpenIOTargetByName[103]!Target Device PDEVICE_OBJECT=8BDFB030
[1]0004.01B4::06/06/2025-12:19:04.081 [qcwcn8930_guid01]!OpenIOTargetByName[104]!PDO PDEVICE_OBJECT=88958A90
[1]0004.01B4::06/06/2025-12:19:04.082 [qcwcn8930_guid01]!OpenIOTargetByName[105]!File Object PFILE_OBJECT=8BFCBBD8
[1]0004.01B4::06/06/2025-12:19:04.083 [qcwcn8930_guid01]!OpenIOTargetByName[106]!File Handle HANDLE=800004D4
[1]0004.01B4::06/06/2025-12:19:04.084 [qcwcn8930_guid01]!SendInternalIoctlSynchronously[107]!Enter
[1]0004.01B4::06/06/2025-12:19:04.084 [qcwcn8930_guid01]!SendInternalIoctlSynchronously[107]!Enter
[1]0004.01B4::06/06/2025-12:19:04.085 [qcwcn8930_guid01]!OpenIOTarget_PIL[12]!Enter
[1]0004.01B4::06/06/2025-12:19:04.086 [qcwcn8930_guid01]!OpenIOTarget_PIL[16]!Target Device PDEVICE_OBJECT=8BC9BD98
[1]0004.01B4::06/06/2025-12:19:04.087 [qcwcn8930_guid01]!OpenIOTarget_PIL[17]!PDO PDEVICE_OBJECT=8895B850
[1]0004.01B4::06/06/2025-12:19:04.088 [qcwcn8930_guid01]!OpenIOTarget_PIL[18]!File Object PFILE_OBJECT=8BFCFA28
[1]0004.01B4::06/06/2025-12:19:04.089 [qcwcn8930_guid01]!OpenIOTarget_PIL[19]!File Handle HANDLE=800004B8
[1]0004.01B4::06/06/2025-12:19:04.089 [qcwcn8930_guid01]!OpenIOTarget_PIL[20]!Succeeded in opening IOTarget on PIL driver, saved IOTarget to device context
[1]0004.01B4::06/06/2025-12:19:04.091 [qcwcn8930_guid01]!sub_40E3C4[133]!2nd parameter value=1
[1]0004.01B4::06/06/2025-12:19:04.092 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=19
[1]0004.01B4::06/06/2025-12:19:04.092 [qcwcn8930_guid01]!call_PoFxPowerControl[109]!Enter
[0]0004.01B4::06/06/2025-12:19:04.114 [qcwcn8930_guid01]!call_PoFxPowerControl[110]!PoFxPowerControl returns STATUS_SUCCESS
[0]0004.01B4::06/06/2025-12:19:04.115 [qcwcn8930_guid01]!call_PoFxPowerControl[111]!PoFxPowerControl output status PEP_STATE_SYNC_PATH
[0]0004.01B4::06/06/2025-12:19:04.119 [qcwcn8930_guid01]!call_PoFxPowerControl[112]!exit 2nd parameter value=0x00000000(FALSE)
[0]0004.01B4::06/06/2025-12:19:04.120 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=7
[0]0004.01B4::06/06/2025-12:19:04.120 [qcwcn8930_guid04]!send_IoCtl_0x3200C_Request_01[52]!Enter
[0]0004.01B4::06/06/2025-12:19:04.121 [qcwcn8930_guid04]!send_IoCtl_0x3200C_Request_02[52]!Enter
[0]0004.01B4::06/06/2025-12:19:04.122 [qcwcn8930_guid01]!sub_40E3C4[150]!Performing Load image and reset hardware for WCNSS...
[0]0004.01B4::06/06/2025-12:19:04.123 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[44]!Enter
[0]0004.01B4::06/06/2025-12:19:04.124 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[46]!Requesting PIL driver to load WCN image
[0]0004.01B4::06/06/2025-12:19:04.126 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[47]!Request to load WCN image created, sending to PIL driver
[1]0004.01B4::06/06/2025-12:19:04.190 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[52]!WCN image loaded, Physical address returned from PIL driver: 8F001228
[1]0004.01B4::06/06/2025-12:19:04.192 [qcwcn8930_guid01]!send_IOCTL_PIL_TZ_LOAD_or_RELOAD_IMAGE[53]!Loaded WCN subsystem hardware with image: \SystemRoot\system32\qcwcnss8930.mbn
[1]0004.01B4::06/06/2025-12:19:04.193 [qcwcn8930_guid01]!sub_40E3C4[152]!Loading image for WCN subsystem through PIL succeeded
[1]0004.01B4::06/06/2025-12:19:04.494 [qcwcn8930_guid01]!sub_40E3C4[153]!IRIS XO clock is configured
[1]0004.01B4::06/06/2025-12:19:04.495 [qcwcn8930_guid01]!AuthAndRelease[54]!Enter
[1]0004.01B4::06/06/2025-12:19:04.496 [qcwcn8930_guid01]!AuthAndRelease[55]!Requesting PIL driver to reset WCN hardware after the image is loaded
[1]0004.01B4::06/06/2025-12:19:04.936 [qcwcn8930_guid01]!AuthAndRelease[118]!AuthAndRelease value=10
[1]0004.01B4::06/06/2025-12:19:04.938 [qcwcn8930_guid01]!sub_40E3C4[155]!Authorize and Reset for WCN subsystem through PIL succeeded
[1]0004.01B4::06/06/2025-12:19:04.939 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=21
[0]0004.015C::06/06/2025-12:19:05.018 [qcwcn8930_guid04]!EvtSSUp[53]!Enter
[0]0004.015C::06/06/2025-12:19:05.020 [qcwcn8930_guid04]!EvtSSUp[54]!WCN subsystem is up and running
[1]0004.0178::06/06/2025-12:19:05.021 [qcwcn8930_guid01]!sub_40E3C4[133]!2nd parameter value=4
[1]0004.0178::06/06/2025-12:19:05.022 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=18
[0]0004.0178::06/06/2025-12:19:22.278 [qcwcn8930_guid01]!sub_40E3C4[133]!2nd parameter value=6
[0]0004.0178::06/06/2025-12:19:22.280 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=0
[0]0004.0178::06/06/2025-12:19:22.281 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=20
[0]0004.0178::06/06/2025-12:19:22.282 [qcwcn8930_guid01]!call_PoFxPowerControl[109]!Enter
[1]0004.0198::06/06/2025-12:19:22.283 [qcwcn8930_guid01]!call_PoFxPowerControl[123]!Enter
[1]0004.0198::06/06/2025-12:19:22.284 [qcwcn8930_guid01]!call_PoFxPowerControl[123]!Enter
[1]0004.0198::06/06/2025-12:19:22.285 [qcwcn8930_guid01]!call_PoFxPowerControl[123]!Enter
[0]0004.0178::06/06/2025-12:19:22.291 [qcwcn8930_guid01]!call_PoFxPowerControl[110]!PoFxPowerControl returns STATUS_SUCCESS
[0]0004.0178::06/06/2025-12:19:22.292 [qcwcn8930_guid01]!call_PoFxPowerControl[111]!PoFxPowerControl output status PEP_STATE_SYNC_PATH
[0]0004.0178::06/06/2025-12:19:22.295 [qcwcn8930_guid01]!call_PoFxPowerControl[112]!exit 2nd parameter value=0x00000001(TRUE)
[0]0004.0178::06/06/2025-12:19:22.296 [qcwcn8930_guid01]!change_InterfaceClassGUID_state[23]!Enter
[1]0004.0178::06/06/2025-12:19:22.298 [qcwcn8930_guid01]!change_InterfaceClassGUID_state[26]!WCN device interface is published
[1]0004.0178::06/06/2025-12:19:22.298 [qcwcn8930_guid01]!setField30[22]!Enter
[1]0004.0178::06/06/2025-12:19:22.299 [qcwcn8930_guid01]!sub_40E3C4[147]!published interface successfully
[1]0004.0178::06/06/2025-12:19:22.301 [qcwcn8930_guid01]!sub_40E3C4[149]!RPE_STATE_ID_READY_FOR_COMMANDS
[1]0004.0178::06/06/2025-12:19:22.302 [qcwcn8930_guid01]!sub_40E3C4[135]!switch value=8
```


### internal IOCTL 0x32008

This IOCTL is sent by Qcwcn8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x802 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_INTERNAL_SMSM_RESET | \Device\SMSM | 4 | 4 |

Content of the input buffer:  
| Bytes 00-03 | 
|-------------|
| 01 00 00 00 | 

The output buffer contains a pointer to the function `FuncSmsmReset` 

### internal IOCTL 0x32010

This IOCTL is sent by Qcwcn8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x804 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_INTERNAL_SMSM_STATE_GET | \Device\SMSM | 0 | 4 |

The output buffer contains a pointer to the function `smsm_state_get` 

### internal IOCTL 0x3200C

This IOCTL is sent by Qcwcn8930.sys  

| Property | Value |
|----------|-------|
| Device | 0x3 |
| Function | 0x803 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |

| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Callback | \Device\SMSM | 12 | 0 |

The completion routine of the device control request is executed in case of success or error during the reset of the subsystem.` 

Content of the input buffer when we set the error callback:  
| Bytes | Value | Comment | 
|-------|-------|---------|
| 00-03 | 03 00 00 00 | SMSM_STATE_WCN |
| 04-07 | 40 00 00 00 | SMSM_RESET |
| 08-0B | 40 00 00 00 | SMSM_RESET |

Content of the input buffer when we set the success callback:  
| Bytes 00-0C | 
|-------------|
| 00 00 00 00 00 00 00 00 00 00 00 00 |


### internal IOCTL 0x9C41241C

This IOCTL is sent by Qcwcn8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x907 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_LOAD_IMAGE | \Device\PIL | 540 | 4 |

Content of the input buffer:  
| Bytes 00-0F | Bytes 10-13 | Bytes 14-21B |
|-------------|-------------|--------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | 06 00 00 00 | Null terminated WCHAR string `\SystemRoot\system32\qcwcnss8930.mbn` |

The first 16 bytes of the input buffer is the GUID of the RPE client:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

The output buffer contains the physical address where the image was loaded.


### internal IOCTL 0x9C412420

This IOCTL is sent by Qcwcn8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x908 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_RELOAD_IMAGE | \Device\PIL | 20 | 4 |

Content of the input buffer:  
| Bytes 00-0F | Bytes 10-13 |
|-------------|-------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | 06 00 00 00 |

The first 16 bytes of the input buffer is the GUID of the RPE client:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

The output buffer contains the physical address where the image was loaded.


### internal IOCTL 0x9C412410

This IOCTL is sent by Qcwcn8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| IOCTL_PIL_TZ_AUTH_IMAGE_AND_RESET | \Device\PIL | 0 | 0 |

