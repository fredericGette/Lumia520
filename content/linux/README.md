# Install PostmarketOS

First, [install Android](/content/android/README.md) because usually PostmarketOS is installed over Android.  
For example: the installation of PostmarketOS requires the [Fastboot communication protocol](https://en.wikipedia.org/wiki/Fastboot) to flash the partitions.

> [!NOTE]
> To install PostmarketOS we also need Ubuntu on the host computer.

Install [pmbootstrap](https://wiki.postmarketos.org/wiki/Pmbootstrap#Installation):
```
$ cd $HOME
$ git clone --depth=1 https://gitlab.com/postmarketOS/pmbootstrap.git
$ mkdir -p ~/.local/bin
$ ln -s "$PWD/pmbootstrap/pmbootstrap.py" ~/.local/bin/pmbootstrap
$ source ~/.profile
```

Configure pmbootstrap (see the PostmarketOS wiki about [Lumia 520](https://wiki.postmarketos.org/wiki/Nokia_Lumia_520_(nokia-fame)) and [Lumia 720](https://wiki.postmarketos.org/wiki/Nokia_Lumia_720_(nokia-zeal))):
```
$ pmbootstrap init
	device: nokia-fame
	channel: edge
	user interface: console
```

Build the images which are going to be flashed in the device:
```
$ pmbootstrap build device-nokia-fame
$ pmbootstrap build linux-nokia-fame
```

Activate [debug shell](https://wiki.postmarketos.org/wiki/Inspecting_the_initramfs#Enable_the_debug_shell) because we will need it for the first boot:
```
$ pmbootstrap initfs hook_add debug-shell
```

Now, we are going to copy some files in a FAT32 micro SDcard in case of failure during first start of PostmarketOS.
```
$ pmbootstrap install
$ pmbootstrap export
$ cd  /tmp/postmarketOS-export
$ sudo partx -a -v nokia-fame.img
```
The file _nokia-fame.img_ is the image of a disk containing 2 partitions: `pmOS_boot` and `pmOS_root`.  
The command partx maps this image to a loop device (example `/dev/loop16`) and each partition on another device (example: `/dev/loop16p1` for `pmOS_boot` and `/dev/loop16p2` for `pmOS_root`).  
We mount the partition `pmOS_root` (change the name of the device loop if necessary):
```
$ sudo mkdir /mnt/pmOS_root
$ sudo mount -o ro /dev/loop16p2 /mnt/pmOS_root
```
Put the content of the partition pmOS_root into a tar file, and copy this file in the micro SDcard.
```
$ sudo tar -czvf rootfs.tar.gz -C /mnt/pmOS_root .
```
Copy the following binary in the micro SDcard also:  
`/mnt/pmOS_root/sbin/mkfs.ext4`

Power off the device, and insert the micro SDcard into it.  

Power on the device in fastboot mode (press volume-down during boot).  

Flash the partition (and reboot the device):
```
$ pmbootstrap flasher flash_rootfs
$ pmbootstrap flasher flash_kernel
$ pmbootstrap flasher boot
```
> [!NOTE]
> If the command `pmbootstrap flasher flash_rootfs` fails with an error `remote: 'Unknown chunk type'`,
> then you can still try to continue the installation process acting as when there is a problem with the root partition.

Wait for the message on the device display: `WARNING: debug-shell is active`.  
Then connect to the device and continue the [init](https://gitlab.com/postmarketOS/pmaports/-/blob/master/main/postmarketos-initramfs/init.sh) process step by step:
```
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
```
# dmesg
```
The last logs should be something like the following:  
```
	[  373.041049] JBD2: no valid journal superblock found
	[  373.041049] EXT4-fs (dm-1): error loading journal
```

We will fix the problem by formatting the root partition without journal and copying the content of the "root file system" into it.  
But before that we have to find the UUID of the `pmOS_root` partition:  
```
# blkid
```
In the result of the previous command, find a line with the text `/dev/mapper/userdata2: LABEL="pmOS_root"` and note the value of the UUID.  

Now we can format the root partition. Do no forget to pass the UUID to the command mkfs.ext4 with the parameter `-U`:  
```
# mkdir /sdcard
# mount /dev/mmcblk1p1 /sdcard
# /sdcard/mkfs.ext4 -O "^metadata_csum,^has_journal" -L pmOS_root -N 100000 -U 875eefec-ef9d-444b-9412-56cbc45ad709 /dev/mapper/userdata2
# mount -o rw /dev/mapper/userdata2  /sysroot
# tar x -zvf /sdcard/rootfs.tar.gz -C /sysroot
```






