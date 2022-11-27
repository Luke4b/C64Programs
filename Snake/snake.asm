BasicUpstart2(main)

* = $0810 "program"

.var tmp_lsb = $FA              //
.var tmp_msb = $FB              // 
//.label screen_lsb = $FC         // screen address low .byte
//.label screen_msb = $FD         // screen address high .byte
.label head_path_pointer_lsb = $FE   // head pointer low .byte
.label head_path_pointer_msb = $FF   // head pointer high .byte

.label bg_colour = $00    // background colour
.label brd_colour = $0b   // border colour
.label food_char = $3f    // character to be used for food.

.label random = $D41B       // address of random numbers from SID
.label width = 8          // maximum 40 must be even number
.label height = 8        // maximum 24 must be even number
.label screen = $0400

.label the_row = head_row           //reused these variables during mazegen
.label the_column = head_column    
.label colour = snake_colour
.label adjacency_length = tmp_direction
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

    // initialises the path pointer to where the path data is stored
    lda #<path
    sta head_path_pointer_lsb
    lda #>path
    sta head_path_pointer_msb

    lda #$0e
    sta snake_colour

    lda #$02
    sta length_lsb       // starting length

    lda #$09            //  default value for last key (to match default direction of up/$00)
    sta last_key

    // starting location in approximately screen centre
    lda #[height / 2]
    sta head_row
    lda #[width /2]
    sta head_column

    jsr clear_screen        // clear screen
    jsr spawn_food          // spawn initial piece of food

    ldx #$28
    lda #$01                // set colour of bottom row
!:  sta $d800 + [24*40], x
    dex
    bpl !-

        //print stuff to debug
.var i=0
.for (;i<6;) {
        ldx #[40 * i]
        ldy #00
    !:  lda cycle + [i * 40], y
        jsr PrintHexValue
        iny
        inx
        cpy #8
        bne !-
        .eval i++
}
        //print stuff to debug
.var j=0
.for (;j<2;) {
        ldx #[40 * j]
        ldy #00
    !:  lda cycle + [6 * 40] + [40 * j], y
        jsr PrintHexValue2
        iny
        inx
        cpy #8
        bne !-
        .eval j++
}


loop:

//    lda mode                // check if mode is set to auto
//    beq !+
    jsr auto_mode           // use the hamiltian path to fake keyboard input

print_stuff:{           // PRINT STUFF FOR DIAGNOSTIC PURPOSE

    ldx #25
    lda cycle_lsb
    jsr PrintHexValue2
    
    // distances

    ldx #30
    lda up_dist_lsb
    jsr PrintHexValue

    ldx #[30 - 3 + [2*40]]
    lda left_dist_lsb
    jsr PrintHexValue

    ldx #[30 + 3 + [2*40]]
    lda right_dist_lsb
    jsr PrintHexValue

    ldx #[30 + [4*40]]
    lda down_dist_lsb
    jsr PrintHexValue

    //targets

    ldx #[42 - 6]
    lda tail_cycle_lsb
    jsr PrintHexValue

    ldx #[42 - 6 + [4*40]]
    lda food_cycle_lsb
    jsr PrintHexValue
}

WAIT_KEY:
 //   jsr $FFE4         // Calling KERNAL GETIN 
 //   beq WAIT_KEY      // If Z, no key was pressed, so try again.



//    jmp !++
//!:  jsr read_keyb           // read last keypress, ignore if invalid
!:  jsr step                // set direction, update head coordinate, reset if AOB
    jsr collision_check     // check if snake has collided with itself or food
    jsr draw                // draw the snake
    jsr spawn_food          // check if there is food, if not spawn one, if food has been eaten increment length
    jsr delay               // run the> delay loop according to speed setting
    jmp loop


