extends Node3D

const PLAYER_SPEED := 4.2
const MOUSE_SENSITIVITY := 0.0025
const TOUCH_SENSITIVITY := 0.0032
const ROOM_HALF := 6.0

var player: CharacterBody3D
var camera: Camera3D
var touch_ui: Control
var touch_move := Vector2.ZERO
var pitch := 0.0
var mouse_captured := false
var edit_mode := false
var selected_object: Node3D
var editor_panel: PanelContainer
var room_width := 12.0
var room_height := 3.2
var room_depth := 12.0
var items_panel: PanelContainer
var wardrobe_panel: PanelContainer
var held_item: RigidBody3D
var inventory := {"bottle": 0, "box": 0}
var item_save_path := "user://room_items.json"
var item_serial := 0
var item_save_timer := 0.0
var lighting_mode := false
var lighting_panel: PanelContainer
var selected_light: OmniLight3D
var placed_lights: Array[OmniLight3D] = []
var light_save_path := "user://room_lights.json"
var room_save_path := "user://room_layout.json"

func _ready() -> void:
	print("Room Explorer: _ready started")
	_build_world()
	_load_room_layout()
	_load_light_state()
	_build_player()
	_build_ui()
	_load_item_state()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("Room Explorer: world, player and UI initialized")

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.10, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 0.65
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 0.8
	add_child(sun)

	_box("Floor", Vector3(room_width, 0.2, room_depth), Vector3(0, -0.1, 0), Color(0.30, 0.27, 0.23))
	_box("Ceiling", Vector3(room_width, 0.2, room_depth), Vector3(0, room_height, 0), Color(0.72, 0.72, 0.68))
	_box("Back wall", Vector3(room_width, room_height, 0.2), Vector3(0, room_height * 0.5 - 0.1, -room_depth * 0.5), Color(0.48, 0.52, 0.56))
	_box("Front wall", Vector3(room_width, room_height, 0.2), Vector3(0, room_height * 0.5 - 0.1, room_depth * 0.5), Color(0.48, 0.52, 0.56))
	_box("Left wall", Vector3(0.2, room_height, room_depth), Vector3(-room_width * 0.5, room_height * 0.5 - 0.1, 0), Color(0.43, 0.47, 0.52))
	_box("Right wall", Vector3(0.2, room_height, room_depth), Vector3(room_width * 0.5, room_height * 0.5 - 0.1, 0), Color(0.43, 0.47, 0.52))

	# Window and architectural trim.
	_box("Window glass", Vector3(2.5, 1.35, 0.06), Vector3(-5.87, 1.95, -1.0), Color(0.18, 0.42, 0.58), false)
	_box("Window sill", Vector3(0.18, 0.12, 2.8), Vector3(-5.72, 1.22, -1.0), Color(0.22, 0.20, 0.18))
	_box("Window top", Vector3(0.18, 0.12, 2.8), Vector3(-5.72, 2.68, -1.0), Color(0.22, 0.20, 0.18))
	_box("Window divider", Vector3(0.18, 1.5, 0.12), Vector3(-5.72, 1.95, -1.0), Color(0.22, 0.20, 0.18))

	# Door on the front wall: dark aged wood, frame and metal handle.
	_box("Door", Vector3(1.05, 2.25, 0.10), Vector3(-3.9, 1.12, 5.82), Color(0.30, 0.19, 0.12))
	_box("Door frame left", Vector3(0.10, 2.42, 0.16), Vector3(-4.48, 1.21, 5.72), Color(0.20, 0.15, 0.11))
	_box("Door frame right", Vector3(0.10, 2.42, 0.16), Vector3(-3.32, 1.21, 5.72), Color(0.20, 0.15, 0.11))
	_box("Door frame top", Vector3(1.25, 0.10, 0.16), Vector3(-3.9, 2.42, 5.72), Color(0.20, 0.15, 0.11))
	_box("Door handle", Vector3(0.06, 0.06, 0.12), Vector3(-3.48, 1.08, 5.70), Color(0.72, 0.65, 0.45))

	# Selected furniture: distressed industrial desk and modern dark wardrobe.
	_box("Industrial desk top", Vector3(2.25, 0.13, 0.95), Vector3(2.85, 1.05, -3.65), Color(0.30, 0.29, 0.27))
	_box("Industrial desk leg left", Vector3(0.10, 1.0, 0.10), Vector3(1.88, 0.50, -4.02), Color(0.20, 0.21, 0.22))
	_box("Industrial desk leg right", Vector3(0.10, 1.0, 0.10), Vector3(3.82, 0.50, -4.02), Color(0.20, 0.21, 0.22))
	_box("Industrial desk rear leg left", Vector3(0.10, 1.0, 0.10), Vector3(1.88, 0.50, -3.28), Color(0.20, 0.21, 0.22))
	_box("Industrial desk rear leg right", Vector3(0.10, 1.0, 0.10), Vector3(3.82, 0.50, -3.28), Color(0.20, 0.21, 0.22))
	_box("Industrial desk drawer unit", Vector3(0.48, 0.72, 0.78), Vector3(3.55, 0.52, -3.65), Color(0.24, 0.25, 0.26))
	_box("Industrial desk drawer handle", Vector3(0.22, 0.035, 0.035), Vector3(3.55, 0.65, -3.235), Color(0.68, 0.68, 0.64))
	_box("Industrial desk drawer front", Vector3(0.43, 0.19, 0.045), Vector3(3.55, 0.76, -3.245), Color(0.31, 0.32, 0.33))
	_box("Industrial desk drawer lower", Vector3(0.43, 0.19, 0.045), Vector3(3.55, 0.48, -3.245), Color(0.25, 0.26, 0.27))
	_box("Industrial desk crossbar front", Vector3(1.78, 0.07, 0.07), Vector3(2.85, 0.32, -4.02), Color(0.16, 0.17, 0.18))
	_box("Industrial desk crossbar rear", Vector3(1.78, 0.07, 0.07), Vector3(2.85, 0.32, -3.28), Color(0.16, 0.17, 0.18))
	_box("Industrial desk tabletop edge", Vector3(2.28, 0.045, 0.99), Vector3(2.85, 1.135, -3.65), Color(0.17, 0.18, 0.19))
	_box("Industrial desk side brace left", Vector3(0.055, 0.62, 0.055), Vector3(1.99, 0.58, -3.65), Color(0.13, 0.14, 0.15))
	_box("Industrial desk side brace right", Vector3(0.055, 0.62, 0.055), Vector3(3.71, 0.58, -3.65), Color(0.13, 0.14, 0.15))
	_box("Industrial desk handle upper", Vector3(0.24, 0.025, 0.025), Vector3(3.55, 0.78, -3.205), Color(0.78, 0.78, 0.73))
	_box("Industrial desk handle lower", Vector3(0.24, 0.025, 0.025), Vector3(3.55, 0.50, -3.205), Color(0.78, 0.78, 0.73))

	_box("Modern wardrobe body", Vector3(1.45, 2.35, 0.78), Vector3(4.65, 1.17, 1.75), Color(0.17, 0.19, 0.22))
	_box("Modern wardrobe left door", Vector3(0.68, 2.22, 0.045), Vector3(4.28, 1.18, 1.335), Color(0.24, 0.27, 0.30))
	_box("Modern wardrobe right door", Vector3(0.68, 2.22, 0.045), Vector3(5.02, 1.18, 1.335), Color(0.21, 0.24, 0.27))
	_box("Modern wardrobe handle left", Vector3(0.025, 0.42, 0.035), Vector3(4.55, 1.18, 1.29), Color(0.72, 0.74, 0.76))
	_box("Modern wardrobe handle right", Vector3(0.025, 0.42, 0.035), Vector3(4.78, 1.18, 1.29), Color(0.72, 0.74, 0.76))

	# A compact radiator below the window and a simple ceiling fixture.
	_box("Window radiator", Vector3(0.18, 0.55, 1.75), Vector3(-5.55, 0.48, -1.0), Color(0.72, 0.73, 0.70))
	_box("Radiator pipe", Vector3(0.12, 0.08, 1.9), Vector3(-5.48, 0.18, -1.0), Color(0.56, 0.57, 0.55))

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.7, 0)
	lamp.light_color = Color(1.0, 0.78, 0.52)
	lamp.light_energy = 1.1
	lamp.omni_range = 8.0
	add_child(lamp)

