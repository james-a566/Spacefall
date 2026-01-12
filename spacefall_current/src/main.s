; ============================================================
; template_bg.s — NES boilerplate (ca65) — BG + Sprites
; NROM-128 (16KB PRG), 8KB CHR-ROM
; Boots to solid BG (tile 0 filled) + movable test sprite
; ============================================================

; ----------------------------
; HW REGS / CONSTANTS
; ----------------------------
PPUCTRL         = $2000
PPUMASK         = $2001
PPUSTATUS       = $2002
OAMADDR         = $2003
PPUSCROLL       = $2005
PPUADDR         = $2006
PPUDATA         = $2007
OAMDMA          = $4014
JOY1            = $4016

BTN_A           = %10000000
BTN_B           = %01000000
BTN_SELECT      = %00100000
BTN_START       = %00010000
BTN_UP          = %00001000
BTN_DOWN        = %00000100
BTN_LEFT        = %00000010
BTN_RIGHT       = %00000001

ENEMY_ATTR      = $01      ; sprite palette 1 or $00 for palette 0
ENEMY_SPAWN_Y   = $10
ENEMY_KILL_Y    = $E0
ENEMY_SPD       = $02
ENEMY_SPAWN_CD  = $20      ; spawn every 32 frames (tweak)

; ============================================================
; ENEMY TYPES
; ============================================================
EN_A = $00        ; 1x1 (8x8)
EN_B = $01        ; 1x1 (8x8)
EN_C = $02        ; 2x2 (16x16)
EN_D = $03        ; 2x2 (16x16)
EN_E = $04        ; 2x2 (16x16)  (homing behavior later)

; ============================================================
; ENEMY TILES (match your CHR exactly)
; ============================================================

; --- Enemy A (8x8) ---
ENEMY_A_TILE_SOLID  = $06
ENEMY_A_TILE_ACCENT = $07   ; 2-tone variant

; --- Enemy B (8x8) ---
ENEMY_B_TILE_SOLID  = $08
ENEMY_B_TILE_ACCENT = $09   ; 2-tone variant

; Choose which variant is currently "active"
; (Use SOLID now; swap to ACCENT later for tuning)
ENEMY_A_TILE = ENEMY_A_TILE_SOLID
ENEMY_B_TILE = ENEMY_B_TILE_SOLID


; ============================================================
; 2x2 META ENEMIES (VISIBLE PLACEHOLDERS)
; Use existing A/B tiles + accent variants so you can see them now.
; Each meta uses 4 tiles: TL, TR, BL, BR
; ============================================================

; C = solid block (uses 0A/0B/0C/0D)
ENEMY_C_TL = $0A
ENEMY_C_TR = $0B
ENEMY_C_BL = $0C
ENEMY_C_BR = $0D

; D = stripes + X (uses 0E/0F and reuse 0E/0F)
ENEMY_D_TL = $0E
ENEMY_D_TR = $0F
ENEMY_D_BL = $0E
ENEMY_D_BR = $0F

; E = mixed (reuse 0A/0D/0C/0F)
ENEMY_E_TL = $0A
ENEMY_E_TR = $0D
ENEMY_E_BL = $0C
ENEMY_E_BR = $0F



DEBUG_DRAW_TEST = 0   ; set to 0 to disable


THR_B = $60     ; ~37% B (96/256). Tweak later.
; do i need THR_C/THR_D here?
THR_E = $F0    ; TEMP: top ~6% of rolls become E (16/256)

; Score 
DIGIT_TILE_BASE = $10

SCORE_OAM   = $EC    ; sprite #59 = 59*4 = $EC
SCORE_Y     = $08
SCORE_X0    = $08
SCORE_ATTR  = $00   ; palette 0

; Game Over
GAMEOVER_OAM  = $A0   ; sprite 40 * 4
GAMEOVER_Y    = $70
GAMEOVER_X0   = $48
GAMEOVER_ATTR = $00   ; palette 0 (white letters)


; --- Letter tile IDs  ---
LETTER_TILE_BASE = $1A

TILE_G = $1A
TILE_A = $1B
TILE_M = $1C
TILE_E = $1D
TILE_O = $1E
TILE_V = $1F
TILE_R = $20
TILE_P = $21
TILE_S = $24
TILE_T = $26
TILE_L = $27
TILE_F = $22   

; ----------------------------
; TITLE "STARFALL" as BG tiles
; ----------------------------
TITLE_NT_HI  = $21
TITLE_NT_LO  = $8C    ; row 12, col 12  => $218C

TITLE_LEN    = 8

TitleStarfallTiles:
  .byte TILE_S, TILE_T, TILE_A, TILE_R, TILE_F, TILE_A, TILE_L, TILE_L

; ----------------------------
; PRESS START as BG tiles
; ----------------------------
PRESS_NT_HI  = $22
PRESS_NT_LO  = $4B    ; row 18, col 11  => $224B

PRESS_NT_LEN = 11          ; "PRESS"(5) + space(1) + "START"(5)

PressStartTiles:
  .byte TILE_P, TILE_R, TILE_E, TILE_S, TILE_S
  .byte $00                ; space (blank tile)
  .byte TILE_S, TILE_T, TILE_A, TILE_R, TILE_T


BANNER_OAM   = $80    ; sprite #32 * 4
BANNER_Y     = $58    ; slightly above center
BANNER_X0    = $64    ; centered-ish for 7 chars (56px wide)
BANNER_ATTR  = $00

; ----------------------------
; GAME OVER as BG tiles
; ----------------------------
GAMEOVER_NT_HI = $21
GAMEOVER_NT_LO = $CB        ; row 14, col 11  => $21CB
GAMEOVER_LEN   = 9

GameOverTiles:
  .byte TILE_G, TILE_A, TILE_M, TILE_E
  .byte $00                ; space (blank tile)
  .byte TILE_O, TILE_V, TILE_E, TILE_R


; PPUMASK presets (includes “show left 8px” bits)
PPUMASK_BG_SPR = %00011110

OAM_BUF = $0200

; ----------------------------
; iNES HEADER
; ----------------------------
.segment "HEADER"
  .byte "NES", $1A   ; Bytes 0-3 Constant Bytes/idenitifies file as iNES format NES ROM image
  .byte $01          ; Byte 4: PRG ROM size / 1 × 16KB PRG
  .byte $01          ; Byte 5: CHR ROM Size / 1 × 8KB CHR
  .byte $01          ; Byte 6: Flags
                        ; 0 Nametable ararngement 
                          ; mapper 0, vertical mirroring
                          ; mapper 1 , horizontal mirroring
                        ; 1 Battery
                        ; 2 Trainer
                        ; 3 Alt nametable layout
                        ; 4 - 7 Lower nibble on mapper number
                        ; Bit 
  .byte $00          ; Byte 7: Flags
                        ; Mapper and NES 2.0 Flags
  .res 8, $00        ; Byte 8: Flags
                        ; PRG RAM size
                     ; Byte 9: Flags 
                        ; 0 TV system: 0 NTSC, 1 Palette
                        ; 2-7 Reserved, set to zero
                        ; virtually unused
                     ; Byte 10: Flags
                        ; not part of officialy specification 
                        ; virtually unused
                        ; 0-1 TV system (0: NTSC; 2: PAL; 1/3: dual compatible)
                        ; 2-3 unused
                        ; 4-5 0: Board has no bus conflicts; 1: Board has bus conflicts
                        ; 6-7 unused
                     ; Byte 11-15 Unused / Padding

; ----------------------------
; ZEROPAGE
; ----------------------------
.segment "ZEROPAGE"
nmi_ready:            .res 1
frame_lo:             .res 1
frame_hi:             .res 1
pad1:                 .res 1
pad1_prev:            .res 1
pad1_new:             .res 1

first_run:            .res 1   ; 0 = not started yet, 1 = started
press_visible:        .res 1   ; 0=hidden, 1=shown (BG)
title_visible:        .res 1   ; 0=hidden, 1=shown (BG)
gameover_visible:     .res 1   ; 0=hidden, 1=shown (BG)
gameover_blink_timer: .res 1   ; counts down frames after entering OVER
gameover_blink_phase: .res 1   ; 0=not blinking / finished, 1=in blink sequence
screen_flash_timer:   .res 1   ; 0=off, >0 flash running

