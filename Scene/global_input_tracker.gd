extends Node
class_name GlobalInputTracker

# Signals - notify UI when stats change
signal stats_updated(session_time: float, session_inputs: int, total_time: float, total_inputs: int)
signal input_detected()  # fires on each input
signal activity_state_changed(is_active: bool)  # fires when user becomes active/idle

# === SESSION DATA (current run only) ===
var session_start_time: float = 0.0
var session_input_count: int = 0

# === TOTAL DATA (persisted across sessions) ===
var total_time_minutes: float = 0.0
var total_input_count: int = 0

# === IDLE DETECTION SETTINGS ===
var last_system_idle_ms: int = 0
var polling_interval: float = 0.5  # check system idle time every 500ms
var idle_threshold_seconds: float = 60.0  # consider user "away" after 60 seconds
var is_user_active: bool = true  # tracks if user is currently active

# === PLATFORM DETECTION ===
var current_platform: String = ""
var idle_command: Array = []
var is_idle_tracking_available: bool = false

# === TIMERS ===
@export var update_interval: float = 1.0  # UI update frequency
@export var save_interval: float = 60.0  # auto-save frequency

var update_timer: Timer
var save_timer: Timer
var idle_poll_timer: Timer

# === CONFIG MANAGER ===
var config_manager: ConfigManager

# === TRACKING STATE ===
var is_tracking_enabled: bool = true
var last_input_time: float = 0.0

func _ready() -> void:
	# Record session start time
	session_start_time = Time.get_ticks_msec() / 1000.0
	last_input_time = session_start_time
	
	# Detect platform and setup idle detection commands
	_setup_platform_commands()
	
	# Create idle polling timer (system-level activity detection)
	idle_poll_timer = Timer.new()
	idle_poll_timer.wait_time = polling_interval
	idle_poll_timer.timeout.connect(_poll_system_idle)
	add_child(idle_poll_timer)
	if is_idle_tracking_available:
		idle_poll_timer.start()
		print("✓ Global idle tracking enabled")
	else:
		print("⚠ Global idle tracking unavailable (will use _input() only)")
	
	# Create stats update timer (UI refresh)
	update_timer = Timer.new()
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(_emit_stats_update)
	add_child(update_timer)
	update_timer.start()
	
	# Create auto-save timer
	save_timer = Timer.new()
	save_timer.wait_time = save_interval
	save_timer.timeout.connect(_save_stats)
	add_child(save_timer)
	save_timer.start()
	
	print("GlobalInputTracker ready [Platform: %s]" % current_platform)

# === PLATFORM-SPECIFIC IDLE DETECTION SETUP ===
func _setup_platform_commands() -> void:
	var os_name = OS.get_name()
	current_platform = os_name
	
	match os_name:
		"Windows":
			# PowerShell command to get milliseconds since last input
			idle_command = [
				"powershell",
				"-NoProfile",
				"-Command",
				"Add-Type -AssemblyName System.Windows.Forms; [System.Environment]::TickCount - [System.Windows.Forms.SystemInformation]::LastInputTime"
			]
			is_idle_tracking_available = true
			
		"macOS":
			# ioreg command to get milliseconds of idle time
			idle_command = [
				"sh",
				"-c",
				"ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000); exit}'"
			]
			is_idle_tracking_available = true
			
		"Linux", "X11":
			# xprintidle returns milliseconds (must be installed: sudo apt install xprintidle)
			idle_command = ["xprintidle"]
			is_idle_tracking_available = true
			print("⚠ Linux: Ensure 'xprintidle' is installed")
			
		_:
			push_warning("Platform %s: Idle tracking unavailable" % os_name)
			is_idle_tracking_available = false

# === ACCURATE INPUT COUNTING (Godot's _input method) ===
func _input(event: InputEvent) -> void:
	if not is_tracking_enabled:
		return
	
	# Count mouse clicks (only on button press, not release)
	if event is InputEventMouseButton and event.pressed:
		_record_input()
	
	# Count keyboard presses (ignore key repeats)
	elif event is InputEventKey and event.pressed and not event.echo:
		_record_input()

