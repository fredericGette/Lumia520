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

Reboot the device (volume-down + power >10s).  

Restart in fastboot mode (volume-down).  

Flash the partition (and reboot the device):
```
$ pmbootstrap flasher flash_rootfs
$ pmbootstrap flasher flash_kernel
$ pmbootstrap flasher boot
```

Wait for the message displayed on the device and indicating we are in debug shell.  
Then connect to the device and continue the init process step by step:
```
$ telnet 172.16.42.1
```