draw_test_active:     .res 1   ; 1 = freeze enemies and show test set
draw_test_done:       .res 1   ; 1 = already spawned once this run

tmp:                  .res 1
tmp0:                 .res 1
tmp1:                 .res 1
tmp2:                 .res 1
tmp3:                 .res 1
tmp4:                 .res 1

debug_force_type: .res 1   ; $FF = off, otherwise EN_A..EN_E
debug_mode: .res 1   ; 0=normal, 1=A, 2=B, 3=C, 4=D, 5=E

; ----------------------------
; BSS
; ----------------------------
.segment "BSS"
game_state:       .res 1
player_x:         .res 1
player_y:         .res 1
player_cd:        .res 1    ; fire cooldown
; bullets (N slots)
BULLET_MAX = 4
bul_alive:        .res BULLET_MAX
bul_x:            .res BULLET_MAX
bul_y:            .res BULLET_MAX
bul_y_prev:       .res BULLET_MAX

scroll_y:         .res 1
gun_side:         .res 1     ; 0 = left gun next, 1 = right gun next
rng_lo:           .res 1
rng_hi:           .res 1
score_lo:         .res 1
score_hi:         .res 1
score_work_lo:    .res 1
score_work_hi:    .res 1
lives:            .res 1        ; start with 3 
invuln_timer:     .res 1        ; frames of i-frames after hit
player_attr:      .res 1
good_flash_timer: .res 1     ; short flash for powerups / good collisions

; Score
score_d0:         .res 1   ; ten-thousands
score_d1:         .res 1   ; thousands
score_d2:         .res 1   ; hundreds
score_d3:         .res 1   ; tens
score_d4:         .res 1   ; ones

score_x_cur: .res 1
tmp_xcur: .res 1

spawn_cd:     .res 1

; enemies (N slots)
ENEMY_MAX = 5
ene_alive:   .res ENEMY_MAX
ene_x:       .res ENEMY_MAX
ene_y:       .res ENEMY_MAX
ene_y_prev:  .res ENEMY_MAX
ene_type:    .res ENEMY_MAX   
obj_kind: .res ENEMY_MAX   ; 0=enemy, 1=good-mandatory, 2=powerup1, 3=powerup2

; 0 = solid, 1 = accent
ene_variant: .res ENEMY_MAX

; Enemies
ene_spd:     .res ENEMY_MAX   ; per-enemy vertical speed (or subtype param)
ene_dx:      .res ENEMY_MAX   ; optional horizontal drift (-2..+2 stored as signed)
ene_hp:      .res ENEMY_MAX   ; if you add tougher enemies
ene_timer:   .res ENEMY_MAX   ; per-enemy timer (wiggle, animation, firing)
ene_score:   .res ENEMY_MAX   ; if different enemies give different points (or derive from type)

; Level control vars
level_idx:       .res 1
level_spawn_cd:  .res 1
level_enemy_spd: .res 1
level_thrB:      .res 1
level_thrC:      .res 1
level_thrD:      .res 1
boss_time_lo:    .res 1
boss_time_hi:    .res 1

; Boss
boss_timer_lo:   .res 1
boss_timer_hi:   .res 1
level_banner:    .res 1    ; frames remaining to show "LEVEL X"

; Game States
STATE_BANNER = $00
STATE_PLAY   = $01
STATE_BOSS   = $02
STATE_OVER   = $03
STATE_TITLE  = $04

; ----------------------------
; CODE
; ----------------------------
.segment "CODE"

; ----------------------------
; Palette data (32 bytes)
; ----------------------------
Palettes:
; BG0 Palettea
  .byte $0F,$30,$30,$30       ; p0
  .byte $0F,$06,$16,$26       ; p1
  .byte $0F,$09,$19,$29       ; p2
  .byte $0F,$0C,$1C,$2C       ; p3

; SPR Palettes
; .byte $0F,$01,$16,$30       ; option C
; .byte $0F,$01,$2A,$30       ; option B

  .byte $0F,$01,$21,$30       ; p0 option A (Player Ship)
  .byte $0F,$06,$30,$30       ; p1 enemy palette


  .byte $0F,$26,$30,$30       ; p2
  .byte $0F,$09,$19,$29       ; p3

LEVEL_STRIDE = 7

LevelParams:
; spawn, spd, thrB, thrC, thrD, boss_lo, boss_hi
  .byte $18,  $02, $40, $48, $4C,  $28, $23   ; L1: 2:30 (9000 = $2328)
  .byte $16,  $02, $60, $70, $78,  $30, $2A   ; L2: 3:00 (10800 = $2A30)
  .byte $14,  $03, $70, $90, $98,  $38, $31   ; L3: 3:30 (12600 = $3138)
  .byte $12,  $03, $80, $A0, $B0,  $40, $38   ; L4: 4:00 (14400 = $3840)
  .byte $10,  $04, $90, $B0, $C0,  $48, $3F   ; L5: 4:30 (16200 = $3F48)


RESET:
  sei
  cld
  ldx #$FF
  txs

  ; APU safety
  lda #$40
  sta $4017
  lda #$00
  sta $4010

  ; PPU off
  lda #$00
  sta PPUCTRL
  sta PPUMASK

  ; warm up
  jsr WaitVBlank
  jsr WaitVBlank

  ; clear RAM + OAM shadow
  jsr ClearRAM
  jsr ClearOAM

  ; ----------------------------
  ; Init game state
  ; ----------------------------
lda #0
sta first_run

  lda #$00
sta score_d0
sta score_d1
sta score_d2
sta score_d3
sta score_d4

  lda #$78
  sta player_x
  lda #$B8
  sta player_y

  lda #$00
  sta player_cd
  sta scroll_y
  sta spawn_cd

lda #$00
sta gun_side

lda #$A7
sta rng_lo
lda #$1D
sta rng_hi


lda #$00
sta score_lo
sta score_hi

lda #$00
sta bul_y_prev

lda #$10
sta spawn_cd      ; start with a short delay before first spawn

  lda #$03
  sta lives
  lda #$00
  sta invuln_timer

  lda #$00
sta good_flash_timer

lda #STATE_TITLE
sta game_state

lda #$00
sta press_visible

lda #$00
sta title_visible

lda #$00
sta gameover_visible

lda #$00
sta gameover_blink_timer
sta gameover_blink_phase

lda #$00
sta screen_flash_timer

lda #$00
sta draw_test_active
sta draw_test_done

; debug code
lda #00
sta debug_force_type

lda #$00
sta debug_mode


; clear bullets
  ldx #$00
@clr_bul:
  cpx #BULLET_MAX
  bcs @clr_bul_done
  lda #$00
  sta bul_alive,x
  sta bul_x,x
  sta bul_y,x
  inx
  bne @clr_bul
@clr_bul_done:

  ; clear enemies
  ldx #$00
@clr_ene:
  cpx #ENEMY_MAX
  bcs @clr_ene_done
  lda #$00
  sta ene_alive,x
  sta ene_x,x
  sta ene_y,x
  inx
  bne @clr_ene
@clr_ene_done:


  ; VRAM init (rendering still OFF)
  jsr ClearNametable0
  jsr InitPalettes

  ; jsr DrawTestSprite

  ; align enabling rendering to vblank boundary
  jsr WaitVBlank

  ; scroll = 0,0 (clean latch)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  ; push initial sprites to real OAM once
  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

  ; enable NMI + rendering
  lda #%10000000      ; NMI on
  sta PPUCTRL
  lda #PPUMASK_BG_SPR ; BG + sprites + show left 8px
  sta PPUMASK

MainLoop:
  jsr WaitFrame
  jsr ReadController1

; --- DEBUG input handling ---
jsr DebugUpdate

  lda game_state
  cmp #STATE_TITLE
  beq @state_title
  cmp #STATE_BANNER
  beq @state_banner
  cmp #STATE_PLAY
  beq @state_play
  cmp #STATE_BOSS
  beq @state_boss
  jmp @state_over


; ----------------------------
; STATE: BANNER (LEVEL X)
; “each frame”: count down banner timer
; ----------------------------
@state_banner:
  jsr UpdatePlayer          ; optional: allow movement during banner
  jsr BannerUpdate          ; <-- THIS is the “each frame” part
  jsr BuildOAM              ; BuildOAM should call DrawLevelBannerSprites when banner active
  jmp MainLoop

