class_name Player
extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
	HURT,
	DYING,
}

@export var RUN_SPEED := 160.0
@export var JUMP_VELOCITY := -300.0
@export var can_combo := false

var FLOOR_ACCELERATION := RUN_SPEED / 0.2
var AIR_ACCELERATION := RUN_SPEED / 0.1
const GROUND_STATES :=[
	State.IDLE, State.RUNNING,State.LANDING,
	State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]
const WALL_JUMP_VELOCITY := Vector2(380, -280) 
const KNOCKBACK_AMOUNT := 450.0

var is_first_tick := false	# 使第一帧跳跃速度不受重力影响
var is_combo_requested := false # combo是否被请求
var pending_damage: Damage # 声明待处理伤害

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var state_machine: StateMachine = $StateMachine
@onready var stats: Stats = $Stats
@onready var invincible_timer: Timer = $InvincibleTimer



# 获取重力加速度
var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float

func _unhandled_input(event: InputEvent) -> void:
	# 在空中预输入跳跃
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	# 长按大跳
	if event.is_action_released("jump") and velocity.y < JUMP_VELOCITY / 2:
		velocity.y = JUMP_VELOCITY / 2
	# 能否combo
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true


func tick_physics(state: State, delta: float) -> void:
	if invincible_timer.time_left > 0:
		graphics.modulate.a = sin(Time.get_ticks_msec() / 20) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1
	
	
	match state:
		State.IDLE:
			move(default_gravity, delta)
				
		State.RUNNING:
			move(default_gravity, delta)
				
		State.JUMP:
			# 重力不影响第一帧跳跃速度
			move(0.0 if is_first_tick else default_gravity, delta)
				
		State.FALL:
			move(default_gravity, delta)
		
		State.LANDING:
			stand(default_gravity, delta)
		
		State.WALL_SLIDING:
			# 滑墙速度变慢
			move(default_gravity / 3, delta)
			# 滑墙动画朝向设定
			graphics.scale.x = get_wall_normal().x
			
		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				# 确保忽略玩家输入
				stand(0.0 if is_first_tick else default_gravity, delta)
				# 确保跳出去的0.1s内玩家背对墙壁
				graphics.scale.x = get_wall_normal().x
			else:
				move(default_gravity, delta)
				
		State.ATTACK_1, State.ATTACK_2, State.ATTACK_3:
			stand(default_gravity, delta)
		
		State.HURT, State.DYING:
			stand(default_gravity, delta)
			
	is_first_tick = false	

# 决定左右和重力作用下的运动函数
func move(gravity: float, delta: float) -> void:
	# 设置移动方向和速度
	# 获取左右方向，左-1，右1
	var direction := Input.get_axis("move_left", "move_right")
	# 设置x轴速度，匀变速运动，分为地面和空中
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, RUN_SPEED * direction, acceleration * delta)
	# 设置y轴重力影响的速度
	velocity.y += gravity * delta
	
	## 跳跃判断
	## 在地板上或者coyotetime时
	#var can_jump := is_on_floor() or coyote_timer.time_left >0
	#var should_jump := can_jump and jump_request_timer.time_left > 0
	#if should_jump:
		## 更改y的速度
		#velocity.y = JUMP_VELOCITY
		#coyote_timer.stop()	
		#jump_request_timer.stop()
	#
	## 播放动画设置
	#if is_on_floor():
		## 没按方向键，且速度为0，播放idle动画
		#if is_zero_approx(direction) and is_zero_approx(velocity.x):
			#animation_player.play("idle")
		#else:
			#animation_player.play("running")
	#elif velocity.y < 0:
		#animation_player.play("jump")
	#else:
		#animation_player.play("fall")
	
	# 如果向左跑，翻转sprite
	# 因为初始sprite是向右的立绘
	if not is_zero_approx(direction):
		graphics.scale.x = -1 if direction < 0 else 1
	
	#var was_on_floor := is_on_floor()	
	
	# 根据velocity来移动player
	move_and_slide()
	 
	## 判断是否为coyote time
	#if is_on_floor() != was_on_floor:
		#if was_on_floor and not should_jump:
			#coyote_timer.start()
		#else:
			#coyote_timer.stop()

