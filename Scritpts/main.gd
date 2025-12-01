# main.gd (リファクタリング後)
extends Node

# ゲームの状態を管理
var is_game_over := false
var is_game_cleared := false

# 各主要ノードへの参照
@export var player: CharacterBody3D
@onready var user_interface = $UserInterface
@onready var chunk_director = $ChunkDirector
@onready var mode_label = $UserInterface/ModeLabel

# UIノードへの参照
@export var pause_menu_scene: PackedScene
@export var results_screen_scene: PackedScene

@export var button_click_sound: AudioStream
@export var game_bgm: AudioStream

func _ready():
	# 初回：WebSocketMangagerの信号送信と、受信メソッドを接続
	WebSocketManager.message_received.connect(_on_web_socket_receive_message_received)
	# リトライ時：すでに接続が確立しているなら、"camera_ready" を待たずに生成を開始
	if WebSocketManager.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		print("WebSocketは既に接続済みです。ゲームを開始します。")
		chunk_director.start_spawning()

	player.global_position.z = chunk_director.start_z_pos
	update_mode_display(Settings.start_section)#, player.speed
	user_interface.get_node("Retry").hide()

	# アンミュート
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, false)
	# BGM再生
	if game_bgm:
		AudioManager.play_bgm(game_bgm, -13.0)
	

func _on_player_collided():
	# プレイヤーが衝突したらゲームオーバー処理を呼び出す
	trigger_game_over()

func trigger_game_over():
	if is_game_over:
		return
	is_game_over = true
	
	user_interface.get_node("Retry").show()
	Engine.time_scale = 0.0 # ゲームの時間を止める
	print("Game Over!")

func trigger_game_clear():
	# 既にゲームオーバーかクリア済みなら何もしない
	if is_game_over or is_game_cleared:
		return

	is_game_cleared = true
	print("ゲームクリア！リザルト画面を表示します。")	
	# プレイヤーの速度を0にして、その場で停止させる
	player.speed = 0.0	
	# リザルト画面のインスタンスを作成して表示
	var results_screen = results_screen_scene.instantiate()
	add_child(results_screen)	
	# (オプション) リザルト画面に最終スコアを渡す
	# results_screen.set_final_score(score_variable)

func _unhandled_input(event):
	# リトライ処理
	if event.is_action_pressed("ui_accept") and user_interface.get_node("Retry").visible:
		print("リトライします...")
		Engine.time_scale = 1.0 # 時間を元に戻す
		get_tree().reload_current_scene()

	# トラッキングリセットボタンが押されたら、face_tracking.py に"reset"コマンドを送る
	if event.is_action_pressed("reset_tracking"):
		# print("リセットボタンが押されました。WebSocket 接続をリセットします")
		var message = {"command": "reset"}
		WebSocketManager.send_message(message)

func _on_web_socket_receive_message_received(data: Dictionary) -> void:
	# "status"キーがあるかチェック (カメラ準備メッセージ). カメラ初期化時に"status"を受信
	if data.has("status"):
		if data["status"] == "camera_ready":
			# 初回起動時はここからスタート
			chunk_director.start_spawning()
		elif data["status"] == "camera_failed":
			print("カメラの起動に失敗しました。")

func _on_pause_button_pressed() -> void:
	AudioManager.play_se(button_click_sound)
	# オーディオミュート
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, true)
	# 1. ポーズメニューのインスタンスを作成
	if get_node_or_null("PauseCanvas") == null:
		# and !user_interface.get_node("Retry").visible:

		var pause_menue = pause_menu_scene.instantiate()
		add_child(pause_menue)

	# 3. ゲーム全体を一時停止
	Engine.time_scale = 0.0
	# get_tree().paused = true

func update_mode_display(difficulty_enum):	#, speed
	var mode_text = ""
	match difficulty_enum:
		Settings.Difficulty.EASY:
			mode_text = "かんたん"
		Settings.Difficulty.MEDIUM:
			mode_text = "ふつう"
		Settings.Difficulty.HARD:
			mode_text = "むずかしい"

	mode_label.text = " " + mode_text	# + "speed: " + str(speed)

func setBGMPitchFromDifficulty():
	if Settings.Difficulty.EASY:
		AudioManager.set_bgm_pitch(1.0)
	elif Settings.Difficulty.MEDIUM:
		AudioManager.set_bgm_pitch(1.15)
	elif Settings.Difficulty.HARD:
		AudioManager.set_bgm_pitch(1.3)
