; "$Id: ATtiny85_uOS_Commands.asm,v 1.9 2025/12/02 14:31:06 administrateur Exp $"

.include		"ATtiny85_uOS_Commands.h"

.cseg

; ---------
; Interpretation d'une commande recue
;
; Usage:
;		 rcall	interprete_command		; Lecture de la FIFO/Rx
;
; Registres utilises (sauvegarde/restaures):
;    REG_TEMP_R16 -> Caractere a convertir et a ajouter apres x10
;    REG_TEMP_R17 -> Working register
;    
; Warning: Pas de test du 'char' passe en argument dans la plage ['0,', '1', ..., '9']
; Remarque: Lecture de la FIFO/Rx jusqu'au vidage
;
; Retour ajoute a 'G_TEST_VALUE_MSB:G_TEST_VALUE_LSB' par decalage et sans raz
; => Raz a la charge de l'interpretation de la valeur
; ---------
interpret_command:

interpret_command_loop:
	cli
	rcall		uart_fifo_rx_read			; Lecture atomique
	sei

	brtc		interpret_command_rtn	; Nouvelle donnee disponible ?

	lds		REG_TEMP_R17, G_TEST_FLAGS

	; Oui. -> Caractere dans 'REG_R2'
	mov		REG_TEMP_R16, REG_R2
	cpi		REG_TEMP_R16, CHAR_COMMAND_REC
	brne		interpret_command_loop_more

	; Le prochain caractere sera le type de la commande
	sbr		REG_TEMP_R17, FLG_TEST_COMMAND_TYPE_MSK
	sts		G_TEST_FLAGS, REG_TEMP_R17
	rjmp		interpret_command_loop

interpret_command_loop_more:
	cpi		REG_TEMP_R16, CHAR_COMMAND_MORE
	brne		interpret_command_loop_more_2

	sbr		REG_TEMP_R17, FLG_TEST_COMMAND_MORE_MSK
	sts		G_TEST_FLAGS, REG_TEMP_R17
	rjmp		interpret_command_loop

interpret_command_loop_more_2:
	cpi		REG_TEMP_R16, CHAR_COMMAND_PLUS
	brne		interpret_command_loop_more_2A

	; Effacement de 'G_TEST_VALUES_ZONE' sur le 1st 'CHAR_COMMAND_PLUS
	sbrs		REG_TEMP_R17, FLG_TEST_COMMAND_PLUS_IDX
	rcall		raz_value_into_zone

	; Ajout 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE' a 'G_TEST_VALUES_ZONE'
	; precedent 'CHAR_COMMAND_PLUS'
	sbrc		REG_TEMP_R17, FLG_TEST_COMMAND_PLUS_IDX
	rcall		add_value_into_zone

	; Force maj 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE'
	sbr		REG_TEMP_R17, (FLG_TEST_COMMAND_MORE_MSK | FLG_TEST_COMMAND_PLUS_MSK)
	sts		G_TEST_FLAGS, REG_TEMP_R17
	rjmp		interpret_command_loop

interpret_command_loop_more_2A:
	cpi		REG_TEMP_R16, CHAR_LF
	brne		interpret_command_loop_more_3

	; Ajout 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE' a 'G_TEST_VALUES_ZONE'
	sbrc		REG_TEMP_R17, FLG_TEST_COMMAND_PLUS_IDX
	rcall		add_value_into_zone

	rcall		exec_command								; Execution de la commande

	; Lancement de l'emission
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK
	rjmp		interpret_command_rtn

interpret_command_loop_more_3:
	sbrs		REG_TEMP_R17, FLG_TEST_COMMAND_TYPE_IDX
	rjmp		interpret_command_loop_more_4

	sts		G_TEST_COMMAND_TYPE, REG_TEMP_R16	; Save command type

	; Raz des donnees de la commande a recevoir
	clr		REG_TEMP_R16
	sts		G_TEST_VALUE_MSB, REG_TEMP_R16
	sts		G_TEST_VALUE_LSB, REG_TEMP_R16
	sts		G_TEST_VALUE_MSB_MORE, REG_TEMP_R16
	sts		G_TEST_VALUE_LSB_MORE, REG_TEMP_R16

	lds		REG_TEMP_R16, G_TEST_VALUES_IDX_WRK
	sts		G_TEST_VALUES_IDX, REG_TEMP_R16

	; Effacement pour prendre la valeur qui suit avec eventuellement des donnees a suivre
	cbr		REG_TEMP_R17, (FLG_TEST_COMMAND_TYPE_MSK | FLG_TEST_COMMAND_MORE_MSK | FLG_TEST_COMMAND_PLUS_MSK)
	sts		G_TEST_FLAGS, REG_TEMP_R17
	rjmp		interpret_command_loop

interpret_command_loop_more_4:
	rcall		char_to_hex_incremental		; Construction de 'G_TEST_VALUE_MSB:G_TEST_VALUE_LSB'
	rjmp		interpret_command_loop

interpret_command_rtn:
	ret
; ---------

; ---------
; - Echo de la commande avec ses parametres
; ---------
uos_print_command_ok:
print_command_ok:
	; Echo de la commande reconnue avec uniquement l'adresse
	; => ie. "[34>zA987-4321]"
	;
	lds		REG_TEMP_R17, G_TEST_FLAGS
	cbr		REG_TEMP_R17, FLG_TEST_COMMAND_ERROR_MSK

	ldi		REG_TEMP_R16, CHAR_COMMAND_SEND
	rjmp		print_command