auto_mode: {    // calculates which cell go to next and fakes the correct keyboard input.
    //load the current head cycle number into cycle_lsb and cycle_msb
    ldx head_row
    ldy head_column
    jsr lookup_cycle
    lda tmp_cycle_msb
    sta cycle_msb
    lda tmp_cycle_lsb
    sta cycle_lsb

    //load the current food cycle number into food_cycle
    ldx food_row
    ldy food_col
    jsr lookup_cycle
    lda tmp_cycle_msb
    sta food_cycle_msb
    lda tmp_cycle_lsb
    sta food_cycle_lsb

    //load the current tail cycle number into tail_cycle
    ldx tail_row
    ldy tail_col
    jsr lookup_cycle
    lda tmp_cycle_msb
    sta tail_cycle_msb
    lda tmp_cycle_lsb
    sta tail_cycle_lsb
    
//find cycle values for each direction
    jsr get_up
    jsr get_right
    jsr get_down
    jsr get_left

//find smallest distance to target
    sec
    lda up_dist_lsb
    sbc down_dist_lsb
    lda up_dist_msb
    sbc up_dist_msb
    bcs !+
    // up < down
    lda up_dist_lsb
    sta tmp_dist_1_lsb
    lda up_dist_msb
    sta tmp_dist_1_msb
    jmp !++
!:  // down < up
    lda down_dist_lsb
    sta tmp_dist_1_lsb
    lda down_dist_msb
    sta tmp_dist_1_msb

!:  sec
    lda left_dist_lsb
    sbc right_dist_lsb
    lda left_dist_msb
    sbc right_dist_msb
    bcs !+
    lda left_dist_lsb   // left < right
    sta tmp_dist_2_lsb
    lda left_dist_msb
    sta tmp_dist_2_msb
    jmp !++
!:  lda right_dist_lsb  // right < left
    sta tmp_dist_2_lsb
    lda right_dist_msb
    sta tmp_dist_2_msb

!:  sec
    lda tmp_dist_1_lsb
    sbc tmp_dist_2_lsb
    lda tmp_dist_1_msb
    sbc tmp_dist_2_msb
    bcs !+
    lda tmp_dist_1_lsb    // tmp_dist_1 < tmp_dist_2
    sta tmp_cycle_lsb
    lda tmp_dist_1_msb
    sta tmp_cycle_msb
    jmp !++
!:  lda tmp_dist_2_lsb  // tmp_dist_2 < tmp_dist_1
    sta tmp_cycle_lsb
    lda tmp_dist_2_msb
    sta tmp_cycle_msb
!:


find_direction:         // find which of the directions had this distance to the target.
    lda tmp_cycle_msb
    cmp up_dist_msb
    bne !+
    lda tmp_cycle_lsb
    cmp up_dist_lsb
    beq !up+
!:  lda tmp_cycle_msb
    cmp down_dist_msb
    bne !+
    lda tmp_cycle_lsb
    cmp down_dist_lsb
    beq !down+
!:  lda tmp_cycle_msb
    cmp right_dist_msb
    bne !+
    lda tmp_cycle_lsb
    cmp right_dist_lsb
    beq !right+
!:  jmp !left+              //exhausted other options so must be left.

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

get_down:
    ldx head_row
    cpx #[height -1]
    beq !no_cut+
    ldy head_column
    inx
    jsr lookup_cycle
    lda tmp_cycle_lsb
    sta down_cycle_lsb
    lda tmp_cycle_msb
    sta down_cycle_msb
    jsr snake_check
    lda safe
    beq !no_cut+
    jsr dist_to_target
    lda tmp_cycle_msb
    sta down_dist_msb
    lda tmp_cycle_lsb
    sta down_dist_lsb
    rts
!no_cut:    
    lda #$FF
    sta down_dist_lsb
    sta down_dist_msb
    rts

get_up:
    ldx head_row
    beq !no_cut+
    ldy head_column
    dex
    jsr lookup_cycle
    lda tmp_cycle_lsb
    sta up_cycle_lsb
    lda tmp_cycle_msb
    sta up_cycle_msb
    jsr snake_check
    lda safe
    beq !no_cut+
    jsr dist_to_target
    lda tmp_cycle_msb
    sta up_dist_msb
    lda tmp_cycle_lsb
    sta up_dist_lsb
    rts
!no_cut:
    lda #$FF
    sta up_dist_lsb
    sta up_dist_msb
    rts

get_right:
    ldx head_row
    ldy head_column
    cpy #[width -1]
    beq !no_cut+
    iny
    jsr lookup_cycle
    lda tmp_cycle_lsb
    sta right_cycle_lsb
    lda tmp_cycle_msb
    sta right_cycle_msb
    jsr snake_check
    lda safe
    beq !no_cut+
    jsr dist_to_target
    lda tmp_cycle_msb
    sta right_dist_msb
    lda tmp_cycle_lsb
    sta right_dist_lsb
    rts
!no_cut:
    lda #$FF
    sta right_dist_lsb
    sta right_dist_msb
    rts

get_left:
    ldx head_row
    ldy head_column
    beq !no_cut+
    dey
    jsr lookup_cycle
    lda tmp_cycle_lsb
    sta left_cycle_lsb
    lda tmp_cycle_msb
    sta left_cycle_msb
    jsr snake_check
    lda safe
    beq !no_cut+
    jsr dist_to_target
    lda tmp_cycle_msb
    sta left_dist_msb
    lda tmp_cycle_lsb
    sta left_dist_lsb
    rts
!no_cut:
    lda #$FF
    sta left_dist_lsb
    sta left_dist_msb
    rts

snake_check:
/*  check if this cell option is unsafe (cells that could contain the snake)
    save safety status in 'safe' 1 = safe, 0 = unsafe
    if the tail > head, safe options are >head AND <tail
    if the head > tail, safe options are >head OR  <tail
*/
    // check if tail >= option cell
    lda tail_cycle_msb
    cmp tmp_cycle_msb
    bcc tail_less            // tail < option cell
    bne tail_greater         // tail > option cell
    lda tail_cycle_lsb
    cmp tmp_cycle_lsb
    bcc tail_less            // tail < option cell
    beq tail_equal           // tail = option cell
    bne tail_greater         //tail > option cell

tail_less:
tail_equal:
    lda #%00000000
    sta safe_tail
    jmp !+
tail_greater:
    lda #%00000001
    sta safe_tail

!:  sec                 // check if the option cell > head
    lda tmp_cycle_lsb
    sbc cycle_lsb
    lda tmp_cycle_msb
    sbc cycle_msb
    rol
    and #%00000001
    sta safe_head

    sec                 // check if the head > tail
    lda cycle_lsb 
    sbc tail_cycle_lsb 
    lda cycle_msb
    sbc tail_cycle_msb
    bcs !+               
    lda safe_tail        // tail > head
    and safe_head
    sta safe
    rts
!:  lda safe_tail        //head > tail
    ora safe_head
    sta safe
    rts

dist_to_target:                   // looks up the distance between tmp_cycle_lsb/msb and the food
    lda tmp_cycle_msb
    cmp food_cycle_msb
    bcc cell_behind_target
    bne cell_ahead_of_target
    lda tmp_cycle_lsb
    cmp food_cycle_lsb
    bcc cell_behind_target
    beq cell_behind_target
    bne cell_ahead_of_target

cell_ahead_of_target:
    sec                           // cell is ahead of target
    lda #<[[height * width] -1]   // subtract cell cycle number from largest cell number and then add target.
    sbc tmp_cycle_lsb
    sta tmp_cycle_lsb
    lda #>[[height * width] -1]
    sbc tmp_cycle_msb
    sta tmp_cycle_msb

    clc
    lda tmp_cycle_lsb
    adc food_cycle_lsb
    sta tmp_cycle_lsb
    lda tmp_cycle_msb
    adc food_cycle_msb
    sta tmp_cycle_msb
    rts
cell_behind_target:  
    sec                                 // cell is behind target
    lda food_cycle_lsb                  // subtract cell cycle number from targets.
    sbc tmp_cycle_lsb
    sta tmp_cycle_lsb
    lda food_cycle_msb
    sbc tmp_cycle_msb
    sta tmp_cycle_msb
    rts

lookup_cycle:                     // looks up cycle lsb/msb indexed by x and y. stored in tmp_cycle_lsb/msb
    lda cycle_table, x
    sta tmp_lsb
    lda cycle_msb_table, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta tmp_cycle_msb
    lda cycle_table + 25, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta tmp_cycle_lsb
    rts

check_for_reset:
    lda $cb            // check if a key has been pressed (resets)
    cmp #$40
    beq !+
    //jmp step.reset
!:  rts
}

