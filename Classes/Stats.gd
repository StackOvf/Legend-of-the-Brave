class_name Stats
extends Node

# 血量变化信号
signal health_changed

@export var max_health: int = 3

@onready var health: int = max_health:
	# 限制health的赋值范围
	set(v):
		v = clampi(v, 0, max_health)
		if health == v:
			return
		health = v
		health_changed.emit()
