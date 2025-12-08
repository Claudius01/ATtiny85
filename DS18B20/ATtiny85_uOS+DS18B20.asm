; "$Id: ATtiny85_uOS+DS18B20.asm,v 1.22 2025/12/08 18:51:48 administrateur Exp $"

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

.cseg

; Definitions de la table de vecteurs de "prolongation" des 4 traitements:
; geres par uOS qui passe la main aux methodes specifiques a l'ADDON
; - #0: Initialisation materielle et logicielle (prolongation du 'setup' de uOS)
; - #1: Traitements en fond de tache
; - #2: Traitements toutes les 1 mS
; - #3: Traitements des nouvelles commandes non supportees par uOS
; - #4: Traitements associes a l'appui bouton avant ceux effectues par uOS
;
; => Toujours definir les 4 adresses avec un 'rjmp' ou un 'ret'
;    si pas de "prolongation" des traitements
;
; => Le nommage est libre et non utilise par uOS
;    => Seul le rang du traitement est impose dans l'ordre defini plus haut

ds18b20_setup:
	; Initialisation et armocage des prises des mesures et de l'emission de la trame
	rjmp		ds18b20_begin

ds18b20_background:
	; Aucun traitement en fond de tache
	ret

ds18b20_1_ms:
	; Aucun traitement toutes les 1 mS
	ret

ds18b20_commands:
	; Execution des commandes "<C" et "<T"
	rjmp		exec_command_ds18b20	

ds18b20_button:
	; Traitements associes a l'appui bouton avant ceux effectues par uOS
	rjmp		exec_button_ds18b20	

; Fin: Definitions de la table de vecteurs de "prolongation" des traitements

; ---------
; Initialisation contextes
; ---------
ds18b20_begin:
	; Prompt d'accueil
	ldi		REG_Z_MSB, ((text_prompt_ds18b20 << 1) / 256)
	ldi		REG_Z_LSB, ((text_prompt_ds18b20 << 1) % 256)
	rcall		uos_push_text_in_fifo_tx

	rcall		ds18b20_init	; Duree de cadencement lue de l'EEPROM @ Id Platine
	rcall		ds18b20_exec	; 1st appel a l'initialisation

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
	; pour une emission de la trame a un temps fonction de l'Id
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

	; Traces de developpement
	; Exemple:
	; -e-
	; [0x00][0x05] -> [Id] Platine][G_DS18B20_COUNTER_INIT]
	; => 'G_DS18B20_COUNTER_INIT' lu de l'eeprom

	ldi		REG_TEMP_R17, 'e'
	rcall		uos_print_mark_skip
	lds		REG_X_LSB, G_HEADER_INDEX_PLATINE
	rcall		uos_print_1_byte_hexa
	lds		REG_X_LSB, G_DS18B20_COUNTER_INIT
	rcall		uos_print_1_byte_hexa
	; Fin: Traces de developpement

	; Armement timer 'DS18B20_TIMER_1_SEC' pour les mesures de temperatures
	; et le cadencement des emissions des trames...
	ldi      REG_TEMP_R17, DS18B20_TIMER_1_SEC
	ldi      REG_TEMP_R18, (1000 % 256)
	ldi      REG_TEMP_R19, (1000 / 256)
	ldi      REG_TEMP_R20, low(exec_timer_ds18b20)
	ldi      REG_TEMP_R21, high(exec_timer_ds18b20)
	rcall    start_timer

	; Lecture depuis l'EEPROM du nombre de DS18B20 a detecter et a gerer
	;       => Valeur a tester dan la plage [1, 2, ..., DS18B20_NBR_ROM_TO_DETECT]
	;          => Sinon forcer a 1 capteur a detecter
	ldi		REG_TEMP_R16, DS18B20_NBR_ROM_TO_DETECT

	ldi		REG_X_MSB, high(EEPROM_ADDR_NBR_DS18B20_TO_DETECT);
	ldi		REG_X_LSB, low(EEPROM_ADDR_NBR_DS18B20_TO_DETECT);

	rcall		eeprom_read_byte

	; Test dans la plage [1, 2, ..., DS18B20_NBR_ROM_TO_DETECT]
	tst		REG_TEMP_R16
	breq		ds18b20_init_force_nbr_detect							; Si valeur 0 lue -> Pas de test dans la plage -> forcage

	cpi		REG_TEMP_R16, (DS18B20_NBR_ROM_TO_DETECT + 1)	; Test dans la plage [1, ..., DS18B20_NBR_ROM_TO_DETECT]
	brlo		ds18b20_init_cont_d

