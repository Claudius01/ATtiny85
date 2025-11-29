; "$Id: ATtiny85_uOS+DS18B20_Timers.asm,v 1.3 2025/11/29 12:31:38 administrateur Exp $"

.cseg

; Extensions d'execution de uOS pour DS18B20
; -------
exec_timer_3_ds18b20:
	lds      REG_X_MSB, G_HEADER_TIMESTAMP_MID
	lds      REG_X_LSB, G_HEADER_TIMESTAMP_LSB
	adiw     REG_X_LSB, 1
	sts      G_HEADER_TIMESTAMP_MID, REG_X_MSB
	sts      G_HEADER_TIMESTAMP_LSB, REG_X_LSB

	brne		exec_timer_3_more

	lds		REG_TEMP_R17, G_HEADER_TIMESTAMP_MSB
	inc		REG_TEMP_R17
	sts		G_HEADER_TIMESTAMP_MSB, REG_TEMP_R17

	; Cadencement de l'emission des trames DS18B20
exec_timer_3_more:
	lds		REG_TEMP_R17, G_DS18B20_COUNTER
	tst		REG_TEMP_R17
	breq		exec_timer_3_cont_d							; Pas de traitement si 'G_DS18B20_COUNTER' trouve a 0

	dec		REG_TEMP_R17
	sts		G_DS18B20_COUNTER, REG_TEMP_R17			; New value of counter
	brne		exec_timer_3_cont_d							; Awaiting counter equal to 0

	lds		REG_TEMP_R17, G_DS18B20_COUNTER_INIT	; Reinit value of counter
	sts		G_DS18B20_COUNTER, REG_TEMP_R17

	; Execution de la decouverte des capteurs DS18B20 + emission de la trame
exec_timer_3_send_trame_derivation:
	rcall		ds18b20_exec

	; Fin: Cadencement de l'emission des trames DS18B20

exec_timer_3_cont_d:
	ldi		REG_TEMP_R17, DS18B20_TIMER_1_SEC
	ldi		REG_TEMP_R18, (1000 % 256)
	ldi		REG_TEMP_R19, (1000 / 256)
	call		start_timer

	ret
; ---------

; End of file

