extends Node
## Game state and rules for Blade & Bellows. Rendering-free so it can be smoke-tested headless.

signal changed

const SAVE := "user://blade_bellows_save.json"
const META := "user://blade_bellows_meta.json"
const DAY_HOURS := 8
const FORGE_HOURS := 2
const SHOP_HOURS := 3
const LAST_DAY := 30
const DEBT_START := 2000
const DEBT_LIMIT := 3500
const CHAMPION_NEED := 80.0

var rng := RandomNumberGenerator.new()
var sound_on := true
var music_on := true

var day := 1
var hours := DAY_HOURS
var gold := 160
var fame := 0
var debt := DEBT_START
var ores := {}
var mats := {}
var gems := {}
var weapons: Array = []
var next_id := 1
var lv := {"forge": 1, "anvil": 1, "shop": 1}
var advs: Array = []
var quests: Array = []
var tales: Array = []
var today := {}
var price_war := 0
var stats := {"forged": 0, "sold": 0, "earned": 0, "best": 0, "deaths": 0, "quests": 0, "contests": 0}
var morning: Array = []
var event := {}
var over := ""          # "", "repossessed", "ending"
var ending := {}
var meta := {"best_grade": "", "runs": 0, "best_gold": 0}

func _ready() -> void:
	rng.randomize()
	load_meta()

# ---------------------------------------------------------------- new game
func new_game(seed_val: int = -1) -> void:
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	day = 1
	hours = DAY_HOURS
	gold = 160
	fame = 0
	debt = DEBT_START
	ores = {"copper": 3, "iron": 4}
	mats = {"oak": 4, "leather": 1}
	gems = {}
	weapons = []
	next_id = 1
	lv = {"forge": 1, "anvil": 1, "shop": 1}
	advs = []
	quests = []
	tales = []
	today = {}
	price_war = 0
	stats = {"forged": 0, "sold": 0, "earned": 0, "best": 0, "deaths": 0, "quests": 0, "contests": 0}
	over = ""
	ending = {}
	weapons.append(make_weapon("sword", "iron", "oak", 48))
	weapons.append(make_weapon("dagger", "copper", "oak", 40))
	for i in 3:
		advs.append(make_adv(1))
	morning = D.STORY[1].duplicate()
	event = {}
	changed.emit()

func lvl(k: String) -> int:
	return int(lv.get(k, 1))

# ---------------------------------------------------------------- weapons
func tier_of(score: float) -> int:
	var t := 0
	for i in D.TIERS.size():
		if score >= float(D.TIERS[i]["min"]):
			t = i
	return t

func tier_name(score: float) -> String:
	return D.TIERS[tier_of(score)]["name"]

func tier_col(score: float) -> Color:
	return D.TIERS[tier_of(score)]["col"]

func make_weapon(type: String, ore: String, mat: String, score: int, gem: String = "") -> Dictionary:
	var w := {"id": next_id, "type": type, "ore": ore, "mat": mat, "score": score, "gem": gem}
	next_id += 1
	return w

func power(w: Dictionary) -> float:
	var o: Dictionary = D.ORES[w["ore"]]
	var t: Dictionary = D.TYPES[w["type"]]
	var m: Dictionary = D.MATS[w["mat"]]
	var p: float = float(o["power"]) * float(t["mult"]) * (0.55 + 0.9 * float(w["score"]) / 100.0) + float(m["power"])
	match str(w.get("gem", "")):
		"ruby": p *= 1.25
		"sapphire": p *= 1.12
		"topaz": p *= 1.1
	return snappedf(p, 0.1)

func value(w: Dictionary) -> int:
	var m: Dictionary = D.MATS[w["mat"]]
	var v: float = power(w) * 6.0 * float(m["mult"])
	if str(w.get("gem", "")) != "":
		v += 35.0
		if w["gem"] == "emerald":
			v *= 1.15
	return int(round(v))

