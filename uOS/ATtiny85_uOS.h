; "$Id: ATtiny85_uOS.h,v 1.10 2025/12/12 15:41:46 administrateur Exp $"

; Registres de travail (dedies)
;
.def		REG_R0				= r0
.def		REG_R1				= r1
.def		REG_R2				= r2
.def		REG_R3				= r3
.def		REG_R4				= r4
.def		REG_R4				= r4
.def		REG_R5				= r5		; Registre dedie a 'uos_delay_1uS'
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

; Definitions pour ajout comportemental:
#define	FLG_BEHAVIOR_MARK_IN_TIM1_COMPA_IDX		IDX_BIT0	; Pulse --\__/--... en entree/sortie de l'It 'tim1_compa_isr'
#define	FLG_BEHAVIOR_MARK_IN_PCINT0_IDX			IDX_BIT1	; Pulse --\__/--... en entree/sortie de l'It 'pcint0_isr'
#define	FLG_BEHAVIOR_MARK_IN_RX_REC_BIT_IDX		IDX_BIT2	; Pulse --\__/--... en entree/sortie de 'tim1_compa_isr_rx_rec_bit'

#define	FLG_BEHAVIOR_ADDON_FOUND_IDX				IDX_BIT4	; Programme ADDON trouve (prolongations traitements)
#define	FLG_BEHAVIOR_ADDON_FOUND_MSK				MSK_BIT4

#define	CPT_CALIBRATION								2
#define	FLG_BEHAVIOR_CALIBRATION_1_uS				IDX_BIT7

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
; Flags generaux REG_FLAGS_0 (masques et index) defini dans la registre r24
#define	FLG_0_PERIODE_1MS_MSK					MSK_BIT0
#define	FLG_0_UART_DETECT_LINE_IDLE_MSK		MSK_BIT1
#define	FLG_0_UART_DETECT_BIT_START_MSK		MSK_BIT2
#define	FLG_0_UART_RX_BYTE_RECEIVED_MSK		MSK_BIT3
#define	FLG_0_UART_TX_TO_SEND_MSK				MSK_BIT4		; Donnees Data/Tx a emettre
#define	FLG_0_PRINT_SKIP_MSK						MSK_BIT5		; Saut des methodes 'print_xxx' si affirme
#define	FLG_0_UART_RX_BYTE_START_ERROR_MSK	MSK_BIT6
#define	FLG_0_UART_RX_BYTE_STOP_ERROR_MSK	MSK_BIT7

#define	FLG_0_PERIODE_1MS_IDX					IDX_BIT0
#define	FLG_0_UART_DETECT_LINE_IDLE_IDX		IDX_BIT1
#define	FLG_0_UART_DETECT_BIT_START_IDX		IDX_BIT2
#define	FLG_0_UART_RX_BYTE_RECEIVED_IDX		IDX_BIT3
#define	FLG_0_UART_TX_TO_SEND_IDX				IDX_BIT4		; Donnees Data/Tx a emettre
#define	FLG_0_PRINT_SKIP_IDX						IDX_BIT5		; Saut des methodes 'print_xxx' si affirme
#define	FLG_0_UART_RX_BYTE_START_ERROR_IDX	IDX_BIT6
#define	FLG_0_UART_RX_BYTE_STOP_ERROR_IDX	IDX_BIT7

; Flags generaux REG_FLAGS_1 (masques et index) defini dans la registre r25
; Etats des FIFO/UART/Rx et Tx + Donnees Rx recues et Tx a emettre
#define	FLG_1_UART_FIFO_RX_NOT_EMPTY_MSK		MSK_BIT0
#define	FLG_1_UART_FIFO_RX_FULL_MSK			MSK_BIT1
#define	FLG_1_UART_RX_RECEIVE_MSK				MSK_BIT2		; Donnees Data/Rx recues
#define	FLG_1_CONNECTED_MSK						MSK_BIT3
#define	FLG_1_UART_FIFO_TX_NOT_EMPTY_MSK		MSK_BIT4
#define	FLG_1_UART_FIFO_TX_FULL_MSK			MSK_BIT5
#define	FLG_1_UART_FIFO_TX_TO_SEND_MSK		MSK_BIT6
#define	FLG_1_LED_RED_ON_MSK						MSK_BIT7

#define	FLG_1_UART_FIFO_RX_NOT_EMPTY_IDX		IDX_BIT0
#define	FLG_1_UART_FIFO_RX_FULL_IDX			IDX_BIT1
#define	FLG_1_UART_RX_RECEIVE_IDX				IDX_BIT2		; Donnees Data/Rx recues
#define	FLG_1_CONNECTED_IDX						IDX_BIT3	
#define	FLG_1_UART_FIFO_TX_NOT_EMPTY_IDX		IDX_BIT4
#define	FLG_1_UART_FIFO_TX_FULL_IDX			IDX_BIT5
#define	FLG_1_UART_FIFO_TX_TO_SEND_IDX		IDX_BIT6
#define	FLG_1_LED_RED_ON_IDX						IDX_BIT7

#define EXTENSION_SETUP					0
#define EXTENSION_BACKGROUND			1
#define EXTENSION_1_MS					2
#define EXTENSION_COMMANDS				3
#define EXTENSION_BUTTON				4

; 1st adresse de la SRAM [0x60...0xFF]
.dseg
G_BEHAVIOR:						.byte		1		; Pilotage du comportement (pas d'ajout de comportement si egal a 0)
G_CALIBRATION:					.byte		1

G_TICK_1MS:						.byte		1		; Compatbilisation des 1mS
G_TICK_1MS_INIT:				.byte		1

; Fin: Definitions pour ajout comportemental

G_CHENILLARD_MSB:				.byte		1		; Chenillard d'allumage/extinction Led GREEN
G_CHENILLARD_LSB:				.byte		1		; au travers d'un mot de 16 bits (16 x 125mS = 2 Sec)

G_NBR_VALUE_TRACE:			.byte		1
G_NBR_ERRORS:					.byte		1

; End of file

