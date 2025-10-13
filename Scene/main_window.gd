extends Control

@onready var chat_text: ChatText = $ChatText
@onready var joke_api: HTTPRequest = $JokeApi


var sentences : Array[String] #sentences
var theJoke : String


func _ready() -> void: #the initial settings
	get_tree().root.set_transparent_background(true)
	requestJoke()
	
	chat_text.custom_minimum_size = Vector2(150, 200) # setting the minimize talking frame
	
	
	sentences = [
		"杀杀杀杀杀",
		"我们都有光明的未来",
		"对对对",
		""
		]
	
	
func _unhandled_input(event:InputEvent) -> void: #quit method
	if event.is_action_pressed("QuitGame"):
		get_tree().quit()


func _on_character_chat() -> void: #chat method
	chat_text.text = sentences.pick_random()
	chat_text.play_chat()
	

func requestJoke() -> void:
	var headers = ["Accept: application/json"] #requiring return json format
	joke_api.request("https://icanhazdadjoke.com/", headers) #setting resource api


func _on_joke_api_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json := JSON.parse_string(body.get_string_from_utf8()) as Dictionary
		if json != null and json.has("joke"):
			theJoke = json.joke as String
		
		sentences[3] = theJoke


func _on_joke_request_timer_timeout() -> void:
	requestJoke()
