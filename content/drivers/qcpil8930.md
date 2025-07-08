## Qcpil8930.sys

On demande, communicate with Qcscm8930.sys to load images of subsystems.
It parses .mbn files, reserves physical memory to load images and then send commands to SCM.   

Registries of the driver:  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\qcPILC`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Enum\ACPI\QCOM0E00\2&daba3ff&0`  
`HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e97d-e325-11ce-bfc1-08002be10318}\0053`

Registry key `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\qcPILC\Parameters`:  
| Registry value | value | comment |
|----------------|-------|---------|
| TestState | 0 | State of the test process |
| TestDataBasePath | `C:\PIL` | Folder where _pilraw_ files are created  |

GUID of the ETW provider:  
`{4B2AE6CB-2AFC-4251-8DF6-55939744250F}`

It communicates with the following devices:  
| Device | Driver | Comment |
|--------|--------|---------|
| \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68} | qcscm8930.sys | Qualcomm Secure Channel Manager Device |

### internal IOCTL 0x9C412400

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x900 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| test load image | 536 | 0 |

Content of the input buffer:  
| Bytes 00-0F | Bytes 10-217 |
|-------------|--------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | Null terminated WCHAR path\file.mbn  |

The first 16 bytes of the input buffer is the GUID of the RPE client.  
Example:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

This command parses and loads the .mbn file in memory but doesn't communicate with the SCM device.
I guess it must be used with the `TestState` registry parameter.

### internal IOCTL 0x9C412404

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x901 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| force authenticate | 0 | 0 |


This command forces to `true` the internal flag indicating whether the image is authenticated or not.
I guess it must be used with the `TestState` registry parameter.

### internal IOCTL 0x9C412408

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x902 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| reload last image | 16 | 0 |

Content of the input buffer:  
| Bytes 00-0F |
|-------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 |

The first 16 bytes of the input buffer is the GUID of the RPE client.  
Example:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

This command reloads the last image sent by the RPE client and communicates with the SCM using the last channel ID indicated by the RPE client.  

### internal IOCTL 0x9C41240C

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x903 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| test reload image | 16 | 0 |

Content of the input buffer:  
| Bytes 00-0F |
|-------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 |

The first 16 bytes of the input buffer is the GUID of the RPE client.  
Example:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

This command reloads the last .mbn file sent by the RPE client but doesn't communicate with the SCM device.
I guess it must be used with the `TestState` registry parameter.

### internal IOCTL 0x9C412410

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x904 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| IOCTL_PIL_TZ_AUTH_IMAGE_AND_RESET | 16 | 0 |

Content of the input buffer:  
| Bytes 00-0F |
|-------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 |

The first 16 bytes of the input buffer is the GUID of the RPE client.  
Example:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

This command sends a command to the SCM device to authenticate the last image sent by the RPE client and reset the subsystem identified by the last channel ID given by the RPE client.  

NTStatus returned:
| Value | Comment |
|-------|---------|
| 0xE0008000 | No image to authentify |

### internal IOCTL 0x9C412414

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x905 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| Set Test | 4 | 0 |

Content of the input buffer:  
| Bytes 00-03 |
|-------------|
| 01 00 00 00 |

The content of the input buffer is a value between 1 and 4 included.  
Depending of the current value of the `TestState` registry parameter, it set the `TestState` with a new value:  
| InputBuffer value | Current `TestState` | New `TestState` |
|-------------------|---------------------|-----------------|
| 1					| 0                   | 1				|
| 2					| 2					  | 3				|
| 3					| 2					  | 4				|
| 4					| any				  | 0               |

| `TestState` | Comment |
|-------------|---------|
| 0			  | Test mode disabled (default) |
| 1           | Start test mode. During the next restart of the device, the `TestState` will be set to 2 by the `EvtDriverDeviceAdd` function. |
| 2			  | Test mode enabled |
| 3           | When loading a .mbn file (with 0x9C412400 or 0x9C41241C), it writes the _pilraw_ files in the folder indicated by the `TestDataBasePath` registry parameter. |
| 4			  | ? |
| 5           | Test mode disabled |

### internal IOCTL 0x9C412418

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x906 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| get TestState | 0 | 4 |

Content of the output buffer:  
| Bytes 00-03 |
|-------------|
| 01 00 00 00 |

The content of the input buffer is current value of the `TestState`.

### internal IOCTL 0x9C41241C

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x907 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| IOCTL_PIL_TZ_LOAD_IMAGE | 540 | 0 |

Content of the input buffer:  
| Bytes 00-0F | Bytes 10-13 | Bytes 14-21B |
|-------------|-------------|--------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | 06 00 00 00 | Null terminated WCHAR path\file.mbn |

