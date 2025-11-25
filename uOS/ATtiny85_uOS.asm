; "$Id: ATtiny85_uOS.asm,v 1.2 2025/11/25 07:47:14 administrateur Exp $"

; - Projet: ATtiny85_uOS.asm
;
; r1.2 - Reprise du projet 'ATtiny85_P5' en integrant les sources inclus:
;        .include   "ATtiny85_uOS_P5.tst"
;        .include   "ATtiny85_uOS_P5.sub"
;
;      - Suppression des directives de plus utilisees et du code mort
;
; - Avertissement: Etude pour l'utilisation d'un ATtiny85-20
;   => Le DigiSpark utilise un ATtiny85-10 cadence a 10 Mhz
;

.include		"tn85def.inc"              ; Labels and identifiers for tiny85
.include		"ATtiny85_uOS.h"

.cseg
.org	0x000 
	rjmp		main					; Vector:  1 - reset
	rjmp		int0_isr				; Vector:  2 - int0_isr
	rjmp		pcint0_isr			; Vector:  3 - pcint0_isr
	rjmp		tim1_compa_isr		; Vector:  4 - tim1_compa_isr
	rjmp		tim1_ovf_isr		; Vector:  5 - tim1_ovf_isr
	rjmp		tim0_ovf_isr		; Vector:  6 - tim0_ovf_isr
	rjmp		ee_rdy_isr			; Vector:  7 - ee_rdy_isr
	rjmp		ana_cmp_isr			; Vector:  8 - ana_cmp_isr
	rjmp		adc_isr				; Vector:  9 - adc_isr
	rjmp		tim1_compb_isr		; Vector: 10 - tim1_compb_isr
	rjmp		tim0_compa_isr		; Vector: 11 - tim0_compa_isr
	rjmp		tim0_compb_isr 	; Vector: 12 - tim0_compb_isr
	rjmp		wdt_isr				; Vector: 13 - wdt_isr
	rjmp		usi_start_isr		; Vector: 14 - usi_start_isr
	rjmp		usi_ovf_isr			; Vector: 15 - usi_ovf_isr

; NE PAS SUPPRIMER les 'nop' (test des '.org')

; TEST
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

; NE PAS MODIFIER (Test du 'rjmp main' pour determination code MSB:LSB ou LSB:MSB)
.org	0x018
main:
	rjmp		main_cont_d

; NE PAS SUPPRIMER les 'nop' (test des '.org')
	nop
	nop
	nop

; NE PAS MODIFIER (Saut depuis le dernier mot du programme)
.org	0x01c 
; Its non supportees
int0_isr:
tim1_ovf_isr:
tim0_ovf_isr:
ee_rdy_isr:
ana_cmp_isr:
adc_isr:
tim1_compb_isr:
tim0_compa_isr:
tim0_compb_isr:
wdt_isr:
usi_start_isr:
usi_ovf_isr:

; ---------
; Mise sur voie de garage avec clignotement Led RED
; ---------
forever_1:
	cli
	ldi		REG_TEMP_R16, 20
	rjmp		forever_init

forever_2:
	cli
	ldi		REG_TEMP_R16, 40

forever_init:
	; Extinction de toutes les Leds
	setLedGreenOff
	setLedYellowOff
	setLedRedOff
	setLedRedIntOff

forever_loop:
	push		REG_TEMP_R16			; Save/Restore temporisation dans REG_TEMP_R16
	setLedRedOn
	rcall		delay_big_2
	pop		REG_TEMP_R16
	push		REG_TEMP_R16
	setLedRedOff
	rcall		delay_big_2
	pop		REG_TEMP_R16
	rjmp		forever_loop
; ---------

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

; ---------
; Table des 16 vecteurs d'execution des taches timer
; => 'NBR_TIMER' taches d'execution definies
; ---------
vector_timers:
	rjmp		exec_timer_0							; Timer #0
	rjmp		exec_timer_1							; Timer #1
	rjmp		exec_timer_2							; Timer #2
	rjmp		exec_timer_3							; Timer #3
	rjmp		exec_timer_4							; Timer #4
	rjmp		exec_timer_5							; Timer #5
	rjmp		exec_timer_6							; Timer #6
	rjmp		exec_timer_7							; Timer #7
	rjmp		exec_timer_8							; Timer #8
	rjmp		exec_timer_9							; Timer #9
	rjmp		exec_timer_connect					; Timer #10
	rjmp		exec_timer_error						; Timer #11
	rjmp		exec_timer_push_button_led			; Timer #12
	rjmp		exec_timer_push_button_detect		; Timer #13
	rjmp		exec_timer_anti_rebound				; Timer #14
	rjmp		exec_timer_led_green					; Timer #15
; ---------

; ---------
; Initialisation de la SRAM
; - Pas d'initialisation des 2 derniers bytes (retour de la fonction)
;
; Registres utilises (non sauvegardes/restaures):
;    REG_TEMP_R16 -> Valeur d'initialisation de la SRAM
; ---------
init_sram_fill:
	ldi		REG_TEMP_R16, 0xff
	ldi		REG_X_MSB, high(RAMEND - 2)
	ldi		REG_X_LSB, low(RAMEND - 2)

init_sram_fill_loop_a:
	; Initialisation a 0xff de la STACK
	; => Permet de connaitre la profondeur maximale de la pile d'appel
	st			X, REG_TEMP_R16
	sbiw		REG_X_LSB, 1
	cpi		REG_X_MSB, high(G_SRAM_END_OF_USE)
	brne		init_sram_fill_loop_a
	cpi		REG_X_LSB, low(G_SRAM_END_OF_USE - 1)	
	brne		init_sram_fill_loop_a

	clr		REG_TEMP_R16

	; Initialisation a 0x00 du reste de la SRAM
	; => Permet de connaitre la profondeur de la pile d'appel
init_sram_fill_loop_b:
	st			X, REG_TEMP_R16
	sbiw		REG_X_LSB, 1
	cpi		REG_X_MSB, high(SRAM_START)
	brne		init_sram_fill_loop_b
	cpi		REG_X_LSB, low(SRAM_START)	
	brne		init_sram_fill_loop_b

	; Fin initialisation [SRAM_START, ..., (RAMEND - 2)]
	ret
; ---------

