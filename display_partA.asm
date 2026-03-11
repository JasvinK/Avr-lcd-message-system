/*
 * display_partA.asm
 *
 *  Created: 3/13/2025 12:40:21 PM
 *   Author: jasvinkaur
 */

#define LCD_LIBONLY              ; Define LCD_LIBONLY to include only the LCD library.
.include "lcd.asm"               ; Include the LCD library for interfacing with the LCD.

.cseg                            ; Start of the code segment.

; Define constants for Timer3 configuration.
#define CLOCK 16.0e6             ; Clock frequency of the microcontroller (16 MHz).
#define DELAY1 1.0               ; Desired delay in seconds.

; Calculate the TOP value for Timer3.
.equ PRESCALE_DIV = 1024         ; Prescaler value for Timer3.
.equ TOP = int(0.5 + (CLOCK / PRESCALE_DIV * DELAY1))  ; Calculate TOP value for 1-second delay.
.if TOP > 65535                  ; Check if TOP exceeds the 16-bit range.
.error "TOP is out of range"     ; Throw an error if TOP is out of range.
.endif

; Initialize the stack pointer.
ldi r16, low(RAMEND)             ; Load the low byte of the end of RAM into r16.
out SPL, r16                     ; Set the stack pointer low byte.
ldi r16, high(RAMEND)            ; Load the high byte of the end of RAM into r16.
out SPH, r16                     ; Set the stack pointer high byte.

; Initialize Timer3 and the LCD.
rcall timer_init                 ; Call timer_init to configure Timer3.
rcall lcd_init                   ; Call lcd_init to initialize the LCD.
call init_strings                ; Call init_strings to load strings into data memory.

; Main program loop.
loop:
	rcall display_msg1           ; Display the first message on the LCD.
	rcall display_msg2           ; Display the second message on the LCD.
	rcall delay_1sec             ; Delay for 1 second.

	call lcd_clr                 ; Clear the LCD display.
	rcall display_msg1           ; Display the first message again.
	rcall delay_1sec             ; Delay for 1 second.

	call lcd_clr                 ; Clear the LCD display.
	rcall display_msg2           ; Display the second message again.
	rcall delay_1sec             ; Delay for 1 second.

	rjmp loop                    ; Repeat the loop indefinitely.

; Initialize Timer3 for a 1-second delay.
timer_init:
	ldi r16, high(TOP)           ; Load the high byte of the TOP value into r16.
	ldi r17, low(TOP)            ; Load the low byte of the TOP value into r17.
	sts OCR3AH, r16              ; Set the high byte of the OCR3A register.
	sts OCR3AL, r17              ; Set the low byte of the OCR3A register.
	ldi r16, 0                   ; Clear r16.
	sts TCCR3A, r16              ; Set TCCR3A to 0 (normal mode).
	ret                          ; Return from the function.

; Delay subroutine using Timer3.
delay_1sec:
	ldi r16, (1 << WGM32) | (1 << CS32) | (1 << CS30)  ; Configure Timer3 for CTC mode with prescaler 1024.
	sts TCCR3B, r16              ; Set TCCR3B.

	wait_timer:
		sbic TIFR3, OCF3A        ; Skip the next instruction if OCF3A (Output Compare Flag) is not set.
		rjmp done_timer          ; Jump to done_timer if OCF3A is set.

		rjmp wait_timer          ; Keep waiting for the timer to overflow.

	done_timer:
		sbi TIFR3, OCF3A         ; Clear OCF3A by writing a 1 to it.
		ret                      ; Return from the subroutine.

; Display the first message on the LCD.
display_msg1:
	push r16                     ; Save r16 on the stack.

	call lcd_clr                 ; Clear the LCD display.

	; Move the cursor to row 0, column 0.
	ldi r16, 0x00                ; Load row 0 into r16.
	push r16                     ; Push row onto the stack.
	ldi r16, 0x00                ; Load column 0 into r16.
	push r16                     ; Push column onto the stack.
	call lcd_gotoxy              ; Move the cursor to the specified position.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.

	; Display msg1 on the first line.
	ldi r16, high(msg1)          ; Load the high byte of msg1's address into r16.
	push r16                     ; Push the high byte onto the stack.
	ldi r16, low(msg1)           ; Load the low byte of msg1's address into r16.
	push r16                     ; Push the low byte onto the stack.
	call lcd_puts                ; Display the string on the LCD.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.

	pop r16                      ; Restore r16 from the stack.
	ret                          ; Return from the function.

; Display the second message on the LCD.
display_msg2:
	push r16                     ; Save r16 on the stack.

	; Move the cursor to row 1, column 0.
	ldi r16, 0x01                ; Load row 1 into r16.
	push r16                     ; Push row onto the stack.
	ldi r16, 0x00                ; Load column 0 into r16.
	push r16                     ; Push column onto the stack.
	call lcd_gotoxy              ; Move the cursor to the specified position.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.

	; Display msg2 on the second line.
	ldi r16, high(msg2)          ; Load the high byte of msg2's address into r16.
	push r16                     ; Push the high byte onto the stack.
	ldi r16, low(msg2)           ; Load the low byte of msg2's address into r16.
	push r16                     ; Push the low byte onto the stack.
	call lcd_puts                ; Display the string on the LCD.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.

	pop r16                      ; Restore r16 from the stack.
	ret                          ; Return from the function.

; Initialize strings by copying them from program memory to data memory.
init_strings:
	push r16                     ; Save r16 on the stack.

	; Copy msg1 from program memory to data memory.
	ldi r16, high(msg1)          ; Load the high byte of the destination address.
	push r16                     ; Push the high byte onto the stack.
	ldi r16, low(msg1)           ; Load the low byte of the destination address.
	push r16                     ; Push the low byte onto the stack.
	ldi r16, high(msg1_p << 1)   ; Load the high byte of the source address (program memory).
	push r16                     ; Push the high byte onto the stack.
	ldi r16, low(msg1_p << 1)    ; Load the low byte of the source address (program memory).
	push r16                     ; Push the low byte onto the stack.
	call str_init                ; Call str_init to copy the string.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.

	; Copy msg2 from program memory to data memory.
	ldi r16, high(msg2)          ; Load the high byte of the destination address.
	push r16                     ; Push the high byte onto the stack.
	ldi r16, low(msg2)           ; Load the low byte of the destination address.
	push r16                     ; Push the low byte onto the stack.
	ldi r16, high(msg2_p << 1)   ; Load the high byte of the source address (program memory).
	push r16                     ; Push the high byte onto the stack.
	ldi r16, low(msg2_p << 1)    ; Load the low byte of the source address (program memory).
	push r16                     ; Push the low byte onto the stack.
	call str_init                ; Call str_init to copy the string.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.
	pop r16                      ; Restore r16 from the stack.

	pop r16                      ; Restore r16 from the stack.
	ret                          ; Return from the function.

; Define strings in program memory.
msg1_p: .db "Jasvin Kaur", 0      ; First message to display.
msg2_p: .db "CSC 230: Spring 2025 ", 0  ; Second message to display.

; Reserve space in data memory for the strings.
.dseg
msg1: .byte 200                   ; Reserve 200 bytes for the first message.
msg2: .byte 200                   ; Reserve 200 bytes for the second message.