extends Control

@onready var chat_text: ChatText = $ChatText
@onready var joke_api: HTTPRequest = $JokeApi
@onready var display_manager: DisplayManager = $DisplayManager
@onready var character: Node2D = $Character
@onready var config_manager: ConfigManager
@onready var global_tracker: GlobalInputTrackerEnhanced = $GlobalInputTracker
@onready var stats_display: StatsDisplayEnhanced = $StatsDisplay

# === SENTENCE STORAGE (句子存储) ===
var sentences: Array[String]  # Array to store all chat sentences (存储所有聊天句子的数组)
var is_dragging: bool = false  # Track if window is being dragged (跟踪窗口是否正在拖动)
var current_api_index: int = 0  # Current API index for rotation (当前API索引用于轮换)

# Drag state trackers (拖动状态跟踪器)
var drag_start_mouse_pos: Vector2i = Vector2i.ZERO
var drag_start_window_pos: Vector2i = Vector2i.ZERO

# === SENTENCE COLLECTIONS (句子集合) ===
# Fixed sentences that never change (永不改变的固定句子)
var fixed_sentences: Array[String] = [
	"对对对",
	"No Niin",
	"您辛苦了"
]

# Dynamic content from APIs (来自API的动态内容)
var dynamic_sentences: Array[String] = ["", "", "", "", "", "", "", ""]
var jokes_collected: int = 0  # Count of jokes collected (收集的笑话数量)
var facts_collected: int = 0  # Count of facts collected (收集的事实数量)

# === API CONFIGURATION (API配置) ===
var apis: Array[Dictionary] = [
	{
		"name": "English Jokes",
		"url": "https://icanhazdadjoke.com/",
		"headers": ["Accept: application/json"],
		"type": "jokes"
	},
	{
		"name": "Random facts",
		"url": "https://uselessfacts.jsph.pl/api/v2/facts/random",
		"headers": ["Accept: application/json"],
		"type": "facts"
	}
]

# Save the base character scale (保存基础角色缩放)
var base_character_scale: Vector2

# === INITIALIZATION (初始化) ===
func _ready() -> void:
	# Set transparent background (设置透明背景)
	get_tree().root.set_transparent_background(true)
	chat_text.custom_minimum_size = Vector2(200, 300)
	
	# Create and initialize config manager (创建并初始化配置管理器)
	config_manager = ConfigManager.new()
	add_child(config_manager)
	print("✅ Connected to ConfigManager (已连接到配置管理器)")
	
	# Initialize GlobalInputTracker (初始化全局输入跟踪器)
	if global_tracker:
		global_tracker.set_config_manager(config_manager)
		global_tracker.stats_updated.connect(_on_stats_updated)
		global_tracker.sleep_mode_changed.connect(_on_sleep_mode_changed)
		global_tracker.activity_state_changed.connect(_on_activity_state_changed)
		print("✅ GlobalInputTracker initialized (全局输入跟踪器已初始化)")
	else:
		push_error("❌ GlobalInputTracker not found (未找到全局输入跟踪器)")
	
	# Initialize StatsDisplay (初始化统计显示)
	if stats_display:
		print("✅ StatsDisplayEnhanced initialized (增强版统计显示已初始化)")
	else:
		push_error("❌ StatsDisplayEnhanced not found (未找到增强版统计显示)")
	
	# Restore window position (恢复窗口位置)
	_restore_window_position()
	
	# Enable redirect following for HTTPRequest (为HTTPRequest启用重定向跟随)
	joke_api.set_max_redirects(8)
	
	# Initialize sentences array with fixed content (用固定内容初始化句子数组)
	update_sentences_array()
	
	# Start initial collection of jokes and facts (开始初始收集笑话和事实)
	start_initial_collection()
	
	# Read the default scale of character (读取角色的默认缩放)
	base_character_scale = character.scale
	
	# Connect DisplayManager signals (连接显示管理器信号)
	if display_manager:
		display_manager.dpi_changed.connect(_on_display_manager_dpi_changed)
		print("✅ Connected to DPI Manager (已连接到DPI管理器)")
	
	# Connect window close request (连接窗口关闭请求)
	get_tree().root.close_requested.connect(_on_window_close_requested)

# === WINDOW POSITION MANAGEMENT (窗口位置管理) ===
func _restore_window_position() -> void:
	# Wait for initialization (等待初始化)
	await get_tree().process_frame
	
	var saved_position = config_manager.get_safe_window_position()
	# Only use saved position if valid (仅在有效时使用保存的位置)
	if saved_position.x >= 0:
		get_tree().root.position = saved_position
		print("✅ Restored position to %s (恢复位置到 %s)" % saved_position)
	else:
		print("ℹ Using default position (使用默认位置)")

func _on_window_close_requested() -> void:
	# Save window position (保存窗口位置)
	var current_position = get_tree().root.position
	config_manager.save_window_position(current_position)
	
	# Save statistics before exit (退出前保存统计数据)
	if global_tracker:
		global_tracker.save_on_exit()
	
	print("💾 Saving and exiting (保存并退出)...")
	get_tree().quit()

# === STATISTICS UPDATE CALLBACK (统计更新回调) ===
func _on_stats_updated(session_time: float, session_inputs: int, total_time: float, total_inputs: int) -> void:
	if stats_display:
		stats_display.update_stats(session_time, session_inputs, total_time, total_inputs)

# === ACTIVITY STATE CALLBACK (活动状态回调) ===
func _on_activity_state_changed(is_active: bool) -> void:
	if is_active:
		print("👤 User is now active (用户现在活跃)")
	else:
		print("💤 User is now idle (用户现在空闲)")

