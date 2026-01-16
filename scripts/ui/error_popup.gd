extends Control
## Popup dialog for displaying network/replay errors with action buttons.

signal action_pressed
signal closed

enum ErrorType { NETWORK, REJECTION, GENERAL }

@onready var background_button: Button = $BackgroundButton
@onready var title_label: Label = $CenterContainer/Panel/VBox/Title
@onready var message_label: Label = $CenterContainer/Panel/VBox/Message
@onready var action_button: Button = $CenterContainer/Panel/VBox/Buttons/ActionButton
@onready var close_button: Button = $CenterContainer/Panel/VBox/Buttons/CloseButton

var _error_type: ErrorType = ErrorType.GENERAL


func _ready():
	background_button.pressed.connect(_on_close)
	action_button.pressed.connect(_on_action)
	close_button.pressed.connect(_on_close)
	visible = false


func show_error(type: ErrorType, title: String, message: String, action_text: String = ""):
	_error_type = type
	title_label.text = title
	message_label.text = message

	# Configure action button
	if action_text.is_empty():
		action_button.visible = false
	else:
		action_button.visible = true
		action_button.text = action_text

	visible = true


func show_network_error(detail: String = ""):
	var message := tr("Could not connect to the server.")
	if not detail.is_empty():
		message = detail
	show_error(ErrorType.NETWORK, tr("Score upload failed"), message, tr("Retry"))


func show_rejection_error(detail: String = ""):
	var message := tr("Your score could not be verified.")
	if not detail.is_empty():
		message = detail
	show_error(ErrorType.REJECTION, tr("Score Rejected"), message, tr("Report\nBug"))


func get_error_type() -> ErrorType:
	return _error_type


func _on_action():
	# For network errors (Retry), hide popup
	# For rejections (Report), keep popup open so user can see error while reporting
	if _error_type == ErrorType.NETWORK:
		visible = false
	action_pressed.emit()


func _on_close():
	visible = false
	closed.emit()
