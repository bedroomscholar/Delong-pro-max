extends Node
class_name GlobalInputTrackerEnhanced

# === SIGNALS ===
# Signal sent when statistics are updated (统计数据更新信号)
signal stats_updated(session_time: float, session_inputs: int, total_time: float, total_inputs: int)
# Signal sent when any input is detected (任何输入被检测到时的信号)
signal input_detected()
# Signal sent when user switches between active and idle (用户在活跃和空闲状态切换时的信号)
signal activity_state_changed(is_active: bool)
# Signal sent when sleep mode changes (睡眠模式变化信号)
signal sleep_mode_changed(is_sleeping: bool)

# === SESSION DATA (Current run only - 当前会话数据) ===
var session_start_time: float = 0.0
var session_input_count: int = 0

# === TOTAL DATA (Persisted across sessions - 跨会话持久化数据) ===
var total_time_minutes: float = 0.0
var total_input_count: int = 0

# === IDLE DETECTION SETTINGS (空闲检测设置) ===
var last_system_idle_ms: int = 0
var polling_interval: float = 0.5  # Check system idle time every 500ms (每500ms检查一次系统空闲时间)
var idle_threshold_seconds: float = 60.0  # Consider user "away" after 60 seconds (60秒后认为用户离开)
var sleep_threshold_seconds: float = 300.0  # Enter sleep mode after 5 minutes (5分钟后进入睡眠模式)
var is_user_active: bool = true  # Tracks if user is currently active (跟踪用户当前是否活跃)
var is_sleeping: bool = false  # Tracks sleep mode state (跟踪睡眠模式状态)

# === PLATFORM DETECTION (平台检测) ===
var current_platform: String = ""
var idle_command: Array = []
var is_idle_tracking_available: bool = false

# === TIMERS (定时器) ===
@export var update_interval: float = 1.0  # UI update frequency (UI更新频率)
@export var save_interval: float = 60.0  # Auto-save frequency (自动保存频率)

var update_timer: Timer
var save_timer: Timer
var idle_poll_timer: Timer

# === CONFIG MANAGER (配置管理器) ===
var config_manager: ConfigManager

# === TRACKING STATE (追踪状态) ===
var is_tracking_enabled: bool = true
var last_input_time: float = 0.0

# === INITIALIZATION (初始化) ===
func _ready() -> void:
	# Record session start time (记录会话开始时间)
	session_start_time = Time.get_ticks_msec() / 1000.0
	last_input_time = session_start_time
	
	# Detect platform and setup idle detection commands (检测平台并设置空闲检测命令)
	_setup_platform_commands()
	
	# Create idle polling timer for system-level activity detection (创建空闲轮询定时器用于系统级活动检测)
	idle_poll_timer = Timer.new()
	idle_poll_timer.wait_time = polling_interval
	idle_poll_timer.timeout.connect(_poll_system_idle)
	add_child(idle_poll_timer)
	if is_idle_tracking_available:
		idle_poll_timer.start()
		print("✓ Global idle tracking enabled (全局空闲追踪已启用)")
	else:
		print("⚠ Global idle tracking unavailable - using fallback mode (全局空闲追踪不可用 - 使用备用模式)")
	
	# Create stats update timer for UI refresh (创建统计更新定时器用于UI刷新)
	update_timer = Timer.new()
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(_emit_stats_update)
	add_child(update_timer)
	update_timer.start()
	
	# Create auto-save timer (创建自动保存定时器)
	save_timer = Timer.new()
	save_timer.wait_time = save_interval
	save_timer.timeout.connect(_save_stats)
	add_child(save_timer)
	save_timer.start()
	
	print("GlobalInputTrackerEnhanced ready [Platform: %s]" % current_platform)

# === PLATFORM-SPECIFIC IDLE DETECTION SETUP (平台特定的空闲检测设置) ===
func _setup_platform_commands() -> void:
	var os_name = OS.get_name()
	current_platform = os_name
	
	match os_name:
		"Windows":
			# PowerShell command to get milliseconds since last input (获取最后输入以来的毫秒数)
			idle_command = [
				"powershell",
				"-NoProfile",
				"-Command",
				"Add-Type -AssemblyName System.Windows.Forms; [System.Environment]::TickCount - [System.Windows.Forms.SystemInformation]::LastInputTime"
			]
			is_idle_tracking_available = true
			
		"macOS":
			# ioreg command to get milliseconds of idle time (获取空闲时间的毫秒数)
			idle_command = [
				"sh",
				"-c",
				"ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000); exit}'"
			]
			is_idle_tracking_available = true
			
		"Linux", "X11":
			# xprintidle returns milliseconds (必须安装: sudo apt install xprintidle)
			idle_command = ["xprintidle"]
			is_idle_tracking_available = true
			print("⚠ Linux: Ensure 'xprintidle' is installed (确保已安装 'xprintidle')")
			
		_:
			push_warning("Platform %s: Idle tracking unavailable (平台不支持空闲追踪)" % os_name)
			is_idle_tracking_available = false

