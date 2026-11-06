class_name Pix
extends RefCounted
## Original pixel art defined as text grids and baked into textures at runtime.

static var cache := {}

const WEAPON := {
	"dagger": [
		"................", "................", "................", "..........WW....", ".........WMD....",
		"........WMD.....", ".......WMD......", "......WMD.......", "...G.WMD........", "....GMD.........",
		".....G..........", "....H.G.........", "...H............", "..P.............", "................", "................"],
	"sword": [
		"..............WW", ".............WMD", "............WMD.", "...........WMD..", "..........WMD...",
		".........WMD....", "........WMD.....", ".......WMD......", "...G..WMD.......", "....GWMD........",
		".....GD.........", "....H.G.........", "...H...G........", "..H.............", ".P..............", "................"],
	"axe": [
		"................", ".........WWW....", "........WMMMW...", ".......WMMMMMD..", ".......MMMMMHD..",
		"........DMMH.D..", "..........H.....", ".........H......", "........H.......", ".......H........",
		"......H.........", ".....H..........", "....H...........", "...H............", "..P.............", "................"],
	"spear": [
		"..............W.", ".............WMW", "............WMD.", "...........WMD..", "..........GD....",
		".........H......", "........H.......", ".......H........", "......H.........", ".....H..........",
		"....H...........", "...H............", "..H.............", ".H..............", "P...............", "................"],
	"mace": [
		"................", "..........D.D...", ".........DMWMD..", "........DMWWMMD.", ".........MMMMD..",
		"........DMMMMMD.", ".........DMHMD..", "..........H.D...", ".........H......", "........H.......",
		".......H........", "......H.........", ".....H..........", "....H...........", "...P............", "................"],
	"greatsword": [
		".............WWW", "............WMMD", "...........WMMD.", "..........WMMD..", ".........WMMD...",
		"........WMMD....", ".......WMMD.....", "......WMMD......", "..G..WMMD.......", "...GWMMD........",
		"....GMD.........", "...H.GG.........", "..H...G.........", ".H..............", "P...............", "................"],
}

const PERSON := [
	"....hhhh....", "...hhhhhh...", "...hssssh...", "...sEssEs...", "...ssssss...", "....smms....",
	"..cccccccc..", ".ccccbbcccc.", ".sccccccccs.", ".s.cccccc.s.", "...cccccc...", "...LLLLLL...",
	"...LL..LL...", "...LL..LL...", "...ee..ee...", "..eee..eee.."]

const HOOD := [
	"...cccccc...", "..cccccccc..", "..cssssssc..", "..sEssssEs..", "..cssssssc..", "...csmmsc...",
	"..cccccccc..", ".ccccbbcccc.", ".sccccccccs.", ".s.cccccc.s.", "...cccccc...", "...LLLLLL...",
	"...LL..LL...", "...LL..LL...", "...ee..ee...", "..eee..eee.."]

const HELM := [
	"....kkkk....", "...kkkkkk...", "...kssssk...", "...sEssEs...", "...ssssss...", "....smms....",
	"..kkcccckk..", ".kccccbbcck.", ".sccccccccs.", ".s.cccccc.s.", "...cccccc...", "...LLLLLL...",
	"...LL..LL...", "...LL..LL...", "...ee..ee...", "..eee..eee.."]

const SMITH := [
	"............", "....hhhh....", "...hssssh...", "...sEssEs...", "...ssssss...", "...bbbbbb...",
	"..sabbbbas..", ".ssaaaaaass.", ".s.aaaaaa.s.", ".s.aaaaaa.s.", "...aaaaaa...", "...LLLLLL...",
	"...LL..LL...", "...LL..LL...", "...ee..ee...", "..eee..eee.."]

const ANVIL := [
	"DDDDDDDDDDDDD...", "MMMMMMMMMMMMMMDD", ".MMMMMMMMMMMMMD.", "....DMMMMMD.....",
	".....DMMMD......", "....DMMMMMD.....", "...DMMMMMMMD....", "...DDDDDDDDD...."]

const GEM := ["..WWW..", ".WGGGD.", "WGGGGGD", "DGGGGGD", ".DGGGD.", "..DGD..", "...D..."]
const ORE := ["...DD...", "..DMMD..", ".DMWMMD.", "DMMMMWMD", "DMWMMMMD", ".DMMMMD.", "..DDDD.."]
const BAR := ["..WWWWWWWW..", ".WMMMMMMMMD.", "DMMMMMMMMMMD", ".DDDDDDDDDD."]

const SKIN := [Color(0.98, 0.82, 0.66), Color(0.87, 0.66, 0.48), Color(0.66, 0.46, 0.3), Color(0.45, 0.3, 0.2)]
const HAIR := [Color(0.2, 0.13, 0.08), Color(0.55, 0.3, 0.12), Color(0.85, 0.7, 0.35), Color(0.6, 0.6, 0.62), Color(0.7, 0.2, 0.12), Color(0.1, 0.1, 0.12)]
const CLOTH := [Color(0.55, 0.2, 0.25), Color(0.2, 0.4, 0.55), Color(0.3, 0.5, 0.3), Color(0.55, 0.45, 0.2), Color(0.45, 0.3, 0.55), Color(0.6, 0.35, 0.2)]

