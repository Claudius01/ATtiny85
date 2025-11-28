; "$Id: ATtiny85_uOS_Interrupts.asm,v 1.3 2025/11/28 14:03:22 administrateur Exp $"

.include		"ATtiny85_uOS_Interrupts.h"

.cseg
; ---------
; tim1_compa_isr
;
; Methode appele a chaque expiration du timer #1 interne (26 uS)
;
; => Traitements (Nbr de cycles maximal):
;    0 - Entree dans l'It + gestion de la pulse         -> 33 cycles max
;
;    1 - tim1_compa_isr_acq_rxd:     Acquisition de RXD pour detection ligne IDLE   -> 18 cycles max
;    2 - tim1_compa_isr_tx_send_bit: Emission d'un bit sur TXD + uart_fifo_rx_write -> 39 + 30 cycles max
;    3 - tim1_compa_isr_rx_rec_bit:  Reception d'un bit sur RXD                     -> 67 cycles max
;    4 - tim1_compa_isr_cpt_1ms:     Comptabilisation de 1 mS                       -> 15 cycles max
;
;      - Sortie de l'It + gestion de la pulse           -> 28 cycles max
;
;    => Total si les 4 traitements sont executes dans le meme tick: 28 + 169 + 33 = 230 cycles max
;
; Registres utilises:
;    REG_X_LSB:REG_X_MSB -> Comptabilisation des ticks dans 'G_TICK_1MS'
;    REG_TEMP_R16        -> Travail
;    REG_TEMP_R17        -> Travail
;    REG_TEMP_R18        -> Travail
;    REG_TEMP_R19        -> Travail
;    REG_PORTB_OUT       -> Image du PORTB
;    REG_SAVE_SREG       -> Sauvegarde temporaire de SREG
; ---------
tim1_compa_isr:
	push		REG_SAVE_SREG
	in			REG_SAVE_SREG, SREG

	push		REG_X_LSB
	push		REG_X_MSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18
	push		REG_TEMP_R19
	push		REG_TEMP_R20
	push		REG_TEMP_R21
	push		REG_TEMP_R22

; ---------
	; Determination du comportement
	lds		REG_TEMP_R16, G_BEHAVIOR
	sbrs		REG_TEMP_R16, FLG_BEHAVIOR_MARK_IN_TIM1_COMPA_IDX
	rjmp		tim1_compa_isr_more

	; Creneau --\_/--- pour indiquer la charge de travail dans l'It
	; => Pas de maj de 'REG_PORTB_OUT' si Led RED Externe allumee (sortie a 0)
	;    => Revient a ne pas generer la Pulse --\_/----
	sbrs		REG_FLAGS_1, FLG_1_LED_RED_ON_IDX
	cbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT

tim1_compa_isr_more:
	out		PORTB, REG_PORTB_OUT						; Raffraichissement du PORTB

; ---------
	; Lecture RXD pour detecter la ligne IDLE si pas deja detectee
	sbrc		REG_FLAGS_0, FLG_0_UART_DETECT_LINE_IDLE_IDX		; Line IDLE detectee ?
	rjmp		tim1_compa_isr_tx_send_bit								; Oui => Ignore acquisition

; ---------
	; Acquisition de RXD pour detection ligne IDLE (RXD durant au moins 10 bits -> 10 * 104 uS)
tim1_compa_isr_acq_rxd:
	sbis		PINB, IDX_BIT_RXD
	rjmp		tim1_compa_isr_acq_rxd_low

tim1_compa_isr_acq_rxd_high:
	lds		REG_X_MSB, G_UART_CPT_LINE_IDLE_MSB		; Reprise du compteur
	lds		REG_X_LSB, G_UART_CPT_LINE_IDLE_LSB

	sbiw		REG_X_LSB, 1						; X -= 1 sur 16 bits
	brne		tim1_compa_isr_acq_rxd_end

	; RXD a l'etat haut durant au moins 11 bits => Detection ligne IDLE
	sbr		REG_FLAGS_0, FLG_0_UART_DETECT_LINE_IDLE_MSK
	rjmp		tim1_compa_isr_acq_rxd_end

tim1_compa_isr_acq_rxd_low:
	cbr		REG_FLAGS_0, FLG_0_UART_DETECT_LINE_IDLE_MSK

	lds		REG_X_MSB, G_DURATION_DETECT_LINE_IDLE_MSB		; RXD a l'etat bas ->  Reinit compteur
	lds		REG_X_LSB, G_DURATION_DETECT_LINE_IDLE_LSB

