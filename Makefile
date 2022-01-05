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
# Manage creation of small FreeBSD distribution packages
# example-use:
#		make prepare; make KBSD2_ADD_PAYLOAD=KBSD2_PLINSTALL kbsd2-memiso
#			creates a 38MiB ISO that can be sanbooted or plain booted with all files necessary to run bsdinstall
#		make prepare; make -DNODEPEND KBSD2_ADD_PAYLOAD=KBSD2_PLSLIMKB kbsd1-memiso
#			creates a 101MiB ISO with a slim full FreeBSD base+kernel (no development tools, manuals), that can be sanbooted with Legacy BIOS and plain booted with EFI BIOS
# for developers:
#		make prepare; make KBSD2_ADD_PAYLOAD=KBSD2_PLINSTALL KBSD2_ADD_PKG=dropbear kbsd2-nfs
#			create an NFS rootdir with the installer and additional packages embedded
# see source for advanced usage


# TOOLS
CAT?=		/bin/cat
CHFLAGS?=	/bin/chflags
LN?=		/bin/ln
MKDIR?=		/bin/mkdir -p
RM?=		/bin/rm
RMDIR?=		/bin/rmdir
TEST?=		/bin/test
FETCH?=		/usr/bin/fetch
FIND?=		/usr/bin/find
GZIP?=		/usr/bin/gzip
INSTALL?=	/usr/bin/install
MKTEMP?=	/usr/bin/mktemp
MKUZIP?=	/usr/bin/mkuzip
STAT?=		/usr/bin/stat
TAR?=		/usr/bin/tar
TOUCH?=		/usr/bin/touch
TRUNCATE?=	/usr/bin/truncate
MTREE?=		/usr/sbin/mtree
MAKEFS?=	/usr/sbin/makefs
PKG?=		/usr/sbin/pkg
PW?=		/usr/sbin/pw

# non-base TOOLS
RSYNC?=		/usr/local/bin/rsync
ZFS?=		/usr/local/sbin/zfs
ZPOOL?=		/usr/local/sbin/zpool

###
# FreeBSD make system is very sophisticated, but we don't use it, unfortunately excluding it here with MAKEFLAGS is not working.
# We would like to keep track of directory changes for now (-w)
#
#.MAKEFLAGS:	-w
#.MAKEFLAGS:	-r 


DOWNLOAD_BASE_URL?=	https://download.freebsd.org/ftp/releases

.include "kbsd.images.mk"

# if you have the TXZ, make -DTXZ_DIR=/my/dist
# if you have them unpacked, make -DTEMPLATE=/my/distfiles
# if you want another arch/version than amd64, use -DKBSD_MACHINE= -DKBSD_MACHINE_ARCH= -DKBSD_MACHINE_VERSION= -DKBSD_TYPE

# internal variables, immediately evaluated
ALL_TXZ:=	kernel base src ports doc lib32 tests base-dbg kernel-dbg lib32-dbg
MMAP_x86-64:=	amd64
MMAP_80386:=	i386

MAP_DEFAULT_ARCH_amd64:=	amd64
MAP_DEFAULT_ARCH_arm:=		armv7
MAP_DEFAULT_ARCH_arm64:=	aarch64
MAP_DEFAULT_ARCH_i386:=		i386
MAP_DEFAULT_ARCH_powerpc:=	powerpc64
MAP_DEFAULT_ARCH_riscv:=	riscv64
MAP_DEFAULT_ARCH_sparc64:=	sparc64

# internal variables, lazily evaluated
KBSD_BASE=			kbsd-${KBSD_VERSION}-${KBSD_MACHINE}-${KBSD_MACHINE_ARCH}
DOWNLOAD_URL=		${DOWNLOAD_BASE_URL}/${KBSD_MACHINE}/${KBSD_MACHINE_ARCH}/${KBSD_VERSION}-${KBSD_TYPE}

KBSD_MACHINE?=		amd64									# machine type
KBSD_MACHINE_ARCH=	${MAP_DEFAULT_ARCH_${KBSD_MACHINE}}		# machine target architecture
KBSD_VERSION?=		13.0
KBSD_TYPE=			RELEASE
KBSD_VERSION_MAJOR=	${KBSD_VERSION:R}
KBSD_VERSION_MINOR=	${KBSD_VERSION:E}

LOADER_MODULES?=	geom_uzip

# FIXME: extend to other machine types and set proper machine architecture
TEMPLATE_MACHINE_VERSION=	${TEMPLATE_TRIPLE:C/.* executable, (Intel )?([^,]+).* for FreeBSD ([0-9.]+).*/\2 \3/W}

#####
### TXZ handling (detect architecture, download, clean-up)
###

.if defined(TXZ_DIR) && exists(${TXZ_DIR}/base.txz)
###
# we have been given a set of TXZ in TXZ_DIR, derive the MACHINE, VERSION information from its content and ensure we do not accidentally delete files there
#
TEMPLATE_TRIPLE!=		tar -xqzOf ${TXZ_DIR}/base.txz ./bin/sh | file - 
KBSD_MACHINE:=			${MMAP_${TEMPLATE_MACHINE_VERSION:[1]}}
KBSD_VERSION:=			${TEMPLATE_MACHINE_VERSION:[2]}

.for txz in ${ALL_TXZ}
clean-txz-${txz}: .PHONY
	@echo Not touching ${.TARGET} in externally provided distribution directory ${TXZ_DIR}
.endfor
clean-txz: .PHONY
	@echo Not touching externally provided distribution directory ${TXZ_DIR}

.else # defined(TXZ_DIR) && exists(${TXZ_DIR}/base.txz)
###
# we manage our TXZ ourselves, so we define cleanup code
#
TXZ_DIR=	txz
ALL_DIRS+=	TXZ_DIR
.if exists(${KBSD_BASE})
.for txz in ${ALL_TXZ}
clean-txz-${txz}: .PHONY
	${RM} -f ${TXZ_DIR}/${txz}.txz