# === SYSTEM IDLE TIME POLLING (global activity detection) ===
func _poll_system_idle() -> void:
	if not is_tracking_enabled or not is_idle_tracking_available:
		return
	
	var idle_time_ms = _get_system_idle_time()
	
	if idle_time_ms < 0:
		# Command failed - skip this cycle
		return
	
	# Check if user transitioned between active/idle states
	var was_active = is_user_active
	is_user_active = (idle_time_ms < idle_threshold_seconds * 1000)
	
	# Emit signal if state changed
	if was_active != is_user_active:
		activity_state_changed.emit(is_user_active)
		if is_user_active:
			print("User became active (idle: %dms)" % idle_time_ms)
		else:
			print("User went idle (idle: %dms)" % idle_time_ms)
	
	# If user just became active after being idle, record it as a "wake up" event
	# (Don't try to estimate input count - that's what _input() is for)
	if is_user_active and not was_active:
		last_input_time = Time.get_ticks_msec() / 1000.0

# === EXECUTE SYSTEM COMMAND TO GET IDLE TIME ===
func _get_system_idle_time() -> int:
	if idle_command.is_empty():
		return -1
	
	var output = []
	var exit_code = OS.execute(idle_command[0], idle_command.slice(1), output, true)
	
	if exit_code != 0:
		return -1  # command failed
	
	if output.is_empty():
		return -1
	
	# Parse the output string to integer
	var result_str = output[0].strip_edges()
	if result_str.is_valid_int():
		return int(result_str)
	
	return -1

# === RECORD A SINGLE INPUT ===
func _record_input() -> void:
	session_input_count += 1
	last_input_time = Time.get_ticks_msec() / 1000.0
	input_detected.emit()

# === STATISTICS GETTERS ===
func get_session_time_minutes() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - session_start_time) / 60.0

func get_total_time_minutes() -> float:
	return total_time_minutes + get_session_time_minutes()

func get_session_inputs() -> int:
	return session_input_count

func get_total_inputs() -> int:
	return total_input_count + session_input_count

# === EMIT STATS UPDATE SIGNAL ===
func _emit_stats_update() -> void:
	stats_updated.emit(
		get_session_time_minutes(),
		get_session_inputs(),
		get_total_time_minutes(),
		get_total_inputs()
	)

# === DATA PERSISTENCE ===
func set_config_manager(manager: ConfigManager) -> void:
	config_manager = manager
	_load_stats()

func _load_stats() -> void:
	if not config_manager:
		return
	
	total_time_minutes = config_manager.config.get_value("stats", "total_time_minutes", 0.0)
	total_input_count = config_manager.config.get_value("stats", "total_input_count", 0)
	print("Loaded history: %.1f mins, %d inputs" % [total_time_minutes, total_input_count])

func _save_stats() -> void:
	if not config_manager:
		return
	
	# Calculate current totals
	var current_total_time = get_total_time_minutes()
	var current_total_inputs = get_total_inputs()
	
	# Save to config file
	config_manager.config.set_value("stats", "total_time_minutes", current_total_time)
	config_manager.config.set_value("stats", "total_input_count", current_total_inputs)
	config_manager.config.set_value("stats", "last_saved", Time.get_datetime_string_from_system())
	
	var err = config_manager.config.save(config_manager.CONFIG_PATH)
	if err == OK:
		print("Stats saved: %.1f mins, %d inputs" % [current_total_time, current_total_inputs])
	else:
		push_error("Failed to save stats (error code: %d)" % err)

func save_on_exit() -> void:
	# Merge session data into totals before saving
	total_time_minutes = get_total_time_minutes()
	total_input_count = get_total_inputs()
	_save_stats()
	print("Final stats saved before exit")

# === TRACKING CONTROL ===
func set_tracking_enabled(enabled: bool) -> void:
	if not enabled and is_tracking_enabled:
		# Save before pausing
		_save_stats()
	
	is_tracking_enabled = enabled
	print("Tracking %s" % ("ENABLED" if enabled else "DISABLED"))

# === DEBUG METHODS ===
func get_debug_info() -> String:
	return "Platform: %s | Tracking: %s | Idle tracking: %s | User active: %s | Session inputs: %d" % [
		current_platform,
		"ON" if is_tracking_enabled else "OFF",
		"Available" if is_idle_tracking_available else "Unavailable",
		"YES" if is_user_active else "NO",
		session_input_count
	]

func test_idle_detection() -> void:
	var idle_ms = _get_system_idle_time()
	if idle_ms >= 0:
		print("✓ System idle time: %d ms (%.1f sec)" % [idle_ms, idle_ms / 1000.0])
	else:
		print("✗ Idle time detection failed")
