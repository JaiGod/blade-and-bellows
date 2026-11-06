extends Control
## Screen controller: builds the responsive layout (scene + menu panel), every menu screen,
## the forging minigame UI, the shop haggling loop, guild commissions, pause and endings.

const GOLD := Color(1, 0.8, 0.35)
const INK := Color(0.96, 0.9, 0.8)
const DIM := Color(0.74, 0.66, 0.56)
const BAD := Color(1, 0.5, 0.42)
const GOOD := Color(0.55, 1, 0.55)

var view: SceneView
var topbar: PanelContainer
var top_l: Label
var btn_snd: Button
var btn_pause: Button
var panel: PanelContainer
var scroll: ScrollContainer
var box: VBoxContainer
var overlay: Control = null
var screen := ""
var sim: ForgeSim = null
var fctx := {}
var sel := {"type": "sword", "ore": "iron", "mat": "oak"}
var customers: Array = []
var ci := 0
var sold_today := 0
var earned_today := 0
var paused := false
var act_btn: Button
var next_btn: Button
var hint_l: Label
var fphase := ""
var champ_w := {}
var msg := ""

func _ready() -> void:
	theme = _make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	view = SceneView.new()
	add_child(view)
	view.press_down.connect(func(): _press(true))
	view.press_up.connect(func(): _press(false))
	topbar = PanelContainer.new()
	topbar.add_theme_stylebox_override("panel", _sb(Color(0.13, 0.08, 0.07), Color(0.45, 0.3, 0.16), 2, 3))
	add_child(topbar)
	var hb := HBoxContainer.new()
	topbar.add_child(hb)
	top_l = Label.new()
	top_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_l.clip_text = true
	top_l.add_theme_font_size_override("font_size", 12)
	top_l.add_theme_color_override("font_color", GOLD)
	top_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(top_l)
	btn_snd = _small("Sound", toggle_sound, hb)
	btn_pause = _small("Pause", toggle_pause, hb)
	panel = PanelContainer.new()
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	get_viewport().size_changed.connect(_layout)
	Game.changed.connect(_refresh_top)
	_layout()
	show_title()
	_start_music.call_deferred()

func _start_music() -> void:
	await get_tree().process_frame
	Sfx.start_music()

# ---------------------------------------------------------------- layout & theme
func _layout() -> void:
	var sz := get_viewport_rect().size
	var th := 30.0
	topbar.position = Vector2.ZERO
	topbar.size = Vector2(sz.x, th)
	if sz.x > sz.y * 1.1:
		var vw := floorf(sz.x * 0.56)
		view.position = Vector2(0, th)
		view.size = Vector2(vw, sz.y - th)
		panel.position = Vector2(vw, th)
		panel.size = Vector2(sz.x - vw, sz.y - th)
	else:
		var vh := clampf(floorf(sz.x * 0.64), 120.0, sz.y * 0.42)
		if screen == "forge" or screen == "result" or screen == "ending":
			vh = clampf(floorf(sz.x * 0.85), 120.0, sz.y * 0.52)
		view.position = Vector2(0, th)
		view.size = Vector2(sz.x, vh)
		panel.position = Vector2(0, th + vh)
		panel.size = Vector2(sz.x, sz.y - th - vh)
	if overlay:
		overlay.size = sz
	_refresh_top()

