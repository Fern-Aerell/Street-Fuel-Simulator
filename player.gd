extends CharacterBody3D

# Mengaktifkan atau menonaktifkan efek goyangan kamera saat berjalan
@export var view_bobbing: bool = true
# Mengatur sensitivitas gerakan mouse
@export var mouse_sensitivity: float = 0.1

# Referensi ke node kamera pemain
@onready var player_camera: Camera3D = $PlayerCamera
# Referensi ke node RayCast3D yang digunakan untuk deteksi objek
@onready var player_camera_ray_cast: RayCast3D = $PlayerCamera/RayCast3D

# Batas sudut vertikal untuk melihat ke atas
const VERTICAL_LOOK_LIMIT_UP: float = 90.0
# Batas sudut vertikal untuk melihat ke bawah
const VERTICAL_LOOK_LIMIT_DOWN: float = -50.0
# Amplitudo goyangan kamera
const BOBBING_AMPLITUDE: float = 0.005
# Kecepatan goyangan kamera saat berjalan
const WALK_BOBBING_SPEED: float = 5.0
# Kecepatan goyangan kamera saat berlari
const SPRINT_BOBBING_SPEED: float = 9.0
# Kecepatan gerakan saat berjalan
const WALK_MOVEMENT_SPEED: float = 3.0
# Kecepatan gerakan saat berlari
const SPRINT_MOVEMENT_SPEED: float = 5.0
# Kecepatan lompatan saat berjalan
const WALK_JUMP_VELOCITY: float = 4.5
# Kecepatan lompatan saat berlari
const SPRINT_JUMP_VELOCITY: float = 6.5
# Jarak maksimum untuk mengambil objek
const GRAB_DISTANCE: float = 2.0
# Kecepatan menggerakkan objek yang diambil
const GRAB_SPEED: float = 10.0
# Sudut rotasi objek yang diambil
const GRAB_ROTATION_ANGEL: float = 90.0

# Rotasi vertikal kamera
var rotation_vertical: float = 0.0
# Status apakah mouse sedang ditangkap
var is_mouse_captured: bool = true
# Kecepatan goyangan kamera saat ini
var current_bobbing_speed: float = WALK_BOBBING_SPEED
# Waktu yang telah berlalu untuk efek goyangan
var bobbing_time_passed: float = 0.0
# Kecepatan gerakan saat ini
var current_movement_speed: float = WALK_MOVEMENT_SPEED
# Kecepatan lompatan saat ini
var current_jump_velocity: float = WALK_JUMP_VELOCITY
# Objek yang sedang dipegang
var grabbed_object: RigidBody3D = null
# Variabel untuk menyimpan status rotasi
var is_rotating = false
var rotation_target = Vector3.ZERO

# Fungsi yang dipanggil saat node siap
func _ready() -> void:
	# Mengatur mode mouse menjadi tertangkap
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Fungsi untuk menangani input yang tidak tertangani
func _unhandled_input(event: InputEvent) -> void:
	# Menangani gerakan mouse untuk rotasi kamera
	if event is InputEventMouseMotion and is_mouse_captured:
		_rotate_camera(event.relative)
	# Menangani tombol escape untuk mengalihkan mode tangkapan mouse
	elif event.is_action_pressed("escape") and is_mouse_captured:
		_toggle_mouse_capture()
	# Menangani klik kiri mouse untuk mengalihkan mode tangkapan mouse
	elif event.is_action_pressed("mouse_left_button") and not is_mouse_captured:
		_toggle_mouse_capture()

# Fungsi untuk memutar kamera berdasarkan gerakan mouse
func _rotate_camera(mouse_delta: Vector2) -> void:
	# Memutar kamera secara horizontal
	rotation.y -= deg_to_rad(mouse_delta.x * mouse_sensitivity)
	# Memutar kamera secara vertikal dengan batasan sudut
	rotation_vertical = clamp(rotation_vertical - mouse_delta.y * mouse_sensitivity, VERTICAL_LOOK_LIMIT_DOWN, VERTICAL_LOOK_LIMIT_UP)
	player_camera.rotation_degrees.x = rotation_vertical

# Fungsi untuk mengalihkan mode tangkapan mouse
func _toggle_mouse_capture() -> void:
	# Mengubah status tangkapan mouse
	is_mouse_captured = not is_mouse_captured
	# Mengatur mode mouse sesuai dengan status tangkapan
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if is_mouse_captured else Input.MOUSE_MODE_VISIBLE)

