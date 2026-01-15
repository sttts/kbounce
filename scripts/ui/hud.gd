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
@onready var game_over_share_button: Button = $GameOverOverlay/CenterContainer/Panel/HBox/VBox/ButtonsContainer/ShareButton
@onready var game_over_new_game_button: Button = $GameOverOverlay/CenterContainer/Panel/HBox/VBox/ButtonsContainer/NewGameButton
@onready var game_over_buttons_container: HBoxContainer = $GameOverOverlay/CenterContainer/Panel/HBox/VBox/ButtonsContainer
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
@onready var help_close_button: Button = $HelpOverlay/CenterContainer/Panel/VBox/BottomRow/CloseButton
@onready var help_version_label: Label = $HelpOverlay/CenterContainer/Panel/VBox/BottomRow/VersionLabel
@onready var report_bug_button: Button = $HelpOverlay/CenterContainer/Panel/VBox/BottomRow/ReportBugButton
@onready var share_logs_button: Button = $HelpOverlay/ShareLogsButton
@onready var fullscreen_button: Button = $TopRightButtons/FullscreenButton
@onready var volume_button: Button = $TopRightButtons/VolumeButton
@onready var volume_popup: PanelContainer = $VolumePopup
@onready var volume_slider: HSlider = $VolumePopup/VBox/SliderContainer/VolumeSlider

var _screenshot_popup: Control = null
var _screenshot_popup_scene: PackedScene = preload("res://scenes/ui/screenshot_popup.tscn")

## Retry and report buttons (created dynamically)
var _retry_button: Button = null
var _report_button: Button = null
## Track upload failure state
var _upload_failed_network: bool = false
var _upload_failed_rejected: bool = false
var _rejection_error: String = ""
var _rejection_request_id: String = ""

## Debug mode click counter
var _debug_click_count := 0


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

	# Connect game over buttons
	game_over_share_button.pressed.connect(_on_game_over_share_pressed)
	game_over_new_game_button.pressed.connect(_on_game_over_new_game_pressed)

	# Connect share notification signal
	ShareManager.show_notification.connect(_on_share_notification)

	# Connect game over and leaderboard signals
	GameManager.game_over.connect(_on_game_over_for_leaderboard)
	LeaderboardManager.score_submitted.connect(_on_score_submitted)
	LeaderboardManager.score_failed.connect(_on_score_failed)
	LeaderboardManager.nickname_updated.connect(_on_nickname_updated)
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
	help_version_label.text = BuildInfo.version_tag
	help_version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	help_version_label.gui_input.connect(_on_version_label_input)
	share_logs_button.pressed.connect(_on_share_logs_pressed)

	# Report bug button (hide on native mobile)
	report_bug_button.visible = not OS.has_feature("mobile")
	report_bug_button.pressed.connect(_on_report_bug_pressed)

	# Hide fullscreen button on native mobile (always fullscreen) and iOS web (unsupported)
	var is_native_mobile := OS.has_feature("mobile")
	var is_ios_web := OS.has_feature("web") and (OS.has_feature("web_ios") or _is_ios_safari())
	fullscreen_button.visible = not (is_native_mobile or is_ios_web)
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)

	# Connect volume button and slider
	volume_button.pressed.connect(_on_volume_button_pressed)
	volume_slider.value = AudioManager.get_volume_linear()
	volume_slider.value_changed.connect(_on_volume_slider_changed)

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


func _is_ios_safari() -> bool:
	# Detect iOS Safari via JavaScript user agent
	if not OS.has_feature("web"):
		return false
	# eval returns Variant, convert to string for reliable comparison
	var result = JavaScriptBridge.eval("(/iPhone|iPad|iPod/.test(navigator.userAgent)) ? 'yes' : 'no'")
	return str(result) == "yes"


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
		time_label.add_theme_color_override("font_color", Color.WHITE)


func _on_fill_changed(percent: int):
	fill_label.text = "%d%%" % percent

	# Highlight when close to goal
	if percent >= 75:
		fill_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Light green
	else:
		fill_label.add_theme_color_override("font_color", Color.WHITE)


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
	# Send final nickname update (only saves locally after server confirms)
	if _user_entry and _user_entry.has_method("get_nickname"):
		var nickname: String = _user_entry.get_nickname()
		if nickname.length() >= 3:
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


func _on_version_label_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_debug_click_count += 1
		if _debug_click_count >= 5:
			_debug_click_count = 0
			var game = get_tree().get_first_node_in_group("game")
			if game and game.has_method("_setup_debug_ui"):
				game._setup_debug_ui()
				help_version_label.text = BuildInfo.version_tag + " [DEBUG]"


