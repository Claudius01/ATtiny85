; "$Id: ATtiny85_uOS+DS18B20_1_Wire.asm,v 1.7 2025/11/29 12:31:38 administrateur Exp $"

; ---------
; ds18b20_write_8_bits_command
; ---------
; Emission d'une commande de 8 bits contenue dans 'REG_TEMP_R16'
; => LSB en tete
; ---------
ds18b20_write_8_bits_command:
	ldi		REG_TEMP_R18, 8

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
	ldi		REG_TEMP_R19, 9
	ldi		REG_TEMP_R18, 72
	rjmp		ds18b20_read_response_x_bits_loop

ds18b20_read_response_64_bits:
	ldi		REG_TEMP_R19, 8
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

