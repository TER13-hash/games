--!strict
-- Enchanted Realm: Inkbound — COD Mobile-style tactical map system.
-- 1. Rotating minimap (top-left): world rotates around the player, compass
--    letters, boss blips, waypoint diamond. Tap it to open the full map.
-- 2. Full tactical map (M): letter/number grid (A1..H4), region panels,
--    boss/gate/portal markers, live facing arrow, click-to-ping waypoints.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Regions"))

local player = Players.LocalPlayer

-- —————— world projection ——————

local WORLD_MIN_X = 0
local WORLD_MAX_X = 2680
local WORLD_MIN_Z = -40
local WORLD_MAX_Z = 40
local WORLD_SPAN_X = WORLD_MAX_X - WORLD_MIN_X
local WORLD_SPAN_Z = WORLD_MAX_Z - WORLD_MIN_Z

local MINI_SIZE = 170 -- minimap pixels
local MINI_SCALE = 1.5 -- minimap px per stud
local FULL_W = 1500 -- full map canvas px
local FULL_H = 430
local MAP_X0 = 34 -- map area origin inside canvas (leaves room for grid labels)
local MAP_Y0 = 30
local MAP_W = FULL_W - 50
local MAP_H = FULL_H - 46

local GRID_COLS = 8
local GRID_ROWS = 4
local COL_LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H" }

local REGION_COLORS: { [string]: Color3 } = {
	forest = Color3.fromRGB(52, 104, 66),
	ruins = Color3.fromRGB(112, 100, 78),
	burning = Color3.fromRGB(134, 70, 38),
	frozen = Color3.fromRGB(96, 136, 176),
	cave = Color3.fromRGB(76, 64, 118),
	sky = Color3.fromRGB(148, 184, 218),
	underground = Color3.fromRGB(52, 68, 74),
}

local gui = Instance.new("ScreenGui")
gui.Name = "WorldMapGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function makeCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function makeStroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
end

local function gridCode(x: number, z: number): string
	local col = math.clamp(math.floor((x - WORLD_MIN_X) / WORLD_SPAN_X * GRID_COLS) + 1, 1, GRID_COLS)
	local row = math.clamp(math.floor((z - WORLD_MIN_Z) / WORLD_SPAN_Z * GRID_ROWS) + 1, 1, GRID_ROWS)
	return COL_LETTERS[col] .. tostring(row)
end

local function worldToFullX(x: number): number
	return MAP_X0 + (x - WORLD_MIN_X) * (MAP_W / WORLD_SPAN_X)
end

local function worldToFullY(z: number): number
	return MAP_Y0 + (z - WORLD_MIN_Z) * (MAP_H / WORLD_SPAN_Z)
end

-- —————— minimap (always visible, top-left) ——————

local minimap = Instance.new("Frame")
minimap.Name = "Minimap"
minimap.BackgroundColor3 = Color3.fromRGB(10, 12, 10)
minimap.BackgroundTransparency = 0.08
minimap.BorderSizePixel = 0
minimap.Size = UDim2.new(0, MINI_SIZE, 0, MINI_SIZE)
minimap.Position = UDim2.new(0, 14, 0, 14)
minimap.ClipsDescendants = true
minimap.Parent = gui
makeCorner(minimap, 12)
makeStroke(minimap, Color3.fromRGB(90, 110, 90), 2)

