; ============================================================
; main_.s — Starfall / Spacefall shooter (ca65)
;
;   1) Constants / Tiles / UI strings
;   2) Memory (ZEROPAGE + BSS)
;   3) Data tables (Palettes, LevelParams)
;   4) RESET + MainLoop state machine
;   5) NMI (vblank work: OAM DMA, BG text toggles, HUD, boss bar)
;   6) Core systems: input, player, bullets, enemies, collisions, HUD, boss
;   7) RNG + debug helpers
;   8) VECTORS + CHR
;
; ============================================================
;
; ============================================================
; RELEASE HARDENING / MAINTENANCE NOTES
;
; Quick checklist before you call a build “release”:
;   [ ] DEBUG_DRAW_TEST disabled (0)
;   [ ] debug_mode forced-off by default (0) and not set via input
;   [ ] Any “test sprite” / “test spawn” code paths unreachable
;   [ ] HUD + boss bar VRAM writes ONLY happen in NMI (vblank)
;   [ ] All sprites outside visible use Y=$FE (no stray junk OAM)
;   [ ] RNG is never all-zero (rng_hi|rng_lo != 0)
;
; Suggested convention going forward:
;   - Put all tunable gameplay constants (speeds, cooldowns, timers) in one place.
;   - Prefer named constants over magic numbers in logic-heavy routines.
;   - Keep debug hooks fenced behind DEBUG_* flags or a single DEBUG define.
; ============================================================

; ============================================================
; CONSTANTS + TILE MAP + UI LAYOUT
; (Keep this section “dumb”: equates only, no code.)
; ============================================================

; ------------------------------------------------------------
; NES hardware registers
; ------------------------------------------------------------
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007

OAMDMA    = $4014
JOY1      = $4016

; ----------------------------
; TUNABLES (game feel)
; ----------------------------

; Player movement (top-left of 16x16 ship)
PLAYER_MOVE_SPD_X     = $02   ; px/frame
PLAYER_MOVE_SPD_Y     = $02   ; px/frame
PLAYER_MIN_X          = $08
PLAYER_MAX_X          = $F0
PLAYER_MIN_Y          = $10
PLAYER_MAX_Y          = $D0

; Bullets
BULLET_SPD            = $05   ; px/frame upward
BULLET_KILL_Y         = $08   ; kill once bullet Y < this (top safety)
BULLET_SPAWN_Y_OFF    = $04   ; spawn at (player_y - off)

; Firing
FIRE_COOLDOWN_FR      = $06   ; frames between shots (lower = faster)
GUN_RIGHT_X_OFF       = $0C   ; right muzzle offset from player_x

INVULN_FRAMES = $30

; Enemy spawning
SPAWN_START_DELAY_FR   = $10   ; grace period before first enemy appears
LEVEL_SPAWN_CD_FR      = $18   ; base frames between spawns for a level

; Flash Screen
FLASH_HIT_FR        = $08   ; quick pop on player hit
FLASH_BOSS_START_FR = $12   ; longer / more dramatic
FLASH_LEVEL_START_FR = $06
FLASH_POWERUP_FR     = $04
FLASH_GRAY_CUTOFF = $0C   ; timers >= this use grayscale

; Boss
BOSS_X_INIT         = $78
BOSS_Y_INIT         = $30

BOSS_HP_INIT        = $10    ; 16 HP
BOSS_HIT_FLASH_FR   = $08
BOSS_FIRE_CD_FR     = $20    ; ~32 frames between shots

FLAG_SET            = $01
FLAG_CLEAR          = $00

; Boss HP bar (BG)
BOSSBAR_NT_HI   = $20
BOSSBAR_NT_LO   = $68   ; row 3, column $2068
BOSSBAR_LEN     = $10   ; 16 tiles
BOSSBAR_TILE    = $0A
BOSSBAR_EMPTY   = $00   ; empty

; Boss movement bounds (top-left position)
BOSS_MIN_X = $08
; right edge clamp = $F0 - (boss width - 8)
; for 16px boss: $F0 - $08 = $E8
BOSS_MAX_X = $E8

BOSS_MIN_Y = $18
BOSS_MAX_Y = $60

BOSS_DX_INIT = $01   ; signed 8-bit: +1
BOSS_DY_INIT = $01

; Boss bullets
BOSS_BULLET_MAX      = 4
BOSS_BULLET_SPD      = $02     ; px/frame downward
BOSS_BULLET_KILL_Y   = $E8     ; kill once bullet Y >= this
BOSS_BULLET_SPAWN_Y  = $10     ; spawn at boss_y + this
BOSS_BULLET_X_OFF    = $08     ; spawn near boss center (for 16px boss)
BOSS_BULLET_Y_OFF    = $08
BOSS_BULLET_TILE     = $05     ; TEMP: pick a visible tile you have
BOSS_BULLET_ATTR     = $01     ; palette index (match ENEMY_ATTR if you want)

BOSS_PAT_SINGLE   = $00
BOSS_PAT_SPREAD3  = $01
BOSS_PAT_AIMED3   = $02

; ============================================================
; TITLE / UI BG TILE STRINGS
; (Used by WriteTitleBG / WritePressStartBG / WriteGameOverBG)
; ============================================================