; ----------------------------
; STATE: PLAY
; “each frame”: decrement boss_timer, transition to BOSS at 0
; ----------------------------
@state_play:


  jsr UpdatePlayer
  jsr UpdateBullets
  jsr UpdateEnemies
  jsr CollideBulletsEnemies
  jsr CollidePlayerEnemies
  jsr PlayUpdate            ; <-- THIS is the “each frame” boss timer part
  jsr BuildOAM
  jmp MainLoop

; ----------------------------
; STATE: BOSS (stub for now)
; ----------------------------
@state_boss:
  ; later: update boss, collide bullets vs boss, etc.
  jsr UpdatePlayer
  jsr UpdateBullets
  ; jsr UpdateBoss
  ; jsr CollideBulletsBoss
  jsr BuildOAM
  jmp MainLoop

; ----------------------------
; STATE: OVER
; ----------------------------
@state_over:
  lda pad1_new
  and #BTN_START
  beq @over_draw
  jsr ReseedRNG
    lda #$00
  sta screen_flash_timer

  jsr ResetRun
  
@over_draw:
  jsr BuildOAM
  jmp MainLoop

@state_title:
  ; wait for START press
  lda pad1_new
  and #BTN_START
  beq :+

    jsr ReseedRNG        ; optional, but nice right before first run
    jsr ResetRun         ; this sets STATE_BANNER (in your code) or STATE_PLAY if you change it
:
  jsr BuildOAM
  jmp MainLoop








; ----------------------------
; NMI
; ----------------------------
NMI:
  pha
  txa
  pha
  tya
  pha

  inc frame_lo
  bne :+
    inc frame_hi
:

  ; ---- OAM DMA (typical) ----
  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA


  lda screen_flash_timer
  beq @flash_off

  dec screen_flash_timer

  ; grayscale only for first 3 frames ($0E,$0D,$0C)
  lda screen_flash_timer
  cmp #$0C
  bcs @flash_gray

@flash_normal:
  lda #PPUMASK_BG_SPR
  sta PPUMASK
  jmp @flash_done

@flash_gray:
  lda #PPUMASK_BG_SPR
  ora #%00000001      ; grayscale
  sta PPUMASK
  jmp @flash_done

@flash_off:
  lda #PPUMASK_BG_SPR
  sta PPUMASK

@flash_done:




; ---- TITLE BG ("STARFALL") show/hide ----
  lda game_state
  cmp #STATE_TITLE
  bne @title_not_title

@title_is_title:
  lda title_visible
  cmp #$01
  beq @title_done
  lda #$01
  sta title_visible
  lda #$01
  jsr WriteTitleStarfallBG
  jmp @title_done

@title_not_title:
  lda title_visible
  beq @title_done
  lda #$00
  sta title_visible
  lda #$00
  jsr WriteTitleStarfallBG

@title_done:


    ; ---- PRESS START BG blink (TITLE only) ----
  lda game_state
  cmp #STATE_TITLE
  bne @not_title

  ; visible? (blink bit)
  lda frame_lo
  and #$10
  beq @want_hidden

@want_shown:
  lda press_visible
  cmp #$01
  beq @ps_done          ; already shown
  lda #$01
  sta press_visible
  lda #$01
  jsr WritePressStartBG
  jmp @ps_done

@want_hidden:
  lda press_visible
  beq @ps_done          ; already hidden
  lda #$00
  sta press_visible
  lda #$00
  jsr WritePressStartBG
  jmp @ps_done

@not_title:
  ; if we left title, ensure it's hidden once
  lda press_visible
  beq @ps_done
  lda #$00
  sta press_visible
  lda #$00
  jsr WritePressStartBG

@ps_done:

  ; ---- GAME OVER BG blink once on entry ----
  lda game_state
  cmp #STATE_OVER
  bne @go_not_over

  ; entering OVER? (start blink sequence once)
  lda gameover_visible
  cmp #$01
  beq @go_in_over_cont

  ; first frame we notice OVER: mark visible + start blink timer
  lda #$01
  sta gameover_visible

  lda #$30              ; total blink duration in frames (~48)
  sta gameover_blink_timer
  lda #$01
  sta gameover_blink_phase

  ; draw it immediately
  lda #$01
  jsr WriteGameOverBG
  jmp @go_done


@go_in_over_cont:
  ; if we're blinking, update show/hide based on timer
  lda gameover_blink_phase
  beq @go_done          ; blink already finished => leave steady

  lda gameover_blink_timer
  beq @go_finish_blink
  dec gameover_blink_timer

  ; timer ranges:
  ; $30..$11 => shown
  ; $10..$01 => hidden
  lda gameover_blink_timer
  cmp #$11
  bcs @go_want_shown

@go_want_hidden:
  lda #$00
  jsr WriteGameOverBG
  jmp @go_done

@go_want_shown:
  lda #$01
  jsr WriteGameOverBG
  jmp @go_done

@go_finish_blink:
  lda #$00
  sta gameover_blink_phase
  lda #$01
  jsr WriteGameOverBG
  jmp @go_done


@go_not_over:
  ; leaving OVER: ensure hidden + reset blink state
  lda gameover_visible
  beq @go_done

  lda #$00
  sta gameover_visible
  sta gameover_blink_phase
  sta gameover_blink_timer

  lda #$00
  jsr WriteGameOverBG

@go_done:



  ; ---- mark frame complete ----
  lda #$01
  sta nmi_ready

  pla
  tay
  pla
  tax
  pla
  rti


IRQ:
  rti

; ----------------------------
; HELPERS
; ----------------------------
WaitFrame:
  lda #$00
  sta nmi_ready
@spin:
  lda nmi_ready
  beq @spin
  rts

WaitVBlank:
  lda PPUSTATUS
@loop:
  lda PPUSTATUS
  bpl @loop
  rts

; Safe RAM clear: skip stack page ($0100) and OAM shadow page ($0200)
ClearRAM:
  lda #$00
  tax
@clr:
  sta $0000,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  inx
  bne @clr
  rts

ClearOAM:
  lda #$FF
  ldx #$00
@o:
  sta OAM_BUF,x
  inx
  inx
  inx
  inx
  bne @o
  rts

ClearNametable0:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$00        ; tile index 0
  ldx #$40        ; 1024 bytes (tiles+attrs)
  ldy #$00
@page:
@byte:
  sta PPUDATA
  iny
  bne @byte
  dex
  bne @page

  lda PPUSTATUS   ; clear latch after big VRAM write
  rts

InitPalettes:
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #$00
@p:
  lda Palettes,x
  sta PPUDATA
  inx
  cpx #$20
  bne @p
  rts

DrawTestSprite:
  lda #$70
  sta OAM_BUF+0
  lda #$00          ; tile 0 (solid)
  sta OAM_BUF+1
  lda #$00          ; palette 0
  sta OAM_BUF+2
  lda #$80
  sta OAM_BUF+3
  rts

ReadController1:
  lda pad1
  sta pad1_prev

  lda #$01
  sta JOY1
  lda #$00
  sta JOY1

  ldx #$08
  lda #$00
  sta pad1
@r:
  lda JOY1
  and #$01
  lsr a
  rol pad1
  dex
  bne @r

  lda pad1
  eor pad1_prev
  and pad1
  sta pad1_new
  rts

; debug_mode: 0=normal, 1=A, 2=B, 3=C, 4=D, 5=E

DebugUpdate:
  lda pad1_new
  and #BTN_SELECT
  beq @done

  inc debug_mode
  lda debug_mode
  cmp #$06
  bcc @done
  lda #$00
  sta debug_mode

@done:
  rts



UpdatePlayer:

  ; ----------------------------
  ; Horizontal movement
  ; ----------------------------

  ; left
  lda pad1
  and #BTN_LEFT
  beq @check_right
  lda player_x
  sec
  sbc #$02
  cmp #$08
  bcs :+
    lda #$08
:
  sta player_x

@check_right:
  lda pad1
  and #BTN_RIGHT
  beq @vert
  lda player_x
  clc
  adc #$02
  cmp #$F0
  bcc :+
    lda #$F0
:
  sta player_x

  ; ----------------------------
  ; Vertical movement
  ; ----------------------------