-- rotating world layer (spins so the player's facing is always up)
local rotator = Instance.new("Frame")
rotator.Name = "Rotator"
rotator.BackgroundTransparency = 1
rotator.Size = UDim2.new(1, 0, 1, 0)
rotator.Parent = minimap

local miniWorld = Instance.new("Frame")
miniWorld.Name = "MiniWorld"
miniWorld.BackgroundTransparency = 1
miniWorld.Size = UDim2.new(0, WORLD_SPAN_X * MINI_SCALE, 0, WORLD_SPAN_Z * MINI_SCALE)
miniWorld.Parent = rotator

-- region blocks on the minimap
for _, id in ipairs(Regions.ORDER) do
	local r = Regions.byId[id]
	local block = Instance.new("Frame")
	block.Name = r.id
	block.BackgroundColor3 = REGION_COLORS[id] or Color3.fromRGB(90, 90, 100)
	block.BackgroundTransparency = 0.3
	block.BorderSizePixel = 0
	block.Size = UDim2.new(0, (r.maxX - r.minX) * MINI_SCALE, 0, WORLD_SPAN_Z * MINI_SCALE)
	block.Position = UDim2.new(0, (r.minX - WORLD_MIN_X) * MINI_SCALE, 0, 0)
	block.Parent = miniWorld
end

-- gate lines
for _, wall in ipairs(Regions.WALLS) do
	local gate = Instance.new("Frame")
	gate.Name = "Gate" .. tostring(wall.x)
	gate.BackgroundColor3 = Color3.fromRGB(30, 26, 40)
	gate.BorderSizePixel = 0
	gate.Size = UDim2.new(0, 3, 0, WORLD_SPAN_Z * MINI_SCALE)
	gate.Position = UDim2.new(0, (wall.x - WORLD_MIN_X) * MINI_SCALE, 0, 0)
	gate.ZIndex = 2
	gate.Parent = miniWorld
end

-- boss blips (red dots)
for _, id in ipairs(Regions.ORDER) do
	local r = Regions.byId[id]
	if r.boss then
		local blip = Instance.new("Frame")
		blip.Name = "BossBlip"
		blip.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
		blip.BorderSizePixel = 0
		blip.Size = UDim2.new(0, 7, 0, 7)
		blip.Position = UDim2.new(0, (r.boss.x - WORLD_MIN_X) * MINI_SCALE - 3, 0, (0 - WORLD_MIN_Z) * MINI_SCALE - 3)
		blip.ZIndex = 3
		blip.Parent = miniWorld
		makeCorner(blip, 4)
	end
end

-- minimap waypoint diamond
local miniWaypoint = Instance.new("Frame")
miniWaypoint.Name = "Waypoint"
miniWaypoint.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
miniWaypoint.BorderSizePixel = 0
miniWaypoint.Size = UDim2.new(0, 8, 0, 8)
miniWaypoint.Rotation = 45
miniWaypoint.Visible = false
miniWaypoint.ZIndex = 4
miniWaypoint.Parent = miniWorld
makeStroke(miniWaypoint, Color3.fromRGB(60, 40, 10), 1)

-- live enemy blips (red dots that rotate with the world)
local enemyBlips: { [Instance]: Frame } = {}
local lastEnemyScan = 0

-- compass letters (rotate with the world layer)
local function compassLabel(text: string, position: UDim2)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0, 14, 0, 14)
	l.Position = position
	l.Font = Enum.Font.GothamBold
	l.Text = text
	l.TextColor3 = Color3.fromRGB(200, 220, 200)
	l.TextScaled = true
	l.ZIndex = 6
	l.Parent = rotator
end
compassLabel("N", UDim2.new(0.5, -7, 0, 3))
compassLabel("E", UDim2.new(1, -17, 0.5, -7))
compassLabel("S", UDim2.new(0.5, -7, 1, -17))
compassLabel("W", UDim2.new(0, 3, 0.5, -7))

-- fixed player arrow (always centered, pointing up)
local arrow = Instance.new("TextLabel")
arrow.Name = "PlayerArrow"
arrow.BackgroundTransparency = 1
arrow.Size = UDim2.new(0, 26, 0, 26)
arrow.Position = UDim2.new(0.5, -13, 0.5, -13)
arrow.Font = Enum.Font.GothamBold
arrow.Text = "▲"
arrow.TextColor3 = Color3.fromRGB(130, 255, 150)
arrow.TextScaled = true
arrow.ZIndex = 8
arrow.Parent = minimap

-- region + grid readout under the minimap
local miniInfo = Instance.new("TextLabel")
miniInfo.Name = "MiniInfo"
miniInfo.BackgroundColor3 = Color3.fromRGB(10, 12, 10)
miniInfo.BackgroundTransparency = 0.35
miniInfo.BorderSizePixel = 0
miniInfo.Size = UDim2.new(0, MINI_SIZE, 0, 20)
miniInfo.Position = UDim2.new(0, 14, 0, 14 + MINI_SIZE + 4)
miniInfo.Font = Enum.Font.GothamBold
miniInfo.Text = ""
miniInfo.TextColor3 = Color3.fromRGB(190, 230, 190)
miniInfo.TextScaled = true
miniInfo.Parent = gui
makeCorner(miniInfo, 6)

