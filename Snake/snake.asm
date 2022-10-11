BasicUpstart2(main)

* = $0810

//.var unused = $FA           // unused zero page location
.var last_key = $FB           // last key pressed
.var screen_lsb = $FC         // screen address low byte
.var screen_msb = $FD         // screen address high byte
.var head_pointer_lsb = $FE   // head pointer low byte
.var head_pointer_msb = $FF   // head pointer high byte

// head_path_pointer might be a better name?
// add additional memory location for temp msb and lsb so the pointer 
// (and also head_row, head_column) don't have to keep being backed up to the stack.

.var bg_colour = $00    // background colour
.var brd_colour = $0b   // border colour
.var food_char = $07    // character to be used for food.

main:
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low byte
    sta $D40F // voice 3 frequency high byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    lda #bg_colour      // set background colour
    sta $d021
    lda #brd_colour
    sta $d020
    jmp start_game

start_game:
    lda $D018 // set character memory to start from ram at $3000
    ora #$0c
    sta $d018
    //  initiate variables to zero
    lda #$00
    sta direction
    sta food_flag
    sta length_msb
    sta head_pointer_lsb

    lda #$00
    sta speed_setting

    lda #$0c
    sta head_pointer_msb

    lda #$0e
    sta snake_colour

    lda #$02
    sta length_lsb       // starting length

    lda #$09            //  default value for last key (to match default direction of up/$00)
    sta last_key

    // starting location in approximately screen centre
    lda #12             // $0C
    sta head_row
    lda #19             // $13
    sta head_column

    jsr clear_screen        // clear screen
    jsr spawn_food          // spawn initial piece of food

loop:
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
    jmp main

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
    cmp #$00
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
    lda food_colour
    sta snake_colour
    rts

draw:
    // draw head
    lda #$0c
    clc
    adc direction
    ldy #$00
    sta (screen_lsb),y

    lda screen_msb
    pha
    adc #$d4                    // move msb up to address colour ram
    sta screen_msb
    lda snake_colour
    sta (screen_lsb),y
    pla
    sta screen_msb

    // add this new head screen location and direction to the path
    lda screen_lsb
    sta (head_pointer_lsb), y

    lda head_pointer_msb
    pha                         // temporarily push the head pointer to the stack

    clc
    adc #$04                    // add 1024 ($0400) to point at the path msb
    sta head_pointer_msb
    lda screen_msb
    sta (head_pointer_lsb),y

    lda head_pointer_msb
    clc
    adc #$04                    // add another 1024 ($0400) to point at the path direction
    sta head_pointer_msb
    lda direction
    sta (head_pointer_lsb),y
    
    pla                         // retrieve head pointer from the stack
    sta head_pointer_msb

    // redraw body behind head
    lda #$01                    // load the path_offset with a vlue one 1 for the space behind the head.
    sta path_offset + 0
    lda #$00
    sta path_offset + 1

    jsr path_lookup                // look up the screen location behind the head from the path
    jsr body_char                  // look up what character to draw based on the previous direction, puts in 'a' reg
    ldy #$00
    sta (screen_lsb),y

    // draw the tail
    sec
    lda length_lsb                 // subtract 1 from the length to find the tail space 
    sbc #$01
    sta path_offset + 0
    lda length_msb
    sbc #$00
    sta path_offset + 1

    jsr path_lookup
    lda #$08
    clc
    adc tail_direction
    ldy #$00
    sta (screen_lsb),y    

    // remove the old tail (overwrite with a blank space)
    lda length_lsb
    sta path_offset + 0
    lda length_msb
    sta path_offset + 1

    jsr path_lookup
    ldy #$00
    lda #$00
    sta (screen_lsb),y

    // increment head_pointer
    clc
    lda head_pointer_lsb
    adc #$01
    sta head_pointer_lsb
    lda head_pointer_msb
    adc #$00
    sta head_pointer_msb
    cmp #$10                    // check if the path pointer should be wrapped back around.
    beq !+
    rts
!:  lda #$0c
    sta head_pointer_msb
    rts

    // looks up the screen location from the path_offset and places
    // it in the screen_msb / lsb locations
    // takes care of wrapping around when decrementing the head_pointer
    // to stay within the valid memory space.
    // restores the head_pointer afterwards.
path_lookup:
    lda head_pointer_msb        // backup head pointer to stack
    pha
    lda head_pointer_lsb
    pha

    sec                         // subtract the path_offset
    sbc path_offset + 0
    sta head_pointer_lsb
    lda head_pointer_msb
    sbc path_offset + 1
    sta head_pointer_msb
    cmp #$0c                    // check if this falls out the bottom of the path space
    bcs !+                      // and if so wrap around.
    adc #$04
    sta head_pointer_msb

!:  ldy #$00                    // retrieve the screen location from the path
    lda (head_pointer_lsb), y
    sta screen_lsb
    clc
    lda head_pointer_msb
    adc #$04
    sta head_pointer_msb
    lda (head_pointer_lsb), y
    sta screen_msb
    clc
    ldy #$01
    lda head_pointer_msb
    adc #$04
    sta head_pointer_msb
    lda (head_pointer_lsb), y
    sta tail_direction
        
    pla
    sta head_pointer_lsb        // restore head pointer from stack
    pla
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
    lda $D41B           // get random 8 bit (0 - 255) number from SID
    and #%00011111      // mask to 5 bit (0-31)
    cmp #3              // lower bound
    bmi rand_row
    cmp #24             // upper bound  compare to see if is in range
    bcs rand_row        // if the number is too large, try again
    sta head_row