func wname(w: Dictionary) -> String:
	var s: String = tier_name(w["score"]) + " " + D.ORES[w["ore"]]["name"] + " " + D.TYPES[w["type"]]["name"]
	if str(w.get("gem", "")) != "":
		s += " of " + D.GEMS[w["gem"]]["ench"]
	return s

func find_weapon(id: int) -> Dictionary:
	for w in weapons:
		if int(w["id"]) == id:
			return w
	return {}

func remove_weapon(id: int) -> void:
	for i in weapons.size():
		if int(weapons[i]["id"]) == id:
			weapons.remove_at(i)
			return

func enchant(w: Dictionary, gem: String) -> bool:
	if w.is_empty() or str(w.get("gem", "")) != "" or int(gems.get(gem, 0)) <= 0:
		return false
	gems[gem] = int(gems[gem]) - 1
	w["gem"] = gem
	changed.emit()
	return true

# ---------------------------------------------------------------- forging
func ore_ok(ore: String) -> bool:
	return lvl("forge") >= int(D.ORES[ore]["forge"])

func mat_ok(mat: String) -> bool:
	return lvl("shop") >= int(D.MATS[mat]["shop"])

## Why a recipe can't be forged right now ("" if it can). free = contest/champion stores.
func forge_block(type: String, ore: String, mat: String, free: bool = false) -> String:
	if not ore_ok(ore):
		return "Upgrade the forge to work " + D.ORES[ore]["name"]
	if free:
		return ""
	if hours < FORGE_HOURS:
		return "Not enough daylight left (needs %dh)" % FORGE_HOURS
	if int(ores.get(ore, 0)) < int(D.TYPES[type]["bars"]):
		return "Needs %d %s bar(s)" % [int(D.TYPES[type]["bars"]), D.ORES[ore]["name"]]
	if int(mats.get(mat, 0)) < 1:
		return "Needs a " + D.MATS[mat]["name"]
	return ""

func begin_forge(type: String, ore: String, mat: String, free: bool = false) -> Dictionary:
	if forge_block(type, ore, mat, free) != "":
		return {}
	if not free:
		ores[ore] = int(ores[ore]) - int(D.TYPES[type]["bars"])
		mats[mat] = int(mats[mat]) - 1
		hours -= FORGE_HOURS
	changed.emit()
	return forge_params(type, ore)

func forge_params(type: String, ore: String) -> Dictionary:
	var o: Dictionary = D.ORES[ore]
	var f := lvl("forge") - 1
	var a := lvl("anvil") - 1
	return {
		"target": float(o["heat"]), "band": float(o["band"]) + 0.025 * f, "cool": 1.0 - 0.15 * f, "pump": 1.0,
		"strikes": maxi(2, int(o["strikes"]) + int(D.TYPES[type]["smod"])),
		"sweet": 0.075 * (1.0 + 0.28 * a), "speed": float(o["speed"]) * (1.0 - 0.1 * a),
		"qtarget": 0.33, "qwin": 0.07 + 0.015 * f, "qspeed": 1.0,
	}

func finish_forge(type: String, ore: String, mat: String, score: int, keep: bool = true) -> Dictionary:
	var w := make_weapon(type, ore, mat, clampi(score, 0, 100))
	stats["forged"] = int(stats["forged"]) + 1
	stats["best"] = maxi(int(stats["best"]), score)
	if keep:
		weapons.append(w)
		if score >= 84:
			add_fame(2)
	changed.emit()
	return w

# ---------------------------------------------------------------- market
func price(kind: String, id: String) -> int:
	var p := 0
	match kind:
		"ore":
			p = int(D.ORES[id]["cost"])
			if today.get("caravan", false):
				p = int(round(p * 0.75))
		"mat":
			p = int(D.MATS[id]["cost"])
		"gem":
			p = int(D.GEMS[id]["cost"])
			if today.get("peddler", false):
				p = int(round(p * 0.7))
	return p

