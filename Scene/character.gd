extends Node2D
class_name Character

@onready var animation_player: AnimationPlayer = $AnimationPlayer

signal chat

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_RIGHT :  # checking the mouse move.
		get_tree().root.position += Vector2i(event.relative) # mapping the mouse location with 2ivector
		
	if event.is_action_pressed("ChatStart"):
		chat.emit() #sending signal
		animation_player.play("Speaking") #playing speakanimation
		
