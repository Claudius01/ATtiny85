; "$Id: ATtiny85_DS18B20_1_Wire_Commands.asm,v 1.7 2025/11/29 16:23:51 administrateur Exp $

.include		"ATtiny85_DS18B20_1_Wire_Commands.h"

; Gestion des commandes 1-Wire:
; * Commandes ROM standards
; - Read Rom [33h]
; - Match Rom [55H]
; - Search ROM [F0h]
;
; * Commandes specifiques au DS18B20
; - Convert T [44h]
; - Read Scratchpad [BEh]
; - Copy Scratchpad [48h]
; - Write Scratchpad [4Eh]
; - Alarm Search [ECh]
;

; ---------
; CMD_READ_ROM
; ---------
; Lecture du registre ROM de 64 bits disponible dans [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 7)]
; ---------
ds18b20_read_rom:
	cli

	ldi		REG_TEMP_R16, DS18B20_CMD_READ_ROM
	rcall		ds18b20_write_8_bits_command
	rcall		ds18b20_read_response_64_bits

	ldi		REG_TEMP_R18, 4
	rcall		ds18b20_print_response

	; Test du CRC8
	ldi		REG_TEMP_R16, 8								; 8 bytes pour le calcul sur les ROM
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_RESP)	; Adresse de 'G_DS18B20_BYTES_RESP'
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_RESP)

	clt															; Test du CRC8 avec non prise en compte du 1st byte
	rcall		ds18b20_crc8_bypass

	set															; A priori, CRC8 recu egal a celui attendu ...
	lds		REG_TEMP_R16, G_CALC_CRC8
	lds		REG_TEMP_R17, G_DS18B20_BYTES_RESP
	cpse		REG_TEMP_R16, REG_TEMP_R17
	clt															; ... et non CRC8 recu different de celui attendu
	; Fin: Test du CRC8

	sei
	ret
; ---------

; ---------
; CMD_CONVERT_T
; ---------
; Conversion de la temperature disponible dans [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 7)]
; ---------
ds18b20_convert_t:
	cli

	ldi		REG_TEMP_R16, DS18B20_CMD_CONVERT_T
	rcall		ds18b20_write_8_bits_command
	rcall		ds18b20_read_response_72_bits

	ldi		REG_TEMP_R16, 'C'
	rcall		uos_push_1_char_in_fifo_tx_skip
	ldi		REG_TEMP_R18, 5
	rcall		ds18b20_print_response

	sei
	ret
; ---------

; ---------
; CMD_READ_SCRATCHPAD
; ---------
; ---------
; Lecture de la Scratchpad disponible dans [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 7)]
; ---------
ds18b20_read_scratchpad:
	cli

	ldi		REG_TEMP_R16, DS18B20_CMD_READ_SCRATCHPAD
	rcall		ds18b20_write_8_bits_command
	rcall		ds18b20_read_response_72_bits

	ldi		REG_TEMP_R16, 'T'
	rcall		uos_push_1_char_in_fifo_tx_skip
	ldi		REG_TEMP_R18, 5
	rcall		ds18b20_print_response

	; Test du CRC8
	ldi		REG_TEMP_R16, 9								; 9 bytes pour le calcul sur les valeurs lues
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_RESP)	; Adresse de 'G_DS18B20_BYTES_RESP'
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_RESP)

	clt															; Test du CRC8 avec non prise en compte du 1st byte
	rcall		ds18b20_crc8_bypass

	set															; A priori, CRC8 recu egal a celui attendu ...
	lds		REG_TEMP_R16, G_CALC_CRC8
	lds		REG_TEMP_R17, G_DS18B20_BYTES_RESP
	cpse		REG_TEMP_R16, REG_TEMP_R17
	clt															; ... et non CRC8 recu different de celui attendu

	brtc		ds18b20_read_scratchpad_ko
	;rjmp		ds18b20_read_scratchpad_ok
	; Fin: Test du CRC8

ds18b20_read_scratchpad_ok:
	; Construction de la trame 
	lds		REG_TEMP_R17, G_BUS_1_WIRE_FLAGS
	sbrc		REG_TEMP_R17, FLG_DS18B20_FRAMES_IDX
	rcall		build_frame_infos

	ldi		REG_TEMP_R16, 'O'
	rcall		uos_push_1_char_in_fifo_tx_skip
	ldi		REG_TEMP_R16, 'k'
	rcall		uos_push_1_char_in_fifo_tx_skip
	rcall		uos_print_line_feed_skip

	rjmp		ds18b20_read_scratchpad_end

