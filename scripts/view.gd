class_name SceneView
extends Control
## Draws every scene (shop, forge, guild, street, title, ending) on a 160x100 virtual pixel canvas,
## plus particles, screen shake and floating text. Mouse/touch presses are forwarded as signals.

signal press_down
signal press_up

const VW := 160.0
const VH := 100.0

var mode := "title"
var sim: ForgeSim = null
var customer: Dictionary = {}
var cust_t := 0.0
var bubble := ""
var t := 0.0
var parts: Array = []
var floats: Array = []
var shake := 0.0
var hammer_t := 0.0
var ending := {}
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			press_down.emit()
		else:
			press_up.emit()
		accept_event()

func set_customer(c: Dictionary) -> void:
	customer = c
	cust_t = 0.0

func _process(dt: float) -> void:
	t += dt
	cust_t += dt
	hammer_t = maxf(0.0, hammer_t - dt * 3.5)
	shake = maxf(0.0, shake - dt * 24.0)
	for p in parts:
		p["p"] += p["v"] * dt
		p["v"].y += float(p["g"]) * dt
		p["life"] -= dt
	parts = parts.filter(func(p): return p["life"] > 0.0)
	for f in floats:
		f["life"] -= dt
		f["p"].y -= 9.0 * dt
	floats = floats.filter(func(f): return f["life"] > 0.0)
	if (mode == "title" or mode == "forge") and randf() < dt * 14.0:
		var src := Vector2(31, 50) if mode == "forge" else Vector2(124, 8)
		var heat := sim.heat if sim else 0.5
		if mode == "title" or randf() < 0.3 + heat:
			parts.append({"p": src + Vector2(randf_range(-8, 8), 0), "v": Vector2(randf_range(-6, 6), randf_range(-26, -12)),
				"g": 4.0, "life": randf_range(0.6, 1.4), "col": Color(1, randf_range(0.5, 0.9), 0.2), "sz": 1.0})
	queue_redraw()

# ---------------------------------------------------------------- effects API
func sparks(at: Vector2, n: int, col: Color = Color(1, 0.8, 0.3), spd: float = 60.0) -> void:
	for i in n:
		var a := randf_range(PI * 1.05, PI * 1.95)
		parts.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(spd * 0.3, spd), "g": 90.0,
			"life": randf_range(0.25, 0.7), "col": col.lerp(Color.WHITE, randf() * 0.4), "sz": randf_range(0.8, 1.6)})

func steam(at: Vector2, n: int) -> void:
	for i in n:
		parts.append({"p": at + Vector2(randf_range(-10, 10), 0), "v": Vector2(randf_range(-8, 8), randf_range(-30, -10)),
			"g": -6.0, "life": randf_range(0.6, 1.4), "col": Color(0.85, 0.88, 0.92, 0.7), "sz": randf_range(2.0, 4.0)})

func coins(at: Vector2, n: int) -> void:
	for i in n:
		parts.append({"p": at, "v": Vector2(randf_range(-30, 30), randf_range(-55, -25)), "g": 120.0,
			"life": randf_range(0.5, 0.9), "col": Color(1, 0.82, 0.25), "sz": 2.0})

func float_text(txt: String, at: Vector2, col: Color = Color(1, 0.9, 0.5)) -> void:
	floats.append({"text": txt, "p": at, "life": 1.4, "col": col})

func bump(amount: float) -> void:
	shake = maxf(shake, amount)

# ---------------------------------------------------------------- helpers
func _s() -> float:
	return minf(size.x / VW, size.y / VH)

func _o() -> Vector2:
	return (size - Vector2(VW, VH) * _s()) * 0.5

func to_screen(v: Vector2) -> Vector2:
	return _o() + v * _s()

func _tex(tx: Texture2D, pos: Vector2, sc: float = 1.0) -> void:
	draw_texture_rect(tx, Rect2(pos, tx.get_size() * sc), false)