; ----------------------------
; "STARFALL" title line
; ----------------------------
TITLE_NT_HI  = $21
TITLE_NT_LO  = $8C    ; row 12, col 12  => $218C
TITLE_LEN    = 8

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


; ------------------------------------------------------------
; Star tile variants (CHR tiles $2C–$2F)
; ------------------------------------------------------------
STAR_T0 = $2C    ; tiny dot
STAR_T1 = $2D    ; plus star
STAR_T2 = $2E    ; diamond star
STAR_T3 = $2F    ; bright cross (rare)

; ------------------------------------------------------------
; Controller bits (pad1 / pad1_new)
; ------------------------------------------------------------
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

; ------------------------------------------------------------
; PPU / rendering presets
; ------------------------------------------------------------
; PPUMASK preset (BG+SPR enabled, show left 8px)
PPUMASK_BG_SPR = %00011110

; OAM shadow buffer (RAM page aligned for DMA)
OAM_BUF = $0200

; ------------------------------------------------------------
; Enemy system (generic)
; ------------------------------------------------------------
ENEMY_ATTR      = $01      ; sprite palette index
ENEMY_SPAWN_Y   = $10
ENEMY_KILL_Y    = $E0

; ------------------------------------------------------------
; Enemy types
; (A/B are 8x8. C/D/E are 16x16 (2x2 metas).)
; ------------------------------------------------------------
EN_A = $00        ; 1x1 (8x8)
EN_B = $01        ; 1x1 (8x8)
EN_C = $02        ; 2x2 (16x16)
EN_D = $03        ; 2x2 (16x16)
EN_E = $04        ; 2x2 (16x16)

; --- A/B tiles (single-tile enemies) ---
ENEMY_A_TILE_SOLID  = $06
ENEMY_A_TILE_ACCENT = $07   ; 2-tone variant
ENEMY_B_TILE_SOLID  = $08
ENEMY_B_TILE_ACCENT = $09   ; 2-tone variant

; Choose which single tile to actually use (swap to ACCENT if desired)
ENEMY_A_TILE = ENEMY_A_TILE_SOLID
ENEMY_B_TILE = ENEMY_B_TILE_SOLID

; --- C/D/E tiles (2x2 metas) ---
; NOTE: these are tile IDs, not sprite slots.
ENEMY_C_TL = $0A
ENEMY_C_TR = $0B
ENEMY_C_BL = $0C
ENEMY_C_BR = $0D

ENEMY_D_TL = $0E
ENEMY_D_TR = $0F
ENEMY_D_BL = $0E
ENEMY_D_BR = $0F

ENEMY_E_TL = $0A
ENEMY_E_TR = $0D
ENEMY_E_BL = $0C
ENEMY_E_BR = $0F

; ------------------------------------------------------------
; RNG thresholds for enemy mix (tweak later)
; ------------------------------------------------------------
THR_B = $60     ; ~37% B (96/256)
THR_E = $F0     ; TEMP: top ~6% become E (16/256)

; ------------------------------------------------------------
; HUD / text tile IDs
; ------------------------------------------------------------
DIGIT_TILE_BASE  = $10     ; 0..9 => $10..$19
LETTER_TILE_BASE = $1A     ; project-specific font mapping

; Letter tiles you currently use explicitly:
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

HEART_TILE = $28

; ------------------------------------------------------------
; HUD (BG nametable layout)
; ------------------------------------------------------------
HUD_NT_HI      = $20
HUD_HI_LO      = $22   ; row 1 col 2  ($2022)
HUD_HI_DIG_LO  = $25   ; row 1 col 5  ($2025)
HUD_SC_LO      = $42   ; row 2 col 2  ($2042) -> "SC "
HUD_SC_DIG_LO  = $45   ; row 2 col 5  ($2045) -> digits start
HUD_LIVES_LO   = $2C   ; row 1 col 12 ($202C)

HUD_MAX_LIVES = 10      ; 

; ------------------------------------------------------------
; Sprite text overlays (score + game over + banner)
; ------------------------------------------------------------
SCORE_OAM   = $EC    ; sprite #59 = 59*4
SCORE_Y     = $08
SCORE_X0    = $08
SCORE_ATTR  = $00

GAMEOVER_OAM  = $A0   ; sprite #40 * 4
GAMEOVER_Y    = $70
GAMEOVER_X0   = $48
GAMEOVER_ATTR = $00

BANNER_OAM   = $80    ; sprite #32 * 4
BANNER_Y     = $58
BANNER_X0    = $64    ; centered-ish for 7 chars (56px wide)
BANNER_ATTR  = $00


; ------------------------------------------------------------
; Boss
; ------------------------------------------------------------
BOSS_OAM  = $60          ; sprite #24 (24*4)
BOSS_ATTR = $02          ; sprite palette 2

BOSS_W = $10
BOSS_H = $10

; boss metasprite tiles (2x2)
BOSS_TL = $0E
BOSS_TR = $0F
BOSS_BL = $0E
BOSS_BR = $0F

; STAR_TILE = $0A

; Game States
STATE_BANNER = $00
STATE_PLAY   = $01
STATE_BOSS   = $02
STATE_OVER   = $03
STATE_TITLE  = $04
STATE_PAUSE = $05   ; pick an unused value

