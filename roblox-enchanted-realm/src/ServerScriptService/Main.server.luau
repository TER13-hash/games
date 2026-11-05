--!strict
-- Enchanted Realm: Inkbound — server master script (fixed with error handling).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Regions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Regions"))
local SoundIDs = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SoundIDs"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local Bosses = require(script.Parent:WaitForChild("Bosses"))
local Enemies = require(script.Parent:WaitForChild("Enemies"))
local Session = require(script.Parent:WaitForChild("Session"))
local SaveData = require(script.Parent:WaitForChild("SaveData"))
local LootChests = require(script.Parent:WaitForChild("LootChests"))
local AdminCommands = require(script.Parent:WaitForChild("AdminCommands"))
local Tutorial = require(script.Parent:WaitForChild("Tutorial"))
local Merchant = require(script.Parent:WaitForChild("Merchant"))
local Pages = require(script.Parent:WaitForChild("Pages"))
local Ferry = require(script.Parent:WaitForChild("Ferry"))
local TerrainBuilder = require(script.Parent:WaitForChild("TerrainBuilder"))

-- we spawn characters ourselves (after the session exists) so they never appear at a wrong spot
Players.CharacterAutoLoads = false
local killPlayer: (any) -> ()
local respawnPlayer: (any) -> ()
local bossCenter: (string) -> Vector3

-- ————————————————————— remotes ——————————————————————
local remotes = Instance.new("Folder")
remotes.Name = "InkboundRemotes"
remotes.Parent = ReplicatedStorage

local function newEvent(name: string): RemoteEvent
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = remotes
	return e
end

local RE = {
	swing = newEvent("AttackSwing"),
	cast = newEvent("CastAbility"),
	interact = newEvent("Interact"),
	checkpoint = newEvent("CheckpointTouch"),
	portal = newEvent("PortalTouch"),
	respawn = newEvent("RespawnRequest"),
	win = newEvent("GameWon"),
	playSound = newEvent("PlaySound"),
	vfx = newEvent("VFX"),
	sync = newEvent("StateSync"),
	bossHealth = newEvent("BossHealth"),
	BossIntro = newEvent("BossIntro"),
	BossRoar = newEvent("BossRoar"),
	BossAttack = newEvent("BossAttack"),
	BossDefeated = newEvent("BossDefeated"),
	EnemyHit = newEvent("EnemyHit"),
	EnemyDied = newEvent("EnemyDied"),
	BurnPlayer = newEvent("BurnPlayer"),
	Rooted = newEvent("Rooted"),
	BlindPlayer = newEvent("BlindPlayer"),
	ZoneEnter = newEvent("ZoneEnter"),
	dialogue = newEvent("Dialogue"),
	narrator = newEvent("Narrator"),
	buy = newEvent("BuyItem"),
	awaken = newEvent("Awaken"),
	syncTime = newEvent("SyncTime"),
}

local objectiveText = Instance.new("StringValue")
objectiveText.Name = "ObjectiveText"
objectiveText.Value = Config.OBJECTIVES.start
objectiveText.Parent = remotes

