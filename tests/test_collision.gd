# test_collision.gd - Unit tests for ball collision and reflection logic
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted

const TestRunner = preload("res://tests/test_runner.gd")


# =============================================================================
# Tests for Collision.calculate_normal (intersection geometry based)
# =============================================================================

func test_normal_ball_hits_wall_from_left():
	# Ball overlapping wall from the left side
	var ball := Rect2(5.0, 5.0, 1.0, 1.0)  # Ball from (5,5) to (6,6)
	var wall := Rect2(5.5, 5.0, 2.0, 1.0)  # Wall from (5.5,5) to (7.5,6)

	var normal := Collision.calculate_normal(ball, wall)

	# Intersection center (5.5-6, 5-6) is left of wall center (6.5, 5.5)
	return TestRunner.assert_eq(normal.x, -1.0, "X normal (hit from left)")


func test_normal_ball_hits_wall_from_right():
	# Ball overlapping wall from the right side
	var ball := Rect2(6.5, 5.0, 1.0, 1.0)  # Ball from (6.5,5) to (7.5,6)
	var wall := Rect2(5.0, 5.0, 2.0, 1.0)  # Wall from (5,5) to (7,6)

	var normal := Collision.calculate_normal(ball, wall)

	# Intersection center is right of wall center
	return TestRunner.assert_eq(normal.x, 1.0, "X normal (hit from right)")


func test_normal_ball_hits_wall_from_top():
	# Ball overlapping wall from the top
	var ball := Rect2(5.0, 5.0, 1.0, 1.0)  # Ball from (5,5) to (6,6)
	var wall := Rect2(5.0, 5.5, 1.0, 2.0)  # Wall from (5,5.5) to (6,7.5)

	var normal := Collision.calculate_normal(ball, wall)

	# Intersection center is above wall center
	return TestRunner.assert_eq(normal.y, -1.0, "Y normal (hit from top)")


func test_normal_ball_hits_wall_from_bottom():
	# Ball overlapping wall from the bottom
	var ball := Rect2(5.0, 6.5, 1.0, 1.0)  # Ball from (5,6.5) to (6,7.5)
	var wall := Rect2(5.0, 5.0, 1.0, 2.0)  # Wall from (5,5) to (6,7)

	var normal := Collision.calculate_normal(ball, wall)

	# Intersection center is below wall center
	return TestRunner.assert_eq(normal.y, 1.0, "Y normal (hit from bottom)")


func test_normal_ball_hits_corner():
	# Ball hitting corner - intersection in corner quadrant
	var ball := Rect2(5.0, 5.0, 1.0, 1.0)  # Ball from (5,5) to (6,6)
	var wall := Rect2(5.5, 5.5, 2.0, 2.0)  # Wall from (5.5,5.5) to (7.5,7.5)

	var normal := Collision.calculate_normal(ball, wall)

	# Intersection center is top-left of wall center
	return TestRunner.assert_eq(normal.x, -1.0, "X normal (corner)") + \
		   TestRunner.assert_eq(normal.y, -1.0, "Y normal (corner)")


func test_normal_ball_centered_on_wall():
	# Ball centered on wall - intersection center equals wall center
	var ball := Rect2(5.5, 5.5, 1.0, 1.0)  # Ball from (5.5,5.5) to (6.5,6.5)
	var wall := Rect2(5.0, 5.0, 2.0, 2.0)  # Wall from (5,5) to (7,7), center at (6,6)

	var normal := Collision.calculate_normal(ball, wall)

	# Intersection center equals wall center, no clear direction
	return TestRunner.assert_eq(normal, Vector2.ZERO, "Centered normal")


func test_normal_no_collision():
	# Ball not colliding with wall
	var ball := Rect2(5.0, 5.0, 1.0, 1.0)
	var wall := Rect2(10.0, 10.0, 1.0, 1.0)  # Far away

	var normal := Collision.calculate_normal(ball, wall)

	# No collision, normal should be zero
	return TestRunner.assert_eq(normal, Vector2.ZERO, "No collision normal")


# =============================================================================
# Tests for ball reflection logic
# =============================================================================

