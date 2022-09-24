BasicUpstart2(main)

* = $0810

.var direction = $FA         // 0 = up then clockwise to 3
.var last_key = $FB          // last key pressed
.var screen_lo = $FC         // screen address low byte
.var screen_hi = $FD         // screen address high byte
.var tail_pointer_lo = $FE   // tail pointer low byte
.var tail_pointer_hi = $FF   // tail pointer high byte


main:
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low byte
    sta $D40F // voice 3 frequency high byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    jsr init
    jsr loop

init:
    //  initiate variables to zero
    lda #$00
    sta direction
    sta food_flag
    sta reset_flag
    sta length_lo
    sta length_hi
    sta tail_pointer_lo

    lda #$0b
    sta tail_pointer_hi

    //  default value for last key (to match default direction of up/$00)
    lda #$09
    sta last_key

    // starting location
    lda #12             // $0C
    sta head_row
    lda #19             // $13
    sta head_column

    // add initial tail location to the path, on the first step it moves up from this position.
    jsr screen_address      // look up the screen address
    ldy #$00
    lda screen_lo           // load screen location low byte
    sta (tail_pointer_lo),y // store the low byte of the tail's screen location to the path
    ldy #$01
    lda screen_hi           // load screen location high byte
    sta (tail_pointer_lo),y // store the high byte of the tail's screen location to the path

    jsr clear_screen

loop:
    jsr read_keyb           // read last keypress, ignore if invalid
    jsr step                // set direction, update head coordinate, reset if AOB
    jsr screen_address      // look up the screen address from coordinates
    jsr collision_check     // check if snake has collided with itself or food

    lda reset_flag      // check if a reset has been triggered and if so re-initiliase the game
    beq continue
    jmp init

continue:
    jsr draw                // draw the snake
    jsr spawn_food          // check if there is food, if not spawn one, if food has been eaten increment length
    jsr delay               // run the delay loop to slow the game
    jmp loop

read_keyb:          // reads keyboard input
    ldx $c5         // read keyboard buffer
    lda direction   
    and #$00000001  // if direction is $01 or $03 then it's horizontal, AND gives 1 otherwise vertical, AND gives 0
    bne horiz
    // not horizontal so direction must be vertical
    txa
    cmp #$12
    beq update_key
    cmp #$0A
    beq update_key
    rts
horiz:
    txa
    cmp #$09
    beq update_key
    cmp #$0D
    beq update_key
    rts
update_key:
    sta last_key
    rts


step:
    lda last_key
    cmp #$09  // 'w' = up
    beq !up+
    cmp #$12  // 'd' = right
    beq !right+
    cmp #$0D  // 's' = down
    beq !down+
    cmp #$0A  // 'a' = left
    beq !left+
    rts
!up:
    lda #$00
    sta direction
    dec head_row // decrement row
    lda head_row
    bmi reset
    rts
!right:
    lda #$01
    sta direction
    inc head_column // increment column
    lda head_column
    cmp #40
    beq reset
    rts
!down:
    lda #$02
    sta direction
    inc head_row // increment row
    lda head_row
    cmp #25
    beq reset
    rts
!left:
    lda #$03
    sta direction
    dec head_column // decrement column
    lda head_column
    bmi reset
    rts

reset:
    lda #$01
    sta reset_flag
    rts

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

collision_check:
    ldy #$00
    lda (screen_lo),y    // load head position in screen ram
    cmp #$06             // check if that has food, character 'F'
    beq fed
    cmp #$20
    bne reset
    rts
fed:
    lda #$00
    sta food_flag        // set food flag to 00 (no food)
    rts


draw:
    // draw head
    ldy #$00                // load the column into y to be used as offset from row address
    lda #$41                // character to print
    sta (screen_lo),y       // draw the head at the row address with the column offset

    // add this head location to the path
    ldy #$02                // index to the next path location
    lda screen_lo           
    sta (tail_pointer_lo),y // store the low byte of the tail's screen location to the path
    ldy #$03
    lda screen_hi
    sta (tail_pointer_lo),y // store the high byte of the tail's screen location to the path


    
    // overdraw the tail, returns the tail to a blank space
    ldy #$00                
    lda (tail_pointer_lo),y // load the tail pointer low byte
    sta screen_lo           // store in the screen location low byte
    ldy #$01                
    lda (tail_pointer_lo),y // load the tail pointer high byte (next value in the path data)
    sta screen_hi           // store in the screen location high byte
    ldy #$00
    lda #$20               // blank space character
    sta (screen_lo),y       // store in screen location

    // debug screen location
    lda screen_hi           
    jsr PrintHexValue
    lda screen_lo
    jsr PrintHexValue2

    inc tail_pointer_lo     // increment the tail_pointer twice!
    inc tail_pointer_lo
    beq tail_pointer_wrap   // if the low byte of the tail pointer has gone to zero, jump to incrementing the high byte
    rts
tail_pointer_wrap:          // increment the high byte 
    inc tail_pointer_hi     // no check here for if it fits within the bounds of the path data, not needed because the snake can't get that big
    rts



spawn_food:              // spawns a food in a random location
    lda food_flag        // load food flag
    bne !skip+           // if the food flag is set, there is already food, skip spawning.

    //temporarily backup the snakes head row to the stack so the screen_row_address routine can be used again
    lda head_row
    pha
    lda head_column
    pha
    
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
    lda #$01
    sta food_flag       // set the food flag to 01 (there is food)
    pla
    sta head_column     // put the head column back
    pla
    sta head_row        // put the head row back
!skip:
    rts
  

delay:
    txa
    pha
    tya
    pha
    ldx #$FF
    ldy #$60
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

PrintHexValue:  pha
                lsr
                lsr
                lsr
                lsr
                jsr PrintHexNybble
                pla
                and #$0f
PrintHexNybble: cmp #$0a
                bcs PHN_IsLetter
PHN_IsDigit:    ora #$30
                bne PHN_Print
PHN_IsLetter:   sbc #$09
PHN_Print:      sta $0400,x
                inx
                rts

PrintHexValue2:  pha
                lsr
                lsr
                lsr
                lsr
                jsr PrintHexNybble2
                pla
                and #$0f
PrintHexNybble2: cmp #$0a
                bcs PHN_IsLetter
PHN_IsDigit2:    ora #$30
                bne PHN_Print
PHN_IsLetter2:   sbc #$09
PHN_Print2:      sta $0403,x
                inx
                rts



food_flag:        .byte 0   // 1 if there is food currently on the board otherwise 0
reset_flag:       .byte 0   // 1 if the game should reset
head_row:         .byte 0   // y-coordinate, zero being top
head_column:      .byte 0   // x-coordinate, zero being left
length_lo:        .byte 0   // snake length low byte
length_hi:        .byte 0   // snake length high byte

* = $0b00
path_hi: .fill 2048, 0