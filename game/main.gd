extends Node
## Entry point: title screen, car select, match setup, then the match. Owns the music.

var _music: AudioStreamPlayer
var _current: Node


func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.apply_controls()
	GameAudio.sfx_volume = GameSettings.sfx_volume
	_music = AudioStreamPlayer.new()
	_music.stream = GameAudio.looped("music_yard")
	_music.volume_db = linear_to_db(maxf(GameSettings.music_volume, 0.0001)) - 6.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)
	if _music.stream != null:
		_music.play()
	if OS.get_cmdline_user_args().has("--skip-title"):
		_start_match()
	else:
		_show_title()


func _swap(next: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = next
	add_child(next)


func _show_title() -> void:
	var t := TitleScreen.new()
	t.start_pressed.connect(_show_car_select, CONNECT_DEFERRED)
	_swap(t)


func _show_car_select() -> void:
	var c := CarSelect.new()
	c.chosen.connect(func(_id): _show_match_setup(), CONNECT_DEFERRED)
	c.back_pressed.connect(_show_title, CONNECT_DEFERRED)
	_swap(c)


func _show_match_setup() -> void:
	var m := MatchSetup.new()
	m.start_pressed.connect(_start_match, CONNECT_DEFERRED)
	m.back_pressed.connect(_show_car_select, CONNECT_DEFERRED)
	_swap(m)


func _start_match() -> void:
	var m := YardMatch.new()
	m.quit_to_title.connect(_show_title, CONNECT_DEFERRED)
	m.change_car_requested.connect(_show_car_select, CONNECT_DEFERRED)
	m.restart_requested.connect(_start_match, CONNECT_DEFERRED)
	_swap(m)