; ---------
; Initialisation de valeurs particulieres dans la SRAM
;
; Variables initialisees:
; - G_TICK_1MS_LSB:G_TICK_1MS_MSB -> Periode pour 1mS a partir de 13uS
;
; Registres utilises (non sauvegardes/restaures):
;    REG_TEMP_R16
;    REG_TEMP_R17 
; ---------
init_sram_values:
	; Initialisation periode de 1mS @ 26uS
	ldi		REG_TEMP_R16, PERIODE_1MS
	sts		G_TICK_1MS_INIT, REG_TEMP_R16
	sts		G_TICK_1MS, REG_TEMP_R16

	; Initialisation du chenillard Led GREEN
	; => 1 creneau de 125mS  _/--\________ toutes les 1 Sec (mode non connecte)
	ldi		REG_TEMP_R16, 0x01
	sts		G_CHENILLARD_MSB, REG_TEMP_R16
	sts		G_CHENILLARD_LSB, REG_TEMP_R16

	; Preparation reception bit RXD
	lds		REG_TEMP_R16, G_DURATION_DETECT_LINE_IDLE_MSB
	lds		REG_TEMP_R17, G_DURATION_DETECT_LINE_IDLE_LSB

	sts		G_UART_CPT_LINE_IDLE_MSB, REG_TEMP_R16
	sts		G_UART_CPT_LINE_IDLE_LSB, REG_TEMP_R17
	; Fin: Preparation reception bit RXD

	ldi		REG_TEMP_R16, NBR_BAUDS_VALUE
	sts		G_BAUDS_VALUE, REG_TEMP_R16

	ldi		REG_TEMP_R16, (DURATION_DETECT_LINE_IDLE / 256)
	sts		G_DURATION_DETECT_LINE_IDLE_MSB, REG_TEMP_R16
	ldi		REG_TEMP_R17, (DURATION_DETECT_LINE_IDLE % 256)
	sts		G_DURATION_DETECT_LINE_IDLE_LSB, REG_TEMP_R17

	ldi		REG_TEMP_R16, DURATION_WAIT_READ_BIT_START
	sts		G_DURATION_WAIT_READ_BIT_START, REG_TEMP_R16
	ret
; ---------

; ---------
; Initialisation du materiel
; - Cadencement a 26uS par le timer materiel #1 (ATtiny85 cadence a 10MHz - 100nS / cycle)
; - Detection changement d'etat sur RXD sur la pin PINB<0> (PCINT0)
;
; Registres utilises (non sauvegardes/restaures):
;    REG_TEMP_R16 -> Valeur d'initialisation des registres materiels
;
; Calculs pour le cadencement @ a la vitesse de l'UART logiciel (ATtiny85-10 cadence a 10MHz)
; - Periode de PCK et CK: 100nS
;   => Prescaler sur PCK: 1, 1/2, 1/4 et 1/8
; - Nombre d'echantillons pour determiner la periode de chaque bit de l'UART logiciel: 4
;   => Pour echantillonner 1 bit a:
;      - 9600 bauds (104 uS) -> echantillonage toutes les  26 uS -> OCR1C = 208 si prescaler /2
;      - 9600 bauds (104 uS) -> echantillonage toutes les  26 uS -> OCR1C = 104 si prescaler /4 (periode exacte du baud ;-)
;      - 9600 bauds (104 uS) -> echantillonage toutes les  26 uS -> OCR1C =  52 si prescaler /8
;
;      - 4800 bauds (208 uS) -> echantillonage toutes les  52 uS -> OCR1C = 208 si prescaler /4 (periode exacte du baud ;-)
;      - 4800 bauds (208 uS) -> echantillonage toutes les  52 uS -> OCR1C = 104 si prescaler /8
;
;      - 2400 bauds (416 uS) -> echantillonage toutes les 104 uS -> OCR1C = 208 si prescaler /8
;
;      => "Fuse Low Byte" configure comme suit:
;               - 0xF1 correspondant a:
;                 - CKDIV8
;                 - CKOUT
;                 - SUT1
;                 - SUT0
;                 - CKSEL0
;
;      - 19200 bauds (52 uS) -> echantillonage toutes les  13 uS -> OCR1C = 104 si prescaler /4 
; ---------
init_hard:
	; Configuration du timer materiel #1 pour une It toutes les 26uS
	ldi		REG_TEMP_R16, (MSK_BIT_PULSE_IT | MSK_BIT_LED_RED | MSK_BIT_LED_GREEN | MSK_BIT_LED_YELLOW | MSK_BIT_LED_RED_INT)
	out		DDRB, REG_TEMP_R16

	; TCCR1: Timer/Counter1 Control Register
	; - CTC1: Set Timer/Counter on Compare Match
	; - CS1[3:0]: Clock Select Bits 1 and 0: PCK/4 ou CK/4
	ldi		REG_TEMP_R16, (1 << CTC1 | 1 << CS11 | 1 << CS10)
	out		TCCR1, REG_TEMP_R16

	; OCR1C: Timer/Counter1 Output Compare RegisterC (value)
	ldi		REG_TEMP_R16, 104				; Cadencement a 26uS = (104 uS / 4) avec un ATtiny85-20 (20 MHz)
	out		OCR1C, REG_TEMP_R16

	; TIMSK: Timer/Counter Interrupt Mask Register
	; - OCIE1A: Timer/Counter1 Output Compare Interrupt Enable
	ldi		REG_TEMP_R16, (1 << OCIE1A)
	out		TIMSK, REG_TEMP_R16

	; TIFR: Timer/Counter Interrupt Flag Register
	; - OCF1A: Set Output Compare Flag 1A
	ldi		REG_TEMP_R16, (1 << OCF1A)
	out		TIFR, REG_TEMP_R16
	; Fin: Configuration du timer #1 pour une It toutes les 13uS

	; Configuration de PINB<0> (RXD) pour une interruption sur changement d'etat --\__ et __/--
	ldi		REG_TEMP_R16, (1 << PCINT0)
	out		PCMSK, REG_TEMP_R16

	ldi		REG_TEMP_R16, (1 << PCIE)
	out		GIMSK, REG_TEMP_R16

   ; Configuration du PULLUP sur PORTB<0> (RXD et Button)
   ldi      REG_TEMP_R16, 0x01
   out      PORTB, REG_TEMP_R16

	ret
; ---------