ds18b20_read_scratchpad_ko:
	ldi		REG_TEMP_R16, 'K'
	rcall		uos_push_1_char_in_fifo_tx_skip
	ldi		REG_TEMP_R16, 'o'
	rcall		uos_push_1_char_in_fifo_tx_skip
	rcall		uos_print_line_feed_skip

	;rjmp		ds18b20_read_scratchpad_end

ds18b20_read_scratchpad_end:
	sei
	ret
; ---------

; ---------
; CMD_MATCH_ROM
; ---------
; Match d'un registre ROM de 64 bits depuis [G_DS18B20_BYTES_SEND, ..., (G_DS18B20_BYTES_SEND + 7)]
; => Test avec "0x53 08 22 53 97 80 B5 28 (1st capteur) 'ds18b20_match_rom_1'
;              "0x47 06 22 60 20 BB C8 28 (2nd capteur) 'ds18b20_match_rom_2'
;              "0x2B 06 22 60 43 40 56 28 (3rd capteur) 'ds18b20_match_rom_3'
; ---------
ds18b20_match_rom:
	; Emission de l'index du ROM #N
	push		REG_X_MSB
	push		REG_X_LSB

	; Get the index of ROM in alarm
	ldi		REG_X_MSB, high(G_DS18B20_BYTES_SEND)
	ldi		REG_X_LSB, low(G_DS18B20_BYTES_SEND)
	rcall		ds18b20_get_rom_idx

	; Update index of ROM for build frame
	sts		G_DS18B20_ROM_IDX, REG_TEMP_R16

	push		REG_TEMP_R16
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 'M'
	rcall		uos_push_1_char_in_fifo_tx_skip
	pop		REG_X_LSB
	rcall		uos_print_1_byte_hexa_skip
	rcall		uos_print_line_feed_skip

	pop		REG_TEMP_R16
	pop		REG_X_LSB
	pop		REG_X_MSB
	; Fin: Emission du ROM #N

	rcall		ds18b20_print_rom_send

	; Attente du vidage de la FIFO/Tx
	rcall		uos_fifo_tx_to_send_sync

	cli

	ldi		REG_TEMP_R16, DS18B20_CMD_MATCH_ROM
	rcall		ds18b20_write_8_bits_command

	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_SEND + 8)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_SEND + 8)

	ld			REG_TEMP_R16, -Y
	rcall		ds18b20_write_8_bits_command
	ld			REG_TEMP_R16, -Y
	rcall		ds18b20_write_8_bits_command
	ld			REG_TEMP_R16, -Y
	rcall		ds18b20_write_8_bits_command
	ld			REG_TEMP_R16, -Y
	rcall		ds18b20_write_8_bits_command
	ld			REG_TEMP_R16, -Y
	rcall		ds18b20_write_8_bits_command
	ld			REG_TEMP_R16, -Y
	rcall		ds18b20_write_8_bits_command
	ld			REG_TEMP_R16, -Y
	rcall		ds18b20_write_8_bits_command
	ld			REG_TEMP_R16, -Y
	rcall		ds18b20_write_8_bits_command

	sei

	ret
; ---------

