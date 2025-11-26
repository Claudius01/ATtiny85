; "$Id: ATtiny85_uOS+DS18B20.h,v 1.3 2025/11/26 17:54:18 administrateur Exp $"

#define	USE_DS18B20_TRACE					0

#define	IDX_BIT_1_WIRE					IDX_BIT2
#define	DS18B20_TIMER_1_SEC			3				; Timer pour les mesures des temperatures et les emissions de trames
#define	CHAR_TYPE_COMMAND_C_MAJ		'C'

; Definitions et Variables pour la gestion des DS18B20 (commande 'search ROM': DS18B20_CMD_SEARCH_ROM)
#define	FLG_DS18B20_CONV_T_MSK		MSK_BIT0
#define	FLG_DS18B20_TEMP_MSK			MSK_BIT1
#define	FLG_DS18B20_FRAMES_MSK		MSK_BIT7		; Trames en lieu et place des 'G_DS18B20_ALR_ROM_N'

#define	FLG_DS18B20_CONV_T_IDX		IDX_BIT0
#define	FLG_DS18B20_TEMP_IDX			IDX_BIT1
#define	FLG_DS18B20_FRAMES_IDX		IDX_BIT7		; Trames en lieu et place des 'G_DS18B20_ALR_ROM_N'

#define	DS18B20_CMD_READ_ROM					0x33	; Lecture du registre ROM de 64 bits
#define	DS18B20_CMD_MATCH_ROM				0x55	; Match du registre ROM de 64 bits
#define	DS18B20_CMD_CONVERT_T				0x44	; Conversion de la temperature
#define	DS18B20_CMD_COPY_SCRATCHPAD		0x48	; Recopie du Scratchpad dans l'EEPROM
#define	DS18B20_CMD_WRITE_SCRATCHPAD		0x4E	; Ecriture de la Scratchpad
#define	DS18B20_CMD_READ_POWER_SUPPLY		0xB4	; Lecture Power Mode
#define	DS18B20_CMD_RECALL_EEPROM			0xB8	; Recopie de l'EEPROM dans le Scratchpad
#define	DS18B20_CMD_READ_SCRATCHPAD		0xBE	; Lecture de la Scratchpad
#define	DS18B20_CMD_SKIP_ROM					0xCC	; Skip du registre ROM de 64 bits
#define	DS18B20_CMD_SEARCH_ALARM			0xEC	; Recherche du registre ROM sur le bus qui est en alarme
#define	DS18B20_CMD_SEARCH_ROM				0xF0	; Recherche du registre ROM sur le bus

#define	FLG_TEST_CONFIG_ERROR_MSK			MSK_BIT7

#define	EEPROM_ADDR_PRIMES					16

.dseg

G_DS18B20_FLAGS:				.byte		1

G_HEADER_NUM_FRAME_MSB:		.byte		1		; Numero de la trame emise par la platine (MSB)
G_HEADER_NUM_FRAME_LSB:		.byte		1		; et (LSB)
G_HEADER_TIMESTAMP_MSB:		.byte		1		; Timestamp en Sec. de l'emission de la trame complete (MSB)
G_HEADER_TIMESTAMP_MID:		.byte		1		; + (MID)
G_HEADER_TIMESTAMP_LSB:		.byte		1		; et (LSB)
G_HEADER_NBR_CAPTEURS:		.byte		1		; Nombre de capteurs
G_DS18B20_BYTES_SEND:		.byte		16				; Bytes a emettre sur le 1-Wire
G_DS18B20_BYTES_RESP:		.byte		16				; Bytes recus sur le 1-Wire
G_DS18B20_BYTES_ROM:			.byte		8				; ROM extrait de la recherche

G_BUS_1_WIRE_FLAGS:			.byte		1
G_DS1820_IN_ALARM:			.byte		1
G_DS1820_FAMILLE:				.byte		1
G_DS18B20_COUNTER:			.byte		1
G_DS18B20_COUNTER_INIT:		.byte		1

G_DS18B20_SPARES_0:			.byte		2

