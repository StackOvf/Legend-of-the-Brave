extends Node2D

@onready var tile_map: TileMapLayer = $TileMaps/Geometry
@onready var camera_2d: Camera2D = $Player/Camera2D


func  _ready() -> void:
	# 计算相机上下左右显示极限
	# 获取地图矩形
	var used := tile_map.get_used_rect().grow(-1)
	# 获取每一格的像素尺寸
	var tile_size := tile_map.tile_set.tile_size
	
	# position为矩形左上角坐标，end为右下角
	camera_2d.limit_top = used.position.y * tile_size.y
	camera_2d.limit_bottom = used.end.y * tile_size.y
	camera_2d.limit_left = used.position.x * tile_size.x
	camera_2d.limit_right = used.end.x * tile_size.x
	# 在加载时取消smoothing属性，避免游戏开始时相机平滑移动
	camera_2d.reset_smoothing()
