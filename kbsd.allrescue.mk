# BSD 3-Clause License
# 
# Copyright (c) 2022, Phoenix Advice, Keve Müller
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# This file is part of kBSD - https://github.com/kevemueller/kBSD

##########
###
# list of all target files provided by /rescue/rescue
#
ALL_RESCUE+=	/bin/[
ALL_RESCUE+=	/bin/cat
ALL_RESCUE+=	/bin/chflags
ALL_RESCUE+=	/bin/chio
ALL_RESCUE+=	/bin/chmod
ALL_RESCUE+=	/bin/cp
ALL_RESCUE+=	/bin/csh
ALL_RESCUE+=	/bin/date
ALL_RESCUE+=	/bin/dd
ALL_RESCUE+=	/bin/df
ALL_RESCUE+=	/bin/echo
ALL_RESCUE+=	/bin/ed
ALL_RESCUE+=	/bin/expr
ALL_RESCUE+=	/bin/getfacl
ALL_RESCUE+=	/bin/hostname
ALL_RESCUE+=	/bin/kenv
ALL_RESCUE+=	/bin/kill
ALL_RESCUE+=	/bin/link
ALL_RESCUE+=	/bin/ln
ALL_RESCUE+=	/bin/ls
ALL_RESCUE+=	/bin/mkdir
ALL_RESCUE+=	/bin/mv
ALL_RESCUE+=	/bin/pgrep
ALL_RESCUE+=	/bin/pkill
ALL_RESCUE+=	/bin/ps
ALL_RESCUE+=	/bin/pwd
ALL_RESCUE+=	/bin/realpath
ALL_RESCUE+=	/bin/red
ALL_RESCUE+=	/bin/rm
ALL_RESCUE+=	/bin/rmdir
ALL_RESCUE+=	/bin/setfacl
ALL_RESCUE+=	/bin/sh
ALL_RESCUE+=	/bin/sleep
ALL_RESCUE+=	/bin/stty
ALL_RESCUE+=	/bin/sync
ALL_RESCUE+=	/bin/tcsh
ALL_RESCUE+=	/bin/test
ALL_RESCUE+=	/bin/unlink
ALL_RESCUE+=	/sbin/bectl
ALL_RESCUE+=	/sbin/bsdlabel
ALL_RESCUE+=	/sbin/camcontrol
ALL_RESCUE+=	/sbin/ccdconfig
ALL_RESCUE+=	/sbin/clri
ALL_RESCUE+=	/sbin/devfs
ALL_RESCUE+=	/sbin/dhclient-script
ALL_RESCUE+=	/sbin/dhclient
ALL_RESCUE+=	/sbin/disklabel
ALL_RESCUE+=	/sbin/dmesg
ALL_RESCUE+=	/sbin/dump
ALL_RESCUE+=	/sbin/dumpfs
ALL_RESCUE+=	/sbin/dumpon
ALL_RESCUE+=	/sbin/fastboot
ALL_RESCUE+=	/sbin/fasthalt
ALL_RESCUE+=	/sbin/fdisk
ALL_RESCUE+=	/sbin/fsck_4.2bsd
ALL_RESCUE+=	/sbin/fsck_ffs
ALL_RESCUE+=	/sbin/fsck_msdosfs
ALL_RESCUE+=	/sbin/fsck_ufs
ALL_RESCUE+=	/sbin/fsck
ALL_RESCUE+=	/sbin/fsdb
ALL_RESCUE+=	/sbin/fsirand
ALL_RESCUE+=	/sbin/gbde
ALL_RESCUE+=	/sbin/geom
ALL_RESCUE+=	/sbin/glabel
ALL_RESCUE+=	/sbin/gpart
ALL_RESCUE+=	/sbin/halt
ALL_RESCUE+=	/sbin/ifconfig
ALL_RESCUE+=	/sbin/init
ALL_RESCUE+=	/sbin/ipf
ALL_RESCUE+=	/sbin/kldconfig
ALL_RESCUE+=	/sbin/kldload
ALL_RESCUE+=	/sbin/kldstat
ALL_RESCUE+=	/sbin/kldunload
ALL_RESCUE+=	/sbin/ldconfig
ALL_RESCUE+=	/sbin/md5
ALL_RESCUE+=	/sbin/mdconfig
ALL_RESCUE+=	/sbin/mdmfs
ALL_RESCUE+=	/sbin/mknod
ALL_RESCUE+=	/sbin/mount_cd9660
ALL_RESCUE+=	/sbin/mount_msdosfs
ALL_RESCUE+=	/sbin/mount_nfs
ALL_RESCUE+=	/sbin/mount_nullfs
ALL_RESCUE+=	/sbin/mount_udf
ALL_RESCUE+=	/sbin/mount_unionfs
ALL_RESCUE+=	/sbin/mount
ALL_RESCUE+=	/sbin/newfs_msdos
ALL_RESCUE+=	/sbin/newfs
ALL_RESCUE+=	/sbin/nextboot
ALL_RESCUE+=	/sbin/nos-tun
ALL_RESCUE+=	/sbin/ping
ALL_RESCUE+=	/sbin/ping6
ALL_RESCUE+=	/sbin/poweroff
ALL_RESCUE+=	/sbin/rcorder
ALL_RESCUE+=	/sbin/rdump
ALL_RESCUE+=	/sbin/reboot
ALL_RESCUE+=	/sbin/restore
ALL_RESCUE+=	/sbin/route
ALL_RESCUE+=	/sbin/routed
ALL_RESCUE+=	/sbin/rrestore
ALL_RESCUE+=	/sbin/rtquery
ALL_RESCUE+=	/sbin/rtsol
ALL_RESCUE+=	/sbin/savecore
ALL_RESCUE+=	/sbin/shutdown
ALL_RESCUE+=	/sbin/spppcontrol
ALL_RESCUE+=	/sbin/swapon
ALL_RESCUE+=	/sbin/sysctl
ALL_RESCUE+=	/sbin/tunefs
ALL_RESCUE+=	/sbin/umount
ALL_RESCUE+=	/sbin/zfs
ALL_RESCUE+=	/sbin/zpool
ALL_RESCUE+=	/usr/bin/bunzip2
ALL_RESCUE+=	/usr/bin/bzcat
ALL_RESCUE+=	/usr/bin/bzip2
ALL_RESCUE+=	/usr/bin/chgrp
ALL_RESCUE+=	/usr/bin/ex
ALL_RESCUE+=	/usr/bin/groups
ALL_RESCUE+=	/usr/bin/gunzip
ALL_RESCUE+=	/usr/bin/gzcat
ALL_RESCUE+=	/usr/bin/gzip
ALL_RESCUE+=	/usr/bin/head
ALL_RESCUE+=	/usr/bin/id
ALL_RESCUE+=	/usr/bin/iscsictl
ALL_RESCUE+=	/usr/bin/less
ALL_RESCUE+=	/usr/bin/lzcat
ALL_RESCUE+=	/usr/bin/lzma
ALL_RESCUE+=	/usr/bin/more
ALL_RESCUE+=	/usr/bin/mt
ALL_RESCUE+=	/usr/bin/nc
ALL_RESCUE+=	/usr/bin/sed
ALL_RESCUE+=	/usr/bin/tail
ALL_RESCUE+=	/usr/bin/tar
ALL_RESCUE+=	/usr/bin/tee
ALL_RESCUE+=	/usr/bin/unlzma
ALL_RESCUE+=	/usr/bin/unxz
.if ${KBSD_VERSION_MAJOR} > 12
ALL_RESCUE+=	/usr/bin/unzstd
.endif
ALL_RESCUE+=	/usr/bin/vi
ALL_RESCUE+=	/usr/bin/whoami
ALL_RESCUE+=	/usr/bin/xz
ALL_RESCUE+=	/usr/bin/xzcat
ALL_RESCUE+=	/usr/bin/zcat
.if ${KBSD_VERSION_MAJOR} > 12
ALL_RESCUE+=	/usr/bin/zstd
ALL_RESCUE+=	/usr/bin/zstdcat
ALL_RESCUE+=	/usr/bin/zstdmt
.endif
ALL_RESCUE+=	/usr/sbin/chown
ALL_RESCUE+=	/usr/sbin/chroot
ALL_RESCUE+=	/usr/sbin/iscsid
ALL_RESCUE+=	/usr/sbin/zdb
