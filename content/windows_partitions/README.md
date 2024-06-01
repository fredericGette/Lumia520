# eMMC partitions of Windows Phone 8.1

Number of eMMC sectors: 0xE90000

| Name            | Acces | Description | LBA start | LBA end | Size (bytes) | File system |
|-----------------|:-----:|-------------|-----------|---------|--------------|-------------|
|IS_UNLOCKED_SBL3 | | WPinternals | 0x000040 | 0x000040 | 0x0000000200 | |
|DPP              | ro | Device Provisioning Partition | 0x001000 | 0x004FFF | 0x0000800000 | FAT |
|MODEM_FSG        | ro | Qualcomm Modem golden file system | 0x005000 | 0x0067FF | 0x0000300000 | |
|SSD              | ro | Qualcomm Secure Software Download | 0x007000 | 0x00701F | 0x0000004000 | |
|SBL1             | ro | Qualcomm Secondary Bootloader | 0x008000 | 0x008BB6 | 0x0000176E00 | |
|HACK             | | WPinternals | 0x008BB7 | 0x008BB7 | 0x0000000200 | |
|SBL2             | ro | Qualcomm Secondary Bootloader | 0x009000 | 0x009BB7 | 0x0000177000 | |
|SBL3             | ro | Qualcomm Secondary Bootloader | 0x00A000 | 0x00AFFF | 0x0000200000 | |
|UEFI             | ro | Qualcomm Bootloader | 0x00B000 | 0x00C387 | 0x0000271000 | |
|RPM              | ro | Qualcomm Bootloader | 0x00D000 | 0x00D3E7 | 0x000007d000 | |
|TZ               | ro | Qualcomm Bootloader | 0x00E000 | 0x00E3E7 | 0x000007d000 | |
|WINSECAPP        | ro | Qualcomm fTPM Application | 0x00F000 | 0x00F3FF | 0x0000080000 | |
|BACKUP_SBL1      | ro | Qualcomm Bootloader Backup | 0x010000 | 0x010BB7 | 0x0000177000 | |
|BACKUP_SBL2      | ro | Qualcomm Bootloader Backup | 0x011000 | 0x011BB7 | 0x0000177000 | |
|BACKUP_SBL3      | ro | Qualcomm Bootloader Backup | 0x012000 | 0x012FFF | 0x0000200000 | |
|BACKUP_UEFI      | ro | Qualcomm Bootloader Backup | 0x013000 | 0x014387 | 0x0000271000 | |
|BACKUP_RPM       | ro | Qualcomm Bootloader Backup | 0x015000 | 0x0153E7 | 0x000007d000 | |
|BACKUP_TZ        | ro | Qualcomm Bootloader Backup | 0x016000 | 0x0163E7 | 0x000007d000 | |
|BACKUP_WINSECAPP | ro | Qualcomm fTPM Application Backup | 0x017000 | 0x0173FF | 0x0000080000 | |
|BACKUP_BS_NV     | | | 0x018000 | 0x0181FF | 0x0000040000 | |
|UEFI_BS_NV       | ro | Qualcomm UEFI Variable Services Partition | 0x018200 | 0x0183FF | 0x0000040000 |
|UEFI_NV          | ro | Qualcomm UEFI Variable Services Partition | 0x019000 | 0x0191FF | 0x0000040000 | |
|PLAT             | ro | Qualcomm ACPI table storage | 0x01A000 | 0x01DFFF | 0x0000800000 | |
|EFIESP           | ro | Qualcomm EFI System Partition | 0x020000 | 0x03FFFF | 0x0004000000 | FAT |
|MODEM_FS1        | r/w | Qualcomm Modem live file system | 0x040000 | 0x0417FF | 0x0000300000 | |
|MODEM_FS2        | r/w | Qualcomm Modem live file system | 0x042000 | 0x0437FF | 0x0000300000 | |
|UEFI_RT_NV       | r/w | Qualcomm UEFI Variable Services Partition | 0x044000 | 0x0441FF | 0x000004000 | |
|UEFI_RT_NV_RPMB  | r/w | Qualcomm UEFI Variable Services Partition | 0x045000 | 0x0450FF | 0x0000020000 | |
|MMOS             | r/w | Microsoft | 0x046000 | 0x06DF5F | 0x0004FEC000 | FAT |
|MainOS           | r/w | Microsoft | 0x070000 | 0x4C7EFF | 0x008AFE0000 | NTFS |
|Data             | r/w | Microsoft | 0x4C8000 | 0xE8FFDE | 0x0138FFBE00 | NTFS |