func test_reflection_horizontal():
	# Ball moving right, hits wall, should reverse X
	var velocity := Vector2(0.125, 0.125)
	var normal := Vector2(-1, 0)  # Wall to the right

	var reflected := _apply_reflection(velocity, normal)

	return TestRunner.assert_eq(reflected.x, -0.125, "Reflected X") + \
		   TestRunner.assert_eq(reflected.y, 0.125, "Y unchanged")


func test_reflection_vertical():
	# Ball moving down, hits floor, should reverse Y
	var velocity := Vector2(0.125, 0.125)
	var normal := Vector2(0, -1)  # Floor below

	var reflected := _apply_reflection(velocity, normal)

	return TestRunner.assert_eq(reflected.x, 0.125, "X unchanged") + \
		   TestRunner.assert_eq(reflected.y, -0.125, "Reflected Y")


func test_reflection_corner():
	# Ball hits corner, should reverse both
	var velocity := Vector2(0.125, 0.125)
	var normal := Vector2(-1, -1)  # Corner

	var reflected := _apply_reflection(velocity, normal)

	return TestRunner.assert_eq(reflected.x, -0.125, "Reflected X") + \
		   TestRunner.assert_eq(reflected.y, -0.125, "Reflected Y")


func test_reflection_already_moving_away():
	# Ball already moving away from wall, no reflection
	var velocity := Vector2(-0.125, 0)  # Moving left
	var normal := Vector2(-1, 0)  # Wall to the right

	var reflected := _apply_reflection(velocity, normal)

	# Should not change (already moving away)
	return TestRunner.assert_eq(reflected.x, -0.125, "X unchanged (moving away)")


# =============================================================================
# Tests for trap detection
# =============================================================================

func test_trap_ball_near_top_border_wall_going_down():
	# Ball is near top border (y=2), wall going DOWN
	# Ball has only 1 tile of escape space -> trapped
	var tiles := _create_empty_tiles()
	var ball_y := 2  # Near top border (border at y=0)
	var is_trapped := _check_trapped(tiles, 10, ball_y, Wall.Direction.DOWN)

	return TestRunner.assert_true(is_trapped, "Ball near top border should be trapped")


func test_trap_ball_far_from_border_wall_going_down():
	# Ball is far from top border (y=10), wall going DOWN
	# Ball has plenty of escape space -> not trapped
	var tiles := _create_empty_tiles()
	var ball_y := 10  # Far from border
	var is_trapped := _check_trapped(tiles, 10, ball_y, Wall.Direction.DOWN)

	return TestRunner.assert_true(not is_trapped, "Ball far from border should not be trapped")


func test_trap_ball_near_bottom_border_wall_going_up():
	# Ball near bottom border, wall going UP
	var tiles := _create_empty_tiles()
	var ball_y := 17  # Near bottom (border at y=19)
	var is_trapped := _check_trapped(tiles, 10, ball_y, Wall.Direction.UP)

	return TestRunner.assert_true(is_trapped, "Ball near bottom border should be trapped")


func test_trap_ball_near_left_border_wall_going_right():
	# Ball near left border, wall going RIGHT
	var tiles := _create_empty_tiles()
	var ball_x := 2  # Near left border
	var is_trapped := _check_trapped(tiles, ball_x, 10, Wall.Direction.RIGHT)

	return TestRunner.assert_true(is_trapped, "Ball near left border should be trapped")


func test_trap_ball_near_right_border_wall_going_left():
	# Ball near right border, wall going LEFT
	var tiles := _create_empty_tiles()
	var ball_x := 29  # Near right border (border at x=31)
	var is_trapped := _check_trapped(tiles, ball_x, 10, Wall.Direction.LEFT)

	return TestRunner.assert_true(is_trapped, "Ball near right border should be trapped")


func test_trap_ball_blocked_by_filled_area():
	# Ball in middle, but filled area blocks escape
	var tiles := _create_empty_tiles()
	# Fill tiles above the ball position
	for y in range(1, 8):
		tiles[10][y] = Board.TileType.WALL
	var ball_y := 9  # Ball just below filled area
	var is_trapped := _check_trapped(tiles, 10, ball_y, Wall.Direction.DOWN)

	return TestRunner.assert_true(is_trapped, "Ball blocked by filled area should be trapped")


