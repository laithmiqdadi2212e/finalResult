extends CharacterBody2D

# -----------------------------
# Tuning
# -----------------------------
const WALK_SPEED       := 80.0
const JUMP_VELOCITY    := -250.0
const ATTACK_DAMAGE    := 25
const ATTACK_RANGE_X   := 36.0     # start attack when |dx| <= this
const ATTACK_COOLDOWN  := 0.6

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# -----------------------------
# Nodes
# -----------------------------
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D      = $Sprite2D
@onready var hitbox: Area2D        = $hitbox
@onready var hurtbox: Area2D       = $hurtbox
@onready var detection: Area2D     = null   # set in _ready if exists

# -----------------------------
# State
# -----------------------------
var is_locked := false
var current_one_shot := ""
var is_dead := false
var facing := -1

var player_detected := false
var player_ref: Node2D = null
var attack_cool := 0.0

# -----------------------------
# Health
# -----------------------------
var max_health := 100
var current_health := max_health

# -----------------------------
# Patrol
# -----------------------------
var patrol_dir := 1
var patrol_timer := 0.0
const PATROL_CHANGE_TIME := 3.0

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health

	# Optional detection area
	if has_node("detection_area"):
		detection = $detection_area
		if not detection.body_entered.is_connected(_on_detection_area_body_entered):
			detection.body_entered.connect(_on_detection_area_body_entered)
		if not detection.body_exited.is_connected(_on_detection_area_body_exited):
			detection.body_exited.connect(_on_detection_area_body_exited)

	# Signals
	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)
	if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	# Hitbox starts OFF; toggled by method keys in attack anim
	hitbox.monitoring = false
	_play_if_diff("idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		if anim.current_animation != "dead":
			anim.play("dead")
		velocity.x = 0
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Cooldown
	if attack_cool > 0.0:
		attack_cool -= delta

	var dir := 0.0

	if player_detected and player_ref:
		var dx := player_ref.global_position.x - global_position.x
		if abs(dx) > ATTACK_RANGE_X:
			dir = sign(dx)
		else:
			dir = 0.0
			_try_attack()
		if dx != 0.0:
			facing = sign(dx)
	else:
		# Simple patrol
		patrol_timer += delta
		if patrol_timer >= PATROL_CHANGE_TIME:
			patrol_timer = 0.0
			patrol_dir *= -1
		dir = patrol_dir
		facing = patrol_dir

	# Movement (blocked during one-shots)
	if not is_locked:
		velocity.x = dir * WALK_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)

	move_and_slide()

	# Animations when free
	if not is_locked:
		_update_move_anim(dir)

	# Face and keep hitbox in front
	sprite.flip_h = (facing < 0)
	$hitbox.position.x = 16.0 * facing

func _update_move_anim(dir: float) -> void:
	if not is_on_floor():
		_play_if_diff("jump")
		return
	if abs(velocity.x) > 1.0:
		if anim.has_animation("run"):
			_play_if_diff("run")
		else:
			_play_if_diff("walk")
	else:
		_play_if_diff("idle")

func _try_attack() -> void:
	if attack_cool > 0.0 or is_locked:
		return
	attack_cool = ATTACK_COOLDOWN

	# Choose an available attack clip
	var attack_name := "attack1"
	if anim.has_animation("RunAndAttack"):
		attack_name = "RunAndAttack"
	elif anim.has_animation("attack2") and randi() % 2 == 0:
		attack_name = "attack2"

	_start_one_shot(attack_name)

# -----------------------------
# One-shots
# -----------------------------
func _start_one_shot(name: String) -> void:
	is_locked = true
	current_one_shot = name
	_play_if_diff(name)

func _on_anim_finished(name: String) -> void:
	if name == current_one_shot:
		if current_one_shot != "dead":
			is_locked = false
		current_one_shot = ""

func _play_if_diff(name: String) -> void:
	if anim.current_animation != name and anim.has_animation(name):
		anim.play(name)

# -----------------------------
# Detection signals
# -----------------------------
func _on_detection_area_body_entered(body: Node) -> void:
	if body and (body.is_in_group("player") or body.has_method("is_player")):
		player_detected = true
		player_ref = body

func _on_detection_area_body_exited(body: Node) -> void:
	if body == player_ref:
		player_detected = false
		player_ref = null

# -----------------------------
# Health / damage
# -----------------------------
func take_damage(amount: int = 25) -> void:
	if is_dead:
		return
	current_health -= amount
	if current_health <= 0:
		_die()
	else:
		_start_one_shot("hurt")

func _die() -> void:
	is_dead = true
	_start_one_shot("dead")
	$CollisionShape2D.disabled = true
	hitbox.monitoring = false
	hurtbox.monitorable = false

# -----------------------------
# Hitbox damage (Area2D signal)
# -----------------------------
func _on_hitbox_area_entered(area: Area2D) -> void:
	# Only damage player hurtbox
	if area.is_in_group("hurtbox_player"):
		var player := area.get_parent()
		if player and player.has_method("take_damage"):
			player.take_damage(ATTACK_DAMAGE)

# -----------------------------
# Methods called from attack animations
# Add Call Method keys in enemy attack anims:
#   _attack_hitbox_on  at impact frame
#   _attack_hitbox_off a few frames later
# -----------------------------
func _attack_hitbox_on() -> void:
	hitbox.monitoring = true

func _attack_hitbox_off() -> void:
	hitbox.monitoring = false

func is_alive() -> bool:
	return not is_dead


func _on_animation_player_animation_changed(old_name: StringName, new_name: StringName) -> void:
	pass # Replace with function body.


func _on_animation_player_current_animation_changed(name: String) -> void:
	pass # Replace with function body.
