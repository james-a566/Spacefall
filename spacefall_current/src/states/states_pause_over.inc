.segment "CODE"

; ----------------------------
; STATE: OVER
; ----------------------------
State_Over:

  lda gameover_built
  bne @over_run

    lda #$01
    jsr famistudio_music_pause

    jsr PlaySFX_OVER

    lda #$00
    sta gameover_visible

    lda #$01
    sta gameover_blink_phase

    lda #$20
    sta gameover_blink_timer

    jsr PPU_BeginVRAM
      jsr ClearNametable0
      jsr DrawStarfieldNT0
      jsr ClearAttributesNT0
    jsr PPU_EndVRAM

    jsr TextQ_Reset

    lda #TILE_TEXT_BLANK
    sta tmp0
    lda #GAMEOVER_NT_HI
    ldx #GAMEOVER_NT_LO
    ldy #GAMEOVER_LEN
    jsr TextQ_QueueFill

    lda #$01
    sta gameover_built

@over_run:

  lda gameover_blink_phase
  beq @go_steady

  lda gameover_blink_timer
  beq @go_finish
  dec gameover_blink_timer

  lda gameover_blink_timer
  cmp #$11
  bcs @go_want_shown

@go_want_hidden:
  lda gameover_visible
  beq @go_done
  lda #$00
  sta gameover_visible

  lda #TILE_TEXT_BLANK
  sta tmp0
  lda #GAMEOVER_NT_HI
  ldx #GAMEOVER_NT_LO
  ldy #GAMEOVER_LEN
  jsr TextQ_QueueFill
  jmp @go_done

@go_want_shown:
  lda gameover_visible
  cmp #$01
  beq @go_done
  lda #$01
  sta gameover_visible

  lda #<Str_GameOver
  sta ptr0
  lda #>Str_GameOver
  sta ptr0+1
  lda #GAMEOVER_NT_HI
  ldx #GAMEOVER_NT_LO
  jsr TextQ_QueueWriteZ
  jmp @go_done

@go_finish:
  lda #$00
  sta gameover_blink_phase

@go_steady:
  lda gameover_visible
  cmp #$01
  beq @go_done
  lda #$01
  sta gameover_visible

  lda #<Str_GameOver
  sta ptr0
  lda #>Str_GameOver
  sta ptr0+1
  lda #GAMEOVER_NT_HI
  ldx #GAMEOVER_NT_LO
  jsr TextQ_QueueWriteZ

@go_done:

  lda pad1_new
  and #BTN_START
  beq @over_draw
    lda #$00
    sta gameover_built
    jsr ReturnToTitle

@over_draw:
  jsr TextQ_End
  jsr BuildOAM
  jmp MainLoop



; ---------------------------
; STATE: PAUSE
; ---------------------------
State_Pause:

  lda pad1_new
  and #BTN_START
  beq :+
    lda paused_prev_state
    sta game_state

    lda #$00
    jsr famistudio_music_pause

    lda #$00
    sta pause_show
    lda #$01
    sta pause_dirty

    lda pad1
    sta pad1_prev
:

  jsr TextQ_End
  jsr BuildOAM
  jmp MainLoop
