; "$Id: ATtiny85_uOS_Timers.asm,v 1.3 2025/11/25 16:56:59 administrateur Exp $"

.include		"ATtiny85_uOS_Timers.h"

.cseg
; ---------
; Gestion des timers 16 bits; Durees [0, 1 mS, ..., ~65 Sec]
;
; Registres utilises (non sauvegardes/restaures):
;    REG_X_LSB:REG_X_MSB -> Valeur du timer #N et decrementation sur 16 bits
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_Z_LSB:REG_Z_MSB -> Adresse d'execution a l'expiration du timer #N (au moyen de 'icall' @Z)
;    REG_TEMP_R16        -> Compteur Timer #N dans la plage [#0, #1, #(NBR_TIMER - 1)]
; ---------
gestion_timer:
	; Comptabilisation dans tous les timers armes
	clr		REG_TEMP_R16

	ldi		REG_Z_LSB, (vector_timers % 256)	; Table des vecteurs d'execution des taches timer
	ldi		REG_Z_MSB, (vector_timers / 256)
	ldi		REG_Y_LSB, (G_TIMER_0 % 256)			; Table des valeurs sur 16 bits des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)	

gestion_timer_loop:
	ldd		REG_X_LSB, Y+0					; X = Duree du Timer #N
	ldd		REG_X_MSB, Y+1
	adiw		REG_X_LSB, 0					; Duree ?= 0
	breq		gestion_timer_next			; Passage au prochain timer si duree a 0

gestion_timer_decrement:
	; Le Timer #N est arme et non expire => Decrementation sur 16 bits et mise a jour duree
	sbiw		REG_X_LSB, 1

	std		Y+0, REG_X_LSB
	std		Y+1, REG_X_MSB

	brne		gestion_timer_next

	; Sauvegarde du contexte
	push		REG_TEMP_R16
	push		REG_Z_LSB
	push		REG_Z_MSB
	push		REG_Y_LSB
	push		REG_Y_MSB
	push		REG_X_LSB
	push		REG_X_MSB

	; Timer #N expire => Execution de la tache associee
	icall

	; Restauration du contexte
	pop		REG_X_MSB
	pop		REG_X_LSB
	pop		REG_Y_MSB
	pop		REG_Y_LSB
	pop		REG_Z_MSB
	pop		REG_Z_LSB
	pop		REG_TEMP_R16

gestion_timer_next:
	; Passage au prochain timer
	adiw		REG_Z_LSB, 1					; Adresse du traitement associe au prochain timer
	adiw		REG_Y_LSB, 2					; Acces au prochain timer de 16 bits
	inc		REG_TEMP_R16					; +1 dans le compteur de timer
	cpi		REG_TEMP_R16, NBR_TIMER		; Tous les timer sont maj [#0, #1, #(NBR_TIMER - 1)] ?
	brne		gestion_timer_loop			; TBC: brmi

gestion_timer_rtn:
	ret
; ---------

; ---------
; Armement d'un timer #N avec une duree sur 16 bits
; => La duree est ajoutee a celle restante permettant ainsi un rearmement
;    avant l'expiration a l'image d'un watchdog
;    => Warning: le timer peut ne jamais expirer si plusieurs armement sans un 'stop_timer'
;                car la duree est augmentee a chaque armement
;
; Usage:
;      ldi        REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      ldi			REG_TEMP_R18, <timer_value_lsb>   ; LSB value
;      ldi			REG_TEMP_R19, <timer_value_msb>   ; MSB value
;      rcall      start_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16        -> Registre de travail
;    REG_TEMP_R17        -> Num timer #N (1st argument inchange apres execution)
;    REG_TEMP_R18        -> Duration LSB (2nd argument)
;    REG_TEMP_R19        -> Duration MSB (3rd argument)
;    REG_TEMP_R20        -> Duration LSB restante avant ajout (duree totale apres ajout)
;    REG_TEMP_R21        -> Duration MSB restante avant ajout (duree totale apres ajout)
; ---------
start_timer:
	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brsh		start_timer_rtn				; Ignore si REG_TEMP_R17 >= NBR_TIMER

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Non: Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)
	clr		REG_TEMP_R16						; Indexation du timer #N
	clc
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	ldd		REG_TEMP_R20, Y+0				; Maj dans R20:R21 de la duree restante du timer indexe par Y
	ldd		REG_TEMP_R21, Y+1

	clc
	add		REG_TEMP_R20, REG_TEMP_R18	; Ajout de la duree passee en argument a celle restante
	adc		REG_TEMP_R21, REG_TEMP_R19

	std		Y+0, REG_TEMP_R20				; Set add duration LSB
	std		Y+1, REG_TEMP_R21				; Set add duration MSB

start_timer_rtn:
	ret
; ---------

