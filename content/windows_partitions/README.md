# eMMC partitions of Windows Phone 8.1

Number of eMMC sectors: 0xE90000  (depends on eMMC manufacturer)  
Sector size : 512 bytes

| Sectors         | Name             | in .ffu              | Informations |
|----------------:|:-----------------|:--------------------:|--------------|
| 0x0-0x0         | MBR              | :white_check_mark:   | **Master Boot Record**<br>*Read-only* |
| 0x1-0x23        | GPT              | :white_check_mark:   | **GUID Table Partition**<br>*Read-only* |
| 0x24-0xFFF      |                  |                      | Empty space. |
| 0x1000-0x4FFF   | DPP              | :white_large_square: | **Device Provisioning Partition**<br>*Read-only*<br>File system:`FAT`<br>GUID:`EBD0A0A2-B9E5-4433-87C0-68B6B72699C7`<br>Attribute:`0x8000000000000000` |
| 0x5000-0x67FF   | MODEM_FSG        | :white_large_square: | **Qualcomm Modem golden file system**<br>*Read-only*<br>GUID:`638FF8E2-22C9-E33B-8F5D-0E81686A68CB`<br>Attribute:`0x8000000000000000` |
| 0x7000-0x701F   | SSD              | :white_large_square: | **Qualcomm Secure Software Download**<br>*Read-only*<br>GUID:`2C86E742-745E-4FDD-BFD8-B6A7AC638772`<br>Attribute:`0x8000000000000000` |
| 0x7020-0x7FFF   |                  |                      | Empty space. |
| 0x8000-0x8BB7   | SBL1             | :white_check_mark:   | **Qualcomm Secondary Bootloader**<br>Last sector is the HACK partition when unlocked.<br>*Read-only*<br>GUID:`DEA0BA2C-CBDD-4805-B4F9-F428251C3E98`<br>Attribute:`0x8000000000000000`|
| 0x8BB7-0x8BB7   | HACK             | :white_large_square: | **WPinternals**<br>Exists only when the bootloader is unlocked.<br>*Read-only*<br>GUID(copy of SBL2):`8C6B52AD-8A9E-4398-AD09-AE916E53AE2D`<br>Attribute(copy of SBL2):`0x8000000000000000` |
| 0x8BB8-0x8FFF   |                  |                      | Empty space. |
| 0x9000-0x9BB7   | SBL2             | :white_check_mark:   | **Qualcomm Secondary Bootloader**<br>*Read-only*<br>GUID:`8C6B52AD-8A9E-4398-AD09-AE916E53AE2D`<br>GUID(when HACK exists):`74747474-7474-7474-7474-747474747474`<br>Attribute:`0x8000000000000000` |
| 0x9BB8-0x9FFF   |                  |                      | Empty space. |
| 0xA000-0xAFFF   | SBL3             | :white_check_mark:   | **Qualcomm Secondary Bootloader**<br>*Read-only*<br>GUID:`05E044DF-92F1-4325-B69E-374A82E97D6E`<br>Attribute:`0x8000000000000000` |
| 0xB000-0xC387   | UEFI             | :white_check_mark:   | **Nokia/Microsoft Application Bootloader**<br>*Read-only*<br>GUID:`400FFDCD-22E0-47E7-9A23-F16ED9382388`<br>Attribute:`0x8000000000000000` |
| 0xC388-0xCFFF   |                  |                      | Empty space. |
| 0xD000-0xD3E7   | RPM              | :white_check_mark:   | **Qualcomm Resource & Power Management**<br>*Read-only*<br>GUID:`098DF793-D712-413D-9D4E-89D711772228`<br>Attribute:`0x8000000000000000` |
| 0xD3E8-0xDFFF   |                  |                      | Empty space. |
| 0xE000-0xE3E7   | TZ               | :white_check_mark:   | **Qualcomm ARM TrustZone**<br>*Read-only*<br>GUID:`A053AA7F-40B8-4B1C-BA08-2F68AC71A4F4`<br>Attribute:`0x8000000000000000` |
| 0xE3E8-0xEFFF   |                  |                      | Empty space. |
| 0xF000-0xF3FF   | WINSECAPP        | :white_check_mark:   | **Qualcomm fTPM (Firmware Trusted Platform Module) Application**<br>*Read-only*<br>GUID:`69B4201F-A5AD-45EB-9F49-45B38CCDAEF5`<br>Attribute:`0x8000000000000000` |
| 0xF400-0xFFFF   |                  |                      | Empty space. |
| 0x10000-0x10BB7 | BACKUP_SBL1      | :white_large_square: | **Qualcomm Bootloader Backup**<br>*Read-only*<br>GUID:`A3381699-350C-465E-BD5D-FA3AB901A39A`<br>Attribute:`0x8000000000000000` |
| 0x10BB8-0x10FFF |                  |                      | Empty space. |
| 0x11000-0x11BB7 | BACKUP_SBL2      | :white_large_square: | **Qualcomm Bootloader Backup**<br>*Read-only*<br>GUID:`A3381699-350C-465E-BD5D-FA3AB901A39A`<br>Attribute:`0x8000000000000000` |
| 0x11BB8-0x11FFF |                  |                      | Empty space. |
| 0x12000-0x12FFF | BACKUP_SBL3      | :white_large_square: | **Qualcomm Bootloader Backup**<br>*Read-only*<br>GUID:`A3381699-350C-465E-BD5D-FA3AB901A39A`<br>Attribute:`0x8000000000000000` |
| 0x13000-0x14387 | BACKUP_UEFI      | :white_large_square: | **Qualcomm Bootloader Backup**<br>*Read-only*<br>GUID:`A3381699-350C-465E-BD5D-FA3AB901A39A`<br>Attribute:`0x8000000000000000` |
| 0x14388-0x14FFF |                  |                      | Empty space. |
| 0x15000-0x153E7 | BACKUP_RPM       | :white_large_square: | **Qualcomm Bootloader Backup**<br>*Read-only*<br>GUID:`A3381699-350C-465E-BD5D-FA3AB901A39A`<br>Attribute:`0x8000000000000000` |
| 0x153E8-0x15FFF |                  |                      | Empty space. |
| 0x16000-0x163E7 | BACKUP_TZ        | :white_large_square: | **Qualcomm Bootloader Backup**<br>*Read-only*<br>GUID:`A3381699-350C-465E-BD5D-FA3AB901A39A`<br>Attribute:`0x8000000000000000` |
| 0x163E8-0x16FFF |                  |                      | Empty space. |
| 0x17000-0x173FF | BACKUP_WINSECAPP | :white_large_square: | **Qualcomm Bootloader Backup**<br>*Read-only*<br>GUID:`A3381699-350C-465E-BD5D-FA3AB901A39A`<br>Attribute:`0x8000000000000000` |
| 0x17400-0x17FFF |                  |                      | Empty space. |
| 0x18000-0x181FF | UEFI_BS_NV       | :white_large_square: | **Qualcomm UEFI Variable Services Partition**<br>*Non Volatile*<br>*Read-only*<br>GUID:`F0B4F48B-AEBA-4ECF-9142-5DC30CDC3E77`<br>Attribute:`0x8000000000000000` |
| 0x18200-0x18FFF |                  |                      | Empty space. |
| 0x19000-0x191FF | UEFI_NV          | :white_large_square: | **Qualcomm UEFI Variable Services Partition**<br>*Non Volatile*<br>*Read-only*<br>GUID:`74DA3EE7-D422-487C-A573-CE03C261362F`<br>Attribute:`0x8000000000000000` |
| 0x19200-0x19FFF |                  |                      | Empty space. |
| 0x1A000-0x1DFFF | PLAT             | :white_check_mark:   | **Qualcomm ACPI table storage**<br>*Read-only*<br>GUID:`543C031A-4CB6-4897-BFFE-4B485768A8AD`<br>Attribute:`0x8000000000000000` |
| 0x1E000-0x1FFFF |                  |                      | Empty space. |
| 0x20000-0x3FFFF | EFIESP           | :white_check_mark:   | **Qualcomm EFI System Partition**<br>*Read-only*<br>File system:`FAT`<br>GUID:`EBD0A0A2-B9E5-4433-87C0-68B6B72699C7`<br>Attribute:`0x8000000000000000` |
| 0x40000-0x417FF | MODEM_FS1        | :white_large_square: | **Qualcomm Modem live file system**<br>*Read-Write*<br>GUID:`EBBEADAF-22C9-E33B-8F5D-0E81686A68CB`<br>Attribute:`0x8000000000000000` |
| 0x41800-0x41FFF |                  |                      | Empty space. |
| 0x42000-0x437FF | MODEM_FS2        | :white_large_square: | **Qualcomm Modem live file system**<br>*Read-Write*<br>GUID:`EBBEADAF-22C9-E33B-8F5D-0E81686A68CB`<br>Attribute:`0x8000000000000000` |
| 0x43800-0x43FFF |                  |                      | Empty space. |
| 0x44000-0x441FF | UEFI_RT_NV       | :white_large_square: | **Qualcomm UEFI Variable Services Partition**<br>*Non Volatile*<br>*Read-Write*<br>GUID:`6BB94537-7D1C-44D0-9DFE-6D77C011DBFC`<br>Attribute:`0x8000000000000000` |
| 0x44200-0x44FFF |                  |                      | Empty space. |
| 0x45000-0x450FF | UEFI_RT_NV_RPMB  | :white_large_square: | **Qualcomm UEFI Variable Services Partition**<br>*Non Volatile*<br>*Read-Write*<br>GUID:`E35F99CF-0025-4252-A608-CAAA1289CAF4`<br>Attribute:`0x8000000000000000` |
| 0x45100-0x45FFF |                  |                      | Empty space. |
| 0x46000-0x6DF5F | MMOS             | :white_check_mark:   | **Microsoft Manufacturing Operating System**<br>Used in "test" mode (aka "label" mode).<br>*Read-Write*<br>File system:`FAT`<br>GUID:`EBD0A0A2-B9E5-4433-87C0-68B6B72699C7`<br>Attribute:`0x8000000000000000` |
| 0x6DF60-0x6FFFF |                  |                      | Empty space. |
| 0x70000-0x4C7EFF | MainOS           | :white_check_mark:   | **Microsoft Windows Phone 8.1**<br>Used in "normal" mode.<br>*Read-Write*<br>File system:`NTFS`<br>GUID:`EBD0A0A2-B9E5-4433-87C0-68B6B72699C7`<br>Attribute:`0x0000000000000000` |
| 0x4C7F00-0x4C7FFF |                  |                      | Empty space. |
| 0x4C8000-0xE8FFDE | Data             | :white_check_mark:   | **Microsoft**<br>*Read-Write*<br>File system:`NTFS`<br>GUID:`EBD0A0A2-B9E5-4433-87C0-68B6B72699C7`<br>Attribute:`0x8000000000000000` |