uos_print_command_ko:
print_command_ko:
	; Echo de la commande non reconnue avec ses parametres
	; => ie. "34?zA987-4321" si commande non reconnue
	;
	lds		REG_TEMP_R17, G_TEST_FLAGS
	sbr		REG_TEMP_R17, FLG_TEST_COMMAND_ERROR_MSK

	ldi		REG_TEMP_R16, CHAR_COMMAND_UNKNOWN

print_command:
	sts		G_TEST_FLAGS, REG_TEMP_R17					; Maj Flag 'FLG_TEST_COMMAND_ERROR'

	rcall		push_1_char_in_fifo_tx						; '>' eor '?'

	lds		REG_TEMP_R16, G_TEST_COMMAND_TYPE
	rcall		push_1_char_in_fifo_tx

	; 1st argument sur 16 bits de la commande
	lds		REG_TEMP_R16, G_TEST_VALUE_MSB
	rcall		convert_and_put_fifo_tx

	lds		REG_TEMP_R16, G_TEST_VALUE_LSB
	rcall		convert_and_put_fifo_tx
	; Fin: Echo de la commande avec uniquement l'adresse

	ldi		REG_Z_MSB, ((text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_lf_end << 1) % 256)
	rcall		push_text_in_fifo_tx

	ret
; ---------

; ---------
; Execution de la commande recue
; ---------
exec_command:
	ldi		REG_TEMP_R16, '['
	rcall		push_1_char_in_fifo_tx

	; Comptabilisation et print des executions
	lds		REG_TEMP_R16, G_NBR_VALUE_TRACE
	inc		REG_TEMP_R16
	sts		G_NBR_VALUE_TRACE, REG_TEMP_R16

	; Compteur d'execution commande sur 8 bits
	lds		REG_TEMP_R16, G_NBR_VALUE_TRACE
	rcall		convert_and_put_fifo_tx

	; Fin: Comptabilisation et print des executions

	; Liste des commandes supportees
	lds		REG_TEMP_R16, G_TEST_COMMAND_TYPE

exec_command_test_a_min:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_A_MIN
	breq		exec_command_type_A

exec_command_test_b_maj:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_B_MAJ
	brne		exec_command_test_f_min
	rjmp		exec_command_type_B

exec_command_test_f_min:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_F_MIN
	brne		exec_command_test_s_read
	rjmp		exec_command_type_f_min

exec_command_test_s_read:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_S_READ
	brne		exec_command_test_s_write
	rjmp		exec_command_type_s_read

exec_command_test_s_write:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_S_WRITE
	brne		exec_command_test_e_read
	rjmp		exec_command_type_s_write

exec_command_test_e_read:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_E_READ
	brne		exec_command_test_e_write
	rjmp		exec_command_type_e_read

exec_command_test_e_write:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_E_WRITE
	brne		exec_command_test_p
	rjmp		exec_command_type_e_write

exec_command_test_p:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_P_READ
	brne		exec_command_test_x
	rjmp		exec_command_type_p_read

exec_command_test_x:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_X
	brne		exec_command_ko
	rjmp		exec_command_type_x
	; Fin: Liste des commandes supportees par uOS

exec_command_ko:
	; La commande n'est pas supportee par uOS
	; => Prolongement si module 'DS18B20' defini
	;
#ifdef USE_DS18B20
#ifndef USE_MINIMALIST
	rcall		exec_command_ds18b20
#endif
#else
	rcall		print_command_ko			; Commande non reconnue
#endif

	ret
; ---------

; ---------
; Execution de la commande 'A'
; ---------
exec_command_type_A:

	rcall		print_command_ok

	clr		REG_X_MSB			; Calcul a partir de l'adresse 0x0000
	clr		REG_X_LSB

	; Raz CRC8
	clr		REG_TEMP_R16
	sts		G_CALC_CRC8, REG_TEMP_R16

exec_command_A_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	; Remarque: Division par 2 car dump de word ;-)
	lsr		REG_X_MSB
	ror		REG_X_LSB
	rcall		print_2_bytes_hexa

	; Retablissement de 'X' qui est toujours pair ici
	lsl		REG_X_LSB
	rol		REG_X_MSB

	; Impression du dump ("[0x....]")
	; => TODO: Si saut 'end_of_program' est de la forme 0xhhh0, pas de valeur apres [0x...]
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	rcall		push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 32

exec_command_A_loop_1:
	; Valeur de la memoire programme indexee par 'REG_X_MSB:REG_X_LSB'
	movw		REG_Z_LSB, REG_X_LSB
	adiw		REG_X_LSB, 1								; Preparation prochain byte

	; Calcul jusqu'a l'adresse 'end_of_program' incluse
	ldi		REG_TEMP_R16, 0x01
	and		REG_TEMP_R16, REG_X_LSB
	breq		exec_command_A_loop_1_cont_d			; Lecture par mot

	push		REG_X_MSB
	push		REG_X_LSB
	lsr		REG_X_MSB
	ror		REG_X_LSB

	ldi		REG_TEMP_R16, low(end_of_program - 1)
	cp			REG_TEMP_R16, REG_X_LSB

	ldi		REG_TEMP_R16, high(end_of_program - 1)
	cpc		REG_TEMP_R16, REG_X_MSB

	pop		REG_X_LSB
	pop		REG_X_MSB
	brmi		exec_command_A_end
	; Fin: Calcul jusqu'a l'adresse 'end_of_program' incluse