; ---------
; delay_big
; => Delay "long" de duree fixe @ REG_TEMP_R16, REG_TEMP_R17 et REG_TEMP_R18
;
; delay_big_2(REG_TEMP_R16)
; => Ne doit pas etre appelee sous It
;
delay_big:
	ldi		REG_TEMP_R16, 40

delay_big_2:
	ldi		REG_TEMP_R17, 125

delay_big_more:
	ldi		REG_TEMP_R18, 250

delay_big_more_1:
	dec		REG_TEMP_R18
	nop									; Wait 1 cycle
	brne		delay_big_more_1
	dec		REG_TEMP_R17
	brne		delay_big_more
	dec		REG_TEMP_R16
	brne		delay_big_2
	ret
; ---------

; ---------
; delay_1uS avec un ATtiny85 10MHz
; => Delai de 1uS
;
delay_1uS:
	nop				; 2 + 1 Cycles (rcall + nop) ou 3 + 1 Cycles (call + nop)
	nop				;   +	1
	nop				;   + 1
	nop				;   + 1
	nop				;   + 1
	nop				;   + 1
	ret				;   + 2 = 10 Cycles = 1uS
; ---------

; ---------
; test_leds
; => Allumage des 3 Leds RED, GREEN et RED Interne
;    puis extinction une par une
;
test_leds:
	clr		REG_PORTB_OUT

	setLedRedOn
	setLedGreenOn
	setLedYellowOn

	ldi		REG_TEMP_R16, 80
	rcall		delay_big_more

	setLedRedOff
	ldi      REG_TEMP_R16, 80
	rcall		delay_big_more

	setLedGreenOff
	ldi      REG_TEMP_R16, 80
	rcall		delay_big_more

	setLedYellowOff
	ldi      REG_TEMP_R16, 80
	rcall		delay_big_more

	ret
; ---------

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
; Fin des taches d'execution des timers

