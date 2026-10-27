extends Node
## 8-bit 音效池：预载 WAV，多播放器轮换避免截断，随机音高微调去机械感

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _idx := 0


func _ready() -> void:
	for n in ["hoe", "water", "plant", "harvest", "coin", "bite", "pick", "axe"]:
		_streams[n] = load("res://assets/s_%s.wav" % n)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(key: String, vol_db := 0.0, jitter := 0.05) -> void:
	if not _streams.has(key):
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = _streams[key]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.play()
