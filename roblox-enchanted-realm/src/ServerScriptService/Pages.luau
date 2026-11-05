--!strict
-- Enchanted Realm: Inkbound — Ink Memories
-- 8 hidden "pages" of the lost Guest's journal scattered through the world.
-- Each one: +30 XP, a lore line, and a permanent mark save-side.
-- Required by Main.server.luau (Main calls Pages.init(RE) once at boot).

local Session = require(script.Parent:WaitForChild("Session"))

local Pages = {}

type PageSpec = { id: string, x: number, y: number, text: string }

local PAGES: { PageSpec } = {
	{ id = "p1", x = 45,   y = 4,  text = "Day 1 — The forest breathed. I swear it breathed." },
	{ id = "p2", x = 210,  y = 3,  text = "Day 4 — The ink in my pen never dried. It whispers." },
	{ id = "p3", x = 428,  y = 6,  text = "Day 9 — The machines here were never machines." },
	{ id = "p4", x = 660,  y = 9,  text = "Day 12 — I drew this page. It drew me back." },
	{ id = "p5", x = 800,  y = 3,  text = "Day 13 — Every flame is a candle someone lit for me." },
	{ id = "p6", x = 1045, y = 5,  text = "Day 15 — I froze. It knew my name before I spoke it." },
	{ id = "p7", x = 1340, y = 12, text = "Day 17 — The cave was a sketch of a sun I'd never seen." },
	{ id = "p8", x = 1880, y = 65, text = "Day 20 — The sky is paper. We are what it chooses to draw." },
}

function Pages.init(RE)
	local world = game:GetService("Workspace")
	for i, spec in ipairs(PAGES) do
		local page = Instance.new("Part")
		page.Name = "InkMemory_" .. spec.id
		page.Size = Vector3.new(1.7, 2.2, 0.12)
		page.Position = Vector3.new(spec.x, spec.y, 0)
		page.Color = Color3.fromRGB(235, 225, 190)
		page.Material = Enum.Material.Neon
		page.Transparency = 0.15
		page.Anchored = true
		page.CanCollide = false
		page.Parent = world

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 230, 150)
		light.Range = 10
		light.Brightness = 1.6
		light.Parent = page

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Read page"
		prompt.ObjectText = "Ink Memory " .. i .. "/8"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = page

		prompt.Triggered:Connect(function(player: Player)
			local s = Session.get(player)
			if not s then
				return
			end
			s.save.foundPages = s.save.foundPages or {}
			if s.save.foundPages[spec.id] then
				return
			end
			s.save.foundPages[spec.id] = true
			s.dirty = true

			page.Transparency = 1
			light.Enabled = false
			prompt.Enabled = false

			local leveled = Session.addXp(s, 30)

			local found = 0
			for _ in pairs(s.save.foundPages) do
				found += 1
			end
			RE.dialogue:FireClient(player, "memory", spec.text)
			RE.narrator:FireClient(player, "Ink Memory " .. found .. "/8 — +30 XP" .. (leveled and " — LEVEL UP!" or ""), 4)
			RE.playSound:FireAllClients("Checkpoint", page.Position, 0.8)
			RE.vfx:FireAllClients("lanternLit", page.Position)
			RE.sync:FireClient(player, Session.syncPayload(s))
		end)
	end
end

return Pages
