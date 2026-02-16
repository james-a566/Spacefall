.segment "CODE"

; ------------------------------------------------------------
; SafeDecrementLives
; - If lives > 0: lives -= 1
; - If lives becomes 0: triggers game over
; - Always marks HUD dirty
; ------------------------------------------------------------
SafeDecrementLives:
  lda lives
  beq @already_zero      ; don't underflow

  sec
  sbc #$01
  sta lives

  lda #FLAG_SET
  sta hud_dirty          ;

  lda lives
  bne @done

  ; ---- lives just hit 0 -> GAME OVER ----
  jsr PlayerSetOver       ; (see below)
  rts

@already_zero:
  jsr DoGameOver
@done:
  rts


AwardLifePlus1:
  lda lives
  cmp #HUD_MAX_LIVES
  bcs @done
  inc lives
  jsr HUD_MarkDirty
@done:
  rts
