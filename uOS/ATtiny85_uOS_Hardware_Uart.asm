; "$Id: ATtiny85_uOS_Hardware_Uart.asm,v 1.9 2026/01/12 10:41:21 administrateur Exp $"

; Implementation de la version hardware avec l'USI
; Cf. La note d'application de Atmel
;     'https://ww1.microchip.com/downloads/aemDocuments/documents/OTH/ApplicationNotes/ApplicationNotes/doc4300.pdf'

.include    "ATtiny85_uOS_Hardware_Uart.h"

.cseg

#if !USE_MINIMALIST_UOS
; ---------
; Gestion des FIFOs UART/Rx et UART/Tx
;
; Usages:
;      mov		REG_R1, <data>			; Donnee a ecrire
;      rcall   uart_fifo_rx|tx_write
;      => Retour: SREG<Bit> = 1 si FIFO/Rx|Tx pleine
;
;      rcall	uart_fifo_rx|tx_read
;      => Retour: Donnee dans G_STACK_RESULTS si SREG<Bit> = 1
;
; Registres utilises (non sauvegardes/restaures):
;    REG_X_LSB:REG_X_LSB -> Pointeur sur les pointeurs ecriture/lecture/data
;    REG_TEMP_R16        -> Working register
;    REG_TEMP_R17        -> Pointeur d'ecriture courant
;    REG_TEMP_R18        -> Pointeur de lecture courant
;
; Warning: Methode appelee sous l'It 'tim1_compa_isr'
; ---------
uart_fifo_rx_write:
	ldi		REG_X_MSB, (G_UART_FIFO_RX_DATA / 256)		; Indexation dans la FIFO/Rx
	ldi		REG_X_LSB, (G_UART_FIFO_RX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_RX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_RX_READ			; Pointeur de lecture courant

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R17	; XL += REG_TEMP_R17
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	st			X, REG_R1			; Ecriture donnee dans [G_UART_FIFO_RX_DATA, ..., G_UART_FIFO_RX_DATA_END]

	inc		REG_TEMP_R17
	andi		REG_TEMP_R17, (SIZE_UART_FIFO_RX - 1)		; Pointeur d'ecriture dans [0, ..., [SIZE_UART_FIFO_RX - 1)]
	sts		G_UART_FIFO_RX_WRITE, REG_TEMP_R17			; Maj pointeur d'ecriture

	; Indication FIFO/Rx non vide
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK

	; Indication si FIFO/Rx pleine
	; => FIFO/Rx pleine si le pointeur d'ecriture "rejoint" le pointeur de lecture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_FULL_MSK 		; FIFO/Rx a priori non pleine ...
	clt																	; SREG<T> = 0
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		uart_fifo_rx_write_rtn
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_FULL_MSK		; ... et non, FIFO/Rx pleine
	set																	; SREG<T> = 1

	; Maj compteur d'erreurs
	rcall		update_errors

uart_fifo_rx_write_rtn:
	ret
; ---------

; ---------
uart_fifo_rx_read:
	ldi		REG_X_MSB, (G_UART_FIFO_RX_DATA / 256)		; Indexation dans la FIFO/Rx
	ldi		REG_X_LSB, (G_UART_FIFO_RX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_RX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_RX_READ			; Pointeur de lecture courant

	; Sortie prematuree si rien a lire
	clt													; A priori pas de donnee a lire
	cp			REG_TEMP_R17, REG_TEMP_R18
	breq		uart_fifo_rx_read_end				; Pointeurs egaux => FIFO/Rx trouvee vide

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R18	; XL += REG_TEMP_R18
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	ld			REG_R2, X					; Lecture de la donnee dans [G_UART_FIFO_RX_DATA, ..., G_UART_FIFO_RX_DATA_END]
	set										; Indication donnee disponible

	inc		REG_TEMP_R18
	andi		REG_TEMP_R18, (SIZE_UART_FIFO_RX - 1)		; Pointeur de lecture dans [0, ..., [SIZE_UART_FIFO_RX - 1)]
	sts		G_UART_FIFO_RX_READ, REG_TEMP_R18

	; Indication FIFO/Rx vide ou non vide apres la lecture
	; => FIFO/Rx vide si le pointeur de lecture "rejoint" le pointeur ecriture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
uart_fifo_rx_read_test_empty:
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		; FIFO/Rx a priori non vide...
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		uart_fifo_rx_read_rtn

uart_fifo_rx_read_end:
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		; ... et non, FIFO/Rx vide

uart_fifo_rx_read_rtn:
	ret
; ---------
#endif

; ---------
uart_fifo_tx_write:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_TEMP_R16
	push		REG_TEMP_R17
	push		REG_TEMP_R18

	ldi		REG_X_MSB, (G_UART_FIFO_TX_DATA / 256)	; Indexation dans la FIFO/Tx et ses 2 pointeurs
	ldi		REG_X_LSB, (G_UART_FIFO_TX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_TX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_TX_READ			; Pointeur de lecture courant

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R17			; XL += REG_TEMP_R17
	adc		REG_X_MSB, REG_TEMP_R16			; XH += 0 + Carry

	st			X, REG_R3			; Ecriture donnee dans [G_UART_FIFO_TX_DATA, ..., G_UART_FIFO_TX_DATA_END]

	inc		REG_TEMP_R17
	andi		REG_TEMP_R17, (SIZE_UART_FIFO_TX - 1)		; Pointeur d'ecriture dans [0, ..., [SIZE_UART_FIFO_TX - 1)]
	sts		G_UART_FIFO_TX_WRITE, REG_TEMP_R17			; Maj pointeur d'ecriture

	; Indication FIFO/Tx non vide
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK

	; Emision de tous les caracteres de la FIFO/Tx jusqu'au dernier des que le pointeur d'ecriture (REG_TEMP_R17)
	; atteint le pointeur de lecture (REG_TEMP_R18) -(SIZE_UART_FIFO_TX / 2) modulo SIZE_UART_FIFO_TX
	; => Revient a vider la FIFO/Tx des que celle-ci est pleine a 50%
	;    => Au dessous des 50%, les caracteres seront emis en fond de tache grace a l'appel de 'fifo_tx_to_send_async'
	;    => Evite d'appeler dans le code la methode 'fifo_tx_to_send_sync' pour ne pas saturer la FIFO/Tx ;-)
	mov		REG_TEMP_R16, REG_TEMP_R18
	subi		REG_TEMP_R16, (SIZE_UART_FIFO_TX / 2)		; Seuil a 50 % d'occupation de la FIFO/Tx
	andi		REG_TEMP_R16, (SIZE_UART_FIFO_TX - 1)		; Modulo SIZE_UART_FIFO_TX
	cp			REG_TEMP_R16, REG_TEMP_R17
	brne		uart_fifo_tx_write_skip

	rcall		fifo_tx_to_send_sync

uart_fifo_tx_write_skip:
	; Fin: Emision de tous les caracteres de la FIFO/Tx...

	; Indication si FIFO pleine
	; => FIFO pleine si le pointeur d'ecriture "rejoint" le pointeur de lecture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_FULL_MSK 		; FIFO/Rx a priori non pleine ...
	clt																	; SREG<T> = 0
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		uart_fifo_tx_write_rtn
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_FULL_MSK		; ... et non, FIFO/Rx pleine
	set																	; SREG<T> = 1

	; Ne doit jamais arrive ;-)...
	; Mise sur voie de garage si FIFO/Tx pleine
	rjmp		forever_1

uart_fifo_tx_write_rtn:
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_TEMP_R16
	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
uart_fifo_tx_read:
	push		REG_X_MSB
	push		REG_X_LSB
	push		REG_TEMP_R17
	push		REG_TEMP_R18

	ldi		REG_X_MSB, (G_UART_FIFO_TX_DATA / 256)	; Indexation dans la FIFO/Tx et ses 2 pointeurs
	ldi		REG_X_LSB, (G_UART_FIFO_TX_DATA % 256)
	lds		REG_TEMP_R17, G_UART_FIFO_TX_WRITE			; Pointeur d'ecriture courant
	lds		REG_TEMP_R18, G_UART_FIFO_TX_READ			; Pointeur d'ecriture courant

	; Sortie prematuree si rien a lire
	clt														; A priori pas de donnee a lire
	cp			REG_TEMP_R17, REG_TEMP_R18
	breq		uart_fifo_tx_read_end					; Pas de lecture => maj flags

	clr		REG_TEMP_R16
	add		REG_X_LSB, REG_TEMP_R18	; XL += REG_TEMP_R18
	adc		REG_X_MSB, REG_TEMP_R16	; XH += 0 + Carry

	ld			REG_R4, X			; Lecture de la donnee dans [G_UART_FIFO_TX_DATA, ..., G_UART_FIFO_TX_DATA_END]
	set								; Indication donnee disponible

	inc		REG_TEMP_R18
	andi		REG_TEMP_R18, (SIZE_UART_FIFO_TX - 1)		; Pointeur de lecture dans [0, ..., [SIZE_UART_FIFO_TX - 1)]
	sts		G_UART_FIFO_TX_READ, REG_TEMP_R18

	; Indication FIFO/Tx vide ou non vide apres la lecture
	; => FIFO/Tx vide si le pointeur de lecture "rejoint" le pointeur ecriture
	;    => Soit (REG_TEMP_R17 == REG_TEMP_R18) ici
uart_fifo_tx_read_test_empty:
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		; FIFO/Rx a priori non vide...
	cp			REG_TEMP_R17, REG_TEMP_R18
	brne		uart_fifo_tx_read_rtn

uart_fifo_tx_read_end:
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		; ... et non, FIFO/Rx vide

uart_fifo_tx_read_rtn:
	pop		REG_TEMP_R18
	pop		REG_TEMP_R17
	pop		REG_X_LSB
	pop		REG_X_MSB
	ret
; ---------

; ---------
; Emission d'un caractere sur Tx
; => Initialise 'G_UART_BYTE_TX_LSB:G_UART_BYTE_TX_MSB' et positionne 'FLG_1_UART_TX_TO_SEND' a 1
;    => Le mot constitue du Bit Start + 8 Datas + 1 ou 2 Bits Stop sera emis sous
;       l'It 'tim1_compa_isr' au moyen de 'G_UART_CPT_DURATION_1BIT_TX' @ 26uS et
;       'G_UART_CPT_NBR_BITS_TX' initialise a ((1+8+1) + x) (x Bits Stop)
;
; Usage:
;      mov		REG_TEMP_R16, <data>
;      rcall   uart_tx_send
;
; Registres utilises (sauvegardes/restaures):
;    REG_TEMP_R16        -> Byte a emettre
;    REG_TEMP_R17        -> Working register
; ---------
uart_tx_send:
	; Test du caractere dans la plage [0x20, 0x21, ..., 0x7F] ou '\n'
	rcall		test_char_valid
	brtc		uart_tx_send_rtn

	push		REG_TEMP_R16
	push		REG_TEMP_R17

	; Code tire de la gestion USI en Langage C
	; Reverse the bits...
	; 'REG_TEMP_R16' -> 'REG_TEMP_R16'
	rcall		bit_reverse
	sts		G_TEMP_TX_CHAR, REG_TEMP_R16	

	cli

	; Disable PCINT0 interrupt
	; PCMSK &= ~_BV(PCINT0);
	cbi		PCMSK, PCINT0

	; Disable USI
	; USICR = 0;
	clr		REG_TEMP_R16
	out		USICR, REG_TEMP_R16

	; USIDR = (tempTxChar >> 1);
	lds		REG_TEMP_R17, G_TEMP_TX_CHAR
	lsr		REG_TEMP_R17	
	out		USIDR, REG_TEMP_R17

	; TCNT0 = 0;
	out		TCNT0, REG_TEMP_R16

	; OCR0A = (uint8_t)TIMER_TICK;
	ldi		REG_TEMP_R16, 0x1A
   out		OCR0A, REG_TEMP_R16

	; USI settings
	; USISR = _BV(USIOIF) | _BV(USICNT3) | _BV(USICNT2) | _BV(USICNT1);
	ldi		REG_TEMP_R16, 0x4E
	out		USISR, REG_TEMP_R16

	; USICR = _BV(USICS0) | _BV(USIOIE) | _BV(USIWM0);
	ldi		REG_TEMP_R16, 0x54
	out		USICR, REG_TEMP_R16

	; Preparation emission
	; state = TX;
	ldi		REG_TEMP_R16, STATE_USI_TX
	sts		G_STATE_USI, REG_TEMP_R16

	; Attente de l'emission du caractere
	sei

	; while (state != END_OF_TX);
uart_tx_send_wait:
	lds		REG_TEMP_R16, G_STATE_USI
	cpi		REG_TEMP_R16, STATE_USI_END_OF_TX
	brne  	uart_tx_send_wait
	; Fin: Attente de l'emission du caractere

	cli

	; Enable RX
	; state = RX;             // Change to RX state
	ldi		REG_TEMP_R16, STATE_USI_RX
	sts		G_STATE_USI, REG_TEMP_R16

	; USICR = 0;              // Disable USI
	clr		REG_TEMP_R16
	out		USICR, REG_TEMP_R16

	; GIFR |= _BV(PCIF);      // Clear Pin change interrupt flag
	in			REG_TEMP_R16, GIFR
	ori		REG_TEMP_R16, (1 << PCIF)
	out		GIFR, REG_TEMP_R16

	; PCMSK |= _BV(PCINT0);   // Reenable interrupt on PCINT0
	sbi		PCMSK, PCINT0
	; Fin: Code tire de la gestion USI en Langage C

	cbr		REG_FLAGS_0, FLG_0_UART_TX_TO_SEND_MSK		; Fin de l'emission

	pop		REG_TEMP_R17
	pop		REG_TEMP_R16

	sei

uart_tx_send_rtn:
	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un texte termine par '\0'
;
; Usage:
;      ldi		REG_Z_MSB, <address MSB>
;      ldi		REG_Z_LSB, <address LSB>
;      rcall   push_text_in_fifo_tx
;
; Registres utilises
;    REG_Z_LSB:REG_Z_LSB -> Pointeur sur le texte en memoire programme (preserve)
;    REG_TEMP_R16        -> Working register (preserve)
; ---------
#if !USE_MINIMALIST_UOS
uos_push_text_in_fifo_tx_skip:
push_text_in_fifo_tx_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret
#endif

uos_push_text_in_fifo_tx:
push_text_in_fifo_tx:
	push		REG_Z_MSB
	push		REG_Z_LSB
	push		REG_TEMP_R16

push_text_in_fifo_tx_loop:
	lpm		REG_TEMP_R16, Z+
	cpi		REG_TEMP_R16, CHAR_NULL		; '\0' terminal ?
	breq		push_text_in_fifo_tx_end

	mov		REG_R3, REG_TEMP_R16
	rcall		uart_fifo_tx_write

	rjmp		push_text_in_fifo_tx_loop

push_text_in_fifo_tx_end:
	pop		REG_TEMP_R16
	pop		REG_Z_LSB
	pop		REG_Z_MSB
	ret
; ---------

; ---------
; Mise dans la FIFO/Tx d'un char
;
; Usage:
;      ldi		REG_TEMP_R16, <value>
;      rcall   push_1_char_in_fifo_tx
;
; Registres utilises
;    REG_TEMP_R16 -> Working register
; ---------
#if !USE_MINIMALIST_UOS
uos_push_1_char_in_fifo_tx_skip:
push_1_char_in_fifo_tx_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret
#endif

uos_push_1_char_in_fifo_tx:
push_1_char_in_fifo_tx:
	mov		REG_R3, REG_TEMP_R16
	rcall		uart_fifo_tx_write

	ret
; ---------

#if !USE_MINIMALIST_UOS
; ---------
; Mise dans la FIFO/Tx d'un texte lu de l'EEPROM et termine par '\0'
; => Si un 0xff est lu (EEPROM non initialisee), abandon de la lecture
; => Limitation a 8 caracteres lus pour eviter un bouclage ;-)
;
; Usage:
;      ldi		REG_TEMP_R18, 8
;      ldi		REG_X_MSB, <address MSB>
;      ldi		REG_X_LSB, <address LSB>
;      rcall   push_text_in_fifo_tx_from_eeprom
;
; ---------
push_text_in_fifo_tx_from_eeprom_skip:
	sbrc		REG_FLAGS_0, FLG_0_PRINT_SKIP_IDX		; Pas de trace si 'FLG_0_PRINT_SKIP' affirme
	ret
#endif

push_text_in_fifo_tx_from_eeprom:
push_text_in_fifo_tx_from_eeprom_loop:
	rcall		eeprom_read_byte

	cpi		REG_TEMP_R16, 0xff
	breq		push_text_in_fifo_tx_from_eeprom_end

	tst		REG_TEMP_R16
	breq		push_text_in_fifo_tx_from_eeprom_end

	rcall		push_1_char_in_fifo_tx

	adiw		REG_X_LSB, 1
	dec		REG_TEMP_R18
	brne		push_text_in_fifo_tx_from_eeprom_loop

push_text_in_fifo_tx_from_eeprom_end:
	ret
; ---------

	ret
; ---------

; ---------
; Emission asynchrone caractere par caractere de la FIFO/Tx
;
; Remarque: Methode a appeler en fond de tache permettant de vider et
;           emettre tous les caracteres de la FIFO/Tx jusqu'au dernier
;
; Usage:
;      rcall   fifo_tx_to_send_async
;
; Registres utilises
;    REG_TEMP_R16        -> Working register (non preserve)
; ---------
fifo_tx_to_send_async:
	; Caractere de la FIFO/Tx a emettre ?
	sbrs		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_IDX
	rjmp		fifo_tx_to_send_async_rtn

	sbrc		REG_FLAGS_0, FLG_0_UART_TX_TO_SEND_IDX		; Caractere emis ?
	rjmp		fifo_tx_to_send_async_rtn

	rcall		uart_fifo_tx_read					; Oui => Lecture du caractere suivant dans FIFO/Tx
	brtc		fifo_tx_to_send_async_end		; Caractere disponible ?

	; Test de l'etat Rx qui doit etre haut pour pouvoir etre emis
	sbis		PINB, IDX_BIT_RXD
	rjmp		fifo_tx_to_send_async_rtn

	mov		REG_TEMP_R16, REG_R4				; Oui => Emission de celui-ci
	rcall		uart_tx_send

	rjmp		fifo_tx_to_send_async_rtn		; Retour et attente que ce caractere soit emis...

fifo_tx_to_send_async_end:
	cbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK		; Non => Arret de la demande d'emission

fifo_tx_to_send_async_rtn:
	ret
; ---------

; ---------
; Emission synchrone caractere par caractere jusqu'a vidage de la FIFO/Tx
;
; Remarque: Methode a appeler apres un appel a 'push_1_char_in_fifo_tx'
;           => Emision de tous les caracteres de la FIFO/Tx jusqu'au dernier
;
; Permet un forcage emission pour eviter la saturation de la FIFO/Tx
; => En effet, la lecture de la FIFO/Tx et l'emission ne commence qu'au
;    retour en fond de tache (cf. 'rcall fifo_tx_to_send_async')
;
; Usage:
;      rcall   fifo_tx_to_send_sync
;
; Registres utilises
;    REG_TEMP_R16        -> Working register (non preserve)
; ---------
uos_fifo_tx_to_send_sync:
fifo_tx_to_send_sync:
	nop

fifo_tx_to_send_sync_retry:
	sbr		REG_FLAGS_1, FLG_1_UART_FIFO_TX_TO_SEND_MSK
	rcall		fifo_tx_to_send_async

	sbrc		REG_FLAGS_0, FLG_0_UART_TX_TO_SEND_IDX				; Caractere emis ?
	rjmp		fifo_tx_to_send_sync_retry								; Non => Retry

	sbrc		REG_FLAGS_1, FLG_1_UART_FIFO_TX_NOT_EMPTY_IDX	; FIFO/Tx vide ?
	rjmp		fifo_tx_to_send_sync_retry								; Non => Retry
	; Fin: Emission, attente FIFO/Tx vide et dernier caractere emis

fifo_tx_to_send_sync_rtn:
	ret
; ---------

; End of file

