/*
 * utility.asm
 *
 *  Created: 8/10/2023 12:35:22 AM
 *   Author: Bertram
 */ 
.include "motor.asm"
.include "LCD.asm"
.include "keypad.asm"
#ifndef _UTILITY_
#define _UTILITY_

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

//argument for nested delay
.def countl=r24
.def counth=r25

//symbolic names in delay
.def ih=r27
.def il=r26
.def ih2=r29
.def il2=r28


//symbolic names in insert_request
.def asize=r10
.def aindex=r17
.def aindexr=r18
.def num=r19
.def value=r11
.def numr=r20
.def reg_cur=r21
.def req_cur=r22
.def cur_f=r5
.def dir=r6
//y is used
//x is used

//symbolic names in dequeue_request
.def request_size=r16
.def request_index=r17

//symbolic names in update_floor
.def direction=r18
.def cur_floor=r21

.macro refresh_lcd
	rcall update_direction
	rcall update_lcd
.endmacro

.macro shiftl_inc
	lsl @0
	inc @0
.endmacro

//@0=register, @1=dseg name
.macro inc_value
	inc @0
	sts @1, @0
.endmacro

//@0=register, @1=dseg name
.macro dec_value
	dec @0
	sts @1, @0
.endmacro

//@0=register, @1=value, @2=dseg name
.macro set_value
	ldi @0, @1
	sts @2, @0
.endmacro 

.macro clear
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr temp
	st Y+, temp
	st Y, temp
.endmacro

//used in insert_request to get negative flag in sreg
.macro test_neg
	mov @0, @1
	sub @0, @2
	in @0, sreg
	lsr @0           
	lsr @0
	lsr @0
	lsr @0
	andi @0, 0x01
.endmacro

////////////can be used for debugging////////////////
.macro test_before
	sbi porta, 1
	ldi countl, low(400)
	ldi counth, high(400)
	rcall nested_delay
.endmacro

.macro test_after
	cbi porta, 1
	ldi countl, low(400)
	ldi counth, high(400)
	rcall nested_delay
.endmacro

.macro enable_int
	in temp, EIMSK
	ori temp, 1<<@0
	out EIMSK, temp
.endmacro

.macro disable_int
	in temp, EIMSK
	andi temp, ~(1<<@0)
	out EIMSK, temp
.endmacro

.macro opening_door
	ldi com_match_l, open
	sts door_state, com_match_l
	//20% high = 13107
	ldi com_match_l, low(13107)
	ldi com_match_h, high(13107)
	start_motor_t3 com_match_l, com_match_h
.endmacro

.macro closing_door
	ldi temp, 1
	sts door_closing, temp
	//80% high = 52428
	ldi com_match_l, low(52428)
	ldi com_match_h, high(52428)
	start_motor_t3 com_match_l, com_match_h
.endmacro

.macro enable_ovf
	ldi temp, 1<<@0
	sts @1, temp
	clear @2
.endmacro

.macro disable_timer
	clr temp
	sts @0, temp
	clear @1
.endmacro

.macro enable_keypad
	ldi temp, 1<<TOIE4
	sts TIMSK4, temp
.endmacro

.macro disable_keypad
	clr temp
	sts TIMSK4, temp
.endmacro 


.cseg
//////////////////////////delay functions////////////////////////
sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

//argument: countl r24 and counth r25
//each loop takes around 10 cycles
//delay is nested. (if argument is 400, then 160000 loops and 1600000 cycles)
nested_delay:
	//prologue
	push ih
	push il
	push ih2
	push il2
	//body
	clr ih
	clr il
d_outer_loop: 
	cp il, countl
	cpc ih, counth 
	brsh d_done
	clr ih2
	clr il2
d_inner_loop: //10 cycles
	cp il2, countl; //1
	cpc ih2, counth //1
	brsh d_done_inner //1
	adiw ih2:il2, 1 //2
	nop //1
	nop //1
	rjmp d_inner_loop //3
d_done_inner:
	adiw ih:il, 1 
	rjmp d_outer_loop
d_done:
	//epilogue
	pop il2
	pop ih2
	pop il
	pop ih
	ret

/////////////////remove the first element from the request queue////////////
dequeue_request:
	push zh
	push zl
	push temp
	push request_size
	push request_index

	//shift everything in request queue: request(i) <- request(i+1)
	ldi zh, high(request)
	ldi zl, low(request)
	ldi request_index, 1
	//disable keypads for race condition
	disable_keypad
	adiw z, 1
	lds request_size, rqs
