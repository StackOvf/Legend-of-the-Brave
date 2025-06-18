extends Enemy

enum State{
	IDLE,
	WALK,
	RUN,
	HURT,
	DYING,
}

# 击退速度常量
const KNOCKBACK_AMOUNT := 450.0

# 待处理的伤害
var pending_damage: Damage

@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var player_checker: RayCast2D = $Graphics/PlayerChecker
@onready var calm_down_timer: Timer = $CalmDownTimer

func can_see_player() -> bool:
	if not player_checker.is_colliding():
		return false
	return player_checker.get_collider() is Player

func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE, State.HURT, State.DYING:
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
			if can_see_player():
				calm_down_timer.start()


func get_next_state(state: State) -> int:
	# 当前生命值为0，进入死亡状态
	# 在死亡状态下，不会重新进入死亡状态
	if stats.health == 0:
		return state_machine.KEEP_CURRENT if state == State.DYING else State.DYING
		
	# 有待处理的伤害，进入受伤状态
	# 重复受伤，也会重新进入受伤状态
	if pending_damage:
		return State.HURT
	match state:
		State.IDLE:
			if can_see_player():
				return State.RUN
			# 等待大于一定时间就走起来
			if state_machine.state_time > 2:
				return State.WALK
		
		State.WALK:
			if can_see_player():
				return State.RUN
			# 如果碰到墙，或者前面踩空
			if wall_checker.is_colliding() or not floor_checker.is_colliding():
				return State.IDLE
		
		State.RUN:
			# 在RUN状态，却没有看见Player，就等待计时结束恢复WALK
			if not can_see_player() and calm_down_timer.is_stopped():
				return State.WALK
				
		State.HURT:
			# HURT动画播放完后，恢复RUN状态
			if not animation_player.is_playing():
				return State.RUN
		
	# 保持当前状态不变,但重新进入该状态
	return state_machine.KEEP_CURRENT

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
		
		State.HURT:
			animation_player.play("hit")
			# 扣除血量
			stats.health -= pending_damage.amount
			
			# 击退
			# 击退方向：从伤害来源的位置指向自己的位置
			var dir := pending_damage.source.global_position.direction_to(global_position)
			# 击退速度&野猪朝向
			if dir.x > 0:
				direction = Direction.LEFT
				velocity.x = Direction.RIGHT * KNOCKBACK_AMOUNT
			else:
				direction = Direction.RIGHT
				velocity.x = Direction.LEFT * KNOCKBACK_AMOUNT
				
			# 防止get_next_state再进入受伤状态 
			pending_damage = null
			
		State.DYING:
			animation_player.play("die")


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
