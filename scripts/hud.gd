extends CanvasLayer

const JoystickScript = preload("res://scripts/joystick.gd")

var game_ref
var ui_root: Control
var menu_layer: Control
var game_layer: Control
var inventory_layer: Control
var menu_panel: PanelContainer
var inventory_panel: PanelContainer
var menu_continue_button: Button
var mode_choice := "survival"
var mode_buttons: Dictionary = {}
var joystick: Control
var status_label: Label
var hint_label: Label
var hotbar_buttons: Array[Button] = []
var action_buttons: Dictionary = {}
var inventory_grid: GridContainer
var recipe_list: VBoxContainer

func setup(game_node) -> void:
	game_ref = game_node
	layer = 10
	ui_root = Control.new()
	ui_root.name = "Interface"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)
	_build_menu()
	_build_game_layer()
	_build_inventory_layer()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _button_style(background: Color, outline: Color, radius: int = 13) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _make_button(caption: String, callback: Callable, dimensions: Vector2 = Vector2(0, 56)) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = dimensions
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#f3f6f8"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#25384b"), Color("#52727e")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#315368"), Color("#73c7bb")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#1b6b6d"), Color("#8fe0d0")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#202a35"), Color("#344552")))
	button.pressed.connect(callback)
	return button

func _make_label(caption: String, font_size: int, color: Color = Color("#edf4f6")) -> Label:
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_menu() -> void:
	menu_layer = Control.new()
	menu_layer.name = "MainMenu"
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(menu_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.07, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(shade)

	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _button_style(Color("#111e2d"), Color("#5c8c92"), 24))
	menu_layer.add_child(menu_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_panel.add_child(content)

	var eyebrow := _make_label("ОРИГИНАЛЬНЫЙ ВОКСЕЛЬНЫЙ МИР", 13, Color("#85c9c5"))
	content.add_child(eyebrow)

	var title := _make_label("BLOCKBOUND", 43, Color("#f6fbff"))
	title.add_theme_color_override("font_shadow_color", Color(0.2, 0.8, 0.75, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(title)

	var subtitle := _make_label("Исследуй. Строй. Выживай.", 19, Color("#b8cbd3"))
	content.add_child(subtitle)

	var separator := HSeparator.new()
	separator.modulate = Color("#477079")
	content.add_child(separator)

	content.add_child(_make_label("РЕЖИМ ИГРЫ", 13, Color("#8eaab6")))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	content.add_child(mode_row)

	var survival_button := _make_button("ВЫЖИВАНИЕ", func(): _set_mode_choice("survival"), Vector2(0, 50))
	var creative_button := _make_button("ТВОРЧЕСТВО", func(): _set_mode_choice("creative"), Vector2(0, 50))
	survival_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creative_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(survival_button)
	mode_row.add_child(creative_button)
	mode_buttons["survival"] = survival_button
	mode_buttons["creative"] = creative_button
	_set_mode_choice("survival")

	var new_button := _make_button("НОВЫЙ МИР", func(): game_ref.start_new_world(mode_choice), Vector2(0, 62))
	new_button.add_theme_font_size_override("font_size", 22)
	new_button.add_theme_stylebox_override("normal", _button_style(Color("#176e70"), Color("#7de1d0"), 16))
	new_button.add_theme_stylebox_override("hover", _button_style(Color("#218c86"), Color("#a5f2df"), 16))
	content.add_child(new_button)

	menu_continue_button = _make_button("ПРОДОЛЖИТЬ", func(): game_ref.continue_world(), Vector2(0, 52))
	content.add_child(menu_continue_button)

	content.add_child(_make_label("Мобильная версия • Godot Engine", 12, Color("#78929f")))

func _set_mode_choice(value: String) -> void:
	mode_choice = value
	for mode_key in mode_buttons.keys():
		var button: Button = mode_buttons[mode_key]
		if str(mode_key) == mode_choice:
			button.add_theme_stylebox_override("normal", _button_style(Color("#1b666c"), Color("#91e4d8")))
		else:
			button.add_theme_stylebox_override("normal", _button_style(Color("#25384b"), Color("#52727e")))

func _build_game_layer() -> void:
	game_layer = Control.new()
	game_layer.name = "GameHUD"
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_layer.visible = false
	ui_root.add_child(game_layer)

	var top_left := PanelContainer.new()
	top_left.position = Vector2(18, 16)
	top_left.add_theme_stylebox_override("panel", _button_style(Color(0.035, 0.08, 0.12, 0.72), Color(0.36, 0.62, 0.68, 0.55), 10))
	game_layer.add_child(top_left)
	var top_text := _make_label("BLOCKBOUND  •  WILDS", 16, Color("#d9f2ef"))
	top_left.add_child(top_text)

	status_label = _make_label("HP 10/10   •   ВЫЖИВАНИЕ", 16, Color("#f1f6f7"))
	status_label.position = Vector2(0, 17)
	status_label.size = Vector2(390, 34)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	game_layer.add_child(status_label)

	hint_label = _make_label("WASD / джойстик — движение  •  правая сторона — обзор", 12, Color("#c3d3da"))
	hint_label.position = Vector2(0, 52)
	hint_label.size = Vector2(500, 25)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	game_layer.add_child(hint_label)

	var reticle := _make_label("+", 28, Color(1, 1, 1, 0.85))
	reticle.position = Vector2(0, 0)
	reticle.size = Vector2(40, 40)
	reticle.name = "Reticle"
	game_layer.add_child(reticle)

	joystick = JoystickScript.new()
	joystick.name = "MovementJoystick"
	game_layer.add_child(joystick)
	joystick.vector_changed.connect(func(value: Vector2): game_ref.player.set_move_input(value))

	var jump_button := _make_button("ПРЫЖОК", func(): game_ref.player.jump(), Vector2(96, 62))
	var bag_button := _make_button("СУМКА", func(): toggle_inventory(), Vector2(96, 52))
	var hit_button := _make_button("УДАР", func(): game_ref.try_attack(), Vector2(96, 52))
	var mine_button := _make_button("КОПАТЬ", func(): game_ref.try_break_block(), Vector2(96, 52))
	var place_button := _make_button("СТРОИТЬ", func(): game_ref.place_selected_block(), Vector2(96, 52))
	action_buttons = {
		"jump": jump_button,
		"bag": bag_button,
		"hit": hit_button,
		"mine": mine_button,
		"place": place_button
	}
	for button in action_buttons.values():
		game_layer.add_child(button)

	var hotbar := HBoxContainer.new()
	hotbar.name = "Hotbar"
	hotbar.add_theme_constant_override("separation", 3)
	hotbar.mouse_filter = Control.MOUSE_FILTER_PASS
	game_layer.add_child(hotbar)
	for index in range(8):
		var slot_index := index
		var slot := _make_button("—", func(): game_ref.select_hotbar_slot(slot_index), Vector2(62, 52))
		slot.add_theme_font_size_override("font_size", 13)
		hotbar_buttons.append(slot)
		hotbar.add_child(slot)

func _build_inventory_layer() -> void:
	inventory_layer = Control.new()
	inventory_layer.name = "InventoryOverlay"
	inventory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_layer.visible = false
	ui_root.add_child(inventory_layer)

	var background := ColorRect.new()
	background.color = Color(0.012, 0.022, 0.035, 0.82)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_layer.add_child(background)

	inventory_panel = PanelContainer.new()
	inventory_panel.add_theme_stylebox_override("panel", _button_style(Color("#142235"), Color("#5e8a92"), 20))
	inventory_layer.add_child(inventory_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	inventory_panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _make_label("РЮКЗАК И КРАФТ", 23, Color("#eaf6f5"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)
	var close_button := _make_button("ЗАКРЫТЬ", func(): toggle_inventory(), Vector2(116, 44))
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	inner.add_child(_make_label("ПРЕДМЕТЫ", 14, Color("#8dc9c1")))
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 4
	inventory_grid.add_theme_constant_override("h_separation", 7)
	inventory_grid.add_theme_constant_override("v_separation", 7)
	inner.add_child(inventory_grid)

	inner.add_child(_make_label("БЫСТРЫЙ КРАФТ", 14, Color("#8dc9c1")))
	recipe_list = VBoxContainer.new()
	recipe_list.add_theme_constant_override("separation", 6)
	inner.add_child(recipe_list)

func _layout() -> void:
	if ui_root == null:
		return
	var view_size := get_viewport().get_visible_rect().size
	var w := view_size.x
	var h := view_size.y
	if menu_panel:
		var panel_width := minf(480.0, w - 32.0)
		var panel_height := minf(500.0, h - 28.0)
		menu_panel.position = Vector2((w - panel_width) * 0.5, (h - panel_height) * 0.5)
		menu_panel.size = Vector2(panel_width, panel_height)
	if inventory_panel:
		var inv_width := minf(920.0, w - 28.0)
		var inv_height := minf(600.0, h - 28.0)
		inventory_panel.position = Vector2((w - inv_width) * 0.5, (h - inv_height) * 0.5)
		inventory_panel.size = Vector2(inv_width, inv_height)
	if status_label:
		status_label.position = Vector2(w - 410, 15)
	if hint_label:
		hint_label.position = Vector2(w - 520, 48)
	var reticle: Control = game_layer.get_node_or_null("Reticle")
	if reticle:
		reticle.position = Vector2(w * 0.5 - 20, h * 0.5 - 20)
	if joystick:
		joystick.position = Vector2(28, h - 188)
		joystick.size = Vector2(156, 156)
	var placements := {
		"jump": Vector2(w - 124, h - 320),
		"bag": Vector2(w - 124, h - 245),
		"hit": Vector2(w - 232, h - 170),
		"mine": Vector2(w - 232, h - 92),
		"place": Vector2(w - 124, h - 92)
	}
	for key in placements.keys():
		var button: Button = action_buttons.get(key)
		if button:
			button.position = placements[key]
	var hotbar: HBoxContainer = game_layer.get_node_or_null("Hotbar")
	if hotbar:
		var total_width := 8.0 * 65.0
		hotbar.position = Vector2((w - total_width) * 0.5, h - 68)
		hotbar.size = Vector2(total_width, 56)
		for slot in hotbar_buttons:
			slot.custom_minimum_size = Vector2(62, 52)

func show_menu(can_continue: bool) -> void:
	menu_layer.visible = true
	game_layer.visible = false
	inventory_layer.visible = false
	menu_continue_button.disabled = not can_continue
	if game_ref and game_ref.player:
		game_ref.player.set_controls_enabled(false)
		game_ref.player.visible = false
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_game() -> void:
	menu_layer.visible = false
	game_layer.visible = true
	inventory_layer.visible = false
	if game_ref and game_ref.player:
		game_ref.player.visible = true
		game_ref.player.set_controls_enabled(true)
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	refresh_hud()

func toggle_inventory() -> void:
	if not game_layer.visible:
		return
	inventory_layer.visible = not inventory_layer.visible
	if game_ref and game_ref.player:
		game_ref.player.set_controls_enabled(not inventory_layer.visible)
	if inventory_layer.visible:
		refresh_inventory()
		if not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if not DisplayServer.is_touchscreen_available():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_hud() -> void:
	if not game_ref:
		return
	if status_label:
		var mode_text := "ТВОРЧЕСТВО" if game_ref.mode == "creative" else "ВЫЖИВАНИЕ"
		var health_text := "∞" if game_ref.mode == "creative" else str(game_ref.health)
		status_label.text = "♥ %s/10   •   %s" % [health_text, mode_text]
	for index in range(hotbar_buttons.size()):
		var item_id := str(game_ref.hotbar[index])
		var count := game_ref.get_item_count(item_id)
		var short_name := game_ref.get_item_short_name(item_id)
		var quantity := "∞" if game_ref.mode == "creative" and game_ref.is_placeable(item_id) else str(count)
		hotbar_buttons[index].text = "%s\n%s" % [short_name, quantity]
		if index == game_ref.selected_slot:
			hotbar_buttons[index].add_theme_stylebox_override("normal", _button_style(Color("#176e70"), Color("#a2f1df"), 8))
		else:
			hotbar_buttons[index].add_theme_stylebox_override("normal", _button_style(Color("#152536"), Color("#59747f"), 8))

func refresh_inventory() -> void:
	if not game_ref or not inventory_grid or not recipe_list:
		return
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()

	var inventory_items: Array = game_ref.inventory.keys()
	inventory_items.sort()
	for item_id in inventory_items:
		var count := game_ref.get_item_count(str(item_id))
		if count <= 0:
			continue
		var item_name := str(item_id)
		var card := _make_button("%s\n× %d" % [game_ref.get_item_title(item_name), count], game_ref.assign_hotbar_item.bind(item_name), Vector2(0, 58))
		card.add_theme_font_size_override("font_size", 14)
		card.disabled = not game_ref.is_placeable(item_name)
		inventory_grid.add_child(card)

	for recipe in game_ref.get_recipes():
		var recipe_id := str(recipe["id"])
		var craft_button := _make_button(game_ref.get_recipe_description(recipe), game_ref.craft_recipe.bind(recipe_id), Vector2(0, 44))
		craft_button.disabled = not game_ref.can_craft(recipe)
		craft_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_list.add_child(craft_button)
	refresh_hud()