tim1_compa_isr_acq_rxd_end:
	sts		G_UART_CPT_LINE_IDLE_MSB, REG_X_MSB		; Maj compteur d'acquisition
	sts		G_UART_CPT_LINE_IDLE_LSB, REG_X_LSB
	; Fin: Acquisition de RXD pour detection ligne IDLE

; ---------
	; Emission d'un bit sur TXD
tim1_compa_isr_tx_send_bit:
	sbrs		REG_FLAGS_0, FLG_0_UART_TX_TO_SEND_IDX			; Byte a emettre TXD ?
	rjmp		tim1_compa_isr_rx_rec_bit							; Non

	lds		REG_TEMP_R18, G_UART_CPT_NBR_BITS_TX			; Oui: Compteur de bits [11, 10, 9, ..., 0]
	lds		REG_TEMP_R17, G_UART_CPT_DURATION_1BIT_TX		;      Compteur d'attente 104 uS [3, 2, 1, 0]  
	tst		REG_TEMP_R17											; Fin de la duree d'attente de 104 uS ?
	brne		tim1_compa_isr_tx_send_bit_dec_duration

	; Au 1st traitement, 'G_UART_CPT_DURATION_1BIT_TX' est initialise a 0 pour debuter
	; immediatement la 1st attente de 104 uS -> reste donc 3 attentes a comptabiliser pour
	; emettre le bit suivant
	; 'G_UART_CPT_NBR_BITS_TX' est initialise a 11 pour 10 bits car represente 0 correspondra
	; a la fin du 10th bits -> Effacement de 'FLG_0_UART_TX_TO_SEND' pour indiquer la fin
	; de l'emission des 1 Bit Start + 8 Datas + 1, 2, ... Bit(s) Stop

	; Initialisation pour un Baud Rate configurable
	lds		REG_TEMP_R17, G_BAUDS_VALUE

	lds		REG_TEMP_R21, G_UART_BYTE_TX_LSB	; Reprise de la serialisation
	lds		REG_TEMP_R22, G_UART_BYTE_TX_MSB

	cbr		REG_PORTB_OUT, MSK_BIT_TXD			; Emission d'un '0' a priori
	sbrc		REG_TEMP_R21, 0						; par rapport a REG_TEMP_R21<0>

	sbr		REG_PORTB_OUT, MSK_BIT_TXD			; ... et non, emission d'un '1'

	out		PORTB, REG_PORTB_OUT					; Ecriture PORTB sans attendre la sortie de l'It

	sec													; Propagation Carry a 1 (MSB ne contient que des '1' ;-)
	ror		REG_TEMP_R22							; Serialisation...
	ror		REG_TEMP_R21							; Preparation nouveau REG_TEMP_R21<0> a emettre

	sts		G_UART_BYTE_TX_LSB, REG_TEMP_R21	; Maj pour la prochaine expiration des 104 uS
	sts		G_UART_BYTE_TX_MSB, REG_TEMP_R22

	dec		REG_TEMP_R18										; Test si les 10 bits ont ete emis ?
	brne		tim1_compa_isr_tx_send_bit_update

	cbr		REG_FLAGS_0, FLG_0_UART_TX_TO_SEND_MSK		; Oui: Fin de l'emission des 10 bits

	sbr		REG_PORTB_OUT, MSK_BIT_TXD    	; TXD a l'etat haut
	rjmp		tim1_compa_isr_tx_send_bit_end

tim1_compa_isr_tx_send_bit_dec_duration:
	dec		REG_TEMP_R17

tim1_compa_isr_tx_send_bit_update:
	sts		G_UART_CPT_DURATION_1BIT_TX, REG_TEMP_R17
	sts		G_UART_CPT_NBR_BITS_TX, REG_TEMP_R18

tim1_compa_isr_tx_send_bit_end:
	; Fin: Emission d'un bit sur TXD

; ---------
	; Reception d'un bit sur RXD
	; => Acquisition si 'FLG_0_UART_DETECT_LINE_IDLE' et 'FLG_0_UART_DETECT_BIT_START' a 1 
