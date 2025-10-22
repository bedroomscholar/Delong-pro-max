extends Node
class_name ConfigManager

# setting the profile path be stored in the user data directory
const CONFIG_PATH = "user://window_config.cfg"

var config : ConfigFile

#initialize the settings
func _ready() -> void:
	config = ConfigFile.new()
	_load_config()

# import the setting file
func _load_config() -> void:
	var err = config.load(CONFIG_PATH)
	if err != OK:
		print("file isn't exist")
	else:
		print("import setting file successfully %s" % CONFIG_PATH)

# save the window location
func save_window_position(position: Vector2i) -> void:
	config.set_value("window", "position_x", position.x)
	config.set_value("window", "position_y", position.y)
	config.set_value("window", "last_saved", Time.get_datetime_string_from_system())
	
	var err = config.save(CONFIG_PATH)
	if err == OK:
		print("saved the window's position %s" % position)
	else:
		push_error("error code $d" % err)

# reading the window's location
func load_window_position() -> Vector2i:
	if not config.has_section("window"):
		print("can't find the window")
		return Vector2i(-1, -1)
		
	var x = config.get_value("window", "position_x", -1)
	var y = config.get_value("window", "position_y", -1)
	
	#checking if the location is valuable
	if x < 0 or y < 0:
		return Vector2i(-1,-1)
	print("import the saved location info (%d, %d)" % [x, y])
	return Vector2i(x, y)

# checking if the location is in the screen
func is_position_valid(position: Vector2i) -> bool:
	var screen_count = DisplayServer.get_screen_count()
	
	#reading all the screen
	for i in range(screen_count):
		var screen_pos = DisplayServer.screen_get_position(i)
		var screen_size = DisplayServer.screen_get_size(i)
		var screen_rect = Rect2i(screen_pos, screen_size)
		
		# checking if the location is in the rectangle
		if screen_rect.has_point(position):
			return true
			
	return false

#getting safe window position
func get_safe_window_position() -> Vector2i:
	var saved_pos = load_window_position()
	# if no saved postion, return to the center of main screen
	if saved_pos.x < 0:
		return _get_screen_center_position()
	
	# checking if the position is still valid
	if is_position_valid(saved_pos):
		return saved_pos
	else:
		print("invalid position. use the main screen")
		return _get_screen_center_position()
	
# get the center of main screen
func _get_screen_center_position() -> Vector2i:
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	return Vector2i(
		(screen_size.x - window_size.x) / 2,
		(screen_size.y - window_size.y) / 2
	)
	
