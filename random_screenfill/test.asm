BasicUpstart2(main)

* = $0810

.var screen_lo = $FC         // screen address low byte
.var screen_hi = $FD         // screen address high byte

main:
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low byte
    sta $D40F // voice 3 frequency high byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    jsr init
    jsr loop

init:
    jsr clear_screen        // clear screen

loop:
    jsr spawn_food          // check if there is food, if not spawn one, if food has been eaten increment length
    jsr delay               // run the delay loop to slow the game
    jmp loop

screen_address:     // finds the screen address for the coordinates in head_row / head_column
    lda #$00            // re-initialise screen address to top left corner
    sta screen_lo
    lda #$04
    sta screen_hi
    ldx head_row        // set row coordinate as x for loop counter.
    beq add_columns     // if row zero skip straight to column.
add_rows_loop:          // add rows
    lda #40             // add a row (40 characters)
    clc
    adc screen_lo      
    sta screen_lo
    lda #$00            // load zero (carry should still be set)
    adc screen_hi       // add the carry if it exists
    sta screen_hi
    dex
    bne add_rows_loop
add_columns:
    lda head_column
    clc
    adc screen_lo
    sta screen_lo
    lda #$00            // load zero (carry should still be set)
    adc screen_hi
    sta screen_hi
    rts


spawn_food:              // spawns a food in a random location
rand_row:
    lda $D41B           //get random 8 bit (0 - 255) number from SID
    lsr                 //divide by 2 to give random number between 0 - 127
    lsr                 //divide by 2 to give random number between 0 - 63
    lsr                 //divide by 2 to give random number between 0 - 31
    cmp #25             //compare to see if is in range
    bcs rand_row        //if the number is too large, try again
    sta head_row
rand_col:               //generate a random number between 0-39 for column
    lda $D41B           //get random 8 bit (0 - 255) number from SID
    lsr                 //divide by 2 to give random number between 0 - 127
    lsr                 //divide by 2 to give random number between 0 - 63
    cmp #40             //compare to see if is in range
    bcs rand_col        //if the number is too large, try again
    sta head_column
    jsr screen_address
    ldy #$00           
    lda (screen_lo),y   // load screen position
    cmp #$20            // see if it's a suitably blank location
    bne rand_row        // if it's not blank try again!!
    lda #$06            // character 'F'
    sta (screen_lo),y   // spawn food
!skip:
    rts
  

delay:
    txa
    pha
    tya
    pha
    ldx #$FF
    ldy #$04
delay_loop:
    dex
    bne delay_loop
    dey
    bne delay_loop
    pla
    tay
    pla
    tax
    rts

clear_screen:   // fill screen with space characters $0400 - $07FF
    ldx #$00
    lda #$20    // space character
cls_loop:
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    dex
    bne cls_loop
    rts

head_row:         .byte 0   // y-coordinate, zero being top
head_column:      .byte 0   // x-coordinate, zero being left