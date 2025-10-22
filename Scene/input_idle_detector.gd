extends Node
class_name InputIdleDetector

signal sleep_mode_changed(is_sleeping: bool)

@export var sleep_after_seconds: float = 300.0 #go to sleeping mode after 5 mins

var last_input_time: float = 0.0
var is_sleeping: bool = false
var check_timer: Timer

func _ready() -> void:
	#record running time
	last_input_time = Time.get_ticks_msec() / 1000.0
	
	#building timer to check if the program needs a sleep
	check_timer = Timer.new()
	check_timer.wait_time = 10.0
	check_timer.timeout.connect(_check_sleep_condition)
	add_child(check_timer)
	check_timer.start()
	print("Idle time: %.0fs" % sleep_after_seconds)

func _input(event: InputEvent) -> void:
	#focus on real user inputs
	if event is InputEventMouseButton or \
		event is InputEventMouseMotion or \
		event is InputEventKey:
			_on_user_input()

func _on_user_input() -> void:
	last_input_time = Time.get_ticks_msec() / 1000.0
	if is_sleeping:
		_wake_up()
		
func _check_sleep_condition() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var idle_duration = current_time - last_input_time
	
	#checking if it need to go to sleep
	if not is_sleeping and idle_duration >= sleep_after_seconds:
		_go_to_sleep()

func _go_to_sleep() -> void:
	is_sleeping = true
	sleep_mode_changed.emit(true)
	print("go to sleep, %.0f" % sleep_after_seconds)
	
func _wake_up() -> void:
	is_sleeping = false
	sleep_mode_changed.emit(false)
	print("wake up")

#force wake up
func force_wake_up() -> void:
	last_input_time = Time.get_ticks_msec() / 1000.0
	if is_sleeping:
		_wake_up()