; ---------
; CMD_SEARCH_ROM
; ---------
; ds18b20_search_rom: Recherche des registres ROM sur le bus
; ---------
; - Chaque passe consiste a remplacer chaque bit "inconnu" (retour 0x00 des 2 'ds18b20_read_bit')
;   par celui du pattern (G_DS18B20_PATTERN) initialise a 0x00 et qui sera incremente
;   a la fin de la passe a l'issue de laquelle un ROM a ete identifie avec ses 64 bits
;
; - Le ROM est conserve apres sa verification @ CRC
;
; - Exemple de ROM determines avec 'G_DS18B20_NBR_BITS_RETRY' egal a 8
;   car apres tests, il est constates qu'il y a au plus 3 bits inconnues a discriminer
;   => Justification de l'initialisation a '((1 << 3) - 1)'
;
; 0x4706226020BBC828 1st capteur DS18B20 avec le pattern initial b0000 0000 -> 2 bits inconnus
;                                                                b0000 0100
; 0xCB062260451C7328 2rd capteur DS18B20 avec le pattern initial b0000 0111 -> 2 bits inconnus
;                                                                b0000 0011
; 0x2B06226043405628 3rd capteur DS18B20 avec le pattern initial b0000 0110 -> 2 bits inconnus
;                                                                b0000 0010
; 0x530822539780B528 4th capteur DS18B20 avec le pattern initial b0000 0101 -> 3 bits inconnus
; 0xE4062260238BB928 5th capteur DS18B20 avec le pattern initial b0000 0001 -> 3 bits inconnus
;
; ---------
ds18b20_search_rom:
	; Initilisation pour x passes durant lesquelles un meme ROM peut etre trouve plusieurs fois
	ldi		REG_TEMP_R16, ((1 << 3) - 1)				; 8 passes + Pattern initial b0000 0111
	sts		G_DS18B20_NBR_BITS_RETRY, REG_TEMP_R16
	sts		G_DS18B20_PATTERN, REG_TEMP_R16

	clr		REG_TEMP_R16
	sts		G_DS18B20_NBR_ROM, REG_TEMP_R16
	sts		G_DS18B20_ROM_IDX_WRK, REG_TEMP_R16
	sts		G_DS18B20_NBR_BITS_0_1_MAX, REG_TEMP_R16

	; Effacement des ROM a rechercher
	rcall		ds18b20_clear_rom	

	lds		REG_TEMP_R16, G_DS18B20_NBR_ROM_MAX
	tst		REG_TEMP_R16
	brne		ds18b20_search_rom_cont_d

	ldi		REG_TEMP_R16, 8
	sts		G_DS18B20_NBR_ROM_MAX, REG_TEMP_R16

ds18b20_search_rom_cont_d:
	clr		REG_TEMP_R16
	sts		G_DS18B20_NBR_BITS_0_1, REG_TEMP_R16

	ldi		REG_TEMP_R16, 'P'
	call		uos_push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_PATTERN
	rcall		uos_print_1_byte_hexa_skip

	rcall		uos_print_line_feed_skip
	call		uos_fifo_tx_to_send_sync

	; Reset
	rcall		ds18b20_reset

	cli

	ldi		REG_TEMP_R16, DS18B20_CMD_SEARCH_ROM
	rcall		ds18b20_write_8_bits_command

	ldi		REG_TEMP_R18, 64		; Searching the ROM register

ds18b20_search_rom_loop:
	clr		REG_TEMP_R17

	rcall		ds18b20_read_bit

	brcc		ds18b20_search_rom_loop_a
	sbr		REG_TEMP_R17, MSK_BIT0

ds18b20_search_rom_loop_a:
	ldi		REG_TEMP_R19, 16
	rcall		ds18b20_shift_right_resp

	rcall		ds18b20_read_bit

	brcc		ds18b20_search_rom_loop_b
	sbr		REG_TEMP_R17, MSK_BIT1

ds18b20_search_rom_loop_b:
	ldi		REG_TEMP_R19, 16
	rcall		ds18b20_shift_right_resp

	cpi		REG_TEMP_R17, 0x00		; Presence de '0' et de '1'
	brne		ds18b20_search_rom_loop_c

	; Comptabilisation du nombre de bits inconnus
	lds		REG_TEMP_R19, G_DS18B20_NBR_BITS_0_1
	inc		REG_TEMP_R19
	sts		G_DS18B20_NBR_BITS_0_1, REG_TEMP_R19

	lds		REG_TEMP_R20, G_DS18B20_NBR_BITS_0_1_MAX
	cp			REG_TEMP_R19, REG_TEMP_R20
	brmi		ds18b20_search_rom_loop_d

	sts		G_DS18B20_NBR_BITS_0_1_MAX, REG_TEMP_R19

ds18b20_search_rom_loop_d:

	; Ecriture de 'G_DS18B20_PATTERN<0>'
	lds		REG_TEMP_R19, G_DS18B20_PATTERN
	lsr		REG_TEMP_R19
	sts		G_DS18B20_PATTERN, REG_TEMP_R19

	brcc		ds18b20_search_rom_loop_0
	rjmp		ds18b20_search_rom_loop_1

