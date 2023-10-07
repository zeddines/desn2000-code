;
; lab03.asm
;
; Created: 7/11/2023 4:51:37 PM
; Author : Bertram
;

.include "m2560def.inc"
.equ descend=1
.equ ascend=0
.equ open=1
.equ close=2
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

//temp and yh and yl are used as temporary registers throughout the entire program. 

//symbolic names in timer0 counters
.def t0_c_l=r24
.def t0_c_h=r25
.def t0_temp=r22


//symbolic names in main 
.def cur_floor=r21
.def direction=r18
.def temp=r22
.def next_stop=r3
.def request_size=r16
.def request_index=r17
.def lfd_arg=r15
// z is also used

//symbolic names in stop_state
.def pressed_open_close=r20
.def blink_counter=r19
.def com_match_l=r17
.def com_match_h=r23
.def cur_floor_stop=r21

//symbolic names in keypad functions, args is r21 and r18
.def ktemp =r16
.def row =r17
.def col =r24
.def mask =r19
.def ktemp2 =r20
.def outputBits = r23
.def i = r22
.def ledValue = r26
//will use r10, r11, r8 and r9 to pass args

.def t4Temp = r27
.def t4TempLow = r28
.def t4TempHigh = r29


//symbolic names in insert_request
.def asize=r10 //(arg and return)
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

//symbolic names in update_lcd 
//argument is cur_floor r21
.def cur_floor_lcd=r21
.def next_stop_lcd=r22
.def do_lcd_input=r16
.def display_number_arg=r17



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

//symbolic names in delay
.def ih=r27
.def il=r26
.def ih2=r29
.def il2=r28
// uses countl=r24
// uses counth=r25

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

.macro do_lcd_command
	ldi do_lcd_input, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi do_lcd_input, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

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

.macro refresh_lcd
	rcall update_direction
	rcall update_lcd
.endmacro

//@0 (lsb) and @1 (hsb) is compare match
//80% high = 52428
//20% high = 13107
.macro start_motor_t3
	sts OCR3BL, @0
	sts OCR3BH, @1
	ldi temp, (1<<CS30)
	sts TCCR3B, temp
	ldi temp, (1<<WGM30)|(1<<COM3B1)
	sts TCCR3A, temp
.endmacro

.macro stop_motor_t3
	clr temp
	sts TCCR3B, temp
	sts TCCR3A, temp
	sts OCR3BL, temp
	sts OCR3BH, temp
	lds temp, door_closing
	cpi temp, 0
	breq end_stop_motor_t3
	ldi temp, close
	sts door_state, temp
	clr temp
	sts door_closing, temp
end_stop_motor_t3:
.endmacro

.macro opening_door
	ldi com_match_l, open
	sts door_state, com_match_l
	ldi com_match_l, low(13107)
	ldi com_match_h, high(13107)
	start_motor_t3 com_match_l, com_match_h
.endmacro

.macro closing_door
	ldi temp, 1
	sts door_closing, temp
	ldi com_match_l, low(52428)
	ldi com_match_h, high(52428)
	start_motor_t3 com_match_l, com_match_h
.endmacro

.dseg
request:
	.byte 10
temp_counter_two_sec:
	.byte 2
current_floor:
	.byte 1
current_direction:
	.byte 1
rqs:
	.byte 1
door_state:
	.byte 1
door_closing:
	.byte 1

.cseg
	jmp reset
	jmp ext_int0
	jmp ext_int1
.org OVF0addr
	jmp Timer0OVF
.org OVF4addr
	jmp Timer4OVF

//////////////interrupt subroutine////////////////
default:
	reti

reset:
	//set up stack, no reserved local variable
	ldi yl, low(RAMEND)
	ldi yh, high(RAMEND)
	out sph, yh
	out spl, yl

	sbi DDRE, PE3	; switch on backlight
	sbi PORTE, PE3

	ldi temp, 0x01
	out DDRC, temp
	out PORTC, temp
	clr temp

	rjmp main

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
//////////////interrupt subroutine////////////////


/////////////timer functions///////////////
//countl and counth is argument
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
/////////////timer functions///////////////

main:
	set_value cur_floor, 1, current_floor
	set_value direction, ascend, current_direction
	clr temp
	sts rqs, temp
	sts door_state, temp
	sts door_closing, temp
	//initialize timer interrupts
	//not enabled
	clr t0_c_l
	clr t0_c_h
	//clr t1_c_l
	//clr t1_c_h
	clr temp
	out TCCR0A, temp
	sts TCCR1A, temp
	sts TCCR2A, temp
	sts TCCR4A, temp
	ldi temp, 0b00000010
	out TCCR0B, temp
	sts TCCR1B, temp
	ldi temp, (1 << CS41)
	sts TCCR4B, temp
	//initialize motor OC3B bit
	ldi temp, 0b00010000 //set bit to output
	out DDRE, temp
	//initialize external interrupt 0 and 1
	//not enabled
	lds temp, EICRA
	ori temp, (2<<ISC00)
	ori temp, (2<<ISC10)
	sts EICRA, temp
	//initialize keypads
	ldi temp, PORTLDIR 
	sts DDRL, temp
	//set up lcd
	ser temp
	out DDRF, temp
	out DDRA, temp
	clr temp
	out PORTF, temp
	out PORTA, temp
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001100 ; Cursor on, bar, no blink

	//does once to display lcd first
	rcall update_lcd 
	enable_keypad
	//enable global interrupts
	sei

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