clean-txz: .PHONY clean-txz-${txz}
.endfor
clean-txz: .PHONY
	-${RMDIR} ${TXZ_DIR}
.endif
.endif #defined(TXZ_DIR) && exists(${TXZ_DIR}/base.txz)

#####
### TEMPLATE_DIR handling (detect architecture, clean-up)
###

.if defined(TEMPLATE_DIR) && exists(${TEMPLATE_DIR}/bin/sh)
###
# we have been given a TEMPLATE_DIR derive the MACHINE, VERSION information from its content and flag the extraction as done
#
TEMPLATE_TRIPLE!=		file ${TEMPLATE_DIR}/bin/sh
KBSD_MACHINE:=			${MMAP_${TEMPLATE_MACHINE_VERSION:[1]}}
KBSD_VERSION:=			${TEMPLATE_MACHINE_VERSION:[2]}

CHECK_kernel:=			/boot/kernel/kernel
CHECK_base:=			/bin/sh
CHECK_base-dbg:=		/usr/lib/debug/bin/sh.debug
CHECK_doc:=				/usr/share/doc/psd/contents.ascii.gz	# removed starting with version 12.0
CHECK_kernel-dbg:=		/usr/lib/debug/boot/kernel/kernel.debug
CHECK_lib32-dbg:=		/usr/lib/debug/libexec/ld-elf32.so.1.debug
CHECK_lib32:=			/libexec/ld-elf32.so.1
CHECK_ports:=			/usr/ports/CHANGES
CHECK_src:=				/usr/src/Makefile
CHECK_test:=			/usr/test/README

.for txz in ${ALL_TXZ}
.if exists(${TEMPLATE_DIR}${CHECK_txz})
.template_${txz}.done: ${WRK_BASE}
	@echo ${txz} was provided extracted in ${TEMPLATE_DIR} - NOP
	${TOUCH} ${.TARGET}
.endif # exists(${TEMPLATE_DIR}${CHECK_txz})
.endfor

clean-template: .PHONY
	@echo Not touching externally provided TEMPLATE_DIR and its extraction state

.else # defined(TEMPLATE_DIR) && exists(${TEMPLATE_DIR}/bin/sh)
###
# we have not been given TEMPLATE_DIR, define our own and set-up ways to populate and clean it
#
TEMPLATE_DIR:=	template
ALL_DIRS:=		TEMPLATE_DIR

.if exists(${KBSD_BASE})
.for txz in ${ALL_TXZ}
.template_${txz}.done: ${TEMPLATE_DIR} ${TXZ_DIR}/${txz}.txz
	@echo extracting ${.ALLSRC:[-1]} to ${TEMPLATE_DIR}
	${TAR} -C ${TEMPLATE_DIR} -xzf ${.ALLSRC:[-1]}
	${TOUCH} ${.TARGET}
.endfor

clean-template: .PHONY
	@echo in ${:!pwd!} ${.CURDIR}
	-${CHFLAGS} -R noschg ${TEMPLATE_DIR}
	${RM} -rf ${TEMPLATE_DIR}
	${RM} -f ${ALL_TXZ:@x@.template_${x}.done@}

clean: clean-template

.endif # exists(${KBSD_BASE})

.endif # defined(TEMPLATE_DIR) && exists(${TEMPLATE_DIR}/bin/sh)


###
#####

.if exists(${KBSD_BASE})
prepare: .PHONY
	@echo Setting up ${KBSD_BASE} for FreeBSD ${KBSD_VERSION} on ${KBSD_MACHINE}/${KBSD_MACHINE_ARCH}

clean: .PHONY
	-${RMDIR} ${.OBJDIR}
	@echo cleaned up ${KBSD_BASE} for FreeBSD ${KBSD_VERSION} on ${KBSD_MACHINE}/${KBSD_MACHINE_ARCH}

help: .PHONY
	@echo KBSD builder II
	@echo
	@echo Collection targets
	@${ALL_COLLECTION:O:@v@echo ${v} - ${${v}_DESC:Q};@}
	@echo Payloads
	@${ALL_PAYLOAD:O:@v@echo ${v} - ${${v}_DESC:Q};@}
	@echo Targets
	@${.ALLTARGETS:O:@v@echo ${v:Q};@}


.else
prepare: .PHONY
	@echo Setting up ${KBSD_BASE} for FreeBSD ${KBSD_VERSION} on ${KBSD_MACHINE}/${KBSD_MACHINE_ARCH}
	${MKDIR} ${KBSD_BASE}
clean: .PHONY
	@echo cleaned up ${KBSD_BASE} for FreeBSD ${KBSD_VERSION} on ${KBSD_MACHINE}/${KBSD_MACHINE_ARCH}

help: .PHONY
	@echo KBSD builder
	@echo 
	@echo "1. Getting started"
	@echo 
	@echo "    make prepare"
	@echo "       defaults to KBSD_VERSION?=${KBSD_VERSION} on KBSD_MACHINE?=${KBSD_MACHINE}/KBSD_MACHINE_ARCH?=${KBSD_MACHINE_ARCH}"
	@echo "       downloads distribution TXZ from DOWNLOAD_BASE_URL?=${DOWNLOAD_BASE_URL}"
	@echo "       clean target cleans up everything"
	@echo "    make TXZ_DIR=<dir> prepare"
	@echo "       obtains KBSD_VERSION, KBSD_MACHINE from content of existing distribution TXZ. (slow, needs to quick unpack base.txz)"
	@echo "       may download additional distribution TXZ from DOWNLOAD_BASE_URL?=${DOWNLOAD_BASE_URL}"
	@echo "       will not remove any distribution txz, but clean target cleans up everything else"
	@echo "    make TEMPLATE_DIR=<dir> prepare"
	@echo "       obtains KBSD_VERSION, KBSD_MACHINE from content of existing distribution template files in TEMPLATE_DIR. (fast)"
	@echo "       downloads additional distribution TXZ from DOWNLOAD_BASE_URL=${DOWNLOAD_BASE_URL}"
	@echo "       will not remove template directory, but clean target cleans up everything else"
