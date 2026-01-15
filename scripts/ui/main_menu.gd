# main_menu.gd - Main menu and game launcher
#
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Control

var _entry_scene: PackedScene = preload("res://scenes/ui/leaderboard_entry.tscn")

@onready var main_menu: Control = $MainMenu
@onready var game_container: Control = $GameContainer
@onready var new_game_button: Button = $MainMenu/CenterContainer/MenuPanel/VBoxContainer/ButtonsBox/NewGameButton
@onready var appstore_button: TextureButton = $MainMenu/CenterContainer/MenuPanel/VBoxContainer/ButtonsBox/AppStoreButton
@onready var entries_container: VBoxContainer = $MainMenu/CenterContainer/MenuPanel/VBoxContainer/LeaderboardSection/ScrollContainer/EntriesContainer
@onready var scroll_container: ScrollContainer = $MainMenu/CenterContainer/MenuPanel/VBoxContainer/LeaderboardSection/ScrollContainer

var _leaderboard_loaded: bool = false
var _screenshot_popup: Control = null
var _screenshot_popup_scene: PackedScene = preload("res://scenes/ui/screenshot_popup.tscn")

# Cached leaderboard data for instant display
var _cached_entries: Array = []
var _cached_user_entries: Array = []
const CACHE_PATH = "user://leaderboard_cache.json"


func _ready():
	# Set initial window size on desktop (80% of screen, maintaining aspect ratio)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		_setup_window_size()

	# Connect signals
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	else:
		push_error("new_game_button is null!")

	# App Store button: visible on web or when running from editor (IDE)
	appstore_button.visible = OS.has_feature("web") or OS.has_feature("editor")
	appstore_button.pressed.connect(_on_appstore_button_pressed)

	GameManager.game_over.connect(_on_game_over)
	GameManager.state_changed.connect(_on_state_changed)

	# Connect leaderboard signals
	LeaderboardManager.leaderboard_loaded.connect(_on_start_screen_leaderboard_loaded)
	LeaderboardManager.leaderboard_failed.connect(_on_start_screen_leaderboard_failed)

	# Load cached leaderboard first for instant display
	_load_cache()
	if _cached_entries.size() > 0:
		_display_leaderboard(_cached_entries, _cached_user_entries)

	# Then fetch fresh data in background
	LeaderboardManager.load_leaderboard("top")


func _on_new_game_pressed():
	main_menu.visible = false

	# Start the game
	var game = game_container.get_node("Game")
	if game:
		game.new_game()
	else:
		push_error("Game node not found!")


func _on_appstore_button_pressed():
	var url := "https://apps.apple.com/de/app/kbounce/id6757555544"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank')" % url)
	else:
		OS.shell_open(url)


func _on_game_over():
	# Keep game state visible for screenshots - user can click New Game button
	pass


func _on_state_changed(state: GameManager.GameState):
	if state == GameManager.GameState.BEFORE_FIRST_GAME:
		main_menu.visible = true
		# Show cached data instantly, then refresh in background
		if _cached_entries.size() > 0:
			_display_leaderboard(_cached_entries, _cached_user_entries)
		LeaderboardManager.load_leaderboard("top")


func _load_start_screen_leaderboard():
	# Show loading only if no cached data
	if _cached_entries.size() == 0:
		_clear_entries()
		_add_loading_label()
	LeaderboardManager.load_leaderboard("top")


func _add_loading_label():
	var label := Label.new()
	label.text = "Loading..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	entries_container.add_child(label)


func _on_start_screen_leaderboard_loaded(entries: Array, _user_rank: int, user_entries: Array):
	# Only handle if on start screen
	if GameManager.state != GameManager.GameState.BEFORE_FIRST_GAME:
		return

	# Skip update if data hasn't changed (prevents flicker)
	if _arrays_equal(entries, _cached_entries) and _arrays_equal(user_entries, _cached_user_entries):
		return

	# Cache and save the data
	_cached_entries = entries
	_cached_user_entries = user_entries
	_save_cache()

	# Display the leaderboard
	_display_leaderboard(entries, user_entries)


func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	return JSON.stringify(a) == JSON.stringify(b)


