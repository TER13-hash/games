-- HOLLOW HOUSE: story-based horror (co-op friendly)
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AMBIENCE_ID = "" -- optional: put "rbxassetid://YOUR_ID" for creepy background audio
local WALL_H = 14
local WALL_COLOR = Color3.fromRGB(55, 45, 40)

local CHAPTERS = {
	[1] = "Chapter 1: Arrival",
	[2] = "Chapter 2: The Whispers",
	[3] = "Chapter 3: The Cellar Door",
	[4] = "Chapter 4: The Wraith",
	[5] = "Chapter 5: Escape",
}

local PAGES = {
	{ pos = Vector3.new(-30, 3, -25), text = "Day 1\n\nWe moved into Hollow House today. Emma says the walls whisper at night. I told her it is only the wind." },
	{ pos = Vector3.new(30, 3, -25), text = "Day 9\n\nEmma has stopped sleeping. She talks to someone beneath the floor. We have no cellar." },
	{ pos = Vector3.new(30, 3, 25), text = "Day 14\n\nI found the cellar door behind the hall mirror. I should never have opened it." },
	{ pos = Vector3.new(-30, 3, 25), text = "Day 15\n\nIt wears Emma's face now. If you are reading this, do not look back. The front door will open for you. RUN." },
}

local state = { chapter = 0, started = false, introDone = false, ending = false }

------------------------------------------------------------
-- WORLD SETUP
------------------------------------------------------------
Lighting.ClockTime = 0
Lighting.Brightness = 0
Lighting.Ambient = Color3.fromRGB(6, 6, 10)
Lighting.OutdoorAmbient = Color3.fromRGB(6, 6, 10)
Lighting.FogColor = Color3.new(0, 0, 0)
Lighting.FogEnd = 150
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0

local base = Workspace:FindFirstChild("Baseplate")
if base then base:Destroy() end
local oldSpawn = Workspace:FindFirstChild("SpawnLocation")
if oldSpawn then oldSpawn:Destroy() end

local world = Instance.new("Folder")
world.Name = "HollowHouse"
world.Parent = Workspace

if AMBIENCE_ID ~= "" then
	local s = Instance.new("Sound")
	s.SoundId = AMBIENCE_ID
	s.Looped = true
	s.Volume = 0.5
	s.Parent = Workspace
	s:Play()
end

local function makePart(size, pos, color, name)
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = world
	return p
end

-- axis "Z": wall runs along Z at x = fixed | axis "X": runs along X at z = fixed
local function wallLine(axis, fixed, from, to, gaps)
	gaps = gaps or {}
	table.sort(gaps)
	local function seg(a, b)
		if b - a < 0.1 then return end
		local mid, len = (a + b) / 2, b - a
		if axis == "Z" then
			makePart(Vector3.new(1, WALL_H, len), Vector3.new(fixed, WALL_H / 2, mid), WALL_COLOR, "Wall")
		else
			makePart(Vector3.new(len, WALL_H, 1), Vector3.new(mid, WALL_H / 2, fixed), WALL_COLOR, "Wall")
		end
	end
	local cursor = from
	for _, g in ipairs(gaps) do
		seg(cursor, g - 4)
		cursor = g + 4
	end
	seg(cursor, to)
end

local floor = makePart(Vector3.new(100, 1, 100), Vector3.new(0, -0.5, 0), Color3.fromRGB(70, 50, 35), "Floor")
floor.Material = Enum.Material.Wood
makePart(Vector3.new(100, 1, 100), Vector3.new(0, WALL_H + 0.5, 0), Color3.fromRGB(30, 25, 22), "Ceiling")
local yard = makePart(Vector3.new(24, 1, 24), Vector3.new(0, -0.5, 62), Color3.fromRGB(25, 45, 25), "Yard")
yard.Material = Enum.Material.Grass

-- outer walls (front door gap at x = 0 on the south wall)
wallLine("Z", -50, -50, 50)
wallLine("Z", 50, -50, 50)
wallLine("X", -50, -50, 50)
wallLine("X", 50, -50, 50, { 0 })
-- interior: hall in the middle, 4 rooms on the sides
wallLine("Z", -10, -50, 50, { -25, 25 })
wallLine("Z", 10, -50, 50, { -25, 25 })
wallLine("X", 0, -50, -10)
wallLine("X", 0, 10, 50)

