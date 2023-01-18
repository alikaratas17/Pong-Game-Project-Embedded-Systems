;
; alikaratas17_project.asm
;
; Author : alikaratas17
;

; Uart Addition 1
.equ CR=13
.equ LF = 10
.equ BAUD_RATE = 9600
.equ CPU_CLOCK  = 4000000
.equ UBRRVAL = (CPU_CLOCK/(16*BAUD_RATE))-1
.def SENTCHAR =r0
.def RECCHAR =r1


.equ U_hex = $55
.equ D_hex = $44

.equ RS=1<<2 ; PORT A
.equ RW= 1<<3 ; PORT A

.equ EN = 1<<6 ; PORT D
.equ RST = 1<<7 ; PORT D

.equ CS1 = 1<<0 ; PORT B
.equ CS2 = 1<<1 ; PORT B
.equ SLOW_SPEED = 0xF0
.equ MEDIUM_SPEED = 0xa0
.equ FAST_SPEED = 0x40

.equ TURN_ON = (1<<5)|(1<<4)|(1<<3)|(1<<2)|(1<<1)|(1<<0)
.equ TURN_OFF = (1<<5)|(1<<4)|(1<<3)|(1<<2)|(1<<1)
.equ PAGE_SELECT = (1<<7)|(1<<5)|(1<<4)|(1<<3) ; OR with 3-bit page number
.equ ADDRESS_SELECT = (1<<6) ; OR with 6-bit addr.
.equ GAP_BEFORE_SCORES = 24

;Ball Dir
.equ UP_BIT = 0
.equ DOWN_BIT = 1
.equ RIGHT_BIT = 2
.equ LEFT_BIT = 3
.equ DIR_UP = (1<<UP_BIT)
.equ DIR_DOWN = (1<<DOWN_BIT)
.equ DIR_RIGHT = (1<<RIGHT_BIT)
.equ DIR_LEFT = (1<<LEFT_BIT)

.equ DDRB_CONFIG = (1<<0) | (1<<1)

.def scores = R15
.def temp=R16
.def temp2=R17
.def temp3 = R18
.def game_speed= R19
.def inputs = R20 ; U2D2/xx/xx/U1D1 -> Mask with 00000011 to get user1's current input, Mask with 11000000 to get user2's current input
.def game_state = R21 
.def sliders = R22 ; Y1 -> Last 4 bits, Y2 -> First 4 bits
.def ball_dir = R23 ; 4 bit for x, 4 for y
.def ball_x = R24
.def ball_y = R25
; Replace with your application code

.org	$0000
	jmp	RESET


RESET:
	;Init Stack Pointer
	ldi temp, low(RAMEND)	; Load low-byte
	out	spl, temp		;
	ldi temp, high(RAMEND)	; Load high-byte
	out sph, temp
	; Set Necessary Parts of ports as output
    ldi temp, (1<<2) | (1<<3)
	out DDRA, temp
	ldi temp, DDRB_CONFIG
	out DDRB, temp
	ldi temp, $FF
	out DDRC, temp
	ldi temp, (1<<6) | (1<<7)
	out DDRD, temp

	; Uart Addition 2
	ldi temp, low(UBRRVAL) ; set the baud rate
	out UBRRL, temp
	ldi temp, high(UBRRVAL) ; set the baud rate
	out UBRRH, temp
	ldi temp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
	out UCSRC, temp ; set 8-bit comm.
	sbi UCSRB, TXEN ; enable UART serial transmitter
	sbi UCSRB, RXEN ; enable UART serial receiver

	; Load 0 to all ports
	ldi temp, $00
	out PORTA, temp
	out PORTB, temp
	out PORTC, temp
	out PORTD, temp
	rcall EN_FALLING_EDGE

	rcall InitScreen
	ldi temp,0;$21
	mov scores,temp
	;rcall DisplayScores
	rcall	InitObjects
	;rcall PlaceBall
	;rcall PlaceSliders
	rcall PlaceBall
	rcall  PlaceSliders
	rcall getGameSpeed
	ldi game_state, 0