func _display_leaderboard(entries: Array, user_entries: Array):
	_clear_entries()
	_leaderboard_loaded = true

	# Track which entries are from user (to highlight in top 10)
	var user_score_ids: Array[String] = []
	for ue in user_entries:
		var id = ue.get("id")
		if id != null:
			user_score_ids.append(str(id))

	# Track user's best score entry for auto-scroll
	var user_best_entry_node: Control = null
	var user_best_score: int = -1

	# Display top 10 entries
	for entry_data in entries:
		var entry_id: String = str(entry_data.get("id", ""))
		var is_user: bool = user_score_ids.has(entry_id)
		var entry = _entry_scene.instantiate()
		entries_container.add_child(entry)
		entry.setup(entry_data, is_user, false)  # not editable
		entry.screenshot_clicked.connect(_on_screenshot_clicked)

		# Track user's best score in top 10
		if is_user:
			var score: int = entry_data.get("score", 0)
			if score > user_best_score:
				user_best_score = score
				user_best_entry_node = entry

	# Add separator and all user scores not in top 10
	var scores_outside_top10: Array = []
	for ue in user_entries:
		var score_id = ue.get("id")
		if score_id != null and str(score_id) in user_score_ids:
			# Check if already shown in top 10
			var rank: int = ue.get("rank", 0)
			if rank > 0 and rank <= 10:
				continue
		scores_outside_top10.append(ue)

	if scores_outside_top10.size() > 0:
		_add_separator()
		for ue in scores_outside_top10:
			var entry = _entry_scene.instantiate()
			entries_container.add_child(entry)
			entry.setup(ue, true, false)  # is_user=true, not editable
			entry.screenshot_clicked.connect(_on_screenshot_clicked)

			# Track user's best score below separator
			var score: int = ue.get("score", 0)
			if score > user_best_score:
				user_best_score = score
				user_best_entry_node = entry

	# Auto-scroll to user's best score entry
	if user_best_entry_node != null:
		_scroll_to_entry(user_best_entry_node)


func _on_start_screen_leaderboard_failed(_error: String):
	# Only handle if on start screen
	if GameManager.state != GameManager.GameState.BEFORE_FIRST_GAME:
		return

	# Use cached data if available, otherwise show offline message
	if _cached_entries.size() > 0:
		_display_leaderboard(_cached_entries, _cached_user_entries)
	else:
		_clear_entries()
		var label := Label.new()
		label.text = "Offline"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		entries_container.add_child(label)


func _add_separator():
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	entries_container.add_child(sep)

	var label := Label.new()
	label.text = "Your Best Scores"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	label.add_theme_font_size_override("font_size", 12)
	entries_container.add_child(label)


func _scroll_to_entry(target: Control):
	# Wait for layout to complete
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(target) or not is_instance_valid(scroll_container):
		return

	# Scroll to center the target entry in the visible area
	var target_pos: float = target.position.y
	var visible_height: float = scroll_container.size.y
	var scroll_pos: float = target_pos - (visible_height / 2) + (target.size.y / 2)
	scroll_container.scroll_vertical = int(max(0, scroll_pos))


func _clear_entries():
	for child in entries_container.get_children():
		child.queue_free()


func _load_cache():
	if not FileAccess.file_exists(CACHE_PATH):
		return

	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		return

	var json_string := file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_string)
	if data == null or not data is Dictionary:
		return

	_cached_entries = data.get("entries", [])
	_cached_user_entries = data.get("user_entries", [])


func _save_cache():
	var data := {
		"entries": _cached_entries,
		"user_entries": _cached_user_entries
	}

	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(data))
	file.close()


func _on_screenshot_clicked(url: String, score_id: String):
	if _screenshot_popup == null:
		_screenshot_popup = _screenshot_popup_scene.instantiate()
		add_child(_screenshot_popup)
	_screenshot_popup.show_screenshot(url, score_id)


func _unhandled_input(event):
	if not is_node_ready():
		return

	# Handle button clicks manually (Godot button detection not working)
	# Using _unhandled_input so overlay buttons get priority
	if main_menu and main_menu.visible and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if new_game_button and new_game_button.get_global_rect().has_point(event.position):
				_on_new_game_pressed()
				get_viewport().set_input_as_handled()


func _setup_window_size():
	const ASPECT_RATIO := 1024.0 / 640.0  # 1.6:1
	const SCREEN_PERCENTAGE := 0.8

	var screen_size := DisplayServer.screen_get_size()
	var max_width := int(screen_size.x * SCREEN_PERCENTAGE)
	var max_height := int(screen_size.y * SCREEN_PERCENTAGE)

	# Calculate window size maintaining aspect ratio
	var window_width := max_width
	var window_height := int(window_width / ASPECT_RATIO)

	# If height exceeds max, scale down from height instead
	if window_height > max_height:
		window_height = max_height
		window_width = int(window_height * ASPECT_RATIO)

	var window_size := Vector2i(window_width, window_height)
	DisplayServer.window_set_size(window_size)

	# Center the window
	var screen_center := screen_size / 2
	var window_pos := Vector2i(screen_center.x - window_width / 2, screen_center.y - window_height / 2)
	DisplayServer.window_set_position(window_pos)
