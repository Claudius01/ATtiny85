; "$Id: ATtiny85_uOS+DS18B20.asm,v 1.3 2025/11/26 17:33:27 administrateur Exp $"

; Programme de gestion des capteurs DS18B20
;
; A la mise sous tension du DS18B20, les 2 seuils Th et Tl sont respectivement a 70 et 75 degres
; et la temperature a 85 degres tant qu'une commande 'DS18B20_CMD_CONVERT_T' n'a pas ete emise
; => En concequence, le capteur presente une alarme dans le cas d'une temperature ambiante de 20 degres
;
; Remarque: L'alarme est presentee des lors que Tc <= Tl ou Tc >= Th avec une precision de 1 degre car
;           les 2 seuils Th et Tl sont definis au degres pres

.include		"ATtiny85_uOS.asm"
.include		"ATtiny85_uOS+DS18B20.h"

.include		"ATtiny85_uOS+DS18B20_Timers.asm"
.include		"ATtiny85_uOS+DS18B20_Commands.asm"
.include		"ATtiny85_uOS+DS18B20_1_Wire.asm"

.cseg

; ---------
; Raz des 16 bytes [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 15)]
;  et des 16 bytes [G_DS18B20_BYTES_SEND, ..., (G_DS18B20_BYTES_SEND + 15)]
; ---------
ds18b20_clear:
; ---------
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_RESP)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_RESP)
	ldi		REG_TEMP_R18, 16
	clr		REG_TEMP_R16

ds18b20_clear_loop:
	st			Y+, REG_TEMP_R16
	dec		REG_TEMP_R18
	brne		ds18b20_clear_loop

	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_SEND)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_SEND)
	ldi		REG_TEMP_R18, 16
	clr		REG_TEMP_R16

ds18b20_clear_loop_2:
	st			Y+, REG_TEMP_R16
	dec		REG_TEMP_R18
	brne		ds18b20_clear_loop_2

	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_ROM)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_ROM)
	ldi		REG_TEMP_R18, 8
	clr		REG_TEMP_R16

ds18b20_clear_loop_3:
	st			Y+, REG_TEMP_R16
	dec		REG_TEMP_R18
	brne		ds18b20_clear_loop_3

	ret
; ---------

; ---------
; Propagation de la Carry et decalage d'un bit a droite
; sur les 'REG_TEMP_R19' bytes a partir de 'G_DS18B20_BYTES_RESP'
; ou a partir de 'G_DS18B20_BYTES_ROM'
; ---------
ds18b20_shift_right_resp:
; ---------
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_RESP)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_RESP)
	rjmp		ds18b20_shift_right

ds18b20_shift_right_rom:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_ROM)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_ROM)
	rjmp		ds18b20_shift_right

ds18b20_shift_right:

	push		REG_TEMP_R19

ds18b20_shift_right_resp_loop:
#if USE_DS18B20_TRACE
	in			REG_SAVE_SREG, SREG				; Save SREG

	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		print_2_bytes_hexa_skip
#endif

	ld			REG_TEMP_R16, Y

#if USE_DS18B20_TRACE
	mov		REG_X_LSB, REG_TEMP_R16
	push		REG_TEMP_R16
	rcall		print_1_byte_hexa_skip
	rcall		print_line_feed_skip
	pop		REG_TEMP_R16
	out		SREG, REG_SAVE_SREG				; Restore SREG
#endif

	ror		REG_TEMP_R16
	st			Y+, REG_TEMP_R16	

	dec		REG_TEMP_R19
	brne		ds18b20_shift_right_resp_loop

	pop		REG_TEMP_R19
	ret
; ---------

; ---------
; Propagation de la Carry et decalage d'un bit a droite
; sur les 'REG_TEMP_R19' bytes a partir de 'G_DS18B20_BYTES_SEND'
; ---------
ds18b20_shift_right_send:
; ---------
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_SEND)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_SEND)

	push		REG_TEMP_R19

ds18b20_shift_right_send_loop:
	ld			REG_TEMP_R16, Y

	ror		REG_TEMP_R16
	st			Y+, REG_TEMP_R16	

	dec		REG_TEMP_R19
	brne		ds18b20_shift_right_send_loop

	pop		REG_TEMP_R19
	ret
; ---------

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
; Conversion de la temperature disponible dans [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 7)]
; ---------
ds18b20_convert_t:
	cli

	ldi		REG_TEMP_R16, DS18B20_CMD_CONVERT_T
	rcall		ds18b20_write_8_bits_command
	rcall		ds18b20_read_response_72_bits

	ldi		REG_TEMP_R16, 'C'
	rcall		push_1_char_in_fifo_tx_skip
	ldi		REG_TEMP_R18, 5
	rcall		ds18b20_print_response

	sei
	ret
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
	rcall		push_1_char_in_fifo_tx_skip
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
	rjmp		ds18b20_read_scratchpad_ok
	; Fin: Test du CRC8

ds18b20_read_scratchpad_ok:
	; Construction de la trame 
	lds		REG_TEMP_R17, G_BUS_1_WIRE_FLAGS
	sbrc		REG_TEMP_R17, FLG_DS18B20_FRAMES_IDX
	rcall		build_frame_infos

	ldi		REG_TEMP_R16, 'O'
	rcall		push_1_char_in_fifo_tx_skip
	ldi		REG_TEMP_R16, 'k'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip

	rjmp		ds18b20_read_scratchpad_end

ds18b20_read_scratchpad_ko:
	ldi		REG_TEMP_R16, 'K'
	rcall		push_1_char_in_fifo_tx_skip
	ldi		REG_TEMP_R16, 'o'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip

	rjmp		ds18b20_read_scratchpad_end

ds18b20_read_scratchpad_end:
	sei
	ret
; ---------

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
	rcall		push_1_char_in_fifo_tx_skip
	pop		REG_X_LSB
	rcall		print_1_byte_hexa_skip
	rcall		print_line_feed_skip

	pop		REG_TEMP_R16
	pop		REG_X_LSB
	pop		REG_X_MSB
	; Fin: Emission du ROM #N

	rcall		ds18b20_print_rom_send

	; Attente du vidage de la FIFO/Tx
	rcall		fifo_tx_to_send_sync

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
ds18b20_reset:
	rcall		ds18b20_clear

	cli

	sbi		PORTB, IDX_BIT_LED_GREEN			; Extinction Led GREEN
	cbi		PORTB, IDX_BIT_1_WIRE

	ldi		REG_TEMP_R17, 1						; Spare for awaiting > 255mS

ds18b20_reset_loop_1:
	ldi		REG_TEMP_R16, 100						; Wait 1mS

ds18b20_reset_loop_2:
	rcall		delay_10uS
	dec		REG_TEMP_R16
	brne		ds18b20_reset_loop_2

	dec		REG_TEMP_R17
	brne		ds18b20_reset_loop_1

	sbi		PORTB, IDX_BIT_1_WIRE

	; Presence detect ?
	cbi		DDRB, IDX_BIT_1_WIRE					; <PORTB<2> en entree
	rcall		delay_65uS

	ldi		REG_TEMP_R17, '0'
	sbic		PINB, IDX_BIT_1_WIRE
	ldi		REG_TEMP_R17, '1'						; ... et non <PORTB<2> a 1

	ldi		REG_TEMP_R18, 100						; Wait 1mS

ds18b20_reset_loop_3:
	rcall		delay_10uS
	dec		REG_TEMP_R18
	brne		ds18b20_reset_loop_3

	sbi		DDRB, IDX_BIT_1_WIRE					; <PORTB<2> en sortie

	ldi		REG_TEMP_R16, 'P'
	rcall		push_1_char_in_fifo_tx_skip
	
	mov		REG_TEMP_R16, REG_TEMP_R17
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip
	; End: Presence detect ?

	sei
	ret
