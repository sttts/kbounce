# hud.gd - Heads-up display for game info
#
# SPDX-FileCopyrightText: 2000-2005 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Control

# Preload icons
var _icon_pause := preload("res://assets/icons/pause.svg")
var _icon_play := preload("res://assets/icons/play.svg")
var _icon_arrow_v := preload("res://assets/icons/arrow_vertical.svg")
var _icon_arrow_h := preload("res://assets/icons/arrow_horizontal.svg")

# Preload leaderboard entry scene
var _entry_scene: PackedScene = preload("res://scenes/ui/leaderboard_entry.tscn")

# Reference to user's editable entry in game over screen
var _user_entry: Node = null

@onready var score_label: Label = $TopBar/ScoreBox/ScoreLabel
@onready var level_label: Label = $TopBar/LevelBox/LevelLabel
@onready var lives_label: Label = $TopBar/LivesBox/LivesLabel
@onready var time_label: Label = $TopBar/TimeBox/TimeLabel
@onready var fill_label: Label = $TopBar/FillBox/FillLabel
@onready var direction_button: Button = $DirectionButton
@onready var pause_button: Button = $TopRightButtons/PauseButton
@onready var stop_button: Button = $TopRightButtons/StopButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var game_over_splash: Control = $GameOverSplash
@onready var game_over_overlay: Control = $GameOverOverlay
@onready var game_over_new_game_button: Button = $GameOverOverlay/CenterContainer/Panel/HBox/VBox/NewGameButton
@onready var game_over_entries_container: VBoxContainer = $GameOverOverlay/CenterContainer/Panel/HBox/VBox/ScrollContainer/EntriesContainer
@onready var game_over_loading_label: Label = $GameOverOverlay/CenterContainer/Panel/HBox/VBox/LoadingLabel
@onready var level_complete_overlay: Control = $LevelCompleteOverlay
@onready var lc_level_label: Label = $LevelCompleteOverlay/CenterContainer/Panel/VBox/LevelLabel
@onready var lc_score_label: Label = $LevelCompleteOverlay/CenterContainer/Panel/VBox/ScoreBox/ScoreLabel
@onready var lc_fill_bonus_label: Label = $LevelCompleteOverlay/CenterContainer/Panel/VBox/FillBonusBox/FillBonusLabel
@onready var lc_lives_bonus_label: Label = $LevelCompleteOverlay/CenterContainer/Panel/VBox/LivesBonusBox/LivesBonusLabel
@onready var impressum_button: LinkButton = $ImpressumButton
@onready var impressum_overlay: Control = $ImpressumOverlay
@onready var impressum_close_button: Button = $ImpressumOverlay/CenterContainer/Panel/VBox/CloseButton
@onready var help_button: Button = $TopRightButtons/HelpButton
@onready var help_overlay: Control = $HelpOverlay
@onready var help_close_button: Button = $HelpOverlay/CenterContainer/Panel/VBox/CloseButton
@onready var fullscreen_button: Button = $TopRightButtons/FullscreenButton

var _screenshot_popup: Control = null
var _screenshot_popup_scene: PackedScene = preload("res://scenes/ui/screenshot_popup.tscn")


func _ready():
	# Connect to GameManager signals
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.fill_changed.connect(_on_fill_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.level_completed.connect(_on_level_completed)

	# Connect direction button
	direction_button.pressed.connect(_on_direction_button_pressed)

	# Connect pause and stop buttons
	pause_button.pressed.connect(_on_pause_button_pressed)
	stop_button.pressed.connect(_on_stop_button_pressed)

	# Connect game over button
	game_over_new_game_button.pressed.connect(_on_game_over_new_game_pressed)

	# Connect game over and leaderboard signals
	GameManager.game_over.connect(_on_game_over_for_leaderboard)
	LeaderboardManager.score_submitted.connect(_on_score_submitted)
	LeaderboardManager.score_failed.connect(_on_score_failed)
	LeaderboardManager.leaderboard_loaded.connect(_on_game_over_leaderboard_loaded)
	LeaderboardManager.leaderboard_failed.connect(_on_game_over_leaderboard_failed)
	LeaderboardManager.rate_limited.connect(_on_rate_limited)

	# Connect impressum buttons (only visible on web)
	impressum_button.visible = OS.has_feature("web")
	impressum_button.pressed.connect(_on_impressum_button_pressed)
	impressum_close_button.pressed.connect(_on_impressum_close_pressed)

	# Connect help buttons
	help_button.pressed.connect(_on_help_button_pressed)
	help_close_button.pressed.connect(_on_help_close_pressed)

	# Connect fullscreen button (only visible on web)
	fullscreen_button.visible = OS.has_feature("web")
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)

	# Connect to game's direction signal when game is available
	await get_tree().process_frame
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.direction_changed.connect(_on_direction_changed)
		_update_direction_button(game.vertical_wall)

	# Initial update
	_update_all()
	_update_overlays()


