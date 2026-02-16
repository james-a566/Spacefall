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

State_BossIntro:

  ; ----------------------------
  ; Build/queue text ONCE
  ; ----------------------------
  lda boss_intro_built
  bne @run

    lda #$01
    sta boss_intro_built

    jsr TextQ_Clear

    lda #<Str_BossWarning
    sta ptr0
    lda #>Str_BossWarning
    sta ptr0+1

    lda #BOSS_INTRO_TEXT_HI
    ldx #BOSS_INTRO_TEXT_LO
    jsr TextQ_QueueStrZ

    jsr TextQ_End

@run:
  lda boss_intro_timer
  beq @go_boss
  dec boss_intro_timer

  jsr BuildOAM
  jmp MainLoop

@go_boss:
  ; ----------------------------
  ; Clear intro text (queue once)
  ; ----------------------------
  jsr TextQ_Clear
  jsr BossIntro_QueueClearText
  jsr TextQ_End

  ; ----------------------------
  ; Clear the playfield + spawn boss
  ; ----------------------------
  jsr ClearEnemies
  jsr ClearCatch
  jsr ClearPlayerBullets
  jsr ClearBossBullets

  jsr BossSpawn

  lda #$00
  sta boss_intro_built      ; so next time you enter, it rebuilds
  lda #STATE_BOSS
  sta game_state

  jsr BuildOAM
  jmp MainLoop


Str_BossWarning:
  .byte TILE_B, TILE_O, TILE_S, TILE_S, TILE_SPACE
  .byte TILE_A, TILE_P, TILE_P, TILE_R, TILE_O, TILE_A, TILE_C, TILE_H, TILE_I,TILE_N, TILE_G
  .byte $00

; Clears exactly the same region your boss intro text uses.
; Uses TextQ_QueueFill to write blank tiles.

BossIntro_QueueClearText:
  lda #$00
  sta tmp0                 ; fill tile = blank (or TILE_SPACE)

  lda #BOSS_INTRO_TEXT_HI
  ldx #BOSS_INTRO_TEXT_LO
  ldy #BOSS_INTRO_TEXT_LEN
  jsr TextQ_QueueFill
  rts