# === ACCURATE INPUT COUNTING (精确的输入计数) ===
func _input(event: InputEvent) -> void:
	# Stop tracking if disabled or in sleep mode (如果禁用或处于睡眠模式则停止追踪)
	if not is_tracking_enabled or is_sleeping:
		return
	
	# Count mouse clicks (only on button press, not release) (仅计数按下事件，不计数释放事件)
	if event is InputEventMouseButton and event.pressed:
		_record_input()
	
	# Count keyboard presses (ignore key repeats) (忽略按键重复)
	elif event is InputEventKey and event.pressed and not event.echo:
		_record_input()

# === SYSTEM IDLE TIME POLLING (系统空闲时间轮询) ===
func _poll_system_idle() -> void:
	# Skip if tracking disabled or not available (如果追踪被禁用或不可用则跳过)
	if not is_tracking_enabled or not is_idle_tracking_available:
		return
	
	var idle_time_ms = _get_system_idle_time()
	
	if idle_time_ms < 0:
		# Command failed - skip this cycle (命令失败 - 跳过此周期)
		return
	
	# Convert to seconds for comparison (转换为秒进行比较)
	var idle_time_seconds = idle_time_ms / 1000.0
	
	# Check if user transitioned between active/idle states (检查用户是否在活跃/空闲状态之间切换)
	var was_active = is_user_active
	is_user_active = (idle_time_seconds < idle_threshold_seconds)
	
	# Emit signal if state changed (如果状态改变则发送信号)
	if was_active != is_user_active:
		activity_state_changed.emit(is_user_active)
		if is_user_active:
			print("User became active (用户变为活跃状态) (idle: %dms)" % idle_time_ms)
		else:
			print("User went idle (用户进入空闲状态) (idle: %dms)" % idle_time_ms)
	
	# Check for sleep mode transition (检查睡眠模式转换)
	if not is_sleeping and idle_time_seconds >= sleep_threshold_seconds:
		_enter_sleep_mode()
	elif is_sleeping and is_user_active:
		_exit_sleep_mode()
	
	# Update last input time if user is active (如果用户活跃则更新最后输入时间)
	if is_user_active:
		last_input_time = Time.get_ticks_msec() / 1000.0

# === EXECUTE SYSTEM COMMAND TO GET IDLE TIME (执行系统命令获取空闲时间) ===
func _get_system_idle_time() -> int:
	if idle_command.is_empty():
		return -1
	
	var output = []
	var exit_code = OS.execute(idle_command[0], idle_command.slice(1), output, true)
	
	if exit_code != 0:
		return -1  # Command failed (命令失败)
	
	if output.is_empty():
		return -1
	
	# Parse the output string to integer (将输出字符串解析为整数)
	var result_str = output[0].strip_edges()
	if result_str.is_valid_int():
		return int(result_str)
	
	return -1

# === SLEEP MODE MANAGEMENT (睡眠模式管理) ===
func _enter_sleep_mode() -> void:
	if is_sleeping:
		return
	
	is_sleeping = true
	is_tracking_enabled = false
	
	# Stop all timers to save resources (停止所有定时器以节省资源)
	if update_timer:
		update_timer.stop()
	if idle_poll_timer:
		idle_poll_timer.stop()
	
	# Save stats before sleeping (睡眠前保存统计数据)
	_save_stats()
	
	sleep_mode_changed.emit(true)
	print("💤 Entering sleep mode (进入睡眠模式) after %.1f seconds" % sleep_threshold_seconds)

func _exit_sleep_mode() -> void:
	if not is_sleeping:
		return
	
	is_sleeping = false
	is_tracking_enabled = true
	
	# Resume timers (恢复定时器)
	if update_timer:
		update_timer.start()
	if idle_poll_timer and is_idle_tracking_available:
		idle_poll_timer.start()
	
	last_input_time = Time.get_ticks_msec() / 1000.0
	
	sleep_mode_changed.emit(false)
	print("👁 Exiting sleep mode (退出睡眠模式)")

