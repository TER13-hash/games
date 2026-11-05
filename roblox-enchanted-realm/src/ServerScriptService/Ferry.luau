--!strict
-- Enchanted Realm: Inkbound — the Forest Ferry
-- Shuttles a raft across the forest river between the two docks.
-- Moves at 11 studs/s each way with a 4-second pause at each side.
-- The raft is velocity-driven (not anchored), so a player standing on it
-- is genuinely carried across. Jumping off mid-crossing = the river wins.

local Ferry = {}

local DOCK_WEST = 231
local DOCK_EAST = 277
local SPEED = 11
local DWELL = 4
local RAFT_Y = 0.9

local function buildRaft(): (Model, BodyVelocity, BodyPosition)
	local model = Instance.new("Model")
	model.Name = "ForestFerry"

	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(9, 0.8, 5)
	deck.Position = Vector3.new(DOCK_WEST, RAFT_Y, 0)
	deck.Color = Color3.fromRGB(110, 74, 42)
	deck.Material = Enum.Material.Wood
	deck.Anchored = false
	deck.Massless = true
	deck.CanCollide = true
	deck.Parent = model
	model.PrimaryPart = deck

	-- plank seams (decor)
	for i = 1, 3 do
		local seam = Instance.new("Part")
		seam.Name = "Seam"
		seam.Size = Vector3.new(0.15, 0.09, 4.8)
		seam.Position = Vector3.new(DOCK_WEST + (i - 2) * 2.2, RAFT_Y + 0.42, 0)
		seam.Color = Color3.fromRGB(72, 48, 28)
		seam.Anchored = false
		seam.Massless = true
		seam.CanCollide = false
		seam.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = deck
		weld.Part1 = seam
		weld.Parent = model
	end

	-- side rails
	for _, side in ipairs({ -1, 1 }) do
		local rail = Instance.new("Part")
		rail.Name = "Rail"
		rail.Size = Vector3.new(9, 0.5, 0.3)
		rail.Position = Vector3.new(DOCK_WEST, RAFT_Y + 1.15, side * 2.3)
		rail.Color = Color3.fromRGB(82, 54, 32)
		rail.Material = Enum.Material.Wood
		rail.Anchored = false
		rail.Massless = true
		rail.CanCollide = false
		rail.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = deck
		weld.Part1 = rail
		weld.Parent = model
	end

	-- corner posts
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local post = Instance.new("Part")
			post.Name = "Post"
			post.Shape = Enum.PartType.Cylinder
			post.Size = Vector3.new(0.6, 1.6, 0.6)
			post.Position = Vector3.new(DOCK_WEST + sx * 4, RAFT_Y + 1.1, sz * 2.2)
			post.Color = Color3.fromRGB(64, 42, 26)
			post.Material = Enum.Material.Wood
			post.Anchored = false
			post.Massless = true
			post.CanCollide = false
			post.Orientation = Vector3.new(0, 0, 90)
			post.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = deck
			weld.Part1 = post
			weld.Parent = model
		end
	end

	-- lantern on a pole
	local pole = Instance.new("Part")
	pole.Name = "LanternPole"
	pole.Size = Vector3.new(0.28, 2.4, 0.28)
	pole.Position = Vector3.new(DOCK_WEST + 3.6, RAFT_Y + 1.6, 0)
	pole.Color = Color3.fromRGB(64, 42, 26)
	pole.Anchored = false
	pole.Massless = true
	pole.CanCollide = false
	pole.Parent = model
	local poleWeld = Instance.new("WeldConstraint")
	poleWeld.Part0 = deck
	poleWeld.Part1 = pole
	poleWeld.Parent = model

	local lantern = Instance.new("Part")
	lantern.Name = "Lantern"
	lantern.Shape = Enum.PartType.Ball
	lantern.Size = Vector3.new(0.6, 0.6, 0.6)
	lantern.Position = Vector3.new(DOCK_WEST + 3.6, RAFT_Y + 3, 0)
	lantern.Material = Enum.Material.Neon
	lantern.Color = Color3.fromRGB(255, 215, 130)
	lantern.Anchored = false
	lantern.Massless = true
	lantern.CanCollide = false
	lantern.Parent = model
	local lanternWeld = Instance.new("WeldConstraint")
	lanternWeld.Part0 = pole
	lanternWeld.Part1 = lantern
	lanternWeld.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 130)
	light.Range = 16
	light.Brightness = 2.4
	light.Parent = lantern

	-- movement drivers: horizontal velocity + vertical hold + upright stabiliser
	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.MaxForce = Vector3.new(math.huge, 0, 0)
	bodyVel.Velocity = Vector3.new(0, 0, 0)
	bodyVel.Parent = deck

	local bodyPos = Instance.new("BodyPosition")
	bodyPos.MaxForce = Vector3.new(0, math.huge, 0)
	bodyPos.D = 900
	bodyPos.Position = Vector3.new(DOCK_WEST, RAFT_Y, 0)
	bodyPos.Parent = deck

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.D = 500
	bodyGyro.CFrame = CFrame.new()
	bodyGyro.Parent = deck

	model.Parent = game:GetService("Workspace")
	return model, bodyVel, bodyPos
