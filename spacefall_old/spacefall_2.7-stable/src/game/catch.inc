.segment "CODE"

; ------------------------------------------------------------
; SpawnCatch
; returns: C=1 spawned, C=0 skipped
; ------------------------------------------------------------
SpawnCatch:
  jsr CountActiveCatch     ; A = active count
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

  lda #CATCH_SPAWN_Y
  sta catch_y,x

  jsr ChooseCatchKind
  sta catch_tile,x

  lda #CATCH_ATTR
  sta catch_attr,x


  ; ---- X position (multiples of 8, with failsafe) ----
  lda #$10
  sta tmp1

@rand_x:
  jsr NextRand
  and #$F8
  cmp #$08
  bcc @retry
  cmp #$F0
  bcs @retry
  sta catch_x,x
  sec
  rts

@retry:
  dec tmp1
  bne @rand_x

  lda #$80
  sta catch_x,x
  sec
  rts

@no_slot:
  clc
  rts




UpdateCatch:
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

  ; y += CATCH_SPD   (or make this a knob later too)
  lda catch_y,x
  clc
  adc #CATCH_SPD
  sta catch_y,x

  ; kill if offscreen
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

; ------------------------------------------------------------
; CollideBulletsCatch
; - If a bullet hits a catch object:
;     * destroy bullet
;     * destroy catch object
;     * jam gun (penalty)
; - Assumes 8x8 sprites for both
; ------------------------------------------------------------
CollideBulletsCatch:
  ldx #$00                    ; bullet index
@bul_loop:
  cpx #BULLET_MAX
  bcs @done

  lda bul_alive,x
  beq @bul_next

  ; cache bullet position in tmp0/tmp1
  lda bul_x,x
  sta tmp0                    ; tmp0 = bul_x
  lda bul_y,x
  sta tmp1                    ; tmp1 = bul_y

  ldy #$00                    ; catch index
@catch_loop:
  cpy #CATCH_MAX
  bcs @bul_next               ; no hit for this bullet

  lda catch_alive,y
  beq @catch_next

  ; ----------------------------
  ; X overlap: |bul_x - catch_x| < 8
  ; ----------------------------
  lda tmp0                    ; bul_x
  sec
  sbc catch_x,y               ; A = bul_x - catch_x
  bcs @x_pos
  eor #$FF
  clc
  adc #$01                    ; abs(A)
@x_pos:
  cmp #$08
  bcs @catch_next             ; >= 8 => no overlap in X

  ; ----------------------------
  ; Y overlap: |bul_y - catch_y| < 8
  ; ----------------------------
  lda tmp1                    ; bul_y
  sec
  sbc catch_y,y               ; A = bul_y - catch_y
  bcs @y_pos
  eor #$FF
  clc
  adc #$01                    ; abs(A)
@y_pos:
  cmp #$08
  bcs @catch_next

  ; ============================
  ; HIT!
  ; ============================
  lda #$00
  sta bul_alive,x
  sta catch_alive,y      ; <-- y is the catch index

  ; optional: blink the player (oops feedback)
  lda #$30             ; tune duration
  sta player_blink_timer

  ; ---- penalty: jam gun ----
  jsr PlaySfxJamClick
  lda level_jam_frames
  sta jam_timer

  lda #JAM_FR
  sta gun_jam_timer

  lda #$0C
  sta jam_flash_timer

  lda #$00
  sta player_cd          ; make jam apply immediately

  jsr SafeDecrementLives
  jsr HUD_MarkDirty

  ; done with this bullet (it’s gone)
  jmp @bul_next



@catch_next:
  iny
  bne @catch_loop             ; safe if CATCH_MAX < 256

@bul_next:
  inx
  bne @bul_loop

@done:
  rts

UpdateJamFlash:
  lda jam_flash_timer
  beq @done
  dec jam_flash_timer
@done:
  rts