-- ————————————————————— time of day (syncs to the player's clock) ——————————————————————
-- The client reports its local wall-clock hour; the server restyles the
-- whole world to match — dawn, day, dusk or deep night like the player's PC.
local function applyTimeOfDay(hourFloat: number)
	local L = game:GetService("Lighting")
	L.ClockTime = hourFloat
	-- rough "day-ness" curve: peaks at noon, zero at midnight
	local day = math.max(0, math.sin((hourFloat - 6) * math.pi / 12))
	L.Brightness = 0.35 + 2.1 * day
	L.Ambient = Color3.fromRGB(
		math.floor(26 + 60 * day),
		math.floor(30 + 55 * day),
		math.floor(44 + 48 * day)
	)
	L.OutdoorAmbient = Color3.fromRGB(
		math.floor(40 + 95 * day),
		math.floor(46 + 86 * day),
		math.floor(58 + 74 * day)
	)
	L.FogEnd = if day < 0.15 then 350 else 1200
end

local function timeWord(hour: number): string
	if hour >= 5 and hour < 7 then return "dawn"
	elseif hour >= 7 and hour < 11 then return "morning"
	elseif hour >= 11 and hour < 14 then return "midday"
	elseif hour >= 14 and hour < 17 then return "afternoon"
	elseif hour >= 17 and hour < 19 then return "dusk"
	elseif hour >= 19 and hour < 23 then return "night"
	else
		return "deep night"
	end
end

local timeSynced = false

RE.syncTime.OnServerEvent:Connect(function(player, hourFloat)
	if typeof(hourFloat) ~= "number" then
		return
	end
	if hourFloat ~= hourFloat or math.abs(hourFloat) == math.huge then
		return
	end
	hourFloat = hourFloat % 24
	local firstSync = not timeSynced
	timeSynced = true
	applyTimeOfDay(hourFloat)
	if firstSync then
		local word = timeWord(hourFloat)
		RE.dialogue:FireClient(player, "time", "Mish: The realm keeps your hour — it is " .. word .. " where you stand.")
	end
end)

-- push current session payload to the client HUD
local function pushSync(playerObj: Player)
	local s = Session.get(playerObj)
	if s then
		RE.sync:FireClient(playerObj, Session.syncPayload(s))
	end
end

-- ————————————————————— world ——————————————————————
-- voxel terrain base first so the world parts don't float over empty space
local terrainOk, terrainErr = pcall(function()
	TerrainBuilder.build()
end)
if not terrainOk then
	warn("[Inkbound] TerrainBuilder failed:", terrainErr)
end

local world: any = nil
local ok, err = pcall(function()
	world = WorldBuilder.build("EnchantedRealm")
end)
if not ok then
	warn("[Inkbound] WorldBuilder failed:", err)
	-- create a fallback so nothing else errors
	world = { marker = Instance.new("Folder"), barriers = {}, hazards = {}, portals = {}, finalePortal = Instance.new("Part"), machineConsole = Instance.new("Part"), machinePiston = Instance.new("Part"), machineCore = Instance.new("Part") }
	world.marker.Name = "EnchantedRealm"
	world.marker.Parent = game:GetService("Workspace")
	world.finalePortal.Name = "FinalePortal"
	world.machineConsole.Name = "machineConsole"
	world.machinePiston.Name = "machinePiston"
	world.machineCore.Name = "machineCore"
else
	world.marker.Parent = game:GetService("Workspace")
end

local lanternFolder = world.marker:FindFirstChild("Lanterns")

-- lantern glow loop
if lanternFolder then
	for _, lantern in ipairs(lanternFolder:GetChildren()) do
		if lantern:IsA("Model") then
			local flame = lantern:FindFirstChild("Flame") :: BasePart?
			if flame then
				task.spawn(function()
					while lantern.Parent do
						local light = flame:FindFirstChildOfClass("PointLight") :: PointLight?
						if light then
							light.Brightness = 2 + 0.4 * math.sin(tick() * 3)
						end
						task.wait(0.05)
					end
				end)
			end
		end
	end
end

Bosses.init(RE, function(damage, fromPos, sourceName)
	local p = Players:GetPlayers()[1]
	local s = p and Session.get(p)
	if not s then
		return
	end
	if tick() < s.invulnerableUntil then
		return
	end
	Session.applyDamage(s, damage)
	s.invulnerableUntil = tick() + Config.PLAYER.invulnerabilityTime
	RE.playSound:FireAllClients("PlayerHurt", p.Character and p.Character.PrimaryPart and p.Character.PrimaryPart.Position or Vector3.zero, 1)
	RE.vfx:FireAllClients("hurtFlash")
	pushSync(s.player)
	if s.hp <= 0 then
		killPlayer(s)
	end
end, function(kind)
	local p = Players:GetPlayers()[1]
	local s = p and Session.get(p)
	if not s then
		return
	end
	local bossDef = Config.BOSSES[kind]
	Session.addXp(s, bossDef.xp)
	Session.markBossDefeated(s, kind)
	local reward = {
		mechanical = { abl = "lightning", echo = "kidlatEcho" },
		machine = { abl = "powerRock", echo = "piyedroEcho" },
		fire = { abl = "fire", echo = "peyroEcho" },
		ice = { abl = "ice", echo = "danEcho" },
		storm = { abl = "wind", echo = "jyrEcho" },
		squid = { abl = "lightningCore", echo = "nukosEcho" },
	}[kind]
	if reward then
		Session.grantAbility(s, reward.abl)
		Session.grantEcho(s, reward.echo)
	end
	if kind == "squid" then
		s.save.grandKey = true
		world.finalePortal.Transparency = 0
		RE.playSound:FireAllClients("KeyClaimed", world.finalePortal.Position, 1)
	end
	pushSync(s.player)
	RE.playSound:FireAllClients("BossDefeat", bossCenter(kind), 1)
	RE.vfx:FireAllClients("bossBurst", bossCenter(kind))
	objectiveText.Value = Config.OBJECTIVES.done
end)

function bossCenter(kind: string): Vector3
	for _, b in ipairs(Bosses.allBosses()) do
		if b.kind == kind then
			return b.bodyParts[1] and b.bodyParts[1].Position or Vector3.new(b.x, b.y + 5, 0)
		end
	end
	return Vector3.new(0, 5, 0)
end

local bossListRef: { any } = (Bosses :: any)

-- ————————————————————— audio helper ——————————————————————
local playedSounds: { [string]: boolean } = {}
local function playSfx(key: string, position: Vector3, volume: number?)
	local id = SoundIDs.find("sfx", key)
	if not id then
		return
	end
	if playedSounds[key] then
		return
	end
	playedSounds[key] = true
	task.delay(0.2, function()
		playedSounds[key] = false
	end)
	RE.playSound:FireAllClients(key, position, volume or 0.8)
end

-- ————————————————————— player damage / death ——————————————————————
local function hurtPlayer(s: Session.State, amount: number, source: string?)
	if s.hp <= 0 then
		return
	end
	if tick() < s.invulnerableUntil and source ~= "pit" then
		return
	end
	Session.applyDamage(s, amount)
	s.invulnerableUntil = tick() + Config.PLAYER.invulnerabilityTime
	local char = s.player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	RE.playSound:FireAllClients("PlayerHurt", hrp and hrp.Position or Vector3.zero, 1)
	RE.vfx:FireAllClients("hurtFlash")
	pushSync(s.player)
	if s.hp <= 0 then
		killPlayer(s)
	end
end

function killPlayer(s: Session.State)
	s.burnUntil = 0
	s.deaths += 1
	s.dirty = true
	RE.playSound:FireAllClients("GameOver", s.checkpointPos, 0.9)
	RE.vfx:FireAllClients("deathFade")
	Bosses.resetAll()
	task.delay(1.8, function()
		if not s.player or not s.player.Parent then
			return
		end
		respawnPlayer(s)
	end)
end

function respawnPlayer(s: Session.State)
	Session.recalcHp(s, true)
	s.ink = math.min(Session.maxInk(s), s.ink + Config.INK.startInk)
	Bosses.resetAll()
	local char = s.player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.CFrame = CFrame.new(s.checkpointPos + Vector3.new(0, 4, 0))
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
	end
	RE.respawn:FireClient(s.player)
	RE.playSound:FireAllClients("Checkpoint", s.checkpointPos, 0.9)
	pushSync(s.player)
end

-- ————————————————————— character setup ——————————————————————
local function setupCharacter(player: Player, char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.WalkSpeed = Config.PLAYER.baseSpeed
	hum.UseJumpPower = true
	hum.JumpPower = Config.PLAYER.jumpPower
	local sess = Session.get(player)
	if sess then
		hrp.CFrame = CFrame.new(sess.checkpointPos + Vector3.new(0, 4, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if not char.Parent then
			conn:Disconnect()
			return
		end
		local pos = hrp.Position
		if math.abs(pos.Z) > 0.5 then
			hrp.CFrame = CFrame.new(pos.X, pos.Y, 0)
		end
		local vel = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(vel.X, vel.Y, 0)
		if pos.Y < Config.WORLD.killY then
			local s = Session.get(player)
			if s then
				hurtPlayer(s, 9999, "pit")
			end
		end
	end)
	char:SetAttribute("ZLockConn", tostring(conn))
end

local function onPlayerAdded(player: Player)
	local s = Session.fresh(player)
	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
	player:LoadCharacter()
	task.delay(3, function() -- let the client scripts load first
		if not player.Parent then
			return
		end
		pushSync(player)
		Tutorial.onPlayer(RE, player)
		RE.dialogue:FireClient(player, "mish_intro", "Mish: You're awake... you're in Encantadia now. The only way home is the Grand Key — held by Nukos, deep below.")
		RE.narrator:FireClient(player, "Enchanted Realm: Inkbound", 4)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

-- ————————————————————— abilities / barriers ——————————————————————
local ABILITY_CAST_LOCK: { [number]: number } = {}

local function inkCost(s: Session.State, abilityId: string): number
	return Config.INK.costs[abilityId] or 0
end

local function hasInk(s: Session.State, abilityId: string): boolean
	return s.ink >= inkCost(s, abilityId)
end

local function spendInk(s: Session.State, abilityId: string)
	s.ink = math.max(0, s.ink - inkCost(s, abilityId))
	s.dirty = true
end

local function nearestBarrier(btype: string, pos: Vector3, radius: number): BasePart?
	local best: BasePart? = nil
	local bestD = radius
	for _, b in ipairs(world.barriers) do
		if b:GetAttribute("BarrierType") == btype then
			local d = (b.Position - pos).Magnitude
			if d < bestD then
				bestD = d
				best = b
			end
		end
	end
	return best
end

local function breakBarrier(s: Session.State, barrier: BasePart)
	local btype = barrier:GetAttribute("BarrierType")
	if s.save.barriersBroken and s.save.barriersBroken[btype] then
		return
	end
	RE.playSound:FireAllClients("BarrierBreak", barrier.Position, 0.9)
	RE.vfx:FireAllClients("breakBarrier", barrier.Position)
	barrier.Transparency = 1
	barrier.CanCollide = false
	barrier.CanTouch = false
	local outline = barrier:FindFirstChild("InkOutline")
	if outline then
		outline:Destroy()
	end
	for _, d in ipairs(barrier:GetChildren()) do
		if d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	if btype == "machineSeal" then
		if s.save.machineAwake and Session.hasAbility(s, "lightningCore") then
			Session.markBarrierBroken(s, btype)
		end
	else
		Session.markBarrierBroken(s, btype)
	end
	if btype == "electric" then
		objectiveText.Value = Config.OBJECTIVES.openElectric
	end
end

for _, barrier in ipairs(world.barriers) do
	barrier.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		local s = Session.get(player)
		if not s then
			return
		end
		local btype = barrier:GetAttribute("BarrierType")
		local need = (Config.BARRIERS :: any)[btype] and (Config.BARRIERS :: any)[btype].need or nil
		if not need then
			return
		end
		if not Session.hasAbility(s, need) then
			if tick() > s.barrierHintCooldown then
				s.barrierHintCooldown = tick() + 4
				RE.playSound:FireAllClients("MachineDenied", barrier.Position, 0.5)
				RE.vfx:FireAllClients("deniedHint", barrier.Position, (Config.BARRIERS :: any)[btype].prompt)
			end
			return
		end
		if tick() > s.barrierPromptCooldown then
			s.barrierPromptCooldown = tick() + 0.8
			breakBarrier(s, barrier)
		end
	end)
end

RE.cast.OnServerEvent:Connect(function(player, abilityId: string, aim: Vector3)
	if typeof(abilityId) ~= "string" then
		return
	end
	local s = Session.get(player)
	if not s then
		return
	end
	if typeof(aim) ~= "Vector3" then
		return
	end
	if not Session.hasAbility(s, abilityId) then
		return
	end
	-- "Over-Inked": cast at a full meter — free, twice as strong, burns the meter
	local overInked = s.ink >= Session.maxInk(s)
	if not overInked and not hasInk(s, abilityId) then
		RE.playSound:FireAllClients("MachineDenied", player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position or Vector3.zero, 0.5)
		return
	end
	local now = tick()
	if (ABILITY_CAST_LOCK[player.UserId] or 0) > now then
		return
	end
	ABILITY_CAST_LOCK[player.UserId] = now + 0.45

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local origin = hrp.Position
	local dir = Vector3.new(aim.X - origin.X, 0, aim.Z - origin.Z)
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(1, 0, 0)
	end
	dir = dir.Unit
	-- multipliers: over-inked surge × mage job bonus × awakening × elemental styles
	local mageMul = 1 + 0.1 * Session.jobRank(s, "mage")
	local awakenMul = if tick() < (s.awakenUntil or 0) then Config.AWAKEN.damageMul else 1
	local flameMul = 1 + 0.25 * (((s.save.roles or {}).flame) or 0)
	local frostMul = 1 + 0.25 * (((s.save.roles or {}).frost) or 0)
	local stormMul = 1 + 0.25 * (((s.save.roles or {}).storm) or 0)
	local damageMul = (if overInked then 2 else 1) * mageMul * awakenMul
	local radiusMul = if overInked then 1.35 else 1
	local dmg = Session.baseDamage(s) * damageMul
	if overInked then
		s.ink = 0
		s.dirty = true
		RE.narrator:FireClient(player, "OVER-INKED — power unbound!", 2.5)
		RE.vfx:FireAllClients("bossBurst", origin, Color3.fromRGB(255, 230, 140))
	else
		spendInk(s, abilityId)
	end
	pushSync(s.player)
	RE.playSound:FireAllClients(abilityId == "lightning" and "LightningCast"
		or abilityId == "fire" and "FireCast"
		or abilityId == "ice" and "IceCast"
		or abilityId == "wind" and "WindCast"
		or abilityId == "powerRock" and "RockShatter"
		or abilityId == "shockwave" and "RockShatter"
		or "LightningCast", origin, 0.8)
	RE.vfx:FireAllClients("cast", abilityId, origin, dir)

	if abilityId == "lightning" or abilityId == "lightningCore" then
		local b = nearestBarrier("electric", origin, 14)
		local console = world.machineConsole
		local hitConsole = console and (origin - console.Position).Magnitude < 14
		if b then
			breakBarrier(s, b)
		end
		if hitConsole then
			if Session.hasAbility(s, "lightningCore") then
				s.save.machineAwake = true
				s.dirty = true
				world.machineCore.Color = Color3.fromRGB(255, 255, 255)
				local light = world.machineCore:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = 3
				end
				world.machinePiston.CFrame = CFrame.new(world.machinePiston.Position.X, 20, 0)
				RE.playSound:FireAllClients("MachineWake", world.machinePiston.Position, 1)
				objectiveText.Value = Config.OBJECTIVES.wakeMachine
				local seal = nearestBarrier("machineSeal", origin, 40)
				if seal then
					breakBarrier(s, seal)
				end
			else
				RE.playSound:FireAllClients("MachineDenied", origin, 0.5)
			end
		end

	elseif abilityId == "fire" then
		local coneDir = dir
		Enemies.forEach(function(c)
			local d = (c.body.Position - origin).Magnitude
			if d < 12 * radiusMul then
				local to = c.body.Position - origin
				local flat = Vector3.new(to.X, 0, to.Z)
				if flat.Magnitude > 0 and flat:Dot(coneDir) > 0.5 * flat.Magnitude then
					Enemies.damage(c, dmg * flameMul, origin, "fire")
				end
			end
		end)
		Bosses.damageInRange(origin, 13 * radiusMul, dmg * flameMul, "fire")
		for _, b in ipairs(world.barriers) do
			local bt = b:GetAttribute("BarrierType")
			if (bt == "vine" or bt == "wood") and (origin - b.Position).Magnitude < 13 then
				breakBarrier(s, b)
			end
		end
		RE.vfx:FireAllClients("fireBreath", origin, dir)

	elseif abilityId == "ice" then
		Enemies.freezeInRadius(origin, 11 * radiusMul, 3.5)
		Bosses.damageInRange(origin, 11 * radiusMul, dmg * frostMul, "ice")
		local plat = Instance.new("Part")
		plat.Name = "IcePlatform"
		plat.Anchored = true
		plat.CanCollide = true
		plat.Material = Enum.Material.Ice
		plat.Color = Color3.fromRGB(190, 235, 255)
		plat.Transparency = 0.15
		plat.Size = Vector3.new(7, 0.6, 8)
		plat.CFrame = CFrame.new(origin.X, origin.Y - 0.4, 0)
		plat.Parent = game:GetService("Workspace")
		local outline = Instance.new("Part")
		outline.Name = "InkOutline"
		outline.Anchored = true
		outline.CanCollide = false
		outline.CanQuery = false
		outline.CanTouch = false
		outline.Color = Color3.fromRGB(8, 8, 10)
		outline.Material = Enum.Material.SmoothPlastic
		outline.Size = plat.Size + Vector3.new(0.08, 0.08, 0.08)
		outline.CFrame = plat.CFrame
		outline.Parent = plat
		Debris:AddItem(plat, 7)
		local b = nearestBarrier("waterfall", origin, 14)
		if b then
			breakBarrier(s, b)
		end
		for _, bb in ipairs(world.barriers) do
			if bb:GetAttribute("BarrierType") == "frozen" and (origin - bb.Position).Magnitude < 14 then
				breakBarrier(s, bb)
			end
		end

	elseif abilityId == "wind" then
		hrp.AssemblyLinearVelocity = Vector3.new(dir.X * 52, 28, dir.Z * 52)
		local glide = Instance.new("BoolValue")
		glide.Name = "WindGlide"
		glide.Value = true
		glide.Parent = hrp
		Debris:AddItem(glide, 2.2)

	elseif abilityId == "powerRock" then
		Bosses.damageInRange(origin, 14 * radiusMul, dmg * 2, "rock")
		Enemies.forEach(function(c)
			if (c.body.Position - origin).Magnitude < 14 * radiusMul then
				Enemies.damage(c, dmg * 2, origin, "rock")
			end
		end)
		for _, b in ipairs(world.barriers) do
			local bt = b:GetAttribute("BarrierType")
			if (bt == "stone" or bt == "rock") and (origin - b.Position).Magnitude < 14 then
				breakBarrier(s, b)
			end
		end
		local a = Instance.new("Attachment")
		a.Parent = hrp
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxassetid://243660364"
		emitter.Color = ColorSequence.new(Color3.fromRGB(170, 150, 120))
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.4, 0.8)
		emitter.Speed = NumberRange.new(12, 22)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		emitter.Parent = a
		emitter:Emit(40)
		Debris:AddItem(a, 1)

	elseif abilityId == "shockwave" then
		-- nova: damage every enemy/boss around you, small hop for flavor
		local radius = 16 * radiusMul
		Enemies.forEach(function(c)
			if (c.body.Position - origin).Magnitude < radius then
				Enemies.damage(c, dmg * 1.5 * stormMul, origin, "physical")
			end
		end)
		Bosses.damageInRange(origin, radius, dmg * 1.5 * stormMul, "physical")
		hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 26, hrp.AssemblyLinearVelocity.Z)
		RE.vfx:FireAllClients("bossBurst", origin, Color3.fromRGB(150, 215, 255))
	end
end)

RE.swing.OnServerEvent:Connect(function(player, dirVec: Vector3)
	local s = Session.get(player)
	if not s then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local dir = if typeof(dirVec) == "Vector3" and Vector3.new(dirVec.X, 0, dirVec.Z).Magnitude > 0.01
		then Vector3.new(dirVec.X, 0, dirVec.Z).Unit
		else Vector3.new(1, 0, 0)
	local origin = hrp.Position + dir * 3 + Vector3.new(0, 1.6, 0)
	local meleeMul = (1 + 0.1 * Session.jobRank(s, "warrior")) * (if tick() < (s.awakenUntil or 0) then Config.AWAKEN.damageMul else 1)
	local meleeDmg = Session.baseDamage(s) * meleeMul
	local hitAny = false
	Enemies.forEach(function(c)
		local to = c.body.Position - origin
		local flat = Vector3.new(to.X, 0, to.Z)
		if flat.Magnitude < Config.PLAYER.attackRange and flat.Magnitude > 0.01 and flat.Unit:Dot(dir) > 0.35 then
			Enemies.damage(c, meleeDmg, origin, "physical")
			hitAny = true
		end
	end)
	Bosses.damageInRange(origin, Config.PLAYER.attackRange + 2, meleeDmg, "physical")
	if hitAny then
		s.ink = math.min(Session.maxInk(s), s.ink + Config.INK.meterGainPerHit)
		local healRank = Session.jobRank(s, "healer")
		if healRank > 0 then
			s.hp = math.min(Session.maxHp(s), s.hp + 3 * healRank)
		end
		s.dirty = true
	end
	RE.playSound:FireAllClients(hitAny and "SwordHit" or "SwordSlash", origin, 0.7)
	RE.vfx:FireAllClients("swing", origin, dir, hitAny)
	pushSync(s.player)
end)

RE.interact.OnServerEvent:Connect(function(player, targetName: string)
	if typeof(targetName) ~= "string" then
		return
	end
	local s = Session.get(player)
	if not s then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	if lanternFolder then
		for _, lantern in ipairs(lanternFolder:GetChildren()) do
			if lantern.Name == targetName and (hrp.Position - lantern.PrimaryPart.Position).Magnitude < 11 then
				local cpId = lantern:GetAttribute("CheckpointId")
				local x = lantern:GetAttribute("CheckpointX")
				local baseY = 0
				for _, island in ipairs(Regions.byId.sky.grounds) do
					if x >= island.x0 and x <= island.x1 then
						baseY = island.topY
					end
				end
				Session.setCheckpoint(s, cpId, Vector3.new(x, baseY + 2, 0))
				pushSync(s.player)
				RE.playSound:FireAllClients("Checkpoint", lantern.PrimaryPart.Position, 1)
				RE.vfx:FireAllClients("lanternLit", lantern.PrimaryPart.Position)
				return
			end
		end
	end
	for _, pad in ipairs(world.portals) do
		if pad.Name == targetName and (hrp.Position - pad.Position).Magnitude < 9 then
			local pid = pad:GetAttribute("PortalId")
			local side = pad:GetAttribute("PortalSide")
			for _, other in ipairs(world.portals) do
				if other:GetAttribute("PortalId") == pid and other:GetAttribute("PortalSide") ~= side then
					hrp.CFrame = CFrame.new(other.Position + Vector3.new(0, 3, 0))
					hrp.AssemblyLinearVelocity = Vector3.zero
					RE.playSound:FireAllClients("PortalHum", other.Position, 0.8)
					return
				end
			end
		end
	end
	if targetName == "FinalePortal" and (hrp.Position - world.finalePortal.Position).Magnitude < 10 then
		if s.save.grandKey then
			RE.win:FireClient(player)
			RE.playSound:FireAllClients("Victory", world.finalePortal.Position, 1)
			s.save.portalUnlocked = true
			s.dirty = true
			objectiveText.Value = Config.OBJECTIVES.escape
		else
			RE.playSound:FireAllClients("MachineDenied", world.finalePortal.Position, 0.5)
		end
	end
end)

local function hazardTouch(part: BasePart)
	part.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		local s = Session.get(player)
		if not s then
			return
		end
		local hz = part:GetAttribute("Hazard")
		local dmg = part:GetAttribute("Damage") or 8
		local now = tick()
		local cdKey = "hazard_" .. part:GetFullName()
		if (s.hazardCooldowns[cdKey] or 0) > now then
			return
		end
		s.hazardCooldowns[cdKey] = now + 0.7
		if hz == "fire" then
			s.burnUntil = now + 4
			s.burnAccum = 0
			RE.playSound:FireAllClients("FireCast", part.Position, 0.5)
			RE.vfx:FireAllClients("burn", part.Position)
		end
		hurtPlayer(s, dmg, hz)
	end)
