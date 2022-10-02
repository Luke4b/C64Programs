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
    sta length_hi
    sta tail_pointer_lo
    sta loopcount_lo
    sta loopcount_hi

    lda #$0b
    sta tail_pointer_hi

    lda #$01
    sta length_lo       // starting length
    lda #$09            //  default value for last key (to match default direction of up/$00)
    sta last_key

    // starting location
    lda #12             // $0C
    sta head_row
    lda #19             // $13
    sta head_column

    jsr clear_screen        // clear screen
    jsr spawn_food          // spawn initial piece of food

loop:

    lda tail_pointer_hi     // print tail pointer, problem occurs with this not looping back correctly.
    jsr PrintHexValue
    lda tail_pointer_lo
    jsr PrintHexValue2    

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
    clc

    lda length_lo   // add 1 to the length 
    adc #$01
    sta length_lo
    lda length_hi
    adc #$00
    sta length_hi        
    rts


draw:
    // draw head
    ldy #$00                
    lda #$41                // character to print
    sta (screen_lo),y       // draw the head at the screen address

    // add this head location to the path
    
    lda tail_pointer_hi
    pha
    lda tail_pointer_lo
    pha                     // backup the tail pointer address to the stack

    // add the length msb (which can be a value of 0-3) to the tail pointer msb
    // this alows indexing ahead by an extra page when length is above 255.
    clc
    lda tail_pointer_hi
    adc length_hi
    cmp #$0f                      // compare to end of path lsb
    bcs !wrap+                    // greater than or equal to then we need to wrap back around.
    sta tail_pointer_hi

    

    ldy length_lo
    lda screen_lo
    sta (tail_pointer_lo),y  // store the screen location lsb to the tail pointer address indexed with length
 
    clc                     // add 1024 ($0400) to the effective tail pointer
    lda tail_pointer_hi     // adjusted with length msb to address the path msb     
    adc #$04
    sta tail_pointer_hi

    lda screen_hi
    sta (tail_pointer_lo),y  // store the screen location msb to the +1024 tail pointer address

    pla
    sta tail_pointer_lo
    pla
    sta tail_pointer_hi     // pull the tail pointer address back from the stack



    // overdraw the tail, returns the tail to a blank space
    ldy #$00
    lda (tail_pointer_lo), y
    sta screen_lo                 // retrieve the screen location lsb from the path

    lda tail_pointer_hi
    pha
    lda tail_pointer_lo
    pha                     // push the tail pointer address to the stack

    clc                     // add 1024 ($0400) to the tail pointer to address the path msb
    lda tail_pointer_hi
    adc #$04
    sta tail_pointer_hi

    lda (tail_pointer_lo), y
    sta screen_hi           // store the screen location msb from the +1000 tail pointer address

    pla
    sta tail_pointer_lo
    pla
    sta tail_pointer_hi     // retrieve the tail pointer from the stack

    lda #$20                // blank space character
    sta (screen_lo),y       // store in screen location

    inc tail_pointer_lo
    rts

!wrap:          //if the msb is greater than or equal to $0f
    sbc #$04    //subtract 4 (so $0f becomes $0b again)    
    .break
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
    cmp #4              // lower bound
    bmi rand_row
    cmp #21             // upper bound  compare to see if is in range
    bcs rand_row        //if the number is too large, try again
    sta head_row
rand_col:               //generate a random number between 0-39 for column
    lda $D41B           //get random 8 bit (0 - 255) number from SID
    lsr                 //divide by 2 to give random number between 0 - 127
    lsr                 //divide by 2 to give random number between 0 - 63
    cmp #04             // lower bound
    bmi rand_col
    cmp #36             // upper bound  compare to see if is in range
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
    ldy #$3a
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

PrintHexValue:  ldx #$00
                pha
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

PrintHexValue2: ldx #$00
                pha
                lsr
                lsr
                lsr
                lsr
                jsr PrintHexNybble2
                pla
                and #$0f
PrintHexNybble2: cmp #$0a
                bcs PHN_IsLetter2
PHN_IsDigit2:    ora #$30
                bne PHN_Print2
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
loopcount_lo:     .byte 0
loopcount_hi:     .byte 0

* = $0b00
//path_hi: .fill 2000, 0
path_lo: .fill 1024, 0
path_hi: .fill 1024, 0