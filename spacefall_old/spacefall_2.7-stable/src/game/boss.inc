.segment "CODE"

; ------------------------------------------------------------
; BossSpawn
; - initializes boss fight state (boss + boss bullets)
; - loads phase triggers + phase settings (table-driven)
; ------------------------------------------------------------
BossSpawn:

lda #$01
sta bossbar_visible
sta bossbar_dirty

  lda #$00
  sta boss_phase

  jsr LoadBossPhaseTriggers
  jsr ApplyBossPhaseSettings

  lda boss_fire_cd_reload
  sta boss_fire_cd

  jsr ClearBossBullets

  lda #FLAG_SET
  sta boss_alive

  lda #BOSS_DX_INIT
  sta boss_dx
  lda #BOSS_DY_INIT
  sta boss_dy

  lda #BOSS_X_INIT
  sta boss_x
  lda #BOSS_Y_INIT
  sta boss_y

  ; ---- HP from per-level table (clamped) ----
  ldx level_idx
  cpx #12
  bcc :+
    ldx #11
:
  lda BossHPMaxTable,x
  sta boss_hp
  sta boss_hp_max


  lda #FLAG_CLEAR
  sta boss_flash

  ; ---- NEW: clear pattern-state vars (important) ----
  lda #$00
  sta boss_burst_left
  sta boss_burst_gap
  sta boss_sweep_idx
  sta boss_sweep_dir

  rts


; tmp0 = filled tiles (0..16)

BossBar_CalcFilled:
  lda boss_hp_max
  beq @zero

  ; numerator = boss_hp << 4
  lda boss_hp
  sta tmp1
  lda #$00
  sta tmp2

  asl tmp1
  rol tmp2
  asl tmp1
  rol tmp2
  asl tmp1
  rol tmp2
  asl tmp1
  rol tmp2

  lda #$00
  sta tmp0

@div:
  lda tmp2
  bne @sub
  lda tmp1
  cmp boss_hp_max
  bcc @done

@sub:
  lda tmp1
  sec
  sbc boss_hp_max
  sta tmp1
  lda tmp2
  sbc #$00
  sta tmp2
  inc tmp0
  jmp @div

@done:
  lda tmp0
  cmp #BOSSBAR_LEN
  bcc :+
    lda #BOSSBAR_LEN
    sta tmp0
:
  rts

@zero:
  lda #$00
  sta tmp0
  rts

BossBar_QueueUpdate:
  jsr BossBar_CalcFilled

  ; ptr0 = source tiles
  lda #<bossbar_buf
  sta ptr0
  lda #>bossbar_buf
  sta ptr0+1

  ldx #$00
@build:
  cpx #BOSSBAR_LEN
  bcs @queue

  txa
  cmp tmp0
  bcc @filled

@empty:
  lda #TILE_BOSSBAR_EMPTY
  jmp @store

@filled:
  lda #TILE_BOSSBAR_FULL

@store:
  sta bossbar_buf,x
  inx
  jmp @build

@queue:
  lda #BOSSBAR_NT_HI
  ldx #BOSSBAR_NT_LO
  ldy #BOSSBAR_LEN
  jsr TextQ_QueueWrite

  rts

BossBar_QueueClear:
  lda #<BlinkBlanks
  sta ptr0
  lda #>BlinkBlanks
  sta ptr0+1

  lda #BOSSBAR_NT_HI
  ldx #BOSSBAR_NT_LO
  ldy #BOSSBAR_LEN
  jsr TextQ_QueueBlanks
  rts


; ------------------------------------------------------------
; ClearBossBullets
; - kills all boss bullets (sets alive = 0)
; ------------------------------------------------------------
ClearBossBullets:
  ldx #$00
@loop:
  cpx #BOSS_BULLET_MAX
  bcs @done

  lda #$00
  sta bossbul_alive,x

  lda #$FF            ; optional “offscreen”
  sta bossbul_x,x
  lda #$FE
  sta bossbul_y,x
  sta bossbul_y_prev,x

  lda #$00
  sta bossbul_dx,x
  sta bossbul_dy,x

  inx
  jmp @loop
@done:
  rts


; Spawns a single downward bullet from boss center
BossFireOne:
  ldx #$00
@find:
  cpx #BOSS_BULLET_MAX
  bcs @no_slot

  lda bossbul_alive,x
  beq @use
  inx
  jmp @find

