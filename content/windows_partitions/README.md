# eMMC partitions of Windows Phone 8.1

| Name            | Acces | Description | LBA start | LBA end | Size (bytes) | File system |
|-----------------|:-----:|-------------|-----------|---------|--------------|-------------|
|IS_UNLOCKED_SBL3 | | WPinternals | 0x000040 | 0x000040 | 0x0000000200 | |
|DPP              | ro | Device Provisioning Partition | 0x001000 | 0x004FFF | 0x0000800000 | |
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
|BACKUP_SBL1      | ro | Qualcomm Bootloader Backup | 65536 | 68535 | 0x0000177000 | |
|BACKUP_SBL2      | ro | Qualcomm Bootloader Backup | 69632 | 72631 | 0x0000177000 | |
|BACKUP_SBL3      | ro | Qualcomm Bootloader Backup | 73728 | 77823 | 0x0000200000 | |
|BACKUP_UEFI      | ro | Qualcomm Bootloader Backup | 77824 | 82823 | 0x0000271000 | |
|BACKUP_RPM       | ro | Qualcomm Bootloader Backup | 86016 | 87015 | 0x000007d000 | |
|BACKUP_TZ        | ro | Qualcomm Bootloader Backup | 90112 | 91111 | 0x000007d000 | |
|BACKUP_WINSECAPP | ro | Qualcomm fTPM Application Backup | 94208 | 95231 | 0x0000080000 ||
|BACKUP_BS_NV     | | | 98304 | 98815 | 0x0000040000 | |
|UEFI_BS_NV       | ro | Qualcomm UEFI Variable Services Partition | 102400 | 102911 | 
|UEFI_NV          | ro | Qualcomm UEFI Variable Services Partition | 0x0000040000 | |
|PLAT             | ro | Qualcomm ACPI table storage | 106496 | 122879 | 0x0000800000 | |
|EFIESP           | ro | Qualcomm EFI System Partition | 131072 | 262143 | 0x0004000000 | |
|MODEM_FS1        | r/w | Qualcomm Modem live file system | 262144 | 268287 | 0x0000300000 | |
|MODEM_FS2        | r/w | Qualcomm Modem live file system | 270336 | 276479 | 0x0000300000 | |
|UEFI_RT_NV       | r/w | Qualcomm UEFI Variable Services Partition | 278528 | 279039 | 0x000004000 | |
|UEFI_RT_NV_RPMB  | r/w | Qualcomm UEFI Variable Services Partition | 282624 | 282879 | 0x0000020000 | |
|MMOS             | r/w | Microsoft | 286720 | 450399 | 0x0004FEC000 | |
|MainOS           | r/w | Microsoft | 458752 | 5013247 | 0x008AFE0000 | |
|Data             | r/w | Microsoft | 5013504 | 0xE8FFDE | 0x0138FFBE00 | |



