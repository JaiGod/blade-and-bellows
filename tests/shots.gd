extends Node
## Captures README screenshots (needs a display, e.g. xvfb-run). SHOTS=<dir>, PORTRAIT=1 for the phone layout.
var main
var out := "user://"
var portrait := false

func _ready() -> void:
	out = OS.get_environment("SHOTS") if OS.get_environment("SHOTS") != "" else "user://"
	portrait = OS.get_environment("PORTRAIT") == "1"
	_run.call_deferred()

func f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var w := 900 if not portrait else 420
	var j: Image = img.duplicate()
	j.resize(w, int(float(w) * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	j.save_jpg(out + "/" + name + ".jpg", 0.72)
	print("[shot] ", name)

func _setup() -> void:
	Game.new_game(42)
	Game.gold = 860
	Game.fame = 34
	Game.day = 9
	Game.lv = {"forge": 3, "anvil": 2, "shop": 2}
	Game.ores = {"copper": 2, "iron": 6, "silver": 4, "mithril": 3}
	Game.mats = {"oak": 3, "leather": 4, "bone": 2}
	Game.gems = {"ruby": 1, "amethyst": 1}
	Game.weapons = []
	Game.weapons.append(Game.make_weapon("greatsword", "silver", "bone", 88, "ruby"))
	Game.weapons.append(Game.make_weapon("axe", "iron", "leather", 74))
	Game.weapons.append(Game.make_weapon("spear", "mithril", "leather", 62))
	Game.weapons.append(Game.make_weapon("dagger", "silver", "bone", 96, "emerald"))
	Game.weapons.append(Game.make_weapon("mace", "iron", "oak", 51))
	Game.weapons.append(Game.make_weapon("sword", "mithril", "bone", 80, "amethyst"))
	Game.refresh_guild()
	Game._tale("Wren Quickstep outfought a salamander queen, their axe singing every swing.")
	Game._tale("Corwin the Bold cut through goblin scouts and came home grinning.")

func _forge_to_hammer(type: String, ore: String) -> void:
	main.start_forge(type, ore, "bone", "contest")
	var sim: ForgeSim = main.sim
	sim.heat = float(sim.p["target"])
	sim.to_anvil()
	await f(3)

func _run() -> void:
	get_window().size = Vector2i(390, 844) if portrait else Vector2i(1280, 720)
	Game.sound_on = false
	Game.music_on = false
	Game.delete_save()
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await f(30)
	if portrait:
		_setup()
		main.show_hub()
		main.start_shop()
		var c: Dictionary = main.customers[0]
		c["pers"] = "noble"
		c["wants"] = "greatsword"
		c["budget"] = 2000
		Game.show_weapon(c, Game.weapons[0])
		main.view.bubble = "%dg?" % int(c["offer"])
		main._customer_ui()
		await f(70)
		await snap("mobile")
		_setup()
		await _forge_to_hammer("sword", "mithril")
		main.sim.marker = 0.5
		main.sim.strike()
		main._process(0.0)
		await f(4)
		await snap("mobile_forge")
		get_tree().quit()
		return
	for i in 30:
		await f(2)
	await snap("title")
	_setup()
	main.show_hub()
	main.start_forge("greatsword", "mithril", "bone", "normal")
	var sim: ForgeSim = main.sim
	sim.pumping = true
	while sim.heat < float(sim.p["target"]) - 0.06:
		sim.step(1.0 / 60.0)
	await f(20)
	sim.heat = float(sim.p["target"]) - 0.01
	await snap("forge_heat")
	sim.pumping = false
	sim.to_anvil()
	main._process(0.0)
	await f(40)
	sim.marker = 0.5
	sim.strike()
	sim.marker = 0.48
	sim.strike()
	sim.marker = 0.3
	main._process(0.0)
	await f(5)
	await snap("forge_hammer")
	while sim.phase == "hammer":
		sim.marker = 0.5
		sim.strike()
	main._process(0.0)
	await f(5)
	sim.needle = float(sim.p["qtarget"])
	sim.quench()
	main._process(0.0)
	await f(12)
	main.show_forge_result()
	await f(20)
	await snap("forged")
	main.show_hub()
	main.start_shop()
	var c: Dictionary = main.customers[0]
	c["pers"] = "noble"
	c["name"] = "Isolde"
	c["wants"] = "greatsword"
	c["budget"] = 2000
	c["hello"] = "I require something worthy of my house."
	Game.show_weapon(c, Game.weapons[0])
	main.view.bubble = "%dg?" % int(c["offer"])
	main._customer_ui()
	await f(70)
	await snap("shop")
	main.show_guild()
	await f(10)
	main.sel["adv"] = int(Game.advs[0]["id"])
	main.sel["d"] = 2
	main.show_guild_weapon()
	await f(30)
	await snap("guild")
	main.show_morning()
	Game.morning = D.STORY[21].duplicate()
	Game.day = 21
	main.show_morning()
	await f(30)
	await snap("story")
	Game.fame = 72
	Game.debt = 0
	var w := Game.make_weapon("greatsword", "starmetal", "ebony", 93, "ruby")
	var e := Game.finish_story(w)
	e["w"] = w
	main.show_ending(e)
	await f(60)
	await snap("ending")
	get_tree().quit()
