; "$Id: ATtiny85_uOS_Timers.asm,v 1.23 2025/12/15 22:42:20 administrateur Exp $"

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

	; Timer #N expire => Execution la methode initialisee dans le contexte si != 0x0000
	rcall		get_address_timer	

	tst		REG_TEMP_R20
	brne		gestion_timer_execute
	tst		REG_TEMP_R21
	brne		gestion_timer_execute

	; L'adresse est a 0x0000 -> Ignore
	rjmp		gestion_timer_restore

gestion_timer_execute:
	; L'adresse n'est pas a 0x0000 -> Execution effective @ Z ...
	movw		REG_Z_LSB, REG_TEMP_R20			; Adresse d'execution
	icall

gestion_timer_restore:
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
	cpi		REG_TEMP_R16, NBR_TIMER		; Tous les timers sont maj [#0, #1, #(NBR_TIMER - 1)] ?
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
;      ldi			REG_TEMP_R20, <address_lsb>   	 ; LSB value
;      ldi			REG_TEMP_R21, <address_msb>   	 ; MSB value
;      rcall      start_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16        -> Registre de travail
;    REG_TEMP_R17        -> Num timer #N (1st argument inchange apres execution)
;    REG_TEMP_R18        -> Duration LSB (2nd argument)
;    REG_TEMP_R19        -> Duration MSB (3rd argument)
;    REG_TEMP_R20        -> Adresse LSB de la methode callback
;    REG_TEMP_R21        -> Adresse MSB de la methode callback
; ---------
start_timer:
	push		REG_TEMP_R17

	cpi		REG_TEMP_R17, NBR_TIMER		; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brsh		start_timer_rtn				; Ignore si REG_TEMP_R17 >= NBR_TIMER

	; Calcul de l'offset...
	lsl		REG_TEMP_R17						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)
	clr		REG_TEMP_R16						; Indexation du timer #N

	ldi		REG_Y_LSB, (G_TIMER_0 % 256)	; Adresse de base des timers
	ldi		REG_Y_MSB, (G_TIMER_0 / 256)

	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N
	std		Y+0, REG_TEMP_R18					; Set duration LSB
	std		Y+1, REG_TEMP_R19					; Set duration MSB

	ldi		REG_Y_LSB, (G_TIMER_ADDRESS_0 % 256)	; Adresse de base des adresses callback
	ldi		REG_Y_MSB, (G_TIMER_ADDRESS_0 / 256)

	add		REG_Y_LSB, REG_TEMP_R17			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R16			; Report C -> YH => Y contient l'adresse du timer #N

	std		Y+0, REG_TEMP_R20					; Set address LSB
	std		Y+1, REG_TEMP_R21					; Set address MSB

start_timer_rtn:
	pop		REG_TEMP_R17
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
	push		REG_TEMP_R17

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
	pop		REG_TEMP_R17
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
	push		REG_TEMP_R17

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
	pop		REG_TEMP_R17
	ret
; ---------

; ---------
; Get address de callback d'un timer #N
;
; Usage:
;      ldi        REG_TEMP_R16, <timer_num>         ; Num in range [0, 1, ..., (NBR_TIMER-1)]
;      rcall      get_address_timer
;
; Registres utilises (non sauvegardes/restaures):
;    REG_Y_LSB:REG_Y_MSB -> Indexation du timer #N
;    REG_TEMP_R16        -> Registre de travail
;    REG_TEMP_R17        -> Num timer #N
;
; Retour:
;    REG_TEMP_R20        -> Adresse LSB de la methode callback
;    REG_TEMP_R21        -> Adresse MSB de la methode callback
; ---------
get_address_timer:
	cpi		REG_TEMP_R16, NBR_TIMER			; N dans la plage [0, 1, ..., (NBR_TIMER-1)] ?
	brcc		get_address_timer_err			; Saut si REG_TEMP_R17 >= NBR_TIMER

	push		REG_TEMP_R16						; Sauvegarde Num Timer

	ldi		REG_Y_LSB, (G_TIMER_ADDRESS_0 % 256)	; Non: Adresse de base des adresses callback
	ldi		REG_Y_MSB, (G_TIMER_ADDRESS_0 / 256)

	lsl		REG_TEMP_R16						; REG_TEMP_R17 *= 2 (Adresse sur des mots de 16 bits)

	clr		REG_TEMP_R17						; Indexation du timer #N
	add		REG_Y_LSB, REG_TEMP_R16			; YL += 2*N
	adc		REG_Y_MSB, REG_TEMP_R17			; Report C -> YH => Y contient l'adresse du timer #N

	ldd		REG_TEMP_R20, Y+0					; Maj dans R18:R19 du contexte
	ldd		REG_TEMP_R21, Y+1