ds18b20_init_force_nbr_detect:
	ldi		REG_TEMP_R16, 1											; 1 DS18B20 a detecter si pas dans la plage

ds18b20_init_cont_d:
	sts		G_DS18B20_NBR_ROM_MAX, REG_TEMP_R16
	; Fin: Lecture depuis l'EEPROM du nombre de DS18B20 a detecter et a gerer

	; Traces de developpement
	lds		REG_X_LSB, G_DS18B20_NBR_ROM_MAX
	rcall		uos_print_1_byte_hexa
	rcall		uos_print_line_feed
	; Fin: Traces de developpement

ds18b20_init_end:
	ret
; ---------

; ---------
; Realise les fonctionnements:
; - Recherche sur le bus des ROMs
; - 1st pass: Conversion des temperatures + Recherche des capteurs en alarme
; - 2nd pass: Prise des temperatures
; - Emission de la trame complete...
; ---------
ds18b20_exec:
	; Autorisation traces si 'G_DS18B20_FLAGS<FLG_DS18B20_TRACE>' a 1
	lds		REG_TEMP_R16, G_DS18B20_FLAGS
	sbrs		REG_TEMP_R16, FLG_DS18B20_TRACE_IDX
	sbr		REG_FLAGS_0, FLG_0_PRINT_SKIP_MSK

	; Recherche sur le bus des ROMs
	ldi		REG_TEMP_R17, 's'
	rcall		uos_print_mark_skip

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
	rcall		uos_print_mark_skip
	rcall		ds18b20_reset

	; Copy ROM @ 'REG_TEMP_R17' into 'G_DS18B20_BYTES_SEND'
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_SEND)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_SEND)
	ldi		REG_TEMP_R17, DS18B20_NBR_ROM_GESTION

ds18b20_exec_loop_2:
	ld			REG_TEMP_R18, X+
	st			Y+, REG_TEMP_R18
	dec		REG_TEMP_R17
	brne		ds18b20_exec_loop_2
	; End: Copy ROM @ 'REG_TEMP_R17' into 'G_DS18B20_BYTES_SEND'

	ldi		REG_TEMP_R17, 'm'
	rcall		uos_print_mark_skip
	rcall		ds18b20_match_rom

	lds		REG_TEMP_R17, G_BUS_1_WIRE_FLAGS
	sbrc		REG_TEMP_R17, FLG_DS18B20_CONV_T_IDX
	rjmp		ds18b20_conversion

	sbrc		REG_TEMP_R17, FLG_DS18B20_TEMP_IDX
	rjmp		ds18b20_temp

	rjmp		ds18b20_exec_cont_d

ds18b20_conversion:
	ldi		REG_TEMP_R17, 'c'
	rcall		uos_print_mark_skip
	rcall		ds18b20_convert_t
	rjmp		ds18b20_exec_cont_d

ds18b20_temp:
	ldi		REG_TEMP_R17, 't'
	rcall		uos_print_mark_skip
	rcall		ds18b20_read_scratchpad
	;rjmp		ds18b20_exec_cont_d

ds18b20_exec_cont_d:
	rcall		fifo_tx_to_send_sync

	pop		REG_TEMP_R16			; Restauration #N
	inc		REG_TEMP_R16			; #N suivant
	rjmp		ds18b20_exec_loop
	; Fin: Conversion pour chaque ROM detecte

