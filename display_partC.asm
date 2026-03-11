/*
 * display_partC.asm
 *
 *  Created: 3/17/2025 4:23:19 PM
 *   Author: jasvinkaur
 */ 
 .cseg
.org 0
    jmp start  ; Reset vector: Jump to the start of the program on reset.

.org 0x22
	jmp timer1_interrupt  ; Timer1 interrupt vector: Jump to the ISR when Timer1 overflows.

.include "lcd.asm"  ; Include the LCD library for interfacing with the LCD.
.cseg

#define DELAY 0.5     ; Delay in seconds for the Timer1 interrupt.
#define WRAP_SEPARATOR ' '   ; Character used as a separator when wrapping text.
.def mode=r21                ; Register to store the scroll mode (0 = left, 1 = right, 2 = no scroll).
.def scroll_line1=r22        ; Register to store the scroll offset for the first line.
.def scroll_line2=r23        ; Register to store the scroll offset for the second line.
.def msg1_len=r24            ; Register to store the length of the first message.
.def msg2_len=r25            ; Register to store the length of the second message.

#define CLOCK 16.0e6         ; Clock frequency of the microcontroller.
.equ PRESCALE_DIV=1024       ; Prescaler value for Timer1.
.equ TOP=int(0.5+(CLOCK/PRESCALE_DIV*DELAY))  ; Calculate the TOP value for Timer1.
.if TOP>65535                ; Check if the TOP value is within the 16-bit range.
.error "TOP is out of range" ; Throw an error if TOP exceeds the range.
.endif

; Definitions for using the Analog to Digital Conversion (ADC) for button input.
.equ ADCSRA_BTN=0x7A  ; ADC Control and Status Register A.
.equ ADCSRB_BTN=0x7B  ; ADC Control and Status Register B.
.equ ADMUX_BTN=0x7C   ; ADC Multiplexer Selection Register.
.equ ADCL_BTN=0x78    ; ADC Data Register Low.
.equ ADCH_BTN=0x79    ; ADC Data Register High.

; Button threshold values for ADC readings.
.equ RIGHT = 0x032  ; ADC value for the right button.
.equ DOWN  = 0x17C  ; ADC value for the down button.
.equ LEFT  = 0x22B  ; ADC value for the left button.

start:
	rcall initialize  ; Initialize the system.
	clr scroll_line1  ; Clear the scroll offset for the first line.
	clr scroll_line2  ; Clear the scroll offset for the second line.
	ldi mode, 2       ; Set mode to 2 (no scrolling) initially.
	rcall final_display  ; Display the initial state of the LCD.
	runtime_loop:
		rcall check_button  ; Check for button input.
		rjmp runtime_loop   ; Repeat indefinitely.

end: jmp end  ; Infinite loop to keep the program running.

; Initialize the system.
initialize: 
    rcall lcd_init  ; Initialize the LCD.
	rcall initialize_adc  ; Initialize the ADC for button input.
	rcall init_strings  ; Copy strings from flash memory to data memory.
	rcall lengths  ; Compute the lengths of the two strings.
	rcall initialize_timer1  ; Configure Timer1 for scrolling.
	ret

; Initialize the ADC for button input.
initialize_adc:
	push r16
	; Enable the ADC and set the prescaler to 128 (16 MHz / 128 = 125 kHz).
	ldi r16, 0x87  ; 0x87 = 0b10000111 (ADEN = 1, ADPS2:0 = 111 for prescaler 128).
	sts ADCSRA_BTN, r16

	; Set ADCSRB to 0 (free-running mode, MUX5 = 0).
	ldi r16, 0x00
	sts ADCSRB_BTN, r16

	; Configure ADMUX:
	; - REFS1:0 = 01 (AVCC with external capacitor at AREF pin).
	; - ADLAR = 0 (right-adjust the ADC result).
	; - MUX4:0 = 00000 (ADC0 channel).
	ldi r16, 0x40  ; 0x40 = 0b01000000
	sts ADMUX_BTN, r16
	pop r16
	ret

; Copy strings from program memory to data memory.
init_strings:
	push r16
	; Copy msg1 from program memory to data memory.
	ldi r16, high(msg1)  ; Load the high byte of the destination address.
	push r16
	ldi r16, low(msg1)   ; Load the low byte of the destination address.
	push r16
	ldi r16, high(msg1_p << 1)  ; Load the high byte of the source address (program memory).
	push r16
	ldi r16, low(msg1_p << 1)   ; Load the low byte of the source address (program memory).
	push r16
	call str_init  ; Call the string initialization routine.
	pop r16  ; Clean up the stack.
	pop r16
	pop r16
	pop r16

	; Copy msg2 from program memory to data memory.
	ldi r16, high(msg2)
	push r16
	ldi r16, low(msg2)
	push r16
	ldi r16, high(msg2_p << 1)
	push r16
	ldi r16, low(msg2_p << 1)
	push r16
	call str_init
	pop r16
	pop r16
	pop r16
	pop r16

	pop r16
	ret

