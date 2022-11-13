BasicUpstart2(main)

* = $0810 "program"

.label the_row = $FA            //
.label the_column = $FB         // 
.label screen_lsb = $FC         // screen address low .byte
.label screen_msb = $FD         // screen address high .byte
.label tmp_lsb = $FE          
.label tmp_msb = $FF   

.label width = 40          // maximum 40 must be even number
.label height = 24         // maximum 24 must be even number
.label random = $D41B       // address of random numbers from SID

.label block_char = $a0
.label vertwall_char = $e7
.label horizwall_char = $ef
.label wallcorner_char = $fa

main:  {
    // set SID chip to generate white noise (random numbers)
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low .byte
    sta $D40F // voice 3 frequency high .byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    lda #BLACK    // set background and border colours to black
    sta $d020   
    sta $d021

    lda $D018           // set character memory to start from ram at $3000
    ora #$0c
    sta $d018

start:
//initialise walls for rows and columns
        lda #$01
        ldx #$00
!:      sta column_walls, x
        sta row_walls, x
        dex
        bne !-

//initialise cycle data
        lda #$00
        ldx #$FF
!:      sta cycle,x
        sta cycle + $FF, x
        dex
        bne !-
        
//initialise maze
        lda #$00
        ldx #$00
!:      sta maze, x
        sta adjacency_rows, x
        sta adjacency_columns, x
        dex
        bne !-


    jsr clear_screen
!:  jsr $ffe4   //Kernal wait key routine
    beq !-
    jsr maze_gen
!:  jsr $ffe4   //Kernal wait key routine
    beq !-
    jsr follow_maze

}
maze_gen:  {  
    //Modified Randomized Prim's algorithm,  the maze is half the size of the hamiltonian cycle required.
    //1.   Pick a cell, mark it as part of the maze. 
    //2.   Add the adjacent cells to a list (check if they're already there?).
    //3.   Pop a random maze-adjacent cell from the list.
                //move the last item into it's space and dec the length
    //4.   Make a random wall between it and the maze into a passage.
                //Add it's adjacent cells to the adjacency list
    //5.   Check if the list of maze-adjacent cells is length 0, if so we're done.


//1 generate an initial random row/column for first cell
initial_cell:           
!:  lda random
    and #%00011111      // limit in size to 32
    cmp #[height / 2]
    bcs !-
    sta the_row
    sta tmprow
!:  lda random
    and #%00111111      // limit in size to 64
    cmp #[width / 2]
    bcs !-
    sta the_column
    sta tmpcol
    ldx #$01            // initial cell tile type
    jsr add_cell
    jsr draw_cell
    lda #GREEN
    sta colour
    jsr colour_cell

    jsr add_adjacencies

maze_gen_loop:
// !:  jsr $ffe4   //Kernal wait key routine
//     beq !-
    jsr pick_adjacent
// !:  jsr $ffe4   //Kernal wait key routine
//     beq !-
    jsr delay
    jsr delay
    jsr create_passage
    jsr delay
    lda adjacency_length
    bne maze_gen_loop
    rts

add_cell:                       // writes a block character to the maze location tmprow, tmpcol
    txa
    pha
    ldx tmprow
    lda maze_table, x
    sta tmp_lsb
    lda #>maze
    sta tmp_msb
    ldy tmpcol
    pla
    tax
    sta (tmp_lsb), y
    rts

draw_cell:      // draws a cell (2x2 tile), code for the tile should be in x reg before calling, tmprow, tmpcol used
    txa         // also changes the tile code in the maze data.
    pha
    lda tmprow              // draw cell
    asl
    tax
    lda screen_table, x
    sta screen_lsb
    lda screen_table + 25, x
    sta screen_msb
    lda tmpcol
    asl
    tay
    pla
    asl // *2
    asl // *4
    tax
    lda tiles, x
    sta (screen_lsb), y
    iny
    lda tiles + 1, x
    sta (screen_lsb), y
    dey
    txa
    pha
    lda tmprow
    asl
    tax
    inx
    lda screen_table, x
    sta screen_lsb
    lda screen_table + 25, x
    sta screen_msb
    pla
    tax
    lda tiles + 2, x
    sta (screen_lsb), y
    iny
    lda tiles + 3, x
    sta (screen_lsb), y
    rts

colour_cell:    // colours the cell pointed at by tmprow, tmpcol in the set colour
    lda tmprow
    asl
    tax
    lda tmpcol
    asl
    tay
    lda screen_table, x
    sta screen_lsb
    lda screen_table + 25, x
    clc
    adc #$d4
    sta screen_msb
    lda colour
    sta (screen_lsb), y
    iny
    sta (screen_lsb), y
    dey
    inx
    lda screen_table, x
    sta screen_lsb
    lda screen_table +25, x
    clc
    adc #$d4
    sta screen_msb
    lda colour
    sta (screen_lsb), y
    iny
    sta (screen_lsb), y
    rts

//2 add cell's adjacents to adjacency lists (lists of row/column)
    //check for edge cases
    //check if cell already exists within these lists, don't add twice
add_adjacencies: {          // takes the current content of the_row and the_column and adds adjacent cells
main_routine:{              // to the adjacency lists
    lda the_row             
    cmp #[height/2 -1]
    bne not_bottom
    jmp not_top

not_bottom:                 // add the cell below
    lda the_row    
    clc
    adc #$01
    sta tmprow
    lda the_column
    sta tmpcol
    jsr add_adj_lists

    lda the_row
    beq !+

not_top:
    lda the_row             //add the cell above
    sec
    sbc #$01
    sta tmprow
    lda the_column
    sta tmpcol
    jsr add_adj_lists

!:  lda the_column
    cmp #[width/2 -1]
    bne not_rightmost
    jmp not_leftmost

not_rightmost:              //add the cell to the right
    lda the_row
    sta tmprow
    lda the_column
    clc
    adc #$01
    sta tmpcol
    jsr add_adj_lists

    lda the_column 
    beq !+

not_leftmost:               //add the cell to the left
    lda the_row
    sta tmprow
    lda the_column
    sec
    sbc #$01
    sta tmpcol
    jsr add_adj_lists

!:  rts
}


add_adj_lists:    {   // check if cell is already in the maze, if not//
                      // check if already exists with adjacency list, 
                      // if not adds the cell (tmprow, tmpcol) to the lists and increments the length.
    ldx adjacency_length
    cpx #$00
    beq first             // the first time the length of the list will be zero, this skips directly to saving.

    ldx tmprow            // checks that this cell isn't already part of the maze.
    ldy tmpcol
    lda maze_table, x
    sta tmp_lsb
    lda #>maze
    sta tmp_msb
    lda (tmp_lsb), y
    beq not_in_maze
    rts

not_in_maze:
    ldx adjacency_length
loop:
    dex     
    lda adjacency_columns, x    // test against column
    cmp tmpcol
    bne next
    lda adjacency_rows, x       // test against row
    cmp tmprow
    bne next
    rts               // if row matches it's a duplicate, return early without adding
next:
    cpx #$00          
    bne loop          // if x hasn't reached zero there are still entries to try.
    ldx adjacency_length    
first:
    lda tmprow
    sta adjacency_rows, x
    lda tmpcol
    sta adjacency_columns, x
    inc adjacency_length

    // draw adjacent cell
    ldx #$00
    jsr draw_cell
    lda #RED
    sta colour
    jsr colour_cell

    rts
}
}

//3 pick a random cell from the adjacency lists, add to maze (stored in screen memory)
pick_adjacent: {
!:  lda random
    and #%01111111
    cmp adjacency_length
    bcs !-                  // if it's larger than the length of the adjacency list try again
    tax
    stx temp

    lda adjacency_rows, x
    sta the_row
    sta tmprow
    lda adjacency_columns, x
    sta the_column
    sta tmpcol
    
    ldx #$01                // tile type to draw
    jsr add_cell            // add cell to maze (stored in screen ram)
    jsr draw_cell           // draw cell on screen
    lda #YELLOW
    sta colour
    jsr colour_cell

    // move last entry in adjacency list down to fill this one's place
    ldx adjacency_length
    dex                     // the length points at the next cell, the last data is in the cell behind.
    lda adjacency_rows, x
    ldx temp
    sta adjacency_rows, x
    ldx adjacency_length
    dex
    lda adjacency_columns, x
    ldx temp
    sta adjacency_columns, x

    dec adjacency_length
    rts
}

//4 make a random wall between this cell and the maze into a passage.
create_passage: {
    lda random
    and #%00000011           // random number between 0-3 for direction
    bne !+
    jmp !up+
!:  cmp #$01
    bne !+
    jmp !down+
!:  cmp #$02
    bne !right+
    jmp !left+

!right:
    lda the_row
    sta tmprow
    lda the_column
    cmp #[[width /2] -1]
    bne !+
    jmp create_passage      // if this is the rightmost column, try again with new random direction
!:  clc
    adc #$01
    sta tmpcol
    jsr check_maze          // loads 'a' reg with contents of (tmprow, tmpcol) from maze in screen ram
    bne !+
    jmp create_passage      // if not in the maze, try again
    
!:  ldx the_row
    ldy the_column
    lda row_walls_table, x
    sta tmp_lsb
    lda #>row_walls
    sta tmp_msb
    lda #$00
    sta (tmp_lsb), y
    lda #$08
    jsr draw_passage
    jmp blah
!up:
    lda the_row
    bne !+
    jmp create_passage      // if this is the top row, try again with new random direction
!:  sec
    sbc #$01
    sta tmprow
    lda the_column
    sta tmpcol
    jsr check_maze          // loads 'a' reg with contents of (tmprow, tmpcol) from maze in screen ram
    bne !+
    jmp create_passage      // if not in the maze, try again
    
!:  ldx the_column
    ldy tmprow
    lda column_walls_table, x
    sta tmp_lsb
    lda #>column_walls
    sta tmp_msb
    lda #$00
    sta (tmp_lsb), y
    lda #$04
    jsr draw_passage
    jmp blah
!down:
    lda the_row
    cmp #[[height/2] -1]
    bne !+
    jmp create_passage      // if this is the bottom row, try again with new random direction
!:  clc
    adc #$01
    sta tmprow
    lda the_column
    sta tmpcol
    jsr check_maze          // loads 'a' reg with contents of (tmprow, tmpcol) from maze in screen ram
    bne !+
    jmp create_passage      // if not in the maze, try again
    
!:  ldx the_column
    ldy the_row
    lda column_walls_table, x
    sta tmp_lsb
    lda #>column_walls
    sta tmp_msb
    lda #$00
    sta (tmp_lsb), y
    lda #$02
    jsr draw_passage
    jmp blah
!left:
    lda the_row
    sta tmprow
    lda the_column
    bne !+
    jmp create_passage     // if this is the leftmost column, try again with new random direction
!:  sec
    sbc #$01
    sta tmpcol
    jsr check_maze          // loads 'a' reg with contents of (tmprow, tmpcol) from maze in screen ram
    bne !+
    jmp create_passage      // if not in the maze, try again

!:  ldx the_row
    ldy tmpcol
    lda row_walls_table, x
    sta tmp_lsb
    lda #>row_walls
    sta tmp_msb
    lda #$00
    sta (tmp_lsb), y
    lda #$03
    jsr draw_passage
    jmp blah

check_maze:                 // check if the cell tmprow, tmpcol is in the maze, load contents into temp
    ldx tmprow
    ldy tmpcol
    lda maze_table, x
    sta tmp_lsb
    lda #>maze
    sta tmp_msb
    lda (tmp_lsb), y
    sta temp
    rts

draw_passage:               //old maze cell is in tmprow,tmpcol tile type in temp. new cell in in the_row, the_col, direction is in 'a' reg
    sta direction           //update the existing maze tile
    ldx temp
    cpx #$01                //need to skip the addition for the first passage drawn.
    beq !+
    clc
    adc temp
!:  tax
    jsr add_cell
    jsr draw_cell
    
    jsr swap_coords         // swap the new cell's coords into tmprow,tmpcol 
    jsr check_maze          // loads the current tile type into temp
    lda direction           
    jsr invert_direction    // switch up for down, left for right.
    ldx temp
    cpx #$01
    beq !+
    clc
    adc temp
!:  tax
    jsr add_cell
    jsr draw_cell
    rts

invert_direction:       //takes up, right, down, left = 2,3,4,8  and changes to 4,8,2,3
    lda direction
    cmp #03
    beq !right+
    cmp #04
    beq !down+
    cmp #08
    beq !left+
!up:
    lda #$04
    sta direction
    rts
!right:
    lda #$08
    sta direction
    rts
!down:
    lda #$02
    sta direction
    rts
!left:
    lda #$03
    sta direction
    rts


swap_coords:
    lda the_row
    pha
    lda the_column
    pha
    lda tmprow
    sta the_row
    lda tmpcol
    sta the_column
    pla
    sta tmpcol
    pla 
    sta tmprow
    rts

blah:
    lda #GREEN
    sta colour
    jsr colour_cell
    lda adjacency_length
    beq !+
    jsr swap_coords
    jsr add_adjacencies
!:  rts



}
}

