; "$Id: ATtiny85_uOS.h,v 1.1 2025/11/24 15:59:13 administrateur Exp $"

#define	USE_PROGRAM_ADDON				0

#define	EEPROM_ADDR_VERSION	0
#define	EEPROM_ADDR_TYPE		8
#define	EEPROM_ADDR_ID			9

#define	CHAR_LF					0x0A		; Line Feed ('\n')
#define	CHAR_CR					0x0D		; Carriage Return ('\r')
#define	CHAR_NULL				0x00		; '\0'
#define	CHAR_SEPARATOR			0xFFFF	; Separateur section datas (0xffff opcode invalide ;-)

#define	CHAR_COMMAND_REC		'<'
#define	CHAR_COMMAND_SEND		'>'
#define	CHAR_COMMAND_MORE		'-'
#define	CHAR_COMMAND_PLUS		'+'
#define	CHAR_COMMAND_UNKNOWN	'?'

#define	CHAR_TYPE_COMMAND_A_MIN		'a'	; Calcul du CRC8-MAXIM du programme		: "<a"
#define	CHAR_TYPE_COMMAND_B_MAJ		'B'	; Set the Bauds rate (300, ..., 19200) : "B0|1|2|3|4|5|6"
#define	CHAR_TYPE_COMMAND_E_READ	'e'	; Dump de l'EEPROM                     : "<eHHHH..."
#define	CHAR_TYPE_COMMAND_F_MIN		'f'	; Lecture de la signature et des fuses : "<f"
#define	CHAR_TYPE_COMMAND_E_WRITE	'E'	; Ecriture d'un byte dans l'EEPROM     : "<EHHHH..."
#define	CHAR_TYPE_COMMAND_P_READ	'p'	; Dump du Programme                    : "<pHHHH..."
#define	CHAR_TYPE_COMMAND_S_READ	's'	; Dump de la SRAM                      : "<sHHHH..."
#define	CHAR_TYPE_COMMAND_S_WRITE	'S'	; Ecriture d'un byte dans la SRAM      : "<SHHHH..."
#define	CHAR_TYPE_COMMAND_X			'x'	; Execution d'un programme de test     : "<xHHHH"

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
; Fin: Constantes pour les Bauds Rate:

; Definition des masques de bits [0x00, 0x01, ..., 0xff] pour les opcodes suivants:
; - ori  -> Logical OR with Immediate
; - andi -> Logical AND with Immediate (Faire le complement a 1 ou (0xFF - MSK_BITX))
; - cbr  -> Clear Bits in Register (= andif avec constante complementee a (0xFF - K))
; - sbr  -> Set Bits in Register (= ori)
;
#define	MSK_BIT7				(1 << 7)
#define	MSK_BIT6				(1 << 6)
#define	MSK_BIT5				(1 << 5)
#define	MSK_BIT4				(1 << 4)
#define	MSK_BIT3				(1 << 3)
#define	MSK_BIT2				(1 << 2)
#define	MSK_BIT1				(1 << 1)
#define	MSK_BIT0				(1 << 0)

; Definition des index de bits [0, 1, ..., 7] pour les opcodes suivants:
; - bld       -> Bit Load from the T Flag in SREG to a Bit in Register
; - bst       -> Bit Store from Bit in Register to T Flag in SREG
; - cbi/sbi   -> Clear Bit in I/O Register / Set Bit in I/O Register
; - sbic/sbis -> Skip if Bit in I/O Register is Cleared / Skip if Bit in I/O Register is Set
; - sbrc/sbrs -> Skip if Bit in Register is Cleared / Skip if Bit in Register is Set
; - bclr/bset -> Bit Clear / Bit Set in SREG
; - brbc/brbs -> Branch if Bit in SREG is Cleared / Set
;
#define	IDX_BIT7				7
#define	IDX_BIT6				6
#define	IDX_BIT5				5
#define	IDX_BIT4				4
#define	IDX_BIT3				3
#define	IDX_BIT2				2
#define	IDX_BIT1				1
#define	IDX_BIT0				0

