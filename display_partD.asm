/*
 * display_partD.asm
 *
 *  Created: 3/17/2025 4:23:39 PM
 *   Author: jasvinkaur
 */
#define LCD_LIBONLY              ; Define LCD_LIBONLY to include only the LCD library.
.include "lcd.asm"               ; Include the LCD library for interfacing with the LCD.

.cseg                            ; Start of the code segment.

; Definitions for using the Analog to Digital Conversion (ADC) for button input.
.equ ADCSRA_BTN = 0x7A           ; ADC Control and Status Register A.
.equ ADCSRB_BTN = 0x7B           ; ADC Control and Status Register B.
.equ ADMUX_BTN = 0x7C            ; ADC Multiplexer Selection Register.
.equ ADCL_BTN = 0x78             ; ADC Data Register Low.
.equ ADCH_BTN = 0x79             ; ADC Data Register High.

; Button threshold values for ADC readings.
.equ RIGHT  = 0x032              ; ADC value for the RIGHT button.
.equ UP     = 0x0C3              ; ADC value for the UP button.
.equ DOWN   = 0x17C              ; ADC value for the DOWN button.
.equ LEFT   = 0x22B              ; ADC value for the LEFT button.
.equ SELECT = 0x316              ; ADC value for the SELECT button.

; Initialize the stack pointer.
    ldi r16, low(RAMEND)         ; Load the low byte of the end of RAM into r16.
    out SPL, r16                 ; Set the stack pointer low byte.
    ldi r16, high(RAMEND)        ; Load the high byte of the end of RAM into r16.
    out SPH, r16                 ; Set the stack pointer high byte.

    call lcd_init                ; Initialize the LCD.
    call lcd_clr                 ; Clear the LCD display.

    call initialize_adc          ; Initialize the ADC for button input.

; Main program loop.
loop:
    call check_button            ; Check for button input.

    cpi r24, 1                  ; Compare r24 with 1 (RIGHT button).
    breq disp_right             ; If equal, branch to disp_right.
    cpi r24, 2                  ; Compare r24 with 2 (UP button).
    breq disp_up                ; If equal, branch to disp_up.
    cpi r24, 3                  ; Compare r24 with 3 (DOWN button).
    breq disp_down              ; If equal, branch to disp_down.
    cpi r24, 4                  ; Compare r24 with 4 (LEFT button).
    breq disp_left              ; If equal, branch to disp_left.

    rjmp loop                   ; Repeat the loop.

; Display "Left" message on the LCD.
disp_left:
    call lcd_clr                ; Clear the LCD display.

    push r16                    ; Save r16 on the stack.

    ldi r16, high(left_msg << 1) ; Load the high byte of the left message address.
    push r16                    ; Push the high byte onto the stack.
    ldi r16, low(left_msg << 1)  ; Load the low byte of the left message address.
    push r16                    ; Push the low byte onto the stack.
    ldi r16, l_offset           ; Load the column offset for the message.
    push r16                    ; Push the offset onto the stack.
    ldi r16, l_row              ; Load the row for the message.
    push r16                    ; Push the row onto the stack.
    call display_message        ; Call the display_message function.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.

    ret                         ; Return from the function.

; Display "Right" message on the LCD.
disp_right:
    call lcd_clr                ; Clear the LCD display.

    push r16                    ; Save r16 on the stack.

    ldi r16, high(right_msg << 1) ; Load the high byte of the right message address.
    push r16                    ; Push the high byte onto the stack.
    ldi r16, low(right_msg << 1)  ; Load the low byte of the right message address.
    push r16                    ; Push the low byte onto the stack.
    ldi r16, r_offset           ; Load the column offset for the message.
    push r16                    ; Push the offset onto the stack.
    ldi r16, r_row              ; Load the row for the message.
    push r16                    ; Push the row onto the stack.
    call display_message        ; Call the display_message function.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.

    ret                         ; Return from the function.

; Display "Up" message on the LCD.
disp_up:
    call lcd_clr                ; Clear the LCD display.

    push r16                    ; Save r16 on the stack.

    ldi r16, high(up_msg << 1)  ; Load the high byte of the up message address.
    push r16                    ; Push the high byte onto the stack.
    ldi r16, low(up_msg << 1)   ; Load the low byte of the up message address.
    push r16                    ; Push the low byte onto the stack.
    ldi r16, u_offset           ; Load the column offset for the message.
    push r16                    ; Push the offset onto the stack.
    ldi r16, u_row              ; Load the row for the message.
    push r16                    ; Push the row onto the stack.
    call display_message        ; Call the display_message function.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.

    rjmp loop                   ; Jump back to the main loop.

; Display "Down" message on the LCD.
disp_down:
    call lcd_clr                ; Clear the LCD display.

    push r16                    ; Save r16 on the stack.

    ldi r16, high(down_msg << 1) ; Load the high byte of the down message address.
    push r16                    ; Push the high byte onto the stack.
    ldi r16, low(down_msg << 1)  ; Load the low byte of the down message address.
    push r16                    ; Push the low byte onto the stack.
    ldi r16, d_offset           ; Load the column offset for the message.
    push r16                    ; Push the offset onto the stack.
    ldi r16, d_row              ; Load the row for the message.
    push r16                    ; Push the row onto the stack.
    call display_message        ; Call the display_message function.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.
    pop r16                     ; Restore r16 from the stack.

    rjmp loop                   ; Jump back to the main loop.

