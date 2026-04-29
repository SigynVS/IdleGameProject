extends CharacterBody2D

@export var speed = 200

func _physics_process(_delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

func start_work_timer(duration: float):
	var bar = find_child("WorkProgress")
	if bar:
		bar.max_value = duration
		bar.value = 0
		bar.show()
		
		var tween = create_tween()
		tween.tween_property(bar, "value", duration, duration)
		
		await tween.finished
		bar.hide()