func _box(label: String, size: Vector3, pos: Vector3, color: Color, solid: bool = true) -> void:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = label
	root.position = pos
	add_child(root)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	var texture_path := ""
	if label.to_lower().contains("wall") or label == "Ceiling":
		texture_path = "res://textures/concrete.png"
	elif label == "Floor":
		texture_path = "res://textures/worn_wood.png"
	elif label.to_lower().contains("industrial desk"):
		texture_path = "res://textures/industrial_metal.png"
	elif label.to_lower().contains("modern wardrobe"):
		texture_path = "res://textures/wardrobe.png"
	elif label.to_lower().contains("door"):
		texture_path = "res://textures/worn_wood.png"
	if texture_path != "":
		var tex := load(texture_path) as Texture2D
		if tex != null:
			material.albedo_texture = tex
			material.uv1_scale = Vector3(2.0, 2.0, 2.0)
	mesh_node.material_override = material
	root.add_child(mesh_node)
	if solid:
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		root.add_child(shape_node)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.95, 4.0)
	add_child(player)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	player.add_child(collision)

	camera = Camera3D.new()
	camera.position = Vector3(0, 0.62, 0)
	camera.fov = 78.0
	camera.current = true
	player.add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "ROOM EXPLORER"
	title.position = Vector2(22, 18)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.94, 0.86))
	layer.add_child(title)

	var hint := Label.new()
	hint.text = "WASD / джойстик — движение    •    мышь / правая часть экрана — обзор"
	hint.position = Vector2(22, 48)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90))
	layer.add_child(hint)

	var overlay_script := load("res://touch_controls.gd")
	touch_ui = Control.new()
	touch_ui.set_script(overlay_script)
	touch_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(touch_ui)
	touch_ui.connect("move_changed", Callable(self, "_on_touch_move"))
	touch_ui.connect("look_delta", Callable(self, "_on_touch_look"))
	touch_ui.connect("screen_tap", Callable(self, "_on_touch_tap"))
	var edit_button := Button.new()
	edit_button.text = "EDIT"
	edit_button.position = Vector2(22, 82)
	edit_button.size = Vector2(112, 48)
	layer.add_child(edit_button)
	edit_button.pressed.connect(_toggle_editor)
	_build_editor_panel(layer)
	var items_button := Button.new()
	items_button.text = "ПРЕДМЕТЫ"
	items_button.position = Vector2(22, 140)
	items_button.size = Vector2(112, 48)
	layer.add_child(items_button)
	items_button.pressed.connect(_toggle_items_panel)
	var lighting_button := Button.new()
	lighting_button.text = "LIGHTING"
	lighting_button.position = Vector2(22, 198)
	lighting_button.size = Vector2(112, 48)
	layer.add_child(lighting_button)
	lighting_button.pressed.connect(_toggle_lighting_mode)
	_build_lighting_panel(layer)
	var pickup_button := Button.new()
	pickup_button.text = "ВЗЯТЬ / ПОЛОЖИТЬ"
	pickup_button.position = Vector2(-250, 18)
	pickup_button.size = Vector2(220, 48)
	pickup_button.anchor_left = 1.0
	pickup_button.anchor_right = 1.0
	layer.add_child(pickup_button)
	pickup_button.pressed.connect(_toggle_hold_item)
	var inventory_button := Button.new()
	inventory_button.text = "В ИНВЕНТАРЬ"
	inventory_button.position = Vector2(-250, 74)
	inventory_button.size = Vector2(220, 48)
	inventory_button.anchor_left = 1.0
	inventory_button.anchor_right = 1.0
	layer.add_child(inventory_button)
	inventory_button.pressed.connect(_put_held_in_inventory)
	var wardrobe_button := Button.new()
	wardrobe_button.text = "ШКАФ / ИНВЕНТАРЬ"
	wardrobe_button.position = Vector2(-250, 130)
	wardrobe_button.size = Vector2(220, 48)
	wardrobe_button.anchor_left = 1.0
	wardrobe_button.anchor_right = 1.0
	layer.add_child(wardrobe_button)
	wardrobe_button.pressed.connect(_interact_wardrobe)
	_build_items_panel(layer)
	_build_wardrobe_panel(layer)

