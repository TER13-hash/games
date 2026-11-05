--!strict
-- Builds the entire Enchanted Realm map into Workspace from Regions.luau.
-- Everything is anchored, sketch-styled ("Inkbound" look: matte colors + black ink outlines + Neon accents).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Regions = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Regions"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local WorldBuilder = {}

-- deterministic RNG so the map is the same every boot
local rng = Random.new(1337)

local function newPart(def: {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	canQuery: boolean?,
	shape: Enum.PartType?,
	parent: Instance,
	neon: boolean?,
}): Part
	local p = Instance.new("Part")
	p.Name = def.name
	p.Anchored = true
	p.Size = def.size
	p.CFrame = def.cframe
	p.Color = def.color
	p.Material = def.neon and Enum.Material.Neon or (def.material or Enum.Material.SmoothPlastic)
	p.Transparency = def.transparency or 0
	p.CanCollide = def.canCollide ~= false
	p.CanQuery = def.canQuery ~= false
	p.CanTouch = true
	p.Shape = def.shape or Enum.PartType.Block
	p.Parent = def.parent
	return p
end

-- "Inkbound" outline: slightly larger matte-black shell behind an object
local function inkOutline(part: BasePart, parent: Instance, grow: number?)
	local g = (grow or 0.08)
	local outline = Instance.new("Part")
	outline.Name = "InkOutline"
	outline.Anchored = true
	outline.CanCollide = false
	outline.CanQuery = false
	outline.CanTouch = false
	outline.Material = Enum.Material.SmoothPlastic
	outline.Color = Color3.fromRGB(8, 8, 10)
	outline.Shape = part.Shape
	outline.Size = part.Size + Vector3.new(g, g, g)
	outline.CFrame = part.CFrame
	outline.Parent = parent
	return outline
end

