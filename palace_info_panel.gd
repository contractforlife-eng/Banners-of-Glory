extends PanelContainer
class_name PalaceInfoPanel

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var alliance_label: Label = $MarginContainer/VBoxContainer/AllianceLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(hide_panel)

func show_palace_info(palace_name: String = "Great Palace", status: String = "Neutral", alliance: String = "None") -> void:
	if title_label:
		title_label.text = palace_name
	if status_label:
		status_label.text = "Current status: " + status
	if alliance_label:
		alliance_label.text = "Controlling alliance: " + alliance
	visible = true

func hide_panel() -> void:
	visible = false
