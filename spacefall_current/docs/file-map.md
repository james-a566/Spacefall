
```md
# Starfall Source Map

## Boot / Frame Flow

`Reset` initializes RAM, PPU, music, and then enters the main loop.

## Main frame flow:

```text
MainLoop
  WaitFrame
  famistudio_update
  ReadController1
  state jump table dispatch

NMI handles:

- frame counter
- OAM DMA
- text queue flush
- HUD updates
- PPUMASK flash/grayscale
- scroll reset
```

## State Flow
```
STATE_TITLE
  ↓ START
STATE_INTRO
  ↓
STATE_TUTORIAL
  ↓
STATE_BANNER
  ↓
STATE_PLAY
  ↓ boss timer
STATE_BOSS_INTRO
  ↓
STATE_BOSS
  ↓ boss defeated
STATE_BOSS_DEFEATED
  ↓ next level
STATE_BANNER / STATE_PLAY
  ↓ after level 12
STATE_ENDING
  ↓ START
STATE_TITLE
```

# Important States

- State_Title: title screen, press start blink
- State_Intro: multi-page intro text
- State_Tutorial: tutorial screen
- State_Banner: level banner transition
- State_Play: main gameplay loop
- State_Boss: boss battle
- State_BossDefeated: boss cleanup / level advance
- State_Ending: final ending reveal

## Level Index Notes
Levels are zero-based:
```
$00 = Level 1
$0B = Level 12
$0C = Final Core / Level 13 ending sequence
```
Important constants:
```
LEVEL_FINAL_IDX = $0C
STATE_ENDING    = $0A
STATE_COUNT     = $0B
```
## Final Core Sequence

The final level does not use normal enemy/catch/boss updates.

EnterFinalLevel prepares the final sequence.

State_Play branches early when:
```
lda level_idx
cmp #LEVEL_FINAL_IDX
```
The final branch runs:

- player update
- bullets update
- final core spawn/update
- player/final core collision

It skips:

- normal catch spawning
- enemies
- boss countdown
- bullet/catch collision

When the player catches the final core, the game enters STATE_ENDING.