-- —————— compass strip (top center, COD-style) ——————

local COMPASS_W = 360
local PX_PER_DEG = 3
local compass = Instance.new("Frame")
compass.Name = "CompassStrip"
compass.BackgroundColor3 = Color3.fromRGB(10, 12, 10)
compass.BackgroundTransparency = 0.45
compass.BorderSizePixel = 0
compass.Size = UDim2.new(0, COMPASS_W, 0, 26)
compass.Position = UDim2.new(0.5, -COMPASS_W / 2, 0, 58)
compass.ClipsDescendants = true
compass.Parent = gui
makeCorner(compass, 8)

local compassInner = Instance.new("Frame")
compassInner.Name = "Inner"
compassInner.BackgroundTransparency = 1
compassInner.Size = UDim2.new(0, 0, 1, 0)
compassInner.Parent = compass

local CARDINALS: { [number]: string } = {
	[0] = "N", [45] = "NE", [90] = "E", [135] = "SE",
	[180] = "S", [225] = "SW", [270] = "W", [315] = "NW",
}
for d = -360, 720, 15 do
	local norm = (d % 360 + 360) % 360
	local cardinal = CARDINALS[norm]
	if cardinal then
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(0, 34, 1, 0)
		l.Position = UDim2.new(0, d * PX_PER_DEG - 17, 0, 0)
		l.Font = Enum.Font.GothamBlack
		l.Text = cardinal
		l.TextColor3 = if norm == 0 then Color3.fromRGB(255, 235, 120) else Color3.fromRGB(220, 240, 220)
		l.TextScaled = true
		l.Parent = compassInner
	else
		local t = Instance.new("Frame")
		t.BackgroundColor3 = Color3.fromRGB(180, 210, 180)
		t.BackgroundTransparency = 0.4
		t.BorderSizePixel = 0
		t.Size = UDim2.new(0, 1, 0, 6)
		t.Position = UDim2.new(0, d * PX_PER_DEG, 0, 18)
		t.Parent = compassInner
	end
end

-- center notch marking the current heading
local notch = Instance.new("Frame")
notch.Name = "Notch"
notch.BackgroundColor3 = Color3.fromRGB(255, 235, 120)
notch.BorderSizePixel = 0
notch.Size = UDim2.new(0, 2, 0, 8)
notch.Position = UDim2.new(0.5, -1, 0, 0)
notch.ZIndex = 3
notch.Parent = compass

-- —————— full tactical map (toggle with M) ——————

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.BackgroundColor3 = Color3.fromRGB(6, 8, 6)
overlay.BackgroundTransparency = 0.25
overlay.BorderSizePixel = 0
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.Visible = false
overlay.ZIndex = 40
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(14, 16, 14)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Size = UDim2.new(0.86, 0, 0.8, 0)
panel.Position = UDim2.new(0.07, 0, 0.1, 0)
panel.Parent = overlay
makeCorner(panel, 14)
makeStroke(panel, Color3.fromRGB(90, 120, 90), 2)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -120, 0, 40)
title.Position = UDim2.new(0, 16, 0, 8)
title.Font = Enum.Font.GothamBlack
	title.Text = "TACTICAL MAP — ENCHANTED REALM"
title.TextColor3 = Color3.fromRGB(180, 235, 180)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local waypointLabel = Instance.new("TextLabel")
waypointLabel.Name = "WaypointLabel"
waypointLabel.BackgroundTransparency = 1
waypointLabel.Size = UDim2.new(0, 260, 0, 26)
waypointLabel.Position = UDim2.new(0, 16, 0, 44)
waypointLabel.Font = Enum.Font.GothamBold
waypointLabel.Text = ""
waypointLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
waypointLabel.TextScaled = true
waypointLabel.TextXAlignment = Enum.TextXAlignment.Left
waypointLabel.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
closeBtn.BackgroundTransparency = 0.2
closeBtn.BorderSizePixel = 0
closeBtn.Size = UDim2.new(0, 40, 0, 32)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
closeBtn.TextScaled = true
closeBtn.Parent = panel
makeCorner(closeBtn, 8)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "MapScroll"
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Size = UDim2.new(1, -24, 1, -84)
scroll.Position = UDim2.new(0, 12, 0, 72)
scroll.CanvasSize = UDim2.new(0, FULL_W, 0, FULL_H)
scroll.ScrollingDirection = Enum.ScrollingDirection.XY
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 160, 120)
scroll.Parent = panel

