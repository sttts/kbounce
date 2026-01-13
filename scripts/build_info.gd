# build_info.gd - Build configuration with defaults and optional overrides
#
# Provides version and config values. Defaults work out of the box.
# Makefile generates override files for release builds.

extends Node

# Defaults for development
var version_tag := "dev"
var leaderboard_api_url := "http://localhost:8787"

const VERSION_OVERRIDE := "res://scripts/version.gd"
const CONFIG_OVERRIDE := "res://scripts/config.gd"


func _init() -> void:
	_load_version_override()
	_load_config_override()


func _load_version_override() -> void:
	if not FileAccess.file_exists(VERSION_OVERRIDE):
		return
	var content := FileAccess.get_file_as_string(VERSION_OVERRIDE)
	var match := RegEx.create_from_string('const TAG = "([^"]*)"').search(content)
	if match:
		version_tag = match.get_string(1)


func _load_config_override() -> void:
	if not FileAccess.file_exists(CONFIG_OVERRIDE):
		return
	var content := FileAccess.get_file_as_string(CONFIG_OVERRIDE)
	var match := RegEx.create_from_string('const LEADERBOARD_API_URL = "([^"]*)"').search(content)
	if match:
		leaderboard_api_url = match.get_string(1)
