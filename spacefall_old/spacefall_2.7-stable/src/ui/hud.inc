.segment "CODE"

HudText_HI: .byte TILE_H, TILE_I, TILE_SPACE
HudText_SC: .byte TILE_S, TILE_C, TILE_SPACE

HUD_QueueUpdate:
  ; ---- queue "HI " ----
  lda #<HudText_HI
  sta ptr0
  lda #>HudText_HI
  sta ptr0+1
  lda #HUD_NT_HI
  ldx #HUD_HI_LO
  ldy #3
  jsr TextQ_QueueWrite

  ; ---- queue HI digits ----
  lda hi_d0
  sta tmp0
  lda hi_d1
  sta tmp1
  lda hi_d2
  sta tmp2
  lda hi_d3
  sta tmp3
  lda hi_d4
  sta tmp4
  jsr HUD_FillDigits5

  lda #<hud_digits_buf
  sta ptr0
  lda #>hud_digits_buf
  sta ptr0+1
  lda #HUD_NT_HI
  ldx #HUD_HI_DIG_LO
  ldy #5
  jsr TextQ_QueueWrite

  ; ---- queue "SC " ----
  lda #<HudText_SC
  sta ptr0
  lda #>HudText_SC
  sta ptr0+1
  lda #HUD_NT_HI
  ldx #HUD_SC_LO
  ldy #3
  jsr TextQ_QueueWrite

  ; ---- queue SCORE digits ----
  lda score_d0
  sta tmp0
  lda score_d1
  sta tmp1
  lda score_d2
  sta tmp2
  lda score_d3
  sta tmp3
  lda score_d4
  sta tmp4
  jsr HUD_FillDigits5

  lda #<hud_digits_buf
  sta ptr0
  lda #>hud_digits_buf
  sta ptr0+1
  lda #HUD_NT_HI
  ldx #HUD_SC_DIG_LO
  ldy #5
  jsr TextQ_QueueWrite

  ; ---- queue hearts ----
  jsr HUD_FillHearts
  lda #<hud_hearts_buf
  sta ptr0
  lda #>hud_hearts_buf
  sta ptr0+1
  lda #HUD_NT_HI
  ldx #HUD_LIVES_LO
  ldy #(HUD_MAX_LIVES*2-1)
  jsr TextQ_QueueWrite

  rts


HUD_Init:
  ; init high score digits to 00000 (once per boot; or keep across runs)
  lda hi_d0
  ora hi_d1
  ora hi_d2
  ora hi_d3
  ora hi_d4
  bne :+
    lda #$00
    sta hi_d0
    sta hi_d1
    sta hi_d2
    sta hi_d3
    sta hi_d4
:

  lda #$01
  sta hud_dirty
  rts

HUD_MarkDirty:
  lda #$01
  sta hud_dirty
  rts

; ============================================================
; HUD (BG TILE UI)
;
; Flow:
;   - Gameplay sets hud_dirty=1 whenever score/lives changes.
;   - NMI calls HUD_NMI_Update when hud_dirty is set.
;   - HUD_NMI_Update writes digits + hearts into the HUD nametable region.
; ============================================================

; ------------------------------------------------------------
; HUD_NMI_Update (VBlank)
; - Writes HUD text + digits + hearts as BG tiles
; - Runs only when hud_dirty=1
; - Always resets scroll latch after VRAM writes
; ------------------------------------------------------------
HUD_NMI_Update:
  lda hud_dirty
  bne :+
  rts
:
  lda #$00
  sta hud_dirty

  ; ---------- write "HI " ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_HI_LO
  sta PPUADDR

  lda #TILE_H
  sta PPUDATA
  lda #TILE_I
  sta PPUDATA
  lda #TILE_SPACE          ; space
  sta PPUDATA

  ; ---------- write HI digits (5) ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_HI_DIG_LO
  sta PPUADDR

  lda hi_d0
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  lda hi_d1
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  lda hi_d2
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  lda hi_d3
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  lda hi_d4
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA

  ; ---------- write "SC " ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_SC_LO
  sta PPUADDR

  lda #TILE_S
  sta PPUDATA
  lda #TILE_C
  sta PPUDATA
  lda #TILE_SPACE          ; space
  sta PPUDATA

  ; ---------- write SCORE digits (5) ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_SC_DIG_LO
  sta PPUADDR

  lda score_d0
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  lda score_d1
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  lda score_d2
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  lda score_d3
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  lda score_d4
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA

   ; ---------- write lives hearts (HUD_MAX_LIVES) with spaces ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_LIVES_LO
  sta PPUADDR

  lda lives
  cmp #HUD_MAX_LIVES
  bcc :+
    lda #HUD_MAX_LIVES