tim1_compa_isr_rx_rec_bit:

	sbrs		REG_FLAGS_0, FLG_0_UART_DETECT_LINE_IDLE_IDX
	rjmp		tim1_compa_isr_rx_rec_bit_end

	sbrs		REG_FLAGS_0, FLG_0_UART_DETECT_BIT_START_IDX
	rjmp		tim1_compa_isr_rx_rec_bit_end

	; Fin de la duree d'attente de 52uS (Bit Start) ou 104 uS (Data et Bit Stop) ?
	lds		REG_TEMP_R17, G_UART_CPT_DURATION_1BIT_RX
	lds		REG_TEMP_R18, G_UART_CPT_NBR_BITS_RX

	tst		REG_TEMP_R17
	brne		tim1_compa_isr_rx_rec_bit_dec_duration

	; Marquage du moment d'acquisition
	; Determination du comportement
	lds		REG_TEMP_R17, G_BEHAVIOR
	sbrs		REG_TEMP_R17, FLG_BEHAVIOR_MARK_IN_RX_REC_BIT_IDX
	rjmp		tim1_compa_isr_rx_rec_bit_more

	; => Pas de maj de 'REG_PORTB_OUT' si Led RED Externe allumee (sortie a 0)
	;    => Revient a ne pas generer la Pulse --\_/----
	sbrs		REG_FLAGS_1, FLG_1_LED_RED_ON_IDX
	cbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT						; Raffraichissement du PORTB

tim1_compa_isr_rx_rec_bit_more:
	; Reinitialisation de la duree d'attente
	lds		REG_TEMP_R17, G_BAUDS_VALUE
	sts		G_UART_CPT_DURATION_1BIT_RX, REG_TEMP_R17

	; Lecture RXD au milieu bit
	clc											; A priori RXD a 0
	sbic		PINB, IDX_BIT_RXD
	sec											; et Non: RXD a 1

	lds		REG_TEMP_R22, G_UART_BYTE_RX_MSB		; Reprise du mot de reception RXD sur 16 bits
	lds		REG_TEMP_R21, G_UART_BYTE_RX_LSB
	ror		REG_TEMP_R22								; Construction de sDDD DDDD DS00 0000 ([S]tart/[s]top)
	ror		REG_TEMP_R21								; par propagation de la Carry (Bit LSB recu en premier)
	sts		G_UART_BYTE_RX_MSB, REG_TEMP_R22
	sts		G_UART_BYTE_RX_LSB, REG_TEMP_R21

	; Fin: Marquage du moment d'acquisition
	; => Pas de maj de 'REG_PORTB_OUT' si Led RED Externe allumee (sortie a 0)
	;    => Revient a ne pas generer la Pulse --\_/----
	sbrc		REG_FLAGS_1, FLG_1_LED_RED_ON_IDX
	rjmp		tim1_compa_isr_rx_rec_ignore_pulse

	rcall		delay_1uS
	rcall		delay_1uS
	sbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT

tim1_compa_isr_rx_rec_ignore_pulse:
	out		PORTB, REG_PORTB_OUT				; Raffraichissement du PORTB

	; Comptabilisation du bit lu
	dec		REG_TEMP_R18
	sts		G_UART_CPT_NBR_BITS_RX, REG_TEMP_R18

	brne		tim1_compa_isr_rx_rec_bit_end

	; Les 10 ont ete lus...
	; => Bit Start de nouveau a detecter
	cbr		REG_FLAGS_0, FLG_0_UART_DETECT_BIT_START_MSK

	; Extraction des Bits Start/Stop et 8 bits de donnees
	lsl		REG_TEMP_R21	; Recuperation des 8 bits dans 'REG_TEMP_R21' et Bit Stop dans la Carry
	rol		REG_TEMP_R22	; Donnees recues D7...D0 dans 'REG_TEMP_R22' et Bit Start dans 'REG_TEMP_R22<D7>'

	; Reception complete (G_UART_BYTE_RX_MSB:LSB (R21:R22) ?= sDDD DDDD DS00 0000)
	; => Test du bit Start ('0')
	sbrc		REG_TEMP_R21, IDX_BIT7			; Test du Bit Start dans 'REG_TEMP_R22<D7>' (erreur si a 1)
	rjmp		tim1_compa_isr_rx_rec_bit_start_err

	; => Detection Break (Bit Stop a '0' et Datas a 0x00)
	; => Test du bit Stop ('1')
	brcs		tim1_compa_isr_rx_rec_bit_ok	; Test du Bit Stop dans la Carry (Ok si a 1)

	; => Test des Datas a 0x00
	tst		REG_TEMP_R22
	brne		tim1_compa_isr_rx_rec_bit_stop_err

tim1_compa_isr_rx_rec_break:
	; Detection d'un byte "break" (10 bits a 0 succedant un etat de RXD a 1)
	cbr		REG_FLAGS_0, FLG_0_UART_DETECT_LINE_IDLE_IDX		; Line Idle de nouveau a detecter
	rjmp		tim1_compa_isr_rx_rec_bit_end