-- front door
local door = makePart(Vector3.new(8, WALL_H, 1), Vector3.new(0, WALL_H / 2, 50), Color3.fromRGB(80, 45, 25), "FrontDoor")
door.Material = Enum.Material.Wood

-- spawn in the north end of the hall
local spawn = Instance.new("SpawnLocation")
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 0.5, -42)
spawn.Anchored = true
spawn.Neutral = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Parent = world

-- lamps
local lamps = {}
local function addLamp(name, pos)
	local bulb = makePart(Vector3.new(1, 0.5, 1), pos, Color3.fromRGB(255, 200, 120), "Lamp_" .. name)
	bulb.Material = Enum.Material.Neon
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 0.8
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Parent = bulb
	table.insert(lamps, { name = name, light = light, on = true })
end
local ly = WALL_H - 1
addLamp("H1", Vector3.new(0, ly, -30))
addLamp("H2", Vector3.new(0, ly, 0))
addLamp("H3", Vector3.new(0, ly, 30))
addLamp("NW", Vector3.new(-30, ly, -25))
addLamp("NE", Vector3.new(30, ly, -25))
addLamp("SE", Vector3.new(30, ly, 25))
addLamp("SW", Vector3.new(-30, ly, 25))

local function flicker(duration)
	local t = 0
	while t < duration do
		for _, l in ipairs(lamps) do
			if l.on then l.light.Enabled = math.random() > 0.5 end
		end
		local w = 0.05 + math.random() * 0.12
		task.wait(w)
		t += w
	end
	for _, l in ipairs(lamps) do l.light.Enabled = l.on end
end

-- flashlight on every player
local function addFlashlight(char)
	local head = char:WaitForChild("Head")
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Front
	sl.Range = 45
	sl.Angle = 60
	sl.Brightness = 3
	sl.Color = Color3.fromRGB(255, 245, 220)
	sl.Parent = head
end

------------------------------------------------------------
-- STORY UI
------------------------------------------------------------
local function forEachGui(fn)
	for _, plr in ipairs(Players:GetPlayers()) do
		local pg = plr:FindFirstChild("PlayerGui")
		local gui = pg and pg:FindFirstChild("StoryGui")
		if gui then fn(gui) end
	end
end

local function newLabel(parent, name, size, pos, textSize, z)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextSize = textSize
	l.Font = Enum.Font.Antique
	l.TextWrapped = true
	l.Text = ""
	l.ZIndex = z
	l.Parent = parent
	return l
end

local function createGui(plr)
	local pg = plr:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "StoryGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local black = Instance.new("Frame")
	black.Name = "Black"
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.BackgroundTransparency = state.introDone and 1 or 0
	black.ZIndex = 1
	black.Parent = gui

	local title = newLabel(gui, "Title", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.4), 64, 3)
	title.TextColor3 = Color3.fromRGB(200, 30, 30)
	newLabel(gui, "Subtitle", UDim2.fromScale(0.8, 0.12), UDim2.fromScale(0.1, 0.82), 26, 3)
	local chap = newLabel(gui, "Chapter", UDim2.fromScale(0.4, 0.05), UDim2.fromScale(0.01, 0.01), 20, 3)
	chap.TextXAlignment = Enum.TextXAlignment.Left
	chap.TextTransparency = 0.3
	chap.Text = CHAPTERS[state.chapter] or ""

	local note = newLabel(gui, "Note", UDim2.fromScale(0.45, 0.35), UDim2.fromScale(0.275, 0.3), 24, 5)
	note.BackgroundTransparency = 0
	note.BackgroundColor3 = Color3.fromRGB(225, 212, 175)
	note.TextColor3 = Color3.fromRGB(40, 25, 15)
	note.Visible = false

	gui.Parent = pg
end

local function say(text, hold)
	forEachGui(function(g)
		g.Subtitle.Text = text
		g.Subtitle.MaxVisibleGraphemes = 0
	end)
	for i = 1, #text do
		forEachGui(function(g) g.Subtitle.MaxVisibleGraphemes = i end)
		task.wait(0.03)
	end
	task.wait(hold or 3)
	forEachGui(function(g)
		if g.Subtitle.Text == text then g.Subtitle.Text = "" end
	end)
end

local function fade(target, t)
	forEachGui(function(g)
		TweenService:Create(g.Black, TweenInfo.new(t), { BackgroundTransparency = target }):Play()
	end)
	task.wait(t)
end