MAIN_LOOP:
	rcall CheckForPause
	rcall GetUser1InputTask
	rcall GetUser2InputTask
	rcall communicateWithComputerTask
	rcall UpdateGameTask
	rcall delay2
	rjmp MAIN_LOOP
; Tasks
communicateWithComputerTask:
	tst game_state
	brne READ_FROM_COMP
SEND_TO_COMP:
	; Send y of sliderR & ball Y to computer
	mov SENTCHAR,sliders
SEND_LOOP1:
	sbis UCSRA, UDRE
	rjmp SEND_LOOP1
	out UDR,SENTCHAR
	mov SENTCHAR,ball_y
SEND_LOOP2:
	sbis UCSRA, UDRE
	rjmp SEND_LOOP2
	out UDR,SENTCHAR
	ret
READ_FROM_COMP:
	sbis UCSRA, RXC
	rjmp RET_communicateWithComputerTask 
	in RECCHAR, UDR 
	mov temp,RECCHAR
	cpi temp,U_hex
	breq U_RECEIVED_FROM_COMP
	cpi temp,D_hex
	breq D_RECEIVED_FROM_COMP
	ret
U_RECEIVED_FROM_COMP:
	sbr inputs,(1<<6)
	ret
D_RECEIVED_FROM_COMP:
	sbr inputs,(1<<7)
RET_communicateWithComputerTask:
	ret
; Get Input From User 1
GetUser1InputTask:
	push temp
	push temp2
	push temp3
	ldi temp3, 0
GETUSER1INPUTTASKLOOP:
	in temp, PINA ; Get input from A0 and A1
	andi temp, (1<<0)|(1<<1)
	tst temp
	breq CONTINUE_USER1_INPUT
	mov temp2, inputs
	andi temp2, 0b11111100
	or temp2, temp
	mov inputs,temp2
CONTINUE_USER1_INPUT:
	inc temp3
	tst temp3
	brne GETUSER1INPUTTASKLOOP
RET_GetUser1InputTask:	
	pop temp3
	pop temp2
	pop temp
	ret

GetUser2InputTask:
	push temp
	push temp2
	push temp3
	ldi temp3, 0
GETUSER2INPUTTASKLOOP:
	in temp, PINA ; Get input from A6 and A7
	andi temp, (1<<6)|(1<<7)
	tst temp
	breq CONTINUE_USER2_INPUT
	mov temp2, inputs
	andi temp2, $FF-((1<<6)|(1<<7))
	or temp2, temp
	mov inputs, temp2
CONTINUE_USER2_INPUT:
	inc temp3
	tst temp3
	brne GETUSER1INPUTTASKLOOP
RET_GetUser2InputTask:	
	pop temp3
	pop temp2
	pop temp
	ret


; Update Game State and Screen
UpdateGameTask:
	inc game_state
	cp game_state, game_speed
	brne RET_UpdateGameTask
	ldi game_state,0
	rcall RemoveSliders
	rcall RemoveBall
	rcall UpdatePositions
	rcall CheckCollisions
	rcall PlaceBall
	rcall  PlaceSliders
RET_UpdateGameTask:
	ret



EN_FALLING_EDGE:
	push temp
	in temp, PIND
	ori temp, EN
	out PORTD, temp
	rcall delay
	in temp, PIND
	andi temp, ~EN
	out PORTD, temp
	pop temp
	ret
	
DELAY:
	push temp
	push temp3
	ldi temp, 0
	ldi temp3,255-1
DELAY_OUTER:
	inc temp3
	tst temp3
	brne DELAY_LOOP
	pop temp3
	pop temp
	ret
DELAY_LOOP:
	inc temp
	tst temp
	brne DELAY_LOOP
	rjmp DELAY_OUTER



; Helpers


