; "$Id: ATtiny85_DS18B20_1_Wire_Commands.h,v 1.3 2025/12/14 18:05:27 administrateur Exp $"

#define	DS18B20_CMD_READ_ROM					0x33	; Lecture du registre ROM de 64 bits
#define	DS18B20_CMD_MATCH_ROM				0x55	; Match du registre ROM de 64 bits
#define	DS18B20_CMD_CONVERT_T				0x44	; Conversion de la temperature
#define	DS18B20_CMD_COPY_SCRATCHPAD		0x48	; Recopie du Scratchpad dans l'EEPROM
#define	DS18B20_CMD_WRITE_SCRATCHPAD		0x4E	; Ecriture de la Scratchpad
#define	DS18B20_CMD_READ_POWER_SUPPLY		0xB4	; Lecture Power Mode
#define	DS18B20_CMD_RECALL_EEPROM			0xB8	; Recopie de l'EEPROM dans le Scratchpad
#define	DS18B20_CMD_READ_SCRATCHPAD		0xBE	; Lecture de la Scratchpad
;#define	DS18B20_CMD_SKIP_ROM					0xCC	; Skip du registre ROM de 64 bits

; Pas de recherche alarme si 'USE_MINIMALIST_ADDONS'
;#ifndef USE_MINIMALIST_ADDONS
#define	DS18B20_CMD_SEARCH_ALARM			0xEC	; Recherche du registre ROM sur le bus qui est en alarme
;#endif

#define	DS18B20_CMD_SEARCH_ROM				0xF0	; Recherche du registre ROM sur le bus

; End of file