tim1_compa_isr_rx_rec_bit_ok:
	mov		REG_R1, REG_TEMP_R22
	rcall		uart_fifo_rx_write
 
	sbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_RECEIVED_MSK		; Donnee recue valide ou "Break" disponible
	rjmp		tim1_compa_isr_rx_rec_bit_end
	; Reception complete sans erreur et byte recu disponible dans 'REG_TEMP_R21'

tim1_compa_isr_rx_rec_bit_start_err:
	sbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_START_ERROR_MSK
	rjmp		tim1_compa_isr_rx_rec_bit_err

tim1_compa_isr_rx_rec_bit_stop_err:
	sbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_STOP_ERROR_MSK

tim1_compa_isr_rx_rec_bit_err:
	; Effacement des Flags pour une nouvelle reception correcte
	cbr		REG_FLAGS_0, (FLG_0_UART_DETECT_LINE_IDLE_IDX | FLG_0_UART_DETECT_BIT_START_IDX | FLG_0_UART_RX_BYTE_RECEIVED_IDX)

	; Comptabilisation des erreurs RXD et FIFO
	rcall		update_errors
	rjmp		tim1_compa_isr_rx_rec_bit_end

tim1_compa_isr_rx_rec_bit_dec_duration:
	dec		REG_TEMP_R17
	sts		G_UART_CPT_DURATION_1BIT_RX, REG_TEMP_R17

tim1_compa_isr_rx_rec_bit_end:
	; Fin: Reception d'un bit sur RXD
; ---------

	; Comptabilisation de 1 mS
tim1_compa_isr_cpt_1ms:
	; => Si 'FLG_0_PERIODE_1MS' est a 1 (1mS atteinte a la precedente It) => Ne rien faire en attendre
	;       que 'FLG_0_PERIODE_1MS' passe a 0
	; => Sinon; si 'G_TICK_1MS' passe a 0 (1mS atteinte) => 'FLG_0_PERIODE_1MS' = 1 => Non maj 'G_TICK_1MS'
	;    Sinon decrementation et maj 'G_TICK_1MS'
	;
	sbrc		REG_FLAGS_0, FLG_0_PERIODE_1MS_IDX
	rjmp		tim1_compa_isr_cpt_1ms_end

	lds		REG_X_LSB, G_TICK_1MS
	tst		REG_X_LSB							; X ?= 0
	brne		tim1_compa_isr_cpt_1ms_dec		; 

	sbr		REG_FLAGS_0, FLG_0_PERIODE_1MS_MSK		; Oui: Set 'FLG_0_PERIODE_1MS'
	rjmp		tim1_compa_isr_cpt_1ms_end					; Fin sans maj de 'G_TICK_1MS'

tim1_compa_isr_cpt_1ms_dec:
	subi		REG_X_LSB, 1			
	sts		G_TICK_1MS, REG_X_LSB

tim1_compa_isr_cpt_1ms_end:
	; Fin: Comptabilisation de 1 mS

; ---------
	; Reecriture des flags generaux

	; Fin: Creneau --\_/---
	; => Pas de maj de 'REG_PORTB_OUT' si Led RED Externe allumee (sortie a 0)
	;    => Revient a ne pas generer la Pulse --\_/----
	sbrs		REG_FLAGS_1, FLG_1_LED_RED_ON_IDX
	sbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT				; Raffraichissement du PORTB

	; Qualification 'delay_1uS'
	lds		REG_TEMP_R17, G_BEHAVIOR
	sbrs		REG_TEMP_R17, FLG_BEHAVIOR_CALIBRATION_1_uS
	rjmp		tim1_compa_isr_cpt_1ms_rtn

	cbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT				; Raffraichissement du PORTB

	rcall		uos_delay_10uS

	sbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT				; Raffraichissement du PORTB
	; Fin: Qualification 'delay_1uS'

tim1_compa_isr_cpt_1ms_rtn:
	pop		REG_TEMP_R22
	pop		REG_TEMP_R21
	pop		REG_TEMP_R20
	pop		REG_TEMP_R19
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_X_MSB
	pop		REG_X_LSB

	out		SREG, REG_SAVE_SREG
	pop		REG_SAVE_SREG

	reti
; ---------

; ---------
; pcint0_isr
;
; Methode appelee sur changement d'etat sur PINB<0> (RXD)
; => Detection du Bit UART/START si REG_FLAGS_0<FLG_0_UART_DETECT_BIT_START> a 0
;    apres une detection reussie d'une ligne IDLE REG_FLAGS_0<FLG_0_UART_DETECT_LINE_IDLE> a 1
;    ou la reception d'un byte UART (1 Start + 8 Datas + 1 ou 2 Stop)
;
; Registres utilises (sauvegardes/restaures):
;    REG_TEMP_R16 -> Travail
; ---------
pcint0_isr:
	push		REG_SAVE_SREG
	in			REG_SAVE_SREG, SREG

	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_Y_MSB
	push		REG_Y_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18
	push		REG_TEMP_R19

	; Fronts montant et descendant detectes sur RXD
	sbic		PINB, IDX_BIT_RXD
	rjmp		pcint0_isr_rising			; RXD a 1
	rjmp		pcint0_isr_falling		; RXD a 0