.endif

.MAIN: help



#TODO: consider using two layered approach instead
# make prepare -> create subdirectory, write configuration and create link to real Makefile in this directory.
# this allows make to be run without detection code, etc. in the subdirectory directly repeatedly without specifying a lot of command line arguments
# .OBJDIR would be gone and things a lot clearer

.if exists(${KBSD_BASE})

.OBJDIR: ${KBSD_BASE}

.for txz in ${ALL_TXZ}
template-${txz}: .PHONY .template_${txz}.done
.endfor

distclean: .PHONY clean-txz clean

###
# common rule to obtain TXZ via fetch
#

.for txz in ${ALL_TXZ}
${TXZ_DIR}/${txz}.txz:
	@echo downloading from ${DOWNLOAD_BASE_URL} for ${MACHINE} ${MACHINE_ARCH} ${VERSION} ${TYPE}
	@echo ${DOWNLOAD_URL}
	${MKDIR} ${TXZ_DIR}
	${FETCH} -o ${.TARGET} ${DOWNLOAD_URL}/${.TARGET:T}

fetch-${txz}: .PHONY ${TXZ_DIR}/${txz}.txz

.endfor

###
#####


#####
### payload definitions

KBSD_LOADER_CONF+=	autoboot_delay="3"
KBSD_LOADER_CONF+=	hostuuid_load="NO"
KBSD_LOADER_CONF+=	entropy_cache_load="NO"
KBSD_LOADER_CONF+=	kern.panic_reboot_wait_time="-1"

#
###

###
# directory tree for the CD loader
#
ALL_PAYLOAD+=		CD
CD_DESC:=			Copy FreeBSD loader for CD booting with legacy BIOS.
CD_DEPEND:=			.template_base.done
CD_OUT:=			cdloader/
CD_TOOLS+=			/boot/cdboot
CD_TOOLS+=			/boot/loader  # FIXME this is loader.lua by accident. make sure to use the right source and rename to target name
ALL_DIRS+=			CD_OUT
#
###



###
# directory tree for the EFI service partition containing the loader
#
EFIBOOTNAME_amd64:=	bootx64.efi
EFIBOOTNAME_i386:=	bootia32.efi
EFIBOOTNAME:=		${EFIBOOTNAME_${KBSD_MACHINE}}

ALL_PAYLOAD+=		EFI
EFI_OUT:=			efi/
EFIBOOT_DIR:=		${EFI_OUT}EFI/BOOT
ALL_DIRS+=			EFIBOOT_DIR
EFI_TARGET:=		${EFIBOOT_DIR}/${EFIBOOTNAME}

EFI_DEPEND:=		${EFI_TARGET} 
EFI_DESC:=			Copy FreeBSD loader for EFI architecture to proper place with proper name.

# TODO: use cp -a and make the target cp_EFIBOOT.done or pl_EFIBOOT.done
${EFI_TARGET}:		.template_base.done ${EFIBOOT_DIR} ${TEMPLATE_DIR}/boot/loader_lua.efi
	${CP} ${.ALLSRC:[-1]:Q} ${.TARGET:Q}

efi.fat: .EFI.done ${EFI_OUT} FAT2M

clean-efifat: .PHONY
	${RM} -f efi.fat

clean: clean-efifat



###
# directory tree for the loader components from FreeBSD
#
# include all modules from LOADER_MODULES

ALL_PAYLOAD+=		LOADERDIR

LOADER_DIR=			loader
ALL_DIRS+=			LOADER_DIR

LOADERDIR_DESC:=	Prepare loader directory.
LOADERDIR_OUT:=		${LOADER_DIR}/
LOADERDIR_DEPEND:=	.template_base.done .template_kernel.done ${TEMPLATE_DIR}/
LOADERDIR_LOADERLOCAL+=	${KBSD_LOADER_CONF}
LOADERDIR_LOADERLOCAL+=	${LOADER_MODULES:@x@${x}_load="YES"@:ts\n}
LOADERDIR_INCLUDE+=	/boot/
LOADERDIR_INCLUDE+=	/boot/device.hints
LOADERDIR_INCLUDE+=	/boot/defaults/
LOADERDIR_INCLUDE+=	/boot/defaults/**
LOADERDIR_INCLUDE+=	/boot/fonts/
LOADERDIR_INCLUDE+=	/boot/fonts/**
LOADERDIR_INCLUDE+=	/boot/images/
LOADERDIR_INCLUDE+=	/boot/images/**
LOADERDIR_INCLUDE+=	/boot/kernel/
LOADERDIR_INCLUDE+=	/boot/kernel/kernel
LOADERDIR_INCLUDE+=	/boot/kernel/linker.hints
LOADERDIR_INCLUDE+=	${LOADER_MODULES:@x@/boot/kernel/${x}.ko@}
LOADERDIR_INCLUDE+=	/boot/lua/
LOADERDIR_INCLUDE+=	/boot/lua/**
LOADERDIR_INCLUDE+=	/boot/modules/


ALL_PAYLOAD+=		LOADERDIRGZ
LOADERDIRGZ_DIR:=	loader-gz
ALL_DIRS+=			LOADERDIRGZ_DIR

LOADERDIRGZ_DESC:=			Prepare gzipped loader directory
LOADERDIRGZ_OUT:=			${LOADERDIRGZ_DIR}/
LOADERDIRGZ_DEPEND:=		.LOADERDIRGZ-gzip.done
LOADERDIRGZ_LOADERLOCAL+=	${LOADERDIR_LOADERLOCAL}

.LOADERDIRGZ-gzip.done: .LOADERDIR.done 
	#${RSYNC} -aH -f"+ */" --include="*.gz" --include="*.hints" --include="*.conf*" --exclude="**" ${LOADERDIR_OUT} ${LOADERDIRGZ_OUT}
	${RSYNC} -aH ${LOADERDIR_OUT} ${LOADERDIRGZ_OUT}
	${FIND} ${LOADERDIRGZ_OUT} -type f -not \( -name "*.gz" -or -name "*.hints" -or -name "*.conf*" \) -exec ${GZIP} -f9 '{}' \;
	${TOUCH} ${.TARGET}