func _on_touch_move(value: Vector2) -> void:
	touch_move = value

func _on_touch_look(delta: Vector2) -> void:
	if not edit_mode and not lighting_mode:
		_rotate_view(delta * TOUCH_SENSITIVITY)

func _on_touch_tap(pos: Vector2) -> void:
	if lighting_mode:
		_place_or_select_light(pos)
	elif edit_mode:
		_select_object(get_viewport_rect().size * 0.5)

func _rotate_view(delta: Vector2) -> void:
	player.rotate_y(-delta.x)
	pitch = clampf(pitch - delta.y, deg_to_rad(-78.0), deg_to_rad(78.0))
	camera.rotation.x = pitch

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_item_state()
		_save_room_layout()
		_save_light_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and lighting_mode:
		_place_or_select_light(get_viewport().get_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and edit_mode:
		_select_object(get_viewport_rect().size * 0.5)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and mouse_captured and not lighting_mode and not edit_mode:
		_rotate_view(event.relative * MOUSE_SENSITIVITY)

func _process(delta: float) -> void:
	if held_item != null and is_instance_valid(held_item):
		var target := camera.global_position + (-camera.global_transform.basis.z * 1.35)
		held_item.global_position = target
		held_item.global_rotation = camera.global_rotation
	item_save_timer += delta
	if item_save_timer >= 2.0:
		item_save_timer = 0.0
		_save_item_state()

func _physics_process(_delta: float) -> void:
	if edit_mode or lighting_mode:
		player.velocity = Vector3.ZERO
		return
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard.y -= 1.0

	var move_input := Vector2(touch_move.x, -touch_move.y)
	if keyboard.length() > 0.05:
		move_input = keyboard.normalized()

	var local_direction := Vector3(move_input.x, 0.0, -move_input.y)
	var direction := player.global_transform.basis * local_direction
	direction.y = 0.0
	direction = direction.normalized()

	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED

	if not player.is_on_floor():
		player.velocity.y -= 18.0 * get_physics_process_delta_time()
	else:
		player.velocity.y = -0.1

	player.move_and_slide()


func _build_editor_panel(layer: CanvasLayer) -> void:
	editor_panel = PanelContainer.new()
	editor_panel.position = Vector2(150, 82)
	editor_panel.size = Vector2(330, 500)
	editor_panel.visible = false
	layer.add_child(editor_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 300
	col.add_theme_constant_override("separation", 5)
	scroll.add_child(col)
	var heading := Label.new()
	heading.text = "РЕДАКТОР КОМНАТЫ"
	heading.add_theme_font_size_override("font_size", 20)
	col.add_child(heading)
	var help := Label.new()
	help.text = "Нажми на предмет в режиме EDIT, чтобы выбрать его."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(help)
	_add_editor_button(col, "Выше +0.2", func(): _move_selected(Vector3.UP * 0.2))
	_add_editor_button(col, "Ниже -0.2", func(): _move_selected(Vector3.DOWN * 0.2))
	_add_editor_button(col, "Вперёд / Назад", func(): _move_selected(Vector3(0, 0, -0.25)))
	_add_editor_button(col, "Назад / Вперёд", func(): _move_selected(Vector3(0, 0, 0.25)))
	_add_editor_button(col, "Влево", func(): _move_selected(Vector3.LEFT * 0.25))
	_add_editor_button(col, "Вправо", func(): _move_selected(Vector3.RIGHT * 0.25))
	_add_editor_button(col, "Повернуть -15°", func(): _rotate_selected(-15.0))
	_add_editor_button(col, "Повернуть +15°", func(): _rotate_selected(15.0))
	_add_editor_button(col, "Увеличить предмет", func(): _scale_selected(1.05))
	_add_editor_button(col, "Уменьшить предмет", func(): _scale_selected(0.95))
	var sep := HSeparator.new()
	col.add_child(sep)
	var room_label := Label.new()
	room_label.text = "Размеры комнаты"
	col.add_child(room_label)
	_add_editor_button(col, "Шире +0.5", func(): _resize_room(0.5, 0.0, 0.0))
	_add_editor_button(col, "Уже -0.5", func(): _resize_room(-0.5, 0.0, 0.0))
	_add_editor_button(col, "Выше +0.2", func(): _resize_room(0.0, 0.2, 0.0))
	_add_editor_button(col, "Ниже -0.2", func(): _resize_room(0.0, -0.2, 0.0))
	_add_editor_button(col, "Глубже +0.5", func(): _resize_room(0.0, 0.0, 0.5))
	_add_editor_button(col, "Мельче -0.5", func(): _resize_room(0.0, 0.0, -0.5))
	_add_editor_button(col, "СОХРАНИТЬ КОМНАТУ", _save_room_layout)
	_add_editor_button(col, "Закрыть редактор", _toggle_editor)

func _build_lighting_panel(layer: CanvasLayer) -> void:
	lighting_panel = PanelContainer.new()
	lighting_panel.position = Vector2(150, 198)
	lighting_panel.size = Vector2(300, 370)
	lighting_panel.visible = false
	layer.add_child(lighting_panel)
	var scroll := ScrollContainer.new()
	lighting_panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 270
	col.add_theme_constant_override("separation", 5)
	scroll.add_child(col)
	var heading := Label.new()
	heading.text = "НАСТРОЙКА СВЕТА"
	col.add_child(heading)
	var help := Label.new()
	help.text = "Нажми на поверхность комнаты, чтобы поставить или выбрать источник света."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(help)
	_add_editor_button(col, "Яркость +", func(): _adjust_selected_light(0.2, 0.0))
	_add_editor_button(col, "Яркость -", func(): _adjust_selected_light(-0.2, 0.0))
	_add_editor_button(col, "Радиус +", func(): _adjust_selected_light(0.0, 0.5))
	_add_editor_button(col, "Радиус -", func(): _adjust_selected_light(0.0, -0.5))
	_add_editor_button(col, "Свет выше", func(): _move_selected_light(Vector3.UP * 0.2))
	_add_editor_button(col, "Свет ниже", func(): _move_selected_light(Vector3.DOWN * 0.2))
	_add_editor_button(col, "Свет влево", func(): _move_selected_light(Vector3.LEFT * 0.2))
	_add_editor_button(col, "Свет вправо", func(): _move_selected_light(Vector3.RIGHT * 0.2))
	_add_editor_button(col, "Свет вперёд", func(): _move_selected_light(Vector3(0, 0, -0.2)))
	_add_editor_button(col, "Свет назад", func(): _move_selected_light(Vector3(0, 0, 0.2)))
	_add_editor_button(col, "Тёплый цвет", func(): _set_selected_light_color(Color(1.0, 0.72, 0.45)))
	_add_editor_button(col, "Холодный цвет", func(): _set_selected_light_color(Color(0.55, 0.75, 1.0)))
	_add_editor_button(col, "Белый цвет", func(): _set_selected_light_color(Color.WHITE))
	_add_editor_button(col, "Удалить выбранный свет", _delete_selected_light)
	_add_editor_button(col, "Сохранить настройки света", _save_light_state)
	_add_editor_button(col, "Закрыть Lighting", _toggle_lighting_mode)

func _toggle_lighting_mode() -> void:
	lighting_mode = not lighting_mode
	lighting_panel.visible = lighting_mode
	if lighting_mode:
		edit_mode = false
		editor_panel.visible = false
		items_panel.visible = false
		touch_move = Vector2.ZERO
		mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		selected_light = null

func _place_or_select_light(screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hit_node: Object = hit.get("collider")
	if hit_node is Node:
		var node := hit_node as Node
		while node != null:
			if node is OmniLight3D:
				selected_light = node as OmniLight3D
				return
			node = node.get_parent()
	var light := OmniLight3D.new()
	light.name = "PlacedLight_%d" % (placed_lights.size() + 1)
	light.global_position = hit.position + Vector3.UP * 1.0
	light.light_energy = 1.0
	light.omni_range = 5.0
	light.light_color = Color(1.0, 0.86, 0.68)
	add_child(light)
	placed_lights.append(light)
	selected_light = light
	_save_light_state()

func _adjust_selected_light(energy_delta: float, range_delta: float) -> void:
	if selected_light == null or not is_instance_valid(selected_light):
		return
	selected_light.light_energy = clampf(selected_light.light_energy + energy_delta, 0.1, 8.0)
	selected_light.omni_range = clampf(selected_light.omni_range + range_delta, 1.0, 20.0)
	_save_light_state()

func _move_selected_light(offset: Vector3) -> void:
	if selected_light != null and is_instance_valid(selected_light):
		selected_light.position += offset
		_save_light_state()

func _set_selected_light_color(value: Color) -> void:
	if selected_light != null and is_instance_valid(selected_light):
		selected_light.light_color = value
		_save_light_state()

func _delete_selected_light() -> void:
	if selected_light == null or not is_instance_valid(selected_light):
		return
	placed_lights.erase(selected_light)
	selected_light.queue_free()
	selected_light = null
	_save_light_state()

func _save_light_state() -> void:
	var entries: Array[Dictionary] = []
	for light in placed_lights:
		if is_instance_valid(light):
			entries.append({"position": [light.position.x, light.position.y, light.position.z], "energy": light.light_energy, "range": light.omni_range, "color": [light.light_color.r, light.light_color.g, light.light_color.b]})
	var file := FileAccess.open(light_save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"lights": entries}))

func _load_light_state() -> void:
	if not FileAccess.file_exists(light_save_path):
		return
	var file := FileAccess.open(light_save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for entry in parsed.get("lights", []):
		var pos: Array = entry.get("position", [0.0, 2.0, 0.0])
		var rgb: Array = entry.get("color", [1.0, 0.86, 0.68])
		if pos.size() < 3 or rgb.size() < 3:
			continue
		var light := OmniLight3D.new()
		light.name = "PlacedLight_%d" % (placed_lights.size() + 1)
		light.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		light.light_energy = float(entry.get("energy", 1.0))
		light.omni_range = float(entry.get("range", 5.0))
		light.light_color = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
		add_child(light)
		placed_lights.append(light)

func _save_room_layout() -> void:
	var objects: Array[Dictionary] = []
	for node in get_children():
		if node is Node3D and node != player and node != camera and not (node is OmniLight3D):
			if node.name in ["WorldEnvironment"]:
				continue
			objects.append({"name": node.name, "position": [node.position.x, node.position.y, node.position.z], "rotation": [node.rotation.x, node.rotation.y, node.rotation.z], "scale": [node.scale.x, node.scale.y, node.scale.z]})
	var file := FileAccess.open(room_save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"width": room_width, "height": room_height, "depth": room_depth, "objects": objects}))

