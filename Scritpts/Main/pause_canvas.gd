# mainシーンで表示するポーズメニューの制御

extends CanvasLayer
@export var JumpSensSlider: Slider
@export var SlidingSenSlider: Slider
@export var button_sound: AudioStream

func _ready() -> void:
	JumpSensSlider.value = Settings.jump_velocity_threshold
	SlidingSenSlider.value = Settings.sliding_velocity_threshold

func _on_to_title_pressed() -> void:
	# 必ずゲームの停止を解除してからシーンを切り替える
	Engine.time_scale = 1.0 # 時間を元に戻す
	# オーディオミュート解除
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, false)
	AudioManager.play_se(button_sound, 1.0)
	
	get_tree().change_scene_to_file("res://Scenes/title.tscn")


func _on_resume_pressed() -> void:
	# ポーズ中に移動した顔のずれをリセット. ジャンプの誤判定対策
	get_tree().call_group("Player", "reset_face_tracking_state")

	# ゲームの停止を解除
	Engine.time_scale = 1.0 # 時間を元に戻す
	# オーディオミュート解除
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_bus_index, false)
	AudioManager.play_se(button_sound, 0.8, -10.0)
	# このメニュー自体をシーンから削除
	queue_free()


func _on_jump_sens_slider_value_changed(value: float) -> void:
	Settings.jump_velocity_threshold = value


func _on_sliding_sens_slider_value_changed(value: float) -> void:
	Settings.sliding_velocity_threshold = value


func _on_to_easy_pressed() -> void:
	# 1. ゲームの停止を解除
	Engine.time_scale = 1.0
	# 2. SettingsのチェックポイントをEASYに設定
	Settings.start_section = Settings.Difficulty.EASY
	# 3. シーンをリロードして、EASYの最初からリスタート
	get_tree().reload_current_scene()


func _on_to_medium_pressed() -> void:
	Engine.time_scale = 1.0
	Settings.start_section = Settings.Difficulty.MEDIUM
	get_tree().reload_current_scene()


func _on_to_hard_pressed() -> void:
	Engine.time_scale = 1.0
	Settings.start_section = Settings.Difficulty.HARD
	get_tree().reload_current_scene()
