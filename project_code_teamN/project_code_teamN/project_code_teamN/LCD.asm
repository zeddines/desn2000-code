/*
 * LCD.asm
 *
 *  Created: 8/9/2023 7:20:47 PM
 *   Author: Bertram
 */ 

 #ifndef _LCD_
 #define _LCD_

//symbolic names in update_lcd 
.def cur_floor_lcd=r21
.def next_stop_lcd=r22
.def do_lcd_input=r16
.def display_number_arg=r17

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4


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

.cseg
////////////////update floor number and direction on lcd based on current////////////////
////////////////floor and current direction/////////////////////////////
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
	

//argument: r21=display_number_arg(number 1-10 to be displayed on lcd)
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

////////////////lcd helper functions//////////////////
//write to lcd instruction register
lcd_command:
	out PORTF, do_lcd_input
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

//write to lcd data register
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

//delays for lcd
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
#endif