@vert:
  ; up
  lda pad1
  and #BTN_UP
  beq @check_down
  lda player_y
  sec
  sbc #$02
  cmp #$10
  bcs :+
    lda #$10
:
  sta player_y

@check_down:
  lda pad1
  and #BTN_DOWN
  beq @fire_cooldown
  lda player_y
  clc
  adc #$02
  cmp #$D0
  bcc :+
    lda #$D0
:
  sta player_y

  ; ----------------------------
  ; Fire (hold A) with cooldown
  ; ----------------------------
@fire_cooldown:
  lda player_cd
  beq @try_fire
  dec player_cd
  jmp @done

@try_fire:
  lda pad1
  and #BTN_A
  beq @done

  jsr FireBulletLR
  lda #$06          ; fire rate (lower = faster). Try 6 first.
  sta player_cd

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
  sbc #$04
  sta bul_y,x
  lda bul_y,x
  sta bul_y_prev,x

  ; choose left/right gun X
  lda gun_side
  beq @left

@right:
  ; right gun: player_x + 12 (for a 16px ship, near right side)
  lda player_x
  clc
  adc #$0C
  sta bul_x,x
  lda #$00
  sta gun_side
  rts

@left:
  ; left gun: player_x + 0 (far left edge)
  lda player_x
  sta bul_x,x
  lda #$01
  sta gun_side
  rts


@no_slot:
  rts


UpdateBullets:
  ldx #$00
@loop:
  cpx #BULLET_MAX
  bcs @done

  lda bul_alive,x
  beq @next

  ; store previous Y for swept collision
  lda bul_y,x
  sta bul_y_prev,x

  ; move up
  sec
  sbc #$05          ; bullet speed
  sta bul_y,x

  bcc @kill         ; underflow (wrapped) => bullet left the top

  ; optional extra safety: also kill if very near top
  cmp #$08
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
; BuildOAM
; - OAM layout:
;   sprites 0-3  = player (2x2)
;   sprites 4-7  = bullets
;   sprites 8..  = enemies
; ----------------------------
BuildOAM:
  lda game_state
  cmp #STATE_TITLE
  bne @check_over

  ; hide all sprites
  ldx #$00
@t_hide_all:
  lda #$FE
  sta OAM_BUF,x
  inx
  inx
  inx
  inx
  bne @t_hide_all

  rts

@check_over:
  lda game_state
  cmp #STATE_OVER
  bne @normal_draw

  ; ----------------------------
  ; STATE_OVER: clear screen, draw overlays only
  ; ----------------------------
  lda game_state
  cmp #STATE_OVER
  bne @normal_draw

  ; clear entire OAM buffer (all 64 sprites)
  ldx #$00
@hide_all:
  lda #$FE
  sta OAM_BUF,x
  inx
  inx
  inx
  inx
  bne @hide_all

  jsr DrawScoreSprites
  rts


@normal_draw:

  ; ----------------------------
  ; Player metasprite (sprites 0-3)
  ; tiles: 01,02,03,04
  ; ----------------------------

  ; sprite 0 (TL)
  lda player_y
  sta OAM_BUF+0
  lda #$01
  sta OAM_BUF+1
  lda player_attr
  sta OAM_BUF+2
  lda player_x
  sta OAM_BUF+3

  ; sprite 1 (TR)
  lda player_y
  sta OAM_BUF+4
  lda #$02
  sta OAM_BUF+5
  lda player_attr
  sta OAM_BUF+6
  lda player_x
  clc
  adc #$08
  sta OAM_BUF+7

  ; sprite 2 (BL)
  lda player_y
  clc
  adc #$08
  sta OAM_BUF+8
  lda #$03
  sta OAM_BUF+9
  lda player_attr
  sta OAM_BUF+10
  lda player_x
  sta OAM_BUF+11

  ; sprite 3 (BR)
  lda player_y
  clc
  adc #$08
  sta OAM_BUF+12
  lda #$04
  sta OAM_BUF+13
  lda player_attr
  sta OAM_BUF+14
  lda player_x
  clc
  adc #$08
  sta OAM_BUF+15

  ; ----------------------------
  ; Bullets (sprites 4-7)
  ; ----------------------------
  ldy #$10          ; OAM offset for sprite #4 (16 bytes in)

  ldx #$00
@bul_draw:
  cpx #BULLET_MAX
  bcs @bul_done

  lda bul_alive,x
  beq @bul_hide

  ; Y
  lda bul_y,x
  sta OAM_BUF,y
  iny
  ; tile
  lda #$05          ; <-- BULLET TILE ID (change to your bullet tile)
  sta OAM_BUF,y
  iny
  ; attr
  lda #$00          ; palette 0 (or change to #$01 if you want palette 1)
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

  ; ----------------------------
  ; Enemies (sprites 8..)
  ; - A/B are 1x1
  ; - C/D/E are 2x2 metasprites
  ; ----------------------------
  ldy #$20          ; OAM offset for sprite #8

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


  ; decide size by type: C/D/E are 2x2 (type >= EN_C)
  lda ene_type,x
  cmp #EN_C
  bcs @ene_is_2x2     ; >= EN_C => 2x2
  jmp @ene_draw_1x1   ; <  EN_C => 1x1 (long jump)

@ene_is_2x2:


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
  lda #ENEMY_E_TL
  sta tmp0
  lda #ENEMY_E_TR
  sta tmp1
  lda #ENEMY_E_BL
  sta tmp2
  lda #ENEMY_E_BR
  sta tmp3
  jmp @ene_draw_2x2

@ene_tiles_C:
  lda #ENEMY_C_TL
  sta tmp0
  lda #ENEMY_C_TR
  sta tmp1
  lda #ENEMY_C_BL
  sta tmp2
  lda #ENEMY_C_BR
  sta tmp3
  jmp @ene_draw_2x2

@ene_tiles_D:
  lda #ENEMY_D_TL
  sta tmp0
  lda #ENEMY_D_TR
  sta tmp1
  lda #ENEMY_D_BL
  sta tmp2
  lda #ENEMY_D_BR
  sta tmp3
  ; fallthrough

@ene_draw_2x2:
  ; TL
  lda ene_y,x
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda #ENEMY_ATTR
  sta OAM_BUF,y
  iny
  lda ene_x,x
  sta OAM_BUF,y
  iny

  ; TR (x + 8)
  lda ene_y,x
  sta OAM_BUF,y
  iny
  lda tmp1
  sta OAM_BUF,y
  iny
  lda #ENEMY_ATTR
  sta OAM_BUF,y
  iny
  lda ene_x,x
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  ; BL (y + 8)
  lda ene_y,x
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda tmp2
  sta OAM_BUF,y
  iny
  lda #ENEMY_ATTR
  sta OAM_BUF,y
  iny
  lda ene_x,x
  sta OAM_BUF,y
  iny

  ; BR (x + 8, y + 8)
  lda ene_y,x
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda tmp3
  sta OAM_BUF,y
  iny
  lda #ENEMY_ATTR
  sta OAM_BUF,y
  iny
  lda ene_x,x
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  jmp @ene_next


@ene_draw_1x1:
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
  lda #ENEMY_B_TILE
  bne @tile_done_1
@tile_A_1:
  lda #ENEMY_A_TILE
@tile_done_1:
  sta OAM_BUF,y
  iny

  ; attr
  lda #ENEMY_ATTR
  sta OAM_BUF,y
  iny

  ; X
  lda ene_x,x
  sta OAM_BUF,y
  iny

  jmp @ene_next


@ene_skip:
  ; do nothing; leaving unused slots for later hide pass

@ene_next:
  inx
  jmp @ene_draw

@ene_done:



  ; ---- hide sprites ----
  tya
  tax
@hide_rest:
  lda #$FE
  sta OAM_BUF,x
  inx
  inx
  inx
  inx
  bne @hide_rest


  lda game_state
  cmp #STATE_TITLE


  ; always show score
  jsr DrawScoreSprites

  ; banner overlay?
  lda game_state
  cmp #STATE_BANNER
  bne @done
  jsr DrawLevelBannerSprites

@done:
  rts



SpawnEnemy:
.if DEBUG_DRAW_TEST
  lda draw_test_active
  bne @no_slot
