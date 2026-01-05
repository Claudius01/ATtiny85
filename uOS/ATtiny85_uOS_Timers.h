; "$Id: ATtiny85_uOS_Timers.h,v 1.14 2026/01/02 18:28:56 administrateur Exp $"

; Attribution des 'NBR_TIMER' timers #0, #1, ..., #15
; => Limitation a 8 timers dans la cas 'USE_MINIMALIST_UOS' (#0, #1, ..., #7)
; => Le traitement associe a chaque timer est effectue dans l'ordre de son index
#if !USE_MINIMALIST_UOS
#define	NBR_TIMER							16
#else
#define	NBR_TIMER							8
#endif

#define	TIMER_CONNECT						0
#define	TIMER_ERROR							1
#define	TIMER_LED_GREEN					2
#define	TIMER_APPUI_BOUTON_LED			3
#define	TIMER_APPUI_BOUTON_DETECT		4

#if !USE_MINIMALIST_UOS
; Pas de gestion de UART/Rx et des Commandes dans le cas 'USE_MINIMALIST_UOS' ;-)
#define	TIMER_RXD_ANTI_REBONDS			5
#endif

#if USE_DUMP_SRAM
#define	TIMER_DUMP_SRAM					6
#endif

.dseg

; Valeurs sur 16 bits des 'NBR_TIMER' accedees par indexation @ G_TIMER_0_LSB:G_TIMER_0_MSB
G_TIMER_0:						.byte		2
G_TIMER_SPACE:					.byte		2 * (NBR_TIMER - 1)

; Contextes sur 16 bits des 'NBR_TIMER' accedees par indexation @ 'G_TIMER_ADDRESS_0'
; => Le contexte est en fait l'adresse d'execution du callback
;    => TODO: A renommer...
G_TIMER_ADDRESS_0:			.byte		2	; 2 bytes pour le contexte
G_TIMER_ADDRESS_SPACE_0:	.byte		2 * (NBR_TIMER - 1)

; End of file

