# Install LineageOS 14.1

First [unlock the bootloader](/content/unlock_bootloader/Readme.md)

## Make a full backup of the phone

> [!CAUTION]
> This backup is mandatory when you zwant to return to Windows Phone 8.1 - of if the installation of Android failed.

Switch the phone to mass storage mode:  
`thor2 -mode rnd -bootmsc`

Copy the content of the phone using Win32DiskImager.
Select the disk corresponding to "MainOS":  
![](backup0.jpg)
![](backup.jpg)

Power-off the device and disconnect the usb cable.  
`thor2 -mode rnd -power_off`
