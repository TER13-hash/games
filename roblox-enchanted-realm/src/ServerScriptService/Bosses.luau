--!strict
-- The Guardians of Encantadia. Six bespoke boss fights built from anchored parts,
-- moved by code. Each boss: dormant -> intro roar -> fight -> defeat.
-- GDD fidelity: Kidlat (shield/beam/vine bait), Piyedro (dash/slam/pillars),
-- Peyro (fire wall/eruption/burn+cleanse), Dan (glasses projectiles/stomp spikes),
-- Maam Jyr (lightning strike/thunder orb/wind blast vulnerability), Nukos (water cycle/ink/grab).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Regions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Regions"))

local Bosses = {}
Bosses.__index = Bosses

export type Boss = {
	kind: string,
	def: any,
	model: Model,
	bodyParts: { Part },
	hp: number,
	maxHp: number,
	x: number,
	y: number,
	area: { minX: number, maxX: number },
	state: string, -- dormant | intro | active | defeated
	cooldowns: { [string]: number },
	rootedUntil: number,
	stunnedUntil: number,
	burnUntil: number,
	regainUntil: number, -- storm guardian: vulnerable window
	submergedUntil: number, -- nukos underwater phase
	surfacedUntil: number,
	lastContactDamage: number,
	lockWalls: { BasePart },
	introPlayed: boolean,
	phase2: boolean, -- enraged at 50% HP
}

local bossList: { Boss } = {}
local events: any = nil
local onPlayerDamaged: ((damage: number, fromPos: Vector3, sourceName: string) -> ())? = nil
local onBossDefeated: ((kind: string) -> ())? = nil
local rng = Random.new(90210)

-- ————————————————————— model factories ——————————————————————

