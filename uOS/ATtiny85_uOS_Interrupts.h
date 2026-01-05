; "$Id: ATtiny85_uOS_Interrupts.h,v 1.3 2025/12/31 17:33:00 administrateur Exp $"

; Periode du tick materiel pour un ATtiny85 cadence a 20 Mhz
; Remarque: La duree de 26 uS permet un echantillonage pour gerer la liason
;           UART a 19200 bauds car 1 bit toutes les 52 uS
;           => Pour les vitesses 9600, 4800, ..., 600 et 300 bauds la duree
;              d'echantillonage est un multiple de 26 uS ;-)
;
#define	PERIODE_1MS					(1000 / 26)		; Cadencement par TMR0 de 26 uS

; Definition de la pin PINB<0> (INT0) dediee a RXD
#define	IDX_BIT_RXD					IDX_BIT0

#if USE_USI
#define STATE_USI_RX						0x01
#define STATE_USI_TX						0x02
#define STATE_USI_TX_IN_PROGRESS		0x04
#define STATE_USI_END_OF_TX			0x08
#endif

; End of file

