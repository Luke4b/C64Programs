BasicUpstart2(main)

* = $0810

main:
    jsr init
    jsr loop

init:
    ldx #$00 //colour to use
    ldy #$00 //screen position offset
    lda #$00
    sta $FA  //character to use
    sta $FB  //screen page LSB
    sta $FD  //colour page LSB
    lda #$04
    sta $FC  //screen page MSB
    lda #$D8
    sta $FE //colour page MSB

loop:
    jsr delay
    txa
    sta ($FD),y  // write colour to screen
    jsr increment_colour
    lda $FA      // load character
    sta ($FB),y  // write to screen
    iny
    bne loop     // if y hasn't overflowed
    inc $FC      // otherwise increment pages
    inc $FE
    lda #$08
    cmp $FC
    bne loop
    lda #$04
    sta $FC
    lda #$D8
    sta $FE
    inc $FA
    jmp loop

increment_colour:
    inx
    cpx #$0F
    bne return
    ldx #$00
    rts
return: rts

delay:
    txa
    pha
    tya
    pha
    ldx #$44
    ldy #$01
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