local function mkPart(model: Model, name: string, size: Vector3, color: Color3, mat: Enum.Material?, neon: boolean?, shape: Enum.PartType?, canCollide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = canCollide ~= false
	p.CanQuery = true
	p.Size = size
	p.Color = color
	p.Material = neon and Enum.Material.Neon or (mat or Enum.Material.SmoothPlastic)
	p.Shape = shape or Enum.PartType.Block
	p.Parent = model
	return p
end

local function inkOutline(model: Model, part: Part, grow: number?)
	local g = grow or 0.1
	local outline = Instance.new("Part")
	outline.Name = "InkOutline"
	outline.Anchored = true
	outline.CanCollide = false
	outline.CanQuery = false
	outline.CanTouch = false
	outline.Color = Color3.fromRGB(8, 8, 10)
	outline.Material = Enum.Material.SmoothPlastic
	outline.Shape = part.Shape
	outline.Size = part.Size + Vector3.new(g, g, g)
	outline.CFrame = part.CFrame
	outline.Parent = model
	return outline
end

local function buildMechanical(model: Model): { Part }
	local parts: { Part } = {}
	local torso = mkPart(model, "Torso", Vector3.new(4.2, 5.2, 2.6), Color3.fromRGB(112, 178, 232), Enum.Material.Metal)
	table.insert(parts, torso)
	local chestLamp = mkPart(model, "ChestLamp", Vector3.new(1.6, 1.6, 0.4), Color3.fromRGB(140, 225, 255), nil, true, Enum.PartType.Cylinder, false)
	chestLamp.CFrame = torso.CFrame * CFrame.new(0, 0.8, 1.5)
	table.insert(parts, chestLamp)
	local head = mkPart(model, "Head", Vector3.new(2.6, 2.2, 2.4), Color3.fromRGB(150, 205, 245), Enum.Material.Metal)
	head.CFrame = torso.CFrame * CFrame.new(0, 3.8, 0)
	table.insert(parts, head)
	local antenna = mkPart(model, "Antenna", Vector3.new(0.4, 1.6, 0.4), Color3.fromRGB(80, 120, 160), Enum.Material.Metal)
	antenna.CFrame = head.CFrame * CFrame.new(0, 1.8, 0)
	table.insert(parts, antenna)
	local orb = mkPart(model, "AntennaOrb", Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(120, 235, 255), nil, true, Enum.PartType.Ball, false)
	orb.CFrame = antenna.CFrame * CFrame.new(0, 1.1, 0)
	table.insert(parts, orb)
	-- eyes
	for _, s in ipairs({ 1, -1 }) do
		local e = mkPart(model, "Eye", Vector3.new(0.45, 0.3, 0.1), Color3.fromRGB(255, 255, 200), nil, true, Enum.PartType.Block, false)
		e.CFrame = head.CFrame * CFrame.new(s * 0.62, 0.25, 1.22)
		table.insert(parts, e)
	end
	-- arms & legs
	for _, s in ipairs({ 1, -1 }) do
		local arm = mkPart(model, "Arm", Vector3.new(1.2, 4.4, 1.2), Color3.fromRGB(96, 96, 108), Enum.Material.Metal)
		arm.CFrame = torso.CFrame * CFrame.new(s * 2.8, -0.4, 0)
		table.insert(parts, arm)
		local leg = mkPart(model, "Leg", Vector3.new(1.5, 3.6, 1.5), Color3.fromRGB(70, 70, 82), Enum.Material.Metal)
		leg.CFrame = torso.CFrame * CFrame.new(s * 1.15, -4.4, 0)
		table.insert(parts, leg)
	end
	for _, p in ipairs(parts) do
		inkOutline(model, p, 0.12)
	end
	return parts
end

local function buildMachine(model: Model): { Part }
	local parts: { Part } = {}
	local torso = mkPart(model, "Torso", Vector3.new(5.4, 5.0, 3.0), Color3.fromRGB(118, 108, 96), Enum.Material.Rock)
	table.insert(parts, torso)
	local armor = mkPart(model, "PelvisPlate", Vector3.new(5.8, 1.6, 3.2), Color3.fromRGB(84, 76, 66), Enum.Material.Rock)
	armor.CFrame = torso.CFrame * CFrame.new(0, -3.1, 0)
	table.insert(parts, armor)
	local head = mkPart(model, "Head", Vector3.new(2.4, 2.0, 2.2), Color3.fromRGB(100, 92, 84), Enum.Material.Rock)
	head.CFrame = torso.CFrame * CFrame.new(0, 3.6, 0)
	table.insert(parts, head)
	for _, s in ipairs({ 1, -1 }) do
		local e = mkPart(model, "Eye", Vector3.new(0.5, 0.25, 0.1), Color3.fromRGB(255, 120, 60), nil, true, Enum.PartType.Block, false)
		e.CFrame = head.CFrame * CFrame.new(s * 0.6, 0.1, 1.12)
		table.insert(parts, e)
	end
	-- big rock hammer held to one side
	local hammerHead = mkPart(model, "HammerHead", Vector3.new(2.6, 2.2, 2.0), Color3.fromRGB(74, 68, 60), Enum.Material.Rock)
	hammerHead.CFrame = torso.CFrame * CFrame.new(4.6, 1.2, 0)
	table.insert(parts, hammerHead)
	local hammerHandle = mkPart(model, "HammerHandle", Vector3.new(0.8, 5.4, 0.8), Color3.fromRGB(66, 52, 38), Enum.Material.Wood)
	hammerHandle.CFrame = torso.CFrame * CFrame.new(4.6, -1.6, 0)
	table.insert(parts, hammerHandle)
	for _, s in ipairs({ 1, -1 }) do
		local arm = mkPart(model, "Arm", Vector3.new(1.6, 4.6, 1.6), Color3.fromRGB(88, 80, 70), Enum.Material.Rock)
		arm.CFrame = torso.CFrame * CFrame.new(s * 3.5, -0.3, 0)
		table.insert(parts, arm)
		local leg = mkPart(model, "Leg", Vector3.new(1.8, 4.0, 1.8), Color3.fromRGB(60, 54, 48), Enum.Material.Rock)
		leg.CFrame = torso.CFrame * CFrame.new(s * 1.4, -4.6, 0)
		table.insert(parts, leg)
	end
	for _, p in ipairs(parts) do
		inkOutline(model, p, 0.14)
	end
	return parts
end

local function buildFire(model: Model): { Part }
	local parts: { Part } = {}
	local core = mkPart(model, "LavaCore", Vector3.new(4.4, 5.6, 2.8), Color3.fromRGB(255, 96, 28), nil, true)
	table.insert(parts, core)
	local head = mkPart(model, "Head", Vector3.new(2.6, 2.2, 2.4), Color3.fromRGB(255, 140, 40), nil, true)
	head.CFrame = core.CFrame * CFrame.new(0, 3.9, 0)
	table.insert(parts, head)
	for _, s in ipairs({ 1, -1 }) do
		local e = mkPart(model, "Eye", Vector3.new(0.5, 0.35, 0.1), Color3.fromRGB(120, 20, 10), nil, true, Enum.PartType.Block, false)
		e.CFrame = head.CFrame * CFrame.new(s * 0.6, 0.15, 1.22)
		table.insert(parts, e)
		local coal = mkPart(model, "CoalShoulder", Vector3.new(1.8, 1.8, 1.8), Color3.fromRGB(28, 24, 22), Enum.Material.Slate, false, Enum.PartType.Ball)
		coal.CFrame = core.CFrame * CFrame.new(s * 3.0, 2.1, 0)
		table.insert(parts, coal)
		local arm = mkPart(model, "Arm", Vector3.new(1.3, 4.4, 1.3), Color3.fromRGB(200, 70, 22), nil, true)
		arm.CFrame = core.CFrame * CFrame.new(s * 2.7, -0.5, 0)
		table.insert(parts, arm)
		local leg = mkPart(model, "Leg", Vector3.new(1.6, 3.6, 1.6), Color3.fromRGB(150, 48, 18), nil, true)
		leg.CFrame = core.CFrame * CFrame.new(s * 1.2, -4.4, 0)
		table.insert(parts, leg)
	end
	-- flame plume on head
	local plume = mkPart(model, "Plume", Vector3.new(1.2, 2.6, 1.2), Color3.fromRGB(255, 210, 70), nil, true, Enum.PartType.Cylinder, false)
	plume.CFrame = head.CFrame * CFrame.new(0, 2.1, 0)
	table.insert(parts, plume)
	for _, p in ipairs(parts) do
		inkOutline(model, p, 0.12)
	end
	return parts
end

local function buildIce(model: Model): { Part }
	local parts: { Part } = {}
	local torso = mkPart(model, "Torso", Vector3.new(4.0, 5.2, 2.6), Color3.fromRGB(214, 236, 248), Enum.Material.Ice)
	table.insert(parts, torso)
	local head = mkPart(model, "Head", Vector3.new(2.5, 2.1, 2.3), Color3.fromRGB(238, 248, 252), Enum.Material.Ice)
	head.CFrame = torso.CFrame * CFrame.new(0, 3.7, 0)
	table.insert(parts, head)
	-- glasses visor
	local visor = mkPart(model, "Glasses", Vector3.new(2.3, 0.7, 0.2), Color3.fromRGB(60, 120, 255), nil, true, Enum.PartType.Block, false)
	visor.CFrame = head.CFrame * CFrame.new(0, 0.15, 1.17)
	table.insert(parts, visor)
	-- frost hair shards
	for i = -1, 1 do
		local shard = mkPart(model, "FrostShard", Vector3.new(0.7, 1.6 + (1 - math.abs(i)) * 0.7, 0.7), Color3.fromRGB(190, 226, 248), Enum.Material.Ice)
		shard.CFrame = head.CFrame * CFrame.new(i * 0.8, 1.6, 0) * CFrame.Angles(0, 0, math.rad(i * 18))
		table.insert(parts, shard)
	end
	for _, s in ipairs({ 1, -1 }) do
		local arm = mkPart(model, "Arm", Vector3.new(1.2, 4.3, 1.2), Color3.fromRGB(190, 216, 234), Enum.Material.Ice)
		arm.CFrame = torso.CFrame * CFrame.new(s * 2.7, -0.4, 0)
		table.insert(parts, arm)
		local leg = mkPart(model, "Leg", Vector3.new(1.5, 3.7, 1.5), Color3.fromRGB(160, 192, 214), Enum.Material.Ice)
		leg.CFrame = torso.CFrame * CFrame.new(s * 1.1, -4.4, 0)
		table.insert(parts, leg)
	end
	for _, p in ipairs(parts) do
		inkOutline(model, p, 0.12)
	end
	return parts
end

local function buildStorm(model: Model): { Part }
	local parts: { Part } = {}
	-- swirling dark-cloud body: stacked squashed balls
	local cloud1 = mkPart(model, "Cloud1", Vector3.new(6.2, 4.4, 4.2), Color3.fromRGB(52, 56, 84), Enum.Material.Slate, false, Enum.PartType.Ball)
	table.insert(parts, cloud1)
	local cloud2 = mkPart(model, "Cloud2", Vector3.new(4.6, 3.8, 3.6), Color3.fromRGB(66, 70, 104), Enum.Material.Slate, false, Enum.PartType.Ball)
	cloud2.CFrame = cloud1.CFrame * CFrame.new(0, 2.9, 0)
	table.insert(parts, cloud2)
	local head = mkPart(model, "Head", Vector3.new(2.8, 2.2, 2.4), Color3.fromRGB(38, 40, 62), Enum.Material.Slate)
	head.CFrame = cloud2.CFrame * CFrame.new(0, 2.3, 0)
	table.insert(parts, head)
	for _, s in ipairs({ 1, -1 }) do
		local e = mkPart(model, "Eye", Vector3.new(0.55, 0.75, 0.1), Color3.fromRGB(200, 150, 255), nil, true, Enum.PartType.Block, false)
		e.CFrame = head.CFrame * CFrame.new(s * 0.62, 0, 1.22)
		table.insert(parts, e)
	end
	-- lightning bolt spine
	local bolt = mkPart(model, "Bolt", Vector3.new(1.1, 4.6, 1.1), Color3.fromRGB(255, 245, 120), nil, true)
	bolt.CFrame = head.CFrame * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(12))
	table.insert(parts, bolt)
	for _, s in ipairs({ 1, -1 }) do
		local wing = mkPart(model, "WindWing", Vector3.new(3.6, 1.6, 0.7), Color3.fromRGB(120, 132, 190), Enum.Material.Slate)
		wing.CFrame = cloud1.CFrame * CFrame.new(s * 4.2, 0.6, 0) * CFrame.Angles(0, 0, math.rad(s * -14))
		table.insert(parts, wing)
	end
	for _, p in ipairs(parts) do
		inkOutline(model, p, 0.1)
	end
	return parts
