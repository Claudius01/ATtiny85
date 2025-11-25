; "$Id: ATtiny85_uOS_Commands.h,v 1.1 2025/11/25 16:56:59 administrateur Exp $"

#define	CHAR_LF					0x0A		; Line Feed ('\n')
#define	CHAR_CR					0x0D		; Carriage Return ('\r')
#define	CHAR_NULL				0x00		; '\0'

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

.dseg
; Variables specifiques aux saisies de commandes a executer
G_TEST_FLAGS:					.byte		1
G_TEST_COMMAND_TYPE:			.byte		1
G_TEST_VALUE_MSB:				.byte		1
G_TEST_VALUE_LSB:				.byte		1
G_TEST_VALUE_MSB_MORE:		.byte		1
G_TEST_VALUE_LSB_MORE:		.byte		1

G_TEST_VALUE_DEC_MSB:		.byte		1
G_TEST_VALUE_DEC_LSB:		.byte		1

;G_TEST_FLAGS_2:				.byte		1

G_TEST_VALUES_IDX_WRK:		.byte		1				; Index sur les valeurs de 'G_TEST_VALUES_ZONE' (travail)
G_TEST_VALUES_IDX:			.byte		1				; Index sur les valeurs de 'G_TEST_VALUES_ZONE' (disponible)
G_TEST_VALUES_ZONE:			.byte		(2 * 32)		; Page de 32 mots

; End of file