# 处理只受重力的移动
func stand(gravity: float, delta: float) -> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	# 平滑的将x轴速度变为0
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	# 设置y轴重力影响的速度
	velocity.y += gravity * delta
	
	move_and_slide()

# 人物死亡
func die() -> void:
	get_tree().reload_current_scene()	
	
	
# 判断能否进入wall_slide状态
func can_wall_slide() -> bool:
	return is_on_wall_only() and hand_checker.is_colliding() and foot_checker.is_colliding()


# 状态转换函数
func get_next_state(state: State) -> int:
	# 当前生命值为0，进入死亡状态
	# 在死亡状态下，不会重新进入死亡状态
	if stats.health == 0:
		return state_machine.KEEP_CURRENT if state == State.DYING else State.DYING
		
	# 有待处理的伤害，进入受伤状态
	# 重复受伤，也会重新进入受伤状态
	if pending_damage:
		return State.HURT
	
	# 跳跃判断
	# 在地板上或者coyotetime时
	var can_jump := is_on_floor() or coyote_timer.time_left >0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
	# 任何在地面的状态，只要没在地板上，就转换为FALL
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	# 左右移动判断
	# 获取左右方向，左-1，右1
	var direction := Input.get_axis("move_left", "move_right")
	# 是否站立不动
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if not is_still:
				return State.RUNNING
				
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if is_still:
				return State.IDLE
				
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
				
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
				
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
		
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0 and not is_first_tick: 
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		
		State.WALL_JUMP:
			# 确保蹬墙跳可以连续
			# 必须在wall_jump状态下过了1帧，不然会在同一帧进行
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
		
		State.ATTACK_1:
			# ATTACK_1的动画播放完，判断是否进入combo
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_combo_requested else State.IDLE
		
		State.ATTACK_2:
			# ATTACK_2的动画播放完，判断是否进入combo
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_combo_requested else State.IDLE
		
		State.ATTACK_3:
			# ATTACK_3的动画播放完，直接IDLE
			if not animation_player.is_playing():
				return State.IDLE
				
		State.HURT:
			# HURT的动画播放完，直接IDLE
			if not animation_player.is_playing():
				return State.IDLE
				
	# 保持原来状态不变，但重新进入该状态
	return state_machine.KEEP_CURRENT

# 在退出或进入某个状态时，执行的函数 
func transition_state(from: State, to: State) -> void:
	print("[%s] %s => %s" %[
		Engine.get_physics_frames(),
		State.keys()[from] if from != -1 else "<START>",
		State.keys()[to]
	])
	# 任何时候只要着陆，就关闭coyotetime
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
	match to:
		State.IDLE:
			animation_player.play("idle")
				
		State.RUNNING:
			animation_player.play("running")
				
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()	
			jump_request_timer.stop()
				
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
		
		State.LANDING:
			animation_player.play("landing")
			
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")
		
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
		
		State.ATTACK_1:
			animation_player.play("attack_1")
			# 状态转换时关闭combo请求
			is_combo_requested = false
			 
		State.ATTACK_2:
			animation_player.play("attack_2")
			is_combo_requested = false
			
		State.ATTACK_3:
			animation_player.play("attack_3")
			is_combo_requested = false
		
		State.HURT:
			animation_player.play("hurt")
			# 扣除血量
			stats.health -= pending_damage.amount
			
			# 击退
			# 击退方向：从伤害来源的位置指向自己的位置
			var dir := pending_damage.source.global_position.direction_to(global_position)
			# 击退速度
			velocity.x =  sign(dir.x)* KNOCKBACK_AMOUNT
				
			# 防止get_next_state再进入受伤状态 
			pending_damage = null
			
			# 进入无敌时间
			invincible_timer.start()
		
		State.DYING:
			animation_player.play("die")
			# 停止无敌时间
			invincible_timer.stop()
		
	is_first_tick = true


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	# 在无敌时间内不会受到伤害
	if invincible_timer.time_left > 0:
		return
	# 实例化pending_damage
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