; ----------------------------
; Catch object (Core Block)
; ----------------------------
CATCH_SPAWN_Y      = $10
CATCH_KILL_Y       = $E8        ; off bottom
CATCH_SPD          = $01        ; pixels per frame
CATCH_SPAWN_MIN    = 90         ; frames
CATCH_SPAWN_VAR    = 90         ; +0..89 => 90..179

CATCH_TILE_CORE    = $30        ; new tile index
CATCH_ATTR         = $02        ; use sprite palette 1

; If player is 16x16 metasprite:
PLAYER_W = 16
PLAYER_H = 16

; Catch is 8x8 tile:
CATCH_W  = 8
CATCH_H  = 8

CATCH_OAM_BASE = $A0   ; sprite #40
CATCH_MAX      = 4     ; 


JAM_FR = 60        ; 1 second at 60fps (tweak)

; ----------------------------
; TUNING DEFAULTS (fallbacks)
; ----------------------------
ENEMY_SPAWN_BASE   = 36      ; frames
CATCH_SPAWN_BASE   = 300     ; frames
JAM_FRAMES_BASE    = 60      ; frames (pick 60 to start)
CATCH_LIFE_BASE    = 240     ; frames (~4 seconds at 60fps)


; ------------------------------------------------------------
; Debug toggles (compile-time)
; ------------------------------------------------------------
DEBUG_DRAW_TEST = 0      ; set to 0 to disable

DEBUG_BOSS_SKIP = 1     ; set to 0 to compile out boss-skip hotkey
BTN_SELECT_START = (BTN_SELECT | BTN_START)

; ----------------------------
; iNES header
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
; ------------------------------------------------------------
; ZEROPAGE (fast access)
; Keep frequently-touched state here: frame sync, input, UI flags, scratch.
; ------------------------------------------------------------
title_inited:         .res 1

paused_prev_state: .res 1   ; stores what you paused from (usually PLAY)
pause_inited:      .res 1   ; one-time draw for overlay (optional)

; ---- Frame sync / input ----
nmi_ready:            .res 1
frame_lo:             .res 1
frame_hi:             .res 1
pad1:                 .res 1
pad1_prev:            .res 1
pad1_new:             .res 1


; ---- Title / UI state (BG toggles) ----
first_run:            .res 1   ; 0 = not started yet, 1 = started
press_visible:        .res 1   ; 0=hidden, 1=shown (BG)
title_visible:        .res 1   ; 0=hidden, 1=shown (BG)
gameover_visible:     .res 1   ; 0=hidden, 1=shown (BG)
gameover_blink_timer: .res 1   ; counts down frames after entering OVER
gameover_blink_phase: .res 1   ; 0=not blinking / finished, 1=in blink sequence
screen_flash_timer:   .res 1   ; 0=off, >0 flash running
boss_hp_clear_pending: .res 1   ; 0=no, 1=yes

draw_test_active:     .res 1   ; 1 = freeze enemies and show test set

; ---- One-shot / debug flow flags ----
draw_test_done:       .res 1   ; 1 = already spawned once this run


; ---- Scratch (temps) ----
; NOTE: These are shared across routines. Avoid relying on them across JSR boundaries
; unless you document it locally. When adding new code, prefer tmp3/tmp4 last so you
; don’t accidentally clobber something older.
tmp:                  .res 1      ; general-purpose scratch (A/B temp)
tmp0:                 .res 1     ; scratch: often loop counter / retry counter
tmp1:                 .res 1     ; scratch: often X/Y working value
tmp2:                 .res 1     ; scratch: often speed/threshold in collisions
tmp3:                 .res 1     ; scratch: spare
tmp4:                 .res 1     ; scratch: spare


; ---- Debug controls ----
debug_force_type: .res 1   ; $FF = off, otherwise EN_A..EN_E
debug_mode: .res 1   ; 0=normal, 1=A, 2=B, 3=C, 4=D, 5=E

; ---- enemy spawns ----
spawn_cd:         .res 1
level_enemy_cd:   .res 1

; ---- catch spawns ----
catch_cd:         .res 1
level_catch_cd:   .res 1

; ---- jam + catch lifetime ----
jam_timer:        .res 1
level_jam_frames: .res 1

catch_life_timer: .res 1
level_catch_life: .res 1
catch_active:     .res 1   ; 0/1 (or reuse your actor alive flag)


; ----------------------------
; BSS
; ----------------------------
.segment "BSS"
; ------------------------------------------------------------
; BSS (RAM)
; Arrays and longer-lived state live here.
; ------------------------------------------------------------

; ---- Gameplay core state ----

; ---- Game state machine ----
game_state:       .res 1

; ---- Player ----
player_x:         .res 1
player_y:         .res 1
player_cd:        .res 1    ; fire cooldown
; bullets (N slots)
BULLET_MAX = 4
bul_alive:        .res BULLET_MAX
bul_x:            .res BULLET_MAX
bul_y:            .res BULLET_MAX
bul_y_prev:       .res BULLET_MAX

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


; ---- Spawning ----

; enemies (N slots)
ENEMY_MAX = 5    ; number of concurrent enemy slots (arrays below)

; ---- Enemies (slot arrays) ----
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

; ----------------------------
; Catch object state
; ----------------------------
catch_spawn_cd: .res 1