ds18b20_search_rom_loop_c:
	cpi		REG_TEMP_R17, 0x02		; Presence de '0' uniquement
	breq		ds18b20_search_rom_loop_0

	cpi		REG_TEMP_R17, 0x01		; Presence de '1' uniquement
	breq		ds18b20_search_rom_loop_1

	cpi		REG_TEMP_R17, 0x03		; No capteur
	breq		ds18b20_search_rom_no_device
	rjmp		ds18b20_search_rom_end

ds18b20_search_rom_loop_0:
	clc
	ldi		REG_TEMP_R19, 8
	rcall		ds18b20_shift_right_rom

	clc
	rjmp		ds18b20_search_rom_loop_01

ds18b20_search_rom_loop_1:
	sec
	ldi		REG_TEMP_R19, 8
	rcall		ds18b20_shift_right_rom

	sec
	;rjmp		ds18b20_search_rom_loop_01

ds18b20_search_rom_loop_01:

	rcall		ds18b20_write_bit	

	dec		REG_TEMP_R18
	brne		ds18b20_search_rom_loop

	rjmp		ds18b20_search_rom_end

ds18b20_search_rom_no_device:
	ldi		REG_TEMP_R16, 'N'
	call		uos_push_1_char_in_fifo_tx_skip
	;rjmp		ds18b20_search_rom_abort

ds18b20_search_rom_abort:
	sei

	ldi		REG_X_LSB, 64
	sub		REG_X_LSB, REG_TEMP_R18
	rcall		uos_print_1_byte_hexa_skip

	mov		REG_X_LSB, REG_TEMP_R17
	rcall		uos_print_1_byte_hexa_skip
	rcall		uos_print_line_feed_skip

	rjmp		ds18b20_search_rom_rtn

ds18b20_search_rom_end:
	sei

	ldi		REG_TEMP_R18, 8
	rcall		ds18b20_print_response

	ldi		REG_TEMP_R18, 8
	rcall		ds18b20_print_rom

	; Copy of ROM found in 'G_DS18B20_BYTES_ROM' to 'G_DS18B20_ROM_0' @ 'G_DS18B20_ROM_IDX'
	; => 'REG_TEMP_R16' contient le rang du CRC du ROM trouve ou 0xff si pas trouve
	rcall		ds18b20_compare_rom

	cpi		REG_TEMP_R16, 0xff
	brne		ds18b20_search_rom_found

	rcall		ds18b20_copy_rom

	lds		REG_TEMP_R16, G_DS18B20_NBR_ROM
	inc		REG_TEMP_R16
	sts		G_DS18B20_NBR_ROM, REG_TEMP_R16

	lds		REG_TEMP_R17, G_DS18B20_NBR_ROM_MAX
	cp			REG_TEMP_R16, REG_TEMP_R17
	brpl		ds18b20_search_rom_rtn

ds18b20_search_rom_found:
	ldi		REG_TEMP_R16, 'N'
	call		uos_push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_NBR_BITS_RETRY
	rcall		uos_print_1_byte_hexa_skip

	ldi		REG_TEMP_R16, '?'
	call		uos_push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_NBR_BITS_0_1
	rcall		uos_print_1_byte_hexa_skip

	rcall		uos_print_line_feed_skip

	call		uos_fifo_tx_to_send_sync

	lds		REG_TEMP_R19, G_DS18B20_NBR_BITS_RETRY
	dec		REG_TEMP_R19
	sts		G_DS18B20_NBR_BITS_RETRY, REG_TEMP_R19
	cpi		REG_TEMP_R19, 0xFF
	breq		ds18b20_search_rom_rtn		

	sts		G_DS18B20_PATTERN, REG_TEMP_R19

	rjmp		ds18b20_search_rom_cont_d

ds18b20_search_rom_rtn:

	ret
; ---------

