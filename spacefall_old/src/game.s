; src/game.s — gameplay module (code + state)

.include "src/common.inc"

.import HUD_Init, HUD_IncScore, HUD_SetLives

; main provides controller state + RNG seed (ZP)
.importzp pad1, pad1_new, rng_seed

.include "src/tiles.inc"



; ----------------------------
; Game-owned state
; ----------------------------
.segment "BSS"
.export lives, game_state
lives:      .res 1
game_state: .res 1

.segment "ZEROPAGE"
.export player_x, player_y, obj_x, obj_y, obj_active
player_x:   .res 1
player_y:   .res 1
obj_x:      .res 1
obj_y:      .res 1
obj_active: .res 1

absdx:      .res 1
absdy:      .res 1
spawn_cd:   .res 1
fall_spd:   .res 1
points:     .res 1

; ----------------------------
; Public entry points
; ----------------------------
.segment "CODE"
.export Game_Init
.export Game_Frame

Game_Init:
  lda #$00
  sta spawn_cd
  sta obj_active
  sta points

  lda #STATE_PLAY
  sta game_state

  lda #$01
  sta fall_spd

  lda #$80
  sta player_x
  lda #$B0
  sta player_y

  lda #START_LIVES
  sta lives
  lda lives
  jsr HUD_SetLives
  rts

Game_Frame:
  lda game_state
  cmp #STATE_TITLE
  bne :+
    jmp DoTitle
:
  cmp #STATE_PLAY
  bne :+
    jmp DoPlay
:
  jmp DoGameOver


; ----------------------------
; Gameplay states (migrated)
; ----------------------------
DoPlay:
  jsr RNG_Next

  ; cooldown tick
  lda spawn_cd
  beq :+
    dec spawn_cd
:

  ; movement
  lda pad1
  and #BTN_LEFT
  beq :+
    lda player_x
    beq :+
    sec
    sbc #$01
    sta player_x
:

  lda pad1
  and #BTN_RIGHT
  beq :+
    lda player_x
    cmp #$F8
    beq :+
    clc
    adc #$01
    sta player_x
:

  lda pad1
  and #BTN_UP
  beq :+
    lda player_y
    cmp #PLAYER_MIN_Y
    beq :+
    sec
    sbc #$01
    sta player_y
:

  lda pad1
  and #BTN_DOWN
  beq :+
    lda player_y
    cmp #PLAYER_MAX_Y
    beq :+
    clc
    adc #$01
    sta player_y
:

  jsr DrawPlayerSprite

  ; object update
  lda obj_active
  bne @fall

    lda spawn_cd
    bne @after_obj
    jsr SpawnObject
    jmp @after_obj

@fall:
  lda obj_y
  clc
  adc fall_spd
  sta obj_y

  lda obj_y
  cmp #OBJ_BOTTOM
  bcc @after_obj

  ; MISS
  lda #$00
  sta obj_active
  lda #$14
  sta spawn_cd

  lda lives
  beq @after_obj
  sec
  sbc #$01
  sta lives

  lda lives
  jsr HUD_SetLives

  lda lives
  bne @after_obj
    lda #STATE_GAMEOVER
    sta game_state

@after_obj:
  jsr CheckCatch
  jsr DrawObjectSprite
  rts


DoTitle:
  jsr RNG_Next
  lda pad1_new
  and #BTN_START
  beq :+
    jsr RestartGame
    lda #STATE_PLAY
    sta game_state
:
  rts


DoGameOver:
  jsr RNG_Next
  lda pad1_new
  and #BTN_START
  beq :+
    jsr RestartGame
    lda #STATE_PLAY
    sta game_state
:
  rts


; ----------------------------
; Helpers moved with gameplay
; ----------------------------
RestartGame:
  jsr HUD_Init

  lda #$80
  sta player_x
  lda #$B0
  sta player_y

  lda #START_LIVES
  sta lives
  lda lives
  jsr HUD_SetLives

  lda #$00
  sta obj_active
  sta spawn_cd

  lda #$01
  sta fall_spd
  rts


SpawnObject:
  lda lives
  beq @no_spawn

  jsr RNG_Next
  and #$F8
  sta obj_x

  lda #$20
  sta obj_y

  lda #$01
  sta obj_active
@no_spawn:
  rts


DrawPlayerSprite:
  lda player_y
  sta OAM_BUF+0
  lda #TILE_PLAYER
  sta OAM_BUF+1
  lda #SPR_ATTR_PAL0
  sta OAM_BUF+2
  lda player_x
  sta OAM_BUF+3
  rts


DrawObjectSprite:
  lda obj_active
  beq @hide

  lda obj_y
  sta OAM_BUF+4
  lda #TILE_SHIP_A
  sta OAM_BUF+5
  lda #SPR_ATTR_PAL1
  sta OAM_BUF+6
  lda obj_x
  sta OAM_BUF+7
  rts

@hide:
  lda #$FF
  sta OAM_BUF+4
  rts


CheckCatch:
  lda obj_active
  beq @no

  ; abs(dy)
  lda obj_y
  sec
  sbc player_y
  bcs @dy_pos
    eor #$FF
    clc
    adc #$01
@dy_pos:
  sta absdy
  lda absdy
  cmp #CATCH_Y_RAD
  bcs @no

  ; abs(dx)
  lda obj_x
  sec
  sbc player_x
  bcs @dx_pos
    eor #$FF
    clc
    adc #$01
@dx_pos:
  sta absdx
  lda absdx
  cmp #CATCH_X_RAD
  bcs @no

  jsr HUD_IncScore
  lda #$00
  sta obj_active
@no:
  rts


RNG_Next:
  lda rng_seed
  asl a
  bcc :+
    eor #$1D
:
  sta rng_seed
  rts