@use:
  lda #$01
  sta bossbul_alive,x

  lda boss_x
  clc
  adc #$08           ; center-ish tweak for boss size
  sta bossbul_x,x

  lda boss_y
  clc
  adc #$10
  sta bossbul_y,x
  sta bossbul_y_prev,x

  lda #$00
  sta bossbul_dx,x
  lda #$02           ; downward speed
  sta bossbul_dy,x
  rts

@no_slot:
  rts


; ============================================================
; BOSS SYSTEM
;
; Boss phase entry:
;   - Timer counts down in PLAY; when it hits 0, @start_boss sets STATE_BOSS.
;   - Boss HP (boss_hp) is tracked in RAM.
;
; 
; ============================================================


BossUpdate:
  lda boss_alive
  beq @done

; debug fire every 30 frames
; lda frame_lo
; and #$1F
; bne :+
;  jsr BossFireOne
; :


  jsr BossMoveByMode
  jsr BossUpdatePhase

  ; flash timer down
  lda boss_flash
  beq :+
    dec boss_flash
:

  ; ---- fire cooldown ----
  lda boss_fire_cd
  beq @fire
  dec boss_fire_cd
  jmp @burst_tick

@fire:
  jsr BossFirePattern
  lda boss_fire_cd_reload
  sta boss_fire_cd

  ; FAST_CD flag: halve cooldown (min 1)
  lda boss_phase_flags
  and #BOSS_PF_FAST_CD
  beq @burst_tick
    lda boss_fire_cd
    lsr a
    bne :+
      lda #$01
:
    sta boss_fire_cd

@burst_tick:
  ; ---- burst follow-up shots ----
  lda boss_burst_left
  beq @done

  lda boss_burst_gap
  beq @do_burst
  dec boss_burst_gap
  jmp @done

@do_burst:
  jsr BossFire_AimedSingle
  dec boss_burst_left
  lda #$06          ; burst spacing (tune)
  sta boss_burst_gap

@done:
  rts


; ------------------------------------------------------------
; BossSpawnBullet
; in:
;   tmp0 = spawn_x
;   tmp1 = spawn_y
;   tmp2 = dx
;   tmp3 = dy
; out:
;   C=1 spawned
;   C=0 no free slot
; ------------------------------------------------------------
BossSpawnBullet:
  ;jsr PlaySfxBossShot
  ldx #$00
@find:
  cpx #BOSS_BULLET_MAX
  bcs @no_slot

  lda bossbul_alive,x
  beq @use

  inx
  jmp @find

@use:
  lda #$01
  sta bossbul_alive,x

  lda tmp0
  sta bossbul_x,x
  lda tmp1
  sta bossbul_y,x
  sta bossbul_y_prev,x

  lda tmp2
  sta bossbul_dx,x
  lda tmp3
  sta bossbul_dy,x

  sec
  rts

@no_slot:
  clc
  rts




BossGetMuzzleXY:
  lda boss_y
  clc
  adc #BOSS_BULLET_Y_OFF
  tay               ; Y = spawn y

  lda boss_x
  clc
  adc #BOSS_BULLET_X_OFF
  rts               ; A = spawn x






; ------------------------------------------------------------
; BossMoveByMode
; - Uses boss_move_mode (from BossPhaseSets byte2)
;
; move_mode:
;   0 = BounceXY
;   1 = BounceX only
;   2 = BounceY only
;   3 = Box patrol (X for 64 frames, then Y for 64 frames)
;   4 = Stutter (move only on even frames)
; ------------------------------------------------------------
BossMoveByMode:
  lda boss_move_mode
  beq @bounce_xy

  cmp #$01
  beq @bounce_x

  cmp #$02
  beq @bounce_y

  cmp #$03
  beq @box_patrol

  cmp #$04
  beq @stutter

  ; default fallback
@bounce_xy:
  jsr BossMoveBounceX
  jsr BossMoveBounceY
  rts

@bounce_x:
  jsr BossMoveBounceX
  rts

@bounce_y:
  jsr BossMoveBounceY
  rts

@box_patrol:
  ; Use frame_lo bit6 as a slow toggle:
  ;   0..63  => X movement
  ;   64..127=> Y movement
  lda frame_lo
  and #%01000000
  beq @box_x
@box_y:
  jsr BossMoveBounceY
  rts
@box_x:
  jsr BossMoveBounceX
  rts

