; ============================
; hud.s — reusable HUD module (BG)
; Contract:
; - Tile $00 is blank (space)
; - Digits at DIGIT_TILE_BASE ($10..$19)
; - Letters at $20..$27 (S C O R E L I V)
; - Call HUD_NMI from NMI (vblank) for VRAM updates
; ; HUD module assumptions:
; - Uses BG nametable 0
; - Writes tiles only (no attributes)
; - Expects tile $00 to be blank
; - Expects digits at $10–$19
; - Safe to call HUD_NMI every frame
; ============================

.export HUD_Init, HUD_DrawStatic, HUD_NMI
.export HUD_IncScore, HUD_SetLives
.include "src/common.inc"
.include "src/tiles.inc"

; ----------------------------
; HUD layout (tile coords)
; ----------------------------
LIVES_LABEL_X = 2
LIVES_X       = 2      ; hearts aligned under the L
LIVES_Y       = 2
LIVES_VAL_Y   = 3

SCORE_LABEL_X = 18
SCORE_X       = 18     ; digits aligned under the S
SCORE_Y       = 2
SCORE_VAL_Y   = 3


HUD_MAX_LIVES = 8      ; pick 3/5/9 etc. (5 looks nice)


; ----------------------------
; ZEROPAGE (HUD state)
; ----------------------------
.segment "ZEROPAGE"
hud_score_hi:     .res 1     ; packed BCD: thousands/hundreds
hud_score_lo:     .res 1     ; packed BCD: tens/ones
hud_score_dirty:  .res 1

hud_lives:        .res 1     ; 0..9
hud_lives_dirty:  .res 1

hud_tmp:          .res 1
hud_vram_lo:      .res 1
hud_vram_hi:      .res 1

; ----------------------------
; CODE
; ----------------------------
.segment "CODE"



; Public: initialize HUD values + mark dirty
HUD_Init:
  lda #$00
  sta hud_score_hi
  sta hud_score_lo
  sta hud_lives

  lda #$01
  sta hud_score_dirty
  sta hud_lives_dirty
  rts




; Public: draw static labels ("LIVES " and "SCORE ")
; Call during init while rendering is OFF (or during vblank)
HUD_DrawStatic:
  ; "SCORE " at (SCORE_LABEL_X, SCORE_Y)
  ldx #SCORE_LABEL_X
  ldy #SCORE_Y
  jsr HUD_SetNT0Addr_XY

  lda #TILE_LETTER_S
  jsr HUD_PutA
  lda #TILE_LETTER_C
  jsr HUD_PutA
  lda #TILE_LETTER_O
  jsr HUD_PutA
  lda #TILE_LETTER_R
  jsr HUD_PutA
  lda #TILE_LETTER_E
  jsr HUD_PutA
  lda #TILE_BLANK
  jsr HUD_PutA   ; space

  ; "LIVES " at (LIVES_LABEL_X, LIVES_Y)
  ldx #LIVES_LABEL_X
  ldy #LIVES_Y
  jsr HUD_SetNT0Addr_XY

  lda #TILE_LETTER_L
  jsr HUD_PutA
  lda #TILE_LETTER_I
  jsr HUD_PutA
  lda #TILE_LETTER_V
  jsr HUD_PutA
  lda #TILE_LETTER_E
  jsr HUD_PutA
  lda #TILE_LETTER_S
  jsr HUD_PutA
  lda #TILE_BLANK
  jsr HUD_PutA   ; space
  rts


; Public: call from NMI (vblank) — redraw if dirty
HUD_NMI:
  lda hud_score_dirty
  beq @no_score
    lda #$00
    sta hud_score_dirty
    jsr HUD_DrawScore4
@no_score:

  lda hud_lives_dirty
  beq @no_lives
    lda #$00
    sta hud_lives_dirty
    jsr HUD_DrawLivesHearts
@no_lives:
  rts

