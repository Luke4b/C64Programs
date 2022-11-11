BasicUpstart2(main)

* = $0810 "program"

.var tmp_lsb = $FA              //
.var tmp_msb = $FB              // 
.label screen_lsb = $FC         // screen address low .byte
.label screen_msb = $FD         // screen address high .byte
.label head_path_pointer_lsb = $FE   // head pointer low .byte
.label head_path_pointer_msb = $FF   // head pointer high .byte

.label bg_colour = $00    // background colour
.label brd_colour = $0b   // border colour
.label food_char = $3f    // character to be used for food.

.label random = $D41B       // address of random numbers from SID
.label width = 40          // maximum 40 must be even number
.label height = 24         // maximum 24 must be even number
.label screen = $0400

.label the_row = head_row           //reused these variables during mazegen
.label the_column = head_column    
.label tmprow = length_lsb
.label tmpcol = length_msb
.label colour = snake_colour
.label adjacency_length = tail_direction
.label temp = prev_dir
.label temp2 = adjacency_length

#import "cycle.asm"

main:
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low .byte
    sta $D40F // voice 3 frequency high .byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    lda $d016           // set multicolour speed_setting
    ora #%00010000
    sta $d016

    lda $D018           // set character memory to start from ram at $3000
    ora #$0c
    sta $d018

    lda #brd_colour     // set border colour
    sta $d020
    lda #bg_colour      // set background colour
    sta $d021
    lda #$04            // bg colour #1, stripes, start with magenta
    sta $d022
    lda #$0b            // bg colour #2, dark grey for shadow
    sta $d023


    jsr menu

menu: {
    lda #$00
    sta mode

    ldx #$00
!:  lda menu_data, x
    sta screen, x
    lda menu_data + $100, x
    sta screen + $100, x
    lda menu_data + $200, x
    sta screen + $200, x
    lda menu_data + $300, x
    sta screen + $300, x
    lda #WHITE
    sta screen + $d400, x
    sta screen + $d500, x
    sta screen + $d600, x
    sta screen + $d700, x
    dex
    bne !-
}

await_input:
!:  lda $cb
    cmp #$0a  // A key
    beq auto
    cmp #$38  // 1 key
    beq slow
    cmp #$3b  // 2 key
    beq medium
    cmp #$08  // 3 key
    beq fast
    jmp !-
auto:   
        jsr maze_gen        // generate new hamiltonian path
        lda #$01            
        sta mode            // set auto mode flag
        lda #$03            // set to super speed
        jmp !+
slow:   lda #$00
        jmp !+
medium: lda #$01
        jmp !+
fast:   lda #$02
!:  sta speed_setting