func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _on_direction_changed(vertical: bool):
	_update_direction_button(vertical)


func _update_all():
	_on_score_changed(GameManager.score)
	_on_level_changed(GameManager.level)
	_on_lives_changed(GameManager.lives)
	_on_time_changed(GameManager.time)
	_on_fill_changed(GameManager.filled)


func _on_score_changed(score: int):
	score_label.text = "%d" % score


func _on_level_changed(level: int):
	# Display balls count (balls = level + 1)
	level_label.text = "%d" % (level + 1)


func _on_lives_changed(lives: int):
	lives_label.text = "%d" % lives


func _on_time_changed(time: int):
	time_label.text = "%d" % time

	# Visual warning when time is low
	if time <= 5:
		time_label.add_theme_color_override("font_color", Color.RED)
	else:
		time_label.add_theme_color_override("font_color", Color.BLACK)


func _on_fill_changed(percent: int):
	fill_label.text = "%d%%" % percent

	# Highlight when close to goal
	if percent >= 75:
		fill_label.add_theme_color_override("font_color", Color(0, 0.5, 0))  # Dark green
	else:
		fill_label.add_theme_color_override("font_color", Color.BLACK)


func _on_direction_button_pressed():
	# Find the game node and toggle direction
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.vertical_wall = not game.vertical_wall
		# Note: _update_direction_button is called via signal


func _update_direction_button(vertical: bool):
	direction_button.icon = _icon_arrow_v if vertical else _icon_arrow_h


func _on_pause_button_pressed():
	if GameManager.state == GameManager.GameState.RUNNING:
		GameManager.set_paused(true)
		pause_button.icon = _icon_play
	elif GameManager.state == GameManager.GameState.PAUSED:
		GameManager.set_paused(false)
		pause_button.icon = _icon_pause


func _on_stop_button_pressed():
	GameManager.close_game()


func _on_game_over_new_game_pressed():
	# Ensure nickname is saved (score already submitted on game over)
	if _user_entry and _user_entry.has_method("get_nickname"):
		var nickname: String = _user_entry.get_nickname()
		if nickname.length() >= 3:
			LeaderboardManager.set_nickname(nickname)
			# Final update to server if not already sent
			LeaderboardManager.update_nickname(nickname)

	GameManager.new_game()


func _on_impressum_button_pressed():
	impressum_overlay.visible = true
	# Pause game if running
	if GameManager.state == GameManager.GameState.RUNNING:
		GameManager.set_paused(true)


func _on_impressum_close_pressed():
	impressum_overlay.visible = false
	# Resume game if it was paused by opening impressum
	if GameManager.state == GameManager.GameState.PAUSED:
		GameManager.set_paused(false)


func _on_help_button_pressed():
	help_overlay.visible = true
	# Pause game if running
	if GameManager.state == GameManager.GameState.RUNNING:
		GameManager.set_paused(true)


func _on_help_close_pressed():
	help_overlay.visible = false
	# Resume game if it was paused by opening help
	if GameManager.state == GameManager.GameState.PAUSED:
		GameManager.set_paused(false)


