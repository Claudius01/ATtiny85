; "$Id: ATtiny85_uOS+DS18B20.h,v 1.21 2026/01/05 13:52:45 administrateur Exp $"

#define	USE_DS18B20_TRACE				0

; Support de 4 capteurs ('DS18B20_NBR_ROM_TO_DETECT' inferieur ou egal a 'DS18B20_NBR_ROM_GESTION')
#if !USE_MINIMALIST_ADDONS
#define	DS18B20_NBR_ROM_TO_DETECT	4
#else
#define	DS18B20_NBR_ROM_TO_DETECT	2
#endif

#define	DS18B20_NBR_ROM_GESTION		8		; Gestion interne des ROM a concurence de 8 max (NE PAS MODIFIER)

#define	IDX_BIT_1_WIRE					IDX_BIT2
#define	NBR_BITS_TO_SHIFT				8

; Remarque: 8 timers minimum definis dans uOS (cf. 'ATtiny85_uOS_Timers.h')
#define	DS18B20_TIMER_1_SEC			(NBR_TIMER - 1)	; Timer pour les mesures des temperatures et les emissions de trames

#if !USE_MINIMALIST_ADDONS
#define	CHAR_TYPE_COMMAND_C_MAJ		'C'
#define	CHAR_TYPE_COMMAND_T_MAJ		'T'
#endif

; Definitions et Variables pour la gestion des DS18B20
#define	FLG_DS18B20_CONV_T_MSK		MSK_BIT0
#define	FLG_DS18B20_TEMP_MSK			MSK_BIT1
#define	FLG_DS18B20_FRAMES_MSK		MSK_BIT2		; Trames en lieu et place des 'G_DS18B20_ALR_ROM_N'
#define	FLG_DS18B20_TRACE_MSK		MSK_BIT3		; Trace Enable (1) /Disable (0) (0 by default)
#define	FLG_TEST_CONFIG_ERROR_MSK	MSK_BIT7

#define	FLG_DS18B20_CONV_T_IDX		IDX_BIT0
#define	FLG_DS18B20_TEMP_IDX			IDX_BIT1
#define	FLG_DS18B20_FRAMES_IDX		IDX_BIT2		; Trames en lieu et place des 'G_DS18B20_ALR_ROM_N'
#define	FLG_DS18B20_TRACE_IDX		IDX_BIT3		; Trace Enable (1) /Disable (0) (0 by default)
#define	FLG_TEST_CONFIG_ERROR_IDX	IDX_BIT7

#define	EEPROM_ADDR_NBR_DS18B20_TO_DETECT			15
#define	EEPROM_ADDR_PRIMES								16

#define	MSK_BIT_ALARM_SEARCH					MSK_BIT7		; 1 si alarme recherchee ET trouvee
#define	MSK_BIT_ALARM_FOUND					MSK_BIT6		; 1 si Tc >= Th ou Tc <= Tl si 'MSK_BIT_ALARM_SEARCH' affirme
#define	MSK_BIT_ALARM_CALCULATED			MSK_BIT5		; 1 si alarme calculee
#define	MSK_BIT_ALARM_CALCULATED_HIGH		MSK_BIT4		; 1 si alarme calculee (Tc >= Th)
#define	MSK_BIT_ALARM_CALCULATED_LOW		MSK_BIT3		; 1 si alarme calculee (Tc <= Tl)

.dseg

G_DS18B20_FLAGS:					.byte		1

G_HEADER_NUM_FRAME_MSB:			.byte		1		; Numero de la trame emise par la platine (MSB)
G_HEADER_NUM_FRAME_LSB:			.byte		1		; et (LSB)
G_HEADER_TIMESTAMP_MSB:			.byte		1		; Timestamp en Sec. de l'emission de la trame complete (MSB)
G_HEADER_TIMESTAMP_MID:			.byte		1		; + (MID)
G_HEADER_TIMESTAMP_LSB:			.byte		1		; et (LSB)
G_HEADER_NBR_CAPTEURS:			.byte		1		; Nombre de capteurs

G_DS18B20_BYTES_SEND:			.byte		16		; Bytes a emettre sur le 1-Wire
G_DS18B20_BYTES_RESP:			.byte		16		; Bytes recus sur le 1-Wire
G_DS18B20_BYTES_ROM:				.byte		8		; ROM extrait de la recherche

G_BUS_1_WIRE_FLAGS:				.byte		1

G_DS18B20_IN_ALARM:				.byte		1
G_DS18B20_FAMILLE:				.byte		1
G_DS18B20_COUNTER:				.byte		1
G_DS18B20_COUNTER_INIT:			.byte		1
G_DS18B20_NBR_BITS_RETRY:		.byte		1		; Numero de la passe ((1 << n) - 1) <= au nbr de bits inconnus
G_DS18B20_PATTERN:				.byte		1		; Pattern a tester
G_DS18B20_NBR_BITS_0_1:			.byte		1		; Nbr de bits inconnus (retour de 0x00) a balayer
G_DS18B20_NBR_BITS_0_1_MAX: 	.byte		1		; Nbr de bits inconnus maximal (pour verification @ pattern a tester
G_DS18B20_NBR_ROM_FOUND:		.byte		1		; Nbr de ROM trouve
G_DS18B20_NBR_ROM_MAX:			.byte		1		; Nbr de ROM maximal supporte (lu depuis l'EEPROM)
G_DS18B20_ROM_IDX_WRK:			.byte		1		; Index dans la table des ROM a rechercher / trouve
G_DS18B20_ROM_IDX:				.byte		1		; Index du ROM "matche" dans la plage [0, 1, 2, etc.]

; Reservation pour 'DS18B20_NBR_ROM_TO_DETECT' capteurs (ROM)
G_DS18B20_ROM_0:					.byte		(DS18B20_NBR_ROM_TO_DETECT * 8)	; Reservation pour 'DS18B20_NBR_ROM_TO_DETECT' ROM

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

; Reservation pour 2 capteurs en alarme dans la version "minimaliste"
; => Sinon reservation pour 4 capteurs en alarme
G_DS18B20_ALR_ROM_0:					.byte		(DS18B20_NBR_ROM_TO_DETECT * 8)	; Reservation pour 'DS18B20_NBR_ROM_TO_DETECT' ALR

; Zone de travail
G_DS18B20_WORK:						.byte		(DS18B20_NBR_ROM_TO_DETECT * 8)	; Non utilise directement

; Reservation de 1 byte pour accueillir le CRC8-MAXIM de l'ensemble de la trame
; Warning: 7 bytes seront concatenes a la trame:
;          - Index et type de la platine (2 bytes)
;          - Numero de la trame emise par cette platine (2 bytes)
;          - Timestamp en Sec. de l'emission de la trame complete (3 bytes)
;          - Nombre de capteurs (1 byte)
;
#define	G_FRAME_ALL_INFOS			G_DS18B20_ALR_ROM_0

; Reservation pour 'DS18B20_NBR_ROM_TO_DETECT' capteurs (ALR)
#define	G_DS18B20_FRAME_0			(G_DS18B20_ALR_ROM_0 + 1)

; End of file