local function showNote(text, hold)
	forEachGui(function(g)
		g.Note.Text = text
		g.Note.Visible = true
	end)
	task.wait(hold)
	forEachGui(function(g) g.Note.Visible = false end)
end

------------------------------------------------------------
-- WRAITH
------------------------------------------------------------
local wraith = { active = false, stunned = false, speed = 9 }

local function buildWraith()
	local m = Instance.new("Model")
	m.Name = "Wraith"
	local function p(size, offset, color)
		local part = Instance.new("Part")
		part.Size = size
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CFrame = CFrame.new(offset)
		part.Parent = m
		return part
	end
	local torso = p(Vector3.new(3, 6, 1.5), Vector3.new(0, 3, 0), Color3.fromRGB(8, 8, 8))
	local head = p(Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 7.1, 0), Color3.fromRGB(220, 220, 220))
	head.Shape = Enum.PartType.Ball
	local e1 = p(Vector3.new(0.4, 0.4, 0.2), Vector3.new(-0.5, 7.3, -1.05), Color3.fromRGB(255, 0, 0))
	local e2 = p(Vector3.new(0.4, 0.4, 0.2), Vector3.new(0.5, 7.3, -1.05), Color3.fromRGB(255, 0, 0))
	e1.Material = Enum.Material.Neon
	e2.Material = Enum.Material.Neon
	p(Vector3.new(0.8, 6, 0.8), Vector3.new(-2.2, 2.5, 0), Color3.fromRGB(8, 8, 8))
	p(Vector3.new(0.8, 6, 0.8), Vector3.new(2.2, 2.5, 0), Color3.fromRGB(8, 8, 8))
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 0, 0)
	glow.Range = 14
	glow.Brightness = 1.5
	glow.Parent = head
	m.PrimaryPart = torso
	return m
end
wraith.model = buildWraith()

local function alivePlayers()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			table.insert(list, { hum = hum, root = root })
		end
	end
	return list
end

local SPAWN_SPOTS = {
	Vector3.new(-30, 3.2, -25), Vector3.new(30, 3.2, -25),
	Vector3.new(30, 3.2, 25), Vector3.new(-30, 3.2, 25),
	Vector3.new(0, 3.2, -40), Vector3.new(0, 3.2, 40),
}

local function farthestSpot()
	local players = alivePlayers()
	local best, bestScore = SPAWN_SPOTS[1], -1
	for _, spot in ipairs(SPAWN_SPOTS) do
		local nearest = math.huge
		for _, pl in ipairs(players) do
			nearest = math.min(nearest, (pl.root.Position - spot).Magnitude)
		end
		if nearest > bestScore then best, bestScore = spot, nearest end
	end
	return best
end

local function wraithOn(speed)
	wraith.speed = speed
	wraith.stunned = false
	wraith.model.Parent = Workspace
	wraith.model:PivotTo(CFrame.new(farthestSpot()))
	wraith.active = true
end

local function wraithOff()
	wraith.active = false
	wraith.model.Parent = nil
end

