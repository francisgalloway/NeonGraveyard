class_name Iso
extends RefCounted
## Isometric grid maths. A cell's world position is the centre of its floor diamond.
##
## TILE_W x TILE_H is the footprint of one grid cell (2:1). SPRITE_ORIGIN is the
## pixel inside the 256x512 Kenney sprites that sits on the centre of the cell
## they occupy. Both were measured from the pack; tweak here if things look off.

const TILE_W := 128.0
const TILE_H := 64.0
const SPRITE_ORIGIN := Vector2(128, 446)


static func cell_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


static func world_to_cell(p: Vector2) -> Vector2i:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2i(roundi((a + b) * 0.5), roundi((b - a) * 0.5))