; ---------
; Rearmement d'un timer #N avec une duree sur 16 bits
; => La nouvelle duree remplace la duree restante correspondant a un fonctionnement
;    'stop_timer' + 'start_timer'
;
; Usage:
;      ldi     REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      ldi		REG_TEMP_R18, <timer_value_lsb>   ; LSB value
;      ldi		REG_TEMP_R19, <timer_value_msb>   ; MSB value
;      rcall   restart_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16          -> Registre de travail
;    REG_TEMP_R17          -> Num timer #N (1st argument)
;    REG_TEMP_R18          -> Duration LSB (2nd argument)
;    REG_TEMP_R19          -> Duration MSB (3rd argument)
; ---------
restart_timer:
	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brsh		restart_timer_rtn				; Ignore si REG_TEMP_R17 >= NBR_TIMER

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Non: Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)
	clr		REG_TEMP_R16						; Indexation du timer #N
	clc
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	std		Y+0, REG_TEMP_R18				; Set add duration LSB
	std		Y+1, REG_TEMP_R19				; Set add duration MSB

restart_timer_rtn:
	ret
; ---------

; ---------
; Arret d'un timer #N
;
; Usage:
;      ldi     REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      rcall   stop_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16          -> Registre de travail
;    REG_TEMP_R17          -> Num timer #N (1st argument)
; ---------
stop_timer:
	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brsh		stop_timer_rtn					; Ignore si REG_TEMP_R17 >= NBR_TIMER

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Non: Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)
	clr		REG_TEMP_R16						; Indexation du timer #N
	clc
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	std		Y+0, REG_TEMP_R16				; Raz duration LSB
	std		Y+1, REG_TEMP_R16				; Raz duration MSB

stop_timer_rtn:
	ret
; ---------

; ---------
; Test d'un timer #N
;
; => La duree est retournee (a zero si time non arme ou expire)
;
; Usage:
;      ldi        REG_TEMP_R17, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      rcall      start_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16        -> Registre de travail
;    REG_TEMP_R17        -> Num timer #N (1st argument inchange apres execution)
;    REG_TEMP_R20        -> Duration LSB restante ou 0
;    REG_TEMP_R21        -> Duration MSB restante ou 0
;
; Retour:
;    Bit T de SREG   -> 0/1: Non arme ou expire / Arme en cours de decrementation
; ---------
test_timer:
	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brsh		test_timer_rtn					; Ignore si REG_TEMP_R17 >= NBR_TIMER

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Non: Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)
	clr		REG_TEMP_R16						; Indexation du timer #N
	clc
	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	ldd		REG_TEMP_R20, Y+0				; Maj dans R20:R21 de la duree restante du timer indexe par Y
	ldd		REG_TEMP_R21, Y+1

	set											; Timer a priori arme et non expire ...
	tst		REG_TEMP_R20
	brne		test_timer_rtn
	tst		REG_TEMP_R21
	brne		test_timer_rtn

	clt											; ... et non => Timer non arme ou expire

test_timer_rtn:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_0:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_1:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_2:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_3:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_4:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_5:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_6:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_7:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_8:
	ret
; ---------

; ---------
; TIMER_SPARE
; ---------
exec_timer_9:
	ret
; ---------

; ---------
; TIMER_CONNECT
; ---------
exec_timer_connect:
	; Passage en mode connecte pour une presentation Led GREEN --\__/-----
	lds		REG_TEMP_R16, G_FLAGS_2
	cbr		REG_TEMP_R16, FLG_2_CONNECTED_MSK
	sts		G_FLAGS_2, REG_TEMP_R16

	cbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_START_ERROR_MSK		; Effacement erreur de reception
	cbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_STOP_ERROR_MSK		; Effacement erreur de reception

	; Retour a la presentation "Non Connecte"
	ldi		REG_TEMP_R16, 0x01
	sts		G_CHENILLARD_MSB, REG_TEMP_R16
	sts		G_CHENILLARD_LSB, REG_TEMP_R16

	ret
; ---------

; ---------
; TIMER_ERROR
; ---------
exec_timer_error:
	; Fin de la presentation des erreurs Bits Start et Bit Stop
	cli
	setLedRedOff
	sei

	ret
; ---------

; ---------
; TIMER_APPUI_BOUTON_LED
; ---------
exec_timer_push_button_led:
	cli
	setLedYellowOff
	sei

	ret
; ---------