ds18b20_exec_conversion_end:
	; Test si tous les 'G_DS18B20_NBR_ROM_FOUND' ont ete balayes
	lds		REG_TEMP_R17, G_DS18B20_NBR_ROM_FOUND
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
	rcall		uos_print_mark_skip
	rcall		ds18b20_search_alarm

	; Effacement des emplacements 'G_DS18B20_ALR_ROM_N' pour acceuillir les trames
	rcall		ds18b20_clear_alr

	rjmp		ds18b20_exec_pass

ds18b20_exec_build_frame:
	ldi		REG_TEMP_R17, 'f'
	rcall		uos_print_mark_skip

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
	ldi		REG_TEMP_R18, DS18B20_NBR_ROM_GESTION
	clr		REG_TEMP_R16

ds18b20_clear_loop_3:
	st			Y+, REG_TEMP_R16
	dec		REG_TEMP_R18
	brne		ds18b20_clear_loop_3

	ret
; ---------

; ---------
; ds18b20_reset: Generation de la pulse RESET --\__/---- de 1mS
; ---------
; La norme specifie > 480uS
;
; Remarque: L'execution est ininterruptible
;           => TODO: Amelioration peut eviter d'etre "sourd" sur la recpetion Rx
; ---------
ds18b20_reset:
	rcall		ds18b20_clear							; Raz des zone d'emission et reception

	cli

	sbi		PORTB, IDX_BIT_LED_GREEN			; Extinction Led GREEN
	cbi		PORTB, IDX_BIT_1_WIRE

	ldi		REG_TEMP_R17, 1						; Spare for awaiting > 255mS

ds18b20_reset_loop_1:
	ldi		REG_TEMP_R16, 100						; Wait 1mS

ds18b20_reset_loop_2:
	rcall		uos_delay_10uS
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
	rcall		uos_delay_10uS
	dec		REG_TEMP_R18
	brne		ds18b20_reset_loop_3

	sbi		DDRB, IDX_BIT_1_WIRE					; <PORTB<2> en sortie

	ldi		REG_TEMP_R16, 'P'
	rcall		push_1_char_in_fifo_tx_skip
	
	mov		REG_TEMP_R16, REG_TEMP_R17
	rcall		push_1_char_in_fifo_tx_skip
	rcall		uos_print_line_feed_skip
	; End: Presence detect ?

	sei
	ret
; ---------

; ---------
ds18b20_print_response:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_RESP)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_RESP)

ds18b20_print_response_loop:
	ld			REG_X_MSB, Y+
	ld			REG_X_LSB, Y+
	rcall		uos_print_2_bytes_hexa_skip

	dec		REG_TEMP_R18
	brne		ds18b20_print_response_loop

	rcall		uos_print_line_feed_skip
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
	rcall		uos_print_2_bytes_hexa_skip

	dec		REG_TEMP_R18
	brne		ds18b20_print_rom_send_loop

	rcall		uos_print_line_feed_skip

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
	rcall		uos_print_2_bytes_hexa_skip

	dec		REG_TEMP_R18
	brne		ds18b20_print_rom_loop

	rcall		uos_print_line_feed_skip

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
	ldi		REG_TEMP_R18, DS18B20_NBR_ROM_GESTION
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

	sts		G_DS18B20_FAMILLE, REG_TEMP_R18	; Update for build frame

	lds		REG_TEMP_R18, G_DS18B20_BYTES_ROM
	ld			REG_TEMP_R19, Y
	cpse		REG_TEMP_R18, REG_TEMP_R19			; CRC different ?
	rjmp		ds18b20_compare_rom_not_found		; Non