; Compute the lengths of msg1 and msg2 and store them in msg1_len and msg2_len.
lengths:
	push ZL
	push ZH
	push r22

	; Compute the length of msg1.
	ldi ZL, low(msg1)
    ldi ZH, high(msg1)
	rcall get_strlen
	mov msg1_len, r22  ; Store the length of msg1 in msg1_len.

	; Compute the length of msg2.
	ldi ZL, low(msg2)
    ldi ZH, high(msg2)
	rcall get_strlen
	mov msg2_len, r22  ; Store the length of msg2 in msg2_len.

	pop r22
	pop ZH
	pop ZL
	ret

; Count the number of characters in a string pointed to by the Z register pair.
; The result is stored in the r22 register.
get_strlen:
	push ZL
	push ZH
	push r16
	clr r22  ; Initialize the counter to zero.
	loop:
		ld r16, Z+  ; Load a character from memory and increment Z.
		cpi r16, 0  ; Check if the character is the null terminator.
		breq done_strlen  ; If null, exit the loop.
		inc r22  ; Increment the counter.
		rjmp loop  ; Repeat for the next character.
	done_strlen:
		pop r16
		pop ZH
		pop ZL
		ret

; Display the first scrolling line on the LCD.
scrolling_line1:
	push r16
	push ZL
	push ZH

	; Point the Z register to msg1.
	ldi ZL, low(msg1)
    ldi ZH, high(msg1)

	; Move the cursor to row 0, column 0.
	ldi r16, 0
	push r16
	push r16
	call lcd_gotoxy
	pop r16
	pop r16

	; Point r16 to the scroll offset for the first line.
	mov r16, scroll_line1

	; Display msg1 on the first line.
	rcall display_line

	pop ZH
	pop ZL
	pop r16
	ret

; Display the second scrolling line on the LCD.
scrolling_line2:
	push r16
	push ZL
	push ZH

	; Point the Z register to msg2.
	ldi ZL, low(msg2)
    ldi ZH, high(msg2)

	; Move the cursor to row 1, column 0.
	ldi r16, 1
	push r16
	ldi r16, 0
	push r16
	call lcd_gotoxy
	pop r16
	pop r16

	; Point r16 to the scroll offset for the second line.
	mov r16, scroll_line2

	; Display msg2 on the second line.
	rcall display_line

	pop ZH
	pop ZL
	pop r16
	ret

; Display a single character pointed to by the r17 register.
char_display:
	push r17
	rcall lcd_putchar  ; Call the LCD character display function.
	pop r17
	ret

; Display 16 characters of a string pointed to by the Z register.
; The starting offset is stored in the r16 register.
; If the string ends before 16 characters, it wraps to the beginning.
display_line:
	push r16  ; Save the offset.
	push r17  ; Save the character.
	push r18  ; Save the counter.
	ldi r18, 0  ; Initialize the counter to zero.

	; Apply the scroll offset to the Z pointer.
	add ZL, r16
	adc ZH, r18  ; r18 is 0, so this handles the carry.

	print_loop:
		ld r17, Z+  ; Load a character from memory and increment Z.
		tst r17  ; Check if the character is the null terminator.
		breq wrap  ; If null, wrap to the beginning of the string.
		rcall char_display  ; Display the character.
		inc r18  ; Increment the counter.
		rjmp check_len  ; Check if 16 characters have been displayed.
	wrap:
		ldi r17, WRAP_SEPARATOR  ; Insert a separator before wrapping.
		rcall char_display
		add r16, r18  ; Add the offset and the counter to get the total length.
		inc r16  ; Account for the null terminator.
		sub ZL, r16  ; Reset Z to the beginning of the string.
		ldi r16, 0  ; Clear r16 to handle the carry.
		sbc ZH, r16
		rjmp print_loop  ; Continue printing.
	check_len:
		cpi r18, 16  ; Check if 16 characters have been displayed.
		brsh done_display  ; If so, exit the loop.
		rjmp print_loop  ; Otherwise, continue.
	done_display:
		pop r18
		pop r17
		pop r16
		ret

; Initialize Timer1 for scrolling.
initialize_timer1:
	push r16
	push r17

	; Set the TOP value for Timer1.
	ldi r17, high(TOP)
	ldi r16, low(TOP)
	sts OCR1AH, r17
	sts OCR1AL, r16

	; Configure Timer1 for CTC mode with a prescaler of 1024.
	ldi r16, 0
	sts TCCR1A, r16

	ldi r16, (1 << WGM12) | (1 << CS12) | (1 << CS10)
	sts TCCR1B, r16

	; Enable Timer1 compare interrupt.
	ldi r16, (1 << OCIE1A)
	sts TIMSK1, r16
	sei  ; Enable global interrupts.

	pop r17
	pop r16
	ret

