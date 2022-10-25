BasicUpstart2(main)

* = $0810 "program"

.var the_row = $FA            //
.var the_column = $FB         // 
.var screen_lsb = $FC         // screen address low .byte
.var screen_msb = $FD         // screen address high .byte 

.label width = 40          // maximum 40 must be even number
.label height = 24         // maximum 24 must be even number
.label random = $D41B       // address of random numbers from SID 

main:  {
    // set SID chip to generate white noise (random numbers)
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low .byte
    sta $D40F // voice 3 frequency high .byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    lda #$01
    sta block_char
!:
    jsr maze_gen
    inc block_char
    jsr !-

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
    lda screen_table, x
    sta screen_lsb
    lda screen_table + 25, x
    sta screen_msb
    ldy the_column
    lda block_char
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


add_adj_lists:    {   // check if cell is already in the maze, if not;
                      // check if already exists with adjacency list, 
                      // if not adds the cell (tmprow, tmpcol) to the lists and increments the length.
    ldx adjacency_length
    cpx #$00
    beq first             // the first time the length of the list will be zero, this skips directly to saving.

    ldx tmprow            // checks that this cell isn't already part of the maze.
    ldy tmpcol
    lda screen_table, x
    sta screen_lsb
    lda screen_table + 25, x
    sta screen_msb
    lda (screen_lsb), y
    cmp block_char
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
    beq !up+
    cmp #$01
    beq !down+
    cmp #$02
    beq !left+
!right:
    lda the_row
    sta tmprow
    lda the_column
    cmp #[[width /2] -1]
    beq create_passage      // if this is the rightmost column, try again with new random direction
    clc
    adc #$01
    sta tmpcol
    jsr check_maze          // loads 'a' reg with contents of (tmprow, tmpcol) from maze in screen ram
    cmp block_char
    bne create_passage      // if not in the maze, try again
    jmp blah
!up:
    lda the_row
    beq create_passage      // if this is the top row, try again with new random direction
    sec
    sbc #$01
    sta tmprow
    lda the_column
    sta tmpcol
    jsr check_maze          // loads 'a' reg with contents of (tmprow, tmpcol) from maze in screen ram
    cmp block_char
    bne create_passage      // if not in the maze, try again
    jmp blah
!down:
    lda the_row
    cmp #[[height/2] -1]
    beq create_passage      // if this is the bottom row, try again with new random direction
    clc
    adc #$01
    sta tmprow
    lda the_column
    sta tmpcol
    jsr check_maze          // loads 'a' reg with contents of (tmprow, tmpcol) from maze in screen ram
    cmp block_char
    bne create_passage      // if not in the maze, try again
    jmp blah
!left:
    lda the_row
    sta tmprow
    lda the_column
    beq create_passage      // if this is the leftmost column, try again with new random direction
    sec
    sbc #$01
    sta tmpcol
    jsr check_maze          // loads 'a' reg with contents of (tmprow, tmpcol) from maze in screen ram
    cmp block_char
    bne create_passage      // if not in the maze, try again
    jmp blah

check_maze: 
    ldx tmprow
    ldy tmpcol
    lda screen_table, x
    sta screen_lsb
    lda screen_table + 25, x
    sta screen_msb
    lda (screen_lsb), y
    rts

blah:
    lda adjacency_length
    beq !+
    jsr add_adjacencies
!:  rts


}
}

temp:               .byte $00
adjacency_length:   .byte $00
tmprow:             .byte $00
tmpcol:             .byte $00
block_char:         .byte $00

* = $0c00 "tables"
screen_table:         .lohifill 25, $0400 + [i * 40]

* = $0d00 "adjacency rows"           // $0e99 maze adjacent cells, row records
adjacency_rows:     .fill 128, $00

* = $0d80 "adjacency columns"               // maze adjacent cells, column records
adjacency_columns:  .fill 128, $00
