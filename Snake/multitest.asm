BasicUpstart2(main)


.var bg_colour = $00    // background colour %0000 0000
.var brd_colour = $06   // border colour %0000 1011
.var bg_colour1 = $04
.var bg_colour2 = $0b   // shadow

main:   // fill screen with space characters $0400 - $07FF

    lda $D018 // set character memory to start from ram at $3000
    ora #$0c
    sta $d018

    lda $D016
    ora #%00010000
    sta $d016


    lda #bg_colour      // set background colour
    sta $d021
    lda #brd_colour
    sta $d020
    lda #bg_colour1
    sta $D022
    lda #bg_colour2
    sta $D023

    ldx #$00

cls_loop:
    lda #$02
  //  sta $0400,x
    sta $0500,x
    sta $0600,x
  //  sta $0700,x
    lda #%00001011
 //   sta $D800,x
    sta $D900,x
    sta $DA00,x
    dex
    bne cls_loop
    rts


*=$3000
blank_spc: .fill 8, $00                                 //$3000     char $00
verti_bod: .fill 8, $7e                                 //$3008     char $01
horiz_bod: .byte $b4, $b4, $94, $94, $9c, $9c, $bc, $bc //$3010     char $02