func can_buy(kind: String, id: String) -> bool:
	if kind == "ore" and not ore_ok(id):
		return false
	if kind == "mat" and not mat_ok(id):
		return false
	return gold >= price(kind, id)

func buy(kind: String, id: String, qty: int = 1) -> int:
	var got := 0
	for i in qty:
		if not can_buy(kind, id):
			break
		gold -= price(kind, id)
		var bag: Dictionary = ores if kind == "ore" else (mats if kind == "mat" else gems)
		bag[id] = int(bag.get(id, 0)) + 1
		got += 1
	if got > 0:
		changed.emit()
	return got

# ---------------------------------------------------------------- upgrades / debt
func upgrade_cost(k: String) -> int:
	var l := lvl(k)
	var costs: Array = D.UPGRADES[k]["costs"]
	return -1 if l >= costs.size() else int(costs[l])

func upgrade(k: String) -> bool:
	var c := upgrade_cost(k)
	if c < 0 or gold < c:
		return false
	gold -= c
	lv[k] = lvl(k) + 1
	add_fame(2)
	changed.emit()
	return true

func pay_debt(amount: int) -> int:
	var a := mini(mini(amount, gold), debt)
	if a <= 0:
		return 0
	gold -= a
	debt -= a
	changed.emit()
	return a

func add_fame(n: int) -> void:
	fame = clampi(fame + n, 0, 100)

func fame_title() -> String:
	if fame >= 80: return "Legendary"
	if fame >= 60: return "Renowned"
	if fame >= 40: return "Respected"
	if fame >= 20: return "Known"
	return "Unknown"

# ---------------------------------------------------------------- shop
func customer_count() -> int:
	return clampi(3 + (lvl("shop") - 1) + int(today.get("cust", 0)), 1, 7)

func make_customer() -> Dictionary:
	var keys := D.PERS.keys()
	var pk: String = keys[rng.randi() % keys.size()]
	var pd: Dictionary = D.PERS[pk]
	var budget: float = (50.0 + fame * 5.0 + day * 8.0) * rng.randf_range(0.7, 1.5)
	if pk == "noble":
		budget *= 1.6
	elif pk == "apprentice":
		budget *= 0.6
	var wants := ""
	if rng.randf() < 0.65:
		wants = D.TYPE_ORDER[rng.randi() % D.TYPE_ORDER.size()]
	var hello: Array = pd["hello"]
	return {"name": D.FIRST[rng.randi() % D.FIRST.size()], "pers": pk, "wants": wants, "budget": int(budget),
		"patience": int(pd["patience"]), "mood": 1.0, "haggles": 0, "offer": 0, "wid": -1,
		"seed": rng.randi() % 100000, "hello": hello[rng.randi() % hello.size()]}

func start_shop() -> Array:
	if hours < SHOP_HOURS or weapons.is_empty():
		return []
	hours -= SHOP_HOURS
	var list: Array = []
	for i in customer_count():
		list.append(make_customer())
	changed.emit()
	return list

func offer_for(c: Dictionary, w: Dictionary) -> int:
	var pk: String = c["pers"]
	var t := tier_of(w["score"])
	if pk == "collector" and t < 2:
		return 0
	var m: float = float(D.PERS[pk]["base"]) * (1.0 + fame / 250.0) * (1.0 + 0.06 * (lvl("shop") - 1))
	if c["wants"] == w["type"]:
		m *= 1.15
	elif c["wants"] != "":
		m *= 0.85
	if pk == "veteran":
		m *= 0.85 + 0.1 * t
	if pk == "collector" and str(w.get("gem", "")) != "":
		m *= 1.35
	if price_war > 0:
		m *= 0.85
	var o: float = value(w) * m * float(c["mood"])
	return maxi(1, mini(int(round(o)), int(c["budget"])))

func show_weapon(c: Dictionary, w: Dictionary) -> int:
	c["wid"] = int(w["id"])
	c["offer"] = offer_for(c, w)
	return int(c["offer"])