func test_trap_ball_has_escape_route():
	# Ball with clear escape route
	var tiles := _create_empty_tiles()
	var ball_y := 10  # Middle of board
	var is_trapped := _check_trapped(tiles, 15, ball_y, Wall.Direction.DOWN)

	return TestRunner.assert_true(not is_trapped, "Ball with escape route should not be trapped")


# =============================================================================
# Tests for wall-to-wall collision helpers
# =============================================================================

func test_paired_walls_up_down():
	# UP and DOWN from same origin are paired
	var result := _are_paired_walls(10, 10, Wall.Direction.UP, 10, 10, Wall.Direction.DOWN)
	return TestRunner.assert_true(result, "UP/DOWN from same origin should be paired")


func test_paired_walls_left_right():
	# LEFT and RIGHT from same origin are paired
	var result := _are_paired_walls(10, 10, Wall.Direction.LEFT, 10, 10, Wall.Direction.RIGHT)
	return TestRunner.assert_true(result, "LEFT/RIGHT from same origin should be paired")


func test_not_paired_different_origin():
	# Same directions but different origins are not paired
	var result := _are_paired_walls(10, 10, Wall.Direction.UP, 15, 10, Wall.Direction.DOWN)
	return TestRunner.assert_true(not result, "Different origins should not be paired")


func test_not_paired_same_direction():
	# Same direction walls are not paired
	var result := _are_paired_walls(10, 10, Wall.Direction.UP, 10, 10, Wall.Direction.UP)
	return TestRunner.assert_true(not result, "Same direction should not be paired")


func test_not_paired_perpendicular():
	# UP and LEFT are not paired (perpendicular)
	var result := _are_paired_walls(10, 10, Wall.Direction.UP, 10, 10, Wall.Direction.LEFT)
	return TestRunner.assert_true(not result, "Perpendicular walls should not be paired")


func test_tip_rect_up():
	var rect := Rect2(5, 3, 1, 5)  # Wall from y=3 to y=8
	var tip := _get_tip_rect(rect, Wall.Direction.UP)
	# UP wall tip is at the top (y=3)
	return TestRunner.assert_approx(tip.position.y, 3.0, 0.01, "Tip Y position") + \
		   TestRunner.assert_approx(tip.size.y, 0.1, 0.01, "Tip height")


func test_tip_rect_down():
	var rect := Rect2(5, 3, 1, 5)  # Wall from y=3 to y=8
	var tip := _get_tip_rect(rect, Wall.Direction.DOWN)
	# DOWN wall tip is at the bottom (y=8 - 0.1)
	return TestRunner.assert_approx(tip.position.y, 7.9, 0.01, "Tip Y position")


func test_tip_rect_left():
	var rect := Rect2(3, 5, 5, 1)  # Wall from x=3 to x=8
	var tip := _get_tip_rect(rect, Wall.Direction.LEFT)
	# LEFT wall tip is at the left (x=3)
	return TestRunner.assert_approx(tip.position.x, 3.0, 0.01, "Tip X position") + \
		   TestRunner.assert_approx(tip.size.x, 0.1, 0.01, "Tip width")


func test_tip_rect_right():
	var rect := Rect2(3, 5, 5, 1)  # Wall from x=3 to x=8
	var tip := _get_tip_rect(rect, Wall.Direction.RIGHT)
	# RIGHT wall tip is at the right (x=8 - 0.1)
	return TestRunner.assert_approx(tip.position.x, 7.9, 0.01, "Tip X position")


func test_rects_share_tile_overlapping():
	var rect1 := Rect2(5.0, 5.0, 1.0, 1.0)  # Tile (5,5)
	var rect2 := Rect2(5.5, 5.5, 1.0, 1.0)  # Overlaps into tile (5,5)
	return TestRunner.assert_true(_rects_share_tile(rect1, rect2), "Overlapping rects should share tile")