; Initialize Screen to All 0s
InitScreen:
	; Reset
	ldi temp, RST
	out PORTD, temp
	rcall EN_FALLING_EDGE
	; Turn on
	ldi temp,TURN_ON
	out PORTC, temp
	rcall EN_FALLING_EDGE

	ldi temp,0
	out PORTA, temp
	ldi temp, PAGE_SELECT
	out PORTC, temp
	rcall EN_FALLING_EDGE

	ldi temp2,0
	ldi temp,RS
	out PORTA, temp
	ldi temp, (1<<7)
	out PORTC,temp
	rjmp InitScreenInner
InitScreenOuter:
	ldi temp,0
	out PORTA, temp
	inc temp2
	cpi temp2,8
	breq RET_INITSCREEN
	ldi temp, PAGE_SELECT
	or temp, temp2
	out PORTC, temp
	rcall EN_FALLING_EDGE
	ldi temp,RS
	out PORTA, temp
	ldi temp3,64
	ldi temp, 0
	out PORTC,temp
InitScreenInner:
	dec temp3
	rcall EN_FALLING_EDGE
	tst temp3
	breq InitScreenOuter
	rjmp InitScreenInner
RET_INITSCREEN:
	ret
	
InitObjects:
	;;ldi sliders, (1<<2)|(1<<6)
	ldi sliders, $67
	ldi ball_dir,DIR_LEFT|DIR_UP
	ldi ball_x, 64
	ldi ball_y, 28
	ldi inputs, 0
	ret
PlaceSliders:
	push temp
	push temp2
	push temp3
PLACE_RIGHT_SLIDER:
	ldi temp2, CS1
	out PORTB, temp2
	mov temp, sliders
	andi temp,1
	tst temp
	breq PLACE_RIGHT_ONE_PART
PLACE_RIGHT_TWO_PART:
	mov temp, sliders
	lsr temp
	andi temp, 0b00000111
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT|0b00111111
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $F0
	out PORTC, temp2
	rcall EN_FALLING_EDGE

	inc temp
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT|0b00111111
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $0F
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	rjmp PLACE_LEFT_SLIDER

PLACE_RIGHT_ONE_PART:
	mov temp, sliders
	lsr temp
	andi temp, 0b00000111
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT|0b00111111
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $FF
	out PORTC, temp2
	rcall EN_FALLING_EDGE


PLACE_LEFT_SLIDER:
	ldi temp2, CS2
	out PORTB, temp2
	mov temp, sliders
	swap temp
	andi temp,1
	tst temp
	breq PLACE_LEFT_ONE_PART
PLACE_LEFT_TWO_PART:
	mov temp, sliders
	swap temp
	lsr temp
	andi temp, 0b00000111
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $F0
	out PORTC, temp2
	rcall EN_FALLING_EDGE

	inc temp
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $0F
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	rjmp RET_PLACE_SLIDERS
PLACE_LEFT_ONE_PART:
	mov temp, sliders
	swap temp
	lsr temp
	andi temp, 0b00000111
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $FF
	out PORTC, temp2
	rcall EN_FALLING_EDGE
RET_PLACE_SLIDERS:
	ldi temp,0
	out PORTB,temp
	pop temp3
	pop temp2
	pop temp
	ret

RemoveSliders:
	push temp
	push temp2
	push temp3
REMOVE_RIGHT_SLIDER:
	ldi temp2, CS1
	out PORTB, temp2
	mov temp, sliders
	andi temp,1
	tst temp
	breq REMOVE_RIGHT_ONE_PART
REMOVE_RIGHT_TWO_PART:
	mov temp, sliders
	lsr temp
	andi temp, 0b00000111
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT|0b00111111
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $00
	out PORTC, temp2
	rcall EN_FALLING_EDGE

	inc temp
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT|0b00111111
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $00
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	rjmp REMOVE_LEFT_SLIDER

REMOVE_RIGHT_ONE_PART:
	mov temp, sliders
	lsr temp
	andi temp, 0b00000111
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT|0b00111111
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $00
	out PORTC, temp2
	rcall EN_FALLING_EDGE