The first 16 bytes of the input buffer is the GUID of the RPE client.  

The bytes from position 16 to 19 is the ID of the secured channel corresponding to a subsystem.  

This command parses and loads the .mbn file in memory to prepare the reset of the subsystem identified by the channel ID.  

NTStatus returned:
| Value | Comment |
|-------|---------|
| 0xE0008005 | Image already loaded |

| GUID RPE client | Secured channel ID | .mbn file path | file size (in bytes) | IoCtl sent by |
|-----------------|--------------------|----------------|----------------------|---------------|
| {d58464d3-5b28-4ea6-a2e2-e8e57c5c69b8} | 0x00000001 | `\SystemRoot\system32\qcadsp8930.mbn` | 6091904 | qcadsp8930.sys |
| {936dc601-5530-4b82-9d2a-72a488bec7c1} | 0x00000004 | `\SystemRoot\system32\qcdsp28930.mbn` | 29776208 | qcamss8930.sys |
| {ba58766d-abf2-4402-88d7-90ab243f6c77} | 0x00000005 | `\SystemRoot\system32\qcdsp1v18930.mbn` | 2839752 | qcamss8930.sys |
| {93367d0f-35ce-4ec4-8e38-bb33030c58b2} | 0x00000006 | `\SystemRoot\system32\qcwcnss8930.mbn` | 2007056 | qcwcn8930.sys |

#### _PilRaw[Hash]NN-0xAAAAAAAA_ files generated with `TestState` 3 

_Hash_ files contains security certificates.  
_NN_ is the order of creation.  
_AAAAAAAA_ is a physical address.    

| File name | size (in bytes) |
|-----------|-----------------|
| pilrawHash01-0x9F015114.bin | 12288   |
| pilrawHash01-0x9F4970F4.bin | 8608    |
| pilrawHash01-0x9FE8B194.bin | 8708    |
| pilrawHash01-0x9FF2E414.bin | 9108    |
| pilraw02-0x28400000.bin     | 65536   |
| pilraw02-0x89000000.bin     | 1048660 |
| pilraw02-0x8D400000.bin     | 2676    |
| pilraw02-0x8F000000.bin     | 9812    |
| pilraw03-0x89100060.bin     | 5729776 |
| pilraw03-0x8D4F8000.bin     | 1038704 |
| pilraw03-0x8DA00000.bin     | 4516016 |
| pilraw03-0x8F010000.bin     | 28672   |
| pilraw04-0x89676E50.bin     | 7468904 |
| pilraw04-0x8D5F6000.bin     | 638524  |
| pilraw04-0x8DE4F000.bin     | 1291574 |
| pilraw04-0x8F017000.bin     | 4096    |
| pilraw05-0x89DC0000.bin     | 16384   |
| pilraw05-0x8D693000.bin     | 2066880 |
| pilraw05-0x8DF8C000.bin     | 245776  |
| pilraw05-0x8F018000.bin     | 4361200 |
| pilraw06-0x89E00000.bin     | 8919408 |
| pilraw06-0x8D900000.bin     | 94208   |
| pilraw06-0x8E000000.bin     | 1688448 |
| pilraw07-0x8A700000.bin     | 5347546 |
| pilraw07-0x8D940000.bin     | 87296   |
| pilraw08-0x8AC1B000.bin     | 29591616|
| pilraw08-0x8D401000.bin     | 11436   |
| pilraw09-0x8C854000.bin     | 79600   |
| pilraw09-0x8D403CC0.bin     | 9692    |
| pilraw10-0x8C868000.bin     | 162128  |
| pilraw10-0x8D4064C0.bin     | 68423   |
| pilraw11-0x8D418000.bin     | 4088    |
| pilraw13-0x8D424000.bin     | 117708  |
| pilraw14-0x8D440BE0.bin     | 153188  |
| pilraw21-0x8D41A000.bin     | 3572    |
| pilraw22-0x8D494000.bin     | 28348   |
| pilraw23-0x8D49AEC0.bin     | 20208   |
| pilraw25-0x8D4B0000.bin     | 74640   |
| pilraw26-0x8D4C23A0.bin     | 50396   |
| pilraw27-0x8D4CE880.bin     | 10560   |
| pilraw29-0x8D4E0000.bin     | 91336   |


### internal IOCTL 0x9C412420

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x908 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| IOCTL_PIL_TZ_RELOAD_IMAGE | 20 | 0 |

Content of the input buffer:  
| Bytes 00-0F | Bytes 10-13 |
|-------------|-------------|
| 0f 7d 36 93 ce 35 c4 4e 8e 38 bb 33 03 0c 58 b2 | 06 00 00 00 |

