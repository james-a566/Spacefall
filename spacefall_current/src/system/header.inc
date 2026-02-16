; ============================================================
; [HDR] iNES Header
; ============================================================
.segment "HEADER"
  .byte "NES", $1A
  .byte $02          ; 32KB PRG (2 * 16KB)
  .byte $01          ; 8KB CHR  (1 * 8KB)
  .byte $01          ; mapper 0, vertical mirroring
  .byte $00
  .res 8, $00