end

local function buildSquid(model: Model): { Part }
	local parts: { Part } = {}
	local mantle = mkPart(model, "Mantle", Vector3.new(9.5, 7.5, 7.5), Color3.fromRGB(120, 26, 46), Enum.Material.Slate, false, Enum.PartType.Ball)
	table.insert(parts, mantle)
	local head = mkPart(model, "Head", Vector3.new(6.2, 4.6, 5.2), Color3.fromRGB(84, 16, 34), Enum.Material.Slate, false, Enum.PartType.Ball)
	head.CFrame = mantle.CFrame * CFrame.new(0, -4.6, 0)
	table.insert(parts, head)
	-- single colossal red eye
	local eye = mkPart(model, "Eye", Vector3.new(3.4, 3.4, 0.6), Color3.fromRGB(255, 40, 40), nil, true, Enum.PartType.Cylinder, false)
	eye.CFrame = head.CFrame * CFrame.new(0, 0, 2.45) * CFrame.Angles(math.rad(90), 0, 0)
	table.insert(parts, eye)
	local pupil = mkPart(model, "Pupil", Vector3.new(1.6, 1.6, 0.7), Color3.fromRGB(20, 0, 0), nil, false, Enum.PartType.Cylinder, false)
	pupil.CFrame = head.CFrame * CFrame.new(0, 0, 2.5) * CFrame.Angles(math.rad(90), 0, 0)
	table.insert(parts, pupil)
	-- armored tentacles (cylinders angled outward), sway handled in tick via attributes
	local tentacleCount = 6
	for i = 1, tentacleCount do
		local t = i - (tentacleCount + 1) / 2
		local tentacle = mkPart(model, "Tentacle" .. i, Vector3.new(1.7, 9.5, 1.7), Color3.fromRGB(140, 30, 52), Enum.Material.Slate, false, Enum.PartType.Cylinder)
		tentacle.CFrame = head.CFrame * CFrame.new(t * 1.9, -4.4, 0.5) * CFrame.Angles(0, 0, math.rad(t * 14))
		table.insert(parts, tentacle)
		-- spiky shell on each tentacle tip
		local tip = mkPart(model, "TentacleSpike" .. i, Vector3.new(2.0, 1.8, 2.0), Color3.fromRGB(60, 10, 22), Enum.Material.Slate, false, Enum.PartType.Ball, false)
		tip.CFrame = tentacle.CFrame * CFrame.new(0, -5.1, 0)
		table.insert(parts, tip)
	end
	for _, p in ipairs(parts) do
		inkOutline(model, p, 0.12)
	end
	return parts
end

local BUILDERS = {
	mechanical = { build = buildMechanical, yOffset = 5.6 },
	machine = { build = buildMachine, yOffset = 5.0 },
	fire = { build = buildFire, yOffset = 5.4 },
	ice = { build = buildIce, yOffset = 5.2 },
	storm = { build = buildStorm, yOffset = 6.4 },
	squid = { build = buildSquid, yOffset = 9.5 },
}

-- ————————————————————— construction ——————————————————————

