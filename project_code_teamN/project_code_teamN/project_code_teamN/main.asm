;
; lab03.asm
;
; Created: 7/11/2023 4:51:37 PM
; Author : Bertram
;
.cseg
	jmp reset
	jmp ext_int0
	jmp ext_int1
.org OVF0addr
	jmp Timer0OVF
.org OVF4addr
	jmp Timer4OVF

.include "m2560def.inc"
.include "utility.asm"
.include "ext_interrupts.asm"
.include "timers.asm"
.include "states.asm"


.equ descend=1
.equ ascend=0
.equ open=1
.equ close=2

//used everywhere
.def temp=r22

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

main:
	//initialize current floor, direction, queue size
	//and state of door
	set_value cur_floor, 1, current_floor
	set_value direction, ascend, current_direction
	clr temp
	sts rqs, temp
	sts door_state, temp
	sts door_closing, temp
	//initialize timer interrupts parameters
	//not enabled yet
	clr t0_c_l
	clr t0_c_h
	clr t4Temp
	clr t4TempLow
	clr t4TempHigh
	clr temp
	out TCCR0A, temp
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
	//not enabled yet
	lds temp, EICRA
	ori temp, (2<<ISC00)
	ori temp, (2<<ISC10)
	sts EICRA, temp
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
	refresh_lcd 
	//initialize and enable keypads
	ldi temp, PORTLDIR 
	sts DDRL, temp
	enable_keypad
	//enable global interrupts
	sei

	rjmp serving_request_state
















