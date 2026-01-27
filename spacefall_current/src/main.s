; ============================================================
; main.s — Starfall / Spacefall shooter (ca65)
; ============================================================
; ============================================================
; Build 2.6 26.01.26 8:55pm
; ============================================================
; ----------------------------
; Audio: FamiStudio
; ----------------------------
; --- FamiStudio config (must be BEFORE including the engine) ---
FAMISTUDIO_CFG_SFX_SUPPORT = 1
FAMISTUDIO_CFG_SFX_STREAMS = 2   ; start with 1 stream (simpler)

; ============================================================
; PLAYTEST-CLEAN ORGANIZATION PASS (NO LOGIC CHANGES)
; ============================================================
; TOC (search these tags):
;   [HW]      NES regs / bits
;   [CONST]   Constants / tiles / states / tuning
;   [HDR]     Header
;   [ZP]      Zero page
;   [BSS]     RAM
;   [RODATA]  Tables (palettes, params, strings)
;   [RESET]   Reset + init
;   [NMI]     NMI / vblank jobs
;   [MAIN]    Main loop + state machine
;   [SYS]     Systems (input/rng/player/bullets/enemies/boss/collisions)
;   [RENDER]  BuildOAM + draw helpers
;   [CHR]     CHR include
; ============================================================

.include "audio/famistudio_ca65.s"
.include "audio/music_all.s"
.include "audio/music_sfx.s"



; ============================================================
; CONSTANTS + TILE MAP + UI LAYOUT
; (Keep this section “dumb”: equates only, no code.)
; ============================================================

; ------------------------------------------------------------
; [HW] NES hardware registers
; ------------------------------------------------------------

; ------------------------------------------------------------
; HW registers
; ------------------------------------------------------------
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAM_HIDE_START  = $F0     ; used by tail-hider clamp (keeps $E0..$EF intact)
OAMDMA    = $4014
JOY1      = $4016
PPUMASK_BG_SPR = %00011000   ; show BG + sprites, hide left 8px

; ------------------------------------------------------------
; Controller
; ------------------------------------------------------------
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001
BTN_SELECT_START = (BTN_SELECT | BTN_START)

; ------------------------------------------------------------
; [CONST] Game states
; ------------------------------------------------------------
STATE_BANNER    = $00
STATE_PLAY      = $01
STATE_BOSS      = $02
STATE_OVER      = $03
STATE_TITLE     = $04
STATE_PAUSE     = $05   ; pick an unused value
STATE_TUTORIAL  = $06   ; pick a value not used

; ------------------------------------------------------------
; OAM layout
; ------------------------------------------------------------
SPR_HIDE_Y      = $FE     ; write to OAM Y to hide a sprite
SPR_SIZE        = $08     ; 8 pixels per hardware sprite
GAMEOVER_OAM  = $A0   ; sprite #40 * 4
GAMEOVER_ATTR = $00
BANNER_OAM   = $80    ; sprite #32 * 4
BANNER_ATTR  = $00
BOSS_OAM  = $10          ;
CATCH_OAM_BASE = $A0   ; sprite #40

; ------------------------------------------------------------
; Tile IDs
; ------------------------------------------------------------
BOSS_BULLET_TILE     = $05     ;
ENEMY_A_TILE_SOLID  = $06
ENEMY_A_TILE_ACCENT = $07   ; 2-tone variant
ENEMY_B_TILE_SOLID  = $08
ENEMY_B_TILE_ACCENT = $09   ; 2-tone variant
ENEMY_A_TILE = ENEMY_A_TILE_SOLID
ENEMY_B_TILE = ENEMY_B_TILE_SOLID
DIGIT_TILE_BASE  = $10     ; 0..9 => $10..$19
LETTER_TILE_BASE = $1A     ; project-specific font mapping
TILE_G = $1A
TILE_A = $1B
TILE_M = $1C
TILE_E = $1D
TILE_O = $1E
TILE_V = $1F
TILE_R = $20
TILE_P = $21
TILE_F = $22
TILE_S = $24
TILE_T = $26
TILE_L = $27
TILE_H = $29
TILE_I = $2A
TILE_C = $2B
TILE_U = $23
TILE_D = $25
TILE_N = $54
HEART_TILE = $28
CATCH_TILE_CORE    = $30        ; new tile index

; ------------------------------------------------------------
; UI layout
; ------------------------------------------------------------
BOSSBAR_NT_HI   = $20
BOSSBAR_NT_LO   = $68   ; row 3, column $2068
BOSSBAR_LEN     = $10   ; 16 tiles
BOSSBAR_TILE    = $0A
BOSSBAR_EMPTY   = $00   ; empty
TITLE_NT_HI  = $21
TITLE_NT_LO  = $8C    ; row 12, col 12  => $218C
TITLE_LEN    = 8
;PRESS_NT_HI  = $22
;PRESS_NT_LO  = $4B    ; row 18, col 11  => $224B
;PRESS_NT_LEN = 11     ; "PRESS"(5) + space(1) + "START"(5)
;GAMEOVER_NT_HI = $21
;GAMEOVER_NT_LO = $CB        ; row 14, col 11  => $21CB
;GAMEOVER_LEN   = 9
HUD_NT_HI      = $20
HUD_HI_LO      = $22   ; row 1 col 2  ($2022)
HUD_HI_DIG_LO  = $25   ; row 1 col 5  ($2025)
HUD_SC_LO      = $42   ; row 2 col 2  ($2042) -> "SC "
HUD_SC_DIG_LO  = $45   ; row 2 col 5  ($2045) -> digits start
HUD_LIVES_LO   = $2C   ; row 1 col 12 ($202C)
HUD_MAX_LIVES = 10      ;
GAMEOVER_Y    = $70
GAMEOVER_X0   = $48
BANNER_Y     = $58
BANNER_X0    = $64    ; centered-ish for 7 chars (56px wide)
PAUSE_NT_HI = $21
PAUSE_NT_LO = $CC
TUT_NT_HI   = $21
TUT_LINE1_LO = $8A     ; centered "AVOID ENEMIES"
TUT_LINE2_LO = $AB     ; next row (+$20)

; ------------------------------------------------------------
; Audio IDs
; ------------------------------------------------------------
MUSIC_TITLE    = $00
MUSIC_GAMEPLAY = $01
MUSIC_BOSS     = $02
MUSIC_NONE     = $FF

; ------------------------------------------------------------
; Gameplay tuning
; ------------------------------------------------------------
PLAYER_MOVE_SPD_X     = $02   ; px/frame
PLAYER_MOVE_SPD_Y     = $02   ; px/frame
PLAYER_MIN_X          = $08
PLAYER_MAX_X          = $F0
PLAYER_MIN_Y          = $10
PLAYER_MAX_Y          = $D0
FIRE_COOLDOWN_FR      = $06   ; frames between shots (lower = faster)
GUN_RIGHT_X_OFF       = $0C   ; right muzzle offset from player_x
INVULN_FRAMES = $60
SPAWN_START_DELAY_FR   = $10   ; grace period before first enemy appears
FLASH_HIT_FR        = $08   ; quick pop on player hit
FLASH_BOSS_START_FR = $12   ; longer / more dramatic
FLASH_LEVEL_START_FR = $06
FLASH_POWERUP_FR     = $04
FLASH_GRAY_CUTOFF = $0C   ; timers >= this use grayscale
FLAG_SET            = $01
FLAG_CLEAR          = $00
STAR_T0 = $2C    ; tiny dot
STAR_T1 = $2D    ; plus star
STAR_T2 = $2E    ; diamond star
STAR_T3 = $2F    ; bright cross (rare)
THR_B = $60     ; ~37% B (96/256)
THR_E = $F0     ; TEMP: top ~6% become E (16/256)
PLAYER_W = 16
PLAYER_H = 16
JAM_FR = 120        ; 1 second at 60fps (tweak)
JAM_FRAMES_BASE    = 60      ; frames (pick 60 to start)

; ------------------------------------------------------------
; Enemy constants
; ------------------------------------------------------------
ENEMY_ATTR      = $01      ; sprite palette index
ENEMY_SPAWN_Y   = $10
ENEMY_KILL_Y    = $E0
ENEMY_HIT_FLASH_FR  = 2    ; tiny flicker for “ouch”
ENEMY_DIE_FLASH_FR  = 8    ; your current death flash length (example)
EN_A = $00        ; 1x1 (8x8)
EN_B = $01        ; 1x1 (8x8)
EN_C = $02        ; 2x2 (16x16)
EN_D = $03        ; 2x2 (16x16)
EN_E = $04        ; 2x2 (16x16)
ENEMY_C_TL = $3C
ENEMY_C_TR = $3D
ENEMY_C_BL = $3E
ENEMY_C_BR = $3F
ENEMY_D_TL = $44
ENEMY_D_TR = $45
ENEMY_D_BL = $46
ENEMY_D_BR = $47
ENEMY_E_TL = $4C
ENEMY_E_TR = $4D
ENEMY_E_BL = $4E
ENEMY_E_BR = $4F
ENEMY_E_S_TL = $50
ENEMY_E_S_TR = $51
ENEMY_E_S_BL = $52
ENEMY_E_S_BR = $53
ENEMY_SPAWN_BASE   = 36      ; frames

; ------------------------------------------------------------
; Bullet constants
; ------------------------------------------------------------
BULLET_SPD            = $05   ; px/frame upward
BULLET_KILL_Y         = $08   ; kill once bullet Y < this (top safety)
BULLET_SPAWN_Y_OFF    = $04   ; spawn at (player_y - off)
BULLET_W = $08
BULLET_H = $08
BULLET_MAX = 4

; ------------------------------------------------------------
; Catch constants
; ------------------------------------------------------------
CATCH_SPAWN_Y      = $10
CATCH_KILL_Y       = $E8        ; off bottom
CATCH_SPD          = $01        ; pixels per frame
CATCH_SPAWN_MIN    = 90         ; frames
CATCH_SPAWN_VAR    = 90         ; +0..89 => 90..179
CATCH_ATTR         = $00        ; use sprite palette 1
CATCH_W  = 8
CATCH_H  = 8
CATCH_MAX      = 4     ;
CATCH_SPAWN_BASE   = 300     ; frames
CATCH_LIFE_BASE    = 240     ; frames (~4 seconds at 60fps)

; ------------------------------------------------------------
; Boss constants
; ------------------------------------------------------------
BOSS_X_INIT         = $78
BOSS_Y_INIT         = $30
BOSS_HP_INIT        = $10    ; 16 HP
BOSS_HIT_FLASH_FR   = $08
BOSS_FIRE_CD_FR     = $20    ; ~32 frames between shots
BOSS_MIN_X = $08
BOSS_MAX_X = $E8
BOSS_MIN_Y = $18
BOSS_MAX_Y = $60
BOSS_DX_INIT = $01   ; signed 8-bit: +1
BOSS_DY_INIT = $01
BOSS_BULLET_MAX      = 8
BOSS_BULLET_SPD      = $02     ; px/frame downward
BOSS_BULLET_KILL_Y   = $E8     ; kill once bullet Y >= this
BOSS_BULLET_SPAWN_Y  = $10     ; spawn at boss_y + this
BOSS_BULLET_X_OFF    = $08     ; spawn near boss center (for 16px boss)
BOSS_BULLET_Y_OFF    = $08
BOSS_BULLET_ATTR     = $01     ;
BOSS_PAT_SINGLE      = 0   ; existing
BOSS_PAT_SPREAD3     = 1   ; existing
BOSS_PAT_AIMED3      = 2   ; existing
BOSS_PAT_RING8       = 3   ; NEW: 8-way ring
BOSS_PAT_BURST_AIM   = 4   ; NEW: aimed burst (multi-shot over frames)
BOSS_PAT_SWEEP5      = 5   ; NEW: 5-shot sweeping fan (angle moves)
BOSS_PAT_STREAM_DOWN = 6   ; NEW: straight-down stream (fast cadence)
BOSS_PF_BIGSHOT_FX   = %00000001  ; bit0: you already use (flash/sfx emphasis)
BOSS_PF_FAST_CD      = %00000010  ; bit1: halves cooldown (min clamp)
BOSS_PF_DOUBLE_SHOT  = %00000100  ; bit2: fires pattern twice (2 volleys)
BOSS_PF_ALT_SWEEP    = %00001000  ; bit3: alternate sweep direction each fire
BOSS_PF_AIM_PLAYER   = %00010000  ; bit4: force aim variants to use player aim (for mixed patterns)
BOSS_PF_WOBBLE       = %00100000  ; bit5: adds small ±1 dx wobble on spawn (cheap “alive” look)
BOSS_PF_TWIN_BARREL  = %01000000  ; bit6: spawn from left/right offsets (two muzzles)
BOSS_PF_DENSE        = %10000000  ; bit7: “dense mode” (adds extra bullets where applicable)
BOSS_ATTR = $03          ; sprite palette 3
BOSS_W = 24
BOSS_H = 24
BOSS_TL = $33
BOSS_TM = $34
BOSS_TR = $35
BOSS_ML = $36
BOSS_MM = $37
BOSS_MR = $38
BOSS_BL = $39
BOSS_BM = $3A
BOSS_BR = $3B
BOSS_00 = BOSS_MM
BOSS_01 = BOSS_MM
BOSS_02 = BOSS_MM
BOSS_03 = BOSS_MM
BOSS_04 = BOSS_MM
BOSS_05 = BOSS_MM
BOSS_06 = BOSS_MM
BOSS_07 = BOSS_MM
BOSS_08 = BOSS_MM
BOSS_09 = BOSS_MM
BOSS_0A = BOSS_MM
BOSS_0B = BOSS_MM
BOSS_0C = BOSS_MM
BOSS_0D = BOSS_MM
BOSS_0E = BOSS_MM
BOSS_0F = BOSS_MM

; ------------------------------------------------------------
; Table strides/params
; ------------------------------------------------------------
LEVEL_SPAWN_CD_FR      = $18   ; base frames between spawns for a level
LEVEL_STRIDE = 12

; ------------------------------------------------------------
; Debug
; ------------------------------------------------------------
DEBUG_DRAW_TEST = 0      ; set to 0 to disable
DEBUG_BOSS_SKIP = 1     ; set to 0 to compile out boss-skip hotkey

; ============================================================
; [HDR] Header
; ============================================================

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

; ============================================================
; [ZP] ZEROPAGE — EXACT SYMBOL SET (no deletions / no renames)
; ============================================================

.segment "ZEROPAGE"

; ---- Music ----
music_cur:        .res 1   ; current song id ($FF = none)
current_music:    .res 1   ; kept because your code references it somewhere

; ---- SFX (square) ----
sfx_ptr_lo: .res 1
sfx_ptr_hi: .res 1
sfx_hold:   .res 1
sfx_active: .res 1

; ---- Input (legacy + current) ----
buttons:        .res 1
buttons_prev:   .res 1

pad1:           .res 1
pad1_prev:      .res 1
pad1_new:       .res 1

; ---- State-entry / UI flags that are touched a lot ----
title_inited:         .res 1
player_hit_lock:      .res 1
boss_sfx_cd:          .res 1

paused_prev_state:    .res 1
pause_inited:         .res 1

; ---- Frame sync ----
nmi_ready:            .res 1
frame_lo:             .res 1
frame_hi:             .res 1

; ---- Title / UI state (BG toggles) ----
first_run:            .res 1
press_visible:        .res 1
title_visible:        .res 1
gameover_visible:     .res 1
gameover_blink_timer: .res 1
gameover_blink_phase: .res 1
screen_flash_timer:   .res 1
boss_hp_clear_pending:.res 1

draw_test_active:     .res 1
draw_test_done:       .res 1

; ---- Scratch ----
tmp:  .res 1
tmp0: .res 1
tmp1: .res 1
tmp2: .res 1
tmp3: .res 1
tmp4: .res 1
tmp5: .res 1
tmp6: .res 1
tmp7: .res 1
tmp8: .res 1

hit_src_x: .res 1


