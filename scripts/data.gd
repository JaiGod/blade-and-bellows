class_name D
extends RefCounted
## Static game data for Blade & Bellows: ores, fittings, weapon types, gems,
## quality tiers, customers, adventurers, dungeons and the 30-day story.

const ORE_ORDER := ["copper", "iron", "silver", "mithril", "starmetal"]
const ORES := {
	"copper": {"name": "Copper", "col": Color(0.85, 0.5, 0.28), "power": 6.0, "cost": 8, "heat": 0.45, "band": 0.17, "strikes": 3, "forge": 1, "speed": 1.0},
	"iron": {"name": "Iron", "col": Color(0.62, 0.65, 0.7), "power": 10.0, "cost": 14, "heat": 0.6, "band": 0.15, "strikes": 4, "forge": 1, "speed": 1.1},
	"silver": {"name": "Silver", "col": Color(0.86, 0.9, 0.96), "power": 16.0, "cost": 26, "heat": 0.52, "band": 0.13, "strikes": 4, "forge": 2, "speed": 1.2},
	"mithril": {"name": "Mithril", "col": Color(0.55, 0.85, 0.95), "power": 26.0, "cost": 46, "heat": 0.74, "band": 0.12, "strikes": 5, "forge": 3, "speed": 1.3},
	"starmetal": {"name": "Starmetal", "col": Color(0.75, 0.58, 1.0), "power": 38.0, "cost": 78, "heat": 0.87, "band": 0.1, "strikes": 6, "forge": 4, "speed": 1.4},
}

const MAT_ORDER := ["oak", "leather", "bone", "ebony"]
const MATS := {
	"oak": {"name": "Oak Haft", "col": Color(0.6, 0.42, 0.24), "power": 0.0, "mult": 1.0, "cost": 4, "shop": 1},
	"leather": {"name": "Leather Grip", "col": Color(0.45, 0.28, 0.18), "power": 1.0, "mult": 1.08, "cost": 9, "shop": 1},
	"bone": {"name": "Wyrmbone Grip", "col": Color(0.92, 0.88, 0.74), "power": 3.0, "mult": 1.18, "cost": 22, "shop": 2},
	"ebony": {"name": "Ebonwood Haft", "col": Color(0.22, 0.16, 0.2), "power": 5.0, "mult": 1.3, "cost": 38, "shop": 3},
}

const TYPE_ORDER := ["dagger", "sword", "axe", "spear", "mace", "greatsword"]
const TYPES := {
	"dagger": {"name": "Dagger", "bars": 1, "mult": 0.72, "smod": -1, "classes": ["rogue"]},
	"sword": {"name": "Sword", "bars": 2, "mult": 1.0, "smod": 0, "classes": ["knight", "ranger"]},
	"axe": {"name": "Battle Axe", "bars": 2, "mult": 1.1, "smod": 0, "classes": ["barbarian"]},
	"spear": {"name": "Spear", "bars": 2, "mult": 0.96, "smod": 0, "classes": ["ranger", "knight"]},
	"mace": {"name": "Mace", "bars": 2, "mult": 1.05, "smod": 1, "classes": ["cleric"]},
	"greatsword": {"name": "Greatsword", "bars": 3, "mult": 1.45, "smod": 2, "classes": ["barbarian", "knight"]},
}

const TIERS := [
	{"min": 0, "name": "Crude", "col": Color(0.6, 0.55, 0.5)},
	{"min": 35, "name": "Common", "col": Color(0.86, 0.84, 0.8)},
	{"min": 55, "name": "Fine", "col": Color(0.45, 0.85, 0.45)},
	{"min": 70, "name": "Superior", "col": Color(0.4, 0.65, 1.0)},
	{"min": 84, "name": "Masterwork", "col": Color(0.8, 0.5, 1.0)},
	{"min": 95, "name": "Legendary", "col": Color(1.0, 0.72, 0.2)},
]