function Bosses.init(ev, playerDamaged, bossDefeated)
	events = ev
	onPlayerDamaged = playerDamaged
	onBossDefeated = bossDefeated

	local root = game:GetService("Workspace"):FindFirstChild("EnchantedRealm")
	local arenaFolder = root and root:FindFirstChild("Arenas")

	for _, id in ipairs(Regions.ORDER) do
		local r = Regions.byId[id]
		local spec = r.boss
		if spec then
			local def = Config.BOSSES[spec.kind]
			local builder = BUILDERS[spec.kind]
			local baseY = spec.arenaY or 0
			local model = Instance.new("Model")
			model.Name = "Boss_" .. spec.kind

			-- build parts centred on a temporary origin, then offset to world
			local parts = builder.build(model)
			local origin = Vector3.new(spec.x, baseY + builder.yOffset, 0)
			for _, p in ipairs(parts) do
				local rel = p.CFrame - Vector3.new(0, 0, 0) -- parts were built around origin already
				p.CFrame = p.CFrame + origin
			end
			-- recentres: parts were authored around (0,0,0) + torso at origin; shift whole model
			model.Parent = arenaFolder or root

			-- anchor everything (movement is scripted)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end

			local boss: Boss = {
				kind = spec.kind,
				def = def,
				model = model,
				bodyParts = parts,
				hp = def.hp,
				maxHp = def.hp,
				x = spec.x,
				y = baseY,
				area = { minX = spec.arenaMinX, maxX = spec.arenaMaxX },
				state = "dormant",
				cooldowns = {},
				rootedUntil = 0,
				stunnedUntil = 0,
				burnUntil = 0,
				regainUntil = 0,
				submergedUntil = 0,
				surfacedUntil = 0,
				lastContactDamage = 0,
				lockWalls = {},
				introPlayed = false,
			phase2 = false,
			}
			table.insert(bossList, boss)
		end
	end
end

-- ————————————————————— helpers ——————————————————————

local function currentPlayerChar(): (Player?, Model?, BasePart?)
	local players = game:GetService("Players"):GetPlayers()
	local p = players[1]
	local char = p and p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return p, char, hrp
end

local function bossCenter(boss: Boss): Vector3
	-- average of torso-ish parts (first part is the core body)
	local p = boss.bodyParts[1]
	return p and p.Position or Vector3.new(boss.x, boss.y + 5, 0)
end

local function shiftBoss(boss: Boss, dx: number, dy: number?)
	local delta = Vector3.new(dx, dy or 0, 0)
	for _, p in ipairs(boss.bodyParts) do
		p.CFrame = p.CFrame + delta
	end
	boss.x += dx
	boss.y += (dy or 0)
end

local function fireBossBar(boss: Boss)
	if events then
		events.BossHealth:FireAllClients(boss.kind, boss.def.name, boss.hp, boss.maxHp)
	end
end

local function arenaLock(boss: Boss)
	local root = game:GetService("Workspace"):FindFirstChild("EnchantedRealm")
	local folder = root and root:FindFirstChild("Arenas")
	for _, x in ipairs({ boss.area.minX - 2, boss.area.maxX + 2 }) do
		local wall = Instance.new("Part")
		wall.Name = "ArenaLock_" .. boss.kind
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanQuery = false
		wall.Transparency = 1
		wall.Size = Vector3.new(4, 80, 16)
		wall.CFrame = CFrame.new(x, 20, 0)
		wall.Parent = folder
		table.insert(boss.lockWalls, wall)
	end
end

local function arenaUnlock(boss: Boss)
	for _, w in ipairs(boss.lockWalls) do
		w:Destroy()
	end
	boss.lockWalls = {}
end

local function projectile(from: Vector3, dir: Vector3, speed: number, damage: number, color: Color3, name: string, arc: boolean?, aoe: number?)
	local p = Instance.new("Part")
	p.Name = "BossProjectile_" .. name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.5, 1.5, 1.5)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.CanCollide = false
	p.CanQuery = false
	p.Anchored = false
	p.Massless = true
	p.Parent = game:GetService("Workspace")
	p.CFrame = CFrame.new(from)
	p.AssemblyLinearVelocity = dir.Unit * speed
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not p.Parent then
			conn:Disconnect()
			return
		end
		if os.clock() - born > 5 then
			p:Destroy()
			conn:Disconnect()
			return
		end
		local _, _, hrp = currentPlayerChar()
		if hrp and (hrp.Position - p.Position).Magnitude < 3.4 then
			if onPlayerDamaged then
				onPlayerDamaged(damage, p.Position, name)
			end
			if aoe and aoe > 0 then
				local a = Instance.new("Attachment")
				a.Parent = p
				local emitter = Instance.new("ParticleEmitter")
				emitter.Texture = "rbxassetid://243660364"
				emitter.Color = ColorSequence.new(color)
				emitter.Rate = 0
				emitter.Lifetime = NumberRange.new(0.3, 0.6)
				emitter.Speed = NumberRange.new(5, 10)
				emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
				emitter.Parent = a
				emitter:Emit(18)
			end
			p:Destroy()
			conn:Disconnect()
		end
	end)
	Debris:AddItem(p, 6)
end

local function telegraphedStrike(x: number, delayTime: number, radius: number, damage: number, color: Color3, name: string)
	-- red/neon marker decal part on the ground, then a vertical bolt
	local marker = Instance.new("Part")
	marker.Name = "StrikeMarker_" .. name
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Color = color
	marker.Transparency = 0.45
	marker.Size = Vector3.new(radius * 2, 0.2, radius * 2)
	marker.CFrame = CFrame.new(x, 0.15, 0)
	marker.Parent = game:GetService("Workspace")
	Debris:AddItem(marker, delayTime + 0.6)

	task.delay(delayTime, function()
		local bolt = Instance.new("Part")
		bolt.Name = "StrikeBolt_" .. name
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.Material = Enum.Material.Neon
		bolt.Color = color
		bolt.Size = Vector3.new(radius * 1.1, 90, radius * 1.1)
		bolt.CFrame = CFrame.new(x, 45, 0)
		bolt.Parent = game:GetService("Workspace")
		Debris:AddItem(bolt, 0.35)
		local _, _, hrp = currentPlayerChar()
		if hrp and math.abs(hrp.Position.X - x) < radius and hrp.Position.Y < 30 then
			if onPlayerDamaged then
				onPlayerDamaged(damage, Vector3.new(x, 1, 0), name)
			end
		end
		if events then
			events.VFX:FireAllClients("strike", Vector3.new(x, 1, 0), color)
		end
	end)
end

