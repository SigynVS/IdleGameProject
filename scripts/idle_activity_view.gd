extends CanvasLayer

var background: ColorRect

func _ready():
	layer = -100
	_build_view()
	if GameData:
		GameData.activity_changed.connect(_on_activity_changed)
		_on_activity_changed(GameData.active_activity_id)

func _build_view():
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.09, 0.11)
	add_child(background)

func _on_activity_changed(activity_id: String):
	var activity = GameData.get_activity(activity_id)
	if activity.is_empty():
		background.color = Color(0.08, 0.09, 0.11)
		return

	background.color = activity.get("background", Color(0.08, 0.09, 0.11))
