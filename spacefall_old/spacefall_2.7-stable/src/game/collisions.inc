.segment "CODE"

; ----------------------------
; CollideBulletsEnemies
; - if bullet point is inside enemy 8x8 box -> kill both
; - optionally add score
; ----------------------------
; ============================================================
; COLLISIONS
; - Bullet vs Enemy
; - Player vs Enemy
;
;
; ============================================================

CollideBulletsEnemies:
  ; Uses simple AABB overlap. Enemy hitbox is currently treated as 8x8.
  ldx #$00                  ; bullet index
@bul_loop:
  cpx #BULLET_MAX
  bcc :+
    jmp @done
  :

  lda bul_alive,x
  bne :+
    jmp @bul_next
  :
  ldy #$00                  ; enemy index
@ene_loop:
  cpy #ENEMY_MAX
  bcc :+
    jmp @bul_next             ; done checking this bullet
:

  lda ene_alive,y
  bne :+
    jmp @ene_next
  :

; X check
  jsr GetEnemyExtent
  sta tmp2              ; 7 or 15

  lda tmp2
  clc
  adc #$01
  sta tmp3            ; size = extent+1 => 8 or 16

  ; tmp3 = enemy size (8 or 16) must already be set
  ; compute enemy_right = ene_x + (size-1)
  lda ene_x,y
  clc
  adc tmp3
  sec
  sbc #$01
  sta tmp0              ; tmp0 = enemy_right

  ; compute bullet_right = bul_x + 7
  lda bul_x,x
  clc
  adc #$07
  sta tmp1              ; tmp1 = bullet_right

  ; if bul_x > enemy_right -> no hit
  lda bul_x,x
  cmp tmp0
  bcc :+
    jmp @ene_next         ; bul_x >= enemy_right+1 (since enemy_right is inclusive)
:
  ; if ene_x > bullet_right -> no hit
  lda ene_x,y
  cmp tmp1
  bcc :+
    jmp @ene_next
  :





  ; ---- Y check (swept with bullet height) ----
  ; bullet_top_now = bul_y
  ; bullet_bottom_prev = bul_y_prev + 7
  ; enemy_bottom_now = ene_y + 7
  ; enemy_top_prev = ene_y_prev

  lda ene_y,y
  clc
  adc tmp2              ; enemy_bottom_now = ene_y + extent
  sta tmp


  ; bullet_top_now <= enemy_bottom_now ?
  lda bul_y,x
  cmp tmp
  bcc @y_ok
  beq @y_ok
  jmp @ene_next

@y_ok:
  ; bullet_bottom_prev >= enemy_top_prev ?
  lda bul_y_prev,x
  clc
  adc #$07              ; or (BULLET_H-1)
  cmp ene_y_prev,y
  bcc @ene_next


  ; ---- HIT! ----
@hit:
  

  ; kill bullet
  lda #$00
  sta bul_alive,x

  ; ---- shield check (Enemy E) ----
  lda ene_type,y
  cmp #EN_E
  bne @apply_damage

  lda ene_variant,y
  beq @apply_damage       ; 0 = unshielded => damage ok

  ; shielded: no damage (but bullet already got consumed)
  lda #ENEMY_HIT_FLASH_FR
  sta ene_flash,y         ; optional: give feedback
  jmp @bul_next

@apply_damage:


  ; ---- apply damage ----
 lda ene_hp,y
beq @already_dead

sec
sbc #$01
sta ene_hp,y
bne @enemy_survives


  ; ============================
  ; ENEMY DIES (hp reached 0)
  ; - “death flash” 
  ; ============================
  ; ENEMY DIES
  lda #ENEMY_DIE_FLASH_FR
  sta ene_flash,y

  sty tmp5            ; <--- ADD (or push Y)

  jsr PlaySfxExplode

  ldy tmp5            ; <--- ADD (restore Y)

  ; ---- add score based on enemy type ----
  txa
  pha                 ; SAVE bullet index X

  ldx ene_type,y
  cpx #$05
  bcc :+
    ldx #EN_A
:
  txa
  asl a
  clc
  adc ene_type,y
  tax

  lda EnemyScore_HTO,x
  sta tmp2
  lda EnemyScore_HTO+1,x
  sta tmp1
  lda EnemyScore_HTO+2,x
  sta tmp0

  jsr AddScoreHTO

  pla
  tax                 ; RESTORE bullet index X

  jmp @bul_next