.endif



  ; find free slot
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

  lda #ENEMY_SPAWN_Y
  sta ene_y,x
  sta ene_y_prev,x

lda rng_lo
ora rng_hi
bne :+
  lda #$A7
  sta rng_lo
  lda #$1D
  sta rng_hi
:


  ; ---- X position (multiples of 8, unbiased, with failsafe) ----
  lda #$10        ; try up to 16 times
  sta tmp0

@rand_x:
  jsr NextRand
  and #$F8          ; 00,08,10,...,F8
  cmp #$08
  bcc @retry
  cmp #$F0
  bcs @retry
  sta ene_x,x
  jmp @x_ok

@retry:
  dec tmp0
  bne @rand_x

  ; fallback if RNG is busted / stuck: pick middle
  lda #$80
  sta ene_x,x

@x_ok:

  ; ----------------------------
  ; DEBUG FORCE (0=normal, 1..5 force A..E)
  ; ----------------------------
  lda debug_mode
  beq @choose_type

  ; A = 1..5 -> convert to EN_A..EN_E (0..4)
  sec
  sbc #$01          ; now A = 0..4
  sta tmp1          ; save forced enemy type id

  lda tmp1
  sta ene_type,x

  ; init per-type params exactly like normal spawns
  lda tmp1
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
  rts

@init_B:
  jsr NextRand
  and #$01
  beq :+
    lda #$01
    bne :++
: lda #$FF
: sta ene_dx,x
  rts

@init_C:
  jsr NextRand
  and #$01
  beq :+
    lda #$01
    bne :++
: lda #$FF
: sta ene_dx,x
  lda #$00
  sta ene_timer,x
  rts

@init_D:
  lda #$08
  sta ene_timer,x
  rts

@init_E:
  lda #$00
  sta ene_timer,x
  rts


@choose_type:
  ; ----------------------------
  ; NORMAL threshold ladder here
  ; ----------------------------
  jsr NextRand
  sta tmp1
  ; compare tmp1 to your thresholds...


  lda tmp1
  cmp level_thrB
  bcc @spawn_B

  lda tmp1
  cmp level_thrC
  bcc @spawn_C

  lda tmp1
  cmp level_thrD
  bcc @spawn_D

  ; ---- E RULE ----
  lda tmp1
  cmp #THR_E
  bcs @spawn_E

  jmp @spawn_A


@spawn_A:
  lda #EN_A
  sta ene_type,x
  lda #$00
  sta ene_dx,x
  rts

@spawn_B:
  lda #EN_B
  sta ene_type,x
  ; init dx = -1 or +1
  jsr NextRand
  and #$01
  beq :+
    lda #$01
    bne :++
: lda #$FF
:
  sta ene_dx,x
  rts

@spawn_C:
  lda #EN_C
  sta ene_type,x
  ; init wiggle dx + timer
  jsr NextRand
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

@spawn_D:
  lda #EN_D
  sta ene_type,x
  lda #$08
  sta ene_timer,x
  rts

@spawn_E:
  lda #EN_E
  sta ene_type,x
  lda #$00
  sta ene_timer,x
  rts



; ----------------------------
; SIZE-AWARE SPAWN CLAMP
; ----------------------------
@spawn_clamp:
  lda ene_type,x
  cmp #EN_C
  bcc @clamp_8x8

@clamp_16x16:
  lda ene_x,x
  cmp #$08
  bcs :+
    lda #$08
    sta ene_x,x
:
  lda ene_x,x
  cmp #$E0
  bcc :+
    lda #$E0
    sta ene_x,x
:
  rts

@clamp_8x8:
  lda ene_x,x
  cmp #$08
  bcs :+
    lda #$08
    sta ene_x,x
:
  lda ene_x,x
  cmp #$E8
  bcc :+
    lda #$E8
    sta ene_x,x
:
  rts

@no_slot:
  ; no free enemy slots - skip spawn
  rts

; ----------------------------
; UpdateEnemies
; ----------------------------
UpdateEnemies:
.if DEBUG_DRAW_TEST
  lda draw_test_active
  beq :+
    rts               ; skip all enemy updates; draw still happens in BuildOAM
:
.endif



  ; ---- spawn cooldown ----
  lda spawn_cd
  beq @do_spawn
  dec spawn_cd
  jmp @move

@do_spawn:
  jsr SpawnEnemy
  lda level_spawn_cd
  sta spawn_cd


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
  cmp #EN_B
  bne :+
    jmp @beh_B
  :
  cmp #EN_C
  bne :+
    jmp @beh_C
  :
  cmp #EN_D
  bne :+
    jmp @beh_D
  :
  cmp #EN_E
  bne :+
    jmp @beh_E
  :
  jmp @after_behaviors      ; EN_A/default: nothing else

@beh_B:
  ; B drift
  lda ene_x,x
  clc
  adc ene_dx,x
  sta ene_x,x

  ; clamp + bounce (uses tmp0 computed above)
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
  bcc @after_behaviors
  lda tmp0
  sta ene_x,x
  lda #$FF
  sta ene_dx,x
  jmp @after_behaviors



@beh_D:
  lda ene_timer,x
  beq @d_maybe_rearm

  ; paused: undo the base fall this frame
  dec ene_timer,x
  lda ene_y,x
  sec
  sbc level_enemy_spd
  sta ene_y,x
  jmp @after_behaviors

@d_maybe_rearm:
  ; random chance per frame to start a pause
  jsr NextRand
  cmp #$20            ; ~12.5% chance
  bcs @after_behaviors
  lda #$08            ; pause length
  sta ene_timer,x
  jmp @after_behaviors


@beh_E:
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



; ----------------------------
; CollideBulletsEnemies
; - if bullet point is inside enemy 8x8 box -> kill both
; - optionally add score
; ----------------------------
CollideBulletsEnemies:
  ldx #$00                  ; bullet index
@bul_loop:
  cpx #BULLET_MAX
  bcs @done

  lda bul_alive,x
  beq @bul_next

  ldy #$00                  ; enemy index
@ene_loop:
  cpy #ENEMY_MAX
  bcs @bul_next             ; done checking this bullet

  lda ene_alive,y
  beq @ene_next

; ---- X overlap (8x8 bullet vs 8x8 enemy) ----
; if bul_x > ene_x+7 => no
lda ene_x,y
clc
adc #$05
cmp bul_x,x
bcc @ene_next

; if ene_x > bul_x+7 => no
lda bul_x,x
clc
adc #$07
cmp ene_x,y
bcc @ene_next


  ; ---- Y check (swept with bullet height) ----
  ; bullet_top_now = bul_y
  ; bullet_bottom_prev = bul_y_prev + 7
  ; enemy_bottom_now = ene_y + 7
  ; enemy_top_prev = ene_y_prev

  ; enemy_bottom_now -> tmp
  lda ene_y,y
  clc
  adc #$07
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
  adc #$07
  cmp ene_y_prev,y
  bcc @ene_next

  ; ---- HIT! ----
@hit:
  lda #$00
  sta bul_alive,x
  sta ene_alive,y

  jsr AddScore1
  jmp @bul_next


@ene_next:
  iny
  bne @ene_loop

@bul_next:
  inx
  bne @bul_loop

@done:
  rts

; ----------------------------
; CollidePlayerEnemies
; 16x16 player vs 8x8 enemy
; - ignores hits if invuln_timer > 0
; - on hit: kill enemy, decrement lives, set GAME_OVER if lives hits 0
; - otherwise start invuln
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

  ; ---- X overlap? ----
  ; if (player_x + 15) < ene_x => no hit
  lda player_x
  clc
  adc #$0F
  cmp ene_x,y
  bcc CPE_NextEnemy

  ; if (ene_x + 7) < player_x => no hit
  lda ene_x,y
  clc
  adc #$07
  cmp player_x
  bcc CPE_NextEnemy

  ; ---- Y overlap? ----
  ; if (player_y + 15) < ene_y => no hit
  lda player_y
  clc
  adc #$0F
  cmp ene_y,y
  bcc CPE_NextEnemy

  ; if (ene_y + 7) < player_y => no hit
  lda ene_y,y
  clc
  adc #$07
  cmp player_y
  bcc CPE_NextEnemy

  ; ---- HIT ----
  lda #$00
  sta ene_alive,y

  ; lose life
  lda lives
  beq CPE_SetOver
  sec
  sbc #$01
  sta lives
  beq CPE_SetOver

  ; start i-frames
  lda #$30
  sta invuln_timer
  rts

