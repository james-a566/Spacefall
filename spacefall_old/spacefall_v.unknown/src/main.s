; ============================================================
; main.s — based on template_bg.s NES boilerplate (ca65) — BG + Sprites
; NROM-128 (16KB PRG), 8KB CHR-ROM
; Boots to solid BG (tile 0 filled) + movable test sprite
; HUD module (hud.s)
; Requires:
;   jsr HUD_DrawStatic during init (rendering off or vblank)
;   jsr HUD_NMI inside NMI
; ============================================================

.include "src/common.inc"
.include "lib/hud/hud.inc"
.include "src/game.inc"
.include "src/tiles.inc"

OAM_BUF = $0200

OAMADDR = $2003
OAMDMA  = $4014

; ----------------------------
; iNES HEADER
; ----------------------------
.segment "HEADER"
  .byte "NES", $1A
  .byte $01          ; 1 × 16KB PRG
  .byte $01          ; 1 × 8KB CHR
  .byte $01          ; mapper 0, vertical mirroring
  .byte $00
  .res 8, $00

; ----------------------------
; ZEROPAGE
; ----------------------------
.segment "ZEROPAGE"
.export nmi_ready, frame_lo, frame_hi
.export pad1, pad1_prev, pad1_new
.export rng_seed

nmi_ready:  .res 1
frame_lo:   .res 1
frame_hi:   .res 1
pad1:       .res 1
pad1_prev:  .res 1
pad1_new:   .res 1
rng_seed:   .res 1

; OAM write cursor: 0..252, advances by 4 per sprite
spr_i:       .res 1

; Anchor position for metasprite
spr_x0:      .res 1
spr_y0:      .res 1

; Tiles for the 2x2 block
spr_tile0:   .res 1   ; top-left
spr_tile1:   .res 1   ; top-right
spr_tile2:   .res 1   ; bottom-left
spr_tile3:   .res 1   ; bottom-right

; Shared attribute for all 4 sprites (palette/flip/priority)
spr_attr0:   .res 1

; ----------------------------
; BSS
; ----------------------------
.segment "BSS"



; ----------------------------
; CODE
; ----------------------------
.segment "CODE"

; ----------------------------
; Palette data (32 bytes)
; ----------------------------
Palettes:

; BG0: c0,  c1,  c2,  c3
.byte $0F, $30, $16, $0F

  .byte $0F,$06,$16,$26
  .byte $0F,$09,$19,$29
  .byte $0F,$0C,$1C,$2C

  ; SPR0 = bright (our test sprite uses color index 3 => entry 4)
  .byte $0F,$16,$16,$16   ; SPR0: bright red (high contrast on white)
  .byte $0F,$30,$10,$20
  .byte $0F,$06,$16,$26
  .byte $0F,$09,$19,$29

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
  sta PPUCTRL
  sta PPUMASK

  ; warm up
  jsr WaitVBlank
  jsr WaitVBlank

  ; clear RAM + OAM shadow
  jsr ClearRAM
  jsr ClearOAM

  ; seed / frame flags (system-owned)
  lda #$00
  sta frame_lo
  sta frame_hi
  sta pad1
  sta pad1_prev
  sta pad1_new
  sta nmi_ready

  lda #$01
  sta rng_seed

  ; VRAM init (rendering still OFF)
  jsr ClearNametable0
  jsr InitPalettes

  ; HUD init + static HUD draw (safe while rendering off)
  jsr HUD_Init
  jsr HUD_DrawStatic

  ; Game init (sets lives, player, objects, etc.)
  jsr Game_Init

  ; align enabling rendering to vblank boundary
  jsr WaitVBlank

  ; scroll = 0,0 (clean latch)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  Spr_BeginFrame:
  lda #$00
  sta spr_i
  rts

Spr_HideAll:
  lda #$FF
  ldx #$00
@loop:
  sta OAM_BUF, x      ; write Y=$FF for every sprite
  inx
  inx
  inx
  inx
  bne @loop
  rts

Spr_Push8x8:
  pha                 ; save tile in A

  ldx spr_i

  ; Y
  tya
  sta OAM_BUF+0, x

  ; tile
  pla
  sta OAM_BUF+1, x

  ; attr
  lda spr_attr0
  sta OAM_BUF+2, x

  ; X
  txa                 ; careful: X currently = spr_i index, not sprite X
  ; We need the sprite X that was passed in X register earlier.
  ; So: DON'T clobber X before using it. We'll rewrite with safer calling below.
  rts


  ; push initial sprites to real OAM once
  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

  ; enable NMI + rendering
  lda #%10000000      ; NMI on
  sta PPUCTRL
  lda #PPUMASK_BG_SPR ; BG + sprites + show left 8px
  sta PPUMASK

MainLoop:
@wait:
  lda nmi_ready
  beq @wait
  lda #$00
  sta nmi_ready

  jsr ReadController1