follow_maze: {

    // start in the top left corner
    lda #$00
    sta the_row
    sta the_column
    sta cycle_lsb
    sta cycle_msb

    lda #$01
    sta direction

    // reinitialize colour
    lda #$00
    sta colour
loop:
    //  increment colour if back to top left corner.
    lda the_row
    bne !+
    lda the_column
    bne !+
    inc colour

// !:  jsr $ffe4   //Kernal wait key routine
//     beq !-
!:  jsr draw
    jsr turn_left
    jsr step
    jsr delay    
    
    clc             // increment the number in the cycle
    lda cycle_lsb
    adc #$01
    sta cycle_lsb
    lda cycle_msb
    adc #$00
    sta cycle_msb

    // if back to zero, 
    lda cycle_lsb
    cmp #$C0
    bne !+
    lda cycle_msb
    cmp #$03
    bne !+
    jmp main.start

!:  jmp loop

draw:
    //get the screen location to draw to
    ldx the_row
    ldy the_column

    // change colour
    lda screen_table, x
    sta screen_lsb
    lda screen_table + 25, x
    clc
    adc #$d4
    sta screen_msb
    lda colour
    sta (screen_lsb), y

    // print cycle number to the screen
    ldx #$00
    lda cycle_msb
    jsr PrintHexValue
    lda cycle_lsb
    jsr PrintHexValue
    ldx the_row

    // write cycle number
    lda cycle_table, x
    sta tmp_lsb
    lda cycle_table + 25, x
    sta tmp_msb
    lda cycle_lsb
    sta (tmp_lsb), y
    lda cycle_msb_table, x
    sta tmp_msb
    lda cycle_msb
    sta (tmp_lsb), y
    rts

step:   // move along path checking if there is a wall and turning (changing direction) if needed
    ldx #$00        // zero the x register, will be used as flag for a wall
    lda direction
    cmp #$01
    beq !right+
    cmp #$02
    beq !down+
    cmp #$03
    beq !left+
!up:
    lda the_row
    and #%00000001  // check if row is odd
    bne !+  
    jsr check_col_wall  // will return with a #$01 in the x reg if there's a wall.
    cpx #$01   
    beq turn_right
!:  dec the_row     // if the row is odd, no wall check is needed.
    rts
!right:
    lda the_column
    and #%00000001  // check if column is even
    beq !+
    jsr check_row_wall
    cpx #$01   
    beq turn_right
!:  inc the_column  // if the column is even, no wall check is needed.
    rts
!down:
    lda the_row
    and #%00000001  // check if row is even
    beq !+
    jsr check_col_wall
    cpx #$01   
    beq turn_right
!:  inc the_row     // if the row is even, no wall check needed.
    rts
!left:
    lda the_column
    and #$00000001  // check if column is odd
    bne !+
    jsr check_row_wall
    cpx #$01
    beq turn_right
!:  dec the_column  // if the column is odd, no wall check is needed.
    rts

turn_right:           // if a wall has been encountered we turn right
    lda direction
    clc
    adc #$01
    cmp #$04          // check if direction needs to loop back to zero
    bne !+
    lda #$00
 !: sta direction 
    jmp step          // try stepping again in the new direction.

turn_left:           // if a wall has been encountered we turn right
    lda direction
    sec
    sbc #$01
    cmp #$ff
    bne !+
    lda #$03
 !: sta direction 
    rts


check_col_wall:
    lda direction
    cmp #$02
    beq !down+
!up:                 // direction = up (label for readability only)
    lda the_row
    bne get_col_wall
    ldx #$01        // must be the top row so set wall flag
    rts
!down:              // direction = down
    lda the_row
    cmp #height - 1 // check if this is the last row (always a wall below)
    bne get_col_wall
    ldx #$01        // mst be the bottom row so set wall flag
    rts         
get_col_wall:
    sec
    sbc #$01                // subtract 1 the row so for input of row 3 or 4 -> 2 or 3, this allows the same routine for up and down
    lsr                     // shift right (divide by 2)  so row 2, %00000010 or row 3, %00000011 = %00000001,1
    tay                     // put the row index in y reg
    lda the_column
    lsr
    tax                     // put the column index in the x reg
    lda column_walls_table, x
    sta tmp_lsb
    lda #>column_walls
    sta tmp_msb
    lda (tmp_lsb), y        
    tax
    rts                     // return with wall flag from maze definition in x reg

check_row_wall:
    lda direction
    cmp #$03
    beq !left+
!right:                     // direction = right (label for readablity only)
    lda the_column
    cmp #width - 1
    bne get_row_wall        // check if this is the rightmost column (always a wall to the right)
    ldx #$01                // must already be rightmost column so set wall flag
    rts
!left:                      // direction = left
    lda the_column          // check if this is the leftmost column (always a wall to the left)
    bne get_row_wall
    ldx #$01                // must already be leftmost column so set wall flag
    rts
get_row_wall:
    sec
    sbc #$01                // subtract 1 the column so for input of column 3 or 4 -> 2 or 3, this allows the same routine for left and right
    lsr                     // shift right (divide by 2)  so if column 2, %00000010 or column 3, %00000011 = %00000001,1
    tay                     // put the column index in y reg
    lda the_row
    lsr
    tax                     // put the row index in the x reg
    lda row_walls_table, x
    sta tmp_lsb
    lda #>row_walls
    sta tmp_msb
    lda (tmp_lsb), y        
    tax
    rts                     // return with wall flag from maze definition in x reg
}

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