; --- catch objects ---
catch_alive: .res CATCH_MAX
catch_x:     .res CATCH_MAX
catch_y:     .res CATCH_MAX
catch_type:  .res CATCH_MAX   ; if you have it
catch_tile:  .res CATCH_MAX   ; <-- NEW: tile id per catch object
catch_attr:  .res CATCH_MAX   ; <-- optional: per-object palette/flip


; Level control vars
level_idx:       .res 1
level_spawn_cd:  .res 1
level_enemy_spd: .res 1
level_thrB:      .res 1
level_thrC:      .res 1
level_thrD:      .res 1
level_thrE:      .res 1

boss_time_lo:    .res 1
boss_time_hi:    .res 1

; Boss
boss_timer_lo:   .res 1
boss_timer_hi:   .res 1
level_banner:    .res 1    ; frames remaining to show "LEVEL X"

; Boss

; ---- Boss ----
boss_alive:      .res 1
boss_x:          .res 1
boss_y:          .res 1
boss_hp:         .res 1
boss_hp_max:     .res 1
boss_hp_dirty:   .res 1
boss_flash:      .res 1        ; frames remaining for hit flash
boss_fire_cd:    .res 1        ; cooldown to shoot

boss_dx: .res 1
boss_dy:  .res 1

; Boss bullets (slot arrays)
bossbul_alive:   .res BOSS_BULLET_MAX
bossbul_x:       .res BOSS_BULLET_MAX
bossbul_y:       .res BOSS_BULLET_MAX
bossbul_y_prev:  .res BOSS_BULLET_MAX

bossbul_dx:  .res BOSS_BULLET_MAX   ; signed
bossbul_dy:  .res BOSS_BULLET_MAX   ; unsigned (or signed later)

boss_pattern: .res 1





; ---- HUD (BG tiles) ----
hud_dirty:      .res 1   ; 1 = update HUD in NMI

hi_d0:          .res 1
hi_d1:          .res 1
hi_d2:          .res 1
hi_d3:          .res 1
hi_d4:          .res 1

; Catch objects
gun_jam_timer: .res 1

; Level control vars (add these if you plan to use them)
level_catch_good_thr: .res 1
level_catch_cap:      .res 1
enemy_cd:             .res 1   

level_catch_cd4:      .res 1
; ----------------------------
; CODE
; ----------------------------
.segment "CODE"

; ----------------------------
; Palette data (32 bytes)
; ----------------------------
Palettes:
; BG0 Palettes
  .byte $0F, $01, $21, $30   ; BG p0: black, dark blue, light blue, white
  .byte $0F,$06,$16,$26       ; p1
  .byte $0F,$09,$19,$29       ; p2
  .byte $0F,$0C,$1C,$2C       ; p3

; SPR Palettes
; .byte $0F,$01,$16,$30       ; option C
; .byte $0F,$01,$2A,$30       ; option B

  .byte $0F,$01,$21,$30       ; p0 option A (Player Ship)
  .byte $0F,$16,$30,$30       ; p1 enemy palette
; SPR palette 2 – Catch objects
.byte $0F, $01, $21, $30
  .byte $0F,$09,$19,$29       ; p3

LEVEL_STRIDE = 12

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
; ------------------------------------------------------------
; TUNING INTUITION
; ------------------------------------------------------------
; - To make catch objects rarer:
;       ↑ catch_cd4   (fewer attempts)
;       ↓ good_thr    (lower chance per attempt)
;       ↓ catch_cap  (fewer allowed simultaneously)
;
; - To make them more generous:
;       ↓ catch_cd4
;       ↑ good_thr
;       ↑ catch_cap
;
; - good_thr controls *probability*
; - catch_cd4 controls *time*
; - catch_cap controls *screen pressure*
;
; ============================================================

; ------------------------------------------------------------
; CATCH MATH QUICK REF (with current logic)
;   attempt interval (sec) = catch_cd4 / 15
;   P(spawn per attempt)   = good_thr / 256
;   expected sec/spawn     = (catch_cd4/15) / (good_thr/256)
;                          = catch_cd4 * 256 / (15*good_thr)
;
; With good_thr = 60:
;   P = 23.4%
;   expected sec/spawn ≈ catch_cd4 * 0.284
; ------------------------------------------------------------

; ------------------------------------------------------------
; ENEMY TYPE THRESHOLDS — HOW TO READ %
; ------------------------------------------------------------
; r = random byte 0..255 (256 total values)
;
; Selection:
;   if r < thrB              -> B
;   else if r < thrC         -> C
;   else if r < thrD         -> D
;   else if thrE != 0
;        and r >= thrE       -> E
;   else                     -> A
;
; Band sizes:
;   B_count = thrB
;   C_count = thrC - thrB
;   D_count = thrD - thrC
;
;   If thrE != 0:
;     E_count = 256 - thrE
;     A_count = thrE - thrD
;   Else (thrE == 0):
;     E_count = 0
;     A_count = 256 - thrD
;
; Percent chance ≈ (count / 256) * 100
;
; Quick intuition:
;   16  ≈ 6.25%
;   32  ≈ 12.5%
;   64  ≈ 25%
;   128 ≈ 50%
;
; Example:
;   thrB=$28 (40) -> B ≈ 15.6%
;   thrC=$48 (72) -> C ≈ 12.5%
;   thrD=$58 (88) -> D ≈ 6.25%
;   thrE=$00      -> A ≈ 65.6%
; ------------------------------------------------------------