func _on_fullscreen_button_pressed():
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_state_changed(state: GameManager.GameState):
	# Update game over overlays based on sub-state
	match state:
		GameManager.GameState.GAME_OVER_SPLASH:
			game_over_splash.visible = true
			game_over_overlay.visible = false
		GameManager.GameState.GAME_OVER_LEADERBOARD:
			game_over_splash.visible = false
			# Skip leaderboard for zero points - go directly to start screen
			if GameManager.score == 0:
				GameManager.close_game()
			else:
				game_over_overlay.visible = true
		GameManager.GameState.BEFORE_FIRST_GAME:
			# Hide all overlays when returning to menu
			game_over_splash.visible = false
			game_over_overlay.visible = false
			pause_overlay.visible = false
			level_complete_overlay.visible = false
		_:
			# Hide game over overlays for all other states
			game_over_splash.visible = false
			game_over_overlay.visible = false
	_update_overlays()


func _update_overlays():
	if not is_node_ready():
		return
	var state := GameManager.state
	if pause_overlay:
		pause_overlay.visible = state == GameManager.GameState.PAUSED
	# Game over overlays are managed by _on_state_changed match statement
	if level_complete_overlay:
		# Level complete overlay is managed by _on_level_completed
		if state != GameManager.GameState.BETWEEN_LEVELS:
			level_complete_overlay.visible = false

	# Update button states
	_update_button_states(state)


func _update_button_states(state: GameManager.GameState):
	# Stop button: enabled during active game
	var can_stop := state in [
		GameManager.GameState.RUNNING,
		GameManager.GameState.PAUSED,
		GameManager.GameState.BETWEEN_LEVELS
	]
	stop_button.disabled = not can_stop

	# Pause button: enabled when running or paused
	var can_pause := state in [
		GameManager.GameState.RUNNING,
		GameManager.GameState.PAUSED
	]
	pause_button.disabled = not can_pause

	# Direction button: enabled only when running
	direction_button.disabled = state != GameManager.GameState.RUNNING


func _on_level_completed(_level: int, fill_bonus: int, lives_bonus: int):
	# Show overlay with trophy and bonuses
	lc_level_label.text = ""  # Trophy is enough, no "Level Complete" text
	lc_score_label.text = "%d" % GameManager.score
	lc_fill_bonus_label.text = "+%d" % fill_bonus
	lc_lives_bonus_label.text = "+%d" % lives_bonus
	level_complete_overlay.visible = true

	# Animate bonuses counting down to score
	await _animate_bonus_counting(fill_bonus, lives_bonus)

	# Countdown 3, 2, 1
	for countdown in [3, 2, 1]:
		if GameManager.state != GameManager.GameState.BETWEEN_LEVELS:
			break
		lc_level_label.text = "%d" % countdown
		await get_tree().create_timer(1.0).timeout

	# Proceed to next level
	level_complete_overlay.visible = false

	# Wait a frame for overlay to actually disappear before screenshot
	await get_tree().process_frame

	# Capture screenshot after overlay is hidden
	LeaderboardManager.capture_screenshot(get_viewport())

	GameManager.next_level()


func _animate_bonus_counting(fill_bonus: int, lives_bonus: int):
	const ANIM_DURATION := 1.5
	var current_score := GameManager.score

	# Wait a moment before starting
	await get_tree().create_timer(0.5).timeout

	# Animate fill bonus counting down
	if fill_bonus > 0:
		var steps := mini(fill_bonus, 60)
		var step_delay := ANIM_DURATION / steps
		var bonus_per_step := fill_bonus / steps
		var remainder := fill_bonus % steps
		var remaining := fill_bonus

		for i in range(steps):
			if GameManager.state != GameManager.GameState.BETWEEN_LEVELS:
				return
			var add := bonus_per_step + (1 if i < remainder else 0)
			remaining -= add
			current_score += add
			lc_score_label.text = "%d" % current_score
			lc_fill_bonus_label.text = "+%d" % remaining
			GameManager.add_score(add)
			await get_tree().create_timer(step_delay).timeout

		lc_fill_bonus_label.text = "+0"

	# Brief pause between bonuses
	await get_tree().create_timer(0.3).timeout

	# Animate lives bonus counting down
	if lives_bonus > 0:
		var steps := mini(lives_bonus, 60)
		var step_delay := ANIM_DURATION / steps
		var bonus_per_step := lives_bonus / steps
		var remainder := lives_bonus % steps
		var remaining := lives_bonus

		for i in range(steps):
			if GameManager.state != GameManager.GameState.BETWEEN_LEVELS:
				return
			var add := bonus_per_step + (1 if i < remainder else 0)
			remaining -= add
			current_score += add
			lc_score_label.text = "%d" % current_score
			lc_lives_bonus_label.text = "+%d" % remaining
			GameManager.add_score(add)
			await get_tree().create_timer(step_delay).timeout

		lc_lives_bonus_label.text = "+0"

	# Wait a moment before continuing
	await get_tree().create_timer(0.5).timeout