exec_command_A_loop_1_cont_d:
	ldi		REG_TEMP_R16, 0x01
	eor		REG_Z_LSB, REG_TEMP_R16		; Lecture MSB puis LSB
	lpm		REG_TEMP_R16, Z
	push		REG_TEMP_R16
	rcall		convert_and_put_fifo_tx

	pop		REG_TEMP_R16
	rcall		calc_crc8_maxim

	dec		REG_TEMP_R18
	brne		exec_command_A_loop_1

	ldi		REG_TEMP_R16, ']'
	rcall		push_1_char_in_fifo_tx

	push		REG_X_LSB
	lds		REG_X_LSB, G_CALC_CRC8
	rcall		print_1_byte_hexa
	rcall		print_line_feed
	pop		REG_X_LSB

	rjmp		exec_command_A_loop_0

exec_command_A_end:
	ldi		REG_TEMP_R16, ']'
	rcall		push_1_char_in_fifo_tx

	push		REG_X_LSB
	lds		REG_X_LSB, G_CALC_CRC8
	rcall		print_1_byte_hexa
	rcall		print_line_feed
	pop		REG_X_LSB

	; Impression du resultat comme "[CRC8-MAXIM [0x0000][0x06f6][0x3c]]"
	push		REG_Z_MSB
	push		REG_Z_LSB
	ldi		REG_Z_MSB, ((text_crc8_maxim_label << 1) / 256)
	ldi		REG_Z_LSB, ((text_crc8_maxim_label << 1) % 256)
	rcall		push_text_in_fifo_tx
	pop		REG_Z_LSB
	pop		REG_Z_MSB

	ldi		REG_Y_MSB, 0
	ldi		REG_Y_LSB, 0
	rcall		print_y_reg

	; Recadrage pour une adresse "imprimable"
	lsr		REG_Z_MSB
	ror		REG_Z_LSB
	sbiw		REG_Z_LSB, 1
	rcall		print_z_reg
	; Fin: Impression du resultat comme "[CRC8-MAXIM [0x0000][0x06f6][0x3c]]"

	push		REG_X_LSB
	lds		REG_X_LSB, G_CALC_CRC8
	rcall		print_1_byte_hexa
	rcall		print_line_feed
	pop		REG_X_LSB

exec_command_A_rtn:
#if 0
	ldi		REG_TEMP_R17, 'c'
	rcall		print_mark
	lds		REG_X_LSB, G_CALC_CRC8
	rcall		print_1_byte_hexa
	rcall		print_line_feed
#endif

	ret
; ---------

; ---------
; Execution de la commande 'B'
;
; Reprogrammation du Baud Rate
; - "<B0": 19200 bauds
; - "<B1":  9600 bauds
; - "<B2":  4800 bauds
; - "<B3":  2400 bauds
; - "<B4":  1200 bauds
; - "<B5":   600 bauds
; - "<B6":   300 bauds
; ---------
exec_command_type_B:
	; Recuperation de l'index
	clr		REG_X_MSB
	lds		REG_X_LSB, G_TEST_VALUE_LSB

	; Multiplication par 4 pour acceder a chaque quadruplet de la table 'const_for_bauds_rate'
	; => Pas de report dans 'REG_X_MSB' car 6 resultats dans la plage [0, 4, 8, 12, 16, 20 et 24]]
	lsl		REG_X_LSB
	lsl		REG_X_LSB

	ldi		REG_Z_MSB, high(const_for_bauds_rate << 1)
	ldi		REG_Z_LSB, low(const_for_bauds_rate << 1)
	add		REG_Z_LSB, REG_X_LSB	
	adc		REG_Z_MSB, REG_X_MSB	

	; Adresse du dernier quadruplet cadree sur un mot
	ldi		REG_TEMP_R17, low((const_for_bauds_rate_end - 1 - 1) << 1)
	cp			REG_TEMP_R17, REG_Z_LSB
	ldi		REG_TEMP_R17, high((const_for_bauds_rate_end - 1 - 1) << 1)
	cpc		REG_TEMP_R17, REG_Z_MSB
	brmi		exec_command_type_B_ko		; Z <= 'Adresse du dernier quadruplet' ?

exec_command_type_B_ok:			; -> Yes (adresse de copie dans la plage ;-)
	ldi		REG_X_MSB, high(G_BAUDS_VALUE)
	ldi		REG_X_LSB, low(G_BAUDS_VALUE)

	; Recopie atomique...
	cli
	lpm		REG_TEMP_R16, Z+
	st			X+, REG_TEMP_R16
	lpm		REG_TEMP_R16, Z+
	st			X+, REG_TEMP_R16
	lpm		REG_TEMP_R16, Z+
	st			X+, REG_TEMP_R16
	lpm		REG_TEMP_R16, Z+
	st			X+, REG_TEMP_R16
	sei

	rcall		print_command_ok			; Commande executee
	ret

