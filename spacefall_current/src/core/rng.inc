.segment "CODE"

; ============================================================
; RNG (RANDOM NUMBER GENERATION)
;
; Implementation:
;   - 16-bit Galois LFSR stored in rng_hi:rng_lo
;   - NextRand advances the LFSR and returns rng_lo in A
;
; Usage pattern:
;   - NMI calls NextRand every frame to keep entropy moving,
;     even during pauses or menus.
;   - Gameplay code calls NextRand when a random decision is needed.
;
; SAFETY:
;   - The all-zero state is invalid for an LFSR.
;   - Code explicitly re-seeds if rng_hi|rng_lo == 0.
; ============================================================

; ------------------------------------------------------------
; NextRand
; - 16-bit Galois LFSR, right shift
; - taps 0xB400 (xor into high byte only)
; - returns A = rng_lo
; ------------------------------------------------------------
NextRand:
  lda rng_hi
  ora rng_lo
  bne :+
    lda #$A5
    sta rng_hi
    lda #$5A
    sta rng_lo
:
  lda rng_hi
  lsr
  sta rng_hi

  lda rng_lo
  ror
  sta rng_lo

  bcc @done
  lda rng_hi
  eor #$B4
  sta rng_hi

@done:
   lda rng_lo
  eor rng_hi
  rts


; returns A = random X in [$08..$E8] aligned to 8
RandX_8px:
@try:
  jsr NextRand
  and #$F8
  cmp #$08
  bcc @try
  cmp #$F0        ; reject $F0..$F8 to avoid right-edge weirdness
  bcs @try
  rts

; IN:  A = threshold (0..255)
; OUT: C=1 if hit (rand < threshold), C=0 otherwise
RandBelowA:
  sta tmp0
  jsr NextRand
  cmp tmp0
  bcc @hit
  clc
  rts
@hit:
  sec
  rts

Rand0to9:
@try:
  jsr NextRand
  cmp #250        ; 250..255 rejected (6 values) so 0..249 maps evenly to 0..9
  bcs @try
  ; now A % 10 without division:
  ; cheap method: repeated subtract (fast enough here)
  ldx #0
@sub:
  cmp #10
  bcc @done
  sbc #10
  inx
  bne @sub
@done:
  rts             ; A is 0..9



; ------------------------------------------------------------
; ReseedRNG
; - Initializes rng_hi:rng_lo to a non-zero value
; - Called on title->start and occasionally for safety
; ------------------------------------------------------------
ReseedRNG:
  lda rng_lo
  eor frame_lo
  eor pad1_new      ; include edge, not held
  ora #$01
  sta rng_lo

  lda rng_hi
  eor frame_hi
  eor pad1
  sta rng_hi

  lda rng_lo
  ora rng_hi
  bne :+
    lda #$A7
    sta rng_lo
    lda #$1D
    sta rng_hi
:
  rts

ReseedCatchSpawn:
  jsr NextRand
  and #$7F                  ; 0..127
  ; reduce to 0..(CATCH_SPAWN_VAR-1) if VAR is power-of-two; for 90 it isn't.
  clc
  adc #CATCH_SPAWN_MIN
  sta catch_cd
  rts