rand_col:               // generate a random number between 0-39 for column
    lda $D41B           // get random 8 bit (0 - 255) number from SID
    and #$00111111      // mask to 6 bit (0 - 63)
    cmp #03             // lower bound
    bmi rand_col
    cmp #37             // upper bound  compare to see if is in range
    bcs rand_col        // if the number is too large, try again
    sta head_column
    jsr screen_address
    ldy #$00           
    lda (screen_lsb),y  // load screen position
    cmp #$00            // see if it's a suitably blank location
    bne rand_row        // if it's not blank try again!!

!:  lda $D41B
    and #%00001111
    cmp #bg_colour      // check this isn't the same as the background colour
    beq !-              // if it is, try again
    sta food_colour
    lda screen_msb      // backup msb to stack
    pha
    clc
    adc #$d4            // to address color ram
    sta screen_msb
    lda food_colour
    sta (screen_lsb),y
    pla
    sta screen_msb      // restore msb

    lda #food_char      // food character
    sta (screen_lsb),y  // spawn food
    lda #$01
    sta food_flag       // set the food flag to 01 (there is food)
    pla
    sta head_column     // put the head column back
    pla
    sta head_row        // put the head row back
!skip:
    rts
  
body_char:             // works out which corner character needs to be drawn, puts it in the 'a' register.
    lda direction
    cmp prev_dir
    bne !corner+             // if the previous direction was different proceed to corner logic
    and #%00000001
    bne !horiz+
    lda #$01
    rts
!horiz:
    lda #$02
    rts
!corner:  cmp #$00
    beq !up+
    cmp #$01
    beq !right+
    cmp #$02
    beq !down+
    lda prev_dir
    cmp #$00
    bne !+
    lda #$03            // ne_corner character
    rts
!:  lda #$05            // se_corner character
    rts
!up:
    lda prev_dir
    cmp #$01
    bne !+
    lda #$05            // se_corner character
    rts
!:  lda #$06            // sw_corner character
    rts
!right:
    lda prev_dir
    cmp #$00
    bne !+  
    lda #$04            // nw_corner character
    rts
!:  lda #$06            // sw_corner character
    rts
!down:
    lda prev_dir
    cmp #$01
    bne !+
    lda #$03            // ne_corner character
    rts
!:  lda #$04            // nw_corner character
    rts

delay:
    txa                 // backup x
    pha
    tya                 // backup y
    pha
    ldx #$FF
    lda speed_setting   // load speed setting
    cmp #$01
    beq med_speed
    bcs high_speed
    ldy #$55
delay_loop:
    dex
    bne delay_loop
    dey
    bne delay_loop
    pla
    tay                 // restore y
    pla
    tax                 // restore x
    rts
med_speed:
    ldy #$3a
    jmp delay_loop
high_speed:
    ldy #$20
    jmp delay_loop


clear_screen:   // fill screen with space characters $0400 - $07FF
    ldx #$00
    lda #$00    // space character
cls_loop:
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    dex
    bne cls_loop
    rts

food_flag:          .byte 0      // 1 if there is food currently on the board otherwise 0
direction:          .byte 0
prev_dir:           .byte 0
head_row:           .byte 0      // y-coordinate, zero being top
head_column:        .byte 0      // x-coordinate, zero being left
length_lsb:         .byte 0      // snake length low byte
length_msb:         .byte 0      // snake length high byte
path_offset:        .word $0000  // 16 bit offset to be applied when looking up screen locations from the path.
tail_direction:     .byte 0
snake_colour:       .byte 0
food_colour:        .byte 0
speed_setting:      .byte 0

screen_table:   .lohifill 25, $0400 + [i * 40]     // table of the memory locations for the first column in each row

* = $0c00
path_lo:  .fill 1024, 0
path_hi:  .fill 1024, 0
path_dir: .fill 1024, 0

*=$3000
blank_spc: .fill 8, $00                                 //$3000     char $00
verti_bod: .fill 8, $7e                                 //$3008     char $01
horiz_bod: .byte $00, $ff, $ff, $ff, $ff, $ff, $ff, $00 //$3010     char $02
ne_corner: .byte $00, $f0, $f8, $fc, $fe, $fe, $fe, $7e //$3018     char $03
nw_corner: .byte $00, $0f, $1f, $3f, $7f, $7f, $7f, $7e //$3020     char $04
se_corner: .byte $7e, $fe, $fe, $fe, $fc, $f8, $f0, $00 //$3028     char $05
sw_corner: .byte $7e, $7f, $7f, $7f, $3f, $1f, $0f, $00 //$3030     char $06
food:      .byte $00, $3c, $42, $42, $42, $42, $3c, $00 //$3038     char $07
tail_up:   .byte $7e, $7e, $3c, $3c, $3c, $18, $18, $18 //$3040     char $08
tail_rght: .byte $00, $02, $1f, $ff, $ff, $1f, $02, $00 //$3048     char $09
tail_down: .byte $18, $18, $18, $3c, $3c, $3c, $7e, $7e //$3050     char $0a
tail_left: .byte $00, $c0, $f8, $ff, $ff, $f8, $c0, $00 //$3058     char $0b
head_up:   .byte $18, $3c, $7e, $bd, $bd, $ff, $ff, $7e //$3060     char $0c
head_rght: .byte $78, $e4, $fe, $ff, $ff, $fe, $e4, $78 //$3068     char $0d
head_down: .byte $7e, $ef, $ef, $bd, $bd, $7e, $3c, $18 //$3070     char $0e
head_left: .byte $1e, $27, $7f, $ff, $ff, $7f, $27, $1e //$3078     char $0f
