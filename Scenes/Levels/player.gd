extends CharacterBody2D

# --- Tuning ---
const WALK_SPEED      := 120.0
const RUN_SPEED       := 190.0
const JUMP_VELOCITY   := -300.0
const ATTACK_DAMAGE   := 50

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- Nodes ---
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D      = $Sprite2D
@onready var hitbox: Area2D        = $hitbox
@onready var hurtbox: Area2D       = $hurtbox

# --- State ---
var is_locked := false
var current_one_shot := ""
var facing := 1                      # 1 right, -1 left

# --- Health ---
var max_health := 100
var current_health := max_health
var is_dead := false

# --- Double Jump ---
var max_jumps := 2
var jumps_remaining := 0
var jump_buffer_time := 0.2  # Time window for buffered jump
var jump_buffer_timer := 0.0
var coyote_time := 0.1       # Time window for coyote time jump
var coyote_timer := 0.0

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	_ensure_input_map()

	# Hitbox starts OFF (toggle during active frames)
	hitbox.monitoring = false
	if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	if not anim.animation_finished.is_connected(_on_anim_finished):
		anim.animation_finished.connect(_on_anim_finished)

# -------------------------------------------------
# Input map (Godot 4 keycode usage)
# -------------------------------------------------
func _add_key(action: String, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)

func _ensure_input_map() -> void:
	if not InputMap.has_action("run"):
		InputMap.add_action("run")
		_add_key("run", KEY_SHIFT)

	if not InputMap.has_action("attack1"):
		InputMap.add_action("attack1")
		_add_key("attack1", KEY_J)

	if not InputMap.has_action("attack2"):
		InputMap.add_action("attack2")
		_add_key("attack2", KEY_K)

	if not InputMap.has_action("attack3"):
		InputMap.add_action("attack3")
		_add_key("attack3", KEY_L)

# -------------------------------------------------
# Game loop
# -------------------------------------------------
func _physics_process(delta: float) -> void:
	# Dead: only play dead & stop moving
	if is_dead:
		if anim.current_animation != "dead":
			anim.play("dead")
		velocity.x = 0
		move_and_slide()
		return

	# Update timers
	_update_timers(delta)

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Reset jumps when on floor
		jumps_remaining = max_jumps
		coyote_timer = coyote_time

	# Input
	var dir := Input.get_axis("ui_left", "ui_right")
	var running := Input.is_action_pressed("run")
	var target_speed := RUN_SPEED if running else WALK_SPEED

	# Movement
	if not is_locked:
		velocity.x = dir * target_speed
	else:
		velocity.x = move_toward(velocity.x, 0, target_speed)

	# Jump input buffering
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time

	# Jump handling
	if not is_locked and _can_jump():
		_perform_jump()

	# Attacks - MOVED THIS BEFORE move_and_slide and removed floor requirement
	if not is_locked:
		if Input.is_action_just_pressed("attack1"):
			_start_one_shot("attack1")
		elif Input.is_action_just_pressed("attack2"):
			_start_one_shot("attack2")
		elif Input.is_action_just_pressed("attack3"):
			_start_one_shot("attack3")

	move_and_slide()

	# Choose move/idle/jump if not in a one-shot
	if not is_locked and current_one_shot == "":
		_update_move_anims(dir, running)

	# Facing + keep the hitbox in front
	if dir != 0.0 and not is_locked:
		facing = -1 if dir < 0.0 else 1
		sprite.flip_h = (facing == -1)
	hitbox.position.x = 18.0 * facing

func _update_timers(delta: float) -> void:
	# Update coyote time
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# Update jump buffer
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

func _can_jump() -> bool:
	return jump_buffer_timer > 0 and (jumps_remaining > 0 or coyote_timer > 0)

func _perform_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer_timer = 0.0
	
	# Use coyote time jump (first jump from ground)
	if coyote_timer > 0:
		coyote_timer = 0.0
	# Use double jump (second jump in air)
	else:
		jumps_remaining -= 1
	
	_play_if_diff("jump")

func _update_move_anims(dir: float, running: bool) -> void:
	if not is_on_floor():
		_play_if_diff("jump")
		return
	if abs(velocity.x) > 1.0:
		_play_if_diff("run" if running else "walk")
	else:
		_play_if_diff("idle")

# -------------------------------------------------
# One-shots: attack / hurt / dead
# -------------------------------------------------
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
	if anim.current_animation != name:
		anim.play(name)

# -------------------------------------------------
# Health & damage
# -------------------------------------------------
func take_damage(damage: int = 50) -> void:
	if is_dead:
		return
	current_health -= damage
	if current_health <= 0:
		_die()
	else:
		_start_one_shot("hurt")

func _die() -> void:
	is_dead = true
	_start_one_shot("dead")
	# Optionally disable collisions:
	# set_collision_layer_value(1, false)
	# set_collision_mask_value(1, false)

# -------------------------------------------------
# Melee via Hitbox Area2D (signal)
# -------------------------------------------------
func _on_hitbox_area_entered(area: Area2D) -> void:
	# Our hitbox touched something; only damage enemy hurtboxes
	if area.is_in_group("hurtbox_enemy"):
		var enemy := area.get_parent()
		if enemy and enemy.has_method("take_damage"):
			enemy.take_damage(ATTACK_DAMAGE)

# -------------------------------------------------
# Methods called from AnimationPlayer (Call Method Track)
# -------------------------------------------------
func _attack_hitbox_on() -> void:
	hitbox.monitoring = true

func _attack_hitbox_off() -> void:
	hitbox.monitoring = false

# -------------------------------------------------
# Optional helpers
# -------------------------------------------------
func is_player() -> bool: return true
func get_health() -> int: return current_health
func reset_player() -> void:
	is_dead = false
	current_health = max_health
	is_locked = false
	current_one_shot = ""
	jumps_remaining = max_jumps
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_play_if_diff("idle")


func _on_animation_player_animation_changed(old_name: StringName, new_name: StringName) -> void:
	pass # Replace with function body.


func _on_animation_player_current_animation_changed(name: String) -> void:
	pass # Replace with function body.
	# Add to your player script
func play_portal_enter():
	# Optional: Play a special portal entry animation
	if has_method("set_locked"):
		set_locked(true)
	
	# Scale down or fade out for portal effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.8)
	tween.tween_callback(queue_free)

func set_locked(locked: bool):
	is_locked = locked