pcint0_isr_rising:

	; Detection du front montant sur RXD __/--
	; => Arret du timer 'TIMER_APPUI_BOUTON_DETECT'
	ldi		REG_TEMP_R17, TIMER_APPUI_BOUTON_DETECT
	rcall		stop_timer

	rjmp		pcint0_isr_rtn

pcint0_isr_falling:
	sbrs		REG_FLAGS_0, FLG_0_UART_DETECT_LINE_IDLE_IDX		; Line IDLE detectee ?
	rjmp		pcint0_isr_rtn												; Non => Ignore --\__ sur RXD

	sbrc		REG_FLAGS_0, FLG_0_UART_DETECT_BIT_START_IDX		; Bit START detecte ?
	rjmp		pcint0_isr_rtn												; Oui => Ignore --\__ sur RXD

	; Marquage du moment d'acquisition
	; Determination du comportement
	lds		REG_TEMP_R17, G_BEHAVIOR
	sbrs		REG_TEMP_R17, FLG_BEHAVIOR_MARK_IN_PCINT0_IDX
	rjmp		pcint0_isr_falling_more

	; => Pas de maj de 'REG_PORTB_OUT' si Led RED Externe allumee (sortie a 0)
	;    => Revient a ne pas generer la Pulse --\_/----
	sbrs		REG_FLAGS_1, FLG_1_LED_RED_ON_IDX
	cbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT						; Raffraichissement du PORTB

pcint0_isr_falling_more:
	; Raz erreurs Bits Start et Bit Stop
	cbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_START_ERROR_MSK
	cbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_STOP_ERROR_MSK

	sbr		REG_FLAGS_0, FLG_0_UART_DETECT_BIT_START_MSK		; Bit Start detecte
	cbr		REG_FLAGS_0, FLG_0_UART_RX_BYTE_RECEIVED_MSK		; Donnee valide a recevoir

	; Rearmement timer pour "annuler" tous les rebonds < 50mS
	ldi		REG_TEMP_R17, TIMER_RXD_ANTI_REBONDS
	ldi		REG_TEMP_R18, (50 % 256)
	ldi		REG_TEMP_R19, (50 / 256)
	rcall		restart_timer

	; Rearmement timer 'TIMER_APPUI_BOUTON_DETECT'
	ldi		REG_TEMP_R17, TIMER_APPUI_BOUTON_DETECT
	ldi		REG_TEMP_R18, (100 % 256)
	ldi		REG_TEMP_R19, (100 / 256)
	rcall		restart_timer

	; Preparation reception bit RXD
	lds		REG_TEMP_R16, G_DURATION_WAIT_READ_BIT_START		; Attente de 26uS * x avant de lire le Bit Start
	sts		G_UART_CPT_DURATION_1BIT_RX, REG_TEMP_R16

	ldi		REG_TEMP_R16, 10			; 10 bits: 1 Bit Start + 8 Datas + 1 Bit Stop
	sts		G_UART_CPT_NBR_BITS_RX, REG_TEMP_R16

	clr		REG_TEMP_R16
	sts		G_UART_BYTE_RX_MSB, REG_TEMP_R16
	sts		G_UART_BYTE_RX_LSB, REG_TEMP_R16
	; Fin: Preparation reception bit RXD (a supprimer a terme)

	; Fin: Marquage du moment d'acquisition
	; => Pas de maj de 'REG_PORTB_OUT' si Led RED Externe allumee (sortie a 0)
	;    => Revient a ne pas generer la Pulse --\_/----
	sbrc		REG_FLAGS_1, FLG_1_LED_RED_ON_IDX
	rjmp		pcint0_isr_ignore_pulse

	rcall		trace_in_it_double_1uS
	sbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT

pcint0_isr_ignore_pulse:
	out		PORTB, REG_PORTB_OUT						; Raffraichissement du PORTB

pcint0_isr_rtn:
	pop		REG_TEMP_R19
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_Y_LSB
	pop		REG_Y_MSB
	pop		REG_X_LSB
	pop		REG_X_MSB

	out		SREG, REG_SAVE_SREG
	pop		REG_SAVE_SREG
	reti
; ---------