delay:
    txa                 // backup x
    pha
    tya                 // backup y
    pha
    ldx #$FF
    ldy #$05
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

// general purpose addresses

temp:               .byte $00
tmp2:               .byte $00
number:             .byte $30
direction:          .byte $00
adjacency_length:   .byte $00
blank:              .byte $00
tmprow:             .byte $00
tmpcol:             .byte $00
colour:             .byte $00
cycle_lsb:          .byte $00
cycle_msb:          .byte $00

.align $100
* = * "tables"
screen_table:         .lohifill 25, $0400 + [i * 40]
column_walls_table:   .fill [width / 2], i * [[height / 2] -1]
row_walls_table:      .fill [height /2], i * [[width  / 2] -1]
maze_table:           .fill 12, [i * 20]
cycle_table:          .lohifill 25, cycle + [i*40]
cycle_msb_table:      .fill 25, $04 + >[cycle + [i*40]]

tiles:  // ordering specific such that conversion can be done with addition with directional pieces
.byte   $6c, $7b, $7c, $7e  // 00 adjacent
.byte   $cf, $d0, $cc, $fa  // 01 cell
.byte   $e5, $e7, $cc, $fa  // 02 up
.byte   $cf, $f7, $cc, $ef  // 03 right
.byte   $cf, $d0, $e5, $e7  // 04 down
.byte   $e5, $fc, $cc, $ef  // 05 upright corner
.byte   $e5, $e7, $e5, $e7  // 06 vertical
.byte   $cf, $f7, $e5, $ec  // 07 rightdown corner
.byte   $f7, $d0, $ef, $fa  // 08 left
.byte   $e5, $fc, $e5, $ec  // 09 T up, right, down
.byte   $fe, $e7, $ef, $fa  // 0A upleft corner
.byte   $f7, $f7, $ef, $ef  // 0B horizontal
.byte   $f7, $d0, $fb, $e7  // 0C downleft corner
.byte   $fe, $fc, $ef, $ef  // 0D T up, right, left
.byte   $fe, $e7, $fb, $e7  // 0E T down, left, up
.byte   $f7, $f7, $fb, $ec  // 0F T right, down, left
.byte   $00, $00, $00, $00  // 10 UNDEFINED
.byte   $fe, $fc, $fb, $ec  // 11 crossroads

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

