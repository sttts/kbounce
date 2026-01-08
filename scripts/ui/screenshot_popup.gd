# screenshot_popup.gd - Reusable screenshot popup viewer
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Control

var _http_request: HTTPRequest = null
var _current_url: String = ""
var _current_score_id: String = ""

@onready var background: Button = $Background
@onready var image: TextureRect = $CenterContainer/VBoxContainer/ScreenshotImage
@onready var report_button: Button = $CenterContainer/VBoxContainer/ReportButton
@onready var report_confirm_dialog: ConfirmationDialog = $ReportConfirmDialog


func _ready():
	visible = false
	background.pressed.connect(_on_close)
	image.gui_input.connect(_on_image_input)
	report_button.pressed.connect(_on_report_pressed)
	report_confirm_dialog.confirmed.connect(_on_report_confirmed)


func show_screenshot(url: String, score_id: String = ""):
	if url.is_empty():
		return

	_current_url = url
	_current_score_id = score_id
	visible = true
	image.texture = null
	_update_report_button()

	if _http_request == null:
		_http_request = HTTPRequest.new()
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)

	_http_request.request(url)


func show_texture(texture: Texture2D):
	if texture == null:
		return

	_current_url = ""
	_current_score_id = ""
	visible = true
	image.texture = texture
	_update_report_button()


func _update_report_button():
	report_button.visible = not _current_score_id.is_empty()
	report_button.disabled = false
	report_button.text = "Report"


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		visible = false
		return

	var img := Image.new()
	var err := img.load_png_from_buffer(body)
	if err != OK:
		err = img.load_jpg_from_buffer(body)
	if err != OK:
		visible = false
		return

	var texture := ImageTexture.create_from_image(img)
	image.texture = texture


func _on_close():
	visible = false


func _on_image_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		visible = false


func _on_report_pressed():
	if not _current_score_id.is_empty():
		report_confirm_dialog.popup_centered()


func _on_report_confirmed():
	if not _current_score_id.is_empty():
		LeaderboardManager.report_score(_current_score_id)
		report_button.disabled = true
		report_button.text = "Reported"