@stutter:
  ; Move only on even frames (frame_lo bit0 = 0)
  lda frame_lo
  and #$01
  bne @stutter_skip
  jsr BossMoveBounceX
  jsr BossMoveBounceY
@stutter_skip:
  rts




; ----------------------------
; BossMoveBounceX
; boss_x += boss_dx (signed)
; bounce at BOSS_MIN_X..BOSS_MAX_X
; ----------------------------
BossMoveBounceX:
  lda boss_x
  clc
  adc boss_dx
  sta boss_x

  ; if boss_x < MIN => clamp + flip dx
  lda boss_x
  cmp #BOSS_MIN_X
  bcs @check_max_x

  lda #BOSS_MIN_X
  sta boss_x
  jsr BossFlipDX
  jmp @done_x

@check_max_x:
  lda boss_x
  cmp #BOSS_MAX_X
  bcc @done_x

  lda #BOSS_MAX_X
  sta boss_x
  jsr BossFlipDX

@done_x:
  rts

; ----------------------------
; BossMoveBounceY
; boss_y += boss_dy (signed)
; bounce at BOSS_MIN_Y..BOSS_MAX_Y
; optional: clamp to UI ceiling (HUD_SAFE)
; ----------------------------
BossMoveBounceY:
  lda boss_y
  clc
  adc boss_dy
  sta boss_y

  ; ---- TOP LIMIT: UI ceiling (optional) ----
;.if HUD_SAFE
  lda boss_y
  cmp #BOSS_UI_CEILING_Y
  bcs :+
    lda #BOSS_UI_CEILING_Y
    sta boss_y
    ; immediately move DOWN after hitting ceiling:
    jsr BossFlipDY
:
;.endif

  ; ---- normal MIN bounce ----
  lda boss_y
  cmp #BOSS_MIN_Y
  bcs @check_max_y

  lda #BOSS_MIN_Y
  sta boss_y
  jsr BossFlipDY
  rts

@check_max_y:
  lda boss_y
  cmp #BOSS_MAX_Y
  bcc @done_y

  lda #BOSS_MAX_Y
  sta boss_y
  jsr BossFlipDY

@done_y:
  rts


; ----------------------------
; BossFlipDX / BossFlipDY
; dx = -dx (two’s complement)
; ----------------------------
BossFlipDX:
  lda boss_dx
  eor #$FF
  clc
  adc #$01
  sta boss_dx
  rts

BossFlipDY:
  lda boss_dy
  eor #$FF
  clc
  adc #$01
  sta boss_dy
  rts

; ------------------------------------------------------------
; BossFireBullet
; - finds a free boss bullet slot
; - spawns at boss center, moving downward
; ------------------------------------------------------------
BossFireBullet:
  ldx #$00
@find:
  cpx #BOSS_BULLET_MAX
  bcs @no_slot
  lda bossbul_alive,x
  beq @use
  inx
  bne @find

@use:
  lda #FLAG_SET
  sta bossbul_alive,x

  ; X = boss_x + center offset
  lda boss_x
  clc
  adc #BOSS_BULLET_X_OFF
  sta bossbul_x,x

  ; Y = boss_y + spawn offset
  lda boss_y
  clc
  adc #BOSS_BULLET_SPAWN_Y
  sta bossbul_y,x
  sta bossbul_y_prev,x

  lda #$00
  sta bossbul_dx,x      ; dx = 0
  lda #$02
  sta bossbul_dy,x      ; dy = 2

@no_slot:
  rts

; ------------------------------------------------------------
; BossFirePattern
; - uses boss_pattern and boss_phase_flags
; ------------------------------------------------------------
BossFirePattern:
  lda boss_pattern
  cmp #BOSS_PAT_SINGLE
  beq @single
  cmp #BOSS_PAT_SPREAD3
  beq @spread3
  cmp #BOSS_PAT_AIMED3
  beq @aimed3
  cmp #BOSS_PAT_RING8
  beq @ring8
  cmp #BOSS_PAT_BURST_AIM
  beq @burst_aim
  cmp #BOSS_PAT_SWEEP5
  beq @sweep5
  cmp #BOSS_PAT_STREAM_DOWN
  beq @stream_down

  rts   ; unknown pattern id => do nothing (safe)

@single:
  jsr BossFire_Single
  jmp @maybe_double

@spread3:
  jsr BossFire_Spread3
  jmp @maybe_double

@aimed3:
  jsr BossFire_Aimed3
  jmp @maybe_double

