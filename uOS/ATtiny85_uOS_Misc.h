; "$Id: ATtiny85_uOS_Misc.h,v 1.4 2026/01/02 18:28:56 administrateur Exp $"

; Forcage des 'call' en 'rcall' dans la cas de la generation "minimaliste"
; => '_CALL' force un "rcall" (appel relatif)
;    => 

#if USE_MINIMALIST_UOS
.macro _CALL
rcall		@0
.endm
#else
.macro _CALL
call		@0
.endm
#endif
; Fin: Forcage des 'call' en 'rcall' dans la cas de la generation "minimaliste"

; Definitions pour le calcul du crc8-maxim
#define	CRC8_POLYNOMIAL	0x8C			; Masque pour le calcul du CR8-MAXIM

.dseg
G_CALC_CRC8:		.byte		1				; Calcul du crc8-maxim cumulee byte par byte

; End of file

