; "$Id: ATtiny85_uOS_Test_Addons.asm,v 1.14 2026/01/02 18:28:56 administrateur Exp $"

; Test d'addons dans uOS

#define TIMER_UOS_TEST								5	; Timer #5

.dseg
G_TEST_ADDON_CPT_BACKGROUND_3:		.byte		1
G_TEST_ADDON_CPT_BACKGROUND_2:		.byte		1
G_TEST_ADDON_CPT_BACKGROUND_1:		.byte		1
G_TEST_ADDON_CPT_BACKGROUND_0:		.byte		1

G_TEST_ADDON_CPT_1_SEC_MSB:			.byte		1
G_TEST_ADDON_CPT_1_SEC_LSB:			.byte		1

G_TEST_ADDON_CPT_1_MS_MSB:				.byte		1
G_TEST_ADDON_CPT_1_MS_LSB:				.byte		1

.cseg

; Definitions de la table de vecteurs de "prolongation" des 4 traitements:
; geres par uOS qui passe la main aux methodes specifiques a l'ADDON
; - #0: Initialisation materielle et logicielle (prolongation du 'setup' de uOS)
; - #1: Traitements en fond de tache
; - #2: Traitements toutes les 1 mS
; - #3: Traitements des nouvelles commandes non supportees par uOS
; - #4: Traitements associes a l'appui bouton avant ceux effectues par uOS
;
; => Toujours definir les 5 adresses avec un 'rjmp' ou un 'ret'
;    si pas de "prolongation" des traitements
;
; => Le nommage est libre et non utilise par uOS
;    => Seul l'adresse du traitement est impose dans l'ordre defini plus haut
; --------
uos_test_setup:
	rjmp		uos_test_setup_contd

uos_test_background:
	rjmp		uos_test_background_contd

uos_test_1_ms:
	rjmp		uos_test_1_ms_contd

uos_test_commands:
	rjmp		uos_test_commands_contd

uos_test_button:
	rjmp		uos_test_button_contd

; Fin: Definitions de la table de vecteurs de "prolongation" des 4 traitements:

; --------
; Prolongations des traitements
; --------
uos_test_setup_contd:
	ldi      REG_Z_MSB, high(text_test_setup << 1)
	ldi      REG_Z_LSB, low(text_test_setup << 1)
	rcall    push_text_in_fifo_tx
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

	; Initialisation timer 'TIMER_UOS_TEST'
	ldi		REG_TEMP_R17, TIMER_UOS_TEST
	ldi		REG_TEMP_R18, (10000 % 256)
	ldi		REG_TEMP_R19, (10000 / 256)
	ldi		REG_TEMP_R20, low(uos_test_timer)
	ldi		REG_TEMP_R21, high(uos_test_timer)
	rcall		start_timer

	ret
; --------

; --------
uos_test_background_contd:
	; Sommation sur 32 bits
	lds		REG_X_MSB, G_TEST_ADDON_CPT_BACKGROUND_1
	lds		REG_X_LSB, G_TEST_ADDON_CPT_BACKGROUND_0
	adiw		REG_X_LSB, 1
	sts		G_TEST_ADDON_CPT_BACKGROUND_1, REG_X_MSB
	sts		G_TEST_ADDON_CPT_BACKGROUND_0, REG_X_LSB
	brne		uos_test_background_more

	lds		REG_X_MSB, G_TEST_ADDON_CPT_BACKGROUND_3
	lds		REG_X_LSB, G_TEST_ADDON_CPT_BACKGROUND_2
	adiw		REG_X_LSB, 1
	sts		G_TEST_ADDON_CPT_BACKGROUND_3, REG_X_MSB
	sts		G_TEST_ADDON_CPT_BACKGROUND_2, REG_X_LSB

uos_test_background_more:
	ret
; --------

