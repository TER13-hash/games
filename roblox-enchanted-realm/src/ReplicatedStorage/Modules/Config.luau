--!strict
-- Enchanted Realm — shared configuration & static tables
-- Metroidvania design ported from the Enchanted Realm GDD.

local Config = {}

Config.GAME = {
	title = "Enchanted Realm: Inkbound",
	shortTitle = "Inkbound",
	tagline = "The world is a sketch. Fight for the page.",
	credits = "Enchanted Realm: Inkbound · Roblox Edition",
}

Config.WORLD = {
	minX = -40,
	maxX = 2680,
	killY = -70,
	nightSky = Color3.fromRGB(24, 34, 44),
}

Config.INK = {
	max = 100,
	meterGainPerHit = 12, -- ink refunded by a landed melee hit
	startInk = 50,
	costs = {
		lightning = 25,
		fire = 30,
		ice = 30,
		wind = 20,
		powerRock = 35, -- a heavy slam, always worth it
		lightningCore = 45,
		shockwave = 40,
	},
}

-- Guardian Echoes: one per Guardian you defeat. Permanent passives.
Config.ECHOS = {
	kidlatEcho = { id = "kidlatEcho", name = "Echo of Kidlat", icon = "⌁", color = Color3.fromRGB(140, 210, 255), desc = "Every 3rd strike discharges crackling arcs (bonus damage)." },
	piyedroEcho = { id = "piyedroEcho", name = "Echo of Piyedro", icon = "⬢", color = Color3.fromRGB(200, 180, 150), desc = "Stone Skin — all incoming damage reduced by 20%." },
	peyroEcho = { id = "peyroEcho", name = "Echo of Peyro", icon = "🔥", color = Color3.fromRGB(255, 150, 70), desc = "Ember Cloak — burn immunity and your fire strikes splash." },
	danEcho = { id = "danEcho", name = "Echo of Dan", icon = "❄", color = Color3.fromRGB(160, 230, 255), desc = "Still Waters — frozen ground under you never breaks, and you resist slows." },
	jyrEcho = { id = "jyrEcho", name = "Echo of Maam Jyr", icon = "🍃", color = Color3.fromRGB(180, 255, 205), desc = "Gale Step — your wind jumps carry you further still." },
	nukosEcho = { id = "nukosEcho", name = "Echo of Nukos", icon = "◈", color = Color3.fromRGB(255, 110, 130), desc = "The tide remembers — victory is yours; the Grand Key sings." },
}

Config.PLAYER = {
	baseHealth = 100,
	baseDamage = 15,
	baseSpeed = 16,
	levelHealthBonus = 10, -- max HP gained per level
	levelDamageBonus = 2, -- damage per level
	heartBonus = 20, -- max HP from a hidden Heart Container (GDD: hidden rooms with health upgrades)
	xpPerLevelBase = 90, -- xp needed for L1->L2; scaled linearly afterwards
	xpPerLevelStep = 45, -- additional xp per subsequent level
	maxLevel = 12,
	attackCooldown = 0.35,
	attackRange = 6.5,
	attackArc = 2.1, -- studs of half-width for the sword hitbox
	invulnerabilityTime = 1.0, -- i-frames after taking a hit
	gravity = 150,
	jumpPower = 62,
	doubleJumpPower = 55,
	doubleJumpEnabledAtStart = false,
	windJumpBonus = 14, -- extra impulse with Wind power
	windSpeedBonus = 6,
	windGlideFactor = 0.25, -- vertical velocity damping while gliding airborne w/ Wind
}

-- XP for going from `level` to `level + 1`
function Config.xpToNext(level: number): number
	return Config.PLAYER.xpPerLevelBase + Config.PLAYER.xpPerLevelStep * (level - 1)
end

