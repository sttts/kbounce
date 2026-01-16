# build_info.gd - Build configuration with defaults and optional overrides
#
# Provides version and config values. Defaults work out of the box.
# Makefile generates override files for release builds.

extends Node

# Defaults for development
var version_tag := "dev"
var config_url := ""

const VERSION_OVERRIDE := "res://scripts/version.gd"
const CONFIG_OVERRIDE := "res://scripts/config.gd"


func _init() -> void:
	_load_version_override()
	_load_config_override()


func _load_version_override() -> void:
	if not ResourceLoader.exists(VERSION_OVERRIDE):
		return
	var script = load(VERSION_OVERRIDE)
	if script and "TAG" in script:
		version_tag = script.TAG


func _load_config_override() -> void:
	if not ResourceLoader.exists(CONFIG_OVERRIDE):
		return
	var script = load(CONFIG_OVERRIDE)
	if script and "CONFIG_URL" in script:
		config_url = script.CONFIG_URL