REMOVE_LEFT_SLIDER:
	ldi temp2, CS2
	out PORTB, temp2
	mov temp, sliders
	swap temp
	andi temp,1
	tst temp
	breq REMOVE_LEFT_ONE_PART
REMOVE_LEFT_TWO_PART:
	mov temp, sliders
	swap temp
	lsr temp
	andi temp, 0b00000111
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $00
	out PORTC, temp2
	rcall EN_FALLING_EDGE

	inc temp
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $00
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	rjmp RET_REMOVE_SLIDERS
REMOVE_LEFT_ONE_PART:
	mov temp, sliders
	swap temp
	lsr temp
	andi temp, 0b00000111
	ldi temp2,0
	out PORTA,temp2
	ldi temp2, PAGE_SELECT
	or temp2, temp
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, RS
	out PORTA, temp2
	ldi temp2, $00
	out PORTC, temp2
	rcall EN_FALLING_EDGE
RET_REMOVE_SLIDERS:
	ldi temp,0
	out PORTB,temp
	pop temp3
	pop temp2
	pop temp
	ret

PlaceBall:
	push temp
	push temp2
	push temp3
	mov temp, ball_x
	andi temp, (1<<6)
	tst temp
	brne BALL_IN2
BALL_IN1:
	ldi temp,CS2
	out PORTB,temp
	rjmp CS_SET_IN_PLACE_BALL
BALL_IN2:
	ldi temp,CS1
	out PORTB,temp
CS_SET_IN_PLACE_BALL:
	ldi temp, 0
	out PORTA,temp
	mov temp2, ball_y
	; Reduce temp2 to 3-bits
	andi temp2, 0b00111111
	lsr temp2
	lsr temp2
	lsr temp2
	andi temp2, 0b00000111
	ldi temp, PAGE_SELECT
	or temp, temp2
	out PORTC, temp
	rcall EN_FALLING_EDGE
	mov temp2, ball_x
	andi temp2, 0b00111111
	ldi temp, ADDRESS_SELECT
	or temp, temp2
	out PORTC, temp
	rcall EN_FALLING_EDGE
	ldi temp, RS
	out PORTA,temp
	mov temp2, ball_y
	andi temp2, 0b00000111
	ldi temp,1
	tst temp2
	breq CONTINUE_AFTER_BUILDING_TEMP_IN_PLACE_BALL
BUILD_TEMP_IN_PLACE_BALL:
	lsl temp
	andi temp,~1
	dec temp2
	tst temp2
	brne BUILD_TEMP_IN_PLACE_BALL
CONTINUE_AFTER_BUILDING_TEMP_IN_PLACE_BALL:
	out PORTC,temp
	rcall EN_FALLING_EDGE
	ldi temp,0
	out PORTB,temp
	pop temp3
	pop temp2
	pop temp
	ret

RemoveBall:
	push temp
	push temp2
	push temp3
	mov temp, ball_x
	andi temp, (1<<6)
	tst temp
	brne BALL_IN2_REMOVE
BALL_IN1_REMOVE:
	ldi temp,CS2
	out PORTB,temp
	rjmp CS_SET_IN_REMOVE_BALL
BALL_IN2_REMOVE:
	ldi temp,CS1
	out PORTB,temp
CS_SET_IN_REMOVE_BALL:
	ldi temp, 0
	out PORTA,temp
	mov temp2, ball_y
	; Reduce temp2 to 3-bits
	andi temp2, 0b00111111
	lsr temp2
	lsr temp2
	lsr temp2
	andi temp2, 0b00000111
	ldi temp, PAGE_SELECT
	or temp, temp2
	out PORTC, temp
	rcall EN_FALLING_EDGE
	mov temp2, ball_x
	andi temp2, 0b00111111
	ldi temp, ADDRESS_SELECT
	or temp, temp2
	out PORTC, temp
	rcall EN_FALLING_EDGE
	ldi temp, RS
	out PORTA,temp
	ldi temp,0
	out PORTC,temp
	rcall EN_FALLING_EDGE
	ldi temp,0
	out PORTB,temp
	pop temp3
	pop temp2
	pop temp
	ret