; ---------
; CMD_WRITE_SCRATCHPAD
; ---------
ds18b20_write_scratchpad:
	cli

	push		REG_TEMP_R18
	push		REG_TEMP_R17
	push		REG_TEMP_R16

	ldi		REG_TEMP_R16, DS18B20_CMD_WRITE_SCRATCHPAD
	rcall		ds18b20_write_8_bits_command

	pop		REG_TEMP_R16
	rcall		ds18b20_write_8_bits_command

	pop		REG_TEMP_R17
	mov		REG_TEMP_R16, REG_TEMP_R17
	rcall		ds18b20_write_8_bits_command

	pop		REG_TEMP_R18
	mov		REG_TEMP_R16, REG_TEMP_R18
	rcall		ds18b20_write_8_bits_command

	sei

	ret
; ---------

; ---------
; CMD_COPY_SCRATCHPAD
; ---------
ds18b20_copy_scratchpad:
	cli
	ldi		REG_TEMP_R16, DS18B20_CMD_COPY_SCRATCHPAD
	rcall		ds18b20_write_8_bits_command
	sei

	ret
; ---------

; ---------
; CMD_SEARCH_ALARM
; ---------
; Recherche des capteurs en "alarme"; cad si la temperature mesuree
; est inferieure a TL ou superieure a TH configurees
; ---------
ds18b20_search_alarm:
	; Initilisation pour x passes durant lesquelles un meme ROM peut etre trouve plusieurs fois
	ldi		REG_TEMP_R16, ((1 << 3) - 1)				; 8 passes + Pattern initial b0000 0111
	sts		G_DS18B20_ALR_NBR_BITS_RETRY, REG_TEMP_R16
	sts		G_DS18B20_ALR_PATTERN, REG_TEMP_R16

	clr		REG_TEMP_R16
	sts		G_DS18B20_ALR_NBR_ROM, REG_TEMP_R16
	sts		G_DS18B20_ALR_ROM_IDX_WRK, REG_TEMP_R16
	sts		G_DS18B20_ALR_NBR_BITS_0_1_MAX, REG_TEMP_R16
	sts		G_DS18B20_IN_ALARM, REG_TEMP_R16

	; Effacement des ROM a rechercher
	rcall		ds18b20_clear_alr	

	lds		REG_TEMP_R16, G_DS18B20_ALR_NBR_ROM_MAX
	tst		REG_TEMP_R16
	brne		ds18b20_search_alr_cont_d

	ldi		REG_TEMP_R16, 8
	sts		G_DS18B20_ALR_NBR_ROM_MAX, REG_TEMP_R16

ds18b20_search_alr_cont_d:
	clr		REG_TEMP_R16
	sts		G_DS18B20_ALR_NBR_BITS_0_1, REG_TEMP_R16

	ldi		REG_TEMP_R16, 'P'
	call		uos_push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_ALR_PATTERN
	rcall		uos_print_1_byte_hexa_skip

	rcall		uos_print_line_feed_skip
	call		uos_fifo_tx_to_send_sync

	; Reset
	rcall		ds18b20_reset

	cli

	ldi		REG_TEMP_R16, DS18B20_CMD_SEARCH_ALARM
	rcall		ds18b20_write_8_bits_command

	ldi		REG_TEMP_R18, 64		; Searching the ROM register

ds18b20_search_alr_loop:
	clr		REG_TEMP_R17

	rcall		ds18b20_read_bit

	brcc		ds18b20_search_alr_loop_a
	sbr		REG_TEMP_R17, MSK_BIT0

ds18b20_search_alr_loop_a:
	ldi		REG_TEMP_R19, 16
	rcall		ds18b20_shift_right_resp

	rcall		ds18b20_read_bit

	brcc		ds18b20_search_alr_loop_b
	sbr		REG_TEMP_R17, MSK_BIT1

ds18b20_search_alr_loop_b:
	ldi		REG_TEMP_R19, 16
	rcall		ds18b20_shift_right_resp

	cpi		REG_TEMP_R17, 0x00		; Presence de '0' et de '1'
	brne		ds18b20_search_alr_loop_c

	; Comptabilisation du nombre de bits inconnus
	lds		REG_TEMP_R19, G_DS18B20_ALR_NBR_BITS_0_1
	inc		REG_TEMP_R19
	sts		G_DS18B20_ALR_NBR_BITS_0_1, REG_TEMP_R19

	lds		REG_TEMP_R20, G_DS18B20_ALR_NBR_BITS_0_1_MAX
	cp			REG_TEMP_R19, REG_TEMP_R20
	brmi		ds18b20_search_alr_loop_d

	sts		G_DS18B20_ALR_NBR_BITS_0_1_MAX, REG_TEMP_R19

