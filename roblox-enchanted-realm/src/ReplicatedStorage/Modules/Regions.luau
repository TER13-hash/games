--!strict
-- Enchanted Realm : Inkbound — world layout (single contiguous map, Hollow-Knight style)
-- All coordinates are in studs. Ground tops sit at y = 0 unless noted.
-- The Z axis is locked to 0 for all gameplay; decoration may wander in Z.

local Regions = {}

Regions.ORDER = {
	"forest",
	"ruins",
	"burning",
	"frozen",
	"cave",
	"sky",
	"underground",
}

Regions.byId = {

	forest = {
		id = "forest",
		name = "Enchanted Forest",
		minX = 0, maxX = 400,
		env = { fog = Color3.fromRGB(28, 52, 36), density = 0.55, ambient = Color3.fromRGB(70, 96, 74) },
		grounds = { { x0 = 0, x1 = 145, topY = 0 }, { x0 = 157, x1 = 400, topY = 0 } }, -- 12-stud hollow log pit
		platforms = {
			{ x = 56, y = 8, w = 12 },
			{ x = 96, y = 13, w = 10 },
			{ x = 140, y = 8, w = 12 },
			{ x = 190, y = 9, w = 12 },
			{ x = 236, y = 14, w = 10 },
			{ x = 280, y = 8, w = 12 },
			{ x = 330, y = 9, w = 10 },
		},
		creeps = {
			{ kind = "creep", x = 72 },
			{ kind = "creep", x = 104 },
			{ kind = "creep", x = 150 },
			{ kind = "creep", x = 215 },
			{ kind = "creep", x = 252 },
			{ kind = "creep", x = 290 },
		},
		boss = { kind = "mechanical", x = 345, arenaMinX = 250, arenaMaxX = 380 },
		vinePatch = { x0 = 300, x1 = 330 }, -- bait the Mechanical Guardian onto this to root it
		hearts = { { x = 88, y = 5, sealedBy = "vine" } }, -- hidden Heart Container, burn the vines
		barrierBlocks = { { type = "vine", x = 88, y = 5, w = 8, h = 10, d = 8 } },
		mishX = 20,
	},

	ruins = {
		id = "ruins",
		name = "Mechanical Ruins",
		minX = 416, maxX = 760,
		env = { fog = Color3.fromRGB(64, 54, 44), density = 0.5, ambient = Color3.fromRGB(96, 84, 66) },
		grounds = { { x0 = 416, x1 = 522, topY = 0 }, { x0 = 530, x1 = 760, topY = 0 } },
		platforms = {
			{ x = 438, y = 7, w = 10 },
			{ x = 475, y = 12, w = 10 },
			{ x = 505, y = 7, w = 12 },
			{ x = 545, y = 7, w = 12 },
			{ x = 610, y = 9, w = 12 },
		},
		creeps = {
			{ kind = "robot", x = 450 },
			{ kind = "robot", x = 492 },
			{ kind = "robot", x = 558 },
			{ kind = "robot", x = 600 },
		},
		electricStrips = { { x0 = 455, x1 = 466 }, { x0 = 585, x1 = 599 } },
		boss = { kind = "machine", x = 712, arenaMinX = 645, arenaMaxX = 755 },
		pillars = { 650, 674, 698, 722, 746 }, -- boss dash-impact here = massive damage + 5s stun
	},

	burning = {
		id = "burning",
		name = "Burning Forest",
		minX = 776, maxX = 1010,
		env = { fog = Color3.fromRGB(74, 40, 22), density = 0.62, ambient = Color3.fromRGB(120, 72, 40) },
		grounds = { { x0 = 776, x1 = 1010, topY = 0 } },
		platforms = {
			{ x = 800, y = 7, w = 10 },
			{ x = 850, y = 7, w = 10 },
			{ x = 930, y = 10, w = 12 },
		},
		creeps = {
			{ kind = "cinderfrog", x = 810 },
			{ kind = "cinderfrog", x = 862 },
			{ kind = "cinderfrog", x = 898 },
		},
		firePits = { { x0 = 830, x1 = 840 }, { x0 = 905, x1 = 916 } },
		boss = { kind = "fire", x = 955, arenaMinX = 905, arenaMaxX = 1005 },
		waterPuddleX = 948, -- standing in water cleanses the burn debuff
	},

	frozen = {
		id = "frozen",
		name = "Frozen Ruins",
		minX = 1026, maxX = 1285,
		env = { fog = Color3.fromRGB(36, 54, 74), density = 0.55, ambient = Color3.fromRGB(92, 120, 148) },
		grounds = { { x0 = 1026, x1 = 1128, topY = 0 }, { x0 = 1140, x1 = 1285, topY = 0 } }, -- frozen chasm
		platforms = {
			{ x = 1050, y = 7, w = 10 },
			{ x = 1105, y = 8, w = 10 },
			{ x = 1165, y = 7, w = 10 },
			{ x = 1220, y = 9, w = 10 },
		},
		creeps = {
			{ kind = "frostee", x = 1065 },
			{ kind = "frostee", x = 1112 },
			{ kind = "frostee", x = 1175 },
			{ kind = "frostee", x = 1230 },
		},
		boss = { kind = "ice", x = 1250, arenaMinX = 1155, arenaMaxX = 1282 },
		hearts = { { x = 1190, y = 19 } }, -- ledge only reachable with the Double Jump
	},

	cave = {
		id = "cave",
		name = "Secret Cave",
		minX = 1301, maxX = 1490,
		env = { fog = Color3.fromRGB(22, 18, 38), density = 0.75, ambient = Color3.fromRGB(64, 52, 96) },
		grounds = { { x0 = 1301, x1 = 1490, topY = 0 } },
		ceilings = { { x0 = 1301, x1 = 1490, y = 26, h = 8 } },
		windCrystal = { x = 1430, y = 6 },
	},

	sky = {
		id = "sky",
		name = "Sky Ruins",
		minX = 1490, maxX = 2015,
		env = { fog = Color3.fromRGB(96, 132, 168), density = 0.25, ambient = Color3.fromRGB(150, 172, 196) },
		grounds = { -- floating islands
			{ x0 = 1490, x1 = 1562, topY = 30, thickness = 6, floating = true },
			{ x0 = 1585, x1 = 1625, topY = 36, thickness = 6, floating = true },
			{ x0 = 1652, x1 = 1692, topY = 42, thickness = 6, floating = true },
			{ x0 = 1722, x1 = 1762, topY = 48, thickness = 6, floating = true },
			{ x0 = 1790, x1 = 1836, topY = 54, thickness = 6, floating = true },
			{ x0 = 1816, x1 = 1892, topY = 58, thickness = 6, floating = true },
			{ x0 = 1900, x1 = 2015, topY = 58, thickness = 8, floating = true },
		},
		creeps = {
			{ kind = "flyingCreep", x = 1605, y = 44 },
			{ kind = "flyingCreep", x = 1670, y = 50 },
			{ kind = "flyingCreep", x = 1745, y = 56 },
			{ kind = "flyingCreep", x = 1808, y = 62 },
		},
		boss = { kind = "storm", x = 1962, arenaMinX = 1905, arenaMaxX = 2005, arenaY = 58 },
	},

	underground = {
		id = "underground",
		name = "Forgotten Underground",
		minX = 2015, maxX = 2680,
		env = { fog = Color3.fromRGB(16, 22, 26), density = 0.8, ambient = Color3.fromRGB(44, 62, 66) },
		grounds = { { x0 = 2015, x1 = 2680, topY = 0 } },
		ceilings = { { x0 = 2015, x1 = 2380, y = 24, h = 8 } }, -- chamber beyond is tall
		creeps = {
			{ kind = "robotElite", x = 2085 },
			{ kind = "robotElite", x = 2180 },
			{ kind = "robotElite", x = 2270 },
		},
		machineRoomX = 2335, -- the gigantic machine; requires the Lightning Core
		sealedDoorX = 2380,
		boss = { kind = "squid", x = 2545, arenaMinX = 2410, arenaMaxX = 2665, triggerX = 2405 },
		waterPool = { x0 = 2470, x1 = 2580, depth = 1.5 },
		grandKeyX = 2545,
		puddleDeepX = 2515,
	},
}

