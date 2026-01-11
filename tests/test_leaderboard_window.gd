# test_leaderboard_window.gd - Unit tests for leaderboard windowing algorithm
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted

const TestRunner = preload("res://tests/test_runner.gd")

# Constants matching hud.gd
const MAX_VISIBLE := 9
const MAX_ABOVE := 3


# =============================================================================
# Tests for leaderboard windowing algorithm
# =============================================================================

func test_user_at_top():
	# User at position 0 - show positions 0-8
	var result := _calculate_window(15, 0)
	return TestRunner.assert_eq(result, {"start": 0, "end": 9}, "User at top shows 0-8")


func test_user_at_position_3():
	# User at position 3 - show 0-8 (3 above user)
	var result := _calculate_window(15, 3)
	return TestRunner.assert_eq(result, {"start": 0, "end": 9}, "User at pos 3 shows 0-8")


func test_user_at_position_5():
	# User at position 5 - show 2-10 (3 above user)
	var result := _calculate_window(15, 5)
	return TestRunner.assert_eq(result, {"start": 2, "end": 11}, "User at pos 5 shows 2-10")


func test_user_at_position_10():
	# User at position 10 in list of 15 - show 7-15 (3 above user)
	var result := _calculate_window(15, 10)
	return TestRunner.assert_eq(result, {"start": 7, "end": 15}, "User at pos 10 in 15 entries")


func test_user_near_end():
	# User at position 10 in list of 12 - show 3-11 (3 above user, stops at end)
	var result := _calculate_window(12, 10)
	return TestRunner.assert_eq(result, {"start": 7, "end": 12}, "User near end")


func test_user_at_last_position():
	# User at last position (14) in list of 15 - show 6-14
	var result := _calculate_window(15, 14)
	return TestRunner.assert_eq(result, {"start": 11, "end": 15}, "User at last position")


func test_no_user_many_entries():
	# No user entry, 15 entries - show first 9
	var result := _calculate_window(15, -1)
	return TestRunner.assert_eq(result, {"start": 0, "end": 9}, "No user, show first 9")


func test_no_user_few_entries():
	# No user entry, only 5 entries - show all
	var result := _calculate_window(5, -1)
	return TestRunner.assert_eq(result, {"start": 0, "end": 5}, "No user, show all 5")


func test_small_list_user_at_top():
	# User at position 0 in list of 5 - show all
	var result := _calculate_window(5, 0)
	return TestRunner.assert_eq(result, {"start": 0, "end": 5}, "Small list, user at top")


func test_small_list_user_in_middle():
	# User at position 2 in list of 5 - show all
	var result := _calculate_window(5, 2)
	return TestRunner.assert_eq(result, {"start": 0, "end": 5}, "Small list, user in middle")


func test_empty_list():
	# Empty list
	var result := _calculate_window(0, -1)
	return TestRunner.assert_eq(result, {"start": 0, "end": 0}, "Empty list")


func test_exactly_9_entries_user_at_3():
	# Exactly 9 entries, user at position 3 - show all
	var result := _calculate_window(9, 3)
	return TestRunner.assert_eq(result, {"start": 0, "end": 9}, "Exactly 9 entries")


func test_max_above_constraint():
	# Verify we never show more than 3 entries above user
	# User at position 8 in list of 20 - should show 5-13 (3 above)
	var result := _calculate_window(20, 8)
	var entries_above: int = 8 - result.start
	return TestRunner.assert_true(entries_above <= MAX_ABOVE, "Max %d entries above user" % MAX_ABOVE)


func test_user_position_4_shows_3_above():
	# User at position 4 - should show positions 1-9 (exactly 3 above)
	var result := _calculate_window(20, 4)
	return TestRunner.assert_eq(result, {"start": 1, "end": 10}, "User at pos 4 shows 3 above")


func test_user_position_6_shows_3_above():
	# User at position 6 - should show positions 3-11 (exactly 3 above)
	var result := _calculate_window(20, 6)
	return TestRunner.assert_eq(result, {"start": 3, "end": 12}, "User at pos 6 shows 3 above")


# =============================================================================
# Helper function - mirrors algorithm in hud.gd
# =============================================================================

## Calculate window indices for leaderboard display
## Returns {start, end} where entries[start:end] should be shown
func _calculate_window(total_entries: int, user_position: int) -> Dictionary:
	var start_idx := 0
	var end_idx := total_entries

	if user_position != -1:
		# Position user with at most MAX_ABOVE entries above (rest below)
		start_idx = maxi(0, user_position - MAX_ABOVE)
		end_idx = mini(start_idx + MAX_VISIBLE, total_entries)
	elif total_entries > MAX_VISIBLE:
		# No user entry, just show first 9
		end_idx = MAX_VISIBLE

	return {"start": start_idx, "end": end_idx}
