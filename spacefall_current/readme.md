# Starfall

Starfall is a homebrew NES arcade shooter written in 6502 assembly using ca65/ld65.

## Overview

Survive escalating waves of enemies, defeat bosses, and recover scattered cores.  
After 12 levels, a final core appears—catch it to complete the run and trigger the ending.

## Release

**Version:** v1.0  
**Status:** Complete playable loop

Features:
- Title, intro, and tutorial flow
- 12 levels of escalating difficulty
- Boss encounters
- Catch/core system
- Final core ending sequence
- Ending screen with staged text reveal
- Pause system
- HUD (score, lives)
- Music + sound effects via FamiStudio

---

## Build

Requires:
- ca65 / ld65 (cc65 toolchain)
- Bash (macOS/Linux)

Build the ROM:

```bash
./build.sh
```
Output
```
build/game.nes
```
## Controls
| Input | Action        |
| ----- | ------------- |
| D-Pad | Move          |
| A     | Shoot         |
| START | Start / Pause |

## Project Structure

```
src/
  main.s                  Entry point / include hub

  config/                 Constants and tile definitions
  core/                   Frame, input, RNG, transitions
  data/                   Level tables, text, lookup data
  game/                   Gameplay systems (player, enemies, boss, catch)
  memory/                 RAM layout (ZP + BSS)
  oam/                    Sprite building
  ppu/                    Backgrounds, VRAM helpers
  states/                 Game states (title, play, boss, ending)
  system/                 Reset, NMI, vectors, header
  ui/                     HUD and text system
  audio/                  FamiStudio engine + data
```
Full breakdown in: docs/file-map.md

## Design Notes
- Levels are zero-based internally:
    - $00 = Level 1
    - $0B = Level 12
    - $0C = Final core sequence
- The final level is not a standard level:
    - No enemies
    - No boss timer
    - Single falling core
    - Player must catch it to finish the run

## Audio
Audio is powered by FamiStudio:

- music_gameplay.fms
- spacefall_sfx.fms

Compiled into:

- src/audio/music_all.s
- src/audio/music_sfx.s

## Debug
Some debug features exist (spawn/testing), but are disabled in the release build.

## Future Plans
Planned for future versions:

- New Game+ difficulty scaling
- Additional polish (visual/audio effects)
- Potential gameplay extensions

## License
(TODO)

## Notes
This project targets NES hardware behavior.
Tested in emulator and on real hardware via flash cartridge.