const GEM_ORDER := ["ruby", "sapphire", "emerald", "topaz", "amethyst"]
const GEMS := {
	"ruby": {"name": "Ruby", "ench": "Flame", "col": Color(0.95, 0.2, 0.25), "cost": 70, "desc": "+25% power"},
	"sapphire": {"name": "Sapphire", "ench": "Frost", "col": Color(0.25, 0.45, 1.0), "cost": 65, "desc": "+12% power, +10% survival"},
	"emerald": {"name": "Emerald", "ench": "Fortune", "col": Color(0.2, 0.85, 0.4), "cost": 60, "desc": "+60% dungeon loot, +15% sale price"},
	"topaz": {"name": "Topaz", "ench": "Haste", "col": Color(1.0, 0.75, 0.2), "cost": 50, "desc": "+10% power, quests 1 day shorter"},
	"amethyst": {"name": "Amethyst", "ench": "Warding", "col": Color(0.7, 0.35, 0.95), "cost": 75, "desc": "+30% survival"},
}

const UPGRADES := {
	"forge": {"name": "Forge", "costs": [0, 250, 600, 1200], "desc": ["", "Wider heat window, slower cooling, unlocks Silver", "Unlocks Mithril, even steadier heat", "Unlocks Starmetal, master furnace"]},
	"anvil": {"name": "Anvil", "costs": [0, 200, 500, 1000], "desc": ["", "Bigger sweet spot, slower hammer swing", "Tempered face: even bigger sweet spot", "Dwarven anvil: huge sweet spot"]},
	"shop": {"name": "Shop", "costs": [0, 300, 700, 1400], "desc": ["", "+1 customer, +6% prices, Wyrmbone grips", "+1 customer, +6% prices, Ebonwood hafts", "+1 customer, +6% prices, grand display"]},
}

const PERS := {
	"haggler": {"name": "Haggler", "base": 0.82, "patience": 3, "succ": 0.72, "gain": 0.12,
		"hello": ["Let's talk numbers, smith.", "I know a bargain when I see one.", "Don't even think about full price."]},
	"noble": {"name": "Noble", "base": 1.05, "patience": 1, "succ": 0.5, "gain": 0.16,
		"hello": ["I require something worthy of my house.", "Quickly now, I have a banquet at noon.", "Only the finest, naturally."]},
	"veteran": {"name": "Veteran", "base": 0.95, "patience": 2, "succ": 0.55, "gain": 0.12,
		"hello": ["Fought in three wars. I know good steel.", "Show me an edge that won't chip.", "Hmph. Let's see your work."]},
	"apprentice": {"name": "Apprentice", "base": 0.86, "patience": 2, "succ": 0.82, "gain": 0.08,
		"hello": ["Um, hi! It's my first quest...", "I saved up all winter for this!", "Is it okay if I just look?"]},
	"collector": {"name": "Collector", "base": 1.0, "patience": 2, "succ": 0.6, "gain": 0.14,
		"hello": ["Only remarkable pieces interest me.", "Enchanted work? Now we're talking.", "I collect blades of character."]},
	"bard": {"name": "Bard", "base": 0.9, "patience": 2, "succ": 0.65, "gain": 0.1,
		"hello": ["A blade for a ballad! What have you got?", "Every song needs a sword.", "I'll sing of your forge in every tavern!"]},
}

const FIRST := ["Aldric", "Brenna", "Corwin", "Dara", "Edda", "Fenn", "Gilda", "Hob", "Isolde", "Joss", "Kestra", "Lorn",
	"Mira", "Nyle", "Orla", "Perrin", "Quinn", "Rowan", "Sable", "Tamsin", "Ulric", "Vela", "Wren", "Yara", "Zed"]
const EPITHET := ["the Bold", "Quickstep", "Ironjaw", "the Quiet", "Ashborn", "Lightfoot", "the Grey", "Stormcaller",
	"Halfmoon", "the Lucky", "Redcloak", "Thornheart"]

const CLASSES := {
	"knight": {"name": "Knight", "col": Color(0.35, 0.45, 0.8)},
	"rogue": {"name": "Rogue", "col": Color(0.3, 0.3, 0.35)},
	"barbarian": {"name": "Barbarian", "col": Color(0.7, 0.3, 0.2)},
	"ranger": {"name": "Ranger", "col": Color(0.3, 0.6, 0.3)},
	"cleric": {"name": "Cleric", "col": Color(0.9, 0.85, 0.7)},
}