; ---- Debug controls ----
debug_force_type: .res 1
debug_mode:       .res 1

; ---- enemy spawns ----
spawn_cd:       .res 1
level_enemy_cd: .res 1

; ---- catch spawns ----
catch_cd:       .res 1
level_catch_cd: .res 1

; ---- jam + catch lifetime ----
jam_timer:        .res 1
level_jam_frames: .res 1

catch_life_timer: .res 1
level_catch_life: .res 1
catch_active:     .res 1

; ---- Pause overlay ----
pause_dirty:  .res 1
pause_show:   .res 1

; ---- Noise SFX ----
sfxn_ptr_lo: .res 1
sfxn_ptr_hi: .res 1
sfxn_hold:   .res 1
sfxn_active: .res 1

; ============================================================
; [BSS] BSS — EXACT SYMBOL SET (no deletions / no renames)
; ============================================================
.segment "BSS"

; ---- Game state machine ----
game_state:       .res 1

; ---- Player ----
player_x:         .res 1
player_y:         .res 1
player_cd:        .res 1

; ---- Player bullets ----
bul_alive:        .res BULLET_MAX
bul_x:            .res BULLET_MAX
bul_y:            .res BULLET_MAX
bul_y_prev:       .res BULLET_MAX

; ---- misc core ----
gun_side:         .res 1
rng_lo:           .res 1
rng_hi:           .res 1
score_lo:         .res 1
score_hi:         .res 1
score_work_lo:    .res 1
score_work_hi:    .res 1
lives:            .res 1
invuln_timer:     .res 1
player_attr:      .res 1
good_flash_timer: .res 1

; ---- Score digits ----
score_d0:         .res 1
score_d1:         .res 1
score_d2:         .res 1
score_d3:         .res 1
score_d4:         .res 1

score_x_cur:      .res 1
tmp_xcur:         .res 1

; ---- Enemies ----
ENEMY_MAX = 5

ene_alive:   .res ENEMY_MAX
ene_x:       .res ENEMY_MAX
ene_y:       .res ENEMY_MAX
ene_y_prev:  .res ENEMY_MAX
ene_type:    .res ENEMY_MAX
obj_kind:    .res ENEMY_MAX
ene_variant: .res ENEMY_MAX

ene_spd:     .res ENEMY_MAX
ene_dx:      .res ENEMY_MAX
ene_hp:      .res ENEMY_MAX
ene_timer:   .res ENEMY_MAX
ene_score:   .res ENEMY_MAX

; ---- Catch object state ----
catch_spawn_cd: .res 1    ; kept even if redundant with catch_cd

catch_alive: .res CATCH_MAX
catch_x:     .res CATCH_MAX
catch_y:     .res CATCH_MAX
catch_type:  .res CATCH_MAX
catch_tile:  .res CATCH_MAX
catch_attr:  .res CATCH_MAX

; ---- Level control vars ----
level_idx:        .res 1
level_spawn_cd:   .res 1
level_enemy_spd:  .res 1
level_thrB:       .res 1
level_thrC:       .res 1
level_thrD:       .res 1
level_thrE:       .res 1

boss_time_lo:     .res 1
boss_time_hi:     .res 1

boss_timer_lo:    .res 1
boss_timer_hi:    .res 1
level_banner:     .res 1

; ---- Boss ----
boss_alive:       .res 1
boss_x:           .res 1
boss_y:           .res 1
boss_hp:          .res 1
boss_hp_max:      .res 1
boss_hp_dirty:    .res 1
boss_flash:       .res 1
boss_fire_cd:     .res 1

boss_dx:          .res 1
boss_dy:          .res 1

bossbul_alive:    .res BOSS_BULLET_MAX
bossbul_x:        .res BOSS_BULLET_MAX
bossbul_y:        .res BOSS_BULLET_MAX
bossbul_y_prev:   .res BOSS_BULLET_MAX
bossbul_dx:       .res BOSS_BULLET_MAX
bossbul_dy:       .res BOSS_BULLET_MAX

boss_pattern:     .res 1
boss_phase_flags: .res 1
boss_sweep_idx:   .res 1
boss_sweep_dir:   .res 1

boss_bigshot_pulse: .res 1
boss_shake_timer:   .res 1
boss_shake_dx:      .res 1
boss_shake_dy:      .res 1

boss_burst_left:  .res 1
boss_burst_gap:   .res 1

boss_phase:       .res 1
boss_phase_t0:    .res 1
boss_phase_t1:    .res 1
boss_phase_t2:    .res 1

boss_fire_cd_reload: .res 1
boss_move_mode:      .res 1

; ---- HUD (BG tiles) ----
hud_dirty:      .res 1

hi_d0:          .res 1
hi_d1:          .res 1
hi_d2:          .res 1
hi_d3:          .res 1
hi_d4:          .res 1

; ---- Extra gameplay ----
gun_jam_timer:          .res 1

level_catch_good_thr:   .res 1
level_catch_cap:        .res 1
enemy_cd:               .res 1    ; kept even if redundant with level_enemy_cd
level_catch_cd4:        .res 1

ene_flash:              .res ENEMY_MAX
catch_pickup_flash:     .res 1
jam_flash_timer:        .res 1

noise_lock_timer: .res 1


player_kb_timer: .res 1    ; frames remaining
player_kb_dx:    .res 1    ; signed (-1 or +1)
player_kb_dy:    .res 1    ; usually +1 (down) or 0

prev_game_state: .res 1
tutorial_timer:  .res 1
tutorial_visible:.res 1
tutorial_dirty:  .res 1   ; 1 = NMI should draw/clear
play_entered:    .res 1

tutorial_done: .res 1   ; 0 = not shown this run, 1 = already shown


.segment "RODATA"
; ============================================================
; [RODATA] STATIC DATA TABLES
; - SFX byte sequences (played by the simple SFX driver)
; - Palettes
; - Difficulty tables (LevelParams / Catch tables / Boss pattern tables)
; - UI strings / lookup tables
; NOTE: A few tiny helper routines may live near their data for convenience.
; ============================================================

TitleStarfallTiles:
  .byte TILE_S, TILE_T, TILE_A, TILE_R, TILE_F, TILE_A, TILE_L, TILE_L


; ----------------------------
; "PRESS START" prompt
; ----------------------------
PRESS_NT_HI  = $22
PRESS_NT_LO  = $4B    ; row 18, col 11  => $224B
PRESS_NT_LEN = 11     ; "PRESS"(5) + space(1) + "START"(5)

PressStartTiles:
  .byte TILE_P, TILE_R, TILE_E, TILE_S, TILE_S
  .byte $00                ; space (blank tile)
  .byte TILE_S, TILE_T, TILE_A, TILE_R, TILE_T


; ----------------------------
; "GAME OVER"
; ----------------------------
GAMEOVER_NT_HI = $21
GAMEOVER_NT_LO = $CB        ; row 14, col 11  => $21CB
GAMEOVER_LEN   = 9

GameOverTiles:
  .byte TILE_G, TILE_A, TILE_M, TILE_E
  .byte $00                ; space (blank tile)
  .byte TILE_O, TILE_V, TILE_E, TILE_R

; ----------------------------
; Sound Data
;-----------------------------
SFX_LASER:
  .byte 1, $35, $98, $00   ; tiny start
  .byte 1, $33, $B0, $00   ; small drop (laser hint)
  .byte 1, $30, $B0, $00   ; silence
  .byte 0

SFX_DRY:
  .byte 1, $32, $C0, $00   ; quiet “tick”
  .byte 1, $30, $C0, $00   ; silence
  .byte 0

  SFX_JAMCLICK:
  .byte 1, $31, $E0, $00
  .byte 1, $30, $E0, $00
  .byte 0

PlaySfxJamClick:
  lda #<SFX_JAMCLICK
  sta sfx_ptr_lo
  lda #>SFX_JAMCLICK
  sta sfx_ptr_hi
  lda #$01
  sta sfx_active
  lda #$00
  sta sfx_hold
  rts

; ----------------------------
; SFX_ENEMY_HIT (NOISE)
; short “tchk” burst
; ----------------------------
SFX_ENEMY_HIT:
  .byte 2, $33, $0E, $08   ; vol=3, hissy period
  .byte 1, $31, $0F, $06   ; quick tail
  .byte 0

SFX_ENEMY_KILL:
  .byte 2, $3C, $08, $08
  .byte 2, $38, $0A, $07
  .byte 1, $34, $0C, $06   ; was 2 -> 1 (shorter tail)
  .byte 0



SFX_PLAYER_HIT:
  .byte 1, $3A, $04, $08
  .byte 2, $36, $06, $07
  .byte 0



SFX_PICKUP:
  .byte 1, $34, $D0, $00
  .byte 1, $36, $B0, $00
  .byte 2, $38, $90, $00
  .byte 1, $30, $90, $00
  .byte 0

SFX_BOSS_SHOT:
  .byte 2, $3A, $B0, $00
  .byte 2, $38, $C8, $00
  .byte 2, $36, $E0, $00
  .byte 1, $30, $E0, $00
  .byte 0

SFX_WARNING_BEEP:
  .byte 2, $33, $A0, $00
  .byte 1, $30, $A0, $00
  .byte 0

SFX_BOSS_PHASE:
  .byte 2, $3F, $05, $08
  .byte 2, $3C, $07, $08
  .byte 2, $38, $09, $07
  .byte 0

; ------------------------------------------------------------
; Palettes (32 bytes)
; ------------------------------------------------------------
Palettes:
; BG palettes (brighter)
.byte $0F,$11,$21,$30   ; BG0: space ramp (dark blue-gray -> blue -> white)
;.byte $0F,$06,$16,$30   ; BG1: warm ramp (pink/red -> white highlight)
; Enemy palette
.byte $0F, $01, $21, $30

.byte $0F,$09,$19,$30   ; BG2: purple ramp -> white highlight
.byte $0F,$0C,$1C,$30   ; BG3: green ramp -> white highlight


  ; SPR palettes (16 bytes) (old palettes)
  ;.byte $0F,$01,$21,$30       ; SPR0 player
  ;.byte $0F,$16,$30,$30       ; SPR1 enemies
  ;.byte $0F,$01,$21,$30       ; SPR2 catch
  ;.byte $0F, $2A, $12, $02      ; SPR3 (boss)

  ; SPR palettes (16 bytes) (new palettes)
  .byte $0F,$01,$21,$30       ; SPR0 player (unchanged)

  .byte $0F,$01,$16,$30       ; SPR1 enemies base:
                              ;   idx1 outline = $01 (deep blue)
                              ;   idx2 body    = $16 (red)
                              ;   idx3 core    = $30 (white)

  .byte $0F,$01,$27,$30       ; SPR2 enemies shield/flash:
                              ;   outline stays same ($01)
                              ;   body becomes gold ($27)
                              ;   core stays white ($30)

  .byte $0F,$2A,$12,$02       ; SPR3 boss (unchanged)



; ------------------------------------------------------------
; Difficulty tables
; ------------------------------------------------------------
; ============================================================
; LEVEL PARAMS — HOW TO READ / TUNE THESE VALUES
; ============================================================
;
; This table defines per-level difficulty “knobs”.
; Each row is 12 bytes (LEVEL_STRIDE = 12).
;
; ------------------------------------------------------------
; GENERAL TIMING NOTES
; ------------------------------------------------------------
; - Game runs at 60 FPS.
; - 1 second = 60 frames.
; - catch_cd4 is multiplied by 4 in the loader:
;       catch_cd = catch_cd4 * 4
;
; ------------------------------------------------------------
; FIELD BREAKDOWN (by index)
; ------------------------------------------------------------
;
; [0] LP_SPAWN_CD  (enemy spawn cooldown, FRAMES)
;     - Smaller = enemies spawn more frequently.
;     - Interpreted directly as frames.
;     - Example:
;         spawn_cd = 30  -> 30 frames  -> 0.5 seconds
;         spawn_cd = 60  -> 60 frames  -> 1.0 second
;
; [1] LP_ENEMY_SPD (enemy fall speed)
;     - Added to Y position each frame.
;     - Larger = enemies fall faster.
;     - This is a per-frame pixel delta (not scaled).
;
; [2–5] LP_THR_B / C / D / E  (enemy type selection thresholds)
;     - Used with an 8-bit RNG roll r = 0..255.
;     - Selection logic:
;         if r < thrB              -> type B
;         else if r < thrC         -> type C
;         else if r < thrD         -> type D
;         else if thrE != 0
;              and r >= thrE       -> type E
;         else                     -> type A
;
;     - Thresholds must be ascending.
;     - Percent chance ≈ (band size) / 256.
;
; [6–7] LP_BOSS_TIME_LO / HI  (boss timer start)
;     - 16-bit value, in FRAMES.
;     - Example:
;         7200 frames  -> 120 seconds -> 2:00
;         9000 frames  -> 150 seconds -> 2:30
;
; [8] LP_ENE_CD  (enemy internal cooldown)
;     - Used by enemy AI for actions/firing.
;     - Smaller = more frequent behavior.
;     - Units are frames (implementation-specific).
;
; [9] LP_CATCH_CD4  (catch spawn attempt interval)
;     - Stored in units of 4 frames.
;     - Loader does:
;         catch_cd = max(catch_cd4,1) * 4
;
;     - Attempt interval (seconds):
;         seconds ≈ catch_cd4 / 15
;
;     - Examples:
;         catch_cd4 = 15  -> 1.0 sec per attempt
;         catch_cd4 = 30  -> 2.0 sec per attempt
;         catch_cd4 = 36  -> 2.4 sec per attempt
;         catch_cd4 = 75  -> 5.0 sec per attempt
;
; [10] LP_GOOD_THR  (catch spawn probability threshold)
;     - On each spawn attempt:
;         r = random 0..255
;         spawn if r < good_thr
;
;     - Probability per attempt:
;         P(spawn) = good_thr / 256
;
;     - Examples:
;         good_thr = 0    -> 0%   (never spawns)
;         good_thr = 32   -> 12.5%
;         good_thr = 60   -> 23.4%
;         good_thr = 128  -> 50%
;         good_thr = 255  -> ~99.6%
;
;     - Expected time between spawns:
;         ≈ (attempt interval) / (good_thr / 256)
;
;     - Example:
;         catch_cd4 = 36  (2.4s attempts)
;         good_thr  = 60  (23.4%)
;         → ~1 spawn every ~10 seconds (on average)
;
; [11] LP_CATCH_CAP  (max active catch objects)
;     - Maximum number of catch objects allowed
;       on screen at once.
;     - Typical values:
;         3 = generous
;         2 = moderate
;         1 = rare / high tension
;     - Must not exceed CATCH_MAX.
;

; ----- Macro: one row = one level -----
; boss_frames is a 16-bit value (in FRAMES).
.macro LEVELPARAMS spawn, spd, thrB, thrC, thrD, thrE, boss_frames, ene_cd, catch_cd4, good_thr, cap
  .byte spawn, spd, thrB, thrC, thrD, thrE, <(boss_frames), >(boss_frames), ene_cd, catch_cd4, good_thr, cap
.endmacro

; Notes:
; - thrE = $00 disables E entirely
; - boss_time is frames @60fps

LevelParams:

; L1 (gentle: mostly A, some B)
LEVELPARAMS $24, $01, $20, $20, $20, $00, 7200,  36,  24, 64,  3
; B 12.5%, A 87.5%

; L2 (a touch more B)
LEVELPARAMS $20, $01, $28, $28, $28, $00, 7200,  36,  26, 60,  3
; B 15.6%, A 84.4%

; L3 (introduce C)
LEVELPARAMS $1C, $02, $28, $40, $40, $00, 9000,  32,  28, 56,  3
; B 15.6%, C 9.4%, A 75.0%

; L4 (more C, tiny D)
LEVELPARAMS $1A, $02, $28, $48, $50, $00, 9000,  32,  30, 52,  2
; B 15.6%, C 12.5%, D 3.1%, A 68.8%