# === RECORD A SINGLE INPUT (记录单次输入) ===
func _record_input() -> void:
	session_input_count += 1
	last_input_time = Time.get_ticks_msec() / 1000.0
	input_detected.emit()
	
	# If in sleep mode, wake up (如果处于睡眠模式，唤醒)
	if is_sleeping:
		_exit_sleep_mode()

# === STATISTICS GETTERS (统计数据获取器) ===
func get_session_time_minutes() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - session_start_time) / 60.0

func get_total_time_minutes() -> float:
	return total_time_minutes + get_session_time_minutes()

func get_session_inputs() -> int:
	return session_input_count

func get_total_inputs() -> int:
	return total_input_count + session_input_count

# === EMIT STATS UPDATE SIGNAL (发送统计更新信号) ===
func _emit_stats_update() -> void:
	# Only emit if not sleeping (仅在非睡眠状态下发送)
	if not is_sleeping:
		stats_updated.emit(
			get_session_time_minutes(),
			get_session_inputs(),
			get_total_time_minutes(),
			get_total_inputs()
		)

# === DATA PERSISTENCE (数据持久化) ===
func set_config_manager(manager: ConfigManager) -> void:
	config_manager = manager
	_load_stats()

func _load_stats() -> void:
	if not config_manager:
		return
	
	total_time_minutes = config_manager.config.get_value("stats", "total_time_minutes", 0.0)
	total_input_count = config_manager.config.get_value("stats", "total_input_count", 0)
	print("📊 Loaded history (加载历史数据): %.1f mins, %d inputs" % [total_time_minutes, total_input_count])

func _save_stats() -> void:
	if not config_manager:
		return
	
	# Calculate current totals (计算当前总数)
	var current_total_time = get_total_time_minutes()
	var current_total_inputs = get_total_inputs()
	
	# Save to config file (保存到配置文件)
	config_manager.config.set_value("stats", "total_time_minutes", current_total_time)
	config_manager.config.set_value("stats", "total_input_count", current_total_inputs)
	config_manager.config.set_value("stats", "last_saved", Time.get_datetime_string_from_system())
	
	var err = config_manager.config.save(config_manager.CONFIG_PATH)
	if err == OK:
		print("💾 Stats saved (统计数据已保存): %.1f mins, %d inputs" % [current_total_time, current_total_inputs])
	else:
		push_error("Failed to save stats (保存统计数据失败) (error code: %d)" % err)

func save_on_exit() -> void:
	# Merge session data into totals before saving (保存前将会话数据合并到总数中)
	total_time_minutes = get_total_time_minutes()
	total_input_count = get_total_inputs()
	_save_stats()
	print("✅ Final stats saved before exit (退出前最终统计数据已保存)")

# === TRACKING CONTROL (追踪控制) ===
func set_tracking_enabled(enabled: bool) -> void:
	if not enabled and is_tracking_enabled:
		# Save before pausing (暂停前保存)
		_save_stats()
	
	is_tracking_enabled = enabled
	var status_en = "ENABLED" if enabled else "DISABLED"
	var status_cn = "启用" if enabled else "禁用"
	print("Tracking %s (追踪%s)" % [status_en, status_cn])

func force_wake_up() -> void:
	"""Force exit from sleep mode (强制退出睡眠模式)"""
	if is_sleeping:
		_exit_sleep_mode()

# === DEBUG METHODS (调试方法) ===
func get_debug_info() -> String:
	return "Platform: %s | Tracking: %s | Idle tracking: %s | User active: %s | Sleeping: %s | Session inputs: %d" % [
		current_platform,
		"ON" if is_tracking_enabled else "OFF",
		"Available" if is_idle_tracking_available else "Unavailable",
		"YES" if is_user_active else "NO",
		"YES" if is_sleeping else "NO",
		session_input_count
	]

func test_idle_detection() -> void:
	"""Test if idle detection is working (测试空闲检测是否工作)"""
	var idle_ms = _get_system_idle_time()
	if idle_ms >= 0:
		print("✓ System idle time (系统空闲时间): %d ms (%.1f sec)" % [idle_ms, idle_ms / 1000.0])
	else:
		print("✗ Idle time detection failed (空闲时间检测失败)")