ds18b20_search_alr_loop_d:

	; Ecriture de 'G_DS18B20_ALR_PATTERN<0>'
	lds		REG_TEMP_R19, G_DS18B20_ALR_PATTERN
	lsr		REG_TEMP_R19
	sts		G_DS18B20_ALR_PATTERN, REG_TEMP_R19

	brcc		ds18b20_search_alr_loop_0
	rjmp		ds18b20_search_alr_loop_1

ds18b20_search_alr_loop_c:
	cpi		REG_TEMP_R17, 0x02		; Presence de '0' uniquement
	breq		ds18b20_search_alr_loop_0

	cpi		REG_TEMP_R17, 0x01		; Presence de '1' uniquement
	breq		ds18b20_search_alr_loop_1

	cpi		REG_TEMP_R17, 0x03		; No capteur
	breq		ds18b20_search_alr_no_device
	rjmp		ds18b20_search_alr_end

ds18b20_search_alr_loop_0:
	clc
	ldi		REG_TEMP_R19, 8
	rcall		ds18b20_shift_right_rom

	clc
	rjmp		ds18b20_search_alr_loop_01

ds18b20_search_alr_loop_1:
	sec
	ldi		REG_TEMP_R19, 8
	rcall		ds18b20_shift_right_rom

	sec
	;rjmp		ds18b20_search_alr_loop_01

ds18b20_search_alr_loop_01:

	rcall		ds18b20_write_bit	

	dec		REG_TEMP_R18
	brne		ds18b20_search_alr_loop

	rjmp		ds18b20_search_alr_end

ds18b20_search_alr_no_device:
	ldi		REG_TEMP_R16, 'N'
	call		uos_push_1_char_in_fifo_tx_skip
	;rjmp		ds18b20_search_alr_abort

ds18b20_search_alr_abort:
	sei

	ldi		REG_X_LSB, 64
	sub		REG_X_LSB, REG_TEMP_R18
	rcall		uos_print_1_byte_hexa_skip

	mov		REG_X_LSB, REG_TEMP_R17
	rcall		uos_print_1_byte_hexa_skip
	rcall		uos_print_line_feed_skip

	rjmp		ds18b20_search_alr_rtn

ds18b20_search_alr_end:
	sei

	ldi		REG_TEMP_R18, 8
	rcall		ds18b20_print_response

	ldi		REG_TEMP_R18, 8
	rcall		ds18b20_print_rom

	; Copy of ROM found in 'G_DS18B20_BYTES_ROM' to 'G_DS18B20_ALR_ROM_0' @ 'G_DS18B20_ALR_ROM_IDX'
	; => 'REG_TEMP_R16' contient le rang du CRC du ROM trouve ou 0xff si pas trouve
	rcall		ds18b20_compare_alr_rom

	cpi		REG_TEMP_R16, 0xff
	brne		ds18b20_search_alr_found

	; Emission de l'index du ROM #N en alarme
	push		REG_X_MSB
	push		REG_X_LSB

	; Get the index of ROM in alarm
	ldi		REG_X_MSB, high(G_DS18B20_BYTES_ROM)
	ldi		REG_X_LSB, low(G_DS18B20_BYTES_ROM)
	rcall		ds18b20_get_rom_idx

	push		REG_TEMP_R16
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, '#'
	call		uos_push_1_char_in_fifo_tx_skip
	pop		REG_X_LSB
	rcall		uos_print_1_byte_hexa_skip
	rcall		uos_print_line_feed_skip

	pop		REG_TEMP_R16
	pop		REG_X_LSB
	pop		REG_X_MSB
	; Fin: Emission du ROM #N en alarme

	; Cas ou le capteur #N n'est pas trouve dans la table des ROM detectes
	; => Abort a la 1st occurence
	cpi		REG_TEMP_R16, 0xff
	breq		ds18b20_search_alr_rtn

	; Update 'G_DS18B20_IN_ALARM' @ 'REG_TEMP_R16'
	ldi		REG_Z_MSB, ((text_msk_table << 1) / 256)
	ldi		REG_Z_LSB, ((text_msk_table << 1) % 256)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_Z_MSB, REG_TEMP_R17
	lpm		REG_TEMP_R18, Z
	lds		REG_TEMP_R17, G_DS18B20_IN_ALARM
	or			REG_TEMP_R17, REG_TEMP_R18
	sts		G_DS18B20_IN_ALARM, REG_TEMP_R17
	; End: Update 'G_DS18B20_IN_ALARM' @ 'REG_TEMP_R16'

	rcall		ds18b20_alr_copy_rom

	lds		REG_TEMP_R16, G_DS18B20_ALR_NBR_ROM
	inc		REG_TEMP_R16
	sts		G_DS18B20_ALR_NBR_ROM, REG_TEMP_R16

	lds		REG_TEMP_R17, G_DS18B20_ALR_NBR_ROM_MAX
	cp			REG_TEMP_R16, REG_TEMP_R17
	brpl		ds18b20_search_alr_rtn