; ---------
; Gestion des FIFOs UART/Rx et UART/Tx
;
; Usages:
;      mov		REG_R1, <data>			; Donnee a ecrire
;      rcall   uart_fifo_rx|tx_write
;      => Retour: SREG<Bit> = 1 si FIFO/Rx|Tx pleine
;
;      rcall	uart_fifo_rx|tx_read
;      => Retour: Donnee dans G_STACK_RESULTS si SREG<Bit> = 1
;
; Registres utilises (non sauvegardes/restaures):
;    REG_X_LSB:REG_X_LSB -> Pointeur sur les pointeurs ecriture/lecture/data
;    REG_TEMP_R16        -> Working register
;    REG_TEMP_R17        -> Pointeur d'ecriture courant
;    REG_TEMP_R18        -> Pointeur de lecture courant
;
; Warning: Methode appelee sous l'It 'tim1_compa_isr'
; ---------
uart_fifo_rx_write:
	ldi		REG_X_MSB, (G_UART_FIFO_RX_DATA / 256)		; Indexation dans la FIFO/Rx
	ldi		REG_X_LSB, (G_UART_FIFO_RX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_RX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_RX_READ			; Pointeur de lecture courant

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R17	; XL += REG_TEMP_R17
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	st			X, REG_R1			; Ecriture donnee dans [G_UART_FIFO_RX_DATA, ..., G_UART_FIFO_RX_DATA_END]

	inc		REG_TEMP_R17
	andi		REG_TEMP_R17, (SIZE_UART_FIFO_RX - 1)		; Pointeur d'ecriture dans [0, ..., [SIZE_UART_FIFO_RX - 1)]
	sts		G_UART_FIFO_RX_WRITE, REG_TEMP_R17			; Maj pointeur d'ecriture

	; Indication FIFO/Rx non vide
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK

	; Indication si FIFO/Rx pleine
	; => FIFO/Rx pleine si le pointeur d'ecriture "rejoint" le pointeur de lecture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_FULL_MSK 		; FIFO/Rx a priori non pleine ...
	clt																	; SREG<T> = 0
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		uart_fifo_rx_write_rtn
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_FULL_MSK		; ... et non, FIFO/Rx pleine
	set																	; SREG<T> = 1

	; Maj compteur d'erreurs
	rcall		update_errors

uart_fifo_rx_write_rtn:
	ret
; ---------

; ---------
uart_fifo_rx_read:
	ldi		REG_X_MSB, (G_UART_FIFO_RX_DATA / 256)		; Indexation dans la FIFO/Rx
	ldi		REG_X_LSB, (G_UART_FIFO_RX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_RX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_RX_READ			; Pointeur de lecture courant

	; Sortie prematuree si rien a lire
	clt													; A priori pas de donnee a lire
	cp			REG_TEMP_R17, REG_TEMP_R18
	breq		uart_fifo_rx_read_end				; Pointeurs egaux => FIFO/Rx trouvee vide

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R18	; XL += REG_TEMP_R18
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	ld			REG_R2, X					; Lecture de la donnee dans [G_UART_FIFO_RX_DATA, ..., G_UART_FIFO_RX_DATA_END]
	set										; Indication donnee disponible

	inc		REG_TEMP_R18
	andi		REG_TEMP_R18, (SIZE_UART_FIFO_RX - 1)		; Pointeur de lecture dans [0, ..., [SIZE_UART_FIFO_RX - 1)]
	sts		G_UART_FIFO_RX_READ, REG_TEMP_R18

	; Indication FIFO/Rx vide ou non vide apres la lecture
	; => FIFO/Rx vide si le pointeur de lecture "rejoint" le pointeur ecriture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
uart_fifo_rx_read_test_empty:
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		; FIFO/Rx a priori non vide...
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		uart_fifo_rx_read_rtn

uart_fifo_rx_read_end:
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		; ... et non, FIFO/Rx vide

uart_fifo_rx_read_rtn:
	ret
; ---------

; ---------
uart_fifo_tx_write:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_TEMP_R17
	push		REG_TEMP_R18

	ldi		REG_X_MSB, (G_UART_FIFO_TX_DATA / 256)	; Indexation dans la FIFO/Tx et ses 2 pointeurs
	ldi		REG_X_LSB, (G_UART_FIFO_TX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_TX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_TX_READ			; Pointeur de lecture courant

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R17			; XL += REG_TEMP_R17
	adc		REG_X_MSB, REG_TEMP_R16			; XH += 0 + Carry

	st			X, REG_R3			; Ecriture donnee dans [G_UART_FIFO_TX_DATA, ..., G_UART_FIFO_TX_DATA_END]

	inc		REG_TEMP_R17
	andi		REG_TEMP_R17, (SIZE_UART_FIFO_TX - 1)		; Pointeur d'ecriture dans [0, ..., [SIZE_UART_FIFO_TX - 1)]
	sts		G_UART_FIFO_TX_WRITE, REG_TEMP_R17			; Maj pointeur d'ecriture

	; Indication FIFO/Tx non vide
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK

	; Emision de tous les caracteres de la FIFO/Tx jusqu'au dernier des que le pointeur d'ecriture (REG_TEMP_R17)
	; atteint le pointeur de lecture (REG_TEMP_R18) -(SIZE_UART_FIFO_TX / 2) modulo SIZE_UART_FIFO_TX
	; => Revient a vider la FIFO/Tx des que celle-ci est pleine a 50%
	;    => Au dessous des 50%, les caracteres seront emis en fond de tache grace a l'appel de 'fifo_tx_to_send_async'
	;    => Evite d'appeler dans le code la methode 'fifo_tx_to_send_sync' pour ne pas saturer la FIFO/Tx ;-)
	mov		REG_TEMP_R16, REG_TEMP_R18
	subi		REG_TEMP_R16, (SIZE_UART_FIFO_TX / 2)		; Seuil a 50 % d'occupation de la FIFO/Tx
	andi		REG_TEMP_R16, (SIZE_UART_FIFO_TX - 1)		; Modulo SIZE_UART_FIFO_TX
	cp			REG_TEMP_R16, REG_TEMP_R17
	brne		uart_fifo_tx_write_skip

	rcall		fifo_tx_to_send_sync

uart_fifo_tx_write_skip:
	; Fin: Emision de tous les caracteres de la FIFO/Tx...

	; Indication si FIFO pleine
	; => FIFO pleine si le pointeur d'ecriture "rejoint" le pointeur de lecture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_FULL_MSK 		; FIFO/Rx a priori non pleine ...
	clt																	; SREG<T> = 0
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		uart_fifo_tx_write_rtn
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_FULL_MSK		; ... et non, FIFO/Rx pleine
	set																	; SREG<T> = 1

	; Ne doit jamais arrive ;-)...
	; Mise sur voie de garage si FIFO/Tx pleine
	rjmp		forever_1

uart_fifo_tx_write_rtn:
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
uart_fifo_tx_read:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_TEMP_R17
	push		REG_TEMP_R18

	ldi		REG_X_MSB, (G_UART_FIFO_TX_DATA / 256)	; Indexation dans la FIFO/Tx et ses 2 pointeurs
	ldi		REG_X_LSB, (G_UART_FIFO_TX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_TX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_TX_READ			; Pointeur d'ecriture courant

	; Sortie prematuree si rien a lire
	clt														; A priori pas de donnee a lire
	cp			REG_TEMP_R17, REG_TEMP_R18
	breq		uart_fifo_tx_read_end					; Pas de lecture => maj flags

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R18	; XL += REG_TEMP_R18
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	ld			REG_R4, X			; Lecture de la donnee dans [G_UART_FIFO_TX_DATA, ..., G_UART_FIFO_TX_DATA_END]
	set								; Indication donnee disponible

	inc		REG_TEMP_R18
	andi		REG_TEMP_R18, (SIZE_UART_FIFO_TX - 1)		; Pointeur de lecture dans [0, ..., [SIZE_UART_FIFO_TX - 1)]
	sts		G_UART_FIFO_TX_READ, REG_TEMP_R18

	; Indication FIFO/Tx vide ou non vide apres la lecture
	; => FIFO/Tx vide si le pointeur de lecture "rejoint" le pointeur ecriture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
uart_fifo_tx_read_test_empty:
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		; FIFO/Rx a priori non vide...
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		uart_fifo_tx_read_rtn

uart_fifo_tx_read_end:
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		; ... et non, FIFO/Rx vide

uart_fifo_tx_read_rtn:
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
; Emission d'un caractere sur Tx
; => Initialise 'G_UART_BYTE_TX_LSB:G_UART_BYTE_TX_MSB' et positionne 'FLG_1_UART_TX_TO_SEND' a 1
;    => Le mot constitue du Bit Start + 8 Datas + 1 ou 2 Bits Stop sera emis sous
;       l'It 'tim1_compa_isr' au moyen de 'G_UART_CPT_DURATION_1BIT_TX' @ 26uS et
;       'G_UART_CPT_NBR_BITS_TX' initialise a ((1+8+1) + x) (x Bits Stop)
;
; Usage:
;      mov		REG_TEMP_R16, <data>
;      rcall   uart_tx_send
;
; Registres utilises (sauvegardes/restaures):
;    REG_TEMP_R16        -> Byte a emettre
;    REG_TEMP_R17        -> Working register
; ---------
uart_tx_send:
	push		REG_TEMP_R16
	push		REG_TEMP_R17

	; Construction du mot a emettre avec '1111 11sD DDDD DDDS' ([S]tart/[s]top)
	; R17:R16 = MSB:LSB = '1111 111D DDDD DDD0'
	ldi		REG_TEMP_R17, 0xFF	; Preparation MSB avec les 1, 2, 3, ... Bits Stop
	lsl		REG_TEMP_R16			; 'DDDD DDD0':  Bit Start a 0 et C = D7
	rol		REG_TEMP_R17			; '1111 111D':  Propagation de la Carry et des Bits Stop

	cli		; Copie atomique
	sts		G_UART_BYTE_TX_LSB, REG_TEMP_R16
	sts		G_UART_BYTE_TX_MSB, REG_TEMP_R17
	sei		; Fin: Copie atomique

	;ldi		REG_TEMP_R16, ((1+8+1) + 1)	; 1 Bit START + 8 Datas + 1 Bit  STOP (11)
	ldi		REG_TEMP_R16, ((1+8+1) + 2)	; 1 Bit START + 8 Datas + 2 Bits STOP (12)
	;ldi		REG_TEMP_R16, ((1+8+1) + 3)	; 1 Bit START + 8 Datas + 3 Bits STOP (13)
	sts		G_UART_CPT_NBR_BITS_TX, REG_TEMP_R16

   clr		REG_TEMP_R16			; Initialisation a 0 pour faire partir l'emission immediatement
   sts		G_UART_CPT_DURATION_1BIT_TX, REG_TEMP_R16

	sbr		REG_PORTB_OUT, MSK_BIT_TXD						; TXD a l'etat haut avant lancement emission
	sbr		REG_FLAGS_0, FLG_0_UART_TX_TO_SEND_MSK		; Positionnement donnee a emettre

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un texte termine par '\0'
;
; Usage:
;      ldi		REG_Z_MSB, <address MSB>
;      ldi		REG_Z_LSB, <address LSB>
;      rcall   push_text_in_fifo_tx
;
; Registres utilises
;    REG_Z_LSB:REG_Z_LSB -> Pointeur sur le texte en memoire programme (preserve)
;    REG_TEMP_R16        -> Working register (preserve)
; ---------
push_text_in_fifo_tx_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

push_text_in_fifo_tx:
	push		REG_Z_MSB
	push		REG_Z_LSB
	push		REG_TEMP_R16

push_text_in_fifo_tx_loop:
	lpm		REG_TEMP_R16, Z+
	cpi		REG_TEMP_R16, CHAR_NULL		; '\0' terminal ?
	breq		push_text_in_fifo_tx_end

	mov		REG_R3, REG_TEMP_R16
	rcall		uart_fifo_tx_write

	rjmp		push_text_in_fifo_tx_loop

push_text_in_fifo_tx_end:
	pop		REG_TEMP_R16
	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un char
;
; Usage:
;      ldi		REG_TEMP_R16, <value>
;      rcall   push_1_char_in_fifo_tx
;
; Registres utilises
;    REG_TEMP_R16 -> Working register
; ---------
push_1_char_in_fifo_tx_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

push_1_char_in_fifo_tx:
	mov		REG_R3, REG_TEMP_R16
	rcall		uart_fifo_tx_write

	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un texte lu de l'EEPROM et termine par '\0'
; => Si un 0xff est lu (EEPROM non initialisee), abandon de la lecture
; => Limitation a 8 caracteres lus pour eviter un bouclage ;-)
;
; Usage:
;      ldi		REG_TEMP_R18, 8
;      ldi		REG_X_MSB, <address MSB>
;      ldi		REG_X_LSB, <address LSB>
;      rcall   push_text_in_fifo_tx_from_eeprom
;
; ---------
push_text_in_fifo_tx_from_eeprom_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

push_text_in_fifo_tx_from_eeprom:
	nop

push_text_in_fifo_tx_from_eeprom_loop:
	rcall		eeprom_read_byte

	cpi		REG_TEMP_R16, 0xff
	breq		push_text_in_fifo_tx_from_eeprom_end

	tst		REG_TEMP_R16
	breq		push_text_in_fifo_tx_from_eeprom_end

	rcall		push_1_char_in_fifo_tx

	adiw		REG_X_LSB, 1
	dec		REG_TEMP_R18
	brne		push_text_in_fifo_tx_from_eeprom_loop

push_text_in_fifo_tx_from_eeprom_end:
	ret
; ---------

	ret
; ---------

; ---------
; Emission asynchrone caractere par caractere de la FIFO/Tx
;
; Remarque: Methode a appeler en fond de tache permettant de vider et
;           emettre tous les caracteres de la FIFO/Tx jusqu'au dernier
;
; Usage:
;      rcall   fifo_tx_to_send_async
;
; Registres utilises
;    REG_TEMP_R16        -> Working register (non preserve)
; ---------
fifo_tx_to_send_async:
	; Caractere de la FIFO/Tx a emettre ?
	sbrs		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_IDX
	rjmp		fifo_tx_to_send_async_rtn

	sbrc		REG_FLAGS_0, FLG_0_UART_TX_TO_SEND_IDX		; Caractere emis ?
	rjmp		fifo_tx_to_send_async_rtn

	rcall		uart_fifo_tx_read					; Oui => Lecture du caractere suivant dans FIFO/Tx
	brtc		fifo_tx_to_send_async_end		; Caractere disponible ?

	mov		REG_TEMP_R16, REG_R4				; Oui => Emission de celui-ci
	rcall		uart_tx_send
	rjmp		fifo_tx_to_send_async_rtn		; Retour et attente que ce caractere soit emis...

fifo_tx_to_send_async_end:
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK		; Non => Arret de la demande d'emission

fifo_tx_to_send_async_rtn:
	ret
; ---------

; ---------
; Emission synchrone caractere par caractere jusqu'a vidage de la FIFO/Tx
;
; Remarque: Methode a appeler apres un appel a 'push_1_char_in_fifo_tx'
;           => Emision de tous les caracteres de la FIFO/Tx jusqu'au dernier
;
; Permet un forcage emission pour eviter la saturation de la FIFO/Tx
; => En effet, la lecture de la FIFO/Tx et l'emission ne commence qu'au
;    retour en fond de tache (cf. 'rcall fifo_tx_to_send_async')
;
; Usage:
;      rcall   fifo_tx_to_send_sync
;
; Registres utilises
;    REG_TEMP_R16        -> Working register (non preserve)
; ---------
fifo_tx_to_send_sync:
	nop

fifo_tx_to_send_sync_retry:
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK
	rcall		fifo_tx_to_send_async

	sbrc		REG_FLAGS_0, FLG_0_UART_TX_TO_SEND_IDX				; Caractere emis ?
	rjmp		fifo_tx_to_send_sync_retry								; Non => Retry

	sbrc		REG_FLAGS_1, FLG_1_UART_FIFO_TX_NOT_EMPTY_IDX	; FIFO/Tx vide ?
	rjmp		fifo_tx_to_send_sync_retry								; Non => Retry
	; Fin: Emission, attente FIFO/Tx vide et dernier caractere emis

fifo_tx_to_send_sync_rtn:
	ret
; ---------

; ---------
test_detect_line_idle:
	sbrc		REG_FLAGS_0, FLG_0_UART_DETECT_LINE_IDLE_IDX
	rjmp		test_detect_line_idle_rtn

	; Presentation flash de 100mS sur Led YELLOW
	cli
	setLedYellowOn
	sei

	; Presentation flash de 100mS sur Led YELLOW
	ldi		REG_TEMP_R17, TIMER_APPUI_BOUTON_LED
	ldi		REG_TEMP_R18, (100 % 256)
	ldi		REG_TEMP_R19, (100 / 256)
	rcall		restart_timer
	; Fin: Presentation flash de 100mS sur Led YELLOW

test_detect_line_idle_rtn:
	ret
; ---------

; ---------
; Allumage fugitif Led RED Externe si erreur
; => L'effacement des 2 'FLG_0_UART_RX_BYTE_START_ERROR' et 'FLG_0_UART_RX_BYTE_STOP_ERROR'
;    est effectue sur la reception d'un nouveau caratere sans erreur ;-)
;    => L'allumage peut durer au dela de la valeur d'initialisation du timer 'TIMER_ERROR'
;       et donc ne pas presenter d'autres erreurs a definir
;       => Choix: Effacement sur time-out de 'TIMER_CONNECT'
;
; => L'effacement des 2 'FLG_1_UART_FIFO_RX_FULL' et 'FLG_1_UART_FIFO_TX_FULL'
;    est effectue des lors que la FIFO/Rx ou Tx n'est plus "vue" comme pleine
;    => Des carateres peuvent avoir ete perdus dans l'empilement dans la FIFO
;
presentation_error:
	sbrc		REG_FLAGS_0, FLG_0_UART_RX_BYTE_START_ERROR_IDX
	rjmp		presentation_error_reinit
	sbrc		REG_FLAGS_0, FLG_0_UART_RX_BYTE_STOP_ERROR_IDX
	rjmp		presentation_error_reinit
	sbrc		REG_FLAGS_1, FLG_1_UART_FIFO_RX_FULL_IDX
	rjmp		presentation_error_reinit
	sbrc		REG_FLAGS_1, FLG_1_UART_FIFO_TX_FULL_IDX
	rjmp		presentation_error_reinit

	lds		REG_TEMP_R16, G_TEST_FLAGS			; Prise des flags 'G_TEST_FLAGS'

	sbrc		REG_TEMP_R16, FLG_TEST_COMMAND_ERROR_IDX
	rjmp		presentation_error_reinit

	sbrc		REG_TEMP_R16, FLG_TEST_EEPROM_ERROR_IDX
	rjmp		presentation_error_reinit

	rjmp		presentation_error_rtn

presentation_error_reinit:
	; Reinitialisation timer 'TIMER_ERROR' tant que erreur(s) presente(s)
	ldi		REG_TEMP_R17, TIMER_ERROR
	ldi		REG_TEMP_R18, (200 % 256)
	ldi		REG_TEMP_R19, (200 / 256)
	rcall		restart_timer

	; Effacement de certaines erreurs non fugitives
	lds		REG_TEMP_R16, G_TEST_FLAGS 
	cbr		REG_TEMP_R16, FLG_TEST_COMMAND_ERROR_MSK
	sts		G_TEST_FLAGS, REG_TEMP_R16

	cli
	setLedRedOn
	sei

presentation_error_rtn:
	ret
; ---------

; ---------
; Conversion en minuscule si 'text_convert_hex_to_min_ascii_table' utilisee
; Conversion en majuscule si 'text_convert_hex_to_maj_ascii_table' utilisee
; ---------
convert_nibble_to_ascii:
	andi		REG_TEMP_R16, 0x0f
	ldi		REG_Z_MSB, high(text_convert_hex_to_min_ascii_table << 1)
	ldi		REG_Z_LSB, low(text_convert_hex_to_min_ascii_table << 1)
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16
	adc		REG_Z_MSB, REG_TEMP_R16
	lpm		REG_TEMP_R16, Z

convert_nibble_to_ascii_rtn:
	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un byte converti en 2 hex-char
;
; Usage:
;      ldi		REG_TEMP_R16, <value>
;      rcall   convert_and_put_fifo_tx
; ---------
convert_and_put_fifo_tx:
	push		REG_TEMP_R16		; Sauvegarde de la valeur a convertir et ecrire

	swap		REG_TEMP_R16		; Copie Bits<7-4> dans Bits<3-0>
	rcall		convert_nibble_to_ascii
	rcall    push_1_char_in_fifo_tx

	pop		REG_TEMP_R16		; Reprise de la valeur a convertir et ecrire

	rcall		convert_nibble_to_ascii
	rcall    push_1_char_in_fifo_tx

	ret
; ---------

presentation_connexion:
	sbrs		REG_FLAGS_1, FLG_1_UART_FIFO_RX_NOT_EMPTY_IDX
	rjmp		presentation_connexion_fifo_rx_empty

presentation_connexion_fifo_rx_not_empty:
	; FIFO/Rx non vide
	; Test si 'Non Connecte' ?
	; => Si Oui: Changement chenillard
	lds		REG_TEMP_R16, G_FLAGS_2
	sbrc		REG_TEMP_R16, FLG_2_CONNECTED_IDX
	rjmp		presentation_connexion_reinit_timer

	; Changement chenillard
	ldi		REG_TEMP_R16, 0xFE
	sts		G_CHENILLARD_MSB, REG_TEMP_R16
	sts		G_CHENILLARD_LSB, REG_TEMP_R16

presentation_connexion_reinit_timer:
	; Reinitialisation timer 'TIMER_ERROR' tant que FIFO/Rx non vide
	ldi		REG_TEMP_R17, TIMER_CONNECT
	ldi		REG_TEMP_R18, (3000 % 256)
	ldi		REG_TEMP_R19, (3000 / 256)
	rcall		restart_timer

	; Passage en mode 'Connecte' pour une presentation Led GREEN --\__/-----
	lds		REG_TEMP_R16, G_FLAGS_2
	sbr		REG_TEMP_R16, FLG_2_CONNECTED_MSK
	;rjmp		presentation_connexion_rtn

presentation_connexion_fifo_rx_empty:
	; Passage en mode 'Non Connecte' a l'expiration du timer 'TIMER_CONNECT'

presentation_connexion_rtn:
	ret
; ---------

; ---------
print_line_feed_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

print_line_feed:
	push		REG_Z_MSB
	push		REG_Z_LSB

	ldi		REG_Z_MSB, ((text_line_feed << 1) / 256)
	ldi		REG_Z_LSB, ((text_line_feed << 1) % 256)
	rcall		push_text_in_fifo_tx

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
print_1_byte_hexa_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

print_1_byte_hexa:
	push		REG_Z_MSB
	push		REG_Z_LSB

	; Emission en hexa du contenu de 'REG_X_LSB'
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	rcall		push_text_in_fifo_tx

	mov		REG_TEMP_R16, REG_X_LSB
	rcall		convert_and_put_fifo_tx

	ldi		REG_Z_MSB, ((text_hexa_value_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_end << 1) % 256)
	rcall		push_text_in_fifo_tx

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
print_2_bytes_hexa_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

print_2_bytes_hexa:
	push		REG_Z_MSB
	push		REG_Z_LSB

	; Emission en hexa du contenu de 'REG_X_MSB:REG_X_LSB'
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	rcall		push_text_in_fifo_tx

	mov		REG_TEMP_R16, REG_X_MSB
	rcall		convert_and_put_fifo_tx

	mov		REG_TEMP_R16, REG_X_LSB
	rcall		convert_and_put_fifo_tx

	ldi		REG_Z_MSB, ((text_hexa_value_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_end << 1) % 256)
	rcall		push_text_in_fifo_tx

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
; Print du registre X
; ---------
print_x_reg_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

print_x_reg:
	push		REG_Z_MSB
	push		REG_Z_LSB

	rcall		print_2_bytes_hexa

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
; Print du registre X
; ---------
print_y_reg_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

print_y_reg:
	push		REG_X_MSB
	push		REG_X_LSB

	movw		REG_X_LSB, REG_Y_LSB
	rcall		print_x_reg

	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
; Print du registre z
; ---------
print_z_reg_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

print_z_reg:
	push		REG_X_MSB
	push		REG_X_LSB

	movw		REG_X_LSB, REG_Z_LSB
	rcall		print_x_reg

	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
; Marquage traces
; ---------
print_mark_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

print_mark:
	push		REG_TEMP_R16
	ldi		REG_TEMP_R16, 3

print_mark_loop:
	push		REG_TEMP_R16
	cpi		REG_TEMP_R16, 2
	brne		print_mark_loop_a
	mov		REG_TEMP_R16, REG_TEMP_R17
	rjmp		print_mark_loop_b

print_mark_loop_a:
	ldi		REG_TEMP_R16, '-'

print_mark_loop_b:
	rcall		push_1_char_in_fifo_tx
	pop		REG_TEMP_R16
	dec		REG_TEMP_R16
	brne		print_mark_loop

	rcall		print_line_feed

	pop		REG_TEMP_R16

	ret
; ---------

;--------------------
; Lecture et sauvegarde des informations de l'EEPROM
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

; ---------
; Trace par un double creneau --\__/--\__/------ sur la Pulse It
; ---------
trace_in_it_double_1uS:
	rcall		delay_1uS
	rcall		delay_1uS
	sbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT				; Raffraichissement du PORTB
	rcall		delay_1uS
	rcall		delay_1uS
	cbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT				; Raffraichissement du PORTB
	rcall		delay_1uS
	rcall		delay_1uS
	sbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT				; Raffraichissement du PORTB

	ret
; ---------

; ---------
; Maj du compteur d'erreurs
; ---------
update_errors:
	lds		REG_TEMP_R16, G_NBR_ERRORS
	inc		REG_TEMP_R16
	sts		G_NBR_ERRORS, REG_TEMP_R16
	ret
; ---------

main_cont_d:
   setTxdHigh							; TXD a l'etat haut le plus vite possible ;-)

	rcall		init_sram_fill			; Initialisation de la SRAM

init_sram_fill_bypass:
	rcall		init_sram_values		; Initialisation de valeurs particulieres
	rcall		init_hard				; Initialisation du materiel
	rcall		test_leds			 	; Test Leds

	; Initialisation timer #7 pour le chenillard Led GREEN
	ldi		REG_TEMP_R17, TIMER_LED_GREEN
	ldi		REG_TEMP_R18, (125 % 256)
	ldi		REG_TEMP_R19, (125 / 256)
	rcall		start_timer

   ;setLedGreenOn			; Allumage de la Led GREEN durant 125mS
	; Fin: Initialisation timer #7

	sei						; Set all interrupts for send prompts

	; Preparation emission des prompts d'accueil
	; => Prompt d'accueil "### ..." avec '\n'
	ldi		REG_Z_MSB, ((text_whoami << 1) / 256)
	ldi		REG_Z_LSB, ((text_whoami << 1) % 256)
	rcall		push_text_in_fifo_tx

	rcall		set_infos_from_eeprom

	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK
	; Fin: Preparation emission du prompt d'accueil

main_loop:
	; Gestion de l'attente expiration des 1ms
	sbrs		REG_FLAGS_0, FLG_0_PERIODE_1MS_IDX		; 1mS expiree ?
	rjmp		main_loop_more									; Non

	; => Expiration de 1mS => Nouvelle periode de 1mS
	; => call 'gestion_timer' (execution du traitement associe a chaque timer qui expire)
	; => reinitialisation 'G_TICK_1MS' (copie atomique ;-)
	; => Effacement 'FLG_0_PERIODE_1MS' -> Relance de la comptabilisation des 1mS

	lds		REG_TEMP_R17, G_TICK_1MS_INIT
	sts		G_TICK_1MS, REG_TEMP_R17

	cbr		REG_FLAGS_0, FLG_0_PERIODE_1MS_MSK

	rcall		gestion_timer		; Gestion des timers

	; Traitements toutes les 1mS
	; ---
	; Presentation etat 'Detect Line Idle'
	rcall		test_detect_line_idle

	; Presentation sur Led GREEN mode "Connecte/Non Connecte"
	rcall		presentation_connexion

	; Interpretation de la commande recue
	rcall		interpret_command

	; ---
	; Fin: Traitements toutes les 1mS

main_loop_more:
	; Test et emission eventuelle d'un caractere de la FIFO/Tx
	; => Effectue des que possible des lors que 'FLG_1_UART_FIFO_TX_TO_SEND'
	;    est a 1 et que 'FLG_0_UART_TX_TO_SEND' est a 0
	;    => Traitement en fond de tache pour cadencer l'emission au max des 9600 bauds
	rcall		fifo_tx_to_send_async

	; Presentation erreurs sur Led RED Externe
	rcall		presentation_error

main_loop_end:
	rjmp		main_loop
	rjmp		forever_1

; ---------
; Interpretation d'une commande de test
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
print_command_ok:
	; Echo de la commande reconnue avec uniquement l'adresse
	; => ie. "[34>zA987-4321]"
	;
	lds		REG_TEMP_R17, G_TEST_FLAGS
	cbr		REG_TEMP_R17, FLG_TEST_COMMAND_ERROR_MSK

	ldi		REG_TEMP_R16, CHAR_COMMAND_SEND
	rjmp		print_command

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
	; Fin: Liste des commandes supportees

exec_command_ko:
	rcall		print_command_ko			; Commande non reconnue

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
	breq		exec_command_A_loop_1_cont_d	; Lecture par mot

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

exec_command_A_rtn:
	ldi		REG_TEMP_R17, 'c'
	rcall		print_mark
	lds		REG_X_LSB, G_CALC_CRC8
	rcall		print_1_byte_hexa
	rcall		print_line_feed
	ret
; ---------

; ---------
; Calcul du CRC8-MAXIM
;
; Input:  G_CALC_CRC8 and REG_TEMP_R16
; Output: G_CALC_CRC8 updated for retry
; ---------
calc_crc8_maxim:
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18
	push		REG_TEMP_R19

	mov		REG_TEMP_R17, REG_TEMP_R16
	lds		REG_TEMP_R19, G_CALC_CRC8

	ldi		REG_TEMP_R18, 8

calc_crc8_maxim_loop_bit:
	mov		REG_TEMP_R16, REG_TEMP_R19	; 'REG_TEMP_R19' contient le CRC8 calcule
	eor		REG_TEMP_R16, REG_TEMP_R17	; 'REG_TEMP_R17' contient le byte a inserer dans le polynome
	andi		REG_TEMP_R16, 0x01			; carry = ((crc ^ i__byte) & 0x01);

	clt											; 'T' determine le report de la carry	
	breq		calc_crc8_maxim_a
	set

calc_crc8_maxim_a:
	lsr		REG_TEMP_R19					; crc >>= 1;
	brtc		calc_crc8_maxim_b

	ldi		REG_TEMP_R16, CRC8_POLYNOMIAL
	eor		REG_TEMP_R19, REG_TEMP_R16					; crc ^= (carry ? CRC8_POLYNOMIAL: 0x00);

calc_crc8_maxim_b:
	sts		G_CALC_CRC8, REG_TEMP_R19

	lsr		REG_TEMP_R17									; i__byte >>= 1

	dec		REG_TEMP_R18
	brne		calc_crc8_maxim_loop_bit

	pop		REG_TEMP_R19
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16

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

#if 1
	; Test de 'REG_X_MSB:REG_X_LSB' dans la plage [SRAM_START, ..., 'G_SRAM_END_OF_USE', ..., RAMEND]
	; => Autorisation d'ecriture a l'adresse 'G_SRAM_END_OF_USE' ;-)
	ldi		REG_TEMP_R16, low(SRAM_START)
	cp			REG_X_LSB, REG_TEMP_R16
	ldi		REG_TEMP_R16, high(SRAM_START)
	cpc		REG_X_MSB, REG_TEMP_R16
	brlo		exec_command_type_s_write_out_of_range		; Saut si X <= 'Adresse du 1er byte de la SRAM'

	ldi		REG_TEMP_R16, low(G_SRAM_END_OF_USE + 1)
	cp			REG_X_LSB, REG_TEMP_R16
	ldi		REG_TEMP_R16, high(G_SRAM_END_OF_USE + 1)
	cpc		REG_X_MSB, REG_TEMP_R16
	brsh		exec_command_type_s_write_out_of_range		; Saut si X > 'Adresse du dernier byte utilise de la SRAM'
#endif

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

; Constantes et textes definis naturellement (MSB:LSB et ordre naturel du texte)
; => Remarque: Nombre pair de caracteres pour eviter le message:
;              "Warning : A .DB segment with an odd number..."

.dw	CHAR_SEPARATOR		; Debut section datas	; NE PAS SUPPRIMER ;-)