@ring8:
  jsr BossFire_Ring8
  jmp @maybe_double

@burst_aim:
  jsr BossFire_BurstAimed
  jmp @maybe_double

@sweep5:
  jsr BossFire_Sweep5
  jmp @maybe_double

@stream_down:
  jsr BossFire_StreamDown
  jmp @maybe_double

@maybe_double:
  lda boss_phase_flags
  and #BOSS_PF_DOUBLE_SHOT
  beq @done
    ; fire the same thing again immediately
    ; (cheap “phase got serious” effect)
    lda boss_pattern
    ; tail-call second volley
    jmp BossFirePattern_SecondVolley

@done:
  rts

BossFirePattern_SecondVolley:
  ; identical dispatch, but no further doubling (prevents recursion storm)
  lda boss_pattern
  cmp #BOSS_PAT_SINGLE
  bne :+
    jmp BossFire_Single
  :
  cmp #BOSS_PAT_SPREAD3
  bne :+ 
    jmp BossFire_Spread3
  :
  cmp #BOSS_PAT_AIMED3
  bne :+
    jmp BossFire_Aimed3
  :
  cmp #BOSS_PAT_RING8
  beq BossFire_Ring8
  cmp #BOSS_PAT_BURST_AIM
  beq BossFire_BurstAimed
  cmp #BOSS_PAT_SWEEP5
  beq BossFire_Sweep5
  cmp #BOSS_PAT_STREAM_DOWN
  bne :+
    jmp BossFire_StreamDown
  :
  rts

BossFire_Ring8:
  jsr BossGetMuzzleXY     ; A=x, Y=y
  sta tmp3                ; base_x
  sty tmp4                ; base_y

  ldx #$00
@loop:
  cpx #8
  bcs @maybe_dense

  ; load dx,dy from table
  lda BossDir8+0,x
  sta tmp0
  lda BossDir8+1,x
  sta tmp1

  ; optional wobble (bit5)
  jsr BossMaybeWobble

  lda tmp3
  ldy tmp4
  jsr BossSpawnBullet

  inx
  inx
  jmp @loop

@maybe_dense:
  lda boss_phase_flags
  and #BOSS_PF_DENSE
  beq @done

  ; dense: spawn a second ring with slightly faster speed (scale dx/dy)
  ldx #$00
@loop2:
  cpx #8
  bcs @done

  lda BossDir8+0,x
  asl a            ; *2 speed-ish (tune)
  sta tmp0
  lda BossDir8+1,x
  asl a
  sta tmp1

  jsr BossMaybeWobble

  lda tmp3
  ldy tmp4
  jsr BossSpawnBullet

  inx
  inx
  jmp @loop2

@done:
  rts

BossFire_BurstAimed:
  lda #$03          ; 3-shot burst (tune)
  sta boss_burst_left
  lda #$00
  sta boss_burst_gap
  rts

BossFire_AimedSingle:
  jsr BossGetMuzzleXY
  sta tmp3
  sty tmp4

  ; compute tmp0=dx tmp1=dy aiming at player (simple 8-way or coarse)
  jsr BossComputeAimDxDy

  jsr BossMaybeWobble

  lda tmp3
  ldy tmp4
  jsr BossSpawnBullet
  rts

BossFire_Sweep5:
  jsr BossGetMuzzleXY
  sta tmp3
  sty tmp4

  ; optionally flip sweep direction each fire
  lda boss_phase_flags
  and #BOSS_PF_ALT_SWEEP
  beq :+
    lda boss_sweep_dir
    eor #$01
    sta boss_sweep_dir
:

  ; base dx depends on sweep_idx and sweep_dir
  ; dx_base = (-2..+2) shifting over time
  ; We'll derive center offset from sweep_idx (0..4)
  lda boss_sweep_idx
  and #$07           ; keep small
  cmp #$05
  bcc :+
    lda #$00
:
  sta boss_sweep_idx

  ; center = (idx - 2) -> -2,-1,0,+1,+2
  lda boss_sweep_idx
  sec
  sbc #$02
  sta tmp2           ; tmp2 = center dx

  ; if dir is negative, invert center
  lda boss_sweep_dir
  beq @dir_ok
    lda tmp2
    eor #$FF
    clc
    adc #$01
    sta tmp2
@dir_ok:

  ; shoot 5 bullets: center-2 .. center+2
  ldx #$00