## Returns {"ok": bool, "left": bool, "offer": int}
func haggle(c: Dictionary) -> Dictionary:
	var pd: Dictionary = D.PERS[c["pers"]]
	var chance: float = float(pd["succ"]) - 0.1 * int(c["haggles"]) + fame / 400.0
	if int(c["offer"]) >= int(c["budget"]):
		chance = 0.08
	c["haggles"] = int(c["haggles"]) + 1
	if rng.randf() < chance:
		c["offer"] = mini(int(ceil(int(c["offer"]) * (1.0 + float(pd["gain"])))), int(c["budget"]))
		return {"ok": true, "left": false, "offer": c["offer"]}
	c["patience"] = int(c["patience"]) - 1
	c["mood"] = float(c["mood"]) - 0.05
	c["offer"] = maxi(1, int(int(c["offer"]) * 0.97))
	var left := int(c["patience"]) <= 0
	if left:
		add_fame(-1)
	return {"ok": false, "left": left, "offer": c["offer"]}

func sell(c: Dictionary) -> int:
	var w := find_weapon(int(c["wid"]))
	if w.is_empty():
		return 0
	var p := int(c["offer"])
	gold += p
	stats["sold"] = int(stats["sold"]) + 1
	stats["earned"] = int(stats["earned"]) + p
	if tier_of(w["score"]) >= 2:
		add_fame(1)
	if c["pers"] == "bard":
		add_fame(2)
	remove_weapon(int(w["id"]))
	changed.emit()
	return p

# ---------------------------------------------------------------- adventurers
func make_adv(level: int) -> Dictionary:
	var ck := D.CLASSES.keys()
	var nm: String = D.FIRST[rng.randi() % D.FIRST.size()] + " " + D.EPITHET[rng.randi() % D.EPITHET.size()]
	return {"id": rng.randi() % 1000000, "name": nm, "cls": ck[rng.randi() % ck.size()], "lvl": level, "busy": false, "seed": rng.randi() % 100000}

func dungeon_open(i: int) -> bool:
	return day >= int(D.DUNGEONS[i]["day"])

func odds(a: Dictionary, w: Dictionary, di: int) -> Dictionary:
	var dg: Dictionary = D.DUNGEONS[di]
	var eff: float = power(w)
	if D.TYPES[w["type"]]["classes"].has(a["cls"]):
		eff *= 1.15
	eff += int(a["lvl"]) * 3.0
	var ratio: float = eff / float(dg["danger"])
	var succ := clampf((ratio - 0.45) * 1.05, 0.05, 0.95)
	var dfail := clampf((1.15 - ratio) * 0.8, 0.03, 0.85)
	match str(w.get("gem", "")):
		"amethyst": dfail *= 0.5
		"sapphire": dfail *= 0.8
	return {"succ": succ, "death": (1.0 - succ) * dfail, "match": D.TYPES[w["type"]]["classes"].has(a["cls"])}

func commission(adv_id: int, wid: int, di: int) -> bool:
	var a := find_adv(adv_id)
	var w := find_weapon(wid)
	if a.is_empty() or w.is_empty() or a["busy"] or not dungeon_open(di):
		return false
	var o := odds(a, w, di)
	var days := int(D.DUNGEONS[di]["days"])
	if w.get("gem", "") == "topaz":
		days = maxi(1, days - 1)
	a["busy"] = true
	quests.append({"adv": adv_id, "w": w.duplicate(), "d": di, "left": days, "succ": o["succ"], "death": o["death"]})
	remove_weapon(wid)
	changed.emit()
	return true

func find_adv(id: int) -> Dictionary:
	for a in advs:
		if int(a["id"]) == id:
			return a
	return {}

