# 各Obstacleの種類、lane (0:左　1:真ん中　2:右)を定義
extends Resource
class_name ObstacleData

@export_enum("jump", "wall", "slide") var type: String
@export_range(0, 2) var lane: int