var _current_screenshot: ImageTexture = null
var _nickname_update_timer: Timer = null
var _rate_limit_timer: Timer = null
var _rate_limit_remaining: int = 0
# Flow ID to validate API responses are for current game over
var _pending_flow_id: int = 0


func _on_game_over_for_leaderboard():
	# Capture flow ID for validating API responses
	_pending_flow_id = GameManager.get_game_over_flow_id()

	# Clear previous entries
	_clear_game_over_entries()
	_user_entry = null

	# Capture screenshot before submission clears it
	if LeaderboardManager.pending_screenshot != null:
		_current_screenshot = ImageTexture.create_from_image(LeaderboardManager.pending_screenshot)
	else:
		_current_screenshot = null

	# Submit score in background (splash visibility managed by _on_state_changed)
	if LeaderboardManager.is_token_valid():
		LeaderboardManager.submit_score(GameManager.score, GameManager.level)
	else:
		# No token, just load leaderboard
		LeaderboardManager.load_leaderboard()


func _on_score_submitted(_score_id: String, _update_token: String, _rank: int, _stored: bool):
	# Note: leaderboard entries come with the score response, no need to request separately
	pass


func _on_score_failed(_error: String):
	# Score submission failed, try to load leaderboard as fallback
	# (don't call on_api_ready yet - wait for leaderboard response)
	LeaderboardManager.load_leaderboard()


func _on_game_over_leaderboard_loaded(entries: Array, _user_rank: int, _user_entries: Array):
	# Only handle during game over (either sub-state)
	if not GameManager.is_game_over():
		return
	game_over_loading_label.visible = false
	_clear_game_over_entries()

	var user_score := GameManager.score
	var user_entry_inserted := false

	# Note: _user_rank from API is the rank of user's BEST score overall, not this game's score.
	# We insert by score comparison to ensure correct position regardless of API response.
	for entry_data in entries:
		var entry_rank: int = entry_data.get("rank", 0)
		var entry_score: int = entry_data.get("score", 0)
		var is_user: bool = entry_data.get("is_user", false)

		# Insert user's editable entry when we find a lower score (if score > 0)
		if user_score > 0 and not user_entry_inserted and user_score >= entry_score:
			_create_user_entry(entry_rank)
			user_entry_inserted = true

		# Skip API entry if it's the same user with same score (we replaced it)
		if is_user and entry_score == user_score and user_entry_inserted:
			continue

		var entry = _entry_scene.instantiate()
		game_over_entries_container.add_child(entry)
		entry.setup(entry_data, is_user, false)  # never editable for API entries
		entry.screenshot_clicked.connect(_on_screenshot_clicked)

	# Add user's editable entry at end if not inserted yet (if score > 0)
	if user_score > 0 and not user_entry_inserted:
		# Rank is after the last entry, or 1 if no entries
		var last_rank: int = 1
		if entries.size() > 0:
			last_rank = entries[entries.size() - 1].get("rank", 0) + 1
		_create_user_entry(last_rank)

	_update_game_over_button_state()

	# Notify GameManager that API is ready (it will validate flow_id)
	GameManager.on_api_ready(_pending_flow_id)