RunService.Heartbeat:Connect(function(dt)
	if not wraith.active or wraith.stunned then return end
	local pos = wraith.model:GetPivot().Position
	local nearest, nearestDist
	for _, pl in ipairs(alivePlayers()) do
		local d = (pl.root.Position - pos).Magnitude
		if not nearestDist or d < nearestDist then nearest, nearestDist = pl, d end
	end
	if not nearest then return end

	if nearestDist < 3.5 then
		nearest.hum.Health = 0
		wraith.stunned = true
		task.delay(6, function()
			if wraith.active then
				wraith.model:PivotTo(CFrame.new(farthestSpot()))
				wraith.stunned = false
			end
		end)
		return
	end

	local target = Vector3.new(nearest.root.Position.X, 3.2, nearest.root.Position.Z)
	local dir = target - pos
	local step = dir.Unit * math.min(wraith.speed * dt, dir.Magnitude)
	wraith.model:PivotTo(CFrame.lookAt(pos + step, target))

	-- lights glitch when it is close
	if nearestDist < 25 and math.random() < 0.05 then
		local l = lamps[math.random(#lamps)]
		task.spawn(function()
			l.light.Enabled = false
			task.wait(0.08)
			l.light.Enabled = l.on
		end)
	end
end)

------------------------------------------------------------
-- STORY TIMELINE
------------------------------------------------------------
local pageParts = {}
local advanceChapter, resetGame

local function openDoor()
	TweenService:Create(door, TweenInfo.new(1.5), { Transparency = 1 }):Play()
	door.CanCollide = false
end

local EVENTS = {}
EVENTS[1] = function()
	say("Find the 4 pages. Learn what happened here.", 4)
end
EVENTS[2] = function()
	flicker(3)
	say("The lights flicker. Something is listening.", 3)
end
EVENTS[3] = function()
	for _, l in ipairs(lamps) do
		if l.name == "NW" or l.name == "NE" then
			l.on = false
			l.light.Enabled = false
		end
	end
	say("Two rooms go dark. Whispers crawl through the walls.", 4)
end
EVENTS[4] = function()
	wraithOn(9)
	say("The wraith has woken. Do not let it touch you.", 4)
end
EVENTS[5] = function()
	openDoor()
	wraith.speed = 12
	say("The front door is unlocked. RUN.", 4)
end

local function activatePage(i)
	local pg = pageParts[i]
	pg.part.Transparency = 0.1
	pg.light.Enabled = true
	pg.prompt.Enabled = true
end

advanceChapter = function(n)
	state.chapter = n
	forEachGui(function(g) g.Chapter.Text = CHAPTERS[n] or "" end)
	if n <= 4 then activatePage(n) end
	task.spawn(EVENTS[n])
end

for i, data in ipairs(PAGES) do
	local part = makePart(Vector3.new(1.6, 2.2, 0.15), data.pos, Color3.fromRGB(235, 225, 190), "Page" .. i)
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.Transparency = 1

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 150)
	light.Range = 14
	light.Brightness = 2
	light.Enabled = false
	light.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Read page"
	prompt.ObjectText = "Page " .. i
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.Enabled = false
	prompt.Parent = part

	local entry = { part = part, light = light, prompt = prompt, done = false }
	pageParts[i] = entry

	prompt.Triggered:Connect(function()
		if state.chapter ~= i or entry.done then return end
		entry.done = true
		part.Transparency = 1
		light.Enabled = false
		prompt.Enabled = false
		task.spawn(function()
			showNote(data.text, 8)
			advanceChapter(i + 1)
		end)
	end)
end

-- ending trigger (outside the front door)
local escapeZone = makePart(Vector3.new(14, 8, 8), Vector3.new(0, 4, 58), Color3.new(0, 0, 0), "EscapeZone")
escapeZone.Transparency = 1
escapeZone.CanCollide = false

local function endGame()
	if state.ending then return end
	state.ending = true
	wraithOff()
	fade(0, 2)
	say("You stumble into the cold night air.", 3)
	say("Behind you, the house falls silent.", 3)
	say("But in the upstairs window... something is smiling.", 4)
	forEachGui(function(g) g.Title.Text = "THE END" end)
	task.wait(6)
	resetGame()
end

escapeZone.Touched:Connect(function(hit)
	if state.chapter ~= 5 then return end
	local char = hit.Parent
	if char and char:FindFirstChildOfClass("Humanoid") and Players:GetPlayerFromCharacter(char) then
		task.spawn(endGame)
	end
end)

resetGame = function()
	state.chapter = 0
	door.Transparency = 0
	door.CanCollide = true
	for _, pg in ipairs(pageParts) do
		pg.done = false
		pg.part.Transparency = 1
		pg.light.Enabled = false
		pg.prompt.Enabled = false
	end
	for _, l in ipairs(lamps) do
		l.on = true
		l.light.Enabled = true
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(function() plr:LoadCharacter() end)
	end
	task.wait(2)
	forEachGui(function(g) g.Title.Text = "" end)
	state.ending = false
	fade(1, 2)
	advanceChapter(1)
end

local function intro()
	task.wait(2)
	forEachGui(function(g) g.Title.Text = "HOLLOW HOUSE" end)
	task.wait(3)
	forEachGui(function(g) g.Title.Text = "" end)
	say("1987. The Hollow family vanished overnight.", 3)
	say("No bodies. No answers. Only the house remained.", 3)
	say("You are the investigator sent to find out why.", 3)
	state.introDone = true
	fade(1, 3)
	advanceChapter(1)
end

------------------------------------------------------------
-- PLAYERS
------------------------------------------------------------
local function onPlayer(plr)
	createGui(plr)
	plr.CharacterAdded:Connect(addFlashlight)
	if plr.Character then task.spawn(addFlashlight, plr.Character) end
	if not state.started then
		state.started = true
		task.spawn(intro)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, plr)
end
