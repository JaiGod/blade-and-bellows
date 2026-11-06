extends Node
## Headless smoke test: boots the real UI and plays through forging (perfect and sloppy),
## selling with haggling, guild commissions, market, enchanting, upgrades, contests,
## save/load, 30 days of story and both endings.
var fails := 0
var main

func check(c: bool, m: String) -> void:
	print(("  ok   " if c else "  FAIL ") + m)
	if not c:
		fails += 1

func f(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

## Plays the forge minigame through ForgeSim with near-perfect or sloppy timing.
func play_forge(sim: ForgeSim, good: bool) -> void:
	var dt := 1.0 / 120.0
	var tgt := float(sim.p["target"])
	var guard := 0
	while sim.heat < (tgt if good else tgt - 0.3) and guard < 5000:
		sim.pumping = true
		sim.step(dt)
		guard += 1
	sim.pumping = false
	sim.to_anvil()
	while sim.phase == "hammer" and guard < 20000:
		sim.step(dt)
		guard += 1
		if good and absf(sim.marker - 0.5) < 0.01:
			sim.strike()
		elif not good and sim.marker > 0.95:
			sim.strike()
	while sim.phase == "quench" and guard < 30000:
		sim.step(dt)
		guard += 1
		if good and absf(sim.needle - float(sim.p["qtarget"])) < 0.01:
			sim.quench()

func _ready() -> void:
	Game.delete_save()
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await f(5)
	check(main.screen == "title", "boots to title")
	main.show_howto()
	await f()
	main.new_game()
	await f()
	check(main.screen == "morning" and Game.day == 1, "new game shows day 1 story")
	check(Game.weapons.size() == 2 and Game.gold == 160 and Game.debt == 2000, "starting stock, gold and debt")
	main.show_hub()
	await f()
	check(main.screen == "hub", "hub opens")
	# forge minigame via the real UI
	main.show_forge_select("normal")
	await f()
	main.sel = {"type": "sword", "ore": "iron", "mat": "oak"}
	var bars := int(Game.ores["iron"])
	main.start_forge("sword", "iron", "oak", "normal")
	await f()
	check(main.screen == "forge" and main.sim != null, "forge minigame starts")
	check(int(Game.ores["iron"]) == bars - 2 and Game.hours == 6, "materials and 2h consumed")
	main._press(true)
	for i in 30:
		main._process(1.0 / 30.0)
	main._press(false)
	check(main.sim.heat > 0.3, "holding pumps the bellows (heat %.2f)" % main.sim.heat)
	var sim: ForgeSim = main.sim
	play_forge(sim, true)
	check(sim.phase == "done" and sim.score >= 84, "perfect play scores Masterwork+ (%d)" % sim.score)
	main._process(0.01)
	main.show_forge_result()
	await f()
	check(main.screen == "result" and Game.weapons.size() == 3, "forged weapon added to stock")
	var best: Dictionary = Game.weapons[-1]
	check(Game.tier_of(best["score"]) >= 4, "tier is %s" % Game.tier_name(best["score"]))
	var sloppy := ForgeSim.new(Game.forge_params("axe", "copper"))
	play_forge(sloppy, false)
	check(sloppy.phase == "done" and sloppy.score < 45, "sloppy play scores low (%d)" % sloppy.score)
	# all weapon types x ores produce sane stats
	var okp := true
	for t in D.TYPE_ORDER:
		for o in D.ORE_ORDER:
			for m in D.MAT_ORDER:
				var w := Game.make_weapon(t, o, m, 70)
				if Game.power(w) <= 0 or Game.value(w) <= 0 or Pix.weapon(t, o, m) == null:
					okp = false
	check(okp, "all 6 types x 5 ores x 4 fittings have power, value and sprite")
	# shop session
	main.show_hub()
	main.start_shop()
	await f()
	check(main.screen == "shop" and main.customers.size() >= 3, "shop opens with customers")
	check(Game.hours == 3, "shop used 3 hours")
	var c: Dictionary = main.customers[0]
	c["pers"] = "haggler"
	c["budget"] = 9999
	c["patience"] = 3
	var w0 := Game.find_weapon(int(best["id"]))
	var o0 := Game.show_weapon(c, w0)
	check(o0 > 0, "customer makes an offer (%dg)" % o0)
	Game.rng.seed = 5
	main._customer_ui()
	main._haggle()
	await f()
	var gold0 := Game.gold
	if main.screen == "shop" and main.ci == 0:
		main._sell()
	check(Game.gold > gold0 or main.ci >= 1, "sold to first customer (+%d)" % (Game.gold - gold0))
	while main.screen == "shop":
		main._leave()
		await f()
	check(main.screen == "shop_done", "shop session ends")
	# personalities and haggling rules
	var col := Game.make_customer()
	col["pers"] = "collector"
	check(Game.offer_for(col, Game.make_weapon("dagger", "copper", "oak", 20)) == 0, "collector refuses crude work")
	var hag := Game.make_customer()
	hag["patience"] = 1
	hag["offer"] = 10
	hag["budget"] = 10
	var walked := false
	for i in 5:
		var r := Game.haggle(hag)
		if r["left"]:
			walked = true
			break
	check(walked, "impatient customer walks out after failed haggles")
	# market + enchanting
	Game.gold = 5000
	check(Game.buy("ore", "iron", 5) == 5, "buy 5 iron bars")
	check(Game.buy("ore", "mithril", 1) == 0, "mithril locked at forge Lv1")
	check(Game.buy("gem", "ruby", 1) == 1 and Game.buy("gem", "amethyst", 1) == 1, "buy gems")
	main.show_market()
	main.show_armory()
	main.sel["w"] = int(Game.weapons[0]["id"])
	main.show_weapon_detail()
	await f()
	var ew: Dictionary = Game.weapons[0]
	var p0 := Game.power(ew)
	check(Game.enchant(ew, "ruby") and Game.power(ew) > p0, "ruby enchant raises power")
	check(not Game.enchant(ew, "amethyst"), "can't enchant twice")
	# upgrades
	main.show_upgrades()
	check(Game.upgrade("forge") and Game.lvl("forge") == 2 and Game.ore_ok("silver"), "forge upgrade unlocks silver")
	check(Game.upgrade("anvil") and Game.forge_params("sword", "iron")["sweet"] > 0.075, "anvil upgrade widens sweet spot")
	check(Game.upgrade("shop") and Game.customer_count() >= 4, "shop upgrade adds customers")
	check(Game.pay_debt(500) == 500 and Game.debt == 1500, "pay debt")
	# guild
	main.show_guild()
	await f()
	var a: Dictionary = Game.advs[0]
	main.sel["adv"] = int(a["id"])
	main.show_guild_dungeon()
	main.sel["d"] = 0
	main.show_guild_weapon()
	var strong := Game.make_weapon("greatsword", "silver", "leather", 90)
	Game.weapons.append(strong)
	var od := Game.odds(a, strong, 0)
	var weak := Game.make_weapon("dagger", "copper", "oak", 5)
	var odw := Game.odds(a, weak, 3)
	check(od["succ"] > 0.8 and odw["death"] > od["death"], "odds favour good steel (%.2f / death %.2f)" % [od["succ"], odw["death"]])
	check(Game.commission(int(a["id"]), int(strong["id"]), 0), "commission adventurer to Mossy Warrens")
	check(not Game.commission(int(a["id"]), int(Game.weapons[0]["id"]), 0), "busy adventurer can't be sent twice")
	main.end_day()
	await f()
	check(Game.day == 2 and Game.hours == 8, "day advances")
	check(Game.quests.is_empty() and not Game.find_adv(int(a["id"])).get("busy", true), "adventurer returned after 1 day")
	check(Game.morning.size() >= 1, "morning report lists the return")
	# save / load
	Game.save_game()
	var g0 := Game.gold
	var n0 := Game.weapons.size()
	Game.gold = 1
	Game.weapons = []
	check(Game.load_game() and Game.gold == g0 and Game.weapons.size() == n0, "save/load roundtrip")
	# run the calendar with events, contests and the champion
	var contest_seen := 0
	var choice_seen := false
	for i in 40:
		if Game.day >= 30:
			break
		var ev: Dictionary = Game.event
		if ev.get("kind", "") == "choice":
			choice_seen = true
			Game.resolve_choice("guard")
		elif ev.get("kind", "") == "contest":
			contest_seen += 1
			main.start_forge(ev["type"], ev["ore"], "leather", "contest")
			play_forge(main.sim, contest_seen == 1)
			main.show_forge_result()
			await f()
		Game.gold = maxi(Game.gold, 400)
		main.end_day()
		await f()
	check(choice_seen, "sabotage choice event on day 9")
	check(contest_seen == 2, "two smithing contests (12 and 24)")
	check(Game.day == 30 and Game.event.get("kind", "") == "champion", "day 30 brings the champion")
	check(Game.dungeon_open(3), "Hollow Spire opened")
	# champion -> good ending
	Game.gold = 5000
	Game.fame = 70
	Game.lv["forge"] = 4
	main.show_forge_select("champion")
	main.sel["type"] = "greatsword"
	main.sel["ore"] = "starmetal"
	main.start_forge("greatsword", "starmetal", "ebony", "champion")
	play_forge(main.sim, true)
	main.show_forge_result()
	await f()
	check(main.screen == "result" and not main.champ_w.is_empty(), "champion blade forged")
	main.finish_champion()
	await f()
	check(main.screen == "ending" and Game.ending["grade"] == "S", "legendary ending (grade %s)" % Game.ending.get("grade", "?"))
	check(not Game.has_save(), "save cleared after ending")
	# bad ending: unpaid debt
	Game.new_game(3)
	Game.gold = 0
	var bad := Game.finish_story(Game.make_weapon("dagger", "copper", "oak", 10))
	check(bad["grade"] == "F", "unpaid debt gives the losing ending")
	# repossession
	Game.new_game(4)
	Game.debt = 3490
	Game.gold = 0
	for i in 7:
		Game.end_day()
	check(Game.over == "repossessed", "unpaid rent past the limit seizes the forge")
	main.show_gameover()
	await f()
	main.toggle_pause()
	main.show_title()
	main.toggle_pause()
	check(main.overlay == null, "pause ignored on title")
	main.new_game()
	main.show_hub()
	main.toggle_pause()
	check(main.paused and main.overlay != null, "pause overlay opens")
	main.toggle_pause()
	check(not main.paused, "pause closes")
	main._layout()
	Game.delete_save()
	print("SMOKE OK" if fails == 0 else "SMOKE FAILED (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
