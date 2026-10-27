extends Node
## BGM（自动加载）：白日/夜晚双主题 chiptune 循环 + 雨声环境音，M 键全局静音

const DAY_DB := -9.0
const NIGHT_DB := -9.0
const RAIN_DB := -13.0

var muted := true  # BGM 与雨声默认关闭，按 M 开启

var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _phase := ""  # "day" / "night"
var _rain_on := false


func _ready() -> void:
	_day = _mk_loop("res://assets/bgm_day.wav")
	_night = _mk_loop("res://assets/bgm_night.wav")
	_rain = _mk_loop("res://assets/s_rain.wav")
	_rain.play()


## 每帧由 main 调用：按时间切昼夜主题、按天气开关雨声
func update_phase(time_min: float, raining: bool) -> void:
	var ph := "night" if (time_min >= 1080.0 or time_min < 360.0) else "day"
	if ph != _phase:
		_phase = ph
		if not muted:
			_crossfade(_day if ph == "day" else _night, _night if ph == "day" else _day)
	if raining != _rain_on:
		_rain_on = raining
		_fade(_rain, RAIN_DB if raining and not muted else -60.0, 1.2)


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		_fade(_day, -60.0, 0.4)
		_fade(_night, -60.0, 0.4)
		_fade(_rain, -60.0, 0.4)
	else:
		var cur := _phase_day()
		_fade(cur, DAY_DB if cur == _day else NIGHT_DB, 0.6, true)
		_fade(_rain, RAIN_DB if _rain_on else -60.0, 0.6)
	return muted


func _phase_day() -> AudioStreamPlayer:
	return _day if _phase == "day" else _night


func _mk_loop(path: String) -> AudioStreamPlayer:
	var s: AudioStreamWAV = load(path)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2  # 16-bit 单声道帧数
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = -60.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _crossfade(fin: AudioStreamPlayer, fout: AudioStreamPlayer) -> void:
	if not fin.playing:
		fin.play()
	_fade(fout, -60.0, 1.6)
	if not muted:
		_fade(fin, DAY_DB if fin == _day else NIGHT_DB, 1.6)


func _fade(p: AudioStreamPlayer, target_db: float, dur: float, and_play := false) -> void:
	if and_play and not p.playing:
		p.play()
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", target_db, dur)
