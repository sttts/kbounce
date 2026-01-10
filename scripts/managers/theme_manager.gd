# theme_manager.gd - Theme/graphics loader (Autoload)
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Emitted when theme changes
signal theme_changed(theme_name: String)

## Available themes
const THEMES := [
	"classic",
	"glass"
]

## Required sprite names for each theme
const SPRITE_NAMES := [
	"background",
	"ball",
	"grid_tile",
	"wall_tile",
	"wall_h",
	"wall_v",
	"wall_end"
]

## Currently loaded theme name
var current_theme := "glass"

## Loaded textures for current theme
var textures := {}

## Background size for rendering
var background_size := Vector2i(1024, 640)

## Cached background image
var _cached_background: Texture2D = null


func _ready():
	load_theme(current_theme)


## Load a theme by name
func load_theme(theme_name: String) -> bool:
	if theme_name not in THEMES:
		push_error("ThemeManager: Unknown theme: " + theme_name)
		return false

	current_theme = theme_name
	var base_path := "res://assets/themes/%s/" % theme_name

	textures.clear()
	_cached_background = null

	# Load all required sprites
	for sprite_name in SPRITE_NAMES:
		var path: String = base_path + sprite_name + ".png"
		if ResourceLoader.exists(path):
			textures[sprite_name] = load(path)
		else:
			# Try alternate naming conventions
			var alt_path: String = base_path + sprite_name.replace("_", "-") + ".png"
			if ResourceLoader.exists(alt_path):
				textures[sprite_name] = load(alt_path)
			else:
				push_warning("ThemeManager: Missing sprite: " + path)

	theme_changed.emit(theme_name)
	return true


## Get a texture by sprite name
func get_texture(sprite_name: String) -> Texture2D:
	return textures.get(sprite_name)


## Get the background texture, scaled to current size
func get_background() -> Texture2D:
	return textures.get("background")


## Set background size for rendering
func set_background_size(size: Vector2i):
	if background_size != size:
		background_size = size
		_cached_background = null


## Get list of available themes
func get_available_themes() -> Array[String]:
	var result: Array[String] = []
	for theme in THEMES:
		result.append(theme)
	return result


## Get preview texture for a theme (for theme selector)
func get_theme_preview(theme_name: String) -> Texture2D:
	var path := "res://assets/themes/%s/preview.png" % theme_name
	if ResourceLoader.exists(path):
		return load(path)
	# Fall back to background
	path = "res://assets/themes/%s/background.png" % theme_name
	if ResourceLoader.exists(path):
		return load(path)
	return null
