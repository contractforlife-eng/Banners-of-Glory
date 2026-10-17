class_name GameHUD
extends CanvasLayer
## Game interface: resource bar, location / army info panel, toasts, help,
## and the bottom-right minimap with the World Map (overview) button.

signal overview_requested
signal minimap_clicked(world_pos: Vector3)
signal upgrade_requested(loc: LocationData)
signal march_requested(loc: LocationData)

const RES_ORDER := ["gold", "food", "wood", "stone", "iron"]
const RES_COLORS := {"gold": Color(1, 0.82, 0.3), "food": Color(0.9, 0.6, 0.35), "wood": Color(0.75, 0.55, 0.35), "stone": Color(0.8, 0.8, 0.85), "iron": Color(0.6, 0.7, 0.85)}

var state: GameState
var minimap: Minimap
var _res_labels := {}
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _body: Label
var _btn_upgrade: Button
var _btn_march: Button
var _toast: Label
var _toast_t := 0.0
var _loc: LocationData


func setup(s: GameState, world: WorldBuilder, cam: StrategyCamera) -> void:
	state = s
	_build_top_bar()
	_build_panel()
	_build_minimap(world, cam)
	_build_help()
	state.resources_changed.connect(func(_id): _refresh_resources())
	state.location_changed.connect(_on_location_changed)
	state.command_rejected.connect(func(r): toast(r, Color(1, 0.5, 0.4)))
	_refresh_resources()


func _on_location_changed(l: LocationData) -> void:
	if l == _loc:
		show_location(l)


func _style(alpha := 0.82) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.05, alpha)
	sb.border_color = Color(0.75, 0.58, 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	return sb


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _style())
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 48
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	bar.add_child(row)
	var title := Label.new()
	title.text = "BANNERS OF GLORY  |  رايات المجد"
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Tahoma", "Arial", "Noto Sans Arabic"])
	title.add_theme_font_override("font", f)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	for r in RES_ORDER:
		var l := Label.new()
		l.add_theme_color_override("font_color", RES_COLORS[r])
		l.add_theme_font_size_override("font_size", 17)
		row.add_child(l)
		_res_labels[r] = l


func _refresh_resources() -> void:
	var res := state.local_player().resources
	for r in RES_ORDER:
		_res_labels[r].text = "%s %d" % [r.capitalize(), res.get(r, 0)]


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(0.88))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -340
	_panel.offset_top = 64
	_panel.offset_right = -12
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1, 0.86, 0.5))
	v.add_child(_title)
	_sub = Label.new()
	_sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	v.add_child(_sub)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 300
	v.add_child(_body)
	var row := HBoxContainer.new()
	v.add_child(row)
	_btn_upgrade = Button.new()
	_btn_upgrade.text = "Upgrade"
	_btn_upgrade.pressed.connect(func(): upgrade_requested.emit(_loc))
	row.add_child(_btn_upgrade)
	_btn_march = Button.new()
	_btn_march.text = "March Hero Here"
	_btn_march.pressed.connect(func(): march_requested.emit(_loc))
	row.add_child(_btn_march)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide_panel)
	row.add_child(close)


func show_location(loc: LocationData) -> void:
	_loc = loc
	var o := state.owner_of(loc)
	var mine := loc.owner_id == state.local_player_id
	_title.text = loc.display_name
	var rel := "Your holding" if mine else ("Allied" if state.is_allied(loc) else ("Neutral" if o == null else "Hostile"))
	_sub.text = "%s  -  Level %d  -  %s" % [loc.kind_name(), loc.level, rel]
	var prod := []
	for k in loc.production:
		if loc.production[k] > 0:
			prod.append("%s +%d" % [k.capitalize(), loc.production[k] * loc.level])
	var lines := [
		"Ruler: %s" % (o.display_name if o else "None"),
		"Alliance: %s" % (o.alliance_id.trim_prefix("a_").capitalize() if o else "-"),
		"Garrison: %d troops" % loc.garrison,
		"Production / tick: %s" % ", ".join(PackedStringArray(prod)),
		"",
		loc.description,
	]
	if mine:
		var cost := state.upgrade_cost(loc)
		lines.append("\nUpgrade cost: %d gold, %d wood, %d stone" % [cost.gold, cost.wood, cost.stone])
	_body.text = "\n".join(PackedStringArray(lines))
	_btn_upgrade.visible = mine
	_btn_march.visible = true
	_btn_march.text = "Reinforce" if mine or state.is_allied(loc) else "Attack / Capture"
	_panel.visible = true


func show_army(army: Army) -> void:
	_loc = null
	_title.text = army.hero_name
	_sub.text = "Hero Army  -  %s" % ("Yours" if army.owner_id == state.local_player_id else "Enemy")
	_body.text = "Troops: %d (spearmen + knight)\nSpeed: %d\n\nRight-click the map to march.\nMarch onto a location to capture it when your strength beats its garrison." % [army.strength, army.speed]
	_btn_upgrade.visible = false
	_btn_march.visible = false
	_panel.visible = true


func hide_panel() -> void:
	_panel.visible = false
	_loc = null


func _build_minimap(world: WorldBuilder, cam: StrategyCamera) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _style(0.9))
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -244
	box.offset_top = -282
	box.offset_right = -12
	box.offset_bottom = -12
	add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	var btn := Button.new()
	btn.text = "World Map (Overview)"
	btn.pressed.connect(func(): overview_requested.emit())
	v.add_child(btn)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(212, 212)
	minimap.setup(world, cam, state)
	minimap.map_clicked.connect(func(p): minimap_clicked.emit(p))
	v.add_child(minimap)


func _build_help() -> void:
	var l := Label.new()
	l.text = "Left-click: select / zoom in   Drag: pan   Wheel: zoom   WASD: pan\nRight-click: march selected army   Space / minimap button: world overview   Esc: deselect"
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	l.offset_left = 14
	l.offset_top = -56
	l.offset_bottom = -10
	l.offset_right = 760
	add_child(l)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 70
	_toast.offset_left = -400
	_toast.offset_right = 400
	add_child(_toast)


func toast(text: String, col := Color(1, 0.9, 0.5)) -> void:
	_toast.text = text
	_toast.modulate = col
	_toast_t = 3.0


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)


func is_over_ui(pos: Vector2) -> bool:
	for c: Control in [_panel, minimap.get_parent()]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	return pos.y < 50.0
