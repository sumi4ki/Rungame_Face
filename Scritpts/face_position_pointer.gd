extends Control

# ポインターの移動を滑らかにするための変数（オプション）
@export var smooth_speed: float = 15.0
var target_position: Vector2 = Vector2.ZERO
var screen_size: Vector2
# 感度を上げて、顔認識ギリギリのエリアに行かないようにする
var pointer_sensitivity = 1.3
var current_x = 0.5
var current_y = 0.5

func _ready():
	# 初期位置を画面中央に
	screen_size = get_viewport_rect().size
	target_position = screen_size / 2
	position = target_position

func _process(delta):
	# 現在の位置から目標位置へ滑らかに移動させる (Lerp). カクつきを抑える
	position = position.lerp(target_position, smooth_speed * delta)

func _on_web_socket_receive_message_received(data: Dictionary) -> void:
	# 再生中に画面の大きさ変更への対応のため、画面サイズ取得
	screen_size = get_viewport_rect().size
	
	if data.has("face_x"):
		var raw_x = clamp(float(data["face_x"]), 0.0, 1.0)
		# 入力は左が1、Godotは左が0 なので反転させる
		current_x = 1.0 - raw_x
		
	if data.has("face_y"):
		var raw_y = clamp(float(data["face_y"]), 0.0, 1.0)
		# Y軸は通常 上が0、下が1 なのでそのまま
		current_y = raw_y

	# アンカーが画面中心であるため、入力から0.5引くことで -0.5 ~ 0.5 の値域に変換
	current_x -= 0.5
	current_y -= 0.5
	
	# -0.5～0.5 の値を 画面サイズ(ピクセル) に変換.
		# screen_sizeの半分を足して画面中央に補正. 
	var pixel_x = ((current_x * screen_size.x * pointer_sensitivity) + screen_size.x/1.9) 
	var pixel_y = ((current_y * screen_size.y * pointer_sensitivity) + screen_size.y/1.9) 
	
	# ポインターの中心を合わせるための補正
	# (TextureRectのサイズなどが size に入っている前提)
	var half_width = size.x / 2.0
	var half_height = size.y / 2.0
	
	target_position = Vector2(pixel_x - half_width, pixel_y - half_height)
	