func _on_share_logs_pressed():
	ShareManager.share_logs()


func _on_report_bug_pressed():
	OS.shell_open("https://github.com/sttts/kbounce/issues")


func _on_fullscreen_button_pressed():
	if OS.has_feature("web"):
		# Use JavaScript Fullscreen API for better mobile Safari support
		JavaScriptBridge.eval("""
			if (document.fullscreenElement || document.webkitFullscreenElement) {
				if (document.exitFullscreen) {
					document.exitFullscreen();
				} else if (document.webkitExitFullscreen) {
					document.webkitExitFullscreen();
				}
			} else {
				var elem = document.documentElement;
				if (elem.requestFullscreen) {
					elem.requestFullscreen();
				} else if (elem.webkitRequestFullscreen) {
					elem.webkitRequestFullscreen();
				}
			}
		""")
	else:
		var current_mode := DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_volume_button_pressed():
	volume_popup.visible = not volume_popup.visible
	if volume_popup.visible:
		# Position popup to the left of the button
		var button_rect := volume_button.get_global_rect()
		volume_popup.global_position = Vector2(
			button_rect.position.x - volume_popup.size.x - 8,
			button_rect.position.y + (button_rect.size.y - volume_popup.size.y) / 2
		)


func _input(event: InputEvent):
	if not volume_popup.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var popup_rect := volume_popup.get_global_rect()
		var button_rect := volume_button.get_global_rect()
		var click_pos: Vector2 = (event as InputEventMouseButton).position
		# Close if click is outside popup and button
		if not popup_rect.has_point(click_pos) and not button_rect.has_point(click_pos):
			volume_popup.visible = false
			get_viewport().set_input_as_handled()


