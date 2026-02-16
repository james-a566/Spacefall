.segment "CODE"


; ClearOAMShadow
; sets Y=$FE for all 64 sprites in OAM_BUF
; ------------------------------------------------------------
; ClearOAMShadow
; - Fills OAM_BUF with Y=$FE (hidden) to start from a clean slate
; ------------------------------------------------------------
ClearOAMShadow:
  ldx #$00
@loop:
  lda #$FE
  sta OAM_BUF,x     ; Y byte
  inx
  inx
  inx
  inx
  bne @loop
  rts

; ----------------------------
; BuildOAM
; - OAM layout:
;   sprites 0-3  = player (2x2)
;   sprites 4-7  = bullets
;   sprites 8..  = enemies
; ----------------------------
; ============================================================
; RENDERING (SPRITES / OAM SHADOW)
;
; Overview:
;   - Main loop builds an OAM shadow buffer (OAM_BUF) each frame.
;   - NMI performs the actual OAM DMA ($4014) to upload sprites to PPU.
;
; Sprite slot map (by convention in this project):
;   0..3   : player ship (2x2 metasprite = 4 hardware sprites)
;   4..7   : bullets (up to BULLET_MAX sprites)
;   8..??  : enemies (mix of 1x1 and 2x2 metasprites)
;   later  : boss (2x2) + UI overlays (banner / score / game over)
;
; Notes:
;   - “Hide sprite” convention: set Y=$FE in OAM to hide.
;   - Keep OAM writes in RAM only; do not touch $2004 outside NMI/DMA.
; ============================================================

; ------------------------------------------------------------
; BuildOAM
; - Clears OAM shadow
; - Draws sprites for the current game_state
; - Does NOT do OAM DMA (NMI does that)
; ------------------------------------------------------------

BuildOAM:
  jsr ClearOAMShadow

  lda game_state
  cmp #STATE_TUTORIAL
  bne @check_title
    jsr DrawTutorialIconSprites
    tya
    tax                  ; X = first unused OAM byte offset
    jmp @hide_tail

@check_title:
  cmp #STATE_TITLE
  bne @check_over
    rts

@check_over:
  lda game_state
  cmp #STATE_OVER
  bne @normal_draw
    rts

@normal_draw:
  

  ; ----------------------------
  ; Player metasprite (sprites 0-3)
  ; ----------------------------

  ; BLINK WINS: if blink is active and we're on a hide frame, hide & skip draw
  lda player_blink_timer
  beq @draw_player

  lda frame_lo
  and #$08
  beq @draw_player      ; even frame => draw

@hide_player:
  lda #$FE
  sta OAM_BUF+$00
  sta OAM_BUF+$04
  sta OAM_BUF+$08
  sta OAM_BUF+$0C
  jmp @after_player     ; IMPORTANT: do not run attr/flash/draw code

@draw_player:

 

  ; (NOW do your tmp4 attr logic: jam flash / pickup flash / etc)
  lda player_attr
  sta tmp4

  ; ---- jam flash wins ----
  lda jam_flash_timer
  beq @check_pickup
  and #$03
  beq @pattr_ready
  lda player_attr
  and #%11111100
  ora #$01
  sta tmp4
  jmp @pattr_ready

@check_pickup:
  lda catch_pickup_flash
  beq @pattr_ready
  and #$03
  beq @pattr_ready
  lda player_attr
  and #%11111100
  ora #$03
  sta tmp4

@pattr_ready:


  ; pick base tile for player metasprite
  lda shield_timer
  beq @base_normal
    lda #TILE_PLAYER_SHIELD_F0
    bne @base_set
@base_normal:
  lda #TILE_PLAYER_F0
@base_set:
  sta tmp5         ; tmp5 = base tile for TL


  ; TL
  lda player_y
  sta OAM_BUF+0
  lda tmp5
  sta OAM_BUF+1
  lda tmp4
  sta OAM_BUF+2
  lda player_x
  sta OAM_BUF+3

  ; TR
  lda player_y
  sta OAM_BUF+4
  lda tmp5
  clc
  adc #$01
  sta OAM_BUF+5
  lda tmp4
  sta OAM_BUF+6
  lda player_x
  clc
  adc #$08
  sta OAM_BUF+7

  ; BL
  lda player_y
  clc
  adc #$08
  sta OAM_BUF+8
  lda tmp5
  clc
  adc #$02
  sta OAM_BUF+9
  lda tmp4
  sta OAM_BUF+10
  lda player_x
  sta OAM_BUF+11

  ; BR
  lda player_y
  clc
  adc #$08
  sta OAM_BUF+12
  lda tmp5
  clc
  adc #$03
  sta OAM_BUF+13
  lda tmp4
  sta OAM_BUF+14
  lda player_x
  clc
  adc #$08
  sta OAM_BUF+15



  

