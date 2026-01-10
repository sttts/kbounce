# leaderboard_entry.gd - Single leaderboard entry row
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends HBoxContainer

signal name_changed(new_name: String)
signal screenshot_clicked(url: String, score_id: String)

# Static screenshot cache shared across all entries
static var _screenshot_cache: Dictionary = {}
# Static flag cache shared across all entries
static var _flag_cache: Dictionary = {}

@onready var rank_label: Label = $RankLabel
@onready var flag_texture: TextureRect = $FlagTexture
@onready var location_label: Label = $LocationLabel
@onready var name_label: Label = $NameLabel
@onready var name_edit: LineEdit = $NameEdit
@onready var level_label: Label = $LevelLabel
@onready var score_label: Label = $ScoreLabel
@onready var screenshot_button: TextureButton = $ScreenshotButton

var _score_id: String = ""
var _screenshot_url: String = ""
var _screenshot_thumbnail_url: String = ""
var _local_screenshot: Texture2D = null
var _is_editable: bool = false
var _is_reportable: bool = false
var _http_request: HTTPRequest = null
var _pulse_tween: Tween = null
var _last_text: String = ""  # For virtual keyboard polling workaround


func _ready():
	set_process(false)  # Disable polling by default
	screenshot_button.pressed.connect(_on_screenshot_pressed)
	name_edit.text_changed.connect(_on_name_text_changed)
	name_edit.focus_entered.connect(_on_name_edit_focused)
	name_edit.focus_exited.connect(_on_name_edit_unfocused)


func _on_name_edit_focused():
	# Show virtual keyboard on mobile web
	if OS.has_feature("web"):
		DisplayServer.virtual_keyboard_show(name_edit.text)
		# Start polling for text changes (virtual keyboard workaround)
		_last_text = name_edit.text
		set_process(true)


func _on_name_edit_unfocused():
	# Hide virtual keyboard
	if OS.has_feature("web"):
		DisplayServer.virtual_keyboard_hide()
		set_process(false)
		# Final check for any text changes
		if name_edit.text != _last_text:
			_last_text = name_edit.text
			name_changed.emit(name_edit.text)


func _process(_delta: float):
	# Poll for text changes when focused (virtual keyboard workaround)
	if name_edit.has_focus() and name_edit.text != _last_text:
		_last_text = name_edit.text
		name_changed.emit(name_edit.text)


func _exit_tree():
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null


func setup(data: Dictionary, is_current_user: bool, editable: bool = false):
	_score_id = data.get("id", "") if data.get("id") != null else ""
	_screenshot_url = data.get("screenshot_url", "") if data.get("screenshot_url") != null else ""
	_screenshot_thumbnail_url = data.get("screenshot_thumbnail_url", "") if data.get("screenshot_thumbnail_url") != null else ""
	_is_editable = editable

	var rank: int = data.get("rank", 0)
	rank_label.text = "#%d" % rank if rank > 0 else "—"

	# Country flag image
	var country_val = data.get("country")
	var country: String = country_val if country_val != null else ""
	if not country.is_empty():
		_load_flag(country.to_lower())
	else:
		flag_texture.visible = false

	# City/location display
	var city_val = data.get("city")
	var city: String = city_val if city_val != null else ""
	if not city.is_empty():
		location_label.text = city
	elif not country.is_empty():
		location_label.text = country
	else:
		location_label.text = "???"
	location_label.visible = true

	var nickname_val = data.get("nickname")
	var nickname: String = nickname_val if nickname_val != null else ""

	# Show editable field for current user entry
	if editable:
		name_label.visible = false
		name_edit.visible = true
		name_edit.text = nickname
	else:
		name_label.visible = true
		name_edit.visible = false
		name_label.text = nickname if not nickname.is_empty() else "???"

	# Display balls count (balls = level + 1)
	var level: int = data.get("level", 1)
	level_label.text = "%d" % (level + 1)

	var score: int = data.get("score", 0)
	score_label.text = _format_score(score)

	# Highlight current user
	if is_current_user:
		if editable:
			# Fancy pulsing gold highlight for editable entry
			_start_pulse_animation()
		else:
			modulate = Color(1.0, 0.95, 0.7)  # Golden highlight

	# Screenshot thumbnail (prefer thumbnail URL, fall back to full screenshot)
	var thumb_url := _screenshot_thumbnail_url if not _screenshot_thumbnail_url.is_empty() else _screenshot_url
	if not thumb_url.is_empty():
		_load_screenshot_thumbnail(thumb_url)
	else:
		screenshot_button.visible = false

	# Only allow reporting other users' entries
	_is_reportable = not is_current_user and not editable and not _score_id.is_empty()