; Attribution des 'NBR_TIMER' timers #0, #1, ..., #15
; => Le traitement associe a chaque timer est effectue dans l'ordre de son index
#define	NBR_TIMER							16

#define	TIMER_CONNECT						10
#define	TIMER_ERROR							11
#define	TIMER_APPUI_BOUTON_LED			12
#define	TIMER_APPUI_BOUTON_DETECT		13
#define	TIMER_RXD_ANTI_REBONDS			14
#define	TIMER_LED_GREEN					15

#define	PERIODE_1MS							(1000 / 26)		; Cadencement par TMR0 de 26 uS ;-)

; Flags generaux FLG_0 (masques et index)
#define	FLG_0_PERIODE_1MS_MSK				MSK_BIT0
#define	FLG_0_PERIODE_1MS_IDX				IDX_BIT0

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
#define	FLG_1_EXEC_DERIVATION_MSK				MSK_BIT3		; Execution du code de derivation dans les "addons"
#define	FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		MSK_BIT4
#define	FLG_1_UART_FIFO_TX_FULL_MSK			MSK_BIT5
#define	FLG_1_UART_FIFO_TX_TO_SEND_MSK		MSK_BIT6
#define	FLG_1_LED_RED_ON_MSK						MSK_BIT7

#define	FLG_1_UART_FIFO_RX_NOT_EMPTY_IDX		IDX_BIT0
#define	FLG_1_UART_FIFO_RX_FULL_IDX			IDX_BIT1
#define	FLG_1_UART_RX_RECEIVE_IDX				IDX_BIT2		; Donnees Data/Rx recues
#define	FLG_1_EXEC_DERIVATION_IDX				IDX_BIT3		; Execution du code de derivation dans les "addons"
#define	FLG_1_UART_FIFO_TX_NOT_EMPTY_IDX		IDX_BIT4
#define	FLG_1_UART_FIFO_TX_FULL_IDX			IDX_BIT5
#define	FLG_1_UART_FIFO_TX_TO_SEND_IDX		IDX_BIT6
#define	FLG_1_LED_RED_ON_IDX						IDX_BIT7

; Flags generaux G_FLAGS_2 (masques et index)
#define	FLG_2_CONNECTED_MSK						MSK_BIT0		; Passage en mode connecte sur reception d'une donnee Rx
#define	FLG_2_SPARE_1_MSK							MSK_BIT1
#define	FLG_2_SPARE_2_MSK							MSK_BIT2
#define	FLG_2_SPARE_3_MSK							MSK_BIT3
#define	FLG_2_SPARE_4_MSK							MSK_BIT4
#define	FLG_2_SPARE_5_MSK							MSK_BIT5
#define	FLG_2_EXEC_DERIVATION_MSK				MSK_BIT6		; Execution du code de derivation dans les "addons"
#define	FLG_2_ENABLE_DERIVATION_MSK			MSK_BIT7		; Autorisation d'ecriture dans le programme

#define	FLG_2_CONNECTED_IDX						IDX_BIT0		; Passage en mode connecte sur reception d'une donnee Rx
#define	FLG_2_SPARE_1_IDX							IDX_BIT1
#define	FLG_2_SPARE_2_IDX							IDX_BIT2
#define	FLG_2_SPARE_3_IDX							IDX_BIT3
#define	FLG_2_SPARE_4_IDX							IDX_BIT4
#define	FLG_2_SPARE_5_IDX							IDX_BIT5
#define	FLG_2_EXEC_DERIVATION_IDX				IDX_BIT6		; Execution du code de derivation dans les "addons"
#define	FLG_2_ENABLE_DERIVATION_IDX			IDX_BIT7		; Autorisation d'ecriture dans le programme

; Registres de travail (dedies)
;
.def		REG_R0				= r0
.def		REG_R1				= r1
.def		REG_R2				= r2
.def		REG_R3				= r3
.def		REG_R4				= r4