func _resolve_quest(q: Dictionary) -> String:
	var a := find_adv(int(q["adv"]))
	var dg: Dictionary = D.DUNGEONS[int(q["d"])]
	var w: Dictionary = q["w"]
	var foes: Array = dg["foe"]
	var foe: String = foes[rng.randi() % foes.size()]
	var wn: String = D.TYPES[w["type"]]["name"].to_lower()
	var r := rng.randf()
	a["busy"] = false
	stats["quests"] = int(stats["quests"]) + 1
	if r < float(q["succ"]):
		var emer: bool = w.get("gem", "") == "emerald"
		var g := int(rng.randi_range(int(dg["gold"][0]), int(dg["gold"][1])) * (1.6 if emer else 1.0))
		gold += g
		var dores: Array = dg["ores"]
		var nb := rng.randi_range(1, 2) + (1 if emer else 0)
		var got: Array = []
		for i in nb:
			var o: String = dores[rng.randi() % dores.size()]
			ores[o] = int(ores.get(o, 0)) + 1
			got.append(D.ORES[o]["name"])
		if rng.randf() < (0.65 if emer else 0.35):
			var dgems: Array = dg["gems"]
			var gm: String = dgems[rng.randi() % dgems.size()]
			gems[gm] = int(gems.get(gm, 0)) + 1
			got.append(D.GEMS[gm]["name"])
		add_fame(int(dg["fame"]) + tier_of(w["score"]) / 2)
		a["lvl"] = mini(10, int(a["lvl"]) + 1)
		var tale: String = D.TALE_WIN[rng.randi() % D.TALE_WIN.size()]
		var txt: String = (tale % [a["name"], foe, wn]) if tale.count("%s") == 3 else (tale % [a["name"], foe])
		_tale(txt)
		return "%s returns from the %s! +%dg, %s. (Lv %d)" % [a["name"], dg["name"], g, ", ".join(got), int(a["lvl"])]
	if r < float(q["succ"]) + float(q["death"]):
		advs.erase(a)
		add_fame(-5)
		stats["deaths"] = int(stats["deaths"]) + 1
		_tale("%s fell to %s in the %s. Their %s was not enough." % [a["name"], foe, dg["name"], wn])
		return "%s died in the %s. Bad steel costs lives. (-5 fame)" % [a["name"], dg["name"]]
	_tale("%s was driven back from the %s by %s." % [a["name"], dg["name"], foe])
	return "%s limps back from the %s empty-handed. The %s was lost." % [a["name"], dg["name"], wn]

func _tale(t: String) -> void:
	tales.push_front("Day %d: %s" % [day, t])
	if tales.size() > 12:
		tales.resize(12)

func refresh_guild() -> void:
	var cap := clampi(3 + fame / 25, 3, 6)
	while advs.size() < cap:
		advs.append(make_adv(clampi(1 + fame / 20 + rng.randi_range(0, 1), 1, 8)))

# ---------------------------------------------------------------- days & events
func rent_due() -> int:
	return 40 + 20 * (day / 7)