G_DS18B20_NBR_BITS_RETRY:		.byte		1			; Numero de la passe ((1 << n) - 1) <= au nbr de bits inconnus
G_DS18B20_PATTERN:				.byte		1			; Pattern a tester
G_DS18B20_NBR_BITS_0_1:			.byte		1			; Nbr de bits inconnus (retour de 0x00) a balayer)
G_DS18B20_NBR_BITS_0_1_MAX: 	.byte		1			; Nbr de bits inconnus maximal (pour verification @ pattern a tester
G_DS18B20_NBR_ROM:				.byte		1			; Nbr de ROM trouve
G_DS18B20_NBR_ROM_MAX:			.byte		1			; Nbr de ROM maximal supporte (lu depuis l'EEPROM)
G_DS18B20_ROM_IDX_WRK:			.byte		1			; Index dans la table des ROM a rechercher / trouve
G_DS18B20_ROM_IDX:				.byte		1			; Index du ROM "matche" dans la plage [0, 1, 2, etc.]

; Reservation pour 8 capteurs
G_DS18B20_ROM_0:					.byte		8			; 1st ROM
G_DS18B20_ROM_1:					.byte		8			; 2nd ROM
G_DS18B20_ROM_2:					.byte		8			; 3rd ROM
G_DS18B20_ROM_3:					.byte		8			; 4th ROM
G_DS18B20_ROM_4:					.byte		8			; 5th ROM
G_DS18B20_ROM_5:					.byte		8			; 6th ROM
G_DS18B20_ROM_6:					.byte		8			; 7th ROM
G_DS18B20_ROM_7:					.byte		8			; 8th ROM

G_DS18B20_SPARES_2:				.byte		8

; Position des donnees '<NAME>' dans 'G_DS18B20_BYTES_RESP' a recopier @ FRAME_IDX_<NAME>
; ie. "0xB9 10 7F FF 7F C9 16 01  36"
;              Resol    Tl Th Tch Tcl
;
#define	RESP_IDX_TC_LSB			8
#define	RESP_IDX_TC_MSB			7
#define	RESP_IDX_TL					5
#define	RESP_IDX_TH					6
#define	RESP_IDX_RESOL_CONV 		2

; Definitions des positions dans la trame
#define	FRAME_IDX_TYPE_PLATINE		15		; Type de la platine lu de l'EEPROM
#define	FRAME_IDX_INDEX_PLATINE		14		; Index de la platine lu de l'EEPROM
#define	FRAME_IDX_NUM_FRAME_MSB		13		; Numero de la trame emise par cette platine (MSB)
#define	FRAME_IDX_NUM_FRAME_LSB		12		; et (LSB)
#define	FRAME_IDX_TIMESTAMP_MSB		11		; Timestamp en Sec. de l'emission de la trame complete (MSB)
#define	FRAME_IDX_TIMESTAMP_MID		10		; et (LSB)
#define	FRAME_IDX_TIMESTAMP_LSB		9		; et (LSB)
#define	FRAME_IDX_NBR_CAPTEURS		8		; Nombre de capteurs

#define	FRAME_IDX_IDX					7		; Index du capteur de temperature (1 byte)
#define	FRAME_IDX_FAMILLE				6		; Famille du capteur (1 byte)
#define	FRAME_IDX_TC_MSB   			5		; Temperature courante Tc (2 bytes)
#define	FRAME_IDX_TC_LSB				4
#define	FRAME_IDX_TH					3		; Temperature de seuil Th (1 byte)
#define	FRAME_IDX_TL					2		; Temperature de seuil Tl (1 byte)
#define	FRAME_IDX_ALR_RES_CONV		1		; Alarme + Resolution de la conversion analogique (1 byte)
#define	FRAME_IDX_CRC8					0		; CRC8 des 7 bytes precedents (1 byte)

#define	FRAME_LENGTH_CAPTEUR			(FRAME_IDX_IDX + 1)		; Longueur d'une trame capteur
; Fin: Definitions des positions dans la trame

; Variables pour la gestion des DS18B20 (commande 'alarm search' DS18B20_CMD_SEARCH_ALARM)
; => Memes principes que pour la commande DS18B20_CMD_SEARCH_ROM
G_DS18B20_ALR_NBR_BITS_RETRY:		.byte		1		; Numero de la passe ((1 << n) - 1) <= au nbr de bits inconnus
G_DS18B20_ALR_PATTERN:				.byte		1		; Pattern a tester
G_DS18B20_ALR_NBR_BITS_0_1:		.byte		1		; Nombre de bits inconnus (retour de 0x00) a balayer)
G_DS18B20_ALR_NBR_BITS_0_1_MAX:	.byte		1		; Nombre de bits inconnus maximal (pour verification @ pattern a tester
G_DS18B20_ALR_NBR_ROM:				.byte		1		; Nombre de ROM trouve
G_DS18B20_ALR_NBR_ROM_MAX:			.byte		1		; Nombre de ROM maximal supporte (lu depuis l'EEPROM)
G_DS18B20_ALR_ROM_IDX_WRK:			.byte		1		; Index dans la table des ROM a rechercher / trouve
G_DS18B20_ALR_SPARES_3:				.byte		1

; Reservation pour 8 capteurs
G_DS18B20_ALR_ROM_0:					.byte		8		; 1st ROM
G_DS18B20_ALR_ROM_1:					.byte		8		; 2nd ROM
G_DS18B20_ALR_ROM_2:					.byte		8		; 3rd ROM
G_DS18B20_ALR_ROM_3:					.byte		8		; 4th ROM
G_DS18B20_ALR_ROM_4:					.byte		8		; 5th ROM
G_DS18B20_ALR_ROM_5:					.byte		8		; 6th ROM
G_DS18B20_ALR_ROM_6:					.byte		8		; 7th ROM
G_DS18B20_ALR_ROM_7:					.byte		8		; 8th ROM

; Reservation pour le header
G_DS18B20_FRAME_HEADER:				.byte		6

G_DS18B20_ALR_SPARES_4:				.byte		2

; Reservation de 1 byte pour accueillir le CRC8 de l'ensemble de la trame
; Warning: 7 bytes seront concatenes a la trame:
;          - Index et type de la platine (2 bytes)
;          - Numero de la trame emise par cette platine (2 bytes)
;          - Timestamp en Sec. de l'emission de la trame complete (3 bytes)
;          - Nombre de capteurs (1 byte)
;
#define	G_FRAME_ALL_INFOS			G_DS18B20_ALR_ROM_0

#define	G_DS18B20_FRAME_0			(G_DS18B20_ALR_ROM_0 + 1)
#define	G_DS18B20_FRAME_1			(G_DS18B20_ALR_ROM_1 + 1)
#define	G_DS18B20_FRAME_2			(G_DS18B20_ALR_ROM_2 + 1)
#define	G_DS18B20_FRAME_3			(G_DS18B20_ALR_ROM_3 + 1)
#define	G_DS18B20_FRAME_4			(G_DS18B20_ALR_ROM_4 + 1)
#define	G_DS18B20_FRAME_5			(G_DS18B20_ALR_ROM_5 + 1)
#define	G_DS18B20_FRAME_6			(G_DS18B20_ALR_ROM_6 + 1)
#define	G_DS18B20_FRAME_7			(G_DS18B20_ALR_ROM_7 + 1)

; End of file

