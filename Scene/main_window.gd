extends Control

@onready var chat_text: ChatText = $ChatText
@onready var joke_api: HTTPRequest = $JokeApi


var sentences : Array[String] #sentences
var theJoke : String


func _ready() -> void: #the initial settings
	get_tree().root.set_transparent_background(true)
	requestJoke()
	sentences = ["天生万物以养人\n人无一物以报天", "杀杀杀杀杀", "我们都有光明的未来", "对对对", "错错错"]
	
	
func _unhandled_input(event:InputEvent) -> void: #quit method
	if event.is_action_pressed("QuitGame"):
		get_tree().quit()


func _on_character_chat() -> void: #chat method
	chat_text.text = sentences.pick_random()
	chat_text.play_chat()
	

func requestJoke() -> void:
	joke_api.request("https://icanhazdadjoke.com/") #setting resource api


func _on_joke_api_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var json := JSON.parse_string(body.get_string_from_utf8()) as Dictionary