func end_day() -> Array:
	var rep: Array = []
	day += 1
	hours = DAY_HOURS
	if price_war > 0:
		price_war -= 1
	today = {}
	event = {}
	# quests
	var still: Array = []
	for q in quests:
		q["left"] = int(q["left"]) - 1
		if int(q["left"]) <= 0:
			rep.append(_resolve_quest(q))
		else:
			still.append(q)
	quests = still
	# weekly rent
	if (day - 1) % 7 == 0 and day > 1:
		var r := rent_due()
		if gold >= r:
			gold -= r
			rep.append("Rent day: paid %dg to the landlord." % r)
		else:
			debt += r + 25
			add_fame(-3)
			rep.append("Rent day: you couldn't pay! %dg added to your debt." % (r + 25))
	if day % 3 == 1:
		refresh_guild()
	# story and events
	if D.STORY.has(day):
		rep.append_array(D.STORY[day])
	match day:
		4:
			price_war = 2
		9:
			event = {"kind": "choice", "text": "Vorn's thugs were seen near your coal shed last night.",
				"opts": [["Hire a night watchman (40g)", "guard"], ["Ignore it", "ignore"]]}
		12:
			event = {"kind": "contest", "type": "sword", "ore": "iron", "rival": 64}
		18:
			if fame < 35 and _idle_adv() != -1:
				var i := _idle_adv()
				rep.append("%s took Vorn's free ale and joined his side. (Earn 35 fame to keep your adventurers loyal.)" % advs[i]["name"])
				advs.remove_at(i)
			else:
				rep.append("Your adventurers laugh Vorn out of the tavern. They're loyal to Blade & Bellows.")
		24:
			event = {"kind": "contest", "type": "greatsword", "ore": "silver" if ore_ok("silver") else "iron", "rival": 79}
		27:
			if fame >= 60:
				rep.append("Nobody believes him. Your name is too well known.")
			else:
				add_fame(-6)
				rep.append("Some customers believe it. (-6 fame)")
		30:
			event = {"kind": "champion"}
		_:
			if not D.STORY.has(day):
				_random_event(rep)
	if debt >= DEBT_LIMIT:
		over = "repossessed"
		rep.append("Guildmaster Hesk arrives with two guards. Your debt is too great: the forge is seized.")
	morning = rep
	save_game()
	changed.emit()
	return rep

func _idle_adv() -> int:
	for i in advs.size():
		if not advs[i]["busy"]:
			return i
	return -1

func _random_event(rep: Array) -> void:
	var r := rng.randf()
	if r < 0.14:
		today["caravan"] = true
		rep.append("A dwarven caravan is in town: ore is 25% cheaper today.")
	elif r < 0.26:
		today["cust"] = 2
		rep.append("Market day! Two extra customers will visit the shop.")
	elif r < 0.36:
		today["cust"] = -1
		rep.append("Rain lashes Emberfall. Fewer customers today.")
	elif r < 0.46:
		today["peddler"] = true
		rep.append("A gem peddler sets up outside: gems are 30% cheaper today.")
	elif r < 0.56:
		var o: String = ["copper", "iron", "iron", "silver"][rng.randi() % 4]
		ores[o] = int(ores.get(o, 0)) + 2
		rep.append("Your neighbour clears out his cellar and gives you 2 %s bars." % D.ORES[o]["name"])

func resolve_choice(opt: String) -> String:
	event = {}
	match opt:
		"guard":
			if gold >= 40:
				gold -= 40
				changed.emit()
				return "The watchman chases off two masked figures. Your coal is safe."
			hours -= 2
			changed.emit()
			return "You can't afford a watchman. By morning your coal is soaked: you lose 2 hours drying it."
		"ignore":
			hours -= 2
			changed.emit()
			return "Your coal is soaked by morning. You lose 2 hours drying it."
	return ""

func contest_result(score: int, rival: int) -> Dictionary:
	event = {}
	stats["contests"] = int(stats["contests"]) + 1
	if score > rival:
		add_fame(15)
		gold += 150
		changed.emit()
		return {"won": true, "text": "The judges raise your blade high! You beat Vorn (%d vs %d). +150 gold, +15 fame." % [score, rival]}
	add_fame(-4)
	changed.emit()
	return {"won": false, "text": "Vorn's blade wins (%d vs %d). He smirks all the way home. -4 fame." % [rival, score]}

func champion_power(w: Dictionary) -> float:
	return power(w) + 20.0 + fame / 10.0