# === SENTENCE MANAGEMENT (句子管理) ===
func update_sentences_array() -> void:
	# Combine fixed and dynamic sentences (合并固定和动态句子)
	sentences = dynamic_sentences + fixed_sentences

# === JOKE/FACT COLLECTION (笑话/事实收集) ===
func start_initial_collection() -> void:
	# Reset counters (重置计数器)
	jokes_collected = 0
	facts_collected = 0
	request_next_item()

func request_next_item() -> void:
	# Request next joke or fact until we have 4 jokes and 4 facts (请求下一个笑话或事实，直到我们有4个笑话和4个事实)
	if jokes_collected < 4:
		request_joke_or_fact(0)  # Request a joke (请求笑话)
	elif facts_collected < 4:
		request_joke_or_fact(1)  # Request a fact (请求事实)
	else:
		# Collection complete (收集完成)
		update_sentences_array()

func request_joke_or_fact(api_index: int) -> void:
	# Request joke or fact from specified API (从指定API请求笑话或事实)
	var api = apis[api_index]
	current_api_index = api_index
	joke_api.request(api["url"], api["headers"])

func _on_joke_api_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# Check if request was successful (检查请求是否成功)
	if response_code != 200:
		print("⚠️ Request failed with code (请求失败，代码): %d" % response_code)
		await get_tree().create_timer(0.5).timeout
		request_next_item()
		return
	
	# Parse JSON response (解析JSON响应)
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		await get_tree().create_timer(0.5).timeout
		request_next_item()
		return
	
	var content_text = ""
	var api_type = apis[current_api_index]["type"]
	
	# Extract content based on API type (根据API类型提取内容)
	if api_type == "jokes" and json.has("joke"):
		content_text = json["joke"]
	elif api_type == "facts" and json.has("text"):
		content_text = json["text"]
	
	if content_text == "":
		await get_tree().create_timer(0.5).timeout
		request_next_item()
		return
	
	# Save to dynamic sentences array (保存到动态句子数组)
	if api_type == "jokes":
		dynamic_sentences[jokes_collected] = content_text
		jokes_collected += 1
	elif api_type == "facts":
		dynamic_sentences[4 + facts_collected] = content_text
		facts_collected += 1
	
	# Small delay before next request to avoid rate limiting (下次请求前的小延迟以避免速率限制)
	await get_tree().create_timer(0.3).timeout
	request_next_item()

# === WINDOW DRAGGING (窗口拖动) ===
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# Start dragging (开始拖动)
				is_dragging = true
				drag_start_mouse_pos = DisplayServer.mouse_get_position()
				drag_start_window_pos = get_tree().root.position
			else:
				# Stop dragging (停止拖动)
				is_dragging = false
			
			# Update display manager dragging state (更新显示管理器拖动状态)
			if display_manager:
				display_manager.set_dragging_state(is_dragging)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Apply drag offset if dragging (如果正在拖动则应用拖动偏移)
	if is_dragging:
		var current_mouse_pos := DisplayServer.mouse_get_position()
		var mouse_offset := current_mouse_pos - drag_start_mouse_pos
		get_tree().root.position = drag_start_window_pos + mouse_offset

# === QUIT GAME HANDLING (退出游戏处理) ===
func _unhandled_input(event: InputEvent) -> void:
	# Quit with Ctrl+Q (使用Ctrl+Q退出)
	if event.is_action_pressed("QuitGame"):
		get_tree().root.close_requested.emit()

# === CHARACTER CHAT (角色聊天) ===
func _on_character_chat() -> void:
	# Show random sentence when character is clicked (角色被点击时显示随机句子)
	var text = sentences.pick_random()
	# Avoid showing empty strings (避免显示空字符串)
	while text == "" and sentences.size() > 0:
		text = sentences.pick_random()
	chat_text.text = text
	chat_text.play_chat()

# === TIMER TIMEOUT (定时器超时) ===
func _on_joke_request_timer_timeout() -> void:
	# Refresh all dynamic content every 2 minutes (每2分钟刷新所有动态内容)
	start_initial_collection()

# === DPI CHANGE HANDLING (DPI变化处理) ===
func _on_display_manager_dpi_changed(new_scale: float) -> void:
	# Update text scale (更新文本缩放)
	var base_font_size := 20
	var new_font_size := int(base_font_size * new_scale)
	chat_text.add_theme_font_size_override("font_size", new_font_size)
	
	# Update character scale (更新角色缩放)
	$Character.scale = Vector2(base_character_scale) * new_scale
	
	# Update stats display scale (更新统计显示缩放)
	if stats_display:
		var stats_base_font_size := 18
		var stats_new_font_size := int(stats_base_font_size * new_scale)
		stats_display.add_theme_font_size_override("font_size", stats_new_font_size)

# === SLEEP MODE HANDLING (睡眠模式处理) ===
func _on_sleep_mode_changed(is_sleeping: bool) -> void:
	if is_sleeping:
		# Stop all events when entering sleep mode (进入睡眠模式时停止所有事件)
		$JokeApi/jokeRequestTimer.stop()
		if display_manager:
			display_manager.set_sleep_mode(true)
		print("💤 Application in sleep mode (应用程序处于睡眠模式)")
	else:
		# Resume events when waking up (唤醒时恢复事件)
		$JokeApi/jokeRequestTimer.start()
		if display_manager:
			display_manager.set_sleep_mode(false)
		print("👁 Application awake (应用程序已唤醒)")