func _text(txt: String, vpos: Vector2, vsize: float, col: Color, center: bool = true, outline: int = 4) -> void:
	var fs := maxi(8, int(vsize * _s()))
	var sp := to_screen(vpos)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if center:
		sp.x -= w * 0.5
	draw_string_outline(font, sp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0.08, 0.05, 0.04))
	draw_string(font, sp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _bricks(col: Color, top: float, bottom: float) -> void:
	var dk := col.darkened(0.25)
	var y := top
	var row := 0
	while y < bottom:
		draw_line(Vector2(-60, y), Vector2(220, y), dk, 0.5)
		var off := 0.0 if row % 2 == 0 else 6.0
		var x := -60.0 + off
		while x < 220:
			draw_line(Vector2(x, y), Vector2(x, y + 6), dk, 0.5)
			x += 12.0
		y += 6.0
		row += 1

func _fire(base: Vector2, w: float, inten: float) -> void:
	draw_circle(base + Vector2(0, -6), 26.0 * inten + 6.0, Color(1, 0.5, 0.15, 0.10))
	for i in 7:
		var x := base.x - w * 0.5 + (i + 0.5) * w / 7.0
		var hgt := (5.0 + 9.0 * inten) * (0.65 + 0.35 * sin(t * (7.0 + i * 1.3) + i * 2.1))
		var col := Color(1, 0.35 + 0.1 * (i % 3), 0.08)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, base.y), Vector2(x + 3, base.y), Vector2(x, base.y - hgt)]), col)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1.6, base.y), Vector2(x + 1.6, base.y), Vector2(x, base.y - hgt * 0.6)]), Color(1, 0.85, 0.3))

