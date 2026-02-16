.segment "CODE"

; ------------------------------------------------------------
; [MAIN]
; ------------------------------------------------------------
MainLoop:
  jsr WaitFrame
  jsr famistudio_update
  jsr ReadController1

.if DEBUG_SPAWN
  ; --- DEBUG input handling ---
  jsr DebugUpdate
.endif

.if DEBUG_BOSS_SKIP
  jsr DebugHotkeys_Frame
.endif

; ------------------------------------------------------------
; State dispatch (game_state)
; ------------------------------------------------------------
  lda game_state
  cmp #STATE_TITLE
  bne :+
    jmp State_Title
  :
  cmp #STATE_INTRO
  bne :+
    jmp State_Intro
  :
  cmp #STATE_TUTORIAL
  bne :+
    jmp State_Tutorial
  :
  cmp #STATE_BANNER
  bne :+
    jmp State_Banner
  :
  cmp #STATE_PLAY
  bne :+
    jmp State_Play
  :

  cmp #STATE_BOSS_INTRO
  bne :+
    jmp State_BossIntro
:


  cmp #STATE_BOSS
  bne :+
    jmp State_Boss
  :
  cmp #STATE_PAUSE
  bne :+
    jmp State_Pause
  :

  jmp State_Over