Config.ABILITIES = {
	doubleJump = { id = "doubleJump", name = "Double Jump", icon = "⇑⇑", color = Color3.fromRGB(180, 220, 255), desc = "Jump a second time mid-air." },
	lightning  = { id = "lightning",  name = "Lightning",   icon = "⚡", color = Color3.fromRGB(255, 235, 120), desc = "Activates ancient mechanisms and opens electric doors." },
	powerRock  = { id = "powerRock",  name = "Power Rock",  icon = "⬢", color = Color3.fromRGB(170, 150, 120), desc = "Breaks sealed stone doors and shatters rock barriers." },
	fire       = { id = "fire",       name = "Fire",        icon = "🔥", color = Color3.fromRGB(255, 140, 60),  desc = "Burns vines, wooden barricades and melts frozen doors." },
	ice        = { id = "ice",        name = "Ice",         icon = "❄", color = Color3.fromRGB(150, 225, 255), desc = "Freezes waterfalls and creates ice platforms." },
	wind       = { id = "wind",       name = "Wind",        icon = "🍃", color = Color3.fromRGB(170, 255, 190), desc = "Huge jumps, wind glide and air dash currents." },
	lightningCore = { id = "lightningCore", name = "Lightning Core", icon = "✦", color = Color3.fromRGB(255, 255, 200), desc = "Enhanced lightning. Wakes the gigantic machine underground." },
	shockwave   = { id = "shockwave",   name = "Shockwave",    icon = "◎", color = Color3.fromRGB(150, 215, 255), desc = "A ring of raw ink energy — damages and hurls back everything around you." },
}

-- Barriers that only open with a specific power
Config.BARRIERS = {
	electric = { need = "lightning", prompt = "Sealed by an ancient mechanism — requires Lightning" },
	stone   = { need = "powerRock", prompt = "A vault of living rock — requires the Power Rock" },
	frozen  = { need = "fire",      prompt = "Frozen solid — melt it with Fire" },
	vine    = { need = "fire",      prompt = "Thick vines — burn them with Fire" },
	wood    = { need = "fire",      prompt = "Collapsed barricade — burn it with Fire" },
	rock    = { need = "powerRock", prompt = "Solid rock — shatter it with the Power Rock" },
}

-- Checkpoints / save points (lanterns)
Config.CHECKPOINTS = {
	{ id = "cp_start",   name = "Enchanted Forest — Mish's Clearing", x = 30,   y = 2 },
	{ id = "cp_forest",  name = "Forest Heart Lantern",               x = 150,  y = 2 },
	{ id = "cp_ruins1",  name = "Ruins Approach Lantern",             x = 428,  y = 2 },
	{ id = "cp_ruins2",  name = "Gear Hall Lantern",                  x = 560,  y = 2 },
	{ id = "cp_burning", name = "Ember Gate Lantern",                 x = 800,  y = 2 },
	{ id = "cp_frozen",  name = "Frozen Gate Lantern",                x = 1045, y = 2 },
	{ id = "cp_cave",    name = "Echo Crystal Lantern",               x = 1330, y = 2 },
	{ id = "cp_sky",     name = "Zephyr Rest Lantern",                x = 1845, y = 60 },
	{ id = "cp_deep",    name = "Deep Gate Lantern",                  x = 2050, y = 2 },
}

-- Order in which objectives are shown (server pushes updates)
Config.OBJECTIVES = {
	start       = "Explore the forest and find a way through",
	giveMish    = "Help Mish and learn of the Grand Key",
	mechBoss    = "Defeat the Mechanical Guardian in the forest",
	openElectric= "Use Lightning to open the sealed door east",
	runins      = "Explore the Mechanical Ruins",
	machineBoss = "Defeat the Machine Warrior",
	openStone   = "Use the Power Rock on the sealed stone door",
	burning     = "Brave the Burning Forest and defeat the Fire Guardian",
	openFrozen  = "Melt the frozen door to the Frozen Ruins",
	iceBoss     = "Defeat the Ice Guardian",
	openWaterfall = "Freeze the waterfall and enter the Secret Cave",
	windCrystal = "Claim the Wind Crystal",
	stormBoss   = "Cross the Sky Ruins and defeat the Storm Guardian",
	wakeMachine = "Return to the Ruins and wake the gigantic machine", -- lore-adjacent: opens Forgotten Underground
	underground = "Descend into the Forgotten Underground",
	squid       = "Defeat Nukos, the Squid Monster, guardian of the Grand Key",
	escape      = "Claim the Grand Key and leave Encantadia",
	done        = "Journey complete",
}

