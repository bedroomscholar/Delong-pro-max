extends Control

@onready var chat_text: ChatText = $ChatText
@onready var joke_api: HTTPRequest = $JokeApi


var sentences : Array[String] #sentences
var is_dragging : bool = false

#different joke & apis
var current_api_index : int = 0

var apis : Array[Dictionary] = [
	{
		"name": "English Jokes",
		"url": "https://icanhazdadjoke.com/",
		"headers": ["Accept: application/json"],
		"type": "jokes"
	},
	{
		"name": "Random facts",
		"url": "https://uselessfacts.jsph.pl/random.json",
		"headers": ["Accept: application/json"],
		"type": "facts"
	}
]

#the initial settings
func _ready() -> void: 
	get_tree().root.set_transparent_background(true)
	chat_text.custom_minimum_size = Vector2(200, 200) # setting the minimize talking frame
	
	# enable redirect following for HTTPRequest
	joke_api.set_max_redirects(5)
	
	sentences = [
	"",
	"",
	"对对对",
	"No Niin",
	"杀杀杀杀杀"
	]
	
	requestJoke(0)
	await get_tree().create_timer(1.0).timeout
	requestJoke(1)
	
	

# checking if right click, then select the whole window, then dragging	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed
			get_viewport().set_input_as_handled() 
	
	if event is InputEventMouseMotion and is_dragging:
		get_tree().root.position += Vector2i(event.relative)
		get_viewport().set_input_as_handled()

	
func _unhandled_input(event:InputEvent) -> void: #quit method
	if event.is_action_pressed("QuitGame"):
		get_tree().quit()


func _on_character_chat() -> void: #chat method
	chat_text.text = sentences.pick_random()
	chat_text.play_chat()
	

func requestJoke(api_index: int) -> void:
	var api = apis[api_index] #choose different api
	joke_api.request(api["url"], api["headers"]) 
	current_api_index = api_index #setting resource api


func _on_joke_api_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
		
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return
	
	var joke_text = ""
	var api_type = apis[current_api_index]["type"]
	
	# get the joke
	if api_type == "jokes" and json.has("joke"):
		joke_text = json["joke"]
	elif api_type == "facts" and json.has("text"):
		joke_text = json["text"]
	
	if joke_text == "":
		return
	
	# save to the places
	if api_type == "jokes":
		sentences[0] = joke_text
	elif api_type == "facts":
		sentences[1] = joke_text


func _on_joke_request_timer_timeout() -> void:
	requestJoke(current_api_index)
	current_api_index = (current_api_index + 1) % 2
