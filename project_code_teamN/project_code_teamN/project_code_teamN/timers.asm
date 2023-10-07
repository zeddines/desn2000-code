/*
 * timer4.asm
 *
 *  Created: 8/9/2023 7:20:08 PM
 *   Author: Bertram
 */ 
 #ifndef _TIMERS_
 #define _TIMERS_
 .include "utility.asm"

 //symbolic names in timer4ovf
.def t4Temp = r27
.def t4TempLow = r28
.def t4TempHigh = r29

 //symbolic names in timer0ovf
.def t0_c_l=r24
.def t0_c_h=r25
.def t0_temp=r22

.cseg
//////////////////timer0 overflow interrupt subroutine///////////////
//implemented as a counter. Calls update_direction, update_floor and update_lcd every
//two seconds
Timer0OVF:
	//prologue
	push t0_temp
	in t0_temp, sreg
	push t0_temp
	push yh
	push yl
	push t0_c_l
	push t0_c_h

check_two_second:
	//temp counter for two second
	lds t0_c_l, temp_counter_two_sec
	lds t0_c_h, temp_counter_two_sec+1
	adiw t0_c_h:t0_c_l, 1
	cpi t0_c_l, low(15624) 
	ldi t0_temp, high(15624)
	cpc t0_c_h, t0_temp
	brne not_two_second
	rcall update_direction
	rcall update_floor
	rcall update_lcd
	clear temp_counter_two_sec
	rjmp t0_end_if

not_two_second:
	sts temp_counter_two_sec, t0_c_l
	sts temp_counter_two_sec+1, t0_c_h
	rjmp t0_end_if
	
t0_end_if:
	//epilogue
	pop t0_c_h
	pop t0_c_l
	pop yl
	pop yh
	pop t0_temp
	out sreg, t0_temp
	pop t0_temp
	reti

///////////////////Timer4 overflow interrupt subroutine//////////////////////
//used for keypad scanning
//keypad is scanned every 0.3ms
Timer4OVF:
	push t4Temp
	in t4Temp, sreg
	push t4Temp
	push yh
	push yl
	push t4TempLow
	push t4TempHigh
	rcall keypad
	rjmp t4_end_if

	
t4_end_if:
	//epilogue
	pop t4TempHigh
	pop t4TempLow
	pop yl
	pop yh
	pop t4Temp
	out sreg, t4Temp
	pop t4Temp
	reti
#endif
