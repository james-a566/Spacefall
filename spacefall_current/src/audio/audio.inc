.segment "CODE"

; A = song id (MUSIC_*)
Music_Play:
  cmp music_cur
  beq @done          ; already playing this
  sta music_cur
  jsr famistudio_music_play
@done:
  rts

Music_Stop:
  lda #MUSIC_NONE
  sta music_cur
  jsr famistudio_music_stop
  rts


; ------------------------------------------------------------
; PlaySfxFS
; - A = sfx id
; - X = famistudio channel (0..?)
; ------------------------------------------------------------
PlaySfxFS:
  jsr famistudio_sfx_play
  rts






SFX_FIRING    = 0
SFX_EXPLODE   = 1
SFX_OVER      = 2
SFX_JAMCLICK  = 3
SFX_DRY       = 4
SFX_ENEMY_HIT = 5
SFX_PLAYER_HIT= 6
SFX_PICKUP    = 7
SFX_BOSS_SHOT = 8


PlaySfxFiring:
  lda #SFX_FIRING
  ldx #FAMISTUDIO_SFX_CH0    ; keep firing on slot 0
  jmp PlaySfxFS


PlaySfxExplode:
  lda #SFX_EXPLODE
  ldx #FAMISTUDIO_SFX_CH1    ; <-- stream/channel SLOT 1 (correct)
  jmp PlaySfxFS

PlaySFX_OVER:
  lda #SFX_OVER
  ldx #FAMISTUDIO_SFX_CH0
  jmp PlaySfxFS

PlaySfxJamClick:
  lda #SFX_JAMCLICK
  ldx #FAMISTUDIO_SFX_CH0
  jmp PlaySfxFS

PlaySfxDry:
  lda #SFX_DRY
  ldx #FAMISTUDIO_SFX_CH0
  jmp PlaySfxFS

PlaySfxEnemyHit:
  lda #SFX_ENEMY_HIT
  ldx #FAMISTUDIO_SFX_CH1
  jmp PlaySfxFS

PlaySfxPlayerHit:
  lda #SFX_PLAYER_HIT
  ldx #FAMISTUDIO_SFX_CH1
  jmp PlaySfxFS

PlaySfxPickup:
  lda #SFX_PICKUP
  ldx #FAMISTUDIO_SFX_CH0
  jmp PlaySfxFS

PlaySfxBossShot:
  lda #SFX_BOSS_SHOT
  ldx #FAMISTUDIO_SFX_CH0
  jmp PlaySfxFS