; "$Id: ATtiny85_uOS+DS18B20_1_Wire.asm,v 1.9 2025/12/03 07:29:24 administrateur Exp $"

; ---------
; ds18b20_write_8_bits_command
; ---------
; Emission d'une commande de 8 bits contenue dans 'REG_TEMP_R16'
; => LSB en tete
; ---------
ds18b20_write_8_bits_command:
	ldi		REG_TEMP_R18, NBR_BITS_TO_SHIFT

ds18b20_write_8_bits_command_loop:
	ror		REG_TEMP_R16
	rcall		ds18b20_write_bit

	dec		REG_TEMP_R18
	brne		ds18b20_write_8_bits_command_loop

	ret
; ---------

; ---------
; ds18b20_read_response_72_bits:
; ds18b20_read_response_64_bits:
; ---------
; Lecture de la reponse sur 64 bits disponible dans [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 7)]
; Lecture de la reponse sur 72 bits disponible dans [G_DS18B20_BYTES_RESP, ..., (G_DS18B20_BYTES_RESP + 8)]
; ---------
ds18b20_read_response_72_bits:
	ldi		REG_TEMP_R19, (72 / 8)
	ldi		REG_TEMP_R18, 72
	rjmp		ds18b20_read_response_x_bits_loop

ds18b20_read_response_64_bits:
	ldi		REG_TEMP_R19, (64 / 8)
	ldi		REG_TEMP_R18, 64

ds18b20_read_response_x_bits_loop:
	rcall		ds18b20_read_bit

	rcall		ds18b20_shift_right_resp

	dec		REG_TEMP_R18
	brne		ds18b20_read_response_x_bits_loop

	ret
; ---------

; ---------
; Emission d'un bit contenu dans la Carry:
; - L'emission d'un bit a 0 consiste a presenter une pulse --\_____/---
;   avec un etat bas d'une duree superieure a 60uS (65uS implemente)
; - L'emission d'un bit a 1 consiste a presenter une pulse --\__/---
;   avec un etat bas d'une duree > 1 uS et < 15uS (10uS implemente)
; - L'etat haut est maintenu jusqu'a une duree de 70uS 
; ---------
ds18b20_write_bit:
	brcs		ds18b20_write_bit_1

ds18b20_write_bit_0:							; Pulse --\____/--
	sbi		PORTB, IDX_BIT_LED_GREEN	; Extinction Led GREEN
	cbi		PORTB, IDX_BIT_1_WIRE

	rcall		delay_65uS

	sbi		PORTB, IDX_BIT_1_WIRE

	rcall		delay_5uS
	rjmp		ds18b20_write_bit_end

ds18b20_write_bit_1:							; Pulse --\_/-----
	cbi		PORTB, IDX_BIT_1_WIRE

	call		uos_delay_10uS

	sbi		PORTB, IDX_BIT_1_WIRE

	rcall		delay_60uS

ds18b20_write_bit_end:
	ret
; ---------

; ---------
; La reception d'un bit retourne dans la Carry:
; - Mise a l'etat bas durant 5uS (la norme specifie > 1uS et < 15uS)
; - Attendre 10 uS avant la lecture de l'entree presentee par un esclave
; - Lecture a 0 ou 1 de l'entree
; ---------
; Lecture d'un bit disponible dans la Carry
;
; Chronograme
; - DDRB<2>:  ..../---------\_______/----------
; - PORTB<2>: ----\___/----------read----------
;                  3uS       10uS       55uS
;
; Pseudo Code:
;
;       DIRECT_MODE_OUTPUT(reg, mask);
;       DIRECT_WRITE_LOW(reg, mask);
;       delayMicroseconds(3);
;       DIRECT_MODE_INPUT(reg, mask);   // let pin float, pull up will raise
;       delayMicroseconds(10);
;       r = DIRECT_READ(reg, mask);
;       delayMicroseconds(55);
;     
; ---------
ds18b20_read_bit:
	sbi		DDRB, IDX_BIT_1_WIRE			; <PORTB<2> en sortie

	; Pulse --\_/---- durant 3uS
	sbi		PORTB, IDX_BIT_LED_GREEN	; Extinction Led GREEN
	cbi		PORTB, IDX_BIT_1_WIRE

	rcall		delay_5uS

	sbi		PORTB, IDX_BIT_1_WIRE

	cbi		DDRB, IDX_BIT_1_WIRE			; <PORTB<2> en entree

	call		uos_delay_10uS					; Attente de 10uS avant de lire le port

	; Lecture au temps (t0 + 15uS)
	clc											; <PORTB<2> a priori a 0 ...
	sbic		PINB, IDX_BIT_1_WIRE
	sec											; ... et non <PORTB<2> a 1

	;rcall		delay_65uS						; Attente de 65uS avant de sortir (total: 73uS)
	rcall		delay_55uS						; Attente de 55uS avant de sortir (total: 70uS)

	sbi		DDRB, IDX_BIT_1_WIRE			; <PORTB<2> en sortie avant de sortir

	ret
