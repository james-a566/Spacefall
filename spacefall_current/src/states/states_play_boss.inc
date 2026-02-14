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
    jsr PPU_EndVRAM

    lda #$01
    sta banner_built

@banner_run:
  jsr BannerUpdate
  jsr TextQ_End
  jsr BuildOAM
  jmp MainLoop



; ----------------------------
; STATE: PLAY
; ----------------------------
State_Play:

  lda #$01
  sta hud_dirty

  lda #$00
  jsr famistudio_music_pause
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

  jsr UpdateCatchPickupFlash
  jsr UpdateJamFlash
  jsr UpdatePlayer
  jsr UpdateBullets
  jsr CollideBulletsCatch
  jsr UpdateShield

  jsr UpdateEnemies

  jsr UpdateCatch
  jsr CollidePlayerCatch

  jsr CollideBulletsEnemies
  jsr CollidePlayerEnemies
  jsr PlayUpdate

@play_render_only:
  jsr TextQ_End
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
      jsr TextQ_End
:

  lda #$01
  sta hud_dirty

  lda #$00
  jsr famistudio_music_pause
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
  jsr CollidePlayerCatch
  jsr CollideBulletsCatch

  jsr BossUpdate
  jsr BossBigAttackFX
  jsr UpdateBossBullets
  jsr CheckPlayerHitByBossBullets
  jsr CollideBulletsBoss

@boss_render_only:
  jsr TextQ_End
  jsr BuildOAM
  jmp MainLoop
