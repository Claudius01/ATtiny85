; "$Id: ATtiny85_uOS_Misc.asm,v 1.13 2025/12/17 12:45:46 administrateur Exp $"

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
	ldi		REG_X_MSB, high(ATTINY_RAMEND - 2)
	ldi		REG_X_LSB, low(ATTINY_RAMEND - 2)

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

	; Fin initialisation [SRAM_START, ..., (ATTINY_RAMEND - 2)]
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

#ifndef USE_MINIMALIST_UOS
	; Preparation reception bit RXD
	lds		REG_TEMP_R16, G_DURATION_DETECT_LINE_IDLE_MSB
	lds		REG_TEMP_R17, G_DURATION_DETECT_LINE_IDLE_LSB

	sts		G_UART_CPT_LINE_IDLE_MSB, REG_TEMP_R16
	sts		G_UART_CPT_LINE_IDLE_LSB, REG_TEMP_R17
	; Fin: Preparation reception bit RXD
#endif

	; Initialisation des definitions pour la vitesse UART/Rx et UART/Tx
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

#ifndef USE_MINIMALIST_UOS
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
; - Cadencement a 26uS par le timer materiel #1 (ATtiny85 cadence a 16 MHz - 62.5 nS / cycle)
; - Detection changement d'etat sur RXD sur la pin PINB<0> (PCINT0)
;
; Registres utilises (non sauvegardes/restaures):
;    REG_TEMP_R16 -> Valeur d'initialisation des registres materiels
;
; Calculs pour le cadencement @ a la vitesse de l'UART logiciel (ATtiny85 cadence a 16 MHz)
; - Periode de PCK et CK: 62.5 nS
;   => Le but est de cadencer par debordement Timer/Counter1 a 26 uS 
;      => 26 uS correspondent a 26000/62.5 = 416 cycles d'horloge a 16 MHz
;         => 416 etant > 255 -> le prescaler TCCR1 est requis avec CS1[3:0]: Clock Select Bits 3, 2, 1, and 0
;         => Prescaler sur PCK: 1/2, 1/4, 1/8, 1/16 et 1/32
;            avec 5 configurations possibles; a savoir:
;            - 208 si prescaler /2  CS1[3:0]: 0010
;            - 104 si prescaler /4  CS1[3:0]: 0011
;            -  52 si prescaler /8  CS1[3:0]: 0100
;            -  26 si prescaler /16 CS1[3:0]: 0101
;            -  13 si prescaler /32 CS1[3:0]: 0110
; ---------
init_hard:
	; Configuration du timer materiel #1 pour une It toutes les 26uS
	ldi		REG_TEMP_R16, (MSK_BIT_PULSE_IT | MSK_BIT_LED_RED | MSK_BIT_LED_GREEN | MSK_BIT_LED_YELLOW | MSK_BIT_LED_RED_INT)
	out		DDRB, REG_TEMP_R16

	; Initialisation du cadencement a 26 uS
	; TCCR1: Timer/Counter1 Control Register
	; - CTC1: Set Timer/Counter on Compare Match
	; OCR1C: Timer/Counter1 Output Compare RegisterC (value)
	ldi		REG_TEMP_R16, (1 << CTC1 | 1 << CS11)					; CS1[3:0]: 0010
	ldi		REG_TEMP_R17, (416 / 2)										; prescaler /2

#if 0		; Sequences d'initialisations a titre de documentation ;-)
	ldi		REG_TEMP_R16, (1 << CTC1 | 1 << CS11)					; CS1[3:0]: 0010
	ldi		REG_TEMP_R17, (416 / 2)										; prescaler /2

	ldi		REG_TEMP_R16, (1 << CTC1 | 1 << CS11 | 1 << CS10)	; CS1[3:0]: 0011
	ldi		REG_TEMP_R17, (416 / 4)										; prescaler /4

	ldi		REG_TEMP_R16, (1 << CTC1 | 1 << CS12)					; CS1[3:0]: 0100
	ldi		REG_TEMP_R17, (416 / 8)										; prescaler /8

	ldi		REG_TEMP_R16, (1 << CTC1 | 1 << CS12 | 1 << CS10)	; CS1[3:0]: 0101
	ldi		REG_TEMP_R17, (416 / 16)									; prescaler /16

	; Remarque: Dysfonctionnement avec 'prescaler /32' ?!..
	ldi		REG_TEMP_R16, (1 << CTC1 | 1 << CS12 | 1 << CS11)	; CS1[3:0]: 0110
	ldi		REG_TEMP_R17, (416 / 32)									; prescaler /32