func test_rects_share_tile_same_tile():
	var rect1 := Rect2(5.1, 5.1, 0.3, 0.3)  # Inside tile (5,5)
	var rect2 := Rect2(5.5, 5.5, 0.3, 0.3)  # Also inside tile (5,5)
	return TestRunner.assert_true(_rects_share_tile(rect1, rect2), "Rects in same tile should share")


func test_rects_share_tile_separate_tiles():
	# Rects in tiles that don't touch (2 tiles apart)
	var rect1 := Rect2(5.0, 5.0, 0.8, 0.8)  # Tile (5,5)
	var rect2 := Rect2(7.0, 5.0, 0.8, 0.8)  # Tile (7,5) - 2 tiles apart
	return TestRunner.assert_true(not _rects_share_tile(rect1, rect2), "Separate tiles should not share")


func test_rects_share_tile_distant():
	var rect1 := Rect2(5.0, 5.0, 1.0, 1.0)
	var rect2 := Rect2(10.0, 10.0, 1.0, 1.0)
	return TestRunner.assert_true(not _rects_share_tile(rect1, rect2), "Distant rects should not share tile")


func test_get_tip_tile_up():
	var rect := Rect2(5.0, 3.0, 1.0, 5.0)  # Wall from (5,3) to (6,8)
	var tip := _get_tip_tile(rect, Wall.Direction.UP)
	return TestRunner.assert_eq(tip, Vector2i(5, 3), "UP wall tip tile")


func test_get_tip_tile_down():
	var rect := Rect2(5.0, 3.0, 1.0, 5.0)  # Wall from (5,3) to (6,8)
	var tip := _get_tip_tile(rect, Wall.Direction.DOWN)
	return TestRunner.assert_eq(tip, Vector2i(5, 7), "DOWN wall tip tile")


func test_get_tip_tile_left():
	var rect := Rect2(3.0, 5.0, 5.0, 1.0)  # Wall from (3,5) to (8,6)
	var tip := _get_tip_tile(rect, Wall.Direction.LEFT)
	return TestRunner.assert_eq(tip, Vector2i(3, 5), "LEFT wall tip tile")


func test_get_tip_tile_right():
	var rect := Rect2(3.0, 5.0, 5.0, 1.0)  # Wall from (3,5) to (8,6)
	var tip := _get_tip_tile(rect, Wall.Direction.RIGHT)
	return TestRunner.assert_eq(tip, Vector2i(7, 5), "RIGHT wall tip tile")


# =============================================================================
# Tests for flood fill logic
# =============================================================================

func test_flood_fill_marks_connected_area():
	var tiles := _create_empty_tiles()
	_flood_fill(tiles, 10, 10)
	# After flood fill, the tile should be TEMP
	return TestRunner.assert_eq(tiles[10][10], Board.TileType.TEMP, "Start tile should be TEMP")


func test_flood_fill_spreads_to_neighbors():
	var tiles := _create_empty_tiles()
	_flood_fill(tiles, 10, 10)
	# Adjacent tiles should also be TEMP
	return TestRunner.assert_eq(tiles[11][10], Board.TileType.TEMP, "Right neighbor") + \
		   TestRunner.assert_eq(tiles[9][10], Board.TileType.TEMP, "Left neighbor") + \
		   TestRunner.assert_eq(tiles[10][11], Board.TileType.TEMP, "Below neighbor") + \
		   TestRunner.assert_eq(tiles[10][9], Board.TileType.TEMP, "Above neighbor")


func test_flood_fill_stops_at_walls():
	var tiles := _create_empty_tiles()
	# Create a wall barrier
	for y in range(1, Board.TILE_NUM_H - 1):
		tiles[15][y] = Board.TileType.WALL
	_flood_fill(tiles, 10, 10)
	# Tiles before wall should be TEMP, tiles after wall should be FREE
	return TestRunner.assert_eq(tiles[14][10], Board.TileType.TEMP, "Before wall should be TEMP") + \
		   TestRunner.assert_eq(tiles[16][10], Board.TileType.FREE, "After wall should be FREE")


