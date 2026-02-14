.segment "CODE"


; ------------------------------------------------------------
; Debug
; ------------------------------------------------------------
DEBUG_BOSS_SKIP = 1     ; set to 0 to compile out boss-skip hotkey
DEBUG_SPAWN     = 1

; debug_mode: 0=normal, 1=A, 2=B, 3=C, 4=D, 5=E


DebugUpdate:
  lda pad1_new
  and #BTN_SELECT
  beq @done

  inc debug_mode
  lda debug_mode
  cmp #$06
  bcc :+
    lda #$00
    sta debug_mode
  :

  lda debug_mode
  beq @done            ; only clear if entering a debug mode

  ldx #$00
@cb_loop:
  cpx #BULLET_MAX
  bcs @done
  lda #$00
  sta bul_alive,x
  inx
  bne @cb_loop

@done:
  rts


; ------------------------------------------------------------
; DebugJumpToBoss
; - Dev hotkey: instantly enter boss phase
; - Safe: clears actors, spawns boss, marks boss bar dirty, flashes
; ------------------------------------------------------------
DebugJumpToBoss:
  jsr ClearActors

  lda #STATE_BOSS
  sta game_state

  lda #FLASH_BOSS_START_FR
  sta screen_flash_timer

  jsr BossSpawn            ; sets boss_alive, boss_x/y, boss_hp, dirty, etc.

  rts