local strip = Instance.new("Frame")
strip.Name = "Strip"
strip.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
strip.BackgroundTransparency = 0.35
strip.BorderSizePixel = 0
strip.Size = UDim2.new(0, FULL_W, 0, FULL_H)
strip.Parent = scroll
makeCorner(strip, 10)

-- region panels
for _, id in ipairs(Regions.ORDER) do
	local r = Regions.byId[id]
	local px = worldToFullX(r.minX)
	local pw = worldToFullX(r.maxX) - px
	local seg = Instance.new("Frame")
	seg.Name = r.id
	seg.BackgroundColor3 = REGION_COLORS[id] or Color3.fromRGB(90, 90, 100)
	seg.BackgroundTransparency = 0.5
	seg.BorderSizePixel = 0
	seg.Size = UDim2.new(0, pw, 0, MAP_H)
	seg.Position = UDim2.new(0, px, 0, MAP_Y0)
	seg.Parent = strip
	makeCorner(seg, 6)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.Position = UDim2.new(0, 0, 0, 4)
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = string.upper(r.name)
	lbl.TextColor3 = Color3.fromRGB(240, 255, 240)
	lbl.TextScaled = true
	lbl.Parent = seg
end

-- grid lines + labels
local colStep = MAP_W / GRID_COLS
local rowStep = MAP_H / GRID_ROWS
for i = 0, GRID_COLS do
	local line = Instance.new("Frame")
	line.Name = "GridV" .. tostring(i)
	line.BackgroundColor3 = Color3.fromRGB(160, 200, 160)
	line.BackgroundTransparency = 0.75
	line.BorderSizePixel = 0
	line.Size = UDim2.new(0, 1, 0, MAP_H)
	line.Position = UDim2.new(0, MAP_X0 + i * colStep, 0, MAP_Y0)
	line.ZIndex = 5
	line.Parent = strip
	if i < GRID_COLS then
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(0, colStep, 0, 18)
		l.Position = UDim2.new(0, MAP_X0 + i * colStep, 0, MAP_Y0 - 20)
		l.Font = Enum.Font.GothamBlack
		l.Text = COL_LETTERS[i + 1]
		l.TextColor3 = Color3.fromRGB(170, 210, 170)
		l.TextScaled = true
		l.Parent = strip
	end
end
for j = 0, GRID_ROWS do
	local line = Instance.new("Frame")
	line.Name = "GridH" .. tostring(j)
	line.BackgroundColor3 = Color3.fromRGB(160, 200, 160)
	line.BackgroundTransparency = 0.75
	line.BorderSizePixel = 0
	line.Size = UDim2.new(0, MAP_W, 0, 1)
	line.Position = UDim2.new(0, MAP_X0, 0, MAP_Y0 + j * rowStep)
	line.ZIndex = 5
	line.Parent = strip
	if j < GRID_ROWS then
		local n = Instance.new("TextLabel")
		n.BackgroundTransparency = 1
		n.Size = UDim2.new(0, 20, 0, rowStep)
		n.Position = UDim2.new(0, MAP_X0 - 22, 0, MAP_Y0 + j * rowStep)
		n.Font = Enum.Font.GothamBlack
		n.Text = tostring(j + 1)
		n.TextColor3 = Color3.fromRGB(170, 210, 170)
		n.TextScaled = true
		n.Parent = strip
	end
end

