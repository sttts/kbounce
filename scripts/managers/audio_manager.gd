# audio_manager.gd - Sound playback manager (Autoload)
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Sound delay to prevent audio spam (in game ticks)
const SOUND_DELAY := 4

## Maximum concurrent sound players
const MAX_PLAYERS := 8

## Default volume (30% = -10.46 dB)
const DEFAULT_VOLUME_DB := -10.46

## Preloaded sound streams
var sounds := {}

## Pool of audio players for concurrent playback
var players: Array[AudioStreamPlayer] = []

## Sound delay counters (for throttling)
var _sound_delays := {}

## Current volume in dB
var _volume_db: float = DEFAULT_VOLUME_DB


func _ready():
	# Preload all game sounds
	sounds = {
		"ball_bounce": preload("res://assets/sounds/ball-bounce.ogg"),
		"ball_bounce_wall": preload("res://assets/sounds/ball-bounce-wall.ogg"),
		"death": preload("res://assets/sounds/death.ogg"),
		"reflect": preload("res://assets/sounds/reflect.ogg"),
		"seconds": preload("res://assets/sounds/seconds.ogg"),
		"timeout": preload("res://assets/sounds/timeout.ogg"),
		"wallstart": preload("res://assets/sounds/wallstart.ogg"),
		"wallend": preload("res://assets/sounds/wallend.ogg"),
	}

	# Create pool of audio players
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.volume_db = _volume_db
		add_child(player)
		players.append(player)


## Play a sound by name
func play(sound_name: String, throttle: bool = false):
	# Check throttling
	if throttle:
		if _sound_delays.get(sound_name, 0) > 0:
			return
		_sound_delays[sound_name] = SOUND_DELAY

	var stream := sounds.get(sound_name) as AudioStream
	if not stream:
		push_warning("AudioManager: Sound not found: " + sound_name)
		return

	# Find an available player
	for player in players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	# All players busy - reuse the first one (oldest sound)
	players[0].stream = stream
	players[0].play()


## Play ball bounce sound with throttling
func play_ball_bounce():
	play("ball_bounce", true)


## Play ball hitting wall sound with throttling
func play_ball_wall():
	play("ball_bounce_wall", true)


## Called each game tick to update sound delays
func tick():
	for key in _sound_delays.keys():
		if _sound_delays[key] > 0:
			_sound_delays[key] -= 1


## Stop all sounds
func stop_all():
	for player in players:
		player.stop()


## Set volume from linear value (0.0 to 1.0)
func set_volume_linear(value: float):
	value = clampf(value, 0.0, 1.0)
	if value <= 0.0:
		_volume_db = -80.0  # Effectively muted
	else:
		_volume_db = 20.0 * log(value) / log(10.0)
	for player in players:
		player.volume_db = _volume_db


## Get volume as linear value (0.0 to 1.0)
func get_volume_linear() -> float:
	if _volume_db <= -80.0:
		return 0.0
	return pow(10.0, _volume_db / 20.0)