exec_command_type_B_ko:					; -> No (adresse de copie hors de la plage ;-)
	rcall		print_command_ko			; Commande non executee (index trop grand)
	ret
; ---------

; ---------
; Execution de la commande 's'
; => Dump de la SRAM: "<sAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du 1st byte a lire (si 0xAAAA == 0x0000 => Debut en SRAM_START
;    - 0xBBBB: le nombre de blocs de 16 bytes
;    - La lecture et l'emission sont effectuees 8 bytes par 8 bytes
;      avec une limitation des adresses dans la plage [SRAM_START, ..., RAMEND]
;
; Reponse: "[NN>sAAAA-BBBB]"
;          "[0xAAAA] [0xd0d1d2d3d4d5d6d7...]" (0xAAAA actualise @ adresse en cours)
; ---------
exec_command_type_s_read:
	rcall		print_command_ok			; Commande reconnue

	; Recuperation de l'adresse du 1st byte a lire
	lds		REG_X_MSB, G_TEST_VALUE_MSB
	lds		REG_X_LSB, G_TEST_VALUE_LSB

	tst		REG_X_MSB
	brne		exec_command_type_s_read_cont_d
	tst		REG_X_LSB
	brne		exec_command_type_s_read_cont_d

	ldi		REG_X_MSB, (SRAM_START / 256)
	ldi		REG_X_LSB, (SRAM_START % 256)

	; Dump de toute la SRAM
	; TODO: Calcul @ 'SRAM_START' et 'RAMEND'
	ldi		REG_TEMP_R17, 32
	rjmp		exec_command_type_s_read_loop_0

exec_command_type_s_read_cont_d:
	; Dump sur 8 x 16 bytes
	; TODO: Get 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE'
	ldi		REG_TEMP_R17, 8

exec_command_type_s_read_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	rcall		print_2_bytes_hexa

	; Impression du dump ("[0x....]")
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	rcall		push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 16

exec_command_type_s_read_loop_1:
	; Valeur de la SRAM indexee par 'REG_X_MSB:REG_X_LSB'
	ld			REG_TEMP_R16, X+
	rcall		convert_and_put_fifo_tx

	; Test limite 'RAMEND'
	; => On suppose qu'au depart 'X <= RAMEND'
	cpi		REG_X_MSB, ((RAMEND + 1) / 256)
	brne		exec_command_type_s_read_more2
	cpi		REG_X_LSB, ((RAMEND + 1) % 256)
	brne		exec_command_type_s_read_more2

	; Astuce pour gagner du code de presentation ;-)
	ldi		REG_TEMP_R18, 1
	ldi		REG_TEMP_R17, 1

exec_command_type_s_read_more2:
	dec		REG_TEMP_R18
	brne		exec_command_type_s_read_loop_1

	ldi		REG_Z_MSB, ((text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_lf_end << 1) % 256)
	rcall		push_text_in_fifo_tx

	dec		REG_TEMP_R17
	brne		exec_command_type_s_read_loop_0

	ret
; ---------