func _sb(bg: Color, border: Color, bw: int = 2, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(3)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = maxi(2, pad - 3)
	s.content_margin_bottom = maxi(2, pad - 3)
	return s

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 13
	th.set_stylebox("normal", "Button", _sb(Color(0.3, 0.19, 0.12), Color(0.62, 0.42, 0.2)))
	th.set_stylebox("hover", "Button", _sb(Color(0.42, 0.26, 0.14), Color(1, 0.75, 0.35)))
	th.set_stylebox("pressed", "Button", _sb(Color(0.55, 0.3, 0.12), Color(1, 0.85, 0.45)))
	th.set_stylebox("disabled", "Button", _sb(Color(0.18, 0.13, 0.11), Color(0.3, 0.24, 0.2)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", INK)
	th.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	th.set_color("font_pressed_color", "Button", Color(1, 1, 0.9))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.44, 0.38))
	th.set_stylebox("panel", "PanelContainer", _sb(Color(0.15, 0.1, 0.09), Color(0.42, 0.28, 0.16), 2, 10))
	th.set_color("font_color", "Label", INK)
	return th

func _refresh_top() -> void:
	if not top_l:
		return
	btn_snd.text = "Sound" if Game.sound_on else "Muted"
	if screen == "title" or screen == "howto":
		top_l.text = "  BLADE & BELLOWS"
		btn_pause.visible = false
		return
	btn_pause.visible = true
	top_l.text = " Day %d/30  %dh  |  %dg  |  Fame %d  |  Debt %d" % [Game.day, Game.hours, Game.gold, Game.fame, Game.debt]

# ---------------------------------------------------------------- UI helpers
func clear() -> void:
	_layout()
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	scroll.scroll_vertical = 0
	_refresh_top()

func H(text: String, col: Color = GOLD, fs: int = 18, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 20
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 4)
	(parent if parent else box).add_child(l)
	return l

func P(text: String, col: Color = INK, fs: int = 13, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 20
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	(parent if parent else box).add_child(l)
	return l

func B(text: String, cb: Callable, enabled: bool = true, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.clip_text = true
	b.custom_minimum_size = Vector2(40, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	(parent if parent else box).add_child(b)
	return b

func ROW(parent: Control = null) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	(parent if parent else box).add_child(r)
	return r

func GRID(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	box.add_child(g)
	return g

func _small(text: String, cb: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.custom_minimum_size = Vector2(54, 24)
	b.add_theme_stylebox_override("normal", _sb(Color(0.3, 0.19, 0.12), Color(0.62, 0.42, 0.2), 1, 4))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	parent.add_child(b)
	return b

func _cols() -> int:
	return 3 if panel.size.x >= 330 else 2

# ---------------------------------------------------------------- input
func _input(e: InputEvent) -> void:
	if e is InputEventKey and not e.echo:
		if e.keycode == KEY_ESCAPE and e.pressed:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif screen == "forge" and not paused:
			if e.keycode == KEY_SPACE:
				_press(e.pressed)
				get_viewport().set_input_as_handled()
			elif (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER) and e.pressed and sim and sim.phase == "heat":
				sim.to_anvil()
				get_viewport().set_input_as_handled()

func _press(down: bool) -> void:
	if screen != "forge" or sim == null or paused:
		return
	if sim.phase == "heat":
		sim.pumping = down
	elif down:
		sim.primary()

func _process(dt: float) -> void:
	if screen == "forge" and sim and not paused:
		sim.step(dt)
		if sim.pumping and randf() < dt * 5.0:
			Sfx.play("whoosh", randf_range(0.85, 1.15))
		for ev in sim.events:
			_forge_event(ev)
		sim.events.clear()
		if sim.phase != fphase:
			_forge_ui()

# ---------------------------------------------------------------- pause
func toggle_pause() -> void:
	if screen == "title" or screen == "howto" or screen == "ending":
		return
	if overlay:
		overlay.queue_free()
		overlay = null
		paused = false
		return
	paused = true
	if sim:
		sim.pumping = false
	overlay = Control.new()
	overlay.size = get_viewport_rect().size
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(260, 0)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	H("Paused", GOLD, 22, vb)
	B("Resume", toggle_pause, true, vb)
	B("Sound: " + ("On" if Game.sound_on else "Off"), func():
		toggle_sound()
		toggle_pause()
		toggle_pause(), true, vb)
	B("Music: " + ("On" if Game.music_on else "Off"), func():
		toggle_music()
		toggle_pause()
		toggle_pause(), true, vb)
	B("Save & quit to title", func():
		toggle_pause()
		Game.save_game()
		show_title(), true, vb)

func toggle_sound() -> void:
	Game.sound_on = not Game.sound_on
	Game.save_meta()
	_refresh_top()

func toggle_music() -> void:
	Game.music_on = not Game.music_on
	Game.save_meta()
	Sfx.start_music()

# ---------------------------------------------------------------- title / help / story
func show_title() -> void:
	screen = "title"
	sim = null
	view.mode = "title"
	view.set_customer({})
	clear()
	H("Blade & Bellows", GOLD, 26)
	P("Forge weapons by hand, haggle with customers and arm adventurers for the dungeons. Pay off your grandfather's debt in 30 days.", DIM)
	if Game.has_save():
		B("Continue", continue_game)
	B("New Game", new_game)
	B("How to Play", show_howto)
	var r := ROW()
	B("Sound: " + ("On" if Game.sound_on else "Off"), func():
		toggle_sound()
		show_title(), true, r)
	B("Music: " + ("On" if Game.music_on else "Off"), func():
		toggle_music()
		show_title(), true, r)
	if str(Game.meta.get("best_grade", "")) != "":
		P("Best ending: grade %s   |   runs finished: %d" % [Game.meta["best_grade"], int(Game.meta.get("runs", 0))], GOLD)
	P("Made by Jaineil Rana (JaKing) - part of JaiGod", DIM, 11)

func continue_game() -> void:
	if not Game.load_game():
		new_game()
		return
	if not Game.event.is_empty():
		show_morning()
	else:
		show_hub()

func new_game() -> void:
	Game.new_game()
	sel = {"type": "sword", "ore": "iron", "mat": "oak"}
	show_morning()

func show_howto() -> void:
	screen = "howto"
	clear()
	H("How to Play")
	H("Forging", GOLD, 15)
	P("1. HEAT: hold the button, Space or the scene to pump the bellows. Get the metal to the glowing green window on the heat gauge, then press 'To the anvil' (Enter).")
	P("2. HAMMER: strike (Space / tap) when the white marker crosses the green zone. Bright green is PERFECT. The metal cools while you work.")
	P("3. QUENCH: the needle on the right drops as the blade cools. Quench when it reaches the blue window.")
	P("Better ore, fittings and quality make stronger, pricier weapons: Crude, Common, Fine, Superior, Masterwork, Legendary.", DIM)
	H("Shop", GOLD, 15)
	P("Open the shop to meet customers. Show a weapon, then sell, haggle or send them away. Hagglers have patience to spare; nobles don't. Collectors love enchanted pieces.")
	H("Adventurers", GOLD, 15)
	P("Lend weapons to adventurers at the Guild. They return with gold, ore, gems and fame - or die if the gear was too weak. Check the odds before you send them.")
	H("Goal", GOLD, 15)
	P("Each day has 8 hours: forging takes 2, a shop session 3. Pay rent weekly, upgrade your forge, anvil and shop, beat your rival Vorn at the contests and forge a blade for the champion on day 30. Pay the 2,000g debt or lose the forge!")
	P("Keys: Space = pump / strike / quench, Enter = to the anvil, Esc = pause.", DIM)
	B("Back", show_title)

func show_morning() -> void:
	screen = "morning"
	sim = null
	view.mode = "street"
	view.set_customer({})
	clear()
	Sfx.play("page")
	H("Day %d" % Game.day, GOLD, 22)
	for line in Game.morning:
		P(str(line))
	if Game.over == "repossessed":
		B("...", show_gameover)
		return
	var ev: Dictionary = Game.event
	match str(ev.get("kind", "")):
		"choice":
			P(str(ev["text"]), GOLD)
			for opt in ev["opts"]:
				var id: String = opt[1]
				B(str(opt[0]), func():
					var r := Game.resolve_choice(id)
					Game.morning = [r]
					show_morning())
		"contest":
			P("CONTEST: forge a %s from %s. The town is watching - and so is Vorn." % [D.TYPES[ev["type"]]["name"], D.ORES[ev["ore"]]["name"]], GOLD)
			P("The guild supplies the materials. Beat Vorn's score to win 150 gold and 15 fame.", DIM)
			B("Enter the contest!", func(): start_forge(ev["type"], ev["ore"], "leather", "contest"))
		"champion":
			B("Forge the Champion's blade", func(): show_forge_select("champion"))
		_:
			B("Open the shutters  >", show_hub)

# ---------------------------------------------------------------- hub
func show_hub() -> void:
	screen = "hub"
	sim = null
	view.mode = "shop"
	view.set_customer({})
	clear()
	Game.save_game()
	H("Day %d of 30  -  %s smith" % [Game.day, Game.fame_title()], GOLD, 17)
	P("%dh of daylight left.  %d weapons in stock.  Debt due on day 30: %dg." % [Game.hours, Game.weapons.size(), Game.debt], DIM)
	if Game.price_war > 0:
		P("Price war with Vorn: offers are 15% lower.", BAD)
	if Game.today.get("caravan", false):
		P("Dwarven caravan: ore is 25% off today.", GOOD)
	if Game.today.get("peddler", false):
		P("Gem peddler: gems are 30% off today.", GOOD)
	if msg != "":
		P(msg, GOLD)
		msg = ""
	B("Forge a weapon  (2h)", func(): show_forge_select("normal"), Game.hours >= Game.FORGE_HOURS)
	B("Open the shop  (3h, %d customers)" % Game.customer_count(), start_shop, Game.hours >= Game.SHOP_HOURS and not Game.weapons.is_empty())
	B("Adventurers' Guild" + ("  (%d on quests)" % Game.quests.size() if Game.quests.size() > 0 else ""), show_guild)
	var r := ROW()
	B("Market", show_market, true, r)
	B("Armory (%d)" % Game.weapons.size(), show_armory, true, r)
	B("Upgrades & Debt", show_upgrades)
	B("End the day  >", end_day)
	var tips := ["Tip: wanted weapon types sell for 20% more.", "Tip: enchant with an Amethyst to protect adventurers.",
		"Tip: Emerald blades bring back far more loot.", "Tip: upgrade the anvil for a bigger sweet spot.",
		"Tip: the Hollow Spire opens on day 8 - it holds Starmetal.", "Tip: rent is due every 7 days."]
	P(tips[Game.day % tips.size()], DIM, 11)

func end_day() -> void:
	Game.end_day()
	if Game.over == "repossessed":
		show_gameover()
	else:
		show_morning()

# ---------------------------------------------------------------- forging
func show_forge_select(mode: String) -> void:
	screen = "forge_select"
	fctx = {"mode": mode}
	view.mode = "forge"
	view.sim = null
	clear()
	var free := mode != "normal"
	if not Game.ore_ok(sel["ore"]):
		sel["ore"] = "iron"
	H("The Champion's Blade" if mode == "champion" else "Choose a recipe", GOLD, 18)
	if mode == "champion":
		P("The guild's stores are open to you. Pick the strongest weapon and the best ore your forge can work.", DIM)
	P("Weapon", GOLD)
	var g := GRID(_cols())
	for tid in D.TYPE_ORDER:
		var td: Dictionary = D.TYPES[tid]
		var b := B(("> " if sel["type"] == tid else "") + "%s (%d)" % [td["name"], int(td["bars"])], func():
			sel["type"] = tid
			show_forge_select(mode), true, g)
		if sel["type"] == tid:
			b.add_theme_color_override("font_color", GOLD)
	P("Ore", GOLD)
	g = GRID(_cols())
	for oid in D.ORE_ORDER:
		var od: Dictionary = D.ORES[oid]
		var txt: String = od["name"] + ("" if free else " x%d" % int(Game.ores.get(oid, 0)))
		if not Game.ore_ok(oid):
			txt = "%s (Forge %d)" % [od["name"], int(od["forge"])]
		var b := B(("> " if sel["ore"] == oid else "") + txt, func():
			sel["ore"] = oid
			show_forge_select(mode), Game.ore_ok(oid), g)
		if sel["ore"] == oid:
			b.add_theme_color_override("font_color", GOLD)
	var mat: String = "ebony" if free else sel["mat"]
	if not free:
		P("Fitting", GOLD)
		g = GRID(2)
		for mid in D.MAT_ORDER:
			var md: Dictionary = D.MATS[mid]
			var ok := Game.mat_ok(mid)
			var txt: String = md["name"] + " x%d" % int(Game.mats.get(mid, 0)) if ok else "%s (Shop %d)" % [md["name"], int(md["shop"])]
			var b := B(("> " if sel["mat"] == mid else "") + txt, func():
				sel["mat"] = mid
				show_forge_select(mode), ok, g)
			if sel["mat"] == mid:
				b.add_theme_color_override("font_color", GOLD)
	var est := Game.make_weapon(sel["type"], sel["ore"], mat, 60)
	Game.next_id -= 1
	var est2 := est.duplicate()
	est2["score"] = 85
	P("Fine: power %d, worth ~%dg.   Masterwork: power %d, worth ~%dg." % [int(Game.power(est)), Game.value(est), int(Game.power(est2)), Game.value(est2)], DIM, 12)
	var block := Game.forge_block(sel["type"], sel["ore"], mat, free)
	if block != "":
		P(block, BAD)
	B("Fire up the forge!", func(): start_forge(sel["type"], sel["ore"], mat, mode), block == "")
	if not free:
		var r := ROW()
		B("Market", show_market, true, r)
		B("Back", show_hub, true, r)

func start_forge(type: String, ore: String, mat: String, mode: String) -> void:
	var params := Game.begin_forge(type, ore, mat, mode != "normal")
	if params.is_empty():
		return
	sim = ForgeSim.new(params)
	fctx = {"type": type, "ore": ore, "mat": mat, "mode": mode}
	view.sim = sim
	view.mode = "forge"
	screen = "forge"
	fphase = ""
	clear()
	H("Forging: %s %s" % [D.ORES[ore]["name"], D.TYPES[type]["name"]], GOLD, 17)
	hint_l = P("")
	act_btn = Button.new()
	act_btn.custom_minimum_size = Vector2(40, 64)
	act_btn.focus_mode = Control.FOCUS_NONE
	act_btn.add_theme_font_size_override("font_size", 18)
	act_btn.button_down.connect(func(): _press(true))
	act_btn.button_up.connect(func(): _press(false))
	box.add_child(act_btn)
	next_btn = Button.new()
	next_btn.custom_minimum_size = Vector2(40, 40)
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.text = "To the anvil  >"
	next_btn.pressed.connect(func():
		if sim:
			sim.to_anvil())
	box.add_child(next_btn)
	_forge_ui()

func _forge_ui() -> void:
	if sim == null or hint_l == null or not is_instance_valid(hint_l):
		return
	fphase = sim.phase
	match sim.phase:
		"heat":
			hint_l.text = "Hold to pump the bellows. Bring the metal to %s (the green window on the left gauge), then take it to the anvil. Don't let it burn!" % Pix.heat_name(float(sim.p["target"]))
			act_btn.text = "HOLD: PUMP BELLOWS"
			next_btn.visible = true
		"hammer":
			hint_l.text = "Strike when the white marker is in the green. %d strikes needed - the metal cools as you work!" % int(sim.p["strikes"])
			act_btn.text = "STRIKE!"
			next_btn.visible = false
		"quench":
			hint_l.text = "The blade is cooling. Quench when the needle on the right gauge reaches the blue window."
			act_btn.text = "QUENCH!"
		"done":
			hint_l.text = sim.last
			act_btn.text = "..."
			act_btn.disabled = true
			get_tree().create_timer(0.9).timeout.connect(_forge_done)

func _forge_event(ev: String) -> void:
	var anvil := Vector2(104, 60)
	match ev:
		"anvil":
			Sfx.play("thud")
			view.bump(2.0)
			view.float_text(sim.last, Vector2(100, 34))
		"strike_perfect":
			Sfx.play("clang", randf_range(1.0, 1.08))
			view.hammer_t = 1.0
			view.sparks(anvil, 26)
			view.bump(5.0)
			view.float_text("PERFECT!", Vector2(104, 46), Color(0.75, 1, 0.5))
		"strike_good":
			Sfx.play("clang_good")
			view.hammer_t = 1.0
			view.sparks(anvil, 14)
			view.bump(3.0)
			view.float_text("Good", Vector2(104, 46), Color(0.5, 0.9, 0.5))
		"strike_ok":
			Sfx.play("clang_good", 0.85)
			view.hammer_t = 1.0
			view.sparks(anvil, 6)
			view.bump(2.0)
			view.float_text("Glancing", Vector2(104, 46), Color(1, 0.8, 0.4))
		"strike_miss":
			Sfx.play("thud")
			view.hammer_t = 1.0
			view.bump(1.0)
			view.float_text("Miss!", Vector2(104, 46), BAD)
		"quench":
			Sfx.play("hiss")
			view.steam(Vector2(139, 58), 34)
		"quench_bad":
			Sfx.play("bad")

func _forge_done() -> void:
	if screen != "forge" or sim == null or sim.phase != "done":
		return
	show_forge_result()

func show_forge_result() -> void:
	screen = "result"
	var mode: String = fctx.get("mode", "normal")
	var w := Game.finish_forge(fctx["type"], fctx["ore"], fctx["mat"], sim.score, mode != "champion")
	clear()
	var tier := Game.tier_of(sim.score)
	H(Game.tier_name(sim.score) + "!", Game.tier_col(sim.score), 24)
	P(Game.wname(w), INK, 15)
	var tr := TextureRect.new()
	tr.texture = Pix.weapon(w["type"], w["ore"], w["mat"], w.get("gem", ""))
	tr.custom_minimum_size = Vector2(64, 64)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(tr)
	P("Heat %d%%   Hammer %d%%   Quench %d%%" % [int(sim.heat_score * 100), int(sim.hammer_avg() * 100), int(sim.quench_score * 100)], DIM)
	P("Quality %d/100   Power %.1f   Worth ~%dg" % [sim.score, Game.power(w), Game.value(w)], GOLD)
	Sfx.play("fanfare" if tier >= 3 else "sparkle")
	if tier >= 3:
		view.sparks(Vector2(139, 50), 40, Color(1, 0.9, 0.5), 80.0)
	match mode:
		"contest":
			var r := Game.contest_result(sim.score, int(Game.event.get("rival", 64)) if Game.event.has("rival") else int(fctx.get("rival", 64)))
			P(str(r["text"]), GOOD if r["won"] else BAD, 14)
			Sfx.play("fanfare" if r["won"] else "sad")
			B("Back to the shop", show_hub)
		"champion":
			champ_w = w
			_champion_ui()
		_:
			B("Forge another", func(): show_forge_select("normal"), Game.hours >= Game.FORGE_HOURS)
			B("Back to the shop", show_hub)

func _champion_ui() -> void:
	var cp := Game.champion_power(champ_w)
	P("With Ser Aveline's skill and your fame, this blade's strength is %d. The Spire's guardian will need about %d." % [int(cp), int(Game.CHAMPION_NEED)], GOOD if cp >= Game.CHAMPION_NEED else BAD)
	if str(champ_w.get("gem", "")) == "":
		for gid in D.GEM_ORDER:
			if int(Game.gems.get(gid, 0)) > 0:
				B("Set a %s: %s" % [D.GEMS[gid]["name"], D.GEMS[gid]["desc"]], func():
					Game.gems[gid] = int(Game.gems[gid]) - 1
					champ_w["gem"] = gid
					Sfx.play("sparkle")
					clear()
					H("Enchanted!", GOLD, 22)
					P(Game.wname(champ_w))
					_champion_ui())
	if Game.debt > 0:
		P("Remember: your %dg debt is collected tonight (you have %dg)." % [Game.debt, Game.gold], BAD if Game.gold < Game.debt else DIM)
	B("Hand the blade to Ser Aveline", finish_champion)

func finish_champion() -> void:
	var e := Game.finish_story(champ_w)
	e["w"] = champ_w
	show_ending(e)

func show_ending(e: Dictionary) -> void:
	screen = "ending"
	view.mode = "ending"
	view.ending = e
	clear()
	H(str(e["title"]), GOLD if e["grade"] != "F" else BAD, 22)
	H("Ending grade: " + str(e["grade"]), INK, 16)
	P(str(e["text"]))
	P("Weapons forged: %d   Sold: %d   Gold earned: %d" % [int(Game.stats["forged"]), int(Game.stats["sold"]), int(Game.stats["earned"])], DIM)
	P("Best quality: %d   Quests: %d   Adventurers lost: %d   Fame: %d" % [int(Game.stats["best"]), int(Game.stats["quests"]), int(Game.stats["deaths"]), Game.fame], DIM)
	Sfx.play("fanfare" if e["grade"] in ["S", "A"] else "sad")
	B("Play again", new_game)
	B("Return to title", show_title)

func show_gameover() -> void:
	screen = "ending"
	view.mode = "street"
	clear()
	H("The Forge Is Seized", BAD, 22)
	P("Your debt passed %dg. Guildmaster Hesk changes the locks while Vorn Ashgrave laughs across the square." % Game.DEBT_LIMIT)
	P("You survived to day %d and forged %d weapons." % [Game.day, int(Game.stats["forged"])], DIM)
	Game.delete_save()
	Sfx.play("sad")
	B("Try again", new_game)
	B("Return to title", show_title)

# ---------------------------------------------------------------- shop
func start_shop() -> void:
	customers = Game.start_shop()
	if customers.is_empty():
		return
	ci = 0
	sold_today = 0
	earned_today = 0
	screen = "shop"
	view.mode = "shop"
	_next_customer()

func _next_customer() -> void:
	if ci >= customers.size() or Game.weapons.is_empty():
		show_shop_done()
		return
	view.set_customer(customers[ci])
	view.bubble = "!"
	Sfx.play("bell")
	msg = ""
	_customer_ui()

func _customer_ui() -> void:
	var c: Dictionary = customers[ci]
	clear()
	H("%s the %s  (%d/%d)" % [c["name"], D.PERS[c["pers"]]["name"], ci + 1, customers.size()], GOLD, 16)
	P("\"%s\"" % c["hello"], DIM)
	if c["wants"] != "":
		P("Looking for: a " + D.TYPES[c["wants"]]["name"], GOLD)
	else:
		P("Looking for: anything good.", INK)
	P("Patience: " + "*".repeat(maxi(0, int(c["patience"]))), DIM, 12)
	if msg != "":
		P(msg, GOLD)
	var w := Game.find_weapon(int(c["wid"]))
	if w.is_empty():
		P("Show them a weapon:", INK)
		var list: Array = Game.weapons.duplicate()
		list.sort_custom(func(a, b): return (1 if a["type"] == c["wants"] else 0) * 10000 + Game.value(a) > (1 if b["type"] == c["wants"] else 0) * 10000 + Game.value(b))
		for x in list:
			var wid := int(x["id"])
			B("%s  (%dg)" % [Game.wname(x), Game.value(x)], func():
				var o := Game.show_weapon(c, Game.find_weapon(wid))
				view.bubble = ("%dg?" % o) if o > 0 else "No."
				msg = ""
				_customer_ui())
		B("Send them away", _leave)
		return
	if int(c["offer"]) <= 0:
		P("\"Hmph. That's beneath my collection.\"", BAD)
		B("Show something else", func():
			c["wid"] = -1
			_customer_ui())
		B("Send them away", _leave)
		return
	P("You show: " + Game.wname(w), INK)
	H("Offer: %dg   (worth %dg)" % [int(c["offer"]), Game.value(w)], GOLD, 16)
	if int(c["offer"]) >= int(c["budget"]):
		P("\"That's every coin I have.\"", DIM)
	B("Sell for %dg" % int(c["offer"]), _sell)
	B("Haggle for more", _haggle)
	var r := ROW()
	B("Show another", func():
		c["wid"] = -1
		msg = ""
		_customer_ui(), true, r)
	B("Send away", _leave, true, r)

func _haggle() -> void:
	var c: Dictionary = customers[ci]
	var r := Game.haggle(c)
	if r["ok"]:
		Sfx.play("sparkle")
		msg = "\"Fine, fine... %dg.\"" % int(r["offer"])
		view.bubble = "%dg..." % int(r["offer"])
		view.float_text("+", Vector2(96, 50), GOOD)
	elif r["left"]:
		Sfx.play("bad")
		view.bump(2.0)
		view.bubble = "Bah!"
		ci += 1
		msg = ""
		_next_customer()
		return
	else:
		Sfx.play("bad")
		msg = "\"Don't push your luck, smith.\" (offer %dg)" % int(r["offer"])
		view.bubble = "Hmph."
	_customer_ui()

func _sell() -> void:
	var c: Dictionary = customers[ci]
	var p := Game.sell(c)
	sold_today += 1
	earned_today += p
	Sfx.play("coin")
	view.coins(Vector2(80, 60), 16)
	view.float_text("+%dg" % p, Vector2(80, 48), GOLD)
	ci += 1
	_next_customer()

func _leave() -> void:
	ci += 1
	_next_customer()

func show_shop_done() -> void:
	screen = "shop_done"
	view.set_customer({})
	clear()
	H("Shop closed", GOLD, 20)
	P("You sold %d weapon(s) for %d gold." % [sold_today, earned_today])
	if Game.weapons.is_empty():
		P("Your shelves are empty! Forge more stock.", BAD)
	B("Back", show_hub)

# ---------------------------------------------------------------- guild
func show_guild() -> void:
	screen = "guild"
	view.mode = "guild"
	view.set_customer({})
	clear()
	H("Adventurers' Guild", GOLD, 18)
	P("Lend a weapon to an adventurer. They bring back gold, ore, gems and fame - or die if your steel fails them.", DIM)
	for a in Game.advs:
		var aid := int(a["id"])
		var txt := "%s - Lv %d %s" % [a["name"], int(a["lvl"]), D.CLASSES[a["cls"]]["name"]]
		if a["busy"]:
			for q in Game.quests:
				if int(q["adv"]) == aid:
					txt += "  (%s, %dd)" % [D.DUNGEONS[int(q["d"])]["name"], int(q["left"])]
		B(txt, func():
			sel["adv"] = aid
			show_guild_dungeon(), not a["busy"])
	if not Game.tales.is_empty():
		H("Tales from the dungeons", GOLD, 14)
		for i in mini(5, Game.tales.size()):
			P(str(Game.tales[i]), DIM, 12)
	B("Back", show_hub)

func show_guild_dungeon() -> void:
	var a := Game.find_adv(int(sel.get("adv", -1)))
	if a.is_empty():
		show_guild()
		return
	clear()
	H("Where should %s go?" % a["name"], GOLD, 16)
	for i in D.DUNGEONS.size():
		var dg: Dictionary = D.DUNGEONS[i]
		var di := i
		var open := Game.dungeon_open(i)
		B("%s  - danger %d, %d day%s" % [dg["name"], int(dg["danger"]), int(dg["days"]), "" if int(dg["days"]) == 1 else "s"] if open else "%s (opens day %d)" % [dg["name"], int(dg["day"])], func():
			sel["d"] = di
			show_guild_weapon(), open)
		var loot: Array = []
		for o in dg["ores"]:
			loot.append(D.ORES[o]["name"])
		P("Loot: %d-%dg, %s, gems. +%d fame" % [int(dg["gold"][0]), int(dg["gold"][1]), "/".join(loot), int(dg["fame"])], DIM, 11)
	B("Back", show_guild)

func show_guild_weapon() -> void:
	var a := Game.find_adv(int(sel.get("adv", -1)))
	var di := int(sel.get("d", 0))
	clear()
	H("Arm %s for the %s" % [a["name"], D.DUNGEONS[di]["name"]], GOLD, 16)
	var likes: Array = []
	for tid in D.TYPE_ORDER:
		if D.TYPES[tid]["classes"].has(a["cls"]):
			likes.append(D.TYPES[tid]["name"])
	P("%ss fight best with: %s (+15%%)." % [D.CLASSES[a["cls"]]["name"], ", ".join(likes)], DIM)
	if Game.weapons.is_empty():
		P("No weapons in stock - forge some first!", BAD)
	for w in Game.weapons:
		var o := Game.odds(a, w, di)
		var wid := int(w["id"])
		var b := B("%d%% win, %d%% death: %s" % [int(o["succ"] * 100), int(round(o["death"] * 100)), Game.wname(w)], func():
			if Game.commission(int(a["id"]), wid, di):
				Sfx.play("fanfare")
				msg = "%s sets off for the %s!" % [a["name"], D.DUNGEONS[di]["name"]]
				show_hub())
		if o["death"] > 0.25:
			b.add_theme_color_override("font_color", BAD)
		elif o["succ"] >= 0.7:
			b.add_theme_color_override("font_color", GOOD)
	B("Back", show_guild_dungeon)

# ---------------------------------------------------------------- market / armory / upgrades
func _buy_row(kind: String, id: String, label: String, ok: bool) -> void:
	var r := ROW()
	var l := P(label, INK if ok else DIM, 12, r)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b1 := B("Buy", func():
		if Game.buy(kind, id, 1) > 0:
			Sfx.play("coin")
		show_market(), ok and Game.can_buy(kind, id), r)
	b1.size_flags_horizontal = Control.SIZE_SHRINK_END
	b1.custom_minimum_size.x = 56
	var b5 := B("x5", func():
		if Game.buy(kind, id, 5) > 0:
			Sfx.play("coin")
		show_market(), ok and Game.can_buy(kind, id), r)
	b5.size_flags_horizontal = Control.SIZE_SHRINK_END
	b5.custom_minimum_size.x = 48

func show_market() -> void:
	screen = "market"
	view.mode = "shop"
	clear()
	var keep := scroll.scroll_vertical
	H("Market  -  %dg" % Game.gold, GOLD, 18)
	H("Ore bars", GOLD, 14)
	for oid in D.ORE_ORDER:
		var od: Dictionary = D.ORES[oid]
		var ok := Game.ore_ok(oid)
		_buy_row("ore", oid, ("%s  %dg  (have %d)" % [od["name"], Game.price("ore", oid), int(Game.ores.get(oid, 0))]) if ok else "%s - needs Forge Lv %d" % [od["name"], int(od["forge"])], ok)
	H("Fittings", GOLD, 14)
	for mid in D.MAT_ORDER:
		var md: Dictionary = D.MATS[mid]
		var ok := Game.mat_ok(mid)
		_buy_row("mat", mid, ("%s  %dg  (have %d)" % [md["name"], Game.price("mat", mid), int(Game.mats.get(mid, 0))]) if ok else "%s - needs Shop Lv %d" % [md["name"], int(md["shop"])], ok)
	H("Gems (for enchanting)", GOLD, 14)
	for gid in D.GEM_ORDER:
		var gd: Dictionary = D.GEMS[gid]
		_buy_row("gem", gid, "%s %dg (have %d): %s" % [gd["name"], Game.price("gem", gid), int(Game.gems.get(gid, 0)), gd["desc"]], true)
	B("Back", show_hub)
	scroll.set_deferred("scroll_vertical", keep)

func show_armory() -> void:
	screen = "armory"
	view.mode = "shop"
	clear()
	H("Armory  -  %d weapons" % Game.weapons.size(), GOLD, 18)
	var gl: Array = []
	for gid in D.GEM_ORDER:
		if int(Game.gems.get(gid, 0)) > 0:
			gl.append("%s x%d" % [D.GEMS[gid]["name"], int(Game.gems[gid])])
	P("Gems: " + (", ".join(gl) if not gl.is_empty() else "none yet"), DIM)
	if Game.weapons.is_empty():
		P("Nothing in stock. Head to the forge!", BAD)
	for w in Game.weapons:
		var wid := int(w["id"])
		var b := B("%s  P%d  %dg" % [Game.wname(w), int(Game.power(w)), Game.value(w)], func():
			sel["w"] = wid
			show_weapon_detail())
		b.add_theme_color_override("font_color", Game.tier_col(w["score"]))
	B("Back", show_hub)

func show_weapon_detail() -> void:
	var w := Game.find_weapon(int(sel.get("w", -1)))
	if w.is_empty():
		show_armory()
		return
	clear()
	H(Game.wname(w), Game.tier_col(w["score"]), 17)
	var tr := TextureRect.new()
	tr.texture = Pix.weapon(w["type"], w["ore"], w["mat"], w.get("gem", ""))
	tr.custom_minimum_size = Vector2(64, 64)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(tr)
	P("Quality %d/100   Power %.1f   Worth ~%dg" % [int(w["score"]), Game.power(w), Game.value(w)])
	P("%s fitting.  Favoured by: %s" % [D.MATS[w["mat"]]["name"], ", ".join(D.TYPES[w["type"]]["classes"])], DIM)
	if str(w.get("gem", "")) != "":
		P("Enchanted: " + D.GEMS[w["gem"]]["desc"], GOOD)
	else:
		var any := false
		for gid in D.GEM_ORDER:
			if int(Game.gems.get(gid, 0)) > 0:
				any = true
				B("Enchant with %s: %s" % [D.GEMS[gid]["name"], D.GEMS[gid]["desc"]], func():
					if Game.enchant(w, gid):
						Sfx.play("sparkle")
						view.sparks(Vector2(80, 30), 30, D.GEMS[gid]["col"], 50.0)
					show_weapon_detail())
		if not any:
			P("No gems to enchant with. Adventurers find them in dungeons, or buy them at the market.", DIM)
	B("Back", show_armory)

func show_upgrades() -> void:
	screen = "upgrades"
	view.mode = "shop"
	clear()
	H("Upgrades  -  %dg" % Game.gold, GOLD, 18)
	for k in ["forge", "anvil", "shop"]:
		var ud: Dictionary = D.UPGRADES[k]
		var l := Game.lvl(k)
		H("%s  Lv %d/4" % [ud["name"], l], INK, 15)
		var c := Game.upgrade_cost(k)
		if c < 0:
			P("Fully upgraded.", GOOD)
		else:
			P(ud["desc"][l], DIM, 12)
			B("Upgrade %s - %dg" % [ud["name"], c], func():
				if Game.upgrade(k):
					Sfx.play("fanfare")
				show_upgrades(), Game.gold >= c)
	H("Debt to Guildmaster Hesk: %dg" % Game.debt, BAD if Game.debt > 0 else GOOD, 15)
	P("Due on day 30. Unpaid rent is added to it; past %dg the forge is seized. Weekly rent: %dg." % [Game.DEBT_LIMIT, Game.rent_due()], DIM, 12)
	if Game.debt > 0:
		var r := ROW()
		for amt in [100, 500]:
			var a: int = amt
			B("Pay %d" % a, func():
				if Game.pay_debt(a) > 0:
					Sfx.play("coin")
				show_upgrades(), Game.gold > 0, r)
		B("Pay all", func():
			if Game.pay_debt(Game.debt) > 0:
				Sfx.play("coin")
			show_upgrades(), Game.gold > 0, r)
	B("Back", show_hub)