The first 16 bytes of the input buffer is the GUID of the RPE client.  
Example:  
`93367d0f-35ce-4ec4-8e38-bb33030c58b2`

The bytes from position 16 to 19 is the ID of the secured channel corresponding to a subsystem.  

This command reloads the last .mbn file sent by the RPE client to prepare the reset of the subsystem identified by the channel ID.

NTStatus returned:
| Value | Comment |
|-------|---------|
| 0xE0008003 | No image to reload |

### internal IOCTL 0x9C412424

This IOCTL is processed by Qcpil8930.sys  

| Property | Value |
|----------|-------|
| Device | 0xC41 |
| Function | 0x909 |
| Access | FILE_ANY_ACCESS |
| Method | METHOD_BUFFERED |


| Name | InputBuffer size | OutputBuffer Size |
|------|------------------|--------------------|
| set TestDataBasePath | 520 | 0 |

Content of the input buffer:  
| Bytes 00-207 |
|--------------|
| Null terminated WCHAR path |

The input buffer is the new value of the `TestDataBasePath` registry parameter.

### internal IOCTL 0xC3514004

This IOCTL is sent by qcpil8930.sys to qcscm8930.sys

| Property | Value |
|----------|-------|
| Device | 0x351 |
| Function | 0x1 |
| Access | FILE_READ_ACCESS |
| Method | METHOD_BUFFERED |


| Name | Device symbolic link name | InputBuffer size | OutputBuffer Size |
|------|-------------|------------------|--------------------|
| Send command | \??\ACPI#QCOM0E90#0#{41c66d2a-a9f1-40ca-a329-ae096c03ee68} | Depends on the command | same as InputBuffer |

#### Command 0x801 "Load image"

InputBuffer:  
| Position | Value | Comment |
|----------|-------|---------|
| Bytes 00-03 | 18 00 00 00 | Packet size ? |
| Bytes 04-07 | 10 00 00 00 | Packet type ? |
| Bytes 08-0B | 00 00 00 00 | ? |
| Bytes 0C-0F | 01 08 00 00 | Command |
| Bytes 10-13 | 06 00 00 00 | Secured channel ID |
| Bytes 14-18 | ?? ?? ?? ?? | Physical address |

OutputBuffer:  
| Position | Value | Comment |
|----------|-------|---------|
| Bytes 00-03 | 18 00 00 00 | Packet size ? |
| Bytes 04-07 | 10 00 00 00 | Packet type ? |
| Bytes 08-0B | ?? ?? ?? ?? | ? |
| Bytes 0C-0F | 01 08 00 00 | Command |
| Bytes 10-13 | 06 00 00 00 | Secured channel ID |
| Bytes 14-18 | ?? ?? ?? ?? | Physical address |

#### Command 0x805 "Authenticate image"

InputBuffer:  
| Position | Value | Comment |
|----------|-------|---------|
| Bytes 00-03 | 18 00 00 00 | Packet size ? |
| Bytes 04-07 | 10 00 00 00 | Packet type ? |
| Bytes 08-0B | 00 00 00 00 | ? |
| Bytes 0C-0F | 05 08 00 00 | Command |
| Bytes 10-13 | 06 00 00 00 | Secured channel ID |

OutputBuffer:  
| Position | Value | Comment |
|----------|-------|---------|
| Bytes 00-03 | 18 00 00 00 | Packet size ? |
| Bytes 04-07 | 10 00 00 00 | Packet type ? |
| Bytes 08-0B | 01 00 00 00 | 1 = authentication successfull |
| Bytes 0C-0F | 05 08 00 00 | Command |
| Bytes 10-13 | 06 00 00 00 | Secured channel ID |

#### Command 0x806 "Reload image"

InputBuffer:  
| Position | Value | Comment |
|----------|-------|---------|
| Bytes 00-03 | 18 00 00 00 | Packet size ? |
| Bytes 04-07 | 10 00 00 00 | Packet type ? |
| Bytes 08-0B | 00 00 00 00 | ? |
| Bytes 0C-0F | 06 08 00 00 | Command |
| Bytes 10-13 | 06 00 00 00 | Secured channel ID |

OutputBuffer:  
| Position | Value | Comment |
|----------|-------|---------|
| Bytes 00-03 | 18 00 00 00 | Packet size ? |
| Bytes 04-07 | 10 00 00 00 | Packet type ? |
| Bytes 08-0B | 01 00 00 00 | 1 = success |
| Bytes 0C-0F | 06 08 00 00 | Command |
| Bytes 10-13 | 06 00 00 00 | Secured channel ID |
