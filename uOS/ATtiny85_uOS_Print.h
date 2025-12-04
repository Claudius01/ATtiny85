; "$Id: ATtiny85_uOS_Print.h,v 1.2 2025/12/01 17:36:27 administrateur Exp $

#define  CHAR_LF					0x0A		; Line Feed ('\n')
#define  CHAR_CR					0x0D		; Carriage Return ('\r')
#define  CHAR_NULL				0x00		; '\0'

.dseg
G_HEADER_TYPE_PLATINE:		.byte		1		; Type de la platine lu de l'EEPROM
G_HEADER_INDEX_PLATINE:		.byte		1		; Index de la platine lu de l'EEPROM

; End of file

