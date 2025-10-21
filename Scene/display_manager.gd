extends Node
class_name DisplayManager

signal dpi_changed(new_scale: float)

@export_group ("DPI Settings")
@export var base_dpi: float = 96.0 #windows' dpi standard
@export var base_window_size: Vector2i = Vector2i(300, 330) #base window's scale

@export_group("Transition")
@export var enable_smooth_transition: bool = true
@export_range(1.0, 20.0, 0.5) var transition_speed: float = 8.0

#internal status variables
var current_screen_index: int = -1
var current_scale_factor: float = 1.0
var target_scale_factor: float = 1.0
var is_transitioning: bool = false
var last_window_position: Vector2i = Vector2i.ZERO #follow the window position
var is_window_dragging: bool = false #checking if the window was dragging
var is_sleeping: bool = false #sleeping state variable

#initialize
func _ready() -> void:
	_detect_and_apply_dpi()
	last_window_position = get_window().position
	
	print("[基准尺寸： %s]" % base_window_size)
	

func _process(delta: float) -> void:
	#if program is sleeping, then stop all the methods
	if is_sleeping:
		return
	
	#detect changes in window position
	#when window is dragging, stop check the screen changes
	if not is_window_dragging:
		var current_position := get_window().position
		if current_position != last_window_position:
			last_window_position = current_position
			_check_screen_change()
		
	if enable_smooth_transition and is_transitioning:
		current_scale_factor = lerp(current_scale_factor, target_scale_factor, delta * transition_speed)
	
		if abs(current_scale_factor - target_scale_factor) < 0.01:
			current_scale_factor = target_scale_factor
			is_transitioning = false
		
		_apply_scale(current_scale_factor)

# checking the window's moving
func _check_screen_change() -> void:
	var window := get_window()
	var new_screen_index := DisplayServer.window_get_current_screen(window.get_window_id())
	
	if new_screen_index != current_screen_index:
		current_screen_index = new_screen_index
		_detect_and_apply_dpi()

# apply dpi
func _detect_and_apply_dpi() -> void:
	var window := get_window()
	var screen_index := DisplayServer.window_get_current_screen(window.get_window_id())
	
	# get the dpi of current screen
	var screen_dpi := DisplayServer.screen_get_dpi(screen_index)
	
	# calculate the scale
	var new_scale := _calculate_scale_factor(screen_dpi)
	
	if abs(new_scale - target_scale_factor) > 0.01:
		target_scale_factor = new_scale
		
		if enable_smooth_transition:
			is_transitioning = true
		else:
			current_scale_factor = new_scale
			_apply_scale(new_scale)
		
		print("DPI: %d | scale: %.2f" % [screen_dpi, new_scale])
		

#calculate the scale
func _calculate_scale_factor(screen_dpi: int) -> float:
	# relative to the baseline DPI
	var raw_scale := float(screen_dpi) / base_dpi
	#quantified to common scaling standards
	var quantized_scale : float = round(raw_scale * 4.0) / 4.0
	#limit the scale
	return clamp(quantized_scale, 0.5, 3.0)
	

#apply the scale
func _apply_scale(scale: float) -> void:
	var window := get_window()
	
	#adjust the physical size of the window
	var new_size := Vector2i(
		int(base_window_size.x * scale),
		int(base_window_size.y * scale)
	)
	window.size = new_size
	
	dpi_changed.emit(scale)

func force_refresh() -> void:
	_detect_and_apply_dpi()

func set_dragging_state(dragging: bool) -> void:
	is_window_dragging = dragging
	#after dragging, check the last location and setting scale
	if not dragging:
		await get_tree().process_frame
		last_window_position = get_window().position
		_check_screen_change()
		
func get_current_screen_info() -> Dictionary:
	var screen_index := DisplayServer.window_get_current_screen(get_window().get_window_id())
	return {
		"index": screen_index,
		"dpi": DisplayServer.screen_get_dpi(screen_index),
		"scale": current_scale_factor,
		"size": DisplayServer.screen_get_size(screen_index),
		"position":DisplayServer.screen_get_position(screen_index)
	}

func set_sleep_mode(sleeping: bool) -> void:
	is_sleeping = sleeping
	if sleeping:
		return
	else:
		_detect_and_apply_dpi()
