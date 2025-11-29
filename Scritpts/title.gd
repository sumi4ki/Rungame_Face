extends Control

@export var description_scene: PackedScene


func _on_start_button_pressed() -> void:
	# res:// はプロジェクトのルートフォルダを指します
	# main.tscn の実際のパスに合わせてください
	Settings.reset_progress()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_description_button_pressed() -> void:
	if description_scene:
		var description_instance = description_scene.instantiate()
		add_child(description_instance)
	pass # Replace with function body.