read_keyb:  {        // reads keyboard input
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
}

step: {
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
    nop
    jsr $FFE4      // Calling KERNAL GETIN 
    nop
    jsr $FFE4
    beq reset      // If zero, no key was pressed, so try again.

    tsx
    inx
    inx
    txs
    jmp menu
}

collision_check:  {
    // if the head and food are at the same coordinate, snake has fed.
    lda head_row
    cmp food_row
    bne !+
    lda head_column
    cmp food_col
    beq fed

    // check the snake has moved onto an empty space, if not, and the space doesn't contain food then
    // it must have hit itself.
!:  ldx head_row
    ldy head_column
    lda screen_table, x
    sta tmp_lsb
    lda screen_table + 25, x
    sta tmp_msb
    lda (tmp_lsb), y
    cmp #$00                    // check for 'space' character
    bne step.reset
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
    and #%00000111      // can only be colours 0-7 because of multicolor speed_setting
    sta $d022
    rts
}

draw:   {
    // draw head
    lda snake_colour
    sta tmp_colour
    ldx head_row
    ldy head_column
    lda #$48                    // head character
    clc
    adc direction               // add direction creates correct head orientation character code
    jsr draw_char_colour

    // add the head coordinates and direction to the path data.
    ldy #$00
    lda head_row
    sta (head_path_pointer_lsb), y
    lda head_path_pointer_msb
    pha                         // temporarily push the head pointer msb to the stack

    clc
    adc #$04                    // add 1024 ($0400) to point at the path msb
    sta head_path_pointer_msb
    lda head_column
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
    lda #$01                    // load the path_offset with a value one 1 for the space behind the head.
    sta path_offset_lsb
    lda #$00
    sta path_offset_msb
    jsr body_char                  // look up what character to draw based on the previous direction, puts in 'a' reg
    jsr path_lookup                // look up the coord behind the head from the path, stored in x/y
    jsr draw_char

    // draw the tail
    sec
    lda length_lsb                 // subtract 1 from the length to find the tail space 
    sbc #$01
    sta path_offset_lsb
    lda length_msb
    sbc #$00
    sta path_offset_msb
    jsr path_lookup

    //  store a copy of the row/col coords in tail_row/tail_col
    txa
    sta tail_row
    tya
    sta tail_col

    lda #$4c                        // tail character
    clc
    adc tmp_direction               // add direction to get correct tail orientation char code
    jsr draw_char
    
    // remove the old tail (overwrite with a blank space)
    lda length_lsb
    sta path_offset_lsb
    lda length_msb
    sta path_offset_msb
    lda #$00            // blank space character code
    jsr path_lookup
    jsr draw_char

    lda food_flag       
    and #%00000001      // check if bit 0 is set (there is no food so the snake must have eaten this loop)
    bne !+              // 
    ora #%00000010      // if this is true then set the 1 bit to indicate.
    sta food_flag       // 

    // increment head_pointer
    ldx #$00
!:  clc
    lda head_path_pointer_lsb
    adc #$01
    sta head_path_pointer_lsb
    lda head_path_pointer_msb
    adc #$00
    sta head_path_pointer_msb
    cmp #[>path] + $04              // check if the path pointer should be wrapped back around.
    beq !+
    rts
!:  lda #>path
    sta head_path_pointer_msb
    rts

draw_char:      // draws the contents of the 'a' register at coordinates x/y
    pha
    lda screen_table, x
    sta tmp_lsb
    lda screen_table + 25, x
    sta tmp_msb
    pla
    sta (tmp_lsb), y
    rts

draw_char_colour:     // draws the character in  'a' in the colour set in tmp_colour at coordinates x/y
    pha
    lda screen_table, x
    sta tmp_lsb
    lda screen_table + 25, x
    sta tmp_msb
    pla
    sta (tmp_lsb), y
    lda tmp_msb
    clc
    adc #$d4
    sta tmp_msb
    lda tmp_colour
    sta (tmp_lsb), y
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
!corner:  
    cmp #$00
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
    lda #$45           // ne_corner character
    rts
!:  lda #$44           // nw_corner character
    rts

}
    // looks up the path offset from the head_pointer by path_offset
    // places the row/column in x/y registers
    // takes care of wrapping around when decrementing the head_pointer
    // to stay within the valid memory space.
    // restores the head_pointer afterwards.
    
