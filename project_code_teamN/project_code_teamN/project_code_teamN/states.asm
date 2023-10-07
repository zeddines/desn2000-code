/*
 * states.asm
 *
 *  Created: 8/10/2023 3:42:50 AM
 *   Author: Bertram
 */
 #ifndef _STATES_
 #define _STATES_

 .include "utility.asm"
 .include "LED.asm"

 //symbolic names in serving state
.def cur_floor=r21
.def next_stop=r3

//symbolic names in emergency state
.def cur_floor=r21
.def ktemp=r16
.def row =r17
.def col =r24
.def mask =r19

//symbolic names in stop_state
.def pressed_open_close=r20
.def blink_counter=r19
.def com_match_l=r17
.def com_match_h=r23
.def cur_floor_stop=r21

//symbolic names in empty_queue_state
.def request_size=r16

.cseg
 ///////////serving_state//////////////
serving_request_state:
	lds request_size, rqs
	cpi request_size, 0
	//transition to idle state as request queue is empty
	breq empty_queue_state
	//enable timer0 for led and floor movement
	enable_ovf TOIE0, TIMSK0, temp_counter_two_sec
serving_request_state_loop:
	// request queue not empty, lift moves
	lds next_stop, request //get the first element in request queue
	lds cur_floor, current_floor
	cp  cur_floor, next_stop
	// check if lift has arrived
	brne serving_request_state_loop
	//lift has arrived requested stop
	//disable timer0 overflow interrupt to stop LED floor update
	disable_timer TIMSK0, temp_counter_two_sec
	//remove the floor that we will serve from the queue
	rcall dequeue_request
serving_request_stopping:
	//transition to stop state
	rcall stop_state
	//returned from stop state
	//enable timer0 overflow interrupt for LED floor update
	enable_ovf TOIE0, TIMSK0, temp_counter_two_sec
	rjmp serving_request_state
//////////serving_state_end///////////////

/////////////empty queue state/////////////
empty_queue_state:
	//disable timer0ovf interrupt to stop LED floor update
	disable_timer TIMSK0, temp_counter_two_sec
empty_queue_state_loop:
	lds request_size, rqs
	cpi request_size, 0
	//check if request queue is still empty
	breq empty_queue_state_loop
	//enable timer0ovf interrupt for LED floor update
	enable_ovf TOIE0, TIMSK0, temp_counter_two_sec
	rjmp serving_request_state
/////////////empty_queue_state end/////////////

 ////////////stop_state/////////////
stop_state:
	//prologue
	push yl
	push yh
	push temp
	push com_match_l
	push com_match_h
	push pressed_open_close
	push blink_counter
stop_starting_sequence:
	clr pressed_open_close
	clr blink_counter
	//opening door, press closed has no effect as the interrupts are disabled
	opening_door
	//blinks for one second
	rcall blink
	rcall blink
	stop_motor_t3
	//enable press button for door close and open
	enable_int INT0
	enable_int INT1
stop_state_loop:
	//blink for 3 seconds
	cpi blink_counter, 6
	brge stop_ending_sequence
	rcall blink
	jmp stop_state_case
stop_state_case_end:
	inc blink_counter
	rjmp stop_state_loop
stop_ending_sequence:
	//blinks for one second
	closing_door
	rcall blink
	cpi pressed_open_close, open
	breq back_to_start
	rcall blink
	cpi pressed_open_close, open
	breq back_to_start
	stop_motor_t3
	//disable_int0 and int1
	disable_int INT0
	disable_int INT1
	clr pressed_open_close
	//epilogue
	pop blink_counter
	pop pressed_open_close
	pop com_match_h
	pop com_match_l
	pop temp
	pop yh
	pop yl
	ret

stop_state_case:
	cpi pressed_open_close, open
	breq stop_state_press_open
	cpi pressed_open_close, close
	breq stop_state_press_close
	jmp stop_state_case_end

stop_state_press_open:
	clr pressed_open_close
	ldi countl, low(440)
	ldi counth, high(440)
	rcall nested_delay
	in temp, PIND
	andi temp, 0b00000010
	cpi temp, 2
	//branch if pb1 is deasserted, user not holding button
	breq go_to_loop
	//button is being held
stop_state_press_open_loop:
	in temp, PIND
	andi temp, 0b00000010
	cpi temp, 2
	//branch if pb1 is deasserted
	breq go_to_end
	rcall blink
	rjmp stop_state_press_open_loop

stop_state_press_close:
	clr pressed_open_close
	rjmp stop_ending_sequence

go_to_end:
	jmp stop_ending_sequence

back_to_start:
	jmp stop_starting_sequence

go_to_loop:
	ldi blink_counter, 0
	jmp stop_state_loop
////////////stop_state end/////////////


///////////emergency state//////////////
emergency_state:
	disable_keypad
	disable_int INT0
	disable_int INT1
	lds ktemp, door_state
	cpi ktemp, open
	brne emergency_door_closed
	stop_motor_t3
	closing_door
	rcall blink
	rcall blink
	stop_motor_t3
emergency_door_closed:
	enable_ovf TOIE0, TIMSK0, temp_counter_two_sec
	ldi ktemp, 1
	sts request, ktemp
	sts rqs, ktemp
	refresh_lcd
	ldi countl, low(440)
	ldi counth, high(440)
	sei
emergency_loop:
	sbi portA, 1
	rcall nested_delay
	cbi portA, 1
	rcall nested_delay
	lds cur_floor, current_floor
	cpi cur_floor, 1
	brne emergency_loop
	disable_timer TIMSK0, temp_counter_two_sec
	do_lcd_command 0b00000001
	do_lcd_data 'E'
	do_lcd_data 'm'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data 'g'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 'c'
	do_lcd_data 'y'
	do_lcd_command 0b11000000
	do_lcd_data 'C'
	do_lcd_data 'a'
	do_lcd_data 'l'
	do_lcd_data 'l'
	do_lcd_command 0b00010100
	do_lcd_data '0'
	do_lcd_data '0'
	do_lcd_data '0'
	do_lcd_command 0b00001100
	rcall stop_state
// infinite loop for waiting
emergency_loop_wait:
	sbi portA, 1
	clr ktemp
	ldi mask, INITCOLMASK
	clr col 
	// monitor asterik key
	// col: 0
	// row: 3
emergency_loop_col:
	STS PORTL, mask 
	ldi ktemp, 0xFF 	
emergency_loop_delay:
	dec ktemp
	brne emergency_loop_delay
	LDS ktemp, PINL 
	andi ktemp, ROWMASK 
	cpi ktemp, 0xF 
	breq emergency_loop_nextcol
	ldi mask, INITROWMASK 
	clr row 
emergency_loop_row:      
	mov ktemp2, ktemp
	and ktemp2, mask 
	brne emergency_loop_skipconv 
	// this checks the location of the asterisk button
	// continues infinite loop if not asterisk button
	cpi col, 0
	brne emergency_loop_wait
	cpi row, 3
	brne emergency_loop_wait
	jmp emergency_reset
emergency_loop_skipconv:
	inc row 
	lsl mask 
	jmp emergency_loop_row       
emergency_loop_nextcol:     
	cpi col, 3 
	// jump to infinite loop and scan again if column reaches max
	breq emergency_loop_wait
	sec 
	rol mask 
	inc col 
	jmp emergency_loop_col
emergency_reset:
	jmp reset
//////////emergency state end//////////////
 #endif
