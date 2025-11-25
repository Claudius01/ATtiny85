; "$Id: ATtiny85_uOS_Eeprom.asm,v 1.4 2025/11/25 18:30:47 administrateur Exp $"

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

;--------------------
; Lecture et impression des informations de l'EEPROM
;--------------------
set_infos_from_eeprom:
	; => Prompt "### EEPROM..."
	ldi		REG_TEMP_R18, 8
	ldi		REG_Z_MSB, ((text_prompt_eeprom_version << 1) / 256)
	ldi		REG_Z_LSB, ((text_prompt_eeprom_version << 1) % 256)
	rcall		push_text_in_fifo_tx

	; Lecture de la version de l'EEPROM definie dans l'EEPROM
	ldi		REG_X_MSB, high(EEPROM_ADDR_VERSION)
	ldi		REG_X_LSB, low(EEPROM_ADDR_VERSION)
	rcall		push_text_in_fifo_tx_from_eeprom
	rcall		print_line_feed

	; => Prompt "### Type..."
	ldi		REG_Z_MSB, ((text_prompt_type << 1) / 256)
	ldi		REG_Z_LSB, ((text_prompt_type << 1) % 256)
	rcall		push_text_in_fifo_tx

	; Lecture du type de la platine defini dans l'EEPROM
	ldi		REG_X_MSB, high(EEPROM_ADDR_TYPE);
	ldi		REG_X_LSB, low(EEPROM_ADDR_TYPE);
	rcall		eeprom_read_byte

	sts		G_HEADER_TYPE_PLATINE, REG_TEMP_R16

	rcall		convert_and_put_fifo_tx
	rcall		print_line_feed

	; => Prompt "### Id..."
	ldi		REG_Z_MSB, ((text_prompt_id << 1) / 256)
	ldi		REG_Z_LSB, ((text_prompt_id << 1) % 256)
	rcall		push_text_in_fifo_tx
	
	; Lecture de l'Id de la palatine defini dans l'EEPROM
	ldi		REG_X_MSB, high(EEPROM_ADDR_ID);
	ldi		REG_X_LSB, low(EEPROM_ADDR_ID);
	rcall		eeprom_read_byte

	sts		G_HEADER_INDEX_PLATINE, REG_TEMP_R16

	rcall		convert_and_put_fifo_tx
	rcall		print_line_feed
	; Fin: Preparation emission des prompts d'accueil

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