; ----- Macro: one row = one level -----
; boss_frames is a 16-bit value (in FRAMES).
.macro LEVELPARAMS spawn, spd, thrB, thrC, thrD, thrE, boss_frames, ene_cd, catch_cd4, good_thr, cap
  .byte spawn, spd, thrB, thrC, thrD, thrE, <(boss_frames), >(boss_frames), ene_cd, catch_cd4, good_thr, cap
.endmacro

; Notes:
; - thrE = $00 disables E entirely
; - boss_time is frames @60fps

; ============================================================
; % NOTES FOR THIS LEVELPARAMS TABLE
; ============================================================
; Catch:
;   attempt every (catch_cd4*4) frames  = catch_cd4/15 seconds
;   spawn chance per attempt = good_thr / 256
;   expected avg time between spawns (no cap/slots) ≈ attempt_seconds / (good_thr/256)
;
; Enemy type mix from thresholds (r=0..255):
;   B = thrB
;   C = thrC - thrB
;   D = thrD - thrC
;   if thrE=0:  A = 256 - thrD, E=0
;   if thrE!=0: A = thrE - thrD, E = 256 - thrE
;   Percent = count/256
; ============================================================

LevelParams:

; L1
; Catch: cd4=24 => 96f => 1.60s/attempt
;       good_thr=96 => 37.50% per attempt
;       expected ≈ 4.27s per successful spawn (ignoring cap/slots), cap=3
; Enemy mix (thrB=$0C thrC=$0C thrD=$0C thrE=$00):
;   A=95.31%  B=4.69%  C=0%  D=0%  E=0%
LEVELPARAMS $24, $01, $0C, $0C, $0C, $00, 7200,  36,  24, 96, 3

; L2
; Catch: cd4=26 => 104f => 1.73s/attempt
;       good_thr=88 => 34.38%
;       expected ≈ 5.04s, cap=3
; Enemy mix (thrB=$40 thrC=$40 thrD=$40 thrE=$00):
;   A=75.00%  B=25.00%  C=0%  D=0%  E=0%
LEVELPARAMS $20, $01, $40, $40, $40, $00, 7200,  36,  26, 88, 3

; L3
; Catch: cd4=28 => 112f => 1.87s/attempt
;       good_thr=80 => 31.25%
;       expected ≈ 5.97s, cap=3
; Enemy mix (thrB=$5A thrC=$5A thrD=$5A thrE=$00):
;   A=64.84%  B=35.16%  C=0%  D=0%  E=0%
LEVELPARAMS $1C, $02, $5A, $5A, $5A, $00, 9000,  32,  28, 80, 3

; L4
; Catch: cd4=30 => 120f => 2.00s/attempt
;       good_thr=72 => 28.13%
;       expected ≈ 7.11s, cap=2
; Enemy mix (thrB=$66 thrC=$76 thrD=$76 thrE=$00):
;   A=53.91%  B=39.84%  C=6.25%  D=0%  E=0%
LEVELPARAMS $1A, $02, $66, $76, $76, $00, 9000,  32,  30, 72, 2

; L5
; Catch: cd4=32 => 128f => 2.13s/attempt
;       good_thr=64 => 25.00%
;       expected ≈ 8.53s, cap=2
; Enemy mix (thrB=$3C thrC=$50 thrD=$50 thrE=$00):
;   A=68.75%  B=23.44%  C=7.81%  D=0%  E=0%
LEVELPARAMS $18, $02, $3C, $50, $50, $00, 10800, 28,  32, 64, 2

; L6
; Catch: cd4=34 => 136f => 2.27s/attempt
;       good_thr=56 => 21.88%
;       expected ≈ 10.36s, cap=2
; Enemy mix (thrB=$30 thrC=$50 thrD=$50 thrE=$00):
;   A=68.75%  B=18.75%  C=12.50%  D=0%  E=0%
LEVELPARAMS $16, $03, $30, $50, $50, $00, 10800, 28,  34, 56, 2

; L7
; Catch: cd4=36 => 144f => 2.40s/attempt
;       good_thr=48 => 18.75%
;       expected ≈ 12.80s, cap=2
; Enemy mix (thrB=$28 thrC=$48 thrD=$58 thrE=$00):
;   A=65.63%  B=15.63%  C=12.50%  D=6.25%  E=0%
LEVELPARAMS $14, $03, $28, $48, $58, $00, 12600, 24,  36, 48, 2

; L8
; Catch: cd4=38 => 152f => 2.53s/attempt
;       good_thr=44 => 17.19%
;       expected ≈ 14.74s, cap=2
; Enemy mix (thrB=$28 thrC=$40 thrD=$50 thrE=$00):
;   A=68.75%  B=15.63%  C=9.38%  D=6.25%  E=0%
LEVELPARAMS $12, $03, $28, $40, $50, $00, 12600, 24,  38, 44, 2

; L9
; Catch: cd4=40 => 160f => 2.67s/attempt
;       good_thr=40 => 15.63%
;       expected ≈ 17.07s, cap=2
; Enemy mix (thrB=$20 thrC=$38 thrD=$50 thrE=$00):
;   A=68.75%  B=12.50%  C=9.38%  D=9.38%  E=0%
LEVELPARAMS $10, $04, $20, $38, $50, $00, 14400, 20,  40, 40, 2