func _on_game_over_leaderboard_failed(_error: String):
	# Only handle during game over (either sub-state)
	if not GameManager.is_game_over():
		return
	game_over_loading_label.text = "Offline mode"
	game_over_loading_label.visible = true
	_clear_game_over_entries()

	# Show user's score as editable entry (rank 0 shows as "—")
	if GameManager.score > 0:
		_create_user_entry(0)

	_update_game_over_button_state()

	# Notify GameManager that API is ready (it will validate flow_id)
	GameManager.on_api_ready(_pending_flow_id)


func _create_user_entry(rank: int):
	_user_entry = _entry_scene.instantiate()
	game_over_entries_container.add_child(_user_entry)

	var user_data := {
		"rank": rank,
		"nickname": LeaderboardManager.nickname,
		"score": GameManager.score,
		"level": GameManager.level,
		"country": LeaderboardManager.country,
		"city": LeaderboardManager.city,
		"screenshot_url": ""
	}
	_user_entry.setup(user_data, true, true)  # is_current_user=true, always editable
	_user_entry.name_changed.connect(_on_user_name_changed)
	_user_entry.screenshot_clicked.connect(_on_screenshot_clicked)

	# Show local screenshot if available
	if _current_screenshot != null:
		_user_entry.set_screenshot_texture(_current_screenshot)


func _on_user_name_changed(new_name: String):
	_update_game_over_button_state()

	# Debounce nickname updates (wait 1 second after typing stops)
	if _nickname_update_timer == null:
		_nickname_update_timer = Timer.new()
		_nickname_update_timer.one_shot = true
		_nickname_update_timer.timeout.connect(_on_nickname_update_timeout)
		add_child(_nickname_update_timer)

	_nickname_update_timer.stop()
	if new_name.strip_edges().length() >= 3:
		_nickname_update_timer.start(1.0)


func _on_nickname_update_timeout():
	if _user_entry and _user_entry.has_method("get_nickname"):
		var nickname: String = _user_entry.get_nickname()
		if nickname.length() >= 3:
			LeaderboardManager.update_nickname(nickname)


func _on_screenshot_clicked(url: String, score_id: String):
	if _screenshot_popup == null:
		_screenshot_popup = _screenshot_popup_scene.instantiate()
		add_child(_screenshot_popup)
	if url == "local:" and _current_screenshot != null:
		_screenshot_popup.show_texture(_current_screenshot)
	else:
		_screenshot_popup.show_screenshot(url, score_id)


func _update_game_over_button_state():
	# Require nickname (3+ chars) when user entry is editable
	if _user_entry and _user_entry.has_method("get_nickname"):
		var nickname: String = _user_entry.get_nickname()
		var is_valid := nickname.length() >= 3
		game_over_new_game_button.disabled = not is_valid
	else:
		# No user entry (e.g., score = 0), button always enabled
		game_over_new_game_button.disabled = false


func _clear_game_over_entries():
	for child in game_over_entries_container.get_children():
		child.queue_free()


func _on_rate_limited(retry_after: int):
	_rate_limit_remaining = retry_after
	game_over_loading_label.text = "Rate limited. Retry in %ds..." % retry_after
	game_over_loading_label.visible = true

	# Create timer if not exists
	if _rate_limit_timer == null:
		_rate_limit_timer = Timer.new()
		_rate_limit_timer.one_shot = false
		_rate_limit_timer.timeout.connect(_on_rate_limit_tick)
		add_child(_rate_limit_timer)

	_rate_limit_timer.start(1.0)


func _on_rate_limit_tick():
	_rate_limit_remaining -= 1

	if _rate_limit_remaining <= 0:
		_rate_limit_timer.stop()
		game_over_loading_label.text = "Retrying..."
		# Retry score submission
		if LeaderboardManager.is_token_valid():
			LeaderboardManager.submit_score(GameManager.score, GameManager.level)
		else:
			# Token expired during wait, just load leaderboard
			LeaderboardManager.load_leaderboard()
	else:
		game_over_loading_label.text = "Rate limited. Retry in %ds..." % _rate_limit_remaining
