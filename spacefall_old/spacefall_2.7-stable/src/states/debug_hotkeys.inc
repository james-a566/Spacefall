.segment "CODE"

.if DEBUG_BOSS_SKIP

DebugHotkeys_Frame:
  lda pad1_new
  and #BTN_SELECT_START
  cmp #BTN_SELECT_START
  bne @done

  lda game_state
  cmp #STATE_TITLE
  beq @done

  jsr DebugJumpToBoss
@done:
  rts
  
.endif
