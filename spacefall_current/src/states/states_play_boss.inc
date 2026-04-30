.segment "CODE"

; ----------------------------
; STATE: BANNER
; ----------------------------
State_Banner:

  lda banner_built
  bne @banner_run

    jsr PPU_BeginVRAM
      jsr ClearNametable0
      jsr DrawStarfieldNT0
      jsr ClearAttributesNT0
      jsr SetUIAttrsNT0
      jsr SetBossBarAttrsNT0
    jsr PPU_EndVRAM

    lda #$01
    sta banner_built

@banner_run:
  jsr BannerUpdate
  jsr TextQ_EndIfDirty
  jsr BuildOAM
  jmp MainLoop



; ----------------------------
; STATE: PLAY
; ----------------------------
State_Play:

  lda #MUSIC_GAMEPLAY
  cmp current_music
  beq :+
    sta current_music
    jsr Music_Play
:

  ; ---- PAUSE TOGGLE ----
  lda pad1_new
  and #BTN_START
  beq :+
    lda #STATE_PLAY
    sta paused_prev_state
    lda #STATE_PAUSE
    sta game_state

    jsr famistudio_music_pause

    lda #$01
    sta pause_show
    lda #$01
    sta pause_dirty

    jmp @play_render_only
:

; ------------------------------------------------------------
; Final Core sequence
; Level 13 is not a normal gameplay level.
; It skips enemy spawning, normal catch spawning, and boss timer.
; The player must catch the final core to enter STATE_ENDING.
; ------------------------------------------------------------
  ; ---- FINAL LEVEL: only player + final core ----
    lda level_idx
  cmp #LEVEL_FINAL_IDX
  bne @normal_play_update

    jsr UpdateCatchPickupFlash
    jsr UpdateJamFlash
    jsr UpdatePlayer
    jsr UpdateBullets

      lda catch_alive
  bne :+
    jsr SpawnFinalCore
:

    jsr UpdateFinalCatch
    jsr CollidePlayerCatch

    jmp @play_render_only

@normal_play_update:
  jsr UpdateCatchPickupFlash
  jsr UpdateJamFlash
  jsr UpdatePlayer
  jsr UpdateBullets

  lda bul_any
  beq :+
    lda catch_any
    beq :+
      jsr CollideBulletsCatch
:

  jsr UpdateShield
  jsr UpdateEnemies

  jsr UpdateCatch
  lda catch_any
  beq :+
    jsr CollidePlayerCatch
:

  lda ene_any
  beq :+
    jsr CollidePlayerEnemies
:

  lda bul_any
  beq :+
    lda ene_any
    beq :+
      jsr CollideBulletsEnemies
:

  jsr PlayUpdate

@play_render_only:
  jsr TextQ_EndIfDirty
  jsr BuildOAM
  jmp MainLoop



; ----------------------------
; STATE: BOSS
; ----------------------------
State_Boss:

  lda bossbar_visible
  beq :+
    lda bossbar_dirty
    beq :+
      lda #$00
      sta bossbar_dirty
      jsr BossBar_QueueUpdate

:

  lda #MUSIC_BOSS
  cmp current_music
  beq :+
    sta current_music
    jsr Music_Play
:

  lda pad1_new
  and #BTN_START
  beq :+
    lda game_state
    sta paused_prev_state
    lda #STATE_PAUSE
    sta game_state

    jsr famistudio_music_pause

    lda #$01
    sta pause_show
    lda #$01
    sta pause_dirty

    lda #$00
    sta pause_inited
    jmp @boss_render_only
:

  jsr UpdateCatchPickupFlash
  jsr UpdateShield

  jsr UpdateJamFlash
  jsr UpdatePlayer
  jsr UpdateBullets

jsr UpdateCatch
lda catch_any
beq :+
  jsr CollidePlayerCatch
:

lda bul_any
beq :+
  lda catch_any
  beq :+
    jsr CollideBulletsCatch
:

  jsr BossUpdate
  jsr BossBigAttackFX
  jsr UpdateBossBullets
  jsr CheckPlayerHitByBossBullets
  jsr CollideBulletsBoss

@boss_render_only:
  jsr TextQ_EndIfDirty
  jsr BuildOAM
  jmp MainLoop


State_BossIntro:

  lda boss_intro_built
  bne @run

  ; ----------------------------
  ; Entry: clear playfield actors NOW
  ; ----------------------------
  jsr ClearEnemies
  jsr ClearCatch
  jsr ClearPlayerBullets
  jsr ClearBossBullets

  lda #$01
  sta boss_intro_built

  lda #$00
  sta boss_intro_blink
  sta boss_intro_lastphase

  ; queue initial draw (visible)
  jsr TextQ_Clear

  lda #<Str_BossLine1
  sta ptr0
  lda #>Str_BossLine1
  sta ptr0+1
  lda #BOSS1_HI
  ldx #BOSS1_LO
  jsr TextQ_QueueStrZ

  lda #<Str_BossLine2
  sta ptr0
  lda #>Str_BossLine2
  sta ptr0+1
  lda #BOSS2_HI
  ldx #BOSS2_LO
  jsr TextQ_QueueStrZ

  jsr TextQ_End

@run:
  ; ----------------------------
  ; Blink phase (toggle every 16 frames)
  ; phase = (frame_lo & $10) ? 1 : 0
  ; ----------------------------
  lda frame_lo
  and #$10
  beq @phase0
  lda #$01
  bne @phase_ok
@phase0:
  lda #$00
@phase_ok:
  cmp boss_intro_lastphase
  beq @timer          ; same phase -> no new VRAM writes

  sta boss_intro_lastphase

  ; queue either text or blanks
  jsr TextQ_Clear

  lda boss_intro_lastphase
  beq @queue_text

