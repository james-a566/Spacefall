; src/chr.s — final CHR-ROM layout (8KB)
.segment "CHARS"
CHR_START:

; --- HUD tiles first (keep their IDs stable) ---
.include "lib/hud/hud_font.s"

; --- Game tiles follow (player/object/etc.) ---
.include "src/game_chr.s"

CHR_END:
.res 8192 - (CHR_END - CHR_START), $00
