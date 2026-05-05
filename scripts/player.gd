extends CharacterBody2D

# ═══════════════════════════════════════════════════════════════════════════
# Player — Character movement controller
#
# NOTE: This script is currently DISABLED in the main scene as the game has
# transitioned to an idle activity-based interface. This file is kept for
# potential future features or if movement-based gameplay is re-enabled.
# ═══════════════════════════════════════════════════════════════════════════

@export var speed: int = 200

func _physics_process(_delta):
	"""Handle player movement using WASD or arrow keys"""
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