game: {
    //  initiate variables
    lda #$00
    sta direction
    sta food_flag
    sta length_msb


    lda #<path_lo
    sta head_path_pointer_lsb
    lda #>path_lo
    sta head_path_pointer_msb

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

    ldx #$28
    lda #$01                // set colour of bottom row
!:  sta $d800 + [24*40], x
    dex
    bpl !-


loop:
    lda mode                // check if mode is set to auto
    beq !+
    jsr auto_mode           // use the hamiltian path to fake keyboard input
    jmp !++
!:  jsr read_keyb           // read last keypress, ignore if invalid
!:  jsr step                // set direction, update head coordinate, reset if AOB
    jsr screen_address      // look up the screen address from coordinates
    jsr collision_check     // check if snake has collided with itself or food
    jsr draw                // draw the snake
    jsr spawn_food          // check if there is food, if not spawn one, if food has been eaten increment length
    jsr delay               // run the delay loop according to speed setting
    jmp loop

auto_mode: {
    //load the current cycle number into cycle_lsb and cycle_msb and increment for later comparison
    ldx head_row
    ldy head_column
    jsr check
    lda >next_cycle
    sta cycle_msb
    lda <next_cycle
    sta cycle_lsb

    //print for debugging
    ldx #$00
    lda cycle_msb
    jsr PrintHexValue
    lda cycle_lsb
    jsr PrintHexValue
    inx
    
    lda cycle + $0428       //print location below top left cell
    jsr PrintHexValue
    lda cycle + $28
    jsr PrintHexValue

    // tsx
    // txa
    // ldx #$06
    // jsr PrintHexValue
    inx
    lda head_path_pointer_msb
    jsr PrintHexValue
    lda head_path_pointer_lsb
    jsr PrintHexValue

    //increment 
    clc
    lda cycle_lsb
    adc #$01
    sta cycle_lsb
    lda cycle_msb
    adc #$00
    sta cycle_msb

    //check hasn't reached 960 ($03c0) where the number wraps
    cmp #$03
    bne !+
    lda cycle_lsb
    cmp #$c0
    bne !+
    // if it has, reset to zero
    lda #$00
    sta cycle_lsb
    sta cycle_msb
!:
    ldx head_row
    // check left (dey)
    dey
    jsr check
    lda <next_cycle
    cmp cycle_lsb
    bne !+
    lda >next_cycle
    cmp cycle_msb
    beq !left+

!:  // check right (iny)
    iny
    iny
    jsr check
    lda <next_cycle
    cmp cycle_lsb
    bne !+
    lda >next_cycle
    cmp cycle_msb
    beq !right+

!:  // check above (dex)
    dey
    dex
    jsr check
    lda <next_cycle
    cmp cycle_lsb
    bne !+
    lda >next_cycle
    cmp cycle_msb
    beq !up+

!:  // check below unecissary because it's the only option left
    jmp !down+

!up:
    lda #$09
    sta last_key
    jmp check_for_reset
!right:
    lda #$12
    sta last_key
    jmp check_for_reset
!down:
    lda #$0d
    sta last_key
    jmp check_for_reset
!left:
    lda #$0a
    sta last_key
    jmp check_for_reset

check:                          // looks up cycle lsb/msb indexed by x and y. stored in next_cycle word
    lda cycle_table, x
    sta tmp_lsb
    lda cycle_msb_table, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta >next_cycle
    lda cycle_table + 25, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta <next_cycle
    rts

check_for_reset:
    lda $cb            // check if a key has been pressed (resets)
    cmp #$40
    beq !+
    jmp reset
!:  rts
}

read_keyb:          // reads keyboard input
    ldx $cb         // read keyboard buffer
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
    jmp menu

screen_address:                   // uses head_row and head_column value to set screen_lsb and screen_msb
    ldy head_row                  // to point at the screen location
    lda screen_table, y
    clc
    adc head_column
    sta screen_lsb
    lda screen_table +25, y
    adc #$00
    sta screen_msb
    rts

collision_check:
    ldy #$00
    lda (screen_lsb),y          // load head position in screen ram
    cmp #food_char              // check if that has food character
    beq fed
    cmp #$00                    // check for 'space' character
    bne reset
    rts
fed:
    lda #$00
    sta food_flag       // set food flag to 00 (no food)
    clc
    lda length_lsb      // add 1 to the length 
    adc #$01
    sta length_lsb
    lda length_msb
    adc #$00
    sta length_msb
    lda $d41b           // get random number
    and #%00000001      // check if odd or even
    beq stripes
    lda food_colour
    sta snake_colour    // change colour of snake (foreground)
    rts
stripes:                // switches the snake colour to the stripes colour and changes the stripes to food colour
    lda $d022           // stripes colour
    ora #%00001000      // switch bit 3 on to enable multi-colour
    sta snake_colour
    lda food_colour
    and #%00000111      // can only be colours 0-8 because of multicolor speed_setting
    sta $d022
    rts

draw:
    // draw head
    lda #$48                    // head character
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
    sta (head_path_pointer_lsb), y

    lda head_path_pointer_msb
    pha                         // temporarily push the head pointer to the stack

    clc
    adc #$04                    // add 1024 ($0400) to point at the path msb
    sta head_path_pointer_msb
    lda screen_msb
    sta (head_path_pointer_lsb),y

    lda head_path_pointer_msb
    clc
    adc #$04                    // add another 1024 ($0400) to point at the path direction
    sta head_path_pointer_msb
    lda direction
    sta (head_path_pointer_lsb),y
    
    pla                         // retrieve head pointer from the stack
    sta head_path_pointer_msb

    // redraw body behind head
    lda #$01                    // load the path_offset with a vlaue one 1 for the space behind the head.
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
    lda #$4c                        // tail character
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

    lda food_flag       
    and #%00000001      // check if bit 0 is set (there is no food so the snake must have eaten this loop)
    bne !+              // 
    ora #%00000010      // if this is true then set the 1 bit to indicate.
    sta food_flag       // 

    // increment head_pointer
!:  clc
    lda head_path_pointer_lsb
    adc #$01
    sta head_path_pointer_lsb
    lda head_path_pointer_msb
    adc #$00
    sta head_path_pointer_msb
    cmp #[>path_lo] + $04                 // check if the path pointer should be wrapped back around.
    beq !+
    rts
!:  lda #>path_lo
    sta head_path_pointer_msb
    rts

    // looks up the screen location from the path_offset and places
    // it in the screen_msb / lsb locations
    // takes care of wrapping around when decrementing the head_pointer
    // to stay within the valid memory space.
    // restores the head_pointer afterwards.
path_lookup:
    lda head_path_pointer_msb        // backup head pointer to stack
    pha
    lda head_path_pointer_lsb
    pha

    sec                         // subtract the path_offset
    sbc path_offset + 0
    sta head_path_pointer_lsb
    lda head_path_pointer_msb
    sbc path_offset + 1
    sta head_path_pointer_msb
    cmp #>path_lo               // check if this falls out the bottom of the path space
    bcs !+                      // and if so wrap around.
    adc #$04
    sta head_path_pointer_msb

!:  ldy #$00                    // retrieve the screen location from the path
    lda (head_path_pointer_lsb), y
    sta screen_lsb
    clc
    lda head_path_pointer_msb
    adc #$04
    sta head_path_pointer_msb
    lda (head_path_pointer_lsb), y
    sta screen_msb
    clc
    ldy #$01
    lda head_path_pointer_msb
    adc #$04
    sta head_path_pointer_msb
    lda (head_path_pointer_lsb), y
    sta tail_direction
        
    pla
    sta head_path_pointer_lsb        // restore head pointer from stack
    pla
    sta head_path_pointer_msb
    rts

spawn_food:              // spawns a food in a random location
    lda food_flag        // load food flag
    and #%00000001       // check if the zero bit is set
    bne !skip+           // if so, there is already food, skip spawning.

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

!:  lda $D41B           // get random number from sid
    and #%00000111
    cmp #bg_colour      // check this isn't the same as the background colour
    beq !-              // if it is, try again
    ora #%00001000      // set multicolour speed_setting
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
    lda food_flag       // load food flag
    ora #%00000001      // set bit 0 to 1 (there is a food on the board)
    sta food_flag       
    pla
    sta head_column     // put the head column back
    pla
    sta head_row        // put the head row back
!skip:
    rts
  
body_char:              // works out which body character needs to be drawn, puts it in the 'a' register.
    lda direction
    cmp prev_dir
    bne !corner+        // if the previous direction was different proceed to corner logic
    lda food_flag
    and #%00000010      // check if the 1 bit is set (snake has fed on prev loop)
    bne !fat_body+
    lda #$40            // body character
    clc
    adc prev_dir
    rts
!fat_body:
    lda food_flag
    and #%00000001      // reset the 1 bit
    sta food_flag
    lda #$50            // use the fat body character
    clc
    adc prev_dir 
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
    lda #$45            // ne_corner character
    rts
!:  lda #$46            // se_corner character
    rts
!up:
    lda prev_dir
    cmp #$01
    bne !+
    lda #$46            // se_corner character
    rts
!:  lda #$47            // sw_corner character
    rts
!right:
    lda prev_dir
    cmp #$00
    bne !+  
    lda #$44            // nw_corner character
    rts
!:  lda #$47            // sw_corner character
    rts
!down:
    lda prev_dir
    cmp #$01
    bne !+
    lda #$45            // ne_corner character
    rts
!:  lda #$44           // nw_corner character
    rts
}


