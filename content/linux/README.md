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

