.segment "CODE"

; ============================================================
; PLAYER
;
; Player coordinate system:
;   player_x / player_y = top-left of a 2x2 metasprite (16x16).
;
; Timers:
;   invuln_timer      : i-frames after being hit (player cannot be damaged)
;   good_flash_timer  : short palette flash (powerups / good collision feedback)
;
; Movement:
;   - D-pad moves ship; X clamped to safe range
;
; Firing:
;   - A fires bullets with a cooldown (fire_cd)
;   - gun_side alternates spawn point for a “dual cannon” feel
; ============================================================

; ------------------------------------------------------------
; UpdatePlayer
; - Move ship (D-pad) with clamps
; - Fire bullets while holding A (cooldown)
; - Tick invulnerability + good_flash timers
; - ComputePlayerAttr (palette flash)
; ------------------------------------------------------------
UpdatePlayer:


  lda player_blink_timer
  beq :+
    dec player_blink_timer
:

  ; ---- knockback override ----
  lda player_kb_timer
  beq @no_kb

  dec player_kb_timer

  ; X += dx (signed)
  lda player_x
  clc
  adc player_kb_dx
  sta player_x

  ; Y += dy (optional)
  lda player_y
  clc
  adc player_kb_dy
  sta player_y

  ; clamp to screen-ish bounds (tune)
  lda player_x
  cmp #$08
  bcs :+
    lda #$08
    sta player_x
:
  lda player_x
  cmp #$F0
  bcc :+
    lda #$F0
    sta player_x
:
  lda player_y
  cmp #$10
  bcs :+
    lda #$10
    sta player_y
:
  lda player_y
  cmp #$D8
  bcc :+
    lda #$D8
    sta player_y
:

; --- IMPORTANT: timers + attr must still run ---
  lda invuln_timer
  beq :+
    dec invuln_timer
:
  lda good_flash_timer
  beq :+
    dec good_flash_timer
:
  jsr ComputePlayerAttr
  rts                 ; skip normal control this frame

@no_kb:


  ; ----------------------------
  ; Horizontal movement
  ; ----------------------------

  ; left
  lda pad1
  and #BTN_LEFT
  beq @check_right
  lda player_x
  sec
  sbc #PLAYER_MOVE_SPD_X
  cmp #PLAYER_MIN_X
  bcs :+
    lda #PLAYER_MIN_X
:
  sta player_x

@check_right:
  lda pad1
  and #BTN_RIGHT
  beq @vert
  lda player_x
  clc
  adc #PLAYER_MOVE_SPD_X
  cmp #PLAYER_MAX_X
  bcc :+
    lda #PLAYER_MAX_X
:
  sta player_x

  ; ----------------------------
  ; Vertical movement
  ; ----------------------------
@vert:
  ; ---- UP ----
  lda pad1
  and #BTN_UP
  beq @check_down

  lda player_y
  sec
  sbc #PLAYER_MOVE_SPD_Y
  cmp #PLAYER_MIN_Y
  bcs :+
    lda #PLAYER_MIN_Y
:
  sta player_y

@check_down:
  lda pad1
  and #BTN_DOWN
  beq @after_vert

  lda player_y
  clc
  adc #PLAYER_MOVE_SPD_Y
  cmp #PLAYER_MAX_Y
  bcc :+
    lda #PLAYER_MAX_Y
:
  sta player_y

@after_vert:
  ; fall through


; ---- Jam timer tick (once per frame) ----
  lda jam_timer
  beq :+
  dec jam_timer
:

  lda boss_sfx_cd
  beq :+
  dec boss_sfx_cd
:


  ; ----------------------------
  ; Fire (hold A) with cooldown
  ; - gun_jam_timer blocks firing but cooldown still ticks
  ; ----------------------------

  ; tick jam timer
  lda gun_jam_timer
  beq :+
  dec gun_jam_timer
:

  ; tick cooldown
  lda player_cd
  beq :+
  dec player_cd
