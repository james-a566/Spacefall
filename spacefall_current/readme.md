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
spacefall_current/
  build.sh                  Build script
  nes.cfg                   Linker config
  readme.md                 Project README
  music_gameplay.fms        FamiStudio music project
  spacefall_sfx.fms         FamiStudio SFX project

  build/
    game.nes                Built ROM output
    main.o                  Build artifact

  docs/
    CHANGELOG.md            Release notes / version history
    file-map.md             Source navigation notes

  src/
    main.s                  Main source file / include hub

    config/
      constants.inc         Gameplay/system constants
      tiles.inc             Tile ID definitions

    core/
      frame.inc             Frame wait / timing helpers
      input.inc             Controller reading
      mem.inc               Memory clearing/helpers
      rng.inc               Random number routines
      state_transitions.inc State transition helpers, ResetRun, level flow

    data/
      level_params.inc      Level parameter tables and final-level setup
      tables_rodata.inc     Read-only lookup tables
      text_pages.inc        Text strings and text page definitions

    debug/
      debug.inc             Debug helpers / debug spawning

    game/
      actors.inc            Actor clearing/setup helpers
      boss.inc              Boss logic
      catch.inc             Catch/core spawning and movement
      collisions.inc        Player/enemy/bullet/catch collisions
      enemies.inc           Enemy spawning and updates
      lives.inc             Lives / damage helpers
      player.inc            Player movement/shooting
      score.inc             Score logic

    memory/
      memory_bss.inc        BSS RAM variables
      memory_zp.inc         Zero-page variables

    oam/
      buildoam.inc          Sprite/OAM composition
      oam.inc               OAM constants/helpers

    ppu/
      backgrounds.inc       Starfield/background drawing
      nmi_ui.inc            HUD/pause/text NMI-side updates
      ppu_helpers.inc       PPU begin/end VRAM helpers

    states/
      mainloop.inc          Main loop and state jump table
      states_title_intro.inc Title, intro, tutorial states
      states_play_boss.inc  Play, boss, boss intro/defeated states
      states_pause_over.inc Pause, game over, ending states
      debug_hotkeys.inc     Debug skip/hotkey state helpers

    system/
      header.inc            iNES header
      reset.inc             Reset/boot sequence
      nmi.inc               NMI routine
      vectors.inc           Interrupt vectors
      chr.s                 CHR include/binary data

    ui/
      hud.inc               HUD drawing/update logic
      textq.inc             Text queue/manual text helpers

    audio/
      audio.inc             Audio constants/wrappers
      famistudio_ca65.s     FamiStudio engine
      music_all.s           Music data
      music_sfx.s           SFX data

    spacefall.chr           Active CHR graphics
    spacefall_backup_2026-02-13.chr
                             Backup CHR graphics
```

## Notes

This build targets mapper 0 / NROM-style simplicity unless otherwise changed in the linker/header configuration.

v1.0 is intentionally feature-complete and conservative. New Game+ scaling and additional post-ending features are planned for a future version.
