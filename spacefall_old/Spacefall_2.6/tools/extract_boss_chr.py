from pathlib import Path

TILE_SIZE = 16

# --- config ---
chr_path = Path("src/boss_ship.chr")     # <-- change name if different
out_path = Path("src/boss_tiles.inc")    # output include

# tiles you listed (3x3 laid out in boss_ship.chr)
tiles = [0x04,0x05,0x06, 0x14,0x15,0x16, 0x24,0x25,0x26]

data = chr_path.read_bytes()
if len(data) != 8192:
    raise SystemExit(f"{chr_path} is {len(data)} bytes, expected 8192 (8KB CHR)")

lines = []
lines.append("; Auto-generated from boss_ship.chr")
lines.append("; Tiles: " + " ".join(f"${t:02X}" for t in tiles))
lines.append("")

for t in tiles:
    base = t * TILE_SIZE
    chunk = data[base:base+TILE_SIZE]
    # format as 16 bytes (one tile)
    bytestr = ",".join(f"${b:02X}" for b in chunk)
    lines.append(f"  .byte {bytestr}   ; tile ${t:02X}")

out_path.write_text("\n".join(lines) + "\n")
print(f"Wrote {out_path} with {len(tiles)} tiles ({len(tiles)*16} bytes)")