local function groundSpikes(originX: number, direction: number, count: number, damage: number, rootTime: number, big: boolean)
	for i = 1, count do
		local sx = originX + direction * (4 + i * 3.4)
		local marker = Instance.new("Part")
		marker.Name = "SpikeMarker"
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Material = Enum.Material.Neon
		marker.Color = Color3.fromRGB(170, 230, 255)
		marker.Transparency = 0.5
		marker.Size = Vector3.new(2.4, 0.15, 6)
		marker.CFrame = CFrame.new(sx, 0.1, 0)
		marker.Parent = game:GetService("Workspace")
		Debris:AddItem(marker, 1.4)
		task.delay(0.7, function()
			local h = big and 4.6 or 2.6
			local spike = Instance.new("Part")
			spike.Name = "IceSpike"
			spike.Anchored = true
			spike.Material = Enum.Material.Ice
			spike.Color = Color3.fromRGB(190, 232, 250)
			spike.Size = Vector3.new(2.2, h, 2.2)
			spike.CFrame = CFrame.new(sx, h / 2, 0)
			spike.Parent = game:GetService("Workspace")
			local tip = Instance.new("Part")
			tip.Name = "IceSpikeTip"
			tip.Anchored = true
			tip.Material = Enum.Material.Neon
			tip.Color = Color3.fromRGB(220, 245, 255)
			tip.Shape = Enum.PartType.Cylinder
			tip.Size = Vector3.new(1.2, 1.2, 1.2)
			tip.CFrame = CFrame.new(sx, h + 0.6, 0)
			tip.Parent = game:GetService("Workspace")
			Debris:AddItem(spike, 1.6)
			Debris:AddItem(tip, 1.6)
			local _, _, hrp = currentPlayerChar()
			if hrp and math.abs(hrp.Position.X - sx) < 2.2 and hrp.Position.Y < h + 1.5 then
				if onPlayerDamaged then
					onPlayerDamaged(damage, Vector3.new(sx, 1, 0), "Ice Spike")
				end
				if events then
					events.Rooted:FireAllClients(rootTime)
				end
			end
		end)
	end
end

-- ————————————————————— damage API (server -> client handled by Main) ——————————————————————

function Bosses.damageInRange(center: Vector3, radius: number, amount: number, element: string?): boolean
	-- returns true if any boss was hit (used by melee/aoe resolution in Main)
	local hitAny = false
	for _, boss in ipairs(bossList) do
		if boss.state ~= "active" and boss.state ~= "intro" then
			continue
		end
		local c = bossCenter(boss)
		if (c - center).Magnitude <= radius + 5 then
			Bosses.damage(boss, amount, element, center)
			hitAny = true
		end
	end
	return hitAny
end

function Bosses.damage(boss: Boss, amount: number, element: string?, fromPos: Vector3?)
	if boss.state ~= "active" and boss.state ~= "intro" then
		return
	end
	local now = os.clock()
	local mult = 1

	-- GDD weakness rules
	if boss.kind == "mechanical" and now < boss.rootedUntil then
		mult *= 1.5
	end
	if boss.kind == "machine" and now < boss.stunnedUntil then
		mult *= 2.0
	end
	if boss.kind == "storm" and now < boss.regainUntil then
		mult *= 1.5
	end
	if boss.kind == "squid" then
		if element == "fire" then
			mult *= 1.6
		elseif element == "lightning" then
			mult *= 1.8
		elseif element == "ice" then
			-- freeze interrupts
			boss.submergedUntil = 0
			boss.stunnedUntil = math.max(boss.stunnedUntil, now + 2.5)
			mult *= 1.1
		end
	end
	if boss.kind == "squid" and now < boss.submergedUntil then
		-- submerged = invulnerable
		fireBossBar(boss)
		return
	end

	boss.hp -= amount * mult
	-- hit flash
	for _, p in ipairs(boss.bodyParts) do
		local original = p.Color
		p.Color = Color3.fromRGB(255, 255, 255)
		task.delay(0.07, function()
			if p.Parent then
				p.Color = original
			end
		end)
	end
	fireBossBar(boss)
	if events then
		events.BossHit:FireAllClients(boss.kind, amount * mult, element or "physical")
	end
	-- phase 2 enrage at 50% HP
	if not boss.phase2 and boss.hp <= boss.maxHp * 0.5 then
		boss.phase2 = true
		boss.cooldowns = {} -- reset all cooldowns for new phase
		if events then
			events.BossRoar:FireAllClients(boss.kind)
			events.VFX:FireAllClients("bossBurst", bossCenter(boss), boss.def.color)
		end
		-- phase 2: faster, more aggressive
		if events then
			events.BossAttack:FireAllClients("enrage", boss.x)
		end
	end
	if boss.hp <= 0 then
		Bosses.defeat(boss)
	end
end

function Bosses.defeat(boss: Boss)
	if boss.state == "defeated" then
		return
	end
	boss.state = "defeated"
	boss.hp = 0
	fireBossBar(boss)
	arenaUnlock(boss)
	-- collapse animation: sink into ground
	local parts = boss.bodyParts
	local sinkSteps = 24
	for i = 1, sinkSteps do
		task.wait(0.05)
		for _, p in ipairs(parts) do
			p.CFrame = p.CFrame + Vector3.new(0, -0.28, 0)
		end
	end
	-- explosion burst
	local c = bossCenter(boss)
	local burst = Instance.new("Part")
	burst.Anchored = true
	burst.CanCollide = false
	burst.Transparency = 1
	burst.Size = Vector3.new(0.1, 0.1, 0.1)
	burst.Position = c
	burst.Parent = game:GetService("Workspace")
	local a = Instance.new("Attachment")
	a.Parent = burst
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://243660364"
	emitter.Color = ColorSequence.new(boss.def.color, Color3.fromRGB(255, 255, 255))
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(10, 26)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = a
	emitter:Emit(60)
	Debris:AddItem(burst, 2)

	for _, p in ipairs(parts) do
		p:Destroy()
	end
	boss.model:Destroy()
	if events then
		events.BossDefeated:FireAllClients(boss.kind, boss.def.name)
	end
	if onBossDefeated then
		onBossDefeated(boss.kind)
	end