* = * "adjacency columns"               // maze adjacent cells, column records
adjacency_columns:  .fill 128, $00

.align $100
* = * "maze"
maze:               .fill 240, $00



*= $3000 "charset"
.byte $3C,$66,$6E,$6E,$60,$62,$3C,$00	// #00 $00
.byte $18,$3C,$66,$7E,$66,$66,$66,$00	// #01 $01
.byte $7C,$66,$66,$7C,$66,$66,$7C,$00	// #02 $02
.byte $3C,$66,$60,$60,$60,$66,$3C,$00	// #03 $03
.byte $78,$6C,$66,$66,$66,$6C,$78,$00	// #04 $04
.byte $7E,$60,$60,$78,$60,$60,$7E,$00	// #05 $05
.byte $7E,$60,$60,$78,$60,$60,$60,$00	// #06 $06
.byte $3C,$66,$60,$6E,$66,$66,$3C,$00	// #07 $07
.byte $66,$66,$66,$7E,$66,$66,$66,$00	// #08 $08
.byte $3C,$18,$18,$18,$18,$18,$3C,$00	// #09 $09
.byte $1E,$0C,$0C,$0C,$0C,$6C,$38,$00	// #10 $0A
.byte $66,$6C,$78,$70,$78,$6C,$66,$00	// #11 $0B
.byte $60,$60,$60,$60,$60,$60,$7E,$00	// #12 $0C
.byte $63,$77,$7F,$6B,$63,$63,$63,$00	// #13 $0D
.byte $66,$76,$7E,$7E,$6E,$66,$66,$00	// #14 $0E
.byte $3C,$66,$66,$66,$66,$66,$3C,$00	// #15 $0F
.byte $7C,$66,$66,$7C,$60,$60,$60,$00	// #16 $10
.byte $3C,$66,$66,$66,$66,$3C,$0E,$00	// #17 $11
.byte $7C,$66,$66,$7C,$78,$6C,$66,$00	// #18 $12
.byte $3C,$66,$60,$3C,$06,$66,$3C,$00	// #19 $13
.byte $7E,$18,$18,$18,$18,$18,$18,$00	// #20 $14
.byte $66,$66,$66,$66,$66,$66,$3C,$00	// #21 $15
.byte $66,$66,$66,$66,$66,$3C,$18,$00	// #22 $16
.byte $63,$63,$63,$6B,$7F,$77,$63,$00	// #23 $17
.byte $66,$66,$3C,$18,$3C,$66,$66,$00	// #24 $18
.byte $66,$66,$66,$3C,$18,$18,$18,$00	// #25 $19
.byte $7E,$06,$0C,$18,$30,$60,$7E,$00	// #26 $1A
.byte $3C,$30,$30,$30,$30,$30,$3C,$00	// #27 $1B
.byte $0C,$12,$30,$7C,$30,$62,$FC,$00	// #28 $1C
.byte $3C,$0C,$0C,$0C,$0C,$0C,$3C,$00	// #29 $1D
.byte $00,$18,$3C,$7E,$18,$18,$18,$18	// #30 $1E
.byte $00,$10,$30,$7F,$7F,$30,$10,$00	// #31 $1F
.byte $00,$00,$00,$00,$00,$00,$00,$00	// #32 $20
.byte $18,$18,$18,$18,$00,$00,$18,$00	// #33 $21
.byte $66,$66,$66,$00,$00,$00,$00,$00	// #34 $22
.byte $66,$66,$FF,$66,$FF,$66,$66,$00	// #35 $23
.byte $18,$3E,$60,$3C,$06,$7C,$18,$00	// #36 $24
.byte $62,$66,$0C,$18,$30,$66,$46,$00	// #37 $25
.byte $3C,$66,$3C,$38,$67,$66,$3F,$00	// #38 $26
.byte $06,$0C,$18,$00,$00,$00,$00,$00	// #39 $27
.byte $0C,$18,$30,$30,$30,$18,$0C,$00	// #40 $28
.byte $30,$18,$0C,$0C,$0C,$18,$30,$00	// #41 $29
.byte $00,$66,$3C,$FF,$3C,$66,$00,$00	// #42 $2A
.byte $00,$18,$18,$7E,$18,$18,$00,$00	// #43 $2B
.byte $00,$00,$00,$00,$00,$18,$18,$30	// #44 $2C
.byte $00,$00,$00,$7E,$00,$00,$00,$00	// #45 $2D
.byte $00,$00,$00,$00,$00,$18,$18,$00	// #46 $2E
.byte $00,$03,$06,$0C,$18,$30,$60,$00	// #47 $2F
.byte $3C,$66,$6E,$76,$66,$66,$3C,$00	// #48 $30
.byte $18,$18,$38,$18,$18,$18,$7E,$00	// #49 $31
.byte $3C,$66,$06,$0C,$30,$60,$7E,$00	// #50 $32
.byte $3C,$66,$06,$1C,$06,$66,$3C,$00	// #51 $33
.byte $06,$0E,$1E,$66,$7F,$06,$06,$00	// #52 $34
.byte $7E,$60,$7C,$06,$06,$66,$3C,$00	// #53 $35
.byte $3C,$66,$60,$7C,$66,$66,$3C,$00	// #54 $36
.byte $7E,$66,$0C,$18,$18,$18,$18,$00	// #55 $37
.byte $3C,$66,$66,$3C,$66,$66,$3C,$00	// #56 $38
.byte $3C,$66,$66,$3E,$06,$66,$3C,$00	// #57 $39
.byte $00,$00,$18,$00,$00,$18,$00,$00	// #58 $3A
.byte $00,$00,$18,$00,$00,$18,$18,$30	// #59 $3B
.byte $0E,$18,$30,$60,$30,$18,$0E,$00	// #60 $3C
.byte $00,$00,$7E,$00,$7E,$00,$00,$00	// #61 $3D
.byte $70,$18,$0C,$06,$0C,$18,$70,$00	// #62 $3E
.byte $3C,$66,$06,$0C,$18,$00,$18,$00	// #63 $3F
.byte $00,$00,$00,$FF,$FF,$00,$00,$00	// #64 $40
.byte $08,$1C,$3E,$7F,$7F,$1C,$3E,$00	// #65 $41
.byte $18,$18,$18,$18,$18,$18,$18,$18	// #66 $42
.byte $00,$00,$00,$FF,$FF,$00,$00,$00	// #67 $43
.byte $00,$00,$FF,$FF,$00,$00,$00,$00	// #68 $44
.byte $00,$FF,$FF,$00,$00,$00,$00,$00	// #69 $45
.byte $00,$00,$00,$00,$FF,$FF,$00,$00	// #70 $46
.byte $30,$30,$30,$30,$30,$30,$30,$30	// #71 $47
.byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C	// #72 $48
.byte $00,$00,$00,$E0,$F0,$38,$18,$18	// #73 $49
.byte $18,$18,$1C,$0F,$07,$00,$00,$00	// #74 $4A
.byte $18,$18,$38,$F0,$E0,$00,$00,$00	// #75 $4B
.byte $C0,$C0,$C0,$C0,$C0,$C0,$FF,$FF	// #76 $4C
.byte $C0,$E0,$70,$38,$1C,$0E,$07,$03	// #77 $4D
.byte $03,$07,$0E,$1C,$38,$70,$E0,$C0	// #78 $4E
.byte $FF,$FF,$C0,$C0,$C0,$C0,$C0,$C0	// #79 $4F
.byte $FF,$FF,$03,$03,$03,$03,$03,$03	// #80 $50
.byte $00,$3C,$7E,$7E,$7E,$7E,$3C,$00	// #81 $51
.byte $00,$00,$00,$00,$00,$FF,$FF,$00	// #82 $52
.byte $36,$7F,$7F,$7F,$3E,$1C,$08,$00	// #83 $53
.byte $60,$60,$60,$60,$60,$60,$60,$60	// #84 $54
.byte $00,$00,$00,$07,$0F,$1C,$18,$18	// #85 $55
.byte $C3,$E7,$7E,$3C,$3C,$7E,$E7,$C3	// #86 $56
.byte $00,$3C,$7E,$66,$66,$7E,$3C,$00	// #87 $57
.byte $18,$18,$66,$66,$18,$18,$3C,$00	// #88 $58
.byte $06,$06,$06,$06,$06,$06,$06,$06	// #89 $59
.byte $08,$1C,$3E,$7F,$3E,$1C,$08,$00	// #90 $5A
.byte $18,$18,$18,$FF,$FF,$18,$18,$18	// #91 $5B
.byte $C0,$C0,$30,$30,$C0,$C0,$30,$30	// #92 $5C
.byte $18,$18,$18,$18,$18,$18,$18,$18	// #93 $5D
.byte $00,$00,$03,$3E,$76,$36,$36,$00	// #94 $5E
.byte $FF,$7F,$3F,$1F,$0F,$07,$03,$01	// #95 $5F
.byte $00,$00,$00,$00,$00,$00,$00,$00	// #96 $60
.byte $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0	// #97 $61
.byte $00,$00,$00,$00,$FF,$FF,$FF,$FF	// #98 $62
.byte $FF,$00,$00,$00,$00,$00,$00,$00	// #99 $63
.byte $00,$00,$00,$00,$00,$00,$00,$FF	// #100 $64
.byte $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0	// #101 $65
.byte $CC,$CC,$33,$33,$CC,$CC,$33,$33	// #102 $66
.byte $03,$03,$03,$03,$03,$03,$03,$03	// #103 $67
.byte $00,$00,$00,$00,$CC,$CC,$33,$33	// #104 $68
.byte $FF,$FE,$FC,$F8,$F0,$E0,$C0,$80	// #105 $69
.byte $03,$03,$03,$03,$03,$03,$03,$03	// #106 $6A
.byte $18,$18,$18,$1F,$1F,$18,$18,$18	// #107 $6B
.byte $00,$00,$00,$00,$0F,$0F,$0F,$0F	// #108 $6C
.byte $18,$18,$18,$1F,$1F,$00,$00,$00	// #109 $6D
.byte $00,$00,$00,$F8,$F8,$18,$18,$18	// #110 $6E
.byte $00,$00,$00,$00,$00,$00,$FF,$FF	// #111 $6F
.byte $00,$00,$00,$1F,$1F,$18,$18,$18	// #112 $70
.byte $18,$18,$18,$FF,$FF,$00,$00,$00	// #113 $71
.byte $00,$00,$00,$FF,$FF,$18,$18,$18	// #114 $72
.byte $18,$18,$18,$F8,$F8,$18,$18,$18	// #115 $73
.byte $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0	// #116 $74
.byte $E0,$E0,$E0,$E0,$E0,$E0,$E0,$E0	// #117 $75
.byte $07,$07,$07,$07,$07,$07,$07,$07	// #118 $76
.byte $FF,$FF,$00,$00,$00,$00,$00,$00	// #119 $77
.byte $FF,$FF,$FF,$00,$00,$00,$00,$00	// #120 $78
.byte $00,$00,$00,$00,$00,$FF,$FF,$FF	// #121 $79
.byte $03,$03,$03,$03,$03,$03,$FF,$FF	// #122 $7A
.byte $00,$00,$00,$00,$F0,$F0,$F0,$F0	// #123 $7B
.byte $0F,$0F,$0F,$0F,$00,$00,$00,$00	// #124 $7C
.byte $18,$18,$18,$F8,$F8,$00,$00,$00	// #125 $7D
.byte $F0,$F0,$F0,$F0,$00,$00,$00,$00	// #126 $7E
.byte $F0,$F0,$F0,$F0,$0F,$0F,$0F,$0F	// #127 $7F
.byte $C3,$99,$91,$91,$9F,$99,$C3,$FF	// #128 $80
.byte $E7,$C3,$99,$81,$99,$99,$99,$FF	// #129 $81
.byte $83,$99,$99,$83,$99,$99,$83,$FF	// #130 $82
.byte $C3,$99,$9F,$9F,$9F,$99,$C3,$FF	// #131 $83
.byte $87,$93,$99,$99,$99,$93,$87,$FF	// #132 $84
.byte $81,$9F,$9F,$87,$9F,$9F,$81,$FF	// #133 $85
.byte $81,$9F,$9F,$87,$9F,$9F,$9F,$FF	// #134 $86
.byte $C3,$99,$9F,$91,$99,$99,$C3,$FF	// #135 $87
.byte $99,$99,$99,$81,$99,$99,$99,$FF	// #136 $88
.byte $C3,$E7,$E7,$E7,$E7,$E7,$C3,$FF	// #137 $89
.byte $E1,$F3,$F3,$F3,$F3,$93,$C7,$FF	// #138 $8A
.byte $99,$93,$87,$8F,$87,$93,$99,$FF	// #139 $8B
.byte $9F,$9F,$9F,$9F,$9F,$9F,$81,$FF	// #140 $8C
.byte $9C,$88,$80,$94,$9C,$9C,$9C,$FF	// #141 $8D
.byte $99,$89,$81,$81,$91,$99,$99,$FF	// #142 $8E
.byte $C3,$99,$99,$99,$99,$99,$C3,$FF	// #143 $8F
.byte $83,$99,$99,$83,$9F,$9F,$9F,$FF	// #144 $90
.byte $C3,$99,$99,$99,$99,$C3,$F1,$FF	// #145 $91
.byte $83,$99,$99,$83,$87,$93,$99,$FF	// #146 $92
.byte $C3,$99,$9F,$C3,$F9,$99,$C3,$FF	// #147 $93
.byte $81,$E7,$E7,$E7,$E7,$E7,$E7,$FF	// #148 $94
.byte $99,$99,$99,$99,$99,$99,$C3,$FF	// #149 $95
.byte $99,$99,$99,$99,$99,$C3,$E7,$FF	// #150 $96
.byte $9C,$9C,$9C,$94,$80,$88,$9C,$FF	// #151 $97
.byte $99,$99,$C3,$E7,$C3,$99,$99,$FF	// #152 $98
.byte $99,$99,$99,$C3,$E7,$E7,$E7,$FF	// #153 $99
.byte $81,$F9,$F3,$E7,$CF,$9F,$81,$FF	// #154 $9A
.byte $C3,$CF,$CF,$CF,$CF,$CF,$C3,$FF	// #155 $9B
.byte $F3,$ED,$CF,$83,$CF,$9D,$03,$FF	// #156 $9C
.byte $C3,$F3,$F3,$F3,$F3,$F3,$C3,$FF	// #157 $9D
.byte $FF,$E7,$C3,$81,$E7,$E7,$E7,$E7	// #158 $9E
.byte $FF,$EF,$CF,$80,$80,$CF,$EF,$FF	// #159 $9F
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF	// #160 $A0
.byte $E7,$E7,$E7,$E7,$FF,$FF,$E7,$FF	// #161 $A1
.byte $99,$99,$99,$FF,$FF,$FF,$FF,$FF	// #162 $A2
.byte $99,$99,$00,$99,$00,$99,$99,$FF	// #163 $A3
.byte $E7,$C1,$9F,$C3,$F9,$83,$E7,$FF	// #164 $A4
.byte $9D,$99,$F3,$E7,$CF,$99,$B9,$FF	// #165 $A5
.byte $C3,$99,$C3,$C7,$98,$99,$C0,$FF	// #166 $A6
.byte $F9,$F3,$E7,$FF,$FF,$FF,$FF,$FF	// #167 $A7
.byte $F3,$E7,$CF,$CF,$CF,$E7,$F3,$FF	// #168 $A8
.byte $CF,$E7,$F3,$F3,$F3,$E7,$CF,$FF	// #169 $A9
.byte $FF,$99,$C3,$00,$C3,$99,$FF,$FF	// #170 $AA
.byte $FF,$E7,$E7,$81,$E7,$E7,$FF,$FF	// #171 $AB
.byte $FF,$FF,$FF,$FF,$FF,$E7,$E7,$CF	// #172 $AC
.byte $FF,$FF,$FF,$81,$FF,$FF,$FF,$FF	// #173 $AD
.byte $FF,$FF,$FF,$FF,$FF,$E7,$E7,$FF	// #174 $AE
.byte $FF,$FC,$F9,$F3,$E7,$CF,$9F,$FF	// #175 $AF
.byte $C3,$99,$91,$89,$99,$99,$C3,$FF	// #176 $B0
.byte $E7,$E7,$C7,$E7,$E7,$E7,$81,$FF	// #177 $B1
.byte $C3,$99,$F9,$F3,$CF,$9F,$81,$FF	// #178 $B2
.byte $C3,$99,$F9,$E3,$F9,$99,$C3,$FF	// #179 $B3
.byte $F9,$F1,$E1,$99,$80,$F9,$F9,$FF	// #180 $B4
.byte $81,$9F,$83,$F9,$F9,$99,$C3,$FF	// #181 $B5
.byte $C3,$99,$9F,$83,$99,$99,$C3,$FF	// #182 $B6
.byte $81,$99,$F3,$E7,$E7,$E7,$E7,$FF	// #183 $B7
.byte $C3,$99,$99,$C3,$99,$99,$C3,$FF	// #184 $B8
.byte $C3,$99,$99,$C1,$F9,$99,$C3,$FF	// #185 $B9
.byte $FF,$FF,$E7,$FF,$FF,$E7,$FF,$FF	// #186 $BA
.byte $FF,$FF,$E7,$FF,$FF,$E7,$E7,$CF	// #187 $BB
.byte $F1,$E7,$CF,$9F,$CF,$E7,$F1,$FF	// #188 $BC
.byte $FF,$FF,$81,$FF,$81,$FF,$FF,$FF	// #189 $BD
.byte $8F,$E7,$F3,$F9,$F3,$E7,$8F,$FF	// #190 $BE
.byte $C3,$99,$F9,$F3,$E7,$FF,$E7,$FF	// #191 $BF
.byte $FF,$FF,$FF,$00,$00,$FF,$FF,$FF	// #192 $C0
.byte $F7,$E3,$C1,$80,$80,$E3,$C1,$FF	// #193 $C1
.byte $E7,$E7,$E7,$E7,$E7,$E7,$E7,$E7	// #194 $C2
.byte $FF,$FF,$FF,$00,$00,$FF,$FF,$FF	// #195 $C3
.byte $FF,$FF,$00,$00,$FF,$FF,$FF,$FF	// #196 $C4
.byte $FF,$00,$00,$FF,$FF,$FF,$FF,$FF	// #197 $C5
.byte $FF,$FF,$FF,$FF,$00,$00,$FF,$FF	// #198 $C6
.byte $CF,$CF,$CF,$CF,$CF,$CF,$CF,$CF	// #199 $C7
.byte $F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3	// #200 $C8
.byte $FF,$FF,$FF,$1F,$0F,$C7,$E7,$E7	// #201 $C9
.byte $E7,$E7,$E3,$F0,$F8,$FF,$FF,$FF	// #202 $CA
.byte $E7,$E7,$C7,$0F,$1F,$FF,$FF,$FF	// #203 $CB
.byte $3F,$3F,$3F,$3F,$3F,$3F,$00,$00	// #204 $CC
.byte $3F,$1F,$8F,$C7,$E3,$F1,$F8,$FC	// #205 $CD
.byte $FC,$F8,$F1,$E3,$C7,$8F,$1F,$3F	// #206 $CE
.byte $00,$00,$3F,$3F,$3F,$3F,$3F,$3F	// #207 $CF
.byte $00,$00,$FC,$FC,$FC,$FC,$FC,$FC	// #208 $D0
.byte $FF,$C3,$81,$81,$81,$81,$C3,$FF	// #209 $D1
.byte $FF,$FF,$FF,$FF,$FF,$00,$00,$FF	// #210 $D2
.byte $C9,$80,$80,$80,$C1,$E3,$F7,$FF	// #211 $D3
.byte $9F,$9F,$9F,$9F,$9F,$9F,$9F,$9F	// #212 $D4
.byte $FF,$FF,$FF,$F8,$F0,$E3,$E7,$E7	// #213 $D5
.byte $3C,$18,$81,$C3,$C3,$81,$18,$3C	// #214 $D6
.byte $FF,$C3,$81,$99,$99,$81,$C3,$FF	// #215 $D7
.byte $E7,$E7,$99,$99,$E7,$E7,$C3,$FF	// #216 $D8
.byte $F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9	// #217 $D9
.byte $F7,$E3,$C1,$80,$C1,$E3,$F7,$FF	// #218 $DA
.byte $E7,$E7,$E7,$00,$00,$E7,$E7,$E7	// #219 $DB
.byte $3F,$3F,$CF,$CF,$3F,$3F,$CF,$CF	// #220 $DC
.byte $E7,$E7,$E7,$E7,$E7,$E7,$E7,$E7	// #221 $DD
.byte $FF,$FF,$FC,$C1,$89,$C9,$C9,$FF	// #222 $DE
.byte $00,$80,$C0,$E0,$F0,$F8,$FC,$FE	// #223 $DF
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF	// #224 $E0
.byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F	// #225 $E1
.byte $FF,$FF,$FF,$FF,$00,$00,$00,$00	// #226 $E2
.byte $00,$FF,$FF,$FF,$FF,$FF,$FF,$FF	// #227 $E3
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$00	// #228 $E4
.byte $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F	// #229 $E5
.byte $33,$33,$CC,$CC,$33,$33,$CC,$CC	// #230 $E6
.byte $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC	// #231 $E7
.byte $FF,$FF,$FF,$FF,$33,$33,$CC,$CC	// #232 $E8
.byte $00,$01,$03,$07,$0F,$1F,$3F,$7F	// #233 $E9
.byte $FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC	// #234 $EA
.byte $E7,$E7,$E7,$E0,$E0,$E7,$E7,$E7	// #235 $EB
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FC,$FC	// #236 $EC
.byte $E7,$E7,$E7,$E0,$E0,$FF,$FF,$FF	// #237 $ED
.byte $FF,$FF,$FF,$07,$07,$E7,$E7,$E7	// #238 $EE
.byte $FF,$FF,$FF,$FF,$FF,$FF,$00,$00	// #239 $EF
.byte $FF,$FF,$FF,$E0,$E0,$E7,$E7,$E7	// #240 $F0
.byte $E7,$E7,$E7,$00,$00,$FF,$FF,$FF	// #241 $F1
.byte $FF,$FF,$FF,$00,$00,$E7,$E7,$E7	// #242 $F2
.byte $E7,$E7,$E7,$07,$07,$E7,$E7,$E7	// #243 $F3
.byte $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3F	// #244 $F4
.byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F	// #245 $F5
.byte $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8	// #246 $F6
.byte $00,$00,$FF,$FF,$FF,$FF,$FF,$FF	// #247 $F7
.byte $00,$00,$00,$FF,$FF,$FF,$FF,$FF	// #248 $F8
.byte $FF,$FF,$FF,$FF,$FF,$00,$00,$00	// #249 $F9
.byte $FC,$FC,$FC,$FC,$FC,$FC,$00,$00	// #250 $FA
.byte $FF,$FF,$FF,$FF,$FF,$FF,$3F,$3F	// #251 $FB
.byte $FC,$FC,$FF,$FF,$FF,$FF,$FF,$FF	// #252 $FC
.byte $E7,$E7,$E7,$07,$07,$FF,$FF,$FF	// #253 $FD
.byte $3F,$3F,$FF,$FF,$FF,$FF,$FF,$FF	// #254 $FE
.byte $0F,$0F,$0F,$0F,$F0,$F0,$F0,$F0	// #255 $FF

.align $100
*=*     "hamiltonian cycle"     // to store the cell numbers for the generated hamiltonian cycle
cycle:  .fill 2048, $00