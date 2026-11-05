--!strict
-- Enchanted Realm: Inkbound — Loot Chests
-- Wooden chests placed along the world route. One-time open: grants ink
-- refills or XP bundles. Lives server-side; required by Main.server.luau
-- (Main calls LootChests.init(RE) once at server start).
--
-- Add your own: drop another entry into CHESTS below. x is the horizontal
-- position along the world; rewards alternate between ink and XP.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Session = require(script.Parent:WaitForChild("Session"))

local LootChests = {}

type ChestSpec = { x: number, ink: number?, xp: number? }

local CHESTS: { ChestSpec } = {
	{ x = 60,   ink = 25 },
	{ x = 145,  xp = 60  },
	{ x = 278,  ink = 35 },
	{ x = 350,  xp = 75  },
	{ x = 500,  ink = 40 },
	{ x = 700,  xp = 110 },
	{ x = 900,  ink = 45 },
	{ x = 1120, xp = 120 },
	{ x = 1350, ink = 50 },
	{ x = 1560, xp = 140 },
	{ x = 1770, ink = 60 },
	{ x = 1990, xp = 160 },
}

local opened: { [number]: boolean } = {}

local function paintWood(part: BasePart, r: number, g: number, b: number)
	part.Color = Color3.fromRGB(r, g, b)
	part.Material = Enum.Material.Wood
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

function LootChests.init(RE)
	-- broadcast HUD state to one player (mirrors Main's pushSync)
	local function pushSync(player: Player)
		local s = Session.get(player)
		if s then
			RE.sync:FireClient(player, Session.syncPayload(s))
		end
	end

	for i, spec in ipairs(CHESTS) do
		-- body
		local body = Instance.new("Part")
		body.Name = "Chest_" .. i
		paintWood(body, 122, 84, 44)
		body.Size = Vector3.new(2.2, 1.6, 1.6)
		body.Position = Vector3.new(spec.x, 3.2, 0)
		body.Parent = game:GetService("Workspace")

		-- ink outline (visual language shared with barriers/lanterns)
		local outline = Instance.new("Part")
		outline.Name = "InkOutline"
		outline.Size = body.Size + Vector3.new(0.12, 0.12, 0.12)
		outline.Color = Color3.fromRGB(8, 8, 10)
		outline.Material = Enum.Material.SmoothPlastic
		outline.Anchored = true
		outline.CanCollide = false
		outline.CanQuery = false
		outline.CanTouch = false
		outline.CFrame = body.CFrame
		outline.Parent = body

		-- lid
		local lid = Instance.new("Part")
		lid.Name = "Lid"
		paintWood(lid, 96, 64, 32)
		lid.Size = Vector3.new(2.3, 0.5, 1.7)
		lid.CFrame = body.CFrame + Vector3.new(0, 1.05, 0)
		lid.Parent = body

		-- metal band (decor)
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(2.28, 0.3, 1.66)
		band.Color = Color3.fromRGB(190, 160, 70)
		band.Material = Enum.Material.Metal
		band.Anchored = true
		band.CanCollide = false
		band.CanQuery = false
		band.CFrame = body.CFrame + Vector3.new(0, 0.1, 0)
		band.Parent = body

		-- prompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "Old Chest"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 6
		prompt.RequiresLineOfSight = false
		prompt.Parent = body

		prompt.Triggered:Connect(function(player: Player)
			if opened[i] then
				return
			end
			opened[i] = true
			prompt.Enabled = false -- one shot per server boot
			-- pop the lid: swing it up and back, fade it out
			lid.CFrame = body.CFrame * CFrame.new(0, 2.4, -0.8) * CFrame.Angles(math.rad(-35), 0, 0)
			lid.Transparency = 0.35

			local s = Session.get(player)
			if not s then
				return
			end

			if spec.ink then
				s.ink = math.min(Session.maxInk(s), s.ink + spec.ink)
				s.dirty = true
				RE.dialogue:FireClient(player, "loot", "Old ink, still usable — +" .. spec.ink .. " ink.")
			end

			if spec.xp then
				local leveled = Session.addXp(s, spec.xp)
				RE.dialogue:FireClient(player, "loot", "A moldy tome of knowledge — +" .. spec.xp .. " XP." .. (leveled and " Level up!" or ""))
			end

			RE.playSound:FireAllClients("Checkpoint", body.Position, 0.9)
			RE.vfx:FireAllClients("breakBarrier", body.Position, "wood")
			pushSync(player)
		end)
	end
end

return LootChests