end

-- Reset a boss to pristine dormant state (called when the player dies)
function Bosses.reset(boss: Boss)
	-- hp refresh; model stays destroyed if it died, so only meaningful for live fights
	boss.hp = boss.maxHp
	boss.state = "dormant"
	arenaUnlock(boss)
	boss.cooldowns = {}
	boss.rootedUntil = 0
	boss.stunnedUntil = 0
	boss.regainUntil = 0
	boss.submergedUntil = 0
	fireBossBar(boss)
end

function Bosses.resetAll()
	for _, b in ipairs(bossList) do
		if b.state == "active" or b.state == "intro" then
			Bosses.reset(b)
		end
	end
end

function Bosses.anyActive(): boolean
	for _, b in ipairs(bossList) do
		if b.state == "active" or b.state == "intro" then
			return true
		end
	end
	return false
end

-- ————————————————————— AI tick ——————————————————————

local function pickCooldown(boss: Boss, key: string, now: number, value: number)
	boss.cooldowns[key] = now + value
end
local function ready(boss: Boss, key: string, now: number): boolean
	return (boss.cooldowns[key] or 0) <= now
end

local tickAccum = 0
local function connRenderCleanup(conn: RBXScriptConnection, age: number)
	if age > 2.2 then
		conn:Disconnect()
	end