; L5 (C becomes real; D noticeable)
LEVELPARAMS $18, $02, $24, $54, $68, $00, 10800, 28,  32, 48,  2
; B 14.1%, C 18.8%, D 7.8%, A 59.4%

; L6 (speed bump; widen D a bit)
LEVELPARAMS $16, $03, $20, $50, $70, $00, 10800, 28,  34, 44,  2
; B 12.5%, C 18.8%, D 12.5%, A 56.3%

; L7 (more pressure; begin “mean” mix)
LEVELPARAMS $14, $03, $1C, $48, $74, $00, 12600, 24,  36, 40,  2
; B 10.9%, C 17.2%, D 17.2%, A 54.7%

; L8 (keep ramp smooth; slightly faster internal cd)
LEVELPARAMS $12, $03, $18, $44, $74, $00, 12600, 24,  38, 36,  2
; B 9.4%, C 17.2%, D 18.8%, A 54.7%

; L9 (spd 4 is spicy; give more D but not insane)
LEVELPARAMS $10, $04, $18, $40, $78, $00, 14400, 20,  40, 32,  2
; B 9.4%, C 15.6%, D 21.9%, A 53.1%

; L10 (introduce E: small top-band)
LEVELPARAMS $0F, $04, $18, $3C, $74, $F0, 16200, 20,  44, 28,  1
; B 9.4%, C 14.1%, D 21.9%, E 6.3%, A ~48.4%

; L11 (slightly more E)
LEVELPARAMS $0E, $04, $18, $38, $70, $EC, 16200, 20,  48, 26,  1
; B 9.4%, C 12.5%, D 21.9%, E 7.8%, A ~48.4%

; L12 (peak: E is real but still not dominating)
LEVELPARAMS $0D, $05, $18, $34, $6C, $E8, 18000, 20,  52, 24,  1
; B 9.4%, C 10.9%, D 21.9%, E 9.4%, A ~48.4%


; ============================================================
; BOSS BEHAVIOR TABLES — DESIGN & TUNING GUIDE
; ============================================================
;
; Boss behavior is 100% table-driven.
; Each boss (per level) has:
;
;   1) BossHPMaxTable      -> how long the fight lasts
;   2) BossPhaseTriggers  -> WHEN phases change (HP thresholds)
;   3) BossPhaseSets      -> WHAT the boss does in each phase
;
; The code reads these tables every frame during STATE_BOSS.
; No hardcoded behavior should override table-owned values.
;
; ------------------------------------------------------------
; 1) BossHPMaxTable
; ------------------------------------------------------------
; One byte per boss (level).
; This is the boss’s MAX HP at spawn.
;
; Example:
;   BossHPMaxTable:
;     .byte 24, 28, 32, 36, ...
;
; Tuning notes:
; - Higher HP = longer fight (more endurance).
; - If a boss feels exhausting, reduce HP before nerfing patterns.
; - HP scaling works best when paired with phase triggers.
;
; ------------------------------------------------------------
; 2) BossPhaseTriggers
; ------------------------------------------------------------
; 3 bytes per boss: t0, t1, t2
;
; Format:
;   .byte t0, t1, t2
;
; Interpretation (HP is decreasing):
;   Phase 0: boss_hp >  t0
;   Phase 1: boss_hp <= t0 AND > t1
;   Phase 2: boss_hp <= t1 AND > t2
;   Phase 3: boss_hp <= t2
;
; IMPORTANT:
; - Values MUST be descending: t0 > t1 > t2
; - Triggers are usually derived from HP max.
;
; Common baseline (quarters of HP):
;   t0 ≈ 75% of HP max
;   t1 ≈ 50% of HP max
;   t2 ≈ 25% of HP max
;
; Example:
;   Boss HP = 24
;   t0 = 18, t1 = 12, t2 = 6
;
; Tuning tips:
; - Raise t0 to shorten phase 0 (less intro).
; - Lower t2 to shorten phase 3 (less brutality).
;
; ------------------------------------------------------------
; 3) BossPhaseSets
; ------------------------------------------------------------
; Core behavior table.
; 4 PHASES per boss.
; 4 BYTES per phase.
; TOTAL = 16 bytes per boss.
;
; Layout per phase:
;   .byte pattern, fire_cd_reload, move_mode, phase_flags
;
; Full layout per boss:
;   phase0 (4 bytes)
;   phase1 (4 bytes)
;   phase2 (4 bytes)
;   phase3 (4 bytes)
;
; ------------------------------------------------------------
; Byte 0: pattern
; ------------------------------------------------------------
; Selects the firing pattern used by BossFirePattern.
;
; Typical meanings (example):
;   0 = single shot
;   1 = 3-way spread
;   2 = wider / faster spread
;   3 = aimed shot
;   4 = radial burst (future)
;
; Tuning:
; - Later phases should usually use higher pattern IDs.
; - Reusing patterns is fine; difficulty also comes from timing.
;
; ------------------------------------------------------------
; Byte 1: fire_cd_reload
; ------------------------------------------------------------
; Cooldown reload value (in FRAMES).
; Lower = fires more often.
;
; Rough feel @ 60 FPS:
;   40–50 = slow / introductory
;   28–36 = normal pressure
;   18–26 = aggressive
;   10–16 = very intense
;
; Tuning:
; - If a phase feels boring, lower by 2–4.
; - If overwhelming, raise by 4–8.
; - Big jumps between phases make transitions feel meaningful.
;
; ------------------------------------------------------------
; Byte 2: move_mode
; ------------------------------------------------------------
; Controls boss movement behavior.
;
; move_mode:
;   0 = BounceXY
;   1 = BounceX only
;   2 = BounceY only
;   3 = Box patrol (X for 64 frames, then Y for 64 frames)
;   4 = Stutter (move only on even frames)
;
; Tuning:
; - Phase 0 often uses X+Y for liveliness.
; - Stationary late phases feel tense and “desperate.”
; - This byte is future-proof: more movement styles can be added.
;
; ------------------------------------------------------------
; Byte 3: phase_flags (bitfield)
; ------------------------------------------------------------
; Optional per-phase modifiers.
; Each bit enables a small behavior tweak.
;
; Example flag ideas:
;   bit0 (%00000001) = big firing FX / screen shake
;   bit1 (%00000010) = aimed shots
;   bit2 (%00000100) = double fire
;   bit3 (%00001000) = fast bullets
;   bit4 (%00010000) = spawn minions (future)
;
; phase_flags (only bit0 currently implemented):
;   bit0 = big attack FX (screen shake + flash on spread)
;   bit1 = (unused)
;   bit2 = (unused)
;   bit3 = (unused)
;
; Tuning:
; - Flags add variety without inventing new patterns.
; - Use sparingly; one flag per phase is usually enough.
; - Leave as 0 if not implemented yet.
;
; ------------------------------------------------------------
; DESIGN PHILOSOPHY
; ------------------------------------------------------------
; - HP controls LENGTH.
; - Phase triggers control PACING.
; - Phase sets control FEEL.
;
; To increase difficulty:
;   - First adjust fire_cd_reload.
;   - Then adjust move_mode or flags.
;   - Increase HP LAST.
;
; Boss fights should feel different because behavior changes,
; not just because the HP bar is bigger.
; ============================================================


; ============================================================
; BOSS DATA TABLES
; ============================================================
;
; There are 12 bosses total (1 per level).
;
; Each boss has:
;   - A maximum HP value
;   - 4 combat phases
;   - 3 HP thresholds that trigger phase changes
;
; ------------------------------------------------------------
; CONSTANTS
; ------------------------------------------------------------
BOSS_PHASE_SET_STRIDE       = 4     ; bytes per phase
BOSS_PHASE_SET_TABLE_STRIDE = 16    ; bytes per boss (4 phases)
;
; Phase entry format (4 bytes):
;   [0] boss_pattern        ; firing pattern (0=single,1=spread,2=aimed)
;   [1] fire_cd_reload      ; frames between shots
;   [2] move_mode           ; reserved (currently unused)
;   [3] phase_flags         ; bit flags (bit0 = big attack FX)
;
; ------------------------------------------------------------
; Boss HP Maximums
; - Indexed by level_idx (0–11)
; ------------------------------------------------------------
BossHPMaxTable:
      ; L1  L2  L3  L4    L5  L6  L7  L8    L9  L10 L11 L12
  .byte 36, 40, 44, 48,   54, 60, 66, 72,   78, 84, 90, 96


; ------------------------------------------------------------
; Boss Phase Parameter Sets
; MUST be exactly 12 * 16 bytes
;
; Layout per boss:
;   Phase 0 (full HP)
;   Phase 1 (~75%)
;   Phase 2 (~50%)
;   Phase 3 (~25%)
; ------------------------------------------------------------
; pattern, fire_cd, move_mode, flags
; fire_cd is base; FAST_CD halves it (you said min clamp exists)

BossPhaseSets:
; pattern, fire_cd, move, flags
; ============================
; Boss 1
; ============================
  .byte 0, 34, 1, %00000000                    ; P0: single, slow, bounceX
  .byte 1, 32, 1, %00000001                    ; P1: spread3 + BIGSHOT_FX
  .byte 2, 30, 0, %00000000                    ; P2: aimed3, bounceXY
  .byte 2, 28, 0, %00000101                    ; P3: aimed3 + DOUBLE_SHOT + BIGSHOT_FX

; ============================
; Boss 2
; ============================
  .byte 1, 32, 1, %00000000                    ; P0: spread3, bounceX
  .byte 2, 30, 1, %00000000                    ; P1: aimed3, bounceX
  .byte 2, 28, 3, %00100000                    ; P2: aimed3, box patrol + WOBBLE
  .byte 2, 26, 3, %00000110                    ; P3: aimed3, box patrol + DOUBLE_SHOT + FAST_CD

; ============================
; Boss 3
; ============================
  .byte 0, 32, 2, %00000000                    ; P0: single, bounceY
  .byte 1, 30, 0, %00100000                    ; P1: spread3, bounceXY + WOBBLE
  .byte 2, 28, 2, %00000010                    ; P2: aimed3, bounceY + FAST_CD
  .byte 2, 26, 4, %00000110                    ; P3: aimed3, stutter + DOUBLE_SHOT + FAST_CD

; ============================
; Boss 4
; ============================
  .byte 0, 30, 0, %00000000                    ; P0: single, bounceXY
  .byte 1, 28, 0, %00000010                    ; P1: spread3 + FAST_CD
  .byte 2, 28, 3, %00000000                    ; P2: aimed3, box patrol
  .byte 2, 26, 3, %00000110                    ; P3: aimed3 + DOUBLE_SHOT + FAST_CD

; ============================
; Boss 5
; ============================
  .byte 1, 30, 1, %00000000                    ; P0: spread3, bounceX
  .byte 1, 28, 1, %00000010                    ; P1: spread3 + FAST_CD
  .byte 2, 28, 0, %00100000                    ; P2: aimed3 + WOBBLE
  .byte 2, 26, 0, %00000111                    ; P3: aimed3 + DOUBLE_SHOT + FAST_CD + BIGSHOT_FX

; ============================
; Boss 6
; ============================
  .byte 2, 30, 0, %00000000                    ; P0: aimed3, bounceXY
  .byte 2, 28, 0, %00000010                    ; P1: aimed3 + FAST_CD
  .byte 2, 28, 3, %00100000                    ; P2: aimed3, box patrol + WOBBLE
  .byte 2, 24, 3, %00000110                    ; P3: aimed3 + DOUBLE_SHOT + FAST_CD

; ============================
; Boss 7
; ============================
  .byte 1, 28, 0, %00000000                    ; P0: spread3, bounceXY
  .byte 2, 28, 4, %00000000                    ; P1: aimed3, stutter
  .byte 2, 26, 4, %00000010                    ; P2: aimed3, stutter + FAST_CD
  .byte 2, 24, 4, %00100110                    ; P3: aimed3, stutter + WOBBLE + DOUBLE_SHOT + FAST_CD

; ============================
; Boss 8
; ============================
  .byte 1, 28, 3, %00000000                    ; P0: spread3, box patrol
  .byte 1, 26, 3, %00000010                    ; P1: spread3 + FAST_CD
  .byte 2, 26, 3, %00100000                    ; P2: aimed3 + WOBBLE
  .byte 2, 24, 3, %00000110                    ; P3: aimed3 + DOUBLE_SHOT + FAST_CD

; ============================
; Boss 9
; ============================
  .byte 2, 28, 0, %00000010                    ; P0: aimed3 + FAST_CD
  .byte 2, 26, 0, %00100000                    ; P1: aimed3 + WOBBLE
  .byte 2, 24, 0, %00000110                    ; P2: aimed3 + DOUBLE_SHOT + FAST_CD
  .byte 2, 24, 4, %00100111                    ; P3: aimed3, stutter + WOBBLE + DOUBLE_SHOT + FAST_CD + BIGSHOT_FX

; ============================
; Boss 10
; ============================
  .byte 1, 26, 0, %00000010                    ; P0: spread3 + FAST_CD
  .byte 2, 26, 0, %00000000                    ; P1: aimed3
  .byte 2, 24, 3, %00000010                    ; P2: aimed3, box patrol + FAST_CD
  .byte 2, 22, 3, %00100110                    ; P3: aimed3, box patrol + WOBBLE + DOUBLE_SHOT + FAST_CD

; ============================
; Boss 11
; ============================
  .byte 2, 26, 0, %00000010                    ; P0: aimed3 + FAST_CD
  .byte 2, 24, 0, %00000110                    ; P1: aimed3 + DOUBLE_SHOT + FAST_CD
  .byte 2, 24, 3, %00100000                    ; P2: aimed3, box patrol + WOBBLE
  .byte 2, 22, 4, %00100110                    ; P3: aimed3, stutter + WOBBLE + DOUBLE_SHOT + FAST_CD

; ============================
; Boss 12
; ============================
  .byte 2, 24, 3, %00000010                    ; P0: aimed3, box patrol + FAST_CD
  .byte 2, 22, 3, %00000110                    ; P1: aimed3 + DOUBLE_SHOT + FAST_CD
  .byte 2, 22, 4, %00100110                    ; P2: aimed3, stutter + WOBBLE + DOUBLE_SHOT + FAST_CD
  .byte 2, 20, 4, %00100111                    ; P3: aimed3, stutter + WOBBLE + DOUBLE_SHOT + FAST_CD + BIGSHOT_FX

; ------------------------------------------------------------
; Boss Phase Triggers
; MUST be exactly 12 * 3 bytes
;
; For each boss:
;   t0 = HP threshold for phase 1
;   t1 = HP threshold for phase 2
;   t2 = HP threshold for phase 3
;
; Rule:
;   if hp < t0 → phase 1
;   if hp < t1 → phase 2
;   if hp < t2 → phase 3
; ------------------------------------------------------------
BossPhaseTriggers:
;        t0  t1  t2
  .byte  27, 18,  9    ; Boss 1 (max 36)
  .byte  30, 20, 10    ; Boss 2 (max 40)
  .byte  33, 22, 11    ; Boss 3 (max 44)
  .byte  36, 24, 12    ; Boss 4 (max 48)
  .byte  40, 27, 14    ; Boss 5 (max 54)
  .byte  45, 30, 15    ; Boss 6 (max 60)
  .byte  50, 33, 17    ; Boss 7 (max 66)
  .byte  54, 36, 18    ; Boss 8 (max 72)
  .byte  58, 39, 20    ; Boss 9 (max 78)
  .byte  63, 42, 21    ; Boss 10 (max 84)
  .byte  68, 45, 23    ; Boss 11 (max 90)
  .byte  72, 48, 24    ; Boss 12 (max 96)



; dx,dy pairs (signed via two’s complement)
BossDir8:
  .byte $00, $FE   ; N   ( 0, -2)
  .byte $02, $FE   ; NE  ( 2, -2)
  .byte $02, $00   ; E   ( 2,  0)
  .byte $02, $02   ; SE  ( 2,  2)
  .byte $00, $02   ; S   ( 0,  2)
  .byte $FE, $02   ; SW  (-2,  2)
  .byte $FE, $00   ; W   (-2,  0)
  .byte $FE, $FE   ; NW  (-2, -2)




