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
STATE_INTRO     = $07

STATE_BOSS_INTRO = $08
; ============================================================
; TEXTQ (Reusable text queue)
; ============================================================
TEXTQ_BUF_SIZE = 192         ; adjust (192..512 typical). 
TEXTQ_END_MARK = $00         ; len=0 terminates the command stream

TEXTQ_FLUSH_BUDGET = 128   ; bytes of VRAM data per NMI (tune 32..96)

; ----------------------------
; Boss HP Bar (BG)
; ----------------------------
BOSSBAR_NT_HI = $20
BOSSBAR_NT_LO = $A8   ; centered, row 5
BOSSBAR_LEN   = 16



;.if HUD_SAFE
BOSS_UI_CEILING_Y = $30   ; tune: $28..$38 typical
;.endif

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
BOSS_BULLET_OAM_BASE = $DC   ; sprite 55
; ------------------------------------------------------------
; Tile IDs
; ------------------------------------------------------------




; ------------------------------------------------------------
; UI layout
; ------------------------------------------------------------

TITLE_NT_HI  = $21
TITLE_NT_LO  = $8C    ; row 12, col 12  => $218C
TITLE_LEN    = 8
PRESS_NT_HI  = $22
PRESS_NT_LO  = $4A    ; row 18, col 11  => $224B
PRESS_NT_LEN = 11     ; "PRESS"(5) + space(1) + "START"(5)
GAMEOVER_NT_HI = $21
GAMEOVER_NT_LO = $CB        ; row 14, col 11  => $21CB
GAMEOVER_LEN   = 9

HUD_NT_HI      = $20

HUD_HI_LO      = $62   ; row 3 col 2  ($2022)
HUD_HI_DIG_LO  = $65   ; row 3 col 5  ($2025)
HUD_SC_LO      = $82   ; row 4 col 2  ($2042) -> "SC "
HUD_SC_DIG_LO  = $85   ; row 4 col 5  ($2045) -> digits start
HUD_LIVES_LO   = $6C   ; row 3 col 12 ($202C)

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
MUSIC_OVER      = $03
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

THR_B = $60     ; ~37% B (96/256)
THR_E = $F0     ; TEMP: top ~6% become E (16/256)
PLAYER_W = 16
PLAYER_H = 16
JAM_FR = 120        ; 1 second at 60fps (tweak)
JAM_FRAMES_BASE    = 60      ; frames (pick 60 to start)

INTRO_PAGE_FRAMES = 240 ; 4 seconds @60 fps
; ------------------------------------------------------------
; Enemy constants
; ------------------------------------------------------------
ENEMY_ATTR      = $01      ; sprite palette index
ENEMY_SPAWN_Y   = $10
ENEMY_KILL_Y    = $E0
ENEMY_HIT_FLASH_FR  = 2    ; tiny flicker for “ouch”
ENEMY_DIE_FLASH_FR  = 24    ; death flash length
EN_A = $00        ; 1x1 (8x8)
EN_B = $01        ; 1x1 (8x8)
EN_C = $02        ; 2x2 (16x16)
EN_D = $03        ; 2x2 (16x16)
EN_E = $04        ; 2x2 (16x16)

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
BOSS_PF_BIGSHOT_FX   = %00000001  ; bit0:  (flash/sfx emphasis)
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



; ------------------------------------------------------------
; Table strides/params
; ------------------------------------------------------------
LEVEL_SPAWN_CD_FR      = $18   ; base frames between spawns for a level
LEVEL_STRIDE = 12


; ------------------------------------------------------------
; OAM SAFETY CONSTANTS (reserved region for fixed boss bullets)
; ------------------------------------------------------------
OAM_DYNAMIC_LIMIT = $E0    ; bytes $E0..$EF reserved for DrawBossBullets_Fixed
OAM_2X2_LIMIT     = $D0    ; need 16 bytes (4 sprites) before hitting $E0
BULLET_OAM_BASE   = $10    ; sprite 4 (4*4)


; ------------------------------------------------------------
; OAM layout helpers (playtest-safe)
; ------------------------------------------------------------
BOSS_OAM_BYTES    = 36    ; 9 sprites * 4 bytes
BOSS_OAM_AFTER    = BOSS_OAM + BOSS_OAM_BYTES

; ------------------------------------------------------------
;
; ------------------------------------------------------------
SHIELD_FRAMES = 255   ; 

BOSS_INTRO_FRAMES = 90
BOSS_INTRO_TEXT_HI  = $21
BOSS_INTRO_TEXT_LO  = $8A
BOSS_INTRO_TEXT_LEN = 18   ; number of tiles you wrote
