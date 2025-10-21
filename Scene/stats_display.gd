extends Label
class_name StatsDisplay

enum DisplayMode{
	SESSION, #current session data
	TOTAL #total data
}

var current_mode: DisplayMode = DisplayMode.SESSION
var cached_session_time: float = 0.0
var cached_session_inputs: int = 0
var cached_total_time: float = 0.0
var cached_total_inputs: int = 0

#initialize
func _ready() -> void:
	#mouse interact
	mouse_filter = Control.MOUSE_FILTER_STOP
	#basic text
	text = "Delong has been with you for 0 minutes\nYou have inputted 0 times"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	print("initialize statsdisplay")

#renew data
func update_stats(session_time: float, session_inputs: int, total_time: float, total_inputs: int) -> void:
	#cache data
	cached_session_time = session_time
	cached_session_inputs = session_inputs
	cached_total_time = total_time
	cached_total_inputs = total_inputs
	
	_update_text()

func _update_text() -> void:
	var time_minutes: int
	var input_count: int
	var prefix: String
	
	if current_mode == DisplayMode.SESSION:
		time_minutes = int(cached_session_time)
		input_count = cached_session_inputs
		prefix = "Delong has been with you for"
	else:
		time_minutes = int(cached_total_time)
		input_count = cached_total_inputs
		prefix = "Delong has been with you in total for"
	
	#plural and muitipul nouns	
	var time_unit: String = "minute" if time_minutes == 1 else "minutes"
	var input_unit: String = "time" if input_count == 1 else "times"
	
	text = "%s %d %s\nYou have inputted %d %s" % [prefix, time_minutes, time_unit, input_count, input_unit]
	
#mouse hover effect
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		modulate = Color(1.2, 1.2, 1.2) 
	elif what == NOTIFICATION_MOUSE_EXIT:
		modulate = Color(1.0, 1.0, 1.0)
