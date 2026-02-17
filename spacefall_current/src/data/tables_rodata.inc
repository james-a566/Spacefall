.segment "RODATA"
; ============================================================
; [RODATA] STATIC DATA TABLES
; - SFX byte sequences (played by the simple SFX driver)
; - Palettes
; - Difficulty tables (LevelParams / Catch tables / Boss pattern tables)
; - UI strings / lookup tables
; NOTE: A few tiny helper routines may live near their data for convenience.
; ============================================================
.macro TEXTPAGE_LINE hi, lo, str
  .byte hi, lo, <str, >str
.endmacro


Str_TitleA: .byte TILE_S,TILE_T,TILE_A,TILE_R,TILE_F,TILE_A,TILE_L,TILE_L,$00

TextPage_Title:
  TEXTPAGE_LINE $21,$4C, Str_TitleA
  .byte $00
  

Str_PressStart:
  .byte TILE_P, TILE_R, TILE_E, TILE_S, TILE_S, TILE_SPACE
  .byte TILE_S, TILE_T, TILE_A, TILE_R, TILE_T, $00

Str_GameOver:
  .byte TILE_G, TILE_A, TILE_M, TILE_E, TILE_SPACE
  .byte TILE_O, TILE_V, TILE_E, TILE_R, $00


; ============================================================
; INTRO TEXT — FINAL (OPTION A)
; ============================================================

; -------- Page 1 --------
Str_Intro1_A:
  .byte TILE_T,TILE_H,TILE_E,TILE_SPACE
  .byte TILE_C,TILE_O,TILE_R,TILE_E, TILE_S
  .byte $00

Str_Intro1_B:
  .byte TILE_K,TILE_E,TILE_E,TILE_P,TILE_SPACE
  .byte TILE_T,TILE_H,TILE_E,TILE_SPACE
  .byte TILE_S,TILE_Y,TILE_S,TILE_T,TILE_E,TILE_M
  .byte $00

Str_Intro1_C:
  .byte TILE_A,TILE_L,TILE_I,TILE_V,TILE_E
  .byte $00


; -------- Page 2 --------
Str_Intro2A:
  .byte TILE_T,TILE_H,TILE_E,TILE_Y,TILE_SPACE
  .byte TILE_A,TILE_R,TILE_E,TILE_SPACE
  .byte TILE_F,TILE_A,TILE_L,TILE_L,TILE_I,TILE_N,TILE_G,$00

Str_Intro2B:
  .byte TILE_I,TILE_N,TILE_SPACE
  .byte TILE_E,TILE_N,TILE_E,TILE_M,TILE_Y,TILE_SPACE
  .byte TILE_S,TILE_P,TILE_A,TILE_C,TILE_E,$00


; -------- Page 3 --------
Str_Intro3A:
  .byte TILE_A,TILE_V,TILE_O,TILE_I,TILE_D,TILE_SPACE
  .byte TILE_E,TILE_N,TILE_E,TILE_M,TILE_I,TILE_E,TILE_S,$00

Str_Intro3B:
  .byte TILE_C,TILE_A,TILE_T,TILE_C,TILE_H,TILE_SPACE
  .byte TILE_C,TILE_O,TILE_R,TILE_E,TILE_S,$00


; -------- Page 4 --------
Str_Intro4:
  .byte TILE_S,TILE_U,TILE_R,TILE_V,TILE_I,TILE_V,TILE_E,$00


; ============================================================
; INTRO PAGES (FINAL)
; ============================================================

TextPage_Intro1:
  TEXTPAGE_LINE $21, $CB, Str_Intro1_A   ; row14 col11
  TEXTPAGE_LINE $21, $E8, Str_Intro1_B   ; row15 col8
  TEXTPAGE_LINE $22, $0D, Str_Intro1_C   ; row16 col13
  .byte $00


TextPage_Intro2:
  TEXTPAGE_LINE $21, $C8, Str_Intro2A    ; row14 col8
  TEXTPAGE_LINE $21, $E9, Str_Intro2B    ; row15 col9
  .byte $00


TextPage_Intro3:
  TEXTPAGE_LINE $21, $CA, Str_Intro3A    ; row14 col10
  TEXTPAGE_LINE $21, $EB, Str_Intro3B    ; row15 col11
  .byte $00


TextPage_Intro4:
  TEXTPAGE_LINE $21, $EC, Str_Intro4     ; row15 col12 (less “jump”)
  .byte $00



; example: intro_page = 0..3

LoadIntroPage:
  lda intro_page
  asl
  tax
  lda IntroPageTable,x
  sta ptr1
  lda IntroPageTable+1,x
  sta ptr1+1
  jsr Text_DrawPage_Manual
  rts

IntroPageTable:
  .word TextPage_Intro1
  .word TextPage_Intro2
  .word TextPage_Intro3
  .word TextPage_Intro4


; ============================================================
; TUTORIAL PAGE 1 (text only; icons are sprites)
; ============================================================

