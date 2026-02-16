.segment "CODE"

Pause_NMI_Update:
  lda pause_dirty
  bne :+
    rts
:
  lda #$00
  sta pause_dirty

  lda PPUSTATUS
  lda #PAUSE_NT_HI
  sta PPUADDR
  lda #PAUSE_NT_LO
  sta PPUADDR

  lda pause_show
  bne @draw

@erase:
  lda #$00
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  rts

@draw:
  lda #TILE_P
  sta PPUDATA
  lda #TILE_A
  sta PPUDATA
  lda #TILE_U
  sta PPUDATA
  lda #TILE_S
  sta PPUDATA
  lda #TILE_E
  sta PPUDATA
  rts