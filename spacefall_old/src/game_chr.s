; src/game_chr.s — game sprite tiles
; Assumes CHR layout places game tiles starting at TILE_PLAYER ($23)

; Tile $23: player (TILE_PLAYER)
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Tile $24: object (TILE_OBJECT)
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Tile $25: alien space ship (TILE_SHIP_A)
.byte $18,$24,$42,$66,$81,$FF,$A5,$5A
.byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $26 Player_TL
.byte $00,$00,$01,$03,$03,$03,$0A,$0D
.byte $00,$00,$00,$00,$0D,$08,$01,$2B

; Tile $27 Player_TR
.byte $00,$00,$00,$80,$80,$80,$A0,$60
.byte $00,$00,$00,$00,$00,$20,$00,$A8

; Tile $28 Player_BL
.byte $2F,$3C,$30,$20,$00,$00,$00,$00
.byte $00,$02,$06,$00,$00,$00,$00,$00

; Tile $29 Player_BR
.byte $E8,$78,$18,$08,$00,$00,$00,$00
.byte $00,$80,$C0,$00,$00,$00,$00,$00