func _on_volume_slider_changed(value: float):
	AudioManager.set_volume_linear(value)


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
				# Keep splash visible and wait before closing
				game_over_splash.visible = true
				await get_tree().create_timer(2.0).timeout
				game_over_splash.visible = false
				# Only close if still in game over state (user may have started new game)
				if GameManager.is_game_over():
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
	# Stop button: enabled during active game and game over leaderboard
	var can_stop := state in [
		GameManager.GameState.RUNNING,
		GameManager.GameState.PAUSED,
		GameManager.GameState.BETWEEN_LEVELS,
		GameManager.GameState.GAME_OVER_LEADERBOARD
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
var _current_screenshot_image: Image = null
var _nickname_update_timer: Timer = null
var _rate_limit_timer: Timer = null
var _rate_limit_remaining: int = 0
# Flow ID to validate API responses are for current game over
var _pending_flow_id: int = 0
# Track if current nickname is rejected (profanity etc)
var _nickname_rejected: bool = false


func _on_game_over_for_leaderboard():
	# Capture flow ID for validating API responses
	_pending_flow_id = GameManager.get_game_over_flow_id()
	print("[HUD] game_over_for_leaderboard flow_id=%d token_valid=%s" % [_pending_flow_id, LeaderboardManager.is_token_valid()])

	# Reset nickname rejection state
	_nickname_rejected = false

	# Reset upload failure state and hide any retry/report buttons
	_hide_retry_report_buttons()

	# Clear previous entries
	_clear_game_over_entries()
	_user_entry = null

	# Capture screenshot before submission clears it
	if LeaderboardManager.pending_screenshot != null:
		_current_screenshot_image = LeaderboardManager.pending_screenshot.duplicate()
		_current_screenshot = ImageTexture.create_from_image(LeaderboardManager.pending_screenshot)
	else:
		_current_screenshot_image = null
		_current_screenshot = null

	# Submit score in background (splash visibility managed by _on_state_changed)
	if LeaderboardManager.is_token_valid():
		LeaderboardManager.submit_score(GameManager.score, GameManager.level)
	else:
		# No token, just load leaderboard
		LeaderboardManager.load_leaderboard()


func _on_score_submitted(_score_id: String, _update_token: String, _rank: int, _stored: bool):
	# Hide retry/report buttons on successful submission
	_hide_retry_report_buttons()
	# Note: leaderboard entries come with the score response, no need to request separately


func _on_score_failed(error: String, request_id: String):
	# Rate limited errors are handled by _on_rate_limited with retry timer
	if error == "Rate limited":
		return

	# Show user-facing errors (like profanity filter)
	if error == "Nickname contains inappropriate content":
		_show_error_notification(error)
		LeaderboardManager.load_leaderboard()
		return

	# Detect network failures vs server rejections
	var is_network_error := error.begins_with("Request failed:") or error.contains("connect") or error.contains("timeout")

	if is_network_error:
		_upload_failed_network = true
		_upload_failed_rejected = false
		game_over_loading_label.text = "Upload failed!"
		game_over_loading_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		game_over_loading_label.visible = true
		_show_retry_button()
	else:
		# Server rejected the score (validation failed, etc.)
		_upload_failed_network = false
		_upload_failed_rejected = true
		_rejection_error = error
		_rejection_request_id = request_id
		game_over_loading_label.text = "Score rejected!"
		game_over_loading_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		game_over_loading_label.visible = true
		_show_report_button()

	# Load leaderboard as fallback
	LeaderboardManager.load_leaderboard()


func _on_nickname_updated(success: bool, error: String):
	if success:
		_nickname_rejected = false
		if _user_entry and _user_entry.has_method("set_nickname_invalid"):
			_user_entry.set_nickname_invalid(false)
		_update_game_over_button_state()
		return

	# Rate limited errors are handled by _on_rate_limited
	if error == "Rate limited":
		return

	# Mark nickname as rejected (profanity filter etc)
	if error == "Nickname contains inappropriate content":
		_nickname_rejected = true
		if _user_entry and _user_entry.has_method("set_nickname_invalid"):
			_user_entry.set_nickname_invalid(true)
		_update_game_over_button_state()


func _on_game_over_leaderboard_loaded(entries: Array, _user_rank: int, _user_entries: Array):
	print("[HUD] leaderboard_loaded is_game_over=%s state=%s" % [GameManager.is_game_over(), GameManager.state])
	# Only handle during game over (either sub-state)
	if not GameManager.is_game_over():
		return
	# Keep failure message visible if retry/report button is showing
	if not _upload_failed_network and not _upload_failed_rejected:
		game_over_loading_label.visible = false
	_clear_game_over_entries()

	const MAX_VISIBLE := 9
	var user_score := GameManager.score

	# Build combined list with user entry at correct position
	var combined_entries: Array = []
	var user_position := -1

	for entry_data in entries:
		var entry_score: int = entry_data.get("score", 0)
		var is_user: bool = entry_data.get("is_user", false)

		# Insert user entry when we find a lower score (if score > 0)
		if user_score > 0 and user_position == -1 and user_score >= entry_score:
			user_position = combined_entries.size()
			combined_entries.append({"is_user_entry": true, "rank": entry_data.get("rank", 0)})

		# Skip API entry if it's the same user with same score (we replaced it)
		if is_user and entry_score == user_score and user_position != -1:
			continue

		combined_entries.append(entry_data)

	# Add user entry at end if not inserted yet (if score > 0)
	if user_score > 0 and user_position == -1:
		user_position = combined_entries.size()
		var last_rank: int = 1
		if entries.size() > 0:
			last_rank = entries[entries.size() - 1].get("rank", 0) + 1
		combined_entries.append({"is_user_entry": true, "rank": last_rank})

	# Calculate which entries to show (max 9, with at most 3 above user for keyboard visibility)
	const MAX_ABOVE := 3  # Keep user entry lower so keyboard doesn't cover it
	var start_idx := 0
	var end_idx := combined_entries.size()

	if user_position != -1:
		# Position user with at most MAX_ABOVE entries above (rest below)
		start_idx = maxi(0, user_position - MAX_ABOVE)
		end_idx = mini(start_idx + MAX_VISIBLE, combined_entries.size())
	elif combined_entries.size() > MAX_VISIBLE:
		# No user entry, just show first 9
		end_idx = MAX_VISIBLE

	# Create visible entries
	for i in range(start_idx, end_idx):
		var entry_data = combined_entries[i]
		if entry_data.get("is_user_entry", false):
			_create_user_entry(entry_data.get("rank", 0))
		else:
			var is_user: bool = entry_data.get("is_user", false)
			var entry = _entry_scene.instantiate()
			game_over_entries_container.add_child(entry)
			entry.setup(entry_data, is_user, false)
			entry.screenshot_clicked.connect(_on_screenshot_clicked)

	_update_game_over_button_state()

	# Notify GameManager that API is ready (it will validate flow_id)
	GameManager.on_api_ready(_pending_flow_id)


func _on_game_over_leaderboard_failed(error: String):
	# Only handle during game over (either sub-state)
	if not GameManager.is_game_over():
		return

	# Rate limited errors are handled by _on_rate_limited with retry timer
	if error == "Rate limited":
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
	# Clear rejected state when user types
	if _nickname_rejected:
		_nickname_rejected = false
		if _user_entry and _user_entry.has_method("set_nickname_invalid"):
			_user_entry.set_nickname_invalid(false)

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
		_screenshot_popup.show_texture(_current_screenshot, GameManager.score, GameManager.level)
	else:
		_screenshot_popup.show_screenshot(url, score_id, GameManager.score, GameManager.level)


func _on_game_over_share_pressed():
	ShareManager.share_score(GameManager.score, GameManager.level, _current_screenshot_image)


var _share_notification_dialog: AcceptDialog = null

func _on_share_notification(message: String):
	if _share_notification_dialog == null:
		_share_notification_dialog = AcceptDialog.new()
		_share_notification_dialog.title = "Shared"
		add_child(_share_notification_dialog)
	_share_notification_dialog.dialog_text = message
	_share_notification_dialog.popup_centered()


var _error_notification_dialog: AcceptDialog = null

func _show_error_notification(message: String):
	if _error_notification_dialog == null:
		_error_notification_dialog = AcceptDialog.new()
		_error_notification_dialog.title = "Error"
		add_child(_error_notification_dialog)
	_error_notification_dialog.dialog_text = message
	_error_notification_dialog.popup_centered()


func _update_game_over_button_state():
	# Require nickname (3+ chars) and not rejected (profanity)
	if _user_entry and _user_entry.has_method("get_nickname"):
		var nickname: String = _user_entry.get_nickname()
		var is_valid := nickname.length() >= 3 and not _nickname_rejected
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
	# Stop if no longer in game over state (user started new game)
	if not GameManager.is_game_over():
		_rate_limit_timer.stop()
		return

	_rate_limit_remaining -= 1

	if _rate_limit_remaining <= 0:
		_rate_limit_timer.stop()
		game_over_loading_label.text = "Retrying..."

		# Retry score submission or load leaderboard
		if LeaderboardManager.is_token_valid():
			LeaderboardManager.submit_score(GameManager.score, GameManager.level)
		else:
			LeaderboardManager.load_leaderboard()
	else:
		game_over_loading_label.text = "Rate limited. Retry in %ds..." % _rate_limit_remaining


func _show_retry_button():
	_hide_retry_report_buttons()

	_retry_button = Button.new()
	_retry_button.text = "Retry"
	_retry_button.custom_minimum_size = Vector2(80, 48)
	_retry_button.pressed.connect(_on_retry_upload_pressed)
	game_over_buttons_container.add_child(_retry_button)
	game_over_buttons_container.move_child(_retry_button, 0)


func _show_report_button():
	_hide_retry_report_buttons()

	_report_button = Button.new()
	_report_button.text = "Report"
	_report_button.custom_minimum_size = Vector2(80, 48)
	_report_button.pressed.connect(_on_report_rejection_pressed)
	game_over_buttons_container.add_child(_report_button)
	game_over_buttons_container.move_child(_report_button, 0)


func _hide_retry_report_buttons():
	if _retry_button != null:
		_retry_button.queue_free()
		_retry_button = null
	if _report_button != null:
		_report_button.queue_free()
		_report_button = null
	_upload_failed_network = false
	# Reset label color to default grey
	game_over_loading_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	_upload_failed_rejected = false


func _on_retry_upload_pressed():
	_hide_retry_report_buttons()
	game_over_loading_label.text = "Retrying..."
	game_over_loading_label.visible = true

	# Request new token and resubmit
	LeaderboardManager.request_game_token()
	# Wait for token then submit (the game_over flow will handle this)
	await LeaderboardManager.token_received
	if GameManager.is_game_over():
		LeaderboardManager.submit_score(GameManager.score, GameManager.level)


func _on_report_rejection_pressed():
	# Open GitHub issue with pre-filled title and body
	var title := "Score rejected: " + _rejection_error
	var body := "**Error:** " + _rejection_error + "\n"
	if not _rejection_request_id.is_empty():
		body += "**Request ID:** " + _rejection_request_id + "\n"
	body += "**Score:** " + str(GameManager.score) + "\n"
	body += "**Level:** " + str(GameManager.level) + "\n"
	body += "**Version:** " + BuildInfo.version_tag + "\n"
	body += "**Platform:** " + OS.get_name() + "\n\n"
	body += "Please describe what happened:\n\n"

	var url := "https://github.com/sttts/kbounce/issues/new?title=" + title.uri_encode() + "&body=" + body.uri_encode()
	OS.shell_open(url)
