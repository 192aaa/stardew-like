extends Node
## BGM（自动加载）：白日/夜晚双主题 chiptune 循环 + 雨声环境音，M 键全局静音

const DAY_DB := -9.0
const NIGHT_DB := -9.0
const RAIN_DB := -13.0

var muted := true  # BGM 与雨声默认关闭，按 M 或设置面板开启
var volume := 1.0  # 音乐音量 0~1，设置面板调节

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
		_fade(_rain, _rain_db(), 1.2)


## 设置面板用：直接指定静音状态（内部复用 M 键那套淡入淡出）
func set_muted(v: bool) -> void:
	if v != muted:
		toggle_mute()


## 设置面板用：调完音量后把当前曲目推到新目标音量
func apply_volume() -> void:
	if muted:
		return
	var cur := _phase_day()
	if cur.playing:
		_fade(cur, _bgm_db(cur), 0.15)
	if _rain.playing:
		_fade(_rain, _rain_db(), 0.15)


## 音量系数换算成 dB 偏移（0 视为完全静音）
func _vol_db() -> float:
	return linear_to_db(clampf(volume, 0.001, 1.0))


func _bgm_db(p: AudioStreamPlayer) -> float:
	return (DAY_DB if p == _day else NIGHT_DB) + _vol_db()


func _rain_db() -> float:
	return (RAIN_DB + _vol_db()) if (_rain_on and not muted) else -60.0


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		_fade(_day, -60.0, 0.4)
		_fade(_night, -60.0, 0.4)
		_fade(_rain, -60.0, 0.4)
	else:
		var cur := _phase_day()
		_fade(cur, _bgm_db(cur), 0.6, true)
		_fade(_rain, _rain_db(), 0.6)
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
		_fade(fin, _bgm_db(fin), 1.6)


func _fade(p: AudioStreamPlayer, target_db: float, dur: float, and_play := false) -> void:
	if and_play and not p.playing:
		p.play()
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", target_db, dur)
