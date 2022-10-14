BasicUpstart2(main)

* = $0810

main:
        jsr initialise
        jsr loop

initialise:
        ldx #$00 // direction 0->3
        ldy #$00

        // store position in screen memory to zero page
        lda #$f4 //low byte
        sta $FD
        lda #$05 //high byte
        sta $FE
        
        lda #$93          //clear screen charater
        jsr $FFD2


loop:
        // check screen limits (approx)
        lda $FE
        cmp #$03
        bne asdf
        //lda #$07
        //sta $FE
        rts
asdf:
        lda $FE
        cmp #$08
        bne sdfg
        //lda #$04
        //sta $FE
        rts
sdfg:

        lda ($FD),y     // look at current contents at screen location
        sta $FC         // store for later

        lda #$57        // circle character code
        sta ($FD),y     // draw circle at screen location

        lda $FC         // retrieve character that was in location
        cmp #$20        // compare to empty square
        bne filled      // branch if location was filled

        inx             // increment x (turn cw)
        lda #$A0
        sta ($FD),y     // change screen location to filled square
        jmp prepstep
        
filled:
        dex             // decrement x (turn ccw)
        lda #$20
        sta ($FD),y     // change screen location to empty square

prepstep:
        cpx #$FF        // check if x has gone negative
        bne not_neg
        ldx #$03
        bne not_over

not_neg:                // check if x has gone over 3 (full rotation)
        cpx #$04
        bne not_over
        ldx #$00

not_over:               // branches for the different directions
        cpx #$00
        beq up
        cpx #$01
        beq right
        cpx #$02
        beq down
        cpx #$03
        beq left

up:
        sec
        lda $FD         // low byte
        sbc #$28
        sta $FD
        lda $FE         // high byte
        sbc #$00
        sta $FE
        jmp loop

right:
        clc
        lda $FD         // low byte
        adc #$01
        sta $FD
        lda $FE
        adc #$00
        sta $FE
        jmp loop

down:
        clc
        lda $FD         // low byte
        adc #$28
        sta $FD
        lda $FE
        adc #$00
        sta $FE
        jmp loop
        
left:
        sec
        lda $FD         // low byte
        sbc #$01
        sta $FD
        lda $FE         // high byte
        sbc #$00
        sta $FE
        jmp loop