end

function Ferry.init()
	local world = game:GetService("Workspace")

	-- docks (wooden planks at each bank)
	for _, x in ipairs({ DOCK_WEST - 4, DOCK_EAST + 4 }) do
		local dock = Instance.new("Part")
		dock.Name = "FerryDock"
		dock.Anchored = true
		dock.Size = Vector3.new(5, 0.6, 5)
		dock.Position = Vector3.new(x, 0.35, 0)
		dock.Color = Color3.fromRGB(96, 64, 38)
		dock.Material = Enum.Material.Wood
		dock.Parent = world
		for _, sx in ipairs({ -1.6, 1.6 }) do
			for _, sz in ipairs({ -1.6, 1.6 }) do
				local post = Instance.new("Part")
				post.Name = "DockPost"
				post.Shape = Enum.PartType.Cylinder
				post.Size = Vector3.new(0.7, 4.4, 0.7)
				post.Position = Vector3.new(x + sx, -1.2, sz)
				post.Color = Color3.fromRGB(72, 48, 28)
				post.Material = Enum.Material.Wood
				post.Anchored = true
				post.Orientation = Vector3.new(0, 0, 90)
				post.Parent = world
			end
		end
	end

	-- the river water (two translucent slabs, slightly different hues/depths)
	local waterTop = Instance.new("Part")
	waterTop.Name = "ForestRiver"
	waterTop.Size = Vector3.new(43.5, 0.3, 46)
	waterTop.Position = Vector3.new(254, -0.35, 0)
	waterTop.Material = Enum.Material.SmoothPlastic
	waterTop.Color = Color3.fromRGB(70, 165, 215)
	waterTop.Transparency = 0.42
	waterTop.Anchored = true
	waterTop.CanCollide = false
	waterTop.CanQuery = false
	waterTop.Parent = world
	local waterDeep = waterTop:Clone()
	waterDeep.Name = "ForestRiverDeep"
	waterDeep.Size = Vector3.new(43.5, 0.3, 46)
	waterDeep.Position = Vector3.new(254, -1.5, 0)
	waterDeep.Color = Color3.fromRGB(38, 118, 185)
	waterDeep.Transparency = 0.55
	waterDeep.Parent = world

	-- raft
	local model, bodyVel, bodyPos = buildRaft()

	local direction = 1 -- 1 = eastward, -1 = westward
	task.spawn(function()
		while true do
			local x = model.PrimaryPart.Position.X
			if direction == 1 and x >= DOCK_EAST then
				direction = -1
				bodyVel.Velocity = Vector3.new(0, 0, 0)
				for i = 1, DWELL * 10 do
					task.wait(0.1)
				end
			elseif direction == -1 and x <= DOCK_WEST then
				direction = 1
				bodyVel.Velocity = Vector3.new(0, 0, 0)
				for i = 1, DWELL * 10 do
					task.wait(0.1)
				end
			end

			bodyVel.Velocity = Vector3.new(direction * SPEED, 0, 0)
			bodyPos.Position = Vector3.new(if direction == 1 then DOCK_EAST else DOCK_WEST, RAFT_Y, 0)
			task.wait(0.05)
		end
	end)
end

return Ferry
