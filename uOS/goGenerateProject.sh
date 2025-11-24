#!/bin/bash

#ident "@(#) micro-infos $Id: goGenerateProject.sh,v 1.3 2025/11/24 16:09:00 administrateur Exp $"

# Script de production d'un projet passe en argument
# Exemples:
#   $ ./goGenerate.sh ATtiny85_uOS.asm              -> Production 'ATtiny85_uOS.asm'

#set -x
set -e

AVRA_DIR="/home/administrateur/Programmes/avra-master_1.4.2"
AVRA_BIN="${AVRA_DIR}/src/avra"
AVRA_INC="${AVRA_DIR}/includes"

PROJECTS="."

if [ -z ${1} ]; then
	echo "No 1st argument passed"

	echo "Usage:"
	echo "${0} <project_name> [clean]"
	echo "Ex: ${0} ATtiny85_uOS"
	echo "    ${0} ATtiny85_uOS clean"

	exit 2
else
	echo "Production of '${1}'..."
	echo $*
fi

if [ -z ${2} ]; then
	echo "No 2nd argument passed"
elif [ "${2}" == "clean" ]; then
	echo "Clean project '${1}'"

	rm -f ${1}.hex ${1}.obj ${1}.map ${1}.lst ${1}.eep.hex

	echo
	ls -ltr ${PROJECTS_FILE}*.*

	exit 0
fi

for project in $*
do
	PROJECTS_FILE=${project}

#PROJECTS_FILE="${PROJECTS}/${1}"

EXT_ASM="asm"
EXT_LST="lst"
EXT_MAP="map"
EXT_DEF="def"
EXT_OBJ="obj"
EXT_HEX="hex"

rm -f ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_MAP} ${PROJECTS_FILE}.${EXT_OBJ} ${PROJECTS_FILE}.${EXT_HEX} ${PROJECTS_FILE}.${EXT_DECODE_MAP} 

echo
echo "################## Production of '${PROJECTS_FILE}' ##################"

${AVRA_BIN} -I ${PROJECTS} -I ${AVRA_INC} -m ${PROJECTS_FILE}.${EXT_MAP} -l ${PROJECTS_FILE}.${EXT_LST} ${PROJECTS_FILE}.${EXT_ASM}

if [ ! -f ${PROJECTS_FILE}.${EXT_LST} ]; then
	echo "Error: No build ;-("	
	exit 1
fi

echo
ls -ltr ${PROJECTS_FILE}*.*

echo
echo "Build successful of project [${PROJECTS_FILE}] :-)"
echo

# Generation eventuelle d'une eeprom au format '.hex'
2>/dev/null type genHexFile

if [ $? -eq 0 ]; then
	echo
	echo "Generate the eeprom content"
	echo
	genHexFile -o ./eeprom_uOS.hex -T 1 -t BYTE -i 0x1234
fi

echo "################## End of production of '${PROJECTS_FILE}' ##################"

done

exit 0
