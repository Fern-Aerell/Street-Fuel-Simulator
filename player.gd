extends CharacterBody3D

## PLAYER CAMERA VARIABLE
# Variabel untuk menyimpan instance camera
@onready var player_camera: Camera3D = $PlayerCamera
# Kecepatan rotasi kamera (dalam derajat per pixel)
var mouse_sensitivity: float = 0.1
# Batas rotasi vertikal untuk kamera (Agar tidak memutar 360 derajat)
const VERTICAL_LOOK_LIMIT_UP: float = 90.0
const VERTICAL_LOOK_LIMIT_DOWN: float = -50.0 # Harus negatif
# Variable untuk menyimpan rotasi vertical (up/down)
var rotation_vertical: float = 0.0
# menyimpan apakah mouse sedang dalam mode capture atau tidak
var is_mouse_captured: bool

## PLAYER BOBBING
@export var view_bobbing: bool = true
# Variable untuk menyimpan seberapah tinggi dan rendah kamera bergerak
const bobbing_amplitude: float = 0.005
# Variable untuk menyimpan kecepatan bobbing saat berjalan
const WALK_BOBBING_SPEED: float = 5.0
# Variable untuk menyimpan kecepatan bobbing saat berlari
const SPRINT_BOBBING_SPEED: float = 9.0
# Variable untuk menyimpan kecepatan bobbing saat saat ini
var current_bobbing_speed: float
# Variable untuk menyimpan waktu bobbing
var bobbing_time_passed: float = 0.0

## PLAYER MOVEMENT VARIABLE
# Variable untuk penyimpan kecepatan berjalan
const WALK_MOVEMENT_SPEED: float = 3.0
# Variable untuk penyimpan kecepatan berlari
const SPRINT_MOVEMENT_SPEED: float = 5.0
# Variable untuk penyimpan tinggi lompatan saat berjalan
const WALK_JUMP_VELOCITY: float = 4.5
# Variable untuk penyimpan tinggi lompatan saat berlari
const SPRINT_JUMP_VELOCITY: float = 6.5
# Variable untuk penyimpan kecepatan bergerak yang akan digunakan
var current_movement_speed: float
# Variable untuk penyimpan tinggi lompatan yang akan digunakan
var current_jump_velocity: float

## PLAYER GRAB OBJECT
# Referensi ke RayCast3D di PlayerCamera
@onready var player_camera_ray_cast: RayCast3D = $PlayerCamera/RayCast3D
# Variabel untuk menyimpan objek yang sedang diambil
var grabbed_object: RigidBody3D = null
# Kecepatan menarik objek ke arah pemain
var grab_distance: float = 2.0
# Kecepatan pergerakan objek ke posisi target
var grab_speed: float = 10.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Mengatur kecepatan bergerak dan tinggi lompatan untuk berjalan
	current_movement_speed = WALK_MOVEMENT_SPEED
	current_jump_velocity = WALK_JUMP_VELOCITY
	# Mengatur kecepatan bobbing untuk berjalan
	current_bobbing_speed = WALK_BOBBING_SPEED
	# Mengatur mode input mouse menjadi captured (Kursor tidak terlihat)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_mouse_captured = true

func _unhandled_input(event):
	# Tangani input mouse jika event adalah MouseMotion dan mouse mode capture
	if event is InputEventMouseMotion and is_mouse_captured:
		_rotate_camera(event.relative)

	# Tangani input jika tombol ESC ditekan
	if event is InputEventKey and event.is_action_pressed("escape"):
		if is_mouse_captured:
			_toggle_mouse_capture()

	# Jika tombol kiri mouse ditekan, kembalikan mode capture
	if event is InputEventMouseButton and event.is_action_pressed("mouse_left_button"):
		if not is_mouse_captured:
			_toggle_mouse_capture()

func _rotate_camera(mouse_delta: Vector2) -> void:
	# Rotasi horizontal (menggerakkan CharacterBody3D)
	rotation.y -= deg_to_rad(mouse_delta.x * mouse_sensitivity)

	# Rotasi vertikal (menggerakkan kamera, tidak langsung pada CharacterBody3D)
	rotation_vertical -= mouse_delta.y * mouse_sensitivity
	rotation_vertical = clamp(rotation_vertical, VERTICAL_LOOK_LIMIT_DOWN, VERTICAL_LOOK_LIMIT_UP)

	# Set rotasi kamera berdasarkan rotasi vertikal
	player_camera.rotation_degrees.x = rotation_vertical

