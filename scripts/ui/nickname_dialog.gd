# nickname_dialog.gd - First launch nickname entry dialog
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Control

signal nickname_submitted(nickname: String)

@onready var line_edit: LineEdit = $CenterContainer/Panel/VBox/LineEdit
@onready var continue_button: Button = $CenterContainer/Panel/VBox/ContinueButton


func _ready():
	# Pre-fill with saved nickname or generate default
	if LeaderboardManager.has_nickname():
		line_edit.text = LeaderboardManager.nickname
	else:
		line_edit.text = LeaderboardManager.generate_default_nickname()
	line_edit.select_all()

	# Connect signals
	continue_button.pressed.connect(_on_continue_pressed)
	line_edit.text_submitted.connect(_on_text_submitted)

	# Focus the text field
	line_edit.grab_focus()


func _on_continue_pressed():
	_submit_nickname()


func _on_text_submitted(_text: String):
	_submit_nickname()


func _submit_nickname():
	var new_nickname := line_edit.text.strip_edges()

	# Use default if empty
	if new_nickname.is_empty():
		new_nickname = LeaderboardManager.generate_default_nickname()

	LeaderboardManager.set_nickname(new_nickname)
	nickname_submitted.emit(new_nickname)
	queue_free()
