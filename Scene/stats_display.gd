extends Label
class_name StatsDisplayEnhanced

# === DISPLAY MODES (显示模式) ===
enum DisplayMode {
	SESSION,  # Current session data (当前会话数据)
	TOTAL,    # Total accumulated data (累计总数据)
	HIDDEN    # Hidden mode (隐藏模式)
}

# === CACHED STATISTICS (缓存的统计数据) ===
var current_mode: DisplayMode = DisplayMode.SESSION
var cached_session_time: float = 0.0
var cached_session_inputs: int = 0
var cached_total_time: float = 0.0
var cached_total_inputs: int = 0

# === ANIMATION SETTINGS (动画设置) ===
var hover_scale: float = 1.2
var normal_scale: float = 1.0
var is_hovering: bool = false

# === INITIALIZATION (初始化) ===
func _ready() -> void:
	# Enable mouse interaction (启用鼠标交互)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Set initial text (设置初始文本)
	text = "Delong has been with you for 0 minutes\nYou have inputted 0 times"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Set cursor to indicate clickability (设置光标以表示可点击)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	print("📊 StatsDisplayEnhanced initialized (增强版统计显示已初始化)")

# === UPDATE STATISTICS (更新统计数据) ===
func update_stats(session_time: float, session_inputs: int, total_time: float, total_inputs: int) -> void:
	# Cache data (缓存数据)
	cached_session_time = session_time
	cached_session_inputs = session_inputs
	cached_total_time = total_time
	cached_total_inputs = total_inputs
	
	_update_display()

func _update_display() -> void:
	match current_mode:
		DisplayMode.SESSION:
			_show_session_stats()
		DisplayMode.TOTAL:
			_show_total_stats()
		DisplayMode.HIDDEN:
			_show_hidden()

# === DISPLAY MODES (显示模式) ===
func _show_session_stats() -> void:
	var time_minutes: int = int(cached_session_time)
	var input_count: int = cached_session_inputs
	
	# Handle plural forms (处理复数形式)
	var time_unit: String = "minute" if time_minutes == 1 else "minutes"
	var input_unit: String = "time" if input_count == 1 else "times"
	
	text = "Delong has been with you for %d %s\nYou have inputted %d %s" % [
		time_minutes, time_unit, input_count, input_unit
	]
	visible = true

func _show_total_stats() -> void:
	var time_minutes: int = int(cached_total_time)
	var input_count: int = cached_total_inputs
	
	# Handle plural forms (处理复数形式)
	var time_unit: String = "minute" if time_minutes == 1 else "minutes"
	var input_unit: String = "time" if input_count == 1 else "times"
	
	text = "Delong has been with you in total for %d %s\nYou have inputted %d %s in total" % [
		time_minutes, time_unit, input_count, input_unit
	]
	visible = true

func _show_hidden() -> void:
	visible = false

# === INPUT HANDLING (输入处理) ===
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Cycle through display modes on click (点击时循环切换显示模式)
		_cycle_display_mode()
		accept_event()

func _cycle_display_mode() -> void:
	match current_mode:
		DisplayMode.SESSION:
			current_mode = DisplayMode.TOTAL
			print("📊 Switched to TOTAL stats mode (切换到总统计模式)")
		DisplayMode.TOTAL:
			current_mode = DisplayMode.HIDDEN
			print("👁 Stats hidden (统计已隐藏)")
		DisplayMode.HIDDEN:
			current_mode = DisplayMode.SESSION
			print("📊 Switched to SESSION stats mode (切换到会话统计模式)")
	
	_update_display()

# === MOUSE HOVER EFFECTS (鼠标悬停效果) ===
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			is_hovering = true
			_animate_hover(true)
		NOTIFICATION_MOUSE_EXIT:
			is_hovering = false
			_animate_hover(false)

func _animate_hover(hovering: bool) -> void:
	# Create smooth color transition (创建平滑的颜色过渡)
	var target_modulate = Color(1.2, 1.2, 1.2) if hovering else Color(1.0, 1.0, 1.0)
	
	# Use tween for smooth animation (使用补间实现平滑动画)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", target_modulate, 0.15)

# === PUBLIC METHODS (公共方法) ===
func set_display_mode(mode: DisplayMode) -> void:
	"""Manually set display mode (手动设置显示模式)"""
	current_mode = mode
	_update_display()

func get_current_mode() -> DisplayMode:
	"""Get current display mode (获取当前显示模式)"""
	return current_mode

func toggle_visibility() -> void:
	"""Toggle between current mode and hidden (在当前模式和隐藏之间切换)"""
	if current_mode == DisplayMode.HIDDEN:
		current_mode = DisplayMode.SESSION
	else:
		current_mode = DisplayMode.HIDDEN
	_update_display()