; Initialize the ADC for button input.
initialize_adc:
    ldi r16, 0x87               ; Enable ADC and set prescaler to 128 (0x87 = 0b10000111).
    sts ADCSRA_BTN, r16         ; Store the value in ADCSRA_BTN.
    ldi r16, 0x00               ; Set ADCSRB_BTN to 0 (free-running mode).
    sts ADCSRB_BTN, r16         ; Store the value in ADCSRB_BTN.
    ldi r16, 0x40               ; Configure ADMUX_BTN (AVCC reference, right-adjust result, ADC0 channel).
    sts ADMUX_BTN, r16          ; Store the value in ADMUX_BTN.
    ret                         ; Return from the function.

; Check for button input and set r24 to the corresponding button value.
check_button:
    lds R16, ADCSRA_BTN         ; Load ADCSRA_BTN into R16.
    ori R16, 0x40               ; Set the ADSC bit to start an ADC conversion.
    sts ADCSRA_BTN, R16         ; Store the updated value in ADCSRA_BTN.

    wait:
        lds R16, ADCSRA_BTN     ; Load ADCSRA_BTN into R16.
        andi R16, 0x40          ; Check if the ADSC bit is still set.
        brne wait               ; If set, continue waiting.

    lds R24, ADCL_BTN           ; Load the low byte of the ADC result into R24.
    lds R25, ADCH_BTN           ; Load the high byte of the ADC result into R25.

    check_right:
        ldi R16, low(RIGHT)     ; Load the low byte of the RIGHT threshold into R16.
        ldi R17, high(RIGHT)    ; Load the high byte of the RIGHT threshold into R17.
        cp R24, R16             ; Compare the low byte of the ADC result with the RIGHT threshold.
        cpc R25, R17            ; Compare the high byte of the ADC result with the RIGHT threshold.
        brsh check_up           ; If greater than or equal, check for the UP button.
        ldi R24, 1              ; Set R24 to 1 (RIGHT button pressed).
        ret                     ; Return from the function.

    check_up:
        ldi R16, low(UP)        ; Load the low byte of the UP threshold into R16.
        ldi R17, high(UP)       ; Load the high byte of the UP threshold into R17.
        cp R24, R16             ; Compare the low byte of the ADC result with the UP threshold.
        cpc R25, R17            ; Compare the high byte of the ADC result with the UP threshold.
        brsh check_down         ; If greater than or equal, check for the DOWN button.
        ldi R24, 2              ; Set R24 to 2 (UP button pressed).
        ret                     ; Return from the function.

    check_down:
        ldi R16, low(DOWN)      ; Load the low byte of the DOWN threshold into R16.
        ldi R17, high(DOWN)     ; Load the high byte of the DOWN threshold into R17.
        cp R24, R16             ; Compare the low byte of the ADC result with the DOWN threshold.
        cpc R25, R17            ; Compare the high byte of the ADC result with the DOWN threshold.
        brsh check_left         ; If greater than or equal, check for the LEFT button.
        ldi R24, 3              ; Set R24 to 3 (DOWN button pressed).
        ret                     ; Return from the function.

    check_left:
        ldi R16, low(LEFT)      ; Load the low byte of the LEFT threshold into R16.
        ldi R17, high(LEFT)     ; Load the high byte of the LEFT threshold into R17.
        cp R24, R16             ; Compare the low byte of the ADC result with the LEFT threshold.
        cpc R25, R17            ; Compare the high byte of the ADC result with the LEFT threshold.
        brsh no_button          ; If greater than or equal, no button is pressed.
        ldi R24, 4              ; Set R24 to 4 (LEFT button pressed).
        ret                     ; Return from the function.

    no_button:
        clr R24                 ; Clear R24 (no button pressed).
        ret                     ; Return from the function.

; Display a message on the LCD.
display_message:
    in YL, SPL                  ; Load the stack pointer low byte into YL.
    in YH, SPH                  ; Load the stack pointer high byte into YH.
    clr R16                     ; Clear R16.
    ldd R16, Y+4                ; Load the row from the stack into R16.
    ldd R17, Y+5                ; Load the column offset from the stack into R17.
    ldd ZL, Y+6                 ; Load the low byte of the message address from the stack into ZL.
    ldd ZH, Y+7                 ; Load the high byte of the message address from the stack into ZH.

    lpm R18, Z                  ; Load the first character of the message into R18.

    push R16                    ; Push the row onto the stack.
    push R17                    ; Push the column offset onto the stack.
    call lcd_gotoxy             ; Move the cursor to the specified position.
    pop R17                     ; Restore R17 from the stack.
    pop R16                     ; Restore R16 from the stack.

    clr R16                     ; Clear R16.
    clr R22                     ; Clear R22.

    final_loop:
        lpm R21, Z              ; Load the next character of the message into R21.
        cpi R21, 0              ; Check if the character is the null terminator.
        breq return             ; If null, return from the function.
        push R21                ; Push the character onto the stack.
        call lcd_putchar        ; Display the character on the LCD.
        pop R21                 ; Restore R21 from the stack.
        adiw Z, 1               ; Increment the Z pointer to the next character.
        rjmp final_loop         ; Repeat the loop.

    return:
        jmp loop                ; Jump back to the main loop.
    ret                         ; Return from the function.

; Messages and positions
left_msg: .db "Left ", 0        ; Message for LEFT button press.
.equ l_row = 1                  ; Row for the LEFT message.
.equ l_offset = 0               ; Column offset for the LEFT message.

right_msg: .db "Right", 0       ; Message for RIGHT button press.
.equ r_row = 0                  ; Row for the RIGHT message.
.equ r_offset = 11              ; Column offset for the RIGHT message.

up_msg: .db "Up ", 0            ; Message for UP button press.
.equ u_row = 0                  ; Row for the UP message.
.equ u_offset = 0               ; Column offset for the UP message.

down_msg: .db "Down ", 0        ; Message for DOWN button press.
.equ d_row = 1                  ; Row for the DOWN message.
.equ d_offset = 11              ; Column offset for the DOWN message.