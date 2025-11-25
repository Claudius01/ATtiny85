; "$Id: ATtiny85_uOS_Eeprom.asm,v 1.3 2025/11/25 16:56:59 administrateur Exp $"

.include		"ATtiny85_uOS_Eeprom.h"

.cseg
; ---------
; Lecture d'un byte de l'EEPROM a l'adresse 'REG_X_MSB:REG_X_LSB'
; => Valeur retournee dans 'REG_TEMP_R16'
; ---------
eeprom_read_byte:
	; Set address
	out		EEARL, REG_X_LSB
	out		EEARH, REG_X_MSB

	; Lecture a l'adresse 'REG_X_MSB:REG_X_LSB'
eeprom_read_byte_wait:
	sbic		EECR, EEPE
	rjmp		eeprom_read_byte_wait

	sbi		EECR, EERE
	in			REG_TEMP_R16, EEDR
	; Fin: Lecture a l'adresse 'REG_X_MSB:REG_X_LSB'

	ret
; ---------

; ---------
; Ecriture d'un byte contenu dans 'REG_TEMP_R16' a l'adresse 'REG_X_MSB:REG_X_LSB' de l'EEPROM
; ---------
eeprom_write_byte:
	; Set address
	out		EEARL, REG_X_LSB
	out		EEARH, REG_X_MSB

	; Set data
	out		EEDR, REG_TEMP_R16

	; Ecriture a l'adresse 'REG_X_MSB:REG_X_LSB' d'un byte
	cbi		EECR, EEPM1
	cbi		EECR, EEPM0

	; Sequence interruptible
	cli
	sbi		EECR, EEMPE		; Start EEPROM write
	sbi		EECR, EEPE
	sei
	; Fin: Sequence interruptible
	; Fin: Ecriture a l'adresse 'REG_X_MSB:REG_X_LSB' d'un byte

eeprom_write_byte_wait:
	sbic		EECR, EEPE
	rjmp		eeprom_write_byte_wait

	ret
; ---------

text_prompt_eeprom_version:
.db	"### EEPROM: ", CHAR_NULL, CHAR_NULL

text_prompt_type:
.db	"### Type: ", CHAR_NULL, CHAR_NULL

text_prompt_id:
.db	"### Id: ", CHAR_NULL, CHAR_NULL

text_eeprom_error:
.db	"Err: EEPROM at ", CHAR_NULL

; End of file