text_whoami:

.db	"### ATtiny85_uOS $Revision: 1.2 $", CHAR_LF, CHAR_NULL, CHAR_NULL

text_prompt_eeprom_version:
.db	"### EEPROM: ", CHAR_NULL, CHAR_NULL

text_prompt_type:
.db	"### Type: ", CHAR_NULL, CHAR_NULL

text_prompt_id:
.db	"### Id: ", CHAR_NULL, CHAR_NULL

text_appui_bouton:
.db	"### Appui bouton [0x", CHAR_NULL, CHAR_NULL

text_appui_bouton_value_hexa:
.db	"] [0x", CHAR_NULL

text_appui_bouton_value_ascii:
.db	"] [", CHAR_NULL

text_appui_bouton_end:
.db	"] ", CHAR_LF, CHAR_NULL

text_hexa_value:
.db	"[0x", CHAR_NULL

text_hexa_value_end:
.db	"]", CHAR_NULL

text_hexa_value_lf_end:
.db	"]", CHAR_LF, CHAR_NULL, CHAR_NULL

text_line_feed:
.db	CHAR_LF, CHAR_NULL

text_eeprom_error:
.db	"Err: EEPROM at ", CHAR_NULL

text_msk_table:
.db	MSK_BIT0, MSK_BIT1, MSK_BIT2, MSK_BIT3
.db	MSK_BIT4, MSK_BIT5, MSK_BIT6, MSK_BIT7

text_convert_hex_to_maj_ascii_table:
.db	"0123456789ABCDEF"

text_convert_hex_to_min_ascii_table:
.db	"0123456789abcdef"

const_for_bauds_rate:
.db	0x01, 0x02, 0x3C, 0x01	; 19200 bauds	; TODO: Erreur de reception cote cible non systematique
.db	0x03, 0x04, 0x78, 0x02	;  9600 bauds
.db	0x07, 0x08, 0xF0, 0x04	;  4800 bauds
.db	0x0F, 0x11, 0xE0, 0x08	;  2400 bauds
.db	0x1F, 0x23, 0xC0, 0x10	;  1200 bauds
.db	0x3E, 0x47, 0x80, 0x20	;   600 bauds
.db	0x7C, 0x8F, 0x00, 0x40	;   300 bauds
const_for_bauds_rate_end:

end_of_program:

; Fin: Constantes et textes definis naturellement (MSB:LSB et ordre naturel du texte)

; End of file
