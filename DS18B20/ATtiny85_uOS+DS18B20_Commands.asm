; "$Id: ATtiny85_uOS+DS18B20_Commands.asm,v 1.2 2025/11/26 17:54:18 administrateur Exp $"

; Prolongation des commandes non supportees par uOS

.cseg

; ---------
exec_command_ds18b20:
	cpi		REG_TEMP_R16, CHAR_TYPE_COMMAND_C_MAJ
	breq		exec_command_type_C

	rjmp    print_command_ko        ; Commande non reconnue
; ---------

; ---------
; Execution de la commande 'C'
;
; Configuration des seuils d'alarme et de la resolution pour un capteur donne
; ou tous les capteurs reconnus sur le bud 1-Wire
;
; Usages:
; - "<C1+<seuil_tl>+<seuil_th>+<resolution>"
;
; avec:
; - <seuil_tl> et <seuil_th> dans la plage [0, 1, ..., 99] pour une temperature positive
;                            egale a [0, 1, ..., 99] degres °C
;                         et dans la plage [101, 102, ..., 155] pour une temperature negative
;                            egale a [-1, -2, ..., -55] degres °C
;
; Remarque: 0 et 100 correspondant a 0 °C
;
; Exemples:
; - "<C1+18+23+2" -> Configuration du capteur #1
; - "<C0+19+22+3" -> Configuration de tous les capteurs
; ---------
exec_command_type_C:
	; Inhibition des traces
	sbr		REG_FLAGS_0, FLG_0_PRINT_SKIP_MSK

	; Prise des parametre de la commande
	; => ie. "<C2+15+24+2" (#Id capteur + Tl + Th + Resolution)
	rcall		exec_command_type_C_get_params

	; Print des conversions valides ou invalides
	brts		exec_command_type_C_ko

exec_command_type_C_ok:
	call		print_command_ok
	rjmp		exec_command_type_C_print

exec_command_type_C_ko:
	call		print_command_ko

exec_command_type_C_print:
	lds		REG_X_LSB, (G_FRAME_ALL_INFOS + 0)
	rcall		print_1_byte_hexa
	lds		REG_X_LSB, (G_FRAME_ALL_INFOS + 1)
	rcall		print_1_byte_hexa
	lds		REG_X_LSB, (G_FRAME_ALL_INFOS + 2)
	rcall		print_1_byte_hexa
	lds		REG_X_LSB, (G_FRAME_ALL_INFOS + 3)
	rcall		print_1_byte_hexa
	rcall		print_line_feed

	ret
; ---------

; ---------
exec_command_type_C_get_params:
; ---------
	; Effacement des conversions des parametres
	clr		REG_TEMP_R16
	sts		(G_FRAME_ALL_INFOS + 0), REG_TEMP_R16		; #Id du capteur
	sts		(G_FRAME_ALL_INFOS + 1), REG_TEMP_R16		; 1st parametre (Tl)
	sts		(G_FRAME_ALL_INFOS + 2), REG_TEMP_R16		; 2nd parametre (Th)
	sts		(G_FRAME_ALL_INFOS + 3), REG_TEMP_R16		; 3rd parametre (Resolution)
	
	; #Id du capteur [0, 1, ..., 0xff]
   clr      REG_X_MSB
   lds      REG_X_LSB, G_TEST_VALUE_LSB

	; Test de l'Id capteur avec comme convention:
	; - Si 'G_DS18B20_NBR_ROM' == 0 -> Erreur
	; - Si 'REG_X_LSB' == 0 -> Adressage des capteurs #0, #1, #2, ..., #(G_DS18B20_NBR_ROM - 1)
	; - Si 'REG_X_LSB' dans la plage [1, 2, ..., G_DS18B20_NBR_ROM] -> Adressage du capteur #'REG_X_LSB'
	; - Sinon -> Erreur	
	lds		REG_TEMP_R16, G_DS18B20_NBR_ROM
	tst		REG_TEMP_R16
	breq		exec_command_type_C_not_valid

	tst		REG_X_LSB
	breq		exec_command_type_C_all_capteur		; Balayage des 'G_DS18B20_NBR_ROM' capteurs

	cp			REG_TEMP_R16, REG_X_LSB					; REG_X_LSB dans la plage [1, 2, ..., G_DS18B20_NBR_ROM]
	clr		REG_TEMP_R16
	cpc		REG_TEMP_R16, REG_X_MSB
	brpl		exec_command_type_C_this_capteur

	rjmp		exec_command_type_C_not_valid			; #Id hors plage @ 'G_DS18B20_NBR_ROM'

exec_command_type_C_all_capteur:
	lds		REG_TEMP_R18, G_DS18B20_NBR_ROM

exec_command_type_C_all_capteur_loop:
	push		REG_TEMP_R18

	mov		REG_X_LSB, REG_TEMP_R18
	rcall		exec_command_type_C_this_capteur

	pop		REG_TEMP_R18
	dec		REG_TEMP_R18
	brne		exec_command_type_C_all_capteur_loop	

	rjmp		exec_command_type_C_end

exec_command_type_C_this_capteur:
	dec		REG_X_LSB									; Formatage #Id dans la plage [0, 1, ..., (G_DS18B20_NBR_ROM - 1)]
	sts		(G_FRAME_ALL_INFOS + 0), REG_X_LSB

   ldi      REG_TEMP_R17, 'C'
   rcall     print_mark_skip
   rcall     print_2_bytes_hexa_skip
   rcall     print_line_feed_skip

	; 1st parametre (Tl)
	ldi		REG_Y_MSB, high(G_TEST_VALUES_ZONE)
	ldi		REG_Y_LSB, low(G_TEST_VALUES_ZONE)
	rcall		exec_command_type_C_convert_param
	brts		exec_command_type_C_not_valid

	sts		(G_FRAME_ALL_INFOS + 1), REG_X_LSB

	; 2nd parametre (Th)
	ldi		REG_Y_MSB, high(G_TEST_VALUES_ZONE + 2)
	ldi		REG_Y_LSB, low(G_TEST_VALUES_ZONE + 2)
	rcall		exec_command_type_C_convert_param
	brts		exec_command_type_C_not_valid

	sts		(G_FRAME_ALL_INFOS + 2), REG_X_LSB

	; 3rd parametre (Resolution)
	ldi		REG_Y_MSB, high(G_TEST_VALUES_ZONE + 4)
	ldi		REG_Y_LSB, low(G_TEST_VALUES_ZONE + 4)
	ldd		REG_X_LSB, Y+0

   rcall     print_1_byte_hexa_skip
   rcall     print_line_feed_skip

	cpi		REG_X_LSB, (3 + 1)		; [0, 1, 2, 3] admis
	brpl		exec_command_type_C_not_valid

	swap		REG_X_LSB					; Mise au format pour le 'scratchpad'
	lsl		REG_X_LSB
	ori		REG_X_LSB, 0x1f
	sts		(G_FRAME_ALL_INFOS + 3), REG_X_LSB

	ldi		REG_TEMP_R17, 'O'
	call		print_mark_skip

	rcall		ds18b20_write_scratchpad_x

	rcall		ds18b20_copy_scratchpad_x

	rjmp		exec_command_type_C_end

exec_command_type_C_not_valid:
	ldi		REG_TEMP_R16, 0xff
	sts		(G_FRAME_ALL_INFOS + 0), REG_TEMP_R16
	sts		(G_FRAME_ALL_INFOS + 1), REG_TEMP_R16
	sts		(G_FRAME_ALL_INFOS + 2), REG_TEMP_R16
	sts		(G_FRAME_ALL_INFOS + 3), REG_TEMP_R16

	lds		REG_TEMP_R16, G_TEST_FLAGS
	sbr		REG_TEMP_R16, FLG_TEST_CONFIG_ERROR_MSK
	sts		G_TEST_FLAGS, REG_TEMP_R16

exec_command_type_C_end:
	ret
; ---------

; ---------
exec_command_type_C_convert_param:
; ---------
	clr		REG_TEMP_R16
	sts		G_TEST_VALUE_DEC_MSB, REG_TEMP_R16		; Raz resultat decimal
	sts		G_TEST_VALUE_DEC_LSB, REG_TEMP_R16

	ldd		REG_X_LSB, Y+0
	ldd		REG_X_MSB, Y+1
   rcall     print_2_bytes_hexa_skip

	rcall		convert_val_for_ds18b20
	brts		exec_command_type_C_wrong
	rjmp		exec_command_type_C_valid

exec_command_type_C_wrong:
	ldi		REG_TEMP_R17, 'K'
	rcall		print_mark_skip
	set									; Car 'T' est modifie par 'uart_fifo_tx_write'
	rjmp		exec_command_type_C_more

exec_command_type_C_valid:
	ldi		REG_TEMP_R17, 'O'
	rcall		print_mark_skip
	rcall		print_1_byte_hexa_skip
   rcall     print_line_feed_skip
	clt									; Car 'T' est modifie par 'uart_fifo_tx_write'

exec_command_type_C_more:
	ret
; ---------