# Fungsi yang dipanggil setiap frame fisika
func _physics_process(delta: float) -> void:
	# Menerapkan gravitasi jika tidak di lantai
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Mengatur kecepatan berdasarkan status berlari
	var is_sprinting = Input.is_action_pressed("sprint")
	current_movement_speed = SPRINT_MOVEMENT_SPEED if is_sprinting else WALK_MOVEMENT_SPEED
	current_jump_velocity = SPRINT_JUMP_VELOCITY if is_sprinting else WALK_JUMP_VELOCITY
	current_bobbing_speed = SPRINT_BOBBING_SPEED if is_sprinting else WALK_BOBBING_SPEED

	# Menangani lompatan
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = current_jump_velocity

	# Menghitung arah gerakan berdasarkan input
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var player_camera_position_default = player_camera.global_transform.origin

	# Menerapkan gerakan dan efek goyangan kamera
	if direction:
		velocity.x = direction.x * current_movement_speed
		velocity.z = direction.z * current_movement_speed
		## VIEW BOBBING
		if view_bobbing:
			bobbing_time_passed += delta * current_bobbing_speed
			var bobbing_offset = Vector3(0, sin(bobbing_time_passed) * BOBBING_AMPLITUDE, 0)
			player_camera.global_transform.origin = player_camera_position_default + bobbing_offset
	else:
		velocity.x = move_toward(velocity.x, 0, current_movement_speed)
		velocity.z = move_toward(velocity.z, 0, current_movement_speed)
		## VIEW BOBBING
		player_camera.global_transform.origin = player_camera_position_default

	# Menerapkan gerakan pada karakter
	move_and_slide()


# Fungsi yang dipanggil setiap frame
func _process(_delta: float) -> void:
	# Menangani pengambilan dan pelepasan objek
	if Input.is_action_pressed("mouse_left_button"):
		if grabbed_object == null:
			_try_grab_object()
		else:
			_hold_object(_delta)
	elif grabbed_object != null:
		_release_object()
	
	if grabbed_object != null:
		# Mengatur arah rotasi berdasarkan input
		var rotation_direction = 0.0

		# Mengatur arah rotasi berdasarkan input
		if Input.is_action_pressed("q"):
			rotation_direction = -1.0 if Input.is_action_pressed("sprint") else 1.0
			rotation_target.x += rotation_direction * 90.0 * _delta  # Incremental rotation
			is_rotating = true
		elif Input.is_action_pressed("e"):
			rotation_direction = -1.0 if Input.is_action_pressed("sprint") else 1.0
			rotation_target.y += rotation_direction * 90.0 * _delta  # Incremental rotation
			is_rotating = true
		elif Input.is_action_pressed("r"):
			rotation_direction = -1.0 if Input.is_action_pressed("sprint") else 1.0
			rotation_target.z += rotation_direction * 90.0 * _delta  # Incremental rotation
			is_rotating = true
		else:
			is_rotating = false

		# Melakukan rotasi jika is_rotating true
		if is_rotating:
			_rotate_grabbed_object(rotation_target, _delta)
		
		# Reset rotation_target jika tidak ada input
		rotation_target = grabbed_object.rotation_degrees
			

# Fungsi untuk mencoba mengambil objek
func _try_grab_object() -> void:
	# Memeriksa apakah ray cast mengenai objek
	if player_camera_ray_cast.is_colliding():
		var object = player_camera_ray_cast.get_collider()
		# Jika objek adalah RigidBody3D, ambil objek tersebut
		if object is RigidBody3D:
			grabbed_object = object
			grabbed_object.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			grabbed_object.freeze = true

# Fungsi untuk memegang objek yang diambil
func _hold_object(delta: float) -> void:
	if grabbed_object:
		# Menghitung posisi target untuk objek yang dipegang
		var target_position = player_camera.global_transform.origin - player_camera.global_transform.basis.z.normalized() * GRAB_DISTANCE
		var motion = (target_position - grabbed_object.global_transform.origin) * GRAB_SPEED * delta
		# Menggerakkan objek yang dipegang
		var collision = grabbed_object.move_and_collide(motion)
		# Menangani tabrakan dengan objek lain
		if collision:
			var collided_body = collision.get_collider()
			if collided_body is RigidBody3D:
				var force_strength = max(0.0, float(grabbed_object.mass - collided_body.mass))
				if force_strength == 0.0:
					force_strength = 0.5
				var impulse_direction = (collided_body.global_transform.origin - grabbed_object.global_transform.origin).normalized()
				collided_body.apply_central_impulse(impulse_direction * force_strength)

# Fungsi untuk melepaskan objek yang dipegang
func _release_object() -> void:
	# Mengaktifkan kembali fisika objek dan melepaskannya
	grabbed_object.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	grabbed_object.freeze = false
	grabbed_object = null

# Fungsi untuk memutar objek yang dipegang pada sumbu tertentu dengan smooth
func _rotate_grabbed_object(target_rotation: Vector3, delta: float) -> void:
	if grabbed_object != null:
		# Kecepatan rotasi
		var rotation_speed = 25.0
		
		# Ambil rotasi saat ini dari objek yang dipegang
		var current_rotation = grabbed_object.rotation_degrees
		
		# Lerp (linear interpolation) untuk rotasi smooth
		current_rotation = current_rotation.lerp(target_rotation, rotation_speed * delta)
		
		# Set rotasi baru pada objek yang dipegang
		grabbed_object.rotation_degrees = current_rotation