:

  ; if jammed, skip firing
  lda gun_jam_timer
    ; if jammed, and player is trying to fire, play jam-click (rate limited
  beq :+

    lda pad1
    and #BTN_A
    beq @done

    lda player_cd
    bne @done

    ;jsr PlaySfxDry
    lda #$06
    sta player_cd
    jmp @done
:

  bne @done

  ; if cooldown still active, skip firing
  lda player_cd
  bne @done

  ; check fire input
  lda pad1
  and #BTN_A
  beq @done

  ; FIRE attempt
  jsr FireBulletLR
  ;bcc @dry_fire

  ; SUCCESS
 jsr PlaySfxFiring


  lda #FIRE_COOLDOWN_FR
  sta player_cd
  jmp @done

@dry_fire:
  jsr PlaySfxDry
  lda #$06
  sta player_cd
  ; fall through to @done



@done:
  ; invuln tick
  lda invuln_timer
  beq :+
  dec invuln_timer
:
  ; good flash tick
  lda good_flash_timer
  beq :+
  dec good_flash_timer
:

  jsr ComputePlayerAttr
  rts



; ============================================================
; BULLETS
;
; Slot arrays (BULLET_MAX entries):
;   bul_alive[i]  : 0/1
;   bul_x/bul_y   : position (top-left of sprite)
;   bul_y_prev    : previous Y (helps swept collision / “tunneling”)
;
; Behavior:
;   - Bullets travel upward at a fixed speed (currently hardcoded #$05)
;   - Bullets die when they leave the top of the screen
; ============================================================

; ----------------------------
; FireBulletLR
; - finds a free bullet slot
; - spawns from left/right gun alternating
; ----------------------------
FireBulletLR:
  ; find free bullet slot
  ldx #$00
@find:
  cpx #BULLET_MAX
  bcs @no_slot
  lda bul_alive,x
  beq @use
  inx
  bne @find

@use:
  lda #$01
  sta bul_alive,x

  ; spawn Y slightly above ship
  lda player_y
  sec
  sbc #BULLET_SPAWN_Y_OFF
  sta bul_y,x
  lda bul_y,x
  sta bul_y_prev,x

  ; choose left/right gun X
  lda gun_side
  beq @left

@right:
  lda player_x
  clc
  adc #GUN_RIGHT_X_OFF
  sta bul_x,x
  lda #$00
  sta gun_side
  sec              ; SUCCESS
  rts

@left:
  lda player_x
  sta bul_x,x
  lda #$01
  sta gun_side
  sec              ; SUCCESS
  rts

@no_slot:
  clc              ; FAIL
  rts



; ------------------------------------------------------------
; UpdateBullets
; - Moves bullets upward
; - Tracks previous Y for swept collision
; - Kills bullets that leave the top
; ------------------------------------------------------------
UpdateBullets:
  lda #$00
  sta bul_any

  ldx #$00
@loop:
  cpx #BULLET_MAX
  bcs @done

  lda bul_alive,x
  beq @next

  lda #$01
  sta bul_any

  ; store previous Y for swept collision
  lda bul_y,x
  sta bul_y_prev,x

  ; move up
  sec
  sbc #BULLET_SPD
  sta bul_y,x

  bcc @kill

  cmp #BULLET_KILL_Y
  bcs @next

@kill:
  lda #$00
  sta bul_alive,x

@next:
  inx
  bne @loop
@done:
  rts




; ----------------------------
; ComputePlayerAttr
; - sets player_attr based on timers
; priority: hurt > good > normal
; ----------------------------
ComputePlayerAttr:
  lda #$00
  sta player_attr

  ; hurt flash
  lda invuln_timer
  beq @check_good
  and #$04
  beq @check_good
  lda #$01
  sta player_attr
  rts

@check_good:
  lda good_flash_timer
  beq @done
  and #$02
  beq @done
  lda #$02
  sta player_attr

@done:
  rts


UpdateShield:
  lda shield_timer
  beq @done

  lda frame_lo
  and #$03        ; every 4 frames
  bne @done

  dec shield_timer
@done:
  rts


ClearGunJam:
  lda #$00
  sta jam_timer
  sta gun_jam_timer
  sta jam_flash_timer
  rts
