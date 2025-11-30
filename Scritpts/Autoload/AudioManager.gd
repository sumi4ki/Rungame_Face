# シーンをまたいでも音が鳴るノード
# AudioStreamPlayerを作成するため、連続で鳴らすSEなどには使わない
extends Node
var bgm_player: AudioStreamPlayer

func _ready():
	# BGM用のスピーカーを1つ作って常駐させる
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)

func play_se(stream: AudioStream, pitch: float = 1.0 ,volume_db: float = 0.0):
	if stream == null:
		print("audio stream null")
		return
	# 1. その音専用のプレイヤーを動的に作る
	var player = AudioStreamPlayer.new()
	
	# 2. パラメータを設定
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	
	# 3. AudioManagerの子として追加
	add_child(player)
	
	# 4. 再生終了したら、自分自身を削除するように予約
	player.finished.connect(player.queue_free)
	
	player.play()

func play_bgm(stream: AudioStream, volume_db: float = 0.0):
	# すでに同じ曲が流れているなら、再生し直さずにそのままにする
	if bgm_player.stream == stream and bgm_player.playing:
		return	
	bgm_player.stream = stream
	bgm_player.volume_db = volume_db
	bgm_player.play()	
func stop_bgm():
	bgm_player.stop()

func set_bgm_pitch(pitch: float):
	if bgm_player:
		# TODO: Tween
		bgm_player.pitch_scale = pitch	
