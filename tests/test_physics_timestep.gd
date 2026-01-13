# test_physics_timestep.gd - Unit tests for fixed timestep physics
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted

const TestRunner = preload("res://tests/test_runner.gd")

# Physics constants (from game.gd)
const PHYSICS_TICK_RATE := 60.0
const PHYSICS_TICK_TIME := 1.0 / PHYSICS_TICK_RATE


# =============================================================================
# Tests for fixed timestep accumulator logic
# =============================================================================

func test_tick_time_calculation():
	# 60 ticks per second = ~16.67ms per tick
	var expected := 1.0 / 60.0
	return TestRunner.assert_approx(PHYSICS_TICK_TIME, expected, 0.0001, "Tick time should be 1/60 second")


func test_single_tick_exact():
	# Exactly one tick time should produce exactly one tick
	var accumulator := 0.0
	var tick_count := 0

	accumulator += PHYSICS_TICK_TIME
	while accumulator >= PHYSICS_TICK_TIME:
		tick_count += 1
		accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_eq(tick_count, 1, "Exact tick time should produce 1 tick")


func test_single_tick_remainder():
	# After one tick, accumulator should be near zero
	var accumulator := 0.0

	accumulator += PHYSICS_TICK_TIME
	while accumulator >= PHYSICS_TICK_TIME:
		accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_approx(accumulator, 0.0, 0.0001, "Accumulator should be ~0 after exact tick")


func test_multiple_ticks_from_large_delta():
	# Large delta (e.g. lag spike) should produce multiple ticks
	var accumulator := 0.0
	var tick_count := 0
	var large_delta := PHYSICS_TICK_TIME * 3.5  # 3.5 ticks worth

	accumulator += large_delta
	while accumulator >= PHYSICS_TICK_TIME:
		tick_count += 1
		accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_eq(tick_count, 3, "3.5 tick times should produce 3 ticks")


func test_accumulator_preserves_remainder():
	# Remainder should be preserved for next frame
	var accumulator := 0.0
	var large_delta := PHYSICS_TICK_TIME * 3.5

	accumulator += large_delta
	while accumulator >= PHYSICS_TICK_TIME:
		accumulator -= PHYSICS_TICK_TIME

	var expected_remainder := PHYSICS_TICK_TIME * 0.5
	return TestRunner.assert_approx(accumulator, expected_remainder, 0.0001, "Should preserve 0.5 tick remainder")


func test_small_delta_no_tick():
	# Delta smaller than tick time should not produce a tick
	var accumulator := 0.0
	var tick_count := 0
	var small_delta := PHYSICS_TICK_TIME * 0.5

	accumulator += small_delta
	while accumulator >= PHYSICS_TICK_TIME:
		tick_count += 1
		accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_eq(tick_count, 0, "Half tick time should produce 0 ticks")


func test_accumulated_small_deltas():
	# Multiple small deltas should eventually produce a tick
	var accumulator := 0.0
	var tick_count := 0
	var small_delta := PHYSICS_TICK_TIME * 0.4

	# Simulate 3 frames with small delta
	for i in range(3):
		accumulator += small_delta
		while accumulator >= PHYSICS_TICK_TIME:
			tick_count += 1
			accumulator -= PHYSICS_TICK_TIME

	# 0.4 + 0.4 + 0.4 = 1.2 ticks worth = 1 tick
	return TestRunner.assert_eq(tick_count, 1, "3 × 0.4 tick times should produce 1 tick")


func test_60fps_produces_60_ticks_per_second():
	# Simulating 60fps for 1 second should produce ~60 ticks
	var accumulator := 0.0
	var tick_count := 0
	var frame_delta := 1.0 / 60.0  # 60fps

	# Simulate 60 frames (1 second)
	for i in range(60):
		accumulator += frame_delta
		while accumulator >= PHYSICS_TICK_TIME:
			tick_count += 1
			accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_eq(tick_count, 60, "60fps for 1s should produce 60 ticks")


func test_30fps_produces_60_ticks_per_second():
	# Simulating 30fps for 1 second should still produce ~60 ticks
	var accumulator := 0.0
	var tick_count := 0
	var frame_delta := 1.0 / 30.0  # 30fps

	# Simulate 30 frames (1 second)
	for i in range(30):
		accumulator += frame_delta
		while accumulator >= PHYSICS_TICK_TIME:
			tick_count += 1
			accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_eq(tick_count, 60, "30fps for 1s should produce 60 ticks")


func test_120fps_produces_60_ticks_per_second():
	# Simulating 120fps for 1 second should produce ~60 ticks
	var accumulator := 0.0
	var tick_count := 0
	var frame_delta := 1.0 / 120.0  # 120fps

	# Simulate 120 frames (1 second)
	for i in range(120):
		accumulator += frame_delta
		while accumulator >= PHYSICS_TICK_TIME:
			tick_count += 1
			accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_eq(tick_count, 60, "120fps for 1s should produce 60 ticks")


func test_variable_fps_produces_consistent_ticks():
	# Variable frame rates should still produce consistent tick count
	var accumulator := 0.0
	var tick_count := 0

	# Simulate variable frame times totaling exactly 1 second
	var deltas := [0.1, 0.15, 0.05, 0.2, 0.08, 0.12, 0.1, 0.2]  # sum = 1.0

	for delta in deltas:
		accumulator += delta
		while accumulator >= PHYSICS_TICK_TIME:
			tick_count += 1
			accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_eq(tick_count, 60, "Variable fps totaling 1s should produce 60 ticks")


func test_reset_accumulator_prevents_burst():
	# Resetting accumulator after pause prevents burst of ticks
	var accumulator := 0.5  # Simulating leftover from previous session

	# Reset (as done when game state changes to RUNNING)
	accumulator = 0.0

	var tick_count := 0
	var normal_delta := 1.0 / 60.0

	accumulator += normal_delta
	while accumulator >= PHYSICS_TICK_TIME:
		tick_count += 1
		accumulator -= PHYSICS_TICK_TIME

	return TestRunner.assert_eq(tick_count, 1, "Reset accumulator should prevent burst ticks")
