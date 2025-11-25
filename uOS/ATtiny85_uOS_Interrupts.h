; "$Id: ATtiny85_uOS_Interrupts.h,v 1.1 2025/11/25 18:11:16 administrateur Exp $"

; Periode du tick materiel pour un ATtiny85 cadence a 20 Mhz
; Remarque: La duree de 26 uS permet un echantillonage pour gerer la liason
;           UART a 19200 bauds car 1 bit toutes les 52 uS
;           => Pour les vitesses 9600, 4800, ..., 600 et 300 bauds la duree
;              d'echantillonage est un multiple de 26 uS ;-)
;
#define	PERIODE_1MS					(1000 / 26)		; Cadencement par TMR0 de 26 uS

; Definition de la pin PINB<0> (INT0) dediee a RXD
#define	IDX_BIT_RXD					IDX_BIT0

; End of file

