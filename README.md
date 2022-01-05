# kBSD
Build system for very small FreeBSD images.
This build system enables you to create small bootable FreeBSD media, that are customized to your needs.

Motivation to create it was the inherent flaw of FreeBSD to boot with memory disks above a certain (small) size on the EFI platform. This rendered the excellent [mfsBSD](https://mfsbsd.vx.sk) tool unfixable for EFI.

## Features
* geom_uzip to maintain a small loadable size
* can chainload larger images seamlessly (reboot -r) on EFI to work around the loader.efi limitation
* supports setting up a writable filesystem as part of preinit, and hence can boot an unmodified FreeBSD tree
* Creates arbitrarily small images that still work by only specifying the names of the binaries / packages that shall be embedded, library dependencies are managed automatically
* fully customizable from the make CLI
* will only re-do what is needed to be done, to facilitate fast turnaround in hacking mode


## Usage
Clone the repository on a FreeBSD system, examine the Makefile, decide on the target to be built and let kBSD do the rest.

### Example usage
* `make prepare; make KBSD2_ADD_PAYLOAD=KBSD2_PLINSTALL kbsd2-memiso`
  * creates a 38MiB ISO that can be sanbooted or plain booted with all files necessary to run bsdinstall
* `make prepare; make -DNODEPEND KBSD2_ADD_PAYLOAD=KBSD2_PLSLIMKB kbsd1-memiso`
  * creates a 101MiB ISO with a slim full FreeBSD base+kernel (no development tools, manuals), that can be sanbooted with Legacy BIOS and plain booted with EFI BIOS
* `make prepare; make -DNODEPEND KBSD2_ADD_PAYLOAD=KBSD2_PLSLIMKB kbsd1-memtftp`
  * creates a 101MiB ISO with a slim full FreeBSD base+kernel (no development tools, manuals), that can be iPXE booted on EFI
  
### For developers:
* `make prepare; make KBSD2_ADD_PAYLOAD=KBSD2_PLINSTALL KBSD2_ADD_PKG=dropbear kbsd2-nfs`
  * create an NFS rootdir with the installer and additional packages embedded

see source for advanced usage

## Problem description
FreeBSD relies on its own loader (coming in different flavours) to be loaded into memory and started. No other advanced loaders support booting FreeBSD.
In a modern dynamic server environment, one is used to be able to choose and configure kernels/modules using the loader, rely on fast protocols (e.g. http) for the transfer of arbitrarily sized kernels/initial ramdisks.

More specifically the FreeBSD kernel and the ramdisk shall be bootable without the need of tweaking DHCP servers or adding NFS mounts. Files shall be transferred over the network using HTTP or TFTP as a fallback. The primary loader shall be iPXE, the secondary loader an emulated CD environment (e.g. BMC or virtualization)

### Loaders
#### iPXE 
iPXE used to boot previous FreeBSD/i386, but since FreeBSD dropped MultiBoot support, this is no longer a solution. 
#### Grub2
Grub2 used to be able to boot FreeBSD kernel in a sophisticated way, but it does not work with recent versions of FreeBSD.
#### pxeboot(8)
The pxeboot must be provided a root-path/next-server by DHCP, it does not support a more dynamic decision on what to boot and always requires the DHCP server as well as an NFS server. It only support root on NFS
#### loader(8)
loader expects to be executed by the disk based FreeBSD bootcode, expects a readable filesystem environment, cannot be started from iPXE, cannot take command line arguments (except for when started by the bootcode).
#### loader.efi(8)
loader.efi is a quite versatile loader, which can be run from the EFI prompt as well as from iPXE directly, it accepts command line arguments. It requires a filesystem, but can work with TFTP.
Biggest flaw is that the combined unzipped size of the kernel + initial ramdisk must fit into 64MiB. With the GENERIC kernel being 28MiB already, this leaves ~36MiB for the ramdisk. Note that a gzipped initial ramdisk (in widespread use) will be unpacked during load, and needs to fit unpacked.

## Problem solution
To support the versatile loading of arbitrarily sized memory disks on the EFI BIOS environments, an intermediate bootstrapping code needs to be implemented that performs the loading of the (too) large memory disk when the kernel is already running and can handle the size.

## Implementation
We need to distinguish between two categories when loading. 
1. The boot media is available after the kernel started.
   
    This is the case when
      * we boot from an (emulated) CDROM
      * we boot from TFTP or NFS
2. The boot media is not available after the kernel started.
    
    This is the case, when
      * we boot from a sanbooted ISO

We also need to distinguish between two sizes when loading. 
1. The kernel and the memory disk fit into 64MiB.
    
    We can boot the memory disk directly on both the EFI and the Legacy BIOS platform.
2. They don't.
   
    We can boot the memory disk directly on the Legacy BIOS platform, but not on EFI.

Cases 1/1, 1/2 and 2/1 are supported by the memiso, memtftp, iso and nfs targets of the kBSD Makefile.

Case 2/2 is supported by the memiso target for Legacy BIOS and the memtftp/nfs targets in EFI mode.