func test_flood_fill_stops_at_borders():
	var tiles := _create_empty_tiles()
	_flood_fill(tiles, 1, 1)  # Near corner
	# Border tiles should remain BORDER
	return TestRunner.assert_eq(tiles[0][1], Board.TileType.BORDER, "Border should remain BORDER")


func test_flood_fill_enclosed_area_stays_free():
	var tiles := _create_empty_tiles()
	# Create a box of walls enclosing tile (20, 10)
	for x in range(18, 23):
		tiles[x][8] = Board.TileType.WALL   # Top wall
		tiles[x][12] = Board.TileType.WALL  # Bottom wall
	for y in range(8, 13):
		tiles[18][y] = Board.TileType.WALL  # Left wall
		tiles[22][y] = Board.TileType.WALL  # Right wall

	# Flood fill from outside the box
	_flood_fill(tiles, 10, 10)

	# Inside the box should still be FREE (not TEMP)
	return TestRunner.assert_eq(tiles[20][10], Board.TileType.FREE, "Enclosed area should stay FREE")


func test_flood_fill_from_wall_does_nothing():
	var tiles := _create_empty_tiles()
	tiles[10][10] = Board.TileType.WALL
	_flood_fill(tiles, 10, 10)
	# Should remain WALL, not changed
	return TestRunner.assert_eq(tiles[10][10], Board.TileType.WALL, "Wall tile unchanged")


# =============================================================================
# Tests for penetration-based edge detection (_get_crossing_normal logic)
# =============================================================================

func test_crossing_vertical_edge_from_left():
	# Ball corner crosses into tile from the left (X boundary)
	# pen_x small, pen_y large -> vertical edge hit
	var curr_pos := Vector2(10.01, 5.5)  # In tile (10, 5)
	var next_pos := Vector2(9.9, 5.6)    # In tile (9, 5) - crossed X boundary
	var next_tile := Vector2i(9, 5)
	var normal := _get_crossing_normal(curr_pos, next_pos, next_tile, 1, 1)
	# Should be vertical edge (X only), not corner
	return TestRunner.assert_eq(normal.x, 1.0, "X normal") + \
		   TestRunner.assert_eq(normal.y, 0.0, "Y normal (not corner)")


func test_crossing_horizontal_edge_from_top():
	# Ball corner crosses into tile from above (Y boundary)
	# pen_y small, pen_x large -> horizontal edge hit
	var curr_pos := Vector2(5.5, 10.01)  # In tile (5, 10)
	var next_pos := Vector2(5.6, 9.9)    # In tile (5, 9) - crossed Y boundary
	var next_tile := Vector2i(5, 9)
	var normal := _get_crossing_normal(curr_pos, next_pos, next_tile, 1, 1)
	# Should be horizontal edge (Y only), not corner
	return TestRunner.assert_eq(normal.x, 0.0, "X normal (not corner)") + \
		   TestRunner.assert_eq(normal.y, 1.0, "Y normal")


func test_crossing_true_corner():
	# Ball corner crosses diagonally with equal penetration
	# pen_x ≈ pen_y -> corner hit
	var curr_pos := Vector2(10.01, 10.01)  # In tile (10, 10)
	var next_pos := Vector2(9.9, 9.9)      # In tile (9, 9) - crossed both
	var next_tile := Vector2i(9, 9)
	var normal := _get_crossing_normal(curr_pos, next_pos, next_tile, 1, 1)
	# Should be corner (both X and Y)
	return TestRunner.assert_eq(normal.x, 1.0, "X normal (corner)") + \
		   TestRunner.assert_eq(normal.y, 1.0, "Y normal (corner)")


func test_crossing_lr_corner_vertical_edge():
	# LR corner (nx=-1, ny=-1) hitting right edge of a tile
	var curr_pos := Vector2(4.99, 5.5)   # In tile (4, 5)
	var next_pos := Vector2(5.1, 5.6)    # In tile (5, 5) - crossed into tile 5
	var next_tile := Vector2i(5, 5)
	var normal := _get_crossing_normal(curr_pos, next_pos, next_tile, -1, -1)
	# pen_x = |5.1 - 5| = 0.1 (small), pen_y = |5.6 - 5| = 0.6 (large)
	# Should be vertical edge
	return TestRunner.assert_eq(normal.x, -1.0, "X normal") + \
		   TestRunner.assert_eq(normal.y, 0.0, "Y normal (not corner)")


