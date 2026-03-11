/*
 * display_partB.asm
 *
 *  Created: 3/14/2025 4:22:57 PM
 *   Author: jasvinkaur
 */ 

; This program initializes an LCD display and scrolls two lines of text (msg1 and msg2) 
; on the LCD using Timer1 interrupts. The text wraps around if it exceeds the display width.

.cseg
.org 0
    jmp start             ; Reset vector: Jump to the start of the program on reset.
.org 0x22
	jmp timer1_interrupt  ; Timer1 interrupt vector: Jump to the ISR when Timer1 overflows.

.include "lcd.asm"        ; Include the LCD library for interfacing with the LCD.
.cseg

#define DELAY 0.5           ; Delay in seconds for the Timer1 interrupt.
#define WRAP_SEPARATOR ' '  ; Character used as a separator when wrapping text.
.def scroll_line1=r22     ; Register to store the scroll offset for the first line.
.def scroll_line2=r23     ; Register to store the scroll offset for the second line.
.def msg1_len=r24         ; Register to store the length of the first message.
.def msg2_len=r25         ; Register to store the length of the second message.

#define CLOCK 16.0e6      ; Clock frequency of the microcontroller.
.equ PRESCALE_DIV=1024    ; Prescaler value for Timer1.
.equ TOP=int(0.5+(CLOCK/PRESCALE_DIV*DELAY))  ; Calculate the TOP value for Timer1.
.if TOP>65535              ; Check if the TOP value is within the 16-bit range.
.error "TOP is out of range"  ; Throw an error if TOP exceeds the range.
.endif

start:
	clr scroll_line1  ; Clear the scroll offset for the first line.
	clr scroll_line2  ; Clear the scroll offset for the second line.
    rcall lcd_init    ; Initialize the LCD.
	rcall init_strings  ; Copy strings from flash memory to data memory.
	rcall lengths  ; Compute the lengths of the two strings.
	rcall final_display  ; Display the initial state of the LCD.
	rcall initialize_timer1  ; Configure Timer1 for scrolling.

end: jmp end  ; Infinite loop to keep the program running.

; Initialize strings by copying them from program memory to data memory.
init_strings:
	push r16
	; Copy msg1 from program memory to data memory.
	ldi r16, high(msg1)  ; Load the high byte of the destination address.
	push r16
	ldi r16, low(msg1)  ; Load the low byte of the destination address.
	push r16
	ldi r16, high(msg1_p << 1)  ; Load the high byte of the source address (program memory).
	push r16
	ldi r16, low(msg1_p << 1)  ; Load the low byte of the source address (program memory).
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

; Counts the number of characters in a string pointed to by the Z register pair.
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

	; Check and truncate msg1 if it exceeds 16 characters.
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

	; Display the first line of text.
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

	; Display the second line of text.
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
	ldi r17, high(TOP)  ; Load the high byte of the TOP value.
	ldi r16, low(TOP)  ; Load the low byte of the TOP value.
	sts OCR1AH, r17  ; Set the high byte of the compare register.
	sts OCR1AL, r16  ; Set the low byte of the compare register.

	; Configure Timer1 for CTC mode with a prescaler of 1024.
	ldi r16, 0
	sts TCCR1A, r16  ; Set Timer1 control register A to 0.

	ldi r16, (1 << WGM12) | (1 << CS12) | (1 << CS10)  ; Set Timer1 control register B.
	sts TCCR1B, r16
	ldi r16, (1 << OCIE1A)  ; Enable Timer1 compare interrupt.
	sts TIMSK1, r16
	sei  ; Enable global interrupts.

	pop r17
	pop r16
	ret

; Clear the LCD and display the current state of the scrolling lines.
final_display:
	rcall lcd_clr  ; Clear the LCD.
	rcall scrolling_line1  ; Display the first scrolling line.
	rcall scrolling_line2  ; Display the second scrolling line.
	ret

; Interrupt service routine for Timer1.
timer1_interrupt:
	cpi msg1_len, 17  ; Check if the first message is longer than 16 characters.
	brsh line1  ; If so, scroll the first line.
	rjmp continue  ; Otherwise, skip scrolling.
	line1:
		cp scroll_line1, msg1_len  ; Check if the scroll offset has reached the end of the message.
		brsh wrap_line1  ; If so, wrap to the beginning.
		inc scroll_line1  ; Otherwise, increment the scroll offset.
		rjmp continue  ; Continue to the second line.
	wrap_line1:
		ldi scroll_line1, 0  ; Reset the scroll offset for the first line.
	continue:
		cpi msg2_len, 17  ; Check if the second message is longer than 16 characters.
		brsh line2  ; If so, scroll the second line.
		rjmp done_interrupt  ; Otherwise, skip scrolling.
	line2:
		cp scroll_line2, msg2_len  ; Check if the scroll offset has reached the end of the message.
		brsh wrap_line2  ; If so, wrap to the beginning.
		inc scroll_line2  ; Otherwise, increment the scroll offset.
		rjmp done_interrupt  ; Exit the ISR.
	wrap_line2:
		ldi scroll_line2, 0  ; Reset the scroll offset for the second line.
	done_interrupt:
		rcall final_display  ; Update the LCD display.
		reti  ; Return from the interrupt.

; Define the strings in program memory.
msg1_p: .db "Jasvin Kaur      ", 0  ; First message with padding.
msg2_p: .db "CSC 230: Spring 2025", 0, 0  ; Second message with padding.

; Reserve space in data memory for the strings.
.dseg
msg1: .byte 200  ; Reserve 200 bytes for the first message.
msg2: .byte 200  ; Reserve 200 bytes for the second message.