func _load_room_layout() -> void:
	if not FileAccess.file_exists(room_save_path):
		return
	var file := FileAccess.open(room_save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	room_width = float(parsed.get("width", room_width))
	room_height = float(parsed.get("height", room_height))
	room_depth = float(parsed.get("depth", room_depth))
	_resize_room(0.0, 0.0, 0.0)
	for entry in parsed.get("objects", []):
		var node := get_node_or_null(NodePath(str(entry.get("name", ""))))
		if node is Node3D:
			var pos: Array = entry.get("position", [])
			var rot: Array = entry.get("rotation", [])
			var scl: Array = entry.get("scale", [])
			if pos.size() >= 3 and rot.size() >= 3 and scl.size() >= 3:
				node.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
				node.rotation = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
				node.scale = Vector3(float(scl[0]), float(scl[1]), float(scl[2]))

func _build_items_panel(layer: CanvasLayer) -> void:
	items_panel = PanelContainer.new()
	items_panel.position = Vector2(150, 140)
	items_panel.size = Vector2(280, 230)
	items_panel.visible = false
	layer.add_child(items_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	items_panel.add_child(col)
	var heading := Label.new()
	heading.text = "ПРЕДМЕТЫ"
	heading.add_theme_font_size_override("font_size", 19)
	col.add_child(heading)
	_add_editor_button(col, "Создать бутылку", func(): _spawn_item("bottle"))
	_add_editor_button(col, "Создать коробку", func(): _spawn_item("box"))
	_add_editor_button(col, "Достать бутылку из инвентаря", func(): _take_from_inventory("bottle"))
	_add_editor_button(col, "Достать коробку из инвентаря", func(): _take_from_inventory("box"))
	_add_editor_button(col, "Закрыть", _toggle_items_panel)


func _build_wardrobe_panel(layer: CanvasLayer) -> void:
	wardrobe_panel = PanelContainer.new()
	wardrobe_panel.position = Vector2(500, 140)
	wardrobe_panel.size = Vector2(300, 240)
	wardrobe_panel.visible = false
	layer.add_child(wardrobe_panel)
	var col := VBoxContainer.new()
	wardrobe_panel.add_child(col)
	var title := Label.new()
	title.text = "ШКАФ — ХРАНИЛИЩЕ"
	title.add_theme_font_size_override("font_size", 18)
	col.add_child(title)
	_add_editor_button(col, "Положить предмет в шкаф", _put_held_in_inventory)
	_add_editor_button(col, "Достать бутылку (%d)" % int(inventory.get("bottle", 0)), func(): _take_from_inventory("bottle"))
	_add_editor_button(col, "Достать коробку (%d)" % int(inventory.get("box", 0)), func(): _take_from_inventory("box"))
	_add_editor_button(col, "Закрыть шкаф", func(): wardrobe_panel.hide())

func _interact_wardrobe() -> void:
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 4.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var node: Node = hit.get("collider") as Node
	while node != null:
		if node.name.to_lower().contains("modern wardrobe"):
			wardrobe_panel.visible = true
			items_panel.visible = false
			edit_mode = false
			lighting_mode = false
			editor_panel.hide()
			lighting_panel.hide()
			touch_move = Vector2.ZERO
			return
		node = node.get_parent()

func _toggle_items_panel() -> void:
	items_panel.visible = not items_panel.visible
	if items_panel.visible:
		edit_mode = false
		lighting_mode = false
		lighting_panel.visible = false
		editor_panel.visible = false
		touch_move = Vector2.ZERO
		mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _spawn_item(kind: String, saved_position: Vector3 = Vector3.INF, saved_rotation: Vector3 = Vector3.ZERO) -> RigidBody3D:
	item_serial += 1
	var body := RigidBody3D.new()
	body.name = "%s_%d" % [kind, item_serial]
	body.set_meta("item_kind", kind)
	body.mass = 0.45 if kind == "bottle" else 1.2
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 4
	var shape_node := CollisionShape3D.new()
	if kind == "bottle":
		var shape := CylinderShape3D.new()
		shape.radius = 0.105
		shape.height = 0.48
		shape_node.shape = shape
		var bottle_mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.105
		cylinder.bottom_radius = 0.105
		cylinder.height = 0.48
		bottle_mesh.mesh = cylinder
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.55, 0.72, 0.82)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.22
		bottle_mesh.material_override = mat
		body.add_child(bottle_mesh)
		var neck := MeshInstance3D.new()
		var neck_mesh := CylinderMesh.new()
		neck_mesh.top_radius = 0.045
		neck_mesh.bottom_radius = 0.055
		neck_mesh.height = 0.12
		neck.mesh = neck_mesh
		neck.position.y = 0.29
		neck.material_override = mat
		body.add_child(neck)
		var cap := MeshInstance3D.new()
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.048
		cap_mesh.bottom_radius = 0.048
		cap_mesh.height = 0.035
		cap.mesh = cap_mesh
		cap.position.y = 0.365
		var cap_mat := StandardMaterial3D.new()
		cap_mat.albedo_color = Color(0.12, 0.18, 0.22)
		cap.material_override = cap_mat
		body.add_child(cap)
	else:
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.42, 0.38, 0.34)
		shape_node.shape = shape
		var box_mesh := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		box_mesh.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.36, 0.18)
		mat.roughness = 0.9
		box_mesh.material_override = mat
		body.add_child(box_mesh)
	body.add_child(shape_node)
	add_child(body)
	if saved_position == Vector3.INF:
		body.global_position = camera.global_position + (-camera.global_transform.basis.z * 1.35) + Vector3.UP * 0.05
	else:
		body.global_position = saved_position
	body.rotation = saved_rotation
	return body

