; "$Id: ATtiny85_uOS+DS18B20_Button.asm,v 1.2 2026/01/05 13:52:45 administrateur Exp $"

; Prolongation de l'appui bouton

.cseg

; ---------
exec_button_ds18b20:
; Emission du prompt de l'appui button
	ldi		REG_Z_MSB, ((text_ds18b20_button << 1) / 256)
	ldi		REG_Z_LSB, ((text_ds18b20_button << 1) % 256)
	_CALL		push_text_in_fifo_tx

	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

	ret
; ---------

text_ds18b20_button:
.db	"### DS18B20: Button action", CHAR_LF, CHAR_NULL

; End of file