StarTiles:
  .byte STAR_T0, STAR_T1, STAR_T2, STAR_T3


; ----------------------------
; Enemy tuning tables
; ----------------------------
EnemyHP_Table:
  .byte 1   ; EN_A  ($00)
  .byte 2   ; EN_B  ($01)
  .byte 3   ; EN_C  ($02)
  .byte 4   ; EN_D  ($03)
  .byte 6   ; EN_E  ($04)


ENEMY_TYPE_COUNT = 5

; ------------------------------------------------------------
; Enemy score values (BCD digits, not binary)
; 3 bytes per type: hundreds, tens, ones
; ------------------------------------------------------------
EnemyScore_HTO:
  .byte 0,1,0   ; EN_A = 010
  .byte 0,2,5   ; EN_B = 025
  .byte 0,5,0   ; EN_C = 050
  .byte 1,0,0   ; EN_D = 100
  .byte 0,5,0   ; EN_E = 050  


; ------------------------------------------------------------
; Boss score by bracket (levels grouped by 3)
; bracket 0 = levels 1–3   => 1000
; bracket 1 = levels 4–6   => 2000
; bracket 2 = levels 7–9   => 5000
; bracket 3 = levels 10–12 => 10000
;
; Digits stored as: d4 d3 d2 d1 d0  (ones..ten-thousands)
; ------------------------------------------------------------
BossScoreDigits:
  .byte 0,0,0,1,0   ; 1000
  .byte 0,0,0,2,0   ; 2000
  .byte 0,0,0,5,0   ; 5000
  .byte 0,0,0,0,1   ; 10000



EnemyFlashFrames_Table:
  .byte 4,6,8,10,12

.segment "OAM"
OAM_BUF: .res 256

; ----------------------------
; CODE
; ----------------------------
.segment "CODE"

; ------------------------------------------------------------
; [RESET]
; - Hardware init
; - RAM/OAM clear
; - Initial game state
; - Enable NMI + rendering
; ------------------------------------------------------------

; ------------------------------------------------------------
; STABLE ZONE — RESET / init
; Playtest build: avoid logic/timing changes here.
; ------------------------------------------------------------
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

  ; warm up (vblank sync)
  jsr WaitVBlank
  jsr WaitVBlank

  ; clear RAM + OAM shadow
  jsr ClearRAM
  jsr ClearOAM

  ; ---- structured init ----
  jsr InitAudio
  jsr InitGameVars
  jsr ClearActors
  jsr InitVRAMAndUI

  jmp MainLoop

; ------------------------------------------------------------
; InitAudio
; - FamiStudio init + SFX init
; - Sets music state vars to "none"
; - Enables APU channels
; ------------------------------------------------------------
InitAudio:
  ; Init FamiStudio (correct regs)
  lda #$01                          ; NTSC
  ldx #<_music_data_spacefall_gameplay
  ldy #>_music_data_spacefall_gameplay
  jsr famistudio_init

  lda #$FF
  sta current_music
  sta music_cur

  ldx #<_sounds
  ldy #>_sounds
  jsr famistudio_sfx_init

  ; enable APU channels (SQ1 SQ2 TRI NOISE)
  lda #%00001111
  sta $4015
  rts

; ------------------------------------------------------------
; InitGameVars
; - Initializes game/state variables (no actor arrays)
; ------------------------------------------------------------
InitGameVars:
  lda #$00
  sta player_kb_timer
  sta player_kb_dx
  sta player_kb_dy

  sta play_entered
  sta first_run

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

  sta gun_side

  ; seed RNG (fixed seed at boot)
  lda #$A7
  sta rng_lo
  lda #$1D
  sta rng_hi

  lda #$00
  sta score_lo
  sta score_hi

  sta bul_y_prev

  ; start with a short delay before first spawn
  lda #SPAWN_START_DELAY_FR
  sta spawn_cd

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
  sta title_visible
  sta gameover_visible

  lda #$00
  sta gameover_blink_timer
  sta gameover_blink_phase

  lda #$00
  sta screen_flash_timer

  lda #$00
  sta draw_test_active
  sta draw_test_done

  ; debug
  lda #$00
  sta debug_force_type
  sta debug_mode
  rts

; ------------------------------------------------------------
; InitVRAMAndUI
; - VRAM init with rendering OFF
; - Draw starfield NT0/NT1 + attributes/UI attrs
; - HUD init
; - Enables NMI + rendering
; ------------------------------------------------------------
InitVRAMAndUI:
  ; keep rendering OFF while writing VRAM
  lda #$00
  sta PPUCTRL
  sta PPUMASK

  ; VRAM init (rendering still OFF)
  jsr WaitVBlank
  ; align enabling rendering to vblank boundary
  jsr WaitVBlank

  ; scroll = 0,0 (clean latch)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  jsr PPU_BeginVRAM
  jsr InitPalettes_Safe

  jsr ClearNametable0
  jsr DrawStarfieldNT0
  jsr ClearAttributesNT0
  jsr SetUIAttrsNT0

  jsr ClearNametable1
  jsr DrawStarfieldNT1
  jsr ClearAttributesNT1
  jsr SetUIAttrsNT1

  jsr PPU_EndVRAM

  jsr HUD_Init

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
  rts


; ----------------------------
; [NMI]
; ----------------------------

; ------------------------------------------------------------
; STABLE ZONE — NMI / vblank timing
; Playtest build: avoid logic/timing changes here.
; ------------------------------------------------------------
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

jsr NextRand

; ---- OAM DMA (typical) ----
  lda #$00
  sta OAMADDR
  lda #>OAM_BUF     ; high byte of the actual buffer location
  sta OAMDMA


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

  ; --------------------------------------------
  ; Tutorial timer (auto-hide)
  ; --------------------------------------------
  lda tutorial_timer
  beq @tut_timer_done

  dec tutorial_timer
  bne @tut_timer_done

  ; timer just hit 0 -> request clear once
  lda #$00
  sta tutorial_visible
  lda #$01
  sta tutorial_dirty

@tut_timer_done:

  ; --------------------------------------------
  ; Tutorial BG draw/clear (one-shot)
  ; --------------------------------------------
  lda tutorial_dirty
  beq @tut_done

  lda #$00
  sta tutorial_dirty

  lda tutorial_visible
  beq @tut_clear

@tut_draw:
  jsr DrawTutorialBG
  jmp @tut_done

@tut_clear:
  jsr ClearTutorialBG

@tut_done:



  lda screen_flash_timer      ; screen_flash_timer: nonzero => temporarily force palette/brightness effect
  beq @flash_off

  dec screen_flash_timer

; grayscale while timer >= FLASH_GRAY_CUTOFF
  lda screen_flash_timer
  cmp #FLASH_GRAY_CUTOFF
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




    jsr Pause_NMI_Update

  jsr HUD_NMI_Update

  lda game_state
  cmp #STATE_BOSS
  bne :+

    lda boss_alive
    beq :+

    lda boss_hp_dirty
    beq :+
      lda #$00
      sta boss_hp_dirty
      jsr WriteBossHPBarBG
:


  lda boss_hp_clear_pending
  beq @boss_hp_clear_done

  lda #FLAG_CLEAR
  sta boss_hp_clear_pending


  jsr ClearBossHPBG          ; writes blanks to the boss HP bar area

@boss_hp_clear_done:



  pla
  tay
  pla
  tax
  pla

    ; --- hard reset scroll every frame ---
  lda PPUSTATUS      ; reset latch
  lda #$00
  sta PPUSCROLL      ; X = 0
  sta PPUSCROLL      ; Y = 0

  ; ensure base nametable is $2000 (optional but recommended)
  lda #%10000000     ; NMI on, nametable 0
  sta PPUCTRL



; now tell the main loop the frame is ready
lda #$01
sta nmi_ready

  rti


IRQ:
  rti


; ------------------------------------------------------------
; [MAIN]
; ------------------------------------------------------------
; MainLoop
; - Frame sync via WaitFrame
; - Poll input
; - Dispatch by game_state
; ------------------------------------------------------------
; ============================================================
; MAIN LOOP / STATE MACHINE
; - Runs once per frame (WaitFrame releases after NMI)
; - Reads controller input
; - Dispatches to the current game_state handler
; - Each state handler is responsible for gameplay updates + calling BuildOAM
;   (NMI handles vblank-only work: OAM DMA + BG/HUD writes)
; ============================================================

; ------------------------------------------------------------
; STABLE ZONE — Main loop / state machine
; Playtest build: avoid logic/timing changes here.
; ------------------------------------------------------------
MainLoop:
  jsr WaitFrame

  jsr famistudio_update
  ;jsr UpdateSfx
  jsr UpdateSfxNoise

  jsr ReadController1

; --- DEBUG input handling ---
jsr DebugUpdate

.if DEBUG_BOSS_SKIP

  ; SELECT + START (new press) => jump to boss
  lda pad1_new
  and #BTN_SELECT_START
  cmp #BTN_SELECT_START
  bne :+

    ; Optional gate: don’t trigger from title
    lda game_state
    cmp #STATE_TITLE
    beq :+

    jsr DebugJumpToBoss
:

.endif




; ------------------------------------------------------------
; State dispatch (game_state)
; ------------------------------------------------------------
  lda game_state
  cmp #STATE_TITLE
  bne :+
    jmp @state_title
  :
  cmp #STATE_TUTORIAL
  beq @state_tutorial

  cmp #STATE_BANNER
  bne :+
    jmp @state_banner
  :

  cmp #STATE_PLAY
  bne :+
    jmp @state_play
  :

  cmp #STATE_BOSS
  bne :+ 
    jmp @state_boss
  :
    cmp #STATE_PAUSE
  bne :+
    jmp @state_pause
  :

  jmp @state_over

; ----------------------------
; STATE: TITLE
; - Blink PRESS START BG tiles (handled via frame counter / visibility flag)
; - Start game on START
; - Draw title sprites + any overlays
; ----------------------------
@state_title:
  lda #MUSIC_TITLE
  cmp current_music
  beq :+
    sta current_music
    jsr Music_Play
:
  jsr NextRand


  lda pad1_new
  and #BTN_START
  beq :+

     jsr ReseedRNG

    ; --- redraw starfield safely (brief render-off) ---
    lda #$00
    sta PPUMASK
    jsr WaitVBlank

  jsr PPU_BeginVRAM
  jsr ClearNametable0
  jsr DrawStarfieldNT0
  jsr ClearAttributesNT0
  jsr ClearNametable1
  jsr DrawStarfieldNT1
  jsr ClearAttributesNT1
  jsr PPU_EndVRAM


    lda #PPUMASK_BG_SPR
    sta PPUMASK

    
    jsr ResetRun
    jsr EnterLevelStart

:

  jsr BuildOAM
  jmp MainLoop


@state_tutorial:
  ; optional: keep player moving around while reading
  jsr UpdatePlayer

  ; allow START to skip tutorial early
  lda pad1_new
  and #BTN_START
  beq :+
    lda #$00
    sta tutorial_timer        ; force it to end
:

  ; when timer hits 0, leave tutorial
  lda tutorial_timer
  bne @tut_render

  ; --- timer is 0: exit tutorial ---

  ; request clear (one-shot)
  lda tutorial_visible
  beq @tut_exit
  lda #$00
  sta tutorial_visible
  lda #$01
  sta tutorial_dirty          ; NMI clears it

@tut_exit:
  ; mark tutorial as shown for this run
  lda #$01
  sta tutorial_done

  ; go to banner (tutorial is before banner now)
  lda #60
  sta level_banner
  lda #STATE_BANNER
  sta game_state

@tut_render:
  jsr BuildOAM
  jmp MainLoop

; ----------------------------
; STATE: BANNER (LEVEL X)
; “each frame”: count down banner timer
; ----------------------------
@state_banner:
  lda #$01
  jsr famistudio_music_pause
  jsr ClearPlayerBullets  
  jsr UpdatePlayer          ; optional: allow movement during banner
  jsr BannerUpdate          ; <-- THIS is the “each frame” part
  jsr BuildOAM              ; BuildOAM should call DrawLevelBannerSprites when banner active
  jmp MainLoop



; ----------------------------
; STATE: PLAY
; “each frame”: decrement boss_timer, transition to BOSS at 0
; ----------------------------
@state_play:


  lda #$00
  jsr famistudio_music_pause
  lda #MUSIC_GAMEPLAY
  cmp current_music
  beq :+
    sta current_music
    jsr Music_Play
:


  ; ---- PAUSE TOGGLE ----
  lda pad1_new
  and #BTN_START
  beq :+
    lda #STATE_PLAY
    sta paused_prev_state
    lda #STATE_PAUSE
    sta game_state

    jsr famistudio_music_pause

    lda #$01
    sta pause_show
    lda #$01
    sta pause_dirty

    jmp @play_render_only
:


  jsr UpdateCatchPickupFlash
  jsr UpdateJamFlash
  jsr UpdatePlayer
  jsr UpdateBullets
  jsr CollideBulletsCatch

  jsr UpdateEnemies

  jsr UpdateCatch
  jsr CollidePlayerCatch

  jsr CollideBulletsEnemies
  jsr CollidePlayerEnemies
  jsr PlayUpdate

@play_render_only:
  jsr BuildOAM
  jmp MainLoop

; ----------------------------
; STATE: BOSS 
; ----------------------------
@state_boss:
  lda #$00
  jsr famistudio_music_pause
  lda #MUSIC_BOSS
  cmp current_music
  beq :+
    sta current_music
    jsr Music_Play
:

    lda pad1_new
  and #BTN_START
  beq :+
    lda game_state
    sta paused_prev_state
    lda #STATE_PAUSE
    sta game_state

    jsr famistudio_music_pause

    lda #$01
    sta pause_show
    lda #$01
    sta pause_dirty

    lda #$00
    sta pause_inited
    jmp @boss_render_only
:

  jsr UpdateCatchPickupFlash
  jsr UpdateJamFlash
  jsr UpdatePlayer
  jsr UpdateBullets

  jsr UpdateCatch
  jsr CollidePlayerCatch
  jsr CollideBulletsCatch

  jsr BossUpdate
  jsr BossBigAttackFX
  ; jsr BossMoveBounceX
  ; jsr BossMoveBounceY
  jsr UpdateBossBullets
  jsr CheckPlayerHitByBossBullets
  jsr CollideBulletsBoss

@boss_render_only:
  jsr BuildOAM
  jmp MainLoop



; ----------------------------
; STATE: OVER (Game Over)
; - Accepts START to restart (ResetRun)
; - Game Over BG blink sequence is driven in NMI using gameover_visible/timers
; - Draws stats / game over sprites via BuildOAM
; ----------------------------
@state_over:
 
jsr famistudio_music_stop

  lda pad1_new
  and #BTN_START
  beq @over_draw
  jsr ReseedRNG
    lda #$00
  sta screen_flash_timer

    lda pad1_new
  and #BTN_START
  beq :+
    jsr ReturnToTitle
:

  
@over_draw:
  jsr BuildOAM
  jmp MainLoop



@state_pause:
  lda pad1_new
  and #BTN_START
  beq :+
    lda paused_prev_state
    sta game_state

    lda #$00
    jsr famistudio_music_pause

      lda #$00
    sta pause_show
    lda #$01
    sta pause_dirty

    ; optional but recommended: prevent double-trigger
    lda pad1
    sta pad1_prev
:

  jsr BuildOAM
  jmp MainLoop


;=========================================================
; [SYS] Systems 
; (input/rng/player/bullets/enemies/boss/collisions)
;=========================================================

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
  ldx #$04        ; 4 * 256 = 1024 bytes
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

ClearAttributesNT0:
  lda PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$C0
  sta PPUADDR
  ldx #$40          ; 64 bytes
  lda #$00
