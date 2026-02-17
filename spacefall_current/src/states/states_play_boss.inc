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





