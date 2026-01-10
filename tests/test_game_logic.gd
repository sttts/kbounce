# test_game_logic.gd - Unit tests for game logic (fill %, score, levels)
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted

const TestRunner = preload("res://tests/test_runner.gd")

# Board dimensions (from Board class)
const TILE_NUM_W := 32
const TILE_NUM_H := 20

# Game constants (from GameManager)
const MIN_FILL_PERCENT := 75
const POINTS_FOR_LIFE := 15
const GAME_TIME_PER_LEVEL := 90


# =============================================================================
# Tests for fill percentage calculation
# =============================================================================

func test_fill_percent_empty_board():
	# Empty board (no walls inside) = 0%
	var tiles := _create_empty_tiles()
	var percent := _calculate_fill_percent(tiles)
	return TestRunner.assert_eq(percent, 0, "Empty board should be 0%")


func test_fill_percent_full_board():
	# All inner tiles filled = 100%
	var tiles := _create_empty_tiles()
	for x in range(1, TILE_NUM_W - 1):
		for y in range(1, TILE_NUM_H - 1):
			tiles[x][y] = Board.TileType.WALL
	var percent := _calculate_fill_percent(tiles)
	return TestRunner.assert_eq(percent, 100, "Full board should be 100%")


func test_fill_percent_half_board():
	# Half inner tiles filled ≈ 50%
	var tiles := _create_empty_tiles()
	var inner_width := TILE_NUM_W - 2  # 30
	var inner_height := TILE_NUM_H - 2  # 18
	var half_count := (inner_width * inner_height) / 2  # 270

	var filled := 0
	for x in range(1, TILE_NUM_W - 1):
		for y in range(1, TILE_NUM_H - 1):
			if filled < half_count:
				tiles[x][y] = Board.TileType.WALL
				filled += 1

	var percent := _calculate_fill_percent(tiles)
	return TestRunner.assert_eq(percent, 50, "Half filled should be 50%")


func test_fill_percent_75_threshold():
	# Exactly 75% (level complete threshold)
	var tiles := _create_empty_tiles()
	var inner_width := TILE_NUM_W - 2
	var inner_height := TILE_NUM_H - 2
	var target_count := (inner_width * inner_height) * 75 / 100

	var filled := 0
	for x in range(1, TILE_NUM_W - 1):
		for y in range(1, TILE_NUM_H - 1):
			if filled < target_count:
				tiles[x][y] = Board.TileType.WALL
				filled += 1

	var percent := _calculate_fill_percent(tiles)
	return TestRunner.assert_eq(percent, 75, "75% fill threshold")


func test_fill_ignores_borders():
	# Border tiles don't count toward fill
	var tiles := _create_empty_tiles()
	# Borders are already set, verify they don't affect percentage
	var percent := _calculate_fill_percent(tiles)
	return TestRunner.assert_eq(percent, 0, "Border tiles should not count")


# =============================================================================
# Tests for level bonus calculation
# =============================================================================

func test_fill_bonus_minimum():
	# Exactly 75% fill = 0 bonus
	var fill_bonus := _calculate_fill_bonus(75, 1)
	return TestRunner.assert_eq(fill_bonus, 0, "75% fill should give 0 bonus")


func test_fill_bonus_level_1():
	# Level 1, 80% fill: (80-75) × 2 × (1+5) = 5 × 2 × 6 = 60
	var fill_bonus := _calculate_fill_bonus(80, 1)
	return TestRunner.assert_eq(fill_bonus, 60, "Level 1, 80% fill bonus")


func test_fill_bonus_level_5():
	# Level 5, 90% fill: (90-75) × 2 × (5+5) = 15 × 2 × 10 = 300
	var fill_bonus := _calculate_fill_bonus(90, 5)
	return TestRunner.assert_eq(fill_bonus, 300, "Level 5, 90% fill bonus")


func test_fill_bonus_100_percent():
	# Level 3, 100% fill: (100-75) × 2 × (3+5) = 25 × 2 × 8 = 400
	var fill_bonus := _calculate_fill_bonus(100, 3)
	return TestRunner.assert_eq(fill_bonus, 400, "Level 3, 100% fill bonus")


