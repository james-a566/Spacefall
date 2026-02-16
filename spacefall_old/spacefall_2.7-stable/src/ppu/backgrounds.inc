.segment "CODE"

; ------------------------------------------------------------
; DrawStarfieldNT0  ($2000 tile area only) 32x30 = 960 bytes
; ------------------------------------------------------------
; ZP temps needed:
;   tmp0 = random byte
;   tmp2 = row counter

DrawStarfieldNT0:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$1E          ; 30 rows
  sta tmp2

@row:
  ldy #$20          ; 32 columns
@col:
  jsr NextRand
  sta tmp0

  lda tmp0
  and #$1F          ; 1/32 chance of star
  bne @empty

    lda tmp0
    eor rng_hi
    and #$03
    tax
    lda StarTiles,x
    jmp @write



@empty:
  lda #$00          ; blank tile

@write:
  sta PPUDATA
  dey
  bne @col

  dec tmp2
  bne @row

  lda PPUSTATUS
  rts


; ------------------------------------------------------------
; DrawStarfieldNT1  ($2400 tile area only) 32x30 = 960 bytes
; ------------------------------------------------------------
DrawStarfieldNT1:
  lda PPUSTATUS
  lda #$24
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #$1E
  sta tmp2

@row:
  ldy #$20
@col:
  jsr NextRand
  sta tmp0

  lda tmp0
  and #$1F
  bne @empty

    lda tmp0
    and #$03
    tax
    lda StarTiles,x
    jmp @write

@empty:
  lda #$00

@write:
  sta PPUDATA
  dey
  bne @col

  dec tmp2
  bne @row

  lda PPUSTATUS
  rts