func test_crossing_ll_corner_horizontal_edge():
	# LL corner (nx=1, ny=-1) hitting bottom edge of a tile
	var curr_pos := Vector2(5.5, 4.99)   # In tile (5, 4)
	var next_pos := Vector2(5.4, 5.1)    # In tile (5, 5) - crossed into tile row 5
	var next_tile := Vector2i(5, 5)
	var normal := _get_crossing_normal(curr_pos, next_pos, next_tile, 1, -1)
	# pen_x = |5.4 - 6| = 0.6 (large), pen_y = |5.1 - 5| = 0.1 (small)
	# Should be horizontal edge
	return TestRunner.assert_eq(normal.x, 0.0, "X normal (not corner)") + \
		   TestRunner.assert_eq(normal.y, -1.0, "Y normal")


# =============================================================================
# Tests for two-corner edge detection patterns
# =============================================================================

func test_two_corners_top_edge():
	# UL and UR both hit -> top edge, not corner
	var ul_hit := true
	var ur_hit := true
	var ll_hit := false
	var lr_hit := false
	var raw_normal := Vector2(1, 2)  # Sum of UL(1,1) + UR(-1,1) with some corner contrib
	var adjusted := _adjust_normal_for_edge_pattern(ul_hit, ur_hit, ll_hit, lr_hit, raw_normal)
	return TestRunner.assert_eq(adjusted.x, 0.0, "X normal (top edge)") + \
		   TestRunner.assert_eq(adjusted.y, 2.0, "Y normal")


func test_two_corners_bottom_edge():
	# LL and LR both hit -> bottom edge
	var ul_hit := false
	var ur_hit := false
	var ll_hit := true
	var lr_hit := true
	var raw_normal := Vector2(-1, -2)
	var adjusted := _adjust_normal_for_edge_pattern(ul_hit, ur_hit, ll_hit, lr_hit, raw_normal)
	return TestRunner.assert_eq(adjusted.x, 0.0, "X normal (bottom edge)") + \
		   TestRunner.assert_eq(adjusted.y, -2.0, "Y normal")


func test_two_corners_left_edge():
	# UL and LL both hit -> left edge
	var ul_hit := true
	var ur_hit := false
	var ll_hit := true
	var lr_hit := false
	var raw_normal := Vector2(2, 1)
	var adjusted := _adjust_normal_for_edge_pattern(ul_hit, ur_hit, ll_hit, lr_hit, raw_normal)
	return TestRunner.assert_eq(adjusted.x, 2.0, "X normal") + \
		   TestRunner.assert_eq(adjusted.y, 0.0, "Y normal (left edge)")


func test_two_corners_right_edge():
	# UR and LR both hit -> right edge
	var ul_hit := false
	var ur_hit := true
	var ll_hit := false
	var lr_hit := true
	var raw_normal := Vector2(-2, -1)
	var adjusted := _adjust_normal_for_edge_pattern(ul_hit, ur_hit, ll_hit, lr_hit, raw_normal)
	return TestRunner.assert_eq(adjusted.x, -2.0, "X normal") + \
		   TestRunner.assert_eq(adjusted.y, 0.0, "Y normal (right edge)")


func test_single_corner_no_adjustment():
	# Only one corner hit -> no adjustment, use raw normal
	var ul_hit := false
	var ur_hit := false
	var ll_hit := false
	var lr_hit := true
	var raw_normal := Vector2(-1, -1)
	var adjusted := _adjust_normal_for_edge_pattern(ul_hit, ur_hit, ll_hit, lr_hit, raw_normal)
	return TestRunner.assert_eq(adjusted, raw_normal, "Single corner unchanged")


