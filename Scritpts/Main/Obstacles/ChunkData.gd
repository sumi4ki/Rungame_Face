# 1チャンクが持つデータ型の定義
extends Resource
class_name ChunkData

@export var length: int = 20                # そのチャンクに使う床の長さ
@export var obstacles: Array[ObstacleData]  # どの障害物を使うか
@export var z_pos_list: Array[int]          # lengthで確保した床に対して、どの奥行きに障害物を配置するか
@export var float_amount_list: Array[float] # その障害物を浮かせる量