path_lookup:
    pha                              // backup current 'a' reg contents to stack
    lda head_path_pointer_msb        // backup head pointer to stack
    pha
    lda head_path_pointer_lsb
    pha

    sec                              // subtract the path_offset
    sbc path_offset_lsb
    sta head_path_pointer_lsb
    lda head_path_pointer_msb
    sbc path_offset_msb
    sta head_path_pointer_msb
    cmp #>path                      // check if this falls out the bottom of the path space
    bcs !+                          // and if so wrap around.
    adc #$04
    sta head_path_pointer_msb

!:  ldy #$00                        // retrieve the row/col coords from the path
    lda (head_path_pointer_lsb), y
    sta tmprow
    clc
    lda head_path_pointer_msb
    adc #$04
    sta head_path_pointer_msb
    lda (head_path_pointer_lsb), y
    sta tmpcol
    clc
    lda head_path_pointer_msb
    adc #$04
    sta head_path_pointer_msb
    ldy #$01
    lda (head_path_pointer_lsb), y
    sta tmp_direction

    ldx tmprow
    ldy tmpcol
        
    pla
    sta head_path_pointer_lsb        // restore head pointer from stack
    pla
    sta head_path_pointer_msb
    pla                              // restore 'a' register
    rts

spawn_food:    {           // spawns a food in a random location
    lda food_flag          // load food flag
    and #%00000001         // check if the zero bit is set
    beq rand_row           
    rts                    // if so, there is already food, skip spawning.

rand_row:
    lda $D41B           // get random 8 bit (0 - 255) number from SID
    and #%00011111      // mask to 5 bit (0-31)
    cmp #00              // lower bound
    bmi rand_row
    cmp #height             // upper bound  compare to see if is in range
    bcs rand_row        // if the number is too large, try again
    sta food_row
rand_col:               // generate a random number between 0-39 for column
    lda $D41B           // get random 8 bit (0 - 255) number from SID
    and #%00111111      // mask to 6 bit (0 - 63)
    cmp #00             // lower bound
    bmi rand_col
    cmp #width             // upper bound  compare to see if is in range
    bcs rand_col        // if the number is too large, try again
    sta food_col

    // check that this cell doesn't contain part of the snake (any character but a blank space)
    ldx food_row
    ldy food_col
    lda screen_table, x
    sta tmp_lsb
    lda screen_table + 25, x
    sta tmp_msb
    lda (tmp_lsb), y
    cmp #$00            // see if it's a suitably blank location
    bne rand_row        // if it's not blank try again!!

!:  lda $D41B           // get random number from sid
    and #%00000111
    cmp #bg_colour      // check this isn't the same as the background colour
    beq !-              // if it is, try again
    ora #%00001000      // set multicolour
    sta food_colour
    sta tmp_colour
    lda #food_char
    jsr draw.draw_char_colour

    lda food_flag       // load food flag
    ora #%00000001      // set bit 0 to 1 (there is a food on the board)
    sta food_flag
}
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
    ldy #$25
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
PHN_Print:      sta $0400 + [17*40],x
                inx
                rts
}