; --------
uos_test_1_ms_contd:
	lds		REG_X_MSB, G_TEST_ADDON_CPT_1_MS_MSB
	lds		REG_X_LSB, G_TEST_ADDON_CPT_1_MS_LSB
	adiw		REG_X_LSB, 1

	push		REG_X_MSB		; Sauvegarde compteur avant test
	push		REG_X_LSB

	; Test si 500 mS ecoulee...
	cpi		REG_X_MSB, (1000 / 256)
	brne		uos_test_1_ms_end
	cpi		REG_X_LSB, (1000 % 256)
	brne		uos_test_1_ms_end

	; 1 Sec ecoulee
	lds		REG_X_MSB, G_TEST_ADDON_CPT_1_SEC_MSB
	lds		REG_X_LSB, G_TEST_ADDON_CPT_1_SEC_LSB
	adiw		REG_X_LSB, 1
	sts		G_TEST_ADDON_CPT_1_SEC_MSB, REG_X_MSB
	sts		G_TEST_ADDON_CPT_1_SEC_LSB, REG_X_LSB

	; Trace du compteur de secondes
	rcall		print_x_reg

	; Print du compteur sur 32 bits 'G_TEST_ADDON_CPT_BACKGROUND' sous la forme [xxxx][yyyy]
	lds		REG_X_MSB, G_TEST_ADDON_CPT_BACKGROUND_3
	lds		REG_X_LSB, G_TEST_ADDON_CPT_BACKGROUND_2
	rcall		print_x_reg

	lds		REG_X_MSB, G_TEST_ADDON_CPT_BACKGROUND_1
	lds		REG_X_LSB, G_TEST_ADDON_CPT_BACKGROUND_0
	rcall		print_x_reg

	; Fin: Trace du compteur de secondes

	; => Trace du texte "] uOS: Test 1 mS..."
	ldi      REG_Z_MSB, high(text_test_1_ms << 1)
	ldi      REG_Z_LSB, low(text_test_1_ms << 1)
	rcall    push_text_in_fifo_tx

	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

	pop		REG_X_LSB		; Restauration pile d'appel...
	pop		REG_X_MSB

	clr		REG_X_MSB		; ... et raz compteur ;-)
	clr		REG_X_LSB

	; Raz du compteur de passage dans le fond tache
	clr		REG_TEMP_R16
	sts		G_TEST_ADDON_CPT_BACKGROUND_3, REG_TEMP_R16
	sts		G_TEST_ADDON_CPT_BACKGROUND_2, REG_TEMP_R16
	sts		G_TEST_ADDON_CPT_BACKGROUND_1, REG_TEMP_R16
	sts		G_TEST_ADDON_CPT_BACKGROUND_0, REG_TEMP_R16

	rjmp		uos_test_1_ms_save
	; Fin: 1 Sec ecoulee

uos_test_1_ms_end:
	pop		REG_X_LSB		; Restauration compteur
	pop		REG_X_MSB

uos_test_1_ms_save:
	sts		G_TEST_ADDON_CPT_1_MS_MSB, REG_X_MSB
	sts		G_TEST_ADDON_CPT_1_MS_LSB, REG_X_LSB

	ret
; --------

; --------
uos_test_commands_contd:
	cpi      REG_TEMP_R16, 't'
	brne		uos_test_commands_contd_ko

	ldi      REG_Z_MSB, high(text_test_commands << 1)
	ldi      REG_Z_LSB, low(text_test_commands << 1)
	rcall    push_text_in_fifo_tx

#if !USE_MINIMALIST_UOS
	rcall		uos_print_command_ok				; Commande reconnue
#endif

	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

#if !USE_MINIMALIST_UOS
	rjmp		uos_test_commands_contd_end
#endif

uos_test_commands_contd_ko:
#if !USE_MINIMALIST_UOS
	rcall		uos_print_command_ko				; Commande non reconnue
#endif

uos_test_commands_contd_end:
	ret
; --------

; --------
uos_test_button_contd:
	ldi      REG_Z_MSB, high(text_test_button << 1)
	ldi      REG_Z_LSB, low(text_test_button << 1)
	rcall    push_text_in_fifo_tx
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

	ret
; --------

; --------
uos_test_timer:
	ldi      REG_Z_MSB, high(text_test_timer << 1)
	ldi      REG_Z_LSB, low(text_test_timer << 1)
	rcall    push_text_in_fifo_tx
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

	; Reinitialisation timer 'TIMER_UOS_TEST'
	ldi		REG_TEMP_R17, TIMER_UOS_TEST
	ldi		REG_TEMP_R18, (10000 % 256)
	ldi		REG_TEMP_R19, (10000 / 256)
	ldi		REG_TEMP_R20, low(uos_test_timer)
	ldi		REG_TEMP_R21, high(uos_test_timer)
	rcall		start_timer

	ret
; --------

text_test_setup:
.db   "uOS: Test setup", CHAR_LF, CHAR_NULL, CHAR_NULL

text_test_1_ms:
.db   "] uOS: Test 1 mS (1000 passages)", CHAR_LF, CHAR_NULL

; ie. "[12] uOS: Test command]
text_test_commands:
.db   "] uOS: Test command", CHAR_LF, CHAR_NULL, CHAR_NULL

text_test_button:
.db   "uOS: Test button", CHAR_LF, CHAR_NULL

text_test_timer:
.db   "uOS: Test timer (10 Sec.)", CHAR_LF, CHAR_NULL, CHAR_NULL

text_bit_reverse:
.db   "Bit Reverse ", CHAR_NULL, CHAR_NULL

; Fin: Definitions de la table de vecteurs de "prolongation" des traitements

; End of file