; ---------

; ---------
; Recherche des registres ROM sur le bus
;
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
	rcall		push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_PATTERN
	rcall		print_1_byte_hexa_skip

	rcall		print_line_feed_skip
	rcall		fifo_tx_to_send_sync

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
	rjmp		ds18b20_search_rom_loop_01

ds18b20_search_rom_loop_01:

	rcall		ds18b20_write_bit	

	dec		REG_TEMP_R18
	brne		ds18b20_search_rom_loop

	rjmp		ds18b20_search_rom_end

ds18b20_search_rom_no_device:
	ldi		REG_TEMP_R16, 'N'
	rcall		push_1_char_in_fifo_tx_skip
	rjmp		ds18b20_search_rom_abort

ds18b20_search_rom_abort:
	sei

	ldi		REG_X_LSB, 64
	sub		REG_X_LSB, REG_TEMP_R18
	rcall		print_1_byte_hexa_skip

	mov		REG_X_LSB, REG_TEMP_R17
	rcall		print_1_byte_hexa_skip
	rcall		print_line_feed_skip

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
	rcall		push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_NBR_BITS_RETRY
	rcall		print_1_byte_hexa_skip

	ldi		REG_TEMP_R16, '?'
	rcall		push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_NBR_BITS_0_1
	rcall		print_1_byte_hexa_skip

	rcall		print_line_feed_skip

	rcall		fifo_tx_to_send_sync

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
; Emission d'une commande de 8 bits contenue dans 'REG_TEMP_R16'
; => LSB en tete
; ---------
ds18b20_write_8_bits_command:
	ldi		REG_TEMP_R18, 8

ds18b20_write_8_bits_command_loop:
	ror		REG_TEMP_R16
	rcall		ds18b20_write_bit

	dec		REG_TEMP_R18
	brne		ds18b20_write_8_bits_command_loop

	ret
; ---------

; ---------
; Lecture de la reponse sur 64 bits disponible dans [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 7)]
; Lecture de la reponse sur 72 bits disponible dans [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 8)]
; ---------
ds18b20_read_response_72_bits:
	ldi		REG_TEMP_R19, 9
	ldi		REG_TEMP_R18, 72
	rjmp		ds18b20_read_response_x_bits_loop

ds18b20_read_response_64_bits:
	ldi		REG_TEMP_R19, 8
	ldi		REG_TEMP_R18, 64

ds18b20_read_response_x_bits_loop:
	rcall		ds18b20_read_bit

	rcall		ds18b20_shift_right_resp

	dec		REG_TEMP_R18
	brne		ds18b20_read_response_x_bits_loop

	ret
; ---------

; ---------
ds18b20_print_response:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_RESP)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_RESP)

ds18b20_print_response_loop:
	ld			REG_X_MSB, Y+
	ld			REG_X_LSB, Y+
	rcall		print_2_bytes_hexa_skip

	dec		REG_TEMP_R18
	brne		ds18b20_print_response_loop

	rcall		print_line_feed_skip
	ret
; ---------

; ---------
ds18b20_print_rom_send:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_SEND)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_SEND)

	ldi		REG_TEMP_R18, 4

ds18b20_print_rom_send_loop:
	ld			REG_X_MSB, Y+
	ld			REG_X_LSB, Y+
	rcall		print_2_bytes_hexa_skip

	dec		REG_TEMP_R18
	brne		ds18b20_print_rom_send_loop

	rcall		print_line_feed_skip

	ret
; ---------

; ---------
ds18b20_print_rom:
	ldi		REG_TEMP_R16, 'R'
	rcall		push_1_char_in_fifo_tx_skip

	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_ROM)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_ROM)

	ldi		REG_TEMP_R18, 4

ds18b20_print_rom_loop:
	ld			REG_X_MSB, Y+
	ld			REG_X_LSB, Y+
	rcall		print_2_bytes_hexa_skip

	dec		REG_TEMP_R18
	brne		ds18b20_print_rom_loop

	rcall		print_line_feed_skip

	ret
; ---------

; ---------
; Clear of ROM table in 'G_DS18B20_BYTES_ROM' to 'G_DS18B20_ROM_0', ...
; ---------
ds18b20_clear_rom:
	ldi		REG_Z_MSB, high(G_DS18B20_ROM_0)
	ldi		REG_Z_LSB, low(G_DS18B20_ROM_0)

	clr		REG_TEMP_R16

	; Balayage des 8 x 8 bytes des ROM a rechercher
	ldi		REG_TEMP_R18, (8 * 8)

ds18b20_clear_rom_loop:
	st			Z+, REG_TEMP_R16

	dec		REG_TEMP_R18
	brne		ds18b20_clear_rom_loop

	ret
; ---------

; ---------
; Copy of ROM found in 'G_DS18B20_BYTES_ROM' to 'G_DS18B20_ROM_0' @ 'G_DS18B20_ROM_IDX'
; ---------
ds18b20_copy_rom:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_ROM)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_ROM)

	lds		REG_TEMP_R16, G_DS18B20_ROM_IDX_WRK
	ldi		REG_Z_MSB, high(G_DS18B20_ROM_0)
	ldi		REG_Z_LSB, low(G_DS18B20_ROM_0)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_Z_MSB, REG_TEMP_R17

	; Preparation prochaine copie
	ldi		REG_TEMP_R18, 8
	add		REG_TEMP_R16, REG_TEMP_R18
	sts		G_DS18B20_ROM_IDX_WRK, REG_TEMP_R16

ds18b20_copy_rom_loop:
	ld			REG_TEMP_R16, Y+
	st			Z+, REG_TEMP_R16

	dec		REG_TEMP_R18
	brne		ds18b20_copy_rom_loop

	ret
; ---------

; ---------
; Compare of ROM found in 'G_DS18B20_BYTES_ROM' with all from ['G_DS18B20_ROM_0', ..., 'G_DS18B20_ROM_7']
;
; Remarque: Seul le test du CRC8 est effectue
;           On suppose qu'il n'y pas 2 ROM differents avec le meme CRC8 valide
;
; => Retour:
;    - 0xff si "Non trouve"
;    - L'index [0, 8, 16, ...] si "trouve"
; ---------
ds18b20_compare_rom:
	ldi		REG_Y_MSB, high(G_DS18B20_ROM_0)
	ldi		REG_Y_LSB, low(G_DS18B20_ROM_0)

	ldi		REG_TEMP_R16, -8		; Index du CRC du n-ieme ROM (0, 8, 16, etc.)

ds18b20_compare_rom_loop:
	subi		REG_TEMP_R16, -8		; 'REG_TEMP_R16' += 8

	; Reinit 'Y' car 'REG_TEMP_R16' l'adresse a tester est ('Y' + 'REG_TEMP_R16')
	ldi		REG_Y_MSB, high(G_DS18B20_ROM_0)
	ldi		REG_Y_LSB, low(G_DS18B20_ROM_0)

	add		REG_Y_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_Y_MSB, REG_TEMP_R17

	lds		REG_TEMP_R18, (G_DS18B20_BYTES_ROM + 7)
	ldd		REG_TEMP_R19, Y+7
	cpse		REG_TEMP_R18, REG_TEMP_R19			; Famille differente ?
	rjmp		ds18b20_compare_rom_not_found		; Non

	sts		G_DS1820_FAMILLE, REG_TEMP_R18	; Update for build frame

	lds		REG_TEMP_R18, G_DS18B20_BYTES_ROM
	ld			REG_TEMP_R19, Y
	cpse		REG_TEMP_R18, REG_TEMP_R19			; CRC different ?
	rjmp		ds18b20_compare_rom_not_found		; Non

