# websocket_receive.gd (修正後)
extends Node

# 汎用的なメッセージ受信シグナル
signal message_received(data: Dictionary)

var socket := WebSocketPeer.new()
@export var websocket_url := "ws://localhost:1234"

func _ready():
	var err = socket.connect_to_url(websocket_url)
	set_process(true)
	if err != OK:
		print("接続に失敗しました: ", err)
		set_process(false)
	else:
		print("接続中…")

func _process(_delta):
	socket.poll()

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var msg = socket.get_packet().get_string_from_utf8()
			var data = JSON.parse_string(msg)
			if typeof(data) == TYPE_DICTIONARY:
				emit_signal("message_received", data)
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		print("WebSocket 接続が閉じられました。")
		set_process(false)

# ▼▼▼ 新しくこの関数を追加 ▼▼▼
# 他のスクリプトからメッセージ送信を依頼するための公開関数
func send_message(data: Dictionary):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_string = JSON.stringify(data)
		socket.send_text(json_string)
	else:
		print("WebSocketが接続されていないため、メッセージを送信できませんでした。")