clean-LOADERDIRGZ-extra: .PHONY
	${RM} -f .LOADERDIRGZ-gzip.done

clean-LOADERDIRGZ: clean-LOADERDIRGZ-extra

#
###


# TODO: simplify by setting _OUT to the skeleton directory, be beware of deleting it!
ALL_PAYLOAD+=			PLROOTSKEL
PLROOTSKEL_DESC:=		Copy root skeleton for kBSD
PLROOTSKEL_DEPEND:=		${.CURDIR}/kbsdroot.skel/
PLROOTSKEL_OUT:=		plrootskel-root/
PLROOTSKEL_INCLUDE:=	**


KBSD1_ROOT_DIR?=	kbsd1root
KBSD2_ROOT_DIR?=	kbsd2root

ALL_DIRS +=	KBSD1_ROOT_DIR KBSD2_ROOT_DIR

CP: .USE
	#@echo Copying ${.TARGET} because of ..${.OODATE}.. dependencies being younger
	${RSYNC} --update -aH --include=${.TARGET:C%[^/]+(.*)%\1%:H:H:H:Q}/ --include=${.TARGET:C%[^/]+(.*)%\1%:H:H:Q}/ --include=${.TARGET:C%[^/]+(.*)%\1%:H:Q}/ --include=${.TARGET:C%[^/]+(.*)%\1%:Q} --exclude='**' ${TEMPLATE_DIR}/ ${.TARGET:C%^([^/]+).*$%\1%:Q}/
	# sometimes the dependency is younger than the target, in order to avoid repeated re-make of the target, touch it with the reference of the youngest of all of the sources that triggered it, include itself in the list
	@${TOUCH} -r `${STAT} -f%m%t%N ${.TARGET} ${.OODATE} | sort -n | tail -1 | cut -f 2` ${.TARGET}



LNR2: .USE
	#${INSTALL} -l r -v ../rescue/${.TARGET:T:Q} ${.TARGET}
	@${MKDIR} ${.TARGET:H}
	@${TEST} -e ${.TARGET} -o -L ${.TARGET} || ${LN} -s ../rescue/${.TARGET:T:Q} ${.TARGET}
	#@${TOUCH} -r ${.TARGET} ${.TARGET:H}
LNR3: .USE
	@${MKDIR} ${.TARGET:H}
	@${TEST} -e ${.TARGET} -o -L ${.TARGET} || ${LN} -s ../../rescue/${.TARGET:T:Q} ${.TARGET}
	#@${TOUCH} -r ${.TARGET} ${.TARGET:H}

KBSD2_PLKERNEL_MODULES+=	zfs nullfs tmpfs

# classic rescue
MINI_TOOLS_DEPEND+=	.template_base.done

# TOOLS needed for rc.kBSD1
MINI_TOOLS+=		/etc/dhclient.conf
MINI_TOOLS+=		/etc/services
MINI_TOOLS+= 		/usr/bin/fetch
MINI_TOOLS+=		/usr/bin/stat
MINI_TOOLS+=		/usr/bin/tftp 

#MINI_TOOLS+=		/usr/bin/grep	# for convenience
#MINI_TOOLS+= 		/usr/bin/limits # for dropbear
#MINI_TOOLS+= 		/usr/bin/ldd	# for convenience
#MINI_TOOLS+= 		/usr/bin/logger	# rc.subr
#MINI_TOOLS+=		/usr/sbin/syslogd 



# norescue
NORRESCUE_TOOLS_DEPEND+=	.template_base.done
NORESCUE_TOOLS+=	${MINI_TOOLS}
NORESCUE_TOOLS+= 	/bin/date
NORESCUE_TOOLS+= 	/bin/df
NORESCUE_TOOLS+= 	/bin/hostname
NORESCUE_TOOLS+=	/bin/ln
NORESCUE_TOOLS+=	/bin/ls
NORESCUE_TOOLS+=	/bin/mkdir
NORESCUE_TOOLS+=	/bin/sh
NORESCUE_TOOLS+=	/sbin/dhclient
NORESCUE_TOOLS+=	/sbin/dhclient-script
NORESCUE_TOOLS+=	/sbin/dmesg
NORESCUE_TOOLS+=	/sbin/ifconfig
NORESCUE_TOOLS+=	/sbin/init
NORESCUE_TOOLS+=	/sbin/mdconfig
NORESCUE_TOOLS+=	/sbin/mount
NORESCUE_TOOLS+=	/sbin/reboot
NORESCUE_TOOLS+=	/sbin/sysctl
NORESCUE_TOOLS+=	/sbin/umount
NORESCUE_TOOLS+=	/usr/bin/grep
NORESCUE_TOOLS+=	/usr/bin/more
NORESCUE_TOOLS+=	/usr/bin/less


# generic tools
KBSD1_PLTOOLS_DEPEND+=	.template_base.done
KBSD1_PLTOOLS_TOOLS+=	${MINI_TOOLS} ${KBSD1_ADD_TOOLS}

