/*
 * keypad.asm
 *
 *  Created: 8/9/2023 7:21:05 PM
 *   Author: Bertram
 */

 #ifndef _KEYPAD_
 #define _KEYPAD_
 .include "states.asm"

 //symbolic names in keypad functions, args is r21 and r18
.def ktemp =r16
.def row =r17
.def col =r24
.def mask =r19
.def ktemp2 =r20
.def outputBits = r23
.def i = r22
.def ledValue = r26

.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

.cseg
keypad:
	push ktemp
	push row
	push col
	push mask
	push ktemp2
	push outputBits
	push i
	push ledValue

	clr ktemp
	ldi mask, INITCOLMASK
	clr col 

colloop:
	STS PORTL, mask 
	ldi ktemp, 0xFF 
	
delay:
	dec ktemp
	brne delay
	LDS ktemp, PINL 
	andi ktemp, ROWMASK 
	cpi ktemp, 0xF 
	breq nextcol
	ldi mask, INITROWMASK 
	clr row 
	
rowloop:      
	mov ktemp2, ktemp
	and ktemp2, mask 
	brne skipconv 
	rcall LED 
	jmp keypad_end
	
skipconv:
	inc row 
	lsl mask 
	jmp rowloop          

nextcol:     
	cpi col, 3 
	breq keypad_end
	sec 
	rol mask 
	inc col 
	jmp colloop 

keypad_end:
	cbi portA, 1
	pop ledValue
	pop i
	pop outputBits
	pop ktemp2
	pop mask
	pop col
	pop row
	pop ktemp
	ret

// LED FUNCTION //
//args is curr_florr r21 and direction r18
LED:
	push col
	push row
	push ktemp
	// added
	push ktemp2
	push mask
	//
	push outputBits
	push ledValue
	push cur_f
	push dir
	push r8
	push r9
	push asize
	push value

	// column 3 is not needed for output
	cpi col, 3 
	breq LED_end
	// check the columns in row 3
	cpi row, 3 
	breq LED_check 
	
	// either value 1-9 is stored in ktemp, depends on which key was pressed
	mov ktemp, row 
	lsl ktemp
	add ktemp, row 
	add ktemp, col 
	inc ktemp 
	
	// general implementation to output floors in the LED
inserting:
	mov value, ktemp 
	lds ktemp, current_floor
	cp ktemp, value
	breq insert_is_current
insert_check_end:
	rcall insert_request
	refresh_lcd
	rjmp LED_end

insert_is_current:
	lds ktemp, door_state
	cpi ktemp, close
	breq insert_check_end
	rjmp LED_end
	//potential addition
	

LED_check:
	// only column 0 and 1 are needed because the * and 0 key are in those columns
	cpi col, 0
	breq output_LED_star
	cpi col, 1
	breq output_LED_tenth

LED_end:
	pop value
	pop asize
	pop r9
	pop r8
	pop dir
	pop cur_f
	pop col
	pop row
	pop mask
	pop ktemp2
	pop ktemp
	pop outputBits
	pop ledValue
	ret
	
output_LED_tenth:
	ldi ktemp, 10
	jmp inserting

output_LED_star:
	jmp emergency_state
#endif

