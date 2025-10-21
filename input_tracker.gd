extends Node
class_name InputTracker

signal stats_updated(session_time: float, session_inputs: int, total_time: float, total_inputs: int)

#session data
var session_start_time: float = 0.0
var session_input_count: int = 0

#total data
var total_time_minutes: float = 0.0
var total_input_count: int = 0

#settings
@export var update_interval: float = 1.0
@export var save_interval: float = 60.0

var update_timer: Timer
var save_timer: Timer
var config_manager: ConfigManager

#initialize
func _ready() -> void:
	#record the starting time of session
	session_start_time = Time.get_ticks_msec()/ 1000.0
	
	#create the renew timer
	update_timer = Timer.new()
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(_emit_stats_update)
	add_child(update_timer)
	update_timer.start()
	
	#create the automatic save system
	save_timer = Timer.new()
	save_timer.wait_time = save_interval
	save_timer.timeout.connect(_save_stats)
	add_child(save_timer)
	save_timer.start()
	
	print("initialize the input tracker")

# input monitoring
func _input(event: InputEvent) -> void:
	#only calculate the real user inputs
	if event is InputEventMouseButton and event.pressed:
		_record_input()
	elif event is InputEventKey and event.pressed and not event.echo:
		_record_input()

func _record_input() -> void:
	session_input_count += 1
	
#statistical calculation
func get_session_time_minutes() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - session_start_time) / 60.0

func get_total_time_minutes() -> float:
	return total_time_minutes + get_session_time_minutes()

func get_session_inputs() -> int:
	return session_input_count

func get_total_inputs() -> int:
	return total_input_count + session_input_count


#emit
func _emit_stats_update() -> void:
	stats_updated.emit(
		get_session_time_minutes(),
		get_session_inputs(),
		get_total_time_minutes(),
		get_total_inputs()
	)

#Data Persistence
func set_config_manager(manager: ConfigManager) -> void:
	config_manager = manager
	_load_stats()

func _load_stats() -> void:
	if not config_manager:
		return
	
	total_time_minutes = config_manager.config.get_value("stats", "total_time_minutes", 0.0)
	total_input_count = config_manager.config.get_value("stats", "total_input_count", 0)
	print("reload the histories, %.1f, %d" % [total_time_minutes, total_input_count])

#save data
func _save_stats() -> void:
	if not config_manager:
		return
	
	var current_total_time = get_total_time_minutes()
	var current_total_inputs = get_total_inputs()
	
	config_manager.config.set_value("stats", "total_time_minutes", current_total_time)
	config_manager.config.set_value("stats", "total_input_count", current_total_inputs)
	config_manager.config.set_value("stats", "last_saved", Time.get_datetime_string_from_system())
	
	var err = config_manager.config_save(config_manager.CONFIG_PATH)
	if err == OK:
		print("saved the statistical datas")
		
#save data before quit
func save_on_exit() -> void:
	total_time_minutes = get_total_time_minutes()
	total_input_count = get_total_inputs()
	_save_stats()
	print("saved the statistical datas before exit")
