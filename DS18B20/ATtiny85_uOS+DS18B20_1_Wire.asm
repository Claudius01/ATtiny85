; "$Id: ATtiny85_uOS+DS18B20_1_Wire.asm,v 1.3 2025/11/28 14:03:32 administrateur Exp $"

; ---------
; Emission d'un bit contenu dans la Carry
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

	rcall		delay_10uS

	sbi		PORTB, IDX_BIT_1_WIRE

	rcall		delay_55uS

ds18b20_write_bit_end:
	ret
; ---------

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

	rcall		delay_3uS

	sbi		PORTB, IDX_BIT_1_WIRE

	cbi		DDRB, IDX_BIT_1_WIRE			; <PORTB<2> en entree

	rcall		delay_10uS						; Attente de 10uS avant de lire le port

	clc											; <PORTB<2> a priori a 0 ...
	sbic		PINB, IDX_BIT_1_WIRE
	sec											; ... et non <PORTB<2> a 1

	rcall		delay_65uS						; Attente de 65uS avant de sortir (total: 73uS)

	sbi		DDRB, IDX_BIT_1_WIRE			; <PORTB<2> en sortie avant de sortir

	ret
; ---------

; ---------
; Routines d'attente
;
; Remarque: La routine d'attente de 1uS est implementee dans uOS et doit etre
;           appelee par un 'call' pour garantire les temps d'attente de 1uS
; ---------
delay_3uS:
	call		uos_delay_1uS
	call		uos_delay_1uS
	call		uos_delay_1uS
	ret

delay_5uS:
	call		uos_delay_1uS
	call		uos_delay_1uS
	call		uos_delay_1uS
	call		uos_delay_1uS
	call		uos_delay_1uS
	ret

delay_10uS:
	rcall		delay_5uS
	rcall		delay_5uS
	ret

delay_55uS:
	rcall		delay_10uS
	rcall		delay_10uS
	rcall		delay_10uS
	rcall		delay_10uS
	rcall		delay_10uS
	rcall		delay_5uS
	ret

delay_65uS:
	rcall		delay_55uS
	rcall		delay_10uS
	ret
; ---------

; End of file