@after_player:


  ; ----------------------------
  ; Bullets (sprite start at 5 )
  ; ----------------------------


  ; ------------------------------------------------------------
  ; Bullet OAM start
  ; - Normal play: bullets start at BULLET_OAM_BASE ($10)
  ; - Boss fight: boss metasprite uses BOSS_OAM..(BOSS_OAM_AFTER-1)
  ;              so bullets must start at BOSS_OAM_AFTER
  ; ------------------------------------------------------------
  lda game_state
  cmp #STATE_BOSS
  bne @bullets_normal
    ldy #BOSS_OAM_AFTER
    jmp @bullets_start_ok
@bullets_normal:
  ldy #BULLET_OAM_BASE
@bullets_start_ok:
  ldx #$00
@bul_draw:
  cpy #OAM_DYNAMIC_LIMIT
  bcs @bul_done

  cpx #BULLET_MAX
  bcs @bul_done

  lda bul_alive,x
  beq @bul_hide

  ; Y
  lda bul_y,x
  sta OAM_BUF,y
  iny
  ; tile
lda #TILE_PBULLET_0
  sta OAM_BUF,y
  iny
  ; attr
  lda #$00          ; palette 0 
  sta OAM_BUF,y
  iny
  ; X
  lda bul_x,x
  sta OAM_BUF,y
  iny
  jmp @bul_next

@bul_hide:
  lda #$FE
  sta OAM_BUF,y
  iny
  iny
  iny
  iny

@bul_next:
  inx
  bne @bul_draw

@bul_done:

@skip_bullets:

  ; ----------------------------
  ; Enemies (sprites 24..)
  ; - A/B are 1x1
  ; - C/D/E are 2x2 metasprites
  ; ----------------------------

  ldx #$00
@ene_draw:
  cpx #ENEMY_MAX
  bcc @ene_in_range
  jmp @ene_done

@ene_in_range:
  lda ene_alive,x
  bne @ene_alive_ok
  jmp @ene_skip

@ene_alive_ok:

  ; ----------------------------
  ; Enemy ATTR (flash pop)
  ; - if ene_flash>0, strobe alt palette
  ; - keep flip/priority bits from ENEMY_ATTR
  ; ----------------------------
  lda #ENEMY_ATTR
  sta tmp4                  ; default attr

  lda ene_flash,x
  beq @attr_ready

  lda frame_lo              ; consistent strobe
  and #$01
  beq @attr_ready

  lda #ENEMY_ATTR
  and #%11111100            ; keep flip/priority bits
  ora #$02                   ; flash to palette 2
  sta tmp4

@attr_ready:


  ; decide size by type: C/D/E are 2x2 (type >= EN_C)
  lda ene_type,x
  cmp #EN_C
  bcs @ene_is_2x2     ; >= EN_C => 2x2
  jmp @ene_draw_1x1   ; <  EN_C => 1x1 (long jump)

@ene_is_2x2:
  ; ---- OAM room guard: 2x2 needs 16 bytes before $E0 ----
  cpy #OAM_2X2_LIMIT
  bcc :+
    jmp @ene_done
:

  ; ============================
  ; 2x2 metasprite (C/D/E)
  ; ============================

  ; pick tile set for C/D/E
  lda ene_type,x
  cmp #EN_C
  beq @ene_tiles_C
  cmp #EN_D
  beq @ene_tiles_D
  ; else E


@ene_tiles_E:
  lda ene_variant,x
  beq @e_normal

@e_shield:
  lda #TILE_ENEMY_E_F0
  sta tmp0
  lda #TILE_ENEMY_E_F0+1
  sta tmp1
  lda #TILE_ENEMY_E_F0+2
  sta tmp2
  lda #TILE_ENEMY_E_F0+3
  sta tmp3
  jmp @ene_draw_2x2