get_address_timer_end:
	pop		REG_TEMP_R16						; Restauration Num Timer
	ret

get_address_timer_err:
	ret
; ---------

#ifndef USE_MINIMALIST_UOS
; ---------
; TIMER_CONNECT
; ---------
exec_timer_connect:
	; Passage en mode connecte pour une presentation Led GREEN --\__/-----
	cbr		REG_FLAGS_1, FLG_1_CONNECTED_MSK
	cbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_START_ERROR_MSK		; Effacement erreur de reception
	cbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_STOP_ERROR_MSK		; Effacement erreur de reception

	; Retour a la presentation "Non Connecte"
	ldi		REG_TEMP_R16, 0x01
	sts		G_CHENILLARD_MSB, REG_TEMP_R16
	sts		G_CHENILLARD_LSB, REG_TEMP_R16

	ret
; ---------
#endif

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

#ifndef USE_MINIMALIST_UOS
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
	ldi		REG_TEMP_R20, low(exec_timer_push_button_led)
	ldi		REG_TEMP_R21, high(exec_timer_push_button_led)
	rcall		start_timer
	; Fin: Presentation flash de 300mS sur Led YELLOW

	; Emission du prompt de l'appui button
	ldi		REG_Z_MSB, ((text_appui_bouton << 1) / 256)
	ldi		REG_Z_LSB, ((text_appui_bouton << 1) % 256)
	rcall		push_text_in_fifo_tx

	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

	; Prolongement si module ADDON detecte
	ldi		REG_TEMP_R17, EXTENSION_BUTTON
	rcall		exec_extension_addon

exec_timer_push_button_detect_rtn:
	ret
; ---------

; ---------
; TIMER_RXD_ANTI_REBONDS
; ---------
exec_timer_anti_rebound:
	cbr		REG_FLAGS_0, FLG_0_UART_DETECT_BIT_START_MSK
	ret
; ---------
#endif

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

	; Rearmement du Timer 'TIMER_LED_GREEN'
	ldi		REG_TEMP_R17, TIMER_LED_GREEN
	ldi		REG_TEMP_R18, (125 % 256)
	ldi		REG_TEMP_R19, (125 / 256)
	ldi		REG_TEMP_R20, low(exec_timer_led_green)
	ldi		REG_TEMP_R21, high(exec_timer_led_green)
	rcall		start_timer

	ret
; ---------

#if USE_DUMP_SRAM
; ---------
exec_timer_dump_sram:
	ldi		REG_Z_MSB, high(text_dump_sram << 1)
	ldi		REG_Z_LSB, low(text_dump_sram << 1)
	rcall		push_text_in_fifo_tx

	rcall		dump_sram_read

	;Reinitialisation timer 'TIMER_DUMP_SRAM'
	ldi		REG_TEMP_R17, TIMER_DUMP_SRAM
	ldi		REG_TEMP_R18, (10000 % 256)
	ldi		REG_TEMP_R19, (10000 / 256)
	ldi		REG_TEMP_R20, low(exec_timer_dump_sram)
	ldi		REG_TEMP_R21, high(exec_timer_dump_sram)
	rcall		start_timer

	ret
; ---------
#endif

#ifndef USE_MINIMALIST_UOS
text_appui_bouton:
.db	"### uOS: Button action", CHAR_LF, CHAR_NULL
#endif

#if 1
text_dump_sram:
.db	"### Dump SRAM...", CHAR_LF, CHAR_NULL
#endif

; End of file