end
for _, h in ipairs(world.hazards) do
	hazardTouch(h)
end
local realmFolder = game:GetService("Workspace"):FindFirstChild("EnchantedRealm")
local puddle = (realmFolder and realmFolder:FindFirstChild("WaterPuddle")) :: BasePart?
if puddle then
	puddle.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			local s = Session.get(player)
			if s then
				s.burnUntil = 0
				RE.playSound:FireAllClients("WaterFreeze", puddle.Position, 0.5)
			end
		end
	end)
end

-- burn tick
task.spawn(function()
	while true do
		task.wait(0.25)
		local now = tick()
		for _, s in ipairs(Session.all()) do
			if now < s.burnUntil then
				s.burnAccum = (s.burnAccum or 0) + 0.25
				if s.burnAccum >= 0.5 then
					s.burnAccum = 0
					hurtPlayer(s, 4, "burn")
				end
			end
		end
	end
end)

-- skills/shop purchases (the in-game SKILLS panel sends these)
RE.buy.OnServerEvent:Connect(function(player, itemId: string)
	if typeof(itemId) ~= "string" then
		return
	end
	local s = Session.get(player)
	if not s then
		return
	end
	local xp = math.floor(s.save.xp or 0)
	local level = s.save.level or 1
	local hearts = math.floor((s.save.maxHpBonus or 0) / Config.PLAYER.heartBonus)
	local satchels = math.floor((s.save.maxInkBonus or 0) / 25)

	local function ack(msg: string)
		RE.narrator:FireClient(player, msg, 3)
		RE.sync:FireClient(player, Session.syncPayload(s))
	end

	if itemId == "shockwave" then
		if Session.hasAbility(s, "shockwave") then
			ack("You already know Shockwave.")
			return
		end
		if xp < 200 then
			ack("The tome costs 200 XP. (you have " .. xp .. ")")
			return
		end
		s.save.xp -= 200
		s.dirty = true
		Session.grantAbility(s, "shockwave")
		RE.vfx:FireAllClients("cast", "shockwave", player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position or Vector3.zero, Vector3.new(1, 0, 0))
		ack("Tome of Shockwave — press [7]!")

	elseif itemId == "satchel" then
		if satchels >= 3 then
			ack("Your satchel is full (3/3).")
			return
		end
		if xp < 150 then
			ack("Ink Satchel costs 150 XP. (you have " .. xp .. ")")
			return
		end
		s.save.xp -= 150
		s.dirty = true
		Session.grantSatchel(s)
		ack("Ink Satchel — +25 max ink. (" .. (satchels + 1) .. "/3)")

	elseif itemId == "heart" then
		if hearts >= 3 then
			ack("Your heart can hold no more (3/3).")
			return
		end
		if xp < 150 then
			ack("Heart Container costs 150 XP. (you have " .. xp .. ")")
			return
		end
		s.save.xp -= 150
		s.dirty = true
		Session.grantHeart(s)
		ack("Heart Container — +20 max HP. (" .. (hearts + 1) .. "/3)")

	elseif itemId == "potion" then
		if xp < 10 then
			ack("Ink Potion costs 10 XP. (you have " .. xp .. ")")
			return
		end
		s.save.xp -= 10
		s.ink = Session.maxInk(s)
		s.dirty = true
		ack("Ink Potion — your meter is full.")

	elseif itemId == "style_flame" or itemId == "style_storm" or itemId == "style_frost" then
		local key = string.sub(itemId, 7)
		local def = (Config.STYLES :: any)[key]
		s.save.roles = s.save.roles or {}
		local rank = s.save.roles[key] or 0
		if rank >= 3 then
			ack(def.name .. " is already mastered.")
			return
		end
		if xp < 150 then
			ack(def.name .. " costs 150 XP per rank. (you have " .. xp .. ")")
			return
		end
		s.save.xp -= 150
		s.save.roles[key] = rank + 1
		s.dirty = true
		ack(def.name .. " — Rank " .. (rank + 1) .. "/3")

	elseif itemId == "job_warrior" or itemId == "job_mage" or itemId == "job_healer" then
		local key = string.sub(itemId, 5)
		local def = (Config.JOBS :: any)[key]
		s.save.jobs = s.save.jobs or {}
		local rank = s.save.jobs[key] or 0
		if rank >= 3 then
			ack(def.name .. " is already mastered.")
			return
		end
		if xp < 150 then
			ack(def.name .. " costs 150 XP per rank. (you have " .. xp .. ")")
			return
		end
		s.save.xp -= 150
		s.save.jobs[key] = rank + 1
		s.dirty = true
		Session.recalcHp(s, true) -- warrior heart bonus applies immediately
		ack(def.name .. " — Rank " .. (rank + 1) .. "/3")
	end
end)

