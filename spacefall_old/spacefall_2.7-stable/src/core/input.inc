.segment "CODE"

; ============================================================
; INPUT
;
; Conventions:
;   pad1       = current button state (bitmask)
;   pad1_prev  = last frame state
;   pad1_new   = buttons newly pressed this frame (rising edges)
;
; NOTE:
;   ReadController1 reads raw input only.
;   Any “meaning” (pause/start/debug toggles) should be handled elsewhere,
;   but this project currently also stores a couple debug toggles nearby.
; ============================================================

; ------------------------------------------------------------
; ReadController1
; - Latches controller 1, reads 8 buttons into pad1
; - Produces pad1_new = newly pressed buttons this frame
; ------------------------------------------------------------
ReadController1:
  lda pad1
  sta pad1_prev

  lda #$01
  sta JOY1
  lda #$00
  sta JOY1
  ; NES controller serial read: 8 bits, LSB first.
  ; Bit order after loop matches BTN_* constants used elsewhere.
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



