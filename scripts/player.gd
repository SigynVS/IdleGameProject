extends CharacterBody2D

@export var speed = 200

var _work_tween: Tween = null

func _physics_process(_delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

func start_work_timer(duration: float):
	var bar = find_child("WorkProgress")
	if not bar:
		return
	
	# Kill any existing tween before starting a new one
	if _work_tween and _work_tween.is_running():
		_work_tween.kill()
	
	bar.max_value = duration
	bar.value = 0
	bar.show()
	
	_work_tween = create_tween()
	_work_tween.tween_property(bar, "value", duration, duration)
	
	await _work_tween.finished
	bar.hide()