.def		REG_R6				= r6
.def		REG_R7				= r7
.def		REG_R8				= r8
.def		REG_R9				= r9
.def		REG_R10				= r10
.def		REG_R11				= r11

.def		REG_R12				= r12
.def		REG_R13				= r13
.def		REG_R14				= r14

.def		REG_SAVE_SREG		= r15		; Sauvegarde temporaire de SREG dans les methodes ISR

; Fin: Registres de travail (dedies)

; Registres de travail temporaires (dedies et banalises)
.def		REG_TEMP_R16		= r16
.def		REG_TEMP_R17		= r17
.def		REG_TEMP_R18		= r18
.def		REG_TEMP_R19		= r19
.def		REG_TEMP_R20		= r20
.def		REG_TEMP_R21		= r21		; Warning: Utilise dans 'tim1_compa_isr' (Cf. TODO: @ Dysfonctionnement...)
.def		REG_TEMP_R22		= r22		; Warning: Utilise dans 'tim1_compa_isr' (Cf. TODO: @ Dysfonctionnement...)

.def		REG_PORTB_OUT		= r23		; Dedie a l'image du PORTB en sortie (Leds, Pulse, TXD, etc.)
.def		REG_FLAGS_0			= r24		; Flags #0
.def		REG_FLAGS_1			= r25		; Flags #1

.def		REG_X_LSB			= r26		; XL
.def		REG_X_MSB			= r27		; XH
.def		REG_Y_LSB			= r28		; YL
.def		REG_Y_MSB			= r29		; YH
.def		REG_Z_LSB			= r30		; ZL
.def		REG_Z_MSB			= r31		; ZH
; Fin: Registres de travail temporaires (dedies et banalises)

; Zone de travail en SRAM de 'uOS'

