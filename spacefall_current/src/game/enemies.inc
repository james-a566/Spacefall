.segment "CODE"

; ============================================================
; SpawnEnemy (clean)
; - pick slot
; - set Y
; - choose type (debug or thresholds)
; - choose X (size-aware, decorrelated)
; - init per-type params (dx/timer)
; ============================================================
; ============================================================
; ENEMY SYSTEM
;
; Data layout (slot arrays, ENEMY_MAX entries):
;   ene_alive[i]   : 0/1
;   ene_x/ene_y    : top-left position (pixels)
;   ene_y_prev     : previous Y (for swept / “tunneling” fixes if needed)
;   ene_type       : EN_A..EN_E (enemy visual / behavior)
;   obj_kind       : 0=enemy, 1=good-mandatory, 2=powerup1, 3=powerup2
;   ene_variant    : 0=solid, 1=accent (palette/alt art)
;   ene_spd        : per-enemy vertical speed or subtype param
;   ene_dx         : signed horizontal drift (-2..+2 as two’s complement)
;   ene_timer      : per-enemy timer / phase accumulator
;
; Type behavior summary (UpdateEnemies):
;   EN_A: straight fall
;   EN_B: horizontal drift + bounce at edges (uses ene_dx)
;   EN_C: oscillate/zig-zag (uses ene_timer + ene_dx)
;   EN_D: pause/step pattern (uses ene_timer)
;   EN_E: “home”/track toward player X (uses ene_dx or direct adjust)
;
;   
; ============================================================

; ------------------------------------------------------------
; SpawnEnemy
; - Finds a free enemy slot
; - Chooses type via debug_mode or level thresholds
; - Chooses X on 8px grid with size-aware clamps
; - Initializes per-type behavior params (dx/timer)
; ------------------------------------------------------------
SpawnEnemy:


  ; ----------------------------
  ; find free slot
  ; ----------------------------
  ldx #$00
@find:
  cpx #ENEMY_MAX
  bcc :+
    jmp @no_slot
  :
  lda ene_alive,x
  beq @use
  inx
  bne @find

@use:
  lda #$01
  sta ene_alive,x
  inc ene_count

  ; ------------------------------------------------
  ; Spawn Y
  ; - 8x8 enemies: fixed Y
  ; - 16x16 enemies (C/D/E): add 0..7 px jitter
  ;   to de-align scanline bands and reduce overflow
  ; ------------------------------------------------
  lda #ENEMY_SPAWN_Y
  sta ene_y,x
  sta ene_y_prev,x



  ; safety: never allow all-zero RNG state
  lda rng_lo
  ora rng_hi
  bne :+
    lda #$A7
    sta rng_lo
    lda #$1D
    sta rng_hi
:

  ; ============================================================
  ; 1) CHOOSE TYPE FIRST
  ; ============================================================
  lda debug_mode
  beq @choose_type_normal

  ; debug_mode: 1..5 => EN_A..EN_E (0..4)
  sec
  sbc #$01
  sta ene_type,x
  jmp @type_done

@choose_type_normal:
  jsr NextRand
  sta tmp1

  lda tmp1
  cmp level_thrB
  bcc @set_B
  cmp level_thrC
  bcc @set_C
  cmp level_thrD
  bcc @set_D

  lda level_thrE
  beq @set_A
  lda tmp1
  cmp level_thrE
  bcs @set_E



@set_A:
  lda #EN_A
  sta ene_type,x
  jmp @type_done

@set_B:
  lda #EN_B
  sta ene_type,x
  jmp @type_done

@set_C:
  lda #EN_C
  sta ene_type,x
  jmp @type_done

@set_D:
  lda #EN_D
  sta ene_type,x
  jmp @type_done

@set_E:
  lda #EN_E
  sta ene_type,x
  ; fallthrough

@type_done:

  ; param roll for dx / variants
  jsr NextRand
  sta tmp3


  ; 16x16 enemies (C/D/E): add 0..7 px jitter
  lda ene_type,x
  cmp #EN_C
  bcc :+
    jsr NextRand
    and #$07
    clc
    adc ene_y,x
    sta ene_y,x
    sta ene_y_prev,x
:


  ; ----------------------------
  ; HP init (per enemy type)
  ; ----------------------------
  ldy ene_type,x
  cpy #$05
  bcc :+
    ldy #$00
  :
  lda EnemyHP_Table,y
  sta ene_hp,x





  ; ============================================================
  ; 2) CHOOSE X SECOND (size-aware + decorrelated)
  ; ============================================================
  ; tmp0 = right clamp (inclusive-ish)
  lda ene_type,x
  cmp #EN_C
  bcc @clamp_for_8x8

  lda #$E0            ; 16x16 right clamp
  bne @clamp_set
@clamp_for_8x8:
  lda #$E8            ; 8x8 right clamp
