--!strict
-- Inkbound — Terrain builder
-- Fills the voxel terrain under the playable corridor so the world looks like real ground,
-- not a floating sky platform. Called once at server boot, BEFORE the world parts are built.
-- The layout follows Regions.luau so terrain matches each zone's ground tops.

local Regions = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Regions"))

local TerrainBuilder = {}

type Ground = { x0: number, x1: number, topY: number, thickness: number? }

local function materialFor(id: string): Enum.Material
	if id == "forest" then return Enum.Material.Grass
	elseif id == "ruins" then return Enum.Material.Concrete
	elseif id == "burning" then return Enum.Material.Sandstone
	elseif id == "frozen" then return Enum.Material.Ice
	elseif id == "cave" then return Enum.Material.Rock
	elseif id == "sky" then return Enum.Material.Slate
	else
		return Enum.Material.Ground
	end
end

function TerrainBuilder.build()
	local terrain = workspace.Terrain
	-- keep it shallow so it never swallows the hand-placed parts; just a bit of visual depth
	for id, r in pairs(Regions.byId) do
		local mat = materialFor(id)
		for _, g in ipairs((r :: any).grounds or {}) do
			local ground = g :: Ground
			local width = ground.x1 - ground.x0
			local thickness = ground.thickness or 4
			local cx = (ground.x0 + ground.x1) / 2
			local top = ground.topY or 0
			local cf = CFrame.new(cx, top - thickness / 2, 0)
			local size = Vector3.new(width, thickness, 46)
			terrain:FillBlock(cf, size, mat)
		end
	end
end

return TerrainBuilder