; --------------------------------
; Draw player (2x2 metasprite)
; --------------------------------

lda player_x
sta spr_x0

lda player_y
sta spr_y0

lda #PLAYER_PAL_ATTR   ; e.g. %00000000 (palette 0)
sta spr_attr0

lda #TILE_PLAYER_TL
sta spr_tile0
lda #TILE_PLAYER_TR
sta spr_tile1
lda #TILE_PLAYER_BL
sta spr_tile2
lda #TILE_PLAYER_BR
sta spr_tile3

jsr Spr_Put2x2

  ; one “frame” of the game state machine
  jsr Game_Frame

  

  jmp MainLoop





; ----------------------------
; NMI
; ----------------------------
NMI:
  pha
  txa
  pha
  tya
  pha

  ; ---- HUD / VRAM updates ----
  jsr HUD_NMI

  ; ---- OAM DMA every frame ----
  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA

  ; ---- keep scroll stable ----
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

   lda #$00
sta $2003
lda #$02
sta $4014


  inc frame_lo
  lda #$01
  sta nmi_ready

  pla
  tay
  pla
  tax
  pla
  rti


IRQ:
  rti

; ----------------------------
; HELPERS
; ----------------------------
WaitVBlank:
  lda PPUSTATUS
@loop:
  lda PPUSTATUS
  bpl @loop
  rts

; Safe RAM clear: skip stack page ($0100) and OAM shadow page ($0200)
ClearRAM:
  lda #$00
  tax
@clr:
  sta $0000,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  sta $0600,x
  sta $0700,x
  inx
  bne @clr
  rts

ClearOAM:
  lda #$FF
  ldx #$00
@o:
  sta OAM_BUF,x
  inx
  inx
  inx
  inx
  bne @o
  rts

ClearNametable0:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$00        ; tile index 0
  ldx #$40        ; 1024 bytes (tiles+attrs)
  ldy #$00
@page:
@byte:
  sta PPUDATA
  iny
  bne @byte
  dex
  bne @page

  lda PPUSTATUS   ; clear latch after big VRAM write
  rts

InitPalettes:
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  ldx #$00
@p:
  lda Palettes,x
  sta PPUDATA
  inx
  cpx #$20
  bne @p
  rts




ReadController1:
  lda pad1
  sta pad1_prev

  lda #$01
  sta JOY1
  lda #$00
  sta JOY1

  ldx #$08
  lda #$00
  sta pad1
@r:
  lda JOY1
  and #$01
  lsr a
  rol pad1
  dex
  bne @r

  lda pad1
  eor pad1_prev
  and pad1
  sta pad1_new
  rts


Spr_Init:
  lda #$FF
  ldx #$00
@loop:
  sta OAM_BUF, x
  inx
  inx
  inx
  inx
  bne @loop
  rts

Spr_BeginFrame:
  lda #$00
  sta spr_i
  rts

; Append one sprite from spr_*0
; Clobbers: A, X
Spr_Put:
  ldx spr_i

  lda spr_y0
  sta OAM_BUF+0, x

  lda spr_tile0
  sta OAM_BUF+1, x

  lda spr_attr0
  sta OAM_BUF+2, x

  lda spr_x0
  sta OAM_BUF+3, x

  ; advance cursor by 4
  lda spr_i
  clc
  adc #$04
  sta spr_i
  rts


; ------------------------------------------------------------
; Spr_Put2x2
; Draw a 2×2 metasprite using four tile IDs in a row:
;   tl, tr, bl, br (in spr_tile0..spr_tile3)
;
; Inputs:
;   spr_x0, spr_y0 = top-left position
;   spr_attr0 = attr for all 4
;   spr_tile0..spr_tile3 = tile IDs
; Clobbers: A, X
; ------------------------------------------------------------


Spr_Put2x2:
  ; TL
  jsr Spr_Put

  ; TR
  lda spr_x0
  clc
  adc #$08
  sta spr_x0
  lda spr_tile1
  sta spr_tile0
  jsr Spr_Put

  ; BL
  lda spr_x0
  sec
  sbc #$08
  sta spr_x0
  lda spr_y0
  clc
  adc #$08
  sta spr_y0
  lda spr_tile2
  sta spr_tile0
  jsr Spr_Put

  ; BR
  lda spr_x0
  clc
  adc #$08
  sta spr_x0
  lda spr_tile3
  sta spr_tile0
  jsr Spr_Put

  ; restore spr_x0/spr_y0 to top-left (optional but nice)
  lda spr_x0
  sec
  sbc #$08
  sta spr_x0
  lda spr_y0
  sec
  sbc #$08
  sta spr_y0

  rts

; ----------------------------
; VECTORS
; ----------------------------
.segment "VECTORS"
  .word NMI
  .word RESET
  .word IRQ