; L10
; Catch: cd4=44 => 176f => 2.93s/attempt
;       good_thr=36 => 14.06%
;       expected ≈ 20.87s, cap=1
; Enemy mix (thrB=$30 thrC=$50 thrD=$70 thrE=$F3):
;   A=51.17%  B=18.75%  C=12.50%  D=12.50%  E=5.08%
LEVELPARAMS $0F, $04, $30, $50, $70, $F3, 16200, 20,  44, 36, 1

; L11
; Catch: cd4=48 => 192f => 3.20s/attempt
;       good_thr=32 => 12.50%
;       expected ≈ 25.60s, cap=1
; Enemy mix (thrB=$27 thrC=$4D thrD=$73 thrE=$EC):
;   A=47.27%  B=15.23%  C=14.84%  D=14.84%  E=7.81%
LEVELPARAMS $0E, $04, $27, $4D, $73, $EC, 16200, 20,  48, 32, 1

; L12
; Catch: cd4=52 => 208f => 3.47s/attempt
;       good_thr=28 => 10.94%
;       expected ≈ 31.68s, cap=1
; Enemy mix (thrB=$20 thrC=$48 thrD=$78 thrE=$E0):
;   A=40.63%  B=12.50%  C=15.63%  D=18.75%  E=12.50%
LEVELPARAMS $0D, $05, $20, $48, $78, $E0, 18000, 20,  52, 28, 1


; L13 
LEVELPARAMS $24, $01, $0C, $0C, $0C, $00, 7200,  36,  24, 96, 3


StarTiles:
  .byte STAR_T0, STAR_T1, STAR_T2, STAR_T3


; ------------------------------------------------------------
; RESET
; - Hardware init
; - RAM/OAM clear
; - Initial game state
; - Enable NMI + rendering
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

lda #SPAWN_START_DELAY_FR
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

lda #$00
sta PPUCTRL
sta PPUMASK

  ; VRAM init (rendering still OFF)
  jsr WaitVBlank

  ; disable NMI (bit 7 = 0)
  lda PPUCTRL
  and #%01111111
  sta PPUCTRL

  ; align enabling rendering to vblank boundary
  jsr WaitVBlank

  ; scroll = 0,0 (clean latch)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL



 ; re-enable NMI if you use it
  lda PPUCTRL
  ora #%10000000
  sta PPUCTRL
jsr InitPalettes

  jsr PPU_BeginVRAM
  jsr ClearNametable0
  jsr DrawStarfieldNT0
  jsr ClearAttributesNT0
  jsr ClearNametable1
  jsr DrawStarfieldNT1
  jsr ClearAttributesNT1
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
MainLoop:
  jsr WaitFrame

  jsr ReadController1

; --- DEBUG input handling ---
; RELEASE NOTE: if you don’t want debug hotkeys in release, stub DebugUpdate or guard it behind a flag.
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
  cmp #STATE_BANNER
  beq @state_banner
  cmp #STATE_PLAY
  beq @state_play
  cmp #STATE_BOSS
  beq @state_boss
    cmp #STATE_PAUSE
  bne :+
    jmp @state_pause
  :

  jmp @state_over


; ----------------------------
; STATE: BANNER (LEVEL X)
; “each frame”: count down banner timer
; ----------------------------
@state_banner:
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
  ; ---- PAUSE TOGGLE ----
  lda pad1_new
  and #BTN_START
  beq :+
    lda #STATE_PLAY
    sta paused_prev_state
    lda #STATE_PAUSE
    sta game_state
    jmp @play_render_only
:

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

  lda pad1_new
  and #BTN_START
  beq :+
    lda game_state
    sta paused_prev_state
    lda #STATE_PAUSE
    sta game_state
    lda #$00
    sta pause_inited
    jmp @boss_render_only        ; skip gameplay update this frame
:

  jsr UpdatePlayer
  jsr UpdateBullets

  jsr UpdateCatch
  jsr CollidePlayerCatch
  jsr CollideBulletsCatch

  jsr BossUpdate
  jsr BossMoveBounceX
  jsr BossMoveBounceY
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

; ----------------------------
; STATE: TITLE
; - Blink PRESS START BG tiles (handled via frame counter / visibility flag)
; - Start game on START
; - Draw title sprites + any overlays
; ----------------------------
@state_title:
  jsr NextRand     ; stir RNG so “time-to-press-start” matters

  lda pad1_new
  and #BTN_START
  beq :+

    ; optional: also mix in frame counter if you have one
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
:

  jsr BuildOAM
  jmp MainLoop

@state_pause:
  lda pad1_new
  and #BTN_START
  beq :+
    lda paused_prev_state
    sta game_state

    ; optional but recommended: prevent double-trigger
    lda pad1
    sta pad1_prev
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

jsr NextRand

; ---- OAM DMA (typical) ----
  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

 

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
  bcc @done
  lda #$00
  sta debug_mode

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
;   - (If you add vertical movement later, mirror the clamp pattern)
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
  bne @done

  ; if cooldown still active, skip firing
  lda player_cd
  bne @done

  ; check fire input
  lda pad1
  and #BTN_A
  beq @done

  ; FIRE
  jsr FireBulletLR
  lda #FIRE_COOLDOWN_FR
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
  ; right gun: player_x + 12 (for a 16px ship, near right side)
  lda player_x
  clc
  adc #GUN_RIGHT_X_OFF
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

  ; jsr DrawScoreSprites
  rts


