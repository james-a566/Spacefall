.segment "CODE"

; ------------------------------------------------------------
; SpawnCatch
; returns: C=1 spawned, C=0 skipped
; ------------------------------------------------------------
SpawnCatch:
  lda catch_count
  cmp level_catch_cap
  bcc @can_spawn
    clc
    rts

@can_spawn:
  ; find a free slot
  ldx #$00
@find:
  cpx #CATCH_MAX
  bcs @no_slot
  lda catch_alive,x
  beq @use
  inx
  bne @find

@use:
  lda #$01
  sta catch_alive,x
  inc catch_count

  lda #CATCH_SPAWN_Y
  sta catch_y,x

  jsr ChooseCatchKind
  sta catch_tile,x

  lda #CATCH_ATTR
  sta catch_attr,x

  ; ---- X position: O(1), no retries ----
  jsr NextRand
  and #$1F              ; 0..31
  cmp #29
  bcc :+
    sbc #29
:
  tay
  lda CatchXTable,y
  sta catch_x,x

  sec
  rts

@no_slot:
  clc
  rts

CatchXTable:
  .byte $08,$10,$18,$20,$28,$30,$38,$40,$48,$50,$58,$60,$68,$70,$78
  .byte $80,$88,$90,$98,$A0,$A8,$B0,$B8,$C0,$C8,$D0,$D8,$E0,$E8

UpdateJamFlash:
  lda jam_flash_timer
  beq @done
  dec jam_flash_timer
@done:
  rts




UpdateCatch:
  lda #$00
  sta catch_any

  ; ---- spawn cooldown ----
  lda catch_cd
  beq @do_spawn
  dec catch_cd
  jmp @move

@do_spawn:
  jsr NextRand
  cmp level_catch_good_thr
  bcs @reload_cd          ; gate failed -> no reseed

  jsr SpawnCatch          ; cap/slot may still block
  jsr ReseedCatchSpawn    ; only reseed when we at least tried

@reload_cd:
  lda level_catch_cd4
  bne :+
    lda #$01
:
  asl
  asl
  sta catch_cd
  jmp @move




@move:
  ldx #$00
@loop:
  cpx #CATCH_MAX
  bcs @done_all

  lda catch_alive,x
  beq @next

  lda #$01
  sta catch_any

  lda catch_y,x
  clc
  adc #CATCH_SPD
  sta catch_y,x

  cmp #CATCH_KILL_Y
  bcc @next
    lda #$00
    sta catch_alive,x


@next:
  inx
  jmp @loop          ; (safer than bne if CATCH_MAX might change)

@done_all:
  rts

; ChooseCatchKind should return one of:
;   TILE_CATCH_CORE_BASE / TILE_CATCH_CORE_FRACTURED / TILE_CATCH_CORE_FINAL
ChooseCatchKind:
  jsr NextRand
  eor rng_hi
  clc
  adc frame_lo

  cmp level_thrFinal
  bcc @final

  cmp level_thrFrac
  bcc @fract

@core:
  lda #TILE_CATCH_CORE_BASE
  rts

@fract:
  lda #TILE_CATCH_CORE_FRACTURED
  rts

@final:
  lda #TILE_CATCH_CORE_FINAL
  rts




; ---------------------------------
; CountActiveCatch -> A = count  
; ---------------------------------
CountActiveCatch:
  ldx #$00
  lda #$00
@loop:
  cpx #CATCH_MAX
  bcs @done
  ldy catch_alive,x
  beq @next
  clc
  adc #$01
@next:
  inx
  jmp @loop
@done:
  sta tmp0          ; optional: keep a copy
  rts

CollideBulletsCatch:
  ldx #$00                    ; bullet index
@bul_loop:
  cpx #BULLET_MAX
  bcs @done

  lda bul_alive,x
  beq @bul_next

  ; cache bullet position
  lda bul_x,x
  sta tmp0                    ; bul_x
  lda bul_y,x
  sta tmp1                    ; bul_y

  ldy #$00                    ; catch index
@catch_loop:
  cpy #CATCH_MAX
  bcs @bul_next               ; no hit for this bullet

  lda catch_alive,y
  beq @catch_next

  ; ----------------------------------------
  ; X: bul_x in [catch_x .. catch_x+7] ?
  ; ----------------------------------------
  lda tmp0                    ; bul_x
  cmp catch_x,y
  bcc @catch_next             ; bul_x < catch_x

  lda tmp0                    ; bul_x
  sec
  sbc catch_x,y               ; bul_x - catch_x
  cmp #$08
  bcs @catch_next             ; >= 8 => to the right

  ; ----------------------------------------
  ; Y: bul_y in [catch_y .. catch_y+7] ?
  ; ----------------------------------------
  lda tmp1                    ; bul_y
  cmp catch_y,y
  bcc @catch_next             ; bul_y < catch_y

  lda tmp1                    ; bul_y
  sec
  sbc catch_y,y               ; bul_y - catch_y
  cmp #$08
  bcs @catch_next

  ; ============================
  ; HIT!
  ; ============================
  lda #$00
  sta bul_alive,x
  sta catch_alive,y

  lda #$30
  sta player_blink_timer

  jsr PlaySfxJamClick
  lda level_jam_frames
  sta jam_timer

  lda #JAM_FR
  sta gun_jam_timer

  lda #$0C
  sta jam_flash_timer

  lda #$00
  sta player_cd

  jsr SafeDecrementLives
  jsr HUD_MarkDirty

  jmp @bul_next

@catch_next:
  iny
  bne @catch_loop

@bul_next:
  inx
  bne @bul_loop

@done:
  rts