DisplayScores:
	push temp
	push temp2
	push temp3
	mov temp, scores
	swap temp
	andi temp,$0F
	tst temp
	breq P2_Score
P1_Score:
	ldi temp2,(1<<1) ;CS2 disabled
	out PORTB, temp2
	ldi temp2, 0
	out PORTA, temp2
	ldi temp2, PAGE_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	rcall AddScore
P2_Score:
	mov temp, scores
	andi temp,$0F
	tst temp
	breq RET_DisplayScores
	ldi temp2,(1<<0) ;CS1 disabled
	out PORTB, temp2
	ldi temp2, 0
	out PORTA, temp2
	ldi temp2, PAGE_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, ADDRESS_SELECT
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	rcall AddScore
RET_DisplayScores:
	ldi temp,0
	out PORTB, temp
	pop temp3
	pop temp2
	pop temp
	ret

AddScore:
	ldi temp2,RS
	out PORTA, temp2
	ldi temp2, (1<<7)
	out PORTC, temp2
	ldi temp3, GAP_BEFORE_SCORES
ADD_SCORE_GAP_LOOP:
	rcall EN_FALLING_EDGE
	dec temp3
	tst temp3
	brne ADD_SCORE_GAP_LOOP
ADD_SCORE_LOOP:
	ldi temp2, (1<<7)|(1<<4)|(1<<3)|(1<<2)|(1<<1)|(1<<0)
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	ldi temp2, (1<<7)
	out PORTC, temp2
	rcall EN_FALLING_EDGE
	dec temp
	brne ADD_SCORE_LOOP
	ret
UpdatePositions:
	push temp
	push temp2
	push temp3
	mov temp,sliders
	andi temp, $0F
	mov temp2, inputs
	swap temp2
	lsr temp2
	lsr temp2
	andi temp2, 0b11
	rcall UpdateSliderPosition
	mov temp3,temp
	ori temp3,$F0
	mov temp,sliders
	swap temp
	andi temp, $0F
	mov temp2, inputs
	andi temp2, 0b11
	rcall UpdateSliderPosition
	ori temp, $F0
	swap temp
	and temp3,temp
	mov sliders,temp3

	mov temp,ball_dir
	sbrs temp,UP_BIT
	rjmp MOVE_BALL_CHECK_DOWN
MOVE_BALL_UP:
	dec ball_y
	rjmp MOVE_BALL_CHECK_RIGHT
MOVE_BALL_CHECK_DOWN:
	sbrs temp,DOWN_BIT
	rjmp MOVE_BALL_CHECK_RIGHT
MOVE_BALL_DOWN:
	inc ball_y
MOVE_BALL_CHECK_RIGHT:
	sbrs temp,RIGHT_BIT
	rjmp MOVE_BALL_CHECK_LEFT
MOVE_BALL_RIGHT:
	inc ball_x
	rjmp RET_UpdatePositions
MOVE_BALL_CHECK_LEFT:
	sbrs temp,LEFT_BIT
	rjmp RET_UpdatePositions
MOVE_BALL_LEFT:
	dec ball_x
RET_UpdatePositions:
	ldi inputs,0
	pop temp3
	pop temp2
	pop temp
	ret
; Update position of temp
; Using info in temp2
UpdateSliderPosition:
	cpi temp2, (1<<0)
	breq UpdateSliderUp
	cpi temp2, (1<<1)
	breq UpdateSliderDown
	ret
UpdateSliderDown:
	cpi temp,$e
	breq NoUpdateToSlider
	inc temp
	ret
UpdateSliderUp:
	cpi temp,2
	breq NoUpdateToSlider
	dec temp
	ret
NoUpdateToSlider:
	ret

CheckCollisions:
	cpi ball_x,0
	breq Collision_with_left
	cpi ball_x,127
	breq Collision_with_right
	rjmp Check_up_down_collisions