ds18b20_compare_rom_found:
	push		REG_TEMP_R16
	mov		REG_X_LSB, REG_TEMP_R16
	rcall		print_1_byte_hexa_skip

	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		print_2_bytes_hexa_skip

	ldi		REG_TEMP_R16, 'F'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip
	pop		REG_TEMP_R16

	rjmp		ds18b20_compare_rom_ret

ds18b20_compare_rom_not_found:
	; Test du CRC8 pour un nouveau ROM non trouve
	push		REG_TEMP_R16
	push		REG_Y_MSB
	push		REG_Y_LSB
	ldi		REG_TEMP_R16, 8								; 8 bytes pour le calcul sur les ROM
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_ROM)	; Adresse de 'G_DS18B20_BYTES_ROM'
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_ROM)

	clt															; Test du CRC8 avec non prise en compte du 1st byte
	rcall		ds18b20_crc8_bypass

	set															; A priori, CRC8 recu egal a celui attendu ...
	lds		REG_TEMP_R16, G_CALC_CRC8
	lds		REG_TEMP_R17, G_DS18B20_BYTES_ROM
	cpse		REG_TEMP_R16, REG_TEMP_R17
	clt															; ... et non CRC8 recu different de celui attendu

	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_TEMP_R16

	brts		ds18b20_compare_rom_crc8_ok		; CRC8 calcule et egal a celui recu ?

ds18b20_compare_rom_crc8_ko:						; Non
	ldi		REG_TEMP_R16, 'K'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip

	ldi		REG_TEMP_R16, 0						; Force a ROM trouve (retour avec 'REG_TEMP_R16' != 0 ;-)
	rjmp		ds18b20_compare_rom_ret

ds18b20_compare_rom_crc8_ok:						; Oui
	; Fin: Test du CRC8 pour un nouveau ROM non trouve

ds18b20_compare_rom_not_found_save:
	push		REG_TEMP_R16
	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		print_2_bytes_hexa_skip

	ldi		REG_TEMP_R16, 'f'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip
	pop		REG_TEMP_R16

	; Test de depassement de l'index 'REG_TEMP_R16'
	lds		REG_TEMP_R17, G_DS18B20_ROM_IDX_WRK
	cp			REG_TEMP_R16, REG_TEMP_R17
	brmi		ds18b20_compare_rom_loop_cont_d
	rjmp		ds18b20_compare_rom_loop_end

ds18b20_compare_rom_loop_cont_d:
	rjmp		ds18b20_compare_rom_loop

ds18b20_compare_rom_loop_end:
	ldi		REG_TEMP_R16, 0xff

ds18b20_compare_rom_ret:
	ret
; ---------

; ---------
; Clear of ROM table 'G_DS18B20_ALR_ROM_0', ...
; ---------
ds18b20_clear_alr:
	ldi		REG_Z_MSB, high(G_DS18B20_ALR_ROM_0)
	ldi		REG_Z_LSB, low(G_DS18B20_ALR_ROM_0)

	clr		REG_TEMP_R16

	; Balayage des 8 x 8 bytes des ROM a rechercher
	ldi		REG_TEMP_R18, (8 * 8)

ds18b20_clear_alr_loop:
	st			Z+, REG_TEMP_R16

	dec		REG_TEMP_R18
	brne		ds18b20_clear_alr_loop

	ret
; ---------

; ---------
; Copy of ROM found in 'G_DS18B20_BYTES_ROM' to 'G_DS18B20_ALR_ROM_0' @ 'G_DS18B20_ALR_ROM_IDX'
; => Code identique a 'ds18b20_copy_rom' sur les variables 'G_DS18B20_ALR_ROM_X'
;    a la place de 'G_DS18B20_XXX'
; ---------
ds18b20_alr_copy_rom:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_ROM)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_ROM)

	lds		REG_TEMP_R16, G_DS18B20_ALR_ROM_IDX_WRK
	ldi		REG_Z_MSB, high(G_DS18B20_ALR_ROM_0)
	ldi		REG_Z_LSB, low(G_DS18B20_ALR_ROM_0)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_Z_MSB, REG_TEMP_R17

	; Preparation prochaine copie
	ldi		REG_TEMP_R18, 8
	add		REG_TEMP_R16, REG_TEMP_R18
	sts		G_DS18B20_ALR_ROM_IDX_WRK, REG_TEMP_R16

ds18b20_alr_copy_rom_loop:
	ld			REG_TEMP_R16, Y+
	st			Z+, REG_TEMP_R16

	dec		REG_TEMP_R18
	brne		ds18b20_alr_copy_rom_loop

	ret
; ---------

; ---------
; Compare of ROM found in 'G_DS18B20_BYTES_ROM' with all from ['G_DS18B20_ALR_ROM_0', ..., 'G_DS18B20_ALR_ROM_7']
;
; Remarque: Seul le test du CRC8 est effectue 
;           On suppose qu'il n'y pas 2 ROM differents avec le meme CRC8 valide
;
; => Retour:
;    - 0xff si "Non trouve"
;    - L'index [0, 8, 16, ...] si "trouve"
; ---------
ds18b20_compare_alr_rom:
	ldi		REG_Y_MSB, high(G_DS18B20_ALR_ROM_0)
	ldi		REG_Y_LSB, low(G_DS18B20_ALR_ROM_0)

	ldi		REG_TEMP_R16, -8		; Index du CRC du n-ieme ROM (0, 8, 16, etc.)

ds18b20_compare_alr_rom_loop:
	subi		REG_TEMP_R16, -8		; 'REG_TEMP_R16' += 8

	; Reinit 'Y' car 'REG_TEMP_R16' l'adresse a tester est ('Y' + 'REG_TEMP_R16')
	ldi		REG_Y_MSB, high(G_DS18B20_ALR_ROM_0)
	ldi		REG_Y_LSB, low(G_DS18B20_ALR_ROM_0)

	add		REG_Y_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_Y_MSB, REG_TEMP_R17

	lds		REG_TEMP_R18, (G_DS18B20_BYTES_ROM + 7)
	ldd		REG_TEMP_R19, Y+7
	cpse		REG_TEMP_R18, REG_TEMP_R19			; Famille differente ?
	rjmp		ds18b20_compare_alr_rom_not_found		; Non

	lds		REG_TEMP_R18, G_DS18B20_BYTES_ROM
	ld			REG_TEMP_R19, Y
	cpse		REG_TEMP_R18, REG_TEMP_R19			; CRC different ?
	rjmp		ds18b20_compare_alr_rom_not_found		; Non

ds18b20_compare_alr_rom_found:
	push		REG_TEMP_R16
	mov		REG_X_LSB, REG_TEMP_R16
	rcall		print_1_byte_hexa_skip

	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		print_2_bytes_hexa_skip

	ldi		REG_TEMP_R16, 'F'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip
	pop		REG_TEMP_R16

	rjmp		ds18b20_compare_alr_rom_ret

ds18b20_compare_alr_rom_not_found:
	; Test du CRC8 pour un nouveau ROM non trouve
	push		REG_TEMP_R16
	push		REG_Y_MSB
	push		REG_Y_LSB
	ldi		REG_TEMP_R16, 8								; 8 bytes pour le calcul sur les ROM
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_ROM)	; Adresse de 'G_DS18B20_BYTES_ROM'
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_ROM)

	clt															; Test du CRC8 avec non prise en compte du 1st byte
	rcall		ds18b20_crc8_bypass

	set															; A priori, CRC8 recu egal a celui attendu ...
	lds		REG_TEMP_R16, G_CALC_CRC8
	lds		REG_TEMP_R17, G_DS18B20_BYTES_ROM
	cpse		REG_TEMP_R16, REG_TEMP_R17
	clt															; ... et non CRC8 recu different de celui attendu

	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_TEMP_R16

	brts		ds18b20_compare_alr_rom_crc8_ok		; CRC8 calcule et egal a celui recu ?