@enemy_survives:
  ; ============================
  ; ENEMY HIT (still alive)
  ; - short hit flash, do NOT die when flash ends
  ; - play hit SFX
  ; ============================
  lda #ENEMY_HIT_FLASH_FR
  sta ene_flash,y

  jsr PlaySfxEnemyHit      ; NOISE hit tick
  jmp @bul_next

@already_dead:
  jmp @bul_next


@ene_next:
  iny
  beq :+
    jmp @ene_loop
  :

@bul_next:
  inx
  beq :+
    jmp @bul_loop
:
@done:
  rts

; ----------------------------
; CollidePlayerEnemies
; 16x16 player vs 8x8 enemy
; - ignores hits if invuln_timer > 0
; - on hit: kill enemy, call PlayerTakeHit, stop after one hit/frame
; ----------------------------
CollidePlayerEnemies:
  lda invuln_timer
  bne CPE_Done

  ldy #$00
CPE_EnemyLoop:
  cpy #ENEMY_MAX
  bcs CPE_Done

 lda ene_alive,y
beq CPE_NextEnemy
lda ene_flash,y
bne CPE_NextEnemy


  jsr GetEnemyExtent
  sta tmp2              ; tmp2 = enemy extent

  lda tmp2
  clc
  adc #$01
  sta tmp3          ; tmp3 = enemy width/height (8 or 16)

  beq CPE_NextEnemy

  ; ---- X overlap? ----
  lda player_x
  clc
  adc #$0F
  cmp ene_x,y
  bcc CPE_NextEnemy

  lda ene_x,y
  clc
  adc tmp2
  cmp player_x
  bcc CPE_NextEnemy


  ; ---- Y overlap? ----
  lda player_y
  clc
  adc #$0F
  cmp ene_y,y
  bcc CPE_NextEnemy

  lda ene_y,y
  clc
  adc tmp2
  cmp player_y
  bcc CPE_NextEnemy


  ; ---- HIT ----
  lda #FLAG_CLEAR
  sta ene_alive,y

  lda ene_x,y
  sta hit_src_x

  ; ---- SHIELD CHECK ----
  lda shield_timer
  beq @no_shield

  ; Shield absorbs the hit:
  ; - do NOT damage player
  ; - optional feedback + brief invuln guard
  lda #$08
  sta invuln_timer        ; prevents immediate re-hit pileups
  ; optional: show flash color you use for shield
  lda #$11
  sta catch_pickup_flash  ; or a dedicated shield_flash if you have one
  jsr PlaySfxPickup       ; or make a PlaySfxShield

  rts

@no_shield:
  jsr PlayerTakeHit
  rts


CPE_NextEnemy:
  iny
  jmp CPE_EnemyLoop

CPE_Done:
  rts

; ------------------------------------------------------------
; GetEnemyExtent
; in:  Y = enemy index
; out: A = extent (7 for 8x8, 15 for 16x16)
; uses: none (A only)
; ------------------------------------------------------------
GetEnemyExtent:
  lda ene_type,y
  cmp #EN_C
  bcc @small          ; A/B are < EN_C
    lda #$0F          ; 16x16 => +15
    rts
@small:
  lda #$07            ; 8x8  => +7
  rts

; ------------------------------------------------------------
; PlayerTakeHit
; - Flash screen
; - Decrement lives (if >0)
; - Mark HUD dirty
; - Start invulnerability frames
; - If lives reaches 0 => PlayerSetOver
; ------------------------------------------------------------
PlayerTakeHit:

lda invuln_timer
bne @done 
  lda #FLASH_HIT_FR
  sta screen_flash_timer

  lda lives
  bne :+
    jmp PlayerSetOver          ; already 0
:

  jsr SafeDecrementLives
  jsr HUD_MarkDirty          ; <-- ALWAYS redraw hearts after a hit

  lda lives
  bne :+ 
    jmp PlayerSetOver          ; if we just hit 0, go over now
:


  lda #INVULN_FRAMES
  sta invuln_timer

  jsr PlaySfxPlayerHit

    lda #$06              ; duration (try 4..8)
  sta player_kb_timer

  ; dx = push away from hit source X
  lda player_x
  cmp hit_src_x
  bcc @push_right

