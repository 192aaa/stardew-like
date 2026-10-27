extends Node
## 联机 Net autoload：WebSocket 房间码客户端
## 负责连接中继服务器（tools/relay/server.js）与消息路由
## 协议：host -> hosted / join -> joined|err / msg 转发 / peer_joined / peer_left

signal room_created(code)
signal joined_room()
signal peer_joined()
signal peer_left()
signal net_message(data)
signal net_error(msg)

enum Mode { SOLO, HOST, GUEST }

var mode: int = Mode.SOLO
var room_code := ""

var _peer := WebSocketPeer.new()
var _want := ""          # 连接建立后要发的请求："__host" 或房间码
var _sent_want := false
var _silent := false     # 主动断开时不触发 net_error


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_online() -> bool:
	return mode != Mode.SOLO


func is_host() -> bool:
	return mode == Mode.HOST


func is_guest() -> bool:
	return mode == Mode.GUEST


## 建房：连接中继并申请房间
func start_host() -> void:
	_connect_relay("__host")


## 加入指定房间
func start_join(code: String) -> void:
	_connect_relay(code.strip_edges().to_upper())


## 主动断开（不触发 net_error）
func close() -> void:
	_silent = true
	_want = ""
	_sent_want = false
	room_code = ""
	mode = Mode.SOLO
	if _peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_peer.close()


## 发送应用层消息（自动包一层 {t:"msg",data}）
func send(data: Dictionary) -> void:
	if _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_peer.send_text(JSON.stringify({t = "msg", data = data}))


func _connect_relay(want: String) -> void:
	_reset()
	_silent = false
	_want = want
	var err := _peer.connect_to_url(_relay_url())
	if err != OK:
		net_error.emit("无法连接服务器")
		_reset()


func _reset() -> void:
	_peer = WebSocketPeer.new()
	_want = ""
	_sent_want = false
	room_code = ""
	mode = Mode.SOLO


## 中继地址：环境变量 SL_RELAY > 网页 ?ws= 参数 > 默认本机
func _relay_url() -> String:
	var url := OS.get_environment("SL_RELAY")
	if url != "":
		return url
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('ws') || ''", true))
		if q != "":
			return q
	return "ws://localhost:8765"


func _process(_delta: float) -> void:
	if _peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _sent_want and _want != "":
			_sent_want = true
			if _want == "__host":
				_peer.send_text(JSON.stringify({t = "host"}))
			else:
				_peer.send_text(JSON.stringify({t = "join", code = _want}))
		while _peer.get_available_packet_count() > 0:
			# 协议只使用文本帧（send_text），无需区分二进制
			_on_packet(_peer.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		if _silent:
			_reset()
		elif _want != "" and not _sent_want:
			net_error.emit("无法连接服务器")
			_reset()
		else:
			net_error.emit("连接已断开")
			_reset()


func _on_packet(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return
	match parsed.get("t", ""):
		"hosted":
			mode = Mode.HOST
			room_code = str(parsed.get("code", ""))
			room_created.emit(room_code)
		"joined":
			mode = Mode.GUEST
			room_code = str(parsed.get("code", ""))
			joined_room.emit()
		"err":
			net_error.emit(str(parsed.get("msg", "加入失败")))
			_reset()
		"peer_joined":
			peer_joined.emit()
		"peer_left":
			peer_left.emit()
		"msg":
			var d = parsed.get("data")
			if d is Dictionary:
				net_message.emit(d)
