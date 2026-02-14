.segment "CODE"

WaitFrame:
  lda #$00
  sta nmi_ready
@spin:
  lda nmi_ready
  beq @spin
  rts

WaitVBlank:
  lda PPUSTATUS
@loop:
  lda PPUSTATUS
  bpl @loop
  rts