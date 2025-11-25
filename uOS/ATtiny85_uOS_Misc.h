; "$Id: ATtiny85_uOS_Misc.h,v 1.1 2025/11/25 16:56:59 administrateur Exp $"

; Definitions pour le calcul du crc8-maxim
#define	CRC8_POLYNOMIAL	0x8C			; Masque pour le calcul du CR8-MAXIM

.dseg
G_CALC_CRC8:		.byte		1				; Calcul du crc8-maxim cumulee byte par byte

; End of file