@clamp_set:
  sta tmp0

  lda #$10            ; tries
  sta tmp2

@rand_x:
  jsr NextRand
  eor frame_lo
  eor tmp1          ; decorrelate from the type roll 
  and #$F8



  ; left clamp
  cmp #$08
  bcc @retry

  ; right clamp (tmp0)
  cmp tmp0
  bcs @retry

  sta ene_x,x
  jmp @x_done

@retry:
  dec tmp2
  bne @rand_x

  ; fallback
  lda #$80
  sta ene_x,x

@x_done:

  ; ============================================================
  ; 3) INIT PER-TYPE PARAMS
  ; ============================================================
  lda ene_type,x
  cmp #EN_B
  beq @init_B
  cmp #EN_C
  beq @init_C
  cmp #EN_D
  beq @init_D
  cmp #EN_E
  beq @init_E

@init_A:
  lda #$00
  sta ene_dx,x
  lda #$00
  sta ene_timer,x
  rts

@init_B:
  lda tmp3
  and #$01
  beq :+
    lda #$01
    bne :++
: lda #$FF
:
  sta ene_dx,x
  lda #$08
  sta ene_timer,x
  rts

@init_C:
  lda tmp3
  and #$01
  beq :+
    lda #$01
    bne :++
: lda #$FF
:
  sta ene_dx,x
  lda #$00
  sta ene_timer,x
  rts

@init_D:
  lda tmp3
  and #$01
  beq :+
    lda #$01
    bne :++
: lda #$FF
:
  sta ene_dx,x
  lda #$08
  sta ene_timer,x
  rts


@init_E:
  lda #$00
  sta ene_dx,x

  lda #$01
  sta ene_variant,x      ; 1 = shielded tiles

  lda #$2D               ; shield frames (~45 frames = 0.75s)
  sta ene_timer,x

  rts


@no_slot:
  rts



; ----------------------------
; UpdateEnemies
; ----------------------------
UpdateEnemies:
  lda #$00
  sta ene_any

  ; ---- spawn cooldown ----
  lda spawn_cd
  beq @do_spawn
  dec spawn_cd
  jmp @move

@do_spawn:
  jsr SpawnEnemy
  lda level_enemy_cd
  sta spawn_cd

  jsr NextRand
  sta rand_frame



@move:
  ldx #$00
@loop:
  cpx #ENEMY_MAX
  bcc :+
    jmp @done
:

  lda ene_alive,x
  bne :+
    jmp @next
  :

  lda #$01
  sta ene_any


  ; ----------------------------
  ; DYING FLASH (enemy was shot)
  ; - count down and freeze
  ; - when it hits 0, kill enemy
  ; ----------------------------
  lda ene_flash,x
  beq @not_flashing

dec ene_flash,x
beq @flash_ended
jmp @next

@flash_ended:
  lda ene_hp,x
  beq :+
    jmp @next        ; still alive, just finished hit flash
 :
 lda #$00
  sta ene_alive,x  ; hp==0 => die now
  jmp @next



@not_flashing:

  ; store previous Y for collisions
  lda ene_y,x
  sta ene_y_prev,x

  ; ----------------------------
  ; size-aware clamp setup
  ; ----------------------------
  lda ene_type,x
  cmp #EN_C
  bcs @clamp_2x2
  lda #$E8            ; 8x8 right clamp
  bne @clamp_set
@clamp_2x2:
  lda #$E0            ; 16x16 right clamp
@clamp_set:
  sta tmp0            ; tmp0 = right X clamp

  ; ----------------------------
  ; COMMON BASE FALL (ALL TYPES)
  ; ----------------------------
  lda ene_y,x
  clc
  adc level_enemy_spd
  sta ene_y,x

  ; ----------------------------
  ; behavior select (extras only)
  ; ----------------------------
  lda ene_type,x
  asl a              ; *2 (word table)
  tay
  lda @EneBehaviorTable,y
  sta ptr0
  lda @EneBehaviorTable+1,y
  sta ptr0+1
  jmp (ptr0)

@EneBehaviorTable:
  .word @after_behaviors
  .word @beh_B
  .word @beh_C
  .word @beh_D
  .word @beh_E


@beh_B:
  lda ene_timer,x
  beq @b_do_drift
  dec ene_timer,x
  jmp @after_behaviors

@b_do_drift:
  lda ene_x,x
  clc
  adc ene_dx,x
  sta ene_x,x

  ; clamp + bounce (uses tmp0)
  lda ene_x,x
  cmp #$08
  bcs @b_chk_right
  lda #$08
  sta ene_x,x
  lda #$01
  sta ene_dx,x
  jmp @after_behaviors