; Debut de la partie [0x60...0xFF] de la SRAM (possibilite d'optimisation des indexations par X, Y et Z )
.dseg
G_TICK_1MS:						.byte		1		; Compatbilisation des 1mS
G_TICK_1MS_INIT:				.byte		1

; Definitions pour ajout comportemental:
#define	FLG_BEHAVIOR_MARK_IN_TIM1_COMPA_IDX		IDX_BIT0	; Pulse --\__/--... en entree/sortie de l'It 'tim1_compa_isr'
#define	FLG_BEHAVIOR_MARK_IN_PCINT0_IDX			IDX_BIT1	; Pulse --\__/--... en entree/sortie de l'It 'pcint0_isr'
#define	FLG_BEHAVIOR_MARK_IN_RX_REC_BIT_IDX		IDX_BIT2	; Pulse --\__/--... en entree/sortie de 'tim1_compa_isr_rx_rec_bit'

G_BAUDS_VALUE:								.byte		1
G_DURATION_DETECT_LINE_IDLE_MSB:		.byte		1
G_DURATION_DETECT_LINE_IDLE_LSB:		.byte		1
G_DURATION_WAIT_READ_BIT_START:		.byte		1

G_BEHAVIOR:						.byte		1				; Pilotage du comportement (pas d'ajout de comportement si egal a 0)
; Fin: Definitions pour ajout comportemental

G_CHENILLARD_MSB:				.byte		1		; Chenillard d'allumage/extinction Led GREEN
G_CHENILLARD_LSB:				.byte		1		; au travers d'un mot de 16 bits (16 x 125mS = 2 Sec)

; Valeurs sur 16 bits des 'NBR_TIMER' accedees par indexation @ G_TIMER_0_LSB:G_TIMER_0_MSB
G_TIMER_0:						.byte		2
G_TIMER_SPACE:					.byte		2 * (NBR_TIMER - 1)
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

G_NBR_VALUE_TRACE:			.byte		1
G_NBR_ERRORS:					.byte		1

; FIFO UART/Rx
#define	SIZE_UART_FIFO_RX			32			; Puissance de 2 pour un modulo (SIZE_UART_FIFO_RX -1)

G_UART_FIFO_RX_WRITE:		.byte		1
G_UART_FIFO_RX_READ:			.byte		1
G_UART_FIFO_RX_DATA:			.byte		(SIZE_UART_FIFO_RX - 1)		; 1st byte de la FIFO/Rx
G_UART_FIFO_RX_DATA_END:	.byte		1									; Last byte de la FIFO/Rx

; FIFO UART/Tx
#define	SIZE_UART_FIFO_TX			64			; Puissance de 2 pour un modulo (SIZE_UART_FIFO_TX - 1)

G_UART_FIFO_TX_WRITE:		.byte		1
G_UART_FIFO_TX_READ:			.byte		1
G_UART_FIFO_TX_DATA:			.byte		(SIZE_UART_FIFO_TX - 1)		; 1st byte de la FIFO/Tx
G_UART_FIFO_TX_DATA_END:	.byte		1									; Last byte de la FIFO/Tx

G_HEADER_TYPE_PLATINE:		.byte		1		; Type de la platine lu de l'EEPROM
G_HEADER_INDEX_PLATINE:		.byte		1		; Index de la platine lu de l'EEPROM
G_HEADER_NUM_FRAME_MSB:		.byte		1		; Numero de la trame emise par la platine (MSB)

G_FLAGS_2:						.byte		1

; Flags propres aux tests (masques et index)
#define	FLG_TEST_COMMAND_TYPE_MSK				MSK_BIT0
#define	FLG_TEST_COMMAND_IN_PROGRESS_MSK		MSK_BIT1
#define	FLG_TEST_COMMAND_MORE_MSK				MSK_BIT2
#define	FLG_TEST_COMMAND_PLUS_MSK				MSK_BIT3
#define	FLG_TEST_COMMAND_ERROR_MSK				MSK_BIT4
#define	FLG_TEST_SPARE_1_MSK						MSK_BIT5
#define	FLG_TEST_EEPROM_ERROR_MSK				MSK_BIT6
#define	FLG_TEST_SPARE_2_MSK						MSK_BIT7

#define	FLG_TEST_COMMAND_TYPE_IDX				IDX_BIT0
#define	FLG_TEST_COMMAND_IN_PROGRESS_IDX		IDX_BIT1
#define	FLG_TEST_COMMAND_MORE_IDX				IDX_BIT2
#define	FLG_TEST_COMMAND_PLUS_IDX				IDX_BIT3
#define	FLG_TEST_COMMAND_ERROR_IDX				IDX_BIT4
#define	FLG_TEST_SPARE_1_IDX						IDX_BIT5
#define	FLG_TEST_EEPROM_ERROR_IDX				IDX_BIT6
#define	FLG_TEST_SPARE_2_IDX						IDX_BIT7

; Variables specifiques aux saisies de commandes a executer
G_TEST_FLAGS:					.byte		1
G_TEST_COMMAND_TYPE:			.byte		1
G_TEST_VALUE_MSB:				.byte		1
G_TEST_VALUE_LSB:				.byte		1
G_TEST_VALUE_MSB_MORE:		.byte		1
G_TEST_VALUE_LSB_MORE:		.byte		1

G_TEST_VALUE_DEC_MSB:		.byte		1
G_TEST_VALUE_DEC_LSB:		.byte		1

G_TEST_FLAGS_2:				.byte		1

G_TEST_VALUES_IDX_WRK:		.byte		1				; Index sur les valeurs de 'G_TEST_VALUES_ZONE' (travail)
G_TEST_VALUES_IDX:			.byte		1				; Index sur les valeurs de 'G_TEST_VALUES_ZONE' (disponible)
G_TEST_VALUES_ZONE:			.byte		(2 * 32)		; Page de 32 mots

; Definitions pour le calcul du crc8-maxim
#define	CRC8_POLYNOMIAL				0x8C			; Masque pour le calcul du CR8-MAXIM

G_CALC_CRC8:					.byte		1				; Calcul du crc8-maxim cumulee byte par byte
; Fin: Definitions pour le calcul du crc8-maxim

; Fin: Zone de travail en SRAM de 'uOS'

G_SRAM_END_OF_USE:					.byte		1

; Fin: Zones de travail en SRAM

; Definitions pour le pilotage avec ori/and/cbr/sbr
; - PORTB<4>: Led RED								0/1: Eteinte/Allumee
; - PORTB<3>: Led GREEN								0/1: Eteinte/Allumee
; - PORTB<2>: Led YELLOW							0/1: Eteinte/Allumee
;             et I/O 1-Wire
; - PORTB<1>: Led RED Interne au DigiSpark	0/1: Allumee/Eteinte
;             et Uart/TXD -> Platine/TXD

#define	MSK_BIT_LED_RED			MSK_BIT4
#define	MSK_BIT_LED_GREEN			MSK_BIT3
#define	MSK_BIT_LED_YELLOW		MSK_BIT2
#define	MSK_BIT_LED_RED_INT		MSK_BIT1

#define	MSK_BIT_TXD					MSK_BIT1		; Emission sur RXD du FT232R (Meme sortie que la Led RED Interne)
#define	MSK_BIT_PULSE_IT			MSK_BIT4		; Remarque: Meme sortie que la Led RED Externe

#define	IDX_BIT_LED_RED			IDX_BIT4
#define	IDX_BIT_LED_GREEN			IDX_BIT3

; Test du boutton par 'sbis/sbic'
#define	BUTTON_TEST_BIT			IDX_BIT0

; Definition de la pin PINB<0> (INT0) dediee a RXD
#define	IDX_BIT_RXD					IDX_BIT0
#define	MSK_BIT_RXD					MSK_BIT0

; --------
; Macros de pilotage du PORTB en sortie
.macro setLedRedOff			; 0/1: On/Off
	cbr		REG_FLAGS_1, FLG_1_LED_RED_ON_MSK	; Led RED Externe eteinte (Pulse --\_/--- possible)
	sbr		REG_PORTB_OUT, MSK_BIT_LED_RED	
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setLedRedOn			; 0/1: On/Off
	sbr		REG_FLAGS_1, FLG_1_LED_RED_ON_MSK	; Led RED Externe allumee (Pulse --\_/--- inhibee)
	cbr		REG_PORTB_OUT, MSK_BIT_LED_RED
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setLedYellowOff		; 0/1: On/Off
	sbr		REG_PORTB_OUT, MSK_BIT_LED_YELLOW	
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setLedYellowOn		; 0/1: On/Off
	cbr		REG_PORTB_OUT, MSK_BIT_LED_YELLOW
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setLedGreenOff		; 0/1: On/Off
	sbr		REG_PORTB_OUT, MSK_BIT_LED_GREEN
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setLedGreenOn			; 0/1: On/Off
	cbr		REG_PORTB_OUT, MSK_BIT_LED_GREEN	
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setLedRedIntOn		; 0/1: Off/On
	sbr		REG_PORTB_OUT, MSK_BIT_LED_RED_INT
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setLedRedIntOff		; 0/1: Off/On
	cbr		REG_PORTB_OUT, MSK_BIT_LED_RED_INT
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setPulseItUp			; Sortie au niveau haut de la pulse It
	sbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setPulseItDown		; Sortie au niveau bas de la pulse It
	cbr		REG_PORTB_OUT, MSK_BIT_PULSE_IT
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setTxdLow				; 0: Low
	cbr		REG_PORTB_OUT, MSK_BIT_TXD
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm

.macro setTxdHigh				; 1: High
	sbr		REG_PORTB_OUT, MSK_BIT_TXD
	out		PORTB, REG_PORTB_OUT					; Raffraichissement du PORTB
.endm
; Fin: Macros de pilotage du PORTB en sortie

; End of file
