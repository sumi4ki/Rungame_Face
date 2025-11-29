# ObstacleData.gd
extends Resource
class_name ObstacleData

@export_enum("jump", "wall", "slide") var type: String
@export_range(0, 2) var lane: int
