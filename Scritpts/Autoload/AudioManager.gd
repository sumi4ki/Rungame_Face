extends Node

# シーンをまたいでも音が鳴る必要があるときにつかう。
# もしくはなる回数の少ないシステム音
# AudioStreamPlayerを作成するため、連続で鳴らすSEなどには使わない

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
	
	# 5. 再生！
	player.play()
