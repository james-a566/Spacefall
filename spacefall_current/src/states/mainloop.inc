MainLoop:
  jsr WaitFrame

  ; RNG only needed for gameplay-ish states (tune if you want it elsewhere)
    lda game_state
  cmp #STATE_PLAY
  beq @do_rng
  cmp #STATE_BOSS
  beq @do_rng
  ; add boss intro if it uses RNG
  ; cmp #STATE_BOSS_INTRO
  ; beq @do_rng
  jmp @skip_rng
@do_rng:
  jsr NextRand
@skip_rng:

  jsr famistudio_update
  jsr ReadController1

.if DEBUG_SPAWN
  jsr DebugUpdate
.endif

.if DEBUG_BOSS_SKIP
  jsr DebugHotkeys_Frame
.endif

  lda game_state
  cmp #$09          ; number of entries (0..8)
  bcc :+
    lda #STATE_TITLE ;
    sta game_state
  :
  asl a
  tax
  lda StateJumpTable,x
  sta ptr0
  lda StateJumpTable+1,x
  sta ptr0+1
  jmp (ptr0)

StateJumpTable:
  .word State_Banner      ; $00
  .word State_Play        ; $01
  .word State_Boss        ; $02
  .word State_Over        ; $03
  .word State_Title       ; $04
  .word State_Pause       ; $05
  .word State_Tutorial    ; $06
  .word State_Intro       ; $07
  .word State_BossIntro   ; $08