@e_normal:
  lda #TILE_ENEMY_E_F1
  sta tmp0
  lda #TILE_ENEMY_E_F1+1
  sta tmp1
  lda #TILE_ENEMY_E_F1+2
  sta tmp2
  lda #TILE_ENEMY_E_F1+3
  sta tmp3
  jmp @ene_draw_2x2




@ene_tiles_C:
  lda #TILE_ENEMY_C_F0
  sta tmp0
  lda #TILE_ENEMY_C_F0+1
  sta tmp1
  lda #TILE_ENEMY_C_F0+2
  sta tmp2
  lda #TILE_ENEMY_C_F0+3
  sta tmp3
  jmp @ene_draw_2x2


@ene_tiles_D:
  lda #TILE_ENEMY_D_F0
  sta tmp0
  lda #TILE_ENEMY_D_F0+1
  sta tmp1
  lda #TILE_ENEMY_D_F0+2
  sta tmp2
  lda #TILE_ENEMY_D_F0+3
  sta tmp3


  ; --------------------------------------------
  ; Optional: make D "bank" based on dx
  ; True 2x2 HFLIP = set HFLIP bit AND swap tiles
  ; --------------------------------------------
  lda ene_dx,x
  bmi @d_flip_left
  ; right: ensure HFLIP clear
  lda tmp4
  and #%10111111      ; clear bit 6
  sta tmp4
  jmp @ene_draw_2x2

@d_flip_left:
  ; set HFLIP
  lda tmp4
  ora #%01000000
  sta tmp4

  ; swap left/right tiles so the 16x16 mirrors correctly
  lda tmp0
  pha
  lda tmp1
  sta tmp0
  pla
  sta tmp1

  lda tmp2
  pha
  lda tmp3
  sta tmp2
  pla
  sta tmp3

  jmp @ene_draw_2x2


@ene_draw_2x2:
  ; cache x/y and x+8 / y+8
  lda ene_x,x
  sta tmp5          ; x0
  clc
  adc #$08
  sta tmp6          ; x1

  lda ene_y,x
  sta tmp7          ; y0
  clc
  adc #$08
  sta tmp8          ; y1

  ; phase = frame_lo & 3
  lda frame_lo
  and #$03
  beq @p0
  cmp #$01
  beq @p1
  cmp #$02
  bne :+
    jmp @p2
  :
  ; else phase 3
  jmp @p3

; ------------------------------------------------
; Phase 0: TL TR BL BR  
; ------------------------------------------------
@p0:
  ; TL (x0,y0) tile tmp0
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; TR (x1,y0) tile tmp1
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  ; BL (x0,y1) tile tmp2
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp2
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; BR (x1,y1) tile tmp3
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp3
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  jmp @ene_next

; ------------------------------------------------
; Phase 1: TR TL BR BL  (swap left/right, bottom order swapped)
; ------------------------------------------------
@p1:
  ; TR
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  ; TL
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; BR
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp3
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  ; BL
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp2
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  jmp @ene_next

; ------------------------------------------------
; Phase 2: BL BR TL TR  (bottom row first)
; ------------------------------------------------
@p2:
  ; BL
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp2
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; BR
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp3
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  ; TL
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; TR
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  jmp @ene_next

; ------------------------------------------------
; Phase 3: BR BL TR TL  (bottom-right first)
; ------------------------------------------------
@p3:
  ; BR
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp3
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  ; BL
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp2
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; TR
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  ; TL
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  jmp @ene_next




@ene_draw_1x1:
  ; ---- OAM room guard: stop before reserved boss-bullet slots ----
  cpy #OAM_DYNAMIC_LIMIT
  bcs @ene_done

  ; ============================
  ; 1x1 enemy (A/B)
  ; ============================

  ; Y
  lda ene_y,x
  sta OAM_BUF,y
  iny

  ; tile
  lda ene_type,x
  cmp #EN_A
  beq @tile_A_1
  ; else B
  lda #TILE_ENEMY_B_F0
  bne @tile_done_1
@tile_A_1:
  lda #TILE_ENEMY_A_F0
@tile_done_1:

  sta OAM_BUF,y
  iny

  ; attr
  lda tmp4
  sta OAM_BUF,y

  iny

  ; X
  lda ene_x,x
  sta OAM_BUF,y
  iny

  jmp @ene_next


