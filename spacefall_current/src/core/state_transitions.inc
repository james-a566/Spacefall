.segment "CODE"

ReturnToTitle:
  jsr TextQ_Reset     

  lda #$00
  sta player_blink_timer
  sta jam_flash_timer
  sta catch_pickup_flash
  sta screen_flash_timer

  lda #$00
  sta title_inited
  sta title_built
  sta press_visible
  sta title_visible

  sta intro_built
  sta tutorial_built
  sta banner_built
  sta gameover_built

  ; --- hard rebuild NT0 NOW (no garbage frame) ---
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

  lda #STATE_TITLE
  sta game_state
  rts




; ----------------------------
; ResetRun
; - prepares a new run (called at boot and on restart)
; ----------------------------
ResetRun:

  lda #$00
  sta player_blink_timer
  sta jam_flash_timer
  sta catch_pickup_flash
  sta screen_flash_timer

  lda #$01
  sta hud_dirty


  ; ---- clear catch objects ----
  ldx #$00
@clr_catch:
  cpx #CATCH_MAX
  bcs @clr_catch_done
  lda #$00
  sta catch_alive,x
  sta catch_x,x
  sta catch_y,x
  inx
  bne @clr_catch
@clr_catch_done:

  ; ---- seed catch spawn cooldown ----

  lda #STATE_PLAY
  sta paused_prev_state


lda #$00          ; start in normal mode
sta debug_force_type

  lda #FLAG_SET
  sta boss_hp_clear_pending


  
  sta boss_alive
  sta boss_hp
  sta boss_hp_max



  lda #$00       ; starting level
  sta level_idx
 jsr LoadLevelParams

   jsr ReseedCatchSpawn

  jsr ClearActors          ; (ok)

  lda #60
  sta level_banner
  lda #STATE_BANNER
  sta game_state

  ; use level params for spawns/timing
  lda level_spawn_cd
  sta spawn_cd
  lda boss_time_lo
  sta boss_timer_lo
  lda boss_time_hi
  sta boss_timer_hi

  ; player
  lda #$78
  sta player_x
  lda #$B8
  sta player_y
  lda #$00
  sta player_cd
  sta gun_side
  sta invuln_timer
  sta good_flash_timer
  lda #$00
sta catch_pickup_flash


  ; score digits
  lda #$00
  sta score_d0
  sta score_d1
  sta score_d2
  sta score_d3
  sta score_d4

  lda #$03         ; starting lives
  sta lives

  ; clear bullets
  ldx #$00
@clr_bul:
  cpx #BULLET_MAX
  bcs @clr_bul_done
  lda #$00
  sta bul_alive,x
  sta bul_x,x
  sta bul_y,x
  sta bul_y_prev,x
  inx
  bne @clr_bul
@clr_bul_done:

  ; clear enemies
  ldx #$00
@clr_ene:
  cpx #ENEMY_MAX
  bcs @clr_ene_done
  lda #$00
  sta ene_alive,x
  sta ene_x,x
  sta ene_y,x
  sta ene_y_prev,x
  sta ene_type,x
  inx
  bne @clr_ene
@clr_ene_done:

  jsr HUD_Init

  rts


; ------------------------------------------------------------
; PlayerSetOver
; - Common game-over transition
; ------------------------------------------------------------
PlayerSetOver:

  jsr ClearActors
  lda #STATE_OVER
  sta game_state

  lda #FLASH_HIT_FR
  sta screen_flash_timer

  lda #FLAG_SET
  sta boss_hp_clear_pending

  rts

  EnterIntro:

    lda #$00
  sta player_blink_timer
    sta jam_flash_timer
  sta catch_pickup_flash
  sta screen_flash_timer


  lda #STATE_INTRO
  sta game_state
  lda #$00
  sta intro_built
  sta intro_page
  rts

EnterLevelStart:
  lda tutorial_done
  bne @go_banner

  ; first time only: tutorial BEFORE banner
  lda #STATE_TUTORIAL
  sta game_state

  lda #$01
  sta tutorial_visible
  lda #180
  sta tutorial_timer
  lda #$01
  sta tutorial_dirty

  lda #$01
  sta hud_dirty

  rts


@go_banner:

jsr LoadCatchKindChances
  lda #60
  sta level_banner
  lda #STATE_BANNER
  sta game_state
  rts

RedrawStarfieldOnRestart:
  ; --- rendering OFF ---
  lda #$00
  sta PPUMASK

  jsr WaitVBlank        ; get safely into vblank

  jsr ReseedRNG         ; IMPORTANT: do this BEFORE drawing stars

  jsr PPU_BeginVRAM
  jsr ClearNametable0
  jsr DrawStarfieldNT0
  jsr ClearAttributesNT0
  jsr ClearNametable1
  jsr DrawStarfieldNT1
  jsr ClearAttributesNT1
  jsr PPU_EndVRAM


  ; clean scroll latch + set 0,0
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  ; --- rendering back ON ---
  lda #PPUMASK_BG_SPR
  sta PPUMASK
  rts

DoGameOver:
  jsr ClearActors
  lda #STATE_OVER
  sta game_state
  rts