--!strict
-- Ambient fireflies scattered around the map, each giving off a little light.
local RunService = game:GetService("RunService")

local Regions = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Regions"))

local FIREFLY_COLOR = Color3.fromRGB(190, 255, 140)
local SPACING = 26 -- average horizontal spacing between fireflies
local rng = Random.new()

local container = Instance.new("Folder")
container.Name = "Fireflies"
container.Parent = workspace

local fireflies = {} -- { part, light, basePos, phase, speed, radius }

-- find the map's X extent from the region definitions
local minX, maxX = math.huge, -math.huge
for _, region in pairs(Regions.byId) do
	if region.minX and region.minX < minX then minX = region.minX end
	if region.maxX and region.maxX > maxX then maxX = region.maxX end
end
if minX == math.huge then minX, maxX = 0, 400 end

-- spawn fireflies across the whole map
for x = minX + 10, maxX - 10, SPACING do
	-- 1-2 fireflies per step, wandering in Z (decoration may leave the gameplay plane)
	local count = rng:NextInteger(1, 2)
	for _ = 1, count do
		local part = Instance.new("Part")
		part.Name = "Firefly"
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Shape = Enum.PartType.Ball
		part.Color = FIREFLY_COLOR
		part.Material = Enum.Material.Neon
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Anchored = true
		part.Transparency = 0.2

		local basePos = Vector3.new(
			x + rng:NextNumber(-SPACING * 0.4, SPACING * 0.4),
			rng:NextNumber(1.5, 7),
			rng:NextNumber(-5, 5)
		)
		part.Position = basePos

		local light = Instance.new("PointLight")
		light.Color = FIREFLY_COLOR
		light.Brightness = 0.6
		light.Range = 9
		light.Shadows = false
		light.Parent = part

		local spark = Instance.new("ParticleEmitter")
		spark.Texture = "rbxassetid://243660364"
		spark.Color = ColorSequence.new(FIREFLY_COLOR)
		spark.Rate = 3
		spark.Lifetime = NumberRange.new(0.4, 0.8)
		spark.Speed = NumberRange.new(0.1, 0.4)
		spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
		spark.LightEmission = 1
		spark.Parent = part

		part.Parent = container

		table.insert(fireflies, {
			part = part,
			light = light,
			basePos = basePos,
			phase = rng:NextNumber(0, math.pi * 2),
			speed = rng:NextNumber(0.3, 0.9),
			radius = rng:NextNumber(1, 3),
		})
	end
end

-- animate: gentle drifting + soft flicker, all in one loop
local time = 0
RunService.Heartbeat:Connect(function(dt)
	time += dt
	for _, f in ipairs(fireflies) do
		local t = time * f.speed + f.phase
		local offset = Vector3.new(
			math.cos(t) * f.radius,
			math.sin(t * 1.7) * 1.2,
			math.sin(t * 0.8) * f.radius * 0.6
		)
		f.part.Position = f.basePos + offset
		-- soft flicker between 0.35 and 0.9
		f.light.Brightness = 0.6 + math.sin(t * 3.1) * 0.25
	end
end)

print("[Inkbound] Spawned " .. #fireflies .. " ambient fireflies across x=" .. minX .. " to " .. maxX)