; ---------
; Execution de la commande 'S'
; => Ecriture de plusieurs bytes dans la SRAM: "<SAAAA+BB+CC+DD..." avec:
;    - 0xAAAA: l'adresse du 1st byte a ecrire
;    - 0xBB:   la valeur 1st du byte a ecrire
;    - 0xCC:   la valeur 2nd du byte a ecrire
;    ...
;
; Reponse: "[NN>SAAAA]"
; ---------
exec_command_type_s_write:
	rcall		print_command_ok			; Commande reconnue

	; Prise du nombre de mots passes en arguments
	lds		REG_X_LSB, G_TEST_VALUES_IDX_WRK
	lsr		REG_X_LSB									; REG_X_LSB /= 2 pour nbr de bytes a ecrire

	mov		REG_TEMP_R18, REG_X_LSB
	; Fin: Prise du nombre de mots passes en arguments

	; Recuperation de l'adresse du 1st byte a ecrire
	lds		REG_X_MSB, G_TEST_VALUE_MSB
	lds		REG_X_LSB, G_TEST_VALUE_LSB

	; Test de 'REG_X_MSB:REG_X_LSB' dans la plage [SRAM_START, ..., 'G_SRAM_END_OF_USE'[
	; => Adresse 'G_SRAM_END_OF_USE' exclue de la plage ;-)
	ldi		REG_TEMP_R16, low(SRAM_START)
	cp			REG_X_LSB, REG_TEMP_R16
	ldi		REG_TEMP_R16, high(SRAM_START)
	cpc		REG_X_MSB, REG_TEMP_R16
	brlo		exec_command_type_s_write_out_of_range		; Saut si X <= 'Adresse du 1er byte de la SRAM'

	ldi		REG_TEMP_R16, low(G_SRAM_END_OF_USE)
	cp			REG_X_LSB, REG_TEMP_R16
	ldi		REG_TEMP_R16, high(G_SRAM_END_OF_USE)
	cpc		REG_X_MSB, REG_TEMP_R16
	brsh		exec_command_type_s_write_out_of_range		; Saut si X > 'Adresse du dernier byte utilise de la SRAM'

	rcall		print_command_ok			; Commande reconnue

	; Lecture des 'REG_TEMP_R18' mots de la SRAM dont seule la partie LSB sera ecrite
	mov		REG_TEMP_R17, REG_TEMP_R18
	ldi		REG_Y_MSB, high(G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(G_TEST_VALUES_ZONE)

exec_command_type_s_write_loop:
	cli

	ld			REG_TEMP_R16, Y
	st			X, REG_TEMP_R16

	adiw		REG_X_LSB, 1			; Adresse SRAM suivante
	adiw		REG_Y_LSB, 2			; Saut au prochain mot
	dec		REG_TEMP_R17
	brne		exec_command_type_s_write_loop

	sei

	rjmp		exec_command_type_s_write_end

exec_command_type_s_write_out_of_range:
	rcall		print_command_ko			; Commande non executee

exec_command_type_s_write_end:
	ret
; ---------

; ---------
; Execution de la commande 'e'
; => Dump de l'EEPROM: "<eAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du 1st byte a lire (si 0xAAAA == 0x0000 => Debut a l'adresse 0 de l'EEPROM
;    - 0xBBBB: le nombre de blocs de 16 bytes
;    - La lecture et l'emission sont effectuees 8 bytes par 8 bytes
;      avec une limitation des adresses dans la plage [0, ..., EEPROMEND]
;
; Reponse: "[NN>eAAAA]"
;          "[0xAAAA] [0xd0d1d2d3d4d5d6d7...]" (0xAAAA actualise @ adresse en cours)
; ---------
exec_command_type_e_read:
	rcall		print_command_ok			; Commande reconnue

	; Recuperation de l'adresse du 1st byte a lire
	lds		REG_X_MSB, G_TEST_VALUE_MSB
	lds		REG_X_LSB, G_TEST_VALUE_LSB

	tst		REG_X_MSB
	brne		exec_command_type_e_read_cont_d
	tst		REG_X_LSB
	brne		exec_command_type_e_read_cont_d

	; Dump de toute l'EEPROM
	; TODO: Calcul @ 'EEPROMEND'
	ldi		REG_TEMP_R17, 32
	rjmp		exec_command_type_e_read_loop_0

exec_command_type_e_read_cont_d:
	; Dump sur 8 x 16 bytes
	; TODO: Get 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE'
	ldi		REG_TEMP_R17, 8

exec_command_type_e_read_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	rcall		print_2_bytes_hexa

	; Impression du dump ("[0x....]")
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	rcall		push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 16

exec_command_type_e_read_loop_1:
	; Valeur de l'EEPROM indexee par 'REG_X_MSB:REG_X_LSB'
	rcall		eeprom_read_byte
	rcall		convert_and_put_fifo_tx

	adiw		REG_X_LSB, 1

	; Test limite 'EEPROMEND'
	; => On suppose qu'au depart 'X <= EEPROMEND'
	cpi		REG_X_MSB, ((EEPROMEND + 1) / 256)
	brne		exec_command_type_e_read_more2
	cpi		REG_X_LSB, ((EEPROMEND + 1) % 256)
	brne		exec_command_type_e_read_more2

	; Astuce pour gagner du code de presentation ;-)
	ldi		REG_TEMP_R18, 1
	ldi		REG_TEMP_R17, 1

exec_command_type_e_read_more2:
	dec		REG_TEMP_R18
	brne		exec_command_type_e_read_loop_1

	ldi		REG_Z_MSB, ((text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_lf_end << 1) % 256)
	rcall		push_text_in_fifo_tx

	dec		REG_TEMP_R17
	brne		exec_command_type_e_read_loop_0

	ret
; ---------

; ---------
; Execution de la commande 'E'
; => Ecriture d'une suite de N bytes dans l'EEPROM (N dans [1, 2, ...])
;    - 0xAAAA:    l'adresse du byte a ecrire dans l'EEPROM
;
; Reponse: "[NN>EAAAA]" (Adresse du byte a ecrire)
; ---------
exec_command_type_e_write:
	; Prise du nombre de mots passes en arguments
	lds		REG_X_LSB, G_TEST_VALUES_IDX_WRK
	lsr		REG_X_LSB									; REG_X_LSB /= 2 pour nbr de bytes a ecrire

	mov		REG_TEMP_R18, REG_X_LSB
	; Fin: Prise du nombre de mots passes en arguments

	; Recuperation de l'adresse du 1st byte a ecrire
	lds		REG_X_MSB, G_TEST_VALUE_MSB
	lds		REG_X_LSB, G_TEST_VALUE_LSB

	; Test de 'REG_X_MSB:REG_X_LSB' dans la plage [0, ..., EEPROMEND] @ 'REG_TEMP_R18'
	ldi		REG_TEMP_R16, low(EEPROMEND + 2)
	ldi		REG_TEMP_R17, high(EEPROMEND + 2)
	sub		REG_TEMP_R16, REG_TEMP_R18
	sbci		REG_TEMP_R17, 0					; Soustraction 16 bits (report de la Carry)

	cp			REG_X_LSB, REG_TEMP_R16		
	cpc		REG_X_MSB, REG_TEMP_R17		
	brpl		exec_command_type_e_write_out_of_range
	; Fin: Test de 'REG_X_MSB:REG_X_LSB' dans la plage [0, ..., EEPROMEND] @ 'REG_TEMP_R18'

	rcall		print_command_ok			; Commande reconnue

	; Lecture des 'REG_TEMP_R18' mots de la SRAM dont seule la partie LSB sera ecrite
	mov		REG_TEMP_R17, REG_TEMP_R18
	ldi		REG_Y_MSB, high(G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(G_TEST_VALUES_ZONE)

	; Clear error
	lds		REG_TEMP_R16, G_TEST_FLAGS
	cbr		REG_TEMP_R16, FLG_TEST_EEPROM_ERROR_MSK
	sts		G_TEST_FLAGS, REG_TEMP_R16

exec_command_type_e_write_loop:
	ld			REG_TEMP_R16, Y
	rcall		eeprom_write_byte

	; Verification de l'ecriture
	mov		REG_TEMP_R18, REG_TEMP_R16		; Save data writed
	clr		REG_TEMP_R16						; Raz before read eeprom @ 'X'
	rcall		eeprom_read_byte	

	cpse		REG_TEMP_R16, REG_TEMP_R18
	rjmp		exec_command_type_e_write_ko
	; Fin: Verification de l'ecriture

	adiw		REG_X_LSB, 1			; Adresse EEPROM suivante
	adiw		REG_Y_LSB, 2			; Saut au prochain mot
	dec		REG_TEMP_R17
	brne		exec_command_type_e_write_loop

	rjmp		exec_command_type_e_write_end

exec_command_type_e_write_ko:
	ldi      REG_Z_MSB, ((text_eeprom_error << 1) / 256)
	ldi      REG_Z_LSB, ((text_eeprom_error << 1) % 256)
	rcall    push_text_in_fifo_tx
	rcall		print_2_bytes_hexa
	rcall    print_line_feed

	lds		REG_TEMP_R16, G_TEST_FLAGS
	sbr		REG_TEMP_R16, FLG_TEST_EEPROM_ERROR_MSK
	sts		G_TEST_FLAGS, REG_TEMP_R16
	rjmp		exec_command_type_e_write_end

exec_command_type_e_write_out_of_range:
	rcall		print_command_ko			; Commande non executee

exec_command_type_e_write_end:
	ret
; ---------

; ---------
; Execution de la commande 'f'
; => Lecture des fuses
; ---------
exec_command_type_f_min:
	rcall		print_command_ok			; Commande reconnue

; Definition du bit 'RSIG' car non attribue dans 'tn85def.inc'
.equ	RSIG = 5		; Read Device Signature Imprint Table

	; Signature...
	ldi		REG_TEMP_R16, (1 << RSIG) | (1 << SPMEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x00
	lpm		REG_X_LSB, Z
	rcall		print_1_byte_hexa

	ldi		REG_TEMP_R16, (1 << RSIG) | (1 << SPMEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x02
	lpm		REG_X_LSB, Z
	rcall		print_1_byte_hexa

	ldi		REG_TEMP_R16, (1 << RSIG) | (1 << SPMEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x04
	lpm		REG_X_LSB, Z
	rcall		print_1_byte_hexa

	rcall		print_line_feed
	; Fin: Signature...

	; Read Fuse Low Byte
	ldi		REG_TEMP_R16, (1 << RFLB) | (1 << SELFPRGEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x00
	lpm		REG_X_LSB, Z
	rcall		print_1_byte_hexa

	; Read Lock bits
	ldi		REG_TEMP_R16, (1 << RFLB) | (1 << SELFPRGEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x01
	lpm		REG_X_LSB, Z
	rcall		print_1_byte_hexa

	; Read Read Fuse Extended Byte
	ldi		REG_TEMP_R16, (1 << RFLB) | (1 << SELFPRGEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x02
	lpm		REG_X_LSB, Z
	rcall		print_1_byte_hexa

	; Read Fuse High Byte
	ldi		REG_TEMP_R16, (1 << RFLB) | (1 << SELFPRGEN)
	out		SPMCSR, REG_TEMP_R16

	ldi		REG_Z_MSB, 0x00
	ldi		REG_Z_LSB, 0x03
	lpm		REG_X_LSB, Z
	rcall		print_1_byte_hexa

	rcall		print_line_feed

	set													; Commande reconnue
	ret
; ---------

; ---------
; Execution de la commande 'p'
; => Dump de la memoire programme: "<pAAAA-BBBB" avec:
;    - 0xAAAA: l'adresse du 1st word a lire
;    - 0xBBBB: le nombre de blocs de 16 bytes
;    - La lecture et l'emission sont effectuees 8 bytes par 8 bytes
;
; Reponse: "[NN>pAAAA-BBBB]"
;          "[0xAAAA] [0xd0d1d2d3d4d5d6d7...]" (0xAAAA actualise @ adresse en cours)
; ---------
exec_command_type_p_read:
	rcall		print_command_ok			; Commande reconnue

	; Recuperation de l'adresse du 1st byte a lire
	lds		REG_X_MSB, G_TEST_VALUE_MSB
	lds		REG_X_LSB, G_TEST_VALUE_LSB

	; Adresse sur des mots
	lsl		REG_X_LSB
	rol		REG_X_MSB

	ldi		REG_TEMP_R17, 8

exec_command_type_p_read_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	; Remarque: Division par 2 car dump de word ;-)
	push		REG_X_MSB
	push		REG_X_LSB

	lsr		REG_X_MSB
	ror		REG_X_LSB
	rcall		print_2_bytes_hexa

	pop		REG_X_LSB
	pop		REG_X_MSB

	; Impression du dump ("[0x....]")
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	rcall		push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 16

exec_command_type_p_read_loop_1:
	; Valeur de la memoire programme indexee par 'REG_X_MSB:REG_X_LSB'
	movw		REG_Z_LSB, REG_X_LSB
	adiw		REG_X_LSB, 1						; Preparation prochain byte

	lpm		REG_TEMP_R16, Z
	rcall		convert_and_put_fifo_tx

	dec		REG_TEMP_R18
	brne		exec_command_type_p_read_loop_1

	ldi		REG_Z_MSB, ((text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_lf_end << 1) % 256)
	rcall		push_text_in_fifo_tx

	dec		REG_TEMP_R17
	brne		exec_command_type_p_read_loop_0

	ret
; ---------

; ---------
; Execution de la commande 'x'
; => Execution d'une methode
; ---------
exec_command_type_x:
	rcall		print_command_ok			; Commande reconnue

	; Recuperation de l'adresse d'execution
	lds		REG_Z_MSB, G_TEST_VALUE_MSB
	lds		REG_Z_LSB, G_TEST_VALUE_LSB

	; Si execution du 'Reset' (adresse 0x0000)
	; => Reinitialisation de 'SPH:SPL' a 'RAMEND'
	tst		REG_Z_MSB
	brne		exec_command_type_x_more

	tst		REG_Z_LSB
	brne		exec_command_type_x_more

	ldi		REG_TEMP_R16, high(RAMEND)
	out		SPH, REG_TEMP_R16

	ldi		REG_TEMP_R16, low(RAMEND)
	out		SPL, REG_TEMP_R16
	; Fin: Si execution du 'Reset' (adresse 0x0000)

	; Saut a un programme dont l'adresse est passe en argument
	; avec d'eventuels parametres apres 'CHAR_COMMAND_PLUS'
	; => Remarque: Le 'ret' en fin de programme fera retourner apres
	;              l'instruction 'rcall exec_command'
exec_command_type_x_more:
	ijmp
; ---------

; ---------
; Conversion ASCII -> Decimal-16 bits
;
; Usage:
;		 rcall	char_to_dec_incremental		; 'REG_TEMP_R16' in ['0,', '1', ..., '9', 'A', ..., 'F'
;
; Registres utilises (sauvegarde/restaures):
;    REG_TEMP_R16 -> Caractere a convertir et a ajouter apres x10
;    REG_TEMP_R17 -> Working register
;    
; Warning: Pas de test du 'char' passe en argument dans la plage ['0,', '1', ..., '9']
;
; Retour ajoute a 'G_TEST_VALUE_DEC_MSB:G_TEST_VALUE_DEC_LSB' par decalage et sans raz
; => Raz a la charge de l'interpretation de la valeur
; ---------
char_to_dec_incremental:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_Y_MSB
	push		REG_Y_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17

	lds		REG_X_LSB, G_TEST_VALUE_DEC_LSB	; Reprise valeur -> X
	lds		REG_X_MSB, G_TEST_VALUE_DEC_MSB

	; Multiplication par 10 = 2 x 5
	lsl		REG_X_LSB
	rol		REG_X_MSB							; X = 2X
	movw		REG_Y_LSB, REG_X_LSB				; Y = 2X

	; REG_TEMP_R17 = 4: 1st pass: X = 2X + 2X = 4X
	; REG_TEMP_R17 = 3: 2nd pass: X = 4X + 2X = 6X
	; REG_TEMP_R17 = 2: 3rd pass: X = 6X + 2X = 8X
	; REG_TEMP_R17 = 1: 4th pass: X = 8X + 2X = 10X => Fin

	ldi		REG_TEMP_R17, 4

char_to_dec_incremental_loop:
	add		REG_X_LSB, REG_Y_LSB				; X += 2X
	adc		REG_X_MSB, REG_Y_MSB
	dec		REG_TEMP_R17
	brne		char_to_dec_incremental_loop

	; Conversion et addition
	subi		REG_TEMP_R16, '0'
	add		REG_X_LSB, REG_TEMP_R16			; X += REG_TEMP_R16
	adc		REG_X_MSB, REG_TEMP_R17			; X += 0 + C

	sts		G_TEST_VALUE_DEC_LSB, REG_X_LSB
	sts		G_TEST_VALUE_DEC_MSB, REG_X_MSB

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
; Conversion ASCII -> Hexa-16 bits
;
; Usage:
;		 rcall	char_to_hex_incremental	; 'REG_R2' in ['0,', '1', ..., '9', 'A', ..., 'F'
;
; Registres utilises (sauvegarde/restaures):
;    REG_TEMP_R16 -> Caractere a convertir et a ajouter apres x16
;    REG_TEMP_R17 -> Working register
;    
; Warning: Pas de test du 'char' passe en argument dans la plage ['0,', '1', ..., '9', 'A', ..., 'F']
;
; Retour ajoute a 'G_TEST_VALUE_MSB:G_TEST_VALUE_LSB'
; ---------
char_to_hex_incremental:
	push		REG_TEMP_R16
	push		REG_TEMP_R17

	; Discrimination...
	lds		REG_TEMP_R16, G_TEST_FLAGS
	sbrc		REG_TEMP_R16, FLG_TEST_COMMAND_MORE_IDX
	rjmp		char_to_hex_incremental_more

	lds		REG_X_LSB, G_TEST_VALUE_LSB			; Reprise valeur -> X
	lds		REG_X_MSB, G_TEST_VALUE_MSB
	rjmp		char_to_hex_incremental_cont_d

char_to_hex_incremental_more:
	lds		REG_X_LSB, G_TEST_VALUE_LSB_MORE		; Reprise valeur -> X
	lds		REG_X_MSB, G_TEST_VALUE_MSB_MORE
	; Fin: Discrimination...

char_to_hex_incremental_cont_d:
	mov		REG_TEMP_R16, REG_R2				; Recuperation valeur a concatener

	; REG_TEMP_R17 = 4: 1st pass: X = 2X
	; REG_TEMP_R17 = 3: 2nd pass: X = 4X
	; REG_TEMP_R17 = 2: 3rd pass: X = 8X
	; REG_TEMP_R17 = 1: 4th pass: X = 16X => Fin

	ldi		REG_TEMP_R17, 4

char_to_hex_incremental_loop:
	lsl		REG_X_LSB				; X *= 2
	rol		REG_X_MSB
	dec		REG_TEMP_R17
	brne		char_to_hex_incremental_loop

	; Conversion ['0', ... , '9'] = [0x30, ... , 0x39] -> [0x0, ..., 0x9]
	;            ['A', ... , 'F'] = [0x41, ... , 0x46] -> [0xa, ..., 0xf]
	;            ['a', ... , 'f'] = [0x61, ... , 0x66] -> [0xa, ..., 0xf]
	;
	sbrc		REG_TEMP_R16, IDX_BIT6			; ['0', ... , '9'] ?
	rjmp		char_to_hex_incremental_a_f	; Non

char_to_hex_incremental_0_9:					; Oui
	subi		REG_TEMP_R16, '0'
	rjmp		char_to_hex_incremental_add

char_to_hex_incremental_a_f:
	cbr		REG_TEMP_R16, MSK_BIT5			; Lowercase -> Uppercase ('a' (0x61) -> 'A' (0x41))
	subi		REG_TEMP_R16, ('A' - 0xa)		; 'A' -> 0xa, ..., 'F' -> 0xf

char_to_hex_incremental_add:
	andi		REG_TEMP_R16, 0x0f				; Filtre Bits<3,0> (precaution ;-)
	or			REG_X_LSB, REG_TEMP_R16			; X |= REG_TEMP_R16

	; Discrimination...
	lds		REG_TEMP_R16, G_TEST_FLAGS
	sbrc		REG_TEMP_R16, FLG_TEST_COMMAND_MORE_IDX
	rjmp		char_to_hex_incremental_more_2

	sts		G_TEST_VALUE_LSB, REG_X_LSB
	sts		G_TEST_VALUE_MSB, REG_X_MSB
	rjmp		char_to_hex_incremental_end

char_to_hex_incremental_more_2:
	sts		G_TEST_VALUE_LSB_MORE, REG_X_LSB
	sts		G_TEST_VALUE_MSB_MORE, REG_X_MSB
	; Fin: Discrimination...

char_to_hex_incremental_end:

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	ret
; ---------

; ---------
; Raz de 'G_TEST_VALUES_ZONE'
; ---------
raz_value_into_zone:
	push		REG_Y_MSB
	push		REG_Y_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17

	clr		REG_TEMP_R16
	sts		G_TEST_VALUES_IDX_WRK, REG_TEMP_R16

	ldi		REG_Y_MSB, high(G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(G_TEST_VALUES_ZONE)

	ldi		REG_TEMP_R16, 32
	clr		REG_TEMP_R17

raz_value_into_zone_loop:
	st			Y+, REG_TEMP_R17
	st			Y+, REG_TEMP_R17

	dec		REG_TEMP_R16
	brne		raz_value_into_zone_loop

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_Y_LSB
	pop		REG_Y_MSB

	ret
; ---------

; Recopie de 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE' a 'G_TEST_VALUES_ZONE'
; ---------
add_value_into_zone:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_Y_MSB
	push		REG_Y_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17

	lds		REG_TEMP_R16, G_TEST_VALUES_IDX_WRK
	ldi		REG_Y_MSB, high(G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(G_TEST_VALUES_ZONE)
	clr		REG_TEMP_R17
	add		REG_Y_LSB, REG_TEMP_R16
	adc		REG_Y_MSB, REG_TEMP_R17

	lds		REG_X_MSB, G_TEST_VALUE_MSB_MORE
	lds		REG_X_LSB, G_TEST_VALUE_LSB_MORE

	std		Y+0, REG_X_LSB			; LSB en tete
	std		Y+1, REG_X_MSB

	inc		REG_TEMP_R16			; Next word
	inc		REG_TEMP_R16
	sts		G_TEST_VALUES_IDX_WRK, REG_TEMP_R16

	; Raz donnee
	clr		REG_TEMP_R16
	sts		G_TEST_VALUE_MSB_MORE, REG_TEMP_R16
	sts		G_TEST_VALUE_LSB_MORE, REG_TEMP_R16

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_X_LSB
	pop		REG_X_MSB

	ret
; ---------

text_crc8_maxim_label:
.db	"[CRC8-MAXIM ", CHAR_NULL, CHAR_NULL

; End of file