dequeue_request_loop:
	cp request_index, request_size
	breq dequeue_request_end
	ld temp, z
	st -z, temp
	adiw z, 2
	inc request_index
	rjmp dequeue_request_loop
dequeue_request_end:
	dec_value request_size, rqs
	refresh_lcd
	enable_keypad
	pop request_index
	pop request_size
	pop temp
	pop zl
	pop zh
	ret

//////////////////////insert a new request into request queue///////////////////
//argument: r11=value to be inserted
insert_request:
	;prologue
	push aindex
	push aindexr
	push num
	push numr
	push reg_cur
	push req_cur
	push xh
	push xl
	push yh
	push yl
	//body
	
	lds asize, rqs
	mov aindexr, asize
	lds cur_f, current_floor
	lds dir, current_direction
	ldi aindex, low(request)
	mov r8, aindex
	ldi aindex, high(request)
	mov r9, aindex
	clr aindex

	//new bit for test conditions
	clr req_cur
	test_neg req_cur, value, cur_f, dir

	; y points to start of array
	mov xh, r9
	mov xl, r8
	
	; z points to end of array
	mov yl, r8
	mov yh, r9
	clr r1
	add yl, asize
	adc yh, r1

outer_loop:
	cp aindex, asize
	brge end_outer
	ld	num, x+

	////new bit for test conditions
	clr reg_cur
	test_neg reg_cur, num, cur_f, dir
	//
	
	cp reg_cur, req_cur
	brne mid_check
	//register floor - current floor is same sign with requested floor - current floor
	//potential insert
	cp value, num
	breq end_insert

	//change
	//if registered floor - current floor is zero, no insert and check next registered floor
	//if registered floor - current floor is negative, try insert using descending condition
	//else registered floor - current floor is positive, try insert using ascending condition
	cp cur_f, num
	breq end_inner
	cpi reg_cur, 1
	breq descending_condition
	rjmp ascending_condition

mid_check:
	//conditions
	cp dir, req_cur
	breq inner_loop
	rjmp end_inner

ascending_condition:
	cp value, num
	brge end_inner
	rjmp inner_loop 

descending_condition:
	cp num, value
	brge end_inner
	rjmp inner_loop 

// inserting
inner_loop:
	cp aindex, aindexr
	brge end_outer
	ld numr, -y
	std y+1, numr
	dec aindexr
	rjmp inner_loop
end_inner:
	inc aindex
	rjmp outer_loop
end_outer:
	; insert value in array and inc r24
	clr r25
	cp asize, r25 
	breq no_dec_insert; array has 0 length, no pre-decr insert
	cp aindex, asize
	breq no_dec_insert;
	st -x, value
	rjmp incr
no_dec_insert:
	st x, value
incr:
	inc_value asize, rqs
end_insert:
	;epilogue
	pop yl
	pop yh
	pop xl
	pop xh
	pop req_cur
	pop reg_cur
	pop numr
	pop num
	pop aindexr
	pop aindex
	ret

/////////////updates floor number based on current direction//////////////////
update_floor:
	//prologue
	push temp
	push cur_floor
	push direction
	//body 
	lds temp, request
	lds cur_floor, current_floor
update_floor_num:
	lds direction, current_direction
	cpi direction, ascend
	breq update_floor_asc
	cpi direction, descend
	breq update_floor_desc
end_update_floor_num:		
	rcall lift_floor_display
	//epilogue
	pop direction
	pop cur_floor
	pop temp
	ret

update_floor_asc:
	inc_value cur_floor, current_floor
	rjmp end_update_floor_num

update_floor_desc:
	dec_value cur_floor, current_floor
	rjmp end_update_floor_num

/////////////updates direction based on first element in request queue//////////////////
update_direction:
	//prologue
	push temp
	push cur_floor
	push direction

	lds temp, request
	lds cur_floor, current_floor
	cp cur_floor, temp
	brlt set_to_asc
	cp temp, cur_floor
	brlt set_to_desc
update_direction_end:
	//epilogue
	pop direction
	pop cur_floor
	pop temp
	ret

set_to_asc:
	set_value direction, ascend, current_direction
	rjmp update_direction_end

set_to_desc:
	set_value direction, descend, current_direction
	rjmp update_direction_end
#endif
