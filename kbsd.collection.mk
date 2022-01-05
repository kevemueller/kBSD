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
# Manage kBSD collections
#
# A collection is defined by adding its collection variable stem to the ALL_COLLECTION variable
# A payload defines
#      COLLECTION_DESC 		- a one liner describing the collection for the user
#      COLLECTION_OUT 		- a directory name _with trailing slash_ containing all the output of the collection
#								defaults to COLLECTION-root
#      COLLECTION_DEPEND 	- a list of dependencies that are to be collected
#      COLLECTION_PLDEPEND 	- a list of payload dependencies that are to be collected
#	   COLLECTION_COPY		- if defined, payload output is copied into the collection output
#	   COLLECTION_LOADERLOCAL-	anything to add to loader.conf.local
#
#
# User defined behaviour overrides
# 
# For all collections, the following targets are defined
#	  COLLECTION			- convenience target
#     collect-COLLECTION	- chained to COLLECTION
#	  ${${cl}_LOADER_CONF}  - filename of colletions loader.conf.local, chained to collect-COLLECTION
#     clean-COLLECTION 		- chain of cleanups
#     clean 				- chained to clean-COLLECTION
# For collections with COPY, the following targets are defined
#     .COLLECTION-copy.done - flag value
#     copy-COLLECTION 		- perform the copy
#     collect-COLLECTION	- chained to copy-PAYLOAD


.for cl in ${ALL_COLLECTION}

${cl}_OUT?=		${cl}-root/
ALL_DIRS+=	${cl}_OUT
${cl}_ALLOUT:=	${${cl}_PLDEPEND:@v@${${v}_OUT}@:O:u} ${${cl}_OUT}

# main targets

.${cl}.done: .${cl}-collect.done
	${TOUCH} ${.TARGET}

${cl}: .PHONY .${cl}.done

.${cl}-collect.done:  ${${cl}_PLDEPEND:@v@.${v}.done@} ${${cl}_DEPEND}
	${TOUCH} ${.TARGET}


.if defined(${cl}_COPY)
.${cl}-copy.done! ${${cl}_PLDEPEND:@v@.${v}.done@} ${${cl}_DEPEND}
	@echo ${${cl}_PLDEPEND:@v@${${v}_OUT}@:O:u}
	${${cl}_PLDEPEND:@v@${${v}_OUT}@:O:u:@v@${RSYNC} -aH ${v} ${${cl}_OUT} ;@}

#	@echo -n ${pl} sync tree ${.ALLSRC:[-1]} -\> ${${pl}_OUT}
#	@${RSYNC} -iaH --update ${${pl}_INCLUDE:@x@--include='${x}'@} --exclude='**' ${.ALLSRC:[-1]} ${${pl}_OUT} | grep -v '^\.' | [ $$(wc -c) -ne 0 ] && ( touch .${pl}_sync.done; echo ) || echo ' [unchanged]'

###
# Convenience rule.
#
copy-${cl}: .PHONY .${cl}-copy.done

.${cl}-collect.done: .${cl}-copy.done

.endif # defined(${cl}_COPY)

${cl}_BOOTDIR:=			${${cl}_OUT}boot
ALL_DIRS+=				${cl}_BOOTDIR
${cl}_LOADER_CONF:=		${${cl}_BOOTDIR}/loader.conf.local

${cl}_LOADERCFGD:=		${${cl}_PLDEPEND:@v@${${v}_LOADERLOCAL}@} ${${cl}_LOADERLOCAL}
${cl}_LOADERCFG:=		${${cl}_LOADERCFGD:O:u}
${cl}_LOADERCFG_GUARD:=	.loadercfg.${${cl}_LOADERCFG:hash}

${${cl}_LOADERCFG_GUARD}:
	@echo "# loader.conf.local for kBSD ${cl}" > ${.TARGET:Q}
	@${${cl}_LOADERCFG:@x@echo ${x:Q} >> ${.TARGET:Q};@}

${${cl}_LOADER_CONF}: ${${cl}_BOOTDIR} ${${cl}_LOADERCFG_GUARD}
	${CP} -a ${.ALLSRC:[-1]} ${.TARGET:Q}

.${cl}-collect.done: ${${cl}_LOADER_CONF}

clean-${cl}: .PHONY
	@test -d ${${cl}_OUT:Q} && ${CHFLAGS} -R noschg ${${cl}_OUT:Q} || true
	${RM} -f .${cl}-collect.done .${cl}.done ${${cl}_LOADERCFG_GUARD}
	${RM} -rf ${${cl}_OUT:Q}

clean: clean-${cl}

.endfor # cl in ${ALL_COLLECTION}

distclean-collection: .PHONY
	${RM} -f .loadercfg.*

distclean: distclean-collection
