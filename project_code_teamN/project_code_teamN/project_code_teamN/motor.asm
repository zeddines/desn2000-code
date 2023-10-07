/*
 * motor.asm
 *
 *  Created: 8/9/2023 7:21:51 PM
 *   Author: Bertram
 */ 

 #ifndef _MOTOR_
 #define _MOTOR_
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
#endif