@b_chk_right:
  lda ene_x,x
  cmp tmp0
  bcs :+
    jmp @after_behaviors
  :
  lda tmp0
  sta ene_x,x
  lda #$FF
  sta ene_dx,x
  jmp @after_behaviors


@beh_C:
  ; C = oscillate: move sideways every frame, reverse every N ticks
  inc ene_timer,x

  ; reverse every 16 frames (tweak: $10 = 16, $08 = faster, $20 = slower)
  lda ene_timer,x
  and #$0F
  bne @c_move

  ; flip direction: dx = -dx  (01 <-> FF)
  lda ene_dx,x
  eor #$FF
  clc
  adc #$01
  sta ene_dx,x

@c_move:
  lda ene_x,x
  clc
  adc ene_dx,x
  sta ene_x,x

  ; clamp + bounce using size-aware clamp (tmp0)
  lda ene_x,x
  cmp #$08
  bcs @c_chk_right
  lda #$08
  sta ene_x,x
  lda #$01
  sta ene_dx,x
  jmp @after_behaviors

@c_chk_right:
  lda ene_x,x
  cmp tmp0
  bcs :+
    jmp @after_behaviors
  :
  lda tmp0
  sta ene_x,x
  lda #$FF
  sta ene_dx,x
  jmp @after_behaviors



@beh_D:
  lda ene_timer,x
  beq @d_active

  ; ----------------------------
  ; PAUSED: undo the base fall this frame
  ; ----------------------------
  dec ene_timer,x
  lda ene_y,x
  sec
  sbc level_enemy_spd
  sta ene_y,x
  jmp @after_behaviors

@d_active:
  ; ----------------------------
  ; ACTIVE: make D more dangerous
  ; - add a downward "lurch" (extra speed)
  ; - drift 1px toward player
  ; ----------------------------

  ; lurch = 1 (always) + bonus when spd is small
  lda #$01            ; base lurch
  ldy level_enemy_spd
  cpy #$02
  bcs :+
    clc
    adc #$01          ; +1 more only when spd==1  (=> lurch 2)
:
  clc
  adc ene_y,x
  sta ene_y,x

  lda frame_lo
  and #$01
  bne @d_maybe_rearm

  ; (2) DRIFT: move 1px toward player_x
  lda player_x
  cmp ene_x,x
  beq @d_maybe_rearm     ; aligned: no drift
  bcc @d_drift_left      ; player_x < ene_x => move left

@d_drift_right:
  lda ene_dx,x
  cmp #$01
  beq :+              ; already heading right
    lda #$06
    sta ene_flash,x   ; pop when turning
:
  lda #$01
  sta ene_dx,x
  inc ene_x,x
  jmp @d_clamp_x


@d_drift_left:
  lda ene_dx,x
  cmp #$FF
  beq :+              ; already heading left
    lda #$06
    sta ene_flash,x
:
  lda #$FF
  sta ene_dx,x
  dec ene_x,x
  ; fallthrough


@d_clamp_x:
  lda ene_x,x
  cmp #$08
  bcs :+
    lda #$08
    sta ene_x,x
:
  lda ene_x,x
  cmp tmp0
  bcc :+
    lda tmp0
    sta ene_x,x
:

@d_maybe_rearm:
  lda rand_frame
  cmp #$20

  bcs @after_behaviors
  lda #$08
  sta ene_timer,x
  jmp @after_behaviors




@beh_E:
  ; --------------------------------------------
  ; Shield timer (ene_variant=1 while shielded)
  ; --------------------------------------------
  lda ene_variant,x
  beq @e_shield_done

  lda ene_timer,x
  beq @e_drop_shield
  dec ene_timer,x
  jmp @e_shield_done

@e_drop_shield:
  lda #$00
  sta ene_variant,x

  lda #$08
  sta ene_flash,x


@e_shield_done:
  ; home toward player_x (2 px/frame)
  lda ene_x,x
  cmp player_x
  beq @after_behaviors
  bcc @e_move_right



  ; home toward player_x (2 px/frame)
  lda ene_x,x
  cmp player_x
  beq @after_behaviors
  bcc @e_move_right

@e_move_left:
  sec
  sbc #$02
  sta ene_x,x
  jmp @e_clamp

@e_move_right:
  clc
  adc #$02
  sta ene_x,x

@e_clamp:
  lda ene_x,x
  cmp #$08
  bcs @e_chk_right
  lda #$08
  sta ene_x,x
  jmp @after_behaviors

@e_chk_right:
  lda ene_x,x
  cmp tmp0
  bcc @after_behaviors
  lda tmp0
  sta ene_x,x
  jmp @after_behaviors



@after_behaviors:
  lda ene_y,x
  cmp #ENEMY_KILL_Y
  bcc @next
  lda #$00
  sta ene_alive,x

@next:
  inx
  beq :+
    jmp @loop
:
@done:
  rts

