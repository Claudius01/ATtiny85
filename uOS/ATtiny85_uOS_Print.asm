; "$Id: ATtiny85_uOS_Print.asm,v 1.21 2026/01/03 15:44:35 administrateur Exp $"

.include		"ATtiny85_uOS_Print.h"

.cseg

#if !USE_MINIMALIST_UOS
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
#if !USE_USI
	; Pas de gestion de l'UART/Rx soft en mode 'USE_USI'
	sbrc		REG_FLAGS_0, FLG_0_UART_RX_BYTE_START_ERROR_IDX
	rjmp		presentation_error_reinit
	sbrc		REG_FLAGS_0, FLG_0_UART_RX_BYTE_STOP_ERROR_IDX
	rjmp		presentation_error_reinit
#endif

	sbrc		REG_FLAGS_1, FLG_1_UART_FIFO_RX_FULL_IDX
	rjmp		presentation_error_reinit

	sbrc		REG_FLAGS_1, FLG_1_UART_FIFO_TX_FULL_IDX
	rjmp		presentation_error_reinit

#if !USE_MINIMALIST_UOS
	lds		REG_TEMP_R16, G_TEST_FLAGS			; Prise des flags 'G_TEST_FLAGS'

	sbrc		REG_TEMP_R16, FLG_TEST_COMMAND_ERROR_IDX
	rjmp		presentation_error_reinit

	sbrc		REG_TEMP_R16, FLG_TEST_EEPROM_ERROR_IDX
	rjmp		presentation_error_reinit
#endif

	rjmp		presentation_error_rtn

presentation_error_reinit:
	; Reinitialisation timer 'TIMER_ERROR' tant que erreur(s) presente(s)
	ldi		REG_TEMP_R17, TIMER_ERROR
	ldi		REG_TEMP_R18, (200 % 256)
	ldi		REG_TEMP_R19, (200 / 256)
	ldi		REG_TEMP_R20, low(exec_timer_error)
	ldi		REG_TEMP_R21, high(exec_timer_error)
	rcall		start_timer

#if !USE_MINIMALIST_UOS
	; Effacement de certaines erreurs non fugitives
	lds		REG_TEMP_R16, G_TEST_FLAGS 
	cbr		REG_TEMP_R16, FLG_TEST_COMMAND_ERROR_MSK
	sts		G_TEST_FLAGS, REG_TEMP_R16
#endif

	cli
	setLedRedOn
	sei

presentation_error_rtn:
	ret
; ---------
#endif

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

#if !USE_MINIMALIST_UOS
; ---------
; Presentation de l'etat de connexion
; ---------
presentation_connexion:
	sbrs		REG_FLAGS_1, FLG_1_UART_FIFO_RX_NOT_EMPTY_IDX
	rjmp		presentation_connexion_fifo_rx_empty

presentation_connexion_fifo_rx_not_empty:
	; FIFO/Rx non vide
	; Test si 'Non Connecte' ?
	; => Si Oui: Changement chenillard
	sbrc		REG_FLAGS_1, FLG_1_CONNECTED_IDX
	rjmp		presentation_connexion_reinit_timer

	; Changement chenillard
	ldi		REG_TEMP_R16, 0xFE
	sts		G_CHENILLARD_MSB, REG_TEMP_R16
	sts		G_CHENILLARD_LSB, REG_TEMP_R16

presentation_connexion_reinit_timer:
	; Reinitialisation timer 'TIMER_CONNECT' tant que FIFO/Rx non vide
	ldi		REG_TEMP_R17, TIMER_CONNECT
	ldi		REG_TEMP_R18, (3000 % 256)
	ldi		REG_TEMP_R19, (3000 / 256)
	ldi		REG_TEMP_R20, low(exec_timer_connect)
	ldi		REG_TEMP_R21, high(exec_timer_connect)
	rcall		start_timer

	; Passage en mode 'Connecte' pour une presentation Led GREEN --\__/-----
	sbr		REG_FLAGS_1, FLG_1_CONNECTED_MSK
	;rjmp		presentation_connexion_rtn

presentation_connexion_fifo_rx_empty:
	; Passage en mode 'Non Connecte' a l'expiration du timer 'TIMER_CONNECT'

presentation_connexion_rtn:
	ret
; ---------
#endif

#if !USE_MINIMALIST_UOS
; ---------
uos_print_line_feed_skip:
print_line_feed_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret
#endif

uos_print_line_feed:
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
uos_print_1_byte_hexa_skip:
print_1_byte_hexa_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

uos_print_1_byte_hexa:
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
uos_print_2_bytes_hexa_skip:
print_2_bytes_hexa_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

uos_print_2_bytes_hexa:
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
; Marquage traces
; ---------
uos_print_mark_skip:
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
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK	; Flush...

	pop		REG_TEMP_R16

	ret
; ---------

#if !USE_MINIMALIST_UOS
; ---------
; Print du registre X
; ---------
uos_print_x_reg_skip:
print_x_reg_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret
#endif

; ---------
; En mode 'Minimaliste', l'addon 'ATtiny85_uOS_Test_Addons.asm' peut etre inclus
; => Appel a 'print_x_reg' dans les methodes de test ;-)
; ---------
uos_print_x_reg:
print_x_reg:
	push		REG_Z_MSB
	push		REG_Z_LSB

	rcall		print_2_bytes_hexa

	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

#if !USE_MINIMALIST_UOS
; ---------
; Print du registre Y
; ---------
uos_print_y_reg_skip:
print_y_reg_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

uos_print_y_reg:
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
; Print du registre Z
; ---------
uos_print_z_reg_skip:
print_z_reg_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret

uos_print_z_reg:
print_z_reg:
	push		REG_X_MSB
	push		REG_X_LSB

	movw		REG_X_LSB, REG_Z_LSB
	rcall		print_x_reg

	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------
#endif

text_hexa_value:
.db	"[0x", CHAR_NULL

text_hexa_value_end:
.db	"]", CHAR_NULL

text_hexa_value_lf_end:
.db	"]", CHAR_LF, CHAR_NULL, CHAR_NULL

text_line_feed:
.db	CHAR_LF, CHAR_NULL

#if 0		; Provision pour une conversion en majuscule
text_convert_hex_to_maj_ascii_table:
.db	"0123456789ABCDEF"
#endif

text_convert_hex_to_min_ascii_table:
.db	"0123456789abcdef"

; End of file