ds18b20_compare_alr_rom_crc8_ko:						; Non
	ldi		REG_TEMP_R16, 'K'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip

	ldi		REG_TEMP_R16, 0						; Force a ROM trouve (retour avec 'REG_TEMP_R16' != 0 ;-)
	rjmp		ds18b20_compare_alr_rom_ret

ds18b20_compare_alr_rom_crc8_ok:						; Oui
	; Fin: Test du CRC8 pour un nouveau ROM non trouve

ds18b20_compare_alr_rom_not_found_save:
	push		REG_TEMP_R16
	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		print_2_bytes_hexa_skip

	ldi		REG_TEMP_R16, 'f'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_line_feed_skip
	pop		REG_TEMP_R16

	; Test de depassement de l'index 'REG_TEMP_R16'
	lds		REG_TEMP_R17, G_DS18B20_ALR_ROM_IDX_WRK
	cp			REG_TEMP_R16, REG_TEMP_R17
	brmi		ds18b20_compare_alr_rom_loop_cont_d
	rjmp		ds18b20_compare_alr_rom_loop_end

ds18b20_compare_alr_rom_loop_cont_d:
	rjmp		ds18b20_compare_alr_rom_loop

ds18b20_compare_alr_rom_loop_end:
	ldi		REG_TEMP_R16, 0xff

ds18b20_compare_alr_rom_ret:
	ret
; ---------

; ---------
; Calcul du CRC8
;
; Input:
;   - Y:            Adresse du 1st byte
;   - REG_TEMP_R16: Nombre de bytes
;     => ('Y' + REG_TEMP_R16): Adresse qui suit le dernier byte a lire
;
;   - Bit Toggle 'T' a 0 pour une non prise en compte du 1st byte
;     => Le CRC8 calcule doit etre compare a celui recu
;
;   - Bit Toggle 'T' a 1 pour une prise en compte du 1st byte
;     => Le CRC8 calcule doit etre a 0
;
; Code en Langage C:
;   - 'i__byte': Byte en entree avec le Bit 0 a prendre en compte
;                => Bit 0 issu de 8 decalages a droite
;
;   - 'crc':     CRC8 incremental initialise a 0x00
;   - CRC8_POLYNOMIAL = CRC8_POLYNOMIAL = 0x8C pour le CRC8-MAXIM
;
;     unsigned char carry = ((crc ^ i__byte) & 0x01);
;
;     crc >>= 1;
;     crc ^= (carry ? CRC8_POLYNOMIAL: 0x00);
;
; ---------
ds18b20_crc8_calc:
	clt
	rjmp		ds18b20_crc8	

ds18b20_crc8_test:
	set
	rjmp		ds18b20_crc8

ds18b20_crc8:
	ldi		REG_TEMP_R16, 9	; 9 bytes pour le calcul sur les reponses
	ldi		REG_Y_MSB, 0x01	; Adresse de 'G_DS18B20_BYTES_RESP'
	ldi		REG_Y_LSB, 0x60

ds18b20_crc8_bypass:
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18
	push		REG_TEMP_R19
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_Y_MSB
	push		REG_Y_LSB
	push		REG_Z_MSB
	push		REG_Z_LSB

	add		REG_Y_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_Y_MSB, REG_TEMP_R17		; 'Y' pointe sur l'addrese qui suit le dernier byte

	mov		REG_TEMP_R18, REG_TEMP_R16	; Parcours sans le 1st byte qui contient

	brts		ds18b20_crc8_more		; 'T'=0: Calcul CRC8 pour comparaison 'T'=1: CRC8 a 0 si Ok
	dec		REG_TEMP_R18

ds18b20_crc8_more:
	clr		REG_TEMP_R19								; CRC8 calcule
	sts		G_CALC_CRC8, REG_TEMP_R19

ds18b20_crc8_loop_bytes:
	lds		REG_TEMP_R19, G_CALC_CRC8				; Reprise du dernier CRC8 calcule
	ld			REG_TEMP_R17, -Y

	mov		REG_X_LSB, REG_TEMP_R17
	rcall		print_1_byte_hexa_skip
	
	push		REG_TEMP_R18

	ldi		REG_TEMP_R18, 8

ds18b20_crc8_loop_bit:
	mov		REG_TEMP_R16, REG_TEMP_R19	; 'REG_TEMP_R19' contient le CRC8 calcule
	eor		REG_TEMP_R16, REG_TEMP_R17	; 'REG_TEMP_R17' contient le byte a inserer dans le polynome
	andi		REG_TEMP_R16, 0x01			; carry = ((crc ^ i__byte) & 0x01);

	clt											; 'T' determine le report de la carry	
	breq		ds18b20_crc8_a
	set

ds18b20_crc8_a:
	lsr		REG_TEMP_R19					; crc >>= 1;
	brtc		ds18b20_crc8_b

	ldi		REG_TEMP_R16, CRC8_POLYNOMIAL
	eor		REG_TEMP_R19, REG_TEMP_R16					; crc ^= (carry ? CRC8_POLYNOMIAL: 0x00);

ds18b20_crc8_b:
	sts		G_CALC_CRC8, REG_TEMP_R19

	lsr		REG_TEMP_R17									; i__byte >>= 1

	dec		REG_TEMP_R18
	brne		ds18b20_crc8_loop_bit

	pop		REG_TEMP_R18
	dec		REG_TEMP_R18
	brne		ds18b20_crc8_loop_bytes		; Non prise en compte du 1st byte qui est le CRC8 recu ;-)

	ldi		REG_TEMP_R16, 'C'
	rcall		push_1_char_in_fifo_tx_skip
	mov		REG_X_LSB, REG_TEMP_R19
	rcall		print_1_byte_hexa_skip
	rcall		print_line_feed_skip

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_X_LSB
	pop		REG_X_MSB
	pop		REG_TEMP_R19
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16

	ret
; ---------

; ---------
; Valeur du ROM #N detecte
;
; Input:
;   - 'REG_TEMP_R16' dans la plage [0, 1, 2, ..., ('G_DS18B20_NBR_ROM' - 1)]
;
; Retour:
;   - Bit Toggle 'T' a 0 pour non detecte (N >= 'G_DS18B20_NBR_ROM')
;   - Bit Toggle 'T' a 1 pour detecte
;     => 'X' contient l'adresse du ROM #N ('G_DS18B20_ROM_0', 'G_DS18B20_ROM_1', etc.)
;
ds18b20_get_rom_detected:
	lds		REG_TEMP_R16, G_TEST_VALUE_LSB_MORE	; Recuperation parametre #N (<xaaaa-nn)

ds18b20_get_rom_detected_bypass:
	push		REG_TEMP_R16
	tst		REG_TEMP_R16								; N >= 0 ?
	brmi		ds18b20_get_rom_detected_ko	; Saut si N < 0

	lds		REG_TEMP_R17, G_DS18B20_NBR_ROM		; Oui
	cp			REG_TEMP_R16, REG_TEMP_R17				; N < 'G_DS18B20_NBR_ROM' ?
	brpl		ds18b20_get_rom_detected_ko	; Saut si N >= 'G_DS18B20_NBR_ROM'