Config.ENEMIES = {
	creep = {
		name = "Encantadian Creep", hp = 30, damage = 8, xp = 15, speed = 7, milestone = "creep",
		color = Color3.fromRGB(90, 160, 80), eyeColor = Color3.fromRGB(255, 240, 120), scale = 1.0,
	},
	robot = {
		name = "Little Robot", hp = 45, damage = 10, xp = 20, speed = 5.5, milestone = "robot",
		color = Color3.fromRGB(140, 150, 165), eyeColor = Color3.fromRGB(255, 120, 40), scale = 1.0,
	},
	robotElite = {
		name = "Mechanical Hunter", hp = 70, damage = 13, xp = 35, speed = 6.5, milestone = "robot",
		color = Color3.fromRGB(110, 115, 130), eyeColor = Color3.fromRGB(255, 60, 40), scale = 1.25,
	},
	cinderfrog = {
		name = "Cinderfrog", hp = 35, damage = 12, xp = 25, speed = 6, ranged = true, milestone = "cinderfrog",
		color = Color3.fromRGB(200, 80, 40), eyeColor = Color3.fromRGB(255, 220, 90), scale = 1.0,
	},
	frostee = {
		name = "Frostee", hp = 45, damage = 12, xp = 25, speed = 6.5, milestone = "frostee",
		color = Color3.fromRGB(170, 225, 245), eyeColor = Color3.fromRGB(60, 90, 255), scale = 1.0,
	},
	flyingCreep = {
		name = "Flying Creep", hp = 30, damage = 10, xp = 30, speed = 8, flying = true, milestone = "flyingcreep",
		color = Color3.fromRGB(130, 90, 200), eyeColor = Color3.fromRGB(255, 80, 220), scale = 0.95,
	},
}

Config.BOSSES = {
	mechanical = {
		name = "Mechanical Guardian — Kidlat", title = "Ruler of Illumicadia",
		hp = 220, damage = 14, xp = 120, color = Color3.fromRGB(120, 190, 255),
	},
	machine = {
		name = "Machine Warrior — Piyedro", title = "Ruler of Mechadia",
		hp = 300, damage = 18, xp = 160, color = Color3.fromRGB(160, 150, 140),
	},
	fire = {
		name = "Fire Guardian — Peyro", title = "Ruler of Pyrocadia",
		hp = 340, damage = 16, xp = 200, color = Color3.fromRGB(255, 110, 40),
	},
	ice = {
		name = "Ice Guardian — Dan", title = "Keeper of the Frozen Ruins",
		hp = 380, damage = 15, xp = 240, color = Color3.fromRGB(170, 225, 250),
	},
	storm = {
		name = "Storm Guardian — Maam Jyr", title = "Ruler of Hurricadia",
		hp = 450, damage = 17, xp = 300, color = Color3.fromRGB(120, 130, 200),
	},
	squid = {
		name = "Nukos — the Squid Monster", title = "Owner of the Grand Key",
		hp = 620, damage = 22, xp = 500, color = Color3.fromRGB(150, 40, 60),
	},
}

-- ═══ ANIME POWERS ═══
-- Ink Awakening: fill the meter, press Q — 6s of pure anime transformation.
-- Style paths: ranked elemental powers bought in the SKILLS panel (150 XP each).
-- Jobs: JRPG-style classes with their own passives (150 XP each).
Config.AWAKEN = {
	duration = 6,
	damageMul = 1.75,
	walkSpeedBonus = 6,
}

Config.STYLES = {
	flame = { id = "flame", name = "Flame Style", icon = "🔥", color = Color3.fromRGB(255, 140, 60), desc = "+25% fire damage per rank (max 3)." },
	storm = { id = "storm", name = "Storm Style", icon = "⚡", color = Color3.fromRGB(150, 215, 255), desc = "+25% shockwave damage per rank (max 3)." },
	frost = { id = "frost", name = "Frost Style", icon = "❄", color = Color3.fromRGB(170, 230, 255), desc = "+25% ice damage per rank (max 3)." },
}

Config.JOBS = {
	warrior = { id = "warrior", name = "Warrior", title = "Vanguard of the Page", icon = "⚔", color = Color3.fromRGB(255, 170, 120), desc = "+15 max HP & +10% melee damage per rank (max 3)." },
	mage = { id = "mage", name = "Mage", title = "Stormweaver", icon = "✦", color = Color3.fromRGB(180, 140, 255), desc = "+20 max ink & +10% ability damage per rank (max 3)." },
	healer = { id = "healer", name = "Healer", title = "Luminary of Dawn", icon = "✚", color = Color3.fromRGB(255, 230, 150), desc = "+10% XP per rank. Land melees to mend +3 HP per rank." },
}

return Config
