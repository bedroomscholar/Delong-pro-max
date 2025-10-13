extends Control

@onready var chat_text: ChatText = $ChatText
@onready var joke_api: HTTPRequest = $JokeApi

var sentences : Array[String]  # array to store chat sentences
var is_dragging : bool = false  # track if window is being dragged
var current_api_index : int = 0  # current API index for rotation

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

# initial settings when game starts
func _ready() -> void: 
	get_tree().root.set_transparent_background(true)
	chat_text.custom_minimum_size = Vector2(200, 200)
	
	# enable redirect following for HTTPRequest
	joke_api.set_max_redirects(8)
	
	# initialize sentences array with fixed content
	update_sentences_array()
	
	# start initial collection of jokes and facts
	start_initial_collection()

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
	
	# limit text length
	if content_text.length() > 120:
		content_text = content_text.substr(0, 117) + "..."
	
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

# checking if right click, then select the whole window, then dragging
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed
			get_viewport().set_input_as_handled() 
	
	if event is InputEventMouseMotion and is_dragging:
		get_tree().root.position += Vector2i(event.relative)
		get_viewport().set_input_as_handled()

# quit the game with Ctrl+Q
func _unhandled_input(event:InputEvent) -> void:
	if event.is_action_pressed("QuitGame"):
		get_tree().quit()

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