; Public: score++
HUD_IncScore:
  ; increment ones
  lda hud_score_lo
  clc
  adc #$01
  sta hud_score_lo

  lda hud_score_lo
  and #$0F
  cmp #$0A
  bcc @mark

  ; carry to tens
  lda hud_score_lo
  and #$F0
  sta hud_score_lo

  lda hud_score_lo
  clc
  adc #$10
  sta hud_score_lo

  lda hud_score_lo
  and #$F0
  cmp #$A0
  bcc @mark

  ; carry to hundreds
  lda hud_score_lo
  and #$0F
  sta hud_score_lo

  lda hud_score_hi
  clc
  adc #$01
  sta hud_score_hi

  lda hud_score_hi
  and #$0F
  cmp #$0A
  bcc @mark

  ; carry to thousands
  lda hud_score_hi
  and #$F0
  sta hud_score_hi

  lda hud_score_hi
  clc
  adc #$10
  sta hud_score_hi

  lda hud_score_hi
  and #$F0
  cmp #$A0
  bcc @mark

  ; wrap 9999 -> 0000
  lda #$00
  sta hud_score_hi
  sta hud_score_lo

@mark:
  lda #$01
  sta hud_score_dirty
  rts

; Public: set lives = A (0..9)
HUD_SetLives:
  and #$0F              ; keep 0..15
  cmp #HUD_MAX_LIVES
  bcc :+
    lda #HUD_MAX_LIVES
:
  sta hud_lives
  lda #$01
  sta hud_lives_dirty
  rts



; --- internal: draw score at SCORE_X/SCORE_Y ---
HUD_DrawScore4:
  ldx #SCORE_X
  ldy #SCORE_VAL_Y
  jsr HUD_SetNT0Addr_XY

  ; thousands
  lda hud_score_hi
  lsr a
  lsr a
  lsr a
  lsr a
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA

  ; hundreds
  lda hud_score_hi
  and #$0F
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA

  ; tens
  lda hud_score_lo
  lsr a
  lsr a
  lsr a
  lsr a
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA

  ; ones
  lda hud_score_lo
  and #$0F
  clc
  adc #TILE_DIGIT_BASE
  sta PPUDATA
  rts

; --- internal: draw lives as hearts at LIVES_X/LIVES_Y ---
HUD_DrawLivesHearts:
  ldx #LIVES_X
  ldy #LIVES_VAL_Y
  jsr HUD_SetNT0Addr_XY

  ldx #$00
@loop:
  cpx #HUD_MAX_LIVES
  beq @done

  txa
  cmp hud_lives
  bcc @draw_heart
    lda #TILE_BLANK
    jmp @put_heart
@draw_heart:
  lda #TILE_HEART
@put_heart:
  sta PPUDATA

  lda #TILE_BLANK         ; spacer
  sta PPUDATA

  inx
  jmp @loop

@done:
  rts




; --- internal: convenience write ---
HUD_PutA:
  sta PPUDATA
  rts

; --- internal: set NT0 addr from tile X,Y (0..31,0..29) ---
HUD_SetNT0Addr_XY:
  stx hud_vram_lo
  lda #$00
  sta hud_vram_hi

  tya
  sta hud_tmp

  lda hud_tmp
  sta hud_vram_lo
  lda #$00
  sta hud_vram_hi

  asl hud_vram_lo
  rol hud_vram_hi
  asl hud_vram_lo
  rol hud_vram_hi
  asl hud_vram_lo
  rol hud_vram_hi
  asl hud_vram_lo
  rol hud_vram_hi
  asl hud_vram_lo
  rol hud_vram_hi        ; *32

  txa
  clc
  adc hud_vram_lo
  sta hud_vram_lo
  lda hud_vram_hi
  adc #NT0_BASE_HI              ; + $2000
  sta hud_vram_hi

  lda PPUSTATUS
  lda hud_vram_hi
  sta PPUADDR
  lda hud_vram_lo
  sta PPUADDR
  rts
