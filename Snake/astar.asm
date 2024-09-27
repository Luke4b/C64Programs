BasicUpstart2(start)

.var tmp_lsb = $FA              //
.var tmp_msb = $FB              // 

.label screen = $0400
.label wall = $A0
.label head = $56
.label food = $51

// cycle wraps at 960 ($03BF)

start:
jsr clear_screen

draw_head:
    ldx the_row
    ldy the_column
    lda screen_table, x
    sta tmp_lsb
    lda screen_table + 25, x
    sta tmp_msb
    lda #head
    sta (tmp_lsb), y

get_head_cycle:
    lda cycle_table, x
    sta tmp_lsb
    lda cycle_table + 25, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta head_lsb
    lda cycle_msb_table, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta head_msb

    ldx #$00
    jsr PrintHexValue
    lda head_lsb
    jsr PrintHexValue

draw_food:
    ldx tmprow
    ldy tmpcol
    lda screen_table, x
    sta tmp_lsb
    lda screen_table + 25, x
    sta tmp_msb
    lda #food
    sta (tmp_lsb), y

get_food_cycle:
    lda cycle_table, x
    sta tmp_lsb
    lda cycle_table + 25, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta food_lsb
    lda cycle_msb_table, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta food_msb

    ldx #$05
    jsr PrintHexValue
    lda head_lsb
    jsr PrintHexValue

// head must not overtake the tail
// head must not overtake food if it hasn't already

draw_walls:

    // initiate coordinates
    ldx #$00
    ldy #$00

    // store screen location in screen_lsb/msb
    lda screen_table, x
    sta screen_lsb
    lda screen_table + 25, x
    sta screen_msb

    // store cycle number in thing_lsb/msb
    lda cycle_table, x
    sta tmp_lsb
    lda cycle_table + 25, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta thing_lsb
    lda cycle_msb_table, x
    sta tmp_msb
    lda (tmp_lsb), y
    sta thing_msb

    //compare with food's cycle number
    lda thing_msb
    cmp food_msb
    bcc less_than
    lda thing_lsb
    cmp food_lsb
    bcc less_than
    jmp greater_than
less_than:
    //compare with tail's cycle number
    lda thing_msb
    cmp tail_msb
    bcc decrement
    lda thing_lsb
    cmp tail_lsb
    bcc decrement


greater_than:   // 
    ldy #$00
    lda screen_lsb
    sta tmp_lsb
    lda screen_msb
    sta tmp_msb
    lda #wall
    sta (tmp_lsb), y


decrement:

jmp *

clear_screen:
    ldx #$00
    lda #$20
!:  sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    dex
    bne !-
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

screen_lsb: .byte $00
screen_msb: .byte $00
temp:       .byte $00
tmprow:     .byte $15
tmpcol:     .byte $20
the_row:    .byte $05
the_column: .byte $02
head_lsb:   .byte $00
head_msb:   .byte $20
length_lsb: .byte $10
length_msb: .byte $01
food_lsb:   .byte $20

food_msb:   .byte $10
tail_lsb:   .byte $00
tail_msb:   .byte $00
thing_lsb:  .byte $00
thing_msb:  .byte $00

// tables
.align $100
screen_table:   .lohifill 25, screen + [i * 40]
cycle_table:          .lohifill 25, cycle + [i*40]
cycle_msb_table:      .fill 25, $04 + >[cycle + [i*40]]

//hamiltonian cycle
.align $100
* = * "cycle"
cycle:  .import binary "goodloop.bin"