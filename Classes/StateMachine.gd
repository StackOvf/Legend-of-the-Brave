class_name StateMachine
extends Node

# 特殊值，确保保持状态不变时，都重新进入一次该状态
const KEEP_CURRENT := -1

var current_state: int = -1:
	set(v):
		# owner表示父节点，这里是player
		owner.transition_state(current_state, v)
		current_state = v
		state_time = 0
# 记录玩家在当前状态下经过了多少时间
var state_time : float

func _ready() -> void:
	# 等待父节点ready信号(从下往上执行ready函数)
	await owner.ready
	# 调用set, 再调用transition_state
	current_state = 0


func _physics_process(delta: float) -> void:
	# 状态推进循环
	while true:
		var next := owner.get_next_state(current_state) as int
		# 无论是否转变状态，都会调用transition_state函数来重新进入状态
		if next == KEEP_CURRENT:
			break
		current_state = next
	
	owner.tick_physics(current_state, delta)
	# 记录每个状态的时间
	state_time += delta