@fan:
  cpx #$05
  bcs @advance

  ; dx = tmp2 + (x-2)
  txa
  sec
  sbc #$02
  clc
  adc tmp2
  sta tmp0

  lda #$02          ; dy down
  sta tmp1

  jsr BossMaybeWobble

  lda tmp3
  ldy tmp4
  jsr BossSpawnBullet

  inx
  jmp @fan

@advance:
  inc boss_sweep_idx

  ; DENSE: add a second fan with dy=3 (heavier rain)
  lda boss_phase_flags
  and #BOSS_PF_DENSE
  beq @done

  lda #$03
  sta tmp1
  ldx #$00
@fan2:
  cpx #$05
  bcs @done
  txa
  sec
  sbc #$02
  clc
  adc tmp2
  sta tmp0

  jsr BossMaybeWobble

  lda tmp3
  ldy tmp4
  jsr BossSpawnBullet

  inx
  jmp @fan2

@done:
  rts

BossFire_StreamDown:
  jsr BossGetMuzzleXY
  sta tmp3
  sty tmp4

  ; base bullet: straight down
  lda #$00
  sta tmp0
  lda #$03
  sta tmp1

  ; spawn center
  lda tmp3
  ldy tmp4
  jsr BossSpawnBullet

  ; twin barrel spawns left/right too
  lda boss_phase_flags
  and #BOSS_PF_TWIN_BARREL
  beq @maybe_dense

  ; left
  lda tmp3
  sec
  sbc #$06
  ldy tmp4
  jsr BossSpawnBullet

  ; right
  lda tmp3
  clc
  adc #$06
  ldy tmp4
  jsr BossSpawnBullet

@maybe_dense:
  lda boss_phase_flags
  and #BOSS_PF_DENSE
  beq @done

  ; dense: add slight diagonals
  lda #$FF          ; -1
  sta tmp0
  lda tmp3
  ldy tmp4
  jsr BossSpawnBullet

  lda #$01
  sta tmp0
  lda tmp3
  ldy tmp4
  jsr BossSpawnBullet

@done:
  rts


BossMaybeWobble:
  lda boss_phase_flags
  and #BOSS_PF_WOBBLE
  beq @done

  ; add ±1 to dx based on frame bit
  lda frame_lo
  and #$01
  beq @minus
@plus:
  inc tmp0
  rts
@minus:
  dec tmp0
@done:
  rts

; ------------------------------------------------------------
; BossComputeAimDxDy
; Outputs:
;   tmp0 = dx (signed byte)
;   tmp1 = dy (signed byte)
; Uses BossDir8 (dx,dy pairs)
; ------------------------------------------------------------
BossComputeAimDxDy:
  ; ---- dx sign ----
  lda player_x
  sec
  sbc boss_x
  bpl @dx_pos
@dx_neg:
  lda #$FF          ; dx_sign = -1
  jmp @dx_store
@dx_pos:
  lda #$01          ; dx_sign = +1
@dx_store:
  sta tmp2          ; tmp2 = dx_sign

  ; ---- dy sign ----
  lda player_y
  sec
  sbc boss_y
  bpl @dy_pos
@dy_neg:
  lda #$FF          ; dy_sign = -1
  jmp @dy_store
@dy_pos:
  lda #$01          ; dy_sign = +1
@dy_store:
  sta tmp3          ; tmp3 = dy_sign

  ; ----------------------------------------------------------
  ; Decide which of 8 directions:
  ; Index mapping to BossDir8 rows:
  ;   0 N, 1 NE, 2 E, 3 SE, 4 S, 5 SW, 6 W, 7 NW
  ;
  ; We'll pick:
  ;  - if dy_sign is + => S hemisphere (3,4,5)
  ;  - if dy_sign is - => N hemisphere (7,0,1)
  ;  - dx_sign chooses left/right
  ; ----------------------------------------------------------

  ; default to vertical (N or S)
  lda tmp3
  bmi @want_north

@want_south:
  ; south: choose S / SE / SW
  lda tmp2
  bmi @south_west
@south_east:
  ldx #3            ; SE
  jmp @load
@south_west:
  ldx #5            ; SW
  jmp @load

@want_north:
  ; north: choose N / NE / NW
  lda tmp2
  bmi @north_west
@north_east:
  ldx #1            ; NE
  jmp @load
@north_west:
  ldx #7            ; NW

@load:
  ; load dx,dy from table: each entry is 2 bytes
  txa
  asl a             ; *2
  tax

  lda BossDir8+0,x
  sta tmp0
  lda BossDir8+1,x
  sta tmp1
  rts