PrintHexValue2:{ pha
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
PHN_Print:      sta $0400 + [23*40],x
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
path_offset_lsb:    .byte 0      // 16 bit offset to be applied when looking up screen locations from the path.
path_offset_msb:    .byte 0
tmp_direction:      .byte 0
tmp_colour:         .byte 0
snake_colour:       .byte 0
food_colour:        .byte 0
speed_setting:      .byte 0
mode:               .byte 0
cycle_lsb:          .byte 0
cycle_msb:          .byte 0
tmp_cycle_lsb:      .byte 0
tmp_cycle_msb:      .byte 0
food_row:           .byte 0
food_col:           .byte 0
tail_row:           .byte 0
tail_col:           .byte 0
food_cycle_lsb:     .byte 0
food_cycle_msb:     .byte 0
tmprow:             .byte 0
tmpcol:             .byte 0
up_dist_lsb:        .byte 0
right_dist_lsb:     .byte 0
down_dist_lsb:      .byte 0
left_dist_lsb:      .byte 0
up_dist_msb:        .byte 0
right_dist_msb:     .byte 0
down_dist_msb:      .byte 0
left_dist_msb:      .byte 0
up_cycle_lsb:       .byte 0
right_cycle_lsb:    .byte 0
down_cycle_lsb:     .byte 0
left_cycle_lsb:     .byte 0
up_cycle_msb:       .byte 0
right_cycle_msb:    .byte 0
down_cycle_msb:     .byte 0
left_cycle_msb:     .byte 0
tail_cycle_lsb:     .byte 0
tail_cycle_msb:     .byte 0
tmp_dist_1_lsb:     .byte 0
tmp_dist_1_msb:     .byte 0
tmp_dist_2_lsb:     .byte 0
tmp_dist_2_msb:     .byte 0
safe_tail:          .byte 0
safe_head:          .byte 0
safe:               .byte 0

screen_table:         .lohifill 25, screen + [i * 40]     // table of the memory locations for the first column in each row
column_walls_table:   .fill [width / 2], i * [[height / 2] -1]
row_walls_table:      .fill [height /2], i * [[width  / 2] -1]
maze_table:           .fill 12, [i * 20]
cycle_table:          .lohifill 25, cycle + [i*40]
cycle_msb_table:      .fill 25, $04 + >[cycle + [i*40]]

.align $100
* = * "path data"       // locations for 'path' (history of previous coordinates
path:
path_row:  .fill 1024, 0     // $0c00 - $0FFF rows
path_col:  .fill 1024, 0     // $1000 - $13FF columns
path_dir: .fill 1024, 0     // $1400 - $17FF directions (needed to draw correct tail)

// a wall is a 1, a passageway is 0
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