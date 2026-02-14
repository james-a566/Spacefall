
.segment "CODE"




; ------------------------------------------------------------
; [RESET]
; - Hardware init
; - RAM/OAM clear
; - Initial game state
; - Enable NMI + rendering
; ------------------------------------------------------------

; ------------------------------------------------------------
; STABLE ZONE — RESET / init
; Playtest build: avoid logic/timing changes here.
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
  sta ppuctrl_shadow
  sta PPUCTRL
  sta PPUMASK

  ; warm up (vblank sync)
  jsr WaitVBlank
  jsr WaitVBlank

  ; clear RAM + OAM shadow
  jsr ClearRAM
  jsr ClearOAM

  ; ---- structured init ----
  jsr InitAudio
  jsr InitGameVars
  jsr ClearActors
  jsr InitVRAMAndUI

  jmp MainLoop

; ------------------------------------------------------------
; InitAudio
; - FamiStudio init + SFX init
; - Sets music state vars to "none"
; - Enables APU channels
; ------------------------------------------------------------
InitAudio:
  ; Init FamiStudio (correct regs)
  lda #$01                          ; NTSC
  ldx #<_music_data_spacefall_gameplay
  ldy #>_music_data_spacefall_gameplay
  jsr famistudio_init

  lda #$FF
  sta current_music
  sta music_cur

  ldx #<_sounds
  ldy #>_sounds
  jsr famistudio_sfx_init

  ; enable APU channels (SQ1 SQ2 TRI NOISE)
  lda #%00001111
  sta $4015
  rts

; ------------------------------------------------------------
; InitGameVars
; - Initializes game/state variables (no actor arrays)
; ------------------------------------------------------------
InitGameVars:
  lda #$00
  sta player_kb_timer
  sta player_kb_dx
  sta player_kb_dy

  sta play_entered
  sta first_run

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

  sta gun_side

  ; seed RNG (fixed seed at boot)
  lda #$A7
  sta rng_lo
  lda #$1D
  sta rng_hi

  lda #$00
  sta score_lo
  sta score_hi

  sta bul_y_prev

  ; start with a short delay before first spawn
  lda #SPAWN_START_DELAY_FR
  sta spawn_cd

  lda #$03
  sta lives
  lda #$00
  sta invuln_timer

  lda #$00
  sta good_flash_timer

  lda #STATE_TITLE
  sta game_state

  lda #$00
sta title_built


  lda #$00
  sta press_visible
  sta title_visible
  sta gameover_visible

  lda #$00
  sta gameover_blink_timer
  sta gameover_blink_phase

  lda #$00
  sta screen_flash_timer

  lda #$00
  sta draw_test_active
  sta draw_test_done

  ; debug
  lda #$00
  sta debug_force_type
  sta debug_mode

  
  rts

; ------------------------------------------------------------
; InitVRAMAndUI
; - VRAM init with rendering OFF
; - Draw starfield NT0/NT1 + attributes/UI attrs
; - HUD init
; - Enables NMI + rendering
; ------------------------------------------------------------
InitVRAMAndUI:
  ; keep rendering OFF while writing VRAM
  lda #$00
  sta ppuctrl_shadow
  sta PPUCTRL
  sta PPUMASK

  ; VRAM init (rendering still OFF)
  jsr WaitVBlank
  ; align enabling rendering to vblank boundary
  jsr WaitVBlank

  ; scroll = 0,0 (clean latch)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  jsr PPU_BeginVRAM
  jsr InitPalettes_Safe

  jsr ClearNametable0
  jsr DrawStarfieldNT0
  jsr ClearAttributesNT0
  jsr SetUIAttrsNT0

  jsr ClearNametable1
  jsr DrawStarfieldNT1
  jsr ClearAttributesNT1
  jsr SetUIAttrsNT1

  jsr PPU_EndVRAM

  jsr HUD_Init

  ; push initial sprites to real OAM once
  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

  ; enable NMI + rendering
  lda #%10000000
  sta ppuctrl_shadow
  sta PPUCTRL


  lda #PPUMASK_BG_SPR ; BG + sprites + show left 8px
  sta PPUMASK
  rts