static func make(rows: Array, pal: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w: int = rows[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var r: String = rows[y]
		for x in w:
			var ch := r[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)

static func weapon(type: String, ore: String, mat: String, gem: String = "") -> ImageTexture:
	var key := "w_%s_%s_%s_%s" % [type, ore, mat, gem]
	if cache.has(key):
		return cache[key]
	var oc: Color = D.ORES[ore]["col"]
	var mc: Color = D.MATS[mat]["col"]
	var gc: Color = Color(0.85, 0.65, 0.25) if gem == "" else D.GEMS[gem]["col"]
	var t := make(WEAPON[type], {"M": oc, "W": oc.lightened(0.45), "D": oc.darkened(0.4), "H": mc, "G": gc, "P": mc.darkened(0.35)})
	cache[key] = t
	return t

static func person(seed_val: int, kind: String = "", cls_col: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var key := "p_%d_%s" % [seed_val, kind]
	if cache.has(key):
		return cache[key]
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var skin: Color = SKIN[r.randi() % SKIN.size()]
	var cloth: Color = CLOTH[r.randi() % CLOTH.size()] if cls_col.a == 0.0 else cls_col
	var pal := {"h": HAIR[r.randi() % HAIR.size()], "s": skin, "E": Color(0.1, 0.08, 0.1), "m": skin.darkened(0.3),
		"c": cloth, "b": Color(0.85, 0.7, 0.3), "L": Color(0.3, 0.25, 0.22), "e": Color(0.2, 0.14, 0.1), "k": Color(0.7, 0.72, 0.78)}
	var rows: Array = PERSON
	if kind == "rogue" or kind == "cleric" or (kind == "" and r.randf() < 0.25):
		rows = HOOD
	elif kind == "knight" or kind == "barbarian":
		rows = HELM
	var t := make(rows, pal)
	cache[key] = t
	return t

static func smith() -> ImageTexture:
	if not cache.has("smith"):
		cache["smith"] = make(SMITH, {"h": Color(0.45, 0.22, 0.1), "s": Color(0.92, 0.72, 0.55), "E": Color(0.1, 0.08, 0.1),
			"b": Color(0.6, 0.3, 0.12), "a": Color(0.42, 0.3, 0.22), "L": Color(0.25, 0.22, 0.2), "e": Color(0.18, 0.12, 0.08)})
	return cache["smith"]

static func anvil() -> ImageTexture:
	if not cache.has("anvil"):
		cache["anvil"] = make(ANVIL, {"M": Color(0.35, 0.36, 0.42), "D": Color(0.18, 0.18, 0.22)})
	return cache["anvil"]

static func gem(id: String) -> ImageTexture:
	var key := "g_" + id
	if not cache.has(key):
		var c: Color = D.GEMS[id]["col"]
		cache[key] = make(GEM, {"G": c, "W": c.lightened(0.6), "D": c.darkened(0.45)})
	return cache[key]

static func ore(id: String) -> ImageTexture:
	var key := "o_" + id
	if not cache.has(key):
		var c: Color = D.ORES[id]["col"]
		cache[key] = make(ORE, {"M": c, "W": c.lightened(0.5), "D": c.darkened(0.5)})
	return cache[key]

static func bar(c: Color) -> ImageTexture:
	var key := "b_" + c.to_html()
	if not cache.has(key):
		cache[key] = make(BAR, {"M": c, "W": c.lightened(0.4), "D": c.darkened(0.4)})
	return cache[key]

## Glowing-metal colour for a heat value 0..1.
static func heat_col(h: float) -> Color:
	var stops := [[0.0, Color(0.28, 0.26, 0.27)], [0.25, Color(0.45, 0.12, 0.08)], [0.42, Color(0.8, 0.12, 0.06)],
		[0.58, Color(1.0, 0.45, 0.08)], [0.74, Color(1.0, 0.8, 0.2)], [0.9, Color(1.0, 0.97, 0.75)], [1.1, Color(0.85, 0.95, 1.0)]]
	for i in stops.size() - 1:
		var a: float = stops[i][0]
		var b: float = stops[i + 1][0]
		if h <= b:
			return (stops[i][1] as Color).lerp(stops[i + 1][1], clampf((h - a) / (b - a), 0.0, 1.0))
	return stops[-1][1]

static func heat_name(h: float) -> String:
	if h < 0.25: return "cold"
	if h < 0.42: return "dull red"
	if h < 0.55: return "cherry red"
	if h < 0.68: return "orange"
	if h < 0.82: return "yellow"
	if h < 0.95: return "white"
	return "burning!"