func _find_item_in_view() -> RigidBody3D:
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 3.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider: Object = hit.get("collider")
	if collider is RigidBody3D and collider.has_meta("item_kind"):
		return collider as RigidBody3D
	return null

func _toggle_hold_item() -> void:
	if held_item != null and is_instance_valid(held_item):
		held_item.freeze = false
		held_item.sleeping = false
		held_item = null
		_save_item_state()
		return
	var target := _find_item_in_view()
	if target != null:
		held_item = target
		held_item.freeze = true
		held_item.linear_velocity = Vector3.ZERO
		held_item.angular_velocity = Vector3.ZERO

func _put_held_in_inventory() -> void:
	if held_item == null or not is_instance_valid(held_item):
		return
	var kind := str(held_item.get_meta("item_kind", "box"))
	inventory[kind] = int(inventory.get(kind, 0)) + 1
	held_item.queue_free()
	held_item = null
	_save_item_state()

func _take_from_inventory(kind: String) -> void:
	if int(inventory.get(kind, 0)) <= 0:
		return
	inventory[kind] = int(inventory[kind]) - 1
	var body := _spawn_item(kind)
	body.freeze = true
	held_item = body
	_save_item_state()

func _save_item_state() -> void:
	var saved_items: Array[Dictionary] = []
	for child in get_children():
		if child is RigidBody3D and child.has_meta("item_kind"):
			var body := child as RigidBody3D
			saved_items.append({
				"kind": str(body.get_meta("item_kind")),
				"position": [body.global_position.x, body.global_position.y, body.global_position.z],
				"rotation": [body.rotation.x, body.rotation.y, body.rotation.z]
			})
	var data := {"items": saved_items, "inventory": inventory}
	var file := FileAccess.open(item_save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func _load_item_state() -> void:
	if not FileAccess.file_exists(item_save_path):
		return
	var file := FileAccess.open(item_save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	var inv: Variant = data.get("inventory", {})
	if inv is Dictionary:
		inventory["bottle"] = int(inv.get("bottle", 0))
		inventory["box"] = int(inv.get("box", 0))
	var entries: Variant = data.get("items", [])
	if entries is Array:
		for entry in entries:
			if not entry is Dictionary:
				continue
			var pos_data: Array = entry.get("position", [0.0, 0.5, 0.0])
			var rot_data: Array = entry.get("rotation", [0.0, 0.0, 0.0])
			if pos_data.size() >= 3 and rot_data.size() >= 3:
				_spawn_item(str(entry.get("kind", "box")), Vector3(float(pos_data[0]), float(pos_data[1]), float(pos_data[2])), Vector3(float(rot_data[0]), float(rot_data[1]), float(rot_data[2])))

func _add_editor_button(parent: VBoxContainer, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	parent.add_child(button)

func _toggle_editor() -> void:
	edit_mode = not edit_mode
	editor_panel.visible = edit_mode
	touch_move = Vector2.ZERO
	if edit_mode:
		lighting_mode = false
		lighting_panel.visible = false
		items_panel.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
	else:
		selected_object = null

func _select_object(screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var node: Node = hit.get("collider") as Node
	while node != null and node.get_parent() != self:
		node = node.get_parent()
	if node is Node3D and node != player:
		selected_object = node as Node3D
		print("Выбран объект: ", selected_object.name)

func _move_selected(offset: Vector3) -> void:
	if selected_object != null:
		selected_object.position += offset

func _rotate_selected(degrees: float) -> void:
	if selected_object != null:
		selected_object.rotate_y(deg_to_rad(degrees))

func _scale_selected(factor: float) -> void:
	if selected_object != null:
		selected_object.scale *= factor

func _resize_room(dw: float, dh: float, dd: float) -> void:
	room_width = clampf(room_width + dw, 6.0, 20.0)
	room_height = clampf(room_height + dh, 2.4, 6.0)
	room_depth = clampf(room_depth + dd, 6.0, 20.0)
	# Rebuild only the architectural shell; movable furniture remains in place.
	for n in get_children():
		if n is StaticBody3D and (n.name in ["Floor", "Ceiling", "Back wall", "Front wall", "Left wall", "Right wall"]):
			n.queue_free()
	# Wait one frame so old collision nodes are removed before rebuilding.
	call_deferred("_rebuild_room_shell")

func _rebuild_room_shell() -> void:
	_box("Floor", Vector3(room_width, 0.2, room_depth), Vector3(0, -0.1, 0), Color(0.30, 0.27, 0.23))
	_box("Ceiling", Vector3(room_width, 0.2, room_depth), Vector3(0, room_height, 0), Color(0.72, 0.72, 0.68))
	_box("Back wall", Vector3(room_width, room_height, 0.2), Vector3(0, room_height * 0.5 - 0.1, -room_depth * 0.5), Color(0.48, 0.52, 0.56))
	_box("Front wall", Vector3(room_width, room_height, 0.2), Vector3(0, room_height * 0.5 - 0.1, room_depth * 0.5), Color(0.48, 0.52, 0.56))
	_box("Left wall", Vector3(0.2, room_height, room_depth), Vector3(-room_width * 0.5, room_height * 0.5 - 0.1, 0), Color(0.43, 0.47, 0.52))
	_box("Right wall", Vector3(0.2, room_height, room_depth), Vector3(room_width * 0.5, room_height * 0.5 - 0.1, 0), Color(0.43, 0.47, 0.52))