@loop:
  sta PPUDATA
  dex
  bne @loop
  rts


ClearNametable1:
  lda PPUSTATUS
  lda #$24
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$00
  ldx #$04
  ldy #$00
@page:
@byte:
  sta PPUDATA
  iny
  bne @byte
  dex
  bne @page

  lda PPUSTATUS
  rts


ClearAttributesNT1:
  lda PPUSTATUS
  lda #$27
  sta PPUADDR
  lda #$C0
  sta PPUADDR
  ldx #$40
  lda #$00
@loop:
  sta PPUDATA
  dex
  bne @loop
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

  ; Top UI band on NT0: set attribute bytes 0..7 to palette 1 ($55)
SetUIAttrsNT0:
  lda PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$C0
  sta PPUADDR

  ldx #$08
  lda #$55        ; palette 1 everywhere in those blocks
@loop:
  sta PPUDATA
  dex
  bne @loop
  rts

; Same for NT1 (attributes at $27C0)
SetUIAttrsNT1:
  lda PPUSTATUS
  lda #$27
  sta PPUADDR
  lda #$C0
  sta PPUADDR

  ldx #$08
  lda #$55
@loop:
  sta PPUDATA
  dex
  bne @loop
  rts

; ------------------------------------------------------------
; InitPalettes_Safe
; - Writes palettes but skips $3F10 (mirror of $3F00 on NES)
; - Palettes layout assumed:
;     00..0F = BG palettes (16 bytes, includes universal at [0])
;     10..1F = SPR palettes (16 bytes, includes mirror at [16])
; ------------------------------------------------------------
InitPalettes_Safe:
  ; --- write universal BG color ($3F00) ---
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda Palettes+0
  sta PPUDATA

  ; --- write BG colors 1..15 to $3F01..$3F0F ---
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$01
  sta PPUADDR

  ldx #$01
@bg:
  lda Palettes,x          ; Palettes[1..15]
  sta PPUDATA
  inx
  cpx #$10
  bne @bg

  ; --- write SPR colors 1..15 to $3F11..$3F1F (skip $3F10) ---
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$11
  sta PPUADDR

  ldx #$11
@spr:
  lda Palettes,x          ; Palettes[17..31]
  sta PPUDATA
  inx
  cpx #$20
  bne @spr

  rts

; ============================================================
; INPUT
;
; Conventions:
;   pad1       = current button state (bitmask)
;   pad1_prev  = last frame state
;   pad1_new   = buttons newly pressed this frame (rising edges)
;
; NOTE:
;   ReadController1 reads raw input only.
;   Any “meaning” (pause/start/debug toggles) should be handled elsewhere,
;   but this project currently also stores a couple debug toggles nearby.
; ============================================================

; ------------------------------------------------------------
; ReadController1
; - Latches controller 1, reads 8 buttons into pad1
; - Produces pad1_new = newly pressed buttons this frame
; ------------------------------------------------------------
ReadController1:
  lda pad1
  sta pad1_prev

  lda #$01
  sta JOY1
  lda #$00
  sta JOY1
  ; NES controller serial read: 8 bits, LSB first.
  ; Bit order after loop matches BTN_* constants used elsewhere.
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

; ============================================================
; DEBUG / TEST HELPERS
; RELEASE NOTE: disable or fence these for final builds.
;
; These hooks are meant for development only.
; Keep them isolated so they don’t subtly affect release gameplay.
;
; Common flags:
;   DEBUG_DRAW_TEST   : bypass updates and draw a known-good sprite
;   debug_mode        : force enemy type (A..E) or 0 for normal behavior
;   draw_test_active  : one-shot guard so tests don’t respawn endlessly
;
; TIP:
;   If something “impossible” is happening in gameplay,
;   search for DEBUG_* or debug_mode first.
; ============================================================

DebugUpdate:
  lda pad1_new
  and #BTN_SELECT
  beq @done

  inc debug_mode
  lda debug_mode
  cmp #$06
  bcc :+
    lda #$00
    sta debug_mode
  :

  lda debug_mode
  beq @done            ; only clear if entering a debug mode

  ldx #$00
@cb_loop:
  cpx #BULLET_MAX
  bcs @done
  lda #$00
  sta bul_alive,x
  inx
  bne @cb_loop

@done:
  rts


; ------------------------------------------------------------
; DebugJumpToBoss
; - Dev hotkey: instantly enter boss phase
; - Safe: clears actors, spawns boss, marks boss bar dirty, flashes
; ------------------------------------------------------------
DebugJumpToBoss:
  jsr ClearActors

  lda #STATE_BOSS
  sta game_state

  lda #FLASH_BOSS_START_FR
  sta screen_flash_timer

  jsr BossSpawn            ; sets boss_alive, boss_x/y, boss_hp, dirty, etc.

  rts


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

    jsr PlaySfxJamClick
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
  bcc @dry_fire

  ; SUCCESS
  ;jsr PlaySfxLaser
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
  sbc #BULLET_SPD          ; bullet speed (px/frame)
  sta bul_y,x

  bcc @kill   ; carry clear => wrapped past 0 => offscreen

  ; optional extra safety: also kill if very near top
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
.if DEBUG_DRAW_TEST
  lda draw_test_active
  beq :+
    jmp @no_slot
  :
.endif

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
  sta tmp1              ; tmp1 = type roll

  lda tmp1
  cmp level_thrB
  bcc @set_B

  lda tmp1
  cmp level_thrC
  bcc @set_C

  lda tmp1
  cmp level_thrD
  bcc @set_D

  ; E only if enabled AND roll >= thrE
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

  ; decorrelate: mix hi + frame into the value we use for X
  eor rng_hi
  clc
  adc frame_lo

  and #$F8            ; 8px grid

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
  ; dx = -1 or +1
  jsr NextRand
  and #$01
  beq :+
    lda #$01
    bne :++
: lda #$FF
:
  sta ene_dx,x
  lda #$08          ; grace frames before drift
  sta ene_timer,x
  rts

@init_C:
  ; dx = -1 or +1, timer starts 0
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

@init_D:
  jsr NextRand
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
.if DEBUG_DRAW_TEST
  lda draw_test_active
  beq :+
    rts               ; skip all enemy updates; draw still happens in BuildOAM
:
.endif

  ; ----------------------------------------------------------
  ; Per-frame enemy update flow:
  ;   1) Handle spawn cooldown (spawn_cd)
  ;   2) For each active slot:
  ;        - store prev Y
  ;        - apply vertical fall (level_enemy_spd + per-slot tweaks)
  ;        - apply type-specific behavior (EN_A..EN_E)
  ;        - kill if past ENEMY_KILL_Y
  ; ----------------------------------------------------------


  ; ---- spawn cooldown ----
  lda spawn_cd
  beq @do_spawn
  dec spawn_cd
  jmp @move

@do_spawn:
  jsr SpawnEnemy
  lda level_enemy_cd
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
  jsr NextRand
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
  adc #$07              ; or (BULLET_H-1) if you define it
  cmp ene_y_prev,y
  bcc @ene_next


  ; ---- HIT! ----
@hit:
  jsr PlaySfxEnemyHit
 

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
  ; - use “death flash” (your existing kill-after-flash path)
  ; ============================
  lda #ENEMY_DIE_FLASH_FR
  sta ene_flash,y
  jsr PlaySfxExplode

  ; ---- add score based on enemy type ----
  txa
  pha                    ; SAVE bullet index X

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
  tax                    ; RESTORE bullet index X

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
  beq PlayerSetOver          ; already 0

  jsr SafeDecrementLives
  jsr HUD_MarkDirty          ; <-- ALWAYS redraw hearts after a hit

  lda lives
  beq PlayerSetOver          ; if we just hit 0, go over now

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


; ------------------------------------------------------------
; PlayerSetOver
; - Common game-over transition
; ------------------------------------------------------------
PlayerSetOver:
  jsr ClearActors
  lda #STATE_OVER
  sta game_state

  lda #FLASH_HIT_FR
  sta screen_flash_timer

  lda #FLAG_SET
  sta boss_hp_clear_pending

  rts

RedrawStarfieldOnRestart:
  ; --- rendering OFF ---
  lda #$00
  sta PPUMASK

  jsr WaitVBlank        ; get safely into vblank

  jsr ReseedRNG         ; IMPORTANT: do this BEFORE drawing stars

  jsr PPU_BeginVRAM
  jsr ClearNametable0
  jsr DrawStarfieldNT0
  jsr ClearAttributesNT0
  jsr ClearNametable1
  jsr DrawStarfieldNT1
  jsr ClearAttributesNT1
  jsr PPU_EndVRAM


  ; clean scroll latch + set 0,0
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  ; --- rendering back ON ---
  lda #PPUMASK_BG_SPR
  sta PPUMASK
  rts

ReturnToTitle:
  ; --- reset title-specific flags so title draws again ---
  lda #$00
  sta title_inited
  sta press_visible
  sta title_visible
  sta gameover_visible
  sta gameover_blink_timer
  sta gameover_blink_phase

  ; lda #$00
  ; sta scroll_x
  ; sta scroll_y_lo
  ; sta scroll_y_hi

  ; --- redraw starfield safely (rendering off inside helper) ---
  jsr RedrawStarfieldOnRestart

  lda #STATE_TITLE
  sta game_state
  rts

; call before any big VRAM write (nametables, attributes, etc.)
PPU_BeginVRAM:
  ; disable NMI 
  lda PPUCTRL
  and #%01111111
  sta PPUCTRL

  ; rendering off
  lda #$00
  sta PPUMASK

  ; wait for vblank boundary
  jsr WaitVBlank

  ; clear latch + set scroll to 0,0 (avoids "streak" artifacts)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL
  rts

PPU_EndVRAM:
  ; clear latch again (safe)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  ; re-enable NMI
  lda PPUCTRL
  ora #%10000000
  sta PPUCTRL

  ; rendering on 
  lda #PPUMASK_BG_SPR
  sta PPUMASK
  rts

; ----------------------------
; ResetRun
; - prepares a new run (called at boot and on restart)
; ----------------------------
ResetRun:

  ; ---- clear catch objects ----
  ldx #$00
@clr_catch:
  cpx #CATCH_MAX
  bcs @clr_catch_done
  lda #$00
  sta catch_alive,x
  sta catch_x,x
  sta catch_y,x
  inx
  bne @clr_catch
@clr_catch_done:

  ; ---- seed catch spawn cooldown ----

  lda #STATE_PLAY
  sta paused_prev_state


lda #$00          ; start in normal mode
sta debug_force_type

  lda #FLAG_SET
  sta boss_hp_clear_pending

  lda #FLAG_CLEAR
  sta boss_hp_dirty
  sta boss_alive
  sta boss_hp
  sta boss_hp_max



.if DEBUG_DRAW_TEST
  lda #$00
  sta draw_test_active
  sta draw_test_done
.endif

  lda #$00       ; starting level
  sta level_idx
 jsr LoadLevelParams

   jsr ReseedCatchSpawn

  jsr ClearActors          ; (ok)

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
  lda #$00
sta catch_pickup_flash


  ; score digits
  lda #$00
  sta score_d0
  sta score_d1
  sta score_d2
  sta score_d3
  sta score_d4

  lda #$03         ; starting lives
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

  jsr HUD_Init

  rts

ReseedCatchSpawn:
  jsr NextRand
  and #$7F                  ; 0..127
  ; reduce to 0..(CATCH_SPAWN_VAR-1) if VAR is power-of-two; for 90 it isn't.
  clc
  adc #CATCH_SPAWN_MIN
  sta catch_cd
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
; SpawnCatch
; returns: C=1 spawned, C=0 skipped
; ------------------------------------------------------------
SpawnCatch:
  jsr CountActiveCatch     ; A = active count
  cmp level_catch_cap
  bcc @can_spawn           ; count < cap
    clc                    ; skipped
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

  lda #CATCH_TILE_CORE
  sta catch_tile,x

  lda #CATCH_ATTR        ; <-- ADD THIS
  sta catch_attr,x       ; <-- ADD THIS


  ; ---- X position (multiples of 8, with failsafe) ----
  lda #$10
  sta tmp1               ; <-- use tmp1, not tmp0

@rand_x:
  jsr NextRand
  and #$F8
  cmp #$08
  bcc @retry
  cmp #$F0
  bcs @retry
  sta catch_x,x
  sec                    ; spawned
  rts

@retry:
  dec tmp1
  bne @rand_x

  lda #$80
  sta catch_x,x
  sec                    ; spawned (fallback still counts as spawn)
  rts

@no_slot:
  clc                    ; skipped (no free slot)
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


CollidePlayerCatch:
  ldx #$00
@loop:
  cpx #CATCH_MAX
  bcs @done

  lda catch_alive,x
  beq @next

  ; ---- dx = catch_x - player_x ----
  lda catch_x,x
  sec
  sbc player_x
  bcs @dx_pos
    eor #$FF
    clc
    adc #$01
@dx_pos:
  ; if dx >= PLAYER_W (16) => no collide
  cmp #PLAYER_W
  bcs @next

  ; ---- dy = catch_y - player_y ----
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

  ; award: +1 life (cap at HUD_MAX_LIVES)
  lda lives
  cmp #HUD_MAX_LIVES      ; <-- NO "$" here
  lda #$11
    sta catch_pickup_flash
    jsr PlaySfxPickup

  bcs @after_life         ; if lives >= max, don't increase

  inc lives
  jsr HUD_MarkDirty       ; lives changed, so redraw hearts next NMI

@after_life:
    


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
beq :+
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



; ------------------------------------------------------------
; AddScore_TensOnes
;   Adds (tens, ones) to score_d4..d0
;   Input: A = tens, X = ones   (0..9 each)
;   Trashes: A
; ------------------------------------------------------------
AddScore_TensOnes:
  ; add ones -> d4
  txa
  clc
  adc score_d4
  cmp #10
  bcc :+
    sbc #10
    sta score_d4
    ; carry into tens
    lda score_d3
    clc
    adc #1
    cmp #10
    bcc @store_d3
      sbc #10
      sta score_d3
      jmp @carry_to_d2
