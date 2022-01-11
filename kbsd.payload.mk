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
# Manage kBSD payloads
#
# A payload is defined by adding its payload variable stem to the ALL_PAYLOAD variable
# A payload defines
#      PAYLOAD_DESC 		- a one liner describing the payload for the user
#      PAYLOAD_OUT 			- a directory name _with trailing slash_ containing all the output of the payload, even if a single file
#      PAYLOAD_DEPEND 		- a list of dependencies that need to be met before the payload can be processed
#                				the last dependency is the source directory of the payload with a trailing slash
#	   PAYLOAD_PLDEPEND		- list of payload dependencies
#	   PAYLOAD_LOADERLOCAL	- lines to be appended to loader.conf.local when using this payload
#      PAYLOAD_EXCLUDE 		- files/directories to be excluded in a synchronization job
#      PAYLOAD_EXCLUDEFILE  - file with files/directories to be excluded in a synchronization job
#      PAYLOAD_INCLUDE 		- files/directories to be included in a synchronization job
#      PAYLOAD_TOOLS 		- absolute filenames for tools that are included from the template directory
#      PAYLOAD_PKG 			- package names that shall be installed
#	   PAYLOAD_PKGEXCLUDE	- paths/files to exclude from installed packages
#							  defaults to ${KBSD_PKGEXCLUDE}
#
#
# User defined behaviour overrides
#     KBSD_PKGEXCLUDE		- list of paths/files to be excluded by default in package payloads
#							  defaults to man include doc *.a
#	  REPOS_DIR				- pkg environment repos dir
#							  defaults to /etc/pkg
# 
# For all payloads, the following targets are defined
#     .PAYLOAD.done			- flag value
#     PAYLOAD				- convenience target
#     clean-PAYLOAD 		- chain of cleanups
#     clean 				- chained to clean-PAYLOAD
# For synchronization payloads, the following targets are defined
#     .PAYLOAD-sync.done 	- flag value
#     sync-PAYLOAD 			- perform the synchronization
#     PAYLOAD 				- chained to sync-PAYLOAD
#     clean-sync-PAYLOAD 	- clean the output
#     clean-PAYLOAD 		- chained to clean-sync-PAYLOAD
# For tools payloads, the following targets are defined
#     ${PL_OUT}/toolname 	- CP target for every tool (absolute pathname)
#     .PAYLOAD-tools.done	- flag the copying of all tools
#     tools-PAYLOAD 		- perform all tool copying
#     PAYLOAD 				- chained to tools-PAYLOAD
#     clean-tools-PAYLOAD 	- remove all tools from target
#     clean-PAYLOAD 		- chained to clean-tools-PAYLOAD
# For package payloads, the following targets are defined
#     .PAYLOAD-pkginst.done - flag the installation of the package in the intermediate directory (PAYLOAD_OUT.pkg)
#     .PAYLOAD-pkgsync.done - flag the copying of the package files from the intermediate directory
#     pkg-PAYLOAD 			- perform installation of packages and copying of the files
#     PAYLOAD 				- chained to pkg-PAYLOAD
#     clean-pkg-PAYLOAD 	- remove package related files
#     clean-PAYLOAD 		- chained to clean-pkg-PAYLOAD



KBSD_PKGEXCLUDE?=	man include doc *.a

###
# environmnent variables for pkg
# we maintain a joint cache and db across all payloads using pkg
# we override the ABI to fit our target
PKG_DBDIR:=			pkg-dbdir					# this is relative and will be inside the payload's pkg directory
PKG_CACHEDIR:=		${.OBJDIR}/pkg-cachedir		# this is absolute and will be shared among payloads
REPOS_DIR?=			/etc/pkg
ABI:=				FreeBSD:${KBSD_VERSION_MAJOR}:${KBSD_MACHINE_ARCH}
.export PKG_DBDIR PKG_CACHEDIR REPOS_DIR ABI


# Special copy from ${TEMPLATE_DIR} to any payload target directory
# TARGET is base/path/./tool/path/file
# we splt it into two components and copy ${TEMPLATE_DIR}/tool/path/file to base/path/tool/path/file smart preserving all directory/file timestamps
CP: .USEBEFORE
	#@echo Copying ${.TARGET}  tf=${toolfile} because of ..${.OODATE}.. dependencies being younger
	${targetdir::=${.TARGET:C%(.+/)\./.+%\1%}} ${toolfile::=${.TARGET:C%.+/\.(/.+)%\1%}}
	${RSYNC} --update -aH ${_::=${toolfile:H:H:H:H:.=} ${toolfile:H:H:H:.=} ${toolfile:H:H:.=} ${toolfile:H:.=}}${_:@v@--include=${v:Q}/@} --include=${toolfile:Q} --exclude='**' ${TEMPLATE_DIR}/ ${targetdir}
	# sometimes the dependency is younger than the target, in order to avoid repeated re-make of the target, touch it with the reference of the youngest of all of the sources that triggered it, include itself in the list
	${!empty(.OODATE):?${TOUCH} -r `${STAT} -f%m%t%N ${.TARGET} ${.OODATE} | sort -n | tail -1 | cut -f 2` ${.TARGET}:}



.for pl in ${ALL_PAYLOAD}
# main targets

.${pl}.done:	${${pl}_PLDEPEND:@v@.${v}.done@} ${${pl}_DEPEND} 
	${TOUCH} ${.TARGET}