-- anime Ink Awakening — burns the full meter for 6s of raw fury (Q)
RE.awaken.OnServerEvent:Connect(function(player)
	local s = Session.get(player)
	if not s then
		return
	end
	local maxInk = Session.maxInk(s)
	if s.ink < maxInk then
		RE.narrator:FireClient(player, "Ink Awakening needs a full meter.", 3)
		return
	end
	s.ink = 0
	s.awakenUntil = tick() + Config.AWAKEN.duration
	s.dirty = true
	local char = player.Character
	local hrp2 = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum2 = char and char:FindFirstChildOfClass("Humanoid")
	if hum2 then
		hum2.WalkSpeed = Config.PLAYER.baseSpeed + Config.AWAKEN.walkSpeedBonus
		task.delay(Config.AWAKEN.duration, function()
			if hum2 and hum2.Parent then
				hum2.WalkSpeed = Config.PLAYER.baseSpeed
			end
		end)
	end
	RE.narrator:FireClient(player, "INK AWAKENING!!", 3)
	RE.vfx:FireAllClients("bossBurst", hrp2 and hrp2.Position or Vector3.new(s.checkpointPos.X, 2, 0), Color3.fromRGB(255, 215, 120))
	RE.playSound:FireAllClients("AbilityUnlock", hrp2 and hrp2.Position or Vector3.new(s.checkpointPos.X, 2, 0), 1)
	pushSync(s.player)
end)

