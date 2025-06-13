extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
}

@export var RUN_SPEED := 160.0
@export var JUMP_VELOCITY := -300.0
var FLOOR_ACCELERATION := RUN_SPEED / 0.1
var AIR_ACCELERATION := RUN_SPEED / 0.02
const GROUND_STATES :=[State.IDLE, State.RUNNING, State.LANDING]
var is_first_tick := false	# 使第一帧跳跃速度不受重力影响

@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var hand_checker: RayCast2D = $Graphics/HandChecker

# 获取重力加速度
var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float

func _unhandled_input(event: InputEvent) -> void:
	# 在空中预输入跳跃
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	# 长按大跳
	if event.is_action_released("jump") and velocity.y < JUMP_VELOCITY / 2:
		velocity.y = JUMP_VELOCITY / 2


func tick_physics(state: State, delta: float) -> void:
	
	match state:
		State.IDLE:
			move(default_gravity, delta)
				
		State.RUNNING:
			move(default_gravity, delta)
				
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
				
		State.FALL:
			move(default_gravity, delta)
		
		State.LANDING:
			stand(delta)
		
		State.WALL_SLIDING:
			move(default_gravity / 3, delta)
			graphics.scale.x = get_wall_normal().x
			
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

# 专用于landing的tick_physics
func stand(delta: float) -> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	# 设置y轴重力影响的速度
	velocity.y += default_gravity * delta
	
	move_and_slide()


# 状态转换函数
func get_next_state(state: State) -> State:
	# 跳跃判断
	# 在地板上或者coyotetime时
	var can_jump := is_on_floor() or coyote_timer.time_left >0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
		
	# 左右移动判断
	# 获取左右方向，左-1，右1
	var direction := Input.get_axis("move_left", "move_right")
	# 是否站立不动
	var is_still := is_zero_approx(direction) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if not is_on_floor():
				return State.FALL
			if not is_still:
				return State.RUNNING
				
		State.RUNNING:
			if not is_on_floor():
				return State.FALL
			if is_still:
				return State.IDLE
				
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
				
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if is_on_wall_only() and hand_checker.is_colliding() and foot_checker.is_colliding():
				return State.WALL_SLIDING
				
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
		
		State.WALL_SLIDING:
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
				
	return state

# 在退出或进入某个状态时，执行的函数 
func transition_state(from: State, to: State) -> void:
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
			
	is_first_tick = true
