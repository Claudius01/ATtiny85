; "$Id: ATtiny85_uOS.asm,v 1.6 2025/11/25 17:29:59 administrateur Exp $"

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
.org	0x0000 
	; Table des 15 vecteurs d'interruption
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

; Its non supportees => Mise sur voie de garage
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

	rjmp		forever_2

; Fin: Its non supportees

; ---------
; Table des 16 vecteurs d'execution des taches timer
; => Cf. 'NBR_TIMER' -> Nombre de taches d'execution definies
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

main:
   ;setTxdHigh							; TXD a l'etat haut le plus vite possible ;-)

	rcall		init_sram_fill			; Initialisation de la SRAM
	rcall		init_sram_values		; Initialisation de valeurs particulieres
	rcall		init_hard				; Initialisation du materiel
	rcall		test_leds			 	; Test Leds

	; Initialisation timer #7 pour le chenillard Led GREEN
	ldi		REG_TEMP_R17, TIMER_LED_GREEN
	ldi		REG_TEMP_R18, (125 % 256)
	ldi		REG_TEMP_R19, (125 / 256)
	rcall		start_timer

   ;setLedGreenOn			; Allumage de la Led GREEN durant 125mS

	sei						; Set all interrupts for send prompts

	; Preparation emission des prompts d'accueil
	; => Prompt d'accueil
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

text_whoami:
.db	"### ATtiny85_uOS $Revision: 1.6 $", CHAR_LF, CHAR_NULL, CHAR_NULL

.include		"ATtiny85_uOS_Macros.def"

.include		"ATtiny85_uOS_Misc.asm"
.include		"ATtiny85_uOS_Interrupts.asm"
.include		"ATtiny85_uOS_Timers.asm"
.include		"ATtiny85_uOS_Uart.asm"
.include		"ATtiny85_uOS_Eeprom.asm"
.include		"ATtiny85_uOS_Commands.asm"
.include		"ATtiny85_uOS_Print.asm"

end_of_program:

.dseg
G_SRAM_END_OF_USE:					.byte		1

; End of file

