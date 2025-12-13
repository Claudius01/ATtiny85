; "$Id: ATtiny85_uOS.asm,v 1.28 2025/12/13 10:14:37 administrateur Exp $"

; - Projet: ATtiny85_uOS.asm
;
; - Avertissement: Etude pour l'utilisation d'un ATtiny85-20
;   => Le DigiSpark utilise un ATtiny85-10 cadence a 10 Mhz
;
; - TODO: Version minimaliste: Allumage fixe de la Led RED au RESET 

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

	nop		; Evite le message "Warning : Improve: Skip equal to 0"

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

; Entree du programme
; - Initialisation de la SRAM
; - Initialisation materielle
; - Test Leds
; - Print du bandeau et des infos EEPROM

; #1 Boucle avec:
;   - Comptabilisation de 1 mS
;   #2 Toutes les 1 mS    
;     - Gestion des timers
;     - Presentation
;     - Interpretation de la commande recue
;   #3 Sans attente de l'expiration de 1 mS
;     - Test et emission eventuelle d'un caractere de la FIFO de transmission
;     - Presentation des erreurs fugitives et persistante
;   #4 Retour en #1
;
; Le "tick" de cadencement fixe a 26uS, la reception avec la mise en FIFO des
; caracteres recus et la gestion du bouton sont effectues sous interruption
; en // des traitements executes dans la boucle #1
;
main:

setup:	; Remarque: Equivalent de la methode 'setup()' dans l'ecosysteme Arduino ;-)
	rcall		init_sram_fill			; Initialisation de la SRAM
	rcall		init_sram_values		; Initialisation de valeurs particulieres
	rcall		init_hard				; Initialisation du materiel
	rcall		test_leds			 	; Test Leds

	; Initialisation timer 'TIMER_LED_GREEN' pour le chenillard Led GREEN
	ldi		REG_TEMP_R17, TIMER_LED_GREEN
	ldi		REG_TEMP_R18, (125 % 256)
	ldi		REG_TEMP_R19, (125 / 256)
	ldi		REG_TEMP_R20, low(exec_timer_led_green)
	ldi		REG_TEMP_R21, high(exec_timer_led_green)
	rcall		start_timer

	sei						; Set all interrupts for send prompts

setup_cold:
	; Preparation emission des prompts d'accueil
	; => Prompt d'accueil
	ldi		REG_Z_MSB, ((text_whoami << 1) / 256)
	ldi		REG_Z_LSB, ((text_whoami << 1) % 256)
	rcall		push_text_in_fifo_tx

	rcall		set_infos_from_eeprom

	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK
	; Fin: Preparation emission des prompts d'accueil ('whoami' et 'eeprom')

	rcall		addon_search_methods

	ldi		REG_TEMP_R17, EXTENSION_SETUP
	rcall		exec_extension_addon

loop:		; Remarque: Equivalent de la methode 'loop()' dans l'ecosysteme Arduino ;-)
	; Gestion de l'attente expiration des 1ms
	sbrs		REG_FLAGS_0, FLG_0_PERIODE_1MS_IDX		; 1mS expiree ?
	rjmp		loop_background								; Non -> Traitements en fond de tache

	; Oui -> Traitements toutes les 1mS
	; => Expiration de 1mS => Nouvelle periode de 1mS
	; => call 'gestion_timer' (execution du traitement associe a chaque timer qui expire)
	; => reinitialisation 'G_TICK_1MS' (copie atomique ;-)
	; => Effacement 'FLG_0_PERIODE_1MS' -> Relance de la comptabilisation des 1mS

loop_1_ms:
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

#ifndef USE_MINIMALIST
	; Interpretation de la commande recue
	rcall		interpret_command
#endif

	ldi		REG_TEMP_R17, EXTENSION_1_MS
	rcall		exec_extension_addon

	; ---
	; Fin: Traitements toutes les 1mS