ds18b20_compare_rom_found:
	push		REG_TEMP_R16
	mov		REG_X_LSB, REG_TEMP_R16
	rcall		uos_print_1_byte_hexa_skip

	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		uos_print_2_bytes_hexa_skip

	ldi		REG_TEMP_R16, 'F'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		uos_print_line_feed_skip
	pop		REG_TEMP_R16

	rjmp		ds18b20_compare_rom_ret

ds18b20_compare_rom_not_found:
	; Test du CRC8 pour un nouveau ROM non trouve
	push		REG_TEMP_R16
	push		REG_Y_MSB
	push		REG_Y_LSB
	ldi		REG_TEMP_R16, NBR_BITS_TO_SHIFT			; 8 bytes pour le calcul sur les ROM
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
	rcall		uos_print_line_feed_skip

	ldi		REG_TEMP_R16, 0						; Force a ROM trouve (retour avec 'REG_TEMP_R16' != 0 ;-)
	rjmp		ds18b20_compare_rom_ret

ds18b20_compare_rom_crc8_ok:						; Oui
	; Fin: Test du CRC8 pour un nouveau ROM non trouve

ds18b20_compare_rom_not_found_save:
	push		REG_TEMP_R16
	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		uos_print_2_bytes_hexa_skip

	ldi		REG_TEMP_R16, 'f'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		uos_print_line_feed_skip
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
; Gestion des alarmes
; ---------
; ds18b20_clear_alr:
; ds18b20_alr_copy_rom:
; ds18b20_compare_alr_rom:
; ds18b20_search_alarm:    Recherche des capteurs en "alarme"
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
	ldi		REG_TEMP_R18, DS18B20_NBR_ROM_GESTION
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
	rcall		uos_print_1_byte_hexa_skip

	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		uos_print_2_bytes_hexa_skip

	ldi		REG_TEMP_R16, 'F'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		uos_print_line_feed_skip
	pop		REG_TEMP_R16

	rjmp		ds18b20_compare_alr_rom_ret

ds18b20_compare_alr_rom_not_found:
	; Test du CRC8 pour un nouveau ROM non trouve
	push		REG_TEMP_R16
	push		REG_Y_MSB
	push		REG_Y_LSB
	ldi		REG_TEMP_R16, NBR_BITS_TO_SHIFT			; 8 bytes pour le calcul sur les ROM
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
	rcall		uos_print_line_feed_skip

	ldi		REG_TEMP_R16, 0						; Force a ROM trouve (retour avec 'REG_TEMP_R16' != 0 ;-)
	rjmp		ds18b20_compare_alr_rom_ret

ds18b20_compare_alr_rom_crc8_ok:						; Oui
	; Fin: Test du CRC8 pour un nouveau ROM non trouve

ds18b20_compare_alr_rom_not_found_save:
	push		REG_TEMP_R16
	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		uos_print_2_bytes_hexa_skip

	ldi		REG_TEMP_R16, 'f'
	rcall		push_1_char_in_fifo_tx_skip
	rcall		uos_print_line_feed_skip
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
; Fin: Gestion des alarmes
; ---------

; ---------
; CRC8-MAXIM
; ---------
; ds18b20_crc8_calc:   Calcul du CRC8
; ds18b20_crc8_test:   Test du CRC8
; ds18b20_crc8_bypass: Test du CRC8 avec non prise en compte du 1st byte
; ---------
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
	;rjmp		ds18b20_crc8

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
	rcall		uos_print_1_byte_hexa_skip
	
	push		REG_TEMP_R18

	ldi		REG_TEMP_R18, NBR_BITS_TO_SHIFT

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
	rcall		uos_print_1_byte_hexa_skip
	rcall		uos_print_line_feed_skip

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
; Fin: CRC8-MAXIM
; ---------