:
  sta score_d4
  ; now add tens (A input) into d3
  lda score_d3
  clc
  adc tmp0          ; (we'll load tmp0 with tens before calling)
  cmp #10
  bcc @store_d3
    sbc #10
    sta score_d3
@carry_to_d2:
    lda score_d2
    clc
    adc #1
    cmp #10
    bcc @store_d2
      sbc #10
      sta score_d2
      ; cascade carry up
      lda score_d1
      clc
      adc #1
      cmp #10
      bcc @store_d1
        sbc #10
        sta score_d1
        lda score_d0
        clc
        adc #1
        cmp #10
        bcc @store_d0
          lda #9        ; clamp like you already do
@store_d0:
          sta score_d0
          jmp @done

@store_d3:
  sta score_d3
@store_d2:
  sta score_d2
@store_d1:
  sta score_d1
@done:
  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts

; ------------------------------------------------------------
; AddScoreHTO
; Adds tmp2:tmp1:tmp0 (hundreds:tens:ones) into score_d2..d4
; Carries upward, clamps score_d0 to 9 (like your old code).
; Trashes A
; ------------------------------------------------------------
AddScoreHTO:
  ; ---- ones -> d4 ----
  lda score_d4
  clc
  adc tmp0
  cmp #10
  bcc :+
    sbc #10
    sta score_d4
    lda #1
    bne @carry_to_tens
:
  sta score_d4
  lda #0
@carry_to_tens:
  sta tmp3          ; tmp3 = carry (0/1)

  ; ---- tens -> d3 ----
  lda score_d3
  clc
  adc tmp1
  adc tmp3
  cmp #10
  bcc :+
    sbc #10
    sta score_d3
    lda #1
    bne @carry_to_hund
:
  sta score_d3
  lda #0
@carry_to_hund:
  sta tmp3

  ; ---- hundreds -> d2 ----
  lda score_d2
  clc
  adc tmp2
  adc tmp3
  cmp #10
  bcc :+
    sbc #10
    sta score_d2
    lda #1
    bne @carry_to_thou
:
  sta score_d2
  lda #0
@carry_to_thou:
  sta tmp3

  ; ---- thousands -> d1 ----
  lda score_d1
  clc
  adc tmp3
  cmp #10
  bcc :+
    sbc #10
    sta score_d1
    lda #1
    bne @carry_to_tenth
:
  sta score_d1
  lda #0
@carry_to_tenth:
  sta tmp3

  ; ---- ten-thousands -> d0 (clamp) ----
  lda score_d0
  clc
  adc tmp3
  cmp #10
  bcc :+
    lda #9          ; clamp at 9
:
  sta score_d0

  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts

; ------------------------------------------------------------
; AddScoreA
;   Adds A points by calling AddScore1 A times
;   Input: A = points (0..9 recommended)
;   Trashes: A, tmp0
; ------------------------------------------------------------
AddScoreA:
  sta tmp0
  beq @done

@loop:
  jsr AddScore1
  dec tmp0
  bne @loop

@done:
  rts


; ------------------------------------------------------------
; AddScore5Digits
; Adds 5 base-10 digits from (tmp0,tmp1) into score_d4..score_d0
; Table format: [d4,d3,d2,d1,d0]
; ------------------------------------------------------------
AddScore5Digits:
  ldy #$00
  clc

  ; d4 (ones)
  lda score_d4
  adc (tmp0),y
  cmp #10
  bcc :+
    sbc #10
    sec
  :
  sta score_d4
  iny

  ; d3 (tens)
  lda score_d3
  adc (tmp0),y
  cmp #10
  bcc :+
    sbc #10
    sec
  :
  sta score_d3
  iny

  ; d2 (hundreds)
  lda score_d2
  adc (tmp0),y
  cmp #10
  bcc :+
    sbc #10
    sec
  :
  sta score_d2
  iny

  ; d1 (thousands)
  lda score_d1
  adc (tmp0),y
  cmp #10
  bcc :+
    sbc #10
    sec
  :
  sta score_d1
  iny

  ; d0 (ten-thousands) + clamp to 9
  lda score_d0
  adc (tmp0),y
  cmp #10
  bcc :+
    lda #9          ; clamp at 99999
  :
  sta score_d0

  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts

; ------------------------------------------------------------
; AddBossScore
; Adds bracketed boss score based on level_idx:
; 0..2  => bracket 0 (1000)
; 3..5  => bracket 1 (2000)
; 6..8  => bracket 2 (5000)
; 9..11 => bracket 3 (10000)
; ------------------------------------------------------------
AddBossScore:
  lda level_idx     ; 0..11
  ldx #$00          ; X = bracket

@div3_loop:
  cmp #3
  bcc @got_bracket
  sec
  sbc #3
  inx
  cpx #3
  bcc @div3_loop
  ; if somehow level_idx is >= 12, clamp bracket to 3
  ldx #3

@got_bracket:
  txa               ; A = X
  asl a             ; *2
  asl a             ; *4
  sta tmp0          ; save 4*X

  txa               ; A = X
  clc
  adc tmp0          ; X + 4X = 5X
  tay               ; Y = bracket * 5


  lda #<BossScoreDigits
  clc
  adc #0            ; (just to be explicit: no-op)
  sta tmp0
  lda #>BossScoreDigits
  sta tmp1

  ; add offset into pointer
  tya
  clc
  adc tmp0
  sta tmp0
  bcc :+
    inc tmp1
  :

  jsr AddScore5Digits
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
  lda #9          ; clamp 
  sta score_d0

@done:
  jsr UpdateHighScoreIfNeeded
  jsr HUD_MarkDirty
  rts

LoadLevelParams:
  ; Y = level_idx * LEVEL_STRIDE (12)
  lda level_idx
  asl
  asl
  sta tmp0
  asl
  clc
  adc tmp0
  tay

  ; --- base 8 bytes ---
  lda LevelParams,y        ; [0] spawn_cd
  sta level_spawn_cd
  sta spawn_cd
  iny
  lda LevelParams,y        ; [1] enemy_spd
  sta level_enemy_spd
  iny
  lda LevelParams,y        ; [2] thrB
  sta level_thrB
  iny
  lda LevelParams,y        ; [3] thrC
  sta level_thrC
  iny
  lda LevelParams,y        ; [4] thrD
  sta level_thrD
  iny
  lda LevelParams,y        ; [5] thrE
  sta level_thrE
  iny
  lda LevelParams,y        ; [6] boss_lo
  sta boss_time_lo
  iny
  lda LevelParams,y        ; [7] boss_hi
  sta boss_time_hi
  iny

  ; --- new 4 knobs ---
  lda LevelParams,y        ; [8] ene_cd
  sta level_enemy_cd
  sta enemy_cd
  iny

  lda LevelParams,y        ; [9] catch_cd4 (units of 4 frames)
  sta level_catch_cd4
  iny

  lda LevelParams,y        ; [10] good_thr
  sta level_catch_good_thr
  iny

  lda LevelParams,y        ; [11] catch_cap
  sta level_catch_cap

  ; scale catch_cd4 -> catch_cd in frames (min 1 step => 4 frames)
  lda level_catch_cd4
  bne :+
    lda #$01
:
  asl                      ; *2
  asl                      ; *4
  sta catch_cd

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
  ; Enter boss phase: set state, flash, clear actors, init boss, show HP bar.
  lda #STATE_BOSS
  sta game_state
    lda #FLASH_BOSS_START_FR
  sta screen_flash_timer

  jsr ClearActors
    jsr BossSpawn
  rts

NextLevel:
  lda #FLAG_SET
  sta boss_hp_clear_pending


  inc level_idx
  jsr LoadLevelParams
  jsr EnterLevelStart
  rts



; ------------------------------------------------------------
; ReseedRNG
; - Initializes rng_hi:rng_lo to a non-zero value
; - Called on title->start and occasionally for safety
; ------------------------------------------------------------
ReseedRNG:
  lda rng_lo
  eor frame_lo
  eor pad1_new      ; include edge, not held
  ora #$01
  sta rng_lo

  lda rng_hi
  eor frame_hi
  eor pad1
  sta rng_hi

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
; BossSpawn
; - initializes boss fight state (boss + boss bullets)
; - loads phase triggers + phase settings (table-driven)
; ------------------------------------------------------------
BossSpawn:
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

  lda #FLAG_SET
  sta boss_hp_dirty
  lda #FLAG_CLEAR
  sta boss_flash

  ; ---- NEW: clear pattern-state vars (important) ----
  lda #$00
  sta boss_burst_left
  sta boss_burst_gap
  sta boss_sweep_idx
  sta boss_sweep_dir

  rts





; ============================================================
; BOSS SYSTEM
;
; Boss phase entry:
;   - Timer counts down in PLAY; when it hits 0, @start_boss sets STATE_BOSS.
;   - Boss HP (boss_hp) is tracked in RAM.
;
; Boss HP bar (BG tiles):
;   - Main loop sets boss_hp_dirty=1 when HP changes.
;   - NMI consumes boss_hp_dirty and calls WriteBossHPBarBG.
;   - When the boss ends, set boss_hp_clear_pending=1 so NMI clears the bar once.
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
; ----------------------------
BossMoveBounceY:
  lda boss_y
  clc
  adc boss_dy
  sta boss_y

  lda boss_y
  cmp #BOSS_MIN_Y
  bcs @check_max_y

  lda #BOSS_MIN_Y
  sta boss_y
  jsr BossFlipDY
  jmp @done_y

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
  ; Index mapping to your BossDir8 rows:
  ;   0 N, 1 NE, 2 E, 3 SE, 4 S, 5 SW, 6 W, 7 NW
  ;
  ; We'll pick:
  ;  - if dy_sign is + => S hemisphere (3,4,5)
  ;  - if dy_sign is - => N hemisphere (7,0,1)
  ;  - dx_sign chooses left/right
  ;  - If you want fewer diagonals, you can force cardinal here.
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

  jsr PlayerTakeHit
  rts


@next:
  inx
  bne @loop

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

  lda #FLAG_SET
  sta boss_hp_dirty

  lda boss_hp
  bne @next_b

  ; boss dead
  lda #FLAG_CLEAR
  sta boss_alive


  ;jsr PlaySfxBossKill         ; (optional if you have it)
  jsr AddBossScore            ; <-- ADD THIS

  jsr ClearBossBullets
  jsr ClearPlayerBullets
  jsr ClearActors             ; optional but recommended

  jsr NextLevel
  rts




@next_b:
  inx
  bne @bul_loop

@done:
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
  adc #$08           ; center-ish tweak for your boss size
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





; ============================================================
; RNG (RANDOM NUMBER GENERATION)
;
; Implementation:
;   - 16-bit Galois LFSR stored in rng_hi:rng_lo
;   - NextRand advances the LFSR and returns rng_lo in A
;
; Usage pattern:
;   - NMI calls NextRand every frame to keep entropy moving,
;     even during pauses or menus.
;   - Gameplay code calls NextRand when a random decision is needed.
;
; SAFETY:
;   - The all-zero state is invalid for an LFSR.
;   - Code explicitly re-seeds if rng_hi|rng_lo == 0.
; ============================================================

; ------------------------------------------------------------
; NextRand
; - 16-bit Galois LFSR, right shift
; - taps 0xB400 (xor into high byte only)
; - returns A = rng_lo
; ------------------------------------------------------------
NextRand:
  ; shift hi first so its bit0 becomes the new bit7 of lo
  lda rng_hi
  lsr
  sta rng_hi

  lda rng_lo
  ror              ; pulls old bit0 of rng_hi into bit7 of rng_lo
  sta rng_lo       ; carry now = old bit0 of rng_lo (tap decision)

  bcc @done        ; if old lsb was 0, no tap

  lda rng_hi
  eor #$B4
  sta rng_hi

@done:
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
  lda #$38          ;
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
  sta catch_alive,y
  

  ; ---- penalty: jam gun ----
  lda level_jam_frames
  sta jam_timer

  lda #JAM_FR
  sta gun_jam_timer
    lda #$0C              ; 12 frames feels good
  sta jam_flash_timer

  lda #$00
  sta player_cd               ; make jam apply immediately
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

; ------------------------------------------------------------
; SafeDecrementLives
; - If lives > 0: lives -= 1
; - If lives becomes 0: triggers game over
; - Always marks HUD dirty
; ------------------------------------------------------------
SafeDecrementLives:
  lda lives
  beq @already_zero      ; don't underflow

  sec
  sbc #$01
  sta lives

  lda #FLAG_SET
  sta hud_dirty          ;

  lda lives
  bne @done

  ; ---- lives just hit 0 -> GAME OVER ----
  jsr PlayerSetOver       ; (see below)
  rts

@already_zero:
  jsr DoGameOver
@done:
  rts

DoGameOver:
  jsr ClearActors
  lda #STATE_OVER
  sta game_state
  rts

Pause_NMI_Update:
  lda pause_dirty
  bne :+
    rts
:
  lda #$00
  sta pause_dirty

  lda PPUSTATUS
  lda #PAUSE_NT_HI
  sta PPUADDR
  lda #PAUSE_NT_LO
  sta PPUADDR

  lda pause_show
  bne @draw

@erase:
  lda #$00
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  rts

@draw:
  lda #$21  ; P
  sta PPUDATA
  lda #$1B  ; A
  sta PPUDATA
  lda #$23  ; U
  sta PPUDATA
  lda #$24  ; S
  sta PPUDATA
  lda #$1D  ; E
  sta PPUDATA
  rts

PlaySfxLaser:
  lda #<SFX_LASER
  sta sfx_ptr_lo
  lda #>SFX_LASER
  sta sfx_ptr_hi
  lda #$01
  sta sfx_active
  lda #$00
  sta sfx_hold
  rts

UpdateSfx:
  lda sfx_active
  bne :+
  rts
:

  lda sfx_hold
  beq @load_step
  dec sfx_hold
  rts

@load_step:
  ldy #$00
  lda (sfx_ptr_lo),y
  beq @stop            ; 0 = end
  sta sfx_hold         ; frames_to_hold

  iny
  lda (sfx_ptr_lo),y   ; $4004 value
  sta $4004            ; $30
  iny
  lda (sfx_ptr_lo),y   ; $4006 value
  sta $4006            ; $49
  iny
  lda (sfx_ptr_lo),y   ; $4007 value
  sta $4007            ; $00

  ; optional but recommended: disable sweep for clean SFX
  lda #$00
  sta $4005

  ; advance pointer by 4 bytes (frames + 3 regs)
  clc
  lda sfx_ptr_lo
  adc #$04
  sta sfx_ptr_lo
  bcc :+
  inc sfx_ptr_hi
:
  rts

@stop:
  lda #$00
  sta sfx_active

  ; silence Square 2 (quickest: set volume = 0)
  lda #$30            ; duty bits unchanged, constant volume, vol=0 (common)
  sta $4004
  rts



PlaySfxDry:
  lda #<SFX_DRY
  sta sfx_ptr_lo
  lda #>SFX_DRY
  sta sfx_ptr_hi
  lda #$01
  sta sfx_active
  lda #$00
  sta sfx_hold
  rts

PlaySfxEnemyHit:
;lda #%00001111
;sta $4015



  lda #<SFX_ENEMY_HIT
  sta sfxn_ptr_lo
  lda #>SFX_ENEMY_HIT
  sta sfxn_ptr_hi
  lda #$01
  sta sfxn_active
  lda #$00
  sta sfxn_hold

  rts

UpdateSfxNoise:
  lda sfxn_active
  bne :+
  rts
:
  lda sfxn_hold
  beq @load_step
  dec sfxn_hold
  rts

@load_step:
  ldy #$00
  lda (sfxn_ptr_lo),y
  beq @stop
  sta sfxn_hold

  iny
  lda (sfxn_ptr_lo),y     ; $400C
  sta $400C

  iny
  lda (sfxn_ptr_lo),y     ; $400E
  sta $400E

  iny
  lda (sfxn_ptr_lo),y     ; $400F
  sta $400F

  ; advance ptr by 4 bytes
  clc
  lda sfxn_ptr_lo
  adc #$04
  sta sfxn_ptr_lo
  bcc :+
  inc sfxn_ptr_hi
:
  rts

@stop:
  lda #$00
  sta sfxn_active

  ; silence noise fast: volume=0 (keep const vol/halt bits)
  lda #%00110000
  sta $400C
  rts


SFX_FIRING    = 0
SFX_EXPLODE   = 1

PlaySfxFiring:
  lda #SFX_FIRING
  ldx #FAMISTUDIO_SFX_CH0    ; keep firing on slot 0
  jsr famistudio_sfx_play
  rts


PlaySfxExplode:
  lda #SFX_EXPLODE
  ldx #FAMISTUDIO_SFX_CH1    ; <-- stream/channel SLOT 1 (correct)
  jsr famistudio_sfx_play
  rts




PlaySfxPlayerHit:


  lda #<SFX_PLAYER_HIT
  sta sfxn_ptr_lo
  lda #>SFX_PLAYER_HIT
  sta sfxn_ptr_hi
  lda #$01
  sta sfxn_active
  lda #$00
  sta sfxn_hold
  rts

PlaySfxPickup:
  lda #<SFX_PICKUP
  sta sfx_ptr_lo
  lda #>SFX_PICKUP
  sta sfx_ptr_hi
  lda #$01
  sta sfx_active
  lda #$00
  sta sfx_hold
  rts

PlaySfxBossShot:
  lda #<SFX_BOSS_SHOT
  sta sfx_ptr_lo
  lda #>SFX_BOSS_SHOT
  sta sfx_ptr_hi
  lda #$01
  sta sfx_active
  lda #$00
  sta sfx_hold
  rts

PlaySfxWarning:
  lda #<SFX_WARNING_BEEP
  sta sfx_ptr_lo
  lda #>SFX_WARNING_BEEP
  sta sfx_ptr_hi
  lda #$01
  sta sfx_active
  lda #$00
  sta sfx_hold
  rts

PlaySfxBossPhase:
  lda #<SFX_BOSS_PHASE
  sta sfxn_ptr_lo
  lda #>SFX_BOSS_PHASE
  sta sfxn_ptr_hi
  lda #$01
  sta sfxn_active
  lda #$00
  sta sfxn_hold
  rts

BossShotSfxMaybe:
  lda boss_sfx_cd
  bne @no
  jsr PlaySfxBossShot   ; OR PlaySfxBossShot (use your boss-shot sound)
  lda #$08              ; rate limit (8 frames feels good)
  sta boss_sfx_cd
@no:
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

; A = song id (MUSIC_*)
Music_Play:
  cmp music_cur
  beq @done          ; already playing this
  sta music_cur
  jsr famistudio_music_play
@done:
  rts

Music_Stop:
  lda #MUSIC_NONE
  sta music_cur
  jsr famistudio_music_stop
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
  ; you can either “snap” current cooldown or not. I recommend snapping:
  sta boss_fire_cd
  iny
  lda BossPhaseSets,y
  sta boss_move_mode
  iny
  lda BossPhaseSets,y
  sta boss_phase_flags

  rts


  EnterLevelStart:
  lda tutorial_done
  bne @go_banner

  ; first time only: tutorial BEFORE banner
  lda #STATE_TUTORIAL
  sta game_state

  lda #$01
  sta tutorial_visible
  lda #180
  sta tutorial_timer
  lda #$01
  sta tutorial_dirty

  rts

@go_banner:
  lda #60
  sta level_banner
  lda #STATE_BANNER
  sta game_state
  rts

;=========================================================
; [RENDER]  BuildOAM + draw helpers
;=========================================================
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
; OAM SAFETY CONSTANTS (reserved region for fixed boss bullets)
; ------------------------------------------------------------
OAM_DYNAMIC_LIMIT = $E0    ; bytes $E0..$EF reserved for DrawBossBullets_Fixed
OAM_2X2_LIMIT     = $D0    ; need 16 bytes (4 sprites) before hitting $E0
BULLET_OAM_BASE   = $10    ; sprite 4 (4*4)


; ------------------------------------------------------------
; OAM layout helpers (playtest-safe)
; ------------------------------------------------------------
;SPR_HIDE_Y        = $FE
;BULLET_OAM_BASE   = $10
;OAM_DYNAMIC_LIMIT = $E0   ; $E0..$EF reserved for DrawBossBullets_Fixed
BOSS_OAM_BYTES    = 36    ; 9 sprites * 4 bytes
BOSS_OAM_AFTER    = BOSS_OAM + BOSS_OAM_BYTES

; ------------------------------------------------------------
; BuildOAM
; - Clears OAM shadow
; - Draws sprites for the current game_state
; - Does NOT do OAM DMA (NMI does that)
; ------------------------------------------------------------

; ------------------------------------------------------------
; STABLE ZONE — Sprite build (OAM shadow)
; Playtest build: avoid logic/timing changes here.
; ------------------------------------------------------------
BuildOAM:
  jsr ClearOAMShadow

  lda game_state
  cmp #STATE_TITLE
  bne @check_over

  ; TITLE: nothing to draw (BG does the title)
  rts

@check_over:
  lda game_state
  cmp #STATE_OVER
  bne @normal_draw

  ; STATE_OVER: no sprites (BG handles overlays)
  rts



@normal_draw:

  ; ----------------------------
  ; Player metasprite (sprites 0-3)
  ; ----------------------------
  lda player_attr
  sta tmp4

  ; ---- jam flash wins ----
  lda jam_flash_timer
  beq @check_pickup
  and #$03
  beq @pattr_ready

  lda player_attr
  and #%11111100
  ora #$01              ; palette 3 for jam (distinct)
  sta tmp4
  jmp @pattr_ready

@check_pickup:
  lda catch_pickup_flash
  beq @pattr_ready
  and #$03
  beq @pattr_ready

  lda player_attr
  and #%11111100
  ora #$03              ; palette 2 for pickup
  sta tmp4

@pattr_ready:


  ; TL
  lda player_y
  sta OAM_BUF+0
  lda #$01
  sta OAM_BUF+1
  lda tmp4
  sta OAM_BUF+2
  lda player_x
  sta OAM_BUF+3

  ; TR
  lda player_y
  sta OAM_BUF+4
  lda #$02
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
  lda #$03
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
  lda #$04
  sta OAM_BUF+13
  lda tmp4
  sta OAM_BUF+14
  lda player_x
  clc
  adc #$08
  sta OAM_BUF+15

  ; ----------------------------
  ; Bullets (sprite start at 5 )
  ; ----------------------------

  .if DEBUG_DRAW_TEST
  lda debug_mode        ; or your draw-test flag, whichever you use
  ; e.g. if debug_mode != 0 and you're doing spawn-cycling, skip drawing bullets
  bne @skip_bullets
.endif

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
  lda #$05          ; <-- BULLET TILE ID 
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
  lda #ENEMY_E_S_TL
  sta tmp0
  lda #ENEMY_E_S_TR
  sta tmp1
  lda #ENEMY_E_S_BL
  sta tmp2
  lda #ENEMY_E_S_BR
  sta tmp3
  jmp @ene_draw_2x2

@e_normal:
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
; Phase 0: TL TR BL BR  (your original order)
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
  lda #ENEMY_B_TILE
  bne @tile_done_1
@tile_A_1:
  lda #ENEMY_A_TILE
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
; DrawTestSprite (DEBUG)
; - Single sprite used to sanity-check OAM rendering
; ------------------------------------------------------------
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
; - Digits are tiles DIGIT_TILE_BASE + 0..9
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
  adc #DIGIT_TILE_BASE
  jsr _DrawBannerChar

  ; ones = tmp0 - 10  (0..9)
  lda tmp0
  sec
  sbc #$0A
  clc
  adc #DIGIT_TILE_BASE
  jsr _DrawBannerChar
  rts

@one_digit:
  lda tmp0
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
rts

; -------------------------------------------------------------
; Boss Render
; -------------------------------------------------------------

; ------------------------------------------------------------
; DrawBossSprites4x4_TEMP
; - TEMP test: draws boss as a 4x4 metasprite (16 sprites)
; - Assumes boss_x/boss_y are top-left
; - MUST NOT touch $E0..$EF (fixed boss bullet slots)
; ------------------------------------------------------------
DrawBossSprites4x4_TEMP:
  lda boss_alive
  bne :+
    rts
:

  ; ---- OAM safety guard ----
  ; need 64 bytes, and must stay below $E0
  ; last safe start: $E0 - $40 = $A0
  cpy #$A0
  bcc :+
    rts
:

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



  ; ============================
  ; Row 0: y + 0
  ; ============================
  lda boss_y
  sta OAM_BUF,y
  iny
  lda #BOSS_00
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  sta OAM_BUF,y
  iny

  lda boss_y
  sta OAM_BUF,y
  iny
  lda #BOSS_01
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  lda boss_y
  sta OAM_BUF,y
  iny
  lda #BOSS_02
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$10
  sta OAM_BUF,y
  iny

  lda boss_y
  sta OAM_BUF,y
  iny
  lda #BOSS_03
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$18
  sta OAM_BUF,y
  iny

  ; ============================
  ; Row 1: y + 8
  ; ============================
  lda boss_y
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #BOSS_04
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #BOSS_05
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #BOSS_06
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$10
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #BOSS_07
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$18
  sta OAM_BUF,y
  iny

  ; ============================
  ; Row 2: y + 16
  ; ============================
  lda boss_y
  clc
  adc #$10
  sta OAM_BUF,y
  iny
  lda #BOSS_08
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$10
  sta OAM_BUF,y
  iny
  lda #BOSS_09
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$10
  sta OAM_BUF,y
  iny
  lda #BOSS_0A
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$10
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$10
  sta OAM_BUF,y
  iny
  lda #BOSS_0B
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$18
  sta OAM_BUF,y
  iny

  ; ============================
  ; Row 3: y + 24
  ; ============================
  lda boss_y
  clc
  adc #$18
  sta OAM_BUF,y
  iny
  lda #BOSS_0C
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$18
  sta OAM_BUF,y
  iny
  lda #BOSS_0D
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$08
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$18
  sta OAM_BUF,y
  iny
  lda #BOSS_0E
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$10
  sta OAM_BUF,y
  iny

  lda boss_y
  clc
  adc #$18
  sta OAM_BUF,y
  iny
  lda #BOSS_0F
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  clc
  adc #$18
  sta OAM_BUF,y
  iny

  rts

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
  lda #BOSS_TL
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
  lda #BOSS_TM
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
  lda #BOSS_TR
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
  lda #BOSS_ML
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
  lda #BOSS_MM
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
  lda #BOSS_MR
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
  lda #BOSS_BL
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
  lda #BOSS_BM
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
  lda #BOSS_BR
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
  cpy #$FC
  bcs @done

  lda bossbul_y,x
  sta OAM_BUF,y
  iny

  lda #BOSS_BULLET_TILE
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

  lda #$05              ; tile
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


DrawTutorialBG:
  ; LINE 1: "AVOID ENEMIES" (13 chars)
  lda PPUSTATUS
  lda #TUT_NT_HI
  sta PPUADDR
  lda #TUT_LINE1_LO
  sta PPUADDR

  lda #TILE_A
  sta PPUDATA
  lda #TILE_V
  sta PPUDATA
  lda #TILE_O
  sta PPUDATA
  lda #TILE_I
  sta PPUDATA
  lda #TILE_D
  sta PPUDATA
  lda #$00
  sta PPUDATA          ; space
  lda #TILE_E
  sta PPUDATA
  lda #TILE_N
  sta PPUDATA
  lda #TILE_E
  sta PPUDATA
  lda #TILE_M
  sta PPUDATA
  lda #TILE_I
  sta PPUDATA
  lda #TILE_E
  sta PPUDATA
  lda #TILE_S
  sta PPUDATA

  ; LINE 2: "CATCH CORES" (11 chars)
  lda PPUSTATUS
  lda #TUT_NT_HI
  sta PPUADDR
  lda #TUT_LINE2_LO
  sta PPUADDR

  lda #TILE_C
  sta PPUDATA
  lda #TILE_A
  sta PPUDATA
  lda #TILE_T
  sta PPUDATA
  lda #TILE_C
  sta PPUDATA
  lda #TILE_H
  sta PPUDATA
  lda #$00
  sta PPUDATA          ; space
  lda #TILE_C
  sta PPUDATA
  lda #TILE_O
  sta PPUDATA
  lda #TILE_R
  sta PPUDATA
  lda #TILE_E
  sta PPUDATA
  lda #TILE_S
  sta PPUDATA

  rts


  ClearTutorialBG:
  ; clear line 1 (13)
  lda PPUSTATUS
  lda #TUT_NT_HI
  sta PPUADDR
  lda #TUT_LINE1_LO
  sta PPUADDR

  ldx #13
  lda #$00
@c1:
  sta PPUDATA
  dex
  bne @c1

  ; clear line 2 (11)
  lda PPUSTATUS
  lda #TUT_NT_HI
  sta PPUADDR
  lda #TUT_LINE2_LO
  sta PPUADDR

  ldx #11
  lda #$00
@c2:
  sta PPUDATA
  dex
  bne @c2

  rts



; ------------------------------------------------------------
; ClearBossHPBG (VBlank)
; - Writes blank tiles over the boss HP bar region
; - Called from NMI when boss_hp_clear_pending=1
; ------------------------------------------------------------
ClearBossHPBG:
  lda PPUSTATUS
  lda #BOSSBAR_NT_HI
  sta PPUADDR
  lda #BOSSBAR_NT_LO
  sta PPUADDR

  ldx #BOSSBAR_LEN
  lda #BOSSBAR_EMPTY      ; usually $00
@loop:
  sta PPUDATA
  dex
  bne @loop
rts

; ------------------------------------------------------------
; WriteBossHPBarBG (VBlank)
; - Percent-scaled boss HP bar
; - 16 tiles wide (BOSSBAR_LEN)
; ------------------------------------------------------------
WriteBossHPBarBG:
  lda PPUSTATUS
  lda #BOSSBAR_NT_HI
  sta PPUADDR
  lda #BOSSBAR_NT_LO
  sta PPUADDR

  ; If hp_max = 0, avoid divide-by-zero: show empty
  lda boss_hp_max
  bne :+
    lda #$00
    sta tmp0          ; filled_tiles = 0
    jmp @draw
:

  ; Compute filled_tiles in tmp0:
  ; tmp0 = floor(boss_hp * 16 / boss_hp_max)
  ; We'll do: numerator = boss_hp << 4  (0..(255*16))
  ; Use 16-bit numerator in tmp2:tmp1 (lo:hi)
  lda boss_hp
  sta tmp1
  lda #$00
  sta tmp2
  ; shift left 4 (16x)
  asl tmp1
  rol tmp2
  asl tmp1
  rol tmp2
  asl tmp1
  rol tmp2
  asl tmp1
  rol tmp2

  ; quotient in tmp0
  lda #$00
  sta tmp0

@div_loop:
  ; while (numerator >= boss_hp_max) { numerator -= boss_hp_max; tmp0++; }
  lda tmp2
  bne @can_sub        ; if high byte nonzero, definitely >=
  lda tmp1
  cmp boss_hp_max
  bcc @div_done

@can_sub:
  lda tmp1
  sec
  sbc boss_hp_max
  sta tmp1
  lda tmp2
  sbc #$00
  sta tmp2
  inc tmp0
  jmp @div_loop

@div_done:
  ; clamp to 16 (just in case)
  lda tmp0
  cmp #BOSSBAR_LEN
  bcc :+
    lda #BOSSBAR_LEN
    sta tmp0
:

@draw:
  ldx #$00
@loop:
  cpx #BOSSBAR_LEN
  bcs @done

  txa
  cmp tmp0
  bcc @filled

@empty:
  lda #BOSSBAR_EMPTY
  sta PPUDATA
  inx
  bne @loop

@filled:
  lda #BOSSBAR_TILE
  sta PPUDATA
  inx
  bne @loop

@done:
  rts


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

HUD_Init:
  ; init high score digits to 00000 (once per boot; or keep across runs)
  lda hi_d0
  ora hi_d1
  ora hi_d2
  ora hi_d3
  ora hi_d4
  bne :+
    lda #$00
    sta hi_d0
    sta hi_d1
    sta hi_d2
    sta hi_d3
    sta hi_d4
:

  lda #$01
  sta hud_dirty
  rts

HUD_MarkDirty:
  lda #$01
  sta hud_dirty
  rts

; ============================================================
; HUD (BG TILE UI)
;
; Flow:
;   - Gameplay sets hud_dirty=1 whenever score/lives changes.
;   - NMI calls HUD_NMI_Update when hud_dirty is set.
;   - HUD_NMI_Update writes digits + hearts into the HUD nametable region.
; ============================================================

; ------------------------------------------------------------
; HUD_NMI_Update (VBlank)
; - Writes HUD text + digits + hearts as BG tiles
; - Runs only when hud_dirty=1
; - Always resets scroll latch after VRAM writes
; ------------------------------------------------------------
HUD_NMI_Update:
  lda hud_dirty
  bne :+
  rts
:
  lda #$00
  sta hud_dirty

  ; ---------- write "HI " ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_HI_LO
  sta PPUADDR

  lda #TILE_H
  sta PPUDATA
  lda #TILE_I
  sta PPUDATA
  lda #$00          ; space
  sta PPUDATA

  ; ---------- write HI digits (5) ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_HI_DIG_LO
  sta PPUADDR

  lda hi_d0
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  lda hi_d1
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  lda hi_d2
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  lda hi_d3
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  lda hi_d4
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA

  ; ---------- write "SC " ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_SC_LO
  sta PPUADDR

  lda #TILE_S
  sta PPUDATA
  lda #TILE_C
  sta PPUDATA
  lda #$00          ; space
  sta PPUDATA

  ; ---------- write SCORE digits (5) ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_SC_DIG_LO
  sta PPUADDR

  lda score_d0
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  lda score_d1
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  lda score_d2
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  lda score_d3
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA
  lda score_d4
  clc
  adc #DIGIT_TILE_BASE
  sta PPUDATA

   ; ---------- write lives hearts (HUD_MAX_LIVES) with spaces ----------
  lda PPUSTATUS
  lda #HUD_NT_HI
  sta PPUADDR
  lda #HUD_LIVES_LO
  sta PPUADDR

  lda lives
  cmp #HUD_MAX_LIVES
  bcc :+
    lda #HUD_MAX_LIVES
:
  sta tmp0


  ldx #$00              ; X = heart index (0..HUD_MAX_LIVES-1)
@heart_loop:
  cpx #HUD_MAX_LIVES
  bcs @hearts_done

  ; if (lives > X) draw heart else blank
  lda tmp0              ; A = lives
  cmp #$01              ; (optional micro-guard; can remove)
  ; not needed, keep going

  lda tmp0
  cpx tmp0              ; can't compare X to mem directly on 6502, so do it this way:
  ; ---- do: A=lives; compare to (X+1) ----
  ; We'll compute (X+1) in A2:
  ; (Simpler approach below)

  ; --- simpler: compute (X+1) into A and compare lives ---
  txa
  clc
  adc #$01              ; A = X+1
  sta tmp1              ; tmp1 = X+1

  lda tmp0              ; A = lives
  cmp tmp1              ; lives >= (X+1) ?
  bcc @blank

  lda #HEART_TILE
  bne @write

@blank:
  lda #$00

@write:
  sta PPUDATA           ; write heart/blank

  ; space after each heart except the last
  inx
  cpx #HUD_MAX_LIVES
  beq @heart_loop       ; last one: no trailing space

  lda #$00
  sta PPUDATA
  jmp @heart_loop

@hearts_done:
  ; continue HUD_NMI_Update...

rts



UpdateHighScoreIfNeeded:
  ; if score > highscore, copy score_d* -> hi_d*
  lda score_d0
  cmp hi_d0
  bcc @no
  bne @yes

  lda score_d1
  cmp hi_d1
  bcc @no
  bne @yes

  lda score_d2
  cmp hi_d2
  bcc @no
  bne @yes

  lda score_d3
  cmp hi_d3
  bcc @no
  bne @yes

  lda score_d4
  cmp hi_d4
  bcc @no
  ; equal or greater => if equal, no need, if greater here it’s “equal” case
  beq @no

@yes:
  lda score_d0
  sta hi_d0
  lda score_d1
  sta hi_d1
  lda score_d2
  sta hi_d2
  lda score_d3
  sta hi_d3
  lda score_d4
  sta hi_d4
  jsr HUD_MarkDirty
@no:
  rts


; ------------------------------------------------------------
; DrawStarfieldNT0  ($2000 tile area only) 32x30 = 960 bytes
; ------------------------------------------------------------
; ZP temps needed:
;   tmp0 = random byte
;   tmp2 = row counter

DrawStarfieldNT0:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$1E          ; 30 rows
  sta tmp2

@row:
  ldy #$20          ; 32 columns
@col:
  jsr NextRand
  sta tmp0

  lda tmp0
  and #$1F          ; 1/32 chance of star
  bne @empty

    lda tmp0
    eor rng_hi
    and #$03
    tax
    lda StarTiles,x
    jmp @write



@empty:
  lda #$00          ; blank tile

@write:
  sta PPUDATA
  dey
  bne @col

  dec tmp2
  bne @row

  lda PPUSTATUS
  rts






; ------------------------------------------------------------
; DrawStarfieldNT1  ($2400 tile area only) 32x30 = 960 bytes
; ------------------------------------------------------------
DrawStarfieldNT1:
  lda PPUSTATUS
  lda #$24
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$1E
  sta tmp2

@row:
  ldy #$20
@col:
  jsr NextRand
  sta tmp0

  lda tmp0
  and #$1F
  bne @empty

    lda tmp0
    and #$03
    tax
    lda StarTiles,x
    jmp @write

@empty:
  lda #$00

@write:
  sta PPUDATA
  dey
  bne @col

  dec tmp2
  bne @row

  lda PPUSTATUS
  rts






















; ----------------------------
; VECTORS
; ----------------------------
.segment "VECTORS"
  .word NMI
  .word RESET
  .word IRQ

; ----------------------------
; [CHR] (8KB)
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
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $18,$24,$42,$66,$81,$FF,$A5,$5A


; Tile $07 Enemy A (multicolor: outline=index1, body=index2, core=index3)

; plane 0 (outline mask + core)
.byte $18,$24,$42,$42,$81,$BD,$99,$42

; plane 1 (body silhouette + core)
.byte $18,$24,$42,$66,$81,$FF,$A5,$5A



; Tile $08 Enemy B single color
.byte $00,$00,$00,$00,$00,$00,$00,$00
.byte $38,$44,$44,$54,$FE,$FE,$54,$92

; Tile $09 Enemy B (multicolor: outline=index1, body=index2, core=index3)

; plane 0 (outline mask + core)
.byte $28,$44,$44,$54,$C6,$C6,$54,$82

; plane 1 (body silhouette + core)
.byte $38,$44,$44,$54,$FE,$FE,$54,$92



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

; Tile $23 'U'
.byte $66,$66,$66,$66,$66,$66,$3C,$00
.byte $66,$66,$66,$66,$66,$66,$3C,$00


; Tile $24 'S'
.byte $3E,$60,$60,$3C,$06,$06,$7C,$00
.byte $3E,$60,$60,$3C,$06,$06,$7C,$00

; Tile $25 'D'
.byte $7C,$66,$66,$66,$66,$66,$7C,$00
.byte $7C,$66,$66,$66,$66,$66,$7C,$00

; Tile $26 'T'
.byte $7E,$18,$18,$18,$18,$18,$18,$00
.byte $7E,$18,$18,$18,$18,$18,$18,$00

; Tile $27 'L'
.byte $60,$60,$60,$60,$60,$60,$7E,$00
.byte $60,$60,$60,$60,$60,$60,$7E,$00

; Tile $28 Heart (both planes same => color 3)
.byte %00000000
.byte %01100110
.byte %11111111
.byte %11111111
.byte %11111111
.byte %01111110
.byte %00111100
.byte %00011000

.byte %00000000
.byte %01100110
.byte %11111111
.byte %11111111
.byte %11111111
.byte %01111110
.byte %00111100
.byte %00011000

; Tile $29 'H'
.byte $66,$66,$66,$7E,$66,$66,$66,$00
.byte $66,$66,$66,$7E,$66,$66,$66,$00

; Tile $2A 'I'
.byte $3C,$18,$18,$18,$18,$18,$3C,$00
.byte $3C,$18,$18,$18,$18,$18,$3C,$00

; Tile $2B 'C'
.byte $3C,$66,$60,$60,$60,$66,$3C,$00
.byte $3C,$66,$60,$60,$60,$66,$3C,$00

; ------------------------------------
; Star variants
; ------------------------------------

; Tile $2C 'Dot'  (make the dot pixel BRIGHT)
; P0 (low bit)
.byte $00,$00,$00,$08,$00,$00,$00,$00
; P1 (high bit)
.byte $00,$00,$00,$08,$00,$00,$00,$00


; Tile $2D 'plus star'  (bright center only)
; P0
.byte $00,$00,$08,$1C,$08,$00,$00,$00
; P1
.byte $00,$00,$00,$08,$00,$00,$00,$00


; Tile $2E 'diamond'  (bright “side points” row only)
; P0
.byte $00,$00,$08,$14,$08,$00,$00,$00
; P1
.byte $00,$00,$00,$14,$00,$00,$00,$00


; Tile $2F 'bright cross'  (bright core, dim outer arms)
; P0
.byte $00,$08,$08,$3E,$08,$08,$00,$00
; P1
.byte $00,$00,$08,$1C,$08,$00,$00,$00


; -------------------------------------
; Catch Objects
; -------------------------------------

; Tile $30 'core block'
; Solid square with bright center
.byte %00000000
.byte %00111100
.byte %00111100
.byte %00111100
.byte %00111100
.byte %00111100
.byte %00000000
.byte %00000000

; Bright core (center mass)
.byte %00000000
.byte %00000000
.byte %00011000
.byte %00011000
.byte %00011000
.byte %00000000
.byte %00000000
.byte %00000000

; Tile $31 'Fractured Core'
; Hollowing begins, structure remains
.byte %00000000
.byte %00111100
.byte %00100010
.byte %00101110
.byte %00100010
.byte %00111100
.byte %00000000
.byte %00000000

; Brightness leaking upward
.byte %00000000
.byte %00011000
.byte %00001000
.byte %00001000
.byte %00001000
.byte %00000000
.byte %00000000
.byte %00000000

; Tile $32 'Final Object'
; Empty frame
.byte %00000000
.byte %00111100
.byte %00100010
.byte %00100010
.byte %00100010
.byte %00111100
.byte %00000000
.byte %00000000

; Only the top edge remains bright
.byte %00000000
.byte %00111100
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000
.byte %00000000


; boss tiles appended (9 tiles)
.include "src/boss_tiles.inc"


; ------------------------------------------------------------
; Enemy C (16x16) — tiles $3C-$3F (4 tiles)
; 2bpp sprite tiles: plane0(8) then plane1(8)
; Index meanings (suggested):
;   0=transparent, 1=outline, 2=body, 3=core
; ------------------------------------------------------------

; Tile $3C EnemyC_TL
.byte $30,$4C,$AC,$BF,$BF,$4C,$2C,$1C   ; plane 0
.byte $0C,$32,$52,$40,$40,$32,$12,$00   ; plane 1

; Tile $3D EnemyC_TR
.byte $0C,$32,$35,$FD,$FD,$32,$34,$38   ; plane 0
.byte $30,$4C,$4A,$02,$02,$4C,$48,$00   ; plane 1

; Tile $3E EnemyC_BL
.byte $1C,$2C,$4C,$BF,$BF,$AC,$4C,$30   ; plane 0
.byte $00,$12,$32,$40,$40,$52,$32,$0C   ; plane 1

; Tile $3F EnemyC_BR
.byte $38,$34,$32,$FD,$FD,$35,$32,$0C   ; plane 0
.byte $00,$48,$4C,$02,$02,$4A,$4C,$30   ; plane 1


; ============================================================
; Enemy D — 3 test variants (each 16x16 = 4 tiles)
; Tiles:
;   D1 Spear     = $40-$43
;   D2 Kite Wasp = $44-$47
;   D3 Hook      = $48-$4B
; Each tile: 8 bytes plane0, then 8 bytes plane1
; ============================================================

; ------------------------------------------------------------
; D1: “Swaying Spear” ($40-$43)
; ------------------------------------------------------------

; Tile $40 D1_TL
.byte $01,$03,$02,$02,$06,$06,$03,$03   ; p0
.byte $00,$00,$01,$01,$09,$09,$01,$01   ; p1

; Tile $41 D1_TR
.byte $80,$C0,$40,$40,$40,$40,$C0,$C0   ; p0
.byte $00,$00,$80,$80,$80,$80,$80,$80   ; p1

; Tile $42 D1_BL
.byte $02,$02,$02,$02,$06,$02,$01,$00   ; p0
.byte $01,$01,$01,$01,$09,$01,$00,$00   ; p1

; Tile $43 D1_BR
.byte $60,$60,$40,$40,$40,$40,$80,$00   ; p0
.byte $90,$90,$80,$80,$80,$80,$00,$00   ; p1


; ------------------------------------------------------------
; D2: “Kite Wasp” ($44-$47)
; ------------------------------------------------------------

; Tile $44 D2_TL
.byte $00,$01,$02,$05,$19,$10,$20,$40   ; p0
.byte $00,$00,$01,$03,$27,$2F,$1F,$3F   ; p1

; Tile $45 D2_TR
.byte $00,$80,$40,$A0,$90,$08,$08,$0A   ; p0
.byte $00,$00,$80,$C0,$E0,$F0,$F4,$F4   ; p1

; Tile $46 D2_BL
.byte $80,$10,$08,$04,$02,$01,$01,$00   ; p0
.byte $7F,$0F,$07,$03,$01,$00,$00,$00   ; p1

; Tile $47 D2_BR
.byte $01,$08,$10,$20,$40,$80,$80,$00   ; p0
.byte $FE,$F0,$E0,$C0,$80,$00,$00,$00   ; p1


; ------------------------------------------------------------
; D3: “Hook / Harpoon” ($48-$4B)
; ------------------------------------------------------------

; Tile $48 D3_TL
.byte $00,$00,$02,$02,$02,$02,$02,$02   ; p0
.byte $00,$00,$01,$01,$01,$01,$01,$01   ; p1

; Tile $49 D3_TR
.byte $00,$00,$40,$08,$40,$40,$40,$40   ; p0
.byte $00,$00,$80,$F0,$80,$80,$80,$80   ; p1

; Tile $4A D3_BL
.byte $02,$02,$02,$02,$02,$02,$00,$00   ; p0
.byte $01,$01,$01,$01,$01,$01,$00,$00   ; p1

; Tile $4B D3_BR
.byte $40,$40,$40,$7E,$06,$04,$00,$00   ; p0
.byte $80,$80,$80,$86,$FE,$F8,$00,$00   ; p1


; ------------------------------------------------------------
; Enemy E (16x16) — tiles $4C-$4F (4 tiles)
; Heavy armored pod w/ bright core
; ------------------------------------------------------------

; Tile $4C EnemyE_TL
.byte $00,$3F,$40,$5F,$50,$50,$53,$53   ; plane 0
.byte $00,$00,$3F,$20,$2F,$23,$2F,$2F   ; plane 1

; Tile $4D EnemyE_TR
.byte $00,$FC,$02,$FA,$0A,$02,$CA,$CA   ; plane 0
.byte $00,$00,$FC,$04,$F4,$E4,$F4,$F4   ; plane 1

; Tile $4E EnemyE_BL
.byte $53,$53,$50,$50,$5F,$4A,$3F,$00   ; plane 0
.byte $2F,$2F,$23,$2F,$20,$35,$00,$00   ; plane 1

; Tile $4F EnemyE_BR
.byte $CA,$CA,$02,$0A,$FA,$AA,$FC,$00   ; plane 0
.byte $F4,$F4,$E4,$F4,$04,$54,$00,$00   ; plane 1


; ------------------------------------------------------------
; Enemy E (SHIELDED - DISTINCT) — tiles $50-$53
; Adds bright “energy ring” accents (color 3) around shell
; ------------------------------------------------------------

; Tile $50 EnemyE_Shield_TL
.byte $00,$3F,$40,$5F,$50,$50,$53,$53   ; p0
.byte $00,$00,$3F,$2F,$3F,$2F,$3F,$3F   ; p1  (more bright on rim)

; Tile $51 EnemyE_Shield_TR
.byte $00,$FC,$02,$FA,$0A,$02,$CA,$CA   ; p0
.byte $00,$00,$FC,$F4,$FC,$F4,$FC,$FC   ; p1

; Tile $52 EnemyE_Shield_BL
.byte $53,$53,$50,$50,$5F,$4A,$3F,$00   ; p0
.byte $3F,$3F,$2F,$3F,$2F,$3F,$3F,$00   ; p1

; Tile $53 EnemyE_Shield_BR
.byte $CA,$CA,$02,$0A,$FA,$AA,$FC,$00   ; p0
.byte $FC,$FC,$F4,$FC,$F4,$FC,$FC,$00   ; p1

; Tile $54 'N'
.byte $66,$76,$7E,$6E,$66,$66,$66,$00
.byte $66,$76,$7E,$6E,$66,$66,$66,$00

  .res 8192-1360, $00

