extends Enemy

enum State{
	IDLE,
	WALK,
	RUN,
}

@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var player_checker: RayCast2D = $Graphics/PlayerChecker
@onready var calm_down_timer: Timer = $CalmDownTimer


func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE:
			move(0.0, delta)
		
		State.WALK:
			move(max_speed / 3, delta)
			
		State.RUN:
			# 暴走状态下，直接转身，继续跑
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				direction *= -1
			move(max_speed, delta)
			# 玩家在checker之内，剩余时间不变
			# 保证野猪一直追
			if player_checker.is_colliding():
				calm_down_timer.start()


func get_next_state(state: State) -> State:
	# 不管现在是什么状态，遇到玩家就会进入RUN状态
	if player_checker.is_colliding():
		return State.RUN
	
	match state:
		State.IDLE:
			# 等待大于一定时间就走起来
			if state_machine.state_time > 2:
				return State.WALK
		
		State.WALK:
			# 如果碰到墙，或者前面踩空
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
		
		State.RUN:
			# 在RUN状态，却没有看见Player，就等待计时结束恢复WALK
			if calm_down_timer.is_stopped():
				return State.WALK
	# 保持当前状态不变	
	return state


func transition_state(from: State, to: State) -> void:
	#print("[%s] %s => %s" %[
		#Engine.get_physics_frames(),
		#State.keys()[from] if from != -1 else "<START>",
		#State.keys()[to]
	#])
	match to:
		State.IDLE:
			animation_player.play("idle")
			# 前面是墙，立即转身
			if wall_checker.is_colliding():
				direction *= -1
				
		State.RUN:
			animation_player.play("run")
				
		State.WALK:
			animation_player.play("walk")
			# 前面是悬崖，先进入IDLE，过一段时间后(2s)，进入WALK
			# 这时候判断是否是悬崖，再转身
			# 实现前面是墙立即转身，前面是悬崖等一段时间再转身的效果
			if not floor_checker.is_colliding():
				direction *= -1
				# 强制更新raycast的检查结果
				# raycast在每一帧开始会更新，但这一帧里后续都用这个值
				# 所以会造成野猪在碰到悬崖后，转身，等一会再走
				floor_checker.force_raycast_update()
				
		