; Check for button input and update the scroll mode.
check_button:
	push r16
	push r17
	push r18  ; r18 stores the low byte of the ADC result.
	push r19  ; r19 stores the high byte of the ADC result.

	; Start an ADC conversion.
	lds r16, ADCSRA_BTN
	ori r16, 0x40  ; Set the ADSC bit to start conversion.
	sts ADCSRA_BTN, r16

	; Wait for the ADC conversion to complete.
	wait:
		lds r16, ADCSRA_BTN
		andi r16, 0x40
		brne wait  ; If ADSC is still set, keep waiting.

	; Read the ADC result.
	lds r18, ADCL_BTN
	lds r19, ADCH_BTN

	; Check if the ADC value corresponds to a button press.
	ldi r16, low(LEFT)
	ldi r17, high(LEFT)
	cp r18, r16
	cpc r19, r17
	brsh done_check  ; If greater than LEFT, exit.

	ldi r16, low(RIGHT)
	ldi r17, high(RIGHT)
	cp r18, r16
	cpc r19, r17
	brlo rbtn  ; If less than RIGHT, check for RIGHT button.
	rjmp assess_lbtn  ; Otherwise, check for LEFT button.

	rbtn:
		ldi mode, 1  ; Set mode to scroll right.
		rjmp done_check

	assess_lbtn:
		ldi r16, low(DOWN)
		ldi r17, high(DOWN)
		cp r18, r16
		cpc r19, r17
		brlo done_check  ; If less than DOWN, do nothing.
	lbtn:
		ldi mode, 0  ; Set mode to scroll left.

	done_check:
		pop r19
		pop r18
		pop r17
		pop r16
	ret

; Clear the LCD and display the current state of the scrolling lines.
final_display:
	rcall lcd_clr  ; Clear the LCD.
	rcall scrolling_line1  ; Display the first scrolling line.
	rcall scrolling_line2  ; Display the second scrolling line.
	ret

; Scroll the text to the left.
scroll_left:
	cpi msg1_len, 17
	brsh line1_left  ; Scroll only if msg1 is longer than 16 characters.
	rjmp continue_left
	line1_left:
		cp scroll_line1, msg1_len
		brsh wrap_line1_left
		inc scroll_line1  ; Increment the scroll offset.
		rjmp continue_left
	wrap_line1_left:
		ldi scroll_line1, 0  ; Wrap to the beginning of the string.
	continue_left:
		cpi msg2_len, 17
		brsh line2_left  ; Scroll only if msg2 is longer than 16 characters.
		rjmp done_left
	line2_left:
		cp scroll_line2, msg2_len
		brsh wrap_line2_left
		inc scroll_line2  ; Increment the scroll offset.
		rjmp done_left
	wrap_line2_left:
		ldi scroll_line2, 0  ; Wrap to the beginning of the string.
	done_left:
		rcall final_display  ; Update the LCD display.
	ret

; Scroll the text to the right.
scroll_right:
	cpi msg1_len, 17
	brsh line1_right  ; Scroll only if msg1 is longer than 16 characters.
	rjmp continue_right
	line1_right:
		cpi scroll_line1, 0
		breq wrap_line1_right
		dec scroll_line1  ; Decrement the scroll offset.
		rjmp continue_right
	wrap_line1_right:
		mov scroll_line1, msg1_len  ; Wrap to the end of the string.
	continue_right:
		cpi msg2_len, 17
		brsh line2_right  ; Scroll only if msg2 is longer than 16 characters.
		rjmp done_right
	line2_right:
		cpi scroll_line2, 0
		breq wrap_line2_right
		dec scroll_line2  ; Decrement the scroll offset.
		rjmp done_right
	wrap_line2_right:
		mov scroll_line2, msg2_len  ; Wrap to the end of the string.
	done_right:
		rcall final_display  ; Update the LCD display.
	ret

; Interrupt service routine for Timer1.
timer1_interrupt:
	push r16
	cpi mode, 2  ; If mode is 2, do not scroll.
	breq done_interrupt
	cpi mode, 1  ; If mode is 1, scroll right.
	breq scrRight
	rcall scroll_left  ; Otherwise, scroll left.
	rjmp done_interrupt
	scrRight:
		rcall scroll_right  ; Scroll right.
	done_interrupt:
		pop r16
		reti

; Define the strings in program memory.
msg1_p: .db "Jasvin Kaur      ", 0
msg2_p: .db "CSC 230: Spring 2025", 0, 0

; Reserve space in data memory for the strings.
.dseg
msg1: .byte 200  ; Reserve 200 bytes for the first message.
msg2: .byte 200  ; Reserve 200 bytes for the second message.