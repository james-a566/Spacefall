# Starfall

Starfall is a homebrew NES arcade shooter built in 6502 assembly using ca65/ld65.

## Current Release

**Release build:** v1.0  
**Status:** Complete playable loop

The game includes:
- title screen
- intro/tutorial flow
- 12 level progression
- boss encounters
- final core sequence
- ending screen
- return to title

## Build

```bash
./build.sh
```

## Controls 

- D-Pad: move
- A: shoot
- START: start / pause / advance from ending

## Source Layout
```

```

## Notes

This build targets mapper 0 / NROM-style simplicity unless otherwise changed in the linker/header configuration.

v1.0 is intentionally feature-complete and conservative. New Game+ scaling and additional post-ending features are planned for a future version.