:
  sta tmp0


  ldx #$00              ; X = heart index (0..HUD_MAX_LIVES-1)
@heart_loop:
  cpx #HUD_MAX_LIVES
  bcs @hearts_done

  ; if (lives > X) draw heart else blank
  lda tmp0              ; A = lives
  cmp #$01              ; (optional micro-guard; can remove)
  ; not needed, keep going

  lda tmp0
  cpx tmp0              ; can't compare X to mem directly on 6502, so do it this way:
  ; ---- do: A=lives; compare to (X+1) ----
  ; We'll compute (X+1) in A2:
  ; (Simpler approach below)

  ; --- simpler: compute (X+1) into A and compare lives ---
  txa
  clc
  adc #$01              ; A = X+1
  sta tmp1              ; tmp1 = X+1

  lda tmp0              ; A = lives
  cmp tmp1              ; lives >= (X+1) ?
  bcc @blank

  lda #TILE_HEART_FULL
  bne @write

@blank:
  lda #$00

@write:
  sta PPUDATA           ; write heart/blank

  ; space after each heart except the last
  inx
  cpx #HUD_MAX_LIVES
  beq @heart_loop       ; last one: no trailing space

  lda #$00
  sta PPUDATA
  jmp @heart_loop

@hearts_done:

rts



UpdateHighScoreIfNeeded:
  ; if score > highscore, copy score_d* -> hi_d*
  lda score_d0
  cmp hi_d0
  bcc @no
  bne @yes

  lda score_d1
  cmp hi_d1
  bcc @no
  bne @yes

  lda score_d2
  cmp hi_d2
  bcc @no
  bne @yes

  lda score_d3
  cmp hi_d3
  bcc @no
  bne @yes

  lda score_d4
  cmp hi_d4
  bcc @no
  ; equal or greater => if equal, no need, if greater here it’s “equal” case
  beq @no

@yes:
  lda score_d0
  sta hi_d0
  lda score_d1
  sta hi_d1
  lda score_d2
  sta hi_d2
  lda score_d3
  sta hi_d3
  lda score_d4
  sta hi_d4
  jsr HUD_MarkDirty
@no:
  rts


; ptr0 -> hud_digits_buf, fills 5 tiles = TILE_DIGIT_BASE + digit
HUD_FillDigits5:
  lda tmp0       ; digit0
  clc
  adc #TILE_DIGIT_BASE
  sta hud_digits_buf+0
  lda tmp1
  clc
  adc #TILE_DIGIT_BASE
  sta hud_digits_buf+1
  lda tmp2
  clc
  adc #TILE_DIGIT_BASE
  sta hud_digits_buf+2
  lda tmp3
  clc
  adc #TILE_DIGIT_BASE
  sta hud_digits_buf+3
  lda tmp4
  clc
  adc #TILE_DIGIT_BASE
  sta hud_digits_buf+4
  rts

HUD_FillHearts:
  ; tmp0 = lives clamped
  lda lives
  cmp #HUD_MAX_LIVES
  bcc :+
    lda #HUD_MAX_LIVES
:
  sta tmp0

  ldx #$00        ; heart index 0..HUD_MAX_LIVES-1
  ldy #$00        ; write index into hud_hearts_buf

@hloop:
  cpx #HUD_MAX_LIVES
  bcs @done

  ; if lives >= (X+1) => heart else space
  txa
  clc
  adc #$01
  sta tmp1

  lda tmp0
  cmp tmp1
  bcc @blank
    lda #TILE_HEART_FULL
    bne @write
@blank:
  lda #TILE_SPACE

@write:
  sta hud_hearts_buf,y
  iny

  inx
  cpx #HUD_MAX_LIVES
  beq @hloop       ; last heart: no trailing space

  lda #TILE_SPACE
  sta hud_hearts_buf,y
  iny
  jmp @hloop

@done:
  rts