-- gates
for _, wall in ipairs(Regions.WALLS) do
	local gate = Instance.new("Frame")
	gate.Name = "Gate" .. tostring(wall.x)
	gate.BackgroundColor3 = Color3.fromRGB(40, 36, 50)
	gate.BorderSizePixel = 0
	gate.Size = UDim2.new(0, 6, 0, MAP_H)
	gate.Position = UDim2.new(0, worldToFullX(wall.x) - 3, 0, MAP_Y0)
	gate.ZIndex = 6
	gate.Parent = strip
	local gl = Instance.new("TextLabel")
	gl.BackgroundTransparency = 1
	gl.Size = UDim2.new(0, 44, 0, 14)
	gl.Position = UDim2.new(0, worldToFullX(wall.x) - 22, 0, MAP_Y0 + 2)
	gl.Font = Enum.Font.GothamBold
	gl.Text = "GATE"
	gl.TextColor3 = Color3.fromRGB(200, 190, 220)
	gl.TextScaled = true
	gl.ZIndex = 7
	gl.Parent = strip
end

-- boss markers
for _, id in ipairs(Regions.ORDER) do
	local r = Regions.byId[id]
	if r.boss then
		local bx = worldToFullX(r.boss.x)
		local by = worldToFullY(0)
		local boss = Instance.new("TextLabel")
		boss.Name = "Boss" .. r.id
		boss.BackgroundTransparency = 1
		boss.Size = UDim2.new(0, 26, 0, 26)
		boss.Position = UDim2.new(0, bx - 13, 0, by - 13)
		boss.Font = Enum.Font.GothamBlack
		boss.Text = "✖"
		boss.TextColor3 = Color3.fromRGB(255, 80, 80)
		boss.TextScaled = true
		boss.ZIndex = 8
		boss.Parent = strip
		local bl = Instance.new("TextLabel")
		bl.BackgroundTransparency = 1
		bl.Size = UDim2.new(0, 50, 0, 12)
		bl.Position = UDim2.new(0, bx - 25, 0, by + 13)
		bl.Font = Enum.Font.GothamBold
		bl.Text = "BOSS"
		bl.TextColor3 = Color3.fromRGB(255, 120, 120)
		bl.TextScaled = true
		bl.ZIndex = 8
		bl.Parent = strip
	end
end

-- portals
for _, portal in ipairs(Regions.PORTALS) do
	local p = Instance.new("TextLabel")
	p.Name = "Portal" .. portal.id
	p.BackgroundTransparency = 1
	p.Size = UDim2.new(0, 24, 0, 24)
	p.Position = UDim2.new(0, worldToFullX(portal.a.x) - 12, 0, worldToFullY(0) + 18)
	p.Font = Enum.Font.GothamBlack
	p.Text = "◈"
	p.TextColor3 = Color3.fromRGB(120, 220, 255)
	p.TextScaled = true
	p.ZIndex = 8
	p.Parent = strip
end

-- start point
local startMark = Instance.new("TextLabel")
startMark.Name = "Start"
startMark.BackgroundTransparency = 1
startMark.Size = UDim2.new(0, 24, 0, 24)
startMark.Position = UDim2.new(0, worldToFullX(30) - 12, 0, worldToFullY(0) + 18)
startMark.Font = Enum.Font.GothamBlack
startMark.Text = "▶"
startMark.TextColor3 = Color3.fromRGB(140, 255, 140)
startMark.TextScaled = true
startMark.ZIndex = 8
startMark.Parent = strip

-- live player marker on the full map
local fullPlayer = Instance.new("TextLabel")
fullPlayer.Name = "Player"
fullPlayer.BackgroundTransparency = 1
fullPlayer.Size = UDim2.new(0, 26, 0, 26)
fullPlayer.Font = Enum.Font.GothamBlack
fullPlayer.Text = "▲"
fullPlayer.TextColor3 = Color3.fromRGB(255, 235, 120)
fullPlayer.TextScaled = true
fullPlayer.ZIndex = 10
fullPlayer.Parent = strip

local fullPlayerTag = Instance.new("TextLabel")
fullPlayerTag.BackgroundTransparency = 1
fullPlayerTag.Size = UDim2.new(0, 40, 0, 12)
fullPlayerTag.Font = Enum.Font.GothamBold
fullPlayerTag.Text = "YOU"
fullPlayerTag.TextColor3 = Color3.fromRGB(255, 235, 120)
fullPlayerTag.TextScaled = true
fullPlayerTag.ZIndex = 10
fullPlayerTag.Parent = fullPlayer