ETC_ESSENTIALS+=	login.conf nsswitch.conf group services
ETC_ESSENTIALS+=	newsyslog.conf rc rc.subr syslog.conf defaults/rc.conf 
ETC_ESSENTIALS+=	rc.d/DAEMON rc.d/FILESYSTEMS rc.d/LOGIN rc.d/NETWORKING rc.d/SERVERS 
ETC_ESSENTIALS+=	rc.d/cleanvar rc.d/dmesg rc.d/ldconfig rc.d/mountcritlocal rc.d/newsyslog rc.d/syslogd rc.d/tmp rc.d/var
ETC_ESSENTIALS+=	fbtab login.conf login.conf.db gettytab ttys
KBSD2_PLTOOLS_TOOLS+=	${ETC_ESSENTIALS:@x@/etc/${x}@}
KBSD2_PLTOOLS_TOOLS+=	${MINI_TOOLS} ${KBSD2_ADD_TOOLS}
KBSD2_PLTOOLS_TOOLS+=	/usr/bin/limits		
KBSD2_PLTOOLS_TOOLS+=	/usr/bin/login
KBSD2_PLTOOLS_TOOLS+=	/usr/libexec/getty
KBSD2_PLTOOLS_TOOLS+=	/usr/sbin/mtree
KBSD2_PLTOOLS_TOOLS+=	/usr/sbin/newsyslog
KBSD2_PLTOOLS_TOOLS+=	/usr/sbin/syslogd
KBSD2_PLTOOLS_TOOLS+=	/etc/mtree/BSD.var.dist
KBSD2_PLTOOLS_INCLUDE+=	/etc/
KBSD2_PLTOOLS_INCLUDE+=	/etc/pam.d/
KBSD2_PLTOOLS_INCLUDE+=	/etc/pam.d/**
KBSD2_PLTOOLS_INCLUDE+=	/etc/security/
KBSD2_PLTOOLS_INCLUDE+=	/etc/security/**
KBSD2_PLTOOLS_INCLUDE+=	/usr/
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/libpam*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_deny*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_group*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_lastlog*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_login_access*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_nologin*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_opie*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_permit*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_rootok*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_securetty*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_self*
KBSD2_PLTOOLS_INCLUDE+=	/usr/lib/pam_unix*
KBSD1_PLTOOLS_LOADERLOCAL+=		init_script="/etc/rc.kBSD1"

KBSD1_PAYLOAD+=		KBSD1_PLRESCUE PLROOTSKEL KBSD1_PLKERNEL KBSD1_PLTOOLS ${KBSD1_ADD_PAYLOAD}
#KBSD2_PAYLOAD+=		KBSD2_PLRESCUE PLROOTSKEL KBSD2_PLROOTPW  KBSD2_PLINSTALL ${KBSD2_ADD_PAYLOAD}
KBSD2_PAYLOAD+=		KBSD2_PLRESCUE PLROOTSKEL KBSD2_PLROOTPW ${KBSD2_ADD_PAYLOAD}


kbsd1-nfs_PLDEPEND			+=	KBSD2_IMAGE
kbsd1-memtftp_PLDEPEND		+=	KBSD2_IMAGE
kbsd1-iso_PLDEPEND			+=	KBSD2_IMAGE
kbsd1-memiso_PLDEPEND		+=	KBSD2_IMAGE

kbsd2-nfs_LOADERLOCAL+=		init_script="/etc/rc.kBSD2"

.for kbsd in KBSD1 KBSD2

PAYLOAD_DIR:=${${kbsd}_ROOT_DIR}

ALL_PAYLOAD+=					${kbsd}_PLRESCUE
${kbsd}_PLRESCUE_DESC:=			Copy rescue environment and create symbolic links to the rescue tools
${kbsd}_PLRESCUE_OUT:=			${PAYLOAD_DIR}/
${kbsd}_PLRESCUE_TOOLS+=		/usr/share/misc/scsi_modes
${kbsd}_PLRESCUE_INCLUDE+=		/dev/
${kbsd}_PLRESCUE_INCLUDE+=		/etc/
${kbsd}_PLRESCUE_INCLUDE+=		/bin/
${kbsd}_PLRESCUE_INCLUDE+=		/media/
${kbsd}_PLRESCUE_INCLUDE+=		/mnt/
${kbsd}_PLRESCUE_INCLUDE+=		/proc/
${kbsd}_PLRESCUE_INCLUDE+=		/root/
${kbsd}_PLRESCUE_INCLUDE+=		/sbin/
${kbsd}_PLRESCUE_INCLUDE+=		/rescue/
${kbsd}_PLRESCUE_INCLUDE+=		/rescue/**
${kbsd}_PLRESCUE_INCLUDE+=		/tmp/
${kbsd}_PLRESCUE_INCLUDE+=		/usr/bin/
${kbsd}_PLRESCUE_INCLUDE+=		/usr/sbin/
${kbsd}_PLRESCUE_INCLUDE+=		/var/

# define link dependencies to all rescue files
.include "kbsd.allrescue.mk"
.for rescue in ${ALL_RESCUE}
${${kbsd}_PLRESCUE_OUT:H}${rescue}:  LNR${rescue:S%/% %g:range:[-1]}
.endfor

${kbsd}_PLRESCUE_DEPEND:=		.template_base.done  ${ALL_RESCUE:%=${${kbsd}_PLRESCUE_OUT:H}%} ${TEMPLATE_DIR}/


ALL_PAYLOAD+=					${kbsd}_PLFULLKB
${kbsd}_PLFULLKB_DESC:=			Copy complete base and kernel for ${kbsd}
${kbsd}_PLFULLKB_OUT:=			${PAYLOAD_DIR}/ 
${kbsd}_PLFULLKB_DEPEND:=		.template_base.done .template_kernel.done ${TEMPLATE_DIR}/
${kbsd}_PLFULLKB_EXCLUDE+=		${${kbsd}_PLROOTPW_TOOLS}
${kbsd}_PLFULLKB_EXCLUDE+=		${CD_TOOLS}
${kbsd}_PLFULLKB_EXCLUDE+=		${LOADERDIR_INCLUDE}
${kbsd}_PLFULLKB_EXCLUDE+=		/etc/rc.d/fsck 					# cannot be disabled in rc.conf and cannot check our md0.uzip
${kbsd}_PLFULLKB_EXCLUDE+=		/etc/rc.d/root 					# cannot be disabled in rc.conf and runs an umount -a, which we don't like
${kbsd}_PLFULLKB_INCLUDE:=		**


ALL_PAYLOAD+=					${kbsd}_PLSLIMKB
${kbsd}_PLSLIMKB_DESC:=			Copy trimmed down base and kernel for ${kbsd}
${kbsd}_PLSLIMKB_OUT:=			${PAYLOAD_DIR}/ 
${kbsd}_PLSLIMKB_DEPEND:=		.template_base.done .template_kernel.done ${TEMPLATE_DIR}/
${kbsd}_PLSLIMKB_EXCLUDE+=		${${kbsd}_PLROOTPW_TOOLS}
${kbsd}_PLSLIMKB_EXCLUDE+=		${CD_TOOLS}
${kbsd}_PLSLIMKB_EXCLUDE+=		${LOADERDIR_INCLUDE}
${kbsd}_PLSLIMKB_EXCLUDE+=		/etc/rc.d/fsck 					# cannot be disabled in rc.conf and cannot check our md0.uzip
${kbsd}_PLSLIMKB_EXCLUDE+=		/etc/rc.d/root 					# cannot be disabled in rc.conf and runs an umount -a, which we don't like
${kbsd}_PLSLIMKB_EXCLUDE+=		doc
${kbsd}_PLSLIMKB_EXCLUDE+=		examples
${kbsd}_PLSLIMKB_EXCLUDE+=		include
${kbsd}_PLSLIMKB_EXCLUDE+=		info
${kbsd}_PLSLIMKB_EXCLUDE+=		games
${kbsd}_PLSLIMKB_EXCLUDE+=		gcov
${kbsd}_PLSLIMKB_EXCLUDE+=		man
${kbsd}_PLSLIMKB_EXCLUDE+=		sendmail
${kbsd}_PLSLIMKB_EXCLUDE+=		*llvm*
${kbsd}_PLSLIMKB_EXCLUDE+=		ld.lld
${kbsd}_PLSLIMKB_EXCLUDE+=		*lldb*
${kbsd}_PLSLIMKB_EXCLUDE+=		svn*
${kbsd}_PLSLIMKB_EXCLUDE+=		tests
${kbsd}_PLSLIMKB_EXCLUDE+=		*.a
${kbsd}_PLSLIMKB_INCLUDE:=		**

ALL_PAYLOAD+=					${kbsd}_PLKERNEL
${kbsd}_PLKERNEL_DESC:=			Copy kernel modules for ${kbsd}
${kbsd}_PLKERNEL_DEPEND:=		.template_kernel.done ${TEMPLATE_DIR}/
${kbsd}_PLKERNEL_OUT:=			${PAYLOAD_DIR}/
${kbsd}_PLKERNEL_INCLUDE+=		/boot/
${kbsd}_PLKERNEL_INCLUDE+=		/boot/kernel/
${kbsd}_PLKERNEL_INCLUDE+=		${${kbsd}_PLKERNEL_MODULES:@x@/boot/kernel/${x}.ko@}

ALL_PAYLOAD+=					${kbsd}_PLINSTALL
${kbsd}_PLINSTALL_DESC:=		Copy essential bsdinstall(8) files for ${kbsd}
${kbsd}_PLINSTALL_DEPEND:=		.template_base.done ${TEMPLATE_DIR}/
${kbsd}_PLINSTALL_PLDEPEND:=	${kbsd}_PLKERNEL ${kbsd}_PLTOOLS ${kbsd}_PLROOTPW
${kbsd}_PLINSTALL_OUT:=			${PAYLOAD_DIR}/
${kbsd}_PLINSTALL_INCLUDE+=		/boot/
${kbsd}_PLINSTALL_INCLUDE+=		/boot/boot
${kbsd}_PLINSTALL_INCLUDE+=		/boot/boot1.efifat
${kbsd}_PLINSTALL_INCLUDE+=		/boot/gptboot
${kbsd}_PLINSTALL_INCLUDE+=		/boot/gptzfsboot
${kbsd}_PLINSTALL_INCLUDE+=		/boot/mbr
${kbsd}_PLINSTALL_INCLUDE+=		/boot/pmbr
${kbsd}_PLINSTALL_INCLUDE+=		/etc/
${kbsd}_PLINSTALL_INCLUDE+=		/etc/termcap.small
${kbsd}_PLINSTALL_INCLUDE+=		/usr/
${kbsd}_PLINSTALL_INCLUDE+=		/usr/libexec/
${kbsd}_PLINSTALL_INCLUDE+=		/usr/libexec/bsdconfig/
${kbsd}_PLINSTALL_INCLUDE+=		/usr/libexec/bsdconfig/**
${kbsd}_PLINSTALL_INCLUDE+=		/usr/libexec/bsdinstall/
${kbsd}_PLINSTALL_INCLUDE+=		/usr/libexec/bsdinstall/**
${kbsd}_PLINSTALL_INCLUDE+=		/usr/sbin/
${kbsd}_PLINSTALL_INCLUDE+=		/usr/sbin/bsdinstall
${kbsd}_PLINSTALL_INCLUDE+=		/usr/share/
${kbsd}_PLINSTALL_INCLUDE+=		/usr/share/bsdconfig/
${kbsd}_PLINSTALL_INCLUDE+=		/usr/share/bsdconfig/**
${kbsd}_PLINSTALL_INCLUDE+=		/usr/share/vt/
${kbsd}_PLINSTALL_INCLUDE+=		/usr/share/vt/**
${kbsd}_PLINSTALL_TOOLS+=       /sbin/geli
${kbsd}_PLINSTALL_TOOLS+=       /sbin/graid
${kbsd}_PLINSTALL_TOOLS+=		/sbin/sha256
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/awk
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/basename
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/bc
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/cap_mkdb
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/clear
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/cut
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/dialog
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/dirname
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/egrep
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/env
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/find
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/grep
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/passwd
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/sort
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/touch
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/tr
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/uname
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/uniq
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/wc
${kbsd}_PLINSTALL_TOOLS+=		/usr/bin/xargs
${kbsd}_PLINSTALL_TOOLS+=		/usr/sbin/efibootmgr
${kbsd}_PLINSTALL_TOOLS+=		/usr/sbin/tzsetup

.${kbsd}_PLINSTALL-dist.done: .${kbsd}_PLINSTALL-sync.done
	${MKDIR} ${${kbsd}_PLINSTALL_OUT}usr/freebsd-dist
	${TOUCH} ${.TARGET}

.${kbsd}_PLINSTALL.done: .${kbsd}_PLINSTALL-dist.done

clean-${kbsd}_PLINSTALL-dist: .PHONY
	${RM} -f .${kbsd}_PLINSTALL-dist.done

clean-${kbsd}_PLINSTALL: clean-${kbsd}_PLINSTALL-dist

ALL_PAYLOAD+=					${kbsd}_PLTOOLS
${kbsd}_PLTOOLS_DESC:=			Install tools with dependencies for ${kbsd}
${kbsd}_PLTOOLS_OUT:=			${PAYLOAD_DIR}/
${kbsd}_PLTOOLS_DEPEND+=		${TEMPLATE_DIR}/
${kbsd}_PLTOOLS_PKG+=			${${kbsd}_ADD_PKG}


ALL_PAYLOAD+=					${kbsd}_PLROOTPW
${kbsd}_PLROOTPW_DESC:=			Configure root password for ${kbsd}
${kbsd}_PLROOTPW_DEPEND+=		.${kbsd}_PLROOTPW-passwd.done
${kbsd}_PLROOTPW_DIR:=			${kbsd:tl}-rootpw
ALL_DIRS+=						${kbsd}_PLROOTPW_DIR
${kbsd}_PLROOTPW_OUT:=			${${kbsd}_PLROOTPW_DIR}/
${kbsd}_PASSWD_FILES:=			master.passwd passwd pwd.db spwd.db
${kbsd}_PLROOTPW_TOOLS:=		${${kbsd}_PASSWD_FILES:@x@/etc/${x}@}

.${kbsd}_PLROOTPW-passwd.done: .${kbsd}_PLROOTPW-tools.done
	echo "kbsd" | ${PW} -R ${${kbsd}_PLROOTPW_OUT} usermod root -s /bin/sh -h 0
	${TOUCH} ${.TARGET}

_clean-passwd-${kbsd}_PLROOTPW: .PHONY
	${RM} -f .${kbsd}_PLROOTPW-passwd.done

clean-${${kbsd}_PLROOTPW_OUT:H}: _clean-passwd-${kbsd}_PLROOTPW



###
# Dependency handling
#  - collect tools and names of packages hashed for the actual (library) dependencies

${kbsd}_MKDEPENDFILES:=		${${kbsd}_PAYLOAD:@v@${${v}_TOOLS}@}
${kbsd}_MKDEPENDPKGS:=		${${kbsd}_PAYLOAD:@v@${${v}_PKG}@}
${kbsd}_MKDEPENDALL:=		${${kbsd}_MKDEPENDFILES} ${${kbsd}_MKDEPENDPKGS}
${kbsd}_DEPENDFILE:=		${kbsd:tl}.depend.${${kbsd}_MKDEPENDALL:O:u:hash}


# we depend on having made all payloads, so we can list all files.
${${kbsd}_DEPENDFILE}: ${${kbsd}_PAYLOAD:@v@.${v}.done@}
	@echo making dependencies #for  ${${kbsd}_MKDEPENDALL:O:u}
	@echo '# dependencies for ${${kbsd}_MKDEPENDALL:O:u}' > ${.TARGET}
	sh ${.CURDIR}/mktools/elfdepend ${${kbsd}_ROOT_DIR:Q} ${TEMPLATE_DIR:Q} | sort | uniq >> ${.TARGET}

.${kbsd}-fixdepend.done: ${${kbsd}_DEPENDFILE}
	@${TOUCH} -r ${.ALLSRC} ${.TARGET} # if we have no dependencies to fix
	@echo -n Fixing dependencies ${${kbsd}_DEPENDFILE} #for ${${kbsd}_MKDEPENDALL:O:u}
	@${RSYNC} -iaH --update --include-from=${${kbsd}_DEPENDFILE} --exclude='**' ${TEMPLATE_DIR:Q}/ ${${kbsd}_ROOT_DIR:Q}/  | grep -v '^\.' | [ $$(wc -c) -ne 0 ] && ( touch ${.TARGET}; echo ) || echo ' [unchanged]'

.if defined(NODEPEND)
.${kbsd}.done: ${${kbsd}_PAYLOAD:@v@.${v}.done@}
	${TOUCH} ${.TARGET}
.else
.${kbsd}.done: .${kbsd}-fixdepend.done
	${TOUCH} ${.TARGET}
.endif


${kbsd}: .PHONY .${kbsd}.done

clean-${kbsd}-fixdepend: .PHONY
	${RM} -f .${kbsd}-fixdepend.done

clean-${kbsd}: clean-${kbsd}-fixdepend
	${RM} -f .${kbsd}.done

clean: clean-${kbsd}

###
# root image configuration
#
ALL_PAYLOAD+=					${kbsd}_IMAGE
${kbsd}_IMAGE_DIR:=				${kbsd:tl}image
ALL_DIRS+=						${kbsd}_IMAGE_DIR
${kbsd}_IMAGE_DESC:=			Create root filesystem memory image for ${kbsd}
${kbsd}_IMAGE_OUT:=				${${kbsd}_IMAGE_DIR}/
${kbsd}_FFS:=					${kbsd:tl}.ffs

#FIXME: non-deterministic label
${${kbsd}_FFS}:	.${kbsd}.done ${${kbsd}_PAYLOAD:@v@${${v}_OUT}@:O:u} FFS
	@echo Your uncompressed root memory filesystem ${.TARGET} is `du -Ak ${.TARGET} | cut -f 1`k

${kbsd:tl}.zfs: .${kbsd}.done ${${kbsd}_PAYLOAD:@v@${${v}_OUT}@:O:u} ZFS
	@echo Your uncompressed root memory filesystem zfs ${.TARGET} is `du -Ak ${.TARGET} | cut -f 1`k

${${kbsd}_IMAGE_DIR}/${${kbsd}_FFS}.gz: ${${kbsd}_FFS} GZ
	@echo Your compressed root memory filesystem ${.TARGET} is `du -Ak ${.TARGET} | cut -f 1`k

${${kbsd}_IMAGE_DIR}/${${kbsd}_FFS}.uz: ${${kbsd}_FFS} UZ
	@echo Your compressed root memory filesystem ${.TARGET} is `du -Ak ${.TARGET} | cut -f 1`k

.if empty(LOADER_MODULES:Mgeom_uzip)
${kbsd}_IMAGENAME:=			${${kbsd}_IMAGE_DIR}/${${kbsd}_FFS}.gz
${kbsd}_IMAGE_xLOADERLOCAL+=	vfs.root.mountfrom="ufs:/dev/md0"
.else # empty(LOADER_MODULES:Mgeom_uzip)
${kbsd}_IMAGENAME:=			${${kbsd}_IMAGE_DIR}/${${kbsd}_FFS}.uz
${kbsd}_IMAGE_xLOADERLOCAL+=	vfs.root.mountfrom="ufs:/dev/md0.uzip"
.endif # empty(LOADER_MODULES:Mgeom_uzip)
${kbsd}_IMAGE_xLOADERLOCAL+=	${kbsd}_load="YES"
${kbsd}_IMAGE_xLOADERLOCAL+=	${kbsd}_type="md_image"
${kbsd}_IMAGE_xLOADERLOCAL+=	${kbsd}_name="/${${kbsd}_IMAGENAME:T}"

${kbsd}_IMAGE_xLOADERLOCAL+= ${${kbsd}_PAYLOAD:@v@${${v}_LOADERLOCAL}@}

${kbsd}_IMAGE_DEPEND:=			${${kbsd}_IMAGE_DIR} ${${kbsd}_IMAGENAME}

clean-${kbsd}_IMAGE-extra:
	${RM} -f ${${kbsd}_FFS}

clean-${kbsd}_IMAGE: clean-${kbsd}_IMAGE-extra
#
###




ALL_COLLECTION+=					${kbsd:tl}-memtftp
${kbsd:tl}-memtftp_DESC:=			Compile an tftp-root directory structure with an MD image
${kbsd:tl}-memtftp_PLDEPEND+=		EFI LOADERDIRGZ ${kbsd}_IMAGE
${kbsd:tl}-memtftp_COPY:=			YES
${kbsd:tl}-memtftp_LOADERLOCAL+=	kernels_autodetect="NO" # incompatible with tftp
${kbsd:tl}-memtftp_LOADERLOCAL+=	tftp.blksize="1428"
${kbsd:tl}-memtftp_LOADERLOCAL+=	${${kbsd}_IMAGE_xLOADERLOCAL}


ALL_COLLECTION+=					${kbsd:tl}-nfs
${kbsd:tl}-nfs_DESC:=				Compile an nfsroot directory structure
${kbsd:tl}-nfs_DEPEND+=				.${kbsd}.done
${kbsd:tl}-nfs_PLDEPEND+=			EFI LOADERDIRGZ ${${kbsd}_PAYLOAD}	
${kbsd:tl}-nfs_COPY:=				YES


ALL_COLLECTION+=					${kbsd:tl}-iso
${kbsd:tl}-iso_DESC:=				Compile an ISO image that runs from the CD.
${kbsd:tl}-iso_DEPEND+=				.${kbsd}.done
${kbsd:tl}-iso_PLDEPEND+=			CD LOADERDIRGZ ${${kbsd}_PAYLOAD}
${kbsd:tl}-iso_LOADERLOCAL+=		vfs.root.mountfrom="cd9660:/dev/cd0"

clean-${kbsd:tl}-iso-extra: .PHONY
	${RM} -f ${kbsd:tl}.iso

clean-${kbsd:tl}-iso: clean-${kbsd:tl}-iso-extra

${kbsd:tl}.iso: .${kbsd:tl}-iso-collect.done efi.fat
	${MAKEFS} -t cd9660 -Z \
		-o rockridge,label=kBSD \
		-o bootimage=i386\;${CD_OUT}boot/cdboot,no-emul-boot \
		-o bootimage=i386\;efi.fat,no-emul-boot,platformid=efi \
		${.TARGET:Q} ${${kbsd:tl}-iso_ALLOUT}

.${kbsd:tl}-iso.done: ${kbsd:tl}.iso

ALL_COLLECTION+=					${kbsd:tl}-memiso
${kbsd:tl}-memiso_DESC:=			Compile an ISO image that fully loads into memory
${kbsd:tl}-memiso_PLDEPEND+=		CD LOADERDIRGZ ${kbsd}_IMAGE
${kbsd:tl}-memiso_LOADERLOCAL+=		${${kbsd}_IMAGE_xLOADERLOCAL}

clean-${kbsd:tl}-memiso-extra:
	${RM} -f ${kbsd:tl}-mem.iso

clean-${kbsd:tl}-memiso: clean-${kbsd:tl}-memiso-extra

${kbsd:tl}-mem.iso: .${kbsd:tl}-memiso-collect.done efi.fat
	${MAKEFS} -t cd9660 -Z \
		-o rockridge,label=kBSD \
		-o bootimage=i386\;${CD_OUT}boot/cdboot,no-emul-boot \
		-o bootimage=i386\;efi.fat,no-emul-boot,platformid=efi \
		${.TARGET:Q} ${${kbsd:tl}-memiso_ALLOUT}

.${kbsd:tl}-memiso.done: ${kbsd:tl}-mem.iso



#	@echo     memnfs
#	@echo '        * prepare KBSD2 to be used booted over NFS, but using root in memory'
#	@echo '	  (mem)?(nfs|tftp)-txz'
#	@echo '       * same as above, just package the directory'
#	@echo ... thumb,memstick, ARM, RISCV...

.endfor # kbsd1, kbsd2

distclean-fixdepend: .PHONY
	${RM} -f kbsd[1-2].depend.*

distclean: distclean-fixdepend



.MAIN: help

.endif # exists(kbsd-${VERSION}-${MACHINE})

.include "kbsd.payload.mk"
.include "kbsd.collection.mk"
.include "kbsd.fileutil.mk"