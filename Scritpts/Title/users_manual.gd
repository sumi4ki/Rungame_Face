# 操作説明の制御
extends CanvasLayer

@onready var button_sound = $ButtonSound
# 操作説明画面の戻るボタン
func _on_resume_pressed() -> void:
	button_sound.play()
	# 見た目だけ消す
	hide()
	# 音が鳴り終わるまで処理を一時停止して待つ
	await button_sound.finished
	# 音が終わったら、自分自身を削除
	queue_free()
