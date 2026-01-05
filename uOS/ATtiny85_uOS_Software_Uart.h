; "$Id: ATtiny85_uOS_Software_Uart.h,v 1.2 2026/01/02 18:28:56 administrateur Exp $"

#if !USE_MINIMALIST_UOS
#define	SIZE_UART_FIFO_RX		(1 << 5)		; 32 bytes -> Puissance de 2 pour un modulo par masque avec (SIZE_UART_FIFO_RX -1)
#define	SIZE_UART_FIFO_TX		(1 << 6)		; 64 bytes -> Puissance de 2 pour un modulo par masque avec (SIZE_UART_FIFO_TX - 1)
#else
#define	SIZE_UART_FIFO_TX		(1 << 4)		; 16 bytes -> Puissance de 2 pour un modulo par masque avec (SIZE_UART_FIFO_TX - 1)
#endif

; Constantes pour les Bauds Rate:
; - DURATION_WAIT_READ_BIT_START: Lecture 26 uS * x apres le front descendant
;   - 9600 bauds: 1
;   - 4800 bauds: 2
;   ...
#define	DURATION_WAIT_READ_BIT_START			(1)
;#define	DURATION_WAIT_READ_BIT_START			(2)
;   
; - NBR_BAUDS_VALUE:
;   - 9600 bauds: 104 uS / 26 uS = 4 -> 3
;   - 4800 bauds: 208 uS / 26 uS = 8 -> 7
;   ...
#define	NBR_BAUDS_VALUE							(4 - 1)
;#define	NBR_BAUDS_VALUE							(7 - 1)

; - DURATION_DETECT_LINE_IDLE:
;   - 9600 bauds: (11 * 4 * 26) 			-> RXD a l'etat haut/bas pendant au moins 11 * 104 uS
;   - 4800 bauds: (11 * 4 * 26 * 2)		-> RXD a l'etat haut/bas pendant au moins 11 * 208 uS
;   ...
#define	DURATION_DETECT_LINE_IDLE				(11 * 4 * 26)
;#define	DURATION_DETECT_LINE_IDLE				(11 * 4 * 26 * 2)

.dseg
G_BAUDS_IDX:								.byte		1	; Index des valeurs de bauds dans 'const_for_bauds_rate'
G_BAUDS_VALUE:								.byte		1

#if !USE_MINIMALIST_UOS
G_DURATION_DETECT_LINE_IDLE_MSB:		.byte		1
G_DURATION_DETECT_LINE_IDLE_LSB:		.byte		1
G_DURATION_WAIT_READ_BIT_START:		.byte		1

G_UART_CPT_LINE_IDLE_LSB:	.byte		1		; Compteur de 16 bits pour la detection de la ligne IDLE
G_UART_CPT_LINE_IDLE_MSB:	.byte		1

G_UART_CPT_DURATION_1BIT_RX:	.byte		1	; Compteur pour l'attente avant nouvelle acquisition RXD
G_UART_CPT_DURATION_1BIT_TX:	.byte		1	; Compteur pour l'attente avant emission prochain bit TXD

G_UART_CPT_NBR_BITS_RX:			.byte		1	; Nommbre de bits pour l'acquisition RXD
G_UART_CPT_NBR_BITS_TX:		.byte		1	; Nommbre de bits pour l'emission TXD

G_UART_BYTE_RX_LSB:			.byte		1		; Mot LSB:MSB recu sur RXD (1 Start + 8 Datas + 1 ou 2 Stop)
G_UART_BYTE_RX_MSB:			.byte		1		; apres serialisation a droite: 1111 11sD DDDD DDDS ([S]tart/[s]top)

G_UART_BYTE_TX_LSB:			.byte		1		; Mot LSB:MSB a emettre sur TXD (1 Start + 8 Datas + 1 ou 2 Stop) avec une
G_UART_BYTE_TX_MSB:			.byte		1		; serialisation a droite via la Carry: 1111 11sD DDDD DDDS ([S]tart/[s]top)

; FIFO UART/Rx
G_UART_FIFO_RX_WRITE:		.byte		1
G_UART_FIFO_RX_READ:			.byte		1
G_UART_FIFO_RX_DATA:			.byte		(SIZE_UART_FIFO_RX - 1)		; 1st byte de la FIFO/Rx
G_UART_FIFO_RX_DATA_END:	.byte		1									; Last byte de la FIFO/Rx

; FIFO UART/Tx
G_UART_FIFO_TX_WRITE:		.byte		1
G_UART_FIFO_TX_READ:			.byte		1
G_UART_FIFO_TX_DATA:			.byte		(SIZE_UART_FIFO_TX - 1)		; 1st byte de la FIFO/Tx
G_UART_FIFO_TX_DATA_END:	.byte		1									; Last byte de la FIFO/Tx

#else
; Aucune variable @ UART/Rx
G_UART_CPT_DURATION_1BIT_TX:	.byte		1	; Compteur pour l'attente avant emission prochain bit TXD

G_UART_CPT_NBR_BITS_TX:		.byte		1	; Nommbre de bits pour l'emission TXD

G_UART_BYTE_TX_LSB:			.byte		1		; Mot LSB:MSB a emettre sur TXD (1 Start + 8 Datas + 1 ou 2 Stop) avec une
G_UART_BYTE_TX_MSB:			.byte		1		; serialisation a droite via la Carry: 1111 11sD DDDD DDDS ([S]tart/[s]top)

; FIFO UART/Tx
G_UART_FIFO_TX_WRITE:		.byte		1
G_UART_FIFO_TX_READ:			.byte		1
G_UART_FIFO_TX_DATA:			.byte		(SIZE_UART_FIFO_TX - 1)		; 1st byte de la FIFO/Tx
G_UART_FIFO_TX_DATA_END:	.byte		1									; Last byte de la FIFO/Tx
#endif

; End of file