Collision_with_left:
	push temp
	mov temp,sliders
	swap temp
	andi temp, $0F
	inc temp
	inc temp
	lsl temp
	lsl temp
	cp ball_y, temp
	brsh GOAL_AGAINST_LEFT
	subi temp,8
	cp ball_y, temp
	brlo GOAL_AGAINST_LEFT
	pop temp
	inc ball_x
	sbr ball_dir, DIR_RIGHT
	cbr ball_dir, DIR_LEFT
	rjmp Check_up_down_collisions
GOAL_AGAINST_LEFT:
	mov temp,scores
	inc temp
	mov scores, temp
	rjmp RET_WITH_GOAL

Collision_with_right:
	push temp
	mov temp,sliders
	andi temp, $0F
	inc temp
	inc temp
	lsl temp
	lsl temp
	cp ball_y, temp
	brsh GOAL_AGAINST_RIGHT
	subi temp,8
	cp ball_y, temp
	brlo GOAL_AGAINST_RIGHT
	pop temp
	dec ball_x
	sbr ball_dir, DIR_LEFT
	cbr ball_dir, DIR_RIGHT
	rjmp Check_up_down_collisions
GOAL_AGAINST_RIGHT:
	mov temp,scores
	swap temp
	inc temp
	swap temp
	mov scores, temp
	rjmp RET_WITH_GOAL

Check_up_down_collisions:
	cpi ball_y,8
	breq Collision_with_up
	cpi ball_y,63
	breq Collision_with_down
	rjmp RET_CheckCollisions
Collision_with_up:
	sbr ball_dir, DIR_DOWN
	cbr ball_dir, DIR_UP
	rjmp RET_CheckCollisions
Collision_with_down:
	sbr ball_dir, DIR_UP
	cbr ball_dir, DIR_DOWN
RET_CheckCollisions:
	ret
RET_WITH_GOAL:
	pop temp
	rcall initObjects
	rcall DisplayScores
	ret	

delay2:
	push temp
	push temp2
	ldi temp2,1
delay2_inner:
	rcall delay2_subroutine
	dec temp2
	brne delay2_inner
	pop temp2
	pop temp
	ret

delay2_subroutine:
	ldi temp, $FF
delay2_subroutine_inner:
	dec temp
	brne delay2_subroutine_inner
	ret


CheckForPause:
	push temp
	push temp2
	in temp2,PIND
	andi temp2, ~ ((1<<2)|(1<<3))

	in temp, PIND
	out PORTD,temp2
	andi temp,(1<<2)|(1<<3)
	cpi temp,(1<<2)|(1<<3)
	brne RETURN_FROM_PAUSE
WAIT_TO_PAUSE:
	rcall delay2
	in temp, PIND
	out PORTD,temp2
	andi temp,(1<<2)|(1<<3)
	cpi temp,(1<<2)|(1<<3)
	breq WAIT_TO_PAUSE ; User needs to stop pressing
	ldi temp, (1<<WDE)|(1<<WDP2)|(1<<WDP1)|(1<<WDP0)
	out WDTCR,temp
	wdr
PAUSED:
	rcall delay2
	in temp, PIND
	out PORTD,temp2
	andi temp,(1<<2)|(1<<3)
	cpi temp,(1<<2);|(1<<3)
	breq STOP_WATCHDOG
	rjmp PAUSED
STOP_WATCHDOG:
	wdr
	ldi temp, (1<<WDTOE)|(1<<WDE)
	out WDTCR,temp
	ldi temp, (0<<WDE)
	out WDTCR,temp
RETURN_FROM_PAUSE:
	pop temp2
	pop temp
	ret

getGameSpeed:
	push temp
	push temp2
	rcall getDefaultGameSpeed
	mov game_speed,temp
	rcall waitFinalChoiceGameSpeed
	rcall writeDefaultGameSpeed
	ldi temp2, DDRB_CONFIG
	out DDRB, temp2
	pop temp2
	pop temp
	ret

