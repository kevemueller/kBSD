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
# Handle creation of filesystem images (FFS, ZFS, ISOFS, ...)
#


###
# Create a BSD Fast File System image in ${.TARGET} with the files from the directory components of the dependencies ${.ALLSRC}, label using the tail component of this dependency.
#
FFS: .USEBEFORE
	${MAKEFS} -t ffs -Z \
		-f 1000 -b 1% -o label=${.ALLSRC:[-1]:T},optimization=space,version=1 \
		${.TARGET:Q} ${.ALLSRC:M*/}

###
# Create a 2M sized image file in ${.TARGET} containing a FAT12 filesystem with the files from the directory components of the dependencies ${.ALLSRC}, 
# label using the tail component of this dependency.
FAT2M: .USEBEFORE
	${MAKEFS} -t msdos -Z \
		-o fat_type=12 \
		-o sectors_per_cluster=1 \
		-o volume_label=${.ALLSRC:[-1]:S%/$%%:T:tu} \
		-s 2048k \
		${.TARGET:Q} ${.ALLSRC:M*/}


###
# Create a ZFS image.
# WIP
ZFS: .USEBEFORE
	# 64M is the smallest acceptable VDEV size, but metaslab_ashift=24 (16M) fits only 3 slabs (48M)
	# 4 slabs (4x16MiB) + 4 vdev labels (1MiB) + boot block reservation (3584KiB) => 70144 KiB is the smallest fully allocatable VDEV
	${TRUNCATE} -s 70144k ${.TARGET}  
	${ZPOOL} create -f -o cachefile=${PWD}/test.cache -o altroot=/${KBSD_BASE}-${.TARGET:R} -o ashift=12 -O compress=lz4 -O atime=off -m /xxx ${KBSD_BASE}-${.TARGET:R} ${.TARGET:tA}
	${ZFS} create ${KBSD_BASE}-${.TARGET:R}/usr
	${ZFS} create ${KBSD_BASE}-${.TARGET:R}/usr/local
	#${RSYNC} -vaH ${.ALLSRC:[-1]}/ /${KBSD_BASE}-${.TARGET:R}/


###
# Create a geom_uzip image from an image.
#
UZ: .USEBEFORE
	${MKUZIP} -o ${.TARGET:Q} ${.ALLSRC:Q}