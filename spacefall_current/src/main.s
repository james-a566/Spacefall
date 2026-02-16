; ============================================================
; main.s — Spacefall v2.7
; “One file to include them all.”
; ============================================================

; ============================================================
; BUILD FLAGS 
; ============================================================
; currently unused 


; ============================================================
; Audio: FamiStudio config
; MUST be defined before including famistudio_ca65.s
; ============================================================
FAMISTUDIO_CFG_SFX_SUPPORT = 1
FAMISTUDIO_CFG_SFX_STREAMS = 2    

; ============================================================
; CONFIG / CONSTANTS
; ============================================================
.include "src/config/constants.inc"
.include "src/config/tiles.inc"

; ============================================================
; MEMORY MAP (ZP + BSS)
; Must come before code that references these symbols.
; ============================================================
.include "src/memory/memory_zp.inc"
.include "src/memory/memory_bss.inc"

; ============================================================
; RODATA / TABLES / TEXT PAGES
; ============================================================
.include "src/data/tables_rodata.inc"
.include "src/data/level_params.inc"
.include "src/data/text_pages.inc"

; ============================================================
; AUDIO ENGINE + DATA + WRAPPERS
; ============================================================
.include "src/audio/famistudio_ca65.s"
.include "src/audio/music_all.s"
.include "src/audio/music_sfx.s"
.include "src/audio/audio.inc"

; ============================================================
; CORE SYSTEMS (frame, input, rng, mem helpers)
; ============================================================
.include "src/core/frame.inc"
.include "src/core/input.inc"
.include "src/core/rng.inc"
.include "src/core/mem.inc"
.include "src/core/state_transitions.inc"

; ============================================================
; UI / TEXT QUEUE / HUD
; ============================================================
.include "src/ui/textq.inc"
.include "src/ui/hud.inc"

; ============================================================
; PPU HELPERS + BACKGROUNDS + NMI UI
; ============================================================
.include "src/ppu/ppu_helpers.inc"
.include "src/ppu/backgrounds.inc"
.include "src/ppu/nmi_ui.inc"

; ============================================================
; OAM / SPRITES
; ============================================================
.include "src/oam/oam.inc"
.include "src/oam/buildoam.inc"

; ============================================================
; GAMEPLAY SYSTEMS
; ============================================================
.include "src/game/actors.inc"
.include "src/game/player.inc"
;.include "src/game/bullets.inc"        ; to add later
.include "src/game/enemies.inc"
.include "src/game/catch.inc"
.include "src/game/boss.inc"
.include "src/game/collisions.inc"
.include "src/game/score.inc"
.include "src/game/lives.inc"

; ============================================================
; DEBUG
; (Keep late so it can call into anything)
; ============================================================
.include "src/debug/debug.inc"

; ============================================================
; STATE MACHINE
; (States call into gameplay systems)
; ============================================================
.include "src/states/debug_hotkeys.inc"
.include "src/states/states_title_intro.inc"
.include "src/states/states_play_boss.inc"
.include "src/states/states_pause_over.inc"
.include "src/states/mainloop.inc"

; ============================================================
; BOOT + INTERRUPTS + VECTORS
; Keep reset/nmi late so all routines exist.
; ============================================================
.include "src/system/reset.inc"
.include "src/system/nmi.inc"
.include "src/system/vectors.inc"

; ============================================================
; [HDR] iNES Header
; ============================================================
.include "src/system/header.inc"

; ============================================================
; CHR
; ============================================================
.include "src/system/chr.s"
