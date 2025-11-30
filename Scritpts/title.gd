extends Control

@export var description_scene: PackedScene
@export var button_click_sound: AudioStream

func _on_start_button_pressed() -> void:
	# シーンが変わっても音が鳴る様に AudioManager に音鳴らしを依頼する
	if button_click_sound:
		AudioManager.play_se(button_click_sound)	
	Settings.reset_progress()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")	


func _on_description_button_pressed() -> void:
	AudioManager.play_se(button_click_sound)
	if description_scene:
		var description_instance = description_scene.instantiate()
		add_child(description_instance)
	pass # Replace with function body.