func get_nickname() -> String:
	return name_edit.text.strip_edges()


func set_screenshot_texture(texture: Texture2D):
	_local_screenshot = texture
	screenshot_button.texture_normal = texture
	screenshot_button.visible = true


func _start_pulse_animation():
	# Set initial bright gold color
	modulate = Color(1.0, 0.9, 0.4)

	# Wait until size is computed (may take multiple frames)
	for i in range(10):
		await get_tree().process_frame
		if size.x > 0:
			break

	if size.x > 0:
		pivot_offset = size / 2

		# Create looping pulse animation with color and subtle scale
		_pulse_tween = create_tween()
		_pulse_tween.set_loops()
		_pulse_tween.set_parallel(true)
		_pulse_tween.tween_property(self, "modulate", Color(1.0, 1.0, 0.6), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.chain()
		_pulse_tween.set_parallel(true)
		_pulse_tween.tween_property(self, "modulate", Color(1.0, 0.85, 0.3), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_name_text_changed(new_text: String):
	name_changed.emit(new_text)


func _load_screenshot_thumbnail(url: String):
	# Check cache first
	if _screenshot_cache.has(url):
		var cached_texture: Texture2D = _screenshot_cache[url]
		screenshot_button.texture_normal = cached_texture
		screenshot_button.visible = true
		return

	if _http_request == null:
		_http_request = HTTPRequest.new()
		add_child(_http_request)
		_http_request.request_completed.connect(_on_screenshot_loaded.bind(url))

	_http_request.request(url)


func _on_screenshot_loaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, url: String):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		screenshot_button.visible = false
		return

	var image := Image.new()
	var err := image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		screenshot_button.visible = false
		return

	var texture := ImageTexture.create_from_image(image)

	# Cache the texture
	_screenshot_cache[url] = texture

	screenshot_button.texture_normal = texture
	screenshot_button.visible = true


func _on_screenshot_pressed():
	var reportable_id := _score_id if _is_reportable else ""
	if _local_screenshot != null:
		screenshot_clicked.emit("local:", reportable_id)
	elif not _screenshot_url.is_empty():
		screenshot_clicked.emit(_screenshot_url, reportable_id)


func _format_score(score: int) -> String:
	# Format with thousand separators
	var s := str(score)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


var _flag_http_request: HTTPRequest = null

func _load_flag(country_code: String):
	if country_code.length() != 2:
		flag_texture.visible = false
		return

	# Check cache first
	if _flag_cache.has(country_code):
		flag_texture.texture = _flag_cache[country_code]
		flag_texture.visible = true
		return

	# Load from CDN
	var url := "https://flagcdn.com/w40/%s.png" % country_code
	if _flag_http_request == null:
		_flag_http_request = HTTPRequest.new()
		add_child(_flag_http_request)
		_flag_http_request.request_completed.connect(_on_flag_loaded.bind(country_code))

	_flag_http_request.request(url)


func _on_flag_loaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, country_code: String):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		flag_texture.visible = false
		return

	var image := Image.new()
	var err := image.load_png_from_buffer(body)
	if err != OK:
		flag_texture.visible = false
		return

	var texture := ImageTexture.create_from_image(image)

	# Cache the texture
	_flag_cache[country_code] = texture

	flag_texture.texture = texture
	flag_texture.visible = true