_clean-${pl}: .PHONY
	${RM} -f .${pl}.done

clean-${${pl}_OUT:H}: _clean-${pl}

${pl}: .PHONY .${pl}.done

clean-${pl}: .PHONY clean-${${pl}_OUT:H}

.if target(clean-${pl}-extra)

clean-${pl}: clean-${pl}-extra

.endif # target(clean-${pl}-extra)

clean: clean-${pl}

.if defined(${pl}_INCLUDE)
###
# We always run the role and capture the output of rsync -i to see if we had a change. We only touch the flag if needed.
# --update is needed, as subsequent rules might override an already existing item, e.g. skeleton directory entry with different timestamp than template directory entry
#
.${pl}-sync.done! ${${pl}_PLDEPEND:@v@.${v}.done@} ${${pl}_DEPEND} 
	#FIXME: this swallows rsync's error condition, evaluate to variable instead?
	@echo -n ${pl} sync tree ${.ALLSRC:[-1]} -\> ${${pl}_OUT}
	@test -f ${.TARGET:Q} || ${TOUCH} ${.TARGET:Q}
	@${RSYNC} -iaH --update ${${pl}_EXCLUDEFILE:@x@--exclude-from=${x:Q}@} ${${pl}_EXCLUDE:@x@--exclude=${x:Q}@} ${${pl}_INCLUDE:@x@--include=${x:Q}@} --exclude='**' ${.ALLSRC:[-1]} ${${pl}_OUT} | grep -v '^\.' | [ $$(wc -c) -ne 0 ] && ( ${TOUCH} ${.TARGET}; echo ) || echo ' [unchanged]'

###
# Convenience rule.
#
sync-${pl}: .PHONY .${pl}-sync.done

.${pl}.done: .${pl}-sync.done

_clean-sync-${pl}: .PHONY
	${RM} -f .${pl}-sync.done

clean-${${pl}_OUT:H}: _clean-sync-${pl}

.endif # defined(${pl}_INCLUDE)

.if defined(${pl}_TOOLS)
# emit CP dependencies
.for tool in ${${pl}_TOOLS}
${${pl}_OUT}.${tool}:	CP
.endfor # tool in ${${pl}_TOOLS}


.${pl}-tools.done: ${${pl}_TOOLS:%=${${pl}_OUT}.%}
	${TOUCH} ${.TARGET}

tools-${pl}: .PHONY .${pl}-tools.done

.${pl}.done: .${pl}-tools.done

_clean-tools-${pl}: .PHONY
	${RM} -f .${pl}-tools.done

clean-${${pl}_OUT:H}: _clean-tools-${pl}



.endif # defined(${pl}_TOOLS)


.if !empty(${pl}_PKG)
${pl}_PKGEXCLUDE?=	${KBSD_PKGEXCLUDE}
${pl}_PKGOUT:=		${${pl}_OUT:/=}.pkg/
ALL_DIRS+=			${pl}_PKGOUT
${pl}_PKGGUARD:=	.${pl}-pkginst.${${pl}_PKG:hash}

## TODO: PKG_DBDIR contains both local.sqlite as well as repo-FreeBSD.sqlite, former must be kept local to the payload directory
## latter should be shared across all payloads. Create a shared PKG_DBDIR with the repo information, create local PKG_DBDIR and symlink the repo information to shared.
##

${${pl}_PKGGUARD}: ${${pl}_PKGOUT}
	@echo Installing packages ${${pl}_PKG}
	ASSUME_ALWAYS_YES=yes ${PKG} -r ${${pl}_PKGOUT} -d install ${${pl}_PKG}
	${TOUCH} ${.TARGET}

.${pl}-pkgsync.done: ${${pl}_PKGGUARD}
	@echo -n ${pl} sync tree ${${pl}_PKGOUT} -\> ${${pl}_OUT}
	@${RSYNC} -iaH --update --exclude=${PKG_DBDIR:Q} ${${pl}_PKGEXCLUDE:@x@--exclude=${x:Q}@} ${${pl}_PKGOUT} ${${pl}_OUT} | grep -v '^\.' | [ $$(wc -c) -ne 0 ] && ( ${TOUCH} ${.TARGET}; echo ) || echo ' [unchanged]'

pkg-${pl}: .PHONY .${pl}-pkgsync.done

.${pl}.done: .${pl}-pkgsync.done

_clean-pkgsync-${pl}:
	${RM} -f .${pl}-pkgsync.done

clean-pkg-${pl}:
	${RM} -rf ${${pl}_PKGOUT} ${${pl}_PKGGUARD}

clean-${${pl}_OUT:H}: _clean-pkgsync-${pl}

clean-${pl}: clean-pkg-${pl}
.endif #!empty(${pl}_PKG)

.endfor # pl in ${ALL_PAYLOAD}


# As payloads accumulate files in their PAYLOAD_OUT directory, they cannot be cleaned independently
# cleaning a payload has to also remove the flags of the other payloads that produce files into the same output directory
# We define for each distinct PAYLOAD_OUT directory a cleanup call, and chain the deletion of the payload cleanups to this

.for plout in ${ALL_PAYLOAD:@v@${${v}_OUT:H}@:O:u}
clean-${plout}: .PHONY
	${RM} -rf ${plout:Q}
.endfor 

distclean-pkgcache: .PHONY
	${RM} -rf ${PKG_CACHEDIR}

distclean: distclean-pkgcache