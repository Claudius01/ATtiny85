; "$Id: ATtiny85_uOS_Uart.h,v 1.1 2025/11/25 16:57:20 administrateur Exp $"

#if 0
; Gestion de l'UART
; -----------------
; - FLG_0_UART_DETECT_LINE_IDLE: Passage a 1 si ligne RXD a l'etat haut durant au moins 10 bits;
;   => Soit 40 acquisitions concecutives espacees de 13uS = 520uS correspondant a 10 bits a 9600 bauds
; - FLG_0_UART_DETECT_BIT_START: Si 'FLG_0_UART_DETECT_LINE_IDLE' a 1, passage a 1 sur detection du bit START
;   => Acquisition au moyen de la detection du front descendant sur RXD (cf. 'int0_isr')
;   => Conservation de 'FLG_0_UART_DETECT_LINE_IDLE' et de 'FLG_0_UART_DETECT_BIT_START' a 1 jusqu'a
;      la fin de l'acquisition d'un byte UART (1 start + 8 datas + 1 stop)
;      => Passage a 0 de 'FLG_0_UART_DETECT_BIT_START' pour relancer la detaction du bit START
; - FLG_0_UART_DETECT_BYTE: Passage a 1 pour indiquer donnee UART disponible jusqu'a sa lecture
;   pour traitement (ie. ecriture dans la FIFO/UART RX)
;
; => 1 - L'acquisition des donnees UART commence des que les 2 flags 'FLG_0_UART_DETECT_LINE_IDLE' et
;    'FLG_0_UART_DETECT_BIT_START' sont a 1
;
;    2 - A la fin de l'acquisition, le flag 'FLG_0_UART_DETECT_BIT_START' est remis a 0
;        pour une detection du bit START
;
;    => 'FLG_0_UART_DETECT_LINE_IDLE' est remis a 0 sur erreur de communication comme:
;       - Pas de bit START lu au 1st bit apres la detection --\__ (Frame Error)
;       - Pas de bit STOP lu au 10th bit (Frame Error)
;       - Donnee non attendue @ protocole
;       - A completer...
;
#define	FLG_0_UART_DETECT_LINE_IDLE_MSK		MSK_BIT1
#define	FLG_0_UART_DETECT_BIT_START_MSK		MSK_BIT2
#define	FLG_0_UART_RX_BYTE_RECEIVED_MSK		MSK_BIT3
#define	FLG_0_UART_TX_TO_SEND_MSK				MSK_BIT4		; Donnees Data/Tx a emettre
#define	FLG_0_PRINT_SKIP_MSK						MSK_BIT5		; Saut des methodes 'print_xxx' si affirme
#define	FLG_0_UART_RX_BYTE_START_ERROR_MSK	MSK_BIT6
#define	FLG_0_UART_RX_BYTE_STOP_ERROR_MSK	MSK_BIT7

#define	FLG_0_UART_DETECT_LINE_IDLE_IDX		IDX_BIT1
#define	FLG_0_UART_DETECT_BIT_START_IDX		IDX_BIT2
#define	FLG_0_UART_RX_BYTE_RECEIVED_IDX		IDX_BIT3
#define	FLG_0_UART_TX_TO_SEND_IDX				IDX_BIT4		; Donnees Data/Tx a emettre
#define	FLG_0_PRINT_SKIP_IDX						IDX_BIT5		; Saut des methodes 'print_xxx' si affirme
#define	FLG_0_UART_RX_BYTE_START_ERROR_IDX	IDX_BIT6
#define	FLG_0_UART_RX_BYTE_STOP_ERROR_IDX	IDX_BIT7

; Flags generaux FLG_1 (masques et index)
; Etats des FIFO/UART/Rx et Tx + Donnees Rx recues et Tx a emettre
#define	FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		MSK_BIT0
#define	FLG_1_UART_FIFO_RX_FULL_MSK			MSK_BIT1
#define	FLG_1_UART_RX_RECEIVE_MSK				MSK_BIT2		; Donnees Data/Rx recues
#endif

#define	SIZE_UART_FIFO_RX		(1 << 5)		; 32 bytes -> Puissance de 2 pour un modulo par masque avec (SIZE_UART_FIFO_RX -1)
#define	SIZE_UART_FIFO_TX		(1 << 6)		; 64 bytes -> Puissance de 2 pour un modulo par masque avec (SIZE_UART_FIFO_TX - 1)

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
G_BAUDS_VALUE:								.byte		1
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

; End of file