@normal_draw:

  ; ----------------------------
  ; Player metasprite (sprites 0-3)
  ; ----------------------------

  ; TL
  lda player_y
  sta OAM_BUF+0
  lda #$01
  sta OAM_BUF+1
  lda player_attr
  sta OAM_BUF+2
  lda player_x
  sta OAM_BUF+3

  ; TR
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

  ; BL
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

  ; BR
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
  ; Bullets (sprite start at 5 )
  ; ----------------------------
  ldy #$10  ; 4 * 4 = $10

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
  ; Enemies (sprites 24..)
  ; - A/B are 1x1
  ; - C/D/E are 2x2 metasprites
  ; ----------------------------
  ldy #$20   

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

  ; ---- BOSS sprites + boss bullets (boss state only) ----
  lda game_state
  cmp #STATE_BOSS
  bne @after_boss_draw

    jsr DrawBossSprites     ; uses Y as current OAM offset
    jsr DrawBossBullets_Fixed   ; sprites 56–59 ($E0..$EF)
@after_boss_draw:

  jsr DrawCatchSprites

  ; ---- banner overlay ----
  lda game_state
  cmp #STATE_BANNER
  beq @draw_banner

@hide_banner:
  jsr HideBannerSprites
  jmp @after_banner

@draw_banner:
  jsr DrawLevelBannerSprites

@after_banner:
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
; HITBOX NOTE:
;   - Rendering: some enemies are drawn as 2x2 metasprites (16x16).
;   - Collision right now treats enemies as 8x8 (top-left + 7).
;   - That mismatch is okay for gameplay feel, but if you want “true” 16x16
;     collisions later, branch on ene_type and use width/height = $0F.
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
  bne @no_slot
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
  lda #$00
  sta ene_dx,x
  lda #$08
  sta ene_timer,x
  rts

@init_E:
  lda #$00
  sta ene_dx,x
  lda #$00
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
  inc ene_x,x
  jmp @d_clamp_x

@d_drift_left:
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
; NOTE ON ENEMY SIZE:
;   Collisions currently assume enemies are 8x8 (x+7, y+7).
;   If you want 16x16 for 2x2 enemies, create a per-type width/height:
;     - small: 7
;     - large: 15
;   and use those in the overlap tests.
; ============================================================

CollideBulletsEnemies:
  ; Uses simple AABB overlap. Enemy hitbox is currently treated as 8x8.
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

  ; ---- enemy extent (7 or 15) ----
  jsr GetEnemyExtent
  sta tmp2              ; tmp2 = enemy extent

  ; ---- X range? (bullet point inside enemy box) ----
  lda bul_x,x
  cmp ene_x,y
  bcc @ene_next
  sec
  sbc ene_x,y
  cmp tmp2
  bcs @ene_next



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
  jsr GetEnemyExtent
  sta tmp2              ; tmp2 = enemy extent

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

  jsr PlayerTakeHit
  rts                  ; stop after one hit per frame

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

  ; (optional) reset scroll vars if you have them
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
  ; disable NMI so it can't fight you for PPU regs mid-write
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

  ; rendering on (use your normal mask)
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

  ; score digits (you’re using score_d0..d4)
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
  ; For now this is fine. Later we can do a tiny mod loop if you care.
  clc
  adc #CATCH_SPAWN_MIN
  sta catch_cd
  rts

; ---------------------------------
; CountActiveCatch -> A = count   (also stores in tmp0 if you want)
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
  bcs @after_life         ; if lives >= max, don't increase

  inc lives
  jsr HUD_MarkDirty       ; lives changed, so redraw hearts next NMI

@after_life:
  ; optional: add score, flash, sound, etc.
  ; jsr AddScoreSmall
  ; lda #GOOD_FLASH_FR : sta good_flash_timer

@next:
  inx
  bne @loop


@done:
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


; ------------------------------------------------------------
; DrawCatchSprites
; - Draws CATCH_MAX 1x1 sprites starting at CATCH_OAM_BASE
; ------------------------------------------------------------
DrawCatchSprites:
  ldx #$00
  ldy #CATCH_OAM_BASE      ; byte offset into OAM_BUF

@loop:
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

  ; ATTR (either per-object or constant)
  ; --- option A: constant ---
  ; lda #CATCH_ATTR
  ; --- option B: array ---
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


; ----------------------------
; DrawScoreSprites
; Draws 5 digits using sprites 59..63 (OAM $EC..$FF)
; Leading zeros blanked (tile 00) except the last digit.
; Requires: blank tile is tile $00
; ----------------------------
; ------------------------------------------------------------
; DrawScoreSprites
; - Draws score digits as sprites (overlay layer)
; - Used when BG HUD is disabled or for special screens
; - NOTE: currently disabled in BuildOAM (score is BG tiles instead)
; ------------------------------------------------------------
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
  lda #60
  sta level_banner
  lda #STATE_BANNER
  sta game_state
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
; BossSpawn
; - initializes boss fight state (boss + boss bullets)
; ------------------------------------------------------------
BossSpawn:
  jsr ClearBossBullets

  lda #$00
  sta boss_pattern

  lda #$00
  sta boss_pattern   ; start with single shots

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

  lda #BOSS_HP_INIT
  sta boss_hp
  sta boss_hp_max

  lda #FLAG_SET
  sta boss_hp_dirty
  lda #FLAG_CLEAR
  sta boss_flash

  lda #BOSS_FIRE_CD_FR
  sta boss_fire_cd

  rts


