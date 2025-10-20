extends Control

@onready var chat_text: ChatText = $ChatText
@onready var joke_api: HTTPRequest = $JokeApi
@onready var display_manager: DisplayManager = $DisplayManager
@onready var character: Node2D = $Character
@onready var idle_detector: InputIdleDetector
@onready var config_manager: ConfigManager

var sentences : Array[String]  # array to store chat sentences
var is_dragging : bool = false  # track if window is being dragged
var current_api_index : int = 0  # current API index for rotation
#drag states follower
var drag_start_mouse_pos: Vector2i = Vector2i.ZERO
var drag_start_window_pos: Vector2i = Vector2i.ZERO

# fixed sentences that never change
var fixed_sentences : Array[String] = [
	"对对对",
	"No Niin",
	"杀杀杀杀杀"
]

# dynamic content from APIs (8 slots: 4 jokes + 4 facts)
var dynamic_sentences : Array[String] = ["", "", "", "", "", "", "", ""]
var jokes_collected : int = 0  # count of jokes collected
var facts_collected : int = 0  # count of facts collected

# different joke & facts APIs
var apis : Array[Dictionary] = [
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

#save the basic scale standard
var base_character_scale: Vector2

# initial settings when game starts
func _ready() -> void: 
	get_tree().root.set_transparent_background(true)
	chat_text.custom_minimum_size = Vector2(200, 300)
	
	# create and initialize config manager
	config_manager = ConfigManager.new()
	add_child(config_manager)
	print("conncet to config manager")
	
	#restore the window position
	_restore_window_position()
	
	# create Input Idle Detector
	idle_detector = InputIdleDetector.new()
	idle_detector.sleep_after_seconds = 300.0 # 5 min
	idle_detector.sleep_mode_changed.connect(_on_sleep_mode_changed)
	add_child(idle_detector)
	print("connect to idle Detector")
	
	# enable redirect following for HTTPRequest
	joke_api.set_max_redirects(8)
	
	# initialize sentences array with fixed content
	update_sentences_array()
	
	# start initial collection of jokes and facts
	start_initial_collection()
	
	#reading the default scale of character
	base_character_scale = character.scale
	
	#DisplayManagement
	if display_manager:
		display_manager.dpi_changed.connect(_on_display_manager_dpi_changed)
		print("connect to the DPI Manager")
		
	#ConfigManagement:
	get_tree().root.close_requested.connect(_on_window_close_requested)
	
#restore the window's position
func _restore_window_position() -> void:
	#wait 1s for initialize
	await get_tree().process_frame
	
	var saved_position = config_manager.get_safe_window_position()
	#only use it when position is valid
	if saved_position.x >= 0:
		get_tree().root.position = saved_position
		print("restore the position to %s" % saved_position)
	else:
		print("use the default position")

#save the window setting when closed program
func _on_window_close_requested() -> void:
	var current_position = get_tree().root.position
	config_manager.save_window_position(current_position)
	print("saving")
	get_tree().quit()
	
# combine fixed and dynamic sentences into one array
func update_sentences_array() -> void:
	sentences = dynamic_sentences + fixed_sentences

# collect initial batch of jokes and facts
func start_initial_collection() -> void:
	jokes_collected = 0
	facts_collected = 0
	request_next_item()

# request next joke or fact until we have 4 jokes and 3 facts
func request_next_item() -> void:
	if jokes_collected < 4:
		# request a joke
		request_joke_or_fact(0)  # 0 = jokes API
	elif facts_collected < 4:
		# request a fact
		request_joke_or_fact(1)  # 1 = facts API
	else:
		# collection complete
		update_sentences_array()

# request joke or fact from specified API
func request_joke_or_fact(api_index: int) -> void:
	var api = apis[api_index]
	current_api_index = api_index
	joke_api.request(api["url"], api["headers"])

# handle API response
func _on_joke_api_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# check if request was successful
	if response_code != 200:
		print("⚠️ Request failed with code: ", response_code)
		# retry the same request after a short delay
		await get_tree().create_timer(0.5).timeout
		request_next_item()
		return
	
	# parse JSON response
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		await get_tree().create_timer(0.5).timeout
		request_next_item()
		return
	
	var content_text = ""
	var api_type = apis[current_api_index]["type"]
	
	# extract content based on API type
	if api_type == "jokes" and json.has("joke"):
		content_text = json["joke"]
	elif api_type == "facts" and json.has("text"):
		content_text = json["text"]
	
	if content_text == "":
		await get_tree().create_timer(0.5).timeout
		request_next_item()
		return
	
	# save to dynamic sentences array
	if api_type == "jokes":
		dynamic_sentences[jokes_collected] = content_text
		jokes_collected += 1
	elif api_type == "facts":
		dynamic_sentences[4 + facts_collected] = content_text
		facts_collected += 1
	
	# small delay before next request to avoid rate limiting
	await get_tree().create_timer(0.3).timeout
	request_next_item()

# recording the initial location, checking if right click, then select the whole window, then dragging
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging = true
				drag_start_mouse_pos = DisplayServer.mouse_get_position()
				drag_start_window_pos = get_tree().root.position
			else:
				is_dragging = false
			# setting the dragging states, calling the display_manager
			if display_manager:
				display_manager.set_dragging_state(is_dragging)
			get_viewport().set_input_as_handled() 

#apply drag
func _process(delta: float) -> void:
	if is_dragging:
		var current_mouse_pos := DisplayServer.mouse_get_position()
		var mouse_offset := current_mouse_pos - drag_start_mouse_pos
		get_tree().root.position = drag_start_window_pos + mouse_offset

# quit the game with Ctrl+Q
func _unhandled_input(event:InputEvent) -> void:
	#use close_request to trigger saving the setting
	if event.is_action_pressed("QuitGame"):
		get_tree().root.close_requested.emit()

# chat method - show random sentence when character is clicked
func _on_character_chat() -> void:
	var text = sentences.pick_random()
	# avoid showing empty strings
	while text == "" and sentences.size() > 0:
		text = sentences.pick_random()
	chat_text.text = text
	chat_text.play_chat()

# timer timeout - refresh all dynamic content every 3 minutes
func _on_joke_request_timer_timeout() -> void:
	start_initial_collection()
	
#DPI changing
func _on_display_manager_dpi_changed(new_scale: float) -> void:
	#setting the text scale
	var base_font_size := 20
	var new_font_size := int(base_font_size * new_scale)
	chat_text.add_theme_font_size_override("font_size", new_font_size)
	#setting the character scale
	$Character.scale = Vector2(base_character_scale) * new_scale
	
#idle detector
func _on_sleep_mode_changed(is_sleeping: bool) -> void:
	if is_sleeping:
		#stop all the event and go to sleep
		$JokeApi/jokeRequestTimer.stop()
		if display_manager:
			display_manager.set_sleep_mode(true)
		
		print('in sleeping')
	else:
		#wake up
		$JokeApi/jokeRequestTimer.start()
		if display_manager:
			display_manager.set_sleep_mode(false)