@queue_blanks:
  lda #TILE_SPACE
  sta tmp0

  lda #BOSS1_HI
  ldx #BOSS1_LO
  ldy #BOSS_LINE1_LEN
  jsr TextQ_QueueFill

  lda #BOSS2_HI
  ldx #BOSS2_LO
  ldy #BOSS_LINE2_LEN
  jsr TextQ_QueueFill

  jsr TextQ_End
  jmp @timer

@queue_text:
  lda #<Str_BossLine1
  sta ptr0
  lda #>Str_BossLine1
  sta ptr0+1
  lda #BOSS1_HI
  ldx #BOSS1_LO
  jsr TextQ_QueueStrZ

  lda #<Str_BossLine2
  sta ptr0
  lda #>Str_BossLine2
  sta ptr0+1
  lda #BOSS2_HI
  ldx #BOSS2_LO
  jsr TextQ_QueueStrZ

  jsr TextQ_End

@timer:
  lda boss_intro_timer
  beq @go_boss
  dec boss_intro_timer

  jsr BuildOAM
  jmp MainLoop

@go_boss:
  ; clear the two lines once before leaving
  jsr TextQ_Clear

  lda #TILE_SPACE
  sta tmp0
  lda #BOSS1_HI
  ldx #BOSS1_LO
  ldy #BOSS_LINE1_LEN
  jsr TextQ_QueueFill

  lda #BOSS2_HI
  ldx #BOSS2_LO
  ldy #BOSS_LINE2_LEN
  jsr TextQ_QueueFill

  jsr TextQ_End

  ; spawn boss + switch state
  jsr BossSpawn
  lda #$00
  sta boss_intro_built
  lda #STATE_BOSS
  sta game_state

  jsr BuildOAM
  jmp MainLoop



State_BossDefeated:
  lda boss_defeat_built
  bne @run

  ; ----------------------------
  ; one-time init on entry
  ; ----------------------------
  lda #$01
  sta boss_defeat_built

  lda #120                 ; 2 seconds (tune)
  sta boss_defeat_timer

  ; clear the playfield so it feels like a clean victory beat
  jsr ClearEnemies
  jsr ClearCatch
  jsr ClearPlayerBullets
  jsr ClearBossBullets

  ; queue text once
  jsr TextQ_Clear

  lda #<Str_ThreatDefeated
  sta ptr0
  lda #>Str_ThreatDefeated
  sta ptr0+1

  lda #BOSS_DEFEAT_HI
  ldx #BOSS_DEFEAT_LO
  jsr TextQ_QueueStrZ

  jsr TextQ_End
  jmp @render

@run:
  lda boss_defeat_timer
  beq @go_next
  dec boss_defeat_timer

  ; ----------------------------
  ; BLINK (optional)
  ; If you don't want blink, delete this whole block.
  ; ----------------------------
  lda frame_lo
  and #$10              ; toggle every 16 frames (tune: $08 faster, $20 slower)
  beq @blink_show

@blink_hide:
  jsr TextQ_Clear
  jsr BossDefeat_QueueClearText
  jsr TextQ_End
  jmp @render

@blink_show:
  jsr TextQ_Clear
  lda #<Str_ThreatDefeated
  sta ptr0
  lda #>Str_ThreatDefeated
  sta ptr0+1
  lda #BOSS_DEFEAT_HI
  ldx #BOSS_DEFEAT_LO
  jsr TextQ_QueueStrZ
  jsr TextQ_End
  ; fallthrough

@render:
  jsr BuildOAM
  jmp MainLoop

@go_next:
  ; clear the text once so it doesn't linger into banner
  jsr TextQ_Clear
  jsr BossDefeat_QueueClearText
  jsr TextQ_End

  lda #$00
  sta boss_defeat_built

  jsr NextLevel           ; your existing flow: LoadLevelParams + EnterLevelStart
  jsr BuildOAM
  jmp MainLoop

BossDefeat_QueueClearText:
  lda #$00
  sta tmp0                 ; blank tile (or TILE_SPACE if you prefer)

  lda #BOSS_DEFEAT_HI
  ldx #BOSS_DEFEAT_LO
  ldy #BOSS_DEFEAT_LEN
  jsr TextQ_QueueFill
  rts



State_Ending:
  lda ending_built
  bne @ending_run

    jsr PPU_BeginVRAM
      jsr ClearNametable0
      jsr DrawStarfieldNT0
      jsr ClearAttributesNT0
    jsr PPU_EndVRAM

    lda #$01
    sta ending_built
    lda #$00
    sta ending_step
    lda #$20
    sta ending_timer

@ending_run:
  lda ending_step
  cmp #$03
  bcs @input

  lda ending_timer
  beq @draw_next
  dec ending_timer
  jmp @input

@draw_next:
  jsr PPU_BeginVRAM

    lda ending_step
    cmp #$00
    bne :+
      lda #<TextPage_Ending1
      sta ptr1
      lda #>TextPage_Ending1
      sta ptr1+1
      jsr Text_DrawPage_Manual
      jmp @line_done
:
    cmp #$01
    bne :+
      lda #<TextPage_Ending2
      sta ptr1
      lda #>TextPage_Ending2
      sta ptr1+1
      jsr Text_DrawPage_Manual
      jmp @line_done
:
    lda #<TextPage_Ending3
    sta ptr1
    lda #>TextPage_Ending3
    sta ptr1+1
    jsr Text_DrawPage_Manual

@line_done:
  jsr PPU_EndVRAM

  inc ending_step
  lda #$30
  sta ending_timer

@input:
  lda pad1_new
  and #BTN_START
  beq @ending_draw

    jsr ReturnToTitle

@ending_draw:
  jsr BuildOAM
  jmp MainLoop