CPE_SetOver:
  jsr ClearActors
  lda #STATE_OVER
  sta game_state

  lda #$12              ; flash duration (18 frames) tweak to taste
  sta screen_flash_timer

  rts


CPE_NextEnemy:
  iny
  bne CPE_EnemyLoop

CPE_Done:
  rts



; ----------------------------
; ResetRun
; - prepares a new run (called at boot and on restart)
; ----------------------------
ResetRun:

lda #$18
sta level_spawn_cd
sta spawn_cd

lda #$00          ; start in normal mode
sta debug_force_type




.if DEBUG_DRAW_TEST
  lda #$00
  sta draw_test_active
  sta draw_test_done
.endif

  lda #$00
  sta level_idx
  jsr LoadLevelParams

  lda #60
  sta level_banner
  lda #STATE_BANNER
  sta game_state

  ; use level params for spawns/timing
  lda level_spawn_cd
  sta spawn_cd
  lda boss_time_lo
  sta boss_timer_lo
  lda boss_time_hi
  sta boss_timer_hi

  ; player
  lda #$78
  sta player_x
  lda #$B8
  sta player_y
  lda #$00
  sta player_cd
  sta gun_side
  sta invuln_timer
  sta good_flash_timer

  ; score digits (you’re using score_d0..d4)
  lda #$00
  sta score_d0
  sta score_d1
  sta score_d2
  sta score_d3
  sta score_d4

  lda #$03
  sta lives

  ; clear bullets
  ldx #$00
@clr_bul:
  cpx #BULLET_MAX
  bcs @clr_bul_done
  lda #$00
  sta bul_alive,x
  sta bul_x,x
  sta bul_y,x
  sta bul_y_prev,x
  inx
  bne @clr_bul
@clr_bul_done:

  ; clear enemies
  ldx #$00
@clr_ene:
  cpx #ENEMY_MAX
  bcs @clr_ene_done
  lda #$00
  sta ene_alive,x
  sta ene_x,x
  sta ene_y,x
  sta ene_y_prev,x
  sta ene_type,x
  inx
  bne @clr_ene
@clr_ene_done:

  rts


; ----------------------------
; ClearActors
; - kills all bullets and enemies (visuals will be empty after BuildOAM)
; ----------------------------
ClearActors:
  ; bullets
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

; ----------------------------
; ScoreToDec5
; Converts score_hi:score_lo (0..65535) into 5 decimal digits
; Outputs: score_d0..score_d4
; Uses: tmp0..tmp4 (need 5 temp bytes)
; ----------------------------

ScoreToDec5:

  lda score_lo
  sta score_work_lo
  lda score_hi
  sta score_work_hi

  ; clear BCD digits (tmp0..tmp4 store 0-9 each)
  lda #$00
  sta tmp0
  sta tmp1
  sta tmp2
  sta tmp3
  sta tmp4

  ldx #$10              ; 16 bits to process

BitLoop:
  ; add-3 step for each digit if >=5
  lda tmp0
  cmp #$05
  bcc :+
  adc #$03
  sta tmp0
:
  lda tmp1
  cmp #$05
  bcc :+
  adc #$03
  sta tmp1
:
  lda tmp2
  cmp #$05
  bcc :+
  adc #$03
  sta tmp2
:
  lda tmp3
  cmp #$05
  bcc :+
  adc #$03
  sta tmp3
:
  lda tmp4
  cmp #$05
  bcc :+
  adc #$03
  sta tmp4
