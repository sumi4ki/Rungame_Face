extends Area3D


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		body.dead()
		print("正面衝突によるゲームオーバー")