func test_three_corners_no_adjustment():
	# Three corners hit -> complex case, no simple edge adjustment
	var ul_hit := true
	var ur_hit := true
	var ll_hit := true
	var lr_hit := false
	var raw_normal := Vector2(1, 1)
	var adjusted := _adjust_normal_for_edge_pattern(ul_hit, ur_hit, ll_hit, lr_hit, raw_normal)
	return TestRunner.assert_eq(adjusted, raw_normal, "Three corners unchanged")


# =============================================================================
# Helper functions
# =============================================================================

## Mimic _get_crossing_normal from board.gd
func _get_crossing_normal(curr_pos: Vector2, next_pos: Vector2, next_tile: Vector2i, nx: int, ny: int) -> Vector2:
	var tile_edge_x: float = next_tile.x if nx < 0 else next_tile.x + 1
	var tile_edge_y: float = next_tile.y if ny < 0 else next_tile.y + 1

	var penetration_x: float = absf(next_pos.x - tile_edge_x)
	var penetration_y: float = absf(next_pos.y - tile_edge_y)

	const CORNER_EPSILON := 0.5
	var penetration_ratio: float = penetration_x / penetration_y if penetration_y > 0.001 else 999.0
	if penetration_ratio < 0.001:
		penetration_ratio = 1.0 / 999.0

	var is_corner := penetration_ratio > (1.0 / (1.0 + CORNER_EPSILON)) and penetration_ratio < (1.0 + CORNER_EPSILON)

	if is_corner:
		return Vector2(nx, ny)
	elif penetration_x < penetration_y:
		return Vector2(nx, 0)
	else:
		return Vector2(0, ny)


## Mimic edge pattern adjustment from _check_ball_collision_tiles
func _adjust_normal_for_edge_pattern(ul_hit: bool, ur_hit: bool, ll_hit: bool, lr_hit: bool, raw_normal: Vector2) -> Vector2:
	if (ul_hit and ur_hit) and not (ll_hit or lr_hit):
		return Vector2(0, 2)  # Top edge
	elif (ll_hit and lr_hit) and not (ul_hit or ur_hit):
		return Vector2(0, -2)  # Bottom edge
	elif (ul_hit and ll_hit) and not (ur_hit or lr_hit):
		return Vector2(2, 0)  # Left edge
	elif (ur_hit and lr_hit) and not (ul_hit or ll_hit):
		return Vector2(-2, 0)  # Right edge
	else:
		return raw_normal

## Apply reflection logic (mimics Ball.collide + go_forward)
func _apply_reflection(velocity: Vector2, normal: Vector2) -> Vector2:
	var reflect_x := false
	var reflect_y := false

	if normal.x > 0:
		reflect_x = velocity.x < 0
	elif normal.x < 0:
		reflect_x = velocity.x > 0

	if normal.y > 0:
		reflect_y = velocity.y < 0
	elif normal.y < 0:
		reflect_y = velocity.y > 0

	var result := velocity
	if reflect_x:
		result.x *= -1
	if reflect_y:
		result.y *= -1
	return result


## Create empty tile array (mimics Board.clear())
func _create_empty_tiles() -> Array:
	var tiles: Array = []
	for x in range(Board.TILE_NUM_W):
		var column: Array = []
		for y in range(Board.TILE_NUM_H):
			if x == 0 or x == Board.TILE_NUM_W - 1 or y == 0 or y == Board.TILE_NUM_H - 1:
				column.append(Board.TileType.BORDER)
			else:
				column.append(Board.TileType.FREE)
		tiles.append(column)
	return tiles


## Check if ball would be trapped (mimics Board._would_ball_be_trapped logic)
func _check_trapped(tiles: Array, ball_x: int, ball_y: int, wall_dir: int) -> bool:
	const MIN_ESCAPE_SPACE := 2

	match wall_dir:
		Wall.Direction.DOWN:
			var free := 0
			for y in range(ball_y - 1, 0, -1):
				if tiles[ball_x][y] != Board.TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.UP:
			var free := 0
			for y in range(ball_y + 1, Board.TILE_NUM_H - 1):
				if tiles[ball_x][y] != Board.TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.RIGHT:
			var free := 0
			for x in range(ball_x - 1, 0, -1):
				if tiles[x][ball_y] != Board.TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.LEFT:
			var free := 0
			for x in range(ball_x + 1, Board.TILE_NUM_W - 1):
				if tiles[x][ball_y] != Board.TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

	return false


