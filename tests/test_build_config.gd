# test_build_config.gd - Unit tests for build/export configuration
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted

const TestRunner = preload("res://tests/test_runner.gd")


func test_web_virtual_keyboard_enabled():
	# Virtual keyboard must be enabled for mobile web to show keyboard on LineEdit focus.
	# This setting has been accidentally disabled multiple times in git history.
	var config := _load_export_presets()
	var value := _get_preset_option(config, "Web", "html/experimental_virtual_keyboard")
	return TestRunner.assert_eq(value, "true", "Web export must have experimental_virtual_keyboard=true")


func test_ios_share_plugin_enabled():
	# SharePlugin must be enabled for iOS share functionality to work.
	var config := _load_export_presets()
	var value := _get_preset_setting(config, "iOS", "plugins/SharePlugin")
	return TestRunner.assert_eq(value, "true", "iOS export must have plugins/SharePlugin=true")


# =============================================================================
# Helper functions
# =============================================================================

## Load export_presets.cfg as raw text
func _load_export_presets() -> String:
	var file := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


## Get a preset setting value from export_presets.cfg (anywhere in preset section)
## Returns the value as string, or empty string if not found
func _get_preset_setting(config: String, preset_name: String, setting_key: String) -> String:
	var lines := config.split("\n")
	var in_target_preset := false

	for line in lines:
		line = line.strip_edges()

		# Check for new preset header (not options) - resets our state
		if line.begins_with("[preset.") and line.ends_with("]") and not ".options]" in line:
			in_target_preset = false

		# Check for preset name
		if line.begins_with("name="):
			var name := line.substr(5).strip_edges().trim_prefix("\"").trim_suffix("\"")
			if name == preset_name:
				in_target_preset = true

		# Look for the setting anywhere in preset section
		if in_target_preset and line.begins_with(setting_key + "="):
			return line.substr(setting_key.length() + 1)

	return ""


## Get a preset option value from export_presets.cfg (in .options section)
## Returns the value as string, or empty string if not found
func _get_preset_option(config: String, preset_name: String, option_key: String) -> String:
	var lines := config.split("\n")
	var in_target_preset := false
	var in_options := false

	for line in lines:
		line = line.strip_edges()

		# Check for preset header (e.g. [preset.0]) - but not options section
		if line.begins_with("[preset.") and line.ends_with("]") and not ".options]" in line:
			in_target_preset = false
			in_options = false

		# Check for preset name
		if line.begins_with("name="):
			var name := line.substr(5).strip_edges().trim_prefix("\"").trim_suffix("\"")
			if name == preset_name:
				in_target_preset = true

		# Check for options section (e.g. [preset.0.options])
		if in_target_preset and ".options]" in line:
			in_options = true

		# Look for the option
		if in_target_preset and in_options and line.begins_with(option_key + "="):
			return line.substr(option_key.length() + 1)

	return ""