ds18b20_get_rom_detected_ok:					; Oui (0 <= N < 'G_DS18B20_NBR_ROM')
	ldi		REG_X_MSB, high(G_DS18B20_ROM_0)
	ldi		REG_X_LSB, low(G_DS18B20_ROM_0)

	lsl		REG_TEMP_R16								; Table de ROM definis sur 8 bytes
	lsl		REG_TEMP_R16								; => 'REG_TEMP_R16' *= 8
	lsl		REG_TEMP_R16

	add		REG_X_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_X_MSB, REG_TEMP_R17

	ldi		REG_TEMP_R16, 'O'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		print_2_bytes_hexa_skip
	rcall		print_line_feed_skip

	set														; Detecte
	rjmp		ds18b20_get_rom_detected_ret

ds18b20_get_rom_detected_ko:
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 'K'
	rcall		push_1_char_in_fifo_tx_skip
	pop		REG_TEMP_R16
	mov		REG_X_LSB, REG_TEMP_R16
	rcall		print_1_byte_hexa_skip
	rcall		print_line_feed_skip

	clt														; Non detecte

ds18b20_get_rom_detected_ret:
	pop		REG_TEMP_R16
	ret
; ---------

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
	sts		G_DS1820_IN_ALARM, REG_TEMP_R16

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
	rcall		push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_ALR_PATTERN
	rcall		print_1_byte_hexa_skip

	rcall		print_line_feed_skip
	rcall		fifo_tx_to_send_sync

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
	rjmp		ds18b20_search_alr_loop_01

ds18b20_search_alr_loop_01:

	rcall		ds18b20_write_bit	

	dec		REG_TEMP_R18
	brne		ds18b20_search_alr_loop

	rjmp		ds18b20_search_alr_end

ds18b20_search_alr_no_device:
	ldi		REG_TEMP_R16, 'N'
	rcall		push_1_char_in_fifo_tx_skip
	rjmp		ds18b20_search_alr_abort

ds18b20_search_alr_abort:
	sei

	ldi		REG_X_LSB, 64
	sub		REG_X_LSB, REG_TEMP_R18
	rcall		print_1_byte_hexa_skip

	mov		REG_X_LSB, REG_TEMP_R17
	rcall		print_1_byte_hexa_skip
	rcall		print_line_feed_skip

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
	rcall		push_1_char_in_fifo_tx_skip
	pop		REG_X_LSB
	rcall		print_1_byte_hexa_skip
	rcall		print_line_feed_skip

	pop		REG_TEMP_R16
	pop		REG_X_LSB
	pop		REG_X_MSB
	; Fin: Emission du ROM #N en alarme

	; Cas ou le capteur #N n'est pas trouve dans la table des ROM detectes
	; => Abort a la 1st occurence
	cpi		REG_TEMP_R16, 0xff
	breq		ds18b20_search_alr_rtn

	; Update 'G_DS1820_IN_ALARM' @ 'REG_TEMP_R16'
	ldi		REG_Z_MSB, ((text_msk_table << 1) / 256)
	ldi		REG_Z_LSB, ((text_msk_table << 1) % 256)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_Z_MSB, REG_TEMP_R17
	lpm		REG_TEMP_R18, Z
	lds		REG_TEMP_R17, G_DS1820_IN_ALARM
	or			REG_TEMP_R17, REG_TEMP_R18
	sts		G_DS1820_IN_ALARM, REG_TEMP_R17
	; End: Update 'G_DS1820_IN_ALARM' @ 'REG_TEMP_R16'

	rcall		ds18b20_alr_copy_rom

	lds		REG_TEMP_R16, G_DS18B20_ALR_NBR_ROM
	inc		REG_TEMP_R16
	sts		G_DS18B20_ALR_NBR_ROM, REG_TEMP_R16

	lds		REG_TEMP_R17, G_DS18B20_ALR_NBR_ROM_MAX
	cp			REG_TEMP_R16, REG_TEMP_R17
	brpl		ds18b20_search_alr_rtn

ds18b20_search_alr_found:
	ldi		REG_TEMP_R16, 'N'
	rcall		push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_ALR_NBR_BITS_RETRY
	rcall		print_1_byte_hexa_skip

	ldi		REG_TEMP_R16, '?'
	rcall		push_1_char_in_fifo_tx_skip
	lds		REG_X_LSB, G_DS18B20_ALR_NBR_BITS_0_1
	rcall		print_1_byte_hexa_skip

	rcall		print_line_feed_skip

	rcall		fifo_tx_to_send_sync

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
; Prise de l'index du ROM passe en argument dans la table ['G_DS18B20_ROM_0', ..., 'G_DS18B20_ROM_7']
;
; - Input:
;    - -REG_X_MSB:REG_X_LSB': Adresse du 1st byte du ROM a rechercher
;
; - Retour dans 'REG_TEMP_R16':
;    - 0xff si "Non trouve"
;
;    - L'index [0, 1, 2, ...] si "trouve" a l'identique sur les 8 octets constituant le ROM
; ---------
ds18b20_get_rom_idx:
	push		REG_TEMP_R17
	push		REG_TEMP_R18
	push		REG_Y_MSB
	push		REG_Y_LSB

	lds		REG_TEMP_R17, G_DS18B20_NBR_ROM
	tst		REG_TEMP_R17
	breq		ds18b20_get_rom_idx_not_found

	ldi		REG_Y_MSB, high(G_DS18B20_ROM_0)
	ldi		REG_Y_LSB, low(G_DS18B20_ROM_0)

	clr		REG_TEMP_R16						

ds18b20_get_rom_idx_loop:
	push		REG_X_MSB							; Sauvegarde de l'adresse du ROM a tester
	push		REG_X_LSB
	ldi		REG_TEMP_R18, 8					; Comparaison sur les 8 bytes
	set												; A priori bytes identiques

ds18b20_get_rom_idx_loop_2:
	ld			REG_R0, X+
	ld			REG_R1, Y+
	cpse		REG_R0, REG_R1
	clt												; Byte(s) different(s) => Continue

	dec		REG_TEMP_R18
	brne		ds18b20_get_rom_idx_loop_2

	pop		REG_X_LSB							; Reprise de l'adresse du ROM a tester
	pop		REG_X_MSB

	brtc		ds18b20_get_rom_idx_cont_d		; Les 8 bytes sont identiques ?
	rjmp		ds18b20_get_rom_idx_found		; Oui => Fin avec l'index dans 'REG_TEMP_R16'

ds18b20_get_rom_idx_cont_d:					; Non => Continue
	inc		REG_TEMP_R16
	dec		REG_TEMP_R17
	brne		ds18b20_get_rom_idx_loop

	rjmp		ds18b20_get_rom_idx_not_found

ds18b20_get_rom_idx_not_found:
	ldi		REG_TEMP_R16, 0xff

	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, '?'
	rcall		push_1_char_in_fifo_tx_skip
	pop		REG_X_LSB
	rcall		print_1_byte_hexa_skip
	pop		REG_X_LSB
	pop		REG_X_MSB
	rcall		print_2_bytes_hexa_skip
	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		print_2_bytes_hexa_skip
	rcall		print_line_feed_skip
	pop		REG_X_LSB
	pop		REG_X_MSB

	ldi		REG_TEMP_R16, 0xff
	rjmp		ds18b20_get_rom_idx_ret

ds18b20_get_rom_idx_found:
	push		REG_TEMP_R16
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 'B'
	rcall		push_1_char_in_fifo_tx_skip
	pop		REG_X_LSB
	rcall		print_1_byte_hexa_skip
	rcall		print_line_feed_skip
	pop		REG_TEMP_R16

ds18b20_get_rom_idx_ret:
	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17

	ret
; ---------