delay:{
    txa                 // backup x
    pha
    tya                 // backup y
    pha
    ldx #$FF
    ldy #$55            // default to speed 0 (low)
    lda speed_setting   // load speed setting
    cmp #$00
    beq low_speed
    cmp #$01
    beq med_speed
    cmp #$02
    beq high_speed
    jmp super_speed
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
low_speed:
    ldy #$50
    jmp delay_loop
med_speed:
    ldy #$3a
    jmp delay_loop
high_speed:
    ldy #$20
    jmp delay_loop
super_speed:
    ldy #$10
    jmp delay_loop
}


clear_screen: {
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
}

PrintHexValue:{ pha
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
PHN_Print:      sta $0400 + [24*40],x
                inx
                rts
}


last_key:           .byte 0      // last key pressed
food_flag:          .byte 0      // 1 if there is food currently on the board otherwise 0
direction:          .byte 0
prev_dir:           .byte 0
head_row:           .byte 0      // y-coordinate, zero being top
head_column:        .byte 0      // x-coordinate, zero being left
length_lsb:         .byte 0      // snake length low .byte
length_msb:         .byte 0      // snake length high .byte
path_offset:        .word $0000  // 16 bit offset to be applied when looking up screen locations from the path.
tail_direction:     .byte 0
snake_colour:       .byte 0
food_colour:        .byte 0
speed_setting:      .byte 0
mode:               .byte 0
cycle_lsb:          .byte 0
cycle_msb:          .byte 0
next_cycle:         .word $0000

