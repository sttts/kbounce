# ball.gd - Ball entity with physics and collision
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

class_name Ball
extends Sprite2D

## Animation delay in ticks
const BALL_ANIM_DELAY := 4

## Ball size relative to tile (0.8 = 80% of tile size)
const BALL_RELATIVE_SIZE := 0.8

## Sound delay to prevent spam (in ticks)
const SOUND_DELAY := 4

## Reference to the game board
var board: Board

## Position in tile coordinates (not pixels)
var relative_pos := Vector2.ZERO

## Velocity in tiles per tick
var velocity := Vector2.ZERO

## Current tile size in pixels
var _tile_size := Vector2i(32, 32)

## Size in pixels
var _size := Vector2i(26, 26)

## Sound cooldown counter
var _sound_delay := 0

## Animation frame counter
var _anim_counter := 0

## Number of animation frames
var _frame_count := 1


func _ready():
	# Load ball texture from theme
	texture = ThemeManager.get_texture("ball")

	# Get frame count from sprite
	if texture:
		# Assuming horizontal sprite sheet
		var frame_width := texture.get_height()  # Square frames
		_frame_count = texture.get_width() / frame_width if frame_width > 0 else 1
	else:
		push_warning("Ball: No texture loaded from theme")

	# Transparency is baked into the sprite now


## Set ball position in tile coordinates
func set_relative_pos(x: float, y: float):
	relative_pos = Vector2(x, y)


## Resize ball to match tile size
func resize(tile_size: Vector2i):
	_tile_size = tile_size
	_size = Vector2i(int(tile_size.x * BALL_RELATIVE_SIZE),
					 int(tile_size.y * BALL_RELATIVE_SIZE))

	# Update sprite scale if needed
	if texture:
		var frame_size := texture.get_height()  # Assuming square frames
		if frame_size > 0:
			var scale_factor := float(_size.x) / float(frame_size)
			scale = Vector2(scale_factor, scale_factor)


## Set a random animation frame
func set_random_frame():
	if _frame_count > 1:
		_anim_counter = randi() % (_frame_count * BALL_ANIM_DELAY)


## Handle collision response (sound effects only - JS handles physics)
func collide(hit: bool, hit_wall: bool):
	# Decrement sound delay
	if _sound_delay > 0:
		_sound_delay -= 1

	if not hit or _sound_delay > 0:
		return

	# Play sound based on what was hit
	if hit_wall:
		AudioManager.play("ball_bounce_wall")
	else:
		AudioManager.play("ball_bounce")
	_sound_delay = SOUND_DELAY


## Update visual representation
func update_visuals():
	# Update screen position (offset by half ball size since sprite is centered)
	if board:
		var top_left := board.map_position(relative_pos)
		position = top_left + Vector2(_size) / 2.0

	# Update animation frame
	_anim_counter += 1
	if _anim_counter >= _frame_count * BALL_ANIM_DELAY:
		_anim_counter = 0

	# Update sprite frame (for sprite sheet)
	var current_frame := _anim_counter / BALL_ANIM_DELAY
	if texture and _frame_count > 1:
		var frame_width := texture.get_height()
		region_enabled = true
		region_rect = Rect2(current_frame * frame_width, 0, frame_width, frame_width)