-- full map waypoint marker
local fullWaypoint = Instance.new("TextLabel")
fullWaypoint.Name = "Waypoint"
fullWaypoint.BackgroundTransparency = 1
fullWaypoint.Size = UDim2.new(0, 22, 0, 22)
fullWaypoint.Font = Enum.Font.GothamBlack
fullWaypoint.Text = "◆"
fullWaypoint.TextColor3 = Color3.fromRGB(255, 200, 60)
fullWaypoint.TextScaled = true
fullWaypoint.Visible = false
fullWaypoint.ZIndex = 9
fullWaypoint.Parent = strip

-- —————— state + updates ——————

local isOpen = false
local waypointWorld: Vector3? = nil
local mapAllowed = true -- false while the title screen is up

-- 3D waypoint beacon (client-side visual column at the ping location)
local beacon: BasePart? = nil
local beaconLabel: TextLabel? = nil

local function setWaypoint(worldPos: Vector3)
	waypointWorld = worldPos
	miniWaypoint.Position = UDim2.new(0, (worldPos.X - WORLD_MIN_X) * MINI_SCALE - 4, 0, (worldPos.Z - WORLD_MIN_Z) * MINI_SCALE - 4)
	miniWaypoint.Visible = true
	fullWaypoint.Position = UDim2.new(0, worldToFullX(worldPos.X) - 11, 0, worldToFullY(worldPos.Z) - 11)
	fullWaypoint.Visible = true

	-- create / move the 3D beacon so the map and the world guide each other
	if not beacon then
		beacon = Instance.new("Part")
		beacon.Name = "WaypointBeacon"
		beacon.Size = Vector3.new(1.2, 90, 1.2)
		beacon.Material = Enum.Material.Neon
		beacon.Color = Color3.fromRGB(255, 200, 60)
		beacon.Transparency = 0.55
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.Parent = workspace
		local bb = Instance.new("BillboardGui")
		bb.Name = "BeaconTag"
		bb.Size = UDim2.new(0, 140, 0, 34)
		bb.StudsOffset = Vector3.new(0, 50, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 100000
		bb.Parent = beacon
		beaconLabel = Instance.new("TextLabel")
		beaconLabel.BackgroundTransparency = 1
		beaconLabel.Size = UDim2.new(1, 0, 1, 0)
		beaconLabel.Font = Enum.Font.GothamBlack
		beaconLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
		beaconLabel.TextScaled = true
		beaconLabel.TextStrokeTransparency = 0.4
		beaconLabel.TextStrokeColor3 = Color3.fromRGB(20, 16, 4)
		beaconLabel.Text = "◆ WAYPOINT"
		beaconLabel.Parent = bb
	end
	beacon.Position = Vector3.new(worldPos.X, worldPos.Y + 45, worldPos.Z)
end

-- click on the full map to place a waypoint ping
strip.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local pxX = input.Position.X - strip.AbsolutePosition.X
		local pxY = input.Position.Y - strip.AbsolutePosition.Y
		local wx = WORLD_MIN_X + (pxX - MAP_X0) / (MAP_W / WORLD_SPAN_X)
		local wz = WORLD_MIN_Z + (pxY - MAP_Y0) / (MAP_H / WORLD_SPAN_Z)
		setWaypoint(Vector3.new(math.clamp(wx, WORLD_MIN_X, WORLD_MAX_X), 0, math.clamp(wz, WORLD_MIN_Z, WORLD_MAX_Z)))
	end
end)