# ---------------------------------------------------------------- draw
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.06, 0.06))
	var s := _s()
	var o := _o() + Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) * s * 0.5
	draw_set_transform(o, 0.0, Vector2(s, s))
	match mode:
		"forge": _draw_forge()
		"guild": _draw_guild()
		"street", "title": _draw_street()
		"ending": _draw_ending()
		_: _draw_shop()
	for p in parts:
		var c: Color = p["col"]
		c.a *= clampf(float(p["life"]) * 2.0, 0.0, 1.0)
		var sz: float = p["sz"]
		draw_rect(Rect2(p["p"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_overlay_text()
	for f in floats:
		var c: Color = f["col"]
		c.a = clampf(float(f["life"]), 0.0, 1.0)
		_text(f["text"], f["p"], 7.0, c)

func _draw_shop() -> void:
	var hrs := float(Game.hours) / Game.DAY_HOURS
	draw_rect(Rect2(-400, -400, 960, 470), Color(0.27, 0.19, 0.16))
	_bricks(Color(0.27, 0.19, 0.16), -30, 70)
	# window with sky that warms toward evening
	var sky := Color(0.45, 0.68, 0.9).lerp(Color(0.95, 0.5, 0.3), 1.0 - hrs)
	draw_rect(Rect2(10, 12, 28, 22), Color(0.18, 0.12, 0.08))
	draw_rect(Rect2(12, 14, 24, 18), sky)
	draw_circle(Vector2(16 + 16 * (1.0 - hrs), 20 + 8 * (1.0 - hrs)), 3, Color(1, 0.95, 0.7))
	draw_line(Vector2(24, 14), Vector2(24, 32), Color(0.18, 0.12, 0.08), 1.5)
	draw_line(Vector2(12, 23), Vector2(36, 23), Color(0.18, 0.12, 0.08), 1.5)
	# shelves with your stock
	for sy in [30.0, 48.0]:
		draw_rect(Rect2(46, sy, 68, 2.5), Color(0.45, 0.3, 0.17))
		draw_rect(Rect2(48, sy + 2.5, 2, 3), Color(0.3, 0.2, 0.12))
		draw_rect(Rect2(110, sy + 2.5, 2, 3), Color(0.3, 0.2, 0.12))
	var shown := 0
	for w in Game.weapons:
		if shown >= 8:
			break
		var x := 49.0 + (shown % 4) * 16.0
		var y := 16.0 + (shown / 4) * 18.0
		_tex(Pix.weapon(w["type"], w["ore"], w["mat"], w.get("gem", "")), Vector2(x, y), 0.9)
		shown += 1
	# the forge in the corner
	draw_rect(Rect2(130, -10, 18, 38), Color(0.32, 0.3, 0.3))
	draw_rect(Rect2(122, 26, 36, 44), Color(0.4, 0.37, 0.36))
	_bricks(Color(0.4, 0.37, 0.36), 26, 26)
	draw_rect(Rect2(127, 42, 26, 18), Color(0.08, 0.04, 0.03))
	_fire(Vector2(140, 60), 22, 0.6)
	draw_rect(Rect2(120, 24, 40, 3), Color(0.3, 0.28, 0.28))
	# floor
	draw_rect(Rect2(-400, 70, 960, 400), Color(0.36, 0.24, 0.14))
	for i in 12:
		draw_line(Vector2(-60, 70 + i * 7), Vector2(220, 70 + i * 7), Color(0.28, 0.18, 0.1), 0.6)
		draw_line(Vector2(-40 + (i * 37) % 200, 70 + i * 7), Vector2(-40 + (i * 37) % 200, 77 + i * 7), Color(0.28, 0.18, 0.1), 0.6)
	# smith behind the counter
	var bob := sin(t * 2.0) * 0.5
	_tex(Pix.smith(), Vector2(66, 40 + bob), 1.3)
	draw_rect(Rect2(30, 62, 84, 12), Color(0.48, 0.31, 0.17))
	draw_rect(Rect2(28, 60, 88, 3), Color(0.62, 0.42, 0.24))
	draw_rect(Rect2(34, 65, 76, 1), Color(0.38, 0.24, 0.13))
	_tex(Pix.anvil(), Vector2(124, 78), 1.5)
	# customer slides in
	if not customer.is_empty():
		var k := clampf(cust_t / 0.6, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		var x := lerpf(175.0, 86.0, k)
		var hop := absf(sin(cust_t * 10.0)) * 1.5 if k < 1.0 else 0.0
		_tex(Pix.person(int(customer["seed"])), Vector2(x, 60 - hop), 1.7)

func _draw_forge() -> void:
	var heat := sim.heat if sim else 0.3
	var phase := sim.phase if sim else "heat"
	draw_rect(Rect2(-400, -400, 960, 480), Color(0.17, 0.11, 0.1))
	_bricks(Color(0.17, 0.11, 0.1), -30, 80)
	draw_circle(Vector2(31, 56), 60, Color(1, 0.45, 0.15, 0.05 + 0.08 * heat))
	draw_rect(Rect2(-400, 80, 960, 400), Color(0.22, 0.15, 0.1))
	# hearth
	draw_rect(Rect2(14, -10, 34, 40), Color(0.33, 0.3, 0.3))
	draw_rect(Rect2(6, 30, 52, 50), Color(0.4, 0.36, 0.35))
	draw_rect(Rect2(12, 44, 40, 22), Color(0.07, 0.03, 0.02))
	var flare := 0.25 if (sim and sim.pumping) else 0.0
	_fire(Vector2(32, 66), 36, clampf(0.35 + heat * 0.6 + flare, 0.0, 1.3))
	draw_rect(Rect2(10, 66, 44, 4), Color(0.25, 0.22, 0.22))
	# bellows
	var squash := 0.0
	if sim and sim.pumping:
		squash = 2.5 + 2.5 * sin(t * 14.0)
	var by := 70.0
	draw_colored_polygon(PackedVector2Array([Vector2(58, by), Vector2(76, by - 9 + squash), Vector2(76, by + 7 - squash * 0.3), Vector2(58, by + 3)]), Color(0.45, 0.28, 0.16))
	draw_line(Vector2(58, by + 1.5), Vector2(52, by), Color(0.3, 0.3, 0.32), 2)
	draw_line(Vector2(76, by - 9 + squash), Vector2(82, by - 13 + squash), Color(0.5, 0.35, 0.2), 1.5)
	# anvil + barrel
	_tex(Pix.anvil(), Vector2(84, 64), 2.0)
	draw_rect(Rect2(126, 60, 26, 24), Color(0.42, 0.27, 0.14))
	draw_rect(Rect2(126, 64, 26, 2), Color(0.25, 0.25, 0.28))
	draw_rect(Rect2(126, 76, 26, 2), Color(0.25, 0.25, 0.28))
	draw_rect(Rect2(128, 59, 22, 3), Color(0.25, 0.45, 0.7))
	# the glowing work-piece
	var mc := Pix.heat_col(heat)
	var bar_pos := Vector2(20, 60)
	if phase == "hammer":
		bar_pos = Vector2(92, 60)
	elif phase == "quench":
		bar_pos = Vector2(127, 50 + (1.0 - sim.needle) * 3.0)
	elif phase == "done":
		bar_pos = Vector2(127, 54)
		mc = Pix.heat_col(0.1)
	if phase != "heat":
		draw_circle(bar_pos + Vector2(12, 2), 8, Color(mc.r, mc.g, mc.b, 0.25 * heat))
	_tex(Pix.bar(mc), bar_pos, 2.0)
	# hammer
	if phase == "hammer":
		var a := lerpf(-0.6, 0.785, hammer_t)
		var piv := Vector2(128, 36)
		var dir := Vector2(-cos(a), sin(a))
		var head := piv + dir * 30.0
		draw_line(piv, head, Color(0.55, 0.38, 0.2), 2.5)
		var n := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([head + n * 5 + dir * 2, head - n * 5 + dir * 2, head - n * 5 - dir * 4, head + n * 5 - dir * 4]), Color(0.35, 0.36, 0.4))
	if not sim:
		return
	# heat gauge
	if phase == "heat" or phase == "hammer":
		var gx := 2.0
		var gy := 8.0
		var gh := 70.0
		draw_rect(Rect2(gx - 1, gy - 1, 8, gh + 2), Color(0.05, 0.03, 0.03))
		for i in 35:
			var hv := float(i) / 35.0 * 1.08
			draw_rect(Rect2(gx, gy + gh - (i + 1) * gh / 35.0, 6, gh / 35.0 + 0.2), Pix.heat_col(hv))
		var tg := float(sim.p["target"])
		var bd := float(sim.p["band"])
		var y1 := gy + gh - (tg + bd * 0.5) / 1.08 * gh
		var y2 := gy + gh - (tg - bd * 0.5) / 1.08 * gh
		var pulse := 0.6 + 0.4 * sin(t * 6.0)
		draw_rect(Rect2(gx - 1.5, y1, 9, y2 - y1), Color(0.3, 1, 0.4, pulse), false, 1.0)
		var hy := gy + gh - heat / 1.08 * gh
		draw_colored_polygon(PackedVector2Array([Vector2(gx + 7, hy), Vector2(gx + 12, hy - 3), Vector2(gx + 12, hy + 3)]), Color.WHITE)
	# hammer timing bar
	if phase == "hammer":
		var hx := 62.0
		var hw := 76.0
		var hy2 := 10.0
		draw_rect(Rect2(hx - 1, hy2 - 1, hw + 2, 9), Color(0.05, 0.03, 0.03))
		draw_rect(Rect2(hx, hy2, hw, 7), Color(0.3, 0.2, 0.18))
		var sw := float(sim.p["sweet"])
		draw_rect(Rect2(hx + (0.5 - sw * 2.3) * hw, hy2, sw * 4.6 * hw, 7), Color(0.55, 0.45, 0.2))
		draw_rect(Rect2(hx + (0.5 - sw) * hw, hy2, sw * 2.0 * hw, 7), Color(0.3, 0.75, 0.3))
		draw_rect(Rect2(hx + (0.5 - sw * 0.45) * hw, hy2, sw * 0.9 * hw, 7), Color(0.75, 1, 0.5))
		var mx := hx + sim.marker * hw
		draw_rect(Rect2(mx - 1, hy2 - 2.5, 2, 12), Color.WHITE)
		var need := int(sim.p["strikes"])
		for i in need:
			var c := Color(0.25, 0.2, 0.2)
			if i < sim.strikes.size():
				var q := float(sim.strikes[i])
				c = Color(0.75, 1, 0.5) if q >= 1.0 else (Color(0.3, 0.75, 0.3) if q >= 0.8 else (Color(0.85, 0.65, 0.2) if q >= 0.4 else Color(0.8, 0.25, 0.2)))
			draw_rect(Rect2(hx + hw * 0.5 - need * 3.5 + i * 7, hy2 + 11, 5, 4), c)
	# quench gauge
	if phase == "quench":
		var qx := 154.0
		var qy := 14.0
		var qh := 60.0
		draw_rect(Rect2(qx - 1, qy - 1, 6, qh + 2), Color(0.05, 0.03, 0.03))
		for i in 30:
			draw_rect(Rect2(qx, qy + i * qh / 30.0, 4, qh / 30.0 + 0.2), Pix.heat_col(1.0 - float(i) / 30.0))
		var qt := float(sim.p["qtarget"])
		var qw := float(sim.p["qwin"])
		var wy1 := qy + (1.0 - qt - qw) * qh
		draw_rect(Rect2(qx - 2.5, wy1, 9, qw * 2.0 * qh), Color(0.4, 0.8, 1.0, 0.6 + 0.4 * sin(t * 8.0)), false, 1.0)
		var ny := qy + (1.0 - sim.needle) * qh
		draw_colored_polygon(PackedVector2Array([Vector2(qx - 1, ny), Vector2(qx - 6, ny - 3), Vector2(qx - 6, ny + 3)]), Color.WHITE)

func _draw_guild() -> void:
	draw_rect(Rect2(-400, -400, 960, 472), Color(0.33, 0.22, 0.14))
	for i in 24:
		draw_line(Vector2(-60 + i * 12, -30), Vector2(-60 + i * 12, 72), Color(0.26, 0.17, 0.1), 0.8)
	draw_rect(Rect2(-400, 72, 960, 400), Color(0.25, 0.2, 0.18))
	for i in 10:
		draw_line(Vector2(-60, 72 + i * 6), Vector2(220, 72 + i * 6), Color(0.2, 0.16, 0.14), 0.6)
	# banner + board
	draw_rect(Rect2(70, 0, 20, 10), Color(0.6, 0.15, 0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(70, 10), Vector2(90, 10), Vector2(80, 15)]), Color(0.6, 0.15, 0.15))
	draw_rect(Rect2(36, 16, 88, 40), Color(0.2, 0.12, 0.07))
	draw_rect(Rect2(38, 18, 84, 36), Color(0.66, 0.5, 0.32))
	for i in 4:
		var dg: Dictionary = D.DUNGEONS[i]
		var open := Game.dungeon_open(i)
		var x := 42.0 + i * 20.0
		var y := 21.0 + (i % 2) * 3.0
		draw_rect(Rect2(x, y, 16, 22), Color(0.93, 0.87, 0.72) if open else Color(0.55, 0.5, 0.45))
		draw_rect(Rect2(x + 3, y + 3, 10, 8), dg["col"] if open else Color(0.3, 0.3, 0.3))
		for l in 3:
			draw_line(Vector2(x + 3, y + 14 + l * 2.5), Vector2(x + 13, y + 14 + l * 2.5), Color(0.4, 0.3, 0.25), 0.6)
		draw_circle(Vector2(x + 8, y + 1), 1.2, Color(0.8, 0.2, 0.2))
	# torches
	for tx in [20.0, 140.0]:
		draw_rect(Rect2(tx - 1, 30, 2, 10), Color(0.4, 0.26, 0.14))
		_fire(Vector2(tx, 30), 5, 0.4)
	# adventurers waiting in the hall
	var shown := 0
	for a in Game.advs:
		if a["busy"]:
			continue
		var cc: Color = D.CLASSES[a["cls"]]["col"]
		var x := 14.0 + shown * 26.0
		_tex(Pix.person(int(a["seed"]), a["cls"], cc), Vector2(x, 62 + sin(t * 2.0 + shown) * 0.5), 1.6)
		shown += 1

func _draw_street() -> void:
	var title := mode == "title"
	var top := Color(0.08, 0.07, 0.2) if title else Color(0.35, 0.45, 0.75)
	var bot := Color(0.5, 0.25, 0.3) if title else Color(0.98, 0.72, 0.45)
	for i in 20:
		draw_rect(Rect2(-400, -400 + i * 24.0 if i == 0 else i * 4.0 - 10.0, 960, 400.0 if i == 0 else 4.2), top.lerp(bot, i / 19.0))
	if title:
		for i in 30:
			var sx := fmod(i * 53.7, 170.0) - 5.0
			var sy := fmod(i * 31.3, 40.0)
			draw_rect(Rect2(sx, sy, 0.8, 0.8), Color(1, 1, 0.9, 0.5 + 0.5 * sin(t * 2.0 + i)))
		draw_circle(Vector2(140, 14), 6, Color(0.95, 0.93, 0.8))
		draw_circle(Vector2(137, 12), 5.5, top.lerp(bot, 0.1))
	else:
		draw_circle(Vector2(20, 30), 7, Color(1, 0.9, 0.55))
	# hill + spire
	draw_colored_polygon(PackedVector2Array([Vector2(-60, 62), Vector2(60, 30), Vector2(110, 44), Vector2(220, 62)]), Color(0.18, 0.16, 0.25) if title else Color(0.45, 0.45, 0.6))
	if Game.day >= 8 or title:
		draw_colored_polygon(PackedVector2Array([Vector2(112, 44), Vector2(117, 4), Vector2(122, 44)]), Color(0.25, 0.15, 0.35))
		draw_circle(Vector2(117, 6), 1.5 + 0.5 * sin(t * 3.0), Color(0.8, 0.4, 1, 0.8))
	# rival shop
	draw_rect(Rect2(124, 34, 50, 40), Color(0.25, 0.22, 0.26))
	draw_colored_polygon(PackedVector2Array([Vector2(120, 34), Vector2(149, 22), Vector2(178, 34)]), Color(0.2, 0.15, 0.18))
	draw_rect(Rect2(132, 46, 10, 10), Color(0.35, 0.6, 0.45) if not title else Color(0.4, 0.8, 0.6))
	# our shop
	draw_rect(Rect2(14, 28, 100, 48), Color(0.45, 0.32, 0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(8, 30), Vector2(64, 10), Vector2(120, 30)]), Color(0.45, 0.18, 0.12))
	draw_rect(Rect2(92, 4, 10, 18), Color(0.35, 0.3, 0.3))
	for i in 4:
		var k := fmod(t * 0.4 + i * 0.25, 1.0)
		draw_circle(Vector2(97 + sin(t + i) * 3.0 + k * 10.0, 2 - k * 20.0), 2.0 + k * 4.0, Color(0.6, 0.6, 0.65, 0.35 * (1.0 - k)))
	draw_rect(Rect2(24, 33, 80, 9), Color(0.2, 0.12, 0.07))
	var glow := Color(1, 0.7, 0.3) if title else Color(0.75, 0.6, 0.4)
	draw_rect(Rect2(22, 48, 22, 16), glow)
	draw_rect(Rect2(84, 48, 22, 16), glow)
	draw_line(Vector2(33, 48), Vector2(33, 64), Color(0.3, 0.2, 0.12), 1)
	draw_line(Vector2(95, 48), Vector2(95, 64), Color(0.3, 0.2, 0.12), 1)
	draw_rect(Rect2(54, 50, 20, 26), Color(0.3, 0.18, 0.1))
	draw_circle(Vector2(70, 64), 1, Color(0.9, 0.75, 0.3))
	draw_rect(Rect2(-400, 76, 960, 400), Color(0.3, 0.27, 0.3) if title else Color(0.55, 0.5, 0.48))
	for i in 14:
		draw_line(Vector2(-40 + i * 16, 76), Vector2(-48 + i * 16, 100), Color(0.25, 0.22, 0.25) if title else Color(0.45, 0.42, 0.4), 0.6)
	if title:
		var swing := absf(sin(t * 3.0))
		_tex(Pix.smith(), Vector2(118, 60), 1.3)
		_tex(Pix.anvil(), Vector2(104, 82), 1.0)
		if swing > 0.97 and randf() < 0.5:
			sparks(Vector2(110, 82), 5)

func _draw_ending() -> void:
	var won: bool = ending.get("won", false)
	var top := Color(0.95, 0.55, 0.35) if won else Color(0.25, 0.25, 0.35)
	var bot := Color(1, 0.85, 0.55) if won else Color(0.45, 0.4, 0.45)
	for i in 20:
		draw_rect(Rect2(-400, i * 4.0 - 10.0 if i > 0 else -400.0, 960, 4.2 if i > 0 else 394.0), top.lerp(bot, i / 19.0))
	draw_circle(Vector2(80, 60), 20, Color(1, 0.95, 0.7, 0.9 if won else 0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-60, 70), Vector2(50, 40), Vector2(120, 52), Vector2(220, 70)]), Color(0.3, 0.22, 0.3))
	if won:
		draw_colored_polygon(PackedVector2Array([Vector2(56, 44), Vector2(58, 30), Vector2(62, 26), Vector2(64, 44)]), Color(0.2, 0.14, 0.25))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(56, 44), Vector2(60, 14), Vector2(64, 44)]), Color(0.2, 0.12, 0.3))
		draw_circle(Vector2(60, 16), 2, Color(0.8, 0.3, 1))
	draw_rect(Rect2(-400, 70, 960, 400), Color(0.25, 0.2, 0.18))
	var w: Dictionary = ending.get("w", {})
	_tex(Pix.person(777, "knight", Color(0.85, 0.85, 0.9)), Vector2(72, 50), 2.0)
	if not w.is_empty():
		_tex(Pix.weapon(w["type"], w["ore"], w["mat"], w.get("gem", "")), Vector2(84, 30 + sin(t * 2.0)), 1.4)
		if won and randf() < 0.2:
			sparks(Vector2(100, 32), 3, Color(1, 0.95, 0.6), 30.0)
	_tex(Pix.smith(), Vector2(40, 52), 1.5)

