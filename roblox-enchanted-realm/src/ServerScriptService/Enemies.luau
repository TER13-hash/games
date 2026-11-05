--!strict
-- Enchantadian Creeps & Machines — patrol / aggro / attack / death / freeze.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Regions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Regions"))

local Enemies = {}
Enemies.__index = Enemies

export type Creep = {
	id: number,
	kind: string,
	model: Model,
	body: Part,
	hp: number,
	maxHp: number,
	def: any,
	homeX: number,
	homeY: number,
	patrolDir: number,
	attackCooldown: number,
	frozenUntil: number,
	burnUntil: number,
	alive: boolean,
	hpBar: Frame?,
	hpFill: Frame?,
}

local creeps: { [number]: Creep } = {}
local nextId = 1
local onPlayerDamaged: ((damage: number, fromPos: Vector3, kind: string) -> ())? = nil
local onCreepKilled: ((milestone: string, xp: number) -> ())? = nil
local events: any = nil

local GRAVITY_FREEZE = "Frozen"

local function newBody(parent: Model, def: any)
	local scale = def.scale or 1
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3.2 * scale, 3.0 * scale, 2.2 * scale)
	body.Material = Enum.Material.SmoothPlastic
	body.Color = def.color
	body.Anchored = false
	body.CanCollide = true
	body.Massless = false
	body.Parent = parent

	-- un-anchor trick: we move via velocity; keep upright with a BodyGyro
	local gyro = Instance.new("BodyGyro")
	gyro.MaxTorque = Vector3.new(0, 4e4, 0)
	gyro.D = 500
	gyro.P = 3000
	gyro.CFrame = CFrame.new()
	gyro.Parent = body

	local attachment = Instance.new("Attachment")
	attachment.Parent = body

	-- glowing eyes on both faces of the body (side-scroller readability)
	for _, side in ipairs({ 1, -1 }) do
		local eyeL = Instance.new("Part")
		eyeL.Name = "Eye"
		eyeL.Size = Vector3.new(0.45 * scale, 0.45 * scale, 0.1)
		eyeL.Material = Enum.Material.Neon
		eyeL.Color = def.eyeColor
		eyeL.CanCollide = false
		eyeL.CanQuery = false
		eyeL.Massless = true
		eyeL.Parent = parent
		eyeL.CFrame = body.CFrame + Vector3.new(-0.7 * scale, 0.35 * scale, side * (body.Size.Z / 2 + 0.05))

		local eyeR = eyeL:Clone()
		eyeR.Parent = parent
		eyeR.CFrame = body.CFrame + Vector3.new(0.7 * scale, 0.35 * scale, side * (body.Size.Z / 2 + 0.05))

		local wl = Instance.new("Weld")
		wl.Part0 = body
		wl.Part1 = eyeL
		wl.C0 = CFrame.new(-0.7 * scale, 0.35 * scale, side * (body.Size.Z / 2 + 0.05))
		wl.Parent = eyeL
		local wr = Instance.new("Weld")
		wr.Part0 = body
		wr.Part1 = eyeR
		wr.C0 = CFrame.new(0.7 * scale, 0.35 * scale, side * (body.Size.Z / 2 + 0.05))
		wr.Parent = eyeR
	end
	return body
end