#endif

	out		TCCR1, REG_TEMP_R16
	nop
	out		OCR1C, REG_TEMP_R17
	; Fin: Initialisation du cadencement a 26 uS

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
; delay_1uS avec un ATtiny85 16 MHz
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

	ret				;   + 4 = 18 Cycles ~= 1uS
; ---------

; ---------
; delay_1uS avec un ATtiny85 cadence a 16 MHz (62.5 nS / cycle)
; avec calibration...
;
; Warning: 'G_CALIBRATION' != 0
;
; Nbr de cycles @ 'REG_R5'
; - REG_R1 = 1 -> 12 cycles
; - REG_R1 = 2 -> 15 cycles (+3 cycles) -> 15 * 62.5 nS = 0.9375 uS => Valeur mesuree de ~1uS ;-)
; - REG_R1 = 3 -> 18 cycles (+3 cycles) -> 18 * 65.5 nS = 1.125 uS
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

#if USE_DUMP_SRAM
; ---------
; => Dump de la SRAM a l'image de la commande "<sAAAA"
;    => Inspire de la methode 'exec_command_type_s_read'
; ---------
dump_sram_read:
	ldi		REG_X_MSB, (SRAM_START / 256)
	ldi		REG_X_LSB, (SRAM_START % 256)

	; Dump de toute la SRAM
	; TODO: Calcul @ 'SRAM_START' et 'ATTINY_RAMEND'
	ldi		REG_TEMP_R17, 32
	rjmp		dump_sram_read_loop_0

	; Dump sur 8 x 16 bytes
	; TODO: Get 'G_TEST_VALUE_MSB_MORE:G_TEST_VALUE_LSB_MORE'
	ldi		REG_TEMP_R17, 8

dump_sram_read_loop_0:
	; Impression de 'X' ("[0xHHHH] ")
	rcall		print_2_bytes_hexa

	; Impression du dump ("[0x....]")
	ldi		REG_Z_MSB, ((text_hexa_value << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value << 1) % 256)
	rcall		push_text_in_fifo_tx

	ldi		REG_TEMP_R18, 16

dump_sram_read_loop_1:
	; Valeur de la SRAM indexee par 'REG_X_MSB:REG_X_LSB'
	ld			REG_TEMP_R16, X+
	rcall		convert_and_put_fifo_tx

	; Test limite 'ATTINY_RAMEND'
	; => On suppose qu'au depart 'X <= ATTINY_RAMEND'
	cpi		REG_X_MSB, ((ATTINY_RAMEND + 1) / 256)
	brne		dump_sram_read_more2
	cpi		REG_X_LSB, ((ATTINY_RAMEND + 1) % 256)
	brne		dump_sram_read_more2

	; Astuce pour gagner du code de presentation ;-)
	ldi		REG_TEMP_R18, 1
	ldi		REG_TEMP_R17, 1

dump_sram_read_more2:
	dec		REG_TEMP_R18
	brne		dump_sram_read_loop_1

	ldi		REG_Z_MSB, ((text_hexa_value_lf_end << 1) / 256)
	ldi		REG_Z_LSB, ((text_hexa_value_lf_end << 1) % 256)
	rcall		push_text_in_fifo_tx

	dec		REG_TEMP_R17
	brne		dump_sram_read_loop_0

	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK

	ret
; ---------
#endif

; End of file