; ---------
; Valeur du ROM #N detecte
;
; Input:
;   - 'REG_TEMP_R16' dans la plage [0, 1, 2, ..., ('G_DS18B20_NBR_ROM_FOUND' - 1)]
;
; Retour:
;   - Bit Toggle 'T' a 0 pour non detecte (N >= 'G_DS18B20_NBR_ROM')
;   - Bit Toggle 'T' a 1 pour detecte
;     => 'X' contient l'adresse du ROM #N ('G_DS18B20_ROM_0', 'G_DS18B20_ROM_1', etc.)
;
#if 0
ds18b20_get_rom_detected:
	lds		REG_TEMP_R16, G_TEST_VALUE_LSB_MORE	; Recuperation parametre #N (<xaaaa-nn)
#endif

ds18b20_get_rom_detected_bypass:
	push		REG_TEMP_R16
	tst		REG_TEMP_R16								; N >= 0 ?
	brmi		ds18b20_get_rom_detected_ko			; Saut si N < 0

	lds		REG_TEMP_R17, G_DS18B20_NBR_ROM_FOUND	; Oui
	cp			REG_TEMP_R16, REG_TEMP_R17				; N < 'G_DS18B20_NBR_ROM_FOUND' ?
	brpl		ds18b20_get_rom_detected_ko			; Saut si N >= 'G_DS18B20_NBR_ROM_FOUND'

ds18b20_get_rom_detected_ok:							; Oui (0 <= N < 'G_DS18B20_NBR_ROM_FOUND')
	ldi		REG_X_MSB, high(G_DS18B20_ROM_0)
	ldi		REG_X_LSB, low(G_DS18B20_ROM_0)

	lsl		REG_TEMP_R16								; Table de ROM definis sur 8 bytes
	lsl		REG_TEMP_R16								; => 'REG_TEMP_R16' *= 8
	lsl		REG_TEMP_R16

	add		REG_X_LSB, REG_TEMP_R16
	clr		REG_TEMP_R17
	adc		REG_X_MSB, REG_TEMP_R17

	ldi		REG_TEMP_R16, 'O'

#if USE_DS18B20_TRACE
	call		push_1_char_in_fifo_tx_skip
#else
	rcall		push_1_char_in_fifo_tx_skip
#endif

	rcall		uos_print_2_bytes_hexa_skip
	rcall		uos_print_line_feed_skip

	set														; Detecte
	rjmp		ds18b20_get_rom_detected_ret

ds18b20_get_rom_detected_ko:
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 'K'
	rcall		push_1_char_in_fifo_tx_skip
	pop		REG_TEMP_R16
	mov		REG_X_LSB, REG_TEMP_R16
	rcall		uos_print_1_byte_hexa_skip
	rcall		uos_print_line_feed_skip

	clt														; Non detecte

ds18b20_get_rom_detected_ret:
	pop		REG_TEMP_R16
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

	lds		REG_TEMP_R17, G_DS18B20_NBR_ROM_FOUND
	tst		REG_TEMP_R17
	breq		ds18b20_get_rom_idx_not_found

	ldi		REG_Y_MSB, high(G_DS18B20_ROM_0)
	ldi		REG_Y_LSB, low(G_DS18B20_ROM_0)

	clr		REG_TEMP_R16						

ds18b20_get_rom_idx_loop:
	push		REG_X_MSB							; Sauvegarde de l'adresse du ROM a tester
	push		REG_X_LSB
	ldi		REG_TEMP_R18, NBR_BITS_TO_SHIFT		; Comparaison sur les 8 bytes
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

	;rjmp		ds18b20_get_rom_idx_not_found

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
	rcall		uos_print_1_byte_hexa_skip
	pop		REG_X_LSB
	pop		REG_X_MSB
	rcall		uos_print_2_bytes_hexa_skip
	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		uos_print_2_bytes_hexa_skip
	rcall		uos_print_line_feed_skip
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
	rcall		uos_print_1_byte_hexa_skip
	rcall		uos_print_line_feed_skip
	pop		REG_TEMP_R16

ds18b20_get_rom_idx_ret:
	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17

	ret