RE.respawn.OnServerEvent:Connect(function(player)
	local s = Session.get(player)
	if s and s.hp <= 0 then
		respawnPlayer(s)
	end
end)

-- save loop
task.spawn(function()
	while true do
		task.wait(30)
		Session.flushAll()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local s = Session.get(player)
	if s then
		Session.flush(s)
	end
	Session.remove(player)
end)

game:BindToClose(function()
	Session.flushAll()
end)

-- zone notifications
local lastRegionId: string? = nil
task.spawn(function()
	while true do
		task.wait(0.5)
		local p = Players:GetPlayers()[1]
		local s = p and Session.get(p)
		if not s or not p.Character then
			continue
		end
		local hrp = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end
		local r = Regions.regionAt(hrp.Position.X)
		if r.id ~= lastRegionId then
			lastRegionId = r.id
			RE.ZoneEnter:FireClient(p, r.id, r.name)
			local zoneObj = {
				forest = Config.OBJECTIVES.start,
				ruins = Config.OBJECTIVES.openElectric,
				burning = Config.OBJECTIVES.burning,
				frozen = Config.OBJECTIVES.openFrozen,
				cave = Config.OBJECTIVES.openWaterfall,
				sky = Config.OBJECTIVES.stormBoss,
				underground = Config.OBJECTIVES.underground,
			}[r.id]
			if zoneObj then
				objectiveText.Value = zoneObj
			end
		end
	end
end)

LootChests.init(RE)
AdminCommands.init(RE)
Merchant.init(RE)
Pages.init(RE)
Ferry.init()

Enemies.setCallbacks(RE, hurtPlayer)
Enemies.spawnAllFromRegions()

objectiveText.Value = Config.OBJECTIVES.start
print("[Inkbound] Enchanted Realm server ready")