ds18b20_search_alr_found:
	ldi		REG_TEMP_R16, 'N'
	call		uos_push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_ALR_NBR_BITS_RETRY
	rcall		uos_print_1_byte_hexa_skip

	ldi		REG_TEMP_R16, '?'
	call		uos_push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_ALR_NBR_BITS_0_1
	rcall		uos_print_1_byte_hexa_skip

	rcall		uos_print_line_feed_skip

	call		uos_fifo_tx_to_send_sync

	lds		REG_TEMP_R19, G_DS18B20_ALR_NBR_BITS_RETRY
	dec		REG_TEMP_R19
	sts		G_DS18B20_ALR_NBR_BITS_RETRY, REG_TEMP_R19
	cpi		REG_TEMP_R19, 0xFF
	breq		ds18b20_search_alr_rtn		

	sts		G_DS18B20_ALR_PATTERN, REG_TEMP_R19

	rjmp		ds18b20_search_alr_cont_d

ds18b20_search_alr_rtn:
	ret
; ---------

; ---------
; Gestion du "scratchpad"
; ---------
; Code DS18B20 pour l'ecriture du 'scratchpad' #x et dans l'eeprom
; ---------
ds18b20_write_scratchpad_x:
	rcall		ds18b20_reset

	lds		REG_TEMP_R16, (G_FRAME_ALL_INFOS + 0)		; Recuperation de l'Id du capteur
	rcall		ds18b20_match_rom_x

	lds		REG_TEMP_R17, (G_FRAME_ALL_INFOS + 1)		; Recuperation Tl
	lds		REG_TEMP_R16, (G_FRAME_ALL_INFOS + 2)		; Recuperation Th
	lds		REG_TEMP_R18, (G_FRAME_ALL_INFOS + 3)		; Recuperation Resolution

	rjmp		ds18b20_write_scratchpad
; ---------

; ---------
ds18b20_copy_scratchpad_x:
	rcall		ds18b20_reset

	lds		REG_TEMP_R16, (G_FRAME_ALL_INFOS + 0)		; Recuperation de l'Id du capteur
	rcall		ds18b20_match_rom_x

	rjmp		ds18b20_copy_scratchpad
; ---------
; Fin: Gestion du "scratchpad"
; ---------

; ---------
ds18b20_match_rom_x:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_SEND)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_SEND)

	rcall		ds18b20_get_rom_detected_bypass	
	brtc		ds18b20_match_rom_x_not_detect

ds18b20_match_rom_x_cont_d:
	ldi		REG_TEMP_R16, 8

ds18b20_match_rom_x_loop:
	ld			REG_TEMP_R17, X+
	st			Y+, REG_TEMP_R17
	dec		REG_TEMP_R16
	brne		ds18b20_match_rom_x_loop

	rjmp		ds18b20_match_rom

ds18b20_match_rom_x_not_detect:
	; ROM non detecte
   ldi      REG_TEMP_R17, '?'
	rcall		uos_print_mark_skip

	lds		REG_TEMP_R16, G_DS18B20_FLAGS
	sbr		REG_TEMP_R16, FLG_TEST_CONFIG_ERROR_MSK
	sts		G_DS18B20_FLAGS, REG_TEMP_R16

	ret
; ---------

; End of file