## Check if two walls are paired (mimics Board._are_paired_walls)
func _are_paired_walls(x1: int, y1: int, dir1: int, x2: int, y2: int, dir2: int) -> bool:
	if x1 != x2 or y1 != y2:
		return false
	return (dir1 == Wall.Direction.UP and dir2 == Wall.Direction.DOWN) or \
		   (dir1 == Wall.Direction.DOWN and dir2 == Wall.Direction.UP) or \
		   (dir1 == Wall.Direction.LEFT and dir2 == Wall.Direction.RIGHT) or \
		   (dir1 == Wall.Direction.RIGHT and dir2 == Wall.Direction.LEFT)


## Get tip rectangle (mimics Board._get_tip_rect)
func _get_tip_rect(rect: Rect2, direction: int) -> Rect2:
	const TIP_SIZE := 0.1
	match direction:
		Wall.Direction.UP:
			return Rect2(rect.position.x, rect.position.y, rect.size.x, TIP_SIZE)
		Wall.Direction.DOWN:
			return Rect2(rect.position.x, rect.end.y - TIP_SIZE, rect.size.x, TIP_SIZE)
		Wall.Direction.LEFT:
			return Rect2(rect.position.x, rect.position.y, TIP_SIZE, rect.size.y)
		Wall.Direction.RIGHT:
			return Rect2(rect.end.x - TIP_SIZE, rect.position.y, TIP_SIZE, rect.size.y)
	return rect


## Check if two rects share a tile (mimics Board._rects_share_tile)
func _rects_share_tile(rect1: Rect2, rect2: Rect2) -> bool:
	var r1_x1 := int(rect1.position.x)
	var r1_y1 := int(rect1.position.y)
	var r1_x2 := int(ceil(rect1.end.x - 0.001))
	var r1_y2 := int(ceil(rect1.end.y - 0.001))

	var r2_x1 := int(rect2.position.x)
	var r2_y1 := int(rect2.position.y)
	var r2_x2 := int(ceil(rect2.end.x - 0.001))
	var r2_y2 := int(ceil(rect2.end.y - 0.001))

	var x_overlap := r1_x1 <= r2_x2 and r2_x1 <= r1_x2
	var y_overlap := r1_y1 <= r2_y2 and r2_y1 <= r1_y2
	return x_overlap and y_overlap


## Get tip tile (mimics Board._get_tip_tile)
func _get_tip_tile(rect: Rect2, direction: int) -> Vector2i:
	match direction:
		Wall.Direction.UP:
			return Vector2i(int(rect.position.x), int(rect.position.y))
		Wall.Direction.DOWN:
			return Vector2i(int(rect.position.x), int(rect.end.y - 0.01))
		Wall.Direction.LEFT:
			return Vector2i(int(rect.position.x), int(rect.position.y))
		Wall.Direction.RIGHT:
			return Vector2i(int(rect.end.x - 0.01), int(rect.position.y))
	return Vector2i(-1, -1)


## Flood fill (mimics Board._flood_fill)
func _flood_fill(tiles: Array, start_x: int, start_y: int):
	if start_x < 0 or start_x >= Board.TILE_NUM_W or start_y < 0 or start_y >= Board.TILE_NUM_H:
		return
	if tiles[start_x][start_y] != Board.TileType.FREE:
		return

	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]

	while not stack.is_empty():
		var pos: Vector2i = stack.pop_back()
		var x: int = pos.x
		var y: int = pos.y

		if x < 0 or x >= Board.TILE_NUM_W or y < 0 or y >= Board.TILE_NUM_H:
			continue
		if tiles[x][y] != Board.TileType.FREE:
			continue

		tiles[x][y] = Board.TileType.TEMP

		stack.push_back(Vector2i(x, y - 1))
		stack.push_back(Vector2i(x + 1, y))
		stack.push_back(Vector2i(x, y + 1))
		stack.push_back(Vector2i(x - 1, y))
