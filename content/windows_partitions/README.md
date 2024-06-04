# eMMC partitions of Windows Phone 8.1

Number of eMMC sectors: 0xE90000

| Name            | Acces | Description | LBA start | LBA end | Size (bytes) | File system | Present in .ffu file | GUID | Attribute flags |
|-----------------|:-----:|-------------|-----------|---------|--------------|-------------|:--------------------:|------|-----------------|
|IS_UNLOCKED_SBL3 | | WPinternals | 0x000040 | 0x000040 | 0x0000000200 | | :white_large_square: | | |
|DPP              | ro | Device Provisioning Partition | 0x001000 | 0x004FFF | 0x0000800000 | FAT | :white_large_square: | EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 | 0x8000000000000000 |
|MODEM_FSG        | ro | Qualcomm Modem golden file system | 0x005000 | 0x0067FF | 0x0000300000 | | :white_large_square: | 638FF8E2-22C9-E33B-8F5D-0E81686A68CB | 0x8000000000000000 |
|SSD              | ro | Qualcomm Secure Software Download | 0x007000 | 0x00701F | 0x0000004000 | | :white_large_square: | 2C86E742-745E-4FDD-BFD8-B6A7AC638772 | 0x8000000000000000 |
|SBL1             | ro | Qualcomm Secondary Bootloader. LBAend=0x008BB7 when bootloader is locked | 0x008000 | 0x008BB6 | 0x0000176E00 | | :white_check_mark: | DEA0BA2C-CBDD-4805-B4F9-F428251C3E98 | 0x8000000000000000 |
|HACK             | | WPinternals Bootloader unlock | 0x008BB7 | 0x008BB7 | 0x0000000200 | | :white_large_square: | 8C6B52AD-8A9E-4398-AD09-AE916E53AE2D | 0x8000000000000000 |
|SBL2             | ro | Qualcomm Secondary Bootloader | 0x009000 | 0x009BB7 | 0x0000177000 | | :white_check_mark: | 74747474-7474-7474-7474-747474747474 | 0x8000000000000000 |
|SBL3             | ro | Qualcomm Secondary Bootloader | 0x00A000 | 0x00AFFF | 0x0000200000 | | :white_check_mark: | 05E044DF-92F1-4325-B69E-374A82E97D6E | 0x8000000000000000 |
|UEFI             | ro | Qualcomm Bootloader | 0x00B000 | 0x00C387 | 0x0000271000 | | :white_check_mark: | 400FFDCD-22E0-47E7-9A23-F16ED9382388 | 0x8000000000000000 |
|RPM              | ro | Qualcomm Bootloader. Resource & Power Management | 0x00D000 | 0x00D3E7 | 0x000007d000 | | :white_check_mark: | 098DF793-D712-413D-9D4E-89D711772228 | 0x8000000000000000 |
|TZ               | ro | Qualcomm Bootloader. ARM TrustZone | 0x00E000 | 0x00E3E7 | 0x000007d000 | | :white_check_mark: | A053AA7F-40B8-4B1C-BA08-2F68AC71A4F4 | 0x8000000000000000 |
|WINSECAPP        | ro | Qualcomm fTPM (Firmware Trusted Platform Module) Application | 0x00F000 | 0x00F3FF | 0x0000080000 | | :white_check_mark: | 69B4201F-A5AD-45EB-9F49-45B38CCDAEF5 | 0x8000000000000000 |
|BACKUP_SBL1      | ro | Qualcomm Bootloader Backup | 0x010000 | 0x010BB7 | 0x0000177000 | | :white_large_square: | A3381699-350C-465E-BD5D-FA3AB901A39A | 0x8000000000000000 |
|BACKUP_SBL2      | ro | Qualcomm Bootloader Backup | 0x011000 | 0x011BB7 | 0x0000177000 | | :white_large_square: | A3381699-350C-465E-BD5D-FA3AB901A39A | 0x8000000000000000 |
|BACKUP_SBL3      | ro | Qualcomm Bootloader Backup | 0x012000 | 0x012FFF | 0x0000200000 | | :white_large_square: | A3381699-350C-465E-BD5D-FA3AB901A39A | 0x8000000000000000 |
|BACKUP_UEFI      | ro | Qualcomm Bootloader Backup | 0x013000 | 0x014387 | 0x0000271000 | | :white_large_square: | A3381699-350C-465E-BD5D-FA3AB901A39A | 0x8000000000000000 |
|BACKUP_RPM       | ro | Qualcomm Bootloader Backup | 0x015000 | 0x0153E7 | 0x000007d000 | | :white_large_square: | A3381699-350C-465E-BD5D-FA3AB901A39A | 0x8000000000000000 |
|BACKUP_TZ        | ro | Qualcomm Bootloader Backup | 0x016000 | 0x0163E7 | 0x000007d000 | | :white_large_square: | A3381699-350C-465E-BD5D-FA3AB901A39A | 0x8000000000000000 |
|BACKUP_WINSECAPP | ro | Qualcomm fTPM Application Backup | 0x017000 | 0x0173FF | 0x0000080000 | | :white_large_square: | A3381699-350C-465E-BD5D-FA3AB901A39A | 0x8000000000000000 |
|BACKUP_BS_NV     | | | 0x018000 | 0x0181FF | 0x0000040000 | | :white_large_square: |
|UEFI_BS_NV       | ro | Qualcomm UEFI Variable Services Partition | 0x018200 | 0x0183FF | 0x0000040000 | | :white_large_square: | F0B4F48B-AEBA-4ECF-9142-5DC30CDC3E77 | 0x8000000000000000 |
|UEFI_NV          | ro | Qualcomm UEFI Variable Services Partition | 0x019000 | 0x0191FF | 0x0000040000 | | :white_large_square: | 74DA3EE7-D422-487C-A573-CE03C261362F | 0x8000000000000000 |
|PLAT             | ro | Qualcomm ACPI table storage | 0x01A000 | 0x01DFFF | 0x0000800000 | | :white_check_mark: | 543C031A-4CB6-4897-BFFE-4B485768A8AD | 0x8000000000000000 |
|EFIESP           | ro | Qualcomm EFI System Partition | 0x020000 | 0x03FFFF | 0x0004000000 | FAT | :white_check_mark: | EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 | 0x8000000000000000 |
|MODEM_FS1        | r/w | Qualcomm Modem live file system | 0x040000 | 0x0417FF | 0x0000300000 | | :white_large_square: | EBBEADAF-22C9-E33B-8F5D-0E81686A68CB | 0x8000000000000000 |
|MODEM_FS2        | r/w | Qualcomm Modem live file system | 0x042000 | 0x0437FF | 0x0000300000 | | :white_large_square: | 0A288B1F-22C9-E33B-8F5D-0E81686A68CB | 0x8000000000000000 |
|UEFI_RT_NV       | r/w | Qualcomm UEFI Variable Services Partition | 0x044000 | 0x0441FF | 0x000004000 | | :white_large_square: | 6BB94537-7D1C-44D0-9DFE-6D77C011DBFC | 0x8000000000000000 |
|UEFI_RT_NV_RPMB  | r/w | Qualcomm UEFI Variable Services Partition | 0x045000 | 0x0450FF | 0x0000020000 | | :white_large_square: | E35F99CF-0025-4252-A608-CAAA1289CAF4 | 0x8000000000000000 |
|MMOS             | r/w | Microsoft | 0x046000 | 0x06DF5F | 0x0004FEC000 | FAT | :white_check_mark: | EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 | 0x8000000000000000 |
|MainOS           | r/w | Microsoft | 0x070000 | 0x4C7EFF | 0x008AFE0000 | NTFS | :white_check_mark: | EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 | 0x0000000000000000 |
|Data             | r/w | Microsoft | 0x4C8000 | 0xE8FFDE | 0x0138FFBE00 | NTFS | :white_check_mark: | EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 | 0x0000000000000000 |



