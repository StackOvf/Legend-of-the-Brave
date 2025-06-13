class_name StateMachine
extends Node

var current_state: int = -1:
	set(v):
		# owner表示父节点，这里是player
		owner.transition_state(current_state, v)
		current_state = v

func _ready() -> void:
	# 等待父节点ready信号(从下往上执行ready函数)
	await owner.ready
	# 调用set, 再调用transition_state
	current_state = 0


func _physics_process(delta: float) -> void:
	# 状态推进循环
	while true:
		var next := owner.get_next_state(current_state) as int
		if current_state == next:
			break
		current_state = next
	
	owner.tick_physics(current_state, delta)