; ---------
; TIMER_APPUI_BOUTON_DETECT
; ---------
exec_timer_push_button_detect:
	; Presentation flash de 300mS sur Led YELLOW
	cli
	setLedYellowOn
	sei

	ldi		REG_TEMP_R17, TIMER_APPUI_BOUTON_LED
	ldi		REG_TEMP_R18, (300 % 256)
	ldi		REG_TEMP_R19, (300 / 256)
	rcall		restart_timer
	; Fin: Presentation flash de 300mS sur Led YELLOW

	; Emission en hexa du compteur 'G_NBR_VALUE_TRACE'
	ldi		REG_Z_MSB, ((text_appui_bouton << 1) / 256)
	ldi		REG_Z_LSB, ((text_appui_bouton << 1) % 256)
	rcall		push_text_in_fifo_tx

	lds		REG_TEMP_R16, G_NBR_VALUE_TRACE
	rcall		convert_and_put_fifo_tx
	; Fin: Emission en hexa du compteur 'G_NBR_VALUE_TRACE'

	; Emission en hexa du compteur 'G_NBR_ERRORS'
	ldi		REG_Z_MSB, ((text_appui_bouton_value_hexa << 1) / 256)
	ldi		REG_Z_LSB, ((text_appui_bouton_value_hexa << 1) % 256)
	rcall		push_text_in_fifo_tx

	lds		REG_TEMP_R16, G_NBR_ERRORS
	rcall		convert_and_put_fifo_tx
	; Fin: Emission en hexa du compteur 'G_NBR_ERRORS'

	; Emission en hexa de 'ASCII' de 'G_TEST_COMMAND_TYPE'
	ldi		REG_Z_MSB, ((text_appui_bouton_value_ascii << 1) / 256)
	ldi		REG_Z_LSB, ((text_appui_bouton_value_ascii << 1) % 256)
	rcall		push_text_in_fifo_tx

	lds		REG_TEMP_R16, G_TEST_COMMAND_TYPE
	rcall		push_1_char_in_fifo_tx
	; Fin: Emission en ASCII de 'G_TEST_COMMAND_TYPE'

	; Emission en hexa de 'G_TEST_VALUE_MSB:G_TEST_VALUE_LSB'
	ldi		REG_Z_MSB, ((text_appui_bouton_value_hexa << 1) / 256)
	ldi		REG_Z_LSB, ((text_appui_bouton_value_hexa << 1) % 256)
	rcall		push_text_in_fifo_tx

	lds		REG_TEMP_R16, G_TEST_VALUE_MSB
	rcall		convert_and_put_fifo_tx

	lds		REG_TEMP_R16, G_TEST_VALUE_LSB
	rcall		convert_and_put_fifo_tx
	; Fin: Emission en hexa de 'G_TEST_VALUE_MSB:G_TEST_VALUE_LSB'

	; Emission en hexa de 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE'
	ldi		REG_Z_MSB, ((text_appui_bouton_value_hexa << 1) / 256)
	ldi		REG_Z_LSB, ((text_appui_bouton_value_hexa << 1) % 256)
	rcall		push_text_in_fifo_tx

	lds		REG_TEMP_R16, G_TEST_VALUE_MSB_MORE
	rcall		convert_and_put_fifo_tx

	lds		REG_TEMP_R16, G_TEST_VALUE_LSB_MORE
	rcall		convert_and_put_fifo_tx
	; Fin: Emission en hexa de 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE'

	ldi		REG_Z_MSB, ((text_appui_bouton_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_appui_bouton_end << 1) % 256)
	rcall		push_text_in_fifo_tx

	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

	ret
; ---------

; ---------
; TIMER_RXD_ANTI_REBONDS
; ---------
exec_timer_anti_rebound:
	cbr		REG_FLAGS_0, FLG_0_UART_DETECT_BIT_START_MSK
	ret
; ---------

; ---------
; TIMER_LED_GREEN
; ---------
exec_timer_led_green:
	; Recuperation du chenillard de presentation de la Led GREEN
	lds		REG_TEMP_R16, G_CHENILLARD_MSB
	lds		REG_TEMP_R17, G_CHENILLARD_LSB

	; Allumage/Extinction atomique en fonction de G_CHENILLARD_LSB<0>
	cli
	sbr		REG_PORTB_OUT, MSK_BIT_LED_GREEN		; Extinction a priori Led GREEN ...
	sbrc		REG_TEMP_R17, IDX_BIT0
	cbr		REG_PORTB_OUT, MSK_BIT_LED_GREEN		; ... en fait, Allumage Led GREEN
	sei
	; Fin: Allumage/Extinction atomique en fonction de G_CHENILLARD_LSB<0>

	; Progression du chenillard
	lsr		REG_TEMP_R16							; G_CHENILLARD_MSB<0> -> Carry
	ror		REG_TEMP_R17							; Carry -> G_CHENILLARD_LSB<7> et G_CHENILLARD_LSB<0> -> Carry

	cbr		REG_TEMP_R16, MSK_BIT7				; Preparation '0' dans G_CHENILLARD_MSB<7> a priori ...
	brcc		exec_timer_led_green_more
	sbr		REG_TEMP_R16, MSK_BIT7				; ... et non, '1' dans G_CHENILLARD_MSB<7>

exec_timer_led_green_more:									; Ici, G_CHENILLARD_MSB<7> reflete la Carry
	sts		G_CHENILLARD_MSB, REG_TEMP_R16
	sts		G_CHENILLARD_LSB, REG_TEMP_R17
	; Fin: Chenillard de presentation de la Led GREEN

	; Armement du Timer #7
	ldi		REG_TEMP_R17, TIMER_LED_GREEN
	ldi		REG_TEMP_R18, (125 % 256)
	ldi		REG_TEMP_R19, (125 / 256)
	rcall		start_timer

	ret
; ---------

text_appui_bouton:
.db	"### Appui bouton [0x", CHAR_NULL, CHAR_NULL

text_appui_bouton_value_hexa:
.db	"] [0x", CHAR_NULL

text_appui_bouton_value_ascii:
.db	"] [", CHAR_NULL

text_appui_bouton_end:
.db	"] ", CHAR_LF, CHAR_NULL

; End of file