loop_background:
	; Traitements en background
	; Test et emission eventuelle d'un caractere de la FIFO/Tx
	; => Effectue des que possible des lors que 'FLG_1_UART_FIFO_TX_TO_SEND'
	;    est a 1 et que 'FLG_0_UART_TX_TO_SEND' est a 0
	;    => Traitement en fond de tache pour cadencer l'emission au max des 9600 bauds
	rcall		fifo_tx_to_send_async

	; Presentation erreurs sur Led RED Externe
	rcall		presentation_error

	ldi		REG_TEMP_R17, EXTENSION_BACKGROUND
	rcall		exec_extension_addon

loop_end:
	rjmp		loop


; -----------
; Determination si les 5 vecteurs de "prolongation" definis dans le cas d'un ADDON
; -----------
addon_search_methods:
	ldi		REG_Z_LSB, low(end_of_prg_uos << 1)
	ldi		REG_Z_MSB, high(end_of_prg_uos << 1)

	ldi		REG_TEMP_R17, (2 * 5)

addon_search_loop:
	lpm		REG_TEMP_R16, Z+
	cpi		REG_TEMP_R16, 0xFF
	brne		addon_found

	; Parcours de tous les bytes des 5 vecteurs
	; => ADDON non trouve si tous les octets sont a 0xFF car 0xFFFF n'est
	;    pas un opcode valide et correspond a la valeur apres un "erase"
	adiw		REG_Z_LSB, 1
	dec		REG_TEMP_R17
	brne		addon_search_loop

addon_not_found:
	rjmp		addon_end

addon_found:
	lds		REG_TEMP_R16, G_BEHAVIOR
	sbr		REG_TEMP_R16, FLG_BEHAVIOR_ADDON_FOUND_MSK
	sts		G_BEHAVIOR, REG_TEMP_R16

addon_end:
	ret
; -----------

; -----------
; Appel eventuel a l'extension contenue dans 'REG_TEMP_R17'
; 1 - EXTENSION_SETUP
; 2 - EXTENSION_BACKGROUND
; 3 - EXTENSION_1_MS
; 4 - EXTENSION_COMMANDS
; 5 - EXTENSION_BUTTON
; -----------
exec_extension_addon:
	lds		REG_TEMP_R18, G_BEHAVIOR
	sbrs		REG_TEMP_R18, FLG_BEHAVIOR_ADDON_FOUND_IDX
	rjmp		exec_extension_addon_rtn

	; Appel au vecteur @ 'REG_TEMP_R17'
	ldi		REG_Z_LSB, low(end_of_prg_uos)
	ldi		REG_Z_MSB, high(end_of_prg_uos)
	add		REG_Z_LSB, REG_TEMP_R17
	clr		REG_TEMP_R17	
	adc		REG_Z_MSB, REG_TEMP_R17

	icall
	; Fin: Appel au vecteur @ 'REG_TEMP_R17'

exec_extension_addon_rtn:
	ret
; -----------

text_whoami:
.db	"### ATtiny85_uOS $Revision: 1.28 $", CHAR_LF, CHAR_NULL

.include		"ATtiny85_uOS_Macros.def"

.include		"ATtiny85_uOS_Misc.asm"
.include		"ATtiny85_uOS_Interrupts.asm"
.include		"ATtiny85_uOS_Timers.asm"
.include		"ATtiny85_uOS_Uart.asm"
.include		"ATtiny85_uOS_Eeprom.asm"

#ifndef USE_MINIMALIST
.include		"ATtiny85_uOS_Commands.asm"
#endif

.include		"ATtiny85_uOS_Print.asm"

end_of_prg_uos:		; Adresse de fin de uOS

; Pas d'inclusion de 'ATtiny85_uOS_Test_Addons.asm' si un ADDON est defini
#ifndef USE_ADDONS
; Test ADDON into uOS
.include		"ATtiny85_uOS_Test_Addons.asm"

.dseg
G_SRAM_END_OF_USE:					.byte		1
#endif
; Fin: Pas d'inclusion de 'ATtiny85_uOS_Test_Addons.asm' si un ADDON est defini

; End of file