-- sketchy floating text label
local function makeLabel(text: string, adornee: BasePart, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Adornee = adornee
	bb.Size = UDim2.new(0, 220, 0, 40)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = 60
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Font = Enum.Font.Bangers
	lbl.Text = text
	lbl.TextScaled = true
	lbl.TextColor3 = color or Color3.fromRGB(255, 240, 205)
	lbl.TextStrokeTransparency = 0.4
	lbl.TextStrokeColor3 = Color3.fromRGB(10, 10, 12)
	lbl.Parent = bb
	bb.Parent = adornee
end

local function makeLantern(name: string, x: number, y: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	local base = newPart({
		name = "Base", size = Vector3.new(1.6, 4.2, 1.6),
		cframe = CFrame.new(x, y + 2.1, 0),
		color = Color3.fromRGB(52, 44, 40), material = Enum.Material.Rock, parent = model,
	})
	newPart({
		name = "Cap", size = Vector3.new(2.6, 0.7, 2.6),
		cframe = CFrame.new(x, y + 4.5, 0),
		color = Color3.fromRGB(36, 30, 28), material = Enum.Material.Rock, parent = model,
	})
	local flame = newPart({
		name = "Flame", size = Vector3.new(1.5, 1.8, 1.5),
		cframe = CFrame.new(x, y + 3.2, 0),
		color = Color3.fromRGB(255, 190, 90), neon = true, parent = model, canCollide = false,
		shape = Enum.PartType.Ball,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 110)
	light.Range = 22
	light.Brightness = 2.4
	light.Parent = flame
	local attach = Instance.new("Attachment")
	attach.Parent = flame
	local ember = Instance.new("ParticleEmitter")
	ember.Texture = "rbxassetid://243660364"
	ember.Color = ColorSequence.new(Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 90, 30))
	ember.Rate = 6
	ember.Lifetime = NumberRange.new(0.5, 1.1)
	ember.Speed = NumberRange.new(1.2, 2.4)
	ember.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	ember.Acceleration = Vector3.new(0, 2.5, 0)
	ember.Parent = attach
	model.PrimaryPart = base
	model.Parent = parent
	model:SetAttribute("CheckpointX", x)
	return model
end

local function makeHeart(name: string, x: number, y: number, parent: Instance): Part
	local heart = newPart({
		name = name, size = Vector3.new(2.6, 2.4, 1.4),
		cframe = CFrame.new(x, y, 0),
		color = Color3.fromRGB(255, 70, 90), neon = true, parent = parent, canCollide = false,
		shape = Enum.PartType.Ball,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 80, 110)
	light.Range = 14
	light.Brightness = 2
	light.Parent = heart
	inkOutline(heart, parent, 0.18)
	return heart
end

local function makeBarrier(btype: string, x: number, y: number, w: number, h: number, d: number, parent: Instance, color: Color3, neon: boolean?, material: Enum.Material?, transparency: number?): Part
	local barrier = newPart({
		name = "Barrier_" .. btype,
		size = Vector3.new(w, h, d),
		cframe = CFrame.new(x, y, 0),
		color = color,
		neon = neon or false,
		material = material,
		transparency = transparency,
		parent = parent,
	})
	barrier:SetAttribute("BarrierType", btype)
	inkOutline(barrier, parent, 0.12)
	barrier.Parent = parent
	return barrier
end

local function scatterDecor(regionId: string, decor: any, parent: Instance, grounds: any)
	local function randGroundX(): number
		local g = grounds[rng:NextInteger(1, #grounds)]
		local pad = 3
		local lo, hi = g.x0 + pad, g.x1 - pad
		if hi <= lo then
			hi = lo + 1
		end
		return rng:NextNumber(lo, hi)
	end
	local function groundTopAt(x: number): number
		for _, g in ipairs(grounds) do
			if x >= g.x0 and x <= g.x1 then
				return g.topY
			end
		end
		return 0
	end

	local function addTree(scale: number, pine: boolean)
		local x = randGroundX()
		local y = groundTopAt(x)
		local trunkH = 3.4 * scale
		local trunk = newPart({
			name = "TreeTrunk", size = Vector3.new(1.3 * scale, trunkH, 1.3 * scale),
			cframe = CFrame.new(x, y + trunkH / 2, rng:NextNumber(-6, 6)),
			color = Color3.fromRGB(74, 52, 36), material = Enum.Material.Wood, parent = parent, shape = Enum.PartType.Cylinder,
		}) * CFrame.Angles(0, 0, math.rad(90))
		trunk.CFrame = trunk.CFrame * CFrame.Angles(0, 0, math.rad(90))
		local canopy = newPart({
			name = "TreeCanopy", size = Vector3.new(6.4 * scale, 5.4 * scale, 5.4 * scale),
			cframe = CFrame.new(x, y + trunkH + 2.2 * scale, 0),
			color = if pine then Color3.fromRGB(34, 84, 46) else Color3.fromRGB(52, 118, 58),
			material = Enum.Material.Grass, parent = parent, shape = Enum.PartType.Ball, canCollide = false,
		})
		inkOutline(canopy, parent, 0.16)
	end

	local function addRock(scale: number)
		local x = randGroundX()
		local y = groundTopAt(x)
		local rock = newPart({
			name = "Rock", size = Vector3.new(2.6 * scale, 1.8 * scale, 2.0 * scale),
			cframe = CFrame.new(x, y + 0.7 * scale, rng:NextNumber(-5, 5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			color = Color3.fromRGB(96, 92, 88), material = Enum.Material.Rock, parent = parent, shape = Enum.PartType.Ball, canCollide = false,
		})
		inkOutline(rock, parent, 0.1)
	end

	local function addCrystal(scale: number, hue: Color3)
		local x = randGroundX()
		local y = groundTopAt(x)
		local shard = newPart({
			name = "Crystal", size = Vector3.new(1.6 * scale, 3.6 * scale, 1.6 * scale),
			cframe = CFrame.new(x, y + 1.7 * scale, rng:NextNumber(-5, 5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			color = hue, neon = true, transparency = 0.25, parent = parent, shape = Enum.PartType.Cylinder, canCollide = false,
		})
		shard.CFrame = shard.CFrame -- keep deterministic
		local light = Instance.new("PointLight")
		light.Color = hue
		light.Range = 10
		light.Brightness = 1.6
		light.Parent = shard
		inkOutline(shard, parent, 0.1)
	end

	local function addColumn()
		local x = randGroundX()
		local y = groundTopAt(x)
		local h = rng:NextNumber(6, 12)
		local col = newPart({
			name = "RuinsColumn", size = Vector3.new(2.2, h, 2.2),
			cframe = CFrame.new(x, y + h / 2, rng:NextNumber(-4, 4)),
			color = Color3.fromRGB(88, 84, 78), material = Enum.Material.Concrete, parent = parent, shape = Enum.PartType.Cylinder,
		})
		col.CFrame = col.CFrame
		newPart({
			name = "ColumnCap", size = Vector3.new(3.0, 0.8, 3.0),
			cframe = CFrame.new(x, y + h + 0.4, 0),
			color = Color3.fromRGB(70, 66, 60), material = Enum.Material.Rock, parent = parent,
		})
		inkOutline(col, parent, 0.1)
	end

	if decor.trees then
		for _ = 1, decor.trees do
			addTree(rng:NextNumber(0.7, 1.6), rng:NextNumber() < 0.5)
		end
	end
	if decor.rocks then
		for _ = 1, decor.rocks do
			addRock(rng:NextNumber(0.6, 1.8))
		end
	end
	if decor.columns then
		for _ = 1, decor.columns do
			addColumn()
		end
	end
	if decor.crystals then
		local palette = { Color3.fromRGB(120, 255, 170), Color3.fromRGB(140, 200, 255), Color3.fromRGB(210, 130, 255) }
		for _ = 1, decor.crystals do
			addCrystal(rng:NextNumber(0.6, 1.5), palette[rng:NextInteger(1, #palette)])
		end
	end

	-- ambient particle emitters
	if decor.fireflies then
		for x = 10, 390, 22 do
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(x, rng:NextNumber(2, 8), rng:NextNumber(-4, 4))
			a.Parent = parent
			local p = Instance.new("ParticleEmitter")
			p.Texture = "rbxassetid://243660364"
			p.Color = ColorSequence.new(Color3.fromRGB(190, 255, 140))
			p.Rate = 1.4
			p.Lifetime = NumberRange.new(2, 4)
			p.Speed = NumberRange.new(0.4, 1.1)
			p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			p.Parent = a
		end
	end
	if decor.embers then
		for x = 780, 1005, 7 do
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(x, rng:NextNumber(1, 6), rng:NextNumber(-5, 5))
			a.Parent = parent
			local p = Instance.new("ParticleEmitter")
			p.Texture = "rbxassetid://243660364"
			p.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 70, 20))
			p.Rate = 2.2
			p.Lifetime = NumberRange.new(0.8, 1.6)
			p.Speed = NumberRange.new(1.5, 3)
			p.Acceleration = Vector3.new(0, 3.5, 0)
			p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
			p.Parent = a
		end
	end
	if decor.snow then
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(1150, 40, 0)
		a.Parent = parent
		local p = Instance.new("ParticleEmitter")
		p.Texture = "rbxassetid://243660364"
		p.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		p.Rate = 18
		p.Lifetime = NumberRange.new(2, 4)
		p.Speed = NumberRange.new(3, 5)
		p.Acceleration = Vector3.new(0, -6, 0)
		p.SpreadAngle = Vector2.new(40, 40)
		p.Size = NumberSequence.new(0.3)
		p.EmissionDirection = Enum.NormalId.Bottom
		p.Parent = a
	end
end

-- —————— public API ——————

function WorldBuilder.build(rootName: string)
	local root = Instance.new("Folder")
	root.Name = rootName
	root.Parent = game:GetService("Workspace")

	local groundsFolder = Instance.new("Folder")
	groundsFolder.Name = "Ground"
	groundsFolder.Parent = root
	local platformsFolder = Instance.new("Folder")
	platformsFolder.Name = "Platforms"
	platformsFolder.Parent = root
	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = root
	local barriersFolder = Instance.new("Folder")
	barriersFolder.Name = "Barriers"
	barriersFolder.Parent = root
	local hazardsFolder = Instance.new("Folder")
	hazardsFolder.Name = "Hazards"
	hazardsFolder.Parent = root
	local checksFolder = Instance.new("Folder")
	checksFolder.Name = "Lanterns"
	checksFolder.Parent = root
	local heartsFolder = Instance.new("Folder")
	heartsFolder.Name = "Hearts"
	heartsFolder.Parent = root
	local portalsFolder = Instance.new("Folder")
	portalsFolder.Name = "Portals"
	portalsFolder.Parent = root
	local arenasFolder = Instance.new("Folder")
	arenasFolder.Name = "Arenas"
	arenasFolder.Parent = root
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = root

	local built = {
		barriers = {},
		hazards = {},
		lanterns = {},
		hearts = {},
		portals = {},
		marker = root,
	}

	-- ground & sky islands
	for _, id in ipairs(Regions.ORDER) do
		local r = Regions.byId[id]
		local isSky = id == "sky"
		for _, g in ipairs(r.grounds) do
			local thickness = g.thickness or 42
			local topY = g.topY
			local width = (g.x1 - g.x0)
			local cx = (g.x0 + g.x1) / 2
			local cy = topY - thickness / 2
			local groundColor: Color3
			local groundMat = Enum.Material.Grass
			if id == "forest" then
				groundColor = Color3.fromRGB(64, 110, 62)
				groundMat = Enum.Material.Grass
			elseif id == "ruins" then
				groundColor = Color3.fromRGB(88, 86, 82)
				groundMat = Enum.Material.Concrete
			elseif id == "burning" then
				groundColor = Color3.fromRGB(96, 48, 34)
				groundMat = Enum.Material.Slate
			elseif id == "frozen" then
				groundColor = Color3.fromRGB(178, 212, 230)
				groundMat = Enum.Material.Ice
			elseif id == "cave" then
				groundColor = Color3.fromRGB(52, 46, 66)
				groundMat = Enum.Material.Rock
			elseif id == "sky" then
				groundColor = Color3.fromRGB(120, 140, 150)
				groundMat = Enum.Material.Slate
			else
				groundColor = Color3.fromRGB(46, 52, 56)
				groundMat = Enum.Material.Rock
			end
			local block = newPart({
				name = "Ground_" .. id,
				size = Vector3.new(width, thickness, 48),
				cframe = CFrame.new(cx, cy, 0),
				color = groundColor,
				material = groundMat,
				parent = groundsFolder,
			})
			if isSky then
				-- ink-black floating island underside
				newPart({
					name = "IslandUnderside",
					size = Vector3.new(width * 0.72, 5, 26),
					cframe = CFrame.new(cx, topY - thickness - 2.4, 0),
					color = Color3.fromRGB(10, 10, 12),
					material = Enum.Material.SmoothPlastic,
					parent = groundsFolder,
				})
			end
		end
		-- ceilings (caves / tunnels)
		for _, c in ipairs(r.ceilings or {}) do
			newPart({
				name = "Ceiling_" .. id,
				size = Vector3.new(c.x1 - c.x0, c.h, 48),
				cframe = CFrame.new((c.x0 + c.x1) / 2, c.y + c.h / 2, 0),
				color = Color3.fromRGB(20, 18, 22),
				material = Enum.Material.Rock,
				parent = groundsFolder,
			})
		end
		-- platforms
		for _, p in ipairs(r.platforms or {}) do
			local plat = newPart({
				name = "Platform",
				size = Vector3.new(p.w, 2, 6),
				cframe = CFrame.new(p.x, p.y, 0),
				color = if id == "frozen" then Color3.fromRGB(206, 232, 246)
					elseif id == "ruins" then Color3.fromRGB(120, 116, 110)
					elseif id == "sky" then Color3.fromRGB(140, 158, 168)
					else Color3.fromRGB(88, 64, 44),
				material = if id == "frozen" then Enum.Material.Ice
					elseif id == "ruins" then Enum.Material.Concrete
					else Enum.Material.Wood,
				parent = platformsFolder,
			})
			inkOutline(plat, platformsFolder, 0.1)
		end
		-- decor
		local decor = Regions.DECOR and Regions.DECOR[id]
		if decor then
			scatterDecor(id, decor, decorFolder, r.grounds)
		end
	end

	-- boss arenas: pillar decorations + invisible lock walls (created by Bosses at fight start)
	local ruins = Regions.byId.ruins
	for _, px in ipairs(ruins.pillars) do
		local pillar = newPart({
			name = "ArenaPillar",
			size = Vector3.new(3.4, 11, 3.4),
			cframe = CFrame.new(px, 5.5, 0),
			color = Color3.fromRGB(98, 94, 88),
			material = Enum.Material.Concrete,
			parent = arenasFolder,
		})
		inkOutline(pillar, arenasFolder, 0.14)
	end
	-- vine patch (mechanical guardian bait)
	if Regions.byId.forest.vinePatch then
		local vp = Regions.byId.forest.vinePatch
		newPart({
			name = "VinePatch",
			size = Vector3.new(vp.x1 - vp.x0, 0.4, 12),
			cframe = CFrame.new((vp.x0 + vp.x1) / 2, 0.2, 0),
			color = Color3.fromRGB(40, 88, 38),
			material = Enum.Material.Grass,
			parent = arenasFolder,
		})
	end
	-- water puddle (fire guardian cleanse)
	local burning = Regions.byId.burning
	local puddle = newPart({
		name = "WaterPuddle",
		size = Vector3.new(11, 0.5, 12),
		cframe = CFrame.new(burning.waterPuddleX, 0.25, 0),
		color = Color3.fromRGB(70, 160, 220),
		material = Enum.Material.Glass,
		transparency = 0.35,
		parent = arenasFolder,
		canCollide = false,
	})
	puddle:SetAttribute("Cleanse", true)
	-- underground water pool
	local pool = Regions.byId.underground.waterPool
	newPart({
		name = "SquidPool",
		size = Vector3.new(pool.x1 - pool.x0, pool.depth, 15),
		cframe = CFrame.new((pool.x0 + pool.x1) / 2, pool.depth / 2 + 0.05, 0),
		color = Color3.fromRGB(28, 66, 84),
		material = Enum.Material.Glass,
		transparency = 0.3,
		parent = arenasFolder,
		canCollide = false,
	})

	-- boundary walls with gated doorways
	for _, wall in ipairs(Regions.WALLS) do
		local halfW = wall.w / 2
		local cx = wall.x
		local door = wall.door
		local doorHalf = door and (door.w / 2) or 0
		-- wall segments left/right of door, then lintel above
		if door then
			local sideW = (wall.w - door.w) / 2
			if sideW > 0 then
				-- (walls are on the boundary; door is interior, sides are decorative lips)
			end
			newPart({
				name = "WallLintel",
				size = Vector3.new(wall.w, wall.h - door.h, 16),
				cframe = CFrame.new(cx, door.h + (wall.h - door.h) / 2, 0),
				color = Color3.fromRGB(30, 30, 34),
				material = Enum.Material.Rock,
				parent = wallsFolder,
			})
			-- flank lips
			local lip = 3
			newPart({
				name = "WallLipL",
				size = Vector3.new(lip, door.h, 16),
				cframe = CFrame.new(cx - doorHalf - lip / 2, door.h / 2, 0),
				color = Color3.fromRGB(30, 30, 34),
				material = Enum.Material.Rock,
				parent = wallsFolder,
			})
			newPart({
				name = "WallLipR",
				size = Vector3.new(lip, door.h, 16),
				cframe = CFrame.new(cx + doorHalf + lip / 2, door.h / 2, 0),
				color = Color3.fromRGB(30, 30, 34),
				material = Enum.Material.Rock,
				parent = wallsFolder,
			})
			-- the barrier itself
			local b: Part? = nil
			if door.barrier == "electric" then
				b = makeBarrier("electric", cx, door.h / 2, door.w - 4, door.h, 8, barriersFolder, Color3.fromRGB(90, 220, 255), true)
				makeLabel("⚡", b, Color3.fromRGB(200, 245, 255))
			elseif door.barrier == "stone" then
				b = makeBarrier("stone", cx, door.h / 2, door.w - 2, door.h, 10, barriersFolder, Color3.fromRGB(122, 106, 84), false, Enum.Material.Rock)
				makeLabel("⬢", b, Color3.fromRGB(232, 220, 190))
			elseif door.barrier == "frozen" then
				b = makeBarrier("frozen", cx, door.h / 2, door.w - 3, door.h, 10, barriersFolder, Color3.fromRGB(160, 225, 255), true, Enum.Material.Ice, 0.15)
			elseif door.barrier == "waterfall" then
				b = makeBarrier("waterfall", cx, door.h / 2, door.w - 1, door.h, 12, barriersFolder, Color3.fromRGB(120, 205, 245), false, Enum.Material.Glass, 0.32)
				makeLabel("≋", b, Color3.fromRGB(200, 240, 255))
				local a = Instance.new("Attachment")
				a.Position = Vector3.new(cx, door.h + 1, 0)
				a.Parent = barriersFolder
				local p = Instance.new("ParticleEmitter")
				p.Texture = "rbxassetid://243660364"
				p.Color = ColorSequence.new(Color3.fromRGB(170, 225, 255))
				p.Rate = 24
				p.Lifetime = NumberRange.new(0.6, 1.0)
				p.Speed = NumberRange.new(8, 12)
				p.Acceleration = Vector3.new(0, -22, 0)
				p.Size = NumberSequence.new(0.5)
				p.EmissionDirection = Enum.NormalId.Bottom
				p.Parent = a
			elseif door.barrier == "machineSeal" then
				b = makeBarrier("machineSeal", cx, door.h / 2, door.w - 2, door.h, 11, barriersFolder, Color3.fromRGB(56, 34, 84), true, nil, 0.05)
				local ring = Instance.new("PointLight")
				ring.Color = Color3.fromRGB(170, 90, 255)
				ring.Range = 18
				ring.Brightness = 2
				ring.Parent = b
				makeLabel("◈", b, Color3.fromRGB(220, 170, 255))
			end
			if b then
				table.insert(built.barriers, b)
			end
		else
			newPart({
				name = "Wall",
				size = Vector3.new(wall.w, wall.h, 16),
				cframe = CFrame.new(cx, wall.h / 2, 0),
				color = Color3.fromRGB(30, 30, 34),
				material = Enum.Material.Rock,
				parent = wallsFolder,
			})
		end
	end

	-- barrier blocks (forest secret pocket)
	for _, id in ipairs(Regions.ORDER) do
		local r = Regions.byId[id]
		for _, bb in ipairs(r.barrierBlocks or {}) do
			local b = makeBarrier(bb.type, bb.x, bb.y, bb.w, bb.h, bb.d or 8, barriersFolder,
				bb.type == "vine" and Color3.fromRGB(44, 96, 40) or Color3.fromRGB(120, 100, 80),
				false, Enum.Material.Grass)
			table.insert(built.barriers, b)
		end
	end

	-- hazards: fire pits & electric strips
	for id, def in pairs(Regions.byId) do
		for _, fp in ipairs((def :: any).firePits or {}) do
			local strip = newPart({
				name = "FirePit",
				size = Vector3.new(fp.x1 - fp.x0, 0.7, 14),
				cframe = CFrame.new((fp.x0 + fp.x1) / 2, 0.35, 0),
				color = Color3.fromRGB(255, 120, 30),
				neon = true,
				parent = hazardsFolder,
				canCollide = false,
			})
			strip:SetAttribute("Hazard", "fire")
			strip:SetAttribute("Damage", 16)
			table.insert(built.hazards, strip)
		end
		for _, es in ipairs((def :: any).electricStrips or {}) do
			local strip = newPart({
				name = "ElectricStrip",
				size = Vector3.new(es.x1 - es.x0, 0.5, 12),
				cframe = CFrame.new((es.x0 + es.x1) / 2, 0.25, 0),
				color = Color3.fromRGB(90, 210, 255),
				neon = true,
				parent = hazardsFolder,
				canCollide = false,
			})
			strip:SetAttribute("Hazard", "electric")
			strip:SetAttribute("Damage", 12)
			table.insert(built.hazards, strip)
		end
	end

	-- the forest river: drowning hazard filling the gap (x 232..276)
	-- fully below ground level (top at y=-1, ground top at y=0)
	local drown = newPart({
		name = "ForestRiver_Drowning",
		size = Vector3.new(44, 6, 46),
		cframe = CFrame.new(254, -4, 0),
		color = Color3.fromRGB(20, 60, 110),
		transparency = 1,
		parent = hazardsFolder,
		canCollide = false,
	})
	drown:SetAttribute("Hazard", "water")
	drown:SetAttribute("Damage", 9999)
	drown.CanTouch = true
	table.insert(built.hazards, drown)

	-- checkpoint lanterns (from Config)
	for _, cp in ipairs(Config.CHECKPOINTS) do
		local baseY = 0
		for _, island in ipairs(Regions.byId.sky.grounds) do
			if cp.x >= island.x0 and cp.x <= island.x1 then
				baseY = island.topY
			end
		end
		local lantern = makeLantern("Lantern_" .. cp.id, cp.x, baseY, checksFolder)
		lantern:SetAttribute("CheckpointId", cp.id)
		lantern:SetAttribute("CheckpointName", cp.name)
		table.insert(built.lanterns, lantern)
	end

	-- hidden hearts
	for _, id in ipairs(Regions.ORDER) do
		local r = Regions.byId[id]
		for _, h in ipairs(r.hearts or {}) do
			local heart = makeHeart("Heart_" .. id, h.x, h.y, heartsFolder)
			table.insert(built.hearts, heart)
		end
	end

	-- two-way portals
	for _, portal in ipairs(Regions.PORTALS) do
		for side, p in pairs({ a = portal.a, b = portal.b }) do
			local pad = newPart({
				name = "PortalPad_" .. portal.id .. side,
				size = Vector3.new(6, 0.6, 8),
				cframe = CFrame.new(p.x, p.y, p.z),
				color = Color3.fromRGB(150, 90, 255),
				neon = true,
				transparency = 0.15,
				parent = portalsFolder,
				canCollide = false,
			})
			pad:SetAttribute("PortalId", portal.id)
			pad:SetAttribute("PortalSide", side)
			pad:SetAttribute("PortalLabel", portal.label or "Travel")
			inkOutline(pad, portalsFolder, 0.2)
			table.insert(built.portals, pad)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(170, 110, 255)
			light.Range = 14
			light.Brightness = 2.2
			light.Parent = pad
			makeLabel("◈ " .. (portal.label or "Portal"), pad, Color3.fromRGB(230, 205, 255))
		end
	end

	-- finale portal (dormant until the Grand Key is claimed)
	local fp = Regions.FINALE_PORTAL
	local finale = newPart({
		name = "FinalePortal",
		size = Vector3.new(7, 0.6, 9),
		cframe = CFrame.new(fp.x, fp.y, fp.z),
		color = Color3.fromRGB(120, 90, 255),
		neon = true,
		transparency = 1, -- invisible until unlocked
		parent = portalsFolder,
		canCollide = false,
	})
	finale:SetAttribute("PortalId", "finale")
	finale:SetAttribute("PortalLabel", "Step through into your world")
	finale.Enabled = true
	built.finalePortal = finale

	-- grand key (hidden until Nukos falls)
	local grandKey = Instance.new("Model")
	grandKey.Name = "GrandKey"
	local keyBody = newPart({
		name = "Shaft",
		size = Vector3.new(0.8, 4.2, 0.8),
		cframe = CFrame.new(Regions.byId.underground.grandKeyX, 5, 0),
		color = Color3.fromRGB(255, 230, 140),
		neon = true,
		parent = grandKey,
	})
	newPart({
		name = "Bow",
		size = Vector3.new(2.2, 2.2, 0.8),
		cframe = CFrame.new(Regions.byId.underground.grandKeyX, 8, 0),
		color = Color3.fromRGB(255, 215, 110),
		neon = true,
		parent = grandKey,
		shape = Enum.PartType.Cylinder,
	})
	local keyLight = Instance.new("PointLight")
	keyLight.Color = Color3.fromRGB(255, 225, 130)
	keyLight.Range = 20
	keyLight.Brightness = 3
	keyLight.Parent = keyBody
	grandKey.PrimaryPart = keyBody
	grandKey.Parent = portalsFolder
	grandKey.Parent = root
	grandKey:SetAttribute("Claimed", false)
	grandKey:GetChildren()[1].Transparency = 1
	for _, d in ipairs(grandKey:GetChildren()) do
		(d :: BasePart).Transparency = 1
	end
	built.grandKey = grandKey

	-- the gigantic machine (rises when awakened)
	local u = Regions.byId.underground
	local machine = Instance.new("Model")
	machine.Name = "GiganticMachine"
	local housing = newPart({
		name = "Housing",
		size = Vector3.new(10, 9, 8),
		cframe = CFrame.new(u.machineRoomX, 4.5, -2),
		color = Color3.fromRGB(60, 58, 64),
		material = Enum.Material.Metal,
		parent = machine,
	})
	local piston = newPart({
		name = "Piston",
		size = Vector3.new(3, 14, 3),
		cframe = CFrame.new(u.machineRoomX, 9, 0),
		color = Color3.fromRGB(96, 92, 100),
		material = Enum.Material.Metal,
		shape = Enum.PartType.Cylinder,
		parent = machine,
	})
	piston.CFrame = CFrame.new(u.machineRoomX, 9, 0) * CFrame.Angles(0, 0, math.rad(90))
	local core = newPart({
		name = "Core",
		size = Vector3.new(2.4, 2.4, 2.4),
		cframe = CFrame.new(u.machineRoomX, 6.4, 2.2),
		color = Color3.fromRGB(80, 60, 120),
		neon = true,
		shape = Enum.PartType.Ball,
		parent = machine,
	})
	local mLight = Instance.new("PointLight")
	mLight.Color = Color3.fromRGB(120, 80, 200)
	mLight.Range = 16
	mLight.Brightness = 0.4
	mLight.Parent = core
	machine.PrimaryPart = housing
	machine.Parent = root
	makeLabel("THE GIGANTIC ENGINE", housing, Color3.fromRGB(180, 150, 230))
	built.machine = machine
	built.machinePiston = piston
	built.machineCore = core

	-- machine console (interact to wake it with the Lightning Core)
	local console = makeBarrier("machineConsole", u.machineRoomX - 6.5, 2, 2, 4, 2, root, Color3.fromRGB(72, 66, 80), false, Enum.Material.Metal)
	console:SetAttribute("Interact", "machine")
	built.machineConsole = console

	-- player spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "InkboundSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(10, 1, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = root

	-- full 3D: invisible Z walls so the player cannot leave the corridor
	for _, side in ipairs({ -1, 1 }) do
		local zWall = newPart({
			name = "ZBoundary_" .. (side < 0 and "Negative" or "Positive"),
			size = Vector3.new(2900, 140, 1),
			cframe = CFrame.new((Config.WORLD.minX + Config.WORLD.maxX) / 2, 30, side * 23.5),
			color = Color3.fromRGB(0, 0, 0),
			material = Enum.Material.SmoothPlastic,
			transparency = 1,
			canQuery = false,
			parent = root,
		})
		zWall.CanCollide = true
		zWall.CanTouch = false
	end

	return built
end

return WorldBuilder
