BasicUpstart2(main)

* = $0810 "program"

.var the_row = $FA            //
.var the_column = $FB         // 
.var screen_lsb = $FC         // screen address low .byte
.var screen_msb = $FD         // screen address high .byte
.var tmp_lsb = $FE          
.var tmp_msb = $FF   

.label width = 40          // maximum 40 must be even number
.label height = 24         // maximum 24 must be even number
.label random = $D41B       // address of random numbers from SID
.label block_char = $a0     

main:  {
    // set SID chip to generate white noise (random numbers)
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low .byte
    sta $D40F // voice 3 frequency high .byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    lda #$01  // initial direction right
    sta direction

    jsr clear_screen
    jsr maze_gen

    // start in the top left corner
    lda #$00
    sta the_row
    lda #$00
    sta the_column

loop:
    jsr draw
    jsr step
    jsr delay
    jmp loop
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
!:  lda random
    and #%00111111      // limit in size to 64
    cmp #[width / 2]
    bcs !-
    sta the_column
    jsr add_cell
    jsr add_adjacencies

maze_gen_loop:
    jsr pick_adjacent
    jsr create_passage
    lda adjacency_length
    bne maze_gen_loop
    rts

add_cell:                       // writes a block character to the screen
    ldx the_row
    lda maze_table, x
    sta tmp_lsb
    lda maze_table + 12, x
    sta tmp_msb
    ldy the_column
    lda #$01
    sta (tmp_lsb), y
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


add_adj_lists:    {   // check if cell is already in the maze, if not;
                      // check if already exists with adjacency list, 
                      // if not adds the cell (tmprow, tmpcol) to the lists and increments the length.
    ldx adjacency_length
    cpx #$00
    beq first             // the first time the length of the list will be zero, this skips directly to saving.

    ldx tmprow            // checks that this cell isn't already part of the maze.
    ldy tmpcol
    lda maze_table, x
    sta tmp_lsb
    lda maze_table + 12, x
    sta tmp_msb
    lda (tmp_lsb), y
    cmp #$01
    bne not_in_maze
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
    lda adjacency_columns, x
    sta the_column
    
    jsr add_cell            // add cell to maze (stored in screen ram)
    
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
    cmp #block_char
    beq !+
    jmp create_passage      // if not in the maze, try again
    
!:  ldx the_row
    ldy the_column
    lda row_walls_table, x
    sta tmp_lsb
    lda #>row_walls
    sta tmp_msb
    lda #$00
    sta (tmp_lsb), y
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
    cmp #block_char
    beq !+
    jmp create_passage      // if not in the maze, try again
    
!:  ldx the_column
    ldy tmprow
    lda column_walls_table, x
    sta tmp_lsb
    lda #>column_walls
    sta tmp_msb
    lda #$00
    sta (tmp_lsb), y
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
    cmp #block_char
    beq !+
    jmp create_passage      // if not in the maze, try again
    
!:  ldx the_column
    ldy the_row
    lda column_walls_table, x
    sta tmp_lsb
    lda #>column_walls
    sta tmp_msb
    lda #$00
    sta (tmp_lsb), y
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
    cmp #block_char
    beq !+
    jmp create_passage      // if not in the maze, try again

!:  ldx the_row
    ldy tmpcol
    lda row_walls_table, x
    sta tmp_lsb
    lda #>row_walls
    sta tmp_msb
    lda #$00
    sta (tmp_lsb), y
    jmp blah

check_maze:                 // check if the cell in this direction is in the maze
    ldx tmprow
    ldy tmpcol
    lda maze_table, x
    sta tmp_lsb
    lda maze_table + 12, x
    sta tmp_msb
    lda (tmp_lsb), y
    rts

blah:
    lda adjacency_length
    beq !+
    jsr add_adjacencies
!:  rts


}
}

draw:
    //get the screen location to draw to
    ldy the_row
    lda screen_table, y
    clc
    adc the_column
    sta screen_lsb
    lda screen_table + 25, y
    adc #$00
    sta screen_msb
    ldy #$00

    lda number
    sta (screen_lsb), y
    inc number
    jsr turn_left
    lda number
    cmp #$3A
    beq cycle
    rts

cycle:
    lda #$30        // reset number to zero character.
    sta number
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
    ldy #$10
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

temp:               .byte $00
number:             .byte $30
direction:          .byte $00
adjacency_length:   .byte $00
blank:              .byte $00
tmprow:             .byte $00
tmpcol:             .byte $00

* = $0c00 "tables"
screen_table:         .lohifill 25, $0400 + [i * 40]
column_walls_table:   .fill [width / 2], i * [[height / 2] -1]
row_walls_table:      .fill [height /2], i * [[width  / 2] -1]
maze_table:           .lohifill 12, $1000 + [i * 20]

// the maze is defined by the 3x3 grid, a wall is a 1, a passageway is 0
* = $0d00 "column_walls"    // $0c99    // can be maximum of 20 x 12 = 240 = $f0
column_walls:   .fill [[[width/2]-1]*[height/2]], $01

* = $0e00 "row_walls"      // $0d99
row_walls:      .fill [[width/2]*[[height/2]-1]], $01

* = $0f00 "adjacency rows"           // $0e99 maze adjacent cells, row records
adjacency_rows:     .fill 128, $00

* = $0f80 "adjacency columns"               // maze adjacent cells, column records
adjacency_columns:  .fill 128, $00

* = $1000 "maze"
maze:               .fill 240, $00