.segment "CODE"

; ----------------------------
; ScoreToDec5
; Converts score_hi:score_lo (0..65535) into 5 decimal digits
; Outputs: score_d0..score_d4
; Uses: tmp0..tmp4 (need 5 temp bytes)
; ----------------------------

ScoreToDec5:

  lda score_lo
  sta score_work_lo
  lda score_hi
  sta score_work_hi

  ; clear BCD digits (tmp0..tmp4 store 0-9 each)
  lda #$00
  sta tmp0
  sta tmp1
  sta tmp2
  sta tmp3
  sta tmp4

  ldx #$10              ; 16 bits to process

BitLoop:
  ; add-3 step for each digit if >=5
  lda tmp0
  cmp #$05
  bcc :+
  adc #$03
  sta tmp0
:
  lda tmp1
  cmp #$05
  bcc :+
  adc #$03
  sta tmp1
:
  lda tmp2
  cmp #$05
  bcc :+
  adc #$03
  sta tmp2
:
  lda tmp3
  cmp #$05
  bcc :+
  adc #$03
  sta tmp3
:
  lda tmp4
  cmp #$05
  bcc :+
  adc #$03
  sta tmp4
:

  ; shift left: [score_hi:score_lo] -> carry into ones digit chain
  asl score_work_lo
  rol score_work_hi

  ; now shift digits left (tmp0..tmp4), pulling in carry each time
  ; carry from score_hi becomes bit0 of tmp4 chain
  ; We implement digit shift by: (digit = digit*2 + carry) % 10 with carry-out.
  ; Since digits are 0-9, we can do it with ROL across packed bits by storing digits in binary and using BCD logic.
  ; Easier: shift as binary across 5 digits using bit carry via ROL-like method on 4-bit values:
  ;
  ; We'll do manual: start from least significant digit (tmp4 = ones)
  ;
  lda tmp4
  asl
  bcc :+
  ; (asl sets carry based on bit7, but our digits are small; carry from asl isn't what we want)
:
  ; Instead: use carry from rol score_hi directly:
  ; carry is already set from rol score_hi, so we do "digit = digit*2 + C", then fix if >=10.
  ; We'll do that pattern for tmp4..tmp0.

  ; ones
  lda tmp4
  asl
  adc #$00              ; add carry-in
  sta tmp4
  cmp #$0A
  bcc @no_c4
  sbc #$0A
  sta tmp4
  sec                    ; carry-out = 1
  bcs @c4_done
@no_c4:
  clc                    ; carry-out = 0
@c4_done:

  ; tens
  lda tmp3
  asl
  adc #$00
  sta tmp3
  cmp #$0A
  bcc @no_c3
  sbc #$0A
  sta tmp3
  sec
  bcs @c3_done
@no_c3:
  clc
@c3_done:

  ; hundreds
  lda tmp2
  asl
  adc #$00
  sta tmp2
  cmp #$0A
  bcc @no_c2
  sbc #$0A
  sta tmp2
  sec
  bcs @c2_done
@no_c2:
  clc
@c2_done:

  ; thousands
  lda tmp1
  asl
  adc #$00
  sta tmp1
  cmp #$0A
  bcc @no_c1
  sbc #$0A
  sta tmp1
  sec
  bcs @c1_done
@no_c1:
  clc
@c1_done:

  ; ten-thousands
  lda tmp0
  asl
  adc #$00
  sta tmp0
  cmp #$0A
  bcc @no_c0
  sbc #$0A
  sta tmp0
  ; carry-out ignored
@no_c0:

dex
beq :+
  jmp BitLoop
:


  ; copy to outputs
  lda tmp0
  sta score_d0
  lda tmp1
  sta score_d1
  lda tmp2
  sta score_d2
  lda tmp3
  sta score_d3
  lda tmp4
  sta score_d4
  rts



; ------------------------------------------------------------
; AddScore_TensOnes
;   Adds (tens, ones) to score_d4..d0
;   Input: A = tens, X = ones   (0..9 each)
;   Trashes: A
; ------------------------------------------------------------
AddScore_TensOnes:
  ; add ones -> d4
  txa
  clc
  adc score_d4
  cmp #10
  bcc :+
    sbc #10
    sta score_d4
    ; carry into tens
    lda score_d3
    clc
    adc #1
    cmp #10
    bcc @store_d3
      sbc #10
      sta score_d3
      jmp @carry_to_d2
:
  sta score_d4
  ; now add tens (A input) into d3
  lda score_d3
  clc
  adc tmp0          ; (we'll load tmp0 with tens before calling)
  cmp #10
  bcc @store_d3
    sbc #10
    sta score_d3
@carry_to_d2:
    lda score_d2
    clc
    adc #1
    cmp #10
    bcc @store_d2
      sbc #10
      sta score_d2
      ; cascade carry up
      lda score_d1
      clc
      adc #1
      cmp #10
      bcc @store_d1
        sbc #10
        sta score_d1
        lda score_d0
        clc
        adc #1
        cmp #10
        bcc @store_d0
          lda #9        ; clamp
@store_d0:
          sta score_d0
          jmp @done

@store_d3:
  sta score_d3
@store_d2:
  sta score_d2
@store_d1:
  sta score_d1
@done:
  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts

; ------------------------------------------------------------
; AddScoreHTO
; Adds tmp2:tmp1:tmp0 (hundreds:tens:ones) into score_d2..d4
; Carries upward, clamps score_d0 to 9.
; Trashes A
; ------------------------------------------------------------
AddScoreHTO:
  ; ---- ones -> d4 ----
  lda score_d4
  clc
  adc tmp0
  cmp #10
  bcc :+
    sbc #10
    sta score_d4
    lda #1
    bne @carry_to_tens
:
  sta score_d4
  lda #0
@carry_to_tens:
  sta tmp3          ; tmp3 = carry (0/1)

  ; ---- tens -> d3 ----
  lda score_d3
  clc
  adc tmp1
  adc tmp3
  cmp #10
  bcc :+
    sbc #10
    sta score_d3
    lda #1
    bne @carry_to_hund
:
  sta score_d3
  lda #0
@carry_to_hund:
  sta tmp3

  ; ---- hundreds -> d2 ----
  lda score_d2
  clc
  adc tmp2
  adc tmp3
  cmp #10
  bcc :+
    sbc #10
    sta score_d2
    lda #1
    bne @carry_to_thou
:
  sta score_d2
  lda #0
@carry_to_thou:
  sta tmp3

  ; ---- thousands -> d1 ----
  lda score_d1
  clc
  adc tmp3
  cmp #10
  bcc :+
    sbc #10
    sta score_d1
    lda #1
    bne @carry_to_tenth
:
  sta score_d1
  lda #0
@carry_to_tenth:
  sta tmp3

  ; ---- ten-thousands -> d0 (clamp) ----
  lda score_d0
  clc
  adc tmp3
  cmp #10
  bcc :+
    lda #9          ; clamp at 9
:
  sta score_d0

  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts

; ------------------------------------------------------------
; AddScoreA
;   Adds A points by calling AddScore1 A times
;   Input: A = points (0..9 recommended)
;   Trashes: A, tmp0
; ------------------------------------------------------------
AddScoreA:
  sta tmp0
  beq @done

@loop:
  jsr AddScore1
  dec tmp0
  bne @loop

@done:
  rts


; ------------------------------------------------------------
; AddScore5Digits
; Adds 5 base-10 digits from (tmp0,tmp1) into score_d4..score_d0
; Table format: [d4,d3,d2,d1,d0]
; ------------------------------------------------------------
AddScore5Digits:
  ldy #$00
  clc

  ; d4 (ones)
  lda score_d4
  adc (tmp0),y
  cmp #10
  bcc :+
    sbc #10
    sec
  :
  sta score_d4
  iny

  ; d3 (tens)
  lda score_d3
  adc (tmp0),y
  cmp #10
  bcc :+
    sbc #10
    sec
  :
  sta score_d3
  iny

  ; d2 (hundreds)
  lda score_d2
  adc (tmp0),y
  cmp #10
  bcc :+
    sbc #10
    sec
  :
  sta score_d2
  iny

  ; d1 (thousands)
  lda score_d1
  adc (tmp0),y
  cmp #10
  bcc :+
    sbc #10
    sec
  :
  sta score_d1
  iny

  ; d0 (ten-thousands) + clamp to 9
  lda score_d0
  adc (tmp0),y
  cmp #10
  bcc :+
    lda #9          ; clamp at 99999
  :
  sta score_d0

  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts

; ------------------------------------------------------------
; AddBossScore
; Adds bracketed boss score based on level_idx:
; 0..2  => bracket 0 (1000)
; 3..5  => bracket 1 (2000)
; 6..8  => bracket 2 (5000)
; 9..11 => bracket 3 (10000)
; ------------------------------------------------------------
AddBossScore:
  lda level_idx     ; 0..11
  ldx #$00          ; X = bracket

@div3_loop:
  cmp #3
  bcc @got_bracket
  sec
  sbc #3
  inx
  cpx #3
  bcc @div3_loop
  ; if somehow level_idx is >= 12, clamp bracket to 3
  ldx #3

@got_bracket:
  txa               ; A = X
  asl a             ; *2
  asl a             ; *4
  sta tmp0          ; save 4*X

  txa               ; A = X
  clc
  adc tmp0          ; X + 4X = 5X
  tay               ; Y = bracket * 5


  lda #<BossScoreDigits
  clc
  adc #0            ; (just to be explicit: no-op)
  sta tmp0
  lda #>BossScoreDigits
  sta tmp1

  ; add offset into pointer
  tya
  clc
  adc tmp0
  sta tmp0
  bcc :+
    inc tmp1
  :

  jsr AddScore5Digits
  rts


; ----------------------------
; AddScore1
; score_d4..score_d0 += 1 (base-10 with carry)
; ----------------------------
AddScore1:
  inc score_d4
  lda score_d4
  cmp #10
  bcc @done
  lda #0
  sta score_d4

  inc score_d3
  lda score_d3
  cmp #10
  bcc @done
  lda #0
  sta score_d3

  inc score_d2
  lda score_d2
  cmp #10
  bcc @done
  lda #0
  sta score_d2

  inc score_d1
  lda score_d1
  cmp #10
  bcc @done
  lda #0
  sta score_d1

  inc score_d0
  lda score_d0
  cmp #10
  bcc @done
  lda #9          ; clamp 
  sta score_d0

@done:
  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts



; Adds fixed points using AddScoreHTO
; expects: tmp2:tmp1:tmp0 = hundreds:tens:ones (0-9 each)
AddPointsHTO:
  jmp AddScoreHTO

Add100:
  lda #$01
  sta tmp2
  lda #$00
  sta tmp1
  sta tmp0
  jmp AddScoreHTO

Add500:
  lda #$05
  sta tmp2
  lda #$00
  sta tmp1
  sta tmp0
  jmp AddScoreHTO

Add1000:
  ; 1000 = add carry into thousands (d1) in your 5-digit system
  ; easiest: add 1 to score_d1 with carry handling
  inc score_d1
  lda score_d1
  cmp #10
  bcc @done
  lda #0
  sta score_d1
  inc score_d0
  lda score_d0
  cmp #10
  bcc @done
  lda #9
  sta score_d0
@done:
  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts


; ------------------------------------------------------------
; ClearEnemiesAddScore
; - For each alive enemy:
;     add its score
;     kill it
; ------------------------------------------------------------
ClearEnemiesAddScore:
  ldx #$00
@loop:
  cpx #ENEMY_MAX
  bcs @done

  lda ene_alive,x
  beq @next

  ; ---- add score based on ene_type,x ----
  ; This mirrors your EnemyScore_HTO lookup approach.
  ; tmp2/tmp1/tmp0 = H:T:O for AddScoreHTO

  ; clamp/guard type if you need it
  ldy ene_type,x
  cpy #$05
  bcc :+
    ldy #EN_A
:

  ; index = type * 3
  tya
  asl a          ; *2
  clc
  adc ene_type,x ; +type => *3
  tay

  lda EnemyScore_HTO,y
  sta tmp2
  lda EnemyScore_HTO+1,y
  sta tmp1
  lda EnemyScore_HTO+2,y
  sta tmp0
  jsr AddScoreHTO

  ; ---- kill enemy ----
  lda #$00
  sta ene_alive,x

@next:
  inx
  bne @loop
@done:
  rts
