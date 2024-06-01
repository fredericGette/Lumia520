# eMMC partitions of LineageOS 14.1

eMMC size : 0x1D2000000 octets

| Name     | Description | Size (bytes) |
|----------|-------------|--------------|
|DPP       | | 0x000800000 |
|fsg       | FileSystem Golden | 0x000300000 |
|SSD       | Secure Software Download | 0x000004000 |
|SBL1      | Secondary BootLoader | 0x000176E00 |
|HACK      | Bootloader unlock | 0x000000200 |
|SBL2      | Secondary BootLoader | 0x000177000 |
|SBL3      | Secondary BootLoader | 0x000200000 | 
|aboot     | LittleKernel | 0x000271000 |
|RPM       | Resource & Power Management | 0x00007D000 |
|TZ        | ARM TrustZone | 0x00007D000 |
|WINSECAPP | | 0x000080000 |
|boot      | Core of Android | 0x001400000 |
|recovery  | Recovery menu | 0x001400000 |
|modem     | Phone modem - baseband | 0x002C20600 |
|TA        | Trusted Application | 0x000200000 |
|modemst1  | | 0x000300000 |
|modemst2  | | 0x000300000 |
|system    | Main system | 0x04B000000 |
|cache     | System and application cache |0x00C800000 |
|userdata  | User data | 0x16E8FBE00 |