; ---------
; Preparation du code a exporter dans le fichier 'DS18B20.asm' inclus dans le projet
; - Recherche sur le bus des ROMs a concurence de 8 maximum
; - Conversion pour la detection de depassement des seuils d'alarme Tl et Th
;   et pour prise des temperatures Tc
; - Recherche des ROMs en alarme @ aus seuils Tl et Th
; - Prise des temperatures Tc
; - Emission de la trame constituee des parties:
;   - Header
;   - Informations pour chaque capteur trouve
;   - CRC8 de la trame complete
; ---------
ds18b20_init:
	; Lecture du nombre premier associe a l'Id de la platine
	ldi		REG_X_MSB, high(EEPROM_ADDR_PRIMES);
	ldi		REG_X_LSB, low(EEPROM_ADDR_PRIMES);
	lds		REG_TEMP_R16, G_HEADER_INDEX_PLATINE
	andi		REG_TEMP_R16, 0x0f
	add		REG_X_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16
	adc		REG_X_MSB, REG_TEMP_R16

	rcall		eeprom_read_byte

	; Test si valeur incorrecte (0x00 ou 0xff)
	; => Pas de maj de 'G_DS18B20_COUNTER_xxx'
	;    => En consequence, pas de cadencement ;-)
	tst		REG_TEMP_R16
	breq		ds18b20_init_end

	cpi		REG_TEMP_R16, 0xff
	breq		ds18b20_init_end
	; Fin: Test si valeur incorrecte (0x00 ou 0xff)

	sts		G_DS18B20_COUNTER_INIT, REG_TEMP_R16

	; Amorce avec une 2nd lecture des DS18B20 au bout de 5 Sec
	; car la 1st retourne la valeur par defaut cad 85 degrees
	; => Les suivantes se feront au rithme de 'G_DS18B20_COUNTER_INIT' Sec. ;-)
	ldi		REG_TEMP_R17, 5
	sts		G_DS18B20_COUNTER, REG_TEMP_R17

	ldi		REG_TEMP_R17, 'e'
	rcall		print_mark_skip
	lds		REG_X_LSB, G_HEADER_INDEX_PLATINE
	rcall		print_1_byte_hexa
	lds		REG_X_LSB, G_DS18B20_COUNTER_INIT
	rcall		print_1_byte_hexa
	rcall		print_line_feed

	; Armement timer 'DS18B20_TIMER_1_SEC' pour les meseure de temperatures
	ldi      REG_TEMP_R17, DS18B20_TIMER_1_SEC
	ldi      REG_TEMP_R18, (1000 % 256)
	ldi      REG_TEMP_R19, (1000 / 256)
	call    start_timer

ds18b20_init_end:
	ret
; ---------

; ---------
ds18b20_exec:
	; Inhibition trace
	sbr		REG_FLAGS_0, FLG_0_PRINT_SKIP_MSK

	; Recherche sur le bus des ROMs
	ldi		REG_TEMP_R17, 's'
	rcall		print_mark_skip

	rcall		ds18b20_search_rom
	; Fin: Recherche sur le bus des ROMs

	; 1st pass: Conversion des temperatures + Recherche des capteurs en alarme
	; 2nd pass: Prise des temperatures
	clr		REG_TEMP_R17
	sbr		REG_TEMP_R17, FLG_DS18B20_CONV_T_MSK
	cbr		REG_TEMP_R17, FLG_DS18B20_TEMP_MSK
	sbr		REG_TEMP_R17, FLG_DS18B20_FRAMES_MSK
	sts		G_BUS_1_WIRE_FLAGS, REG_TEMP_R17

ds18b20_exec_pass:

	; Conversion pour chaque ROM detecte #N [0, 1, 2, etc.]
	clr		REG_TEMP_R16

ds18b20_exec_loop:
	; Recuperation du ROM #N detecte
	rcall		ds18b20_get_rom_detected_bypass	
	brtc		ds18b20_exec_conversion_end

	push		REG_TEMP_R16			; Sauvegarde #N

	; Reset capteur #N
	ldi		REG_TEMP_R17, 'r'
	rcall		print_mark_skip
	rcall		ds18b20_reset

	; Copy ROM @ 'REG_TEMP_R17' into 'G_DS18B20_BYTES_SEND'
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_SEND)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_SEND)
	ldi		REG_TEMP_R17, 8

ds18b20_exec_loop_2:
	ld			REG_TEMP_R18, X+
	st			Y+, REG_TEMP_R18
	dec		REG_TEMP_R17
	brne		ds18b20_exec_loop_2
	; End: Copy ROM @ 'REG_TEMP_R17' into 'G_DS18B20_BYTES_SEND'

	ldi		REG_TEMP_R17, 'm'
	rcall		print_mark_skip
	rcall		ds18b20_match_rom

	lds		REG_TEMP_R17, G_BUS_1_WIRE_FLAGS
	sbrc		REG_TEMP_R17, FLG_DS18B20_CONV_T_IDX
	rjmp		ds18b20_conversion

	sbrc		REG_TEMP_R17, FLG_DS18B20_TEMP_IDX
	rjmp		ds18b20_temp

	rjmp		ds18b20_exec_cont_d

ds18b20_conversion:
	ldi		REG_TEMP_R17, 'c'
	rcall		print_mark_skip
	rcall		ds18b20_convert_t
	rjmp		ds18b20_exec_cont_d

ds18b20_temp:
	ldi		REG_TEMP_R17, 't'
	rcall		print_mark_skip
	rcall		ds18b20_read_scratchpad
	rjmp		ds18b20_exec_cont_d

ds18b20_exec_cont_d:
	rcall		fifo_tx_to_send_sync

	pop		REG_TEMP_R16			; Restauration #N
	inc		REG_TEMP_R16			; #N suivant
	rjmp		ds18b20_exec_loop
	; Fin: Conversion pour chaque ROM detecte

ds18b20_exec_conversion_end:
	; Test si tous les 'G_DS18B20_NBR_ROM' ont ete balayes
	lds		REG_TEMP_R17, G_DS18B20_NBR_ROM
	tst		REG_TEMP_R17
	breq		ds18b20_exec_build_frame		; Construction de la trame a emettre

	cpse		REG_TEMP_R16, REG_TEMP_R17		; Fin si erreur de comparaison
	rjmp		ds18b20_exec_end

	; Recherche des capteurs en alarme si fin de la conversion
	lds		REG_TEMP_R17, G_BUS_1_WIRE_FLAGS
	sbrc		REG_TEMP_R17, FLG_DS18B20_CONV_T_IDX
	rjmp		ds18b20_exec_search_alarm

	cbr		REG_TEMP_R17, FLG_DS18B20_TEMP_MSK
	sts		G_BUS_1_WIRE_FLAGS, REG_TEMP_R17
	rjmp		ds18b20_exec_build_frame

ds18b20_exec_search_alarm:
	cbr		REG_TEMP_R17, FLG_DS18B20_CONV_T_MSK
	sbr		REG_TEMP_R17, FLG_DS18B20_TEMP_MSK
	sts		G_BUS_1_WIRE_FLAGS, REG_TEMP_R17

	ldi		REG_TEMP_R17, 'a'
	rcall		print_mark_skip
	rcall		ds18b20_search_alarm

	; Effacement des emplacements 'G_DS18B20_ALR_ROM_N' pour acceuillir les trames
	rcall		ds18b20_clear_alr

	rjmp		ds18b20_exec_pass

ds18b20_exec_build_frame:
	ldi		REG_TEMP_R17, 'f'
	rcall		print_mark_skip

	; Complements d'informations de la trame complete a emettre
	rcall		buid_frame_complement

	; Preparation prochaine emission
	lds		REG_Y_MSB, G_HEADER_NUM_FRAME_MSB
	lds		REG_Y_LSB, G_HEADER_NUM_FRAME_LSB
	adiw		REG_Y_LSB, 1
	sts		G_HEADER_NUM_FRAME_MSB, REG_Y_MSB
	sts		G_HEADER_NUM_FRAME_LSB, REG_Y_LSB