; ------------------------------------------------------------
; UpdateBossBullets
; - Moves boss bullets downward
; - Tracks previous Y for swept collision
; - Kills bullets that leave the bottom
; ------------------------------------------------------------
UpdateBossBullets:
  ldx #$00
@loop:
  cpx #BOSS_BULLET_MAX
  bcs @done

  lda bossbul_alive,x
  beq @next

  ; prev Y
  lda bossbul_y,x
  sta bossbul_y_prev,x

  ; X += dx (signed)
  lda bossbul_x,x
  clc
  adc bossbul_dx,x
  sta bossbul_x,x

  ; ---- kill if off left/right (prevent wraparound) ----
  lda bossbul_x,x
  cmp #$08
  bcc @kill
  cmp #$F8
  bcs @kill

  ; Y += dy
  lda bossbul_y,x
  clc
  adc bossbul_dy,x
  sta bossbul_y,x

  ; kill if off bottom
  cmp #BOSS_BULLET_KILL_Y
  bcc @next

@kill:
  lda #FLAG_CLEAR
  sta bossbul_alive,x
  jmp @next


@next:
  inx
  bne @loop
@done:
  rts


BossFire_Single:
  ; A=x, Y=y
  jsr BossGetMuzzleXY

  ; store spawn position
  sta tmp0          ; x
  sty tmp1          ; y

  ; set dx/dy
  lda #$00
  sta tmp2          ; dx
  lda #$02
  sta tmp3          ; dy

  jsr BossSpawnBullet
  rts






BossFire_Spread3:

  lda boss_x
  clc
  adc #BOSS_BULLET_X_OFF
  sta tmp0

  lda boss_y
  clc
  adc #BOSS_BULLET_Y_OFF
  sta tmp1

  lda #$02
  sta tmp3          ; dy = 2

  ; left: dx = $FF (-1)
  lda #$FF
  sta tmp2
  jsr BossSpawnBullet
  ; mid: dx = 0
  lda #$00
  sta tmp2
  jsr BossSpawnBullet
  ; right: dx = +1
  lda #$01
  sta tmp2
  jsr BossSpawnBullet

  rts

BossFire_Aimed3:
  ; base spawn pos
  lda boss_x
  clc
  adc #BOSS_BULLET_X_OFF
  sta tmp0

  lda boss_y
  clc
  adc #BOSS_BULLET_Y_OFF
  sta tmp1

  lda #$02
  sta tmp3          ; dy = 2

  ; dx = sign(player_x - boss_x) in {-1,0,+1}
  lda player_x
  sec
  sbc boss_x
  beq @dx0
  bcc @dx_neg

@dx_pos:
  lda #$01
  bne @dx_set
@dx_neg:
  lda #$FF
  bne @dx_set
@dx0:
  lda #$00
@dx_set:
  sta tmp2


  jsr BossSpawnBullet
  rts

; ------------------------------------------------------------
; CheckPlayerHitByBossBullets
; - if invuln_timer > 0, skip
; - checks each live boss bullet vs player box
; - on hit: kill bullet, apply damage
; ------------------------------------------------------------
CheckPlayerHitByBossBullets:
  lda invuln_timer
  bne @done

  ldx #$00
@loop:
  cpx #BOSS_BULLET_MAX
  bcs @done

  lda bossbul_alive,x
  beq @next

  ; ----------------------------
  ; SANITY: ignore bullets offscreen / garbage Y
  ; ----------------------------
  lda bossbul_y,x
  cmp #$08
  bcc @next                 ; too high
  cmp #BOSS_BULLET_KILL_Y
  bcs @next                 ; too low / already past kill line

  lda bossbul_x,x
  cmp #$08
  bcc @next
  cmp #$F8
  bcs @next

  ; ----------------------------
  ; X overlap (coarse 16x16 player vs 8x8 bullet)
  ; ----------------------------
  lda bossbul_x,x
  sec
  sbc player_x
  cmp #$10
  bcs @next

  ; ----------------------------
  ; Y overlap
  ; ----------------------------
  lda bossbul_y,x
  sec
  sbc player_y
  cmp #$10
  bcs @next

  ; HIT
  lda #FLAG_CLEAR
  sta bossbul_alive,x

  lda bossbul_x,x
  sta hit_src_x

  ; ---- SHIELD: absorb hit ----
  lda shield_timer
  beq @no_shield

    lda #$10
    sta invuln_timer
    rts