# Fungsi untuk mengubah mode mouse capture
func _toggle_mouse_capture() -> void:
	if is_mouse_captured:
		# Jika mouse sedang di-capture, ubah menjadi visible
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		is_mouse_captured = false
	else:
		# Jika mouse tidak di-capture, ubah kembali menjadi captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		is_mouse_captured = true

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jika pemain menekan tombol sprint maka kecepatan bergerak dan tinggi lompatan akan di sesuaikan
	if Input.is_action_pressed("sprint"):
		# Mengatur kecepatan bergerak dan tinggi lompatan untuk berlari
		current_movement_speed = SPRINT_MOVEMENT_SPEED
		current_jump_velocity = SPRINT_JUMP_VELOCITY
		# Mengatur kecepatan bobbing untuk berlari
		current_bobbing_speed = SPRINT_BOBBING_SPEED
	else:
		# Mengatur kecepatan bergerak dan tinggi lompatan untuk berjalan
		current_movement_speed = WALK_MOVEMENT_SPEED
		current_jump_velocity = WALK_JUMP_VELOCITY
		# Mengatur kecepatan bobbing untuk berjalan
		current_bobbing_speed = WALK_BOBBING_SPEED

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = current_jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var player_camera_position_default = player_camera.global_transform.origin
	if direction:
		velocity.x = direction.x * current_movement_speed
		velocity.z = direction.z * current_movement_speed
		## BOBBING
		if view_bobbing:
			bobbing_time_passed += delta * current_bobbing_speed
			# Hitung posisi bobbing
			var bobbing_offset = Vector3(0, sin(bobbing_time_passed) * bobbing_amplitude, 0)
			player_camera.global_transform.origin = player_camera_position_default + bobbing_offset
	else:
		velocity.x = move_toward(velocity.x, 0, current_movement_speed)
		velocity.z = move_toward(velocity.z, 0, current_movement_speed)
		## BOBBING
		player_camera.global_transform.origin = player_camera_position_default

	move_and_slide()

func _process(delta: float) -> void:
	if Input.is_action_pressed("mouse_left_button"):
		if grabbed_object == null:
			_try_grab_object()
		else:
			_hold_object(delta)
	else:
		if grabbed_object != null:
			_release_object()

# Mencoba mengambil objek
func _try_grab_object():
	if player_camera_ray_cast.is_colliding():
		var object = player_camera_ray_cast.get_collider()
		if object is RigidBody3D:
			grabbed_object = object
			grabbed_object.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			grabbed_object.freeze = true # Membekukan rotasi/gerakan saat diambil

# Memegang objek dan mengatur posisinya
func _hold_object(delta: float):
	if grabbed_object != null:
		var target_position = player_camera.global_transform.origin + -player_camera.global_transform.basis.z.normalized() * grab_distance
		# Hitung pergerakan yang diinginkan
		var motion = target_position - grabbed_object.global_transform.origin
		# Gunakan move_and_collide agar tidak menembus benda lain
		var collision = grabbed_object.move_and_collide(motion * grab_speed * delta)
		# Jika terjadi tabrakan
		if collision:
			var collided_body = collision.get_collider()
			if collided_body is RigidBody3D:
				# Bandingkan massa sebelum menerapkan gaya dorong
				if grabbed_object.mass >= collided_body.mass:
					# Hitung arah dorong
					var impulse_direction = (collided_body.global_transform.origin - grabbed_object.global_transform.origin).normalized()
					# Sesuaikan kekuatan dorongan
					var force_strength = float(grabbed_object.mass - collided_body.mass)
					if force_strength < 0.0:
						force_strength = 0.0
					elif force_strength == 0.0:
						force_strength = 0.5
					collided_body.apply_central_impulse(impulse_direction * force_strength)

# Melepaskan objek
func _release_object():
	if grabbed_object != null:
		grabbed_object.freeze = false # Aktifkan kembali gerakan fisika
		grabbed_object = null