:

  ; shift left: [score_hi:score_lo] -> carry into ones digit chain
  asl score_work_lo
  rol score_work_hi

  ; now shift digits left (tmp0..tmp4), pulling in carry each time
  ; carry from score_hi becomes bit0 of tmp4 chain
  ; We implement digit shift by: (digit = digit*2 + carry) % 10 with carry-out.
  ; Since digits are 0-9, we can do it with ROL across packed bits by storing digits in binary and using BCD logic.
  ; Easier: shift as binary across 5 digits using bit carry via ROL-like method on 4-bit values:
  ;
  ; We'll do manual: start from least significant digit (tmp4 = ones)
  ;
  lda tmp4
  asl
  bcc :+
  ; (asl sets carry based on bit7, but our digits are small; carry from asl isn't what we want)
:
  ; Instead: use carry from rol score_hi directly:
  ; carry is already set from rol score_hi, so we do "digit = digit*2 + C", then fix if >=10.
  ; We'll do that pattern for tmp4..tmp0.

  ; ones
  lda tmp4
  asl
  adc #$00              ; add carry-in
  sta tmp4
  cmp #$0A
  bcc @no_c4
  sbc #$0A
  sta tmp4
  sec                    ; carry-out = 1
  bcs @c4_done
@no_c4:
  clc                    ; carry-out = 0
@c4_done:

  ; tens
  lda tmp3
  asl
  adc #$00
  sta tmp3
  cmp #$0A
  bcc @no_c3
  sbc #$0A
  sta tmp3
  sec
  bcs @c3_done
@no_c3:
  clc
@c3_done:

  ; hundreds
  lda tmp2
  asl
  adc #$00
  sta tmp2
  cmp #$0A
  bcc @no_c2
  sbc #$0A
  sta tmp2
  sec
  bcs @c2_done
@no_c2:
  clc
@c2_done:

  ; thousands
  lda tmp1
  asl
  adc #$00
  sta tmp1
  cmp #$0A
  bcc @no_c1
  sbc #$0A
  sta tmp1
  sec
  bcs @c1_done
@no_c1:
  clc
@c1_done:

  ; ten-thousands
  lda tmp0
  asl
  adc #$00
  sta tmp0
  cmp #$0A
  bcc @no_c0
  sbc #$0A
  sta tmp0
  ; carry-out ignored
@no_c0:

  dex

  bne :+
   jmp BitLoop
  :

  ; copy to outputs
  lda tmp0
  sta score_d0
  lda tmp1
  sta score_d1
  lda tmp2
  sta score_d2
  lda tmp3
  sta score_d3
  lda tmp4
  sta score_d4
  rts

; ----------------------------
; DrawScoreSprites
; Draws 5 digits using sprites 59..63 (OAM $EC..$FF)
; Leading zeros blanked (tile 00) except the last digit.
; Requires: blank tile is tile $00
; ----------------------------
DrawScoreSprites:
  ldx #SCORE_OAM
  lda #SCORE_X0
  sta tmp_xcur

  ; d0
  lda score_d0
  bne @d0_show
  lda #$00
  bne @d0_draw
@d0_show:
  clc
  adc #DIGIT_TILE_BASE
@d0_draw:
  jsr _DrawOneDigit

  ; d1
  lda score_d0
  bne @d1_force
  lda score_d1
  bne @d1_show
  lda #$00
  bne @d1_draw
@d1_force:
@d1_show:
  lda score_d1
  clc
  adc #DIGIT_TILE_BASE
@d1_draw:
  jsr _DrawOneDigit

  ; d2
  lda score_d0
  ora score_d1
  bne @d2_force
  lda score_d2
  bne @d2_show
  lda #$00
  bne @d2_draw
@d2_force:
@d2_show:
  lda score_d2
  clc
  adc #DIGIT_TILE_BASE
@d2_draw:
  jsr _DrawOneDigit

  ; d3
  lda score_d0
  ora score_d1
  ora score_d2
  bne @d3_force
  lda score_d3
  bne @d3_show
  lda #$00
  bne @d3_draw
@d3_force:
@d3_show:
  lda score_d3
  clc
  adc #DIGIT_TILE_BASE
@d3_draw:
  jsr _DrawOneDigit

  ; d4 (always show)
  lda score_d4
  clc
  adc #DIGIT_TILE_BASE
  jsr _DrawOneDigit

  rts

; A = tile id (or $00 for blank), X = OAM offset
_DrawOneDigit:
  pha                 ; save tile

  ; Y
  lda #SCORE_Y
  sta OAM_BUF,x
  inx

  ; tile
  pla
  sta OAM_BUF,x
  inx

  ; attr
  lda #SCORE_ATTR
  sta OAM_BUF,x
  inx

  ; X
  lda tmp_xcur
  sta OAM_BUF,x
  inx

  ; advance screen X cursor
  lda tmp_xcur
  clc
  adc #$08
  sta tmp_xcur

  rts


; ----------------------------
; AddScore1
; score_d4..score_d0 += 1 (base-10 with carry)
; ----------------------------
AddScore1:
  inc score_d4
  lda score_d4
  cmp #10
  bcc @done
  lda #0
  sta score_d4

  inc score_d3
  lda score_d3
  cmp #10
  bcc @done
  lda #0
  sta score_d3

  inc score_d2
  lda score_d2
  cmp #10
  bcc @done
  lda #0
  sta score_d2

  inc score_d1
  lda score_d1
  cmp #10
  bcc @done
  lda #0
  sta score_d1

  inc score_d0
  lda score_d0
  cmp #10
  bcc @done
  lda #9          ; clamp at 99999 if you want
  sta score_d0

@done:
  rts

LoadLevelParams:
  lda level_idx
  asl
  clc
  adc level_idx      ; *3
  asl                ; *6
  clc
  adc level_idx      ; *7  (now A = level_idx*7)
  tay

  lda LevelParams,y
  sta level_spawn_cd
  iny
  lda LevelParams,y
sta level_enemy_spd
  iny
  lda LevelParams,y
  sta level_thrB
  iny
  lda LevelParams,y
  sta level_thrC
  iny
  lda LevelParams,y
  sta level_thrD
  iny
  lda LevelParams,y
  sta boss_time_lo
  iny
  lda LevelParams,y
  sta boss_time_hi

  ; reset boss timer = boss_time
  lda boss_time_lo
  sta boss_timer_lo
  lda boss_time_hi
  sta boss_timer_hi

  rts

BannerUpdate:
  lda level_banner
  beq @done_banner
  dec level_banner
  rts
@done_banner:
  lda #STATE_PLAY
  sta game_state
  rts


PlayUpdate:
  ; decrement boss timer and switch to boss
  lda boss_timer_lo
  bne @dec_lo
  lda boss_timer_hi
  beq @start_boss
  dec boss_timer_hi
  lda #$FF
  sta boss_timer_lo
  rts

@dec_lo:
  dec boss_timer_lo
  rts

@start_boss:
  lda #STATE_BOSS
  sta game_state
  jsr ClearActors
  rts

NextLevel:
  inc level_idx
  jsr LoadLevelParams
  lda #60
  sta level_banner
  lda #STATE_BANNER
  sta game_state
  rts

  ; ----------------------------
; DrawLevelBannerSprites
; Draws "LEVEL X" using sprites starting at BANNER_OAM
; Uses: tmp_xcur, tmp0
; Assumes: digits tiles start at DIGIT_TILE_BASE
; ----------------------------
DrawLevelBannerSprites:
  ldx #BANNER_OAM

  lda #BANNER_X0
  sta tmp_xcur

  ; L
  lda #TILE_L
  jsr _DrawBannerChar

  ; E  (you already have TILE_E = $1D)
  lda #TILE_E
  jsr _DrawBannerChar

  ; V  (you already have TILE_V = $1F)
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

  ; X digit = (level_idx + 1), clamped 1..9 for now
  lda level_idx
  clc
  adc #$01
  cmp #$0A
  bcc :+
    lda #$09
:
  clc
  adc #DIGIT_TILE_BASE
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


; A = 0 => hide (write blanks)
; A = 1 => show (write STARFALL)
WriteTitleStarfallBG:
  pha

  ; set VRAM address to TITLE position ($214C)
  lda PPUSTATUS
  lda #TITLE_NT_HI
  sta PPUADDR
  lda #TITLE_NT_LO
  sta PPUADDR

  pla
  beq @write_blanks

@write_text:
  ldx #$00
@tloop:
  lda TitleStarfallTiles,x
  sta PPUDATA
  inx
  cpx #TITLE_LEN
  bne @tloop
  jmp @done

@write_blanks:
  ldx #$00
@bloop:
  lda #$00          ; blank tile
  sta PPUDATA
  inx
  cpx #TITLE_LEN
  bne @bloop

@done:
  ; reset scroll latch
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL
  rts

; A = 0 => hide (write blanks)
; A = 1 => show (write GameOverTiles)
WriteGameOverBG:
  pha

  lda PPUSTATUS
  lda #GAMEOVER_NT_HI
  sta PPUADDR
  lda #GAMEOVER_NT_LO
  sta PPUADDR

  pla
  beq @write_blanks

@write_text:
  ldx #$00
@tloop:
  lda GameOverTiles,x
  sta PPUDATA
  inx
  cpx #GAMEOVER_LEN
  bne @tloop
  jmp @done

@write_blanks:
  ldx #$00
@bloop:
  lda #$00
  sta PPUDATA
  inx
  cpx #GAMEOVER_LEN
  bne @bloop

@done:
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL
  rts



; A = 0 => hide (write blanks)
; A = 1 => show (write PressStartTiles)
WritePressStartBG:
  pha

  ; set VRAM address to $2248
  lda PPUSTATUS
  lda #PRESS_NT_HI
  sta PPUADDR
  lda #PRESS_NT_LO
  sta PPUADDR

  pla
  beq @write_blanks

@write_text:
  ldx #$00
@tloop:
  lda PressStartTiles,x
  sta PPUDATA
  inx
  cpx #PRESS_NT_LEN
  bne @tloop
  jmp @done

@write_blanks:
  ldx #$00
@bloop:
  lda #$00          ; blank tile
  sta PPUDATA
  inx
  cpx #PRESS_NT_LEN
  bne @bloop

@done:
  ; good hygiene: reset scroll latch (prevents weirdness later)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL
  rts


ReseedRNG:
  lda rng_lo
  eor frame_lo
  eor pad1
  ora #$01
  sta rng_lo

  lda rng_hi
  eor frame_hi
  eor pad1_prev
  sta rng_hi

  ; ensure nonzero state
  lda rng_lo
  ora rng_hi
  bne :+
    lda #$A7
    sta rng_lo
    lda #$1D
    sta rng_hi
:
  rts



; ------------------------------------------------------------
; NextRand
; - 16-bit Galois LFSR, avoids 0 state externally
; - returns A = rng_lo
; Polynomial/tap: 0xB400 (common)
; ------------------------------------------------------------
NextRand:
  ; correct 16-bit shift right: (rng_hi:rng_lo) >>= 1
  lda rng_hi
  lsr
  sta rng_hi
  lda rng_lo
  ror
  sta rng_lo

  ; if old bit0 was 1 (now in carry), apply tap
  bcc :+
    lda rng_hi
    eor #$B4
    sta rng_hi
:

  lda rng_lo
  rts





; ------------------------------------------------------------
; DebugSpawn_DrawTestOnce
; Spawns A–E enemies at fixed X/Y once per run.
; Also enables draw_test_active so they don't move.
; ------------------------------------------------------------
DebugSpawn_DrawTestOnce:
  lda draw_test_done
  bne @skip

  lda game_state
  cmp #STATE_PLAY
  beq @ok

@skip:
  jmp @out

@ok:


  lda #$01
  sta draw_test_done
  sta draw_test_active

  ; Clear all enemies first (optional but recommended)
  ldx #$00
@clr:
  lda #$00
  sta ene_alive,x
  inx
  cpx #ENEMY_MAX
  bne @clr

  ; ---- spawn A in slot 0 ----
  ldx #$00
  lda #$01
  sta ene_alive,x
  lda #EN_A
  sta ene_type,x
  lda #$20
  sta ene_x,x
  lda #$40
  sta ene_y,x

  ; ---- spawn B in slot 1 ----
  ldx #$01
  cpx #ENEMY_MAX
  bcs @out
  lda #$01
  sta ene_alive,x
  lda #EN_B
  sta ene_type,x
  lda #$50
  sta ene_x,x
  lda #$40
  sta ene_y,x

  ; ---- spawn C (2x2) in slot 2 ----
  ldx #$02
  cpx #ENEMY_MAX
  bcs @out
  lda #$01
  sta ene_alive,x
  lda #EN_C
  sta ene_type,x
  lda #$80
  sta ene_x,x
  lda #$38          ; slightly higher so you can see spacing
  sta ene_y,x

  ; ---- spawn D (2x2) in slot 3 ----
  ldx #$03
  cpx #ENEMY_MAX
  bcs @out
  lda #$01
  sta ene_alive,x
  lda #EN_D
  sta ene_type,x
  lda #$B0
  sta ene_x,x
  lda #$38
  sta ene_y,x

  ; ---- spawn E (2x2) in slot 4 ----
  ldx #$04
  cpx #ENEMY_MAX
  bcs @out
  lda #$01
  sta ene_alive,x
  lda #EN_E
  sta ene_type,x
  lda #$D0
  sta ene_x,x
  lda #$38
  sta ene_y,x

@out:
  rts


; ----------------------------
; VECTORS
; ----------------------------
.segment "VECTORS"
  .word NMI
  .word RESET
  .word IRQ

; ----------------------------
; CHR (8KB)
; ----------------------------
.segment "CHARS"
; Tile 00 (blank)
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $01 Player_TL
.byte $00,$00,$01,$03,$03,$03,$0A,$0D
.byte $00,$00,$00,$00,$00,$08,$01,$2A

; Tile $02 Player_TR
.byte $00,$00,$00,$80,$80,$80,$A0,$60
.byte $00,$00,$00,$00,$00,$20,$00,$A8

; Tile $03 Player_BL
.byte $2F,$3C,$30,$20,$00,$00,$00,$00
.byte $00,$02,$06,$00,$00,$00,$00,$00

; Tile $04 Player_BR
.byte $E8,$78,$18,$08,$00,$00,$00,$00
.byte $00,$80,$C0,$00,$00,$00,$00,$00

; Tile $05 Bullet (outlined laser)
; center = color 3, sides = color 1

; plane 0 (low bit)
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000
.byte %00111000

; plane 1 (high bit)
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000
.byte %00010000

; Tile $06 Enemy A single color
.byte $18,$24,$42,$66,$81,$FF,$A5,$5A
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $07 Enemy A (2-color variant)
; Enemy ship (2-color variant)
; color 1 = body / outline
; color 3 = bright core

; plane 0 (low bit) — SAME silhouette
.byte $18,$24,$42,$66,$81,$FF,$A5,$5A

; Tile $07 Enemy A (outline accents) — plane 1
.byte $18  ; row 0: outer edges
.byte $24  ; row 1
.byte $42  ; row 2
.byte $42  ; row 3 (keeps it from looking like a face)
.byte $81  ; row 4
.byte $81  ; row 5 (avoid bright interior on the full $FF row)
.byte $81  ; row 6 (avoid "mask" look)
.byte $42  ; row 7


; Tile $08 Enemy B single color
.byte $38,$44,$44,$54,$FE,$FE,$54,$92
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $09 Enemy B (2-tone accent)
; plane 0 (silhouette) — unchanged
.byte $38,$44,$44,$54,$FE,$FE,$54,$92

; Tile $09 Enemy B (outline accents) — plane 1
.byte $28  ; row 0: edges of the top cap ($38)
.byte $44  ; row 1
.byte $44  ; row 2
.byte $44  ; row 3 (edge-only, avoids interior "face")
.byte $82  ; row 4 (edges only on the fat body)
.byte $82  ; row 5
.byte $44  ; row 6
.byte $82  ; row 7 (edges only on bottom)




; Tile $0A DEBUG solid (color 1)
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
.byte $00,$00,$00,$00,$00,$00,$00,$00


; Tile $0B DEBUG solid (color 2)
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF


; Tile $0C DEBUG solid (color 3)
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF


; Tile $0D DEBUG checker (alternating)
.byte $AA,$55,$AA,$55,$AA,$55,$AA,$55
.byte $00,$00,$00,$00,$00,$00,$00,$00


; Tile $0E DEBUG vertical stripes
.byte $CC,$CC,$CC,$CC,$CC,$CC,$CC,$CC
.byte $00,$00,$00,$00,$00,$00,$00,$00


; Tile $0F DEBUG X pattern
.byte $81,$42,$24,$18,$18,$24,$42,$81
.byte $00,$00,$00,$00,$00,$00,$00,$00


; ----------------------------
; Digits 0-9 (tiles $10-$19)
; color index 3 (both planes set)
; ----------------------------

; Tile $10 '0'
.byte $3C,$66,$6E,$76,$66,$66,$3C,$00
.byte $3C,$66,$6E,$76,$66,$66,$3C,$00

; Tile $11 '1'
.byte $18,$38,$18,$18,$18,$18,$7E,$00
.byte $18,$38,$18,$18,$18,$18,$7E,$00

; Tile $12 '2'
.byte $3C,$66,$06,$0C,$30,$60,$7E,$00
.byte $3C,$66,$06,$0C,$30,$60,$7E,$00

; Tile $13 '3'
.byte $3C,$66,$06,$1C,$06,$66,$3C,$00
.byte $3C,$66,$06,$1C,$06,$66,$3C,$00

; Tile $14 '4'
.byte $0C,$1C,$3C,$6C,$7E,$0C,$0C,$00
.byte $0C,$1C,$3C,$6C,$7E,$0C,$0C,$00

; Tile $15 '5'
.byte $7E,$60,$7C,$06,$06,$66,$3C,$00
.byte $7E,$60,$7C,$06,$06,$66,$3C,$00

; Tile $16 '6'
.byte $1C,$30,$60,$7C,$66,$66,$3C,$00
.byte $1C,$30,$60,$7C,$66,$66,$3C,$00

; Tile $17 '7'
.byte $7E,$66,$06,$0C,$18,$18,$18,$00
.byte $7E,$66,$06,$0C,$18,$18,$18,$00

; Tile $18 '8'
.byte $3C,$66,$66,$3C,$66,$66,$3C,$00
.byte $3C,$66,$66,$3C,$66,$66,$3C,$00

; Tile $19 '9'
.byte $3C,$66,$66,$3E,$06,$0C,$38,$00
.byte $3C,$66,$66,$3E,$06,$0C,$38,$00


; ----------------------------
; Letters for "GAME OVER" (tiles $1A-$20)
; Using color index 3 (both planes identical)
; ----------------------------

; Tile $1A 'G'
.byte $3C,$66,$60,$6E,$66,$66,$3C,$00
.byte $3C,$66,$60,$6E,$66,$66,$3C,$00

; Tile $1B 'A'
.byte $18,$3C,$66,$66,$7E,$66,$66,$00
.byte $18,$3C,$66,$66,$7E,$66,$66,$00

; Tile $1C 'M'
.byte $63,$77,$7F,$6B,$63,$63,$63,$00
.byte $63,$77,$7F,$6B,$63,$63,$63,$00

; Tile $1D 'E'
.byte $7E,$60,$60,$7C,$60,$60,$7E,$00
.byte $7E,$60,$60,$7C,$60,$60,$7E,$00

; Tile $1E 'O'
.byte $3C,$66,$66,$66,$66,$66,$3C,$00
.byte $3C,$66,$66,$66,$66,$66,$3C,$00

; Tile $1F 'V'
.byte $66,$66,$66,$66,$66,$3C,$18,$00
.byte $66,$66,$66,$66,$66,$3C,$18,$00

; Tile $20 'R'
.byte $7C,$66,$66,$7C,$6C,$66,$66,$00
.byte $7C,$66,$66,$7C,$6C,$66,$66,$00

; Tile $21 'P'
.byte $7C,$66,$66,$7C,$60,$60,$60,$00
.byte $7C,$66,$66,$7C,$60,$60,$60,$00

; Tile $22 'F'
.byte $7E,$60,$60,$7C,$60,$60,$60,$00
.byte $7E,$60,$60,$7C,$60,$60,$60,$00

; Tile $23 (unused / reserved)
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $24 'S'
.byte $3E,$60,$60,$3C,$06,$06,$7C,$00
.byte $3E,$60,$60,$3C,$06,$06,$7C,$00

; Tile $25 (unused / reserved)
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $26 'T'
.byte $7E,$18,$18,$18,$18,$18,$18,$00
.byte $7E,$18,$18,$18,$18,$18,$18,$00

; Tile $27 'L'
.byte $60,$60,$60,$60,$60,$60,$7E,$00
.byte $60,$60,$60,$60,$60,$60,$7E,$00

  .res 8192-640, $00
