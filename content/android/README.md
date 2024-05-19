# Install LineageOS 14.1

First [unlock the bootloader](/content/unlock_bootloader/Readme.md)

## Make a full backup of the phone

> [!CAUTION]
> This backup is mandatory when you want to return to Windows Phone 8.1 - of if the installation of Android failed.

Switch the device to mass storage mode:  
`thor2 -mode rnd -bootmsc`

Copy the content of the device using Win32DiskImager.  
Select the disk corresponding to "MainOS":  
![](backup0.jpg)
![](backup.jpg)

When the copy is finished: exit mass storage mode.  
`thor2 -mode rnd -reboot`

Send the following command and disconnect the usb cable when the device seems to be locked on the Nokia logo (the device will power-off automatically upon disconnection).  
`thor2 -mode rnd -power_off`

## Install TWRP

Prepare thor2 to put the device "in wait for command" (messaging timeout is disabled):  
`thor2 -mode rnd -asciimsgreq NOKD -asciimsgresp NOKD -skip_com_scan`

Immediatly connect the usb cable (the phone will power-on automatically upon connection).  

Flash the .mbn (multi boot binary) file of TWRP in the UEFI partition.  
`thor2 -mode uefiflash -partitionname UEFI -partitionimagefile "C:\Users\Public\Downloads\LK Bootloader installer\64 bit installers\lflash_windows_x86_x64\DATA\EMMCBOOT.mbn"`

Reboot the device.  
`thor2 -mode rnd -reboot`

After reboot, the device should be in "fastboot" mode:  
![](fastboot.JPG)
