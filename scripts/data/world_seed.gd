class_name WorldSeed
extends RefCounted
## Static starting content for the offline prototype. A server would send this.

const MAP_SIZE := 1600.0  # meters, square, centered on origin

static func players() -> Array[PlayerData]:
	var list: Array[PlayerData] = []
	list.append(_p("p_local", "House Al-Nasr", "a_crescent", Color(0.15, 0.35, 0.85), true))
	list.append(_p("p_red", "Kingdom of Varn", "a_iron", Color(0.8, 0.12, 0.1), false))
	list.append(_p("p_green", "Greenmarch League", "a_crescent", Color(0.2, 0.6, 0.25), false))
	list.append(_p("p_gold", "Sunspire Dominion", "a_iron", Color(0.9, 0.7, 0.15), false))
	return list


static func locations() -> Array[LocationData]:
	var K := LocationData.Kind
	var list: Array[LocationData] = []
	list.append(_l("c_home", "Glory Keep", K.CASTLE, Vector2(-120, 260), "p_local", 3, 900, "Your seat of power. Upgrade it to unlock more march slots and research."))
	list.append(_l("c_varn", "Varnhold", K.CASTLE, Vector2(420, -380), "p_red", 4, 1400, "Fortified capital of the Kingdom of Varn."))
	list.append(_l("c_green", "Oakheart Castle", K.CASTLE, Vector2(-520, -300), "p_green", 3, 1000, "Allied castle of the Greenmarch League."))
	list.append(_l("c_gold", "Sunspire", K.CASTLE, Vector2(520, 420), "p_gold", 5, 1800, "Golden citadel overlooking the southern plains."))
	list.append(_l("city_1", "Port Meridian", K.CITY, Vector2(80, -40), "", 3, 600, "Wealthy trade city. Capture it for gold income."))
	list.append(_l("city_2", "Ironvale", K.CITY, Vector2(-380, 80), "", 2, 450, "Mining city rich in iron and stone."))
	list.append(_l("fort_1", "Ravenwatch", K.FORTRESS, Vector2(180, -520), "p_red", 2, 700, "Border fortress guarding the northern pass."))
	list.append(_l("fort_2", "Stonegate", K.FORTRESS, Vector2(-80, 560), "", 2, 500, "Abandoned fortress on the southern road."))
	list.append(_l("v_1", "Millbrook", K.VILLAGE, Vector2(-260, 360), "p_local", 1, 80, "Farming village. Produces food."))
	list.append(_l("v_2", "Ashford", K.VILLAGE, Vector2(60, 300), "", 1, 60, "Woodcutters' village."))
	list.append(_l("v_3", "Thornby", K.VILLAGE, Vector2(300, 120), "", 1, 70, "Quiet village near the river."))
	list.append(_l("v_4", "Elmsworth", K.VILLAGE, Vector2(-600, 300), "", 1, 50, "Remote hamlet in the western hills."))
	list.append(_l("v_5", "Dunmere", K.VILLAGE, Vector2(640, -60), "", 1, 90, "Fishing village on the eastern coast."))
	list.append(_l("bf_1", "Field of Crowns", K.BATTLEFIELD, Vector2(220, -200), "", 1, 0, "Contested battlefield. Alliances clash here during war events."))
	return list


static func _p(id: String, n: String, ally: String, col: Color, local: bool) -> PlayerData:
	var p := PlayerData.new()
	p.id = id; p.display_name = n; p.alliance_id = ally; p.banner_color = col; p.is_local = local
	return p


static func _l(id: String, n: String, k: int, pos: Vector2, owner: String, lvl: int, gar: int, desc: String) -> LocationData:
	var l := LocationData.new()
	l.id = id; l.display_name = n; l.kind = k; l.map_position = pos; l.owner_id = owner
	l.level = lvl; l.garrison = gar; l.description = desc
	return l
