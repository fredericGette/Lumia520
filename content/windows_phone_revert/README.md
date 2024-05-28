# Revert to Windows Phone 8.1

from [Linux](/content/linux/README.md) or [Android](/content/android/README.md)

Use the .img file you created at the beginning of the installation of [Android](/content/android/README.md).

Create a folder "parts" and extract the partitions of the .img files using imgman64.exe or 7zip (faster than imgman64).

Example with imgman64.exe:  
```
imgman64.exe <your backup>.img parts
```

Reboot the phone in fastboot mode (keep volume-down pressed during reboot).  

Boot a special version of TWRP with "root adb" activated (not touch screen action required !):
```
fastboot boot recovery_unsecure.img
```

Send a file containing the Windows Phone partition table to the phone:
```
adb push fame_wp_unlocked.gpt /cache/
```

Open a root shell on the phone:
```
adb shell
```

Modify the partition table of the phone:
```
# sgdisk --load-backup /cache/fame_wp_unlocked.gpt /dev/block/mmcblk0
```

Force the update of the physical storage, then reboot the phone:
```
# sync
# sync
# reboot
```

You might have also to "power off" the phone, then "power on" to correctly take into account the new partition table.  
Reboot the phone in fastboot mode (keep volume-down pressed during reboot).   

Flash the partitions (extracted at the beginning of this document) in the order given by the following list of partition names:

1. TZ
2. SSD
3. RPM
4. WINSECAPP
5. MODEM_FSG
6. MODEM_FS1
7. MODEM_FS2
8. UEFI_BS_NV
9. UEFI_NV
10. UEFI_RT_NV
11. UEFI_RT_NV_RPMB
12. PLAT
13. MMOS
14. EFIESP
15. UEFI

```
fastboot flash <partition name> parts\<partition file>.img
```

