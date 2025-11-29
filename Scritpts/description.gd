extends CanvasLayer

# 操作説明画面の戻るボタン
func _on_resume_pressed() -> void:
	# 自分自身を削除
	queue_free()
	pass # Replace with function body.
