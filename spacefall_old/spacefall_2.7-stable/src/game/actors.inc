; ----------------------------
; ClearActors
; - kills all bullets and enemies AND boss bullets
; ----------------------------
ClearActors:
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


