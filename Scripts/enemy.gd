# 定义所有敌人通用的属性
class_name Enemy
extends CharacterBody2D

enum Direction{
	LEFT = -1,
	RIGHT = 1,
}

@export var direction := Direction.LEFT:
	set(v):
		direction = v
		# 确保初始化完成
		if not is_node_ready():
			await ready
		# 素材初始向左，向右需要翻转素材
		graphics.scale.x = -direction
@export var max_speed: float = 180
@export var acceleration: float = 2000 

# 获取重力加速度
var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float

@onready var graphics: Node2D = $Graphics
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var stats: Stats = $Stats

# 通用运动函数
func move(speed: float, delta: float) -> void:
	# 平滑的将x轴速度变为目标速度speed
	velocity.x = move_toward(velocity.x, speed * direction, acceleration * delta)
	# 设置y轴重力影响的速度
	velocity.y += default_gravity * delta
	
	move_and_slide()
	
# 通用死亡函数
func die() -> void:
	queue_free()
