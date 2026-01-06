#!/bin/bash

#ident "@(#) micro-infos $Id: goGenerateProjectAllModes.sh,v 1.3 2026/01/06 17:00:10 administrateur Exp $"

# Script de production d'un projet passe en argument dans tous les modes supportes
# Exemples:
#   $ ./goGenerateProjectAllModes.sh ATtiny85_uOS     -> Production du projet 'ATtiny85_uOS'

#set -x
set -e

AVRA_DIR="/home/administrateur/Programmes/avra-master_1.4.2"
AVRA_BIN="${AVRA_DIR}/src/avra"
AVRA_INC="${AVRA_DIR}/includes"

PROJECTS="."

if [ -z ${1} ]; then
	echo "No 1st argument passed"

	echo "Usage:"
	echo "${0} <project_name>"
	echo "Ex: ${0} ATtiny85_uOS+DS18B20"

	exit 2
else
	echo "Production of '${1}'..."
	echo $*
fi

PROJECTS_FILE=${1}

EXT_ASM="asm"
EXT_LST="lst"
EXT_MAP="map"
EXT_DEF="def"
EXT_OBJ="obj"
EXT_HEX="hex"

LIST_MODE_USE_USI="USE_USI=0 USE_USI=1"
LIST_MODE_MINIMALIST_VALUE="0 1"

for mode_usi in ${LIST_MODE_USE_USI}
do
	for mode_minimalist_value in ${LIST_MODE_MINIMALIST_VALUE}
	do
		_USE_MINIMALIST_UOS="USE_MINIMALIST_UOS=${mode_minimalist_value}"
		_USE_MINIMALIST_ADDONS="USE_MINIMALIST_ADDONS=${mode_minimalist_value}"

		echo "Mode USI               [${mode_usi}]"
		echo "Mode Minimalist Value  [${mode_minimalist_value}]"
		echo "Mode Minimalist uOS    [${_USE_MINIMALIST_UOS}]"
		echo "Mode Minimalist Addons [${_USE_MINIMALIST_ADDONS}]"

		rm -f ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_MAP} ${PROJECTS_FILE}.${EXT_OBJ} ${PROJECTS_FILE}.${EXT_HEX}

		${AVRA_BIN} -D USE_ADDONS -D ${_USE_MINIMALIST_UOS} -D ${mode_usi} -D ${_USE_MINIMALIST_ADDONS} \
			-I ${PROJECTS} -I ${AVRA_INC} -I ../uOS -m ${PROJECTS_FILE}.${EXT_MAP} -l ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_ASM}

		if [ ! -f ${PROJECTS_FILE}.${EXT_LST} ]; then
			echo "Error: No build ;-("	
			exit 1
		fi

		# Recopie des productions...
		PRODUCT_DIRETORY="${mode_usi}-USE_MINIMALIST=${mode_minimalist_value}"
		test -d Products-${PRODUCT_DIRETORY} || mkdir Products-${PRODUCT_DIRETORY}
		cp -p ${PROJECTS_FILE}.${EXT_HEX} ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_MAP} Products-${PRODUCT_DIRETORY}
	done
done

echo
echo "List of productions"
echo "-------------------"

for d in `ls -d Products-*`
do
	echo $d
	ls -l $d

	echo
	echo "Sizes memory"
	echo "------------"
	egrep "G_SRAM_END_OF_USE|end_of_prg_uos|end_of_prg_addons" $d/*.map

	echo
done

echo
echo "Build successful of project [${PROJECTS_FILE}] :-)"
echo

exit 0