-- live updates: minimap always, full map while open
RunService.Heartbeat:Connect(function()
	-- hide the map HUD while the title screen is up
	local pg = player:FindFirstChild("PlayerGui")
	local syncGui = pg and pg:FindFirstChild("SyncGui")
	local titleShowing = syncGui ~= nil and syncGui:FindFirstChild("TitleMenu") ~= nil
	mapAllowed = not titleShowing
	if minimap.Visible ~= mapAllowed then
		minimap.Visible = mapAllowed
		miniInfo.Visible = mapAllowed
		compass.Visible = mapAllowed
		if not mapAllowed and isOpen then
			overlay.Visible = false
			isOpen = false
		end
	end
	if not mapAllowed then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local look = cam.CFrame.LookVector
	local heading = math.deg(math.atan2(look.X, -look.Z))
	local pos = hrp.Position

	-- compass strip: slide the labels with the camera heading
	local normHeading = (heading % 360 + 360) % 360
	compassInner.Position = UDim2.new(0, COMPASS_W / 2 - normHeading * PX_PER_DEG, 0, 0)

	-- minimap: rotate world around player, keep player centered
	rotator.Rotation = -heading
	miniWorld.Position = UDim2.new(
		0, MINI_SIZE / 2 - (pos.X - WORLD_MIN_X) * MINI_SCALE,
		0, MINI_SIZE / 2 - (pos.Z - WORLD_MIN_Z) * MINI_SCALE
	)
	local region = Regions.regionAt(pos.X)
	miniInfo.Text = string.upper(region.name) .. "  ·  " .. gridCode(pos.X, pos.Z)

	-- live enemy blips: rescan the world every 0.25s
	if os.clock() - lastEnemyScan > 0.25 then
		lastEnemyScan = os.clock()
		local world = workspace:FindFirstChild("EnchantedRealm") or workspace
		local seen: { [Instance]: true } = {}
		for _, m in ipairs(world:GetChildren()) do
			if m:IsA("Model") and string.sub(m.Name, 1, 6) == "Creep_" then
				local pp = m.PrimaryPart
				if pp then
					seen[m] = true
					local blip = enemyBlips[m]
					if not blip then
						blip = Instance.new("Frame")
						blip.Name = "EnemyBlip"
						blip.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
						blip.BorderSizePixel = 0
						blip.Size = UDim2.new(0, 5, 0, 5)
						blip.ZIndex = 3
						blip.Parent = miniWorld
						local bc = Instance.new("UICorner")
						bc.CornerRadius = UDim.new(1, 0)
						bc.Parent = blip
						enemyBlips[m] = blip
					end
					blip.Position = UDim2.new(0, (pp.Position.X - WORLD_MIN_X) * MINI_SCALE - 2, 0, (pp.Position.Z - WORLD_MIN_Z) * MINI_SCALE - 2)
				end
			end
		end
		for m, blip in pairs(enemyBlips) do
			if not seen[m] then
				blip:Destroy()
				enemyBlips[m] = nil
			end
		end
	end

	-- beacon tag shows live distance to the waypoint
	if waypointWorld and beacon and beaconLabel then
		beaconLabel.Text = "◆ " .. gridCode(waypointWorld.X, waypointWorld.Z) .. " · " .. math.floor((pos - waypointWorld).Magnitude) .. "m"
	end

	-- full map
	if isOpen then
		fullPlayer.Position = UDim2.new(0, worldToFullX(pos.X) - 13, 0, worldToFullY(pos.Z) - 13)
		fullPlayer.Rotation = heading
		if waypointWorld then
			waypointLabel.Text = "WAYPOINT " .. gridCode(waypointWorld.X, waypointWorld.Z) .. " — " .. math.floor((pos - waypointWorld).Magnitude) .. "m  (click map to move it)"
		end
	end
end)

-- —————— open / close ——————

local function openMap()
	if isOpen then
		return
	end
	isOpen = true
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.25 }):Play()
	panel.Size = UDim2.new(0.86, 0, 0, 0)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0.86, 0, 0.8, 0) }):Play()
	-- center the scroll on the player
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		local viewW = scroll.AbsoluteWindowSize.X
		if viewW > 0 then
			local target = math.clamp(worldToFullX(hrp.Position.X) - viewW / 2, 0, math.max(0, FULL_W - viewW))
			scroll.CanvasPosition = Vector2.new(target, 0)
		end
	end
end

local function closeMap()
	if not isOpen then
		return
	end
	isOpen = false
	local tween = TweenService:Create(panel, TweenInfo.new(0.15), { Size = UDim2.new(0.86, 0, 0, 0) })
	tween:Play()
	tween.Completed:Once(function()
		if not isOpen then
			overlay.Visible = false
		end
	end)
end

local function toggleMap()
	if not mapAllowed then
		return
	end
	if isOpen then
		closeMap()
	else
		openMap()
	end
end

closeBtn.Activated:Connect(closeMap)

-- tap the minimap to expand, like COD Mobile
minimap.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		toggleMap()
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		toggleMap()
	elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closeMap()
	end
end)

print("[Inkbound] tactical map ready (minimap + grid map, COD-style)")