func _draw_overlay_text() -> void:
	match mode:
		"title":
			_text("BLADE & BELLOWS", Vector2(80, 22), 15.0, Color(1, 0.78, 0.3), true, 8)
			_text("a blacksmith-shop RPG", Vector2(80, 31), 6.0, Color(0.95, 0.88, 0.75))
			_text("BLADE & BELLOWS", Vector2(64, 40), 5.0, Color(1, 0.8, 0.35))
		"street":
			_text("BLADE & BELLOWS", Vector2(64, 40), 5.0, Color(1, 0.8, 0.35))
			if Game.day >= 4:
				_text("VORN'S", Vector2(149, 31), 3.5, Color(0.6, 0.9, 0.7))
			_text("Day %d" % Game.day, Vector2(80, 92), 9.0, Color(1, 0.95, 0.8), true, 6)
		"shop":
			_text("Day %d  -  %dh of daylight" % [Game.day, Game.hours], Vector2(80, 96), 5.0, Color(0.95, 0.85, 0.7))
			if not customer.is_empty() and cust_t > 0.6 and bubble != "":
				var bp := Vector2(98, 52)
				var sp := to_screen(bp)
				var fs := maxi(9, int(5.0 * _s()))
				var tw := font.get_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var r := Rect2(sp + Vector2(-tw * 0.5 - 6, -fs - 6), Vector2(tw + 12, fs + 10))
				r.position.x = clampf(r.position.x, 2, size.x - r.size.x - 2)
				draw_rect(r, Color(1, 0.97, 0.88))
				draw_rect(r, Color(0.2, 0.12, 0.08), false, 2.0)
				draw_string(font, r.position + Vector2(6, fs + 2), bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.12, 0.08))
		"forge":
			if sim:
				var names := {"heat": "HEAT THE METAL", "hammer": "HAMMER IT", "quench": "QUENCH", "done": "DONE"}
				_text(names.get(sim.phase, ""), Vector2(100 if sim.phase == "heat" else 40, 96 if sim.phase != "heat" else 20), 7.0, Color(1, 0.85, 0.45), true, 6)
				if sim.phase == "heat":
					var col := Color(0.5, 1, 0.5) if sim.in_band() else Color(1, 0.9, 0.8)
					_text(Pix.heat_name(sim.heat) + (" - ready!" if sim.in_band() else ""), Vector2(100, 30), 6.0, col)
					_text("target: " + Pix.heat_name(float(sim.p["target"])), Vector2(100, 38), 5.0, Color(0.9, 0.8, 0.7))
				if sim.last != "" and (sim.phase == "quench" or sim.phase == "done"):
					_text(sim.last, Vector2(100, 30), 6.0, Color(1, 1, 0.8))
		"guild":
			_text("ADVENTURERS' GUILD", Vector2(80, 12) + Vector2(0, -2), 6.0, Color(1, 0.85, 0.5))
		"ending":
			_text(ending.get("title", ""), Vector2(80, 16), 10.0, Color(1, 0.9, 0.55), true, 6)
			_text("Grade " + str(ending.get("grade", "")), Vector2(80, 26), 6.0, Color(1, 1, 0.9))
