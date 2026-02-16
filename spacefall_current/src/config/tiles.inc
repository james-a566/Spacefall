; ============================================================
; tiles.inc — Spacefall v2.7 (canonical tile ID map)
; ============================================================
; Single source of truth for tile IDs.
; Draw tiles in NEXXT to match these indices.
;
; Conventions:
;   - BG tiles: $00-$7F
;   - SPR tiles: $80-$FF
;   - 2x2 metasprite frames are 4 consecutive tiles:
;         TL=base+0, TR=base+1, BL=base+2, BR=base+3
; ============================================================

; Solid/Debug blocks
TILE_BLANK_00 = $00
TILE_SOLID_01 = $01
TILE_SOLID_02 = $02
TILE_SOLID_03 = $03


TILE_BOSSBAR_EMPTY = $2E
 
TILE_BOSSBAR_FULL  = $02

; ------------------------------------------------------------
; BG (0..127) — digits, letters, HUD icons, star tiles
; ------------------------------------------------------------
TILE_DIGIT_BASE = TILE_DIGIT_0

; ---- Digits 0–9 ----
TILE_DIGIT_0 = $60
TILE_DIGIT_1 = $61
TILE_DIGIT_2 = $62
TILE_DIGIT_3 = $63
TILE_DIGIT_4 = $64
TILE_DIGIT_5 = $65
TILE_DIGIT_6 = $66
TILE_DIGIT_7 = $67
TILE_DIGIT_8 = $68
TILE_DIGIT_9 = $69

; ---- Letters A–Z (caps) ----
TILE_A = $10
TILE_B = $11
TILE_C = $12
TILE_D = $13
TILE_E = $14
TILE_F = $15
TILE_G = $16
TILE_H = $17
TILE_I = $18
TILE_J = $19
TILE_K = $1A
TILE_L = $1B
TILE_M = $1C
TILE_N = $1D
TILE_O = $1E
TILE_P = $1F
TILE_Q = $20
TILE_R = $21
TILE_S = $22
TILE_T = $23
TILE_U = $24
TILE_V = $25
TILE_W = $26
TILE_X = $27
TILE_Y = $28
TILE_Z = $29

; ---- Common text glyphs (optional but reserved) ----
TILE_DOT   = $2C   ; '.'
TILE_COLON = $2D   ; ':'
TILE_SPACE = $2E   ; blank
TILE_TEXT_BLANK = $2E
TILE_DASH  = $2F   ; '-'

; ---- HUD hearts (BG) ----
TILE_HEART_FULL  = $30
TILE_HEART_EMPTY = $2E

; ---- BG stars (reserve a block for expansion) ----
TILE_STAR_0 = $40
TILE_STAR_1 = $41
TILE_STAR_2 = $42
TILE_STAR_3 = $43
TILE_STAR_4 = $44
TILE_STAR_5 = $45
; $46-$4F reserved: more star variants / BG deco

; ---- BG reserved / future ----
; $50-$7F reserved


; ------------------------------------------------------------
; SPRITES (128..255) — player, bullets, enemies, boss
; ------------------------------------------------------------

; ----------------------------
; 2x2 metasprite frame rule:
; TL=base+0, TR=base+1, BL=base+2, BR=base+3
; ----------------------------

; ---- Player (2x2) block ($80-$8F): 4 frames max ----
TILE_PLAYER_F0 = $80          ; 80-83
TILE_PLAYER_SHIELD_F0 = $84   ; 84-87      ; ship with shield
TILE_PLAYER_F2 = $88          ; 88-8B
TILE_PLAYER_F3 = $8C          ; 8C-8F

; ---- Player bullets / tiny FX (1x1) block ($90-$97) ----
TILE_PBULLET_0  = $90
TILE_PBULLET_1  = $91
TILE_PBULLET_2  = $92
TILE_PBULLET_3  = $93

TILE_CATCH_CORE_BASE          = $94
TILE_CATCH_CORE_FRACTURED     = $95
TILE_CATCH_CORE_FINAL         = $96   

; Tile $97 unused

; ---- Enemy A (1x1) block ($98-$9F): up to 8 frames ----
TILE_ENEMY_A_F0 = $98
TILE_ENEMY_A_F1 = $99
TILE_ENEMY_A_F2 = $9A
TILE_ENEMY_A_F3 = $9B
TILE_ENEMY_A_F4 = $9C
TILE_ENEMY_A_F5 = $9D
TILE_ENEMY_A_F6 = $9E
TILE_ENEMY_A_F7 = $9F

; ---- Enemy B (1x1) block ($A0-$A7): up to 8 frames ----
TILE_ENEMY_B_F0 = $A0
TILE_ENEMY_B_F1 = $A1
TILE_ENEMY_B_F2 = $A2
TILE_ENEMY_B_F3 = $A3
TILE_ENEMY_B_F4 = $A4
TILE_ENEMY_B_F5 = $A5
TILE_ENEMY_B_F6 = $A6
TILE_ENEMY_B_F7 = $A7

; ---- Enemy C (2x2) block ($A8-$B7): 4 frames max ----
TILE_ENEMY_C_F0 = $A8   ; A8-AB
TILE_ENEMY_C_F1 = $AC   ; AC-AF
TILE_ENEMY_C_F2 = $B0   ; B0-B3
TILE_ENEMY_C_F3 = $B4   ; B4-B7

; ---- Enemy D (2x2) block ($B8-$C7): 4 frames max ----
TILE_ENEMY_D_F0 = $B8   ; B8-BB
TILE_ENEMY_D_F1 = $BC   ; BC-BF  (good home for flip anim frame)
TILE_ENEMY_D_F2 = $C0   ; C0-C3
TILE_ENEMY_D_F3 = $C4   ; C4-C7

; ---- Enemy E (2x2) block ($C8-$D7): 4 frames max ----
TILE_ENEMY_E_F0 = $C8   ; C8-CB
TILE_ENEMY_E_F1 = $CC   ; CC-CF
TILE_ENEMY_E_F2 = $D0   ; D0-D3
TILE_ENEMY_E_F3 = $D4   ; D4-D7

; ---- Boss 3x3 block ($D8-$E0) ----
TILE_BOSS_TL = $D8
TILE_BOSS_TM = $D9
TILE_BOSS_TR = $DA
TILE_BOSS_ML = $DB
TILE_BOSS_MM = $DC
TILE_BOSS_MR = $DD
TILE_BOSS_BL = $DE
TILE_BOSS_BM = $DF
TILE_BOSS_BR = $E0

; explosions, pickups, enemy bullets, extra UI sprites, etc. $F0-$FF
; 2x2 explosion frames (TL tile of each frame)
TILE_EXP2X2_F0 = $F0   ; uses F0 F1 F2 F3
TILE_EXP2X2_F1 = $F4   ; uses F4 F5 F6 F7
TILE_EXP2X2_F2 = $F8   ; uses F8 F9 FA FB

; 1x1 explosion frames
TILE_EXP1X1_0  = $FC
TILE_EXP1X1_1  = $FD
TILE_EXP1X1_2  = $FE

   