///////////serving_state//////////////
serving_request_state:
	//enable_keypad
	lds request_size, rqs
	cpi request_size, 0
	breq empty_queue_state
	//enable timer0 for led and floor movement
	enable_ovf TOIE0, TIMSK0, temp_counter_two_sec
serving_request_state_loop:
	// has request, lift keeps moving
	lds next_stop, request //get the first element in request queue
	lds cur_floor, current_floor
	cp  cur_floor, next_stop
	brne serving_request_state_loop
	//disable timer0 overflow interrupt
	disable_timer TIMSK0, temp_counter_two_sec
	rjmp request_served

serving_request_stopping:
	rcall stop_state
	//rjmp request_served
	enable_ovf TOIE0, TIMSK0, temp_counter_two_sec
	rjmp serving_request_state

/////////////empty queue state/////////////
empty_queue_state:
	//timer is already disabled during after stop_state
	disable_timer TIMSK0, temp_counter_two_sec
empty_queue_state_loop:
	lds request_size, rqs
	cpi request_size, 0
	breq empty_queue_state_loop
	enable_ovf TOIE0, TIMSK0, temp_counter_two_sec
	rjmp serving_request_state
/////////////empty_queue_state end/////////////

request_served:
	//move everything in request: request(i) <- request(i+1)
	ldi zh, high(request)
	ldi zl, low(request)
	ldi request_index, 1
	//disable keypads for race condition
	disable_keypad
	adiw z, 1
	lds request_size, rqs
request_served_loop:
	cp request_index, request_size
	breq request_served_end
	ld temp, z
	st -z, temp
	adiw z, 2
	inc request_index
	rjmp request_served_loop
request_served_end:
	dec_value request_size, rqs
	refresh_lcd
	enable_keypad
	rjmp serving_request_stopping
///////////serving_state end//////////////



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


// KEYPAD FUNCTIONALITY //
//args is curr_floor r21 and direction r18
keypad:
	push ktemp
	push row
	push col
	push mask
	push ktemp2
	push outputBits
	push i
	push ledValue
	// sbi portA, 1

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
	//ldi countl, low(400)
	//ldi counth, high(400)
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
	opening_door
	rcall blink
	rcall blink
	stop_motor_t3
	rcall blink
	rcall blink
	rcall blink
	rcall blink
	rcall blink
	rcall blink
	closing_door
	rcall blink
	rcall blink
	stop_motor_t3
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


///////////insert request///////////////
//r11 is value to be inserted
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

/////////insert request end
update_lcd:
	//prologue
	push cur_floor_lcd
	push next_stop_lcd
	push do_lcd_input
	push temp
	//body
	do_lcd_command 0b00000001 //clear display
	do_lcd_data 'C'
	do_lcd_data 'u'
	do_lcd_data 'r'
	do_lcd_data 'r'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'f'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_data ' '
	//mov display_number_arg, cur_floor_lcd
	lds display_number_arg, current_floor
	rcall display_number
	do_lcd_command 0b11000000
	do_lcd_data 'N'
	do_lcd_data 'e'
	do_lcd_data 'x'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 's'
	do_lcd_data 't'
	do_lcd_data 'o'
	do_lcd_data 'p'
	do_lcd_data ' '
	lds temp, rqs
	cpi temp, 0
	breq update_lcd_empty_queue
	lds display_number_arg, request
	rcall display_number
	do_lcd_data ' '
	do_lcd_data ' '
	lds temp, current_direction
	cpi temp, ascend
	breq update_lcd_up
	rjmp update_lcd_down
	//epilogue
update_lcd_end:
	pop temp
	pop do_lcd_input
	pop next_stop_lcd
	pop cur_floor_lcd
	ret

update_lcd_empty_queue:
	do_lcd_data '-'
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data '-'
	rjmp update_lcd_end

update_lcd_up:
	do_lcd_data 'U'
	rjmp update_lcd_end

update_lcd_down:
	do_lcd_data 'D'
	rjmp update_lcd_end
	

/////////////lcd code in part B lab 4////////////////
//argument is r21 number
display_number:
	push do_lcd_input
	push display_number_arg

	cpi display_number_arg, 10
	brlt display_normal
	//display ten
	do_lcd_data '1'
	do_lcd_data '0'
	rjmp display_number_end
display_normal:
	ldi do_lcd_input, 0b00110000 ; ascii for '0'
	add do_lcd_input, display_number_arg ; Convert the digit to ASCII character
	rcall lcd_data
	rcall lcd_wait ; Display the digit on the LCD 

display_number_end:
	pop display_number_arg
	pop do_lcd_input
	ret

lcd_command:
	out PORTF, do_lcd_input
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, do_lcd_input
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

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
/////////////lcd code in part B lab 4 end////////////////

//// argument is cur_floor=r21
blink:
	//prologue
	push countl
	push counth
	push temp
	push lfd_arg
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
	// SEE IF CAN REMOVE
	//mov lfd_arg, cur_floor_blink
	// !!!!!!!!!!!!!
	rcall lift_floor_display
	//epilogue
	pop lfd_arg
	pop temp
	pop counth
	pop countl
	ret 

//called in timer0 ovf
update_floor:
	//prologue
	push temp
	push cur_floor
	push direction
	//body 
	lds temp, request
	lds cur_floor, current_floor
	//cp cur_floor, temp
	//brlt set_to_asc
	//cp temp, cur_floor
	//brlt set_to_desc
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


	

//argument for current floor number in r15
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