; ---------

; ---------
; Propagation de la Carry et decalage d'un bit a droite
; sur les 'REG_TEMP_R19' bytes a partir de 'G_DS18B20_BYTES_RESP'
; ou a partir de 'G_DS18B20_BYTES_ROM'
; ---------
ds18b20_shift_right_resp:
; ---------
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_RESP)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_RESP)
	rjmp		ds18b20_shift_right

ds18b20_shift_right_rom:
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_ROM)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_ROM)
	;rjmp		ds18b20_shift_right

ds18b20_shift_right:

	push		REG_TEMP_R19

ds18b20_shift_right_resp_loop:
#if USE_DS18B20_TRACE
	in			REG_SAVE_SREG, SREG				; Save SREG

	mov		REG_X_MSB, REG_Y_MSB
	mov		REG_X_LSB, REG_Y_LSB
	rcall		uos_print_2_bytes_hexa_skip
#endif

	ld			REG_TEMP_R16, Y

#if USE_DS18B20_TRACE
	mov		REG_X_LSB, REG_TEMP_R16
	push		REG_TEMP_R16
	rcall		uos_print_1_byte_hexa_skip
	rcall		uos_print_line_feed_skip
	pop		REG_TEMP_R16
	out		SREG, REG_SAVE_SREG				; Restore SREG
#endif

	ror		REG_TEMP_R16
	st			Y+, REG_TEMP_R16	

	dec		REG_TEMP_R19
	brne		ds18b20_shift_right_resp_loop

	pop		REG_TEMP_R19
	ret
; ---------

; ---------
; Propagation de la Carry et decalage d'un bit a droite
; sur les 'REG_TEMP_R19' bytes a partir de 'G_DS18B20_BYTES_SEND'
; ---------
ds18b20_shift_right_send:
; ---------
	ldi		REG_Y_MSB, high(G_DS18B20_BYTES_SEND)
	ldi		REG_Y_LSB, low(G_DS18B20_BYTES_SEND)

	push		REG_TEMP_R19

ds18b20_shift_right_send_loop:
	ld			REG_TEMP_R16, Y

	ror		REG_TEMP_R16
	st			Y+, REG_TEMP_R16	

	dec		REG_TEMP_R19
	brne		ds18b20_shift_right_send_loop

	pop		REG_TEMP_R19
	ret
; ---------

; ---------
; Routines d'attente
;
; Remarque: Les routines d'attente de 1uS et 10uS sont implementees dans uOS
; ---------
delay_65uS:
	rcall		delay_5uS

delay_60uS:
	rcall		delay_5uS

delay_55uS:
	call		uos_delay_10uS
	call		uos_delay_10uS
	call		uos_delay_10uS
	call		uos_delay_10uS
	call		uos_delay_10uS

delay_5uS:
	call		uos_delay_1uS
	call		uos_delay_1uS
	call		uos_delay_1uS
	call		uos_delay_1uS
	call		uos_delay_1uS

	ret
; ---------

; End of file

