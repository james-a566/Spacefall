
---

# `docs/file-map.md`

```md
# Starfall Source Map

This document describes the structure and flow of the Starfall codebase.

---

# 🔁 Frame Flow

Main loop:

```text
MainLoop
  WaitFrame
  famistudio_update
  ReadController1
  state dispatch (jump table)
```
## NMI Responsibilities

`src/system/nmi.inc`

Runs once per frame:

- Frame counter increment
- OAM DMA (sprite upload)
- Text queue flush
- HUD updates
- Pause UI updates
- Screen flash / grayscale effects
- Scroll reset
- PPUCTRL restore

Important rule:
Registers (A/X/Y) are restored last before RTI.

## State System

State dispatch lives in:

`src/states/mainloop.inc`

Jump table:

- STATE_BANNER        $00
- STATE_PLAY          $01
- STATE_BOSS          $02
- STATE_OVER          $03
- STATE_TITLE         $04
- STATE_PAUSE         $05
- STATE_TUTORIAL      $06
- STATE_INTRO         $07
- STATE_BOSSINTRO     $08
- STATE_BOSSDEFEATED  $09
- STATE_ENDING        $0A


## State Flow
```
TITLE
  ↓ START
INTRO
  ↓
TUTORIAL
  ↓
BANNER
  ↓
PLAY
  ↓ (boss timer)
BOSS INTRO
  ↓
BOSS
  ↓
BOSS DEFEATED
  ↓
NEXT LEVEL → BANNER → PLAY

(Level 12 complete)
  ↓
FINAL CORE (Level 13)
  ↓
ENDING
  ↓ START
TITLE
```
## Level System

Defined in:

`src/data/level_params.inc`

Levels are zero-based:

- $00 = Level 1
- $0B = Level 12
- $0C = Final Core (Level 13)

Key constant:
```
LEVEL_FINAL_IDX = $0C
```

## Final Core Sequence

Triggered after Level 12.

Setup:

`EnterFinalLevel (state_transitions.inc)`

Behavior differences:

- Skips:
    - Enemy updates
    - Normal catch spawning
    - Boss timer / PlayUpdate logic
- Uses:
    - UpdateFinalCatch
    - CollidePlayerCatch

Core behavior:

- Falls from top
- Pulses (palette toggle)
- Respawns if missed
- Ends run when caught

## Gameplay Systems

Located in:

`src/game/`

Key files:
- player.inc — movement, shooting, cooldown
- bullets (within player) — projectile updates
- enemies.inc — enemy logic
- boss.inc — boss patterns + behavior
- catch.inc — falling core objects
- collisions.inc — all collision systems
- lives.inc — damage and life handling
- score.inc — scoring

## Memory Layout
`src/memory/`
- memory_zp.inc — zero-page variables (fast access)
- memory_bss.inc — general RAM

## Rendering
### OAM / Sprites
`src/oam/`
- buildoam.inc — builds sprite buffer each frame
### Background / PPU
`src/ppu/`
- backgrounds.inc — starfield
- ppu_helpers.inc — VRAM safe writes
- nmi_ui.inc — HUD updates in NMI

## Text System
```
src/ui/textq.inc
src/data/text_pages.inc
```
Two modes:

- Manual full-page draw (Text_DrawPage_Manual)
- Queue-based updates (TextQ_*)

Used for:

- Title
- Intro/tutorial
- Ending sequence

## Audio
`src/audio/`
- famistudio_ca65.s — engine
- music_all.s — music
- music_sfx.s — SFX

Update call:

`jsr famistudio_update`

## Core Systems
` src/coure/`
- frame.inc — frame sync
- input.inc — controller reading
- rng.inc — pseudo-random generator
- state_transitions.inc — ResetRun, level flow

## Debug
```
src/debug/debug.inc
src/states/debug_hotkeys.inc
```

Used for:

- spawning tests
- boss skip/debugging

Disabled in release.

## Build System
```
build.sh
nes.cfg
```
- Assembles all .s files
- Links into final .nes ROM

## Key Gotchas
- NMI register restore must be last
- VRAM writes only during VBlank or render-off
- StateJumpTable requires STATE_COUNT update
- Final level must skip PlayUpdate

## Summary
Starfall is structured as:
```
Engine (core/system)
  + Gameplay systems (game/)
  + State machine (states/)
  + Rendering (ppu/oam/ui)
  + Data (levels/text/audio)
```
v1.0 represents a complete, stable release build.