@no_shield:
  jsr PlayerTakeHit
  rts



@next:
  inx
  bne @loop

@done:
  rts


; ------------------------------------------------------------
; BossBigAttackFX
; - If boss_bigshot_pulse set:
;     start shake + flash + (optional) SFX
; - Each frame:
;     updates boss_shake_dx and counts shake down
; ------------------------------------------------------------
BossBigAttackFX:
  lda boss_bigshot_pulse
  beq @tick

  lda #$00
  sta boss_bigshot_pulse

  ; shake: 6 frames
  lda #$06
  sta boss_shake_timer

  ; muzzle flash pulse (short)
  lda boss_flash
  bne @tick
  lda #$08
  sta boss_flash

@tick:
  jsr GetBossShakeDY
  sta boss_shake_dy

  lda boss_shake_timer
  beq @done
  dec boss_shake_timer
@done:
  rts


; returns A = 0 or 1 or $FF (-1)
GetBossShakeDX:
  lda boss_shake_timer
  beq @zero

  lda frame_lo
  and #$01
  beq @plus

  lda #$FE        ; -1
  rts

@plus:
  lda #$02        ; +1
  rts

@zero:
  lda #$00
  rts

; returns A = 0, +1, or $FF (-1)
GetBossShakeDY:
  lda boss_shake_timer
  beq @zero

  lda frame_lo
  and #$01
  beq @plus

  lda #$FF        ; -1
  rts

@plus:
  lda #$01        ; +1
  rts

@zero:
  lda #$00
  rts

; ------------------------------------------------------------
; LoadBossPhaseTriggers
; - loads t0/t1/t2 for current level into boss_phase_t0..t2
; tables: BossPhaseTriggers = 12 * 3 bytes
; ------------------------------------------------------------
LoadBossPhaseTriggers:
  ; Y = level_idx * 3
  lda level_idx
  asl              ; *2
  clc
  adc level_idx    ; *3
  tay

  lda BossPhaseTriggers,y
  sta boss_phase_t0
  iny
  lda BossPhaseTriggers,y
  sta boss_phase_t1
  iny
  lda BossPhaseTriggers,y
  sta boss_phase_t2
  rts

; ------------------------------------------------------------
; ApplyBossPhaseSettings
; - loads current phase row for current level boss into:
;   boss_pattern, boss_fire_cd_reload, boss_move_mode, boss_phase_flags
; - clamps boss index to 0..11
; - applies FAST_CD (halve, with min clamp)
; ------------------------------------------------------------
ApplyBossPhaseSettings:

  ; ---- boss index clamp (0..11) ----
  lda level_idx
  cmp #12
  bcc @idx_ok
    lda #11
@idx_ok:
  sta tmp5            ; tmp5 = boss_idx (0..11)

  ; base = boss_idx * 16
  lda tmp5
  asl a               ; *2
  asl a               ; *4
  asl a               ; *8
  asl a               ; *16
  sta tmp2            ; tmp2 = base offset (0..176)

  ; phase_off = boss_phase * 4
  lda boss_phase
  asl a
  asl a               ; *4
  clc
  adc tmp2            ; A = base + phase_off
  tax                 ; X = final byte offset into BossPhaseSets

  lda BossPhaseSets+0,x
  sta boss_pattern

  lda BossPhaseSets+2,x
  sta boss_move_mode

  lda BossPhaseSets+3,x
  sta boss_phase_flags

  ; fire_cd_reload (apply FAST_CD if set)
  lda BossPhaseSets+1,x
  sta boss_fire_cd_reload

  lda boss_phase_flags
  and #BOSS_PF_FAST_CD
  beq @done

    ; halve cooldown
    lda boss_fire_cd_reload
    lsr a
    ; min clamp (tune this; 6–10 is a common “still fair” range)
    cmp #6
    bcs :+
      lda #6
:
    sta boss_fire_cd_reload

@done:
  rts



; ------------------------------------------------------------
; BossResolvePhase
; in:  boss_hp, boss_phase_t0..t2
; out: A = desired phase (0..3)
; ------------------------------------------------------------
BossResolvePhase:
  lda boss_hp

  ; if hp <= t2 => phase 3
  cmp boss_phase_t2
  bcc @p3          ; hp < t2
  beq @p3          ; hp == t2

  ; if hp <= t1 => phase 2
  lda boss_hp
  cmp boss_phase_t1
  bcc @p2
  beq @p2

  ; if hp <= t0 => phase 1
  lda boss_hp
  cmp boss_phase_t0
  bcc @p1
  beq @p1

  lda #$00
  rts
