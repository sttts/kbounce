# wall.gd - Wall entity that extends from click point
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

class_name Wall
extends Node2D

## Emitted when wall is destroyed by a ball (costs a life)
signal died

## Wall direction
enum Direction { UP = 0, DOWN = 1, LEFT = 2, RIGHT = 3 }

## Reference to the game board
var board: Board

## Direction this wall extends
var direction: Direction = Direction.UP

## Wall velocity in tiles per tick
var wall_velocity := 0.125

## Whether wall is currently being built
var _building := false

## Starting tile position
var start_x := 0
var start_y := 0

## Current bounding rect in tile coordinates
var _bounding_rect := Rect2()


## Current tile size
var _tile_size := Vector2i(32, 32)

## Sprite references
@onready var _sprite: Sprite2D = $Sprite2D


func _ready():
	visible = false


## Start building wall from a tile position
func build(x: int, y: int):
	if _building:
		return  # Already building

	start_x = x
	start_y = y
	_building = true
	visible = true

	# Initialize bounding rect covering the full starting tile.
	# Tips are at opposite edges: UP at top (position.y), DOWN at bottom (end.y)
	# Direction-aware collision checking only looks at the tip.
	_bounding_rect = Rect2(x, y, 1, 1)

	AudioManager.play("wallstart")
	update_visuals()


## Get current bounding rectangle
func bounding_rect() -> Rect2:
	return _bounding_rect


## Resize wall to match tile size
func resize(tile_size: Vector2i):
	_tile_size = tile_size


## Update visual representation
func update_visuals():
	if not _building or not board:
		return

	# Update position (floor to avoid wobbling with pixel calculations)
	var pos := board.map_position(_bounding_rect.position)
	position = Vector2(floor(pos.x), floor(pos.y))

	# Trigger redraw
	queue_redraw()


## Custom drawing for the wall
func _draw():
	if not _building:
		return

	var wall_h := ThemeManager.get_texture("wall_h")  # Inner tile for LEFT/RIGHT
	var wall_v := ThemeManager.get_texture("wall_v")  # Inner tile for UP/DOWN
	var wall_end := ThemeManager.get_texture("wall_end")  # Tip tile for all directions

	var tw := _tile_size.x
	var th := _tile_size.y

	# Calculate pixel dimensions based on floored positions to avoid wobbling
	var start_x := int(floor(_bounding_rect.position.x * tw))
	var start_y := int(floor(_bounding_rect.position.y * th))
	var end_x := int(floor(_bounding_rect.end.x * tw))
	var end_y := int(floor(_bounding_rect.end.y * th))

	var pixel_width := end_x - start_x
	var pixel_height := end_y - start_y

	if pixel_width == 0 and pixel_height == 0:
		return

	# Static grid-aligned inner tiles, complete tip tile at exact sub-pixel position
	match direction:
		Direction.UP:
			if wall_v:
				var full_tiles := pixel_height / th
				var partial := pixel_height % th

				# Inner tiles below the tip (grid-aligned)
				for i in range(full_tiles):
					draw_texture_rect(wall_v, Rect2(0, partial + i * th, tw, th), false)

				# Full tip tile at exact sub-pixel position (may extend beyond bounding box)
				if wall_end:
					# Tip position: fractional pixel offset from node position
					var world_tip_y: float = _bounding_rect.position.y * th
					var exact_tip_y: float = world_tip_y - floor(world_tip_y)
					draw_texture_rect(wall_end, Rect2(0, exact_tip_y, tw, th), false)

		Direction.DOWN:
			if wall_v:
				var full_tiles := pixel_height / th
				var partial := pixel_height % th

				# Inner tiles from top (grid-aligned)
				for i in range(full_tiles):
					draw_texture_rect(wall_v, Rect2(0, i * th, tw, th), false)

				# Full tip tile at exact sub-pixel position
				if wall_end:
					# Tip at bottom: world end minus node position minus tile height
					var world_end_y: float = _bounding_rect.end.y * th
					var node_y: float = floor(_bounding_rect.position.y * th)
					var exact_tip_y: float = world_end_y - node_y - th
					draw_texture_rect(wall_end, Rect2(0, exact_tip_y, tw, th), false)

		Direction.LEFT:
			if wall_h:
				var full_tiles := pixel_width / tw
				var partial := pixel_width % tw

				# Inner tiles to the right (grid-aligned)
				for i in range(full_tiles):
					draw_texture_rect(wall_h, Rect2(partial + i * tw, 0, tw, th), false)

				# Full tip tile at exact sub-pixel position
				if wall_end:
					# Tip position: fractional pixel offset from node position
					var world_tip_x: float = _bounding_rect.position.x * tw
					var exact_tip_x: float = world_tip_x - floor(world_tip_x)
					draw_texture_rect(wall_end, Rect2(exact_tip_x, 0, tw, th), false)

		Direction.RIGHT:
			if wall_h:
				var full_tiles := pixel_width / tw
				var partial := pixel_width % tw

				# Inner tiles from left (grid-aligned)
				for i in range(full_tiles):
					draw_texture_rect(wall_h, Rect2(i * tw, 0, tw, th), false)

				# Full tip tile at exact sub-pixel position
				if wall_end:
					# Tip at right: world end minus node position minus tile width
					var world_end_x: float = _bounding_rect.end.x * tw
					var node_x: float = floor(_bounding_rect.position.x * tw)
					var exact_tip_x: float = world_end_x - node_x - tw
					draw_texture_rect(wall_end, Rect2(exact_tip_x, 0, tw, th), false)


## Wall completed successfully
func _finish():
	AudioManager.play("wallend")


## Wall destroyed by ball (costs a life)
func die():
	AudioManager.play("death")
	died.emit()


## Wall destroyed by wall-to-wall collision (no life cost)
func die_from_wall():
	AudioManager.play("death")