Str_TutEnemies:
  .byte TILE_F,TILE_I,TILE_R,TILE_E,TILE_SPACE
  .byte TILE_A,TILE_T,TILE_SPACE
  .byte TILE_E,TILE_N,TILE_E,TILE_M,TILE_I,TILE_E,TILE_S,$00

Str_TutCores:
  .byte TILE_D,TILE_O,TILE_SPACE
  .byte TILE_N,TILE_O,TILE_T,TILE_SPACE
  .byte TILE_F,TILE_I,TILE_R,TILE_E,TILE_SPACE
  .byte TILE_A,TILE_T,TILE_SPACE
  .byte TILE_C,TILE_O,TILE_R,TILE_E,TILE_S,$00

TextPage_Tutorial1:
  ; Row 9, Col 8  (center 15 chars)
  TEXTPAGE_LINE $21, $28, Str_TutEnemies   ; $2120 + $08 = $2128

  ; Row 16, Col 6 (center 20 chars)
  TEXTPAGE_LINE $22, $06, Str_TutCores     ; $2200 + $06 = $2206

  .byte $00


; Must be >= the largest blank run
BLANK_MAX_LEN = 32

BlinkBlanks:
  .repeat BLANK_MAX_LEN
    .byte $00          ; blank tile (space)
  .endrepeat


; ----------------------------
; Boss Intro
; ----------------------------
; Pick a placeholder tile for now.
; Later replace TILE_WARN with your triangle/exclamation tile.
TILE_WARN = TILE_SPACE   ; TEMP until you have the symbol tile

Str_BossLine1:
  .byte TILE_WARN, TILE_SPACE
  .byte TILE_W, TILE_A, TILE_R, TILE_N, TILE_I, TILE_N, TILE_G
  .byte TILE_SPACE, TILE_WARN
  .byte $00

Str_BossLine2:
  .byte TILE_I, TILE_N, TILE_C, TILE_O, TILE_M, TILE_I, TILE_N, TILE_G
  .byte TILE_SPACE
  .byte TILE_T, TILE_H, TILE_R, TILE_E, TILE_A, TILE_T
  .byte $00



; ----------------------------
; Sound Data
;-----------------------------


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

  .byte $0F,$16,$27,$30       ; SPR2 explosion/fx
                              

  .byte $0F,$2A,$12,$02       ; SPR3 boss (unchanged)



; ------------------------------------------------------------
; Difficulty tables
; ------------------------------------------------------------
; ============================================================
; LEVEL PARAMS (12 bytes per level, 60fps)
; ============================================================
; [0] spawn_cd     frames between enemy spawns (smaller = more enemies)
; [1] enemy_spd    pixels/frame falling speed
; [2] thrB         r < thrB  => B
; [3] thrC         else if r < thrC => C
; [4] thrD         else if r < thrD => D
; [5] thrE         if thrE!=0 and r >= thrE => E (top-band), else A
; [6-7] boss_time  16-bit frames until boss (e.g. 7200=120s)
; [8] ene_cd       enemy AI cooldown knob (frames, impl-specific)
; [9] catch_cd4    catch attempt interval in 4-frame units (catch_cd = max(1,cd4)*4)
; [10] good_thr    chance per attempt: spawn if r < good_thr (good_thr/256)
; [11] catch_cap   max active catch objects on screen
; ============================================================




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

; L10 (introduce E)
LEVELPARAMS $0F, $04, $18, $3C, $74, $F0, 15000, 20,  44, 28,  1

; L11
LEVELPARAMS $0E, $04, $18, $38, $70, $EC, 15000, 20,  48, 28,  1

; L12
LEVELPARAMS $0D, $05, $18, $34, $6C, $E8, 16200, 20,  52, 28,  1





; CatchKindParams per level: thrFrac, thrFinal
; Model:
;   r < thrFinal  => FINAL
;   r < thrFrac   => FRACTURED
;   else          => CORE

CatchKindParams:
  .byte $00,$00   ; L1
  .byte $10,$00   ; L2
  .byte $20,$00   ; L3
  .byte $60,$02   ; L4
  .byte $70,$04   ; L5
  .byte $80,$06   ; L6
  .byte $90,$08   ; L7
  .byte $A0,$0A   ; L8
  .byte $B0,$0C   ; L9
  .byte $C8,$18   ; L10  (~78% frac, ~9% final)
  .byte $D8,$1C   ; L11  (~84% frac, ~11% final)
  .byte $E0,$20   ; L12  (~88% frac, ~12% final)



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
; fire_cd is base; FAST_CD halves it 

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
  .byte TILE_STAR_0, TILE_STAR_1, TILE_STAR_2, TILE_STAR_3


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
  .byte 2,5,0   ; EN_E = 250  


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

ScorePlus100:    .byte 0,0,1,0,0   ; [d4,d3,d2,d1,d0] => 00100
ScorePlus500:    .byte 0,0,5,0,0   ; 00500
ScorePlus1000:   .byte 0,0,0,1,0   ; 01000

; tmp0/tmp1 = pointer to 5-digit table
AddScore_FromTable:
  jsr AddScore5Digits
  rts