local function attachHealthBar(model: Model, body: Part, def: any)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HPBar"
	billboard.Size = UDim2.new(0, 64, 0, 8)
	billboard.StudsOffset = Vector3.new(0, (body.Size.Y / 2) + 1.1, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 55
	billboard.Parent = body

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.new(1, 0, 1, 0)
	back.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return back, fill
end

function Enemies.spawn(kind: string, x: number, y: number?): Creep?
	local def = (Config.ENEMIES :: any)[kind]
	if not def then
		warn("[Inkbound] unknown creep kind:", kind)
		return nil
	end
	local groundY = y or 0
	local model = Instance.new("Model")
	model.Name = "Creep_" .. kind

	local body = newBody(model, def)
	local startY = groundY + body.Size.Y / 2 + 0.05
	body.CFrame = CFrame.new(x, startY, 0)

	local back, fill = attachHealthBar(model, body, def)

	-- name tag, tiny & stylish
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.new(0, 120, 0, 16)
	tag.StudsOffset = Vector3.new(0, -(body.Size.Y / 2) - 0.8, 0)
	tag.MaxDistance = 40
	tag.Parent = body
	local tagLbl = Instance.new("TextLabel")
	tagLbl.BackgroundTransparency = 1
	tagLbl.Size = UDim2.new(1, 0, 1, 0)
	tagLbl.Font = Enum.Font.Bangers
	tagLbl.Text = def.name
	tagLbl.TextScaled = true
	tagLbl.TextColor3 = Color3.fromRGB(255, 244, 210)
	tagLbl.TextStrokeTransparency = 0.5
	tagLbl.TextStrokeColor3 = Color3.fromRGB(10, 10, 12)
	tagLbl.Parent = tag

	model.PrimaryPart = body
	model.Parent = game:GetService("Workspace"):FindFirstChild("EnchantedRealm") or game:GetService("Workspace")

	local creep: Creep = {
		id = nextId,
		kind = kind,
		model = model,
		body = body,
		hp = def.hp,
		maxHp = def.hp,
		def = def,
		homeX = x,
		homeY = startY,
		patrolDir = (rngDir()),
		attackCooldown = 0,
		frozenUntil = 0,
		burnUntil = 0,
		alive = true,
		hpBar = back :: any,
		hpFill = fill :: any,
	}
	nextId += 1
	creeps[creep.id] = creep
	return creep
end

function rngDir(): number
	return (math.random() < 0.5) and -1 or 1
end

function Enemies.spawnAllFromRegions()
	for _, id in ipairs(Regions.ORDER) do
		local r = Regions.byId[id]
		for _, s in ipairs(r.creeps or {}) do
			Enemies.spawn(s.kind, s.x, s.y)
		end
	end
end

function Enemies.setCallbacks(ev: any, playerDamagedCb: (damage: number, fromPos: Vector3, kind: string) -> ())
	events = ev
	onPlayerDamaged = playerDamagedCb
end

function Enemies.forEach(fn: (c: Creep) -> ())
	for _, c in pairs(creeps) do
		if c.alive then
			fn(c)
		end
	end
end

function Enemies.count(): number
	local n = 0
	for _, c in pairs(creeps) do
		if c.alive then
			n += 1
		end
	end
	return n
end

function Enemies.getByModel(model: Instance): Creep?
	for _, c in pairs(creeps) do
		if c.model == model then
			return c
		end
	end
	return nil
end

local function burst(position: Vector3, color: Color3, amount: number)
	local p = Instance.new("Part")
	p.Name = "BurstFX"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Position = position
	p.Parent = game:GetService("Workspace")
	local a = Instance.new("Attachment")
	a.Parent = p
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://243660364"
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.Acceleration = Vector3.new(0, -18, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	emitter.Parent = a
	emitter:Emit(amount)
	game:GetService("Debris"):AddItem(p, 1.2)
end

function Enemies.damage(creep: Creep, amount: number, fromPos: Vector3?, element: string?)
	if not creep.alive then
		return
	end
	creep.hp -= amount
	if creep.hpFill then
		(creep.hpFill :: Frame).Size = UDim2.new(math.max(0, creep.hp / creep.maxHp), 0, 1, 0)
	end
	-- hit flash
	local body = creep.body
	local original = body.Color
	body.Color = Color3.fromRGB(255, 255, 255)
	task.delay(0.08, function()
		if body and body.Parent then
			body.Color = original
		end
	end)
	-- knockback
	if fromPos and body.AssemblyLinearVelocity then
		local dir = (body.Position - fromPos)
		dir = Vector3.new(dir.X, 0, 0)
		if dir.Magnitude > 0.01 then
			dir = dir.Unit
			body.AssemblyLinearVelocity = Vector3.new(dir.X * 22, math.max(body.AssemblyLinearVelocity.Y, 4), 0)
		end
	end
	if events then
		events.EnemyHit:FireAllClients(creep.model, amount, element or "physical")
	end
	if creep.hp <= 0 then
		Enemies.kill(creep)
	end
end

function Enemies.kill(creep: Creep)
	if not creep.alive then
		return
	end
	creep.alive = false
	burst(creep.body.Position, creep.def.color, 26)
	if events then
		events.EnemyDied:FireAllClients(creep.model, creep.def.milestone, creep.def.xp)
	end
	if onCreepKilled then
		onCreepKilled(creep.def.milestone, creep.def.xp)
	end
	creep.model:Destroy()
	creeps[creep.id] = nil
end

function Enemies.freezeInRadius(center: Vector3, radius: number, duration: number)
	local now = os.clock()
	Enemies.forEach(function(c)
		local d = (c.body.Position - center).Magnitude
		if d <= radius then
			c.frozenUntil = math.max(c.frozenUntil, now + duration)
			-- visual ice shell
			c.body.Color = Color3.fromRGB(190, 235, 255)
			task.delay(duration, function()
				if c.alive and c.body.Parent then
					c.body.Color = c.def.color
				end
			end)
		end
	end)
end

-- per-frame AI
local function tick(dt: number)
	local now = os.clock()
	-- find "the" player character (single-player first; works for local server too)
	local players = game:GetService("Players"):GetPlayers()
	local player = players[1]
	local character = player and player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	for _, c in pairs(creeps) do
		if not c.alive then
			continue
		end
		local body = c.body
		if body.Parent == nil then
			continue
		end

		-- burn damage over time
		if now < c.burnUntil then
			c.hp -= 6 * dt
			if c.hp <= 0 then
				Enemies.kill(c)
				continue
			end
		end

		local frozen = now < c.frozenUntil
		local vel = body.AssemblyLinearVelocity

		if frozen then
			body.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
			continue
		end

		local def = c.def
		local toPlayer = hrp and (hrp.Position - body.Position) or Vector3.zero
		local distXZ = Vector3.new(toPlayer.X, 0, toPlayer.Z).Magnitude
		local flat = Vector3.new(toPlayer.X, 0, toPlayer.Z)
		local flatMag = flat.Magnitude

		if def.flying then
			-- sine-wave flight, aggro = swoop at the player
			local bobY = math.sin(now * 2.4 + c.id) * 1.4
			local targetY = (hrp and (hrp.Position.Y + 3.2) or c.homeY) + bobY
			if distXZ < 26 and hrp then
				local dir = flatMag > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
				body.AssemblyLinearVelocity = Vector3.new(dir.X * def.speed, (targetY - body.Position.Y) * 3, dir.Z * def.speed)
			else
				body.AssemblyLinearVelocity = Vector3.new(c.patrolDir * def.speed * 0.6, (targetY - body.Position.Y) * 3, 0)
				if math.abs(body.Position.X - c.homeX) > 24 then
					c.patrolDir *= -1
				end
			end
			-- contact damage
			if hrp and distXZ < 3.4 and (now - (c :: any).lastHit or 0) > 1.3 then
				(c :: any).lastHit = now
				if onPlayerDamaged then
					onPlayerDamaged(def.damage, body.Position, def.name)
				end
			end
		elsif def.ranged then
			-- cinderfrog: keep mid distance, spit fireballs
			local wantDist = 11
			local move3 = Vector3.zero
			if hrp and flatMag > 0.01 then
				local f = flat.Unit
				if distXZ > wantDist + 3 then
					move3 = f
				elseif distXZ < wantDist - 3 then
					move3 = -f
				end
			else
				move3 = Vector3.new(c.patrolDir, 0, 0)
				if math.abs(body.Position.X - c.homeX) > 12 then
					c.patrolDir *= -1
				end
			end
			body.AssemblyLinearVelocity = Vector3.new(move3.X * def.speed, vel.Y, move3.Z * def.speed)
			-- fireball
			if hrp and distXZ < 24 and now >= c.attackCooldown then
				c.attackCooldown = now + 2.3
				fireProjectile(body, hrp, def.damage, Color3.fromRGB(255, 140, 50), "Cinderfrog Fireball")
			end
		else
			-- melee creeps
			local move3 = Vector3.new(c.patrolDir, 0, 0)
			if hrp and distXZ < 15 and flatMag > 0.01 then
				move3 = flat.Unit
			else
				if math.abs(body.Position.X - c.homeX) > 14 then
					c.patrolDir *= -1
				end
			end
			body.AssemblyLinearVelocity = Vector3.new(move3.X * def.speed, vel.Y, move3.Z * def.speed)
			if hrp and distXZ < 3.6 and now >= c.attackCooldown then
				c.attackCooldown = now + 1.6
				local dir = flatMag > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
				local hrpVel = Vector3.zero
				if hrp.Parent then
					local bv = hrp:FindFirstChildOfClass("BodyVelocity")
					hrpVel = bv and bv.Velocity or Vector3.zero
				end
				-- knock the player back a bit
				hrp.AssemblyLinearVelocity = Vector3.new(dir.X * 26, 12, dir.Z * 26)
				if onPlayerDamaged then
					onPlayerDamaged(def.damage, body.Position, def.name)
				end
			end
		end
	end
end

function fireProjectile(from: BasePart, target: BasePart, damage: number, color: Color3, name: string)
	local p = Instance.new("Part")
	p.Name = "Projectile_" .. name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.6, 1.6, 1.6)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.CanCollide = false
	p.CanQuery = false
	p.Anchored = false
	p.Massless = true
	p.Parent = game:GetService("Workspace")
	p.CFrame = CFrame.new(from.Position + Vector3.new(0, 1.2, 0))

	local dir = (target.Position + Vector3.new(0, 1, 0) - p.Position)
	if dir.Magnitude < 0.01 then
		p:Destroy()
		return
	end
	dir = dir.Unit
	p.AssemblyLinearVelocity = dir * 55

	-- hit detection: proximity check each frame, lifetime ~3s
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not p or not p.Parent then
			conn:Disconnect()
			return
		end
		if os.clock() - born > 3.5 then
			p:Destroy()
			conn:Disconnect()
			return
		end
		local prim = game:GetService("Players"):GetPlayers()[1]
		local char = prim and prim.Character
		local targetHrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetHrp and (targetHrp.Position - p.Position).Magnitude < 3 then
			if onPlayerDamaged then
				onPlayerDamaged(damage, p.Position, name)
			end
			burst(p.Position, color, 12)
			p:Destroy()
			conn:Disconnect()
		end
	end)
	game:GetService("Debris"):AddItem(p, 4)
end

RunService.Heartbeat:Connect(tick)

return Enemies
