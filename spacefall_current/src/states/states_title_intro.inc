.segment "CODE"

; ----------------------------
; STATE: TITLE
; ----------------------------
State_Title:

  ; ---- music ----
  lda #MUSIC_TITLE
  cmp current_music
  beq :+
    sta current_music
    jsr Music_Play
:

  jsr NextRand

  ; ---- build title screen once ----
  lda title_built
  bne @title_run

    jsr PPU_BeginVRAM
      jsr ClearNametable0
      jsr DrawStarfieldNT0
      jsr ClearAttributesNT0

      lda #<TextPage_Title
      sta ptr1
      lda #>TextPage_Title
      sta ptr1+1
      jsr Text_DrawPage_Manual
    jsr PPU_EndVRAM

    lda #$01
    sta title_built

@title_run:

  ; ---- START press (do this BEFORE exiting the state) ----
  lda pad1_new
  and #BTN_START
  beq @no_start

    jsr ReseedRNG
    jsr ResetRun
    jsr EnterIntro

    jsr TextQ_End
    jsr BuildOAM
    jmp MainLoop

@no_start:

  ; --------------------------------------------------
  ; PRESS START blink (queue-based)
  ; --------------------------------------------------
  lda frame_lo
  and #$10
  beq @ps_hide

@ps_show:
  lda press_visible
  cmp #$01
  beq @ps_done
  lda #$01
  sta press_visible

  lda #<Str_PressStart
  sta ptr0
  lda #>Str_PressStart
  sta ptr0+1
  lda #PRESS_NT_HI
  ldx #PRESS_NT_LO
  jsr TextQ_QueueWriteZ
  jmp @ps_done

@ps_hide:
  lda press_visible
  beq @ps_done
  lda #$00
  sta press_visible

  lda #<BlinkBlanks
  sta ptr0
  lda #>BlinkBlanks
  sta ptr0+1
  lda #PRESS_NT_HI
  ldx #PRESS_NT_LO
  ldy #PRESS_NT_LEN
  jsr TextQ_QueueWrite

@ps_done:
  jsr TextQ_End
  jsr BuildOAM
  jmp MainLoop



; ----------------------------
; STATE: INTRO (multi-page)
; ----------------------------
State_Intro:

  ; --- build once on entry ---
  lda intro_built
  bne @intro_run

  lda #$00
  sta intro_page

  lda #INTRO_PAGE_FRAMES
  sta intro_timer

  ; draw starfield + first page
  jsr PPU_BeginVRAM
    jsr ClearNametable0
    jsr DrawStarfieldNT0
    jsr ClearAttributesNT0

    ldx intro_page
    txa
    asl
    tax
    lda IntroPageTable,x
    sta ptr1
    lda IntroPageTable+1,x
    sta ptr1+1
    jsr Text_DrawPage_Manual
  jsr PPU_EndVRAM

  lda #$01
  sta intro_built

@intro_run:

  ; --- auto-advance timer ---
  lda intro_timer
  beq @maybe_advance
  dec intro_timer

@maybe_advance:

  ; advance if timer hit 0 OR player presses A/START
  lda pad1_new
  and #(BTN_A | BTN_START)
  bne @advance

  lda intro_timer
  bne @intro_render
  jmp @advance

@advance:
  inc intro_page

  lda intro_page
  cmp #4
  bcc @draw_next

  ; finished intro -> go to tutorial
  lda #$00
  sta tutorial_built
  lda #240
  sta tutorial_timer

  lda #STATE_TUTORIAL
  sta game_state

  jmp @intro_render

@draw_next:
  lda #INTRO_PAGE_FRAMES
  sta intro_timer

  jsr PPU_BeginVRAM
    jsr ClearNametable0
    jsr DrawStarfieldNT0
    jsr ClearAttributesNT0

    ldx intro_page
    txa
    asl
    tax
    lda IntroPageTable,x
    sta ptr1
    lda IntroPageTable+1,x
    sta ptr1+1
    jsr Text_DrawPage_Manual
  jsr PPU_EndVRAM

@intro_render:
  jsr BuildOAM
  jmp MainLoop



; ---------------------------
; STATE: TUTORIAL
; ---------------------------
State_Tutorial:
  lda tutorial_built
  bne @tut_run

    jsr PPU_BeginVRAM
      jsr ClearNametable0
      jsr DrawStarfieldNT0
      jsr ClearAttributesNT0

      lda #<TextPage_Tutorial1
      sta ptr1
      lda #>TextPage_Tutorial1
      sta ptr1+1
      jsr Text_DrawPage_Manual
    jsr PPU_EndVRAM

    lda #$01
    sta tutorial_built

@tut_run:
  jsr UpdatePlayer

  lda tutorial_timer
  beq :+
    dec tutorial_timer
:

  lda pad1_new
  and #BTN_START
  beq :+
    lda #$00
    sta tutorial_timer
:

  lda tutorial_timer
  bne @tut_render

  ; --- timer hit 0: leave tutorial ---
  lda #$01
  sta tutorial_done

  lda #$00
  sta tutorial_built

  jsr EnterLevelStart
  lda #120
  sta level_banner

  lda #$00
  sta banner_built

  lda #STATE_BANNER
  sta game_state

  jmp State_Banner

@tut_render:
  jsr TextQ_End
  jsr BuildOAM
  jmp MainLoop
