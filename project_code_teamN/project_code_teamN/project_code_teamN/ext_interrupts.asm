/*
 * ext_interrupts.asm
 *
 *  Created: 8/10/2023 1:32:09 AM
 *   Author: Bertram
 */ 

 #ifndef _ext_interrupts_
 #define _ext_interrupts_
 .include "utility.asm"
 .cseg

///////////////////external interrupt 0, corresponds to pb0 closing door///////////////////
ext_int0:
	//prologue
	push temp
	in temp, sreg
	push temp
	push countl
	push counth
	//debouncing delay, around 30ms
	ldi countl, low(220)
	ldi counth, high(220)
	rcall nested_delay

	in temp, PIND
	andi temp, 1
	cpi temp, 1
	//branch if pb0 is deasserted
	breq ext_int0_end
	ldi pressed_open_close, close

ext_int0_end:
	//writing 1 to EIFR
	in temp, EIFR
	ori temp, 1
	out EIFR, temp
    //epilogue
	pop counth
	pop countl
	pop temp
	out sreg, temp
	pop temp
	reti
	
///////////////////external interrupt 1, corresponds to pb1 opening door///////////////////
ext_int1:
	//prologue
	push temp
	in temp, sreg
	push temp
	push countl
	push counth
	//debouncing delay, around 30ms
	ldi countl, low(220)
	ldi counth, high(220)
	rcall nested_delay
	in temp, PIND
	andi temp, 0b00000010
	cpi temp, 2
	//branch if pb1 is deasserted
	breq ext_int1_end
	ldi pressed_open_close, open


ext_int1_end:
	//writing 1 to EIFR
	in temp, EIFR
	ori temp, (1<<1)
	out EIFR, temp
    //epilogue
	pop counth
	pop countl
	pop temp
	out sreg, temp
	pop temp
	reti
#endif
