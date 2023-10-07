/*
 * LED.asm
 *
 *  Created: 8/9/2023 7:20:34 PM
 *   Author: Bertram
 */
 


 #ifndef _LED_
 #define _LED_
 .include "utility.asm"

//symbolic names in blink
.def lfd_arg=r15
.def countl=r24
.def counth=r25


//symbolic names in lift_floor_display function
.def lfd_i=r16
.def lfd_bitPC=r17
.def lfd_bitPG=r18
.def lfd_temp=r19
.def lfd_floor=r15


.cseg
/////////////////////////////blinking LED///////////////////
//executes a LED blinking cycle 
//each blinking cycle takes 0.5 seconds
blink:
	//prologue
	push countl
	push counth
	push temp
	//body
	ldi countl, low(632)
	ldi counth, high(632)
	rcall nested_delay
	clr temp
	out PORTC, temp
	out PORTG, temp
	ldi countl, low(632)
	ldi counth, high(632)
	rcall nested_delay
	rcall lift_floor_display
	//epilogue
	pop temp
	pop counth
	pop countl
	ret 

//////////////////////display floor number on LED////////////////////
lift_floor_display:
	//prologue
	push yl
	push yh
	push r15
	push r16
	push r17
	push r18
	push r19
	in yl, spl
	in yh, sph

	clr lfd_bitPC
	clr lfd_bitPG
	clr lfd_i
	out PORTC, lfd_bitPC
	out PORTG, lfd_bitPC

	lds lfd_floor, current_floor
loop:
	cp lfd_i, lfd_floor
	breq load_port
	shiftl_inc lfd_bitPC
	brcs shiftl_inc_PG
loop_c:
	inc lfd_i
	rjmp loop

shiftl_inc_PG:
	shiftl_inc lfd_bitPG
	rjmp loop_c

load_port: 
	out PORTC, lfd_bitPC
	out PORTG, lfd_bitPG
	ser lfd_temp
	out DDRC, lfd_temp
	out DDRG, lfd_temp

lift_floor_display_end:
	pop r19
	pop r18
	pop r17
	pop r16
	pop r15
	pop yh
	pop yl
	ret
#endif