end
local function tick(dt: number)
	tickAccum += dt
	local _, _, hrp = currentPlayerChar()
	local now = os.clock()

	for _, boss in ipairs(bossList) do
		if boss.state == "dormant" then
			-- activate when the player enters the arena
			if hrp then
				local px = hrp.Position.X
				local triggerX = Regions.byId[boss.kind == "mechanical" and "forest"
						or boss.kind == "machine" and "ruins"
						or boss.kind == "fire" and "burning"
						or boss.kind == "ice" and "frozen"
						or boss.kind == "storm" and "sky"
						or "underground"].boss.triggerX
				if boss.kind == "squid" then
					if px >= (triggerX or 2405) then
						boss.state = "intro"
						arenaLock(boss)
						if events then
							events.BossIntro:FireAllClients(boss.kind, boss.def.name, boss.def.title)
						end
					end
				elseif px >= boss.area.minX and px <= boss.area.maxX then
					boss.state = "intro"
					arenaLock(boss)
					if events then
						events.BossIntro:FireAllClients(boss.kind, boss.def.name, boss.def.title)
					end
				end
			end

		elseif boss.state == "intro" then
			boss.cooldowns.introEnd = now + 2.2
			boss.state = "active"
			if events then
				events.BossRoar:FireAllClients(boss.kind)
			end

		elseif boss.state == "active" then
			if not hrp then
				continue
			end
			local px = hrp.Position.X
			local dx = px - boss.x
			local dist = math.abs(dx)
			local dir = if dx >= 0 then 1 else -1
			local profile = boss.def

			-- electricity strip damage? (environmental, handled by Main via hazards)

			-- contact damage
			if dist < 4.6 and hrp.Position.Y < boss.y + 12 then
				if now - boss.lastContactDamage > 1.2 then
					boss.lastContactDamage = now
					if onPlayerDamaged then
						onPlayerDamaged(math.floor(profile.damage * 0.7), bossCenter(boss), profile.name)
					end
				end
			end

			-- vine root check (mechanical guardian bait)
			if boss.kind == "mechanical" then
				local vp = Regions.byId.forest.vinePatch
				if vp and boss.x >= vp.x0 and boss.x <= vp.x1 and now >= boss.rootedUntil then
					boss.rootedUntil = now + 15
					if events then
						events.VFX:FireAllClients("root", Vector3.new(boss.x, 0.5, 0), Color3.fromRGB(90, 200, 90))
					end
				end
			end

			local rooted = now < boss.rootedUntil
			local stunned = now < boss.stunnedUntil
			local canMove = not rooted and not stunned

			-- phase 2 enrage: periodic charge attack (all bosses)
			if boss.phase2 and ready(boss, "enrageCharge", now) then
				pickCooldown(boss, "enrageCharge", now, 5)
				local chargeX = hrp.Position.X
				telegraphedStrike(chargeX, 0.6, 3.2, 0, boss.def.color, "Enrage Charge")
				task.delay(0.6, function()
					if onPlayerDamaged and hrp and hrp.Parent then
						if math.abs(hrp.Position.X - chargeX) < 3.6 then
							onPlayerDamaged(math.floor(profile.damage * 1.3), bossCenter(boss), "Enrage Charge")
						end
					end
					if events then
						events.BossAttack:FireAllClients("enrageCharge", chargeX)
					end
				end)
			end

			-- per-boss brains
			if boss.kind == "mechanical" then
				-- chase slowly, prefer beams at range
				if canMove then
					shiftBoss(boss, dir * 3.2 * dt, 0)
				end
				if dist > 12 and ready(boss, "beam", now) then
					pickCooldown(boss, "beam", now, 4.2)
					-- telegraph then beam
					local tx = hrp.Position.X
					telegraphedStrike(tx, 0.75, 2.2, 0, Color3.fromRGB(150, 230, 255), "Energy Beam")
					task.delay(0.75, function()
						if onPlayerDamaged and hrp and hrp.Parent then
							if math.abs(hrp.Position.X - tx) < 2.6 and hrp.Position.Y < 25 then
								onPlayerDamaged(18, Vector3.new(tx, hrp.Position.Y, 0), "Energy Beam")
							end
						end
					end)
					if events then
						events.BossAttack:FireAllClients("beam", tx)
					end
				elseif dist <= 7 and ready(boss, "swipe", now) then
					pickCooldown(boss, "swipe", now, 1.8)
					if onPlayerDamaged then
						onPlayerDamaged(profile.damage, bossCenter(boss), profile.name)
					end
				end
				-- shield pulse every 17s
				if ready(boss, "pulse", now) then
					pickCooldown(boss, "pulse", now, 17)
					local pulse = Instance.new("Part")
					pulse.Name = "ShieldPulse"
					pulse.Shape = Enum.PartType.Cylinder
					pulse.Anchored = true
					pulse.CanCollide = false
					pulse.CanQuery = false
					pulse.Material = Enum.Material.Neon
					pulse.Color = Color3.fromRGB(150, 230, 255)
					pulse.Transparency = 0.4
					pulse.Size = Vector3.new(1.2, 3, 3)
					pulse.CFrame = CFrame.new(boss.x, boss.y + 4, 0) * CFrame.Angles(0, 0, math.rad(90))
					pulse.Parent = game:GetService("Workspace")
					Debris:AddItem(pulse, 1.1)
					local t0 = os.clock()
					local conn: RBXScriptConnection
					conn = RunService.Heartbeat:Connect(function(step)
						local age = os.clock() - t0
						local radius = age * 26 + 2
						pulse.Size = Vector3.new(1.2, radius * 2, radius * 2)
						pulse.Transparency = 0.4 + age * 0.55
						if hrp and hrp.Parent then
							local d = math.abs(hrp.Position.X - boss.x)
							if math.abs(d - radius) < 2.4 and pulse.Transparency < 0.9 then
								hrp.AssemblyLinearVelocity = Vector3.new(if hrp.Position.X >= boss.x then 48 else -48, 16, 0)
								if onPlayerDamaged then
									onPlayerDamaged(8, bossCenter(boss), "Shield Pulse")
								end
							end
						end
						if age > 1.0 then
							conn:Disconnect()
						end
					end)
					if events then
						events.BossAttack:FireAllClients("pulse", boss.x)
					end
				end

			elseif boss.kind == "machine" then
				if canMove then
					shiftBoss(boss, dir * 2.6 * dt, 0)
				end
				-- dash attack
				if dist > 10 and ready(boss, "dash", now) then
					pickCooldown(boss, "dash", now, 4.5)
					local dashDir = dir
					local startX = boss.x
					local steps = 14
					local stepLen = 3.4 * dashDir
					local hitPillar = false
					for i = 1, steps do
						task.wait(0.045)
						shiftBoss(boss, stepLen, 0)
						for _, px in ipairs(Regions.byId.ruins.pillars) do
							if math.abs(boss.x - px) < 2.6 then
								hitPillar = true
								break
							end
						end
						if hitPillar then
							break
						end
					end
					if hitPillar then
						boss.stunnedUntil = now + 5
						Bosses.damage(boss, 60, "pillar", nil) -- clashes for massive damage
						if events then
							events.VFX:FireAllClients("pillarCrash", Vector3.new(boss.x, 3, 0), Color3.fromRGB(255, 220, 140))
							events.BossAttack:FireAllClients("pillarCrash", boss.x)
						end
					elseif hrp and math.abs(hrp.Position.X - boss.x) < 4 and hrp.Parent then
						hrp.AssemblyLinearVelocity = Vector3.new(dashDir * 40, 14, 0)
						if onPlayerDamaged then
							onPlayerDamaged(profile.damage, bossCenter(boss), "Dash Attack")
						end
					end
				-- slam
				elseif dist <= 7.5 and ready(boss, "slam", now) then
					pickCooldown(boss, "slam", now, 2.3)
					if hrp and math.abs(hrp.Position.X - boss.x) < 7 then
						hrp.AssemblyLinearVelocity = Vector3.new(if dx >= 0 then 26 else -26, 22, 0)
						if onPlayerDamaged then
							onPlayerDamaged(profile.damage, bossCenter(boss), "Hammer Slam")
						end
					end
					if events then
						events.BossAttack:FireAllClients("slam", boss.x)
					end
				end

			elseif boss.kind == "fire" then
				if canMove then
					shiftBoss(boss, dir * 2.9 * dt, 0)
				end
				-- fire wall on his perimeter, sweeping outward
				if ready(boss, "firewall", now) then
					pickCooldown(boss, "firewall", now, 6.5)
					for _, side in ipairs({ -1, 1 }) do
						local wall = Instance.new("Part")
						wall.Name = "FireWall"
						wall.Anchored = true
						wall.CanCollide = false
						wall.CanQuery = false
						wall.Material = Enum.Material.Neon
						wall.Color = Color3.fromRGB(255, 120, 30)
						wall.Transparency = 0.15
						wall.Size = Vector3.new(2.2, 3.4, 10)
						wall.CFrame = CFrame.new(boss.x + side * 3, 1.7, 0)
						wall.Parent = game:GetService("Workspace")
						Debris:AddItem(wall, 2.4)
						local t0 = os.clock()
						local conn: RBXScriptConnection
						conn = RunService.Heartbeat:Connect(function(step)
							local age = os.clock() - t0
							wall.CFrame = wall.CFrame + Vector3.new(side * 14 * step, 0, 0)
							if hrp and hrp.Parent and math.abs(hrp.Position.X - wall.Position.X) < 2.4 and hrp.Position.Y < 4.5 then
								if onPlayerDamaged then
									onPlayerDamaged(10, wall.Position, "Fire Wall")
								end
								if events then
									events.BurnPlayer:FireAllClients(3)
								end
							end
							connRenderCleanup(conn, age)
						end)
					end
					if events then
						events.BossAttack:FireAllClients("firewall", boss.x)
					end
				end
				-- eruption if the player camps in one spot
				local still = hrp and hrp.AssemblyLinearVelocity and hrp.AssemblyLinearVelocity.Magnitude < 1.5
				if hrp and still then
					if not (boss :: any).stillSince then
						(boss :: any).stillSince = now
					elseif now - (boss :: any).stillSince > 1.6 and ready(boss, "eruption", now) then
						pickCooldown(boss, "eruption", now, 3.5)
						(boss :: any).stillSince = now -- reset timer
						telegraphedStrike(hrp.Position.X, 0.9, 2.6, 25, Color3.fromRGB(255, 110, 30), "Fire Eruption")
					end
				else
					(boss :: any).stillSince = nil
				end
				if dist <= 6.5 and ready(boss, "swipe", now) then
					pickCooldown(boss, "swipe", now, 1.7)
					if onPlayerDamaged then
						onPlayerDamaged(profile.damage, bossCenter(boss), "Flame Swipe")
					end
				end

			elseif boss.kind == "ice" then
				if canMove then
					shiftBoss(boss, dir * 2.7 * dt, 0)
				end
				-- glasses volley
				if dist > 6 and ready(boss, "volley", now) then
					pickCooldown(boss, "volley", now, 2.7)
					local target = hrp.Position + Vector3.new(0, 1.5, 0)
					local origin = bossCenter(boss) + Vector3.new(0, 4.2, 0)
					for _, spread in ipairs({ -0.14, 0, 0.14 }) do
						local dirV = (target - origin).Unit
						local rotated = Vector3.new(dirV.X * math.cos(spread) - dirV.Y * math.sin(spread), dirV.X * math.sin(spread) + dirV.Y * math.cos(spread), 0)
						projectile(origin, rotated, 46, 12, Color3.fromRGB(170, 225, 255), "Ice Shard", false, 0)
					end
					if events then
						events.BossAttack:FireAllClients("volley", boss.x)
					end
				elseif dist <= 5.5 and ready(boss, "swipe", now) then
					pickCooldown(boss, "swipe", now, 1.6)
					if onPlayerDamaged then
						onPlayerDamaged(profile.damage, bossCenter(boss), "Frost Swipe")
					end
				end
				-- stomps
				if ready(boss, "stompBig", now) then
					pickCooldown(boss, "stompBig", now, 15)
					groundSpikes(boss.x, dir, 5, 18, 2, true)
					if events then
						events.BossAttack:FireAllClients("stompBig", boss.x)
					end
				elseif ready(boss, "stompSmall", now) then
					pickCooldown(boss, "stompSmall", now, 5.5)
					groundSpikes(boss.x, dir, 5, 10, 0.9, false)
					if events then
						events.BossAttack:FireAllClients("stompSmall", boss.x)
					end
				end

			elseif boss.kind == "storm" then
				-- hover: no gravity, gentle drift toward the player at range, bobbing
				local hoverY = 6 + math.sin(now * 1.6) * 1.2
				local targetYDelta = (boss.y + hoverY) - bossCenter(boss).Y
				if canMove then
					shiftBoss(boss, dir * 2.4 * dt, math.clamp(targetYDelta * 0.6 * dt, -1.2, 1.2))
				end
				-- lightning strike on the player's position
				if ready(boss, "bolt", now) then
					pickCooldown(boss, "bolt", now, 3.1)
					telegraphedStrike(hrp.Position.X, 0.8, 3.2, 20, Color3.fromRGB(220, 190, 255), "Lightning Strike")
					if events then
						events.BossAttack:FireAllClients("bolt", hrp.Position.X)
					end
				end
				-- thunder orb (arcing)
				if ready(boss, "orb", now) then
					pickCooldown(boss, "orb", now, 4.4)
					local origin = bossCenter(boss)
					local to = hrp.Position - origin
					local flat = Vector3.new(to.X, 0, 0)
					local dirV = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
					projectile(origin, dirV + Vector3.new(0, 0.35, 0), 40, 14, Color3.fromRGB(255, 240, 130), "Thunder Orb", true, 3.5)
					if events then
						events.BossAttack:FireAllClients("orb", boss.x)
					end
				end
				-- wind blast every 5s; then she regains power (vulnerable)
				if ready(boss, "windblast", now) then
					pickCooldown(boss, "windblast", now, 5)
					hrp.AssemblyLinearVelocity = Vector3.new(if dx >= 0 then 60 else -60, 10, 0)
					boss.regainUntil = now + 2.4
					if onPlayerDamaged then
						onPlayerDamaged(8, bossCenter(boss), "Wind Blast")
					end
					if events then
						events.BossAttack:FireAllClients("windblast", boss.x)
					end
				end

			elseif boss.kind == "squid" then
				local submerged = now < boss.submergedUntil
				if submerged then
					-- drift silently toward under the player
					shiftBoss(boss, dir * 5.2 * dt, 0)
				else
					if canMove then
						shiftBoss(boss, dir * 2.1 * dt, 0)
					end
					-- resurface cycle: every 17s dive for 5s
					if now >= (boss.surfacedUntil or 0) then
						if ready(boss, "dive", now) then
							pickCooldown(boss, "dive", now, 17)
							boss.submergedUntil = now + 5
							boss.surfacedUntil = now + 22
							if events then
								events.BossAttack:FireAllClients("dive", boss.x)
							end
						end
					end
					-- tentacle slam
					if ready(boss, "slamT", now) then
						pickCooldown(boss, "slamT", now, 3.6)
						telegraphedStrike(hrp.Position.X, 0.85, 2.6, 25, Color3.fromRGB(150, 30, 60), "Tentacle Slam")
						if events then
							events.BossAttack:FireAllClients("slamT", hrp.Position.X)
						end
					end
					-- ink blast spread
					if ready(boss, "ink", now) then
						pickCooldown(boss, "ink", now, 6.2)
						local origin = bossCenter(boss)
						for _, spread in ipairs({ -0.22, 0, 0.22 }) do
							local base = (hrp.Position - origin).Unit
							local rot = Vector3.new(base.X * math.cos(spread) - base.Y * math.sin(spread), base.X * math.sin(spread) + base.Y * math.cos(spread), 0)
							projectile(origin, rot, 38, 12, Color3.fromRGB(30, 12, 28), "Ink Blast", false, 0)
						end
						if events then
							events.BlindPlayer:FireAllClients(2)
							events.BossAttack:FireAllClients("ink", boss.x)
						end
					end
					-- tentacle grab: pull the player in
					if dist < 11 and ready(boss, "grab", now) then
						pickCooldown(boss, "grab", now, 9)
						local pull = math.min(16, dist - 2)
						hrp.CFrame = hrp.CFrame + Vector3.new(if dx >= 0 then -pull else pull, 0, 0)
						if onPlayerDamaged then
							onPlayerDamaged(15, bossCenter(boss), "Tentacle Grab")
						end
						if events then
							events.BossAttack:FireAllClients("grab", boss.x)
						end
					end
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(tick)

function Bosses.allBosses(): { Boss }
	return bossList
end

return Bosses
