.segment "CODE"

LoadLevelParams:
  ; Y = level_idx * LEVEL_STRIDE (12)
  lda level_idx
  asl
  asl
  sta tmp0
  asl
  clc
  adc tmp0
  tay

  ; --- base 8 bytes ---
  lda LevelParams,y        ; [0] spawn_cd
  sta level_spawn_cd
  sta spawn_cd
  iny
  lda LevelParams,y        ; [1] enemy_spd
  sta level_enemy_spd
  iny
  lda LevelParams,y        ; [2] thrB
  sta level_thrB
  iny
  lda LevelParams,y        ; [3] thrC
  sta level_thrC
  iny
  lda LevelParams,y        ; [4] thrD
  sta level_thrD
  iny
  lda LevelParams,y        ; [5] thrE
  sta level_thrE
  iny
  lda LevelParams,y        ; [6] boss_lo
  sta boss_time_lo
  iny
  lda LevelParams,y        ; [7] boss_hi
  sta boss_time_hi
  iny

  ; --- new 4 knobs ---
  lda LevelParams,y        ; [8] ene_cd
  sta level_enemy_cd
  sta enemy_cd
  iny

  lda LevelParams,y        ; [9] catch_cd4 (units of 4 frames)
  sta level_catch_cd4
  iny

  lda LevelParams,y        ; [10] good_thr
  sta level_catch_good_thr
  iny

  lda LevelParams,y        ; [11] catch_cap
  sta level_catch_cap

  ; scale catch_cd4 -> catch_cd in frames (min 1 step => 4 frames)
  lda level_catch_cd4
  bne :+
    lda #$01
:
  asl                      ; *2
  asl                      ; *4
  sta catch_cd

  ; reset boss timer = boss_time
  lda boss_time_lo
  sta boss_timer_lo
  lda boss_time_hi
  sta boss_timer_hi

  jsr LoadCatchKindChances
  rts


LoadCatchKindChances:
  ldx level_idx
  cpx #12
  bcc :+
    ldx #11
:
  txa
  asl                 ; *2 (2 bytes per level)
  tax

  lda CatchKindParams,x
  sta level_thrFrac
  inx
  lda CatchKindParams,x
  sta level_thrFinal
  rts

NextLevel:
    lda #FLAG_SET
    sta boss_hp_clear_pending


    inc level_idx
    jsr LoadLevelParams
    jsr EnterLevelStart
    rts

BannerUpdate:
  lda level_banner
  beq @done_banner
  dec level_banner
  rts
@done_banner:
  lda #STATE_PLAY
  sta game_state
  
  rts


PlayUpdate:
  ; decrement boss timer and switch to boss
  lda boss_timer_lo
  bne @dec_lo
  lda boss_timer_hi
  beq @start_boss
  dec boss_timer_hi
  lda #$FF
  sta boss_timer_lo
  rts

@dec_lo:
  dec boss_timer_lo
  rts

@start_boss:
  ; Enter boss phase: set state, flash, clear actors, init boss, show HP bar.
  lda #STATE_BOSS
  sta game_state
  lda #FLASH_BOSS_START_FR
  sta screen_flash_timer

  jsr ClearActors
  jsr BossSpawn

  rts

