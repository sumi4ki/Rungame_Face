extends Control


func _ready():
	var output := []
	var full_path := ProjectSettings.globalize_path("res://face_tracker.py")
	OS.execute("python", [full_path], output, false, false)


func _on_start_button_pressed() -> void:
	# res:// はプロジェクトのルートフォルダを指します
	# main.tscn の実際のパスに合わせてください
	Settings.reset_progress()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