@ene_skip:
  ; ---- OAM room guard ----
  cpy #OAM_DYNAMIC_LIMIT
  bcs @ene_done

  lda ene_type,x
  cmp #EN_C
  bcs @skip_16        ; C/D/E would have been 2x2

  ; A/B would have been 1x1: hide 1 sprite (4 bytes)
  lda #$FE
  sta OAM_BUF,y
  tya
  clc
  adc #$04
  tay
  jmp @ene_next

@skip_16:
  lda #$FE
  sta OAM_BUF,y
  sta OAM_BUF+4,y
  sta OAM_BUF+8,y
  sta OAM_BUF+12,y
  tya
  clc
  adc #$10
  tay
  jmp @ene_next


@ene_next:
  inx
  jmp @ene_draw

@ene_done:


  ; ---- catch sprites (skip if we'd enter reserved boss-bullet region) ----
  cpy #OAM_DYNAMIC_LIMIT
  bcs @skip_catch_draw
  jsr DrawCatchSprites
@skip_catch_draw:

  ; ---- banner overlay ----
  lda game_state
  cmp #STATE_BANNER
  beq @draw_banner

@hide_banner:
  jsr HideBannerSprites
  jmp @after_banner

@draw_banner:
  cpy #OAM_DYNAMIC_LIMIT
  bcs @after_banner
  jsr DrawLevelBannerSprites

@after_banner:

  ; ---- BOSS sprites + boss bullets (boss state only) ----
  ; Draw boss LAST so enemies/catch/banner can't overwrite it.
  lda game_state
  cmp #STATE_BOSS
  bne @after_boss_draw

    ldy #BOSS_OAM
    jsr DrawBossSprites     ; uses Y as current OAM offset

    jsr DrawBossBullets_Fixed   ; sprites 56–59 ($E0..$EF)
@after_boss_draw:

   ; --------------------------------------------
  ; Hide remaining sprites (but DO NOT touch
  ; fixed boss bullet slots at $E0..$EF)
  ; --------------------------------------------
  tya
  and #$FC          ; align to sprite boundary

  cmp #$F0
  bcs :+
    lda #$F0        ; clamp start to $F0 so we won't overwrite $E0..$EF
:
  tax


@hide_tail:
  lda #$FE
  sta OAM_BUF,x
  inx
  inx
  inx
  inx
  bne @hide_tail
  rts


; ------------------------------------------------------------
; DrawCatchSprites
; - Draws CATCH_MAX 1x1 sprites starting at current OAM cursor
; - INPUT:  Y = byte offset into OAM_BUF (must be multiple of 4)
; - OUTPUT: Y = advanced cursor
; - Safety: stops early if Y reaches OAM_DYNAMIC_LIMIT ($E0),
;           leaving remaining sprites hidden (ClearOAMShadow already did this).
; ------------------------------------------------------------
DrawCatchSprites:
  ldx #$00

@loop:
  ; ---- OAM room guard ----
  cpy #OAM_DYNAMIC_LIMIT
  bcs @done

  cpx #CATCH_MAX
  bcs @done

  lda catch_alive,x
  beq @hide_one

  ; Y
  lda catch_y,x
  sta OAM_BUF,y
  iny

  ; TILE (per-object)
  lda catch_tile,x
  sta OAM_BUF,y
  iny

  ; ATTR (array)
  lda catch_attr,x
  sta OAM_BUF,y
  iny

  ; X
  lda catch_x,x
  sta OAM_BUF,y
  iny

  inx
  jmp @loop

@hide_one:
  lda #$FE
  sta OAM_BUF,y     ; hide sprite by Y=$FE
  iny
  iny
  iny
  iny
  inx
  jmp @loop

@done:
  rts


; ------------------------------------------------------------
; DrawLevelBannerSprites
; - Draws “LEVEL N” where N is 1..99 (works fine for 1..12)
; - Digits are tiles TILE_DIGIT_BASE + 0..9
; ------------------------------------------------------------
DrawLevelBannerSprites:
  ldx #BANNER_OAM

  lda #BANNER_X0
  sta tmp_xcur

  ; L
  lda #TILE_L
  jsr _DrawBannerChar
  ; E
  lda #TILE_E
  jsr _DrawBannerChar
  ; V
  lda #TILE_V
  jsr _DrawBannerChar
  ; E
  lda #TILE_E
  jsr _DrawBannerChar
  ; L
  lda #TILE_L
  jsr _DrawBannerChar

  ; space (advance X by 8, no sprite)
  lda tmp_xcur
  clc
  adc #$08
  sta tmp_xcur

  ; ----------------------------
  ; level_num = level_idx + 1
  ; ----------------------------
  lda level_idx
  clc
  adc #$01
  sta tmp0            ; tmp0 = level number (1..)

  ; if tmp0 < 10 => draw one digit
  lda tmp0
  cmp #$0A
  bcc @one_digit

  ; else: draw tens digit (for 10..19, tens is '1')
  lda #$01
  clc
  adc #TILE_DIGIT_BASE
  jsr _DrawBannerChar

  ; ones = tmp0 - 10  (0..9)
  lda tmp0
  sec
  sbc #$0A
  clc
  adc #TILE_DIGIT_BASE
  jsr _DrawBannerChar
  rts

@one_digit:
  lda tmp0
  clc
  adc #TILE_DIGIT_BASE
  jsr _DrawBannerChar
  rts



; A = tile id, X = OAM offset, tmp_xcur = screen X cursor
_DrawBannerChar:
  pha
  lda #BANNER_Y
  sta OAM_BUF,x
  inx
  pla
  sta OAM_BUF,x
  inx
  lda #BANNER_ATTR
  sta OAM_BUF,x
  inx
  lda tmp_xcur
  sta OAM_BUF,x
  inx

  lda tmp_xcur
  clc
  adc #$08
  sta tmp_xcur
  rts




; -------------------------------------------------------------
; Boss Render
; -------------------------------------------------------------

; ------------------------------------------------------------
; DrawBossSprites
; - Draws boss as a 3x3 metasprite (9 hardware sprites)
; - Assumes boss_x/boss_y are top-left
; - Uses Y shake: base_y = boss_y + boss_shake_dy
; - IMPORTANT: must not write into $E0..$EF (fixed boss bullet slots)
; ------------------------------------------------------------
DrawBossSprites:
  lda boss_alive
  bne :+
    rts
:

  ; ---- ATTR with flash ----
  lda #BOSS_ATTR
  sta tmp0
  lda boss_flash
  beq @attr_ok
  lda frame_lo
  and #$04
  beq @attr_ok
  lda #BOSS_ATTR
  eor #$01
  sta tmp0
@attr_ok:

  ; ---- base X (no shake here) ----
  lda boss_x
  sta tmp1

  ; ---- base Y with shake ----
  lda boss_y
  clc
  adc boss_shake_dy
  sta tmp2

  ; ============================
  ; Row 0: y = base_y + 0
  ; ============================

  ; TL
  lda tmp2
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_TL
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny

  ; TM
  lda tmp2
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_TM
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  ; TR
  lda tmp2
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_TR
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  clc
  adc #$10
  sta OAM_BUF,y
  iny


  ; ============================
  ; Row 1: y = base_y + 8
  ; ============================

  ; ML
  lda tmp2
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_ML
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny

  ; MM
  lda tmp2
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_MM
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  ; MR
  lda tmp2
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_MR
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  clc
  adc #$10
  sta OAM_BUF,y
  iny


  ; ============================
  ; Row 2: y = base_y + 16
  ; ============================

  ; BL
  lda tmp2
  clc
  adc #$10
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_BL
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny

  ; BM
  lda tmp2
  clc
  adc #$10
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_BM
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  ; BR
  lda tmp2
  clc
  adc #$10
  sta OAM_BUF,y
  iny
  lda #TILE_BOSS_BR
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp1
  clc
  adc #$10
  sta OAM_BUF,y
  iny

  rts

; ------------------------------------------------------------
; DrawBossBullets
; - emits 1 sprite per live boss bullet
; - expects: Y = OAM write cursor
; - returns: Y advanced
; ------------------------------------------------------------
DrawBossBullets:
  ldx #$00
@loop:
  cpx #BOSS_BULLET_MAX
  bcs @done

  lda bossbul_alive,x
  beq @next

  ; OAM safety: need 4 bytes
  cpy #$FD
  bcs @done

  lda bossbul_y,x
  sta OAM_BUF,y
  iny

  lda #TILE_PBULLET_0
  sta OAM_BUF,y
  iny

  lda #BOSS_BULLET_ATTR
  sta OAM_BUF,y
  iny

  lda bossbul_x,x
  sta OAM_BUF,y
  iny

@next:
  inx
  bne @loop
@done:
  rts


; ------------------------------------------------------------
; DrawBossBullets_Fixed
; - draws boss bullets into fixed OAM slots (sprites #56-59)
; - ignores dynamic Y cursor issues
; ------------------------------------------------------------
DrawBossBullets_Fixed:
  ldy #$E0        ; sprite #56 (56*4)

  ldx #$00
@loop:
  cpx #BOSS_BULLET_MAX
  bcs @done

  lda bossbul_alive,x
  beq @hide

  lda bossbul_y,x
  sta OAM_BUF,y
  iny

  lda #TILE_PBULLET_0              ; tile
  sta OAM_BUF,y
  iny

  lda #$00              ; TEMP: palette 0
  sta OAM_BUF,y
  iny

  lda bossbul_x,x
  sta OAM_BUF,y
  iny
  jmp @next

@hide:
  lda #$FE
  sta OAM_BUF,y
  iny
  iny
  iny
  iny

@next:
  inx
  bne @loop
@done:
  rts


;DrawTutorialBG:
  ; LINE 1: "AVOID ENEMIES" (13 chars)
 ; lda PPUSTATUS
  ;lda #TUT_NT_HI
  ;sta PPUADDR
  ;lda #TUT_LINE1_LO
 ; sta PPUADDR

  ;lda #TILE_A
  ;sta PPUDATA
  ;lda #TILE_V
  ;sta PPUDATA
  ;lda #TILE_O
  ;sta PPUDATA
  ;lda #TILE_I
  ;sta PPUDATA
  ;lda #TILE_D
  ;sta PPUDATA
  ;lda #$00
  ;sta PPUDATA          ; space
  ;lda #TILE_E
  ;sta PPUDATA
  ;lda #TILE_N
  ;sta PPUDATA
  ;lda #TILE_E
  ;sta PPUDATA
  ;lda #TILE_M
  ;sta PPUDATA
  ;lda #TILE_I
  ;sta PPUDATA
  ;lda #TILE_E
  ;sta PPUDATA
  ;lda #TILE_S
  ;sta PPUDATA

  ; LINE 2: "CATCH CORES" (11 chars)
  ;lda PPUSTATUS
  ;lda #TUT_NT_HI
  ;sta PPUADDR
  ;lda #TUT_LINE2_LO
  ;sta PPUADDR

  ;lda #TILE_C
  ;sta PPUDATA
  ;lda #TILE_A
  ;sta PPUDATA
  ;lda #TILE_T
  ;sta PPUDATA
  ;lda #TILE_C
  ;sta PPUDATA
  ;lda #TILE_H
  ;sta PPUDATA
  ;lda #$00
  ;sta PPUDATA          ; space
  ;lda #TILE_C
  ;sta PPUDATA
  ;lda #TILE_O
  ;sta PPUDATA
  ;lda #TILE_R
  ;sta PPUDATA
  ;lda #TILE_E
  ;sta PPUDATA
  ;lda #TILE_S
  ;sta PPUDATA

  ;rts


  ;ClearTutorialBG:
  ; clear line 1 (13)
  ;lda PPUSTATUS
  ;lda #TUT_NT_HI
  ;sta PPUADDR
  ;lda #TUT_LINE1_LO
  ;sta PPUADDR

  ;ldx #13
  ;lda #$00
;@c1:
 ; sta PPUDATA
 ; dex
 ; bne @c1

  ; clear line 2 (11)
  ;lda PPUSTATUS
  ;lda #TUT_NT_HI
  ;sta PPUADDR
  ;lda #TUT_LINE2_LO
  ;sta PPUADDR

  ;ldx #11
  ;lda #$00
;@c2:
 ; sta PPUDATA
 ; dex
 ; bne @c2

 ; rts


HideBannerSprites: 
ldx #BANNER_OAM 
lda #$FE 
sta OAM_BUF,x 
sta OAM_BUF+4,x 
sta OAM_BUF+8,x 
sta OAM_BUF+12,x 
sta OAM_BUF+16,x 
sta OAM_BUF+20,x 
sta OAM_BUF+24,x 
rts

  ; Hides the 5 score digit sprites (sprites 59..63 at OAM $EC..$FF)
; ------------------------------------------------------------
; HideScoreSprites
; - Hides all score sprites by setting their Y=$FE
; ------------------------------------------------------------
HideScoreSprites:
  lda #$FE
  sta OAM_BUF+$EC     ; sprite 59 Y
  sta OAM_BUF+$F0     ; sprite 60 Y
  sta OAM_BUF+$F4     ; sprite 61 Y
  sta OAM_BUF+$F8     ; sprite 62 Y
  sta OAM_BUF+$FC     ; sprite 63 Y
  rts



; ------------------------------------------------------------
; DrawTutorialIconSprites
; - Draws: enemy row + core row as sprites (not BG)
; - Uses the SAME sprite palettes as gameplay via ATTR bytes.
; - Writes into OAM_BUF starting at TUT_OAM_BASE.
; ------------------------------------------------------------
TUT_OAM_BASE = $20      ; sprite slot *4 (byte offset)

DrawTutorialIconSprites:
  ldy #TUT_OAM_BASE

  ; ----------------------------
  ; ENEMY ROW (Y=$70)
  ; ----------------------------
  lda #$58
  sta tmp7
  clc
  adc #$08
  sta tmp8

  lda #ENEMY_ATTR
  sta tmp4              ; attr

  ; --- Enemy A (1x1) ---
  lda #$50             ; x
  sta tmp5
  lda tmp7              ; y
  sta OAM_BUF,y         ; Y
  iny
  lda #TILE_ENEMY_A_F0
  sta OAM_BUF,y         ; TILE
  iny
  lda tmp4
  sta OAM_BUF,y         ; ATTR
  iny
  lda tmp5
  sta OAM_BUF,y         ; X
  iny

  ; --- Enemy B (1x1) ---
  lda #$60
  sta tmp5
  lda tmp7
  sta OAM_BUF,y
  iny
  lda #TILE_ENEMY_B_F0
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; --- Enemy C (2x2) at X=$50 ---
  lda #$70
  sta tmp5              ; x0
  clc
  adc #$08
  sta tmp6              ; x1

lda #TILE_ENEMY_C_F0
sta tmp0
lda #TILE_ENEMY_C_F0+1
sta tmp1
lda #TILE_ENEMY_C_F0+2
sta tmp2
lda #TILE_ENEMY_C_F0+3
sta tmp3

  jsr TUT_Push2x2

  ; --- Enemy D (2x2) at X=$68 ---
  lda #$88
  sta tmp5
  clc
  adc #$08
  sta tmp6

lda #TILE_ENEMY_D_F0
sta tmp0
lda #TILE_ENEMY_D_F0+1
sta tmp1
lda #TILE_ENEMY_D_F0+2
sta tmp2
lda #TILE_ENEMY_D_F0+3
sta tmp3

  jsr TUT_Push2x2

  ; --- Enemy E (2x2) at X=$80 ---
  lda #$A0
  sta tmp5
  clc
  adc #$08
  sta tmp6

lda #TILE_ENEMY_E_F0
sta tmp0
lda #TILE_ENEMY_E_F0+1
sta tmp1
lda #TILE_ENEMY_E_F0+2
sta tmp2
lda #TILE_ENEMY_E_F0+3
sta tmp3

  jsr TUT_Push2x2

  ; ----------------------------
  ; CORE ROW (Y=$88)
  ; ----------------------------
  lda #$90
  sta tmp7

  lda #$00
  sta tmp4

  lda #$74
  sta tmp5
  lda #TILE_CATCH_CORE_BASE
  jsr TUT_Push1x1

  lda #$7C
  sta tmp5
  lda #TILE_CATCH_CORE_FRACTURED
  jsr TUT_Push1x1

  lda #$84
  sta tmp5
  lda #TILE_CATCH_CORE_FINAL
  jsr TUT_Push1x1




  rts

; tmp0..tmp3 tiles
; tmp4 = attr
; tmp5 = x0
; tmp6 = x1
; tmp7 = y0
; tmp8 = y1
; Y   = OAM byte offset
TUT_Push2x2:
  ; TL
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; TR
  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  ; BL
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp2
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny

  ; BR
  lda tmp8
  sta OAM_BUF,y
  iny
  lda tmp3
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp6
  sta OAM_BUF,y
  iny

  rts


; ----------------------------
; 1x1 sprite helper
; - A = tile
; - tmp4 = attr
; - tmp5 = x
; - tmp7 = y
; - Y = OAM byte offset
; ----------------------------
TUT_Push1x1:
  sta tmp0              ; save tile

  lda tmp7
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda tmp4
  sta OAM_BUF,y
  iny
  lda tmp5
  sta OAM_BUF,y
  iny
  rts




