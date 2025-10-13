extends Label
class_name ChatText

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $Timer


func play_chat() ->void:
	animation_player.play("ChatSpeaking")
	timer.start()


func _on_timer_timeout() -> void:
	visible_ratio = 0
