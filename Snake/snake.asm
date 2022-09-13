BasicUpstart2(main)

* = $0810

main:    
    jsr init
    jsr loop

init:
    lda #$FF  // maximum frequency value
    sta $D40E // voice 3 frequency low byte
    sta $D40F // voice 3 frequency high byte
    lda #$80  // noise waveform, gate bit off
    sta $D412 // voice 3 control register

    lda #$00
    sta $FA  // direction, 0 = up then clockwise
    sta $FB  // last keypress
    sta $FE  // snake length
    sta $080F  // food_flag
    sta $080E  // reset_flag

    lda #$F4 //head low byte
    sta $FC
    lda #$05 //head high byte
    sta $FD

    lda #$93          //clear screen character
    jsr $FFD2

loop:
    jsr read_keyb
    jsr step
    jsr check_bounds
    jsr food
    jsr snake_length
    jsr delay

    lda $080E
    cmp #$01   // check the reset flag
    bne loop
    jmp init

snake_length:
    lda $FE
    sta $0400
    rts

step:  // move the head one step in the correct direction
    lda $FA         // load direction
    ldy #$00
    sta ($FC),y     // draw the head
    cmp #$00
    beq !up+
    cmp #$01
    beq !right+
    cmp #$02
    beq !down+
    cmp #$03
    beq !left+
    rts
!up:
    sec         // set carry
    lda $FC     // low byte
    sbc #$28    // sub decimal 40 for row above
    sta $FC
    lda $FD         // high byte
    sbc #$00
    sta $FD
    rts
!left:
    sec         // set carry
    lda $FC     // low byte
    sbc #$01    // sub 01 for column left
    sta $FC
    lda $FD     // high byte
    sbc #$00
    sta $FD
    rts
!right:
    lda $FC     // low byte
    adc #$00    // add 01 for column right
    sta $FC
    lda $FD     // high byte
    adc #$00
    sta $FD
    rts
!down:
    lda $FC     // low byte
    adc #$27    // add decimal 40 for rown below
    sta $FC
    lda $FD     // high byte
    adc #$00
    sta $FD
    rts

read_keyb:   // reads keyboard input and changes the direction accordingly
    lda $c5  // load top of keyboard buffer
    sta $FB  // store keypress
    lda #$01
    and $FA  // check if direction is horizontal
    bne horiz
    // if direction is not horizontal, must be vertical so left right apply.
    lda $FB
    cmp #$0A  // 'a' = left
    beq !left+
    cmp #$12  // 'f' = right
    beq !right+
    rts
horiz:  // if direction is horizontal, up and down apply.
    lda $FB
    cmp #$09  // 'w' = up
    beq !up+
    cmp #$0D  // 's' = down
    beq !down+
    rts
!left:
    lda #$03
    sta $FA
    rts
!right:
    lda #$01
    sta $FA
    rts
!up:
    lda #$00
    sta $FA
    rts
!down:
    lda #$02
    sta $FA
    rts


food:
    lda $080F       // food flag, 0 means there's no food currently on the board
    cmp #$00
    beq spawn       // if there's no food, jump to spawn routine
    ldy #$00
    lda ($FC),y     // load head position in screen ram
    cmp #$06        // check if that has food, character 'F'
    beq fed
    rts
fed:
    inc $FE         // increment snake length
    lda #$00
    sta $080F       // set food flag to 00 (no food)
    rts
spawn:              // spawns a food in a random location
    lda #$01
    sta $080F       // set the food flag to 01 (there is food)
    ldy $D41B       // get random number from SID
    lda #$06        // character 'F'
    sta ($FC),y
    rts


check_bounds:
    // check left/right of screen
    lda $FA  // load direction
    cmp #$01
    beq !right+
    cmp #$03
    beq !left+  // if direction is neither left or right
                // check bottom/top of screen
                // check page (screen ram $0400-$07E7)
    lda $FD     //load high bit (page)
    cmp #$03
    beq out_of_bounds
    cmp #$08
    beq out_of_bounds
    cmp #$07
    beq last_page
    rts
last_page:
    lda $FC   //load low bit
    cmp #$E8
    beq out_of_bounds
    rts
!right:
    rts
!left:
    rts
out_of_bounds:
    lda #$01    //set the reset flag
    sta $080E
    rts

delay:
    txa
    pha
    tya
    pha
    ldx #$FF
    ldy #$50
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