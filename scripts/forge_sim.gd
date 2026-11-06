class_name ForgeSim
extends RefCounted
## The hands-on forging minigame as pure logic: HEAT (pump the bellows to the right colour),
## HAMMER (timed strikes on a swinging marker) and QUENCH (plunge at the right glow).

var p: Dictionary
var phase := "heat"     # heat, hammer, quench, done
var heat := 0.12
var pumping := false
var t := 0.0
var heat_score := 0.0
var strikes: Array = []
var marker := 0.0
var mdir := 1.0
var needle := 1.0
var quench_score := 0.0
var score := 0
var last := ""
var events: Array = []

func _init(params: Dictionary) -> void:
	p = params

func step(dt: float) -> void:
	t += dt
	match phase:
		"heat":
			if pumping:
				heat += dt * 0.36 * float(p["pump"])
			heat -= dt * 0.06 * float(p["cool"]) * (0.4 + heat)
			heat = clampf(heat, 0.0, 1.08)
		"hammer":
			heat = maxf(0.0, heat - dt * 0.035 * float(p["cool"]))
			marker += mdir * dt * float(p["speed"]) * (1.0 + 0.05 * strikes.size())
			if marker > 1.0:
				marker = 2.0 - marker
				mdir = -1.0
			elif marker < 0.0:
				marker = -marker
				mdir = 1.0
		"quench":
			needle -= dt * 0.5 * float(p["qspeed"])
			if needle <= 0.0:
				needle = 0.0
				quench_score = 0.0
				last = "Too late! The blade cooled in the air."
				events.append("quench_bad")
				_finish()

## Heat colour quality: 1.0 dead-centre of the target window, falling off outside it.
func heat_quality(h: float) -> float:
	var d := absf(h - float(p["target"]))
	var half := float(p["band"]) * 0.5
	if d <= half:
		return 1.0 - 0.25 * d / half
	return clampf(0.75 - (d - half) * 3.0, 0.0, 0.75)

func in_band() -> bool:
	return absf(heat - float(p["target"])) <= float(p["band"]) * 0.5

func to_anvil() -> void:
	if phase != "heat":
		return
	heat_score = heat_quality(heat)
	if heat > float(p["target"]) + float(p["band"]) * 0.5 + 0.12:
		last = "Overheated! The metal is scorched."
	elif in_band():
		last = "Perfect colour!"
	elif heat < float(p["target"]):
		last = "A little cold..."
	else:
		last = "A little hot..."
	phase = "hammer"
	marker = 0.0
	mdir = 1.0
	events.append("anvil")

func strike() -> void:
	if phase != "hammer":
		return
	var d := absf(marker - 0.5)
	var sw := float(p["sweet"])
	var q := 0.1
	var kind := "miss"
	if d <= sw * 0.45:
		q = 1.0
		kind = "perfect"
	elif d <= sw:
		q = 0.8
		kind = "good"
	elif d <= sw * 2.3:
		q = 0.45
		kind = "ok"
	if heat < float(p["target"]) - 0.28:
		q *= 0.6
		kind += "_cold"
	strikes.append(q)
	last = {"perfect": "PERFECT!", "good": "Good strike", "ok": "Glancing blow", "miss": "Miss!"}.get(kind.split("_")[0], "")
	if kind.ends_with("_cold"):
		last += " (metal too cold)"
	events.append("strike_" + kind.split("_")[0])
	if strikes.size() >= int(p["strikes"]):
		phase = "quench"
		needle = 1.0
		events.append("lift")

func quench() -> void:
	if phase != "quench":
		return
	var d := absf(needle - float(p["qtarget"]))
	var w := float(p["qwin"])
	if d <= w * 0.5:
		quench_score = 1.0
		last = "Flawless quench!"
	elif d <= w:
		quench_score = 0.8
		last = "Good quench"
	else:
		quench_score = clampf(0.7 - (d - w) * 3.0, 0.0, 0.7)
		last = "Too early - the steel cracks a little" if needle > float(p["qtarget"]) else "Too late - the temper is soft"
	events.append("quench")
	_finish()

func hammer_avg() -> float:
	if strikes.is_empty():
		return 0.0
	var s := 0.0
	for q in strikes:
		s += float(q)
	return s / strikes.size()

func _finish() -> void:
	score = int(round(100.0 * (0.3 * heat_score + 0.5 * hammer_avg() + 0.2 * quench_score)))
	phase = "done"
	events.append("done")

## Primary action (space / tap / button) for the current phase, except pumping which is held.
func primary() -> void:
	match phase:
		"hammer":
			strike()
		"quench":
			quench()
