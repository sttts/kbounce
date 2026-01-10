# test_runner.gd - Simple unit test runner for Godot
#
# Run with: godot --headless --script tests/test_runner.gd
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends SceneTree

var _passed := 0
var _failed := 0
var _current_test := ""


func _init():
	print("\n========================================")
	print("Running Unit Tests")
	print("========================================\n")

	# Run all test suites
	_run_test_suite(preload("res://tests/test_collision.gd").new())
	_run_test_suite(preload("res://tests/test_wall_ball.gd").new())

	# Print summary
	print("\n========================================")
	print("Results: %d passed, %d failed" % [_passed, _failed])
	print("========================================\n")

	# Exit with error code if any tests failed
	quit(1 if _failed > 0 else 0)


func _run_test_suite(suite: Object):
	var suite_name: String = suite.get_script().resource_path.get_file()
	print("Suite: %s" % suite_name)

	# Find and run all methods starting with "test_"
	for method in suite.get_method_list():
		var name: String = method["name"]
		if name.begins_with("test_"):
			_current_test = name
			_run_test(suite, name)

	print("")


func _run_test(suite: Object, method_name: String):
	var result := "PASS"
	var error_msg := ""

	# Call the test method
	var test_result = suite.call(method_name)
	if test_result is String and not test_result.is_empty():
		result = "FAIL"
		error_msg = test_result
		_failed += 1
	else:
		_passed += 1

	# Print result
	var status := "✓" if result == "PASS" else "✗"
	print("  %s %s" % [status, method_name])
	if not error_msg.is_empty():
		print("    → %s" % error_msg)


## Assert helper - returns error message if condition is false
static func assert_true(condition: bool, message: String = "Expected true") -> String:
	return "" if condition else message


## Assert helper - returns error message if values are not equal
static func assert_eq(actual, expected, message: String = "") -> String:
	if actual == expected:
		return ""
	var msg := "Expected %s but got %s" % [expected, actual]
	if not message.is_empty():
		msg = message + ": " + msg
	return msg


## Assert helper - returns error message if values are not approximately equal
static func assert_approx(actual: float, expected: float, epsilon: float = 0.001, message: String = "") -> String:
	if abs(actual - expected) <= epsilon:
		return ""
	var msg := "Expected ~%s but got %s" % [expected, actual]
	if not message.is_empty():
		msg = message + ": " + msg
	return msg
