# screenshot_popup.gd - Reusable screenshot popup viewer
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Control

var _http_request: HTTPRequest = null
var _current_url: String = ""

@onready var background: Button = $Background
@onready var image: TextureRect = $CenterContainer/ScreenshotImage


func _ready():
	visible = false
	background.pressed.connect(_on_close)


func show_screenshot(url: String):
	if url.is_empty():
		return

	_current_url = url
	visible = true
	image.texture = null

	if _http_request == null:
		_http_request = HTTPRequest.new()
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)

	_http_request.request(url)


func show_texture(texture: Texture2D):
	if texture == null:
		return

	_current_url = ""
	visible = true
	image.texture = texture


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
