; "$Id: ATtiny85_uOS_Misc.asm,v 1.6 2025/12/05 17:18:56 administrateur Exp $"

.include		"ATtiny85_uOS_Misc.h"

.cseg
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
	cpi		REG_X_MSB, high(SRAM_START - 1)
	brne		init_sram_fill_loop_b
	cpi		REG_X_LSB, low(SRAM_START - 1)	
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

	; Initialisation des definitions pour la vitesse UART/Rx et UART/Tx
#if 0
	; TODO: => Reprise de la prise 'const_for_bauds_rate'
	ldi		REG_TEMP_R16, NBR_BAUDS_VALUE

	ldi		REG_TEMP_R16, (DURATION_DETECT_LINE_IDLE / 256)
	sts		G_DURATION_DETECT_LINE_IDLE_MSB, REG_TEMP_R16
	ldi		REG_TEMP_R17, (DURATION_DETECT_LINE_IDLE % 256)
	sts		G_DURATION_DETECT_LINE_IDLE_LSB, REG_TEMP_R17

	ldi		REG_TEMP_R16, DURATION_WAIT_READ_BIT_START
	sts		G_DURATION_WAIT_READ_BIT_START, REG_TEMP_R16
#else
	; Reprise des definitions de 'const_for_bauds_rate'
	; @ 'G_BAUDS_IDX' recopie de l'EEPROM

   ; Lecture de l'index des Bauds
	ldi		REG_X_MSB, high(EEPROM_ADDR_BAUDS_IDX);
	ldi		REG_X_LSB, low(EEPROM_ADDR_BAUDS_IDX);
	rcall		eeprom_read_byte

	; Test dans la plage [0, 1, ..., 6]
	; => Forcage a 1 pour 9600 bauds si pas dans la plage
	cpi		REG_TEMP_R16, (6 + 1)
	brlo		init_sram_values_set_bauds_index
	ldi		REG_TEMP_R16, 1

init_sram_values_set_bauds_index:
	sts		G_BAUDS_IDX, REG_TEMP_R16

	ldi		REG_Z_MSB, high(const_for_bauds_rate << 1)
	ldi		REG_Z_LSB, low(const_for_bauds_rate << 1)

	; Pointage sur l'adresse ('const_for_bauds_rate' + 4 * 'G_BAUDS_IDX')
	lds		REG_TEMP_R16, G_BAUDS_IDX
	lsl		REG_TEMP_R16						; x 2
	lsl		REG_TEMP_R16						; x 2
	add		REG_Z_LSB, REG_TEMP_R16
	clr		REG_TEMP_R16						; Report de la Carry
	adc		REG_Z_MSB, REG_TEMP_R16

	; Lecture des 4 definitions...
	lpm		REG_TEMP_R17, Z+
	sts		G_BAUDS_VALUE, REG_TEMP_R17
	lpm		REG_TEMP_R17, Z+
	sts		G_DURATION_DETECT_LINE_IDLE_MSB, REG_TEMP_R17
	lpm		REG_TEMP_R17, Z+
	sts		G_DURATION_DETECT_LINE_IDLE_LSB, REG_TEMP_R17
	lpm		REG_TEMP_R17, Z+
	sts		G_DURATION_WAIT_READ_BIT_START, REG_TEMP_R17
#endif
	; Fin: Initialisation des definitions pour la vitesse UART/Rx et UART/Tx

	ldi		REG_TEMP_R16, CPT_CALIBRATION
	sts		G_CALIBRATION, REG_TEMP_R16

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
	nop				; 4 + 1 Cycles (rcall ou call + nop)
	nop				;   +	1
	nop				;   + 1
	nop				;   + 1
	nop				;   + 1
	nop				;   + 1

#if 1
	nop				;   + 1
	nop				;   + 1
	nop				;   + 1
#endif

	ret				;   + 4 = xx Cycles = 1uS
; ---------

; ---------
; delay_1uS avec un ATtiny85 20MHz
; avec calibration...
;
; Warning: 'G_CALIBRATION' != 0
;
; Nbr de cycles @ 'REG_R5'
; - REG_R1 = 1 -> 12 cycles
; - REG_R1 = 2 -> 15 cycles (+3 cycles)  => Valeur mesuree de ~1uS ;-)
; - REG_R1 = 3 -> 18 cycles (+3 cycles)
; - etc.
;
uos_delay_1uS:
	lds		REG_R5, G_CALIBRATION		;  4 (rcall ou call) + 2 cycles

uos_delay_1uS_loop:
	dec		REG_R5							; Content of 'REG_R5' x cycle(s)
	brne		uos_delay_1uS_loop			; +2 ou +1 cycles

	ret											; +4 cycles
; ---------

; ---------
uos_delay_10uS:
	rcall		uos_delay_1uS					; #0
	rcall		uos_delay_1uS					; #1
	rcall		uos_delay_1uS					; #2
	rcall		uos_delay_1uS					; #3
	rcall		uos_delay_1uS					; #4
	rcall		uos_delay_1uS					; #5
	rcall		uos_delay_1uS					; #6
	rcall		uos_delay_1uS					; #7
	rcall		uos_delay_1uS					; #8
	rcall		uos_delay_1uS					; #9

	ret
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

; ---------
; Mise sur voie de garage avec clignotement Led RED
; ---------
forever_1:
	cli
	ldi		REG_TEMP_R16, 20	; Clignotement rapide
	rjmp		forever_init

forever_2:
	cli
	ldi		REG_TEMP_R16, 40	; Clignotement lent

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

; End of file

