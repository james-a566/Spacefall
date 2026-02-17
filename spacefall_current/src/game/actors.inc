; ----------------------------
; ClearActors
; - kills all bullets and enemies AND boss bullets
; ----------------------------
ClearActors:
  lda #$00
  sta bul_any        ; if you have it
  sta ene_any        ; if you have it
  sta bul_count      ; if you add it
  sta ene_count      ; if you add it
  ; (boss bullets likely have their own count/any too)

  ; player bullets
  ldx #$00
@b:
  cpx #BULLET_MAX
  bcs @b_done
  lda #$00
  sta bul_alive,x
  inx
  bne @b
@b_done:

  ; enemies
  ldx #$00
@e:
  cpx #ENEMY_MAX
  bcs @e_done
  lda #$00
  sta ene_alive,x
  inx
  bne @e
@e_done:

  ; boss bullets  <<< THIS IS THE IMPORTANT PART
  jsr ClearBossBullets

  rts

; ------------------------------------------------------------
; ClearPlayerBullets
; - kills all player bullets
; ------------------------------------------------------------
ClearPlayerBullets:
  ldx #$00
@loop:
  cpx #BULLET_MAX
  bcs @done

  lda #$00
  sta bul_alive,x

  inx
  jmp @loop

@done:
  rts

; Adds score for enemy in slot Y (uses ene_type,y)
; Requires EnemyScore_HTO table (hundreds,tens,ones per type)
AddScoreForEnemyY:
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
  rts

; Clears all active enemies and awards their point values.
ClearEnemies_AwardScore:
  ldy #$00
@loop:
  cpy #ENEMY_MAX
  bcs @done

  lda ene_alive,y
  beq @next

  jsr AddScoreForEnemyY
  lda #$00
  sta ene_alive,y

@next:
  iny
  bne @loop
@done:
  rts

; ------------------------------------------------------------
; ClearCatch
; - Clears all catch objects (cores/fractured/final)
; - Safe to call during transitions (boss trigger, banner, etc.)
; ------------------------------------------------------------
ClearCatch:
  ldx #$00
@loop:
  lda #$00
  sta catch_alive,x
  ; Optional hygiene (not required, but helps debugging):
  ; sta catch_x,x
  ; sta catch_y,x
  ; sta catch_tile,x
  ; sta catch_attr,x
  inx
  cpx #CATCH_MAX
  bne @loop
  rts

; ------------------------------------------------------------
; ClearEnemies
; - Clears all enemy slots
; - Also clears flash/hp so you don't get leftover death/hit visuals
; ------------------------------------------------------------
ClearEnemies:
  lda #$00
  sta ene_count
  sta ene_any        ; optional: keep flags consistent

  ldx #$00
@loop:
  lda #$00
  sta ene_alive,x
  sta ene_flash,x
  sta ene_hp,x

  ; Optional (only if these arrays exist in your build):
  ; sta ene_timer,x
  ; sta ene_variant,x
  ; sta ene_dx,x
  ; sta ene_y_prev,x
  ; sta ene_x,x
  ; sta ene_y,x

  inx
  cpx #ENEMY_MAX
  bne @loop
  rts