@push_left:
  lda #$FF              ; -1
  bne @dx_set

@push_right:
  lda #$01              ; +1
@dx_set:
  sta player_kb_dx


  lda #$01              ; small downward nudge (optional)
  sta player_kb_dy

@done:
  rts

CollidePlayerCatch:
  ldx #$00
@loop:
  cpx #CATCH_MAX
  bcs @done

  lda catch_alive,x
  beq @next

  ; ---- dx = |catch_x - player_x| ----
  lda catch_x,x
  sec
  sbc player_x
  bcs @dx_pos
    eor #$FF
    clc
    adc #$01
@dx_pos:
  cmp #PLAYER_W
  bcs @next

  ; ---- dy = |catch_y - player_y| ----
  lda catch_y,x
  sec
  sbc player_y
  bcs @dy_pos
    eor #$FF
    clc
    adc #$01
@dy_pos:
  cmp #PLAYER_H
  bcs @next

  ; ---- COLLISION! ----
  lda #$00
  sta catch_alive,x

  ; cache kind (tile)
  lda catch_tile,x
  sta tmp6

  ; common feedback
  lda #$11
  sta catch_pickup_flash
  jsr PlaySfxPickup

  ; everyone gets +1 life
  jsr AwardLifePlus1

  ; branch by kind 
  lda tmp6
  cmp #TILE_CATCH_CORE_BASE        ; $F0
  beq @kind_core
  cmp #TILE_CATCH_CORE_FRACTURED       ; $F1
  beq @kind_fract
  cmp #TILE_CATCH_CORE_FINAL     ; $F2
  beq @kind_final
  jmp @done                   ; unknown => just life

@kind_core:
  jsr Add100
  jmp @done

@kind_fract:
  lda #SHIELD_FRAMES
  sta shield_timer
  jsr ClearGunJam
  jsr Add500
  jmp @done

@kind_final:
  jsr ClearEnemies_AwardScore
  jsr Add1000
  jmp @done

@next:
  inx
  bne @loop

@done:
  rts




UpdateCatchPickupFlash:
  lda catch_pickup_flash
  beq @done
  dec catch_pickup_flash
@done:
  rts


; ------------------------------------------------------------
; CollideBulletsBoss
; - Bullet vs boss AABB (16x16)
; - On boss death: clears bar + clears actors/bullets + advances level
; ------------------------------------------------------------
CollideBulletsBoss:
  lda boss_alive
  bne :+
    rts
:

  ldx #$00
@bul_loop:
  cpx #BULLET_MAX
  bcs @done

  lda bul_alive,x
  beq @next_b

  ; AABB check: bullet point vs 16x16 boss box
  ; X in range?
  lda bul_x,x
  cmp boss_x
  bcc @next_b
  sec
  sbc boss_x
  cmp #BOSS_W
  bcs @next_b

  ; Y in range?
  lda bul_y,x
  cmp boss_y
  bcc @next_b
  sec
  sbc boss_y
  cmp #BOSS_H
  bcs @next_b

  ; HIT!
  lda #FLAG_CLEAR
  sta bul_alive,x

  lda #BOSS_HIT_FLASH_FR
  sta boss_flash

  lda boss_hp
  beq @next_b
  sec
  sbc #$01
  sta boss_hp

  lda #$01
  sta bossbar_dirty


  ; ---- PHASE CHANGE: if boss_hp * 2 < boss_hp_max ----
  lda boss_pattern
  bne :+                ; already switched? skip
    lda boss_hp
    asl
    cmp boss_hp_max
    bcs :+
      lda #$01
      sta boss_pattern
:



  lda boss_hp
  bne @next_b

  ; boss dead
  lda #FLAG_CLEAR
  sta boss_alive

  lda #$01
  sta boss_hp_clear_pending


  ;jsr PlaySfxBossKill         ;
  jsr AddBossScore            ; <-- ADD THIS

  jsr ClearBossBullets
  jsr ClearPlayerBullets
  jsr ClearActors             ; optional but recommended

  jsr BossBar_QueueClear

  jsr NextLevel
  rts


@next_b:
  inx
  bne @bul_loop

@done:
  rts