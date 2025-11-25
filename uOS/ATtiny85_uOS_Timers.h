; "$Id:"

; Attribution des 'NBR_TIMER' timers #0, #1, ..., #15
; => Le traitement associe a chaque timer est effectue dans l'ordre de son index
#define	NBR_TIMER							16

#define	TIMER_CONNECT						10
#define	TIMER_ERROR							11
#define	TIMER_APPUI_BOUTON_LED			12
#define	TIMER_APPUI_BOUTON_DETECT		13
#define	TIMER_RXD_ANTI_REBONDS			14
#define	TIMER_LED_GREEN					15

.dseg

; Valeurs sur 16 bits des 'NBR_TIMER' accedees par indexation @ G_TIMER_0_LSB:G_TIMER_0_MSB
G_TIMER_0:						.byte		2
G_TIMER_SPACE:					.byte		2 * (NBR_TIMER - 1)

; End of file