ds18b20_exec_end:
	; Reactivation trace
	cbr		REG_FLAGS_0, FLG_0_PRINT_SKIP_MSK

	; Emission de la trame complete
	rcall		ds18b20_send_frame

	ret

; ---------
; Construction des trames a emettre pour chaque capteur
; => Les informations issues de 'ds18b20_read_scratchpad' sont deja disponibles
; => Les trames sont ecrites aux emplacements ['G_DS18B20_ALR_ROM_0', 'G_DS18B20_ALR_ROM_1', etc.]
; ---------
build_frame_infos:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_RESP)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_RESP)
	ldi		REG_Z_MSB, high(G_DS18B20_FRAME_0)
	ldi		REG_Z_LSB, low(G_DS18B20_FRAME_0)
	lds		REG_TEMP_R17, G_DS18B20_ROM_IDX

	; Inversion pour l'emission du 1st capteur en premier
	; #0 -> 'G_DS18B20_NBR_ROM', #1 -> ('G_DS18B20_NBR_ROM' - 1), etc.
	lds		REG_TEMP_R16, G_DS18B20_NBR_ROM
	sub		REG_TEMP_R16, REG_TEMP_R17	
	subi		REG_TEMP_R16, 1
	lsl		REG_TEMP_R16
	lsl		REG_TEMP_R16
	lsl		REG_TEMP_R16
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16
	adc		REG_Z_MSB, REG_TEMP_R16

	lds		REG_TEMP_R16, G_DS1820_FAMILLE
	std		Z + FRAME_IDX_FAMILLE, REG_TEMP_R16

	lds		REG_TEMP_R16, G_DS18B20_ROM_IDX
	std		Z + FRAME_IDX_IDX, REG_TEMP_R16

	ldd		REG_TEMP_R16, Y + RESP_IDX_TC_LSB
	std		Z + FRAME_IDX_TC_LSB, REG_TEMP_R16

	ldd		REG_TEMP_R16, Y + RESP_IDX_TC_MSB
	std		Z + FRAME_IDX_TC_MSB, REG_TEMP_R16

	ldd		REG_TEMP_R16, Y + RESP_IDX_TL
	std		Z + FRAME_IDX_TL, REG_TEMP_R16

	ldd		REG_TEMP_R16, Y + RESP_IDX_TH
	std		Z + FRAME_IDX_TH, REG_TEMP_R16

	ldd		REG_TEMP_R16, Y + RESP_IDX_RESOL_CONV
	swap		REG_TEMP_R16				; Resolution dans REG_TEMP_R16<2,1>
	lsr		REG_TEMP_R16				; Resolution dans REG_TEMP_R16<1,0>
	andi		REG_TEMP_R16, 0x03		; Isolement de la resolution

	; Add  Etat du capteur en alarme ou non (bit #7 de 'FRAME_IDX_ALR_RES_CONV')
	push		REG_Z_MSB
	push		REG_Z_LSB

	ldi		REG_Z_MSB, ((text_msk_table << 1) / 256)
	ldi		REG_Z_LSB, ((text_msk_table << 1) % 256)
	lds		REG_TEMP_R17, G_DS18B20_ROM_IDX
	add		REG_Z_LSB, REG_TEMP_R17
	clr		REG_TEMP_R17
	adc		REG_Z_MSB, REG_TEMP_R17
	lpm		REG_TEMP_R17, Z
	lds		REG_TEMP_R18, G_DS1820_IN_ALARM
	and		REG_TEMP_R17, REG_TEMP_R18
	breq		build_frame_infos_no_alarm
	sbr		REG_TEMP_R16, MSK_BIT7	; Etat d'alarme du Capteur dans REG_TEMP_R16<7>

build_frame_infos_no_alarm:
	pop		REG_Z_LSB
	pop		REG_Z_MSB
	std		Z + FRAME_IDX_ALR_RES_CONV, REG_TEMP_R16
	; End: Add  Etat du capteur en alarme ou non (bit #7 de 'FRAME_IDX_ALR_RES_CONV')

	; Calcul du CRC8
	ldi		REG_TEMP_R16, 8				; CRC8 sur les 7 bytes qui suivent 'Z + FRAME_IDX_CRC8'
	movw		REG_Y_LSB, REG_Z_LSB
	clt
	rcall		ds18b20_crc8_bypass
	lds		REG_TEMP_R16, G_CALC_CRC8
	std		Z + FRAME_IDX_CRC8, REG_TEMP_R16
	; Fin: Calcul du CRC8

	ret
; ---------

; ---------
buid_frame_complement:
	; Positionnement sur le 1st byte qui suit le dernier byte de la trame capteur
	ldi		REG_Z_MSB, high(G_DS18B20_FRAME_0)
	ldi		REG_Z_LSB, low(G_DS18B20_FRAME_0)
	lds		REG_TEMP_R16, G_DS18B20_NBR_ROM
	sts		G_HEADER_NBR_CAPTEURS, REG_TEMP_R16		; Nombre de capteurs
	lsl		REG_TEMP_R16									; Raccourci car 'FRAME_LENGTH_CAPTEUR' == 8
	lsl		REG_TEMP_R16
	lsl		REG_TEMP_R16
	mov		REG_TEMP_R17, REG_TEMP_R16					; Nbr de bytes sans le CRC8 et le Header

	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16
	adc		REG_Z_MSB, REG_TEMP_R16
	sbiw		REG_Z_LSB, FRAME_LENGTH_CAPTEUR

	lds		REG_TEMP_R16, G_HEADER_NBR_CAPTEURS
	std		Z + FRAME_IDX_NBR_CAPTEURS, REG_TEMP_R16

	lds		REG_TEMP_R16, G_HEADER_TIMESTAMP_MSB
	std		Z + FRAME_IDX_TIMESTAMP_MSB, REG_TEMP_R16
	lds		REG_TEMP_R16, G_HEADER_TIMESTAMP_MID
	std		Z + FRAME_IDX_TIMESTAMP_MID, REG_TEMP_R16
	lds		REG_TEMP_R16, G_HEADER_TIMESTAMP_LSB
	std		Z + FRAME_IDX_TIMESTAMP_LSB, REG_TEMP_R16

	lds		REG_TEMP_R16, G_HEADER_NUM_FRAME_MSB
	std		Z + FRAME_IDX_NUM_FRAME_MSB, REG_TEMP_R16
	lds		REG_TEMP_R16, G_HEADER_NUM_FRAME_LSB
	std		Z + FRAME_IDX_NUM_FRAME_LSB, REG_TEMP_R16

	lds		REG_TEMP_R16, G_HEADER_INDEX_PLATINE
	std		Z + FRAME_IDX_INDEX_PLATINE, REG_TEMP_R16
	lds		REG_TEMP_R16, G_HEADER_TYPE_PLATINE
	std		Z + FRAME_IDX_TYPE_PLATINE, REG_TEMP_R16

	; Calcul du CRC8 de la trame complete
	subi		REG_TEMP_R17, -(1 + 8)			; Reprise du nombre de bytes avec le CRC8 et le Header

	; Calcul du CRC8 sur tous les bytes sauf le 1st
	ldi		REG_Y_MSB, high(G_FRAME_ALL_INFOS)
	ldi		REG_Y_LSB, low(G_FRAME_ALL_INFOS)
	mov		REG_TEMP_R16, REG_TEMP_R17
	clt
	rcall		ds18b20_crc8_bypass
	lds		REG_TEMP_R16, G_CALC_CRC8
	sts		G_FRAME_ALL_INFOS, REG_TEMP_R16
	; Fin: Calcul du CRC8 sur tous les bytes sauf le 1st

	mov		REG_X_LSB, REG_TEMP_R17
	rcall		print_1_byte_hexa_skip
	movw		REG_X_LSB, REG_Y_LSB
	rcall		print_2_bytes_hexa_skip
	rcall		print_line_feed_skip

	; Calcul du CRC8 sur tous les bytes avec le 1st
	; => Le CRC8 "total" doit etre etre egal a 0 car inclu ledit CRC8 ;-)
	ldi		REG_Y_MSB, high(G_FRAME_ALL_INFOS)
	ldi		REG_Y_LSB, low(G_FRAME_ALL_INFOS)
	mov		REG_TEMP_R16, REG_TEMP_R17
	set
	rcall		ds18b20_crc8_bypass
	lds		REG_TEMP_R16, G_CALC_CRC8
	; Fin: Calcul du CRC8 sur tous les bytes avec le 1st

	mov		REG_X_LSB, REG_TEMP_R17
	rcall		print_1_byte_hexa_skip
	movw		REG_X_LSB, REG_Y_LSB
	rcall		print_2_bytes_hexa_skip
	rcall		print_line_feed_skip
	; Fin: Calcul du CRC8 sur tous les bytes avec le 1st
	; Fin: Calcul du CRC8 de la trame complete

	ret
; ---------

; ---------
; Emission de la trame complete
; ---------
ds18b20_send_frame:
	; Positionnement sur le 1st byte qui suit le dernier byte de la trame capteur
	lds		REG_TEMP_R18, G_HEADER_NBR_CAPTEURS		; Nombre de capteurs
	lsl		REG_TEMP_R18									; Raccourci car 'FRAME_LENGTH_CAPTEUR' == 8
	lsl		REG_TEMP_R18
	lsl		REG_TEMP_R18
	subi		REG_TEMP_R18, -(1 + 8)						; Nombre de bytes avec le CRC8 et le Header

	ldi		REG_Y_MSB, high(G_FRAME_ALL_INFOS)
	ldi		REG_Y_LSB, low(G_FRAME_ALL_INFOS)
	add		REG_Y_LSB, REG_TEMP_R18
	clr		REG_TEMP_R16
	adc		REG_Y_MSB, REG_TEMP_R16

#if USE_DS18B20_TRACE
	ldi		REG_TEMP_R17, '$'
	rcall		print_mark_skip
	mov		REG_X_LSB, REG_TEMP_R18
	rcall		print_2_bytes_hexa
	rcall		print_y_reg
	rcall		print_line_feed_skip
#endif

	; Emission de la trame
	ldi		REG_TEMP_R16, '$'
	call		push_1_char_in_fifo_tx_skip

ds18b20_send_frame_loop:
	ld			REG_TEMP_R16, -Y
	rcall		convert_and_put_fifo_tx

	dec		REG_TEMP_R18
	brne		ds18b20_send_frame_loop

	rcall		print_line_feed_skip
	call		fifo_tx_to_send_sync
	; Fin: Emission de la trame

	ret
; ---------

; ---------
; Configuration des DS18B20
; ---------

; ---------
; Conversion pour le DS18B20
;
; Input: 'REG_X_MSB:REG_X_LSB'
;
; Output: - Si valeur coherente (T == 1) -> 'REG_X_LSB'
;         - Sinon               (T == 0) -> 'REG_X_LSB' indefini
; ---------
convert_val_for_ds18b20:
	rcall		convert_2_bytes_hexa_to_dec

	lds		REG_X_MSB, G_TEST_VALUE_DEC_MSB
	lds		REG_X_LSB, G_TEST_VALUE_DEC_LSB
	rcall		print_2_bytes_hexa_skip
   call     print_line_feed_skip

	; Test dans la plage [0, 1, ..., 99, 100, 101, ..., 155]
	;                                    L-- Negatives (0, -1, -2, ..., -55)
	;                                    => (256 - (Value - 100)) = ((356 - Value) % 256) -> [0, -1, -2, ..., -55]
	;                     L-- Positives (0, 1, 2, ..;, 99)                                -> [0, +1, +2, ..., +99]
	;
	ldi		REG_TEMP_R17, 0
	ldi		REG_TEMP_R16, (155 + 1)
	cp			REG_X_LSB, REG_TEMP_R16
	cpc		REG_X_MSB, REG_TEMP_R17
	brpl		convert_val_for_ds18b20_ko

	; Test si valeur negative a configurer ?
	ldi		REG_TEMP_R17, 0
	ldi		REG_TEMP_R16, 100
	cp			REG_X_LSB, REG_TEMP_R16
	cpc		REG_X_MSB, REG_TEMP_R17
	brpl		convert_val_for_ds18b20_val_neg

convert_val_for_ds18b20_val_pos:
	movw		REG_TEMP_R16, REG_X_LSB
	rjmp		convert_val_for_ds18b20_value

convert_val_for_ds18b20_val_neg:
	ldi		REG_TEMP_R17, 0x01		; 356 = 0x164
	ldi		REG_TEMP_R16, 0x64
	sub		REG_TEMP_R16, REG_X_LSB	; ((356 - Value) % 256)

convert_val_for_ds18b20_value:
	mov		REG_X_LSB, REG_TEMP_R16
	clt
	rjmp		convert_val_for_ds18b20_rtn

convert_val_for_ds18b20_ko:
	set

convert_val_for_ds18b20_rtn:
	ret
; ---------

; ---------
; Conversion des 2 bytes 'REG_X_MSB:REG_X_LSB' en decimal dans 'G_TEST_VALUE_DEC_MSB:G_TEST_VALUE_DEC_LSB'
; ---------
convert_2_bytes_hexa_to_dec:
	push		REG_TEMP_R16

	mov		REG_TEMP_R16, REG_X_MSB
	swap		REG_TEMP_R16
	andi		REG_TEMP_R16, 0x0F					; Isolement de '0xHH..:....'
	subi		REG_TEMP_R16, -'0'					; Conversion en ASCII ['0', ..., '9']
	rcall		char_to_dec_incremental

	mov		REG_TEMP_R16, REG_X_MSB
	andi		REG_TEMP_R16, 0x0F					; Isolement de '0x..HH:....'
	subi		REG_TEMP_R16, -'0'					; Conversion en ASCII ['0', ..., '9']
	rcall		char_to_dec_incremental

	mov		REG_TEMP_R16, REG_X_LSB
	swap		REG_TEMP_R16
	andi		REG_TEMP_R16, 0x0F					; Isolement de '0x....:HH..'
	subi		REG_TEMP_R16, -'0'					; Conversion en ASCII ['0', ..., '9']
	rcall		char_to_dec_incremental

	mov		REG_TEMP_R16, REG_X_LSB
	andi		REG_TEMP_R16, 0x0F					; Isolement de '0x....:..HH'
	subi		REG_TEMP_R16, -'0'					; Conversion en ASCII ['0', ..., '9']
	rcall		char_to_dec_incremental

	pop		REG_TEMP_R16
	ret
; ---------

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
	rcall		print_mark_skip

	lds		REG_TEMP_R16, G_DS18B20_FLAGS
	sbr		REG_TEMP_R16, FLG_TEST_CONFIG_ERROR_MSK
	sts		G_DS18B20_FLAGS, REG_TEMP_R16

	ret
; ---------

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
ds18b20_copy_scratchpad:
	cli
	ldi		REG_TEMP_R16, DS18B20_CMD_COPY_SCRATCHPAD
	rcall		ds18b20_write_8_bits_command
	sei

	ret
; ---------

text_msk_table:
.db	MSK_BIT0, MSK_BIT1, MSK_BIT2, MSK_BIT3
.db	MSK_BIT4, MSK_BIT5, MSK_BIT6, MSK_BIT7

end:

end_of_program:
 
.dseg
G_SRAM_END_OF_USE:		.byte	1

; End of file