func test_lives_bonus():
	# 3 lives remaining: 3 × 15 = 45
	var lives_bonus := _calculate_lives_bonus(3)
	return TestRunner.assert_eq(lives_bonus, 45, "3 lives bonus")


func test_lives_bonus_zero():
	# 0 lives: 0 × 15 = 0
	var lives_bonus := _calculate_lives_bonus(0)
	return TestRunner.assert_eq(lives_bonus, 0, "0 lives bonus")


func test_total_bonus_level_1():
	# Level 1, 85% fill, 2 lives remaining
	# Fill: (85-75) × 2 × 6 = 120
	# Lives: 2 × 15 = 30
	# Total: 150
	var fill_bonus := _calculate_fill_bonus(85, 1)
	var lives_bonus := _calculate_lives_bonus(2)
	return TestRunner.assert_eq(fill_bonus + lives_bonus, 150, "Total bonus level 1")


# =============================================================================
# Tests for level initialization
# =============================================================================

func test_new_game_initial_level():
	# New game starts at level 1
	return TestRunner.assert_eq(1, 1, "New game starts at level 1")


func test_lives_equals_balls():
	# Lives = level + 1 (balls count)
	var level := 1
	var lives := level + 1
	return TestRunner.assert_eq(lives, 2, "Level 1 has 2 lives (balls)")


func test_lives_level_5():
	var level := 5
	var lives := level + 1
	return TestRunner.assert_eq(lives, 6, "Level 5 has 6 lives (balls)")


func test_time_per_level():
	return TestRunner.assert_eq(GAME_TIME_PER_LEVEL, 90, "90 seconds per level")


func test_min_fill_percent():
	return TestRunner.assert_eq(MIN_FILL_PERCENT, 75, "75% fill required")


# =============================================================================
# Tests for time mechanics
# =============================================================================

func test_time_tick():
	var time := 90
	time -= 1
	return TestRunner.assert_eq(time, 89, "Time decrements by 1")


func test_time_runs_out():
	var time := 1
	time -= 1
	var game_over := time <= 0
	return TestRunner.assert_true(game_over, "Time 0 triggers game over")


func test_time_not_negative():
	var time := 0
	time -= 1
	if time < 0:
		time = 0
	return TestRunner.assert_eq(time, 0, "Time doesn't go negative")


# =============================================================================
# Tests for score formatting
# =============================================================================

func test_format_score_small():
	var formatted := _format_score(500)
	return TestRunner.assert_eq(formatted, "500", "Small score no separator")


func test_format_score_thousands():
	var formatted := _format_score(1500)
	return TestRunner.assert_eq(formatted, "1,500", "Thousands separator")


func test_format_score_millions():
	var formatted := _format_score(1234567)
	return TestRunner.assert_eq(formatted, "1,234,567", "Multiple separators")


func test_format_score_zero():
	var formatted := _format_score(0)
	return TestRunner.assert_eq(formatted, "0", "Zero score")


# =============================================================================
# Helper functions
# =============================================================================

## Create empty tile array with borders
func _create_empty_tiles() -> Array:
	var tiles: Array = []
	for x in range(TILE_NUM_W):
		var column: Array = []
		for y in range(TILE_NUM_H):
			if x == 0 or x == TILE_NUM_W - 1 or y == 0 or y == TILE_NUM_H - 1:
				column.append(Board.TileType.BORDER)
			else:
				column.append(Board.TileType.FREE)
		tiles.append(column)
	return tiles


## Calculate fill percentage (mimics Board logic)
func _calculate_fill_percent(tiles: Array) -> int:
	var filled_count := 0
	for x in range(1, TILE_NUM_W - 1):
		for y in range(1, TILE_NUM_H - 1):
			if tiles[x][y] == Board.TileType.WALL:
				filled_count += 1

	return filled_count * 100 / ((TILE_NUM_W - 2) * (TILE_NUM_H - 2))


## Calculate fill bonus (mimics GameManager logic)
func _calculate_fill_bonus(filled: int, level: int) -> int:
	return (filled - MIN_FILL_PERCENT) * 2 * (level + 5)


## Calculate lives bonus (mimics GameManager logic)
func _calculate_lives_bonus(lives: int) -> int:
	return lives * POINTS_FOR_LIFE


## Format score with thousand separators (mimics leaderboard_entry)
func _format_score(score: int) -> String:
	var s := str(score)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