@p1:
  lda #$01
  rts
@p2:
  lda #$02
  rts
@p3:
  lda #$03
  rts




; ------------------------------------------------------------
; LoadBossPhaseConfig
; in: A = boss_index (0..11 if 12 levels)
; out: boss_phase_t0/t1/t2, boss_hp_max, phase0 params
; trashes: A,X,Y,tmp0,tmp1
; ------------------------------------------------------------
LoadBossPhaseConfig:
  sta tmp0                ; tmp0 = boss_index

  ; --- boss_hp_max ---
  tax
  lda BossHPMaxTable,x
  sta boss_hp_max

  ; --- triggers: 3 bytes per boss ---
  lda tmp0
  asl a                   ; *2
  clc
  adc tmp0                ; *3
  tax
  lda BossPhaseTriggers,x
  sta boss_phase_t0       ; threshold for phase1
  lda BossPhaseTriggers+1,x
  sta boss_phase_t1       ; threshold for phase2
  lda BossPhaseTriggers+2,x
  sta boss_phase_t2       ; threshold for phase3

  ; --- phase set pointer: 16 bytes per boss ---
  ; offset = boss_index * 16
  lda tmp0
  asl a   ; *2
  asl a   ; *4
  asl a   ; *8
  asl a   ; *16
  tay

  ; phase0 fields: [pattern, fire_cd4?, move_mode, flags]
  lda BossPhaseSets,y
  sta boss_pattern
  iny
  lda BossPhaseSets,y
  sta boss_fire_cd_reload
  sta boss_fire_cd        ; seed current CD from reload
  iny
  lda BossPhaseSets,y
  sta boss_move_mode
  iny
  lda BossPhaseSets,y
  sta boss_phase_flags

  lda #$00
  sta boss_phase

  rts

; ------------------------------------------------------------
; BossUpdatePhase
; - call once per frame during STATE_BOSS
; - assumes triggers: t0 > t1 > t2 (HP descending thresholds)
; ------------------------------------------------------------
BossUpdatePhase:
  ; A = boss_hp (keep it; reuse for all compares)
  lda boss_hp

  ; desired phase defaults to 0
  ldx #$00

  ; if hp < t0 => phase 1+
  cmp boss_phase_t0
  bcs @check_p2         ; hp >= t0 => still phase 0
  ldx #$01              ; hp < t0 => phase 1

@check_p2:
  ; if hp < t1 => phase 2+
  lda boss_hp
  cmp boss_phase_t1
  bcs @check_p3
  ldx #$02

@check_p3:
  ; if hp < t2 => phase 3
  lda boss_hp
  cmp boss_phase_t2
  bcs @apply_if_changed
  ldx #$03

@apply_if_changed:
  txa
  cmp boss_phase
  beq @done

  ; ---- phase changed ----
  sta boss_phase

  ; apply new phase params from BossPhaseSets
  jsr ApplyBossPhaseSettings     ; (or BossApplyPhaseParams, but be consistent)

  ; make new phase fire rate take effect immediately
  lda boss_fire_cd_reload
  sta boss_fire_cd

  ; optional: phase SFX + small flash
  ;jsr PlaySfxBossPhase
  lda #$06
  sta screen_flash_timer

    lda #$00
  sta boss_burst_left
  sta boss_burst_gap
  sta boss_sweep_idx
  sta boss_sweep_dir


@done:
  rts


BossApplyPhaseParams:
  ; Y = boss_index*16 + boss_phase*4
  lda level_idx
  sta tmp0

  lda tmp0
  asl a
  asl a
  asl a
  asl a            ; A = boss_index*16
  sta tmp1         ; tmp1 = base

  lda boss_phase
  asl a
  asl a            ; A = phase*4
  clc
  adc tmp1         ; A = base + phase*4
  tay

  lda BossPhaseSets,y
  sta boss_pattern
  iny
  lda BossPhaseSets,y
  sta boss_fire_cd_reload
  ; snapping:
  sta boss_fire_cd
  iny
  lda BossPhaseSets,y
  sta boss_move_mode
  iny
  lda BossPhaseSets,y
  sta boss_phase_flags

  rts