screen_table:         .lohifill 25, screen + [i * 40]     // table of the memory locations for the first column in each row
column_walls_table:   .fill [width / 2], i * [[height / 2] -1]
row_walls_table:      .fill [height /2], i * [[width  / 2] -1]
maze_table:           .fill 12, [i * 20]
cycle_table:          .lohifill 25, cycle + [i*40]
cycle_msb_table:      .fill 25, $04 + >[cycle + [i*40]]

.align $100
* = * "path data"       // locations for 'path' (history of previous screen locations)
path_lo:  .fill 1024, 0     // $0c00 - $0FFF screen location low bytes
path_hi:  .fill 1024, 0     // $1000 - $13FF screen location high bytes
path_dir: .fill 1024, 0     // $1400 - $17FF directions (needed to draw correct tail)

// the maze is defined by the 3x3 grid, a wall is a 1, a passageway is 0
.align $100
* = * "column_walls"      // can be maximum of 20 x 12 = 240 = $f0
column_walls:   .fill [[[width/2]-1]*[height/2]], $01
.align $100
* = * "row_walls"    
row_walls:      .fill [[height/2]*[[width/2]-1]], $01
.align $100
* = * "adjacency rows"           // maze adjacent cells, row records
adjacency_rows:     .fill 128, $00
.align $100
* = * "adjacency columns"               // maze adjacent cells, column records
adjacency_columns:  .fill 128, $00
.align $100
* = * "maze"
maze:               .fill 240, $00

*=$3000  "character set" // this character set would run to $37FF
.import binary "snake - Chars.bin"

*=*     "hamiltonian cycle"     // to store the cell numbers for the generated hamiltonian cycle
cycle:  .fill 2048, $00

*=*   "menu data"
menu_data:
.import binary "menu.bin"