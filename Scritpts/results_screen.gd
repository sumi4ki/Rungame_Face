# ゲームクリア時のボタン制御
extends Control

func _on_to_title_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/title.tscn")