getDefaultGameSpeed:
	ldi temp, $00
	out EEARH,temp
	ldi temp,$10
	out EEARL,temp
	ldi temp, (1<<EERE)
	out EECR,temp
	in temp, EEDR
	;ldi temp,FAST_SPEED
	cpi temp,SLOW_SPEED
	breq INITIAL_CHOICE_SLOW
	cpi temp,MEDIUM_SPEED
	breq INITIAL_CHOICE_MEDIUM
	cpi temp,FAST_SPEED
	breq INITIAL_CHOICE_FAST
	ldi temp,0 ; Since temp is not one of the choices
	ret
INITIAL_CHOICE_SLOW:
	ldi temp2, DDRB_CONFIG|(1<<5)
	out DDRB, temp2
	in temp2,PINB
	ori temp2,(1<<5)
	out PORTB,temp2
	ret
INITIAL_CHOICE_MEDIUM:
	ldi temp2, DDRB_CONFIG|(1<<6)
	out DDRB, temp2
	in temp2,PINB
	ori temp2,(1<<6)
	out PORTB,temp2
	ret
INITIAL_CHOICE_FAST:
	ldi temp2, DDRB_CONFIG|(1<<7)
	out DDRB, temp2
	in temp2,PINB
	ori temp2,(1<<7)
	out PORTB,temp2
	ret

waitFinalChoiceGameSpeed:
	rcall delay2
	in temp2,PINB
	andi temp2, (1<<7)|(1<<6)|(1<<5)|(1<<4)
	mov temp, temp2
	andi temp,(1<<7)
	tst temp
	breq CONSIDER_MEDIUM
waitFinalChoiceGameSpeed_FastPressed:
	cpi game_speed, FAST_SPEED
	breq CONSIDER_MEDIUM
	ldi game_speed, FAST_SPEED
	ldi temp2, DDRB_CONFIG|(1<<7)
	out DDRB, temp2
	in temp2,PINB
	andi temp2, DDRB_CONFIG
	ori temp2,(1<<7)
	out PORTB,temp2
	rjmp waitFinalChoiceGameSpeed
CONSIDER_MEDIUM:
	mov temp, temp2
	andi temp,(1<<6)
	tst temp
	breq CONSIDER_SLOW
waitFinalChoiceGameSpeed_MediumPressed:
	cpi game_speed, MEDIUM_SPEED
	breq CONSIDER_SLOW
	ldi game_speed, MEDIUM_SPEED
	ldi temp2, DDRB_CONFIG|(1<<6)
	out DDRB, temp2
	in temp2,PINB
	andi temp2, DDRB_CONFIG
	ori temp2,(1<<6)
	out PORTB,temp2
	rjmp waitFinalChoiceGameSpeed
CONSIDER_SLOW:
	mov temp, temp2
	andi temp,(1<<5)
	tst temp
	breq CONSIDER_SEND
waitFinalChoiceGameSpeed_SlowPressed:
	cpi game_speed, SLOW_SPEED
	breq CONSIDER_SEND
	ldi game_speed, SLOW_SPEED
	ldi temp2, DDRB_CONFIG|(1<<5)
	out DDRB, temp2
	in temp2,PINB
	andi temp2, DDRB_CONFIG
	ori temp2,(1<<5)
	out PORTB,temp2
	rjmp waitFinalChoiceGameSpeed
CONSIDER_SEND:
	mov temp, temp2
	andi temp,(1<<4)
	tst temp
	breq waitFinalChoiceGameSpeed
waitFinalChoiceGameSpeed_SendPressed:
	tst game_speed
	breq waitFinalChoiceGameSpeed
RET_waitFinalChoiceGameSpeed:
	ret


writeDefaultGameSpeed:
	in temp2, EECR
	andi temp2, (1<<EEWE)
	tst temp2
	brne writeDefaultGameSpeed
	ldi temp, $00
	out EEARH,temp
	ldi temp,$10
	out EEARL,temp
	out EEDR, game_speed
	ldi temp, (1<<EEMWE)
	out EECR,temp
	ldi temp, (1<<EEWE)
	out EECR,temp
	ret
	