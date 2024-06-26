# Install PostmarketOS

First, [install Android](/content/android/README.md) because usually PostmarketOS is installed over Android.  
For example: the installation of PostmarketOS requires the [Fastboot communication protocol](https://en.wikipedia.org/wiki/Fastboot) to flash the partitions.

> [!NOTE]
> To install PostmarketOS we also need Ubuntu on the host computer.

Install [pmbootstrap](https://wiki.postmarketos.org/wiki/Pmbootstrap#Installation):
```Shell
$ cd $HOME
$ git clone --depth=1 https://gitlab.com/postmarketOS/pmbootstrap.git
$ mkdir -p ~/.local/bin
$ ln -s "$PWD/pmbootstrap/pmbootstrap.py" ~/.local/bin/pmbootstrap
$ source ~/.profile
```

Configure pmbootstrap (see the PostmarketOS wiki about [Lumia 520](https://wiki.postmarketos.org/wiki/Nokia_Lumia_520_(nokia-fame)) and [Lumia 720](https://wiki.postmarketos.org/wiki/Nokia_Lumia_720_(nokia-zeal))):
```Shell
$ pmbootstrap init
	device: nokia-fame
	channel: edge
	user interface: console
```

> [!NOTE]
> Currently, I'm not able to use the xfce4 ui due to a fatal error `Segmentation fault at address 0x4` when the x11 server starts.
> Nor the fbkeyboard ui because the console framebuffer in not activated in the kernel.

Build the images which are going to be flashed in the phone:
```Shell
$ pmbootstrap build device-nokia-fame
$ pmbootstrap build linux-nokia-fame
```

Activate [debug-shell](https://wiki.postmarketos.org/wiki/Inspecting_the_initramfs#Enable_the_debug_shell) because we will need it for the first boot:
```Shell
$ pmbootstrap initfs hook_add debug-shell
```

Now, we are going to copy some files in a FAT32 micro SDcard in case of failure during first start of PostmarketOS.
```Shell
$ pmbootstrap install
$ pmbootstrap export
$ cd  /tmp/postmarketOS-export
$ sudo partx -a -v nokia-fame.img
```
The file _nokia-fame.img_ is the image of a disk containing 2 partitions: `pmOS_boot` and `pmOS_root`.  
The command partx maps this image to a loop device (example `/dev/loop16`) and each partition on another device (example: `/dev/loop16p1` for `pmOS_boot` and `/dev/loop16p2` for `pmOS_root`).  
We mount the partition `pmOS_root` (change the name of the device loop if necessary):
```Shell
$ sudo mkdir /mnt/pmOS_root
$ sudo mount -o ro /dev/loop16p2 /mnt/pmOS_root
```
Put the content of the partition pmOS_root into a tar file, and copy this file in the micro SDcard.
```Shell
$ sudo tar -czvf rootfs.tar.gz -C /mnt/pmOS_root .
```
Copy the following binary in the micro SDcard also:  
`/mnt/pmOS_root/sbin/mkfs.ext4`

Power off the phone, and insert the micro SDcard into it.  

Power on the phone in fastboot mode (press volume-down during boot).  

Flash the partition (and reboot the phone):
```Shell
$ pmbootstrap flasher flash_rootfs
$ pmbootstrap flasher flash_kernel
$ pmbootstrap flasher boot
```
> [!NOTE]
> If the command `pmbootstrap flasher flash_rootfs` fails with an error `remote: 'Unknown chunk type'`,
> then you can still continue the installation process because we will write the root filesystem again later.

Wait for the message on the phone display: `WARNING: debug-shell is active`.  
Then connect to the phone and continue the [init](https://gitlab.com/postmarketOS/pmaports/-/blob/master/main/postmarketos-initramfs/init.sh) process step by step:
```Shell
$ telnet 172.16.42.1
# . /usr/share/misc/source_deviceinfo
# . /init_functions.sh
# mount_boot_partition /boot
# extract_initramfs_extra /boot/initramfs-extra
# setup_udev
# run_hooks /hooks-extra
# wait_root_partition
# delete_old_install_partition
# resize_root_partition
# unlock_root_partition
# resize_root_filesystem
# mount_root_partition
```

The mount of the root partition may fail: `ERROR: unable to mount root partition!`  
Check the cause of the problem:  
```Shell
# dmesg
```
The last logs should be something like the following:  
```Shell
	[  373.041049] JBD2: no valid journal superblock found
	[  373.041049] EXT4-fs (dm-1): error loading journal
```

We will fix the problem by formatting the root partition without journal and copying the content of the "root file system" into it.  
But before that we have to find the UUID of the `pmOS_root` partition:  
```Shell
# blkid
```
In the result of the previous command, find a line with the text `/dev/mapper/userdata2: LABEL="pmOS_root"` and note the value of the UUID.  

Now we can format the root partition. Do no forget to use the correct UUID for the parameter `-U`:  
```Shell
# mkdir /sdcard
# mount /dev/mmcblk1p1 /sdcard
# /sdcard/mkfs.ext4 -O "^metadata_csum,^has_journal" -L pmOS_root -N 100000 -U 875eefec-ef9d-444b-9412-56cbc45ad709 /dev/mapper/userdata2
# mount -o rw /dev/mapper/userdata2  /sysroot
# tar x -zvf /sdcard/rootfs.tar.gz -C /sysroot
```

Before rebooting the phone, we are going to modify a startup script to avoid a potential freeze (or crash) during the boot:
```Shell
# vi /sysroot/etc/init.d/udev-trigger
```
Near the end of the file, modify the line which trigger the adding of all devices:  
At the end of the command `udevadm trigger --type=devices --action=add`  
add ` --attr-nomatch=address=* --attr-nomatch=flags=0x1003`  
because we don't want to trigger the adding of the device `/sys/devices/platform/msm_hsusb/gadget/net/usb0` which has an attribute `address` with an unknown value and an attribute `flags` with the value `0x1003`.

Terminate the telnet session:
```Shell
# exit
```

deactivate the [debug-shell](https://wiki.postmarketos.org/wiki/Inspecting_the_initramfs#Enable_the_debug_shell):  
```
$ pmbootstrap initfs hook_del debug-shell
```

And force a reboot of the phone by pressing volume-down + power more than 10 secondes. After the reboot keep the volume-down pressed to boot in fastboot mode.  

Flash the initramfs without the debug-shell, then reboot:
```Shell
$ pmbootstrap flasher flash_kernel
$ pmbootstrap flasher boot
```

After 2 minutes, the startup logo stops moving.  
At this moment you can open a ssh session to the phone.  
```Shell
$ ssh user@172.16.42.1
```

Note the difference of color between the capture and the real display. I guess there's a problem with the color mode ([24bits instead of 32bits](https://wiki.postmarketos.org/wiki/Troubleshooting:Xorg#X11_segfault)).  
![](framebuffer.jpg) ![](capture.jpg)
![](ssh.jpg)

> [!NOTE]
> Not only the first boot is long. The following ones will last the same time.  
> There is no working graphical ui currently.  
> But we can still display image in the framebuffer. See example below.

Display an animation:  
```Shell
$ sudo pbsplash -v -b "test framebuffer" -m "LUMIA 520" -s /usr/share/pbsplash/pmos-logo.svg
```

Listen to events (event0 is the touchscreen):  
```Shell
$ evtest
```

Enable Internet access using USB (to install new packages on the phone for example):  
See https://wiki.postmarketos.org/wiki/USB_Internet  
On the host computer (Ubuntu):  
```Shell
$ sudo su
# sysctl net.ipv4.ip_forward=1
# iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# iptables -A FORWARD -s 172.16.42.0/24 -j ACCEPT
# iptables -A POSTROUTING -t nat -j MASQUERADE -s 172.16.42.0/24
# iptables-save
# exit
```
On the phone:  
```Shell
$ sudo su
# ip route add default via 172.16.42.2 dev usb0
# echo nameserver 1.1.1.1 > /etc/resolv.conf
# exit
```

Capture screen:  
```Shell
$ sudo apk add fbgrab
$ fbgrab -v /home/user/capture.png
```