-- Boundary walls (full-height) with a gated doorway into the next zone.
Regions.WALLS = {
	{ x = 400, w = 16, h = 60, door = { barrier = "electric", h = 14, w = 16 } },
	{ x = 760, w = 16, h = 60, door = { barrier = "stone", h = 14, w = 16 } },
	{ x = 1010, w = 16, h = 60, door = { barrier = "frozen", h = 14, w = 16 } },
	{ x = 1285, w = 16, h = 60, door = { barrier = "waterfall", h = 40, w = 16 } }, -- needs Ice
	{ x = 2380, w = 16, h = 44, door = { barrier = "machineSeal", h = 26, w = 16 } }, -- needs Lightning Core
}

-- Two-way portals (cave <-> sky top, sky <-> deep gate). The finale portal is one-way.
Regions.PORTALS = {
	{
		id = "caveSky",
		label = "Ascend to the Sky Ruins",
		a = { x = 1468, y = 2, z = 0 },
		b = { x = 1520, y = 31, z = 0 },
	},
	{
		id = "skyDeep",
		label = "Descend into the Forgotten Underground",
		a = { x = 2008, y = 59.4, z = 0 },
		b = { x = 2032, y = 2, z = 0 },
	},
}
Regions.FINALE_PORTAL = { x = 2460, y = 1.5, z = 0 } -- opens only after the Grand Key is claimed

-- Decor density per region id (trees / rocks / shards / columns — spawned by the builder)
Regions.DECOR = {
	forest = { trees = 34, rocks = 10, glowcaps = 14, fireflies = true },
	ruins = { columns = 22, rocks = 8, sparks = true },
	burning = { trees = 26, firepitsDecor = 8, embers = true },
	frozen = { icicles = 30, rocks = 12, snow = true },
	cave = { crystals = 26, rocks = 6 },
	sky = { floatingRocks = 14, clouds = true },
	underground = { pillars = 18, crystals = 10, drips = true },
}

function Regions.regionAt(x: number)
	for _, id in ipairs(Regions.ORDER) do
		local r = Regions.byId[id]
		if x >= r.minX and x <= r.maxX then
			return r
		end
	end
	return Regions.byId.forest
end

return Regions