const DUNGEONS := [
	{"id": "warrens", "name": "Mossy Warrens", "danger": 12.0, "days": 1, "ores": ["copper", "iron"], "gems": ["topaz", "emerald"], "gold": [25, 70], "fame": 3, "day": 1,
		"col": Color(0.35, 0.6, 0.3), "foe": ["giant rats", "a moss troll", "goblin scouts", "a cave bear"]},
	{"id": "crypt", "name": "Sunken Crypt", "danger": 22.0, "days": 2, "ores": ["iron", "silver"], "gems": ["amethyst", "sapphire"], "gold": [70, 150], "fame": 6, "day": 1,
		"col": Color(0.4, 0.45, 0.7), "foe": ["drowned skeletons", "a wailing wight", "bog ghouls", "a bone serpent"]},
	{"id": "caverns", "name": "Ember Caverns", "danger": 34.0, "days": 2, "ores": ["silver", "mithril"], "gems": ["ruby", "topaz"], "gold": [130, 250], "fame": 10, "day": 3,
		"col": Color(0.85, 0.4, 0.2), "foe": ["magma imps", "a salamander queen", "fire beetles", "a cinder golem"]},
	{"id": "spire", "name": "Hollow Spire", "danger": 55.0, "days": 3, "ores": ["mithril", "starmetal"], "gems": ["ruby", "sapphire", "emerald", "topaz", "amethyst"], "gold": [230, 430], "fame": 16, "day": 8,
		"col": Color(0.55, 0.35, 0.8), "foe": ["hollow knights", "a void wyrm", "shadow wraiths", "the Spire Warden"]},
]

const TALE_WIN := ["%s cut through %s and came home grinning.", "%s outfought %s, their %s singing every swing.",
	"Bards already sing how %s bested %s.", "%s faced %s and did not flinch."]
const TALE_FAIL := ["%s fled from %s, battered but alive.", "%s was driven back by %s. The %s took a beating."]
const TALE_DEATH := ["%s fell to %s. Their %s was not enough.", "%s never returned from facing %s."]

## Fixed story beats, keyed by day.
const STORY := {
	1: ["Emberfall, first frost.", "Your grandfather's forge is yours now, along with his debt: 2,000 gold owed to Guildmaster Hesk, due in 30 days.",
		"Across the square, the rival smith Vorn Ashgrave watches your shutters open.", "Forge blades. Sell them. Arm the adventurers. Make the name Blade & Bellows mean something again."],
	4: ["Vorn slashes his prices and shouts about it all morning.", "PRICE WAR: customers offer 15% less for the next 2 days."],
	8: ["The ground trembles at dawn. The Hollow Spire has opened on the hill above town.", "The guild posts a new dungeon: the Hollow Spire. Deadly, but rich in Mithril and Starmetal."],
	12: ["Festival of Sparks! The town smithing contest begins at noon.", "Vorn Ashgrave enters, of course."],
	15: ["Guildmaster Hesk stops by, counting on his fingers.", "\"Halfway there, smith. I do hope you've been saving.\""],
	18: ["Vorn is buying drinks for adventurers at the Rusty Tankard, trying to lure them to his shop."],
	21: ["A champion rides into Emberfall: Ser Aveline of the White Road.", "\"Something stirs at the top of the Hollow Spire. On the thirtieth day I climb it. I will need the finest blade in the land.\""],
	24: ["The Harvest contest! The guild wants a Greatsword, and Vorn has been practising."],
	27: ["Rumours spread that Blade & Bellows steel is brittle. Vorn's work, no doubt."],
	30: ["The thirtieth day. Ser Aveline stands in your doorway in silver armour.", "\"Forge me a blade, smith. Whatever the Spire holds, this ends today.\"", "The Guild has sent you its finest stores. Choose any weapon and any ore you can work."],
}