func finish_story(w: Dictionary) -> Dictionary:
	var paid := false
	if debt > 0 and gold >= debt:
		gold -= debt
		debt = 0
	paid = debt <= 0
	var cp := champion_power(w)
	var won := cp >= CHAMPION_NEED
	var grade := "C"
	var title := ""
	var text := ""
	if not paid:
		grade = "F"
		title = "The Forge Goes Cold"
		text = "You still owe Hesk %dg. %s The shutters of Blade & Bellows close for good." % [debt,
			"Aveline triumphs with your blade, but songs don't pay debts." if won else "Aveline returns from the Spire wounded, and the town forgets your name."]
	elif won and fame >= 60:
		grade = "S"
		title = "Legend of Emberfall"
		text = "Aveline's %s splits the Hollow Warden's crown. The Spire falls silent. Pilgrims come from every kingdom to see the forge that made it." % wname(w)
	elif won:
		grade = "A"
		title = "The Champion's Smith"
		text = "Aveline returns at dusk, battered, holding your %s aloft. The Spire is sealed. Your debt is paid and your name is made." % wname(w)
	else:
		grade = "B"
		title = "A Smith Who Endured"
		text = "Your %s cracks against the Warden's shell (power %d of %d needed). Aveline survives and the debt is paid, but the Spire still looms." % [wname(w), int(cp), int(CHAMPION_NEED)]
	over = "ending"
	ending = {"grade": grade, "title": title, "text": text, "won": won, "paid": paid, "power": cp}
	meta["runs"] = int(meta.get("runs", 0)) + 1
	var order := "FCBAS"
	if order.find(grade) > order.find(str(meta.get("best_grade", ""))) or str(meta.get("best_grade", "")) == "":
		meta["best_grade"] = grade
	meta["best_gold"] = maxi(int(meta.get("best_gold", 0)), int(stats["earned"]))
	save_meta()
	delete_save()
	changed.emit()
	return ending

# ---------------------------------------------------------------- save / load
func state() -> Dictionary:
	return {"v": 1, "day": day, "hours": hours, "gold": gold, "fame": fame, "debt": debt, "ores": ores, "mats": mats,
		"gems": gems, "weapons": weapons, "next_id": next_id, "lv": lv, "advs": advs, "quests": quests, "tales": tales,
		"today": today, "price_war": price_war, "stats": stats, "morning": morning, "event": event}

func save_game() -> bool:
	if over != "":
		return false
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state()))
	f.close()
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = int(d[k])
	return out

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	day = int(data["day"]); hours = int(data["hours"]); gold = int(data["gold"]); fame = int(data["fame"]); debt = int(data["debt"])
	ores = _ints(data["ores"]); mats = _ints(data["mats"]); gems = _ints(data["gems"]); lv = _ints(data["lv"])
	stats = _ints(data["stats"])
	next_id = int(data["next_id"]); price_war = int(data["price_war"])
	weapons = []
	for w in data["weapons"]:
		weapons.append(_fix_w(w))
	advs = []
	for a in data["advs"]:
		advs.append({"id": int(a["id"]), "name": a["name"], "cls": a["cls"], "lvl": int(a["lvl"]), "busy": bool(a["busy"]), "seed": int(a["seed"])})
	quests = []
	for q in data["quests"]:
		quests.append({"adv": int(q["adv"]), "w": _fix_w(q["w"]), "d": int(q["d"]), "left": int(q["left"]), "succ": float(q["succ"]), "death": float(q["death"])})
	tales = data["tales"]
	today = data["today"]
	morning = data.get("morning", [])
	event = data.get("event", {})
	if event.has("rival"):
		event["rival"] = int(event["rival"])
	over = ""
	changed.emit()
	return true

func _fix_w(w: Dictionary) -> Dictionary:
	return {"id": int(w["id"]), "type": w["type"], "ore": w["ore"], "mat": w["mat"], "score": int(w["score"]), "gem": str(w.get("gem", ""))}

func load_meta() -> void:
	if not FileAccess.file_exists(META):
		return
	var f := FileAccess.open(META, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		meta = data
		if data.has("sound"):
			sound_on = bool(data["sound"])
		if data.has("music"):
			music_on = bool(data["music"])

func save_meta() -> void:
	meta["sound"] = sound_on
	meta["music"] = music_on
	var f := FileAccess.open(META, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))
		f.close()
