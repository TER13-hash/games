--!strict
-- Enchanted Realm: Inkbound — Merchant Syla
-- A wandering trader by the spawn clearing. Sells goods for XP.
-- On interact (E) the next useful purchase is auto-selected:
--   1. Tome of Shockwave (200 XP) — if you haven't learned it yet
--   2. Heart Container     (150 XP) — +20 max HP, up to 3 hearts
--   3. Ink Potion          ( 10 XP) — refill ink to full
-- XP is spent straight from s.save.xp; otherwise nothing is taken.

local Session = require(script.Parent:WaitForChild("Session"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Config"))

local Merchant = {}

local MERCHANT_X = 8  -- near cp_start (x = 30)

function Merchant.init(RE)
	local world = game:GetService("Workspace")

	local model = Instance.new("Model")
	model.Name = "MerchantSyla"

	-- torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(3, 4, 1.5)
	torso.Position = Vector3.new(MERCHANT_X, 4, 0)
	torso.Color = Color3.fromRGB(70, 52, 96)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = true
	torso.Parent = model

	-- head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.7, 1.7, 1.7)
	head.Position = Vector3.new(MERCHANT_X, 6.6, 0)
	head.Color = Color3.fromRGB(228, 196, 160)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.Parent = model

	-- wide-brim hat
	local hat = Instance.new("Part")
	hat.Name = "HatBrim"
	hat.Size = Vector3.new(3.2, 0.25, 3.2)
	hat.Position = Vector3.new(MERCHANT_X, 7.4, 0)
	hat.Color = Color3.fromRGB(46, 34, 64)
	hat.Material = Enum.Material.SmoothPlastic
	hat.Anchored = true
	hat.Parent = model
	local hatTop = Instance.new("Part")
	hatTop.Name = "HatTop"
	hatTop.Size = Vector3.new(1.8, 1.4, 1.8)
	hatTop.Position = Vector3.new(MERCHANT_X, 8.2, 0)
	hatTop.Color = Color3.fromRGB(56, 42, 76)
	hatTop.Material = Enum.Material.SmoothPlastic
	hatTop.Anchored = true
	hatTop.Parent = model

	-- staff (decor)
	local staff = Instance.new("Part")
	staff.Name = "Staff"
	staff.Size = Vector3.new(0.35, 6.5, 0.35)
	staff.Position = Vector3.new(MERCHANT_X + 2.1, 4.5, 0)
	staff.Color = Color3.fromRGB(96, 64, 32)
	staff.Material = Enum.Material.Wood
	staff.Anchored = true
	staff.Parent = model
	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Shape = Enum.PartType.Ball
	crystal.Size = Vector3.new(1, 1, 1)
	crystal.Position = Vector3.new(MERCHANT_X + 2.1, 8, 0)
	crystal.Color = Color3.fromRGB(150, 215, 255)
	crystal.Material = Enum.Material.Neon
	crystal.Anchored = true
	crystal.Parent = model
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 215, 255)
	glow.Range = 12
	glow.Brightness = 1.2
	glow.Parent = crystal

	model.PrimaryPart = torso
	model.Parent = world

	-- shop prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Merchant Syla"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	prompt.Triggered:Connect(function(player: Player)
		local s = Session.get(player)
		if not s then
			return
		end
		local xp = math.floor(s.save.xp or 0)
		local hatCount = math.floor((s.save.maxHpBonus or 0) / Config.PLAYER.heartBonus)
		local satchelCount = math.floor((s.save.maxInkBonus or 0) / 25)
		local function sync()
			RE.sync:FireClient(player, Session.syncPayload(s))
		end

		if not Session.hasAbility(s, "shockwave") and xp >= 200 then
			s.save.xp -= 200
			s.dirty = true
			Session.grantAbility(s, "shockwave")
			RE.narrator:FireClient(player, "Tome of Shockwave — a ring of raw ink. Press [7].", 6)
			RE.playSound:FireAllClients("Checkpoint", torso.Position, 0.8)
			sync()

		elseif hatCount < 3 and xp >= 150 then
			s.save.xp -= 150
			s.dirty = true
			Session.grantHeart(s)
			RE.narrator:FireClient(player, "Heart Container — your life grows (+20 max HP).", 5)
			RE.playSound:FireAllClients("Checkpoint", torso.Position, 0.8)
			sync()

		elseif satchelCount < 3 and xp >= 150 then
			s.save.xp -= 150
			s.dirty = true
			Session.grantSatchel(s)
			RE.narrator:FireClient(player, "Ink Satchel — +25 max ink. (" .. (satchelCount + 1) .. "/3)", 5)
			RE.playSound:FireAllClients("Checkpoint", torso.Position, 0.8)
			sync()

		elseif xp >= 10 then
			s.save.xp -= 10
			s.ink = Session.maxInk(s)
			s.dirty = true
			RE.narrator:FireClient(player, "Ink Potion — your meter is full.", 4)
			RE.playSound:FireAllClients("Checkpoint", torso.Position, 0.8)
			sync()

		else
			RE.narrator:FireClient(player, "Not enough XP, traveler. (need 10 XP)", 4)
		end
	end)
end

return Merchant
