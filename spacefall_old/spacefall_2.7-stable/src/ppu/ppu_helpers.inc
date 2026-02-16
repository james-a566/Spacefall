.segment "CODE"

; call before any big VRAM write (nametables, attributes, etc.)
PPU_BeginVRAM:
  ; disable NMI using shadow (DO NOT read $2000)
  lda ppuctrl_shadow
  and #%01111111
  sta ppuctrl_shadow
  sta PPUCTRL

  ; rendering off
  lda #$00
  sta PPUMASK

  ; wait for vblank boundary
  jsr WaitVBlank

  ; clear latch + set scroll to 0,0 (avoids "streak" artifacts)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL
  rts

PPU_EndVRAM:
  ; clear latch again (safe)
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  ; re-enable NMI using shadow (DO NOT read $2000)
  lda ppuctrl_shadow
  ora #%10000000
  sta ppuctrl_shadow
  sta PPUCTRL

  ; rendering on
  lda #PPUMASK_BG_SPR
  sta PPUMASK
  rts

ClearNametable0:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$00        ; tile index 0
  ldx #$04        ; 4 * 256 = 1024 bytes
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

ClearAttributesNT0:
  lda PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$C0
  sta PPUADDR
  ldx #$40          ; 64 bytes
  lda #$00
@loop:
  sta PPUDATA
  dex
  bne @loop
  rts


ClearNametable1:
  lda PPUSTATUS
  lda #$24
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$00
  ldx #$04
  ldy #$00
@page:
@byte:
  sta PPUDATA
  iny
  bne @byte
  dex
  bne @page

  lda PPUSTATUS
  rts


ClearAttributesNT1:
  lda PPUSTATUS
  lda #$27
  sta PPUADDR
  lda #$C0
  sta PPUADDR
  ldx #$40
  lda #$00
@loop:
  sta PPUDATA
  dex
  bne @loop
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

  ; Top UI band on NT0: set attribute bytes 0..7 to palette 1 ($55)
SetUIAttrsNT0:
  lda PPUSTATUS
  lda #$23
  sta PPUADDR
  lda #$C0
  sta PPUADDR

  ldx #$08
  lda #$55        ; palette 1 everywhere in those blocks
@loop:
  sta PPUDATA
  dex
  bne @loop
  rts

; Same for NT1 (attributes at $27C0)
SetUIAttrsNT1:
  lda PPUSTATUS
  lda #$27
  sta PPUADDR
  lda #$C0
  sta PPUADDR

  ldx #$08
  lda #$55
@loop:
  sta PPUDATA
  dex
  bne @loop
  rts

; ------------------------------------------------------------
; InitPalettes_Safe
; - Writes palettes but skips $3F10 (mirror of $3F00 on NES)
; - Palettes layout assumed:
;     00..0F = BG palettes (16 bytes, includes universal at [0])
;     10..1F = SPR palettes (16 bytes, includes mirror at [16])
; ------------------------------------------------------------
InitPalettes_Safe:
  ; --- write universal BG color ($3F00) ---
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda Palettes+0
  sta PPUDATA

  ; --- write BG colors 1..15 to $3F01..$3F0F ---
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$01
  sta PPUADDR

  ldx #$01
@bg:
  lda Palettes,x          ; Palettes[1..15]
  sta PPUDATA
  inx
  cpx #$10
  bne @bg

  ; --- write SPR colors 1..15 to $3F11..$3F1F (skip $3F10) ---
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$11
  sta PPUADDR

  ldx #$11
@spr:
  lda Palettes,x          ; Palettes[17..31]
  sta PPUDATA
  inx
  cpx #$20
  bne @spr

  rts