; ------------------------------------------------------------
; DrawBossSprites
; - Draws boss as a 2x2 metasprite (4 hardware sprites)
; - Assumes boss_x/boss_y are top-left
; ------------------------------------------------------------
DrawBossSprites:
  lda boss_alive
  bne :+
    rts
:

 ; ---- OAM safety guard (need 16 bytes) ----
  cpy #$F0          ; last safe start for 4 sprites
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
  eor #$01          ; toggle palette 2<->3 (or 0<->1 etc.)
  sta tmp0
@attr_ok:


  ; TL
  lda boss_y
  sta OAM_BUF,y
  iny
  lda #BOSS_TL
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  sta OAM_BUF,y
  iny

  ; TR
  lda boss_y
  sta OAM_BUF,y
  iny
  lda #BOSS_TR
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

  ; BL
  lda boss_y
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #BOSS_BL
  sta OAM_BUF,y
  iny
  lda tmp0
  sta OAM_BUF,y
  iny
  lda boss_x
  sta OAM_BUF,y
  iny

  ; BR
  lda boss_y
  clc
  adc #$08
  sta OAM_BUF,y
  iny
  lda #BOSS_BR
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

; ------------------------------------------------------------
; BossUpdate
; - Placeholder boss movement + firing cadence
; - Decrements boss_flash timer
; ------------------------------------------------------------
BossUpdate:
  lda boss_alive
  bne :+
    rts
:

  ; flash timer down
  lda boss_flash
  beq :+
  dec boss_flash
:

  ; movement (example: every other frame)
  lda frame_lo
  and #$01
  bne @fire
  jsr BossMoveBounceX
  ; jsr BossMoveBounceY   ; enable if you want vertical bounce too

  lda boss_fire_cd
  beq @fire
  dec boss_fire_cd
  jmp @after_fire

@fire:
  jsr BossFirePattern

  ; reload cooldown based on pattern (optional)
  lda boss_pattern
  beq :+
    lda #20          ; faster/harder in phase 2
    bne @set_cd
:
  lda #30            ; phase 1 slower
@set_cd:
  sta boss_fire_cd

@after_fire:






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

  ; >>> ADD THIS RIGHT HERE <<<
  lda #$00
  sta bossbul_dx,x      ; dx = 0
  lda #$02
  sta bossbul_dy,x      ; dy = 2

@no_slot:
  rts

; ------------------------------------------------------------
; BossFirePattern
; - fires based on boss_pattern
;   0 = Single
;   1 = Spread3
;   2 = Aimed3   (optional / future)
; ------------------------------------------------------------
BossFirePattern:
  lda boss_pattern
  beq @single

  cmp #$01
  beq @spread3

  ; default (or #$02)
@aimed3:
  jsr BossFire_Aimed3
  rts

@spread3:
  jsr BossFire_Spread3
  rts

@single:
  jsr BossFire_Single
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

BossSpawnBullet:
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

  lda tmp0
  sta bossbul_x,x
  lda tmp1
  sta bossbul_y,x
  sta bossbul_y_prev,x

  lda tmp2
  sta bossbul_dx,x
  lda tmp3
  sta bossbul_dy,x

@no_slot:
  rts

BossFire_Single:
  ; X = boss_x + center
  lda boss_x
  clc
  adc #BOSS_BULLET_X_OFF
  sta tmp0

  lda boss_y
  clc
  adc #BOSS_BULLET_Y_OFF
  sta tmp1

  lda #$00
  sta tmp2          ; dx = 0
  lda #$02
  sta tmp3          ; dy = 2

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
; - on hit: kill bullet, apply damage (your existing HIT path)
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

  jsr PlayerTakeHit
  rts                       ; one hit per frame

@next:
  inx
  bne @loop

@done:
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

  lda #FLAG_SET
  sta boss_hp_clear_pending   ; let NMI clear the bar once

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

  inx
  jmp @loop

@done:
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
; - Draws boss_hp as a row of filled/empty tiles
; - Assumes it is called inside NMI (vblank)
; - Leaves scroll reset to 0,0
; ------------------------------------------------------------
WriteBossHPBarBG:
  ; draws boss_hp as 0..BOSSBAR_LEN tiles
  ; assumes called in NMI (vblank)
  lda PPUSTATUS
  lda #BOSSBAR_NT_HI
  sta PPUADDR
  lda #BOSSBAR_NT_LO
  sta PPUADDR

  ldx #$00
@loop:
  cpx #BOSSBAR_LEN
  bcs @done

  ; filled if x < boss_hp
  txa
  cmp boss_hp
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
  sta hud_dirty          ; or hud_lives_dirty, whichever you use

  lda lives
  bne @done

  ; ---- lives just hit 0 -> GAME OVER ----
  jsr PlayerSetOver       ; (see below)
  rts

@already_zero:
  ; If you're somehow here while still playing, force game over
  jsr DoGameOver
@done:
  rts

DoGameOver:
  jsr ClearActors
  lda #STATE_OVER
  sta game_state
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

  .res 8192-816, $00
