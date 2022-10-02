BasicUpstart2(main)

* = $0810

//.var unused = $FA           // unused zero page location
.var last_key = $FB           // last key pressed
.var screen_lsb = $FC         // screen address low byte
.var screen_msb = $FD         // screen address high byte
.var head_pointer_lsb = $FE   // tail pointer low byte
.var head_pointer_msb = $FF   // tail pointer high byte

.var food_char = $41    // character to be used for food.

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
    sta length_msb
    sta head_pointer_lsb
    sta loopcount_lo
    sta loopcount_hi

    lda #$0b
    sta head_pointer_msb

    lda #$01
    sta length_lsb       // starting length

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
    lda length_msb
    jsr PrintHexValue
    lda length_lsb
    jsr PrintHexValue2    

    jsr read_keyb           // read last keypress, ignore if invalid
    jsr step                // set direction, update head coordinate, reset if AOB
    jsr screen_address      // look up the screen address from coordinates
    jsr collision_check     // check if snake has collided with itself or food
    jsr draw                // draw the snake
    jsr spawn_food          // check if there is food, if not spawn one, if food has been eaten increment length
    jsr delay               // run the delay loop to slow the game
    jmp loop

read_keyb:          // reads keyboard input
    ldx $c5         // read keyboard buffer
    lda direction   
    and #$00000001  // if direction is $01 or $03 then it's horizontal, AND gives 1 otherwise vertical, AND gives 0
    bne !horiz+
    // not horizontal so direction must be vertical
    txa
    cmp #$12
    beq update_key
    cmp #$0A
    beq update_key
    rts
!horiz:
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
    lda direction 
    sta prev_dir     // store the direction from the previous loop
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
    tsx
    inx
    inx
    txs
    jmp init

screen_address:         // finds the screen address for the coordinates in head_row / head_column
    lda #$00            // re-initialise screen address to top left corner
    sta screen_lsb
    lda #$04
    sta screen_msb
    ldx head_row        // set row coordinate as x for loop counter.
    beq add_columns     // if row zero skip straight to column.
add_rows_loop:          // add rows
    lda #40             // add a row (40 characters)
    clc
    adc screen_lsb      
    sta screen_lsb
    lda #$00            // load zero (carry should still be set)
    adc screen_msb       // add the carry if it exists
    sta screen_msb
    dex
    bne add_rows_loop
add_columns:
    lda head_column
    clc
    adc screen_lsb
    sta screen_lsb
    lda #$00            // load zero (carry should still be set)
    adc screen_msb
    sta screen_msb
    rts

collision_check:
    ldy #$00
    lda (screen_lsb),y         // load head position in screen ram
    cmp #food_char              // check if that has food character
    beq fed
    cmp #$20
    bne reset
    rts
fed:
    lda #$00
    sta food_flag        // set food flag to 00 (no food)
    clc

    lda length_lsb   // add 1 to the length 
    adc #$01
    sta length_lsb
    lda length_msb
    adc #$00
    sta length_msb        
    rts


draw:
    // draw head
    ldy #$00                    
    jsr which_char
    sta (screen_lsb),y       // draw the head at the screen address

    // add head screen location to path
    lda screen_lsb
    sta (head_pointer_lsb), y

    lda head_pointer_msb
    pha                         // temporarily push the head pointer to the stack
    clc
    adc #$04                    // add 1024 ($0400) to point at the path msb
    sta head_pointer_msb
    lda screen_msb
    sta (head_pointer_lsb),y
    pla                         // retrieve head pointer from the stack
    sta head_pointer_msb

    // overwrite the tail
    lda head_pointer_msb        // temporarily push the head pointers to the stack so
    pha                         // so they can instead be used to hold the pointer to the tail
    lda head_pointer_lsb
    pha

    sec                         // subtract the snake's length to get to the tail.
    sbc length_lsb
    sta head_pointer_lsb
    lda head_pointer_msb
    sbc length_msb
    sta head_pointer_msb
    cmp #$0b                    // check if this falls out the bottom of the path space
    bcs !+                      // and if so wrap around.
    adc #$04
    sta head_pointer_msb
!: 

    ldy #$00                    // retrieve the screen location from the path and write 
    lda (head_pointer_lsb), y   // a blank space character to that location.
    sta screen_lsb
    clc
    lda head_pointer_msb
    adc #$04
    sta head_pointer_msb
    lda (head_pointer_lsb), y
    sta screen_msb
    lda #$20
    sta (screen_lsb), y
    
    pla                         // retrieve the head points from the stack
    sta head_pointer_lsb
    pla
    sta head_pointer_msb


    // increment head_pointer
    clc
    lda head_pointer_lsb
    adc #$01
    sta head_pointer_lsb
    lda head_pointer_msb
    adc #$00
    sta head_pointer_msb
    cmp #$0f                    // check if the path pointer should be wrapped back around.
    beq !+
    rts
!:  lda #$0b
    sta head_pointer_msb
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
    lda (screen_lsb),y  // load screen position
    cmp #$20            // see if it's a suitably blank location
    bne rand_row        // if it's not blank try again!!
    lda #food_char       // food character
    sta (screen_lsb),y  // spawn food
    lda #$01
    sta food_flag       // set the food flag to 01 (there is food)
    pla
    sta head_column     // put the head column back
    pla
    sta head_row        // put the head row back
!skip:
    rts
  
which_char:             // works out which character needs to be drawn, puts it in the a register.
    lda direction
    and #$00000001
    bne !horiz+
    lda #$5d
    rts
!horiz:
    lda #$43
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

food_flag:          .byte 0   // 1 if there is food currently on the board otherwise 0
direction:          .byte 0
prev_dir:           .byte 0
head_row:           .byte 0   // y-coordinate, zero being top
head_column:        .byte 0   // x-coordinate, zero being left
length_lsb:         .byte 0   // snake length low byte
length_msb:         .byte 0   // snake length high byte
loopcount_lo:       .byte 0
loopcount_hi:       .byte 0

* = $0b00
path_lo: .fill 1024, 0
path_hi: .fill 1024, 0