; ---------

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
	; #0 -> 'G_DS18B20_NBR_ROM_FOUND', #1 -> ('G_DS18B20_NBR_ROM_FOUND' - 1), etc.
	lds		REG_TEMP_R16, G_DS18B20_NBR_ROM_FOUND
	sub		REG_TEMP_R16, REG_TEMP_R17	
	subi		REG_TEMP_R16, 1
	lsl		REG_TEMP_R16
	lsl		REG_TEMP_R16
	lsl		REG_TEMP_R16
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16
	adc		REG_Z_MSB, REG_TEMP_R16

	lds		REG_TEMP_R16, G_DS18B20_FAMILLE
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
	lds		REG_TEMP_R18, G_DS18B20_IN_ALARM
	and		REG_TEMP_R17, REG_TEMP_R18
	breq		build_frame_infos_no_alarm
	sbr		REG_TEMP_R16, MSK_BIT7	; Etat d'alarme du Capteur dans REG_TEMP_R16<7>

build_frame_infos_no_alarm:
	pop		REG_Z_LSB
	pop		REG_Z_MSB
	std		Z + FRAME_IDX_ALR_RES_CONV, REG_TEMP_R16
	; End: Add  Etat du capteur en alarme ou non (bit #7 de 'FRAME_IDX_ALR_RES_CONV')

	; Calcul du CRC8
	ldi		REG_TEMP_R16, NBR_BITS_TO_SHIFT			; CRC8 sur les 7 bytes qui suivent 'Z + FRAME_IDX_CRC8'
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
	lds		REG_TEMP_R16, G_DS18B20_NBR_ROM_FOUND
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
	rcall		uos_print_1_byte_hexa_skip
	movw		REG_X_LSB, REG_Y_LSB
	rcall		uos_print_2_bytes_hexa_skip
	rcall		uos_print_line_feed_skip

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
	rcall		uos_print_1_byte_hexa_skip
	movw		REG_X_LSB, REG_Y_LSB
	rcall		uos_print_2_bytes_hexa_skip
	rcall		uos_print_line_feed_skip
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
	rcall		uos_print_mark_skip
	mov		REG_X_LSB, REG_TEMP_R18
	rcall		uos_print_2_bytes_hexa
	rcall		uos_print_y_reg
	rcall		uos_print_line_feed_skip
#endif

	; Emission de la trame
	ldi		REG_TEMP_R16, '$'
	rcall		uos_push_1_char_in_fifo_tx_skip

ds18b20_send_frame_loop:
	ld			REG_TEMP_R16, -Y
	rcall		convert_and_put_fifo_tx

	dec		REG_TEMP_R18
	brne		ds18b20_send_frame_loop

	rcall		uos_print_line_feed_skip
	rcall		fifo_tx_to_send_sync
	; Fin: Emission de la trame

	ret
; ---------

; ---------
; Configuration des DS18B20
; ---------

#ifndef USE_MINIMALIST
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
	rcall		uos_print_2_bytes_hexa_skip
	rcall		uos_print_line_feed_skip

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
#endif

text_prompt_ds18b20:
.db	"### ATtiny85_uOS+DS18B20 $Revision: 1.22 $", CHAR_LF, CHAR_NULL

text_msk_table:
.db	MSK_BIT0, MSK_BIT1, MSK_BIT2, MSK_BIT3
.db	MSK_BIT4, MSK_BIT5, MSK_BIT6, MSK_BIT7

;end:

.include		"ATtiny85_uOS+DS18B20_Timers.asm"

#ifndef USE_MINIMALIST
.include		"ATtiny85_uOS+DS18B20_Commands.asm"
#endif

.include		"ATtiny85_uOS+DS18B20_1_Wire.asm"
.include		"ATtiny85_uOS+DS18B20_Button.asm"

.include		"ATtiny85_DS18B20_1_Wire_Commands.asm"
 
.dseg
G_SRAM_END_OF_USE:		.byte	1

; End of file

